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
	-- Sea Cook and Brawler fight with their bare legs / fists (owner, v0.22.3): these lines are fighting styles, nothing is worn
	Shoes = { magic = false, label = "Leg Style", names = { "Deckhand Leg", "Galley Leg", "Iron Leg", "Ember Leg", "Cloudstride Leg" } },
	StormBaton = { magic = true, label = "Baton", names = { "Bamboo Staff", "Deckhand Baton", "Folding Baton", "Tide Baton", "Mariner's Rod" } }, -- melee since v0.25.51, MATK (INT class) since v0.25.52
	MedKit = { magic = true, label = "Powder Pouch", names = { "Herb Pouch", "Field Powders", "Surgeon's Dust", "Miracle Powder", "Panacea Pouch" } },
	Knuckles = { magic = false, label = "Fist Style", names = { "Street Fists", "Iron Fists", "Sharktooth Fists", "Thunderclap Fists", "Titan Fists" } },
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

-- ===== Famed blades (v0.25.104, docs/Plan-Weapons-v2.md) =====
-- Every sword is a block model built from `blade` (Shared/Modules/BladeModel): shape + guard style + colors.
-- Ladder (owner): gray = the wooden starter (Sword_Plain) | green "Forty Fathoms" (many, General Store + mob drops) |
-- blue "Twenty Tides" (boss drops) | purple = a Tide blade awakened (this update: Whitevow only) | gold "Seven Crowns"
-- (next update) | "Eclipsed" black blades (sea 3). Variants differ by stats only for now: Katana leans WPN/END,
-- Cutlass leans WPN/VIT.
local SWORD_LINE_BLADES = {
	Plain = { form = "Wooden", blade = "B08456", guard = "7A5232", wrap = "D8C9A0", pommel = "7A5232" },
	Keen = { form = "Katana", hilt = "round", blade = "C9D3E0", edge = "F4F8FF", guard = "3B3F4A", wrap = "F2F2F2", wrap2 = "9AA6B8", pommel = "D9A441", scabbard = "E8E8EE" },
	Master = { form = "Cutlass", hilt = "shell", blade = "B9C9DA", edge = "E6F3FF", guard = "D9A441", wrap = "2C4F8C", pommel = "D9A441", scabbard = "1E2E4A" },
	Grand = { form = "Katana", shape = "long", hilt = "flower", blade = "D5DCF5", edge = "FFFFFF", guard = "6A5AA8", wrap = "3A2D63", pommel = "C9C9E8", scabbard = "2A2045", glow = true },
	Supreme = { form = "Cutlass", shape = "hooked", hilt = "basket", blade = "AFC4E8", edge = "BFF4FF", guard = "2E3550", wrap = "6A3FB0", pommel = "FFD34D", scabbard = "1A1C2A", glow = true },
}
for gid, spec in pairs(SWORD_LINE_BLADES) do
	Items["Sword_" .. gid].blade = spec
end
local BLADE_TIERS = {
	Fathom = { rarity = "Uncommon", grade = "Keen", ledger = "Forty Fathoms", atk = 30, req = 10, slots = 1, price = 3500, lean = 2 },
	Tide = { rarity = "Rare", grade = "Master", ledger = "Twenty Tides", atk = 52, req = 20, slots = 2, price = 30000, lean = 3 },
	Awakened = { rarity = "Epic", grade = "Grand", ledger = "Twenty Tides, Awakened", atk = 80, req = 35, slots = 3, price = 150000, lean = 4 },
}
local Blades = {} -- id list per tier, in order (Index / store rolls / drops read these)
local function blade(id, name, tierId, spec)
	local t = BLADE_TIERS[tierId]
	local katana = spec.form == "Katana"
	add(id, {
		name = name,
		kind = "Weapon",
		slot = "weapon",
		weaponType = "Sword",
		typeLabel = spec.form,
		grade = t.grade,
		ledger = t.ledger,
		bladeTier = tierId,
		rarity = t.rarity,
		atk = t.atk,
		matk = 0,
		reqLevel = t.req,
		slots = t.slots,
		price = t.price,
		refinable = true,
		blade = spec,
		-- remake attributes: every blade leans Weaponry; a katana adds Endurance, a cutlass Vitality
		WPN = t.lean,
		END = katana and math.ceil(t.lean / 2) or nil,
		VIT = not katana and math.ceil(t.lean / 2) or nil,
	})
	Blades[tierId] = Blades[tierId] or {}
	table.insert(Blades[tierId], id)
end
-- Forty Fathoms (green)
blade("Blade_Seafoam", "Seafoam Katana", "Fathom", { form = "Katana", hilt = "round", blade = "C8D6DC", edge = "F0FAFF", guard = "2F6F6A", wrap = "7FD1B9", wrap2 = "3E8C7A", pommel = "C9A441", scabbard = "2B4A47" })
blade("Blade_CrimsonThread", "Crimson Thread", "Fathom", { form = "Katana", hilt = "square", blade = "C9CFD8", guard = "3A2A2A", wrap = "C8323C", wrap2 = "7A1C22", pommel = "D9A441", scabbard = "2A1416" })
blade("Blade_Ashwind", "Ashwind Katana", "Fathom", { form = "Katana", shape = "straight", hilt = "bar", blade = "B4BAC4", guard = "2A2C30", wrap = "5A5E66", wrap2 = "2E3136", pommel = "8A8F99", scabbard = "1C1D20" })
blade("Blade_Sunbrand", "Sunbrand Katana", "Fathom", { form = "Katana", shape = "broad", hilt = "flower", blade = "D2CFC4", guard = "B8862B", wrap = "F08A24", wrap2 = "A3521A", pommel = "FFD34D", scabbard = "5A3416" })
blade("Blade_IndigoRain", "Indigo Rain", "Fathom", { form = "Katana", shape = "slim", hilt = "oval", blade = "C0CBE0", guard = "1F2A4A", wrap = "3A4FA8", wrap2 = "1F2B66", pommel = "B8C4E8", scabbard = "141B33" })
blade("Blade_Harbor", "Harbor Cutlass", "Fathom", { form = "Cutlass", hilt = "bow", blade = "BCC6D0", guard = "C8963E", wrap = "6B4226", pommel = "C8963E", scabbard = "3A2A1E" })
blade("Blade_Coral", "Coral Cutlass", "Fathom", { form = "Cutlass", shape = "falchion", hilt = "cross", blade = "D0C8CC", guard = "E07A7A", wrap = "8C2F3E", pommel = "F2A0A0", scabbard = "4A1E26" })
blade("Blade_Jade", "Jade Cutlass", "Fathom", { form = "Cutlass", hilt = "shell", blade = "BFD8C8", edge = "E8FFF0", guard = "2E7D4F", wrap = "1F4A33", pommel = "7FD19A", scabbard = "16301F" })
blade("Blade_Gullfeather", "Gullfeather Cutlass", "Fathom", { form = "Cutlass", shape = "straight", hilt = "ring", blade = "D8DEE6", guard = "E8E8EE", wrap = "F4F4F4", wrap2 = "B8C0CC", pommel = "9AA6B8", scabbard = "D8D8E0" })
blade("Blade_Stormsteel", "Stormsteel Cutlass", "Fathom", { form = "Cutlass", shape = "broad", hilt = "basket", blade = "9FB4D0", edge = "D8E8FF", guard = "3E4A63", wrap = "2A3448", pommel = "8FA8D8", scabbard = "1A2030" })
-- Twenty Tides (blue): boss drops
blade("Blade_Gullwing", "Gullwing", "Tide", { form = "Katana", shape = "long", hilt = "oval", blade = "E2E8F2", edge = "FFFFFF", guard = "D8DDE6", wrap = "6FB7FF", wrap2 = "F4F8FF", pommel = "FFFFFF", scabbard = "F0F2F6", glow = true })
blade("Blade_Saltfang", "Saltfang", "Tide", { form = "Cutlass", shape = "hooked", hilt = "basket", blade = "9CC8E8", edge = "CFF6FF", guard = "1E5C8A", wrap = "0E2F4D", pommel = "6FD3FF", scabbard = "0B2236", glow = true })
blade("Blade_Coralvein", "Coralvein", "Tide", { form = "Katana", shape = "deep", hilt = "flower", blade = "E6C8C8", edge = "FFE0E0", guard = "8C1E2E", wrap = "D8404E", wrap2 = "5A0E18", pommel = "FF9AA8", scabbard = "3A0A12", glow = true })
blade("Blade_Moonhook", "Moonhook", "Tide", { form = "Cutlass", shape = "hooked", hilt = "ring", blade = "D8DCE8", edge = "F4F6FF", guard = "8A8FA8", wrap = "2E2A4A", pommel = "E8E8FF", scabbard = "22203A", glow = true })
blade("Blade_Kelpwhisper", "Kelpwhisper", "Tide", { form = "Katana", shape = "slim", hilt = "round", blade = "C4DCC8", edge = "E8FFEC", guard = "2A5A3A", wrap = "3F8F55", wrap2 = "1C3F26", pommel = "B8E8A0", scabbard = "13301C", glow = true })
blade("Blade_Emberwake", "Emberwake", "Tide", { form = "Cutlass", shape = "falchion", hilt = "shell", blade = "D8C4B4", edge = "FFD8A0", guard = "8A3A14", wrap = "2A1610", pommel = "FF9A3C", scabbard = "2A120A", glow = true })
-- Awakened Tide (purple): Whitevow, a vow sworn on a white hilt (Battle Pass tier 50 later; Dev grant until then)
blade("Blade_Whitevow", "Whitevow", "Awakened", { form = "Katana", shape = "long", hilt = "square", blade = "E8EAF4", edge = "FFFFFF", guard = "C9B8F0", wrap = "FFFFFF", wrap2 = "D8D4EC", pommel = "9A7FD8", scabbard = "F6F6FA", glow = true })

-- v0.25.105: green (Uncommon) weapons for every other class, so each one can start the Ascend ladder (stats differ only;
-- they use their type's model + the Keen icon). { id, name, type, main stat, second stat }
local GREENS = {
	{ "Knuckles_Barnacle", "Barnacle Fists", "Knuckles", "MAR", "END" },
	{ "Knuckles_Rope", "Rope-Wrap Fists", "Knuckles", "END", "MAR" },
	{ "Shoes_Gale", "Gale Leg", "Shoes", "END", "MAR" },
	{ "Shoes_Anchor", "Anchor Leg", "Shoes", "MAR", "VIT" },
	{ "Slingshot_Reed", "Reedline Musket", "Slingshot", "WPN", "END" },
	{ "Slingshot_Gull", "Gullsight Musket", "Slingshot", "WPN", "WIL" },
	{ "StormBaton_Kelp", "Kelpwood Baton", "StormBaton", "WPN", "WIL" },
	{ "StormBaton_Compass", "Compass Baton", "StormBaton", "WPN", "END" },
	{ "MedKit_Mint", "Seamint Pouch", "MedKit", "WPN", "VIT" },
	{ "MedKit_Salt", "Saltpetre Pouch", "MedKit", "WPN", "WIL" },
	{ "Hammer_Rivet", "Rivet Hammer", "Hammer", "WPN", "VIT" },
	{ "Hammer_Keel", "Keelpin Maul", "Hammer", "VIT", "WPN" },
}
local GreenIds = {}
for _, g in ipairs(GREENS) do
	local t, line = BLADE_TIERS.Fathom, WeaponLines[g[3]]
	add(g[1], {
		name = g[2],
		kind = "Weapon",
		slot = "weapon",
		weaponType = g[3],
		typeLabel = line.label,
		grade = t.grade,
		rarity = t.rarity,
		atk = line.magic and math.floor(t.atk * 0.6) or t.atk,
		matk = line.magic and t.atk or 0,
		reqLevel = t.req,
		slots = t.slots,
		price = t.price,
		refinable = true,
		[g[4]] = t.lean,
		[g[5]] = math.ceil(t.lean / 2),
	})
	table.insert(GreenIds, g[1])
end

-- ===== Armor / headgear / accessories =====
add("SailorVest", { name = "Sailor Vest", kind = "Armor", slot = "armor", def = 6, reqLevel = 1, slots = 1, price = 400, refinable = true, rarity = "Common" })
add("MarineCoat", { name = "Marine Greatcoat", kind = "Armor", slot = "armor", def = 16, reqLevel = 20, slots = 1, price = 8000, refinable = true, rarity = "Rare" })
add("CaptainCoat", { name = "Captain's Coat", kind = "Armor", slot = "armor", def = 28, reqLevel = 45, slots = 1, price = 50000, refinable = true, rarity = "Epic" })
add("SharkscaleMail", { name = "Sharkscale Mail", kind = "Armor", slot = "armor", def = 36, mdef = 8, reqLevel = 55, slots = 1, price = 90000, refinable = true, rarity = "Legendary" })

add("Bandana", { name = "Bandana", kind = "Headgear", slot = "headgear", def = 2, reqLevel = 1, slots = 0, price = 200, refinable = true, rarity = "Common" })
add("SunHat", { name = "Sun Hat", kind = "Headgear", slot = "headgear", def = 4, WIL = 3, reqLevel = 10, slots = 1, price = 3000, refinable = true, rarity = "Uncommon" })
add("MarineCap", { name = "Marine Cap", kind = "Headgear", slot = "headgear", def = 6, VIT = 2, reqLevel = 20, slots = 1, price = 6000, refinable = true, rarity = "Rare" })
add("ClownNose", { name = "Clown Nose", kind = "Headgear", slot = "headgear", def = 3, WPN = 4, reqLevel = 25, slots = 1, price = 9000, refinable = true, rarity = "Epic" })

add("CompassCharm", { name = "Compass Charm", kind = "Accessory", slot = "accessory", END = 2, WPN = 2, reqLevel = 1, slots = 1, price = 1500, rarity = "Uncommon" })
add("TangerinePin", { name = "Tangerine Pin", kind = "Accessory", slot = "accessory", WIL = 4, maxSp = 40, reqLevel = 30, slots = 1, price = 15000, rarity = "Epic" })
add("SharkToothNecklace", { name = "Shark Tooth Necklace", kind = "Accessory", slot = "accessory", WPN = 5, reqLevel = 50, slots = 1, price = 40000, rarity = "Legendary" })
-- Seastone gear (v0.24.14, owner's design): MARINES only. In PvP their hits may seal a Cursed Fruit user's powers
-- (FruitService.TrySeastone: best equipped `seastone = { chance, seconds }`). Fruit users cannot wear Seastone.
add("SeastoneBracer", { name = "Seastone Bracer", desc = "Marines only. PvP hits have a 20% chance to seal a fruit user's powers for 3 s. Fruit users cannot wear Seastone.", kind = "Accessory", slot = "accessory", VIT = 2, reqLevel = 20, slots = 1, price = 12000, rarity = "Rare", faction = "Marine", seastone = { 0.2, 3 }, icon = "⛓️" })
add("SeastoneShackle", { name = "Seastone Shackle Charm", desc = "Marines only. PvP hits have a 35% chance to seal a fruit user's powers for 4 s. Fruit users cannot wear Seastone.", kind = "Accessory", slot = "accessory", VIT = 4, WPN = 3, reqLevel = 45, slots = 1, price = 60000, rarity = "Epic", faction = "Marine", seastone = { 0.35, 4 }, icon = "⛓️" })

-- v0.25.32 (owner): the humanoid monsters' signature pieces (models in Config/Accessories, the same blocks the monster
-- wears): dropped by that monster, some sold in the General Store; worn on the character like every gear piece
add("ClownWig", { name = "Clown Wig", kind = "Headgear", slot = "headgear", def = 3, WPN = 3, reqLevel = 20, slots = 1, price = 7000, refinable = true, rarity = "Rare" })
add("ConfettiWig", { name = "Confetti Wig", kind = "Headgear", slot = "headgear", def = 6, WPN = 5, WIL = 3, reqLevel = 30, slots = 1, price = 24000, refinable = true, rarity = "Epic" })
add("CatEars", { name = "Night Cat Ears", kind = "Headgear", slot = "headgear", def = 3, END = 5, reqLevel = 30, slots = 1, price = 14000, refinable = true, rarity = "Rare" })
add("HypnoGoggles", { name = "Hypno Goggles", kind = "Headgear", slot = "headgear", def = 3, WIL = 5, reqLevel = 32, slots = 1, price = 15000, refinable = true, rarity = "Rare" })
add("IronHelmet", { name = "Armada Helmet", kind = "Headgear", slot = "headgear", def = 10, VIT = 3, reqLevel = 40, slots = 1, price = 22000, refinable = true, rarity = "Rare" })
add("GlowVisor", { name = "Silent Visor", kind = "Headgear", slot = "headgear", def = 5, WPN = 6, END = 4, reqLevel = 40, slots = 1, price = 45000, refinable = true, rarity = "Epic" })
add("RingmasterHat", { name = "Ringmaster's Top Hat", kind = "Headgear", slot = "headgear", def = 6, WIL = 6, reqLevel = 28, slots = 1, price = 30000, refinable = true, rarity = "Epic" })
add("AdmiralCrown", { name = "Armada Crown", kind = "Headgear", slot = "headgear", def = 12, WPN = 5, VIT = 4, reqLevel = 50, slots = 1, price = 120000, refinable = true, rarity = "Legendary" })
add("CapeNavy", { name = "Navy Captain's Cape", kind = "Accessory", slot = "accessory", VIT = 4, reqLevel = 20, slots = 1, price = 20000, rarity = "Epic" })
add("CapeGold", { name = "Ringmaster's Cape", kind = "Accessory", slot = "accessory", WIL = 4, WPN = 2, reqLevel = 28, slots = 1, price = 28000, rarity = "Epic" })
add("CapePurple", { name = "Confetti Cape", kind = "Accessory", slot = "accessory", WIL = 5, reqLevel = 30, slots = 1, price = 30000, rarity = "Epic" })
add("CapeShadow", { name = "Shadow Cape", kind = "Accessory", slot = "accessory", END = 6, reqLevel = 40, slots = 1, price = 50000, rarity = "Epic" })
add("CapeCrimson", { name = "Admiral's Crimson Cape", kind = "Accessory", slot = "accessory", WPN = 6, VIT = 3, reqLevel = 50, slots = 1, price = 110000, rarity = "Legendary" })
add("CapeSlate", { name = "Mist Cape", kind = "Accessory", slot = "accessory", WIL = 5, VIT = 5, reqLevel = 58, slots = 1, price = 150000, rarity = "Legendary" })
add("ChiefFurMantle", { name = "Chief's Fur Mantle", desc = "Worn by Bandit Chief Ragmaw.", kind = "Accessory", slot = "accessory", WPN = 3, VIT = 2, reqLevel = 10, slots = 1, price = 4000, rarity = "Rare" })
add("PamperedShades", { name = "Pampered Shades", desc = "Ensign Velour never takes them off.", kind = "Headgear", slot = "headgear", def = 2, WPN = 3, WIL = 3, reqLevel = 15, slots = 1, price = 8000, refinable = true, rarity = "Rare" })
add("TamerWhip", { name = "Tamer's Coiled Whip", desc = "Beast Tamer Bristle's whip, coiled at the hip.", kind = "Accessory", slot = "accessory", END = 4, WPN = 2, reqLevel = 25, slots = 1, price = 20000, rarity = "Rare" })
add("BeardDark", { name = "Bandit Beard", kind = "Accessory", slot = "accessory", WPN = 2, reqLevel = 8, slots = 0, price = 1200, rarity = "Uncommon" })
add("BeardBrown", { name = "Sea Dog Beard", kind = "Accessory", slot = "accessory", VIT = 3, reqLevel = 20, slots = 1, price = 6000, rarity = "Uncommon" })
add("BeardGrey", { name = "Commodore's Beard", kind = "Accessory", slot = "accessory", VIT = 4, WIL = 3, reqLevel = 65, slots = 1, price = 90000, rarity = "Epic" })

-- ===== Consumables =====
add("MeatOnBone", { name = "Meat on the Bone", desc = "Restores 20% HP.", kind = "Consumable", heal = 0.2, price = 80, stack = true, cd = 1.5, rarity = "Common" })
add("BigFeast", { name = "Pirate Feast", desc = "Restores 50% HP.", kind = "Consumable", heal = 0.5, price = 600, stack = true, cd = 3, rarity = "Uncommon" })
add("TangerineJuice", { name = "Tangerine Juice", desc = "Restores 25% SP.", kind = "Consumable", healSp = 0.25, price = 150, stack = true, cd = 1.5, rarity = "Common" })
-- v0.25.55 (owner): S / M / L sizes for the F1 HP and F2 SP slots (meat on the HP side, barrel tankards on the SP side)
add("RoastShank", { name = "Roast Shank", desc = "Restores 35% HP.", kind = "Consumable", heal = 0.35, price = 260, stack = true, cd = 2, rarity = "Common" })
add("SeaGrog", { name = "Sea Grog", desc = "Restores 45% SP.", kind = "Consumable", healSp = 0.45, price = 420, stack = true, cd = 2, rarity = "Uncommon" })
add("CaptainsKeg", { name = "Captain's Keg", desc = "Restores 70% SP.", kind = "Consumable", healSp = 0.7, price = 1100, stack = true, cd = 3, rarity = "Uncommon" })
add("RepairKit", { name = "Ship Repair Kit", desc = "Repairs 20% of your ship's HP.", kind = "Consumable", shipRepair = 0.2, price = 1200, stack = true, cd = 8, rarity = "Uncommon" })
-- remake 0.1.11 (owner): Doctor / Shipwright Mastery for everyone, whatever weapon you hold (the arts only make it faster)
add("PatchPlanks", { name = "Patch Planks", desc = "Anyone can nail them on: repairs 6% of your ship's HP. Trains Shipwright Mastery.", kind = "Consumable", shipRepair = 0.06, price = 150, stack = true, cd = 3, rarity = "Common" })
add("Bandage", { name = "Bandage", desc = "Heals the most hurt party member near you (or yourself) by 25% HP. Trains Doctor Mastery.", kind = "Consumable", allyHeal = 0.25, price = 60, stack = true, cd = 3, rarity = "Common" })
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
	{ "TigerPelt", "Tiger Pelt", 16, "Common" },
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

-- ===== Cooking (Mastery v2 M2): ingredients, new dishes, 2 / 3 star versions (Config/Recipes) =====
local Recipes = require(script.Parent.Recipes)
add("RawMeat", { name = "Raw Meat", desc = "Cook it at a campfire.", kind = "Material", ingredient = true, price = 30, stack = true, rarity = "Common" })
add("FreshFish", { name = "Fresh Fish", desc = "Cook it at a campfire.", kind = "Material", ingredient = true, price = 40, stack = true, rarity = "Common" })
add("Tangerine", { name = "Tangerine", desc = "Juice it at a campfire.", kind = "Material", ingredient = true, price = 30, stack = true, rarity = "Common" })
add("Spice", { name = "Sea Spice", desc = "Hot peppers and salt. Medium and large recipes need it.", kind = "Material", ingredient = true, price = 40, stack = true, rarity = "Common" })
add("GrilledFish", { name = "Grilled Fish", desc = "Restores 20% HP.", kind = "Consumable", heal = 0.2, price = 90, stack = true, cd = 1.5, rarity = "Common" })
add("FishStew", { name = "Fish Stew", desc = "Restores 35% HP.", kind = "Consumable", heal = 0.35, price = 280, stack = true, cd = 2, rarity = "Common" })
add("PepperSkewer", { name = "Pepper Skewer", desc = "Restores 20% HP. +8% damage for 5 minutes.", kind = "Consumable", heal = 0.2, price = 400, stack = true, cd = 2, rarity = "Uncommon",
	buff = { id = "Cuisine", stats = { atk = 0.08 }, dur = 300 } })
add("LeviathanFeast", { name = "Leviathan Feast", desc = "Restores 50% HP. Your whole party nearby: faster HP and SP regen, +10% defense for 15 minutes.", kind = "Consumable", heal = 0.5, price = 1500, stack = true, cd = 5, rarity = "Epic",
	buff = { id = "Feast", stats = { hpRegen = 0.5, spRegen = 0.5, def = 0.1 }, dur = 900, party = true } })
for _, r in ipairs(Recipes.List) do
	local base = Items[r.id]
	assert(base, "Recipes: no item " .. r.id)
	-- never worth more sold than its ingredients cost to buy
	local cost = 0
	for ing, n in pairs(r.needs) do
		cost += (Items[ing] and Items[ing].price or 0) * n
	end
	base.sellCap = math.floor(cost * 0.9)
	base.recipe = r.id
	for stars, s in pairs(Recipes.Stars) do
		local d = table.clone(base)
		d.id = nil
		d.name = s.prefix .. " " .. base.name
		d.heal = base.heal and base.heal * s.heal or nil
		d.healSp = base.healSp and base.healSp * s.heal or nil
		d.stars = stars
		d.cookedFrom = r.id
		-- the dish's own buff gets stronger; plain dishes get one by main ingredient
		local stats = {}
		for k, v in pairs(Recipes.Buff[r.kind] or {}) do
			stats[k] = v * s.buffK
		end
		if base.buff then
			for k, v in pairs(base.buff.stats) do
				stats[k] = math.max(stats[k] or 0, v * (1 + (s.buffK - 1) * 0.5))
			end
			d.buff = { id = base.buff.id, stats = stats, dur = base.buff.dur, party = base.buff.party }
		else
			d.buff = { id = "Food", stats = stats, dur = s.dur }
		end
		local parts = {}
		for k, v in pairs(stats) do
			table.insert(parts, "+" .. math.floor(v * 100 + 0.5) .. "% " .. (Recipes.BuffText[k] or k))
		end
		table.sort(parts)
		local healText = (d.heal and ("Restores " .. math.floor(d.heal * 100 + 0.5) .. "% HP. ") or "")
			.. (d.healSp and ("Restores " .. math.floor(d.healSp * 100 + 0.5) .. "% SP. ") or "")
		d.desc = string.rep("*", stars) .. " " .. healText .. table.concat(parts, ", ") .. " for " .. math.floor(d.buff.dur / 60) .. " min"
			.. (d.buff.party and " (whole party nearby)." or ".")
		add(Recipes.ItemId(r.id, stars), d)
	end
end
-- story key item (quest T12): the next island's name only shows once your compass points to it (owner, v0.22.4)
add("SeaCompass", { name = "Sea Compass", kind = "Material", price = 0, stack = true, rarity = "Epic", key = true,
	desc = "An old brass compass. Each time you finish an island's story, it points to the next port and reveals its name." })

-- ===== Cursed Fruits (uneaten: tradable items) =====
local Fruits = require(script.Parent.Fruits)
local fruitPrice = { Rare = 50000, Epic = 150000, Legendary = 400000, Mythic = 1000000, Secret = 2500000 }
for _, f in ipairs(Fruits.List) do
	add("Fruit_" .. f.id, { name = f.name, desc = f.desc .. " Eat it from your Bag.", kind = "Fruit", fruit = f.id, rarity = f.rarity, price = fruitPrice[f.rarity] or 50000, icon = f.icon })
end

-- ===== Pets: eggs and bait =====
add("SeaEgg", { name = "Sea Egg", desc = "Hatch it from your Bag. Hermit 40% / Boarlet 35% / Gull 20% / Puffer 5%.", kind = "Egg", rarity = "Uncommon", price = 2000, icon = "🥚", stack = true })
add("GoldenEgg", { name = "Golden Egg", desc = "Hatch it from your Bag. Gull 40% / Puffer 35% / Lantern 22% / Leviathan 3%.", kind = "Egg", rarity = "Epic", price = 20000, icon = "🪺", stack = true })
add("CrewContract", { name = "Crew Contract", desc = "A sailor's signed papers. Sign it at a Tavern Keeper to add them to your crew.", kind = "Material", price = 50, rarity = "Common", icon = "📜" }) -- v0.25.148: entry.recruit = who (Config/Recruits Record)
add("SeaBait", { name = "Sea Bait", desc = "Throw it at a weakened Wild Boar or Leviathan (below 35% HP) to tame it.", kind = "Consumable", special = true, price = 300, stack = true, rarity = "Common", icon = "🪤" })

-- ===== Ammo (slingshot classes, Config/Ammo) =====
local Ammo = require(script.Parent.Ammo)
for _, am in ipairs(Ammo.List) do
	add(am.item, { name = am.name, desc = am.desc, kind = "Ammo", ammo = am.id, price = am.price, stack = true, rarity = am.rarity or "Common", icon = "🔸" })
end
-- v0.25.81: the old slingshot shots are no longer fired; they only sell
for _, am in ipairs(Ammo.Legacy) do
	add(am.item, { name = am.name, desc = "Old slingshot ammo. It no longer fits a musket: sell it.", kind = "Material", price = am.price, stack = true, rarity = am.rarity or "Common", icon = "🔸" })
end

-- General store stock
local Shop = {
	"MeatOnBone", "RoastShank", "BigFeast", "TangerineJuice", "SeaGrog", "CaptainsKeg", "Bandage", "PatchPlanks", "RepairKit", "RawMeat", "FreshFish", "Tangerine", "Spice", "SeaBait", "SteelOre", "Wood", "SailCloth",
	"SailorVest", "Bandana", "CompassCharm", "SeastoneBracer", "BeardDark", "BeardBrown", "ClownWig",
	"Ammo_Musket",
	"Knuckles_Plain", "Sword_Plain", "Slingshot_Plain", "Shoes_Plain", "StormBaton_Plain", "MedKit_Plain", "Hammer_Plain",
}

return {
	Items = Items,
	Blades = Blades,
	BladeTiers = BLADE_TIERS,
	Greens = GreenIds,
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
