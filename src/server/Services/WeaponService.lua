-- WeaponService: what each player carries, always visible to everyone.
--  * Holstered (calm): the class weapon rests on the body - cutlass in its scabbard at the left hip, hammer across the
--    back, the folded storm staff and the powder pouch on the belt; knuckles are tucked away.
--  * Drawn (fighting): attacking or casting puts it in the hands for 8 s (scabbard stays at the hip), then it goes back.
--  * Always worn: Sea Cook shin guards, the Sharpshooter's satchel on a strap across the chest.
-- Models: ReplicatedStorage.Assets.Weapons/<Name> (tools/blender/voxel_weapons.py; long axis along Z, striking end -Z).
-- Character attributes: Weapon = <WeaponType>, WeaponOut = true while drawn (CharAnim plays the stance from these).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local WeaponInfo = require(ReplicatedStorage.Shared.Modules.WeaponInfo)
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
	Knuckles = { { "RightHand", "Knuckles", CFrame.new(0, -0.1, 0) }, { "LeftHand", "Knuckles", CFrame.new(0, -0.1, 0) } },
	Shoes = {},
}
-- at rest (LowerTorso: x = right, -z = front; UpperTorso back = +z)
local HOLSTERED = {
	Sword = { { "LowerTorso", "SwordSheathed", CFrame.new(-1.1, -0.3, 0.35) * A(rad(-143), 0, 0) } },
	Hammer = { { "UpperTorso", "Hammer", CFrame.new(0.25, -1.0, 0.7) * A(0, 0, rad(-20)) * A(rad(90), 0, 0) * A(0, 0, rad(90)) } },
	StormBaton = { { "LowerTorso", "StormBatonPack", CFrame.new(1.12, -0.35, 0.05) * A(rad(-90), 0, 0) } },
	MedKit = { { "LowerTorso", "MedKit", CFrame.new(1.1, -0.35, -0.15) } },
	Slingshot = {},
	Knuckles = {},
	Shoes = {},
}
-- worn the whole time for these weapon types
local WORN = {
	Shoes = { { "RightLowerLeg", "Shoes", CFrame.new(0, -0.1, 0) }, { "LeftLowerLeg", "Shoes", CFrame.new(0, -0.1, 0) } },
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
		band.CFrame = torso.CFrame * CFrame.new(-0.05, -0.05, z) * A(0, 0, rad(z < 0 and 38 or -38))
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
	wearGear(char, wType)
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
					pcall(wearGear, char, wType)
				end
			end
		end
	end)
end

return WS
