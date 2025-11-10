local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
wait(1)

-- ========= CONFIGURATION =========
local RECORDING_FPS = 60
local MAX_FRAMES = 30000
local MIN_DISTANCE_THRESHOLD = 0.015
local VELOCITY_SCALE = 1
local VELOCITY_Y_SCALE = 1
local RESUME_DISTANCE_THRESHOLD = 15
local PLAYBACK_FIXED_TIMESTEP = 1 / 60
local STATE_CHANGE_COOLDOWN = 0.03

-- ========= VARIABLES =========
local IsRecording = false
local IsPlaying = false
local IsPaused = false
local IsAutoLoopPlaying = false
local CurrentSpeed = 1
local CurrentWalkSpeed = 16
local RecordedMovements = {}
local RecordingOrder = {}
local CurrentRecording = {Frames = {}, StartTime = 0, Name = ""}
local AutoRespawn = false
local InfiniteJump = false
local AutoLoop = false
local ShiftLockEnabled = false
local ShowPaths = false
local recordConnection = nil
local playbackConnection = nil
local loopConnection = nil
local jumpConnection = nil
local shiftLockConnection = nil
local lastRecordTime = 0
local lastRecordPos = nil
local checkpointNames = {}
local PathVisualization = {}
local CurrentPauseMarker = nil
local playbackStartTime = 0
local totalPausedDuration = 0
local pauseStartTime = 0
local currentPlaybackFrame = 1
local lastPlaybackState = nil
local lastStateChangeTime = 0
local CurrentLoopIndex = 1
local activeConnections = {}
local CheckedRecordings = {}
local CurrentPlayingRecording = nil
local PausedAtFrame = 0
local playbackAccumulator = 0
local LastPausePosition = nil
local LastPauseRecording = nil

-- ========= CHARACTER STATE MANAGEMENT =========
local prePauseHumanoidState = nil
local prePauseWalkSpeed = 16
local prePauseAutoRotate = true
local prePauseJumpPower = 50
local prePausePlatformStand = false
local prePauseSit = false

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

-- ========= MOVEMENT STATE DETECTION =========
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

-- ========= FRAME DATA FUNCTIONS =========
local function GetFramePosition(frame)
    return Vector3.new(frame.Position[1], frame.Position[2], frame.Position[3])
end

local function GetFrameCFrame(frame)
    local pos = GetFramePosition(frame)
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

-- ========= SMART POSITIONING SYSTEM =========
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

-- ========= PAUSE MARKER SYSTEM =========
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

-- ========= CHARACTER READY CHECK =========
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

-- ========= SHIFT LOCK SYSTEM =========
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
    shiftLockConnection = RunService.RenderStepped:Connect(function()
        if ShiftLockEnabled and player.Character then
            ApplyVisibleShiftLock()
        end
    end)
    AddConnection(shiftLockConnection)
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
end

local function ToggleVisibleShiftLock()
    ShiftLockEnabled = not ShiftLockEnabled
    if ShiftLockEnabled then
        EnableVisibleShiftLock()
    else
        DisableVisibleShiftLock()
    end
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

-- ========= RECORDING STUDIO GUI (170x170) =========
local RecordingStudio = Instance.new("Frame")
RecordingStudio.Size = UDim2.fromOffset(170, 170)
RecordingStudio.Position = UDim2.new(0.5, -85, 0.5, -85)
RecordingStudio.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
RecordingStudio.BorderSizePixel = 0
RecordingStudio.Active = true
RecordingStudio.Draggable = true
RecordingStudio.Visible = false
RecordingStudio.Parent = ScreenGui

local StudioCorner = Instance.new("UICorner")
StudioCorner.CornerRadius = UDim.new(0, 10)
StudioCorner.Parent = RecordingStudio

local StudioHeader = Instance.new("Frame")
StudioHeader.Size = UDim2.new(1, 0, 0, 25)
StudioHeader.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
StudioHeader.BorderSizePixel = 0
StudioHeader.Parent = RecordingStudio

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 10)
HeaderCorner.Parent = StudioHeader

local CloseStudioBtn = Instance.new("TextButton")
CloseStudioBtn.Size = UDim2.fromOffset(20, 20)
CloseStudioBtn.Position = UDim2.new(1, -22, 0.5, -10)
CloseStudioBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
CloseStudioBtn.Text = "×"
CloseStudioBtn.TextColor3 = Color3.new(1, 1, 1)
CloseStudioBtn.Font = Enum.Font.GothamBold
CloseStudioBtn.TextSize = 18
CloseStudioBtn.Parent = StudioHeader

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 5)
CloseCorner.Parent = CloseStudioBtn

local StudioContent = Instance.new("Frame")
StudioContent.Size = UDim2.new(1, -16, 1, -33)
StudioContent.Position = UDim2.new(0, 8, 0, 28)
StudioContent.BackgroundTransparency = 1
StudioContent.Parent = RecordingStudio

local function CreateStudioBtn(text, x, y, w, h)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(w, h)
    btn.Position = UDim2.fromOffset(x, y)
    btn.BackgroundColor3 = Color3.fromRGB(56, 58, 127)
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.AutoButtonColor = false
    btn.Parent = StudioContent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = btn
    
    return btn
end

-- Studio Buttons Layout (170x170)
local SaveBtn = CreateStudioBtn("SAVE", 5, 5, 70, 28)
local ClearBtn = CreateStudioBtn("CLEAR", 79, 5, 70, 28)

local RecordBtn = CreateStudioBtn("RECORD", 5, 38, 144, 32)
local ResumeBtn = CreateStudioBtn("RESUME", 5, 75, 144, 32)

local BackBtn = CreateStudioBtn("BACK", 5, 112, 70, 32)
local NextBtn = CreateStudioBtn("NEXT", 79, 112, 70, 32)

-- ========= PLAYBACK CONTROL GUI (200x170) =========
local PlaybackControl = Instance.new("Frame")
PlaybackControl.Size = UDim2.fromOffset(200, 170)
PlaybackControl.Position = UDim2.new(0.5, -100, 0.5, -100)
PlaybackControl.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
PlaybackControl.BorderSizePixel = 0
PlaybackControl.Active = true
PlaybackControl.Draggable = true
PlaybackControl.Visible = false
PlaybackControl.Parent = ScreenGui

local PlaybackCorner = Instance.new("UICorner")
PlaybackCorner.CornerRadius = UDim.new(0, 10)
PlaybackCorner.Parent = PlaybackControl

local PlaybackHeader = Instance.new("Frame")
PlaybackHeader.Size = UDim2.new(1, 0, 0, 25)
PlaybackHeader.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
PlaybackHeader.BorderSizePixel = 0
PlaybackHeader.Parent = PlaybackControl

local PlaybackHeaderCorner = Instance.new("UICorner")
PlaybackHeaderCorner.CornerRadius = UDim.new(0, 10)
PlaybackHeaderCorner.Parent = PlaybackHeader

local ClosePlaybackBtn = Instance.new("TextButton")
ClosePlaybackBtn.Size = UDim2.fromOffset(20, 20)
ClosePlaybackBtn.Position = UDim2.new(1, -22, 0.5, -10)
ClosePlaybackBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
ClosePlaybackBtn.Text = "×"
ClosePlaybackBtn.TextColor3 = Color3.new(1, 1, 1)
ClosePlaybackBtn.Font = Enum.Font.GothamBold
ClosePlaybackBtn.TextSize = 18
ClosePlaybackBtn.Parent = PlaybackHeader

local ClosePlaybackCorner = Instance.new("UICorner")
ClosePlaybackCorner.CornerRadius = UDim.new(0, 5)
ClosePlaybackCorner.Parent = ClosePlaybackBtn

local PlaybackContent = Instance.new("Frame")
PlaybackContent.Size = UDim2.new(1, -16, 1, -33)
PlaybackContent.Position = UDim2.new(0, 8, 0, 28)
PlaybackContent.BackgroundTransparency = 1
PlaybackContent.Parent = PlaybackControl

local function CreatePlaybackBtn(text, x, y, w, h)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(w, h)
    btn.Position = UDim2.fromOffset(x, y)
    btn.BackgroundColor3 = Color3.fromRGB(56, 58, 127)
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.AutoButtonColor = false
    btn.Parent = PlaybackContent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = btn
    
    return btn
end

local function CreatePlaybackToggle(text, x, y, w, h, default)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(w, h)
    btn.Position = UDim2.fromOffset(x, y)
    btn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    btn.Text = ""
    btn.Parent = PlaybackContent
    
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
    
    local function Animate(isOn)
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local bgColor = isOn and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(50, 50, 50)
        local knobPos = isOn and UDim2.new(0, 11, 0, 2) or UDim2.new(0, 2, 0, 2)
        TweenService:Create(toggle, tweenInfo, {BackgroundColor3 = bgColor}):Play()
        TweenService:Create(knob, tweenInfo, {Position = knobPos}):Play()
    end
    
    return btn, Animate
end

-- Playback Control Layout (200x170)
local PlayBtnControl = CreatePlaybackBtn("PLAY", 5, 5, 84, 32)
local PauseBtnControl = CreatePlaybackBtn("PAUSE", 93, 5, 84, 32)

local LoopBtnControl, AnimateLoopControl = CreatePlaybackToggle("AutoLoop", 5, 42, 84, 22, false)
local ShiftLockBtnControl, AnimateShiftLockControl = CreatePlaybackToggle("ShiftLock", 93, 42, 84, 22, false)

local ResetBtnControl, AnimateResetControl = CreatePlaybackToggle("ResetChar", 5, 69, 84, 22, false)
local RespawnBtnControl, AnimateRespawnControl = CreatePlaybackToggle("Respawn", 93, 69, 84, 22, false)

local JumpBtnControl, AnimateJumpControl = CreatePlaybackToggle("InfJump", 5, 96, 172, 22, false)

-- ========= MAIN GUI (250x340) =========
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

local function CreateButton(text, x, y, w, h)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(w, h)
    btn.Position = UDim2.fromOffset(x, y)
    btn.BackgroundColor3 = Color3.fromRGB(19, 137, 79)
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.AutoButtonColor = false
    btn.Parent = Content
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    
    return btn
end

-- ========= MAIN GUI LAYOUT (250x340) =========
local OpenStudioBtn = CreateButton("RECORD", 0, 2, 75, 30)
local MenuBtn = CreateButton("MENU", 79, 2, 75, 30)
local PlaybackBtn = CreateButton("PLAY", 158, 2, 76, 30)

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

local SaveFileBtn = CreateButton("SAVE FILE", 0, 62, 115, 30)
local LoadFileBtn = CreateButton("LOAD FILE", 119, 62, 115, 30)

local PathToggleBtn = CreateButton("SHOW RUTE", 0, 96, 115, 30)
local MergeBtn = CreateButton("MERGE", 119, 96, 115, 30)

-- Recording List (Scrollable) 
local RecordList = Instance.new("ScrollingFrame")
RecordList.Size = UDim2.new(1, 0, 0, 170)
RecordList.Position = UDim2.fromOffset(0, 130)
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

-- ========= RECORDING SYSTEM =========
local function StartRecording()
    if IsRecording then return end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    IsRecording = true
    CurrentRecording = {Frames = {}, StartTime = tick(), Name = "Walk_" .. os.date("%H%M%S")}
    lastRecordTime = 0
    lastRecordPos = nil
    
    RecordBtn.Text = "STOP"
    RecordBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 60)
    
    recordConnection = RunService.Heartbeat:Connect(function()
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") or #CurrentRecording.Frames >= MAX_FRAMES then
            StopRecording()
            return
        end
        
        local now = tick()
        if (now - lastRecordTime) < (1 / RECORDING_FPS) then return end
        
        local hrp = char.HumanoidRootPart
        local hum = char:FindFirstChildOfClass("Humanoid")
        local currentPos = hrp.Position
        local currentVelocity = hrp.AssemblyLinearVelocity
        
        local moveState = GetCurrentMoveState(hum)
        
        if lastRecordPos and (currentPos - lastRecordPos).Magnitude < MIN_DISTANCE_THRESHOLD and moveState == "Grounded" then
            lastRecordTime = now
            return
        end
        
        local cf = hrp.CFrame
        table.insert(CurrentRecording.Frames, {
            Position = {cf.Position.X, cf.Position.Y, cf.Position.Z},
            LookVector = {cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z},
            UpVector = {cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z},
            Velocity = {currentVelocity.X, currentVelocity.Y, currentVelocity.Z},
            MoveState = moveState,
            WalkSpeed = hum and hum.WalkSpeed or 16,
            Timestamp = now - CurrentRecording.StartTime
        })
        
        lastRecordTime = now
        lastRecordPos = currentPos
    end)
end

local function StopRecording()
    if not IsRecording then return end
    IsRecording = false
    
    if recordConnection then
        recordConnection:Disconnect()
        recordConnection = nil
    end
    
    RecordBtn.Text = "RECORD"
    RecordBtn.BackgroundColor3 = Color3.fromRGB(56, 58, 127)
end

local function SaveRecording()
    if #CurrentRecording.Frames == 0 then
        return
    end
    
    local name = CurrentRecording.Name
    RecordedMovements[name] = CurrentRecording.Frames
    table.insert(RecordingOrder, name)
    checkpointNames[name] = "checkpoint_" .. #RecordingOrder
    UpdateRecordList()
    
    CurrentRecording = {Frames = {}, StartTime = 0, Name = "Walk_" .. os.date("%H%M%S")}
end

local function ClearAll()
    RecordedMovements = {}
    RecordingOrder = {}
    checkpointNames = {}
    CheckedRecordings = {}
    ClearPathVisualization()
    UpdateRecordList()
end

-- ========= RECORD LIST MANAGEMENT =========
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
    for _, child in pairs(RecordList:GetChildren()) do 
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local yPos = 0
    for index, name in ipairs(RecordingOrder) do
        local rec = RecordedMovements[name]
        if not rec then continue end
        
        local item = Instance.new("Frame")
        item.Size = UDim2.new(1, -4, 0, 33)
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
        infoLabel.Size = UDim2.new(0, 180, 0, 14)
        infoLabel.Position = UDim2.fromOffset(22, 2)
        infoLabel.BackgroundTransparency = 1
        if #rec > 0 then
            local totalSeconds = rec[#rec].Timestamp
            infoLabel.Text = "[✔️] " .. FormatDuration(totalSeconds) .. " Frame " .. #rec
        else
            infoLabel.Text = "[✔️] 0:00 Frame 0"
        end
        infoLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
        infoLabel.Font = Enum.Font.GothamBold
        infoLabel.TextSize = 7
        infoLabel.TextXAlignment = Enum.TextXAlignment.Left
        infoLabel.Parent = item
        
        local playBtn = Instance.new("TextButton")
        playBtn.Size = UDim2.fromOffset(26, 16)
        playBtn.Position = UDim2.fromOffset(3, 17)
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
        delBtn.Position = UDim2.fromOffset(32, 17)
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
        nameBox.Position = UDim2.fromOffset(61, 17)
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
        
        local upBtn = Instance.new("TextButton")
        upBtn.Size = UDim2.fromOffset(26, 16)
        upBtn.Position = UDim2.new(1, -55, 0, 17)
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
        downBtn.Position = UDim2.new(1, -27, 0, 17)
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
        end)
        
        nameBox.FocusLost:Connect(function()
            local newName = nameBox.Text
            if newName and newName ~= "" then
                checkpointNames[name] = newName
            end
        end)
        
        upBtn.MouseButton1Click:Connect(function()
            if index > 1 then 
                MoveRecordingUp(name) 
            end
        end)
        
        downBtn.MouseButton1Click:Connect(function()
            if index < #RecordingOrder then 
                MoveRecordingDown(name) 
            end
        end)
        
        playBtn.MouseButton1Click:Connect(function()
            if not IsPlaying then 
                PlayRecording(name) 
            end
        end)
        
        delBtn.MouseButton1Click:Connect(function()
            RecordedMovements[name] = nil
            checkpointNames[name] = nil
            CheckedRecordings[name] = nil
            local idx = table.find(RecordingOrder, name)
            if idx then table.remove(RecordingOrder, idx) end
            UpdateRecordList()
        end)
        
        yPos = yPos + 36
    end
    
    RecordList.CanvasSize = UDim2.new(0, 0, 0, math.max(yPos, RecordList.AbsoluteSize.Y))
end

-- ========= IMPROVED PLAYBACK WITH SMART RESUME =========
function PlayRecording(name)
    if IsPlaying then return end
    
    local recording = name and RecordedMovements[name] or (RecordingOrder[1] and RecordedMovements[RecordingOrder[1]])
    if not recording or #recording == 0 then
        return
    end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        return
    end

    IsPlaying = true
    IsPaused = false
    CurrentPlayingRecording = recording
    PausedAtFrame = 0
    playbackAccumulator = 0
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local currentPos = hrp.Position
    
    -- Smart resume system: find nearest frame within route
    local nearestFrame, distance = FindNearestFrame(recording, currentPos)
    
    if distance <= RESUME_DISTANCE_THRESHOLD then
        -- Resume from nearest position in route
        currentPlaybackFrame = nearestFrame
        playbackStartTime = tick() - (GetFrameTimestamp(recording[nearestFrame]) / CurrentSpeed)
    else
        -- Start from beginning if too far
        currentPlaybackFrame = 1
        playbackStartTime = tick()
        hrp.CFrame = GetFrameCFrame(recording[1])
    end
    
    totalPausedDuration = 0
    pauseStartTime = 0
    lastPlaybackState = nil
    lastStateChangeTime = 0

    SaveHumanoidState()
    
    PlayBtnControl.Text = "STOP"
    PlayBtnControl.BackgroundColor3 = Color3.fromRGB(200, 50, 60)

    playbackConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not IsPlaying then
            playbackConnection:Disconnect()
            RestoreFullUserControl()
            UpdatePauseMarker()
            lastPlaybackState = nil
            lastStateChangeTime = 0
            PlayBtnControl.Text = "PLAY"
            PlayBtnControl.BackgroundColor3 = Color3.fromRGB(56, 58, 127)
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
            PlayBtnControl.Text = "PLAY"
            PlayBtnControl.BackgroundColor3 = Color3.fromRGB(56, 58, 127)
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
            PlayBtnControl.BackgroundColor3 = Color3.fromRGB(56, 58, 127)
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
                UpdatePauseMarker()
                lastPlaybackState = nil
                lastStateChangeTime = 0
                PlayBtnControl.Text = "PLAY"
                PlayBtnControl.BackgroundColor3 = Color3.fromRGB(56, 58, 127)
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
                PlayBtnControl.BackgroundColor3 = Color3.fromRGB(56, 58, 127)
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
                            hum:ChangeState(Enum.HumanoidStateType.Freefall)
                        elseif moveState == "Swimming" then
                            hum:ChangeState(Enum.HumanoidStateType.Swimming)
                        else
                            hum:ChangeState(Enum.HumanoidStateType.Running)
                        end
                    end
                end
            end)
        end
    end)
    
    AddConnection(playbackConnection)
end

function StopPlayback()
    if AutoLoop then
        StopAutoLoopAll()
        AnimateLoopControl(false)
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
    
    PlayBtnControl.Text = "PLAY"
    PlayBtnControl.BackgroundColor3 = Color3.fromRGB(56, 58, 127)
    PauseBtnControl.Text = "PAUSE"
    PauseBtnControl.BackgroundColor3 = Color3.fromRGB(56, 58, 127)
end

function PausePlayback()
    -- Resume dari pause dengan smart positioning
    if not IsPlaying and not IsAutoLoopPlaying and IsPaused then
        if LastPausePosition and LastPauseRecording then
            local char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then
                return
            end
            
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local currentPos = hrp.Position
            
            local nearestFrame, distance = FindNearestFrame(LastPauseRecording, currentPos)
            
            if distance <= RESUME_DISTANCE_THRESHOLD then
                -- Resume dari posisi terdekat dalam rute
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
                
                PlayBtnControl.Text = "STOP"
                PlayBtnControl.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
                PauseBtnControl.Text = "PAUSE"
                PauseBtnControl.BackgroundColor3 = Color3.fromRGB(56, 58, 127)
                
                playbackConnection = RunService.Heartbeat:Connect(function(deltaTime)
                    if not IsPlaying then
                        playbackConnection:Disconnect()
                        RestoreFullUserControl()
                        UpdatePauseMarker()
                        lastPlaybackState = nil
                        lastStateChangeTime = 0
                        PlayBtnControl.Text = "PLAY"
                        PlayBtnControl.BackgroundColor3 = Color3.fromRGB(56, 58, 127)
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
                        PlayBtnControl.Text = "PLAY"
                        PlayBtnControl.BackgroundColor3 = Color3.fromRGB(56, 58, 127)
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
                        PlayBtnControl.BackgroundColor3 = Color3.fromRGB(56, 58, 127)
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
                            UpdatePauseMarker()
                            lastPlaybackState = nil
                            lastStateChangeTime = 0
                            PlayBtnControl.Text = "PLAY"
                            PlayBtnControl.BackgroundColor3 = Color3.fromRGB(56, 58, 127)
                            return
                        end
                        
                        local frame = LastPauseRecording[currentPlaybackFrame]
                        if not frame then
                            IsPlaying = false
                            RestoreFullUserControl()
                            UpdatePauseMarker()
                            lastPlaybackState = nil
                            lastStateChangeTime = 0
                            PlayBtnControl.Text = "PLAY"
                            PlayBtnControl.BackgroundColor3 = Color3.fromRGB(56, 58, 127)
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
                                        hum:ChangeState(Enum.HumanoidStateType.Freefall)
                                    elseif moveState == "Swimming" then
                                        hum:ChangeState(Enum.HumanoidStateType.Swimming)
                                    else
                                        hum:ChangeState(Enum.HumanoidStateType.Running)
                                    end
                                end
                            end
                        end)
                    end
                end)
                
                AddConnection(playbackConnection)
                UpdatePauseMarker()
            else
                -- Jika terlalu jauh, teleport ke awal recording
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
                
                PlayBtnControl.Text = "STOP"
                PlayBtnControl.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
                PauseBtnControl.Text = "PAUSE"
                PauseBtnControl.BackgroundColor3 = Color3.fromRGB(56, 58, 127)
                
                playbackConnection = RunService.Heartbeat:Connect(function(deltaTime)
                    if not IsPlaying then
                        playbackConnection:Disconnect()
                        RestoreFullUserControl()
                        UpdatePauseMarker()
                        lastPlaybackState = nil
                        lastStateChangeTime = 0
                        PlayBtnControl.Text = "PLAY"
                        PlayBtnControl.BackgroundColor3 = Color3.fromRGB(56, 58, 127)
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
                        PlayBtnControl.Text = "PLAY"
                        PlayBtnControl.BackgroundColor3 = Color3.fromRGB(56, 58, 127)
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
                        PlayBtnControl.BackgroundColor3 = Color3.fromRGB(56, 58, 127)
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
                            UpdatePauseMarker()
                            lastPlaybackState = nil
                            lastStateChangeTime = 0
                            PlayBtnControl.Text = "PLAY"
                            PlayBtnControl.BackgroundColor3 = Color3.fromRGB(56, 58, 127)
                            return
                        end
                        
                        local frame = LastPauseRecording[currentPlaybackFrame]
                        if not frame then
                            IsPlaying = false
                            RestoreFullUserControl()
                            UpdatePauseMarker()
                            lastPlaybackState = nil
                            lastStateChangeTime = 0
                            PlayBtnControl.Text = "PLAY"
                            PlayBtnControl.BackgroundColor3 = Color3.fromRGB(56, 58, 127)
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
                                        hum:ChangeState(Enum.HumanoidStateType.Freefall)
                                    elseif moveState == "Swimming" then
                                        hum:ChangeState(Enum.HumanoidStateType.Swimming)
                                    else
                                        hum:ChangeState(Enum.HumanoidStateType.Running)
                                    end
                                end
                            end
                        end)
                    end
                end)
                
                AddConnection(playbackConnection)
                UpdatePauseMarker()
            end
        end
        return
    end
    
    -- Pause saat playback sedang berjalan
    if IsPlaying then
        IsPaused = not IsPaused
        
        if IsPaused then
            PauseBtnControl.Text = "RESUME"
            PauseBtnControl.BackgroundColor3 = Color3.fromRGB(8, 181, 116)
            RestoreHumanoidState()
            UpdatePauseMarker()
        else
            PauseBtnControl.Text = "PAUSE"
            PauseBtnControl.BackgroundColor3 = Color3.fromRGB(56, 58, 127)
            SaveHumanoidState()
            UpdatePauseMarker()
        end
    end
end

-- ========= AUTO LOOP SYSTEM =========
function StartAutoLoopAll()
    if not AutoLoop then return end
    
    if #RecordingOrder == 0 then
        AutoLoop = false
        AnimateLoopControl(false)
        return
    end
    
    CurrentLoopIndex = 1
    IsAutoLoopPlaying = true
    lastPlaybackState = nil
    lastStateChangeTime = 0
    
    PlayBtnControl.Text = "STOP"
    PlayBtnControl.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
    
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
                            AnimateLoopControl(false)
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
                                AnimateLoopControl(false)
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
                    
                    -- Fixed timestep for auto-loop
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
                            task.spawn(function()
                                hrp.CFrame = GetFrameCFrame(frame)
                                hrp.AssemblyLinearVelocity = GetFrameVelocity(frame)
                                
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
                                            hum:ChangeState(Enum.HumanoidStateType.Freefall)
                                        elseif moveState == "Swimming" then
                                            hum:ChangeState(Enum.HumanoidStateType.Swimming)
                                        else
                                            hum:ChangeState(Enum.HumanoidStateType.Running)
                                        end
                                    end
                                end
                            end)
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
        PlayBtnControl.Text = "PLAY"
        PlayBtnControl.BackgroundColor3 = Color3.fromRGB(56, 58, 127)
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
    
    PlayBtnControl.Text = "PLAY"
    PlayBtnControl.BackgroundColor3 = Color3.fromRGB(56, 58, 127)
    PauseBtnControl.Text = "PAUSE"
    PauseBtnControl.BackgroundColor3 = Color3.fromRGB(56, 58, 127)
end

-- ========= FILE MANAGEMENT =========
local function SaveToJSON()
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
        return
    end
    
    local success, err = pcall(function()
        local saveData = {
            Version = "2.1",
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
        
        local jsonString = HttpService:JSONEncode(saveData)
        writefile(filename, jsonString)
    end)
end

local function LoadFromJSON()
    local filename = FilenameBox.Text
    if filename == "" then filename = "MyReplays" end
    filename = filename .. ".json"
    
    local success, err = pcall(function()
        if not isfile(filename) then
            return
        end
        
        local jsonString = readfile(filename)
        local saveData = HttpService:JSONDecode(jsonString)
        
        RecordedMovements = {}
        RecordingOrder = saveData.RecordingOrder or {}
        checkpointNames = saveData.CheckpointNames or {}
        CheckedRecordings = {}
        
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
        
        UpdateRecordList()
    end)
end

-- ========= MERGE SYSTEM =========
local function CreateMergedReplay()
    if #RecordingOrder < 2 then
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
end

-- ========= PATH VISUALIZATION =========
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
                local part = Instance.new("Part")
                part.Name = "PathSegment"
                part.Anchored = true
                part.CanCollide = false
                part.Material = Enum.Material.Neon
                part.BrickColor = BrickColor.new("Really black")
                part.Transparency = 0.2
                local distance = (previousPos - currentPos).Magnitude
                part.Size = Vector3.new(0.2, 0.2, distance)
                part.CFrame = CFrame.lookAt((previousPos + currentPos) / 2, currentPos)
                part.Parent = workspace
                table.insert(PathVisualization, part)
                previousPos = currentPos
            end
        end
    end
end

-- ========= INPUT VALIDATION =========
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
    else
        SpeedBox.Text = string.format("%.2f", CurrentSpeed)
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
    else
        WalkSpeedBox.Text = tostring(CurrentWalkSpeed)
    end
end)

-- ========= BUTTON CONNECTIONS =========
-- Studio Connections
RecordBtn.MouseButton1Click:Connect(function()
    if IsRecording then
        StopRecording()
    else
        StartRecording()
    end
end)

SaveBtn.MouseButton1Click:Connect(function()
    SaveRecording()
    RecordingStudio.Visible = false
    MainFrame.Visible = true
end)

ClearBtn.MouseButton1Click:Connect(function()
    ClearAll()
end)

CloseStudioBtn.MouseButton1Click:Connect(function()
    if IsRecording then
        StopRecording()
    end
    RecordingStudio.Visible = false
    MainFrame.Visible = true
end)

-- Playback Control Connections
PlayBtnControl.MouseButton1Click:Connect(function()
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

PauseBtnControl.MouseButton1Click:Connect(function()
    PausePlayback()
end)

LoopBtnControl.MouseButton1Click:Connect(function()
    AutoLoop = not AutoLoop
    AnimateLoopControl(AutoLoop)
    
    if AutoLoop then
        if not next(RecordedMovements) then
            AutoLoop = false
            AnimateLoopControl(false)
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

ShiftLockBtnControl.MouseButton1Click:Connect(function()
    ToggleVisibleShiftLock()
    AnimateShiftLockControl(ShiftLockEnabled)
end)

RespawnBtnControl.MouseButton1Click:Connect(function()
    AutoRespawn = not AutoRespawn
    AnimateRespawnControl(AutoRespawn)
end)

ResetBtnControl.MouseButton1Click:Connect(function()
    ResetCharacter()
end)

JumpBtnControl.MouseButton1Click:Connect(function()
    ToggleInfiniteJump()
    AnimateJumpControl(InfiniteJump)
end)

ClosePlaybackBtn.MouseButton1Click:Connect(function()
    PlaybackControl.Visible = false
end)

-- Main Frame Connections
OpenStudioBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    RecordingStudio.Visible = true
end)

PlaybackBtn.MouseButton1Click:Connect(function()
    PlaybackControl.Visible = not PlaybackControl.Visible
end)

MenuBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/arullwah/Wkwkwkw/refs/heads/main/library.lua", true))()
        end)
    end)
end)

SaveFileBtn.MouseButton1Click:Connect(function()
    SaveToJSON()
end)

LoadFileBtn.MouseButton1Click:Connect(function()
    LoadFromJSON()
end)

PathToggleBtn.MouseButton1Click:Connect(function()
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
    CreateMergedReplay()
end)

HideButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    MiniButton.Visible = true
end)

MiniButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    MiniButton.Visible = false
end)

CloseButton.MouseButton1Click:Connect(function()
    if IsRecording then StopRecording() end
    if IsPlaying or AutoLoop then StopPlayback() end
    if ShiftLockEnabled then DisableVisibleShiftLock() end
    if InfiniteJump then DisableInfiniteJump() end
    CleanupConnections()
    ClearPathVisualization()
    ScreenGui:Destroy()
end)

-- ========= HOTKEYS =========
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F9 then
        if RecordingStudio.Visible then
            if IsRecording then StopRecording() else StartRecording() end
        end
    elseif input.KeyCode == Enum.KeyCode.F10 then
        if IsPlaying or AutoLoop then StopPlayback() else PlayRecording() end
    elseif input.KeyCode == Enum.KeyCode.F11 then
        MainFrame.Visible = not MainFrame.Visible
        MiniButton.Visible = not MainFrame.Visible
    elseif input.KeyCode == Enum.KeyCode.F8 then
        if RecordingStudio.Visible then
            RecordingStudio.Visible = false
            MainFrame.Visible = true
        else
            MainFrame.Visible = false
            RecordingStudio.Visible = true
        end
    elseif input.KeyCode == Enum.KeyCode.F7 then
        AutoLoop = not AutoLoop
        AnimateLoopControl(AutoLoop)
        if AutoLoop then StartAutoLoopAll() else StopAutoLoopAll() end
    elseif input.KeyCode == Enum.KeyCode.F4 then
        ShowPaths = not ShowPaths
        if ShowPaths then
            VisualizeAllPaths()
        else
            ClearPathVisualization()
        end
    elseif input.KeyCode == Enum.KeyCode.F3 then
        ToggleVisibleShiftLock()
        AnimateShiftLockControl(ShiftLockEnabled)
    elseif input.KeyCode == Enum.KeyCode.F2 then
        ToggleInfiniteJump()
        AnimateJumpControl(InfiniteJump)
    end
end)

-- ========= INITIALIZATION =========
UpdateRecordList()

task.spawn(function()
    task.wait(2)
    local filename = "MyReplays.json"
    if isfile and readfile and isfile(filename) then
        LoadFromJSON()
    end
end)

player.CharacterRemoving:Connect(function()
    if IsRecording then
        StopRecording()
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