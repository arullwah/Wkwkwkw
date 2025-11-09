--[[
  GAZE • REALISTIC MOTION & CAMERA FX (200x200)
  - Header kosong + tombol close (pojok kanan), drag stabil (mouse/touch).
  - Efek real-time (aktif per-toggle):
      • Shake (getar halus saat bergerak/berlari)
      • Tilt (miring saat belok/strafe)
      • Bob (head bob saat berjalan)
      • Jump Zoom (FOV naik saat lompat/terbang, kembali mulus)
  - Slider sederhana: - / + untuk atur intensitas.
  - RESET untuk kembalikan kamera (FOV/efek) ke default.
  - Tanpa notify.
]]

-------------------- HARD RESET --------------------
local CoreGui = game:GetService("CoreGui")
pcall(function()
    local old = CoreGui:FindFirstChild("GAZE_CameraFX")
    if old then old:Destroy() end
end)

-------------------- SERVICES ----------------------
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-------------------- SAFE HUMANOID ------------------
local function getHumanoid()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.25)
end)

-------------------- STATE & DEFAULTS ---------------
local BASE_FOV = Camera.FieldOfView
local FX_ENABLED = true

local cfg = {
    shake = {on=true,  amt=0.15, freq=6.0},   -- amt dalam studs (offset), freq Hz
    tilt  = {on=true,  amt=4.0},              -- derajat roll maksimal
    bob   = {on=true,  amt=0.12, freq=8.0},   -- bob offset Y dan X kecil
    zoom  = {on=true,  amt=10.0, speed=6.0},  -- tambahan FOV saat jump/freefall
}
local minmax = {
    shake = {0, 0.6},
    tilt  = {0, 10},
    bob   = {0, 0.5},
    zoom  = {0, 25},
}

-- internal
local rt = 0
local lastCF = Camera.CFrame
local bindName = "GAZE_CameraFX_Bind"

-------------------- MATH HELPERS -------------------
local function lerp(a,b,t) return a + (b-a)*t end
local function clamp(x,a,b) return math.max(a, math.min(b, x)) end
local function slerpFOV(target, dt, speed)
    Camera.FieldOfView = lerp(Camera.FieldOfView, target, 1 - math.exp(-speed*dt))
end

-------------------- MOTION READ --------------------
local function planarSpeed(root)
    if not root then return 0 end
    local v = root.Velocity
    return Vector3.new(v.X, 0, v.Z).Magnitude
end

local function groundedState(hum)
    if not hum then return false end
    local st = hum:GetState()
    return st == Enum.HumanoidStateType.Running
        or st == Enum.HumanoidStateType.RunningNoPhysics
        or st == Enum.HumanoidStateType.Landed
        or st == Enum.HumanoidStateType.Climbing
end

-------------------- RENDER LOOP --------------------
local function applyCameraFX(dt)
    if not FX_ENABLED then return end
    local hum = getHumanoid()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart") or nil
    if not (hum and root) then return end

    rt += dt

    -- dasar kamera setelah Roblox update
    local camCF = Camera.CFrame

    -- SPEED & MOVEDIR
    local spd = planarSpeed(root)
    local moving = spd > 0.1
    local moveDir = hum.MoveDirection

    -- ===== SHAKE =====
    local offset = Vector3.new()
    if cfg.shake.on and moving then
        -- gunakan simplex noise agar halus
        local n1 = math.noise(rt * cfg.shake.freq, 0, 0)
        local n2 = math.noise(0, rt * (cfg.shake.freq*1.13), 0)
        local n3 = math.noise(0, 0, rt * (cfg.shake.freq*0.91))
        local amt = cfg.shake.amt * clamp(spd/16, 0.6, 2.0) -- skala oleh kecepatan
        offset = Vector3.new(n1, n2, n3) * amt
    end

    -- ===== BOB =====
    if cfg.bob.on and moving then
        local w = rt * cfg.bob.freq * clamp(spd/10, 0.7, 2.0)
        local y = math.sin(w) * cfg.bob.amt
        local x = math.cos(w*0.5) * (cfg.bob.amt*0.4)
        offset += Vector3.new(x, y, 0)
    end

    -- ===== TILT =====
    local roll = 0
    if cfg.tilt.on and moving then
        -- proyeksikan MoveDirection ke sumbu kamera kanan
        local right = camCF.RightVector
        local side = right:Dot(moveDir)
        roll = clamp(-side * math.rad(cfg.tilt.amt), -math.rad(cfg.tilt.amt), math.rad(cfg.tilt.amt))
    end

    -- ===== ZOOM (JUMP / AIR) =====
    local inAir = not groundedState(hum)
    if cfg.zoom.on then
        local target = BASE_FOV + (inAir and cfg.zoom.amt or 0)
        slerpFOV(target, dt, cfg.zoom.speed)
    end

    -- TERAPKAN OFFSET & ROLL SETELAH UPDATE KAMERA
    camCF = camCF * CFrame.new(offset) * CFrame.Angles(0, 0, roll)
    Camera.CFrame = camCF

    lastCF = camCF
end

local function bind()
    if RunService:IsClient() then
        pcall(function() RunService:UnbindFromRenderStep(bindName) end)
        RunService:BindToRenderStep(bindName, Enum.RenderPriority.Camera.Value + 1, applyCameraFX)
    end
end
local function unbind()
    pcall(function() RunService:UnbindFromRenderStep(bindName) end)
end

-------------------- RESET --------------------------
local function resetCamera()
    FX_ENABLED = false
    unbind()
    task.wait() -- beri 1 frame untuk berhenti
    Camera.FieldOfView = BASE_FOV
    FX_ENABLED = true
    bind()
end

-------------------- GUI ROOT ----------------------
local root = Instance.new("ScreenGui")
root.Name = "GAZE_CameraFX"
root.ResetOnSpawn = false
root.IgnoreGuiInset = true
root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
root.DisplayOrder = 10000
root.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(200, 200)
Main.Position = UDim2.new(0.5, -100, 0.5, -100)
Main.BackgroundColor3 = Color3.fromRGB(0,0,0)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = root
Instance.new("UICorner", Main).CornerRadius = UDim.new(0,14)

-- Header kosong + tombol close
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1,0,0,24)
Header.BackgroundColor3 = Color3.fromRGB(20,20,20)
Header.BorderSizePixel = 0
Header.Parent = Main
Instance.new("UICorner", Header).CornerRadius = UDim.new(0,14)

local Close = Instance.new("TextButton")
Close.AnchorPoint = Vector2.new(1,0)
Close.Position = UDim2.new(1,-6,0,4)
Close.Size = UDim2.fromOffset(22,16)
Close.Text = "x"
Close.Font = Enum.Font.GothamBold
Close.TextScaled = true
Close.TextColor3 = Color3.new(1,1,1)
Close.BackgroundColor3 = Color3.fromRGB(200,40,40)
Close.BorderSizePixel = 0
Close.Parent = Header
Instance.new("UICorner", Close).CornerRadius = UDim.new(0,6)
Close.MouseButton1Click:Connect(function()
    FX_ENABLED = false
    unbind()
    Camera.FieldOfView = BASE_FOV
    root:Destroy()
end)

-- Drag (global, stabil)
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
    for _,t in ipairs({Header,Main}) do
        t.InputBegan:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
                begin(i)
            end
        end)
    end
end

-------------------- UI WIDGETS --------------------
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1,-12,1,-(24+10))
Content.Position = UDim2.new(0,6,0,30)
Content.BackgroundTransparency = 1
Content.Parent = Main

local List = Instance.new("ScrollingFrame")
List.Size = UDim2.new(1,0,1,-(28+6))
List.Position = UDim2.new(0,0,0,0)
List.BackgroundTransparency = 1
List.ScrollBarThickness = 4
List.CanvasSize = UDim2.new(0,0,0,0)
List.Parent = Content

local UIL = Instance.new("UIListLayout", List)
UIL.Padding = UDim.new(0,6)
UIL.SortOrder = Enum.SortOrder.LayoutOrder
local function fitCanvas() task.defer(function() List.CanvasSize = UDim2.new(0,0,0, UIL.AbsoluteContentSize.Y+8) end) end
UIL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitCanvas)

local function makeRow(title, key, isAngle)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,30)
    row.BackgroundColor3 = Color3.fromRGB(25,25,25)
    row.BorderSizePixel = 0
    row.Parent = List
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,8)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0,8,0,0)
    label.Size = UDim2.new(0.45, -8, 1, 0)
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = title
    label.TextColor3 = Color3.new(1,1,1)
    label.Parent = row

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0.22, 0, 0, 24)
    toggle.Position = UDim2.new(0.45, 0, 0.5, -12)
    toggle.Font = Enum.Font.GothamBold
    toggle.TextScaled = true
    toggle.TextColor3 = Color3.new(1,1,1)
    toggle.BackgroundColor3 = cfg[key].on and Color3.fromRGB(0,140,60) or Color3.fromRGB(60,60,60)
    toggle.Text = cfg[key].on and "ON" or "OFF"
    toggle.BorderSizePixel = 0
    toggle.Parent = row
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0,6)

    local minus = Instance.new("TextButton")
    minus.Size = UDim2.new(0.11, -2, 0, 24)
    minus.Position = UDim2.new(0.67, 2, 0.5, -12)
    minus.Text = "-"
    minus.Font = Enum.Font.GothamBold
    minus.TextScaled = true
    minus.TextColor3 = Color3.new(1,1,1)
    minus.BackgroundColor3 = Color3.fromRGB(45,45,45)
    minus.BorderSizePixel = 0
    minus.Parent = row
    Instance.new("UICorner", minus).CornerRadius = UDim.new(0,6)

    local val = Instance.new("TextLabel")
    val.BackgroundColor3 = Color3.fromRGB(35,35,35)
    val.BorderSizePixel = 0
    val.Size = UDim2.new(0.18, 0, 0, 24)
    val.Position = UDim2.new(0.78, 2, 0.5, -12)
    val.Font = Enum.Font.GothamBold
    val.TextScaled = true
    val.TextColor3 = Color3.new(1,1,1)
    val.Text = (isAngle and math.floor(cfg[key].amt) or string.format("%.2f", cfg[key].amt))
    val.Parent = row
    Instance.new("UICorner", val).CornerRadius = UDim.new(0,6)

    local plus = Instance.new("TextButton")
    plus.Size = UDim2.new(0.11, -2, 0, 24)
    plus.Position = UDim2.new(0.96, 0, 0.5, -12)
    plus.Text = "+"
    plus.Font = Enum.Font.GothamBold
    plus.TextScaled = true
    plus.TextColor3 = Color3.new(1,1,1)
    plus.BackgroundColor3 = Color3.fromRGB(45,45,45)
    plus.BorderSizePixel = 0
    plus.Parent = row
    Instance.new("UICorner", plus).CornerRadius = UDim.new(0,6)

    local function updateToggle()
        toggle.BackgroundColor3 = cfg[key].on and Color3.fromRGB(0,140,60) or Color3.fromRGB(60,60,60)
        toggle.Text = cfg[key].on and "ON" or "OFF"
        val.Text = (isAngle and math.floor(cfg[key].amt) or string.format("%.2f", cfg[key].amt))
    end

    toggle.MouseButton1Click:Connect(function()
        cfg[key].on = not cfg[key].on
        updateToggle()
    end)

    minus.MouseButton1Click:Connect(function()
        local lo, hi = minmax[key][1], minmax[key][2]
        cfg[key].amt = clamp(cfg[key].amt - (isAngle and 1 or 0.02), lo, hi)
        updateToggle()
    end)
    plus.MouseButton1Click:Connect(function()
        local lo, hi = minmax[key][1], minmax[key][2]
        cfg[key].amt = clamp(cfg[key].amt + (isAngle and 1 or 0.02), lo, hi)
        updateToggle()
    end)

    return row
end

makeRow("Shake", "shake", false)
makeRow("Tilt",  "tilt",  true )
makeRow("Bob",   "bob",   false)

do
    -- Row khusus Jump Zoom (FOV)
    local row = makeRow("Jump Zoom", "zoom", true)
    -- Tambah slider kecepatan transisi (kecil di bawah)
    local sub = Instance.new("Frame")
    sub.Size = UDim2.new(1,0,0,22)
    sub.BackgroundTransparency = 1
    sub.Parent = List

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0,8,0,0)
    lbl.Size = UDim2.new(0.55,-8,1,0)
    lbl.Font = Enum.Font.Gotham
    lbl.TextScaled = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = Color3.new(1,1,1)
    lbl.Text = "Smooth"
    lbl.Parent = sub

    local minus = Instance.new("TextButton")
    minus.Size = UDim2.new(0.17, -2, 1, 0)
    minus.Position = UDim2.new(0.55, 2, 0, 0)
    minus.Text = "-"
    minus.Font = Enum.Font.GothamBold
    minus.TextScaled = true
    minus.TextColor3 = Color3.new(1,1,1)
    minus.BackgroundColor3 = Color3.fromRGB(45,45,45)
    minus.BorderSizePixel = 0
    minus.Parent = sub
    Instance.new("UICorner", minus).CornerRadius = UDim.new(0,6)

    local val = Instance.new("TextLabel")
    val.Size = UDim2.new(0.18, 0, 1, 0)
    val.Position = UDim2.new(0.72, 2, 0, 0)
    val.BackgroundColor3 = Color3.fromRGB(35,35,35)
    val.BorderSizePixel = 0
    val.Font = Enum.Font.GothamBold
    val.TextScaled = true
    val.TextColor3 = Color3.new(1,1,1)
    val.Text = tostring(cfg.zoom.speed)
    val.Parent = sub
    Instance.new("UICorner", val).CornerRadius = UDim.new(0,6)

    local plus = Instance.new("TextButton")
    plus.Size = UDim2.new(0.17, -2, 1, 0)
    plus.Position = UDim2.new(0.90, 0, 0, 0)
    plus.Text = "+"
    plus.Font = Enum.Font.GothamBold
    plus.TextScaled = true
    plus.TextColor3 = Color3.new(1,1,1)
    plus.BackgroundColor3 = Color3.fromRGB(45,45,45)
    plus.BorderSizePixel = 0
    plus.Parent = sub
    Instance.new("UICorner", plus).CornerRadius = UDim.new(0,6)

    local function upd() val.Text = tostring(math.floor(cfg.zoom.speed*10)/10) end
    minus.MouseButton1Click:Connect(function()
        cfg.zoom.speed = clamp(cfg.zoom.speed - 0.5, 1, 20); upd()
    end)
    plus.MouseButton1Click:Connect(function()
        cfg.zoom.speed = clamp(cfg.zoom.speed + 0.5, 1, 20); upd()
    end)
    upd()
end

-- Bottom bar: RESET / DISABLE ALL
local Bottom = Instance.new("Frame")
Bottom.Size = UDim2.new(1,0,0,28)
Bottom.Position = UDim2.new(0,0,1,-28)
Bottom.BackgroundTransparency = 1
Bottom.Parent = Content

local ResetBtn = Instance.new("TextButton")
ResetBtn.Size = UDim2.new(0.48, -2, 1, 0)
ResetBtn.Position = UDim2.new(0,0,0,0)
ResetBtn.Text = "RESET"
ResetBtn.Font = Enum.Font.GothamBold
ResetBtn.TextScaled = true
ResetBtn.TextColor3 = Color3.new(1,1,1)
ResetBtn.BackgroundColor3 = Color3.fromRGB(170,60,60)
ResetBtn.BorderSizePixel = 0
ResetBtn.Parent = Bottom
Instance.new("UICorner", ResetBtn).CornerRadius = UDim.new(0,8)

local ToggleAll = Instance.new("TextButton")
ToggleAll.Size = UDim2.new(0.48, 0, 1, 0)
ToggleAll.Position = UDim2.new(1, 0, 0, 0); ToggleAll.AnchorPoint = Vector2.new(1,0)
ToggleAll.Text = "DISABLE ALL"
ToggleAll.Font = Enum.Font.GothamBold
ToggleAll.TextScaled = true
ToggleAll.TextColor3 = Color3.new(1,1,1)
ToggleAll.BackgroundColor3 = Color3.fromRGB(60,60,60)
ToggleAll.BorderSizePixel = 0
ToggleAll.Parent = Bottom
Instance.new("UICorner", ToggleAll).CornerRadius = UDim.new(0,8)

ResetBtn.MouseButton1Click:Connect(function()
    cfg.shake.on, cfg.tilt.on, cfg.bob.on, cfg.zoom.on = true, true, true, true
    cfg.shake.amt, cfg.shake.freq = 0.15, 6.0
    cfg.tilt.amt = 4.0
    cfg.bob.amt, cfg.bob.freq = 0.12, 8.0
    cfg.zoom.amt, cfg.zoom.speed = 10.0, 6.0
    resetCamera()
end)

local allOff = false
ToggleAll.MouseButton1Click:Connect(function()
    allOff = not allOff
    cfg.shake.on = not allOff
    cfg.tilt.on  = not allOff
    cfg.bob.on   = not allOff
    cfg.zoom.on  = not allOff
    ToggleAll.Text = allOff and "ENABLE ALL" or "DISABLE ALL"
    ToggleAll.BackgroundColor3 = allOff and Color3.fromRGB(0,140,60) or Color3.fromRGB(60,60,60)
end)

fitCanvas()

-------------------- START -------------------------
bind()

-- Safety: pulihkan FOV saat respawn / destroy
root.AncestryChanged:Connect(function(_, parent)
    if not parent then
        FX_ENABLED = false
        unbind()
        Camera.FieldOfView = BASE_FOV
    end
end)