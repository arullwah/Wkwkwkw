--[[
  GAZE • JUMP BUTTON MODIFIER GUI (180x180)
  - Panel 180x180, close di pojok kanan.
  - TextBox untuk set ukuran tombol lompat (px).
  - Tombol -10 / +10 untuk cepat ubah ukuran.
  - Toggle ON/OFF untuk mengaktifkan drag tombol lompat bawaan Roblox.
  - Tanpa notify, gaya simple 3D, kompatibel mouse & touch.
]]

-------------------- SERVICES --------------------
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-------------------- FIND DEFAULT JUMP BUTTON --------------------
local defaultJumpButton
local originalJumpSize
local originalJumpPosition
local jumpDragEnabled = false

local function FindJumpButton()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    local touchGui = playerGui:FindFirstChild("TouchGui")
    if not touchGui then return nil end
    local tcf = touchGui:FindFirstChild("TouchControlFrame")
    if not tcf then return nil end
    return tcf:FindFirstChild("JumpButton")
end

local function EnsureJumpButton()
    -- coba beberapa kali biar aman saat UI bawaan belum siap
    for _ = 1, 60 do
        defaultJumpButton = FindJumpButton()
        if defaultJumpButton then
            originalJumpSize = defaultJumpButton.Size
            originalJumpPosition = defaultJumpButton.Position
            break
        end
        task.wait(0.1)
    end
end

-------------------- DRAG HANDLER UNTUK JUMP BUTTON --------------------
local function MakeJumpDraggable(button)
    if not button then return end
    local dragging = false
    local dragInput, dragStart, startPos

    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            if jumpDragEnabled then
                dragging = true
                dragStart = input.Position
                startPos = button.Position
                button.ZIndex = 10
            end
        end
    end)

    button.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            button.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            button.ZIndex = 1
        end
    end)
end

-------------------- GUI 180x180 --------------------
local CoreGui = game:GetService("CoreGui")
pcall(function()
    local old = CoreGui:FindFirstChild("GAZE_JumpModifier_180")
    if old then old:Destroy() end
end)

local root = Instance.new("ScreenGui")
root.Name = "GAZE_JumpModifier_180"
root.ResetOnSpawn = false
root.IgnoreGuiInset = true
root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
root.DisplayOrder = 10000
root.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(180, 180)
Main.Position = UDim2.new(0.5, -90, 0.5, -90)
Main.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = root

local corner = Instance.new("UICorner", Main)
corner.CornerRadius = UDim.new(0, 14)

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 24)
Header.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Header.BorderSizePixel = 0
Header.Parent = Main
local hcorn = Instance.new("UICorner", Header); hcorn.CornerRadius = UDim.new(0, 14)

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(1, -40, 1, 0)
Title.Position = UDim2.new(0, 8, 0, 0)
Title.Font = Enum.Font.GothamBold
Title.Text = ""
Title.TextColor3 = Color3.new(1,1,1)
Title.TextScaled = true
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Close = Instance.new("TextButton")
Close.AnchorPoint = Vector2.new(1,0)
Close.Position = UDim2.new(1, -6, 0, 4)
Close.Size = UDim2.fromOffset(22, 16)
Close.BackgroundColor3 = Color3.fromRGB(200,40,40)
Close.BorderSizePixel = 0
Close.Text = "x"
Close.TextScaled = true
Close.Font = Enum.Font.GothamBold
Close.TextColor3 = Color3.new(1,1,1)
Close.Parent = Header
local cc = Instance.new("UICorner", Close); cc.CornerRadius = UDim.new(0,6)
Close.MouseButton1Click:Connect(function() root:Destroy() end)

-- Drag panel (global, stabil)
do
    local dragging=false; local dragStart; local startPos; local conn
    local function endDrag() dragging=false; if conn then conn:Disconnect() conn=nil end end
    local function begin(input)
        dragging=true; dragStart=input.Position; startPos=Main.Position
        if conn then conn:Disconnect() end
        conn = UserInputService.InputChanged:Connect(function(i)
            if not dragging then return end
            if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
                local d=i.Position-dragStart
                Main.Position = UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
            end
        end)
        input.Changed:Connect(function()
            if input.UserInputState==Enum.UserInputState.End then endDrag() end
        end)
    end
    local function hook(t)
        t.InputBegan:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then begin(i) end
        end)
    end
    hook(Header); hook(Main)
end

-- Content
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -12, 1, - (24 + 12))
Content.Position = UDim2.new(0, 6, 0, 30)
Content.BackgroundTransparency = 1
Content.Parent = Main

-- TextBox untuk ukuran (px)
local SizeBox = Instance.new("TextBox")
SizeBox.PlaceholderText = "Ukuran px (50-200)"
SizeBox.Text = ""
SizeBox.ClearTextOnFocus = false
SizeBox.Size = UDim2.new(1, 0, 0, 28)
SizeBox.Font = Enum.Font.Gotham
SizeBox.TextScaled = true
SizeBox.TextColor3 = Color3.new(1,1,1)
SizeBox.BackgroundColor3 = Color3.fromRGB(30,30,30)
SizeBox.BorderSizePixel = 0
SizeBox.Parent = Content
local sbc = Instance.new("UICorner", SizeBox); sbc.CornerRadius = UDim.new(0, 8)

-- Row tombol -10 / +10
local Row = Instance.new("Frame")
Row.Size = UDim2.new(1,0,0,28)
Row.Position = UDim2.new(0,0,0,34)
Row.BackgroundTransparency = 1
Row.Parent = Content

local function SmallBtn(parent, text)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.48, 0, 1, 0)
    b.BackgroundColor3 = Color3.fromRGB(45,45,45)
    b.BorderSizePixel = 0
    b.Text = text
    b.TextScaled = true
    b.Font = Enum.Font.GothamBold
    b.TextColor3 = Color3.new(1,1,1)
    b.Parent = parent
    local c = Instance.new("UICorner", b); c.CornerRadius = UDim.new(0, 8)
    return b
end

local Minus10 = SmallBtn(Row, "-10")
Minus10.Position = UDim2.new(0,0,0,0)
local Plus10 = SmallBtn(Row, "+10")
Plus10.Position = UDim2.new(1,0,0,0); Plus10.AnchorPoint = Vector2.new(1,0)

-- Toggle drag ON/OFF
local DragToggle = Instance.new("TextButton")
DragToggle.Size = UDim2.new(1,0,0,30)
DragToggle.Position = UDim2.new(0,0,0,68)
DragToggle.BackgroundColor3 = Color3.fromRGB(60,60,60)
DragToggle.BorderSizePixel = 0
DragToggle.Text = "Drag: OFF"
DragToggle.TextScaled = true
DragToggle.Font = Enum.Font.GothamBold
DragToggle.TextColor3 = Color3.new(1,1,1)
DragToggle.Parent = Content
local dtc = Instance.new("UICorner", DragToggle); dtc.CornerRadius = UDim.new(0, 8)

local function setToggleVisual()
    if jumpDragEnabled then
        DragToggle.BackgroundColor3 = Color3.fromRGB(0, 140, 60)
        DragToggle.Text = "Drag: ON"
    else
        DragToggle.BackgroundColor3 = Color3.fromRGB(60,60,60)
        DragToggle.Text = "Drag: OFF"
    end
end

DragToggle.MouseButton1Click:Connect(function()
    jumpDragEnabled = not jumpDragEnabled
    setToggleVisual()
end)

-------------------- LOGIKA UKURAN --------------------
local MIN_PX, MAX_PX = 50, 500

local function Clamp(n) return math.clamp(n, MIN_PX, MAX_PX) end

local function ApplySize(px)
    if defaultJumpButton then
        defaultJumpButton.Size = UDim2.new(0, px, 0, px)
    end
end

Minus10.MouseButton1Click:Connect(function()
    if not defaultJumpButton then return end
    local cur = defaultJumpButton.Size.Y.Offset
    ApplySize(Clamp(cur - 10))
end)

Plus10.MouseButton1Click:Connect(function()
    if not defaultJumpButton then return end
    local cur = defaultJumpButton.Size.Y.Offset
    ApplySize(Clamp(cur + 10))
end)

SizeBox.FocusLost:Connect(function(enterPressed)
    local v = tonumber(SizeBox.Text)
    if v then
        ApplySize(Clamp(math.floor(v)))
    end
end)

-------------------- INIT --------------------
task.spawn(function()
    EnsureJumpButton()
    if defaultJumpButton then
        -- jika belum pernah dipasang handler drag, pasang sekarang
        MakeJumpDraggable(defaultJumpButton)
        -- set placeholder nilai awal
        SizeBox.PlaceholderText = "..."
    end
    setToggleVisual()
end)