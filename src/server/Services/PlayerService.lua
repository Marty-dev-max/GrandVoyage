-- PlayerService: levels, EXP, stats, skills, job change, characters, client sync
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local ClassesCfg = require(Shared.Config.Classes)
local Islands = require(Shared.Config.Islands)
local FruitsCfg = require(Shared.Config.Fruits)
local Formulas = require(Shared.Modules.Formulas)
local Net = require(Shared.Modules.Net)

local Classes = ClassesCfg.Classes
local PS = {}
local R
local derived = {}
local dirty = {}

function PS.Init(registry)
	R = registry
	Players.RespawnTime = GameConfig.RespawnTime
end

function PS.Profile(player)
	return R.DataService.Get(player)
end

function PS.Derived(player)
	return derived[player]
end

function PS.Root(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

function PS.Humanoid(player)
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

-- Recompute derived stats (after gear, buffs or level changes)
function PS.Recompute(player)
	local profile = PS.Profile(player)
	if not profile then
		return
	end
	local d = Formulas.Compute(profile, R.CombatService.GetBuffs(player))
	derived[player] = d
	local hum = PS.Humanoid(player)
	if hum and hum.Health > 0 then
		local ratio = hum.Health / math.max(1, hum.MaxHealth)
		hum.MaxHealth = d.maxHp
		hum.Health = math.clamp(d.maxHp * ratio, 1, d.maxHp)
		if not player:GetAttribute("Vending") then
			hum.WalkSpeed = d.moveSpeed
		end
	end
	local sp = player:GetAttribute("SP") or d.maxSp
	player:SetAttribute("MaxSP", d.maxSp)
	player:SetAttribute("SP", math.min(sp, d.maxSp))
	PS.MarkDirty(player)
	return d
end

function PS.SetAttributes(player)
	local p = PS.Profile(player)
	if not p then
		return
	end
	local cls = Classes[p.class]
	player:SetAttribute("Class", p.class)
	player:SetAttribute("ClassName", cls and cls.name or p.class)
	player:SetAttribute("Level", p.baseLevel)
	player:SetAttribute("JobLevel", p.jobLevel)
	player:SetAttribute("BaseExp", p.baseExp)
	player:SetAttribute("BaseExpNext", Formulas.BaseExpToNext(p.baseLevel))
	player:SetAttribute("JobExp", p.jobExp)
	player:SetAttribute("JobExpNext", Formulas.JobExpToNext(p.jobLevel))
	player:SetAttribute("Beli", p.beli)
	player:SetAttribute("Faction", p.faction)
	player:SetAttribute("Bounty", p.bounty)
	player:SetAttribute("Merit", p.merit)
	player:SetAttribute("StatPoints", p.statPoints)
	player:SetAttribute("SkillPoints", p.skillPoints)
	player:SetAttribute("Crew", p.crew)
	-- set here (on load) so the HUD shows Pearls right away instead of 0 until the first purchase
	player:SetAttribute("Pearls", (p.pearls or 0) + (p.pearlsBound or 0))
	player:SetAttribute("PearlsTradable", p.pearls or 0)
	if R and R.FruitService then
		R.FruitService.SetAttributes(player, p)
	end
	if R and R.PetService then
		R.PetService.SetAttributes(player, p)
	end
	if R and R.ProgressService then
		R.ProgressService.SetAttributes(player, p)
	end
end

function PS.MarkDirty(player)
	dirty[player] = true
end

local function sync(player)
	local p = PS.Profile(player)
	if not p then
		return
	end
	PS.SetAttributes(player)
	Net.Push(player, "Profile", {
		profile = {
			class = p.class,
			baseLevel = p.baseLevel,
			jobLevel = p.jobLevel,
			statPoints = p.statPoints,
			skillPoints = p.skillPoints,
			stats = p.stats,
			skills = p.skills,
			skillBar = p.skillBar,
			autoSkills = p.autoSkills,
			inventory = p.inventory,
			equipment = p.equipment,
			beli = p.beli,
			faction = p.faction,
			guildId = p.guildId,
			bounty = p.bounty,
			ships = p.ships,
			activeShip = p.activeShip,
			shipSunk = p.shipSunk,
			crew = p.crew,
			unlocked = p.unlocked,
			chests = p.chests,
			classProgress = p.classProgress,
			fruit = p.fruit,
			pets = p.pets,
			activePet = p.activePet,
			perks = p.perks,
			daily = p.daily,
			ach = p.ach,
			title = p.title,
			pearls = p.pearls,
			pearlsBound = p.pearlsBound,
			expBoostUntil = p.expBoostUntil,
			classSwitches = p.classSwitches,
			settings = p.settings,
		},
		derived = derived[player],
	})
	if R.QuestService then
		task.spawn(R.QuestService.Check, player)
	end
	if R.ProgressService then
		task.spawn(R.ProgressService.Check, player)
	end
end

function PS.AddBeli(player, amount)
	local p = PS.Profile(player)
	if not p then
		return false
	end
	if amount < 0 and p.beli + amount < 0 then
		return false
	end
	p.beli = math.floor(p.beli + amount)
	player:SetAttribute("Beli", p.beli)
	PS.MarkDirty(player)
	return true
end

function PS.Notify(player, text, kind)
	Net.Push(player, "Toast", { text = text, kind = kind or "info" })
end

-- ===== EXP / Level =====
local function jobCap(p)
	local cls = Classes[p.class]
	if cls and cls.tier == 0 then
		return GameConfig.JobChangeLevel
	end
	return GameConfig.MaxJobLevel
end

-- pos (optional): world position the EXP came from; the client flies EXP orbs from there into the level ring
function PS.GiveExp(player, base, job, pos)
	local p = PS.Profile(player)
	local d = derived[player]
	if not p then
		return
	end
	local mult = 1 + (d and d.expPct or 0) + ((p.expBoostUntil or 0) > os.time() and 0.5 or 0)
	base = math.floor(base * mult)
	job = math.floor(job * mult)
	if base > 0 or job > 0 then
		Net.Push(player, "ExpGain", { base = base, job = job, pos = pos })
		if R.PetService then
			R.PetService.OnBaseExp(player, base)
		end
	end
	local leveled = false
	if p.baseLevel < GameConfig.MaxBaseLevel then
		p.baseExp += base
		while p.baseLevel < GameConfig.MaxBaseLevel and p.baseExp >= Formulas.BaseExpToNext(p.baseLevel) do
			p.baseExp -= Formulas.BaseExpToNext(p.baseLevel)
			p.baseLevel += 1
			p.statPoints += Formulas.StatPointsForLevel(p.baseLevel)
			leveled = true
		end
		if p.baseLevel >= GameConfig.MaxBaseLevel then
			p.baseExp = 0
		end
	end
	local jobLeveled = false
	local cap = jobCap(p)
	if p.jobLevel < cap then
		p.jobExp += job
		while p.jobLevel < cap and p.jobExp >= Formulas.JobExpToNext(p.jobLevel) do
			p.jobExp -= Formulas.JobExpToNext(p.jobLevel)
			p.jobLevel += 1
			p.skillPoints += 1
			jobLeveled = true
		end
		if p.jobLevel >= cap then
			p.jobExp = 0
		end
	end
	if leveled or jobLeveled then
		local d2 = PS.Recompute(player)
		local hum = PS.Humanoid(player)
		if hum and d2 and leveled then
			hum.Health = d2.maxHp
			player:SetAttribute("SP", d2.maxSp)
		end
		local root = PS.Root(player)
		if root then
			Net.FX("LevelUp", { pos = root.Position, job = not leveled }, root.Position, 300)
		end
		if leveled then
			PS.Notify(player, "LEVEL UP! Base Lv." .. p.baseLevel, "level")
		else
			PS.Notify(player, "Job Lv." .. p.jobLevel .. " (+1 Skill Point)", "level")
		end
	end
	PS.MarkDirty(player)
end

-- ===== Spawn / characters =====
function PS.SpawnCFrame(islandId)
	return R.WorldBuilder.GetSpawn(islandId)
end

function PS.TeleportTo(player, cf)
	local char = player.Character
	if char then
		char:PivotTo(cf + Vector3.new(0, 3, 0))
	end
end

local function onCharacter(player, char)
	local hum = char:WaitForChild("Humanoid")
	char:WaitForChild("HumanoidRootPart")
	local p = PS.Profile(player)
	if not p then
		return
	end
	hum.BreakJointsOnDeath = false
	task.defer(function()
		PS.TeleportTo(player, PS.SpawnCFrame(p.lastIsland))
	end)
	local d = PS.Recompute(player)
	if d then
		hum.MaxHealth = d.maxHp
		hum.Health = d.maxHp
		player:SetAttribute("SP", d.maxSp)
	end
	hum.Died:Connect(function()
		-- Death penalty: lose 1% EXP (Ragnarok-style)
		local loss = math.floor(Formulas.BaseExpToNext(p.baseLevel) * 0.01)
		p.baseExp = math.max(0, p.baseExp - loss)
		PS.MarkDirty(player)
		R.CombatService.ClearBuffs(player)
		R.MarketService.CloseStall(player)
		PS.Notify(player, "You were knocked out... respawning at " .. Islands.ById[p.lastIsland].name, "bad")
	end)
end

local function onPlayerAdded(player)
	local p = R.DataService.Load(player)
	if not p then
		return
	end
	PS.SetAttributes(player)
	R.GuildService.OnPlayerJoin(player)
	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	PS.MarkDirty(player)
end

-- ===== Request handlers =====
local function setupHandlers()
	Net.Handle("GetState", function(player)
		PS.MarkDirty(player)
		return true
	end, 1)

	Net.Handle("AllocateStat", function(player, data)
		local p = PS.Profile(player)
		local stat = data.stat
		local amount = math.clamp(math.floor(tonumber(data.amount) or 1), 1, 10)
		if not p.stats[stat] then
			return false, "Invalid stat"
		end
		for _ = 1, amount do
			local cur = p.stats[stat]
			local cost = Formulas.StatCost(cur)
			if cur >= Formulas.MaxStat or p.statPoints < cost then
				break
			end
			p.statPoints -= cost
			p.stats[stat] = cur + 1
		end
		PS.Recompute(player)
		return true
	end, 0.05)

	Net.Handle("LearnSkill", function(player, data)
		local p = PS.Profile(player)
		local skill = ClassesCfg.SkillById[data.skillId]
		if not skill then
			return false, "Skill not found"
		end
		if skill.class ~= p.class and skill.class ~= "Common" then
			return false, "Your class cannot learn this skill"
		end
		local lv = p.skills[skill.id] or 0
		if lv >= skill.maxLevel then
			return false, "Skill is already max level"
		end
		if p.skillPoints < 1 then
			return false, "Not enough skill points"
		end
		p.skillPoints -= 1
		p.skills[skill.id] = lv + 1
		if lv == 0 and #p.skillBar < 8 then
			table.insert(p.skillBar, skill.id)
		end
		PS.MarkDirty(player)
		return true
	end, 0.05)

	Net.Handle("SetSkillBar", function(player, data)
		local p = PS.Profile(player)
		local bar = {}
		if type(data.bar) == "table" then
			for i = 1, math.min(8, #data.bar) do
				local id = data.bar[i]
				if type(id) == "string" and (p.skills[id] or R.FruitService.CanSlot(p, id)) then
					table.insert(bar, id)
				end
			end
		end
		p.skillBar = bar
		PS.MarkDirty(player)
		return true
	end)

	Net.Handle("SetAutoSettings", function(player, data)
		local p = PS.Profile(player)
		if type(data.autoSkills) == "table" then
			local a = {}
			for id, v in pairs(data.autoSkills) do
				if type(id) == "string" and (p.skills[id] or R.FruitService.CanSlot(p, id)) and v == true then
					a[id] = true
				end
			end
			p.autoSkills = a
		end
		if tonumber(data.autoPotionPct) then
			p.settings.autoPotionPct = math.clamp(math.floor(data.autoPotionPct), 0, 90)
		end
		PS.MarkDirty(player)
		return true
	end)

	Net.Handle("SaveClientSettings", function(player, data)
		local p = PS.Profile(player)
		if type(data.settings) ~= "table" then
			return false
		end
		local clean = {}
		local n = 0
		for k, v in pairs(data.settings) do
			if type(k) == "string" and #k <= 24 and (type(v) == "number" or type(v) == "boolean" or (type(v) == "string" and #v <= 16)) then
				clean[k] = v
				n += 1
				if n >= 24 then
					break
				end
			end
		end
		p.settings.client = clean
		return true
	end, 1)

	-- Switch class at a Job Master. Progress is saved per class, so switching back resumes where you left off.
	-- First switch: needs Job Lv.10 and is free. Later switches cost Base Lv x ClassSwitchCostPerLevel Doubloons.
	Net.Handle("ChangeJob", function(player, data)
		local p = PS.Profile(player)
		local target = Classes[data.class]
		if not target or target.tier ~= 1 then
			return false, "Invalid class"
		end
		if data.class == p.class then
			return false, "You already are a " .. target.name
		end
		if not R.WorldBuilder.NearNPC(player, "JobMaster") then
			return false, "Talk to a Job Master"
		end
		p.classProgress = p.classProgress or {}
		p.classSwitches = p.classSwitches or 0
		if p.classSwitches == 0 and p.jobLevel < GameConfig.JobChangeLevel then
			return false, "Reach Job Lv." .. GameConfig.JobChangeLevel .. " first"
		end
		local cost = p.classSwitches == 0 and 0 or p.baseLevel * GameConfig.ClassSwitchCostPerLevel
		local usedVoucher = false
		if cost > 0 and p.perks and (p.perks.freeSwitch or 0) > 0 then
			p.perks.freeSwitch -= 1 -- Class Switch Voucher from the Pearl Shop
			cost = 0
			usedVoucher = true
		end
		if cost > 0 and not PS.AddBeli(player, -cost) then
			return false, "Switching costs " .. cost .. " Doubloons"
		end
		local _ = usedVoucher
		-- save the current class, load (or start) the target class
		p.classProgress[p.class] = { jobLevel = p.jobLevel, jobExp = p.jobExp }
		local saved = p.classProgress[data.class]
		local fresh = saved == nil
		p.class = data.class
		p.jobLevel = saved and saved.jobLevel or 1
		p.jobExp = saved and saved.jobExp or 0
		p.classSwitches += 1
		if fresh then
			p.skillPoints += 1
			R.InventoryService.AddItem(player, target.weapons[1] .. "_Plain", 1)
		end
		-- unequip a weapon the new class cannot use
		local wEntry = p.equipment.weapon and Formulas.FindItem(p, p.equipment.weapon)
		if wEntry then
			local def = require(Shared.Modules.ItemDB).Get(wEntry.id)
			if def and not table.find(target.weapons, def.weaponType) then
				p.equipment.weapon = nil
			end
		end
		-- skills of other classes stay learned but cannot be used: drop them from the bar
		local bar = {}
		for _, id in ipairs(p.skillBar) do
			local sk = ClassesCfg.SkillById[id]
			if sk and (sk.class == p.class or sk.class == "Common") then
				table.insert(bar, id)
			end
		end
		for _, sk in ipairs(target.skills) do
			if (p.skills[sk.id] or 0) > 0 and not table.find(bar, sk.id) and #bar < 8 then
				table.insert(bar, sk.id)
			end
		end
		p.skillBar = bar
		PS.Recompute(player)
		local root = PS.Root(player)
		if root then
			Net.FX("JobChange", { pos = root.Position, color = target.color }, root.Position, 400)
		end
		if fresh then
			Net.PushAll("Announce", { text = player.DisplayName .. " became a " .. target.name .. "!" })
		end
		return true, (fresh and "You are now a " or "Welcome back, ") .. target.name .. (cost > 0 and ("  (-" .. cost .. " Doubloons)") or "")
	end, 1)

	Net.Handle("FastTravel", function(player, data)
		local p = PS.Profile(player)
		local island = Islands.ById[data.island]
		if not island or not p.unlocked[island.id] then
			return false, "Island not discovered yet (sail there first)"
		end
		if R.ShipService.GetShipOf(player) then
			return false, "Dock your ship first"
		end
		local cost = 100 * island.index
		if not PS.AddBeli(player, -cost) then
			return false, "Not enough Doubloons (" .. cost .. ")"
		end
		p.lastIsland = island.id
		PS.TeleportTo(player, PS.SpawnCFrame(island.id))
		return true, "Courier gull flight to " .. island.name
	end, 2)
end

function PS.UnlockIsland(player, islandId)
	local p = PS.Profile(player)
	if p and not p.unlocked[islandId] then
		p.unlocked[islandId] = true
		local island = Islands.ById[islandId]
		Net.Push(player, "IslandDiscovered", { id = islandId, name = island.name, subtitle = island.subtitle })
		PS.MarkDirty(player)
	end
	if p then
		p.lastIsland = islandId
	end
end

function PS.Start()
	setupHandlers()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, pl in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, pl)
	end
	Players.PlayerRemoving:Connect(function(player)
		R.MarketService.CloseStall(player)
		R.ShipService.DespawnShipOf(player)
		R.ShipyardService.ExitBuild(player)
		R.PartyService.Leave(player)
		R.DataService.Release(player)
		derived[player] = nil
		dirty[player] = nil
	end)
	-- Debounced profile sync to the client
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player in pairs(dirty) do
				dirty[player] = nil
				if player.Parent then
					sync(player)
				end
			end
		end
	end)
	-- Overboard: sinking below the sea, or swimming longer than your breath lasts, washes you back ashore.
	-- (The client floats you at the surface; this check is the authority, so a modified client cannot swim forever.)
	local swimTime = {}
	local SWIM = GameConfig.Swim
	local function nearIsland(pos)
		for _, isl in ipairs(Islands.List) do
			local d = (Vector2.new(pos.X - isl.x, pos.Z - (isl.z or 0))).Magnitude
			if d < isl.radius + 8 then
				return true
			end
		end
		return false
	end
	Players.PlayerRemoving:Connect(function(pl)
		swimTime[pl] = nil
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		for _, player in ipairs(Players:GetPlayers()) do
			local root = PS.Root(player)
			local hum = PS.Humanoid(player)
			local onShip = root and R.ShipService.IsOnShip(player)
			local inSea = root and hum and hum.Health > 0 and not onShip and root.Position.Y < GameConfig.SeaLevel + 0.5 and not nearIsland(root.Position)
			swimTime[player] = inSea and (swimTime[player] or 0) + 0.5 or 0
			local sank = root and hum and hum.Health > 0 and root.Position.Y < -8 and not onShip
			-- Cursed Fruit users cannot swim at all: any water deeper than the shallows drags them under
			local fruitSink = player:GetAttribute("Fruit") ~= nil and root and not onShip and root.Position.Y < GameConfig.SeaLevel - 1 and swimTime[player] >= FruitsCfg.SinkSeconds
			if sank or fruitSink or swimTime[player] > SWIM.BreathSeconds + 2 then
				local p = PS.Profile(player)
				if p then
					swimTime[player] = 0
					hum.Health = math.max(1, hum.Health - hum.MaxHealth * 0.1)
					PS.TeleportTo(player, PS.SpawnCFrame(p.lastIsland))
					PS.Notify(player, "Out of breath! The waves washed you ashore... (sail a ship to cross the sea)", "bad")
				end
			end
		end
	end)
end

return PS
