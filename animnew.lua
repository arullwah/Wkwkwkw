-- ByaruL AutoWalk v2.3 - RealTime Optimized Edition
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local player = Players.LocalPlayer
wait(1)

-- ========= REAL-TIME CONFIGURATION =========
local RECORDING_FPS = 60
local MAX_FRAMES = 30000
local MIN_DISTANCE_THRESHOLD = 0.015
local VELOCITY_SCALE = 1
local VELOCITY_Y_SCALE = 1
local ROUTE_PROXIMITY_THRESHOLD = 15

-- ========= ENHANCED RIG DETECTION =========
local RIG_PROFILES = {
    ["R6"] = {
        Height = 5.0,
        HipHeight = 1.35,
        VelocityMultiplier = 1.0,
        JumpPower = 50,
        GroundOffset = 0.0,
        HeightCompensation = 0.0,
        TorsoName = "Torso",
        HeadOffset = 1.5
    },
    ["R15"] = {
        Height = 5.4,
        HipHeight = 2.1, 
        VelocityMultiplier = 1.0,
        JumpPower = 50,
        GroundOffset = 0.0,
        HeightCompensation = 0.75,
        TorsoName = "UpperTorso",
        HeadOffset = 0.65
    },
    ["R15_Tall"] = {
        Height = 6.5,
        HipHeight = 2.8,
        VelocityMultiplier = 1.15,
        JumpPower = 50,
        GroundOffset = 0.5,
        HeightCompensation = 1.5,
        TorsoName = "UpperTorso",
        HeadOffset = 0.8
    },
    ["Zepeto"] = {
        Height = 4.8,
        HipHeight = 0.5,
        VelocityMultiplier = 1.0,
        JumpPower = 50,
        GroundOffset = 2.0,
        HeightCompensation = 3.5,
        TorsoName = "UpperTorso",
        HeadOffset = 0.3
    }
}

-- ========= VARIABLES =========
local IsRecording = false
local IsPlaying = false
local IsPaused = false
local CurrentSpeed = 1
local CurrentWalkSpeed = 16
local RecordedMovements = {}
local RecordingOrder = {}
local CurrentRecording = {Frames = {}, StartTime = 0, Name = ""}
local SelectedReplays = {}

local AutoRespawn = false
local InfiniteJump = false
local AutoLoop = false
local R15TallMode = false
local ForceZepetoMode = false
local IsZepetoCharacter = false
local CurrentRigType = "R15"

local recordConnection = nil
local playbackConnection = nil
local loopConnection = nil
local jumpConnection = nil
local shiftLockConnection = nil

local lastFrameTime = 0
local frameInterval = 1 / RECORDING_FPS
local lastRecordPos = nil

local checkpointNames = {}
local PathVisualization = {}
local ShowPaths = false
local CurrentPauseMarker = nil

-- ========= PLAYBACK STATE =========
local playbackStartTime = 0
local totalPausedDuration = 0
local pauseStartTime = 0
local currentPlaybackFrame = 1
local lastPlaybackState = nil

-- ========= AUTO LOOP STATE =========
local IsAutoLoopPlaying = false
local CurrentLoopIndex = 1
local SelectedReplaysList = {}

-- ========= CONNECTION MANAGEMENT =========
local activeConnections = {}

local function AddConnection(connection)
    table.insert(activeConnections, connection)
end

local function CleanupConnections()
    for _, connection in ipairs(activeConnections) do
        if connection then connection:Disconnect() end
    end
    activeConnections = {}
    
    if recordConnection then recordConnection:Disconnect() recordConnection = nil end
    if playbackConnection then playbackConnection:Disconnect() playbackConnection = nil end
    if loopConnection then loopConnection:Disconnect() loopConnection = nil end
    if jumpConnection then jumpConnection:Disconnect() jumpConnection = nil end
    if shiftLockConnection then shiftLockConnection:Disconnect() shiftLockConnection = nil end
    
    for _, part in pairs(PathVisualization) do
        pcall(function() part:Destroy() end)
    end
    PathVisualization = {}
    
    if CurrentPauseMarker then
        pcall(function() CurrentPauseMarker:Destroy() end)
        CurrentPauseMarker = nil
    end
end

-- ========= ENHANCED CHARACTER DETECTION =========
local function EnhancedRigDetection(character)
    character = character or player.Character
    if not character then return "R15" end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return "R15" end
    
    local rigType = humanoid.RigType.Name
    
    if rigType == "R6" then
        return "R6"
    elseif rigType == "R15" then
        local hrp = character:FindFirstChild("HumanoidRootPart")
        local head = character:FindFirstChild("Head")
        local upperTorso = character:FindFirstChild("UpperTorso")
        local leftUpperLeg = character:FindFirstChild("LeftUpperLeg")
        
        if hrp and head and upperTorso then
            local characterHeight = math.abs(head.Position.Y - hrp.Position.Y) + (head.Size.Y / 2)
            local torsoHeight = upperTorso.Size.Y
            local legLength = 0
            
            if leftUpperLeg then
                local leftLowerLeg = character:FindFirstChild("LeftLowerLeg")
                if leftLowerLeg then
                    legLength = leftUpperLeg.Size.Y + leftLowerLeg.Size.Y
                end
            end
            
            if characterHeight > 6.2 or legLength > 3.8 or torsoHeight > 1.4 then
                return "R15_Tall"
            end
            
            if characterHeight > 6.0 then
                return "R15_Tall"
            end
        end
        
        return "R15"
    end
    
    return "R15"
end

local function AdvancedZepetoDetection(character)
    if not character then return false end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    
    local head = character:FindFirstChild("Head")
    local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    
    if head and torso then
        local headSize = head.Size.Y
        local torsoSize = torso.Size.Y
        local sizeRatio = headSize / torsoSize
        
        if sizeRatio > 1.3 then
            return true
        end
        
        if headSize > 1.1 and torsoSize < 0.9 then
            return true
        end
    end
    
    local playerName = string.lower(player.Name)
    local displayName = string.lower(player.DisplayName)
    
    local zepetoKeywords = {"zepeto", "itboy", "2d", "flat", "chibi", "anime"}
    for _, keyword in ipairs(zepetoKeywords) do
        if string.find(playerName, keyword) or string.find(displayName, keyword) then
            return true
        end
    end
    
    for _, obj in pairs(character:GetChildren()) do
        if obj:IsA("Animation") then
            local animName = string.lower(obj.Name)
            for _, keyword in ipairs(zepetoKeywords) do
                if string.find(animName, keyword) then
                    return true
                end
            end
        end
    end
    
    return false
end

local function GetRigProfile(rigType)
    rigType = rigType or CurrentRigType
    
    if IsZepetoCharacter or ForceZepetoMode then
        return RIG_PROFILES["Zepeto"] or RIG_PROFILES["R15"]
    end
    
    return RIG_PROFILES[rigType] or RIG_PROFILES["R15"]
end

-- ========= REAL-TIME MOVEMENT FUNCTIONS =========
local function GetFramePosition(frame)
    return Vector3.new(frame.Position[1], frame.Position[2], frame.Position[3])
end

local function GetFrameCFrame(frame, recordedRig, currentRig)
    local pos = GetFramePosition(frame)
    local look = Vector3.new(frame.LookVector[1], frame.LookVector[2], frame.LookVector[3])
    local up = Vector3.new(frame.UpVector[1], frame.UpVector[2], frame.UpVector[3])
    
    if IsZepetoCharacter or ForceZepetoMode then
        pos = pos + Vector3.new(0, 8.0, 0)
    else
        local recordedProfile = RIG_PROFILES[recordedRig] or RIG_PROFILES["R15"]
        local currentProfile = RIG_PROFILES[currentRig] or RIG_PROFILES["R15"]
        local heightOffset = currentProfile.HipHeight - recordedProfile.HipHeight
        
        if R15TallMode and recordedRig == "R6" and currentRig == "R15_Tall" then
            heightOffset = heightOffset + 1.3
        end
        
        pos = pos + Vector3.new(0, heightOffset, 0)
    end
    
    return CFrame.lookAt(pos, pos + look, up)
end

local function GetFrameVelocity(frame, recordedRig, currentRig)
    recordedRig = recordedRig or frame.RigType or "R15"
    currentRig = currentRig or CurrentRigType
    
    local recordedProfile = RIG_PROFILES[recordedRig] or RIG_PROFILES["R15"]
    local currentProfile = RIG_PROFILES[currentRig] or RIG_PROFILES["R15"]
    local compatMultiplier = currentProfile.VelocityMultiplier / recordedProfile.VelocityMultiplier
    local heightMultiplier = currentProfile.Height / recordedProfile.Height
    
    if R15TallMode and recordedRig == "R6" and currentRig == "R15_Tall" then
        heightMultiplier = 1.15
    end
    
    return frame.Velocity and Vector3.new(
        frame.Velocity[1] * VELOCITY_SCALE * compatMultiplier * heightMultiplier,
        frame.Velocity[2] * VELOCITY_Y_SCALE * compatMultiplier,
        frame.Velocity[3] * VELOCITY_SCALE * compatMultiplier * heightMultiplier
    ) or Vector3.new(0, 0, 0)
end

local function GetFrameWalkSpeed(frame)
    return frame.WalkSpeed or 16
end

local function GetFrameTimestamp(frame)
    return frame.Timestamp or 0
end

local function GetRecordingRigType(recording)
    if not recording or #recording == 0 then return "R15" end
    return recording[1].RigType or "R15"
end

-- ========= CHARACTER MANAGEMENT =========
local function IsCharacterReady()
    local char = player.Character
    if not char then return false end
    if not char:FindFirstChild("HumanoidRootPart") then return false end
    if not char:FindFirstChildOfClass("Humanoid") then return false end
    if char.Humanoid.Health <= 0 then return false end
    return true
end

local function ResetCharacter()
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.Health = 0
        end
    end
end

local prePauseHumanoidState = nil
local prePauseWalkSpeed = 16
local prePauseAutoRotate = true
local prePauseJumpPower = 50

local function SaveHumanoidState()
    local char = player.Character
    if not char then return end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        prePauseAutoRotate = humanoid.AutoRotate
        prePauseWalkSpeed = humanoid.WalkSpeed
        prePauseJumpPower = humanoid.JumpPower
        prePauseHumanoidState = humanoid:GetState()
    end
end

local function RestoreHumanoidState()
    local char = player.Character
    if not char then return end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.AutoRotate = prePauseAutoRotate
        humanoid.WalkSpeed = prePauseWalkSpeed
        humanoid.JumpPower = prePauseJumpPower
    end
end

local function DisableJump()
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.JumpPower = 0
        end
    end
end

local function EnableJump()
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.JumpPower = prePauseJumpPower or GetRigProfile().JumpPower
        end
    end
end

local function RestoreFullUserControl()
    local char = player.Character
    if not char then return end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
    if humanoid then
        humanoid.AutoRotate = true
        humanoid.WalkSpeed = CurrentWalkSpeed
        humanoid.JumpPower = GetRigProfile().JumpPower
        humanoid.PlatformStand = false
        humanoid.Sit = false
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end
    
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end
end

-- ========= REAL-TIME PLAYBACK SYSTEM =========
local function RealTimePlayback(recording, startFrame, recordedRig, currentRig)
    if not recording or #recording == 0 then return end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    playbackStartTime = tick()
    totalPausedDuration = 0
    pauseStartTime = 0
    lastPlaybackState = nil

    playbackConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not IsPlaying then
            playbackConnection:Disconnect()
            RestoreFullUserControl()
            return
        end
        
        if IsPaused then
            if pauseStartTime == 0 then
                pauseStartTime = tick()
                RestoreHumanoidState()
            end
            return
        else
            if pauseStartTime > 0 then
                totalPausedDuration = totalPausedDuration + (tick() - pauseStartTime)
                pauseStartTime = 0
                SaveHumanoidState()
                DisableJump()
            end
        end

        char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            IsPlaying = false
            playbackConnection:Disconnect()
            RestoreFullUserControl()
            return
        end

        hum = char:FindFirstChildOfClass("Humanoid")
        hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then
            IsPlaying = false
            playbackConnection:Disconnect()
            RestoreFullUserControl()
            return
        end

        local currentTime = tick()
        local effectiveTime = (currentTime - playbackStartTime - totalPausedDuration) * CurrentSpeed
        
        local currentFrame = 1
        for i = 1, #recording do
            if GetFrameTimestamp(recording[i]) <= effectiveTime then
                currentFrame = i
            else
                break
            end
        end

        if currentFrame >= #recording then
            IsPlaying = false
            IsPaused = false
            lastPlaybackState = nil
            
            local finalFrame = recording[#recording]
            if finalFrame then
                pcall(function()
                    hrp.CFrame = GetFrameCFrame(finalFrame, recordedRig, currentRig)
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                end)
            end
            
            RestoreFullUserControl()
            playbackConnection:Disconnect()
            return
        end

        local targetFrame = recording[currentFrame]
        if not targetFrame then return end

        pcall(function()
            local targetCFrame = GetFrameCFrame(targetFrame, recordedRig, currentRig)
            local targetVelocity = GetFrameVelocity(targetFrame, recordedRig, currentRig) * CurrentSpeed
            
            hrp.CFrame = targetCFrame
            hrp.AssemblyLinearVelocity = targetVelocity
            hum.WalkSpeed = GetFrameWalkSpeed(targetFrame) * CurrentSpeed
            
            local moveState = targetFrame.MoveState
            if moveState ~= lastPlaybackState then
                lastPlaybackState = moveState
                
                if moveState == "Climbing" then
                    hum:ChangeState(Enum.HumanoidStateType.Climbing)
                elseif moveState == "Jumping" then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                elseif moveState == "Falling" then
                    hum:ChangeState(Enum.HumanoidStateType.Freefall)
                elseif moveState == "Swimming" then
                    hum:ChangeState(Enum.HumanoidStateType.Swimming)
                else
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                end
            end
            
            currentPlaybackFrame = currentFrame
            FrameLabel.Text = string.format("Frame: %d/%d", currentPlaybackFrame, #recording)
        end)
    end)
    
    AddConnection(playbackConnection)
end

-- ========= ENHANCED AUTO LOOP SYSTEM =========
local function GetSelectedReplaysList()
    local selectedList = {}
    
    for _, name in ipairs(RecordingOrder) do
        if RecordedMovements[name] and #RecordedMovements[name] > 0 then
            if SelectedReplays[name] then
                table.insert(selectedList, name)
            end
        end
    end
    
    if #selectedList == 0 then
        for _, name in ipairs(RecordingOrder) do
            if RecordedMovements[name] and #RecordedMovements[name] > 0 then
                table.insert(selectedList, name)
            end
        end
    end
    
    return selectedList
end

local function EnhancedAutoLoopPlayback()
    if IsAutoLoopPlaying then return end
    
    SelectedReplaysList = GetSelectedReplaysList()
    if #SelectedReplaysList == 0 then
        return
    end
    
    CurrentLoopIndex = 1
    IsAutoLoopPlaying = true
    AutoLoop = true
    
    loopConnection = RunService.Heartbeat:Connect(function()
        if not AutoLoop or not IsAutoLoopPlaying then
            if loopConnection then
                loopConnection:Disconnect()
                loopConnection = nil
            end
            IsAutoLoopPlaying = false
            return
        end
        
        if CurrentLoopIndex <= #SelectedReplaysList then
            local recordingName = SelectedReplaysList[CurrentLoopIndex]
            local recording = RecordedMovements[recordingName]
            
            if recording and #recording > 0 then
                local maxWaitTime = 10
                local waitStart = tick()
                
                while not IsCharacterReady() and AutoLoop and IsAutoLoopPlaying do
                    if tick() - waitStart > maxWaitTime then
                        if AutoRespawn then
                            ResetCharacter()
                            task.wait(2)
                        end
                        break
                    end
                    task.wait(0.1)
                end
                
                if IsCharacterReady() and AutoLoop and IsAutoLoopPlaying then
                    local recordedRig = GetRecordingRigType(recording)
                    local currentRig = CurrentRigType
                    
                    SaveHumanoidState()
                    DisableJump()
                    
                    local playbackStart = tick()
                    local playbackPaused = 0
                    local currentPlayFrame = 1
                    local playbackComplete = false
                    
                    while AutoLoop and IsAutoLoopPlaying and currentPlayFrame <= #recording do
                        if IsPaused then
                            task.wait(0.1)
                            playbackPaused = playbackPaused + 0.1
                            continue
                        end
                        
                        local char = player.Character
                        if not char or not char:FindFirstChild("HumanoidRootPart") then
                            break
                        end
                        
                        local effectiveTime = (tick() - playbackStart - playbackPaused) * CurrentSpeed
                        
                        currentPlayFrame = 1
                        for i = 1, #recording do
                            if GetFrameTimestamp(recording[i]) <= effectiveTime then
                                currentPlayFrame = i
                            else
                                break
                            end
                        end
                        
                        if currentPlayFrame > #recording then
                            playbackComplete = true
                            break
                        end
                        
                        local frame = recording[currentPlayFrame]
                        if frame then
                            pcall(function()
                                local hrp = char.HumanoidRootPart
                                local hum = char:FindFirstChildOfClass("Humanoid")
                                
                                if hrp and hum then
                                    hrp.CFrame = GetFrameCFrame(frame, recordedRig, currentRig)
                                    hrp.AssemblyLinearVelocity = GetFrameVelocity(frame, recordedRig, currentRig) * CurrentSpeed
                                    hum.WalkSpeed = GetFrameWalkSpeed(frame) * CurrentSpeed
                                    
                                    local moveState = frame.MoveState
                                    if moveState == "Jumping" then
                                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                                    elseif moveState == "Falling" then
                                        hum:ChangeState(Enum.HumanoidStateType.Freefall)
                                    elseif moveState == "Climbing" then
                                        hum:ChangeState(Enum.HumanoidStateType.Climbing)
                                    else
                                        hum:ChangeState(Enum.HumanoidStateType.Running)
                                    end
                                end
                            end)
                        end
                        
                        FrameLabel.Text = string.format("Loop: %d/%d | Frame: %d/%d", 
                            CurrentLoopIndex, #SelectedReplaysList, currentPlayFrame, #recording)
                        
                        task.wait()
                    end
                    
                    RestoreFullUserControl()
                    
                    if playbackComplete then
                        CurrentLoopIndex = CurrentLoopIndex + 1
                    else
                        CurrentLoopIndex = CurrentLoopIndex + 1
                    end
                else
                    CurrentLoopIndex = CurrentLoopIndex + 1
                end
            else
                CurrentLoopIndex = CurrentLoopIndex + 1
            end
        else
            CurrentLoopIndex = 1
        end
        
        if AutoLoop and IsAutoLoopPlaying then
            task.wait(0.5)
        end
    end)
    
    AddConnection(loopConnection)
end

-- ========= RECORDING SYSTEM =========
local function GetCurrentMoveState(hum)
    if not hum then return "Grounded" end
    local state = hum:GetState()
    if state == Enum.HumanoidStateType.Climbing then return "Climbing"
    elseif state == Enum.HumanoidStateType.Jumping then return "Jumping"
    elseif state == Enum.HumanoidStateType.Freefall then return "Falling"
    elseif state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics then return "Grounded"
    elseif state == Enum.HumanoidStateType.Swimming then return "Swimming"
    else return "Grounded" end
end

local function ShouldRecordFrame()
    local currentTime = tick()
    return (currentTime - lastFrameTime) >= frameInterval
end

function StartRecording()
    if IsRecording then return end
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    IsRecording = true
    CurrentRecording = {Frames = {}, StartTime = tick(), Name = "recording_" .. os.date("%H%M%S")}
    lastFrameTime = 0
    lastRecordPos = nil
    
    RecordBtnBig.Text = "STOP RECORDING"
    RecordBtnBig.BackgroundColor3 = Color3.fromRGB(163, 10, 10)
    
    recordConnection = RunService.Heartbeat:Connect(function()
        if not IsRecording then return end
        
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") or #CurrentRecording.Frames >= MAX_FRAMES then
            StopRecording()
            return
        end
        
        if not ShouldRecordFrame() then return end
        
        local hrp = char.HumanoidRootPart
        local hum = char:FindFirstChildOfClass("Humanoid")
        local currentPos = hrp.Position
        local currentVelocity = hrp.AssemblyLinearVelocity
        local moveState = GetCurrentMoveState(hum)

        if lastRecordPos and (currentPos - lastRecordPos).Magnitude < MIN_DISTANCE_THRESHOLD and moveState == "Grounded" then
            return
        end

        local cf = hrp.CFrame
        local frameData = {
            Position = {cf.Position.X, cf.Position.Y, cf.Position.Z},
            LookVector = {cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z},
            UpVector = {cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z},
            Velocity = {currentVelocity.X, currentVelocity.Y, currentVelocity.Z},
            MoveState = moveState,
            WalkSpeed = hum and hum.WalkSpeed or 16,
            Timestamp = tick() - CurrentRecording.StartTime,
            RigType = CurrentRigType
        }
        
        table.insert(CurrentRecording.Frames, frameData)
        lastFrameTime = tick()
        lastRecordPos = currentPos
        
        FrameLabel.Text = string.format("Frames: %d", #CurrentRecording.Frames)
    end)
    
    AddConnection(recordConnection)
end

function StopRecording()
    if not IsRecording then return end
    IsRecording = false
    
    if recordConnection then
        recordConnection:Disconnect()
        recordConnection = nil
    end
    
    if #CurrentRecording.Frames > 0 then
        local name = CurrentRecording.Name
        RecordedMovements[name] = CurrentRecording.Frames
        table.insert(RecordingOrder, name)
        checkpointNames[name] = "checkpoint_" .. #RecordingOrder
        SelectedReplays[name] = false
        UpdateRecordList()
    end
    
    RecordBtnBig.Text = "RECORDING"
    RecordBtnBig.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
    FrameLabel.Text = "Frames: 0"
end

-- ========= PLAYBACK CONTROL =========
function PlayRecording(name)
    if IsPlaying then return end
    
    local recording = name and RecordedMovements[name] or (RecordingOrder[1] and RecordedMovements[RecordingOrder[1]])
    if not recording or #recording == 0 then
        return
    end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        return
    end

    IsPlaying = true
    IsPaused = false
    totalPausedDuration = 0
    pauseStartTime = 0
    lastPlaybackState = nil

    local recordedRig = GetRecordingRigType(recording)
    local currentRig = CurrentRigType
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local nearestFrame = 1
    
    for i = 1, #recording do
        local framePos = GetFramePosition(recording[i])
        local distance = (framePos - hrp.Position).Magnitude
        if distance <= ROUTE_PROXIMITY_THRESHOLD then
            nearestFrame = i
        end
    end
    
    currentPlaybackFrame = nearestFrame
    playbackStartTime = tick() - (GetFrameTimestamp(recording[nearestFrame]) / CurrentSpeed)

    SaveHumanoidState()
    DisableJump()

    RealTimePlayback(recording, currentPlaybackFrame, recordedRig, currentRig)
end

function PausePlayback()
    if not IsPlaying and not IsAutoLoopPlaying then return end
    
    IsPaused = not IsPaused
    
    if IsPaused then
        PauseBtnBig.Text = "RESUME"
        PauseBtnBig.BackgroundColor3 = Color3.fromRGB(8, 181, 116)
        RestoreHumanoidState()
        EnableJump()
    else
        PauseBtnBig.Text = "PAUSE"
        PauseBtnBig.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
        SaveHumanoidState()
        DisableJump()
    end
end

function StopPlayback()
    if AutoLoop then
        StopAutoLoopAll()
    end
    
    if not IsPlaying then return end
    IsPlaying = false
    IsPaused = false
    lastPlaybackState = nil
    
    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end
    
    RestoreFullUserControl()
    
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if humanoid then
            humanoid.AutoRotate = true
            humanoid.WalkSpeed = CurrentWalkSpeed
            humanoid.JumpPower = GetRigProfile().JumpPower
        end
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
    end
end

local function StopAutoLoopAll()
    AutoLoop = false
    IsAutoLoopPlaying = false
    IsPlaying = false
    IsPaused = false
    lastPlaybackState = nil
    
    if loopConnection then
        loopConnection:Disconnect()
        loopConnection = nil
    end
    
    RestoreFullUserControl()
    
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if humanoid then
            humanoid.AutoRotate = true
            humanoid.WalkSpeed = CurrentWalkSpeed
            humanoid.JumpPower = GetRigProfile().JumpPower
        end
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
    end
end

-- ========= GUI SETUP =========
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoWalkByaruL"
ScreenGui.ResetOnSpawn = false
if player:FindFirstChild("PlayerGui") then
    ScreenGui.Parent = player.PlayerGui
else
    wait(2)
    ScreenGui.Parent = player:WaitForChild("PlayerGui")
end

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.fromOffset(250, 350)
MainFrame.Position = UDim2.new(0.5, -125, 0.5, -225)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 32)
Header.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 12)
HeaderCorner.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 1, 0)
Title.BackgroundTransparency = 1
Title.Text = "ByaruL - RealTime Edition"
Title.TextColor3 = Color3.fromRGB(255,255,255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Center
Title.Parent = Header

local FrameLabel = Instance.new("TextLabel")
FrameLabel.Size = UDim2.new(0, 70, 1, 0)
FrameLabel.Position = UDim2.new(0, 5, 0, 0)
FrameLabel.BackgroundTransparency = 1
FrameLabel.Text = "Frame: 0"
FrameLabel.TextColor3 = Color3.fromRGB(255,255,255)
FrameLabel.Font = Enum.Font.GothamBold
FrameLabel.TextSize = 9
FrameLabel.Parent = Header

local HideButton = Instance.new("TextButton")
HideButton.Size = UDim2.fromOffset(25, 25)
HideButton.Position = UDim2.new(1, -60, 0.5, -12)
HideButton.BackgroundColor3 = Color3.fromRGB(162, 175, 170)
HideButton.Text = "_"
HideButton.TextColor3 = Color3.new(1, 1, 1)
HideButton.Font = Enum.Font.GothamBold
HideButton.TextSize = 14
HideButton.Parent = Header

local HideCorner = Instance.new("UICorner")
HideCorner.CornerRadius = UDim.new(0, 6)
HideCorner.Parent = HideButton

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.fromOffset(25, 25)
CloseButton.Position = UDim2.new(1, -30, 0.5, -12)
CloseButton.BackgroundColor3 = Color3.fromRGB(230, 62, 62)
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.new(1, 1, 1)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 12
CloseButton.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseButton

local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, -10, 1, -42)
Content.Position = UDim2.new(0, 5, 0, 36)
Content.BackgroundTransparency = 1
Content.ScrollBarThickness = 6
Content.ScrollBarImageColor3 = Color3.fromRGB(80, 120, 255)
Content.ScrollingDirection = Enum.ScrollingDirection.Y
Content.VerticalScrollBarInset = Enum.ScrollBarInset.Always
Content.CanvasSize = UDim2.new(0, 0, 0, 800)
Content.Parent = MainFrame

local MiniButton = Instance.new("TextButton")
MiniButton.Size = UDim2.fromOffset(40, 40)
MiniButton.Position = UDim2.new(0.5, -22.5, 0, -30)
MiniButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MiniButton.Text = "⚙️"
MiniButton.TextColor3 = Color3.new(1, 1, 1)
MiniButton.Font = Enum.Font.GothamBold
MiniButton.TextSize = 25
MiniButton.Visible = false
MiniButton.Active = true
MiniButton.Draggable = true
MiniButton.Parent = ScreenGui

local MiniCorner = Instance.new("UICorner")
MiniCorner.CornerRadius = UDim.new(0, 8)
MiniCorner.Parent = MiniButton

local function CreateButton(text, x, y, w, h, color, parent)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(w, h)
    btn.Position = UDim2.fromOffset(x, y)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 9
    btn.AutoButtonColor = false
    btn.Parent = parent or Content
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    
    return btn
end

local function CreateToggle(text, x, y, w, h, default)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(w, h)
    btn.Position = UDim2.fromOffset(x, y)
    btn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    btn.Text = ""
    btn.Parent = Content
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = btn
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, w - 28, 1, 0)
    label.Position = UDim2.new(0, 4, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 220)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 7
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = btn
    
    local toggle = Instance.new("Frame")
    toggle.Size = UDim2.fromOffset(22, 12)
    toggle.Position = UDim2.new(1, -25, 0.5, -6)
    toggle.BackgroundColor3 = default and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(50, 50, 50)
    toggle.BorderSizePixel = 0
    toggle.Parent = btn
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(1, 0)
    toggleCorner.Parent = toggle
    
    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(8, 8)
    knob.Position = default and UDim2.new(0, 12, 0, 2) or UDim2.new(0, 2, 0, 2)
    knob.BackgroundColor3 = Color3.fromRGB(220, 220, 230)
    knob.BorderSizePixel = 0
    knob.Parent = toggle
    
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob
    
    local function Animate(isOn)
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local bgColor = isOn and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(50, 50, 50)
        local knobPos = isOn and UDim2.new(0, 12, 0, 2) or UDim2.new(0, 2, 0, 2)
        TweenService:Create(toggle, tweenInfo, {BackgroundColor3 = bgColor}):Play()
        TweenService:Create(knob, tweenInfo, {Position = knobPos}):Play()
    end
    
    return btn, Animate
end

-- ========= UI ELEMENTS =========
local RecordBtnBig = CreateButton("RECORDING", 5, 5, 117, 30, Color3.fromRGB(59, 15, 116))
local PlayBtnBig = CreateButton("PLAY", 5, 40, 75, 30, Color3.fromRGB(59, 15, 116))
local StopBtnBig = CreateButton("STOP", 85, 40, 75, 30, Color3.fromRGB(59, 15, 116))
local PauseBtnBig = CreateButton("PAUSE", 165, 40, 75, 30, Color3.fromRGB(59, 15, 116))

local LoopBtn, AnimateLoop = CreateToggle("Auto Loop", 0, 75, 78, 22, false)
local JumpBtn, AnimateJump = CreateToggle("Infinite Jump", 82, 75, 78, 22, false)
local ShiftLockBtn, AnimateShiftLock = CreateToggle("ShiftLock", 164, 75, 78, 22, false)

local RespawnBtn, AnimateRespawn = CreateToggle("Auto Respawn", 0, 102, 117, 22, false)
local R15TallBtn, AnimateR15Tall = CreateToggle("R6 → R15 Tall", 123, 102, 117, 22, false)

local SpeedBox = Instance.new("TextBox")
SpeedBox.Size = UDim2.fromOffset(55, 26)
SpeedBox.Position = UDim2.fromOffset(5, 129)
SpeedBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
SpeedBox.BorderSizePixel = 0
SpeedBox.Text = "1.00"
SpeedBox.PlaceholderText = "Speed..."
SpeedBox.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedBox.Font = Enum.Font.GothamBold
SpeedBox.TextSize = 11
SpeedBox.TextXAlignment = Enum.TextXAlignment.Center
SpeedBox.ClearTextOnFocus = false
SpeedBox.Parent = Content

local SpeedCorner = Instance.new("UICorner")
SpeedCorner.CornerRadius = UDim.new(0, 6)
SpeedCorner.Parent = SpeedBox

local FilenameBox = Instance.new("TextBox")
FilenameBox.Size = UDim2.fromOffset(110, 26)
FilenameBox.Position = UDim2.fromOffset(65, 129)
FilenameBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
FilenameBox.BorderSizePixel = 0
FilenameBox.Text = ""
FilenameBox.PlaceholderText = "Custom File..."
FilenameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
FilenameBox.Font = Enum.Font.GothamBold
FilenameBox.TextSize = 11
FilenameBox.TextXAlignment = Enum.TextXAlignment.Center
FilenameBox.ClearTextOnFocus = false
FilenameBox.Parent = Content

local FilenameCorner = Instance.new("UICorner")
FilenameCorner.CornerRadius = UDim.new(0, 6)
FilenameCorner.Parent = FilenameBox

local WalkSpeedBox = Instance.new("TextBox")
WalkSpeedBox.Size = UDim2.fromOffset(55, 26)
WalkSpeedBox.Position = UDim2.fromOffset(180, 129)
WalkSpeedBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
WalkSpeedBox.BorderSizePixel = 0
WalkSpeedBox.Text = "16"
WalkSpeedBox.PlaceholderText = "8-200"
WalkSpeedBox.TextColor3 = Color3.fromRGB(255, 255, 255)
WalkSpeedBox.Font = Enum.Font.GothamBold
WalkSpeedBox.TextSize = 11
WalkSpeedBox.TextXAlignment = Enum.TextXAlignment.Center
WalkSpeedBox.ClearTextOnFocus = false
WalkSpeedBox.Parent = Content

local WalkSpeedCorner = Instance.new("UICorner")
WalkSpeedCorner.CornerRadius = UDim.new(0, 6)
WalkSpeedCorner.Parent = WalkSpeedBox

local SaveFileBtn = CreateButton("SAVE FILE", 0, 160, 117, 26, Color3.fromRGB(59, 15, 116))
local LoadFileBtn = CreateButton("LOAD FILE", 123, 160, 117, 26, Color3.fromRGB(59, 15, 116))

local PathToggleBtn = CreateButton("SHOW RUTE", 0, 191, 117, 26, Color3.fromRGB(59, 15, 116))
local MergeBtn = CreateButton("MERGE", 123, 191, 117, 26, Color3.fromRGB(59, 15, 116))

local RecordList = Instance.new("ScrollingFrame")
RecordList.Size = UDim2.new(1, 0, 0, 120)
RecordList.Position = UDim2.fromOffset(0, 222)
RecordList.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
RecordList.BorderSizePixel = 0
RecordList.ScrollBarThickness = 6
RecordList.ScrollBarImageColor3 = Color3.fromRGB(80, 120, 255)
RecordList.ScrollingDirection = Enum.ScrollingDirection.Y
RecordList.VerticalScrollBarInset = Enum.ScrollBarInset.Always
RecordList.CanvasSize = UDim2.new(0, 0, 0, 0)
RecordList.Parent = Content

local ListCorner = Instance.new("UICorner")
ListCorner.CornerRadius = UDim.new(0, 6)
ListCorner.Parent = RecordList

-- ========= RECORD LIST FUNCTIONS =========
function UpdateRecordList()
    for _, child in pairs(RecordList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local yPos = 0
    for index, name in ipairs(RecordingOrder) do
        local rec = RecordedMovements[name]
        if not rec then continue end
        
        if SelectedReplays[name] == nil then
            SelectedReplays[name] = false
        end
        
        local item = Instance.new("Frame")
        item.Size = UDim2.new(1, -6, 0, 50)
        item.Position = UDim2.new(0, 3, 0, yPos)
        item.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        item.Parent = RecordList
    
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = item
        
        local actionRow = Instance.new("Frame")
        actionRow.Size = UDim2.new(1, 0, 0, 25)
        actionRow.BackgroundTransparency = 1
        actionRow.Parent = item
        
        local playBtn = Instance.new("TextButton")
        playBtn.Size = UDim2.fromOffset(25, 25)
        playBtn.Position = UDim2.fromOffset(5, 0)
        playBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
        playBtn.Text = "▶"
        playBtn.TextColor3 = Color3.new(1, 1, 1)
        playBtn.Font = Enum.Font.GothamBold
        playBtn.TextSize = 12
        playBtn.Parent = actionRow
        
        local playCorner = Instance.new("UICorner")
        playCorner.CornerRadius = UDim.new(0, 4)
        playCorner.Parent = playBtn
        
        local delBtn = Instance.new("TextButton")
        delBtn.Size = UDim2.fromOffset(25, 25)
        delBtn.Position = UDim2.fromOffset(35, 0)
        delBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
        delBtn.Text = "✕"
        delBtn.TextColor3 = Color3.new(1, 1, 1)
        delBtn.Font = Enum.Font.GothamBold
        delBtn.TextSize = 12
        delBtn.Parent = actionRow
        
        local delCorner = Instance.new("UICorner")
        delCorner.CornerRadius = UDim.new(0, 4)
        delCorner.Parent = delBtn
        
        local nameBox = Instance.new("TextBox")
        nameBox.Size = UDim2.new(0, 100, 0, 25)
        nameBox.Position = UDim2.fromOffset(65, 0)
        nameBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        nameBox.BorderSizePixel = 0
        nameBox.Text = checkpointNames[name] or "checkpoint_" .. index
        nameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameBox.Font = Enum.Font.GothamBold
        nameBox.TextSize = 10
        nameBox.TextXAlignment = Enum.TextXAlignment.Center
        nameBox.PlaceholderText = "Enter name..."
        nameBox.ClearTextOnFocus = false
        nameBox.Parent = actionRow
        
        local nameBoxCorner = Instance.new("UICorner")
        nameBoxCorner.CornerRadius = UDim.new(0, 4)
        nameBoxCorner.Parent = nameBox
        
        local upBtn = Instance.new("TextButton")
        upBtn.Size = UDim2.fromOffset(25, 25)
        upBtn.Position = UDim2.fromOffset(170, 0)
        upBtn.BackgroundColor3 = index > 1 and Color3.fromRGB(74, 195, 147) or Color3.fromRGB(30, 30, 30)
        upBtn.Text = "↑"
        upBtn.TextColor3 = Color3.new(1, 1, 1)
        upBtn.Font = Enum.Font.GothamBold
        upBtn.TextSize = 12
        upBtn.Parent = actionRow
        
        local upCorner = Instance.new("UICorner")
        upCorner.CornerRadius = UDim.new(0, 4)
        upCorner.Parent = upBtn
        
        local downBtn = Instance.new("TextButton")
        downBtn.Size = UDim2.fromOffset(25, 25)
        downBtn.Position = UDim2.fromOffset(200, 0)
        downBtn.BackgroundColor3 = index < #RecordingOrder and Color3.fromRGB(74, 195, 147) or Color3.fromRGB(30, 30, 30)
        downBtn.Text = "↓"
        downBtn.TextColor3 = Color3.new(1, 1, 1)
        downBtn.Font = Enum.Font.GothamBold
        downBtn.TextSize = 12
        downBtn.Parent = actionRow
        
        local downCorner = Instance.new("UICorner")
        downCorner.CornerRadius = UDim.new(0, 4)
        downCorner.Parent = downBtn
        
        local infoRow = Instance.new("Frame")
        infoRow.Size = UDim2.new(1, 0, 0, 20)
        infoRow.Position = UDim2.fromOffset(0, 30)
        infoRow.BackgroundTransparency = 1
        infoRow.Parent = item
        
        local checkbox = Instance.new("TextButton")
        checkbox.Size = UDim2.fromOffset(16, 16)
        checkbox.Position = UDim2.fromOffset(10, 2)
        checkbox.BackgroundColor3 = SelectedReplays[name] and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(40, 40, 50)
        checkbox.Text = SelectedReplays[name] and "✓" or ""
        checkbox.TextColor3 = Color3.new(1, 1, 1)
        checkbox.Font = Enum.Font.GothamBold
        checkbox.TextSize = 10
        checkbox.Parent = infoRow
        
        local checkboxCorner = Instance.new("UICorner")
        checkboxCorner.CornerRadius = UDim.new(0, 3)
        checkboxCorner.Parent = checkbox
        
        local infoLabel = Instance.new("TextLabel")
        infoLabel.Size = UDim2.new(1, -40, 1, 0)
        infoLabel.Position = UDim2.fromOffset(30, 0)
        infoLabel.BackgroundTransparency = 1
        
        local recordingRigType = GetRecordingRigType(rec)
        local rigText = recordingRigType
        if R15TallMode and recordingRigType == "R6" and CurrentRigType == "R15_Tall" then
            rigText = rigText .. " → R15_Tall ✓"
        end
        
        if IsZepetoCharacter then
            rigText = rigText .. " | ZEPETO"
        end
        
        if #rec > 0 then
            local totalSeconds = rec[#rec].Timestamp
            local minutes = math.floor(totalSeconds / 60)
            local seconds = math.floor(totalSeconds % 60)
            infoLabel.Text = "✔️ " .. string.format("%d:%02d", minutes, seconds) .. " • " .. #rec .. " frames • " .. rigText
        else
            infoLabel.Text = "❌ 0:00 • 0 frames • " .. rigText
        end
        
        infoLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
        infoLabel.Font = Enum.Font.GothamBold
        infoLabel.TextSize = 8
        infoLabel.TextXAlignment = Enum.TextXAlignment.Left
        infoLabel.Parent = infoRow
        
        checkbox.MouseButton1Click:Connect(function()
            SelectedReplays[name] = not SelectedReplays[name]
            checkbox.BackgroundColor3 = SelectedReplays[name] and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(40, 40, 50)
            checkbox.Text = SelectedReplays[name] and "✓" or ""
        end)
        
        upBtn.MouseButton1Click:Connect(function()
            if index > 1 then 
                local temp = RecordingOrder[index]
                RecordingOrder[index] = RecordingOrder[index - 1]
                RecordingOrder[index - 1] = temp
                UpdateRecordList()
            end
        end)
        
        downBtn.MouseButton1Click:Connect(function()
            if index < #RecordingOrder then 
                local temp = RecordingOrder[index]
                RecordingOrder[index] = RecordingOrder[index + 1]
                RecordingOrder[index + 1] = temp
                UpdateRecordList()
            end
        end)
        
        playBtn.MouseButton1Click:Connect(function()
            if not IsPlaying then 
                PlayRecording(name)
            end
        end)
        
        delBtn.MouseButton1Click:Connect(function()
            RecordedMovements[name] = nil
            checkpointNames[name] = nil
            SelectedReplays[name] = nil
            local idx = table.find(RecordingOrder, name)
            if idx then table.remove(RecordingOrder, idx) end
            UpdateRecordList()
        end)
        
        nameBox.FocusLost:Connect(function()
            local newName = nameBox.Text
            if newName and newName ~= "" then
                checkpointNames[name] = newName
            end
        end)
        
        yPos = yPos + 53
    end
    
    RecordList.CanvasSize = UDim2.new(0, 0, 0, math.max(yPos, RecordList.AbsoluteSize.Y))
end

-- ========= BUTTON EVENT HANDLERS =========
RecordBtnBig.MouseButton1Click:Connect(function()
    if IsRecording then 
        StopRecording() 
    else 
        StartRecording() 
    end
end)

PlayBtnBig.MouseButton1Click:Connect(function()
    if AutoLoop then return end
    PlayRecording()
end)

StopBtnBig.MouseButton1Click:Connect(function()
    StopPlayback()
end)

PauseBtnBig.MouseButton1Click:Connect(function()
    PausePlayback()
end)

LoopBtn.MouseButton1Click:Connect(function()
    AutoLoop = not AutoLoop
    AnimateLoop(AutoLoop)
    
    if AutoLoop then
        for _, name in ipairs(RecordingOrder) do
            if RecordedMovements[name] and #RecordedMovements[name] > 0 then
                SelectedReplays[name] = true
            end
        end
        
        UpdateRecordList()
        
        if IsPlaying then
            IsPlaying = false
            IsPaused = false
            RestoreFullUserControl()
        end
        
        EnhancedAutoLoopPlayback()
    else
        StopAutoLoopAll()
    end
end)

ShiftLockBtn.MouseButton1Click:Connect(function()
    AnimateShiftLock(false)
end)

RespawnBtn.MouseButton1Click:Connect(function()
    AutoRespawn = not AutoRespawn
    AnimateRespawn(AutoRespawn)
end)

R15TallBtn.MouseButton1Click:Connect(function()
    R15TallMode = not R15TallMode
    AnimateR15Tall(R15TallMode)
    UpdateRecordList()
end)

JumpBtn.MouseButton1Click:Connect(function()
    InfiniteJump = not InfiniteJump
    AnimateJump(InfiniteJump)
end)

HideButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    MiniButton.Visible = true
end)

MiniButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    MiniButton.Visible = false
end)

CloseButton.MouseButton1Click:Connect(function()
    if IsRecording then StopRecording() end
    if IsPlaying or AutoLoop then StopPlayback() end
    CleanupConnections()
    ScreenGui:Destroy()
end)

-- ========= INITIALIZATION =========
UpdateRecordList()

task.spawn(function()
    task.wait(1)
    CurrentRigType = EnhancedRigDetection()
    IsZepetoCharacter = AdvancedZepetoDetection(player.Character)
    
    if IsZepetoCharacter then
        ForceZepetoMode = true
    end
end)

player.CharacterAdded:Connect(function(character)
    task.wait(1)
    CurrentRigType = EnhancedRigDetection(character)
    IsZepetoCharacter = AdvancedZepetoDetection(character)
    
    if IsZepetoCharacter then
        ForceZepetoMode = true
    end
    
    local humanoid = character:WaitForChild("Humanoid", 5)
    if humanoid then
        humanoid.WalkSpeed = CurrentWalkSpeed
        humanoid.JumpPower = GetRigProfile().JumpPower
    end
end)

print("✅ ByaruL AutoWalk v2.3 - RealTime Edition Loaded!")