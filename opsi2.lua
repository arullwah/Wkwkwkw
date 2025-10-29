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
local MIN_DISTANCE_THRESHOLD = 0.01
local VELOCITY_SCALE = 1
local VELOCITY_Y_SCALE = 1

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
local RecordedMovements = {}
local RecordingOrder = {}
local CurrentRecording = {Frames = {}, StartTime = 0, Name = ""}
local AutoLoop = false
local AutoRespawn = false
local InfiniteJump = false
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
end

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
        humanoid.WalkSpeed = 16
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
        humanoid.WalkSpeed = 16
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

-- ========= IMPROVED MACRO/MERGE SYSTEM =========
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
            
            local transitionFrame = {
                Position = lastFrame.Position,
                LookVector = firstFrame.LookVector,
                UpVector = firstFrame.UpVector,
                Velocity = {0, 0, 0},
                MoveState = "Grounded",
                WalkSpeed = firstFrame.WalkSpeed,
                Timestamp = lastFrame.Timestamp + 0.05
            }
            table.insert(mergedFrames, transitionFrame)
            totalTimeOffset = totalTimeOffset + 0.05
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
            local pos2 = Vector3.new(frame.Position[1], frame.Position[2], frame.Position[2])
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

-- PERBAIKAN: MainFrame diperbesar untuk scroll yang lebih baik
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
Title.Text = "ByaruL"
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

local ResizeButton = Instance.new("TextButton")
ResizeButton.Size = UDim2.fromOffset(24, 24)
ResizeButton.Position = UDim2.new(1, -24, 1, -24)
ResizeButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
ResizeButton.Text = "↖️"
ResizeButton.TextColor3 = Color3.new(1, 1, 1)
ResizeButton.Font = Enum.Font.GothamBold
ResizeButton.TextSize = 20
ResizeButton.ZIndex = 2
ResizeButton.Parent = MainFrame

local ResizeCorner = Instance.new("UICorner")
ResizeCorner.CornerRadius = UDim.new(0, 8)
ResizeCorner.Parent = ResizeButton

-- PERBAIKAN: Content frame diperbesar untuk scroll yang lebih baik
local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, -10, 1, -42)
Content.Position = UDim2.new(0, 5, 0, 36)
Content.BackgroundTransparency = 1
Content.ScrollBarThickness = 6 -- Dipertebal scrollbar
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
-- Baris 1: Recording Button
local RecordBtnBig = CreateButton("RECORDING", 5, 5, 240, 30, Color3.fromRGB(59, 15, 116))

local PlayBtnBig = CreateButton("PLAY", 5, 40, 75, 30, Color3.fromRGB(59, 15, 116))
local StopBtnBig = CreateButton("STOP", 85, 40, 75, 30, Color3.fromRGB(59, 15, 116))
local PauseBtnBig = CreateButton("PAUSE", 165, 40, 75, 30, Color3.fromRGB(59, 15, 116))

-- Toggle layout: Kiri=AutoLoop, Tengah=InfiniteJump, Kanan=ShiftLock
local LoopBtn, AnimateLoop = CreateToggle("Auto Loop", 0, 75, 78, 22, false)
local JumpBtn, AnimateJump = CreateToggle("Infinite Jump", 82, 75, 78, 22, false)
local ShiftLockBtn, AnimateShiftLock = CreateToggle("ShiftLock", 164, 75, 78, 22, false)

-- Baris kedua: Auto Respawn
local RespawnBtn, AnimateRespawn = CreateToggle("Auto Respawn", 0, 102, 117, 22, false)

local FilenameBox = Instance.new("TextBox")
FilenameBox.Size = UDim2.fromOffset(117, 26)
FilenameBox.Position = UDim2.fromOffset(0, 129)
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

local SpeedBox = Instance.new("TextBox")
SpeedBox.Size = UDim2.fromOffset(117, 26)
SpeedBox.Position = UDim2.fromOffset(123, 129)
SpeedBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
SpeedBox.BorderSizePixel = 0
SpeedBox.Text = "1.00"
SpeedBox.PlaceholderText = "Speed (0.25-30)..."
SpeedBox.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedBox.Font = Enum.Font.GothamBold
SpeedBox.TextSize = 11
SpeedBox.TextXAlignment = Enum.TextXAlignment.Center
SpeedBox.ClearTextOnFocus = false
SpeedBox.Parent = Content

local SpeedCorner = Instance.new("UICorner")
SpeedCorner.CornerRadius = UDim.new(0, 6)
SpeedCorner.Parent = SpeedBox

local SaveFileBtn = CreateButton("SAVE FILE", 0, 160, 117, 26, Color3.fromRGB(59, 15, 116))
local LoadFileBtn = CreateButton("LOAD FILE", 123, 160, 117, 26, Color3.fromRGB(59, 15, 116))

local PathToggleBtn = CreateButton("RUTE", 0, 191, 117, 26, Color3.fromRGB(59, 15, 116))
local MergeBtn = CreateButton("MERGE", 123, 191, 117, 26, Color3.fromRGB(59, 15, 116))

-- PERBAIKAN: RecordList diperbesar dan diperbaiki scroll-nya
local RecordList = Instance.new("ScrollingFrame")
RecordList.Size = UDim2.new(1, 0, 0, 180) -- Diperbesar tinggi nya
RecordList.Position = UDim2.fromOffset(0, 222)
RecordList.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
RecordList.BorderSizePixel = 0
RecordList.ScrollBarThickness = 6 -- Dipertebal
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

-- ========= RESPONSIVE RESIZE FUNCTIONALITY =========
local IsResizing = false
local StartMousePos
local StartSize

ResizeButton.MouseButton1Down:Connect(function()
    IsResizing = true
    StartMousePos = UserInputService:GetMouseLocation()
    StartSize = MainFrame.Size
end)

UserInputService.TouchStarted:Connect(function(touch, processed)
    if processed then return end
    if touch and ResizeButton:IsDescendantOf(ScreenGui) then
        local touchPos = Vector2.new(touch.Position.X, touch.Position.Y)
        local framePos = MainFrame.AbsolutePosition
        local frameSize = MainFrame.AbsoluteSize
        
        if touchPos.X >= framePos.X + frameSize.X - 50 and 
           touchPos.Y >= framePos.Y + frameSize.Y - 50 then
            IsResizing = true
            StartMousePos = touchPos
            StartSize = MainFrame.Size
        end
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if IsResizing then
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local currentMousePos
            if input.UserInputType == Enum.UserInputType.Touch then
                currentMousePos = Vector2.new(input.Position.X, input.Position.Y)
            else
                currentMousePos = UserInputService:GetMouseLocation()
            end
            
            local delta = currentMousePos - StartMousePos
            
            local newWidth = math.clamp(StartSize.X.Offset + delta.X, 200, 400)
            local newHeight = math.clamp(StartSize.Y.Offset + delta.Y, 200, 600) -- Diperbesar max height
            
            MainFrame.Size = UDim2.fromOffset(newWidth, newHeight)
            
            local widthScale = newWidth / 250
            
            RecordBtnBig.Size = UDim2.fromOffset(240 * widthScale, 30)
            
            PlayBtnBig.Size = UDim2.fromOffset(75 * widthScale, 30)
            StopBtnBig.Size = UDim2.fromOffset(75 * widthScale, 30)
            PauseBtnBig.Size = UDim2.fromOffset(75 * widthScale, 30)
            
            StopBtnBig.Position = UDim2.fromOffset(5 + (75 * widthScale) + 5, 40)
            PauseBtnBig.Position = UDim2.fromOffset(5 + (75 * widthScale) * 2 + 10, 40)
            
            LoopBtn.Size = UDim2.fromOffset(78 * widthScale, 22)
            JumpBtn.Size = UDim2.fromOffset(78 * widthScale, 22)
            ShiftLockBtn.Size = UDim2.fromOffset(78 * widthScale, 22)
            
            JumpBtn.Position = UDim2.fromOffset(5 + (78 * widthScale) + 5, 75)
            ShiftLockBtn.Position = UDim2.fromOffset(5 + (78 * widthScale) * 2 + 10, 75)
            
            RespawnBtn.Size = UDim2.fromOffset(117 * widthScale, 22)
            
            FilenameBox.Size = UDim2.fromOffset(117 * widthScale, 26)
            SpeedBox.Size = UDim2.fromOffset(117 * widthScale, 26)
            SpeedBox.Position = UDim2.fromOffset(5 + (117 * widthScale) + 5, 129)
            
            SaveFileBtn.Size = UDim2.fromOffset(117 * widthScale, 26)
            LoadFileBtn.Size = UDim2.fromOffset(117 * widthScale, 26)
            LoadFileBtn.Position = UDim2.fromOffset(5 + (117 * widthScale) + 5, 160)
            
            PathToggleBtn.Size = UDim2.fromOffset(117 * widthScale, 26)
            MergeBtn.Size = UDim2.fromOffset(117 * widthScale, 26)
            MergeBtn.Position = UDim2.fromOffset(5 + (117 * widthScale) + 5, 191)
            
            -- Update RecordList size when resizing
            RecordList.Size = UDim2.new(1, 0, 0, 180 * (newHeight / 450))
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        IsResizing = false
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
        item.Size = UDim2.new(1, -6, 0, 40)
        item.Position = UDim2.new(0, 3, 0, yPos)
        item.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        item.Parent = RecordList
    
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = item
        
        -- PERBAIKAN: TextBox untuk custom nama dengan fungsi save yang benar
        local nameBox = Instance.new("TextBox")
        nameBox.Size = UDim2.new(1, -130, 0, 18)
        nameBox.Position = UDim2.new(0, 8, 0, 4)
        nameBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        nameBox.BorderSizePixel = 0
        nameBox.Text = checkpointNames[name] or "checkpoint_" .. index
        nameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameBox.Font = Enum.Font.GothamBold
        nameBox.TextSize = 10
        nameBox.TextXAlignment = Enum.TextXAlignment.Left
        nameBox.PlaceholderText = "Enter name..."
        nameBox.ClearTextOnFocus = false
        nameBox.Parent = item
        
        local nameBoxCorner = Instance.new("UICorner")
        nameBoxCorner.CornerRadius = UDim.new(0, 3)
        nameBoxCorner.Parent = nameBox
        
        -- PERBAIKAN: Save nama ketika selesai edit
        nameBox.FocusLost:Connect(function()
            local newName = nameBox.Text
            if newName and newName ~= "" then
                checkpointNames[name] = newName
                PlaySound("Success")
            end
        end)
        
        local infoLabel = Instance.new("TextLabel")
        infoLabel.Size = UDim2.new(1, -130, 0, 16)
        infoLabel.Position = UDim2.new(0, 8, 0, 22)
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
        
        local playBtn = Instance.new("TextButton")
        playBtn.Size = UDim2.fromOffset(25, 25)
        playBtn.Position = UDim2.new(1, -110, 0, 7)
        playBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        playBtn.Text = "▶"
        playBtn.TextColor3 = Color3.new(1, 1, 1)
        playBtn.Font = Enum.Font.GothamBold
        playBtn.TextSize = 35
        playBtn.Parent = item
        
        local playCorner = Instance.new("UICorner")
        playCorner.CornerRadius = UDim.new(0, 6)
        playCorner.Parent = playBtn
        
        local upBtn = Instance.new("TextButton")
        upBtn.Size = UDim2.fromOffset(25, 25)
        upBtn.Position = UDim2.new(1, -80, 0, 7)
        upBtn.BackgroundColor3 = index > 1 and Color3.fromRGB(74, 195, 147) or Color3.fromRGB(30, 30, 30)
        upBtn.Text = "↑"
        upBtn.TextColor3 = Color3.new(1, 1, 1)
        upBtn.Font = Enum.Font.GothamBold
        upBtn.TextSize = 35
        upBtn.Parent = item
        
        local upCorner = Instance.new("UICorner")
        upCorner.CornerRadius = UDim.new(0, 6)
        upCorner.Parent = upBtn
        
        local downBtn = Instance.new("TextButton")
        downBtn.Size = UDim2.fromOffset(25, 25)
        downBtn.Position = UDim2.new(1, -50, 0, 7)
        downBtn.BackgroundColor3 = index < #RecordingOrder and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(30, 30, 30)
        downBtn.Text = "↓"
        downBtn.TextColor3 = Color3.new(1, 1, 1)
        downBtn.Font = Enum.Font.GothamBold
        downBtn.TextSize = 35
        downBtn.Parent = item
        
        local downCorner = Instance.new("UICorner")
        downCorner.CornerRadius = UDim.new(0, 6)
        downCorner.Parent = downBtn
        
        local delBtn = Instance.new("TextButton")
        delBtn.Size = UDim2.fromOffset(25, 25)
        delBtn.Position = UDim2.new(1, -20, 0, 7)
        delBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        delBtn.Text = "x"
        delBtn.TextColor3 = Color3.new(1, 1, 1)
        delBtn.Font = Enum.Font.GothamBold
        delBtn.TextSize = 30
        delBtn.Parent = item
        
        local delCorner = Instance.new("UICorner")
        delCorner.CornerRadius = UDim.new(0, 6)
        delCorner.Parent = delBtn
        
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
            local idx = table.find(RecordingOrder, name)
            if idx then table.remove(RecordingOrder, idx) end
            UpdateRecordList()
        end)
        
        yPos = yPos + 43
    end
    
    -- PERBAIKAN: CanvasSize diupdate dengan benar untuk scroll yang smooth
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
        if moveState == "Falling" and velY > 25 then
            moveState = "Jumping"
        elseif velY > 50 then
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

-- ========= IMPROVED PLAYBACK SYSTEM WITH VISIBLE SHIFTLOCK =========
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
    currentPlaybackFrame = 1
    playbackStartTime = tick()
    totalPausedDuration = 0
    pauseStartTime = 0

    SaveHumanoidState()
    DisableJump()
    
    HideJumpButton()
    PlaySound("Play")

    playbackConnection = RunService.Heartbeat:Connect(function()
        if not IsPlaying then
            playbackConnection:Disconnect()
            RestoreFullUserControl()
            UpdatePauseMarker()
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
            return
        end
        
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then
            IsPlaying = false
            RestoreFullUserControl()
            UpdatePauseMarker()
            return
        end

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
            return
        end

        local frame = recording[currentPlaybackFrame]
        if not frame then
            IsPlaying = false
            RestoreFullUserControl()
            UpdatePauseMarker()
            return
        end

        pcall(function()
            hrp.CFrame = GetFrameCFrame(frame)
            hrp.AssemblyLinearVelocity = GetFrameVelocity(frame)
            
            if hum then
                hum.WalkSpeed = GetFrameWalkSpeed(frame) * CurrentSpeed
                hum.AutoRotate = false
                
                local moveState = frame.MoveState
                if moveState == "Climbing" then
                    hum:ChangeState(Enum.HumanoidStateType.Climbing)
                    hum.PlatformStand = false
                    hum.AutoRotate = false
                elseif moveState == "Jumping" then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                    task.spawn(function()
                        wait(0.01)
                        if hum and hum.Parent then
                            hum:ChangeState(Enum.HumanoidStateType.Jumping)
                        end
                    end)
                elseif moveState == "Falling" then
                    hum:ChangeState(Enum.HumanoidStateType.Freefall)
                else
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                end
            end
            
            if ShiftLockEnabled then
                ApplyVisibleShiftLock()
            end
        end)
    end)
    
    AddConnection(playbackConnection)
end

-- ========= FIXED AUTO LOOP SYSTEM - TANPA HENTI =========
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
    
    loopConnection = task.spawn(function()
        while AutoLoop and IsAutoLoopPlaying do
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
            
            local shouldReset = false
            if AutoRespawn and CurrentLoopIndex == 1 then
                shouldReset = true
            end
            
            if shouldReset then
                ResetCharacter()
                local success = WaitForRespawn()
                if not success then
                    -- Jika respawn gagal, lanjut ke recording berikutnya
                    CurrentLoopIndex = CurrentLoopIndex + 1
                    if CurrentLoopIndex > #RecordingOrder then
                        CurrentLoopIndex = 1
                    end
                    task.wait(1)
                    continue
                end
                
                task.wait(1.5)
            end
            
            -- PERBAIKAN: Jika karakter mati, tunggu respawn dan lanjutkan
            if not IsCharacterReady() then
                local maxWaitTime = 15
                local startWait = tick()
                
                while not IsCharacterReady() and AutoLoop and IsAutoLoopPlaying do
                    if tick() - startWait > maxWaitTime then
                        -- Timeout, lanjut ke recording berikutnya
                        CurrentLoopIndex = CurrentLoopIndex + 1
                        if CurrentLoopIndex > #RecordingOrder then
                            CurrentLoopIndex = 1
                        end
                        break
                    end
                    task.wait(0.5)
                end
                
                if not AutoLoop or not IsAutoLoopPlaying then break end
                
                task.wait(1.0)
            end
            
            if not AutoLoop or not IsAutoLoopPlaying then break end
            
            local playbackCompleted = false
            local playbackStart = tick()
            local playbackPausedTime = 0
            local playbackPauseStart = 0
            local currentFrame = 1
            
            SaveHumanoidState()
            DisableJump()
            
            HideJumpButton()
            
            while AutoLoop and IsAutoLoopPlaying and currentFrame <= #recording do
                if not IsCharacterReady() then
                    -- Karakter mati selama playback, break untuk lanjut ke recording berikutnya
                    break
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
                        break
                    end
                    
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if not hum or not hrp then
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
                            hrp.CFrame = GetFrameCFrame(frame)
                            hrp.AssemblyLinearVelocity = GetFrameVelocity(frame)
                            
                            if hum then
                                hum.WalkSpeed = GetFrameWalkSpeed(frame) * CurrentSpeed
                                hum.AutoRotate = false
                                
                                local moveState = frame.MoveState
                                if moveState == "Climbing" then
                                    hum:ChangeState(Enum.HumanoidStateType.Climbing)
                                    hum.PlatformStand = false
                                    hum.AutoRotate = false
                                elseif moveState == "Jumping" then
                                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                                    task.spawn(function()
                                        wait(0.01)
                                        if hum and hum.Parent then
                                            hum:ChangeState(Enum.HumanoidStateType.Jumping)
                                        end
                                    end)
                                elseif moveState == "Falling" then
                                    hum:ChangeState(Enum.HumanoidStateType.Freefall)
                                else
                                    hum:ChangeState(Enum.HumanoidStateType.Running)
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
            
            if playbackCompleted then
                PlaySound("Success")
                
                CurrentLoopIndex = CurrentLoopIndex + 1
                if CurrentLoopIndex > #RecordingOrder then
                    CurrentLoopIndex = 1
                end
                
                task.wait(0.5)
            else
                -- Jika playback tidak completed (karakter mati), lanjut ke recording berikutnya
                CurrentLoopIndex = CurrentLoopIndex + 1
                if CurrentLoopIndex > #RecordingOrder then
                    CurrentLoopIndex = 1
                end
                task.wait(0.5)
            end
        end
        
        IsAutoLoopPlaying = false
        IsPaused = false
        RestoreFullUserControl()
        UpdatePauseMarker()
    end)
end

function StopAutoLoopAll()
    AutoLoop = false
    IsAutoLoopPlaying = false
    IsPlaying = false
    IsPaused = false
    
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
    
    local success, err = pcall(function()
        local saveData = {
            Version = "2.0",
            Obfuscated = true,
            Checkpoints = {},
            RecordingOrder = RecordingOrder, -- PERBAIKAN: Simpan urutan recording
            CheckpointNames = checkpointNames -- PERBAIKAN: Simpan custom names
        }
        
        for name, frames in pairs(RecordedMovements) do
            local checkpointData = {
                Name = name,
                DisplayName = checkpointNames[name] or "checkpoint",
                Frames = frames
            }
            table.insert(saveData.Checkpoints, checkpointData)
        end
        
        local obfuscatedData = ObfuscateRecordingData(RecordedMovements)
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
        RecordingOrder = saveData.RecordingOrder or {} -- PERBAIKAN: Load urutan
        checkpointNames = saveData.CheckpointNames or {} -- PERBAIKAN: Load custom names
        
        if saveData.Obfuscated and saveData.ObfuscatedFrames then
            local deobfuscatedData = DeobfuscateRecordingData(saveData.ObfuscatedFrames)
            
            for _, checkpointData in ipairs(saveData.Checkpoints or {}) do
                local name = checkpointData.Name
                local frames = deobfuscatedData[name]
                
                if frames then
                    RecordedMovements[name] = frames
                    -- PERBAIKAN: Pastikan nama ada di RecordingOrder jika tidak ada
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
    if IsRecording then StopRecording() end
    if IsPlaying or AutoLoop then StopPlayback() end
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
    end
end)

-- ========= INITIAL SETUP =========
-- Initialize the record list
UpdateRecordList()

-- Auto-load any saved recordings on script start
task.spawn(function()
    task.wait(2)
    local filename = "MyReplays.json"
    if isfile and readfile and isfile(filename) then
        LoadFromObfuscatedJSON()
    end
end)

-- Character cleanup on removal
player.CharacterRemoving:Connect(function()
    if IsRecording then
        StopRecording()
    end
    if IsPlaying or AutoLoop then
        StopPlayback()
    end
end)

-- ========= FINAL INITIALIZATION =========
warn("Loaded Successfully!")

-- Ensure proper cleanup on script termination
game:GetService("ScriptContext").DescendantRemoving:Connect(function(descendant)
    if descendant == ScreenGui then
        CleanupConnections()
        ClearPathVisualization()
        ShowJumpButton()
    end
end)