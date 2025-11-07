-- ========= AUTO WALK PRO v9.0 - UNIVERSAL CHARACTER EDITION =========
-- ENHANCED R6/R15 COMPATIBILITY + FIXED SAVE SYSTEM

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
local MIN_DISTANCE_THRESHOLD = 0.01
local VELOCITY_SCALE = 1
local VELOCITY_Y_SCALE = 1
local ROUTE_PROXIMITY_THRESHOLD = 10
local MOVETO_REACH_DISTANCE = 2
local MAX_FRAME_JUMP = 60

-- Anti-Fall Configuration
local FALL_TIME_THRESHOLD = 1.5
local FALL_HEIGHT_THRESHOLD = 30
local TIMELINE_STEP_SECONDS = 1

-- ========= ENHANCED CHARACTER DETECTION SYSTEM =========
local function GetCharacterTorso(char)
    if not char then return nil end
    return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
end

local function IsR15Character(char)
    return char:FindFirstChild("UpperTorso") ~= nil
end

local function GetCharacterHeight(char)
    if not char then return 0 end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0 end
    
    if IsR15Character(char) then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        return humanoid and humanoid.HipHeight + 2 or 5
    else
        return 5 -- Default height for R6
    end
end

local function GetTorsoPosition(char)
    local torso = GetCharacterTorso(char)
    return torso and torso.Position or Vector3.new(0, 0, 0)
end

-- ========= CORE VARIABLES =========
local IsRecording = false
local IsPlaying = false
local IsPaused = false
local UseMoveTo = true
local CurrentSpeed = 1
local RecordedMovements = {}
local CurrentRecording = {Frames = {}, StartTime = 0, Name = ""}
local AutoLoop = false
local recordConnection = nil
local lastRecordTime = 0
local lastRecordPos = nil
local ShowVisualization = false

-- ========= ANTI-FALL VARIABLES =========
local IsFallDetected = false
local LastSafeFrame = 0
local fallStartTime = 0
local fallStartHeight = 0
local isCurrentlyFalling = false

-- ========= PAUSE/RESUME VARIABLES =========
local playbackStartTime = 0
local totalPausedDuration = 0
local pauseStartTime = 0
local currentPlaybackFrame = 1
local lastMoveState = nil
local moveToConnection = nil
local currentRecordingName = ""

-- ========= EVENT CLEANUP =========
local eventConnections = {}

local function AddConnection(conn)
    table.insert(eventConnections, conn)
end

local function CleanupConnections()
    for _, conn in pairs(eventConnections) do
        if conn and conn.Connected then
            conn:Disconnect()
        end
    end
    eventConnections = {}
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
        humanoid.JumpPower = 50
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
        
        if moveToConnection then
            moveToConnection:Disconnect()
            moveToConnection = nil
        end
    end)
end

-- ========= ENHANCED FALL DETECTION =========
local function GetCurrentMoveState(char)
    if not char then return "Unknown" end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local torso = GetCharacterTorso(char)
    
    if not humanoid or not hrp or not torso then return "Unknown" end
    
    local state = humanoid:GetState()
    local velocity = torso.AssemblyLinearVelocity
    local position = torso.Position
    
    -- Enhanced fall detection using torso
    if state == Enum.HumanoidStateType.Freefall then
        if not isCurrentlyFalling then
            isCurrentlyFalling = true
            fallStartTime = tick()
            fallStartHeight = position.Y
        end
        
        local fallDuration = tick() - fallStartTime
        local fallDistance = fallStartHeight - position.Y
        
        if fallDuration > FALL_TIME_THRESHOLD and fallDistance > FALL_HEIGHT_THRESHOLD then
            IsFallDetected = true
            return "Falling"
        end
        
        return "Falling"
    else
        if isCurrentlyFalling then
            isCurrentlyFalling = false
            fallStartTime = 0
            fallStartHeight = 0
        end
    end
    
    -- Map state to move state
    if state == Enum.HumanoidStateType.Freefall then
        return "Falling"
    elseif state == Enum.HumanoidStateType.Jumping then
        return "Jumping"
    elseif state == Enum.HumanoidStateType.Climbing then
        return "Climbing"
    elseif state == Enum.HumanoidStateType.Swimming then
        return "Swimming"
    elseif state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics then
        return "Running"
    else
        return "Grounded"
    end
end

-- ========= ENHANCED FRAME DATA FUNCTIONS =========
local function GetFramePosition(frame)
    if not frame or not frame.Position then return Vector3.new(0, 0, 0) end
    return Vector3.new(frame.Position[1], frame.Position[2], frame.Position[3])
end

local function GetFrameCFrame(frame)
    if not frame then return CFrame.new() end
    local pos = GetFramePosition(frame)
    local look = frame.LookVector and Vector3.new(frame.LookVector[1], frame.LookVector[2], frame.LookVector[3]) or Vector3.new(0, 0, 1)
    local up = frame.UpVector and Vector3.new(frame.UpVector[1], frame.UpVector[2], frame.UpVector[3]) or Vector3.new(0, 1, 0)
    return CFrame.lookAt(pos, pos + look, up)
end

local function GetFrameVelocity(frame)
    if not frame or not frame.Velocity then return Vector3.new(0, 0, 0) end
    return Vector3.new(
        frame.Velocity[1] * VELOCITY_SCALE,
        frame.Velocity[2] * VELOCITY_Y_SCALE,
        frame.Velocity[3] * VELOCITY_SCALE
    )
end

local function GetFrameWalkSpeed(frame)
    return frame.WalkSpeed or 16
end

local function GetFrameTimestamp(frame)
    return frame.Timestamp or 0
end

-- ========= FIND NEAREST FRAME TO POSITION =========
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
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoWalkProV90"
ScreenGui.ResetOnSpawn = false
if player:FindFirstChild("PlayerGui") then
    ScreenGui.Parent = player.PlayerGui
else
    wait(2)
    ScreenGui.Parent = player:WaitForChild("PlayerGui")
end

-- ========= RECORDING STUDIO GUI (230x190) =========
local RecordingStudio = Instance.new("Frame")
RecordingStudio.Size = UDim2.fromOffset(230, 190)
RecordingStudio.Position = UDim2.new(0.5, -115, 0.5, -95)
RecordingStudio.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
RecordingStudio.BorderSizePixel = 0
RecordingStudio.Active = true
RecordingStudio.Draggable = true
RecordingStudio.Visible = false
RecordingStudio.Parent = ScreenGui

local StudioCorner = Instance.new("UICorner")
StudioCorner.CornerRadius = UDim.new(0, 10)
StudioCorner.Parent = RecordingStudio

local StudioStroke = Instance.new("UIStroke")
StudioStroke.Color = Color3.fromRGB(100, 150, 255)
StudioStroke.Thickness = 2
StudioStroke.Parent = RecordingStudio

-- Studio Header
local StudioHeader = Instance.new("Frame")
StudioHeader.Size = UDim2.new(1, 0, 0, 28)
StudioHeader.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
StudioHeader.BorderSizePixel = 0
StudioHeader.Parent = RecordingStudio

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 10)
HeaderCorner.Parent = StudioHeader

local StudioTitle = Instance.new("TextLabel")
StudioTitle.Size = UDim2.new(1, -30, 1, 0)
StudioTitle.Position = UDim2.new(0, 10, 0, 0)
StudioTitle.BackgroundTransparency = 1
StudioTitle.Text = "🎬 RECORDING STUDIO v9.0"
StudioTitle.TextColor3 = Color3.fromRGB(100, 200, 255)
StudioTitle.Font = Enum.Font.GothamBold
StudioTitle.TextSize = 11
StudioTitle.TextXAlignment = Enum.TextXAlignment.Left
StudioTitle.Parent = StudioHeader

local CloseStudioBtn = Instance.new("TextButton")
CloseStudioBtn.Size = UDim2.fromOffset(20, 20)
CloseStudioBtn.Position = UDim2.new(1, -24, 0.5, -10)
CloseStudioBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
CloseStudioBtn.Text = "×"
CloseStudioBtn.TextColor3 = Color3.new(1, 1, 1)
CloseStudioBtn.Font = Enum.Font.GothamBold
CloseStudioBtn.TextSize = 14
CloseStudioBtn.Parent = StudioHeader

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 5)
CloseCorner.Parent = CloseStudioBtn

-- Studio Content
local StudioContent = Instance.new("Frame")
StudioContent.Size = UDim2.new(1, -16, 1, -36)
StudioContent.Position = UDim2.new(0, 8, 0, 32)
StudioContent.BackgroundTransparency = 1
StudioContent.Parent = RecordingStudio

-- Helper function untuk create buttons
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
            BackgroundColor3 = Color3.fromRGB(
                math.min(color.R * 255 + 30, 255),
                math.min(color.G * 255 + 30, 255),
                math.min(color.B * 255 + 30, 255)
            )
        }):Play()
    end)
    
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = color}):Play()
    end)
    
    return btn
end

-- Top Row Buttons
local ReverseBtn = CreateStudioBtn("⏪ REVERSE", 5, 5, 64, 30, Color3.fromRGB(255, 150, 50))
local RecordBtn = CreateStudioBtn("● RECORD", 74, 5, 68, 30, Color3.fromRGB(200, 50, 60))
local SaveReplayBtn = CreateStudioBtn("💾 SAVE REPLAY", 147, 5, 68, 30, Color3.fromRGB(100, 200, 100))

-- Frame Counter
local FrameLabel = Instance.new("TextLabel")
FrameLabel.Size = UDim2.fromOffset(214, 28)
FrameLabel.Position = UDim2.fromOffset(5, 40)
FrameLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
FrameLabel.Text = "Frames: 0 / 30000"
FrameLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
FrameLabel.Font = Enum.Font.GothamBold
FrameLabel.TextSize = 10
FrameLabel.Parent = StudioContent

local FrameCorner = Instance.new("UICorner")
FrameCorner.CornerRadius = UDim.new(0, 5)
FrameCorner.Parent = FrameLabel

local FrameStroke = Instance.new("UIStroke")
FrameStroke.Color = Color3.fromRGB(60, 60, 70)
FrameStroke.Thickness = 1
FrameStroke.Parent = FrameLabel

-- Timeline Control Label
local TimelineLabel = Instance.new("TextLabel")
TimelineLabel.Size = UDim2.fromOffset(214, 20)
TimelineLabel.Position = UDim2.fromOffset(5, 73)
TimelineLabel.BackgroundTransparency = 1
TimelineLabel.Text = "Timeline Control (1 sec/step)"
TimelineLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
TimelineLabel.Font = Enum.Font.Gotham
TimelineLabel.TextSize = 8
TimelineLabel.Parent = StudioContent

-- Bottom Row Buttons
local RewindBtn = CreateStudioBtn("⏪ MUNDUR", 5, 98, 64, 35, Color3.fromRGB(80, 120, 200))
local ResumeBtn = CreateStudioBtn("▶ RESUME", 74, 98, 68, 35, Color3.fromRGB(40, 180, 80))
local ForwardBtn = CreateStudioBtn("MAJU ⏩", 147, 98, 68, 35, Color3.fromRGB(80, 120, 200))

-- Status Label
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.fromOffset(214, 20)
StatusLabel.Position = UDim2.fromOffset(5, 138)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Ready to record - R6/R15 Compatible"
StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 8
StatusLabel.Parent = StudioContent

-- Character Type Indicator
local CharTypeLabel = Instance.new("TextLabel")
CharTypeLabel.Size = UDim2.fromOffset(214, 16)
CharTypeLabel.Position = UDim2.fromOffset(5, 158)
CharTypeLabel.BackgroundTransparency = 1
CharTypeLabel.Text = "Character: Detecting..."
CharTypeLabel.TextColor3 = Color3.fromRGB(180, 180, 255)
CharTypeLabel.Font = Enum.Font.Gotham
CharTypeLabel.TextSize = 8
CharTypeLabel.Parent = StudioContent

-- ========= MAIN GUI =========
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.fromOffset(250, 280)
MainFrame.Position = UDim2.new(0.5, -125, 0.5, -140)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(60, 60, 60)
MainStroke.Thickness = 2
MainStroke.Parent = MainFrame

-- Main Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 32)
Header.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local MainHeaderCorner = Instance.new("UICorner")
MainHeaderCorner.CornerRadius = UDim.new(0, 12)
MainHeaderCorner.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -60, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "AUTO WALK PRO v9.0"
Title.TextColor3 = Color3.fromRGB(100, 255, 150)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local HideButton = Instance.new("TextButton")
HideButton.Size = UDim2.fromOffset(20, 20)
HideButton.Position = UDim2.new(1, -50, 0.5, -10)
HideButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
HideButton.Text = "_"
HideButton.TextColor3 = Color3.new(1, 1, 1)
HideButton.Font = Enum.Font.GothamBold
HideButton.TextSize = 12
HideButton.Parent = Header

local HideCorner = Instance.new("UICorner")
HideCorner.CornerRadius = UDim.new(0, 6)
HideCorner.Parent = HideButton

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.fromOffset(20, 20)
CloseButton.Position = UDim2.new(1, -25, 0.5, -10)
CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
CloseButton.Text = "×"
CloseButton.TextColor3 = Color3.new(1, 1, 1)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 14
CloseButton.Parent = Header

local CloseCorner2 = Instance.new("UICorner")
CloseCorner2.CornerRadius = UDim.new(0, 6)
CloseCorner2.Parent = CloseButton

-- Content Area
local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, -16, 1, -40)
Content.Position = UDim2.new(0, 8, 0, 36)
Content.BackgroundTransparency = 1
Content.ScrollBarThickness = 4
Content.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
Content.CanvasSize = UDim2.new(0, 0, 0, 550)
Content.Parent = MainFrame

-- Mini Button
local MiniButton = Instance.new("TextButton")
MiniButton.Size = UDim2.fromOffset(40, 40)
MiniButton.Position = UDim2.new(0, 20, 0.5, -20)
MiniButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MiniButton.Text = "AWP"
MiniButton.TextColor3 = Color3.fromRGB(100, 255, 150)
MiniButton.Font = Enum.Font.GothamBold
MiniButton.TextSize = 12
MiniButton.Visible = false
MiniButton.Active = true
MiniButton.Draggable = true
MiniButton.Parent = ScreenGui

local MiniCorner = Instance.new("UICorner")
MiniCorner.CornerRadius = UDim.new(0, 8)
MiniCorner.Parent = MiniButton

local MiniStroke = Instance.new("UIStroke")
MiniStroke.Color = Color3.fromRGB(100, 255, 150)
MiniStroke.Thickness = 2
MiniStroke.Parent = MiniButton

-- ========= MAIN GUI COMPONENTS =========
local function CreateElegantButton(text, x, y, w, h, color, parent)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(w, h)
    btn.Position = UDim2.fromOffset(x, y)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.AutoButtonColor = false
    btn.Parent = parent or Content
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 60)
    stroke.Thickness = 1
    stroke.Parent = btn
    
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(
            math.min(color.R * 255 + 20, 255),
            math.min(color.G * 255 + 20, 255), 
            math.min(color.B * 255 + 20, 255)
        )}):Play()
    end)
    
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = color}):Play()
    end)
    
    return btn
end

local function CreateElegantLabel(text, x, y, w, h, size, parent, center)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.fromOffset(w, h)
    lbl.Position = UDim2.fromOffset(x, y)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(180, 180, 200)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = size or 10
    lbl.TextXAlignment = center and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
    lbl.Parent = parent or Content
    return lbl
end

local function CreateElegantTextBox(placeholder, x, y, w, h, parent)
    local box = Instance.new("TextBox")
    box.Size = UDim2.fromOffset(w, h)
    box.Position = UDim2.fromOffset(x, y)
    box.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    box.Text = ""
    box.PlaceholderText = placeholder
    box.TextColor3 = Color3.fromRGB(200, 200, 220)
    box.Font = Enum.Font.Gotham
    box.TextSize = 10
    box.Parent = parent or Content
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = box
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 60)
    stroke.Thickness = 1
    stroke.Parent = box
    
    box.Focused:Connect(function()
        TweenService:Create(box, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(35, 35, 35)}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(100, 255, 150)}):Play()
    end)
    
    box.FocusLost:Connect(function()
        TweenService:Create(box, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(25, 25, 25)}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(60, 60, 60)}):Play()
    end)
    
    return box
end

-- Status Label (Main GUI)
local Status = CreateElegantLabel("System Ready - v9.0 R6/R15 Universal", 0, 248, 234, 20, 9, nil, true)
Status.TextColor3 = Color3.fromRGB(100, 255, 150)
Status.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Status.BackgroundTransparency = 0

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 6)
StatusCorner.Parent = Status

local StatusStroke = Instance.new("UIStroke")
StatusStroke.Color = Color3.fromRGB(60, 60, 60)
StatusStroke.Thickness = 1
StatusStroke.Parent = Status

-- Main GUI Layout
local OpenStudioBtn = CreateElegantButton("🎬 RECORDING STUDIO", 10, 10, 230, 26, Color3.fromRGB(100, 150, 255))

-- Playback Controls
local PauseBtn = CreateElegantButton("⏸ PAUSE", 10, 40, 70, 26, Color3.fromRGB(255, 150, 50))
local PlayBtn = CreateElegantButton("▶ PLAY", 85, 40, 70, 26, Color3.fromRGB(40, 180, 80))
local StopBtn = CreateElegantButton("■ STOP", 160, 40, 70, 26, Color3.fromRGB(150, 50, 60))

-- Settings
local MoveToBtn = CreateElegantButton("MoveTo: ON", 10, 70, 110, 24, Color3.fromRGB(40, 180, 80))
local VisualBtn = CreateElegantButton("Visual: OFF", 125, 70, 110, 24, Color3.fromRGB(80, 80, 80))

-- Loop Setting
local LoopBtn = CreateElegantButton("Loop: OFF", 10, 98, 110, 24, Color3.fromRGB(80, 80, 80))

-- File Management
local FileNameBox = CreateElegantTextBox("filename", 10, 126, 150, 24)
local SaveFileBtn = CreateElegantButton("SAVE", 165, 126, 35, 24, Color3.fromRGB(40, 140, 70))
local LoadFileBtn = CreateElegantButton("LOAD", 205, 126, 35, 24, Color3.fromRGB(140, 100, 40))

-- Speed Control
local SpeedMinus = CreateElegantButton("-", 10, 154, 50, 24, Color3.fromRGB(60, 60, 60))
local SpeedPlus = CreateElegantButton("+", 190, 154, 50, 24, Color3.fromRGB(60, 60, 60))

local SpeedDisplay = CreateElegantLabel("1.00x", 65, 154, 120, 24, 11, nil, true)
SpeedDisplay.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
SpeedDisplay.BackgroundTransparency = 0
SpeedDisplay.TextColor3 = Color3.fromRGB(100, 255, 150)

local SpeedCorner2 = Instance.new("UICorner")
SpeedCorner2.CornerRadius = UDim.new(0, 6)
SpeedCorner2.Parent = SpeedDisplay

local SpeedStroke = Instance.new("UIStroke")
SpeedStroke.Color = Color3.fromRGB(60, 60, 60)
SpeedStroke.Thickness = 1
SpeedStroke.Parent = SpeedDisplay

-- Character Info
local CharInfoLabel = CreateElegantLabel("Character: Detecting...", 10, 182, 230, 20, 9, nil, true)
CharInfoLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
CharInfoLabel.BackgroundTransparency = 0
CharInfoLabel.TextColor3 = Color3.fromRGB(180, 180, 255)

local CharInfoCorner = Instance.new("UICorner")
CharInfoCorner.CornerRadius = UDim.new(0, 6)
CharInfoCorner.Parent = CharInfoLabel

-- Replay List
local ReplayList = Instance.new("ScrollingFrame")
ReplayList.Size = UDim2.new(1, 0, 0, 80)
ReplayList.Position = UDim2.fromOffset(0, 206)
ReplayList.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
ReplayList.BorderSizePixel = 0
ReplayList.ScrollBarThickness = 4
ReplayList.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
ReplayList.CanvasSize = UDim2.new(0, 0, 0, 0)
ReplayList.Parent = Content

local ListCorner = Instance.new("UICorner")
ListCorner.CornerRadius = UDim.new(0, 6)
ListCorner.Parent = ReplayList

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 2)
ListLayout.Parent = ReplayList

-- ========= ENHANCED CHARACTER DETECTION UPDATE =========
local function UpdateCharacterInfo()
    local char = player.Character
    if char then
        local isR15 = IsR15Character(char)
        local charType = isR15 and "R15" or "R6"
        local torso = GetCharacterTorso(char)
        local status = torso and "✅ Ready" or "❌ No Torso"
        
        CharInfoLabel.Text = "Character: " .. charType .. " - " .. status
        CharTypeLabel.Text = "Character: " .. charType .. " - " .. status
    else
        CharInfoLabel.Text = "Character: None"
        CharTypeLabel.Text = "Character: None"
    end
end

-- ========= ROUTE VISUALIZATION =========
local routeParts = {}
local routeBeams = {}

local function ClearRouteVisualization()
    for _, part in pairs(routeParts) do
        if part and part.Parent then
            part:Destroy()
        end
    end
    for _, beam in pairs(routeBeams) do
        if beam and beam.Parent then
            beam:Destroy()
        end
    end
    routeParts = {}
    routeBeams = {}
end

local function ShowRouteVisualization(recording)
    ClearRouteVisualization()
    
    if not recording or #recording == 0 or not ShowVisualization then return end
    
    local folder = Instance.new("Folder")
    folder.Name = "RouteVisualization"
    folder.Parent = workspace
    
    local lastPart = nil
    
    for i = 1, #recording, 10 do
        local frame = recording[i]
        local pos = GetFramePosition(frame)
        
        local part = Instance.new("Part")
        part.Size = Vector3.new(0.3, 0.3, 0.3)
        part.Position = pos
        part.Anchored = true
        part.CanCollide = false
        part.Transparency = 0.4
        part.Color = Color3.fromRGB(100, 255, 150)
        part.Material = Enum.Material.Neon
        part.Shape = Enum.PartType.Ball
        part.Parent = folder
        
        table.insert(routeParts, part)
        
        if lastPart then
            local beam = Instance.new("Beam")
            beam.Attachment0 = Instance.new("Attachment")
            beam.Attachment0.Parent = lastPart
            beam.Attachment1 = Instance.new("Attachment")
            beam.Attachment1.Parent = part
            beam.Color = ColorSequence.new(Color3.fromRGB(100, 255, 150))
            beam.Width0 = 0.15
            beam.Width1 = 0.15
            beam.Brightness = 2
            beam.Parent = folder
            
            table.insert(routeBeams, beam)
            table.insert(routeBeams, beam.Attachment0)
            table.insert(routeBeams, beam.Attachment1)
        end
        
        lastPart = part
    end
end

-- ========= ENHANCED REVERSE SYSTEM =========
local function FindLastSafeFrame()
    if not CurrentRecording or not CurrentRecording.Frames or #CurrentRecording.Frames == 0 then 
        return 0 
    end
    
    for i = #CurrentRecording.Frames, 1, -1 do
        local frame = CurrentRecording.Frames[i]
        if frame and (frame.MoveState == "Grounded" or frame.MoveState == "Running") then
            return i
        end
    end
    
    return #CurrentRecording.Frames
end

local function ReverseToSafePosition()
    if not CurrentRecording or not CurrentRecording.Frames or #CurrentRecording.Frames == 0 then
        StatusLabel.Text = "❌ No recording to reverse!"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then 
        StatusLabel.Text = "❌ Character not found!"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return 
    end
    
    local hrp = char.HumanoidRootPart
    
    local safeFrameIndex = FindLastSafeFrame()
    
    if safeFrameIndex == 0 then
        StatusLabel.Text = "❌ No safe position found!"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    if safeFrameIndex < 1 or safeFrameIndex > #CurrentRecording.Frames then
        StatusLabel.Text = "❌ Invalid safe frame!"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    local safeFrame = CurrentRecording.Frames[safeFrameIndex]
    if safeFrame then
        local success, result = pcall(function()
            hrp.CFrame = GetFrameCFrame(safeFrame)
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end)
        
        if not success then
            StatusLabel.Text = "❌ Error during teleport!"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            return
        end
        
        for i = #CurrentRecording.Frames, safeFrameIndex + 1, -1 do
            table.remove(CurrentRecording.Frames, i)
        end
        
        UpdateStudioUI()
        StatusLabel.Text = "⏪ Reversed to safe frame " .. safeFrameIndex
        StatusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
        
        IsFallDetected = false
        isCurrentlyFalling = false
    else
        StatusLabel.Text = "❌ Safe frame data corrupted!"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    end
end

-- ========= ENHANCED RECORDING STUDIO SYSTEM =========
local function UpdateStudioUI()
    if FrameLabel then
        FrameLabel.Text = "Frames: " .. (CurrentRecording.Frames and #CurrentRecording.Frames or 0) .. " / 30000"
    end
end

local function StartStudioRecording()
    if IsRecording then return end
    
    local char = player.Character
    if not char then
        StatusLabel.Text = "❌ Character not found!"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    local torso = GetCharacterTorso(char)
    if not torso then
        StatusLabel.Text = "❌ No torso found!"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    IsRecording = true
    IsFallDetected = false
    isCurrentlyFalling = false
    LastSafeFrame = 0
    CurrentRecording = {Frames = {}, StartTime = tick(), Name = "Studio_" .. os.date("%H%M%S")}
    lastRecordTime = 0
    lastRecordPos = nil
    
    RecordBtn.Text = "⏹ STOP"
    RecordBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 60)
    StatusLabel.Text = "🎬 Recording... Move your character"
    StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
    
    recordConnection = RunService.Heartbeat:Connect(function()
        local char = player.Character
        if not char or #CurrentRecording.Frames >= MAX_FRAMES then
            return
        end
        
        local torso = GetCharacterTorso(char)
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        
        if not torso or not hrp then return end
        
        local moveState = GetCurrentMoveState(char)
        
        if IsFallDetected then
            StatusLabel.Text = "⚠️ FALL DETECTED! Click REVERSE to go back to safe position"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 150, 50)
            return
        end
        
        if moveState == "Grounded" or moveState == "Running" then
            LastSafeFrame = #CurrentRecording.Frames
        end
        
        local now = tick()
        if (now - lastRecordTime) < (1 / RECORDING_FPS) then return end
        
        local currentPos = torso.Position
        local currentVelocity = torso.AssemblyLinearVelocity
        
        if lastRecordPos and (currentPos - lastRecordPos).Magnitude < MIN_DISTANCE_THRESHOLD and moveState == "Grounded" then
            lastRecordTime = now
            return
        end
        
        local cf = hrp.CFrame
        table.insert(CurrentRecording.Frames, {
            Position = {torso.Position.X, torso.Position.Y, torso.Position.Z},
            LookVector = {cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z},
            UpVector = {cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z},
            Velocity = {currentVelocity.X, currentVelocity.Y, currentVelocity.Z},
            MoveState = moveState,
            WalkSpeed = hum and hum.WalkSpeed or 16,
            Timestamp = now - CurrentRecording.StartTime,
            CharacterType = IsR15Character(char) and "R15" or "R6"
        })
        
        lastRecordTime = now
        lastRecordPos = currentPos
        
        UpdateStudioUI()
    end)
end

local function StopStudioRecording()
    IsRecording = false
    IsFallDetected = false
    isCurrentlyFalling = false
    
    if recordConnection then
        recordConnection:Disconnect()
        recordConnection = nil
    end
    
    RecordBtn.Text = "● RECORD"
    RecordBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
    
    if CurrentRecording.Frames and #CurrentRecording.Frames > 0 then
        StatusLabel.Text = "✅ Recording stopped (" .. #CurrentRecording.Frames .. " frames)"
        StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
    else
        StatusLabel.Text = "Recording stopped (0 frames)"
        StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
    end
end

local function RewindTimeline()
    if not CurrentRecording or not CurrentRecording.Frames or #CurrentRecording.Frames == 0 then 
        StatusLabel.Text = "❌ No frames to rewind!"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return 
    end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = char.HumanoidRootPart
    
    local framesToRewind = TIMELINE_STEP_SECONDS * RECORDING_FPS
    local targetFrame = math.max(1, #CurrentRecording.Frames - framesToRewind)
    
    local targetFrameData = CurrentRecording.Frames[targetFrame]
    if targetFrameData then
        local success = pcall(function()
            hrp.CFrame = GetFrameCFrame(targetFrameData)
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end)
        
        if success then
            StatusLabel.Text = "⏪ Rewound to frame " .. targetFrame
            StatusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
        else
            StatusLabel.Text = "❌ Error during rewind!"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
    end
end

local function ForwardTimeline()
    if not CurrentRecording or not CurrentRecording.Frames or #CurrentRecording.Frames == 0 then 
        StatusLabel.Text = "❌ No frames to forward!"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return 
    end
    
    StatusLabel.Text = "⏩ Use RESUME to continue recording from current position"
    StatusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
end

local function ResumeStudioRecording()
    if IsRecording then
        StatusLabel.Text = "▶ Recording resumed from current position"
        StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
        
        IsFallDetected = false
        isCurrentlyFalling = false
    else
        StatusLabel.Text = "❌ Not recording - Click RECORD first"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    end
end

-- ========= FIXED SAVE SYSTEM =========
local function SaveStudioRecording()
    if not CurrentRecording or not CurrentRecording.Frames or #CurrentRecording.Frames == 0 then
        StatusLabel.Text = "❌ No frames to save!"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    local recordingName = "Studio_" .. os.date("%H%M%S")
    
    -- FIX: Ensure RecordedMovements is properly initialized
    if not RecordedMovements then
        RecordedMovements = {}
    end
    
    -- FIX: Create a clean copy of the recording data
    local recordingCopy = {}
    for i, frame in ipairs(CurrentRecording.Frames) do
        recordingCopy[i] = {
            Position = frame.Position and {frame.Position[1], frame.Position[2], frame.Position[3]} or {0, 0, 0},
            LookVector = frame.LookVector and {frame.LookVector[1], frame.LookVector[2], frame.LookVector[3]} or {0, 0, 1},
            UpVector = frame.UpVector and {frame.UpVector[1], frame.UpVector[2], frame.UpVector[3]} or {0, 1, 0},
            Velocity = frame.Velocity and {frame.Velocity[1], frame.Velocity[2], frame.Velocity[3]} or {0, 0, 0},
            MoveState = frame.MoveState or "Grounded",
            WalkSpeed = frame.WalkSpeed or 16,
            Timestamp = frame.Timestamp or 0,
            CharacterType = frame.CharacterType or "Unknown"
        }
    end
    
    RecordedMovements[recordingName] = recordingCopy
    UpdateReplayList()
    
    StatusLabel.Text = "💾 Saved: " .. recordingName .. " (" .. #CurrentRecording.Frames .. " frames)"
    StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
    
    UpdateStatus("Saved: " .. recordingName .. " (" .. #CurrentRecording.Frames .. " frames)")
    
    CurrentRecording = {Frames = {}, StartTime = 0, Name = "Studio_" .. os.date("%H%M%S")}
    UpdateStudioUI()
    
    wait(1.5)
    RecordingStudio.Visible = false
    MainFrame.Visible = true
end

-- ========= ENHANCED REPLAY LIST MANAGEMENT =========
local function UpdateReplayList()
    CleanupConnections()
    
    for _, child in pairs(ReplayList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    if not RecordedMovements then
        RecordedMovements = {}
        return
    end
    
    local recordingNames = {}
    for name, _ in pairs(RecordedMovements) do
        table.insert(recordingNames, name)
    end
    table.sort(recordingNames)
    
    local yPos = 0
    for index, name in ipairs(recordingNames) do
        local rec = RecordedMovements[name]
        local item = Instance.new("Frame")
        item.Size = UDim2.new(1, -8, 0, 16)
        item.Position = UDim2.new(0, 4, 0, yPos)
        item.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        item.Parent = ReplayList
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = item
        
        local nameBox = Instance.new("TextBox")
        nameBox.Size = UDim2.new(0, 120, 1, 0)
        nameBox.Position = UDim2.new(0, 4, 0, 0)
        nameBox.BackgroundTransparency = 1
        nameBox.Text = name
        nameBox.TextColor3 = Color3.new(1, 1, 1)
        nameBox.Font = Enum.Font.Gotham
        nameBox.TextSize = 8
        nameBox.PlaceholderText = "Rename..."
        nameBox.Parent = item
        
        local playBtn = Instance.new("TextButton")
        playBtn.Size = UDim2.fromOffset(30, 12)
        playBtn.Position = UDim2.new(1, -60, 0.5, -6)
        playBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
        playBtn.Text = "PLAY"
        playBtn.TextColor3 = Color3.new(1, 1, 1)
        playBtn.Font = Enum.Font.GothamBold
        playBtn.TextSize = 6
        playBtn.AutoButtonColor = false
        playBtn.Parent = item
        
        local playCorner = Instance.new("UICorner")
        playCorner.CornerRadius = UDim.new(0, 3)
        playCorner.Parent = playBtn
        
        local delBtn = Instance.new("TextButton")
        delBtn.Size = UDim2.fromOffset(30, 12)
        delBtn.Position = UDim2.new(1, -25, 0.5, -6)
        delBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
        delBtn.Text = "DEL"
        delBtn.TextColor3 = Color3.new(1, 1, 1)
        delBtn.Font = Enum.Font.GothamBold
        delBtn.TextSize = 6
        delBtn.AutoButtonColor = false
        delBtn.Parent = item
        
        local delCorner = Instance.new("UICorner")
        delCorner.CornerRadius = UDim.new(0, 3)
        delCorner.Parent = delBtn
        
        nameBox.FocusLost:Connect(function(enterPressed)
            if enterPressed and nameBox.Text ~= "" and nameBox.Text ~= name then
                RecordedMovements[nameBox.Text] = RecordedMovements[name]
                RecordedMovements[name] = nil
                UpdateReplayList()
            else
                nameBox.Text = name
            end
        end)
        
        local playConn = playBtn.MouseButton1Click:Connect(function()
            if not IsPlaying then
                PlayRecording(name)
            end
        end)
        AddConnection(playConn)
        
        local delConn = delBtn.MouseButton1Click:Connect(function()
            RecordedMovements[name] = nil
            UpdateReplayList()
            UpdateStatus("Deleted: " .. name)
        end)
        AddConnection(delConn)
        
        yPos = yPos + 18
    end
    
    ReplayList.CanvasSize = UDim2.new(0, 0, 0, yPos)
end

-- ========= STUDIO BUTTON EVENTS =========
RecordBtn.MouseButton1Click:Connect(function()
    if IsRecording then
        StopStudioRecording()
    else
        StartStudioRecording()
    end
end)

ReverseBtn.MouseButton1Click:Connect(function()
    local success, errorMsg = pcall(ReverseToSafePosition)
    if not success then
        StatusLabel.Text = "❌ Reverse Error: " .. tostring(errorMsg)
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    end
end)

RewindBtn.MouseButton1Click:Connect(function()
    local success, errorMsg = pcall(RewindTimeline)
    if not success then
        StatusLabel.Text = "❌ Rewind Error: " .. tostring(errorMsg)
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    end
end)

ForwardBtn.MouseButton1Click:Connect(function()
    local success, errorMsg = pcall(ForwardTimeline)
    if not success then
        StatusLabel.Text = "❌ Forward Error: " .. tostring(errorMsg)
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    end
end)

ResumeBtn.MouseButton1Click:Connect(function()
    local success, errorMsg = pcall(ResumeStudioRecording)
    if not success then
        StatusLabel.Text = "❌ Resume Error: " .. tostring(errorMsg)
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    end
end)

SaveReplayBtn.MouseButton1Click:Connect(function()
    local success, errorMsg = pcall(SaveStudioRecording)
    if not success then
        StatusLabel.Text = "❌ Save Error: " .. tostring(errorMsg)
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    end
end)

CloseStudioBtn.MouseButton1Click:Connect(function()
    if IsRecording then
        StopStudioRecording()
    end
    RecordingStudio.Visible = false
    MainFrame.Visible = true
end)

-- ========= ENHANCED PLAYBACK SYSTEMS =========
function PlayRecordingWithMoveTo(recording, startFrame)
    if not recording or #recording == 0 then return end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
    if not hum or not hrp then return end
    
    task.spawn(function()
        hum.AutoRotate = true
        hum.PlatformStand = false
        
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
        
        local currentFrame = startFrame or 1
        
        while IsPlaying and currentFrame <= #recording do
            if IsPaused then
                if pauseStartTime == 0 then
                    pauseStartTime = tick()
                end
                RunService.Heartbeat:Wait()
                continue
            else
                if pauseStartTime > 0 then
                    totalPausedDuration = totalPausedDuration + (tick() - pauseStartTime)
                    pauseStartTime = 0
                end
            end
            
            char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then break end
            hum = char:FindFirstChildOfClass("Humanoid")
            hrp = char:FindFirstChild("HumanoidRootPart")
            if not hum or not hrp then break end
            
            local currentTime = tick()
            local effectiveTime = (currentTime - playbackStartTime - totalPausedDuration) * CurrentSpeed
            
            local targetFrame = currentFrame
            local framesSkipped = 0
            
            while targetFrame < #recording 
                and framesSkipped < MAX_FRAME_JUMP
                and GetFrameTimestamp(recording[targetFrame + 1]) <= effectiveTime do
                targetFrame = targetFrame + 1
                framesSkipped = framesSkipped + 1
            end
            
            if targetFrame > #recording then
                targetFrame = #recording
            end
            
            local frame = recording[targetFrame]
            if not frame then break end
            
            currentFrame = targetFrame
            currentPlaybackFrame = targetFrame
            
            local success, errorMsg = pcall(function()
                local targetPos = GetFramePosition(frame)
                local moveState = frame.MoveState
                
                local scaledVelocity = GetFrameVelocity(frame) * CurrentSpeed
                hum.WalkSpeed = GetFrameWalkSpeed(frame) * CurrentSpeed
                
                local distanceToTarget = (hrp.Position - targetPos).Magnitude
                
                -- ENHANCED: Height adjustment for R15 characters
                local adjustedPos = targetPos
                local currentCharType = IsR15Character(char) and "R15" or "R6"
                local recordedCharType = frame.CharacterType or "Unknown"
                
                if currentCharType == "R15" and recordedCharType == "R6" then
                    -- Adjust height for R15 playing R6 recording
                    adjustedPos = Vector3.new(targetPos.X, targetPos.Y + GetCharacterHeight(char), targetPos.Z)
                elseif currentCharType == "R6" and recordedCharType == "R15" then
                    -- Adjust height for R6 playing R15 recording  
                    adjustedPos = Vector3.new(targetPos.X, targetPos.Y - GetCharacterHeight(char), targetPos.Z)
                end
                
                if distanceToTarget > 15 then
                    hrp.CFrame = CFrame.new(adjustedPos)
                    currentFrame = currentFrame + 1
                elseif distanceToTarget > MOVETO_REACH_DISTANCE then
                    hum:MoveTo(adjustedPos)
                else
                    currentFrame = currentFrame + 1
                end
                
                if moveState ~= lastMoveState then
                    lastMoveState = moveState
                    
                    if moveState == "Climbing" then
                        hum:ChangeState(Enum.HumanoidStateType.Climbing)
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
            
            if not success then
                break
            end
            
            if currentFrame >= #recording then break end
            RunService.Heartbeat:Wait()
        end
        
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
        
        if AutoLoop and IsPlaying then
            currentPlaybackFrame = 1
            playbackStartTime = tick()
            totalPausedDuration = 0
            PlayRecordingWithMoveTo(recording, 1)
        else
            IsPlaying = false
            IsPaused = false
            lastMoveState = nil
            CompleteCharacterReset(char)
            UpdateStatus("🎉 Playback Complete!")
        end
    end)
end

function PlayRecordingWithCFrame(recording, startFrame)
    if not recording or #recording == 0 then return end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
    if not hum or not hrp then return end
    
    task.spawn(function()
        hum.AutoRotate = false
        hum.PlatformStand = false
        
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
        
        local currentFrame = startFrame or 1
        
        while IsPlaying and currentFrame <= #recording do
            if IsPaused then
                if pauseStartTime == 0 then
                    pauseStartTime = tick()
                end
                RunService.Heartbeat:Wait()
                continue
            else
                if pauseStartTime > 0 then
                    totalPausedDuration = totalPausedDuration + (tick() - pauseStartTime)
                    pauseStartTime = 0
                end
            end
            
            char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then break end
            hum = char:FindFirstChildOfClass("Humanoid")
            hrp = char:FindFirstChild("HumanoidRootPart")
            if not hum or not hrp then break end
            
            local currentTime = tick()
            local effectiveTime = (currentTime - playbackStartTime - totalPausedDuration) * CurrentSpeed
            
            local targetFrame = currentFrame
            local framesSkipped = 0
            
            while targetFrame < #recording 
                and framesSkipped < MAX_FRAME_JUMP
                and GetFrameTimestamp(recording[targetFrame + 1]) <= effectiveTime do
                targetFrame = targetFrame + 1
                framesSkipped = framesSkipped + 1
            end
            
            if targetFrame > #recording then
                targetFrame = #recording
            end
            
            local frame = recording[targetFrame]
            if not frame then break end
            
            currentFrame = targetFrame
            currentPlaybackFrame = targetFrame
            
            local success, errorMsg = pcall(function()
                -- ENHANCED: Height adjustment for character compatibility
                local targetPos = GetFramePosition(frame)
                local currentCharType = IsR15Character(char) and "R15" or "R6"
                local recordedCharType = frame.CharacterType or "Unknown"
                
                if currentCharType == "R15" and recordedCharType == "R6" then
                    targetPos = Vector3.new(targetPos.X, targetPos.Y + GetCharacterHeight(char), targetPos.Z)
                elseif currentCharType == "R6" and recordedCharType == "R15" then
                    targetPos = Vector3.new(targetPos.X, targetPos.Y - GetCharacterHeight(char), targetPos.Z)
                end
                
                local adjustedCFrame = CFrame.lookAt(targetPos, targetPos + Vector3.new(frame.LookVector[1], frame.LookVector[2], frame.LookVector[3]))
                
                hrp.CFrame = adjustedCFrame
                hrp.AssemblyLinearVelocity = GetFrameVelocity(frame) * CurrentSpeed
                hum.WalkSpeed = GetFrameWalkSpeed(frame) * CurrentSpeed
                
                local moveState = frame.MoveState
                
                if moveState ~= lastMoveState then
                    lastMoveState = moveState
                    
                    if moveState == "Climbing" then
                        hum:ChangeState(Enum.HumanoidStateType.Climbing)
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
            
            if not success then
                break
            end
            
            if currentFrame >= #recording then break end
            RunService.Heartbeat:Wait()
        end
        
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
        
        if AutoLoop and IsPlaying then
            currentPlaybackFrame = 1
            playbackStartTime = tick()
            totalPausedDuration = 0
            PlayRecordingWithCFrame(recording, 1)
        else
            IsPlaying = false
            IsPaused = false
            lastMoveState = nil
            CompleteCharacterReset(char)
            UpdateStatus("🎉 Playback Complete!")
        end
    end)
end

function PlayRecording(name)
    if IsPlaying then return end
    
    local recording = name and RecordedMovements[name] or next(RecordedMovements) and (select(2, next(RecordedMovements)))
    if not recording then
        UpdateStatus("ERROR: No recordings!")
        return
    end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        UpdateStatus("ERROR: Character not found!")
        return
    end
    
    currentRecordingName = name or next(RecordedMovements)
    
    IsPlaying = true
    IsPaused = false
    totalPausedDuration = 0
    pauseStartTime = 0
    lastMoveState = nil
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local nearestFrame, distance = FindNearestFrame(recording, hrp.Position)
    
    if distance <= ROUTE_PROXIMITY_THRESHOLD then
        currentPlaybackFrame = nearestFrame
        playbackStartTime = tick() - (GetFrameTimestamp(recording[nearestFrame]) / CurrentSpeed)
    else
        currentPlaybackFrame = 1
        playbackStartTime = tick()
        
        local startPos = GetFramePosition(recording[1])
        if (hrp.Position - startPos).Magnitude > 50 then
            hrp.CFrame = CFrame.new(startPos)
        end
    end
    
    if UseMoveTo then
        PlayRecordingWithMoveTo(recording, currentPlaybackFrame)
    else
        PlayRecordingWithCFrame(recording, currentPlaybackFrame)
    end
end

function StopPlayback()
    if not IsPlaying then return end
    IsPlaying = false
    IsPaused = false
    lastMoveState = nil
    
    if moveToConnection then
        moveToConnection:Disconnect()
        moveToConnection = nil
    end
    
    local char = player.Character
    if char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
        
        CompleteCharacterReset(char)
    end
    
    UpdateStatus("Playback Stopped")
end

function PauseResumePlayback()
    if not IsPlaying then return end
    IsPaused = not IsPaused
    
    if IsPaused then
        UpdateStatus("⏸️ Playback Paused")
    else
        UpdateStatus("▶️ Playback Resumed")
    end
end

function UpdateStatus(msg)
    if Status then
        Status.Text = msg
    end
end

-- ========= SPEED CONTROL =========
local function UpdateSpeedDisplay()
    SpeedDisplay.Text = string.format("%.2fx", CurrentSpeed)
end

SpeedMinus.MouseButton1Click:Connect(function()
    if CurrentSpeed > 0.5 then
        CurrentSpeed = math.max(0.5, CurrentSpeed - 0.25)
        UpdateSpeedDisplay()
        UpdateStatus("Speed: " .. string.format("%.2f", CurrentSpeed) .. "x")
    end
end)

SpeedPlus.MouseButton1Click:Connect(function()
    if CurrentSpeed < 10 then
        CurrentSpeed = math.min(10, CurrentSpeed + 0.25)
        UpdateSpeedDisplay()
        UpdateStatus("Speed: " .. string.format("%.2f", CurrentSpeed) .. "x")
    end
end)

-- ========= FIXED FILE MANAGEMENT =========
local function SaveToFile()
    local filename = FileNameBox.Text
    if filename == "" then filename = "MyWalk" end
    filename = filename:gsub("[^%w%s%-_]", "") .. ".json"
    
    if not RecordedMovements or not next(RecordedMovements) then
        UpdateStatus("ERROR: No recordings to save!")
        return
    end
    
    local success, errorMsg = pcall(function()
        -- FIX: Ensure all data is properly serializable
        local serializableRecordings = {}
        for name, recording in pairs(RecordedMovements) do
            serializableRecordings[name] = recording
        end
        
        local data = {
            recordings = serializableRecordings,
            settings = {
                speed = CurrentSpeed,
                autoLoop = AutoLoop,
                useMoveTo = UseMoveTo,
                showVisualization = ShowVisualization
            },
            version = "9.0"
        }
        
        -- FIX: Use proper JSON encoding
        local jsonData = HttpService:JSONEncode(data)
        writefile(filename, jsonData)
        UpdateStatus("Saved: " .. filename)
    end)
    
    if not success then
        UpdateStatus("ERROR: Save failed - " .. tostring(errorMsg))
    end
end

local function LoadFromFile()
    local filename = FileNameBox.Text
    if filename == "" then filename = "MyWalk" end
    filename = filename:gsub("[^%w%s%-_]", "") .. ".json"
    
    local success, errorMsg = pcall(function()
        if not isfile or not isfile(filename) then
            UpdateStatus("ERROR: File not found")
            return
        end
        
        local fileContent = readfile(filename)
        local data = HttpService:JSONDecode(fileContent)
        
        RecordedMovements = data.recordings or {}
        CurrentSpeed = data.settings and data.settings.speed or 1
        AutoLoop = data.settings and data.settings.autoLoop or false
        UseMoveTo = data.settings and data.settings.useMoveTo or true
        ShowVisualization = data.settings and data.settings.showVisualization or false
        
        UpdateSpeedDisplay()
        MoveToBtn.Text = "MoveTo: " .. (UseMoveTo and "ON" or "OFF")
        MoveToBtn.BackgroundColor3 = UseMoveTo and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(80, 80, 80)
        VisualBtn.Text = "Visual: " .. (ShowVisualization and "ON" or "OFF") 
        VisualBtn.BackgroundColor3 = ShowVisualization and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(80, 80, 80)
        LoopBtn.Text = "Loop: " .. (AutoLoop and "ON" or "OFF")
        LoopBtn.BackgroundColor3 = AutoLoop and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(80, 80, 80)
        
        UpdateReplayList()
        UpdateStatus("Loaded: " .. filename)
    end)
    
    if not success then
        UpdateStatus("ERROR: Load failed - " .. tostring(errorMsg))
    end
end

-- ========= MAIN GUI BUTTON EVENTS =========
OpenStudioBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    RecordingStudio.Visible = true
    StatusLabel.Text = "🎬 Recording Studio Ready - R6/R15 Universal"
    StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
    UpdateCharacterInfo()
end)

PauseBtn.MouseButton1Click:Connect(function()
    PauseResumePlayback()
end)

PlayBtn.MouseButton1Click:Connect(function()
    if IsPlaying and IsPaused then
        PauseResumePlayback()
    else
        PlayRecording()
    end
end)

StopBtn.MouseButton1Click:Connect(function()
    StopPlayback()
end)

MoveToBtn.MouseButton1Click:Connect(function()
    UseMoveTo = not UseMoveTo
    MoveToBtn.Text = "MoveTo: " .. (UseMoveTo and "ON" or "OFF")
    MoveToBtn.BackgroundColor3 = UseMoveTo and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(80, 80, 80)
    UpdateStatus("MoveTo: " .. (UseMoveTo and "ON" or "OFF"))
end)

VisualBtn.MouseButton1Click:Connect(function()
    ShowVisualization = not ShowVisualization
    VisualBtn.Text = "Visual: " .. (ShowVisualization and "ON" or "OFF")
    VisualBtn.BackgroundColor3 = ShowVisualization and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(80, 80, 80)
    if ShowVisualization then
        local recording = currentRecordingName and RecordedMovements[currentRecordingName]
        if not recording and next(RecordedMovements) then
            recording = select(2, next(RecordedMovements))
        end
        if recording then
            ShowRouteVisualization(recording)
        end
    else
        ClearRouteVisualization()
    end
    UpdateStatus("Visual: " .. (ShowVisualization and "ON" or "OFF"))
end)

LoopBtn.MouseButton1Click:Connect(function()
    AutoLoop = not AutoLoop
    LoopBtn.Text = "Loop: " .. (AutoLoop and "ON" or "OFF")
    LoopBtn.BackgroundColor3 = AutoLoop and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(80, 80, 80)
    UpdateStatus("Auto Loop: " .. (AutoLoop and "ON" or "OFF"))
end)

SaveFileBtn.MouseButton1Click:Connect(SaveToFile)
LoadFileBtn.MouseButton1Click:Connect(LoadFromFile)

HideButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    MiniButton.Visible = true
end)

MiniButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    MiniButton.Visible = false
end)

CloseButton.MouseButton1Click:Connect(function()
    if IsRecording then StopStudioRecording() end
    if IsPlaying then StopPlayback() end
    CleanupConnections()
    ClearRouteVisualization()
    ScreenGui:Destroy()
end)

-- ========= HOTKEYS =========
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    if input.KeyCode == Enum.KeyCode.F9 then
        if RecordingStudio.Visible then
            if IsRecording then
                StopStudioRecording()
            else
                StartStudioRecording()
            end
        end
    elseif input.KeyCode == Enum.KeyCode.F10 then
        if IsPlaying then 
            StopPlayback() 
        else 
            PlayRecording() 
        end
    elseif input.KeyCode == Enum.KeyCode.F11 then
        MainFrame.Visible = not MainFrame.Visible
        MiniButton.Visible = not MainFrame.Visible
    elseif input.KeyCode == Enum.KeyCode.F7 then
        PauseResumePlayback()
    elseif input.KeyCode == Enum.KeyCode.F8 then
        if RecordingStudio.Visible then
            RecordingStudio.Visible = false
            MainFrame.Visible = true
        else
            MainFrame.Visible = false
            RecordingStudio.Visible = true
        end
    end
end)

-- ========= INITIALIZATION =========
-- Initialize RecordedMovements if nil
if not RecordedMovements then
    RecordedMovements = {}
end

UpdateReplayList()
UpdateCharacterInfo()
UpdateStatus("🎬 Auto Walk Pro v9.0 - R6/R15 Universal Ready!")
UpdateSpeedDisplay()

-- Auto character info update
RunService.Heartbeat:Connect(function()
    UpdateCharacterInfo()
end)

wait(1)
UpdateStatus("✅ All Systems Operational - R6/R15 Universal Support Active")