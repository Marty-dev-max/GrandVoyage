-- FruitService: Cursed Fruits (Config/Fruits). Drops, the natural fruit spawn, eating, Fruit Mastery and Seastone.
-- Uneaten fruits are normal inventory items ("Fruit_<id>") so they can be stored, traded and sold in stalls.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Fruits = require(Shared.Config.Fruits)
local Islands = require(Shared.Config.Islands)
local Rarity = require(Shared.Modules.Rarity)
local Formulas = require(Shared.Modules.Formulas)
local Net = require(Shared.Modules.Net)

local FS = {}
local R
local M = Fruits.Mastery

local function profile(player)
	return R.PlayerService.Profile(player)
end

-- ===== mastery =====
function FS.NeedFor(level)
	return M.Base + M.PerLevel * level
end

local function setAttrs(player, p)
	player:SetAttribute("Fruit", p.fruit and p.fruit.id or nil)
	player:SetAttribute("FruitMastery", p.fruit and p.fruit.mastery or nil)
end
FS.SetAttributes = setAttrs

local function unlockedSkills(p)
	local out = {}
	local def = p.fruit and Fruits.ById[p.fruit.id]
	if def then
		for _, s in ipairs(def.skills) do
			if p.fruit.mastery >= s.mastery then
				table.insert(out, s)
			end
		end
	end
	return out
end

local function addToBar(p)
	for _, s in ipairs(unlockedSkills(p)) do
		if not table.find(p.skillBar, s.id) and #p.skillBar < 8 then
			table.insert(p.skillBar, s.id)
		end
	end
end

function FS.GainMastery(player, amount)
	local p = profile(player)
	if not p or not p.fruit then
		return
	end
	local f = p.fruit
	if f.mastery >= M.Max then
		return
	end
	f.exp += amount
	local leveled = false
	while f.mastery < M.Max and f.exp >= FS.NeedFor(f.mastery) do
		f.exp -= FS.NeedFor(f.mastery)
		f.mastery += 1
		leveled = true
		local def = Fruits.ById[f.id]
		for _, s in ipairs(def.skills) do
			if s.mastery == f.mastery then
				Net.Push(player, "Banner", { title = "New Fruit Skill!", subtitle = s.name .. "  •  " .. def.name })
			end
		end
	end
	if leveled then
		addToBar(p)
		setAttrs(player, p)
		Net.Push(player, "Toast", { text = "Fruit Mastery Lv." .. f.mastery, kind = "good" })
	end
	R.PlayerService.MarkDirty(player)
end

-- Skill level used by CombatService for a fruit skill, or nil (with a reason) if it cannot be used now
function FS.SkillLevel(player, skill)
	local p = profile(player)
	if not p or not p.fruit or p.fruit.id ~= skill.fruit then
		return nil, "You have not eaten that fruit"
	end
	if p.fruit.mastery < skill.mastery then
		return nil, "Needs Fruit Mastery " .. skill.mastery
	end
	if (player:GetAttribute("SeastoneUntil") or 0) > os.clock() then
		return nil, "Seastone! Your fruit powers are sealed"
	end
	-- mastery adds damage: +1% per level (mult is scaled by CombatService with 1 + 0.1 * (lv - 1))
	return 1 + p.fruit.mastery * M.DamagePerLevel * 10
end

function FS.CanSlot(p, skillId)
	for _, s in ipairs(unlockedSkills(p)) do
		if s.id == skillId then
			return true
		end
	end
	return false
end

local lastCast = {}
function FS.OnCast(player)
	lastCast[player] = os.clock()
	FS.GainMastery(player, M.ExpPerCast)
	R.QuestService.Event(player, "FruitSkill")
end

-- kills count toward mastery if a fruit skill was used in the last 4 seconds
function FS.OnKill(player)
	if lastCast[player] and os.clock() - lastCast[player] < 4 then
		FS.GainMastery(player, M.ExpPerKill)
	end
end

-- Marine hits in PvP may seal a fruit user's powers
function FS.TrySeastone(attacker, victim)
	if attacker:GetAttribute("Faction") ~= "Marine" or not victim:GetAttribute("Fruit") then
		return
	end
	if math.random() < Fruits.Seastone.Chance then
		victim:SetAttribute("SeastoneUntil", os.clock() + Fruits.Seastone.Seconds)
		Net.Push(victim, "Toast", { text = "⛓️ Seastone! Fruit powers sealed for " .. Fruits.Seastone.Seconds .. "s", kind = "bad" })
	end
end

-- ===== drops =====
local function pickFruit()
	local total = 0
	for _, f in ipairs(Fruits.List) do
		total += f.weight
	end
	local r = math.random() * total
	for _, f in ipairs(Fruits.List) do
		r -= f.weight
		if r <= 0 then
			return f
		end
	end
	return Fruits.List[#Fruits.List]
end

function FS.Give(player, f, source)
	R.InventoryService.AddItem(player, "Fruit_" .. f.id, 1)
	Net.Push(player, "Loot", { items = { { id = "Fruit_" .. f.id, qty = 1 } } })
	Net.Push(player, "Banner", { title = "Cursed Fruit!", subtitle = f.name })
	if Rarity.Get(f.rarity).rank >= Fruits.Drops.AnnounceRank then
		Net.PushAll("Announce", { text = "🍎 " .. player.DisplayName .. " found the " .. f.name .. " (" .. source .. ")!", rarity = f.rarity })
	end
end

-- chance roll; returns true if a fruit dropped
function FS.RollDrop(player, chance, source)
	if math.random() >= chance then
		return false
	end
	FS.Give(player, pickFruit(), source or "drop")
	return true
end

-- ===== natural spawn: a glowing fruit appears on a random island =====
local spawned
local function fruitModel(f, pos)
	local m = Instance.new("Model")
	m.Name = "CursedFruit"
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(2.4, 2.4, 2.4)
	body.Color = f.color
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.CFrame = CFrame.new(pos + Vector3.new(0, 1.6, 0))
	body.Parent = m
	-- swirl rings: the classic "cursed fruit" look
	for i = -1, 1 do
		local ring = Instance.new("Part")
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.25, 2.5 - math.abs(i) * 0.7, 2.5 - math.abs(i) * 0.7)
		ring.Color = f.swirl
		ring.Material = Enum.Material.Neon
		ring.Anchored = true
		ring.CanCollide = false
		ring.CFrame = body.CFrame * CFrame.new(0, i * 0.6, 0) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Parent = m
	end
	local stem = Instance.new("Part")
	stem.Size = Vector3.new(0.25, 0.9, 0.25)
	stem.Color = Color3.fromRGB(70, 120, 50)
	stem.Anchored = true
	stem.CanCollide = false
	stem.CFrame = body.CFrame * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, 0.4)
	stem.Parent = m
	local light = Instance.new("PointLight")
	light.Color = f.color
	light.Range = 18
	light.Brightness = 2
	light.Parent = body
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = f.swirl
	sparkles.Parent = body
	m.PrimaryPart = body
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = "Strange Fruit"
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	CollectionService:AddTag(m, "CursedFruit")
	m.Parent = workspace
	return m, prompt
end

local function groundAt(x, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { workspace:FindFirstChild("Monsters"), workspace:FindFirstChild("Ships") }
	params.RespectCanCollide = true
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), params)
	return hit and hit.Position.Y > 2 and hit.Position or nil
end

function FS.SpawnTreeFruit()
	if spawned and spawned.Parent then
		spawned:Destroy()
	end
	local island = Islands.List[math.random(1, #Islands.List)]
	local pos
	for _ = 1, 30 do
		local a, d = math.random() * math.pi * 2, island.radius * (0.25 + math.random() * 0.5)
		pos = groundAt(island.x + math.cos(a) * d, (island.z or 0) + math.sin(a) * d)
		if pos then
			break
		end
	end
	if not pos then
		return
	end
	local f = pickFruit()
	local m, prompt = fruitModel(f, pos)
	spawned = m
	Net.PushAll("Announce", { text = "🍎 A strange fruit has appeared somewhere on " .. island.name .. "!", rarity = "Epic" })
	prompt.Triggered:Connect(function(player)
		local root = R.PlayerService.Root(player)
		if not m.Parent or not root or (root.Position - m.PrimaryPart.Position).Magnitude > 16 then
			return
		end
		m:Destroy()
		FS.Give(player, f, island.name)
	end)
	task.delay(Fruits.Drops.TreeLifetime, function()
		if m.Parent then
			m:Destroy()
		end
	end)
end

function FS.Init(registry)
	R = registry
end

function FS.Start()
	Players.PlayerRemoving:Connect(function(player)
		lastCast[player] = nil
	end)
	Players.PlayerAdded:Connect(function(player)
		task.delay(3, function()
			local p = profile(player)
			if p then
				setAttrs(player, p)
			end
		end)
	end)
	Net.Handle("EatFruit", function(player, data)
		local p = profile(player)
		local entry = p and Formulas.FindItem(p, data.uid)
		local fid = entry and string.match(entry.id, "^Fruit_(.+)$")
		local f = fid and Fruits.ById[fid]
		if not f then
			return false, "That is not a Cursed Fruit"
		end
		if player:GetAttribute("Vending") then
			return false, "Close your stall first"
		end
		local old = p.fruit and Fruits.ById[p.fruit.id]
		R.InventoryService.RemoveUid(player, entry.uid, 1)
		-- the old fruit's power is gone for good; strip its skills from the bar
		if old then
			local bar = {}
			for _, id in ipairs(p.skillBar) do
				if not string.match(id, "^F_") then
					table.insert(bar, id)
				end
			end
			p.skillBar = bar
		end
		p.fruit = { id = f.id, mastery = 1, exp = 0 }
		addToBar(p)
		setAttrs(player, p)
		R.PlayerService.Recompute(player)
		local root = R.PlayerService.Root(player)
		if root then
			Net.FX("JobChange", { pos = root.Position, color = f.color }, root.Position, 300)
		end
		Net.PushAll("Announce", { text = player.DisplayName .. " ate the " .. f.name .. "!", rarity = f.rarity })
		return true, "You ate the " .. f.name .. "! (You can no longer swim)"
	end, 1)
	-- natural spawns
	task.spawn(function()
		task.wait(60)
		while true do
			pcall(FS.SpawnTreeFruit)
			task.wait(Fruits.Drops.TreeInterval)
		end
	end)
end

return FS
