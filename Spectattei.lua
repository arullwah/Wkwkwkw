--[[
  GAZE • SPECTATE PRO (200x200, header kosong + tombol close)
  - Daftar semua pemain (real-time), search + refresh.
  - Spectate siapa pun di server (kamera nempel ke Humanoid target).
  - Stream-in agresif di sekitar target agar lingkungan tidak hilang (StreamingEnabled safe).
  - Tanpa WindUI dan tanpa notify (clean).
]]

-------------------- HARD RESET --------------------
local CoreGui = game:GetService("CoreGui")
pcall(function()
    local old = CoreGui:FindFirstChild("GAZE_SpectatePro")
    if old then old:Destroy() end
end)

-------------------- SERVICES ----------------------
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-------------------- GUI ROOT (200x200) --------------------
local root = Instance.new("ScreenGui")
root.Name = "GAZE_SpectatePro"
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
Close.MouseButton1Click:Connect(function() root:Destroy() end)

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

-- Content
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1,-12,1,-(24+10))
Content.Position = UDim2.new(0,6,0,30)
Content.BackgroundTransparency = 1
Content.Parent = Main

-- Search + Refresh + Stop
local Search = Instance.new("TextBox")
Search.Size = UDim2.new(1,-88,0,24)
Search.PlaceholderText = "Cari pemain…"
Search.ClearTextOnFocus = false
Search.Text = ""
Search.Font = Enum.Font.Gotham
Search.TextScaled = true
Search.TextColor3 = Color3.new(1,1,1)
Search.BackgroundColor3 = Color3.fromRGB(30,30,30)
Search.BorderSizePixel = 0
Search.Parent = Content
Instance.new("UICorner", Search).CornerRadius = UDim.new(0,8)

local Refresh = Instance.new("TextButton")
Refresh.Size = UDim2.new(0,40,0,24)
Refresh.Position = UDim2.new(1,-82,0,0)
Refresh.Text = "Ref"
Refresh.Font = Enum.Font.GothamBold
Refresh.TextScaled = true
Refresh.TextColor3 = Color3.new(1,1,1)
Refresh.BackgroundColor3 = Color3.fromRGB(45,45,45)
Refresh.BorderSizePixel = 0
Refresh.Parent = Content
Instance.new("UICorner", Refresh).CornerRadius = UDim.new(0,8)

local StopBtn = Instance.new("TextButton")
StopBtn.Size = UDim2.new(0,40,0,24)
StopBtn.Position = UDim2.new(1,-40,0,0)
StopBtn.Text = "Stop"
StopBtn.Font = Enum.Font.GothamBold
StopBtn.TextScaled = true
StopBtn.TextColor3 = Color3.new(1,1,1)
StopBtn.BackgroundColor3 = Color3.fromRGB(170,60,60)
StopBtn.BorderSizePixel = 0
StopBtn.Parent = Content
Instance.new("UICorner", StopBtn).CornerRadius = UDim.new(0,8)

-- List pemain
local List = Instance.new("ScrollingFrame")
List.Size = UDim2.new(1,0,1,-(24+6))
List.Position = UDim2.new(0,0,0,30)
List.BackgroundTransparency = 1
List.ScrollBarThickness = 4
List.CanvasSize = UDim2.new(0,0,0,0)
List.Parent = Content

local UIL = Instance.new("UIListLayout", List)
UIL.Padding = UDim.new(0,6)
UIL.SortOrder = Enum.SortOrder.LayoutOrder
local function FitCanvas() task.defer(function() List.CanvasSize = UDim2.new(0,0,0, UIL.AbsoluteContentSize.Y + 8) end) end
UIL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(FitCanvas)

-------------------- SPECTATE ENGINE --------------------
local originalSubject, originalType
local spectatingTarget = nil
local streamConn, lifeConn

local STREAM_RING_RADIUS = 80         -- radius sampling orbit
local STREAM_REQUESTS = 6             -- titik orbit untuk prefetch
local STREAM_TICK = 0.1               -- interval request selama spectate
local STREAM_TIMEOUT = 3              -- waktu tunggu awal saat stream-in target

local function HumanoidOf(plr)
    return plr and plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
end
local function HRPOf(plr)
    local c = plr and plr.Character
    return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso"))
end

-- Prefetch area sekitar target: orbit kamera "virtual" untuk memicu stream
local function PrefetchAround(pos, radius, steps)
    if not workspace.RequestStreamAroundAsync then return end
    for i=1, steps do
        local a = (i/steps) * math.pi * 2
        local p = pos + Vector3.new(math.cos(a)*radius, 0, math.sin(a)*radius)
        pcall(function() workspace:RequestStreamAroundAsync(p) end)
        task.wait(0.03)
    end
end

local function RequestAround(pos)
    if workspace.RequestStreamAroundAsync then
        pcall(function() workspace:RequestStreamAroundAsync(pos) end)
    end
end

local function StopSpectate()
    spectatingTarget = nil
    if streamConn then streamConn:Disconnect(); streamConn=nil end
    if lifeConn then lifeConn:Disconnect(); lifeConn=nil end
    if originalSubject then
        Camera.CameraSubject = originalSubject
        originalSubject = nil
    end
    if originalType then
        Camera.CameraType = originalType
        originalType = nil
    end
end

local function StartSpectate(plr)
    if not plr or plr == LocalPlayer then return end
    local hum = HumanoidOf(plr)
    local hrp = HRPOf(plr)

    -- Tunggu stream-in awal bila perlu
    local t0 = tick()
    while not (hum and hrp) and tick()-t0 < STREAM_TIMEOUT do
        hum = HumanoidOf(plr); hrp = HRPOf(plr)
        RequestAround((hrp and hrp.Position) or (plr.Character and plr.Character:GetPivot().Position) or Vector3.new())
        task.wait(0.1)
    end
    if not (hum and hrp) then return end

    -- Simpan state kamera
    originalSubject = originalSubject or Camera.CameraSubject
    originalType    = originalType or Camera.CameraType

    -- Spectate: kamera nempel ke humanoid target
    Camera.CameraType   = Enum.CameraType.Custom
    Camera.CameraSubject= hum

    -- Prefetch lingkungan (orbit beberapa titik di sekitar target)
    PrefetchAround(hrp.Position, STREAM_RING_RADIUS, STREAM_REQUESTS)

    -- Loop stream-in agresif selama spectate
    if streamConn then streamConn:Disconnect() end
    streamConn = RunService.Heartbeat:Connect(function()
        local h = HumanoidOf(plr); local p = HRPOf(plr)
        if not (h and p) then
            -- coba stream-in lagi sebentar; kalau tetap tak ada, stop
            RequestAround(p and p.Position or (plr.Character and plr.Character:GetPivot().Position) or Vector3.new())
            return
        end
        RequestAround(p.Position)
    end)

    -- Hentikan otomatis jika target keluar/respawn lama
    if lifeConn then lifeConn:Disconnect() end
    lifeConn = plr.CharacterAdded:Connect(function()
        task.wait(0.3)
        StartSpectate(plr) -- reattach ke karakter baru
    end)

    spectatingTarget = plr
end

-------------------- UI: LIST PEMAIN --------------------
local function PassFilter(plr, txt)
    if txt == "" then return true end
    txt = string.lower(txt)
    return string.find(string.lower(plr.Name), txt, 1, true)
        or string.find(string.lower(plr.DisplayName), txt, 1, true)
end

local function MakeRow(parent, plr)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,28)
    row.BackgroundColor3 = Color3.fromRGB(25,25,25)
    row.BorderSizePixel = 0
    row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,8)

    local name = Instance.new("TextLabel")
    name.BackgroundTransparency = 1
    name.Position = UDim2.new(0,8,0,0)
    name.Size = UDim2.new(1,-92,1,0)
    name.Font = Enum.Font.GothamBold
    name.TextScaled = true
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.Text = plr.Name .. " · @" .. plr.DisplayName
    name.TextColor3 = Color3.new(1,1,1)
    name.Parent = row

    local view = Instance.new("TextButton")
    view.Size = UDim2.new(0,42,0,22)
    view.Position = UDim2.new(1,-42-4,0.5,-11)
    view.Text = "View"
    view.Font = Enum.Font.GothamBold
    view.TextScaled = true
    view.TextColor3 = Color3.new(1,1,1)
    view.BackgroundColor3 = Color3.fromRGB(0,110,200)
    view.BorderSizePixel = 0
    view.Parent = row
    Instance.new("UICorner", view).CornerRadius = UDim.new(0,6)

    view.MouseButton1Click:Connect(function()
        StartSpectate(plr)
    end)
end

local function RebuildList()
    for _, ch in ipairs(List:GetChildren()) do
        if ch:IsA("Frame") then ch:Destroy() end
    end
    local q = Search.Text or ""
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and PassFilter(plr, q) then
            MakeRow(List, plr)
        end
    end
    FitCanvas()
end

-- Wiring
Search:GetPropertyChangedSignal("Text"):Connect(RebuildList)
Refresh.MouseButton1Click:Connect(RebuildList)
StopBtn.MouseButton1Click:Connect(StopSpectate)

Players.PlayerAdded:Connect(RebuildList)
Players.PlayerRemoving:Connect(function(removed)
    if spectatingTarget == removed then
        StopSpectate()
    end
    RebuildList()
end)

-- Safety periodic refresh
task.spawn(function()
    while root.Parent do
        task.wait(5)
        RebuildList()
        if spectatingTarget then
            local hrp = HRPOf(spectatingTarget)
            if hrp then
                PrefetchAround(hrp.Position, STREAM_RING_RADIUS, STREAM_REQUESTS)
            end
        end
    end
end)

-- Start
RebuildList()