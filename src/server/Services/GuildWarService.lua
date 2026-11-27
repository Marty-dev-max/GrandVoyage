-- GuildWarService: guild war over sea forts (WoE-like)
-- Break a fort's Giant Signal Conch (core) and your guild takes the fort
-- During the war, players of different guilds can fight inside fort zones
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Islands = require(Shared.Config.Islands)
local Net = require(Shared.Modules.Net)
local Formulas = require(Shared.Modules.Formulas)

local GW = {}
local R
local active = false
local endsAt = 0
local owners = {} -- fortId -> { guildId, guildName, faction }
local cores = {} -- fortId -> mob
local FORT_RADIUS = 130

function GW.Init(registry)
	R = registry
end

local function fortPos(fort)
	return Vector3.new(fort.x, 0, fort.z)
end

function GW.IsActive()
	return active
end

local function inFort(player)
	local root = R.PlayerService.Root(player)
	if not root then
		return false
	end
	for _, f in ipairs(Islands.Forts) do
		local d = (Vector2.new(root.Position.X, root.Position.Z) - Vector2.new(f.x, f.z)).Magnitude
		if d <= FORT_RADIUS then
			return true
		end
	end
	return false
end

function GW.CanFight(a, b)
	if not active then
		return false
	end
	local ga, gb = a:GetAttribute("GuildId"), b:GetAttribute("GuildId")
	return ga ~= nil and gb ~= nil and ga ~= gb and inFort(a) and inFort(b)
end

local function broadcast()
	local list = {}
	for _, f in ipairs(Islands.Forts) do
		local o = owners[f.id]
		table.insert(list, { id = f.id, name = f.name, owner = o and o.guildName or "-", faction = o and o.faction or "None" })
	end
	Net.PushAll("GuildWar", { active = active, endsAt = endsAt, serverTime = os.time(), forts = list })
end

local function spawnCore(fort)
	local center = R.MonsterService.GroundAt(fort.x, fort.z)
	local owner = owners[fort.id]
	cores[fort.id] = R.MonsterService.Spawn("FortCore", center, {
		noRespawn = true,
		hpMult = GameConfig.GuildWar.CoreHP / 60000,
		canDamage = function(player)
			local gid = player:GetAttribute("GuildId")
			return active and gid ~= nil and (not owner or owner.guildId ~= gid)
		end,
		onDeath = function(_, killer)
			cores[fort.id] = nil
			if not active then
				return
			end
			if killer and killer:GetAttribute("GuildId") then
				owners[fort.id] = {
					guildId = killer:GetAttribute("GuildId"),
					guildName = killer:GetAttribute("GuildName"),
					faction = killer:GetAttribute("Faction"),
				}
				Net.PushAll("Announce", { text = "🏴 " .. killer:GetAttribute("GuildName") .. " captured " .. fort.name .. "!", kind = "war" })
			end
			broadcast()
			task.delay(3, function()
				if active then
					spawnCore(fort)
				end
			end)
		end,
	})
end

function GW.StartWar()
	if active then
		return
	end
	active = true
	endsAt = os.time() + GameConfig.GuildWar.Duration
	for _, f in ipairs(Islands.Forts) do
		spawnCore(f)
	end
	Net.PushAll("Banner", { title = "GUILD WAR!", subtitle = "The battle for the Azure East forts has begun!" })
	broadcast()
end

function GW.EndWar()
	if not active then
		return
	end
	active = false
	for id, mob in pairs(cores) do
		if not mob.dead then
			R.MonsterService.Kill(mob)
		end
		cores[id] = nil
	end
	-- Rewards: online members of each fort-holding guild
	for _, f in ipairs(Islands.Forts) do
		local o = owners[f.id]
		if o then
			for _, pl in ipairs(Players:GetPlayers()) do
				if pl:GetAttribute("GuildId") == o.guildId then
					R.PlayerService.AddBeli(pl, 100000)
					R.InventoryService.AddItem(pl, "TidecoreShard", 3)
					R.InventoryService.AddItem(pl, "TreasureMap", 1)
					R.PlayerService.Notify(pl, "Fort reward: " .. f.name, "good")
				end
			end
		end
	end
	Net.PushAll("Banner", { title = "GUILD WAR OVER", subtitle = "The forts have been decided" })
	broadcast()
end

function GW.Start()
	Net.Handle("GetGuildWar", function()
		broadcast()
		return true
	end, 2)
	-- Admin commands for testing (game owner or Studio only)
	Net.Handle("Admin", function(player, data)
		if not (RunService:IsStudio() or player.UserId == game.CreatorId) then
			return false, "no permission"
		end
		if data.cmd == "gw_start" then
			GW.StartWar()
		elseif data.cmd == "gw_end" then
			GW.EndWar()
		elseif data.cmd == "level" then
			local p = R.DataService.Get(player)
			p.baseLevel = math.clamp(tonumber(data.value) or 70, 1, GameConfig.MaxBaseLevel)
			p.jobLevel = math.max(p.jobLevel, 10)
			p.statPoints = math.max(0, Formulas.PointsAt(p.baseLevel) - Formulas.Spent(p.stats)) -- every point of the new level
			p.skillPoints += 20
			R.PlayerService.Recompute(player)
		elseif data.cmd == "resetlevel" then
			-- back to a fresh Lv 1 character (class, items, quests kept) to test early combat
			local p = R.DataService.Get(player)
			p.baseLevel, p.baseExp, p.jobLevel, p.jobExp = 1, 0, 1, 0
			p.statPoints, p.skillPoints = Formulas.PointsAt(1), 1
			p.stats = { VIT = 0, END = 0, WIL = 0, WPN = 0, MAR = 0, FRU = 0 }
			for id in pairs(p.skills) do
				p.skills[id] = 1
			end
			R.PlayerService.Recompute(player)
			return true, "Reset to Lv 1"
		elseif data.cmd == "resetall" then
			-- like joining for the very first time: fresh Lv 1 Brawler, starter kit, tutorial quest, start island
			pcall(R.ShipService.DespawnShipOf, player)
			pcall(R.MarketService.CloseStall, player)
			pcall(R.FruitService.RemoveFruit, player)
			pcall(R.CombatService.ClearBuffs, player)
			R.PearlService.DevReset(player)
			R.DataService.ResetProfile(player)
			R.PlayerService.SetAttributes(player)
			pcall(R.TitleService.Refresh, player, true)
			R.PlayerService.Recompute(player)
			R.PlayerService.MarkDirty(player)
			R.QuestService.Push(player, true)
			task.defer(function()
				if player.Parent then
					R.PlayerService.Respawn(player)
				end
			end)
			return true, "Reset to a brand-new player"
		elseif data.cmd == "heritage" then
			-- test any heritage (+ variant) on the current character
			local Looks = require(ReplicatedStorage.Shared.Config.Looks)
			local id, var = string.match(tostring(data.value or ""), "^(%w+):?(%d*)$")
			local h = id and Looks.HeritageById[id]
			if not h then
				return false, "Unknown race"
			end
			local p = R.DataService.Get(player)
			p.heritage = id
			p.heritageVariant = tonumber(var) or 1
			p.heritageMode = "flame"
			player:SetAttribute("Heritage", id)
			player:SetAttribute("HeritageMode", "flame")
			R.PlayerService.Recompute(player)
			task.defer(function()
				if player.Parent then
					R.PlayerService.Respawn(player)
				end
			end)
			return true, "Race: " .. h.name
		elseif data.cmd == "role" then
			-- v0.25.129: "FourTempests" / "SevenPrivateers" / "none", optionally ":PlayerName" (beta top pirates)
			local role, who = string.match(tostring(data.value or ""), "^(%a+):?(.*)$")
			local target = player
			if who and who ~= "" then
				target = nil
				for _, pl in ipairs(Players:GetPlayers()) do
					if string.lower(pl.Name) == string.lower(who) or string.lower(pl.DisplayName) == string.lower(who) then
						target = pl
					end
				end
				if not target then
					return false, "No player " .. who .. " in this server"
				end
			end
			local tp = R.PlayerService.Profile(target)
			if not tp then
				return false, "Not loaded"
			end
			tp.titles = tp.titles or {}
			for _, id in ipairs({ "FourTempests", "SevenPrivateers" }) do
				tp.titles[id] = nil
				if tp.title == id then
					tp.title = ""
				end
			end
			if role ~= "none" then
				if role ~= "FourTempests" and role ~= "SevenPrivateers" then
					return false, "Unknown role " .. tostring(role)
				end
				R.TitleService.Grant(target, role)
				tp.title = role
			end
			R.PlayerService.MarkDirty(target)
			R.TitleService.Refresh(target, true)
			return true, "Role " .. tostring(role) .. " -> " .. target.Name
		elseif data.cmd == "toki" then
			-- v0.25.70: "Conqueror" / "none" on yourself, or "Conqueror:PlayerName" / "none:PlayerName" (beta top players)
			local kind, who = string.match(tostring(data.value or ""), "^(%a+):?(.*)$")
			local target = player
			if who and who ~= "" then
				target = nil
				for _, pl in ipairs(Players:GetPlayers()) do
					if string.lower(pl.Name) == string.lower(who) or string.lower(pl.DisplayName) == string.lower(who) then
						target = pl
					end
				end
				if not target then
					return false, "No player " .. who .. " in this server"
				end
			end
			if kind == "none" then
				for _, k in ipairs({ "Conqueror", "Armament", "Observation" }) do
					R.TokiService.Remove(target, k)
				end
				return true, "Toki removed from " .. target.Name
			end
			if not R.TokiService.Grant(target, kind, "dev") then
				return false, "Unknown Toki or already has it"
			end
			return true, kind .. " Toki given to " .. target.Name
		elseif data.cmd == "removefruit" then
			if not R.FruitService.RemoveFruit(player) then
				return false, "No fruit to remove"
			end
			return true, "Fruit power removed"
		elseif data.cmd == "beli" then
			R.PlayerService.AddBeli(player, tonumber(data.value) or 1000000)
		elseif data.cmd == "items" then
			for _, id in ipairs({ "IronIngot", "Gunpowder", "Wood", "SailCloth", "SteelOre", "TidecoreShard", "PureTidecore", "TreasureWood" }) do
				R.InventoryService.AddItem(player, id, 50)
			end
		elseif data.cmd == "weapons" then -- v0.25.105: every famed blade + green class weapon (Index / Evolve tests)
			local ItemDB = require(Shared.Modules.ItemDB)
			local list = table.clone(ItemDB.Greens)
			for _, tier in ipairs({ "Fathom", "Tide", "Awakened" }) do
				table.move(ItemDB.Blades[tier], 1, #ItemDB.Blades[tier], #list + 1, list)
			end
			for _, id in ipairs(list) do
				R.InventoryService.AddItem(player, id, 1)
			end
		-- ===== test helpers for fruits / pets / pearls / quests =====
		elseif data.cmd == "fruit" then
			local Fruits = require(Shared.Config.Fruits)
			local f = Fruits.ById[tostring(data.value)]
			if not f then
				return false, "Unknown fruit"
			end
			R.FruitService.Give(player, f, "dev")
		elseif data.cmd == "mastery" then
			R.FruitService.GainMastery(player, 5000)
		elseif data.cmd == "spawnfruit" then
			R.FruitService.SpawnTreeFruit() -- alert only if the tester holds the Fruit Notifier (v0.25.61)
		elseif data.cmd == "models" then
			local n = R.AssetService.Gallery(player)
			local failed = {}
			for name in pairs(R.AssetService.Failed) do
				table.insert(failed, name)
			end
			return true, n .. " models" .. (#failed > 0 and ("  •  failed: " .. table.concat(failed, ", ")) or "")
		elseif data.cmd == "eggs" then
			R.InventoryService.AddItem(player, "SeaEgg", 3)
			R.InventoryService.AddItem(player, "GoldenEgg", 2)
			R.InventoryService.AddItem(player, "SeaBait", 10)
		elseif data.cmd == "petlevel" then
			local p = R.DataService.Get(player)
			local pet = p.activePet and R.PetService.Find(p, p.activePet)
			if not pet then
				return false, "Summon a pet first"
			end
			pet.level = math.min(50, pet.level + 15)
			R.PetService.SetAttributes(player, p)
			R.PlayerService.MarkDirty(player)
		elseif data.cmd == "pearls" then
			R.PearlService.Credit(player, 1000, "dev")
		elseif data.cmd == "joblevel" then
			local p = R.DataService.Get(player)
			p.jobLevel = math.max(p.jobLevel, 10)
			p.skillPoints += 10
			R.PlayerService.Recompute(player)
		elseif data.cmd == "questnext" then
			local p = R.DataService.Get(player)
			p.quest = p.quest or { step = 1, progress = 0 }
			p.quest.step += 1
			p.quest.progress = 0
			R.PlayerService.MarkDirty(player)
			R.QuestService.Push(player, true)
		elseif data.cmd == "chestreset" then
			local p = R.DataService.Get(player)
			p.chests = {}
			R.PlayerService.MarkDirty(player)
		end
		return true, "ok"
	end, 0.5)

	task.spawn(function()
		while true do
			task.wait(20)
			local t = os.date("!*t")
			if not active then
				for _, s in ipairs(GameConfig.GuildWar.Schedule) do
					if t.wday == s.wday and t.hour == s.hour and t.min >= s.minute and t.min < s.minute + 2 then
						GW.StartWar()
					end
				end
			elseif os.time() >= endsAt then
				GW.EndWar()
			end
		end
	end)
end

return GW
