
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
wait(1)

-- ========= CONFIGURATION =========
local RECORDING_FPS = 120
local MAX_FRAMES = 30000
local MIN_DISTANCE_THRESHOLD = 0.01
local VELOCITY_SCALE = 1
local VELOCITY_Y_SCALE = 1
local REVERSE_SPEED_MULTIPLIER = 1.0
local FORWARD_SPEED_MULTIPLIER = 1.0
local REVERSE_FRAME_STEP = 1
local FORWARD_FRAME_STEP = 1
local TIMELINE_STEP_SECONDS = 0.1
local STATE_CHANGE_COOLDOWN = 0.01
local TRANSITION_FRAMES = 5
local RESUME_DISTANCE_THRESHOLD = 15
local PLAYBACK_FIXED_TIMESTEP = 1 / 60

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
local CurrentSpeed = 1
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
        if connection then
            connection:Disconnect()
        end
    end
    activeConnections = {}
    
    if recordConnection then recordConnection:Disconnect() recordConnection = nil end
    if playbackConnection then playbackConnection:Disconnect() playbackConnection = nil end
    if loopConnection then loopConnection:Disconnect() loopConnection = nil end
    if shiftLockConnection then shiftLockConnection:Disconnect() shiftLockConnection = nil end
    if jumpConnection then jumpConnection:Disconnect() jumpConnection = nil end
    if reverseConnection then reverseConnection:Disconnect() reverseConnection = nil end
    if forwardConnection then forwardConnection:Disconnect() forwardConnection = nil end
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

-- ========= FIXED: ApplyMoveState Function =========
local function ApplyMoveState(humanoid, moveState)
    if not humanoid then return end
    
    local stateTime = tick()
    
    -- Jump dan Fall tanpa cooldown
    if moveState == "Jumping" then
        if lastPlaybackState ~= "Jumping" then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            lastPlaybackState = "Jumping"
            lastStateChangeTime = stateTime
        end
        return
    end
    
    if moveState == "Falling" then
        if lastPlaybackState ~= "Falling" then
            humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
            lastPlaybackState = "Falling"
            lastStateChangeTime = stateTime
        end
        return
    end
    
    -- State lain dengan cooldown
    if moveState ~= lastPlaybackState and (stateTime - lastStateChangeTime) >= STATE_CHANGE_COOLDOWN then
        lastPlaybackState = moveState
        lastStateChangeTime = stateTime
        
        if moveState == "Climbing" then
            humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
            humanoid.PlatformStand = false
            humanoid.AutoRotate = false
        elseif moveState == "Swimming" then
            humanoid:ChangeState(Enum.HumanoidStateType.Swimming)
        else
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end
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
                    Timestamp = previousFrame.Timestamp + (expectedInterval * (j))
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
    local optimizedFrames = {}
    local lastSignificantFrame = nil
    for i, frame in ipairs(mergedFrames) do
        local shouldInclude = true
        if lastSignificantFrame then
            local pos1 = Vector3.new(lastSignificantFrame.Position[1], lastSignificantFrame.Position[2], lastSignificantFrame.Position[3])
            local pos2 = Vector3.new(frame.Position[1], frame.Position[2], frame.Position[3])
            local distance = (pos1 - pos2).Magnitude
            if distance < 0.1 and frame.MoveState == lastSignificantFrame.MoveState then
                shouldInclude = false
            end
        end
        if shouldInclude then
            table.insert(optimizedFrames, frame)
            lastSignificantFrame = frame
        end
    end
    local mergedName = "merged_" .. os.date("%H%M%S")
    RecordedMovements[mergedName] = optimizedFrames
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

-- ========= GUI SETUP =========
local CoreGui = game:GetService("CoreGui")
local parent = (pcall(function() return gethui and gethui() end) and gethui()) or CoreGui

local function protect(g)
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(g) end
        if protect_gui then protect_gui(g) end
    end)
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoWalkByaruL"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
protect(ScreenGui)
ScreenGui.Parent = parent

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
    local cr = Instance.new("UICorner", b); cr.CornerRadius = UDim.new(0,10)
    local st = Instance.new("UIStroke", b); st.Thickness = 1; st.Color = Color3.fromRGB(70,70,78)
    return b
end

-- ========= MINI FLOATING RECORDER GUI (160x100) =========
local RecorderPanel = Instance.new("Frame")
RecorderPanel.Name = "RecorderPanel"
RecorderPanel.Size = UDim2.fromOffset(160,100)
RecorderPanel.Position = UDim2.fromOffset(80, 220)
RecorderPanel.BackgroundColor3 = Color3.fromRGB(18,18,22)
RecorderPanel.BackgroundTransparency = 0.15
RecorderPanel.Active = true
RecorderPanel.Parent = ScreenGui

local pc = Instance.new("UICorner", RecorderPanel)
pc.CornerRadius = UDim.new(0,14)
local ps = Instance.new("UIStroke", RecorderPanel)
ps.Thickness = 1
ps.Color = Color3.fromRGB(60,60,68)

local recWrap = Instance.new("Frame", RecorderPanel)
recWrap.BackgroundTransparency = 1
recWrap.Size = UDim2.fromScale(1,1)
local recPad = Instance.new("UIPadding", recWrap)
recPad.PaddingTop = UDim.new(0,6)
recPad.PaddingBottom = UDim.new(0,6)
recPad.PaddingLeft = UDim.new(0,8)
recPad.PaddingRight = UDim.new(0,8)

local recVlist = Instance.new("UIListLayout", recWrap)
recVlist.FillDirection = Enum.FillDirection.Vertical
recVlist.Padding = UDim.new(0,8)
recVlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
recVlist.VerticalAlignment = Enum.VerticalAlignment.Center

local function recRow()
    local r = Instance.new("Frame")
    r.BackgroundTransparency = 1
    r.Size = UDim2.new(1,0,0,40)
    r.Parent = recWrap
    local h = Instance.new("UIListLayout", r)
    h.FillDirection = Enum.FillDirection.Horizontal
    h.Padding = UDim.new(0,8)
    h.HorizontalAlignment = Enum.HorizontalAlignment.Center
    h.VerticalAlignment = Enum.VerticalAlignment.Center
    return r
end

local recRowTop = recRow()
local recRowBottom = recRow()

local btnSaveRec = makeButton("Save")
btnSaveRec.Parent = recRowTop
local btnRecToggle = makeButton("Rec")
btnRecToggle.Parent = recRowTop

local btnPrevRec = makeButton("Prev")
btnPrevRec.Parent = recRowBottom
local btnPauseRec = makeButton("Pause")
btnPauseRec.Parent = recRowBottom
local btnNextRec = makeButton("Next")
btnNextRec.Parent = recRowBottom

setIcon(btnSaveRec, "💾", "S")
setIcon(btnRecToggle, "🎦", "R")
setIcon(btnPrevRec, "⏪", "<<")
setIcon(btnPauseRec, "⏸", "||")
setIcon(btnNextRec, "⏩", ">>")

-- Dragging Recorder
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

RecorderPanel.Position = clampToViewport(RecorderPanel.Position, RecorderPanel.AbsoluteSize)

-- ========= MINI FLOATING PLAYBACK GUI (160x60) =========
local PlaybackPanel = Instance.new("Frame")
PlaybackPanel.Name = "PlaybackPanel"
PlaybackPanel.Size = UDim2.fromOffset(160, 60)
PlaybackPanel.Position = UDim2.fromOffset(100, 340)
PlaybackPanel.BackgroundColor3 = Color3.fromRGB(18,18,22)
PlaybackPanel.BackgroundTransparency = 0.15
PlaybackPanel.Active = true
PlaybackPanel.Parent = ScreenGui

local ppc = Instance.new("UICorner", PlaybackPanel)
ppc.CornerRadius = UDim.new(0,14)
local pps = Instance.new("UIStroke", PlaybackPanel)
pps.Thickness = 1
pps.Color = Color3.fromRGB(60,60,68)

local playWrap = Instance.new("Frame", PlaybackPanel)
playWrap.BackgroundTransparency = 1
playWrap.Size = UDim2.fromScale(1,1)
local playPad = Instance.new("UIPadding", playWrap)
playPad.PaddingTop = UDim.new(0,10)
playPad.PaddingBottom = UDim.new(0,10)
playPad.PaddingLeft = UDim.new(0,10)
playPad.PaddingRight = UDim.new(0,10)

local playRow = Instance.new("Frame", playWrap)
playRow.BackgroundTransparency = 1
playRow.Size = UDim2.new(1,0,1,0)
local pH = Instance.new("UIListLayout", playRow)
pH.FillDirection = Enum.FillDirection.Horizontal
pH.Padding = UDim.new(0,12)
pH.HorizontalAlignment = Enum.HorizontalAlignment.Center
pH.VerticalAlignment = Enum.VerticalAlignment.Center

local btnPlayToggle = makeButton("Play")
btnPlayToggle.Parent = playRow
local btnPauseToggle = makeButton("Pause")
btnPauseToggle.Parent = playRow

setIcon(btnPlayToggle, "▶️", ">")
setIcon(btnPauseToggle, "⏹", "■")

-- Dragging Playback
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

PlaybackPanel.Position = clampToViewport(PlaybackPanel.Position, PlaybackPanel.AbsoluteSize)

-- ========= MAIN GUI (250x420) =========
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.fromOffset(250, 420)
MainFrame.Position = UDim2.new(0.5, -125, 0.5, -210)
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

local HeaderCorner2 = Instance.new("UICorner")
HeaderCorner2.CornerRadius = UDim.new(0, 12)
HeaderCorner2.Parent = Header

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
HideButton.BackgroundColor3 = Color3.fromRGB(162, 175, 170)
HideButton.Text = "_"
HideButton.TextColor3 = Color3.new(1, 1, 1)
HideButton.Font = Enum.Font.GothamBold
HideButton.TextSize = 12
HideButton.Parent = Header

local HideCorner2 = Instance.new("UICorner")
HideCorner2.CornerRadius = UDim.new(0, 6)
HideCorner2.Parent = HideButton

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.fromOffset(22, 22)
CloseButton.Position = UDim2.new(1, -25, 0.5, -11)
CloseButton.BackgroundColor3 = Color3.fromRGB(230, 62, 62)
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.new(1, 1, 1)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 10
CloseButton.Parent = Header

local CloseCorner2 = Instance.new("UICorner")
CloseCorner2.CornerRadius = UDim.new(0, 6)
CloseCorner2.Parent = CloseButton

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
    label.TextSize = 9
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
    
    local function Animate(isOn)
        PlaySound("Toggle")
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local bgColor = isOn and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(50, 50, 50)
        local knobPos = isOn and UDim2.new(0, 11, 0, 2) or UDim2.new(0, 2, 0, 2)
        TweenService:Create(toggle, tweenInfo, {BackgroundColor3 = bgColor}):Play()
        TweenService:Create(knob, tweenInfo, {Position = knobPos}):Play()
    end
    
    return btn, Animate
end

-- ========= TOGGLE ROW (5 toggles in 1 row) =========
local ToggleLoopBtn, AnimateLoop = CreateToggle("Loop", 0, 2, 44, 18, false)
local ToggleRespawnBtn, AnimateRespawn = CreateToggle("Respawn", 46, 2, 44, 18, false)
local ToggleResetBtn, AnimateReset = CreateToggle("Reset", 92, 2, 44, 18, false)
local ToggleJumpBtn, AnimateJump = CreateToggle("InfJump", 138, 2, 44, 18, false)
local ToggleShiftBtn, AnimateShift = CreateToggle("Shift", 184, 2, 48, 18, false)

-- ========= MAIN GUI BUTTONS =========
local MenuBtn = CreateButton("MENU", 0, 24, 115, 30, Color3.fromRGB(19, 137, 79))
local PathToggleBtn = CreateButton("SHOW RUTE", 119, 24, 115, 30, Color3.fromRGB(19, 137, 79))

local SpeedBox = Instance.new("TextBox")
SpeedBox.Size = UDim2.fromOffset(60, 22)
SpeedBox.Position = UDim2.fromOffset(0, 58)
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
FilenameBox.Position = UDim2.fromOffset(62, 58)
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
WalkSpeedBox.Position = UDim2.fromOffset(174, 58)
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

local SaveFileBtn = CreateButton("SAVE FILE", 0, 84, 115, 30, Color3.fromRGB(19, 137, 79))
local LoadFileBtn = CreateButton("LOAD FILE", 119, 84, 115, 30, Color3.fromRGB(19, 137, 79))

local MergeBtn = CreateButton("MERGE", 0, 118, 234, 30, Color3.fromRGB(19, 137, 79))

-- Recording List (Scrollable) 
local RecordList = Instance.new("ScrollingFrame")
RecordList.Size = UDim2.new(1, 0, 0, 230)
RecordList.Position = UDim2.fromOffset(0, 152)
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
        nameBox.Size = UDim2.new(0, 90, 0, 16)
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
        
        nameBox.FocusLost:Connect(function()
            local newName = nameBox.Text
            if newName and newName ~= "" then
                checkpointNames[name] = newName
                PlaySound("Success")
            end
        end)
        
        local upBtn = Instance.new("TextButton")
        upBtn.Size = UDim2.fromOffset(26, 16)
        upBtn.Position = UDim2.new(1, -55, 0, 21)
        upBtn.BackgroundColor3 = index > 1 and Color3.fromRGB(74, 195, 147) or Color3.fromRGB(40, 40, 40)
        upBtn.Text = "↑"
        upBtn.TextColor3 = Color3.new(1, 1, 1)
        upBtn.Font = Enum.Font.GothamBold
        upBtn.TextSize = 14
        upBtn.Parent = item
        
        local upCorner = Instance.new("UICorner")
        upCorner.CornerRadius = UDim.new(0, 3)
        upCorner.Parent = upBtn
        
        local downBtn = Instance.new("TextButton")
        downBtn.Size = UDim2.fromOffset(26, 16)
        downBtn.Position = UDim2.new(1, -27, 0, 21)
        downBtn.BackgroundColor3 = index < #RecordingOrder and Color3.fromRGB(74, 195, 147) or Color3.fromRGB(40, 40, 40)
        downBtn.Text = "↓"
        downBtn.TextColor3 = Color3.new(1, 1, 1)
        downBtn.Font = Enum.Font.GothamBold
        downBtn.TextSize = 14
        downBtn.Parent = item
        
        local downCorner = Instance.new("UICorner")
        downCorner.CornerRadius = UDim.new(0, 3)
        downCorner.Parent = downBtn
        
        checkBox.MouseButton1Click:Connect(function()
            CheckedRecordings[name] = not CheckedRecordings[name]
            checkBox.Text = CheckedRecordings[name] and "✓" or ""
            SimpleButtonClick(checkBox)
        end)
        
        upBtn.MouseButton1Click:Connect(function()
            if index > 1 then 
                SimpleButtonClick(upBtn)
                MoveRecordingUp(name) 
            end
        end)
        
        downBtn.MouseButton1Click:Connect(function()
            if index < #RecordingOrder then 
                SimpleButtonClick(downBtn)
                MoveRecordingDown(name) 
            end
        end)
        
        playBtn.MouseButton1Click:Connect(function()
            if not IsPlaying then 
                SimpleButtonClick(playBtn)
                PlayRecording(name) 
            end
        end)
        
        delBtn.MouseButton1Click:Connect(function()
            SimpleButtonClick(delBtn)
            RecordedMovements[name] = nil
            checkpointNames[name] = nil
            CheckedRecordings[name] = nil
            local idx = table.find(RecordingOrder, name)
            if idx then table.remove(RecordingOrder, idx) end
            UpdateRecordList()
        end)
        
        yPos = yPos + 43
    end
    
    RecordList.CanvasSize = UDim2.new(0, 0, 0, math.max(yPos, RecordList.AbsoluteSize.Y))
end

local function ApplyFrameToCharacter(frame)
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    
    if not hrp or not hum then return end
    
    hrp.CFrame = GetFrameCFrame(frame)
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
    
    task.spawn(function()
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
        
        setIcon(btnRecToggle, "⏹", "■")
        
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
                if (now - lastStudioRecordTime) < (1 / RECORDING_FPS) then return end
                
                local currentPos = hrp.Position
                local currentVelocity = hrp.AssemblyLinearVelocity
                
                if lastStudioRecordPos and (currentPos - lastStudioRecordPos).Magnitude < MIN_DISTANCE_THRESHOLD then
                    lastStudioRecordTime = now
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
                
                lastStudioRecordTime = now
                lastStudioRecordPos = currentPos
                CurrentTimelineFrame = #StudioCurrentRecording.Frames
                TimelinePosition = CurrentTimelineFrame
            end)
        end)
    end)
end

local function StopStudioRecording()
    StudioIsRecording = false
    IsTimelineMode = false
    
    task.spawn(function()
        if recordConnection then
            recordConnection:Disconnect()
            recordConnection = nil
        end
        
        setIcon(btnRecToggle, "🎦", "R")
        
        PlaySound("RecordStop")
    end)
end

local function GoBackTimeline()
    if not StudioIsRecording or #StudioCurrentRecording.Frames == 0 then
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
    if not StudioIsRecording or #StudioCurrentRecording.Frames == 0 then
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

local function ResumeStudioRecording()
    if not StudioIsRecording then
        PlaySound("Error")
        return
    end
    
    task.spawn(function()
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
        
        if #StudioCurrentRecording.Frames > 0 then
            local lastFrame = StudioCurrentRecording.Frames[#StudioCurrentRecording.Frames]
            local lastTimestamp = lastFrame.Timestamp
            
            StudioCurrentRecording.StartTime = tick() - lastTimestamp
            
            local currentCFrame = hrp.CFrame
            local lastCFrame = GetFrameCFrame(lastFrame)
            
            if (currentCFrame.Position - lastCFrame.Position).Magnitude > 2 then
                local transitionFrame = {
                    Position = {
                        (lastCFrame.Position.X + currentCFrame.Position.X) / 2,
                        (lastCFrame.Position.Y + currentCFrame.Position.Y) / 2, 
                        (lastCFrame.Position.Z + currentCFrame.Position.Z) / 2
                    },
                    LookVector = {
                        (lastCFrame.LookVector.X + currentCFrame.LookVector.X) / 2,
                        (lastCFrame.LookVector.Y + currentCFrame.LookVector.Y) / 2,
                        (lastCFrame.LookVector.Z + currentCFrame.LookVector.Z) / 2
                    },
                    UpVector = {0, 1, 0},
                    Velocity = {0, 0, 0},
                    MoveState = "Grounded",
                    WalkSpeed = CurrentWalkSpeed,
                    Timestamp = lastTimestamp + (1 / RECORDING_FPS)
                }
                table.insert(StudioCurrentRecording.Frames, transitionFrame)
            end
        end
        
        IsTimelineMode = false
        lastStudioRecordTime = tick()
        lastStudioRecordPos = hrp.Position
        
        if hum then
            hum.WalkSpeed = CurrentWalkSpeed
            hum.AutoRotate = true
        end
        
        PlaySound("Success")
    end)
end

local function SaveStudioRecording()
    task.spawn(function()
        if #StudioCurrentRecording.Frames == 0 then
            PlaySound("Error")
            return
        end
        
        if StudioIsRecording then
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

-- ========= RECORDER BUTTON CONNECTIONS =========
btnRecToggle.MouseButton1Click:Connect(function()
    SimpleButtonClick(btnRecToggle)
    if StudioIsRecording then
        StopStudioRecording()
    else
        StartStudioRecording()
    end
end)

btnPrevRec.MouseButton1Click:Connect(function()
    SimpleButtonClick(btnPrevRec)
    GoBackTimeline()
end)

btnPauseRec.MouseButton1Click:Connect(function()
    SimpleButtonClick(btnPauseRec)
    ResumeStudioRecording()
end)

btnNextRec.MouseButton1Click:Connect(function()
    SimpleButtonClick(btnNextRec)
    GoNextTimeline()
end)

btnSaveRec.MouseButton1Click:Connect(function()
    SimpleButtonClick(btnSaveRec)
    SaveStudioRecording()
end)

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
    
    setIcon(btnPlayToggle, "⏹", "■")

    playbackConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not IsPlaying then
            playbackConnection:Disconnect()
            RestoreFullUserControl()
            UpdatePauseMarker()
            lastPlaybackState = nil
            lastStateChangeTime = 0
            setIcon(btnPlayToggle, "▶️", ">")
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
            setIcon(btnPlayToggle, "▶️", ">")
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
            setIcon(btnPlayToggle, "▶️", ">")
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
                setIcon(btnPlayToggle, "▶️", ">")
                return
            end

            local frame = recording[currentPlaybackFrame]
            if not frame then
                IsPlaying = false
                RestoreFullUserControl()
                UpdatePauseMarker()
                lastPlaybackState = nil
                lastStateChangeTime = 0
                setIcon(btnPlayToggle, "▶️", ">")
                return
            end

            hrp.CFrame = GetFrameCFrame(frame)
            hrp.AssemblyLinearVelocity = GetFrameVelocity(frame)
            
            if hum then
                hum.WalkSpeed = GetFrameWalkSpeed(frame) * CurrentSpeed
                hum.AutoRotate = false
                
                ApplyMoveState(hum, frame.MoveState)
                
                if ShiftLockEnabled then
                    ApplyVisibleShiftLock()
                end
            end
        end
    end)
    
    AddConnection(playbackConnection)
end

function StartAutoLoopAll()
    if not AutoLoop then return end
    
    if #RecordingOrder == 0 then
        AutoLoop = false
        AnimateLoop(false)
        PlaySound("Error")
        return
    end
    
    PlaySound("Play")
    
    CurrentLoopIndex = 1
    IsAutoLoopPlaying = true
    lastPlaybackState = nil
    lastStateChangeTime = 0
    
    setIcon(btnPlayToggle, "⏹", "■")
    
    loopConnection = task.spawn(function()
        while AutoLoop and IsAutoLoopPlaying do
            if not AutoLoop or not IsAutoLoopPlaying then
                break
            end
            
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
                    
                    while not IsCharacterReady() and AutoLoop and IsAutoLoopPlaying do
                        waitAttempts = waitAttempts + 1
                        
                        if waitAttempts >= maxWaitAttempts then
                            AutoLoop = false
                            IsAutoLoopPlaying = false
                            AnimateLoop(false)
                            PlaySound("Error")
                            break
                        end
                        
                        task.wait(0.5)
                    end
                    
                    if not AutoLoop or not IsAutoLoopPlaying then break end
                    task.wait(1.0)
                end
            end
            
            if not AutoLoop or not IsAutoLoopPlaying then break end
            
            local playbackCompleted = false
            local playbackStart = tick()
            local playbackPausedTime = 0
            local playbackPauseStart = 0
            local currentFrame = 1
            local deathRetryCount = 0
            local maxDeathRetries = 999999
            local loopAccumulator = 0
            
            lastPlaybackState = nil
            lastStateChangeTime = 0
            
            SaveHumanoidState()
            
            while AutoLoop and IsAutoLoopPlaying and currentFrame <= #recording and deathRetryCount < maxDeathRetries do
                
                if not IsCharacterReady() then
                    deathRetryCount = deathRetryCount + 1
                    
                    if AutoRespawn then
                        ResetCharacter()
                        local success = WaitForRespawn()
                        
                        if success then
                            RestoreFullUserControl()
                            task.wait(1.5)
                            
                            currentFrame = 1
                            playbackStart = tick()
                            playbackPausedTime = 0
                            playbackPauseStart = 0
                            lastPlaybackState = nil
                            lastStateChangeTime = 0
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
                        
                        while not IsCharacterReady() and AutoLoop and IsAutoLoopPlaying do
                            manualRespawnWait = manualRespawnWait + 1
                            
                            if manualRespawnWait >= maxManualWait then
                                AutoLoop = false
                                IsAutoLoopPlaying = false
                                AnimateLoop(false)
                                PlaySound("Error")
                                break
                            end
                            
                            task.wait(0.5)
                        end
                        
                        if not AutoLoop or not IsAutoLoopPlaying then break end
                        
                        RestoreFullUserControl()
                        task.wait(1.5)
                        
                        currentFrame = 1
                        playbackStart = tick()
                        playbackPausedTime = 0
                        playbackPauseStart = 0
                        lastPlaybackState = nil
                        lastStateChangeTime = 0
                        loopAccumulator = 0
                        
                        SaveHumanoidState()
                        
                        continue
                    end
                end
                
                if IsPaused then
                    if playbackPauseStart == 0 then
                        playbackPauseStart = tick()
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
                    
                    while loopAccumulator >= PLAYBACK_FIXED_TIMESTEP do
                        loopAccumulator = loopAccumulator - PLAYBACK_FIXED_TIMESTEP
                        
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
                            hrp.CFrame = GetFrameCFrame(frame)
                            hrp.AssemblyLinearVelocity = GetFrameVelocity(frame)
                            
                            if hum then
                                hum.WalkSpeed = GetFrameWalkSpeed(frame) * CurrentSpeed
                                hum.AutoRotate = false
                                
                                ApplyMoveState(hum, frame.MoveState)
                                
                                if ShiftLockEnabled then
                                    ApplyVisibleShiftLock()
                                end
                            end
                        end
                    end
                    
                    if playbackCompleted then
                        break
                    end
                end
            end
            
            RestoreFullUserControl()
            UpdatePauseMarker()
            lastPlaybackState = nil
            lastStateChangeTime = 0
            
            if playbackCompleted then
                PlaySound("Success")
                
                CurrentLoopIndex = CurrentLoopIndex + 1
                if CurrentLoopIndex > #RecordingOrder then
                    CurrentLoopIndex = 1
                end
                
                task.wait(0.5)
            else
                if not AutoLoop or not IsAutoLoopPlaying then
                    break
                else
                    task.wait(1)
                end
            end
        end
        
        IsAutoLoopPlaying = false
        IsPaused = false
        RestoreFullUserControl()
        UpdatePauseMarker()
        lastPlaybackState = nil
        lastStateChangeTime = 0
        setIcon(btnPlayToggle, "▶️", ">")
    end)
end

function StopAutoLoopAll()
    AutoLoop = false
    IsAutoLoopPlaying = false
    IsPlaying = false
    IsPaused = false
    lastPlaybackState = nil
    lastStateChangeTime = 0
    
    if loopConnection then
        task.cancel(loopConnection)
        loopConnection = nil
    end
    
    RestoreFullUserControl()
    UpdatePauseMarker()
    
    local char = player.Character
    if char then CompleteCharacterReset(char) end
    
    PlaySound("Stop")
    setIcon(btnPlayToggle, "▶️", ">")
    setIcon(btnPauseToggle, "⏹", "■")
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
    lastStateChangeTime = 0
    LastPausePosition = nil
    LastPauseRecording = nil
    RestoreFullUserControl()
    UpdatePauseMarker()
    
    local char = player.Character
    if char then CompleteCharacterReset(char) end
    
    PlaySound("Stop")
    setIcon(btnPlayToggle, "▶️", ">")
    setIcon(btnPauseToggle, "⏹", "■")
end

function PausePlayback()
    if not IsPlaying and not IsAutoLoopPlaying and IsPaused then
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
                IsPlaying = true
                IsPaused = false
                CurrentPlayingRecording = LastPauseRecording
                currentPlaybackFrame = nearestFrame
                playbackStartTime = tick() - (GetFrameTimestamp(LastPauseRecording[nearestFrame]) / CurrentSpeed)
                totalPausedDuration = 0
                pauseStartTime = 0
                lastPlaybackState = nil
                lastStateChangeTime = 0
                playbackAccumulator = 0
                
                SaveHumanoidState()
                PlaySound("Play")
                
                setIcon(btnPlayToggle, "⏹", "■")
                setIcon(btnPauseToggle, "⏹", "■")
                
                playbackConnection = RunService.Heartbeat:Connect(function(deltaTime)
                    if not IsPlaying then
                        playbackConnection:Disconnect()
                        RestoreFullUserControl()
                        UpdatePauseMarker()
                        lastPlaybackState = nil
                        lastStateChangeTime = 0
                        setIcon(btnPlayToggle, "▶️", ">")
                        return
                    end
                    
                    if IsPaused then
                        if pauseStartTime == 0 then
                            pauseStartTime = tick()
                            PausedAtFrame = currentPlaybackFrame
                            local char = player.Character
                            if char and char:FindFirstChild("HumanoidRootPart") then
                                LastPausePosition = char.HumanoidRootPart.Position
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
                        setIcon(btnPlayToggle, "▶️", ">")
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
                        setIcon(btnPlayToggle, "▶️", ">")
                        return
                    end
                    
                    playbackAccumulator = playbackAccumulator + deltaTime
                    
                    while playbackAccumulator >= PLAYBACK_FIXED_TIMESTEP do
                        playbackAccumulator = playbackAccumulator - PLAYBACK_FIXED_TIMESTEP
                        
                        local currentTime = tick()
                        local effectiveTime = (currentTime - playbackStartTime - totalPausedDuration) * CurrentSpeed
                        
                        while currentPlaybackFrame < #LastPauseRecording and GetFrameTimestamp(LastPauseRecording[currentPlaybackFrame + 1]) <= effectiveTime do
                            currentPlaybackFrame = currentPlaybackFrame + 1
                        end
                        
                        if currentPlaybackFrame >= #LastPauseRecording then
                            IsPlaying = false
                            RestoreFullUserControl()
                            PlaySound("Success")
                            UpdatePauseMarker()
                            lastPlaybackState = nil
                            lastStateChangeTime = 0
                            setIcon(btnPlayToggle, "▶️", ">")
                            return
                        end
                        
                        local frame = LastPauseRecording[currentPlaybackFrame]
                        if not frame then
                            IsPlaying = false
                            RestoreFullUserControl()
                            UpdatePauseMarker()
                            lastPlaybackState = nil
                            lastStateChangeTime = 0
                            setIcon(btnPlayToggle, "▶️", ">")
                            return
                        end
                        
                        hrp.CFrame = GetFrameCFrame(frame)
                        hrp.AssemblyLinearVelocity = GetFrameVelocity(frame)
                        
                        if hum then
                            hum.WalkSpeed = GetFrameWalkSpeed(frame) * CurrentSpeed
                            hum.AutoRotate = false
                            
                            ApplyMoveState(hum, frame.MoveState)
                            
                            if ShiftLockEnabled then
                                ApplyVisibleShiftLock()
                            end
                        end
                    end
                end)
                
                AddConnection(playbackConnection)
                UpdatePauseMarker()
            else
                hrp.CFrame = GetFrameCFrame(LastPauseRecording[1])
                task.wait(0.1)
                
                IsPlaying = true
                IsPaused = false
                CurrentPlayingRecording = LastPauseRecording
                currentPlaybackFrame = 1
                playbackStartTime = tick()
                totalPausedDuration = 0
                pauseStartTime = 0
                lastPlaybackState = nil
                lastStateChangeTime = 0
                playbackAccumulator = 0
                
                SaveHumanoidState()
                PlaySound("Play")
                
                setIcon(btnPlayToggle, "⏹", "■")
                setIcon(btnPauseToggle, "⏹", "■")
                
                playbackConnection = RunService.Heartbeat:Connect(function(deltaTime)
                    if not IsPlaying then
                        playbackConnection:Disconnect()
                        RestoreFullUserControl()
                        UpdatePauseMarker()
                        lastPlaybackState = nil
                        lastStateChangeTime = 0
                        setIcon(btnPlayToggle, "▶️", ">")
                        return
                    end
                    
                    if IsPaused then
                        if pauseStartTime == 0 then
                            pauseStartTime = tick()
                            PausedAtFrame = currentPlaybackFrame
                            local char = player.Character
                            if char and char:FindFirstChild("HumanoidRootPart") then
                                LastPausePosition = char.HumanoidRootPart.Position
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
                        setIcon(btnPlayToggle, "▶️", ">")
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
                        setIcon(btnPlayToggle, "▶️", ">")
                        return
                    end
                    
                    playbackAccumulator = playbackAccumulator + deltaTime
                    
                    while playbackAccumulator >= PLAYBACK_FIXED_TIMESTEP do
                        playbackAccumulator = playbackAccumulator - PLAYBACK_FIXED_TIMESTEP
                        
                        local currentTime = tick()
                        local effectiveTime = (currentTime - playbackStartTime - totalPausedDuration) * CurrentSpeed
                        
                        while currentPlaybackFrame < #LastPauseRecording and GetFrameTimestamp(LastPauseRecording[currentPlaybackFrame + 1]) <= effectiveTime do
                            currentPlaybackFrame = currentPlaybackFrame + 1
                        end
                        
                        if currentPlaybackFrame >= #LastPauseRecording then
                            IsPlaying = false
                            RestoreFullUserControl()
                            PlaySound("Success")
                            UpdatePauseMarker()
                            lastPlaybackState = nil
                            lastStateChangeTime = 0
                            setIcon(btnPlayToggle, "▶️", ">")
                            return
                        end
                        
                        local frame = LastPauseRecording[currentPlaybackFrame]
                        if not frame then
                            IsPlaying = false
                            RestoreFullUserControl()
                            UpdatePauseMarker()
                            lastPlaybackState = nil
                            lastStateChangeTime = 0
                            setIcon(btnPlayToggle, "▶️", ">")
                            return
                        end
                        
                        hrp.CFrame = GetFrameCFrame(frame)
                        hrp.AssemblyLinearVelocity = GetFrameVelocity(frame)
                        
                        if hum then
                            hum.WalkSpeed = GetFrameWalkSpeed(frame) * CurrentSpeed
                            hum.AutoRotate = false
                            
                            ApplyMoveState(hum, frame.MoveState)
                            
                            if ShiftLockEnabled then
                                ApplyVisibleShiftLock()
                            end
                        end
                    end
                end)
                
                AddConnection(playbackConnection)
                UpdatePauseMarker()
            end
        end
        return
    end
    
    if AutoLoop and IsAutoLoopPlaying then
        IsPaused = not IsPaused
        
        if IsPaused then
            setIcon(btnPauseToggle, "⏸", "||")
            RestoreHumanoidState()
            if ShiftLockEnabled then
                ApplyVisibleShiftLock()
            end
            UpdatePauseMarker()
            PlaySound("Click")
        else
            setIcon(btnPauseToggle, "⏹", "■")
            SaveHumanoidState()
            UpdatePauseMarker()
            PlaySound("Click")
        end
    elseif IsPlaying then
        IsPaused = not IsPaused
        
        if IsPaused then
            setIcon(btnPauseToggle, "⏸", "||")
            RestoreHumanoidState()
            if ShiftLockEnabled then
                ApplyVisibleShiftLock()
            end
            UpdatePauseMarker()
            PlaySound("Click")
        else
            setIcon(btnPauseToggle, "⏹", "■")
            SaveHumanoidState()
            UpdatePauseMarker()
            PlaySound("Click")
        end
    end
end

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

-- ========= PLAYBACK BUTTON CONNECTIONS =========
btnPlayToggle.MouseButton1Click:Connect(function()
    SimpleButtonClick(btnPlayToggle)
    if IsPlaying or IsAutoLoopPlaying then
        StopPlayback()
    else
        if AutoLoop then
            StartAutoLoopAll()
        else
            PlayRecording()
        end
    end
end)

btnPauseToggle.MouseButton1Click:Connect(function()
    SimpleButtonClick(btnPauseToggle)
    PausePlayback()
end)

-- ========= TOGGLE CONNECTIONS =========
ToggleLoopBtn.MouseButton1Click:Connect(function()
    SimpleButtonClick(ToggleLoopBtn)
    AutoLoop = not AutoLoop
    AnimateLoop(AutoLoop)
    
    if AutoLoop then
        if not next(RecordedMovements) then
            AutoLoop = false
            AnimateLoop(false)
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

ToggleShiftBtn.MouseButton1Click:Connect(function()
    SimpleButtonClick(ToggleShiftBtn)
    ToggleVisibleShiftLock()
    AnimateShift(ShiftLockEnabled)
end)

ToggleRespawnBtn.MouseButton1Click:Connect(function()
    SimpleButtonClick(ToggleRespawnBtn)
    AutoRespawn = not AutoRespawn
    AnimateRespawn(AutoRespawn)
    PlaySound("Toggle")
end)

ToggleResetBtn.MouseButton1Click:Connect(function()
    SimpleButtonClick(ToggleResetBtn)
    AutoReset = not AutoReset
    AnimateReset(AutoReset)
    PlaySound("Toggle")
end)

ToggleJumpBtn.MouseButton1Click:Connect(function()
    SimpleButtonClick(ToggleJumpBtn)
    ToggleInfiniteJump()
    AnimateJump(InfiniteJump)
    PlaySound("Toggle")
end)

-- ========= MAIN FRAME CONNECTIONS =========
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
    SimpleButtonClick(MergeBtn)
    CreateMergedReplay()
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
    if StudioIsRecording then StopStudioRecording() end
    if IsPlaying or AutoLoop then StopPlayback() end
    if ShiftLockEnabled then DisableVisibleShiftLock() end
    if InfiniteJump then DisableInfiniteJump() end
    CleanupConnections()
    ClearPathVisualization()
    ScreenGui:Destroy()
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F9 then
        if StudioIsRecording then StopStudioRecording() else StartStudioRecording() end
    elseif input.KeyCode == Enum.KeyCode.F10 then
        if IsPlaying or AutoLoop then StopPlayback() else PlayRecording() end
    elseif input.KeyCode == Enum.KeyCode.F11 then
        MainFrame.Visible = not MainFrame.Visible
        MiniButton.Visible = not MainFrame.Visible
    elseif input.KeyCode == Enum.KeyCode.F7 then
        AutoLoop = not AutoLoop
        AnimateLoop(AutoLoop)
        if AutoLoop then StartAutoLoopAll() else StopAutoLoopAll() end
    elseif input.KeyCode == Enum.KeyCode.F6 then
        SaveToObfuscatedJSON()
    elseif input.KeyCode == Enum.KeyCode.F5 then
        AutoRespawn = not AutoRespawn
        AnimateRespawn(AutoRespawn)
    elseif input.KeyCode == Enum.KeyCode.F4 then
        ShowPaths = not ShowPaths
        if ShowPaths then
            VisualizeAllPaths()
        else
            ClearPathVisualization()
        end
    elseif input.KeyCode == Enum.KeyCode.F3 then
        ToggleVisibleShiftLock()
        AnimateShift(ShiftLockEnabled)
    elseif input.KeyCode == Enum.KeyCode.F2 then
        ToggleInfiniteJump()
        AnimateJump(InfiniteJump)
    elseif input.KeyCode == Enum.KeyCode.LeftBracket then
        GoBackTimeline()
    elseif input.KeyCode == Enum.KeyCode.RightBracket then
        GoNextTimeline()
    end
end)

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
    if StudioIsRecording then
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
