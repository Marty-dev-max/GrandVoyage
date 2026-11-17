-- Ammo for slingshot classes (Sharpshooter): pick one from the bullet button next to the hotbar.
-- Every basic attack uses 1 of the picked kind (Pebble Shot is free and never runs out; when a kind runs out the
-- shot falls back to Pebble). Effects are applied on the server (CombatService).
--   mult = damage multiplier, critBonus = +crit %, ignoreDef = skip the target's DEF, slow = target speed x for 2 s,
--   splash = radius (studs) where others take half damage
local A = {
	List = {
		{ id = "Pebble", name = "Pebble Shot", color = Color3.fromRGB(190, 180, 165), mult = 1, desc = "Plain pebbles. Free, never runs out." },
		{ id = "Ember", name = "Ember Shot", color = Color3.fromRGB(255, 120, 40), mult = 1.15, element = "fire", dot = { "burn", 0.12, 3 }, rarity = "Uncommon", price = 8, desc = "+15% damage, sets the target burning." },
		{ id = "Frost", name = "Frost Shot", color = Color3.fromRGB(110, 210, 255), mult = 1.1, slow = 0.6, element = "ice", rarity = "Uncommon", price = 8, desc = "+10% damage, slows the target." },
		{ id = "Spark", name = "Spark Shot", color = Color3.fromRGB(255, 225, 60), mult = 1.1, critBonus = 12, element = "shock", rarity = "Uncommon", price = 10, desc = "+10% damage, +12% crit chance." },
		{ id = "Needle", name = "Needle Shot", color = Color3.fromRGB(205, 215, 230), mult = 1.15, ignoreDef = true, element = "pierce", rarity = "Rare", price = 18, desc = "+15% damage and ignores DEF." },
		{ id = "Blast", name = "Blast Shot", color = Color3.fromRGB(255, 70, 70), mult = 1.3, splash = 9, element = "fire", rarity = "Rare", price = 25, desc = "+30% damage, explodes: half damage around it." },
		{ id = "Star", name = "Star Shot", color = Color3.fromRGB(190, 110, 255), mult = 1.6, critBonus = 8, element = "star", rarity = "Epic", price = 120, desc = "+60% damage, +8% crit chance." },
	},
	ById = {},
	Weapons = { Slingshot = true }, -- weapon types that shoot ammo
	Default = "Pebble",
}
for _, a in ipairs(A.List) do
	A.ById[a.id] = a
	a.item = a.price and ("Ammo_" .. a.id) or nil
end
return A
