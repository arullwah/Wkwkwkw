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
local recordConnection = nil
local playbackConnection = nil
local loopConnection = nil
local lastRecordTime = 0
local lastRecordPos = nil
local checkpointNames = {}
local PathVisualization = {}
local ShowPaths = false

-- ========= PAUSE/RESUME VARIABLES =========
local playbackStartTime = 0
local totalPausedDuration = 0
local pauseStartTime = 0
local currentPlaybackFrame = 1
local prePauseHumanoidState = nil
local prePauseWalkSpeed = 16
local prePauseAutoRotate = true
local prePauseJumpPower = 50

-- ========= AUTO LOOP VARIABLES =========
local IsAutoLoopPlaying = false
local CurrentLoopIndex = 1
local LoopPauseStartTime = 0
local LoopTotalPausedDuration = 0

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
end

-- ========= ✅ AUTO RESPAWN FUNCTION =========
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
            warn("⚠️ Respawn timeout!")
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
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end)
end

-- ========= FULL USER CONTROL RESTORATION =========
local function RestoreFullUserControl()
    local char = player.Character
    if not char then return end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
    if humanoid then
        -- Restore semua properti ke default
        humanoid.AutoRotate = true
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = prePauseJumpPower or 50
        humanoid.PlatformStand = false
        
        -- Kembalikan ke state normal
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end
    
    if hrp then
        -- Clear physics
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end
    
    print("🎮 Full user control restored")
end

-- ========= ENHANCED JUMP DETECTION SYSTEM =========
local lastGroundState = true
local jumpBuffer = 0

local function GetCurrentMoveState(hum)
    if not hum then return "Grounded" end
    
    local hrp = hum.Parent and hum.Parent:FindFirstChild("HumanoidRootPart")
    if not hrp then return "Grounded" end
    
    local state = hum:GetState()
    local velY = hrp.AssemblyLinearVelocity.Y
    
    -- Deteksi transisi dari grounded ke air (loncatan)
    local isGrounded = state == Enum.HumanoidStateType.Running 
                    or state == Enum.HumanoidStateType.RunningNoPhysics
                    or state == Enum.HumanoidStateType.Climbing
    
    if not lastGroundState and isGrounded then
        -- Baru mendarat
        jumpBuffer = 0
    elseif lastGroundState and not isGrounded and velY > 10 then
        -- Baru mulai lompat
        jumpBuffer = 3  -- Tandai sebagai jumping untuk 3 frame
    end
    
    lastGroundState = isGrounded
    
    -- Prioritaskan jump state jika dalam buffer
    if jumpBuffer > 0 then
        jumpBuffer = jumpBuffer - 1
        return "Jumping"
    end
    
    -- State normal (SAMA PERSIS seperti script pertama)
    if state == Enum.HumanoidStateType.Climbing then return "Climbing"
    elseif state == Enum.HumanoidStateType.Jumping then return "Jumping"
    elseif state == Enum.HumanoidStateType.Freefall then return "Falling"
    elseif state == Enum.HumanoidStateType.Swimming then return "Swimming"
    elseif state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics then return "Grounded"
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

-- ========= 🔄 MACRO/MERGE SYSTEM =========
local function CreateMergedReplay()
    if #RecordingOrder < 2 then
        print("❌ Need at least 2 checkpoints to merge!")
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
    
    local mergedName = "arul_" .. os.date("%H%M%S")
    RecordedMovements[mergedName] = mergedFrames
    table.insert(RecordingOrder, mergedName)
    checkpointNames[mergedName] = "MERGED ALL"
    
    UpdateRecordList()
    print("✅ Merge " .. #RecordingOrder-1 .. " checkpoints into one replay!")
    print("📊 Total frames: " .. #mergedFrames)
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

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.fromOffset(250, 320)
MainFrame.Position = UDim2.new(0.5, -125, 0.5, -160)
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
Title.TextColor3 = Color3.fromRGB(100, 255, 150)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Center
Title.Parent = Header

local FrameLabel = Instance.new("TextLabel")
FrameLabel.Size = UDim2.new(0, 70, 1, 0)
FrameLabel.Position = UDim2.new(0, 5, 0, 0)
FrameLabel.BackgroundTransparency = 1
FrameLabel.Text = "Frames: 0"
FrameLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
FrameLabel.Font = Enum.Font.GothamBold
FrameLabel.TextSize = 9
FrameLabel.Parent = Header

-- ========= BIGGER HIDE & CLOSE BUTTONS WITH ROUNDED CORNERS =========
local HideButton = Instance.new("TextButton")
HideButton.Size = UDim2.fromOffset(30, 25)
HideButton.Position = UDim2.new(1, -65, 0.5, -12)
HideButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
HideButton.Text = "_"
HideButton.TextColor3 = Color3.new(1, 1, 1)
HideButton.Font = Enum.Font.GothamBold
HideButton.TextSize = 14
HideButton.Parent = Header

local HideCorner = Instance.new("UICorner")
HideCorner.CornerRadius = UDim.new(0, 6)
HideCorner.Parent = HideButton

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.fromOffset(30, 25)
CloseButton.Position = UDim2.new(1, -30, 0.5, -12)
CloseButton.BackgroundColor3 = Color3.fromRGB(200, 60, 70)
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.new(1, 1, 1)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 12
CloseButton.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseButton

-- ========= RED RESIZE BUTTON 30x30 =========
local ResizeButton = Instance.new("TextButton")
ResizeButton.Size = UDim2.fromOffset(30, 30)
ResizeButton.Position = UDim2.new(1, -30, 1, -30)
ResizeButton.BackgroundColor3 = Color3.fromRGB(200, 60, 70)
ResizeButton.Text = "⤢"
ResizeButton.TextColor3 = Color3.new(1, 1, 1)
ResizeButton.Font = Enum.Font.GothamBold
ResizeButton.TextSize = 14
ResizeButton.ZIndex = 2
ResizeButton.Parent = MainFrame

local ResizeCorner = Instance.new("UICorner")
ResizeCorner.CornerRadius = UDim.new(0, 8)
ResizeCorner.Parent = ResizeButton

local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, -10, 1, -42)
Content.Position = UDim2.new(0, 5, 0, 36)
Content.BackgroundTransparency = 1
Content.ScrollBarThickness = 3
Content.ScrollBarImageColor3 = Color3.fromRGB(80, 120, 255)
Content.CanvasSize = UDim2.new(0, 0, 0, 750)
Content.Parent = MainFrame

-- ========= MINI BUTTON DI TENGAH ATAS =========
local MiniButton = Instance.new("TextButton")
MiniButton.Size = UDim2.fromOffset(40, 40)
MiniButton.Position = UDim2.new(0.5, -20, 0, 10) -- Posisi di tengah atas
MiniButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MiniButton.Text = "ArL"
MiniButton.TextColor3 = Color3.new(1, 1, 1)
MiniButton.Font = Enum.Font.GothamBold
MiniButton.TextSize = 14
MiniButton.Visible = false
MiniButton.Active = true
MiniButton.Draggable = true
MiniButton.Parent = ScreenGui

local MiniCorner = Instance.new("UICorner")
MiniCorner.CornerRadius = UDim.new(0, 8)
MiniCorner.Parent = MiniButton

-- Helper Functions
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
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 1
    stroke.Transparency = 0.85
    stroke.Parent = btn
    
    btn.MouseButton1Down:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(w - 2, h - 2)
        }):Play()
    end)
    
    btn.MouseButton1Up:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(w, h)
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
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local bgColor = isOn and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(50, 50, 50)
        local knobPos = isOn and UDim2.new(0, 12, 0, 2) or UDim2.new(0, 2, 0, 2)
        TweenService:Create(toggle, tweenInfo, {BackgroundColor3 = bgColor}):Play()
        TweenService:Create(knob, tweenInfo, {Position = knobPos}):Play()
    end
    
    return btn, Animate
end

-- ========= UI ELEMENTS =========
local RecordBtnBig = CreateButton("⏺️ REC", 5, 5, 115, 30, Color3.fromRGB(220, 60, 70))
local SaveBtnBig = CreateButton("💾 SAVE", 125, 5, 115, 30, Color3.fromRGB(50, 140, 220))

local PlayBtnBig = CreateButton("▶️ PLAY", 5, 40, 75, 30, Color3.fromRGB(50, 200, 90))
local StopBtnBig = CreateButton("⏹️ STOP", 85, 40, 75, 30, Color3.fromRGB(220, 60, 70))
local PauseBtnBig = CreateButton("⏸️ PAUSE", 165, 40, 75, 30, Color3.fromRGB(200, 160, 50))

-- Toggle buttons in one row
local LoopBtn, AnimateLoop = CreateToggle("🔁 Auto Loop", 0, 75, 117, 22, false)
local RespawnBtn, AnimateRespawn = CreateToggle("🔄 Auto Respawn", 123, 75, 117, 22, false)

-- Textboxes in two rows (with bigger text)
local FilenameBox = Instance.new("TextBox")
FilenameBox.Size = UDim2.fromOffset(117, 26)
FilenameBox.Position = UDim2.fromOffset(0, 102)
FilenameBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
FilenameBox.BorderSizePixel = 0
FilenameBox.Text = ""
FilenameBox.PlaceholderText = "Nama File..."
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
SpeedBox.Position = UDim2.fromOffset(123, 102)
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

local SaveFileBtn = CreateButton("💾 SAVE FILE", 0, 133, 117, 26, Color3.fromRGB(50, 140, 220))
local LoadFileBtn = CreateButton("📂 LOAD FILE", 123, 133, 117, 26, Color3.fromRGB(50, 200, 90))

local PathToggleBtn = CreateButton("〽️ RUTE", 0, 164, 117, 26, Color3.fromRGB(180, 80, 220))
local MergeBtn = CreateButton("🔄 MERGE", 123, 164, 117, 26, Color3.fromRGB(180, 80, 220))

local RecordList = Instance.new("ScrollingFrame")
RecordList.Size = UDim2.new(1, 0, 1, -195)
RecordList.Position = UDim2.fromOffset(0, 195)
RecordList.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
RecordList.BorderSizePixel = 0
RecordList.ScrollBarThickness = 3
RecordList.ScrollBarImageColor3 = Color3.fromRGB(80, 120, 255)
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
    else
        SpeedBox.Text = string.format("%.2f", CurrentSpeed)
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
            local newHeight = math.clamp(StartSize.Y.Offset + delta.Y, 200, 400)
            
            MainFrame.Size = UDim2.fromOffset(newWidth, newHeight)
            
            local widthScale = newWidth / 250
            
            RecordBtnBig.Size = UDim2.fromOffset(115 * widthScale, 30)
            SaveBtnBig.Size = UDim2.fromOffset(115 * widthScale, 30)
            PlayBtnBig.Size = UDim2.fromOffset(75 * widthScale, 30)
            StopBtnBig.Size = UDim2.fromOffset(75 * widthScale, 30)
            PauseBtnBig.Size = UDim2.fromOffset(75 * widthScale, 30)
            
            SaveBtnBig.Position = UDim2.fromOffset(5 + (115 * widthScale) + 5, 5)
            StopBtnBig.Position = UDim2.fromOffset(5 + (75 * widthScale) + 5, 40)
            PauseBtnBig.Position = UDim2.fromOffset(5 + (75 * widthScale) * 2 + 10, 40)
            
            LoopBtn.Size = UDim2.fromOffset(117 * widthScale, 22)
            RespawnBtn.Size = UDim2.fromOffset(117 * widthScale, 22)
            RespawnBtn.Position = UDim2.fromOffset(5 + (117 * widthScale) + 5, 75)
            
            FilenameBox.Size = UDim2.fromOffset(117 * widthScale, 26)
            SpeedBox.Size = UDim2.fromOffset(117 * widthScale, 26)
            SpeedBox.Position = UDim2.fromOffset(5 + (117 * widthScale) + 5, 102)
            
            SaveFileBtn.Size = UDim2.fromOffset(117 * widthScale, 26)
            LoadFileBtn.Size = UDim2.fromOffset(117 * widthScale, 26)
            LoadFileBtn.Position = UDim2.fromOffset(5 + (117 * widthScale) + 5, 133)
            
            PathToggleBtn.Size = UDim2.fromOffset(117 * widthScale, 26)
            MergeBtn.Size = UDim2.fromOffset(117 * widthScale, 26)
            MergeBtn.Position = UDim2.fromOffset(5 + (117 * widthScale) + 5, 164)
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
        
        local nameBox = Instance.new("TextBox")
        nameBox.Size = UDim2.new(1, -130, 0, 18)
        nameBox.Position = UDim2.new(0, 8, 0, 4)
        nameBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        nameBox.BorderSizePixel = 0
        nameBox.Text = checkpointNames[name] or "checkpoint"
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
        
        local infoLabel = Instance.new("TextLabel")
        infoLabel.Size = UDim2.new(1, -130, 0, 16)
        infoLabel.Position = UDim2.new(0, 8, 0, 22)
        infoLabel.BackgroundTransparency = 1
        if #rec > 0 then
            local totalSeconds = rec[#rec].Timestamp
            infoLabel.Text = 
                '<font color="rgb(255,80,80)">' .. FormatDuration(totalSeconds) .. '</font>' .. 
                ' <font color="rgb(255,255,255)">• ' .. #rec .. ' frames</font>'
            infoLabel.RichText = true
        else
            infoLabel.Text = '<font color="rgb(255,80,80)">0:00</font> <font color="rgb(255,255,255)">• 0 frames</font>'
            infoLabel.RichText = true
        end
        infoLabel.Font = Enum.Font.GothamBold
        infoLabel.TextSize = 8
        infoLabel.TextXAlignment = Enum.TextXAlignment.Left
        infoLabel.Parent = item
        
        local playBtn = Instance.new("TextButton")
        playBtn.Size = UDim2.fromOffset(25, 25)
        playBtn.Position = UDim2.new(1, -110, 0, 7)
        playBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        playBtn.Text = "▶️"
        playBtn.TextColor3 = Color3.new(1, 1, 1)
        playBtn.Font = Enum.Font.GothamBold
        playBtn.TextSize = 20
        playBtn.Parent = item
        
        local playCorner = Instance.new("UICorner")
        playCorner.CornerRadius = UDim.new(0, 6)
        playCorner.Parent = playBtn
        
        local upBtn = Instance.new("TextButton")
        upBtn.Size = UDim2.fromOffset(25, 25)
        upBtn.Position = UDim2.new(1, -80, 0, 7)
        upBtn.BackgroundColor3 = index > 1 and Color3.fromRGB(40, 120, 200) or Color3.fromRGB(30, 30, 30)
        upBtn.Text = "⬆️"
        upBtn.TextColor3 = Color3.new(1, 1, 1)
        upBtn.Font = Enum.Font.GothamBold
        upBtn.TextSize = 20
        upBtn.Parent = item
        
        local upCorner = Instance.new("UICorner")
        upCorner.CornerRadius = UDim.new(0, 6)
        upCorner.Parent = upBtn
        
        local downBtn = Instance.new("TextButton")
        downBtn.Size = UDim2.fromOffset(25, 25)
        downBtn.Position = UDim2.new(1, -50, 0, 7)
        downBtn.BackgroundColor3 = index < #RecordingOrder and Color3.fromRGB(40, 120, 200) or Color3.fromRGB(30, 30, 30)
        downBtn.Text = "⬇️"
        downBtn.TextColor3 = Color3.new(1, 1, 1)
        downBtn.Font = Enum.Font.GothamBold
        downBtn.TextSize = 20
        downBtn.Parent = item
        
        local downCorner = Instance.new("UICorner")
        downCorner.CornerRadius = UDim.new(0, 6)
        downCorner.Parent = downBtn
        
        local delBtn = Instance.new("TextButton")
        delBtn.Size = UDim2.fromOffset(25, 25)
        delBtn.Position = UDim2.new(1, -20, 0, 7)
        delBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        delBtn.Text = "🚮"
        delBtn.TextColor3 = Color3.new(1, 1, 1)
        delBtn.Font = Enum.Font.GothamBold
        delBtn.TextSize = 20
        delBtn.Parent = item
        
        local delCorner = Instance.new("UICorner")
        delCorner.CornerRadius = UDim.new(0, 6)
        delCorner.Parent = delBtn
        
        upBtn.MouseButton1Click:Connect(function()
            if index > 1 then MoveRecordingUp(name) end
        end)
        
        downBtn.MouseButton1Click:Connect(function()
            if index < #RecordingOrder then MoveRecordingDown(name) end
        end)
        
        playBtn.MouseButton1Click:Connect(function()
            if not IsPlaying then PlayRecording(name) end
        end)
        
        delBtn.MouseButton1Click:Connect(function()
            RecordedMovements[name] = nil
            checkpointNames[name] = nil
            local idx = table.find(RecordingOrder, name)
            if idx then table.remove(RecordingOrder, idx) end
            UpdateRecordList()
        end)
        
        yPos = yPos + 43
    end
    
    RecordList.CanvasSize = UDim2.new(0, 0, 0, yPos)
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

-- ========= SAVE HUMANOID STATE =========
local function SaveHumanoidState()
    local char = player.Character
    if not char then return end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        prePauseAutoRotate = humanoid.AutoRotate
        prePauseWalkSpeed = humanoid.WalkSpeed
        prePauseJumpPower = humanoid.JumpPower
        prePauseHumanoidState = humanoid:GetState()
    end
end

-- ========= OPTIMIZED RECORDING SYSTEM =========
local lastFrameTime = 0
local frameInterval = 1 / RECORDING_FPS

local function ShouldRecordFrame()
    local currentTime = tick()
    return (currentTime - lastFrameTime) >= frameInterval
end

function StartRecording()
    if IsRecording then return end
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        print("❌ Character not found!")
        return
    end
    
    IsRecording = true
    CurrentRecording = {Frames = {}, StartTime = tick(), Name = "Roel_" .. os.date("%H%M%S")}
    lastRecordTime = 0
    lastRecordPos = nil
    lastFrameTime = 0
    
    RecordBtnBig.Text = "STOP"
    RecordBtnBig.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    
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
    
    RecordBtnBig.Text = "REC"
    RecordBtnBig.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
end

function SaveRecording()
    if #CurrentRecording.Frames == 0 then
        print("❌ No recording to save!")
        return
    end
    local name = CurrentRecording.Name
    RecordedMovements[name] = CurrentRecording.Frames
    table.insert(RecordingOrder, name)
    checkpointNames[name] = "checkpoint_" .. #RecordingOrder
    UpdateRecordList()
    CurrentRecording = {Frames = {}, StartTime = 0, Name = "Roel_" .. os.date("%H%M%S")}
    FrameLabel.Text = "Frames: 0"
    print("✅ Saved recording: " .. name)
end

-- ========= OPTIMIZED PLAYBACK SYSTEM (ORIGINAL DARI SCRIPT PERTAMA) =========
function PlayRecording(name)
    if IsPlaying then return end
    
    local recording = name and RecordedMovements[name] or (RecordingOrder[1] and RecordedMovements[RecordingOrder[1]])
    if not recording or #recording == 0 then
        print("❌ No recordings or empty recording!")
        return
    end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        print("❌ Character not found!")
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

    playbackConnection = RunService.Heartbeat:Connect(function()
        if not IsPlaying then
            playbackConnection:Disconnect()
            RestoreFullUserControl()
            return
        end
        
        if IsPaused then
            if pauseStartTime == 0 then
                pauseStartTime = tick()
                RestoreFullUserControl()
            end
            return
        else
            if pauseStartTime > 0 then
                totalPausedDuration = totalPausedDuration + (tick() - pauseStartTime)
                pauseStartTime = 0
                DisableJump()
            end
        end

        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            IsPlaying = false
            RestoreFullUserControl()
            return
        end
        
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then
            IsPlaying = false
            RestoreFullUserControl()
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
            print("✅ Playback finished - Control restored")
            return
        end

        local frame = recording[currentPlaybackFrame]
        if not frame then
            IsPlaying = false
            RestoreFullUserControl()
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
    
    AddConnection(playbackConnection)
end

-- ========= FIXED AUTO LOOP SYSTEM =========
function StartAutoLoopAll()
    if not AutoLoop then return end
    
    if #RecordingOrder == 0 then
        print("❌ No checkpoints to loop!")
        AutoLoop = false
        AnimateLoop(false)
        return
    end
    
    print("🔄 Starting auto loop with " .. #RecordingOrder .. " recordings")
    
    CurrentLoopIndex = 1
    IsAutoLoopPlaying = true
    
    loopConnection = task.spawn(function()
        while AutoLoop and IsAutoLoopPlaying do
            local recordingName = RecordingOrder[CurrentLoopIndex]
            local recording = RecordedMovements[recordingName]
            
            if not recording or #recording == 0 then
                print("❌ Skipping empty recording: " .. recordingName)
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
                print("🔄 Resetting character for new loop")
                ResetCharacter()
                local success = WaitForRespawn()
                if not success then
                    print("❌ Respawn failed! Stopping loop.")
                    AutoLoop = false
                    IsAutoLoopPlaying = false
                    AnimateLoop(false)
                    break
                end
                
                print("⏳ Waiting for character to fully load...")
                task.wait(1.5)
            end
            
            if not IsCharacterReady() then
                print("💀 Character died, waiting for respawn...")
                local maxWaitTime = 15
                local startWait = tick()
                
                while not IsCharacterReady() and AutoLoop and IsAutoLoopPlaying do
                    if tick() - startWait > maxWaitTime then
                        print("❌ Respawn timeout! Stopping loop.")
                        AutoLoop = false
                        IsAutoLoopPlaying = false
                        AnimateLoop(false)
                        break
                    end
                    task.wait(0.5)
                end
                
                if not AutoLoop or not IsAutoLoopPlaying then break end
                
                print("⏳ Character respawned, waiting to stabilize...")
                task.wait(1.0)
            end
            
            if not AutoLoop or not IsAutoLoopPlaying then break end
            
            print("▶️ Playing recording " .. CurrentLoopIndex .. "/" .. #RecordingOrder .. ": " .. recordingName)
            
            local playbackCompleted = false
            local playbackStart = tick()
            local playbackPausedTime = 0
            local playbackPauseStart = 0
            local currentFrame = 1
            
            SaveHumanoidState()
            DisableJump()
            
            while AutoLoop and IsAutoLoopPlaying and currentFrame <= #recording do
                if not IsCharacterReady() then
                    print("💀 Character died during playback, stopping current recording")
                    break
                end
                
                if IsPaused then
                    if playbackPauseStart == 0 then
                        playbackPauseStart = tick()
                        RestoreFullUserControl()
                    end
                    task.wait(0.1)
                else
                    if playbackPauseStart > 0 then
                        playbackPausedTime = playbackPausedTime + (tick() - playbackPauseStart)
                        playbackPauseStart = 0
                        DisableJump()
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
                    end
                    
                    task.wait()
                end
            end
            
            RestoreFullUserControl()
            
            if playbackCompleted then
                print("✅ Finished recording: " .. recordingName)
                
                CurrentLoopIndex = CurrentLoopIndex + 1
                if CurrentLoopIndex > #RecordingOrder then
                    CurrentLoopIndex = 1
                    print("🔄 Loop completed, restarting from beginning")
                end
                
                task.wait(0.5)
            else
                if not IsCharacterReady() then
                    print("💀 Playback interrupted - character died")
                else
                    print("⏸️ Playback interrupted")
                    break
                end
            end
        end
        
        IsAutoLoopPlaying = false
        IsPaused = false
        RestoreFullUserControl()
        print("⏹️ Auto loop stopped")
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
    
    local char = player.Character
    if char then CompleteCharacterReset(char) end
    
    print("⏹️ Auto loop stopped")
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
    
    local char = player.Character
    if char then CompleteCharacterReset(char) end
    
    print("⏹️ Playback stopped")
end

function PausePlayback()
    if AutoLoop and IsAutoLoopPlaying then
        IsPaused = not IsPaused
        
        if IsPaused then
            PauseBtnBig.Text = "RESUME"
            PauseBtnBig.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
            RestoreFullUserControl()
            print("⏸️ Auto Loop paused - Full control restored")
        else
            PauseBtnBig.Text = "PAUSE"
            PauseBtnBig.BackgroundColor3 = Color3.fromRGB(180, 140, 40)
            SaveHumanoidState()
            DisableJump()
            print("▶️ Auto Loop resumed")
        end
    elseif IsPlaying then
        IsPaused = not IsPaused
        
        if IsPaused then
            PauseBtnBig.Text = "RESUME"
            PauseBtnBig.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
            RestoreFullUserControl()
            print("⏸️ Playback paused - Full control restored")
        else
            PauseBtnBig.Text = "PAUSE"
            PauseBtnBig.BackgroundColor3 = Color3.fromRGB(180, 140, 40)
            SaveHumanoidState()
            DisableJump()
            print("▶️ Playback resumed")
        end
    end
end

-- ========= SIMPLE JSON SAVE/LOAD FUNCTIONS =========
local function SaveToFile()
    local filename = FilenameBox.Text
    if filename == "" then filename = "MyReplays" end
    filename = filename .. ".json"
    
    if not next(RecordedMovements) then
        print("❌ No recordings to save!")
        return
    end
    
    local success, err = pcall(function()
        local saveData = {
            checkpoints = {},
            order = RecordingOrder,
            names = checkpointNames,
            settings = {
                speed = CurrentSpeed,
                autoLoop = AutoLoop,
                autoRespawn = AutoRespawn
            }
        }
        
        for name, frames in pairs(RecordedMovements) do
            local checkpointData = {
                name = checkpointNames[name] or name,
                frameCount = #frames,
                frames = {}
            }
            
            for i, frame in ipairs(frames) do
                table.insert(checkpointData.frames, {
                    p = frame.Position,
                    l = frame.LookVector,
                    u = frame.UpVector,
                    v = frame.Velocity,
                    m = frame.MoveState,
                    w = frame.WalkSpeed,
                    t = frame.Timestamp
                })
            end
            
            saveData.checkpoints[name] = checkpointData
        end
        
        local jsonString = HttpService:JSONEncode(saveData)
        writefile(filename, jsonString)
        print("💾 Saved: " .. filename)
    end)
    
    if not success then
        print("❌ Save failed: " .. tostring(err))
    end
end

local function LoadFromFile()
    local filename = FilenameBox.Text
    if filename == "" then filename = "MyReplays" end
    filename = filename .. ".json"
    
    local success, err = pcall(function()
        if not isfile(filename) then
            print("❌ File not found: " .. filename)
            return
        end
        
        local jsonString = readfile(filename)
        local data = HttpService:JSONDecode(jsonString)
        
        RecordedMovements = {}
        RecordingOrder = data.order or {}
        checkpointNames = data.names or {}
        
        for name, checkpointData in pairs(data.checkpoints or {}) do
            local frames = {}
            
            for i, simpleFrame in ipairs(checkpointData.frames or {}) do
                table.insert(frames, {
                    Position = simpleFrame.p or {0, 0, 0},
                    LookVector = simpleFrame.l or {0, 0, 1},
                    UpVector = simpleFrame.u or {0, 1, 0},
                    Velocity = simpleFrame.v or {0, 0, 0},
                    MoveState = simpleFrame.m or "Grounded",
                    WalkSpeed = simpleFrame.w or 16,
                    Timestamp = simpleFrame.t or 0
                })
            end
            
            RecordedMovements[name] = frames
        end
        
        CurrentSpeed = data.settings and data.settings.speed or 1
        AutoLoop = data.settings and data.settings.autoLoop or false
        AutoRespawn = data.settings and data.settings.autoRespawn or false
        
        SpeedBox.Text = string.format("%.2f", CurrentSpeed)
        
        UpdateRecordList()
        AnimateLoop(AutoLoop)
        AnimateRespawn(AutoRespawn)
        print("📂 Loaded: " .. filename)
    end)
    
    if not success then
        print("❌ Load failed: " .. tostring(err))
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
    
    print("🎨 Visualized paths for all recordings")
end

-- ========= BUTTON EVENTS =========
RecordBtnBig.MouseButton1Click:Connect(function()
    if IsRecording then StopRecording() else StartRecording() end
end)

SaveBtnBig.MouseButton1Click:Connect(SaveRecording)

PlayBtnBig.MouseButton1Click:Connect(function()
    if AutoLoop then return end
    PlayRecording()
end)

StopBtnBig.MouseButton1Click:Connect(StopPlayback)
PauseBtnBig.MouseButton1Click:Connect(PausePlayback)

LoopBtn.MouseButton1Click:Connect(function()
    AutoLoop = not AutoLoop
    AnimateLoop(AutoLoop)
    
    if AutoLoop then
        if not next(RecordedMovements) then
            AutoLoop = false
            AnimateLoop(false)
            print("❌ No recordings to loop!")
            return
        end
        
        if IsPlaying then
            IsPlaying = false
            IsPaused = false
            RestoreFullUserControl()
        end
        
        print("🔁 Auto Loop Started")
        StartAutoLoopAll()
    else
        StopAutoLoopAll()
        print("🔁 Auto Loop Stopped")
    end
end)

RespawnBtn.MouseButton1Click:Connect(function()
    AutoRespawn = not AutoRespawn
    AnimateRespawn(AutoRespawn)
    print("🔄 Auto Respawn: " .. (AutoRespawn and "ON" or "OFF"))
end)

SaveFileBtn.MouseButton1Click:Connect(SaveToFile)
LoadFileBtn.MouseButton1Click:Connect(LoadFromFile)

PathToggleBtn.MouseButton1Click:Connect(function()
    ShowPaths = not ShowPaths
    if ShowPaths then
        PathToggleBtn.Text = "🚫 RUTE"
        VisualizeAllPaths()
    else
        PathToggleBtn.Text = "🎨 RUTE"
        ClearPathVisualization()
    end
end)

MergeBtn.MouseButton1Click:Connect(CreateMergedReplay)

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
    CleanupConnections()
    ClearPathVisualization()
    ScreenGui:Destroy()
    print("👋 ByaruL Auto Walk System Closed")
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
        SaveToFile()
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
    end
end)