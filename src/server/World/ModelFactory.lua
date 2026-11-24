-- ModelFactory: procedural chibi models (placeholders until Blender models arrive)
-- A model at ReplicatedStorage.Assets.Monsters.<MonsterId> automatically replaces the placeholder
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MF = {}

local function part(parent, shape, size, color, cf, opts)
	local p = Instance.new("Part")
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = (opts and opts.material) or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = cf
	p.CanCollide = opts and opts.collide or false
	p.Massless = true
	p.CastShadow = true
	p.Name = (opts and opts.name) or "Part"
	p.Parent = parent
	return p
end
MF.Part = part

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function eyes(model, head, size, forwardOffset, spacing, height)
	local white = Color3.new(1, 1, 1)
	for _, side in ipairs({ -1, 1 }) do
		local cf = head.CFrame * CFrame.new(side * spacing, height, -forwardOffset)
		local e = part(model, Enum.PartType.Ball, Vector3.new(size, size, size), white, cf)
		local pupil = part(model, Enum.PartType.Ball, Vector3.new(size * 0.55, size * 0.55, size * 0.55), Color3.fromRGB(25, 25, 35), cf * CFrame.new(0, 0, -size * 0.3))
		weld(head, e)
		weld(head, pupil)
	end
end

local function hat(model, head, kind, s)
	if not kind then
		return
	end
	local top = head.CFrame * CFrame.new(0, head.Size.Y * 0.45, 0)
	local h
	if kind == "marine" then
		h = part(model, Enum.PartType.Cylinder, Vector3.new(0.5 * s, 2.2 * s, 2.2 * s), Color3.new(1, 1, 1), top * CFrame.Angles(0, 0, math.pi / 2))
		local band = part(model, Enum.PartType.Cylinder, Vector3.new(0.25 * s, 2.25 * s, 2.25 * s), Color3.fromRGB(40, 90, 200), top * CFrame.new(0, -0.2 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))
		weld(head, band)
	elseif kind == "bandana" then
		h = part(model, Enum.PartType.Ball, Vector3.new(2.1 * s, 1.1 * s, 2.1 * s), Color3.fromRGB(220, 60, 60), top * CFrame.new(0, -0.3 * s, 0))
	elseif kind == "clown" then
		h = part(model, Enum.PartType.Ball, Vector3.new(0.7 * s, 0.7 * s, 0.7 * s), Color3.fromRGB(255, 40, 40), head.CFrame * CFrame.new(0, 0, -head.Size.Z * 0.5))
	elseif kind == "cat" then
		for _, side in ipairs({ -1, 1 }) do
			local ear = part(model, Enum.PartType.Block, Vector3.new(0.5 * s, 0.8 * s, 0.3 * s), Color3.fromRGB(40, 35, 45), top * CFrame.new(side * 0.6 * s, 0.2 * s, 0) * CFrame.Angles(0, 0, side * -0.3))
			weld(head, ear)
		end
		return
	elseif kind == "captain" then
		-- tricorn: dark crown + wide brim + gold band, so quest guides read from far away
		h = part(model, Enum.PartType.Cylinder, Vector3.new(1.1 * s, 2.0 * s, 2.0 * s), Color3.fromRGB(40, 30, 30), top * CFrame.new(0, 0.3 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))
		local brim = part(model, Enum.PartType.Cylinder, Vector3.new(0.2 * s, 3.4 * s, 3.4 * s), Color3.fromRGB(50, 36, 34), top * CFrame.new(0, -0.15 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))
		weld(head, brim)
		local band = part(model, Enum.PartType.Cylinder, Vector3.new(0.25 * s, 2.05 * s, 2.05 * s), Color3.fromRGB(255, 200, 60), top * CFrame.new(0, 0.05 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))
		weld(head, band)
	elseif kind == "helmet" then
		h = part(model, Enum.PartType.Ball, Vector3.new(2.3 * s, 1.6 * s, 2.3 * s), Color3.fromRGB(150, 150, 160), top * CFrame.new(0, -0.35 * s, 0), { material = Enum.Material.Metal })
	end
	if h then
		weld(head, h)
	end
end

-- v0.25.32 (owner): humanoid monsters are voxel characters like the players: an R15 rig dressed by VoxelChar
-- (Config/MonsterLooks) + their accessories (Config/Accessories, the same models players wear when they get them).
-- One template per monster id is built (CreateHumanoidModelFromDescription yields) and cloned after that.
local templates = {}
function MF.VoxelMonster(def)
	local MonsterLooks = require(ReplicatedStorage.Shared.Config.MonsterLooks)
	local look = MonsterLooks.Look(def.id)
	if not look then
		return nil
	end
	if not templates[def.id] then
		local VoxelChar = require(ReplicatedStorage.Shared.Modules.VoxelChar)
		local Accessory = require(ReplicatedStorage.Shared.Modules.Accessory)
		local e = MonsterLooks.ById[def.id]
		local desc = Instance.new("HumanoidDescription")
		desc.BodyTypeScale = 0
		desc.ProportionScale = 0
		local m = game:GetService("Players"):CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		local animate = m:FindFirstChild("Animate")
		if animate then
			animate:Destroy()
		end
		local race, variant = MonsterLooks.Race(def.id)
		VoxelChar.Apply(m, look, race, variant, nil)
		for _, id in ipairs(e.acc or {}) do
			Accessory.Wear(m, id)
		end
		if e.held then
			Accessory.Wear(m, e.held)
		end
		local hum = m:FindFirstChildOfClass("Humanoid")
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.BreakJointsOnDeath = false
		local s = (def.style and def.style.scale) or 1
		if math.abs(s - 1) > 0.01 then
			m:ScaleTo(s)
		end
		m:SetAttribute("RealModel", true)
		m:SetAttribute("R15Mob", true)
		m:SetAttribute("AttackClip", e.attack or "Brawler_Hook")
		templates[def.id] = m
	end
	local m = templates[def.id]:Clone()
	m.Name = def.id
	return m
end

-- Build a monster: Model + HumanoidRootPart + Humanoid
function MF.Monster(def)
	local okV, voxel = pcall(MF.VoxelMonster, def)
	if okV and voxel then
		return voxel
	elseif not okV then
		warn("[ModelFactory] voxel monster " .. tostring(def.id) .. " failed: " .. tostring(voxel))
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local custom = assets and assets:FindFirstChild("Monsters") and assets.Monsters:FindFirstChild(def.id)
	if custom then
		local m = custom:Clone()
		m.Name = def.id
		m:SetAttribute("RealModel", true)
		return m
	end

	local style = def.style or {}
	local s = style.scale or 1
	local c = style.color or Color3.fromRGB(200, 200, 200)
	local shape = style.shape or "humanoid"
	local model = Instance.new("Model")
	model.Name = def.id

	local rootSize = Vector3.new(2.4, 2.4, 2.4) * s
	local root = part(model, Enum.PartType.Block, rootSize, c, CFrame.new(0, 0, 0), { name = "HumanoidRootPart" })
	root.Transparency = 1
	root.Massless = false
	root.CanCollide = true
	local base = root.CFrame
	local body, head

	if shape == "crab" then
		body = part(model, Enum.PartType.Ball, Vector3.new(3.2, 1.8, 2.6) * s, c, base)
		for _, side in ipairs({ -1, 1 }) do
			local claw = part(model, Enum.PartType.Ball, Vector3.new(1.3, 1.1, 1.3) * s, c:Lerp(Color3.new(1, 1, 1), 0.15), base * CFrame.new(side * 1.9 * s, 0.4 * s, -1.2 * s))
			weld(body, claw)
			for i = -1, 1 do
				local leg = part(model, Enum.PartType.Block, Vector3.new(1.2, 0.25, 0.25) * s, c, base * CFrame.new(side * 1.6 * s, -0.7 * s, i * 0.6 * s) * CFrame.Angles(0, 0, side * 0.5))
				weld(body, leg)
			end
		end
		head = body
		eyes(model, body, 0.6 * s, 1.1 * s, 0.5 * s, 0.9 * s)
	elseif shape == "snail" then
		body = part(model, Enum.PartType.Block, Vector3.new(2.2, 1.2, 4.4) * s, Color3.fromRGB(255, 220, 170), base * CFrame.new(0, -0.6 * s, 0))
		local shell = part(model, Enum.PartType.Ball, Vector3.new(3, 3, 3) * s, c, base * CFrame.new(0, 1.1 * s, 0.7 * s))
		weld(body, shell)
		local swirl = part(model, Enum.PartType.Ball, Vector3.new(1.4, 1.4, 1.4) * s, c:Lerp(Color3.new(1, 1, 1), 0.35), shell.CFrame * CFrame.new(1.05 * s, 0, 0))
		weld(shell, swirl)
		head = part(model, Enum.PartType.Ball, Vector3.new(1.6, 1.6, 1.6) * s, Color3.fromRGB(255, 220, 170), base * CFrame.new(0, 0.4 * s, -1.9 * s))
		weld(body, head)
		local receiver = part(model, Enum.PartType.Block, Vector3.new(1.8, 0.4, 0.5) * s, Color3.fromRGB(40, 40, 40), base * CFrame.new(0, 2.8 * s, 0.7 * s))
		weld(shell, receiver)
		eyes(model, head, 0.4 * s, 0.7 * s, 0.35 * s, 0.6 * s)
	elseif shape == "seaking" then
		body = part(model, Enum.PartType.Ball, Vector3.new(4, 4, 4) * s, c, base * CFrame.new(0, 1 * s, 0))
		local prev = body
		for i = 1, 4 do
			local seg = part(model, Enum.PartType.Ball, Vector3.new(3.4, 3.4, 3.4) * s * (1 - i * 0.12), c:Lerp(Color3.new(0, 0, 0), i * 0.05), base * CFrame.new(0, (1 - i * 0.6) * s, i * 2.4 * s))
			weld(prev, seg)
		end
		local belly = part(model, Enum.PartType.Ball, Vector3.new(3, 3, 3) * s, Color3.fromRGB(250, 230, 180), base * CFrame.new(0, 0.6 * s, -0.8 * s))
		weld(body, belly)
		head = body
		eyes(model, body, 1 * s, 1.8 * s, 0.9 * s, 0.9 * s)
		for _, side in ipairs({ -1, 1 }) do
			local fin = part(model, Enum.PartType.Block, Vector3.new(0.3, 2.2, 1.6) * s, Color3.fromRGB(255, 120, 80), base * CFrame.new(side * 2 * s, 2.5 * s, 0.5 * s) * CFrame.Angles(0, 0, side * 0.5))
			weld(body, fin)
		end
	elseif shape == "boar" or shape == "wolf" or shape == "lion" or shape == "cat" then
		body = part(model, Enum.PartType.Ball, Vector3.new(2.6, 2.2, 3.6) * s, c, base)
		head = part(model, Enum.PartType.Ball, Vector3.new(2.2, 2.1, 2.1) * s, c:Lerp(Color3.new(1, 1, 1), 0.08), base * CFrame.new(0, 0.7 * s, -1.9 * s))
		weld(body, head)
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local leg = part(model, Enum.PartType.Block, Vector3.new(0.6, 1.2, 0.6) * s, c:Lerp(Color3.new(0, 0, 0), 0.2), base * CFrame.new(sx * 0.8 * s, -1.1 * s, sz * 1.1 * s))
				weld(body, leg)
			end
		end
		if shape == "boar" then
			for _, sx in ipairs({ -1, 1 }) do
				local tusk = part(model, Enum.PartType.Block, Vector3.new(0.2, 0.6, 0.2) * s, Color3.new(1, 1, 0.95), head.CFrame * CFrame.new(sx * 0.5 * s, -0.3 * s, -1 * s) * CFrame.Angles(0.4, 0, 0))
				weld(head, tusk)
			end
		elseif shape == "lion" then
			local mane = part(model, Enum.PartType.Ball, Vector3.new(3.2, 3, 1.6) * s, Color3.fromRGB(180, 90, 40), head.CFrame * CFrame.new(0, 0, 0.5 * s))
			weld(head, mane)
		elseif shape == "wolf" or shape == "cat" then
			for _, sx in ipairs({ -1, 1 }) do
				local ear = part(model, Enum.PartType.Block, Vector3.new(0.4, 0.8, 0.3) * s, c, head.CFrame * CFrame.new(sx * 0.6 * s, 1.1 * s, 0))
				weld(head, ear)
			end
		end
		eyes(model, head, 0.55 * s, 0.95 * s, 0.45 * s, 0.25 * s)
	else
		-- humanoid / monkey / fishman: big head, small body (chibi)
		local skin = shape == "fishman" and c or Color3.fromRGB(255, 215, 180)
		if shape == "monkey" then
			skin = c:Lerp(Color3.new(1, 0.9, 0.8), 0.4)
		end
		body = part(model, Enum.PartType.Block, Vector3.new(2, 2, 1.3) * s, c, base * CFrame.new(0, -0.2 * s, 0))
		head = part(model, Enum.PartType.Ball, Vector3.new(2.4, 2.4, 2.4) * s, skin, base * CFrame.new(0, 2 * s, 0))
		weld(body, head)
		for _, sx in ipairs({ -1, 1 }) do
			local arm = part(model, Enum.PartType.Block, Vector3.new(0.6, 1.6, 0.6) * s, skin, base * CFrame.new(sx * 1.35 * s, -0.2 * s, 0))
			arm.Name = sx < 0 and "LeftArm" or "RightArm"
			weld(body, arm)
			local leg = part(model, Enum.PartType.Block, Vector3.new(0.75, 1.1, 0.75) * s, c:Lerp(Color3.new(0, 0, 0), 0.35), base * CFrame.new(sx * 0.5 * s, -1.75 * s, 0))
			weld(body, leg)
		end
		if shape == "fishman" then
			local fin = part(model, Enum.PartType.Block, Vector3.new(0.3, 1.4, 1.4) * s, c:Lerp(Color3.new(0, 0, 0), 0.25), head.CFrame * CFrame.new(0, 1.2 * s, 0.3 * s) * CFrame.Angles(0.6, 0, 0))
			weld(head, fin)
			if def.isBoss then
				local nose = part(model, Enum.PartType.Block, Vector3.new(0.35, 0.35, 2.2) * s, Color3.fromRGB(230, 230, 230), head.CFrame * CFrame.new(0, 0, -1.8 * s))
				weld(head, nose)
			end
		elseif shape == "monkey" then
			local tail = part(model, Enum.PartType.Block, Vector3.new(0.3, 0.3, 1.8) * s, c, base * CFrame.new(0, -0.8 * s, 1.2 * s) * CFrame.Angles(0.6, 0, 0))
			weld(body, tail)
		end
		eyes(model, head, 0.55 * s, 1.05 * s, 0.45 * s, 0.15 * s)
		hat(model, head, style.hat, s)
	end
	weld(root, body)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root then
			weld(root, d)
		end
	end

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	-- HipHeight = distance from the bottom of HumanoidRootPart to the ground
	if shape == "crab" or shape == "snail" then
		hum.HipHeight = 0.1
	elseif shape == "seaking" then
		hum.HipHeight = 0.5
	elseif shape == "boar" or shape == "wolf" or shape == "lion" or shape == "cat" then
		hum.HipHeight = 0.5 * s
	else
		hum.HipHeight = 1.1 * s
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.Parent = model
	model.PrimaryPart = root
	return model
end

-- Town NPC (with ProximityPrompt)
-- NPCs (v0.25.0, owner: everything voxel): built with the players' own voxel character system (Shared/Modules/VoxelChar)
-- so they share the blocky body, anime face and hair. The outfit follows the role (title keywords + hat), colors come
-- from `color`, and hair / eyes / mouth / skin are picked from the name (stable: the same NPC always looks the same).
-- The pivot sits 2.6 studs above the feet (where the old chibi models had theirs), so callers place them unchanged.
local NPC_STYLE = {
	-- keyword in the title -> { shirt, pants, shoes } (names from Config/Looks)
	{ "Blacksmith", "Armor Vest", "Overalls", "Boots" },
	{ "Store", "Polo", "Long Pants", "Sneakers" },
	{ "Tavern", "Cook Apron", "Long Pants", "Clogs" },
	{ "Gull", "Sailor Stripes", "Rolled Cuffs", "Sandals" },
	{ "Shipwright", "Overalls", "Cargo", "Buckle Boots" },
	{ "Job", "Captain Coat", "Wide Hakama", "Tall Boots" }, -- v0.25.118: a long coat (see NPC_LOOK)
	{ "Guild", "Captain Coat", "Long Pants", "Tall Boots" },
	{ "Bounty", "Open Vest", "Sash Pants", "Boots" },
	{ "Fruit", "Belted Tunic", "Baggy", "Sandals" },
	{ "Pet", "Scarf Tee", "Shorts", "Sneakers" },
	{ "Arena", "Bandage Wrap", "Sash Pants", "Wraps" },
	{ "Market", "Open Jacket", "Cargo", "Boots" },
}
-- v0.25.118 (owner: the Job Master should look sharp and seasoned): fixed looks per title over the hashed ones
local NPC_LOOK = {
	["Job Master"] = {
		hair = "Swept", eyes = "Sharp", mouth = "Smirk", mark = "Scar", hair1 = "E8E8EE", hair2 = "B8BCC8",
		shirt1 = "8E1C2A", shirt2 = "E8B84A", pants1 = "1C1A22", pants2 = "3A2A30", shoes1 = "1C1A22", shoes2 = "E8B84A",
		eyes1 = "D8A030", skin = "D6A478",
	},
	-- v0.25.143 (owner: every island's quest giver should be someone else, not Rowan's twin). shirt/pants/shoes = Looks
	-- names, hat = voxelHat kind (overrides the caller's), race/variant = a Heritage body.
	["Lieutenant Pell"] = {
		shirt = "Captain Coat", pants = "Long Pants", shoes = "Tall Boots", hat = "marine", hair = "Side Part",
		eyes = "Determined", mouth = "Flat", hair1 = "243A96", hair2 = "1C1A22", shirt1 = "F4F4F4", shirt2 = "2850B4",
		pants1 = "1C2A5A", pants2 = "F4F4F4", shoes1 = "1C1A22", shoes2 = "1C1A22", skin = "EABE96",
	},
	["Mayor Biscuit"] = {
		shirt = "Open Jacket", pants = "Baggy", shoes = "Buckle Boots", hat = "tophat", hair = "Fluffy", eyes = "Happy",
		mouth = "Laugh", mark = "Stubble", race = "Beastkin", variant = 3, hair1 = "C48646", hair2 = "7A4A28",
		shirt1 = "E07828", shirt2 = "FFD860", pants1 = "6A3C1E", pants2 = "E8B84A", shoes1 = "462C1E", shoes2 = "E8B84A",
		skin = "F6D0AA",
	},
	["Nanny Clove"] = {
		shirt = "Wrap Top", pants = "Skirt", shoes = "Clogs", hat = "headscarf", hair = "Bun", eyes = "Gentle",
		mouth = "Small Smile", hair1 = "96989F", hair2 = "F4F4F4", shirt1 = "6E9A48", shirt2 = "F4ECD0",
		pants1 = "8C5A3A", pants2 = "F4ECD0", shoes1 = "8C6E46", shoes2 = "462C1E", skin = "D6A478",
	},
	["Head Chef Gusto"] = {
		shirt = "Cook Apron", pants = "Side Stripe", shoes = "Clogs", hat = "toque", hair = "Pompadour", eyes = "Fierce",
		mouth = "Grin", mark = "Stubble", race = "Oni", variant = 2, hair1 = "1C1A22", hair2 = "462C1E",
		shirt1 = "F4F4F4", shirt2 = "D83A3A", pants1 = "1C1A22", pants2 = "F4F4F4", shoes1 = "F4F4F4", shoes2 = "1C1A22",
		skin = "BE8860",
	},
	["Granny Rind"] = {
		shirt = "Belted Tunic", pants = "Wide Hakama", shoes = "Sandals", hat = "none", hair = "Bun", eyes = "Closed", mouth = "Happy",
		race = "Tidekin", variant = 1, hair1 = "F4F4F4", hair2 = "C8E6FA", shirt1 = "F08A2A", shirt2 = "FFE0A0",
		pants1 = "2A6E8C", pants2 = "FFE0A0", shoes1 = "8C6E46", shoes2 = "462C1E", skin = "FFE2C4",
	},
	["Harbor Master Vane"] = {
		shirt = "Captain Coat", pants = "Cargo", shoes = "Tall Boots", hat = "captain", hair = "Long Straight",
		eyes = "Cool", mouth = "Smirk", mark = "Scar", hair1 = "545662", hair2 = "1C1A22", shirt1 = "1E3A5A",
		shirt2 = "E8B84A", pants1 = "3A2A20", pants2 = "1C1A22", shoes1 = "1C1A22", shoes2 = "8C6E46", skin = "A06C48",
	},
}
local function nameHash(s, salt)
	local h = salt or 7
	for i = 1, #s do
		h = (h * 31 + string.byte(s, i)) % 100003
	end
	return h
end
local function pick(list, s, salt)
	return list[(nameHash(s, salt) % #list) + 1]
end
local function idx(list, name)
	return table.find(list, name) or 1
end
local function hex(c)
	return string.format("%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function voxelHat(model, kind)
	if not kind then
		return
	end
	local top = 6.45 -- top of the voxel head cube in the preview's rest pose
	local function blk(size, color, pos, mat)
		local b = part(model, Enum.PartType.Block, size, color, CFrame.new(pos), { material = mat or Enum.Material.SmoothPlastic, name = "NpcHat" })
		b.Anchored = true
		return b
	end
	if kind == "marine" then
		blk(Vector3.new(2.0, 0.45, 2.0), Color3.new(1, 1, 1), Vector3.new(0, top + 0.2, 0))
		blk(Vector3.new(2.05, 0.2, 2.05), Color3.fromRGB(40, 90, 200), Vector3.new(0, top + 0.05, 0))
		blk(Vector3.new(1.0, 0.12, 0.6), Color3.fromRGB(30, 50, 110), Vector3.new(0, top - 0.02, -1.2))
	elseif kind == "bandana" then
		blk(Vector3.new(1.95, 0.5, 1.95), Color3.fromRGB(220, 60, 60), Vector3.new(0, top + 0.05, 0))
		blk(Vector3.new(0.35, 0.35, 0.5), Color3.fromRGB(190, 40, 40), Vector3.new(0, top - 0.25, 1.15))
	elseif kind == "captain" then
		blk(Vector3.new(3.0, 0.22, 2.6), Color3.fromRGB(50, 36, 34), Vector3.new(0, top + 0.1, 0))
		blk(Vector3.new(1.9, 0.75, 1.8), Color3.fromRGB(40, 30, 30), Vector3.new(0, top + 0.55, 0))
		blk(Vector3.new(1.95, 0.18, 1.85), Color3.fromRGB(255, 200, 60), Vector3.new(0, top + 0.3, 0), Enum.Material.Neon)
	elseif kind == "helmet" then
		blk(Vector3.new(2.05, 0.8, 2.05), Color3.fromRGB(150, 150, 160), Vector3.new(0, top + 0.1, 0), Enum.Material.Metal)
	elseif kind == "cat" then
		for _, side in ipairs({ -1, 1 }) do
			blk(Vector3.new(0.45, 0.6, 0.3), Color3.fromRGB(40, 35, 45), Vector3.new(side * 0.6, top + 0.3, 0))
		end
	elseif kind == "master" then
		-- crimson headband with two tails flying out the back + a gold plate on the forehead
		blk(Vector3.new(2.05, 0.32, 2.05), Color3.fromRGB(170, 24, 36), Vector3.new(0, top - 0.55, 0))
		blk(Vector3.new(0.5, 0.26, 0.12), Color3.fromRGB(232, 184, 74), Vector3.new(0, top - 0.55, -1.06), Enum.Material.Metal)
		blk(Vector3.new(0.22, 0.2, 1.1), Color3.fromRGB(150, 20, 32), Vector3.new(-0.25, top - 0.75, 1.5))
		blk(Vector3.new(0.22, 0.2, 0.9), Color3.fromRGB(150, 20, 32), Vector3.new(0.25, top - 0.95, 1.4))
	elseif kind == "tophat" then
		blk(Vector3.new(2.6, 0.18, 2.6), Color3.fromRGB(36, 30, 34), Vector3.new(0, top + 0.08, 0))
		blk(Vector3.new(1.6, 1.5, 1.6), Color3.fromRGB(40, 34, 38), Vector3.new(0, top + 0.9, 0))
		blk(Vector3.new(1.65, 0.3, 1.65), Color3.fromRGB(200, 60, 40), Vector3.new(0, top + 0.35, 0))
	elseif kind == "toque" then
		blk(Vector3.new(1.9, 0.5, 1.9), Color3.new(1, 1, 1), Vector3.new(0, top + 0.2, 0))
		blk(Vector3.new(2.3, 1.1, 2.3), Color3.fromRGB(248, 248, 248), Vector3.new(0, top + 1.0, 0))
		blk(Vector3.new(1.6, 0.5, 1.6), Color3.fromRGB(240, 240, 240), Vector3.new(0.2, top + 1.7, -0.1))
	elseif kind == "headscarf" then
		blk(Vector3.new(2.08, 0.7, 2.08), Color3.fromRGB(200, 70, 80), Vector3.new(0, top - 0.05, 0.05))
		blk(Vector3.new(0.5, 0.4, 0.3), Color3.fromRGB(170, 50, 60), Vector3.new(0, top - 0.4, 1.15))
		blk(Vector3.new(0.3, 0.6, 0.15), Color3.fromRGB(170, 50, 60), Vector3.new(0.15, top - 0.85, 1.2))
	elseif kind == "clown" then
		blk(Vector3.new(0.45, 0.45, 0.45), Color3.fromRGB(255, 40, 40), Vector3.new(0, 5.35, -0.95))
	end
end

function MF.NPC(name, color, hatKind)
	local Looks = require(ReplicatedStorage.Shared.Config.Looks)
	local VoxelChar = require(ReplicatedStorage.Shared.Modules.VoxelChar)
	local style = { "Tee", "Long Pants", "Boots" }
	for _, row in ipairs(NPC_STYLE) do
		if string.find(name, row[1], 1, true) then
			style = { row[2], row[3], row[4] }
			break
		end
	end
	color = color or Color3.fromRGB(200, 200, 200)
	local skin = pick(Looks.SkinPresets, name, 3)
	local hairColors = { "1C1A22", "462C1E", "7A4A28", "C48646", "ECC878", "96989F", "F4F4F4", "C42A2E", "243A96" }
	local h1 = pick(hairColors, name, 5)
	local look = {
		hair = (hatKind == "captain" or hatKind == "marine") and idx(Looks.Hair, pick({ "Short", "Messy", "Swept", "Side Part", "Ponytail" }, name, 11))
			or ((nameHash(name, 13) % #Looks.Hair) + 1),
		eyes = idx(Looks.Eyes, pick({ "Bright", "Gentle", "Sharp", "Calm", "Happy", "Determined", "Cool", "Round" }, name, 17)),
		mouth = idx(Looks.Mouths, pick({ "Smile", "Grin", "Smirk", "Small Smile", "Happy", "Flat" }, name, 19)),
		shirt = idx(Looks.Shirts, style[1]),
		pants = idx(Looks.Pants, style[2]),
		shoes = idx(Looks.Shoes, style[3]),
		hair1 = h1, hair2 = h1,
		eyes1 = pick({ "3880EC", "3EAA50", "7A4A28", "961E46", "5A8296" }, name, 23), eyes2 = "181F46",
		shirt1 = hex(color), shirt2 = hex(color:Lerp(Color3.new(1, 1, 1), 0.55)),
		pants1 = pick({ "243A96", "462C1E", "545662", "8C6E46", "1C1A22" }, name, 29), pants2 = "181F46",
		shoes1 = "462C1E", shoes2 = "1C1A22",
		skin = skin,
	}
	local fixed = NPC_LOOK[name]
	if fixed then
		for k, v in pairs(fixed) do
			if k == "hair" then
				look.hair = idx(Looks.Hair, v)
			elseif k == "eyes" then
				look.eyes = idx(Looks.Eyes, v)
			elseif k == "mouth" then
				look.mouth = idx(Looks.Mouths, v)
			elseif k == "shirt" then
				look.shirt = idx(Looks.Shirts, v)
			elseif k == "pants" then
				look.pants = idx(Looks.Pants, v)
			elseif k == "shoes" then
				look.shoes = idx(Looks.Shoes, v)
			elseif k == "hat" then
				hatKind = v
			elseif k ~= "mark" and k ~= "race" and k ~= "variant" then
				look[k] = v
			end
		end
	end
	local clean = Looks.Sanitize(look)
	clean.mark = fixed and fixed.mark or nil -- (Sanitize drops it; VoxelChar draws it for monsters and this NPC)
	local m = VoxelChar.Preview(clean, fixed and fixed.race or nil, fixed and fixed.variant or 1, nil, { lite = true })
	m.Name = name
	voxelHat(m, hatKind)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p:SetAttribute("NoVoxel", true) -- already blocks: the map's Voxelize pass leaves them alone
		end
	end
	-- pivot 2.6 above the feet, like the old models (WorldBuilder.npc places them with that)
	local root = m.PrimaryPart
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = CFrame.new(0, 2.6, 0)
	return m
end

function MF.Billboard(adornee, title, subtitle, color, height)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Nameplate"
	bb.Size = UDim2.fromOffset(220, 60)
	bb.StudsOffsetWorldSpace = Vector3.new(0, height or 4, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 140
	bb.Adornee = adornee
	local t = Instance.new("TextLabel")
	t.Name = "Title"
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0.55, 0)
	t.Font = Enum.Font.Arcade
	t.TextScaled = true
	t.Text = title
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.3
	t.Parent = bb
	if subtitle then
		local s = t:Clone()
		s.Name = "Subtitle"
		s.Position = UDim2.new(0, 0, 0.55, 0)
		s.Size = UDim2.new(1, 0, 0.4, 0)
		s.Text = subtitle
		s.TextColor3 = Color3.fromRGB(255, 240, 200)
		s.Font = Enum.Font.Arcade
		s.Parent = bb
	end
	bb.Parent = adornee
	return bb
end

return MF
