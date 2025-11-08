-- ========= AUTO WALK PRO v8.5 - ENHANCED REVERSE SYSTEM =========
-- GUI AutoWalk Pro v8.5 + Advanced Recording System ByaruL v3.0
-- Perfect Timeline + Reverse Playback + Seamless Fall Recovery

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
wait(1)

-- ========= CONFIGURATION =========
local RECORDING_FPS = 60
local MAX_FRAMES = 30000
local MIN_DISTANCE_THRESHOLD = 0.015
local VELOCITY_SCALE = 1
local VELOCITY_Y_SCALE = 1
local ROUTE_PROXIMITY_THRESHOLD = 10
local TIMELINE_STEP_SECONDS = 1

-- ========= REVERSE PLAYBACK CONFIG =========
local REVERSE_SPEED_MULTIPLIER = 2.0
local FORWARD_SPEED_MULTIPLIER = 2.0
local REVERSE_FRAME_STEP = 2
local FORWARD_FRAME_STEP = 2

-- ========= REAL-TIME PLAYBACK CONFIG =========
local INTERPOLATION_ENABLED = true
local INTERPOLATION_ALPHA = 0.45
local MIN_INTERPOLATION_DISTANCE = 0.3

-- ========= UNIVERSAL CHARACTER SUPPORT =========
local UNIVERSAL_MODE = true
local DYNAMIC_GROUND_OFFSET = true
local R6_OFFSET = 3.2
local R15_OFFSET = 4.8
local FALLBACK_OFFSET = 3.5

-- ========= FALL DETECTION CONFIG =========
local FALL_TIME_THRESHOLD = 0.8
local FALL_HEIGHT_THRESHOLD = 15
local FALL_VELOCITY_THRESHOLD = -50
local SAFE_FRAME_BUFFER = 10

-- ========= CORE VARIABLES =========
local IsRecording = false
local IsPlaying = false
local IsPaused = false
local IsReversing = false
local IsForwarding = false
local UseMoveTo = false
local CurrentSpeed = 1
local RecordedMovements = {}
local CurrentRecording = {Frames = {}, StartTime = 0, Name = ""}
local AutoHeal = false
local AutoLoop = false
local recordConnection = nil
local playbackConnection = nil
local lastRecordTime = 0
local lastRecordPos = nil
local ShowVisualization = false

-- ========= ANTI-FALL VARIABLES =========
local IsFallDetected = false
local LastSafeFrame = 0
local LastSafePosition = nil
local LastSafeVelocity = nil
local fallStartTime = 0
local fallStartHeight = 0
local isCurrentlyFalling = false
local FallCheckEnabled = true
local PreFallFrameCount = 0

-- ========= PAUSE/RESUME VARIABLES =========
local playbackStartTime = 0
local totalPausedDuration = 0
local pauseStartTime = 0
local currentPlaybackFrame = 1
local lastMoveState = nil
local currentRecordingName = ""

-- ========= TIMELINE NAVIGATION VARIABLES =========
local TimelinePosition = 0
local IsTimelineMode = false
local timelineGroundedStart = nil
local ReverseStartFrame = 0
local reverseConnection = nil
local forwardConnection = nil

-- ========= REAL-TIME PLAYBACK VARIABLES =========
local lastPlaybackCFrame = nil
local lastPlaybackVelocity = Vector3.new(0, 0, 0)
local prePauseHumanoidState = nil
local prePauseWalkSpeed = 16
local prePauseAutoRotate = true
local prePauseJumpPower = 50

-- ========= SEAMLESS TRANSITION VARIABLES =========
local TransitionFrames = {}
local IsTransitionMode = false
local TransitionStartFrame = 0

-- ========= EVENT CLEANUP =========
local eventConnections = {}

local function AddConnection(conn)
    table.insert(eventConnections, conn)
end

local function CleanupConnections()
    for _, conn in pairs(eventConnections) do
        pcall(function()
            if conn and conn.Connected then
                conn:Disconnect()
            end
        end)
    end
    eventConnections = {}
end

-- ========= ENHANCED PCALL WRAPPER =========
local function SafeCall(func, ...)
    local success, result = pcall(func, ...)
    return success, result
end

-- ========= UNIVERSAL CHARACTER DETECTION =========
local function GetCharacterType()
    local char = player.Character
    if not char then return "Unknown" end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return "Unknown" end
    
    if humanoid.RigType == Enum.HumanoidRigType.R6 then
        return "R6"
    elseif humanoid.RigType == Enum.HumanoidRigType.R15 then
        return "R15"
    end
    
    local leftLeg = char:FindFirstChild("Left Leg")
    local leftLowerLeg = char:FindFirstChild("LeftLowerLeg")
    
    if leftLeg and not leftLowerLeg then
        return "R6"
    elseif leftLowerLeg then
        return "R15"
    end
    
    return "Unknown"
end

local function GetDynamicGroundOffset()
    if not DYNAMIC_GROUND_OFFSET then
        return FALLBACK_OFFSET
    end
    
    local charType = GetCharacterType()
    if charType == "R6" then
        return R6_OFFSET
    elseif charType == "R15" then
        return R15_OFFSET
    else
        return FALLBACK_OFFSET
    end
end

local function GetOptimalGroundOffset()
    local charType = GetCharacterType()
    
    if charType == "R6" then
        return 3.2
    elseif charType == "R15" then
        return 4.8
    else
        return FALLBACK_OFFSET
    end
end

-- ========= ENHANCED GROUND DETECTION =========
local function GetEnhancedGroundHeight(position, character)
    local rayOrigin = Vector3.new(position.X, position.Y + 8, position.Z)
    local rayDirection = Vector3.new(0, -20, 0)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    if character then
        raycastParams.FilterDescendantsInstances = {character}
    end
    
    local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    if rayResult then
        return rayResult.Position.Y
    end
    
    return position.Y - 5
end

local function AdjustPositionToGround(position)
    local char = player.Character
    local groundHeight = GetEnhancedGroundHeight(position, char)
    local offset = GetOptimalGroundOffset()
    
    local charType = GetCharacterType()
    if charType == "R15" then
        offset = offset + 0.2
    end
    
    return Vector3.new(position.X, groundHeight + offset, position.Z)
end

-- ========= R15 VELOCITY CONTROL =========
local function ApplyUniversalVelocity(character, velocity)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local charType = GetCharacterType()
    
    if charType == "R15" then
        local bodyVelocity = hrp:FindFirstChild("AutoWalkBodyVelocity")
        if not bodyVelocity then
            bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.Name = "AutoWalkBodyVelocity"
            bodyVelocity.MaxForce = Vector3.new(4000, 0, 4000)
            bodyVelocity.Parent = hrp
        end
        
        local currentVel = bodyVelocity.Velocity
        local smoothVelocity = currentVel:Lerp(velocity, 0.3)
        bodyVelocity.Velocity = smoothVelocity
        
        return true
    else
        SafeCall(function()
            hrp.AssemblyLinearVelocity = velocity
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end)
        return true
    end
end

-- ========= CHARACTER RESET =========
local function CompleteCharacterReset(char)
    SafeCall(function()
        if not char or not char:IsDescendantOf(workspace) then return end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not humanoid or not hrp then return end
        
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 50
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
        
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
        
        local bodyVelocity = hrp:FindFirstChild("AutoWalkBodyVelocity")
        if bodyVelocity then
            bodyVelocity:Destroy()
        end
    end)
end

-- ========= ENHANCED FALL DETECTION =========
local function GetCurrentMoveState(hum, hrp)
    if not hum then return "Grounded" end
    
    local state = hum:GetState()
    local currentVelocity = hrp.AssemblyLinearVelocity
    
    if state == Enum.HumanoidStateType.Freefall then
        if not isCurrentlyFalling then
            isCurrentlyFalling = true
            fallStartTime = tick()
            fallStartHeight = hrp.Position.Y
        end
        
        local fallDuration = tick() - fallStartTime
        local fallDistance = fallStartHeight - hrp.Position.Y
        
        if FallCheckEnabled and (
            (fallDuration > FALL_TIME_THRESHOLD and fallDistance > FALL_HEIGHT_THRESHOLD) or
            currentVelocity.Y < FALL_VELOCITY_THRESHOLD
        ) then
            IsFallDetected = true
            return "Falling"
        end
        
        return "Falling"
    else
        if isCurrentlyFalling then
            isCurrentlyFalling = false
            fallStartTime = 0
            fallStartHeight = 0
        end
    end
    
    if hrp.Position.Y < -50 then
        IsFallDetected = true
        return "Falling"
    end
    
    if state == Enum.HumanoidStateType.Jumping then
        return "Jumping"
    elseif state == Enum.HumanoidStateType.Climbing then
        return "Climbing"
    elseif state == Enum.HumanoidStateType.Swimming then
        return "Swimming"
    elseif state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics then
        return "Grounded"
    else
        return "Grounded"
    end
end

-- ========= FRAME DATA FUNCTIONS =========
local function GetFramePosition(frame)
    return Vector3.new(frame.Position[1], frame.Position[2], frame.Position[3])
end

local function GetFrameCFrame(frame)
    local pos = GetFramePosition(frame)
    local look = Vector3.new(frame.LookVector[1], frame.LookVector[2], frame.LookVector[3])
    local up = Vector3.new(frame.UpVector[1], frame.UpVector[2], frame.UpVector[3])
    
    pos = AdjustPositionToGround(pos)
    
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

-- ========= SEAMLESS FRAME DELETION =========
local function DeleteFramesFromFall(startFrame)
    SafeCall(function()
        if #CurrentRecording.Frames == 0 or startFrame <= 0 then return end
        
        local framesToDelete = math.min(SAFE_FRAME_BUFFER, #CurrentRecording.Frames - startFrame)
        
        for i = 1, framesToDelete do
            if #CurrentRecording.Frames > startFrame then
                table.remove(CurrentRecording.Frames, #CurrentRecording.Frames)
            end
        end
        
        PreFallFrameCount = #CurrentRecording.Frames
        
        if #CurrentRecording.Frames > 0 then
            local lastFrame = CurrentRecording.Frames[#CurrentRecording.Frames]
            LastSafePosition = GetFramePosition(lastFrame)
            LastSafeVelocity = GetFrameVelocity(lastFrame)
        end
    end)
end

-- ========= SEAMLESS TRANSITION CREATOR =========
local function CreateSeamlessTransition(fromFrame, toPosition)
    SafeCall(function()
        TransitionFrames = {}
        IsTransitionMode = true
        TransitionStartFrame = #CurrentRecording.Frames
        
        if not fromFrame then return end
        
        local startPos = GetFramePosition(fromFrame)
        local distance = (toPosition - startPos).Magnitude
        local transitionSteps = math.max(5, math.floor(distance / 2))
        
        for i = 1, transitionSteps do
            local alpha = i / transitionSteps
            local interpPos = startPos:Lerp(toPosition, alpha)
            local interpVel = GetFrameVelocity(fromFrame):Lerp(Vector3.new(0, 0, 0), alpha)
            
            table.insert(TransitionFrames, {
                Position = {interpPos.X, interpPos.Y, interpPos.Z},
                LookVector = fromFrame.LookVector,
                UpVector = fromFrame.UpVector,
                Velocity = {interpVel.X, interpVel.Y, interpVel.Z},
                MoveState = "Grounded",
                WalkSpeed = fromFrame.WalkSpeed or 16,
                Timestamp = fromFrame.Timestamp + (i * 0.016)
            })
        end
    end)
end

-- ========= FIND NEAREST FRAME =========
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

-- ========= INTERPOLATION FUNCTION =========
local function SmoothCFrameLerp(currentCF, targetCF, alpha)
    if not INTERPOLATION_ENABLED then
        return targetCF
    end
    
    local currentPos = currentCF.Position
    local targetPos = targetCF.Position
    local distance = (targetPos - currentPos).Magnitude
    
    if distance > 25 then
        return targetCF
    end
    
    if distance < MIN_INTERPOLATION_DISTANCE then
        return targetCF
    end
    
    local newPos = currentPos:Lerp(targetPos, alpha)
    local newCF = currentCF:Lerp(targetCF, alpha)
    
    return CFrame.new(newPos) * (newCF - newCF.Position)
end

-- ========= PAUSE STATE MANAGEMENT =========
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

local function RestoreHumanoidState()
    local char = player.Character
    if not char then return end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.AutoRotate = prePauseAutoRotate
        humanoid.WalkSpeed = prePauseWalkSpeed
        humanoid.JumpPower = prePauseJumpPower
    end
end

-- ========= UNIVERSAL STATE CONTROL =========
local function UniversalStateControl(humanoid, targetState)
    if not humanoid then return end
    
    SafeCall(function()
        if targetState == "Climbing" then
            humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
        elseif targetState == "Jumping" then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        elseif targetState == "Swimming" then
            humanoid:ChangeState(Enum.HumanoidStateType.Swimming)
        elseif targetState == "Falling" then
            humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        else
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end
    end)
end

-- ========= GUI SETUP =========
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoWalkProV85"
ScreenGui.ResetOnSpawn = false

SafeCall(function()
    if player:FindFirstChild("PlayerGui") then
        ScreenGui.Parent = player.PlayerGui
    else
        wait(2)
        ScreenGui.Parent = player:WaitForChild("PlayerGui")
    end
end)

-- ========= RECORDING STUDIO GUI (230x230) =========
local RecordingStudio = Instance.new("Frame")
RecordingStudio.Size = UDim2.fromOffset(230, 230)
RecordingStudio.Position = UDim2.new(0.5, -115, 0.5, -115)
RecordingStudio.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
RecordingStudio.BorderSizePixel = 0
RecordingStudio.Active = true
RecordingStudio.Draggable = true
RecordingStudio.Visible = false
RecordingStudio.Parent = ScreenGui

local StudioCorner = Instance.new("UICorner")
StudioCorner.CornerRadius = UDim.new(0, 10)
StudioCorner.Parent = RecordingStudio

local StudioStroke = Instance.new("UIStroke")
StudioStroke.Color = Color3.fromRGB(100, 150, 255)
StudioStroke.Thickness = 2
StudioStroke.Parent = RecordingStudio

-- Studio Header
local StudioHeader = Instance.new("Frame")
StudioHeader.Size = UDim2.new(1, 0, 0, 28)
StudioHeader.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
StudioHeader.BorderSizePixel = 0
StudioHeader.Parent = RecordingStudio

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 10)
HeaderCorner.Parent = StudioHeader

local StudioTitle = Instance.new("TextLabel")
StudioTitle.Size = UDim2.new(1, -30, 1, 0)
StudioTitle.Position = UDim2.new(0, 10, 0, 0)
StudioTitle.BackgroundTransparency = 1
StudioTitle.Text = "🎬 RECORDING STUDIO v8.5"
StudioTitle.TextColor3 = Color3.fromRGB(100, 200, 255)
StudioTitle.Font = Enum.Font.GothamBold
StudioTitle.TextSize = 11
StudioTitle.TextXAlignment = Enum.TextXAlignment.Left
StudioTitle.Parent = StudioHeader

local CloseStudioBtn = Instance.new("TextButton")
CloseStudioBtn.Size = UDim2.fromOffset(20, 20)
CloseStudioBtn.Position = UDim2.new(1, -24, 0.5, -10)
CloseStudioBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
CloseStudioBtn.Text = "×"
CloseStudioBtn.TextColor3 = Color3.new(1, 1, 1)
CloseStudioBtn.Font = Enum.Font.GothamBold
CloseStudioBtn.TextSize = 14
CloseStudioBtn.Parent = StudioHeader

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 5)
CloseCorner.Parent = CloseStudioBtn

-- Studio Content
local StudioContent = Instance.new("Frame")
StudioContent.Size = UDim2.new(1, -16, 1, -36)
StudioContent.Position = UDim2.new(0, 8, 0, 32)
StudioContent.BackgroundTransparency = 1
StudioContent.Parent = RecordingStudio

-- Helper function
local function CreateStudioBtn(text, x, y, w, h, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(w, h)
    btn.Position = UDim2.fromOffset(x, y)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 9
    btn.AutoButtonColor = false
    btn.Parent = StudioContent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = btn
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 1
    stroke.Transparency = 0.7
    stroke.Parent = btn
    
    btn.MouseEnter:Connect(function()
        SafeCall(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(
                    math.min(color.R * 255 + 30, 255),
                    math.min(color.G * 255 + 30, 255),
                    math.min(color.B * 255 + 30, 255)
                )
            }):Play()
        end)
    end)
    
    btn.MouseLeave:Connect(function()
        SafeCall(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = color}):Play()
        end)
    end)
    
    return btn
end

-- Top Row Buttons
local RecordBtn = CreateStudioBtn("● RECORD", 5, 5, 68, 30, Color3.fromRGB(200, 50, 60))
local SaveBtn = CreateStudioBtn("💾 SAVE", 78, 5, 68, 30, Color3.fromRGB(100, 200, 100))
local ClearBtn = CreateStudioBtn("🗑️ CLEAR", 151, 5, 68, 30, Color3.fromRGB(150, 50, 60))

-- Frame Counter
local FrameLabel = Instance.new("TextLabel")
FrameLabel.Size = UDim2.fromOffset(214, 28)
FrameLabel.Position = UDim2.fromOffset(5, 40)
FrameLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
FrameLabel.Text = "Frames: 0 / 30000 | Safe: 0"
FrameLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
FrameLabel.Font = Enum.Font.GothamBold
FrameLabel.TextSize = 10
FrameLabel.Parent = StudioContent

local FrameCorner = Instance.new("UICorner")
FrameCorner.CornerRadius = UDim.new(0, 5)
FrameCorner.Parent = FrameLabel

local FrameStroke = Instance.new("UIStroke")
FrameStroke.Color = Color3.fromRGB(60, 60, 70)
FrameStroke.Thickness = 1
FrameStroke.Parent = FrameLabel

-- Timeline Label
local TimelineLabel = Instance.new("TextLabel")
TimelineLabel.Size = UDim2.fromOffset(214, 20)
TimelineLabel.Position = UDim2.fromOffset(5, 73)
TimelineLabel.BackgroundTransparency = 1
TimelineLabel.Text = "⏮️ Reverse / Forward Timeline ⏭️"
TimelineLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
TimelineLabel.Font = Enum.Font.Gotham
TimelineLabel.TextSize = 8
TimelineLabel.Parent = StudioContent

-- Timeline Buttons
local ReverseBtn = CreateStudioBtn("⏪ MUNDUR", 5, 98, 104, 35, Color3.fromRGB(80, 120, 200))
local ForwardBtn = CreateStudioBtn("⏩ MAJU", 114, 98, 105, 35, Color3.fromRGB(200, 120, 80))

-- Resume Button
local ResumeBtn = CreateStudioBtn("▶ RESUME", 5, 138, 214, 30, Color3.fromRGB(40, 180, 80))

-- Status Label
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.fromOffset(214, 20)
StatusLabel.Position = UDim2.fromOffset(5, 173)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Ready to record"
StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 8
StatusLabel.Parent = StudioContent

-- ========= CLEAN MAIN GUI (250x200) =========
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.fromOffset(250, 200)
MainFrame.Position = UDim2.new(0.5, -125, 0.5, -100)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(60, 60, 60)
MainStroke.Thickness = 2
MainStroke.Parent = MainFrame

-- Main Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 32)
Header.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local MainHeaderCorner = Instance.new("UICorner")
MainHeaderCorner.CornerRadius = UDim.new(0, 12)
MainHeaderCorner.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -60, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "AUTO WALK PRO v8.5"
Title.TextColor3 = Color3.fromRGB(100, 255, 150)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local HideButton = Instance.new("TextButton")
HideButton.Size = UDim2.fromOffset(20, 20)
HideButton.Position = UDim2.new(1, -50, 0.5, -10)
HideButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
HideButton.Text = "_"
HideButton.TextColor3 = Color3.new(1, 1, 1)
HideButton.Font = Enum.Font.GothamBold
HideButton.TextSize = 12
HideButton.Parent = Header

local HideCorner = Instance.new("UICorner")
HideCorner.CornerRadius = UDim.new(0, 6)
HideCorner.Parent = HideButton

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.fromOffset(20, 20)
CloseButton.Position = UDim2.new(1, -25, 0.5, -10)
CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
CloseButton.Text = "×"
CloseButton.TextColor3 = Color3.new(1, 1, 1)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 14
CloseButton.Parent = Header

local CloseCorner2 = Instance.new("UICorner")
CloseCorner2.CornerRadius = UDim.new(0, 6)
CloseCorner2.Parent = CloseButton

-- Content Area
local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, -16, 1, -40)
Content.Position = UDim2.new(0, 8, 0, 36)
Content.BackgroundTransparency = 1
Content.ScrollBarThickness = 4
Content.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
Content.CanvasSize = UDim2.new(0, 0, 0, 400)
Content.Parent = MainFrame

-- Mini Button
local MiniButton = Instance.new("TextButton")
MiniButton.Size = UDim2.fromOffset(40, 40)
MiniButton.Position = UDim2.new(0, 20, 0.5, -20)
MiniButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MiniButton.Text = "AWP"
MiniButton.TextColor3 = Color3.fromRGB(100, 255, 150)
MiniButton.Font = Enum.Font.GothamBold
MiniButton.TextSize = 12
MiniButton.Visible = false
MiniButton.Active = true
MiniButton.Draggable = true
MiniButton.Parent = ScreenGui

local MiniCorner = Instance.new("UICorner")
MiniCorner.CornerRadius = UDim.new(0, 8)
MiniCorner.Parent = MiniButton

local MiniStroke = Instance.new("UIStroke")
MiniStroke.Color = Color3.fromRGB(100, 255, 150)
MiniStroke.Thickness = 2
MiniStroke.Parent = MiniButton

-- ========= CLEAN GUI COMPONENTS =========
local function CreateElegantButton(text, x, y, w, h, color, parent)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(w, h)
    btn.Position = UDim2.fromOffset(x, y)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.AutoButtonColor = false
    btn.Parent = parent or Content
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 60)
    stroke.Thickness = 1
    stroke.Parent = btn
    
    btn.MouseEnter:Connect(function()
        SafeCall(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(
                math.min(color.R * 255 + 20, 255),
                math.min(color.G * 255 + 20, 255), 
                math.min(color.B * 255 + 20, 255)
            )}):Play()
        end)
    end)
    
    btn.MouseLeave:Connect(function()
        SafeCall(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = color}):Play()
        end)
    end)
    
    return btn
end

local function CreateElegantTextBox(placeholder, x, y, w, h, parent)
    local box = Instance.new("TextBox")
    box.Size = UDim2.fromOffset(w, h)
    box.Position = UDim2.fromOffset(x, y)
    box.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    box.Text = ""
    box.PlaceholderText = placeholder
    box.TextColor3 = Color3.fromRGB(200, 200, 220)
    box.Font = Enum.Font.Gotham
    box.TextSize = 10
    box.Parent = parent or Content
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = box
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 60)
    stroke.Thickness = 1
    stroke.Parent = box
    
    box.Focused:Connect(function()
        SafeCall(function()
            TweenService:Create(box, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(35, 35, 35)}):Play()
            TweenService:Create(stroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(100, 255, 150)}):Play()
        end)
    end)
    
    box.FocusLost:Connect(function()
        SafeCall(function()
            TweenService:Create(box, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(25, 25, 25)}):Play()
            TweenService:Create(stroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(60, 60, 60)}):Play()
        end)
    end)
    
    return box
end

local function CreateToggleButton(text, x, y, w, h, defaultState)
    local btn = CreateElegantButton(text, x, y, w, h, defaultState and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(80, 80, 80))
    
    local isOn = defaultState
    
    local function UpdateButton()
        if isOn then
            btn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
            btn.Text = text .. " ON"
        else
            btn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
            btn.Text = text .. " OFF"
        end
    end
    
    UpdateButton()
    
    btn.MouseEnter:Connect(function()
        SafeCall(function()
            if isOn then
                TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(60, 200, 100)}):Play()
            else
                TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(100, 100, 100)}):Play()
            end
        end)
    end)
    
    btn.MouseLeave:Connect(function()
        SafeCall(function()
            if isOn then
                TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 180, 80)}):Play()
            else
                TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(80, 80, 80)}):Play()
            end
        end)
    end)
    
    return btn, function() return isOn end, function(state) 
        isOn = state 
        UpdateButton()
    end
end

-- Status Label
local Status = Instance.new("TextLabel")
Status.Size = UDim2.fromOffset(234, 20)
Status.Position = UDim2.fromOffset(0, 380)
Status.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Status.BackgroundTransparency = 0
Status.Text = "System Ready - v8.5 Enhanced Reverse"
Status.TextColor3 = Color3.fromRGB(100, 255, 150)
Status.Font = Enum.Font.Gotham
Status.TextSize = 9
Status.TextXAlignment = Enum.TextXAlignment.Center
Status.Parent = Content

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 6)
StatusCorner.Parent = Status

local StatusStroke = Instance.new("UIStroke")
StatusStroke.Color = Color3.fromRGB(60, 60, 60)
StatusStroke.Thickness = 1
StatusStroke.Parent = Status

-- Main GUI Layout
local OpenStudioBtn = CreateElegantButton("🎬 RECORDING STUDIO", 10, 5, 230, 30, Color3.fromRGB(100, 150, 255))

local PauseBtn = CreateElegantButton("⏸ PAUSE", 10, 40, 70, 26, Color3.fromRGB(255, 150, 50))
local PlayBtn = CreateElegantButton("▶ PLAY", 85, 40, 70, 26, Color3.fromRGB(40, 180, 80))
local StopBtn = CreateElegantButton("■ STOP", 160, 40, 70, 26, Color3.fromRGB(150, 50, 60))

local MoveToBtn, GetMoveToState, SetMoveToState = CreateToggleButton("MoveTo", 10, 75, 110, 24, false)
local VisualBtn, GetVisualState, SetVisualState = CreateToggleButton("Visual", 125, 75, 110, 24, false)
local LoopBtn, GetLoopState, SetLoopState = CreateToggleButton("Loop", 10, 105, 110, 24, false)
local HealBtn, GetHealState, SetHealState = CreateToggleButton("Heal", 125, 105, 110, 24, false)

local FileNameBox = CreateElegantTextBox("filename", 10, 140, 150, 24)
local SaveFileBtn = CreateElegantButton("SAVE", 165, 140, 35, 24, Color3.fromRGB(40, 140, 70))
local LoadFileBtn = CreateElegantButton("LOAD", 205, 140, 35, 24, Color3.fromRGB(140, 100, 40))

local SpeedMinus = CreateElegantButton("-", 10, 175, 50, 24, Color3.fromRGB(60, 60, 60))
local SpeedPlus = CreateElegantButton("+", 190, 175, 50, 24, Color3.fromRGB(60, 60, 60))

local SpeedDisplay = Instance.new("TextLabel")
SpeedDisplay.Size = UDim2.fromOffset(120, 24)
SpeedDisplay.Position = UDim2.fromOffset(65, 175)
SpeedDisplay.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
SpeedDisplay.BackgroundTransparency = 0
SpeedDisplay.Text = "1.00x"
SpeedDisplay.TextColor3 = Color3.fromRGB(100, 255, 150)
SpeedDisplay.Font = Enum.Font.Gotham
SpeedDisplay.TextSize = 11
SpeedDisplay.TextXAlignment = Enum.TextXAlignment.Center
SpeedDisplay.Parent = Content

local SpeedCorner2 = Instance.new("UICorner")
SpeedCorner2.CornerRadius = UDim.new(0, 6)
SpeedCorner2.Parent = SpeedDisplay

local SpeedStroke = Instance.new("UIStroke")
SpeedStroke.Color = Color3.fromRGB(60, 60, 60)
SpeedStroke.Thickness = 1
SpeedStroke.Parent = SpeedDisplay

-- Replay List
local ReplayList = Instance.new("ScrollingFrame")
ReplayList.Size = UDim2.new(1, 0, 0, 170)
ReplayList.Position = UDim2.fromOffset(0, 205)
ReplayList.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
ReplayList.BorderSizePixel = 0
ReplayList.ScrollBarThickness = 4
ReplayList.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
ReplayList.CanvasSize = UDim2.new(0, 0, 0, 0)
ReplayList.Parent = Content

local ListCorner = Instance.new("UICorner")
ListCorner.CornerRadius = UDim.new(0, 6)
ListCorner.Parent = ReplayList

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 2)
ListLayout.Parent = ReplayList

-- ========= ROUTE VISUALIZATION =========
local routeParts = {}
local routeBeams = {}

local function ClearRouteVisualization()
    SafeCall(function()
        for _, part in pairs(routeParts) do
            if part and part.Parent then
                part:Destroy()
            end
        end
        for _, beam in pairs(routeBeams) do
            if beam and beam.Parent then
                beam:Destroy()
            end
        end
        routeParts = {}
        routeBeams = {}
    end)
end

local function ShowRouteVisualization(recording)
    ClearRouteVisualization()
    
    if not recording or #recording == 0 or not ShowVisualization then return end
    
    SafeCall(function()
        local folder = Instance.new("Folder")
        folder.Name = "RouteVisualization"
        folder.Parent = workspace
        
        local lastPart = nil
        local step = math.max(10, math.floor(#recording / 500))
        
        for i = 1, #recording, step do
            local frame = recording[i]
            local pos = GetFramePosition(frame)
            
            local part = Instance.new("Part")
            part.Size = Vector3.new(0.3, 0.3, 0.3)
            part.Position = pos
            part.Anchored = true
            part.CanCollide = false
            part.Transparency = 0.4
            part.Color = Color3.fromRGB(100, 255, 150)
            part.Material = Enum.Material.Neon
            part.Shape = Enum.PartType.Ball
            part.Parent = folder
            
            table.insert(routeParts, part)
            
            if lastPart then
                local beam = Instance.new("Beam")
                beam.Attachment0 = Instance.new("Attachment")
                beam.Attachment0.Parent = lastPart
                beam.Attachment1 = Instance.new("Attachment")
                beam.Attachment1.Parent = part
                beam.Color = ColorSequence.new(Color3.fromRGB(100, 255, 150))
                beam.Width0 = 0.15
                beam.Width1 = 0.15
                beam.Brightness = 2
                beam.Parent = folder
                
                table.insert(routeBeams, beam)
                table.insert(routeBeams, beam.Attachment0)
                table.insert(routeBeams, beam.Attachment1)
            end
            
            lastPart = part
        end
    end)
end

-- ========= REPLAY LIST MANAGEMENT =========
local function UpdateReplayList()
    CleanupConnections()
    
    SafeCall(function()
        for _, child in pairs(ReplayList:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
        
        local recordingNames = {}
        for name, _ in pairs(RecordedMovements) do
            table.insert(recordingNames, name)
        end
        table.sort(recordingNames)
        
        local yPos = 0
        for index, name in ipairs(recordingNames) do
            local rec = RecordedMovements[name]
            local item = Instance.new("Frame")
            item.Size = UDim2.new(1, -8, 0, 16)
            item.Position = UDim2.new(0, 4, 0, yPos)
            item.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            item.Parent = ReplayList
            
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 4)
            corner.Parent = item
            
            local nameBox = Instance.new("TextBox")
            nameBox.Size = UDim2.new(0, 120, 1, 0)
            nameBox.Position = UDim2.new(0, 4, 0, 0)
            nameBox.BackgroundTransparency = 1
            nameBox.Text = name
            nameBox.TextColor3 = Color3.new(1, 1, 1)
            nameBox.Font = Enum.Font.Gotham
            nameBox.TextSize = 8
            nameBox.PlaceholderText = "Rename..."
            nameBox.Parent = item
            
            local playBtn = Instance.new("TextButton")
            playBtn.Size = UDim2.fromOffset(30, 12)
            playBtn.Position = UDim2.new(1, -60, 0.5, -6)
            playBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
            playBtn.Text = "PLAY"
            playBtn.TextColor3 = Color3.new(1, 1, 1)
            playBtn.Font = Enum.Font.GothamBold
            playBtn.TextSize = 6
            playBtn.AutoButtonColor = false
            playBtn.Parent = item
            
            local playCorner = Instance.new("UICorner")
            playCorner.CornerRadius = UDim.new(0, 3)
            playCorner.Parent = playBtn
            
            local delBtn = Instance.new("TextButton")
            delBtn.Size = UDim2.fromOffset(30, 12)
            delBtn.Position = UDim2.new(1, -25, 0.5, -6)
            delBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
            delBtn.Text = "DEL"
            delBtn.TextColor3 = Color3.new(1, 1, 1)
            delBtn.Font = Enum.Font.GothamBold
            delBtn.TextSize = 6
            delBtn.AutoButtonColor = false
            delBtn.Parent = item
            
            local delCorner = Instance.new("UICorner")
            delCorner.CornerRadius = UDim.new(0, 3)
            delCorner.Parent = delBtn
            
            nameBox.FocusLost:Connect(function(enterPressed)
                SafeCall(function()
                    if enterPressed and nameBox.Text ~= "" and nameBox.Text ~= name then
                        RecordedMovements[nameBox.Text] = RecordedMovements[name]
                        RecordedMovements[name] = nil
                        UpdateReplayList()
                    else
                        nameBox.Text = name
                    end
                end)
            end)
            
            local playConn = playBtn.MouseButton1Click:Connect(function()
                SafeCall(function()
                    if not IsPlaying then
                        PlayRecording(name)
                    end
                end)
            end)
            AddConnection(playConn)
            
            local delConn = delBtn.MouseButton1Click:Connect(function()
                SafeCall(function()
                    RecordedMovements[name] = nil
                    UpdateReplayList()
                    UpdateStatus("Deleted: " .. name)
                end)
            end)
            AddConnection(delConn)
            
            yPos = yPos + 18
        end
        
        ReplayList.CanvasSize = UDim2.new(0, 0, 0, yPos)
    end)
end

-- ========= STUDIO UI UPDATE =========
local function UpdateStudioUI()
    SafeCall(function()
        local safeFrameInfo = LastSafeFrame > 0 and LastSafeFrame or #CurrentRecording.Frames
        FrameLabel.Text = string.format("Frames: %d / 30000 | Safe: %d", #CurrentRecording.Frames, safeFrameInfo)
    end)
end

-- ========= ENHANCED REVERSE PLAYBACK SYSTEM =========
local function StartReversePlayback()
    if IsReversing or not IsRecording then return end
    
    SafeCall(function()
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            StatusLabel.Text = "❌ Character not found!"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            return
        end
        
        if #CurrentRecording.Frames == 0 then
            StatusLabel.Text = "❌ No frames to reverse!"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            return
        end
        
        IsReversing = true
        IsTimelineMode = true
        FallCheckEnabled = false
        ReverseStartFrame = #CurrentRecording.Frames
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        
        if hum then
            hum.AutoRotate = false
            hum.PlatformStand = false
        end
        
        StatusLabel.Text = "⏪ Reversing playback..."
        StatusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
        
        local currentFrame = #CurrentRecording.Frames
        
        reverseConnection = RunService.Heartbeat:Connect(function()
            if not IsReversing or not IsRecording then
                if reverseConnection then
                    reverseConnection:Disconnect()
                    reverseConnection = nil
                end
                return
            end
            
            char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then
                IsReversing = false
                if reverseConnection then
                    reverseConnection:Disconnect()
                    reverseConnection = nil
                end
                return
            end
            
            hrp = char:FindFirstChild("HumanoidRootPart")
            hum = char:FindFirstChildOfClass("Humanoid")
            
            if not hrp or not hum then
                IsReversing = false
                if reverseConnection then
                    reverseConnection:Disconnect()
                    reverseConnection = nil
                end
                return
            end
            
            currentFrame = currentFrame - (REVERSE_FRAME_STEP * REVERSE_SPEED_MULTIPLIER)
            
            if currentFrame < 1 then
                currentFrame = 1
                IsReversing = false
                StatusLabel.Text = "⏹️ Reached start of recording"
                StatusLabel.TextColor3 = Color3.fromRGB(255, 150, 50)
                if reverseConnection then
                    reverseConnection:Disconnect()
                    reverseConnection = nil
                end
                return
            end
            
            local frame = CurrentRecording.Frames[math.floor(currentFrame)]
            if frame then
                SafeCall(function()
                    local targetCFrame = GetFrameCFrame(frame)
                    hrp.CFrame = targetCFrame
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    
                    if hum then
                        hum.WalkSpeed = 0
                        UniversalStateControl(hum, "Grounded")
                    end
                    
                    UpdateStudioUI()
                end)
            end
        end)
        
        AddConnection(reverseConnection)
    end)
end

local function StopReversePlayback()
    IsReversing = false
    
    SafeCall(function()
        if reverseConnection then
            reverseConnection:Disconnect()
            reverseConnection = nil
        end
        
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = 16
            end
        end
        
        StatusLabel.Text = "⏸️ Reverse stopped - Use RESUME to continue"
        StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
    end)
end

-- ========= ENHANCED FORWARD PLAYBACK SYSTEM =========
local function StartForwardPlayback()
    if IsForwarding or not IsRecording then return end
    
    SafeCall(function()
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            StatusLabel.Text = "❌ Character not found!"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            return
        end
        
        if #CurrentRecording.Frames == 0 then
            StatusLabel.Text = "❌ No frames to forward!"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            return
        end
        
        IsForwarding = true
        IsTimelineMode = true
        FallCheckEnabled = false
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        
        if hum then
            hum.AutoRotate = false
            hum.PlatformStand = false
        end
        
        StatusLabel.Text = "⏩ Forwarding playback..."
        StatusLabel.TextColor3 = Color3.fromRGB(200, 150, 100)
        
        local currentFrame = 1
        
        local currentPos = hrp.Position
        local nearestFrame, _ = FindNearestFrame(CurrentRecording.Frames, currentPos)
        currentFrame = nearestFrame
        
        forwardConnection = RunService.Heartbeat:Connect(function()
            if not IsForwarding or not IsRecording then
                if forwardConnection then
                    forwardConnection:Disconnect()
                    forwardConnection = nil
                end
                return
            end
            
            char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then
                IsForwarding = false
                if forwardConnection then
                    forwardConnection:Disconnect()
                    forwardConnection = nil
                end
                return
            end
            
            hrp = char:FindFirstChild("HumanoidRootPart")
            hum = char:FindFirstChildOfClass("Humanoid")
            
            if not hrp or not hum then
                IsForwarding = false
                if forwardConnection then
                    forwardConnection:Disconnect()
                    forwardConnection = nil
                end
                return
            end
            
            currentFrame = currentFrame + (FORWARD_FRAME_STEP * FORWARD_SPEED_MULTIPLIER)
            
            if currentFrame > #CurrentRecording.Frames then
                currentFrame = #CurrentRecording.Frames
                IsForwarding = false
                StatusLabel.Text = "⏹️ Reached end of recording"
                StatusLabel.TextColor3 = Color3.fromRGB(255, 150, 50)
                if forwardConnection then
                    forwardConnection:Disconnect()
                    forwardConnection = nil
                end
                return
            end
            
            local frame = CurrentRecording.Frames[math.floor(currentFrame)]
            if frame then
                SafeCall(function()
                    local targetCFrame = GetFrameCFrame(frame)
                    hrp.CFrame = targetCFrame
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    
                    if hum then
                        hum.WalkSpeed = 0
                        UniversalStateControl(hum, "Grounded")
                    end
                    
                    UpdateStudioUI()
                end)
            end
        end)
        
        AddConnection(forwardConnection)
    end)
end

local function StopForwardPlayback()
    IsForwarding = false
    
    SafeCall(function()
        if forwardConnection then
            forwardConnection:Disconnect()
            forwardConnection = nil
        end
        
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = 16
            end
        end
        
        StatusLabel.Text = "⏸️ Forward stopped - Use RESUME to continue"
        StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
    end)
end

-- ========= RECORDING STUDIO FUNCTIONS =========
local function StartStudioRecording()
    if IsRecording then return end
    
    SafeCall(function()
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            StatusLabel.Text = "❌ Character not found!"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            return
        end
        
        IsRecording = true
        IsFallDetected = false
        isCurrentlyFalling = false
        LastSafeFrame = 0
        LastSafePosition = nil
        LastSafeVelocity = nil
        TimelinePosition = 0
        IsTimelineMode = false
        FallCheckEnabled = true
        IsTransitionMode = false
        TransitionFrames = {}
        PreFallFrameCount = 0
        timelineGroundedStart = nil
        CurrentRecording = {Frames = {}, StartTime = tick(), Name = "Studio_" .. os.date("%H%M%S")}
        lastRecordTime = 0
        lastRecordPos = nil
        
        RecordBtn.Text = "⏹ STOP"
        RecordBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 60)
        StatusLabel.Text = "🎬 Recording... Move your character"
        StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
        
        recordConnection = RunService.Heartbeat:Connect(function()
            SafeCall(function()
                local char = player.Character
                if not char or not char:FindFirstChild("HumanoidRootPart") or #CurrentRecording.Frames >= MAX_FRAMES then
                    return
                end
                
                local hrp = char.HumanoidRootPart
                local hum = char:FindFirstChildOfClass("Humanoid")
                
                if IsTimelineMode then
                    local moveState = GetCurrentMoveState(hum, hrp)
                    if moveState == "Grounded" then
                        if not timelineGroundedStart then
                            timelineGroundedStart = tick()
                        elseif tick() - timelineGroundedStart > 2 then
                            IsTimelineMode = false
                            FallCheckEnabled = true
                            StatusLabel.Text = "✅ Auto-resumed recording"
                            StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
                            timelineGroundedStart = nil
                        end
                    else
                        timelineGroundedStart = nil
                    end
                    return
                end
                
                local moveState = GetCurrentMoveState(hum, hrp)
                
                if IsFallDetected and FallCheckEnabled then
                    IsTimelineMode = true
                    FallCheckEnabled = false
                    
                    DeleteFramesFromFall(LastSafeFrame)
                    
                    StatusLabel.Text = "⚠️ FALL DETECTED! Use MUNDUR/MAJU"
                    StatusLabel.TextColor3 = Color3.fromRGB(255, 150, 50)
                    IsFallDetected = false
                    return
                end
                
                if moveState == "Grounded" or moveState == "Running" then
                    LastSafeFrame = #CurrentRecording.Frames
                    LastSafePosition = hrp.Position
                    LastSafeVelocity = hrp.AssemblyLinearVelocity
                end
                
                local now = tick()
                if (now - lastRecordTime) < (1 / RECORDING_FPS) then return end
                
                local currentPos = hrp.Position
                local currentVelocity = hrp.AssemblyLinearVelocity
                
                if lastRecordPos and (currentPos - lastRecordPos).Magnitude < MIN_DISTANCE_THRESHOLD and moveState == "Grounded" then
                    lastRecordTime = now
                    return
                end
                
                local cf = hrp.CFrame
                table.insert(CurrentRecording.Frames, {
                    Position = {cf.Position.X, cf.Position.Y, cf.Position.Z},
                    LookVector = {cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z},
                    UpVector = {cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z},
                    Velocity = {currentVelocity.X, currentVelocity.Y, currentVelocity.Z},
                    MoveState = moveState,
                    WalkSpeed = hum and hum.WalkSpeed or 16,
                    Timestamp = now - CurrentRecording.StartTime
                })
                
                lastRecordTime = now
                lastRecordPos = currentPos
                
                UpdateStudioUI()
            end)
        end)
    end)
end

local function StopStudioRecording()
    IsRecording = false
    IsFallDetected = false
    isCurrentlyFalling = false
    IsTimelineMode = false
    FallCheckEnabled = true
    IsTransitionMode = false
    timelineGroundedStart = nil
    
    SafeCall(function()
        if recordConnection then
            recordConnection:Disconnect()
            recordConnection = nil
        end
        
        RecordBtn.Text = "● RECORD"
        RecordBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
        
        if #CurrentRecording.Frames > 0 then
            StatusLabel.Text = "✅ Recording stopped (" .. #CurrentRecording.Frames .. " frames)"
            StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
        else
            StatusLabel.Text = "Recording stopped (0 frames)"
            StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
        end
    end)
end

local function ResumeStudioRecording()
    if not IsRecording then
        StatusLabel.Text = "❌ Not recording!"
        return
    end
    
    SafeCall(function()
        if IsReversing then
            StopReversePlayback()
        end
        
        if IsForwarding then
            StopForwardPlayback()
        end
        
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            StatusLabel.Text = "❌ Character not found!"
            return
        end
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        
        if #CurrentRecording.Frames > 0 then
            local lastFrame = CurrentRecording.Frames[#CurrentRecording.Frames]
            local currentPos = hrp.Position
            local lastPos = GetFramePosition(lastFrame)
            
            if (currentPos - lastPos).Magnitude > 5 then
                CreateSeamlessTransition(lastFrame, currentPos)
                
                for _, transFrame in ipairs(TransitionFrames) do
                    table.insert(CurrentRecording.Frames, transFrame)
                end
                
                IsTransitionMode = false
                TransitionFrames = {}
                
                StatusLabel.Text = "✅ Seamless transition created"
                StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
            end
        end
        
        IsTimelineMode = false
        FallCheckEnabled = true
        IsFallDetected = false
        isCurrentlyFalling = false
        timelineGroundedStart = nil
        
        if hum then
            hum.WalkSpeed = 16
            hum.AutoRotate = true
        end
        
        StatusLabel.Text = "▶ Recording resumed from frame " .. #CurrentRecording.Frames
        StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
        
        UpdateStudioUI()
    end)
end

local function SaveStudioRecording()
    SafeCall(function()
        if #CurrentRecording.Frames == 0 then
            StatusLabel.Text = "❌ No frames to save!"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            return
        end
        
        if IsRecording then
            StopStudioRecording()
        end
        
        RecordedMovements[CurrentRecording.Name] = CurrentRecording.Frames
        UpdateReplayList()
        
        StatusLabel.Text = "💾 Saved: " .. CurrentRecording.Name
        StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
        
        UpdateStatus("Saved: " .. CurrentRecording.Name .. " (" .. #CurrentRecording.Frames .. " frames)")
        
        CurrentRecording = {Frames = {}, StartTime = 0, Name = "Studio_" .. os.date("%H%M%S")}
        TimelinePosition = 0
        IsTimelineMode = false
        timelineGroundedStart = nil
        LastSafeFrame = 0
        LastSafePosition = nil
        LastSafeVelocity = nil
        UpdateStudioUI()
        
        wait(1.5)
        RecordingStudio.Visible = false
        MainFrame.Visible = true
    end)
end

local function ClearStudioRecording()
    SafeCall(function()
        if IsRecording then
            StopStudioRecording()
        end
        
        CurrentRecording = {Frames = {}, StartTime = 0, Name = "Studio_" .. os.date("%H%M%S")}
        TimelinePosition = 0
        IsTimelineMode = false
        LastSafeFrame = 0
        LastSafePosition = nil
        LastSafeVelocity = nil
        IsTransitionMode = false
        TransitionFrames = {}
        timelineGroundedStart = nil
        
        UpdateStudioUI()
        StatusLabel.Text = "🗑️ Cleared - Ready to record"
        StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
    end)
end

-- ========= STUDIO BUTTON EVENTS =========
RecordBtn.MouseButton1Click:Connect(function()
    if IsRecording then
        StopStudioRecording()
    else
        StartStudioRecording()
    end
end)

ReverseBtn.MouseButton1Click:Connect(function()
    if IsReversing then
        StopReversePlayback()
    else
        if IsForwarding then
            StopForwardPlayback()
        end
        StartReversePlayback()
    end
end)

ForwardBtn.MouseButton1Click:Connect(function()
    if IsForwarding then
        StopForwardPlayback()
    else
        if IsReversing then
            StopReversePlayback()
        end
        StartForwardPlayback()
    end
end)

ResumeBtn.MouseButton1Click:Connect(ResumeStudioRecording)
SaveBtn.MouseButton1Click:Connect(SaveStudioRecording)
ClearBtn.MouseButton1Click:Connect(ClearStudioRecording)

CloseStudioBtn.MouseButton1Click:Connect(function()
    SafeCall(function()
        if IsRecording then
            StopStudioRecording()
        end
        if IsReversing then
            StopReversePlayback()
        end
        if IsForwarding then
            StopForwardPlayback()
        end
        RecordingStudio.Visible = false
        MainFrame.Visible = true
    end)
end)

-- ========= BYARUL PLAYBACK SYSTEM =========
function PlayRecordingWithByarulSystem(recording, startFrame)
    if not recording or #recording == 0 then return end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
    if not hum or not hrp then return end
    
    task.spawn(function()
        SafeCall(function()
            hum.AutoRotate = false
            hum.PlatformStand = false
            
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
            
            local currentFrame = startFrame or 1
            playbackStartTime = tick()
            totalPausedDuration = 0
            pauseStartTime = 0
            lastPlaybackState = nil
            
            lastPlaybackCFrame = hrp.CFrame
            lastPlaybackVelocity = Vector3.new(0, 0, 0)
            
            playbackConnection = RunService.Heartbeat:Connect(function(deltaTime)
                if not IsPlaying then
                    playbackConnection:Disconnect()
                    CompleteCharacterReset(char)
                    return
                end
                
                if IsPaused then
                    if pauseStartTime == 0 then
                        pauseStartTime = tick()
                        RestoreHumanoidState()
                    end
                    return
                else
                    if pauseStartTime > 0 then
                        totalPausedDuration = totalPausedDuration + (tick() - pauseStartTime)
                        pauseStartTime = 0
                        SaveHumanoidState()
                    end
                end
                
                char = player.Character
                if not char or not char:FindFirstChild("HumanoidRootPart") then
                    IsPlaying = false
                    playbackConnection:Disconnect()
                    return
                end
                
                hum = char:FindFirstChildOfClass("Humanoid")
                hrp = char:FindFirstChild("HumanoidRootPart")
                if not hum or not hrp then
                    IsPlaying = false
                    playbackConnection:Disconnect()
                    return
                end
                
                local currentTime = tick()
                local effectiveTime = (currentTime - playbackStartTime - totalPausedDuration) * CurrentSpeed
                
                local targetFrameIndex = 1
                for i = 1, #recording do
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
                    lastPlaybackState = nil
                    
                    local finalFrame = recording[#recording]
                    if finalFrame then
                        SafeCall(function()
                            hrp.CFrame = GetFrameCFrame(finalFrame)
                            ApplyUniversalVelocity(char, Vector3.new(0, 0, 0))
                        end)
                    end
                    
                    CompleteCharacterReset(char)
                    playbackConnection:Disconnect()
                    
                    if AutoLoop then
                        task.wait(0.5)
                        PlayRecording(currentRecordingName)
                    end
                    return
                end
                
                local targetFrame = recording[currentFrame]
                if not targetFrame then return end
                
                SafeCall(function()
                    local targetCFrame = GetFrameCFrame(targetFrame)
                    local targetVelocity = GetFrameVelocity(targetFrame) * CurrentSpeed
                    
                    local smoothCFrame = SmoothCFrameLerp(hrp.CFrame, targetCFrame, INTERPOLATION_ALPHA)
                    local smoothVelocity = lastPlaybackVelocity:Lerp(targetVelocity, INTERPOLATION_ALPHA)
                    
                    hrp.CFrame = smoothCFrame
                    ApplyUniversalVelocity(char, smoothVelocity)
                    
                    lastPlaybackCFrame = smoothCFrame
                    lastPlaybackVelocity = smoothVelocity
                    
                    hum.WalkSpeed = GetFrameWalkSpeed(targetFrame) * CurrentSpeed
                    
                    local charType = GetCharacterType()
                    if charType == "R15" then
                        if hum then
                            hum.PlatformStand = false
                            hum.AutoRotate = false
                        end
                    end
                    
                    local moveState = targetFrame.MoveState
                    
                    if moveState ~= lastPlaybackState then
                        lastPlaybackState = moveState
                        UniversalStateControl(hum, moveState)
                    end
                    
                    currentPlaybackFrame = currentFrame
                    
                    if FrameLabel then
                        FrameLabel.Text = string.format("Frame: %d/%d", currentPlaybackFrame, #recording)
                    end
                    
                    if AutoHeal and hum.Health < hum.MaxHealth * 0.5 then
                        hum.Health = hum.MaxHealth
                    end
                end)
            end)
            
            AddConnection(playbackConnection)
        end)
    end)
end

-- ========= PLAYBACK FUNCTIONS =========
function PlayRecording(name)
    if IsPlaying then return end
    
    SafeCall(function()
        local recording = name and RecordedMovements[name] or next(RecordedMovements) and (select(2, next(RecordedMovements)))
        if not recording then
            UpdateStatus("ERROR: No recordings!")
            return
        end
        
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            UpdateStatus("ERROR: Character not found!")
            return
        end
        
        currentRecordingName = name or next(RecordedMovements)
        
        IsPlaying = true
        IsPaused = false
        totalPausedDuration = 0
        pauseStartTime = 0
        lastMoveState = nil
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local nearestFrame, distance = FindNearestFrame(recording, hrp.Position)
        
        if distance <= ROUTE_PROXIMITY_THRESHOLD then
            currentPlaybackFrame = nearestFrame
            UpdateStatus(string.format("▶ Starting from Frame %d (nearby)", nearestFrame))
        else
            currentPlaybackFrame = 1
            
            local startPos = GetFramePosition(recording[1])
            if (hrp.Position - startPos).Magnitude > 50 then
                hrp.CFrame = CFrame.new(startPos)
                UpdateStatus("📍 Teleported to start")
            else
                UpdateStatus("▶ Starting playback")
            end
        end
        
        PlayRecordingWithByarulSystem(recording, currentPlaybackFrame)
    end)
end

function StopPlayback()
    if not IsPlaying then return end
    
    SafeCall(function()
        IsPlaying = false
        IsPaused = false
        lastMoveState = nil
        
        if playbackConnection then
            playbackConnection:Disconnect()
            playbackConnection = nil
        end
        
        local char = player.Character
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
            
            CompleteCharacterReset(char)
        end
        
        if ShowVisualization then
            ClearRouteVisualization()
        end
        
        UpdateStatus("■ Playback Stopped")
    end)
end

function PauseResumePlayback()
    if not IsPlaying then return end
    
    SafeCall(function()
        IsPaused = not IsPaused
        
        if IsPaused then
            UpdateStatus("⏸️ Playback Paused")
        else
            UpdateStatus("▶️ Playback Resumed")
        end
    end)
end

function UpdateStatus(msg)
    SafeCall(function()
        if Status then
            Status.Text = msg
        end
    end)
end

-- ========= SPEED CONTROL =========
local function UpdateSpeedDisplay()
    SafeCall(function()
        SpeedDisplay.Text = string.format("%.2fx", CurrentSpeed)
    end)
end

SpeedMinus.MouseButton1Click:Connect(function()
    SafeCall(function()
        if CurrentSpeed > 0.5 then
            CurrentSpeed = math.max(0.5, CurrentSpeed - 0.25)
            UpdateSpeedDisplay()
            UpdateStatus("Speed: " .. string.format("%.2f", CurrentSpeed) .. "x")
        end
    end)
end)

SpeedPlus.MouseButton1Click:Connect(function()
    SafeCall(function()
        if CurrentSpeed < 10 then
            CurrentSpeed = math.min(10, CurrentSpeed + 0.25)
            UpdateSpeedDisplay()
            UpdateStatus("Speed: " .. string.format("%.2f", CurrentSpeed) .. "x")
        end
    end)
end)

-- ========= FILE MANAGEMENT =========
local function SaveToFile()
    SafeCall(function()
        local filename = FileNameBox.Text
        if filename == "" then filename = "MyWalk" end
        filename = filename:gsub("[^%w%s%-_]", "") .. ".json"
        
        if not next(RecordedMovements) then
            UpdateStatus("ERROR: No recordings to save!")
            return
        end
        
        local data = {
            recordings = RecordedMovements,
            settings = {
                speed = CurrentSpeed,
                autoHeal = AutoHeal,
                autoLoop = AutoLoop,
                useMoveTo = UseMoveTo,
                showVisualization = ShowVisualization
            },
            version = "8.5"
        }
        writefile(filename, HttpService:JSONEncode(data))
        UpdateStatus("💾 Saved: " .. filename)
    end)
end

local function LoadFromFile()
    SafeCall(function()
        local filename = FileNameBox.Text
        if filename == "" then filename = "MyWalk" end
        filename = filename:gsub("[^%w%s%-_]", "") .. ".json"
        
        if isfile(filename) then
            local data = HttpService:JSONDecode(readfile(filename))
            RecordedMovements = data.recordings or {}
            CurrentSpeed = data.settings and data.settings.speed or 1
            AutoHeal = data.settings and data.settings.autoHeal or false
            AutoLoop = data.settings and data.settings.autoLoop or false
            UseMoveTo = data.settings and data.settings.useMoveTo or false
            ShowVisualization = data.settings and data.settings.showVisualization or false
            
            UpdateSpeedDisplay()
            SetMoveToState(UseMoveTo)
            SetVisualState(ShowVisualization)
            SetLoopState(AutoLoop)
            SetHealState(AutoHeal)
            UpdateReplayList()
            UpdateStatus("📂 Loaded: " .. filename)
        else
            UpdateStatus("❌ ERROR: File not found")
        end
    end)
end

-- ========= MAIN GUI BUTTON EVENTS =========
OpenStudioBtn.MouseButton1Click:Connect(function()
    SafeCall(function()
        MainFrame.Visible = false
        RecordingStudio.Visible = true
        StatusLabel.Text = "🎬 Recording Studio Ready"
        StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
    end)
end)

PauseBtn.MouseButton1Click:Connect(function()
    PauseResumePlayback()
end)

PlayBtn.MouseButton1Click:Connect(function()
    SafeCall(function()
        if IsPlaying and IsPaused then
            PauseResumePlayback()
        else
            PlayRecording()
        end
    end)
end)

StopBtn.MouseButton1Click:Connect(function()
    StopPlayback()
end)

MoveToBtn.MouseButton1Click:Connect(function()
    SafeCall(function()
        UseMoveTo = not UseMoveTo
        SetMoveToState(UseMoveTo)
        if UseMoveTo then
            UpdateStatus("🎯 Mode: MoveTo (Disabled)")
        else
            UpdateStatus("🚀 Mode: CFrame (Active)")
        end
    end)
end)

VisualBtn.MouseButton1Click:Connect(function()
    SafeCall(function()
        ShowVisualization = not ShowVisualization
        SetVisualState(ShowVisualization)
        if ShowVisualization then
            local recording = currentRecordingName and RecordedMovements[currentRecordingName]
            if not recording and next(RecordedMovements) then
                recording = select(2, next(RecordedMovements))
            end
            if recording then
                ShowRouteVisualization(recording)
            end
        else
            ClearRouteVisualization()
        end
        UpdateStatus("👁️ Visual: " .. (ShowVisualization and "ON" or "OFF"))
    end)
end)

LoopBtn.MouseButton1Click:Connect(function()
    SafeCall(function()
        AutoLoop = not AutoLoop
        SetLoopState(AutoLoop)
        UpdateStatus("🔄 Auto Loop: " .. (AutoLoop and "ON" or "OFF"))
    end)
end)

HealBtn.MouseButton1Click:Connect(function()
    SafeCall(function()
        AutoHeal = not AutoHeal
        SetHealState(AutoHeal)
        UpdateStatus("❤️ Auto Heal: " .. (AutoHeal and "ON" or "OFF"))
    end)
end)

SaveFileBtn.MouseButton1Click:Connect(SaveToFile)
LoadFileBtn.MouseButton1Click:Connect(LoadFromFile)

HideButton.MouseButton1Click:Connect(function()
    SafeCall(function()
        MainFrame.Visible = false
        MiniButton.Visible = true
    end)
end)

MiniButton.MouseButton1Click:Connect(function()
    SafeCall(function()
        MainFrame.Visible = true
        MiniButton.Visible = false
    end)
end)

CloseButton.MouseButton1Click:Connect(function()
    SafeCall(function()
        if IsRecording then StopStudioRecording() end
        if IsPlaying then StopPlayback() end
        if IsReversing then StopReversePlayback() end
        if IsForwarding then StopForwardPlayback() end
        CleanupConnections()
        ClearRouteVisualization()
        ScreenGui:Destroy()
    end)
end)

-- ========= HOTKEYS =========
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    SafeCall(function()
        if input.KeyCode == Enum.KeyCode.F9 then
            if RecordingStudio.Visible then
                if IsRecording then
                    StopStudioRecording()
                else
                    StartStudioRecording()
                end
            end
        elseif input.KeyCode == Enum.KeyCode.F10 then
            if IsPlaying then 
                StopPlayback() 
            else 
                PlayRecording() 
            end
        elseif input.KeyCode == Enum.KeyCode.F11 then
            MainFrame.Visible = not MainFrame.Visible
            MiniButton.Visible = not MainFrame.Visible
        elseif input.KeyCode == Enum.KeyCode.F7 then
            PauseResumePlayback()
        elseif input.KeyCode == Enum.KeyCode.F8 then
            if RecordingStudio.Visible then
                RecordingStudio.Visible = false
                MainFrame.Visible = true
            else
                MainFrame.Visible = false
                RecordingStudio.Visible = true
            end
        elseif input.KeyCode == Enum.KeyCode.F6 then
            if IsRecording and RecordingStudio.Visible then
                if IsReversing then
                    StopReversePlayback()
                else
                    StartReversePlayback()
                end
            end
        elseif input.KeyCode == Enum.KeyCode.F5 then
            if RecordingStudio.Visible and #CurrentRecording.Frames > 0 then
                SaveStudioRecording()
            end
        elseif input.KeyCode == Enum.KeyCode.F4 then
            if IsRecording and RecordingStudio.Visible then
                if IsForwarding then
                    StopForwardPlayback()
                else
                    StartForwardPlayback()
                end
            end
        elseif input.KeyCode == Enum.KeyCode.F3 then
            if IsRecording and RecordingStudio.Visible then
                ResumeStudioRecording()
            end
        end
    end)
end)

-- ========= AUTO HEAL SYSTEM =========
RunService.Heartbeat:Connect(function()
    SafeCall(function()
        if not AutoHeal then return end
        
        local char = player.Character
        if not char then return end
        
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        
        if hum.Health < hum.MaxHealth * 0.5 then
            hum.Health = hum.MaxHealth
        end
    end)
end)

-- ========= ANTI-STUCK DETECTION =========
local lastPosition = nil
local stuckTimer = 0
local STUCK_THRESHOLD = 3

RunService.Heartbeat:Connect(function()
    SafeCall(function()
        if not IsPlaying or IsPaused then 
            lastPosition = nil
            stuckTimer = 0
            return 
        end
        
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        
        local hrp = char.HumanoidRootPart
        local currentPos = hrp.Position
        
        if lastPosition then
            local distance = (currentPos - lastPosition).Magnitude
            
            if distance < 1 then
                stuckTimer = stuckTimer + task.wait()
                
                if stuckTimer >= STUCK_THRESHOLD then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then
                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                        
                        if currentPlaybackFrame < #RecordedMovements[currentRecordingName] then
                            currentPlaybackFrame = currentPlaybackFrame + 5
                        end
                    end
                    
                    stuckTimer = 0
                    UpdateStatus("⚠️ Stuck detected - attempting recovery")
                end
            else
                stuckTimer = 0
            end
        end
        
        lastPosition = currentPos
    end)
end)

-- ========= CHARACTER RESPAWN HANDLER =========
player.CharacterAdded:Connect(function(newChar)
    SafeCall(function()
        wait(1)
        
        if IsRecording then
            StopStudioRecording()
            UpdateStatus("⚠️ Recording stopped - Character respawned")
        end
        
        if IsPlaying then
            StopPlayback()
            UpdateStatus("⚠️ Playback stopped - Character respawned")
        end
        
        if IsReversing then
            StopReversePlayback()
        end
        
        if IsForwarding then
            StopForwardPlayback()
        end
        
        local charType = GetCharacterType()
        if charType == "R15" then
            local humanoid = newChar:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.PlatformStand = false
                humanoid.AutoRotate = false
            end
        end
    end)
end)

-- ========= PROGRESS BAR =========
local ProgressFrame = Instance.new("Frame")
ProgressFrame.Size = UDim2.new(1, -16, 0, 6)
ProgressFrame.Position = UDim2.new(0, 8, 1, -30)
ProgressFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ProgressFrame.BorderSizePixel = 0
ProgressFrame.Visible = false
ProgressFrame.Parent = MainFrame

local ProgressCorner = Instance.new("UICorner")
ProgressCorner.CornerRadius = UDim.new(0, 3)
ProgressCorner.Parent = ProgressFrame

local ProgressBar = Instance.new("Frame")
ProgressBar.Size = UDim2.new(0, 0, 1, 0)
ProgressBar.BackgroundColor3 = Color3.fromRGB(100, 255, 150)
ProgressBar.BorderSizePixel = 0
ProgressBar.Parent = ProgressFrame

local BarCorner = Instance.new("UICorner")
BarCorner.CornerRadius = UDim.new(0, 3)
BarCorner.Parent = ProgressBar

RunService.Heartbeat:Connect(function()
    SafeCall(function()
        if IsPlaying and currentRecordingName and RecordedMovements[currentRecordingName] then
            ProgressFrame.Visible = true
            local progress = currentPlaybackFrame / #RecordedMovements[currentRecordingName]
            ProgressBar.Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0)
        else
            ProgressFrame.Visible = false
        end
    end)
end)

-- ========= INITIALIZATION =========
SafeCall(function()
    UpdateReplayList()
    UpdateStatus("✅ Auto Walk Pro v8.5 - Enhanced Reverse Ready!")
    UpdateSpeedDisplay()
end)

-- ========= R15 INITIALIZATION =========
task.spawn(function()
    task.wait(1)
    local char = player.Character
    if char then
        local charType = GetCharacterType()
        if charType == "R15" then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.PlatformStand = false
                humanoid.AutoRotate = false
            end
        end
    end
end)

-- ========= FINAL CONFIRMATION =========
task.wait(1)
SafeCall(function()
    UpdateStatus("✅ All Systems Operational - Reverse System Active!")
    print("=".rep(60))
    print("AUTO WALK PRO v8.5 - ENHANCED REVERSE SYSTEM")
    print("=".rep(60))
    print("✅ Recording Studio: Enhanced with Reverse/Forward")
    print("✅ Fall Detection: Auto-pause with frame deletion")
    print("✅ Seamless Transition: Smooth resume after fall")
    print("✅ Reverse Playback: Navigate backwards through recording")
    print("✅ Forward Playback: Navigate forwards through recording")
    print("✅ Universal Character: Full R6/R15 support")
    print("=".rep(60))
    print("HOTKEYS:")
    print("F3  - Resume recording after reverse/forward")
    print("F4  - Toggle Forward playback (in Recording Studio)")
    print("F5  - Save current recording")
    print("F6  - Toggle Reverse playback (in Recording Studio)")
    print("F7  - Pause/Resume playback")
    print("F8  - Toggle Studio/Main GUI")
    print("F9  - Start/Stop recording")
    print("F10 - Play/Stop playback")
    print("F11 - Show/Hide GUI")
    print("=".rep(60))
    print("STUDIO CONTROLS:")
    print("⏪ MUNDUR  - Reverse through recording (deletes fall frames)")
    print("⏩ MAJU    - Forward through recording")
    print("▶ RESUME  - Continue recording with seamless transition")
    print("💾 SAVE   - Save recording to list")
    print("🗑️ CLEAR  - Clear current recording")
    print("=".rep(60))
    print("FEATURES:")
    print("• Auto Fall Detection - Detects and handles falls")
    print("• Frame Deletion - Removes frames before fall")
    print("• Seamless Transition - Smooth connection after fall")
    print("• Reverse Navigation - Go back to find safe position")
    print("• Forward Navigation - Skip ahead in recording")
    print("• Auto-Resume - Continues recording smoothly")
    print("=".rep(60))
    print("STATUS: Ready to use!")
    print("=".rep(60))
end)

-- ========= VISUAL FEEDBACK FOR REVERSE/FORWARD =========
local ReverseIndicator = Instance.new("Frame")
ReverseIndicator.Size = UDim2.fromOffset(60, 20)
ReverseIndicator.Position = UDim2.fromOffset(5, 198)
ReverseIndicator.BackgroundColor3 = Color3.fromRGB(80, 120, 200)
ReverseIndicator.BorderSizePixel = 0
ReverseIndicator.Visible = false
ReverseIndicator.Parent = StudioContent

local ReverseCorner = Instance.new("UICorner")
ReverseCorner.CornerRadius = UDim.new(0, 5)
ReverseCorner.Parent = ReverseIndicator

local ReverseText = Instance.new("TextLabel")
ReverseText.Size = UDim2.new(1, 0, 1, 0)
ReverseText.BackgroundTransparency = 1
ReverseText.Text = "⏪ REV"
ReverseText.TextColor3 = Color3.new(1, 1, 1)
ReverseText.Font = Enum.Font.GothamBold
ReverseText.TextSize = 9
ReverseText.Parent = ReverseIndicator

local ForwardIndicator = Instance.new("Frame")
ForwardIndicator.Size = UDim2.fromOffset(60, 20)
ForwardIndicator.Position = UDim2.fromOffset(70, 198)
ForwardIndicator.BackgroundColor3 = Color3.fromRGB(200, 120, 80)
ForwardIndicator.BorderSizePixel = 0
ForwardIndicator.Visible = false
ForwardIndicator.Parent = StudioContent

local ForwardCorner = Instance.new("UICorner")
ForwardCorner.CornerRadius = UDim.new(0, 5)
ForwardCorner.Parent = ForwardIndicator

local ForwardText = Instance.new("TextLabel")
ForwardText.Size = UDim2.new(1, 0, 1, 0)
ForwardText.BackgroundTransparency = 1
ForwardText.Text = "⏩ FWD"
ForwardText.TextColor3 = Color3.new(1, 1, 1)
ForwardText.Font = Enum.Font.GothamBold
ForwardText.TextSize = 9
ForwardText.Parent = ForwardIndicator

local TimelineModeIndicator = Instance.new("Frame")
TimelineModeIndicator.Size = UDim2.fromOffset(80, 20)
TimelineModeIndicator.Position = UDim2.fromOffset(135, 198)
TimelineModeIndicator.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
TimelineModeIndicator.BorderSizePixel = 0
TimelineModeIndicator.Visible = false
TimelineModeIndicator.Parent = StudioContent

local TimelineCorner = Instance.new("UICorner")
TimelineCorner.CornerRadius = UDim.new(0, 5)
TimelineCorner.Parent = TimelineModeIndicator

local TimelineText = Instance.new("TextLabel")
TimelineText.Size = UDim2.new(1, 0, 1, 0)
TimelineText.BackgroundTransparency = 1
TimelineText.Text = "⚠️ PAUSED"
TimelineText.TextColor3 = Color3.new(1, 1, 1)
TimelineText.Font = Enum.Font.GothamBold
TimelineText.TextSize = 8
TimelineText.Parent = TimelineModeIndicator

-- ========= INDICATOR UPDATE LOOP =========
RunService.Heartbeat:Connect(function()
    SafeCall(function()
        if RecordingStudio.Visible then
            ReverseIndicator.Visible = IsReversing
            ForwardIndicator.Visible = IsForwarding
            TimelineModeIndicator.Visible = IsTimelineMode and not IsReversing and not IsForwarding
            
            if IsReversing then
                local pulse = math.abs(math.sin(tick() * 3))
                ReverseIndicator.BackgroundColor3 = Color3.fromRGB(
                    80 + pulse * 40,
                    120 + pulse * 40,
                    200 + pulse * 55
                )
            end
            
            if IsForwarding then
                local pulse = math.abs(math.sin(tick() * 3))
                ForwardIndicator.BackgroundColor3 = Color3.fromRGB(
                    200 + pulse * 55,
                    120 + pulse * 40,
                    80 + pulse * 40
                )
            end
            
            if IsTimelinMode and not IsReversing and not IsForwarding then
                local pulse = math.abs(math.sin(tick() * 2))
                TimelineModeIndicator.BackgroundColor3 = Color3.fromRGB(
                    255,
                    150 + pulse * 50,
                    50 + pulse * 30
                )
            end
        end
    end)
end)

-- ========= ENHANCED STUDIO INFO DISPLAY =========
local InfoFrame = Instance.new("Frame")
InfoFrame.Size = UDim2.fromOffset(214, 50)
InfoFrame.Position = UDim2.fromOffset(5, 220)
InfoFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
InfoFrame.BorderSizePixel = 0
InfoFrame.Visible = true
InfoFrame.Parent = RecordingStudio

local InfoCorner = Instance.new("UICorner")
InfoCorner.CornerRadius = UDim.new(0, 6)
InfoCorner.Parent = InfoFrame

local InfoStroke = Instance.new("UIStroke")
InfoStroke.Color = Color3.fromRGB(60, 60, 70)
InfoStroke.Thickness = 1
InfoStroke.Parent = InfoFrame

local InfoTitle = Instance.new("TextLabel")
InfoTitle.Size = UDim2.new(1, -8, 0, 12)
InfoTitle.Position = UDim2.fromOffset(4, 2)
InfoTitle.BackgroundTransparency = 1
InfoTitle.Text = "📊 RECORDING INFO"
InfoTitle.TextColor3 = Color3.fromRGB(150, 200, 255)
InfoTitle.Font = Enum.Font.GothamBold
InfoTitle.TextSize = 8
InfoTitle.TextXAlignment = Enum.TextXAlignment.Left
InfoTitle.Parent = InfoFrame

local InfoDuration = Instance.new("TextLabel")
InfoDuration.Size = UDim2.new(1, -8, 0, 10)
InfoDuration.Position = UDim2.fromOffset(4, 16)
InfoDuration.BackgroundTransparency = 1
InfoDuration.Text = "Duration: 0.00s"
InfoDuration.TextColor3 = Color3.fromRGB(200, 200, 220)
InfoDuration.Font = Enum.Font.Gotham
InfoDuration.TextSize = 7
InfoDuration.TextXAlignment = Enum.TextXAlignment.Left
InfoDuration.Parent = InfoFrame

local InfoDistance = Instance.new("TextLabel")
InfoDistance.Size = UDim2.new(1, -8, 0, 10)
InfoDistance.Position = UDim2.fromOffset(4, 28)
InfoDistance.BackgroundTransparency = 1
InfoDistance.Text = "Distance: 0.00 studs"
InfoDistance.TextColor3 = Color3.fromRGB(200, 200, 220)
InfoDistance.Font = Enum.Font.Gotham
InfoDistance.TextSize = 7
InfoDistance.TextXAlignment = Enum.TextXAlignment.Left
InfoDistance.Parent = InfoFrame

local InfoFPS = Instance.new("TextLabel")
InfoFPS.Size = UDim2.new(1, -8, 0, 10)
InfoFPS.Position = UDim2.fromOffset(4, 40)
InfoFPS.BackgroundTransparency = 1
InfoFPS.Text = "FPS: 60 | Quality: Perfect"
InfoFPS.TextColor3 = Color3.fromRGB(100, 255, 150)
InfoFPS.Font = Enum.Font.Gotham
InfoFPS.TextSize = 7
InfoFPS.TextXAlignment = Enum.TextXAlignment.Left
InfoFPS.Parent = InfoFrame

-- Adjust Studio size to fit info panel
RecordingStudio.Size = UDim2.fromOffset(230, 280)
RecordingStudio.Position = UDim2.new(0.5, -115, 0.5, -140)
StudioContent.Size = UDim2.new(1, -16, 1, -36)

-- ========= INFO UPDATE SYSTEM =========
local totalDistance = 0
local lastInfoUpdatePos = nil

RunService.Heartbeat:Connect(function()
    SafeCall(function()
        if not RecordingStudio.Visible or not IsRecording then 
            totalDistance = 0
            lastInfoUpdatePos = nil
            return 
        end
        
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        
        if lastInfoUpdatePos then
            local dist = (hrp.Position - lastInfoUpdatePos).Magnitude
            totalDistance = totalDistance + dist
        end
        lastInfoUpdatePos = hrp.Position
        
        local duration = 0
        if #CurrentRecording.Frames > 0 then
            local lastFrame = CurrentRecording.Frames[#CurrentRecording.Frames]
            duration = GetFrameTimestamp(lastFrame)
        end
        
        InfoDuration.Text = string.format("Duration: %.2fs", duration)
        InfoDistance.Text = string.format("Distance: %.2f studs", totalDistance)
        
        local quality = "Perfect"
        local qualityColor = Color3.fromRGB(100, 255, 150)
        
        if #CurrentRecording.Frames > 25000 then
            quality = "Warning"
            qualityColor = Color3.fromRGB(255, 200, 100)
        elseif #CurrentRecording.Frames >= 30000 then
            quality = "FULL!"
            qualityColor = Color3.fromRGB(255, 100, 100)
        end
        
        InfoFPS.Text = string.format("FPS: %d | Quality: %s", RECORDING_FPS, quality)
        InfoFPS.TextColor3 = qualityColor
    end)
end)

-- ========= SEAMLESS TRANSITION VISUAL FEEDBACK =========
local function ShowTransitionEffect()
    SafeCall(function()
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        
        local effect = Instance.new("Part")
        effect.Size = Vector3.new(4, 0.2, 4)
        effect.Position = hrp.Position
        effect.Anchored = true
        effect.CanCollide = false
        effect.Transparency = 0.5
        effect.Color = Color3.fromRGB(100, 255, 150)
        effect.Material = Enum.Material.Neon
        effect.Parent = workspace
        
        local tween = TweenService:Create(effect, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = Vector3.new(8, 0.1, 8),
            Transparency = 1
        })
        
        tween:Play()
        
        task.delay(1, function()
            if effect and effect.Parent then
                effect:Destroy()
            end
        end)
    end)
end

-- ========= ENHANCED RESUME WITH TRANSITION EFFECT =========
local originalResumeFunction = ResumeStudioRecording

ResumeStudioRecording = function()
    originalResumeFunction()
    ShowTransitionEffect()
end

-- ========= FALL DETECTION VISUAL WARNING =========
local function ShowFallWarning()
    SafeCall(function()
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        
        for i = 1, 3 do
            local warning = Instance.new("Part")
            warning.Size = Vector3.new(1, 1, 1)
            warning.Position = hrp.Position + Vector3.new(0, i * 2, 0)
            warning.Anchored = true
            warning.CanCollide = false
            warning.Transparency = 0.3
            warning.Color = Color3.fromRGB(255, 100, 100)
            warning.Material = Enum.Material.Neon
            warning.Shape = Enum.PartType.Ball
            warning.Parent = workspace
            
            local tween = TweenService:Create(warning, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = warning.Position + Vector3.new(0, 5, 0),
                Transparency = 1,
                Size = Vector3.new(0.2, 0.2, 0.2)
            })
            
            tween:Play()
            
            task.delay(0.8, function()
                if warning and warning.Parent then
                    warning:Destroy()
                end
            end)
        end
    end)
end

-- ========= ENHANCED FALL DETECTION WITH VISUAL =========
local originalFallDetection = GetCurrentMoveState

GetCurrentMoveState = function(hum, hrp)
    local state = originalFallDetection(hum, hrp)
    
    if state == "Falling" and IsFallDetected and not isCurrentlyFalling then
        ShowFallWarning()
    end
    
    return state
end

-- ========= SAFE POSITION MARKER =========
local safePositionMarker = nil

local function ShowSafePositionMarker()
    SafeCall(function()
        if safePositionMarker then
            safePositionMarker:Destroy()
            safePositionMarker = nil
        end
        
        if not LastSafePosition then return end
        
        local marker = Instance.new("Part")
        marker.Size = Vector3.new(2, 0.5, 2)
        marker.Position = LastSafePosition + Vector3.new(0, -2, 0)
        marker.Anchored = true
        marker.CanCollide = false
        marker.Transparency = 0.6
        marker.Color = Color3.fromRGB(100, 255, 150)
        marker.Material = Enum.Material.Neon
        marker.Parent = workspace
        
        local rotation = 0
        local rotateConn = RunService.Heartbeat:Connect(function()
            if marker and marker.Parent then
                rotation = rotation + 2
                marker.Orientation = Vector3.new(0, rotation, 0)
            else
                if rotateConn then
                    rotateConn:Disconnect()
                end
            end
        end)
        
        safePositionMarker = marker
    end)
end

-- ========= UPDATE SAFE MARKER ON REVERSE =========
local originalStopReverse = StopReversePlayback

StopReversePlayback = function()
    originalStopReverse()
    ShowSafePositionMarker()
end

-- ========= CLEANUP SAFE MARKER ON RESUME =========
local originalResumeCleanup = ResumeStudioRecording

ResumeStudioRecording = function()
    SafeCall(function()
        if safePositionMarker then
            local tween = TweenService:Create(safePositionMarker, TweenInfo.new(0.5), {
                Transparency = 1,
                Size = Vector3.new(4, 1, 4)
            })
            tween:Play()
            
            task.delay(0.5, function()
                if safePositionMarker and safePositionMarker.Parent then
                    safePositionMarker:Destroy()
                    safePositionMarker = nil
                end
            end)
        end
    end)
    
    originalResumeCleanup()
end

-- ========= NOTIFICATION SYSTEM =========
local NotificationFrame = Instance.new("Frame")
NotificationFrame.Size = UDim2.fromOffset(200, 40)
NotificationFrame.Position = UDim2.new(0.5, -100, 0, -50)
NotificationFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
NotificationFrame.BorderSizePixel = 0
NotificationFrame.Visible = false
NotificationFrame.Parent = ScreenGui

local NotifCorner = Instance.new("UICorner")
NotifCorner.CornerRadius = UDim.new(0, 8)
NotifCorner.Parent = NotificationFrame

local NotifStroke = Instance.new("UIStroke")
NotifStroke.Color = Color3.fromRGB(100, 255, 150)
NotifStroke.Thickness = 2
NotifStroke.Parent = NotificationFrame

local NotifText = Instance.new("TextLabel")
NotifText.Size = UDim2.new(1, -16, 1, 0)
NotifText.Position = UDim2.fromOffset(8, 0)
NotifText.BackgroundTransparency = 1
NotifText.Text = ""
NotifText.TextColor3 = Color3.fromRGB(100, 255, 150)
NotifText.Font = Enum.Font.GothamBold
NotifText.TextSize = 10
NotifText.TextWrapped = true
NotifText.Parent = NotificationFrame

local function ShowNotification(message, color, duration)
    SafeCall(function()
        NotifText.Text = message
        NotifStroke.Color = color or Color3.fromRGB(100, 255, 150)
        NotifText.TextColor3 = color or Color3.fromRGB(100, 255, 150)
        
        NotificationFrame.Position = UDim2.new(0.5, -100, 0, -50)
        NotificationFrame.Visible = true
        
        local slideIn = TweenService:Create(NotificationFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, -100, 0, 20)
        })
        slideIn:Play()
        
        task.delay(duration or 3, function()
            local slideOut = TweenService:Create(NotificationFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, -100, 0, -50)
            })
            slideOut:Play()
            
            task.delay(0.3, function()
                NotificationFrame.Visible = false
            end)
        end)
    end)
end

-- ========= ENHANCED STATUS UPDATES WITH NOTIFICATIONS =========
local originalUpdateStatus = UpdateStatus

UpdateStatus = function(msg)
    originalUpdateStatus(msg)
    
    if msg:find("ERROR") or msg:find("❌") then
        ShowNotification(msg, Color3.fromRGB(255, 100, 100), 2)
    elseif msg:find("✅") or msg:find("Saved") then
        ShowNotification(msg, Color3.fromRGB(100, 255, 150), 2)
    elseif msg:find("⚠️") or msg:find("FALL") then
        ShowNotification(msg, Color3.fromRGB(255, 150, 50), 3)
    end
end

-- ========= FINAL STATUS UPDATE =========
task.wait(0.5)
SafeCall(function()
    ShowNotification("✅ AUTO WALK PRO v8.5 Ready!", Color3.fromRGB(100, 255, 150), 3)
    UpdateStatus("✅ Enhanced Reverse System - All Systems Go!")
end)

-- ========= END OF SCRIPT =========
print("✅ Auto Walk Pro v8.5 - Enhanced Reverse System Loaded Successfully!")
print("📌 Created by ByaruL System Integration")
print("🎬 Recording Studio with Advanced Timeline Control")
print("⏪ Reverse/Forward Navigation with Fall Recovery")
print("🔄 Seamless Transition System Active")
print("=".rep(60))