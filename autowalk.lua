-- =====================================================
-- COMPLETE AUTO WALK UI LIBRARY
-- Version: 3.0 - Full Featured
-- =====================================================

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Library = {}
Library.__index = Library

function Library.new(config)
    local self = setmetatable({}, Library)
    
    self.Title = config.Title or "Auto Walk"
    self.Size = config.Size or {250, 350}
    self.ThemeColor = config.ThemeColor or Color3.fromRGB(59, 15, 116)
    self.Connections = {}
    self.RecordListItems = {}
    
    self:CreateUI()
    
    return self
end

function Library:AddConnection(connection)
    table.insert(self.Connections, connection)
    return connection
end

function Library:Cleanup()
    for _, connection in pairs(self.Connections) do
        if connection then
            pcall(function() connection:Disconnect() end)
        end
    end
    self.Connections = {}
end

function Library:CreateUI()
    local player = game:GetService("Players").LocalPlayer
    
    -- ScreenGui
    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = "AutoWalkUI_" .. HttpService:GenerateGUID(false)
    self.ScreenGui.ResetOnSpawn = false
    self.ScreenGui.Parent = player:WaitForChild("PlayerGui")
    
    -- Main Frame
    self.MainFrame = Instance.new("Frame")
    self.MainFrame.Size = UDim2.fromOffset(self.Size[1], self.Size[2])
    self.MainFrame.Position = UDim2.new(0.5, -self.Size[1]/2, 0.5, -self.Size[2]/2)
    self.MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    self.MainFrame.BorderSizePixel = 0
    self.MainFrame.Active = true
    self.MainFrame.Draggable = true
    self.MainFrame.Parent = self.ScreenGui
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent = self.MainFrame
    
    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 32)
    header.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    header.BorderSizePixel = 0
    header.Parent = self.MainFrame
    
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 12)
    headerCorner.Parent = header
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = self.Title
    title.TextColor3 = Color3.fromRGB(100, 255, 150)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.Parent = header
    
    self.TitleLabel = title
    
    -- Frame Counter
    self.FrameLabel = Instance.new("TextLabel")
    self.FrameLabel.Size = UDim2.new(0, 70, 1, 0)
    self.FrameLabel.Position = UDim2.new(0, 5, 0, 0)
    self.FrameLabel.BackgroundTransparency = 1
    self.FrameLabel.Text = "Frames: 0"
    self.FrameLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
    self.FrameLabel.Font = Enum.Font.GothamBold
    self.FrameLabel.TextSize = 9
    self.FrameLabel.Parent = header
    
    -- Hide Button
    local hideButton = Instance.new("TextButton")
    hideButton.Size = UDim2.fromOffset(30, 25)
    hideButton.Position = UDim2.new(1, -65, 0.5, -12)
    hideButton.BackgroundColor3 = self.ThemeColor
    hideButton.Text = "_"
    hideButton.TextColor3 = Color3.new(1, 1, 1)
    hideButton.Font = Enum.Font.GothamBold
    hideButton.TextSize = 14
    hideButton.Parent = header
    
    local hideCorner = Instance.new("UICorner")
    hideCorner.CornerRadius = UDim.new(0, 6)
    hideCorner.Parent = hideButton
    
    -- Close Button
    self.CloseButton = Instance.new("TextButton")
    self.CloseButton.Size = UDim2.fromOffset(30, 25)
    self.CloseButton.Position = UDim2.new(1, -30, 0.5, -12)
    self.CloseButton.BackgroundColor3 = self.ThemeColor
    self.CloseButton.Text = "X"
    self.CloseButton.TextColor3 = Color3.new(1, 1, 1)
    self.CloseButton.Font = Enum.Font.GothamBold
    self.CloseButton.TextSize = 12
    self.CloseButton.Parent = header
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = self.CloseButton
    
    -- Resize Button
    self.ResizeButton = Instance.new("TextButton")
    self.ResizeButton.Size = UDim2.fromOffset(24, 24)
    self.ResizeButton.Position = UDim2.new(1, -24, 1, -24)
    self.ResizeButton.BackgroundColor3 = self.ThemeColor
    self.ResizeButton.Text = "⤢"
    self.ResizeButton.TextColor3 = Color3.new(1, 1, 1)
    self.ResizeButton.Font = Enum.Font.GothamBold
    self.ResizeButton.TextSize = 14
    self.ResizeButton.ZIndex = 2
    self.ResizeButton.Parent = self.MainFrame
    
    local resizeCorner = Instance.new("UICorner")
    resizeCorner.CornerRadius = UDim.new(0, 8)
    resizeCorner.Parent = self.ResizeButton
    
    -- Content Area
    self.Content = Instance.new("ScrollingFrame")
    self.Content.Size = UDim2.new(1, -10, 1, -42)
    self.Content.Position = UDim2.new(0, 5, 0, 36)
    self.Content.BackgroundTransparency = 1
    self.Content.ScrollBarThickness = 3
    self.Content.ScrollBarImageColor3 = Color3.fromRGB(80, 120, 255)
    self.Content.CanvasSize = UDim2.new(0, 0, 0, 800)
    self.Content.Parent = self.MainFrame
    
    -- Mini Button
    self.MiniButton = Instance.new("TextButton")
    self.MiniButton.Size = UDim2.fromOffset(40, 40)
    self.MiniButton.Position = UDim2.new(0.5, -20, 0, 10)
    self.MiniButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    self.MiniButton.Text = "ArL"
    self.MiniButton.TextColor3 = Color3.new(1, 1, 1)
    self.MiniButton.Font = Enum.Font.GothamBold
    self.MiniButton.TextSize = 14
    self.MiniButton.Visible = false
    self.MiniButton.Active = true
    self.MiniButton.Draggable = true
    self.MiniButton.Parent = self.ScreenGui
    
    local miniCorner = Instance.new("UICorner")
    miniCorner.CornerRadius = UDim.new(0, 8)
    miniCorner.Parent = self.MiniButton
    
    -- Hide/Show Logic
    hideButton.MouseButton1Click:Connect(function()
        self.MainFrame.Visible = false
        self.MiniButton.Visible = true
    end)
    
    self.MiniButton.MouseButton1Click:Connect(function()
        self.MainFrame.Visible = true
        self.MiniButton.Visible = false
    end)
    
    -- Setup Resize
    self:SetupResize()
end

-- Resize System
function Library:SetupResize()
    local IsResizing = false
    local StartMousePos
    local StartSize
    
    self.ResizeButton.MouseButton1Down:Connect(function()
        IsResizing = true
        StartMousePos = UserInputService:GetMouseLocation()
        StartSize = self.MainFrame.Size
    end)
    
    self:AddConnection(UserInputService.InputChanged:Connect(function(input)
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
                local newHeight = math.clamp(StartSize.Y.Offset + delta.Y, 200, 500)
                
                self.MainFrame.Size = UDim2.fromOffset(newWidth, newHeight)
            end
        end
    end))
    
    self:AddConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            IsResizing = false
        end
    end))
end

-- Create Button
function Library:CreateButton(text, x, y, w, h, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(w, h)
    btn.Position = UDim2.fromOffset(x, y)
    btn.BackgroundColor3 = color or self.ThemeColor
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 9
    btn.AutoButtonColor = false
    btn.Parent = self.Content
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.7
    stroke.Parent = btn
    
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.new(
                math.min((color or self.ThemeColor).R * 1.2, 1),
                math.min((color or self.ThemeColor).G * 1.2, 1),
                math.min((color or self.ThemeColor).B * 1.2, 1)
            )
        }):Play()
    end)
    
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = color or self.ThemeColor
        }):Play()
    end)
    
    return btn
end

-- Create Toggle
function Library:CreateToggle(text, x, y, w, h, default)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(w, h)
    btn.Position = UDim2.fromOffset(x, y)
    btn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    btn.Text = ""
    btn.Parent = self.Content
    
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
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local bgColor = isOn and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(50, 50, 50)
        local knobPos = isOn and UDim2.new(0, 12, 0, 2) or UDim2.new(0, 2, 0, 2)
        TweenService:Create(toggle, tweenInfo, {BackgroundColor3 = bgColor}):Play()
        TweenService:Create(knob, tweenInfo, {Position = knobPos}):Play()
    end
    
    return btn, Animate
end

-- Create TextBox
function Library:CreateTextBox(x, y, w, h, placeholder)
    local textbox = Instance.new("TextBox")
    textbox.Size = UDim2.fromOffset(w, h)
    textbox.Position = UDim2.fromOffset(x, y)
    textbox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    textbox.BorderSizePixel = 0
    textbox.Text = ""
    textbox.PlaceholderText = placeholder
    textbox.TextColor3 = Color3.fromRGB(255, 255, 255)
    textbox.Font = Enum.Font.GothamBold
    textbox.TextSize = 11
    textbox.TextXAlignment = Enum.TextXAlignment.Center
    textbox.ClearTextOnFocus = false
    textbox.Parent = self.Content
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = textbox
    
    return textbox
end

-- Create Record List
function Library:CreateRecordList(x, y)
    local list = Instance.new("ScrollingFrame")
    list.Size = UDim2.new(1, 0, 1, -y)
    list.Position = UDim2.fromOffset(0, y)
    list.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 3
    list.ScrollBarImageColor3 = Color3.fromRGB(80, 120, 255)
    list.CanvasSize = UDim2.new(0, 0, 0, 0)
    list.Parent = self.Content
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = list
    
    self.RecordList = list
    return list
end

-- Update Record List with Full Features
function Library:UpdateRecordList(recordings, order, names, callbacks)
    if not self.RecordList then return end
    
    -- Clear existing items
    for _, child in pairs(self.RecordList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local yPos = 0
    
    for index, name in ipairs(order) do
        local rec = recordings[name]
        if not rec then continue end
        
        local item = Instance.new("Frame")
        item.Size = UDim2.new(1, -6, 0, 40)
        item.Position = UDim2.new(0, 3, 0, yPos)
        item.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        item.Parent = self.RecordList
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = item
        
        -- Name Box
        local nameBox = Instance.new("TextBox")
        nameBox.Size = UDim2.new(1, -130, 0, 18)
        nameBox.Position = UDim2.new(0, 8, 0, 4)
        nameBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        nameBox.BorderSizePixel = 0
        nameBox.Text = names[name] or "checkpoint"
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
        
        -- Info Label
        local infoLabel = Instance.new("TextLabel")
        infoLabel.Size = UDim2.new(1, -130, 0, 16)
        infoLabel.Position = UDim2.new(0, 8, 0, 22)
        infoLabel.BackgroundTransparency = 1
        
        if #rec > 0 then
            local totalSeconds = rec[#rec].Timestamp or 0
            local minutes = math.floor(totalSeconds / 60)
            local seconds = math.floor(totalSeconds % 60)
            infoLabel.Text = string.format("%d:%02d • %d frames", minutes, seconds, #rec)
        else
            infoLabel.Text = "0:00 • 0 frames"
        end
        
        infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        infoLabel.Font = Enum.Font.GothamBold
        infoLabel.TextSize = 8
        infoLabel.TextXAlignment = Enum.TextXAlignment.Left
        infoLabel.Parent = item
        
        -- Play Button
        local playBtn = Instance.new("TextButton")
        playBtn.Size = UDim2.fromOffset(25, 25)
        playBtn.Position = UDim2.new(1, -110, 0, 7)
        playBtn.BackgroundColor3 = self.ThemeColor
        playBtn.Text = "▶"
        playBtn.TextColor3 = Color3.new(1, 1, 1)
        playBtn.Font = Enum.Font.GothamBold
        playBtn.TextSize = 20
        playBtn.Parent = item
        
        local playCorner = Instance.new("UICorner")
        playCorner.CornerRadius = UDim.new(0, 6)
        playCorner.Parent = playBtn
        
        -- Up Button
        local upBtn = Instance.new("TextButton")
        upBtn.Size = UDim2.fromOffset(25, 25)
        upBtn.Position = UDim2.new(1, -80, 0, 7)
        upBtn.BackgroundColor3 = index > 1 and self.ThemeColor or Color3.fromRGB(30, 30, 30)
        upBtn.Text = "↑"
        upBtn.TextColor3 = Color3.new(1, 1, 1)
        upBtn.Font = Enum.Font.GothamBold
        upBtn.TextSize = 20
        upBtn.Parent = item
        
        local upCorner = Instance.new("UICorner")
        upCorner.CornerRadius = UDim.new(0, 6)
        upCorner.Parent = upBtn
        
        -- Down Button
        local downBtn = Instance.new("TextButton")
        downBtn.Size = UDim2.fromOffset(25, 25)
        downBtn.Position = UDim2.new(1, -50, 0, 7)
        downBtn.BackgroundColor3 = index < #order and self.ThemeColor or Color3.fromRGB(30, 30, 30)
        downBtn.Text = "↓"
        downBtn.TextColor3 = Color3.new(1, 1, 1)
        downBtn.Font = Enum.Font.GothamBold
        downBtn.TextSize = 20
        downBtn.Parent = item
        
        local downCorner = Instance.new("UICorner")
        downCorner.CornerRadius = UDim.new(0, 6)
        downCorner.Parent = downBtn
        
        -- Delete Button
        local delBtn = Instance.new("TextButton")
        delBtn.Size = UDim2.fromOffset(25, 25)
        delBtn.Position = UDim2.new(1, -20, 0, 7)
        delBtn.BackgroundColor3 = self.ThemeColor
        delBtn.Text = "✕"
        delBtn.TextColor3 = Color3.new(1, 1, 1)
        delBtn.Font = Enum.Font.GothamBold
        delBtn.TextSize = 20
        delBtn.Parent = item
        
        local delCorner = Instance.new("UICorner")
        delCorner.CornerRadius = UDim.new(0, 6)
        delCorner.Parent = delBtn
        
        -- Callbacks
        if callbacks then
            if callbacks.OnNameChange then
                nameBox.FocusLost:Connect(function()
                    callbacks.OnNameChange(name, nameBox.Text)
                end)
            end
            
            if callbacks.OnPlay then
                playBtn.MouseButton1Click:Connect(function()
                    callbacks.OnPlay(name)
                end)
            end
            
            if callbacks.OnMoveUp then
                upBtn.MouseButton1Click:Connect(function()
                    if index > 1 then callbacks.OnMoveUp(name) end
                end)
            end
            
            if callbacks.OnMoveDown then
                downBtn.MouseButton1Click:Connect(function()
                    if index < #order then callbacks.OnMoveDown(name) end
                end)
            end
            
            if callbacks.OnDelete then
                delBtn.MouseButton1Click:Connect(function()
                    callbacks.OnDelete(name)
                end)
            end
        end
        
        yPos = yPos + 43
    end
    
    self.RecordList.CanvasSize = UDim2.new(0, 0, 0, yPos)
end

-- Update Frame Count
function Library:UpdateFrameCount(count)
    if self.FrameLabel then
        self.FrameLabel.Text = string.format("Frames: %d", count)
    end
end

-- Destroy
function Library:Destroy()
    self:Cleanup()
    if self.ScreenGui then
        self.ScreenGui:Destroy()
    end
end

return Library