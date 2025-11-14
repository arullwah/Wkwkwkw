--[[
  GAZE • EMOTE GUI v3.1 - EXTERNAL-FIRST EDIT (Final: index-based counter + click sound vol=1)
  - Click sound (rbxassetid://2865227271) plays once per Play/Save click (volume = 1)
  - Middle pagination label shows "< Prev   X / TOTAL   emote tersedia   Next >"
    where X = index of last emote currently displayed (based on external list + current page)
  - Next/Prev for Emote tab navigates pages normally and updates X accordingly
  - Saved tab pagination remains independent / unchanged
  - RGB stroke for main GUI and mini-button
  By: adapted for Arull (final)
]]

-------------------- HARD RESET --------------------
local CoreGui = game:GetService("CoreGui")
pcall(function() if CoreGui:FindFirstChild("GAZE_EmotePanel") then CoreGui.GAZE_EmotePanel:Destroy() end end)
pcall(function() if CoreGui:FindFirstChild("GAZE_Toggle") then CoreGui.GAZE_Toggle:Destroy() end end)

-------------------- SERVICES ----------------------
local Players  = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local AvatarEditorService = game:GetService("AvatarEditorService")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local animator  = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)

player.CharacterAdded:Connect(function(c)
    if _G.__GAZE_StopCurrent then pcall(_G.__GAZE_StopCurrent) end
    character = c
    humanoid  = c:WaitForChild("Humanoid", 5)
    if humanoid then
        animator  = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
    end
end)

-------------------- UTILS -------------------------
local function glossy(frame, r)
    local u = frame:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
    u.CornerRadius = UDim.new(0, r or 10); u.Parent = frame

    local g = frame:FindFirstChild("Gloss") or Instance.new("Frame")
    g.Name="Gloss"; g.Parent=frame
    g.BackgroundTransparency = 0
    g.BackgroundColor3 = Color3.new(1,1,1)
    g.BorderSizePixel = 0
    g.ZIndex = (frame.ZIndex or 1) + 1
    g.Size = UDim2.new(1,0,0, math.max(6, math.floor((frame.AbsoluteSize.Y/300)*18)))

    local grad = g:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
    grad.Parent = g
    grad.Rotation=90
    grad.Color = ColorSequence.new(Color3.new(1,1,1), Color3.new(0,0,0))
    grad.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0,0.82),
        NumberSequenceKeypoint.new(1,1)
    }
end

local AnimCache = {}
local function GetReal(id)
    if not id then return nil end
    if AnimCache[id] then return AnimCache[id] end
    local ok, objs = pcall(function() return game:GetObjects("rbxassetid://"..tostring(id)) end)
    if ok and objs and #objs>0 then
        local found
        for _,root in ipairs(objs) do
            if root:IsA("Animation") and root.AnimationId ~= "" then
                found = tonumber(root.AnimationId:match("%d+")) or found
            else
                for _,d in ipairs(root:GetDescendants()) do
                    if d:IsA("Animation") and d.AnimationId ~= "" then
                        found = tonumber(d.AnimationId:match("%d+")) or found
                        if found then break end
                    end
                end
            end
            pcall(function() root:Destroy() end)
            if found then break end
        end
        AnimCache[id] = found or id
        return AnimCache[id]
    end
    AnimCache[id] = id
    return id
end

local NameCache = {}
local function getNameOfAsset(assetId)
    if NameCache[assetId] then return NameCache[assetId] end
    local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, tonumber(assetId))
    local nm = (ok and info and info.Name) and info.Name or ("Item "..tostring(assetId))
    NameCache[assetId] = nm
    return nm
end

-------------------- SAVE FILES --------------------
local IO_AVAILABLE = (typeof(readfile)=="function" and typeof(writefile)=="function" and typeof(isfile)=="function")
local SAVED_FILE = "SavedEmotes.json"
local POS_FILE   = "GAZE_TogglePos.json"
local Saved = {}

local function loadSaved()
    if IO_AVAILABLE and isfile(SAVED_FILE) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(SAVED_FILE)) end)
        if ok and type(data)=="table" then Saved = data end
    end
end
local function saveSaved()
    if not IO_AVAILABLE then return end
    pcall(function() writefile(SAVED_FILE, HttpService:JSONEncode(Saved)) end)
end
loadSaved()

-------------------- PLAYBACK ----------------------
local CurrentTrack = nil
local StopOnMove = true

local function stopCurrent()
    if CurrentTrack then
        pcall(function()
            CurrentTrack:Stop(0.1)
            CurrentTrack:Destroy()
        end)
        CurrentTrack=nil
    end
end
_G.__GAZE_StopCurrent = stopCurrent

local function playEmoteByAssetId(assetId)
    stopCurrent()
    local real = GetReal(assetId)
    if not real then return end
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://"..tostring(real)
    local ok, tr = pcall(function() return animator:LoadAnimation(anim) end)
    if ok and tr then
        tr.Priority = Enum.AnimationPriority.Action
        tr.Looped = true
        tr:Play(0.1, 1, 1)
        tr:AdjustSpeed(1)
        CurrentTrack = tr
    end
end

local lastCheck = 0
local GRACE = 0.15
local INPUT_EPS = 0.05
RunService.RenderStepped:Connect(function(dt)
    if not StopOnMove then return end
    if not (character and humanoid and CurrentTrack and CurrentTrack.IsPlaying) then return end
    lastCheck += dt
    if lastCheck < GRACE then return end
    lastCheck = 0
    local md = humanoid.MoveDirection
    local movingByInput = (md and md.Magnitude or 0) > INPUT_EPS
    local st = humanoid:GetState()
    local jumped = (st == Enum.HumanoidStateType.Jumping) or (st == Enum.HumanoidStateType.Freefall)
    if movingByInput or jumped then
        stopCurrent()
    end
end)

-------------------- RGB STROKE CONFIG --------------------
local RGB_STROKE_ENABLED = true
local RGB_STROKE_THICKNESS = 2
local RGB_CYCLE_SPEED = 3.0  -- hue revolutions per second

-------------------- EXTERNAL EMOTE CONFIG (AUTO-ON) --------------------
local EXTERNAL_URL = "https://raw.githubusercontent.com/7yd7/sniper-Emote/refs/heads/test/EmoteSniper.json"
local emoteCatalog = {}
local externalTotal = 0
local externalPage = 1

-- load external list (async, immediate at start)
local function loadExternalList()
    task.spawn(function()
        local ok, body = pcall(function() return game:HttpGet(EXTERNAL_URL) end)
        if not ok or not body or body == "" then
            warn("Failed to fetch external emote list")
            emoteCatalog = {}
            externalTotal = 0
            return
        end
        local suc, dec = pcall(function() return HttpService:JSONDecode(body) end)
        if not suc or not dec or type(dec.data) ~= "table" then
            warn("External emote list parse failed")
            emoteCatalog = {}
            externalTotal = 0
            return
        end
        emoteCatalog = {}
        for _, item in ipairs(dec.data) do
            local id = tonumber(item.id)
            if id and id > 0 then
                table.insert(emoteCatalog, { id = id, name = item.name or ("Emote_"..tostring(id)) })
            end
        end
        externalTotal = #emoteCatalog
        externalPage = 1
        -- safe to render (GUI created earlier)
        pcall(function() renderEmotePage() end)
    end)
end

-------------------- CLICK SOUND --------------------
local CLICK_SOUND_ID = "rbxassetid://2865227271"
local CLICK_VOLUME = 1 -- requested final volume

local function playClickSound()
    pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = CLICK_SOUND_ID
        s.Volume = CLICK_VOLUME
        s.PlayOnRemove = false
        local pg = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui")
        s.Parent = pg
        s:Play()
        s.Ended:Connect(function()
            pcall(function() s:Destroy() end)
        end)
        task.delay(6, function() if s and s.Parent then pcall(function() s:Destroy() end) end end)
    end)
end

-------------------- GUI ROOT ----------------------
local root = Instance.new("ScreenGui")
root.Name = "GAZE_EmotePanel"; root.IgnoreGuiInset = true; root.ResetOnSpawn = false; root.Parent = CoreGui
root.DisplayOrder = 10000
root.Enabled = true  -- open by default

local camera = workspace.CurrentCamera
local vp = camera and camera.ViewportSize or Vector2.new(1920,1080)
local minSide = math.min(vp.X, vp.Y)
local scaleFactor = math.clamp(minSide/1080, 0.75, 1.35)

local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(math.floor(300*scaleFactor), math.floor(300*scaleFactor))
Main.Position = UDim2.new(0.5, -Main.Size.X.Offset/2, 0.5, -Main.Size.Y.Offset/2)
Main.BackgroundColor3 = Color3.fromRGB(0,0,0)
Main.Active = true
Main.Draggable = true
Main.Parent = root
glossy(Main, 14)

-- RGB stroke (attach to Main)
local rgbStrokeConn = nil
local rgbStroke = nil
local rgbStart = tick()
if RGB_STROKE_ENABLED then
    rgbStroke = Instance.new("UIStroke")
    rgbStroke.Name = "RGBStroke"
    rgbStroke.Thickness = RGB_STROKE_THICKNESS
    rgbStroke.LineJoinMode = Enum.LineJoinMode.Round
    rgbStroke.Parent = Main
end

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1,0,0, math.floor(30*scaleFactor))
Header.BackgroundColor3 = Color3.fromRGB(10,10,10)
Header.Parent = Main
glossy(Header, 12)

local btnClose = Instance.new("TextButton")
btnClose.AnchorPoint = Vector2.new(1,0); btnClose.Position = UDim2.new(1,-6,0,6)
btnClose.Size = UDim2.fromOffset(math.floor(20*scaleFactor), math.floor(20*scaleFactor))
btnClose.Text = "x"; btnClose.TextScaled = true; btnClose.Font = Enum.Font.GothamBold
btnClose.TextColor3 = Color3.new(1,1,1); btnClose.BackgroundColor3 = Color3.fromRGB(220,40,40)
btnClose.Parent = Header; glossy(btnClose, 8)
btnClose.MouseButton1Click:Connect(function()
    root:Destroy()
    local tg = CoreGui:FindFirstChild("GAZE_Toggle"); if tg then tg:Destroy() end
end)

local row = Instance.new("Frame")
row.Size = UDim2.new(1,-12,0, math.floor(24*scaleFactor))
row.Position = UDim2.new(0,6,0, math.floor(3*scaleFactor))
row.BackgroundTransparency = 1; row.Parent = Header

local somBtn  -- StopMove toggle
do
    local function mkToggle(txt, state, xoff)
        local holder = Instance.new("Frame")
        holder.Size = UDim2.new(0, math.floor(120*scaleFactor), 1, 0)
        holder.Position = UDim2.new(0, xoff, 0, 0)
        holder.BackgroundTransparency = 1
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1,-(math.floor(36*scaleFactor)+6),1,0)
        label.BackgroundTransparency = 1; label.TextColor3 = Color3.new(1,1,1)
        label.TextScaled = true; label.Font = Enum.Font.Gotham; label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = txt; label.Parent = holder
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, math.floor(36*scaleFactor), 1, 0)
        btn.Position = UDim2.new(1, -math.floor(36*scaleFactor), 0, 0)
        btn.BackgroundColor3 = state and Color3.fromRGB(0,160,0) or Color3.fromRGB(70,70,70)
        btn.Text = state and "ON" or "OFF"
        btn.TextScaled = true; btn.Font = Enum.Font.GothamBold; btn.TextColor3 = Color3.new(1,1,1)
        btn.Parent = holder; glossy(btn, 8)
        holder.Parent = row
        return btn
    end
    somBtn = mkToggle("StopMove", true, 0)
    somBtn.MouseButton1Click:Connect(function()
        StopOnMove = not StopOnMove
        somBtn.BackgroundColor3 = StopOnMove and Color3.fromRGB(0,160,0) or Color3.fromRGB(70,70,70)
        somBtn.Text = StopOnMove and "ON" or "OFF"
    end)
end

local TabsBar = Instance.new("Frame")
TabsBar.Size = UDim2.new(1,-8,0, math.floor(26*scaleFactor))
TabsBar.Position = UDim2.new(0,4,0, math.floor(32*scaleFactor))
TabsBar.BackgroundTransparency = 1
TabsBar.Parent = Main

local function mkTab(text, xScale, xOff)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1/2, -2, 1, 0)
    b.Position = UDim2.new(xScale, xOff, 0, 0)
    b.BackgroundColor3 = Color3.fromRGB(25,25,25)
    b.Text = text; b.TextScaled = true; b.Font = Enum.Font.GothamBold; b.TextColor3 = Color3.new(1,1,1)
    glossy(b, 8); b.Parent = TabsBar
    return b
end
local tabEmote = mkTab("Emote", 0, 0)
local tabSaved = mkTab("Saved", 1/2, 2)

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1,-8,1,-(math.floor(32*scaleFactor)+math.floor(26*scaleFactor)+math.floor(14*scaleFactor)+math.floor(26*scaleFactor)))
Content.Position = UDim2.new(0,4,0, math.floor(32*scaleFactor)+math.floor(26*scaleFactor)+math.floor(6*scaleFactor))
Content.BackgroundTransparency = 1
Content.Parent = Main

local BottomBar = Instance.new("Frame")
BottomBar.Size = UDim2.new(1,-8,0, math.floor(26*scaleFactor))
BottomBar.Position = UDim2.new(0,4,1,-math.floor(30*scaleFactor))
BottomBar.BackgroundTransparency = 1
BottomBar.Parent = Main

-- Pagination controls: Prev | middle label (page / total) | Next
local btnPrev = Instance.new("TextButton", BottomBar)
btnPrev.Size = UDim2.new(0.28,0,1,0)
btnPrev.Position = UDim2.new(0,0,0,0)
btnPrev.BackgroundColor3 = Color3.fromRGB(35,35,35)
btnPrev.Text="< Prev"; btnPrev.TextScaled=true; btnPrev.Font=Enum.Font.Gotham; btnPrev.TextColor3=Color3.new(1,1,1); glossy(btnPrev,8)

local pageLabel = Instance.new("TextLabel", BottomBar)
pageLabel.Size = UDim2.new(0.44,0,1,0)
pageLabel.Position = UDim2.new(0.28,0,0,0)
pageLabel.BackgroundColor3 = Color3.fromRGB(30,30,30)
pageLabel.TextScaled = true
pageLabel.Font = Enum.Font.GothamBold
pageLabel.TextColor3 = Color3.new(1,1,1)
pageLabel.Text = "" -- will be set when Emote tab active
pageLabel.BorderSizePixel = 0
glossy(pageLabel, 8)

local btnNext = Instance.new("TextButton", BottomBar)
btnNext.Size = UDim2.new(0.28,0,1,0)
btnNext.Position = UDim2.new(0.72,0,0,0)
btnNext.BackgroundColor3 = Color3.fromRGB(35,35,35)
btnNext.Text="Next >"; btnNext.TextScaled=true; btnNext.Font=Enum.Font.Gotham; btnNext.TextColor3=Color3.new(1,1,1); glossy(btnNext,8)

local function mkPane()
    local pane = Instance.new("Frame"); pane.Size = UDim2.new(1,0,1,0); pane.BackgroundTransparency = 1
    local grid = Instance.new("ScrollingFrame"); grid.Parent = pane; grid.Size = UDim2.new(1,0,1,0)
    grid.BackgroundTransparency = 1; grid.ScrollBarThickness = math.max(4, math.floor(4*scaleFactor)); grid.CanvasSize = UDim2.new(0,0,0,0)
    local lay = Instance.new("UIGridLayout", grid)
    lay.CellSize = UDim2.fromOffset(math.floor(90*scaleFactor), math.floor(120*scaleFactor))
    lay.CellPadding = UDim2.fromOffset(math.floor(5*scaleFactor), math.floor(5*scaleFactor))
    lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
    lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        grid.CanvasSize = UDim2.new(0,0,0, lay.AbsoluteContentSize.Y + math.floor(6*scaleFactor))
    end)
    return pane, grid
end

local MAX_VISIBLE = 6
local paneEmote, gridEmote = mkPane(); paneEmote.Parent = Content
local paneSaved, gridSaved = mkPane(); paneSaved.Parent=Content; paneSaved.Visible=false

-- makeCard: plays click sound on Play and Save actions
local function makeCard(id, nameText, onPlay, onSaveOrRemove, mode)
    local card = Instance.new("Frame")
    card.Size = UDim2.fromOffset(math.floor(90*scaleFactor), math.floor(120*scaleFactor))
    card.BackgroundColor3 = Color3.fromRGB(20,20,20); glossy(card,8)
    
    local img = Instance.new("ImageLabel"); img.Parent=card; img.BackgroundTransparency=1
    img.Size = UDim2.new(1,-math.floor(6*scaleFactor),0,math.floor(60*scaleFactor))
    img.Position = UDim2.new(0, math.floor(3*scaleFactor), 0, math.floor(3*scaleFactor))
    pcall(function()
        img.Image = "rbxthumb://type=Asset&id="..tostring(id).."&w=150&h=150"
    end)
    
    local name = Instance.new("TextLabel"); name.Parent=card; name.BackgroundTransparency=1
    name.Size = UDim2.new(1,-math.floor(6*scaleFactor),0,math.floor(28*scaleFactor))
    name.Position = UDim2.new(0, math.floor(3*scaleFactor), 0, math.floor(66*scaleFactor))
    name.Font = Enum.Font.Gotham; name.TextScaled=true; name.TextWrapped=true; name.TextColor3=Color3.new(1,1,1)
    name.Text = nameText or "Unknown"
    
    local play = Instance.new("TextButton"); play.Parent=card
    play.Size = UDim2.new(0.45,-math.floor(2*scaleFactor),0,math.floor(18*scaleFactor))
    play.Position = UDim2.new(0, math.floor(3*scaleFactor), 1, -math.floor(21*scaleFactor))
    play.BackgroundColor3 = Color3.fromRGB(0,150,0); play.Text="Play"; play.TextScaled=true; play.Font=Enum.Font.Gotham; play.TextColor3=Color3.new(1,1,1); glossy(play,6)
    
    local save = Instance.new("TextButton"); save.Parent=card
    save.Size = UDim2.new(0.45,-math.floor(2*scaleFactor),0,math.floor(18*scaleFactor))
    save.Position = UDim2.new(0.55,0,1,-math.floor(21*scaleFactor))
    save.BackgroundColor3 = (mode=="remove") and Color3.fromRGB(170,50,50) or Color3.fromRGB(0,90,170)
    save.Text = (mode=="remove") and "Remove" or "Save"
    save.TextScaled=true; save.Font=Enum.Font.Gotham; save.TextColor3=Color3.new(1,1,1); glossy(save,6)
    
    play.MouseButton1Click:Connect(function()
        pcall(onPlay, id)
        pcall(playClickSound) -- play once per click
    end)
    save.MouseButton1Click:Connect(function()
        pcall(onSaveOrRemove, id, save)
        pcall(playClickSound) -- play once per click
    end)
    
    return card
end

--------------------------------------------------------------
-- CATALOG TAB (external-first)
--------------------------------------------------------------
local function updatePageLabel()
    if activeTab ~= "emote" then
        pageLabel.Text = "" -- hide when not Emote tab
        return
    end
    local total = externalTotal or 0
    if total == 0 then
        pageLabel.Text = "< Prev   0 / 0  emote tersedia   Next >"
        return
    end
    local finish = math.min(externalPage * MAX_VISIBLE, total)
    pageLabel.Text = string.format("< Prev   %d / %d  emote tersedia   Next >", finish, total)
end

function renderEmotePage()
    for _,c in ipairs(gridEmote:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end

    if externalTotal == 0 then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,0,0, math.floor(22*scaleFactor))
        lbl.Position = UDim2.new(0,0,0.5,-math.floor(11*scaleFactor))
        lbl.BackgroundTransparency = 1
        lbl.Text = "Loading external emotes..."
        lbl.Font = Enum.Font.GothamBold
        lbl.TextScaled = true
        lbl.TextColor3 = Color3.new(1,1,1)
        lbl.Parent = gridEmote
        updatePageLabel()
        return
    end

    local total = externalTotal
    local per = MAX_VISIBLE
    local pages = math.max(1, math.ceil(total / per))
    externalPage = math.clamp(externalPage, 1, pages)

    local startIdx = (externalPage-1)*per + 1
    local finish = math.min(externalPage*per, total)

    for i=startIdx, finish do
        local it = emoteCatalog[i]
        if it then
            local card = makeCard(it.id, it.name or getNameOfAsset(it.id),
                function(id) playEmoteByAssetId(id) end,
                function(id, btn)
                    local animIdStr = "rbxassetid://"..tostring(GetReal(id))
                    for _,s in ipairs(Saved) do
                        if s.id==id then
                            btn.Text="Already"; task.delay(0.5,function() if btn then btn.Text="Save" end end)
                            return
                        end
                    end
                    table.insert(Saved, {id=id, name=(it.name or getNameOfAsset(id)), AnimationId=animIdStr})
                    saveSaved()
                    btn.Text="Saved!"; btn.BackgroundColor3 = Color3.fromRGB(0,170,90)
                    task.delay(0.4,function() if btn then btn.Text="Save"; btn.BackgroundColor3=Color3.fromRGB(0,90,170) end end)
                end,
                "save"
            )
            card.Parent = gridEmote
        end
    end

    -- update label (finish index / total)
    updatePageLabel()
end

--------------------------------------------------------------
-- SAVED TAB
--------------------------------------------------------------
local svPage = 1

local function renderSavedPage()
    for _,c in ipairs(gridSaved:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    local total = #Saved
    if total==0 then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,0,0, math.floor(22*scaleFactor))
        lbl.Position = UDim2.new(0,0,0.5,-math.floor(11*scaleFactor))
        lbl.BackgroundTransparency = 1
        lbl.Text = "No saved emotes"
        lbl.Font = Enum.Font.GothamBold
        lbl.TextScaled = true
        lbl.TextColor3 = Color3.new(1,1,1)
        lbl.Parent = gridSaved
        return
    end
    local start = (svPage-1)*MAX_VISIBLE + 1
    local finish = math.min(svPage*MAX_VISIBLE, total)
    for i=start, finish do
        local it = Saved[i]
        local playFn = function()
            if it.AnimationId then
                stopCurrent()
                local anim = Instance.new("Animation"); anim.AnimationId = it.AnimationId
                local ok, tr = pcall(function() return animator:LoadAnimation(anim) end)
                if ok and tr then 
                    tr.Priority=Enum.AnimationPriority.Action
                    tr.Looped=true
                    tr:Play(0.1,1,1)
                    tr:AdjustSpeed(1)
                    CurrentTrack=tr
                end
            else
                playEmoteByAssetId(it.id)
            end
        end
        local card = makeCard(it.id, it.name or getNameOfAsset(it.id),
            function() playFn() end,
            function(_, btn)
                table.remove(Saved, i)
                saveSaved()
                if (svPage-1)*MAX_VISIBLE >= #Saved and svPage>1 then 
                    svPage -= 1
                end
                renderSavedPage()
            end,
            "remove"
        )
        card.Parent = gridSaved
    end
end

-------------------- TAB SWITCH --------------------
local activeTab = "emote"

local function setTab(which)
    activeTab = which
    paneEmote.Visible = (which=="emote")
    paneSaved.Visible = (which=="saved")
    tabEmote.BackgroundColor3 = (which=="emote") and Color3.fromRGB(35,35,35) or Color3.fromRGB(25,25,25)
    tabSaved.BackgroundColor3 = (which=="saved") and Color3.fromRGB(35,35,35) or Color3.fromRGB(25,25,25)
    
    stopCurrent()
    
    if which=="emote" then
        renderEmotePage()
    else
        renderSavedPage()
    end

    updatePageLabel()
end

tabEmote.MouseButton1Click:Connect(function() setTab("emote") end)
tabSaved.MouseButton1Click:Connect(function() setTab("saved") end)

-------------------- PAGINATION BEHAVIOR (SEPARATE FOR EMOTE / SAVED) --------------------
btnNext.MouseButton1Click:Connect(function()
    if activeTab == "saved" then
        -- saved pagination
        local total = #Saved
        if total == 0 then return end
        local maxPage = math.max(1, math.ceil(total / MAX_VISIBLE))
        if svPage < maxPage then
            svPage = svPage + 1
        else
            svPage = 1
        end
        renderSavedPage()
        return
    end

    -- activeTab == "emote" (external-first)
    if externalTotal > 0 then
        local total = externalTotal
        local per = MAX_VISIBLE
        local pages = math.max(1, math.ceil(total / per))
        if externalPage < pages then
            externalPage = externalPage + 1
        else
            externalPage = 1
        end
        renderEmotePage()
        return
    end

    -- fallback behavior (if external not loaded) - try AvatarEditorService pages (kept for safety)
    if not currentPages then return end
    if currentPages.IsFinished then return end
    
    local ok = pcall(function()
        currentPages:AdvanceToNextPageAsync()
    end)
    
    if ok then
        currentPageNumber = currentPageNumber + 1
        renderEmotePage()
    else
        local targetPage = currentPageNumber + 1
        local fresh = fetchPagesTo(targetPage)
        if fresh then
            currentPages = fresh
            currentPageNumber = math.min(targetPage, currentPageNumber + 1)
            renderEmotePage()
        end
    end
end)

btnPrev.MouseButton1Click:Connect(function()
    if activeTab == "saved" then
        -- saved pagination
        local total = #Saved
        if total == 0 then return end
        local maxPage = math.max(1, math.ceil(total / MAX_VISIBLE))
        if svPage > 1 then
            svPage = svPage - 1
        else
            svPage = maxPage
        end
        renderSavedPage()
        return
    end

    -- activeTab == "emote"
    if externalTotal > 0 then
        local total = externalTotal
        local per = MAX_VISIBLE
        local pages = math.max(1, math.ceil(total / per))
        if externalPage > 1 then
            externalPage = externalPage - 1
        else
            externalPage = pages
        end
        renderEmotePage()
        return
    end

    if not currentPages then return end
    if currentPageNumber <= 1 then return end
    
    local ok = pcall(function()
        currentPages:AdvanceToPreviousPageAsync()
    end)
    
    if ok then
        currentPageNumber = math.max(1, currentPageNumber - 1)
        renderEmotePage()
    else
        local targetPage = math.max(1, currentPageNumber - 1)
        local fresh = fetchPagesTo(targetPage)
        if fresh then
            currentPages = fresh
            currentPageNumber = targetPage
            renderEmotePage()
        end
    end
end)

-------------------- MINI BUTTON (toggle & RGB stroke) --------------------
local toggleGui = Instance.new("ScreenGui")
toggleGui.Name = "GAZE_Toggle"
toggleGui.ResetOnSpawn = false
toggleGui.Parent = CoreGui
toggleGui.DisplayOrder = 10001

local tBtn = Instance.new("TextButton")
tBtn.Parent = toggleGui
tBtn.Text = "A"
tBtn.Font = Enum.Font.GothamBold
tBtn.TextScaled = true
tBtn.Size = UDim2.new(0, 50, 0, 50)
tBtn.Position = UDim2.new(0, 20, 0.5, -25)
tBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
tBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
tBtn.Active = true
tBtn.BorderSizePixel = 0
glossy(tBtn, 12)

-- mini stroke
local miniStroke = Instance.new("UIStroke")
miniStroke.Name = "MiniStroke"
miniStroke.Thickness = RGB_STROKE_THICKNESS
miniStroke.LineJoinMode = Enum.LineJoinMode.Round
miniStroke.Parent = tBtn

-- dragging
local dragging = false
local dragStart = nil
local startPos = nil

tBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or 
       input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = tBtn.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or 
                     input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        tBtn.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

tBtn.MouseButton1Click:Connect(function()
    root.Enabled = not root.Enabled
end)

local function saveBtnPos()
    if not IO_AVAILABLE then return end
    local x = tBtn.AbsolutePosition.X
    local y = tBtn.AbsolutePosition.Y
    local payload = {x=x, y=y}
    pcall(function() 
        writefile(POS_FILE, HttpService:JSONEncode(payload)) 
    end)
end

pcall(function()
    if IO_AVAILABLE and isfile(POS_FILE) then
        local data = HttpService:JSONDecode(readfile(POS_FILE))
        if typeof(data)=="table" and data.x and data.y then
            tBtn.Position = UDim2.fromOffset(data.x, data.y)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or 
                     input.UserInputType == Enum.UserInputType.Touch) then
        dragging = false
        saveBtnPos()
    end
end)

-- RGB stroke animation (both main and mini)
local rgbConnAll = nil
if RGB_STROKE_ENABLED then
    rgbStart = tick()
    rgbConnAll = RunService.RenderStepped:Connect(function()
        local hue = ((tick() - rgbStart) * RGB_CYCLE_SPEED) % 1
        pcall(function()
            if rgbStroke then rgbStroke.Color = Color3.fromHSV(hue, 1, 1) end
            if miniStroke then miniStroke.Color = Color3.fromHSV((hue+0.08)%1, 1, 1) end
        end)
    end)
    root.Destroying:Connect(function()
        if rgbConnAll then
            rgbConnAll:Disconnect()
            rgbConnAll = nil
        end
    end)
end

-------------------- INITIAL LOAD -------------------
-- load external immediately
loadExternalList()

-- try to also prepare AvatarEditorService pages for fallback (non-blocking)
local function getPages()
    local ok, pages = pcall(function()
        local params = CatalogSearchParams.new()
        params.SearchKeyword = ""
        params.CategoryFilter = Enum.CatalogCategoryFilter.None
        params.SalesTypeFilter = Enum.SalesTypeFilter.All
        params.AssetTypes = { Enum.AvatarAssetType.EmoteAnimation }
        params.IncludeOffSale = true
        params.SortType = Enum.CatalogSortType.Relevance
        params.Limit = 30
        return AvatarEditorService:SearchCatalog(params)
    end)
    return ok and pages or nil
end

local currentPages = getPages()
-- initial render (if external not yet loaded, renderEmotePage will show loading)
renderEmotePage()

-- Prev/Next label initial state (compute from externalPage if externalTotal present)
updatePageLabel()

tabEmote.MouseButton1Click:Connect(function() setTab("emote") end)
tabSaved.MouseButton1Click:Connect(function() setTab("saved") end)

-- ensure Saved tab can render saved when toggled
tabSaved.MouseButton1Click:Connect(function()
    renderSavedPage()
end)

-- Glossy resize with debounce
local resizeDebounce = false
Main:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    if resizeDebounce then return end
    resizeDebounce = true
    task.wait(0.1)
    local g=Main:FindFirstChild("Gloss")
    if g then g:Destroy() end
    glossy(Main,14)
    resizeDebounce = false
end)

Header:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    if resizeDebounce then return end
    resizeDebounce = true
    task.wait(0.1)
    local g=Header:FindFirstChild("Gloss")
    if g then g:Destroy() end
    glossy(Header,12)
    resizeDebounce = false
end)