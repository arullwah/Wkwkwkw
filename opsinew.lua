-- ========= MINI BUTTON: MOBILE-SAFE DRAG + FIVE TAP (INSTANT) =========

-- Five tap variables
local tapCount = 0
local lastTapTime = 0
local TAP_WINDOW = 0.5
local tapResetConnection = nil

-- Dragging variables
local dragging = false
local dragInput = nil
local dragStart = nil
local startPos = nil
local dragThreshold = 5
local hasDragged = false

-- Save file
local miniSaveFile = "MiniButtonPos.json"

-- Load saved position
SafeCall(function()
    if hasFileSystem and isfile and isfile(miniSaveFile) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(miniSaveFile)) end)
        if ok and type(data) == "table" and data.x and data.y then
            MiniButton.Position = UDim2.fromOffset(data.x, data.y)
        end
    end
end)

-- Show tap indicator
local function ShowTapFeedback(count)
    task.spawn(function()
        pcall(function()
            if not ScreenGui or not MiniButton then return end
            
            local indicator = Instance.new("TextLabel")
            indicator.Size = UDim2.fromOffset(50, 25)
            indicator.Position = UDim2.new(0, MiniButton.AbsolutePosition.X - 5, 0, MiniButton.AbsolutePosition.Y - 30)
            indicator.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            indicator.BackgroundTransparency = 0.2
            indicator.Text = count .. "/5"
            indicator.TextColor3 = Color3.fromRGB(255, 255, 255)
            indicator.Font = Enum.Font.GothamBold
            indicator.TextSize = 16
            indicator.TextStrokeTransparency = 0.5
            indicator.BorderSizePixel = 0
            indicator.Parent = ScreenGui
            
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 6)
            corner.Parent = indicator
            
            indicator.TextSize = 0
            TweenService:Create(indicator, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                TextSize = 16
            }):Play()
            
            task.wait(0.6)
            TweenService:Create(indicator, TweenInfo.new(0.3), {
                BackgroundTransparency = 1,
                TextTransparency = 1,
                TextStrokeTransparency = 1
            }):Play()
            
            task.wait(0.3)
            indicator:Destroy()
        end)
    end)
end

-- Pulse button with color (ASYNC - NON-BLOCKING!)
local function PulseButton(color, scale)
    task.spawn(function()
        pcall(function()
            if not MiniButton or not MiniButton.Parent then return end
            
            local originalColor = MiniButton.BackgroundColor3
            local originalSize = MiniButton.Size
            local targetSize = UDim2.fromOffset(40 * scale, 40 * scale)
            
            local tweenOut = TweenService:Create(
                MiniButton, 
                TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {
                    BackgroundColor3 = color,
                    Size = targetSize
                }
            )
            tweenOut:Play()
            tweenOut.Completed:Wait()
            
            task.wait(0.1)
            
            local tweenIn = TweenService:Create(
                MiniButton,
                TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {
                    BackgroundColor3 = originalColor,
                    Size = originalSize
                }
            )
            tweenIn:Play()
        end)
    end)
end

-- Handle five tap logic
local function HandleTap()
    local currentTime = tick()
    
    if currentTime - lastTapTime > TAP_WINDOW then
        tapCount = 0
    end
    
    tapCount = tapCount + 1
    lastTapTime = currentTime
    
    -- TAP 1: TOGGLE MAINFRAME (INSTANT!)
    if tapCount == 1 then
        pcall(function() PlaySound("Click") end)
        
        if MainFrame then
            MainFrame.Visible = not MainFrame.Visible
        end
        
        ShowTapFeedback(1)
        PulseButton(Color3.fromRGB(59, 15, 116), 1.05)
        
    -- TAP 2: SUBTLE FEEDBACK
    elseif tapCount == 2 then
        pcall(function() PlaySound("Click") end)
        ShowTapFeedback(2)
        PulseButton(Color3.fromRGB(80, 40, 140), 1.08)
        
    -- TAP 3: WARNING START
    elseif tapCount == 3 then
        pcall(function() PlaySound("Toggle") end)
        ShowTapFeedback(3)
        PulseButton(Color3.fromRGB(200, 150, 50), 1.12)
        
    -- TAP 4: STRONG WARNING
    elseif tapCount == 4 then
        pcall(function() PlaySound("Toggle") end)
        ShowTapFeedback(4)
        PulseButton(Color3.fromRGB(255, 150, 0), 1.16)
        
    -- TAP 5: CLOSE
    elseif tapCount >= 5 then
        pcall(function() PlaySound("Success") end)
        ShowTapFeedback(5)
        PulseButton(Color3.fromRGB(255, 50, 50), 1.2)
        
        task.wait(0.3)
        
        task.spawn(function()
            pcall(function()
                if StudioIsRecording then StopStudioRecording() end
                if IsPlaying or AutoLoop then StopPlayback() end
                if ShiftLockEnabled then DisableVisibleShiftLock() end
                if InfiniteJump then DisableInfiniteJump() end
                
                if titlePulseConnection then
                    titlePulseConnection:Disconnect()
                    titlePulseConnection = nil
                end
                
                CleanupConnections()
                ClearPathVisualization()
                RemoveShiftLockIndicator()
                
                if MainFrame then
                    TweenService:Create(MainFrame, TweenInfo.new(0.4), {
                        BackgroundTransparency = 1
                    }):Play()
                end
                
                if MiniButton then
                    local miniTween = TweenService:Create(MiniButton, TweenInfo.new(0.4), {
                        BackgroundTransparency = 1,
                        TextTransparency = 1
                    })
                    miniTween:Play()
                    miniTween.Completed:Wait()
                end
                
                task.wait(0.1)
                if ScreenGui then ScreenGui:Destroy() end
            end)
        end)
        
        tapCount = 0
    end
    
    if tapResetConnection then
        task.cancel(tapResetConnection)
    end
    
    tapResetConnection = task.delay(TAP_WINDOW, function()
        if tapCount < 5 then
            tapCount = 0
        end
    end)
end

-- INPUT BEGAN: Track specific input object
MiniButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or 
       input.UserInputType == Enum.UserInputType.Touch then
        
        dragging = true
        hasDragged = false
        dragInput = input
        dragStart = input.Position
        startPos = MiniButton.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                if dragInput == input then
                    dragging = false
                    dragInput = nil
                    
                    if not hasDragged then
                        HandleTap()
                    end
                    
                    if hasDragged then
                        SafeCall(function()
                            if hasFileSystem and writefile and HttpService then
                                local absX = MiniButton.AbsolutePosition.X
                                local absY = MiniButton.AbsolutePosition.Y
                                writefile(miniSaveFile, HttpService:JSONEncode({x = absX, y = absY}))
                            end
                        end)
                    end
                end
            end
        end)
    end
end)

-- INPUT CHANGED: Only process input that initiated drag
UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if dragInput ~= input then return end
    
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and 
       input.UserInputType ~= Enum.UserInputType.Touch then return end
    if not dragStart or not startPos then return end

    SafeCall(function()
        local delta = input.Position - dragStart
        local distance = math.sqrt(delta.X^2 + delta.Y^2)
        
        if distance > dragThreshold then
            hasDragged = true
        end
        
        if hasDragged then
            local newX = startPos.X.Offset + delta.X
            local newY = startPos.Y.Offset + delta.Y

            local cam = workspace.CurrentCamera
            local vx = (cam and cam.ViewportSize.X) or 1920
            local vy = (cam and cam.ViewportSize.Y) or 1080
            local margin = 4
            local btnWidth = MiniButton.AbsoluteSize.X
            local btnHeight = MiniButton.AbsoluteSize.Y

            newX = math.clamp(newX, -btnWidth + margin, vx - margin)
            newY = math.clamp(newY, -btnHeight + margin, vy - margin)

            MiniButton.Position = UDim2.fromOffset(newX, newY)
        end
    end)
end)