-- ByaruL AutoWalk v3.1 - HYBRID SMART MOVEMENT
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

wait(1)

-- ========= CONFIGURATION =========
local RECORDING_FPS = 60
local MAX_FRAMES = 30000
local MIN_DISTANCE_THRESHOLD = 0.015
local VELOCITY_SCALE = 1
local VELOCITY_Y_SCALE = 1

-- ========= HYBRID MOVEMENT CONFIG =========
local HYBRID_MODE = true
local SMART_GROUND_DETECTION = true
local SMOOTH_INTERPOLATION = true
local INTERPOLATION_ALPHA = 0.4
local MIN_INTERPOLATION_DISTANCE = 0.3

-- ========= SMART GROUND SETTINGS =========
local NATURAL_GROUND_OFFSET = 2.5  -- Base offset untuk natural feel
local MAX_RAYCAST_DISTANCE = 15
local FOOT_CLEARANCE = 0.3  -- Jarak minimal kaki dari ground

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
local recordConnection = nil
local playbackConnection = nil
local loopConnection = nil
local jumpConnection = nil
local lastRecordTime = 0
local lastRecordPos = nil
local checkpointNames = {}
local PathVisualization = {}
local ShowPaths = false
local CurrentPauseMarker = nil

-- ========= REAL-TIME PLAYBACK VARIABLES =========
local lastPlaybackCFrame = nil
local lastPlaybackVelocity = Vector3.new(0, 0, 0)
local lastRealFrameTime = 0

-- ========= PAUSE/RESUME VARIABLES =========
local playbackStartTime = 0
local totalPausedDuration = 0
local pauseStartTime = 0
local currentPlaybackFrame = 1
local prePauseHumanoidState = nil
local prePauseWalkSpeed = 16
local prePauseAutoRotate = true
local prePauseJumpPower = 50
local prePausePlatformStand = false
local prePauseSit = false

-- ========= PLAYBACK STATE TRACKING =========
local lastPlaybackState = nil
local lastStateChangeTime = 0
local STATE_CHANGE_COOLDOWN = 0.15

-- ========= ENHANCED AUTO LOOP VARIABLES =========
local IsAutoLoopPlaying = false
local CurrentLoopIndex = 1
local LoopPauseStartTime = 0
local LoopTotalPausedDuration = 0
local CurrentReplayAttempts = 0
local MAX_REPLAY_ATTEMPTS = 5
local LastFrameTime = 0
local TARGET_FRAME_TIME = 1 / 60  -- 60 FPS target

-- ========= MEMORY MANAGEMENT =========
local activeConnections = {}

local function AddConnection(connection)
    table.insert(activeConnections, connection)
end

local function CleanupConnections()
    for _, connection in ipairs(activeConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    activeConnections = {}
    
    if recordConnection then
        recordConnection:Disconnect()
        recordConnection = nil
    end
    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end
    if loopConnection then
        loopConnection:Disconnect()
        loopConnection = nil
    end
    if jumpConnection then
        jumpConnection:Disconnect()
        jumpConnection = nil
    end
    
    -- Clear visualizations
    for _, part in pairs(PathVisualization) do
        pcall(function() part:Destroy() end)
    end
    PathVisualization = {}
    
    if CurrentPauseMarker then
        pcall(function() CurrentPauseMarker:Destroy() end)
        CurrentPauseMarker = nil
    end
end

-- ========= HYBRID MOVEMENT SYSTEM =========
local function GetSmartGroundHeight(position, character)
    if not SMART_GROUND_DETECTION then
        return position.Y
    end
    
    local rayOrigin = Vector3.new(position.X, position.Y + 3, position.Z)
    local rayDirection = Vector3.new(0, -MAX_RAYCAST_DISTANCE, 0)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    if character then
        raycastParams.FilterDescendantsInstances = {character}
    end
    
    local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    
    if rayResult then
        return rayResult.Position.Y + NATURAL_GROUND_OFFSET + FOOT_CLEARANCE
    end
    
    -- Fallback: check surrounding area
    local checkOffsets = {
        Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
        Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
        Vector3.new(0.5, 0, 0.5), Vector3.new(-0.5, 0, -0.5)
    }
    
    for _, offset in ipairs(checkOffsets) do
        local checkOrigin = rayOrigin + offset
        rayResult = workspace:Raycast(checkOrigin, rayDirection, raycastParams)
        if rayResult then
            return rayResult.Position.Y + NATURAL_GROUND_OFFSET + FOOT_CLEARANCE
        end
    end
    
    -- Jika tidak ada ground terdeteksi, return original position dengan offset natural
    return position.Y + NATURAL_GROUND_OFFSET
end

local function ApplyHybridVelocity(character, velocity)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    
    -- Hybrid approach: Gunakan assembly velocity dengan gentle handling
    local success = pcall(function()
        hrp.AssemblyLinearVelocity = velocity
        -- Biarkan angular velocity natural untuk rotation yang smooth
    end)
    
    if not success then
        -- Fallback: BodyVelocity dengan force yang lebih gentle
        local bodyVelocity = hrp:FindFirstChild("AutoWalkBodyVelocity")
        if not bodyVelocity then
            bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.Name = "AutoWalkBodyVelocity"
            bodyVelocity.MaxForce = Vector3.new(1500, 0, 1500)  -- Reduced force untuk natural movement
            bodyVelocity.Parent = hrp
        end
        bodyVelocity.Velocity = velocity
    end
    
    -- Pastikan humanoid state natural
    if humanoid then
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
    end
    
    return true
end

local function HybridCFrameLerp(currentCF, targetCF, alpha)
    if not SMOOTH_INTERPOLATION then
        return targetCF
    end
    
    local currentPos = currentCF.Position
    local targetPos = targetCF.Position
    local distance = (targetPos - currentPos).Magnitude
    
    -- Skip interpolation untuk teleport
    if distance > 20 then
        return targetCF
    end
    
    -- Smooth position dengan easing
    local newPos = currentPos:Lerp(targetPos, alpha)
    
    -- Smart ground adjustment hanya jika diperlukan
    if SMART_GROUND_DETECTION and distance < 5 then
        local char = player.Character
        local groundHeight = GetSmartGroundHeight(newPos, char)
        if newPos.Y < groundHeight then
            newPos = Vector3.new(newPos.X, groundHeight, newPos.Z)
        end
    end
    
    -- Smooth rotation
    local newCF = currentCF:Lerp(targetCF, alpha)
    
    return CFrame.new(newPos) * (newCF - newCF.Position)
end

-- ========= HIGH FPS SYSTEM =========
local function ShouldProcessFrame()
    local currentTime = tick()
    if currentTime - LastFrameTime >= TARGET_FRAME_TIME then
        LastFrameTime = currentTime
        return true
    end
    return false
end

-- ========= CAMERA STABILIZATION =========
local function StabilizeCameraHybrid()
    local camera = workspace.CurrentCamera
    if not camera then return end
    
    pcall(function()
        camera.CameraType = Enum.CameraType.Custom
        -- Jangan force CFrame untuk prevent jitter
    end)
end

-- ========= HYBRID HUMANOID CONTROL =========
local function HybridStateControl(humanoid, targetState)
    if not humanoid then return end
    
    pcall(function()
        local currentState = humanoid:GetState()
        local currentTime = tick()
        
        -- Cooldown untuk prevent state spam
        if (currentTime - lastStateChangeTime) < STATE_CHANGE_COOLDOWN then
            return
        end
        
        -- Smart state management
        if targetState == "Climbing" and currentState ~= Enum.HumanoidStateType.Climbing then
            humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
            lastStateChangeTime = currentTime
        elseif targetState == "Jumping" and currentState ~= Enum.HumanoidStateType.Jumping then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            lastStateChangeTime = currentTime
        elseif targetState == "Falling" and currentState ~= Enum.HumanoidStateType.Freefall then
            humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
            lastStateChangeTime = currentTime
        elseif targetState == "Swimming" and currentState ~= Enum.HumanoidStateType.Swimming then
            humanoid:ChangeState(Enum.HumanoidStateType.Swimming)
            lastStateChangeTime = currentTime
        else
            -- Untuk grounded states, biarkan humanoid natural
            if currentState == Enum.HumanoidStateType.Freefall or 
               currentState == Enum.HumanoidStateType.Jumping then
                humanoid:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
                lastStateChangeTime = currentTime
            end
        end
    end)
end

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

-- ========= SOUND SYSTEM =========
local function PlaySound(soundType)
    pcall(function()
        local sound = Instance.new("Sound")
        sound.SoundId = SoundEffects[soundType] or SoundEffects.Click
        sound.Volume = 0.3
        sound.Parent = workspace
        sound:Play()
        game:GetService("Debris"):AddItem(sound, 2)
    end)
end

-- ========= ENHANCED BUTTON ANIMATION =========
local function AnimateButtonClick(button)
    PlaySound("Click")
    
    local originalSize = button.Size
    local tweenInfo = TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    
    TweenService:Create(button, tweenInfo, {
        Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset - 4, originalSize.Y.Scale, originalSize.Y.Offset - 4)
    }):Play()
    
    local originalColor = button.BackgroundColor3
    local brighterColor = Color3.new(
        math.min(originalColor.R * 1.3, 1),
        math.min(originalColor.G * 1.3, 1), 
        math.min(originalColor.B * 1.3, 1)
    )
    
    TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundColor3 = brighterColor
    }):Play()
    
    wait(0.1)
    TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
        Size = originalSize,
        BackgroundColor3 = originalColor
    }):Play()
end

-- ========= AUTO RESPAWN FUNCTION =========
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
        if tick() - startTime > timeout then
            return false
        end
    until player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChildOfClass("Humanoid") and player.Character.Humanoid.Health > 0
    
    task.wait(1)
    return true
end

-- ========= CHARACTER READY CHECK =========
local function IsCharacterReady()
    local char = player.Character
    if not char then return false end
    if not char:FindFirstChild("HumanoidRootPart") then return false end
    if not char:FindFirstChildOfClass("Humanoid") then return false end
    if char.Humanoid.Health <= 0 then return false end
    return true
end

-- ========= ENHANCED CHARACTER RESET =========
local function CompleteCharacterReset(char)
    if not char or not char:IsDescendantOf(workspace) then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then return end
    pcall(function()
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
        humanoid.WalkSpeed = CurrentWalkSpeed
        humanoid.JumpPower = 50
        humanoid.Sit = false
        ApplyHybridVelocity(char, Vector3.new(0, 0, 0))
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
        
        -- Clean up BodyVelocity
        local bodyVelocity = hrp:FindFirstChild("AutoWalkBodyVelocity")
        if bodyVelocity then
            bodyVelocity:Destroy()
        end
    end)
end

-- ========= INFINITE JUMP SYSTEM =========
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

-- ========= IMPROVED PAUSE SYSTEM =========
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
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
    if humanoid then
        humanoid.AutoRotate = prePauseAutoRotate
        humanoid.WalkSpeed = prePauseWalkSpeed
        humanoid.JumpPower = prePauseJumpPower
        humanoid.PlatformStand = prePausePlatformStand
        humanoid.Sit = prePauseSit
    end
end

-- ========= FULL USER CONTROL RESTORATION =========
local function RestoreFullUserControl()
    local char = player.Character
    if not char then return end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
    if humanoid then
        humanoid.AutoRotate = true
        humanoid.WalkSpeed = CurrentWalkSpeed
        humanoid.JumpPower = 50
        humanoid.PlatformStand = false
        humanoid.Sit = false
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end
    
    if hrp then
        pcall(function() 
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end)
        
        -- Clean up BodyVelocity
        local bodyVelocity = hrp:FindFirstChild("AutoWalkBodyVelocity")
        if bodyVelocity then
            bodyVelocity:Destroy()
        end
    end
    
    lastPlaybackCFrame = nil
    lastPlaybackVelocity = Vector3.new(0, 0, 0)
end

-- ========= PERFECT JUMP DETECTION =========
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

-- ========= PATH VISUALIZATION FUNCTIONS =========
local function ClearPathVisualization()
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
    label.Text = "⏸️ PAUSED"
    label.TextColor3 = Color3.new(1, 1, 0)
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBold
    label.TextSize = 18
    label.TextScaled = false
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

-- ========= SIMPLIFIED FRAME DATA FUNCTIONS =========
local function GetFramePosition(frame)
    return Vector3.new(frame.Position[1], frame.Position[2], frame.Position[3])
end

local function GetFrameCFrame(frame)
    local pos = GetFramePosition(frame)
    local look = Vector3.new(frame.LookVector[1], frame.LookVector[2], frame.LookVector[3])
    local up = Vector3.new(frame.UpVector[1], frame.UpVector[2], frame.UpVector[3])
    
    -- HYBRID: Smart ground adjustment hanya jika diperlukan
    if SMART_GROUND_DETECTION then
        local char = player.Character
        local groundHeight = GetSmartGroundHeight(pos, char)
        if pos.Y < groundHeight then
            pos = Vector3.new(pos.X, groundHeight, pos.Z)
        end
    end
    
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

-- ========= HIGH FPS PLAYBACK SYSTEM =========
local function PlayRecordingWithCFrame(recording, startFrame)
    if not recording or #recording == 0 then return end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
    if not hum or not hrp then return end

    local currentFrame = startFrame or 1
    playbackStartTime = tick()
    totalPausedDuration = 0
    pauseStartTime = 0
    lastPlaybackState = nil
    LastFrameTime = tick()
    
    lastPlaybackCFrame = hrp.CFrame
    lastPlaybackVelocity = Vector3.new(0, 0, 0)

    playbackConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not IsPlaying then
            playbackConnection:Disconnect()
            RestoreFullUserControl()
            return
        end
        
        -- HIGH FPS: Skip frame jika belum waktunya
        if not ShouldProcessFrame() then
            return
        end
        
        -- IMPROVED PAUSE SYSTEM - FULL STOP
        if IsPaused then
            if pauseStartTime == 0 then
                pauseStartTime = tick()
                RestoreHumanoidState()
                ApplyHybridVelocity(char, Vector3.new(0, 0, 0)) -- FULL STOP
                UpdatePauseMarker()
            end
            return
        else
            if pauseStartTime > 0 then
                totalPausedDuration = totalPausedDuration + (tick() - pauseStartTime)
                pauseStartTime = 0
                SaveHumanoidState()
                UpdatePauseMarker()
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
        
        local targetFrameIndex = 1
        for i = 1, #recording do
            if GetFrameTimestamp(recording[i]) <= effectiveTime then
                targetFrameIndex = i
            else
                break
            end
        end
        
        currentFrame = targetFrameIndex

        if currentFrame >= #recording then
            IsPlaying = false
            IsPaused = false
            lastPlaybackState = nil
            
            local finalFrame = recording[#recording]
            if finalFrame then
                pcall(function()
                    hrp.CFrame = GetFrameCFrame(finalFrame)
                    ApplyHybridVelocity(char, Vector3.new(0, 0, 0))
                end)
            end
            
            RestoreFullUserControl()
            UpdatePauseMarker()
            playbackConnection:Disconnect()
            PlaySound("Stop")
            return
        end

        local targetFrame = recording[currentFrame]
        if not targetFrame then return end

        pcall(function()
            -- Camera stabilization
            StabilizeCameraHybrid()
            
            local targetCFrame = GetFrameCFrame(targetFrame)
            local targetVelocity = GetFrameVelocity(targetFrame) * CurrentSpeed
            
            -- Hybrid smooth interpolation
            local smoothCFrame = HybridCFrameLerp(hrp.CFrame, targetCFrame, INTERPOLATION_ALPHA)
            local smoothVelocity = lastPlaybackVelocity:Lerp(targetVelocity, INTERPOLATION_ALPHA)
            
            -- Apply hybrid movement
            hrp.CFrame = smoothCFrame
            ApplyHybridVelocity(char, smoothVelocity)
            
            lastPlaybackCFrame = smoothCFrame
            lastPlaybackVelocity = smoothVelocity
            
            hum.WalkSpeed = GetFrameWalkSpeed(targetFrame) * CurrentSpeed
            
            local moveState = targetFrame.MoveState
            local currentStateTime = tick()
            
            if moveState ~= lastPlaybackState and (currentStateTime - lastStateChangeTime) > STATE_CHANGE_COOLDOWN then
                lastPlaybackState = moveState
                lastStateChangeTime = currentStateTime
                HybridStateControl(hum, moveState)
            end
            
            currentPlaybackFrame = currentFrame
            
            if FrameLabel then
                FrameLabel.Text = string.format("Frame: %d/%d", currentPlaybackFrame, #recording)
            end
        end)
    end)
    
    AddConnection(playbackConnection)
end

-- ========= HIGH FPS AUTO LOOP SYSTEM =========
local function PlaySingleRecording(recordingName)
    local recording = RecordedMovements[recordingName]
    if not recording or #recording == 0 then 
        return false 
    end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then 
        return false 
    end
    
    SaveHumanoidState()
    
    local framePlaybackStart = tick()
    local framePausedTime = 0
    local framePauseStart = 0
    local currentFrame = 1
    LastFrameTime = tick()
    
    if char and char:FindFirstChild("HumanoidRootPart") then
        lastPlaybackCFrame = char.HumanoidRootPart.CFrame
        lastPlaybackVelocity = Vector3.new(0, 0, 0)
    end
    
    local playbackCompleted = false
    local playbackFailed = false
    
    local singlePlaybackConnection
    singlePlaybackConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not AutoLoop or not IsAutoLoopPlaying then
            singlePlaybackConnection:Disconnect()
            return
        end
        
        -- HIGH FPS: Skip frame jika belum waktunya
        if not ShouldProcessFrame() then
            return
        end
        
        -- IMPROVED PAUSE SYSTEM
        if IsPaused then
            if framePauseStart == 0 then
                framePauseStart = tick()
                RestoreHumanoidState()
                ApplyHybridVelocity(char, Vector3.new(0, 0, 0)) -- FULL STOP
                UpdatePauseMarker()
            end
            return
        else
            if framePauseStart > 0 then
                framePausedTime = framePausedTime + (tick() - framePauseStart)
                framePauseStart = 0
                SaveHumanoidState()
                UpdatePauseMarker()
            end
        end
        
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            playbackFailed = true
            singlePlaybackConnection:Disconnect()
            return
        end
        
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp or hum.Health <= 0 then
            playbackFailed = true
            singlePlaybackConnection:Disconnect()
            return
        end
        
        local currentTime = tick()
        local effectiveTime = (currentTime - framePlaybackStart - framePausedTime) * CurrentSpeed
        
        local targetFrameIndex = 1
        for i = 1, #recording do
            if GetFrameTimestamp(recording[i]) <= effectiveTime then
                targetFrameIndex = i
            else
                break
            end
        end
        
        currentFrame = targetFrameIndex
        
        if currentFrame >= #recording then
            playbackCompleted = true
            singlePlaybackConnection:Disconnect()
            return
        end
        
        local targetFrame = recording[currentFrame]
        if not targetFrame then return end

        pcall(function()
            StabilizeCameraHybrid()
            
            local targetCFrame = GetFrameCFrame(targetFrame)
            local targetVelocity = GetFrameVelocity(targetFrame) * CurrentSpeed
            
            local smoothCFrame = HybridCFrameLerp(hrp.CFrame, targetCFrame, 0.4)
            local smoothVelocity = lastPlaybackVelocity:Lerp(targetVelocity, 0.4)
            
            hrp.CFrame = smoothCFrame
            ApplyHybridVelocity(char, smoothVelocity)
            
            lastPlaybackCFrame = smoothCFrame
            lastPlaybackVelocity = smoothVelocity
            
            hum.WalkSpeed = GetFrameWalkSpeed(targetFrame) * CurrentSpeed
            
            local moveState = targetFrame.MoveState
            if moveState ~= lastPlaybackState then
                lastPlaybackState = moveState
                HybridStateControl(hum, moveState)
            end
        end)
    end)
    
    AddConnection(singlePlaybackConnection)
    
    local startWait = tick()
    while AutoLoop and IsAutoLoopPlaying and not playbackCompleted and not playbackFailed do
        if tick() - startWait > 120 then
            break
        end
        task.wait(0.05)  -- Reduced wait time untuk responsiveness
    end
    
    singlePlaybackConnection:Disconnect()
    RestoreFullUserControl()
    
    return playbackCompleted, playbackFailed
end

local function StartAutoLoopAll()
    if IsAutoLoopPlaying then 
        return 
    end
    
    if not AutoLoop then 
        return 
    end
    
    if #RecordingOrder == 0 then
        PlaySound("Error")
        return
    end
    
    PlaySound("Play")
    
    CurrentLoopIndex = 1
    IsAutoLoopPlaying = true
    lastPlaybackState = nil
    CurrentReplayAttempts = 0
    LastFrameTime = tick()
    
    loopConnection = RunService.Heartbeat:Connect(function()
        if not AutoLoop or not IsAutoLoopPlaying then
            if loopConnection then
                loopConnection:Disconnect()
                loopConnection = nil
            end
            IsAutoLoopPlaying = false
            return
        end
        
        while AutoLoop and IsAutoLoopPlaying and CurrentLoopIndex <= #RecordingOrder do
            local recordingName = RecordingOrder[CurrentLoopIndex]
            local maxRetries = 5
            local retryCount = 0
            local characterReady = false
            
            -- Wait for character to be ready
            while not characterReady and retryCount < maxRetries do
                if not IsCharacterReady() then
                    if AutoRespawn then
                        ResetCharacter()
                    end
                    
                    local waitStart = tick()
                    while not IsCharacterReady() do
                        if tick() - waitStart > 10 then
                            break
                        end
                        task.wait(0.3)  -- Reduced wait time
                    end
                end
                
                characterReady = IsCharacterReady()
                retryCount = retryCount + 1
                
                if not characterReady and retryCount < maxRetries then
                    task.wait(0.5)
                end
            end
            
            if not AutoLoop or not IsAutoLoopPlaying then break end
            
            if not characterReady then
                -- Skip jika karakter tidak ready setelah retry
                CurrentLoopIndex = CurrentLoopIndex + 1
                if CurrentLoopIndex > #RecordingOrder then
                    CurrentLoopIndex = 1
                end
                task.wait(1)  -- Reduced wait time
                continue
            end
            
            -- Play current replay
            local success, failed = PlaySingleRecording(recordingName)
            
            if not AutoLoop or not IsAutoLoopPlaying then break end
            
            if success then
                -- Successfully completed replay, move to next
                CurrentLoopIndex = CurrentLoopIndex + 1
                CurrentReplayAttempts = 0
                if CurrentLoopIndex > #RecordingOrder then
                    CurrentLoopIndex = 1
                end
            elseif failed then
                -- Playback failed (character died), retry current replay
                CurrentReplayAttempts = CurrentReplayAttempts + 1
                
                if CurrentReplayAttempts >= MAX_REPLAY_ATTEMPTS then
                    -- Too many failures, skip to next replay
                    CurrentLoopIndex = CurrentLoopIndex + 1
                    CurrentReplayAttempts = 0
                    if CurrentLoopIndex > #RecordingOrder then
                        CurrentLoopIndex = 1
                    end
                else
                    -- Retry current replay
                    print("🔄 AutoLoop: Retrying replay due to failure (" .. CurrentReplayAttempts .. "/" .. MAX_REPLAY_ATTEMPTS .. ")")
                end
            else
                -- Other failure, move to next replay
                CurrentLoopIndex = CurrentLoopIndex + 1
                CurrentReplayAttempts = 0
                if CurrentLoopIndex > #RecordingOrder then
                    CurrentLoopIndex = 1
                end
            end
            
            task.wait(0.3)  -- Reduced pause between replays
        end
    end)
    
    AddConnection(loopConnection)
end

local function StopAutoLoopAll()
    AutoLoop = false
    IsAutoLoopPlaying = false
    IsPlaying = false
    IsPaused = false
    lastPlaybackState = nil
    CurrentReplayAttempts = 0
    
    if loopConnection then
        loopConnection:Disconnect()
        loopConnection = nil
    end
    
    RestoreFullUserControl()
    UpdatePauseMarker()
    
    local char = player.Character
    if char then CompleteCharacterReset(char) end
    
    PlaySound("Stop")
end

-- ========= GUI SETUP =========
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoWalkByaruL"
ScreenGui.ResetOnSpawn = false

if syn and syn.protect_gui then
    syn.protect_gui(ScreenGui)
    ScreenGui.Parent = game:GetService("CoreGui")
elseif gethui then
    ScreenGui.Parent = gethui()
elseif game:GetService("CoreGui"):FindFirstChild("RobloxGui") then
    ScreenGui.Parent = game:GetService("CoreGui")
else
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
Title.Text = "ByaruL - Hybrid v3.1"
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

-- Enhanced Button Creation
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
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0,0,0)
    stroke.Thickness = 1.0
    stroke.Transparency = 0.0
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
        PlaySound("Toggle")
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

-- TOGGLE LAYOUT
local LoopBtn, AnimateLoop = CreateToggle("Auto Loop", 0, 75, 78, 22, false)
local JumpBtn, AnimateJump = CreateToggle("Infinite Jump", 82, 75, 78, 22, false)
local RespawnBtn, AnimateRespawn = CreateToggle("Auto Respawn", 164, 75, 78, 22, false)

-- ========= TEXTBOX LAYOUT =========
local SpeedBox = Instance.new("TextBox")
SpeedBox.Size = UDim2.fromOffset(55, 26)
SpeedBox.Position = UDim2.fromOffset(5, 102)
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
FilenameBox.Position = UDim2.fromOffset(65, 102)
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
WalkSpeedBox.Position = UDim2.fromOffset(180, 102)
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

local SaveFileBtn = CreateButton("SAVE FILE", 0, 133, 117, 26, Color3.fromRGB(59, 15, 116))
local LoadFileBtn = CreateButton("LOAD FILE", 123, 133, 117, 26, Color3.fromRGB(59, 15, 116))

local PathToggleBtn = CreateButton("SHOW RUTE", 0, 164, 117, 26, Color3.fromRGB(59, 15, 116))
local MergeBtn = CreateButton("MERGE", 123, 164, 117, 26, Color3.fromRGB(59, 15, 116))

-- Record List
local RecordList = Instance.new("ScrollingFrame")
RecordList.Size = UDim2.new(1, 0, 0, 120)
RecordList.Position = UDim2.fromOffset(0, 195)
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

-- Speed validation function
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

-- WalkSpeed validation function
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

-- ========= REORDER FUNCTIONS =========
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

-- ========= FORMAT DURATION FUNCTION =========
local function FormatDuration(seconds)
    local minutes = math.floor(seconds / 60)
    local remainingSeconds = math.floor(seconds % 60)
    return string.format("%d:%02d", minutes, remainingSeconds)
end

-- ========= UPDATED RECORD LIST =========
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
        infoLabel.Parent = infoRow
        
        if #rec > 0 then
            local totalSeconds = rec[#rec].Timestamp
            infoLabel.Text = "✔️ " .. FormatDuration(totalSeconds) .. " • " .. #rec .. " frames • HYBRID"
        else
            infoLabel.Text = "❌ 0:00 • 0 frames • HYBRID"
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
            PlaySound("Toggle")
        end)
        
        upBtn.MouseButton1Click:Connect(function()
            if index > 1 then 
                AnimateButtonClick(upBtn)
                MoveRecordingUp(name) 
            end
        end)
        
        downBtn.MouseButton1Click:Connect(function()
            if index < #RecordingOrder then 
                AnimateButtonClick(downBtn)
                MoveRecordingDown(name) 
            end
        end)
        
        playBtn.MouseButton1Click:Connect(function()
            if not IsPlaying then 
                AnimateButtonClick(playBtn)
                PlayRecording(name) 
            end
        end)
        
        delBtn.MouseButton1Click:Connect(function()
            AnimateButtonClick(delBtn)
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
                PlaySound("Success")
            end
        end)
        
        yPos = yPos + 53
    end
    
    RecordList.CanvasSize = UDim2.new(0, 0, 0, math.max(yPos, RecordList.AbsoluteSize.Y))
end

-- ========= OPTIMIZED RECORDING SYSTEM =========
local lastFrameTime = 0
local frameInterval = 1 / RECORDING_FPS

local function ShouldRecordFrame()
    local currentTime = tick()
    return (currentTime - lastFrameTime) >= frameInterval
end

-- ========= AUTOMATIC SAVE SYSTEM =========
local function AutoSaveRecording()
    if #CurrentRecording.Frames == 0 then
        PlaySound("Error")
        return
    end
    
    local name = CurrentRecording.Name
    RecordedMovements[name] = CurrentRecording.Frames
    table.insert(RecordingOrder, name)
    checkpointNames[name] = "checkpoint_" .. #RecordingOrder
    SelectedReplays[name] = false
    
    UpdateRecordList()
    
    PlaySound("Success")
    
    CurrentRecording = {Frames = {}, StartTime = 0, Name = "recording_" .. os.date("%H%M%S")}
end

function StartRecording()
    if IsRecording then return end
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        PlaySound("Error")
        return
    end
    
    IsRecording = true
    CurrentRecording = {Frames = {}, StartTime = tick(), Name = "recording_" .. os.date("%H%M%S")}
    lastRecordTime = 0
    lastRecordPos = nil
    lastFrameTime = 0
    
    RecordBtnBig.Text = "STOP RECORDING"
    RecordBtnBig.BackgroundColor3 = Color3.fromRGB(163, 10, 10)
    
    PlaySound("RecordStart")
    
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

        local velY = currentVelocity.Y
        if moveState == "Falling" and velY > 10 then
            moveState = "Jumping"
        elseif velY > 40 then
            moveState = "Jumping"
        end

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
            Timestamp = tick() - CurrentRecording.StartTime
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
        AutoSaveRecording()
    end
    
    RecordBtnBig.Text = "RECORDING"
    RecordBtnBig.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
    
    PlaySound("RecordStop")
    FrameLabel.Text = "Frames: 0"
end

-- ========= SIMPLIFIED PLAYBACK SYSTEM =========
function PlayRecording(name)
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
    totalPausedDuration = 0
    pauseStartTime = 0
    lastPlaybackState = nil

    currentPlaybackFrame = 1
    playbackStartTime = tick()

    SaveHumanoidState()
    PlaySound("Play")

    PlayRecordingWithCFrame(recording, currentPlaybackFrame)
end

-- ========= IMPROVED PAUSE SYSTEM =========
function PausePlayback()
    if not IsPlaying and not IsAutoLoopPlaying then return end
    
    IsPaused = not IsPaused
    
    if IsPaused then
        PauseBtnBig.Text = "RESUME"
        PauseBtnBig.BackgroundColor3 = Color3.fromRGB(8, 181, 116)
        RestoreHumanoidState()
        -- FULL STOP ketika pause
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            ApplyHybridVelocity(char, Vector3.new(0, 0, 0))
        end
        UpdatePauseMarker()
        PlaySound("Click")
    else
        PauseBtnBig.Text = "PAUSE"
        PauseBtnBig.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
        SaveHumanoidState()
        UpdatePauseMarker()
        PlaySound("Click")
    end
end

function StopPlayback()
    if AutoLoop then
        StopAutoLoopAll()
        AnimateLoop(false)
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
    UpdatePauseMarker()
    
    local char = player.Character
    if char then CompleteCharacterReset(char) end
    
    PlaySound("Stop")
end

-- ========= ENHANCED SAVE SYSTEM =========
local function SaveToJSON()
    local filename = FilenameBox.Text
    if filename == "" then filename = "MyReplays" end
    filename = filename .. ".json"
    
    if not next(RecordedMovements) then
        PlaySound("Error")
        return
    end
    
    local success, err = pcall(function()
        local saveData = {
            Version = "3.1",
            Checkpoints = {},
            RecordingOrder = RecordingOrder,
            CheckpointNames = checkpointNames
        }
        
        -- Jika ada yang dicentang, save hanya yang dicentang
        -- Jika tidak ada yang dicentang, save semua
        local hasSelected = false
        for name, isSelected in pairs(SelectedReplays) do
            if isSelected then
                hasSelected = true
                break
            end
        end
        
        for name, frames in pairs(RecordedMovements) do
            -- Save hanya jika: tidak ada yang dicentang ATAU yang ini dicentang
            if not hasSelected or SelectedReplays[name] then
                local checkpointData = {
                    Name = name,
                    DisplayName = checkpointNames[name] or "checkpoint",
                    Frames = frames
                }
                table.insert(saveData.Checkpoints, checkpointData)
            end
        end
        
        local jsonString = HttpService:JSONEncode(saveData)
        
        if writefile then
            writefile(filename, jsonString)
            PlaySound("Success")
        else
            PlaySound("Error")
        end
    end)
    
    if not success then
        PlaySound("Error")
    end
end

local function LoadFromJSON()
    local filename = FilenameBox.Text
    if filename == "" then filename = "MyReplays" end
    filename = filename .. ".json"
    
    local success, err = pcall(function()
        if not readfile or not isfile then
            PlaySound("Error")
            return
        end
        
        if not isfile(filename) then
            PlaySound("Error")
            return
        end
        
        local jsonString = readfile(filename)
        local saveData = HttpService:JSONDecode(jsonString)
        
        RecordedMovements = {}
        RecordingOrder = saveData.RecordingOrder or {}
        checkpointNames = saveData.CheckpointNames or {}
        SelectedReplays = {}
        
        for _, checkpointData in ipairs(saveData.Checkpoints or {}) do
            local name = checkpointData.Name
            local frames = checkpointData.Frames
            
            if frames then
                RecordedMovements[name] = frames
                SelectedReplays[name] = false
            end
        end
        
        UpdateRecordList()
        PlaySound("Success")
    end)
    
    if not success then
        PlaySound("Error")
    end
end

-- ========= PATH VISUALIZATION FOR ALL RECORDINGS =========
local function VisualizeAllPaths()
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

-- ========= BUTTON EVENTS =========
RecordBtnBig.MouseButton1Click:Connect(function()
    AnimateButtonClick(RecordBtnBig)
    if IsRecording then 
        StopRecording() 
    else 
        StartRecording() 
    end
end)

PlayBtnBig.MouseButton1Click:Connect(function()
    AnimateButtonClick(PlayBtnBig)
    if AutoLoop then return end
    PlayRecording()
end)

StopBtnBig.MouseButton1Click:Connect(function()
    AnimateButtonClick(StopBtnBig)
    StopPlayback()
end)

PauseBtnBig.MouseButton1Click:Connect(function()
    AnimateButtonClick(PauseBtnBig)
    PausePlayback()
end)

LoopBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(LoopBtn)
    AutoLoop = not AutoLoop
    AnimateLoop(AutoLoop)
    
    if AutoLoop then
        if #RecordingOrder == 0 then
            AutoLoop = false
            AnimateLoop(false)
            PlaySound("Error")
            return
        end
        
        if IsPlaying then
            IsPlaying = false
            IsPaused = false
            RestoreFullUserControl()
        end
        
        StartAutoLoopAll()
    else
        StopAutoLoopAll()
    end
end)

RespawnBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(RespawnBtn)
    AutoRespawn = not AutoRespawn
    AnimateRespawn(AutoRespawn)
    PlaySound("Toggle")
end)

JumpBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(JumpBtn)
    ToggleInfiniteJump()
    AnimateJump(InfiniteJump)
    PlaySound("Toggle")
end)

SaveFileBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(SaveFileBtn)
    SaveToJSON()
end)

LoadFileBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(LoadFileBtn)
    LoadFromJSON()
end)

PathToggleBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(PathToggleBtn)
    ShowPaths = not ShowPaths
    if ShowPaths then
        PathToggleBtn.Text = "HIDE RUTE"
        VisualizeAllPaths()
    else
        PathToggleBtn.Text = "SHOW RUTE"
        ClearPathVisualization()
    end
end)

MergeBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(MergeBtn)
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
    SelectedReplays[mergedName] = false
    
    UpdateRecordList()
    PlaySound("Success")
end)

HideButton.MouseButton1Click:Connect(function()
    AnimateButtonClick(HideButton)
    MainFrame.Visible = false
    MiniButton.Visible = true
end)

MiniButton.MouseButton1Click:Connect(function()
    AnimateButtonClick(MiniButton)
    MainFrame.Visible = true
    MiniButton.Visible = false
end)

CloseButton.MouseButton1Click:Connect(function()
    AnimateButtonClick(CloseButton)
    if IsRecording then StopRecording() end
    if IsPlaying or AutoLoop then StopPlayback() end
    if InfiniteJump then DisableInfiniteJump() end
    CleanupConnections()
    ClearPathVisualization()
    ScreenGui:Destroy()
end)

-- ========= HTTPS SUPPORT FOR GUI =========
local function LoadGUIFromURL(url)
    local success, result = pcall(function()
        local httpService = game:GetService("HttpService")
        local response = httpService:GetAsync(url)
        return response
    end)
    
    if success then
        return result
    else
        warn("Failed to load GUI from URL: " .. tostring(result))
        return nil
    end
end

-- ========= HOTKEYS =========
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F9 then
        if IsRecording then StopRecording() else StartRecording() end
    elseif input.KeyCode == Enum.KeyCode.F10 then
        if IsPlaying or AutoLoop then StopPlayback() else PlayRecording() end
    elseif input.KeyCode == Enum.KeyCode.F11 then
        MainFrame.Visible = not MainFrame.Visible
        MiniButton.Visible = not MainFrame.Visible
    elseif input.KeyCode == Enum.KeyCode.F8 then
        local char = player.Character
        if char then CompleteCharacterReset(char) end
    elseif input.KeyCode == Enum.KeyCode.F7 then
        AutoLoop = not AutoLoop
        AnimateLoop(AutoLoop)
        if AutoLoop then 
            StartAutoLoopAll() 
        else 
            StopAutoLoopAll() 
        end
    elseif input.KeyCode == Enum.KeyCode.F6 then
        SaveToJSON()
    elseif input.KeyCode == Enum.KeyCode.F5 then
        AutoRespawn = not AutoRespawn
        AnimateRespawn(AutoRespawn)
    elseif input.KeyCode == Enum.KeyCode.F4 then
        ShowPaths = not ShowPaths
        if ShowPaths then
            PathToggleBtn.Text = "HIDE RUTE"
            VisualizeAllPaths()
        else
            PathToggleBtn.Text = "SHOW RUTE"
            ClearPathVisualization()
        end
    elseif input.KeyCode == Enum.KeyCode.F2 then
        ToggleInfiniteJump()
        AnimateJump(InfiniteJump)
    end
end)

-- ========= INITIAL SETUP =========
UpdateRecordList()

task.spawn(function()
    task.wait(2)
    local filename = "MyReplays.json"
    if readfile and isfile and isfile(filename) then
        LoadFromJSON()
    end
end)

player.CharacterRemoving:Connect(function()
    if IsRecording then
        StopRecording()
    end
    if IsPlaying then
        IsPlaying = false
        IsPaused = false
    end
end)

player.CharacterAdded:Connect(function(character)
    task.wait(1)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if humanoid then
        humanoid.WalkSpeed = CurrentWalkSpeed
        humanoid.JumpPower = 50
    end
end)

print("✅ AutoWalk ByaruL v3.1 - HYBRID SMART MOVEMENT Loaded!")