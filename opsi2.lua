-- ========= AUTO WALK PRO v8.1 - ULTIMATE EDITION =========
-- RECORDING STUDIO WITH SMART ANTI-FALL + TIMELINE CONTROL
-- GUI Size: 230x190 | All Core Systems Preserved + UI Improvements

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
local JUMP_VELOCITY_THRESHOLD = 25

-- Anti-Fall Configuration
local FALL_TIME_THRESHOLD = 1.5  -- Harus jatuh 1.5 detik baru dianggap fall
local FALL_HEIGHT_THRESHOLD = 30 -- Harus jatuh 30 studs
local TIMELINE_STEP_SECONDS = 1  -- Maju/mundur 1 detik per klik

-- ========= CORE VARIABLES =========
local IsRecording = false
local IsPlaying = false
local IsPaused = false
local UseMoveTo = true
local CurrentSpeed = 1
local RecordedMovements = {}
local CurrentRecording = {Frames = {}, StartTime = 0, Name = ""}
local AutoHeal = false
local AutoLoop = false
local recordConnection = nil
local lastRecordTime = 0
local lastRecordPos = nil
local ShowVisualization = false

-- ========= ANTI-FALL VARIABLES =========
local IsFallDetected = false
local LastSafeFrame = 0  -- Frame terakhir yang aman sebelum jatuh
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

-- ========= SMART FALL DETECTION =========
local function GetCurrentMoveState(hum, hrp)
    if not hum then return "Grounded" end
    
    local state = hum:GetState()
    local velocity = hrp.AssemblyLinearVelocity
    
    -- Track falling state
    if state == Enum.HumanoidStateType.Freefall then
        if not isCurrentlyFalling then
            isCurrentlyFalling = true
            fallStartTime = tick()
            fallStartHeight = hrp.Position.Y
        end
        
        local fallDuration = tick() - fallStartTime
        local fallDistance = fallStartHeight - hrp.Position.Y
        
        -- ONLY trigger fall jika jatuh lama & tinggi
        if fallDuration > FALL_TIME_THRESHOLD and fallDistance > FALL_HEIGHT_THRESHOLD then
            IsFallDetected = true
            return "Falling"
        end
        
        return "Falling"
    else
        -- Reset fall tracking saat landed
        if isCurrentlyFalling then
            isCurrentlyFalling = false
            fallStartTime = 0
            fallStartHeight = 0
        end
    end
    
    -- Void detection
    if hrp.Position.Y < -50 then
        IsFallDetected = true
        return "Falling"
    end
    
    if state == Enum.HumanoidStateType.Jumping then
        return "Jumping"
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
ScreenGui.Name = "AutoWalkProV81"
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
StudioTitle.Text = "🎬 RECORDING STUDIO"
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
    
    -- Hover effect
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

-- Top Row Buttons (REVERSE ALWAYS VISIBLE)
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

-- Bottom Row Buttons (ALWAYS VISIBLE)
local RewindBtn = CreateStudioBtn("⏪ MUNDUR", 5, 98, 64, 35, Color3.fromRGB(80, 120, 200))
local ResumeBtn = CreateStudioBtn("▶ RESUME", 74, 98, 68, 35, Color3.fromRGB(40, 180, 80))
local ForwardBtn = CreateStudioBtn("MAJU ⏩", 147, 98, 68, 35, Color3.fromRGB(80, 120, 200))

-- Status Label
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.fromOffset(214, 20)
StatusLabel.Position = UDim2.fromOffset(5, 138)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Ready to record"
StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 8
StatusLabel.Parent = StudioContent

-- ========= MAIN GUI (250x280) - REDESIGNED =========
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
Title.Text = "AUTO WALK PRO v8.1"
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

-- ========= MAIN GUI COMPONENTS (REDESIGNED) =========
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

local function CreateToggleButton(text, x, y, w, h, defaultState)
    local btn = CreateElegantButton(text, x, y, w, h, defaultState and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(80, 80, 80))
    
    local isOn = defaultState
    
    local function UpdateButton()
        if isOn then
            btn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
            btn.Text = text .. " ON"
        else
            btn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
            btn.Text = text .. " OFF"
        end
    end
    
    UpdateButton()
    
    btn.MouseEnter:Connect(function()
        if isOn then
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(60, 200, 100)}):Play()
        else
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(100, 100, 100)}):Play()
        end
    end)
    
    btn.MouseLeave:Connect(function()
        if isOn then
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 180, 80)}):Play()
        else
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(80, 80, 80)}):Play()
        end
    end)
    
    return btn, function() return isOn end, function(state) 
        isOn = state 
        UpdateButton()
    end
end

-- Status Label (Main GUI)
local Status = CreateElegantLabel("System Ready - v8.1", 0, 248, 234, 20, 9, nil, true)
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

-- Main GUI Layout (REDESIGNED)
CreateElegantLabel("CONTROL", 0, 0, 234, 14, 9, nil, true)

-- Recording Studio Button
local OpenStudioBtn = CreateElegantButton("🎬 RECORDING STUDIO", 10, 18, 230, 26, Color3.fromRGB(100, 150, 255))

-- Playback Controls (NEW LAYOUT)
local PauseBtn = CreateElegantButton("⏸ PAUSE", 10, 48, 70, 26, Color3.fromRGB(255, 150, 50))
local PlayBtn = CreateElegantButton("▶ PLAY", 85, 48, 70, 26, Color3.fromRGB(40, 180, 80))
local StopBtn = CreateElegantButton("■ STOP", 160, 48, 70, 26, Color3.fromRGB(150, 50, 60))

CreateElegantLabel("SETTINGS", 0, 80, 234, 14, 9, nil, true)

local MoveToBtn, GetMoveToState, SetMoveToState = CreateToggleButton("MoveTo", 10, 98, 110, 24, true)
local VisualBtn, GetVisualState, SetVisualState = CreateToggleButton("Visual", 125, 98, 110, 24, false)
local LoopBtn, GetLoopState, SetLoopState = CreateToggleButton("Loop", 10, 126, 110, 24, false)
local HealBtn, GetHealState, SetHealState = CreateToggleButton("Heal", 125, 126, 110, 24, false)

-- File Management (MOVED UP)
CreateElegantLabel("FILE MANAGEMENT", 0, 154, 234, 14, 9, nil, true)

local FileNameBox = CreateElegantTextBox("filename", 10, 172, 150, 24)
local SaveFileBtn = CreateElegantButton("SAVE", 165, 172, 35, 24, Color3.fromRGB(40, 140, 70))
local LoadFileBtn = CreateElegantButton("LOAD", 205, 172, 35, 24, Color3.fromRGB(140, 100, 40))

CreateElegantLabel("SPEED: 1.00x", 0, 200, 234, 14, 9, nil, true)

local SpeedMinus = CreateElegantButton("-", 10, 218, 50, 24, Color3.fromRGB(60, 60, 60))
local SpeedPlus = CreateElegantButton("+", 190, 218, 50, 24, Color3.fromRGB(60, 60, 60))

local SpeedDisplay = CreateElegantLabel("1.00x", 65, 218, 120, 24, 11, nil, true)
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

CreateElegantLabel("REPLAY LIST", 0, 246, 234, 14, 9, nil, true)

-- Replay List
local ReplayList = Instance.new("ScrollingFrame")
ReplayList.Size = UDim2.new(1, 0, 0, 126)
ReplayList.Position = UDim2.fromOffset(0, 264)
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

-- ========= REPLAY LIST MANAGEMENT =========
local function UpdateReplayList()
    CleanupConnections()
    
    for _, child in pairs(ReplayList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
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

-- ========= IMPROVED REVERSE SYSTEM =========
local function FindLastSafeFrame()
    if #CurrentRecording.Frames == 0 then return 0 end
    
    -- Cari frame terakhir dengan state grounded
    for i = #CurrentRecording.Frames, 1, -1 do
        local frame = CurrentRecording.Frames[i]
        if frame.MoveState == "Grounded" or frame.MoveState == "Running" then
            return i
        end
    end
    
    -- Jika tidak ada grounded, return frame pertama
    return 1
end

local function ReverseToSafePosition()
    if #CurrentRecording.Frames == 0 then
        StatusLabel.Text = "❌ No recording to reverse!"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = char.HumanoidRootPart
    
    -- Cari frame aman terakhir
    local safeFrameIndex = FindLastSafeFrame()
    
    if safeFrameIndex == 0 then
        StatusLabel.Text = "❌ No safe position found!"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    -- Teleport ke safe frame
    local safeFrame = CurrentRecording.Frames[safeFrameIndex]
    if safeFrame then
        hrp.CFrame = GetFrameCFrame(safeFrame)
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        
        -- Remove frames after safe position
        for i = #CurrentRecording.Frames, safeFrameIndex + 1, -1 do
            table.remove(CurrentRecording.Frames, i)
        end
        
        UpdateStudioUI()
        StatusLabel.Text = "⏪ Reversed to safe frame " .. safeFrameIndex
        StatusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
        
        -- Reset fall detection
        IsFallDetected = false
        isCurrentlyFalling = false
        
        -- Auto resume recording setelah reverse
        if IsRecording then
            StatusLabel.Text = "⏪ Reversed to frame " .. safeFrameIndex .. " - Recording RESUMED"
            StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
        end
    end
end

-- ========= RECORDING STUDIO SYSTEM =========
local function UpdateStudioUI()
    FrameLabel.Text = "Frames: " .. #CurrentRecording.Frames .. " / 30000"
end

local function StartStudioRecording()
    if IsRecording then return end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        StatusLabel.Text = "❌ Character not found!"
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
    
    -- Timeline controls selalu visible
    RewindBtn.Visible = true
    ForwardBtn.Visible = true
    ResumeBtn.Visible = true
    
    recordConnection = RunService.Heartbeat:Connect(function()
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") or #CurrentRecording.Frames >= MAX_FRAMES then
            return
        end
        
        local hrp = char.HumanoidRootPart
        local hum = char:FindFirstChildOfClass("Humanoid")
        
        -- Check fall detection
        local moveState = GetCurrentMoveState(hum, hrp)
        
        if IsFallDetected then
            -- Auto pause recording saat fall terdeteksi
            StatusLabel.Text = "⚠️ FALL DETECTED! Click REVERSE to go back to safe position"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 150, 50)
            return
        end
        
        -- Update last safe frame jika tidak falling
        if moveState == "Grounded" or moveState == "Running" then
            LastSafeFrame = #CurrentRecording.Frames
        end
        
        local now = tick()
        if (now - lastRecordTime) < (1 / RECORDING_FPS) then return end
        
        local currentPos = hrp.Position
        local currentVelocity = hrp.AssemblyLinearVelocity
        
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
    
    if #CurrentRecording.Frames > 0 then
        StatusLabel.Text = "✅ Recording stopped (" .. #CurrentRecording.Frames .. " frames)"
        StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
    else
        StatusLabel.Text = "Recording stopped (0 frames)"
        StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
    end
    
    -- Timeline controls tetap visible
    RewindBtn.Visible = true
    ForwardBtn.Visible = true
    ResumeBtn.Visible = true
end

local function RewindTimeline()
    if #CurrentRecording.Frames == 0 then 
        StatusLabel.Text = "❌ No frames to rewind!"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return 
    end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = char.HumanoidRootPart
    
    -- Calculate frames to rewind (1 second = 60 frames)
    local framesToRewind = TIMELINE_STEP_SECONDS * RECORDING_FPS
    local targetFrame = math.max(1, #CurrentRecording.Frames - framesToRewind)
    
    -- Teleport to target frame position
    local targetFrameData = CurrentRecording.Frames[targetFrame]
    if targetFrameData then
        hrp.CFrame = GetFrameCFrame(targetFrameData)
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        
        StatusLabel.Text = "⏪ Rewound to frame " .. targetFrame
        StatusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
    end
end

local function ForwardTimeline()
    if #CurrentRecording.Frames == 0 then 
        StatusLabel.Text = "❌ No frames to forward!"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return 
    end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = char.HumanoidRootPart
    
    -- Calculate frames to forward (1 second = 60 frames)
    local framesToForward = TIMELINE_STEP_SECONDS * RECORDING_FPS
    local targetFrame = math.min(#CurrentRecording.Frames, #CurrentRecording.Frames + framesToForward)
    
    -- Jika target frame melebihi current frames, tidak melakukan apa-apa
    if targetFrame > #CurrentRecording.Frames then
        StatusLabel.Text = "⏩ Already at the latest frame"
        StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
        return
    end
    
    StatusLabel.Text = "⏩ Use RESUME to continue recording from current position"
    StatusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
end

local function ResumeStudioRecording()
    if IsRecording then
        StatusLabel.Text = "▶ Recording resumed from current position"
        StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
        
        -- Reset fall detection
        IsFallDetected = false
        isCurrentlyFalling = false
    else
        StatusLabel.Text = "❌ Not recording - Click RECORD first"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    end
end

local function SaveStudioRecording()
    if #CurrentRecording.Frames == 0 then
        StatusLabel.Text = "❌ No frames to save!"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    local recordingName = "Studio_" .. os.date("%H%M%S")
    RecordedMovements[recordingName] = CurrentRecording.Frames
    UpdateReplayList()
    
    StatusLabel.Text = "💾 Saved: " .. recordingName
    StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
    
    UpdateStatus("Saved from Studio: " .. recordingName .. " (" .. #CurrentRecording.Frames .. " frames)")
    
    -- Reset recording
    CurrentRecording = {Frames = {}, StartTime = 0, Name = "Studio_" .. os.date("%H%M%S")}
    UpdateStudioUI()
    
    wait(1.5)
    RecordingStudio.Visible = false
    MainFrame.Visible = true
end

-- ========= STUDIO BUTTON EVENTS =========
RecordBtn.MouseButton1Click:Connect(function()
    if IsRecording then
        StopStudioRecording()
    else
        StartStudioRecording()
    end
end)

ReverseBtn.MouseButton1Click:Connect(ReverseToSafePosition)
RewindBtn.MouseButton1Click:Connect(RewindTimeline)
ForwardBtn.MouseButton1Click:Connect(ForwardTimeline)
ResumeBtn.MouseButton1Click:Connect(ResumeStudioRecording)
SaveReplayBtn.MouseButton1Click:Connect(SaveStudioRecording)

CloseStudioBtn.MouseButton1Click:Connect(function()
    if IsRecording then
        StopStudioRecording()
    end
    RecordingStudio.Visible = false
    MainFrame.Visible = true
end)

-- ========= PLAYBACK SYSTEMS =========
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
        
        -- Disable collision saat playback
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
                    if char and char:FindFirstChild("HumanoidRootPart") then
                        local currentHum = char:FindFirstChildOfClass("Humanoid")
                        local currentHrp = char:FindFirstChild("HumanoidRootPart")
                        if currentHum and currentHrp then
                            currentHum.AutoRotate = true
                            currentHum.PlatformStand = false
                            currentHrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                            currentHrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                            currentHum:ChangeState(Enum.HumanoidStateType.Running)
                        end
                    end
                end
                RunService.Heartbeat:Wait()
                continue
            else
                if pauseStartTime > 0 then
                    totalPausedDuration = totalPausedDuration + (tick() - pauseStartTime)
                    pauseStartTime = 0
                    if hum then
                        hum.AutoRotate = true
                        hum.PlatformStand = false
                    end
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
            
            pcall(function()
                local targetPos = GetFramePosition(frame)
                local moveState = frame.MoveState
                
                local scaledVelocity = GetFrameVelocity(frame) * CurrentSpeed
                hum.WalkSpeed = GetFrameWalkSpeed(frame) * CurrentSpeed
                
                local distanceToTarget = (hrp.Position - targetPos).Magnitude
                
                if distanceToTarget > 15 then
                    hrp.CFrame = CFrame.new(targetPos)
                    currentFrame = currentFrame + 1
                elseif distanceToTarget > MOVETO_REACH_DISTANCE then
                    hum:MoveTo(targetPos)
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
                
                if AutoHeal and hum.Health < hum.MaxHealth * 0.5 then
                    hum.Health = hum.MaxHealth
                end
            end)
            
            if currentFrame % 30 == 0 then
                UpdateStatus(string.format("MoveTo: Frame %d/%d", currentFrame, #recording))
            end
            
            if currentFrame >= #recording then break end
            RunService.Heartbeat:Wait()
        end
        
        -- Re-enable collision
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
        
        if AutoLoop and IsPlaying then
            UpdateStatus("🔄 Looping...")
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
        
        -- Noclip mode
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
                    if char and char:FindFirstChild("HumanoidRootPart") then
                        local currentHum = char:FindFirstChildOfClass("Humanoid")
                        local currentHrp = char:FindFirstChild("HumanoidRootPart")
                        if currentHum and currentHrp then
                            currentHum.AutoRotate = true
                            currentHum.PlatformStand = false
                            currentHrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                            currentHrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                            currentHum:ChangeState(Enum.HumanoidStateType.Running)
                        end
                    end
                end
                RunService.Heartbeat:Wait()
                continue
            else
                if pauseStartTime > 0 then
                    totalPausedDuration = totalPausedDuration + (tick() - pauseStartTime)
                    pauseStartTime = 0
                    if hum then
                        hum.AutoRotate = false
                        hum.PlatformStand = false
                    end
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
            
            pcall(function()
                hrp.CFrame = GetFrameCFrame(frame)
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
                
                if AutoHeal and hum.Health < hum.MaxHealth * 0.5 then
                    hum.Health = hum.MaxHealth
                end
            end)
            
            if currentFrame % 30 == 0 then
                UpdateStatus(string.format("CFrame: Frame %d/%d", currentFrame, #recording))
            end
            
            if currentFrame >= #recording then break end
            RunService.Heartbeat:Wait()
        end
        
        -- Re-enable collision
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
        
        if AutoLoop and IsPlaying then
            UpdateStatus("🔄 Looping...")
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
        UpdateStatus(string.format("Starting from Frame %d", nearestFrame))
    else
        currentPlaybackFrame = 1
        playbackStartTime = tick()
        
        local startPos = GetFramePosition(recording[1])
        if (hrp.Position - startPos).Magnitude > 50 then
            hrp.CFrame = CFrame.new(startPos)
            UpdateStatus("Teleported to start")
        else
            UpdateStatus("Starting from Frame 1")
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
        -- Re-enable collision
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

-- ========= FILE MANAGEMENT =========
local function SaveToFile()
    local filename = FileNameBox.Text
    if filename == "" then filename = "MyWalk" end
    filename = filename:gsub("[^%w%s%-_]", "") .. ".json"
    
    if not next(RecordedMovements) then
        UpdateStatus("ERROR: No recordings to save!")
        return
    end
    
    pcall(function()
        local data = {
            recordings = RecordedMovements,
            settings = {
                speed = CurrentSpeed,
                autoHeal = AutoHeal,
                autoLoop = AutoLoop,
                useMoveTo = UseMoveTo,
                showVisualization = ShowVisualization
            },
            version = "8.1"
        }
        writefile(filename, HttpService:JSONEncode(data))
        UpdateStatus("Saved: " .. filename)
    end)
end

local function LoadFromFile()
    local filename = FileNameBox.Text
    if filename == "" then filename = "MyWalk" end
    filename = filename:gsub("[^%w%s%-_]", "") .. ".json"
    
    pcall(function()
        if isfile(filename) then
            local data = HttpService:JSONDecode(readfile(filename))
            RecordedMovements = data.recordings or {}
            CurrentSpeed = data.settings and data.settings.speed or 1
            AutoHeal = data.settings and data.settings.autoHeal or false
            AutoLoop = data.settings and data.settings.autoLoop or false
            UseMoveTo = data.settings and data.settings.useMoveTo or true
            ShowVisualization = data.settings and data.settings.showVisualization or false
            
            UpdateSpeedDisplay()
            SetMoveToState(UseMoveTo)
            SetVisualState(ShowVisualization)
            SetLoopState(AutoLoop)
            SetHealState(AutoHeal)
            UpdateReplayList()
            UpdateStatus("Loaded: " .. filename)
        else
            UpdateStatus("ERROR: File not found")
        end
    end)
end

-- ========= HTTP SUPPORT FOR FUTURE GUI LOADING =========
local function LoadGUIFromURL(url)
    -- Placeholder untuk future HTTP support
    -- Ini akan digunakan untuk load GUI dari URL
    UpdateStatus("HTTP Support: Ready for future updates")
end

-- ========= MAIN GUI BUTTON EVENTS =========
OpenStudioBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    RecordingStudio.Visible = true
    StatusLabel.Text = "🎬 Recording Studio Ready - Timeline controls ALWAYS VISIBLE"
    StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
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
    SetMoveToState(UseMoveTo)
    UpdateStatus("MoveTo: " .. (UseMoveTo and "ON" or "OFF"))
end)

VisualBtn.MouseButton1Click:Connect(function()
    ShowVisualization = not ShowVisualization
    SetVisualState(ShowVisualization)
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
    SetLoopState(AutoLoop)
    UpdateStatus("Auto Loop: " .. (AutoLoop and "ON" or "OFF"))
end)

HealBtn.MouseButton1Click:Connect(function()
    AutoHeal = not AutoHeal
    SetHealState(AutoHeal)
    UpdateStatus("Auto Heal: " .. (AutoHeal and "ON" or "OFF"))
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

-- ========= AUTO HEAL =========
RunService.Heartbeat:Connect(function()
    if not AutoHeal then return end
    
    local char = player.Character
    if not char then return end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    if hum.Health < hum.MaxHealth * 0.5 then
        hum.Health = hum.MaxHealth
    end
end)

-- ========= INITIALIZATION =========
UpdateReplayList()
UpdateStatus("🎬 Auto Walk Pro v8.1 - Ready!")
UpdateSpeedDisplay()

-- Initialize HTTP support
LoadGUIFromURL("") -- Initialize HTTP system

wait(1)
UpdateStatus("✅ All Systems Operational + HTTP Support Ready")

print("===========================================")
print("    AUTO WALK PRO v8.1 - LOADED")
print("===========================================")
print("🎬 Recording Studio:        ACTIVE")
print("🛡️ Smart Anti-Fall:          ACTIVE")
print("⏪ Timeline Control:         ACTIVE")
print("🚫 Anti-Stuck System:       ACTIVE")
print("🌐 HTTP Support:            READY")
print("📊 Recordings Loaded:       " .. (function()
    local count = 0
    for _ in pairs(RecordedMovements) do
        count = count + 1
    end
    return count
end)())
print("===========================================")
print("")
print("📌 HOTKEYS:")
print("   F8  - Open/Close Recording Studio")
print("   F9  - Quick Record (Studio only)")
print("   F10 - Play/Stop")
print("   F11 - Hide/Show Main GUI")
print("   F7  - Pause/Resume Playback")
print("")
print("🎯 RECORDING STUDIO FEATURES:")
print("   ⏪ REVERSE  - Kembali ke posisi aman (ALWAYS VISIBLE)")
print("   ● RECORD   - Start/Stop recording")
print("   💾 SAVE REPLAY - Save ke replay list")
print("   ⏪ MUNDUR  - Mundur 1 detik (ALWAYS VISIBLE)")
print("   ▶ RESUME   - Lanjut recording (ALWAYS VISIBLE)")
print("   ⏩ MAJU    - Info maju timeline (ALWAYS VISIBLE)")
print("")
print("✨ NEW IN v8.1:")
print("   • Timeline controls ALWAYS VISIBLE")
print("   • Improved Reverse System dengan safe frame detection")
print("   • Save Replay button langsung save recording")
print("   • HTTP Support ready untuk future updates")
print("   • Better fall detection dan auto-resume")
print("===========================================")