
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
wait(1)

-- ========= CONFIGURATION =========
local RECORDING_FPS = 60
local PLAYBACK_FPS = 60
local MAX_FRAMES = 50000
local MIN_DISTANCE_THRESHOLD = 0.005
local VELOCITY_SCALE = 1
local VELOCITY_Y_SCALE = 1
local STATE_CHANGE_COOLDOWN = 0.05
local TRANSITION_FRAMES = 5
local PLAYBACK_FIXED_TIMESTEP = 1 / 60
local JUMP_VELOCITY_THRESHOLD = 8
local FALL_VELOCITY_THRESHOLD = -6
local SMOOTH_TRANSITION_DURATION = 0.3
local LOOP_TRANSITION_DELAY = 0.1
local AUTO_LOOP_RETRY_DELAY = 0.5

-- ========= FIELD MAPPING FOR OBFUSCATION =========
local FIELD_MAPPING = {
    Position = "11",
    LookVector = "88", 
    UpVector = "55",
    Velocity = "22",
    MoveState = "33",
    WalkSpeed = "44",
    Timestamp = "66",
    RealTime = "77"
}

local REVERSE_MAPPING = {
    ["11"] = "Position",
    ["88"] = "LookVector",
    ["55"] = "UpVector", 
    ["22"] = "Velocity",
    ["33"] = "MoveState",
    ["44"] = "WalkSpeed",
    ["66"] = "Timestamp",
    ["77"] = "RealTime"
}

-- ========= VARIABLES =========
local IsRecording = false
local IsPlaying = false
local IsPaused = false
local CurrentSpeed = 1
local CurrentWalkSpeed = 16
local RecordedMovements = {}
local RecordingOrder = {}
local CurrentRecording = {Frames = {}, StartTime = 0, RealStartTime = 0, Name = ""}
local AutoRespawn = false
local InfiniteJump = false
local AutoLoop = false
local AutoReset = false
local recordConnection = nil
local playbackConnection = nil
local loopConnection = nil
local jumpConnection = nil
local shiftLockConnection = nil
local lastRecordTime = 0
local lastRecordRealTime = 0
local lastRecordPos = nil
local checkpointNames = {}
local PathVisualization = {}
local ShowPaths = false
local CurrentPauseMarker = nil
local currentPlaybackFrame = 1
local prePauseHumanoidState = nil
local prePauseWalkSpeed = 16
local prePauseAutoRotate = true
local prePauseJumpPower = 50
local prePausePlatformStand = false
local prePauseSit = false
local lastPlaybackState = nil
local lastStateChangeTime = 0
local lastStateChangeRealTime = 0
local IsAutoLoopPlaying = false
local CurrentLoopIndex = 1
local originalMouseBehavior = nil
local ShiftLockEnabled = false
local isShiftLockActive = false
local StudioIsRecording = false
local StudioCurrentRecording = {Frames = {}, StartTime = 0, RealStartTime = 0, Name = ""}
local lastStudioRecordTime = 0
local lastStudioRecordRealTime = 0
local lastStudioRecordPos = nil
local activeConnections = {}
local CheckedRecordings = {}
local CurrentTimelineFrame = 0
local TimelinePosition = 0
local CurrentPlayingRecording = nil
local PausedAtFrame = 0
local LastPausePosition = nil
local LastPauseRecording = nil
local NearestRecordingDistance = math.huge
local LoopRetryAttempts = 0
local MaxLoopRetries = 999
local IsLoopTransitioning = false
local virtualPlaybackTime = 0

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

local function AddConnection(connection)
    table.insert(activeConnections, connection)
end

local function CleanupConnections()
    for _, connection in ipairs(activeConnections) do
        if connection and typeof(connection) == "RBXScriptConnection" then
            connection:Disconnect()
        end
    end
    activeConnections = {}
    
    if recordConnection then recordConnection:Disconnect() recordConnection = nil end
    if playbackConnection then playbackConnection:Disconnect() playbackConnection = nil end
    if loopConnection then 
        if typeof(loopConnection) == "thread" then
            task.cancel(loopConnection)
        elseif typeof(loopConnection) == "RBXScriptConnection" then
            loopConnection:Disconnect()
        end
        loopConnection = nil 
    end
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

local function AnimateButtonClick(button)
    task.spawn(function()
        PlaySound("Click")
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
    task.wait(0.5)
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
        if prePauseHumanoidState == Enum.HumanoidStateType.Climbing then
            humanoid.PlatformStand = false
            humanoid.AutoRotate = false
        end
    end
end

local function RestoreHumanoidState()
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
    if ShiftLockEnabled then
        EnableVisibleShiftLock()
    end
end

local function GetCurrentMoveState(hum, velocity)
    if not hum then return "Grounded" end
    
    local state = hum:GetState()
    local velocityY = velocity and velocity.Y or 0
    
    if state == Enum.HumanoidStateType.Climbing then 
        return "Climbing"
    elseif velocityY > JUMP_VELOCITY_THRESHOLD then 
        return "Jumping"
    elseif velocityY < FALL_VELOCITY_THRESHOLD then 
        return "Falling"
    elseif state == Enum.HumanoidStateType.Swimming then 
        return "Swimming"
    elseif state == Enum.HumanoidStateType.Jumping then
        return "Jumping"
    elseif state == Enum.HumanoidStateType.Freefall then
        return "Falling"
    elseif state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics then 
        return "Grounded"
    else 
        return "Grounded" 
    end
end

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

local function NormalizeRecordingTimestamps(frames)
    if #frames == 0 then return frames end
    
    local normalized = {}
    local virtualTime = 0
    local frameInterval = 1 / RECORDING_FPS
    
    for i, frame in ipairs(frames) do
        local newFrame = {}
        for k, v in pairs(frame) do
            newFrame[k] = v
        end
        newFrame.Timestamp = virtualTime
        virtualTime = virtualTime + frameInterval
        table.insert(normalized, newFrame)
    end
    
    return normalized
end

local function CreateSmoothTransition(lastFrame, firstFrame, numFrames)
    local transitionFrames = {}
    for i = 1, numFrames do
        local alpha = i / (numFrames + 1)
        local smoothAlpha = alpha * alpha * (3 - 2 * alpha)
        
        local pos1 = Vector3.new(lastFrame.Position[1], lastFrame.Position[2], lastFrame.Position[3])
        local pos2 = Vector3.new(firstFrame.Position[1], firstFrame.Position[2], firstFrame.Position[3])
        local lerpedPos = pos1:Lerp(pos2, smoothAlpha)
        local look1 = Vector3.new(lastFrame.LookVector[1], lastFrame.LookVector[2], lastFrame.LookVector[3])
        local look2 = Vector3.new(firstFrame.LookVector[1], firstFrame.LookVector[2], firstFrame.LookVector[3])
        local lerpedLook = look1:Lerp(look2, smoothAlpha).Unit
        local up1 = Vector3.new(lastFrame.UpVector[1], lastFrame.UpVector[2], lastFrame.UpVector[3])
        local up2 = Vector3.new(firstFrame.UpVector[1], firstFrame.UpVector[2], firstFrame.UpVector[3])
        local lerpedUp = up1:Lerp(up2, smoothAlpha).Unit
        local vel1 = Vector3.new(lastFrame.Velocity[1], lastFrame.Velocity[2], lastFrame.Velocity[3])
        local vel2 = Vector3.new(firstFrame.Velocity[1], firstFrame.Velocity[2], firstFrame.Velocity[3])
        local lerpedVel = vel1:Lerp(vel2, smoothAlpha)
        local ws1 = lastFrame.WalkSpeed
        local ws2 = firstFrame.WalkSpeed
        local lerpedWS = ws1 + (ws2 - ws1) * smoothAlpha
        table.insert(transitionFrames, {
            Position = {lerpedPos.X, lerpedPos.Y, lerpedPos.Z},
            LookVector = {lerpedLook.X, lerpedLook.Y, lerpedLook.Z},
            UpVector = {lerpedUp.X, lerpedUp.Y, lerpedUp.Z},
            Velocity = {lerpedVel.X, lerpedVel.Y, lerpedVel.Z},
            MoveState = lastFrame.MoveState,
            WalkSpeed = lerpedWS,
            Timestamp = lastFrame.Timestamp + (i * (1 / RECORDING_FPS)),
            RealTime = lastFrame.RealTime or lastFrame.Timestamp
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
            totalTimeOffset = totalTimeOffset + (TRANSITION_FRAMES * (1 / RECORDING_FPS))
        end
        for frameIndex, frame in ipairs(checkpoint) do
            local newFrame = {
                Position = {frame.Position[1], frame.Position[2], frame.Position[3]},
                LookVector = {frame.LookVector[1], frame.LookVector[2], frame.LookVector[3]},
                UpVector = {frame.UpVector[1], frame.UpVector[2], frame.UpVector[3]},
                Velocity = {frame.Velocity[1], frame.Velocity[2], frame.Velocity[3]},
                MoveState = frame.MoveState,
                WalkSpeed = frame.WalkSpeed,
                Timestamp = frame.Timestamp + totalTimeOffset,
                RealTime = frame.RealTime or frame.Timestamp
            }
            table.insert(mergedFrames, newFrame)
        end
        if #checkpoint > 0 then
            totalTimeOffset = totalTimeOffset + checkpoint[#checkpoint].Timestamp + 0.1
        end
    end
    
    mergedFrames = NormalizeRecordingTimestamps(mergedFrames)
    
    local mergedName = "merged_" .. os.date("%H%M%S")
    RecordedMovements[mergedName] = mergedFrames
    table.insert(RecordingOrder, mergedName)
    checkpointNames[mergedName] = "MERGED ALL"
    UpdateRecordList()
    PlaySound("Success")
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
        else
            PlayBtnControl.Text = "PLAY"
        end
    end
end

local function ProcessHumanoidState(hum, frame, lastState, lastStateTime)
    if not hum then return lastState, lastStateTime end
    
    local moveState = frame.MoveState
    local frameVelocity = GetFrameVelocity(frame)
    local currentTime = tick()
    
    local isJumpingByVelocity = frameVelocity.Y > JUMP_VELOCITY_THRESHOLD
    local isFallingByVelocity = frameVelocity.Y < FALL_VELOCITY_THRESHOLD
    
    if isJumpingByVelocity and moveState ~= "Jumping" and moveState ~= "Climbing" then
        moveState = "Jumping"
    elseif isFallingByVelocity and moveState ~= "Falling" and moveState ~= "Climbing" then
        moveState = "Falling"
    end
    
    if moveState ~= lastState then
        if (currentTime - lastStateTime) >= STATE_CHANGE_COOLDOWN then
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
            return moveState, currentTime
        end
    end
    
    return lastState, lastStateTime
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

-- ========= RECORDING STUDIO GUI =========
local RecordingStudio = Instance.new("Frame")
RecordingStudio.Size = UDim2.fromOffset(250, 140)
RecordingStudio.Position = UDim2.new(0.5, -125, 0.3, 0)
RecordingStudio.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
RecordingStudio.BorderSizePixel = 0
RecordingStudio.Active = true
RecordingStudio.Draggable = true
RecordingStudio.Visible = false
RecordingStudio.Parent = ScreenGui

local StudioCorner = Instance.new("UICorner")
StudioCorner.CornerRadius = UDim.new(0, 8)
StudioCorner.Parent = RecordingStudio

local StudioHeader = Instance.new("Frame")
StudioHeader.Size = UDim2.new(1, 0, 0, 30)
StudioHeader.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
StudioHeader.BorderSizePixel = 0
StudioHeader.Parent = RecordingStudio

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 8)
HeaderCorner.Parent = StudioHeader

local StudioTitle = Instance.new("TextLabel")
StudioTitle.Size = UDim2.new(1, -60, 1, 0)
StudioTitle.Position = UDim2.new(0, 30, 0, 0)
StudioTitle.BackgroundTransparency = 1
StudioTitle.Text = "RECORDING STUDIO"
StudioTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
StudioTitle.Font = Enum.Font.GothamBold
StudioTitle.TextSize = 12
StudioTitle.Parent = StudioHeader

local RecordingLED = Instance.new("Frame")
RecordingLED.Size = UDim2.fromOffset(12, 12)
RecordingLED.Position = UDim2.new(0, 10, 0.5, -6)
RecordingLED.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
RecordingLED.BorderSizePixel = 0
RecordingLED.Visible = false
RecordingLED.Parent = StudioHeader

local LEDCorner = Instance.new("UICorner")
LEDCorner.CornerRadius = UDim.new(1, 0)
LEDCorner.Parent = RecordingLED

local CloseStudioBtn = Instance.new("TextButton")
CloseStudioBtn.Size = UDim2.fromOffset(24, 24)
CloseStudioBtn.Position = UDim2.new(1, -27, 0.5, -12)
CloseStudioBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
CloseStudioBtn.Text = "X"
CloseStudioBtn.TextColor3 = Color3.new(1, 1, 1)
CloseStudioBtn.Font = Enum.Font.GothamBold
CloseStudioBtn.TextSize = 14
CloseStudioBtn.Parent = StudioHeader

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseStudioBtn

local StudioContent = Instance.new("Frame")
StudioContent.Size = UDim2.new(1, -16, 1, -38)
StudioContent.Position = UDim2.new(0, 8, 0, 34)
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
    btn.TextSize = 13
    btn.AutoButtonColor = false
    btn.Parent = StudioContent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(
                math.min(color.R * 255 + 30, 255) / 255,
                math.min(color.G * 255 + 30, 255) / 255,
                math.min(color.B * 255 + 30, 255) / 255
            )
        }):Play()
    end)
    
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = color}):Play()
    end)
    
    return btn
end

local SaveBtn = CreateStudioBtn("SAVE", 4, 4, 110, 30, Color3.fromRGB(100, 50, 200))
local StartBtn = CreateStudioBtn("REC", 118, 4, 110, 30, Color3.fromRGB(200, 50, 60))
local ResumeBtn = CreateStudioBtn("RESUME", 4, 38, 224, 28, Color3.fromRGB(100, 50, 200))
local PrevBtn = CreateStudioBtn("PREV", 4, 70, 110, 28, Color3.fromRGB(100, 50, 200))
local NextBtn = CreateStudioBtn("NEXT", 118, 70, 110, 28, Color3.fromRGB(100, 50, 200))

-- ========= PLAYBACK CONTROL GUI =========
local PlaybackControl = Instance.new("Frame")
PlaybackControl.Size = UDim2.fromOffset(250, 200)
PlaybackControl.Position = UDim2.new(0.5, -125, 0.3, 0)
PlaybackControl.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
PlaybackControl.BorderSizePixel = 0
PlaybackControl.Active = true
PlaybackControl.Draggable = true
PlaybackControl.Visible = false
PlaybackControl.Parent = ScreenGui

local PlaybackCorner = Instance.new("UICorner")
PlaybackCorner.CornerRadius = UDim.new(0, 8)
PlaybackCorner.Parent = PlaybackControl

local PlaybackHeader = Instance.new("Frame")
PlaybackHeader.Size = UDim2.new(1, 0, 0, 30)
PlaybackHeader.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
PlaybackHeader.BorderSizePixel = 0
PlaybackHeader.Parent = PlaybackControl

local PlaybackHeaderCorner = Instance.new("UICorner")
PlaybackHeaderCorner.CornerRadius = UDim.new(0, 8)
PlaybackHeaderCorner.Parent = PlaybackHeader

local PlaybackTitle = Instance.new("TextLabel")
PlaybackTitle.Size = UDim2.new(1, -30, 1, 0)
PlaybackTitle.BackgroundTransparency = 1
PlaybackTitle.Text = "PLAYBACK CONTROL"
PlaybackTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
PlaybackTitle.Font = Enum.Font.GothamBold
PlaybackTitle.TextSize = 12
PlaybackTitle.Parent = PlaybackHeader

local ClosePlaybackBtn = Instance.new("TextButton")
ClosePlaybackBtn.Size = UDim2.fromOffset(24, 24)
ClosePlaybackBtn.Position = UDim2.new(1, -27, 0.5, -12)
ClosePlaybackBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
ClosePlaybackBtn.Text = "X"
ClosePlaybackBtn.TextColor3 = Color3.new(1, 1, 1)
ClosePlaybackBtn.Font = Enum.Font.GothamBold
ClosePlaybackBtn.TextSize = 14
ClosePlaybackBtn.Parent = PlaybackHeader

local ClosePlaybackCorner = Instance.new("UICorner")
ClosePlaybackCorner.CornerRadius = UDim.new(0, 6)
ClosePlaybackCorner.Parent = ClosePlaybackBtn

local PlaybackContent = Instance.new("Frame")
PlaybackContent.Size = UDim2.new(1, -16, 1, -38)
PlaybackContent.Position = UDim2.new(0, 8, 0, 34)
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
    btn.TextSize = 14
    btn.AutoButtonColor = false
    btn.Parent = PlaybackContent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(
                math.min(color.R * 255 + 30, 255) / 255,
                math.min(color.G * 255 + 30, 255) / 255,
                math.min(color.B * 255 + 30, 255) / 255
            )
        }):Play()
    end)
    
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = color}):Play()
    end)
    
    return btn
end

local function CreateModernToggle(text, x, y, w, h, default)
    local container = Instance.new("Frame")
    container.Size = UDim2.fromOffset(w, h)
    container.Position = UDim2.fromOffset(x, y)
    container.BackgroundTransparency = 1
    container.Parent = PlaybackContent
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundColor3 = default and Color3.fromRGB(100, 50, 200) or Color3.fromRGB(60, 60, 65)
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = container
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.Parent = btn
    
    local function UpdateToggle(isOn)
        PlaySound("Toggle")
        local targetColor = isOn and Color3.fromRGB(100, 50, 200) or Color3.fromRGB(60, 60, 65)
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(btn, tweenInfo, {BackgroundColor3 = targetColor}):Play()
    end
    
    return btn, UpdateToggle
end

local PlayBtnControl = CreatePlaybackBtn("PLAY", 4, 4, 224, 36, Color3.fromRGB(100, 50, 200))

local LoopBtnControl, AnimateLoopControl = CreateModernToggle("Loop OFF", 4, 44, 110, 28, false)
local ShiftBtnControl, AnimateShiftControl = CreateModernToggle("Shift OFF", 118, 44, 110, 28, false)

local RespawnBtnControl, AnimateRespawnControl = CreateModernToggle("Respawn OFF", 4, 76, 110, 28, false)
local ResetBtnControl, AnimateResetControl = CreateModernToggle("Reset OFF", 118, 76, 110, 28, false)

local JumpBtnControl, AnimateJumpControl = CreateModernToggle("Jump OFF", 4, 108, 224, 28, false)

local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Size = UDim2.new(1, 0, 0, 16)
SpeedLabel.Position = UDim2.fromOffset(0, 140)
SpeedLabel.BackgroundTransparency = 1
SpeedLabel.Text = "Speed Multiplier"
SpeedLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
SpeedLabel.Font = Enum.Font.GothamBold
SpeedLabel.TextSize = 11
SpeedLabel.Parent = PlaybackContent

local SpeedBox = Instance.new("TextBox")
SpeedBox.Size = UDim2.fromOffset(224, 24)
SpeedBox.Position = UDim2.fromOffset(4, 158)
SpeedBox.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
SpeedBox.BorderSizePixel = 0
SpeedBox.Text = "1.00"
SpeedBox.PlaceholderText = "Speed"
SpeedBox.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedBox.Font = Enum.Font.GothamBold
SpeedBox.TextSize = 12
SpeedBox.TextXAlignment = Enum.TextXAlignment.Center
SpeedBox.ClearTextOnFocus = false
SpeedBox.Parent = PlaybackContent

local SpeedCorner = Instance.new("UICorner")
SpeedCorner.CornerRadius = UDim.new(0, 6)
SpeedCorner.Parent = SpeedBox

-- ========= MAIN GUI =========
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.fromOffset(250, 300)
MainFrame.Position = UDim2.new(0.5, -125, 0.5, -150)
MainFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 30)
Header.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner2 = Instance.new("UICorner")
HeaderCorner2.CornerRadius = UDim.new(0, 8)
HeaderCorner2.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 1, 0)
Title.BackgroundTransparency = 1
Title.Text = "ByaruL Recorder"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Center
Title.Parent = Header

local HideButton = Instance.new("TextButton")
HideButton.Size = UDim2.fromOffset(24, 24)
HideButton.Position = UDim2.new(1, -55, 0.5, -12)
HideButton.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
HideButton.Text = "_"
HideButton.TextColor3 = Color3.new(1, 1, 1)
HideButton.Font = Enum.Font.GothamBold
HideButton.TextSize = 14
HideButton.Parent = Header

local HideCorner2 = Instance.new("UICorner")
HideCorner2.CornerRadius = UDim.new(0, 6)
HideCorner2.Parent = HideButton

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.fromOffset(24, 24)
CloseButton.Position = UDim2.new(1, -27, 0.5, -12)
CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.new(1, 1, 1)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 14
CloseButton.Parent = Header

local CloseCorner2 = Instance.new("UICorner")
CloseCorner2.CornerRadius = UDim.new(0, 6)
CloseCorner2.Parent = CloseButton

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -16, 1, -38)
Content.Position = UDim2.new(0, 8, 0, 34)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

local MiniButton = Instance.new("TextButton")
MiniButton.Size = UDim2.fromOffset(40, 40)
MiniButton.Position = UDim2.new(0.5, -20, 0, -30)
MiniButton.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
MiniButton.Text = "B"
MiniButton.TextColor3 = Color3.new(1, 1, 1)
MiniButton.Font = Enum.Font.GothamBold
MiniButton.TextSize = 20
MiniButton.Visible = false
MiniButton.Active = true
MiniButton.Draggable = true
MiniButton.Parent = ScreenGui

local MiniCorner2 = Instance.new("UICorner")
MiniCorner2.CornerRadius = UDim.new(0, 8)
MiniCorner2.Parent = MiniButton

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
    
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(
                math.min(color.R * 255 + 30, 255) / 255,
                math.min(color.G * 255 + 30, 255) / 255,
                math.min(color.B * 255 + 30, 255) / 255
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

local OpenStudioBtn = CreateButton("RECORD", 0, 2, 73, 30, Color3.fromRGB(100, 50, 200))
local MenuBtn = CreateButton("MENU", 77, 2, 73, 30, Color3.fromRGB(100, 50, 200))
local PlaybackBtn = CreateButton("PLAY", 154, 2, 78, 30, Color3.fromRGB(100, 50, 200))

local FilenameBox = Instance.new("TextBox")
FilenameBox.Size = UDim2.fromOffset(224, 24)
FilenameBox.Position = UDim2.fromOffset(4, 36)
FilenameBox.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
FilenameBox.BorderSizePixel = 0
FilenameBox.Text = ""
FilenameBox.PlaceholderText = "Filename"
FilenameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
FilenameBox.Font = Enum.Font.GothamBold
FilenameBox.TextSize = 10
FilenameBox.TextXAlignment = Enum.TextXAlignment.Center
FilenameBox.ClearTextOnFocus = false
FilenameBox.Parent = Content

local FilenameCorner = Instance.new("UICorner")
FilenameCorner.CornerRadius = UDim.new(0, 6)
FilenameCorner.Parent = FilenameBox

local SaveFileBtn = CreateButton("SAVE", 4, 64, 110, 28, Color3.fromRGB(100, 50, 200))
local LoadFileBtn = CreateButton("LOAD", 118, 64, 110, 28, Color3.fromRGB(100, 50, 200))

local PathToggleBtn = CreateButton("PATH", 4, 96, 110, 28, Color3.fromRGB(100, 50, 200))
local MergeBtn = CreateButton("MERGE", 118, 96, 110, 28, Color3.fromRGB(100, 50, 200))

local RecordList = Instance.new("ScrollingFrame")
RecordList.Size = UDim2.new(1, 0, 0, 130)
RecordList.Position = UDim2.fromOffset(4, 128)
RecordList.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
RecordList.BorderSizePixel = 0
RecordList.ScrollBarThickness = 4
RecordList.ScrollBarImageColor3 = Color3.fromRGB(100, 50, 200)
RecordList.ScrollingDirection = Enum.ScrollingDirection.Y
RecordList.VerticalScrollBarInset = Enum.ScrollBarInset.Always
RecordList.CanvasSize = UDim2.new(0, 0, 0, 0)
RecordList.Parent = Content

local ListCorner = Instance.new("UICorner")
ListCorner.CornerRadius = UDim.new(0, 6)
ListCorner.Parent = RecordList

local CreditLabel = Instance.new("TextLabel")
CreditLabel.Size = UDim2.new(1, 0, 0, 16)
CreditLabel.Position = UDim2.fromOffset(4, 262)
CreditLabel.BackgroundTransparency = 1
CreditLabel.Text = "ByaruL Recorder v2.3"
CreditLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
CreditLabel.Font = Enum.Font.GothamBold
CreditLabel.TextSize = 9
CreditLabel.TextXAlignment = Enum.TextXAlignment.Center
CreditLabel.Parent = Content

local function ValidateSpeed(speedText)
    local speed = tonumber(speedText)
    if not speed then return false, "Invalid number" end
    if speed < 0.5 or speed > 30 then return false, "Speed must be between 0.5 and 30" end
    return true, speed
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
    for _, child in pairs(RecordList:GetChildren()) do 
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local yPos = 0
    for index, name in ipairs(RecordingOrder) do
        local rec = RecordedMovements[name]
        if not rec then continue end
        
        local item = Instance.new("Frame")
        item.Size = UDim2.new(1, -8, 0, 50)
        item.Position = UDim2.new(0, 4, 0, yPos)
        item.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
        item.Parent = RecordList
    
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = item
        
        local playBtn = Instance.new("TextButton")
        playBtn.Size = UDim2.fromOffset(32, 20)
        playBtn.Position = UDim2.fromOffset(4, 5)
        playBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
        playBtn.Text = "P"
        playBtn.TextColor3 = Color3.new(1, 1, 1)
        playBtn.Font = Enum.Font.GothamBold
        playBtn.TextSize = 12
        playBtn.Parent = item
        
        local playCorner = Instance.new("UICorner")
        playCorner.CornerRadius = UDim.new(0, 4)
        playCorner.Parent = playBtn
        
        local delBtn = Instance.new("TextButton")
        delBtn.Size = UDim2.fromOffset(32, 20)
        delBtn.Position = UDim2.fromOffset(39, 5)
        delBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
        delBtn.Text = "D"
        delBtn.TextColor3 = Color3.new(1, 1, 1)
        delBtn.Font = Enum.Font.GothamBold
        delBtn.TextSize = 12
        delBtn.Parent = item
        
        local delCorner = Instance.new("UICorner")
        delCorner.CornerRadius = UDim.new(0, 4)
        delCorner.Parent = delBtn
        
        local checkBox = Instance.new("TextButton")
        checkBox.Size = UDim2.fromOffset(18, 18)
        checkBox.Position = UDim2.fromOffset(76, 6)
        checkBox.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
        checkBox.Text = CheckedRecordings[name] and "V" or ""
        checkBox.TextColor3 = Color3.fromRGB(100, 255, 150)
        checkBox.Font = Enum.Font.GothamBold
        checkBox.TextSize = 12
        checkBox.Parent = item
        
        local checkCorner = Instance.new("UICorner")
        checkCorner.CornerRadius = UDim.new(0, 3)
        checkCorner.Parent = checkBox
        
        local nameBox = Instance.new("TextBox")
        nameBox.Size = UDim2.new(0, 78, 0, 20)
        nameBox.Position = UDim2.fromOffset(98, 5)
        nameBox.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
        nameBox.BorderSizePixel = 0
        nameBox.Text = checkpointNames[name] or "Checkpoint"
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
        
        local upBtn = Instance.new("TextButton")
        upBtn.Size = UDim2.fromOffset(22, 20)
        upBtn.Position = UDim2.new(1, -48, 0, 5)
        upBtn.BackgroundColor3 = index > 1 and Color3.fromRGB(100, 50, 200) or Color3.fromRGB(60, 60, 65)
        upBtn.Text = "U"
        upBtn.TextColor3 = Color3.new(1, 1, 1)
        upBtn.Font = Enum.Font.GothamBold
        upBtn.TextSize = 12
        upBtn.Parent = item
        
        local upCorner = Instance.new("UICorner")
        upCorner.CornerRadius = UDim.new(0, 3)
        upCorner.Parent = upBtn
        
        local downBtn = Instance.new("TextButton")
        downBtn.Size = UDim2.fromOffset(22, 20)
        downBtn.Position = UDim2.new(1, -24, 0, 5)
        downBtn.BackgroundColor3 = index < #RecordingOrder and Color3.fromRGB(100, 50, 200) or Color3.fromRGB(60, 60, 65)
        downBtn.Text = "D"
        downBtn.TextColor3 = Color3.new(1, 1, 1)
        downBtn.Font = Enum.Font.GothamBold
        downBtn.TextSize = 12
        downBtn.Parent = item
        
        local downCorner = Instance.new("UICorner")
        downCorner.CornerRadius = UDim.new(0, 3)
        downCorner.Parent = downBtn
        
        local infoLabel = Instance.new("TextLabel")
        infoLabel.Size = UDim2.new(1, -8, 0, 18)
        infoLabel.Position = UDim2.fromOffset(4, 28)
        infoLabel.BackgroundTransparency = 1
        if #rec > 0 then
            local totalSeconds = rec[#rec].Timestamp
            infoLabel.Text = FormatDuration(totalSeconds) .. " - " .. #rec .. " frames"
        else
            infoLabel.Text = "0:00 - 0 frames"
        end
        infoLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
        infoLabel.Font = Enum.Font.GothamBold
        infoLabel.TextSize = 9
        infoLabel.TextXAlignment = Enum.TextXAlignment.Center
        infoLabel.Parent = item
        
        nameBox.FocusLost:Connect(function()
            local newName = nameBox.Text
            if newName and newName ~= "" then
                checkpointNames[name] = newName
                PlaySound("Success")
            end
        end)
        
        checkBox.MouseButton1Click:Connect(function()
            CheckedRecordings[name] = not CheckedRecordings[name]
            checkBox.Text = CheckedRecordings[name] and "V" or ""
            AnimateButtonClick(checkBox)
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
            if not IsPlaying and not IsAutoLoopPlaying then 
                AnimateButtonClick(playBtn)
                PlayRecording(name) 
            end
        end)
        
        delBtn.MouseButton1Click:Connect(function()
            AnimateButtonClick(delBtn)
            RecordedMovements[name] = nil
            checkpointNames[name] = nil
            CheckedRecordings[name] = nil
            local idx = table.find(RecordingOrder, name)
            if idx then table.remove(RecordingOrder, idx) end
            UpdateRecordList()
        end)
        
        yPos = yPos + 54
    end
    
    RecordList.CanvasSize = UDim2.new(0, 0, 0, math.max(yPos, RecordList.AbsoluteSize.Y))
end

local function UpdateStudioUI()
    if StudioIsRecording then
        StudioTitle.Text = "RECORDING - Frame: " .. CurrentTimelineFrame
    else
        StudioTitle.Text = "RECORDING STUDIO"
    end
end

local function ApplyFrameToCharacter(frame)
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    
    if not hrp or not hum then return end
    
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
end

local function StartStudioRecording()
    if StudioIsRecording then return end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        PlaySound("Error")
        return
    end
    
    StudioIsRecording = true
    local currentTime = tick()
    StudioCurrentRecording = {
        Frames = {}, 
        StartTime = 0, 
        RealStartTime = currentTime, 
        Name = "recording_" .. os.date("%H%M%S")
    }
    lastStudioRecordTime = 0
    lastStudioRecordRealTime = currentTime
    lastStudioRecordPos = nil
    CurrentTimelineFrame = 0
    TimelinePosition = 0
    
    StartBtn.Text = "STOP"
    StartBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
    RecordingLED.Visible = true
    
    PlaySound("RecordStart")
    
    recordConnection = RunService.Heartbeat:Connect(function()
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") or #StudioCurrentRecording.Frames >= MAX_FRAMES then
            return
        end
        
        local hrp = char.HumanoidRootPart
        local hum = char:FindFirstChildOfClass("Humanoid")
        
        local now = tick()
        local virtualNow = #StudioCurrentRecording.Frames * (1 / RECORDING_FPS)
        
        if (now - lastStudioRecordRealTime) < (1 / RECORDING_FPS) then return end
        
        local currentPos = hrp.Position
        local currentVelocity = hrp.AssemblyLinearVelocity
        
        if lastStudioRecordPos and (currentPos - lastStudioRecordPos).Magnitude < MIN_DISTANCE_THRESHOLD then
            lastStudioRecordRealTime = now
            return
        end
        
        local cf = hrp.CFrame
        local moveState = GetCurrentMoveState(hum, currentVelocity)
        
        table.insert(StudioCurrentRecording.Frames, {
            Position = {cf.Position.X, cf.Position.Y, cf.Position.Z},
            LookVector = {cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z},
            UpVector = {cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z},
            Velocity = {currentVelocity.X, currentVelocity.Y, currentVelocity.Z},
            MoveState = moveState,
            WalkSpeed = hum and hum.WalkSpeed or 16,
            Timestamp = virtualNow,
            RealTime = now - StudioCurrentRecording.RealStartTime
        })
        
        lastStudioRecordRealTime = now
        lastStudioRecordTime = virtualNow
        lastStudioRecordPos = currentPos
        CurrentTimelineFrame = #StudioCurrentRecording.Frames
        TimelinePosition = CurrentTimelineFrame
        
        UpdateStudioUI()
    end)
    AddConnection(recordConnection)
end

local function StopStudioRecording()
    StudioIsRecording = false
    
    if recordConnection then
        recordConnection:Disconnect()
        recordConnection = nil
    end
    
    StartBtn.Text = "REC"
    StartBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
    RecordingLED.Visible = false
    
    PlaySound("RecordStop")
    UpdateStudioUI()
end

local function GoBackTimeline()
    if not StudioIsRecording or #StudioCurrentRecording.Frames == 0 then
        PlaySound("Error")
        return
    end
    
    local targetFrame = math.max(1, TimelinePosition - 5)
    
    TimelinePosition = targetFrame
    CurrentTimelineFrame = targetFrame
    
    local frame = StudioCurrentRecording.Frames[targetFrame]
    if frame then
        ApplyFrameToCharacter(frame)
        UpdateStudioUI()
        PlaySound("Click")
    end
end

local function GoNextTimeline()
    if not StudioIsRecording or #StudioCurrentRecording.Frames == 0 then
        PlaySound("Error")
        return
    end
    
    local targetFrame = math.min(#StudioCurrentRecording.Frames, TimelinePosition + 5)
    
    TimelinePosition = targetFrame
    CurrentTimelineFrame = targetFrame
    
    local frame = StudioCurrentRecording.Frames[targetFrame]
    if frame then
        ApplyFrameToCharacter(frame)
        UpdateStudioUI()
        PlaySound("Click")
    end
end

local function ResumeStudioRecording()
    if not StudioIsRecording then
        PlaySound("Error")
        return
    end
    
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
    
    if TimelinePosition < #StudioCurrentRecording.Frames then
        local newFrames = {}
        for i = 1, TimelinePosition do
            table.insert(newFrames, StudioCurrentRecording.Frames[i])
        end
        StudioCurrentRecording.Frames = newFrames
    end
    
    local lastFrame = StudioCurrentRecording.Frames[#StudioCurrentRecording.Frames]
    local currentPos = hrp.Position
    local lastPos = GetFramePosition(lastFrame)
    local distance = (currentPos - lastPos).Magnitude
    
    if distance > 0.5 then
        local transitionFrames = CreateSmoothTransition(
            lastFrame, 
            {
                Position = {currentPos.X, currentPos.Y, currentPos.Z},
                LookVector = {hrp.CFrame.LookVector.X, hrp.CFrame.LookVector.Y, hrp.CFrame.LookVector.Z},
                UpVector = {hrp.CFrame.UpVector.X, hrp.CFrame.UpVector.Y, hrp.CFrame.UpVector.Z},
                Velocity = {0, 0, 0},
                MoveState = "Grounded",
                WalkSpeed = CurrentWalkSpeed,
                Timestamp = lastFrame.Timestamp + (1 / RECORDING_FPS),
                RealTime = lastFrame.RealTime or lastFrame.Timestamp
            },
            TRANSITION_FRAMES
        )
        
        for _, tFrame in ipairs(transitionFrames) do
            table.insert(StudioCurrentRecording.Frames, tFrame)
        end
    end
    
    StudioCurrentRecording.Frames = NormalizeRecordingTimestamps(StudioCurrentRecording.Frames)
    
    lastStudioRecordTime = #StudioCurrentRecording.Frames * (1 / RECORDING_FPS)
    lastStudioRecordRealTime = tick()
    lastStudioRecordPos = hrp.Position
    TimelinePosition = #StudioCurrentRecording.Frames
    CurrentTimelineFrame = #StudioCurrentRecording.Frames
    
    if hum then
        hum.WalkSpeed = CurrentWalkSpeed
        hum.AutoRotate = true
    end
    
    UpdateStudioUI()
    PlaySound("Success")
end

local function SaveStudioRecording()
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
    checkpointNames[StudioCurrentRecording.Name] = "Checkpoint " .. #RecordingOrder
    UpdateRecordList()
    
    PlaySound("Success")
    
    StudioCurrentRecording = {Frames = {}, StartTime = 0, RealStartTime = 0, Name = "recording_" .. os.date("%H%M%S")}
    CurrentTimelineFrame = 0
    TimelinePosition = 0
    UpdateStudioUI()
    
    task.wait(0.5)
    RecordingStudio.Visible = false
    MainFrame.Visible = true
end

StartBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(StartBtn)
    if StudioIsRecording then
        StopStudioRecording()
    else
        StartStudioRecording()
    end
end)

PrevBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(PrevBtn)
    GoBackTimeline()
end)

NextBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(NextBtn)
    GoNextTimeline()
end)

ResumeBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(ResumeBtn)
    ResumeStudioRecording()
end)

SaveBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(SaveBtn)
    SaveStudioRecording()
end)

CloseStudioBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(CloseStudioBtn)
    if StudioIsRecording then
        StopStudioRecording()
    end
    RecordingStudio.Visible = false
    MainFrame.Visible = true
end)

local function SaveToObfuscatedJSON()
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
            Version = "2.3",
            Obfuscated = true,
            RecordingFPS = RECORDING_FPS,
            PlaybackFPS = PLAYBACK_FPS,
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

local function LoadFromObfuscatedJSON()
    local filename = FilenameBox.Text
    if filename == "" then filename = "MyReplays" end
    filename = filename .. ".json"
    
    local success, err = pcall(function()
        if not isfile or not readfile then
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
        CheckedRecordings = {}
        
        if saveData.Obfuscated and saveData.ObfuscatedFrames then
            local deobfuscatedData = DeobfuscateRecordingData(saveData.ObfuscatedFrames)
            
            for _, checkpointData in ipairs(saveData.Checkpoints or {}) do
                local name = checkpointData.Name
                local frames = deobfuscatedData[name]
                
                if frames then
                    frames = NormalizeRecordingTimestamps(frames)
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
                    frames = NormalizeRecordingTimestamps(frames)
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

function PlayFromSpecificFrame(recording, startFrame, recordingName)
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
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    local currentPos = hrp.Position
    local targetFrame = recording[startFrame]
    local targetPos = GetFramePosition(targetFrame)
    
    local distance = (currentPos - targetPos).Magnitude
    
    if distance > 3 then
        local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(hrp, tweenInfo, {CFrame = GetFrameCFrame(targetFrame)}):Play()
        task.wait(0.15)
    end
    
    currentPlaybackFrame = startFrame
    virtualPlaybackTime = GetFrameTimestamp(recording[startFrame])
    lastPlaybackState = nil
    lastStateChangeTime = 0
    lastStateChangeRealTime = 0

    SaveHumanoidState()
    PlaySound("Play")
    
    PlayBtnControl.Text = "STOP"

    playbackConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not IsPlaying then
            if playbackConnection then
                playbackConnection:Disconnect()
                playbackConnection = nil
            end
            RestoreFullUserControl()
            lastPlaybackState = nil
            lastStateChangeTime = 0
            lastStateChangeRealTime = 0
            PlayBtnControl.Text = "PLAY"
            UpdatePlayButtonStatus()
            return
        end
        
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            IsPlaying = false
            if playbackConnection then
                playbackConnection:Disconnect()
                playbackConnection = nil
            end
            RestoreFullUserControl()
            lastPlaybackState = nil
            lastStateChangeTime = 0
            lastStateChangeRealTime = 0
            PlayBtnControl.Text = "PLAY"
            UpdatePlayButtonStatus()
            return
        end
        
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then
            IsPlaying = false
            if playbackConnection then
                playbackConnection:Disconnect()
                playbackConnection = nil
            end
            RestoreFullUserControl()
            lastPlaybackState = nil
            lastStateChangeTime = 0
            lastStateChangeRealTime = 0
            PlayBtnControl.Text = "PLAY"
            UpdatePlayButtonStatus()
            return
        end

        local scaledDelta = deltaTime * CurrentSpeed
        virtualPlaybackTime = virtualPlaybackTime + scaledDelta
        
        while currentPlaybackFrame < #recording do
            local nextFrame = currentPlaybackFrame + 1
            if GetFrameTimestamp(recording[nextFrame]) <= virtualPlaybackTime then
                currentPlaybackFrame = nextFrame
            else
                break
            end
        end

        if currentPlaybackFrame >= #recording then
            IsPlaying = false
            if playbackConnection then
                playbackConnection:Disconnect()
                playbackConnection = nil
            end
            RestoreFullUserControl()
            PlaySound("Success")
            lastPlaybackState = nil
            lastStateChangeTime = 0
            lastStateChangeRealTime = 0
            PlayBtnControl.Text = "PLAY"
            UpdatePlayButtonStatus()
            return
        end

        local frame = recording[currentPlaybackFrame]
        if not frame then
            IsPlaying = false
            if playbackConnection then
                playbackConnection:Disconnect()
                playbackConnection = nil
            end
            RestoreFullUserControl()
            lastPlaybackState = nil
            lastStateChangeTime = 0
            lastStateChangeRealTime = 0
            PlayBtnControl.Text = "PLAY"
            UpdatePlayButtonStatus()
            return
        end

        hrp.CFrame = GetFrameCFrame(frame)
        hrp.AssemblyLinearVelocity = GetFrameVelocity(frame)
        
        if hum then
            hum.WalkSpeed = GetFrameWalkSpeed(frame)
            hum.AutoRotate = false
            
            lastPlaybackState, lastStateChangeTime = ProcessHumanoidState(
                hum, frame, lastPlaybackState, lastStateChangeTime
            )
        end
        
        if ShiftLockEnabled then
            ApplyVisibleShiftLock()
        end
    end)
    
    AddConnection(playbackConnection)
    UpdatePlayButtonStatus()
end

function SmartPlayRecording(maxDistance)
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
    local bestRecordingIndex = nil
    
    for index, recordingName in ipairs(RecordingOrder) do
        local recording = RecordedMovements[recordingName]
        if recording and #recording > 0 then
            local nearestFrame, frameDistance = FindNearestFrame(recording, currentPos)
            
            if frameDistance < bestDistance and frameDistance <= (maxDistance or 50) then
                bestDistance = frameDistance
                bestRecording = recording
                bestFrame = nearestFrame
                bestRecordingName = recordingName
                bestRecordingIndex = index
            end
        end
    end
    
    if bestRecording then
        CurrentLoopIndex = bestRecordingIndex or 1
        PlayFromSpecificFrame(bestRecording, bestFrame, bestRecordingName)
    else
        if #RecordingOrder > 0 then
            local firstRecording = RecordedMovements[RecordingOrder[1]]
            if firstRecording then
                CurrentLoopIndex = 1
                PlayFromSpecificFrame(firstRecording, 1, RecordingOrder[1])
            else
                PlaySound("Error")
            end
        else
            PlaySound("Error")
        end
    end
end

function PlayRecording(name)
    if name then
        local recording = RecordedMovements[name]
        if recording then
            local recordingIndex = table.find(RecordingOrder, name)
            if recordingIndex then
                CurrentLoopIndex = recordingIndex
            end
            PlayFromSpecificFrame(recording, 1, name)
        end
    else
        SmartPlayRecording(50)
    end
end

function StartAutoLoopAll()
    if not AutoLoop then return end
    
    if #RecordingOrder == 0 then
        AutoLoop = false
        AnimateLoopControl(false)
        LoopBtnControl.Text = "Loop OFF"
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
    
    PlaySound("Play")
    
    IsAutoLoopPlaying = true
    LoopRetryAttempts = 0
    lastPlaybackState = nil
    lastStateChangeTime = 0
    lastStateChangeRealTime = 0
    
    PlayBtnControl.Text = "STOP"
    
    loopConnection = task.spawn(function()
        while AutoLoop and IsAutoLoopPlaying do
            if not AutoLoop or not IsAutoLoopPlaying then break end
            
            if CurrentLoopIndex > #RecordingOrder then
                CurrentLoopIndex = 1
            end
            
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
                    if not success then
                        task.wait(AUTO_LOOP_RETRY_DELAY)
                        continue
                    end
                    task.wait(0.5)
                else
                    local waitTime = 0
                    local maxWaitTime = 30
                    
                    while not IsCharacterReady() and AutoLoop and IsAutoLoopPlaying do
                        waitTime = waitTime + 0.5
                        if waitTime >= maxWaitTime then
                            AutoLoop = false
                            IsAutoLoopPlaying = false
                            AnimateLoopControl(false)
                            LoopBtnControl.Text = "Loop OFF"
                            PlaySound("Error")
                            break
                        end
                        task.wait(0.5)
                    end
                    
                    if not AutoLoop or not IsAutoLoopPlaying then break end
                    task.wait(0.5)
                end
            end
            
            if not AutoLoop or not IsAutoLoopPlaying then break end
            
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                hrp.CFrame = GetFrameCFrame(recordingToPlay[1])
                hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                task.wait(0.15)
            end
            
            local playbackCompleted = false
            local currentFrame = 1
            local virtualTime = GetFrameTimestamp(recordingToPlay[1])
            
            lastPlaybackState = nil
            lastStateChangeTime = 0
            lastStateChangeRealTime = 0
            
            SaveHumanoidState()
            
            IsLoopTransitioning = false
            local deathRetryCount = 0
            local maxDeathRetries = 999
            
            while AutoLoop and IsAutoLoopPlaying and currentFrame <= #recordingToPlay and deathRetryCount < maxDeathRetries do
                
                if not IsCharacterReady() then
                    deathRetryCount = deathRetryCount + 1
                    
                    if AutoRespawn then
                        ResetCharacter()
                        local success = WaitForRespawn()
                        
                        if success then
                            RestoreFullUserControl()
                            task.wait(0.5)
                            
                            currentFrame = 1
                            virtualTime = GetFrameTimestamp(recordingToPlay[1])
                            lastPlaybackState = nil
                            lastStateChangeTime = 0
                            lastStateChangeRealTime = 0
                            
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
                                AutoLoop = false
                                IsAutoLoopPlaying = false
                                AnimateLoopControl(false)
                                LoopBtnControl.Text = "Loop OFF"
                                PlaySound("Error")
                                break
                            end
                            task.wait(0.5)
                        end
                        
                        if not AutoLoop or not IsAutoLoopPlaying then break end
                        
                        RestoreFullUserControl()
                        task.wait(0.5)
                        
                        currentFrame = 1
                        virtualTime = GetFrameTimestamp(recordingToPlay[1])
                        lastPlaybackState = nil
                        lastStateChangeTime = 0
                        lastStateChangeRealTime = 0
                        
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
                local scaledDelta = deltaTime * CurrentSpeed
                virtualTime = virtualTime + scaledDelta
                
                while currentFrame < #recordingToPlay do
                    local nextFrame = currentFrame + 1
                    if GetFrameTimestamp(recordingToPlay[nextFrame]) <= virtualTime then
                        currentFrame = nextFrame
                    else
                        break
                    end
                end
                
                if currentFrame >= #recordingToPlay then
                    playbackCompleted = true
                    break
                end
                
                local frame = recordingToPlay[currentFrame]
                if frame then
                    hrp.CFrame = GetFrameCFrame(frame)
                    hrp.AssemblyLinearVelocity = GetFrameVelocity(frame)
                    
                    if hum then
                        hum.WalkSpeed = GetFrameWalkSpeed(frame)
                        hum.AutoRotate = false
                        
                        lastPlaybackState, lastStateChangeTime = ProcessHumanoidState(
                            hum, frame, lastPlaybackState, lastStateChangeTime
                        )
                    end

                    if ShiftLockEnabled then
                        ApplyVisibleShiftLock()
                    end
                end
            end
            
            RestoreFullUserControl()
            lastPlaybackState = nil
            lastStateChangeTime = 0
            lastStateChangeRealTime = 0
            
            if playbackCompleted then
                PlaySound("Success")
                
                if AutoReset then
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
        end
        
        IsAutoLoopPlaying = false
        IsLoopTransitioning = false
        RestoreFullUserControl()
        lastPlaybackState = nil
        lastStateChangeTime = 0
        lastStateChangeRealTime = 0
        PlayBtnControl.Text = "PLAY"
        UpdatePlayButtonStatus()
    end)
end

function StopAutoLoopAll()
    AutoLoop = false
    IsAutoLoopPlaying = false
    IsPlaying = false
    IsLoopTransitioning = false
    lastPlaybackState = nil
    lastStateChangeTime = 0
    lastStateChangeRealTime = 0
    
    if loopConnection then
        if typeof(loopConnection) == "thread" then
            task.cancel(loopConnection)
        elseif typeof(loopConnection) == "RBXScriptConnection" then
            loopConnection:Disconnect()
        end
        loopConnection = nil
    end
    
    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end
    
    RestoreFullUserControl()
    
    local char = player.Character
    if char then CompleteCharacterReset(char) end
    
    PlaySound("Stop")
    PlayBtnControl.Text = "PLAY"
    UpdatePlayButtonStatus()
end

function StopPlayback()
    if AutoLoop then
        StopAutoLoopAll()
        AnimateLoopControl(false)
        LoopBtnControl.Text = "Loop OFF"
    end
    
    if not IsPlaying and not IsAutoLoopPlaying then return end
    
    IsPlaying = false
    IsAutoLoopPlaying = false
    IsLoopTransitioning = false
    lastPlaybackState = nil
    lastStateChangeTime = 0
    lastStateChangeRealTime = 0
    LastPausePosition = nil
    LastPauseRecording = nil
    
    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end
    
    if loopConnection then
        if typeof(loopConnection) == "thread" then
            task.cancel(loopConnection)
        elseif typeof(loopConnection) == "RBXScriptConnection" then
            loopConnection:Disconnect()
        end
        loopConnection = nil
    end
    
    RestoreFullUserControl()
    
    local char = player.Character
    if char then CompleteCharacterReset(char) end
    
    PlaySound("Stop")
    PlayBtnControl.Text = "PLAY"
    UpdatePlayButtonStatus()
end

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
    AnimateLoopControl(AutoLoop)
    LoopBtnControl.Text = AutoLoop and "Loop ON" or "Loop OFF"
    
    if AutoLoop then
        if not next(RecordedMovements) then
            AutoLoop = false
            AnimateLoopControl(false)
            LoopBtnControl.Text = "Loop OFF"
            PlaySound("Error")
            return
        end
        
        if IsPlaying then
            IsPlaying = false
            if playbackConnection then
                playbackConnection:Disconnect()
                playbackConnection = nil
            end
            RestoreFullUserControl()
        end
        
        StartAutoLoopAll()
    else
        StopAutoLoopAll()
    end
end)

ShiftBtnControl.MouseButton1Click:Connect(function()
    AnimateButtonClick(ShiftBtnControl)
    ToggleVisibleShiftLock()
    AnimateShiftControl(ShiftLockEnabled)
    ShiftBtnControl.Text = ShiftLockEnabled and "Shift ON" or "Shift OFF"
end)

RespawnBtnControl.MouseButton1Click:Connect(function()
    AnimateButtonClick(RespawnBtnControl)
    AutoRespawn = not AutoRespawn
    AnimateRespawnControl(AutoRespawn)
    RespawnBtnControl.Text = AutoRespawn and "Respawn ON" or "Respawn OFF"
    PlaySound("Toggle")
end)

ResetBtnControl.MouseButton1Click:Connect(function()
    AnimateButtonClick(ResetBtnControl)
    AutoReset = not AutoReset
    AnimateResetControl(AutoReset)
    ResetBtnControl.Text = AutoReset and "Reset ON" or "Reset OFF"
    PlaySound("Toggle")
end)

JumpBtnControl.MouseButton1Click:Connect(function()
    AnimateButtonClick(JumpBtnControl)
    ToggleInfiniteJump()
    AnimateJumpControl(InfiniteJump)
    JumpBtnControl.Text = InfiniteJump and "Jump ON" or "Jump OFF"
    PlaySound("Toggle")
end)

ClosePlaybackBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(ClosePlaybackBtn)
    PlaybackControl.Visible = false
end)

OpenStudioBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(OpenStudioBtn)
    MainFrame.Visible = false
    RecordingStudio.Visible = true
    UpdateStudioUI()
end)

PlaybackBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(PlaybackBtn)
    PlaybackControl.Visible = not PlaybackControl.Visible
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

PathToggleBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(PathToggleBtn)
    ShowPaths = not ShowPaths
    if ShowPaths then
        PathToggleBtn.Text = "PATH ON"
        VisualizeAllPaths()
    else
        PathToggleBtn.Text = "PATH"
        ClearPathVisualization()
    end
end)

MergeBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(MergeBtn)
    CreateMergedReplay()
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
    if StudioIsRecording then StopStudioRecording() end
    if IsPlaying or AutoLoop or IsAutoLoopPlaying then StopPlayback() end
    if ShiftLockEnabled then DisableVisibleShiftLock() end
    if InfiniteJump then DisableInfiniteJump() end
    CleanupConnections()
    ClearPathVisualization()
    ScreenGui:Destroy()
end)

player.CharacterAdded:Connect(function(character)
    task.wait(0.5)
    
    local humanoid = character:WaitForChild("Humanoid", 5)
    if humanoid then
        humanoid.WalkSpeed = CurrentWalkSpeed
        humanoid.JumpPower = prePauseJumpPower or 50
    end
end)

player.CharacterRemoving:Connect(function()
    if StudioIsRecording then
        StopStudioRecording()
    end
end)

UpdateRecordList()
UpdatePlayButtonStatus()

task.spawn(function()
    while task.wait(2) do
        if not IsPlaying and not IsAutoLoopPlaying then
            UpdatePlayButtonStatus()
        end
    end
end)

task.spawn(function()
    task.wait(2)
    local filename = "MyReplays.json"
    if isfile and readfile and isfile(filename) then
        FilenameBox.Text = "MyReplays"
        LoadFromObfuscatedJSON()
    end
end)

game:GetService("ScriptContext").DescendantRemoving:Connect(function(descendant)
    if descendant == ScreenGui then
        CleanupConnections()
        ClearPathVisualization()
    end
end)