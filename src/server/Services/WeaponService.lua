-- WeaponService: what each player carries, always visible to everyone.
--  * Holstered (calm): the class weapon rests on the body - cutlass in its scabbard at the left hip, hammer across the
--    back, the folded storm staff and the powder pouch on the belt.
--  * Drawn (fighting): attacking or casting puts it in the hands for 8 s (scabbard stays at the hip), then it goes back.
--  * Always worn: the Sharpshooter's satchel on a strap across the chest.
--  * Brawler (Knuckles = Fist Style) and Sea Cook (Shoes = Leg Style) fight bare-handed / bare-legged: nothing is mounted
--    (owner, v0.22.3: no brass knuckles, no shin guards; plain punches and kicks).
-- Models: ReplicatedStorage.Assets.Weapons/<Name> (tools/blender/voxel_weapons.py; long axis along Z, striking end -Z).
-- Character attributes: Weapon = <WeaponType>, WeaponOut = true while drawn (CharAnim plays the stance from these).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local WeaponInfo = require(ReplicatedStorage.Shared.Modules.WeaponInfo)
local Formulas = require(ReplicatedStorage.Shared.Modules.Formulas)
local Net = require(ReplicatedStorage.Shared.Modules.Net)

local WS = {}
local R

local HOLSTER_AFTER = 8 -- seconds without attacking
local A = CFrame.Angles
local rad = math.rad
-- in the hands. Hands: -Y runs down to the fingers, -Z is forward. The cutlass tilts down a little like a real grip.
local DRAWN = {
	Sword = { { "RightHand", "Sword", CFrame.new(0, -0.15, 0) * A(rad(-35), 0, 0) }, { "LowerTorso", "Scabbard", CFrame.new(-1.1, -0.3, 0.35) * A(rad(-143), 0, 0) } },
	Hammer = { { "RightHand", "Hammer", CFrame.new(0, -0.15, 0) } },
	StormBaton = { { "RightHand", "StormBaton", CFrame.new(0, -0.15, 0) } },
	Slingshot = { { "LeftHand", "Slingshot", CFrame.new(0, -0.15, 0) } },
	MedKit = { { "RightHand", "MedKit", CFrame.new(0, -0.45, -0.1) } },
	Knuckles = {},
	Shoes = {},
	Fists = {},
}
-- at rest (LowerTorso: x = right, -z = front; UpperTorso back = +z)
local HOLSTERED = {
	Sword = { { "LowerTorso", "SwordSheathed", CFrame.new(-1.1, -0.3, 0.35) * A(rad(-143), 0, 0) } },
	-- hammer on the back: head down toward the ground, handle up by the right shoulder (where the right hand grabs it)
	Hammer = { { "UpperTorso", "Hammer", CFrame.new(0.55, 0.75, 0.7) * A(0, 0, rad(-20)) * A(rad(-90), 0, 0) * A(0, 0, rad(90)) } },
	StormBaton = { { "LowerTorso", "StormBatonPack", CFrame.new(1.12, -0.35, 0.05) * A(rad(-90), 0, 0) } },
	MedKit = { { "LowerTorso", "MedKit", CFrame.new(1.1, -0.35, -0.15) } },
	Slingshot = {},
	Knuckles = {},
	Shoes = {},
	Fists = {},
}
-- worn the whole time for these weapon types
local WORN = {
	Slingshot = { { "LowerTorso", "SlingBag", CFrame.new(-1.15, -0.55, 0.15) * A(0, rad(90), 0) } },
}

local lastUse = {} -- player -> os.clock() of the last attack

local function template(name)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Weapons")
	return folder and folder:FindFirstChild(name)
end

local function clear(char, tag)
	for _, c in ipairs(char:GetChildren()) do
		if c:GetAttribute(tag) then
			c:Destroy()
		end
	end
end

local function weld(model, limb)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0 = limb
			w.Part1 = p
			w.Parent = p
		end
	end
end

local function mount(char, list, tag)
	for _, m in ipairs(list or {}) do
		local limb = char:FindFirstChild(m[1])
		local tpl = template(m[2])
		if limb and tpl then
			local w = tpl:Clone()
			w.Name = tag .. "_" .. m[2]
			w:SetAttribute(tag, m[2])
			w:PivotTo(limb.CFrame * m[3])
			weld(w, limb)
			w.Parent = char
		end
	end
end

-- the satchel strap: two thin bands over the right shoulder, diagonally across chest and back to the left hip
local function strap(char)
	local torso = char:FindFirstChild("UpperTorso")
	if not torso then
		return
	end
	local folder = Instance.new("Model")
	folder.Name = "GVGear_Strap"
	folder:SetAttribute("GVGear", "Strap")
	for _, z in ipairs({ -0.53, 0.53 }) do
		local band = Instance.new("Part")
		band.Name = "Strap"
		band.Size = Vector3.new(0.32, 2.5, 0.08)
		band.Color = Color3.fromRGB(110, 70, 42)
		band.Material = Enum.Material.Fabric
		-- one strap seen from front and back runs the same way (right shoulder -> left hip): same angle on both
		-- bands (v0.25.8, owner: the front one was mirrored and pointed away from the satchel)
		band.CFrame = torso.CFrame * CFrame.new(-0.05, -0.05, z) * A(0, 0, rad(-38))
		band.Parent = folder
	end
	weld(folder, torso)
	folder.Parent = char
end

-- put the right things where they belong for this character's weapon type and state
local function dress(char, wType, out)
	clear(char, "GVWeapon")
	mount(char, out and DRAWN[wType] or HOLSTERED[wType], "GVWeapon")
	char:SetAttribute("Weapon", wType)
	char:SetAttribute("WeaponOut", out == true)
end

local function wearGear(char, wType)
	if char:GetAttribute("GearFor") == wType then
		return
	end
	clear(char, "GVGear")
	mount(char, WORN[wType], "GVGear")
	if wType == "Slingshot" then
		strap(char)
	end
	char:SetAttribute("GearFor", wType)
end

-- v0.25.14 (owner): equipped headgear / armor / accessory show on the character as welded voxel blocks.
-- Entries: { limb, size (x limb size), offset (x limb size), color }. The voxel head is "VoxelHead" (Head is hidden);
-- hats sit above the hair (offsets > 0.5 of the head).
local C = Color3.fromRGB
local OUTFIT = {
	Bandana = { { "Head", Vector3.new(1.32, 0.2, 1.32), Vector3.new(0, 0.22, 0), C(210, 50, 55) }, { "Head", Vector3.new(0.26, 0.26, 0.26), Vector3.new(0, 0.2, 0.7), C(190, 40, 45) }, { "Head", Vector3.new(0.12, 0.42, 0.08), Vector3.new(0.1, -0.05, 0.72), C(190, 40, 45) } },
	SunHat = { { "Head", Vector3.new(1.9, 0.08, 1.9), Vector3.new(0, 0.62, 0), C(240, 234, 214) }, { "Head", Vector3.new(1.05, 0.32, 1.05), Vector3.new(0, 0.8, 0), C(240, 234, 214) }, { "Head", Vector3.new(1.08, 0.1, 1.08), Vector3.new(0, 0.7, 0), C(70, 150, 220) }, { "Head", Vector3.new(0.2, 0.2, 0.2), Vector3.new(0.45, 0.74, -0.42), C(255, 120, 170) } },
	MarineCap = { { "Head", Vector3.new(1.3, 0.28, 1.3), Vector3.new(0, 0.68, 0), C(245, 245, 250) }, { "Head", Vector3.new(1.32, 0.1, 1.32), Vector3.new(0, 0.58, 0), C(40, 60, 130) }, { "Head", Vector3.new(0.9, 0.06, 0.45), Vector3.new(0, 0.56, -0.75), C(40, 60, 130) }, { "Head", Vector3.new(0.2, 0.14, 0.05), Vector3.new(0, 0.68, -0.66), C(255, 200, 60) } },
	ClownNose = { { "Head", Vector3.new(0.22, 0.22, 0.22), Vector3.new(0, -0.05, -0.56), C(240, 40, 40) } },
	SailorVest = { { "UpperTorso", Vector3.new(0.42, 1.02, 1.08), Vector3.new(-0.3, 0, 0), C(60, 110, 200) }, { "UpperTorso", Vector3.new(0.42, 1.02, 1.08), Vector3.new(0.3, 0, 0), C(60, 110, 200) }, { "UpperTorso", Vector3.new(1.06, 0.12, 1.1), Vector3.new(0, 0.46, 0), C(245, 245, 250) } },
	MarineCoat = { { "UpperTorso", Vector3.new(1.08, 1.04, 1.1), Vector3.zero, C(240, 240, 245) }, { "UpperTorso", Vector3.new(0.12, 1.05, 0.06), Vector3.new(0, 0, -0.54), C(40, 60, 130) }, { "UpperTorso", Vector3.new(0.3, 0.08, 0.4), Vector3.new(0.42, 0.52, 0), C(255, 200, 60) }, { "UpperTorso", Vector3.new(0.3, 0.08, 0.4), Vector3.new(-0.42, 0.52, 0), C(255, 200, 60) }, { "LowerTorso", Vector3.new(1.0, 2.6, 0.12), Vector3.new(0, -0.9, 0.55), C(240, 240, 245) } },
	CaptainCoat = { { "UpperTorso", Vector3.new(1.08, 1.04, 1.1), Vector3.zero, C(165, 38, 45) }, { "UpperTorso", Vector3.new(0.1, 1.05, 0.06), Vector3.new(-0.12, 0, -0.54), C(255, 200, 60) }, { "UpperTorso", Vector3.new(0.1, 1.05, 0.06), Vector3.new(0.12, 0, -0.54), C(255, 200, 60) }, { "UpperTorso", Vector3.new(0.32, 0.1, 0.42), Vector3.new(0.42, 0.52, 0), C(255, 200, 60) }, { "UpperTorso", Vector3.new(0.32, 0.1, 0.42), Vector3.new(-0.42, 0.52, 0), C(255, 200, 60) }, { "LowerTorso", Vector3.new(1.0, 2.8, 0.12), Vector3.new(0, -1.0, 0.55), C(150, 32, 40) } },
	SharkscaleMail = { { "UpperTorso", Vector3.new(1.06, 1.03, 1.08), Vector3.zero, C(90, 120, 150) }, { "UpperTorso", Vector3.new(1.07, 0.1, 1.09), Vector3.new(0, 0.2, 0), C(60, 85, 110) }, { "UpperTorso", Vector3.new(1.07, 0.1, 1.09), Vector3.new(0, -0.15, 0), C(60, 85, 110) }, { "UpperTorso", Vector3.new(1.07, 0.1, 1.09), Vector3.new(0, -0.4, 0), C(130, 165, 195) } },
	CompassCharm = { { "UpperTorso", Vector3.new(0.22, 0.22, 0.06), Vector3.new(0.25, 0.15, -0.56), C(255, 200, 60) } },
	TangerinePin = { { "UpperTorso", Vector3.new(0.2, 0.2, 0.06), Vector3.new(-0.28, 0.25, -0.56), C(255, 150, 40) } },
	SharkToothNecklace = { { "UpperTorso", Vector3.new(0.1, 0.16, 0.06), Vector3.new(-0.2, 0.38, -0.56), C(250, 248, 235) }, { "UpperTorso", Vector3.new(0.1, 0.2, 0.06), Vector3.new(0, 0.36, -0.56), C(250, 248, 235) }, { "UpperTorso", Vector3.new(0.1, 0.16, 0.06), Vector3.new(0.2, 0.38, -0.56), C(250, 248, 235) } },
	SeastoneBracer = { { "RightLowerArm", Vector3.new(1.15, 0.45, 1.15), Vector3.zero, C(60, 70, 90) } },
	SeastoneShackle = { { "RightLowerArm", Vector3.new(1.18, 0.5, 1.18), Vector3.zero, C(50, 58, 78) }, { "LeftLowerArm", Vector3.new(1.18, 0.5, 1.18), Vector3.zero, C(50, 58, 78) } },
}

local function wearOutfit(char, p)
	local ids = {}
	local hide = p.settings and p.settings.hideGear == true
	for _, slot in ipairs(hide and {} or { "headgear", "armor", "accessory" }) do
		local uid = p.equipment and p.equipment[slot]
		local e = uid and Formulas.FindItem(p, uid)
		if e and OUTFIT[e.id] then
			table.insert(ids, e.id)
		end
	end
	local key = table.concat(ids, ",")
	if char:GetAttribute("OutfitKey") == key then
		return
	end
	clear(char, "GVOutfit")
	for _, id in ipairs(ids) do
		local model = Instance.new("Model")
		model.Name = "GVOutfit_" .. id
		model:SetAttribute("GVOutfit", id)
		for _, b in ipairs(OUTFIT[id]) do
			local limb = (b[1] == "Head" and char:FindFirstChild("VoxelHead")) or char:FindFirstChild(b[1])
			if limb then
				local part = Instance.new("Part")
				part.Name = "Outfit"
				part.Size = limb.Size * b[2]
				part.CFrame = limb.CFrame * CFrame.new(limb.Size * b[3])
				part.Color = b[4]
				part.Material = Enum.Material.SmoothPlastic
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.Massless = true
				part.TopSurface = Enum.SurfaceType.Smooth
				part.BottomSurface = Enum.SurfaceType.Smooth
				part.Parent = model
				local w = Instance.new("WeldConstraint")
				w.Part0 = limb
				w.Part1 = part
				w.Parent = part
			end
		end
		model.Parent = char
	end
	char:SetAttribute("OutfitKey", key)
end

local function typeOf(player)
	return WeaponInfo.TypeOf(R.DataService.Get(player))
end

-- called on every basic attack / skill: weapon into the hands (or swap it if the class changed)
function WS.Draw(player, wType)
	local char = player.Character
	if not char or not wType then
		return
	end
	lastUse[player] = os.clock()
	wearGear(char, WeaponInfo.ClassWeapon(R.DataService.Get(player)))
	if char:GetAttribute("WeaponOut") and char:GetAttribute("Weapon") == wType then
		return
	end
	dress(char, wType, true)
	-- the draw moment (the folded staff snaps out to full length, blades come out of the scabbard...)
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then
		Net.FX("WeaponDraw", { char = char, weapon = wType, pos = root.Position }, root.Position, 150)
	end
end

function WS.Holster(player)
	lastUse[player] = nil
	local char = player.Character
	if char then
		dress(char, typeOf(player), false)
	end
end

function WS.Init(registry)
	R = registry
end

function WS.Start()
	Players.PlayerRemoving:Connect(function(p)
		lastUse[p] = nil
	end)
	-- every second: put weapons away after a calm spell, and keep holstered gear in sync with class / equipment
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for _, p in ipairs(Players:GetPlayers()) do
				local char = p.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if char and hum and hum.Health > 0 and char:FindFirstChild("LowerTorso") and R.DataService.Get(p) then
					local wType = typeOf(p)
					local t = lastUse[p]
					if t and now - t > HOLSTER_AFTER then
						lastUse[p] = nil
						dress(char, wType, false)
					elseif not t and (char:GetAttribute("Weapon") ~= wType or char:GetAttribute("WeaponOut") == nil) then
						dress(char, wType, false) -- fresh character, class switch or new weapon equipped
					end
					pcall(wearGear, char, WeaponInfo.ClassWeapon(R.DataService.Get(p)))
					pcall(wearOutfit, char, R.DataService.Get(p))
				end
			end
		end
	end)
end

return WS
