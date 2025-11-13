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

-- ========= CONFIGURATION =========
local RECORDING_FPS = 60
local MAX_FRAMES = 30000
local MIN_DISTANCE_THRESHOLD = 0.015
local VELOCITY_SCALE = 1
local VELOCITY_Y_SCALE = 1
local REVERSE_SPEED_MULTIPLIER = 1.0
local FORWARD_SPEED_MULTIPLIER = 1.0
local REVERSE_FRAME_STEP = 1
local FORWARD_FRAME_STEP = 1
local TIMELINE_STEP_SECONDS = 0.1
local STATE_CHANGE_COOLDOWN = 0.05
local TRANSITION_FRAMES = 5
local RESUME_DISTANCE_THRESHOLD = 40
local PLAYBACK_FIXED_TIMESTEP = 1 / 60 -- 60 FPS fixed untuk playback

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
local LastPauseFrame = 0

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

local function ApplyVisibleShiftLock()
    if not ShiftLockEnabled or not player.Character then return end
    pcall(function()
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
    end)
end

local function EnableVisibleShiftLock()
    if shiftLockConnection or not ShiftLockEnabled then return end
    pcall(function()
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
    end)
end

local function DisableVisibleShiftLock()
    pcall(function()
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
    end)
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
        end
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
        if ShiftLockEnabled then
            EnableVisibleShiftLock()
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
        for _, checkpointName in ipairs(RecordingOrder) do
            if not CheckedRecordings[checkpointName] then continue end
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
    end)
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

-- ========= FITUR BARU: Auto-deteksi Recording Terdekat =========
local function FindNearestRecording(maxDistance)
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        return nil, math.huge
    end
    
    local currentPos = char.HumanoidRootPart.Position
    local nearestRecording = nil
    local nearestDistance = math.huge
    local nearestFrame = 1
    
    for _, name in ipairs(RecordingOrder) do
        local recording = RecordedMovements[name]
        if recording and #recording > 0 then
            local frame, distance = FindNearestFrame(recording, currentPos)
            if distance < nearestDistance then
                nearestDistance = distance
                nearestRecording = name
                nearestFrame = frame
            end
        end
    end
    
    if nearestDistance <= (maxDistance or RESUME_DISTANCE_THRESHOLD) then
        return nearestRecording, nearestDistance, nearestFrame
    end
    
    return nil, nearestDistance, 1
end

-- ========= ELEGANT GUI SETUP =========
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ByaruLRecorderElegant"
ScreenGui.ResetOnSpawn = false
if player:FindFirstChild("PlayerGui") then
    ScreenGui.Parent = player.PlayerGui
else
    wait(2)
    ScreenGui.Parent = player:WaitForChild("PlayerGui")
end

-- ========= MAIN ELEGANT FRAME =========
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.fromOffset(300, 320)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -160)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

-- Header dengan title dan window controls
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 32)
Header.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 8)
HeaderCorner.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -60, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "ByaruL Recorder"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.fromOffset(20, 20)
MinimizeBtn.Position = UDim2.new(1, -45, 0.5, -10)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
MinimizeBtn.Text = "_"
MinimizeBtn.TextColor3 = Color3.new(1, 1, 1)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 14
MinimizeBtn.Parent = Header

local MinimizeCorner = Instance.new("UICorner")
MinimizeCorner.CornerRadius = UDim.new(0, 4)
MinimizeCorner.Parent = MinimizeBtn

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

-- Content Area
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -6, 1, -38)
Content.Position = UDim2.new(0, 3, 0, 36)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

-- ========= CONTROL BUTTONS SECTION =========
local ControlSection = Instance.new("Frame")
ControlSection.Size = UDim2.new(1, 0, 0, 30)
ControlSection.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
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

local PlayBtn = CreateControlBtn("PLAY", 0, 95, Color3.fromRGB(59, 15, 116))
local RecordBtn = CreateControlBtn("REC", 100, 95, Color3.fromRGB(200, 50, 60))
local MenuBtn = CreateControlBtn("MENU", 200, 95, Color3.fromRGB(70, 70, 90))

-- ========= SAVE SETTINGS SECTION =========
local SaveSection = Instance.new("Frame")
SaveSection.Size = UDim2.new(1, 0, 0, 80)
SaveSection.Position = UDim2.new(0, 0, 0, 40)
SaveSection.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
SaveSection.BorderSizePixel = 0
SaveSection.Parent = Content

local SaveCorner = Instance.new("UICorner")
SaveCorner.CornerRadius = UDim.new(0, 6)
SaveCorner.Parent = SaveSection

local SaveHeader = Instance.new("TextLabel")
SaveHeader.Size = UDim2.new(1, -6, 0, 20)
SaveHeader.Position = UDim2.new(0, 3, 0, 3)
SaveHeader.BackgroundTransparency = 1
SaveHeader.Text = "Save Settings"
SaveHeader.TextColor3 = Color3.fromRGB(255, 255, 255)
SaveHeader.Font = Enum.Font.GothamBold
SaveHeader.TextSize = 12
SaveHeader.TextXAlignment = Enum.TextXAlignment.Left
SaveHeader.Parent = SaveSection

local FilenameBox = Instance.new("TextBox")
FilenameBox.Size = UDim2.new(1, -6, 0, 22)
FilenameBox.Position = UDim2.new(0, 3, 0, 26)
FilenameBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
FilenameBox.BorderSizePixel = 0
FilenameBox.Text = "MyReplays"
FilenameBox.PlaceholderText = "Filename"
FilenameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
FilenameBox.Font = Enum.Font.Gotham
FilenameBox.TextSize = 11
FilenameBox.TextXAlignment = Enum.TextXAlignment.Center
FilenameBox.ClearTextOnFocus = false
FilenameBox.Parent = SaveSection

local FilenameCorner = Instance.new("UICorner")
FilenameCorner.CornerRadius = UDim.new(0, 4)
FilenameCorner.Parent = FilenameBox

local SaveButtons = Instance.new("Frame")
SaveButtons.Size = UDim2.new(1, -6, 0, 22)
SaveButtons.Position = UDim2.new(0, 3, 0, 53)
SaveButtons.BackgroundTransparency = 1
SaveButtons.Parent = SaveSection

local SaveFileBtn = CreateControlBtn("SAVE", 0, 95, Color3.fromRGB(59, 15, 116))
SaveFileBtn.Parent = SaveButtons
local LoadFileBtn = CreateControlBtn("LOAD", 100, 95, Color3.fromRGB(59, 15, 116))
LoadFileBtn.Parent = SaveButtons
local MergeBtn = CreateControlBtn("MERGE", 200, 95, Color3.fromRGB(59, 15, 116))
MergeBtn.Parent = SaveButtons

-- ========= RECORDINGS LIST SECTION =========
local RecordingsSection = Instance.new("Frame")
RecordingsSection.Size = UDim2.new(1, 0, 0, 150)
RecordingsSection.Position = UDim2.new(0, 0, 0, 130)
RecordingsSection.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
RecordingsSection.BorderSizePixel = 0
RecordingsSection.Parent = Content

local RecordingsCorner = Instance.new("UICorner")
RecordingsCorner.CornerRadius = UDim.new(0, 6)
RecordingsCorner.Parent = RecordingsSection

local RecordingsHeader = Instance.new("TextLabel")
RecordingsHeader.Size = UDim2.new(1, -6, 0, 20)
RecordingsHeader.Position = UDim2.new(0, 3, 0, 3)
RecordingsHeader.BackgroundTransparency = 1
RecordingsHeader.Text = "Recordings (0)"
RecordingsHeader.TextColor3 = Color3.fromRGB(255, 255, 255)
RecordingsHeader.Font = Enum.Font.GothamBold
RecordingsHeader.TextSize = 12
RecordingsHeader.TextXAlignment = Enum.TextXAlignment.Left
RecordingsHeader.Parent = RecordingsSection

local RecordingsList = Instance.new("ScrollingFrame")
RecordingsList.Size = UDim2.new(1, -6, 1, -26)
RecordingsList.Position = UDim2.new(0, 3, 0, 23)
RecordingsList.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
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

-- ========= MINIMIZED BUTTON =========
local MiniButton = Instance.new("TextButton")
MiniButton.Size = UDim2.fromOffset(50, 50)
MiniButton.Position = UDim2.new(0, 10, 0, 10)
MiniButton.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
MiniButton.Text = "🎮"
MiniButton.TextColor3 = Color3.new(1, 1, 1)
MiniButton.Font = Enum.Font.GothamBold
MiniButton.TextSize = 20
MiniButton.Visible = false
MiniButton.Active = true
MiniButton.Draggable = true
MiniButton.Parent = ScreenGui

local MiniCorner = Instance.new("UICorner")
MiniCorner.CornerRadius = UDim.new(0, 8)
MiniCorner.Parent = MiniButton

-- ========= PLAYBACK CONTROL GUI (FIXED LAYOUT) =========
local PlaybackControl = Instance.new("Frame")
PlaybackControl.Size = UDim2.fromOffset(156, 130)
PlaybackControl.Position = UDim2.new(0.5, -78, 0.5, -65)
PlaybackControl.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
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

-- Playback Control Buttons dengan spacing 3px yang PERFECT
local PlayBtnControl = CreatePlaybackBtn("PLAY", 3, 3, 138, 25, Color3.fromRGB(59, 15, 116))

-- Row 2: Toggle buttons dengan spacing 3px
local LoopBtnControl = CreatePlaybackBtn("Loop OFF", 3, 31, 69, 20, Color3.fromRGB(80, 80, 80))
local JumpBtnControl = CreatePlaybackBtn("Jump OFF", 75, 31, 69, 20, Color3.fromRGB(80, 80, 80))

-- Row 3
local RespawnBtnControl = CreatePlaybackBtn("Respawn OFF", 3, 54, 69, 20, Color3.fromRGB(80, 80, 80))
local ShiftLockBtnControl = CreatePlaybackBtn("Shift OFF", 75, 54, 69, 20, Color3.fromRGB(80, 80, 80))

-- Row 4
local ResetBtnControl = CreatePlaybackBtn("Reset OFF", 3, 77, 69, 20, Color3.fromRGB(80, 80, 80))
local ShowRuteBtnControl = CreatePlaybackBtn("Path OFF", 75, 77, 69, 20, Color3.fromRGB(80, 80, 80))

-- Row 5: Info label
local PlaybackInfo = Instance.new("TextLabel")
PlaybackInfo.Size = UDim2.new(1, -6, 0, 20)
PlaybackInfo.Position = UDim2.fromOffset(3, 100)
PlaybackInfo.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
PlaybackInfo.BorderSizePixel = 0
PlaybackInfo.Text = "Ready"
PlaybackInfo.TextColor3 = Color3.fromRGB(100, 255, 150)
PlaybackInfo.Font = Enum.Font.GothamBold
PlaybackInfo.TextSize = 9
PlaybackInfo.Parent = PlaybackContent

local InfoCorner = Instance.new("UICorner")
InfoCorner.CornerRadius = UDim.new(0, 4)
InfoCorner.Parent = PlaybackInfo

-- ========= RECORDING STUDIO GUI (FIXED LAYOUT) =========
local RecordingStudio = Instance.new("Frame")
RecordingStudio.Size = UDim2.fromOffset(156, 130)
RecordingStudio.Position = UDim2.new(0.5, -78, 0.5, -65)
RecordingStudio.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
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

-- Row 1: Save & Record buttons dengan spacing 3px
local SaveBtn = CreateStudioBtn("SAVE", 3, 3, 69, 22, Color3.fromRGB(59, 15, 116))
local StartBtn = CreateStudioBtn("RECORD", 75, 3, 69, 22, Color3.fromRGB(200, 50, 60))

-- Row 2: Resume button (full width)
local ResumeBtn = CreateStudioBtn("RESUME", 3, 28, 144, 22, Color3.fromRGB(59, 15, 116))

-- Row 3: Prev & Next buttons
local PrevBtn = CreateStudioBtn("◀ PREV", 3, 53, 69, 22, Color3.fromRGB(59, 15, 116))
local NextBtn = CreateStudioBtn("NEXT ▶", 75, 53, 69, 22, Color3.fromRGB(59, 15, 116))

-- Row 4: Speed Controls
local SpeedBox = Instance.new("TextBox")
SpeedBox.Size = UDim2.fromOffset(69, 20)
SpeedBox.Position = UDim2.fromOffset(3, 78)
SpeedBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
SpeedBox.BorderSizePixel = 0
SpeedBox.Text = "1.00"
SpeedBox.PlaceholderText = "Speed"
SpeedBox.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedBox.Font = Enum.Font.GothamBold
SpeedBox.TextSize = 9
SpeedBox.TextXAlignment = Enum.TextXAlignment.Center
SpeedBox.ClearTextOnFocus = false
SpeedBox.Parent = StudioContent

local SpeedCorner = Instance.new("UICorner")
SpeedCorner.CornerRadius = UDim.new(0, 4)
SpeedCorner.Parent = SpeedBox

local WalkSpeedBox = Instance.new("TextBox")
WalkSpeedBox.Size = UDim2.fromOffset(69, 20)
WalkSpeedBox.Position = UDim2.fromOffset(75, 78)
WalkSpeedBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
WalkSpeedBox.BorderSizePixel = 0
WalkSpeedBox.Text = "16"
WalkSpeedBox.PlaceholderText = "WalkSpeed"
WalkSpeedBox.TextColor3 = Color3.fromRGB(255, 255, 255)
WalkSpeedBox.Font = Enum.Font.GothamBold
WalkSpeedBox.TextSize = 9
WalkSpeedBox.TextXAlignment = Enum.TextXAlignment.Center
WalkSpeedBox.ClearTextOnFocus = false
WalkSpeedBox.Parent = StudioContent

local WalkSpeedCorner = Instance.new("UICorner")
WalkSpeedCorner.CornerRadius = UDim.new(0, 4)
WalkSpeedCorner.Parent = WalkSpeedBox

-- Row 5: Info label
local StudioInfo = Instance.new("TextLabel")
StudioInfo.Size = UDim2.new(1, -6, 0, 20)
StudioInfo.Position = UDim2.fromOffset(3, 101)
StudioInfo.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
StudioInfo.BorderSizePixel = 0
StudioInfo.Text = "Frame: 0 | Timeline: Ready"
StudioInfo.TextColor3 = Color3.fromRGB(100, 255, 150)
StudioInfo.Font = Enum.Font.GothamBold
StudioInfo.TextSize = 8
StudioInfo.Parent = StudioContent

local StudioInfoCorner = Instance.new("UICorner")
StudioInfoCorner.CornerRadius = UDim.new(0, 4)
StudioInfoCorner.Parent = StudioInfo

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

-- ========= RECORDING LIST FUNCTIONS =========
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
            
            -- ✅ Height 95px
            local item = Instance.new("Frame")
            item.Size = UDim2.new(1, -6, 0, 95)
            item.Position = UDim2.new(0, 3, 0, yPos)
            item.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
            item.Parent = RecordingsList
        
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 4)
            corner.Parent = item
            
            -- Checkbox
            local checkBox = Instance.new("TextButton")
            checkBox.Size = UDim2.fromOffset(18, 18)
            checkBox.Position = UDim2.fromOffset(5, 5)
            checkBox.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
            checkBox.Text = CheckedRecordings[name] and "✓" or ""
            checkBox.TextColor3 = Color3.fromRGB(100, 255, 150)
            checkBox.Font = Enum.Font.GothamBold
            checkBox.TextSize = 12
            checkBox.Parent = item
            
            local checkCorner = Instance.new("UICorner")
            checkCorner.CornerRadius = UDim.new(0, 3)
            checkCorner.Parent = checkBox
            
            -- Name box
            local nameBox = Instance.new("TextBox")
            nameBox.Size = UDim2.new(1, -100, 0, 18)
            nameBox.Position = UDim2.fromOffset(28, 5)
            nameBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
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
            
            -- Info label
            local infoLabel = Instance.new("TextLabel")
            infoLabel.Size = UDim2.new(1, -100, 0, 14)
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
            
            -- ✅ BARIS 1: PLAY & DELETE (Posisi kanan atas)
            local playBtn = Instance.new("TextButton")
            playBtn.Size = UDim2.fromOffset(40, 20)
            playBtn.Position = UDim2.new(1, -85, 0, 5)
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
            delBtn.Size = UDim2.fromOffset(40, 20)
            delBtn.Position = UDim2.new(1, -40, 0, 5)
            delBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
            delBtn.Text = "Delete"
            delBtn.TextColor3 = Color3.new(1, 1, 1)
            delBtn.Font = Enum.Font.GothamBold
            delBtn.TextSize = 9
            delBtn.Parent = item
            
            local delCorner = Instance.new("UICorner")
            delCorner.CornerRadius = UDim.new(0, 3)
            delCorner.Parent = delBtn
            
            -- ✅ BARIS 2: NAIK & TURUN (ukuran sama dengan play/delete)
            local upBtn = Instance.new("TextButton")
            upBtn.Size = UDim2.fromOffset(40, 20)
            upBtn.Position = UDim2.new(1, -85, 0, 30)
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
            downBtn.Size = UDim2.fromOffset(40, 20)
            downBtn.Position = UDim2.new(1, -40, 0, 30)
            downBtn.BackgroundColor3 = index < #RecordingOrder and Color3.fromRGB(74, 195, 147) or Color3.fromRGB(60, 60, 70)
            downBtn.Text = "Turun"
            downBtn.TextColor3 = Color3.new(1, 1, 1)
            downBtn.Font = Enum.Font.GothamBold
            downBtn.TextSize = 9
            downBtn.Parent = item
            
            local downCorner = Instance.new("UICorner")
            downCorner.CornerRadius = UDim.new(0, 3)
            downCorner.Parent = downBtn
            
            -- Update recordings count
            RecordingsHeader.Text = "Recordings (" .. #RecordingOrder .. ")"
            
            -- ========= EVENT HANDLERS =========
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
                CheckedRecordings[name] = nil
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
            
            yPos = yPos + 100
        end
        
        RecordingsList.CanvasSize = UDim2.new(0, 0, 0, math.max(yPos, RecordingsList.AbsoluteSize.Y))
    end)
end

-- ========= STUDIO RECORDING FUNCTIONS =========
local function UpdateStudioUI()
    pcall(function()
        if StudioIsRecording then
            StudioInfo.Text = string.format("Frame: %d | Timeline: %s", 
                #StudioCurrentRecording.Frames, 
                IsTimelineMode and "PAUSED" or "RECORDING")
            StudioInfo.TextColor3 = IsTimelineMode and Color3.fromRGB(255, 200, 0) or Color3.fromRGB(100, 255, 150)
        else
            StudioInfo.Text = "Frame: 0 | Timeline: Ready"
            StudioInfo.TextColor3 = Color3.fromRGB(100, 255, 150)
        end
    end)
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
            
            StartBtn.Text = "STOP"
            StartBtn.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
            
            PlaySound("RecordStart")
            
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
                        table.insert(StudioCurrentRecording.Frames, {
                            Position = {cf.Position.X, cf.Position.Y, cf.Position.Z},
                            LookVector = {cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z},
                            UpVector = {cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z},
                            Velocity = {currentVelocity.X, currentVelocity.Y, currentVelocity.Z},
                            MoveState = GetCurrentMoveState(hum),
                            WalkSpeed = hum and hum.WalkSpeed or 16,
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
            
            StartBtn.Text = "RECORD"
            StartBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
            
            PlaySound("RecordStop")
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
            
            IsTimelineMode = false
            lastStudioRecordTime = tick()
            lastStudioRecordPos = hrp.Position
            
            if hum then
                hum.WalkSpeed = CurrentWalkSpeed
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
            
            RecordedMovements[StudioCurrentRecording.Name] = StudioCurrentRecording.Frames
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

-- ========= STUDIO BUTTON CONNECTIONS =========
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

-- ========= SAVE/LOAD SYSTEM =========
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

-- ========= PATH VISUALIZATION =========
local function VisualizeAllPaths()
    ClearPathVisualization()
    
    if not ShowPaths then return end
    
    pcall(function()
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
    end)
end

-- ========= IMPROVED PLAYBACK SYSTEM WITH SMART RESUME =========
function PlayRecording(name)
    if IsPlaying then return end
    
    local recording = name and RecordedMovements[name] or (RecordingOrder[1] and RecordedMovements[RecordingOrder[1]])
    if not recording or #recording == 0 then
        PlaySound("Error")
        return
    end
    
    pcall(function()
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
        
        -- Smart resume: cari frame terdekat dalam radius 40 studs
        local nearestFrame, distance = FindNearestFrame(recording, currentPos)
        
        if distance <= RESUME_DISTANCE_THRESHOLD then
            currentPlaybackFrame = nearestFrame
            playbackStartTime = tick() - (GetFrameTimestamp(recording[nearestFrame]) / CurrentSpeed)
            PlaybackInfo.Text = string.format("Resume @ Frame %d", nearestFrame)
            PlaybackInfo.TextColor3 = Color3.fromRGB(255, 200, 0)
        else
            currentPlaybackFrame = 1
            playbackStartTime = tick()
            hrp.CFrame = GetFrameCFrame(recording[1])
            PlaybackInfo.Text = "Playing from start"
            PlaybackInfo.TextColor3 = Color3.fromRGB(100, 255, 150)
        end
        
        totalPausedDuration = 0
        pauseStartTime = 0
        lastPlaybackState = nil
        lastStateChangeTime = 0

        SaveHumanoidState()
        PlaySound("Play")
        
        PlayBtnControl.Text = "STOP"
        PlayBtnControl.BackgroundColor3 = Color3.fromRGB(200, 50, 60)

        playbackConnection = RunService.Heartbeat:Connect(function(deltaTime)
            pcall(function()
                if not IsPlaying then
                    playbackConnection:Disconnect()
                    RestoreFullUserControl()
                    UpdatePauseMarker()
                    lastPlaybackState = nil
                    lastStateChangeTime = 0
                    PlayBtnControl.Text = "PLAY"
                    PlayBtnControl.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
                    PlaybackInfo.Text = "Stopped"
                    PlaybackInfo.TextColor3 = Color3.fromRGB(255, 100, 100)
                    return
                end

                local char = player.Character
                if not char or not char:FindFirstChild("HumanoidRootPart") then
                    IsPlaying = false
                    RestoreFullUserControl()
                    UpdatePauseMarker()
                    lastPlaybackState = nil
                    lastStateChangeTime = 0
                    PlayBtnControl.Text = "PLAY"
                    PlayBtnControl.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
                    PlaybackInfo.Text = "Character Missing"
                    PlaybackInfo.TextColor3 = Color3.fromRGB(255, 100, 100)
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
                    PlayBtnControl.Text = "PLAY"
                    PlayBtnControl.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
                    PlaybackInfo.Text = "Humanoid Missing"
                    PlaybackInfo.TextColor3 = Color3.fromRGB(255, 100, 100)
                    return
                end

                -- Fixed timestep implementation
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
                        PlayBtnControl.Text = "PLAY"
                        PlayBtnControl.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
                        PlaybackInfo.Text = "Completed"
                        PlaybackInfo.TextColor3 = Color3.fromRGB(100, 255, 150)
                        LastPausePosition = nil
                        LastPauseRecording = nil
                        LastPauseFrame = 0
                        return
                    end

                    local frame = recording[currentPlaybackFrame]
                    if not frame then
                        IsPlaying = false
                        RestoreFullUserControl()
                        UpdatePauseMarker()
                        lastPlaybackState = nil
                        lastStateChangeTime = 0
                        PlayBtnControl.Text = "PLAY"
                        PlayBtnControl.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
                        PlaybackInfo.Text = "Frame Error"
                        PlaybackInfo.TextColor3 = Color3.fromRGB(255, 100, 100)
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
                            elseif moveState == "Climbing" then
                                if moveState ~= lastPlaybackState and (stateTime - lastStateChangeTime) >= STATE_CHANGE_COOLDOWN then
                                    lastPlaybackState = moveState
                                    lastStateChangeTime = stateTime
                                    hum:ChangeState(Enum.HumanoidStateType.Climbing)
                                    hum.PlatformStand = false
                                    hum.AutoRotate = false
                                end
                            elseif moveState == "Swimming" then
                                if moveState ~= lastPlaybackState and (stateTime - lastStateChangeTime) >= STATE_CHANGE_COOLDOWN then
                                    lastPlaybackState = moveState
                                    lastStateChangeTime = stateTime
                                    hum:ChangeState(Enum.HumanoidStateType.Swimming)
                                end
                            else
                                if moveState ~= lastPlaybackState and (stateTime - lastStateChangeTime) >= STATE_CHANGE_COOLDOWN then
                                    lastPlaybackState = moveState
                                    lastStateChangeTime = stateTime
                                    hum:ChangeState(Enum.HumanoidStateType.Running)
                                end
                            end
                        end
                        
                        if ShiftLockEnabled then
                            ApplyVisibleShiftLock()
                        end
                        
                        -- Update info
                        local progress = math.floor((currentPlaybackFrame / #recording) * 100)
                        PlaybackInfo.Text = string.format("Frame %d/%d (%d%%)", currentPlaybackFrame, #recording, progress)
                        PlaybackInfo.TextColor3 = Color3.fromRGB(100, 255, 150)
                    end)
                end
            end)
        end)
        
        AddConnection(playbackConnection)
    end)
end

-- ========= IMPROVED AUTO LOOP SYSTEM =========
function StartAutoLoopAll()
    if not AutoLoop then return end
    
    if #RecordingOrder == 0 then
        AutoLoop = false
        LoopBtnControl.Text = "Loop OFF"
        LoopBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        PlaySound("Error")
        return
    end
    
    PlaySound("Play")
    
    -- Smart detection untuk mulai dari recording terdekat
    local nearestRecording, distance = FindNearestRecording(50)
    if nearestRecording then
        CurrentLoopIndex = table.find(RecordingOrder, nearestRecording) or 1
        PlaybackInfo.Text = string.format("Smart Loop @ %dm", math.floor(distance))
    else
        CurrentLoopIndex = 1
        PlaybackInfo.Text = "Auto Loop Active"
    end
    
    IsAutoLoopPlaying = true
    lastPlaybackState = nil
    lastStateChangeTime = 0
    
    PlayBtnControl.Text = "STOP"
    PlayBtnControl.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
    PlaybackInfo.TextColor3 = Color3.fromRGB(100, 255, 150)
    
    loopConnection = task.spawn(function()
        while AutoLoop and IsAutoLoopPlaying do
            pcall(function()
                if not AutoLoop or not IsAutoLoopPlaying then
                    return
                end
                
                local recordingName = RecordingOrder[CurrentLoopIndex]
                local recording = RecordedMovements[recordingName]
                
                if not recording or #recording == 0 then
                    CurrentLoopIndex = CurrentLoopIndex + 1
                    if CurrentLoopIndex > #RecordingOrder then
                        CurrentLoopIndex = 1
                    end
                    task.wait(1)
                    return
                end
                
                -- Tunggu karakter ready
                local waitAttempts = 0
                local maxWaitAttempts = 120
                
                while not IsCharacterReady() and AutoLoop and IsAutoLoopPlaying do
                    waitAttempts = waitAttempts + 1
                    
                    if AutoRespawn and waitAttempts > 10 then
                        ResetCharacter()
                        task.wait(2)
                    end
                    
                    if waitAttempts >= maxWaitAttempts then
                        AutoLoop = false
                        IsAutoLoopPlaying = false
                        LoopBtnControl.Text = "Loop OFF"
                        LoopBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                        PlaySound("Error")
                        break
                    end
                    
                    task.wait(0.5)
                end
                
                if not AutoLoop or not IsAutoLoopPlaying then return end
                
                local playbackCompleted = false
                local playbackStart = tick()
                local currentFrame = 1
                local deathRetryCount = 0
                local maxDeathRetries = 999999
                local loopAccumulator = 0
                
                lastPlaybackState = nil
                lastStateChangeTime = 0
                
                SaveHumanoidState()
                
                -- Smart resume: mulai dari frame terdekat
                local char = player.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    local currentPos = char.HumanoidRootPart.Position
                    local nearestFrame, frameDistance = FindNearestFrame(recording, currentPos)
                    if frameDistance <= 50 then
                        currentFrame = nearestFrame
                        playbackStart = tick() - (GetFrameTimestamp(recording[nearestFrame]) / CurrentSpeed)
                        PlaybackInfo.Text = string.format("Loop %d/%d @ %dm", CurrentLoopIndex, #RecordingOrder, math.floor(frameDistance))
                    else
                        PlaybackInfo.Text = string.format("Loop %d/%d", CurrentLoopIndex, #RecordingOrder)
                    end
                end
                
                while AutoLoop and IsAutoLoopPlaying and currentFrame <= #recording and deathRetryCount < maxDeathRetries do
                    pcall(function()
                        if not IsCharacterReady() then
                            deathRetryCount = deathRetryCount + 1
                            
                            if AutoRespawn then
                                ResetCharacter()
                                local success = WaitForRespawn()
                                
                                if success then
                                    RestoreFullUserControl()
                                    task.wait(1.5)
                                    
                                    -- Setelah respawn, cari frame terdekat untuk melanjutkan
                                    local char = player.Character
                                    if char and char:FindFirstChild("HumanoidRootPart") then
                                        local newNearestFrame, newDistance = FindNearestFrame(recording, char.HumanoidRootPart.Position)
                                        if newDistance <= 50 then
                                            currentFrame = newNearestFrame
                                            playbackStart = tick() - (GetFrameTimestamp(recording[newNearestFrame]) / CurrentSpeed)
                                        else
                                            currentFrame = 1
                                            playbackStart = tick()
                                        end
                                    else
                                        currentFrame = 1
                                        playbackStart = tick()
                                    end
                                    
                                    lastPlaybackState = nil
                                    lastStateChangeTime = 0
                                    loopAccumulator = 0
                                    
                                    SaveHumanoidState()
                                    
                                    return
                                else
                                    task.wait(2)
                                    return
                                end
                            else
                                local manualRespawnWait = 0
                                local maxManualWait = 60
                                
                                while not IsCharacterReady() and AutoLoop and IsAutoLoopPlaying do
                                    manualRespawnWait = manualRespawnWait + 1
                                    
                                    if manualRespawnWait >= maxManualWait then
                                        AutoLoop = false
                                        IsAutoLoopPlaying = false
                                        LoopBtnControl.Text = "Loop OFF"
                                        LoopBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                                        PlaySound("Error")
                                        break
                                    end
                                    
                                    task.wait(0.5)
                                end
                                
                                if not AutoLoop or not IsAutoLoopPlaying then return end
                                
                                RestoreFullUserControl()
                                task.wait(1.5)
                                
                                -- Setelah manual respawn, cari frame terdekat
                                local char = player.Character
                                if char and char:FindFirstChild("HumanoidRootPart") then
                                    local newNearestFrame, newDistance = FindNearestFrame(recording, char.HumanoidRootPart.Position)
                                    if newDistance <= 50 then
                                        currentFrame = newNearestFrame
                                        playbackStart = tick() - (GetFrameTimestamp(recording[newNearestFrame]) / CurrentSpeed)
                                    else
                                        currentFrame = 1
                                        playbackStart = tick()
                                    end
                                else
                                    currentFrame = 1
                                    playbackStart = tick()
                                end
                                
                                lastPlaybackState = nil
                                lastStateChangeTime = 0
                                loopAccumulator = 0
                                
                                SaveHumanoidState()
                                
                                return
                            end
                        end
                        
                        local char = player.Character
                        if not char or not char:FindFirstChild("HumanoidRootPart") then
                            task.wait(0.5)
                            return
                        end
                        
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        if not hum or not hrp then
                            task.wait(0.5)
                            return
                        end
                        
                        -- Fixed timestep for auto-loop
                        local deltaTime = task.wait()
                        loopAccumulator = loopAccumulator + deltaTime
                        
                        while loopAccumulator >= PLAYBACK_FIXED_TIMESTEP do
                            loopAccumulator = loopAccumulator - PLAYBACK_FIXED_TIMESTEP
                            
                            local currentTime = tick()
                            local effectiveTime = (currentTime - playbackStart) * CurrentSpeed
                            
                            while currentFrame < #recording and GetFrameTimestamp(recording[currentFrame + 1]) <= effectiveTime do
                                currentFrame = currentFrame + 1
                            end
                            
                            if currentFrame >= #recording then
                                playbackCompleted = true
                                break
                            end
                            
                            local frame = recording[currentFrame]
                            if frame then
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
                                        elseif moveState == "Climbing" then
                                            if moveState ~= lastPlaybackState and (stateTime - lastStateChangeTime) >= STATE_CHANGE_COOLDOWN then
                                                lastPlaybackState = moveState
                                                lastStateChangeTime = stateTime
                                                hum:ChangeState(Enum.HumanoidStateType.Climbing)
                                                hum.PlatformStand = false
                                                hum.AutoRotate = false
                                            end
                                        elseif moveState == "Swimming" then
                                            if moveState ~= lastPlaybackState and (stateTime - lastStateChangeTime) >= STATE_CHANGE_COOLDOWN then
                                                lastPlaybackState = moveState
                                                lastStateChangeTime = stateTime
                                                hum:ChangeState(Enum.HumanoidStateType.Swimming)
                                            end
                                        else
                                            if moveState ~= lastPlaybackState and (stateTime - lastStateChangeTime) >= STATE_CHANGE_COOLDOWN then
                                                lastPlaybackState = moveState
                                                lastStateChangeTime = stateTime
                                                hum:ChangeState(Enum.HumanoidStateType.Running)
                                            end
                                        end
                                    end
                    
                                    if ShiftLockEnabled then
                                        ApplyVisibleShiftLock()
                                    end
                                end)
                            end
                        end
                        
                        if playbackCompleted then
                            return
                        end
                    end)
                end
                
                RestoreFullUserControl()
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
                        return
                    else
                        -- Jika tidak completed (mati/error), tetap lanjut ke recording berikutnya
                        CurrentLoopIndex = CurrentLoopIndex + 1
                        if CurrentLoopIndex > #RecordingOrder then
                            CurrentLoopIndex = 1
                        end
                        task.wait(1)
                    end
                end
            end)
        end
        
        IsAutoLoopPlaying = false
        RestoreFullUserControl()
        lastPlaybackState = nil
        lastStateChangeTime = 0
        PlayBtnControl.Text = "PLAY"
        PlayBtnControl.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
        PlaybackInfo.Text = "Loop Stopped"
        PlaybackInfo.TextColor3 = Color3.fromRGB(255, 200, 0)
    end)
end

function StopAutoLoopAll()
    AutoLoop = false
    IsAutoLoopPlaying = false
    IsPlaying = false
    lastPlaybackState = nil
    lastStateChangeTime = 0
    
    if loopConnection then
        pcall(function() task.cancel(loopConnection) end)
        loopConnection = nil
    end
    
    RestoreFullUserControl()
    
    pcall(function()
        local char = player.Character
        if char then CompleteCharacterReset(char) end
    end)
    
    PlaySound("Stop")
    PlayBtnControl.Text = "PLAY"
    PlayBtnControl.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
    PlaybackInfo.Text = "Ready"
    PlaybackInfo.TextColor3 = Color3.fromRGB(100, 255, 150)
end

function StopPlayback()
    if AutoLoop then
        StopAutoLoopAll()
        LoopBtnControl.Text = "Loop OFF"
        LoopBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    end
    
    if not IsPlaying then return end
    
    pcall(function()
        IsPlaying = false
        lastPlaybackState = nil
        lastStateChangeTime = 0
        RestoreFullUserControl()
        
        local char = player.Character
        if char then CompleteCharacterReset(char) end
        
        PlaySound("Stop")
        PlayBtnControl.Text = "PLAY"
        PlayBtnControl.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
        PlaybackInfo.Text = "Stopped"
        PlaybackInfo.TextColor3 = Color3.fromRGB(255, 200, 0)
    end)
end

-- ========= PLAYBACK CONTROL BUTTONS =========
PlayBtnControl.MouseButton1Click:Connect(function()
    AnimateButtonClick(PlayBtnControl)
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

-- Toggle button functions
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
        VisualizeAllPaths()
    else
        ShowRuteBtnControl.Text = "Path OFF"
        ShowRuteBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        ClearPathVisualization()
    end
end)

-- ========= MAIN FRAME BUTTONS =========
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

MinimizeBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(MinimizeBtn)
    MainFrame.Visible = false
    MiniButton.Visible = true
end)

MiniButton.MouseButton1Click:Connect(function()
    AnimateButtonClick(MiniButton)
    MainFrame.Visible = true
    MiniButton.Visible = false
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
            task.wait(0.2)
            ScreenGui:Destroy()
        end)
    end)
end)

-- ========= INITIALIZATION =========
UpdateRecordList()

-- Auto-load dengan proteksi
if hasFileSystem then
    task.spawn(function()
        task.wait(2)
        pcall(function()
            local filename = "MyReplays.json"
            if isfile(filename) then
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
        if IsPlaying or AutoLoop then
            StopPlayback()
        end
    end)
end)

game:GetService("ScriptContext").DescendantRemoving:Connect(function(descendant)
    if descendant == ScreenGui then
        pcall(function()
            CleanupConnections()
            ClearPathVisualization()
        end)
    end
end)

-- Success notification
task.spawn(function()
    task.wait(1)
    PlaySound("Success")
    if PlaybackInfo then
        PlaybackInfo.Text = "✓ Script Loaded!"
        PlaybackInfo.TextColor3 = Color3.fromRGB(100, 255, 150)
    end
end)

print("✅ ByaruL Recorder v2.1 - Loaded Successfully!")
print("📌 Features: Smart Resume, Fixed Layout, File Protection")
print("🎮 Resume works within 40 studs radius!")
print("🔄 Improved Auto Loop System with Smart Detection!")