
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "AUTOWALK BYARUL",
    Author = "by Player",
    Folder = "autowalkbyarul",
    HideSearchBar = true,
    
    OpenButton = {
        Title = "OPEN AUTOWALK", 
        CornerRadius = UDim.new(1,0),
        StrokeThickness = 3,
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
        Color = ColorSequence.new(
            Color3.fromHex("#FF416C"),  
            Color3.fromHex("#FF4B2B")   
        )
    }
})

do
    WindUI:AddTheme({
        Name = "FullBlack",
        Accent = Color3.fromHex("#000000"),
        Dialog = Color3.fromHex("#000000"),
        Outline = Color3.fromHex("#FF416C"),
        Text = Color3.fromHex("#FFFFFF"),
        Placeholder = Color3.fromHex("#666666"),
        Button = Color3.fromHex("#000000"),
        Icon = Color3.fromHex("#FFFFFF"),
        WindowBackground = Color3.fromHex("#000000"),
        TopbarButtonIcon = Color3.fromHex("#FFFFFF"),
        TopbarTitle = Color3.fromHex("#FFFFFF"),
        TopbarAuthor = Color3.fromHex("#888888"),
        TopbarIcon = Color3.fromHex("#FFFFFF"),
        TabBackground = Color3.fromHex("#000000"),
        TabTitle = Color3.fromHex("#FFFFFF"),
        TabIcon = Color3.fromHex("#FFFFFF"),
        ElementBackground = Color3.fromHex("#000000"),
        ElementTitle = Color3.fromHex("#FFFFFF"),
        ElementDesc = Color3.fromHex("#888888"),
        ElementIcon = Color3.fromHex("#FFFFFF"),
    })
    
    WindUI:SetTheme("FullBlack")
end

-- ========= SERVICES =========
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local player = Players.LocalPlayer

-- ========= CONFIGURATION =========
local RECORDING_FPS = 120
local MAX_FRAMES = 50000
local MIN_DISTANCE_THRESHOLD = 0.01
local VELOCITY_SCALE = 1
local VELOCITY_Y_SCALE = 1
local ROUTE_PROXIMITY_THRESHOLD = 15
local MOVETO_REACH_DISTANCE = 3
local MAX_FRAME_JUMP = 30
local USE_MOVETO_SYSTEM = false
local USE_FORCED_MOVEMENT = true

-- ========= R15 TALL SUPPORT =========
local R15TallMode = false
local R15TallOffset = Vector3.new(0, 0.5, 0)

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
local UseMoveTo = false
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

-- ========= PERFORMANCE OPTIMIZATION =========
local FrameBuffer = {}
local LastProcessedFrame = 0
local UseFrameInterpolation = true
local InterpolationSmoothing = 0.15
local PlaybackFPS = 144
local LastPlaybackFrame = 0
local FrameCache = {}

-- ========= PAUSE/RESUME VARIABLES =========
local playbackStartTime = 0
local totalPausedDuration = 0
local pauseStartTime = 0
local currentPlaybackFrame = 1
local prePauseHumanoidState = nil
local prePauseWalkSpeed = 16
local prePauseAutoRotate = true
local prePauseJumpPower = 50
local prePausePlatformStand = false
local prePauseSit = false

-- ========= PLAYBACK STATE TRACKING =========
local lastPlaybackState = nil
local lastStateChangeTime = 0
local STATE_CHANGE_COOLDOWN = 0.1

-- ========= AUTO LOOP VARIABLES =========
local IsAutoLoopPlaying = false
local CurrentLoopIndex = 1
local LoopPauseStartTime = 0
local LoopTotalPausedDuration = 0
local SelectedReplaysList = {}

-- ========= VISIBLE SHIFTLOCK SYSTEM =========
local shiftLockConnection = nil
local originalMouseBehavior = nil
local ShiftLockEnabled = false
local isShiftLockActive = false

-- ========= MEMORY MANAGEMENT =========
local activeConnections = {}

-- ========= JSON CONFIG SYSTEM =========
local SavedConfigs = {}
local CurrentConfigName = ""
local ConfigFolder = "AutoWalkByarul_Configs"

local function AddConnection(connection)
    table.insert(activeConnections, connection)
end

local function CleanupConnections()
    for _, connection in ipairs(activeConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    activeConnections = {}
    
    if recordConnection then recordConnection:Disconnect() recordConnection = nil end
    if playbackConnection then playbackConnection:Disconnect() playbackConnection = nil end
    if loopConnection then loopConnection:Disconnect() loopConnection = nil end
    if shiftLockConnection then shiftLockConnection:Disconnect() shiftLockConnection = nil end
    if jumpConnection then jumpConnection:Disconnect() jumpConnection = nil end
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

-- ========= JSON SAVE/LOAD FUNCTIONS =========
local function SerializeRecordings()
    local data = {
        Version = "2.0",
        Timestamp = os.time(),
        R15TallMode = R15TallMode,
        Recordings = {},
        RecordingOrder = RecordingOrder,
        CheckpointNames = checkpointNames,
        SelectedReplays = SelectedReplays
    }
    
    for name, frames in pairs(RecordedMovements) do
        data.Recordings[name] = frames
    end
    
    return HttpService:JSONEncode(data)
end

local function DeserializeRecordings(jsonString)
    local success, data = pcall(function()
        return HttpService:JSONDecode(jsonString)
    end)
    
    if not success or not data then
        return false, "Invalid JSON format"
    end
    
    if not data.Recordings then
        return false, "No recordings found in config"
    end
    
    return true, data
end

local function SaveConfigToFile(configName)
    if configName == "" or not configName then
        return false, "Config name cannot be empty"
    end
    
    local jsonData = SerializeRecordings()
    
    if not writefile then
        return false, "Your executor doesn't support file operations"
    end
    
    local folderPath = ConfigFolder
    if not isfolder(folderPath) then
        makefolder(folderPath)
    end
    
    local filePath = folderPath .. "/" .. configName .. ".json"
    
    pcall(function()
        writefile(filePath, jsonData)
    end)
    
    SavedConfigs[configName] = true
    
    return true, "Config saved successfully"
end

local function LoadConfigFromFile(configName)
    if not readfile or not isfile then
        return false, "Your executor doesn't support file operations"
    end
    
    local filePath = ConfigFolder .. "/" .. configName .. ".json"
    
    if not isfile(filePath) then
        return false, "Config file not found"
    end
    
    local success, jsonData = pcall(function()
        return readfile(filePath)
    end)
    
    if not success then
        return false, "Failed to read config file"
    end
    
    local decodeSuccess, data = DeserializeRecordings(jsonData)
    
    if not decodeSuccess then
        return false, data
    end
    
    RecordedMovements = {}
    RecordingOrder = {}
    checkpointNames = {}
    SelectedReplays = {}
    
    for name, frames in pairs(data.Recordings) do
        RecordedMovements[name] = frames
    end
    
    RecordingOrder = data.RecordingOrder or {}
    checkpointNames = data.CheckpointNames or {}
    SelectedReplays = data.SelectedReplays or {}
    R15TallMode = data.R15TallMode or false
    
    for _, name in ipairs(RecordingOrder) do
        if SelectedReplays[name] == nil then
            SelectedReplays[name] = false
        end
    end
    
    CurrentConfigName = configName
    
    return true, "Config loaded successfully"
end

local function GetAllConfigs()
    if not isfolder or not listfiles then
        return {}
    end
    
    local folderPath = ConfigFolder
    
    if not isfolder(folderPath) then
        makefolder(folderPath)
        return {}
    end
    
    local files = listfiles(folderPath)
    local configs = {}
    
    for _, filePath in ipairs(files) do
        local fileName = filePath:match("([^/\\]+)%.json$")
        if fileName then
            table.insert(configs, fileName)
        end
    end
    
    return configs
end

local function DeleteConfig(configName)
    if not delfile or not isfile then
        return false, "Your executor doesn't support file operations"
    end
    
    local filePath = ConfigFolder .. "/" .. configName .. ".json"
    
    if not isfile(filePath) then
        return false, "Config file not found"
    end
    
    pcall(function()
        delfile(filePath)
    end)
    
    SavedConfigs[configName] = nil
    
    return true, "Config deleted successfully"
end

-- ========= R15 TALL POSITION ADJUSTMENT =========
local function AdjustPositionForR15Tall(position)
    if R15TallMode then
        return position + R15TallOffset
    end
    return position
end

local function GetAdjustedFramePosition(frame)
    local pos = Vector3.new(frame.Position[1], frame.Position[2], frame.Position[3])
    return AdjustPositionForR15Tall(pos)
end

-- ========= CHARACTER FUNCTIONS =========
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
            return false
        end
    until player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChildOfClass("Humanoid") and player.Character.Humanoid.Health > 0
    
    task.wait(1)
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
        humanoid.JumpPower = 50
        humanoid.Sit = false
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end)
end

-- ========= SHIFTLOCK FUNCTIONS =========
local function ApplyVisibleShiftLock()
    if not ShiftLockEnabled or not player.Character then return end
    
    local char = player.Character
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local camera = workspace.CurrentCamera
    
    if humanoid and hrp and camera then
        humanoid.AutoRotate = false
        
        local lookVector = camera.CFrame.LookVector
        local horizontalLook = Vector3.new(lookVector.X, 0, lookVector.Z).Unit
        
        if horizontalLook.Magnitude > 0 then
            hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + horizontalLook)
        end
    end
end

local function EnableVisibleShiftLock()
    if shiftLockConnection or not ShiftLockEnabled then return end
    
    originalMouseBehavior = UserInputService.MouseBehavior
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    isShiftLockActive = true
    
    shiftLockConnection = RunService.RenderStepped:Connect(function()
        if ShiftLockEnabled and player.Character then
            ApplyVisibleShiftLock()
        end
    end)
    
    AddConnection(shiftLockConnection)
    PlaySound("Toggle")
end

local function DisableVisibleShiftLock()
    if shiftLockConnection then
        shiftLockConnection:Disconnect()
        shiftLockConnection = nil
    end
    
    if originalMouseBehavior then
        UserInputService.MouseBehavior = originalMouseBehavior
    end
    
    local char = player.Character
    if char and char:FindFirstChildOfClass("Humanoid") then
        char.Humanoid.AutoRotate = true
    end
    
    isShiftLockActive = false
    PlaySound("Toggle")
end

local function ToggleVisibleShiftLock()
    ShiftLockEnabled = not ShiftLockEnabled
    
    if ShiftLockEnabled then
        EnableVisibleShiftLock()
    else
        DisableVisibleShiftLock()
    end
end

-- ========= INFINITE JUMP =========
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

local function ToggleInfiniteJump()
    InfiniteJump = not InfiniteJump
    
    if InfiniteJump then
        EnableInfiniteJump()
    else
        DisableInfiniteJump()
    end
end

-- ========= HUMANOID STATE FUNCTIONS =========
local function SaveHumanoidState()
    local char = player.Character
    if not char then return end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        prePauseAutoRotate = humanoid.AutoRotate
        prePauseWalkSpeed = humanoid.WalkSpeed
        prePauseJumpPower = humanoid.JumpPower
        prePausePlatformStand = humanoid.PlatformStand
        prePauseSit = humanoid.Sit
        prePauseHumanoidState = humanoid:GetState()
        
        if prePauseHumanoidState == Enum.HumanoidStateType.Climbing then
            humanoid.PlatformStand = false
            humanoid.AutoRotate = false
        end
    end
end

local function RestoreHumanoidState()
    local char = player.Character
    if not char then return end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    
    if humanoid then
        if prePauseHumanoidState == Enum.HumanoidStateType.Climbing then
            humanoid.PlatformStand = false
            humanoid.AutoRotate = false
            humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
        else
            humanoid.AutoRotate = prePauseAutoRotate
            humanoid.WalkSpeed = prePauseWalkSpeed
            humanoid.JumpPower = prePauseJumpPower
            humanoid.PlatformStand = prePausePlatformStand
            humanoid.Sit = prePauseSit
        end
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
        humanoid.JumpPower = 50
        humanoid.PlatformStand = false
        humanoid.Sit = false
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end
    
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end
end

-- ========= JUMP CONTROL =========
local function DisableJump()
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            prePauseJumpPower = humanoid.JumpPower
            humanoid.JumpPower = 0
        end
    end
end

local function EnableJump()
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.JumpPower = prePauseJumpPower or 50
        end
    end
end

-- ========= MOVE STATE DETECTION =========
local function GetCurrentMoveState(hum)
    if not hum then return "Grounded" end
    local state = hum:GetState()
    if state == Enum.HumanoidStateType.Climbing then return "Climbing"
    elseif state == Enum.HumanoidStateType.Jumping then return "Jumping"
    elseif state == Enum.HumanoidStateType.Freefall then return "Falling"
    elseif state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics then return "Grounded"
    elseif state == Enum.HumanoidStateType.Swimming then return "Swimming"
    else return "Grounded" end
end

-- ========= PATH VISUALIZATION =========
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

local function CreatePauseMarker(position)
    if CurrentPauseMarker and CurrentPauseMarker.Parent then
        CurrentPauseMarker:Destroy()
        CurrentPauseMarker = nil
    end
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PauseMarker"
    billboard.Size = UDim2.new(0, 200, 0, 60)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "⏸ PAUSE"
    label.TextColor3 = Color3.new(1, 1, 0)
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBold
    label.TextSize = 18
    label.TextScaled = false
    label.Parent = billboard
    
    local part = Instance.new("Part")
    part.Name = "PauseMarkerPart"
    part.Anchored = true
    part.CanCollide = false
    part.Size = Vector3.new(0.1, 0.1, 0.1)
    part.Transparency = 1
    part.Position = position + Vector3.new(0, 2, 0)
    part.Parent = workspace
    
    billboard.Adornee = part
    billboard.Parent = part
    
    CurrentPauseMarker = part
    
    return part
end

local function UpdatePauseMarker()
    if IsPaused then
        if not CurrentPauseMarker then
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local position = char.HumanoidRootPart.Position
                CreatePauseMarker(position)
            end
        end
    else
        if CurrentPauseMarker and CurrentPauseMarker.Parent then
            CurrentPauseMarker:Destroy()
            CurrentPauseMarker = nil
        end
    end
end

-- ========= FRAME DATA FUNCTIONS (WITH CACHING) =========
local function GetFramePosition(frame)
    if not FrameCache[frame] then
        FrameCache[frame] = {
            Position = Vector3.new(frame.Position[1], frame.Position[2], frame.Position[3])
        }
    end
    return FrameCache[frame].Position
end

local function GetFrameCFrame(frame)
    local pos = GetFramePosition(frame)
    local look = Vector3.new(frame.LookVector[1], frame.LookVector[2], frame.LookVector[3])
    local up = Vector3.new(frame.UpVector[1], frame.UpVector[2], frame.UpVector[3])
    return CFrame.lookAt(pos, pos + look, up)
end

local function GetFrameVelocity(frame)
    return frame.Velocity and Vector3.new(
        frame.Velocity[1] * VELOCITY_SCALE,
        frame.Velocity[2] * VELOCITY_Y_SCALE,
        frame.Velocity[3] * VELOCITY_SCALE
    ) or Vector3.new(0, 0, 0)
end

local function GetFrameWalkSpeed(frame)
    return frame.WalkSpeed or 16
end

local function GetFrameTimestamp(frame)
    return frame.Timestamp or 0
end

-- ========= SMART ROUTE DETECTION =========
local function FindNearestFrame(recording, position)
    if not recording or #recording == 0 then return 1, math.huge end
    
    local nearestFrame = 1
    local nearestDistance = math.huge
    
    for i, frame in ipairs(recording) do
        local framePos = GetFramePosition(frame)
        local distance = (framePos - position).Magnitude
        
        if distance < nearestDistance then
            nearestDistance = distance
            nearestFrame = i
        end
    end
    
    return nearestFrame, nearestDistance
end

-- ========= FRAME INTERPOLATION =========
local function InterpolateFrame(frame1, frame2, alpha)
    local pos1 = GetFramePosition(frame1)
    local pos2 = GetFramePosition(frame2)
    
    local cf1 = GetFrameCFrame(frame1)
    local cf2 = GetFrameCFrame(frame2)
    
    local vel1 = GetFrameVelocity(frame1)
    local vel2 = GetFrameVelocity(frame2)
    
    return {
        Position = pos1:Lerp(pos2, alpha),
        CFrame = cf1:Lerp(cf2, alpha),
        Velocity = vel1:Lerp(vel2, alpha),
        WalkSpeed = frame1.WalkSpeed + (frame2.WalkSpeed - frame1.WalkSpeed) * alpha,
        MoveState = alpha < 0.5 and frame1.MoveState or frame2.MoveState
    }
end

-- ========= ULTRA SMOOTH CFRAME PLAYBACK =========
local function PlayRecordingWithSmoothCFrame(recording, startFrame)
    if not recording or #recording == 0 then return end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
    if not hum or not hrp then return end

    local currentFrame = startFrame or 1
    playbackStartTime = tick()
    totalPausedDuration = 0
    pauseStartTime = 0
    lastPlaybackState = nil
    LastPlaybackFrame = 0

    local targetFPS = PlaybackFPS
    local frameTime = 1 / targetFPS
    local lastFrameUpdate = tick()

    playbackConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not IsPlaying then
            playbackConnection:Disconnect()
            RestoreFullUserControl()
            return
        end
        
        if IsPaused then
            if pauseStartTime == 0 then
                pauseStartTime = tick()
                RestoreHumanoidState()
                if ShiftLockEnabled then ApplyVisibleShiftLock() end
                UpdatePauseMarker()
            end
            return
        else
            if pauseStartTime > 0 then
                totalPausedDuration = totalPausedDuration + (tick() - pauseStartTime)
                pauseStartTime = 0
                SaveHumanoidState()
                DisableJump()
                UpdatePauseMarker()
            end
        end

        char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            IsPlaying = false
            playbackConnection:Disconnect()
            RestoreFullUserControl()
            return
        end

        hum = char:FindFirstChildOfClass("Humanoid")
        hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then
            IsPlaying = false
            playbackConnection:Disconnect()
            RestoreFullUserControl()
            return
        end

        local currentTime = tick()
        if currentTime - lastFrameUpdate < frameTime then
            return
        end
        lastFrameUpdate = currentTime

        local effectiveTime = (currentTime - playbackStartTime - totalPausedDuration) * CurrentSpeed
        
        local nextFrameIndex = currentFrame + 1
        while nextFrameIndex < #recording and GetFrameTimestamp(recording[nextFrameIndex]) <= effectiveTime do
            currentFrame = nextFrameIndex
            nextFrameIndex = currentFrame + 1
        end

        if currentFrame >= #recording then
            IsPlaying = false
            IsPaused = false
            lastPlaybackState = nil
            
            local finalFrame = recording[#recording]
            if finalFrame then
                pcall(function()
                    hrp.CFrame = GetFrameCFrame(finalFrame)
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                end)
            end
            
            RestoreFullUserControl()
            UpdatePauseMarker()
            playbackConnection:Disconnect()
            PlaySound("Stop")
            WindUI:Notify({
                Title = "✅ PLAYBACK COMPLETE",
                Content = "Recording finished smoothly",
                Duration = 2
            })
            return
        end

        local currentFrameData = recording[currentFrame]
        if not currentFrameData then return end

        local interpolatedData = currentFrameData
        if nextFrameIndex <= #recording and UseFrameInterpolation then
            local nextFrameData = recording[nextFrameIndex]
            local currentTimestamp = GetFrameTimestamp(currentFrameData)
            local nextTimestamp = GetFrameTimestamp(nextFrameData)
            local timeDiff = nextTimestamp - currentTimestamp
            
            if timeDiff > 0 then
                local alpha = (effectiveTime - currentTimestamp) / timeDiff
                alpha = math.clamp(alpha, 0, 1)
                interpolatedData = InterpolateFrame(currentFrameData, nextFrameData, alpha)
            end
        end

        pcall(function()
            local targetCFrame = type(interpolatedData.CFrame) == "CFrame" and interpolatedData.CFrame or GetFrameCFrame(currentFrameData)
            local targetVelocity = type(interpolatedData.Velocity) == "Vector3" and interpolatedData.Velocity or GetFrameVelocity(currentFrameData)
            local targetWalkSpeed = interpolatedData.WalkSpeed or GetFrameWalkSpeed(currentFrameData)
            local moveState = interpolatedData.MoveState or currentFrameData.MoveState
            
            if R15TallMode then
                targetCFrame = targetCFrame + R15TallOffset
            end
            
            hrp.CFrame = targetCFrame
            hrp.AssemblyLinearVelocity = targetVelocity * CurrentSpeed
            hum.WalkSpeed = targetWalkSpeed * CurrentSpeed
            
            if moveState ~= lastPlaybackState then
                lastPlaybackState = moveState
                
                if moveState == "Climbing" then
                    hum:ChangeState(Enum.HumanoidStateType.Climbing)
                    hum.PlatformStand = false
                    hum.AutoRotate = false
                elseif moveState == "Jumping" then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                elseif moveState == "Falling" then
                    hum:ChangeState(Enum.HumanoidStateType.Freefall)
                elseif moveState == "Swimming" then
                    hum:ChangeState(Enum.HumanoidStateType.Swimming)
                else
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                end
            end
            
            currentPlaybackFrame = currentFrame
            LastPlaybackFrame = currentFrame
        end)
    end)
    
    AddConnection(playbackConnection)
end

-- ========= ENHANCED FORCED MOVEMENT PLAYBACK =========
local function PlayRecordingWithSmoothForcedMovement(recording, startFrame)
    if not recording or #recording == 0 then return end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
    if not hum or not hrp then return end

    local currentFrame = startFrame or 1
    playbackStartTime = tick()
    totalPausedDuration = 0
    pauseStartTime = 0
    lastPlaybackState = nil
    LastPlaybackFrame = 0

    local targetFPS = PlaybackFPS
    local frameTime = 1 / targetFPS
    local lastFrameUpdate = tick()

    playbackConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not IsPlaying then
            playbackConnection:Disconnect()
            RestoreFullUserControl()
            return
        end
        
        if IsPaused then
            if pauseStartTime == 0 then
                pauseStartTime = tick()
                RestoreHumanoidState()
                if ShiftLockEnabled then ApplyVisibleShiftLock() end
                UpdatePauseMarker()
            end
            return
        else
            if pauseStartTime > 0 then
                totalPausedDuration = totalPausedDuration + (tick() - pauseStartTime)
                pauseStartTime = 0
                SaveHumanoidState()
                DisableJump()
                UpdatePauseMarker()
            end
        end

        char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            IsPlaying = false
            playbackConnection:Disconnect()
            RestoreFullUserControl()
            return
        end

        hum = char:FindFirstChildOfClass("Humanoid")
        hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then
            IsPlaying = false
            playbackConnection:Disconnect()
            RestoreFullUserControl()
            return
        end

        local currentTime = tick()
        if currentTime - lastFrameUpdate < frameTime then
            return
        end
        lastFrameUpdate = currentTime

        local effectiveTime = (currentTime - playbackStartTime - totalPausedDuration) * CurrentSpeed
        
        local nextFrameIndex = currentFrame + 1
        while nextFrameIndex < #recording and GetFrameTimestamp(recording[nextFrameIndex]) <= effectiveTime do
            currentFrame = nextFrameIndex
            nextFrameIndex = currentFrame + 1
        end

        if currentFrame >= #recording then
            IsPlaying = false
            IsPaused = false
            lastPlaybackState = nil
            
            local finalFrame = recording[#recording]
            if finalFrame then
                pcall(function()
                    hrp.CFrame = GetFrameCFrame(finalFrame)
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                end)
            end
            
            RestoreFullUserControl()
            UpdatePauseMarker()
            playbackConnection:Disconnect()
            PlaySound("Stop")
            WindUI:Notify({
                Title = "✅ PLAYBACK COMPLETE",
                Content = "Recording finished smoothly",
                Duration = 2
            })
            return
        end

        local currentFrameData = recording[currentFrame]
        if not currentFrameData then return end

        local interpolatedData = currentFrameData
        if nextFrameIndex <= #recording and UseFrameInterpolation then
            local nextFrameData = recording[nextFrameIndex]
            local currentTimestamp = GetFrameTimestamp(currentFrameData)
            local nextTimestamp = GetFrameTimestamp(nextFrameData)
            local timeDiff = nextTimestamp - currentTimestamp
            
            if timeDiff > 0 then
                local alpha = (effectiveTime - currentTimestamp) / timeDiff
                alpha = math.clamp(alpha, 0, 1)
                interpolatedData = InterpolateFrame(currentFrameData, nextFrameData, alpha)
            end
        end

        pcall(function()
            local targetPos = type(interpolatedData.Position) == "Vector3" and interpolatedData.Position or GetFramePosition(currentFrameData)
            local targetCFrame = type(interpolatedData.CFrame) == "CFrame" and interpolatedData.CFrame or GetFrameCFrame(currentFrameData)
            local targetVelocity = type(interpolatedData.Velocity) == "Vector3" and interpolatedData.Velocity or GetFrameVelocity(currentFrameData)
            local targetWalkSpeed = interpolatedData.WalkSpeed or GetFrameWalkSpeed(currentFrameData)
            local moveState = interpolatedData.MoveState or currentFrameData.MoveState
            
            if R15TallMode then
                targetPos = targetPos + R15TallOffset
                targetCFrame = targetCFrame + R15TallOffset
            end
            
            local currentPos = hrp.Position
            local direction = (targetPos - currentPos)
            local distance = direction.Magnitude
            local directionUnit = distance > 0 and direction.Unit or Vector3.new(0, 0, 0)
            
            if distance > 15.0 then
                hrp.CFrame = targetCFrame
                hrp.AssemblyLinearVelocity = targetVelocity * CurrentSpeed
            elseif distance > 3.0 then
                local speed = targetWalkSpeed * CurrentSpeed * 1.5
                hrp.AssemblyLinearVelocity = directionUnit * speed + Vector3.new(0, targetVelocity.Y, 0)
                hrp.CFrame = CFrame.new(currentPos, targetPos)
            elseif distance > 0.5 then
                local speed = targetWalkSpeed * CurrentSpeed
                hrp.AssemblyLinearVelocity = directionUnit * speed + Vector3.new(0, targetVelocity.Y, 0)
                hrp.CFrame = targetCFrame
            else
                hrp.CFrame = targetCFrame
                hrp.AssemblyLinearVelocity = targetVelocity * CurrentSpeed
            end
            
            hum.WalkSpeed = targetWalkSpeed * CurrentSpeed
            
            if moveState ~= lastPlaybackState then
                lastPlaybackState = moveState
                
                if moveState == "Climbing" then
                    hum:ChangeState(Enum.HumanoidStateType.Climbing)
                    hum.PlatformStand = false
                    hum.AutoRotate = false
                elseif moveState == "Jumping" then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                elseif moveState == "Falling" then
                    hum:ChangeState(Enum.HumanoidStateType.Freefall)
                elseif moveState == "Swimming" then
                    hum:ChangeState(Enum.HumanoidStateType.Swimming)
                else
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                end
            end
            
            currentPlaybackFrame = currentFrame
            LastPlaybackFrame = currentFrame
        end)
    end)
    
    AddConnection(playbackConnection)
end

-- ========= OPTIMIZED RECORDING SYSTEM =========
local lastFrameTime = 0
local frameInterval = 1 / RECORDING_FPS

local function ShouldRecordFrame()
    local currentTime = tick()
    return (currentTime - lastFrameTime) >= frameInterval
end

local function AutoSaveRecording()
    if #CurrentRecording.Frames == 0 then
        PlaySound("Error")
        WindUI:Notify({
            Title = "❌ RECORDING ERROR",
            Content = "No frames recorded!",
            Duration = 2
        })
        return
    end
    
    local name = CurrentRecording.Name
    RecordedMovements[name] = CurrentRecording.Frames
    table.insert(RecordingOrder, name)
    checkpointNames[name] = "Recording " .. #RecordingOrder
    SelectedReplays[name] = false
    
    PlaySound("Success")
    WindUI:Notify({
        Title = "💾 RECORDING SAVED",
        Content = string.format("Frames: %d | Duration: %.1fs", #CurrentRecording.Frames, CurrentRecording.Frames[#CurrentRecording.Frames].Timestamp),
        Duration = 3
    })
    
    CurrentRecording = {Frames = {}, StartTime = 0, Name = "recording_" .. os.date("%H%M%S")}
end

function StartRecording()
    if IsRecording then return end
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        PlaySound("Error")
        WindUI:Notify({
            Title = "❌ RECORDING ERROR",
            Content = "Character not ready!",
            Duration = 2
        })
        return
    end
    
    IsRecording = true
    CurrentRecording = {Frames = {}, StartTime = tick(), Name = "recording_" .. os.date("%H%M%S")}
    lastRecordTime = 0
    lastRecordPos = nil
    lastFrameTime = 0
    FrameCache = {}
    
    PlaySound("RecordStart")
    WindUI:Notify({
        Title = "🔴 RECORDING STARTED",
        Content = string.format("FPS: %d | Max Frames: %d", RECORDING_FPS, MAX_FRAMES),
        Duration = 2
    })
    
    recordConnection = RunService.Heartbeat:Connect(function()
        if not IsRecording then return end
        
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") or #CurrentRecording.Frames >= MAX_FRAMES then
            StopRecording()
            return
        end
        
        if not ShouldRecordFrame() then return end
        
        local hrp = char.HumanoidRootPart
        local hum = char:FindFirstChildOfClass("Humanoid")
        local currentPos = hrp.Position
        local currentVelocity = hrp.AssemblyLinearVelocity
        local moveState = GetCurrentMoveState(hum)

        if R15TallMode then
            currentPos = currentPos - R15TallOffset
        end

        local velY = currentVelocity.Y
        if moveState == "Falling" and velY > 25 then
            moveState = "Jumping"
        elseif velY > 50 then
            moveState = "Jumping"
        end

        if lastRecordPos and (currentPos - lastRecordPos).Magnitude < MIN_DISTANCE_THRESHOLD and moveState == "Grounded" then
            return
        end

        local cf = hrp.CFrame
        local frameData = {
            Position = {cf.Position.X, cf.Position.Y, cf.Position.Z},
            LookVector = {cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z},
            UpVector = {cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z},
            Velocity = {currentVelocity.X, currentVelocity.Y, currentVelocity.Z},
            MoveState = moveState,
            WalkSpeed = hum and hum.WalkSpeed or 16,
            Timestamp = tick() - CurrentRecording.StartTime,
        }
        
        table.insert(CurrentRecording.Frames, frameData)
        lastFrameTime = tick()
        lastRecordPos = currentPos
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
    else
        WindUI:Notify({
            Title = "⏹ RECORDING STOPPED",
            Content = "No frames recorded",
            Duration = 2
        })
    end
    
    PlaySound("RecordStop")
end

-- ========= MAIN PLAYBACK FUNCTION =========
function PlayRecording(name)
    if IsPlaying then return end
    
    local recording = name and RecordedMovements[name] or (RecordingOrder[1] and RecordedMovements[RecordingOrder[1]])
    if not recording or #recording == 0 then
        PlaySound("Error")
        WindUI:Notify({
            Title = "❌ PLAYBACK ERROR",
            Content = "No recording found!",
            Duration = 2
        })
        return
    end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        PlaySound("Error")
        WindUI:Notify({
            Title = "❌ PLAYBACK ERROR",
            Content = "Character not ready!",
            Duration = 2
        })
        return
    end

    IsPlaying = true
    IsPaused = false
    totalPausedDuration = 0
    pauseStartTime = 0
    lastPlaybackState = nil
    FrameCache = {}
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local nearestFrame, distance = FindNearestFrame(recording, hrp.Position)
    
    if distance <= ROUTE_PROXIMITY_THRESHOLD then
        currentPlaybackFrame = nearestFrame
        playbackStartTime = tick() - (GetFrameTimestamp(recording[nearestFrame]) / CurrentSpeed)
        WindUI:Notify({
            Title = "▶️ PLAYBACK STARTED",
            Content = string.format("Smart start at frame %d/%d", nearestFrame, #recording),
            Duration = 2
        })
    else
        currentPlaybackFrame = 1
        playbackStartTime = tick()
        
        if (hrp.Position - GetFramePosition(recording[1])).Magnitude > 50 then
            hrp.CFrame = CFrame.new(GetFramePosition(recording[1]))
        end
        WindUI:Notify({
            Title = "▶️ PLAYBACK STARTED",
            Content = string.format("Playing %d frames | %.1fs", #recording, recording[#recording].Timestamp),
            Duration = 2
        })
    end

    SaveHumanoidState()
    DisableJump()
    PlaySound("Play")

    if UseMoveTo then
        PlayRecordingWithSmoothForcedMovement(recording, currentPlaybackFrame)
    else
        PlayRecordingWithSmoothCFrame(recording, currentPlaybackFrame)
    end
end

function PausePlayback()
    if not IsPlaying and not IsAutoLoopPlaying then return end
    
    IsPaused = not IsPaused
    
    if IsPaused then
        RestoreHumanoidState()
        EnableJump()
        if ShiftLockEnabled then
            ApplyVisibleShiftLock()
        end
        UpdatePauseMarker()
        PlaySound("Click")
        WindUI:Notify({
            Title = "⏸ PLAYBACK PAUSED",
            Content = string.format("Frame %d/%d", LastPlaybackFrame, #(RecordedMovements[RecordingOrder[1]] or {})),
            Duration = 2
        })
    else
        SaveHumanoidState()
        DisableJump()
        UpdatePauseMarker()
        PlaySound("Click")
        WindUI:Notify({
            Title = "▶️ PLAYBACK RESUMED",
            Content = "Continuing recording...",
            Duration = 2
        })
    end
end

function StopPlayback()
    if AutoLoop then
        StopAutoLoopAll()
    end
    
    if not IsPlaying then return end
    IsPlaying = false
    IsPaused = false
    lastPlaybackState = nil
    
    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end
    
    RestoreFullUserControl()
    UpdatePauseMarker()
    
    local char = player.Character
    if char then CompleteCharacterReset(char) end
    
    PlaySound("Stop")
    WindUI:Notify({
        Title = "⏹ PLAYBACK STOPPED",
        Content = "Control returned to player",
        Duration = 2
    })
end

-- ========= AUTO LOOP SYSTEM =========
function PlayAutoLoopAll()
    if IsAutoLoopPlaying or not AutoLoop then return end
    
    SelectedReplaysList = {}
    for _, name in ipairs(RecordingOrder) do
        if SelectedReplays[name] then
            table.insert(SelectedReplaysList, name)
        end
    end
    
    if #SelectedReplaysList == 0 then
        PlaySound("Error")
        WindUI:Notify({
            Title = "❌ AUTO LOOP ERROR",
            Content = "No replays selected!",
            Duration = 2
        })
        return
    end
    
    IsAutoLoopPlaying = true
    CurrentLoopIndex = 1
    
    WindUI:Notify({
        Title = "🔄 AUTO LOOP STARTED",
        Content = string.format("Playing %d replays in sequence", #SelectedReplaysList),
        Duration = 3
    })
    
    local function PlayNextInLoop()
        if not IsAutoLoopPlaying or CurrentLoopIndex > #SelectedReplaysList then
            IsAutoLoopPlaying = false
            RestoreFullUserControl()
            WindUI:Notify({
                Title = "✅ AUTO LOOP COMPLETE",
                Content = "All selected replays finished",
                Duration = 2
            })
            return
        end
        
        local replayName = SelectedReplaysList[CurrentLoopIndex]
        local recording = RecordedMovements[replayName]
        
        if not recording then
            CurrentLoopIndex = CurrentLoopIndex + 1
            PlayNextInLoop()
            return
        end
        
        WindUI:Notify({
            Title = "▶️ LOOP PLAYBACK",
            Content = string.format("Playing %d/%d: %s", CurrentLoopIndex, #SelectedReplaysList, checkpointNames[replayName] or replayName),
            Duration = 2
        })
        
        IsPlaying = true
        IsPaused = false
        
        PlayRecording(replayName)
        
        task.wait(recording[#recording].Timestamp / CurrentSpeed + 1)
        
        IsPlaying = false
        CurrentLoopIndex = CurrentLoopIndex + 1
        
        task.wait(0.5)
        PlayNextInLoop()
    end
    
    PlayNextInLoop()
end

function StopAutoLoopAll()
    if not IsAutoLoopPlaying then return end
    
    IsAutoLoopPlaying = false
    IsPlaying = false
    IsPaused = false
    
    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end
    
    RestoreFullUserControl()
    
    PlaySound("Stop")
    WindUI:Notify({
        Title = "⏹ AUTO LOOP STOPPED",
        Content = "Loop playback cancelled",
        Duration = 2
    })
end

-- ========= RENAME RECORDING FUNCTION =========
local function RenameRecording(oldName, newName)
    if not RecordedMovements[oldName] then
        return false, "Recording not found"
    end
    
    if newName == "" or not newName then
        return false, "New name cannot be empty"
    end
    
    if RecordedMovements[newName] then
        return false, "A recording with that name already exists"
    end
    
    RecordedMovements[newName] = RecordedMovements[oldName]
    RecordedMovements[oldName] = nil
    
    for i, name in ipairs(RecordingOrder) do
        if name == oldName then
            RecordingOrder[i] = newName
            break
        end
    end
    
    if checkpointNames[oldName] then
        checkpointNames[newName] = checkpointNames[oldName]
        checkpointNames[oldName] = nil
    end
    
    if SelectedReplays[oldName] ~= nil then
        SelectedReplays[newName] = SelectedReplays[oldName]
        SelectedReplays[oldName] = nil
    end
    
    return true, "Recording renamed successfully"
end

-- ========= DELETE RECORDING FUNCTION =========
local function DeleteRecording(name)
    if not RecordedMovements[name] then
        return false, "Recording not found"
    end
    
    RecordedMovements[name] = nil
    
    for i, recordName in ipairs(RecordingOrder) do
        if recordName == name then
            table.remove(RecordingOrder, i)
            break
        end
    end
    
    checkpointNames[name] = nil
    SelectedReplays[name] = nil
    
    return true, "Recording deleted successfully"
end

-- ========= WINDUI INTERFACE =========

-- TAB MAIN CONTROLS
local MainTab = Window:Tab({
    Title = "MAIN CONTROLS",
    Icon = "play",
})

MainTab:Button({
    Title = "🔴 START RECORDING",
    Desc = "Begin recording movement",
    Callback = function()
        StartRecording()
    end
})

MainTab:Button({
    Title = "⏹ STOP RECORDING", 
    Desc = "Stop and auto-save recording",
    Callback = function()
        StopRecording()
    end
})

MainTab:Space()

MainTab:Button({
    Title = "▶️ PLAY RECORDING",
    Desc = "Play first/selected recording",
    Callback = function()
        PlayRecording()
    end
})

MainTab:Button({
    Title = "⏸ PAUSE/RESUME",
    Desc = "Toggle pause state",
    Callback = function()
        PausePlayback()
    end
})

MainTab:Button({
    Title = "⏹ STOP PLAYBACK",
    Desc = "Stop current playback",
    Callback = function()
        StopPlayback()
    end
})

MainTab:Space()

MainTab:Toggle({
    Title = "🔄 AUTO LOOP",
    Desc = "Enable auto loop for selected replays",
    Default = false,
    Callback = function(state)
        AutoLoop = state
        PlaySound("Toggle")
        WindUI:Notify({
            Title = state and "✅ AUTO LOOP ON" or "❌ AUTO LOOP OFF",
            Content = state and "Will loop selected replays" or "Single playback mode",
            Duration = 2
        })
    end
})

MainTab:Button({
    Title = "🔄 START AUTO LOOP",
    Desc = "Play all selected replays in order",
    Callback = function()
        PlayAutoLoopAll()
    end
})

MainTab:Button({
    Title = "⏹ STOP AUTO LOOP",
    Desc = "Stop loop playback",
    Callback = function()
        StopAutoLoopAll()
    end
})

-- TAB SETTINGS
local SettingsTab = Window:Tab({
    Title = "SETTINGS",
    Icon = "settings",
})

SettingsTab:Toggle({
    Title = "🔄 AUTO RESPAWN",
    Desc = "Automatically respawn when dead",
    Default = false,
    Callback = function(state)
        AutoRespawn = state
        PlaySound("Toggle")
        WindUI:Notify({
            Title = state and "✅ AUTO RESPAWN ON" or "❌ AUTO RESPAWN OFF",
            Content = state and "Will auto respawn on death" or "Manual respawn required",
            Duration = 2
        })
    end
})

SettingsTab:Toggle({
    Title = "🎯 NATURAL MOVEMENT", 
    Desc = "Use velocity movement (smoother but less precise)",
    Default = false,
    Callback = function(state)
        UseMoveTo = state
        PlaySound("Toggle")
        WindUI:Notify({
            Title = state and "✅ NATURAL MOVEMENT ON" or "✅ PRECISE MOVEMENT ON",
            Content = state and "Using velocity-based movement" or "Using exact CFrame positioning",
            Duration = 2
        })
    end
})

SettingsTab:Toggle({
    Title = "♾️ INFINITE JUMP",
    Desc = "Enable unlimited jumping",
    Default = false, 
    Callback = function(state)
        ToggleInfiniteJump()
        WindUI:Notify({
            Title = state and "✅ INFINITE JUMP ON" or "❌ INFINITE JUMP OFF",
            Content = state and "Unlimited jumps enabled" or "Normal jumping restored",
            Duration = 2
        })
    end
})

SettingsTab:Toggle({
    Title = "🔒 SHIFT LOCK",
    Desc = "Enable visible shift lock camera",
    Default = false,
    Callback = function(state)
        ToggleVisibleShiftLock()
        WindUI:Notify({
            Title = state and "✅ SHIFT LOCK ON" or "❌ SHIFT LOCK OFF",
            Content = state and "Camera locked to character" or "Free camera movement",
            Duration = 2
        })
    end
})

SettingsTab:Toggle({
    Title = "🧍 R15 TALL MODE",
    Desc = "Enable offset for R15 Tall avatars",
    Default = false,
    Callback = function(state)
        R15TallMode = state
        PlaySound("Toggle")
        WindUI:Notify({
            Title = state and "✅ R15 TALL MODE ON" or "❌ R15 TALL MODE OFF",
            Content = state and "Position offset enabled for tall avatars" or "Normal avatar mode",
            Duration = 2
        })
    end
})

SettingsTab:Toggle({
    Title = "🎞️ FRAME INTERPOLATION",
    Desc = "Smooth playback between frames",
    Default = true,
    Callback = function(state)
        UseFrameInterpolation = state
        PlaySound("Toggle")
        WindUI:Notify({
            Title = state and "✅ INTERPOLATION ON" or "❌ INTERPOLATION OFF",
            Content = state and "Smooth frame transitions enabled" or "Raw frame playback",
            Duration = 2
        })
    end
})

SettingsTab:Space()

SettingsTab:Slider({
    Title = "⚡ PLAYBACK SPEED",
    Desc = "Adjust playback speed multiplier",
    Value = {
        Min = 0.25,
        Max = 5,
        Default = 1,
    },
    Callback = function(value)
        CurrentSpeed = value
        PlaySound("Click")
        WindUI:Notify({
            Title = "⚡ SPEED CHANGED",
            Content = string.format("Playback speed: %.2fx", value),
            Duration = 2
        })
    end
})

SettingsTab:Slider({
    Title = "🏃 WALK SPEED",
    Desc = "Set character walk speed",
    Value = {
        Min = 8,
        Max = 200,
        Default = 16,
    },
    Callback = function(value)
        CurrentWalkSpeed = value
        local char = player.Character
        if char and char:FindFirstChildOfClass("Humanoid") then
            char.Humanoid.WalkSpeed = CurrentWalkSpeed
        end
        PlaySound("Click")
        WindUI:Notify({
            Title = "🏃 WALK SPEED SET",
            Content = string.format("Walk speed: %d", value),
            Duration = 2
        })
    end
})

SettingsTab:Slider({
    Title = "🎬 RECORDING FPS",
    Desc = "Higher FPS = smoother recording (60-240)",
    Value = {
        Min = 60,
        Max = 240,
        Default = 120,
    },
    Callback = function(value)
        RECORDING_FPS = value
        PlaySound("Click")
        WindUI:Notify({
            Title = "🎬 RECORDING FPS SET",
            Content = string.format("Recording at %d FPS", value),
            Duration = 2
        })
    end
})

SettingsTab:Slider({
    Title = "📺 PLAYBACK FPS",
    Desc = "Target FPS for playback (60-240)",
    Value = {
        Min = 60,
        Max = 240,
        Default = 144,
    },
    Callback = function(value)
        PlaybackFPS = value
        PlaySound("Click")
        WindUI:Notify({
            Title = "📺 PLAYBACK FPS SET",
            Content = string.format("Playback target: %d FPS", value),
            Duration = 2
        })
    end
})

-- TAB SAVE/LOAD CONFIG
local ConfigTab = Window:Tab({
    Title = "CONFIG USAGE",
    Icon = "folder",
})

ConfigTab:Input({
    Title = "Config Name",
    Desc = "Enter name for saving/loading",
    Value = {
        Default = "",
        Placeholder = "Enter config name..."
    },
    Callback = function(text)
        CurrentConfigName = text
    end
})

ConfigTab:Space()

ConfigTab:Button({
    Title = "💾 SAVE CONFIG",
    Desc = "Save all recordings to JSON file",
    Callback = function()
        if CurrentConfigName == "" then
            PlaySound("Error")
            WindUI:Notify({
                Title = "❌ SAVE ERROR",
                Content = "Please enter a config name first!",
                Duration = 2
            })
            return
        end
        
        local success, message = SaveConfigToFile(CurrentConfigName)
        
        if success then
            PlaySound("Success")
            WindUI:Notify({
                Title = "✅ CONFIG SAVED",
                Content = string.format("'%s' saved with %d recordings!", CurrentConfigName, #RecordingOrder),
                Duration = 3
            })
        else
            PlaySound("Error")
            WindUI:Notify({
                Title = "❌ SAVE ERROR",
                Content = message,
                Duration = 3
            })
        end
    end
})

ConfigTab:Button({
    Title = "📂 LOAD CONFIG",
    Desc = "Load recordings from JSON file",
    Callback = function()
        if CurrentConfigName == "" then
            PlaySound("Error")
            WindUI:Notify({
                Title = "❌ LOAD ERROR",
                Content = "Please enter a config name first!",
                Duration = 2
            })
            return
        end
        
        local success, message = LoadConfigFromFile(CurrentConfigName)
        
        if success then
            PlaySound("Success")
            WindUI:Notify({
                Title = "✅ CONFIG LOADED",
                Content = string.format("'%s' loaded! %d recordings found", CurrentConfigName, #RecordingOrder),
                Duration = 3
            })
            UpdateRecordingList()
        else
            PlaySound("Error")
            WindUI:Notify({
                Title = "❌ LOAD ERROR",
                Content = message,
                Duration = 3
            })
        end
    end
})

ConfigTab:Space()

ConfigTab:Dropdown({
    Title = "All Configs",
    Desc = "Select existing configs",
    Value = {
        Default = "--",
        List = GetAllConfigs()
    },
    Callback = function(selected)
        if selected and selected ~= "--" then
            CurrentConfigName = selected
            WindUI:Notify({
                Title = "📁 CONFIG SELECTED",
                Content = string.format("Selected: %s", selected),
                Duration = 2
            })
        end
    end
})

ConfigTab:Button({
    Title = "🔄 REFRESH CONFIG LIST",
    Desc = "Update available configs",
    Callback = function()
        local configs = GetAllConfigs()
        PlaySound("Click")
        WindUI:Notify({
            Title = "🔄 LIST REFRESHED",
            Content = string.format("Found %d configs", #configs),
            Duration = 2
        })
    end
})

ConfigTab:Space()

ConfigTab:Button({
    Title = "🗑️ DELETE CONFIG",
    Desc = "Remove selected config file",
    Callback = function()
        if CurrentConfigName == "" then
            PlaySound("Error")
            WindUI:Notify({
                Title = "❌ DELETE ERROR",
                Content = "Please select a config first!",
                Duration = 2
            })
            return
        end
        
        local success, message = DeleteConfig(CurrentConfigName)
        
        if success then
            PlaySound("Success")
            WindUI:Notify({
                Title = "✅ CONFIG DELETED",
                Content = string.format("'%s' has been deleted", CurrentConfigName),
                Duration = 3
            })
            CurrentConfigName = ""
        else
            PlaySound("Error")
            WindUI:Notify({
                Title = "❌ DELETE ERROR",
                Content = message,
                Duration = 3
            })
        end
    end
})

-- TAB VISUALIZATION
local VisualTab = Window:Tab({
    Title = "VISUAL",
    Icon = "visibility",
})

VisualTab:Toggle({
    Title = "👁️ SHOW PATHS",
    Desc = "Display recorded routes in 3D",
    Default = false,
    Callback = function(state)
        ShowPaths = state
        if ShowPaths then
            ClearPathVisualization()
            
            local totalPaths = 0
            for _, name in ipairs(RecordingOrder) do
                local recording = RecordedMovements[name]
                if not recording or #recording < 2 then continue end
                
                local previousPos = GetFramePosition(recording[1])
                
                for i = 2, #recording, 5 do
                    local frame = recording[i]
                    local currentPos = GetFramePosition(frame)
                    
                    if (currentPos - previousPos).Magnitude > 0.5 then
                        CreatePathSegment(previousPos, currentPos, BrickColor.new("Really black"))
                        previousPos = currentPos
                        totalPaths = totalPaths + 1
                    end
                end
            end
            
            PlaySound("Success")
            WindUI:Notify({
                Title = "✅ PATHS VISIBLE",
                Content = string.format("Showing %d path segments", totalPaths),
                Duration = 2
            })
        else
            ClearPathVisualization()
            PlaySound("Click")
            WindUI:Notify({
                Title = "❌ PATHS HIDDEN",
                Content = "Route visualization disabled",
                Duration = 2
            })
        end
    end
})

VisualTab:Button({
    Title = "🧹 CLEAR PATHS",
    Desc = "Remove all path visualizations",
    Callback = function()
        ClearPathVisualization()
        ShowPaths = false
        PlaySound("Click")
        WindUI:Notify({
            Title = "🧹 PATHS CLEARED",
            Content = "All visualizations removed",
            Duration = 2
        })
    end
})

VisualTab:Space()

VisualTab:Button({
    Title = "🔄 RESET CHARACTER",
    Desc = "Reset character state completely",
    Callback = function()
        local char = player.Character
        if char then
            CompleteCharacterReset(char)
            PlaySound("Success")
            WindUI:Notify({
                Title = "✅ CHARACTER RESET",
                Content = "Character state restored to normal",
                Duration = 2
            })
        else
            PlaySound("Error")
            WindUI:Notify({
                Title = "❌ RESET ERROR",
                Content = "Character not found!",
                Duration = 2
            })
        end
    end
})

VisualTab:Button({
    Title = "💀 RESPAWN CHARACTER",
    Desc = "Force respawn character",
    Callback = function()
        ResetCharacter()
        PlaySound("Click")
        WindUI:Notify({
            Title = "💀 RESPAWNING...",
            Content = "Character will respawn shortly",
            Duration = 2
        })
    end
})

-- TAB RECORDINGS (WITH FULL FEATURES)
local RecordingsTab = Window:Tab({
    Title = "RECORDINGS",
    Icon = "list",
})

local recordingList = {}

local function UpdateRecordingList()
    for _, child in pairs(recordingList) do
        if child and child.Remove then
            pcall(function() child:Remove() end)
        end
    end
    recordingList = {}
    
    if #RecordingOrder == 0 then
        local emptyLabel = RecordingsTab:Label({
            Title = "📭 NO RECORDINGS",
            Desc = "Start recording to see them here"
        })
        table.insert(recordingList, emptyLabel)
        return
    end
    
    for index, name in ipairs(RecordingOrder) do
        local rec = RecordedMovements[name]
        if not rec then continue end
        
        local duration = rec[#rec] and rec[#rec].Timestamp or 0
        local displayName = checkpointNames[name] or ("Recording " .. index)
        
        -- TOGGLE for selecting replay
        local toggleElement = RecordingsTab:Toggle({
            Title = string.format("☑️ %s", displayName),
            Desc = string.format("Select for auto loop | %d frames | %.1fs", #rec, duration),
            Default = SelectedReplays[name] or false,
            Callback = function(state)
                SelectedReplays[name] = state
                PlaySound("Toggle")
                WindUI:Notify({
                    Title = state and "✅ SELECTED" or "❌ DESELECTED",
                    Content = displayName,
                    Duration = 1
                })
            end
        })
        table.insert(recordingList, toggleElement)
        
        -- INPUT for renaming
        local renameInput = RecordingsTab:Input({
            Title = "✏️ Rename",
            Desc = "Enter new name for this recording",
            Value = {
                Default = displayName,
                Placeholder = "Enter new name..."
            },
            Callback = function(newName)
                if newName and newName ~= "" and newName ~= displayName then
                    checkpointNames[name] = newName
                    PlaySound("Success")
                    WindUI:Notify({
                        Title = "✅ RENAMED",
                        Content = string.format("'%s' → '%s'", displayName, newName),
                        Duration = 2
                    })
                    UpdateRecordingList()
                end
            end
        })
        table.insert(recordingList, renameInput)
        
        -- PLAY BUTTON
        local playButton = RecordingsTab:Button({
            Title = "▶️ PLAY",
            Desc = "Play this recording",
            Callback = function()
                PlayRecording(name)
            end
        })
        table.insert(recordingList, playButton)
        
        -- DELETE BUTTON
        local deleteButton = RecordingsTab:Button({
            Title = "🗑️ DELETE",
            Desc = "Remove this recording",
            Callback = function()
                local success, message = DeleteRecording(name)
                if success then
                    PlaySound("Success")
                    WindUI:Notify({
                        Title = "✅ DELETED",
                        Content = string.format("'%s' removed", displayName),
                        Duration = 2
                    })
                    UpdateRecordingList()
                else
                    PlaySound("Error")
                    WindUI:Notify({
                        Title = "❌ DELETE ERROR",
                        Content = message,
                        Duration = 2
                    })
                end
            end
        })
        table.insert(recordingList, deleteButton)
        
        -- SPACER
        local spacer = RecordingsTab:Space()
        table.insert(recordingList, spacer)
    end
    
    -- SUMMARY
    local totalFrames = 0
    local totalDuration = 0
    local selectedCount = 0
    for _, name in ipairs(RecordingOrder) do
        local rec = RecordedMovements[name]
        if rec then
            totalFrames = totalFrames + #rec
            totalDuration = totalDuration + (rec[#rec] and rec[#rec].Timestamp or 0)
        end
        if SelectedReplays[name] then
            selectedCount = selectedCount + 1
        end
    end
    
    local summaryLabel = RecordingsTab:Label({
        Title = "📊 SUMMARY",
        Desc = string.format("%d recordings | %d selected | %d frames | %.1fs total", 
            #RecordingOrder, 
            selectedCount,
            totalFrames, 
            totalDuration
        )
    })
    table.insert(recordingList, summaryLabel)
end

RecordingsTab:Button({
    Title = "🔄 REFRESH LIST",
    Desc = "Update recordings display",
    Callback = function()
        UpdateRecordingList()
        PlaySound("Click")
        WindUI:Notify({
            Title = "🔄 LIST UPDATED",
            Content = string.format("Showing %d recordings", #RecordingOrder),
            Duration = 2
        })
    end
})

RecordingsTab:Space()

RecordingsTab:Button({
    Title = "☑️ SELECT ALL",
    Desc = "Select all recordings for loop",
    Callback = function()
        for _, name in ipairs(RecordingOrder) do
            SelectedReplays[name] = true
        end
        UpdateRecordingList()
        PlaySound("Success")
        WindUI:Notify({
            Title = "✅ ALL SELECTED",
            Content = string.format("%d recordings selected", #RecordingOrder),
            Duration = 2
        })
    end
})

RecordingsTab:Button({
    Title = "❌ DESELECT ALL",
    Desc = "Deselect all recordings",
    Callback = function()
        for _, name in ipairs(RecordingOrder) do
            SelectedReplays[name] = false
        end
        UpdateRecordingList()
        PlaySound("Click")
        WindUI:Notify({
            Title = "❌ ALL DESELECTED",
            Content = "No recordings selected",
            Duration = 2
        })
    end
})

RecordingsTab:Space()

RecordingsTab:Button({
    Title = "🗑️ CLEAR ALL RECORDINGS",
    Desc = "Remove all saved recordings (WARNING!)",
    Callback = function()
        if #RecordingOrder == 0 then
            WindUI:Notify({
                Title = "ℹ️ NO RECORDINGS",
                Content = "Nothing to clear",
                Duration = 2
            })
            return
        end
        
        RecordedMovements = {}
        RecordingOrder = {}
        checkpointNames = {}
        SelectedReplays = {}
        FrameCache = {}
        UpdateRecordingList()
        PlaySound("Success")
        WindUI:Notify({
            Title = "✅ RECORDINGS CLEARED",
            Content = "All recordings have been removed",
            Duration = 2
        })
    end
})

-- TAB ADVANCED
local AdvancedTab = Window:Tab({
    Title = "ADVANCED",
    Icon = "tune",
})

AdvancedTab:Label({
    Title = "⚙️ ADVANCED SETTINGS",
    Desc = "Fine-tune recording and playback"
})

AdvancedTab:Slider({
    Title = "📏 MIN DISTANCE THRESHOLD",
    Desc = "Minimum distance to record new frame (lower = more detail)",
    Value = {
        Min = 0.001,
        Max = 0.1,
        Default = 0.01,
    },
    Callback = function(value)
        MIN_DISTANCE_THRESHOLD = value
        PlaySound("Click")
        WindUI:Notify({
            Title = "📏 THRESHOLD SET",
            Content = string.format("Min distance: %.3f studs", value),
            Duration = 2
        })
    end
})

AdvancedTab:Slider({
    Title = "🎯 ROUTE PROXIMITY",
    Desc = "Distance to detect nearby route (smart start)",
    Value = {
        Min = 5,
        Max = 50,
        Default = 15,
    },
    Callback = function(value)
        ROUTE_PROXIMITY_THRESHOLD = value
        PlaySound("Click")
        WindUI:Notify({
            Title = "🎯 PROXIMITY SET",
            Content = string.format("Route detection: %d studs", value),
            Duration = 2
        })
    end
})

AdvancedTab:Slider({
    Title = "🔢 MAX FRAMES",
    Desc = "Maximum frames per recording",
    Value = {
        Min = 10000,
        Max = 100000,
        Default = 50000,
    },
    Callback = function(value)
        MAX_FRAMES = value
        PlaySound("Click")
        WindUI:Notify({
            Title = "🔢 MAX FRAMES SET",
            Content = string.format("Max frames: %d", value),
            Duration = 2
        })
    end
})

AdvancedTab:Space()

AdvancedTab:Button({
    Title = "📊 SHOW PERFORMANCE INFO",
    Desc = "Display current system stats",
    Callback = function()
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        local selectedCount = 0
        for _, selected in pairs(SelectedReplays) do
            if selected then selectedCount = selectedCount + 1 end
        end
        
        local info = string.format(
            "FPS: %.1f\nRecording: %s\nPlaying: %s\nAuto Loop: %s\nCurrent Frames: %d\nTotal Recordings: %d\nSelected: %d\nConfigs: %d\nPath Segments: %d\nR15 Tall: %s",
            workspace:GetRealPhysicsFPS(),
            IsRecording and "YES" or "NO",
            IsPlaying and "YES" or "NO",
            AutoLoop and "ENABLED" or "DISABLED",
            #(CurrentRecording.Frames or {}),
            #RecordingOrder,
            selectedCount,
            #GetAllConfigs(),
            #PathVisualization,
            R15TallMode and "ENABLED" or "DISABLED"
        )
        
        PlaySound("Click")
        WindUI:Notify({
            Title = "📊 PERFORMANCE INFO",
            Content = info,
            Duration = 7
        })
    end
})

AdvancedTab:Button({
    Title = "🧹 CLEAR FRAME CACHE",
    Desc = "Free memory from cached frames",
    Callback = function()
        local cacheSize = 0
        for _ in pairs(FrameCache) do
            cacheSize = cacheSize + 1
        end
        
        FrameCache = {}
        
        PlaySound("Success")
        WindUI:Notify({
            Title = "✅ CACHE CLEARED",
            Content = string.format("Freed %d cached frames", cacheSize),
            Duration = 2
        })
    end
})

AdvancedTab:Space()

AdvancedTab:Label({
    Title = "⚠️ EXPERIMENTAL",
    Desc = "Use with caution"
})

AdvancedTab:Slider({
    Title = "🎛️ VELOCITY SCALE",
    Desc = "Horizontal velocity multiplier (experimental)",
    Value = {
        Min = 0.5,
        Max = 2,
        Default = 1,
    },
    Callback = function(value)
        VELOCITY_SCALE = value
        PlaySound("Click")
        WindUI:Notify({
            Title = "🎛️ VELOCITY SCALE SET",
            Content = string.format("Horizontal velocity: %.2fx", value),
            Duration = 2
        })
    end
})

AdvancedTab:Slider({
    Title = "🎛️ VELOCITY Y SCALE",
    Desc = "Vertical velocity multiplier (jump/fall)",
    Value = {
        Min = 0.5,
        Max = 2,
        Default = 1,
    },
    Callback = function(value)
        VELOCITY_Y_SCALE = value
        PlaySound("Click")
        WindUI:Notify({
            Title = "🎛️ Y VELOCITY SCALE SET",
            Content = string.format("Vertical velocity: %.2fx", value),
            Duration = 2
        })
    end
})

AdvancedTab:Slider({
    Title = "🔧 INTERPOLATION SMOOTHING",
    Desc = "Frame blend smoothness (0.05-0.5)",
    Value = {
        Min = 0.05,
        Max = 0.5,
        Default = 0.15,
    },
    Callback = function(value)
        InterpolationSmoothing = value
        PlaySound("Click")
        WindUI:Notify({
            Title = "🔧 SMOOTHING SET",
            Content = string.format("Interpolation: %.2f", value),
            Duration = 2
        })
    end
})

-- TAB ABOUT
local AboutTab = Window:Tab({
    Title = "ABOUT",
    Icon = "info",
})

AboutTab:Label({
    Title = "📱 AUTOWALK BYARUL",
    Desc = "Advanced Movement Recorder v2.0 Complete"
})

AboutTab:Space()

AboutTab:Label({
    Title = "✨ FEATURES",
    Desc = "• High FPS recording (60-240 FPS)\n• Ultra smooth interpolated playback\n• JSON save/load config system\n• R15 Tall avatar support\n• Auto loop selected replays\n• Smart route detection\n• Path visualization\n• Frame caching system\n• Individual recording management\n• Rename/Delete recordings\n• Toggle selection for loop"
})

AboutTab:Space()

AboutTab:Label({
    Title = "🎮 CONTROLS",
    Desc = "• Record: Start/Stop recording\n• Select: Toggle recordings for loop\n• Rename: Click textbox to rename\n• Play: Individual or auto loop\n• Pause: Control character while paused\n• Config: Save/load all recordings"
})

AboutTab:Space()

AboutTab:Label({
    Title = "⚙️ OPTIMIZATION",
    Desc = string.format("• Recording FPS: %d\n• Playback FPS: %d\n• Frame interpolation: %s\n• Cache enabled: YES\n• Total recordings: %d", 
        RECORDING_FPS, 
        PlaybackFPS,
        UseFrameInterpolation and "ON" or "OFF",
        #RecordingOrder
    )
})

AboutTab:Space()

AboutTab:Button({
    Title = "📋 COPY DISCORD",
    Desc = "Get support and updates",
    Callback = function()
        setclipboard("discord.gg/yourserver") -- Ganti dengan Discord Anda
        PlaySound("Success")
        WindUI:Notify({
            Title = "✅ COPIED!",
            Content = "Discord link copied to clipboard",
            Duration = 2
        })
    end
})

AboutTab:Button({
    Title = "💝 SUPPORT DEVELOPER",
    Desc = "Consider supporting the project",
    Callback = function()
        PlaySound("Success")
        WindUI:Notify({
            Title = "💝 THANK YOU!",
            Content = "Your support means everything!",
            Duration = 3
        })
    end
})

AboutTab:Space()

AboutTab:Label({
    Title = "⚠️ DISCLAIMER",
    Desc = "Use responsibly. May be detected by anti-cheat systems. Not responsible for bans."
})

-- Initialize recording list
UpdateRecordingList()

-- Auto-save on script shutdown
local scriptInstance = script

game:GetService("ScriptContext").DescendantRemoving:Connect(function(descendant)
    if descendant == scriptInstance then
        CleanupConnections()
        ClearPathVisualization()
        
        if IsRecording then
            StopRecording()
        end
        
        if IsPlaying then
            StopPlayback()
        end
    end
end)

-- Character respawn handler
player.CharacterAdded:Connect(function(char)
    task.wait(1)
    
    if AutoRespawn and (IsPlaying or IsRecording) then
        task.wait(2)
        CompleteCharacterReset(char)
        
        if IsPlaying then
            PlayRecording(RecordingOrder[1])
        end
    end
    
    local humanoid = char:WaitForChild("Humanoid", 5)
    if humanoid then
        humanoid.WalkSpeed = CurrentWalkSpeed
    end
end)

-- Periodic cache cleanup (every 5 minutes)
task.spawn(function()
    while task.wait(300) do
        if not IsPlaying and not IsRecording then
            local oldCacheSize = 0
            for _ in pairs(FrameCache) do
                oldCacheSize = oldCacheSize + 1
            end
            
            if oldCacheSize > 1000 then
                FrameCache = {}
                print("[AutoWalk] Cache cleaned: " .. oldCacheSize .. " frames freed")
            end
        end
    end
end)

-- Performance monitor
task.spawn(function()
    while task.wait(1) do
        if IsPlaying then
            local fps = workspace:GetRealPhysicsFPS()
            if fps < 30 then
                warn("[AutoWalk] Low FPS detected: " .. fps .. " - Consider reducing playback FPS")
            end
        end
    end
end)

-- Final initialization
PlaySound("Success")
WindUI:Notify({
    Title = "✅ AUTOWALK BYARUL LOADED",
    Content = string.format("v2.0 Complete | Recording: %d FPS | Playback: %d FPS", RECORDING_FPS, PlaybackFPS),
    Duration = 5
})

print("=" .. string.rep("=", 70))
print("  AUTOWALK BYARUL - COMPLETE EDITION v2.0")
print("  Features: JSON Config, Auto Loop, Rename, Select, R15 Tall, Smooth Playback")
print("  Status: ✅ FULLY LOADED")
print("=" .. string.rep("=", 70))