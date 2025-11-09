--[[
  GAZE • REALISTIC MOTION & CAMERA FX (SUPER COMPACT) — 200x200
  - Perampingan baris: prioritas tombol (-/+) SELALU tampil.
  - Badge angka dipersempit (32px), toggle mini (34x18), tombol +/- (18x18).
  - Tidak ada overlap/ketutupan; ClipsDescendants dimatikan.
  - Header kosong + close, drag stabil. Tanpa notify.
]]

-------------------- HARD RESET --------------------
local CoreGui = game:GetService("CoreGui")
pcall(function() local o=CoreGui:FindFirstChild("GAZE_CameraFX_SC") if o then o:Destroy() end end)

-------------------- SERVICES ----------------------
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")

local LP=Players.LocalPlayer
local Cam=workspace.CurrentCamera

-------------------- STATE -------------------------
local BASE_FOV=Cam.FieldOfView
local FX_ON=true
local cfg={
    tilt={on=true, amt=4.0},
    bob ={on=true, amt=0.12, freq=8.0},
    zoom={on=true, amt=10.0, speed=6.0},
}
local range={tilt={0,10}, bob={0,0.5}, zoom={0,25}, smooth={1,20}}
local rt=0
local bindName="GAZE_CamFX_SC_Bind"

local function hum() local c=LP.Character return c and c:FindFirstChildOfClass("Humanoid") end
local function hrp() local c=LP.Character return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")) end
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
local function lerp(a,b,t) return a+(b-a)*t end
local function slerpFOV(target,dt,speed) Cam.FieldOfView = lerp(Cam.FieldOfView,target,1-math.exp(-speed*dt)) end
local function grounded(h) if not h then return false end local s=h:GetState()
    return s==Enum.HumanoidStateType.Running or s==Enum.HumanoidStateType.RunningNoPhysics or s==Enum.HumanoidStateType.Landed or s==Enum.HumanoidStateType.Climbing
end
local function planarSpeed(p) if not p then return 0 end local v=p.Velocity return Vector3.new(v.X,0,v.Z).Magnitude end

-------------------- LOOP --------------------------
local function step(dt)
    if not FX_ON then return end
    local h=hum(); local p=hrp(); if not (h and p) then return end
    rt+=dt
    local moving = planarSpeed(p) > 0.1
    local md = h.MoveDirection
    local camCF = Cam.CFrame

    -- BOB
    local offs = Vector3.new()
    if cfg.bob.on and moving then
        local w=rt*cfg.bob.freq
        offs+=Vector3.new(math.cos(w*0.5)*(cfg.bob.amt*0.4), math.sin(w)*cfg.bob.amt, 0)
    end

    -- TILT
    local roll=0
    if cfg.tilt.on and moving then
        local side = camCF.RightVector:Dot(md)
        roll = clamp(-side*math.rad(cfg.tilt.amt), -math.rad(cfg.tilt.amt), math.rad(cfg.tilt.amt))
    end

    -- ZOOM
    if cfg.zoom.on then
        local target = BASE_FOV + ((not grounded(h)) and cfg.zoom.amt or 0)
        slerpFOV(target, dt, cfg.zoom.speed)
    end

    Cam.CFrame = camCF * CFrame.new(offs) * CFrame.Angles(0,0,roll)
end
local function bind() pcall(function() RunService:UnbindFromRenderStep(bindName) end); RunService:BindToRenderStep(bindName, Enum.RenderPriority.Camera.Value+1, step) end
local function unbind() pcall(function() RunService:UnbindFromRenderStep(bindName) end) end
local function resetCam() FX_ON=false; unbind(); task.wait(); Cam.FieldOfView=BASE_FOV; FX_ON=true; bind() end

-------------------- GUI ---------------------------
local root=Instance.new("ScreenGui")
root.Name="GAZE_CameraFX_SC"
root.ResetOnSpawn=false
root.IgnoreGuiInset=true
root.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
root.DisplayOrder=10000
root.Parent=CoreGui

local Main=Instance.new("Frame")
Main.Size=UDim2.fromOffset(200,200)
Main.Position=UDim2.new(0.5,-100,0.5,-100)
Main.BackgroundColor3=Color3.fromRGB(0,0,0)
Main.BorderSizePixel=0
Main.Active=true
Main.ClipsDescendants=false
Main.Parent=root
Instance.new("UICorner",Main).CornerRadius=UDim.new(0,14)

local Header=Instance.new("Frame")
Header.Size=UDim2.new(1,0,0,22)
Header.BackgroundColor3=Color3.fromRGB(20,20,20)
Header.BorderSizePixel=0
Header.ClipsDescendants=false
Header.Parent=Main
Instance.new("UICorner",Header).CornerRadius=UDim.new(0,14)

local Close=Instance.new("TextButton")
Close.AnchorPoint=Vector2.new(1,0)
Close.Position=UDim2.new(1,-6,0,3)
Close.Size=UDim2.fromOffset(20,16)
Close.Text="x"; Close.Font=Enum.Font.GothamBold; Close.TextScaled=true
Close.TextColor3=Color3.new(1,1,1)
Close.BackgroundColor3=Color3.fromRGB(200,40,40); Close.BorderSizePixel=0
Close.Parent=Header
Instance.new("UICorner",Close).CornerRadius=UDim.new(0,5)
Close.MouseButton1Click:Connect(function() FX_ON=false; unbind(); Cam.FieldOfView=BASE_FOV; root:Destroy() end)

-- drag
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
                Main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
            end
        end)
        input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then endDrag() end end)
    end
    for _,t in ipairs({Header,Main}) do
        t.InputBegan:Connect(function(i)
            local ut=i.UserInputType
            if ut==Enum.UserInputType.MouseButton1 or ut==Enum.UserInputType.Touch then begin(i) end
        end)
    end
end

-- content
local Content=Instance.new("Frame")
Content.Size=UDim2.new(1,-10,1,-(22+8+28))
Content.Position=UDim2.new(0,5,0,26)
Content.BackgroundTransparency=1
Content.ClipsDescendants=false
Content.Parent=Main

local Scroll=Instance.new("ScrollingFrame")
Scroll.Size=UDim2.new(1,0,1,0)
Scroll.BackgroundTransparency=1
Scroll.ScrollBarThickness=3
Scroll.CanvasSize=UDim2.new(0,0,0,0)
Scroll.ClipsDescendants=false
Scroll.Parent=Content

local UIL=Instance.new("UIListLayout",Scroll)
UIL.Padding=UDim.new(0,5)
UIL.SortOrder=Enum.SortOrder.LayoutOrder
local function fit() task.defer(function() Scroll.CanvasSize=UDim2.new(0,0,0,UIL.AbsoluteContentSize.Y+6) end) end
UIL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)

-- mini toggle
local function miniToggle(parent, get, set)
    local t=Instance.new("TextButton")
    t.Size=UDim2.fromOffset(34,18)
    t.Position=UDim2.fromOffset(0,4)
    t.Text=get() and "ON" or "OFF"
    t.Font=Enum.Font.GothamBold; t.TextScaled=true; t.TextColor3=Color3.new(1,1,1)
    t.BackgroundColor3=get() and Color3.fromRGB(0,140,60) or Color3.fromRGB(60,60,60)
    t.BorderSizePixel=0; t.Parent=parent
    Instance.new("UICorner",t).CornerRadius=UDim.new(0,5)
    local function refresh()
        t.Text=get() and "ON" or "OFF"
        t.BackgroundColor3=get() and Color3.fromRGB(0,140,60) or Color3.fromRGB(60,60,60)
    end
    t.MouseButton1Click:Connect(function() set(not get()); refresh() end)
    return t, refresh
end

-- row builder (super compact)
local function makeRow(label, key, isAngle)
    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,26)
    row.BackgroundColor3=Color3.fromRGB(25,25,25)
    row.BorderSizePixel=0
    row.ClipsDescendants=false
    row.Parent=Scroll
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,7)

    -- label kecil, sempit
    local L=Instance.new("TextLabel")
    L.BackgroundTransparency=1
    L.Position=UDim2.fromOffset(6,0)
    L.Size=UDim2.new(0,78,1,0) -- dipangkas agar area kanan luas
    L.Font=Enum.Font.GothamBold; L.TextScaled=true; L.TextXAlignment=Enum.TextXAlignment.Left
    L.TextColor3=Color3.new(1,1,1); L.Text=label
    L.Parent=row

    local right=Instance.new("Frame")
    right.BackgroundTransparency=1
    right.Size=UDim2.new(1,-(6+78+6),1,0) -- sisa lebar
    right.Position=UDim2.new(0,6+78,0,0)
    right.Parent=row
    right.ClipsDescendants=false

    local tog,_=miniToggle(right, function() return cfg[key].on end, function(v) cfg[key].on=v end)

    local minus=Instance.new("TextButton")
    minus.Size=UDim2.fromOffset(18,18)
    minus.Position=UDim2.new(0,36,0,4)
    minus.Text="-"; minus.Font=Enum.Font.GothamBold; minus.TextScaled=true; minus.TextColor3=Color3.new(1,1,1)
    minus.BackgroundColor3=Color3.fromRGB(45,45,45); minus.BorderSizePixel=0; minus.Parent=right
    Instance.new("UICorner",minus).CornerRadius=UDim.new(0,5)

    local val=Instance.new("TextLabel")
    val.Size=UDim2.fromOffset(32,18)
    val.Position=UDim2.new(0,56,0,4)
    val.BackgroundColor3=Color3.fromRGB(35,35,35); val.BorderSizePixel=0
    val.Font=Enum.Font.GothamBold; val.TextScaled=true; val.TextColor3=Color3.new(1,1,1)
    val.Text=(isAngle and tostring(math.floor(cfg[key].amt)) or string.format("%.2f", cfg[key].amt))
    val.Parent=right
    Instance.new("UICorner",val).CornerRadius=UDim.new(0,5)

    local plus=Instance.new("TextButton")
    plus.Size=UDim2.fromOffset(18,18)
    plus.Position=UDim2.new(0,90,0,4) -- JAUH ke kanan agar tak pernah ketutup
    plus.Text="+"; plus.Font=Enum.Font.GothamBold; plus.TextScaled=true; plus.TextColor3=Color3.new(1,1,1)
    plus.BackgroundColor3=Color3.fromRGB(45,45,45); plus.BorderSizePixel=0; plus.Parent=right
    Instance.new("UICorner",plus).CornerRadius=UDim.new(0,5)

    local function updateText()
        val.Text=(isAngle and tostring(math.floor(cfg[key].amt)) or string.format("%.2f", cfg[key].amt))
    end
    minus.MouseButton1Click:Connect(function()
        local lo,hi=range[key][1],range[key][2]
        cfg[key].amt = clamp(cfg[key].amt - (isAngle and 1 or 0.02), lo, hi)
        updateText()
    end)
    plus.MouseButton1Click:Connect(function()
        local lo,hi=range[key][1],range[key][2]
        cfg[key].amt = clamp(cfg[key].amt + (isAngle and 1 or 0.02), lo, hi)
        updateText()
    end)
end

makeRow("Tilt","tilt",true)
makeRow("Bob","bob",false)
makeRow("Jump Zoom","zoom",true)

-- Smooth (khusus speed)
do
    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,26)
    row.BackgroundColor3=Color3.fromRGB(25,25,25); row.BorderSizePixel=0
    row.ClipsDescendants=false
    row.Parent=Scroll
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,7)

    local L=Instance.new("TextLabel")
    L.BackgroundTransparency=1
    L.Position=UDim2.fromOffset(6,0)
    L.Size=UDim2.new(0,78,1,0)
    L.Font=Enum.Font.Gotham; L.TextScaled=true; L.TextXAlignment=Enum.TextXAlignment.Left
    L.TextColor3=Color3.new(1,1,1); L.Text="Smooth"
    L.Parent=row

    local minus=Instance.new("TextButton")
    minus.Size=UDim2.fromOffset(18,18)
    minus.Position=UDim2.new(0,6+78,0,4)
    minus.Text="-"; minus.Font=Enum.Font.GothamBold; minus.TextScaled=true; minus.TextColor3=Color3.new(1,1,1)
    minus.BackgroundColor3=Color3.fromRGB(45,45,45); minus.BorderSizePixel=0; minus.Parent=row
    Instance.new("UICorner",minus).CornerRadius=UDim.new(0,5)

    local val=Instance.new("TextLabel")
    val.Size=UDim2.fromOffset(32,18)
    val.Position=UDim2.new(0,6+78+20,0,4)
    val.BackgroundColor3=Color3.fromRGB(35,35,35); val.BorderSizePixel=0
    val.Font=Enum.Font.GothamBold; val.TextScaled=true; val.TextColor3=Color3.new(1,1,1)
    val.Text=tostring(cfg.zoom.speed); val.Parent=row
    Instance.new("UICorner",val).CornerRadius=UDim.new(0,5)

    local plus=Instance.new("TextButton")
    plus.Size=UDim2.fromOffset(18,18)
    plus.Position=UDim2.new(0,6+78+20+34,0,4)
    plus.Text="+"; plus.Font=Enum.Font.GothamBold; plus.TextScaled=true; plus.TextColor3=Color3.new(1,1,1)
    plus.BackgroundColor3=Color3.fromRGB(45,45,45); plus.BorderSizePixel=0; plus.Parent=row
    Instance.new("UICorner",plus).CornerRadius=UDim.new(0,5)

    local function upd() val.Text=tostring(math.floor(cfg.zoom.speed*10)/10) end
    minus.MouseButton1Click:Connect(function() cfg.zoom.speed=clamp(cfg.zoom.speed-0.5, range.smooth[1], range.smooth[2]); upd() end)
    plus.MouseButton1Click:Connect(function()  cfg.zoom.speed=clamp(cfg.zoom.speed+0.5, range.smooth[1], range.smooth[2]); upd() end)
    upd()
end

-- bottom bar
local Bottom=Instance.new("Frame")
Bottom.Size=UDim2.new(1,-10,0,28)
Bottom.Position=UDim2.new(0,5,1,-28)
Bottom.BackgroundTransparency=1
Bottom.Parent=Main

local Reset=Instance.new("TextButton")
Reset.Size=UDim2.new(0.48,-2,1,0)
Reset.Position=UDim2.new(0,0,0,0)
Reset.Text="RESET"
Reset.Font=Enum.Font.GothamBold; Reset.TextScaled=true; Reset.TextColor3=Color3.new(1,1,1)
Reset.BackgroundColor3=Color3.fromRGB(170,60,60); Reset.BorderSizePixel=0
Reset.Parent=Bottom; Instance.new("UICorner",Reset).CornerRadius=UDim.new(0,7)
Reset.MouseButton1Click:Connect(function()
    cfg.tilt.on,cfg.bob.on,cfg.zoom.on=true,true,true
    cfg.tilt.amt=4.0; cfg.bob.amt=0.12; cfg.bob.freq=8.0; cfg.zoom.amt=10.0; cfg.zoom.speed=6.0
    resetCam()
end)

local TAll=Instance.new("TextButton")
TAll.Size=UDim2.new(0.48,0,1,0)
TAll.Position=UDim2.new(1,0,0,0); TAll.AnchorPoint=Vector2.new(1,0)
TAll.Text="DISABLE ALL"
TAll.Font=Enum.Font.GothamBold; TAll.TextScaled=true; TAll.TextColor3=Color3.new(1,1,1)
TAll.BackgroundColor3=Color3.fromRGB(60,60,60); TAll.BorderSizePixel=0
TAll.Parent=Bottom; Instance.new("UICorner",TAll).CornerRadius=UDim.new(0,7)
local allOff=false
TAll.MouseButton1Click:Connect(function()
    allOff=not allOff
    cfg.tilt.on, cfg.bob.on, cfg.zoom.on = not allOff, not allOff, not allOff
    TAll.Text = allOff and "ENABLE ALL" or "DISABLE ALL"
    TAll.BackgroundColor3 = allOff and Color3.fromRGB(0,140,60) or Color3.fromRGB(60,60,60)
end)

fit()
bind()
root.AncestryChanged:Connect(function(_,p) if not p then FX_ON=false; unbind(); Cam.FieldOfView=BASE_FOV end end)