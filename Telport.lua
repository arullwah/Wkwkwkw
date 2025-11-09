--[[
  GAZE • TELEPORT PRO v2.1 (Long Range + Follow Fix)
  - Perbaiki "following nyangkut": hanya satu target follow pada satu waktu.
  - Tambah tombol "Stop Follow" global.
  - Semua tombol Follow di list auto-update visual saat target berganti/berhenti.
  - Teleport jarak jauh dengan multi-hop + stream-in aman (StreamingEnabled safe).
  - UI 200x220, header kosong + tombol close, search + refresh.
  - Tanpa notify sama sekali.
]]

-------------------- HARD RESET --------------------
local CoreGui = game:GetService("CoreGui")
pcall(function()
    local old = CoreGui:FindFirstChild("GAZE_TeleportPro_v21")
    if old then old:Destroy() end
end)

-------------------- SERVICES ----------------------
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera           = workspace.CurrentCamera
local LocalPlayer      = Players.LocalPlayer

-------------------- GUI ROOT ----------------------
local root = Instance.new("ScreenGui")
root.Name = "GAZE_TeleportPro_v21"
root.ResetOnSpawn = false
root.IgnoreGuiInset = true
root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
root.DisplayOrder = 10000
root.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(200, 220)
Main.Position = UDim2.new(0.5, -100, 0.5, -110)
Main.BackgroundColor3 = Color3.fromRGB(0,0,0)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = root
Instance.new("UICorner", Main).CornerRadius = UDim.new(0,14)

-- Header (kosong + close)
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
Close.BackgroundColor3 = Color3.fromRGB(200,40,40)
Close.BorderSizePixel = 0
Close.Text = "x"
Close.TextScaled = true
Close.Font = Enum.Font.GothamBold
Close.TextColor3 = Color3.new(1,1,1)
Close.Parent = Header
Instance.new("UICorner", Close).CornerRadius = UDim.new(0,6)
Close.MouseButton1Click:Connect(function() root:Destroy() end)

-- Drag (global stabil)
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

-- Search + Refresh
local Search = Instance.new("TextBox")
Search.Size = UDim2.new(1,-56,0,24)
Search.PlaceholderText = "Cari nama..."
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
Refresh.Size = UDim2.new(0,52,0,24)
Refresh.Position = UDim2.new(1,-52,0,0)
Refresh.Text = "Ref"
Refresh.Font = Enum.Font.GothamBold
Refresh.TextScaled = true
Refresh.TextColor3 = Color3.new(1,1,1)
Refresh.BackgroundColor3 = Color3.fromRGB(45,45,45)
Refresh.BorderSizePixel = 0
Refresh.Parent = Content
Instance.new("UICorner", Refresh).CornerRadius = UDim.new(0,8)

-- List
local List = Instance.new("ScrollingFrame")
List.Size = UDim2.new(1,0,1,-(24+6+28+6)) -- sisakan tempat untuk bar kontrol bawah
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

-- Bottom control bar (Stop Follow)
local Bottom = Instance.new("Frame")
Bottom.Size = UDim2.new(1,0,0,28)
Bottom.Position = UDim2.new(0,0,1,-28)
Bottom.BackgroundTransparency = 1
Bottom.Parent = Content

local StopFollowBtn = Instance.new("TextButton")
StopFollowBtn.Size = UDim2.new(1,0,1,0)
StopFollowBtn.Text = "STOP"
StopFollowBtn.Font = Enum.Font.GothamBold
StopFollowBtn.TextScaled = true
StopFollowBtn.TextColor3 = Color3.new(1,1,1)
StopFollowBtn.BackgroundColor3 = Color3.fromRGB(170,60,60)
StopFollowBtn.BorderSizePixel = 0
StopFollowBtn.Parent = Bottom
Instance.new("UICorner", StopFollowBtn).CornerRadius = UDim.new(0,8)

-------------------- TELEPORT ENGINE --------------------
local followConn, followTarget
local HOP_STEP      = 300      -- jarak per hop (studs)
local HOP_THRESHOLD = 800      -- mulai multi-hop jika jarak besar
local STREAM_TIMEOUT= 3        -- detik tunggu stream-in awal

local function HRP(char)
    return char and (char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("Head"))
end

local function Humanoid(char)
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function SafePivot(cf)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = Humanoid(char)
    if hum then hum.Sit = false end
    char:PivotTo(cf)
end

-- Paksa stream sekitar posisi
local function RequestAround(pos)
    if workspace.RequestStreamAroundAsync then
        pcall(function() workspace:RequestStreamAroundAsync(pos) end)
    end
end

-- Spectate-sementara untuk stream-in target (tanpa mengganggu user)
local function StreamInTarget(plr)
    if not plr or not plr.Character then return nil end
    local hum = Humanoid(plr.Character)
    local original = Camera.CameraSubject
    if hum then Camera.CameraSubject = hum end
    local part = nil
    local t0 = tick()
    repeat
        part = HRP(plr.Character)
        if part then break end
        local pos = (plr.Character and plr.Character:GetPivot().Position) or Vector3.new()
        RequestAround(pos)
        task.wait(0.1)
    until tick()-t0 >= STREAM_TIMEOUT
    Camera.CameraSubject = original
    return part
end

local function TeleportToPlayer(plr)
    if not plr or plr == LocalPlayer then return end
    local myChar = LocalPlayer.Character
    if not myChar then return end

    local tChar = plr.Character
    local tPart = HRP(tChar) or StreamInTarget(plr)
    if not tPart then return end

    local myPart = HRP(myChar)
    if not myPart then return end

    local startPos = myPart.Position
    local endPos   = tPart.Position + Vector3.new(0,5,0)
    local vec      = endPos - startPos
    local dist     = vec.Magnitude

    if dist > HOP_THRESHOLD then
        local dir  = vec.Unit
        local hops = math.ceil(dist / HOP_STEP)
        for i=1, hops do
            local stepEnd = startPos + dir * math.min(i*HOP_STEP, dist)
            SafePivot(CFrame.new(stepEnd))
            RequestAround(stepEnd)
            task.wait(0.08)
        end
    else
        SafePivot(CFrame.new(endPos))
    end
end

local function StopFollow()
    if followConn then followConn:Disconnect(); followConn=nil end
    followTarget = nil
end

local function StartFollow(plr)
    -- pastikan hanya satu target aktif
    if followTarget == plr then return end
    if followConn then followConn:Disconnect(); followConn=nil end
    followTarget = plr
    followConn = RunService.Heartbeat:Connect(function()
        if not followTarget then return end
        local c = followTarget.Character
        local t = HRP(c)
        if not t then
            t = StreamInTarget(followTarget)
            if not t then return end
        end
        -- ikuti di belakang 2 studs
        local behind = t.CFrame * CFrame.new(0,0,-2)
        SafePivot(behind)
        RequestAround(t.Position)
    end)
end

-------------------- LIST & BUTTON STATE --------------------
-- Simpan referensi tombol follow per pemain untuk sinkronisasi visual
local followButtons = {}  -- [player] = button

local function IsFollowing(plr) return followTarget == plr end

local function UpdateFollowVisuals()
    -- update semua tombol follow sesuai followTarget saat ini
    for plr, btn in pairs(followButtons) do
        if btn and btn.Parent then
            local following = IsFollowing(plr)
            btn.BackgroundColor3 = following and Color3.fromRGB(0,140,60) or Color3.fromRGB(60,60,60)
            btn.Text = following and "Following" or "Follow"
        end
    end
end

local function PassFilter(plr, txt)
    if txt=="" then return true end
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
    name.Size = UDim2.new(1,-118,1,0)
    name.Font = Enum.Font.GothamBold
    name.TextScaled = true
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.Text = plr.Name .. " · @" .. plr.DisplayName
    name.TextColor3 = Color3.new(1,1,1)
    name.Parent = row

    local tp = Instance.new("TextButton")
    tp.Size = UDim2.new(0,38,0,22)
    tp.Position = UDim2.new(1, -(38*2 + 8), 0.5, -11)
    tp.BackgroundColor3 = Color3.fromRGB(0,110,200)
    tp.BorderSizePixel = 0
    tp.Text = "TP"
    tp.TextScaled = true
    tp.Font = Enum.Font.GothamBold
    tp.TextColor3 = Color3.new(1,1,1)
    tp.Parent = row
    Instance.new("UICorner", tp).CornerRadius = UDim.new(0,6)

    local follow = Instance.new("TextButton")
    follow.Size = UDim2.new(0,60,0,22)
    follow.Position = UDim2.new(1, -60 - 4, 0.5, -11)
    follow.BackgroundColor3 = Color3.fromRGB(60,60,60)
    follow.BorderSizePixel = 0
    follow.Text = "Follow"
    follow.TextScaled = true
    follow.Font = Enum.Font.GothamBold
    follow.TextColor3 = Color3.new(1,1,1)
    follow.Parent = row
    Instance.new("UICorner", follow).CornerRadius = UDim.new(0,6)

    -- simpan button untuk sync global
    followButtons[plr] = follow

    -- actions
    tp.MouseButton1Click:Connect(function()
        TeleportToPlayer(plr)
    end)

    follow.MouseButton1Click:Connect(function()
        if IsFollowing(plr) then
            StopFollow()
        else
            StartFollow(plr)
        end
        UpdateFollowVisuals()
    end)

    -- set visual awal
    local following = IsFollowing(plr)
    follow.BackgroundColor3 = following and Color3.fromRGB(0,140,60) or Color3.fromRGB(60,60,60)
    follow.Text = following and "Following" or "Follow"

    -- bersihkan referensi saat row hilang
    row.AncestryChanged:Connect(function(_, parentNow)
        if not parentNow then
            if followButtons[plr] == follow then
                followButtons[plr] = nil
            end
        end
    end)
end

local function RebuildList()
    -- hapus semua row & referensi lama
    for _, ch in ipairs(List:GetChildren()) do
        if ch:IsA("Frame") then ch:Destroy() end
    end
    followButtons = {}

    local q = Search.Text or ""
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and PassFilter(plr, q) then
            MakeRow(List, plr)
        end
    end
    FitCanvas()
    UpdateFollowVisuals()
end

-------------------- WIRING --------------------
Search:GetPropertyChangedSignal("Text"):Connect(RebuildList)
Refresh.MouseButton1Click:Connect(RebuildList)
StopFollowBtn.MouseButton1Click:Connect(function()
    StopFollow()
    UpdateFollowVisuals()
end)

Players.PlayerAdded:Connect(RebuildList)
Players.PlayerRemoving:Connect(function(removed)
    if followTarget == removed then
        StopFollow()
    end
    RebuildList()
end)

-- Safety periodic refresh & keep streaming when following
task.spawn(function()
    while root.Parent do
        task.wait(5)
        RebuildList()
        if followTarget and followTarget.Character then
            local t = HRP(followTarget.Character)
            if t then RequestAround(t.Position) end
        end
    end
end)

-- Respawn safety
LocalPlayer.CharacterAdded:Connect(function()
    -- Biarkan follow berjalan; loop Heartbeat akan lanjut ketika char ada
    task.wait(0.5)
    UpdateFollowVisuals()
end)

-- Start
RebuildList()