-- ========================================
-- COMPLETE AUTO WALK RECORDER SYSTEM
-- With Floating Mini GUIs
-- ========================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer

-- ========= EXECUTOR SAFE PARENT =========
local function getParent()
    local success, result = pcall(function()
        if gethui then return gethui() end
        if syn and syn.protect_gui then return CoreGui end
        return CoreGui
    end)
    return success and result or CoreGui
end

local function protectGui(g)
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(g) end
        if protect_gui then protect_gui(g) end
    end)
end

-- ========= CONFIGURATION =========
local RECORDING_FPS = 120
local MAX_FRAMES = 30000
local MIN_DISTANCE_THRESHOLD = 0.01
local VELOCITY_SCALE = 1
local VELOCITY_Y_SCALE = 1
local PLAYBACK_FIXED_TIMESTEP = 1 / 60
local STATE_CHANGE_COOLDOWN = 0.01
local RESUME_DISTANCE_THRESHOLD = 15
local TRANSITION_FRAMES = 5
local TIMELINE_STEP_SECONDS = 0.1

-- ========= FIELD MAPPING FOR OBFUSCATION =========
local FIELD_MAPPING = {
    Position = "11",
    LookVector = "88",
    UpVector = "55",
    Velocity = "22",
    MoveState = "33",
    WalkSpeed = "44",
    Timestamp = "66"
}

local REVERSE_MAPPING = {
    ["11"] = "Position",
    ["88"] = "LookVector",
    ["55"] = "UpVector",
    ["22"] = "Velocity",
    ["33"] = "MoveState",
    ["44"] = "WalkSpeed",
    ["66"] = "Timestamp"
}

-- ========= VARIABLES =========
local IsRecording = false
local IsPlaying = false
local IsPaused = false
local IsTimelineMode = false
local AutoLoop = false
local AutoRespawn = false
local AutoReset = false
local InfiniteJump = false
local ShiftLockEnabled = false
local ShowPaths = false

local CurrentSpeed = 1
local CurrentWalkSpeed = 16
local RecordedMovements = {}
local RecordingOrder = {}
local checkpointNames = {}
local CheckedRecordings = {}
local PathVisualization = {}

local StudioCurrentRecording = {Frames = {}, StartTime = 0, Name = ""}
local CurrentPlayingRecording = nil
local CurrentTimelineFrame = 0
local TimelinePosition = 0
local PausedAtFrame = 0

local lastRecordTime = 0
local lastRecordPos = nil
local playbackStartTime = 0
local totalPausedDuration = 0
local pauseStartTime = 0
local currentPlaybackFrame = 1
local playbackAccumulator = 0

local prePauseHumanoidState = nil
local prePauseWalkSpeed = 16
local prePauseAutoRotate = true
local prePauseJumpPower = 50
local lastPlaybackState = nil
local lastStateChangeTime = 0

local LastPausePosition = nil
local LastPauseRecording = nil
local CurrentPauseMarker = nil

local recordConnection = nil
local playbackConnection = nil
local jumpConnection = nil
local shiftLockConnection = nil
local originalMouseBehavior = nil
local isShiftLockActive = false

local activeConnections = {}

-- ========= FORWARD DECLARATIONS =========
local UpdateRecordList
local PlayRecording
local StopPlayback
local PausePlayback
local StartAutoLoopAll
local SaveHumanoidState
local RestoreHumanoidState
local RestoreFullUserControl
local VisualizeAllPaths
local ClearPathVisualization
local SaveToObfuscatedJSON
local LoadFromObfuscatedJSON

-- ========= UTILITY FUNCTIONS =========
local function AddConnection(connection)
    table.insert(activeConnections, connection)
end

local function CleanupConnections()
    for _, connection in ipairs(activeConnections) do
        if connection then
            pcall(function() connection:Disconnect() end)
        end
    end
    activeConnections = {}
    
    if recordConnection then recordConnection:Disconnect() recordConnection = nil end
    if playbackConnection then playbackConnection:Disconnect() playbackConnection = nil end
    if shiftLockConnection then shiftLockConnection:Disconnect() shiftLockConnection = nil end
    if jumpConnection then jumpConnection:Disconnect() jumpConnection = nil end
end

local function PlaySound(soundType)
    task.spawn(function()
        local sounds = {
            Click = "rbxassetid://4499400560",
            Toggle = "rbxassetid://7468131335",
            RecordStart = "rbxassetid://4499400560",
            RecordStop = "rbxassetid://4499400560",
            Play = "rbxassetid://4499400560",
            Stop = "rbxassetid://4499400560",
            Error = "rbxassetid://7772283448",
            Success = "rbxassetid://2865227271"
        }
        local sound = Instance.new("Sound")
        sound.SoundId = sounds[soundType] or sounds.Click
        sound.Volume = 0.3
        sound.Parent = workspace
        sound:Play()
        game:GetService("Debris"):AddItem(sound, 2)
    end)
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

local function WaitForRespawn()
    local startTime = tick()
    local timeout = 10
    repeat
        task.wait(0.1)
        if tick() - startTime > timeout then return false end
    until player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChildOfClass("Humanoid") and player.Character.Humanoid.Health > 0
    task.wait(1)
    return true
end

local function IsCharacterReady()
    local char = player.Character
    if not char then return false end
    if not char:FindFirstChild("HumanoidRootPart") then return false end
    if not char:FindFirstChildOfClass("Humanoid") then return false end
    if char.Humanoid.Health <= 0 then return false end
    return true
end

local function GetCurrentMoveState(hum, velocity)
    if not hum then return "Grounded" end
    
    local state = hum:GetState()
    local velocityY = velocity and velocity.Y or 0
    
    if state == Enum.HumanoidStateType.Jumping or velocityY > 5 then 
        return "Jumping"
    elseif state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.FallingDown or velocityY < -5 then 
        return "Falling"
    elseif state == Enum.HumanoidStateType.Climbing then 
        return "Climbing"
    elseif state == Enum.HumanoidStateType.Swimming then 
        return "Swimming"
    else 
        return "Grounded" 
    end
end

local function GetFrameCFrame(frame)
    local pos = Vector3.new(frame.Position[1], frame.Position[2], frame.Position[3])
    local look = Vector3.new(frame.LookVector[1], frame.LookVector[2], frame.LookVector[3])
    local up = Vector3.new(frame.UpVector[1], frame.UpVector[2], frame.UpVector[3])
    return CFrame.lookAt(pos, pos + look, up)
end

local function GetFrameVelocity(frame)
    return frame.Velocity and Vector3.new(
        frame.Velocity[1] * VELOCITY_SCALE,
        frame.Velocity[2] * VELOCITY_Y_SCALE,
        frame.Velocity[3] * VELOCITY_SCALE
    ) or Vector3.new(0, 0, 0)
end

local function GetFrameWalkSpeed(frame)
    return frame.WalkSpeed or 16
end

local function GetFrameTimestamp(frame)
    return frame.Timestamp or 0
end

local function GetFramePosition(frame)
    return Vector3.new(frame.Position[1], frame.Position[2], frame.Position[3])
end

local function FindNearestFrame(recording, position)
    if not recording or #recording == 0 then return 1, math.huge end
    local nearestFrame = 1
    local nearestDistance = math.huge
    for i, frame in ipairs(recording) do
        local framePos = GetFramePosition(frame)
        local distance = (framePos - position).Magnitude
        if distance < nearestDistance then
            nearestDistance = distance
            nearestFrame = i
        end
    end
    return nearestFrame, nearestDistance
end

SaveHumanoidState = function()
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

RestoreHumanoidState = function()
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.AutoRotate = prePauseAutoRotate
        humanoid.WalkSpeed = prePauseWalkSpeed
        humanoid.JumpPower = prePauseJumpPower
    end
end

RestoreFullUserControl = function()
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if humanoid then
        humanoid.AutoRotate = true
        humanoid.WalkSpeed = CurrentWalkSpeed
        humanoid.JumpPower = prePauseJumpPower or 50
        humanoid.PlatformStand = false
        humanoid.Sit = false
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end
    if ShiftLockEnabled then
        local camera = workspace.CurrentCamera
        if humanoid and hrp and camera then
            humanoid.AutoRotate = false
        end
    end
end

local function ApplyVisibleShiftLock()
    if not ShiftLockEnabled or not player.Character then return end
    local char = player.Character
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local camera = workspace.CurrentCamera
    if humanoid and hrp and camera then
        humanoid.AutoRotate = false
        local lookVector = camera.CFrame.LookVector
        local horizontalLook = Vector3.new(lookVector.X, 0, lookVector.Z).Unit
        if horizontalLook.Magnitude > 0 then
            hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + horizontalLook)
        end
    end
end

local function EnableVisibleShiftLock()
    if shiftLockConnection or not ShiftLockEnabled then return end
    originalMouseBehavior = UserInputService.MouseBehavior
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    isShiftLockActive = true
    shiftLockConnection = RunService.RenderStepped:Connect(function()
        if ShiftLockEnabled and player.Character then
            ApplyVisibleShiftLock()
        end
    end)
    AddConnection(shiftLockConnection)
    PlaySound("Toggle")
end

local function DisableVisibleShiftLock()
    if shiftLockConnection then
        shiftLockConnection:Disconnect()
        shiftLockConnection = nil
    end
    if originalMouseBehavior then
        UserInputService.MouseBehavior = originalMouseBehavior
    end
    local char = player.Character
    if char and char:FindFirstChildOfClass("Humanoid") then
        char.Humanoid.AutoRotate = true
    end
    isShiftLockActive = false
    PlaySound("Toggle")
end

local function ToggleVisibleShiftLock()
    ShiftLockEnabled = not ShiftLockEnabled
    if ShiftLockEnabled then
        EnableVisibleShiftLock()
    else
        DisableVisibleShiftLock()
    end
end

local function EnableInfiniteJump()
    if jumpConnection then return end
    jumpConnection = UserInputService.JumpRequest:Connect(function()
        if InfiniteJump and player.Character then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end)
    AddConnection(jumpConnection)
end

local function DisableInfiniteJump()
    if jumpConnection then
        jumpConnection:Disconnect()
        jumpConnection = nil
    end
end

local function ToggleInfiniteJump()
    InfiniteJump = not InfiniteJump
    if InfiniteJump then
        EnableInfiniteJump()
    else
        DisableInfiniteJump()
    end
end

ClearPathVisualization = function()
    for _, part in pairs(PathVisualization) do
        if part and part.Parent then
            part:Destroy()
        end
    end
    PathVisualization = {}
    if CurrentPauseMarker and CurrentPauseMarker.Parent then
        CurrentPauseMarker:Destroy()
        CurrentPauseMarker = nil
    end
end

local function CreatePathSegment(startPos, endPos, color)
    local part = Instance.new("Part")
    part.Name = "PathSegment"
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon
    part.BrickColor = color or BrickColor.new("Really black")
    part.Transparency = 0.2
    local distance = (startPos - endPos).Magnitude
    part.Size = Vector3.new(0.2, 0.2, distance)
    part.CFrame = CFrame.lookAt((startPos + endPos) / 2, endPos)
    part.Parent = workspace
    table.insert(PathVisualization, part)
    return part
end

local function CreatePauseMarker(position)
    if CurrentPauseMarker and CurrentPauseMarker.Parent then
        CurrentPauseMarker:Destroy()
        CurrentPauseMarker = nil
    end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PauseMarker"
    billboard.Size = UDim2.new(0, 200, 0, 60)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "PAUSE"
    label.TextColor3 = Color3.new(1, 1, 0)
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBold
    label.TextSize = 18
    label.Parent = billboard
    local part = Instance.new("Part")
    part.Name = "PauseMarkerPart"
    part.Anchored = true
    part.CanCollide = false
    part.Size = Vector3.new(0.1, 0.1, 0.1)
    part.Transparency = 1
    part.Position = position + Vector3.new(0, 2, 0)
    part.Parent = workspace
    billboard.Adornee = part
    billboard.Parent = part
    CurrentPauseMarker = part
    return part
end

local function UpdatePauseMarker()
    if IsPaused then
        if not CurrentPauseMarker then
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local position = char.HumanoidRootPart.Position
                CreatePauseMarker(position)
            end
        end
    else
        if CurrentPauseMarker and CurrentPauseMarker.Parent then
            CurrentPauseMarker:Destroy()
            CurrentPauseMarker = nil
        end
    end
end

local function ObfuscateRecordingData(recordingData)
    local obfuscated = {}
    for checkpointName, frames in pairs(recordingData) do
        local obfuscatedFrames = {}
        for _, frame in ipairs(frames) do
            local obfuscatedFrame = {}
            for fieldName, fieldValue in pairs(frame) do
                local code = FIELD_MAPPING[fieldName]
                if code then
                    obfuscatedFrame[code] = fieldValue
                else
                    obfuscatedFrame[fieldName] = fieldValue
                end
            end
            table.insert(obfuscatedFrames, obfuscatedFrame)
        end
        obfuscated[checkpointName] = obfuscatedFrames
    end
    return obfuscated
end

local function DeobfuscateRecordingData(obfuscatedData)
    local deobfuscated = {}
    for checkpointName, frames in pairs(obfuscatedData) do
        local deobfuscatedFrames = {}
        for _, frame in ipairs(frames) do
            local deobfuscatedFrame = {}
            for code, fieldValue in pairs(frame) do
                local fieldName = REVERSE_MAPPING[code]
                if fieldName then
                    deobfuscatedFrame[fieldName] = fieldValue
                else
                    deobfuscatedFrame[code] = fieldValue
                end
            end
            table.insert(deobfuscatedFrames, deobfuscatedFrame)
        end
        deobfuscated[checkpointName] = deobfuscatedFrames
    end
    return deobfuscated
end

local function EliminateTimeGaps(recording)
    if #recording < 2 then return recording end
    
    local cleanedFrames = {recording[1]}
    local expectedInterval = 1 / RECORDING_FPS
    local toleranceMultiplier = 2.5
    
    for i = 2, #recording do
        local currentFrame = recording[i]
        local previousFrame = cleanedFrames[#cleanedFrames]
        
        local timeDiff = currentFrame.Timestamp - previousFrame.Timestamp
        
        if timeDiff > expectedInterval * toleranceMultiplier then
            local gapFrames = math.floor(timeDiff / expectedInterval) - 1
            
            for j = 1, gapFrames do
                local alpha = j / (gapFrames + 1)
                
                local interpolatedFrame = {
                    Position = {
                        previousFrame.Position[1] + (currentFrame.Position[1] - previousFrame.Position[1]) * alpha,
                        previousFrame.Position[2] + (currentFrame.Position[2] - previousFrame.Position[2]) * alpha,
                        previousFrame.Position[3] + (currentFrame.Position[3] - previousFrame.Position[3]) * alpha
                    },
                    LookVector = currentFrame.LookVector,
                    UpVector = currentFrame.UpVector,
                    Velocity = {
                        previousFrame.Velocity[1] + (currentFrame.Velocity[1] - previousFrame.Velocity[1]) * alpha,
                        previousFrame.Velocity[2] + (currentFrame.Velocity[2] - previousFrame.Velocity[2]) * alpha,
                        previousFrame.Velocity[3] + (currentFrame.Velocity[3] - previousFrame.Velocity[3]) * alpha
                    },
                    MoveState = currentFrame.MoveState,
                    WalkSpeed = currentFrame.WalkSpeed,
                    Timestamp = previousFrame.Timestamp + (expectedInterval * j)
                }
                
                table.insert(cleanedFrames, interpolatedFrame)
            end
        end
        
        local expectedTimestamp = cleanedFrames[#cleanedFrames].Timestamp + expectedInterval
        currentFrame.Timestamp = expectedTimestamp
        
        table.insert(cleanedFrames, currentFrame)
    end
    
    return cleanedFrames
end

local function CreateContinuousTimeline(frames)
    if not frames or #frames == 0 then return {} end
    
    local continuousFrames = {}
    local currentTimestamp = 0
    local expectedInterval = 1 / RECORDING_FPS
    
    for i, frame in ipairs(frames) do
        local normalizedFrame = {
            Position = frame.Position,
            LookVector = frame.LookVector,
            UpVector = frame.UpVector,
            Velocity = frame.Velocity,
            MoveState = frame.MoveState,
            WalkSpeed = frame.WalkSpeed,
            Timestamp = currentTimestamp
        }
        
        table.insert(continuousFrames, normalizedFrame)
        currentTimestamp = currentTimestamp + expectedInterval
    end
    
    return continuousFrames
end

local function CreateSmoothTransition(lastFrame, firstFrame, numFrames)
    local transitionFrames = {}
    for i = 1, numFrames do
        local alpha = i / (numFrames + 1)
        local pos1 = Vector3.new(lastFrame.Position[1], lastFrame.Position[2], lastFrame.Position[3])
        local pos2 = Vector3.new(firstFrame.Position[1], firstFrame.Position[2], firstFrame.Position[3])
        local lerpedPos = pos1:Lerp(pos2, alpha)
        
        local look1 = Vector3.new(lastFrame.LookVector[1], lastFrame.LookVector[2], lastFrame.LookVector[3])
        local look2 = Vector3.new(firstFrame.LookVector[1], firstFrame.LookVector[2], firstFrame.LookVector[3])
        local lerpedLook = look1:Lerp(look2, alpha).Unit
        
        local up1 = Vector3.new(lastFrame.UpVector[1], lastFrame.UpVector[2], lastFrame.UpVector[3])
        local up2 = Vector3.new(firstFrame.UpVector[1], firstFrame.UpVector[2], firstFrame.UpVector[3])
        local lerpedUp = up1:Lerp(up2, alpha).Unit
        
        local vel1 = Vector3.new(lastFrame.Velocity[1], lastFrame.Velocity[2], lastFrame.Velocity[3])
        local vel2 = Vector3.new(firstFrame.Velocity[1], firstFrame.Velocity[2], firstFrame.Velocity[3])
        local lerpedVel = vel1:Lerp(vel2, alpha)
        
        local ws1 = lastFrame.WalkSpeed
        local ws2 = firstFrame.WalkSpeed
        local lerpedWS = ws1 + (ws2 - ws1) * alpha
        
        table.insert(transitionFrames, {
            Position = {lerpedPos.X, lerpedPos.Y, lerpedPos.Z},
            LookVector = {lerpedLook.X, lerpedLook.Y, lerpedLook.Z},
            UpVector = {lerpedUp.X, lerpedUp.Y, lerpedUp.Z},
            Velocity = {lerpedVel.X, lerpedVel.Y, lerpedVel.Z},
            MoveState = lastFrame.MoveState,
            WalkSpeed = lerpedWS,
            Timestamp = lastFrame.Timestamp + (i * 0.016)
        })
    end
    return transitionFrames
end

local function CreateMergedReplay()
    if #RecordingOrder < 2 then
        PlaySound("Error")
        return
    end
    local mergedFrames = {}
    local totalTimeOffset = 0
    for _, checkpointName in ipairs(RecordingOrder) do
        local checkpoint = RecordedMovements[checkpointName]
        if not checkpoint then continue end
        if #mergedFrames > 0 and #checkpoint > 0 then
            local lastFrame = mergedFrames[#mergedFrames]
            local firstFrame = checkpoint[1]
            local transitionFrames = CreateSmoothTransition(lastFrame, firstFrame, TRANSITION_FRAMES)
            for _, tFrame in ipairs(transitionFrames) do
                tFrame.Timestamp = tFrame.Timestamp + totalTimeOffset
                table.insert(mergedFrames, tFrame)
            end
            totalTimeOffset = totalTimeOffset + (TRANSITION_FRAMES * 0.016)
        end
        for frameIndex, frame in ipairs(checkpoint) do
            local newFrame = {
                Position = {frame.Position[1], frame.Position[2], frame.Position[3]},
                LookVector = {frame.LookVector[1], frame.LookVector[2], frame.LookVector[3]},
                UpVector = {frame.UpVector[1], frame.UpVector[2], frame.UpVector[3]},
                Velocity = {frame.Velocity[1], frame.Velocity[2], frame.Velocity[3]},
                MoveState = frame.MoveState,
                WalkSpeed = frame.WalkSpeed,
                Timestamp = frame.Timestamp + totalTimeOffset
            }
            table.insert(mergedFrames, newFrame)
        end
        if #checkpoint > 0 then
            totalTimeOffset = totalTimeOffset + checkpoint[#checkpoint].Timestamp + 0.1
        end
    end
    
    local mergedName = "merged_" .. os.date("%H%M%S")
    RecordedMovements[mergedName] = mergedFrames
    table.insert(RecordingOrder, mergedName)
    checkpointNames[mergedName] = "MERGED ALL"
    UpdateRecordList()
    PlaySound("Success")
end

VisualizeAllPaths = function()
    ClearPathVisualization()
    
    if not ShowPaths then return end
    
    for _, name in ipairs(RecordingOrder) do
        local recording = RecordedMovements[name]
        if not recording or #recording < 2 then continue end
        
        local previousPos = Vector3.new(
            recording[1].Position[1],
            recording[1].Position[2],
            recording[1].Position[3]
        )
        
        for i = 2, #recording, 3 do
            local frame = recording[i]
            local currentPos = Vector3.new(frame.Position[1], frame.Position[2], frame.Position[3])
            
            if (currentPos - previousPos).Magnitude > 0.5 then
                CreatePathSegment(previousPos, currentPos)
                previousPos = currentPos
            end
        end
    end
end

SaveToObfuscatedJSON = function()
    local filename = "MyReplays.json"
    
    local hasCheckedRecordings = false
    for name, checked in pairs(CheckedRecordings) do
        if checked then
            hasCheckedRecordings = true
            break
        end
    end
    
    if not hasCheckedRecordings then
        PlaySound("Error")
        return
    end
    
    local success, err = pcall(function()
        local saveData = {
            Version = "2.1",
            Obfuscated = true,
            Checkpoints = {},
            RecordingOrder = {},
            CheckpointNames = {}
        }
        
        for _, name in ipairs(RecordingOrder) do
            if CheckedRecordings[name] then
                local frames = RecordedMovements[name]
                if frames then
                    local checkpointData = {
                        Name = name,
                        DisplayName = checkpointNames[name] or "checkpoint",
                        Frames = frames
                    }
                    table.insert(saveData.Checkpoints, checkpointData)
                    table.insert(saveData.RecordingOrder, name)
                    saveData.CheckpointNames[name] = checkpointNames[name]
                end
            end
        end
        
        local recordingsToObfuscate = {}
        for _, name in ipairs(saveData.RecordingOrder) do
            recordingsToObfuscate[name] = RecordedMovements[name]
        end
        
        local obfuscatedData = ObfuscateRecordingData(recordingsToObfuscate)
        saveData.ObfuscatedFrames = obfuscatedData
        
        local jsonString = HttpService:JSONEncode(saveData)
        writefile(filename, jsonString)
        PlaySound("Success")
    end)
    
    if not success then
        PlaySound("Error")
    end
end

LoadFromObfuscatedJSON = function()
    local filename = "MyReplays.json"
    
    local success, err = pcall(function()
        if not isfile(filename) then
            PlaySound("Error")
            return
        end
        
        local jsonString = readfile(filename)
        local saveData = HttpService:JSONDecode(jsonString)
        
        RecordedMovements = {}
        RecordingOrder = saveData.RecordingOrder or {}
        checkpointNames = saveData.CheckpointNames or {}
        CheckedRecordings = {}
        
        if saveData.Obfuscated and saveData.ObfuscatedFrames then
            local deobfuscatedData = DeobfuscateRecordingData(saveData.ObfuscatedFrames)
            
            for _, checkpointData in ipairs(saveData.Checkpoints or {}) do
                local name = checkpointData.Name
                local frames = deobfuscatedData[name]
                
                if frames then
                    RecordedMovements[name] = frames
                    if not table.find(RecordingOrder, name) then
                        table.insert(RecordingOrder, name)
                    end
                end
            end
        else
            for _, checkpointData in ipairs(saveData.Checkpoints or {}) do
                local name = checkpointData.Name
                local frames = checkpointData.Frames
                
                if frames then
                    RecordedMovements[name] = frames
                    if not table.find(RecordingOrder, name) then
                        table.insert(RecordingOrder, name)
                    end
                end
            end
        end
        
        UpdateRecordList()
        PlaySound("Success")
    end)
    
    if not success then
        PlaySound("Error")
    end
end

-- ========= CORE PLAYBACK FUNCTIONS =========
PlayRecording = function(name)
    if IsPlaying then return end
    
    local recording = name and RecordedMovements[name] or (RecordingOrder[1] and RecordedMovements[RecordingOrder[1]])
    if not recording or #recording == 0 then
        PlaySound("Error")
        return
    end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        PlaySound("Error")
        return
    end

    IsPlaying = true
    IsPaused = false
    CurrentPlayingRecording = recording
    PausedAtFrame = 0
    playbackAccumulator = 0
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local currentPos = hrp.Position
    
    local nearestFrame, distance = FindNearestFrame(recording, currentPos)
    
    if distance <= RESUME_DISTANCE_THRESHOLD then
        currentPlaybackFrame = nearestFrame
        playbackStartTime = tick() - (GetFrameTimestamp(recording[nearestFrame]) / CurrentSpeed)
    else
        currentPlaybackFrame = 1
        playbackStartTime = tick()
        hrp.CFrame = GetFrameCFrame(recording[1])
    end
    
    totalPausedDuration = 0
    pauseStartTime = 0
    lastPlaybackState = nil
    lastStateChangeTime = 0

    SaveHumanoidState()
    PlaySound("Play")

    playbackConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not IsPlaying then
            playbackConnection:Disconnect()
            RestoreFullUserControl()
            UpdatePauseMarker()
            lastPlaybackState = nil
            lastStateChangeTime = 0
            return
        end
        
        if IsPaused then
            if pauseStartTime == 0 then
                pauseStartTime = tick()
                PausedAtFrame = currentPlaybackFrame
                local char = player.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    LastPausePosition = char.HumanoidRootPart.Position
                    LastPauseRecording = recording
                end
                RestoreHumanoidState()
                if ShiftLockEnabled then
                    ApplyVisibleShiftLock()
                end
                UpdatePauseMarker()
            end
            return
        else
            if pauseStartTime > 0 then
                totalPausedDuration = totalPausedDuration + (tick() - pauseStartTime)
                pauseStartTime = 0
                UpdatePauseMarker()
            end
        end

        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            IsPlaying = false
            RestoreFullUserControl()
            UpdatePauseMarker()
            lastPlaybackState = nil
            lastStateChangeTime = 0
            return
        end
        
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then
            IsPlaying = false
            RestoreFullUserControl()
            UpdatePauseMarker()
            lastPlaybackState = nil
            lastStateChangeTime = 0
            return
        end

        playbackAccumulator = playbackAccumulator + deltaTime
        
        while playbackAccumulator >= PLAYBACK_FIXED_TIMESTEP do
            playbackAccumulator = playbackAccumulator - PLAYBACK_FIXED_TIMESTEP
            
            local currentTime = tick()
            local effectiveTime = (currentTime - playbackStartTime - totalPausedDuration) * CurrentSpeed
            
            while currentPlaybackFrame < #recording and GetFrameTimestamp(recording[currentPlaybackFrame + 1]) <= effectiveTime do
                currentPlaybackFrame = currentPlaybackFrame + 1
            end

            if currentPlaybackFrame >= #recording then
                IsPlaying = false
                RestoreFullUserControl()
                PlaySound("Success")
                UpdatePauseMarker()
                lastPlaybackState = nil
                lastStateChangeTime = 0
                return
            end

            local frame = recording[currentPlaybackFrame]
            if not frame then
                IsPlaying = false
                RestoreFullUserControl()
                UpdatePauseMarker()
                lastPlaybackState = nil
                lastStateChangeTime = 0
                return
            end

            task.spawn(function()
                hrp.CFrame = GetFrameCFrame(frame)
                hrp.AssemblyLinearVelocity = GetFrameVelocity(frame)
                
                if hum then
                    hum.WalkSpeed = GetFrameWalkSpeed(frame) * CurrentSpeed
                    hum.AutoRotate = false
                    
                    local moveState = frame.MoveState
                    local stateTime = tick()
                    
                    if moveState == "Jumping" then
                        if lastPlaybackState ~= "Jumping" then
                            hum:ChangeState(Enum.HumanoidStateType.Jumping)
                            lastPlaybackState = "Jumping"
                            lastStateChangeTime = stateTime
                        end
                    elseif moveState == "Falling" then
                        if lastPlaybackState ~= "Falling" then
                            hum:ChangeState(Enum.HumanoidStateType.Freefall)
                            lastPlaybackState = "Falling"
                            lastStateChangeTime = stateTime
                        end
                    else
                        if moveState ~= lastPlaybackState and (stateTime - lastStateChangeTime) >= STATE_CHANGE_COOLDOWN then
                            lastPlaybackState = moveState
                            lastStateChangeTime = stateTime
                            
                            if moveState == "Climbing" then
                                hum:ChangeState(Enum.HumanoidStateType.Climbing)
                                hum.PlatformStand = false
                                hum.AutoRotate = false
                            elseif moveState == "Swimming" then
                                hum:ChangeState(Enum.HumanoidStateType.Swimming)
                            else
                                hum:ChangeState(Enum.HumanoidStateType.Running)
                            end
                        end
                    end
                    
                    if ShiftLockEnabled then
                        ApplyVisibleShiftLock()
                    end
                end
            end)
        end
    end)
    
    AddConnection(playbackConnection)
end

StopPlayback = function()
    if AutoLoop then
        AutoLoop = false
    end
    
    if not IsPlaying then return end
    IsPlaying = false
    IsPaused = false
    lastPlaybackState = nil
    lastStateChangeTime = 0
    LastPausePosition = nil
    LastPauseRecording = nil
    RestoreFullUserControl()
    UpdatePauseMarker()
    
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if humanoid then
            humanoid.AutoRotate = true
            humanoid.WalkSpeed = CurrentWalkSpeed
            humanoid.PlatformStand = false
            humanoid.Sit = false
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
    end
    
    PlaySound("Stop")
end

PausePlayback = function()
    if not IsPlaying and not AutoLoop and IsPaused then
        if LastPausePosition and LastPauseRecording then
            local char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then
                PlaySound("Error")
                return
            end
            
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local currentPos = hrp.Position
            
            local nearestFrame, distance = FindNearestFrame(LastPauseRecording, currentPos)
            
            if distance <= RESUME_DISTANCE_THRESHOLD then
                PlayRecording(nil)
            else
                hrp.CFrame = GetFrameCFrame(LastPauseRecording[1])
                task.wait(0.1)
                PlayRecording(nil)
            end
        end
        return
    end
    
    if IsPlaying or AutoLoop then
        IsPaused = not IsPaused
        
        if IsPaused then
            RestoreHumanoidState()
            if ShiftLockEnabled then
                ApplyVisibleShiftLock()
            end
            UpdatePauseMarker()
            PlaySound("Click")
        else
            SaveHumanoidState()
            UpdatePauseMarker()
            PlaySound("Click")
        end
    end
end

StartAutoLoopAll = function()
    if not AutoLoop then return end
    
    if #RecordingOrder == 0 then
        AutoLoop = false
        PlaySound("Error")
        return
    end
    
    PlaySound("Play")
    
    local CurrentLoopIndex = 1
    
    task.spawn(function()
        while AutoLoop do
            if not AutoLoop then break end
            
            local recordingName = RecordingOrder[CurrentLoopIndex]
            local recording = RecordedMovements[recordingName]
            
            if not recording or #recording == 0 then
                CurrentLoopIndex = CurrentLoopIndex + 1
                if CurrentLoopIndex > #RecordingOrder then
                    CurrentLoopIndex = 1
                end
                task.wait(1)
                continue
            end
            
            if not IsCharacterReady() then
                if AutoRespawn then
                    ResetCharacter()
                    local success = WaitForRespawn()
                    if not success then
                        task.wait(2)
                        continue
                    end
                    task.wait(1.5)
                else
                    local waitAttempts = 0
                    local maxWaitAttempts = 60
                    
                    while not IsCharacterReady() and AutoLoop do
                        waitAttempts = waitAttempts + 1
                        
                        if waitAttempts >= maxWaitAttempts then
                            AutoLoop = false
                            PlaySound("Error")
                            break
                        end
                        
                        task.wait(0.5)
                    end
                    
                    if not AutoLoop then break end
                    task.wait(1.0)
                end
            end
            
            if not AutoLoop then break end
            
            PlayRecording(recordingName)
            
            while IsPlaying and AutoLoop do
                task.wait(0.1)
            end
            
            if not AutoLoop then break end
            
            CurrentLoopIndex = CurrentLoopIndex + 1
            if CurrentLoopIndex > #RecordingOrder then
                CurrentLoopIndex = 1
            end
            
            task.wait(0.5)
        end
        
        RestoreFullUserControl()
        UpdatePauseMarker()
        lastPlaybackState = nil
        lastStateChangeTime = 0
    end)
end

-- ========= RECORDING FUNCTIONS =========
local function ApplyFrameToCharacter(frame)
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    
    if not hrp or not hum then return end
    
    task.spawn(function()
        local targetCFrame = GetFrameCFrame(frame)
        hrp.CFrame = targetCFrame
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        
        if hum then
            hum.WalkSpeed = 0
            hum.AutoRotate = false
            
            local moveState = frame.MoveState
            if moveState == "Climbing" then
                hum:ChangeState(Enum.HumanoidStateType.Climbing)
                hum.PlatformStand = false
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
    end)
end

local function StartStudioRecording()
    if IsRecording then return end
    
    task.spawn(function()
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            PlaySound("Error")
            return
        end
        
        IsRecording = true
        IsTimelineMode = false
        StudioCurrentRecording = {Frames = {}, StartTime = tick(), Name = "recording_" .. os.date("%H%M%S")}
        lastRecordTime = 0
        lastRecordPos = nil
        CurrentTimelineFrame = 0
        TimelinePosition = 0
        
        PlaySound("RecordStart")
        
        recordConnection = RunService.Heartbeat:Connect(function()
            task.spawn(function()
                local char = player.Character
                if not char or not char:FindFirstChild("HumanoidRootPart") or #StudioCurrentRecording.Frames >= MAX_FRAMES then
                    return
                end
                
                local hrp = char.HumanoidRootPart
                local hum = char:FindFirstChildOfClass("Humanoid")
                
                if IsTimelineMode then
                    return
                end
                
                local now = tick()
                if (now - lastRecordTime) < (1 / RECORDING_FPS) then return end
                
                local currentPos = hrp.Position
                local currentVelocity = hrp.AssemblyLinearVelocity
                
                if lastRecordPos and (currentPos - lastRecordPos).Magnitude < MIN_DISTANCE_THRESHOLD then
                    lastRecordTime = now
                    return
                end
                
                local cf = hrp.CFrame
                table.insert(StudioCurrentRecording.Frames, {
                    Position = {cf.Position.X, cf.Position.Y, cf.Position.Z},
                    LookVector = {cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z},
                    UpVector = {cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z},
                    Velocity = {currentVelocity.X, currentVelocity.Y, currentVelocity.Z},
                    MoveState = GetCurrentMoveState(hum, currentVelocity),
                    WalkSpeed = hum and hum.WalkSpeed or 16,
                    Timestamp = now - StudioCurrentRecording.StartTime
                })
                
                lastRecordTime = now
                lastRecordPos = currentPos
                CurrentTimelineFrame = #StudioCurrentRecording.Frames
                TimelinePosition = CurrentTimelineFrame
            end)
        end)
    end)
end

local function StopStudioRecording()
    IsRecording = false
    IsTimelineMode = false
    
    task.spawn(function()
        if recordConnection then
            recordConnection:Disconnect()
            recordConnection = nil
        end
        
        PlaySound("RecordStop")
    end)
end

local function GoBackTimeline()
    if not IsRecording or #StudioCurrentRecording.Frames == 0 then
        PlaySound("Error")
        return
    end
    
    task.spawn(function()
        IsTimelineMode = true
        
        local targetFrame = math.max(1, TimelinePosition - math.floor(RECORDING_FPS * TIMELINE_STEP_SECONDS))
        
        TimelinePosition = targetFrame
        CurrentTimelineFrame = targetFrame
        
        local frame = StudioCurrentRecording.Frames[targetFrame]
        if frame then
            ApplyFrameToCharacter(frame)
            PlaySound("Click")
        end
    end)
end

local function GoNextTimeline()
    if not IsRecording or #StudioCurrentRecording.Frames == 0 then
        PlaySound("Error")
        return
    end
    
    task.spawn(function()
        IsTimelineMode = true
        
        local targetFrame = math.min(#StudioCurrentRecording.Frames, TimelinePosition + math.floor(RECORDING_FPS * TIMELINE_STEP_SECONDS))
        
        TimelinePosition = targetFrame
        CurrentTimelineFrame = targetFrame
        
        local frame = StudioCurrentRecording.Frames[targetFrame]
        if frame then
            ApplyFrameToCharacter(frame)
            PlaySound("Click")
        end
    end)
end

local function SaveStudioRecording()
    task.spawn(function()
        if #StudioCurrentRecording.Frames == 0 then
            PlaySound("Error")
            return
        end
        
        if IsRecording then
            StopStudioRecording()
        end
        
        local processedFrames = EliminateTimeGaps(StudioCurrentRecording.Frames)
        processedFrames = CreateContinuousTimeline(processedFrames)
        
        RecordedMovements[StudioCurrentRecording.Name] = processedFrames
        table.insert(RecordingOrder, StudioCurrentRecording.Name)
        checkpointNames[StudioCurrentRecording.Name] = "checkpoint_" .. #RecordingOrder
        UpdateRecordList()
        
        PlaySound("Success")
        
        StudioCurrentRecording = {Frames = {}, StartTime = 0, Name = "recording_" .. os.date("%H%M%S")}
        IsTimelineMode = false
        CurrentTimelineFrame = 0
        TimelinePosition = 0
    end)
end

-- ========= MAIN GUI SETUP =========
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoWalkByaruL"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
protectGui(ScreenGui)
ScreenGui.Parent = getParent()

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.fromOffset(250, 400)
MainFrame.Position = UDim2.new(0.5, -125, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 28)
Header.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 12)
HeaderCorner.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 1, 0)
Title.BackgroundTransparency = 1
Title.Text = "ByaruL Recorder"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.Parent = Header

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.fromOffset(22, 22)
CloseButton.Position = UDim2.new(1, -25, 0.5, -11)
CloseButton.BackgroundColor3 = Color3.fromRGB(230, 62, 62)
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.new(1, 1, 1)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 10
CloseButton.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseButton

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -16, 1, -36)
Content.Position = UDim2.new(0, 8, 0, 32)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

local function CreateToggle(name, text, yPos, defaultState)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(0.48, 0, 0, 30)
    btn.Position = UDim2.new(0, 0, 0, yPos)
    btn.BackgroundColor3 = defaultState and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(50, 50, 50)
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Parent = Content
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    
    return btn
end

local LoopToggle = CreateToggle("LoopToggle", "AutoLoop", 0, false)
LoopToggle.Position = UDim2.new(0, 0, 0, 0)

local RespawnToggle = CreateToggle("RespawnToggle", "AutoRespawn", 0, false)
RespawnToggle.Position = UDim2.new(0.52, 0, 0, 0)

local ShiftLockToggle = CreateToggle("ShiftLockToggle", "ShiftLock", 35, false)
ShiftLockToggle.Position = UDim2.new(0, 0, 0, 35)

local JumpToggle = CreateToggle("JumpToggle", "InfJump", 35, false)
JumpToggle.Position = UDim2.new(0.52, 0, 0, 35)

local PathToggle = CreateToggle("PathToggle", "Show Path", 70, false)
PathToggle.Position = UDim2.new(0, 0, 0, 70)

local SpeedBox = Instance.new("TextBox")
SpeedBox.Size = UDim2.new(0.48, 0, 0, 30)
SpeedBox.Position = UDim2.new(0.52, 0, 0, 70)
SpeedBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
SpeedBox.BorderSizePixel = 0
SpeedBox.Text = "1.00"
SpeedBox.PlaceholderText = "Speed"
SpeedBox.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedBox.Font = Enum.Font.GothamBold
SpeedBox.TextSize = 10
SpeedBox.Parent = Content

local SpeedCorner = Instance.new("UICorner")
SpeedCorner.CornerRadius = UDim.new(0, 6)
SpeedCorner.Parent = SpeedBox

local function CreateButton(text, yPos, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.Position = UDim2.new(0, 0, 0, yPos)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Parent = Content
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    
    return btn
end

local SaveBtn = CreateButton("SAVE FILE", 105, Color3.fromRGB(19, 137, 79))
local LoadBtn = CreateButton("LOAD FILE", 142, Color3.fromRGB(19, 137, 79))
local MergeBtn = CreateButton("MERGE ALL", 179, Color3.fromRGB(19, 137, 79))

local RecordList = Instance.new("ScrollingFrame")
RecordList.Size = UDim2.new(1, 0, 0, 180)
RecordList.Position = UDim2.fromOffset(0, 216)
RecordList.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
RecordList.BorderSizePixel = 0
RecordList.ScrollBarThickness = 4
RecordList.ScrollBarImageColor3 = Color3.fromRGB(80, 120, 255)
RecordList.CanvasSize = UDim2.new(0, 0, 0, 0)
RecordList.Parent = Content

local ListCorner = Instance.new("UICorner")
ListCorner.CornerRadius = UDim.new(0, 6)
ListCorner.Parent = RecordList

local function FormatDuration(seconds)
    local minutes = math.floor(seconds / 60)
    local remainingSeconds = math.floor(seconds % 60)
    return string.format("%d:%02d", minutes, remainingSeconds)
end

UpdateRecordList = function()
    for _, child in pairs(RecordList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local yPos = 0
    for index, name in ipairs(RecordingOrder) do
        local rec = RecordedMovements[name]
        if not rec then continue end
        
        local item = Instance.new("Frame")
        item.Size = UDim2.new(1, -4, 0, 40)
        item.Position = UDim2.new(0, 2, 0, yPos)
        item.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
        item.Parent = RecordList
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = item
        
        local checkBox = Instance.new("TextButton")
        checkBox.Size = UDim2.fromOffset(16, 16)
        checkBox.Position = UDim2.fromOffset(3, 3)
        checkBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        checkBox.Text = CheckedRecordings[name] and "✓" or ""
        checkBox.TextColor3 = Color3.fromRGB(100, 255, 150)
        checkBox.Font = Enum.Font.GothamBold
        checkBox.TextSize = 11
        checkBox.Parent = item
        
        local checkCorner = Instance.new("UICorner")
        checkCorner.CornerRadius = UDim.new(0, 3)
        checkCorner.Parent = checkBox
        
        local infoLabel = Instance.new("TextLabel")
        infoLabel.Size = UDim2.new(0, 180, 0, 16)
        infoLabel.Position = UDim2.fromOffset(22, 3)
        infoLabel.BackgroundTransparency = 1
        if #rec > 0 then
            local totalSeconds = rec[#rec].Timestamp
            infoLabel.Text = FormatDuration(totalSeconds) .. " • " .. #rec .. " frames"
        else
            infoLabel.Text = "0:00 • 0 frames"
        end
        infoLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
        infoLabel.Font = Enum.Font.GothamBold
        infoLabel.TextSize = 7
        infoLabel.TextXAlignment = Enum.TextXAlignment.Left
        infoLabel.Parent = item
        
        local playBtn = Instance.new("TextButton")
        playBtn.Size = UDim2.fromOffset(26, 16)
        playBtn.Position = UDim2.fromOffset(3, 21)
        playBtn.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
        playBtn.Text = "▶"
        playBtn.TextColor3 = Color3.new(1, 1, 1)
        playBtn.Font = Enum.Font.GothamBold
        playBtn.TextSize = 14
        playBtn.Parent = item
        
        local playCorner = Instance.new("UICorner")
        playCorner.CornerRadius = UDim.new(0, 4)
        playCorner.Parent = playBtn
        
        local delBtn = Instance.new("TextButton")
        delBtn.Size = UDim2.fromOffset(26, 16)
        delBtn.Position = UDim2.fromOffset(32, 21)
        delBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
        delBtn.Text = "🗑"
        delBtn.TextColor3 = Color3.new(1, 1, 1)
        delBtn.Font = Enum.Font.GothamBold
        delBtn.TextSize = 8
        delBtn.Parent = item
        
        local delCorner = Instance.new("UICorner")
        delCorner.CornerRadius = UDim.new(0, 4)
        delCorner.Parent = delBtn
        
        local nameBox = Instance.new("TextBox")
        nameBox.Size = UDim2.new(0, 150, 0, 16)
        nameBox.Position = UDim2.fromOffset(61, 21)
        nameBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        nameBox.BorderSizePixel = 0
        nameBox.Text = checkpointNames[name] or "Checkpoint1"
        nameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameBox.Font = Enum.Font.GothamBold
        nameBox.TextSize = 7
        nameBox.TextXAlignment = Enum.TextXAlignment.Center
        nameBox.PlaceholderText = "Name"
        nameBox.ClearTextOnFocus = false
        nameBox.Parent = item
        
        local nameBoxCorner = Instance.new("UICorner")
        nameBoxCorner.CornerRadius = UDim.new(0, 3)
        nameBoxCorner.Parent = nameBox
        
        checkBox.MouseButton1Click:Connect(function()
            CheckedRecordings[name] = not CheckedRecordings[name]
            checkBox.Text = CheckedRecordings[name] and "✓" or ""
            PlaySound("Click")
        end)
        
        playBtn.MouseButton1Click:Connect(function()
            if not IsPlaying then
                PlaySound("Click")
                PlayRecording(name)
            end
        end)
        
        delBtn.MouseButton1Click:Connect(function()
            PlaySound("Click")
            RecordedMovements[name] = nil
            checkpointNames[name] = nil
            CheckedRecordings[name] = nil
            local idx = table.find(RecordingOrder, name)
            if idx then table.remove(RecordingOrder, idx) end
            UpdateRecordList()
        end)
        
        nameBox.FocusLost:Connect(function()
            local newName = nameBox.Text
            if newName and newName ~= "" then
                checkpointNames[name] = newName
                PlaySound("Success")
            end
        end)
        
        yPos = yPos + 43
    end
    
    RecordList.CanvasSize = UDim2.new(0, 0, 0, math.max(yPos, RecordList.AbsoluteSize.Y))
end

-- ========= TOGGLE CONNECTIONS =========
LoopToggle.MouseButton1Click:Connect(function()
    AutoLoop = not AutoLoop
    LoopToggle.BackgroundColor3 = AutoLoop and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(50, 50, 50)
    PlaySound("Toggle")
    
    if AutoLoop then
        if not next(RecordedMovements) then
            AutoLoop = false
            LoopToggle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            return
        end
        
        if IsPlaying then
            IsPlaying = false
            IsPaused = false
            RestoreFullUserControl()
        end
        
        StartAutoLoopAll()
    else
        StopPlayback()
    end
end)

RespawnToggle.MouseButton1Click:Connect(function()
    AutoRespawn = not AutoRespawn
    RespawnToggle.BackgroundColor3 = AutoRespawn and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(50, 50, 50)
    PlaySound("Toggle")
end)

ShiftLockToggle.MouseButton1Click:Connect(function()
    ToggleVisibleShiftLock()
    ShiftLockToggle.BackgroundColor3 = ShiftLockEnabled and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(50, 50, 50)
end)

JumpToggle.MouseButton1Click:Connect(function()
    ToggleInfiniteJump()
    JumpToggle.BackgroundColor3 = InfiniteJump and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(50, 50, 50)
end)

PathToggle.MouseButton1Click:Connect(function()
    ShowPaths = not ShowPaths
    PathToggle.BackgroundColor3 = ShowPaths and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(50, 50, 50)
    PlaySound("Toggle")
    if ShowPaths then
        VisualizeAllPaths()
    else
        ClearPathVisualization()
    end
end)

SpeedBox.FocusLost:Connect(function()
    local speed = tonumber(SpeedBox.Text)
    if speed and speed >= 0.25 and speed <= 30 then
        CurrentSpeed = speed
        SpeedBox.Text = string.format("%.2f", speed)
        PlaySound("Success")
    else
        SpeedBox.Text = string.format("%.2f", CurrentSpeed)
        PlaySound("Error")
    end
end)

SaveBtn.MouseButton1Click:Connect(function()
    PlaySound("Click")
    SaveToObfuscatedJSON()
end)

LoadBtn.MouseButton1Click:Connect(function()
    PlaySound("Click")
    LoadFromObfuscatedJSON()
end)

MergeBtn.MouseButton1Click:Connect(function()
    PlaySound("Click")
    CreateMergedReplay()
end)

CloseButton.MouseButton1Click:Connect(function()
    PlaySound("Click")
    if IsRecording then StopStudioRecording() end
    if IsPlaying or AutoLoop then StopPlayback() end
    if ShiftLockEnabled then DisableVisibleShiftLock() end
    if InfiniteJump then DisableInfiniteJump() end
    CleanupConnections()
    ClearPathVisualization()
    ScreenGui:Destroy()
end)

-- ========= FLOATING RECORDER GUI =========
local Camera = workspace.CurrentCamera

local function clampToViewport(pos, size)
    local vs = Camera and Camera.ViewportSize or Vector2.new(1920, 1080)
    local x = math.clamp(pos.X.Offset, 0, vs.X - size.X)
    local y = math.clamp(pos.Y.Offset, 0, vs.Y - size.Y)
    return UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
end

local function setIcon(btn, emoji, fallback)
    btn.Text = emoji
    btn.Font = Enum.Font.GothamBold
    btn.TextScaled = true
    btn.TextWrapped = true
    btn.TextColor3 = Color3.fromRGB(235, 235, 240)
    task.defer(function()
        local b = btn.TextBounds
        if (b.X < 4 or b.Y < 4) then
            btn.Text = fallback
        end
    end)
end

local function makeButton(name)
    local b = Instance.new("TextButton")
    b.Name = name
    b.Size = UDim2.fromOffset(40, 40)
    b.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
    b.AutoButtonColor = true
    local cr = Instance.new("UICorner", b)
    cr.CornerRadius = UDim.new(0, 10)
    local st = Instance.new("UIStroke", b)
    st.Thickness = 1
    st.Color = Color3.fromRGB(70, 70, 78)
    return b
end

local RecorderPanel = Instance.new("Frame")
RecorderPanel.Name = "RecorderPanel"
RecorderPanel.Size = UDim2.fromOffset(160, 100)
RecorderPanel.Position = UDim2.fromOffset(80, 220)
RecorderPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
RecorderPanel.BackgroundTransparency = 0.15
RecorderPanel.Active = true
RecorderPanel.Parent = ScreenGui

local pc = Instance.new("UICorner", RecorderPanel)
pc.CornerRadius = UDim.new(0, 14)
local ps = Instance.new("UIStroke", RecorderPanel)
ps.Thickness = 1
ps.Color = Color3.fromRGB(60, 60, 68)

local wrap = Instance.new("Frame", RecorderPanel)
wrap.BackgroundTransparency = 1
wrap.Size = UDim2.fromScale(1, 1)
local pad = Instance.new("UIPadding", wrap)
pad.PaddingTop = UDim.new(0, 6)
pad.PaddingBottom = UDim.new(0, 6)
pad.PaddingLeft = UDim.new(0, 8)
pad.PaddingRight = UDim.new(0, 8)

local vlist = Instance.new("UIListLayout", wrap)
vlist.FillDirection = Enum.FillDirection.Vertical
vlist.Padding = UDim.new(0, 8)
vlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
vlist.VerticalAlignment = Enum.VerticalAlignment.Center

local function row()
    local r = Instance.new("Frame")
    r.BackgroundTransparency = 1
    r.Size = UDim2.new(1, 0, 0, 40)
    r.Parent = wrap
    local h = Instance.new("UIListLayout", r)
    h.FillDirection = Enum.FillDirection.Horizontal
    h.Padding = UDim.new(0, 8)
    h.HorizontalAlignment = Enum.HorizontalAlignment.Center
    h.VerticalAlignment = Enum.VerticalAlignment.Center
    return r
end

local rowTop = row()
local rowBottom = row()

local btnSave = makeButton("Save")
btnSave.Parent = rowTop
local btnRec = makeButton("Rec")
btnRec.Parent = rowTop
local btnPrev = makeButton("Prev")
btnPrev.Parent = rowBottom
local btnPause = makeButton("Pause")
btnPause.Parent = rowBottom
local btnNext = makeButton("Next")
btnNext.Parent = rowBottom

setIcon(btnSave, "💾", "S")
setIcon(btnRec, "🎦", "R")
setIcon(btnPrev, "⏪", "<<")
setIcon(btnPause, "⏸", "||")
setIcon(btnNext, "⏩", ">>")

do
    local dragging = false
    local dragStart, startPos
    local function IBegan(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = i.Position
            startPos = RecorderPanel.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    RecorderPanel.Position = clampToViewport(RecorderPanel.Position, RecorderPanel.AbsoluteSize)
                end
            end)
        end
    end
    local function IChanged(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            RecorderPanel.Position = clampToViewport(UDim2.fromOffset(startPos.X.Offset + d.X, startPos.Y.Offset + d.Y), RecorderPanel.AbsoluteSize)
        end
    end
    RecorderPanel.InputBegan:Connect(IBegan)
    RecorderPanel.InputChanged:Connect(IChanged)
    UserInputService.InputChanged:Connect(IChanged)
end

btnSave.MouseButton1Click:Connect(function()
    PlaySound("Click")
    btnSave.TextTransparency = 0.25
    task.delay(0.2, function() btnSave.TextTransparency = 0 end)
    SaveStudioRecording()
end)

btnRec.MouseButton1Click:Connect(function()
    if IsRecording then
        setIcon(btnRec, "🎦", "R")
        StopStudioRecording()
    else
        setIcon(btnRec, "⏹", "■")
        StartStudioRecording()
    end
    PlaySound("Click")
end)

btnPrev.MouseButton1Click:Connect(function()
    PlaySound("Click")
    GoBackTimeline()
end)

btnPause.MouseButton1Click:Connect(function()
    PlaySound("Click")
    if IsRecording and not IsTimelineMode then
        IsTimelineMode = true
        local char = player.Character
        if char and char:FindFirstChildOfClass("Humanoid") then
            char.Humanoid.WalkSpeed = 0
        end
    elseif IsRecording and IsTimelineMode then
        IsTimelineMode = false
        local char = player.Character
        if char and char:FindFirstChildOfClass("Humanoid") then
            char.Humanoid.WalkSpeed = CurrentWalkSpeed
        end
    end
end)

btnNext.MouseButton1Click:Connect(function()
    PlaySound("Click")
    GoNextTimeline()
end)

RecorderPanel.Position = clampToViewport(RecorderPanel.Position, RecorderPanel.AbsoluteSize)

-- ========= FLOATING PLAYBACK GUI =========
local PlaybackPanel = Instance.new("Frame")
PlaybackPanel.Name = "PlaybackPanel"
PlaybackPanel.Size = UDim2.fromOffset(160, 60)
PlaybackPanel.Position = UDim2.fromOffset(100, 340)
PlaybackPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
PlaybackPanel.BackgroundTransparency = 0.15
PlaybackPanel.Active = true
PlaybackPanel.Parent = ScreenGui

local pc2 = Instance.new("UICorner", PlaybackPanel)
pc2.CornerRadius = UDim.new(0, 14)
local ps2 = Instance.new("UIStroke", PlaybackPanel)
ps2.Thickness = 1
ps2.Color = Color3.fromRGB(60, 60, 68)

local wrap2 = Instance.new("Frame", PlaybackPanel)
wrap2.BackgroundTransparency = 1
wrap2.Size = UDim2.fromScale(1, 1)
local pad2 = Instance.new("UIPadding", wrap2)
pad2.PaddingTop = UDim.new(0, 10)
pad2.PaddingBottom = UDim.new(0, 10)
pad2.PaddingLeft = UDim.new(0, 10)
pad2.PaddingRight = UDim.new(0, 10)

local row2 = Instance.new("Frame", wrap2)
row2.BackgroundTransparency = 1
row2.Size = UDim2.new(1, 0, 1, 0)
local h2 = Instance.new("UIListLayout", row2)
h2.FillDirection = Enum.FillDirection.Horizontal
h2.Padding = UDim.new(0, 12)
h2.HorizontalAlignment = Enum.HorizontalAlignment.Center
h2.VerticalAlignment = Enum.VerticalAlignment.Center

local btnPlay = makeButton("Play")
local btnPlayPause = makeButton("Pause")
btnPlay.Parent = row2
btnPlayPause.Parent = row2

setIcon(btnPlay, "▶️", ">")
setIcon(btnPlayPause, "⏹", "■")

do
    local dragging = false
    local dragStart, startPos
    local function IBegan(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = i.Position
            startPos = PlaybackPanel.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    PlaybackPanel.Position = clampToViewport(PlaybackPanel.Position, PlaybackPanel.AbsoluteSize)
                end
            end)
        end
    end
    local function IChanged(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            PlaybackPanel.Position = clampToViewport(UDim2.fromOffset(startPos.X.Offset + d.X, startPos.Y.Offset + d.Y), PlaybackPanel.AbsoluteSize)
        end
    end
    PlaybackPanel.InputBegan:Connect(IBegan)
    PlaybackPanel.InputChanged:Connect(IChanged)
    UserInputService.InputChanged:Connect(IChanged)
end

btnPlay.MouseButton1Click:Connect(function()
    if IsPlaying or AutoLoop then
        setIcon(btnPlay, "▶️", ">")
        StopPlayback()
    else
        setIcon(btnPlay, "⏹", "■")
        if AutoLoop then
            StartAutoLoopAll()
        else
            PlayRecording()
        end
    end
    PlaySound("Click")
end)

btnPlayPause.MouseButton1Click:Connect(function()
    if IsPaused then
        setIcon(btnPlayPause, "⏹", "■")
        PausePlayback()
    else
        setIcon(btnPlayPause, "⏸", "||")
        PausePlayback()
    end
    PlaySound("Click")
end)

PlaybackPanel.Position = clampToViewport(PlaybackPanel.Position, PlaybackPanel.AbsoluteSize)

-- ========= KEYBINDS =========
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    if input.KeyCode == Enum.KeyCode.F9 then
        if IsRecording then
            StopStudioRecording()
            setIcon(btnRec, "🎦", "R")
        else
            StartStudioRecording()
            setIcon(btnRec, "⏹", "■")
        end
    elseif input.KeyCode == Enum.KeyCode.F10 then
        if IsPlaying or AutoLoop then
            StopPlayback()
            setIcon(btnPlay, "▶️", ">")
        else
            PlayRecording()
            setIcon(btnPlay, "⏹", "■")
        end
    elseif input.KeyCode == Enum.KeyCode.F11 then
        MainFrame.Visible = not MainFrame.Visible
    elseif input.KeyCode == Enum.KeyCode.F8 then
        RecorderPanel.Visible = not RecorderPanel.Visible
    elseif input.KeyCode == Enum.KeyCode.F7 then
        AutoLoop = not AutoLoop
        LoopToggle.BackgroundColor3 = AutoLoop and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(50, 50, 50)
        if AutoLoop then
            StartAutoLoopAll()
        else
            StopPlayback()
        end
    elseif input.KeyCode == Enum.KeyCode.F6 then
        SaveToObfuscatedJSON()
    elseif input.KeyCode == Enum.KeyCode.F5 then
        AutoRespawn = not AutoRespawn
        RespawnToggle.BackgroundColor3 = AutoRespawn and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(50, 50, 50)
    elseif input.KeyCode == Enum.KeyCode.F4 then
        ShowPaths = not ShowPaths
        PathToggle.BackgroundColor3 = ShowPaths and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(50, 50, 50)
        if ShowPaths then
            VisualizeAllPaths()
        else
            ClearPathVisualization()
        end
    elseif input.KeyCode == Enum.KeyCode.F3 then
        ToggleVisibleShiftLock()
        ShiftLockToggle.BackgroundColor3 = ShiftLockEnabled and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(50, 50, 50)
    elseif input.KeyCode == Enum.KeyCode.F2 then
        ToggleInfiniteJump()
        JumpToggle.BackgroundColor3 = InfiniteJump and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(50, 50, 50)
    elseif input.KeyCode == Enum.KeyCode.LeftBracket then
        GoBackTimeline()
    elseif input.KeyCode == Enum.KeyCode.RightBracket then
        GoNextTimeline()
    end
end)

-- ========= INITIALIZE =========
UpdateRecordList()

task.spawn(function()
    task.wait(2)
    if typeof(isfile) == "function" and typeof(readfile) == "function" then
        local filename = "MyReplays.json"
        if isfile(filename) then
            LoadFromObfuscatedJSON()
        end
    end
end)

player.CharacterRemoving:Connect(function()
    if IsRecording then
        StopStudioRecording()
    end
    if IsPlaying or AutoLoop then
        StopPlayback()
    end
end)

game:GetService("ScriptContext").DescendantRemoving:Connect(function(descendant)
    if descendant == ScreenGui then
        CleanupConnections()
        ClearPathVisualization()
    end
end)