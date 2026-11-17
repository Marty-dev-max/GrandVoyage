-- WeaponService: the class weapon appears in the player's hands while they fight and is put away after a calm spell.
-- Models: ReplicatedStorage.Assets.Weapons/<WeaponType> (tools/blender/voxel_weapons.py, pivot on the grip, striking
-- end along -Z). Welded on the server, so everyone sees them. Character attributes drive the client's stance animation
-- (CharAnim): Weapon = <WeaponType>, WeaponOut = true while drawn.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local WS = {}

local HOLSTER_AFTER = 8 -- seconds without attacking
-- where each weapon goes: { part, offset in that part's space }. Hands: -Y runs down to the fingers, -Z is forward.
local MOUNTS = {
	Sword = { { "RightHand", CFrame.new(0, -0.15, 0) } },
	Hammer = { { "RightHand", CFrame.new(0, -0.15, 0) } },
	StormBaton = { { "RightHand", CFrame.new(0, -0.15, 0) } },
	Slingshot = { { "LeftHand", CFrame.new(0, -0.15, 0) } },
	MedKit = { { "RightHand", CFrame.new(0, -0.75, 0) } },
	Knuckles = { { "RightHand", CFrame.new(0, -0.1, 0) }, { "LeftHand", CFrame.new(0, -0.1, 0) } },
	Shoes = { { "RightLowerLeg", CFrame.new(0, -0.1, 0) }, { "LeftLowerLeg", CFrame.new(0, -0.1, 0) } },
}

local lastUse = {} -- player -> os.clock()

local function template(wType)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Weapons")
	return folder and folder:FindFirstChild(wType)
end

local function holster(char)
	if not char then
		return
	end
	for _, c in ipairs(char:GetChildren()) do
		if c:GetAttribute("GVWeapon") then
			c:Destroy()
		end
	end
	char:SetAttribute("WeaponOut", false)
end

local function mount(char, wType)
	local tpl = template(wType)
	for _, m in ipairs(MOUNTS[wType] or {}) do
		local limb = char:FindFirstChild(m[1])
		if tpl and limb then
			local w = tpl:Clone()
			w.Name = "Weapon_" .. m[1]
			w:SetAttribute("GVWeapon", wType)
			w:PivotTo(limb.CFrame * m[2])
			for _, p in ipairs(w:GetDescendants()) do
				if p:IsA("BasePart") then
					p.Anchored = false
					p.CanCollide = false
					p.CanQuery = false
					p.CanTouch = false
					p.Massless = true
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = limb
					weld.Part1 = p
					weld.Parent = p
				end
			end
			w.Parent = char
		end
	end
end

-- called on every basic attack / skill: draw the weapon (or swap it if the class changed)
function WS.Draw(player, wType)
	local char = player.Character
	if not char or not wType then
		return
	end
	lastUse[player] = os.clock()
	if char:GetAttribute("WeaponOut") and char:GetAttribute("Weapon") == wType then
		return
	end
	holster(char)
	char:SetAttribute("Weapon", wType)
	mount(char, wType)
	char:SetAttribute("WeaponOut", true)
end

function WS.Holster(player)
	lastUse[player] = nil
	holster(player.Character)
end

function WS.Init(_registry) end

function WS.Start()
	Players.PlayerRemoving:Connect(function(p)
		lastUse[p] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for p, t in pairs(lastUse) do
				if now - t > HOLSTER_AFTER then
					lastUse[p] = nil
					holster(p.Character)
				end
			end
		end
	end)
end

return WS
