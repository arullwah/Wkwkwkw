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
        MinDistance = 0.01,
        TimelineStep = 0.1
    },
    Playback = {
        VelocityScale = 1,
        VelocityYScale = 1,
        ReverseSpeed = 2.0,
        ForwardSpeed = 3.0,
        FixedTimestep = 1 / 60,
        ResumeDistance = 15,
        StateChangeCooldown = 0.01
    },
    Features = {
        AutoRespawn = false,
        InfiniteJump = false,
        AutoLoop = false,
        ShowPaths = false,
        ShiftLock = false,
        AutoReset = false
    }
}

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
local playbackAccumulator = 0
local LastPausePosition = nil
local LastPauseRecording = nil

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
local ScreenGui, MainFrame

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

local function CompleteCharacterReset(char)
    if not char or not char:IsDescendantOf(workspace) then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then return end
    task.spawn(function()
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
        humanoid.WalkSpeed = CurrentWalkSpeed
        humanoid.JumpPower = prePauseJumpPower or 50
        humanoid.Sit = false
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end)
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

local function VisualizeAllPaths()
    ClearPathVisualization()
    
    if not Config.Features.ShowPaths then return end
    
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

local function ApplyFrameToCharacter(frame)
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = char.HumanoidRootPart
    local hum = char:FindFirstChildOfClass("Humanoid")
    
    if not hrp or not hum then return end
    
    task.spawn(function()
        local targetCFrame = GetFrameCFrame(frame)
        hrp.CFrame = targetCFrame
        hrp.AssemblyLinearVelocity = GetFrameVelocity(frame)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        
        if hum then
            hum.WalkSpeed = GetFrameWalkSpeed(frame)
            hum.AutoRotate = false
            
            local moveState = frame.MoveState
            if moveState == "Jumping" then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            elseif moveState == "Falling" then
                hum:ChangeState(Enum.HumanoidStateType.Freefall)
            elseif moveState == "Climbing" then
                hum:ChangeState(Enum.HumanoidStateType.Climbing)
                hum.PlatformStand = false
                hum.AutoRotate = false
            elseif moveState == "Swimming" then
                hum:ChangeState(Enum.HumanoidStateType.Swimming)
            else
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
        end
    end)
end

-- ========= DATA PROCESSING =========
local function CreateContinuousTimeline(frames)
    if not frames or #frames == 0 then return {} end
    
    local continuousFrames = {}
    local currentTimestamp = 0
    local expectedInterval = 1 / Config.Recording.FPS
    
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

-- ========= OBFUSCATION FUNCTIONS =========
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

-- ========= TIMELINE FUNCTIONS =========
local function GoBackTimeline()
    if CurrentState ~= States.RECORDING or #CurrentRecording.Frames == 0 then
        PlaySound("Error")
        return
    end
    
    CurrentState = States.TIMELINE
    
    local frameStep = math.floor(Config.Recording.FPS * Config.Recording.TimelineStep * Config.Playback.ReverseSpeed)
    local targetFrame = math.max(1, TimelinePosition - frameStep)
    
    TimelinePosition = targetFrame
    CurrentTimelineFrame = targetFrame
    
    local frame = CurrentRecording.Frames[targetFrame]
    if frame then
        ApplyFrameToCharacter(frame)
        PlaySound("Click")
    end
end

local function GoNextTimeline()
    if CurrentState ~= States.RECORDING or #CurrentRecording.Frames == 0 then
        PlaySound("Error")
        return
    end
    
    CurrentState = States.TIMELINE
    
    local frameStep = math.floor(Config.Recording.FPS * Config.Recording.TimelineStep * Config.Playback.ForwardSpeed)
    local targetFrame = math.min(#CurrentRecording.Frames, TimelinePosition + frameStep)
    
    TimelinePosition = targetFrame
    CurrentTimelineFrame = targetFrame
    
    local frame = CurrentRecording.Frames[targetFrame]
    if frame then
        ApplyFrameToCharacter(frame)
        PlaySound("Click")
    end
end

local function ResumeRecording()
    if CurrentState ~= States.RECORDING then
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
    
    -- HAPUS SEMUA FRAME SETELAH TIMELINE POSITION
    if TimelinePosition < #CurrentRecording.Frames then
        local newFrames = {}
        for i = 1, TimelinePosition do
            table.insert(newFrames, CurrentRecording.Frames[i])
        end
        CurrentRecording.Frames = newFrames
    end
    
    -- RESET START TIME UNTUK MELANJUTKAN
    if #CurrentRecording.Frames > 0 then
        local lastFrame = CurrentRecording.Frames[#CurrentRecording.Frames]
        CurrentRecording.StartTime = tick() - lastFrame.Timestamp
    end
    
    CurrentState = States.RECORDING
    PlaySound("Success")
end

-- ========= RECORDING FUNCTIONS =========
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
    elseif state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics then 
        return "Grounded"
    else 
        return "Grounded" 
    end
end

local function StartRecording()
    if CurrentState == States.RECORDING then return end
    
    task.spawn(function()
        local char = player.Character
        if not IsCharacterReady() then
            PlaySound("Error")
            return
        end
        
        CurrentState = States.RECORDING
        CurrentRecording = {Frames = {}, StartTime = tick(), Name = "recording_" .. os.date("%H%M%S")}
        TimelinePosition = 0
        CurrentTimelineFrame = 0
        
        if MiniRecorderButtons and MiniRecorderButtons.Record then
            MiniRecorderButtons.Record.Text = "⏹"
        end
        
        PlaySound("RecordStart")
        
        local lastRecordTime = 0
        local lastRecordPos = nil
        
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
            
            if lastRecordPos and (currentPos - lastRecordPos).Magnitude < Config.Recording.MinDistance then
                lastRecordTime = now
                return
            end
            
            local cf = hrp.CFrame
            local newFrame = {
                Position = {cf.Position.X, cf.Position.Y, cf.Position.Z},
                LookVector = {cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z},
                UpVector = {cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z},
                Velocity = {currentVelocity.X, currentVelocity.Y, currentVelocity.Z},
                MoveState = GetCurrentMoveState(hum, currentVelocity),
                WalkSpeed = hum and hum.WalkSpeed or 16,
                Timestamp = now - CurrentRecording.StartTime
            }
            
            table.insert(CurrentRecording.Frames, newFrame)
            lastRecordTime = now
            lastRecordPos = currentPos
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
    
    -- LANGSUNG PAKAI FRAME ASLI TANPA INTERPOLATION
    local processedFrames = CreateContinuousTimeline(CurrentRecording.Frames)
    
    RecordedMovements[CurrentRecording.Name] = processedFrames
    table.insert(RecordingOrder, CurrentRecording.Name)
    checkpointNames[CurrentRecording.Name] = "checkpoint_" .. #RecordingOrder
    
    UpdateRecordList()
    PlaySound("Success")
    
    CurrentRecording = {Frames = {}, StartTime = 0, Name = "recording_" .. os.date("%H%M%S")}
    TimelinePosition = 0
    CurrentTimelineFrame = 0
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

    CurrentState = States.PLAYING
    CurrentPlayingRecording = recording
    playbackAccumulator = 0
    
    local hrp = char.HumanoidRootPart
    local currentPos = hrp.Position
    
    local nearestFrame, distance = FindNearestFrame(recording, currentPos)
    
    if distance <= Config.Playback.ResumeDistance then
        currentPlaybackFrame = nearestFrame
        playbackStartTime = tick() - (GetFrameTimestamp(recording[nearestFrame]) / CurrentSpeed)
    else
        currentPlaybackFrame = 1
        playbackStartTime = tick()
        -- INSTANT TELEPORT KE FRAME PERTAMA TANPA INTERPOLATION
        hrp.CFrame = GetFrameCFrame(recording[1])
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
            return
        end
        
        if CurrentState == States.PAUSED then
            if pauseStartTime == 0 then
                pauseStartTime = tick()
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
                UpdatePauseMarker()
            end
        end

        local char = player.Character
        if not IsCharacterReady() then
            CurrentState = States.IDLE
            RestoreFullUserControl()
            UpdatePauseMarker()
            return
        end
        
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then
            CurrentState = States.IDLE
            RestoreFullUserControl()
            UpdatePauseMarker()
            return
        end

        playbackAccumulator = playbackAccumulator + deltaTime
        
        while playbackAccumulator >= Config.Playback.FixedTimestep do
            playbackAccumulator = playbackAccumulator - Config.Playback.FixedTimestep
            
            local currentTime = tick()
            local effectiveTime = (currentTime - playbackStartTime - totalPausedDuration) * CurrentSpeed
            
            while currentPlaybackFrame < #recording and GetFrameTimestamp(recording[currentPlaybackFrame + 1]) <= effectiveTime do
                currentPlaybackFrame = currentPlaybackFrame + 1
            end

            if currentPlaybackFrame >= #recording then
                CurrentState = States.IDLE
                RestoreFullUserControl()
                PlaySound("Success")
                UpdatePauseMarker()
                return
            end

            local frame = recording[currentPlaybackFrame]
            if not frame then
                CurrentState = States.IDLE
                RestoreFullUserControl()
                UpdatePauseMarker()
                return
            end

            -- INSTANT APPLY FRAME TANPA INTERPOLATION
            task.spawn(function()
                hrp.CFrame = GetFrameCFrame(frame)
                hrp.AssemblyLinearVelocity = GetFrameVelocity(frame)
                
                if hum then
                    hum.WalkSpeed = GetFrameWalkSpeed(frame) * CurrentSpeed
                    hum.AutoRotate = false
                    
                    local moveState = frame.MoveState
                    if moveState == "Jumping" then
                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                    elseif moveState == "Falling" then
                        hum:ChangeState(Enum.HumanoidStateType.Freefall)
                    elseif moveState == "Climbing" then
                        hum:ChangeState(Enum.HumanoidStateType.Climbing)
                        hum.PlatformStand = false
                        hum.AutoRotate = false
                    elseif moveState == "Swimming" then
                        hum:ChangeState(Enum.HumanoidStateType.Swimming)
                    else
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                    end
                end
            end)
        end
    end)
    
    AddConnection(playbackConnection)
end

local function StopPlayback()
    if CurrentState == States.PLAYING or CurrentState == States.PAUSED then
        CurrentState = States.IDLE
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

-- ========= AUTO LOOP SYSTEM =========
local CurrentLoopIndex = 1
local IsAutoLoopPlaying = false

local function StartAutoLoopAll()
    if not Config.Features.AutoLoop then return end
    
    if #RecordingOrder == 0 then
        Config.Features.AutoLoop = false
        PlaySound("Error")
        return
    end
    
    PlaySound("Play")
    
    CurrentLoopIndex = 1
    IsAutoLoopPlaying = true
    
    loopConnection = task.spawn(function()
        while Config.Features.AutoLoop and IsAutoLoopPlaying do
            if not Config.Features.AutoLoop or not IsAutoLoopPlaying then break end
            
            local recordingName = RecordingOrder[CurrentLoopIndex]
            local recording = RecordedMovements[recordingName]
            
            if not recording or #recording == 0 then
                CurrentLoopIndex = CurrentLoopIndex + 1
                if CurrentLoopIndex > #RecordingOrder then CurrentLoopIndex = 1 end
                task.wait(1)
                continue
            end
            
            if not IsCharacterReady() then
                if Config.Features.AutoRespawn then
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
                    
                    while not IsCharacterReady() and Config.Features.AutoLoop and IsAutoLoopPlaying do
                        waitAttempts = waitAttempts + 1
                        if waitAttempts >= maxWaitAttempts then
                            Config.Features.AutoLoop = false
                            IsAutoLoopPlaying = false
                            PlaySound("Error")
                            break
                        end
                        task.wait(0.5)
                    end
                    
                    if not Config.Features.AutoLoop or not IsAutoLoopPlaying then break end
                    task.wait(1.0)
                end
            end
            
            if not Config.Features.AutoLoop or not IsAutoLoopPlaying then break end
            
            local playbackCompleted = false
            local playbackStart = tick()
            local playbackPausedTime = 0
            local playbackPauseStart = 0
            local currentFrame = 1
            local deathRetryCount = 0
            local maxDeathRetries = 999999
            local loopAccumulator = 0
            
            SaveHumanoidState()
            
            while Config.Features.AutoLoop and IsAutoLoopPlaying and currentFrame <= #recording and deathRetryCount < maxDeathRetries do
                
                if not IsCharacterReady() then
                    deathRetryCount = deathRetryCount + 1
                    
                    if Config.Features.AutoRespawn then
                        ResetCharacter()
                        local success = WaitForRespawn()
                        
                        if success then
                            RestoreFullUserControl()
                            task.wait(1.5)
                            
                            currentFrame = 1
                            playbackStart = tick()
                            playbackPausedTime = 0
                            playbackPauseStart = 0
                            loopAccumulator = 0
                            
                            SaveHumanoidState()
                            continue
                        else
                            task.wait(2)
                            continue
                        end
                    else
                        local manualRespawnWait = 0
                        local maxManualWait = 60
                        
                        while not IsCharacterReady() and Config.Features.AutoLoop and IsAutoLoopPlaying do
                            manualRespawnWait = manualRespawnWait + 1
                            
                            if manualRespawnWait >= maxManualWait then
                                Config.Features.AutoLoop = false
                                IsAutoLoopPlaying = false
                                PlaySound("Error")
                                break
                            end
                            
                            task.wait(0.5)
                        end
                        
                        if not Config.Features.AutoLoop or not IsAutoLoopPlaying then break end
                        
                        RestoreFullUserControl()
                        task.wait(1.5)
                        
                        currentFrame = 1
                        playbackStart = tick()
                        playbackPausedTime = 0
                        playbackPauseStart = 0
                        loopAccumulator = 0
                        
                        SaveHumanoidState()
                        continue
                    end
                end
                
                if CurrentState == States.PAUSED then
                    if playbackPauseStart == 0 then
                        playbackPauseStart = tick()
                        RestoreHumanoidState()
                        UpdatePauseMarker()
                    end
                    task.wait(0.1)
                else
                    if playbackPauseStart > 0 then
                        playbackPausedTime = playbackPausedTime + (tick() - playbackPauseStart)
                        playbackPauseStart = 0
                        UpdatePauseMarker()
                    end
                    
                    local char = player.Character
                    if not char or not char:FindFirstChild("HumanoidRootPart") then
                        task.wait(0.5)
                        break
                    end
                    
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if not hum or not hrp then
                        task.wait(0.5)
                        break
                    end
                    
                    local deltaTime = task.wait()
                    loopAccumulator = loopAccumulator + deltaTime
                    
                    while loopAccumulator >= Config.Playback.FixedTimestep do
                        loopAccumulator = loopAccumulator - Config.Playback.FixedTimestep
                        
                        local currentTime = tick()
                        local effectiveTime = (currentTime - playbackStart - playbackPausedTime) * CurrentSpeed
                        
                        while currentFrame < #recording and GetFrameTimestamp(recording[currentFrame + 1]) <= effectiveTime do
                            currentFrame = currentFrame + 1
                        end
                        
                        if currentFrame >= #recording then
                            playbackCompleted = true
                            break
                        end
                        
                        local frame = recording[currentFrame]
                        if frame then
                            -- INSTANT APPLY FRAME TANPA INTERPOLATION
                            task.spawn(function()
                                hrp.CFrame = GetFrameCFrame(frame)
                                hrp.AssemblyLinearVelocity = GetFrameVelocity(frame)
                                
                                if hum then
                                    hum.WalkSpeed = GetFrameWalkSpeed(frame) * CurrentSpeed
                                    hum.AutoRotate = false
                                    
                                    local moveState = frame.MoveState
                                    if moveState == "Jumping" then
                                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                                    elseif moveState == "Falling" then
                                        hum:ChangeState(Enum.HumanoidStateType.Freefall)
                                    elseif moveState == "Climbing" then
                                        hum:ChangeState(Enum.HumanoidStateType.Climbing)
                                        hum.PlatformStand = false
                                        hum.AutoRotate = false
                                    elseif moveState == "Swimming" then
                                        hum:ChangeState(Enum.HumanoidStateType.Swimming)
                                    else
                                        hum:ChangeState(Enum.HumanoidStateType.Running)
                                    end
                                end
                            end)
                        end
                    end
                    
                    if playbackCompleted then break end
                end
            end
            
            RestoreFullUserControl()
            UpdatePauseMarker()
            
            if playbackCompleted then
                PlaySound("Success")
                
                CurrentLoopIndex = CurrentLoopIndex + 1
                if CurrentLoopIndex > #RecordingOrder then CurrentLoopIndex = 1 end
                
                task.wait(0.5)
            else
                if not Config.Features.AutoLoop or not IsAutoLoopPlaying then break end
                task.wait(1)
            end
        end
        
        IsAutoLoopPlaying = false
        CurrentState = States.IDLE
        RestoreFullUserControl()
        UpdatePauseMarker()
    end)
end

local function StopAutoLoopAll()
    Config.Features.AutoLoop = false
    IsAutoLoopPlaying = false
    CurrentState = States.IDLE
    
    if loopConnection then
        task.cancel(loopConnection)
        loopConnection = nil
    end
    
    RestoreFullUserControl()
    UpdatePauseMarker()
    
    local char = player.Character
    if char then CompleteCharacterReset(char) end
    
    PlaySound("Stop")
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

-- ========= FILE OPERATIONS =========
local function SaveToObfuscatedJSON()
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

local function LoadFromObfuscatedJSON()
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

-- ========= RECORDING LIST FUNCTIONS =========
local function FormatDuration(seconds)
    local minutes = math.floor(seconds / 60)
    local remainingSeconds = math.floor(seconds % 60)
    return string.format("%d:%02d", minutes, remainingSeconds)
end

local function MoveRecordingUp(name)
    local currentIndex = table.find(RecordingOrder, name)
    if currentIndex and currentIndex > 1 then
        RecordingOrder[currentIndex] = RecordingOrder[currentIndex - 1]
        RecordingOrder[currentIndex - 1] = name
        UpdateRecordList()
    end
end

local function MoveRecordingDown(name)
    local currentIndex = table.find(RecordingOrder, name)
    if currentIndex and currentIndex < #RecordingOrder then
        RecordingOrder[currentIndex] = RecordingOrder[currentIndex + 1]
        RecordingOrder[currentIndex + 1] = name
        UpdateRecordList()
    end
end

function UpdateRecordList()
    -- Implementation for updating the recording list UI
    -- This would create the list items for each recording
end

-- ========= MERGE FUNCTION =========
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
ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoWalkByaruL"
ScreenGui.ResetOnSpawn = false
if player:FindFirstChild("PlayerGui") then
    ScreenGui.Parent = player.PlayerGui
else
    wait(2)
    ScreenGui.Parent = player:WaitForChild("PlayerGui")
end

-- ========= MAIN FRAME GUI =========
MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.fromOffset(250, 340)
MainFrame.Position = UDim2.new(0.5, -125, 0.5, -170)
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

local function CreateToggle(text, x, y, w, h, default)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(w, h)
    btn.Position = UDim2.fromOffset(x, y)
    btn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
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
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = btn
    
    local toggle = Instance.new("Frame")
    toggle.Size = UDim2.fromOffset(20, 11)
    toggle.Position = UDim2.new(1, -23, 0.5, -5)
    toggle.BackgroundColor3 = default and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(50, 50, 50)
    toggle.BorderSizePixel = 0
    toggle.Parent = btn
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(1, 0)
    toggleCorner.Parent = toggle
    
    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(7, 7)
    knob.Position = default and UDim2.new(0, 11, 0, 2) or UDim2.new(0, 2, 0, 2)
    knob.BackgroundColor3 = Color3.fromRGB(220, 220, 230)
    knob.BorderSizePixel = 0
    knob.Parent = toggle
    
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob
    
    return btn, toggle, knob
end

-- ========= CREATE MAIN GUI BUTTONS =========
local MenuBtn = CreateButton("MENU", 0, 2, 75, 30, Color3.fromRGB(56, 128, 204))
local FloatingBtn = CreateButton("FLOATING", 79, 2, 171, 30, Color3.fromRGB(56, 128, 204))

local SpeedBox = Instance.new("TextBox")
SpeedBox.Size = UDim2.fromOffset(60, 22)
SpeedBox.Position = UDim2.fromOffset(0, 36)
SpeedBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
SpeedBox.BorderSizePixel = 0
SpeedBox.Text = "1.00"
SpeedBox.PlaceholderText = "Speed"
SpeedBox.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedBox.Font = Enum.Font.GothamBold
SpeedBox.TextSize = 8
SpeedBox.TextXAlignment = Enum.TextXAlignment.Center
SpeedBox.ClearTextOnFocus = false
SpeedBox.Parent = Content

local SpeedCorner = Instance.new("UICorner")
SpeedCorner.CornerRadius = UDim.new(0, 4)
SpeedCorner.Parent = SpeedBox

local FilenameBox = Instance.new("TextBox")
FilenameBox.Size = UDim2.fromOffset(110, 22)
FilenameBox.Position = UDim2.fromOffset(62, 36)
FilenameBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
FilenameBox.BorderSizePixel = 0
FilenameBox.Text = ""
FilenameBox.PlaceholderText = "Custom Filename"
FilenameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
FilenameBox.Font = Enum.Font.GothamBold
FilenameBox.TextSize = 8
FilenameBox.TextXAlignment = Enum.TextXAlignment.Center
FilenameBox.ClearTextOnFocus = false
FilenameBox.Parent = Content

local FilenameCorner = Instance.new("UICorner")
FilenameCorner.CornerRadius = UDim.new(0, 4)
FilenameCorner.Parent = FilenameBox

local WalkSpeedBox = Instance.new("TextBox")
WalkSpeedBox.Size = UDim2.fromOffset(60, 22)
WalkSpeedBox.Position = UDim2.fromOffset(174, 36)
WalkSpeedBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
WalkSpeedBox.BorderSizePixel = 0
WalkSpeedBox.Text = "16"
WalkSpeedBox.PlaceholderText = "WalkSpeed"
WalkSpeedBox.TextColor3 = Color3.fromRGB(255, 255, 255)
WalkSpeedBox.Font = Enum.Font.GothamBold
WalkSpeedBox.TextSize = 8
WalkSpeedBox.TextXAlignment = Enum.TextXAlignment.Center
WalkSpeedBox.ClearTextOnFocus = false
WalkSpeedBox.Parent = Content

local WalkSpeedCorner = Instance.new("UICorner")
WalkSpeedCorner.CornerRadius = UDim.new(0, 4)
WalkSpeedCorner.Parent = WalkSpeedBox

local SaveFileBtn = CreateButton("SAVE FILE", 0, 62, 115, 30, Color3.fromRGB(56, 128, 204))
local LoadFileBtn = CreateButton("LOAD FILE", 119, 62, 115, 30, Color3.fromRGB(56, 128, 204))

local PathToggleBtn = CreateButton("SHOW RUTE", 0, 96, 115, 30, Color3.fromRGB(56, 128, 204))
local MergeBtn = CreateButton("MERGE", 119, 96, 115, 30, Color3.fromRGB(56, 128, 204))

-- Toggle buttons
local LoopToggle, LoopToggleFrame, LoopKnob = CreateToggle("AutoLoop", 0, 130, 115, 22, false)
local ShiftLockToggle, ShiftLockToggleFrame, ShiftLockKnob = CreateToggle("ShiftLock", 119, 130, 115, 22, false)
local RespawnToggle, RespawnToggleFrame, RespawnKnob = CreateToggle("AutoRespawn", 0, 155, 115, 22, false)
local JumpToggle, JumpToggleFrame, JumpKnob = CreateToggle("InfJump", 119, 155, 115, 22, false)

-- Recording List
local RecordList = Instance.new("ScrollingFrame")
RecordList.Size = UDim2.new(1, 0, 0, 120)
RecordList.Position = UDim2.fromOffset(0, 180)
RecordList.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
RecordList.BorderSizePixel = 0
RecordList.ScrollBarThickness = 4
RecordList.ScrollBarImageColor3 = Color3.fromRGB(80, 120, 255)
RecordList.ScrollingDirection = Enum.ScrollingDirection.Y
RecordList.VerticalScrollBarInset = Enum.ScrollBarInset.Always
RecordList.CanvasSize = UDim2.new(0, 0, 0, 0)
RecordList.Parent = Content

local ListCorner = Instance.new("UICorner")
ListCorner.CornerRadius = UDim.new(0, 6)
ListCorner.Parent = RecordList

-- ========= TOGGLE ANIMATION FUNCTIONS =========
local function AnimateToggle(toggle, knob, isOn)
    PlaySound("Toggle")
    local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local bgColor = isOn and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(50, 50, 50)
    local knobPos = isOn and UDim2.new(0, 11, 0, 2) or UDim2.new(0, 2, 0, 2)
    TweenService:Create(toggle, tweenInfo, {BackgroundColor3 = bgColor}):Play()
    TweenService:Create(knob, tweenInfo, {Position = knobPos}):Play()
end

-- ========= CONNECT BUTTON EVENTS =========
MenuBtn.MouseButton1Click:Connect(function()
    SimpleButtonClick(MenuBtn)
    task.spawn(function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/arullwah/Wkwkwkw/refs/heads/main/library.lua", true))()
        end)
        
        if success then
            PlaySound("Success")
        else
            PlaySound("Error")
        end
    end)
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
                if Config.Features.AutoLoop then
                    StartAutoLoopAll()
                else
                    PlayRecording()
                end
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

SaveFileBtn.MouseButton1Click:Connect(function()
    SimpleButtonClick(SaveFileBtn)
    SaveToObfuscatedJSON()
end)

LoadFileBtn.MouseButton1Click:Connect(function()
    SimpleButtonClick(LoadFileBtn)
    LoadFromObfuscatedJSON()
end)

PathToggleBtn.MouseButton1Click:Connect(function()
    SimpleButtonClick(PathToggleBtn)
    Config.Features.ShowPaths = not Config.Features.ShowPaths
    if Config.Features.ShowPaths then
        PathToggleBtn.Text = "HIDE RUTE"
        VisualizeAllPaths()
    else
        PathToggleBtn.Text = "SHOW RUTE"
        ClearPathVisualization()
    end
end)

MergeBtn.MouseButton1Click:Connect(function()
    SimpleButtonClick(MergeBtn)
    CreateMergedReplay()
end)

-- Toggle connections
LoopToggle.MouseButton1Click:Connect(function()
    SimpleButtonClick(LoopToggle)
    Config.Features.AutoLoop = not Config.Features.AutoLoop
    AnimateToggle(LoopToggleFrame, LoopKnob, Config.Features.AutoLoop)
    
    if Config.Features.AutoLoop then
        if not next(RecordedMovements) then
            Config.Features.AutoLoop = false
            AnimateToggle(LoopToggleFrame, LoopKnob, false)
            return
        end
        
        if CurrentState == States.PLAYING then
            CurrentState = States.IDLE
            RestoreFullUserControl()
        end
        
        StartAutoLoopAll()
    else
        StopAutoLoopAll()
    end
end)

ShiftLockToggle.MouseButton1Click:Connect(function()
    SimpleButtonClick(ShiftLockToggle)
    ToggleVisibleShiftLock()
    AnimateToggle(ShiftLockToggleFrame, ShiftLockKnob, Config.Features.ShiftLock)
end)

RespawnToggle.MouseButton1Click:Connect(function()
    SimpleButtonClick(RespawnToggle)
    Config.Features.AutoRespawn = not Config.Features.AutoRespawn
    AnimateToggle(RespawnToggleFrame, RespawnKnob, Config.Features.AutoRespawn)
end)

JumpToggle.MouseButton1Click:Connect(function()
    SimpleButtonClick(JumpToggle)
    ToggleInfiniteJump()
    AnimateToggle(JumpToggleFrame, JumpKnob, Config.Features.InfiniteJump)
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
    if Config.Features.ShiftLock then DisableVisibleShiftLock() end
    if Config.Features.InfiniteJump then DisableInfiniteJump() end
    CleanupConnections()
    ClearPathVisualization()
    ScreenGui:Destroy()
    if MiniRecorderGUI then MiniRecorderGUI:Destroy() end
    if PlaybackGUI then PlaybackGUI:Destroy() end
end)

-- ========= VALIDATION FUNCTIONS =========
local function ValidateSpeed(speedText)
    local speed = tonumber(speedText)
    if not speed then return false, "Invalid number" end
    if speed < 0.25 or speed > 30 then return false, "Speed must be between 0.25 and 30" end
    local roundedSpeed = math.floor((speed * 4) + 0.5) / 4
    return true, roundedSpeed
end

SpeedBox.FocusLost:Connect(function()
    local success, result = ValidateSpeed(SpeedBox.Text)
    if success then
        CurrentSpeed = result
        SpeedBox.Text = string.format("%.2f", result)
        PlaySound("Success")
    else
        SpeedBox.Text = string.format("%.2f", CurrentSpeed)
        PlaySound("Error")
    end
end)

local function ValidateWalkSpeed(walkSpeedText)
    local walkSpeed = tonumber(walkSpeedText)
    if not walkSpeed then return false, "Invalid number" end
    if walkSpeed < 8 or walkSpeed > 200 then return false, "WalkSpeed must be between 8 and 200" end
    return true, walkSpeed
end

WalkSpeedBox.FocusLost:Connect(function()
    local success, result = ValidateWalkSpeed(WalkSpeedBox.Text)
    if success then
        CurrentWalkSpeed = result
        WalkSpeedBox.Text = tostring(result)
        local char = player.Character
        if char and char:FindFirstChildOfClass("Humanoid") then
            char.Humanoid.WalkSpeed = CurrentWalkSpeed
        end
        PlaySound("Success")
    else
        WalkSpeedBox.Text = tostring(CurrentWalkSpeed)
        PlaySound("Error")
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
    elseif input.KeyCode == Enum.KeyCode.F8 then
        -- Toggle floating GUIs
        if MiniRecorderGUI then
            MiniRecorderGUI.Enabled = not MiniRecorderGUI.Enabled
        end
        if PlaybackGUI then
            PlaybackGUI.Enabled = not PlaybackGUI.Enabled
        end
    elseif input.KeyCode == Enum.KeyCode.F7 then
        Config.Features.AutoLoop = not Config.Features.AutoLoop
        AnimateToggle(LoopToggleFrame, LoopKnob, Config.Features.AutoLoop)
        if Config.Features.AutoLoop then 
            StartAutoLoopAll() 
        else 
            StopAutoLoopAll() 
        end
    elseif input.KeyCode == Enum.KeyCode.F6 then
        SaveToObfuscatedJSON()
    elseif input.KeyCode == Enum.KeyCode.F5 then
        Config.Features.AutoRespawn = not Config.Features.AutoRespawn
        AnimateToggle(RespawnToggleFrame, RespawnKnob, Config.Features.AutoRespawn)
    elseif input.KeyCode == Enum.KeyCode.F4 then
        Config.Features.ShowPaths = not Config.Features.ShowPaths
        if Config.Features.ShowPaths then
            VisualizeAllPaths()
        else
            ClearPathVisualization()
        end
    elseif input.KeyCode == Enum.KeyCode.F3 then
        ToggleVisibleShiftLock()
        AnimateToggle(ShiftLockToggleFrame, ShiftLockKnob, Config.Features.ShiftLock)
    elseif input.KeyCode == Enum.KeyCode.F2 then
        ToggleInfiniteJump()
        AnimateToggle(JumpToggleFrame, JumpKnob, Config.Features.InfiniteJump)
    elseif input.KeyCode == Enum.KeyCode.LeftBracket then
        GoBackTimeline()
    elseif input.KeyCode == Enum.KeyCode.RightBracket then
        GoNextTimeline()
    end
end)

-- ========= INITIALIZATION =========
UpdateRecordList()

task.spawn(function()
    task.wait(2)
    local filename = "MyReplays.json"
    if isfile and readfile then
        if isfile(filename) then
            LoadFromObfuscatedJSON()
        end
    end
end)

player.CharacterRemoving:Connect(function()
    if CurrentState == States.RECORDING then
        StopRecording()
    end
    if CurrentState == States.PLAYING then
        StopPlayback()
    end
end)

game:GetService("ScriptContext").DescendantRemoving:Connect(function(descendant)
    if descendant == ScreenGui then
        CleanupConnections()
        ClearPathVisualization()
    end
end)

print("ByaruL Recorder Loaded Successfully!")
print("State: " .. CurrentState)
print("F9: Start/Stop Recording")
print("F10: Play/Stop Playback") 
print("F11: Toggle GUI")
print("F8: Toggle Floating GUI")
print("F7: AutoLoop On/Off")
print("F6: Save Recording")
print("F5: AutoRespawn On/Off")
print("F4: Show/Hide Path")
print("F3: ShiftLock On/Off")
print("F2: Infinite Jump On/Off")
print("[: Timeline Back | ]: Timeline Next")