-- InventoryService: bag, equipment, consumables, card sockets, refining, NPC shop
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Classes = require(Shared.Config.Classes).Classes
local MasteryCfg = require(Shared.Config.Mastery)
local ItemDB = require(Shared.Modules.ItemDB)
local Formulas = require(Shared.Modules.Formulas)
local Net = require(Shared.Modules.Net)

local Inv = {}
local R
local itemCooldowns = {}

function Inv.Init(registry)
	R = registry
end

local function profile(player)
	return R.DataService.Get(player)
end

function Inv.Count(player, id)
	local p = profile(player)
	local n = 0
	for _, e in ipairs(p.inventory) do
		if e.id == id then
			n += e.qty or 1
		end
	end
	return n
end

function Inv.AddItem(player, id, qty, extra)
	local p = profile(player)
	local def = ItemDB.Get(id)
	if not p or not def then
		return false
	end
	qty = qty or 1
	if ItemDB.IsStackable(def) then
		for _, e in ipairs(p.inventory) do
			if e.id == id then
				e.qty += qty
				e.got = os.time() -- trade lock for Pearl stalls restarts
				R.PlayerService.MarkDirty(player)
				return true
			end
		end
		if #p.inventory >= GameConfig.InventorySlots then
			R.PlayerService.Notify(player, "Inventory full!", "bad")
			return false
		end
		table.insert(p.inventory, { uid = R.DataService.NewUid(), id = id, qty = qty, got = os.time() })
	else
		for _ = 1, qty do
			if #p.inventory >= GameConfig.InventorySlots then
				R.PlayerService.Notify(player, "Inventory full!", "bad")
				return false
			end
			local entry = { uid = R.DataService.NewUid(), id = id, qty = 1, refine = 0, cards = {}, got = os.time() }
			if extra then
				entry.refine = extra.refine or 0
				entry.cards = extra.cards or {}
			end
			table.insert(p.inventory, entry)
		end
		if def.blade then -- v0.25.127 Index: the Blade Ledger remembers every blade you ever got
			p.index = p.index or {}
			p.index.blades = p.index.blades or {}
			p.index.blades[id] = true
		end
	end
	R.PlayerService.MarkDirty(player)
	return true
end

function Inv.IsEquipped(p, uid)
	for _, u in pairs(p.equipment) do
		if u == uid then
			return true
		end
	end
	return false
end

-- Remove by uid (never removes equipped items)
function Inv.RemoveUid(player, uid, qty)
	local p = profile(player)
	qty = qty or 1
	for i, e in ipairs(p.inventory) do
		if e.uid == uid then
			if Inv.IsEquipped(p, uid) then
				return false
			end
			if (e.qty or 1) < qty then
				return false
			end
			e.qty = (e.qty or 1) - qty
			if e.qty <= 0 then
				table.remove(p.inventory, i)
			end
			R.PlayerService.MarkDirty(player)
			return true
		end
	end
	return false
end

function Inv.RemoveItem(player, id, qty)
	if Inv.Count(player, id) < qty then
		return false
	end
	local p = profile(player)
	local left = qty
	for i = #p.inventory, 1, -1 do
		local e = p.inventory[i]
		if e.id == id and not Inv.IsEquipped(p, e.uid) then
			local take = math.min(left, e.qty or 1)
			e.qty = (e.qty or 1) - take
			left -= take
			if e.qty <= 0 then
				table.remove(p.inventory, i)
			end
			if left <= 0 then
				break
			end
		end
	end
	R.PlayerService.MarkDirty(player)
	return left <= 0
end

-- cost = { beli = 100, Wood = 2, ... }
function Inv.CanPay(player, cost)
	local p = profile(player)
	for k, v in pairs(cost) do
		if k == "beli" then
			if p.beli < v then
				return false, "Not enough Doubloons"
			end
		elseif Inv.Count(player, k) < v then
			local def = ItemDB.Get(k)
			return false, "Missing material: " .. (def and def.name or k)
		end
	end
	return true
end

function Inv.Pay(player, cost, mult)
	mult = mult or 1
	local ok, msg = Inv.CanPay(player, cost)
	if not ok then
		return false, msg
	end
	for k, v in pairs(cost) do
		if k == "beli" then
			R.PlayerService.AddBeli(player, -math.floor(v * mult))
		else
			Inv.RemoveItem(player, k, math.floor(v * mult))
		end
	end
	return true
end

function Inv.Refund(player, cost)
	for k, v in pairs(cost) do
		if k == "beli" then
			R.PlayerService.AddBeli(player, v)
		else
			Inv.AddItem(player, k, v)
		end
	end
end

local function setup()
	Net.Handle("EquipItem", function(player, data)
		local p = profile(player)
		local entry = Formulas.FindItem(p, data.uid)
		local def = entry and ItemDB.ForEntry(entry)
		if not def or not def.slot then
			return false, "Cannot equip"
		end
		if (def.reqLevel or 1) > p.baseLevel then
			return false, "Requires Lv." .. def.reqLevel
		end
		if def.faction and player:GetAttribute("Faction") ~= def.faction then
			return false, def.faction .. "s only"
		end
		if def.seastone and p.fruit then
			return false, "Seastone drains Cursed Fruit users: you cannot wear it"
		end
		-- remake: any character can use any weapon (no class locks)
		if player:GetAttribute("Vending") then
			return false, "Close your stall first"
		end
		p.equipment[def.slot] = entry.uid
		R.PlayerService.Recompute(player)
		R.WeaponService.RefreshOutfit(player)
		if def.slot == "weapon" then
			R.PlayerService.FollowWeapon(player) -- remake R3 Weapon Arts
		end
		return true
	end)

	Net.Handle("UnequipItem", function(player, data)
		local p = profile(player)
		if type(data.slot) == "string" then
			p.equipment[data.slot] = nil
		end
		R.PlayerService.Recompute(player)
		R.WeaponService.RefreshOutfit(player)
		if data.slot == "weapon" then
			R.PlayerService.FollowWeapon(player) -- remake R3: bare hands = Brawler arts
		end
		return true
	end)

	-- remake M4: can a Patch Plank / Repair Kit be used on your ship right now?
	local function repairCheck(player)
		local ship = R.ShipService.GetShipOf(player)
		if not ship or not R.ShipService.IsAboard(player, ship) then
			return false, "You must be aboard your own ship"
		end
		if ship.hp and ship.maxHp and ship.hp >= ship.maxHp and (ship.flood or 0) < 0.5 then
			return false, "Your ship is not damaged"
		end
		return true
	end

	-- remake M4 (Shipwright): start the Timing Bar for a repair item; UseItem { uid, token, t } finishes it
	Net.Handle("RepairStart", function(player, data)
		local p = profile(player)
		local entry = type(data) == "table" and Formulas.FindItem(p, data.uid)
		local def = entry and ItemDB.ForEntry(entry)
		if not def or not def.shipRepair then
			return false, "Cannot use"
		end
		local key = player.UserId .. def.id
		if itemCooldowns[key] and os.clock() < itemCooldowns[key] then
			return false, "On cooldown"
		end
		local ok, why = repairCheck(player)
		if not ok then
			return false, why
		end
		local run = R.MasteryService.TimingStart(player, "Shipwright", { uid = entry.uid })
		if not run then
			return false
		end
		return { ok = true, data = run }
	end, 0.5)

	Net.Handle("UseItem", function(player, data)
		local p = profile(player)
		local entry = Formulas.FindItem(p, data.uid)
		if not entry and data.id then
			for _, e in ipairs(p.inventory) do
				if e.id == data.id then
					entry = e
					break
				end
			end
		end
		local def = entry and ItemDB.ForEntry(entry)
		if not def or def.kind ~= "Consumable" or def.special then
			return false, "Cannot use"
		end
		local key = player.UserId .. (def.cookedFrom or def.id) -- star dishes share their plain one's cooldown
		if itemCooldowns[key] and os.clock() < itemCooldowns[key] then
			return false, "On cooldown"
		end
		local hum = R.PlayerService.Humanoid(player)
		if not hum or hum.Health <= 0 then
			return false
		end
		if def.shipRepair then
			local ok, why = repairCheck(player)
			if not ok then
				return false, why
			end
			-- remake M4: a timed repair (RepairStart -> Timing Bar) brings its token; no token = a plain repair
			local q = 1
			if data.token then
				local got, run = R.MasteryService.TimingFinish(player, data.token, data.t)
				if got and run and run.uid == entry.uid then
					q = got
				end
			end
			local RC = MasteryCfg.Repair
			if not R.ShipService.RepairOwned(player, def.shipRepair * RC.Mult[q], q >= RC.PlugAt) then
				return false, "You must be aboard your own ship"
			end
			if q > 1 then
				R.PlayerService.Notify(player, q == 3 and "Perfect repair! x" .. RC.Mult[3] .. ", no more leaks" or "Good repair! x" .. RC.Mult[2], "good")
			end
		end
		-- remake 0.1.11 Bandage: the most hurt party member within reach (never a downed one: that is a revive), else
		-- yourself. Goes through CombatService.HealPlayer with you as the healer = healMult + Doctor Mastery XP.
		if def.allyHeal then
			local myRoot = R.PlayerService.Root(player)
			local function hurt(m)
				local mh = R.PlayerService.Humanoid(m)
				local mr = R.PlayerService.Root(m)
				if not (mh and mr and myRoot) or mh.Health <= 0 or R.KnockdownService.IsDowned(m) then
					return nil
				end
				if (mr.Position - myRoot.Position).Magnitude > 20 then
					return nil
				end
				local ratio = mh.Health / math.max(1, mh.MaxHealth)
				return ratio < 0.999 and ratio or nil
			end
			-- others first (the most hurt), yourself only when nobody else needs it
			local best, bestRatio = nil, 1
			for _, m in ipairs(R.PartyService.Members(player)) do
				local ratio = m ~= player and hurt(m)
				if ratio and ratio < bestRatio then
					best, bestRatio = m, ratio
				end
			end
			if not best and hurt(player) then
				best = player
			end
			if not best then
				return false, "Nobody near you is hurt"
			end
			local bh = R.PlayerService.Humanoid(best)
			R.CombatService.HealPlayer(best, bh.MaxHealth * def.allyHeal, player)
			if best ~= player then
				R.PlayerService.Notify(best, player.DisplayName .. " patched you up!", "good")
			end
		end
		-- v0.25.77 Sea Cook Hearty Meal: a feast buff makes food and drinks heal more (buff stat foodHeal)
		-- remake R3: Cook Mastery perks / talents (d.foodMult) add to it, and eating trains Cook Mastery
		local dd = R.PlayerService.Derived(player)
		local foodK = 1 + (R.CombatService.GetBuffs(player).foodHeal or 0) + (dd and dd.foodMult or 0)
		if (def.heal or def.healSp) and not def.shipRepair then
			R.MasteryService.Add(player, "Cook", MasteryCfg.Gain.FoodUse)
		end
		if def.heal then
			hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * def.heal * foodK)
		end
		if def.expBoost then
			p.expBoostUntil = math.max(os.time(), p.expBoostUntil or 0) + def.expBoost
			R.PlayerService.Notify(player, "📘 +50% EXP for " .. math.floor((p.expBoostUntil - os.time()) / 60) .. " minutes", "good")
		end
		if def.healSp then
			local max = player:GetAttribute("MaxSP") or 100
			player:SetAttribute("SP", math.min(max, (player:GetAttribute("SP") or 0) + max * def.healSp * foodK))
		end
		-- Mastery v2 M2: cooked dishes carry a buff (Config/Recipes); a party one reaches everyone near you
		if def.buff then
			local targets = { player }
			if def.buff.party then
				local myRoot = R.PlayerService.Root(player)
				for _, m in ipairs(R.PartyService.Members(player)) do
					local mr = R.PlayerService.Root(m)
					if m ~= player and mr and myRoot and (mr.Position - myRoot.Position).Magnitude <= 40 then
						table.insert(targets, m)
					end
				end
			end
			for _, m in ipairs(targets) do
				R.CombatService.AddBuff(m, def.buff.id or "Food", def.buff.stats, def.buff.dur or 60)
				if m ~= player then
					R.PlayerService.Notify(m, player.DisplayName .. " shared a " .. def.name .. "!", "good")
				end
			end
		end
		-- Mastery v2: Doctor Steady Hands = healing items ready sooner
		local cdK = (def.heal or def.healSp or def.allyHeal) and (1 - (dd and dd.itemCdCut or 0)) or 1
		itemCooldowns[key] = os.clock() + (def.cd or 1) * cdK
		-- Mastery v2: Shipwright Sturdy Patch = a chance to keep the planks / kit
		if not (def.shipRepair and math.random() < (dd and dd.plankSave or 0)) then
			Inv.RemoveUid(player, entry.uid, 1)
		end
		local root = R.PlayerService.Root(player)
		if root then
			Net.FX("UseItem", { pos = root.Position, id = def.id }, root.Position, 200)
		end
		return true
	end, 0.2)

	Net.Handle("InsertCard", function(player, data)
		local p = profile(player)
		local cardEntry = Formulas.FindItem(p, data.cardUid)
		local target = Formulas.FindItem(p, data.targetUid)
		local cardDef = cardEntry and ItemDB.Get(cardEntry.id)
		local targetDef = target and ItemDB.ForEntry(target)
		if not cardDef or cardDef.kind ~= "Card" or not targetDef then
			return false, "Invalid request"
		end
		if targetDef.slot ~= cardDef.cardSlot then
			return false, "This card only fits: " .. cardDef.cardSlot
		end
		target.cards = target.cards or {}
		if #target.cards >= (targetDef.slots or 0) then
			return false, "No free card slot"
		end
		if not R.WorldBuilder.NearNPC(player, "Blacksmith") then
			return false, "Visit a Blacksmith to socket cards"
		end
		table.insert(target.cards, cardDef.id)
		Inv.RemoveUid(player, cardEntry.uid, 1)
		R.PlayerService.Recompute(player)
		return true, "Card socketed!"
	end, 0.3)

	Net.Handle("Refine", function(player, data)
		local p = profile(player)
		local entry = Formulas.FindItem(p, data.uid)
		local def = entry and ItemDB.ForEntry(entry)
		if not def or not def.refinable then
			return false, "Cannot be refined"
		end
		if not R.WorldBuilder.NearNPC(player, "Blacksmith") then
			return false, "Stand near a Blacksmith"
		end
		local cfg = GameConfig.Refine
		local cur = entry.refine or 0
		if cur >= cfg.Max then
			return false, "Already at max refine"
		end
		local canEvo, _, need = ItemDB.AscendInfo(entry)
		if canEvo and cur >= need then
			return false, "Top of its rarity: EVOLVE it" -- v0.25.106: the track ends at the evolve level
		end
		local mat, matQty, beliCost = ItemDB.RefineMaterial(cur)
		local ok, msg = Inv.Pay(player, { beli = beliCost, [mat] = matQty })
		if not ok then
			return false, msg
		end
		local guard = data.useGuard == true and Inv.Count(player, "RefineGuard") > 0
		if guard then
			Inv.RemoveItem(player, "RefineGuard", 1)
		end
		local cls = Classes[p.class]
		local chance = cfg.Chance[cur + 1] + (cls.passive and cls.passive.refineBonus or 0)
		local root = R.PlayerService.Root(player)
		if math.random() < chance then
			entry.refine = cur + 1
			R.PlayerService.Recompute(player)
			if root then
				Net.FX("RefineSuccess", { pos = root.Position }, root.Position, 200)
			end
			if entry.refine >= 7 then
				Net.PushAll("Announce", { text = player.DisplayName .. " refined " .. def.name .. " to +" .. entry.refine .. "!" })
			end
			return { ok = true, msg = "Success! +" .. entry.refine, data = { result = "success", refine = entry.refine } }
		end
		if root then
			Net.FX("RefineFail", { pos = root.Position }, root.Position, 200)
		end
		if cur >= cfg.BreakFrom and not guard and math.random() < cfg.BreakChance then
			for slot, uid in pairs(p.equipment) do
				if uid == entry.uid then
					p.equipment[slot] = nil
				end
			end
			for i, e in ipairs(p.inventory) do
				if e == entry then
					table.remove(p.inventory, i)
					break
				end
			end
			R.PlayerService.Recompute(player)
			return { ok = true, msg = "The item shattered...", data = { result = "broken" } }
		end
		if cur > cfg.Safe and not guard then
			entry.refine = cur - 1
		end
		R.PlayerService.Recompute(player)
		return { ok = true, msg = guard and "Failed (Willpower Charm protected it)" or "Failed... refine level dropped", data = { result = "fail", refine = entry.refine } }
	end, 0.6)

	-- v0.25.105 Ascend: a weapon refined to NeedRefine[rarity] climbs one rarity (ItemDB.ForEntry), refine resets to +0
	Net.Handle("Ascend", function(player, data)
		local p = profile(player)
		local entry = type(data) == "table" and Formulas.FindItem(p, data.uid)
		if not entry then
			return false, "Item not found"
		end
		local ok, nextR, need, cost = ItemDB.AscendInfo(entry)
		if not ok then
			return false, nextR
		end
		if not R.WorldBuilder.NearNPC(player, "Blacksmith") then
			return false, "Stand near a Blacksmith"
		end
		if (entry.refine or 0) < need then
			return false, "Refine it to +" .. need .. " first"
		end
		local paid, msg = Inv.Pay(player, cost)
		if not paid then
			return false, msg
		end
		entry.asc = (entry.asc or 0) + 1
		entry.refine = 0
		R.PlayerService.Recompute(player)
		R.PlayerService.MarkDirty(player)
		local root = R.PlayerService.Root(player)
		if root then
			Net.FX("RefineSuccess", { pos = root.Position }, root.Position, 200)
		end
		local def = ItemDB.ForEntry(entry)
		Net.PushAll("Announce", { text = player.DisplayName .. " evolved " .. def.name .. " to " .. string.upper(nextR) .. "!" })
		return { ok = true, msg = "Evolved to " .. nextR .. "!", data = { result = "evolved", rarity = nextR } }
	end, 0.6)

	Net.Handle("ShopBuy", function(player, data)
		local def = ItemDB.Get(data.id)
		local qty = math.clamp(math.floor(tonumber(data.qty) or 1), 1, 99)
		if not def or not table.find(ItemDB.Shop, def.id) then
			return false, "Not sold here"
		end
		if not R.WorldBuilder.NearNPC(player, "Shop") then
			return false, "Stand near a shop"
		end
		if not def.stack then
			qty = 1
		end
		if not R.PlayerService.AddBeli(player, -def.price * qty) then
			return false, "Not enough Doubloons"
		end
		Inv.AddItem(player, def.id, qty)
		return true, "Bought " .. def.name .. " x" .. qty
	end, 0.2)

	-- v0.25.123 blade roll (GameConfig.BladeRoll): pay the fee to see one random blade, then BUY it or PASS
	local offers = {} -- [player] = { id, at }
	Net.Handle("BladeLook", function(player)
		local cfg = GameConfig.BladeRoll
		if not R.WorldBuilder.NearNPC(player, "Shop") then
			return false, "Stand near a shop"
		end
		if not R.PlayerService.AddBeli(player, -cfg.Fee) then
			return false, "Not enough Doubloons"
		end
		local tier = math.random() < cfg.TideChance and "Tide" or "Fathom"
		local list = ItemDB.Blades[tier]
		local id = list[math.random(#list)]
		offers[player] = { id = id, at = os.clock() }
		return { ok = true, data = { id = id } }
	end, 0.8)
	Net.Handle("BladeBuy", function(player)
		local o = offers[player]
		if not o or os.clock() - o.at > GameConfig.BladeRoll.Seconds then
			offers[player] = nil
			return false, "The merchant put that blade away"
		end
		if not R.WorldBuilder.NearNPC(player, "Shop") then
			return false, "Stand near a shop"
		end
		local def = ItemDB.Get(o.id)
		if not R.PlayerService.AddBeli(player, -def.price) then
			return false, "Not enough Doubloons"
		end
		offers[player] = nil
		Inv.AddItem(player, def.id, 1)
		return true, "Bought " .. def.name
	end, 0.5)
	Net.Handle("BladePass", function(player)
		offers[player] = nil
		return true
	end, 0.2)
	game:GetService("Players").PlayerRemoving:Connect(function(pl)
		offers[pl] = nil
	end)

	Net.Handle("ShopSell", function(player, data)
		local p = profile(player)
		local entry = Formulas.FindItem(p, data.uid)
		local def = entry and ItemDB.ForEntry(entry)
		if not def then
			return false
		end
		if not R.WorldBuilder.NearNPC(player, "Shop") then
			return false, "Stand near a shop"
		end
		local qty = math.clamp(math.floor(tonumber(data.qty) or 1), 1, entry.qty or 1)
		if not Inv.RemoveUid(player, entry.uid, qty) then
			return false, "Cannot sell (unequip it first)"
		end
		R.PlayerService.AddBeli(player, math.floor(math.min((def.price or 0) * 0.5, def.sellCap or math.huge)) * qty) -- sellCap: cooked food (Config/Recipes)
		return true
	end, 0.2)
end

function Inv.Start()
	setup()
end

return Inv
