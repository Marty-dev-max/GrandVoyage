-- IslandTrades (R5 0.1.28-remake): a Trader NPC on each Origin home island (World/OriginIslands, role "Trader") swaps
-- that island's monster material for useful things. Same idea everywhere (supplies, Steel Ore, a Sea Egg, the island
-- mini boss's own wearable as a sure way to get it), plus one trade in the island's own flavor.
-- give = { [itemId] = qty, beli = n }; get = { item = id, qty = n } or { beli = n }
-- Server: InventoryService "IslandTrade" { island, i }; client: Panels.Trader.
local T = {}

local function common(mat, bossItem)
	return {
		{ give = { [mat] = 4 }, get = { item = "Bandage", qty = 2 } },
		{ give = { [mat] = 6 }, get = { item = "MeatOnBone", qty = 3 } },
		{ give = { [mat] = 8, beli = 100 }, get = { item = "SteelOre", qty = 1 } },
		{ give = { [mat] = 20, beli = 500 }, get = { item = "SeaEgg", qty = 1 } },
		{ give = { [mat] = 30, beli = 1500 }, get = { item = bossItem, qty = 1 } },
	}
end

local function with(list, extra)
	table.insert(list, 3, extra)
	return list
end

T.ByIsland = {
	BastionRock = {
		name = "Quartermaster Bell",
		material = "GullFeather",
		line = "Those thieves pinned our stolen feathers in their caps. Bring them back and the stores will pay you in kind.",
		trades = with(common("GullFeather", "GullFeatherCap"), { give = { GullFeather = 6, beli = 50 }, get = { item = "Ammo_Musket", qty = 20 } }),
	},
	SmugglersHollow = {
		name = "Fence Marlo",
		material = "CutPurse",
		line = "Purses, eh? No questions asked. I pay better than the shop, and I've got goods under the counter.",
		trades = with(common("CutPurse", "TinCrown"), { give = { CutPurse = 4 }, get = { beli = 260 } }),
	},
	ShackleReef = {
		name = "Tinker Rook",
		material = "RustyShackle",
		line = "Iron's iron, rust or no. Bring me shackles off that hulk and I'll beat them into something useful.",
		trades = with(common("RustyShackle", "WardenKeyRing"), { give = { RustyShackle = 6, beli = 80 }, get = { item = "IronIngot", qty = 1 } }),
	},
	InkwellIsle = {
		name = "Curator Wren",
		material = "RelicShard",
		line = "Every shard is a sentence of the old world. Bring them to the library and I'll share what we've learned.",
		trades = with(common("RelicShard", "DustGoggles"), { give = { RelicShard = 12, beli = 300 }, get = { item = "CaptainsLog", qty = 1 } }),
	},
}

return T
