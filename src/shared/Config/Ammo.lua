-- Ammo for slingshot classes (Sharpshooter): pick one from the bullet button next to the hotbar.
-- Every basic attack uses 1 of the picked kind (Pebble Shot is free and never runs out; when a kind runs out the
-- shot falls back to Pebble). Effects are applied on the server (CombatService).
--   mult = damage multiplier, critBonus = +crit %, ignoreDef = skip the target's DEF, slow = target speed x for 2 s,
--   splash = radius (studs) where others take half damage
-- v0.25.81 (owner): ONE ammo now = Musket Ball (the Sharpshooter shoots musket balls). Every basic attack uses 1; out of
-- balls = no shot ("buy more at the General Store"). Not free: bought, dropped by humanoid monsters (gunners drop more),
-- and every character gets a starter pouch (CombatService.MusketStarter). The old kinds stay as Legacy items so
-- saves that hold them still load (they only sell now).
local A = {
	List = {
		{ id = "Musket", name = "Musket Ball", color = Color3.fromRGB(70, 68, 76), mult = 1, rarity = "Common", price = 4, desc = "Lead balls for your musket. One per shot." },
	},
	Legacy = {
		{ id = "Ember", name = "Ember Shot", rarity = "Uncommon", price = 8 },
		{ id = "Frost", name = "Frost Shot", rarity = "Uncommon", price = 8 },
		{ id = "Spark", name = "Spark Shot", rarity = "Uncommon", price = 10 },
		{ id = "Needle", name = "Needle Shot", rarity = "Rare", price = 18 },
		{ id = "Blast", name = "Blast Shot", rarity = "Rare", price = 25 },
		{ id = "Star", name = "Star Shot", rarity = "Epic", price = 120 },
	},
	ById = {},
	Weapons = { Slingshot = true }, -- weapon types that shoot ammo
	Default = "Musket",
	Starter = 300, -- balls in the first pouch
}
for _, a in ipairs(A.List) do
	A.ById[a.id] = a
	a.item = "Ammo_" .. a.id
end
for _, a in ipairs(A.Legacy) do
	a.item = "Ammo_" .. a.id
end
return A
