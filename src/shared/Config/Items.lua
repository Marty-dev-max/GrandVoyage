-- Items: weapons, armor, consumables and materials.
-- Weapon grades: Plain -> Keen -> Masterwork -> Grandmaster -> Supreme (Supreme = Grand Current only)
-- Every item has a rarity (see Modules/Rarity) used for colors, glows and drop announcements.
local Grades = {
	{ id = "Plain", name = "Plain", mult = 1.0, slots = 0, rarity = "Common" },
	{ id = "Keen", name = "Keen", mult = 1.25, slots = 1, rarity = "Rare" },
	{ id = "Master", name = "Masterwork", mult = 1.55, slots = 2, rarity = "Epic" },
	{ id = "Grand", name = "Grandmaster", mult = 1.9, slots = 3, rarity = "Legendary" },
	{ id = "Supreme", name = "Supreme", mult = 2.4, slots = 4, rarity = "Mythic" },
}
local GradeById = {}
for i, g in ipairs(Grades) do
	g.rank = i
	GradeById[g.id] = g
end

local Items = {}
local function add(id, def)
	def.id = id
	Items[id] = def
end

-- ===== Weapons (5 grades per weapon type) =====
local WeaponLines = {
	Sword = { magic = false, label = "Sword", names = { "Driftwood Katana", "Seagull Katana", "Tidecutter", "Moonwave Blade", "Stormfang" } },
	Slingshot = { magic = false, label = "Slingshot", names = { "Twig Slingshot", "Brass Slingshot", "Falcon Sling", "Stardrop Sling", "Skybreaker" } },
	Shoes = { magic = false, label = "Battle Boots", names = { "Deck Boots", "Chef Loafers", "Iron-Toe Boots", "Flamewalk Boots", "Skystep Boots" } },
	StormBaton = { magic = true, label = "Storm Baton", names = { "Bamboo Staff", "Weather Rod", "Storm Baton", "Tempest Rod", "Skyweaver Baton" } },
	MedKit = { magic = true, label = "Med Kit", names = { "First Aid Kit", "Field Satchel", "Surgeon Case", "Miracle Bag", "Panacea Chest" } },
	Knuckles = { magic = false, label = "Knuckles", names = { "Brass Knuckles", "Iron Knuckles", "Sharktooth Knuckles", "Thunderclap Fists", "Titan Gauntlets" } },
	Hammer = { magic = false, label = "Hammer", names = { "Wooden Mallet", "Shipwright Hammer", "Keel Breaker", "Galley Maul", "Dockyard Titan" } },
}
local gradeLevels = { 1, 15, 30, 50, 75 }
local gradeAtk = { 14, 32, 55, 85, 125 }
local gradePrice = { 300, 4000, 25000, 120000, 600000 }
for wtype, line in pairs(WeaponLines) do
	for i, name in ipairs(line.names) do
		local grade = Grades[i]
		add(wtype .. "_" .. grade.id, {
			name = name,
			kind = "Weapon",
			slot = "weapon",
			weaponType = wtype,
			typeLabel = line.label,
			grade = grade.id,
			rarity = grade.rarity,
			atk = line.magic and math.floor(gradeAtk[i] * 0.6) or gradeAtk[i],
			matk = line.magic and gradeAtk[i] or 0,
			reqLevel = gradeLevels[i],
			slots = grade.slots,
			price = gradePrice[i],
			refinable = true,
			grandLine = i == 5,
		})
	end
end

-- ===== Armor / headgear / accessories =====
add("SailorVest", { name = "Sailor Vest", kind = "Armor", slot = "armor", def = 6, reqLevel = 1, slots = 1, price = 400, refinable = true, rarity = "Common" })
add("MarineCoat", { name = "Marine Greatcoat", kind = "Armor", slot = "armor", def = 16, reqLevel = 20, slots = 1, price = 8000, refinable = true, rarity = "Rare" })
add("CaptainCoat", { name = "Captain's Coat", kind = "Armor", slot = "armor", def = 28, reqLevel = 45, slots = 1, price = 50000, refinable = true, rarity = "Epic" })
add("SharkscaleMail", { name = "Sharkscale Mail", kind = "Armor", slot = "armor", def = 36, mdef = 8, reqLevel = 55, slots = 1, price = 90000, refinable = true, rarity = "Legendary" })

add("Bandana", { name = "Bandana", kind = "Headgear", slot = "headgear", def = 2, reqLevel = 1, slots = 0, price = 200, refinable = true, rarity = "Common" })
add("SunHat", { name = "Sun Hat", kind = "Headgear", slot = "headgear", def = 4, luk = 3, reqLevel = 10, slots = 1, price = 3000, refinable = true, rarity = "Uncommon" })
add("MarineCap", { name = "Marine Cap", kind = "Headgear", slot = "headgear", def = 6, vit = 2, reqLevel = 20, slots = 1, price = 6000, refinable = true, rarity = "Rare" })
add("ClownNose", { name = "Clown Nose", kind = "Headgear", slot = "headgear", def = 3, dex = 4, reqLevel = 25, slots = 1, price = 9000, refinable = true, rarity = "Epic" })

add("CompassCharm", { name = "Compass Charm", kind = "Accessory", slot = "accessory", agi = 2, dex = 2, reqLevel = 1, slots = 1, price = 1500, rarity = "Uncommon" })
add("TangerinePin", { name = "Tangerine Pin", kind = "Accessory", slot = "accessory", luk = 4, maxSp = 40, reqLevel = 30, slots = 1, price = 15000, rarity = "Epic" })
add("SharkToothNecklace", { name = "Shark Tooth Necklace", kind = "Accessory", slot = "accessory", str = 5, reqLevel = 50, slots = 1, price = 40000, rarity = "Legendary" })

-- ===== Consumables =====
add("MeatOnBone", { name = "Meat on the Bone", desc = "Restores 20% HP.", kind = "Consumable", heal = 0.2, price = 80, stack = true, cd = 1.5, rarity = "Common" })
add("BigFeast", { name = "Pirate Feast", desc = "Restores 50% HP.", kind = "Consumable", heal = 0.5, price = 600, stack = true, cd = 3, rarity = "Uncommon" })
add("TangerineJuice", { name = "Tangerine Juice", desc = "Restores 25% SP.", kind = "Consumable", healSp = 0.25, price = 150, stack = true, cd = 1.5, rarity = "Common" })
add("RepairKit", { name = "Ship Repair Kit", desc = "Repairs 20% of your ship's HP.", kind = "Consumable", shipRepair = 0.2, price = 1200, stack = true, cd = 8, rarity = "Uncommon" })
add("CaptainsLog", { name = "Captain's Log", desc = "+50% EXP for 30 minutes.", kind = "Consumable", expBoost = 1800, price = 2000, stack = true, cd = 1, rarity = "Rare" })
add("RefineGuard", { name = "Willpower Charm", desc = "Prevents downgrade and breaking on a failed refine.", kind = "Consumable", price = 50000, stack = true, special = "RefineGuard", rarity = "Legendary" })

-- ===== Materials =====
local mats = {
	{ "Wood", "Ship Timber", 20, "Common" },
	{ "IronIngot", "Iron Ingot", 120, "Uncommon" },
	{ "Gunpowder", "Gunpowder", 80, "Uncommon" },
	{ "SailCloth", "Sail Cloth", 60, "Common" },
	{ "SteelOre", "Steel Ore", 200, "Uncommon", "Refines +1 to +5" },
	{ "TidecoreShard", "Tidecore Shard", 2500, "Rare", "Refines +6 to +10" },
	{ "PureTidecore", "Pure Tidecore", 20000, "Epic", "Refines +11 to +15" },
	{ "LeviathanScale", "Leviathan Scale", 5000, "Epic" },
	{ "TreasureWood", "Treasure-Tree Wood", 15000, "Legendary" },
	{ "CrabShell", "Crab Shell", 10, "Common" },
	{ "MonkeyFur", "Monkey Fur", 12, "Common" },
	{ "BoarTusk", "Boar Tusk", 15, "Common" },
	{ "MarineBadge", "Marine Badge", 40, "Common" },
	{ "ClownPaint", "Clown Paint", 60, "Common" },
	{ "CatClaw", "Cat Claw", 90, "Uncommon" },
	{ "ArmorRivet", "Armor Rivet", 140, "Uncommon" },
	{ "SharkfolkFin", "Sharkfolk Fin", 200, "Uncommon" },
	{ "WantedPoster", "Wanted Poster", 300, "Uncommon" },
	{ "TreasureMap", "Treasure Map", 3000, "Rare" },
}
for _, m in ipairs(mats) do
	add(m[1], { name = m[2], kind = "Material", price = m[3], stack = true, rarity = m[4], desc = m[5] })
end

-- ===== Cursed Fruits (uneaten: tradable items) =====
local Fruits = require(script.Parent.Fruits)
local fruitPrice = { Rare = 50000, Epic = 150000, Legendary = 400000, Mythic = 1000000, Secret = 2500000 }
for _, f in ipairs(Fruits.List) do
	add("Fruit_" .. f.id, { name = f.name, desc = f.desc .. " Eat it from your Bag.", kind = "Fruit", fruit = f.id, rarity = f.rarity, price = fruitPrice[f.rarity] or 50000, icon = f.icon })
end

-- ===== Pets: eggs and bait =====
add("SeaEgg", { name = "Sea Egg", desc = "Hatch it from your Bag. Hermit 40% / Boarlet 35% / Gull 20% / Puffer 5%.", kind = "Egg", rarity = "Uncommon", price = 2000, icon = "🥚" })
add("GoldenEgg", { name = "Golden Egg", desc = "Hatch it from your Bag. Gull 40% / Puffer 35% / Lantern 22% / Leviathan 3%.", kind = "Egg", rarity = "Epic", price = 20000, icon = "🪺" })
add("SeaBait", { name = "Sea Bait", desc = "Throw it at a weakened Beach Crab, Wild Boar or Leviathan (below 35% HP) to tame it.", kind = "Consumable", special = true, price = 300, stack = true, rarity = "Common", icon = "🪤" })

-- General store stock
local Shop = {
	"MeatOnBone", "BigFeast", "TangerineJuice", "RepairKit", "SeaBait", "SteelOre", "Wood", "SailCloth",
	"SailorVest", "Bandana", "CompassCharm",
	"Knuckles_Plain", "Sword_Plain", "Slingshot_Plain", "Shoes_Plain", "StormBaton_Plain", "MedKit_Plain", "Hammer_Plain",
}

return {
	Items = Items,
	Grades = Grades,
	GradeById = GradeById,
	Shop = Shop,
	RefineMaterial = function(currentRefine)
		if currentRefine < 5 then
			return "SteelOre", 1, 500
		elseif currentRefine < 10 then
			return "TidecoreShard", 1, 5000
		else
			return "PureTidecore", 1, 40000
		end
	end,
}
