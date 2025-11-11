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
    REVERSING = "reversing",
    FORWARDING = "forwarding",
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
        ReverseSpeed = 2.0,    -- Increased from 1.0
        ForwardSpeed = 3.0,    -- Increased from 1.0
        FixedTimestep = 1 / 60,
        ResumeDistance = 15,
        StateChangeCooldown = 0.01,
        TransitionFrames = 5
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
local PausedAtFrame = 0
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

local function ApplyFrameToCharacter(frame)
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = char.HumanoidRootPart
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
        end
    end)
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
    
    -- Potong frames setelah timeline position
    if TimelinePosition < #CurrentRecording.Frames then
        local newFrames = {}
        for i = 1, TimelinePosition do
            table.insert(newFrames, CurrentRecording.Frames[i])
        end
        CurrentRecording.Frames = newFrames
    end
    
    -- Update start time untuk melanjutkan
    if #CurrentRecording.Frames > 0 then
        local lastFrame = CurrentRecording.Frames[#CurrentRecording.Frames]
        CurrentRecording.StartTime = tick() - lastFrame.Timestamp
    end
    
    CurrentState = States.RECORDING
    PlaySound("Success")
end

-- ========= RECORDING FUNCTIONS =========
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
                MoveState = "Grounded",
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
    
    RecordedMovements[CurrentRecording.Name] = CurrentRecording.Frames
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
    PausedAtFrame = 0
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

            task.spawn(function()
                hrp.CFrame = GetFrameCFrame(frame)
                hrp.AssemblyLinearVelocity = GetFrameVelocity(frame)
                
                if hum then
                    hum.WalkSpeed = GetFrameWalkSpeed(frame) * CurrentSpeed
                    hum.AutoRotate = false
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

-- ========= RECORDING LIST FUNCTIONS =========
function UpdateRecordList()
    -- Implementation for record list UI
    -- (Same as original but adapted for new state system)
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

-- ========= CREATE MAIN GUI BUTTONS =========
local MenuBtn = CreateButton("MENU", 0, 2, 75, 30, Color3.fromRGB(56, 128, 204))
local FloatingBtn = CreateButton("FLOATING", 79, 2, 171, 30, Color3.fromRGB(56, 128, 204))

local SaveFileBtn = CreateButton("SAVE FILE", 0, 62, 115, 30, Color3.fromRGB(56, 128, 204))
local LoadFileBtn = CreateButton("LOAD FILE", 119, 62, 115, 30, Color3.fromRGB(56, 128, 204))

local PathToggleBtn = CreateButton("SHOW RUTE", 0, 96, 115, 30, Color3.fromRGB(56, 128, 204))
local MergeBtn = CreateButton("MERGE", 119, 96, 115, 30, Color3.fromRGB(56, 128, 204))

-- ========= CONNECT BUTTON EVENTS =========
MenuBtn.MouseButton1Click:Connect(function()
    SimpleButtonClick(MenuBtn)
    -- Menu functionality here
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

print("ByaruL Recorder Loaded Successfully!")
print("State: " .. CurrentState)
print("F9: Start/Stop Recording")
print("F10: Play/Stop Playback") 
print("F11: Toggle GUI")
print("[: Timeline Back | ]: Timeline Next")