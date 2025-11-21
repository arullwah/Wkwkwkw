local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
wait(1)

-- ========= FILE SYSTEM PROTECTION =========
local hasFileSystem = (writefile ~= nil and readfile ~= nil and isfile ~= nil)

if not hasFileSystem then
    warn("⚠️ File system tidak tersedia. Script akan berjalan tanpa fitur Save/Load.")
    writefile = function() end
    readfile = function() return "" end
    isfile = function() return false end
end

-- ========= OPTIMIZED CONFIGURATION (TESTED & PERFECT) =========
local RECORDING_FPS = 60
local MAX_FRAMES = 30000
local MIN_DISTANCE_THRESHOLD = 0.008
local VELOCITY_SCALE = 1
local VELOCITY_Y_SCALE = 1
local TIMELINE_STEP_SECONDS = 0.15
local JUMP_VELOCITY_THRESHOLD = 10
local STATE_CHANGE_COOLDOWN = 0.1
local TRANSITION_FRAMES = 6
local RESUME_DISTANCE_THRESHOLD = 40
local PLAYBACK_FIXED_TIMESTEP = 1 / 60
local LOOP_TRANSITION_DELAY = 0.08
local AUTO_LOOP_RETRY_DELAY = 0.3
local TIME_BYPASS_THRESHOLD = 0.05
local LAG_DETECTION_THRESHOLD = 0.15
local MAX_LAG_FRAMES_TO_SKIP = 3
local INTERPOLATE_AFTER_LAG = true
local ENABLE_FRAME_SMOOTHING = false
local SMOOTHING_WINDOW = 3
local USE_VELOCITY_PLAYBACK = false
local INTERPOLATION_LOOKAHEAD = 2
local STOP_VELOCITY_THRESHOLD = 1.0

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
local IsReversing = false
local IsForwarding = false
local IsTimelineMode = false
local CurrentSpeed = 1.0
local CurrentWalkSpeed = 16
local RecordedMovements = {}
local RecordingOrder = {}
local CurrentRecording = {Frames = {}, StartTime = 0, Name = ""}
local AutoRespawn = false
local InfiniteJump = false
local AutoLoop = false
local recordConnection = nil
local playbackConnection = nil
local loopConnection = nil
local jumpConnection = nil
local reverseConnection = nil
local forwardConnection = nil
local lastRecordTime = 0
local lastRecordPos = nil
local checkpointNames = {}
local PathVisualization = {}
local ShowPaths = false
local PathAutoHide = true
local CurrentPauseMarker = nil
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
local lastPlaybackState = nil
local lastStateChangeTime = 0
local IsAutoLoopPlaying = false
local CurrentLoopIndex = 1
local LoopPauseStartTime = 0
local LoopTotalPausedDuration = 0
local shiftLockConnection = nil
local originalMouseBehavior = nil
local ShiftLockEnabled = false
local isShiftLockActive = false
local StudioIsRecording = false
local StudioCurrentRecording = {Frames = {}, StartTime = 0, Name = ""}
local lastStudioRecordTime = 0
local lastStudioRecordPos = nil
local activeConnections = {}
local CheckedRecordings = {}
local CurrentTimelineFrame = 0
local TimelinePosition = 0
local AutoReset = false
local CurrentPlayingRecording = nil
local PausedAtFrame = 0
local playbackAccumulator = 0
local LastPausePosition = nil
local LastPauseRecording = nil
local LastPauseFrame = 0
local NearestRecordingDistance = math.huge
local LoopRetryAttempts = 0
local MaxLoopRetries = 999
local IsLoopTransitioning = false
local titlePulseConnection = nil
local previousFrameData = nil
local PathHasBeenUsed = {}
local PathsHiddenOnce = false

-- ⭐ FIXED: Visual ShiftLock Variables dengan system yang lebih robust
local ShiftLockVisualIndicator = nil
local ShiftLockCameraOffset = Vector3.new(1.75, 0, 0)
local ShiftLockUpdateConnection = nil
local OriginalCameraOffset = nil
local IsShiftLockForceDisabled = false

-- ========= SOUND EFFECTS =========
local SoundEffects = {
    Click = "rbxassetid://4499400560",
    Toggle = "rbxassetid://7468131335",
    Error = "rbxassetid://7772283448",
    Success = "rbxassetid://2865227271"
}

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
    
    if recordConnection then pcall(function() recordConnection:Disconnect() end) recordConnection = nil end
    if playbackConnection then pcall(function() playbackConnection:Disconnect() end) playbackConnection = nil end
    if loopConnection then pcall(function() task.cancel(loopConnection) end) loopConnection = nil end
    if shiftLockConnection then pcall(function() shiftLockConnection:Disconnect() end) shiftLockConnection = nil end
    if jumpConnection then pcall(function() jumpConnection:Disconnect() end) jumpConnection = nil end
    if reverseConnection then pcall(function() reverseConnection:Disconnect() end) reverseConnection = nil end
    if forwardConnection then pcall(function() forwardConnection:Disconnect() end) forwardConnection = nil end
    if titlePulseConnection then pcall(function() titlePulseConnection:Disconnect() end) titlePulseConnection = nil end
    if ShiftLockUpdateConnection then pcall(function() ShiftLockUpdateConnection:Disconnect() end) ShiftLockUpdateConnection = nil end
end

local function PlaySound(soundType)
    task.spawn(function()
        pcall(function()
            local sound = Instance.new("Sound")
            sound.SoundId = SoundEffects[soundType] or SoundEffects.Click
            sound.Volume = 0.3
            sound.Parent = workspace
            sound:Play()
            game:GetService("Debris"):AddItem(sound, 2)
        end)
    end)
end

local function AnimateButtonClick(button)
    PlaySound("Click")
    pcall(function()
        local originalColor = button.BackgroundColor3
        local brighterColor = Color3.new(
            math.min(originalColor.R * 1.3, 1),
            math.min(originalColor.G * 1.3, 1), 
            math.min(originalColor.B * 1.3, 1)
        )
        
        TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundColor3 = brighterColor
        }):Play()
        
        task.wait(0.1)
        
        TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundColor3 = originalColor
        }):Play()
    end)
end

local function ResetCharacter()
    pcall(function()
        local char = player.Character
        if char then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.Health = 0
            end
        end
    end)
end

local function WaitForRespawn()
    local startTime = tick()
    local timeout = 10
    repeat
        task.wait(0.05)
        if tick() - startTime > timeout then return false end
    until player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChildOfClass("Humanoid") and player.Character.Humanoid.Health > 0
    task.wait(0.3)
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

local function CompleteCharacterReset(char)
    if not char or not char:IsDescendantOf(workspace) then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then return end
    task.spawn(function()
        pcall(function()
            humanoid.PlatformStand = false
            humanoid.AutoRotate = true
            humanoid.WalkSpeed = CurrentWalkSpeed
            humanoid.JumpPower = prePauseJumpPower or 50
            humanoid.Sit = false
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end)
    end)
end

-- ⭐⭐⭐ FIXED: VISUAL SHIFTLOCK SYSTEM YANG BERFUNGSI DI SEMUA KONDISI ⭐⭐⭐
local function CreateShiftLockIndicator()
    if ShiftLockVisualIndicator then
        pcall(function() ShiftLockVisualIndicator:Destroy() end)
        ShiftLockVisualIndicator = nil
    end
    
    pcall(function()
        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "ShiftLockIndicator"
        ScreenGui.ResetOnSpawn = false
        ScreenGui.DisplayOrder = 999
        
        local indicator = Instance.new("ImageLabel")
        indicator.Name = "LockIcon"
        indicator.Size = UDim2.fromOffset(32, 32)
        indicator.Position = UDim2.new(0.5, 16, 0.5, 0)
        indicator.AnchorPoint = Vector2.new(0.5, 0.5)
        indicator.BackgroundTransparency = 1
        indicator.Image = "rbxasset://textures/ui/MouseLockedCursor.png"
        indicator.ImageColor3 = Color3.fromRGB(255, 255, 255)
        indicator.ImageTransparency = 0
        indicator.Parent = ScreenGui
        
        ScreenGui.Parent = player:WaitForChild("PlayerGui")
        ShiftLockVisualIndicator = ScreenGui
    end)
end

local function RemoveShiftLockIndicator()
    if ShiftLockVisualIndicator then
        pcall(function()
            ShiftLockVisualIndicator:Destroy()
            ShiftLockVisualIndicator = nil
        end)
    end
end

local function ApplyVisualShiftLock()
    if not ShiftLockEnabled or IsShiftLockForceDisabled then return end
    if IsPlaying or IsAutoLoopPlaying or IsRecording or StudioIsRecording then return end
    
    pcall(function()
        local char = player.Character
        if not char then return end
        
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local camera = workspace.CurrentCamera
        
        if not humanoid or not hrp or not camera then return end
        
        humanoid.AutoRotate = false
        
        local cameraCFrame = camera.CFrame
        local lookVector = cameraCFrame.LookVector
        local horizontalLook = Vector3.new(lookVector.X, 0, lookVector.Z)
        
        if horizontalLook.Magnitude > 0.01 then
            local targetCFrame = CFrame.new(hrp.Position, hrp.Position + horizontalLook)
            hrp.CFrame = targetCFrame
        end
        
        if not OriginalCameraOffset then
            OriginalCameraOffset = humanoid.CameraOffset
        end
        humanoid.CameraOffset = ShiftLockCameraOffset
    end)
end

local function EnableVisibleShiftLock()
    if ShiftLockUpdateConnection or not ShiftLockEnabled then return end
    
    pcall(function()
        IsShiftLockForceDisabled = false
        isShiftLockActive = true
        
        CreateShiftLockIndicator()
        
        local char = player.Character
        if char then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid and not OriginalCameraOffset then
                OriginalCameraOffset = humanoid.CameraOffset
            end
        end
        
        ShiftLockUpdateConnection = RunService.RenderStepped:Connect(function()
            if ShiftLockEnabled and player.Character and not IsShiftLockForceDisabled then
                ApplyVisualShiftLock()
            end
        end)
        
        AddConnection(ShiftLockUpdateConnection)
        PlaySound("Toggle")
    end)
end

local function DisableVisibleShiftLock()
    pcall(function()
        if ShiftLockUpdateConnection then
            ShiftLockUpdateConnection:Disconnect()
            ShiftLockUpdateConnection = nil
        end
        
        RemoveShiftLockIndicator()
        
        local char = player.Character
        if char and char:FindFirstChildOfClass("Humanoid") then
            local humanoid = char.Humanoid
            humanoid.AutoRotate = true
            
            if OriginalCameraOffset then
                humanoid.CameraOffset = OriginalCameraOffset
                OriginalCameraOffset = nil
            else
                humanoid.CameraOffset = Vector3.new(0, 0, 0)
            end
        end
        
        isShiftLockActive = false
        PlaySound("Toggle")
    end)
end

local function ForceDisableShiftLock()
    IsShiftLockForceDisabled = true
    DisableVisibleShiftLock()
end

local function ForceEnableShiftLock()
    IsShiftLockForceDisabled = false
    if ShiftLockEnabled then
        EnableVisibleShiftLock()
    end
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
            pcall(function()
                local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end)
        end
    end)
    AddConnection(jumpConnection)
end

local function DisableInfiniteJump()
    if jumpConnection then
        pcall(function() jumpConnection:Disconnect() end)
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

local function SaveHumanoidState()
    pcall(function()
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
            if prePauseHumanoidState == Enum.HumanoidStateType.Climbing then
                humanoid.PlatformStand = false
                humanoid.AutoRotate = false
            end
        end
    end)
end

local function RestoreHumanoidState()
    pcall(function()
        local char = player.Character
        if not char then return end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            if prePauseHumanoidState == Enum.HumanoidStateType.Climbing then
                humanoid.PlatformStand = false
                humanoid.AutoRotate = false
                humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
            else
                humanoid.AutoRotate = prePauseAutoRotate
                humanoid.WalkSpeed = prePauseWalkSpeed
                humanoid.JumpPower = prePauseJumpPower
                humanoid.PlatformStand = prePausePlatformStand
                humanoid.Sit = prePauseSit
            end
        end
    end)
end

local function RestoreFullUserControl()
    pcall(function()
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
            
            if OriginalCameraOffset then
                humanoid.CameraOffset = OriginalCameraOffset
            else
                humanoid.CameraOffset = Vector3.new(0, 0, 0)
            end
        end
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
        if ShiftLockEnabled then
            ForceEnableShiftLock()
        end
    end)
end

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

local function GetFrameVelocity(frame)
    if not frame.Velocity then return Vector3.new(0, 0, 0) end
    
    local vel = Vector3.new(
        frame.Velocity[1] * VELOCITY_SCALE,
        frame.Velocity[2] * VELOCITY_Y_SCALE,
        frame.Velocity[3] * VELOCITY_SCALE
    )
    
    local horizontalVel = Vector3.new(vel.X, 0, vel.Z)
    
    if horizontalVel.Magnitude < STOP_VELOCITY_THRESHOLD then
        return Vector3.new(0, vel.Y, 0)
    end
    
    return vel
end

local function ProcessHumanoidState(hum, frame, lastState, lastStateTime)
    local moveState = frame.MoveState
    local frameVelocity = GetFrameVelocity(frame)
    local currentTime = tick()
    
    local isJumpingByVelocity = frameVelocity.Y > JUMP_VELOCITY_THRESHOLD
    local isFallingByVelocity = frameVelocity.Y < -5
    
    if isJumpingByVelocity and moveState ~= "Jumping" then
        moveState = "Jumping"
    elseif isFallingByVelocity and moveState ~= "Falling" then
        moveState = "Falling"
    end
    
    if moveState == "Jumping" then
        if lastState ~= "Jumping" then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
            return "Jumping", currentTime
        end
    elseif moveState == "Falling" then
        if lastState ~= "Falling" then
            hum:ChangeState(Enum.HumanoidStateType.Freefall)
            return "Falling", currentTime
        end
    else
        if moveState ~= lastState and (currentTime - lastStateTime) >= STATE_CHANGE_COOLDOWN then
            if moveState == "Climbing" then
                hum:ChangeState(Enum.HumanoidStateType.Climbing)
                hum.PlatformStand = false
                hum.AutoRotate = false
            elseif moveState == "Swimming" then
                hum:ChangeState(Enum.HumanoidStateType.Swimming)
            else
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
            return moveState, currentTime
        end
    end
    
    return lastState, lastStateTime
end

local function ClearPathVisualization()
    pcall(function()
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
    end)
end

local function CreatePathSegment(startPos, endPos, color)
    local success, part = pcall(function()
        local p = Instance.new("Part")
        p.Name = "PathSegment"
        p.Anchored = true
        p.CanCollide = false
        p.Material = Enum.Material.Neon
        p.BrickColor = color or BrickColor.new("Really black")
        p.Transparency = 0.2
        local distance = (startPos - endPos).Magnitude
        p.Size = Vector3.new(0.2, 0.2, distance)
        p.CFrame = CFrame.lookAt((startPos + endPos) / 2, endPos)
        p.Parent = workspace
        table.insert(PathVisualization, p)
        return p
    end)
    return success and part or nil
end

local function CreatePauseMarker(position)
    pcall(function()
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
        label.Text = "PAUSED"
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
    end)
end

local function UpdatePauseMarker()
    pcall(function()
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
    end)
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
    
    pcall(function()
        local mergedFrames = {}
        local totalTimeOffset = 0
        local mergedCount = 0
        
        for _, checkpointName in ipairs(RecordingOrder) do
            if not CheckedRecordings[checkpointName] then continue end
            
            local checkpoint = RecordedMovements[checkpointName]
            if not checkpoint or #checkpoint == 0 then 
                warn("⚠️ Skipping empty checkpoint:", checkpointName)
                continue 
            end
            
            print("✅ Merging:", checkpointName, "| Frames:", #checkpoint)
            
            if #mergedFrames > 0 and #checkpoint > 0 then
                local lastFrame = mergedFrames[#mergedFrames]
                local firstFrame = checkpoint[1]
                
                local lastPos = Vector3.new(lastFrame.Position[1], lastFrame.Position[2], lastFrame.Position[3])
                local nextPos = Vector3.new(firstFrame.Position[1], firstFrame.Position[2], firstFrame.Position[3])
                local distance = (lastPos - nextPos).Magnitude
                
                print("   📏 Distance to next:", math.floor(distance), "studs")
                
                local transitionCount = TRANSITION_FRAMES
                
                if distance < 5 then
                    transitionCount = 2
                elseif distance < 20 then
                    transitionCount = 4
                else
                    transitionCount = 8
                end
                
                local lastState = lastFrame.MoveState
                local nextState = firstFrame.MoveState
                
                if lastState == nextState and lastState == "Grounded" then
                    transitionCount = math.max(2, transitionCount)
                end
                
                print("   🔄 Creating", transitionCount, "transition frames")
                
                local transitionFrames = CreateSmoothTransition(lastFrame, firstFrame, transitionCount)
                
                for i, tFrame in ipairs(transitionFrames) do
                    tFrame.Timestamp = lastFrame.Timestamp + (i * 0.016) + 0.05
                    table.insert(mergedFrames, tFrame)
                end
                
                totalTimeOffset = mergedFrames[#mergedFrames].Timestamp + 0.05
            end
            
            for frameIndex, frame in ipairs(checkpoint) do
                local newFrame = {
                    Position = {frame.Position[1], frame.Position[2], frame.Position[3]},
                    LookVector = {frame.LookVector[1], frame.LookVector[2], frame.LookVector[3]},
                    UpVector = {frame.UpVector[1], frame.UpVector[2], frame.UpVector[3]},
                    Velocity = {frame.Velocity[1], frame.Velocity[2], frame.Velocity[3]},
                    MoveState = frame.MoveState,
                    WalkSpeed = frame.WalkSpeed,
                    Timestamp = totalTimeOffset + frame.Timestamp
                }
                table.insert(mergedFrames, newFrame)
            end
            
            if #checkpoint > 0 then
                totalTimeOffset = mergedFrames[#mergedFrames].Timestamp + 0.1
            end
            
            mergedCount = mergedCount + 1
        end
        
        if #mergedFrames == 0 then
            warn("❌ Merge failed: No frames created")
            PlaySound("Error")
            return
        end
        
        print("✅ Merge complete! Total frames:", #mergedFrames, "| Checkpoints merged:", mergedCount)
        
        local firstTimestamp = mergedFrames[1].Timestamp
        for _, frame in ipairs(mergedFrames) do
            frame.Timestamp = frame.Timestamp - firstTimestamp
        end
        
        local mergedName = "merged_" .. os.date("%H%M%S")
        RecordedMovements[mergedName] = mergedFrames
        table.insert(RecordingOrder, mergedName)
        checkpointNames[mergedName] = "MERGED (" .. mergedCount .. " checkpoints)"
        
        UpdateRecordList()
        PlaySound("Success")
        
        print("📊 Merged replay saved as:", mergedName)
        print("   Duration:", string.format("%.2f", mergedFrames[#mergedFrames].Timestamp), "seconds")
    end)
end

local function GetFrameCFrame(frame)
    local pos = Vector3.new(frame.Position[1], frame.Position[2], frame.Position[3])
    local look = Vector3.new(frame.LookVector[1], frame.LookVector[2], frame.LookVector[3])
    local up = Vector3.new(frame.UpVector[1], frame.UpVector[2], frame.UpVector[3])
    return CFrame.lookAt(pos, pos + look, up)
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

local function DetectAndCompensateLag(frames)
    if not frames or #frames < 3 then return frames end
    
    local compensatedFrames = {}
    local lagDetected = false
    
    for i = 1, #frames do
        local frame = frames[i]
        
        if i > 1 then
            local timeDiff = frame.Timestamp - frames[i-1].Timestamp
            local expectedDiff = 1 / RECORDING_FPS
            
            if timeDiff > LAG_DETECTION_THRESHOLD then
                lagDetected = true
                
                local missedFrames = math.floor(timeDiff / expectedDiff) - 1
                local framesToInterpolate = math.min(missedFrames, MAX_LAG_FRAMES_TO_SKIP)
                
                if INTERPOLATE_AFTER_LAG and framesToInterpolate > 0 then
                    local prevFrame = frames[i-1]
                    local nextFrame = frame
                    
                    for j = 1, framesToInterpolate do
                        local alpha = j / (framesToInterpolate + 1)
                        
                        local pos1 = Vector3.new(prevFrame.Position[1], prevFrame.Position[2], prevFrame.Position[3])
                        local pos2 = Vector3.new(nextFrame.Position[1], nextFrame.Position[2], nextFrame.Position[3])
                        local interpPos = pos1:Lerp(pos2, alpha)
                        
                        local look1 = Vector3.new(prevFrame.LookVector[1], prevFrame.LookVector[2], prevFrame.LookVector[3])
                        local look2 = Vector3.new(nextFrame.LookVector[1], nextFrame.LookVector[2], nextFrame.LookVector[3])
                        local interpLook = look1:Lerp(look2, alpha).Unit
                        
                        local up1 = Vector3.new(prevFrame.UpVector[1], prevFrame.UpVector[2], prevFrame.UpVector[3])
                        local up2 = Vector3.new(nextFrame.UpVector[1], nextFrame.UpVector[2], nextFrame.UpVector[3])
                        local interpUp = up1:Lerp(up2, alpha).Unit
                        
                        local vel1 = Vector3.new(prevFrame.Velocity[1], prevFrame.Velocity[2], prevFrame.Velocity[3])
                        local vel2 = Vector3.new(nextFrame.Velocity[1], nextFrame.Velocity[2], nextFrame.Velocity[3])
                        local interpVel = vel1:Lerp(vel2, alpha)
                        
                        local interpWS = prevFrame.WalkSpeed + (nextFrame.WalkSpeed - prevFrame.WalkSpeed) * alpha
                        
                        table.insert(compensatedFrames, {
                            Position = {interpPos.X, interpPos.Y, interpPos.Z},
                            LookVector = {interpLook.X, interpLook.Y, interpLook.Z},
                            UpVector = {interpUp.X, interpUp.Y, interpUp.Z},
                            Velocity = {interpVel.X, interpVel.Y, interpVel.Z},
                            MoveState = prevFrame.MoveState,
                            WalkSpeed = interpWS,
                            Timestamp = prevFrame.Timestamp + (j * expectedDiff),
                            IsInterpolated = true
                        })
                    end
                end
            end
        end
        
        table.insert(compensatedFrames, frame)
    end
    
    return compensatedFrames, lagDetected
end

local function SmoothFrames(frames)
    if not ENABLE_FRAME_SMOOTHING or #frames < SMOOTHING_WINDOW * 2 then 
        return frames 
    end
    
    local smoothedFrames = {}
    local halfWindow = math.floor(SMOOTHING_WINDOW / 2)
    
    for i = 1, #frames do
        if i <= halfWindow or i > (#frames - halfWindow) then
            table.insert(smoothedFrames, frames[i])
        else
            local avgPos = Vector3.zero
            local avgLook = Vector3.zero
            local avgUp = Vector3.zero
            local avgVel = Vector3.zero
            local avgWS = 0
            local count = 0
            
            for j = -halfWindow, halfWindow do
                local idx = i + j
                if idx >= 1 and idx <= #frames then
                    local f = frames[idx]
                    avgPos = avgPos + Vector3.new(f.Position[1], f.Position[2], f.Position[3])
                    avgLook = avgLook + Vector3.new(f.LookVector[1], f.LookVector[2], f.LookVector[3])
                    avgUp = avgUp + Vector3.new(f.UpVector[1], f.UpVector[2], f.UpVector[3])
                    avgVel = avgVel + Vector3.new(f.Velocity[1], f.Velocity[2], f.Velocity[3])
                    avgWS = avgWS + f.WalkSpeed
                    count = count + 1
                end
            end
            
            avgPos = avgPos / count
            avgLook = (avgLook / count).Unit
            avgUp = (avgUp / count).Unit
            avgVel = avgVel / count
            avgWS = avgWS / count
            
            local smoothedFrame = {
                Position = {avgPos.X, avgPos.Y, avgPos.Z},
                LookVector = {avgLook.X, avgLook.Y, avgLook.Z},
                UpVector = {avgUp.X, avgUp.Y, avgUp.Z},
                Velocity = {avgVel.X, avgVel.Y, avgVel.Z},
                MoveState = frames[i].MoveState,
                WalkSpeed = avgWS,
                Timestamp = frames[i].Timestamp,
                IsSmoothed = true
            }
            
            table.insert(smoothedFrames, smoothedFrame)
        end
    end
    
    return smoothedFrames
end

local function NormalizeRecordingTimestamps(recording)
    if not recording or #recording == 0 then return recording end
    
    local lagCompensated, hadLag = DetectAndCompensateLag(recording)
    
    if hadLag then
        print("⚠️ Lag terdeteksi ")
    end
    
    local smoothed = ENABLE_FRAME_SMOOTHING and SmoothFrames(lagCompensated) or lagCompensated
    
    local normalized = {}
    local expectedFrameTime = 1 / RECORDING_FPS
    
    for i, frame in ipairs(smoothed) do
        local newFrame = {
            Position = frame.Position,
            LookVector = frame.LookVector,
            UpVector = frame.UpVector,
            Velocity = frame.Velocity,
            MoveState = frame.MoveState,
            WalkSpeed = frame.WalkSpeed,
            Timestamp = 0,
            IsInterpolated = frame.IsInterpolated,
            IsSmoothed = frame.IsSmoothed
        }
        
        if i == 1 then
            newFrame.Timestamp = 0
        else
            local prevTimestamp = normalized[i-1].Timestamp
            local originalTimeDiff = frame.Timestamp - smoothed[i-1].Timestamp
            
            if originalTimeDiff > (expectedFrameTime * 3) then
                newFrame.Timestamp = prevTimestamp + expectedFrameTime
            else
                newFrame.Timestamp = prevTimestamp + math.max(originalTimeDiff, expectedFrameTime * 0.5)
            end
        end
        
        table.insert(normalized, newFrame)
    end
    
    return normalized
end

local function StartTitlePulse(titleLabel)
    if titlePulseConnection then
        pcall(function() titlePulseConnection:Disconnect() end)
        titlePulseConnection = nil
    end

    if not titleLabel then return end

    local hueSpeed = 0.25
    local pulseFreq = 4.5
    local baseSize = 14
    local sizeAmplitude = 6
    local strokeMin = 0.0
    local strokeMax = 0.9
    local strokePulseFreq = 2.2

    titlePulseConnection = RunService.RenderStepped:Connect(function()
        pcall(function()
            if not titleLabel or not titleLabel.Parent then
                if titlePulseConnection then
                    titlePulseConnection:Disconnect()
                    titlePulseConnection = nil
                end
                return
            end

            local t = tick()

            local hue = (t * hueSpeed) % 1
            local color = Color3.fromHSV(hue, 1, 1)
            titleLabel.TextColor3 = color

            local pulse = 0.5 + (math.sin(t * pulseFreq) * 0.5)
            local newSize = baseSize + (pulse * sizeAmplitude)
            titleLabel.TextSize = math.max(8, math.floor(newSize + 0.5))

            if titleLabel.TextStrokeTransparency ~= nil then
                local strokePulse = 0.5 + (math.sin(t * strokePulseFreq) * 0.5)
                local strokeTransparency = strokeMin + (strokePulse * (strokeMax - strokeMin))
                titleLabel.TextStrokeTransparency = math.clamp(strokeTransparency, 0, 1)
                titleLabel.TextStrokeColor3 = Color3.new(0,0,0)
            end

            if titleLabel.Position and typeof(titleLabel.Position) == "UDim2" then
                local jitter = (math.sin(t * pulseFreq * 0.5) * 2) * (pulse * 0.6)
                titleLabel.Position = UDim2.new(titleLabel.Position.X.Scale, titleLabel.Position.X.Offset, titleLabel.Position.Y.Scale, titleLabel.Position.Y.Offset + jitter)
            end
        end)
    end)

    AddConnection(titlePulseConnection)
end

local function FindNearestRecording(maxDistance)
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        return nil, math.huge, nil
    end
    
    local currentPos = char.HumanoidRootPart.Position
    local nearestRecording = nil
    local nearestDistance = math.huge
    local nearestName = nil
    
    for _, recordingName in ipairs(RecordingOrder) do
        local recording = RecordedMovements[recordingName]
        if recording and #recording > 0 then
            local nearestFrame, frameDistance = FindNearestFrame(recording, currentPos)
            
            if frameDistance < nearestDistance and frameDistance <= (maxDistance or 50) then
                nearestDistance = frameDistance
                nearestRecording = recording
                nearestName = recordingName
            end
        end
    end
    
    return nearestRecording, nearestDistance, nearestName
end

local function UpdatePlayButtonStatus()
    local nearestRecording, distance = FindNearestRecording(50)
    NearestRecordingDistance = distance or math.huge
    
    if PlayBtnControl then
        if nearestRecording and distance <= 50 then
            PlayBtnControl.Text = "PLAY (" .. math.floor(distance) .. "m)"
            PlayBtnControl.BackgroundColor3 = Color3.fromRGB(80, 180, 80)
        else
            PlayBtnControl.Text = "PLAY"
            PlayBtnControl.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
        end
    end
end

local function CheckIfPathUsed(recordingName)
    if not recordingName then return end
    if not CurrentPlayingRecording then return end
    
    local recording = RecordedMovements[recordingName]
    if not recording or #recording == 0 then return end
    
    if PathHasBeenUsed[recordingName] then return end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local lastFrame = recording[#recording]
    local lastPos = GetFramePosition(lastFrame)
    local currentPos = char.HumanoidRootPart.Position
    local distance = (currentPos - lastPos).Magnitude
    
    if distance < 10 and currentPlaybackFrame >= (#recording - 5) then
        PathHasBeenUsed[recordingName] = true
        
        local allPathsUsed = true
        for _, name in ipairs(RecordingOrder) do
            if not PathHasBeenUsed[name] then
                allPathsUsed = false
                break
            end
        end
        
        if allPathsUsed and ShowPaths and not PathsHiddenOnce then
            PathsHiddenOnce = true
            ShowPaths = false
            ClearPathVisualization()
            if ShowRuteBtnControl then
                ShowRuteBtnControl.Text = "Path OFF"
                ShowRuteBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
            end
        end
    end
end

-- ========= FIXED PLAYBACK FUNCTIONS =========

local function PlayFromSpecificFrame(recording, startFrame, recordingName)
    if IsPlaying or IsAutoLoopPlaying then return end
    
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
    previousFrameData = nil
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    local currentPos = hrp.Position
    local targetFrame = recording[startFrame]
    local targetPos = GetFramePosition(targetFrame)
    
    local distance = (currentPos - targetPos).Magnitude
    
    if distance > 3 then
        hrp.CFrame = GetFrameCFrame(targetFrame)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        task.wait(0.03)
    end
    
    currentPlaybackFrame = startFrame
    playbackStartTime = tick() - (GetFrameTimestamp(recording[startFrame]) / CurrentSpeed)
    totalPausedDuration = 0
    pauseStartTime = 0
    lastPlaybackState = nil
    lastStateChangeTime = 0

    SaveHumanoidState()
    
    -- ⭐ FIXED: ShiftLock management yang benar
    ForceDisableShiftLock()
    
    PlaySound("Toggle")
    
    if PlayBtnControl then
        PlayBtnControl.Text = "STOP"
        PlayBtnControl.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
    end

    playbackConnection = RunService.Heartbeat:Connect(function(deltaTime)
        pcall(function()
            if not IsPlaying then
                playbackConnection:Disconnect()
                RestoreFullUserControl()
                
                -- ⭐ FIXED: Restore ShiftLock setelah playback
                ForceEnableShiftLock()
                
                CheckIfPathUsed(recordingName)
                UpdatePauseMarker()
                lastPlaybackState = nil
                lastStateChangeTime = 0
                previousFrameData = nil
                if PlayBtnControl then
                    PlayBtnControl.Text = "PLAY"
                    PlayBtnControl.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
                end
                UpdatePlayButtonStatus()
                return
            end
            
            local char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then
                IsPlaying = false
                ForceEnableShiftLock()
                RestoreFullUserControl()
                CheckIfPathUsed(recordingName)
                UpdatePauseMarker()
                lastPlaybackState = nil
                lastStateChangeTime = 0
                previousFrameData = nil
                if PlayBtnControl then
                    PlayBtnControl.Text = "PLAY"
                    PlayBtnControl.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
                end
                UpdatePlayButtonStatus()
                return
            end
            
            local hum = char:FindFirstChildOfClass("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hum or not hrp then
                IsPlaying = false
                ForceEnableShiftLock()
                RestoreFullUserControl()
                CheckIfPathUsed(recordingName)
                UpdatePauseMarker()
                lastPlaybackState = nil
                lastStateChangeTime = 0
                previousFrameData = nil
                if PlayBtnControl then
                    PlayBtnControl.Text = "PLAY"
                    PlayBtnControl.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
                end
                UpdatePlayButtonStatus()
                return
            end

            playbackAccumulator = playbackAccumulator + deltaTime
            
            while playbackAccumulator >= PLAYBACK_FIXED_TIMESTEP do
                playbackAccumulator = playbackAccumulator - PLAYBACK_FIXED_TIMESTEP
                 
                local currentTime = tick()
                local effectiveTime = (currentTime - playbackStartTime - totalPausedDuration) * CurrentSpeed
                
                local nextFrame = currentPlaybackFrame
                while nextFrame < #recording and GetFrameTimestamp(recording[nextFrame + 1]) <= effectiveTime do
                    nextFrame = nextFrame + 1
                end

                if nextFrame >= #recording then
                    IsPlaying = false
                    ForceEnableShiftLock()
                    RestoreFullUserControl()
                    CheckIfPathUsed(recordingName)
                    PlaySound("Success")
                    UpdatePauseMarker()
                    lastPlaybackState = nil
                    lastStateChangeTime = 0
                    previousFrameData = nil
                    if PlayBtnControl then
                        PlayBtnControl.Text = "PLAY"
                        PlayBtnControl.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
                    end
                    UpdatePlayButtonStatus()
                    return
                end

                local frame = recording[nextFrame]
                if not frame then
                    IsPlaying = false
                    ForceEnableShiftLock()
                    RestoreFullUserControl()
                    CheckIfPathUsed(recordingName)
                    UpdatePauseMarker()
                    lastPlaybackState = nil
                    lastStateChangeTime = 0
                    previousFrameData = nil
                    if PlayBtnControl then
                        PlayBtnControl.Text = "PLAY"
                        PlayBtnControl.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
                    end
                    UpdatePlayButtonStatus()
                    return
                end

                hrp.CFrame = GetFrameCFrame(frame)
                hrp.AssemblyLinearVelocity = GetFrameVelocity(frame)
                hrp.AssemblyAngularVelocity = Vector3.zero
                
                if hum then
                    hum.WalkSpeed = GetFrameWalkSpeed(frame) * CurrentSpeed
                    hum.AutoRotate = false
                    
                    lastPlaybackState, lastStateChangeTime = ProcessHumanoidState(
                        hum, frame, lastPlaybackState, lastStateChangeTime
                    )
                end
                
                currentPlaybackFrame = nextFrame
            end
        end)
    end)
    
    AddConnection(playbackConnection)
    UpdatePlayButtonStatus()
end

local function SmartPlayRecording(maxDistance)
    if IsPlaying or IsAutoLoopPlaying then return end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        PlaySound("Error")
        return
    end

    local currentPos = char.HumanoidRootPart.Position
    local bestRecording = nil
    local bestFrame = 1
    local bestDistance = math.huge
    local bestRecordingName = nil
    
    for _, recordingName in ipairs(RecordingOrder) do
        local recording = RecordedMovements[recordingName]
        if recording and #recording > 0 then
            local nearestFrame, frameDistance = FindNearestFrame(recording, currentPos)
            
            if frameDistance < bestDistance and frameDistance <= (maxDistance or 50) then
                bestDistance = frameDistance
                bestRecording = recording
                bestFrame = nearestFrame
                bestRecordingName = recordingName
            end
        end
    end
    
    if bestRecording then
        PlayFromSpecificFrame(bestRecording, bestFrame, bestRecordingName)
    else
        local firstRecording = RecordingOrder[1] and RecordedMovements[RecordingOrder[1]]
        if firstRecording then
            PlayFromSpecificFrame(firstRecording, 1, RecordingOrder[1])
        else
            PlaySound("Error")
        end
    end
end

-- ✅ FIXED: PlayRecording function yang benar
local function PlayRecording(name)
    if not name then
        SmartPlayRecording(50)
        return
    end
    
    local recording = RecordedMovements[name]
    if recording then
        PlayFromSpecificFrame(recording, 1, name)
    else
        PlaySound("Error")
        warn("❌ Recording tidak ditemukan:", name)
    end
end

-- ✅ FIXED: StopAutoLoopAll function yang benar
local function StopAutoLoopAll()
    AutoLoop = false
    IsAutoLoopPlaying = false
    IsPlaying = false
    IsLoopTransitioning = false
    lastPlaybackState = nil
    lastStateChangeTime = 0
    
    if loopConnection then
        pcall(function() task.cancel(loopConnection) end)
        loopConnection = nil
    end
    
    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end
    
    RestoreFullUserControl()
    
    -- ⭐ FIXED: Restore ShiftLock setelah autoloop
    ForceEnableShiftLock()
    
    pcall(function()
        local char = player.Character
        if char then CompleteCharacterReset(char) end
    end)
    
    PlaySound("Toggle")
    if PlayBtnControl then
        PlayBtnControl.Text = "PLAY"
        PlayBtnControl.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
    end
    if LoopBtnControl then
        LoopBtnControl.Text = "Loop OFF"
        LoopBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    end
    UpdatePlayButtonStatus()
end

-- ✅ FIXED: StopPlayback function yang benar
local function StopPlayback()
    lastStateChangeTime = 0
    lastPlaybackState = nil

    if AutoLoop then
        StopAutoLoopAll()
        if LoopBtnControl then
            LoopBtnControl.Text = "Loop OFF"
            LoopBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        end
    end
    
    if not IsPlaying and not IsAutoLoopPlaying then return end
    
    IsPlaying = false
    IsAutoLoopPlaying = false
    IsLoopTransitioning = false
    LastPausePosition = nil
    LastPauseRecording = nil
    
    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end
    
    if loopConnection then
        pcall(function() task.cancel(loopConnection) end)
        loopConnection = nil
    end
    
    RestoreFullUserControl()
    
    -- ⭐ FIXED: Restore ShiftLock setelah playback
    ForceEnableShiftLock()
    
    local char = player.Character
    if char then CompleteCharacterReset(char) end
    
    PlaySound("Toggle")
    if PlayBtnControl then
        PlayBtnControl.Text = "PLAY"
        PlayBtnControl.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
    end
    UpdatePlayButtonStatus()
end

-- ✅ FIXED: StartAutoLoopAll function yang benar
local function StartAutoLoopAll()
    if not AutoLoop then return end
    
    if #RecordingOrder == 0 then
        AutoLoop = false
        if LoopBtnControl then
            LoopBtnControl.Text = "Loop OFF"
            LoopBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        end
        PlaySound("Error")
        return
    end
    
    if IsPlaying then
        IsPlaying = false
        if playbackConnection then
            playbackConnection:Disconnect()
            playbackConnection = nil
        end
    end
    
    PlaySound("Toggle")
    
    if CurrentLoopIndex == 0 or CurrentLoopIndex > #RecordingOrder then
        local nearestRecording, distance, nearestName = FindNearestRecording(50)
        if nearestRecording then
            CurrentLoopIndex = table.find(RecordingOrder, nearestName) or 1
        else
            CurrentLoopIndex = 1
        end
    end
    
    IsAutoLoopPlaying = true
    LoopRetryAttempts = 0
    lastPlaybackState = nil
    lastStateChangeTime = 0
    
    -- ⭐ FIXED: Disable ShiftLock selama autoloop
    ForceDisableShiftLock()
    
    if PlayBtnControl then
        PlayBtnControl.Text = "STOP"
        PlayBtnControl.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
    end
    if LoopBtnControl then
        LoopBtnControl.Text = "Loop ON"
        LoopBtnControl.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
    end

    loopConnection = task.spawn(function()
        while AutoLoop and IsAutoLoopPlaying do
            if not AutoLoop or not IsAutoLoopPlaying then break end
            
            local recordingToPlay = nil
            local recordingNameToPlay = nil
            local searchAttempts = 0
            
            while searchAttempts < #RecordingOrder do
                recordingNameToPlay = RecordingOrder[CurrentLoopIndex]
                recordingToPlay = RecordedMovements[recordingNameToPlay]
                
                if recordingToPlay and #recordingToPlay > 0 then
                    break
                else
                    CurrentLoopIndex = CurrentLoopIndex + 1
                    if CurrentLoopIndex > #RecordingOrder then
                        CurrentLoopIndex = 1
                    end
                    searchAttempts = searchAttempts + 1
                end
            end
            
            if not recordingToPlay or #recordingToPlay == 0 then
                CurrentLoopIndex = 1
                task.wait(1)
                continue
            end
            
            if not IsCharacterReady() then
                if AutoRespawn then
                    ResetCharacter()
                    local success = WaitForRespawn()
                    
                    if success then
                        RestoreFullUserControl()
                        task.wait(0.5)
                        
                        currentFrame = 1
                        playbackStartTime = tick()
                        lastPlaybackState = nil
                        lastStateChangeTime = 0
                        loopAccumulator = 0
                        
                        SaveHumanoidState()
                        
                        local char = player.Character
                        if char and char:FindFirstChild("HumanoidRootPart") then
                            char.HumanoidRootPart.CFrame = GetFrameCFrame(recordingToPlay[1])
                            task.wait(0.1)
                        end
                        
                        continue
                    else
                        task.wait(AUTO_LOOP_RETRY_DELAY)
                        continue
                    end
                else
                    local manualRespawnWait = 0
                    local maxManualWait = 30
                    
                    while not IsCharacterReady() and AutoLoop and IsAutoLoopPlaying do
                        manualRespawnWait = manualRespawnWait + 0.5
                        if manualRespawnWait >= maxManualWait then
                            break
                        end
                        task.wait(0.5)
                    end
                    
                    if not AutoLoop or not IsAutoLoopPlaying then break end
                    if not IsCharacterReady() then
                        break
                    end
                    
                    RestoreFullUserControl()
                    task.wait(0.5)
                    
                    currentFrame = 1
                    playbackStartTime = tick()
                    lastPlaybackState = nil
                    lastStateChangeTime = 0
                    loopAccumulator = 0
                    
                    SaveHumanoidState()
                    continue
                end
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
            
            if loopAccumulator >= PLAYBACK_FIXED_TIMESTEP then
                loopAccumulator = loopAccumulator - PLAYBACK_FIXED_TIMESTEP
                
                local currentTime = tick()
                local effectiveTime = (currentTime - playbackStartTime) * CurrentSpeed
                
                local targetFrame = currentFrame
                for i = currentFrame, #recordingToPlay do
                    if GetFrameTimestamp(recordingToPlay[i]) <= effectiveTime then
                        targetFrame = i
                    else
                        break
                    end
                end
                
                currentFrame = targetFrame
                
                if currentFrame >= #recordingToPlay then
                    playbackCompleted = true
                end
                
                if not playbackCompleted then
                    local frame = recordingToPlay[currentFrame]
                    if frame then
                        hrp.CFrame = GetFrameCFrame(frame)
                        hrp.AssemblyLinearVelocity = GetFrameVelocity(frame)
                        hrp.AssemblyAngularVelocity = Vector3.zero
                        
                        if hum then
                            hum.WalkSpeed = GetFrameWalkSpeed(frame) * CurrentSpeed
                            hum.AutoRotate = false
                            
                            lastPlaybackState, lastStateChangeTime = ProcessHumanoidState(
                                hum, frame, lastPlaybackState, lastStateChangeTime
                            )
                        end
                    end
                end
            end
            
            if playbackCompleted then
                break
            end
        end
        
        RestoreFullUserControl()
        lastPlaybackState = nil
        lastStateChangeTime = nil
        
        if playbackCompleted then
            PlaySound("Success")
            CheckIfPathUsed(recordingNameToPlay)
            
            local isLastRecording = (CurrentLoopIndex >= #RecordingOrder)
            
            if AutoReset and isLastRecording then
                ResetCharacter()
                local success = WaitForRespawn()
                if success then
                    task.wait(0.5)
                end
            end
            
            CurrentLoopIndex = CurrentLoopIndex + 1
            if CurrentLoopIndex > #RecordingOrder then
                CurrentLoopIndex = 1
                
                if AutoLoop and IsAutoLoopPlaying then
                    IsLoopTransitioning = true
                    task.wait(LOOP_TRANSITION_DELAY)
                    IsLoopTransitioning = false
                end
            end
            
            if not AutoLoop or not IsAutoLoopPlaying then break end
        else
            if not AutoLoop or not IsAutoLoopPlaying then
                break
            else
                CurrentLoopIndex = CurrentLoopIndex + 1
                if CurrentLoopIndex > #RecordingOrder then
                    CurrentLoopIndex = 1
                end
                task.wait(AUTO_LOOP_RETRY_DELAY)
            end
        end
    end)
    
    IsAutoLoopPlaying = false
    IsLoopTransitioning = false
    RestoreFullUserControl()
    lastPlaybackState = nil
    lastStateChangeTime = 0
    
    -- ⭐ FIXED: Restore ShiftLock setelah autoloop
    ForceEnableShiftLock()
    
    if PlayBtnControl then
        PlayBtnControl.Text = "PLAY"
        PlayBtnControl.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
    end
    if LoopBtnControl then
        LoopBtnControl.Text = "Loop OFF"
        LoopBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    end
    UpdatePlayButtonStatus()
end

-- UI CODE
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ByaruLRecorderElegant"
ScreenGui.ResetOnSpawn = false
if player:FindFirstChild("PlayerGui") then
    ScreenGui.Parent = player.PlayerGui
else
    wait(2)
    ScreenGui.Parent = player:WaitForChild("PlayerGui")
end

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.fromOffset(255, 365)
MainFrame.Position = UDim2.new(0.5, -127.5, 0.5, -182.5)
MainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 32)
Header.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 8)
HeaderCorner.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 1, 0)
Title.BackgroundTransparency = 1
Title.Text = "ByaruL Recorder"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Center
Title.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.fromOffset(20, 20)
CloseBtn.Position = UDim2.new(1, -20, 0.5, -10)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.new(1, 1, 1)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 4)
CloseCorner.Parent = CloseBtn

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -6, 1, -38)
Content.Position = UDim2.new(0, 3, 0, 36)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

local ControlSection = Instance.new("Frame")
ControlSection.Size = UDim2.new(1, 0, 0, 30)
ControlSection.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
ControlSection.BorderSizePixel = 0
ControlSection.Parent = Content

local ControlCorner = Instance.new("UICorner")
ControlCorner.CornerRadius = UDim.new(0, 6)
ControlCorner.Parent = ControlSection

local ControlButtons = Instance.new("Frame")
ControlButtons.Size = UDim2.new(1, -6, 1, -6)
ControlButtons.Position = UDim2.new(0, 3, 0, 3)
ControlButtons.BackgroundTransparency = 1
ControlButtons.Parent = ControlSection

local function CreateControlBtn(text, x, size, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(size, 22)
    btn.Position = UDim2.fromOffset(x, 0)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.AutoButtonColor = false
    btn.Parent = ControlButtons
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = btn
    
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.new(
                math.min(color.R * 1.2, 1),
                math.min(color.G * 1.2, 1),
                math.min(color.B * 1.2, 1)
            )
        }):Play()
    end)
    
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = color
        }):Play()
    end)
    
    return btn
end

local PlayBtn = CreateControlBtn("PLAY", 0, 81, Color3.fromRGB(59, 15, 116))
local RecordBtn = CreateControlBtn("RECORD", 84, 81, Color3.fromRGB(59, 15, 116))
local MenuBtn = CreateControlBtn("MENU", 168, 81, Color3.fromRGB(59, 15, 116))

local SpeedWalkSection = Instance.new("Frame")
SpeedWalkSection.Size = UDim2.new(1, 0, 0, 28)
SpeedWalkSection.Position = UDim2.new(0, 0, 0, 36)
SpeedWalkSection.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
SpeedWalkSection.BorderSizePixel = 0
SpeedWalkSection.Parent = Content

local SpeedWalkCorner = Instance.new("UICorner")
SpeedWalkCorner.CornerRadius = UDim.new(0, 6)
SpeedWalkCorner.Parent = SpeedWalkSection

local SpeedBox = Instance.new("TextBox")
SpeedBox.Size = UDim2.fromOffset(55, 20)
SpeedBox.Position = UDim2.fromOffset(5, 4)
SpeedBox.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
SpeedBox.BorderSizePixel = 0
SpeedBox.Text = "1.00"
SpeedBox.PlaceholderText = "Speed"
SpeedBox.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedBox.Font = Enum.Font.GothamBold
SpeedBox.TextSize = 10
SpeedBox.TextXAlignment = Enum.TextXAlignment.Center
SpeedBox.ClearTextOnFocus = false
SpeedBox.Parent = SpeedWalkSection

local SpeedCorner = Instance.new("UICorner")
SpeedCorner.CornerRadius = UDim.new(0, 4)
SpeedCorner.Parent = SpeedBox

local FilenameBox = Instance.new("TextBox")
FilenameBox.Size = UDim2.fromOffset(125, 20)
FilenameBox.Position = UDim2.fromOffset(65, 4)
FilenameBox.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
FilenameBox.BorderSizePixel = 0
FilenameBox.Text = ""
FilenameBox.PlaceholderText = "Filename"
FilenameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
FilenameBox.Font = Enum.Font.Gotham
FilenameBox.TextSize = 10
FilenameBox.TextXAlignment = Enum.TextXAlignment.Center
FilenameBox.ClearTextOnFocus = false
FilenameBox.Parent = SpeedWalkSection

local FilenameCorner = Instance.new("UICorner")
FilenameCorner.CornerRadius = UDim.new(0, 4)
FilenameCorner.Parent = FilenameBox

local WalkSpeedBox = Instance.new("TextBox")
WalkSpeedBox.Size = UDim2.fromOffset(55, 20)
WalkSpeedBox.Position = UDim2.fromOffset(195, 4)
WalkSpeedBox.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
WalkSpeedBox.BorderSizePixel = 0
WalkSpeedBox.Text = "16"
WalkSpeedBox.PlaceholderText = "WalkSpeed"
WalkSpeedBox.TextColor3 = Color3.fromRGB(255, 255, 255)
WalkSpeedBox.Font = Enum.Font.GothamBold
WalkSpeedBox.TextSize = 10
WalkSpeedBox.TextXAlignment = Enum.TextXAlignment.Center
WalkSpeedBox.ClearTextOnFocus = false
WalkSpeedBox.Parent = SpeedWalkSection

local WalkSpeedCorner = Instance.new("UICorner")
WalkSpeedCorner.CornerRadius = UDim.new(0, 4)
WalkSpeedCorner.Parent = WalkSpeedBox

local SaveSection = Instance.new("Frame")
SaveSection.Size = UDim2.new(1, 0, 0, 55)
SaveSection.Position = UDim2.new(0, 0, 0, 70)
SaveSection.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
SaveSection.BorderSizePixel = 0
SaveSection.Parent = Content

local SaveCorner = Instance.new("UICorner")
SaveCorner.CornerRadius = UDim.new(0, 6)
SaveCorner.Parent = SaveSection

local SaveButtons = Instance.new("Frame")
SaveButtons.Size = UDim2.new(1, -6, 1, -6)
SaveButtons.Position = UDim2.new(0, 3, 0, 3)
SaveButtons.BackgroundTransparency = 1
SaveButtons.Parent = SaveSection

local SaveFileBtn = CreateControlBtn("SAVE", 0, 81, Color3.fromRGB(59, 15, 116))
SaveFileBtn.Parent = SaveButtons
SaveFileBtn.Position = UDim2.fromOffset(0, 0)

local MergeBtn = CreateControlBtn("MERGE", 84, 81, Color3.fromRGB(59, 15, 116))
MergeBtn.Parent = SaveButtons
MergeBtn.Position = UDim2.fromOffset(84, 0)

local LoadFileBtn = CreateControlBtn("LOAD", 168, 81, Color3.fromRGB(59, 15, 116))
LoadFileBtn.Parent = SaveButtons
LoadFileBtn.Position = UDim2.fromOffset(168, 0)

local CheckAllBtn = Instance.new("TextButton")
CheckAllBtn.Size = UDim2.new(1, 0, 0, 22)
CheckAllBtn.Position = UDim2.fromOffset(0, 26)
CheckAllBtn.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
CheckAllBtn.Text = "CHECKLIST ALL"
CheckAllBtn.TextColor3 = Color3.new(1, 1, 1)
CheckAllBtn.Font = Enum.Font.GothamBold
CheckAllBtn.TextSize = 11
CheckAllBtn.AutoButtonColor = false
CheckAllBtn.Parent = SaveButtons

local CheckAllCorner = Instance.new("UICorner")
CheckAllCorner.CornerRadius = UDim.new(0, 4)
CheckAllCorner.Parent = CheckAllBtn

CheckAllBtn.MouseEnter:Connect(function()
    TweenService:Create(CheckAllBtn, TweenInfo.new(0.2), {
        BackgroundColor3 = Color3.fromRGB(
            math.min(59 * 1.2, 255) / 255,
            math.min(15 * 1.2, 255) / 255,
            math.min(116 * 1.2, 255) / 255
        )
    }):Play()
end)

CheckAllBtn.MouseLeave:Connect(function()
    TweenService:Create(CheckAllBtn, TweenInfo.new(0.2), {
        BackgroundColor3 = Color3.fromRGB(59, 15, 116)
    }):Play()
end)

local RecordingsSection = Instance.new("Frame")
RecordingsSection.Size = UDim2.new(1, 0, 0, 200)
RecordingsSection.Position = UDim2.new(0, 0, 0, 131)
RecordingsSection.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
RecordingsSection.BorderSizePixel = 0
RecordingsSection.Parent = Content

local RecordingsCorner = Instance.new("UICorner")
RecordingsCorner.CornerRadius = UDim.new(0, 6)
RecordingsCorner.Parent = RecordingsSection

local RecordingsList = Instance.new("ScrollingFrame")
RecordingsList.Size = UDim2.new(1, -6, 1, -6)
RecordingsList.Position = UDim2.new(0, 3, 0, 3)
RecordingsList.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
RecordingsList.BorderSizePixel = 0
RecordingsList.ScrollBarThickness = 4
RecordingsList.ScrollBarImageColor3 = Color3.fromRGB(80, 120, 255)
RecordingsList.ScrollingDirection = Enum.ScrollingDirection.Y
RecordingsList.VerticalScrollBarInset = Enum.ScrollBarInset.Always
RecordingsList.CanvasSize = UDim2.new(0, 0, 0, 0)
RecordingsList.Parent = RecordingsSection

local ListCorner = Instance.new("UICorner")
ListCorner.CornerRadius = UDim.new(0, 4)
ListCorner.Parent = RecordingsList

local MiniButton = Instance.new("TextButton")
MiniButton.Size = UDim2.fromOffset(40, 40)
MiniButton.Position = UDim2.new(0, 10, 0, 10)
MiniButton.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
MiniButton.Text = "A"
MiniButton.TextColor3 = Color3.new(1, 1, 1)
MiniButton.Font = Enum.Font.GothamBold
MiniButton.TextSize = 25
MiniButton.Visible = true
MiniButton.Active = true
MiniButton.Draggable = false
MiniButton.Parent = ScreenGui

local MiniCorner = Instance.new("UICorner")
MiniCorner.CornerRadius = UDim.new(0, 8)
MiniCorner.Parent = MiniButton

local PlaybackControl = Instance.new("Frame")
PlaybackControl.Size = UDim2.fromOffset(156, 120)
PlaybackControl.Position = UDim2.new(0.5, -78, 0.5, -52.5)
PlaybackControl.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
PlaybackControl.BorderSizePixel = 0
PlaybackControl.Active = true
PlaybackControl.Draggable = true
PlaybackControl.Visible = false
PlaybackControl.Parent = ScreenGui

local PlaybackCorner = Instance.new("UICorner")
PlaybackCorner.CornerRadius = UDim.new(0, 8)
PlaybackCorner.Parent = PlaybackControl

local PlaybackContent = Instance.new("Frame")
PlaybackContent.Size = UDim2.new(1, -6, 1, -6)
PlaybackContent.Position = UDim2.new(0, 3, 0, 3)
PlaybackContent.BackgroundTransparency = 1
PlaybackContent.Parent = PlaybackControl

local function CreatePlaybackBtn(text, x, y, w, h, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(w, h)
    btn.Position = UDim2.fromOffset(x, y)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.AutoButtonColor = false
    btn.Parent = PlaybackContent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = btn
    
    btn.MouseEnter:Connect(function()
        task.spawn(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(
                    math.min(color.R * 255 * 1.2, 255) / 255,
                    math.min(color.G * 255 * 1.2, 255) / 255,
                    math.min(color.B * 255 * 1.2, 255) / 255
                )
            }):Play()
        end)
    end)
    
    btn.MouseLeave:Connect(function()
        task.spawn(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = color}):Play()
        end)
    end)
    
    return btn
end

local PlayBtnControl = CreatePlaybackBtn("PLAY", 3, 3, 144, 25, Color3.fromRGB(59, 15, 116))
local LoopBtnControl = CreatePlaybackBtn("Loop OFF", 3, 31, 71, 20, Color3.fromRGB(80, 80, 80))
local JumpBtnControl = CreatePlaybackBtn("Jump OFF", 77, 31, 70, 20, Color3.fromRGB(80, 80, 80))
local RespawnBtnControl = CreatePlaybackBtn("Respawn OFF", 3, 54, 71, 20, Color3.fromRGB(80, 80, 80))
local ShiftLockBtnControl = CreatePlaybackBtn("Shift OFF", 77, 54, 70, 20, Color3.fromRGB(80, 80, 80))
local ResetBtnControl = CreatePlaybackBtn("Reset OFF", 3, 77, 71, 20, Color3.fromRGB(80, 80, 80))
local ShowRuteBtnControl = CreatePlaybackBtn("Path OFF", 77, 77, 70, 20, Color3.fromRGB(80, 80, 80))

local RecordingStudio = Instance.new("Frame")
RecordingStudio.Size = UDim2.fromOffset(156, 120)
RecordingStudio.Position = UDim2.new(0.5, -78, 0.5, -50)
RecordingStudio.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
RecordingStudio.BorderSizePixel = 0
RecordingStudio.Active = true
RecordingStudio.Draggable = true
RecordingStudio.Visible = false
RecordingStudio.Parent = ScreenGui

local StudioCorner = Instance.new("UICorner")
StudioCorner.CornerRadius = UDim.new(0, 8)
StudioCorner.Parent = RecordingStudio

local StudioContent = Instance.new("Frame")
StudioContent.Size = UDim2.new(1, -6, 1, -6)
StudioContent.Position = UDim2.new(0, 3, 0, 3)
StudioContent.BackgroundTransparency = 1
StudioContent.Parent = RecordingStudio

local function CreateStudioBtn(text, x, y, w, h, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(w, h)
    btn.Position = UDim2.fromOffset(x, y)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.AutoButtonColor = false
    btn.Parent = StudioContent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = btn
    
    btn.MouseEnter:Connect(function()
        task.spawn(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(
                    math.min(color.R * 255 * 1.2, 255) / 255,
                    math.min(color.G * 255 * 1.2, 255) / 255,
                    math.min(color.B * 255 * 1.2, 255) / 255
                )
            }):Play()
        end)
    end)
    
    btn.MouseLeave:Connect(function()
        task.spawn(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = color}):Play()
        end)
    end)
    
    return btn
end

local SaveBtn = CreateStudioBtn("SAVE", 3, 3, 71, 22, Color3.fromRGB(59, 15, 116))
local StartBtn = CreateStudioBtn("START", 77, 3, 70, 22, Color3.fromRGB(59, 15, 116))
local ResumeBtn = CreateStudioBtn("RESUME", 3, 28, 144, 22, Color3.fromRGB(59, 15, 116))
local PrevBtn = CreateStudioBtn("◀ PREV", 3, 58, 71, 30, Color3.fromRGB(59, 15, 116))
local NextBtn = CreateStudioBtn("NEXT ▶", 77, 58, 70, 30, Color3.fromRGB(59, 15, 116))

local function ValidateSpeed(speedText)
    local speed = tonumber(speedText)
    if not speed then return false, "Invalid number" end
    if speed < 0.25 or speed > 100.0 then return false, "Speed must be between 0.25 and 100.0" end
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
        pcall(function()
            local char = player.Character
            if char and char:FindFirstChildOfClass("Humanoid") then
                char.Humanoid.WalkSpeed = CurrentWalkSpeed
            end
        end)
        PlaySound("Success")
    else
        WalkSpeedBox.Text = tostring(CurrentWalkSpeed)
        PlaySound("Error")
    end
end)

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

local function FormatDuration(seconds)
    local minutes = math.floor(seconds / 60)
    local remainingSeconds = math.floor(seconds % 60)
    return string.format("%d:%02d", minutes, remainingSeconds)
end

function UpdateRecordList()
    pcall(function()
        for _, child in pairs(RecordingsList:GetChildren()) do 
            if child:IsA("Frame") then child:Destroy() end
        end
        
        local yPos = 3
        for index, name in ipairs(RecordingOrder) do
            local rec = RecordedMovements[name]
            if not rec then continue end
            
            local item = Instance.new("Frame")
            item.Size = UDim2.new(1, -6, 0, 60)
            item.Position = UDim2.new(0, 3, 0, yPos)
            item.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
            item.Parent = RecordingsList
        
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 4)
            corner.Parent = item
            
            local checkBox = Instance.new("TextButton")
            checkBox.Size = UDim2.fromOffset(18, 18)
            checkBox.Position = UDim2.fromOffset(5, 5)
            checkBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            checkBox.Text = CheckedRecordings[name] and "✓" or ""
            checkBox.TextColor3 = Color3.fromRGB(100, 255, 150)
            checkBox.Font = Enum.Font.GothamBold
            checkBox.TextSize = 12
            checkBox.Parent = item
            
            local checkCorner = Instance.new("UICorner")
            checkCorner.CornerRadius = UDim.new(0, 3)
            checkCorner.Parent = checkBox
            
            local nameBox = Instance.new("TextBox")
            nameBox.Size = UDim2.new(1, -90, 0, 18)
            nameBox.Position = UDim2.fromOffset(28, 5)
            nameBox.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            nameBox.BorderSizePixel = 0
            nameBox.Text = checkpointNames[name] or "Checkpoint1"
            nameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameBox.Font = Enum.Font.GothamBold
            nameBox.TextSize = 9
            nameBox.TextXAlignment = Enum.TextXAlignment.Left
            nameBox.PlaceholderText = "Name"
            nameBox.ClearTextOnFocus = false
            nameBox.Parent = item
            
            local nameBoxCorner = Instance.new("UICorner")
            nameBoxCorner.CornerRadius = UDim.new(0, 3)
            nameBoxCorner.Parent = nameBox
            
            local infoLabel = Instance.new("TextLabel")
            infoLabel.Size = UDim2.new(1, -90, 0, 14)
            infoLabel.Position = UDim2.fromOffset(28, 25)
            infoLabel.BackgroundTransparency = 1
            if #rec > 0 then
                local totalSeconds = rec[#rec].Timestamp
                infoLabel.Text = "🕐 " .. FormatDuration(totalSeconds) .. " 📊 " .. #rec .. " frames"
            else
                infoLabel.Text = "🕐 0:00 📊 0 frames"
            end
            infoLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
            infoLabel.Font = Enum.Font.GothamBold
            infoLabel.TextSize = 8
            infoLabel.TextXAlignment = Enum.TextXAlignment.Left
            infoLabel.Parent = item
            
            local playBtn = Instance.new("TextButton")
            playBtn.Size = UDim2.fromOffset(38, 20)
            playBtn.Position = UDim2.new(1, -79, 0, 5)
            playBtn.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
            playBtn.Text = "Play"
            playBtn.TextColor3 = Color3.new(1, 1, 1)
            playBtn.Font = Enum.Font.GothamBold
            playBtn.TextSize = 9
            playBtn.Parent = item
            
            local playCorner = Instance.new("UICorner")
            playCorner.CornerRadius = UDim.new(0, 3)
            playCorner.Parent = playBtn
            
            local delBtn = Instance.new("TextButton")
            delBtn.Size = UDim2.fromOffset(38, 20)
            delBtn.Position = UDim2.new(1, -38, 0, 5)
            delBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
            delBtn.Text = "Delete"
            delBtn.TextColor3 = Color3.new(1, 1, 1)
            delBtn.Font = Enum.Font.GothamBold
            delBtn.TextSize = 8
            delBtn.Parent = item
            
            local delCorner = Instance.new("UICorner")
            delCorner.CornerRadius = UDim.new(0, 3)
            delCorner.Parent = delBtn
            
            local upBtn = Instance.new("TextButton")
            upBtn.Size = UDim2.fromOffset(38, 20)
            upBtn.Position = UDim2.new(1, -79, 0, 30)
            upBtn.BackgroundColor3 = index > 1 and Color3.fromRGB(74, 195, 147) or Color3.fromRGB(60, 60, 70)
            upBtn.Text = "Naik"
            upBtn.TextColor3 = Color3.new(1, 1, 1)
            upBtn.Font = Enum.Font.GothamBold
            upBtn.TextSize = 9
            upBtn.Parent = item
            
            local upCorner = Instance.new("UICorner")
            upCorner.CornerRadius = UDim.new(0, 3)
            upCorner.Parent = upBtn
            
            local downBtn = Instance.new("TextButton")
            downBtn.Size = UDim2.fromOffset(38, 20)
            downBtn.Position = UDim2.new(1, -38, 0, 30)
            downBtn.BackgroundColor3 = index < #RecordingOrder and Color3.fromRGB(74, 195, 147) or Color3.fromRGB(60, 60, 70)
            downBtn.Text = "Turun"
            downBtn.TextColor3 = Color3.new(1, 1, 1)
            downBtn.Font = Enum.Font.GothamBold
            downBtn.TextSize = 9
            downBtn.Parent = item
            
            local downCorner = Instance.new("UICorner")
            downCorner.CornerRadius = UDim.new(0, 3)
            downCorner.Parent = downBtn
            
            nameBox.FocusLost:Connect(function()
                local newName = nameBox.Text
                if newName and newName ~= "" then
                    checkpointNames[name] = newName
                    PlaySound("Success")
                end
            end)
            
            checkBox.MouseButton1Click:Connect(function()
                CheckedRecordings[name] = not CheckedRecordings[name]
                checkBox.Text = CheckedRecordings[name] and "✓" or ""
                AnimateButtonClick(checkBox)
            end)
            
            -- ✅ FIXED: Scope issue dengan menggunakan local variable
            local currentRecordingName = name
            playBtn.MouseButton1Click:Connect(function()
                if not IsPlaying then 
                    AnimateButtonClick(playBtn)
                    PlayRecording(currentRecordingName) 
                end
            end)
            
            delBtn.MouseButton1Click:Connect(function()
                AnimateButtonClick(delBtn)
                RecordedMovements[name] = nil
                checkpointNames[name] = nil
                CheckedRecordings[name] = nil
                PathHasBeenUsed[name] = nil
                local idx = table.find(RecordingOrder, name)
                if idx then table.remove(RecordingOrder, idx) end
                UpdateRecordList()
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
            
            yPos = yPos + 65
        end
        
        RecordingsList.CanvasSize = UDim2.new(0, 0, 0, math.max(yPos, RecordingsList.AbsoluteSize.Y))
    end)
end

local function UpdateStudioUI()
end

local function ApplyFrameToCharacter(frame)
    pcall(function()
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
    end)
end

local function StartStudioRecording()
    if StudioIsRecording then return end
    
    task.spawn(function()
        pcall(function()
            local char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then
                PlaySound("Error")
                return
            end
            
            StudioIsRecording = true
            IsTimelineMode = false
            StudioCurrentRecording = {Frames = {}, StartTime = tick(), Name = "recording_" .. os.date("%H%M%S")}
            lastStudioRecordTime = 0
            lastStudioRecordPos = nil
            CurrentTimelineFrame = 0
            TimelinePosition = 0
            
            -- ⭐ FIXED: Disable ShiftLock selama recording
            ForceDisableShiftLock()
            
            StartBtn.Text = "STOP"
            StartBtn.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
            
            PlaySound("Toggle")
            
            recordConnection = RunService.Heartbeat:Connect(function()
                task.spawn(function()
                    pcall(function()
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
                        if (now - lastStudioRecordTime) < (1 / RECORDING_FPS) then return end
                        
                        local currentPos = hrp.Position
                        local currentVelocity = hrp.AssemblyLinearVelocity
                        
                        if lastStudioRecordPos and (currentPos - lastStudioRecordPos).Magnitude < MIN_DISTANCE_THRESHOLD then
                            lastStudioRecordTime = now
                            return
                        end
                        
                        local cf = hrp.CFrame
                        local currentWalkSpeed = hum and hum.WalkSpeed or 16
                        
                        table.insert(StudioCurrentRecording.Frames, {
                            Position = {cf.Position.X, cf.Position.Y, cf.Position.Z},
                            LookVector = {cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z},
                            UpVector = {cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z},
                            Velocity = {currentVelocity.X, currentVelocity.Y, currentVelocity.Z},
                            MoveState = GetCurrentMoveState(hum),
                            WalkSpeed = currentWalkSpeed,
                            Timestamp = now - StudioCurrentRecording.StartTime
                        })
                        
                        lastStudioRecordTime = now
                        lastStudioRecordPos = currentPos
                        CurrentTimelineFrame = #StudioCurrentRecording.Frames
                        TimelinePosition = CurrentTimelineFrame
                        
                        UpdateStudioUI()
                    end)
                end)
            end)
            AddConnection(recordConnection)
        end)
    end)
end

local function StopStudioRecording()
    StudioIsRecording = false
    IsTimelineMode = false
    
    task.spawn(function()
        pcall(function()
            if recordConnection then
                recordConnection:Disconnect()
                recordConnection = nil
            end
            
            -- ⭐ FIXED: Restore ShiftLock setelah recording
            ForceEnableShiftLock()
            
            StartBtn.Text = "START"
            StartBtn.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
            
            PlaySound("Toggle")
            UpdateStudioUI()
        end)
    end)
end

local function GoBackTimeline()
    if not StudioIsRecording or #StudioCurrentRecording.Frames == 0 then
        PlaySound("Error")
        return
    end
    
    task.spawn(function()
        pcall(function()
            IsTimelineMode = true
            
            local targetFrame = math.max(1, TimelinePosition - math.floor(RECORDING_FPS * TIMELINE_STEP_SECONDS))
            
            TimelinePosition = targetFrame
            CurrentTimelineFrame = targetFrame
            
            local frame = StudioCurrentRecording.Frames[targetFrame]
            if frame then
                ApplyFrameToCharacter(frame)
                UpdateStudioUI()
                PlaySound("Click")
            end
        end)
    end)
end

local function GoNextTimeline()
    if not StudioIsRecording or #StudioCurrentRecording.Frames == 0 then
        PlaySound("Error")
        return
    end
    
    task.spawn(function()
        pcall(function()
            IsTimelineMode = true
            
            local targetFrame = math.min(#StudioCurrentRecording.Frames, TimelinePosition + math.floor(RECORDING_FPS * TIMELINE_STEP_SECONDS))
            
            TimelinePosition = targetFrame
            CurrentTimelineFrame = targetFrame
            
            local frame = StudioCurrentRecording.Frames[targetFrame]
            if frame then
                ApplyFrameToCharacter(frame)
                UpdateStudioUI()
                PlaySound("Click")
            end
        end)
    end)
end

local function ResumeStudioRecording()
    if not StudioIsRecording then
        PlaySound("Error")
        return
    end
    
    task.spawn(function()
        pcall(function()
            if #StudioCurrentRecording.Frames == 0 then
                PlaySound("Error")
                return
            end
            
            local char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then
                PlaySound("Error")
                return
            end
            
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            
            local lastRecordedFrame = StudioCurrentRecording.Frames[TimelinePosition]
            local lastState = lastRecordedFrame and lastRecordedFrame.MoveState or "Grounded"
            local lastWalkSpeed = lastRecordedFrame and lastRecordedFrame.WalkSpeed or 16
            
            if TimelinePosition < #StudioCurrentRecording.Frames then
                local newFrames = {}
                for i = 1, TimelinePosition do
                    table.insert(newFrames, StudioCurrentRecording.Frames[i])
                end
                StudioCurrentRecording.Frames = newFrames
                
                if #StudioCurrentRecording.Frames > 0 then
                    local lastFrame = StudioCurrentRecording.Frames[#StudioCurrentRecording.Frames]
                    StudioCurrentRecording.StartTime = tick() - lastFrame.Timestamp
                end
            end
            
            if #StudioCurrentRecording.Frames > 0 and INTERPOLATION_LOOKAHEAD > 0 then
                local lastFrame = StudioCurrentRecording.Frames[#StudioCurrentRecording.Frames]
                local currentPos = hrp.Position
                local lastPos = Vector3.new(lastFrame.Position[1], lastFrame.Position[2], lastFrame.Position[3])
                
                if (currentPos - lastPos).Magnitude > 0.5 then
                    for i = 1, INTERPOLATION_LOOKAHEAD do
                        local alpha = i / (INTERPOLATION_LOOKAHEAD + 1)
                        local interpPos = lastPos:Lerp(currentPos, alpha)
                        
                        local interpFrame = {
                            Position = {interpPos.X, interpPos.Y, interpPos.Z},
                            LookVector = lastFrame.LookVector,
                            UpVector = lastFrame.UpVector,
                            Velocity = lastFrame.Velocity,
                            MoveState = lastState,
                            WalkSpeed = lastWalkSpeed,
                            Timestamp = lastFrame.Timestamp + (i * (1/RECORDING_FPS)),
                            IsInterpolated = true
                        }
                        table.insert(StudioCurrentRecording.Frames, interpFrame)
                    end
                    
                    StudioCurrentRecording.StartTime = tick() - StudioCurrentRecording.Frames[#StudioCurrentRecording.Frames].Timestamp
                end
            end
            
            IsTimelineMode = false
            lastStudioRecordTime = tick()
            lastStudioRecordPos = hrp.Position
            
            if hum then
                hum.WalkSpeed = lastWalkSpeed
                hum.AutoRotate = true
            end
            
            UpdateStudioUI()
            PlaySound("Success")
        end)
    end)
end

local function SaveStudioRecording()
    task.spawn(function()
        pcall(function()
            if #StudioCurrentRecording.Frames == 0 then
                PlaySound("Error")
                return
            end
            
            if StudioIsRecording then
                StopStudioRecording()
            end
            
            local normalizedFrames = NormalizeRecordingTimestamps(StudioCurrentRecording.Frames)
            
            RecordedMovements[StudioCurrentRecording.Name] = normalizedFrames
            table.insert(RecordingOrder, StudioCurrentRecording.Name)
            checkpointNames[StudioCurrentRecording.Name] = "checkpoint_" .. #RecordingOrder
            UpdateRecordList()
            
            PlaySound("Success")
            
            StudioCurrentRecording = {Frames = {}, StartTime = 0, Name = "recording_" .. os.date("%H%M%S")}
            IsTimelineMode = false
            CurrentTimelineFrame = 0
            TimelinePosition = 0
            UpdateStudioUI()
            
            wait(1)
            RecordingStudio.Visible = false
            MainFrame.Visible = true
        end)
    end)
end

local function SaveToObfuscatedJSON()
    if not hasFileSystem then
        PlaySound("Error")
        return
    end
    
    local filename = FilenameBox.Text
    if filename == "" then filename = "MyReplays" end
    filename = filename .. ".json"
    
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
            Version = "3.2",
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
    if not hasFileSystem then
        PlaySound("Error")
        return
    end
    
    local filename = FilenameBox.Text
    if filename == "" then filename = "MyReplays" end
    filename = filename .. ".json"
    
    local success, err = pcall(function()
        if not isfile(filename) then
            PlaySound("Error")
            return
        end
        
        local jsonString = readfile(filename)
        local saveData = HttpService:JSONDecode(jsonString)
        
        local newRecordingOrder = saveData.RecordingOrder or {}
        local newCheckpointNames = saveData.CheckpointNames or {}
        
        if saveData.Obfuscated and saveData.ObfuscatedFrames then
            local deobfuscatedData = DeobfuscateRecordingData(saveData.ObfuscatedFrames)
            
            for _, checkpointData in ipairs(saveData.Checkpoints or {}) do
                local name = checkpointData.Name
                local frames = deobfuscatedData[name]
                
                if frames then
                    RecordedMovements[name] = frames
                    checkpointNames[name] = newCheckpointNames[name] or checkpointData.DisplayName
                    
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

local function VisualizeAllPaths()
    ClearPathVisualization()
    
    if not ShowPaths then return end
    
    pcall(function()
        for _, name in ipairs(RecordingOrder) do
            if PathHasBeenUsed[name] then continue end
            
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
    end)
end

-- BUTTON CONNECTIONS
PlayBtnControl.MouseButton1Click:Connect(function()
    AnimateButtonClick(PlayBtnControl)
    if IsPlaying or IsAutoLoopPlaying then
        StopPlayback()
    else
        if AutoLoop then
            StartAutoLoopAll()
        else
            SmartPlayRecording(50)
        end
    end
end)

LoopBtnControl.MouseButton1Click:Connect(function()
    AnimateButtonClick(LoopBtnControl)
    AutoLoop = not AutoLoop
    if AutoLoop then
        LoopBtnControl.Text = "Loop ON"
        LoopBtnControl.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
        if not next(RecordedMovements) then
            AutoLoop = false
            LoopBtnControl.Text = "Loop OFF"
            LoopBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
            PlaySound("Error")
            return
        end
        if IsPlaying then
            IsPlaying = false
            RestoreFullUserControl()
        end
        StartAutoLoopAll()
    else
        LoopBtnControl.Text = "Loop OFF"
        LoopBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        StopAutoLoopAll()
    end
end)

JumpBtnControl.MouseButton1Click:Connect(function()
    AnimateButtonClick(JumpBtnControl)
    ToggleInfiniteJump()
    if InfiniteJump then
        JumpBtnControl.Text = "Jump ON"
        JumpBtnControl.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
    else
        JumpBtnControl.Text = "Jump OFF"
        JumpBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    end
end)

RespawnBtnControl.MouseButton1Click:Connect(function()
    AnimateButtonClick(RespawnBtnControl)
    AutoRespawn = not AutoRespawn
    if AutoRespawn then
        RespawnBtnControl.Text = "Respawn ON"
        RespawnBtnControl.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
    else
        RespawnBtnControl.Text = "Respawn OFF"
        RespawnBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    end
    PlaySound("Toggle")
end)

ShiftLockBtnControl.MouseButton1Click:Connect(function()
    AnimateButtonClick(ShiftLockBtnControl)
    ToggleVisibleShiftLock()
    if ShiftLockEnabled then
        ShiftLockBtnControl.Text = "Shift ON"
        ShiftLockBtnControl.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
    else
        ShiftLockBtnControl.Text = "Shift OFF"
        ShiftLockBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    end
end)

ResetBtnControl.MouseButton1Click:Connect(function()
    AnimateButtonClick(ResetBtnControl)
    AutoReset = not AutoReset
    if AutoReset then
        ResetBtnControl.Text = "Reset ON"
        ResetBtnControl.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
    else
        ResetBtnControl.Text = "Reset OFF"
        ResetBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    end
    PlaySound("Toggle")
end)

ShowRuteBtnControl.MouseButton1Click:Connect(function()
    AnimateButtonClick(ShowRuteBtnControl)
    ShowPaths = not ShowPaths
    if ShowPaths then
        ShowRuteBtnControl.Text = "Path ON"
        ShowRuteBtnControl.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
        PathsHiddenOnce = false
        PathHasBeenUsed = {}
        VisualizeAllPaths()
    else
        ShowRuteBtnControl.Text = "Path OFF"
        ShowRuteBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        ClearPathVisualization()
    end
end)

PlayBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(PlayBtn)
    PlaybackControl.Visible = not PlaybackControl.Visible
end)

RecordBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(RecordBtn)
    RecordingStudio.Visible = true
end)

MenuBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(MenuBtn)
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

SaveFileBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(SaveFileBtn)
    SaveToObfuscatedJSON()
end)

LoadFileBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(LoadFileBtn)
    LoadFromObfuscatedJSON()
end)

MergeBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(MergeBtn)
    CreateMergedReplay()
end)

CheckAllBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(CheckAllBtn)
    
    local allChecked = true
    for _, name in ipairs(RecordingOrder) do
        if not CheckedRecordings[name] then
            allChecked = false
            break
        end
    end
    
    if allChecked then
        for _, name in ipairs(RecordingOrder) do
            CheckedRecordings[name] = false
        end
        CheckAllBtn.Text = "CHECKLIST ALL"
        CheckAllBtn.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
    else
        for _, name in ipairs(RecordingOrder) do
            CheckedRecordings[name] = true
        end
        CheckAllBtn.Text = "UNCHECKALL"
        CheckAllBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
    end
    
    UpdateRecordList()
    PlaySound("Toggle")
end)

StartBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        AnimateButtonClick(StartBtn)
        if StudioIsRecording then
            StopStudioRecording()
        else
            StartStudioRecording()
        end
    end)
end)

PrevBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        AnimateButtonClick(PrevBtn)
        GoBackTimeline()
    end)
end)

NextBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        AnimateButtonClick(NextBtn)
        GoNextTimeline()
    end)
end)

ResumeBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        AnimateButtonClick(ResumeBtn)
        ResumeStudioRecording()
    end)
end)

SaveBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        AnimateButtonClick(SaveBtn)
        SaveStudioRecording()
    end)
end)

CloseBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(CloseBtn)
    task.spawn(function()
        pcall(function()
            if StudioIsRecording then StopStudioRecording() end
            if IsPlaying or AutoLoop then StopPlayback() end
            if ShiftLockEnabled then DisableVisibleShiftLock() end
            if InfiniteJump then DisableInfiniteJump() end
            CleanupConnections()
            ClearPathVisualization()
            RemoveShiftLockIndicator()
            task.wait(0.2)
            ScreenGui:Destroy()
        end)
    end)
end)

-- MINI BUTTON FUNCTIONALITY
local miniSaveFile = "MiniButtonPos.json"

pcall(function()
    if hasFileSystem and isfile and isfile(miniSaveFile) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(miniSaveFile)) end)
        if ok and type(data) == "table" and data.x and data.y then
            MiniButton.Position = UDim2.fromOffset(data.x, data.y)
        end
    end
end)

MiniButton.MouseButton1Click:Connect(function()
    pcall(PlaySound, "Click")
    
    pcall(function()
        local originalSize = MiniButton.TextSize
        TweenService:Create(MiniButton, TweenInfo.new(0.1), {
            TextSize = originalSize * 1.2
        }):Play()
        task.wait(0.1)
        TweenService:Create(MiniButton, TweenInfo.new(0.1), {
            TextSize = originalSize
        }):Play()
    end)
    
    if MainFrame then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

local dragging = false
local dragStart = nil
local startPos = nil

MiniButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MiniButton.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                pcall(function()
                    if hasFileSystem and writefile and HttpService then
                        local absX = MiniButton.AbsolutePosition.X
                        local absY = MiniButton.AbsolutePosition.Y
                        writefile(miniSaveFile, HttpService:JSONEncode({x = absX, y = absY}))
                    end
                end)
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
    if not dragStart or not startPos then return end

    local delta = input.Position - dragStart
    local newX = startPos.X.Offset + delta.X
    local newY = startPos.Y.Offset + delta.Y

    local cam = workspace.CurrentCamera
    local vx, vy = (cam and cam.ViewportSize.X) or 1920, (cam and cam.ViewportSize.Y) or 1080
    newX = math.clamp(newX, 0, math.max(0, vx - MiniButton.AbsoluteSize.X))
    newY = math.clamp(newY, 0, math.max(0, vy - MiniButton.AbsoluteSize.Y))

    MiniButton.Position = UDim2.fromOffset(newX, newY)
end)

-- INITIALIZATION
UpdateRecordList()
UpdatePlayButtonStatus()
StartTitlePulse(Title)

task.spawn(function()
    while task.wait(2) do
        if not IsPlaying and not IsAutoLoopPlaying then
            UpdatePlayButtonStatus()
        end
    end
end)

if hasFileSystem then
    task.spawn(function()
        task.wait(2)
        pcall(function()
            local filename = "MyReplays.json"
            if isfile(filename) then
                FilenameBox.Text = "MyReplays"
                LoadFromObfuscatedJSON()
            end
        end)
    end)
end

player.CharacterRemoving:Connect(function()
    pcall(function()
        if StudioIsRecording then
            StopStudioRecording()
        end
        if IsPlaying and not AutoLoop then
            StopPlayback()
        end
        
        if ShiftLockEnabled then
            DisableVisibleShiftLock()
        end
    end)
end)

player.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    pcall(function()
        if ShiftLockEnabled then
            task.wait(0.5)
            EnableVisibleShiftLock()
        end
    end)
end)

game:GetService("ScriptContext").DescendantRemoving:Connect(function(descendant)
    if descendant == ScreenGui then
        pcall(function()
            CleanupConnections()
            ClearPathVisualization()
            RemoveShiftLockIndicator()
        end)
    end
end)

game:BindToClose(function()
    pcall(function()
        CleanupConnections()
        ClearPathVisualization()
        RemoveShiftLockIndicator()
    end)
end)

task.spawn(function()
    task.wait(1)
    PlaySound("Success")
end)
