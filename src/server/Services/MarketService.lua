-- MarketService: player vending stalls (Ragnarok-style) inside towns
-- Listed items move into escrow; closing the stall or leaving returns them
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Classes = require(Shared.Config.Classes).Classes
local ItemDB = require(Shared.Modules.ItemDB)
local Formulas = require(Shared.Modules.Formulas)
local SeaZones = require(Shared.Modules.SeaZones)
local Net = require(Shared.Modules.Net)
local ModelFactory = require(script.Parent.Parent.World.ModelFactory)
local PearlsCfg = require(Shared.Config.Pearls)

local Market = {}
local R
local stalls = {} -- seller -> { title, items = { {entry, qty, price} }, model }
local mcfg = GameConfig.Market

function Market.Init(registry)
	R = registry
end

local function inTown(player)
	local root = R.PlayerService.Root(player)
	if not root then
		return false
	end
	local island, d = SeaZones.NearestIsland(root.Position)
	return island ~= nil and d <= island.townRadius + 40
end

local function listing(stall)
	local out = {}
	for i, it in ipairs(stall.items) do
		table.insert(out, { index = i, id = it.entry.id, refine = it.entry.refine, asc = it.entry.asc, cards = it.entry.cards, qty = it.qty, price = it.price, currency = stall.currency })
	end
	return out
end

local function buildBooth(player, title)
	local root = R.PlayerService.Root(player)
	local model = Instance.new("Model")
	model.Name = "Stall_" .. player.UserId
	local base = CFrame.new(root.Position - Vector3.new(0, 2.6, 0)) * root.CFrame.Rotation
	local P = ModelFactory.Part
	local counter = P(model, Enum.PartType.Block, Vector3.new(7, 3, 2.5), Color3.fromRGB(190, 130, 80), base * CFrame.new(0, 1.5, -3), { material = Enum.Material.WoodPlanks, collide = true })
	counter.Anchored = true
	local colors = { Color3.fromRGB(255, 90, 80), Color3.fromRGB(255, 250, 240) }
	-- v0.25.43 (owner: it was backwards): posts stand behind the seller, the awning slopes down toward the buyers
	for i = 0, 5 do
		local stripe = P(model, Enum.PartType.Block, Vector3.new(1.3, 0.3, 5.8), colors[i % 2 + 1], base * CFrame.new(-3.25 + i * 1.3, 7.2, -1.9) * CFrame.Angles(-0.3, 0, 0), { material = Enum.Material.Fabric })
		stripe.Anchored = true
	end
	for _, sx in ipairs({ -3.4, 3.4 }) do
		local pole = P(model, Enum.PartType.Block, Vector3.new(0.4, 8.2, 0.4), Color3.fromRGB(120, 80, 50), base * CFrame.new(sx, 4.1, 0.8))
		pole.Anchored = true
	end
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Massless = false
		end
	end
	local bb = ModelFactory.Billboard(counter, "🏪 " .. title, player.DisplayName, Color3.fromRGB(255, 230, 120), 8)
	bb.MaxDistance = 90
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Browse"
	prompt.ObjectText = title
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.Parent = counter
	prompt.Triggered:Connect(function(buyer)
		-- the seller manages their own stall here (add / take back items, close it)
		Net.Push(buyer, "OpenUI", { panel = buyer == player and "StallSetup" or "Stall", sellerId = player.UserId })
	end)
	model.Parent = workspace
	return model
end

local giveBack -- (below)
function Market.CloseStall(player)
	local stall = stalls[player]
	if not stall then
		return
	end
	stalls[player] = nil
	local p = R.DataService.Get(player)
	if p then
		for _, it in ipairs(stall.items) do
			giveBack(player, p, it)
		end
		R.PlayerService.MarkDirty(player)
	end
	if stall.model then
		stall.model:Destroy()
	end
	player:SetAttribute("Vending", nil)
	local hum = R.PlayerService.Humanoid(player)
	local d = R.PlayerService.Derived(player)
	if hum and d then
		hum.WalkSpeed = d.moveSpeed
		hum.JumpPower = 50
	end
	if player.Parent then
		Net.Push(player, "StallState", { open = false })
	end
end

local function isDev(player)
	return game:GetService("RunService"):IsStudio() or player.UserId == game.CreatorId
end

local function maxItemsOf(p)
	local cls = Classes[p.class]
	local n = (cls and cls.passive and cls.passive.stallSlots) and mcfg.ShipwrightStallItems or mcfg.MaxStallItems
	if p.perks and p.perks.stallSlots then
		n += 2 -- Bigger Stall (Pearl Shop)
	end
	return n
end

-- one listing request { uid, price, qty } -> { uid, qty, price } or nil, why
local function checkItem(player, p, it, currency, used)
	local entry = type(it) == "table" and Formulas.FindItem(p, it.uid)
	local price = type(it) == "table" and math.floor(tonumber(it.price) or 0)
	if not entry or used[entry.uid] or R.InventoryService.IsEquipped(p, entry.uid) then
		return nil, "Invalid item"
	end
	if price < 1 or price > mcfg.MaxPrice then
		return nil, "Invalid price"
	end
	if currency == "pearls" then
		local def = ItemDB.Get(entry.id)
		-- v0.25.42 (owner): the developer can list fresh items to test Gem stalls (no 24 h trade lock)
		if R.PearlService.TradeLocked(entry) and not isDev(player) then
			return nil, (def and def.name or "That item") .. " was obtained less than " .. PearlsCfg.Trade.LockHours .. "h ago"
		end
		local okPrice, lo, hi = R.PearlService.PriceOk(entry.id, price)
		if not okPrice then
			return nil, (def and def.name or "Item") .. ": Gem price must be " .. lo .. "-" .. hi
		end
	end
	used[entry.uid] = true
	return { uid = entry.uid, qty = math.clamp(math.floor(tonumber(it.qty) or 1), 1, entry.qty or 1), price = price }
end

-- Gem stalls burn a non-refundable listing fee
local function payFee(player, items, currency)
	if currency ~= "pearls" then
		return true
	end
	local value = 0
	for _, it in ipairs(items) do
		value += it.price * it.qty
	end
	local fee = math.max(1, math.floor(value * PearlsCfg.Trade.ListingFeeRate))
	if not R.PearlService.Spend(player, fee, "listing fee", false) then
		return false, "Listing fee: " .. fee .. " Gems"
	end
	return true
end

-- move a checked item out of the bag into the stall's escrow
local function escrow(player, p, it)
	local entry = Formulas.FindItem(p, it.uid)
	local def = ItemDB.Get(entry.id)
	if def.stack then
		R.InventoryService.RemoveUid(player, entry.uid, it.qty)
		return { entry = { id = entry.id }, qty = it.qty, price = it.price }
	end
	for idx, e in ipairs(p.inventory) do
		if e == entry then
			table.remove(p.inventory, idx)
			break
		end
	end
	return { entry = entry, qty = 1, price = it.price }
end

-- give an escrowed stall item back to its seller
giveBack = function(player, p, it)
	if it.qty <= 0 then
		return
	end
	local def = ItemDB.Get(it.entry.id)
	if def and def.stack then
		R.InventoryService.AddItem(player, it.entry.id, it.qty)
	else
		table.insert(p.inventory, it.entry)
	end
	it.qty = 0
end

local function liveCount(stall)
	local n = 0
	for _, it in ipairs(stall.items) do
		if it.qty > 0 then
			n += 1
		end
	end
	return n
end

local function pushState(player, stall)
	Net.Push(player, "StallState", { open = true, title = stall.title, items = listing(stall), currency = stall.currency })
end

function Market.Start()
	Net.Handle("StallOpen", function(player, data)
		if stalls[player] then
			return false, "Stall already open"
		end
		if not inTown(player) then
			return false, "Stalls can only be opened in town"
		end
		if R.ShipService.IsOnShip(player) then
			return false, "Get off your ship first"
		end
		local p = R.DataService.Get(player)
		local maxItems = maxItemsOf(p)
		local currency = data.currency == "pearls" and "pearls" or "beli"
		-- v0.25.42 (owner): the developer can open a Gem stall right away to test it (Studio or the place's creator,
		-- the same rule as the Dev tab): no Lv / account-age gate, no 24 h trade lock on fresh items
		if currency == "pearls" and not isDev(player) then
			local ok, why = R.PearlService.CanTrade(player)
			if not ok then
				return false, why
			end
		end
		local title = type(data.title) == "string" and data.title:sub(1, 30) or "My Shop"
		local okF, filtered = pcall(function()
			return game:GetService("TextService"):FilterStringAsync(title, player.UserId):GetNonChatStringForBroadcastAsync()
		end)
		title = okF and filtered or "Shop"
		if type(data.items) ~= "table" or #data.items == 0 then
			return false, "Pick items to sell"
		end
		local items = {}
		local used = {}
		for i = 1, math.min(#data.items, maxItems) do
			local it, why = checkItem(player, p, data.items[i], currency, used)
			if not it then
				return false, why
			end
			table.insert(items, it)
		end
		local okFee, whyFee = payFee(player, items, currency)
		if not okFee then
			return false, whyFee
		end
		-- Move items into escrow
		local stallItems = {}
		for _, it in ipairs(items) do
			table.insert(stallItems, escrow(player, p, it))
		end
		local stall = { title = title, items = stallItems, currency = currency }
		stalls[player] = stall
		stall.model = buildBooth(player, title)
		player:SetAttribute("Vending", title)
		local hum = R.PlayerService.Humanoid(player)
		if hum then
			hum.WalkSpeed = 0
			hum.JumpPower = 0
		end
		R.PlayerService.MarkDirty(player)
		pushState(player, stall)
		return true, "Stall opened"
	end, 2)

	-- v0.25.43 (owner): edit an open stall: list one more item, or take one back (sold-out slots stay as qty 0 so a
	-- buyer's open window keeps pointing at the right index)
	Net.Handle("StallAdd", function(player, data)
		local stall = stalls[player]
		if not stall then
			return false, "Your stall is closed"
		end
		local p = R.DataService.Get(player)
		if liveCount(stall) >= maxItemsOf(p) then
			return false, "Your stall is full (" .. maxItemsOf(p) .. " items)"
		end
		local used = {}
		local it, why = checkItem(player, p, data, stall.currency, used)
		if not it then
			return false, why
		end
		local okFee, whyFee = payFee(player, { it }, stall.currency)
		if not okFee then
			return false, whyFee
		end
		table.insert(stall.items, escrow(player, p, it))
		R.PlayerService.MarkDirty(player)
		pushState(player, stall)
		return true, "Added to your stall"
	end, 0.4)

	Net.Handle("StallRemove", function(player, data)
		local stall = stalls[player]
		local it = stall and stall.items[tonumber(data.index) or 0]
		if not it or it.qty <= 0 then
			return false, "Not in your stall"
		end
		local p = R.DataService.Get(player)
		if not ItemDB.Get(it.entry.id).stack and #p.inventory >= GameConfig.InventorySlots then
			return false, "Inventory full"
		end
		giveBack(player, p, it)
		R.PlayerService.MarkDirty(player)
		if liveCount(stall) == 0 then
			Market.CloseStall(player)
			return true, "Stall closed"
		end
		pushState(player, stall)
		return true, "Taken back"
	end, 0.4)

	Net.Handle("StallClose", function(player)
		Market.CloseStall(player)
		return true
	end, 1)

	Net.Handle("StallView", function(_, data)
		local seller = Players:GetPlayerByUserId(tonumber(data.sellerId) or 0)
		local stall = seller and stalls[seller]
		if not stall then
			return false, "This stall is closed"
		end
		return { ok = true, data = { title = stall.title, seller = seller.DisplayName, items = listing(stall), currency = stall.currency } }
	end, 0.3)

	Net.Handle("StallBuy", function(buyer, data)
		local seller = Players:GetPlayerByUserId(tonumber(data.sellerId) or 0)
		local stall = seller and stalls[seller]
		if not stall or seller == buyer then
			return false, "This stall is closed"
		end
		local it = stall.items[tonumber(data.index) or 0]
		if not it or it.qty <= 0 then
			return false, "Sold out"
		end
		local qty = math.clamp(math.floor(tonumber(data.qty) or 1), 1, it.qty)
		local total = it.price * qty
		local bp = R.DataService.Get(buyer)
		local pearls = stall.currency == "pearls"
		if #bp.inventory >= GameConfig.InventorySlots then
			return false, "Inventory full"
		end
		if pearls then
			local ok, why = R.PearlService.CanTrade(buyer)
			if not ok then
				return false, why
			end
			if not R.PearlService.Spend(buyer, total, "market buy", false) then
				return false, "Not enough tradable Gems"
			end
		else
			if bp.beli < total then
				return false, "Not enough Doubloons"
			end
			R.PlayerService.AddBeli(buyer, -total)
		end
		local def = ItemDB.Get(it.entry.id)
		if def.stack then
			R.InventoryService.AddItem(buyer, it.entry.id, qty)
		else
			it.entry.got = os.time() -- bought items are trade-locked too (stops instant flipping)
			table.insert(bp.inventory, it.entry)
			R.PlayerService.MarkDirty(buyer)
		end
		it.qty -= qty
		if pearls then
			local income = math.floor(total * (1 - PearlsCfg.Trade.TaxRate))
			R.PearlService.Credit(seller, income, "market")
			R.PlayerService.Notify(seller, "Sold " .. def.name .. " x" .. qty .. " for " .. PearlsCfg.Icon .. income, "good")
		else
			local income = math.floor(total * (1 - mcfg.TaxRate))
			R.PlayerService.AddBeli(seller, income)
			R.PlayerService.Notify(seller, "Sold " .. def.name .. " x" .. qty .. " for 🪙" .. income, "good")
		end
		pushState(seller, stall)
		local remaining = 0
		for _, x in ipairs(stall.items) do
			remaining += x.qty
		end
		if remaining <= 0 then
			R.PlayerService.Notify(seller, "Your stall sold out!", "good")
			Market.CloseStall(seller)
		end
		return true, "Purchased"
	end, 0.3)
end

return Market
