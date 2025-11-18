--[[ 
Gaze Animations GUI – ScrollFix + Full-panel Drag (restored)
Perbaikan & fitur (sesuai permintaan):
- Menyimpan pilihan animasi saat dipilih dan memuat kembali saat respawn.
- Menutup GUI meng-set preferensi "permanen" (disimpan ke file) sehingga GUI tidak auto-open saat respawn.
- Mengeksekusi ulang script (run/execute) akan memaksa membuka GUI kembali (override sementara preferensi saved).
- Tombol close -> permanent-close (disimpan). Namun **jika kamu menjalankan/execute script lagi**, GUI akan terbuka kembali otomatis.
- Hotkey reopen (`.`) juga bisa membuka GUI kembali tanpa perlu re-execute.
- Database Animations disediakan sebagai kerangka — ISI SENDIRI nanti.
- Semua UIStroke / stroke / RGB edges dipertahankan.
]]

-- ====== Services ======
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local HttpService = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- ====== KONFIG (persisten) ======
local CONFIG_FILE = "AnimHub_Config.json"
local SAVE_FILE   = "AnimHub_Saved.json"

local Config = { GuiClosed = false }

local function loadConfig()
    pcall(function()
        if isfile and isfile(CONFIG_FILE) then
            local t = HttpService:JSONDecode(readfile(CONFIG_FILE))
            if typeof(t)=="table" and type(t.GuiClosed)=="boolean" then Config = t end
        end
    end)
end

local function saveConfig()
    pcall(function()
        if writefile then writefile(CONFIG_FILE, HttpService:JSONEncode(Config)) end
    end)
end

-- ====== Behavior: Force-open when THIS script is executed ======
-- Penjelasan singkat:
-- * Saat script ini dijalankan, kita ingin GUI muncul walau sebelumnya user men-`close` dan menyimpannya.
-- * Oleh karena itu kita set Config.GuiClosed = false & saveConfig() sekali pada run ini agar GUI terbuka.
-- * Namun ketika user menekan tombol close, kita tetap menyimpan GuiClosed = true agar respawn berikutnya tidak auto-open.
local FUNCTIONAL_FORCE_OPEN_ON_RUN = true

-- ====== Patch: (legacy) optional global flag support ======
if _G.AnimHubForceOpen == nil then _G.AnimHubForceOpen = true end

-- ====== DATABASE (KERANGKA) ======
-- Isi tabel berikut dengan animID (string atau {id1,id2} untuk Idle double)
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
        ["(UGC) TailWag"] = {"129026910898635", "129026910898635"},
        ["WICKED DANCING"] = {"4128695", "82682578794949"},
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

-- ====== State ======
local guiOpen = false
local lastAnimations = {}

-- ====== Utils ======
local function validateCharacter()
    local c = Player.Character
    return c and c:FindFirstChildOfClass("Humanoid") and c:FindFirstChild("HumanoidRootPart")
end

local function preloadAnimation(animIdAny)
    local ids = (type(animIdAny)=="table") and animIdAny or {animIdAny}
    local assets = {}
    for _,id in ipairs(ids) do
        if id and tostring(id)~="" then
            local a = Instance.new("Animation")
            a.AnimationId = "rbxassetid://"..tostring(id)
            table.insert(assets, a)
        end
    end
    pcall(function()
        if #assets>0 then ContentProvider:PreloadAsync(assets) end
    end)
end

local function stopAllTracks(h)
    for _,t in ipairs(h:GetPlayingAnimationTracks()) do
        pcall(function() t:Stop(0.12) end)
    end
end

local function softKickAnimate(h)
    h:Move(Vector3.new(), true)
    task.wait(0.04)
    h:Move(Vector3.new(0.05,0,0), true)
    task.wait(0.04)
    h:Move(Vector3.new(), true)
end

local function saveLast()
    pcall(function() if writefile then writefile(SAVE_FILE, HttpService:JSONEncode(lastAnimations)) end end)
end

-- ====== Apply Animation ======
local function setAnim(kind, id)
    if not validateCharacter() then return false end
    if not id or id=="" then return false end

    local c = Player.Character
    local h = c:FindFirstChildOfClass("Humanoid")
    local anim = c:FindFirstChild("Animate")
    if not h or not anim then return false end

    pcall(function() preloadAnimation(id) end)
    stopAllTracks(h)

    local ok = true
    if     kind=="Idle"     and anim.idle      then 
        if type(id)~="table" then ok = false else
            anim.idle.Animation1.AnimationId="rbxassetid://"..id[1]; anim.idle.Animation2.AnimationId="rbxassetid://"..id[2]; lastAnimations.Idle = id
        end
    elseif kind=="Walk"     and anim.walk      then anim.walk.WalkAnim.AnimationId   ="rbxassetid://"..id;   lastAnimations.Walk = id
    elseif kind=="Run"      and anim.run       then anim.run.RunAnim.AnimationId     ="rbxassetid://"..id;   lastAnimations.Run  = id
    elseif kind=="Jump"     and anim.jump      then anim.jump.JumpAnim.AnimationId   ="rbxassetid://"..id;   lastAnimations.Jump = id
    elseif kind=="Fall"     and anim.fall      then anim.fall.FallAnim.AnimationId   ="rbxassetid://"..id;   lastAnimations.Fall = id
    elseif kind=="Swim"     and anim.swim      then anim.swim.Swim.AnimationId       ="rbxassetid://"..id;   lastAnimations.Swim = id
    elseif kind=="SwimIdle" and anim.swimidle  then anim.swimidle.SwimIdle.AnimationId="rbxassetid://"..id;  lastAnimations.SwimIdle = id
    elseif kind=="Climb"    and anim.climb     then anim.climb.ClimbAnim.AnimationId ="rbxassetid://"..id;   lastAnimations.Climb = id
    else ok=false end

    task.wait(0.08)
    softKickAnimate(h)
    if ok then saveLast() end
    return ok
end

-- ====== Load saved saat respawn ======
local function loadSaved()
    if not validateCharacter() then return end
    pcall(function()
        if isfile and isfile(SAVE_FILE) then
            local t = HttpService:JSONDecode(readfile(SAVE_FILE))
            if typeof(t)=="table" then lastAnimations = t for k,v in pairs(t) do setAnim(k,v) end end
        end
    end)
end

-- ====== GUI ======
local RGBConfig = {
    ENABLED = true, STROKE_THICKNESS = 2, CYCLE_SPEED = 3.0,
    MOVE_SPEED = 160, EDGE_LENGTH = 64, PULSE_INTENSITY = 0.35,
    PULSE_BASE = 0.7, TEXT_SIZE = 18, EDGE_COUNT = 4
}

local function openGUI()
    if guiOpen or Config.GuiClosed then return end
    if not validateCharacter() then return end
    guiOpen = true

    local existing = PlayerGui:FindFirstChild("GazeAnimGUI_Simple")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "GazeAnimGUI_Simple"
    sg.ResetOnSpawn = false
    sg.Parent = PlayerGui

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0,200,0,200)
    main.Position = UDim2.new(0.5,-100,0.5,-100)
    main.BackgroundColor3 = Color3.fromRGB(10,10,10)
    main.BorderSizePixel = 0
    main.Active = true
    main.Parent = sg
    Instance.new("UICorner", main).CornerRadius = UDim.new(0,12)

    local stroke = Instance.new("UIStroke", main)
    stroke.Color = Color3.fromRGB(35,35,35)
    stroke.Thickness=1

    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1,0,0,30)
    header.BackgroundColor3 = Color3.fromRGB(12,12,12)
    header.BorderSizePixel = 0
    header.Parent = main
    Instance.new("UICorner", header).CornerRadius = UDim.new(0,12)

    local search = Instance.new("TextBox")
    search.PlaceholderText = "Cari animasi..."
    search.Text = ""
    search.ClearTextOnFocus = false
    search.Size = UDim2.new(1,-70,1,-10)
    search.Position = UDim2.new(0,8,0,5)
    search.BackgroundColor3 = Color3.fromRGB(18,18,18)
    search.TextColor3 = Color3.fromRGB(220,220,220)
    search.PlaceholderColor3 = Color3.fromRGB(120,120,120)
    search.Font = Enum.Font.Gotham
    search.TextSize = 12
    search.BorderSizePixel = 0
    search.Parent = header
    Instance.new("UICorner", search).CornerRadius = UDim.new(0,8)

    local close = Instance.new("TextButton")
    close.Text = "X"
    close.Font = Enum.Font.GothamBold
    close.TextSize = 16
    close.TextColor3 = Color3.fromRGB(255,120,120)
    close.Size = UDim2.new(0,28,0,22)
    close.Position = UDim2.new(1,-34,0,4)
    close.BackgroundColor3 = Color3.fromRGB(30,10,10)
    close.BorderSizePixel = 0
    close.Parent = header
    Instance.new("UICorner", close).CornerRadius = UDim.new(0,8)

    -- IMPORTANT: close menyimpan preferensi "permanen" (GuiClosed = true)
    close.MouseButton1Click:Connect(function()
        Config.GuiClosed = true
        saveConfig()            -- simpan preferensi; respawn selanjutnya tidak auto-open
        sg:Destroy()
        guiOpen = false
    end)

    -- List (fixed canvas sizing)
    local list = Instance.new("ScrollingFrame")
    list.Size = UDim2.new(1,-8,1,-38)
    list.Position = UDim2.new(0,4,0,34)
    list.BackgroundColor3 = Color3.fromRGB(14,14,14)
    list.ScrollBarThickness = 4
    list.BorderSizePixel = 0
    list.Parent = main
    Instance.new("UICorner", list).CornerRadius = UDim.new(0,10)
    local ls = Instance.new("UIStroke", list); ls.Color=Color3.fromRGB(32,32,32); ls.Thickness=1

    -- UIListLayout
    local layout = Instance.new("UIListLayout", list)
    layout.Padding = UDim.new(0,6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    -- Robust refreshCanvas: wait until AbsoluteContentSize stabilizes (or timeout)
    local function refreshCanvas()
        local prev = -1
        local stableCount = 0
        for i=1,12 do
            task.wait()
            local h = layout.AbsoluteContentSize.Y
            if h == prev then
                stableCount = stableCount + 1
                if stableCount >= 2 then break end
            else
                stableCount = 0
                prev = h
            end
        end
        local finalH = math.max(0, layout.AbsoluteContentSize.Y)
        local pad = 12
        list.CanvasSize = UDim2.new(0, 0, 0, finalH + pad)
    end

    -- ensure refresh when layout content changes
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        task.spawn(refreshCanvas)
    end)

    -- initial population and helpers
    local buttons = {}
    local index = 0
    local function addBtn(label, kind, id)
        index = index + 1
        local b=Instance.new("TextButton")
        b.Size=UDim2.new(1,-8,0,24)
        b.LayoutOrder = index
        b.BackgroundColor3=Color3.fromRGB(20,20,20)
        b.TextColor3=Color3.fromRGB(220,220,220)
        b.Font=Enum.Font.Gotham
        b.TextSize=11
        b.TextXAlignment=Enum.TextXAlignment.Left
        b.BorderSizePixel=0
        b.Text = label.."  •  "..kind
        b.Parent=list
        Instance.new("UICorner", b).CornerRadius=UDim.new(0,8)
        local pad=Instance.new("UIPadding", b); pad.PaddingLeft=UDim.new(0,8)
        Instance.new("UIStroke", b).Color=Color3.fromRGB(35,35,35)

        b.MouseButton1Click:Connect(function()
            -- suppress click if drag in progress is using attribute (handled in drag)
            if b:GetAttribute("SuppressClick") then return end
            local ok = setAnim(kind,id)
            b.BackgroundColor3 = ok and Color3.fromRGB(18,45,110) or Color3.fromRGB(80,20,20)
            task.wait(0.18)
            b.BackgroundColor3 = Color3.fromRGB(20,20,20)
        end)

        table.insert(buttons, b)
    end

    local function clearButtons()
        for _,v in ipairs(buttons) do
            if v and v.Parent then v:Destroy() end
        end
        buttons = {}
        index = 0
    end

    -- populate buttons from Animations skeleton (no IDs)
    local function populateButtons()
        clearButtons()
        for n,i in pairs(Animations.Idle) do addBtn(n,"Idle", i) end
        for n,i in pairs(Animations.Walk) do addBtn(n,"Walk", i) end
        for n,i in pairs(Animations.Run) do addBtn(n,"Run", i) end
        for n,i in pairs(Animations.Jump) do addBtn(n,"Jump", i) end
        for n,i in pairs(Animations.Fall) do addBtn(n,"Fall", i) end
        for n,i in pairs(Animations.SwimIdle) do addBtn(n,"SwimIdle", i) end
        for n,i in pairs(Animations.Swim) do addBtn(n,"Swim", i) end
        for n,i in pairs(Animations.Climb) do addBtn(n,"Climb", i) end

        task.spawn(refreshCanvas)
    end

    populateButtons()

    -- ====== RGB Edges Integration (kept) ======
    local rgbConn = nil
    local edgeFrames = {}
    local MAIN_W = 200
    local MAIN_H = 200

    if RGBConfig.ENABLED then
        local globalStroke = stroke
        globalStroke.Thickness = RGBConfig.STROKE_THICKNESS

        for i = 1, RGBConfig.EDGE_COUNT do
            local e = Instance.new("Frame")
            e.Name = "RGB_Edge"..i
            e.Size = UDim2.fromOffset(RGBConfig.EDGE_LENGTH, RGBConfig.STROKE_THICKNESS*2)
            e.AnchorPoint = Vector2.new(0.5, 0.5)
            e.BackgroundColor3 = Color3.fromHSV(0,1,1)
            e.BorderSizePixel = 0
            e.ZIndex = main.ZIndex + 1
            e.Parent = main
            local ec = Instance.new("UICorner")
            ec.CornerRadius = UDim.new(0, 6)
            ec.Parent = e
            table.insert(edgeFrames, e)
        end

        local perimeter = (MAIN_W * 2) + (MAIN_H * 2)
        local function placeSegment(segment, p, length)
            p = p % perimeter
            if p <= MAIN_W then
                local centerX = p
                segment.Rotation = 0
                segment.Size = UDim2.fromOffset(length, RGBConfig.STROKE_THICKNESS*2)
                segment.AnchorPoint = Vector2.new(0.5, 0)
                segment.Position = UDim2.new(0, centerX, 0, -RGBConfig.STROKE_THICKNESS)
                return
            end
            p = p - MAIN_W
            if p <= MAIN_H then
                local centerY = p
                segment.Rotation = 90
                segment.Size = UDim2.fromOffset(length, RGBConfig.STROKE_THICKNESS*2)
                segment.AnchorPoint = Vector2.new(1, 0.5)
                segment.Position = UDim2.new(0, MAIN_W + RGBConfig.STROKE_THICKNESS, 0, centerY)
                return
            end
            p = p - MAIN_H
            if p <= MAIN_W then
                local centerX = MAIN_W - p
                segment.Rotation = 0
                segment.Size = UDim2.fromOffset(length, RGBConfig.STROKE_THICKNESS*2)
                segment.AnchorPoint = Vector2.new(0.5, 1)
                segment.Position = UDim2.new(0, centerX, 0, MAIN_H + RGBConfig.STROKE_THICKNESS)
                return
            end
            p = p - MAIN_W
            local centerY = MAIN_H - p
            segment.Rotation = 90
            segment.Size = UDim2.fromOffset(length, RGBConfig.STROKE_THICKNESS*2)
            segment.AnchorPoint = Vector2.new(0, 0.5)
            segment.Position = UDim2.new(0, -RGBConfig.STROKE_THICKNESS, 0, centerY)
        end

        local edgePos = 0
        local startTick = tick()

        rgbConn = RunService.RenderStepped:Connect(function(dt)
            local t = tick() - startTick
            local hue = (t * RGBConfig.CYCLE_SPEED) % 1
            local angle = hue * math.pi * 2
            local rawPulse = (math.sin(angle) + 1) / 2
            local pulse = RGBConfig.PULSE_BASE + (rawPulse * RGBConfig.PULSE_INTENSITY)

            pcall(function()
                globalStroke.Color = Color3.fromHSV(hue, 1, 1)
            end)

            edgePos = (edgePos + RGBConfig.MOVE_SPEED * dt) % perimeter

            for i = 1, #edgeFrames do
                local offset = perimeter * ((i-1) / RGBConfig.EDGE_COUNT)
                local pos = (edgePos + offset) % perimeter

                local pieceHue = (hue + (i-1) * 0.04) % 1
                local c = Color3.fromHSV(pieceHue, 1, 1)

                local dynamicLength = RGBConfig.EDGE_LENGTH * (0.8 + (pulse - RGBConfig.PULSE_BASE) * 0.6)
                placeSegment(edgeFrames[i], pos, dynamicLength)

                edgeFrames[i].BackgroundColor3 = c
                edgeFrames[i].Visible = true
                edgeFrames[i].BackgroundTransparency = 0
                edgeFrames[i].Size = UDim2.fromOffset(dynamicLength, RGBConfig.STROKE_THICKNESS * (1 + (pulse - RGBConfig.PULSE_BASE) * 1.2))
            end
        end)

        sg.Destroying:Connect(function()
            if rgbConn then rgbConn:Disconnect(); rgbConn = nil end
        end)
    end

    -- connect search filtering (and refresh canvas after)
    search:GetPropertyChangedSignal("Text"):Connect(function()
        local q=string.lower(search.Text)
        for _,b in ipairs(buttons) do
            local show = (q=="" or string.find(string.lower(b.Text), q, 1, true)~=nil)
            b.Visible=show
        end
        task.spawn(refreshCanvas)
    end)

    -- Also re-run refreshCanvas if children removed/added externally
    list.ChildRemoved:Connect(function() task.spawn(refreshCanvas) end)
    list.ChildAdded:Connect(function() task.spawn(refreshCanvas) end)

    -- ====== FULL-PANEL DRAG (RESTORED) ======
    do
        local dragArmed, dragging = false, false
        local dragStart, startPos
        local DRAG_THRESHOLD = 8 -- ubah kalau mau sensitivity lain
        local activeButton = nil

        local function begin(i)
            if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then return end
            local p = Vector2.new(i.Position.X, i.Position.Y)
            -- hanya mulai drag jika pointer awal berada di atas main frame
            local pos, size = main.AbsolutePosition, main.AbsoluteSize
            if not (p.X >= pos.X and p.X <= pos.X + size.X and p.Y >= pos.Y and p.Y <= pos.Y + size.Y) then return end

            dragArmed = true
            dragging = false
            dragStart = i.Position
            startPos = main.Position
            activeButton = (i.Target and i.Target:IsA("TextButton")) and i.Target or nil
        end

        local function update(i)
            if not dragArmed then return end
            if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
            local d = i.Position - dragStart
            if not dragging and (math.abs(d.X) + math.abs(d.Y) >= DRAG_THRESHOLD) then
                dragging = true
                if activeButton then activeButton:SetAttribute("SuppressClick", true) end
            end
            if dragging then
                main.Position = UDim2.fromOffset(startPos.X.Offset + d.X, startPos.Y.Offset + d.Y)
            end
        end

        local function finish(i)
            if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then return end
            dragArmed, dragging = false, false
            if activeButton then activeButton:SetAttribute("SuppressClick", nil); activeButton = nil end
            -- clamp to viewport (keep on screen) — attempt to keep similar center
            local vs = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920,1080)
            local absPos = main.AbsolutePosition
            local absSize = main.AbsoluteSize
            local x = math.clamp(absPos.X, 0, vs.X - absSize.X)
            local y = math.clamp(absPos.Y, 0, vs.Y - absSize.Y)
            main.Position = UDim2.fromOffset(x, y)
        end

        -- Listen on gui so clicks inside children still register as begin
        main.InputBegan:Connect(begin)
        UIS.InputChanged:Connect(update)
        UIS.InputEnded:Connect(finish)
    end

end

-- ====== Startup / Respawn ======
loadConfig()

-- Force-open on this execution if requested (this makes re-executing the script reopen GUI)
if FUNCTIONAL_FORCE_OPEN_ON_RUN or _G.AnimHubForceOpen then
    Config.GuiClosed = false
    saveConfig()
    _G.AnimHubForceOpen = false
end

Player.CharacterAdded:Connect(function()
    task.defer(function()
        task.wait(1.1)
        loadSaved()
        if not Config.GuiClosed then openGUI() end
    end)
end)

task.defer(function()
    task.wait(0.8)
    if validateCharacter() and not Config.GuiClosed then openGUI() end
end)

-- ====== Re-Open Hotkey ======
do
    local REOPEN_KEY = Enum.KeyCode.Period
    UIS.InputBegan:Connect(function(input,gp)
        if gp then return end
        if input.UserInputType==Enum.UserInputType.Keyboard and input.KeyCode==REOPEN_KEY then
            if Config.GuiClosed then Config.GuiClosed=false saveConfig() end
            if not guiOpen then openGUI() end
        end
    end)
end