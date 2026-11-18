-- StoreService (v0.24.0, owner): BENEFITS + BOOSTS (Config/Store), paid with Gems (PearlService.Spend) or Robux
-- (developer products, PearlService's ProcessReceipt hands them here), for yourself or as a gift to a player in this
-- server. A Robux gift is registered first (StoreBuyRobux stores the recipient), then the receipt grants it; receipts
-- are recorded in the buyer's profile so a purchase is never granted twice.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Modules.Net)
local Formulas = require(Shared.Modules.Formulas)
local StoreCfg = require(Shared.Config.Store)

local Store = {}
local R
local byId, byProduct = {}, {}
for _, list in ipairs({ StoreCfg.Benefits, StoreCfg.Boosts }) do
	for _, it in ipairs(list) do
		byId[it.id] = it
		if it.productId and it.productId ~= 0 then
			byProduct[it.productId] = it
		end
	end
end
local pendingGift = {} -- buyer -> { id, to (Player), t }

local BOOST_ATTR = { exp = "BoostExp", drop = "BoostDrop", fruit = "BoostFruit" }

function Store.Init(registry)
	R = registry
end

local function boosts(p)
	p.boosts = p.boosts or {}
	return p.boosts
end

function Store.BoostActive(player, kind)
	local p = R.DataService.Get(player)
	return p ~= nil and (boosts(p)[kind] or 0) > os.time()
end

function Store.SetAttributes(player)
	local p = R.DataService.Get(player)
	if not p then
		return
	end
	for kind, attr in pairs(BOOST_ATTR) do
		local untilT = boosts(p)[kind] or 0
		player:SetAttribute(attr, untilT > os.time() and untilT or nil)
	end
end

-- refund every spent stat point
local function resetStats(player, p)
	local refund = 0
	for _, stat in ipairs(Formulas.StatNames) do
		for v = 1, (p.stats[stat] or 1) - 1 do
			refund += Formulas.StatCost(v)
		end
		p.stats[stat] = 1
	end
	p.statPoints += refund
	R.PlayerService.Recompute(player)
	return refund
end

-- apply an item to `to`. Returns ok, message for the recipient
local function grant(to, it, fromName)
	local p = R.DataService.Get(to)
	if not p then
		return false, "Player is not in the game"
	end
	p.storeTokens = p.storeTokens or {}
	local msg
	if it.boost then
		local b = boosts(p)
		b[it.boost] = math.max(b[it.boost] or 0, os.time()) + it.minutes * 60
		msg = it.name .. " active!"
	elseif it.id == "ResetStats" then
		msg = "Stats reset: " .. resetStats(to, p) .. " points refunded"
	elseif it.id == "FruitRemover" then
		if p.fruit and R.FruitService.RemoveFruit then
			R.FruitService.RemoveFruit(to)
			msg = "Your Cursed Fruit is gone: you can eat a new one"
		else
			p.storeTokens.FruitRemover = (p.storeTokens.FruitRemover or 0) + 1
			msg = "Fruit Remover saved: use it from the Store when you have a fruit"
		end
	elseif it.id == "BossRespawn" then
		local n = R.BossService.RespawnAllNow and R.BossService.RespawnAllNow() or 0
		Net.PushAll("Announce", { text = "👑 " .. to.DisplayName .. " called the bosses back! (" .. n .. ")", rarity = "Legendary" })
		msg = n > 0 and ("Bosses respawning: " .. n) or "Every boss is already up"
	end
	Store.SetAttributes(to)
	R.PlayerService.MarkDirty(to)
	if fromName then
		R.PlayerService.Notify(to, "🎁 " .. fromName .. " gifted you " .. it.name .. "! " .. (msg or ""), "good")
	else
		R.PlayerService.Notify(to, "🛍️ " .. (msg or it.name), "good")
	end
	return true, msg
end

local function recipientOf(player, toUserId)
	if toUserId == nil or tonumber(toUserId) == player.UserId then
		return player
	end
	local to = Players:GetPlayerByUserId(tonumber(toUserId) or 0)
	if not to or not R.DataService.Get(to) then
		return nil
	end
	return to
end

-- PearlService.processReceipt asks here first; returns a decision or nil (not a store product)
function Store.Receipt(info)
	local it = byProduct[info.ProductId]
	if not it then
		return nil
	end
	local buyer = Players:GetPlayerByUserId(info.PlayerId)
	local p = buyer and R.DataService.Get(buyer)
	if not p then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	p.receipts = p.receipts or {}
	if p.receipts[info.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local pend = pendingGift[buyer]
	local to = buyer
	if pend and pend.id == it.id and os.clock() - pend.t < 600 and pend.to.Parent and R.DataService.Get(pend.to) then
		to = pend.to
	end
	pendingGift[buyer] = nil
	p.receipts[info.PurchaseId] = true
	local ok = grant(to, it, to ~= buyer and buyer.DisplayName or nil)
	if not ok and to ~= buyer then
		grant(buyer, it)
	end
	if to ~= buyer then
		R.PlayerService.Notify(buyer, "🎁 Gift sent to " .. to.DisplayName .. ": " .. it.name, "good")
	end
	if R.DataService.Save(buyer) == false then
		p.receipts[info.PurchaseId] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Store.Start()
	R.DataService.Loaded:Connect(function(player)
		Store.SetAttributes(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		pendingGift[player] = nil
	end)
	-- boost timers run out: clear the attributes (the HUD timer reads them)
	task.spawn(function()
		while true do
			task.wait(15)
			for _, pl in ipairs(Players:GetPlayers()) do
				pcall(Store.SetAttributes, pl)
			end
		end
	end)

	Net.Handle("StoreInfo", function(player)
		local p = R.DataService.Get(player)
		return true, nil, { boosts = boosts(p), tokens = p.storeTokens or {}, gems = (p.pearls or 0) + (p.pearlsBound or 0) }
	end, 0.5)

	Net.Handle("StoreBuyGems", function(player, data)
		local it = byId[data.id]
		if not it or not it.gems then
			return false, "Unknown item"
		end
		local to = recipientOf(player, data.to)
		if not to then
			return false, "That player is not here"
		end
		if not R.PearlService.Spend(player, it.gems, "store:" .. it.id .. (to ~= player and (":gift:" .. to.UserId) or ""), true) then
			return false, "Not enough Gems"
		end
		local ok, msg = grant(to, it, to ~= player and player.DisplayName or nil)
		if to ~= player then
			return ok, "🎁 Gift sent to " .. to.DisplayName
		end
		return ok, msg
	end, 0.6)

	Net.Handle("StoreBuyRobux", function(player, data)
		local it = byId[data.id]
		if not it then
			return false, "Unknown item"
		end
		if not it.productId or it.productId == 0 then
			return false, "Robux purchase coming soon (use Gems)"
		end
		local to = recipientOf(player, data.to)
		if not to then
			return false, "That player is not here"
		end
		pendingGift[player] = to ~= player and { id = it.id, to = to, t = os.clock() } or nil
		MarketplaceService:PromptProductPurchase(player, it.productId)
		return true
	end, 1)

	Net.Handle("StoreUseToken", function(player, data)
		local p = R.DataService.Get(player)
		local it = byId[data.id]
		p.storeTokens = p.storeTokens or {}
		if not it or (p.storeTokens[it.id] or 0) <= 0 then
			return false, "You have none"
		end
		if it.id == "FruitRemover" and not p.fruit then
			return false, "You have no Cursed Fruit"
		end
		p.storeTokens[it.id] -= 1
		return grant(player, it)
	end, 1)
end

return Store
