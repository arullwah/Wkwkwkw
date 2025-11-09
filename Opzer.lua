--[[
  GAZE • PERFORMANCE OPTIMIZER (FIXED | COMPACT + SCROLL) — 200x200
  - Satu GUI saja (tanpa tab).
  - Header kosong + tombol close, drag stabil (tanpa akses i.Target).
  - Preset tombol: LOW / MEDIUM / HIGH / ULTRA / AUTO DETECT / RESET.
  - Semua diposisikan di ScrollingFrame kecil supaya muat di 200x200.
  - Aman dari error “Expected identifier … got '='” dan “Target is not a valid member of InputObject”.
  - Tidak perlu Color3.fromHex / API aneh; semua memakai Color3.fromRGB.
]]

-------------------- HARD RESET --------------------
local CoreGui = game:GetService("CoreGui")
pcall(function()
    local old = CoreGui:FindFirstChild("GAZE_PerfOptimizer_FIXED")
    if old then old:Destroy() end
end)

-------------------- SERVICES ----------------------
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local RunService       = game:GetService("RunService")

-------------------- EFFECT HELPERS ----------------
local function ensureEffect(cls, name)
    local e = Lighting:FindFirstChild(name)
    if not e or not e:IsA(cls) then
        if e then pcall(function() e:Destroy() end) end
        e = Instance.new(cls)
        e.Name = name
        e.Parent = Lighting
    end
    return e
end
local function getFX()
    local CC   = ensureEffect("ColorCorrectionEffect","GAZE_CC")
    local Bloom= ensureEffect("BloomEffect","GAZE_Bloom")
    local SR   = ensureEffect("SunRaysEffect","GAZE_SunRays")
    local DOF  = ensureEffect("DepthOfFieldEffect","GAZE_DOF")
    return CC,Bloom,SR,DOF
end

-------------------- SNAPSHOT DEFAULTS -------------
local SNAP, HAS_DEFAULTS = {}, false
local function snapshotDefaults()
    if HAS_DEFAULTS then return end
    HAS_DEFAULTS = true
    SNAP = {
        Technology      = Lighting.Technology,
        Brightness      = Lighting.Brightness,
        GlobalShadows   = Lighting.GlobalShadows,
        EnvDiff         = Lighting.EnvironmentDiffuseScale,
        EnvSpec         = Lighting.EnvironmentSpecularScale,
        OutdoorAmbient  = Lighting.OutdoorAmbient,
        FogColor        = Lighting.FogColor,
        FogStart        = Lighting.FogStart,
        FogEnd          = Lighting.FogEnd,
    }
    local CC,Bloom,SR,DOF = getFX()
    SNAP.CC   = {B=CC.Brightness, C=CC.Contrast, S=CC.Saturation, T=CC.TintColor, E=CC.Enabled}
    SNAP.Bloom= {I=Bloom.Intensity, Z=Bloom.Size, Th=Bloom.Threshold, E=Bloom.Enabled}
    SNAP.SR   = {I=SR.Intensity, Sp=SR.Spread, E=SR.Enabled}
    SNAP.DOF  = {FD=DOF.FocusDistance, R=DOF.InFocusRadius, N=DOF.NearIntensity, F=DOF.FarIntensity, E=DOF.Enabled}
end

local function setQuality(q)
    local ok = pcall(function()
        settings().Rendering.QualityLevel = q   -- valid assignment, dibungkus pcall
    end)
    return ok
end

-------------------- PRESETS ------------------------
local function apply_LOW()
    snapshotDefaults()
    setQuality(Enum.QualityLevel.Level01)
    Lighting.Technology = Enum.Technology.Voxel
    Lighting.GlobalShadows = false
    Lighting.Brightness = 1.5
    Lighting.EnvironmentDiffuseScale = 0.1
    Lighting.EnvironmentSpecularScale = 0.1
    Lighting.OutdoorAmbient = Color3.fromRGB(0,0,0)
    Lighting.FogColor = Color3.fromRGB(0,0,0); Lighting.FogStart = 10; Lighting.FogEnd = 200
    local CC,Bloom,SR,DOF = getFX()
    CC.Enabled=false; Bloom.Enabled=false; SR.Enabled=false; DOF.Enabled=false
end

local function apply_MED()
    snapshotDefaults()
    setQuality(Enum.QualityLevel.Level05)
    Lighting.Technology = Enum.Technology.Voxel
    Lighting.GlobalShadows = false
    Lighting.Brightness = 2.0
    Lighting.EnvironmentDiffuseScale = 0.2
    Lighting.EnvironmentSpecularScale = 0.2
    Lighting.OutdoorAmbient = Color3.fromRGB(20,20,20)
    Lighting.FogColor = Color3.fromRGB(20,20,20); Lighting.FogStart = 50; Lighting.FogEnd = 600
    local CC,Bloom,SR,DOF = getFX()
    CC.Enabled=true; CC.Brightness=0.05; CC.Contrast=0.05; CC.Saturation=-0.05; CC.TintColor=Color3.fromRGB(255,255,255)
    Bloom.Enabled=false; SR.Enabled=false; DOF.Enabled=false
end

local function apply_HIGH()
    snapshotDefaults()
    setQuality(Enum.QualityLevel.Level08)
    Lighting.Technology = Enum.Technology.ShadowMap
    Lighting.GlobalShadows = true
    Lighting.Brightness = 2.2
    Lighting.EnvironmentDiffuseScale = 0.5
    Lighting.EnvironmentSpecularScale = 0.5
    Lighting.OutdoorAmbient = Color3.fromRGB(35,35,35)
    Lighting.FogColor = Color3.fromRGB(30,30,40); Lighting.FogStart=80; Lighting.FogEnd=1200
    local CC,Bloom,SR,DOF = getFX()
    CC.Enabled=true; CC.Brightness=0.08; CC.Contrast=0.08; CC.Saturation=0.05
    Bloom.Enabled=true; Bloom.Intensity=0.20; Bloom.Size=24; Bloom.Threshold=1.2
    SR.Enabled=true; SR.Intensity=0.05; SR.Spread=0.8
    DOF.Enabled=false
end

local function apply_ULTRA()
    snapshotDefaults()
    setQuality(Enum.QualityLevel.Level10)
    Lighting.Technology = Enum.Technology.Future
    Lighting.GlobalShadows = true
    Lighting.Brightness = 2.3
    Lighting.EnvironmentDiffuseScale = 1
    Lighting.EnvironmentSpecularScale = 1
    Lighting.OutdoorAmbient = Color3.fromRGB(45,45,45)
    Lighting.FogColor = Color3.fromRGB(45,45,60); Lighting.FogStart=150; Lighting.FogEnd=2000
    local CC,Bloom,SR,DOF = getFX()
    CC.Enabled=true; CC.Brightness=0.10; CC.Contrast=0.12; CC.Saturation=0.10
    Bloom.Enabled=true; Bloom.Intensity=0.35; Bloom.Size=32; Bloom.Threshold=1.1
    SR.Enabled=true; SR.Intensity=0.08; SR.Spread=1
    DOF.Enabled=true; DOF.FocusDistance=math.huge; DOF.InFocusRadius=50; DOF.NearIntensity=0; DOF.FarIntensity=0.15
end

local function apply_RESET()
    if not HAS_DEFAULTS then return end
    Lighting.Technology = SNAP.Technology
    Lighting.Brightness = SNAP.Brightness
    Lighting.GlobalShadows = SNAP.GlobalShadows
    Lighting.EnvironmentDiffuseScale = SNAP.EnvDiff
    Lighting.EnvironmentSpecularScale = SNAP.EnvSpec
    Lighting.OutdoorAmbient = SNAP.OutdoorAmbient
    Lighting.FogColor = SNAP.FogColor; Lighting.FogStart = SNAP.FogStart; Lighting.FogEnd = SNAP.FogEnd
    local CC,Bloom,SR,DOF = getFX()
    CC.Brightness=SNAP.CC.B; CC.Contrast=SNAP.CC.C; CC.Saturation=SNAP.CC.S; CC.TintColor=SNAP.CC.T; CC.Enabled=SNAP.CC.E
    Bloom.Intensity=SNAP.Bloom.I; Bloom.Size=SNAP.Bloom.Z; Bloom.Threshold=SNAP.Bloom.Th; Bloom.Enabled=SNAP.Bloom.E
    SR.Intensity=SNAP.SR.I; SR.Spread=SNAP.SR.Sp; SR.Enabled=SNAP.SR.E
    DOF.FocusDistance=SNAP.DOF.FD; DOF.InFocusRadius=SNAP.DOF.R; DOF.NearIntensity=SNAP.DOF.N; DOF.FarIntensity=SNAP.DOF.F; DOF.Enabled=SNAP.DOF.E
end

-------------------- AUTO DETECT --------------------
local function measureFPS(dur)
    dur = dur or 1.0
    local frames, t = 0, 0
    local c = RunService.RenderStepped:Connect(function(dt) frames = frames + 1; t = t + dt end)
    task.wait(dur)
    c:Disconnect()
    return (t > 0) and (frames / t) or 60
end
local function autoDetect()
    local CC,Bloom,SR,DOF = getFX()
    local prev={CC=CC.Enabled,Bloom=Bloom.Enabled,SR=SR.Enabled,DOF=DOF.Enabled}
    CC.Enabled=false; Bloom.Enabled=false; SR.Enabled=false; DOF.Enabled=false
    local fps = measureFPS(1.0)
    CC.Enabled=prev.CC; Bloom.Enabled=prev.Bloom; SR.Enabled=prev.SR; DOF.Enabled=prev.DOF
    if fps < 35 then apply_LOW()
    elseif fps < 55 then apply_MED()
    elseif fps < 85 then apply_HIGH()
    else apply_ULTRA() end
end

-------------------- GUI ROOT ----------------------
local root = Instance.new("ScreenGui")
root.Name = "GAZE_PerfOptimizer_FIXED"
root.ResetOnSpawn = false
root.IgnoreGuiInset = true
root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
root.DisplayOrder = 10000
root.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(200,200)
Main.Position = UDim2.new(0.5,-100,0.5,-100)
Main.BackgroundColor3 = Color3.fromRGB(0,0,0)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = root
Instance.new("UICorner", Main).CornerRadius = UDim.new(0,14)

-- Header kosong + close
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1,0,0,22)
Header.BackgroundColor3 = Color3.fromRGB(20,20,20)
Header.BorderSizePixel = 0
Header.Parent = Main
Instance.new("UICorner", Header).CornerRadius = UDim.new(0,14)

local Close = Instance.new("TextButton")
Close.AnchorPoint = Vector2.new(1,0)
Close.Position = UDim2.new(1,-6,0,3)
Close.Size = UDim2.fromOffset(20,16)
Close.Text = "x"
Close.Font = Enum.Font.GothamBold
Close.TextScaled = true
Close.TextColor3 = Color3.new(1,1,1)
Close.BackgroundColor3 = Color3.fromRGB(200,40,40)
Close.BorderSizePixel = 0
Close.Parent = Header
Instance.new("UICorner", Close).CornerRadius = UDim.new(0,5)
Close.MouseButton1Click:Connect(function() root:Destroy() end)

-- Drag stabil (tanpa i.Target)
do
    local dragging = false
    local dragStart, startPos
    local conn
    local function endDrag()
        dragging = false
        if conn then conn:Disconnect(); conn = nil end
    end
    local function begin(input)
        dragging = true
        dragStart = input.Position
        startPos  = Main.Position
        if conn then conn:Disconnect() end
        conn = UserInputService.InputChanged:Connect(function(i)
            if not dragging then return end
            if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
                local d = i.Position - dragStart
                Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then endDrag() end
        end)
    end
    for _,t in ipairs({Header, Main}) do
        t.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                begin(i)
            end
        end)
    end
end

-- Content (Scrolling agar semua tombol muat)
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1,-10,1,-(22+8))
Content.Position = UDim2.new(0,5,0,26)
Content.BackgroundTransparency = 1
Content.Parent = Main

local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1,0,1,0)
Scroll.ScrollBarThickness = 3
Scroll.BackgroundTransparency = 1
Scroll.CanvasSize = UDim2.new(0,0,0,0)
Scroll.Parent = Content

local UIL = Instance.new("UIListLayout", Scroll)
UIL.Padding = UDim.new(0,6)
UIL.SortOrder = Enum.SortOrder.LayoutOrder
local function fit() task.defer(function() Scroll.CanvasSize = UDim2.new(0,0,0, UIL.AbsoluteContentSize.Y + 6) end) end
UIL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)

local function Btn(text, color)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1,0,0,30)
    holder.BackgroundTransparency = 1
    holder.Parent = Scroll

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,1,0)
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextScaled = true
    btn.TextColor3 = Color3.new(1,1,1)
    btn.BackgroundColor3 = color or Color3.fromRGB(40,40,40)
    btn.BorderSizePixel = 0
    btn.Parent = holder
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)

    return btn
end

-- Tombol preset (singkat & jelas)
local bLow   = Btn("FPS+ LOW",    Color3.fromRGB(60,60,60))
local bMed   = Btn("FPS+ MEDIUM", Color3.fromRGB(75,75,75))
local bHigh  = Btn("FPS+ HIGH",   Color3.fromRGB(0,110,200))
local bUltra = Btn("FPS+ ULTRA",  Color3.fromRGB(0,140,60))
local bAuto  = Btn("AUTO DETECT", Color3.fromRGB(120,90,0))
local bReset = Btn("RESET DEFAULT", Color3.fromRGB(170,60,60))

bLow.MouseButton1Click:Connect(function()   apply_LOW()   end)
bMed.MouseButton1Click:Connect(function()   apply_MED()   end)
bHigh.MouseButton1Click:Connect(function()  apply_HIGH()  end)
bUltra.MouseButton1Click:Connect(function() apply_ULTRA() end)
bAuto.MouseButton1Click:Connect(function()  autoDetect()  end)
bReset.MouseButton1Click:Connect(function() apply_RESET() end)

fit()