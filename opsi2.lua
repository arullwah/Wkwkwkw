-- ========= AUTO WALK PRO v8.7 - SMOOTH RECORDING SYSTEM =========
-- Enhanced Recording + Smooth Reverse/Forward + Universal Character Support

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

-- ========= SMOOTH REVERSE/FORWARD CONFIG =========
local REVERSE_SPEED_MULTIPLIER = 1.0
local FORWARD_SPEED_MULTIPLIER = 1.0
local REVERSE_FRAME_STEP = 1
local FORWARD_FRAME_STEP = 1
local TIMELINE_STEP_SECONDS = 0.5

-- ========= STABILITY CONFIG =========
local INTERPOLATION_ENABLED = true
local INTERPOLATION_ALPHA = 0.45
local MIN_INTERPOLATION_DISTANCE = 0.3

-- ========= UNIVERSAL CHARACTER SUPPORT =========
local UNIVERSAL_MODE = true

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
local AutoLoop = false
local recordConnection = nil
local playbackConnection = nil
local lastRecordTime = 0
local lastRecordPos = nil
local ShowVisualization = false
local currentRecordingName = nil
local currentPlaybackFrame = 1
local playbackStartTime = 0
local totalPausedDuration = 0
local pauseStartTime = 0
local lastPlaybackState = nil

-- ========= REAL-TIME FALL DETECTION VARIABLES =========
local lastStablePosition = nil
local fallSequence = {}
local consecutiveFallFrames = 0

-- ========= TIMELINE NAVIGATION VARIABLES =========
local TimelinePosition = 0
local IsTimelineMode = false
local reverseConnection = nil
local forwardConnection = nil

-- ========= REAL-TIME PLAYBACK VARIABLES =========
local lastPlaybackCFrame = nil
local lastPlaybackVelocity = Vector3.new(0, 0, 0)
local prePauseHumanoidState = nil
local prePauseWalkSpeed = 16
local prePauseAutoRotate = true
local prePauseJumpPower = 50

-- ========= EVENT CLEANUP =========
local eventConnections = {}

local function AddConnection(conn)
    table.insert(eventConnections, conn)
end

local function CleanupConnections()
    for _, conn in pairs(eventConnections) do
        if conn and conn.Connected then
            conn:Disconnect()
        end
    end
    eventConnections = {}
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
    
    return "Unknown"
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
        pcall(function()
            hrp.AssemblyLinearVelocity = velocity
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end)
        return true
    end
end

-- ========= CHARACTER RESET =========
local function CompleteCharacterReset(char)
    pcall(function()
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
        humanoid:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
        
        local bodyVelocity = hrp:FindFirstChild("AutoWalkBodyVelocity")
        if bodyVelocity then
            bodyVelocity:Destroy()
        end
    end)
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

-- ========= FRAME DATA FUNCTIONS =========
local function GetFramePosition(frame)
    return Vector3.new(frame.Position[1], frame.Position[2], frame.Position[3])
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

-- ========= REAL-TIME FALL DETECTION =========
local function IsPositionStable(currentPos, previousPos)
    if not previousPos then return true end
    local verticalChange = math.abs(currentPos.Y - previousPos.Y)
    return verticalChange < 2.0  -- Threshold untuk stable movement
end

local function ProcessRealTimeFallDetection()
    if not IsRecording or #CurrentRecording.Frames < 2 then return end
    
    local currentFrameIndex = #CurrentRecording.Frames
    local currentFrame = CurrentRecording.Frames[currentFrameIndex]
    local currentPos = GetFramePosition(currentFrame)
    
    -- Initialize last stable position
    if not lastStablePosition then
        lastStablePosition = currentPos
        return
    end
    
    -- Check vertical velocity for fall detection
    local velocity = GetFrameVelocity(currentFrame)
    local verticalVelocity = math.abs(velocity.Y)
    
    -- Check if current position is stable
    if IsPositionStable(currentPos, lastStablePosition) and verticalVelocity < 15 then
        -- Position is stable, update last stable position
        lastStablePosition = currentPos
        consecutiveFallFrames = 0
    else
        -- Position unstable, potentially falling
        consecutiveFallFrames = consecutiveFallFrames + 1
        
        -- If fall sequence is significant, mark frames for cleanup
        if consecutiveFallFrames > 8 then  -- 8 frames of falling
            -- Mark these frames as fall frames
            for i = math.max(1, currentFrameIndex - consecutiveFallFrames), currentFrameIndex do
                if CurrentRecording.Frames[i] then
                    CurrentRecording.Frames[i].IsFallFrame = true
                end
            end
        end
    end
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

-- ========= FIND NEAREST STABLE FRAME =========
local function FindNearestStableFrame(recording, position)
    if not recording or #recording == 0 then return 1 end
    
    local nearestFrame = 1
    local nearestDistance = math.huge
    
    for i = 1, #recording do
        local frame = recording[i]
        local framePos = GetFramePosition(frame)
        local distance = (framePos - position).Magnitude
        
        -- Skip fall frames when looking for stable frame
        if not frame.IsFallFrame and distance < nearestDistance then
            nearestDistance = distance
            nearestFrame = i
        end
    end
    
    return nearestFrame
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

-- ========= ENHANCED UNIVERSAL STATE CONTROL =========
local function UniversalStateControl(humanoid, targetState, frameData)
    if not humanoid then return end
    
    pcall(function()
        if targetState == "Climbing" then
            humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
            -- Add slight delay for climb animation to trigger
            if frameData and frameData.Velocity then
                local vel = GetFrameVelocity(frameData)
                if vel.Y > 5 then  -- Moving upward while climbing
                    humanoid.Jump = true
                end
            end
        elseif targetState == "Jumping" then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            -- Force jump for better animation
            humanoid.Jump = true
        elseif targetState == "Swimming" then
            humanoid:ChangeState(Enum.HumanoidStateType.Swimming)
        elseif targetState == "Falling" then
            humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        elseif targetState == "Running" then
            humanoid:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
        else
            humanoid:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
        end
    end)
end

-- ========= SEAMLESS TRANSITION CREATOR =========
local function CreateSeamlessTransition(fromFrame, toPosition)
    local TransitionFrames = {}
    
    if not fromFrame then return TransitionFrames end
    
    local startPos = GetFramePosition(fromFrame)
    local distance = (toPosition - startPos).Magnitude
    local transitionSteps = math.max(3, math.floor(distance / 1.5))
    
    for i = 1, transitionSteps do
        local alpha = i / transitionSteps
        local interpPos = startPos:Lerp(toPosition, alpha)
        
        table.insert(TransitionFrames, {
            Position = {interpPos.X, interpPos.Y, interpPos.Z},
            LookVector = fromFrame.LookVector,
            UpVector = fromFrame.UpVector,
            Velocity = {0, 0, 0},
            MoveState = "Running",
            WalkSpeed = fromFrame.WalkSpeed or 16,
            Timestamp = fromFrame.Timestamp + (i * 0.016)
        })
    end
    
    return TransitionFrames
end

-- ========= FALL FRAME CLEANUP =========
local function DetectAndRemoveFallFrames(recording)
    if not recording or #recording < 10 then return recording end
    
    local cleanedFrames = {}
    local fallStartIndex = 0
    local inFallSequence = false
    
    for i = 1, #recording do
        local frame = recording[i]
        
        if frame.IsFallFrame then
            if not inFallSequence then
                inFallSequence = true
                fallStartIndex = math.max(1, i - 1)
            end
        else
            if inFallSequence then
                inFallSequence = false
                local fallEndIndex = i
                local fallFrameCount = fallEndIndex - fallStartIndex
                
                if fallFrameCount > 5 then
                    -- Keep frames before fall
                    for j = 1, fallStartIndex do
                        if recording[j] and not recording[j].IsFallFrame then
                            table.insert(cleanedFrames, recording[j])
                        end
                    end
                    
                    -- Create transition
                    local preFallFrame = recording[fallStartIndex]
                    local postFallFrame = recording[fallEndIndex]
                    
                    if preFallFrame and postFallFrame then
                        local startPos = GetFramePosition(preFallFrame)
                        local endPos = GetFramePosition(postFallFrame)
                        
                        if (endPos - startPos).Magnitude < 50 then
                            local transitionFrames = CreateSeamlessTransition(preFallFrame, endPos)
                            for _, transFrame in ipairs(transitionFrames) do
                                table.insert(cleanedFrames, transFrame)
                            end
                        else
                            table.insert(cleanedFrames, postFallFrame)
                        end
                    end
                    
                    -- Skip the fall frames
                    i = fallEndIndex
                else
                    -- Short fall, keep the frames
                    for j = fallStartIndex, fallEndIndex do
                        if recording[j] then
                            recording[j].IsFallFrame = nil
                            table.insert(cleanedFrames, recording[j])
                        end
                    end
                end
            else
                table.insert(cleanedFrames, frame)
            end
        end
    end
    
    -- Handle case where fall sequence continues to end
    if inFallSequence and #cleanedFrames > 0 then
        local lastGoodFrame = cleanedFrames[#cleanedFrames]
        local transitionFrames = CreateSeamlessTransition(lastGoodFrame, GetFramePosition(recording[#recording]))
        for _, transFrame in ipairs(transitionFrames) do
            table.insert(cleanedFrames, transFrame)
        end
    end
    
    return #cleanedFrames > 0 and cleanedFrames or recording
end

-- ========= GUI SETUP =========
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoWalkProV87"
ScreenGui.ResetOnSpawn = false

pcall(function()
    if player:FindFirstChild("PlayerGui") then
        ScreenGui.Parent = player.PlayerGui
    else
        wait(2)
        ScreenGui.Parent = player:WaitForChild("PlayerGui")
    end
end)

-- ========= SIMPLE RECORDING STUDIO GUI =========
local RecordingStudio = Instance.new("Frame")
RecordingStudio.Size = UDim2.fromOffset(180, 200)
RecordingStudio.Position = UDim2.new(0.5, -90, 0.5, -100)
RecordingStudio.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
RecordingStudio.BorderSizePixel = 0
RecordingStudio.Active = true
RecordingStudio.Draggable = true
RecordingStudio.Visible = false
RecordingStudio.Parent = ScreenGui

local StudioCorner = Instance.new("UICorner")
StudioCorner.CornerRadius = UDim.new(0, 8)
StudioCorner.Parent = RecordingStudio

local StudioStroke = Instance.new("UIStroke")
StudioStroke.Color = Color3.fromRGB(100, 150, 255)
StudioStroke.Thickness = 2
StudioStroke.Parent = RecordingStudio

-- Studio Header dengan Close Button
local StudioHeader = Instance.new("Frame")
StudioHeader.Size = UDim2.new(1, 0, 0, 24)
StudioHeader.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
StudioHeader.BorderSizePixel = 0
StudioHeader.Parent = RecordingStudio

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 8)
HeaderCorner.Parent = StudioHeader

local CloseStudioBtn = Instance.new("TextButton")
CloseStudioBtn.Size = UDim2.fromOffset(20, 20)
CloseStudioBtn.Position = UDim2.new(1, -25, 0.5, -10)
CloseStudioBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
CloseStudioBtn.Text = "×"
CloseStudioBtn.TextColor3 = Color3.new(1, 1, 1)
CloseStudioBtn.Font = Enum.Font.GothamBold
CloseStudioBtn.TextSize = 14
CloseStudioBtn.Parent = StudioHeader

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 4)
CloseCorner.Parent = CloseStudioBtn

-- Studio Content
local StudioContent = Instance.new("Frame")
StudioContent.Size = UDim2.new(1, -16, 1, -30)
StudioContent.Position = UDim2.new(0, 8, 0, 28)
StudioContent.BackgroundTransparency = 1
StudioContent.Parent = RecordingStudio

-- Helper function untuk membuat button studio
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
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = btn
    
    btn.MouseEnter:Connect(function()
        pcall(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(
                    math.min(color.R * 255 + 20, 255),
                    math.min(color.G * 255 + 20, 255),
                    math.min(color.B * 255 + 20, 255)
                )
            }):Play()
        end)
    end)
    
    btn.MouseLeave:Connect(function()
        pcall(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = color}):Play()
        end)
    end)
    
    return btn
end

-- Top Row Buttons - Sesuai permintaan
local SaveBtn = CreateStudioBtn("SAVE", 5, 5, 50, 25, Color3.fromRGB(100, 200, 100))
local RecordBtn = CreateStudioBtn("RECORD", 60, 5, 55, 25, Color3.fromRGB(200, 50, 60))
local ClearBtn = CreateStudioBtn("CLEAR", 120, 5, 50, 25, Color3.fromRGB(150, 50, 60))

-- Frame Counter
local FrameLabel = Instance.new("TextLabel")
FrameLabel.Size = UDim2.fromOffset(164, 28)
FrameLabel.Position = UDim2.fromOffset(5, 35)
FrameLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
FrameLabel.Text = "Frame 0"
FrameLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
FrameLabel.Font = Enum.Font.GothamBold
FrameLabel.TextSize = 11
FrameLabel.Parent = StudioContent

local FrameCorner = Instance.new("UICorner")
FrameCorner.CornerRadius = UDim.new(0, 5)
FrameCorner.Parent = FrameLabel

-- Bottom Row Buttons - Sesuai permintaan
local ReverseBtn = CreateStudioBtn("⏪", 5, 68, 50, 30, Color3.fromRGB(80, 120, 200))
local ResumeBtn = CreateStudioBtn("RESUME", 60, 68, 55, 30, Color3.fromRGB(40, 180, 80))
local ForwardBtn = CreateStudioBtn("⏩", 120, 68, 50, 30, Color3.fromRGB(200, 120, 80))

-- Status Label
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.fromOffset(164, 20)
StatusLabel.Position = UDim2.fromOffset(5, 103)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Ready to record"
StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 9
StatusLabel.Parent = StudioContent

-- ========= MAIN GUI =========
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.fromOffset(250, 280)
MainFrame.Position = UDim2.new(0.5, -125, 0.5, -140)
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
Title.Text = "AUTO WALK PRO v8.7"
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
        pcall(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(
                math.min(color.R * 255 + 20, 255),
                math.min(color.G * 255 + 20, 255), 
                math.min(color.B * 255 + 20, 255)
            )}):Play()
        end)
    end)
    
    btn.MouseLeave:Connect(function()
        pcall(function()
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
        pcall(function()
            if isOn then
                TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(60, 200, 100)}):Play()
            else
                TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(100, 100, 100)}):Play()
            end
        end)
    end)
    
    btn.MouseLeave:Connect(function()
        pcall(function()
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
Status.Text = "System Ready - v8.7 Smooth Recording"
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

-- Progress Bar
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

-- ========= ROUTE VISUALIZATION =========
local routeParts = {}
local routeBeams = {}

local function ClearRouteVisualization()
    pcall(function()
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
    
    pcall(function()
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
    
    pcall(function()
        for _, child in pairs(ReplayList:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        
        local recordingNames = {}
        for name, recording in pairs(RecordedMovements) do
            if recording and #recording > 0 then
                table.insert(recordingNames, name)
            end
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
            
            local framesLabel = Instance.new("TextLabel")
            framesLabel.Size = UDim2.new(0, 40, 1, 0)
            framesLabel.Position = UDim2.new(0, 125, 0, 0)
            framesLabel.BackgroundTransparency = 1
            framesLabel.Text = "(" .. #rec .. ")"
            framesLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            framesLabel.Font = Enum.Font.Gotham
            framesLabel.TextSize = 7
            framesLabel.TextXAlignment = Enum.TextXAlignment.Left
            framesLabel.Parent = item
            
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
                pcall(function()
                    if enterPressed and nameBox.Text ~= "" and nameBox.Text ~= name then
                        if not RecordedMovements[nameBox.Text] then
                            RecordedMovements[nameBox.Text] = RecordedMovements[name]
                            RecordedMovements[name] = nil
                            UpdateReplayList()
                        else
                            nameBox.Text = name
                            UpdateStatus("Name already exists!")
                        end
                    else
                        nameBox.Text = name
                    end
                end)
            end)
            
            local playConn = playBtn.MouseButton1Click:Connect(function()
                pcall(function()
                    if not IsPlaying then
                        PlayRecording(name)
                    end
                end)
            end)
            AddConnection(playConn)
            
            local delConn = delBtn.MouseButton1Click:Connect(function()
                pcall(function()
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
    pcall(function()
        FrameLabel.Text = "Frame " .. #CurrentRecording.Frames
    end)
end

-- ========= ENHANCED RECORDING WITH REAL-TIME FALL DETECTION =========
local function StartEnhancedRecording()
    if IsRecording then return end
    
    pcall(function()
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            StatusLabel.Text = "❌ Character not found!"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            return
        end
        
        IsRecording = true
        IsTimelineMode = false
        CurrentRecording = {Frames = {}, StartTime = tick(), Name = "Recording_" .. os.date("%H%M%S")}
        lastRecordTime = 0
        lastRecordPos = nil
        lastStablePosition = nil
        fallSequence = {}
        consecutiveFallFrames = 0
        
        RecordBtn.Text = "STOP"
        RecordBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 60)
        StatusLabel.Text = "Recording..."
        StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
        
        recordConnection = RunService.Heartbeat:Connect(function()
            pcall(function()
                local char = player.Character
                if not char or not char:FindFirstChild("HumanoidRootPart") or #CurrentRecording.Frames >= MAX_FRAMES then
                    return
                end
                
                local hrp = char.HumanoidRootPart
                local hum = char:FindFirstChildOfClass("Humanoid")
                
                if IsTimelineMode then
                    return
                end
                
                local now = tick()
                if (now - lastRecordTime) < (1 / RECORDING_FPS) then return end
                
                local currentPos = hrp.Position
                local currentVelocity = hrp.AssemblyLinearVelocity
                
                if lastRecordPos and (currentPos - lastRecordPos).Magnitude < MIN_DISTANCE_THRESHOLD then
                    lastRecordTime = now
                    return
                end
                
                local cf = hrp.CFrame
                local newFrame = {
                    Position = {cf.Position.X, cf.Position.Y, cf.Position.Z},
                    LookVector = {cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z},
                    UpVector = {cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z},
                    Velocity = {currentVelocity.X, currentVelocity.Y, currentVelocity.Z},
                    MoveState = "Running",
                    WalkSpeed = hum and hum.WalkSpeed or 16,
                    Timestamp = now - CurrentRecording.StartTime
                }
                
                -- Detect movement state
                if currentVelocity.Y > 25 then
                    newFrame.MoveState = "Jumping"
                elseif currentVelocity.Y < -25 then
                    newFrame.MoveState = "Falling"
                elseif math.abs(currentVelocity.Y) < 5 and currentVelocity.Magnitude > 2 then
                    newFrame.MoveState = "Running"
                else
                    newFrame.MoveState = "Idle"
                end
                
                table.insert(CurrentRecording.Frames, newFrame)
                
                -- Real-time fall detection
                ProcessRealTimeFallDetection()
                
                lastRecordTime = now
                lastRecordPos = currentPos
                
                UpdateStudioUI()
            end)
        end)
    end)
end

local function StopStudioRecording()
    IsRecording = false
    IsTimelineMode = false
    
    pcall(function()
        if recordConnection then
            recordConnection:Disconnect()
            recordConnection = nil
        end
        
        RecordBtn.Text = "RECORD"
        RecordBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
        
        if #CurrentRecording.Frames > 0 then
            StatusLabel.Text = "Stopped (" .. #CurrentRecording.Frames .. " frames)"
            StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
        else
            StatusLabel.Text = "Stopped (0 frames)"
            StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
        end
    end)
end

-- ========= SMOOTH REVERSE PLAYBACK SYSTEM =========
local function StartReversePlayback()
    if IsReversing or not IsRecording then return end
    
    pcall(function()
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
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        
        if hum then
            hum.AutoRotate = false
        end
        
        StatusLabel.Text = "Reversing..."
        StatusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
        
        local currentFrame = #CurrentRecording.Frames
        local targetFrame = math.max(1, currentFrame - math.floor(RECORDING_FPS * TIMELINE_STEP_SECONDS))
        
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
            
            if currentFrame <= targetFrame then
                currentFrame = targetFrame
                IsReversing = false
                StatusLabel.Text = "Reverse completed"
                StatusLabel.TextColor3 = Color3.fromRGB(255, 150, 50)
                if reverseConnection then
                    reverseConnection:Disconnect()
                    reverseConnection = nil
                end
                return
            end
            
            currentFrame = currentFrame - REVERSE_FRAME_STEP
            
            local frame = CurrentRecording.Frames[math.floor(currentFrame)]
            if frame then
                pcall(function()
                    local targetCFrame = GetFrameCFrame(frame)
                    hrp.CFrame = targetCFrame
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    
                    if hum then
                        hum.WalkSpeed = 0
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
    
    pcall(function()
        if reverseConnection then
            reverseConnection:Disconnect()
            reverseConnection = nil
        end
        
        StatusLabel.Text = "Reverse stopped"
        StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
    end)
end

-- ========= SMOOTH FORWARD PLAYBACK SYSTEM =========
local function StartForwardPlayback()
    if IsForwarding or not IsRecording then return end
    
    pcall(function()
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
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        
        if hum then
            hum.AutoRotate = false
        end
        
        StatusLabel.Text = "Forwarding..."
        StatusLabel.TextColor3 = Color3.fromRGB(200, 150, 100)
        
        local currentPos = hrp.Position
        local nearestFrame, _ = FindNearestFrame(CurrentRecording.Frames, currentPos)
        local currentFrame = nearestFrame
        local targetFrame = math.min(#CurrentRecording.Frames, currentFrame + math.floor(RECORDING_FPS * TIMELINE_STEP_SECONDS))
        
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
            
            if currentFrame >= targetFrame then
                currentFrame = targetFrame
                IsForwarding = false
                StatusLabel.Text = "Forward completed"
                StatusLabel.TextColor3 = Color3.fromRGB(255, 150, 50)
                if forwardConnection then
                    forwardConnection:Disconnect()
                    forwardConnection = nil
                end
                return
            end
            
            currentFrame = currentFrame + FORWARD_FRAME_STEP
            
            local frame = CurrentRecording.Frames[math.floor(currentFrame)]
            if frame then
                pcall(function()
                    local targetCFrame = GetFrameCFrame(frame)
                    hrp.CFrame = targetCFrame
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    
                    if hum then
                        hum.WalkSpeed = 0
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
    
    pcall(function()
        if forwardConnection then
            forwardConnection:Disconnect()
            forwardConnection = nil
        end
        
        StatusLabel.Text = "Forward stopped"
        StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
    end)
end

-- ========= SMART RESUME WITH FALL CLEANUP =========
local function SmartResumeRecording()
    if not IsRecording then
        StatusLabel.Text = "❌ Not recording!"
        return
    end
    
    pcall(function()
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
        local currentPos = hrp.Position
        
        -- Find nearest stable frame
        local nearestStableFrame = FindNearestStableFrame(CurrentRecording.Frames, currentPos)
        
        -- Delete frames after the stable frame
        if nearestStableFrame < #CurrentRecording.Frames then
            local framesDeleted = #CurrentRecording.Frames - nearestStableFrame
            for i = #CurrentRecording.Frames, nearestStableFrame + 1, -1 do
                table.remove(CurrentRecording.Frames, i)
            end
            StatusLabel.Text = "Deleted " .. framesDeleted .. " frames"
        end
        
        -- Apply fall cleanup to remaining frames
        if #CurrentRecording.Frames > 10 then
            CurrentRecording.Frames = DetectAndRemoveFallFrames(CurrentRecording.Frames)
        end
        
        -- Create seamless transition
        if #CurrentRecording.Frames > 0 then
            local lastFrame = CurrentRecording.Frames[#CurrentRecording.Frames]
            local lastPos = GetFramePosition(lastFrame)
            
            if (currentPos - lastPos).Magnitude > 1.5 then
                local transitionFrames = CreateSeamlessTransition(lastFrame, currentPos)
                
                for _, transFrame in ipairs(transitionFrames) do
                    table.insert(CurrentRecording.Frames, transFrame)
                end
                
                StatusLabel.Text = "Smart transition created"
                StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
            end
        end
        
        IsTimelineMode = false
        
        if hum then
            hum.WalkSpeed = 16
            hum.AutoRotate = true
        end
        
        StatusLabel.Text = "Resumed (Fall Cleaned)"
        StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
        
        UpdateStudioUI()
    end)
end

local function SaveStudioRecording()
    pcall(function()
        if #CurrentRecording.Frames == 0 then
            StatusLabel.Text = "❌ No frames to save!"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            return
        end
        
        if IsRecording then
            StopStudioRecording()
        end
        
        -- Apply final fall cleanup before saving
        local cleanedRecording = DetectAndRemoveFallFrames(CurrentRecording.Frames)
        
        -- Simpan recording yang sudah dibersihkan
        RecordedMovements[CurrentRecording.Name] = cleanedRecording
        UpdateReplayList()
        
        StatusLabel.Text = "Saved: " .. CurrentRecording.Name
        StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
        
        UpdateStatus("Saved: " .. CurrentRecording.Name .. " (" .. #cleanedRecording .. " cleaned frames)")
        
        -- Reset recording
        CurrentRecording = {Frames = {}, StartTime = 0, Name = "Recording_" .. os.date("%H%M%S")}
        TimelinePosition = 0
        IsTimelineMode = false
        UpdateStudioUI()
        
        wait(1.5)
        RecordingStudio.Visible = false
        MainFrame.Visible = true
    end)
end

local function ClearStudioRecording()
    pcall(function()
        if IsRecording then
            StopStudioRecording()
        end
        
        CurrentRecording = {Frames = {}, StartTime = 0, Name = "Recording_" .. os.date("%H%M%S")}
        TimelinePosition = 0
        IsTimelineMode = false
        
        UpdateStudioUI()
        StatusLabel.Text = "Cleared - Ready to record"
        StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
    end)
end

-- ========= STUDIO BUTTON EVENTS =========
RecordBtn.MouseButton1Click:Connect(function()
    pcall(function()
        if IsRecording then
            StopStudioRecording()
        else
            StartEnhancedRecording()
        end
    end)
end)

ReverseBtn.MouseButton1Click:Connect(function()
    pcall(function()
        if IsReversing then
            StopReversePlayback()
        else
            if IsForwarding then
                StopForwardPlayback()
            end
            StartReversePlayback()
        end
    end)
end)

ForwardBtn.MouseButton1Click:Connect(function()
    pcall(function()
        if IsForwarding then
            StopForwardPlayback()
        else
            if IsReversing then
                StopReversePlayback()
            end
            StartForwardPlayback()
        end
    end)
end)

ResumeBtn.MouseButton1Click:Connect(function()
    pcall(function()
        SmartResumeRecording()
    end)
end)

SaveBtn.MouseButton1Click:Connect(function()
    pcall(function()
        SaveStudioRecording()
    end)
end)

ClearBtn.MouseButton1Click:Connect(function()
    pcall(function()
        ClearStudioRecording()
    end)
end)

CloseStudioBtn.MouseButton1Click:Connect(function()
    pcall(function()
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

-- ========= ENHANCED PLAYBACK SYSTEM =========
function PlayRecordingWithEnhancedSystem(recording, startFrame)
    if not recording or #recording == 0 then return end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
    if not hum or not hrp then return end
    
    task.spawn(function()
        pcall(function()
            SaveHumanoidState()
            hum.AutoRotate = false
            hum.PlatformStand = false
            
            local currentFrame = startFrame or 1
            playbackStartTime = tick()
            totalPausedDuration = 0
            pauseStartTime = 0
            lastPlaybackState = nil
            
            lastPlaybackCFrame = hrp.CFrame
            lastPlaybackVelocity = Vector3.new(0, 0, 0)
            
            playbackConnection = RunService.Heartbeat:Connect(function(deltaTime)
                if not IsPlaying then
                    if playbackConnection then
                        playbackConnection:Disconnect()
                    end
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
                    if playbackConnection then
                        playbackConnection:Disconnect()
                    end
                    return
                end
                
                hum = char:FindFirstChildOfClass("Humanoid")
                hrp = char:FindFirstChild("HumanoidRootPart")
                if not hum or not hrp then
                    IsPlaying = false
                    if playbackConnection then
                        playbackConnection:Disconnect()
                    end
                    return
                end
                
                if currentFrame > #recording then
                    IsPlaying = false
                    IsPaused = false
                    lastPlaybackState = nil
                    
                    local finalFrame = recording[#recording]
                    if finalFrame then
                        pcall(function()
                            hrp.CFrame = GetFrameCFrame(finalFrame)
                            ApplyUniversalVelocity(char, Vector3.new(0, 0, 0))
                        end)
                    end
                    
                    CompleteCharacterReset(char)
                    if playbackConnection then
                        playbackConnection:Disconnect()
                    end
                    
                    if AutoLoop then
                        task.wait(0.5)
                        PlayRecording(currentRecordingName)
                    end
                    return
                end
                
                local targetFrame = recording[currentFrame]
                if not targetFrame then 
                    currentFrame = currentFrame + 1
                    return 
                end
                
                pcall(function()
                    local targetCFrame = GetFrameCFrame(targetFrame)
                    local targetVelocity = GetFrameVelocity(targetFrame) * CurrentSpeed
                    
                    local smoothCFrame = SmoothCFrameLerp(hrp.CFrame, targetCFrame, INTERPOLATION_ALPHA)
                    local smoothVelocity = lastPlaybackVelocity:Lerp(targetVelocity, INTERPOLATION_ALPHA)
                    
                    hrp.CFrame = smoothCFrame
                    ApplyUniversalVelocity(char, smoothVelocity)
                    
                    lastPlaybackCFrame = smoothCFrame
                    lastPlaybackVelocity = smoothVelocity
                    
                    hum.WalkSpeed = GetFrameWalkSpeed(targetFrame) * CurrentSpeed
                    
                    -- Enhanced state control for better animations
                    local moveState = targetFrame.MoveState
                    
                    if moveState ~= lastPlaybackState then
                        lastPlaybackState = moveState
                        UniversalStateControl(hum, moveState, targetFrame)
                    end
                    
                    currentPlaybackFrame = currentFrame
                    currentFrame = currentFrame + 1
                end)
            end)
            
            AddConnection(playbackConnection)
        end)
    end)
end

-- ========= PLAYBACK FUNCTIONS =========
function PlayRecording(name)
    if IsPlaying then return end
    
    pcall(function()
        local recording = nil
        if name then
            recording = RecordedMovements[name]
        else
            local firstKey = next(RecordedMovements)
            if firstKey then
                recording = RecordedMovements[firstKey]
                name = firstKey
            end
        end
        
        if not recording then
            UpdateStatus("ERROR: No recordings available!")
            return
        end
        
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            UpdateStatus("ERROR: Character not found!")
            return
        end
        
        currentRecordingName = name
        
        IsPlaying = true
        IsPaused = false
        totalPausedDuration = 0
        pauseStartTime = 0
        lastMoveState = nil
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local nearestFrame, distance = FindNearestFrame(recording, hrp.Position)
        
        if distance <= ROUTE_PROXIMITY_THRESHOLD then
            currentPlaybackFrame = nearestFrame
            UpdateStatus("▶ Playing: " .. name .. " (from frame " .. nearestFrame .. ")")
        else
            currentPlaybackFrame = 1
            UpdateStatus("▶ Playing: " .. name)
        end
        
        PlayRecordingWithEnhancedSystem(recording, currentPlaybackFrame)
    end)
end

function StopPlayback()
    if not IsPlaying then return end
    
    pcall(function()
        IsPlaying = false
        IsPaused = false
        lastMoveState = nil
        
        if playbackConnection then
            playbackConnection:Disconnect()
            playbackConnection = nil
        end
        
        local char = player.Character
        if char then
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
    
    pcall(function()
        IsPaused = not IsPaused
        
        if IsPaused then
            UpdateStatus("⏸️ Playback Paused")
        else
            UpdateStatus("▶️ Playback Resumed")
        end
    end)
end

function UpdateStatus(msg)
    pcall(function()
        if Status then
            Status.Text = msg
        end
    end)
end

-- ========= SPEED CONTROL =========
local function UpdateSpeedDisplay()
    pcall(function()
        SpeedDisplay.Text = string.format("%.2fx", CurrentSpeed)
    end)
end

SpeedMinus.MouseButton1Click:Connect(function()
    pcall(function()
        if CurrentSpeed > 0.5 then
            CurrentSpeed = math.max(0.5, CurrentSpeed - 0.25)
            UpdateSpeedDisplay()
            UpdateStatus("Speed: " .. string.format("%.2f", CurrentSpeed) .. "x")
        end
    end)
end)

SpeedPlus.MouseButton1Click:Connect(function()
    pcall(function()
        if CurrentSpeed < 10 then
            CurrentSpeed = math.min(10, CurrentSpeed + 0.25)
            UpdateSpeedDisplay()
            UpdateStatus("Speed: " .. string.format("%.2f", CurrentSpeed) .. "x")
        end
    end)
end)

-- ========= FILE MANAGEMENT =========
local function SaveToFile()
    pcall(function()
        if not writefile then
            UpdateStatus("❌ Save system not available")
            return
        end
        
        local filename = FileNameBox.Text
        if filename == "" then 
            filename = "MyWalk" 
        end
        filename = filename:gsub("[^%w%s%-_]", "") .. ".json"
        
        if not next(RecordedMovements) then
            UpdateStatus("ERROR: No recordings to save!")
            return
        end
        
        local data = {
            recordings = RecordedMovements,
            settings = {
                speed = CurrentSpeed,
                autoLoop = AutoLoop,
                useMoveTo = UseMoveTo,
                showVisualization = ShowVisualization
            },
            version = "8.7"
        }
        
        local jsonEncodeSuccess, jsonResult = pcall(function()
            return HttpService:JSONEncode(data)
        end)
        
        if not jsonEncodeSuccess then
            UpdateStatus("❌ JSON encode failed")
            return
        end
        
        local saveSuccess, saveResult = pcall(function()
            return writefile(filename, jsonResult)
        end)
        
        if saveSuccess then
            UpdateStatus("💾 Saved: " .. filename)
        else
            UpdateStatus("❌ Save failed")
        end
    end)
end

local function LoadFromFile()
    pcall(function()
        if not readfile or not isfile then
            UpdateStatus("❌ Load system not available")
            return
        end
        
        local filename = FileNameBox.Text
        if filename == "" then 
            filename = "MyWalk" 
        end
        filename = filename:gsub("[^%w%s%-_]", "") .. ".json"
        
        local fileCheckSuccess, fileExists = pcall(function()
            return isfile(filename)
        end)
        
        if not fileCheckSuccess then
            UpdateStatus("❌ File check failed")
            return
        end
        
        if fileCheckSuccess and fileExists then
            local readSuccess, fileContent = pcall(function()
                return readfile(filename)
            end)
            
            if not readSuccess then
                UpdateStatus("❌ Read file failed")
                return
            end
            
            local decodeSuccess, data = pcall(function()
                return HttpService:JSONDecode(fileContent)
            end)
            
            if decodeSuccess and data and type(data) == "table" then
                RecordedMovements = data.recordings or {}
                CurrentSpeed = (data.settings and type(data.settings.speed) == "number") and data.settings.speed or 1
                AutoLoop = (data.settings and type(data.settings.autoLoop) == "boolean") and data.settings.autoLoop or false
                UseMoveTo = (data.settings and type(data.settings.useMoveTo) == "boolean") and data.settings.useMoveTo or false
                ShowVisualization = (data.settings and type(data.settings.showVisualization) == "boolean") and data.settings.showVisualization or false
                
                UpdateSpeedDisplay()
                SetMoveToState(UseMoveTo)
                SetVisualState(ShowVisualization)
                SetLoopState(AutoLoop)
                UpdateReplayList()
                
                UpdateStatus("📂 Loaded: " .. filename)
            else
                UpdateStatus("❌ ERROR: Invalid file format")
            end
        else
            UpdateStatus("❌ ERROR: File not found")
        end
    end)
end

-- ========= MAIN GUI BUTTON EVENTS =========
OpenStudioBtn.MouseButton1Click:Connect(function()
    pcall(function()
        MainFrame.Visible = false
        RecordingStudio.Visible = true
        StatusLabel.Text = "Ready to record"
        StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
    end)
end)

PauseBtn.MouseButton1Click:Connect(function()
    pcall(function()
        PauseResumePlayback()
    end)
end)

PlayBtn.MouseButton1Click:Connect(function()
    pcall(function()
        if IsPlaying and IsPaused then
            PauseResumePlayback()
        else
            PlayRecording()
        end
    end)
end)

StopBtn.MouseButton1Click:Connect(function()
    pcall(function()
        StopPlayback()
    end)
end)

MoveToBtn.MouseButton1Click:Connect(function()
    pcall(function()
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
    pcall(function()
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
    pcall(function()
        AutoLoop = not AutoLoop
        SetLoopState(AutoLoop)
        UpdateStatus("🔄 Auto Loop: " .. (AutoLoop and "ON" or "OFF"))
    end)
end)

SaveFileBtn.MouseButton1Click:Connect(function()
    pcall(function()
        SaveToFile()
    end)
end)

LoadFileBtn.MouseButton1Click:Connect(function()
    pcall(function()
        LoadFromFile()
    end)
end)

HideButton.MouseButton1Click:Connect(function()
    pcall(function()
        MainFrame.Visible = false
        MiniButton.Visible = true
    end)
end)

MiniButton.MouseButton1Click:Connect(function()
    pcall(function()
        MainFrame.Visible = true
        MiniButton.Visible = false
    end)
end)

CloseButton.MouseButton1Click:Connect(function()
    pcall(function()
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
    
    pcall(function()
        if input.KeyCode == Enum.KeyCode.F9 then
            if RecordingStudio.Visible then
                if IsRecording then
                    StopStudioRecording()
                else
                    StartEnhancedRecording()
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
        end
    end)
end)

-- ========= CHARACTER RESPAWN HANDLER =========
player.CharacterAdded:Connect(function(newChar)
    pcall(function()
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
    end)
end)

-- ========= PROGRESS BAR UPDATE =========
RunService.Heartbeat:Connect(function()
    pcall(function()
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
pcall(function()
    UpdateReplayList()
    UpdateStatus("✅ Auto Walk Pro v8.7 - Smooth Recording Ready!")
    UpdateSpeedDisplay()
end)

-- ========= FINAL STATUS UPDATE =========
task.wait(0.5)
pcall(function()
    UpdateStatus("✅ Smooth Recording System - All Systems Go!")
end)