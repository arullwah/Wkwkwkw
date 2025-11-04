--[[

    WindUI Example - Auto Walk dengan Sistem Lengkap
    
]]


local WindUI

do
    local ok, result = pcall(function()
        return require("./src/Init")
    end)
    
    if ok then
        WindUI = result
    else 
        WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/refs/heads/main/dist/main.lua"))()
    end
end

-- */  Mendapatkan data player  /* --
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local player = Players.LocalPlayer

-- ========= SISTEM AUTO WALK LENGKAP =========
local RECORDING_FPS = 60
local MAX_FRAMES = 30000
local MIN_DISTANCE_THRESHOLD = 0.015
local VELOCITY_SCALE = 1
local VELOCITY_Y_SCALE = 1

local R6_VELOCITY_MULTIPLIER = 0.85
local R15_VELOCITY_MULTIPLIER = 1.0
local R6_JUMP_POWER = 50
local R15_JUMP_POWER = 50

local FIELD_MAPPING = {
    Position = "11",
    LookVector = "88", 
    UpVector = "55",
    Velocity = "22",
    MoveState = "33",
    WalkSpeed = "44",
    Timestamp = "66",
    RigType = "77"
}

local REVERSE_MAPPING = {
    ["11"] = "Position",
    ["88"] = "LookVector",
    ["55"] = "UpVector", 
    ["22"] = "Velocity",
    ["33"] = "MoveState",
    ["44"] = "WalkSpeed",
    ["66"] = "Timestamp",
    ["77"] = "RigType"
}

-- Variables
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

-- Pause/Resume Variables
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
local originalJumpButtonEnabled = true

-- Playback State Tracking
local lastPlaybackState = nil
local lastStateChangeTime = 0
local STATE_CHANGE_COOLDOWN = 0.15

-- Auto Loop Variables
local IsAutoLoopPlaying = false
local CurrentLoopIndex = 1
local LoopPauseStartTime = 0
local LoopTotalPausedDuration = 0

-- Visible Shiftlock System
local shiftLockConnection = nil
local originalMouseBehavior = nil
local ShiftLockEnabled = false
local isShiftLockActive = false

-- Memory Management
local activeConnections = {}

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
    
    if recordConnection then
        recordConnection:Disconnect()
        recordConnection = nil
    end
    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end
    if loopConnection then
        loopConnection:Disconnect()
        loopConnection = nil
    end
    if shiftLockConnection then
        shiftLockConnection:Disconnect()
        shiftLockConnection = nil
    end
    if jumpConnection then
        jumpConnection:Disconnect()
        jumpConnection = nil
    end
end

-- Rig Type Detection System
local CurrentRigType = "R15"

local function GetRigType(character)
    character = character or player.Character
    if not character then return "R15" end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return "R15" end
    
    return humanoid.RigType.Name
end

local function GetRigVelocityMultiplier(rigType)
    rigType = rigType or GetRigType()
    return rigType == "R6" and R6_VELOCITY_MULTIPLIER or R15_VELOCITY_MULTIPLIER
end

local function GetDefaultJumpPower(rigType)
    rigType = rigType or GetRigType()
    return rigType == "R6" and R6_JUMP_POWER or R15_JUMP_POWER
end

local function GetRecordingRigType(recording)
    if not recording or #recording == 0 then return "R15" end
    return recording[1].RigType or "R15"
end

local function CalculateRigCompatibilityMultiplier(recordedRig, currentRig)
    if recordedRig == currentRig then
        return 1.0
    end
    
    if recordedRig == "R6" and currentRig == "R15" then
        return R15_VELOCITY_MULTIPLIER / R6_VELOCITY_MULTIPLIER
    end
    
    if recordedRig == "R15" and currentRig == "R6" then
        return R6_VELOCITY_MULTIPLIER / R15_VELOCITY_MULTIPLIER
    end
    
    return 1.0
end

-- Sound Effects
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

-- Auto Respawn Functions
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
        humanoid.JumpPower = GetDefaultJumpPower()
        humanoid.Sit = false
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end)
end

-- Visible Shiftlock System
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

-- Infinite Jump System
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

-- Humanoid State Management
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
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
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
        humanoid.JumpPower = GetDefaultJumpPower()
        humanoid.PlatformStand = false
        humanoid.Sit = false
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end
    
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end
    
    if ShiftLockEnabled then
        EnableVisibleShiftLock()
    end
end

-- Move State Detection
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

-- Path Visualization
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

local function UpdatePauseMarker()
    if IsPaused then
        if not CurrentPauseMarker then
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local position = char.HumanoidRootPart.Position
                -- Create pause marker logic here
            end
        end
    else
        if CurrentPauseMarker and CurrentPauseMarker.Parent then
            CurrentPauseMarker:Destroy()
            CurrentPauseMarker = nil
        end
    end
end

-- Obfuscation Functions
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

-- Frame Data Functions
local function GetFrameCFrame(frame)
    local pos = Vector3.new(frame.Position[1], frame.Position[2], frame.Position[3])
    local look = Vector3.new(frame.LookVector[1], frame.LookVector[2], frame.LookVector[3])
    local up = Vector3.new(frame.UpVector[1], frame.UpVector[2], frame.UpVector[3])
    return CFrame.lookAt(pos, pos + look, up)
end

local function GetFrameVelocity(frame, recordedRig, currentRig)
    recordedRig = recordedRig or frame.RigType or "R15"
    currentRig = currentRig or GetRigType()
    
    local compatMultiplier = CalculateRigCompatibilityMultiplier(recordedRig, currentRig)
    
    return frame.Velocity and Vector3.new(
        frame.Velocity[1] * VELOCITY_SCALE * compatMultiplier,
        frame.Velocity[2] * VELOCITY_Y_SCALE * compatMultiplier,
        frame.Velocity[3] * VELOCITY_SCALE * compatMultiplier
    ) or Vector3.new(0, 0, 0)
end

local function GetFrameWalkSpeed(frame)
    return frame.WalkSpeed or 16
end

local function GetFrameTimestamp(frame)
    return frame.Timestamp or 0
end

-- Recording System
local lastFrameTime = 0
local frameInterval = 1 / RECORDING_FPS

local function ShouldRecordFrame()
    local currentTime = tick()
    return (currentTime - lastFrameTime) >= frameInterval
end

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

local function StartRecording()
    if IsRecording then return end
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        PlaySound("Error")
        return
    end
    
    IsRecording = true
    CurrentRecording = {Frames = {}, StartTime = tick(), Name = "recording_" .. os.date("%H%M%S")}
    lastRecordTime = 0
    lastRecordPos = nil
    lastFrameTime = 0
    
    PlaySound("RecordStart")
    
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
            RigType = GetRigType(char)
        }
        
        table.insert(CurrentRecording.Frames, frameData)
        lastFrameTime = tick()
        lastRecordPos = currentPos
    end)
    
    AddConnection(recordConnection)
end

local function StopRecording()
    if not IsRecording then return end
    IsRecording = false
    
    if recordConnection then
        recordConnection:Disconnect()
        recordConnection = nil
    end
    
    if #CurrentRecording.Frames > 0 then
        AutoSaveRecording()
    end
    
    PlaySound("RecordStop")
end

-- Playback System
local function PlayRecording(name)
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
    currentPlaybackFrame = 1
    playbackStartTime = tick()
    totalPausedDuration = 0
    pauseStartTime = 0
    lastPlaybackState = nil
    lastStateChangeTime = 0

    local recordedRig = GetRecordingRigType(recording)
    local currentRig = GetRigType()
    
    if recordedRig ~= currentRig then
        warn(string.format("⚠️ Recording is %s, playing on %s. Auto-adjusting velocity...", recordedRig, currentRig))
    end

    SaveHumanoidState()
    
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

    DisableJump()
    
    PlaySound("Play")

    playbackConnection = RunService.Heartbeat:Connect(function()
        if not IsPlaying then
            playbackConnection:Disconnect()
            RestoreFullUserControl()
            UpdatePauseMarker()
            lastPlaybackState = nil
            lastStateChangeTime = 0
            return
        end
        
        if IsPaused then
            if pauseStartTime == 0 then
                pauseStartTime = tick()
                RestoreHumanoidState()
                if ShiftLockEnabled then
                    ApplyVisibleShiftLock()
                end
                UpdatePauseMarker()
            end
            return
        else
            if pauseStartTime > 0 then
                totalPausedDuration = totalPausedDuration + (tick() - pauseStartTime)
                pauseStartTime = 0
                DisableJump()
                UpdatePauseMarker()
            end
        end

        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            IsPlaying = false
            RestoreFullUserControl()
            UpdatePauseMarker()
            lastPlaybackState = nil
            lastStateChangeTime = 0
            return
        end
        
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then
            IsPlaying = false
            RestoreFullUserControl()
            UpdatePauseMarker()
            lastPlaybackState = nil
            lastStateChangeTime = 0
            return
        end

        local currentTime = tick()
        local effectiveTime = (currentTime - playbackStartTime - totalPausedDuration) * CurrentSpeed
        
        while currentPlaybackFrame < #recording and GetFrameTimestamp(recording[currentPlaybackFrame + 1]) <= effectiveTime do
            currentPlaybackFrame = currentPlaybackFrame + 1
        end

        if currentPlaybackFrame >= #recording then
            IsPlaying = false
            RestoreFullUserControl()
            PlaySound("Success")
            UpdatePauseMarker()
            lastPlaybackState = nil
            lastStateChangeTime = 0
            return
        end

        local frame = recording[currentPlaybackFrame]
        if not frame then
            IsPlaying = false
            RestoreFullUserControl()
            UpdatePauseMarker()
            lastPlaybackState = nil
            lastStateChangeTime = 0
            return
        end

        pcall(function()
            hrp.CFrame = GetFrameCFrame(frame)
            hrp.AssemblyLinearVelocity = GetFrameVelocity(frame, recordedRig, currentRig)
            
            if hum then
                hum.WalkSpeed = GetFrameWalkSpeed(frame) * CurrentSpeed
                hum.AutoRotate = false
                
                local moveState = frame.MoveState
                local stateTime = tick()
                
                if moveState ~= lastPlaybackState and (stateTime - lastStateChangeTime) >= STATE_CHANGE_COOLDOWN then
                    lastPlaybackState = moveState
                    lastStateChangeTime = stateTime
                    
                    if moveState == "Climbing" then
                        hum:ChangeState(Enum.HumanoidStateType.Climbing)
                        hum.PlatformStand = false
                        hum.AutoRotate = false
                    elseif moveState == "Jumping" then
                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                    elseif moveState == "Falling" then
                        local currentVelocity = hrp.AssemblyLinearVelocity
                        if currentVelocity.Y < -8 then
                            hum:ChangeState(Enum.HumanoidStateType.Freefall)
                        end
                    elseif moveState == "Swimming" then
                        hum:ChangeState(Enum.HumanoidStateType.Swimming)
                    else
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                    end
                end
            end
            
            if ShiftLockEnabled then
                ApplyVisibleShiftLock()
            end
        end)
    end)
    
    AddConnection(playbackConnection)
end

-- Auto Loop System
local function StartAutoLoopAll()
    if not AutoLoop then return end
    
    if #RecordingOrder == 0 then
        AutoLoop = false
        PlaySound("Error")
        return
    end
    
    PlaySound("Play")
    
    CurrentLoopIndex = 1
    IsAutoLoopPlaying = true
    lastPlaybackState = nil
    lastStateChangeTime = 0
    
    loopConnection = task.spawn(function()
        while AutoLoop and IsAutoLoopPlaying do
            if not AutoLoop or not IsAutoLoopPlaying then
                break
            end
            
            local recordingName = RecordingOrder[CurrentLoopIndex]
            local recording = RecordedMovements[recordingName]
            
            if not recording or #recording == 0 then
                CurrentLoopIndex = CurrentLoopIndex + 1
                if CurrentLoopIndex > #RecordingOrder then
                    CurrentLoopIndex = 1
                end
                task.wait(1)
                continue
            end
            
            local recordedRig = GetRecordingRigType(recording)
            local currentRig = GetRigType()
            
            if recordedRig ~= currentRig then
                warn(string.format("⚠️ Loop: Recording %s is %s, playing on %s", recordingName, recordedRig, currentRig))
            end
            
            if not IsCharacterReady() then
                if AutoRespawn then
                    ResetCharacter()
                    local success = WaitForRespawn()
                    if not success then
                        task.wait(2)
                        continue
                    end
                    task.wait(1.5)
                else
                    local waitAttempts = 0
                    local maxWaitAttempts = 120
                    
                    while not IsCharacterReady() and AutoLoop and IsAutoLoopPlaying do
                        waitAttempts = waitAttempts + 1
                        if waitAttempts >= maxWaitAttempts then
                            waitAttempts = 0
                        end
                        task.wait(0.5)
                    end
                    
                    if not AutoLoop or not IsAutoLoopPlaying then break end
                    task.wait(1.0)
                end
            end
            
            if not AutoLoop or not IsAutoLoopPlaying then break end
            
            local playbackCompleted = false
            local playbackStart = tick()
            local playbackPausedTime = 0
            local playbackPauseStart = 0
            local currentFrame = 1
            local deathRetryCount = 0
            local maxDeathRetries = 999999
            
            lastPlaybackState = nil
            lastStateChangeTime = 0
            
            SaveHumanoidState()
            
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

            DisableJump()
            
            while AutoLoop and IsAutoLoopPlaying and currentFrame <= #recording and deathRetryCount < maxDeathRetries do
                
                if not IsCharacterReady() then
                    deathRetryCount = deathRetryCount + 1
                    
                    if AutoRespawn then
                        ResetCharacter()
                        local success = WaitForRespawn()
                        
                        if success then
                            RestoreFullUserControl()
                            task.wait(1.5)
                            
                            currentFrame = 1
                            playbackStart = tick()
                            playbackPausedTime = 0
                            playbackPauseStart = 0
                            lastPlaybackState = nil
                            lastStateChangeTime = 0
                            
                            SaveHumanoidState()
                            DisableJump()
                            
                            continue
                        else
                            task.wait(2)
                            continue
                        end
                    else
                        local manualRespawnWait = 0
                        local maxManualWait = 120
                        
                        while not IsCharacterReady() and AutoLoop and IsAutoLoopPlaying do
                            manualRespawnWait = manualRespawnWait + 1
                            if manualRespawnWait >= maxManualWait then
                                manualRespawnWait = 0
                            end
                            task.wait(0.5)
                        end
                        
                        if not AutoLoop or not IsAutoLoopPlaying then break end
                        
                        RestoreFullUserControl()
                        task.wait(1.5)
                        
                        currentFrame = 1
                        playbackStart = tick()
                        playbackPausedTime = 0
                        playbackPauseStart = 0
                        lastPlaybackState = nil
                        lastStateChangeTime = 0
                        
                        SaveHumanoidState()
                        DisableJump()
                        
                        continue
                    end
                end
                
                if IsPaused then
                    if playbackPauseStart == 0 then
                        playbackPauseStart = tick()
                        RestoreHumanoidState()
                        if ShiftLockEnabled then
                            ApplyVisibleShiftLock()
                        end
                        UpdatePauseMarker()
                    end
                    task.wait(0.1)
                else
                    if playbackPauseStart > 0 then
                        playbackPausedTime = playbackPausedTime + (tick() - playbackPauseStart)
                        playbackPauseStart = 0
                        DisableJump()
                        UpdatePauseMarker()
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
                    
                    local currentTime = tick()
                    local effectiveTime = (currentTime - playbackStart - playbackPausedTime) * CurrentSpeed
                    
                    while currentFrame < #recording and GetFrameTimestamp(recording[currentFrame + 1]) <= effectiveTime do
                        currentFrame = currentFrame + 1
                    end
                    
                    if currentFrame >= #recording then
                        playbackCompleted = true
                        break
                    end
                    
                    local frame = recording[currentFrame]
                    if frame then
                        pcall(function()
                            hrp.CFrame = GetFrameCFrame(frame)
                            hrp.AssemblyLinearVelocity = GetFrameVelocity(frame, recordedRig, currentRig)
                            
                            if hum then
                                hum.WalkSpeed = GetFrameWalkSpeed(frame) * CurrentSpeed
                                hum.AutoRotate = false
                                
                                local moveState = frame.MoveState
                                local stateTime = tick()
                                
                                if moveState ~= lastPlaybackState and (stateTime - lastStateChangeTime) >= STATE_CHANGE_COOLDOWN then
                                    lastPlaybackState = moveState
                                    lastStateChangeTime = stateTime
                                    
                                    if moveState == "Climbing" then
                                        hum:ChangeState(Enum.HumanoidStateType.Climbing)
                                        hum.PlatformStand = false
                                        hum.AutoRotate = false
                                    elseif moveState == "Jumping" then
                                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                                    elseif moveState == "Falling" then
                                        local currentVelocity = hrp.AssemblyLinearVelocity
                                        if currentVelocity.Y < -8 then
                                            hum:ChangeState(Enum.HumanoidStateType.Freefall)
                                        end
                                    elseif moveState == "Swimming" then
                                        hum:ChangeState(Enum.HumanoidStateType.Swimming)
                                    else
                                        hum:ChangeState(Enum.HumanoidStateType.Running)
                                    end
                                end
                            end
                            
                            if ShiftLockEnabled then
                                ApplyVisibleShiftLock()
                            end
                        end)
                    end
                    
                    task.wait()
                end
            end
            
            RestoreFullUserControl()
            UpdatePauseMarker()
            lastPlaybackState = nil
            lastStateChangeTime = 0
            
            if playbackCompleted then
                PlaySound("Success")
                
                CurrentLoopIndex = CurrentLoopIndex + 1
                if CurrentLoopIndex > #RecordingOrder then
                    CurrentLoopIndex = 1
                end
                
                task.wait(0.5)
            else
                if not AutoLoop or not IsAutoLoopPlaying then
                    break
                else
                    task.wait(1)
                end
            end
        end
        
        IsAutoLoopPlaying = false
        IsPaused = false
        RestoreFullUserControl()
        UpdatePauseMarker()
        lastPlaybackState = nil
        lastStateChangeTime = 0
    end)
end

local function StopAutoLoopAll()
    AutoLoop = false
    IsAutoLoopPlaying = false
    IsPlaying = false
    IsPaused = false
    lastPlaybackState = nil
    lastStateChangeTime = 0
    
    if loopConnection then
        task.cancel(loopConnection)
        loopConnection = nil
    end
    
    RestoreFullUserControl()
    UpdatePauseMarker()
    
    local char = player.Character
    if char then CompleteCharacterReset(char) end
    
    PlaySound("Stop")
end

local function StopPlayback()
    if AutoLoop then
        StopAutoLoopAll()
    end
    
    if not IsPlaying then return end
    IsPlaying = false
    IsPaused = false
    lastPlaybackState = nil
    lastStateChangeTime = 0
    RestoreFullUserControl()
    UpdatePauseMarker()
    
    local char = player.Character
    if char then CompleteCharacterReset(char) end
    
    PlaySound("Stop")
end

local function PausePlayback()
    if AutoLoop and IsAutoLoopPlaying then
        IsPaused = not IsPaused
        
        if IsPaused then
            RestoreHumanoidState()
            if ShiftLockEnabled then
                ApplyVisibleShiftLock()
            end
            UpdatePauseMarker()
            PlaySound("Click")
        else
            SaveHumanoidState()
            
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

            DisableJump()
            UpdatePauseMarker()
            PlaySound("Click")
        end
    elseif IsPlaying then
        IsPaused = not IsPaused
        
        if IsPaused then
            RestoreHumanoidState()
            if ShiftLockEnabled then
                ApplyVisibleShiftLock()
            end
            UpdatePauseMarker()
            PlaySound("Click")
        else
            SaveHumanoidState()
            
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

            DisableJump()
            UpdatePauseMarker()
            PlaySound("Click")
        end
    end
end

-- Save/Load System
local function SaveToObfuscatedJSON()
    local filename = "MyReplays"
    filename = filename .. ".json"
    
    local hasSelected = false
    local selectedCount = 0
    for name, isSelected in pairs(SelectedReplays) do
        if isSelected then
            hasSelected = true
            selectedCount = selectedCount + 1
        end
    end
    
    if not next(RecordedMovements) then
        PlaySound("Error")
        return
    end
    
    local success, err = pcall(function()
        local saveData = {
            Version = "2.0",
            Obfuscated = true,
            Checkpoints = {},
            RecordingOrder = {},
            CheckpointNames = {}
        }
        
        local recordingsToSave = {}
        
        if hasSelected then
            for name, isSelected in pairs(SelectedReplays) do
                if isSelected and RecordedMovements[name] then
                    recordingsToSave[name] = RecordedMovements[name]
                    table.insert(saveData.RecordingOrder, name)
                    saveData.CheckpointNames[name] = checkpointNames[name]
                end
            end
            warn(string.format("💾 Saving %d selected replay(s) to %s", selectedCount, filename))
        else
            recordingsToSave = RecordedMovements
            saveData.RecordingOrder = RecordingOrder
            saveData.CheckpointNames = checkpointNames
            warn(string.format("💾 Saving all %d replay(s) to %s", #RecordingOrder, filename))
        end
        
        for name, frames in pairs(recordingsToSave) do
            local checkpointData = {
                Name = name,
                DisplayName = saveData.CheckpointNames[name] or "checkpoint",
                Frames = frames
            }
            table.insert(saveData.Checkpoints, checkpointData)
        end
        
        local obfuscatedData = ObfuscateRecordingData(recordingsToSave)
        saveData.ObfuscatedFrames = obfuscatedData
        
        local jsonString = HttpService:JSONEncode(saveData)
        writefile(filename, jsonString)
        PlaySound("Success")
        
        if hasSelected then
            for name, _ in pairs(SelectedReplays) do
                SelectedReplays[name] = false
            end
            UpdateRecordList()
        end
    end)
    
    if not success then
        PlaySound("Error")
        warn("❌ Save failed: " .. tostring(err))
    end
end

local function LoadFromObfuscatedJSON()
    local filename = "MyReplays.json"
    
    local success, err = pcall(function()
        if not isfile(filename) then
            PlaySound("Error")
            warn("❌ File not found: " .. filename)
            return
        end
        
        local jsonString = readfile(filename)
        local saveData = HttpService:JSONDecode(jsonString)
        
        RecordedMovements = {}
        RecordingOrder = saveData.RecordingOrder or {}
        checkpointNames = saveData.CheckpointNames or {}
        SelectedReplays = {}
        
        if saveData.Obfuscated and saveData.ObfuscatedFrames then
            local deobfuscatedData = DeobfuscateRecordingData(saveData.ObfuscatedFrames)
            
            for _, checkpointData in ipairs(saveData.Checkpoints or {}) do
                local name = checkpointData.Name
                local frames = deobfuscatedData[name]
                
                if frames then
                    RecordedMovements[name] = frames
                    SelectedReplays[name] = false
                    if not table.find(RecordingOrder, name) then
                        table.insert(RecordingOrder, name)
                    end
                    
                    local recordedRig = GetRecordingRigType(frames)
                    local currentRig = GetRigType()
                    if recordedRig ~= currentRig then
                        warn(string.format("⚠️ '%s' recorded on %s, current rig: %s", name, recordedRig, currentRig))
                    end
                end
            end
        else
            for _, checkpointData in ipairs(saveData.Checkpoints or {}) do
                local name = checkpointData.Name
                local frames = checkpointData.Frames
                
                if frames then
                    RecordedMovements[name] = frames
                    SelectedReplays[name] = false
                    if not table.find(RecordingOrder, name) then
                        table.insert(RecordingOrder, name)
                    end
                end
            end
        end
        
        UpdateRecordList()
        PlaySound("Success")
        warn(string.format("✅ Loaded %d replay(s) from %s", #RecordingOrder, filename))
    end)
    
    if not success then
        PlaySound("Error")
        warn("❌ Load failed: " .. tostring(err))
    end
end

-- Merge System
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
        
        if #mergedFrames > 0 and #checkpoint > 0 then
            local lastFrame = mergedFrames[#mergedFrames]
            local firstFrame = checkpoint[1]
            
            local transitionFrame = {
                Position = lastFrame.Position,
                LookVector = firstFrame.LookVector,
                UpVector = firstFrame.UpVector,
                Velocity = {0, 0, 0},
                MoveState = "Grounded",
                WalkSpeed = firstFrame.WalkSpeed,
                Timestamp = lastFrame.Timestamp + 0.05,
                RigType = firstFrame.RigType or GetRigType()
            }
            table.insert(mergedFrames, transitionFrame)
            totalTimeOffset = totalTimeOffset + 0.05
        end
        
        for frameIndex, frame in ipairs(checkpoint) do
            local newFrame = {
                Position = {frame.Position[1], frame.Position[2], frame.Position[3]},
                LookVector = {frame.LookVector[1], frame.LookVector[2], frame.LookVector[3]},
                UpVector = {frame.UpVector[1], frame.UpVector[2], frame.UpVector[3]},
                Velocity = {frame.Velocity[1], frame.Velocity[2], frame.Velocity[3]},
                MoveState = frame.MoveState,
                WalkSpeed = frame.WalkSpeed,
                Timestamp = frame.Timestamp + totalTimeOffset,
                RigType = frame.RigType or GetRigType()
            }
            table.insert(mergedFrames, newFrame)
        end
        
        if #checkpoint > 0 then
            totalTimeOffset = totalTimeOffset + checkpoint[#checkpoint].Timestamp + 0.1
        end
    end
    
    local optimizedFrames = {}
    local lastSignificantFrame = nil
    
    for i, frame in ipairs(mergedFrames) do
        local shouldInclude = true
        
        if lastSignificantFrame then
            local pos1 = Vector3.new(lastSignificantFrame.Position[1], lastSignificantFrame.Position[2], lastSignificantFrame.Position[3])
            local pos2 = Vector3.new(frame.Position[1], frame.Position[2], frame.Position[3])
            local distance = (pos1 - pos2).Magnitude
            
            if distance < 0.1 and frame.MoveState == lastSignificantFrame.MoveState then
                shouldInclude = false
            end
        end
        
        if shouldInclude then
            table.insert(optimizedFrames, frame)
            lastSignificantFrame = frame
        end
    end
    
    local mergedName = "merged_" .. os.date("%H%M%S")
    RecordedMovements[mergedName] = optimizedFrames
    table.insert(RecordingOrder, mergedName)
    checkpointNames[mergedName] = "MERGED ALL"
    SelectedReplays[mergedName] = false
    
    UpdateRecordList()
    PlaySound("Success")
end

-- Path Visualization
local function VisualizeAllPaths()
    ClearPathVisualization()
    
    if not ShowPaths then return end
    
    for _, name in ipairs(RecordingOrder) do
        local recording = RecordedMovements[name]
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
end

-- ========= WINDUI INTEGRATION =========

-- */  Window  /* --
local Window = WindUI:CreateWindow({
    Title = "AUTO WALK",
    Folder = "ftgshub",
    Icon = "user",
    NewElements = true,
    HideSearchBar = true,
    
    OpenButton = {
        Title = "Open Auto Walk UI",
        CornerRadius = UDim.new(1,0),
        StrokeThickness = 3,
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
        
        Color = ColorSequence.new(
            Color3.fromHex("#30FF6A"), 
            Color3.fromHex("#e7ff2f")
        )
    }
})

-- */  Profile Section  /* --
local ProfileSection = Window:Section({
    Title = "User Profile",
})

do
    local ProfileTab = ProfileSection:Tab({
        Title = "Profile",
        Icon = "user",
    })
    
    local userId = player.UserId
    local thumbType = Enum.ThumbnailType.HeadShot
    local thumbSize = Enum.ThumbnailSize.Size420x420
    local content, isReady = Players:GetUserThumbnailAsync(userId, thumbType, thumbSize)
    
    ProfileTab:Paragraph({
        Title = player.DisplayName ~= "" and player.DisplayName or player.Name,
        Desc = "Status: Online • Auto Walk Ready",
        Image = content,
        Thumbnail = content,
        ImageSize = 48,
    })
    
    ProfileTab:Space({ Columns = 3 })
    
    ProfileTab:Button({
        Title = "Finding Server",
        Icon = "search",
        Color = Color3.fromHex("#3b82f6"),
        Callback = function()
            WindUI:Notify({
                Title = "Server Search",
                Content = "Searching for available servers...",
            })
        end
    })

    ProfileTab:Button({
        Title = "Checkpoint 2",
        Icon = "map-pin",
        Color = Color3.fromHex("#10b981"),
        Callback = function()
            WindUI:Notify({
                Title = "Checkpoint 2",
                Content = "Navigating to Checkpoint 2...",
            })
        end
    })

    ProfileTab:Button({
        Title = "Checkpoint 4", 
        Icon = "map-pin",
        Color = Color3.fromHex("#8b5cf6"),
        Callback = function()
            WindUI:Notify({
                Title = "Checkpoint 4",
                Content = "Navigating to Checkpoint 4...",
            })
        end
    })
end

-- */  Auto Walk Controls Section  /* --
local ControlsSection = Window:Section({
    Title = "Auto Walk Controls",
})

do
    local ControlsTab = ControlsSection:Tab({
        Title = "Main Controls",
        Icon = "settings",
    })
    
    -- Recording Controls
    local RecordBtn = ControlsTab:Button({
        Title = "START RECORDING",
        Color = Color3.fromHex("#3b82f6"),
        Icon = "circle",
        Callback = function()
            if IsRecording then 
                StopRecording()
                RecordBtn:Set({
                    Title = "START RECORDING",
                    Color = Color3.fromHex("#3b82f6")
                })
            else 
                StartRecording()
                RecordBtn:Set({
                    Title = "STOP RECORDING",
                    Color = Color3.fromHex("#ef4444")
                })
            end
        end
    })
    
    ControlsTab:Space()
    
    -- Playback Controls
    local PlayBtn = ControlsTab:Button({
        Title = "PLAY",
        Color = Color3.fromHex("#10b981"),
        Icon = "play",
        Callback = function()
            PlayRecording()
        end
    })
    
    local StopBtn = ControlsTab:Button({
        Title = "STOP",
        Color = Color3.fromHex("#ef4444"),
        Icon = "square",
        Callback = function()
            StopPlayback()
        end
    })
    
    local PauseBtn = ControlsTab:Button({
        Title = "PAUSE",
        Color = Color3.fromHex("#f59e0b"),
        Icon = "pause",
        Callback = function()
            PausePlayback()
            if IsPaused then
                PauseBtn:Set({
                    Title = "RESUME",
                    Color = Color3.fromHex("#10b981")
                })
            else
                PauseBtn:Set({
                    Title = "PAUSE", 
                    Color = Color3.fromHex("#f59e0b")
                })
            end
        end
    })
    
    ControlsTab:Space()
    
    -- Speed Controls
    local SpeedInput = ControlsTab:Input({
        Title = "Playback Speed",
        Desc = "Set speed multiplier (0.25 - 30)",
        Value = "1.00",
        Callback = function(value)
            local speed = tonumber(value)
            if speed and speed >= 0.25 and speed <= 30 then
                CurrentSpeed = math.floor((speed * 4) + 0.5) / 4
                SpeedInput:Set(string.format("%.2f", CurrentSpeed))
                PlaySound("Success")
            else
                SpeedInput:Set(string.format("%.2f", CurrentSpeed))
                PlaySound("Error")
            end
        end
    })
    
    local WalkSpeedInput = ControlsTab:Input({
        Title = "Walk Speed",
        Desc = "Set character walk speed (8 - 200)",
        Value = "16",
        Callback = function(value)
            local walkSpeed = tonumber(value)
            if walkSpeed and walkSpeed >= 8 and walkSpeed <= 200 then
                CurrentWalkSpeed = walkSpeed
                
                local char = player.Character
                if char and char:FindFirstChildOfClass("Humanoid") then
                    char.Humanoid.WalkSpeed = CurrentWalkSpeed
                end
                
                PlaySound("Success")
            else
                WalkSpeedInput:Set(tostring(CurrentWalkSpeed))
                PlaySound("Error")
            end
        end
    })
    
    ControlsTab:Space()
    
    -- Toggle Controls
    local LoopToggle = ControlsTab:Toggle({
        Title = "Auto Loop",
        Desc = "Loop through all recordings automatically",
        Callback = function(state)
            AutoLoop = state
            if AutoLoop then
                if not next(RecordedMovements) then
                    AutoLoop = false
                    LoopToggle:Set(false)
                    return
                end
                
                if IsPlaying then
                    IsPlaying = false
                    IsPaused = false
                    RestoreFullUserControl()
                end
                
                StartAutoLoopAll()
            else
                StopAutoLoopAll()
            end
        end
    })
    
    local JumpToggle = ControlsTab:Toggle({
        Title = "Infinite Jump",
        Desc = "Enable infinite jumping",
        Callback = function(state)
            ToggleInfiniteJump()
        end
    })
    
    local ShiftLockToggle = ControlsTab:Toggle({
        Title = "ShiftLock",
        Desc = "Enable shiftlock system",
        Callback = function(state)
            ToggleVisibleShiftLock()
        end
    })
    
    local RespawnToggle = ControlsTab:Toggle({
        Title = "Auto Respawn",
        Desc = "Automatically respawn when dead",
        Callback = function(state)
            AutoRespawn = state
        end
    })
    
    ControlsTab:Space()
    
    -- Path Visualization
    local PathToggle = ControlsTab:Toggle({
        Title = "Show Paths",
        Desc = "Visualize recorded paths",
        Callback = function(state)
            ShowPaths = state
            if ShowPaths then
                VisualizeAllPaths()
            else
                ClearPathVisualization()
            end
        end
    })
    
    ControlsTab:Space()
    
    -- Save/Load Buttons
    ControlsTab:Button({
        Title = "SAVE REPLAYS",
        Color = Color3.fromHex("#10b981"),
        Icon = "download",
        Callback = function()
            SaveToObfuscatedJSON()
        end
    })
    
    ControlsTab:Button({
        Title = "LOAD REPLAYS", 
        Color = Color3.fromHex("#3b82f6"),
        Icon = "upload",
        Callback = function()
            LoadFromObfuscatedJSON()
        end
    })
    
    ControlsTab:Button({
        Title = "MERGE REPLAYS",
        Color = Color3.fromHex("#8b5cf6"),
        Icon = "merge",
        Callback = function()
            CreateMergedReplay()
        end
    })
end

-- */  Replay List Section  /* --
local ReplaySection = Window:Section({
    Title = "Replay List",
})

do
    local ReplayTab = ReplaySection:Tab({
        Title = "Saved Replays",
        Icon = "list",
    })
    
    -- Function to update replay list in WindUI
    function UpdateRecordList()
        -- Clear existing replay list UI elements
        -- This would need custom implementation based on WindUI's capabilities
        
        for index, name in ipairs(RecordingOrder) do
            local rec = RecordedMovements[name]
            if not rec then continue end
            
            if SelectedReplays[name] == nil then
                SelectedReplays[name] = false
            end
            
            local recordingRigType = GetRecordingRigType(rec)
            local currentRigType = GetRigType()
            local rigMismatch = recordingRigType ~= currentRigType
            
            -- Create replay item (this is simplified - would need actual WindUI elements)
            local totalSeconds = #rec > 0 and rec[#rec].Timestamp or 0
            local minutes = math.floor(totalSeconds / 60)
            local seconds = math.floor(totalSeconds % 60)
            local durationText = string.format("%d:%02d", minutes, seconds)
            
            local frameCount = #rec
            local rigText = recordingRigType
            if rigMismatch then
                rigText = rigText .. " ⚠️→" .. currentRigType
            end
            
            -- Here you would create actual WindUI elements for each replay
            -- This is a placeholder for the concept
        end
    end
    
    -- Placeholder for replay list display
    ReplayTab:Section({
        Title = "Replay Management",
        Desc = "Use the controls above to manage your replays",
    })
    
    ReplayTab:Section({
        Title = "Total Replays: " .. (#RecordingOrder),
        TextSize = 14,
        TextTransparency = 0.3,
    })
end

-- ========= HOTKEY SYSTEM =========
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F9 then
        if IsRecording then StopRecording() else StartRecording() end
    elseif input.KeyCode == Enum.KeyCode.F10 then
        if IsPlaying or AutoLoop then StopPlayback() else PlayRecording() end
    elseif input.KeyCode == Enum.KeyCode.F7 then
        AutoLoop = not AutoLoop
        if AutoLoop then StartAutoLoopAll() else StopAutoLoopAll() end
    elseif input.KeyCode == Enum.KeyCode.F6 then
        SaveToObfuscatedJSON()
    elseif input.KeyCode == Enum.KeyCode.F5 then
        AutoRespawn = not AutoRespawn
    elseif input.KeyCode == Enum.KeyCode.F4 then
        ShowPaths = not ShowPaths
        if ShowPaths then
            VisualizeAllPaths()
        else
            ClearPathVisualization()
        end
    elseif input.KeyCode == Enum.KeyCode.F3 then
        ToggleVisibleShiftLock()
    elseif input.KeyCode == Enum.KeyCode.F2 then
        ToggleInfiniteJump()
    end
end)

-- ========= INITIALIZATION =========
task.spawn(function()
    task.wait(1)
    local currentRig = GetRigType()
    warn(string.format("🎮 Auto Walk System Loaded | Current Rig: %s", currentRig))
    warn("📋 Hotkeys: F9=Record | F10=Play | F7=Loop | F6=Save | F5=Respawn")
end)

task.spawn(function()
    task.wait(2)
    local filename = "MyReplays.json"
    if isfile and readfile and isfile(filename) then
        LoadFromObfuscatedJSON()
    end
end)

player.CharacterRemoving:Connect(function()
    if IsRecording then
        StopRecording()
    end
    if IsPlaying or AutoLoop then
        StopPlayback()
    end
end)

player.CharacterAdded:Connect(function(character)
    task.wait(1)
    local newRig = GetRigType(character)
    CurrentRigType = newRig
    
    local humanoid = character:WaitForChild("Humanoid", 5)
    if humanoid then
        humanoid.WalkSpeed = CurrentWalkSpeed
        humanoid.JumpPower = GetDefaultJumpPower(newRig)
    end
    
    warn(string.format("🔄 Character respawned | Rig Type: %s", newRig))
end)

-- Initial update
UpdateRecordList()