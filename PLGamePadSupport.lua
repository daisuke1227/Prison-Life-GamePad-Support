-- hey Aesthetical this is for you theres a lot of players like me that wanna use a controller and you removed it so hard yesterday I spent a good 10-15 minutes making a gamepad support script but you BROKE IT with the backpack and I just wanna tell you that please add Controller support it will be so amazing please and thank you this code was vibecoded and it may be the messiest code on earth but if I some stupid vibecoder can do it you can to and i dont even have the source of the game so please add it this took me literal hours to fix and get everything correct :3

local Players = game:GetService("Players")
repeat task.wait() Players = game:GetService("Players") until Players
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then LocalPlayer = Players.PlayerAdded:Wait() end
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

task.spawn(function()
	local success, err = pcall(function()
		-- IMPORTANT: You must upload the new UI script to a new pastebin and put the RAW URL here
		loadstring(game:HttpGet("https://pastebin.com/raw/dtJLzaDD", true))()
	end)
	if not success then
		warn("Keybind UI failed to load: " .. tostring(err))
	end
end)

local function LoadConfig()
	if not readfile or not isfile("ControllerConfig.json") then
		warn("readfile is not available or config file does not exist.")
		return nil
	end

	local settings = nil
	local success, err = pcall(function()
		local fileContent = readfile("ControllerConfig.json")
		local decodedSettings = HttpService:JSONDecode(fileContent)
		
		if decodedSettings and decodedSettings.Keybinds then
			settings = { Keybinds = {} }
			
			for key, keyName in pairs(decodedSettings.Keybinds) do
				if Enum.KeyCode[keyName] then
					settings.Keybinds[key] = Enum.KeyCode[keyName]
				else
					warn("Invalid keyName in config:", keyName)
				end
			end
		else
			warn("Config file is empty or corrupted.")
		end
	end)
	
	if success and settings then
		return settings
	else
		warn("Failed to load config: " .. tostring(err))
		return nil
	end
end

if not _G.Settings then
	_G.Settings = LoadConfig()
end

if not _G.Settings or not _G.Settings.Keybinds then
	_G.Settings = {
		Keybinds = {
			MenuToggle = Enum.KeyCode.ButtonY,
			Sprint = Enum.KeyCode.ButtonX,
			Crouch = Enum.KeyCode.ButtonB,
			Reload = Enum.KeyCode.ButtonL2
		}
	}
end
_G.isListeningForKey = nil

_G.SaveConfig = function()
	if not writefile then 
		warn("writefile is not available in this environment.")
		return 
	end
	
	pcall(function()
		local settingsToSave = {
			Keybinds = {}
		}
		
		for key, value in pairs(_G.Settings.Keybinds) do
			if value and value.Name then
				settingsToSave.Keybinds[key] = value.Name
			end
		end
		
		local jsonSettings = HttpService:JSONEncode(settingsToSave)
		
		writefile("ControllerConfig.json", jsonSettings)
	end)
end


StarterGui:SetCore("SendNotification", {
	Title = "Controller Support",
	Text = "R1/L1: Cycle Tool\nR2: Shoot\nL2: Reload\nButton B: Crouch\nButton X: Sprint\nButton Y: Toggle Menu",
	Duration = 7
})

local GunRemotes = ReplicatedStorage:WaitForChild("GunRemotes")
local ShootEvent = GunRemotes:WaitForChild("ShootEvent")
local FuncReload = GunRemotes:WaitForChild("FuncReload")

local GunAnimations = ReplicatedStorage:WaitForChild("GunAnimations")
local Anim_ShootBullet = GunAnimations:WaitForChild("ShootBullet")
local Anim_ShootShell = GunAnimations:WaitForChild("ShootShell")
local Anim_ReloadMag = GunAnimations:WaitForChild("ReloadMagazine")
local Anim_ReloadShell = GunAnimations:WaitForChild("ReloadShells")

local GunFrame = PlayerGui:WaitForChild("Home"):WaitForChild("hud"):WaitForChild("BottomRightFrame"):WaitForChild("GunFrame")
local BulletsLabel = GunFrame:WaitForChild("BulletsLabel")
local Backpack_Toolbar = PlayerGui:WaitForChild("Home"):WaitForChild("hud"):WaitForChild("BackpackUI"):WaitForChild("Toolbar")
local MobileCursor = PlayerGui:WaitForChild("Home"):WaitForChild("hud"):WaitForChild("MobileGunFrame"):WaitForChild("MobileCursor")

local currentTool = nil
local toolAttributes = {}
local loadedAnimations = {}
local lastShotTime = 0
local isShooting = false
local isShielding = false

local raycastParams = RaycastParams.new()
raycastParams.CollisionGroup = "ClientBullet"
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local bulletTweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local taserTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
local tweenGoal_Transparency = { ["Transparency"] = 1 }
local tweenGoal_Brightness = { ["Brightness"] = 0 }

local Backpack_currentSlot = 1
local Backpack_HighlightColor = Color3.fromRGB(0, 48, 79)
local Backpack_DefaultColor = Color3.fromRGB(18, 18, 21)

local VK_C = 0x43
local VK_R = 0x52
local WALK_SPEED, SPRINT_SPEED = 16, 24
local isSprint = false

local function safe_call(fn, ...) if type(fn) ~= "function" then return end pcall(fn, ...) end

local do_kpress, do_krelease = function() end, function() end
if type(syn) == "table" and type(syn.keyboard_event) == "function" then
	do_kpress = function(vk) safe_call(syn.keyboard_event, vk, true) end
	do_krelease = function(vk) safe_call(syn.keyboard_event, vk, false) end
elseif type(keypress) == "function" and type(keyrelease) == "function" then
	do_kpress, do_krelease = keypress, keyrelease
end

local function getHumanoid()
	local char = LocalPlayer and LocalPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local RemoteFolder = workspace:FindFirstChild("Remote") or workspace:WaitForChild("Remote")
local equipShieldRemote = RemoteFolder and RemoteFolder:FindFirstChild("equipShield")

local function loadAnimations(humanoid)
	local Animator = humanoid:FindFirstChildOfClass("Animator")
	if not Animator then return end
	loadedAnimations = {
		ShootBullet = Animator:LoadAnimation(Anim_ShootBullet),
		ShootShell = Animator:LoadAnimation(Anim_ShootShell),
		ReloadMagazine = Animator:LoadAnimation(Anim_ReloadMag),
		ReloadShells = Animator:LoadAnimation(Anim_ReloadShell)
	}
	for _, anim in pairs(loadedAnimations) do if anim then anim.Priority = Enum.AnimationPriority.Action2 end end
end

local function updateAmmoGUI()
	if not currentTool then return end
	local ammo = currentTool:GetAttribute("Local_CurrentAmmo")
	local maxAmmo = toolAttributes.MaxAmmo
	if ammo and maxAmmo then BulletsLabel.Text = tostring(ammo) .. "/" .. tostring(maxAmmo) end
end

local function playToolSound(soundName)
	if currentTool and currentTool:FindFirstChild("Handle") then
		local sound = currentTool.Handle:FindFirstChild(soundName)
		if sound then sound:Play() end
	end
end

local function internal_castRay(p_HeadPos, p_TargetPos)
	local spreadBase = toolAttributes.Spread or 1
	local spread = (p_HeadPos - p_TargetPos).Magnitude / spreadBase
	if not spread or spread == math.huge or spread ~= spread then spread = 1 end
	local v55 = (math.random() - 0.5) * 2 * (spread / 10)
	local v56 = (math.random() - 0.5) * 2 * (spread / 10)
	local v57 = (math.random() - 0.5) * 2 * (spread / 10)
	local direction = (p_TargetPos + Vector3.new(v55, v56, v57) - p_HeadPos).Unit
	local v58 = direction * (toolAttributes.Range or 800)
	local v59 = workspace:Raycast(p_HeadPos, v58, raycastParams)
	local hitInstance = v59 and v59.Instance or nil
	local hitPosition = v59 and v59.Position or (p_HeadPos + v58)
	return hitInstance, hitPosition
end

local function internal_createTaser(p_HeadPos, p_TargetPos)
	local hitInstance, hitPosition = internal_castRay(p_HeadPos, p_TargetPos)
	local mag = (hitPosition - currentTool.Muzzle.Position).Magnitude
	local part = Instance.new("Part", currentTool)
	Instance.new("BlockMesh", part).Scale = Vector3.new(0.8, 0.8, 1)
	part.Name = "RayPart"
	part.BrickColor = BrickColor.new("Cyan")
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 0.5
	part.FormFactor = Enum.FormFactor.Custom
	part.Size = Vector3.new(0.2, 0.2, mag)
	part.CFrame = CFrame.new(hitPosition, currentTool.Muzzle.Position) * CFrame.new(0, 0, -mag / 2)
	part.CollisionGroup = "Nothing"
	local light = Instance.new("SurfaceLight", part)
	light.Color = Color3.fromRGB(0, 234, 255)
	light.Range = 7
	light.Face = Enum.NormalId.Bottom
	light.Brightness = 5
	light.Angle = 180
	Debris:AddItem(part, 2)
	local tween1 = TweenService:Create(part, bulletTweenInfo, tweenGoal_Transparency)
	local tween2 = TweenService:Create(light, bulletTweenInfo, tweenGoal_Brightness)
	tween1:Play()
	tween2:Play()
	if currentTool and currentTool:FindFirstChild("Handle") and currentTool.Handle:FindFirstChild("Flare") then
		currentTool.Handle.Flare.Enabled = true
		task.delay(0.05, function()
			if currentTool and currentTool:FindFirstChild("Handle") and currentTool.Handle:FindFirstChild("Flare") then
				currentTool.Handle.Flare.Enabled = false
			end
		end)
	end
	return hitInstance, hitPosition
end

local function internal_createBullet(p_HeadPos, p_TargetPos)
	local hitInstance, hitPosition = internal_castRay(p_HeadPos, p_TargetPos)
	local mag = (hitPosition - currentTool.Muzzle.Position).Magnitude
	local part = Instance.new("Part", currentTool)
	Instance.new("BlockMesh", part).Scale = Vector3.new(0.5, 0.5, 1)
	part.Name = "RayPart"
	part.BrickColor = BrickColor.Yellow()
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 0.5
	part.FormFactor = Enum.FormFactor.Custom
	part.Size = Vector3.new(0.2, 0.2, mag)
	part.CFrame = CFrame.new(hitPosition, currentTool.Muzzle.Position) * CFrame.new(0, 0, -mag / 2)
	Debris:AddItem(part, 0.05)
	if currentTool and currentTool:FindFirstChild("Handle") and currentTool.Handle:FindFirstChild("Flare") then
		currentTool.Handle.Flare.Enabled = true
		task.delay(0.05, function()
			if currentTool and currentTool:FindFirstChild("Handle") and currentTool.Handle:FindFirstChild("Flare") then
				currentTool.Handle.Flare.Enabled = false
			end
		end)
	end
	return hitInstance, hitPosition
end

local function isRiotShield(tool)
	if not tool or not tool.IsA then return false end
	if not tool:IsA("Tool") then return false end
	local name = (tool.Name or ""):lower()
	local attrName = (tool:GetAttribute("ToolName") or ""):lower()
	local ttAttr = (tool:GetAttribute("ToolType") or ""):lower()
	if name == "riot shield" or name == "riotshield" or attrName == "riot shield" or attrName == "riotshield" then return true end
	if name:find("riot") and name:find("shield") then return true end
	if ttAttr == "shield" and (name:find("riot") or attrName:find("riot")) then return true end
	return false
end

local function findShieldInBackpack()
	if LocalPlayer and LocalPlayer:FindFirstChild("Backpack") then
		for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do if isRiotShield(tool) then return tool end end
	end
	local char = LocalPlayer.Character
	if char then
		for _, tool in ipairs(char:GetChildren()) do if isRiotShield(tool) then return tool end end
	end
	return nil
end

local function equipShieldTool(tool)
	if not isRiotShield(tool) then return false, "not a Riot Shield" end
	local humanoid = getHumanoid()
	if not humanoid then return false, "no humanoid" end
	local parent = tool.Parent
	if parent ~= LocalPlayer.Backpack and parent ~= LocalPlayer.Character then return false, "tool not in Backpack or Character" end
	local ok, err = pcall(function() humanoid:EquipTool(tool) end)
	if not ok then return false, err end
	currentTool = tool
	toolAttributes = currentTool:GetAttributes()
	lastShotTime = tick() - (toolAttributes.FireRate or 0.1)
	return true, nil
end

local function shootWeapon()
	if isShielding then return end
	if not currentTool or (currentTool:GetAttribute("Local_ReloadSession") or 0) > 0 then return end
	local humanoid = getHumanoid()
	if not humanoid or humanoid.Health <= 0 then return end
	local currentAmmo = currentTool:GetAttribute("Local_CurrentAmmo")
	if not currentAmmo or currentAmmo <= 0 then return end
	local fireRate = toolAttributes.FireRate or 0.1
	if tick() - lastShotTime < fireRate then return end
	lastShotTime = tick()
	currentAmmo = currentAmmo - 1
	currentTool:SetAttribute("Local_CurrentAmmo", currentAmmo)
	toolAttributes.Local_CurrentAmmo = currentAmmo
	updateAmmoGUI()
	if toolAttributes.IsShotgun then
		if loadedAnimations.ShootShell then loadedAnimations.ShootShell:Play() end
		task.delay(0.2, function() playToolSound("SecondarySound") end)
	else
		if loadedAnimations.ShootBullet then loadedAnimations.ShootBullet:Play() end
	end
	playToolSound("ShootSound")
	local head = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
	if not head then return end
	local headPos = head.Position
	local aimScreenPos
	if MobileCursor and MobileCursor.AbsolutePosition and MobileCursor.AbsoluteSize and MobileCursor.Visible then
		local abs = MobileCursor.AbsolutePosition + (MobileCursor.AbsoluteSize / 2)
		aimScreenPos = Vector2.new(abs.X, abs.Y)
	else
		aimScreenPos = UserInputService:GetMouseLocation()
		if not aimScreenPos then aimScreenPos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2) end
	end
	local cameraRay = Camera:ViewportPointToRay(aimScreenPos.X, aimScreenPos.Y)
	local rayTarget
	local raycastResult = workspace:Raycast(cameraRay.Origin, cameraRay.Direction * 500, raycastParams)
	if raycastResult then rayTarget = raycastResult.Position else rayTarget = cameraRay.Origin + cameraRay.Direction * 500 end
	local hitData = {}
	local projectileCount = toolAttributes.ProjectileCount or 1
	local effectFunction = (toolAttributes.Projectile == "Taser") and internal_createTaser or internal_createBullet
	for i = 1, projectileCount do
		local hitInstance, hitPosition = effectFunction(headPos, rayTarget)
		table.insert(hitData, { headPos, hitPosition, hitInstance })
	end
	ShootEvent:FireServer(hitData)
end

local function Backpack_getEquippedTool()
	local char = LocalPlayer.Character
	if not char then return nil end
	for _, child in ipairs(char:GetChildren()) do if child:IsA("Tool") then return child end end
	return nil
end

local function Backpack_getToolButtons()
	local buttons = {}
	for _, button in ipairs(Backpack_Toolbar:GetChildren()) do
		if (button:IsA("TextButton") or button:IsA("ImageButton")) and button.Visible == true then table.insert(buttons, button) end
	end
	table.sort(buttons, function(a, b) return a.Position.X.Offset < b.Position.X.Offset end)
	return buttons
end

local function Backpack_updateHighlight(buttons, slot)
	local equippedTool = Backpack_getEquippedTool()
	for i, button in ipairs(buttons) do
		local toolName = button.Text
		if i == slot then
			if equippedTool and equippedTool.Name == toolName then
				button.BackgroundColor3 = Backpack_HighlightColor
			elseif not equippedTool then
				button.BackgroundColor3 = Backpack_HighlightColor
			else
				button.BackgroundColor3 = Backpack_DefaultColor
			end
		elseif equippedTool and equippedTool.Name == toolName then
			button.BackgroundColor3 = Backpack_HighlightColor
		else
			button.BackgroundColor3 = Backpack_DefaultColor
		end
	end
end

local function Backpack_equipToolBySlot(slot)
	local buttons = Backpack_getToolButtons()
	if #buttons == 0 then return end
	local targetButton = buttons[slot]
	if not targetButton then return end
	local toolName = targetButton.Text
	local tool = LocalPlayer.Backpack:FindFirstChild(toolName)
	local humanoid = getHumanoid()
	if not humanoid then return end
	local equippedTool = Backpack_getEquippedTool()
	if equippedTool and equippedTool.Name == toolName then
		humanoid:UnequipTools()
		Backpack_currentSlot = slot
	elseif tool then
		humanoid:EquipTool(tool)
		Backpack_currentSlot = slot
		task.delay(0.05, function()
			local eq = Backpack_getEquippedTool()
			if eq and eq:GetAttribute("FireRate") then lastShotTime = tick() - (eq:GetAttribute("FireRate") or 0.1) end
		end)
	end
	Backpack_updateHighlight(buttons, Backpack_currentSlot)
end

local function Backpack_cycleTool(direction)
	local buttons = Backpack_getToolButtons()
	local numTools = #buttons
	if numTools == 0 then return end
	local equippedTool = Backpack_getEquippedTool()
	local currentEquippedSlot = -1
	if equippedTool then
		for i, button in ipairs(buttons) do if button.Text == equippedTool.Name then currentEquippedSlot = i break end end
	else currentEquippedSlot = -1 end
	local nextSlot
	if currentEquippedSlot == -1 then
		if direction == 1 then nextSlot = 1 else nextSlot = numTools end
	else
		nextSlot = currentEquippedSlot + direction
		if nextSlot > numTools then nextSlot = 0 elseif nextSlot < 1 then nextSlot = 0 end
	end
	if nextSlot == 0 then
		local humanoid = getHumanoid()
		if humanoid then humanoid:UnequipTools() end
		Backpack_currentSlot = 1
		Backpack_updateHighlight(buttons, -1)
	else
		Backpack_equipToolBySlot(nextSlot)
	end
end

local function onChildAdded(child)
	if not child:IsA("Tool") then return end
	if child.Parent ~= LocalPlayer.Character then return end
	if child:GetAttribute("ToolType") == "Gun" then
		child:WaitForChild("Handle")
		currentTool = child
		toolAttributes = currentTool:GetAttributes()
		if LocalPlayer.Character then raycastParams.FilterDescendantsInstances = {LocalPlayer.Character} end
		local serverAmmo = currentTool:GetAttribute("CurrentAmmo")
		currentTool:SetAttribute("Local_CurrentAmmo", serverAmmo)
		toolAttributes.Local_CurrentAmmo = serverAmmo
		updateAmmoGUI()
		local humanoid = getHumanoid()
		if humanoid then task.spawn(function() loadAnimations(humanoid) end) end
		lastShotTime = tick() - (toolAttributes.FireRate or currentTool:GetAttribute("FireRate") or 0.1)
	end
	if isRiotShield(child) and child.Parent == LocalPlayer.Character then
		currentTool = child
		toolAttributes = currentTool:GetAttributes()
		lastShotTime = tick() - (toolAttributes.FireRate or currentTool:GetAttribute("FireRate") or 0.1)
	end
end

local function onChildRemoved(child)
	if child == currentTool then
		currentTool = nil
		toolAttributes = {}
		loadedAnimations = {}
		isShooting = false
		isShielding = false
		lastShotTime = 0
	end
end

local function setupCharacter(character)
	isSprint = false
	raycastParams.FilterDescendantsInstances = {character}
	character.ChildAdded:Connect(onChildAdded)
	character.ChildRemoved:Connect(onChildRemoved)
	for _, child in ipairs(character:GetChildren()) do onChildAdded(child) end
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:FindFirstChild("Humanoid")
	if humanoid then loadAnimations(humanoid) end
end

LocalPlayer.CharacterAdded:Connect(setupCharacter)
if LocalPlayer.Character then setupCharacter(LocalPlayer.Character) end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if _G.isListeningForKey then
		local key = input.KeyCode
		local inputType = input.UserInputType

		local isKeyboard = (inputType == Enum.UserInputType.Keyboard)
		local isGamepad = (inputType == Enum.UserInputType.Gamepad1 or
						   inputType == Enum.UserInputType.Gamepad2 or
						   inputType == Enum.UserInputType.Gamepad3 or
						   inputType == Enum.UserInputType.Gamepad4)

		if isKeyboard or isGamepad then
			if key == Enum.KeyCode.Unknown then 
				_G.isListeningForKey = nil
				if _G.updateMenuUI then _G.updateMenuUI() end
				return true 
			end
			
			local success, keyName = pcall(function() return key.Name end)
			if not success or not keyName or keyName == "Unknown" then
				_G.isListeningForKey = nil
				if _G.updateMenuUI then _G.updateMenuUI() end
				return true
			end

			_G.Settings.Keybinds[_G.isListeningForKey] = key
			_G.isListeningForKey = nil
			if _G.updateMenuUI then _G.updateMenuUI() end
			return true
		else
			return false
		end
	end

	local k = input.KeyCode
	local inputType = input.UserInputType

	if k == _G.Settings.Keybinds.MenuToggle then
		if _G.KeybindMenu then
			_G.KeybindMenu.Visible = not _G.KeybindMenu.Visible
			if _G.KeybindMenu.Visible then
				_G.selectedMenuItemIndex = 1
				if _G.updateMenuUI then _G.updateMenuUI() end
			end
		end
		return
	end
	
	if _G.handleMenuNavigation and _G.handleMenuNavigation(input) then return end
	if gameProcessed then return end
if k == Enum.KeyCode.ButtonR2 then
	
		local isController = k == Enum.KeyCode.ButtonR2
		local isMouse = inputType == Enum.UserInputType.MouseButton1
		local isTouch = inputType == Enum.UserInputType.Touch
		local usingShield = false
		if currentTool and isRiotShield(currentTool) then usingShield = true end
		if isController and usingShield then
			isShielding = true
			if equipShieldRemote and typeof(equipShieldRemote.FireServer) == "function" then pcall(function() equipShieldRemote:FireServer() end) end
		else
			if isMouse then
				task.spawn(function() shootWeapon() end)
			else
				if isController then
					if currentTool and (toolAttributes.ToolType == "Gun" or (currentTool and currentTool:GetAttribute("ToolType") == "Gun")) then
						isShooting = true
						if currentTool and toolAttributes.AutoFire == false then shootWeapon() end
					else
						if isTouch then
							isShooting = true
							if currentTool and toolAttributes.AutoFire == false then shootWeapon() end
						end
					end
				else
					isShooting = true
					if currentTool and toolAttributes.AutoFire == false then shootWeapon() end
				end
			end
		end
	elseif k == _G.Settings.Keybinds.Reload or k == Enum.KeyCode.R then
		safe_call(do_kpress, VK_R)
	elseif k == Enum.KeyCode.ButtonR1 then
		Backpack_cycleTool(1)
	elseif k == Enum.KeyCode.ButtonL1 then
		Backpack_cycleTool(-1)
	elseif k == _G.Settings.Keybinds.Crouch then
		safe_call(do_kpress, VK_C)
	elseif k == _G.Settings.Keybinds.Sprint then
		isSprint = not isSprint
		local hum = getHumanoid()
		if hum then hum.WalkSpeed = (isSprint and SPRINT_SPEED) or WALK_SPEED end
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	local k = input.KeyCode
	if k == Enum.KeyCode.ButtonR2 then
		if isShielding then
			isShielding = false
			if equipShieldRemote and typeof(equipShieldRemote.FireServer) == "function" then pcall(function() equipShieldRemote:FireServer(false) end) end
		else
			isShooting = false
		end
	elseif k == _G.Settings.Keybinds.Reload or k == Enum.KeyCode.R then
		safe_call(do_krelease, VK_R)
	elseif k == _G.Settings.Keybinds.Crouch then
		safe_call(do_krelease, VK_C)
		local hum = getHumanoid()
		if hum then
			hum.WalkSpeed = (isSprint and SPRINT_SPEED) or WALK_SPEED
		end
	end
end)

RunService.RenderStepped:Connect(function()
	if isShooting and currentTool and toolAttributes.AutoFire == true then shootWeapon() end
end)