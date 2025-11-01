local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

StarterGui:SetCore("SendNotification", {
    Title = "Controller Support Added",
    Text = "R2: Shoot\nL2: Reload ('R' Key)\nButton B: Crouch\nButton X: Sprint (Toggle)",
    Duration = 5
})

local function safe_call(fn, ...)
    if type(fn) ~= "function" then return end
    pcall(fn, ...)
end

local do_press, do_release, do_kpress, do_krelease = function() end, function() end, function() end, function() end

if type(syn) == "table" then
    if type(syn.mouse_event) == "function" then
        do_press = function() safe_call(syn.mouse_event, 0x0002) end
        do_release = function() safe_call(syn.mouse_event, 0x0004) end
    end
    if type(syn.keyboard_event) == "function" then
        do_kpress = function(vk) safe_call(syn.keyboard_event, vk, true) end
        do_krelease = function(vk) safe_call(syn.keyboard_event, vk, false) end
    end
end

if type(mouse1press) == "function" and type(mouse1release) == "function" then
    do_press, do_release = mouse1press, mouse1release
end

if type(keypress) == "function" and type(keyrelease) == "function" then
    do_kpress, do_krelease = keypress, keyrelease
end

local VK_R, VK_C = 0x52, 0x43
local WALK_SPEED, SPRINT_SPEED = 16, 24
local isSprint = false

local function getHumanoid()
    local char = LocalPlayer and LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent then return end
    local k = input.KeyCode
    if k == Enum.KeyCode.ButtonR2 then
        safe_call(do_press)
    elseif k == Enum.KeyCode.ButtonL2 then
        safe_call(do_kpress, VK_R)
    elseif k == Enum.KeyCode.ButtonB then
        safe_call(do_kpress, VK_C)
    elseif k == Enum.KeyCode.ButtonX then
        isSprint = not isSprint
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = (isSprint and SPRINT_SPEED) or WALK_SPEED end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent then return end
    local k = input.KeyCode
    if k == Enum.KeyCode.ButtonR2 then
        safe_call(do_release)
    elseif k == Enum.KeyCode.ButtonL2 then
        safe_call(do_krelease, VK_R)
    elseif k == Enum.KeyCode.ButtonB then
        safe_call(do_krelease, VK_C)
    end
end)