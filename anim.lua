-- ✅ Gaze Animations GUI - Advanced Auto Load System
-- By Arull | Modified with Auto Load on Startup & Respawn

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

-- === ANIMATIONS DATABASE (GAZE SYSTEM) ===
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
    ["SwimIdle"] = {
        ["Astronaut"] = "891663592",
        ["Adidas Community"] = "109346520324160",
        ["Bold"] = "16738339817",
        ["Bubbly"] = "910030921",
        ["Cartoony"] = "10921079380",
        ["Catwalk Glam"] = "98854111361360",
        ["Confident"] = "1070012133",
        ["CowBoy"] = "1014411816",
        ["Elder"] = "10921110146",
        ["Mage"] = "707894699",
        ["Ninja"] = "656118341",
        ["NFL"] = "79090109939093",
        ["Patrol"] = "1151221899",
        ["Knight"] = "10921125935",
        ["OldSchool"] = "10921244018",
        ["Levitation"] = "10921139478",
        ["Popstar"] = "1212998578",
        ["Princess"] = "941025398",
        ["Pirate"] = "750785176",
        ["R6"] = "12518152696",
        ["Robot"] = "10921253767",
        ["Sneaky"] = "1132506407",
        ["Sports (Adidas)"] = "18537387180",
        ["Stylish"] = "10921281964",
        ["Stylized"] = "4708190607",
        ["SuperHero"] = "10921297391",
        ["Toy"] = "10921310341",
        ["Vampire"] = "10921325443",
        ["Werewolf"] = "10921341319",
        ["Wicked (Popular)"] = "113199415118199",
        ["No Boundaries (Walmart)"] = "18747071682"
    },
    ["Swim"] = {
        ["Astronaut"] = "891663592",
        ["Adidas Community"] = "133308483266208",
        ["Bubbly"] = "910028158",
        ["Bold"] = "16738339158",
        ["Cartoony"] = "10921079380",
        ["Catwalk Glam"] = "134591743181628",
        ["CowBoy"] = "1014406523",
        ["Confident"] = "1070009914",
        ["Elder"] = "10921108971",
        ["Knight"] = "10921125160",
        ["Mage"] = "707876443",
        ["NFL"] = "132697394189921",
        ["OldSchool"] = "10921243048",
        ["PopStar"] = "1212998578",
        ["Princess"] = "941018893",
        ["Pirate"] = "750784579",
        ["Patrol"] = "1151204998",
        ["R6"] = "12518152696",
        ["Robot"] = "10921253142",
        ["Levitation"] = "10921138209",
        ["Stylish"] = "10921281000",
        ["SuperHero"] = "10921295495",
        ["Sneaky"] = "1132500520",
        ["Sports (Adidas)"] = "18537389531",
        ["Toy"] = "10921309319",
        ["Vampire"] = "10921324408",
        ["Werewolf"] = "10921340419",
        ["Wicked (Popular)"] = "99384245425157",
        ["No Boundaries (Walmart)"] = "18747073181",
        ["Zombie"] = "616165109"
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

-- === DEFAULT ANIMATIONS (R15 Standard) ===
local DefaultAnimations = {
    Idle = {"507766666", "507766951"},
    Walk = "507777826",
    Run = "507767714",
    Jump = "507765000",
    Fall = "507767968",
    Swim = "507784897",
    SwimIdle = "507785072",
    Climb = "507765644"
}

-- === STATE ===
local lastAnimations = {}
local guiOpen = false

-- === UTILS ===
local function StopAllAnims()
    local character = Player.Character
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
    local character = Player.Character
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        end
    end
end

local function SetAnimation(animType, animId)
    local character = Player.Character
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
    elseif animType == "Swim" and animate.swim then
        animate.swim.Swim.AnimationId = "rbxassetid://" .. animId
        lastAnimations.Swim = animId
    elseif animType == "SwimIdle" and animate.swimidle then
        animate.swimidle.SwimIdle.AnimationId = "rbxassetid://" .. animId
        lastAnimations.SwimIdle = animId
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

-- === RESET ANIMATIONS TO DEFAULT ===
local function ResetAnimations()
    local character = Player.Character
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
    if animate.swim then
        animate.swim.Swim.AnimationId = "rbxassetid://" .. DefaultAnimations.Swim
    end
    if animate.swimidle then
        animate.swimidle.SwimIdle.AnimationId = "rbxassetid://" .. DefaultAnimations.SwimIdle
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

-- === ADVANCED LOAD SAVED ANIMATIONS ===
local function LoadSavedAnimations()
    task.spawn(function()
        local character = Player.Character
        if not character then return end
        
        -- Wait for Animate script to fully load with longer timeout
        local animate = character:WaitForChild("Animate", 10)
        if not animate then 
            warn("[AnimHub] Animate script not found!")
            return 
        end
        
        -- Wait for humanoid
        local humanoid = character:WaitForChild("Humanoid", 10)
        if not humanoid then 
            warn("[AnimHub] Humanoid not found!")
            return 
        end
        
        -- Extra wait to ensure all animation children are loaded
        task.wait(0.3)
        
        -- Load saved data
        local success, result = pcall(function()
            if isfile and readfile and isfile("AnimHub_Saved.json") then
                local fileContent = readfile("AnimHub_Saved.json")
                local savedData = HttpService:JSONDecode(fileContent)
                
                if not savedData or type(savedData) ~= "table" then
                    warn("[AnimHub] Invalid save data!")
                    return
                end
                
                -- Apply each animation type with verification
                for animType, animId in pairs(savedData) do
                    task.wait(0.08) -- Small delay between each animation
                    
                    if animType == "Idle" and animate:FindFirstChild("idle") then
                        local idle = animate.idle
                        if idle:FindFirstChild("Animation1") and idle:FindFirstChild("Animation2") then
                            idle.Animation1.AnimationId = "rbxassetid://" .. animId[1]
                            idle.Animation2.AnimationId = "rbxassetid://" .. animId[2]
                        end
                    elseif animType == "Walk" and animate:FindFirstChild("walk") then
                        local walk = animate.walk
                        if walk:FindFirstChild("WalkAnim") then
                            walk.WalkAnim.AnimationId = "rbxassetid://" .. animId
                        end
                    elseif animType == "Run" and animate:FindFirstChild("run") then
                        local run = animate.run
                        if run:FindFirstChild("RunAnim") then
                            run.RunAnim.AnimationId = "rbxassetid://" .. animId
                        end
                    elseif animType == "Jump" and animate:FindFirstChild("jump") then
                        local jump = animate.jump
                        if jump:FindFirstChild("JumpAnim") then
                            jump.JumpAnim.AnimationId = "rbxassetid://" .. animId
                        end
                    elseif animType == "Fall" and animate:FindFirstChild("fall") then
                        local fall = animate.fall
                        if fall:FindFirstChild("FallAnim") then
                            fall.FallAnim.AnimationId = "rbxassetid://" .. animId
                        end
                    elseif animType == "Swim" and animate:FindFirstChild("swim") then
                        local swim = animate.swim
                        if swim:FindFirstChild("Swim") then
                            swim.Swim.AnimationId = "rbxassetid://" .. animId
                        end
                    elseif animType == "SwimIdle" and animate:FindFirstChild("swimidle") then
                        local swimidle = animate.swimidle
                        if swimidle:FindFirstChild("SwimIdle") then
                            swimidle.SwimIdle.AnimationId = "rbxassetid://" .. animId
                        end
                    elseif animType == "Climb" and animate:FindFirstChild("climb") then
                        local climb = animate.climb
                        if climb:FindFirstChild("ClimbAnim") then
                            climb.ClimbAnim.AnimationId = "rbxassetid://" .. animId
                        end
                    end
                end
                
                lastAnimations = savedData
                
                -- Force refresh animations
                task.wait(0.15)
                RefreshCharacter()
                
                print("[AnimHub] Animations loaded successfully!")
            else
                print("[AnimHub] No saved animations found.")
            end
        end)
        
        if not success then
            warn("[AnimHub] Error loading animations: " .. tostring(result))
        end
    end)
end

-- === MAIN GUI FUNCTION ===
local function OpenGUI()
    if guiOpen then return end
    guiOpen = true

    local sg = Instance.new("ScreenGui")
    sg.Name = "GazeAnimGUI"
    sg.ResetOnSpawn = false
    sg.Parent = PlayerGui

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 250, 0, 250)
    main.Position = UDim2.new(0.5, -125, 0.5, -125)
    main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    main.BackgroundTransparency = 0.2
    main.Active = true
    main.ZIndex = 1
    main.Parent = sg

    -- === HEADER (LOAD + SEARCH + RESET + CLOSE) ===
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 35)
    header.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
    header.BackgroundTransparency = 0.3
    header.ZIndex = 2
    header.Parent = main

    -- Load Button (Kiri)
    local loadBtn = Instance.new("TextButton")
    loadBtn.Text = "📂"
    loadBtn.Size = UDim2.new(0, 25, 0, 25)
    loadBtn.Position = UDim2.new(0, 5, 0.5, -12.5)
    loadBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
    loadBtn.BackgroundTransparency = 0.2
    loadBtn.TextColor3 = Color3.new(1, 1, 1)
    loadBtn.Font = Enum.Font.GothamBold
    loadBtn.TextSize = 14
    loadBtn.ZIndex = 4
    loadBtn.Parent = header

    -- Search Box (Tengah)
    local search = Instance.new("TextBox")
    search.Text = ""
    search.PlaceholderText = ""
    search.Size = UDim2.new(0, 80, 0, 25)
    search.Position = UDim2.new(0, 35, 0.5, -12.5)
    search.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    search.BackgroundTransparency = 0.3
    search.TextColor3 = Color3.new(1, 1, 1)
    search.PlaceholderColor3 = Color3.fromRGB(180, 180, 190)
    search.Font = Enum.Font.Gotham
    search.TextSize = 12
    search.ClearTextOnFocus = false
    search.ZIndex = 3
    search.Parent = header

    -- Reset Button
    local resetBtn = Instance.new("TextButton")
    resetBtn.Text = "🔄"
    resetBtn.Size = UDim2.new(0, 25, 0, 25)
    resetBtn.Position = UDim2.new(0, 120, 0.5, -12.5)
    resetBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 50)
    resetBtn.BackgroundTransparency = 0.2
    resetBtn.TextColor3 = Color3.new(1, 1, 1)
    resetBtn.Font = Enum.Font.GothamBold
    resetBtn.TextSize = 14
    resetBtn.ZIndex = 4
    resetBtn.Parent = header

    -- Close Button (Paling Kanan)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Text = "×"
    closeBtn.Size = UDim2.new(0, 25, 0, 25)
    closeBtn.Position = UDim2.new(1, -30, 0.5, -12.5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.ZIndex = 4
    closeBtn.Parent = header

    -- Button Actions
    loadBtn.MouseButton1Click:Connect(function()
        LoadSavedAnimations()
    end)

    resetBtn.MouseButton1Click:Connect(function()
        ResetAnimations()
    end)

    closeBtn.MouseButton1Click:Connect(function()
        sg:Destroy()
        guiOpen = false
    end)

    -- Draggable Logic (Full Body - dari main frame)
    local dragging, dragInput, dragStart, startPos
    main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    main.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    main.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    -- Scrollable List
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -10, 1, -45)
    scroll.Position = UDim2.new(0, 5, 0, 40)
    scroll.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
    scroll.BackgroundTransparency = 0.25
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 5
    scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 170, 255)
    scroll.ZIndex = 2
    scroll.ClipsDescendants = true
    scroll.Parent = main

    local buttons = {}
    local yPos = 0

    local function addButton(name, animType, animId)
        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.Text = name .. " - " .. animType
        btn.Size = UDim2.new(1, -10, 0, 30)
        btn.Position = UDim2.new(0, 5, 0, yPos)
        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
        btn.BackgroundTransparency = 0.2
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 11
        btn.ZIndex = 3
        btn.Parent = scroll
        btn.MouseButton1Click:Connect(function()
            SetAnimation(animType, animId)
        end)
        table.insert(buttons, btn)
        yPos = yPos + 35
    end

    -- Populate Buttons
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
    for name, id in pairs(Animations.SwimIdle) do
        addButton(name, "SwimIdle", id)
    end
    for name, id in pairs(Animations.Swim) do
        addButton(name, "Swim", id)
    end
    for name, id in pairs(Animations.Climb) do
        addButton(name, "Climb", id)
    end

    scroll.CanvasSize = UDim2.new(0, 0, 0, yPos)

    -- Search Filter
    search:GetPropertyChangedSignal("Text"):Connect(function()
        local query = search.Text:lower()
        local pos = 0
        for _, btn in ipairs(buttons) do
            if query == "" or btn.Text:lower():find(query, 1, true) then
                btn.Visible = true
                btn.Position = UDim2.new(0, 5, 0, pos)
                pos = pos + 35
            else
                btn.Visible = false
            end
        end
        scroll.CanvasSize = UDim2.new(0, 0, 0, pos)
    end)
end

-- === AUTO-LOAD SYSTEM (WORKS EVEN WHEN GUI IS CLOSED) ===
-- This runs independently from GUI state
Player.CharacterAdded:Connect(function(character)
    -- Wait 2 seconds for character to fully load
    task.wait(2)
    
    -- Verify character still exists
    if Player.Character == character then
        LoadSavedAnimations()
    end
end)

-- === INITIAL LOAD ON SCRIPT EXECUTION ===
-- Auto-load animations when script first runs
task.spawn(function()
    if Player.Character then
        task.wait(2)
        LoadSavedAnimations()
    end
end)

-- === OPEN GUI NOW ===
OpenGUI()