--[[
  GAZE • PERFORMANCE OPTIMIZER (FPS+ MODE) — 200x200
  Header kosong + tombol close (pojok kanan), drag stabil.
  Preset: FPS+ LOW / MEDIUM / HIGH / ULTRA + AUTO DETECT + RESET DEFAULT.
  Tanpa notify. Auto-save preset terakhir (jika writefile tersedia).
]]

-------------------- HARD RESET --------------------
local CoreGui = game:GetService("CoreGui")
pcall(function() local o = CoreGui:FindFirstChild("GAZE_PerfOptimizer") if o then o:Destroy() end end)

-------------------- SERVICES ----------------------
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")

-------------------- STORAGE -----------------------
local IO_OK = (typeof(writefile)=="function" and typeof(readfile)=="function" and typeof(isfile)=="function")
local CFG_FILE = "gaze_perf_optimizer.json"
local HttpService = game:GetService("HttpService")

local function savePreset(name)
    if not IO_OK then return end
    local ok, _ = pcall(function()
        writefile(CFG_FILE, HttpService:JSONEncode({preset=name}))
    end)
end
local function loadPreset()
    if not IO_OK or not isfile(CFG_FILE) then return nil end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(CFG_FILE))
    end)
    return (ok and data and data.preset) and data.preset or nil
end

-------------------- POST FX HELPERS ---------------
local function ensureEffect(cls, name)
    local e = Lighting:FindFirstChild(name)
    if not e or not e:IsA(cls) then
        if e then pcall(function() e:Destroy() end) end
        e = Instance.new(cls); e.Name = name; e.Parent = Lighting
    end
    return e
end

local function getFX()
    local CC   = ensureEffect("ColorCorrectionEffect", "GAZE_CC")
    local Bloom= ensureEffect("BloomEffect",            "GAZE_Bloom")
    local SR   = ensureEffect("SunRaysEffect",          "GAZE_SunRays")
    local DOF  = ensureEffect("DepthOfFieldEffect",     "GAZE_DOF")
    return CC, Bloom, SR, DOF
end

-------------------- DEFAULT SNAPSHOT --------------
local DEFAULTS_TAKEN = false
local SNAP = {}
local function snapshotDefaults()
    if DEFAULTS_TAKEN then return end
    DEFAULTS_TAKEN = true
    SNAP = {
        Technology            = Lighting.Technology,
        Brightness            = Lighting.Brightness,
        GlobalShadows         = Lighting.GlobalShadows,
        EnvironmentDiffuse    = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecular   = Lighting.EnvironmentSpecularScale,
        OutdoorAmbient        = Lighting.OutdoorAmbient,
        ClockTime             = Lighting.ClockTime,
        FogColor              = Lighting.FogColor,
        FogStart              = Lighting.FogStart,
        FogEnd                = Lighting.FogEnd,
    }
    local CC,Bloom,SR,DOF = getFX()
    SNAP.CC   = {Brightness=CC.Brightness, Contrast=CC.Contrast, Saturation=CC.Saturation, TintColor=CC.TintColor, Enabled=CC.Enabled}
    SNAP.Bloom= {Intensity=Bloom.Intensity, Size=Bloom.Size, Threshold=Bloom.Threshold, Enabled=Bloom.Enabled}
    SNAP.SR   = {Intensity=SR.Intensity, Spread=SR.Spread, Enabled=SR.Enabled}
    SNAP.DOF  = {FocusDistance=DOF.FocusDistance, InFocusRadius=DOF.InFocusRadius, NearIntensity=DOF.NearIntensity, FarIntensity=DOF.FarIntensity, Enabled=DOF.Enabled}
end

-------------------- QUALITY (best-effort) ---------
local function setQuality(levelEnum)
    local ok = pcall(function()
        settings().Rendering.QualityLevel = levelEnum
    end)
    if not ok then
        -- Abaikan jika tidak bisa di-set di environment user
    end
end

-------------------- PRESETS ------------------------
local function apply_LOW()
    snapshotDefaults()
    setQuality(Enum.QualityLevel.Level01)

    Lighting.Technology            = Enum.Technology.Voxel
    Lighting.GlobalShadows         = false
    Lighting.Brightness            = 1.5
    Lighting.EnvironmentDiffuseScale  = 0.1
    Lighting.EnvironmentSpecularScale = 0.1
    Lighting.OutdoorAmbient        = Color3.fromRGB(0,0,0)
    Lighting.FogColor              = Color3.fromRGB(0,0,0)
    Lighting.FogStart              = 10
    Lighting.FogEnd                = 200

    local CC,Bloom,SR,DOF = getFX()
    CC.Enabled    = false
    Bloom.Enabled = false
    SR.Enabled    = false
    DOF.Enabled   = false
end

local function apply_MEDIUM()
    snapshotDefaults()
    setQuality(Enum.QualityLevel.Level05)

    Lighting.Technology            = Enum.Technology.Voxel
    Lighting.GlobalShadows         = false
    Lighting.Brightness            = 2.0
    Lighting.EnvironmentDiffuseScale  = 0.2
    Lighting.EnvironmentSpecularScale = 0.2
    Lighting.OutdoorAmbient        = Color3.fromRGB(20,20,20)
    Lighting.FogColor              = Color3.fromRGB(20,20,20)
    Lighting.FogStart              = 50
    Lighting.FogEnd                = 600

    local CC,Bloom,SR,DOF = getFX()
    CC.Enabled    = true;  CC.Brightness = 0.05; CC.Contrast=0.05; CC.Saturation=-0.05; CC.TintColor=Color3.new(1,1,1)
    Bloom.Enabled = false
    SR.Enabled    = false
    DOF.Enabled   = false
end

local function apply_HIGH()
    snapshotDefaults()
    setQuality(Enum.QualityLevel.Level08)

    Lighting.Technology            = Enum.Technology.ShadowMap
    Lighting.GlobalShadows         = true
    Lighting.Brightness            = 2.2
    Lighting.EnvironmentDiffuseScale  = 0.5
    Lighting.EnvironmentSpecularScale = 0.5
    Lighting.OutdoorAmbient        = Color3.fromRGB(35,35,35)
    Lighting.FogColor              = Color3.fromRGB(30,30,40)
    Lighting.FogStart              = 80
    Lighting.FogEnd                = 1200

    local CC,Bloom,SR,DOF = getFX()
    CC.Enabled    = true;  CC.Brightness = 0.08; CC.Contrast=0.08; CC.Saturation=0.05; CC.TintColor=Color3.new(1,1,1)
    Bloom.Enabled = true;  Bloom.Intensity=0.2; Bloom.Size=24; Bloom.Threshold=1.2
    SR.Enabled    = true;  SR.Intensity=0.05; SR.Spread=0.8
    DOF.Enabled   = false
end

local function apply_ULTRA()
    snapshotDefaults()
    setQuality(Enum.QualityLevel.Level10)

    Lighting.Technology            = Enum.Technology.Future
    Lighting.GlobalShadows         = true
    Lighting.Brightness            = 2.3
    Lighting.EnvironmentDiffuseScale  = 1
    Lighting.EnvironmentSpecularScale = 1
    Lighting.OutdoorAmbient        = Color3.fromRGB(45,45,45)
    Lighting.FogColor              = Color3.fromRGB(45,45,60)
    Lighting.FogStart              = 150
    Lighting.FogEnd                = 2000

    local CC,Bloom,SR,DOF = getFX()
    CC.Enabled    = true;  CC.Brightness = 0.1;  CC.Contrast=0.12; CC.Saturation=0.1;  CC.TintColor=Color3.new(1,1,1)
    Bloom.Enabled = true;  Bloom.Intensity=0.35; Bloom.Size=32;   Bloom.Threshold=1.1
    SR.Enabled    = true;  SR.Intensity=0.08;  SR.Spread=1
    DOF.Enabled   = true;  DOF.FocusDistance=Infinity; DOF.InFocusRadius=50; DOF.NearIntensity=0; DOF.FarIntensity=0.15
end

local function apply_RESET()
    if not DEFAULTS_TAKEN then return end
    Lighting.Technology              = SNAP.Technology
    Lighting.Brightness              = SNAP.Brightness
    Lighting.GlobalShadows           = SNAP.GlobalShadows
    Lighting.EnvironmentDiffuseScale = SNAP.EnvironmentDiffuse
    Lighting.EnvironmentSpecularScale= SNAP.EnvironmentSpecular
    Lighting.OutdoorAmbient          = SNAP.OutdoorAmbient
    Lighting.ClockTime               = SNAP.ClockTime
    Lighting.FogColor                = SNAP.FogColor
    Lighting.FogStart                = SNAP.FogStart
    Lighting.FogEnd                  = SNAP.FogEnd

    local CC,Bloom,SR,DOF = getFX()
    CC.Brightness = SNAP.CC.Brightness; CC.Contrast=SNAP.CC.Contrast; CC.Saturation=SNAP.CC.Saturation; CC.TintColor=SNAP.CC.TintColor; CC.Enabled=SNAP.CC.Enabled
    Bloom.Intensity=SNAP.Bloom.Intensity; Bloom.Size=SNAP.Bloom.Size; Bloom.Threshold=SNAP.Bloom.Threshold; Bloom.Enabled=SNAP.Bloom.Enabled
    SR.Intensity   =SNAP.SR.Intensity;    SR.Spread=SNAP.SR.Spread;     SR.Enabled=SNAP.SR.Enabled
    DOF.FocusDistance=SNAP.DOF.FocusDistance; DOF.InFocusRadius=SNAP.DOF.InFocusRadius; DOF.NearIntensity=SNAP.DOF.NearIntensity; DOF.FarIntensity=SNAP.DOF.FarIntensity; DOF.Enabled=SNAP.DOF.Enabled
end

-------------------- AUTO DETECT --------------------
-- Sampling FPS singkat lalu pilih preset
local function measureFPS(duration)
    duration = duration or 1.5
    local frames, t = 0, 0
    local conn
    conn = game:GetService("RunService").RenderStepped:Connect(function(dt)
        frames += 1
        t += dt
    end)
    task.wait(duration)
    if conn then conn:Disconnect() end
    local fps = (t>0) and (frames/t) or 60
    return fps
end

local function autoDetect()
    -- Matikan efek dulu sementara untuk baca FPS "mentah".
    local CC,Bloom,SR,DOF = getFX()
    local prev = {CC=CC.Enabled,Bloom=Bloom.Enabled,SR=SR.Enabled,DOF=DOF.Enabled}
    CC.Enabled=false; Bloom.Enabled=false; SR.Enabled=false; DOF.Enabled=false

    local fps = measureFPS(1.2)

    -- Kembalikan state semula sebelum apply preset
    CC.Enabled=prev.CC; Bloom.Enabled=prev.Bloom; SR.Enabled=prev.SR; DOF.Enabled=prev.DOF

    if fps < 35 then
        apply_LOW();   savePreset("LOW")
    elseif fps < 55 then
        apply_MEDIUM();savePreset("MEDIUM")
    elseif fps < 85 then
        apply_HIGH();  savePreset("HIGH")
    else
        apply_ULTRA(); savePreset("ULTRA")
    end
end

-------------------- GUI ROOT ----------------------
local root = Instance.new("ScreenGui")
root.Name = "GAZE_PerfOptimizer"
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

-- Header kosong + close
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
Close.MouseButton1Click:Connect(function() root:Destroy() end)

-- Drag (global)
do
    local dragging=false; local dragStart; local startPos; local conn
    local function endDrag() dragging=false; if conn then conn:Disconnect(); conn=nil end end
    local function begin(input)
        dragging=true; dragStart=input.Position; startPos=Main.Position
        if conn then conn:Disconnect() end
        conn = UserInputService.InputChanged:Connect(function(i)
            if not dragging then return end
            if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
                local d=i.Position-dragStart
                Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
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

-- Content (buttons)
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1,-12,1,-(24+10))
Content.Position = UDim2.new(0,6,0,30)
Content.BackgroundTransparency = 1
Content.Parent = Main

local function SimpleBtn(parent, text, color)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1,0,0,32)
    holder.BackgroundTransparency = 1
    holder.Parent = parent

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,1,0)
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextScaled = true
    btn.TextColor3 = Color3.new(1,1,1)
    btn.BackgroundColor3 = color or Color3.fromRGB(35,35,35)
    btn.BorderSizePixel = 0
    btn.Parent = holder
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,10)

    local shadow = Instance.new("Frame")
    shadow.Size = UDim2.new(1,0,1,0)
    shadow.Position = UDim2.new(0,0,0,3)
    shadow.BackgroundColor3 = Color3.fromRGB(15,15,15)
    shadow.BorderSizePixel = 0
    shadow.Parent = holder
    Instance.new("UICorner", shadow).CornerRadius = UDim.new(0,10)

    btn:GetPropertyChangedSignal("Position"):Connect(function()
        shadow.Position = UDim2.new(btn.Position.X.Scale, btn.Position.X.Offset, btn.Position.Y.Scale, btn.Position.Y.Offset+3)
    end)
    btn:GetPropertyChangedSignal("Size"):Connect(function()
        shadow.Size = btn.Size
    end)
    return btn
end

-- Layout
local List = Instance.new("Frame")
List.Size = UDim2.new(1,0,1,0)
List.BackgroundTransparency = 1
List.Parent = Content

local UIList = Instance.new("UIListLayout", List)
UIList.Padding = UDim.new(0,6)
UIList.SortOrder = Enum.SortOrder.LayoutOrder

local bLow   = SimpleBtn(List, "FPS+ LOW",    Color3.fromRGB(60,60,60))
local bMed   = SimpleBtn(List, "FPS+ MEDIUM", Color3.fromRGB(70,70,70))
local bHigh  = SimpleBtn(List, "FPS+ HIGH",   Color3.fromRGB(0,110,200))
local bUltra = SimpleBtn(List, "FPS+ ULTRA",  Color3.fromRGB(0,140,60))
local bAuto  = SimpleBtn(List, "AUTO DETECT", Color3.fromRGB(120,90,0))
local bReset = SimpleBtn(List, "RESET DEFAULT", Color3.fromRGB(170,60,60))

-- Actions
bLow.MouseButton1Click:Connect(function()   apply_LOW();   savePreset("LOW")   end)
bMed.MouseButton1Click:Connect(function()   apply_MEDIUM();savePreset("MEDIUM")end)
bHigh.MouseButton1Click:Connect(function()  apply_HIGH();  savePreset("HIGH")  end)
bUltra.MouseButton1Click:Connect(function() apply_ULTRA(); savePreset("ULTRA") end)
bAuto.MouseButton1Click:Connect(function()  autoDetect()                     end)
bReset.MouseButton1Click:Connect(function() apply_RESET(); savePreset("RESET")end)

-- Apply last preset if exists
task.defer(function()
    local last = loadPreset()
    if last == "LOW" then apply_LOW()
    elseif last == "MEDIUM" then apply_MEDIUM()
    elseif last == "HIGH" then apply_HIGH()
    elseif last == "ULTRA" then apply_ULTRA()
    elseif last == "RESET" then apply_RESET()
    end
end)