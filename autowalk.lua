-- Modern UI Library - Mobile Friendly (No Conflicts!) dengan Execute System
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")

local SimpleUI = {
    Tabs = {},
    CurrentTab = nil,
    Connections = {}
}

function SimpleUI:AddConnection(connection)
    table.insert(self.Connections, connection)
    return connection
end

function SimpleUI:Cleanup()
    for _, connection in pairs(self.Connections) do
        if connection then
            pcall(function() connection:Disconnect() end)
        end
    end
    self.Connections = {}
end

-- Helper function untuk execute system
local function getTextBoxText(textboxObj)
    return textboxObj and textboxObj:Get() or ""
end

-- Safe execution function
function SimpleUI:SafeExecute(code, isURL)
    local success, result = pcall(function()
        if isURL then
            return loadstring(game:HttpGet(code, true))()
        else
            return loadstring(code)()
        end
    end)
    
    return success, result
end

-- Create ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MobileUI_" .. HttpService:GenerateGUID(false)
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = game.CoreGui

-- Main Window (300x400) - Sedikit lebih tinggi untuk fitur baru
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 300, 0, 400)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BackgroundTransparency = 0.05
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = false
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(60, 60, 60)
UIStroke.Thickness = 2
UIStroke.Parent = MainFrame

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 35)
Header.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Header.BorderSizePixel = 0
Header.Active = true
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 10)
HeaderCorner.Parent = Header

local HeaderFix = Instance.new("Frame")
HeaderFix.Size = UDim2.new(1, 0, 0, 10)
HeaderFix.Position = UDim2.new(0, 0, 1, -10)
HeaderFix.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
HeaderFix.BorderSizePixel = 0
HeaderFix.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0, 180, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "🎮 EXECUTE UI"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

-- Control Buttons
local Controls = Instance.new("Frame")
Controls.Size = UDim2.new(0, 60, 1, 0)
Controls.Position = UDim2.new(1, -65, 0, 0)
Controls.BackgroundTransparency = 1
Controls.Parent = Header

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 25, 0, 25)
MinimizeBtn.Position = UDim2.new(0, 3, 0.5, -12.5)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
MinimizeBtn.Text = "_"
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 14
MinimizeBtn.BorderSizePixel = 0
MinimizeBtn.AutoButtonColor = false
MinimizeBtn.Parent = Controls

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinimizeBtn

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 25, 0, 25)
CloseBtn.Position = UDim2.new(0, 32, 0.5, -12.5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.BorderSizePixel = 0
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = Controls

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

-- Tab Container
local TabContainer = Instance.new("ScrollingFrame")
TabContainer.Size = UDim2.new(1, -16, 0, 30)
TabContainer.Position = UDim2.new(0, 8, 0, 40)
TabContainer.BackgroundTransparency = 1
TabContainer.BorderSizePixel = 0
TabContainer.ScrollBarThickness = 0
TabContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
TabContainer.AutomaticCanvasSize = Enum.AutomaticSize.X
TabContainer.ScrollingDirection = Enum.ScrollingDirection.X
TabContainer.Parent = MainFrame

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.Padding = UDim.new(0, 4)
TabLayout.Parent = TabContainer

-- Content Container
local ContentContainer = Instance.new("ScrollingFrame")
ContentContainer.Size = UDim2.new(1, -16, 1, -80)
ContentContainer.Position = UDim2.new(0, 8, 0, 75)
ContentContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
ContentContainer.BackgroundTransparency = 0.1
ContentContainer.BorderSizePixel = 0
ContentContainer.ScrollBarThickness = 5
ContentContainer.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
ContentContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
ContentContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
ContentContainer.ScrollingDirection = Enum.ScrollingDirection.Y
ContentContainer.Parent = MainFrame

local ContentCorner = Instance.new("UICorner")
ContentCorner.CornerRadius = UDim.new(0, 8)
ContentCorner.Parent = ContentContainer

-- Mini Button (Centered Top)
local MiniButton = Instance.new("TextButton")
MiniButton.Size = UDim2.new(0, 45, 0, 45)
MiniButton.Position = UDim2.new(0.5, -22.5, 0, 10)
MiniButton.AnchorPoint = Vector2.new(0, 0)
MiniButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MiniButton.Text = "⚙️"
MiniButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MiniButton.Font = Enum.Font.GothamBold
MiniButton.TextSize = 18
MiniButton.Visible = false
MiniButton.ZIndex = 10
MiniButton.Active = true
MiniButton.BorderSizePixel = 0
MiniButton.Parent = ScreenGui

local MiniCorner = Instance.new("UICorner")
MiniCorner.CornerRadius = UDim.new(0, 10)
MiniCorner.Parent = MiniButton

local MiniStroke = Instance.new("UIStroke")
MiniStroke.Color = Color3.fromRGB(60, 60, 60)
MiniStroke.Thickness = 2
MiniStroke.Parent = MiniButton

-- DRAG SYSTEM (Mobile-Friendly, Only for Header and MiniButton)
local dragData = {
    active = false,
    object = nil,
    input = nil,
    startPos = nil
}

local function startDrag(input, object)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragData.active = true
        dragData.object = object
        dragData.input = input
        dragData.startPos = object.Position
    end
end

local function updateDrag(input)
    if not dragData.active or not dragData.object then return end
    
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - dragData.input.Position
        dragData.object.Position = UDim2.new(
            dragData.startPos.X.Scale,
            dragData.startPos.X.Offset + delta.X,
            dragData.startPos.Y.Scale,
            dragData.startPos.Y.Offset + delta.Y
        )
    end
end

local function endDrag(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragData.active = false
        dragData.object = nil
    end
end

SimpleUI:AddConnection(Header.InputBegan:Connect(function(input)
    startDrag(input, MainFrame)
end))

SimpleUI:AddConnection(MiniButton.InputBegan:Connect(function(input)
    startDrag(input, MiniButton)
end))

SimpleUI:AddConnection(UserInputService.InputChanged:Connect(updateDrag))
SimpleUI:AddConnection(UserInputService.InputEnded:Connect(endDrag))

-- Minimize/Restore
local isMinimized = false

local function restoreUI()
    MiniButton.Visible = false
    MainFrame.Visible = true
    MainFrame.Size = UDim2.new(0, 0, 0, 0)
    
    TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 300, 0, 400)
    }):Play()
    isMinimized = false
end

MinimizeBtn.MouseButton1Click:Connect(function()
    if not isMinimized then
        TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0)
        }):Play()
        task.wait(0.3)
        MainFrame.Visible = false
        MiniButton.Visible = true
        MiniButton.Position = UDim2.new(0.5, -22.5, 0, 10)
        isMinimized = true
    else
        restoreUI()
    end
end)

MiniButton.MouseButton1Click:Connect(function()
    if isMinimized then
        restoreUI()
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0)
    }):Play()
    TweenService:Create(MiniButton, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0)
    }):Play()
    task.wait(0.3)
    SimpleUI:Cleanup()
    ScreenGui:Destroy()
end)

-- TAB SYSTEM
function SimpleUI:AddTab(tabName)
    local tabButton = Instance.new("TextButton")
    tabButton.Size = UDim2.new(0, 70, 1, 0)
    tabButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    tabButton.Text = tabName
    tabButton.TextColor3 = Color3.fromRGB(180, 180, 180)
    tabButton.Font = Enum.Font.GothamBold
    tabButton.TextSize = 11
    tabButton.BorderSizePixel = 0
    tabButton.AutoButtonColor = false
    tabButton.Parent = TabContainer
    
    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 6)
    tabCorner.Parent = tabButton
    
    local tabContent = Instance.new("Frame")
    tabContent.Size = UDim2.new(1, 0, 0, 0)
    tabContent.BackgroundTransparency = 1
    tabContent.Visible = false
    tabContent.Parent = ContentContainer
    
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.Padding = UDim.new(0, 8)
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Parent = tabContent
    
    local tabPadding = Instance.new("UIPadding")
    tabPadding.PaddingTop = UDim.new(0, 5)
    tabPadding.PaddingBottom = UDim.new(0, 5)
    tabPadding.Parent = tabContent
    
    local tab = {
        Name = tabName,
        Button = tabButton,
        Content = tabContent
    }
    
    table.insert(self.Tabs, tab)
    
    tabButton.MouseButton1Click:Connect(function()
        self:SwitchTab(tabName)
    end)
    
    if #self.Tabs == 1 then
        self:SwitchTab(tabName)
    end
    
    local tabFunctions = {}
    
    -- ADD BUTTON
    function tabFunctions:AddButton(config)
        local buttonFrame = Instance.new("Frame")
        buttonFrame.Size = UDim2.new(1, 0, 0, 32)
        buttonFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        buttonFrame.BorderSizePixel = 0
        buttonFrame.Parent = tabContent
        
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 6)
        buttonCorner.Parent = buttonFrame
        
        local buttonStroke = Instance.new("UIStroke")
        buttonStroke.Color = Color3.fromRGB(60, 60, 60)
        buttonStroke.Thickness = 1
        buttonStroke.Parent = buttonFrame
        
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, 0, 1, 0)
        button.BackgroundTransparency = 1
        button.Text = config.Name or "Button"
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.Font = Enum.Font.GothamBold
        button.TextSize = 11
        button.BorderSizePixel = 0
        button.AutoButtonColor = false
        button.Parent = buttonFrame
        
        button.MouseEnter:Connect(function()
            TweenService:Create(buttonFrame, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            }):Play()
        end)
        
        button.MouseLeave:Connect(function()
            TweenService:Create(buttonFrame, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            }):Play()
        end)
        
        button.MouseButton1Click:Connect(function()
            if config.Callback then
                task.spawn(config.Callback)
            end
        end)
        
        return {
            Set = function(self, text)
                button.Text = text
            end
        }
    end
    
    -- ADD TOGGLE
    function tabFunctions:AddToggle(config)
        local toggleState = config.Default or false
        
        local toggleFrame = Instance.new("Frame")
        toggleFrame.Size = UDim2.new(1, 0, 0, 28)
        toggleFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        toggleFrame.BorderSizePixel = 0
        toggleFrame.Parent = tabContent
        
        local toggleCorner = Instance.new("UICorner")
        toggleCorner.CornerRadius = UDim.new(0, 6)
        toggleCorner.Parent = toggleFrame
        
        local toggleStroke = Instance.new("UIStroke")
        toggleStroke.Color = Color3.fromRGB(60, 60, 60)
        toggleStroke.Thickness = 1
        toggleStroke.Parent = toggleFrame
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.6, 0, 1, 0)
        label.Position = UDim2.new(0, 8, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = config.Name or "Toggle"
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = toggleFrame
        
        local toggleButton = Instance.new("TextButton")
        toggleButton.Size = UDim2.new(0, 38, 0, 18)
        toggleButton.Position = UDim2.new(1, -42, 0.5, -9)
        toggleButton.BackgroundColor3 = toggleState and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(60, 60, 60)
        toggleButton.Text = ""
        toggleButton.BorderSizePixel = 0
        toggleButton.AutoButtonColor = false
        toggleButton.Parent = toggleFrame
        
        local toggleCorner2 = Instance.new("UICorner")
        toggleCorner2.CornerRadius = UDim.new(1, 0)
        toggleCorner2.Parent = toggleButton
        
        local toggleDot = Instance.new("Frame")
        toggleDot.Size = UDim2.new(0, 14, 0, 14)
        toggleDot.Position = UDim2.new(0, toggleState and 22 or 2, 0.5, -7)
        toggleDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        toggleDot.BorderSizePixel = 0
        toggleDot.Parent = toggleButton
        
        local dotCorner = Instance.new("UICorner")
        dotCorner.CornerRadius = UDim.new(1, 0)
        dotCorner.Parent = toggleDot
        
        local function toggle()
            toggleState = not toggleState
            
            TweenService:Create(toggleButton, TweenInfo.new(0.2), {
                BackgroundColor3 = toggleState and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(60, 60, 60)
            }):Play()
            
            TweenService:Create(toggleDot, TweenInfo.new(0.2), {
                Position = UDim2.new(0, toggleState and 22 or 2, 0.5, -7)
            }):Play()
            
            if config.Callback then
                task.spawn(config.Callback, toggleState)
            end
        end
        
        toggleButton.MouseButton1Click:Connect(toggle)
        
        return {
            Set = function(self, state)
                if state ~= toggleState then
                    toggle()
                end
            end
        }
    end
    
    -- ADD SLIDER (Simple Click-Based, Mobile Friendly)
    function tabFunctions:AddSlider(config)
        local sliderValue = config.Default or config.Min or 0
        local dragging = false
        
        local sliderFrame = Instance.new("Frame")
        sliderFrame.Size = UDim2.new(1, 0, 0, 45)
        sliderFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        sliderFrame.BorderSizePixel = 0
        sliderFrame.Parent = tabContent
        
        local sliderCorner = Instance.new("UICorner")
        sliderCorner.CornerRadius = UDim.new(0, 6)
        sliderCorner.Parent = sliderFrame
        
        local sliderStroke = Instance.new("UIStroke")
        sliderStroke.Color = Color3.fromRGB(60, 60, 60)
        sliderStroke.Thickness = 1
        sliderStroke.Parent = sliderFrame
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -16, 0, 18)
        label.Position = UDim2.new(0, 8, 0, 3)
        label.BackgroundTransparency = 1
        label.Text = (config.Name or "Slider") .. ": " .. sliderValue
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = sliderFrame
        
        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, -16, 0, 6)
        track.Position = UDim2.new(0, 8, 1, -18)
        track.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        track.BorderSizePixel = 0
        track.Parent = sliderFrame
        
        local trackCorner = Instance.new("UICorner")
        trackCorner.CornerRadius = UDim.new(1, 0)
        trackCorner.Parent = track
        
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
        fill.BorderSizePixel = 0
        fill.Parent = track
        
        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(1, 0)
        fillCorner.Parent = fill
        
        local sliderButton = Instance.new("TextButton")
        sliderButton.Size = UDim2.new(1, 0, 1, 0)
        sliderButton.BackgroundTransparency = 1
        sliderButton.Text = ""
        sliderButton.BorderSizePixel = 0
        sliderButton.AutoButtonColor = false
        sliderButton.Parent = track
        
        local function updateSlider(input)
            local posX
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                posX = input.Position.X
            else
                return
            end
            
            local relativeX = math.clamp((posX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            
            local newValue = config.Min + (config.Max - config.Min) * relativeX
            if config.Increment then
                newValue = math.floor(newValue / config.Increment + 0.5) * config.Increment
            else
                newValue = math.floor(newValue + 0.5)
            end
            
            newValue = math.clamp(newValue, config.Min, config.Max)
            
            if newValue ~= sliderValue then
                sliderValue = newValue
                fill.Size = UDim2.new(relativeX, 0, 1, 0)
                label.Text = (config.Name or "Slider") .. ": " .. sliderValue
                
                if config.Callback then
                    task.spawn(config.Callback, sliderValue)
                end
            end
        end
        
        sliderButton.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                updateSlider(input)
            end
        end)
        
        sliderButton.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                updateSlider(input)
            end
        end)
        
        sliderButton.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
        
        local initialPercent = (sliderValue - config.Min) / (config.Max - config.Min)
        fill.Size = UDim2.new(initialPercent, 0, 1, 0)
        
        return {
            Set = function(self, value)
                sliderValue = math.clamp(value, config.Min, config.Max)
                local percent = (sliderValue - config.Min) / (config.Max - config.Min)
                fill.Size = UDim2.new(percent, 0, 1, 0)
                label.Text = (config.Name or "Slider") .. ": " .. sliderValue
            end
        }
    end
    
    -- ADD TEXTBOX
    function tabFunctions:AddTextbox(config)
        local textboxFrame = Instance.new("Frame")
        textboxFrame.Size = UDim2.new(1, 0, 0, 42)
        textboxFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        textboxFrame.BorderSizePixel = 0
        textboxFrame.Parent = tabContent
        
        local textboxCorner = Instance.new("UICorner")
        textboxCorner.CornerRadius = UDim.new(0, 6)
        textboxCorner.Parent = textboxFrame
        
        local textboxStroke = Instance.new("UIStroke")
        textboxStroke.Color = Color3.fromRGB(60, 60, 60)
        textboxStroke.Thickness = 1
        textboxStroke.Parent = textboxFrame
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -16, 0, 16)
        label.Position = UDim2.new(0, 8, 0, 2)
        label.BackgroundTransparency = 1
        label.Text = config.Name or "Textbox"
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 10
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = textboxFrame
        
        local textbox = Instance.new("TextBox")
        textbox.Size = UDim2.new(1, -16, 0, 20)
        textbox.Position = UDim2.new(0, 8, 0, 19)
        textbox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        textbox.TextColor3 = Color3.fromRGB(255, 255, 255)
        textbox.Font = Enum.Font.Gotham
        textbox.TextSize = 10
        textbox.PlaceholderText = config.Placeholder or "Enter text..."
        textbox.Text = config.Default or ""
        textbox.ClearTextOnFocus = false
        textbox.BorderSizePixel = 0
        textbox.Parent = textboxFrame
        
        local textboxInnerCorner = Instance.new("UICorner")
        textboxInnerCorner.CornerRadius = UDim.new(0, 4)
        textboxInnerCorner.Parent = textbox
        
        textbox.FocusLost:Connect(function(enterPressed)
            if enterPressed and config.Callback then
                task.spawn(config.Callback, textbox.Text)
            end
        end)
        
        return {
            Set = function(self, text)
                textbox.Text = text
            end,
            Get = function(self)
                return textbox.Text
            end
        }
    end
    
    -- ADD MULTI-LINE TEXTBOX (Untuk Code Editor)
    function tabFunctions:AddMultiLineTextbox(config)
        local textboxFrame = Instance.new("Frame")
        textboxFrame.Size = UDim2.new(1, 0, 0, config.Height or 80)
        textboxFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        textboxFrame.BorderSizePixel = 0
        textboxFrame.Parent = tabContent
        
        local textboxCorner = Instance.new("UICorner")
        textboxCorner.CornerRadius = UDim.new(0, 6)
        textboxCorner.Parent = textboxFrame
        
        local textboxStroke = Instance.new("UIStroke")
        textboxStroke.Color = Color3.fromRGB(60, 60, 60)
        textboxStroke.Thickness = 1
        textboxStroke.Parent = textboxFrame
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -16, 0, 16)
        label.Position = UDim2.new(0, 8, 0, 2)
        label.BackgroundTransparency = 1
        label.Text = config.Name or "Code Editor"
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 10
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = textboxFrame
        
        local scrollingFrame = Instance.new("ScrollingFrame")
        scrollingFrame.Size = UDim2.new(1, -16, 1, -25)
        scrollingFrame.Position = UDim2.new(0, 8, 0, 19)
        scrollingFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        scrollingFrame.BorderSizePixel = 0
        scrollingFrame.ScrollBarThickness = 6
        scrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
        scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scrollingFrame.Parent = textboxFrame
        
        local textbox = Instance.new("TextBox")
        textbox.Size = UDim2.new(1, 0, 1, 0)
        textbox.BackgroundTransparency = 1
        textbox.TextColor3 = Color3.fromRGB(255, 255, 255)
        textbox.Font = Enum.Font.Gotham
        textbox.TextSize = 10
        textbox.PlaceholderText = config.Placeholder or "Paste your lua code here..."
        textbox.Text = config.Default or ""
        textbox.ClearTextOnFocus = false
        textbox.MultiLine = true
        textbox.TextWrapped = true
        textbox.TextXAlignment = Enum.TextXAlignment.Left
        textbox.TextYAlignment = Enum.TextYAlignment.Top
        textbox.BorderSizePixel = 0
        textbox.Parent = scrollingFrame
        
        local textboxInnerCorner = Instance.new("UICorner")
        textboxInnerCorner.CornerRadius = UDim.new(0, 4)
        textboxInnerCorner.Parent = scrollingFrame
        
        textbox:GetPropertyChangedSignal("Text"):Connect(function()
            scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, textbox.TextBounds.Y + 10)
        end)
        
        return {
            Set = function(self, text)
                textbox.Text = text
            end,
            Get = function(self)
                return textbox.Text
            end,
            Instance = textbox
        }
    end
    
    -- ADD DROPDOWN
    function tabFunctions:AddDropdown(config)
        local dropdownState = config.Default or config.Options[1]
        local dropdownOpen = false
        
        local dropdownFrame = Instance.new("Frame")
        dropdownFrame.Size = UDim2.new(1, 0, 0, 28)
        dropdownFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        dropdownFrame.BorderSizePixel = 0
        dropdownFrame.Parent = tabContent
        
        local dropdownCorner = Instance.new("UICorner")
        dropdownCorner.CornerRadius = UDim.new(0, 6)
        dropdownCorner.Parent = dropdownFrame
        
        local dropdownStroke = Instance.new("UIStroke")
        dropdownStroke.Color = Color3.fromRGB(60, 60, 60)
        dropdownStroke.Thickness = 1
        dropdownStroke.Parent = dropdownFrame
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.5, 0, 1, 0)
        label.Position = UDim2.new(0, 8, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = config.Name or "Dropdown"
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = dropdownFrame
        
        local currentText = Instance.new("TextLabel")
        currentText.Size = UDim2.new(0.35, 0, 1, 0)
        currentText.Position = UDim2.new(0.5, 0, 0, 0)
        currentText.BackgroundTransparency = 1
        currentText.Text = dropdownState
        currentText.TextColor3 = Color3.fromRGB(200, 200, 200)
        currentText.Font = Enum.Font.Gotham
        currentText.TextSize = 10
        currentText.TextXAlignment = Enum.TextXAlignment.Right
        currentText.TextTruncate = Enum.TextTruncate.AtEnd
        currentText.Parent = dropdownFrame
        
        local arrow = Instance.new("TextLabel")
        arrow.Size = UDim2.new(0, 18, 1, 0)
        arrow.Position = UDim2.new(1, -20, 0, 0)
        arrow.BackgroundTransparency = 1
        arrow.Text = "▼"
        arrow.TextColor3 = Color3.fromRGB(200, 200, 200)
        arrow.Font = Enum.Font.Gotham
        arrow.TextSize = 10
        arrow.Parent = dropdownFrame
        
        local dropdownButton = Instance.new("TextButton")
        dropdownButton.Size = UDim2.new(1, 0, 1, 0)
        dropdownButton.BackgroundTransparency = 1
        dropdownButton.Text = ""
        dropdownButton.BorderSizePixel = 0
        dropdownButton.AutoButtonColor = false
        dropdownButton.Parent = dropdownFrame
        
        local optionsFrame = Instance.new("Frame")
        optionsFrame.Size = UDim2.new(0, 0, 0, 0)
        optionsFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        optionsFrame.BorderSizePixel = 0
        optionsFrame.Visible = false
        optionsFrame.ZIndex = 200
        optionsFrame.Parent = ScreenGui
        
        local optionsCorner = Instance.new("UICorner")
        optionsCorner.CornerRadius = UDim.new(0, 6)
        optionsCorner.Parent = optionsFrame
        
        local optionsStroke = Instance.new("UIStroke")
        optionsStroke.Color = Color3.fromRGB(60, 60, 60)
        optionsStroke.Thickness = 1
        optionsStroke.Parent = optionsFrame
        
        local optionsScroll = Instance.new("ScrollingFrame")
        optionsScroll.Size = UDim2.new(1, 0, 1, 0)
        optionsScroll.BackgroundTransparency = 1
        optionsScroll.BorderSizePixel = 0
        optionsScroll.ScrollBarThickness = 4
        optionsScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
        optionsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        optionsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        optionsScroll.ZIndex = 201
        optionsScroll.Parent = optionsFrame
        
        local optionsLayout = Instance.new("UIListLayout")
        optionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
        optionsLayout.Parent = optionsScroll
        
        for _, option in ipairs(config.Options) do
            local optionButton = Instance.new("TextButton")
            optionButton.Size = UDim2.new(1, 0, 0, 28)
            optionButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            optionButton.Text = option
            optionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            optionButton.Font = Enum.Font.Gotham
            optionButton.TextSize = 10
            optionButton.BorderSizePixel = 0
            optionButton.AutoButtonColor = false
            optionButton.ZIndex = 202
            optionButton.Parent = optionsScroll
            
            optionButton.MouseEnter:Connect(function()
                TweenService:Create(optionButton, TweenInfo.new(0.1), {
                    BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                }):Play()
            end)
            
            optionButton.MouseLeave:Connect(function()
                TweenService:Create(optionButton, TweenInfo.new(0.1), {
                    BackgroundColor3 = Color3.fromRGB(35, 35, 35)
                }):Play()
            end)
            
            optionButton.MouseButton1Click:Connect(function()
                dropdownState = option
                currentText.Text = option
                optionsFrame.Visible = false
                dropdownOpen = false
                arrow.Text = "▼"
                
                if config.Callback then
                    task.spawn(config.Callback, option)
                end
            end)
        end
        
        local function updatePosition()
            local pos = dropdownFrame.AbsolutePosition
            local size = dropdownFrame.AbsoluteSize
            optionsFrame.Position = UDim2.fromOffset(pos.X, pos.Y + size.Y + 4)
            optionsFrame.Size = UDim2.new(0, size.X, 0, math.min(#config.Options * 28, 140))
        end
        
        dropdownButton.MouseButton1Click:Connect(function()
            dropdownOpen = not dropdownOpen
            
            if dropdownOpen then
                updatePosition()
                arrow.Text = "▲"
            else
                arrow.Text = "▼"
            end
            
            optionsFrame.Visible = dropdownOpen
        end)
        
        SimpleUI:AddConnection(UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 and dropdownOpen then
                local mousePos = UserInputService:GetMouseLocation()
                local dropPos = dropdownFrame.AbsolutePosition
                local dropSize = dropdownFrame.AbsoluteSize
                local optPos = optionsFrame.AbsolutePosition
                local optSize = optionsFrame.AbsoluteSize
                
                local inDrop = mousePos.X >= dropPos.X and mousePos.X <= dropPos.X + dropSize.X and
                              mousePos.Y >= dropPos.Y and mousePos.Y <= dropPos.Y + dropSize.Y
                
                local inOpt = mousePos.X >= optPos.X and mousePos.X <= optPos.X + optSize.X and
                             mousePos.Y >= optPos.Y and mousePos.Y <= optPos.Y + optSize.Y
                
                if not inDrop and not inOpt then
                    optionsFrame.Visible = false
                    dropdownOpen = false
                    arrow.Text = "▼"
                end
            end
        end))
        
        return {
            Set = function(self, option)
                dropdownState = option
                currentText.Text = option
            end
        }
    end
    
    -- ADD LABEL
    function tabFunctions:AddLabel(text)
        local labelFrame = Instance.new("Frame")
        labelFrame.Size = UDim2.new(1, 0, 0, 22)
        labelFrame.BackgroundTransparency = 1
        labelFrame.Parent = tabContent
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -8, 1, 0)
        label.Position = UDim2.new(0, 8, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = text or "Label"
        label.TextColor3 = Color3.fromRGB(200, 200, 200)
        label.Font = Enum.Font.Gotham
        label.TextSize = 10
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = labelFrame
        
        return {
            Set = function(self, newText)
                label.Text = newText
            end
        }
    end
    
    -- ADD SECTION
    function tabFunctions:AddSection(text)
        local sectionFrame = Instance.new("Frame")
        sectionFrame.Size = UDim2.new(1, 0, 0, 25)
        sectionFrame.BackgroundTransparency = 1
        sectionFrame.Parent = tabContent
        
        local sectionLabel = Instance.new("TextLabel")
        sectionLabel.Size = UDim2.new(1, -8, 1, 0)
        sectionLabel.Position = UDim2.new(0, 8, 0, 0)
        sectionLabel.BackgroundTransparency = 1
        sectionLabel.Text = text or "Section"
        sectionLabel.TextColor3 = Color3.fromRGB(100, 150, 255)
        sectionLabel.Font = Enum.Font.GothamBold
        sectionLabel.TextSize = 12
        sectionLabel.TextXAlignment = Enum.TextXAlignment.Left
        sectionLabel.Parent = sectionFrame
        
        local divider = Instance.new("Frame")
        divider.Size = UDim2.new(1, -8, 0, 1)
        divider.Position = UDim2.new(0, 8, 1, -4)
        divider.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        divider.BorderSizePixel = 0
        divider.Parent = sectionFrame
    end
    
    return tabFunctions
end

function SimpleUI:SwitchTab(tabName)
    for _, tab in pairs(self.Tabs) do
        tab.Content.Visible = (tab.Name == tabName)
        
        if tab.Name == tabName then
            TweenService:Create(tab.Button, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(0, 150, 255)
            }):Play()
            tab.Button.TextColor3 = Color3.fromRGB(255, 255, 255)
            self.CurrentTab = tab
        else
            TweenService:Create(tab.Button, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            }):Play()
            tab.Button.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
    end
end

-- =======================================
-- SINGLE TAB DENGAN SEMUA FITUR EXECUTE
-- =======================================

local MainTab = SimpleUI:AddTab("Executor")

-- ===== EXECUTE SYSTEM =====
MainTab:AddSection("🚀 Execute System")

-- Single-line URL/Code Input
local scriptInput = MainTab:AddTextbox({
    Name = "URL / Quick Code",
    Placeholder = "https://... or paste lua code here",
    Callback = function(text)
        if text ~= "" then
            local success, result = pcall(function()
                if text:match("^https://") or text:match("^http://") then
                    loadstring(game:HttpGet(text, true))()
                else
                    loadstring(text)()
                end
            end)
            
            if success then
                scriptInput:Set("✅ Executed Successfully!")
                print("Script executed successfully")
            else
                scriptInput:Set("❌ Error: " .. tostring(result):sub(1, 30))
                warn("Execution failed: " .. tostring(result))
            end
            task.wait(2)
            scriptInput:Set("")
        end
    end
})

-- Multi-line Code Editor
MainTab:AddSection("📝 Multi-line Code Editor")

local multiLineCode = MainTab:AddMultiLineTextbox({
    Name = "Lua Code Editor",
    Placeholder = "print('Hello World!')\nfor i=1,5 do\n    print(i)\nend\n-- Multi-line code supported",
    Height = 100
})

local multiLineOutput = MainTab:AddLabel("💡 Ready to execute code...")

-- Execute Buttons
local executeBtn = MainTab:AddButton({
    Name = "🚀 Execute Editor Code",
    Callback = function()
        local code = multiLineCode:Get()
        if code and code ~= "" then
            local success, result = pcall(function()
                loadstring(code)()
            end)
            
            if success then
                multiLineOutput:Set("✅ Execution Successful!")
                print("Multi-line code executed successfully")
            else
                multiLineOutput:Set("❌ Error: " .. tostring(result):sub(1, 40))
                warn("Multi-line execution failed: " .. tostring(result))
            end
        else
            multiLineOutput:Set("⚠️ Please enter some code!")
        end
    end
})

-- Clear Code Button
MainTab:AddButton({
    Name = "🗑️ Clear Editor",
    Callback = function()
        if multiLineCode then
            multiLineCode:Set("")
            multiLineOutput:Set("✅ Editor cleared!")
        end
    end
})

-- Safe Execute Button
MainTab:AddButton({
    Name = "🛡️ Safe Execute (Protected)",
    Callback = function()
        local code = multiLineCode:Get()
        if code and code ~= "" then
            local env = {}
            setmetatable(env, {__index = getfenv()})
            
            local success, result = pcall(function()
                local fn, err = loadstring(code)
                if fn then
                    setfenv(fn, env)
                    return fn()
                else
                    error(err)
                end
            end)
            
            if success then
                multiLineOutput:Set("✅ Safe Execution Complete!")
            else
                multiLineOutput:Set("❌ Protected: " .. tostring(result):sub(1, 35))
            end
        end
    end
})

-- ===== QUICK SCRIPTS =====
MainTab:AddSection("🔥 Popular Scripts")

local quickScripts = {
    {
        Name = "🔄 Infinite Yield",
        Code = "loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))()"
    },
    {
        Name = "🔍 Dex Explorer", 
        Code = "loadstring(game:HttpGet('https://raw.githubusercontent.com/infyiff/backup/main/dex.lua'))()"
    },
    {
        Name = "📡 Remote Spy",
        Code = "loadstring(game:HttpGet('https://raw.githubusercontent.com/exxtremestuffs/SimpleSpySource/master/SimpleSpy.lua'))()"
    },
    {
        Name = "🐟 Simple Fly",
        Code = "loadstring(game:HttpGet('https://raw.githubusercontent.com/XNEOFF/FlyGui/main/FlyGui.txt'))()"
    }
}

for _, scriptInfo in ipairs(quickScripts) do
    MainTab:AddButton({
        Name = scriptInfo.Name,
        Callback = function()
            local success, result = pcall(function()
                loadstring(scriptInfo.Code)()
            end)
            
            if success then
                multiLineOutput:Set("✅ " .. scriptInfo.Name .. " Loaded!")
            else
                multiLineOutput:Set("❌ Failed: " .. scriptInfo.Name)
            end
        end
    })
end

-- ===== GAME CONTROLS =====
MainTab:AddSection("🎮 Game Controls")

MainTab:AddToggle({
    Name = "God Mode",
    Default = false,
    Callback = function(value)
        print("God Mode:", value)
        multiLineOutput:Set("God Mode: " .. tostring(value))
    end
})

MainTab:AddToggle({
    Name = "ESP",
    Default = false,
    Callback = function(value)
        print("ESP:", value)
        multiLineOutput:Set("ESP: " .. tostring(value))
    end
})

MainTab:AddButton({
    Name = "Teleport Spawn",
    Callback = function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(0, 50, 0)
            multiLineOutput:Set("✅ Teleported to Spawn!")
        end
    end
})

MainTab:AddButton({
    Name = "Remove Fog",
    Callback = function()
        game.Lighting.FogEnd = 100000
        multiLineOutput:Set("✅ Fog Removed!")
    end
})

-- ===== PLAYER CONTROLS =====
MainTab:AddSection("👤 Player Mods")

local speedSlider = MainTab:AddSlider({
    Name = "Walk Speed",
    Min = 16,
    Max = 200,
    Default = 16,
    Increment = 1,
    Callback = function(value)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = value
        end
    end
})

local jumpSlider = MainTab:AddSlider({
    Name = "Jump Power",
    Min = 50,
    Max = 300,
    Default = 50,
    Increment = 5,
    Callback = function(value)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.JumpPower = value
        end
    end
})

-- ===== UI SETTINGS =====
MainTab:AddSection("⚙️ UI Settings")

local themeDropdown = MainTab:AddDropdown({
    Name = "Theme Color",
    Options = {"Blue", "Red", "Green", "Purple", "Orange"},
    Default = "Blue",
    Callback = function(option)
        local colors = {
            Blue = Color3.fromRGB(0, 150, 255),
            Red = Color3.fromRGB(255, 60, 60),
            Green = Color3.fromRGB(0, 200, 100),
            Purple = Color3.fromRGB(150, 50, 255),
            Orange = Color3.fromRGB(255, 150, 0)
        }
        
        if SimpleUI.CurrentTab then
            TweenService:Create(SimpleUI.CurrentTab.Button, TweenInfo.new(0.3), {
                BackgroundColor3 = colors[option] or colors.Blue
            }):Play()
        end
        multiLineOutput:Set("Theme: " .. option)
    end
})

MainTab:AddToggle({
    Name = "Auto Save Config",
    Default = true,
    Callback = function(value)
        multiLineOutput:Set("Auto Save: " .. tostring(value))
    end
})

-- ===== INFO & STATUS =====
MainTab:AddSection("ℹ️ System Info")

MainTab:AddLabel("✅ Mobile Friendly UI")
MainTab:AddLabel("✅ Full Execute System")
MainTab:AddLabel("✅ Multi-line Editor")
MainTab:AddLabel("✅ Safe Execution Mode")
MainTab:AddLabel(" ")
MainTab:AddLabel("Made with ❤️ - Executor UI")
MainTab:AddLabel("Version 4.0")

-- ===== DANGER ZONE =====
MainTab:AddSection("🗑️ Danger Zone")

MainTab:AddButton({
    Name = "Destroy UI",
    Callback = function()
        multiLineOutput:Set("👋 Goodbye!")
        task.wait(1)
        SimpleUI:Cleanup()
        ScreenGui:Destroy()
    end
})

return SimpleUI