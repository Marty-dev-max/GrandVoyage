-- PearlService: Pearls currency with a daily earn cap, a ledger of every change, trading gates, the Pearl Shop
-- and Robux purchases (idempotent ProcessReceipt). See Config/Pearls for every number.
--
-- Profile fields: pearls (tradable), pearlsBound (from Robux: shop only), pearlDay = { day, earned },
-- pearlFrozen (trading frozen for review), perks = { stallSlots = true, freeSwitch = n }, receipts = { [id] = true }
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Pearls = require(Shared.Config.Pearls)
local ItemDB = require(Shared.Modules.ItemDB)
local Net = require(Shared.Modules.Net)

local PS = {}
local R
local ledgerStore
local ledgerBuffer = {} -- userId -> { entries }
local hourly = {} -- player -> { t0, income }

local function today()
	return os.date("!%Y%m%d")
end

local function prof(player)
	local p = R.PlayerService.Profile(player)
	if p then
		p.pearls = p.pearls or 0
		p.pearlsBound = p.pearlsBound or 0
		p.perks = p.perks or {}
		p.receipts = p.receipts or {}
		if type(p.pearlDay) ~= "table" or p.pearlDay.day ~= today() then
			p.pearlDay = { day = today(), earned = 0 }
		end
	end
	return p
end

local function sync(player, p)
	player:SetAttribute("Pearls", p.pearls + p.pearlsBound)
	player:SetAttribute("PearlsTradable", p.pearls)
	R.PlayerService.MarkDirty(player)
end

local function log(player, delta, source, p)
	local buf = ledgerBuffer[player.UserId] or {}
	table.insert(buf, { t = os.time(), d = delta, s = source, bal = p.pearls, bound = p.pearlsBound })
	ledgerBuffer[player.UserId] = buf
end

local function flush(userId)
	local buf = ledgerBuffer[userId]
	if not buf or #buf == 0 or not ledgerStore then
		return
	end
	ledgerBuffer[userId] = nil
	pcall(function()
		ledgerStore:UpdateAsync("u_" .. userId .. "_" .. today(), function(old)
			old = old or {}
			for _, e in ipairs(buf) do
				table.insert(old, e)
			end
			while #old > 500 do
				table.remove(old, 1)
			end
			return old
		end)
	end)
end

-- Earn from a gameplay source (capped per day unless ignoreCap: one-time sources such as achievements).
-- Returns the amount actually granted.
function PS.Earn(player, amount, source, ignoreCap)
	local p = prof(player)
	if not p or amount <= 0 then
		return 0
	end
	local room = ignoreCap and amount or (Pearls.DailyCap - p.pearlDay.earned)
	local got = math.max(0, math.min(amount, room))
	if got <= 0 then
		return 0
	end
	if not ignoreCap then
		p.pearlDay.earned += got
	end
	p.pearls += got
	log(player, got, source, p)
	sync(player, p)
	Net.Push(player, "PearlGain", { amount = got, source = source, capped = got < amount })
	return got
end

-- Market income / refunds: tradable, not capped, but watched for abnormal rates
local function credit(player, amount, source)
	local p = prof(player)
	p.pearls += amount
	log(player, amount, source, p)
	local h = hourly[player]
	if not h or os.clock() - h.t0 > 3600 then
		h = { t0 = os.clock(), income = 0 }
		hourly[player] = h
	end
	h.income += amount
	if source == "market" and h.income > Pearls.Trade.HourlyIncomeFlag and not p.pearlFrozen then
		p.pearlFrozen = true
		warn("[PearlService] trading frozen for review:", player.UserId, h.income)
		R.PlayerService.Notify(player, "Gem trading is paused for a review of unusual activity.", "bad")
	end
	sync(player, p)
end
PS.Credit = credit

-- Spend. allowBound = shop purchases may use Robux Pearls (spent first); trades may not.
function PS.Spend(player, amount, reason, allowBound)
	local p = prof(player)
	if not p or amount <= 0 then
		return false
	end
	local bound = allowBound and math.min(p.pearlsBound, amount) or 0
	if p.pearls + bound < amount then
		return false
	end
	p.pearlsBound -= bound
	p.pearls -= (amount - bound)
	log(player, -amount, reason, p)
	sync(player, p)
	return true
end

-- Dev reset: the balance goes to 0 and the ledger says why
function PS.DevReset(player)
	local p = prof(player)
	if not p then
		return
	end
	local total = p.pearls + p.pearlsBound
	if total > 0 then
		p.pearls, p.pearlsBound = 0, 0
		log(player, -total, "dev_reset", p)
	end
	sync(player, p)
end

function PS.CanTrade(player)
	local p = prof(player)
	if not p then
		return false, "Not loaded"
	end
	if p.pearlFrozen then
		return false, "Your Gem trading is paused for review"
	end
	if p.baseLevel < Pearls.Trade.MinLevel then
		return false, "Gem trading unlocks at Lv." .. Pearls.Trade.MinLevel
	end
	if player.AccountAge < Pearls.Trade.MinAccountAgeDays then
		return false, "Your Roblox account must be " .. Pearls.Trade.MinAccountAgeDays .. " days old to trade Gems"
	end
	return true
end

function PS.ReferencePrice(itemId)
	local def = ItemDB.Get(itemId)
	return math.max(1, math.floor((def and def.price or 250) / Pearls.Trade.DoubloonsPerPearl))
end

function PS.PriceOk(itemId, unitPrice)
	local ref = PS.ReferencePrice(itemId)
	local lo, hi = math.max(1, math.floor(ref * Pearls.Trade.BandMin)), math.ceil(ref * Pearls.Trade.BandMax)
	return unitPrice >= lo and unitPrice <= hi, lo, hi
end

function PS.TradeLocked(entry)
	return entry.got ~= nil and os.time() - entry.got < Pearls.Trade.LockHours * 3600
end

-- ===== Robux =====
local productById = {}
for _, prod in ipairs(Pearls.Products) do
	if prod.productId ~= 0 then
		productById[prod.productId] = prod
	end
end

-- Heritage spin packs (Config/Spins): granted to the account spin bank, works on the title menu too
local SpinsCfg = require(Shared.Config.Spins)
local spinPackById = {}
for _, sp in ipairs(SpinsCfg.Products) do
	if sp.productId and sp.productId ~= 0 then
		spinPackById[sp.productId] = sp
	end
end

local function processReceipt(info)
	local pack = spinPackById[info.ProductId]
	if pack then
		if not R.DataService.GrantBankSpins(info.PlayerId, info.PurchaseId, pack.spins) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local buyer = Players:GetPlayerByUserId(info.PlayerId)
		if buyer then
			Net.Push(buyer, "SpinsBought", { spins = pack.spins, bank = R.DataService.BankSpins(info.PlayerId) })
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local prod = productById[info.ProductId]
	if not player or not prod then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local p = prof(player)
	if not p then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if p.receipts[info.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already granted (idempotent)
	end
	p.receipts[info.PurchaseId] = true
	p.pearlsBound += prod.pearls
	log(player, prod.pearls, "robux:" .. info.ProductId, p)
	sync(player, p)
	-- grant only counts once it is saved
	local ok = R.DataService.Save and R.DataService.Save(player)
	if ok == false then
		p.receipts[info.PurchaseId] = nil
		p.pearlsBound -= prod.pearls
		sync(player, p)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Net.Push(player, "PearlGain", { amount = prod.pearls, source = "purchase" })
	flush(player.UserId)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function PS.Init(registry)
	R = registry
end

function PS.Start()
	pcall(function()
		ledgerStore = DataStoreService:GetDataStore(Pearls.LedgerStore)
	end)
	if next(productById) or next(spinPackById) then
		MarketplaceService.ProcessReceipt = processReceipt
	end
	R.DataService.Loaded:Connect(function(player) -- v0.24.0: once a character slot is loaded (title menu)
		task.delay(3, function()
			local p = prof(player)
			if p then
				sync(player, p)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		hourly[player] = nil
		flush(player.UserId)
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			for userId in pairs(ledgerBuffer) do
				flush(userId)
			end
		end
	end)

	Net.Handle("PearlInfo", function(player)
		local p = prof(player)
		local canTrade, why = PS.CanTrade(player)
		local products = {}
		for _, prod in ipairs(Pearls.Products) do
			table.insert(products, { productId = prod.productId, pearls = prod.pearls, name = prod.name })
		end
		return { ok = true, data = {
			pearls = p.pearls, bound = p.pearlsBound, earnedToday = p.pearlDay.earned, cap = Pearls.DailyCap,
			canTrade = canTrade, tradeWhy = why, perks = p.perks, products = products,
		} }
	end, 0.5)

	Net.Handle("PearlShopBuy", function(player, data)
		local p = prof(player)
		local item
		for _, it in ipairs(Pearls.Shop) do
			if it.id == data.id then
				item = it
			end
		end
		if not item then
			return false, "Unknown item"
		end
		if item.once and p.perks[item.perk] then
			return false, "You already own this"
		end
		if not PS.Spend(player, item.price, "shop:" .. item.id, true) then
			return false, "Not enough Gems"
		end
		if item.kind == "item" then
			R.InventoryService.AddItem(player, item.item, item.qty)
		elseif item.perk == "freeSwitch" then
			p.perks.freeSwitch = (p.perks.freeSwitch or 0) + 1
		else
			p.perks[item.perk] = true
		end
		R.PlayerService.MarkDirty(player)
		return true, "Bought " .. item.name
	end, 0.5)

	Net.Handle("PearlBuyProduct", function(player, data)
		local id = tonumber(data.productId) or 0
		if not productById[id] then
			return false, "Not on sale yet"
		end
		MarketplaceService:PromptProductPurchase(player, id)
		return true
	end, 1)
end

return PS
