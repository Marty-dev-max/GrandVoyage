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
local VoxelAvatar = require(script.Parent.VoxelAvatar)
local VoxelChar = require(Shared.Modules.VoxelChar)
local Looks = require(Shared.Config.Looks)

local Classes = ClassesCfg.Classes
local PS = {}
local R
local ItemDB = require(Shared.Modules.ItemDB)

-- ===== skill bar (12 fixed slots, "" = empty) =====
-- can this profile put this skill on its bar right now? (learned + its class, Common, or an unlocked fruit skill)
local function usableSkill(p, id)
	local sk = ClassesCfg.SkillById[id]
	if not sk then
		return R.FruitService.CanSlot(p, id) == true
	end
	if sk.fruit then
		return R.FruitService.CanSlot(p, id) == true
	end
	return (p.skills[id] or 0) > 0 and (sk.class == p.class or sk.class == "Common")
end
PS.UsableSkill = usableSkill

-- drop trailing empty slots (keeps the saved profile small; gaps in the middle stay where the player put them)
local function trimBar(bar)
	local n = #bar
	while n > 0 and (bar[n] == "" or bar[n] == nil) do
		bar[n] = nil
		n -= 1
	end
	for i = 1, n do
		bar[i] = bar[i] or ""
	end
	return bar
end
PS.TrimBar = trimBar

-- ===== auto stat upgrade (Stats window toggle): spend points in the build that suits the class =====
local STAT_BUILD = {
	Brawler = { STR = 5, AGI = 3, VIT = 3, DEX = 1 },
	Swordsman = { STR = 5, VIT = 3, AGI = 2, DEX = 1 },
	Sniper = { DEX = 5, AGI = 3, LUK = 2 },
	Cook = { AGI = 4, STR = 4, VIT = 2, LUK = 1 },
	Navigator = { INT = 5, DEX = 3, VIT = 2 },
	Doctor = { INT = 5, VIT = 3, DEX = 2 },
	Shipwright = { STR = 4, VIT = 4, DEX = 2 },
}
function PS.AutoStats(player)
	local p = PS.Profile(player)
	if not p or not (p.settings and p.settings.autoStats) then
		return
	end
	local build = STAT_BUILD[p.class] or { STR = 1, AGI = 1, VIT = 1, DEX = 1 }
	local spent = 0
	for _ = 1, 400 do
		-- the stat furthest behind its share of the build
		local best, bestRatio
		for stat, w in pairs(build) do
			local v = p.stats[stat]
			if w > 0 and v and v < Formulas.MaxStat then
				local ratio = v / w
				if not bestRatio or ratio < bestRatio then
					best, bestRatio = stat, ratio
				end
			end
		end
		if not best then
			break
		end
		local cost = Formulas.StatCost(p.stats[best])
		if cost > p.statPoints then
			break
		end
		p.statPoints -= cost
		p.stats[best] += 1
		spent += 1
	end
	if spent > 0 then
		PS.Recompute(player)
		if R.QuestService then
			R.QuestService.Event(player, "Stat", nil, spent)
		end
	end
end

-- put a skill in the first free slot (no-op if it is already on the bar or the bar is full)
function PS.BarAdd(p, id)
	if table.find(p.skillBar, id) then
		return true
	end
	for i = 1, GameConfig.SkillBarSize do
		if p.skillBar[i] == nil or p.skillBar[i] == "" then
			for j = #p.skillBar + 1, i - 1 do
				p.skillBar[j] = ""
			end
			p.skillBar[i] = id
			return true
		end
	end
	return false
end

-- empty every slot whose skill matches `drop(id)` (slots keep their positions)
function PS.BarRemoveIf(p, drop)
	for i, id in ipairs(p.skillBar) do
		if id ~= "" and drop(id) then
			p.skillBar[i] = ""
		end
	end
	trimBar(p.skillBar)
end
local derived = {}
local dirty = {}

function PS.Init(registry)
	R = registry
	Players.RespawnTime = GameConfig.RespawnTime
	if GameConfig.TitleMenu then
		-- v0.24.0: nobody spawns until they pick a character slot and press Play on the title menu
		Players.CharacterAutoLoads = false
		Net.SetGate(function(player)
			return R.DataService.Get(player) ~= nil
		end)
	end
end

-- the blank R15 body every custom character is built on (the look itself is VoxelChar blocks)
local function blankDescription()
	local desc = Instance.new("HumanoidDescription")
	desc.HeightScale, desc.WidthScale, desc.DepthScale, desc.HeadScale = 1, 1, 1, 1
	desc.BodyTypeScale, desc.ProportionScale = 0, 0
	return desc
end

-- (re)spawn the player's character: their custom look when the title menu is on, else their Roblox avatar
function PS.Respawn(player)
	if not player.Parent or not R.DataService.Get(player) then
		return
	end
	if GameConfig.TitleMenu then
		local ok, err = pcall(function()
			player:LoadCharacterWithHumanoidDescription(blankDescription())
		end)
		if not ok then
			warn("[PlayerService] spawn with description failed, plain spawn:", err)
			pcall(player.LoadCharacter, player)
		end
	else
		player:LoadCharacter()
	end
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
			itemBar = p.itemBar,
			titles = p.titles,
			ammo = p.ammo,
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
		+ ((p.boosts and (p.boosts.exp or 0) > os.time()) and 1 or 0) -- Store 2x EXP
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
	if leveled then
		task.defer(PS.AutoStats, player)
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

-- every avatar gets the same R15 body (owner decision): classic proportions and default body parts, so attack
-- poses and class outfits fit everyone; face, hair, accessories and clothing stay the player's own
local function normalizeAvatar(hum)
	if not GameConfig.NormalizeAvatars or hum.RigType ~= Enum.HumanoidRigType.R15 then
		return true
	end
	local ok, desc = pcall(function()
		return hum:GetAppliedDescription()
	end)
	if not ok or not desc then
		return false
	end
	desc.HeightScale, desc.WidthScale, desc.DepthScale, desc.HeadScale = 1, 1, 1, 1
	desc.BodyTypeScale, desc.ProportionScale = 0, 0
	desc.Torso, desc.LeftArm, desc.RightArm, desc.LeftLeg, desc.RightLeg = 0, 0, 0, 0, 0
	if GameConfig.VoxelAvatars then
		-- voxel style (v0.22.6): the plain head (we put a cube with the face on it) and no layered 3D clothing
		desc.Head = 0
		pcall(function()
			local keep = {}
			for _, a in ipairs(desc:GetAccessories(true)) do
				if not a.IsLayered then
					table.insert(keep, a)
				end
			end
			desc:SetAccessories(keep, true)
		end)
	end
	local applied = pcall(function()
		hum:ApplyDescription(desc)
	end)
	return applied
end

local function onCharacter(player, char)
	local hum = char:WaitForChild("Humanoid")
	char:WaitForChild("HumanoidRootPart")
	-- every spawn (also after dying): wait until Roblox has put the avatar's look on, then reset the body;
	-- applying too early was silently undone by the appearance loader
	task.spawn(function()
		if GameConfig.TitleMenu then
			-- custom character (title menu creator): blocks built from the slot's look
			task.wait(0.15)
			local prof = PS.Profile(player)
			if char.Parent and prof then
				local ok, err = pcall(VoxelChar.Apply, char, prof.look, prof.heritage, prof.heritageVariant, prof.heritageMode)
				if not ok then
					warn("[PlayerService] voxel character failed:", err)
				end
				if prof.heritage == "Skyborn" or prof.heritage == "Cinderwing" then
					hum.UseJumpPower = true
					hum.JumpPower = 50 * 1.15
				end
			end
			return
		end
		if not player:HasAppearanceLoaded() then
			player.CharacterAppearanceLoaded:Wait()
		end
		for _ = 1, 4 do
			task.wait(0.2)
			if not char.Parent or player.Character ~= char then
				return
			end
			if normalizeAvatar(hum) then
				if GameConfig.VoxelAvatars then
					task.wait(0.3) -- let the re-applied accessories attach
					if char.Parent then
						local ok, err = pcall(VoxelAvatar.Apply, char)
						if not ok then
							warn("[PlayerService] voxel avatar failed:", err)
						end
					end
				end
				return
			end
		end
	end)
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
		if not Players.CharacterAutoLoads then
			task.delay(Players.RespawnTime, function()
				if player.Character == char then
					PS.Respawn(player)
				end
			end)
		end
	end)
end

local function enterGame(player, slot)
	local p = R.DataService.Load(player, slot)
	if not p then
		return nil
	end
	p.lastPlayed = os.time()
	player:SetAttribute("Slot", slot)
	player:SetAttribute("Heritage", p.heritage)
	player:SetAttribute("HeritageMode", p.heritageMode)
	PS.SetAttributes(player)
	R.GuildService.OnPlayerJoin(player)
	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	PS.MarkDirty(player)
	R.DataService.FireLoaded(player)
	return p
end

local function onPlayerAdded(player)
	if GameConfig.TitleMenu then
		return -- waits on the title menu (MenuPlay)
	end
	enterGame(player, 1)
end

-- ===== title menu: character slots (open requests, allowed before the player is in the game) =====
local entering = {}
local function setupMenuHandlers()
	local function validSlot(n)
		n = tonumber(n)
		if not n or n ~= math.floor(n) or n < 1 or n > Looks.Slots then
			return nil
		end
		return n
	end
	Net.Handle("MenuSlots", function(player)
		local list, err = R.DataService.ListSlots(player)
		if not list then
			return false, err
		end
		return true, nil, { slots = list, bank = R.DataService.BankSpins(player.UserId), inGame = R.DataService.Get(player) ~= nil }
	end, 1, true)
	-- save a slot's look (creates the slot if it is empty)
	Net.Handle("MenuSaveLook", function(player, data)
		local slot = validSlot(data.slot)
		if not slot then
			return false, "Invalid slot"
		end
		local look = Looks.Sanitize(data.look)
		local sum, err = R.DataService.EditSlot(player, slot, function(d)
			d.look = look
		end)
		if not sum then
			return false, err
		end
		return true, "Character saved", sum
	end, 0.5, true)
	-- Heritage spin: rolled here, never on the client. The slot's own spins go first, then the account's bought ones.
	Net.Handle("MenuSpin", function(player, data)
		local slot = validSlot(data.slot)
		if not slot then
			return false, "Invalid slot"
		end
		local look = data.look and Looks.Sanitize(data.look)
		local function roll(useBank)
			local rolled, noSpins
			local sum, err = R.DataService.EditSlot(player, slot, function(d)
				if look then
					d.look = look
				end
				if not useBank then
					if (d.spins or 0) <= 0 then
						noSpins = true
						return
					end
					d.spins -= 1
				end
				rolled = Looks.RollHeritage()
				d.heritage = rolled
				d.heritageVariant = Looks.RollVariant(rolled)
				d.heritageMode = "flame"
			end)
			return sum, err, rolled, noSpins
		end
		local sum, err, rolled, noSpins = roll(false)
		if sum and noSpins then
			if not R.DataService.TakeBankSpin(player.UserId) then
				return false, "No spins left", sum
			end
			sum, err, rolled = roll(true)
			if not sum then
				R.DataService.RefundBankSpin(player.UserId)
			end
		end
		if not sum then
			return false, err
		end
		local h = Looks.HeritageById[rolled]
		if h and h.chance <= 2 then
			Net.PushAll("Announce", { text = "✨ " .. player.DisplayName .. " rolled the " .. h.chance .. "% " .. h.name .. " heritage!", rarity = h.chance <= 0.5 and "Mythic" or "Legendary" })
		end
		return true, nil, { summary = sum, heritage = rolled, variant = sum.variant, bank = R.DataService.BankSpins(player.UserId) }
	end, 1.2, true)
	-- Cinderwing: switch FLAME (hits harder) <-> CALM (moves faster)
	Net.Handle("HeritageMode", function(player)
		local p = PS.Profile(player)
		local h = p and Looks.HeritageById[p.heritage or ""]
		if not h or not h.modes then
			return false, "Your heritage has no modes"
		end
		p.heritageMode = p.heritageMode == "calm" and "flame" or "calm"
		player:SetAttribute("HeritageMode", p.heritageMode)
		if player.Character then
			VoxelChar.SetFlame(player.Character, p.heritageMode ~= "calm")
			local root = PS.Root(player)
			if root then
				Net.FX("HeritageMode", { char = player.Character, mode = p.heritageMode, pos = root.Position }, root.Position, 250)
			end
		end
		PS.Recompute(player)
		return true, p.heritageMode == "calm" and "CALM mode: faster" or "FLAME mode: stronger"
	end, 1.5)
	Net.Handle("MenuPlay", function(player, data)
		local slot = validSlot(data.slot) or 1
		if R.DataService.Get(player) then
			return false, "Already in game"
		end
		if entering[player] then
			return false, "Loading..."
		end
		entering[player] = true
		local ok, p = pcall(enterGame, player, slot)
		entering[player] = nil
		if not ok or not p then
			warn("[PlayerService] MenuPlay failed:", p)
			return false, "Could not load this character, try again"
		end
		task.spawn(PS.Respawn, player)
		return true
	end, 2, true)
	-- in-game MENU button: save + unload this character and go back to the title menu (pick / edit a slot)
	Net.Handle("MenuReturn", function(player)
		if not R.DataService.Get(player) then
			return false, "Not in game"
		end
		for _, fn in ipairs({ R.MarketService.CloseStall, R.ShipService.DespawnShipOf, R.ShipyardService.ExitBuild, R.PartyService.Leave }) do
			pcall(fn, player)
		end
		local char = player.Character
		player.Character = nil
		if char then
			char:Destroy()
		end
		R.DataService.Release(player) -- saves (and frees the session lock)
		derived[player] = nil
		dirty[player] = nil
		for _, a in ipairs({ "Slot", "Heritage", "HeritageMode", "BoostExp", "BoostDrop", "BoostFruit" }) do
			player:SetAttribute(a, nil)
		end
		return true
	end, 3)
	Players.PlayerRemoving:Connect(function(player)
		entering[player] = nil
	end)
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

	-- the Stats window's "Apply": several stats at once, { add = { STR = 3, AGI = 2 } }; all-or-nothing on the cost
	Net.Handle("AllocateStats", function(player, data)
		local p = PS.Profile(player)
		if type(data.add) ~= "table" then
			return false
		end
		local plan, total = {}, 0
		for _, stat in ipairs(Formulas.StatNames) do
			local n = math.floor(tonumber(data.add[stat]) or 0)
			if n < 0 or n > 200 then
				return false, "Invalid amount"
			end
			local cur = p.stats[stat]
			for k = 0, n - 1 do
				if cur + k >= Formulas.MaxStat then
					return false, stat .. " is already at the maximum"
				end
				total += Formulas.StatCost(cur + k)
			end
			plan[stat] = n
		end
		if total == 0 then
			return false, "Nothing to apply"
		end
		if total > p.statPoints then
			return false, "Not enough stat points"
		end
		local raised = 0
		for stat, n in pairs(plan) do
			p.stats[stat] += n
			raised += n
		end
		p.statPoints -= total
		PS.Recompute(player)
		-- "Train Your Body" counts stat points raised (the Stats window applies a whole plan in one request)
		if R.QuestService then
			R.QuestService.Event(player, "Stat", nil, raised)
		end
		return true, "Stats raised"
	end, 0.3)

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
		if lv == 0 then
			PS.BarAdd(p, skill.id)
		end
		PS.MarkDirty(player)
		return true
	end, 0.05)

	-- the whole bar, slot by slot ("" = empty slot); a skill may sit in one slot only
	Net.Handle("SetSkillBar", function(player, data)
		local p = PS.Profile(player)
		if type(data.bar) ~= "table" then
			return false
		end
		local bar, seen = {}, {}
		for i = 1, GameConfig.SkillBarSize do
			local id = data.bar[i]
			local okId = type(id) == "string" and id ~= "" and not seen[id] and usableSkill(p, id)
			bar[i] = okId and id or ""
			if okId then
				seen[id] = true
			end
		end
		p.skillBar = trimBar(bar)
		PS.MarkDirty(player)
		return true
	end)

	-- slingshot ammo pick (Config/Ammo); the shot itself checks you still have some
	Net.Handle("SetAmmo", function(player, data)
		local p = PS.Profile(player)
		local AmmoCfg = require(Shared.Config.Ammo)
		local a = type(data.id) == "string" and AmmoCfg.ById[data.id]
		if not a then
			return false
		end
		if a.item and R.InventoryService.Count(player, a.item) <= 0 then
			return false, "You have no " .. a.name .. " (buy some at the General Store)"
		end
		p.ammo = a.id
		PS.MarkDirty(player)
		return true, a.name .. " loaded"
	end, 0.2)

	-- quick item slots F1-F8: consumable item ids ("" = empty)
	Net.Handle("SetItemBar", function(player, data)
		local p = PS.Profile(player)
		if type(data.bar) ~= "table" then
			return false
		end
		local bar = {}
		for i = 1, GameConfig.ItemBarSize do
			local id = data.bar[i]
			local def = type(id) == "string" and id ~= "" and ItemDB.Get(id)
			bar[i] = (def and def.kind == "Consumable" and not def.special) and id or ""
		end
		p.itemBar = trimBar(bar)
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
		if type(data.autoStats) == "boolean" then
			p.settings.autoStats = data.autoStats
			if data.autoStats then
				task.defer(PS.AutoStats, player)
			end
		end
		if tonumber(data.autoRadius) then
			local ab = GameConfig.AutoBattle
			p.settings.autoRadius = math.clamp(math.floor(data.autoRadius), ab.MinRadius, ab.SearchRadius)
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
		local oldClass = p.class
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
		-- then hand them the best weapon of the new class that they own (highest grade, then refine); the player can
		-- change it afterwards (owner: switching class auto-equips the class weapon)
		if not p.equipment.weapon then
			local best, bestScore
			for _, e in ipairs(p.inventory) do
				local def = ItemDB.Get(e.id)
				if def and def.kind == "Weapon" and table.find(target.weapons, def.weaponType) and (def.reqLevel or 1) <= p.baseLevel then
					local g = ItemDB.Grade(def)
					local score = (g and g.rank or 1) * 100 + (e.refine or 0)
					if not bestScore or score > bestScore then
						best, bestScore = e, score
					end
				end
			end
			if best then
				p.equipment.weapon = best.uid
			end
		end
		-- each class keeps its own bar: save the old one, restore (or build) the new one. Skills of other classes stay
		-- learned but cannot be used here; Common and fruit skills come along. Every learned skill of the class gets a slot.
		p.classBars = p.classBars or {}
		p.classBars[oldClass] = table.clone(p.skillBar)
		local bar = {}
		for i, id in ipairs(p.classBars[p.class] or p.skillBar) do
			bar[i] = (id ~= "" and usableSkill(p, id)) and id or ""
		end
		p.skillBar = trimBar(bar)
		for _, sk in ipairs(target.skills) do
			if (p.skills[sk.id] or 0) > 0 then
				PS.BarAdd(p, sk.id)
			end
		end
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
	setupMenuHandlers()
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
	local underTime = {}
	Players.PlayerRemoving:Connect(function(pl)
		swimTime[pl] = nil
		underTime[pl] = nil
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
			-- diving (v0.22.4): breath only drains with the head under water, and refills fast at the surface
			local under = inSea and root.Position.Y < GameConfig.SeaLevel - SWIM.SurfaceOffset - 2
			underTime[player] = under and (underTime[player] or 0) + 0.5 or math.max(0, (underTime[player] or 0) - 3)
			local sank = root and hum and hum.Health > 0 and root.Position.Y < GameConfig.SeaLevel - SWIM.MaxDepth - 12 and not onShip
			-- Cursed Fruit users cannot swim: the sea drags them under and they DROWN (HP drains) until they get out or die
			local drowning = player:GetAttribute("Fruit") ~= nil and inSea and root.Position.Y < GameConfig.SeaLevel - 1 and swimTime[player] >= FruitsCfg.SinkSeconds
			if drowning then
				hum.Health = math.max(0, hum.Health - hum.MaxHealth * FruitsCfg.DrownPerSecond * 0.5)
				if not player:GetAttribute("Drowning") then
					player:SetAttribute("Drowning", true)
					PS.Notify(player, "You're drowning! Cursed Fruit users can't swim - get out of the water!", "bad")
				end
			else
				player:SetAttribute("Drowning", nil)
			end
			if not drowning and (sank or swimTime[player] > SWIM.SeaSeconds + 3 or (underTime[player] or 0) > SWIM.BreathSeconds * (player:GetAttribute("Heritage") == "Tidekin" and 1.6 or 1) + 3) then
				local p = PS.Profile(player)
				if p then
					swimTime[player] = 0
					underTime[player] = 0
					hum.Health = math.max(1, hum.Health - hum.MaxHealth * 0.1)
					PS.TeleportTo(player, PS.SpawnCFrame(p.lastIsland))
					PS.Notify(player, "Out of breath! The waves washed you ashore... (sail a ship to cross the sea)", "bad")
				end
			end
		end
	end)
end

return PS
