-- UltimateLib.lua
-- Ultimate Script Library v1.0
-- Auto-update from GitHub

local UltimateLibrary = {}
UltimateLibrary.Version = "1.0.0"

function UltimateLibrary:LoadUI()
    local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
    
    local Window = WindUI:CreateWindow({
        Title = "ByaruL",
        Author = "by Player", 
        Folder = "ultimatescript",
        HideSearchBar = true,
        Size = UDim2.fromOffset(250, 500)
    })

    -- Apply black theme
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
        ElementIcon = Color3.fromHex("#FFFFFF")
    })
    
    WindUI:SetTheme("FullBlack")

    return self:SetupFeatures(Window, WindUI)
end

function UltimateLibrary:SetupFeatures(Window, WindUI)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local LocalPlayer = Players.LocalPlayer

    -- CONFIG MANAGEMENT SYSTEM
    local ConfigManager = Window.ConfigManager
    local CurrentConfigName = "default"
    
    -- CONFIG VARIABLES
    local Config = {
        NoClipEnabled = false,
        InfiniteJumpEnabled = false,
        WalkSpeed = 16,
        ESPEnabled = false,
        JumpDragEnabled = false,
        JumpButtonSize = 80,
        JumpButtonHidden = false
    }

    -- Load config function
    local function LoadConfig()
        Window.CurrentConfig = ConfigManager:CreateConfig(CurrentConfigName)
        if Window.CurrentConfig:Load() then
            for key, value in pairs(Window.CurrentConfig.Data) do
                if Config[key] ~= nil then
                    Config[key] = value
                end
            end
            WindUI:Notify({
                Title = "CONFIG LOADED", 
                Content = "Settings loaded: " .. CurrentConfigName, 
                Duration = 3
            })
            return true
        end
        return false
    end

    -- Save config function
    local function SaveConfig()
        Window.CurrentConfig = ConfigManager:CreateConfig(CurrentConfigName)
        Window.CurrentConfig.Data = Config
        if Window.CurrentConfig:Save() then
            WindUI:Notify({
                Title = "CONFIG SAVED", 
                Content = "Settings saved: " .. CurrentConfigName, 
                Duration = 3
            })
            return true
        end
        return false
    end

    -- VARIABLES
    local ESPEnabled = Config.ESPEnabled
    local ESPConnections = {}
    local ESPFolders = {}

    local NoClipEnabled = Config.NoClipEnabled
    local NoClipConnection = nil

    local InfiniteJumpEnabled = Config.InfiniteJumpEnabled
    local JumpConnection = nil

    local CurrentWalkspeed = Config.WalkSpeed

    local ViewingPlayer = nil
    local OriginalCameraSubject = nil
    local ViewConnection = nil

    -- JUMP BUTTON VARIABLES
    local defaultJumpButton = nil
    local originalJumpSize = nil
    local originalJumpPosition = nil
    local jumpDragEnabled = Config.JumpDragEnabled

    -- ADVANCED ESP SYSTEM
    local function CreateESP(player)
        if ESPFolders[player] then return end
        
        local folder = Instance.new("Folder")
        folder.Name = "ESP_" .. player.Name
        folder.Parent = game:GetService("CoreGui")
        ESPFolders[player] = folder
        
        local connection
        connection = RunService.Heartbeat:Connect(function()
            if not ESPEnabled or not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") or player == LocalPlayer then
                if connection then 
                    connection:Disconnect() 
                end
                if folder then 
                    folder:Destroy() 
                    ESPFolders[player] = nil 
                end
                return
            end
            
            for _, obj in pairs(folder:GetChildren()) do 
                obj:Destroy() 
            end
            
            local rootPart = player.Character.HumanoidRootPart
            
            -- Player Info Billboard
            local billboard = Instance.new("BillboardGui")
            billboard.Name = "PlayerInfo"
            billboard.Adornee = rootPart
            billboard.Size = UDim2.new(0, 80, 0, 30)
            billboard.StudsOffset = Vector3.new(0, 3, 0)
            billboard.AlwaysOnTop = true
            billboard.Parent = folder
            
            local backgroundFrame = Instance.new("Frame")
            backgroundFrame.Size = UDim2.new(1, 0, 1, 0)
            backgroundFrame.Position = UDim2.new(0, 0, 0, 0)
            backgroundFrame.BackgroundColor3 = Color3.new(0, 0, 0)
            backgroundFrame.BackgroundTransparency = 0.4
            backgroundFrame.BorderSizePixel = 0
            backgroundFrame.Parent = billboard
            
            local usernameLabel = Instance.new("TextLabel")
            usernameLabel.Size = UDim2.new(1, 0, 0.33, 0)
            usernameLabel.Position = UDim2.new(0, 0, 0, 0)
            usernameLabel.BackgroundTransparency = 1
            usernameLabel.Text = player.Name
            usernameLabel.TextColor3 = Color3.new(1, 1, 1)
            usernameLabel.TextSize = 10
            usernameLabel.Font = Enum.Font.GothamBold
            usernameLabel.TextStrokeTransparency = 0.8
            usernameLabel.Parent = backgroundFrame
            
            local displayLabel = Instance.new("TextLabel")
            displayLabel.Size = UDim2.new(1, 0, 0.33, 0)
            displayLabel.Position = UDim2.new(0, 0, 0.33, 0)
            displayLabel.BackgroundTransparency = 1
            displayLabel.Text = "@" .. player.DisplayName
            displayLabel.TextColor3 = Color3.new(1, 1, 1)
            displayLabel.TextSize = 8
            displayLabel.Font = Enum.Font.Gotham
            displayLabel.TextStrokeTransparency = 0.8
            displayLabel.Parent = backgroundFrame
            
            local infoLabel = Instance.new("TextLabel")
            infoLabel.Size = UDim2.new(1, 0, 0.34, 0)
            infoLabel.Position = UDim2.new(0, 0, 0.66, 0)
            infoLabel.BackgroundTransparency = 1
            infoLabel.TextColor3 = Color3.new(1, 1, 1)
            infoLabel.TextSize = 7
            infoLabel.Font = Enum.Font.Gotham
            infoLabel.TextStrokeTransparency = 0.8
            infoLabel.Parent = backgroundFrame
            
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local distance = (rootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                infoLabel.Text = math.floor(distance) .. " | ID:" .. player.UserId
            end
            
            local box = Instance.new("BoxHandleAdornment")
            box.Name = "ESPBox"
            box.Adornee = rootPart
            box.AlwaysOnTop = true
            box.ZIndex = 5
            box.Size = Vector3.new(4, 6, 4)
            box.Color3 = Color3.new(1, 1, 1)
            box.Transparency = 0.3
            box.Parent = folder
            
            for i = 1, 6 do
                local line = Instance.new("LineHandleAdornment")
                line.Name = "ESPLine"
                line.Adornee = workspace.Terrain
                line.Color3 = Color3.new(1, 1, 1)
                line.Transparency = 0.4
                line.Thickness = 1
                line.ZIndex = 3
                
                local startPos = rootPart.Position
                local endPos = startPos
                
                if i == 1 then 
                    endPos = startPos + Vector3.new(0, 8, 0)
                elseif i == 2 then 
                    endPos = startPos + Vector3.new(5, 0, 0)
                elseif i == 3 then 
                    endPos = startPos + Vector3.new(-5, 0, 0)
                elseif i == 4 then 
                    endPos = startPos + Vector3.new(0, 0, 5)
                elseif i == 5 then 
                    endPos = startPos + Vector3.new(0, 0, -5)
                elseif i == 6 then 
                    endPos = startPos + Vector3.new(0, -3, 0) 
                end
                
                line.Length = (endPos - startPos).Magnitude
                line.CFrame = CFrame.lookAt(startPos, endPos)
                line.Parent = folder
            end
        end)
        
        ESPConnections[player] = connection
    end

    local function UpdateESP()
        if ESPEnabled then
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then 
                    CreateESP(player) 
                end
            end
            
            Players.PlayerAdded:Connect(function(player)
                if ESPEnabled then 
                    CreateESP(player) 
                end
            end)
        else
            for _, connection in pairs(ESPConnections) do 
                connection:Disconnect() 
            end
            ESPConnections = {}
            
            for _, folder in pairs(ESPFolders) do 
                folder:Destroy() 
            end
            ESPFolders = {}
        end
    end

    -- MOVEMENT FUNCTIONS
    local function NoClipFunction()
        if NoClipEnabled then
            if NoClipConnection then 
                NoClipConnection:Disconnect() 
            end
            
            NoClipConnection = RunService.Stepped:Connect(function()
                if LocalPlayer.Character then
                    for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide then
                            part.CanCollide = false
                        end
                    end
                end
            end)
        else
            if NoClipConnection then 
                NoClipConnection:Disconnect() 
                NoClipConnection = nil 
            end
            
            if LocalPlayer.Character then
                for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                    if part:IsA("BasePart") then 
                        part.CanCollide = true 
                    end
                end
            end
        end
    end

    local function InfiniteJumpFunction()
        if InfiniteJumpEnabled then
            if JumpConnection then 
                JumpConnection:Disconnect() 
            end
            
            JumpConnection = UserInputService.JumpRequest:Connect(function()
                if LocalPlayer.Character then
                    local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    if humanoid then 
                        humanoid:ChangeState("Jumping") 
                    end
                end
            end)
        else
            if JumpConnection then 
                JumpConnection:Disconnect() 
                JumpConnection = nil 
            end
        end
    end

    local function UpdateWalkspeed()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = CurrentWalkspeed
        end
    end

    -- ADVANCED TELEPORT SYSTEM
    local function SafeTeleportToPlayer(playerName)
        local targetPlayer = nil
        
        for _, player in pairs(Players:GetPlayers()) do
            if string.lower(player.Name) == string.lower(playerName) or string.lower(player.DisplayName) == string.lower(playerName) then
                targetPlayer = player
                break
            end
        end
        
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local targetRoot = targetPlayer.Character.HumanoidRootPart
            
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local localRoot = LocalPlayer.Character.HumanoidRootPart
                local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                local originalHealth = humanoid and humanoid.Health or 100
                
                local safeOffset = Vector3.new(0, 5, 0)
                local targetCFrame = targetRoot.CFrame + safeOffset
                
                localRoot.CFrame = targetCFrame
                wait(0.1)
                
                if humanoid then 
                    humanoid.Health = originalHealth 
                end
                
                WindUI:Notify({
                    Title = "TELEPORTED", 
                    Content = "To: " .. targetPlayer.Name, 
                    Duration = 2
                })
                return true
            end
        else
            WindUI:Notify({
                Title = "TELEPORT FAILED", 
                Content = "Player not found", 
                Duration = 2
            })
            return false
        end
    end

    -- SPECTATE SYSTEM
    local function StopViewing()
        if ViewConnection then 
            ViewConnection:Disconnect() 
            ViewConnection = nil 
        end
        
        if OriginalCameraSubject then 
            workspace.CurrentCamera.CameraSubject = OriginalCameraSubject 
            OriginalCameraSubject = nil 
        end
        
        ViewingPlayer = nil
        
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            workspace.CurrentCamera.CameraSubject = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        end
        
        WindUI:Notify({
            Title = "SPECTATE STOPPED", 
            Content = "Back to your character", 
            Duration = 2
        })
        
        return true
    end

    local function ViewPlayer(username)
        if username == "" or username == nil then 
            StopViewing() 
            return 
        end
        
        local targetPlayer = nil
        for _, player in pairs(Players:GetPlayers()) do
            if string.lower(player.Name) == string.lower(username) or string.lower(player.DisplayName) == string.lower(username) then
                targetPlayer = player
                break
            end
        end
        
        if targetPlayer and targetPlayer.Character then
            StopViewing()
            
            ViewingPlayer = targetPlayer
            OriginalCameraSubject = workspace.CurrentCamera.CameraSubject
            
            ViewConnection = RunService.Heartbeat:Connect(function()
                if not ViewingPlayer or not ViewingPlayer.Character or not ViewingPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    StopViewing()
                    return
                end
                
                workspace.CurrentCamera.CameraSubject = ViewingPlayer.Character:FindFirstChildOfClass("Humanoid")
            end)
            
            WindUI:Notify({
                Title = "SPECTATING", 
                Content = targetPlayer.Name, 
                Duration = 3
            })
            
            return true
        else
            WindUI:Notify({
                Title = "PLAYER NOT FOUND", 
                Content = username, 
                Duration = 2
            })
            return false
        end
    end

    -- JUMP BUTTON SYSTEM
    local function FindJumpButton()
        local playerGui = LocalPlayer:WaitForChild("PlayerGui")
        local touchGui = playerGui:FindFirstChild("TouchGui")
        
        if touchGui then
            local touchControlFrame = touchGui:FindFirstChild("TouchControlFrame")
            if touchControlFrame then 
                return touchControlFrame:FindFirstChild("JumpButton") 
            end
        end
        
        return nil
    end

    local function MakeJumpDraggable(button)
        local dragging = false
        local dragInput = nil
        local dragStart = nil
        local startPos = nil
        
        button.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if jumpDragEnabled then
                    dragging = true
                    dragStart = input.Position
                    startPos = button.Position
                    button.ZIndex = 10
                end
            end
        end)
        
        button.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)
        
        UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                button.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            end
        end)
        
        button.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                button.ZIndex = 1
            end
        end)
    end

    local function InitializeJumpButton()
        task.spawn(function()
            task.wait(3)
            defaultJumpButton = FindJumpButton()
            
            if defaultJumpButton then
                originalJumpSize = defaultJumpButton.Size
                originalJumpPosition = defaultJumpButton.Position
                MakeJumpDraggable(defaultJumpButton)
                
                -- Apply saved settings
                if Config.JumpButtonSize then
                    defaultJumpButton.Size = UDim2.new(0, Config.JumpButtonSize, 0, Config.JumpButtonSize)
                end
                if Config.JumpButtonHidden then
                    defaultJumpButton.Visible = not Config.JumpButtonHidden
                end
            end
        end)
    end

    -- GET PLAYER LIST
    local function GetPlayerList()
        local playerList = {}
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local status = "Online"
                if not player.Character then 
                    status = "No Character"
                elseif player.Character:FindFirstChildOfClass("Humanoid") then
                    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                    if humanoid.Health <= 0 then 
                        status = "Dead" 
                    end
                end
                
                table.insert(playerList, {
                    Title = player.Name,
                    Desc = "Display: " .. player.DisplayName .. " | " .. status
                })
            end
        end
        return playerList
    end

    local function RefreshPlayerLists()
        local currentPlayerList = GetPlayerList()
        
        if TeleportDropdown then 
            TeleportDropdown:UpdateValues(currentPlayerList) 
        end
        
        if ViewDropdown then 
            ViewDropdown:UpdateValues(currentPlayerList) 
        end
        
        return true
    end

    -- LOAD EXTERNAL SCRIPTS
    local function LoadExternalScript(url, scriptName)
        local success, result = pcall(function()
            local scriptContent = game:HttpGet(url)
            if scriptContent then
                local loadedScript = loadstring(scriptContent)()
                WindUI:Notify({
                    Title = "SCRIPT LOADED", 
                    Content = scriptName .. " activated!", 
                    Duration = 3
                })
                return true
            end
            return false
        end)
        
        if not success then
            WindUI:Notify({
                Title = "LOAD FAILED", 
                Content = "Failed to load " .. scriptName, 
                Duration = 3
            })
        end
        
        return success
    end

    -- SETUP UI ELEMENTS
    local MainTab = Window:Tab({
        Title = "MAIN FEATURES", 
        Icon = "settings"
    })

    -- MOVEMENT SECTION
    local MovementSection = MainTab:Section({
        Title = "MOVEMENT"
    })
    
    local NoClipToggle = MovementSection:Toggle({
        Title = "NO CLIP", 
        Desc = "Walk through walls", 
        Default = Config.NoClipEnabled,
        Callback = function(state)
            NoClipEnabled = state
            Config.NoClipEnabled = state
            SaveConfig()
            NoClipFunction()
        end
    })
    
    MovementSection:Space()
    
    local InfiniteJumpToggle = MovementSection:Toggle({
        Title = "INFINITE JUMP", 
        Desc = "Jump infinitely", 
        Default = Config.InfiniteJumpEnabled,
        Callback = function(state)
            InfiniteJumpEnabled = state
            Config.InfiniteJumpEnabled = state
            SaveConfig()
            InfiniteJumpFunction()
        end
    })
    
    MovementSection:Space()
    
    local WalkspeedSlider = MovementSection:Slider({
        Title = "WALKSPEED", 
        Desc = "Speed (16-200)", 
        Value = {
            Min = 16, 
            Max = 200, 
            Default = Config.WalkSpeed
        }, 
        Callback = function(value)
            CurrentWalkspeed = value
            Config.WalkSpeed = value
            SaveConfig()
            UpdateWalkspeed()
        end
    })
    
    MovementSection:Space()
    
    MovementSection:Button({
        Title = "RESET WALKSPEED", 
        Desc = "Back to default", 
        Callback = function()
            CurrentWalkspeed = 16
            Config.WalkSpeed = 16
            WalkspeedSlider:Set(16)
            SaveConfig()
            UpdateWalkspeed()
        end
    })

    -- VISUALS SECTION
    local VisualsSection = MainTab:Section({
        Title = "VISUALS"
    })
    
    local ESPToggle = VisualsSection:Toggle({
        Title = "ADVANCED ESP", 
        Desc = "Player ESP with info", 
        Default = Config.ESPEnabled,
        Callback = function(state)
            ESPEnabled = state
            Config.ESPEnabled = state
            SaveConfig()
            UpdateESP()
        end
    })

    -- SPECTATE SECTION
    local SpectateSection = MainTab:Section({
        Title = "SPECTATE"
    })
    
    local ViewDropdown = SpectateSection:Dropdown({
        Title = "SPECTATE PLAYER", 
        Desc = "Select player to watch", 
        Values = GetPlayerList(), 
        Callback = function(option)
            if option and option.Title then 
                ViewPlayer(option.Title) 
            end
        end
    })
    
    SpectateSection:Button({
        Title = "STOP SPECTATING", 
        Desc = "Back to character", 
        Callback = function()
            StopViewing()
            ViewDropdown:Set(nil)
        end
    })
    
    SpectateSection:Button({
        Title = "REFRESH LIST", 
        Desc = "Update player list", 
        Callback = function()
            RefreshPlayerLists()
            WindUI:Notify({
                Title = "LIST UPDATED", 
                Content = "Player list refreshed", 
                Duration = 2
            })
        end
    })

    -- TELEPORT SECTION
    local TeleportSection = MainTab:Section({
        Title = "TELEPORT"
    })
    
    local TeleportDropdown = TeleportSection:Dropdown({
        Title = "TELEPORT TO PLAYER", 
        Desc = "Safe CFrame teleport", 
        Values = GetPlayerList(), 
        Callback = function(option)
            if option and option.Title then 
                SafeTeleportToPlayer(option.Title) 
            end
        end
    })
    
    TeleportSection:Button({
        Title = "REFRESH LIST", 
        Desc = "Update player list", 
        Callback = function()
            RefreshPlayerLists()
            WindUI:Notify({
                Title = "LIST UPDATED", 
                Content = "Player list refreshed", 
                Duration = 2
            })
        end
    })
    
    TeleportSection:Space()
    
    TeleportSection:Button({
        Title = "TELEPORT TO SPAWN", 
        Desc = "Safe spawn teleport", 
        Callback = function()
            if LocalPlayer.Character then 
                LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(0, 50, 0) 
                WindUI:Notify({
                    Title = "TELEPORTED", 
                    Content = "To spawn", 
                    Duration = 2
                }) 
            end 
        end
    })

    -- JUMP BUTTON SECTION
    local JumpButtonSection = MainTab:Section({
        Title = "JUMP BUTTON"
    })
    
    local JumpDragToggle = JumpButtonSection:Toggle({
        Title = "DRAG MODE", 
        Desc = "Drag jump button", 
        Default = Config.JumpDragEnabled,
        Callback = function(state)
            jumpDragEnabled = state
            Config.JumpDragEnabled = state
            SaveConfig()
        end
    })
    
    JumpButtonSection:Space()
    
    local JumpSizeSlider = JumpButtonSection:Slider({
        Title = "BUTTON SIZE", 
        Desc = "Size (50-200)", 
        Value = {
            Min = 50, 
            Max = 200, 
            Default = Config.JumpButtonSize or 80
        }, 
        Callback = function(value)
            if defaultJumpButton then 
                defaultJumpButton.Size = UDim2.new(0, value, 0, value) 
            end
            Config.JumpButtonSize = value
            SaveConfig()
        end
    })
    
    JumpButtonSection:Space()
    
    local JumpHideToggle = JumpButtonSection:Toggle({
        Title = "HIDE BUTTON", 
        Desc = "Show/hide button", 
        Default = Config.JumpButtonHidden,
        Callback = function(state)
            if defaultJumpButton then 
                defaultJumpButton.Visible = not state 
            end
            Config.JumpButtonHidden = state
            SaveConfig()
        end
    })
    
    JumpButtonSection:Space()
    
    JumpButtonSection:Button({
        Title = "RESET BUTTON", 
        Desc = "Default size/position", 
        Callback = function()
            if defaultJumpButton then 
                defaultJumpButton.Size = originalJumpSize 
                defaultJumpButton.Position = originalJumpPosition 
                defaultJumpButton.Visible = true 
                Config.JumpButtonSize = 80
                Config.JumpButtonHidden = false
                SaveConfig()
                JumpSizeSlider:Set(80)
                JumpHideToggle:Set(false)
            end 
        end
    })

    -- CONFIG TAB
    local ConfigTab = Window:Tab({
        Title = "CONFIG", 
        Icon = "save"
    })
    
    local ConfigSection = ConfigTab:Section({
        Title = "CONFIG MANAGEMENT"
    })
    
    local ConfigNameInput = ConfigSection:Input({
        Title = "CONFIG NAME",
        Desc = "Enter config name to save/load",
        Placeholder = "default",
        Callback = function(value)
            CurrentConfigName = value
        end
    })

    -- Get all existing configs
    local allConfigs = ConfigManager:AllConfigs()
    
    ConfigSection:Dropdown({
        Title = "EXISTING CONFIGS",
        Desc = "Select from saved configs",
        Values = allConfigs,
        Callback = function(value)
            CurrentConfigName = value
            ConfigNameInput:Set(value)
        end
    })

    ConfigSection:Space()

    ConfigSection:Button({
        Title = "SAVE CONFIG",
        Desc = "Save current settings",
        Callback = function()
            SaveConfig()
        end
    })

    ConfigSection:Button({
        Title = "LOAD CONFIG", 
        Desc = "Load saved settings",
        Callback = function()
            if LoadConfig() then
                -- Update UI from loaded config
                NoClipToggle:Set(Config.NoClipEnabled)
                InfiniteJumpToggle:Set(Config.InfiniteJumpEnabled)
                WalkspeedSlider:Set(Config.WalkSpeed)
                ESPToggle:Set(Config.ESPEnabled)
                JumpDragToggle:Set(Config.JumpDragEnabled)
                JumpSizeSlider:Set(Config.JumpButtonSize or 80)
                JumpHideToggle:Set(Config.JumpButtonHidden)
                
                -- Apply loaded settings
                NoClipEnabled = Config.NoClipEnabled
                InfiniteJumpEnabled = Config.InfiniteJumpEnabled
                CurrentWalkspeed = Config.WalkSpeed
                ESPEnabled = Config.ESPEnabled
                jumpDragEnabled = Config.JumpDragEnabled
                
                NoClipFunction()
                InfiniteJumpFunction()
                UpdateWalkspeed()
                UpdateESP()
            end
        end
    })

    -- OPEN GUI TAB
    local OpenGuiTab = Window:Tab({
        Title = "OPEN GUI", 
        Icon = "external-link"
    })
    
    local ExternalScriptsSection = OpenGuiTab:Section({
        Title = "EXTERNAL SCRIPTS"
    })
    
    ExternalScriptsSection:Button({
        Title = "LOAD FLY SCRIPT", 
        Desc = "Advanced flying system", 
        Callback = function() 
            LoadExternalScript("https://pastebin.com/raw/t4Et3pw5", "Fly Script") 
        end
    })
    
    ExternalScriptsSection:Space()
    
    ExternalScriptsSection:Button({
        Title = "LOAD ANIMATION GAZE", 
        Desc = "Animation gaze system", 
        Callback = function() 
            LoadExternalScript("https://pastebin.com/raw/np70cuG7", "Animation Gaze") 
        end
    })

    -- AUTO UPDATE SYSTEMS
    Players.PlayerAdded:Connect(function() 
        wait(1) 
        RefreshPlayerLists() 
    end)
    
    Players.PlayerRemoving:Connect(function() 
        wait(1) 
        RefreshPlayerLists() 
    end)
    
    LocalPlayer.CharacterAdded:Connect(function() 
        wait(1) 
        UpdateWalkspeed() 
        if ViewingPlayer then 
            StopViewing() 
        end 
    end)

    -- INITIALIZE & LOAD CONFIG
    UpdateWalkspeed()
    InitializeJumpButton()
    RefreshPlayerLists()
    LoadConfig()

    WindUI:Notify({
        Title = "SCRIPT LOADED", 
        Content = "Ultimate Library Ready! 🚀", 
        Duration = 3
    })

    return Window
end

return UltimateLibrary