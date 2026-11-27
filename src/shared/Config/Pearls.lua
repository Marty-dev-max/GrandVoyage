-- Pearls 🦪: the premium-ish currency. Earned only from bounded sources (never from farming or Auto Battle),
-- spendable in the Pearl Shop and tradable in player stalls under strict rules (anti-inflation, anti-bot, anti-RMT).
local P = {}

P.Icon = "💎"
P.DailyCap = 300 -- max Pearls EARNED per player per day (UTC). Market income and Robux purchases do not count.

-- Earn sources
P.Sources = {
	Chest = { Wooden = 2, Silver = 5, Golden = 12, Captain = 30 }, -- first time each chest is opened
	IslandExplored = 50, -- all chests on an island
	QuestStep = 3, -- each main-story step
	TutorialDone = 25,
	MVP = 10, -- top damage on an MVP boss
}

-- Trading (stalls priced in Pearls)
P.Trade = {
	MinLevel = 30,
	MinAccountAgeDays = 14, -- Roblox account age (stops fresh alt/bot accounts)
	LockHours = 24, -- items you just obtained cannot be sold for Pearls yet
	TaxRate = 0.05, -- burned on every sale
	ListingFeeRate = 0.01, -- burned when the stall opens (min 1 Pearl), not refunded
	BandMin = 0.25, -- price per unit must be within [BandMin, BandMax] x the item's reference price
	BandMax = 4.0,
	DoubloonsPerPearl = 250, -- reference price = item Doubloon price / this (min 1)
	HourlyIncomeFlag = 20000, -- earning more than this from sales in an hour freezes Pearl trading for review
}

-- Pearl Shop (Pearls are burned here: the main sink). Bound (Robux) Pearls are spent first.
P.Shop = {
	{ id = "RefineGuard", kind = "item", item = "RefineGuard", qty = 1, price = 60, name = "Willpower Charm", icon = "🧿", desc = "Protects a refine from downgrade and breaking." },
	{ id = "ExpScroll", kind = "item", item = "CaptainsLog", qty = 1, price = 80, name = "Captain's Log", icon = "📘", desc = "+50% EXP for 30 minutes." },
	{ id = "SwitchVoucher", kind = "perk", perk = "freeSwitch", price = 150, name = "Class Switch Voucher", icon = "st_ticket", desc = "Your next class switch is free." },
	{ id = "SeaEgg", kind = "item", item = "SeaEgg", qty = 1, price = 120, bulk = { 1, 10, 30 }, name = "Sea Egg", icon = "🥚", desc = "Hermit 40% • Boarlet 35% • Gull 20% • Puffer 5%" },
	{ id = "StallSlots", kind = "perk", perk = "stallSlots", price = 400, name = "Bigger Stall", icon = "st_stall", desc = "+2 stall slots, forever.", once = true },
}

-- Robux developer products (create them in the Creator Hub, then paste the ids). 0 = not on sale yet.
-- Robux Pearls are BOUND: usable in the Pearl Shop, never tradable.
P.Products = {
	{ productId = 3732181648, pearls = 100, name = "Pile of Gems", icon = "st_gems_s" },
	{ productId = 3732181740, pearls = 550, name = "Chest of Gems", icon = "st_gems_m" },
	{ productId = 3732181832, pearls = 1200, name = "Trophy of Gems", icon = "st_gems_l" },
}

P.LedgerStore = "GV_PearlLedger_r1"

return P
