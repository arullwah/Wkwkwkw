-- ByaruL AutoWalk v6.0 - ENHANCED FRAME DATA SYSTEM
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

wait(1)

-- ========= ENHANCED CONFIGURATION =========
local RECORDING_FPS = 60
local MAX_FRAMES = 30000
local MIN_DISTANCE_THRESHOLD = 0.01
local RESUME_DISTANCE = 15
local CATCHUP_SPEED_MULTIPLIER = 1.3

-- ========= ENHANCED MOVEMENT CONFIG =========
local SMOOTH_PLAYBACK = true
local SMART_RESUME = true

-- ========= VARIABLES =========
local IsRecording = false
local IsPlaying = false
local IsPaused = false
local CurrentSpeed = 1
local CurrentWalkSpeed = 16
local RecordedMovements = {}
local RecordingOrder = {}
local CurrentRecording = {Frames = {}, StartTime = 0, Name = ""}
local SelectedReplays = {}

local AutoRespawn = false
local InfiniteJump = false
local AutoLoop = false
local recordConnection = nil
local playbackConnection = nil
local loopConnection = nil
local jumpConnection = nil
local lastRecordTime = 0
local lastRecordPos = nil
local checkpointNames = {}
local PathVisualization = {}
local ShowPaths = false
local CurrentPauseMarker = nil

-- ========= PERFECT SYNC CONTROL =========
local IsAutoLoopPlaying = false
local CurrentLoopIndex = 1
local CurrentReplayAttempts = 0
local MAX_REPLAY_ATTEMPTS = 2
local IsRespawning = false

-- ========= STATE PRESERVATION =========
local playbackStartTime = 0
local totalPausedDuration = 0
local pauseStartTime = 0
local currentPlaybackFrame = 1
local prePauseHumanoidState = nil
local prePauseWalkSpeed = 16
local prePauseAutoRotate = true
local prePauseJumpPower = 50

-- ========= MEMORY MANAGEMENT =========
local activeConnections = {}

local function AddConnection(connection)
    table.insert(activeConnections, connection)
end

local function CleanupAllConnections()
    for _, conn in ipairs(activeConnections) do
        if conn and typeof(conn) == "RBXScriptConnection" then
            pcall(function() conn:Disconnect() end)
        end
    end
    activeConnections = {}
    
    local connections = {recordConnection, playbackConnection, loopConnection, jumpConnection}
    for _, conn in pairs(connections) do
        if conn then
            pcall(function() conn:Disconnect() end)
        end
    end
    
    recordConnection = nil
    playbackConnection = nil
    loopConnection = nil
    jumpConnection = nil
end

-- ========= ENHANCED FRAME DATA SYSTEM =========
local function CreateFrameData()
    local char = player.Character
    if not char then return nil end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return nil end
    
    -- Get current state
    local currentState = humanoid:GetState()
    local stateName = tostring(currentState):gsub("Enum.HumanoidStateType.", "")
    
    -- Get velocity
    local velocity = hrp.AssemblyLinearVelocity
    local moveDirection = humanoid.MoveDirection
    
    -- Get floor information
    local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
    local floorNormal = Vector3.new(0, 1, 0)
    
    -- Try to get more accurate floor normal
    if grounded then
        local rayOrigin = hrp.Position
        local rayDirection = Vector3.new(0, -5, 0)
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.FilterDescendantsInstances = {char}
        
        local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
        if raycastResult then
            floorNormal = raycastResult.Normal
        end
    end
    
    return {
        t = tick(), -- timestamp
        p = {hrp.Position.X, hrp.Position.Y, hrp.Position.Z}, -- position
        lv = {hrp.CFrame.LookVector.X, hrp.CFrame.LookVector.Y, hrp.CFrame.LookVector.Z}, -- look vector
        up = {hrp.CFrame.UpVector.X, hrp.CFrame.UpVector.Y, hrp.CFrame.UpVector.Z}, -- up vector
        vel = {velocity.X, velocity.Y, velocity.Z}, -- velocity
        ws = humanoid.WalkSpeed, -- walk speed
        state = stateName, -- humanoid state
        md = {moveDirection.X, moveDirection.Y, moveDirection.Z}, -- move direction
        autoRotate = humanoid.AutoRotate,
        platformStand = humanoid.PlatformStand,
        jump = humanoid.Jump, -- jump state (edge trigger)
        grounded = grounded,
        floorNormal = {floorNormal.X, floorNormal.Y, floorNormal.Z},
        dt = 0 -- delta time (will be set during recording)
    }
end

local function GetFrameCFrame(frame)
    local position = Vector3.new(frame.p[1], frame.p[2], frame.p[3])
    local lookVector = Vector3.new(frame.lv[1], frame.lv[2], frame.lv[3])
    local upVector = Vector3.new(frame.up[1], frame.up[2], frame.up[3])
    
    return CFrame.fromMatrix(position, lookVector:Cross(upVector), upVector, lookVector)
end

local function GetFramePosition(frame)
    return Vector3.new(frame.p[1], frame.p[2], frame.p[3])
end

local function ApplyFrameData(frame, humanoid, hrp)
    if not frame or not humanoid or not hrp then return end
    
    pcall(function()
        -- Apply CFrame first
        hrp.CFrame = GetFrameCFrame(frame)
        
        -- Apply humanoid properties
        humanoid.WalkSpeed = frame.ws * CurrentSpeed
        humanoid.AutoRotate = frame.autoRotate
        humanoid.PlatformStand = frame.platformStand
        
        -- Apply jump (edge trigger)
        if frame.jump and not humanoid.Jump then
            humanoid.Jump = true
        elseif not frame.jump and humanoid.Jump then
            humanoid.Jump = false
        end
        
        -- Apply velocity if available
        if frame.vel then
            hrp.AssemblyLinearVelocity = Vector3.new(frame.vel[1], frame.vel[2], frame.vel[3])
        end
        
        -- Try to apply humanoid state
        local stateEnum = Enum.HumanoidStateType[frame.state]
        if stateEnum then
            humanoid:ChangeState(stateEnum)
        end
    end)
end

-- ========= ENHANCED CHARACTER MANAGEMENT =========
local function ResetCharacter()
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.Health = 0
        end
    end
end

local function WaitForRespawn()
    local startTime = tick()
    local timeout = 10
    
    repeat
        task.wait(0.1)
        if tick() - startTime > timeout then
            warn("⚠️ Respawn timeout!")
            return false
        end
    until player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChildOfClass("Humanoid") and player.Character.Humanoid.Health > 0
    
    task.wait(1) -- Extra stabilization time
    return true
end

local function IsCharacterReady()
    local char = player.Character
    if not char then return false end
    if not char:FindFirstChild("HumanoidRootPart") then return false end
    if not char:FindFirstChildOfClass("Humanoid") then return false end
    if char.Humanoid.Health <= 0 then return false end
    return true
end

local function CompleteCharacterReset(char)
    if not char or not char:IsDescendantOf(workspace) then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then return end
    pcall(function()
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
        humanoid.WalkSpeed = CurrentWalkSpeed
        humanoid.JumpPower = prePauseJumpPower or 50
        humanoid.Jump = false
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end)
end

-- ========= STATE MANAGEMENT SYSTEM =========
local function SaveHumanoidState()
    local char = player.Character
    if not char then return end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        prePauseAutoRotate = humanoid.AutoRotate
        prePauseWalkSpeed = humanoid.WalkSpeed
        prePauseJumpPower = humanoid.JumpPower
        prePauseHumanoidState = humanoid:GetState()
    end
end

local function RestoreFullUserControl()
    local char = player.Character
    if not char then return end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
    if humanoid then
        humanoid.AutoRotate = true
        humanoid.WalkSpeed = CurrentWalkSpeed
        humanoid.JumpPower = prePauseJumpPower or 50
        humanoid.PlatformStand = false
        humanoid.Jump = false
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end
    
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end
end

-- ========= SMART RESUME SYSTEM =========
local function FindNearestResumeFrame(recording, currentPos)
    if not recording or #recording == 0 then return 1 end
    
    local nearestFrame = 1
    local minDistance = math.huge
    
    for i = 1, math.min(#recording, 5000), 5 do
        local framePos = GetFramePosition(recording[i])
        local distance = (currentPos - framePos).Magnitude
        
        if distance < minDistance and distance < RESUME_DISTANCE then
            minDistance = distance
            nearestFrame = i
        end
    end
    
    if minDistance >= RESUME_DISTANCE then
        return 1
    end
    
    return nearestFrame
end

-- ========= ENHANCED AUTO LOOP SYSTEM =========
local function PlaySingleRecording(recordingName)
    local recording = RecordedMovements[recordingName]
    if not recording or #recording == 0 then 
        return false 
    end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then 
        return false 
    end
    
    local hrp = char.HumanoidRootPart
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return false end
    
    -- Reset state sebelum playback
    pcall(function()
        humanoid.PlatformStand = false
        humanoid.AutoRotate = false
        humanoid.Sit = false
        humanoid.Jump = false
    end)
    
    local playbackStart = tick()
    local totalPaused = 0
    local pauseStart = 0
    local currentFrame = 1
    
    -- Smart Resume: Cari frame terdekat
    if SMART_RESUME then
        local nearest = FindNearestResumeFrame(recording, hrp.Position)
        currentFrame = math.max(1, nearest - 10)
    end
    
    local completed = false
    local failed = false
    
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if not AutoLoop or not IsAutoLoopPlaying then
            connection:Disconnect()
            return
        end
        
        -- Pause handling
        if IsPaused then
            if pauseStart == 0 then
                pauseStart = tick()
            end
            return
        else
            if pauseStart > 0 then
                totalPaused = totalPaused + (tick() - pauseStart)
                pauseStart = 0
            end
        end
        
        -- Character check
        if not char or not char.Parent or not hrp or not humanoid or humanoid.Health <= 0 then
            failed = true
            connection:Disconnect()
            return
        end
        
        -- Frame calculation
        local currentTime = tick()
        local effectiveTime = (currentTime - playbackStart - totalPaused) * CurrentSpeed
        
        local targetFrame = 1
        local accumulated = 0
        
        for i = currentFrame, math.min(currentFrame + 100, #recording) do
            accumulated = accumulated + recording[i].dt
            if accumulated >= effectiveTime then
                targetFrame = i
                break
            end
        end
        
        currentFrame = targetFrame
        
        -- End condition
        if currentFrame >= #recording then
            completed = true
            connection:Disconnect()
            return
        end
        
        local frame = recording[currentFrame]
        if not frame then return end

        -- Apply enhanced frame data
        ApplyFrameData(frame, humanoid, hrp)
    end)
    
    -- Wait for completion
    local startWait = tick()
    while AutoLoop and IsAutoLoopPlaying and not completed and not failed do
        if tick() - startWait > (#recording * 2) + 5 then
            break
        end
        task.wait(0.05)
    end
    
    if connection then
        connection:Disconnect()
    end
    
    return completed, failed
end

local function StartAutoLoopAll()
    if IsAutoLoopPlaying then return end
    if not AutoLoop then return end
    
    if #RecordingOrder == 0 then
        PlaySound("Error")
        return
    end
    
    -- Cleanup sebelum memulai
    CleanupAllConnections()
    
    PlaySound("Play")
    
    CurrentLoopIndex = 1
    IsAutoLoopPlaying = true
    CurrentReplayAttempts = 0
    
    -- Gunakan task.spawn untuk memisahkan thread
    task.spawn(function()
        while AutoLoop and IsAutoLoopPlaying do
            if CurrentLoopIndex > #RecordingOrder then
                CurrentLoopIndex = 1
            end
            
            local recordingName = RecordingOrder[CurrentLoopIndex]
            
            -- Character ready check
            local charReady = false
            for i = 1, 3 do
                if IsCharacterReady() then
                    charReady = true
                    break
                end
                task.wait(0.5)
            end
            
            if not charReady then
                if AutoRespawn then
                    ResetCharacter()
                    task.wait(2)
                else
                    CurrentLoopIndex = CurrentLoopIndex + 1
                    task.wait(0.5)
                    continue
                end
            end
            
            -- Perfect Sync: Reset hanya di loop pertama dengan AutoRespawn
            local shouldReset = false
            if AutoRespawn and CurrentLoopIndex == 1 then
                shouldReset = true
            end
            
            if shouldReset then
                print("🔄 Resetting character for new loop")
                ResetCharacter()
                local success = WaitForRespawn()
                if not success then
                    print("❌ Respawn failed! Stopping loop.")
                    AutoLoop = false
                    IsAutoLoopPlaying = false
                    AnimateLoop(false)
                    break
                end
                
                print("⏳ Waiting for character to fully load...")
                task.wait(1.5)
            end
            
            -- Tunggu karakter ready untuk kasus mati tanpa auto respawn
            if not IsCharacterReady() then
                print("💀 Character died, waiting for respawn...")
                local maxWaitTime = 15
                local startWait = tick()
                
                while not IsCharacterReady() and AutoLoop and IsAutoLoopPlaying do
                    if tick() - startWait > maxWaitTime then
                        print("❌ Respawn timeout! Stopping loop.")
                        AutoLoop = false
                        IsAutoLoopPlaying = false
                        AnimateLoop(false)
                        break
                    end
                    task.wait(0.5)
                end
                
                if not AutoLoop or not IsAutoLoopPlaying then break end
                
                print("⏳ Character respawned, waiting to stabilize...")
                task.wait(1.0)
            end
            
            if not AutoLoop or not IsAutoLoopPlaying then break end
            
            -- Main playback
            local success, failed = PlaySingleRecording(recordingName)
            
            if not AutoLoop or not IsAutoLoopPlaying then break end
            
            -- Handle result
            if success then
                CurrentLoopIndex = CurrentLoopIndex + 1
                CurrentReplayAttempts = 0
            elseif failed then
                CurrentReplayAttempts = CurrentReplayAttempts + 1
                if CurrentReplayAttempts >= 2 then
                    CurrentLoopIndex = CurrentLoopIndex + 1
                    CurrentReplayAttempts = 0
                end
            else
                CurrentLoopIndex = CurrentLoopIndex + 1
            end
            
            -- Delay antar recordings
            local delayEnd = tick() + 0.8
            while tick() < delayEnd do
                if not AutoLoop or not IsAutoLoopPlaying then break end
                task.wait(0.1)
            end
        end
        
        IsAutoLoopPlaying = false
        CleanupAllConnections()
        RestoreFullUserControl()
    end)
end

local function StopAutoLoopAll()
    AutoLoop = false
    IsAutoLoopPlaying = false
    IsPlaying = false
    IsPaused = false
    
    if loopConnection then
        task.cancel(loopConnection)
        loopConnection = nil
    end
    
    RestoreFullUserControl()
    
    local char = player.Character
    if char then CompleteCharacterReset(char) end
    
    PlaySound("Stop")
end

-- ========= ENHANCED PLAYBACK SYSTEM =========
local function PlayEnhancedRecording(recording, startFrame, replayName)
    if not recording or #recording == 0 then return end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    local currentFrame = startFrame or 1
    playbackStartTime = tick()
    totalPausedDuration = 0
    pauseStartTime = 0

    -- Smart Resume
    if SMART_RESUME and startFrame == 1 then
        local nearestFrame = FindNearestResumeFrame(recording, hrp.Position)
        if nearestFrame > 1 then
            currentFrame = nearestFrame
        end
    end

    SaveHumanoidState()

    playbackConnection = RunService.Heartbeat:Connect(function()
        if not IsPlaying then
            playbackConnection:Disconnect()
            RestoreFullUserControl()
            return
        end
        
        if IsPaused then
            if pauseStartTime == 0 then
                pauseStartTime = tick()
                RestoreFullUserControl()
            end
            return
        else
            if pauseStartTime > 0 then
                totalPausedDuration = totalPausedDuration + (tick() - pauseStartTime)
                pauseStartTime = 0
            end
        end

        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            IsPlaying = false
            playbackConnection:Disconnect()
            RestoreFullUserControl()
            return
        end

        hrp = char:FindFirstChild("HumanoidRootPart")
        humanoid = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not humanoid then
            IsPlaying = false
            playbackConnection:Disconnect()
            RestoreFullUserControl()
            return
        end

        local currentTime = tick()
        local effectiveTime = (currentTime - playbackStartTime - totalPausedDuration) * CurrentSpeed
        
        local targetFrame = 1
        local accumulatedTime = 0
        
        for i = 1, #recording do
            accumulatedTime = accumulatedTime + recording[i].dt
            if accumulatedTime >= effectiveTime then
                targetFrame = i
                break
            end
        end
        
        currentFrame = targetFrame

        if currentFrame >= #recording then
            IsPlaying = false
            IsPaused = false
            RestoreFullUserControl()
            playbackConnection:Disconnect()
            PlaySound("Stop")
            return
        end

        local frame = recording[currentFrame]
        if not frame then return end

        ApplyFrameData(frame, humanoid, hrp)
        currentPlaybackFrame = currentFrame
    end)
    
    AddConnection(playbackConnection)
end

-- ========= ENHANCED RECORDING SYSTEM =========
function StartRecording()
    if IsRecording then return end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        PlaySound("Error")
        return
    end
    
    IsRecording = true
    CurrentRecording = {Frames = {}, StartTime = tick(), Name = "recording_" .. os.date("%H%M%S")}
    lastRecordTime = tick()
    lastRecordPos = nil
    
    RecordBtnBig.Text = "STOP RECORDING"
    RecordBtnBig.BackgroundColor3 = Color3.fromRGB(163, 10, 10)
    
    PlaySound("RecordStart")
    
    recordConnection = RunService.Heartbeat:Connect(function()
        if not IsRecording then return end
        
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") or #CurrentRecording.Frames >= MAX_FRAMES then
            StopRecording()
            return
        end
        
        local currentTime = tick()
        local deltaTime = currentTime - lastRecordTime
        
        if deltaTime >= (1 / RECORDING_FPS) then
            local hrp = char.HumanoidRootPart
            local currentPos = hrp.Position
            
            if lastRecordPos and (currentPos - lastRecordPos).Magnitude < MIN_DISTANCE_THRESHOLD then
                lastRecordTime = currentTime
                return
            end
            
            local frameData = CreateFrameData()
            if frameData then
                frameData.dt = deltaTime
                table.insert(CurrentRecording.Frames, frameData)
                lastRecordTime = currentTime
                lastRecordPos = currentPos
                
                FrameLabel.Text = string.format("Frames: %d", #CurrentRecording.Frames)
            end
        end
    end)
    
    AddConnection(recordConnection)
end

function StopRecording()
    if not IsRecording then return end
    IsRecording = false
    
    if recordConnection then
        recordConnection:Disconnect()
        recordConnection = nil
    end
    
    if #CurrentRecording.Frames > 0 then
        AutoSaveRecording()
    end
    
    RecordBtnBig.Text = "RECORDING"
    RecordBtnBig.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
    
    PlaySound("RecordStop")
    FrameLabel.Text = "Frames: 0"
end

-- ========= PAUSE/RESUME SYSTEM =========
function PausePlayback()
    if not IsPlaying and not IsAutoLoopPlaying then return end
    
    IsPaused = not IsPaused
    
    if IsPaused then
        PauseBtnBig.Text = "RESUME"
        PauseBtnBig.BackgroundColor3 = Color3.fromRGB(8, 181, 116)
        RestoreFullUserControl()
        PlaySound("Click")
    else
        PauseBtnBig.Text = "PAUSE"
        PauseBtnBig.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
        SaveHumanoidState()
        PlaySound("Click")
    end
end

function StopPlayback()
    if AutoLoop then
        StopAutoLoopAll()
        AnimateLoop(false)
    end
    
    if not IsPlaying then return end
    IsPlaying = false
    IsPaused = false
    
    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end
    
    RestoreFullUserControl()
    
    local char = player.Character
    if char then CompleteCharacterReset(char) end
    
    PlaySound("Stop")
end

-- ========= SOUND EFFECTS =========
local SoundEffects = {
    Click = "rbxassetid://4499400560",
    Toggle = "rbxassetid://7468131335", 
    RecordStart = "rbxassetid://4499400560",
    RecordStop = "rbxassetid://4499400560",
    Play = "rbxassetid://4499400560",
    Stop = "rbxassetid://4499400560",
    Error = "rbxassetid://7772283448",
    Success = "rbxassetid://2865227271"
}

local function PlaySound(soundType)
    pcall(function()
        local sound = Instance.new("Sound")
        sound.SoundId = SoundEffects[soundType] or SoundEffects.Click
        sound.Volume = 0.3
        sound.Parent = workspace
        sound:Play()
        game:GetService("Debris"):AddItem(sound, 2)
    end)
end

-- ========= GUI SETUP =========
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoWalkByaruL"
ScreenGui.ResetOnSpawn = false

if syn and syn.protect_gui then
    syn.protect_gui(ScreenGui)
    ScreenGui.Parent = game:GetService("CoreGui")
elseif gethui then
    ScreenGui.Parent = gethui()
elseif game:GetService("CoreGui"):FindFirstChild("RobloxGui") then
    ScreenGui.Parent = game:GetService("CoreGui")
else
    ScreenGui.Parent = player:WaitForChild("PlayerGui")
end

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.fromOffset(250, 350) 
MainFrame.Position = UDim2.new(0.5, -125, 0.5, -225)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 32)
Header.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 12)
HeaderCorner.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 1, 0)
Title.BackgroundTransparency = 1
Title.Text = "ByaruL v6.0 - ENHANCED DATA"
Title.TextColor3 = Color3.fromRGB(255,255,255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Center
Title.Parent = Header

local FrameLabel = Instance.new("TextLabel")
FrameLabel.Size = UDim2.new(0, 70, 1, 0)
FrameLabel.Position = UDim2.new(0, 5, 0, 0)
FrameLabel.BackgroundTransparency = 1
FrameLabel.Text = "Frame: 0"
FrameLabel.TextColor3 = Color3.fromRGB(255,255,255)
FrameLabel.Font = Enum.Font.GothamBold
FrameLabel.TextSize = 9
FrameLabel.Parent = Header

local HideButton = Instance.new("TextButton")
HideButton.Size = UDim2.fromOffset(25, 25)
HideButton.Position = UDim2.new(1, -60, 0.5, -12)
HideButton.BackgroundColor3 = Color3.fromRGB(162, 175, 170)
HideButton.Text = "_"
HideButton.TextColor3 = Color3.new(1, 1, 1)
HideButton.Font = Enum.Font.GothamBold
HideButton.TextSize = 14
HideButton.Parent = Header

local HideCorner = Instance.new("UICorner")
HideCorner.CornerRadius = UDim.new(0, 6)
HideCorner.Parent = HideButton

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.fromOffset(25, 25)
CloseButton.Position = UDim2.new(1, -30, 0.5, -12)
CloseButton.BackgroundColor3 = Color3.fromRGB(230, 62, 62)
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.new(1, 1, 1)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 12
CloseButton.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseButton

local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, -10, 1, -42)
Content.Position = UDim2.new(0, 5, 0, 36)
Content.BackgroundTransparency = 1
Content.ScrollBarThickness = 6
Content.ScrollBarImageColor3 = Color3.fromRGB(80, 120, 255)
Content.ScrollingDirection = Enum.ScrollingDirection.Y
Content.VerticalScrollBarInset = Enum.ScrollBarInset.Always
Content.CanvasSize = UDim2.new(0, 0, 0, 800)
Content.Parent = MainFrame

local MiniButton = Instance.new("TextButton")
MiniButton.Size = UDim2.fromOffset(40, 40)
MiniButton.Position = UDim2.new(0.5, -22.5, 0, -30)
MiniButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MiniButton.Text = "⚙️"
MiniButton.TextColor3 = Color3.new(1, 1, 1)
MiniButton.Font = Enum.Font.GothamBold
MiniButton.TextSize = 25
MiniButton.Visible = false
MiniButton.Active = true
MiniButton.Draggable = true
MiniButton.Parent = ScreenGui

local MiniCorner = Instance.new("UICorner")
MiniCorner.CornerRadius = UDim.new(0, 8)
MiniCorner.Parent = MiniButton

-- Enhanced Button Creation
local function CreateButton(text, x, y, w, h, color, parent)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(w, h)
    btn.Position = UDim2.fromOffset(x, y)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 9
    btn.AutoButtonColor = false
    btn.Parent = parent or Content
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0,0,0)
    stroke.Thickness = 1.0
    stroke.Transparency = 0.0
    stroke.Parent = btn
    
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.new(
                math.min(color.R * 1.2, 1),
                math.min(color.G * 1.2, 1),
                math.min(color.B * 1.2, 1)
            )
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), {
            Transparency = 0.3
        }):Play()
    end)
    
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = color
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), {
            Transparency = 0.7
        }):Play()
    end)
    
    return btn
end

local function CreateToggle(text, x, y, w, h, default)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(w, h)
    btn.Position = UDim2.fromOffset(x, y)
    btn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    btn.Text = ""
    btn.Parent = Content
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = btn
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, w - 28, 1, 0)
    label.Position = UDim2.new(0, 4, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 220)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 7
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = btn
    
    local toggle = Instance.new("Frame")
    toggle.Size = UDim2.fromOffset(22, 12)
    toggle.Position = UDim2.new(1, -25, 0.5, -6)
    toggle.BackgroundColor3 = default and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(50, 50, 50)
    toggle.BorderSizePixel = 0
    toggle.Parent = btn
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(1, 0)
    toggleCorner.Parent = toggle
    
    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(8, 8)
    knob.Position = default and UDim2.new(0, 12, 0, 2) or UDim2.new(0, 2, 0, 2)
    knob.BackgroundColor3 = Color3.fromRGB(220, 220, 230)
    knob.BorderSizePixel = 0
    knob.Parent = toggle
    
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob
    
    local function Animate(isOn)
        PlaySound("Toggle")
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local bgColor = isOn and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(50, 50, 50)
        local knobPos = isOn and UDim2.new(0, 12, 0, 2) or UDim2.new(0, 2, 0, 2)
        TweenService:Create(toggle, tweenInfo, {BackgroundColor3 = bgColor}):Play()
        TweenService:Create(knob, tweenInfo, {Position = knobPos}):Play()
    end
    
    return btn, Animate
end

-- ========= UI ELEMENTS =========
local RecordBtnBig = CreateButton("RECORDING", 5, 5, 117, 30, Color3.fromRGB(59, 15, 116))
local PlayBtnBig = CreateButton("PLAY", 5, 40, 75, 30, Color3.fromRGB(59, 15, 116))
local StopBtnBig = CreateButton("STOP", 85, 40, 75, 30, Color3.fromRGB(59, 15, 116))
local PauseBtnBig = CreateButton("PAUSE", 165, 40, 75, 30, Color3.fromRGB(59, 15, 116))

-- TOGGLE LAYOUT
local LoopBtn, AnimateLoop = CreateToggle("Auto Loop", 0, 75, 78, 22, false)
local JumpBtn, AnimateJump = CreateToggle("Infinite Jump", 82, 75, 78, 22, false)
local RespawnBtn, AnimateRespawn = CreateToggle("Auto Respawn", 164, 75, 78, 22, false)

-- SMART FEATURES TOGGLE
local SmartResumeBtn, AnimateSmartResume = CreateToggle("Smart Resume", 0, 100, 117, 22, true)

-- ========= TEXTBOX LAYOUT =========
local SpeedBox = Instance.new("TextBox")
SpeedBox.Size = UDim2.fromOffset(55, 26)
SpeedBox.Position = UDim2.fromOffset(5, 127)
SpeedBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
SpeedBox.BorderSizePixel = 0
SpeedBox.Text = "1.00"
SpeedBox.PlaceholderText = "Speed..."
SpeedBox.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedBox.Font = Enum.Font.GothamBold
SpeedBox.TextSize = 11
SpeedBox.TextXAlignment = Enum.TextXAlignment.Center
SpeedBox.ClearTextOnFocus = false
SpeedBox.Parent = Content

local SpeedCorner = Instance.new("UICorner")
SpeedCorner.CornerRadius = UDim.new(0, 6)
SpeedCorner.Parent = SpeedBox

local FilenameBox = Instance.new("TextBox")
FilenameBox.Size = UDim2.fromOffset(110, 26)
FilenameBox.Position = UDim2.fromOffset(65, 127)
FilenameBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
FilenameBox.BorderSizePixel = 0
FilenameBox.Text = ""
FilenameBox.PlaceholderText = "Custom File..."
FilenameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
FilenameBox.Font = Enum.Font.GothamBold
FilenameBox.TextSize = 11
FilenameBox.TextXAlignment = Enum.TextXAlignment.Center
FilenameBox.ClearTextOnFocus = false
FilenameBox.Parent = Content

local FilenameCorner = Instance.new("UICorner")
FilenameCorner.CornerRadius = UDim.new(0, 6)
FilenameCorner.Parent = FilenameBox

local WalkSpeedBox = Instance.new("TextBox")
WalkSpeedBox.Size = UDim2.fromOffset(55, 26)
WalkSpeedBox.Position = UDim2.fromOffset(180, 127)
WalkSpeedBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
WalkSpeedBox.BorderSizePixel = 0
WalkSpeedBox.Text = "16"
WalkSpeedBox.PlaceholderText = "8-200"
WalkSpeedBox.TextColor3 = Color3.fromRGB(255, 255, 255)
WalkSpeedBox.Font = Enum.Font.GothamBold
WalkSpeedBox.TextSize = 11
WalkSpeedBox.TextXAlignment = Enum.TextXAlignment.Center
WalkSpeedBox.ClearTextOnFocus = false
WalkSpeedBox.Parent = Content

local WalkSpeedCorner = Instance.new("UICorner")
WalkSpeedCorner.CornerRadius = UDim.new(0, 6)
WalkSpeedCorner.Parent = WalkSpeedBox

local SaveFileBtn = CreateButton("SAVE FILE", 0, 158, 117, 26, Color3.fromRGB(59, 15, 116))
local LoadFileBtn = CreateButton("LOAD FILE", 123, 158, 117, 26, Color3.fromRGB(59, 15, 116))

local PathToggleBtn = CreateButton("SHOW RUTE", 0, 189, 117, 26, Color3.fromRGB(59, 15, 116))
local MergeBtn = CreateButton("MERGE", 123, 189, 117, 26, Color3.fromRGB(59, 15, 116))

-- Record List
local RecordList = Instance.new("ScrollingFrame")
RecordList.Size = UDim2.new(1, 0, 0, 120)
RecordList.Position = UDim2.fromOffset(0, 220)
RecordList.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
RecordList.BorderSizePixel = 0
RecordList.ScrollBarThickness = 6
RecordList.ScrollBarImageColor3 = Color3.fromRGB(80, 120, 255)
RecordList.ScrollingDirection = Enum.ScrollingDirection.Y
RecordList.VerticalScrollBarInset = Enum.ScrollBarInset.Always
RecordList.CanvasSize = UDim2.new(0, 0, 0, 0)
RecordList.Parent = Content

local ListCorner = Instance.new("UICorner")
ListCorner.CornerRadius = UDim.new(0, 6)
ListCorner.Parent = RecordList

-- Speed validation function
local function ValidateSpeed(speedText)
    local speed = tonumber(speedText)
    if not speed then return false, "Invalid number" end
    if speed < 0.25 or speed > 30 then return false, "Speed must be between 0.25 and 30" end
    local roundedSpeed = math.floor((speed * 4) + 0.5) / 4
    return true, roundedSpeed
end

SpeedBox.FocusLost:Connect(function()
    local success, result = ValidateSpeed(SpeedBox.Text)
    if success then
        CurrentSpeed = result
        SpeedBox.Text = string.format("%.2f", result)
        PlaySound("Success")
    else
        SpeedBox.Text = string.format("%.2f", CurrentSpeed)
        PlaySound("Error")
    end
end)

-- WalkSpeed validation function
local function ValidateWalkSpeed(walkSpeedText)
    local walkSpeed = tonumber(walkSpeedText)
    if not walkSpeed then return false, "Invalid number" end
    if walkSpeed < 8 or walkSpeed > 200 then return false, "WalkSpeed must be between 8 and 200" end
    return true, walkSpeed
end

WalkSpeedBox.FocusLost:Connect(function()
    local success, result = ValidateWalkSpeed(WalkSpeedBox.Text)
    if success then
        CurrentWalkSpeed = result
        WalkSpeedBox.Text = tostring(result)
        
        local char = player.Character
        if char and char:FindFirstChildOfClass("Humanoid") then
            char.Humanoid.WalkSpeed = CurrentWalkSpeed
        end
        
        PlaySound("Success")
    else
        WalkSpeedBox.Text = tostring(CurrentWalkSpeed)
        PlaySound("Error")
    end
end)

-- ========= BUTTON EVENTS =========
RecordBtnBig.MouseButton1Click:Connect(function()
    if IsRecording then StopRecording() else StartRecording() end
end)

PlayBtnBig.MouseButton1Click:Connect(function()
    if AutoLoop then return end
    PlayRecording()
end)

StopBtnBig.MouseButton1Click:Connect(function()
    StopPlayback()
end)

PauseBtnBig.MouseButton1Click:Connect(function()
    PausePlayback()
end)

LoopBtn.MouseButton1Click:Connect(function()
    AutoLoop = not AutoLoop
    AnimateLoop(AutoLoop)
    
    if AutoLoop then
        if not next(RecordedMovements) then
            AutoLoop = false
            AnimateLoop(false)
            PlaySound("Error")
            return
        end
        
        if IsPlaying then
            IsPlaying = false
            IsPaused = false
            RestoreFullUserControl()
        end
        
        PlaySound("Play")
        StartAutoLoopAll()
    else
        StopAutoLoopAll()
    end
end)

RespawnBtn.MouseButton1Click:Connect(function()
    AutoRespawn = not AutoRespawn
    AnimateRespawn(AutoRespawn)
    PlaySound("Toggle")
end)

JumpBtn.MouseButton1Click:Connect(function()
    InfiniteJump = not InfiniteJump
    AnimateJump(InfiniteJump)
    
    if InfiniteJump then
        EnableInfiniteJump()
    else
        DisableInfiniteJump()
    end
    PlaySound("Toggle")
end)

SmartResumeBtn.MouseButton1Click:Connect(function()
    SMART_RESUME = not SMART_RESUME
    AnimateSmartResume(SMART_RESUME)
    PlaySound("Toggle")
end)

SaveFileBtn.MouseButton1Click:Connect(function()
    SaveToJSON()
end)

LoadFileBtn.MouseButton1Click:Connect(function()
    LoadFromJSON()
end)

PathToggleBtn.MouseButton1Click:Connect(function()
    ShowPaths = not ShowPaths
    if ShowPaths then
        PathToggleBtn.Text = "HIDE RUTE"
        VisualizeAllPaths()
    else
        PathToggleBtn.Text = "SHOW RUTE"
        ClearPathVisualization()
    end
end)

MergeBtn.MouseButton1Click:Connect(function()
    CreateMergedReplay()
end)

HideButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    MiniButton.Visible = true
end)

MiniButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    MiniButton.Visible = false
end)

CloseButton.MouseButton1Click:Connect(function()
    if IsRecording then StopRecording() end
    if IsPlaying or AutoLoop then StopPlayback() end
    if InfiniteJump then DisableInfiniteJump() end
    CleanupAllConnections()
    ClearPathVisualization()
    ScreenGui:Destroy()
end)

-- ========= INFINITE JUMP SYSTEM =========
local function EnableInfiniteJump()
    if jumpConnection then return end
    
    jumpConnection = UserInputService.JumpRequest:Connect(function()
        if InfiniteJump and player.Character then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end)
    
    AddConnection(jumpConnection)
end

local function DisableInfiniteJump()
    if jumpConnection then
        jumpConnection:Disconnect()
        jumpConnection = nil
    end
end

-- ========= PATH VISUALIZATION FUNCTIONS =========
local function ClearPathVisualization()
    for _, part in pairs(PathVisualization) do
        if part and part.Parent then
            part:Destroy()
        end
    end
    PathVisualization = {}
    
    if CurrentPauseMarker and CurrentPauseMarker.Parent then
        CurrentPauseMarker:Destroy()
        CurrentPauseMarker = nil
    end
end

local function CreatePathSegment(startPos, endPos, color)
    local part = Instance.new("Part")
    part.Name = "PathSegment"
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon
    part.BrickColor = color or BrickColor.new("Really black")
    part.Transparency = 0.2
    
    local distance = (startPos - endPos).Magnitude
    part.Size = Vector3.new(0.2, 0.2, distance)
    part.CFrame = CFrame.lookAt((startPos + endPos) / 2, endPos)
    
    part.Parent = workspace
    table.insert(PathVisualization, part)
    
    return part
end

local function VisualizeAllPaths()
    ClearPathVisualization()
    
    if not ShowPaths then return end
    
    for _, name in ipairs(RecordingOrder) do
        local recording = RecordedMovements[name]
        if not recording or #recording < 2 then continue end
        
        local previousPos = Vector3.new(
            recording[1].p[1],
            recording[1].p[2], 
            recording[1].p[3]
        )
        
        for i = 2, #recording, 3 do
            local frame = recording[i]
            local currentPos = Vector3.new(frame.p[1], frame.p[2], frame.p[3])
            
            if (currentPos - previousPos).Magnitude > 0.5 then
                CreatePathSegment(previousPos, currentPos)
                previousPos = currentPos
            end
        end
    end
end

-- ========= AUTOMATIC SAVE SYSTEM =========
local function AutoSaveRecording()
    if #CurrentRecording.Frames == 0 then
        PlaySound("Error")
        return
    end
    
    local name = CurrentRecording.Name
    RecordedMovements[name] = CurrentRecording.Frames
    table.insert(RecordingOrder, name)
    checkpointNames[name] = "checkpoint_" .. #RecordingOrder
    SelectedReplays[name] = false
    
    UpdateRecordList()
    
    PlaySound("Success")
    
    CurrentRecording = {Frames = {}, StartTime = 0, Name = "recording_" .. os.date("%H%M%S")}
end

-- ========= ENHANCED PLAYBACK =========
function PlayRecording(name)
    if IsPlaying then return end
    
    local recording = name and RecordedMovements[name] or (RecordingOrder[1] and RecordedMovements[RecordingOrder[1]])
    if not recording or #recording == 0 then
        PlaySound("Error")
        return
    end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        PlaySound("Error")
        return
    end

    IsPlaying = true
    IsPaused = false
    totalPausedDuration = 0
    pauseStartTime = 0

    currentPlaybackFrame = 1
    playbackStartTime = tick()

    SaveHumanoidState()
    PlaySound("Play")

    PlayEnhancedRecording(recording, currentPlaybackFrame, name)
end

-- ========= ENHANCED SAVE/LOAD SYSTEM =========
local function SaveToJSON()
    local filename = FilenameBox.Text
    if filename == "" then filename = "MyReplays" end
    filename = filename .. ".json"
    
    if not next(RecordedMovements) then
        PlaySound("Error")
        return
    end
    
    local success, err = pcall(function()
        local saveData = {
            Version = "6.0-Enhanced",
            Checkpoints = {},
            RecordingOrder = RecordingOrder,
            CheckpointNames = checkpointNames
        }
        
        local hasSelected = false
        for name, isSelected in pairs(SelectedReplays) do
            if isSelected then
                hasSelected = true
                break
            end
        end
        
        for name, frames in pairs(RecordedMovements) do
            if not hasSelected or SelectedReplays[name] then
                local checkpointData = {
                    Name = name,
                    DisplayName = checkpointNames[name] or "checkpoint",
                    Frames = frames
                }
                table.insert(saveData.Checkpoints, checkpointData)
            end
        end
        
        local jsonString = HttpService:JSONEncode(saveData)
        
        if writefile then
            writefile(filename, jsonString)
            PlaySound("Success")
        else
            PlaySound("Error")
        end
    end)
    
    if not success then
        PlaySound("Error")
    end
end

local function LoadFromJSON()
    local filename = FilenameBox.Text
    if filename == "" then filename = "MyReplays" end
    filename = filename .. ".json"
    
    local success, err = pcall(function()
        if not readfile or not isfile then
            PlaySound("Error")
            return
        end
        
        if not isfile(filename) then
            PlaySound("Error")
            return
        end
        
        local jsonString = readfile(filename)
        local saveData = HttpService:JSONDecode(jsonString)
        
        RecordedMovements = {}
        RecordingOrder = saveData.RecordingOrder or {}
        checkpointNames = saveData.CheckpointNames or {}
        SelectedReplays = {}
        
        for _, checkpointData in ipairs(saveData.Checkpoints or {}) do
            local name = checkpointData.Name
            local frames = checkpointData.Frames
            
            if frames then
                RecordedMovements[name] = frames
                SelectedReplays[name] = false
            end
        end
        
        UpdateRecordList()
        PlaySound("Success")
    end)
    
    if not success then
        PlaySound("Error")
    end
end

-- ========= ENHANCED MERGE SYSTEM =========
local function CreateMergedReplay()
    if #RecordingOrder < 2 then
        PlaySound("Error")
        return
    end
    
    local mergedFrames = {}
    local totalTimeOffset = 0
    
    for _, checkpointName in ipairs(RecordingOrder) do
        local checkpoint = RecordedMovements[checkpointName]
        if not checkpoint then continue end
        
        for frameIndex, frame in ipairs(checkpoint) do
            local newFrame = {
                t = frame.t,
                p = {frame.p[1], frame.p[2], frame.p[3]},
                lv = {frame.lv[1], frame.lv[2], frame.lv[3]},
                up = {frame.up[1], frame.up[2], frame.up[3]},
                vel = frame.vel and {frame.vel[1], frame.vel[2], frame.vel[3]} or nil,
                ws = frame.ws,
                state = frame.state,
                md = frame.md and {frame.md[1], frame.md[2], frame.md[3]} or nil,
                autoRotate = frame.autoRotate,
                platformStand = frame.platformStand,
                jump = frame.jump,
                grounded = frame.grounded,
                floorNormal = frame.floorNormal and {frame.floorNormal[1], frame.floorNormal[2], frame.floorNormal[3]} or nil,
                dt = frame.dt
            }
            table.insert(mergedFrames, newFrame)
        end
        
        if #checkpoint > 0 then
            totalTimeOffset = totalTimeOffset + 0.1
        end
    end
    
    local mergedName = "merged_" .. os.date("%H%M%S")
    RecordedMovements[mergedName] = mergedFrames
    table.insert(RecordingOrder, mergedName)
    checkpointNames[mergedName] = "MERGED ALL"
    SelectedReplays[mergedName] = false
    
    UpdateRecordList()
    PlaySound("Success")
end

-- ========= REORDER FUNCTIONS =========
local function MoveRecordingUp(name)
    local currentIndex = table.find(RecordingOrder, name)
    if currentIndex and currentIndex > 1 then
        RecordingOrder[currentIndex] = RecordingOrder[currentIndex - 1]
        RecordingOrder[currentIndex - 1] = name
        UpdateRecordList()
    end
end

local function MoveRecordingDown(name)
    local currentIndex = table.find(RecordingOrder, name)
    if currentIndex and currentIndex < #RecordingOrder then
        RecordingOrder[currentIndex] = RecordingOrder[currentIndex + 1]
        RecordingOrder[currentIndex + 1] = name
        UpdateRecordList()
    end
end

-- ========= FORMAT DURATION FUNCTION =========
local function FormatDuration(seconds)
    local minutes = math.floor(seconds / 60)
    local remainingSeconds = math.floor(seconds % 60)
    return string.format("%d:%02d", minutes, remainingSeconds)
end

-- ========= UPDATED RECORD LIST =========
function UpdateRecordList()
    for _, child in pairs(RecordList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local yPos = 0
    for index, name in ipairs(RecordingOrder) do
        local rec = RecordedMovements[name]
        if not rec then continue end
        
        if SelectedReplays[name] == nil then
            SelectedReplays[name] = false
        end
        
        local item = Instance.new("Frame")
        item.Size = UDim2.new(1, -6, 0, 50)
        item.Position = UDim2.new(0, 3, 0, yPos)
        item.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        item.Parent = RecordList
    
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = item
        
        local actionRow = Instance.new("Frame")
        actionRow.Size = UDim2.new(1, 0, 0, 25)
        actionRow.BackgroundTransparency = 1
        actionRow.Parent = item
        
        local playBtn = Instance.new("TextButton")
        playBtn.Size = UDim2.fromOffset(25, 25)
        playBtn.Position = UDim2.fromOffset(5, 0)
        playBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
        playBtn.Text = "▶"
        playBtn.TextColor3 = Color3.new(1, 1, 1)
        playBtn.Font = Enum.Font.GothamBold
        playBtn.TextSize = 12
        playBtn.Parent = actionRow
        
        local playCorner = Instance.new("UICorner")
        playCorner.CornerRadius = UDim.new(0, 4)
        playCorner.Parent = playBtn
        
        local delBtn = Instance.new("TextButton")
        delBtn.Size = UDim2.fromOffset(25, 25)
        delBtn.Position = UDim2.fromOffset(35, 0)
        delBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
        delBtn.Text = "✕"
        delBtn.TextColor3 = Color3.new(1, 1, 1)
        delBtn.Font = Enum.Font.GothamBold
        delBtn.TextSize = 12
        delBtn.Parent = actionRow
        
        local delCorner = Instance.new("UICorner")
        delCorner.CornerRadius = UDim.new(0, 4)
        delCorner.Parent = delBtn
        
        local nameBox = Instance.new("TextBox")
        nameBox.Size = UDim2.new(0, 100, 0, 25)
        nameBox.Position = UDim2.fromOffset(65, 0)
        nameBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        nameBox.BorderSizePixel = 0
        nameBox.Text = checkpointNames[name] or "checkpoint_" .. index
        nameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameBox.Font = Enum.Font.GothamBold
        nameBox.TextSize = 10
        nameBox.TextXAlignment = Enum.TextXAlignment.Center
        nameBox.PlaceholderText = "Enter name..."
        nameBox.ClearTextOnFocus = false
        nameBox.Parent = actionRow
        
        local nameBoxCorner = Instance.new("UICorner")
        nameBoxCorner.CornerRadius = UDim.new(0, 4)
        nameBoxCorner.Parent = nameBox
        
        local upBtn = Instance.new("TextButton")
        upBtn.Size = UDim2.fromOffset(25, 25)
        upBtn.Position = UDim2.fromOffset(170, 0)
        upBtn.BackgroundColor3 = index > 1 and Color3.fromRGB(74, 195, 147) or Color3.fromRGB(30, 30, 30)
        upBtn.Text = "↑"
        upBtn.TextColor3 = Color3.new(1, 1, 1)
        upBtn.Font = Enum.Font.GothamBold
        upBtn.TextSize = 12
        upBtn.Parent = actionRow
        
        local upCorner = Instance.new("UICorner")
        upCorner.CornerRadius = UDim.new(0, 4)
        upCorner.Parent = upBtn
        
        local downBtn = Instance.new("TextButton")
        downBtn.Size = UDim2.fromOffset(25, 25)
        downBtn.Position = UDim2.fromOffset(200, 0)
        downBtn.BackgroundColor3 = index < #RecordingOrder and Color3.fromRGB(74, 195, 147) or Color3.fromRGB(30, 30, 30)
        downBtn.Text = "↓"
        downBtn.TextColor3 = Color3.new(1, 1, 1)
        downBtn.Font = Enum.Font.GothamBold
        downBtn.TextSize = 12
        downBtn.Parent = actionRow
        
        local downCorner = Instance.new("UICorner")
        downCorner.CornerRadius = UDim.new(0, 4)
        downCorner.Parent = downBtn
        
        local infoRow = Instance.new("Frame")
        infoRow.Size = UDim2.new(1, 0, 0, 20)
        infoRow.Position = UDim2.fromOffset(0, 30)
        infoRow.BackgroundTransparency = 1
        infoRow.Parent = item
        
        local checkbox = Instance.new("TextButton")
        checkbox.Size = UDim2.fromOffset(16, 16)
        checkbox.Position = UDim2.fromOffset(10, 2)
        checkbox.BackgroundColor3 = SelectedReplays[name] and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(40, 40, 50)
        checkbox.Text = SelectedReplays[name] and "✓" or ""
        checkbox.TextColor3 = Color3.new(1, 1, 1)
        checkbox.Font = Enum.Font.GothamBold
        checkbox.TextSize = 10
        checkbox.Parent = infoRow
        
        local checkboxCorner = Instance.new("UICorner")
        checkboxCorner.CornerRadius = UDim.new(0, 3)
        checkboxCorner.Parent = checkbox
        
        local infoLabel = Instance.new("TextLabel")
        infoLabel.Size = UDim2.new(1, -40, 1, 0)
        infoLabel.Position = UDim2.fromOffset(30, 0)
        infoLabel.BackgroundTransparency = 1
        
        if #rec > 0 then
            local totalSeconds = 0
            for _, frame in ipairs(rec) do
                totalSeconds = totalSeconds + frame.dt
            end
            infoLabel.Text = "✔️ " .. FormatDuration(totalSeconds) .. " • " .. #rec .. " frames • ENHANCED"
        else
            infoLabel.Text = "❌ 0:00 • 0 frames • ENHANCED"
        end
        
        infoLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
        infoLabel.Font = Enum.Font.GothamBold
        infoLabel.TextSize = 8
        infoLabel.TextXAlignment = Enum.TextXAlignment.Left
        infoLabel.Parent = infoRow
        
        checkbox.MouseButton1Click:Connect(function()
            SelectedReplays[name] = not SelectedReplays[name]
            checkbox.BackgroundColor3 = SelectedReplays[name] and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(40, 40, 50)
            checkbox.Text = SelectedReplays[name] and "✓" or ""
            PlaySound("Toggle")
        end)
        
        upBtn.MouseButton1Click:Connect(function()
            if index > 1 then 
                MoveRecordingUp(name) 
            end
        end)
        
        downBtn.MouseButton1Click:Connect(function()
            if index < #RecordingOrder then 
                MoveRecordingDown(name) 
            end
        end)
        
        playBtn.MouseButton1Click:Connect(function()
            if not IsPlaying then 
                PlayRecording(name) 
            end
        end)
        
        delBtn.MouseButton1Click:Connect(function()
            RecordedMovements[name] = nil
            checkpointNames[name] = nil
            SelectedReplays[name] = nil
            local idx = table.find(RecordingOrder, name)
            if idx then table.remove(RecordingOrder, idx) end
            UpdateRecordList()
        end)
        
        nameBox.FocusLost:Connect(function()
            local newName = nameBox.Text
            if newName and newName ~= "" then
                checkpointNames[name] = newName
                PlaySound("Success")
            end
        end)
        
        yPos = yPos + 53
    end
    
    RecordList.CanvasSize = UDim2.new(0, 0, 0, math.max(yPos, RecordList.AbsoluteSize.Y))
end

-- ========= HOTKEYS =========
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F9 then
        if IsRecording then StopRecording() else StartRecording() end
    elseif input.KeyCode == Enum.KeyCode.F10 then
        if IsPlaying or AutoLoop then StopPlayback() else PlayRecording() end
    elseif input.KeyCode == Enum.KeyCode.F11 then
        MainFrame.Visible = not MainFrame.Visible
        MiniButton.Visible = not MainFrame.Visible
    elseif input.KeyCode == Enum.KeyCode.F8 then
        local char = player.Character
        if char then CompleteCharacterReset(char) end
    elseif input.KeyCode == Enum.KeyCode.F7 then
        AutoLoop = not AutoLoop
        AnimateLoop(AutoLoop)
        if AutoLoop then 
            StartAutoLoopAll() 
        else 
            StopAutoLoopAll() 
        end
    elseif input.KeyCode == Enum.KeyCode.F6 then
        SaveToJSON()
    elseif input.KeyCode == Enum.KeyCode.F5 then
        AutoRespawn = not AutoRespawn
        AnimateRespawn(AutoRespawn)
    elseif input.KeyCode == Enum.KeyCode.F4 then
        ShowPaths = not ShowPaths
        if ShowPaths then
            PathToggleBtn.Text = "HIDE RUTE"
            VisualizeAllPaths()
        else
            PathToggleBtn.Text = "SHOW RUTE"
            ClearPathVisualization()
        end
    elseif input.KeyCode == Enum.KeyCode.F3 then
        SMART_RESUME = not SMART_RESUME
        AnimateSmartResume(SMART_RESUME)
    elseif input.KeyCode == Enum.KeyCode.F2 then
        InfiniteJump = not InfiniteJump
        AnimateJump(InfiniteJump)
        if InfiniteJump then
            EnableInfiniteJump()
        else
            DisableInfiniteJump()
        end
    end
end)

-- ========= INITIAL SETUP =========
UpdateRecordList()

task.spawn(function()
    task.wait(2)
    local filename = "MyReplays.json"
    if readfile and isfile and isfile(filename) then
        LoadFromJSON()
    end
end)

player.CharacterRemoving:Connect(function()
    if IsRecording then
        StopRecording()
    end
    if IsPlaying then
        IsPlaying = false
        IsPaused = false
    end
end)

player.CharacterAdded:Connect(function(character)
    task.wait(1)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if humanoid then
        humanoid.WalkSpeed = CurrentWalkSpeed
        humanoid.JumpPower = 50
    end
end)

print("✅ ByaruL AutoWalk v6.0 - ENHANCED FRAME DATA Loaded!")
print("🎯 Features: Enhanced Frame Data, Perfect Auto Loop, Smart Resume")
print("📊 Data Structure: Position, LookVector, Velocity, State, MoveDirection, Ground Detection")