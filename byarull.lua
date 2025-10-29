
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
local RECORDING_FPS = 70
local MAX_FRAMES = 35000
local MIN_DISTANCE_THRESHOLD = 0.01
local VELOCITY_SCALE = 1
local VELOCITY_Y_SCALE = 1

-- ========= FIELD MAPPING FOR OBFUSCATION =========
local FIELD_MAPPING = {
    Position = "11",
    LookVector = "88", 
    UpVector = "55",
    Velocity = "22",
    MoveState = "33",
    WalkSpeed = "44",
    Timestamp = "66"
}

local REVERSE_MAPPING = {
    ["11"] = "Position",
    ["88"] = "LookVector",
    ["55"] = "UpVector", 
    ["22"] = "Velocity",
    ["33"] = "MoveState",
    ["44"] = "WalkSpeed",
    ["66"] = "Timestamp"
}

-- ========= VARIABLES =========
local IsRecording = false
local IsPlaying = false
local IsPaused = false
local CurrentSpeed = 1
local RecordedMovements = {}
local RecordingOrder = {}
local CurrentRecording = {Frames = {}, StartTime = 0, Name = ""}
local AutoLoop = false
local AutoRespawn = false
local InfiniteJump = false
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
local originalJumpButtonEnabled = true

-- ========= AUTO LOOP VARIABLES =========
local IsAutoLoopPlaying = false
local CurrentLoopIndex = 1
local LoopPauseStartTime = 0
local LoopTotalPausedDuration = 0

-- ========= VISIBLE SHIFTLOCK SYSTEM =========
local shiftLockConnection = nil
local originalMouseBehavior = nil
local ShiftLockEnabled = false
local isShiftLockActive = false

-- ========= ANIMATION SYSTEM VARIABLES =========
local lastAnimations = {}
local animationGuiOpen = false

-- ========= ANIMATIONS DATABASE (GAZE SYSTEM) =========
local Animations = {
    ["Idle"] = {
        ["2016 Animation (mm2)"] = {"387947158", "387947464"},
        ["(UGC) Oh Really?"] = {"98004748982532", "98004748982532"},
        ["Astronaut"] = {"891621366", "891633237"},
        ["Adidas Community"] = {"122257458498464", "102357151005774"},
        ["Bold"] = {"16738333868", "16738334710"},
        ["(UGC) Slasher"] = {"140051337061095", "140051337061095"},
        ["(UGC) Retro"] = {"80479383912838", "80479383912838"},
        ["(UGC) Magician"] = {"139433213852503", "139433213852503"},
        ["(UGC) John Doe"] = {"72526127498800", "72526127498800"},
        ["(UGC) Noli"] = {"139360856809483", "139360856809483"},
        ["(UGC) Coolkid"] = {"95203125292023", "95203125292023"},
        ["(UGC) Survivor Injured"] = {"73905365652295", "73905365652295"},
        ["(UGC) Retro Zombie"] = {"90806086002292", "90806086002292"},
        ["(UGC) 1x1x1x1"] = {"76780522821306", "76780522821306"},
        ["Borock"] = {"3293641938", "3293642554"},
        ["Bubbly"] = {"910004836", "910009958"},
        ["Cartoony"] = {"742637544", "742638445"},
        ["Confident"] = {"1069977950", "1069987858"},
        ["Catwalk Glam"] = {"133806214992291","94970088341563"},
        ["Cowboy"] = {"1014390418", "1014398616"},
        ["Drooling Zombie"] = {"3489171152", "3489171152"},
        ["Elder"] = {"10921101664", "10921102574"},
        ["Ghost"] = {"616006778","616008087"},
        ["Knight"] = {"657595757", "657568135"},
        ["Levitation"] = {"616006778", "616008087"},
        ["Mage"] = {"707742142", "707855907"},
        ["MrToilet"] = {"4417977954", "4417978624"},
        ["Ninja"] = {"656117400", "656118341"},
        ["NFL"] = {"92080889861410", "74451233229259"},
        ["OldSchool"] = {"10921230744", "10921232093"},
        ["Patrol"] = {"1149612882", "1150842221"},
        ["Pirate"] = {"750781874", "750782770"},
        ["Default Retarget"] = {"95884606664820", "95884606664820"},
        ["Very Long"] = {"18307781743", "18307781743"},
        ["Sway"] = {"560832030", "560833564"},
        ["Popstar"] = {"1212900985", "1150842221"},
        ["Princess"] = {"941003647", "941013098"},
        ["R6"] = {"12521158637","12521162526"},
        ["R15 Reanimated"] = {"4211217646", "4211218409"},
        ["Realistic"] = {"17172918855", "17173014241"},
        ["Robot"] = {"616088211", "616089559"},
        ["Sneaky"] = {"1132473842", "1132477671"},
        ["Sports (Adidas)"] = {"18537376492", "18537371272"},
        ["Soldier"] = {"3972151362", "3972151362"},
        ["Stylish"] = {"616136790", "616138447"},
        ["Stylized Female"] = {"4708191566", "4708192150"},
        ["Superhero"] = {"10921288909", "10921290167"},
        ["Toy"] = {"782841498", "782845736"},
        ["Udzal"] = {"3303162274", "3303162549"},
        ["Vampire"] = {"1083445855", "1083450166"},
        ["Werewolf"] = {"1083195517", "1083214717"},
        ["Wicked (Popular)"] = {"118832222982049", "76049494037641"},
        ["No Boundaries (Walmart)"] = {"18747067405", "18747063918"},
        ["Zombie"] = {"616158929", "616160636"},
        ["(UGC) Zombie"] = {"77672872857991", "77672872857991"},
        ["(UGC) TailWag"] = {"129026910898635", "129026910898635"}
    },
    ["Walk"] = {
        ["Gojo"] = "95643163365384",
        ["Geto"] = "85811471336028",
        ["Astronaut"] = "891667138",
        ["(UGC) Zombie"] = "113603435314095",
        ["Adidas Community"] = "122150855457006",
        ["Bold"] = "16738340646",
        ["Bubbly"] = "910034870",
        ["(UGC) Smooth"] = "76630051272791",
        ["Cartoony"] = "742640026",
        ["Confident"] = "1070017263",
        ["Cowboy"] = "1014421541",
        ["(UGC) Retro"] = "107806791584829",
        ["(UGC) Retro Zombie"] = "140703855480494",
        ["Catwalk Glam"] = "109168724482748",
        ["Drooling Zombie"] = "3489174223",
        ["Elder"] = "10921111375",
        ["Ghost"] = "616013216",
        ["Knight"] = "10921127095",
        ["Levitation"] = "616013216",
        ["Mage"] = "707897309",
        ["Ninja"] = "656121766",
        ["NFL"] = "110358958299415",
        ["OldSchool"] = "10921244891",
        ["Patrol"] = "1151231493",
        ["Pirate"] = "750785693",
        ["Default Retarget"] = "115825677624788",
        ["Popstar"] = "1212980338",
        ["Princess"] = "941028902",
        ["R6"] = "12518152696",
        ["R15 Reanimated"] = "4211223236",
        ["2016 Animation (mm2)"] = "387947975",
        ["Robot"] = "616095330",
        ["Sneaky"] = "1132510133",
        ["Sports (Adidas)"] = "18537392113",
        ["Stylish"] = "616146177",
        ["Stylized Female"] = "4708193840",
        ["Superhero"] = "10921298616",
        ["Toy"] = "10921306285",
        ["Udzal"] = "3303162967",
        ["Vampire"] = "1083473930",
        ["Werewolf"] = "1083178339",
        ["Wicked (Popular)"] = "92072849924640",
        ["No Boundaries (Walmart)"] = "18747074203",
        ["Zombie"] = "616168032"
    },
    ["Run"] = {
        ["2016 Animation (mm2)"] = "387947975",
        ["(UGC) Soccer"] = "116881956670910",
        ["Adidas Community"] = "82598234841035",
        ["Astronaut"] = "10921039308",
        ["Bold"] = "16738337225",
        ["Bubbly"] = "10921057244",
        ["Cartoony"] = "10921076136",
        ["(UGC) Dog"] = "130072963359721",
        ["Confident"] = "1070001516",
        ["(UGC) Pride"] = "116462200642360",
        ["(UGC) Retro"] = "107806791584829",
        ["(UGC) Retro Zombie"] = "140703855480494",
        ["Cowboy"] = "1014401683",
        ["Catwalk Glam"] = "81024476153754",
        ["Drooling Zombie"] = "3489173414",
        ["Elder"] = "10921104374",
        ["Ghost"] = "616013216",
        ["Heavy Run (Udzal / Borock)"] = "3236836670",
        ["Knight"] = "10921121197",
        ["Levitation"] = "616010382",
        ["Mage"] = "10921148209",
        ["MrToilet"] = "4417979645",
        ["Ninja"] = "656118852",
        ["NFL"] = "117333533048078",
        ["OldSchool"] = "10921240218",
        ["Patrol"] = "1150967949",
        ["Pirate"] = "750783738",
        ["Default Retarget"] = "102294264237491",
        ["Popstar"] = "1212980348",
        ["Princess"] = "941015281",
        ["R6"] = "12518152696",
        ["R15 Reanimated"] = "4211220381",
        ["Robot"] = "10921250460",
        ["Sneaky"] = "1132494274",
        ["Sports (Adidas)"] = "18537384940",
        ["Stylish"] = "10921276116",
        ["Stylized Female"] = "4708192705",
        ["Superhero"] = "10921291831",
        ["Toy"] = "10921306285",
        ["Vampire"] = "10921320299",
        ["Werewolf"] = "10921336997",
        ["Wicked (Popular)"] = "72301599441680",
        ["No Boundaries (Walmart)"] = "18747070484",
        ["Zombie"] = "616163682"
    },
    ["Jump"] = {
        ["Astronaut"] = "891627522",
        ["Adidas Community"] = "75290611992385",
        ["Bold"] = "16738336650",
        ["Bubbly"] = "910016857",
        ["Cartoony"] = "742637942",
        ["Catwalk Glam"] = "116936326516985",
        ["Confident"] = "1069984524",
        ["Cowboy"] = "1014394726",
        ["Elder"] = "10921107367",
        ["Ghost"] = "616008936",
        ["Knight"] = "910016857",
        ["Levitation"] = "616008936",
        ["Mage"] = "10921149743",
        ["Ninja"] = "656117878",
        ["NFL"] = "119846112151352",
        ["OldSchool"] = "10921242013",
        ["Patrol"] = "1148811837",
        ["Pirate"] = "750782230",
        ["(UGC) Retro"] = "139390570947836",
        ["Default Retarget"] = "117150377950987",
        ["Popstar"] = "1212954642",
        ["Princess"] = "941008832",
        ["Robot"] = "616090535",
        ["R15 Reanimated"] = "4211219390",
        ["R6"] = "12520880485",
        ["Sneaky"] = "1132489853",
        ["Sports (Adidas)"] = "18537380791",
        ["Stylish"] = "616139451",
        ["Stylized Female"] = "4708188025",
        ["Superhero"] = "10921294559",
        ["Toy"] = "10921308158",
        ["Vampire"] = "1083455352",
        ["Werewolf"] = "1083218792",
        ["Wicked (Popular)"] = "104325245285198",
        ["No Boundaries (Walmart)"] = "18747069148",
        ["Zombie"] = "616161997"
    },
    ["Fall"] = {
        ["Astronaut"] = "891617961",
        ["Adidas Community"] = "98600215928904",
        ["Bold"] = "16738333171",
        ["Bubbly"] = "910001910",
        ["Cartoony"] = "742637151",
        ["Catwalk Glam"] = "92294537340807",
        ["Confident"] = "1069973677",
        ["Cowboy"] = "1014384571",
        ["Elder"] = "10921105765",
        ["Knight"] = "10921122579",
        ["Levitation"] = "616005863",
        ["Mage"] = "707829716",
        ["Ninja"] = "656115606",
        ["NFL"] = "129773241321032",
        ["OldSchool"] = "10921241244",
        ["Patrol"] = "1148863382",
        ["Popstar"] = "1212900995",
        ["Princess"] = "941000007",
        ["Robot"] = "616087089",
        ["R15 Reanimated"] = "4211216152",
        ["R6"] = "12520972571",
        ["Sneaky"] = "1132469004",
        ["Sports (Adidas)"] = "18537367238",
        ["Stylish"] = "616134815",
        ["Stylized Female"] = "4708186162",
        ["Superhero"] = "10921293373",
        ["Toy"] = "782846423",
        ["Vampire"] = "1083443587",
        ["Werewolf"] = "1083189019",
        ["Wicked (Popular)"] = "121152442762481",
        ["No Boundaries (Walmart)"] = "18747062535",
        ["Zombie"] = "616157476"
    },
    ["Climb"] = {
        ["Astronaut"] = "10921032124",
        ["Adidas Community"] = "88763136693023",
        ["Bold"] = "16738332169",
        ["Cartoony"] = "742636889",
        ["Catwalk Glam"] = "119377220967554",
        ["Confident"] = "1069946257",
        ["CowBoy"] = "1014380606",
        ["Elder"] = "845392038",
        ["Ghost"] = "616003713",
        ["Knight"] = "10921125160",
        ["Levitation"] = "10921132092",
        ["Mage"] = "707826056",
        ["Ninja"] = "656114359",
        ["(UGC) Retro"] = "121075390792786",
        ["NFL"] = "134630013742019",
        ["OldSchool"] = "10921229866",
        ["Patrol"] = "1148811837",
        ["Popstar"] = "1213044953",
        ["Princess"] = "940996062",
        ["R6"] = "12520982150",
        ["Reanimated R15"] = "4211214992",
        ["Robot"] = "616086039",
        ["Sneaky"] = "1132461372",
        ["Sports (Adidas)"] = "18537363391",
        ["Stylish"] = "10921271391",
        ["Stylized Female"] = "4708184253",
        ["SuperHero"] = "10921286911",
        ["Toy"] = "10921300839",
        ["Vampire"] = "1083439238",
        ["WereWolf"] = "10921329322",
        ["Wicked (Popular)"] = "131326830509784",
        ["No Boundaries (Walmart)"] = "18747060903",
        ["Zombie"] = "616156119"
    }
}

-- ========= DEFAULT ANIMATIONS (R15 Standard) =========
local DefaultAnimations = {
    Idle = {"507766666", "507766951"},
    Walk = "507777826",
    Run = "507767714",
    Jump = "507765000",
    Fall = "507767968",
    Climb = "507765644"
}

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
    if shiftLockConnection then
        shiftLockConnection:Disconnect()
        shiftLockConnection = nil
    end
    if jumpConnection then
        jumpConnection:Disconnect()
        jumpConnection = nil
    end
end

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
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = prePauseJumpPower or 50
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

-- ========= ANIMATION SYSTEM FUNCTIONS =========
local function StopAllAnims()
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
                track:Stop(0)
            end
        end
    end
end

local function RefreshCharacter()
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        end
    end
end

local function SetAnimation(animType, animId)
    local character = player.Character
    if not character then return end
    local animate = character:FindFirstChild("Animate")
    if not animate then return end
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.PlatformStand = true
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and not part.Anchored then
                part.Anchored = true
            end
        end
    end
    StopAllAnims()
    task.wait(0.1)
    if animType == "Idle" and animate.idle then
        animate.idle.Animation1.AnimationId = "rbxassetid://" .. animId[1]
        animate.idle.Animation2.AnimationId = "rbxassetid://" .. animId[2]
        lastAnimations.Idle = animId
    elseif animType == "Walk" and animate.walk then
        animate.walk.WalkAnim.AnimationId = "rbxassetid://" .. animId
        lastAnimations.Walk = animId
    elseif animType == "Run" and animate.run then
        animate.run.RunAnim.AnimationId = "rbxassetid://" .. animId
        lastAnimations.Run = animId
    elseif animType == "Jump" and animate.jump then
        animate.jump.JumpAnim.AnimationId = "rbxassetid://" .. animId
        lastAnimations.Jump = animId
    elseif animType == "Fall" and animate.fall then
        animate.fall.FallAnim.AnimationId = "rbxassetid://" .. animId
        lastAnimations.Fall = animId
    elseif animType == "Climb" and animate.climb then
        animate.climb.ClimbAnim.AnimationId = "rbxassetid://" .. animId
        lastAnimations.Climb = animId
    end
    pcall(function()
        if writefile and readfile and isfile then
            writefile("AnimHub_Saved.json", HttpService:JSONEncode(lastAnimations))
        end
    end)
    RefreshCharacter()
    task.wait(0.1)
    if humanoid then
        humanoid.PlatformStand = false
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.Anchored then
                part.Anchored = false
            end
        end
    end
end

-- ========= RESET ANIMATIONS TO DEFAULT =========
local function ResetAnimations()
    local character = player.Character
    if not character then return end
    local animate = character:FindFirstChild("Animate")
    if not animate then return end
    local humanoid = character:FindFirstChild("Humanoid")
    
    if humanoid then
        humanoid.PlatformStand = true
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and not part.Anchored then
                part.Anchored = true
            end
        end
    end
    
    StopAllAnims()
    task.wait(0.1)
    
    -- Reset to default R15 animations
    if animate.idle then
        animate.idle.Animation1.AnimationId = "rbxassetid://" .. DefaultAnimations.Idle[1]
        animate.idle.Animation2.AnimationId = "rbxassetid://" .. DefaultAnimations.Idle[2]
    end
    if animate.walk then
        animate.walk.WalkAnim.AnimationId = "rbxassetid://" .. DefaultAnimations.Walk
    end
    if animate.run then
        animate.run.RunAnim.AnimationId = "rbxassetid://" .. DefaultAnimations.Run
    end
    if animate.jump then
        animate.jump.JumpAnim.AnimationId = "rbxassetid://" .. DefaultAnimations.Jump
    end
    if animate.fall then
        animate.fall.FallAnim.AnimationId = "rbxassetid://" .. DefaultAnimations.Fall
    end
    if animate.climb then
        animate.climb.ClimbAnim.AnimationId = "rbxassetid://" .. DefaultAnimations.Climb
    end
    
    -- Clear saved animations
    lastAnimations = {}
    pcall(function()
        if writefile and delfile and isfile and isfile("AnimHub_Saved.json") then
            delfile("AnimHub_Saved.json")
        end
    end)
    
    RefreshCharacter()
    task.wait(0.1)
    
    if humanoid then
        humanoid.PlatformStand = false
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.Anchored then
                part.Anchored = false
            end
        end
    end
end

-- ========= ADVANCED LOAD SAVED ANIMATIONS (FIXED) =========
local function LoadSavedAnimations()
    task.spawn(function()
        local character = player.Character
        if not character then 
            print(" No character found!")
            return 
        end
        
        -- Wait for Animate script to fully load
        local animate = character:WaitForChild("Animate", 10)
        if not animate then 
            warn("Animate script not found!")
            return 
        end
        
        -- Wait for humanoid
        local humanoid = character:WaitForChild("Humanoid", 10)
        if not humanoid then 
            warn("Humanoid not found!")
            return 
        end
        
        -- Extra wait to ensure all animation children are loaded
        task.wait(0.5)
        
        -- Load saved data dengan error handling yang better
        local success, savedData = pcall(function()
            if isfile and readfile and isfile("AnimHub_Saved.json") then
                local fileContent = readfile("AnimHub_Saved.json")
                print("File content loaded:", fileContent:sub(1, 100) .. "...")
                
                local decodedData = HttpService:JSONDecode(fileContent) -- ✅ FIX: JSONDecode bukan JSONEncode
                
                if not decodedData or type(decodedData) ~= "table" then
                    warn("Invalid save data format!")
                    return nil
                end
                
                return decodedData
            else
                print("No saved animations file found")
                return nil
            end
        end)
        
        if not success or not savedData then
            warn("Error loading animations: " .. tostring(savedData))
            return
        end
        
        print("Successfully loaded saved data:", savedData)
        
        -- Apply each animation type dengan verification
        for animType, animId in pairs(savedData) do
            task.wait(0.05) -- Small delay between each animation
            
            if animType == "Idle" and animate:FindFirstChild("idle") then
                local idle = animate.idle
                if idle:FindFirstChild("Animation1") and idle:FindFirstChild("Animation2") then
                    if type(animId) == "table" and #animId >= 2 then
                        idle.Animation1.AnimationId = "rbxassetid://" .. animId[1]
                        idle.Animation2.AnimationId = "rbxassetid://" .. animId[2]
                        print(" Set Idle animation:", animId[1], animId[2])
                    end
                end
            elseif animType == "Walk" and animate:FindFirstChild("walk") then
                local walk = animate.walk
                if walk:FindFirstChild("WalkAnim") and type(animId) == "string" then
                    walk.WalkAnim.AnimationId = "rbxassetid://" .. animId
                    print("Set Walk animation:", animId)
                end
            elseif animType == "Run" and animate:FindFirstChild("run") then
                local run = animate.run
                if run:FindFirstChild("RunAnim") and type(animId) == "string" then
                    run.RunAnim.AnimationId = "rbxassetid://" .. animId
                    print(" Set Run animation:", animId)
                end
            elseif animType == "Jump" and animate:FindFirstChild("jump") then
                local jump = animate.jump
                if jump:FindFirstChild("JumpAnim") and type(animId) == "string" then
                    jump.JumpAnim.AnimationId = "rbxassetid://" .. animId
                    print("Set Jump animation:", animId)
                end
            elseif animType == "Fall" and animate:FindFirstChild("fall") then
                local fall = animate.fall
                if fall:FindFirstChild("FallAnim") and type(animId) == "string" then
                    fall.FallAnim.AnimationId = "rbxassetid://" .. animId
                    print("Set Fall animation:", animId)
                end
            elseif animType == "Climb" and animate:FindFirstChild("climb") then
                local climb = animate.climb
                if climb:FindFirstChild("ClimbAnim") and type(animId) == "string" then
                    climb.ClimbAnim.AnimationId = "rbxassetid://" .. animId
                    print(" Set Climb animation:", animId)
                end
            end
        end
        
        lastAnimations = savedData
        
        -- Force refresh animations
        task.wait(0.2)
        RefreshCharacter()
        
        print("[AnimHub] All animations loaded successfully!")
    end)
end

-- ========= ANIMATION GUI 200x200 =========
local function OpenAnimationGUI()
    if animationGuiOpen then return end
    animationGuiOpen = true

    local AnimationGUI = Instance.new("ScreenGui")
    AnimationGUI.Name = "AnimationGUI"
    AnimationGUI.ResetOnSpawn = false
    AnimationGUI.Parent = player.PlayerGui
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 200, 0, 200)
    MainFrame.Position = UDim2.new(0.5, -100, 0.5, -100)
    MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Parent = AnimationGUI
    
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 8)
    MainCorner.Parent = MainFrame
    
    -- Header (Lebar 200, Tinggi 35)
    local Header = Instance.new("Frame")
    Header.Size = UDim2.new(1, 0, 0, 35)
    Header.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
    Header.BorderSizePixel = 0
    Header.Parent = MainFrame
    
    local HeaderCorner = Instance.new("UICorner")
    HeaderCorner.CornerRadius = UDim.new(0, 8)
    HeaderCorner.Parent = Header
    
    -- Load Button (Kiri)
    local LoadBtn = Instance.new("TextButton")
    LoadBtn.Size = UDim2.new(0, 25, 0, 25)
    LoadBtn.Position = UDim2.new(0, 5, 0.5, -12.5)
    LoadBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
    LoadBtn.Text = "📂"
    LoadBtn.TextColor3 = Color3.new(1, 1, 1)
    LoadBtn.Font = Enum.Font.GothamBold
    LoadBtn.TextSize = 14
    LoadBtn.Parent = Header
    
    local LoadCorner = Instance.new("UICorner")
    LoadCorner.CornerRadius = UDim.new(0, 4)
    LoadCorner.Parent = LoadBtn
    
    -- Search Box (Tengah)
    local SearchBox = Instance.new("TextBox")
    SearchBox.Size = UDim2.new(0, 80, 0, 25)
    SearchBox.Position = UDim2.new(0, 35, 0.5, -12.5)
    SearchBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    SearchBox.BorderSizePixel = 0
    SearchBox.Text = ""
    SearchBox.PlaceholderText = "Search..."
    SearchBox.TextColor3 = Color3.new(1, 1, 1)
    SearchBox.Font = Enum.Font.Gotham
    SearchBox.TextSize = 11
    SearchBox.TextXAlignment = Enum.TextXAlignment.Left
    SearchBox.ClearTextOnFocus = false
    SearchBox.Parent = Header
    
    local SearchCorner = Instance.new("UICorner")
    SearchCorner.CornerRadius = UDim.new(0, 4)
    SearchCorner.Parent = SearchBox
    
    local SearchPadding = Instance.new("UIPadding")
    SearchPadding.PaddingLeft = UDim.new(0, 8)
    SearchPadding.Parent = SearchBox
    
    -- Reset Button
    local ResetBtn = Instance.new("TextButton")
    ResetBtn.Size = UDim2.new(0, 25, 0, 25)
    ResetBtn.Position = UDim2.new(0, 120, 0.5, -12.5)
    ResetBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 50)
    ResetBtn.Text = "🔄"
    ResetBtn.TextColor3 = Color3.new(1, 1, 1)
    ResetBtn.Font = Enum.Font.GothamBold
    ResetBtn.TextSize = 14
    ResetBtn.Parent = Header
    
    local ResetCorner = Instance.new("UICorner")
    ResetCorner.CornerRadius = UDim.new(0, 4)
    ResetCorner.Parent = ResetBtn
    
    -- Close Button (Kanan)
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 25, 0, 25)
    CloseBtn.Position = UDim2.new(1, -30, 0.5, -12.5)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 80)
    CloseBtn.Text = "×"
    CloseBtn.TextColor3 = Color3.new(1, 1, 1)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 16
    CloseBtn.Parent = Header
    
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 4)
    CloseCorner.Parent = CloseBtn
    
    -- Animation List (Compact)
    local AnimationList = Instance.new("ScrollingFrame")
    AnimationList.Size = UDim2.new(1, -10, 1, -40)
    AnimationList.Position = UDim2.new(0, 5, 0, 40)
    AnimationList.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    AnimationList.BorderSizePixel = 0
    AnimationList.ScrollBarThickness = 3
    AnimationList.ScrollBarImageColor3 = Color3.fromRGB(59, 15, 116)
    AnimationList.CanvasSize = UDim2.new(0, 0, 0, 0)
    AnimationList.Parent = MainFrame
    
    local ListCorner = Instance.new("UICorner")
    ListCorner.CornerRadius = UDim.new(0, 6)
    ListCorner.Parent = AnimationList
    
    -- Populate animation list
    local buttons = {}
    local yPos = 0
    
    local function addButton(name, animType, animId)
        local item = Instance.new("TextButton")
        item.Size = UDim2.new(1, -10, 0, 25)
        item.Position = UDim2.new(0, 5, 0, yPos)
        item.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        item.BorderSizePixel = 0
        item.Text = name .. " - " .. animType
        item.TextColor3 = Color3.new(1, 1, 1)
        item.Font = Enum.Font.GothamBold
        item.TextSize = 9
        item.TextXAlignment = Enum.TextXAlignment.Left
        item.Parent = AnimationList
        
        local itemCorner = Instance.new("UICorner")
        itemCorner.CornerRadius = UDim.new(0, 4)
        itemCorner.Parent = item
        
        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 8)
        padding.Parent = item
        
        item.MouseButton1Click:Connect(function()
            SetAnimation(animType, animId)
            PlaySound("Success")
        end)
        
        -- Hover effects
        item.MouseEnter:Connect(function()
            TweenService:Create(item, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(59, 15, 116)
            }):Play()
        end)
        
        item.MouseLeave:Connect(function()
            TweenService:Create(item, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(35, 35, 45)
            }):Play()
        end)
        
        table.insert(buttons, item)
        yPos = yPos + 28
    end
    
    -- Populate all animations
    for name, ids in pairs(Animations.Idle) do
        addButton(name, "Idle", ids)
    end
    for name, id in pairs(Animations.Walk) do
        addButton(name, "Walk", id)
    end
    for name, id in pairs(Animations.Run) do
        addButton(name, "Run", id)
    end
    for name, id in pairs(Animations.Jump) do
        addButton(name, "Jump", id)
    end
    for name, id in pairs(Animations.Fall) do
        addButton(name, "Fall", id)
    end
    for name, id in pairs(Animations.Climb) do
        addButton(name, "Climb", id)
    end
    
    -- Update canvas size
    AnimationList.CanvasSize = UDim2.new(0, 0, 0, yPos)
    
    -- Button functionality
    LoadBtn.MouseButton1Click:Connect(function()
        AnimateButtonClick(LoadBtn)
        LoadSavedAnimations()
        PlaySound("Success")
    end)
    
    ResetBtn.MouseButton1Click:Connect(function()
        AnimateButtonClick(ResetBtn)
        ResetAnimations()
        PlaySound("Toggle")
    end)
    
    CloseBtn.MouseButton1Click:Connect(function()
        AnimateButtonClick(CloseBtn)
        AnimationGUI:Destroy()
        animationGuiOpen = false
        PlaySound("Click")
    end)
    
    -- Search functionality
    SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local query = SearchBox.Text:lower()
        local pos = 0
        for _, btn in ipairs(buttons) do
            if query == "" or btn.Text:lower():find(query, 1, true) then
                btn.Visible = true
                btn.Position = UDim2.new(0, 5, 0, pos)
                pos = pos + 28
            else
                btn.Visible = false
            end
        end
        AnimationList.CanvasSize = UDim2.new(0, 0, 0, pos)
    end)
    
    -- Draggable functionality
    local dragging, dragInput, dragStart, startPos
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)
    
    MainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    MainFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- ========= JUMP BUTTON CONTROL SYSTEM =========
local function HideJumpButton()
    pcall(function()
        StarterGui:SetCore("VRLaserPointerMode", 0)
        StarterGui:SetCore("VREnableControllerModels", false)
        
        local touchGui = player.PlayerGui:FindFirstChild("TouchGui")
        if touchGui then
            local touchControlFrame = touchGui:FindFirstChild("TouchControlFrame")
            if touchControlFrame then
                local jumpButton = touchControlFrame:FindFirstChild("JumpButton")
                if jumpButton then
                    jumpButton.Visible = false
                end
            end
        end
        
        StarterGui:SetCore("TopbarEnabled", false)
    end)
end

local function ShowJumpButton()
    pcall(function()
        StarterGui:SetCore("VRLaserPointerMode", 3)
        StarterGui:SetCore("VREnableControllerModels", true)
        
        local touchGui = player.PlayerGui:FindFirstChild("TouchGui")
        if touchGui then
            local touchControlFrame = touchGui:FindFirstChild("TouchControlFrame")
            if touchControlFrame then
                local jumpButton = touchControlFrame:FindFirstChild("JumpButton")
                if jumpButton then
                    jumpButton.Visible = true
                end
            end
        end
        
        StarterGui:SetCore("TopbarEnabled", true)
    end)
end

local function SaveJumpButtonState()
    originalJumpButtonEnabled = true
end

-- ========= IMPROVED CLIMBING PAUSE FIX =========
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
    
    SaveJumpButtonState()
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

-- ========= FULL USER CONTROL RESTORATION =========
local function RestoreFullUserControl()
    local char = player.Character
    if not char then return end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
    if humanoid then
        humanoid.AutoRotate = true
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = prePauseJumpPower or 50
        humanoid.PlatformStand = false
        humanoid.Sit = false
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end
    
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end
    
    ShowJumpButton()
    
    if ShiftLockEnabled then
        EnableVisibleShiftLock()
    end
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
                Timestamp = lastFrame.Timestamp + 0.05
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
                Timestamp = frame.Timestamp + totalTimeOffset
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
            local pos2 = Vector3.new(frame.Position[1], frame.Position[2], frame.Position[2])
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
    
    UpdateRecordList()
    PlaySound("Success")
end

-- ========= FRAME DATA FUNCTIONS =========
local function GetFrameCFrame(frame)
    local pos = Vector3.new(frame.Position[1], frame.Position[2], frame.Position[3])
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
MainFrame.Position = UDim2.new(0.5, -125, 0.5, -175)
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
Title.Text = "ByaruL"
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
HideButton.Position = UDim2.new(1, -65, 0.5, -12)
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
Content.ScrollBarThickness = 3
Content.ScrollBarImageColor3 = Color3.fromRGB(80, 120, 255)
Content.CanvasSize = UDim2.new(0, 0, 0, 800)
Content.Parent = MainFrame

local MiniButton = Instance.new("TextButton")
MiniButton.Size = UDim2.fromOffset(40, 40)
MiniButton.Position = UDim2.new(0.5, -20, 0, -30)
MiniButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MiniButton.Text = "⚙️"
MiniButton.TextColor3 = Color3.new(1, 1, 1)
MiniButton.Font = Enum.Font.GothamBold
MiniButton.TextSize = 25
MiniButton.Visible = true
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
-- Baris 1: Recording dan Animation Button bersebelahan
local RecordBtnBig = CreateButton("RECORDING", 5, 5, 117, 30, Color3.fromRGB(59, 15, 116))
local AnimationBtnBig = CreateButton("ANIMATIONS", 127, 5, 117, 30, Color3.fromRGB(59, 15, 116))

local PlayBtnBig = CreateButton("PLAY", 5, 40, 75, 30, Color3.fromRGB(59, 15, 116))
local StopBtnBig = CreateButton("STOP", 85, 40, 75, 30, Color3.fromRGB(59, 15, 116))
local PauseBtnBig = CreateButton("PAUSE", 165, 40, 75, 30, Color3.fromRGB(59, 15, 116))

-- Toggle layout: Kiri=AutoLoop, Tengah=InfiniteJump, Kanan=ShiftLock
local LoopBtn, AnimateLoop = CreateToggle("Auto Loop", 0, 75, 78, 22, false)
local JumpBtn, AnimateJump = CreateToggle("Infinite Jump", 82, 75, 78, 22, false)
local ShiftLockBtn, AnimateShiftLock = CreateToggle("ShiftLock", 164, 75, 78, 22, false)

-- Baris kedua: Auto Respawn
local RespawnBtn, AnimateRespawn = CreateToggle("Auto Respawn", 0, 102, 117, 22, false)

local FilenameBox = Instance.new("TextBox")
FilenameBox.Size = UDim2.fromOffset(117, 26)
FilenameBox.Position = UDim2.fromOffset(0, 129)
FilenameBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
FilenameBox.BorderSizePixel = 0
FilenameBox.Text = ""
FilenameBox.PlaceholderText = "Nama File..."
FilenameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
FilenameBox.Font = Enum.Font.GothamBold
FilenameBox.TextSize = 11
FilenameBox.TextXAlignment = Enum.TextXAlignment.Center
FilenameBox.ClearTextOnFocus = false
FilenameBox.Parent = Content

local FilenameCorner = Instance.new("UICorner")
FilenameCorner.CornerRadius = UDim.new(0, 6)
FilenameCorner.Parent = FilenameBox

local SpeedBox = Instance.new("TextBox")
SpeedBox.Size = UDim2.fromOffset(117, 26)
SpeedBox.Position = UDim2.fromOffset(123, 129)
SpeedBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
SpeedBox.BorderSizePixel = 0
SpeedBox.Text = "1.00"
SpeedBox.PlaceholderText = "Speed (0.25-30)..."
SpeedBox.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedBox.Font = Enum.Font.GothamBold
SpeedBox.TextSize = 11
SpeedBox.TextXAlignment = Enum.TextXAlignment.Center
SpeedBox.ClearTextOnFocus = false
SpeedBox.Parent = Content

local SpeedCorner = Instance.new("UICorner")
SpeedCorner.CornerRadius = UDim.new(0, 6)
SpeedCorner.Parent = SpeedBox

local SaveFileBtn = CreateButton("SAVE FILE", 0, 160, 117, 26, Color3.fromRGB(59, 15, 116))
local LoadFileBtn = CreateButton("LOAD FILE", 123, 160, 117, 26, Color3.fromRGB(59, 15, 116))

local PathToggleBtn = CreateButton("RUTE", 0, 191, 117, 26, Color3.fromRGB(59, 15, 116))
local MergeBtn = CreateButton("MERGE", 123, 191, 117, 26, Color3.fromRGB(59, 15, 116))

local RecordList = Instance.new("ScrollingFrame")
RecordList.Size = UDim2.new(1, 0, 1, -222)
RecordList.Position = UDim2.fromOffset(0, 222)
RecordList.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
RecordList.BorderSizePixel = 0
RecordList.ScrollBarThickness = 3
RecordList.ScrollBarImageColor3 = Color3.fromRGB(80, 120, 255)
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

-- ========= RESPONSIVE RESIZE FUNCTIONALITY =========
local IsResizing = false
local StartMousePos
local StartSize

ResizeButton.MouseButton1Down:Connect(function()
    IsResizing = true
    StartMousePos = UserInputService:GetMouseLocation()
    StartSize = MainFrame.Size
end)

UserInputService.TouchStarted:Connect(function(touch, processed)
    if processed then return end
    if touch and ResizeButton:IsDescendantOf(ScreenGui) then
        local touchPos = Vector2.new(touch.Position.X, touch.Position.Y)
        local framePos = MainFrame.AbsolutePosition
        local frameSize = MainFrame.AbsoluteSize
        
        if touchPos.X >= framePos.X + frameSize.X - 50 and 
           touchPos.Y >= framePos.Y + frameSize.Y - 50 then
            IsResizing = true
            StartMousePos = touchPos
            StartSize = MainFrame.Size
        end
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if IsResizing then
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local currentMousePos
            if input.UserInputType == Enum.UserInputType.Touch then
                currentMousePos = Vector2.new(input.Position.X, input.Position.Y)
            else
                currentMousePos = UserInputService:GetMouseLocation()
            end
            
            local delta = currentMousePos - StartMousePos
            
            local newWidth = math.clamp(StartSize.X.Offset + delta.X, 200, 400)
            local newHeight = math.clamp(StartSize.Y.Offset + delta.Y, 200, 400)
            
            MainFrame.Size = UDim2.fromOffset(newWidth, newHeight)
            
            local widthScale = newWidth / 250
            
            RecordBtnBig.Size = UDim2.fromOffset(117 * widthScale, 30)
            AnimationBtnBig.Size = UDim2.fromOffset(117 * widthScale, 30)
            AnimationBtnBig.Position = UDim2.fromOffset(5 + (117 * widthScale) + 5, 5)
            
            PlayBtnBig.Size = UDim2.fromOffset(75 * widthScale, 30)
            StopBtnBig.Size = UDim2.fromOffset(75 * widthScale, 30)
            PauseBtnBig.Size = UDim2.fromOffset(75 * widthScale, 30)
            
            StopBtnBig.Position = UDim2.fromOffset(5 + (75 * widthScale) + 5, 40)
            PauseBtnBig.Position = UDim2.fromOffset(5 + (75 * widthScale) * 2 + 10, 40)
            
            LoopBtn.Size = UDim2.fromOffset(78 * widthScale, 22)
            JumpBtn.Size = UDim2.fromOffset(78 * widthScale, 22)
            ShiftLockBtn.Size = UDim2.fromOffset(78 * widthScale, 22)
            
            JumpBtn.Position = UDim2.fromOffset(5 + (78 * widthScale) + 5, 75)
            ShiftLockBtn.Position = UDim2.fromOffset(5 + (78 * widthScale) * 2 + 10, 75)
            
            RespawnBtn.Size = UDim2.fromOffset(117 * widthScale, 22)
            
            FilenameBox.Size = UDim2.fromOffset(117 * widthScale, 26)
            SpeedBox.Size = UDim2.fromOffset(117 * widthScale, 26)
            SpeedBox.Position = UDim2.fromOffset(5 + (117 * widthScale) + 5, 129)
            
            SaveFileBtn.Size = UDim2.fromOffset(117 * widthScale, 26)
            LoadFileBtn.Size = UDim2.fromOffset(117 * widthScale, 26)
            LoadFileBtn.Position = UDim2.fromOffset(5 + (117 * widthScale) + 5, 160)
            
            PathToggleBtn.Size = UDim2.fromOffset(117 * widthScale, 26)
            MergeBtn.Size = UDim2.fromOffset(117 * widthScale, 26)
            MergeBtn.Position = UDim2.fromOffset(5 + (117 * widthScale) + 5, 191)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        IsResizing = false
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

-- ========= UPDATE RECORD LIST =========
function UpdateRecordList()
    for _, child in pairs(RecordList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local yPos = 0
    for index, name in ipairs(RecordingOrder) do
        local rec = RecordedMovements[name]
        if not rec then continue end
        
        local item = Instance.new("Frame")
        item.Size = UDim2.new(1, -6, 0, 40)
        item.Position = UDim2.new(0, 3, 0, yPos)
        item.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        item.Parent = RecordList
    
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = item
        
        local nameBox = Instance.new("TextBox")
        nameBox.Size = UDim2.new(1, -130, 0, 18)
        nameBox.Position = UDim2.new(0, 8, 0, 4)
        nameBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        nameBox.BorderSizePixel = 0
        nameBox.Text = checkpointNames[name] or "checkpoint"
        nameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameBox.Font = Enum.Font.GothamBold
        nameBox.TextSize = 10
        nameBox.TextXAlignment = Enum.TextXAlignment.Left
        nameBox.PlaceholderText = "Enter name..."
        nameBox.ClearTextOnFocus = false
        nameBox.Parent = item
        
        local nameBoxCorner = Instance.new("UICorner")
        nameBoxCorner.CornerRadius = UDim.new(0, 3)
        nameBoxCorner.Parent = nameBox
        
        local infoLabel = Instance.new("TextLabel")
        infoLabel.Size = UDim2.new(1, -130, 0, 16)
        infoLabel.Position = UDim2.new(0, 8, 0, 22)
        infoLabel.BackgroundTransparency = 1
        if #rec > 0 then
            local totalSeconds = rec[#rec].Timestamp
            infoLabel.Text = FormatDuration(totalSeconds) .. " • " .. #rec .. " frames"
        else
            infoLabel.Text = "0:00 • 0 frames"
        end
        infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        infoLabel.Font = Enum.Font.GothamBold
        infoLabel.TextSize = 8
        infoLabel.TextXAlignment = Enum.TextXAlignment.Left
        infoLabel.Parent = item
        
        local playBtn = Instance.new("TextButton")
        playBtn.Size = UDim2.fromOffset(25, 25)
        playBtn.Position = UDim2.new(1, -110, 0, 7)
        playBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        playBtn.Text = "▶"
        playBtn.TextColor3 = Color3.new(1, 1, 1)
        playBtn.Font = Enum.Font.GothamBold
        playBtn.TextSize = 35
        playBtn.Parent = item
        
        local playCorner = Instance.new("UICorner")
        playCorner.CornerRadius = UDim.new(0, 6)
        playCorner.Parent = playBtn
        
        local upBtn = Instance.new("TextButton")
        upBtn.Size = UDim2.fromOffset(25, 25)
        upBtn.Position = UDim2.new(1, -80, 0, 7)
        upBtn.BackgroundColor3 = index > 1 and Color3.fromRGB(74, 195, 147) or Color3.fromRGB(30, 30, 30)
        upBtn.Text = "↑"
        upBtn.TextColor3 = Color3.new(1, 1, 1)
        upBtn.Font = Enum.Font.GothamBold
        upBtn.TextSize = 35
        upBtn.Parent = item
        
        local upCorner = Instance.new("UICorner")
        upCorner.CornerRadius = UDim.new(0, 6)
        upCorner.Parent = upBtn
        
        local downBtn = Instance.new("TextButton")
        downBtn.Size = UDim2.fromOffset(25, 25)
        downBtn.Position = UDim2.new(1, -50, 0, 7)
        downBtn.BackgroundColor3 = index < #RecordingOrder and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(30, 30, 30)
        downBtn.Text = "↓"
        downBtn.TextColor3 = Color3.new(1, 1, 1)
        downBtn.Font = Enum.Font.GothamBold
        downBtn.TextSize = 35
        downBtn.Parent = item
        
        local downCorner = Instance.new("UICorner")
        downCorner.CornerRadius = UDim.new(0, 6)
        downCorner.Parent = downBtn
        
        local delBtn = Instance.new("TextButton")
        delBtn.Size = UDim2.fromOffset(25, 25)
        delBtn.Position = UDim2.new(1, -20, 0, 7)
        delBtn.BackgroundColor3 = Color3.fromRGB(230, 62, 62)
        delBtn.Text = "x"
        delBtn.TextColor3 = Color3.new(1, 1, 1)
        delBtn.Font = Enum.Font.GothamBold
        delBtn.TextSize = 30
        delBtn.Parent = item
        
        local delCorner = Instance.new("UICorner")
        delCorner.CornerRadius = UDim.new(0, 6)
        delCorner.Parent = delBtn
        
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
            local idx = table.find(RecordingOrder, name)
            if idx then table.remove(RecordingOrder, idx) end
            UpdateRecordList()
        end)
        
        yPos = yPos + 43
    end
    
    RecordList.CanvasSize = UDim2.new(0, 0, 0, yPos)
end

-- ========= JUMP CONTROL FUNCTIONS =========
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
            Timestamp = tick() - CurrentRecording.StartTime
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

-- ========= IMPROVED PLAYBACK SYSTEM WITH VISIBLE SHIFTLOCK =========
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
    currentPlaybackFrame = 1
    playbackStartTime = tick()
    totalPausedDuration = 0
    pauseStartTime = 0

    SaveHumanoidState()
    DisableJump()
    
    HideJumpButton()
    PlaySound("Play")

    playbackConnection = RunService.Heartbeat:Connect(function()
        if not IsPlaying then
            playbackConnection:Disconnect()
            RestoreFullUserControl()
            UpdatePauseMarker()
            return
        end
        
        if IsPaused then
            if pauseStartTime == 0 then
                pauseStartTime = tick()
                RestoreHumanoidState()
                ShowJumpButton()
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
                HideJumpButton()
                UpdatePauseMarker()
            end
        end

        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            IsPlaying = false
            RestoreFullUserControl()
            UpdatePauseMarker()
            return
        end
        
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then
            IsPlaying = false
            RestoreFullUserControl()
            UpdatePauseMarker()
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
            return
        end

        local frame = recording[currentPlaybackFrame]
        if not frame then
            IsPlaying = false
            RestoreFullUserControl()
            UpdatePauseMarker()
            return
        end

        pcall(function()
            hrp.CFrame = GetFrameCFrame(frame)
            hrp.AssemblyLinearVelocity = GetFrameVelocity(frame)
            
            if hum then
                hum.WalkSpeed = GetFrameWalkSpeed(frame) * CurrentSpeed
                hum.AutoRotate = false
                
                local moveState = frame.MoveState
                if moveState == "Climbing" then
                    hum:ChangeState(Enum.HumanoidStateType.Climbing)
                    hum.PlatformStand = false
                    hum.AutoRotate = false
                elseif moveState == "Jumping" then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                    task.spawn(function()
                        wait(0.01)
                        if hum and hum.Parent then
                            hum:ChangeState(Enum.HumanoidStateType.Jumping)
                        end
                    end)
                elseif moveState == "Falling" then
                    hum:ChangeState(Enum.HumanoidStateType.Freefall)
                else
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                end
            end
            
            if ShiftLockEnabled then
                ApplyVisibleShiftLock()
            end
        end)
    end)
    
    AddConnection(playbackConnection)
end

-- ========= FIXED AUTO LOOP SYSTEM - TANPA HENTI =========
function StartAutoLoopAll()
    if not AutoLoop then return end
    
    if #RecordingOrder == 0 then
        AutoLoop = false
        AnimateLoop(false)
        PlaySound("Error")
        return
    end
    
    PlaySound("Play")
    
    CurrentLoopIndex = 1
    IsAutoLoopPlaying = true
    
    loopConnection = task.spawn(function()
        while AutoLoop and IsAutoLoopPlaying do
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
            
            local shouldReset = false
            if AutoRespawn and CurrentLoopIndex == 1 then
                shouldReset = true
            end
            
            if shouldReset then
                ResetCharacter()
                local success = WaitForRespawn()
                if not success then
                    -- Jika respawn gagal, lanjut ke recording berikutnya
                    CurrentLoopIndex = CurrentLoopIndex + 1
                    if CurrentLoopIndex > #RecordingOrder then
                        CurrentLoopIndex = 1
                    end
                    task.wait(1)
                    continue
                end
                
                task.wait(1.5)
            end
            
            -- PERBAIKAN: Jika karakter mati, tunggu respawn dan lanjutkan
            if not IsCharacterReady() then
                local maxWaitTime = 15
                local startWait = tick()
                
                while not IsCharacterReady() and AutoLoop and IsAutoLoopPlaying do
                    if tick() - startWait > maxWaitTime then
                        -- Timeout, lanjut ke recording berikutnya
                        CurrentLoopIndex = CurrentLoopIndex + 1
                        if CurrentLoopIndex > #RecordingOrder then
                            CurrentLoopIndex = 1
                        end
                        break
                    end
                    task.wait(0.5)
                end
                
                if not AutoLoop or not IsAutoLoopPlaying then break end
                
                task.wait(1.0)
            end
            
            if not AutoLoop or not IsAutoLoopPlaying then break end
            
            local playbackCompleted = false
            local playbackStart = tick()
            local playbackPausedTime = 0
            local playbackPauseStart = 0
            local currentFrame = 1
            
            SaveHumanoidState()
            DisableJump()
            
            HideJumpButton()
            
            while AutoLoop and IsAutoLoopPlaying and currentFrame <= #recording do
                if not IsCharacterReady() then
                    -- Karakter mati selama playback, break untuk lanjut ke recording berikutnya
                    break
                end
                
                if IsPaused then
                    if playbackPauseStart == 0 then
                        playbackPauseStart = tick()
                        RestoreHumanoidState()
                        ShowJumpButton()
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
                        HideJumpButton()
                        UpdatePauseMarker()
                    end
                    
                    local char = player.Character
                    if not char or not char:FindFirstChild("HumanoidRootPart") then
                        break
                    end
                    
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if not hum or not hrp then
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
                            hrp.AssemblyLinearVelocity = GetFrameVelocity(frame)
                            
                            if hum then
                                hum.WalkSpeed = GetFrameWalkSpeed(frame) * CurrentSpeed
                                hum.AutoRotate = false
                                
                                local moveState = frame.MoveState
                                if moveState == "Climbing" then
                                    hum:ChangeState(Enum.HumanoidStateType.Climbing)
                                    hum.PlatformStand = false
                                    hum.AutoRotate = false
                                elseif moveState == "Jumping" then
                                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                                    task.spawn(function()
                                        wait(0.01)
                                        if hum and hum.Parent then
                                            hum:ChangeState(Enum.HumanoidStateType.Jumping)
                                        end
                                    end)
                                elseif moveState == "Falling" then
                                    hum:ChangeState(Enum.HumanoidStateType.Freefall)
                                else
                                    hum:ChangeState(Enum.HumanoidStateType.Running)
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
            
            if playbackCompleted then
                PlaySound("Success")
                
                CurrentLoopIndex = CurrentLoopIndex + 1
                if CurrentLoopIndex > #RecordingOrder then
                    CurrentLoopIndex = 1
                end
                
                task.wait(0.5)
            else
                -- Jika playback tidak completed (karakter mati), lanjut ke recording berikutnya
                CurrentLoopIndex = CurrentLoopIndex + 1
                if CurrentLoopIndex > #RecordingOrder then
                    CurrentLoopIndex = 1
                end
                task.wait(0.5)
            end
        end
        
        IsAutoLoopPlaying = false
        IsPaused = false
        RestoreFullUserControl()
        UpdatePauseMarker()
    end)
end

function StopAutoLoopAll()
    AutoLoop = false
    IsAutoLoopPlaying = false
    IsPlaying = false
    IsPaused = false
    
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

function StopPlayback()
    if AutoLoop then
        StopAutoLoopAll()
        AnimateLoop(false)
    end
    
    if not IsPlaying then return end
    IsPlaying = false
    IsPaused = false
    RestoreFullUserControl()
    UpdatePauseMarker()
    
    local char = player.Character
    if char then CompleteCharacterReset(char) end
    
    PlaySound("Stop")
end

function PausePlayback()
    if AutoLoop and IsAutoLoopPlaying then
        IsPaused = not IsPaused
        
        if IsPaused then
            PauseBtnBig.Text = "RESUME"
            PauseBtnBig.BackgroundColor3 = Color3.fromRGB(8, 181, 116)
            RestoreHumanoidState()
            ShowJumpButton()
            if ShiftLockEnabled then
                ApplyVisibleShiftLock()
            end
            UpdatePauseMarker()
            PlaySound("Click")
        else
            PauseBtnBig.Text = "PAUSE"
            PauseBtnBig.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
            SaveHumanoidState()
            DisableJump()
            HideJumpButton()
            UpdatePauseMarker()
            PlaySound("Click")
        end
    elseif IsPlaying then
        IsPaused = not IsPaused
        
        if IsPaused then
            PauseBtnBig.Text = "RESUME"
            PauseBtnBig.BackgroundColor3 = Color3.fromRGB(8, 181, 116)
            RestoreHumanoidState()
            ShowJumpButton()
            if ShiftLockEnabled then
                ApplyVisibleShiftLock()
            end
            UpdatePauseMarker()
            PlaySound("Click")
        else
            PauseBtnBig.Text = "PAUSE"
            PauseBtnBig.BackgroundColor3 = Color3.fromRGB(59, 15, 116)
            SaveHumanoidState()
            DisableJump()
            HideJumpButton()
            UpdatePauseMarker()
            PlaySound("Click")
        end
    end
end

-- ========= FIXED OBFUSCATED JSON SYSTEM =========
local function SaveToObfuscatedJSON()
    local filename = FilenameBox.Text
    if filename == "" then filename = "MyReplays" end
    filename = filename .. ".json"
    
    if not next(RecordedMovements) then
        PlaySound("Error")
        return
    end
    
    local success, err = pcall(function()
        local saveData = {
            Version = "2.0",
            Obfuscated = true,
            Checkpoints = {}
        }
        
        for name, frames in pairs(RecordedMovements) do
            local checkpointData = {
                Name = name,
                DisplayName = checkpointNames[name] or "checkpoint",
                Frames = frames
            }
            table.insert(saveData.Checkpoints, checkpointData)
        end
        
        local obfuscatedData = ObfuscateRecordingData(RecordedMovements)
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
        
        RecordedMovements = {}
        RecordingOrder = {}
        checkpointNames = {}
        
        if saveData.Obfuscated and saveData.ObfuscatedFrames then
            local deobfuscatedData = DeobfuscateRecordingData(saveData.ObfuscatedFrames)
            
            for _, checkpointData in ipairs(saveData.Checkpoints or {}) do
                local name = checkpointData.Name
                local frames = deobfuscatedData[name]
                
                if frames then
                    RecordedMovements[name] = frames
                    table.insert(RecordingOrder, name)
                    checkpointNames[name] = checkpointData.DisplayName or checkpointData.Name
                end
            end
        else
            for _, checkpointData in ipairs(saveData.Checkpoints or {}) do
                local name = checkpointData.Name
                local frames = checkpointData.Frames
                
                if frames then
                    RecordedMovements[name] = frames
                    table.insert(RecordingOrder, name)
                    checkpointNames[name] = checkpointData.DisplayName or checkpointData.Name
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

-- ANIMATION GUI BUTTON
AnimationBtnBig.MouseButton1Click:Connect(function()
    AnimateButtonClick(AnimationBtnBig)
    OpenAnimationGUI()
    PlaySound("Toggle")
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
        if not next(RecordedMovements) then
            AutoLoop = false
            AnimateLoop(false)
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
    ShowJumpButton()
    ScreenGui:Destroy()
end)

-- ========= AUTO-LOAD ANIMATIONS SYSTEM =========
-- This runs independently from GUI state
player.CharacterAdded:Connect(function(character)
    -- Wait 2 seconds for character to fully load
    task.wait(2)
    
    -- Verify character still exists
    if player.Character == character then
        LoadSavedAnimations()
    end
end)

-- === INITIAL LOAD ON SCRIPT EXECUTION ===
-- Auto-load animations when script first runs
task.spawn(function()
    if player.Character then
        task.wait(2)
        LoadSavedAnimations()
    end
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
        if AutoLoop then StartAutoLoopAll() else StopAutoLoopAll() end
    elseif input.KeyCode == Enum.KeyCode.F6 then
        SaveToObfuscatedJSON()
    elseif input.KeyCode == Enum.KeyCode.F5 then
        AutoRespawn = not AutoRespawn
        AnimateRespawn(AutoRespawn)
    elseif input.KeyCode == Enum.KeyCode.F4 then
        ShowPaths = not ShowPaths
        if ShowPaths then
            VisualizeAllPaths()
        else
            ClearPathVisualization()
        end
    elseif input.KeyCode == Enum.KeyCode.F3 then
        ToggleVisibleShiftLock()
        AnimateShiftLock(ShiftLockEnabled)
    elseif input.KeyCode == Enum.KeyCode.F2 then
        ToggleInfiniteJump()
        AnimateJump(InfiniteJump)
    end
end)