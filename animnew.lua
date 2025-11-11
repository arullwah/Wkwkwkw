
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
wait(1)

-- ========= STATE MANAGEMENT =========
local States = {
    IDLE = "idle",
    RECORDING = "recording", 
    PLAYING = "playing",
    PAUSED = "paused",
    TIMELINE = "timeline"
}

local CurrentState = States.IDLE

-- ========= CONFIGURATION =========
local Config = {
    Recording = {
        FPS = 120,
        MaxFrames = 30000,
        MinDistance = 0.001,
        MinVelocityChange = 0.01,
        TimelineStep = 0.1
    },
    Playback = {
        VelocityScale = 1,
        VelocityYScale = 1,
        ReverseSpeed = 2.0,
        ForwardSpeed = 2.0,
        FixedTimestep = 1 / 120,
        ResumeDistance = 15,
        StateChangeCooldown = 0.01,
        TransitionFrames = 3,
        BlendSpeed = 0.3,
        InstantTeleportDistance = 50
    },
    Features = {
        AutoRespawn = false,
        InfiniteJump = false,
        AutoLoop = false,
        ShowPaths = false,
        ShiftLock = false,
        AutoReset = false,
        SmoothPlayback = true
    }
}

-- ========= CORE VARIABLES =========
local RecordedMovements = {}
local RecordingOrder = {}
local CurrentRecording = {Frames = {}, StartTime = 0, Name = ""}
local CurrentSpeed = 1
local CurrentWalkSpeed = 16
local checkpointNames = {}
local CheckedRecordings = {}
local PathVisualization = {}
local CurrentPauseMarker = nil

-- ========= PLAYBACK VARIABLES =========
local playbackStartTime = 0
local totalPausedDuration = 0
local pauseStartTime = 0
local currentPlaybackFrame = 1
local CurrentPlayingRecording = nil
local PausedAtFrame = 0
local playbackAccumulator = 0
local LastPausePosition = nil
local LastPauseRecording = nil
local lastRecordedFrame = nil
local isResuming = false

-- ========= INTERPOLATION VARIABLES =========
local isBlending = false
local blendStartTime = 0
local blendDuration = 0
local blendStartCFrame = nil
local blendStartVelocity = nil

-- ========= TIMELINE VARIABLES =========
local CurrentTimelineFrame = 0
local TimelinePosition = 0

-- ========= CHARACTER STATE =========
local prePauseHumanoidState = nil
local prePauseWalkSpeed = 16
local prePauseAutoRotate = true
local prePauseJumpPower = 50
local prePausePlatformStand = false
local prePauseSit = false

-- ========= CONNECTIONS =========
local activeConnections = {}
local recordConnection = nil
local playbackConnection = nil
local loopConnection = nil
local shiftLockConnection = nil
local jumpConnection = nil

-- ========= SOUND EFFECTS =========
local SoundEffects = {
    Click = "rbxassetid://4499400560",
    Toggle = "rbxassetid://7468131335", 
    RecordStart = "rbxassetid://4499400560",
    RecordStop = "rbxassetid://4499400560",
    Play = "rbxassetid://4499400560",
    Stop = "rbxassetid://4499400560",
    Error = "rbxassetid://7772283448",
    Success = "rbxassetid://2865227271"
}

-- ========= GUI VARIABLES =========
local MiniRecorderGUI, MiniRecorderButtons
local PlaybackGUI, PlaybackButtons
local RecordListFrame, RecordListContainer
local SpeedTextBox, WalkSpeedTextBox, FileNameTextBox

-- ========= UTILITY FUNCTIONS =========
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
    if shiftLockConnection then shiftLockConnection:Disconnect() shiftLockConnection = nil end
    if jumpConnection then jumpConnection:Disconnect() jumpConnection = nil end
end

local function PlaySound(soundType)
    task.spawn(function()
        local sound = Instance.new("Sound")
        sound.SoundId = SoundEffects[soundType] or SoundEffects.Click
        sound.Volume = 0.3
        sound.Parent = workspace
        sound:Play()
        game:GetService("Debris"):AddItem(sound, 2)
    end)
end

local function SimpleButtonClick(button)
    PlaySound("Click")
    local originalColor = button.BackgroundColor3
    local brighterColor = Color3.new(
        math.min(originalColor.R * 1.3, 1),
        math.min(originalColor.G * 1.3, 1), 
        math.min(originalColor.B * 1.3, 1)
    )
    button.BackgroundColor3 = brighterColor
    task.wait(0.1)
    button.BackgroundColor3 = originalColor
end

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
        if humanoid then humanoid.Health = 0 end
    end
end

local function WaitForRespawn()
    local startTime = tick()
    local timeout = 10
    repeat
        task.wait(0.1)
        if tick() - startTime > timeout then return false end
    until IsCharacterReady()
    task.wait(1)
    return true
end

-- ========= CHARACTER STATE MANAGEMENT =========
local function SaveHumanoidState()
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        prePauseAutoRotate = humanoid.AutoRotate
        prePauseWalkSpeed = humanoid.WalkSpeed
        prePauseJumpPower = humanoid.JumpPower
        prePausePlatformStand = humanoid.PlatformStand
        prePauseSit = humanoid.Sit
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
        humanoid.PlatformStand = prePausePlatformStand
        humanoid.Sit = prePauseSit
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
        humanoid.JumpPower = prePauseJumpPower or 50
        humanoid.PlatformStand = false
        humanoid.Sit = false
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end
end

-- ========= PATH VISUALIZATION =========
local function ClearPathVisualization()
    for _, part in pairs(PathVisualization) do
        if part and part.Parent then part:Destroy() end
    end
    PathVisualization = {}
    if CurrentPauseMarker and CurrentPauseMarker.Parent then
        CurrentPauseMarker:Destroy()
        CurrentPauseMarker = nil
    end
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
    if CurrentState == States.PAUSED then
        if not CurrentPauseMarker then
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                CreatePauseMarker(char.HumanoidRootPart.Position)
            end
        end
    else
        if CurrentPauseMarker then
            CurrentPauseMarker:Destroy()
            CurrentPauseMarker = nil
        end
    end
end

-- ========= FRAME UTILITIES =========
local function GetFrameCFrame(frame)
    local pos = Vector3.new(frame.Position[1], frame.Position[2], frame.Position[3])
    local look = Vector3.new(frame.LookVector[1], frame.LookVector[2], frame.LookVector[3])
    local up = Vector3.new(frame.UpVector[1], frame.UpVector[2], frame.UpVector[3])
    return CFrame.lookAt(pos, pos + look, up)
end

local function GetFrameVelocity(frame)
    return frame.Velocity and Vector3.new(
        frame.Velocity[1] * Config.Playback.VelocityScale,
        frame.Velocity[2] * Config.Playback.VelocityYScale,
        frame.Velocity[3] * Config.Playback.VelocityScale
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

-- ========= SMOOTH INTERPOLATION SYSTEM =========
local function LerpCFrame(cf1, cf2, alpha)
    local pos = cf1.Position:Lerp(cf2.Position, alpha)
    local look = cf1.LookVector:Lerp(cf2.LookVector, alpha).Unit
    local up = cf1.UpVector:Lerp(cf2.UpVector, alpha).Unit
    return CFrame.lookAt(pos, pos + look, up)
end

local function StartBlend(targetCFrame, targetVelocity, duration)
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    isBlending = true
    blendStartTime = tick()
    blendDuration = duration or (Config.Playback.TransitionFrames / Config.Recording.FPS)
    blendStartCFrame = char.HumanoidRootPart.CFrame
    blendStartVelocity = char.HumanoidRootPart.AssemblyLinearVelocity
end

local function UpdateBlend(targetCFrame, targetVelocity)
    if not isBlending then return false end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then 
        isBlending = false
        return false 
    end
    
    local elapsed = tick() - blendStartTime
    local alpha = math.min(elapsed / blendDuration, 1)
    alpha = 1 - math.pow(1 - alpha, 3)
    
    local hrp = char.HumanoidRootPart
    hrp.CFrame = LerpCFrame(blendStartCFrame, targetCFrame, alpha)
    hrp.AssemblyLinearVelocity = blendStartVelocity:Lerp(targetVelocity, alpha)
    
    if alpha >= 1 then
        isBlending = false
        return false
    end
    
    return true
end

local function ApplyFrameToCharacter(frame, smooth)
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = char.HumanoidRootPart
    local hum = char:FindFirstChildOfClass("Humanoid")
    
    if not hrp or not hum then return end
    
    local targetCFrame = GetFrameCFrame(frame)
    local targetVelocity = GetFrameVelocity(frame)
    
    if smooth and Config.Features.SmoothPlayback then
        local distance = (hrp.Position - targetCFrame.Position).Magnitude
        
        if distance > Config.Playback.InstantTeleportDistance then
            hrp.CFrame = targetCFrame
            hrp.AssemblyLinearVelocity = targetVelocity
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        else
            if not isBlending then
                StartBlend(targetCFrame, targetVelocity, Config.Playback.BlendSpeed)
            end
        end
    else
        hrp.CFrame = targetCFrame
        hrp.AssemblyLinearVelocity = targetVelocity
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end
    
    if hum then
        hum.WalkSpeed = GetFrameWalkSpeed(frame)
        hum.AutoRotate = false
    end
end

-- ========= TIMELINE FUNCTIONS =========
local function GoBackTimeline()
    if CurrentState ~= States.RECORDING or #CurrentRecording.Frames == 0 then
        PlaySound("Error")
        return
    end
    
    if recordConnection then
        recordConnection:Disconnect()
        recordConnection = nil
    end
    
    CurrentState = States.TIMELINE
    
    local frameStep = math.floor(Config.Recording.FPS * Config.Recording.TimelineStep * Config.Playback.ReverseSpeed)
    local targetFrame = math.max(1, TimelinePosition - frameStep)
    
    TimelinePosition = targetFrame
    CurrentTimelineFrame = targetFrame
    
    local frame = CurrentRecording.Frames[targetFrame]
    if frame then
        ApplyFrameToCharacter(frame, false)
        PlaySound("Click")
    end
end

local function GoNextTimeline()
    if CurrentState ~= States.RECORDING or #CurrentRecording.Frames == 0 then
        PlaySound("Error")
        return
    end
    
    if recordConnection then
        recordConnection:Disconnect()
        recordConnection = nil
    end
    
    CurrentState = States.TIMELINE
    
    local frameStep = math.floor(Config.Recording.FPS * Config.Recording.TimelineStep * Config.Playback.ForwardSpeed)
    local targetFrame = math.min(#CurrentRecording.Frames, TimelinePosition + frameStep)
    
    TimelinePosition = targetFrame
    CurrentTimelineFrame = targetFrame
    
    local frame = CurrentRecording.Frames[targetFrame]
    if frame then
        ApplyFrameToCharacter(frame, false)
        PlaySound("Click")
    end
end

local function ResumeRecording()
    if CurrentState ~= States.TIMELINE and CurrentState ~= States.RECORDING then
        PlaySound("Error")
        return
    end
    
    if #CurrentRecording.Frames == 0 then
        PlaySound("Error")
        return
    end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        PlaySound("Error")
        return
    end
    
    if TimelinePosition < #CurrentRecording.Frames then
        local newFrames = {}
        for i = 1, TimelinePosition do
            table.insert(newFrames, CurrentRecording.Frames[i])
        end
        CurrentRecording.Frames = newFrames
    end
    
    if #CurrentRecording.Frames > 0 then
        local lastFrame = CurrentRecording.Frames[#CurrentRecording.Frames]
        CurrentRecording.StartTime = tick() - lastFrame.Timestamp
        lastRecordedFrame = lastFrame
    end
    
    CurrentState = States.RECORDING
    StartRecording()
    PlaySound("Success")
end

-- ========= RECORDING FUNCTIONS =========
local function StartRecording()
    if CurrentState == States.RECORDING and recordConnection then return end
    
    task.spawn(function()
        local char = player.Character
        if not IsCharacterReady() then
            PlaySound("Error")
            return
        end
        
        if CurrentState ~= States.TIMELINE then
            CurrentState = States.RECORDING
            
            -- Get custom filename from textbox
            local customName = FileNameTextBox and FileNameTextBox.Text or ""
            if customName == "" or customName == "File Name" then
                customName = "recording_" .. os.date("%H%M%S")
            end
            
            CurrentRecording = {Frames = {}, StartTime = tick(), Name = customName}
            TimelinePosition = 0
            CurrentTimelineFrame = 0
            lastRecordedFrame = nil
        else
            CurrentState = States.RECORDING
        end
        
        if MiniRecorderButtons and MiniRecorderButtons.Record then
            MiniRecorderButtons.Record.Text = "⏹"
        end
        
        PlaySound("RecordStart")
        
        local lastRecordTime = 0
        local lastRecordPos = nil
        local lastVelocity = nil
        
        recordConnection = RunService.Heartbeat:Connect(function()
            if CurrentState ~= States.RECORDING then return end
            
            local char = player.Character
            if not IsCharacterReady() or #CurrentRecording.Frames >= Config.Recording.MaxFrames then
                return
            end
            
            local hrp = char.HumanoidRootPart
            local hum = char:FindFirstChildOfClass("Humanoid")
            
            local now = tick()
            if (now - lastRecordTime) < (1 / Config.Recording.FPS) then return end
            
            local currentPos = hrp.Position
            local currentVelocity = hrp.AssemblyLinearVelocity
            
            if lastRecordPos then
                local posChange = (currentPos - lastRecordPos).Magnitude
                local velChange = lastVelocity and (currentVelocity - lastVelocity).Magnitude or math.huge
                
                if posChange < Config.Recording.MinDistance and velChange < Config.Recording.MinVelocityChange then
                    lastRecordTime = now
                    return
                end
            end
            
            local cf = hrp.CFrame
            local newFrame = {
                Position = {cf.Position.X, cf.Position.Y, cf.Position.Z},
                LookVector = {cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z},
                UpVector = {cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z},
                Velocity = {currentVelocity.X, currentVelocity.Y, currentVelocity.Z},
                MoveState = "Grounded",
                WalkSpeed = hum and hum.WalkSpeed or 16,
                Timestamp = now - CurrentRecording.StartTime
            }
            
            table.insert(CurrentRecording.Frames, newFrame)
            lastRecordedFrame = newFrame
            lastRecordTime = now
            lastRecordPos = currentPos
            lastVelocity = currentVelocity
            TimelinePosition = #CurrentRecording.Frames
            CurrentTimelineFrame = TimelinePosition
        end)
        
        AddConnection(recordConnection)
    end)
end

local function StopRecording()
    if CurrentState ~= States.RECORDING then return end
    
    if recordConnection then
        recordConnection:Disconnect()
        recordConnection = nil
    end
    
    if MiniRecorderButtons and MiniRecorderButtons.Record then
        MiniRecorderButtons.Record.Text = "🎦"
    end
    
    CurrentState = States.IDLE
    PlaySound("RecordStop")
end

local function SaveRecording()
    if #CurrentRecording.Frames == 0 then
        PlaySound("Error")
        return
    end
    
    if CurrentState == States.RECORDING then
        StopRecording()
    end
    
    RecordedMovements[CurrentRecording.Name] = CurrentRecording.Frames
    table.insert(RecordingOrder, CurrentRecording.Name)
    checkpointNames[CurrentRecording.Name] = "checkpoint_" .. #RecordingOrder
    
    UpdateRecordList()
    PlaySound("Success")
    
    -- Reset for new recording
    local customName = FileNameTextBox and FileNameTextBox.Text or ""
    if customName == "" or customName == "File Name" then
        customName = "recording_" .. os.date("%H%M%S")
    end
    
    CurrentRecording = {Frames = {}, StartTime = 0, Name = customName}
    TimelinePosition = 0
    CurrentTimelineFrame = 0
    lastRecordedFrame = nil
end

-- ========= PLAYBACK FUNCTIONS =========
local function PlayRecording(name)
    if CurrentState == States.PLAYING then return end
    
    local recording = name and RecordedMovements[name] or (RecordingOrder[1] and RecordedMovements[RecordingOrder[1]])
    if not recording or #recording == 0 then
        PlaySound("Error")
        return
    end
    
    local char = player.Character
    if not IsCharacterReady() then
        PlaySound("Error")
        return
    end

    -- Update speed and walkspeed from textboxes
    if SpeedTextBox and tonumber(SpeedTextBox.Text) then
        CurrentSpeed = tonumber(SpeedTextBox.Text)
    end
    
    if WalkSpeedTextBox and tonumber(WalkSpeedTextBox.Text) then
        CurrentWalkSpeed = tonumber(WalkSpeedTextBox.Text)
    end

    CurrentState = States.PLAYING
    CurrentPlayingRecording = recording
    PausedAtFrame = 0
    playbackAccumulator = 0
    isBlending = false
    isResuming = false
    
    local hrp = char.HumanoidRootPart
    local currentPos = hrp.Position
    
    local nearestFrame, distance = FindNearestFrame(recording, currentPos)
    
    if distance <= Config.Playback.ResumeDistance then
        currentPlaybackFrame = nearestFrame
        playbackStartTime = tick() - (GetFrameTimestamp(recording[nearestFrame]) / CurrentSpeed)
        isResuming = true
        StartBlend(GetFrameCFrame(recording[nearestFrame]), GetFrameVelocity(recording[nearestFrame]), 0.2)
    else
        currentPlaybackFrame = 1
        playbackStartTime = tick()
        hrp.CFrame = GetFrameCFrame(recording[1])
        hrp.AssemblyLinearVelocity = GetFrameVelocity(recording[1])
    end
    
    totalPausedDuration = 0
    pauseStartTime = 0

    SaveHumanoidState()
    PlaySound("Play")
    
    playbackConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if CurrentState ~= States.PLAYING then
            playbackConnection:Disconnect()
            RestoreFullUserControl()
            UpdatePauseMarker()
            isBlending = false
            return
        end
        
        if CurrentState == States.PAUSED then
            if pauseStartTime == 0 then
                pauseStartTime = tick()
                PausedAtFrame = currentPlaybackFrame
                local char = player.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    LastPausePosition = char.HumanoidRootPart.Position
                    LastPauseRecording = recording
                end
                RestoreHumanoidState()
                UpdatePauseMarker()
            end
            return
        else
            if pauseStartTime > 0 then
                totalPausedDuration = totalPausedDuration + (tick() - pauseStartTime)
                pauseStartTime = 0
                isResuming = true
                
                if currentPlaybackFrame <= #recording then
                    StartBlend(
                        GetFrameCFrame(recording[currentPlaybackFrame]), 
                        GetFrameVelocity(recording[currentPlaybackFrame]), 
                        0.15
                    )
                end
                
                UpdatePauseMarker()
            end
        end

        local char = player.Character
        if not IsCharacterReady() then
            CurrentState = States.IDLE
            RestoreFullUserControl()
            UpdatePauseMarker()
            isBlending = false
            return
        end
        
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then
            CurrentState = States.IDLE
            RestoreFullUserControl()
            UpdatePauseMarker()
            isBlending = false
            return
        end

        playbackAccumulator = playbackAccumulator + math.min(deltaTime, 0.1)
        
        local maxIterations = 10
        local iterations = 0
        
        while playbackAccumulator >= Config.Playback.FixedTimestep and iterations < maxIterations do
            playbackAccumulator = playbackAccumulator - Config.Playback.FixedTimestep
            iterations = iterations + 1
            
            local currentTime = tick()
            local effectiveTime = (currentTime - playbackStartTime - totalPausedDuration) * CurrentSpeed
            
            local targetFrame = currentPlaybackFrame
            while targetFrame < #recording and GetFrameTimestamp(recording[targetFrame]) < effectiveTime do
                targetFrame = targetFrame + 1
            end
            
            if targetFrame > currentPlaybackFrame + 1 then
                targetFrame = currentPlaybackFrame + 1
            end
            
            currentPlaybackFrame = targetFrame

            if currentPlaybackFrame > #recording then
                CurrentState = States.IDLE
                RestoreFullUserControl()
                PlaySound("Success")
                UpdatePauseMarker()
                isBlending = false
                return
            end

            local frame = recording[currentPlaybackFrame]
            if not frame then
                CurrentState = States.IDLE
                RestoreFullUserControl()
                UpdatePauseMarker()
                isBlending = false
                return
            end

            task.spawn(function()
                local targetCFrame = GetFrameCFrame(frame)
                local targetVelocity = GetFrameVelocity(frame)
                
                if isBlending then
                    local stillBlending = UpdateBlend(targetCFrame, targetVelocity)
                    if not stillBlending then
                        isResuming = false
                    end
                else
                    hrp.CFrame = targetCFrame
                    hrp.AssemblyLinearVelocity = targetVelocity
                    hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end
                
                if hum then
                    hum.WalkSpeed = GetFrameWalkSpeed(frame) * CurrentSpeed
                    hum.AutoRotate = false
                end
            end)
        end
        
        if iterations >= maxIterations then
            warn("Playback: Frame processing limit reached")
            playbackAccumulator = 0
        end
    end)
    
    AddConnection(playbackConnection)
end

local function StopPlayback()
    if CurrentState == States.PLAYING or CurrentState == States.PAUSED then
        CurrentState = States.IDLE
        isBlending = false
        isResuming = false
        RestoreFullUserControl()
        UpdatePauseMarker()
        PlaySound("Stop")
    end
end

local function PausePlayback()
    if CurrentState == States.PLAYING then
        CurrentState = States.PAUSED
        RestoreHumanoidState()
        UpdatePauseMarker()
        PlaySound("Click")
    elseif CurrentState == States.PAUSED then
        CurrentState = States.PLAYING
        SaveHumanoidState()
        UpdatePauseMarker()
        PlaySound("Click")
    end
end

-- ========= DELETE RECORDING =========
local function DeleteRecording(name)
    if not RecordedMovements[name] then return end
    
    RecordedMovements[name] = nil
    checkpointNames[name] = nil
    CheckedRecordings[name] = nil
    
    for i, recordName in ipairs(RecordingOrder) do
        if recordName == name then
            table.remove(RecordingOrder, i)
            break
        end
    end
    
    UpdateRecordList()
    PlaySound("Success")
end

-- ========= SHIFT LOCK SYSTEM =========
local function ApplyVisibleShiftLock()
    if not Config.Features.ShiftLock or not player.Character then return end
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
    if shiftLockConnection then return end
    shiftLockConnection = RunService.RenderStepped:Connect(function()
        if Config.Features.ShiftLock and player.Character then
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
    local char = player.Character
    if char and char:FindFirstChildOfClass("Humanoid") then
        char.Humanoid.AutoRotate = true
    end
    PlaySound("Toggle")
end

local function ToggleVisibleShiftLock()
    Config.Features.ShiftLock = not Config.Features.ShiftLock
    if Config.Features.ShiftLock then
        EnableVisibleShiftLock()
    else
        DisableVisibleShiftLock()
    end
end

-- ========= INFINITE JUMP =========
local function EnableInfiniteJump()
    if jumpConnection then return end
    jumpConnection = UserInputService.JumpRequest:Connect(function()
        if Config.Features.InfiniteJump and player.Character then
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
    Config.Features.InfiniteJump = not Config.Features.InfiniteJump
    if Config.Features.InfiniteJump then
        EnableInfiniteJump()
    else
        DisableInfiniteJump()
    end
end

-- ========= FILE SAVE/LOAD FUNCTIONS =========
local function SaveToFile()
    if #RecordingOrder == 0 then
        PlaySound("Error")
        StarterGui:SetCore("SendNotification", {
            Title = "Error",
            Text = "No recordings to save!",
            Duration = 3
        })
        return
    end
    
    local data = {
        Recordings = RecordedMovements,
        Order = RecordingOrder,
        Names = checkpointNames,
        Version = "2.0"
    }
    
    local jsonData = HttpService:JSONEncode(data)
    
    local success, result = pcall(function()
        if setclipboard then
            setclipboard(jsonData)
            return true
        elseif writefile then
            local fileName = (FileNameTextBox and FileNameTextBox.Text ~= "" and FileNameTextBox.Text ~= "File Name") 
                and FileNameTextBox.Text .. ".json" 
                or "recording_" .. os.date("%Y%m%d_%H%M%S") .. ".json"
            writefile(fileName, jsonData)
            return true
        end
        return false
    end)
    
    if success and result then
        PlaySound("Success")
        StarterGui:SetCore("SendNotification", {
            Title = "Success",
            Text = "Recording saved to clipboard/file!",
            Duration = 3
        })
    else
        PlaySound("Error")
        StarterGui:SetCore("SendNotification", {
            Title = "Error",
            Text = "Failed to save recording!",
            Duration = 3
        })
    end
end

local function LoadFromFile()
    local success, result = pcall(function()
        local jsonData
        
        if getclipboard then
            jsonData = getclipboard()
        elseif readfile then
            local fileName = (FileNameTextBox and FileNameTextBox.Text ~= "" and FileNameTextBox.Text ~= "File Name") 
                and FileNameTextBox.Text .. ".json" 
                or "recording.json"
            jsonData = readfile(fileName)
        end
        
        if not jsonData then return false end
        
        local data = HttpService:JSONDecode(jsonData)
        
        if data.Recordings and data.Order then
            RecordedMovements = data.Recordings
            RecordingOrder = data.Order
            checkpointNames = data.Names or {}
            
            UpdateRecordList()
            return true
        end
        
        return false
    end)
    
    if success and result then
        PlaySound("Success")
        StarterGui:SetCore("SendNotification", {
            Title = "Success",
            Text = "Recording loaded successfully!",
            Duration = 3
        })
    else
        PlaySound("Error")
        StarterGui:SetCore("SendNotification", {
            Title = "Error",
            Text = "Failed to load recording!",
            Duration = 3
        })
    end
end

-- ========= RECORDING LIST FUNCTIONS =========
function UpdateRecordList()
    if not RecordListContainer then return end
    
    -- Clear existing list
    for _, child in ipairs(RecordListContainer:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    -- Create new list items
    for i, recordName in ipairs(RecordingOrder) do
        local itemFrame = Instance.new("Frame")
        itemFrame.Size = UDim2.new(1, -10, 0, 35)
        itemFrame.Position = UDim2.new(0, 5, 0, (i - 1) * 40)
        itemFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
        itemFrame.BorderSizePixel = 0
        itemFrame.Parent = RecordListContainer
        
        local itemCorner = Instance.new("UICorner")
        itemCorner.CornerRadius = UDim.new(0, 6)
        itemCorner.Parent = itemFrame
        
        -- Checkbox
        local checkbox = Instance.new("TextButton")
        checkbox.Size = UDim2.fromOffset(25, 25)
        checkbox.Position = UDim2.new(0, 5, 0.5, -12.5)
        checkbox.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
        checkbox.Text = CheckedRecordings[recordName] and "✓" or ""
        checkbox.TextColor3 = Color3.new(0, 1, 0)
        checkbox.Font = Enum.Font.GothamBold
        checkbox.TextSize = 16
        checkbox.Parent = itemFrame
        
        local checkCorner = Instance.new("UICorner")
        checkCorner.CornerRadius = UDim.new(0, 4)
        checkCorner.Parent = checkbox
        
        checkbox.MouseButton1Click:Connect(function()
            CheckedRecordings[recordName] = not CheckedRecordings[recordName]
            checkbox.Text = CheckedRecordings[recordName] and "✓" or ""
            SimpleButtonClick(checkbox)
        end)
        
        -- Name label
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -120, 1, 0)
        nameLabel.Position = UDim2.new(0, 35, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = recordName
        nameLabel.TextColor3 = Color3.new(1, 1, 1)
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.TextSize = 11
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.Parent = itemFrame
        
        -- Frame count
        local frameCount = RecordedMovements[recordName] and #RecordedMovements[recordName] or 0
        local countLabel = Instance.new("TextLabel")
        countLabel.Size = UDim2.fromOffset(50, 25)
        countLabel.Position = UDim2.new(1, -105, 0.5, -12.5)
        countLabel.BackgroundTransparency = 1
        countLabel.Text = frameCount .. "f"
        countLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        countLabel.Font = Enum.Font.Gotham
        countLabel.TextSize = 10
        countLabel.Parent = itemFrame
        
        -- Play button
        local playBtn = Instance.new("TextButton")
        playBtn.Size = UDim2.fromOffset(25, 25)
        playBtn.Position = UDim2.new(1, -55, 0.5, -12.5)
        playBtn.BackgroundColor3 = Color3.fromRGB(56, 128, 204)
        playBtn.Text = "▶"
        playBtn.TextColor3 = Color3.new(1, 1, 1)
        playBtn.Font = Enum.Font.GothamBold
        playBtn.TextSize = 12
        playBtn.Parent = itemFrame
        
        local playCorner = Instance.new("UICorner")
        playCorner.CornerRadius = UDim.new(0, 4)
        playCorner.Parent = playBtn
        
        playBtn.MouseButton1Click:Connect(function()
            SimpleButtonClick(playBtn)
            PlayRecording(recordName)
        end)
        
        -- Delete button
        local deleteBtn = Instance.new("TextButton")
        deleteBtn.Size = UDim2.fromOffset(25, 25)
        deleteBtn.Position = UDim2.new(1, -25, 0.5, -12.5)
        deleteBtn.BackgroundColor3 = Color3.fromRGB(230, 62, 62)
        deleteBtn.Text = "X"
        deleteBtn.TextColor3 = Color3.new(1, 1, 1)
        deleteBtn.Font = Enum.Font.GothamBold
        deleteBtn.TextSize = 12
        deleteBtn.Parent = itemFrame
        
        local deleteCorner = Instance.new("UICorner")
        deleteCorner.CornerRadius = UDim.new(0, 4)
        deleteCorner.Parent = deleteBtn
        
        deleteBtn.MouseButton1Click:Connect(function()
            SimpleButtonClick(deleteBtn)
            DeleteRecording(recordName)
        end)
    end
    
    -- Update container size
    RecordListContainer.CanvasSize = UDim2.new(0, 0, 0, #RecordingOrder * 40 + 5)
end

-- ========= FLOATING MINI RECORDER GUI =========
local function CreateMiniRecorderGUI()
    local CoreGui = game:GetService("CoreGui")
    local parent
    local success, result = pcall(function()
        return gethui and gethui()
    end)
    if success and result then
        parent = result
    else
        parent = CoreGui
    end

    local function protect(gui)
        pcall(function()
            if syn and syn.protect_gui then
                syn.protect_gui(gui)
            end
        end)
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "MiniRecorder160x100"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    protect(gui)
    gui.Parent = parent

    local UIS = game:GetService("UserInputService")
    local Camera = workspace.CurrentCamera

    local function clampToViewport(pos, size)
        local vs = Camera and Camera.ViewportSize or Vector2.new(1920,1080)
        local x = math.clamp(pos.X.Offset, 0, vs.X - size.X)
        local y = math.clamp(pos.Y.Offset, 0, vs.Y - size.Y)
        return UDim2.fromOffset(math.floor(x+0.5), math.floor(y+0.5))
    end

    local function setIcon(btn, emoji, fallback)
        btn.Text = emoji
        btn.Font = Enum.Font.GothamBold
        btn.TextScaled = true
        btn.TextWrapped = true
        btn.TextColor3 = Color3.fromRGB(235,235,240)
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
        b.Size = UDim2.fromOffset(40,40)
        b.BackgroundColor3 = Color3.fromRGB(30,30,34)
        b.AutoButtonColor = true
        local cr = Instance.new("UICorner", b)
        cr.CornerRadius = UDim.new(0,10)
        local st = Instance.new("UIStroke", b)
        st.Thickness = 1
        st.Color = Color3.fromRGB(70,70,78)
        return b
    end

    local panel = Instance.new("Frame")
    panel.Name = "RecorderPanel"
    panel.Size = UDim2.fromOffset(160,100)
    panel.Position = UDim2.fromOffset(80, 220)
    panel.BackgroundColor3 = Color3.fromRGB(18,18,22)
    panel.BackgroundTransparency = 0.15
    panel.Active = true
    local pc = Instance.new("UICorner", panel)
    pc.CornerRadius = UDim.new(0,14)
    local ps = Instance.new("UIStroke", panel)
    ps.Thickness = 1
    ps.Color = Color3.fromRGB(60,60,68)
    panel.Parent = gui

    local wrap = Instance.new("Frame", panel)
    wrap.BackgroundTransparency = 1
    wrap.Size = UDim2.fromScale(1,1)
    local pad = Instance.new("UIPadding", wrap)
    pad.PaddingTop = UDim.new(0,6)
    pad.PaddingBottom = UDim.new(0,6)
    pad.PaddingLeft = UDim.new(0,8)
    pad.PaddingRight = UDim.new(0,8)

    local vlist = Instance.new("UIListLayout", wrap)
    vlist.FillDirection = Enum.FillDirection.Vertical
    vlist.Padding = UDim.new(0,8)
    vlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
    vlist.VerticalAlignment = Enum.VerticalAlignment.Center

    local function row()
        local r = Instance.new("Frame")
        r.BackgroundTransparency = 1
        r.Size = UDim2.new(1,0,0,40)
        r.Parent = wrap
        local h = Instance.new("UIListLayout", r)
        h.FillDirection = Enum.FillDirection.Horizontal
        h.Padding = UDim.new(0,8)
        h.HorizontalAlignment = Enum.HorizontalAlignment.Center
        h.VerticalAlignment = Enum.VerticalAlignment.Center
        return r
    end

    local rowTop    = row()
    local rowBottom = row()

    local btnSave  = makeButton("Save")
    btnSave.Parent  = rowTop
    local btnRec   = makeButton("Rec")
    btnRec.Parent   = rowTop
    local btnPrev  = makeButton("Prev")
    btnPrev.Parent  = rowBottom
    local btnPause = makeButton("Pause")
    btnPause.Parent = rowBottom
    local btnNext  = makeButton("Next")
    btnNext.Parent  = rowBottom

    setIcon(btnSave , "💾", "S")
    setIcon(btnRec  , "🎦", "R")
    setIcon(btnPrev , "⏪", "<<")
    setIcon(btnPause, "⏸", "||")
    setIcon(btnNext , "⏩", ">>")

    -- Dragging functionality
    do
        local dragging = false
        local dragStart, startPos
        local function IBegan(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = i.Position
                startPos = panel.Position
                i.Changed:Connect(function()
                    if i.UserInputState == Enum.UserInputState.End then
                        dragging = false
                        panel.Position = clampToViewport(panel.Position, panel.AbsoluteSize)
                    end
                end)
            end
        end
        local function IChanged(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                local d = i.Position - dragStart
                panel.Position = clampToViewport(UDim2.fromOffset(startPos.X.Offset + d.X, startPos.Y.Offset + d.Y), panel.AbsoluteSize)
            end
        end
        panel.InputBegan:Connect(IBegan)
        panel.InputChanged:Connect(IChanged)
        UIS.InputChanged:Connect(IChanged)
    end

    panel.Position = clampToViewport(panel.Position, panel.AbsoluteSize)
    
    return gui, {
        Save = btnSave,
        Record = btnRec,
        Previous = btnPrev,
        Pause = btnPause,
        Next = btnNext
    }
end

-- ========= FLOATING PLAYBACK GUI =========
local function CreatePlaybackGUI()
    local CoreGui = game:GetService("CoreGui")
    local parent
    local success, result = pcall(function()
        return gethui and gethui()
    end)
    if success and result then
        parent = result
    else
        parent = CoreGui
    end

    local function protect(gui)
        pcall(function()
            if syn and syn.protect_gui then
                syn.protect_gui(gui)
            end
        end)
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "PlaybackBar160"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    protect(gui)
    gui.Parent = parent

    local UIS = game:GetService("UserInputService")
    local Camera = workspace.CurrentCamera

    local function clampToViewport(pos, size)
        local vs = Camera and Camera.ViewportSize or Vector2.new(1920,1080)
        local x = math.clamp(pos.X.Offset, 0, vs.X - size.X)
        local y = math.clamp(pos.Y.Offset, 0, vs.Y - size.Y)
        return UDim2.fromOffset(math.floor(x+0.5), math.floor(y+0.5))
    end

    local function setIcon(btn, emoji, fallback)
        btn.Text = emoji
        btn.Font = Enum.Font.GothamBold
        btn.TextScaled = true
        btn.TextWrapped = true
        btn.TextColor3 = Color3.fromRGB(235,235,240)
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
        b.Size = UDim2.fromOffset(40,40)
        b.BackgroundColor3 = Color3.fromRGB(30,30,34)
        b.AutoButtonColor = true
        local cr = Instance.new("UICorner", b)
        cr.CornerRadius = UDim.new(0,10)
        local st = Instance.new("UIStroke", b)
        st.Thickness = 1
        st.Color = Color3.fromRGB(70,70,78)
        return b
    end

    local panel = Instance.new("Frame")
    panel.Name = "PlaybackPanel"
    panel.Size = UDim2.fromOffset(160, 60)
    panel.Position = UDim2.fromOffset(100, 260)
    panel.BackgroundColor3 = Color3.fromRGB(18,18,22)
    panel.BackgroundTransparency = 0.15
    panel.Active = true
    panel.Parent = gui
    local pc = Instance.new("UICorner", panel)
    pc.CornerRadius = UDim.new(0,14)
    local ps = Instance.new("UIStroke", panel)
    ps.Thickness = 1
    ps.Color = Color3.fromRGB(60,60,68)

    local wrap = Instance.new("Frame", panel)
    wrap.BackgroundTransparency = 1
    wrap.Size = UDim2.fromScale(1,1)
    local pad = Instance.new("UIPadding", wrap)
    pad.PaddingTop = UDim.new(0,10)
    pad.PaddingBottom = UDim.new(0,10)
    pad.PaddingLeft = UDim.new(0,10)
    pad.PaddingRight = UDim.new(0,10)

    local row = Instance.new("Frame", wrap)
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1,0,1,0)
    local h = Instance.new("UIListLayout", row)
    h.FillDirection = Enum.FillDirection.Horizontal
    h.Padding = UDim.new(0,12)
    h.HorizontalAlignment = Enum.HorizontalAlignment.Center
    h.VerticalAlignment = Enum.VerticalAlignment.Center

    local btnPlay  = makeButton("Play")
    local btnPause = makeButton("Pause")
    btnPlay.Parent  = row
    btnPause.Parent = row

    setIcon(btnPlay , "▶️", ">")
    setIcon(btnPause, "⏹", "■")

    -- Dragging functionality
    do
        local dragging = false
        local dragStart, startPos
        local function IBegan(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = i.Position
                startPos = panel.Position
                i.Changed:Connect(function()
                    if i.UserInputState == Enum.UserInputState.End then
                        dragging = false
                        panel.Position = clampToViewport(panel.Position, panel.AbsoluteSize)
                    end
                end)
            end
        end
        local function IChanged(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                local d = i.Position - dragStart
                panel.Position = clampToViewport(UDim2.fromOffset(startPos.X.Offset + d.X, startPos.Y.Offset + d.Y), panel.AbsoluteSize)
            end
        end
        panel.InputBegan:Connect(IBegan)
        panel.InputChanged:Connect(IChanged)
        UIS.InputChanged:Connect(IChanged)
    end

    panel.Position = clampToViewport(panel.Position, panel.AbsoluteSize)
    
    return gui, {
        Play = btnPlay,
        Pause = btnPause
    }
end

-- ========= MAIN GUI SETUP =========
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoWalkByaruL"
ScreenGui.ResetOnSpawn = false
if player:FindFirstChild("PlayerGui") then
    ScreenGui.Parent = player.PlayerGui
else
    wait(2)
    ScreenGui.Parent = player:WaitForChild("PlayerGui")
end

-- ========= MAIN FRAME GUI =========
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.fromOffset(250, 470)
MainFrame.Position = UDim2.new(0.5, -125, 0.5, -235)
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
Title.Text = "ByaruL Recorder v2.0"
Title.TextColor3 = Color3.fromRGB(255,255,255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Center
Title.Parent = Header

local HideButton = Instance.new("TextButton")
HideButton.Size = UDim2.fromOffset(22, 22)
HideButton.Position = UDim2.new(1, -50, 0.5, -11)
HideButton.BackgroundColor3 = Color3.fromRGB(56, 128, 204)
HideButton.Text = "_"
HideButton.TextColor3 = Color3.new(1, 1, 1)
HideButton.Font = Enum.Font.GothamBold
HideButton.TextSize = 12
HideButton.Parent = Header

local HideCorner = Instance.new("UICorner")
HideCorner.CornerRadius = UDim.new(0, 6)
HideCorner.Parent = HideButton

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

local MiniButton = Instance.new("TextButton")
MiniButton.Size = UDim2.fromOffset(40, 40)
MiniButton.Position = UDim2.new(0.5, -20, 0, -30)
MiniButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MiniButton.Text = "A"
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

-- ========= BUTTON CREATION FUNCTIONS =========
local function CreateButton(text, x, y, w, h, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(w, h)
    btn.Position = UDim2.fromOffset(x, y)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.AutoButtonColor = false
    btn.Parent = Content
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 1
    stroke.Transparency = 0.7
    stroke.Parent = btn
    
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.new(
                math.min(color.R * 1.2, 1),
                math.min(color.G * 1.2, 1),
                math.min(color.B * 1.2, 1)
            )
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), {
            Transparency = 0.3
        }):Play()
    end)
    
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = color
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), {
            Transparency = 0.7
        }):Play()
    end)
    
    return btn
end

local function CreateTextBox(placeholder, x, y, w, h)
    local textbox = Instance.new("TextBox")
    textbox.Size = UDim2.fromOffset(w, h)
    textbox.Position = UDim2.fromOffset(x, y)
    textbox.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    textbox.Text = placeholder
    textbox.PlaceholderText = placeholder
    textbox.TextColor3 = Color3.new(1, 1, 1)
    textbox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    textbox.Font = Enum.Font.Gotham
    textbox.TextSize = 11
    textbox.ClearTextOnFocus = false
    textbox.Parent = Content
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = textbox
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(70, 70, 78)
    stroke.Thickness = 1
    stroke.Parent = textbox
    
    textbox.Focused:Connect(function()
        TweenService:Create(stroke, TweenInfo.new(0.2), {
            Color = Color3.fromRGB(56, 128, 204),
            Thickness = 2
        }):Play()
    end)
    
    textbox.FocusLost:Connect(function()
        TweenService:Create(stroke, TweenInfo.new(0.2), {
            Color = Color3.fromRGB(70, 70, 78),
            Thickness = 1
        }):Play()
    end)
    
    return textbox
end

-- ========= CREATE TEXTBOXES =========
SpeedTextBox = CreateTextBox("Speed", 0, 2, 75, 28)
SpeedTextBox.Text = "1"

WalkSpeedTextBox = CreateTextBox("WalkSpeed", 79, 2, 75, 28)
WalkSpeedTextBox.Text = "16"

FileNameTextBox = CreateTextBox("File Name", 158, 2, 76, 28)

-- ========= CREATE MAIN GUI BUTTONS =========
local FloatingBtn = CreateButton("FLOATING", 0, 34, 234, 28, Color3.fromRGB(56, 128, 204))

local SaveFileBtn = CreateButton("SAVE FILE", 0, 66, 115, 28, Color3.fromRGB(56, 128, 204))
local LoadFileBtn = CreateButton("LOAD FILE", 119, 66, 115, 28, Color3.fromRGB(56, 128, 204))

local PathToggleBtn = CreateButton("SHOW RUTE", 0, 98, 115, 28, Color3.fromRGB(56, 128, 204))
local MergeBtn = CreateButton("MERGE", 119, 98, 115, 28, Color3.fromRGB(56, 128, 204))

-- ========= RECORDING LIST FRAME =========
RecordListFrame = Instance.new("Frame")
RecordListFrame.Size = UDim2.new(1, 0, 1, -134)
RecordListFrame.Position = UDim2.new(0, 0, 0, 130)
RecordListFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
RecordListFrame.BorderSizePixel = 0
RecordListFrame.Parent = Content

local ListCorner = Instance.new("UICorner")
ListCorner.CornerRadius = UDim.new(0, 8)
ListCorner.Parent = RecordListFrame

local ListStroke = Instance.new("UIStroke")
ListStroke.Color = Color3.fromRGB(40, 40, 48)
ListStroke.Thickness = 1
ListStroke.Parent = RecordListFrame

-- List Header
local ListHeader = Instance.new("Frame")
ListHeader.Size = UDim2.new(1, 0, 0, 30)
ListHeader.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
ListHeader.BorderSizePixel = 0
ListHeader.Parent = RecordListFrame

local HeaderCornerList = Instance.new("UICorner")
HeaderCornerList.CornerRadius = UDim.new(0, 8)
HeaderCornerList.Parent = ListHeader

local ListTitle = Instance.new("TextLabel")
ListTitle.Size = UDim2.new(1, -10, 1, 0)
ListTitle.Position = UDim2.new(0, 5, 0, 0)
ListTitle.BackgroundTransparency = 1
ListTitle.Text = "📋 REPLAY LIST"
ListTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
ListTitle.Font = Enum.Font.GothamBold
ListTitle.TextSize = 12
ListTitle.TextXAlignment = Enum.TextXAlignment.Left
ListTitle.Parent = ListHeader

-- Scrolling Container
RecordListContainer = Instance.new("ScrollingFrame")
RecordListContainer.Size = UDim2.new(1, -10, 1, -40)
RecordListContainer.Position = UDim2.new(0, 5, 0, 35)
RecordListContainer.BackgroundTransparency = 1
RecordListContainer.BorderSizePixel = 0
RecordListContainer.ScrollBarThickness = 4
RecordListContainer.ScrollBarImageColor3 = Color3.fromRGB(56, 128, 204)
RecordListContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
RecordListContainer.Parent = RecordListFrame

-- ========= CONNECT BUTTON EVENTS =========
SaveFileBtn.MouseButton1Click:Connect(function()
    SimpleButtonClick(SaveFileBtn)
    SaveToFile()
end)

LoadFileBtn.MouseButton1Click:Connect(function()
    SimpleButtonClick(LoadFileBtn)
    LoadFromFile()
end)

PathToggleBtn.MouseButton1Click:Connect(function()
    SimpleButtonClick(PathToggleBtn)
    Config.Features.ShowPaths = not Config.Features.ShowPaths
    if Config.Features.ShowPaths then
        PathToggleBtn.Text = "HIDE RUTE"
    else
        PathToggleBtn.Text = "SHOW RUTE"
        ClearPathVisualization()
    end
end)

MergeBtn.MouseButton1Click:Connect(function()
    SimpleButtonClick(MergeBtn)
    
    -- Merge checked recordings
    local mergedFrames = {}
    local mergedName = "merged_" .. os.date("%H%M%S")
    
    for _, recordName in ipairs(RecordingOrder) do
        if CheckedRecordings[recordName] then
            local recording = RecordedMovements[recordName]
            if recording then
                for _, frame in ipairs(recording) do
                    table.insert(mergedFrames, frame)
                end
            end
        end
    end
    
    if #mergedFrames > 0 then
        RecordedMovements[mergedName] = mergedFrames
        table.insert(RecordingOrder, mergedName)
        checkpointNames[mergedName] = "merged"
        
        UpdateRecordList()
        PlaySound("Success")
        
        StarterGui:SetCore("SendNotification", {
            Title = "Success",
            Text = "Merged " .. #mergedFrames .. " frames!",
            Duration = 3
        })
    else
        PlaySound("Error")
        StarterGui:SetCore("SendNotification", {
            Title = "Error",
            Text = "No recordings selected!",
            Duration = 3
        })
    end
end)

FloatingBtn.MouseButton1Click:Connect(function()
    SimpleButtonClick(FloatingBtn)
    
    -- Toggle Main GUI
    MainFrame.Visible = not MainFrame.Visible
    MiniButton.Visible = not MainFrame.Visible
    
    -- Initialize floating GUIs if not exists
    if not MiniRecorderGUI then
        MiniRecorderGUI, MiniRecorderButtons = CreateMiniRecorderGUI()
        
        -- Connect mini recorder buttons
        MiniRecorderButtons.Save.MouseButton1Click:Connect(function()
            SimpleButtonClick(MiniRecorderButtons.Save)
            SaveRecording()
        end)

        MiniRecorderButtons.Record.MouseButton1Click:Connect(function()
            SimpleButtonClick(MiniRecorderButtons.Record)
            if CurrentState == States.RECORDING then
                StopRecording()
                MiniRecorderButtons.Record.Text = "🎦"
            else
                StartRecording()
                MiniRecorderButtons.Record.Text = "⏹"
            end
        end)

        MiniRecorderButtons.Previous.MouseButton1Click:Connect(function()
            SimpleButtonClick(MiniRecorderButtons.Previous)
            GoBackTimeline()
        end)

        MiniRecorderButtons.Pause.MouseButton1Click:Connect(function()
            SimpleButtonClick(MiniRecorderButtons.Pause)
            ResumeRecording()
        end)

        MiniRecorderButtons.Next.MouseButton1Click:Connect(function()
            SimpleButtonClick(MiniRecorderButtons.Next)
            GoNextTimeline()
        end)
    else
        MiniRecorderGUI.Enabled = not MiniRecorderGUI.Enabled
    end
    
    if not PlaybackGUI then
        PlaybackGUI, PlaybackButtons = CreatePlaybackGUI()
        
        -- Connect playback buttons
        PlaybackButtons.Play.MouseButton1Click:Connect(function()
            SimpleButtonClick(PlaybackButtons.Play)
            if CurrentState == States.PLAYING or CurrentState == States.PAUSED then
                StopPlayback()
                PlaybackButtons.Play.Text = "▶️"
            else
                PlayRecording()
                PlaybackButtons.Play.Text = "⏹"
            end
        end)

        PlaybackButtons.Pause.MouseButton1Click:Connect(function()
            SimpleButtonClick(PlaybackButtons.Pause)
            PausePlayback()
            if CurrentState == States.PAUSED then
                PlaybackButtons.Pause.Text = "▶️"
            else
                PlaybackButtons.Pause.Text = "⏸"
            end
        end)
    else
        PlaybackGUI.Enabled = not PlaybackGUI.Enabled
    end
end)

HideButton.MouseButton1Click:Connect(function()
    SimpleButtonClick(HideButton)
    MainFrame.Visible = false
    MiniButton.Visible = true
end)

MiniButton.MouseButton1Click:Connect(function()
    SimpleButtonClick(MiniButton)
    MainFrame.Visible = true
    MiniButton.Visible = false
end)

CloseButton.MouseButton1Click:Connect(function()
    SimpleButtonClick(CloseButton)
    if CurrentState == States.RECORDING then StopRecording() end
    if CurrentState == States.PLAYING then StopPlayback() end
    CleanupConnections()
    ClearPathVisualization()
    ScreenGui:Destroy()
    if MiniRecorderGUI then MiniRecorderGUI:Destroy() end
    if PlaybackGUI then PlaybackGUI:Destroy() end
end)

-- ========= TEXTBOX VALIDATION =========
SpeedTextBox.FocusLost:Connect(function()
    local value = tonumber(SpeedTextBox.Text)
    if value and value > 0 and value <= 10 then
        CurrentSpeed = value
        PlaySound("Success")
    else
        SpeedTextBox.Text = tostring(CurrentSpeed)
        PlaySound("Error")
    end
end)

WalkSpeedTextBox.FocusLost:Connect(function()
    local value = tonumber(WalkSpeedTextBox.Text)
    if value and value > 0 and value <= 100 then
        CurrentWalkSpeed = value
        local char = player.Character
        if char and char:FindFirstChildOfClass("Humanoid") then
            char.Humanoid.WalkSpeed = value
        end
        PlaySound("Success")
    else
        WalkSpeedTextBox.Text = tostring(CurrentWalkSpeed)
        PlaySound("Error")
    end
end)

FileNameTextBox.Focused:Connect(function()
    if FileNameTextBox.Text == "File Name" then
        FileNameTextBox.Text = ""
    end
end)

FileNameTextBox.FocusLost:Connect(function()
    if FileNameTextBox.Text == "" then
        FileNameTextBox.Text = "File Name"
    end
end)

-- ========= KEYBOARD SHORTCUTS =========
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    if input.KeyCode == Enum.KeyCode.F9 then
        if CurrentState == States.RECORDING then 
            StopRecording()
        else 
            StartRecording()
        end
    elseif input.KeyCode == Enum.KeyCode.F10 then
        if CurrentState == States.PLAYING or CurrentState == States.PAUSED then
            StopPlayback()
        else
            PlayRecording()
        end
    elseif input.KeyCode == Enum.KeyCode.F11 then
        MainFrame.Visible = not MainFrame.Visible
        MiniButton.Visible = not MainFrame.Visible
    elseif input.KeyCode == Enum.KeyCode.LeftBracket then
        GoBackTimeline()
    elseif input.KeyCode == Enum.KeyCode.RightBracket then
        GoNextTimeline()
    elseif input.KeyCode == Enum.KeyCode.P then
        if CurrentState == States.PLAYING then
            PausePlayback()
        end
    elseif input.KeyCode == Enum.KeyCode.S and input.UserInputState == Enum.UserInputState.Begin then
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
            SaveRecording()
        end
    end
end)

-- ========= AUTO-UPDATE WALKSPEED =========
player.CharacterAdded:Connect(function(character)
    wait(1)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = CurrentWalkSpeed
        
        humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if CurrentState ~= States.PLAYING and CurrentState ~= States.PAUSED then
                CurrentWalkSpeed = humanoid.WalkSpeed
                if WalkSpeedTextBox then
                    WalkSpeedTextBox.Text = tostring(math.floor(CurrentWalkSpeed))
                end
            end
        end)
    end
end)

-- ========= INITIALIZATION =========
player.CharacterRemoving:Connect(function()
    if CurrentState == States.RECORDING then
        StopRecording()
    end
    if CurrentState == States.PLAYING then
        StopPlayback()
    end
end)

-- Initialize current character
if player.Character then
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        CurrentWalkSpeed = humanoid.WalkSpeed
        WalkSpeedTextBox.Text = tostring(math.floor(CurrentWalkSpeed))
        
        humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if CurrentState ~= States.PLAYING and CurrentState ~= States.PAUSED then
                CurrentWalkSpeed = humanoid.WalkSpeed
                if WalkSpeedTextBox then
                    WalkSpeedTextBox.Text = tostring(math.floor(CurrentWalkSpeed))
                end
            end
        end)
    end
end

print("===========================================")
print("ByaruL Recorder v2.0 - FULL EDITION")
print("===========================================")
print("✓ State: " .. CurrentState)
print("✓ Smooth Interpolation: ENABLED")
print("✓ Frame Skip Protection: ENABLED")
print("✓ Smart Recording: ENABLED")
print("✓ Replay List: ENABLED")
print("✓ Custom Speed/WalkSpeed: ENABLED")
print("✓ File Save/Load: ENABLED")
print("===========================================")
print("FEATURES:")
print("• Speed TextBox - Control playback speed (0.1-10)")
print("• WalkSpeed TextBox - Control character speed (1-100)")
print("• File Name TextBox - Custom save/load filename")
print("• Replay List - Manage all recordings")
print("  - Checkbox: Select for merge")
print("  - Play: Quick play recording")
print("  - Delete: Remove recording")
print("• Save/Load File - Export/Import recordings")
print("• Merge - Combine selected recordings")
print("• Show Rute - Visualize recording path")
print("===========================================")
print("CONTROLS:")
print("F9      : Start/Stop Recording")
print("F10     : Play/Stop Playback") 
print("F11     : Toggle GUI")
print("P       : Pause/Resume Playback")
print("[       : Timeline Back")
print("]       : Timeline Next")
print("Ctrl+S  : Save Recording")
print("===========================================")
print("TEXTBOX USAGE:")
print("1. Speed: 0.5 = half speed, 2 = double speed")
print("2. WalkSpeed: Default 16, max 100")
print("3. File Name: Custom name for save/load")
print("===========================================")