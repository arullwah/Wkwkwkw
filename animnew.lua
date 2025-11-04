ByarulLv2.4

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local player = Players.LocalPlayer
wait(1)

-- ========= CONFIGURATION =========
local RECORDING_FPS = 60
local MAX_FRAMES = 30000
local MIN_DISTANCE_THRESHOLD = 0.015
local VELOCITY_SCALE = 1
local VELOCITY_Y_SCALE = 1
local ROUTE_PROXIMITY_THRESHOLD = 15
local MAX_FRAME_JUMP = 30

-- ========= REMOVED SMOOTH INTERPOLATION =========
local INTERPOLATION_ENABLED = false -- Disabled to prevent sticking

-- ========= ADVANCED RIG TYPE CONFIGURATION =========
local RIG_PROFILES = {
    ["R6"] = {
        Height = 5.0,
        HipHeight = 1.35,
        VelocityMultiplier = 1.0,
        JumpPower = 50,
        GroundOffset = 0.0,
        HeightCompensation = 0.0,
        TorsoName = "Torso",
        HeadOffset = 1.5
    },
    ["R15"] = {
        Height = 5.4,
        HipHeight = 2.1, 
        VelocityMultiplier = 1.0,
        JumpPower = 50,
        GroundOffset = 0.0,
        HeightCompensation = 0.75,
        TorsoName = "UpperTorso",
        HeadOffset = 0.65
    },
    ["R15_Tall"] = {
        Height = 6.5,
        HipHeight = 2.8,
        VelocityMultiplier = 1.15,
        JumpPower = 50,
        GroundOffset = 0.5,
        HeightCompensation = 1.5,
        TorsoName = "UpperTorso",
        HeadOffset = 0.8
    },
    ["Zepeto"] = {
        Height = 4.8,
        HipHeight = 0.5,
        VelocityMultiplier = 1.0,
        JumpPower = 50,
        GroundOffset = 2.0,
        HeightCompensation = 3.5,
        TorsoName = "UpperTorso",
        HeadOffset = 0.3
    }
}

-- ========= FIELD MAPPING FOR OBFUSCATION =========
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
local R15TallMode = false
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

-- ========= IMPROVED ZEPETO DETECTION =========
local ForceZepetoMode = false
local IsZepetoCharacter = false

-- ========= REMOVED SMOOTH PLAYBACK VARIABLES =========
-- Using direct frame playback without interpolation

-- ========= PAUSE/RESUME VARIABLES =========
local playbackStartTime = 0
local totalPausedDuration = 0
local pauseStartTime = 0
local currentPlaybackFrame = 1

-- ========= IMPROVED AUTO LOOP VARIABLES =========
local IsAutoLoopPlaying = false
local CurrentLoopIndex = 1
local LoopPauseStartTime = 0
local LoopTotalPausedDuration = 0
local SelectedReplaysList = {}
local CurrentLoopRecording = nil
local LoopPlaybackConnection = nil

-- ========= VISIBLE SHIFTLOCK SYSTEM =========
local shiftLockConnection = nil
local originalMouseBehavior = nil
local ShiftLockEnabled = false
local isShiftLockActive = false

-- ========= MEMORY MANAGEMENT =========
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
    if LoopPlaybackConnection then
        LoopPlaybackConnection:Disconnect()
        LoopPlaybackConnection = nil
    end
    if shiftLockConnection then
        shiftLockConnection:Disconnect()
        shiftLockConnection = nil
    end
    if jumpConnection then
        jumpConnection:Disconnect()
        jumpConnection = nil
    end
    
    -- Clear visualizations
    for _, part in pairs(PathVisualization) do
        pcall(function() part:Destroy() end)
    end
    PathVisualization = {}
    
    if CurrentPauseMarker then
        pcall(function() CurrentPauseMarker:Destroy() end)
        CurrentPauseMarker = nil
    end
end

-- ========= IMPROVED RIG TYPE DETECTION SYSTEM =========
local CurrentRigType = "R15"

local function DetectAdvancedRigType(character)
    character = character or player.Character
    if not character then return "R15" end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return "R15" end
    
    local rigType = humanoid.RigType.Name
    
    -- Detect R6
    if rigType == "R6" then
        return "R6"
    end
    
    -- Detect R15 variants
    if rigType == "R15" then
        local hrp = character:FindFirstChild("HumanoidRootPart")
        local head = character:FindFirstChild("Head")
        local upperTorso = character:FindFirstChild("UpperTorso")
        
        if hrp and head and upperTorso then
            -- Calculate character height
            local characterHeight = math.abs(head.Position.Y - hrp.Position.Y) + (head.Size.Y / 2)
            
            -- Improved tall detection
            if characterHeight > 6.0 then
                return "R15_Tall"
            end
        end
        
        return "R15"
    end
    
    return "R15"
end

-- ========= GREATLY IMPROVED ZEPETO DETECTION =========
local function DetectZepetoCharacter(character)
    character = character or player.Character
    if not character then return false end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    
    -- Check for Zepeto-specific characteristics
    local head = character:FindFirstChild("Head")
    local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    local humanoidDescription = humanoid:FindFirstChild("HumanoidDescription")
    
    if humanoidDescription then
        -- Check for Zepeto-specific body parts
        if humanoidDescription:FindFirstChild("BodyTypeScale") then
            return true
        end
        
        -- Check for Zepeto-specific proportions
        if humanoidDescription.HeadScale then
            if humanoidDescription.HeadScale > 1.2 then
                return true
            end
        end
    end
    
    -- Check body proportions
    if head and torso then
        local headSize = head.Size.Y
        local torsoSize = torso.Size.Y
        local sizeRatio = headSize / torsoSize
        
        -- Zepeto characters typically have larger heads
        if sizeRatio > 1.3 then
            return true
        end
        
        -- Check for flat/2D appearance
        if headSize > 1.0 and torsoSize < 0.8 then
            return true
        end
    end
    
    -- Check player name for Zepeto indicators
    local playerName = string.lower(player.Name)
    local displayName = string.lower(player.DisplayName)
    
    local zepetoKeywords = {"zepeto", "itboy", "2d", "flat", "cartoon", "anime"}
    
    for _, keyword in ipairs(zepetoKeywords) do
        if string.find(playerName, keyword) or string.find(displayName, keyword) then
            return true
        end
    end
    
    -- Check for specific Zepeto animations
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if animator then
        for _, track in pairs(animator:GetPlayingAnimationTracks()) do
            local animName = string.lower(track.Animation.Name)
            if string.find(animName, "zepeto") or string.find(animName, "itboy") then
                return true
            end
        end
    end
    
    return false
end

local function GetRigProfile(rigType)
    rigType = rigType or DetectAdvancedRigType()
    
    -- Force Zepeto mode if detected
    if IsZepetoCharacter or ForceZepetoMode then
        print("🎭 ZEPETO MODE ACTIVATED - Using Zepeto profile")
        return RIG_PROFILES["Zepeto"] or RIG_PROFILES["R15"]
    end
    
    return RIG_PROFILES[rigType] or RIG_PROFILES["R15"]
end

local function CalculateRigCompatibilityMultiplier(recordedRig, currentRig)
    local recordedProfile = RIG_PROFILES[recordedRig] or RIG_PROFILES["R15"]
    local currentProfile = RIG_PROFILES[currentRig] or RIG_PROFILES["R15"]
    
    if not recordedProfile or not currentProfile then return 1.0 end
    if recordedProfile.VelocityMultiplier == 0 then return 1.0 end
    
    return currentProfile.VelocityMultiplier / recordedProfile.VelocityMultiplier
end

-- ========= GREATLY IMPROVED HEIGHT OFFSET SYSTEM =========
local function GetRigHeightOffset(recordedRig, currentRig)
    -- SPECIAL HANDLING FOR ZEPETO - IMPROVED
    if IsZepetoCharacter or ForceZepetoMode then
        if recordedRig == "R6" then
            return 6.5  -- Big boost for R6 to Zepeto
        elseif recordedRig == "R15" then
            return 5.0  -- Boost for R15 to Zepeto
        elseif recordedRig == "R15_Tall" then
            return 4.0  -- Smaller boost for Tall to Zepeto
        else
            return 6.0  -- Default Zepeto boost
        end
    end
    
    -- Handle Zepeto recording played on normal rigs
    if recordedRig == "Zepeto" then
        if currentRig == "R6" then
            return -6.5  -- Lower for Zepeto to R6
        elseif currentRig == "R15" then
            return -5.0  -- Lower for Zepeto to R15
        elseif currentRig == "R15_Tall" then
            return -4.0  -- Lower for Zepeto to Tall
        end
    end
    
    local recordedProfile = RIG_PROFILES[recordedRig] or RIG_PROFILES["R15"]
    local currentProfile = RIG_PROFILES[currentRig] or RIG_PROFILES["R15"]
    
    -- Calculate height difference based on actual character heights
    local heightDiff = currentProfile.Height - recordedProfile.Height
    
    -- Apply R15 Tall Mode adjustment
    if R15TallMode and recordedRig == "R6" and currentRig == "R15_Tall" then
        heightDiff = heightDiff + 1.0  -- Extra boost for tall mode
    end
    
    return heightDiff * 0.7  -- Scale factor for natural adjustment
end

local function GetRecordingRigType(recording)
    if not recording or #recording == 0 then return "R15" end
    return recording[1].RigType or "R15"
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

-- ========= SOUND SYSTEM =========
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

-- ========= ENHANCED BUTTON ANIMATION =========
local function AnimateButtonClick(button)
    PlaySound("Click")
    
    local originalSize = button.Size
    TweenService:Create(button, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset - 4, originalSize.Y.Scale, originalSize.Y.Offset - 4)
    }):Play()
    
    local originalColor = button.BackgroundColor3
    local brighterColor = Color3.new(
        math.min(originalColor.R * 1.3, 1),
        math.min(originalColor.G * 1.3, 1), 
        math.min(originalColor.B * 1.3, 1)
    )
    
    TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundColor3 = brighterColor
    }):Play()
    
    wait(0.1)
    TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
        Size = originalSize,
        BackgroundColor3 = originalColor
    }):Play()
end

-- ========= AUTO RESPAWN FUNCTION =========
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

-- ========= CHARACTER READY CHECK =========
local function IsCharacterReady()
    local char = player.Character
    if not char then return false end
    if not char:FindFirstChild("HumanoidRootPart") then return false end
    if not char:FindFirstChildOfClass("Humanoid") then return false end
    if char.Humanoid.Health <= 0 then return false end
    return true
end

-- ========= ENHANCED CHARACTER RESET =========
local function CompleteCharacterReset(char)
    if not char or not char:IsDescendantOf(workspace) then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then return end
    pcall(function()
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
        humanoid.WalkSpeed = CurrentWalkSpeed
        humanoid.JumpPower = GetRigProfile().JumpPower
        humanoid.Sit = false
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end)
end

-- ========= VISIBLE SHIFTLOCK SYSTEM FUNCTIONS =========
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

local function ToggleInfiniteJump()
    InfiniteJump = not InfiniteJump
    
    if InfiniteJump then
        EnableInfiniteJump()
    else
        DisableInfiniteJump()
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
    label.Text = "PAUSE"
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

local function VisualizeRecordingPath(recording, name)
    ClearPathVisualization()
    
    if not recording or #recording < 2 then return end
    
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

-- ========= OBFUSCATION FUNCTIONS =========
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

-- ========= IMPROVED MACRO/MERGE SYSTEM =========
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
                RigType = firstFrame.RigType or DetectAdvancedRigType()
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
                RigType = frame.RigType or DetectAdvancedRigType()
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

-- ========= ADVANCED FRAME DATA FUNCTIONS WITH RIG COMPATIBILITY =========
local function GetFramePosition(frame)
    return Vector3.new(frame.Position[1], frame.Position[2], frame.Position[3])
end

-- ========= GREATLY IMPROVED RIG COMPATIBILITY SYSTEM =========
local function GetFrameCFrame(frame, recordedRig, currentRig)
    local pos = GetFramePosition(frame)
    local look = Vector3.new(frame.LookVector[1], frame.LookVector[2], frame.LookVector[3])
    local up = Vector3.new(frame.UpVector[1], frame.UpVector[2], frame.UpVector[3])
    
    -- IMPROVED ZEPETO HANDLING
    if IsZepetoCharacter or ForceZepetoMode then
        if recordedRig == "R6" then
            pos = pos + Vector3.new(0, 6.5, 0)  -- Big boost for R6 to Zepeto
        elseif recordedRig == "R15" then
            pos = pos + Vector3.new(0, 5.0, 0)  -- Boost for R15 to Zepeto
        elseif recordedRig == "R15_Tall" then
            pos = pos + Vector3.new(0, 4.0, 0)  -- Smaller boost for Tall to Zepeto
        else
            pos = pos + Vector3.new(0, 6.0, 0)  -- Default Zepeto boost
        end
        print("🔧 ZEPETO MODE: Height adjusted for " .. recordedRig .. " → Zepeto")
    elseif recordedRig == "Zepeto" then
        -- Handle Zepeto recording played on normal rigs
        if currentRig == "R6" then
            pos = pos + Vector3.new(0, -6.5, 0)  -- Lower for Zepeto to R6
        elseif currentRig == "R15" then
            pos = pos + Vector3.new(0, -5.0, 0)  -- Lower for Zepeto to R15
        elseif currentRig == "R15_Tall" then
            pos = pos + Vector3.new(0, -4.0, 0)  -- Lower for Zepeto to Tall
        end
        print("🔧 NORMAL MODE: Height adjusted for Zepeto → " .. currentRig)
    else
        -- Normal rig compatibility
        local heightOffset = GetRigHeightOffset(recordedRig, currentRig)
        pos = pos + Vector3.new(0, heightOffset, 0)
        
        if R15TallMode and recordedRig == "R6" and currentRig == "R15_Tall" then
            print("🔧 R15 TALL MODE: R6 → R15_Tall conversion active")
        end
    end
    
    return CFrame.lookAt(pos, pos + look, up)
end

local function GetFrameVelocity(frame, recordedRig, currentRig)
    recordedRig = recordedRig or frame.RigType or "R15"
    currentRig = currentRig or DetectAdvancedRigType()
    
    local compatMultiplier = CalculateRigCompatibilityMultiplier(recordedRig, currentRig)
    local recordedProfile = RIG_PROFILES[recordedRig] or RIG_PROFILES["R15"]
    local currentProfile = RIG_PROFILES[currentRig] or RIG_PROFILES["R15"]
    
    local heightMultiplier = currentProfile.Height / recordedProfile.Height
    
    -- Apply R15 Tall Mode velocity adjustment
    if R15TallMode and recordedRig == "R6" and currentRig == "R15_Tall" then
        heightMultiplier = 1.15 -- Boost for tall characters
    end
    
    return frame.Velocity and Vector3.new(
        frame.Velocity[1] * VELOCITY_SCALE * compatMultiplier * heightMultiplier,
        frame.Velocity[2] * VELOCITY_Y_SCALE * compatMultiplier,
        frame.Velocity[3] * VELOCITY_SCALE * compatMultiplier * heightMultiplier
    ) or Vector3.new(0, 0, 0)
end

local function GetFrameWalkSpeed(frame)
    return frame.WalkSpeed or 16
end

local function GetFrameTimestamp(frame)
    return frame.Timestamp or 0
end

-- ========= SMART ROUTE DETECTION SYSTEM =========
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

-- ========= PERFECT JUMP DETECTION =========
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

-- ========= FIXED JUMP CONTROL FUNCTIONS =========
local function DisableJump()
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.JumpPower = 0
        end
    end
end

local function EnableJump()
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.JumpPower = GetRigProfile().JumpPower
        end
    end
end

-- ========= PURE CFRAME SYSTEM WITHOUT INTERPOLATION =========
local function PlayRecordingWithCFrame(recording, startFrame, recordedRig, currentRig)
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

    playbackConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not IsPlaying then
            playbackConnection:Disconnect()
            EnableJump()
            return
        end
        
        -- PAUSE HANDLING
        if IsPaused then
            if pauseStartTime == 0 then
                pauseStartTime = tick()
                EnableJump()
                if ShiftLockEnabled then ApplyVisibleShiftLock() end
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

        -- CHARACTER SAFETY CHECK
        char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            IsPlaying = false
            playbackConnection:Disconnect()
            EnableJump()
            return
        end

        hum = char:FindFirstChildOfClass("Humanoid")
        hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then
            IsPlaying = false
            playbackConnection:Disconnect()
            EnableJump()
            return
        end

        -- TIME CALCULATION
        local currentTime = tick()
        local effectiveTime = (currentTime - playbackStartTime - totalPausedDuration) * CurrentSpeed
        
        -- FIND CURRENT FRAME BASED ON TIME
        local targetFrameIndex = currentFrame
        for i = currentFrame, #recording do
            if GetFrameTimestamp(recording[i]) <= effectiveTime then
                targetFrameIndex = i
            else
                break
            end
        end
        
        currentFrame = targetFrameIndex

        if currentFrame >= #recording then
            IsPlaying = false
            IsPaused = false
            
            -- Ensure final position accuracy
            local finalFrame = recording[#recording]
            if finalFrame then
                pcall(function()
                    hrp.CFrame = GetFrameCFrame(finalFrame, recordedRig, currentRig)
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                end)
            end
            
            EnableJump()
            UpdatePauseMarker()
            playbackConnection:Disconnect()
            PlaySound("Stop")
            return
        end

        local targetFrame = recording[currentFrame]
        if not targetFrame then return end

        pcall(function()
            -- DIRECT CFRAME APPLICATION (NO INTERPOLATION)
            local targetCFrame = GetFrameCFrame(targetFrame, recordedRig, currentRig)
            local targetVelocity = GetFrameVelocity(targetFrame, recordedRig, currentRig) * CurrentSpeed
            
            -- Apply directly without interpolation
            hrp.CFrame = targetCFrame
            hrp.AssemblyLinearVelocity = targetVelocity
            
            -- Apply WalkSpeed
            hum.WalkSpeed = GetFrameWalkSpeed(targetFrame) * CurrentSpeed
            
            -- STATE MANAGEMENT
            local moveState = targetFrame.MoveState
            
            if moveState == "Climbing" then
                hum:ChangeState(Enum.HumanoidStateType.Climbing)
            elseif moveState == "Jumping" then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            elseif moveState == "Falling" then
                hum:ChangeState(Enum.HumanoidStateType.Freefall)
            elseif moveState == "Swimming" then
                hum:ChangeState(Enum.HumanoidStateType.Swimming)
            else
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
            
            currentPlaybackFrame = currentFrame
            
            -- Update frame counter
            if currentFrame % 5 == 0 then
                FrameLabel.Text = string.format("Frame: %d/%d", currentPlaybackFrame, #recording)
            end
        end)
    end)
    
    AddConnection(playbackConnection)
end

-- ========= GREATLY IMPROVED AUTO LOOP SYSTEM =========
local function GetSelectedReplaysList()
    local selectedList = {}
    
    -- AUTO SELECT ALL VALID REPLAYS WHEN AUTO LOOP IS ACTIVATED
    if AutoLoop then
        for _, name in ipairs(RecordingOrder) do
            if RecordedMovements[name] and #RecordedMovements[name] > 0 then
                SelectedReplays[name] = true
                table.insert(selectedList, name)
            end
        end
    else
        -- Manual selection
        for _, name in ipairs(RecordingOrder) do
            if RecordedMovements[name] and #RecordedMovements[name] > 0 and SelectedReplays[name] then
                table.insert(selectedList, name)
            end
        end
    end
    
    -- If still no selections, use all valid replays
    if #selectedList == 0 then
        for _, name in ipairs(RecordingOrder) do
            if RecordedMovements[name] and #RecordedMovements[name] > 0 then
                table.insert(selectedList, name)
            end
        end
    end
    
    return selectedList
end

local function PlaySingleRecording(recordingName)
    local recording = RecordedMovements[recordingName]
    if not recording or #recording == 0 then 
        print("❌ Replay kosong: " .. recordingName)
        return false 
    end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then 
        print("❌ Karakter tidak ready")
        return false 
    end
    
    local recordedRig = GetRecordingRigType(recording)
    local currentRig = DetectAdvancedRigType()
    
    print("🎮 Memulai playback: " .. recordingName .. " (" .. #recording .. " frames)")
    
    DisableJump()
    
    local framePlaybackStart = tick()
    local framePausedTime = 0
    local framePauseStart = 0
    local currentFrame = 1
    
    local playbackCompleted = false
    local loopStopped = false
    
    -- BUAT CONNECTION REAL-TIME UNTUK PLAYBACK
    local singlePlaybackConnection
    singlePlaybackConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not AutoLoop or not IsAutoLoopPlaying then
            loopStopped = true
            singlePlaybackConnection:Disconnect()
            return
        end
        
        -- PAUSE HANDLING
        if IsPaused then
            if framePauseStart == 0 then
                framePauseStart = tick()
                EnableJump()
                if ShiftLockEnabled then ApplyVisibleShiftLock() end
                UpdatePauseMarker()
            end
            return
        else
            if framePauseStart > 0 then
                framePausedTime = framePausedTime + (tick() - framePauseStart)
                framePauseStart = 0
                DisableJump()
                UpdatePauseMarker()
            end
        end
        
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            playbackCompleted = false
            singlePlaybackConnection:Disconnect()
            return
        end
        
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then
            playbackCompleted = false
            singlePlaybackConnection:Disconnect()
            return
        end
        
        -- REAL-TIME FRAME CALCULATION
        local currentTime = tick()
        local effectiveTime = (currentTime - framePlaybackStart - framePausedTime) * CurrentSpeed
        
        -- CARI FRAME YANG SESUAI DENGAN WAKTU SAAT INI
        local targetFrameIndex = currentFrame
        for i = currentFrame, #recording do
            if GetFrameTimestamp(recording[i]) <= effectiveTime then
                targetFrameIndex = i
            else
                break
            end
        end
        
        currentFrame = targetFrameIndex
        
        if currentFrame >= #recording then
            playbackCompleted = true
            singlePlaybackConnection:Disconnect()
            return
        end
        
        local targetFrame = recording[currentFrame]
        if not targetFrame then return end

        -- DIRECT PLAYBACK TANPA INTERPOLATION
        pcall(function()
            local targetCFrame = GetFrameCFrame(targetFrame, recordedRig, currentRig)
            local targetVelocity = GetFrameVelocity(targetFrame, recordedRig, currentRig) * CurrentSpeed
            
            -- APPLY DIRECTLY
            hrp.CFrame = targetCFrame
            hrp.AssemblyLinearVelocity = targetVelocity
            
            -- APPLY WALKSPEED & STATE
            hum.WalkSpeed = GetFrameWalkSpeed(targetFrame) * CurrentSpeed
            
            local moveState = targetFrame.MoveState
            if moveState == "Climbing" then
                hum:ChangeState(Enum.HumanoidStateType.Climbing)
            elseif moveState == "Jumping" then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            elseif moveState == "Falling" then
                hum:ChangeState(Enum.HumanoidStateType.Freefall)
            else
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
            
            -- REAL-TIME FRAME COUNTER
            FrameLabel.Text = string.format("Loop: %d/%d | Frame: %d/%d", 
                CurrentLoopIndex, #SelectedReplaysList, currentFrame, #recording)
        end)
    end)
    
    AddConnection(singlePlaybackConnection)
    
    -- TUNGGU SAMPAI PLAYBACK SELESAI ATAU KARAKTER MATI
    local startWait = tick()
    while AutoLoop and IsAutoLoopPlaying and not playbackCompleted and not loopStopped do
        -- Check if character died during playback
        if not IsCharacterReady() then
            print("💀 Karakter mati selama playback, menunggu respawn...")
            -- Wait for respawn and continue from current frame
            if AutoRespawn then
                ResetCharacter()
            end
            
            local waitStart = tick()
            while not IsCharacterReady() and AutoLoop and IsAutoLoopPlaying do
                if tick() - waitStart > 15 then -- Timeout 15 detik
                    print("⏰ Timeout menunggu respawn")
                    break
                end
                task.wait(0.5)
            end
            
            if IsCharacterReady() then
                print("✅ Karakter respawned, melanjutkan playback...")
                -- Reset playback time to continue from current frame
                framePlaybackStart = tick() - (GetFrameTimestamp(recording[currentFrame]) / CurrentSpeed)
                framePausedTime = 0
            else
                break
            end
        end
        
        if tick() - startWait > 300 then -- Timeout 300 detik (5 menit)
            print("⏰ Timeout playback: " .. recordingName)
            break
        end
        task.wait(0.1)
    end
    
    singlePlaybackConnection:Disconnect()
    EnableJump()
    
    print("✅ Playback selesai: " .. recordingName .. " - " .. tostring(playbackCompleted))
    return playbackCompleted
end

local function StartAutoLoopAll()
    if IsAutoLoopPlaying then 
        print("🔄 AutoLoop sudah berjalan")
        return 
    end
    
    if not AutoLoop then 
        print("❌ AutoLoop tidak aktif")
        return 
    end
    
    SelectedReplaysList = GetSelectedReplaysList()
    
    if #SelectedReplaysList == 0 then
        print("❌ Tidak ada replay yang valid untuk di-loop")
        PlaySound("Error")
        return
    end
    
    print("🔄 Memulai AutoLoop dengan " .. #SelectedReplaysList .. " replay")
    PlaySound("Play")
    
    CurrentLoopIndex = 1
    IsAutoLoopPlaying = true
    
    -- Buat connection utama untuk manage loop sequence
    loopConnection = RunService.Heartbeat:Connect(function()
        if not AutoLoop or not IsAutoLoopPlaying then
            if loopConnection then
                loopConnection:Disconnect()
                loopConnection = nil
            end
            IsAutoLoopPlaying = false
            return
        end
        
        -- Loop melalui semua replay yang dipilih
        while AutoLoop and IsAutoLoopPlaying and CurrentLoopIndex <= #SelectedReplaysList do
            local recordingName = SelectedReplaysList[CurrentLoopIndex]
            print("🎮 Memutar replay: " .. recordingName .. " (" .. CurrentLoopIndex .. "/" .. #SelectedReplaysList .. ")")
            
            -- Pastikan karakter ready sebelum memulai
            if not IsCharacterReady() then
                print("💀 Karakter tidak ready, menunggu respawn...")
                if AutoRespawn then
                    ResetCharacter()
                end
                
                local waitStart = tick()
                while not IsCharacterReady() and AutoLoop and IsAutoLoopPlaying do
                    if tick() - waitStart > 15 then -- Timeout 15 detik
                        print("⏰ Timeout menunggu karakter ready")
                        break
                    end
                    task.wait(0.5)
                end
            end
            
            if not AutoLoop or not IsAutoLoopPlaying then break end
            
            if not IsCharacterReady() then
                -- Skip ke replay berikutnya jika karakter tidak ready
                print("⏭️ Skip replay " .. CurrentLoopIndex .. " - karakter tidak ready")
                CurrentLoopIndex = CurrentLoopIndex + 1
                if CurrentLoopIndex > #SelectedReplaysList then
                    CurrentLoopIndex = 1
                end
                task.wait(2)
                continue
            end
            
            -- Mainkan replay saat ini
            local success = PlaySingleRecording(recordingName)
            
            if success then
                print("✅ Replay " .. CurrentLoopIndex .. " selesai")
                CurrentLoopIndex = CurrentLoopIndex + 1
                if CurrentLoopIndex > #SelectedReplaysList then
                    CurrentLoopIndex = 1
                    print("🔄 Kembali ke replay pertama")
                end
            else
                print("❌ Replay " .. CurrentLoopIndex .. " terinterupsi")
                -- Tetap lanjut ke replay berikutnya
                CurrentLoopIndex = CurrentLoopIndex + 1
                if CurrentLoopIndex > #SelectedReplaysList then
                    CurrentLoopIndex = 1
                end
            end
            
            task.wait(0.5) -- Jeda antar replay
        end
    end)
    
    AddConnection(loopConnection)
end

local function StopAutoLoopAll()
    print("🛑 Menghentikan AutoLoop")
    AutoLoop = false
    IsAutoLoopPlaying = false
    IsPlaying = false
    IsPaused = false
    
    if loopConnection then
        loopConnection:Disconnect()
        loopConnection = nil
    end
    
    if LoopPlaybackConnection then
        LoopPlaybackConnection:Disconnect()
        LoopPlaybackConnection = nil
    end
    
    EnableJump()
    UpdatePauseMarker()
    
    local char = player.Character
    if char then CompleteCharacterReset(char) end
    
    PlaySound("Stop")
end

-- ========= GUI SETUP =========
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoWalkByaruL"
ScreenGui.ResetOnSpawn = false
if player:FindFirstChild("PlayerGui") then
    ScreenGui.Parent = player.PlayerGui
else
    wait(2)
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
Title.Text = "ByaruL - CFrame Mode v2.4"
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

local ResizeButton = Instance.new("TextButton")
ResizeButton.Size = UDim2.fromOffset(24, 24)
ResizeButton.Position = UDim2.new(1, -24, 1, -24)
ResizeButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
ResizeButton.Text = "↖️"
ResizeButton.TextColor3 = Color3.new(1, 1, 1)
ResizeButton.Font = Enum.Font.GothamBold
ResizeButton.TextSize = 20
ResizeButton.ZIndex = 2
ResizeButton.Parent = MainFrame

local ResizeCorner = Instance.new("UICorner")
ResizeCorner.CornerRadius = UDim.new(0, 8)
ResizeCorner.Parent = ResizeButton

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

-- Enhanced Button Creation with Powerful Animations
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

-- TOGGLE LAYOUT: Auto Loop, Infinite Jump, ShiftLock
local LoopBtn, AnimateLoop = CreateToggle("Auto Loop", 0, 75, 78, 22, false)
local JumpBtn, AnimateJump = CreateToggle("Infinite Jump", 82, 75, 78, 22, false)
local ShiftLockBtn, AnimateShiftLock = CreateToggle("ShiftLock", 164, 75, 78, 22, false)

-- TOGGLE: Auto Respawn (kiri), R15 Tall Mode (kanan)
local RespawnBtn, AnimateRespawn = CreateToggle("Auto Respawn", 0, 102, 117, 22, false)
local R15TallBtn, AnimateR15Tall = CreateToggle("R6 → R15 Tall", 123, 102, 117, 22, false)

-- ========= TEXTBOX LAYOUT =========
-- Speed Box (Kiri - 55px)
local SpeedBox = Instance.new("TextBox")
SpeedBox.Size = UDim2.fromOffset(55, 26)
SpeedBox.Position = UDim2.fromOffset(5, 129)
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

-- Filename Box (Tengah - 110px)
local FilenameBox = Instance.new("TextBox")
FilenameBox.Size = UDim2.fromOffset(110, 26)
FilenameBox.Position = UDim2.fromOffset(65, 129)
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

-- WalkSpeed Box (Kanan - 55px)
local WalkSpeedBox = Instance.new("TextBox")
WalkSpeedBox.Size = UDim2.fromOffset(55, 26)
WalkSpeedBox.Position = UDim2.fromOffset(180, 129)
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

local SaveFileBtn = CreateButton("SAVE FILE", 0, 160, 117, 26, Color3.fromRGB(59, 15, 116))
local LoadFileBtn = CreateButton("LOAD FILE", 123, 160, 117, 26, Color3.fromRGB(59, 15, 116))

local PathToggleBtn = CreateButton("SHOW RUTE", 0, 191, 117, 26, Color3.fromRGB(59, 15, 116))
local MergeBtn = CreateButton("MERGE", 123, 191, 117, 26, Color3.fromRGB(59, 15, 116))

-- Record List
local RecordList = Instance.new("ScrollingFrame")
RecordList.Size = UDim2.new(1, 0, 0, 120)
RecordList.Position = UDim2.fromOffset(0, 222)
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
        
        -- ACTION BUTTONS ROW
        local actionRow = Instance.new("Frame")
        actionRow.Size = UDim2.new(1, 0, 0, 25)
        actionRow.BackgroundTransparency = 1
        actionRow.Parent = item
        
        -- Play Button
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
        
        -- Delete Button
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
        
        -- Name TextBox
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
        
        -- Up Button
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
        
        -- Down Button
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
        
        -- INFO ROW
        local infoRow = Instance.new("Frame")
        infoRow.Size = UDim2.new(1, 0, 0, 20)
        infoRow.Position = UDim2.fromOffset(0, 30)
        infoRow.BackgroundTransparency = 1
        infoRow.Parent = item
        
        -- Checkbox
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
        
        -- Info Label
        local infoLabel = Instance.new("TextLabel")
        infoLabel.Size = UDim2.new(1, -40, 1, 0)
        infoLabel.Position = UDim2.fromOffset(30, 0)
        infoLabel.BackgroundTransparency = 1
        
        -- Get recording info
        local recordingRigType = GetRecordingRigType(rec)
        local currentRigType = DetectAdvancedRigType()
        local rigMismatch = recordingRigType ~= currentRigType
        
        -- Show R15 Tall Mode indicator
        local rigText = recordingRigType
        if R15TallMode and recordingRigType == "R6" and currentRigType == "R15_Tall" then
            rigText = rigText .. " → R15_Tall ✓"
            rigMismatch = false
        elseif rigMismatch then
            rigText = rigText .. " ⚠️"
        end
        
        -- Tampilkan indicator Zepeto
        if IsZepetoCharacter then
            rigText = rigText .. " | ZEPETO"
        end
        
        if #rec > 0 then
            local totalSeconds = rec[#rec].Timestamp
            infoLabel.Text = "✔️ " .. FormatDuration(totalSeconds) .. " • " .. #rec .. " frames • " .. rigText
        else
            infoLabel.Text = "❌ 0:00 • 0 frames • " .. rigText
        end
        
        infoLabel.TextColor3 = rigMismatch and Color3.fromRGB(255, 200, 100) or Color3.fromRGB(200, 200, 220)
        infoLabel.Font = Enum.Font.GothamBold
        infoLabel.TextSize = 8
        infoLabel.TextXAlignment = Enum.TextXAlignment.Left
        infoLabel.Parent = infoRow
        
        -- EVENT HANDLERS
        checkbox.MouseButton1Click:Connect(function()
            SelectedReplays[name] = not SelectedReplays[name]
            checkbox.BackgroundColor3 = SelectedReplays[name] and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(40, 40, 50)
            checkbox.Text = SelectedReplays[name] and "✓" or ""
            PlaySound("Toggle")
        end)
        
        upBtn.MouseButton1Click:Connect(function()
            if index > 1 then 
                AnimateButtonClick(upBtn)
                MoveRecordingUp(name) 
            end
        end)
        
        downBtn.MouseButton1Click:Connect(function()
            if index < #RecordingOrder then 
                AnimateButtonClick(downBtn)
                MoveRecordingDown(name) 
            end
        end)
        
        playBtn.MouseButton1Click:Connect(function()
            if not IsPlaying then 
                AnimateButtonClick(playBtn)
                PlayRecording(name) 
            end
        end)
        
        delBtn.MouseButton1Click:Connect(function()
            AnimateButtonClick(delBtn)
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

-- ========= OPTIMIZED RECORDING SYSTEM =========
local lastFrameTime = 0
local frameInterval = 1 / RECORDING_FPS

local function ShouldRecordFrame()
    local currentTime = tick()
    return (currentTime - lastFrameTime) >= frameInterval
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

function StartRecording()
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
        
        if not ShouldRecordFrame() then return end
        
        local hrp = char.HumanoidRootPart
        local hum = char:FindFirstChildOfClass("Humanoid")
        local currentPos = hrp.Position
        local currentVelocity = hrp.AssemblyLinearVelocity
        local moveState = GetCurrentMoveState(hum)

        local velY = currentVelocity.Y
        if moveState == "Falling" and velY > 10 then
            moveState = "Jumping"
        elseif velY > 40 then
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
            RigType = DetectAdvancedRigType(char)
        }
        
        table.insert(CurrentRecording.Frames, frameData)
        lastFrameTime = tick()
        lastRecordPos = currentPos
        
        FrameLabel.Text = string.format("Frames: %d", #CurrentRecording.Frames)
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

-- ========= PERFECTED PLAYBACK SYSTEM =========
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

    -- Detect rig compatibility
    local recordedRig = GetRecordingRigType(recording)
    local currentRig = DetectAdvancedRigType()
    
    -- SMART ROUTE DETECTION: Find nearest frame
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local nearestFrame, distance = FindNearestFrame(recording, hrp.Position)
    
    if distance <= ROUTE_PROXIMITY_THRESHOLD then
        currentPlaybackFrame = nearestFrame
        playbackStartTime = tick() - (GetFrameTimestamp(recording[nearestFrame]) / CurrentSpeed)
    else
        currentPlaybackFrame = 1
        playbackStartTime = tick()
        
        -- Teleport to start position if too far
        local startPos = GetFramePosition(recording[1])
        if (hrp.Position - startPos).Magnitude > 50 then
            hrp.CFrame = CFrame.new(startPos)
        end
    end

    DisableJump()
    PlaySound("Play")

    -- Pure CFrame playback without interpolation
    PlayRecordingWithCFrame(recording, currentPlaybackFrame, recordedRig, currentRig)
end

-- ========= PERFECTED PAUSE SYSTEM =========
function PausePlayback()
    if not IsPlaying and not IsAutoLoopPlaying then return end
    
    IsPaused = not IsPaused
    
    if IsPaused then
        PauseBtnBig.Text = "RESUME"
        PauseBtnBig.BackgroundColor3 = Color3.fromRGB(8, 181, 116)
        EnableJump()
        if ShiftLockEnabled then
            ApplyVisibleShiftLock()
        end
        UpdatePauseMarker()
        PlaySound("Click")
    else
        PauseBtnBig.Text = "PAUSE"
        PauseBtnBig.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
        DisableJump()
        UpdatePauseMarker()
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
    
    EnableJump()
    UpdatePauseMarker()
    
    local char = player.Character
    if char then CompleteCharacterReset(char) end
    
    PlaySound("Stop")
end

-- ========= SELECTIVE SAVE SYSTEM =========
local function SaveToObfuscatedJSON()
    local filename = FilenameBox.Text
    if filename == "" then filename = "MyReplays" end
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
            Version = "2.4",
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
        else
            recordingsToSave = RecordedMovements
            saveData.RecordingOrder = RecordingOrder
            saveData.CheckpointNames = checkpointNames
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
        
        if writefile then
            writefile(filename, jsonString)
            PlaySound("Success")
        else
            PlaySound("Error")
        end
        
        if hasSelected then
            for name, _ in pairs(SelectedReplays) do
                SelectedReplays[name] = false
            end
            UpdateRecordList()
        end
    end)
    
    if not success then
        PlaySound("Error")
    end
end

local function LoadFromObfuscatedJSON()
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
    end)
    
    if not success then
        PlaySound("Error")
    end
end

-- ========= PATH VISUALIZATION FOR ALL RECORDINGS =========
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

-- ========= BUTTON EVENTS WITH ENHANCED ANIMATIONS =========
RecordBtnBig.MouseButton1Click:Connect(function()
    AnimateButtonClick(RecordBtnBig)
    if IsRecording then 
        StopRecording() 
    else 
        StartRecording() 
    end
end)

PlayBtnBig.MouseButton1Click:Connect(function()
    AnimateButtonClick(PlayBtnBig)
    if AutoLoop then return end
    PlayRecording()
end)

StopBtnBig.MouseButton1Click:Connect(function()
    AnimateButtonClick(StopBtnBig)
    StopPlayback()
end)

PauseBtnBig.MouseButton1Click:Connect(function()
    AnimateButtonClick(PauseBtnBig)
    PausePlayback()
end)

LoopBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(LoopBtn)
    AutoLoop = not AutoLoop
    AnimateLoop(AutoLoop)
    
    if AutoLoop then
        -- AUTO CEKLIS SEMUA REPLAY YANG VALID
        local hasAnyValid = false
        for _, name in ipairs(RecordingOrder) do
            if RecordedMovements[name] and #RecordedMovements[name] > 0 then
                SelectedReplays[name] = true
                hasAnyValid = true
            end
        end
        
        if not hasAnyValid then
            AutoLoop = false
            AnimateLoop(false)
            PlaySound("Error")
            return
        end
        
        UpdateRecordList()
        
        if IsPlaying then
            IsPlaying = false
            IsPaused = false
            EnableJump()
        end
        
        StartAutoLoopAll()
    else
        StopAutoLoopAll()
    end
end)

ShiftLockBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(ShiftLockBtn)
    ToggleVisibleShiftLock()
    AnimateShiftLock(ShiftLockEnabled)
end)

RespawnBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(RespawnBtn)
    AutoRespawn = not AutoRespawn
    AnimateRespawn(AutoRespawn)
    PlaySound("Toggle")
end)

-- ========= R15 TALL MODE TOGGLE =========
R15TallBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(R15TallBtn)
    R15TallMode = not R15TallMode
    AnimateR15Tall(R15TallMode)
    
    -- Update record list to show conversion indicator
    UpdateRecordList()
    
    PlaySound("Toggle")
end)

JumpBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(JumpBtn)
    ToggleInfiniteJump()
    AnimateJump(InfiniteJump)
    PlaySound("Toggle")
end)

SaveFileBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(SaveFileBtn)
    SaveToObfuscatedJSON()
end)

LoadFileBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(LoadFileBtn)
    LoadFromObfuscatedJSON()
end)

PathToggleBtn.MouseButton1Click:Connect(function()
    AnimateButtonClick(PathToggleBtn)
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
    AnimateButtonClick(MergeBtn)
    CreateMergedReplay()
end)

HideButton.MouseButton1Click:Connect(function()
    AnimateButtonClick(HideButton)
    MainFrame.Visible = false
    MiniButton.Visible = true
end)

MiniButton.MouseButton1Click:Connect(function()
    AnimateButtonClick(MiniButton)
    MainFrame.Visible = true
    MiniButton.Visible = false
end)

CloseButton.MouseButton1Click:Connect(function()
    AnimateButtonClick(CloseButton)
    if IsRecording then StopRecording() end
    if IsPlaying or AutoLoop then StopPlayback() end
    if ShiftLockEnabled then DisableVisibleShiftLock() end
    if InfiniteJump then DisableInfiniteJump() end
    CleanupConnections()
    ClearPathVisualization()
    ScreenGui:Destroy()
end)

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
            -- Auto ceklis semua saat pertama kali aktifkan dengan F7
            local hasAnyValid = false
            for _, name in ipairs(RecordingOrder) do
                if RecordedMovements[name] and #RecordedMovements[name] > 0 then
                    SelectedReplays[name] = true
                    hasAnyValid = true
                end
            end
            
            if hasAnyValid then
                UpdateRecordList()
                StartAutoLoopAll() 
            else
                AutoLoop = false
                AnimateLoop(false)
            end
        else 
            StopAutoLoopAll() 
        end
    elseif input.KeyCode == Enum.KeyCode.F6 then
        SaveToObfuscatedJSON()
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
        ToggleVisibleShiftLock()
        AnimateShiftLock(ShiftLockEnabled)
    elseif input.KeyCode == Enum.KeyCode.F2 then
        ToggleInfiniteJump()
        AnimateJump(InfiniteJump)
    elseif input.KeyCode == Enum.KeyCode.F1 then
        R15TallMode = not R15TallMode
        AnimateR15Tall(R15TallMode)
        UpdateRecordList()
    end
end)

-- ========= INITIAL SETUP =========
UpdateRecordList()

-- IMPROVED RIG DETECTION ON STARTUP
task.spawn(function()
    task.wait(1)
    CurrentRigType = DetectAdvancedRigType()
    IsZepetoCharacter = DetectZepetoCharacter()
    
    if IsZepetoCharacter then
        print("🎭 ZEPETO/2D CHARACTER DETECTED! Applying special fixes...")
        ForceZepetoMode = true
        UpdateRecordList()
    end
    
    print("🔧 Current Rig Type: " .. CurrentRigType)
    print("🔧 Zepeto Mode: " .. tostring(IsZepetoCharacter))
end)

task.spawn(function()
    task.wait(2)
    local filename = "MyReplays.json"
    if readfile and isfile and isfile(filename) then
        LoadFromObfuscatedJSON()
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
    -- AutoLoop will continue after respawn
end)

-- ========= IMPROVED CHARACTER ADDED HANDLER =========
player.CharacterAdded:Connect(function(character)
    task.wait(1)
    local newRig = DetectAdvancedRigType(character)
    CurrentRigType = newRig
    IsZepetoCharacter = DetectZepetoCharacter(character)
    
    if IsZepetoCharacter then
        print("🎭 ZEPETO/2D CHARACTER DETECTED! Applying special fixes...")
        ForceZepetoMode = true
    end
    
    local humanoid = character:WaitForChild("Humanoid", 5)
    if humanoid then
        humanoid.WalkSpeed = CurrentWalkSpeed
        humanoid.JumpPower = GetRigProfile(newRig).JumpPower
    end
    
    UpdateRecordList()
end)

-- ========= FINAL INITIALIZATION =========
game:GetService("ScriptContext").DescendantRemoving:Connect(function(descendant)
    if descendant == ScreenGui then
        CleanupConnections()
        ClearPathVisualization()
    end
end)

-- ========= IMPROVED RIG TYPE MONITOR =========
task.spawn(function()
    while true do
        task.wait(3) -- Check every 3 seconds
        if player.Character then
            local currentRig = DetectAdvancedRigType()
            local wasZepeto = IsZepetoCharacter
            IsZepetoCharacter = DetectZepetoCharacter()
            
            if currentRig ~= CurrentRigType then
                CurrentRigType = currentRig
                UpdateRecordList()
                print("🔧 Rig Type Changed: " .. CurrentRigType)
            end
            
            if IsZepetoCharacter and not wasZepeto then
                print("🎭 ZEPETO/2D CHARACTER DETECTED! Applying special fixes...")
                ForceZepetoMode = true
                UpdateRecordList()
            elseif not IsZepetoCharacter and wasZepeto then
                print("🔧 Zepeto Mode Disabled")
                ForceZepetoMode = false
                UpdateRecordList()
            end
        end
    end
end)

print("✅ AutoWalk ByaruL v2.4 - Enhanced CFrame Mode Loaded!")
print("🔧 Fixed: Interpolation removed to prevent sticking")
print("🔧 Fixed: Improved Zepeto detection and height adjustment") 
print("🔧 Fixed: Auto Loop now auto-selects all replays and continues after death")