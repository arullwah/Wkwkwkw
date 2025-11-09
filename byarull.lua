--[[
  GAZE • SIMPLE LAUNCHER (RAW GITHUB SAFE) — 200x200
  - Tombol sederhana, warna utama: Color3.fromRGB(59,15,116).
  - Tanpa tab/notify. Scroll kecil bila daftar panjang.
  - Aman di banyak executor (pcall + multi-backend fetch).
  - Memory Cleaner DIHAPUS dari daftar.
]]

-------------------- PENGATURAN --------------------
local AUTO_HIDE = true
local BTN_COLOR = Color3.fromRGB(59, 15, 116)

-------------------- HARD RESET --------------------
local CoreGui = game:GetService("CoreGui")
pcall(function()
    local old = CoreGui:FindFirstChild("GAZE_SimpleLauncher")
    if old then old:Destroy() end
end)

-------------------- SAFE FETCH --------------------
local HttpService = game:GetService("HttpService")

local function try_request(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body)=="string" and #body>0 then return true, body end

    ok, body = pcall(function() return HttpService:GetAsync(url, true) end)
    if ok and type(body)=="string" and #body>0 then return true, body end

    local req = (typeof(syn)=="table" and syn.request)
            or (typeof(request)=="function" and request)
            or (typeof(http_request)=="function" and http_request)
    if req then
        local ok2, res = pcall(req, {Url=url, Method="GET"})
        if ok2 and res and type(res.Body)=="string" and #res.Body>0 then
            return true, res.Body
        end
    end
    return false, "fetch failed"
end

local launching = false
local function launch(url)
    if launching then return end
    launching = true
    task.spawn(function()
        local full = url .. (url:find("?") and "&" or "?") .. "cb=" .. tostring(math.random(1,1e9))
        local ok, src = try_request(full)
        if not ok then launching=false return end
        local fn, err = loadstring(src)
        if not fn then launching=false return end
        pcall(fn)
        launching = false
    end)
    if AUTO_HIDE and root then root.Enabled = false end
end

-------------------- LINK RAW ----------------------
local LINKS = {
    {"Animation",      "https://raw.githubusercontent.com/arullwah/Wkwkwkw/refs/heads/main/anim.lua"},
    {"Emote",          "https://raw.githubusercontent.com/arullwah/Wkwkwkw/refs/heads/main/Emot_ah.lua"},
    {"Fly",            "https://raw.githubusercontent.com/arullwah/Wkwkwkw/refs/heads/main/Flyik.lua"},
    {"Jump Button",    "https://raw.githubusercontent.com/arullwah/Wkwkwkw/refs/heads/main/Jumboet.lua"},
    {"Teleport",       "https://raw.githubusercontent.com/arullwah/Wkwkwkw/refs/heads/main/Telport.lua"},
    {"Spectate",       "https://raw.githubusercontent.com/arullwah/Wkwkwkw/refs/heads/main/Spectattei.lua"},
    {"Performance",    "https://raw.githubusercontent.com/arullwah/Wkwkwkw/refs/heads/main/Opzer.lua"},
    {"Realistic Mode", "https://raw.githubusercontent.com/arullwah/Wkwkwkw/refs/heads/main/Relic.lua"},
    -- Memory Cleaner dihapus
}

-------------------- GUI ROOT ----------------------
local root = Instance.new("ScreenGui")
root.Name = "GAZE_SimpleLauncher"
root.ResetOnSpawn = false
root.IgnoreGuiInset = true
root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
root.DisplayOrder = 10000
root.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(200,200)
Main.Position = UDim2.new(0.5,-100,0.5,-100)
Main.BackgroundColor3 = Color3.fromRGB(20,20,25) -- Diperjelas background
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = root
Instance.new("UICorner", Main).CornerRadius = UDim.new(0,14)

-- Header dengan title
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1,0,0,22)
Header.BackgroundColor3 = Color3.fromRGB(25,25,35)
Header.BorderSizePixel = 0
Header.Parent = Main
Instance.new("UICorner", Header).CornerRadius = UDim.new(0,14)

-- Title text
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1,-30,1,0)
Title.Position = UDim2.new(0,8,0,0)
Title.BackgroundTransparency = 1
Title.Text = "Menu ByaruL"
Title.TextColor3 = Color3.fromRGB(255,255,255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Close = Instance.new("TextButton")
Close.AnchorPoint = Vector2.new(1,0)
Close.Position = UDim2.new(1,-6,0,3)
Close.Size = UDim2.fromOffset(20,16)
Close.Text = "×"
Close.Font = Enum.Font.GothamBold
Close.TextSize = 14
Close.TextColor3 = Color3.new(1,1,1)
Close.BackgroundColor3 = Color3.fromRGB(200,40,40)
Close.BorderSizePixel = 0
Close.Parent = Header
Instance.new("UICorner", Close).CornerRadius = UDim.new(0,5)
Close.MouseButton1Click:Connect(function() root:Destroy() end)

-- Drag stabil
local UserInputService = game:GetService("UserInputService")
do
    local dragging=false; local dragStart; local startPos; local conn
    local function endDrag() dragging=false; if conn then conn:Disconnect(); conn=nil end end
    local function begin(input)
        dragging=true; dragStart=input.Position; startPos=Main.Position
        if conn then conn:Disconnect() end
        conn = UserInputService.InputChanged:Connect(function(i)
            if not dragging then return end
            if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
                local d=i.Position - dragStart
                Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
        input.Changed:Connect(function()
            if input.UserInputState==Enum.UserInputState.End then endDrag() end
        end)
    end
    for _,t in ipairs({Header, Main}) do
        t.InputBegan:Connect(function(i)
            local ut=i.UserInputType
            if ut==Enum.UserInputType.MouseButton1 or ut==Enum.UserInputType.Touch then begin(i) end
        end)
    end
end

-------------------- SCROLL & BUTTONS --------------
local Container = Instance.new("Frame")
Container.Size = UDim2.new(1,-10,1,-(22+8))
Container.Position = UDim2.new(0,5,0,26)
Container.BackgroundTransparency = 1
Container.Parent = Main

local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1,0,1,0)
Scroll.BackgroundTransparency = 1
Scroll.ScrollBarThickness = 3
Scroll.ScrollBarImageColor3 = Color3.fromRGB(100,100,150)
Scroll.CanvasSize = UDim2.new(0,0,0,0)
Scroll.Parent = Container

local UIL = Instance.new("UIListLayout", Scroll)
UIL.Padding = UDim.new(0,6)
UIL.SortOrder = Enum.SortOrder.LayoutOrder
local function fit() task.defer(function() Scroll.CanvasSize = UDim2.new(0,0,0, UIL.AbsoluteContentSize.Y+6) end) end
UIL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)

local function mkButton(text)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1,0,0,32)
    holder.BackgroundTransparency = 1
    holder.Parent = Scroll

    -- Shadow dulu (di belakang)
    local shadow = Instance.new("Frame")
    shadow.Size = UDim2.new(1,0,1,0)
    shadow.Position = UDim2.new(0,0,0,2)
    shadow.BackgroundColor3 = Color3.fromRGB(10,10,15)
    shadow.BorderSizePixel = 0
    shadow.ZIndex = 1
    shadow.Parent = holder
    Instance.new("UICorner", shadow).CornerRadius = UDim.new(0,8)

    -- Button utama
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,1,0)
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12 -- FIX: Ukuran teks tetap
    btn.TextColor3 = Color3.fromRGB(255,255,255) -- FIX: Warna teks putih
    btn.BackgroundColor3 = BTN_COLOR
    btn.BorderSizePixel = 0
    btn.ZIndex = 2 -- FIX: Button di atas shadow
    btn.Parent = holder
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)

    -- Stroke untuk kontras tambahan
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255,255,255)
    stroke.Thickness = 1
    stroke.Transparency = 0.8
    stroke.Parent = btn

    -- Animasi hover
    btn.MouseEnter:Connect(function()
        game:GetService("TweenService"):Create(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(79, 35, 136) -- Warna lebih terang
        }):Play()
    end)

    btn.MouseLeave:Connect(function()
        game:GetService("TweenService"):Create(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = BTN_COLOR
        }):Play()
    end)

    return btn
end

-- Buat semua button
for _, item in ipairs(LINKS) do
    local title, url = item[1], item[2]
    local b = mkButton(title)
    b.MouseButton1Click:Connect(function() 
        launch(url) 
    end)
end

fit()