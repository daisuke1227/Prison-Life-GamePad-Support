local UserInputService = game:GetService("UserInputService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local function showNotification(msg, duration)
    local screenGui = Instance.new("ScreenGui")
    screenGui.DisplayOrder = 999
    screenGui.IgnoreGuiInset = true
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 0, 120)
    textLabel.Position = UDim2.new(0, 0, 0, 0)
    textLabel.BackgroundColor3 = Color3.new(0, 0, 0)
    textLabel.BackgroundTransparency = 0.2
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    textLabel.TextSize = 22
    textLabel.Font = Enum.Font.SourceSans
    textLabel.TextWrapped = true
    textLabel.TextScaled = false
    textLabel.Text = msg
    textLabel.Parent = screenGui
    
    screenGui.Parent = PlayerGui
    
    task.delay(duration, function()
        screenGui:Destroy()
    end)
end

showNotification("Controller Map Loaded:\nR2: Shoot (Left Click)\nL2: 'R' Key\nButton B: 'C' Key\nButton X: Toggle Speed", 10)

local do_press_func = mouse1press
local do_release_func = mouse1release
if syn and syn.mouse_event then
    do_press_func = function() syn.mouse_event(0x0002) end
    do_release_func = function() syn.mouse_event(0x0004) end
end

local do_keypress_func = keypress
local do_keyrelease_func = keyrelease
if syn and syn.keyboard_event then
    do_keypress_func = function(vk) syn.keyboard_event(vk, true) end
    do_keyrelease_func = function(vk) syn.keyboard_event(vk, false) end
end

local VK_R = 0x52
local VK_C = 0x43

if not (do_press_func and do_release_func) then
end

if not (do_keypress_func and do_keyrelease_func) then
    return
end

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    local key = input.KeyCode

    if key == Enum.KeyCode.ButtonR2 then
        if do_press_func then do_press_func() end
    
    elseif key == Enum.KeyCode.ButtonL2 then
        if do_keypress_func then do_keypress_func(VK_R) end

    elseif key == Enum.KeyCode.ButtonB then
        if do_keypress_func then do_keypress_func(VK_C) end

    elseif key == Enum.KeyCode.ButtonX then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = (hum.WalkSpeed == 16 and 24) or 16
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    local key = input.KeyCode

    if key == Enum.KeyCode.ButtonR2 then
        if do_release_func then do_release_func() end

    elseif key == Enum.KeyCode.ButtonL2 then
        if do_keyrelease_func then do_keyrelease_func(VK_R) end

    elseif key == Enum.KeyCode.ButtonB then
        if do_keyrelease_func then do_keyrelease_func(VK_C) end
    end
end)
