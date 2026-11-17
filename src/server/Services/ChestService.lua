-- ChestService: exploration chests (built by WorldBuilder, tagged "Chest"). One open per player per chest.
-- Anti-exploit: opening goes through the ProximityPrompt (server-side Triggered), the server re-checks distance,
-- the opened flag is saved in the profile, and rewards are computed only on the server.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local ChestsCfg = require(Shared.Config.Chests)
local PearlsCfg = require(Shared.Config.Pearls)
local Islands = require(Shared.Config.Islands)
local Formulas = require(Shared.Modules.Formulas)
local Net = require(Shared.Modules.Net)

local CS = {}
local R
local byIsland = {} -- islandId -> { chestId, ... }

local function islandLevel(islandId)
	local isl = Islands.ById[islandId]
	return isl and isl.levels[1] or 1
end

-- roll a reward table for a tier at an island level
local function roll(def, level)
	local beli = math.floor(def.beli * math.max(1, level) ^ 0.8)
	local exp = math.floor(Formulas.BaseExpToNext(math.max(1, level)) * def.expPct)
	local items = {}
	for _, it in ipairs(def.items or {}) do
		if math.random() < it[3] then
			table.insert(items, { id = it[1], qty = it[2] })
		end
	end
	return beli, exp, items
end

local function give(player, beli, exp, items)
	R.PlayerService.AddBeli(player, beli)
	R.PlayerService.GiveExp(player, exp, math.floor(exp * 0.5))
	for _, it in ipairs(items) do
		R.InventoryService.AddItem(player, it.id, it.qty)
	end
	Net.Push(player, "Loot", { beli = beli, items = items })
end

local function countFound(p, islandId)
	local found = 0
	for _, id in ipairs(byIsland[islandId] or {}) do
		if p.chests[id] then
			found += 1
		end
	end
	return found, #(byIsland[islandId] or {})
end

local function open(player, model)
	local p = R.PlayerService.Profile(player)
	local root = R.PlayerService.Root(player)
	if not p or not root or not model.PrimaryPart then
		return
	end
	p.chests = p.chests or {}
	local id = model:GetAttribute("ChestId")
	local tier = model:GetAttribute("Tier")
	local islandId = model:GetAttribute("Island")
	local def = ChestsCfg.Tiers[tier]
	if not def or not id then
		return
	end
	if p.chests[id] then
		R.PlayerService.Notify(player, "You already looted this chest.", "info")
		return
	end
	if (root.Position - model.PrimaryPart.Position).Magnitude > ChestsCfg.MaxOpenDistance then
		return -- too far: a spoofed trigger
	end
	p.chests[id] = true
	R.PlayerService.MarkDirty(player)
	local beli, exp, items = roll(def, islandLevel(islandId))
	give(player, beli, exp, items)
	R.PetService.RollChestEgg(player, tier)
	if tier == "Captain" then
		R.FruitService.RollDrop(player, require(Shared.Config.Fruits).Drops.CaptainChest, def.name)
	end
	local found, total = countFound(p, islandId)
	Net.Push(player, "ChestOpened", { id = id, tier = tier, rarity = def.rarity, name = def.name, island = islandId, found = found, total = total })
	Net.FX("ChestOpen", { pos = model.PrimaryPart.Position, rarity = def.rarity }, model.PrimaryPart.Position, 200)
	R.QuestService.Event(player, "Chest", tier)
	R.PearlService.Earn(player, PearlsCfg.Sources.Chest[tier] or 0, "chest")
	if found == total and total > 0 then
		local b = ChestsCfg.IslandBonus
		local bBeli, bExp, bItems = roll(b, islandLevel(islandId))
		give(player, bBeli, bExp, bItems)
		local isl = Islands.ById[islandId]
		R.PearlService.Earn(player, PearlsCfg.Sources.IslandExplored, "explored")
		Net.Push(player, "Banner", { title = "Island Explored!", subtitle = "All " .. total .. " chests on " .. (isl and isl.name or islandId) .. " found" })
	end
end

function CS.Init(registry)
	R = registry
end

function CS.Start()
	for _, m in ipairs(CollectionService:GetTagged("Chest")) do
		local islandId = m:GetAttribute("Island")
		byIsland[islandId] = byIsland[islandId] or {}
		table.insert(byIsland[islandId], m:GetAttribute("ChestId"))
		local prompt = m:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			-- the chest shakes and rattles for a moment (client FX), then opens; one open in flight per player+chest
			local opening = {}
			prompt.Triggered:Connect(function(player)
				local p = R.PlayerService.Profile(player)
				if opening[player] or not m.PrimaryPart or (p and p.chests and p.chests[m:GetAttribute("ChestId")]) then
					if p and p.chests and p.chests[m:GetAttribute("ChestId")] then
						R.PlayerService.Notify(player, "You already looted this chest.", "info")
					end
					return
				end
				opening[player] = true
				Net.FX("ChestShake", { model = m, pos = m.PrimaryPart.Position, time = 0.85 }, m.PrimaryPart.Position, 120)
				task.delay(0.85, function()
					opening[player] = nil
					local ok, err = pcall(open, player, m)
					if not ok then
						warn("[ChestService]", err)
					end
				end)
			end)
		end
	end
	Net.Handle("ChestCounts", function(player)
		local p = R.PlayerService.Profile(player)
		if not p then
			return false
		end
		p.chests = p.chests or {}
		local out = {}
		for islandId in pairs(byIsland) do
			local f, t = countFound(p, islandId)
			out[islandId] = { found = f, total = t }
		end
		return { ok = true, data = out }
	end, 1)
end

return CS
