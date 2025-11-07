-- ========= AUTO WALK PRO v9.0 - FULL BODY TRACKING SYSTEM =========
-- R6/R15 CROSS-COMPATIBILITY + COMPLETE ANIMATION RECORDING
-- Fix playback stuck issue + Perfect movement replay

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
local MIN_DISTANCE_THRESHOLD = 0.01
local VELOCITY_SCALE = 1
local ROUTE_PROXIMITY_THRESHOLD = 10
local MOVETO_REACH_DISTANCE = 2
local MAX_FRAME_JUMP = 60
local JUMP_VELOCITY_THRESHOLD = 25
local FALL_TIME_THRESHOLD = 1.0
local FALL_HEIGHT_THRESHOLD = 20
local TIMELINE_STEP_SECONDS = 1

-- ========= BODY TRACKING CONFIGURATION =========
local ENABLE_FULL_BODY = true -- Toggle full body tracking
local RECORD_ANIMATIONS = true -- Record animation states

-- R6 Parts
local R6_PARTS = {
    "Head", "Torso", 
    "Left Arm", "Right Arm",
    "Left Leg", "Right Leg"
}

-- R15 Parts
local R15_PARTS = {
    "Head",
    "UpperTorso", "LowerTorso",
    "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot"
}

-- ========= CORE VARIABLES =========
local IsRecording = false
local IsPlaying = false
local IsPaused = false
local UseMoveTo = true
local CurrentSpeed = 1
local RecordedMovements = {}
local CurrentRecording = {Frames = {}, StartTime = 0, Name = "", RigType = "Unknown"}
local AutoHeal = false
local AutoLoop = false
local recordConnection = nil
local lastRecordTime = 0
local lastRecordPos = nil
local ShowVisualization = false

-- ========= ANTI-FALL VARIABLES =========
local IsFallDetected = false
local LastSafeFrame = 0
local fallStartTime = 0
local fallStartHeight = 0
local isCurrentlyFalling = false
local FallCheckEnabled = true

-- ========= PAUSE/RESUME VARIABLES =========
local playbackStartTime = 0
local totalPausedDuration = 0
local pauseStartTime = 0
local currentPlaybackFrame = 1
local lastMoveState = nil
local moveToConnection = nil
local currentRecordingName = ""

-- ========= TIMELINE NAVIGATION VARIABLES =========
local TimelinePosition = 0
local IsTimelineMode = false
local timelineGroundedStart = nil

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
    if not success then
        -- Silent error handling
    end
    return success, result
end

-- ========= RIG TYPE DETECTION =========
local function GetRigType(character)
    if not character then return "Unknown" end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return "Unknown" end
    
    if character:FindFirstChild("UpperTorso") then
        return "R15"
    elseif character:FindFirstChild("Torso") then
        return "R6"
    end
    
    return "Unknown"
end

-- ========= BODY PART MAPPING (R6 <-> R15) =========
local PART_MAPPING = {
    -- R6 to R15
    ["Torso"] = "UpperTorso",
    ["Left Arm"] = "LeftUpperArm",
    ["Right Arm"] = "RightUpperArm",
    ["Left Leg"] = "LeftUpperLeg",
    ["Right Leg"] = "RightUpperLeg",
    
    -- R15 to R6
    ["UpperTorso"] = "Torso",
    ["LowerTorso"] = "Torso",
    ["LeftUpperArm"] = "Left Arm",
    ["LeftLowerArm"] = "Left Arm",
    ["LeftHand"] = "Left Arm",
    ["RightUpperArm"] = "Right Arm",
    ["RightLowerArm"] = "Right Arm",
    ["RightHand"] = "Right Arm",
    ["LeftUpperLeg"] = "Left Leg",
    ["LeftLowerLeg"] = "Left Leg",
    ["LeftFoot"] = "Left Leg",
    ["RightUpperLeg"] = "Right Leg",
    ["RightLowerLeg"] = "Right Leg",
    ["RightFoot"] = "Right Leg"
}

-- ========= GET COMPATIBLE PART =========
local function GetCompatiblePart(character, partName, sourceRigType, targetRigType)
    -- Same rig type
    if sourceRigType == targetRigType then
        return character:FindFirstChild(partName)
    end
    
    -- Try direct find first
    local part = character:FindFirstChild(partName)
    if part then return part end
    
    -- Use mapping
    local mappedName = PART_MAPPING[partName]
    if mappedName then
        return character:FindFirstChild(mappedName)
    end
    
    return nil
end

-- ========= RECORD FULL BODY FRAME =========
local function RecordFullBodyFrame(character)
    local rigType = GetRigType(character)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    
    if not hrp or not humanoid then return nil end
    
    local frame = {
        Timestamp = tick() - CurrentRecording.StartTime,
        RigType = rigType,
        
        -- Core movement data
        RootCFrame = {hrp.CFrame:GetComponents()},
        RootVelocity = {hrp.AssemblyLinearVelocity.X, hrp.AssemblyLinearVelocity.Y, hrp.AssemblyLinearVelocity.Z},
        WalkSpeed = humanoid.WalkSpeed,
        MoveState = GetCurrentMoveState(humanoid, hrp),
        
        -- Body parts data
        BodyParts = {}
    }
    
    if ENABLE_FULL_BODY then
        local partsToRecord = rigType == "R6" and R6_PARTS or R15_PARTS
        
        for _, partName in ipairs(partsToRecord) do
            local part = character:FindFirstChild(partName)
            if part and part:IsA("BasePart") then
                local cf = part.CFrame
                local relCF = hrp.CFrame:ToObjectSpace(cf) -- Relative to HRP
                
                frame.BodyParts[partName] = {
                    RelativeCFrame = {relCF:GetComponents()},
                    Velocity = {part.AssemblyLinearVelocity.X, part.AssemblyLinearVelocity.Y, part.AssemblyLinearVelocity.Z}
                }
            end
        end
        
        -- Record Motor6D data for precise animation
        if RECORD_ANIMATIONS then
            frame.Joints = {}
            for _, obj in ipairs(character:GetDescendants()) do
                if obj:IsA("Motor6D") then
                    frame.Joints[obj.Name] = {
                        C0 = {obj.C0:GetComponents()},
                        C1 = {obj.C1:GetComponents()}
                    }
                end
            end
        end
    end
    
    return frame
end

-- ========= PLAYBACK FULL BODY FRAME =========
local function PlaybackFullBodyFrame(character, frame, useSmooth)
    local targetRigType = GetRigType(character)
    local sourceRigType = frame.RigType or "Unknown"
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    
    if not hrp or not humanoid then return end
    
    -- Apply root movement
    SafeCall(function()
        if frame.RootCFrame then
            local cf = CFrame.new(unpack(frame.RootCFrame))
            
            if UseMoveTo and not useSmooth then
                -- MoveTo mode - natural walking
                humanoid:MoveTo(cf.Position)
                hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.atan2(cf.LookVector.X, cf.LookVector.Z), 0)
            else
                -- CFrame mode - direct positioning
                hrp.CFrame = cf
            end
        end
        
        if frame.RootVelocity then
            hrp.AssemblyLinearVelocity = Vector3.new(
                frame.RootVelocity[1] * CurrentSpeed,
                frame.RootVelocity[2] * CurrentSpeed,
                frame.RootVelocity[3] * CurrentSpeed
            )
        end
        
        if frame.WalkSpeed then
            humanoid.WalkSpeed = frame.WalkSpeed * CurrentSpeed
        end
    end)
    
    -- Apply body parts (with cross-rig compatibility)
    if ENABLE_FULL_BODY and frame.BodyParts then
        SafeCall(function()
            for partName, data in pairs(frame.BodyParts) do
                local targetPart = GetCompatiblePart(character, partName, sourceRigType, targetRigType)
                
                if targetPart and targetPart:IsA("BasePart") and data.RelativeCFrame then
                    -- Apply relative CFrame to maintain animation
                    local relCF = CFrame.new(unpack(data.RelativeCFrame))
                    local worldCF = hrp.CFrame * relCF
                    
                    targetPart.CFrame = worldCF
                    
                    -- Apply velocity for natural movement
                    if data.Velocity and not UseMoveTo then
                        targetPart.AssemblyLinearVelocity = Vector3.new(
                            data.Velocity[1] * CurrentSpeed,
                            data.Velocity[2] * CurrentSpeed,
                            data.Velocity[3] * CurrentSpeed
                        )
                    end
                end
            end
        end)
    end
    
    -- Apply joint data (if same rig type)
    if RECORD_ANIMATIONS and frame.Joints and sourceRigType == targetRigType then
        SafeCall(function()
            for jointName, data in pairs(frame.Joints) do
                local joint = character:FindFirstChild(jointName, true)
                if joint and joint:IsA("Motor6D") then
                    if data.C0 then
                        joint.C0 = CFrame.new(unpack(data.C0))
                    end
                    if data.C1 then
                        joint.C1 = CFrame.new(unpack(data.C1))
                    end
                end
            end
        end)
    end
    
    -- Apply movement state
    if frame.MoveState then
        SafeCall(function()
            if frame.MoveState == "Jumping" then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            elseif frame.MoveState == "Falling" then
                humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
            elseif frame.MoveState == "Climbing" then
                humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
            elseif frame.MoveState == "Swimming" then
                humanoid:ChangeState(Enum.HumanoidStateType.Swimming)
            else
                humanoid:ChangeState(Enum.HumanoidStateType.Running)
            end
        end)
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
        
        -- Re-enable collisions
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
        
        if moveToConnection then
            moveToConnection:Disconnect()
            moveToConnection = nil
        end
    end)
end

-- ========= FALL DETECTION =========
local function GetCurrentMoveState(hum, hrp)
    if not hum then return "Grounded" end
    
    local state = hum:GetState()
    local velocity = hrp.AssemblyLinearVelocity
    
    if state == Enum.HumanoidStateType.Freefall then
        if not isCurrentlyFalling then
            isCurrentlyFalling = true
            fallStartTime = tick()
            fallStartHeight = hrp.Position.Y
        end
        
        local fallDuration = tick() - fallStartTime
        local fallDistance = fallStartHeight - hrp.Position.Y
        
        if FallCheckEnabled and (fallDuration > FALL_TIME_THRESHOLD and fallDistance > FALL_HEIGHT_THRESHOLD) then
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
    if frame.RootCFrame then
        local cf = CFrame.new(unpack(frame.RootCFrame))
        return cf.Position
    end
    return Vector3.new(0, 0, 0)
end

local function GetFrameTimestamp(frame)
    return frame.Timestamp or 0
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

-- ========= GUI SETUP =========
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoWalkProV9"
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
StudioTitle.Text = "🎬 RECORDING STUDIO"
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
FrameLabel.Text = "Frames: 0 / 30000 | Rig: Unknown"
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
TimelineLabel.Text = "Timeline Control (1 sec/step)"
TimelineLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
TimelineLabel.Font = Enum.Font.Gotham
TimelineLabel.TextSize = 8
TimelineLabel.Parent = StudioContent

-- Timeline Buttons
local RewindBtn = CreateStudioBtn("⏪ MUNDUR", 5, 98, 64, 35, Color3.fromRGB(80, 120, 200))
local ResumeBtn = CreateStudioBtn("▶ RESUME", 74, 98, 68, 35, Color3.fromRGB(40, 180, 80))
local ForwardBtn = CreateStudioBtn("MAJU ⏩", 147, 98, 68, 35, Color3.fromRGB(80, 120, 200))

-- Full Body Toggle
local FullBodyBtn = CreateStudioBtn("FULL BODY: ON", 5, 138, 214, 24, Color3.fromRGB(100, 150, 255))

-- Status Label
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.fromOffset(214, 20)
StatusLabel.Position = UDim2.fromOffset(5, 167)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Ready to record"
StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 8
StatusLabel.Parent = StudioContent

-- ========= MAIN GUI (250x220) =========
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.fromOffset(250, 220)
MainFrame.Position = UDim2.new(0.5, -125, 0.5, -110)
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
Title.Text = "AUTO WALK PRO v9.0"
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
Content.CanvasSize = UDim2.new(0, 0, 0, 420)
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

-- ========= GUI COMPONENTS =========
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
Status.Position = UDim2.fromOffset(0, 400)
Status.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Status.BackgroundTransparency = 0
Status.Text = "System Ready - v9.0 Full Body"
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

local MoveToBtn, GetMoveToState, SetMoveToState = CreateToggleButton("MoveTo", 10, 75, 110, 24, true)
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
ReplayList.Size = UDim2.new(1, 0, 0, 190)
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

local function ClearRouteVisualization()
    SafeCall(function()
        for _, part in pairs(routeParts) do
            if part and part.Parent then
                part:Destroy()
            end
        end
        routeParts = {}
    end)
end

local function ShowRouteVisualization(recording)
    ClearRouteVisualization()
    
    if not recording or #recording == 0 or not ShowVisualization then return end
    
    SafeCall(function()
        local folder = Instance.new("Folder")
        folder.Name = "RouteVisualization"
        folder.Parent = workspace
        
        local step = math.max(10, math.floor(#recording / 500))
        
        for i = 1, #recording, step do
            local frame = recording[i]
            local pos = GetFramePosition(frame)
            
            local part = Instance.new("Part")
            part.Size = Vector3.new(0.5, 0.5, 0.5)
            part.Position = pos
            part.Anchored = true
            part.CanCollide = false
            part.Transparency = 0.3
            part.Color = Color3.fromRGB(100, 255, 150)
            part.Material = Enum.Material.Neon
            part.Shape = Enum.PartType.Ball
            part.Parent = folder
            
            table.insert(routeParts, part)
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
            item.Size = UDim2.new(1, -8, 0, 18)
            item.Position = UDim2.new(0, 4, 0, yPos)
            item.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            item.Parent = ReplayList
            
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 4)
            corner.Parent = item
            
            local rigType = rec.RigType or "Unknown"
            local rigColor = rigType == "R6" and Color3.fromRGB(255, 200, 100) or Color3.fromRGB(100, 200, 255)
            
            local rigLabel = Instance.new("TextLabel")
            rigLabel.Size = UDim2.fromOffset(25, 14)
            rigLabel.Position = UDim2.new(0, 2, 0.5, -7)
            rigLabel.BackgroundColor3 = rigColor
            rigLabel.Text = rigType
            rigLabel.TextColor3 = Color3.new(0, 0, 0)
            rigLabel.Font = Enum.Font.GothamBold
            rigLabel.TextSize = 6
            rigLabel.Parent = item
            
            local rigCorner = Instance.new("UICorner")
            rigCorner.CornerRadius = UDim.new(0, 3)
            rigCorner.Parent = rigLabel
            
            local nameBox = Instance.new("TextBox")
            nameBox.Size = UDim2.new(0, 90, 1, 0)
            nameBox.Position = UDim2.new(0, 30, 0, 0)
            nameBox.BackgroundTransparency = 1
            nameBox.Text = name
            nameBox.TextColor3 = Color3.new(1, 1, 1)
            nameBox.Font = Enum.Font.Gotham
            nameBox.TextSize = 8
            nameBox.PlaceholderText = "Rename..."
            nameBox.Parent = item
            
            local playBtn = Instance.new("TextButton")
            playBtn.Size = UDim2.fromOffset(30, 14)
            playBtn.Position = UDim2.new(1, -65, 0.5, -7)
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
            delBtn.Size = UDim2.fromOffset(30, 14)
            delBtn.Position = UDim2.new(1, -30, 0.5, -7)
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
            
            yPos = yPos + 20
        end
        
        ReplayList.CanvasSize = UDim2.new(0, 0, 0, yPos)
    end)
end

-- ========= STUDIO UI UPDATE =========
local function UpdateStudioUI()
    SafeCall(function()
        local currentPos = TimelinePosition > 0 and TimelinePosition or #CurrentRecording.Frames
        local rigType = CurrentRecording.RigType or "Unknown"
        FrameLabel.Text = string.format("Frames: %d / 30000 | Rig: %s", #CurrentRecording.Frames, rigType)
    end)
end

-- ========= RECORDING FUNCTIONS =========
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
        TimelinePosition = 0
        IsTimelineMode = false
        FallCheckEnabled = true
        timelineGroundedStart = nil
        
        local rigType = GetRigType(char)
        CurrentRecording = {
            Frames = {}, 
            StartTime = tick(), 
            Name = "Studio_" .. os.date("%H%M%S"),
            RigType = rigType
        }
        
        lastRecordTime = 0
        lastRecordPos = nil
        
        RecordBtn.Text = "⏹ STOP"
        RecordBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 60)
        StatusLabel.Text = "🎬 Recording " .. rigType .. "... Move character"
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
                    StatusLabel.Text = "⚠️ FALL DETECTED! Use Timeline"
                    StatusLabel.TextColor3 = Color3.fromRGB(255, 150, 50)
                    IsFallDetected = false
                    return
                end
                
                if moveState == "Grounded" or moveState == "Running" then
                    LastSafeFrame = #CurrentRecording.Frames
                end
                
                local now = tick()
                if (now - lastRecordTime) < (1 / RECORDING_FPS) then return end
                
                local currentPos = hrp.Position
                
                if lastRecordPos and (currentPos - lastRecordPos).Magnitude < MIN_DISTANCE_THRESHOLD and moveState == "Grounded" then
                    lastRecordTime = now
                    return
                end
                
                local frame = RecordFullBodyFrame(char)
                if frame then
                    table.insert(CurrentRecording.Frames, frame)
                end
                
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

local function RewindTimeline()
    if not IsRecording then
        StatusLabel.Text = "❌ Not recording!"
        return
    end
    
    SafeCall(function()
        if #CurrentRecording.Frames == 0 then return end
        
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        
        local hrp = char.HumanoidRootPart
        
        local framesToDelete = TIMELINE_STEP_SECONDS * RECORDING_FPS
        local targetFrame = math.max(1, #CurrentRecording.Frames - framesToDelete)
        
        for i = #CurrentRecording.Frames, targetFrame + 1, -1 do
            table.remove(CurrentRecording.Frames, i)
        end
        
        if #CurrentRecording.Frames > 0 then
            local frame = CurrentRecording.Frames[#CurrentRecording.Frames]
            PlaybackFullBodyFrame(char, frame, true)
            
            for i = #CurrentRecording.Frames, 1, -1 do
                if CurrentRecording.Frames[i].MoveState == "Grounded" then
                    LastSafeFrame = i
                    break
                end
            end
            
            TimelinePosition = #CurrentRecording.Frames
        end
        
        IsTimelineMode = true
        FallCheckEnabled = false
        
        UpdateStudioUI()
        StatusLabel.Text = "⏪ Rewound 1 second - Use RESUME"
        StatusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
        
        IsFallDetected = false
        isCurrentlyFalling = false
        timelineGroundedStart = nil
    end)
end

local function ForwardTimeline()
    if not IsRecording then
        StatusLabel.Text = "❌ Not recording!"
        return
    end
    
    SafeCall(function()
        if #CurrentRecording.Frames == 0 then return end
        
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        
        if not IsTimelineMode then
            StatusLabel.Text = "⏩ Already at latest position"
            StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
            return
        end
        
        if #CurrentRecording.Frames > 0 then
            local frame = CurrentRecording.Frames[#CurrentRecording.Frames]
            PlaybackFullBodyFrame(char, frame, true)
        end
        
        UpdateStudioUI()
        StatusLabel.Text = "⏩ Position updated - Use RESUME"
        StatusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
        
        IsFallDetected = false
        isCurrentlyFalling = false
        timelineGroundedStart = nil
    end)
end

local function ResumeStudioRecording()
    if not IsRecording then
        StatusLabel.Text = "❌ Not recording!"
        return
    end
    
    SafeCall(function()
        IsTimelineMode = false
        FallCheckEnabled = true
        IsFallDetected = false
        isCurrentlyFalling = false
        timelineGroundedStart = nil
        
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
        RecordedMovements[CurrentRecording.Name].RigType = CurrentRecording.RigType
        
        UpdateReplayList()
        
        StatusLabel.Text = "💾 Saved: " .. CurrentRecording.Name
        StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
        
        UpdateStatus("Saved: " .. CurrentRecording.Name .. " (" .. #CurrentRecording.Frames .. " frames)")
        
        local rigType = GetRigType(player.Character)
        CurrentRecording = {Frames = {}, StartTime = 0, Name = "Studio_" .. os.date("%H%M%S"), RigType = rigType}
        TimelinePosition = 0
        IsTimelineMode = false
        timelineGroundedStart = nil
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
        
        local rigType = GetRigType(player.Character)
        CurrentRecording = {Frames = {}, StartTime = 0, Name = "Studio_" .. os.date("%H%M%S"), RigType = rigType}
        TimelinePosition = 0
        IsTimelineMode = false
        LastSafeFrame = 0
        timelineGroundedStart = nil
        
        UpdateStudioUI()
        StatusLabel.Text = "🗑️ Cleared - Ready to record"
        StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
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
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        
        -- Prepare character for playback
        SafeCall(function()
            humanoid.AutoRotate = not UseMoveTo
            humanoid.PlatformStand = false
            
            -- Disable collisions for smooth playback
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = false
                end
            end
        end)
        
        local nearestFrame, distance = FindNearestFrame(recording, hrp.Position)
        
        if distance <= ROUTE_PROXIMITY_THRESHOLD then
            currentPlaybackFrame = nearestFrame
            playbackStartTime = tick() - (GetFrameTimestamp(recording[nearestFrame]) / CurrentSpeed)
            UpdateStatus(string.format("▶ Starting from Frame %d (nearby)", nearestFrame))
        else
            currentPlaybackFrame = 1
            playbackStartTime = tick()
            
            local startPos = GetFramePosition(recording[1])
            if (hrp.Position - startPos).Magnitude > 50 then
                hrp.CFrame = CFrame.new(startPos)
                UpdateStatus("📍 Teleported to start position")
            else
                UpdateStatus("▶ Starting from Frame 1")
            end
        end
        
        -- Start playback loop
        task.spawn(function()
            SafeCall(function()
                local currentFrame = currentPlaybackFrame
                
                while IsPlaying and currentFrame <= #recording do
                    -- Handle pause
                    if IsPaused then
                        if pauseStartTime == 0 then
                            pauseStartTime = tick()
                            SafeCall(function()
                                if char and char:FindFirstChild("HumanoidRootPart") then
                                    local currentHum = char:FindFirstChildOfClass("Humanoid")
                                    local currentHrp = char:FindFirstChild("HumanoidRootPart")
                                    if currentHum and currentHrp then
                                        currentHum.PlatformStand = false
                                        currentHrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                                        currentHrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                                    end
                                end
                            end)
                        end
                        RunService.Heartbeat:Wait()
                        continue
                    else
                        if pauseStartTime > 0 then
                            totalPausedDuration = totalPausedDuration + (tick() - pauseStartTime)
                            pauseStartTime = 0
                        end
                    end
                    
                    -- Refresh character reference
                    char = player.Character
                    if not char or not char:FindFirstChild("HumanoidRootPart") then break end
                    humanoid = char:FindFirstChildOfClass("Humanoid")
                    hrp = char:FindFirstChild("HumanoidRootPart")
                    if not humanoid or not hrp then break end
                    
                    local currentTime = tick()
                    local effectiveTime = (currentTime - playbackStartTime - totalPausedDuration) * CurrentSpeed
                    
                    -- Find target frame based on timestamp
                    local targetFrame = currentFrame
                    local framesSkipped = 0
                    
                    while targetFrame < #recording 
                        and framesSkipped < MAX_FRAME_JUMP
                        and GetFrameTimestamp(recording[targetFrame + 1]) <= effectiveTime do
                        
                        -- Don't skip critical state changes
                        local currentState = recording[targetFrame].MoveState
                        local nextState = recording[targetFrame + 1].MoveState
                        
                        if currentState ~= nextState and (nextState == "Jumping" or nextState == "Falling") then
                            break
                        end
                        
                        targetFrame = targetFrame + 1
                        framesSkipped = framesSkipped + 1
                    end
                    
                    if targetFrame > #recording then
                        targetFrame = #recording
                    end
                    
                    local frame = recording[targetFrame]
                    if not frame then break end
                    
                    currentFrame = targetFrame
                    currentPlaybackFrame = targetFrame
                    
                    -- Apply frame with full body tracking
                    PlaybackFullBodyFrame(char, frame, false)
                    
                    -- Auto heal
                    if AutoHeal and humanoid.Health < humanoid.MaxHealth * 0.5 then
                        humanoid.Health = humanoid.MaxHealth
                    end
                    
                    -- Update status
                    if currentFrame % 30 == 0 then
                        local mode = UseMoveTo and "MoveTo" or "CFrame"
                        UpdateStatus(string.format("%s: Frame %d/%d (%.1f%%)", mode, currentFrame, #recording, (currentFrame / #recording) * 100))
                    end
                    
                    if currentFrame >= #recording then break end
                    RunService.Heartbeat:Wait()
                end
                
                -- Restore collisions
                SafeCall(function()
                    for _, part in pairs(char:GetDescendants()) do
                        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                            part.CanCollide = true
                        end
                    end
                end)
                
                -- Handle loop or stop
                if AutoLoop and IsPlaying then
                    UpdateStatus("🔄 Looping...")
                    currentPlaybackFrame = 1
                    playbackStartTime = tick()
                    totalPausedDuration = 0
                    PlayRecording(currentRecordingName)
                else
                    IsPlaying = false
                    IsPaused = false
                    lastMoveState = nil
                    CompleteCharacterReset(char)
                    UpdateStatus("🎉 Playback Complete!")
                end
            end)
        end)
    end)
end

function StopPlayback()
    if not IsPlaying then return end
    
    SafeCall(function()
        IsPlaying = false
        IsPaused = false
        lastMoveState = nil
        
        if moveToConnection then
            moveToConnection:Disconnect()
            moveToConnection = nil
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
                showVisualization = ShowVisualization,
                fullBodyTracking = ENABLE_FULL_BODY
            },
            version = "9.0"
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
            UseMoveTo = data.settings and data.settings.useMoveTo or true
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

-- ========= STUDIO BUTTON EVENTS =========
RecordBtn.MouseButton1Click:Connect(function()
    if IsRecording then
        StopStudioRecording()
    else
        StartStudioRecording()
    end
end)

RewindBtn.MouseButton1Click:Connect(RewindTimeline)
ForwardBtn.MouseButton1Click:Connect(ForwardTimeline)
ResumeBtn.MouseButton1Click:Connect(ResumeStudioRecording)
SaveBtn.MouseButton1Click:Connect(SaveStudioRecording)
ClearBtn.MouseButton1Click:Connect(ClearStudioRecording)

FullBodyBtn.MouseButton1Click:Connect(function()
    SafeCall(function()
        ENABLE_FULL_BODY = not ENABLE_FULL_BODY
        if ENABLE_FULL_BODY then
            FullBodyBtn.Text = "FULL BODY: ON"
            FullBodyBtn.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
            StatusLabel.Text = "✅ Full body tracking enabled"
        else
            FullBodyBtn.Text = "FULL BODY: OFF"
            FullBodyBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
            StatusLabel.Text = "⚠️ HRP-only mode (legacy)"
        end
    end)
end)

CloseStudioBtn.MouseButton1Click:Connect(function()
    SafeCall(function()
        if IsRecording then
            StopStudioRecording()
        end
        RecordingStudio.Visible = false
        MainFrame.Visible = true
    end)
end)

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
            UpdateStatus("🎯 Mode: Smart MoveTo")
        else
            UpdateStatus("🚀 Mode: Pure CFrame")
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
                RewindTimeline()
            end
        elseif input.KeyCode == Enum.KeyCode.F5 then
            if RecordingStudio.Visible and #CurrentRecording.Frames > 0 then
                SaveStudioRecording()
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
                stuckTimer = stuckTimer + RunService.Heartbeat:Wait()
                
                if stuckTimer >= STUCK_THRESHOLD then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then
                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                        
                        if UseMoveTo and currentPlaybackFrame < #RecordedMovements[currentRecordingName] then
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
    end)
end)

-- ========= PLAYBACK CLEANUP ON STOP =========
local originalStopPlayback = StopPlayback
StopPlayback = function()
    SafeCall(function()
        if ShowVisualization then
            ClearRouteVisualization()
        end
        originalStopPlayback()
    end)
end

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
    UpdateStatus("✅ Auto Walk Pro v9.0 - Full Body Ready!")
    UpdateSpeedDisplay()
    UpdateStudioUI()
end)

-- ========= FINAL CONFIRMATION =========
task.wait(1)
SafeCall(function()
    UpdateStatus("✅ R6/R15 Cross-Compatible System Active")
    
    -- Display current rig type
    local char = player.Character
    if char then
        local rigType = GetRigType(char)
        print("🎮 Auto Walk Pro v9.0 Loaded")
        print("📦 Your Current Rig: " .. rigType)
        print("✨ Full Body Tracking: " .. (ENABLE_FULL_BODY and "ENABLED" or "DISABLED"))
        print("🔧 Cross-Compatibility: R6 ↔ R15 Supported")
    end
end)