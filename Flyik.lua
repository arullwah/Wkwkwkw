--[[
  FLY SYSTEM • GAZE-STYLE ELEGANT UI
  - UI elegan ala "GAZE Emote": dark glossy, rounded, tombol berwarna tegas.
  - Header minimalis (Close + Hide), draggable (mobile/PC), mini-button "A" mengapung.
  - Kompatibel mobile (PlayerModule:GetControls()) & PC (WASD/Space/Shift).
  - Noclip Fly via RunService.Stepped, aman enable/disable.
  - Speed control: TextBox + tombol -10 / +10.
]]

--========================= SERVICES =========================
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

--========================= FLY STATE ========================
local flyEnabled = false
local flySpeed = 50
local rotationSpeed = 1.9
local noclipFly = true

local bodyGyro : BodyGyro? = nil
local bodyVelocity : BodyVelocity? = nil
local flyConnection : RBXScriptConnection? = nil
local noclipConnection : RBXScriptConnection? = nil

--=================== MOBILE CONTROL MODULE ==================
local controlModule = nil
pcall(function()
    local ps = player:WaitForChild("PlayerScripts", 5)
    if ps then
        local playerModule = require(ps:WaitForChild("PlayerModule"))
        controlModule = playerModule:GetControls()
    end
end)

--========================= HELPERS ==========================
local function toast(t)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title="FLY", Text=tostring(t), Duration=3})
    end)
end

-- glossy + rounded ala GAZE
local function glossy(frame: Instance, r: number?)
    local u = frame:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
    u.CornerRadius = UDim.new(0, r or 10); u.Parent = frame

    local g = frame:FindFirstChild("Gloss") or Instance.new("Frame")
    g.Name = "Gloss"; g.Parent = frame
    g.BackgroundTransparency = 0; g.BorderSizePixel = 0
    g.BackgroundColor3 = Color3.new(1,1,1)
    g.ZIndex = (frame.ZIndex or 1) + 1
    local h = math.max(6, math.floor((frame.AbsoluteSize.Y/200)*14))
    g.Size = UDim2.new(1,0,0,h)

    local grad = g:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
    grad.Parent = g
    grad.Rotation = 90
    grad.Color = ColorSequence.new(Color3.new(1,1,1), Color3.new(0,0,0))
    grad.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0,0.82),
        NumberSequenceKeypoint.new(1,1)
    }
end

local function mkButton(parent: Instance, text: string, bg: Color3)
    local b = Instance.new("TextButton")
    b.Parent = parent
    b.Text = text or ""
    b.Font = Enum.Font.GothamBold
    b.TextScaled = true
    b.TextColor3 = Color3.new(1,1,1)
    b.BackgroundColor3 = bg or Color3.fromRGB(30,30,30)
    b.AutoButtonColor = true
    glossy(b, 8)
    return b
end

local function mkLabel(parent: Instance, text: string)
    local l = Instance.new("TextLabel")
    l.Parent = parent
    l.Text = text or ""
    l.Font = Enum.Font.Gotham
    l.TextScaled = true
    l.TextWrapped = true
    l.BackgroundTransparency = 1
    l.TextColor3 = Color3.new(1,1,1)
    return l
end

local function mkBox(parent: Instance, text: string)
    local tb = Instance.new("TextBox")
    tb.Parent = parent
    tb.Font = Enum.Font.GothamBold
    tb.TextScaled = true
    tb.TextWrapped = true
    tb.ClearTextOnFocus = false
    tb.Text = text or ""
    tb.TextColor3 = Color3.new(1,1,1)
    tb.PlaceholderText = "speed"
    tb.PlaceholderColor3 = Color3.fromRGB(180,180,180)
    tb.BackgroundColor3 = Color3.fromRGB(25,25,25)
    glossy(tb, 6)
    return tb
end

--========================= NOCLIP ===========================
local function enableNoclip(character: Model?)
    if noclipConnection then noclipConnection:Disconnect() end
    noclipConnection = RunService.Stepped:Connect(function()
        if not flyEnabled or not noclipFly then return end
        if not character or not character.Parent then return end
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
end

local function disableNoclip(character: Model?)
    if noclipConnection then noclipConnection:Disconnect(); noclipConnection = nil end
    if character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
    end
end

--=========================== FLY ============================
local function toggleFly(enabled: boolean)
    flyEnabled = enabled
    if enabled then
        local character = player.Character or player.CharacterAdded:Wait()
        local humanoid = character:WaitForChild("Humanoid")
        local root = character:WaitForChild("HumanoidRootPart")

        humanoid.PlatformStand = true

        bodyGyro = Instance.new("BodyGyro")
        bodyGyro.P = 9e4
        bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        bodyGyro.CFrame = root.CFrame
        bodyGyro.Parent = root

        bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.Velocity = Vector3.zero
        bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        bodyVelocity.Parent = root

        if noclipFly then
            enableNoclip(character)
        end

        local camera = workspace.CurrentCamera
        local lastLook = camera.CFrame.LookVector

        if flyConnection then flyConnection:Disconnect() end
        flyConnection = RunService.Heartbeat:Connect(function()
            if not flyEnabled then return end
            character = player.Character
            if not character or not character:FindFirstChild("HumanoidRootPart") then return end
            root = character.HumanoidRootPart
            humanoid = character:FindFirstChildOfClass("Humanoid")
            if not humanoid or not root then return end

            local camCF = camera.CFrame
            local look = camCF.LookVector
            local right = camCF.RightVector
            local targetVel = Vector3.zero

            -- Mobile
            if controlModule then
                local mv = controlModule:GetMoveVector()
                if mv.Magnitude > 0 then
                    local worldMove = camCF:VectorToWorldSpace(mv)
                    targetVel = worldMove.Unit * flySpeed
                end
            end
            -- PC
            if UIS:IsKeyDown(Enum.KeyCode.W) then targetVel += look * flySpeed end
            if UIS:IsKeyDown(Enum.KeyCode.S) then targetVel -= look * flySpeed end
            if UIS:IsKeyDown(Enum.KeyCode.A) then targetVel -= right * flySpeed end
            if UIS:IsKeyDown(Enum.KeyCode.D) then targetVel += right * flySpeed end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then targetVel += Vector3.new(0, flySpeed, 0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then targetVel -= Vector3.new(0, flySpeed, 0) end

            bodyVelocity.Velocity = bodyVelocity.Velocity:Lerp(targetVel, 0.25)

            local currentLook = camera.CFrame.LookVector
            lastLook = lastLook:Lerp(currentLook, rotationSpeed * 0.016)
            bodyGyro.CFrame = CFrame.lookAt(root.Position, root.Position + lastLook)

            if targetVel.Magnitude == 0 then
                bodyVelocity.Velocity = Vector3.zero
                root.AssemblyLinearVelocity = Vector3.zero
            end
        end)
    else
        if flyConnection then flyConnection:Disconnect(); flyConnection = nil end
        if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end
        if bodyVelocity then bodyVelocity:Destroy(); bodyVelocity = nil end

        local character = player.Character
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            local root = character:FindFirstChild("HumanoidRootPart")
            if humanoid and root then
                humanoid.PlatformStand = false
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                disableNoclip(character)
            end
        end
    end
end

--=========================== GUI ===========================
-- Root
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FlySystemGUI_GAZE"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
if syn and syn.protect_gui then pcall(function() syn.protect_gui(ScreenGui) end) end
ScreenGui.Parent = player:WaitForChild("PlayerGui")

-- Main Card (elegan)
local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(200, 110) -- kamu bisa ubah ke 200x120 bila perlu
Main.Position = UDim2.new(0, 50, 0, 50)
Main.BackgroundColor3 = Color3.fromRGB(0,0,0)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui
glossy(Main, 12)

-- Header minimalis (Close + Hide)
local Header = Instance.new("Frame")
Header.Parent = Main
Header.Size = UDim2.new(1,0,0,22)
Header.BackgroundColor3 = Color3.fromRGB(10,10,10)
Header.BorderSizePixel = 0
glossy(Header, 10)

local btnClose = mkButton(Header, "x", Color3.fromRGB(200,40,40))
btnClose.AnchorPoint = Vector2.new(1,0)
btnClose.Position = UDim2.new(1,-4,0,4)
btnClose.Size = UDim2.fromOffset(18,14)

local btnHide = mkButton(Header, "_", Color3.fromRGB(40,40,40))
btnHide.AnchorPoint = Vector2.new(1,0)
btnHide.Position = UDim2.new(1,-26,0,4)
btnHide.Size = UDim2.fromOffset(18,14)

-- Body area
local Body = Instance.new("Frame")
Body.Parent = Main
Body.Size = UDim2.new(1,-8,1,-30)
Body.Position = UDim2.new(0,4,0,26)
Body.BackgroundTransparency = 1

-- Kiri: Toggle Fly (ala tombol "Play" GAZE)
local FlyBtn = mkButton(Body, "FLY: OFF", Color3.fromRGB(0,90,170))
FlyBtn.Position = UDim2.new(0,0,0,0)
FlyBtn.Size = UDim2.new(0.45, -2, 0, 36)

-- Kanan atas: Speed Box
local SpeedBox = mkBox(Body, tostring(flySpeed))
SpeedBox.Position = UDim2.new(0.5, 2, 0, 0)
SpeedBox.Size = UDim2.new(0.5, -2, 0, 36)

-- Bawah kiri: -10
local BtnMinus = mkButton(Body, "-10", Color3.fromRGB(35,35,35))
BtnMinus.Position = UDim2.new(0,0,0,42)
BtnMinus.Size = UDim2.new(0.23, -1, 0, 28)

-- Bawah tengah: +10
local BtnPlus = mkButton(Body, "+10", Color3.fromRGB(35,35,35))
BtnPlus.Position = UDim2.new(0.24,0,0,42)
BtnPlus.Size = UDim2.new(0.23, -1, 0, 28)

-- Bawah kanan: Noclip toggle
local NoclipBtn = mkButton(Body, "NCLP: ON", Color3.fromRGB(0,150,0))
NoclipBtn.Position = UDim2.new(0.5, 2, 0, 42)
NoclipBtn.Size = UDim2.new(0.5, -2, 0, 28)

-- Mini floating button "A" (ala GAZE)
local MiniBtn = mkButton(ScreenGui, "A", Color3.fromRGB(0,0,0))
MiniBtn.TextScaled = true
MiniBtn.Size = UDim2.fromOffset(46,46)
MiniBtn.Position = UDim2.new(0, 12, 0.5, -23)
MiniBtn.Visible = false
MiniBtn.ZIndex = 9999

--===================== DRAG (Mobile & PC) ===================
do
    local dragging=false
    local dragStart, startPos

    local function begin(input)
        dragging=true
        dragStart = input.Position
        startPos  = Main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging=false end
        end)
    end
    local function update(input)
        if not dragging then return end
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end

    -- drag dari header
    Header.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then begin(i) end
    end)
    Header.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then update(i) end
    end)
    -- drag juga dari body
    Body.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then begin(i) end
    end)
    Body.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then update(i) end
    end)
end

--======================= BUTTON LOGIC =======================
local function updateFlyVisual()
    FlyBtn.Text = flyEnabled and "FLY: ON" or "FLY: OFF"
    FlyBtn.BackgroundColor3 = flyEnabled and Color3.fromRGB(0,170,90) or Color3.fromRGB(0,90,170)
end

local function setSpeed(v)
    v = math.clamp(math.floor(tonumber(v) or flySpeed), 1, 500)
    flySpeed = v
    SpeedBox.Text = tostring(v)
end

FlyBtn.MouseButton1Click:Connect(function()
    toggleFly(not flyEnabled)
    updateFlyVisual()
end)

BtnMinus.MouseButton1Click:Connect(function()
    setSpeed(flySpeed - 10)
end)

BtnPlus.MouseButton1Click:Connect(function()
    setSpeed(flySpeed + 10)
end)

SpeedBox.FocusLost:Connect(function()
    setSpeed(SpeedBox.Text)
end)

NoclipBtn.MouseButton1Click:Connect(function()
    noclipFly = not noclipFly
    NoclipBtn.Text = noclipFly and "NCLP: ON" or "NCLP: OFF"
    NoclipBtn.BackgroundColor3 = noclipFly and Color3.fromRGB(0,150,0) or Color3.fromRGB(70,70,70)
    local character = player.Character
    if noclipFly and flyEnabled and character then
        enableNoclip(character)
    else
        disableNoclip(character)
    end
end)

btnHide.MouseButton1Click:Connect(function()
    Main.Visible = false
    MiniBtn.Visible = true
end)

MiniBtn.MouseButton1Click:Connect(function()
    Main.Visible = true
    MiniBtn.Visible = false
end)

btnClose.MouseButton1Click:Connect(function()
    if flyEnabled then toggleFly(false) end
    ScreenGui:Destroy()
end)

-- Hotkey F toggle
UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F then
        toggleFly(not flyEnabled)
        updateFlyVisual()
    end
end)

--===================== FINAL TOUCHES ========================
-- glossy reflow saat size berubah (agar strip proporsional)
Main:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    local g=Main:FindFirstChild("Gloss"); if g then g:Destroy() end; glossy(Main,12)
end)
Header:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    local g=Header:FindFirstChild("Gloss"); if g then g:Destroy() end; glossy(Header,10)
end)

-- init
updateFlyVisual()