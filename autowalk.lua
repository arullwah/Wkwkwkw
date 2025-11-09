-- ========= AUTO WALK PRO v9.0 (FINAL, 1 FILE) =========
-- Playback berbasis waktu (mulus), Reverse/Forward 0.5s berulang,
-- Resume menghapus frame depan sesuai timeline & sambung mulus,
-- Save→Replay List→Play/Delete/Close berfungsi,
-- GUI 200x180, header "Frame X" di tengah, 7 replay terlihat tanpa scroll,
-- Tanpa raycast & tanpa anti-fall aktif, tanpa print/warn.

-- ========= SERVICES =========
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
task.wait(0.5)

-- ========= CONFIG =========
local RECORDING_FPS = 60
local MAX_FRAMES = 30000
local MIN_DISTANCE_THRESHOLD = 0.015
local ROUTE_PROXIMITY_THRESHOLD = 10

local INTERPOLATION_ENABLED = true
local INTERPOLATION_ALPHA = 0.45
local MIN_INTERPOLATION_DISTANCE = 0.3

local TIMELINE_STEP_SECONDS = 0.5 -- reverse/forward step
local GUI_MAIN_W, GUI_MAIN_H = 200, 180

-- ========= STATE =========
local IsRecording = false
local IsTimelineMode = false -- saat navigasi reverse/forward
local IsPlaying = false
local IsPaused = false
local AutoLoop = false

local CurrentSpeed = 1.0
local CurrentRecording = { Frames = {}, StartTime = 0, Name = "" }
local RecordedMovements = {} -- [name] = array of frames

local recordConnection
local playbackConnection
local globalConnections = {}
local replayListConnections = {}

local lastRecordTime = 0
local lastRecordPos = nil

-- Timeline cursor berbasis detik (bukan index)
local TimelineCursorSec = 0

-- Playback trackers
local currentRecordingName = nil
local currentPlaybackFrame = 1
local playbackStartTick = 0
local totalPausedDuration = 0
local pauseStartTick = 0
local playbackStartOffsetSec = 0 -- untuk play dari frame terdekat

-- ========= CONNECTION HELPERS =========
local function AddGlobal(conn) if conn then table.insert(globalConnections, conn) end end
local function CleanupGlobal()
	for _, c in ipairs(globalConnections) do if c and c.Connected then c:Disconnect() end end
	globalConnections = {}
end
local function CleanupReplayListConns()
	for _, c in ipairs(replayListConnections) do if c and c.Connected then c:Disconnect() end end
	replayListConnections = {}
end

-- ========= UTIL =========
local function GetChar()
	local ch = player.Character
	if ch and ch:FindFirstChild("HumanoidRootPart") and ch:FindFirstChildOfClass("Humanoid") then
		return ch, ch.HumanoidRootPart, ch:FindFirstChildOfClass("Humanoid")
	end
	return nil
end

local function Vec3From(t) return Vector3.new(t[1], t[2], t[3]) end

local function GetFrameCFrame(f)
	local pos = Vec3From(f.Position)
	local look = Vec3From(f.LookVector)
	local up = Vec3From(f.UpVector)
	return CFrame.lookAt(pos, pos + look, up)
end

local function GetFrameTimestamp(f) return f.Timestamp or 0 end
local function GetFrameWalkSpeed(f) return f.WalkSpeed or 16 end

local function SmoothCFrameLerp(currentCF, targetCF, alpha)
	if not INTERPOLATION_ENABLED then return targetCF end
	local dist = (targetCF.Position - currentCF.Position).Magnitude
	if dist < MIN_INTERPOLATION_DISTANCE or dist > 25 then
		return targetCF
	end
	return currentCF:Lerp(targetCF, alpha)
end

-- Binary search by timestamp
local function FindFrameIndexByTime(frames, t)
	if not frames or #frames == 0 then return 1 end
	local lo, hi = 1, #frames
	while lo < hi do
		local mid = math.floor((lo + hi) / 2)
		if GetFrameTimestamp(frames[mid]) < t then
			lo = mid + 1
		else
			hi = mid
		end
	end
	return lo
end

local function UpdateTimelineCursorToEnd()
	if #CurrentRecording.Frames == 0 then
		TimelineCursorSec = 0
	else
		TimelineCursorSec = GetFrameTimestamp(CurrentRecording.Frames[#CurrentRecording.Frames])
	end
end

-- Buat transisi halus saat resume dari last frame ke posisi HRP sekarang
local function CreateSeamlessTransition(fromFrame, toPos)
	local Trans = {}
	if not fromFrame or not toPos then return Trans end
	local startPos = Vec3From(fromFrame.Position)
	local dist = (toPos - startPos).Magnitude
	local steps = math.max(3, math.floor(dist / 1.5))
	for i = 1, steps do
		local a = i / steps
		local p = startPos:Lerp(toPos, a)
		table.insert(Trans, {
			Position = {p.X, p.Y, p.Z},
			LookVector = fromFrame.LookVector,
			UpVector = fromFrame.UpVector,
			Velocity = {0,0,0},
			MoveState = "Running",
			WalkSpeed = fromFrame.WalkSpeed or 16,
			Timestamp = fromFrame.Timestamp + (i * (1/RECORDING_FPS))
		})
	end
	return Trans
end

-- ========= GUI (MAIN 200x180) =========
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoWalkProV90"
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = player:WaitForChild("PlayerGui") end)

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.fromOffset(GUI_MAIN_W, GUI_MAIN_H)
MainFrame.Position = UDim2.new(0.5, -GUI_MAIN_W/2, 0.5, -GUI_MAIN_H/2)
MainFrame.BackgroundColor3 = Color3.fromRGB(15,15,15)
MainFrame.BorderSizePixel = 0
MainFrame.Active, MainFrame.Draggable = true, true
MainFrame.Parent = ScreenGui
local MainCorner = Instance.new("UICorner", MainFrame) MainCorner.CornerRadius = UDim.new(0,10)

-- Header dengan label Frame di tengah + [x]
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1,0,0,22)
Header.BackgroundColor3 = Color3.fromRGB(0,0,0)
Header.BorderSizePixel = 0
Header.Parent = MainFrame
local HeaderCorner = Instance.new("UICorner", Header) HeaderCorner.CornerRadius = UDim.new(0,10)

local FrameLabel = Instance.new("TextLabel")
FrameLabel.Size = UDim2.new(1,-26,1,0)
FrameLabel.Position = UDim2.new(0,13,0,0)
FrameLabel.BackgroundTransparency = 1
FrameLabel.Text = "Frame 0"
FrameLabel.TextColor3 = Color3.fromRGB(100,255,150)
FrameLabel.Font = Enum.Font.GothamBold
FrameLabel.TextSize = 12
FrameLabel.TextXAlignment = Enum.TextXAlignment.Center
FrameLabel.Parent = Header
FrameLabel.ZIndex = 2

local CloseMainBtn = Instance.new("TextButton")
CloseMainBtn.Size = UDim2.fromOffset(18,18)
CloseMainBtn.Position = UDim2.new(1,-20,0.5,-9)
CloseMainBtn.BackgroundColor3 = Color3.fromRGB(200,50,60)
CloseMainBtn.Text = "×"
CloseMainBtn.TextColor3 = Color3.new(1,1,1)
CloseMainBtn.Font = Enum.Font.GothamBold
CloseMainBtn.TextSize = 14
CloseMainBtn.Parent = Header
local CloseCorner = Instance.new("UICorner", CloseMainBtn) CloseCorner.CornerRadius = UDim.new(0,4)

-- Helper button
local function Btn(parent, text, x, y, w, h, color)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(w,h)
	b.Position = UDim2.fromOffset(x,y)
	b.BackgroundColor3 = color
	b.Text = text
	b.TextColor3 = Color3.new(1,1,1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 10
	b.AutoButtonColor = false
	b.Parent = parent
	local c = Instance.new("UICorner", b) c.CornerRadius = UDim.new(0,6)
	return b
end

-- Row1: [SAVE] [RECORD] [CLEAR]
local RowY1 = 26
local SaveBtn   = Btn(MainFrame, "SAVE",   6, RowY1, 58, 20, Color3.fromRGB(40,140,70))
local RecordBtn = Btn(MainFrame, "RECORD", 70, RowY1, 64, 20, Color3.fromRGB(200,50,60))
local ClearBtn  = Btn(MainFrame, "CLEAR",  140, RowY1, 54, 20, Color3.fromRGB(140,50,60))

-- Row2: [⏪] [RESUME] [⏩]
local RowY2 = RowY1 + 24
local ReverseBtn = Btn(MainFrame, "⏪",     6, RowY2, 58, 22, Color3.fromRGB(80,120,200))
local ResumeBtn  = Btn(MainFrame, "RESUME",70, RowY2, 64, 22, Color3.fromRGB(40,180,80))
local ForwardBtn = Btn(MainFrame, "⏩",     140,RowY2, 54, 22, Color3.fromRGB(200,120,80))

-- Row3: [PAUSE] [PLAY] [STOP]
local RowY3 = RowY2 + 24
local PauseBtn = Btn(MainFrame, "PAUSE",  6, RowY3, 58, 20, Color3.fromRGB(255,150,50))
local PlayBtn  = Btn(MainFrame, "PLAY",  70, RowY3, 64, 20, Color3.fromRGB(40,180,80))
local StopBtn  = Btn(MainFrame, "STOP", 140, RowY3, 54, 20, Color3.fromRGB(150,50,60))

-- Row4: Filename + [SAVE FILE] [LOAD]
local FileName = Instance.new("TextBox")
FileName.Size = UDim2.fromOffset(120, 20)
FileName.Position = UDim2.fromOffset(6, RowY3+24)
FileName.BackgroundColor3 = Color3.fromRGB(25,25,25)
FileName.Text = ""
FileName.PlaceholderText = "filename"
FileName.TextColor3 = Color3.fromRGB(200,200,220)
FileName.Font = Enum.Font.Gotham
FileName.TextSize = 10
FileName.Parent = MainFrame
local FileCorner = Instance.new("UICorner", FileName) FileCorner.CornerRadius = UDim.new(0,6)

local SaveFileBtn = Btn(MainFrame, "SAVE", 130, RowY3+24, 30, 20, Color3.fromRGB(40,140,70))
local LoadFileBtn = Btn(MainFrame, "LOAD", 164, RowY3+24, 30, 20, Color3.fromRGB(140,100,40))

-- Status (di atas progress)
local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1,-12,0,12)
Status.Position = UDim2.new(0,6,1,-28)
Status.BackgroundTransparency = 1
Status.Text = "Ready"
Status.TextColor3 = Color3.fromRGB(100,255,150)
Status.Font = Enum.Font.Gotham
Status.TextSize = 10
Status.TextXAlignment = Enum.TextXAlignment.Center
Status.Parent = MainFrame

-- Progress bar (bawah)
local ProgressBG = Instance.new("Frame")
ProgressBG.Size = UDim2.new(1,-12,0,6)
ProgressBG.Position = UDim2.new(0,6,1,-14)
ProgressBG.BackgroundColor3 = Color3.fromRGB(30,30,30)
ProgressBG.BorderSizePixel = 0
ProgressBG.Parent = MainFrame
local PBGC = Instance.new("UICorner", ProgressBG) PBGC.CornerRadius = UDim.new(0,3)

local ProgressBar = Instance.new("Frame")
ProgressBar.Size = UDim2.new(0,0,1,0)
ProgressBar.BackgroundColor3 = Color3.fromRGB(100,255,150)
ProgressBar.BorderSizePixel = 0
ProgressBar.Parent = ProgressBG
local PBC = Instance.new("UICorner", ProgressBar) PBC.CornerRadius = UDim.new(0,3)

local function UpdateStatus(msg) pcall(function() Status.Text = msg end) end

-- Replay List (muat 7 item tanpa scroll; sisanya scroll)
local ListTop = RowY3 + 24 + 24
local visibleHeight = GUI_MAIN_H - ListTop - 32 -- sisakan area status + progress
local ReplayList = Instance.new("ScrollingFrame")
ReplayList.Size = UDim2.new(1,-12,0,visibleHeight)
ReplayList.Position = UDim2.fromOffset(6, ListTop)
ReplayList.BackgroundColor3 = Color3.fromRGB(20,20,20)
ReplayList.BorderSizePixel = 0
ReplayList.ScrollBarThickness = 4
ReplayList.ScrollBarImageColor3 = Color3.fromRGB(80,80,80)
ReplayList.CanvasSize = UDim2.new(0,0,0,0)
ReplayList.Parent = MainFrame
local RLCorner = Instance.new("UICorner", ReplayList) RLCorner.CornerRadius = UDim.new(0,6)
local RLLayout = Instance.new("UIListLayout", ReplayList) RLLayout.Padding = UDim.new(0,2)

-- ========= FRAME LABEL =========
local function UpdateFrameLabel() pcall(function() FrameLabel.Text = "Frame " .. tostring(#CurrentRecording.Frames) end) end

-- ========= RECORDING =========
local function StartRecording()
	if IsRecording then return end
	local char, hrp, hum = GetChar()
	if not char then UpdateStatus("Character not found"); return end

	IsRecording = true
	IsTimelineMode = false
	CurrentRecording = { Frames = {}, StartTime = tick(), Name = "Recording_" .. os.date("%H%M%S") }
	lastRecordTime = 0
	lastRecordPos = nil
	UpdateTimelineCursorToEnd()

	RecordBtn.Text = "STOP"
	UpdateStatus("Recording...")

	recordConnection = RunService.Heartbeat:Connect(function()
		local ch, r, h = GetChar()
		if not ch or #CurrentRecording.Frames >= MAX_FRAMES then return end
		if IsTimelineMode then return end -- pause write saat navigasi timeline

		local now = tick()
		if (now - lastRecordTime) < (1/RECORDING_FPS) then return end

		local cf = r.CFrame
		local pos = r.Position
		if lastRecordPos and (pos - lastRecordPos).Magnitude < MIN_DISTANCE_THRESHOLD then
			lastRecordTime = now
			return
		end

		local vel = r.AssemblyLinearVelocity
		local state = "Idle"
		if vel.Y > 25 then state = "Jumping"
		elseif vel.Y < -25 then state = "Falling"
		elseif math.abs(vel.Y) < 5 and vel.Magnitude > 2 then state = "Running"
		end

		table.insert(CurrentRecording.Frames, {
			Position = {cf.Position.X, cf.Position.Y, cf.Position.Z},
			LookVector = {cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z},
			UpVector = {cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z},
			Velocity = {vel.X, vel.Y, vel.Z},
			MoveState = state,
			WalkSpeed = h and h.WalkSpeed or 16,
			Timestamp = now - CurrentRecording.StartTime
		})

		lastRecordTime = now
		lastRecordPos = pos
		UpdateFrameLabel()
		UpdateTimelineCursorToEnd() -- cursor selalu ke akhir ketika merekam
	end)
	AddGlobal(recordConnection)
end

local function StopRecording()
	if not IsRecording then return end
	IsRecording = false
	IsTimelineMode = false
	if recordConnection then recordConnection:Disconnect() recordConnection = nil end
	RecordBtn.Text = "RECORD"
	UpdateStatus("Recording stopped ("..tostring(#CurrentRecording.Frames).." frames)")
end

-- ========= TIMELINE REVERSE/FORWARD =========
local function MoveCharacterToTime(frames, t)
	local ch, hrp, hum = GetChar()
	if not ch or not frames or #frames == 0 then return end
	local idx = FindFrameIndexByTime(frames, t)
	idx = math.clamp(idx, 1, #frames)
	local f = frames[idx]
	hrp.CFrame = GetFrameCFrame(f)
	if hum then hum.WalkSpeed = 0 end
	currentPlaybackFrame = idx
end

local function StartReverseStep()
	if not IsRecording then UpdateStatus("Not recording"); return end
	if #CurrentRecording.Frames == 0 then UpdateStatus("No frames"); return end

	IsTimelineMode = true
	TimelineCursorSec = math.max(0, TimelineCursorSec - TIMELINE_STEP_SECONDS)
	MoveCharacterToTime(CurrentRecording.Frames, TimelineCursorSec)
	UpdateStatus("Reverse 0.5s → t="..string.format("%.2f", TimelineCursorSec))
end

local function StartForwardStep()
	if not IsRecording then UpdateStatus("Not recording"); return end
	if #CurrentRecording.Frames == 0 then UpdateStatus("No frames"); return end

	local endT = GetFrameTimestamp(CurrentRecording.Frames[#CurrentRecording.Frames])
	TimelineCursorSec = math.min(endT, TimelineCursorSec + TIMELINE_STEP_SECONDS)
	MoveCharacterToTime(CurrentRecording.Frames, TimelineCursorSec)
	UpdateStatus("Forward 0.5s → t="..string.format("%.2f", TimelineCursorSec))
end

-- ========= SMART RESUME (hapus frame depan & sambung) =========
local function SmartResume()
	if not IsRecording then UpdateStatus("Not recording"); return end
	local ch, hrp, hum = GetChar()
	if not ch then UpdateStatus("Character not found"); return end
	if #CurrentRecording.Frames == 0 then
		IsTimelineMode = false
		UpdateStatus("Resume ready (no frames yet)")
		return
	end

	-- 1) Potong semua frame setelah TimelineCursorSec
	local idx = FindFrameIndexByTime(CurrentRecording.Frames, TimelineCursorSec)
	for i = #CurrentRecording.Frames, idx, -1 do
		table.remove(CurrentRecording.Frames, i)
	end

	-- 2) Buat transition jika posisi HRP sekarang jauh dari frame terakhir
	if #CurrentRecording.Frames > 0 then
		local lastFrame = CurrentRecording.Frames[#CurrentRecording.Frames]
		local lastPos = Vec3From(lastFrame.Position)
		local curPos = hrp.Position
		if (curPos - lastPos).Magnitude > 1.5 then
			local trans = CreateSeamlessTransition(lastFrame, curPos)
			for _, f in ipairs(trans) do table.insert(CurrentRecording.Frames, f) end
		end
	end

	-- 3) Lanjut rekam normal (heartbeat), timeline mode off
	IsTimelineMode = false
	if hum then hum.AutoRotate = true end
	UpdateFrameLabel()
	UpdateStatus("Resume: cut to t="..string.format("%.2f", TimelineCursorSec).." & continue recording")
end

-- ========= REPLAY LIST =========
local function UpdateReplayList()
	CleanupReplayListConns()
	for _, c in ipairs(ReplayList:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end

	local names = {}
	for name, rec in pairs(RecordedMovements) do
		if rec and #rec > 0 then table.insert(names, name) end
	end
	table.sort(names)

	local y = 0
	for _, name in ipairs(names) do
		local rec = RecordedMovements[name]
		local item = Instance.new("Frame")
		item.Size = UDim2.new(1, -4, 0, 16)
		item.BackgroundColor3 = Color3.fromRGB(30,30,30)
		item.Parent = ReplayList
		item.LayoutOrder = y
		local ic = Instance.new("UICorner", item) ic.CornerRadius = UDim.new(0,4)

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1,-70,1,0)
		label.Position = UDim2.new(0,4,0,0)
		label.BackgroundTransparency = 1
		label.Text = name .. " ("..tostring(#rec)..")"
		label.TextColor3 = Color3.new(1,1,1)
		label.Font = Enum.Font.Gotham
		label.TextSize = 10
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = item

		local play = Instance.new("TextButton")
		play.Size = UDim2.fromOffset(32,14)
		play.Position = UDim2.new(1,-66,0.5,-7)
		play.BackgroundColor3 = Color3.fromRGB(40,180,80)
		play.Text = "PLAY"
		play.TextColor3 = Color3.new(1,1,1)
		play.Font = Enum.Font.GothamBold
		play.TextSize = 8
		play.AutoButtonColor = false
		play.Parent = item
		local pc = Instance.new("UICorner", play) pc.CornerRadius = UDim.new(0,3)

		local del = Instance.new("TextButton")
		del.Size = UDim2.fromOffset(28,14)
		del.Position = UDim2.new(1,-34,0.5,-7)
		del.BackgroundColor3 = Color3.fromRGB(200,50,60)
		del.Text = "DEL"
		del.TextColor3 = Color3.new(1,1,1)
		del.Font = Enum.Font.GothamBold
		del.TextSize = 8
		del.AutoButtonColor = false
		del.Parent = item
		local dc = Instance.new("UICorner", del) dc.CornerRadius = UDim.new(0,3)

		local c1 = play.MouseButton1Click:Connect(function()
			if IsPlaying then return end
			currentRecordingName = name
			AutoLoop = false
			IsPaused = false
			IsPlaying = true
			playbackStartTick = tick()
			totalPausedDuration = 0
			pauseStartTick = 0
			currentPlaybackFrame = 1
			playbackStartOffsetSec = 0
			UpdateStatus("▶ Playing: "..name)
		end)
		table.insert(replayListConnections, c1)

		local c2 = del.MouseButton1Click:Connect(function()
			RecordedMovements[name] = nil
			UpdateReplayList()
			UpdateStatus("Deleted: "..name)
		end)
		table.insert(replayListConnections, c2)

		y += 18
	end

	ReplayList.CanvasSize = UDim2.new(0,0,0,y)
end

-- ========= CHARACTER HELPERS =========
local function CompleteCharacterReset(ch)
	pcall(function()
		local hum = ch:FindFirstChildOfClass("Humanoid")
		local hrp = ch:FindFirstChild("HumanoidRootPart")
		if hum then
			hum.PlatformStand = false
			hum.AutoRotate = true
			hum.WalkSpeed = 16
			hum.JumpPower = 50
		end
		if hrp then
			hrp.AssemblyLinearVelocity = Vector3.new()
			hrp.AssemblyAngularVelocity = Vector3.new()
		end
	end)
end

local function ApplyFrameToCharacter(f)
	local ch, hrp, hum = GetChar()
	if not ch then return end
	local targetCF = GetFrameCFrame(f)
	hrp.CFrame = SmoothCFrameLerp(hrp.CFrame, targetCF, INTERPOLATION_ALPHA)
	if hum then
		hum.WalkSpeed = GetFrameWalkSpeed(f) * CurrentSpeed
		local s = f.MoveState
		if s == "Climbing" then hum:ChangeState(Enum.HumanoidStateType.Climbing)
		elseif s == "Jumping" then hum:ChangeState(Enum.HumanoidStateType.Jumping); hum.Jump = true
		elseif s == "Swimming" then hum:ChangeState(Enum.HumanoidStateType.Swimming)
		elseif s == "Falling" then hum:ChangeState(Enum.HumanoidStateType.Freefall)
		else hum:ChangeState(Enum.HumanoidStateType.RunningNoPhysics) end
	end
end

-- ========= PLAYBACK LOOP (TIME-BASED) =========
local function StopPlayback()
	if not IsPlaying then return end
	IsPlaying, IsPaused = false, false
	if playbackConnection then playbackConnection:Disconnect() playbackConnection = nil end
	local ch = player.Character
	if ch then CompleteCharacterReset(ch) end
	UpdateStatus("■ Playback Stopped")
end

local function ResetPlaybackLoopWithOffset()
	if playbackConnection then playbackConnection:Disconnect() playbackConnection = nil end

	playbackConnection = RunService.Heartbeat:Connect(function()
		if not IsPlaying then return end

		local name = currentRecordingName
		if not name then
			local first = next(RecordedMovements)
			if not first then StopPlayback() return end
			name = first
			currentRecordingName = first
		end
		local rec = RecordedMovements[name]
		if not rec or #rec == 0 then StopPlayback() return end

		local ch = player.Character
		if not ch then StopPlayback() return end

		local now = tick()
		if IsPaused then
			if pauseStartTick == 0 then pauseStartTick = now end
			return
		else
			if pauseStartTick > 0 then
				totalPausedDuration += (now - pauseStartTick)
				pauseStartTick = 0
			end
		end

		local elapsed = ((now - playbackStartTick - totalPausedDuration) * CurrentSpeed) + playbackStartOffsetSec
		local idx = FindFrameIndexByTime(rec, elapsed)
		if idx > #rec then
			StopPlayback()
			if AutoLoop then
				task.wait(0.5)
				IsPlaying, IsPaused = true, false
				playbackStartTick = tick()
				totalPausedDuration, pauseStartTick = 0, 0
				playbackStartOffsetSec = 0
				UpdateStatus("🔁 Looping playback...")
			end
			return
		end

		currentPlaybackFrame = idx
		ApplyFrameToCharacter(rec[idx])

		local lastT = GetFrameTimestamp(rec[#rec])
		local progress = (lastT > 0) and math.clamp(elapsed / lastT, 0, 1) or 0
		ProgressBar.Size = UDim2.new(progress, 0, 1, 0)
	end)
	AddGlobal(playbackConnection)
end
ResetPlaybackLoopWithOffset()

local function PlayFromNearestFrame(name)
	local ch, hrp = GetChar()
	if not ch then UpdateStatus("Character not found"); return end
	if not name then for k,_ in pairs(RecordedMovements) do name = k break end end
	if not name then UpdateStatus("No recordings"); return end

	local rec = RecordedMovements[name]
	if not rec or #rec == 0 then UpdateStatus("Empty recording"); return end

	currentRecordingName = name
	local nearest, dist = 1, math.huge
	for i, f in ipairs(rec) do
		local p = Vec3From(f.Position)
		local d = (p - hrp.Position).Magnitude
		if d < dist then dist = d; nearest = i end
	end

	if dist <= ROUTE_PROXIMITY_THRESHOLD then
		playbackStartOffsetSec = GetFrameTimestamp(rec[nearest])
	else
		playbackStartOffsetSec = 0
	end

	IsPlaying, IsPaused = true, false
	playbackStartTick = tick()
	totalPausedDuration, pauseStartTick = 0, 0
	currentPlaybackFrame = 1
	AutoLoop = false
	UpdateStatus(("▶ Playing: %s %s"):format(name, dist <= ROUTE_PROXIMITY_THRESHOLD and "(nearest)" or "(from start)"))
end

-- ========= SAVE / LOAD =========
local function SaveToFile()
	if not writefile then UpdateStatus("Save system not available"); return end
	if not next(RecordedMovements) then UpdateStatus("No recordings to save"); return end
	local filename = FileName.Text
	if filename == "" then filename = "MyWalk" end
	filename = filename:gsub("[^%w%s%-_]", "") .. ".json"

	local data = {
		recordings = RecordedMovements,
		settings = { speed = CurrentSpeed, autoLoop = AutoLoop },
		version = "9.0"
	}
	local ok, json = pcall(function() return HttpService:JSONEncode(data) end)
	if not ok then UpdateStatus("JSON encode failed"); return end
	local ok2 = pcall(function() writefile(filename, json) end)
	if ok2 then UpdateStatus("Saved: "..filename) else UpdateStatus("Save failed") end
end

local function LoadFromFile()
	if not readfile or not isfile then UpdateStatus("Load system not available"); return end
	local filename = FileName.Text
	if filename == "" then filename = "MyWalk" end
	filename = filename:gsub("[^%w%s%-_]", "") .. ".json"
	local ok, exists = pcall(function() return isfile(filename) end)
	if not ok or not exists then UpdateStatus("File not found"); return end
	local ok2, content = pcall(function() return readfile(filename) end)
	if not ok2 then UpdateStatus("Read file failed"); return end
	local ok3, data = pcall(function() return HttpService:JSONDecode(content) end)
	if not ok3 or type(data)~="table" then UpdateStatus("Invalid file"); return end

	RecordedMovements = data.recordings or {}
	CurrentSpeed = (data.settings and tonumber(data.settings.speed)) or 1
	AutoLoop = (data.settings and (data.settings.autoLoop == true)) or false
	UpdateReplayList()
	UpdateStatus("Loaded: "..filename)
end

-- ========= SPEED & LOOP UI =========
local function AddHoverEffect(button, baseColor)
	local hoverColor = Color3.fromRGB(
		math.min(baseColor.R * 255 + 20, 255),
		math.min(baseColor.G * 255 + 20, 255),
		math.min(baseColor.B * 255 + 20, 255)
	)
	button.MouseEnter:Connect(function()
		pcall(function() TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = hoverColor}):Play() end)
	end)
	button.MouseLeave:Connect(function()
		pcall(function() TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = baseColor}):Play() end)
	end)
end

local function MakeSmallBtn(txt, x, y, w, h, color)
	local b = Btn(MainFrame, txt, x, y, w, h, color)
	AddHoverEffect(b, color)
	return b
end

-- Letakkan Loop+Speed di area sisa atas status (tinggi 20)
local LoopBtn = MakeSmallBtn("Loop: OFF", 6, GUI_MAIN_H-60, 60, 20, Color3.fromRGB(80,80,80))
local SpeedMinus = MakeSmallBtn("-", GUI_MAIN_W-94, GUI_MAIN_H-60, 22, 20, Color3.fromRGB(50,50,50))
local SpeedDisplay = Instance.new("TextLabel")
SpeedDisplay.Size = UDim2.fromOffset(60, 20)
SpeedDisplay.Position = UDim2.new(1, -66, 1, -60)
SpeedDisplay.BackgroundColor3 = Color3.fromRGB(25,25,25)
SpeedDisplay.TextColor3 = Color3.fromRGB(100,255,150)
SpeedDisplay.Font = Enum.Font.GothamBold
SpeedDisplay.TextSize = 10
SpeedDisplay.Text = string.format("%.2fx", CurrentSpeed)
SpeedDisplay.TextXAlignment = Enum.TextXAlignment.Center
SpeedDisplay.Parent = MainFrame
local SpeedCorner = Instance.new("UICorner", SpeedDisplay) SpeedCorner.CornerRadius = UDim.new(0,6)
local SpeedPlus = MakeSmallBtn("+", GUI_MAIN_W-4-22, GUI_MAIN_H-60, 22, 20, Color3.fromRGB(50,50,50))

local function UpdateSpeedDisplay()
	pcall(function() SpeedDisplay.Text = string.format("%.2fx", CurrentSpeed) end)
end
local function ToggleLoop()
	AutoLoop = not AutoLoop
	LoopBtn.Text = "Loop: " .. (AutoLoop and "ON" or "OFF")
	LoopBtn.BackgroundColor3 = AutoLoop and Color3.fromRGB(40,180,80) or Color3.fromRGB(80,80,80)
	UpdateStatus("🔁 AutoLoop: " .. (AutoLoop and "Enabled" or "Disabled"))
end
LoopBtn.MouseButton1Click:Connect(ToggleLoop)
SpeedMinus.MouseButton1Click:Connect(function()
	if CurrentSpeed > 0.25 then
		CurrentSpeed = math.max(0.25, CurrentSpeed - 0.25)
		UpdateSpeedDisplay(); UpdateStatus("Speed: "..string.format("%.2fx", CurrentSpeed))
	end
end)
SpeedPlus.MouseButton1Click:Connect(function()
	if CurrentSpeed < 10 then
		CurrentSpeed = math.min(10, CurrentSpeed + 0.25)
		UpdateSpeedDisplay(); UpdateStatus("Speed: "..string.format("%.2fx", CurrentSpeed))
	end
end)

-- ========= BUTTON EVENTS =========
SaveBtn.MouseButton1Click:Connect(function()
	if #CurrentRecording.Frames == 0 then UpdateStatus("No frames to save"); return end
	if IsRecording then StopRecording() end
	RecordedMovements[CurrentRecording.Name] = CurrentRecording.Frames
	UpdateReplayList()
	UpdateStatus("Saved: "..CurrentRecording.Name.." ("..tostring(#CurrentRecording.Frames).." frames)")
	CurrentRecording = { Frames = {}, StartTime = 0, Name = "Recording_" .. os.date("%H%M%S") }
	UpdateFrameLabel()
end)

RecordBtn.MouseButton1Click:Connect(function()
	if IsRecording then StopRecording() else StartRecording() end
end)

ClearBtn.MouseButton1Click:Connect(function()
	if IsRecording then StopRecording() end
	CurrentRecording = { Frames = {}, StartTime = 0, Name = "Recording_" .. os.date("%H%M%S") }
	TimelineCursorSec = 0
	UpdateFrameLabel()
	UpdateStatus("Cleared")
end)

ReverseBtn.MouseButton1Click:Connect(function() StartReverseStep() end)
ForwardBtn.MouseButton1Click:Connect(function() StartForwardStep() end)
ResumeBtn.MouseButton1Click:Connect(function() SmartResume() end)

PauseBtn.MouseButton1Click:Connect(function()
	if not IsPlaying then return end
	IsPaused = not IsPaused
	UpdateStatus(IsPaused and "⏸ Paused" or "▶ Resumed")
end)

PlayBtn.MouseButton1Click:Connect(function()
	if IsPlaying then
		if IsPaused then IsPaused = false UpdateStatus("▶ Resumed") end
		return
	end
	-- play dari awal rekaman aktif (atau nearest via F6)
	local pick = currentRecordingName
	if not pick then for k,_ in pairs(RecordedMovements) do pick = k break end end
	if not pick then UpdateStatus("No recordings"); return end
	currentRecordingName = pick
	IsPlaying, IsPaused = true, false
	playbackStartTick = tick()
	totalPausedDuration, pauseStartTick = 0, 0
	currentPlaybackFrame = 1
	playbackStartOffsetSec = 0
	UpdateStatus("▶ Playing: "..pick)
end)

StopBtn.MouseButton1Click:Connect(function() StopPlayback() end)
SaveFileBtn.MouseButton1Click:Connect(function() SaveToFile() end)
LoadFileBtn.MouseButton1Click:Connect(function() LoadFromFile() end)

CloseMainBtn.MouseButton1Click:Connect(function()
	if IsRecording then StopRecording() end
	if IsPlaying then StopPlayback() end
	CleanupReplayListConns()
	CleanupGlobal()
	ScreenGui:Destroy()
end)

-- ========= HOTKEYS =========
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.F9 then
		if IsRecording then StopRecording() else StartRecording() end
	elseif input.KeyCode == Enum.KeyCode.F10 then
		if IsPlaying then StopPlayback() else
			local pick = currentRecordingName
			if not pick then for k,_ in pairs(RecordedMovements) do pick = k break end end
			if pick then
				currentRecordingName = pick
				IsPlaying, IsPaused = true, false
				playbackStartTick = tick()
				totalPausedDuration, pauseStartTick = 0, 0
				currentPlaybackFrame = 1
				playbackStartOffsetSec = 0
				UpdateStatus("▶ Playing: "..pick)
			else
				UpdateStatus("No recordings")
			end
		end
	elseif input.KeyCode == Enum.KeyCode.F7 then
		if IsPlaying then IsPaused = not IsPaused; UpdateStatus(IsPaused and "⏸ Paused" or "▶ Resumed") end
	elseif input.KeyCode == Enum.KeyCode.F6 then
		PlayFromNearestFrame(currentRecordingName)
	end
end)

-- ========= GUI POLISH (hover) =========
for _, btn in ipairs({SaveBtn, RecordBtn, ClearBtn, ReverseBtn, ResumeBtn, ForwardBtn,
	PauseBtn, PlayBtn, StopBtn, SaveFileBtn, LoadFileBtn, LoopBtn, SpeedMinus, SpeedPlus}) do
	AddHoverEffect(btn, btn.BackgroundColor3)
end

-- ========= RESPAWN SAFETY =========
player.CharacterAdded:Connect(function()
	task.wait(1)
	if IsRecording then
		StopRecording()
		UpdateStatus("⚠️ Recording stopped - Character respawned")
	end
	if IsPlaying then
		StopPlayback()
		UpdateStatus("⚠️ Playback stopped - Character respawned")
	end
end)

-- ========= QoL: label info timeline saat navigate =========
RunService.Heartbeat:Connect(function()
	pcall(function()
		if IsRecording then
			FrameLabel.Text = "Frame " .. tostring(#CurrentRecording.Frames)
		elseif IsTimelineMode then
			FrameLabel.Text = ("t=%.2fs | Frame %d"):format(
				TimelineCursorSec,
				FindFrameIndexByTime(CurrentRecording.Frames, TimelineCursorSec)
			)
		end
	end)
end)

-- ========= INIT =========
UpdateReplayList()
UpdateStatus("✅ Auto Walk Pro v9.0 Ready")
UpdateFrameLabel()