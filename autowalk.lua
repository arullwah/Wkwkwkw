
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
wait(1)

-- ========================================
-- FILE SYSTEM PROTECTION
-- ========================================
local hasFileSystem = (writefile ~= nil and readfile ~= nil and isfile ~= nil)

if not hasFileSystem then
    warn("⚠️ File system tidak tersedia. Script akan berjalan tanpa fitur Save/Load.")
    writefile = function() end
    readfile = function() return "" end
    isfile = function() return false end
end

-- ========================================
-- CONFIGURATION
-- ========================================
local CONFIG = {
    Recording = {
        FPS = 90,
        MAX_FRAMES = 30000,
        MIN_DISTANCE_THRESHOLD = 0.012,
        TIMELINE_STEP_SECONDS = 0.15,
        GAP_DETECTION_TIME = 0.5,
        GAP_BLEND_FRAMES = 3
    },
    Playback = {
        FIXED_TIMESTEP = 1 / 90,
        USE_VELOCITY = true,
        INTERPOLATION_LOOKAHEAD = 3,
        RESUME_BLEND_FRAMES = 5,
        RESUME_POSITION_TOLERANCE = 2
    },
    Transitions = {
        FRAMES = 8,
        LOOP_DELAY = 0.12,
        STATE_CHANGE_COOLDOWN = 0.1
    },
    Velocity = {
        SCALE = 1,
        Y_SCALE = 1,
        JUMP_THRESHOLD = 10,
        FALL_THRESHOLD = -5
    },
    AutoLoop = {
        RETRY_DELAY = 0.5,
        MAX_RETRIES = 999,
        RESUME_DISTANCE_THRESHOLD = 40
    },
    LagCompensation = {
        DETECTION_THRESHOLD = 0.2,
        MAX_FRAMES_TO_SKIP = 5,
        INTERPOLATE_AFTER_LAG = true,
        TIME_BYPASS_THRESHOLD = 0.15
    },
    Smoothing = {
        ENABLE = false,
        WINDOW = 3
    }
}

-- ========================================
-- FIELD MAPPING (OBFUSCATION)
-- ========================================
local FIELD_MAPPING = {
    Position = "11",
    LookVector = "88", 
    UpVector = "55",
    Velocity = "22",
    MoveState = "33",
    WalkSpeed = "44",
    Timestamp = "66"
}

local REVERSE_MAPPING = {}
for k, v in pairs(FIELD_MAPPING) do
    REVERSE_MAPPING[v] = k
end

-- ========================================
-- STATE VARIABLES
-- ========================================
local State = {
    -- Recording
    IsRecording = false,
    StudioIsRecording = false,
    StudioCurrentRecording = {Frames = {}, StartTime = 0, Name = ""},
    CurrentRecording = {Frames = {}, StartTime = 0, Name = ""},
    lastRecordTime = 0,
    lastRecordPos = nil,
    lastStudioRecordTime = 0,
    lastStudioRecordPos = nil,
    lastRecordedState = nil,
    
    -- Playback
    IsPlaying = false,
    IsPaused = false,
    IsReversing = false,
    IsForwarding = false,
    IsAutoLoopPlaying = false,
    CurrentSpeed = 1.0,
    CurrentWalkSpeed = 16,
    currentPlaybackFrame = 1,
    playbackAccumulator = 0,
    playbackStartTime = 0,
    totalPausedDuration = 0,
    pauseStartTime = 0,
    CurrentPlayingRecording = nil,
    PausedAtFrame = 0,
    LastPausePosition = nil,
    LastPauseRecording = nil,
    LastPauseFrame = 0,
    previousFrameData = nil,
    lastPlaybackState = nil,
    lastStateChangeTime = 0,
    
    -- Timeline
    IsTimelineMode = false,
    CurrentTimelineFrame = 0,
    TimelinePosition = 0,
    
    -- Loop
    CurrentLoopIndex = 1,
    LoopPauseStartTime = 0,
    LoopTotalPausedDuration = 0,
    LoopRetryAttempts = 0,
    IsLoopTransitioning = false,
    
    -- Features
    AutoRespawn = false,
    InfiniteJump = false,
    AutoLoop = false,
    AutoReset = false,
    ShiftLockEnabled = false,
    isShiftLockActive = false,
    ShowPaths = false,
    PathAutoHide = true,
    
    -- Pre-pause states
    prePauseHumanoidState = nil,
    prePauseWalkSpeed = 16,
    prePauseAutoRotate = true,
    prePauseJumpPower = 50,
    prePausePlatformStand = false,
    prePauseSit = false,
    
    -- UI
    NearestRecordingDistance = math.huge,
    originalMouseBehavior = nil
}

-- ========================================
-- DATA STORAGE
-- ========================================
local Data = {
    RecordedMovements = {},
    RecordingOrder = {},
    checkpointNames = {},
    CheckedRecordings = {},
    PathHasBeenUsed = {},
    PathsHiddenOnce = false
}

-- ========================================
-- CONNECTIONS STORAGE
-- ========================================
local Connections = {
    record = nil,
    playback = nil,
    loop = nil,
    jump = nil,
    reverse = nil,
    forward = nil,
    shiftLock = nil,
    titlePulse = nil,
    active = {}
}

-- ========================================
-- VISUALIZATION
-- ========================================
local Visualization = {
    PathVisualization = {},
    CurrentPauseMarker = nil
}

-- ========================================
-- SOUND EFFECTS
-- ========================================
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

-- ========================================
-- UTILITY FUNCTIONS
-- ========================================
local function PlaySound(soundType)
    task.spawn(function()
        pcall(function()
            local sound = Instance.new("Sound")
            sound.SoundId = SoundEffects[soundType] or SoundEffects.Click
            sound.Volume = 0.3
            sound.Parent = workspace
            sound:Play()
            game:GetService("Debris"):AddItem(sound, 2)
        end)
    end)
end

local function AnimateButtonClick(button)
    PlaySound("Click")
    pcall(function()
        local originalColor = button.BackgroundColor3
        local brighterColor = Color3.new(
            math.min(originalColor.R * 1.3, 1),
            math.min(originalColor.G * 1.3, 1), 
            math.min(originalColor.B * 1.3, 1)
        )
        
        TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundColor3 = brighterColor
        }):Play()
        
        task.wait(0.1)
        
        TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundColor3 = originalColor
        }):Play()
    end)
end

-- ========================================
-- CONNECTION MANAGER
-- ========================================
local function AddConnection(connection)
    table.insert(Connections.active, connection)
end

local function CleanupConnections()
    for _, connection in ipairs(Connections.active) do
        if connection then
            pcall(function() connection:Disconnect() end)
        end
    end
    Connections.active = {}
    
    for key, conn in pairs(Connections) do
        if key ~= "active" and conn then
            pcall(function() 
                if typeof(conn) == "RBXScriptConnection" then
                    conn:Disconnect()
                else
                    task.cancel(conn)
                end
            end)
            Connections[key] = nil
        end
    end
end

-- ========================================
-- CHARACTER UTILITIES
-- ========================================
local function IsCharacterReady()
    local char = player.Character
    if not char then return false end
    if not char:FindFirstChild("HumanoidRootPart") then return false end
    if not char:FindFirstChildOfClass("Humanoid") then return false end
    if char.Humanoid.Health <= 0 then return false end
    return true
end

local function ResetCharacter()
    pcall(function()
        local char = player.Character
        if char then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.Health = 0
            end
        end
    end)
end

local function WaitForRespawn()
    local startTime = tick()
    local timeout = 10
    repeat
        task.wait(0.1)
        if tick() - startTime > timeout then return false end
    until player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChildOfClass("Humanoid") and player.Character.Humanoid.Health > 0
    task.wait(1)
    return true
end

local function CompleteCharacterReset(char)
    if not char or not char:IsDescendantOf(workspace) then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then return end
    task.spawn(function()
        pcall(function()
            humanoid.PlatformStand = false
            humanoid.AutoRotate = true
            humanoid.WalkSpeed = State.CurrentWalkSpeed
            humanoid.JumpPower = State.prePauseJumpPower or 50
            humanoid.Sit = false
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end)
    end)
end

-- ========================================
-- HUMANOID STATE UTILITIES
-- ========================================
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

local function SaveHumanoidState()
    pcall(function()
        local char = player.Character
        if not char then return end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            State.prePauseAutoRotate = humanoid.AutoRotate
            State.prePauseWalkSpeed = humanoid.WalkSpeed
            State.prePauseJumpPower = humanoid.JumpPower
            State.prePausePlatformStand = humanoid.PlatformStand
            State.prePauseSit = humanoid.Sit
            State.prePauseHumanoidState = humanoid:GetState()
            if State.prePauseHumanoidState == Enum.HumanoidStateType.Climbing then
                humanoid.PlatformStand = false
                humanoid.AutoRotate = false
            end
        end
    end)
end

local function RestoreHumanoidState()
    pcall(function()
        local char = player.Character
        if not char then return end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            if State.prePauseHumanoidState == Enum.HumanoidStateType.Climbing then
                humanoid.PlatformStand = false
                humanoid.AutoRotate = false
                humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
            else
                humanoid.AutoRotate = State.prePauseAutoRotate
                humanoid.WalkSpeed = State.prePauseWalkSpeed
                humanoid.JumpPower = State.prePauseJumpPower
                humanoid.PlatformStand = State.prePausePlatformStand
                humanoid.Sit = State.prePauseSit
            end
        end
    end)
end

local function RestoreFullUserControl()
    pcall(function()
        local char = player.Character
        if not char then return end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if humanoid then
            humanoid.AutoRotate = true
            humanoid.WalkSpeed = State.CurrentWalkSpeed
            humanoid.JumpPower = State.prePauseJumpPower or 50
            humanoid.PlatformStand = false
            humanoid.Sit = false
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
        if State.ShiftLockEnabled then
            EnableVisibleShiftLock()
        end
    end)
end

-- ========================================
-- SHIFT LOCK SYSTEM
-- ========================================
local function ApplyVisibleShiftLock()
    if not State.ShiftLockEnabled or not player.Character then return end
    pcall(function()
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
    end)
end

function EnableVisibleShiftLock()
    if Connections.shiftLock or not State.ShiftLockEnabled then return end
    pcall(function()
        State.originalMouseBehavior = UserInputService.MouseBehavior
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        State.isShiftLockActive = true
        Connections.shiftLock = RunService.RenderStepped:Connect(function()
            if State.ShiftLockEnabled and player.Character then
                ApplyVisibleShiftLock()
            end
        end)
        AddConnection(Connections.shiftLock)
        PlaySound("Toggle")
    end)
end

function DisableVisibleShiftLock()
    pcall(function()
        if Connections.shiftLock then
            Connections.shiftLock:Disconnect()
            Connections.shiftLock = nil
        end
        if State.originalMouseBehavior then
            UserInputService.MouseBehavior = State.originalMouseBehavior
        end
        local char = player.Character
        if char and char:FindFirstChildOfClass("Humanoid") then
            char.Humanoid.AutoRotate = true
        end
        State.isShiftLockActive = false
        PlaySound("Toggle")
    end)
end

local function ToggleVisibleShiftLock()
    State.ShiftLockEnabled = not State.ShiftLockEnabled
    if State.ShiftLockEnabled then
        EnableVisibleShiftLock()
    else
        DisableVisibleShiftLock()
    end
end

-- ========================================
-- INFINITE JUMP SYSTEM
-- ========================================
local function EnableInfiniteJump()
    if Connections.jump then return end
    Connections.jump = UserInputService.JumpRequest:Connect(function()
        if State.InfiniteJump and player.Character then
            pcall(function()
                local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end)
        end
    end)
    AddConnection(Connections.jump)
end

local function DisableInfiniteJump()
    if Connections.jump then
        pcall(function() Connections.jump:Disconnect() end)
        Connections.jump = nil
    end
end

local function ToggleInfiniteJump()
    State.InfiniteJump = not State.InfiniteJump
    if State.InfiniteJump then
        EnableInfiniteJump()
    else
        DisableInfiniteJump()
    end
end

-- ========================================
-- FRAME DATA UTILITIES
-- ========================================
local function GetFrameCFrame(frame)
    local pos = Vector3.new(frame.Position[1], frame.Position[2], frame.Position[3])
    local look = Vector3.new(frame.LookVector[1], frame.LookVector[2], frame.LookVector[3])
    local up = Vector3.new(frame.UpVector[1], frame.UpVector[2], frame.UpVector[3])
    return CFrame.lookAt(pos, pos + look, up)
end

local function GetFrameVelocity(frame)
    return frame.Velocity and Vector3.new(
        frame.Velocity[1] * CONFIG.Velocity.SCALE,
        frame.Velocity[2] * CONFIG.Velocity.Y_SCALE,
        frame.Velocity[3] * CONFIG.Velocity.SCALE
    ) or Vector3.new(0, 0, 0)
end

local function GetFrameWalkSpeed(frame)
    return frame.WalkSpeed or 16
end

local function GetFrameTimestamp(frame)
    return frame.Timestamp or 0
end

local function GetFramePosition(frame)
    return Vector3.new(frame.Position[1], frame.Position[2], frame.Position[3])
end

-- ========================================
-- OBFUSCATION SYSTEM
-- ========================================
local function ObfuscateRecordingData(recordingData)
    local obfuscated = {}
    for checkpointName, frames in pairs(recordingData) do
        local obfuscatedFrames = {}
        for _, frame in ipairs(frames) do
            local obfuscatedFrame = {}
            for fieldName, fieldValue in pairs(frame) do
                local code = FIELD_MAPPING[fieldName]
                if code then
                    obfuscatedFrame[code] = fieldValue
                else
                    obfuscatedFrame[fieldName] = fieldValue
                end
            end
            table.insert(obfuscatedFrames, obfuscatedFrame)
        end
        obfuscated[checkpointName] = obfuscatedFrames
    end
    return obfuscated
end

local function DeobfuscateRecordingData(obfuscatedData)
    local deobfuscated = {}
    for checkpointName, frames in pairs(obfuscatedData) do
        local deobfuscatedFrames = {}
        for _, frame in ipairs(frames) do
            local deobfuscatedFrame = {}
            for code, fieldValue in pairs(frame) do
                local fieldName = REVERSE_MAPPING[code]
                if fieldName then
                    deobfuscatedFrame[fieldName] = fieldValue
                else
                    deobfuscatedFrame[code] = fieldValue
                end
            end
            table.insert(deobfuscatedFrames, deobfuscatedFrame)
        end
        deobfuscated[checkpointName] = deobfuscatedFrames
    end
    return deobfuscated
end

-- ========================================
-- PATH VISUALIZATION
-- ========================================
local function ClearPathVisualization()
    pcall(function()
        for _, part in pairs(Visualization.PathVisualization) do
            if part and part.Parent then
                part:Destroy()
            end
        end
        Visualization.PathVisualization = {}
        if Visualization.CurrentPauseMarker and Visualization.CurrentPauseMarker.Parent then
            Visualization.CurrentPauseMarker:Destroy()
            Visualization.CurrentPauseMarker = nil
        end
    end)
end

local function CreatePathSegment(startPos, endPos, color)
    local success, part = pcall(function()
        local p = Instance.new("Part")
        p.Name = "PathSegment"
        p.Anchored = true
        p.CanCollide = false
        p.Material = Enum.Material.Neon
        p.BrickColor = color or BrickColor.new("Really black")
        p.Transparency = 0.2
        local distance = (startPos - endPos).Magnitude
        p.Size = Vector3.new(0.2, 0.2, distance)
        p.CFrame = CFrame.lookAt((startPos + endPos) / 2, endPos)
        p.Parent = workspace
        table.insert(Visualization.PathVisualization, p)
        return p
    end)
    return success and part or nil
end

local function VisualizeAllPaths()
    ClearPathVisualization()
    
    if not State.ShowPaths then return end
    
    pcall(function()
        for _, name in ipairs(Data.RecordingOrder) do
            if Data.PathHasBeenUsed[name] then continue end
            
            local recording = Data.RecordedMovements[name]
            if not recording or #recording < 2 then continue end
            
            local previousPos = Vector3.new(
                recording[1].Position[1],
                recording[1].Position[2], 
                recording[1].Position[3]
            )
            
            for i = 2, #recording, 3 do
                local frame = recording[i]
                local currentPos = Vector3.new(frame.Position[1], frame.Position[2], frame.Position[3])
                
                if (currentPos - previousPos).Magnitude > 0.5 then
                    CreatePathSegment(previousPos, currentPos)
                    previousPos = currentPos
                end
            end
        end
    end)
end

local function CheckIfPathUsed(recordingName)
    if not recordingName then return end
    if not State.CurrentPlayingRecording then return end
    
    local recording = Data.RecordedMovements[recordingName]
    if not recording or #recording == 0 then return end
    
    if Data.PathHasBeenUsed[recordingName] then return end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local lastFrame = recording[#recording]
    local lastPos = GetFramePosition(lastFrame)
    local currentPos = char.HumanoidRootPart.Position
    local distance = (currentPos - lastPos).Magnitude
    
    if distance < 10 and State.currentPlaybackFrame >= (#recording - 5) then
        Data.PathHasBeenUsed[recordingName] = true
        
        local allPathsUsed = true
        for _, name in ipairs(Data.RecordingOrder) do
            if not Data.PathHasBeenUsed[name] then
                allPathsUsed = false
                break
            end
        end
        
        if allPathsUsed and State.ShowPaths and not Data.PathsHiddenOnce then
            Data.PathsHiddenOnce = true
            State.ShowPaths = false
            ClearPathVisualization()
            if ShowRuteBtnControl then
                ShowRuteBtnControl.Text = "Path OFF"
                ShowRuteBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
            end
        end
    end
end

-- ========================================
-- LAG COMPENSATION SYSTEM
-- ========================================
local function DetectAndCompensateLag(frames)
    if not frames or #frames < 3 then return frames end
    
    local compensatedFrames = {}
    local lagDetected = false
    
    for i = 1, #frames do
        local frame = frames[i]
        
        if i > 1 then
            local timeDiff = frame.Timestamp - frames[i-1].Timestamp
            local expectedDiff = 1 / CONFIG.Recording.FPS
            
            if timeDiff > CONFIG.LagCompensation.DETECTION_THRESHOLD then
                lagDetected = true
                
                local missedFrames = math.floor(timeDiff / expectedDiff) - 1
                local framesToInterpolate = math.min(missedFrames, CONFIG.LagCompensation.MAX_FRAMES_TO_SKIP)
                
                if CONFIG.LagCompensation.INTERPOLATE_AFTER_LAG and framesToInterpolate > 0 then
                    local prevFrame = frames[i-1]
                    local nextFrame = frame
                    
                    for j = 1, framesToInterpolate do
                        local alpha = j / (framesToInterpolate + 1)
                        
                        local pos1 = Vector3.new(prevFrame.Position[1], prevFrame.Position[2], prevFrame.Position[3])
                        local pos2 = Vector3.new(nextFrame.Position[1], nextFrame.Position[2], nextFrame.Position[3])
                        local interpPos = pos1:Lerp(pos2, alpha)
                        
                        local look1 = Vector3.new(prevFrame.LookVector[1], prevFrame.LookVector[2], prevFrame.LookVector[3])
                        local look2 = Vector3.new(nextFrame.LookVector[1], nextFrame.LookVector[2], nextFrame.LookVector[3])
                        local interpLook = look1:Lerp(look2, alpha).Unit
                        
                        local up1 = Vector3.new(prevFrame.UpVector[1], prevFrame.UpVector[2], prevFrame.UpVector[3])
                        local up2 = Vector3.new(nextFrame.UpVector[1], nextFrame.UpVector[2], nextFrame.UpVector[3])
                        local interpUp = up1:Lerp(up2, alpha).Unit
                        
                        local vel1 = Vector3.new(prevFrame.Velocity[1], prevFrame.Velocity[2], prevFrame.Velocity[3])
                        local vel2 = Vector3.new(nextFrame.Velocity[1], nextFrame.Velocity[2], nextFrame.Velocity[3])
                        local interpVel = vel1:Lerp(vel2, alpha)
                        
                        local interpWS = prevFrame.WalkSpeed + (nextFrame.WalkSpeed - prevFrame.WalkSpeed) * alpha
                        
                        table.insert(compensatedFrames, {
                            Position = {interpPos.X, interpPos.Y, interpPos.Z},
                            LookVector = {interpLook.X, interpLook.Y, interpLook.Z},
                            UpVector = {interpUp.X, interpUp.Y, interpUp.Z},
                            Velocity = {interpVel.X, interpVel.Y, interpVel.Z},
                            MoveState = prevFrame.MoveState,
                            WalkSpeed = interpWS,
                            Timestamp = prevFrame.Timestamp + (j * expectedDiff),
                            IsInterpolated = true
                        })
                    end
                end
            end
        end
        
        table.insert(compensatedFrames, frame)
    end
    
    return compensatedFrames, lagDetected
end

-- ========================================
-- GAP DETECTION & BLENDING
-- ========================================
local function DetectAndBlendGaps(frames)
    if not frames or #frames < 2 then return frames end
    
    local blendedFrames = {}
    local lastFrame = nil
    
    for i, frame in ipairs(frames) do
        if i == 1 then
            table.insert(blendedFrames, frame)
            lastFrame = frame
        else
            local timeDiff = frame.Timestamp - lastFrame.Timestamp
            local expectedDiff = 1 / CONFIG.Recording.FPS
            
            if timeDiff > (expectedDiff * 3) and timeDiff < CONFIG.Recording.GAP_DETECTION_TIME then
                local gapFrames = math.floor(timeDiff / expectedDiff) - 1
                local framesToBlend = math.min(gapFrames, CONFIG.Recording.GAP_BLEND_FRAMES)
                
                local sameState = (lastFrame.MoveState == frame.MoveState)
                
                if sameState and (lastFrame.MoveState == "Grounded" or lastFrame.MoveState == "Climbing" or lastFrame.MoveState == "Jumping" or lastFrame.MoveState == "Falling") then
                    for j = 1, framesToBlend do
                        local alpha = j / (framesToBlend + 1)
                        alpha = alpha * alpha * (3 - 2 * alpha)
                        
                        local pos1 = Vector3.new(lastFrame.Position[1], lastFrame.Position[2], lastFrame.Position[3])
                        local pos2 = Vector3.new(frame.Position[1], frame.Position[2], frame.Position[3])
                        local interpPos = pos1:Lerp(pos2, alpha)
                        
                        local look1 = Vector3.new(lastFrame.LookVector[1], lastFrame.LookVector[2], lastFrame.LookVector[3])
                        local look2 = Vector3.new(frame.LookVector[1], frame.LookVector[2], frame.LookVector[3])
                        local interpLook = look1:Lerp(look2, alpha).Unit
                        
                        local up1 = Vector3.new(lastFrame.UpVector[1], lastFrame.UpVector[2], lastFrame.UpVector[3])
                        local up2 = Vector3.new(frame.UpVector[1], frame.UpVector[2], frame.UpVector[3])
                        local interpUp = up1:Lerp(up2, alpha).Unit
                        
                        local vel1 = Vector3.new(lastFrame.Velocity[1], lastFrame.Velocity[2], lastFrame.Velocity[3])
                        local vel2 = Vector3.new(frame.Velocity[1], frame.Velocity[2], frame.Velocity[3])
                        local interpVel = vel1:Lerp(vel2, alpha)
                        
                        local interpWS = lastFrame.WalkSpeed + (frame.WalkSpeed - lastFrame.WalkSpeed) * alpha
                        
                        table.insert(blendedFrames, {
                            Position = {interpPos.X, interpPos.Y, interpPos.Z},
                            LookVector = {interpLook.X, interpLook.Y, interpLook.Z},
                            UpVector = {interpUp.X, interpUp.Y, interpUp.Z},
                            Velocity = {interpVel.X, interpVel.Y, interpVel.Z},
                            MoveState = lastFrame.MoveState,
                            WalkSpeed = interpWS,
                            Timestamp = lastFrame.Timestamp + (j * expectedDiff),
                            IsGapBlend = true
                        })
                    end
                end
            end
            
            table.insert(blendedFrames, frame)
            lastFrame = frame
        end
    end
    
    return blendedFrames
end

-- ========================================
-- FRAME SMOOTHING
-- ========================================
local function SmoothFrames(frames)
    if not CONFIG.Smoothing.ENABLE or #frames < CONFIG.Smoothing.WINDOW * 2 then 
        return frames 
    end
    
    local smoothedFrames = {}
    local halfWindow = math.floor(CONFIG.Smoothing.WINDOW / 2)
    
    for i = 1, #frames do
        if i <= halfWindow or i > (#frames - halfWindow) then
            table.insert(smoothedFrames, frames[i])
        else
            local avgPos = Vector3.zero
            local avgLook = Vector3.zero
            local avgUp = Vector3.zero
            local avgVel = Vector3.zero
            local avgWS = 0
            local count = 0
            
            for j = -halfWindow, halfWindow do
                local idx = i + j
                if idx >= 1 and idx <= #frames then
                    local f = frames[idx]
                    avgPos = avgPos + Vector3.new(f.Position[1], f.Position[2], f.Position[3])
                    avgLook = avgLook + Vector3.new(f.LookVector[1], f.LookVector[2], f.LookVector[3])
                    avgUp = avgUp + Vector3.new(f.UpVector[1], f.UpVector[2], f.UpVector[3])
                    avgVel = avgVel + Vector3.new(f.Velocity[1], f.Velocity[2], f.Velocity[3])
                    avgWS = avgWS + f.WalkSpeed
                    count = count + 1
                end
            end
            
            avgPos = avgPos / count
            avgLook = (avgLook / count).Unit
            avgUp = (avgUp / count).Unit
            avgVel = avgVel / count
            avgWS = avgWS / count
            
            local smoothedFrame = {
                Position = {avgPos.X, avgPos.Y, avgPos.Z},
                LookVector = {avgLook.X, avgLook.Y, avgLook.Z},
                UpVector = {avgUp.X, avgUp.Y, avgUp.Z},
                Velocity = {avgVel.X, avgVel.Y, avgVel.Z},
                MoveState = frames[i].MoveState,
                WalkSpeed = avgWS,
                Timestamp = frames[i].Timestamp,
                IsSmoothed = true
            }
            
            table.insert(smoothedFrames, smoothedFrame)
        end
    end
    
    return smoothedFrames
end

-- ========================================
-- TIMESTAMP NORMALIZATION
-- ========================================
local function NormalizeRecordingTimestamps(recording)
    if not recording or #recording == 0 then return recording end
    
    local lagCompensated, hadLag = DetectAndCompensateLag(recording)
    
    if hadLag then
        print("⚠️ Lag detected and compensated")
    end
    
    local gapBlended = DetectAndBlendGaps(lagCompensated)
    local smoothed = CONFIG.Smoothing.ENABLE and SmoothFrames(gapBlended) or gapBlended
    
    local normalized = {}
    local timeOffset = 0
    local lastValidTimestamp = 0
    
    for i, frame in ipairs(smoothed) do
        local newFrame = {
            Position = frame.Position,
            LookVector = frame.LookVector,
            UpVector = frame.UpVector,
            Velocity = frame.Velocity,
            MoveState = frame.MoveState,
            WalkSpeed = frame.WalkSpeed,
            Timestamp = 0,
            IsInterpolated = frame.IsInterpolated,
            IsSmoothed = frame.IsSmoothed,
            IsGapBlend = frame.IsGapBlend
        }
        
        if i == 1 then
            newFrame.Timestamp = 0
            lastValidTimestamp = 0
        else
            local originalTimeDiff = frame.Timestamp - smoothed[i-1].Timestamp
            
            if originalTimeDiff > CONFIG.LagCompensation.TIME_BYPASS_THRESHOLD then
                timeOffset = timeOffset + (originalTimeDiff - (1/CONFIG.Recording.FPS))
            end
            
            newFrame.Timestamp = frame.Timestamp - timeOffset
            lastValidTimestamp = newFrame.Timestamp
        end
        
        table.insert(normalized, newFrame)
    end
    
    return normalized
end

-- ========================================
-- SMART TRANSITION SYSTEM
-- ========================================
local function CreateSmartTransition(lastFrame, firstFrame, numFrames)
    local transitionFrames = {}
    local lastState = lastFrame.MoveState
    local nextState = firstFrame.MoveState
    
    if lastState == nextState then
        if lastState == "Grounded" or lastState == "Climbing" then
            numFrames = math.max(1, math.floor(numFrames * 0.3))
        elseif lastState == "Jumping" or lastState == "Falling" then
            numFrames = math.max(2, math.floor(numFrames * 0.5))
        end
    end
    
    for i = 1, numFrames do
        local alpha = i / (numFrames + 1)
        alpha = alpha * alpha * (3 - 2 * alpha)
        
        local pos1 = Vector3.new(lastFrame.Position[1], lastFrame.Position[2], lastFrame.Position[3])
        local pos2 = Vector3.new(firstFrame.Position[1], firstFrame.Position[2], firstFrame.Position[3])
        local lerpedPos = pos1:Lerp(pos2, alpha)
        
        local look1 = Vector3.new(lastFrame.LookVector[1], lastFrame.LookVector[2], lastFrame.LookVector[3])
        local look2 = Vector3.new(firstFrame.LookVector[1], firstFrame.LookVector[2], firstFrame.LookVector[3])
        local lerpedLook = look1:Lerp(look2, alpha).Unit
        
        local up1 = Vector3.new(lastFrame.UpVector[1], lastFrame.UpVector[2], lastFrame.UpVector[3])
        local up2 = Vector3.new(firstFrame.UpVector[1], firstFrame.UpVector[2], firstFrame.UpVector[3])
        local lerpedUp = up1:Lerp(up2, alpha).Unit
        
        local vel1 = Vector3.new(lastFrame.Velocity[1], lastFrame.Velocity[2], lastFrame.Velocity[3])
        local vel2 = Vector3.new(firstFrame.Velocity[1], firstFrame.Velocity[2], firstFrame.Velocity[3])
        local lerpedVel = vel1:Lerp(vel2, alpha)
        
        local ws1 = lastFrame.WalkSpeed
        local ws2 = firstFrame.WalkSpeed
        local lerpedWS = ws1 + (ws2 - ws1) * alpha
        
        table.insert(transitionFrames, {
            Position = {lerpedPos.X, lerpedPos.Y, lerpedPos.Z},
            LookVector = {lerpedLook.X, lerpedLook.Y, lerpedLook.Z},
            UpVector = {lerpedUp.X, lerpedUp.Y, lerpedUp.Z},
            Velocity = {lerpedVel.X, lerpedVel.Y, lerpedVel.Z},
            MoveState = lastState,
            WalkSpeed = lerpedWS,
            Timestamp = lastFrame.Timestamp + (i * 0.011),
            IsTransition = true
        })
    end
    return transitionFrames
end

-- ========================================
-- MERGE RECORDINGS SYSTEM (UPDATED)
-- ========================================
local function CreateMergedReplay()
    if #Data.RecordingOrder < 2 then
        PlaySound("Error")
        return
    end
    
    pcall(function()
        local mergedFrames = {}
        local totalTimeOffset = 0
        
        for _, checkpointName in ipairs(Data.RecordingOrder) do
            local checkpoint = Data.RecordedMovements[checkpointName]
            if not checkpoint or #checkpoint == 0 then continue end
            
            if #mergedFrames > 0 and #checkpoint > 0 then
                local lastFrame = mergedFrames[#mergedFrames]
                local firstFrame = checkpoint[1]
                
                local transitionCount = CONFIG.Transitions.FRAMES
                local lastState = lastFrame.MoveState
                local nextState = firstFrame.MoveState
                
                if lastState == nextState then
                    if lastState == "Grounded" or lastState == "Running" then
                        transitionCount = 1
                    elseif lastState == "Climbing" then
                        transitionCount = 2
                    elseif lastState == "Jumping" or lastState == "Falling" then
                        transitionCount = 2
                    end
                else
                    transitionCount = math.floor(CONFIG.Transitions.FRAMES * 0.6)
                end
                
                local transitionFrames = CreateSmartTransition(lastFrame, firstFrame, transitionCount)
                for _, tFrame in ipairs(transitionFrames) do
                    tFrame.Timestamp = tFrame.Timestamp + totalTimeOffset
                    table.insert(mergedFrames, tFrame)
                end
                totalTimeOffset = totalTimeOffset + (transitionCount * 0.011)
            end
            
            for frameIndex, frame in ipairs(checkpoint) do
                local newFrame = {
                    Position = {frame.Position[1], frame.Position[2], frame.Position[3]},
                    LookVector = {frame.LookVector[1], frame.LookVector[2], frame.LookVector[3]},
                    UpVector = {frame.UpVector[1], frame.UpVector[2], frame.UpVector[3]},
                    Velocity = {frame.Velocity[1], frame.Velocity[2], frame.Velocity[3]},
                    MoveState = frame.MoveState,
                    WalkSpeed = frame.WalkSpeed,
                    Timestamp = frame.Timestamp + totalTimeOffset
                }
                table.insert(mergedFrames, newFrame)
            end
            if #checkpoint > 0 then
                totalTimeOffset = totalTimeOffset + checkpoint[#checkpoint].Timestamp + 0.02
            end
        end
        
        local mergedName = "merged_" .. os.date("%H%M%S")
        Data.RecordedMovements[mergedName] = mergedFrames
        table.insert(Data.RecordingOrder, mergedName)
        Data.checkpointNames[mergedName] = "MERGED"
        UpdateRecordList()
        PlaySound("Success")
    end)
end

-- ========================================
-- SAVE/LOAD SYSTEM (UPDATED - ONLY CHECKED RECORDINGS)
-- ========================================
local function SaveToObfuscatedJSON()
    if not hasFileSystem then
        PlaySound("Error")
        return
    end
    
    local filename = FilenameBox.Text
    if filename == "" then filename = "MyReplays" end
    filename = filename .. ".json"
    
    local hasCheckedRecordings = false
    for name, checked in pairs(Data.CheckedRecordings) do
        if checked then
            hasCheckedRecordings = true
            break
        end
    end
    
    if not hasCheckedRecordings then
        PlaySound("Error")
        return
    end
    
    local success, err = pcall(function()
        local saveData = {
            Version = "3.0",
            Obfuscated = true,
            Checkpoints = {},
            RecordingOrder = {},
            CheckpointNames = {}
        }
        
        for _, name in ipairs(Data.RecordingOrder) do
            if Data.CheckedRecordings[name] then
                local frames = Data.RecordedMovements[name]
                if frames then
                    local checkpointData = {
                        Name = name,
                        DisplayName = Data.checkpointNames[name] or "checkpoint",
                        Frames = frames
                    }
                    table.insert(saveData.Checkpoints, checkpointData)
                    table.insert(saveData.RecordingOrder, name)
                    saveData.CheckpointNames[name] = Data.checkpointNames[name]
                end
            end
        end
        
        local recordingsToObfuscate = {}
        for _, name in ipairs(saveData.RecordingOrder) do
            recordingsToObfuscate[name] = Data.RecordedMovements[name]
        end
        
        local obfuscatedData = ObfuscateRecordingData(recordingsToObfuscate)
        saveData.ObfuscatedFrames = obfuscatedData
        
        local jsonString = HttpService:JSONEncode(saveData)
        
        writefile(filename, jsonString)
        PlaySound("Success")
    end)
    
    if not success then
        PlaySound("Error")
    end
end

local function LoadFromObfuscatedJSON()
    if not hasFileSystem then
        PlaySound("Error")
        return
    end
    
    local filename = FilenameBox.Text
    if filename == "" then filename = "MyReplays" end
    filename = filename .. ".json"
    
    local success, err = pcall(function()
        if not isfile(filename) then
            PlaySound("Error")
            return
        end
        
        local jsonString = readfile(filename)
        local saveData = HttpService:JSONDecode(jsonString)
        
        local newRecordingOrder = saveData.RecordingOrder or {}
        local newCheckpointNames = saveData.CheckpointNames or {}
        
        if saveData.Obfuscated and saveData.ObfuscatedFrames then
            local deobfuscatedData = DeobfuscateRecordingData(saveData.ObfuscatedFrames)
            
            for _, checkpointData in ipairs(saveData.Checkpoints or {}) do
                local name = checkpointData.Name
                local frames = deobfuscatedData[name]
                
                if frames then
                    Data.RecordedMovements[name] = frames
                    Data.checkpointNames[name] = newCheckpointNames[name] or checkpointData.DisplayName
                    
                    if not table.find(Data.RecordingOrder, name) then
                        table.insert(Data.RecordingOrder, name)
                    end
                end
            end
        end
        
        UpdateRecordList()
        PlaySound("Success")
    end)
    
    if not success then
        PlaySound("Error")
    end
end

-- ========================================
-- RECORDING FINDER UTILITIES
-- ========================================
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

local function FindNearestRecording(maxDistance)
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        return nil, math.huge, nil
    end
    
    local currentPos = char.HumanoidRootPart.Position
    local nearestRecording = nil
    local nearestDistance = math.huge
    local nearestName = nil
    
    for _, recordingName in ipairs(Data.RecordingOrder) do
        local recording = Data.RecordedMovements[recordingName]
        if recording and #recording > 0 then
            local nearestFrame, frameDistance = FindNearestFrame(recording, currentPos)
            
            if frameDistance < nearestDistance and frameDistance <= (maxDistance or 50) then
                nearestDistance = frameDistance
                nearestRecording = recording
                nearestName = recordingName
            end
        end
    end
    
    return nearestRecording, nearestDistance, nearestName
end

local function UpdatePlayButtonStatus()
    local nearestRecording, distance = FindNearestRecording(50)
    State.NearestRecordingDistance = distance or math.huge
    
    if PlayBtnControl then
        if nearestRecording and distance <= 50 then
            PlayBtnControl.Text = "PLAY (" .. math.floor(distance) .. "m)"
            PlayBtnControl.BackgroundColor3 = Color3.fromRGB(80, 180, 80)
        else
            PlayBtnControl.Text = "PLAY"
            PlayBtnControl.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
        end
    end
end

-- ========================================
-- HUMANOID STATE PROCESSING
-- ========================================
local function ProcessHumanoidState(hum, frame, lastState, lastStateTime)
    if not hum then return lastState, lastStateTime end
    
    local moveState = frame.MoveState
    local frameVelocity = GetFrameVelocity(frame)
    local currentTime = tick()
    
    local isJumpingByVelocity = frameVelocity.Y > CONFIG.Velocity.JUMP_THRESHOLD
    local isFallingByVelocity = frameVelocity.Y < -5
    
    if moveState == "Jumping" or isJumpingByVelocity then
        if lastState ~= "Jumping" then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
            return "Jumping", currentTime
        end
    elseif moveState == "Falling" or isFallingByVelocity then
        if lastState ~= "Falling" then
            hum:ChangeState(Enum.HumanoidStateType.Freefall)
            return "Falling", currentTime
        end
    else
        if moveState ~= lastState and (currentTime - lastStateTime) >= CONFIG.Transitions.STATE_CHANGE_COOLDOWN then
            if moveState == "Climbing" then
                hum:ChangeState(Enum.HumanoidStateType.Climbing)
                hum.PlatformStand = false
                hum.AutoRotate = false
            elseif moveState == "Swimming" then
                hum:ChangeState(Enum.HumanoidStateType.Swimming)
            else
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
            return moveState, currentTime
        end
    end
    
    return lastState, lastStateTime
end

-- ========================================
-- FRAME APPLICATION TO CHARACTER
-- ========================================
local function ApplyFrameToCharacter(frame)
    pcall(function()
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        
        if not hrp or not hum then return end
        
        task.spawn(function()
            local targetCFrame = GetFrameCFrame(frame)
            hrp.CFrame = targetCFrame
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            
            if hum then
                hum.WalkSpeed = 0
                hum.AutoRotate = false
                
                local moveState = frame.MoveState
                if moveState == "Climbing" then
                    hum:ChangeState(Enum.HumanoidStateType.Climbing)
                    hum.PlatformStand = false
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
        end)
    end)
end

-- ========================================
-- PLAYBACK SYSTEM - CORE FUNCTIONS
-- ========================================
function PlayFromSpecificFrame(recording, startFrame, recordingName)
    if State.IsPlaying or State.IsAutoLoopPlaying then return end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        PlaySound("Error")
        return
    end

    State.IsPlaying = true
    State.IsPaused = false
    State.CurrentPlayingRecording = recording
    State.PausedAtFrame = 0
    State.playbackAccumulator = 0
    State.previousFrameData = nil
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    local currentPos = hrp.Position
    local targetFrame = recording[startFrame]
    local targetPos = GetFramePosition(targetFrame)
    
    local distance = (currentPos - targetPos).Magnitude
    
    if distance > 3 then
        local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(hrp, tweenInfo, {CFrame = GetFrameCFrame(targetFrame)}):Play()
        task.wait(0.15)
    end
    
    State.currentPlaybackFrame = startFrame
    State.playbackStartTime = tick() - (GetFrameTimestamp(recording[startFrame]) / State.CurrentSpeed)
    State.totalPausedDuration = 0
    State.pauseStartTime = 0
    State.lastPlaybackState = nil
    State.lastStateChangeTime = 0

    SaveHumanoidState()
    
    local wasShiftLockEnabled = State.ShiftLockEnabled
    if State.ShiftLockEnabled then
        DisableVisibleShiftLock()
    end
    
    PlaySound("Play")
    
    PlayBtnControl.Text = "PAUSE"
    PlayBtnControl.BackgroundColor3 = Color3.fromRGB(200, 50, 60)

    Connections.playback = RunService.Heartbeat:Connect(function(deltaTime)
        pcall(function()
            if not State.IsPlaying then
                Connections.playback:Disconnect()
                RestoreFullUserControl()
                
                if wasShiftLockEnabled then
                    State.ShiftLockEnabled = true
                    EnableVisibleShiftLock()
                end
                
                CheckIfPathUsed(recordingName)
                State.lastPlaybackState = nil
                State.lastStateChangeTime = 0
                State.previousFrameData = nil
                PlayBtnControl.Text = "PLAY"
                PlayBtnControl.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
                UpdatePlayButtonStatus()
                return
            end
            
            local char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then
                State.IsPlaying = false
                if wasShiftLockEnabled then
                    State.ShiftLockEnabled = true
                    EnableVisibleShiftLock()
                end
                RestoreFullUserControl()
                CheckIfPathUsed(recordingName)
                State.lastPlaybackState = nil
                State.lastStateChangeTime = 0
                State.previousFrameData = nil
                PlayBtnControl.Text = "PLAY"
                PlayBtnControl.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
                UpdatePlayButtonStatus()
                return
            end
            
            local hum = char:FindFirstChildOfClass("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hum or not hrp then
                State.IsPlaying = false
                if wasShiftLockEnabled then
                    State.ShiftLockEnabled = true
                    EnableVisibleShiftLock()
                end
                RestoreFullUserControl()
                CheckIfPathUsed(recordingName)
                State.lastPlaybackState = nil
                State.lastStateChangeTime = 0
                State.previousFrameData = nil
                PlayBtnControl.Text = "PLAY"
                PlayBtnControl.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
                UpdatePlayButtonStatus()
                return
            end

            State.playbackAccumulator = State.playbackAccumulator + deltaTime
            
            while State.playbackAccumulator >= CONFIG.Playback.FIXED_TIMESTEP do
                State.playbackAccumulator = State.playbackAccumulator - CONFIG.Playback.FIXED_TIMESTEP
                 
                local currentTime = tick()
                local effectiveTime = (currentTime - State.playbackStartTime - State.totalPausedDuration) * State.CurrentSpeed
                
                local nextFrame = State.currentPlaybackFrame
                while nextFrame < #recording and GetFrameTimestamp(recording[nextFrame + 1]) <= effectiveTime do
                    nextFrame = nextFrame + 1
                end

                if nextFrame >= #recording then
                    State.IsPlaying = false
                    if wasShiftLockEnabled then
                        State.ShiftLockEnabled = true
                        EnableVisibleShiftLock()
                    end
                    RestoreFullUserControl()
                    CheckIfPathUsed(recordingName)
                    PlaySound("Success")
                    State.lastPlaybackState = nil
                    State.lastStateChangeTime = 0
                    State.previousFrameData = nil
                    PlayBtnControl.Text = "PLAY"
                    PlayBtnControl.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
                    UpdatePlayButtonStatus()
                    return
                end

                local frame = recording[nextFrame]
                if not frame then
                    State.IsPlaying = false
                    if wasShiftLockEnabled then
                        State.ShiftLockEnabled = true
                        EnableVisibleShiftLock()
                    end
                    RestoreFullUserControl()
                    CheckIfPathUsed(recordingName)
                    State.lastPlaybackState = nil
                    State.lastStateChangeTime = 0
                    State.previousFrameData = nil
                    PlayBtnControl.Text = "PLAY"
                    PlayBtnControl.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
                    UpdatePlayButtonStatus()
                    return
                end

                task.spawn(function()
                    local char = player.Character
                    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
                    
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    
                    if not hrp or not hum then return end
                    
                    hrp.CFrame = GetFrameCFrame(frame)
                    
                    if CONFIG.Playback.USE_VELOCITY then
                        hrp.AssemblyLinearVelocity = GetFrameVelocity(frame)
                    else
                        hrp.AssemblyLinearVelocity = Vector3.zero
                    end
                    hrp.AssemblyAngularVelocity = Vector3.zero
                    
                    if hum then
                        hum.WalkSpeed = GetFrameWalkSpeed(frame) * State.CurrentSpeed
                        hum.AutoRotate = false
                        
                        State.lastPlaybackState, State.lastStateChangeTime = ProcessHumanoidState(
                            hum, frame, State.lastPlaybackState, State.lastStateChangeTime
                        )
                    end
                end)
                
                State.previousFrameData = frame
                State.currentPlaybackFrame = nextFrame
            end
        end)
    end)
    
    AddConnection(Connections.playback)
    UpdatePlayButtonStatus()
end

function PlayRecording(name)
    if name then
        local recording = Data.RecordedMovements[name]
        if recording then
            PlayFromSpecificFrame(recording, 1, name)
        end
    else
        SmartPlayRecording(50)
    end
end

function SmartPlayRecording(maxDistance)
    if State.IsPlaying or State.IsAutoLoopPlaying then return end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        PlaySound("Error")
        return
    end

    local currentPos = char.HumanoidRootPart.Position
    local bestRecording = nil
    local bestFrame = 1
    local bestDistance = math.huge
    local bestRecordingName = nil
    
    for _, recordingName in ipairs(Data.RecordingOrder) do
        local recording = Data.RecordedMovements[recordingName]
        if recording and #recording > 0 then
            local nearestFrame, frameDistance = FindNearestFrame(recording, currentPos)
            
            if frameDistance < bestDistance and frameDistance <= (maxDistance or 50) then
                bestDistance = frameDistance
                bestRecording = recording
                bestFrame = nearestFrame
                bestRecordingName = recordingName
            end
        end
    end
    
    if bestRecording then
        PlayFromSpecificFrame(bestRecording, bestFrame, bestRecordingName)
    else
        local firstRecording = Data.RecordingOrder[1] and Data.RecordedMovements[Data.RecordingOrder[1]]
        if firstRecording then
            PlayFromSpecificFrame(firstRecording, 1, Data.RecordingOrder[1])
        else
            PlaySound("Error")
        end
    end
end

function StopPlayback()
    if State.AutoLoop then
        StopAutoLoopAll()
        LoopBtnControl.Text = "Loop OFF"
        LoopBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    end
    
    if not State.IsPlaying and not State.IsAutoLoopPlaying then return end
    
    State.IsPlaying = false
    State.IsAutoLoopPlaying = false
    State.IsLoopTransitioning = false
    State.lastPlaybackState = nil
    State.lastStateChangeTime = 0
    State.LastPausePosition = nil
    State.LastPauseRecording = nil
    
    if Connections.playback then
        Connections.playback:Disconnect()
        Connections.playback = nil
    end
    
    if Connections.loop then
        pcall(function() task.cancel(Connections.loop) end)
        Connections.loop = nil
    end
    
    RestoreFullUserControl()
    
    local char = player.Character
    if char then CompleteCharacterReset(char) end
    
    PlaySound("Stop")
    PlayBtnControl.Text = "PLAY"
    PlayBtnControl.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
    UpdatePlayButtonStatus()
end

-- ========================================
-- AUTO LOOP SYSTEM
-- ========================================
function StartAutoLoopAll()
    if not State.AutoLoop then return end
    
    if #Data.RecordingOrder == 0 then
        State.AutoLoop = false
        LoopBtnControl.Text = "Loop OFF"
        LoopBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        PlaySound("Error")
        return
    end
    
    if State.IsPlaying then
        State.IsPlaying = false
        if Connections.playback then
            Connections.playback:Disconnect()
            Connections.playback = nil
        end
    end
    
    PlaySound("Play")
    
    if State.CurrentLoopIndex == 0 or State.CurrentLoopIndex > #Data.RecordingOrder then
        local nearestRecording, distance, nearestName = FindNearestRecording(50)
        if nearestRecording then
            State.CurrentLoopIndex = table.find(Data.RecordingOrder, nearestName) or 1
        else
            State.CurrentLoopIndex = 1
        end
    end
    
    State.IsAutoLoopPlaying = true
    State.LoopRetryAttempts = 0
    State.lastPlaybackState = nil
    State.lastStateChangeTime = 0
    
    PlayBtnControl.Text = "STOP"
    PlayBtnControl.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
    
    Connections.loop = task.spawn(function()
        while State.AutoLoop and State.IsAutoLoopPlaying do
            if not State.AutoLoop or not State.IsAutoLoopPlaying then break end
            
            local recordingToPlay = nil
            local recordingNameToPlay = nil
            local searchAttempts = 0
            
            while searchAttempts < #Data.RecordingOrder do
                recordingNameToPlay = Data.RecordingOrder[State.CurrentLoopIndex]
                recordingToPlay = Data.RecordedMovements[recordingNameToPlay]
                
                if recordingToPlay and #recordingToPlay > 0 then
                    break
                else
                    State.CurrentLoopIndex = State.CurrentLoopIndex + 1
                    if State.CurrentLoopIndex > #Data.RecordingOrder then
                        State.CurrentLoopIndex = 1
                    end
                    searchAttempts = searchAttempts + 1
                end
            end
            
            if not recordingToPlay or #recordingToPlay == 0 then
                State.CurrentLoopIndex = 1
                task.wait(1)
                continue
            end
            
            if not IsCharacterReady() then
                if State.AutoRespawn then
                    ResetCharacter()
                    local success = WaitForRespawn()
                    if not success then
                        task.wait(CONFIG.AutoLoop.RETRY_DELAY)
                        continue
                    end
                    task.wait(0.5)
                else
                    local waitTime = 0
                    local maxWaitTime = 30
                    
                    while not IsCharacterReady() and State.AutoLoop and State.IsAutoLoopPlaying do
                        waitTime = waitTime + 0.5
                        if waitTime >= maxWaitTime then
                            break
                        end
                        task.wait(0.5)
                    end
                    
                    if not State.AutoLoop or not State.IsAutoLoopPlaying then break end
                    if not IsCharacterReady() then
                        task.wait(CONFIG.AutoLoop.RETRY_DELAY)
                        continue
                    end
                    task.wait(0.5)
                end
            end
            
            if not State.AutoLoop or not State.IsAutoLoopPlaying then break end
            
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local targetCFrame = GetFrameCFrame(recordingToPlay[1])
                hrp.CFrame = targetCFrame
                hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                task.wait(0.15)
            end
            
            local playbackCompleted = false
            local currentFrame = 1
            local playbackStartTime = tick()
            local loopAccumulator = 0
            
            State.lastPlaybackState = nil
            State.lastStateChangeTime = 0
            
            SaveHumanoidState()
            
            State.IsLoopTransitioning = false
            
            while State.AutoLoop and State.IsAutoLoopPlaying and currentFrame <= #recordingToPlay do
                
                if not IsCharacterReady() then
                    
                    if State.AutoRespawn then
                        ResetCharacter()
                        local success = WaitForRespawn()
                        
                        if success then
                            RestoreFullUserControl()
                            task.wait(0.5)
                            
                            currentFrame = 1
                            playbackStartTime = tick()
                            State.lastPlaybackState = nil
                            State.lastStateChangeTime = 0
                            loopAccumulator = 0
                            
                            SaveHumanoidState()
                            
                            local char = player.Character
                            if char and char:FindFirstChild("HumanoidRootPart") then
                                char.HumanoidRootPart.CFrame = GetFrameCFrame(recordingToPlay[1])
                                task.wait(0.1)
                            end
                            
                            continue
                        else
                            task.wait(CONFIG.AutoLoop.RETRY_DELAY)
                            continue
                        end
                    else
                        local manualRespawnWait = 0
                        local maxManualWait = 30
                        
                        while not IsCharacterReady() and State.AutoLoop and State.IsAutoLoopPlaying do
                            manualRespawnWait = manualRespawnWait + 0.5
                            if manualRespawnWait >= maxManualWait then
                                break
                            end
                            task.wait(0.5)
                        end
                        
                        if not State.AutoLoop or not State.IsAutoLoopPlaying then break end
                        if not IsCharacterReady() then
                            break
                        end
                        
                        RestoreFullUserControl()
                        task.wait(0.5)
                        
                        currentFrame = 1
                        playbackStartTime = tick()
                        State.lastPlaybackState = nil
                        State.lastStateChangeTime = 0
                        loopAccumulator = 0
                        
                        SaveHumanoidState()
                        continue
                    end
                end
                
                local char = player.Character
                if not char or not char:FindFirstChild("HumanoidRootPart") then
                    task.wait(0.5)
                    break
                end
                
                local hum = char:FindFirstChildOfClass("Humanoid")
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if not hum or not hrp then
                    task.wait(0.5)
                    break
                end
                
                local deltaTime = task.wait()
                loopAccumulator = loopAccumulator + deltaTime
                
                if loopAccumulator >= CONFIG.Playback.FIXED_TIMESTEP then
                    loopAccumulator = loopAccumulator - CONFIG.Playback.FIXED_TIMESTEP
                    
                    local currentTime = tick()
                    local effectiveTime = (currentTime - playbackStartTime) * State.CurrentSpeed
                    
                    local targetFrame = currentFrame
                    for i = currentFrame, #recordingToPlay do
                        if GetFrameTimestamp(recordingToPlay[i]) <= effectiveTime then
                            targetFrame = i
                        else
                            break
                        end
                    end
                    
                    currentFrame = targetFrame
                    
                    if currentFrame >= #recordingToPlay then
                        playbackCompleted = true
                    end
                    
                    if not playbackCompleted then
                        local frame = recordingToPlay[currentFrame]
                        if frame then
                            hrp.CFrame = GetFrameCFrame(frame)
                            
                            if CONFIG.Playback.USE_VELOCITY then
                                hrp.AssemblyLinearVelocity = GetFrameVelocity(frame)
                            else
                                hrp.AssemblyLinearVelocity = Vector3.zero
                            end
                            hrp.AssemblyAngularVelocity = Vector3.zero
                            
                            if hum then
                                hum.WalkSpeed = GetFrameWalkSpeed(frame) * State.CurrentSpeed
                                hum.AutoRotate = false
                                
                                State.lastPlaybackState, State.lastStateChangeTime = ProcessHumanoidState(
                                    hum, frame, State.lastPlaybackState, State.lastStateChangeTime
                                )
                            end
                        end
                    end
                end
                
                if playbackCompleted then
                    break
                end
            end
            
            RestoreFullUserControl()
            State.lastPlaybackState = nil
            State.lastStateChangeTime = 0
            
            if playbackCompleted then
                PlaySound("Success")
                CheckIfPathUsed(recordingNameToPlay)
                
                local isLastRecording = (State.CurrentLoopIndex >= #Data.RecordingOrder)
                
                if State.AutoReset and isLastRecording then
                    ResetCharacter()
                    local success = WaitForRespawn()
                    if success then
                        task.wait(0.5)
                    end
                end
                
                State.CurrentLoopIndex = State.CurrentLoopIndex + 1
                if State.CurrentLoopIndex > #Data.RecordingOrder then
                    State.CurrentLoopIndex = 1
                    
                    if State.AutoLoop and State.IsAutoLoopPlaying then
                        State.IsLoopTransitioning = true
                        task.wait(CONFIG.Transitions.LOOP_DELAY)
                        State.IsLoopTransitioning = false
                    end
                end
                
                if not State.AutoLoop or not State.IsAutoLoopPlaying then break end
            else
                if not State.AutoLoop or not State.IsAutoLoopPlaying then
                    break
                else
                    State.CurrentLoopIndex = State.CurrentLoopIndex + 1
                    if State.CurrentLoopIndex > #Data.RecordingOrder then
                        State.CurrentLoopIndex = 1
                    end
                    task.wait(CONFIG.AutoLoop.RETRY_DELAY)
                end
            end
        end
        
        State.IsAutoLoopPlaying = false
        State.IsLoopTransitioning = false
        RestoreFullUserControl()
        State.lastPlaybackState = nil
        State.lastStateChangeTime = 0
        PlayBtnControl.Text = "PLAY"
        PlayBtnControl.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
        UpdatePlayButtonStatus()
    end)
end

function StopAutoLoopAll()
    State.AutoLoop = false
    State.IsAutoLoopPlaying = false
    State.IsPlaying = false
    State.IsLoopTransitioning = false
    State.lastPlaybackState = nil
    State.lastStateChangeTime = 0
    
    if Connections.loop then
        pcall(function() task.cancel(Connections.loop) end)
        Connections.loop = nil
    end
    
    if Connections.playback then
        Connections.playback:Disconnect()
        Connections.playback = nil
    end
    
    RestoreFullUserControl()
    
    pcall(function()
        local char = player.Character
        if char then CompleteCharacterReset(char) end
    end)
    
    PlaySound("Stop")
    PlayBtnControl.Text = "PLAY"
    PlayBtnControl.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
    UpdatePlayButtonStatus()
end

-- ========================================
-- STUDIO RECORDING SYSTEM
-- ========================================
local function UpdateStudioUI()
    -- Clean interface
end

local function StartStudioRecording()
    if State.StudioIsRecording then return end
    
    task.spawn(function()
        pcall(function()
            local char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then
                PlaySound("Error")
                return
            end
            
            State.StudioIsRecording = true
            State.IsTimelineMode = false
            State.StudioCurrentRecording = {Frames = {}, StartTime = tick(), Name = "recording_" .. os.date("%H%M%S")}
            State.lastStudioRecordTime = 0
            State.lastStudioRecordPos = nil
            State.CurrentTimelineFrame = 0
            State.TimelinePosition = 0
            State.lastRecordedState = nil
            
            StartBtn.Text = "STOP"
            StartBtn.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
            
            PlaySound("RecordStart")
            
            Connections.record = RunService.Heartbeat:Connect(function()
                task.spawn(function()
                    pcall(function()
                        local char = player.Character
                        if not char or not char:FindFirstChild("HumanoidRootPart") or #State.StudioCurrentRecording.Frames >= CONFIG.Recording.MAX_FRAMES then
                            return
                        end
                        
                        local hrp = char.HumanoidRootPart
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        
                        if State.IsTimelineMode then
                            return
                        end
                        
                        local now = tick()
                        if (now - State.lastStudioRecordTime) < (1 / CONFIG.Recording.FPS) then return end
                        
                        local currentPos = hrp.Position
                        local currentVelocity = hrp.AssemblyLinearVelocity
                        local currentState = GetCurrentMoveState(hum)
                        
                        if State.lastStudioRecordPos and (currentPos - State.lastStudioRecordPos).Magnitude < CONFIG.Recording.MIN_DISTANCE_THRESHOLD then
                            State.lastStudioRecordTime = now
                            return
                        end
                        
                        local cf = hrp.CFrame
                        table.insert(State.StudioCurrentRecording.Frames, {
                            Position = {cf.Position.X, cf.Position.Y, cf.Position.Z},
                            LookVector = {cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z},
                            UpVector = {cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z},
                            Velocity = {currentVelocity.X, currentVelocity.Y, currentVelocity.Z},
                            MoveState = currentState,
                            WalkSpeed = hum and hum.WalkSpeed or 16,
                            Timestamp = now - State.StudioCurrentRecording.StartTime
                        })
                        
                        State.lastStudioRecordTime = now
                        State.lastStudioRecordPos = currentPos
                        State.lastRecordedState = currentState
                        State.CurrentTimelineFrame = #State.StudioCurrentRecording.Frames
                        State.TimelinePosition = State.CurrentTimelineFrame
                        
                        UpdateStudioUI()
                    end)
                end)
            end)
            AddConnection(Connections.record)
        end)
    end)
end

local function StopStudioRecording()
    State.StudioIsRecording = false
    State.IsTimelineMode = false
    
    task.spawn(function()
        pcall(function()
            if Connections.record then
                Connections.record:Disconnect()
                Connections.record = nil
            end
            
            StartBtn.Text = "START"
            StartBtn.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
            
            PlaySound("RecordStop")
            UpdateStudioUI()
        end)
    end)
end

local function GoBackTimeline()
    if not State.StudioIsRecording or #State.StudioCurrentRecording.Frames == 0 then
        PlaySound("Error")
        return
    end
    
    task.spawn(function()
        pcall(function()
            State.IsTimelineMode = true
            
            local targetFrame = math.max(1, State.TimelinePosition - math.floor(CONFIG.Recording.FPS * CONFIG.Recording.TIMELINE_STEP_SECONDS))
            
            State.TimelinePosition = targetFrame
            State.CurrentTimelineFrame = targetFrame
            
            local frame = State.StudioCurrentRecording.Frames[targetFrame]
            if frame then
                ApplyFrameToCharacter(frame)
                UpdateStudioUI()
                PlaySound("Click")
            end
        end)
    end)
end

local function GoNextTimeline()
    if not State.StudioIsRecording or #State.StudioCurrentRecording.Frames == 0 then
        PlaySound("Error")
        return
    end
    
    task.spawn(function()
        pcall(function()
            State.IsTimelineMode = true
            
            local targetFrame = math.min(#State.StudioCurrentRecording.Frames, State.TimelinePosition + math.floor(CONFIG.Recording.FPS * CONFIG.Recording.TIMELINE_STEP_SECONDS))
            
            State.TimelinePosition = targetFrame
            State.CurrentTimelineFrame = targetFrame
            
            local frame = State.StudioCurrentRecording.Frames[targetFrame]
            if frame then
                ApplyFrameToCharacter(frame)
                UpdateStudioUI()
                PlaySound("Click")
            end
        end)
    end)
end

local function ResumeStudioRecording()
    if not State.StudioIsRecording then
        PlaySound("Error")
        return
    end
    
    task.spawn(function()
        pcall(function()
            if #State.StudioCurrentRecording.Frames == 0 then
                PlaySound("Error")
                return
            end
            
            local char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then
                PlaySound("Error")
                return
            end
            
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            
            local lastRecordedFrame = State.StudioCurrentRecording.Frames[State.TimelinePosition]
            local lastState = lastRecordedFrame and lastRecordedFrame.MoveState or "Grounded"
            
            if State.TimelinePosition < #State.StudioCurrentRecording.Frames then
                local newFrames = {}
                for i = 1, State.TimelinePosition do
                    table.insert(newFrames, State.StudioCurrentRecording.Frames[i])
                end
                State.StudioCurrentRecording.Frames = newFrames
                
                if #State.StudioCurrentRecording.Frames > 0 then
                    local lastFrame = State.StudioCurrentRecording.Frames[#State.StudioCurrentRecording.Frames]
                    State.StudioCurrentRecording.StartTime = tick() - lastFrame.Timestamp
                end
            end
            
            if #State.StudioCurrentRecording.Frames > 0 then
                local lastFrame = State.StudioCurrentRecording.Frames[#State.StudioCurrentRecording.Frames]
                local currentPos = hrp.Position
                local lastPos = Vector3.new(lastFrame.Position[1], lastFrame.Position[2], lastFrame.Position[3])
                local distance = (currentPos - lastPos).Magnitude
                
                if distance > 0.3 then
                    local blendFrames = CONFIG.Playback.RESUME_BLEND_FRAMES
                    
                    if lastState == GetCurrentMoveState(hum) then
                        if lastState == "Grounded" or lastState == "Running" then
                            blendFrames = 2
                        elseif lastState == "Climbing" then
                            blendFrames = 3
                        elseif lastState == "Jumping" or lastState == "Falling" then
                            blendFrames = 2
                        end
                    end
                    
                    for i = 1, blendFrames do
                        local alpha = i / (blendFrames + 1)
                        alpha = alpha * alpha * (3 - 2 * alpha)
                        
                        local interpPos = lastPos:Lerp(currentPos, alpha)
                        
                        local lastLook = Vector3.new(lastFrame.LookVector[1], lastFrame.LookVector[2], lastFrame.LookVector[3])
                        local currentLook = hrp.CFrame.LookVector
                        local interpLook = lastLook:Lerp(currentLook, alpha).Unit
                        
                        local lastUp = Vector3.new(lastFrame.UpVector[1], lastFrame.UpVector[2], lastFrame.UpVector[3])
                        local currentUp = hrp.CFrame.UpVector
                        local interpUp = lastUp:Lerp(currentUp, alpha).Unit
                        
                        local lastVel = Vector3.new(lastFrame.Velocity[1], lastFrame.Velocity[2], lastFrame.Velocity[3])
                        local currentVel = hrp.AssemblyLinearVelocity
                        local interpVel = lastVel:Lerp(currentVel, alpha)
                        
                        local interpFrame = {
                            Position = {interpPos.X, interpPos.Y, interpPos.Z},
                            LookVector = {interpLook.X, interpLook.Y, interpLook.Z},
                            UpVector = {interpUp.X, interpUp.Y, interpUp.Z},
                            Velocity = {interpVel.X, interpVel.Y, interpVel.Z},
                            MoveState = lastState,
                            WalkSpeed = lastFrame.WalkSpeed,
                            Timestamp = lastFrame.Timestamp + (i * (1/CONFIG.Recording.FPS)),
                            IsResumeBlend = true
                        }
                        table.insert(State.StudioCurrentRecording.Frames, interpFrame)
                    end
                    
                    State.StudioCurrentRecording.StartTime = tick() - State.StudioCurrentRecording.Frames[#State.StudioCurrentRecording.Frames].Timestamp
                end
            end
            
            State.IsTimelineMode = false
            State.lastStudioRecordTime = tick()
            State.lastStudioRecordPos = hrp.Position
            State.lastRecordedState = lastState
            
            if hum then
                hum.WalkSpeed = State.CurrentWalkSpeed
                hum.AutoRotate = true
            end
            
            UpdateStudioUI()
            PlaySound("Success")
        end)
    end)
end

local function SaveStudioRecording()
    task.spawn(function()
        pcall(function()
            if #State.StudioCurrentRecording.Frames == 0 then
                PlaySound("Error")
                return
            end
            
            if State.StudioIsRecording then
                StopStudioRecording()
            end
            
            local normalizedFrames = NormalizeRecordingTimestamps(State.StudioCurrentRecording.Frames)
            
            Data.RecordedMovements[State.StudioCurrentRecording.Name] = normalizedFrames
            table.insert(Data.RecordingOrder, State.StudioCurrentRecording.Name)
            Data.checkpointNames[State.StudioCurrentRecording.Name] = "checkpoint_" .. #Data.RecordingOrder
            UpdateRecordList()
            
            PlaySound("Success")
            
            State.StudioCurrentRecording = {Frames = {}, StartTime = 0, Name = "recording_" .. os.date("%H%M%S")}
            State.IsTimelineMode = false
            State.CurrentTimelineFrame = 0
            State.TimelinePosition = 0
            State.lastRecordedState = nil
            UpdateStudioUI()
            
            wait(1)
            RecordingStudio.Visible = false
            MainFrame.Visible = true
        end)
    end)
end

-- ========================================
-- RGB TITLE PULSE SYSTEM
-- ========================================
local function StartTitlePulse(titleLabel)
    if Connections.titlePulse then
        pcall(function() Connections.titlePulse:Disconnect() end)
        Connections.titlePulse = nil
    end

    if not titleLabel then return end

    local hueSpeed = 0.25
    local pulseFreq = 4.5
    local baseSize = 14
    local sizeAmplitude = 6
    local strokeMin = 0.0
    local strokeMax = 0.9
    local strokePulseFreq = 2.2

    Connections.titlePulse = RunService.RenderStepped:Connect(function()
        pcall(function()
            if not titleLabel or not titleLabel.Parent then
                if Connections.titlePulse then
                    Connections.titlePulse:Disconnect()
                    Connections.titlePulse = nil
                end
                return
            end

            local t = tick()

            local hue = (t * hueSpeed) % 1
            local color = Color3.fromHSV(hue, 1, 1)
            titleLabel.TextColor3 = color

            local pulse = 0.5 + (math.sin(t * pulseFreq) * 0.5)
            local newSize = baseSize + (pulse * sizeAmplitude)
            titleLabel.TextSize = math.max(8, math.floor(newSize + 0.5))

            if titleLabel.TextStrokeTransparency ~= nil then
                local strokePulse = 0.5 + (math.sin(t * strokePulseFreq) * 0.5)
                local strokeTransparency = strokeMin + (strokePulse * (strokeMax - strokeMin))
                titleLabel.TextStrokeTransparency = math.clamp(strokeTransparency, 0, 1)
                titleLabel.TextStrokeColor3 = Color3.new(0,0,0)
            end

            if titleLabel.Position and typeof(titleLabel.Position) == "UDim2" then
                local jitter = (math.sin(t * pulseFreq * 0.5) * 2) * (pulse * 0.6)
                titleLabel.Position = UDim2.new(titleLabel.Position.X.Scale, titleLabel.Position.X.Offset, titleLabel.Position.Y.Scale, titleLabel.Position.Y.Offset + jitter)
            end
        end)
    end)

    AddConnection(Connections.titlePulse)
end

-- ========================================
-- GUI CREATION
-- ========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ByaruLRecorderElegant"
ScreenGui.ResetOnSpawn = false
if player:FindFirstChild("PlayerGui") then
    ScreenGui.Parent = player.PlayerGui
else
    wait(2)
    ScreenGui.Parent = player:WaitForChild("PlayerGui")
end

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.fromOffset(255, 310)
MainFrame.Position = UDim2.new(0.5, -127.5, 0.5, -150)
MainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 32)
Header.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 8)
HeaderCorner.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 1, 0)
Title.BackgroundTransparency = 1
Title.Text = "ByaruL Recorder"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Center
Title.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.fromOffset(20, 20)
CloseBtn.Position = UDim2.new(1, -20, 0.5, -10)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.new(1, 1, 1)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 4)
CloseCorner.Parent = CloseBtn

-- Content
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -6, 1, -38)
Content.Position = UDim2.new(0, 3, 0, 36)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

-- Control Section
local ControlSection = Instance.new("Frame")
ControlSection.Size = UDim2.new(1, 0, 0, 30)
ControlSection.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
ControlSection.BorderSizePixel = 0
ControlSection.Parent = Content

local ControlCorner = Instance.new("UICorner")
ControlCorner.CornerRadius = UDim.new(0, 6)
ControlCorner.Parent = ControlSection

local ControlButtons = Instance.new("Frame")
ControlButtons.Size = UDim2.new(1, -6, 1, -6)
ControlButtons.Position = UDim2.new(0, 3, 0, 3)
ControlButtons.BackgroundTransparency = 1
ControlButtons.Parent = ControlSection

local function CreateControlBtn(text, x, size, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(size, 22)
    btn.Position = UDim2.fromOffset(x, 0)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.AutoButtonColor = false
    btn.Parent = ControlButtons
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = btn
    
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.new(
                math.min(color.R * 1.2, 1),
                math.min(color.G * 1.2, 1),
                math.min(color.B * 1.2, 1)
            )
        }):Play()
    end)
    
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = color
        }):Play()
    end)
    
    return btn
end

local PlayBtn = CreateControlBtn("PLAY", 0, 81, Color3.fromRGB(59, 15, 116))
local RecordBtn = CreateControlBtn("RECORD", 84, 81, Color3.fromRGB(59, 15, 116))
local MenuBtn = CreateControlBtn("MENU", 168, 81, Color3.fromRGB(59, 15, 116))

-- Save Section
local SaveSection = Instance.new("Frame")
SaveSection.Size = UDim2.new(1, 0, 0, 60)
SaveSection.Position = UDim2.new(0, 0, 0, 36)
SaveSection.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
SaveSection.BorderSizePixel = 0
SaveSection.Parent = Content

local SaveCorner = Instance.new("UICorner")
SaveCorner.CornerRadius = UDim.new(0, 6)
SaveCorner.Parent = SaveSection

local FilenameBox = Instance.new("TextBox")
FilenameBox.Size = UDim2.new(1, -6, 0, 22)
FilenameBox.Position = UDim2.new(0, 3, 0, 5)
FilenameBox.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
FilenameBox.BorderSizePixel = 0
FilenameBox.Text = ""
FilenameBox.PlaceholderText = "Filename"
FilenameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
FilenameBox.Font = Enum.Font.Gotham
FilenameBox.TextSize = 11
FilenameBox.TextXAlignment = Enum.TextXAlignment.Center
FilenameBox.ClearTextOnFocus = false
FilenameBox.Parent = SaveSection

local FilenameCorner = Instance.new("UICorner")
FilenameCorner.CornerRadius = UDim.new(0, 4)
FilenameCorner.Parent = FilenameBox

local SaveButtons = Instance.new("Frame")
SaveButtons.Size = UDim2.new(1, -6, 0, 22)
SaveButtons.Position = UDim2.new(0, 3, 0, 32)
SaveButtons.BackgroundTransparency = 1
SaveButtons.Parent = SaveSection

local SaveFileBtn = CreateControlBtn("SAVE", 0, 81, Color3.fromRGB(59, 15, 116))
SaveFileBtn.Parent = SaveButtons
local LoadFileBtn = CreateControlBtn("LOAD", 84, 81, Color3.fromRGB(59, 15, 116))
LoadFileBtn.Parent = SaveButtons
local MergeBtn = CreateControlBtn("MERGE", 168, 81, Color3.fromRGB(59, 15, 116))
MergeBtn.Parent = SaveButtons

-- Recordings Section
local RecordingsSection = Instance.new("Frame")
RecordingsSection.Size = UDim2.new(1, 0, 0, 170)
RecordingsSection.Position = UDim2.new(0, 0, 0, 102)
RecordingsSection.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
RecordingsSection.BorderSizePixel = 0
RecordingsSection.Parent = Content

local RecordingsCorner = Instance.new("UICorner")
RecordingsCorner.CornerRadius = UDim.new(0, 6)
RecordingsCorner.Parent = RecordingsSection

local RecordingsList = Instance.new("ScrollingFrame")
RecordingsList.Size = UDim2.new(1, -6, 1, -6)
RecordingsList.Position = UDim2.new(0, 3, 0, 3)
RecordingsList.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
RecordingsList.BorderSizePixel = 0
RecordingsList.ScrollBarThickness = 4
RecordingsList.ScrollBarImageColor3 = Color3.fromRGB(80, 120, 255)
RecordingsList.ScrollingDirection = Enum.ScrollingDirection.Y
RecordingsList.VerticalScrollBarInset = Enum.ScrollBarInset.Always
RecordingsList.CanvasSize = UDim2.new(0, 0, 0, 0)
RecordingsList.Parent = RecordingsSection

local ListCorner = Instance.new("UICorner")
ListCorner.CornerRadius = UDim.new(0, 4)
ListCorner.Parent = RecordingsList

-- Mini Button
local MiniButton = Instance.new("TextButton")
MiniButton.Size = UDim2.fromOffset(40, 40)
MiniButton.Position = UDim2.new(0, 10, 0, 10)
MiniButton.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
MiniButton.Text = "A"
MiniButton.TextColor3 = Color3.new(1, 1, 1)
MiniButton.Font = Enum.Font.GothamBold
MiniButton.TextSize = 25
MiniButton.Visible = true
MiniButton.Active = true
MiniButton.Draggable = false
MiniButton.Parent = ScreenGui

local MiniCorner = Instance.new("UICorner")
MiniCorner.CornerRadius = UDim.new(0, 8)
MiniCorner.Parent = MiniButton

-- Playback Control
local PlaybackControl = Instance.new("Frame")
PlaybackControl.Size = UDim2.fromOffset(156, 130)
PlaybackControl.Position = UDim2.new(0.5, -78, 0.5, -52.5)
PlaybackControl.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
PlaybackControl.BorderSizePixel = 0
PlaybackControl.Active = true
PlaybackControl.Draggable = true
PlaybackControl.Visible = false
PlaybackControl.Parent = ScreenGui

local PlaybackCorner = Instance.new("UICorner")
PlaybackCorner.CornerRadius = UDim.new(0, 8)
PlaybackCorner.Parent = PlaybackControl

local PlaybackContent = Instance.new("Frame")
PlaybackContent.Size = UDim2.new(1, -6, 1, -6)
PlaybackContent.Position = UDim2.new(0, 3, 0, 3)
PlaybackContent.BackgroundTransparency = 1
PlaybackContent.Parent = PlaybackControl

local function CreatePlaybackBtn(text, x, y, w, h, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(w, h)
    btn.Position = UDim2.fromOffset(x, y)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.AutoButtonColor = false
    btn.Parent = PlaybackContent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = btn
    
    btn.MouseEnter:Connect(function()
        task.spawn(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(
                    math.min(color.R * 255 * 1.2, 255) / 255,
                    math.min(color.G * 255 * 1.2, 255) / 255,
                    math.min(color.B * 255 * 1.2, 255) / 255
                )
            }):Play()
        end)
    end)
    
    btn.MouseLeave:Connect(function()
        task.spawn(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = color}):Play()
        end)
    end)
    
    return btn
end

local PlayBtnControl = CreatePlaybackBtn("PLAY", 3, 3, 144, 25, Color3.fromRGB(59, 15, 116))
local LoopBtnControl = CreatePlaybackBtn("Loop OFF", 3, 31, 71, 20, Color3.fromRGB(80, 80, 80))
local JumpBtnControl = CreatePlaybackBtn("Jump OFF", 77, 31, 70, 20, Color3.fromRGB(80, 80, 80))
local RespawnBtnControl = CreatePlaybackBtn("Respawn OFF", 3, 54, 71, 20, Color3.fromRGB(80, 80, 80))
local ShiftLockBtnControl = CreatePlaybackBtn("Shift OFF", 77, 54, 70, 20, Color3.fromRGB(80, 80, 80))
local ResetBtnControl = CreatePlaybackBtn("Reset OFF", 3, 77, 71, 20, Color3.fromRGB(80, 80, 80))
local ShowRuteBtnControl = CreatePlaybackBtn("Path OFF", 77, 77, 70, 20, Color3.fromRGB(80, 80, 80))

-- Recording Studio
local RecordingStudio = Instance.new("Frame")
RecordingStudio.Size = UDim2.fromOffset(156, 130)
RecordingStudio.Position = UDim2.new(0.5, -78, 0.5, -52.5)
RecordingStudio.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
RecordingStudio.BorderSizePixel = 0
RecordingStudio.Active = true
RecordingStudio.Draggable = true
RecordingStudio.Visible = false
RecordingStudio.Parent = ScreenGui

local StudioCorner = Instance.new("UICorner")
StudioCorner.CornerRadius = UDim.new(0, 8)
StudioCorner.Parent = RecordingStudio

local StudioContent = Instance.new("Frame")
StudioContent.Size = UDim2.new(1, -6, 1, -6)
StudioContent.Position = UDim2.new(0, 3, 0, 3)
StudioContent.BackgroundTransparency = 1
StudioContent.Parent = RecordingStudio

local function CreateStudioBtn(text, x, y, w, h, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(w, h)
    btn.Position = UDim2.fromOffset(x, y)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.AutoButtonColor = false
    btn.Parent = StudioContent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = btn
    
    btn.MouseEnter:Connect(function()
        task.spawn(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(
                    math.min(color.R * 255 * 1.2, 255) / 255,
                    math.min(color.G * 255 * 1.2, 255) / 255,
                    math.min(color.B * 255 * 1.2, 255) / 255
                )
            }):Play()
        end)
    end)
    
    btn.MouseLeave:Connect(function()
        task.spawn(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = color}):Play()
        end)
    end)
    
    return btn
end

local SaveBtn = CreateStudioBtn("SAVE", 3, 3, 71, 22, Color3.fromRGB(59, 15, 116))
local StartBtn = CreateStudioBtn("START", 77, 3, 70, 22, Color3.fromRGB(59, 15, 116))
local ResumeBtn = CreateStudioBtn("RESUME", 3, 28, 144, 22, Color3.fromRGB(59, 15, 116))
local PrevBtn = CreateStudioBtn("◀ PREV", 3, 53, 71, 22, Color3.fromRGB(59, 15, 116))
local NextBtn = CreateStudioBtn("NEXT ▶", 77, 53, 70, 22, Color3.fromRGB(59, 15, 116))

local SpeedBox = Instance.new("TextBox")
SpeedBox.Size = UDim2.fromOffset(71, 20)
SpeedBox.Position = UDim2.fromOffset(3, 78)
SpeedBox.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
SpeedBox.BorderSizePixel = 0
SpeedBox.Text = "1.00"
SpeedBox.PlaceholderText = "Speed"
SpeedBox.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedBox.Font = Enum.Font.GothamBold
SpeedBox.TextSize = 9
SpeedBox.TextXAlignment = Enum.TextXAlignment.Center
SpeedBox.ClearTextOnFocus = false
SpeedBox.Parent = StudioContent

local SpeedCorner = Instance.new("UICorner")
SpeedCorner.CornerRadius = UDim.new(0, 4)
SpeedCorner.Parent = SpeedBox

local WalkSpeedBox = Instance.new("TextBox")
WalkSpeedBox.Size = UDim2.fromOffset(70, 20)
WalkSpeedBox.Position = UDim2.fromOffset(77, 78)
WalkSpeedBox.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
WalkSpeedBox.BorderSizePixel = 0
WalkSpeedBox.Text = "16"
WalkSpeedBox.PlaceholderText = "WalkSpeed"
WalkSpeedBox.TextColor3 = Color3.fromRGB(255, 255, 255)
WalkSpeedBox.Font = Enum.Font.GothamBold
WalkSpeedBox.TextSize = 9
WalkSpeedBox.TextXAlignment = Enum.TextXAlignment.Center
WalkSpeedBox.ClearTextOnFocus = false
WalkSpeedBox.Parent = StudioContent

local WalkSpeedCorner = Instance.new("UICorner")
WalkSpeedCorner.CornerRadius = UDim.new(0, 4)
WalkSpeedCorner.Parent = WalkSpeedBox

-- ========================================
-- RECORDING LIST UPDATE FUNCTION
-- ========================================
local function FormatDuration(seconds)
    local minutes = math.floor(seconds / 60)
    local remainingSeconds = math.floor(seconds % 60)
    return string.format("%d:%02d", minutes, remainingSeconds)
end

local function MoveRecordingUp(name)
    local currentIndex = table.find(Data.RecordingOrder, name)
    if currentIndex and currentIndex > 1 then
        Data.RecordingOrder[currentIndex] = Data.RecordingOrder[currentIndex - 1]
        Data.RecordingOrder[currentIndex - 1] = name
        UpdateRecordList()
    end
end

local function MoveRecordingDown(name)
    local currentIndex = table.find(Data.RecordingOrder, name)
    if currentIndex and currentIndex < #Data.RecordingOrder then
        Data.RecordingOrder[currentIndex] = Data.RecordingOrder[currentIndex + 1]
        Data.RecordingOrder[currentIndex + 1] = name
        UpdateRecordList()
    end
end

function UpdateRecordList()
    pcall(function()
        for _, child in pairs(RecordingsList:GetChildren()) do 
            if child:IsA("Frame") then child:Destroy() end
        end
        
        local yPos = 3
        for index, name in ipairs(Data.RecordingOrder) do
            local rec = Data.RecordedMovements[name]
            if not rec then continue end
            
            local item = Instance.new("Frame")
            item.Size = UDim2.new(1, -6, 0, 60)
            item.Position = UDim2.new(0, 3, 0, yPos)
            item.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
            item.Parent = RecordingsList
        
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 4)
            corner.Parent = item
            
            local checkBox = Instance.new("TextButton")
            checkBox.Size = UDim2.fromOffset(18, 18)
            checkBox.Position = UDim2.fromOffset(5, 5)
            checkBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            checkBox.Text = Data.CheckedRecordings[name] and "✓" or ""
            checkBox.TextColor3 = Color3.fromRGB(100, 255, 150)
            checkBox.Font = Enum.Font.GothamBold
            checkBox.TextSize = 12
            checkBox.Parent = item
            
            local checkCorner = Instance.new("UICorner")
            checkCorner.CornerRadius = UDim.new(0, 3)
            checkCorner.Parent = checkBox
            
            local nameBox = Instance.new("TextBox")
            nameBox.Size = UDim2.new(1, -90, 0, 18)
            nameBox.Position = UDim2.fromOffset(28, 5)
            nameBox.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            nameBox.BorderSizePixel = 0
            nameBox.Text = Data.checkpointNames[name] or "Checkpoint1"
            nameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameBox.Font = Enum.Font.GothamBold
            nameBox.TextSize = 9
            nameBox.TextXAlignment = Enum.TextXAlignment.Left
            nameBox.PlaceholderText = "Name"
            nameBox.ClearTextOnFocus = false
            nameBox.Parent = item
            
            local nameBoxCorner = Instance.new("UICorner")
            nameBoxCorner.CornerRadius = UDim.new(0, 3)
            nameBoxCorner.Parent = nameBox
            
            local infoLabel = Instance.new("TextLabel")
            infoLabel.Size = UDim2.new(1, -90, 0, 14)
            infoLabel.Position = UDim2.fromOffset(28, 25)
            infoLabel.BackgroundTransparency = 1
            if #rec > 0 then
                local totalSeconds = rec[#rec].Timestamp
                infoLabel.Text = "🕐 " .. FormatDuration(totalSeconds) .. " 📊 " .. #rec .. " frames"
            else
                infoLabel.Text = "🕐 0:00 📊 0 frames"
            end
            infoLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
            infoLabel.Font = Enum.Font.GothamBold
            infoLabel.TextSize = 8
            infoLabel.TextXAlignment = Enum.TextXAlignment.Left
            infoLabel.Parent = item
            
            local playBtn = Instance.new("TextButton")
            playBtn.Size = UDim2.fromOffset(38, 20)
            playBtn.Position = UDim2.new(1, -79, 0, 5)
            playBtn.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
            playBtn.Text = "Play"
            playBtn.TextColor3 = Color3.new(1, 1, 1)
            playBtn.Font = Enum.Font.GothamBold
            playBtn.TextSize = 9
            playBtn.Parent = item
            
            local playCorner = Instance.new("UICorner")
            playCorner.CornerRadius = UDim.new(0, 3)
            playCorner.Parent = playBtn
            
            local delBtn = Instance.new("TextButton")
            delBtn.Size = UDim2.fromOffset(38, 20)
            delBtn.Position = UDim2.new(1, -38, 0, 5)
            delBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
            delBtn.Text = "Delete"
            delBtn.TextColor3 = Color3.new(1, 1, 1)
            delBtn.Font = Enum.Font.GothamBold
            delBtn.TextSize = 8
            delBtn.Parent = item
            
            local delCorner = Instance.new("UICorner")
            delCorner.CornerRadius = UDim.new(0, 3)
            delCorner.Parent = delBtn
            
            local upBtn = Instance.new("TextButton")
            upBtn.Size = UDim2.fromOffset(38, 20)
            upBtn.Position = UDim2.new(1, -79, 0, 30)
            upBtn.BackgroundColor3 = index > 1 and Color3.fromRGB(74, 195, 147) or Color3.fromRGB(60, 60, 70)
            upBtn.Text = "Naik"
            upBtn.TextColor3 = Color3.new(1, 1, 1)
            upBtn.Font = Enum.Font.GothamBold
            upBtn.TextSize = 9
            upBtn.Parent = item
            
            local upCorner = Instance.new("UICorner")
            upCorner.CornerRadius = UDim.new(0, 3)
            upCorner.Parent = upBtn
            
            local downBtn = Instance.new("TextButton")
            downBtn.Size = UDim2.fromOffset(38, 20)
            downBtn.Position = UDim2.new(1, -38, 0, 30)
            downBtn.BackgroundColor3 = index < #Data.RecordingOrder and Color3.fromRGB(74, 195, 147) or Color3.fromRGB(60, 60, 70)
            downBtn.Text = "Turun"
            downBtn.TextColor3 = Color3.new(1, 1, 1)
            downBtn.Font = Enum.Font.GothamBold
            downBtn.TextSize = 9
            downBtn.Parent = item
            
            local downCorner = Instance.new("UICorner")
            downCorner.CornerRadius = UDim.new(0, 3)
            downCorner.Parent = downBtn
            
            nameBox.FocusLost:Connect(function()
                local newName = nameBox.Text
                if newName and newName ~= "" then
                    Data.checkpointNames[name] = newName
                    PlaySound("Success")
                end
            end)
            
            checkBox.MouseButton1Click:Connect(function()
                Data.CheckedRecordings[name] = not Data.CheckedRecordings[name]
                checkBox.Text = Data.CheckedRecordings[name] and "✓" or ""
                AnimateButtonClick(checkBox)
            end)
            
            playBtn.MouseButton1Click:Connect(function()
                if not State.IsPlaying then 
                    AnimateButtonClick(playBtn)
                    PlayRecording(name) 
                end
            end)
            
            delBtn.MouseButton1Click:Connect(function()
                AnimateButtonClick(delBtn)
                Data.RecordedMovements[name] = nil
                Data.checkpointNames[name] = nil
                Data.CheckedRecordings[name] = nil
                Data.PathHasBeenUsed[name] = nil
                local idx = table.find(Data.RecordingOrder, name)
                if idx then table.remove(Data.RecordingOrder, idx) end
                UpdateRecordList()
            end)
            
            upBtn.MouseButton1Click:Connect(function()
                if index > 1 then 
                    AnimateButtonClick(upBtn)
                    MoveRecordingUp(name) 
                end
            end)
            
            downBtn.MouseButton1Click:Connect(function()
                if index < #Data.RecordingOrder then 
                    AnimateButtonClick(downBtn)
                    MoveRecordingDown(name) 
                end
            end)
            
            yPos = yPos + 65
        end
        
        RecordingsList.CanvasSize = UDim2.new(0, 0, 0, math.max(yPos, RecordingsList.AbsoluteSize.Y))
    end)
end

-- ========================================
-- VALIDATION FUNCTIONS
-- ========================================
local function ValidateSpeed(speedText)
    local speed = tonumber(speedText)
    if not speed then return false, "Invalid number" end
    if speed < 0.25 or speed > 100.0 then return false, "Speed must be between 0.25 and 100.0" end
    local roundedSpeed = math.floor((speed * 4) + 0.5) / 4
    return true, roundedSpeed
end

SpeedBox.FocusLost:Connect(function()
    local success, result = ValidateSpeed(SpeedBox.Text)
    if success then
        State.CurrentSpeed = result
        SpeedBox.Text = string.format("%.2f", result)
        PlaySound("Success")
    else
        SpeedBox.Text = string.format("%.2f", State.CurrentSpeed)
        PlaySound("Error")
    end
end)

local function ValidateWalkSpeed(walkSpeedText)
    local walkSpeed = tonumber(walkSpeedText)
    if not walkSpeed then return false, "Invalid number" end
    if walkSpeed < 8 or walkSpeed > 200 then return false, "WalkSpeed must be between 8 and 200" end
    return true, walkSpeed
end

WalkSpeedBox.FocusLost:Connect(function()
    local success, result = ValidateWalkSpeed(WalkSpeedBox.Text)
    if success then
        State.CurrentWalkSpeed = result
        WalkSpeedBox.Text = tostring(result)
        pcall(function()
            local char = player.Character
            if char and char:FindFirstChildOfClass("Humanoid") then
                char.Humanoid.WalkSpeed = State.CurrentWalkSpeed
            end
        end)
        PlaySound("Success")
    else
        WalkSpeedBox.Text = tostring(State.CurrentWalkSpeed)
        PlaySound("Error")
    end
end)

-- ========================================
-- BUTTON CONNECTIONS
-- ========================================

-- Studio Buttons
StartBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        AnimateButtonClick(StartBtn)
        if State.StudioIsRecording then
            StopStudioRecording()
        else
            StartStudioRecording()
        end
    end)
end)

PrevBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        AnimateButtonClick(PrevBtn)
        GoBackTimeline()
    end)
end)

NextBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        AnimateButtonClick(NextBtn)
        GoNextTimeline()
    end)
end)

ResumeBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        AnimateButtonClick(ResumeBtn)
        ResumeStudioRecording()
    end)
end)

SaveBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        AnimateButtonClick(SaveBtn)
        SaveStudioRecording()
    end)
end)

-- Playback Control Buttons
PlayBtnControl.MouseButton1Click:Connect(function()
    AnimateButtonClick(PlayBtnControl)
    if State.IsPlaying or State.IsAutoLoopPlaying then
        StopPlayback()
    else
        if State.AutoLoop then
            StartAutoLoopAll()
        else
            SmartPlayRecording(50)
        end
    end
end)

LoopBtnControl.MouseButton1Click:Connect(function()
    AnimateButtonClick(LoopBtnControl)
    State.AutoLoop = not State.AutoLoop
    if State.AutoLoop then
        LoopBtnControl.Text = "Loop ON"
        LoopBtnControl.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
        if not next(Data.RecordedMovements) then
            State.AutoLoop = false
            LoopBtnControl.Text = "Loop OFF"
            LoopBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
            PlaySound("Error")
            return
        end
        if State.IsPlaying then
            State.IsPlaying = false
            RestoreFullUserControl()
        end
        StartAutoLoopAll()
    else
        LoopBtnControl.Text = "Loop OFF"
        LoopBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        StopAutoLoopAll()
    end
end)

JumpBtnControl.MouseButton1Click:Connect(function()
    AnimateButtonClick(JumpBtnControl)
    ToggleInfiniteJump()
    if State.InfiniteJump then

        JumpBtnControl.Text = "Jump ON"
        JumpBtnControl.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
    else
        JumpBtnControl.Text = "Jump OFF"
        JumpBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    end
end)

RespawnBtnControl.MouseButton1Click:Connect(function()
    AnimateButtonClick(RespawnBtnControl)
    State.AutoRespawn = not State.AutoRespawn
    if State.AutoRespawn then
        RespawnBtnControl.Text = "Respawn ON"
        RespawnBtnControl.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
    else
        RespawnBtnControl.Text = "Respawn OFF"
        RespawnBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    end
    PlaySound("Toggle")
end)

ShiftLockBtnControl.MouseButton1Click:Connect(function()
    AnimateButtonClick(ShiftLockBtnControl)
    ToggleVisibleShiftLock()
    if State.ShiftLockEnabled then
        ShiftLockBtnControl.Text = "Shift ON"
        ShiftLockBtnControl.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
    else
        ShiftLockBtnControl.Text = "Shift OFF"
        ShiftLockBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    end
end)

ResetBtnControl.MouseButton1Click:Connect(function()
    AnimateButtonClick(ResetBtnControl)
    State.AutoReset = not State.AutoReset
    if State.AutoReset then
        ResetBtnControl.Text = "Reset ON"
        ResetBtnControl.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
    else
        ResetBtnControl.Text = "Reset OFF"
        ResetBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    end
    PlaySound("Toggle")
end)

ShowRuteBtnControl.MouseButton1Click:Connect(function()
    AnimateButtonClick(ShowRuteBtnControl)
    State.ShowPaths = not State.ShowPaths
    if State.ShowPaths then
        ShowRuteBtnControl.Text = "Path ON"
        ShowRuteBtnControl.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
        Data.PathsHiddenOnce = false
        VisualizeAllPaths()
    else
        ShowRuteBtnControl.Text = "Path OFF"
        ShowRuteBtnControl.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        ClearPathVisualization()
    end
end)

-- Main Frame Buttons
PlayBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(PlayBtn)
    PlaybackControl.Visible = not PlaybackControl.Visible
end)

RecordBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(RecordBtn)
    RecordingStudio.Visible = true
end)

MenuBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(MenuBtn)
    task.spawn(function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/arullwah/Wkwkwkw/refs/heads/main/library.lua", true))()
        end)
        
        if success then
            PlaySound("Success")
        else
            PlaySound("Error")
        end
    end)
end)

SaveFileBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(SaveFileBtn)
    SaveToObfuscatedJSON()
end)

LoadFileBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(LoadFileBtn)
    LoadFromObfuscatedJSON()
end)

MergeBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(MergeBtn)
    CreateMergedReplay()
end)

CloseBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(CloseBtn)
    task.spawn(function()
        pcall(function()
            if State.StudioIsRecording then StopStudioRecording() end
            if State.IsPlaying or State.AutoLoop then StopPlayback() end
            if State.ShiftLockEnabled then DisableVisibleShiftLock() end
            if State.InfiniteJump then DisableInfiniteJump() end
            CleanupConnections()
            ClearPathVisualization()
            task.wait(0.2)
            ScreenGui:Destroy()
        end)
    end)
end)

-- ========================================
-- MINI BUTTON SYSTEM
-- ========================================
local miniSaveFile = "MiniButtonPos.json"

pcall(function()
    if hasFileSystem and isfile and isfile(miniSaveFile) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(miniSaveFile)) end)
        if ok and type(data) == "table" and data.x and data.y then
            MiniButton.Position = UDim2.fromOffset(data.x, data.y)
        end
    end
end)

MiniButton.MouseButton1Click:Connect(function()
    pcall(PlaySound, "Click")
    
    pcall(function()
        local originalSize = MiniButton.TextSize
        TweenService:Create(MiniButton, TweenInfo.new(0.1), {
            TextSize = originalSize * 1.2
        }):Play()
        task.wait(0.1)
        TweenService:Create(MiniButton, TweenInfo.new(0.1), {
            TextSize = originalSize
        }):Play()
    end)
    
    if MainFrame then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

local dragging = false
local dragStart = nil
local startPos = nil

MiniButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MiniButton.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                pcall(function()
                    if hasFileSystem and writefile and HttpService then
                        local absX = MiniButton.AbsolutePosition.X
                        local absY = MiniButton.AbsolutePosition.Y
                        writefile(miniSaveFile, HttpService:JSONEncode({x = absX, y = absY}))
                    end
                end)
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
    if not dragStart or not startPos then return end

    local delta = input.Position - dragStart
    local newX = startPos.X.Offset + delta.X
    local newY = startPos.Y.Offset + delta.Y

    local cam = workspace.CurrentCamera
    local vx, vy = (cam and cam.ViewportSize.X) or 1920, (cam and cam.ViewportSize.Y) or 1080
    newX = math.clamp(newX, 0, math.max(0, vx - MiniButton.AbsoluteSize.X))
    newY = math.clamp(newY, 0, math.max(0, vy - MiniButton.AbsoluteSize.Y))

    MiniButton.Position = UDim2.fromOffset(newX, newY)
end)

-- ========================================
-- CHARACTER EVENT HANDLERS
-- ========================================
player.CharacterRemoving:Connect(function()
    pcall(function()
        if State.StudioIsRecording then
            StopStudioRecording()
        end
        if State.IsPlaying and not State.AutoLoop then
            StopPlayback()
        end
    end)
end)

game:GetService("ScriptContext").DescendantRemoving:Connect(function(descendant)
    if descendant == ScreenGui then
        pcall(function()
            CleanupConnections()
            ClearPathVisualization()
        end)
    end
end)

-- ========================================
-- INITIALIZATION
-- ========================================
UpdateRecordList()
UpdatePlayButtonStatus()
StartTitlePulse(Title)

-- Update play button status periodically
task.spawn(function()
    while task.wait(2) do
        if not State.IsPlaying and not State.IsAutoLoopPlaying then
            UpdatePlayButtonStatus()
        end
    end
end)

-- Auto-load saved recordings if file exists
if hasFileSystem then
    task.spawn(function()
        task.wait(2)
        pcall(function()
            local filename = "MyReplays.json"
            if isfile(filename) then
                FilenameBox.Text = "MyReplays"
                LoadFromObfuscatedJSON()
            end
        end)
    end)
end

-- Success notification
task.spawn(function()
    task.wait(1)
    PlaySound("Success")
    print("✅ ByaruL Recorder v3.0 - Loaded Successfully!")
    print("📝 Features:")
    print("  • Recording: 90 FPS with lag compensation")
    print("  • Playback: Smart play, auto-loop, speed control")
    print("  • Merge: Combine all recordings (no checkbox needed)")
    print("  • Save: Only checked recordings will be saved")
    print("  • Path visualization with auto-hide")
    print("  • Infinite jump, shift-lock, auto-respawn")
    print("🎮 Made by ByaruL - Enjoy!")
end)