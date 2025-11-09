local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local player = Players.LocalPlayer
wait(1)

-- ========= CONFIGURATION =========
local RECORDING_FPS = 60
local MAX_FRAMES = 30000
local MIN_DISTANCE_THRESHOLD = 0.015
local VELOCITY_SCALE = 1
local VELOCITY_Y_SCALE = 1

-- ========= OPTIMIZED INTERPOLATION SYSTEM =========
local INTERPOLATION_ENABLED = true
local INTERPOLATION_ALPHA = 0.7
local MAX_INTERPOLATION_DISTANCE = 25
local MIN_INTERPOLATION_DISTANCE = 0.05

-- ========= RESUME SYSTEM IMPROVEMENT =========
local RESUME_REWIND_SECONDS = 0.5  -- Mundur 0.5 detik saat resume
local MAX_RESUME_REWINDS = 10      -- Maksimal 10x rewind (5 detik total)

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
local lastRecordTime = 0
local lastRecordPos = nil
local checkpointNames = {}
local PathVisualization = {}
local ShowPaths = false
local CurrentPauseMarker = nil

-- ========= STUDIO RECORDING VARIABLES =========
local IsStudioRecording = false
local IsStudioPlaying = false
local IsStudioPaused = false
local IsReversing = false
local IsForwarding = false
local StudioRecording = {Frames = {}, StartTime = 0, Name = ""}
local studioRecordConnection = nil
local reverseConnection = nil
local forwardConnection = nil
local currentRewindCount = 0

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
local originalJumpButtonEnabled = true

-- ========= PLAYBACK STATE TRACKING =========
local lastPlaybackState = nil
local lastStateChangeTime = 0
local STATE_CHANGE_COOLDOWN = 0.15

-- ========= AUTO LOOP VARIABLES =========
local IsAutoLoopPlaying = false
local CurrentLoopIndex = 1
local LoopPauseStartTime = 0
local LoopTotalPausedDuration = 0

-- ========= VISIBLE SHIFTLOCK SYSTEM =========
local shiftLockConnection = nil
local originalMouseBehavior = nil
local ShiftLockEnabled = false
local isShiftLockActive = false

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
    if shiftLockConnection then
        shiftLockConnection:Disconnect()
        shiftLockConnection = nil
    end
    if jumpConnection then
        jumpConnection:Disconnect()
        jumpConnection = nil
    end
    if studioRecordConnection then
        studioRecordConnection:Disconnect()
        studioRecordConnection = nil
    end
    if reverseConnection then
        reverseConnection:Disconnect()
        reverseConnection = nil
    end
    if forwardConnection then
        forwardConnection:Disconnect()
        forwardConnection = nil
    end
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
    TweenService:Create(button, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
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
        humanoid.JumpPower = prePauseJumpPower or 50
        humanoid.Sit = false
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end)
end

-- ========= VISIBLE SHIFTLOCK SYSTEM FUNCTIONS =========
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

-- ========= JUMP BUTTON CONTROL SYSTEM =========
local function HideJumpButton()
    pcall(function()
        StarterGui:SetCore("VRLaserPointerMode", 0)
        StarterGui:SetCore("VREnableControllerModels", false)
        
        local touchGui = player.PlayerGui:FindFirstChild("TouchGui")
        if touchGui then
            local touchControlFrame = touchGui:FindFirstChild("TouchControlFrame")
            if touchControlFrame then
                local jumpButton = touchControlFrame:FindFirstChild("JumpButton")
                if jumpButton then
                    jumpButton.Visible = false
                end
            end
        end
        
        StarterGui:SetCore("TopbarEnabled", false)
    end)
end

local function ShowJumpButton()
    pcall(function()
        StarterGui:SetCore("VRLaserPointerMode", 3)
        StarterGui:SetCore("VREnableControllerModels", true)
        
        local touchGui = player.PlayerGui:FindFirstChild("TouchGui")
        if touchGui then
            local touchControlFrame = touchGui:FindFirstChild("TouchControlFrame")
            if touchControlFrame then
                local jumpButton = touchControlFrame:FindFirstChild("JumpButton")
                if jumpButton then
                    jumpButton.Visible = true
                end
            end
        end
        
        StarterGui:SetCore("TopbarEnabled", true)
    end)
end

local function SaveJumpButtonState()
    originalJumpButtonEnabled = true
end

-- ========= IMPROVED CLIMBING PAUSE FIX =========
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
    
    SaveJumpButtonState()
end

local function RestoreHumanoidState()
    local char = player.Character
    if not char then return end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
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

-- ========= FULL USER CONTROL RESTORATION =========
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
    
    ShowJumpButton()
    
    if ShiftLockEnabled then
        EnableVisibleShiftLock()
    end
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

local function VisualizeRecordingPath(recording, name)
    ClearPathVisualization()
    
    if not recording or #recording < 2 then return end
    
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

-- ========= SMOOTH INTERPOLATION FUNCTIONS =========
local function SmoothCFrameLerp(currentCF, targetCF, alpha, maxDistance)
    if not INTERPOLATION_ENABLED then
        return targetCF
    end
    
    local currentPos = currentCF.Position
    local targetPos = targetCF.Position
    local distance = (targetPos - currentPos).Magnitude
    
    if distance > (maxDistance or MAX_INTERPOLATION_DISTANCE) then
        return targetCF
    end
    
    if distance < MIN_INTERPOLATION_DISTANCE then
        return targetCF
    end
    
    local dynamicAlpha = math.min(alpha, distance * 2)
    
    local newPos = currentPos:Lerp(targetPos, dynamicAlpha)
    local newCF = currentCF:Lerp(targetCF, dynamicAlpha * 0.8)
    
    return CFrame.new(newPos) * (newCF - newCF.Position)
end

local function SmoothVector3Lerp(currentVec, targetVec, alpha)
    return currentVec:Lerp(targetVec, alpha * 0.6)
end

-- ========= ENHANCED RESUME & MERGE SYSTEM =========
local function FixBrokenTransitions(recording)
    if not recording or #recording < 10 then return recording end
    
    local fixedFrames = {}
    local lastGoodFrame = recording[1]
    
    table.insert(fixedFrames, lastGoodFrame)
    
    for i = 2, #recording do
        local currentFrame = recording[i]
        local prevFrame = recording[i-1]
        
        local currentPos = Vector3.new(currentFrame.Position[1], currentFrame.Position[2], currentFrame.Position[3])
        local prevPos = Vector3.new(prevFrame.Position[1], prevFrame.Position[2], prevFrame.Position[3])
        
        local distance = (currentPos - prevPos).Magnitude
        local timeGap = currentFrame.Timestamp - prevFrame.Timestamp
        
        if distance > 5 and timeGap < 0.5 then
            local transitionFrames = math.min(15, math.max(5, math.floor(distance * 1.5)))
            
            for j = 1, transitionFrames do
                local progress = j / transitionFrames
                local easeProgress = progress * progress
                
                local transitionFrame = {
                    Position = {
                        prevFrame.Position[1] + (currentFrame.Position[1] - prevFrame.Position[1]) * easeProgress,
                        prevFrame.Position[2] + (currentFrame.Position[2] - prevFrame.Position[2]) * easeProgress,
                        prevFrame.Position[3] + (currentFrame.Position[3] - prevFrame.Position[3]) * easeProgress
                    },
                    LookVector = {
                        prevFrame.LookVector[1] + (currentFrame.LookVector[1] - prevFrame.LookVector[1]) * progress,
                        prevFrame.LookVector[2] + (currentFrame.LookVector[2] - prevFrame.LookVector[2]) * progress,
                        prevFrame.LookVector[3] + (currentFrame.LookVector[3] - prevFrame.LookVector[3]) * progress
                    },
                    UpVector = {
                        prevFrame.UpVector[1] + (currentFrame.UpVector[1] - prevFrame.UpVector[1]) * progress,
                        prevFrame.UpVector[2] + (currentFrame.UpVector[2] - prevFrame.UpVector[2]) * progress,
                        prevFrame.UpVector[3] + (currentFrame.UpVector[3] - prevFrame.UpVector[3]) * progress
                    },
                    Velocity = {
                        prevFrame.Velocity[1] * (1 - progress) + currentFrame.Velocity[1] * progress,
                        prevFrame.Velocity[2] * (1 - progress) + currentFrame.Velocity[2] * progress,
                        prevFrame.Velocity[3] * (1 - progress) + currentFrame.Velocity[3] * progress
                    },
                    MoveState = distance > 10 and "Grounded" or prevFrame.MoveState,
                    WalkSpeed = prevFrame.WalkSpeed + (currentFrame.WalkSpeed - prevFrame.WalkSpeed) * progress,
                    Timestamp = prevFrame.Timestamp + (timeGap * progress)
                }
                
                table.insert(fixedFrames, transitionFrame)
            end
        else
            table.insert(fixedFrames, currentFrame)
        end
        
        lastGoodFrame = currentFrame
    end
    
    return fixedFrames
end

-- ========= UPDATED MERGE SYSTEM =========
local function CreateMergedReplayWithSmoothTransition()
    if #RecordingOrder < 2 then
        PlaySound("Error")
        return
    end
    
    local mergedFrames = {}
    local totalTimeOffset = 0
    
    for orderIndex, checkpointName in ipairs(RecordingOrder) do
        local checkpoint = RecordedMovements[checkpointName]
        if not checkpoint then continue end
        
        local fixedCheckpoint = FixBrokenTransitions(checkpoint)
        
        if #mergedFrames > 0 and #fixedCheckpoint > 0 then
            local lastFrame = mergedFrames[#mergedFrames]
            local firstFrame = fixedCheckpoint[1]
            
            local lastPos = Vector3.new(lastFrame.Position[1], lastFrame.Position[2], lastFrame.Position[3])
            local firstPos = Vector3.new(firstFrame.Position[1], firstFrame.Position[2], firstFrame.Position[3])
            local distance = (firstPos - lastPos).Magnitude
            
            local transitionFramesCount = math.min(20, math.max(8, math.floor(distance * 1.2)))
            
            for i = 1, transitionFramesCount do
                local progress = i / transitionFramesCount
                local easeProgress = progress * (2 - progress)
                
                local transitionFrame = {
                    Position = {
                        lastFrame.Position[1] + (firstFrame.Position[1] - lastFrame.Position[1]) * easeProgress,
                        lastFrame.Position[2] + (firstFrame.Position[2] - lastFrame.Position[2]) * easeProgress,
                        lastFrame.Position[3] + (firstFrame.Position[3] - lastFrame.Position[3]) * easeProgress
                    },
                    LookVector = {
                        lastFrame.LookVector[1] + (firstFrame.LookVector[1] - lastFrame.LookVector[1]) * progress,
                        lastFrame.LookVector[2] + (firstFrame.LookVector[2] - lastFrame.LookVector[2]) * progress,
                        lastFrame.LookVector[3] + (firstFrame.LookVector[3] - lastFrame.LookVector[3]) * progress
                    },
                    UpVector = firstFrame.UpVector,
                    Velocity = {
                        lastFrame.Velocity[1] * (1 - progress) + firstFrame.Velocity[1] * progress,
                        lastFrame.Velocity[2] * (1 - progress) + firstFrame.Velocity[2] * progress,
                        lastFrame.Velocity[3] * (1 - progress) + firstFrame.Velocity[3] * progress
                    },
                    MoveState = "Grounded",
                    WalkSpeed = lastFrame.WalkSpeed + (firstFrame.WalkSpeed - lastFrame.WalkSpeed) * progress,
                    Timestamp = lastFrame.Timestamp + (0.08 * i)
                }
                
                table.insert(mergedFrames, transitionFrame)
            end
        end
        
        for frameIndex, frame in ipairs(fixedCheckpoint) do
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
        
        if #fixedCheckpoint > 0 then
            totalTimeOffset = totalTimeOffset + fixedCheckpoint[#fixedCheckpoint].Timestamp + 0.15
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
            
            if distance < 0.02 and frame.MoveState == lastSignificantFrame.MoveState then
                shouldInclude = false
            end
        end
        
        if shouldInclude then
            table.insert(optimizedFrames, frame)
            lastSignificantFrame = frame
        end
    end
    
    local mergedName = "merged_smooth_" .. os.date("%H%M%S")
    RecordedMovements[mergedName] = optimizedFrames
    table.insert(RecordingOrder, mergedName)
    checkpointNames[mergedName] = "SMOOTH MERGE"
    
    UpdateRecordList()
    PlaySound("Success")
end

-- ========= FRAME DATA FUNCTIONS =========
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

-- ========= IMPROVED RESUME SYSTEM =========
local function FindResumeFrameIndex(recording, currentRewindCount)
    if not recording or #recording == 0 then return 1 end
    
    local targetRewindTime = currentRewindCount * RESUME_REWIND_SECONDS
    local currentTime = recording[#recording].Timestamp
    
    local targetTime = math.max(0, currentTime - targetRewindTime)
    
    for i = #recording, 1, -1 do
        if recording[i].Timestamp <= targetTime then
            return math.max(1, i)
        end
    end
    
    return 1
end

local function SmartResumeRecording()
    if not IsStudioRecording or #StudioRecording.Frames == 0 then
        StudioStatusLabel.Text = "❌ No recording to resume!"
        StudioStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        PlaySound("Error")
        return
    end
    
    -- Increment rewind counter
    currentRewindCount = math.min(currentRewindCount + 1, MAX_RESUME_REWINDS)
    
    local resumeFrameIndex = FindResumeFrameIndex(StudioRecording.Frames, currentRewindCount)
    local framesToDelete = #StudioRecording.Frames - resumeFrameIndex
    
    if framesToDelete > 0 then
        for i = #StudioRecording.Frames, resumeFrameIndex + 1, -1 do
            table.remove(StudioRecording.Frames, i)
        end
    end
    
    StudioStatusLabel.Text = string.format("⏪ Rewind %d/%d (%d frames deleted)", 
        currentRewindCount, MAX_RESUME_REWINDS, framesToDelete)
    StudioStatusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
    
    UpdateStudioUI()
    PlaySound("Success")
end

local function ResetResumeRewind()
    currentRewindCount = 0
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

-- Main Frame 250x280
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.fromOffset(250, 280)
MainFrame.Position = UDim2.new(0.5, -125, 0.5, -140)
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
Title.Text = "ByaruL"
Title.TextColor3 = Color3.fromRGB(255,255,255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Center
Title.Parent = Header

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
Content.CanvasSize = UDim2.new(0, 0, 0, 600)
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

-- Enhanced Button Creation with Powerful Animations
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
local StudioBtn = CreateButton("🎬 STUDIO", 5, 5, 117, 30, Color3.fromRGB(59, 15, 116))
local SettingsBtn = CreateButton("⚙️ SETTINGS", 127, 5, 117, 30, Color3.fromRGB(59, 15, 116))

local PlayBtnBig = CreateButton("PLAY", 5, 40, 75, 30, Color3.fromRGB(59, 15, 116))
local StopBtnBig = CreateButton("STOP", 85, 40, 75, 30, Color3.fromRGB(59, 15, 116))
local PauseBtnBig = CreateButton("PAUSE", 165, 40, 75, 30, Color3.fromRGB(59, 15, 116))

local LoopBtn, AnimateLoop = CreateToggle("Auto Loop", 0, 75, 78, 22, false)
local JumpBtn, AnimateJump = CreateToggle("Infinite Jump", 82, 75, 78, 22, false)
local ShiftLockBtn, AnimateShiftLock = CreateToggle("ShiftLock", 164, 75, 78, 22, false)

local RespawnBtn, AnimateRespawn = CreateToggle("Auto Respawn", 0, 102, 117, 22, false)

local SpeedBox = Instance.new("TextBox")
SpeedBox.Size = UDim2.fromOffset(58, 26)
SpeedBox.Position = UDim2.fromOffset(0, 129)
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
FilenameBox.Size = UDim2.fromOffset(58, 26)
FilenameBox.Position = UDim2.fromOffset(63, 129)
FilenameBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
FilenameBox.BorderSizePixel = 0
FilenameBox.Text = ""
FilenameBox.PlaceholderText = "File..."
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
WalkSpeedBox.Size = UDim2.fromOffset(58, 26)
WalkSpeedBox.Position = UDim2.fromOffset(126, 129)
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

-- Record List
local RecordList = Instance.new("ScrollingFrame")
RecordList.Size = UDim2.new(1, 0, 0, 180)
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

-- ========= NEW STUDIO RECORDING GUI =========
local RecordingStudio = Instance.new("Frame")
RecordingStudio.Size = UDim2.fromOffset(190, 190)
RecordingStudio.Position = UDim2.new(0.5, -95, 0.5, -95)
RecordingStudio.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
RecordingStudio.BorderSizePixel = 0
RecordingStudio.Active = true
RecordingStudio.Draggable = true
RecordingStudio.Visible = false
RecordingStudio.Parent = ScreenGui

local StudioCorner = Instance.new("UICorner")
StudioCorner.CornerRadius = UDim.new(0, 10)
StudioCorner.Parent = RecordingStudio

local StudioStroke = Instance.new("UIStroke")
StudioStroke.Color = Color3.fromRGB(59, 15, 116)
StudioStroke.Thickness = 2
StudioStroke.Parent = RecordingStudio

-- Studio Header dengan Frame Label di tengah
local StudioHeader = Instance.new("Frame")
StudioHeader.Size = UDim2.new(1, 0, 0, 28)
StudioHeader.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
StudioHeader.BorderSizePixel = 0
StudioHeader.Parent = RecordingStudio

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 10)
HeaderCorner.Parent = StudioHeader

local StudioFrameLabel = Instance.new("TextLabel")
StudioFrameLabel.Size = UDim2.new(1, -60, 1, 0)
StudioFrameLabel.Position = UDim2.new(0, 30, 0, 0)
StudioFrameLabel.BackgroundTransparency = 1
StudioFrameLabel.Text = "Frame: 0"
StudioFrameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
StudioFrameLabel.Font = Enum.Font.GothamBold
StudioFrameLabel.TextSize = 11
StudioFrameLabel.TextXAlignment = Enum.TextXAlignment.Center
StudioFrameLabel.Parent = StudioHeader

local CloseStudioBtn = Instance.new("TextButton")
CloseStudioBtn.Size = UDim2.fromOffset(20, 20)
CloseStudioBtn.Position = UDim2.new(1, -25, 0.5, -10)
CloseStudioBtn.BackgroundColor3 = Color3.fromRGB(230, 62, 62)
CloseStudioBtn.Text = "×"
CloseStudioBtn.TextColor3 = Color3.new(1, 1, 1)
CloseStudioBtn.Font = Enum.Font.GothamBold
CloseStudioBtn.TextSize = 14
CloseStudioBtn.Parent = StudioHeader

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 5)
CloseCorner.Parent = CloseStudioBtn

-- Studio Content - Full Drag
local StudioContent = Instance.new("Frame")
StudioContent.Size = UDim2.new(1, -16, 1, -36)
StudioContent.Position = UDim2.new(0, 8, 0, 32)
StudioContent.BackgroundTransparency = 1
StudioContent.Active = true
StudioContent.Draggable = true
StudioContent.Parent = RecordingStudio

-- Helper function for studio buttons
local function CreateStudioBtn(text, x, y, w, h, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(w, h)
    btn.Position = UDim2.fromOffset(x, y)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 9
    btn.AutoButtonColor = false
    btn.Parent = StudioContent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
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
    end)
    
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = color}):Play()
    end)
    
    return btn
end

-- Top Row: [SAVE] [CLEAR]
local StudioSaveBtn = CreateStudioBtn("SAVE", 5, 5, 85, 25, Color3.fromRGB(59, 15, 116))
local StudioClearBtn = CreateStudioBtn("CLEAR", 95, 5, 85, 25, Color3.fromRGB(59, 15, 116))

-- Middle: [RECORD] (Full Width)
local StudioRecordBtn = CreateStudioBtn("● RECORD", 5, 35, 175, 30, Color3.fromRGB(59, 15, 116))

-- Middle: [RESUME] (Full Width)
local StudioResumeBtn = CreateStudioBtn("RESUME", 5, 70, 175, 30, Color3.fromRGB(59, 15, 116))

-- Bottom: [BACK] [NEXT]
local StudioReverseBtn = CreateStudioBtn("BACK", 5, 105, 85, 30, Color3.fromRGB(59, 15, 116))
local StudioForwardBtn = CreateStudioBtn("NEXT", 95, 105, 85, 30, Color3.fromRGB(59, 15, 116))

-- Status Label
local StudioStatusLabel = Instance.new("TextLabel")
StudioStatusLabel.Size = UDim2.fromOffset(175, 20)
StudioStatusLabel.Position = UDim2.fromOffset(5, 140)
StudioStatusLabel.BackgroundTransparency = 1
StudioStatusLabel.Text = "Ready to record"
StudioStatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
StudioStatusLabel.Font = Enum.Font.Gotham
StudioStatusLabel.TextSize = 8
StudioStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
StudioStatusLabel.Parent = StudioContent

-- ========= STUDIO RECORDING FUNCTIONS =========
local function UpdateStudioUI()
    StudioFrameLabel.Text = string.format("Frame: %d", #StudioRecording.Frames)
end

local function StartStudioRecording()
    if IsStudioRecording then return end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        StudioStatusLabel.Text = "❌ Character not found!"
        StudioStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    IsStudioRecording = true
    IsReversing = false
    IsForwarding = false
    ResetResumeRewind()  -- Reset rewind counter saat mulai recording baru
    StudioRecording = {Frames = {}, StartTime = tick(), Name = "Studio_" .. os.date("%H%M%S")}
    lastRecordTime = 0
    lastRecordPos = nil
    
    StudioRecordBtn.Text = "⏹ STOP"
    StudioRecordBtn.BackgroundColor3 = Color3.fromRGB(163, 10, 10)
    StudioStatusLabel.Text = "🎬 Recording..."
    StudioStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
    
    PlaySound("RecordStart")
    
    studioRecordConnection = RunService.Heartbeat:Connect(function()
        if not IsStudioRecording then return end
        
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") or #StudioRecording.Frames >= MAX_FRAMES then
            return
        end
        
        local hrp = char.HumanoidRootPart
        local hum = char:FindFirstChildOfClass("Humanoid")
        
        if IsReversing or IsForwarding then
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
        table.insert(StudioRecording.Frames, {
            Position = {cf.Position.X, cf.Position.Y, cf.Position.Z},
            LookVector = {cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z},
            UpVector = {cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z},
            Velocity = {currentVelocity.X, currentVelocity.Y, currentVelocity.Z},
            MoveState = GetCurrentMoveState(hum),
            WalkSpeed = hum and hum.WalkSpeed or 16,
            Timestamp = now - StudioRecording.StartTime
        })
        
        lastRecordTime = now
        lastRecordPos = currentPos
        
        UpdateStudioUI()
    end)
    
    AddConnection(studioRecordConnection)
end

local function StopStudioRecording()
    IsStudioRecording = false
    
    if studioRecordConnection then
        studioRecordConnection:Disconnect()
        studioRecordConnection = nil
    end
    
    StudioRecordBtn.Text = "● RECORD"
    StudioRecordBtn.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
    
    if #StudioRecording.Frames > 0 then
        StudioStatusLabel.Text = "✅ Recording stopped (" .. #StudioRecording.Frames .. " frames)"
        StudioStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
    else
        StudioStatusLabel.Text = "Recording stopped (0 frames)"
        StudioStatusLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
    end
    
    PlaySound("RecordStop")
end

local function SaveStudioRecording()
    if #StudioRecording.Frames == 0 then
        StudioStatusLabel.Text = "❌ No frames to save!"
        StudioStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        PlaySound("Error")
        return
    end
    
    if IsStudioRecording then
        StopStudioRecording()
    end
    
    RecordedMovements[StudioRecording.Name] = StudioRecording.Frames
    table.insert(RecordingOrder, StudioRecording.Name)
    checkpointNames[StudioRecording.Name] = "studio_" .. #RecordingOrder
    
    UpdateRecordList()
    
    StudioStatusLabel.Text = "💾 Saved: " .. StudioRecording.Name
    StudioStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
    
    PlaySound("Success")
    
    StudioRecording = {Frames = {}, StartTime = 0, Name = "Studio_" .. os.date("%H%M%S")}
    ResetResumeRewind()
    UpdateStudioUI()
    
    wait(1.5)
    RecordingStudio.Visible = false
    MainFrame.Visible = true
end

local function ClearStudioRecording()
    if IsStudioRecording then
        StopStudioRecording()
    end
    
    StudioRecording = {Frames = {}, StartTime = 0, Name = "Studio_" .. os.date("%H%M%S")}
    ResetResumeRewind()
    
    UpdateStudioUI()
    StudioStatusLabel.Text = "🗑️ Cleared - Ready to record"
    StudioStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
    PlaySound("Success")
end

local function StartReversePlayback()
    if IsReversing or not IsStudioRecording then return end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        StudioStatusLabel.Text = "❌ Character not found!"
        StudioStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    if #StudioRecording.Frames == 0 then
        StudioStatusLabel.Text = "❌ No frames to reverse!"
        StudioStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    IsReversing = true
    IsForwarding = false
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    
    if hum then
        hum.AutoRotate = false
    end
    
    StudioStatusLabel.Text = "⏪ Reversing..."
    StudioStatusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
    
    local currentFrame = #StudioRecording.Frames
    local targetFrame = math.max(1, currentFrame - math.floor(RECORDING_FPS * 0.5))
    
    reverseConnection = RunService.Heartbeat:Connect(function()
        if not IsReversing or not IsStudioRecording then
            if reverseConnection then
                reverseConnection:Disconnect()
                reverseConnection = nil
            end
            return
        end
        
        char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            IsReversing = false
            if reverseConnection then
                reverseConnection:Disconnect()
                reverseConnection = nil
            end
            return
        end
        
        hrp = char:FindFirstChild("HumanoidRootPart")
        hum = char:FindFirstChildOfClass("Humanoid")
        
        if not hrp or not hum then
            IsReversing = false
            if reverseConnection then
                reverseConnection:Disconnect()
                reverseConnection = nil
            end
            return
        end
        
        if currentFrame <= targetFrame then
            currentFrame = targetFrame
            IsReversing = false
            StudioStatusLabel.Text = "⏹️ Reverse completed"
            StudioStatusLabel.TextColor3 = Color3.fromRGB(255, 150, 50)
            if reverseConnection then
                reverseConnection:Disconnect()
                reverseConnection = nil
            end
            return
        end
        
        currentFrame = currentFrame - 1
        
        local frame = StudioRecording.Frames[math.floor(currentFrame)]
        if frame then
            local targetCFrame = GetFrameCFrame(frame)
            hrp.CFrame = targetCFrame
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            
            if hum then
                hum.WalkSpeed = 0
            end
            
            UpdateStudioUI()
        end
    end)
    
    AddConnection(reverseConnection)
end

local function StopReversePlayback()
    IsReversing = false
    
    if reverseConnection then
        reverseConnection:Disconnect()
        reverseConnection = nil
    end
    
    StudioStatusLabel.Text = "⏸️ Reverse stopped"
    StudioStatusLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
end

local function StartForwardPlayback()
    if IsForwarding or not IsStudioRecording then return end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        StudioStatusLabel.Text = "❌ Character not found!"
        StudioStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    if #StudioRecording.Frames == 0 then
        StudioStatusLabel.Text = "❌ No frames to forward!"
        StudioStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    IsForwarding = true
    IsReversing = false
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    
    if hum then
        hum.AutoRotate = false
    end
    
    StudioStatusLabel.Text = "⏩ Forwarding..."
    StudioStatusLabel.TextColor3 = Color3.fromRGB(200, 150, 100)
    
    local currentPos = hrp.Position
    local nearestFrame = 1
    local nearestDistance = math.huge
    
    for i, frame in ipairs(StudioRecording.Frames) do
        local framePos = Vector3.new(frame.Position[1], frame.Position[2], frame.Position[3])
        local distance = (framePos - currentPos).Magnitude
        
        if distance < nearestDistance then
            nearestDistance = distance
            nearestFrame = i
        end
    end
    
    local currentFrame = nearestFrame
    local targetFrame = math.min(#StudioRecording.Frames, currentFrame + math.floor(RECORDING_FPS * 0.5))
    
    forwardConnection = RunService.Heartbeat:Connect(function()
        if not IsForwarding or not IsStudioRecording then
            if forwardConnection then
                forwardConnection:Disconnect()
                forwardConnection = nil
            end
            return
        end
        
        char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            IsForwarding = false
            if forwardConnection then
                forwardConnection:Disconnect()
                forwardConnection = nil
            end
            return
        end
        
        hrp = char:FindFirstChild("HumanoidRootPart")
        hum = char:FindFirstChildOfClass("Humanoid")
        
        if not hrp or not hum then
            IsForwarding = false
            if forwardConnection then
                forwardConnection:Disconnect()
                forwardConnection = nil
            end
            return
        end
        
        if currentFrame >= targetFrame then
            currentFrame = targetFrame
            IsForwarding = false
            StudioStatusLabel.Text = "⏹️ Forward completed"
            StudioStatusLabel.TextColor3 = Color3.fromRGB(255, 150, 50)
            if forwardConnection then
                forwardConnection:Disconnect()
                forwardConnection = nil
            end
            return
        end
        
        currentFrame = currentFrame + 1
        
        local frame = StudioRecording.Frames[math.floor(currentFrame)]
        if frame then
            local targetCFrame = GetFrameCFrame(frame)
            hrp.CFrame = targetCFrame
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            
            if hum then
                hum.WalkSpeed = 0
            end
            
            UpdateStudioUI()
        end
    end)
    
    AddConnection(forwardConnection)
end

local function StopForwardPlayback()
    IsForwarding = false
    
    if forwardConnection then
        forwardConnection:Disconnect()
        forwardConnection = nil
    end
    
    StudioStatusLabel.Text = "⏸️ Forward stopped"
    StudioStatusLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
end

-- ========= IMPROVED RESUME FUNCTION =========
local function ResumeStudioRecording()
    if not IsStudioRecording then
        StudioStatusLabel.Text = "❌ Not recording!"
        return
    end
    
    if IsReversing then
        StopReversePlayback()
    end
    
    if IsForwarding then
        StopForwardPlayback()
    end
    
    SmartResumeRecording()
end

-- ========= STUDIO BUTTON EVENTS =========
StudioRecordBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(StudioRecordBtn)
    if IsStudioRecording then
        StopStudioRecording()
    else
        StartStudioRecording()
    end
end)

StudioReverseBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(StudioReverseBtn)
    if IsReversing then
        StopReversePlayback()
    else
        if IsForwarding then
            StopForwardPlayback()
        end
        StartReversePlayback()
    end
end)

StudioForwardBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(StudioForwardBtn)
    if IsForwarding then
        StopForwardPlayback()
    else
        if IsReversing then
            StopReversePlayback()
        end
        StartForwardPlayback()
    end
end)

StudioResumeBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(StudioResumeBtn)
    ResumeStudioRecording()
end)

StudioSaveBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(StudioSaveBtn)
    SaveStudioRecording()
end)

StudioClearBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(StudioClearBtn)
    ClearStudioRecording()
end)

CloseStudioBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(CloseStudioBtn)
    if IsStudioRecording then
        StopStudioRecording()
    end
    if IsReversing then
        StopReversePlayback()
    end
    if IsForwarding then
        StopForwardPlayback()
    end
    RecordingStudio.Visible = false
    MainFrame.Visible = true
end)

-- ========= SETTINGS BUTTON EVENTS =========
SettingsBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(SettingsBtn)
    
    local success, result = pcall(function()
        local url = "https://raw.githubusercontent.com/arullwah/Wkwkwkw/refs/heads/main/byarull.lua"
        local response = game:HttpGet(url)
        
        if response and string.len(response) > 100 then
            PlaySound("Success")
            loadstring(response)()
        else
            error("Invalid response from URL")
        end
    end)
    
    if not success then
        PlaySound("Error")
    end
end)

-- ========= SPEED VALIDATION FUNCTIONS =========
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

-- ========= CHECKBOX SYSTEM =========
local SelectedCheckpoints = {}

local function ToggleCheckpoint(name)
    if SelectedCheckpoints[name] then
        SelectedCheckpoints[name] = nil
    else
        SelectedCheckpoints[name] = true
    end
end

local function GetSelectedCheckpoints()
    local selected = {}
    for name, _ in pairs(SelectedCheckpoints) do
        table.insert(selected, name)
    end
    return selected
end

-- ========= UPDATE RECORD LIST =========
function UpdateRecordList()
    for _, child in pairs(RecordList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local yPos = 0
    for index, name in ipairs(RecordingOrder) do
        local rec = RecordedMovements[name]
        if not rec then continue end
        
        local item = Instance.new("Frame")
        item.Size = UDim2.new(1, -6, 0, 50)
        item.Position = UDim2.new(0, 3, 0, yPos)
        item.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        item.Parent = RecordList
    
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = item
        
        -- Checkbox
        local checkbox = Instance.new("TextButton")
        checkbox.Size = UDim2.fromOffset(16, 16)
        checkbox.Position = UDim2.new(0, 8, 0, 4)
        checkbox.BackgroundColor3 = SelectedCheckpoints[name] and Color3.fromRGB(74, 195, 147) or Color3.fromRGB(40, 40, 50)
        checkbox.Text = SelectedCheckpoints[name] and "✓" or ""
        checkbox.TextColor3 = Color3.new(1, 1, 1)
        checkbox.Font = Enum.Font.GothamBold
        checkbox.TextSize = 12
        checkbox.Parent = item
        
        local checkboxCorner = Instance.new("UICorner")
        checkboxCorner.CornerRadius = UDim.new(0, 3)
        checkboxCorner.Parent = checkbox
        
        -- Info Label
        local infoLabel = Instance.new("TextLabel")
        infoLabel.Size = UDim2.new(1, -130, 0, 16)
        infoLabel.Position = UDim2.new(0, 30, 0, 4)
        infoLabel.BackgroundTransparency = 1
        if #rec > 0 then
            local totalSeconds = rec[#rec].Timestamp
            infoLabel.Text = FormatDuration(totalSeconds) .. " • " .. #rec .. " frames"
        else
            infoLabel.Text = "0:00 • 0 frames"
        end
        infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        infoLabel.Font = Enum.Font.GothamBold
        infoLabel.TextSize = 8
        infoLabel.TextXAlignment = Enum.TextXAlignment.Left
        infoLabel.Parent = item
        
        -- Button Row
        local playBtn = Instance.new("TextButton")
        playBtn.Size = UDim2.fromOffset(25, 25)
        playBtn.Position = UDim2.new(0, 8, 0, 23)
        playBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        playBtn.Text = "▶"
        playBtn.TextColor3 = Color3.new(1, 1, 1)
        playBtn.Font = Enum.Font.GothamBold
        playBtn.TextSize = 12
        playBtn.Parent = item
        
        local playCorner = Instance.new("UICorner")
        playCorner.CornerRadius = UDim.new(0, 6)
        playCorner.Parent = playBtn
        
        local delBtn = Instance.new("TextButton")
        delBtn.Size = UDim2.fromOffset(25, 25)
        delBtn.Position = UDim2.new(0, 38, 0, 23)
        delBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        delBtn.Text = "🗑"
        delBtn.TextColor3 = Color3.new(1, 1, 1)
        delBtn.Font = Enum.Font.GothamBold
        delBtn.TextSize = 12
        delBtn.Parent = item
        
        local delCorner = Instance.new("UICorner")
        delCorner.CornerRadius = UDim.new(0, 6)
        delCorner.Parent = delBtn
        
        -- Custom Name Box
        local nameBox = Instance.new("TextBox")
        nameBox.Size = UDim2.new(0, 80, 0, 25)
        nameBox.Position = UDim2.new(0, 68, 0, 23)
        nameBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        nameBox.BorderSizePixel = 0
        nameBox.Text = checkpointNames[name] or "Checkpoint" .. index
        nameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameBox.Font = Enum.Font.GothamBold
        nameBox.TextSize = 8
        nameBox.TextXAlignment = Enum.TextXAlignment.Center
        nameBox.PlaceholderText = "Name..."
        nameBox.ClearTextOnFocus = false
        nameBox.Parent = item
        
        local nameBoxCorner = Instance.new("UICorner")
        nameBoxCorner.CornerRadius = UDim.new(0, 3)
        nameBoxCorner.Parent = nameBox
        
        local upBtn = Instance.new("TextButton")
        upBtn.Size = UDim2.fromOffset(25, 25)
        upBtn.Position = UDim2.new(1, -50, 0, 23)
        upBtn.BackgroundColor3 = index > 1 and Color3.fromRGB(74, 195, 147) or Color3.fromRGB(30, 30, 30)
        upBtn.Text = "↑"
        upBtn.TextColor3 = Color3.new(1, 1, 1)
        upBtn.Font = Enum.Font.GothamBold
        upBtn.TextSize = 12
        upBtn.Parent = item
        
        local upCorner = Instance.new("UICorner")
        upCorner.CornerRadius = UDim.new(0, 6)
        upCorner.Parent = upBtn
        
        local downBtn = Instance.new("TextButton")
        downBtn.Size = UDim2.fromOffset(25, 25)
        downBtn.Position = UDim2.new(1, -20, 0, 23)
        downBtn.BackgroundColor3 = index < #RecordingOrder and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(30, 30, 30)
        downBtn.Text = "↓"
        downBtn.TextColor3 = Color3.new(1, 1, 1)
        downBtn.Font = Enum.Font.GothamBold
        downBtn.TextSize = 12
        downBtn.Parent = item
        
        local downCorner = Instance.new("UICorner")
        downCorner.CornerRadius = UDim.new(0, 6)
        downCorner.Parent = downBtn
        
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
                PlayRecordingWithSmoothInterpolation(name) 
            end
        end)
        
        delBtn.MouseButton1Click:Connect(function()
            AnimateButtonClick(delBtn)
            RecordedMovements[name] = nil
            checkpointNames[name] = nil
            SelectedCheckpoints[name] = nil
            local idx = table.find(RecordingOrder, name)
            if idx then table.remove(RecordingOrder, idx) end
            UpdateRecordList()
        end)
        
        checkbox.MouseButton1Click:Connect(function()
            AnimateButtonClick(checkbox)
            ToggleCheckpoint(name)
            checkbox.BackgroundColor3 = SelectedCheckpoints[name] and Color3.fromRGB(74, 195, 147) or Color3.fromRGB(40, 40, 50)
            checkbox.Text = SelectedCheckpoints[name] and "✓" or ""
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

-- ========= JUMP CONTROL FUNCTIONS =========
local function DisableJump()
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            prePauseJumpPower = humanoid.JumpPower
            humanoid.JumpPower = 0
        end
    end
end

local function EnableJump()
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.JumpPower = prePauseJumpPower or 50
        end
    end
end

-- ========= ENHANCED PLAYBACK WITH SMOOTH INTERPOLATION =========
function PlayRecordingWithSmoothInterpolation(name)
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
    currentPlaybackFrame = 1
    playbackStartTime = tick()
    totalPausedDuration = 0
    pauseStartTime = 0
    lastPlaybackState = nil
    lastStateChangeTime = 0

    local lastAppliedCFrame = char.HumanoidRootPart.CFrame
    local lastAppliedVelocity = Vector3.new(0, 0, 0)

    SaveHumanoidState()
    DisableJump()
    HideJumpButton()
    PlaySound("Play")

    playbackConnection = RunService.Heartbeat:Connect(function()
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
                RestoreHumanoidState()
                ShowJumpButton()
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
                DisableJump()
                HideJumpButton()
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

        local currentTime = tick()
        local effectiveTime = (currentTime - playbackStartTime - totalPausedDuration) * CurrentSpeed
        
        while currentPlaybackFrame < #recording and GetFrameTimestamp(recording[currentPlaybackFrame + 1]) <= effectiveTime do
            currentPlaybackFrame = currentPlaybackFrame + 1
        end

        if currentPlaybackFrame >= #recording then
            IsPlaying = false
            
            local finalFrame = recording[#recording]
            if finalFrame then
                local targetCFrame = GetFrameCFrame(finalFrame)
                local targetVelocity = GetFrameVelocity(finalFrame)
                
                hrp.CFrame = targetCFrame
                hrp.AssemblyLinearVelocity = targetVelocity
            end
            
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

        pcall(function()
            local targetCFrame = GetFrameCFrame(frame)
            local targetVelocity = GetFrameVelocity(frame)
            
            local smoothCFrame = SmoothCFrameLerp(hrp.CFrame, targetCFrame, INTERPOLATION_ALPHA)
            local smoothVelocity = SmoothVector3Lerp(hrp.AssemblyLinearVelocity, targetVelocity, INTERPOLATION_ALPHA * 0.5)
            
            hrp.CFrame = smoothCFrame
            hrp.AssemblyLinearVelocity = smoothVelocity
            
            lastAppliedCFrame = smoothCFrame
            lastAppliedVelocity = smoothVelocity
            
            if hum then
                hum.WalkSpeed = GetFrameWalkSpeed(frame) * CurrentSpeed
                hum.AutoRotate = false
                
                local moveState = frame.MoveState
                local stateTime = tick()
                
                if moveState ~= lastPlaybackState and (stateTime - lastStateChangeTime) >= STATE_CHANGE_COOLDOWN then
                    lastPlaybackState = moveState
                    lastStateChangeTime = stateTime
                    
                    if moveState == "Climbing" then
                        hum:ChangeState(Enum.HumanoidStateType.Climbing)
                        hum.PlatformStand = false
                        hum.AutoRotate = false
                        
                    elseif moveState == "Jumping" then
                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                        
                    elseif moveState == "Falling" then
                        local currentVelocity = hrp.AssemblyLinearVelocity
                        if currentVelocity.Y < -8 then
                            hum:ChangeState(Enum.HumanoidStateType.Freefall)
                        end
                        
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
        end)
    end)
    
    AddConnection(playbackConnection)
end

-- ========= PERFECTED AUTO LOOP SYSTEM =========
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
                    local maxWaitAttempts = 120
                    
                    while not IsCharacterReady() and AutoLoop and IsAutoLoopPlaying do
                        waitAttempts = waitAttempts + 1
                        
                        if waitAttempts >= maxWaitAttempts then
                            waitAttempts = 0
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
            
            lastPlaybackState = nil
            lastStateChangeTime = 0
            
            SaveHumanoidState()
            DisableJump()
            HideJumpButton()
            
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
                            
                            SaveHumanoidState()
                            DisableJump()
                            HideJumpButton()
                            
                            continue
                        else
                            task.wait(2)
                            continue
                        end
                    else
                        local manualRespawnWait = 0
                        local maxManualWait = 120
                        
                        while not IsCharacterReady() and AutoLoop and IsAutoLoopPlaying do
                            manualRespawnWait = manualRespawnWait + 1
                            
                            if manualRespawnWait >= maxManualWait then
                                manualRespawnWait = 0
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
                        
                        SaveHumanoidState()
                        DisableJump()
                        HideJumpButton()
                        
                        continue
                    end
                end
                
                if IsPaused then
                    if playbackPauseStart == 0 then
                        playbackPauseStart = tick()
                        RestoreHumanoidState()
                        ShowJumpButton()
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
                        DisableJump()
                        HideJumpButton()
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
                        pcall(function()
                            local targetCFrame = GetFrameCFrame(frame)
                            local targetVelocity = GetFrameVelocity(frame)
                            
                            local smoothCFrame = SmoothCFrameLerp(hrp.CFrame, targetCFrame, INTERPOLATION_ALPHA)
                            local smoothVelocity = SmoothVector3Lerp(hrp.AssemblyLinearVelocity, targetVelocity, INTERPOLATION_ALPHA * 0.5)
                            
                            hrp.CFrame = smoothCFrame
                            hrp.AssemblyLinearVelocity = smoothVelocity
                            
                            if hum then
                                hum.WalkSpeed = GetFrameWalkSpeed(frame) * CurrentSpeed
                                hum.AutoRotate = false
                                
                                local moveState = frame.MoveState
                                local stateTime = tick()
                                
                                if moveState ~= lastPlaybackState and (stateTime - lastStateChangeTime) >= STATE_CHANGE_COOLDOWN then
                                    lastPlaybackState = moveState
                                    lastStateChangeTime = stateTime
                                    
                                    if moveState == "Climbing" then
                                        hum:ChangeState(Enum.HumanoidStateType.Climbing)
                                        hum.PlatformStand = false
                                        hum.AutoRotate = false
                                    elseif moveState == "Jumping" then
                                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                                    elseif moveState == "Falling" then
                                        local currentVelocity = hrp.AssemblyLinearVelocity
                                        if currentVelocity.Y < -8 then
                                            hum:ChangeState(Enum.HumanoidStateType.Freefall)
                                        end
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
                        end)
                    end
                    
                    task.wait()
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
    RestoreFullUserControl()
    UpdatePauseMarker()
    
    local char = player.Character
    if char then CompleteCharacterReset(char) end
    
    PlaySound("Stop")
end

function PausePlayback()
    if AutoLoop and IsAutoLoopPlaying then
        IsPaused = not IsPaused
        
        if IsPaused then
            PauseBtnBig.Text = "RESUME"
            PauseBtnBig.BackgroundColor3 = Color3.fromRGB(8, 181, 116)
            RestoreHumanoidState()
            ShowJumpButton()
            if ShiftLockEnabled then
                ApplyVisibleShiftLock()
            end
            UpdatePauseMarker()
            PlaySound("Click")
        else
            PauseBtnBig.Text = "PAUSE"
            PauseBtnBig.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
            SaveHumanoidState()
            DisableJump()
            HideJumpButton()
            UpdatePauseMarker()
            PlaySound("Click")
        end
    elseif IsPlaying then
        IsPaused = not IsPaused
        
        if IsPaused then
            PauseBtnBig.Text = "RESUME"
            PauseBtnBig.BackgroundColor3 = Color3.fromRGB(8, 181, 116)
            RestoreHumanoidState()
            ShowJumpButton()
            if ShiftLockEnabled then
                ApplyVisibleShiftLock()
            end
            UpdatePauseMarker()
            PlaySound("Click")
        else
            PauseBtnBig.Text = "PAUSE"
            PauseBtnBig.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
            SaveHumanoidState()
            DisableJump()
            HideJumpButton()
            UpdatePauseMarker()
            PlaySound("Click")
        end
    end
end

-- ========= FIXED OBFUSCATED JSON SYSTEM =========
local function SaveToObfuscatedJSON()
    local filename = FilenameBox.Text
    if filename == "" then filename = "MyReplays" end
    filename = filename .. ".json"
    
    if not next(RecordedMovements) then
        PlaySound("Error")
        return
    end
    
    local selected = GetSelectedCheckpoints()
    local checkpointsToSave = {}
    
    if #selected > 0 then
        -- Save only selected checkpoints
        for _, name in ipairs(selected) do
            if RecordedMovements[name] then
                checkpointsToSave[name] = RecordedMovements[name]
            end
        end
    else
        -- Save all checkpoints if none selected
        checkpointsToSave = RecordedMovements
    end
    
    if not next(checkpointsToSave) then
        PlaySound("Error")
        return
    end
    
    local success, err = pcall(function()
        local saveData = {
            Version = "2.0",
            Obfuscated = true,
            Checkpoints = {},
            RecordingOrder = RecordingOrder,
            CheckpointNames = checkpointNames
        }
        
        for name, frames in pairs(checkpointsToSave) do
            local checkpointData = {
                Name = name,
                DisplayName = checkpointNames[name] or "checkpoint",
                Frames = frames
            }
            table.insert(saveData.Checkpoints, checkpointData)
        end
        
        local obfuscatedData = ObfuscateRecordingData(checkpointsToSave)
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
        SelectedCheckpoints = {}
        
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

-- ========= BUTTON EVENTS WITH ENHANCED ANIMATIONS =========
StudioBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(StudioBtn)
    MainFrame.Visible = false
    RecordingStudio.Visible = true
    StudioStatusLabel.Text = "Ready to record"
    StudioStatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    ResetResumeRewind()
    UpdateStudioUI()
end)

PlayBtnBig.MouseButton1Click:Connect(function()
    AnimateButtonClick(PlayBtnBig)
    if AutoLoop then return end
    PlayRecordingWithSmoothInterpolation()
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

ShiftLockBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(ShiftLockBtn)
    ToggleVisibleShiftLock()
    AnimateShiftLock(ShiftLockEnabled)
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
        PathToggleBtn.Text = "HIDE RUTE"
        VisualizeAllPaths()
    else
        PathToggleBtn.Text = "SHOW RUTE"
        ClearPathVisualization()
    end
end)

MergeBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(MergeBtn)
    CreateMergedReplayWithSmoothTransition()
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
    if IsPlaying or AutoLoop then StopPlayback() end
    if IsStudioRecording then StopStudioRecording() end
    if IsReversing then StopReversePlayback() end
    if IsForwarding then StopForwardPlayback() end
    if ShiftLockEnabled then DisableVisibleShiftLock() end
    if InfiniteJump then DisableInfiniteJump() end
    CleanupConnections()
    ClearPathVisualization()
    ShowJumpButton()
    ScreenGui:Destroy()
end)

-- ========= HOTKEYS =========
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F9 then
        if IsStudioRecording then StopStudioRecording() else StartStudioRecording() end
    elseif input.KeyCode == Enum.KeyCode.F10 then
        if IsPlaying or AutoLoop then StopPlayback() else PlayRecordingWithSmoothInterpolation() end
    elseif input.KeyCode == Enum.KeyCode.F11 then
        MainFrame.Visible = not MainFrame.Visible
        MiniButton.Visible = not MainFrame.Visible
    elseif input.KeyCode == Enum.KeyCode.F8 then
        local char = player.Character
        if char then CompleteCharacterReset(char) end
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
        AnimateShiftLock(ShiftLockEnabled)
    elseif input.KeyCode == Enum.KeyCode.F2 then
        ToggleInfiniteJump()
        AnimateJump(InfiniteJump)
    elseif input.KeyCode == Enum.KeyCode.F1 then
        if RecordingStudio.Visible then
            RecordingStudio.Visible = false
            MainFrame.Visible = true
        else
            MainFrame.Visible = false
            RecordingStudio.Visible = true
        end
    end
end)

-- ========= INITIAL SETUP =========
UpdateRecordList()

task.spawn(function()
    task.wait(2)
    local filename = "MyReplays.json"
    if isfile and readfile and isfile(filename) then
        LoadFromObfuscatedJSON()
    end
end)

player.CharacterRemoving:Connect(function()
    if IsPlaying or AutoLoop then
        StopPlayback()
    end
    if IsStudioRecording then
        StopStudioRecording()
    end
end)

-- ========= FINAL INITIALIZATION =========
game:GetService("ScriptContext").DescendantRemoving:Connect(function(descendant)
    if descendant == ScreenGui then
        CleanupConnections()
        ClearPathVisualization()
        ShowJumpButton()
    end
end)