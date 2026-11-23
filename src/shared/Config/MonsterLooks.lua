-- MonsterLooks (v0.25.32, owner): humanoid monsters are voxel characters like the players (Modules/VoxelChar on an
-- R15 rig) that keep their old design: outfit colors, hair, face, and their signature accessories (Config/Accessories)
-- which are also items they drop. Style names come from Config/Looks; colors are hex like the player looks.
--   attack = the R15 clip they swing with (Config/AnimClips), held = the weapon block model in their hand.
local Looks = require(script.Parent.Looks)

local L = {}
L.Marks = { "Scar", "Stubble", "ClownPaint", "WarPaint", "Gills", "Whiskers" } -- tools/gen_faces.py MARKS
local ById = {}
L.ById = ById

local function look(t)
	return t
end

ById.MountainBandit = look({ hair = "Messy", eyes = "Thug", mouth = "Snarl", mark = "Scar", shirt = "Open Vest", pants = "Baggy", shoes = "Wraps",
	hair1 = "3C2A1E", shirt1 = "785A3C", shirt2 = "A08060", pants1 = "4A3A2C", skin = "D6A478", eyes1 = "C08020", eyes2 = "6A3A10",
	acc = { "Bandana", "BeardDark" }, held = "HeldClub", attack = "Hammer_Smash" })
ById.MarineRecruit = look({ hair = "Short", eyes = "Stern", mouth = "Flat", shirt = "Sailor Stripes", pants = "Long Pants", shoes = "Boots",
	hair1 = "462C1E", shirt1 = "F0F0FA", shirt2 = "3C5AAA", pants1 = "3C5AAA", skin = "F6D0AA", eyes1 = "4A3A30", eyes2 = "2A1E18",
	acc = { "MarineCap" }, held = "HeldCutlass", attack = "Sword_Slash" })
ById.MarineRifleman = look({ hair = "Buzz", eyes = "Stern", mouth = "Clench", shirt = "Sailor Stripes", pants = "Long Pants", shoes = "Boots",
	hair1 = "1C1A22", shirt1 = "DCE6FA", shirt2 = "3C5AAA", pants1 = "3C5AAA", skin = "EABE96", eyes1 = "3C3C46", eyes2 = "1C1C24",
	acc = { "MarineCap" }, held = "HeldRifle", attack = "Sling_Shoot" })
ById.ClownGrunt = look({ hair = "Bald", eyes = "Crazed", mouth = "Painted", mark = "ClownPaint", shirt = "Belted Tunic", pants = "Baggy", shoes = "Clogs",
	shirt1 = "FF7878", shirt2 = "FFF0B4", pants1 = "4678D2", skin = "FAF0EB", eyes1 = "30B040", eyes2 = "106020",
	acc = { "ClownWig", "ClownNose" }, held = "HeldClub", attack = "Hammer_Smash" })
ById.CircusAcrobat = look({ hair = "Bald", eyes = "Wink", mouth = "Painted", mark = "ClownPaint", shirt = "Wrap Top", pants = "Side Stripe", shoes = "Slippers",
	shirt1 = "FFC850", shirt2 = "C83CA0", pants1 = "C83CA0", skin = "FAF0EB", eyes1 = "E04090", eyes2 = "801050",
	acc = { "ClownWig", "ClownNose" }, attack = "Cook_FrontKick" })
ById.NightCatPirate = look({ hair = "Wolf Cut", eyes = "Feral", mouth = "Fang", mark = "Whiskers", shirt = "Hoodie", pants = "Long Pants", shoes = "Wraps",
	hair1 = "282230", shirt1 = "463C50", shirt2 = "282230", pants1 = "282232", skin = "C8B4A0", eyes1 = "E0C020", eyes2 = "A08010",
	acc = { "CatEars" }, held = "HeldClaws", attack = "Brawler_Hook" })
ById.HypnoThug = look({ hair = "Pompadour", eyes = "Spiral", mouth = "Snarl", mark = "Stubble", shirt = "Tank", pants = "Cargo", shoes = "Boots",
	hair1 = "3C2850", shirt1 = "C878DC", pants1 = "4A3A5A", skin = "E2C8AA", eyes1 = "B040E0", eyes2 = "602080",
	acc = { "HypnoGoggles" }, held = "HeldClub", attack = "Hammer_Smash" })
ById.ArmadaRaider = look({ hair = "Short", eyes = "Thug", mouth = "Clench", mark = "WarPaint", shirt = "Armor Vest", pants = "Knee Pads", shoes = "Tall Boots",
	hair1 = "2A2A30", shirt1 = "9696A0", shirt2 = "64646E", pants1 = "4A4A54", skin = "D6A478", eyes1 = "A02020", eyes2 = "501010",
	acc = { "IronHelmet" }, held = "HeldCutlass", attack = "Sword_Slash" })
ById.StarvedPirate = look({ hair = "Shaggy Long", eyes = "Tired", mouth = "Nervous", mark = "Stubble", shirt = "Bandage Wrap", pants = "Rolled Cuffs", shoes = "Barefoot",
	hair1 = "786450", shirt1 = "B48C6E", pants1 = "6E5A46", skin = "D6A478", eyes1 = "807060", eyes2 = "4A3A30",
	acc = { "Bandana", "BeardBrown" }, held = "HeldCutlass", attack = "Sword_Slash" })
ById.ArmoredGunner = look({ hair = "Buzz", eyes = "Stern", mouth = "Scowl", mark = "Scar", shirt = "Armor Vest", pants = "Cargo", shoes = "Tall Boots",
	hair1 = "1C1A22", shirt1 = "6E6E78", shirt2 = "46464E", pants1 = "3C3C46", skin = "BE8860", eyes1 = "3C3C46", eyes2 = "1C1C24",
	acc = { "IronHelmet" }, held = "HeldRifle", attack = "Sling_Shoot" })
ById.BountyHunter = look({ hair = "Long Straight", eyes = "Cool", mouth = "Smirk", mark = "Stubble", shirt = "Open Jacket", pants = "Long Pants", shoes = "Buckle Boots",
	hair1 = "462C1E", shirt1 = "64503C", shirt2 = "C8A064", pants1 = "322822", skin = "EABE96", eyes1 = "70A0A0", eyes2 = "305050",
	acc = { "Bandana" }, held = "HeldPistol", attack = "Sling_Shoot" })
ById.MarineElite = look({ hair = "Side Part", eyes = "Determined", mouth = "Flat", shirt = "Captain Coat", pants = "Long Pants", shoes = "Tall Boots",
	hair1 = "1C1A22", shirt1 = "FFFFFF", shirt2 = "1E3278", pants1 = "1E3278", skin = "F6D0AA", eyes1 = "2A4A8A", eyes2 = "14244A",
	acc = { "MarineCap", "MarineCoat" }, held = "HeldCutlass", attack = "Sword_Slash" })
ById.MistSoldier = look({ hair = "Buzz", eyes = "Stern", mouth = "Flat", shirt = "Long Sleeve", pants = "Cargo", shoes = "Boots",
	hair1 = "54545E", shirt1 = "C8C8D2", shirt2 = "6E6E82", pants1 = "6E6E82", skin = "E2C8AA", eyes1 = "8A8A9A", eyes2 = "4A4A5A",
	acc = { "MarineCap" }, held = "HeldRifle", attack = "Sling_Shoot" })

-- fish-folk = Tidekin bodies (race + variant from Config/Looks: 1 reef, 2 shark, 3 lionfish, 4 manta)
ById.SharkfolkBrawler = look({ race = "Tidekin", variant = 2, hair = "Buzz", eyes = "Beady", mouth = "Fang", mark = "Gills", shirt = "Open Vest", pants = "Wide Hakama", shoes = "Barefoot",
	hair1 = "28324A", shirt1 = "E6E6EE", shirt2 = "3C64A0", pants1 = "2A3A5A", skin = "6E9CC8", eyes1 = "202020", eyes2 = "101010",
	acc = { "SharkToothNecklace" }, attack = "Brawler_Hook" })
ById.SawfolkRaider = look({ race = "Tidekin", variant = 3, hair = "Spiky", eyes = "Beady", mouth = "Snarl", mark = "Gills", shirt = "Armor Vest", pants = "Cargo", shoes = "Wraps",
	hair1 = "3A3070", shirt1 = "6E78C8", shirt2 = "3C4690", pants1 = "2E2A50", skin = "8C96D2", eyes1 = "202020", eyes2 = "101010",
	acc = { "Bandana" }, held = "HeldCutlass", attack = "Sword_Slash" })
ById.OctofolkBrute = look({ race = "Tidekin", variant = 1, hair = "Afro", eyes = "Beady", mouth = "Scowl", shirt = "Tank", pants = "Baggy", shoes = "Barefoot",
	hair1 = "B4466E", shirt1 = "F0E6C8", pants1 = "6E3C5A", skin = "E68CAA", eyes1 = "F0C040", eyes2 = "A07010",
	acc = { "BeardDark" }, held = "HeldClub", attack = "Hammer_Smash" })

-- bosses (scaled up by Config/Monsters style.scale)
ById.AxeCaptain = look({ hair = "Buzz", eyes = "Thug", mouth = "Scowl", mark = "Scar", shirt = "Captain Coat", pants = "Long Pants", shoes = "Tall Boots",
	hair1 = "6E5032", shirt1 = "F0F0FA", shirt2 = "283C78", pants1 = "283C78", skin = "D6A478", eyes1 = "6A4A2A", eyes2 = "3A2414",
	acc = { "MarineCap", "BeardBrown", "CapeNavy" }, held = "HeldBattleAxe", attack = "Hammer_Smash" })
ById.CaptainConfetti = look({ hair = "Bald", eyes = "Crazed", mouth = "Painted", mark = "ClownPaint", shirt = "Captain Coat", pants = "Baggy", shoes = "Clogs",
	shirt1 = "FF5050", shirt2 = "FFD040", pants1 = "7828C8", skin = "FAF0EB", eyes1 = "E04040", eyes2 = "801010",
	acc = { "ConfettiWig", "ClownNose", "CapePurple" }, held = "HeldClub", attack = "Hammer_Smash" })
ById.RingMaster = look({ hair = "Swept", eyes = "Sharp", mouth = "Grin", mark = "ClownPaint", shirt = "Captain Coat", pants = "Long Pants", shoes = "Tall Boots",
	hair1 = "1C1A22", shirt1 = "C83CA0", shirt2 = "FFD040", pants1 = "1C1A22", skin = "FAF0EB", eyes1 = "C040A0", eyes2 = "601050",
	acc = { "RingmasterHat", "CapeGold" }, held = "HeldClub", attack = "Hammer_Smash" })
ById.SilentClaw = look({ hair = "Wolf Cut", eyes = "Feral", mouth = "Fang", mark = "Whiskers", shirt = "Open Jacket", pants = "Long Pants", shoes = "Wraps",
	hair1 = "1C1A22", shirt1 = "3C3246", shirt2 = "1E1828", pants1 = "1E1828", skin = "C8B4A0", eyes1 = "F0E040", eyes2 = "B0A010",
	acc = { "CatEars", "GlowVisor", "CapeShadow" }, held = "HeldClaws", attack = "Brawler_Hook" })
ById.ArmadaAdmiral = look({ hair = "Short", eyes = "Fierce", mouth = "Smirk", mark = "WarPaint", shirt = "Armor Vest", pants = "Knee Pads", shoes = "Tall Boots",
	hair1 = "2A2A30", shirt1 = "E6BE3C", shirt2 = "A08228", pants1 = "4A4A54", skin = "BE8860", eyes1 = "C08020", eyes2 = "6A3A10",
	acc = { "AdmiralCrown", "CapeCrimson" }, held = "HeldCutlass", attack = "Sword_Slash" })
ById.SawtoothOverlord = look({ race = "Tidekin", variant = 2, hair = "Hero Spikes", eyes = "Feral", mouth = "Snarl", mark = "Gills", shirt = "Captain Coat", pants = "Wide Hakama", shoes = "Barefoot",
	hair1 = "1E2A46", shirt1 = "3C5A96", shirt2 = "E6BE3C", pants1 = "1E2A46", skin = "5A82B4", eyes1 = "E02020", eyes2 = "801010",
	acc = { "SharkToothNecklace", "CapeShadow" }, held = "HeldBattleAxe", attack = "Hammer_Smash" })
ById.DepthsWarden = look({ race = "Tidekin", variant = 4, hair = "Long Straight", eyes = "Beady", mouth = "Flat", mark = "Gills", shirt = "Armor Vest", pants = "Long Pants", shoes = "Tall Boots",
	hair1 = "1E3C64", shirt1 = "285A8C", shirt2 = "5AC8C8", pants1 = "1E2E50", skin = "3C6EA0", eyes1 = "40E0E0", eyes2 = "108080",
	acc = { "IronHelmet", "CapeSlate" }, held = "HeldTrident", attack = "Sword_Slash" })
ById.MistCommodore = look({ hair = "Side Part", eyes = "Calm", mouth = "Flat", mark = "Scar", shirt = "Captain Coat", pants = "Long Pants", shoes = "Tall Boots",
	hair1 = "C8C8D2", shirt1 = "EBEBF5", shirt2 = "5A5A6E", pants1 = "5A5A6E", skin = "E2C8AA", eyes1 = "A0A0B0", eyes2 = "50505E",
	acc = { "MarineCap", "BeardGrey", "CapeSlate" }, held = "HeldCutlass", attack = "Sword_Slash" })

-- the VoxelChar look for a monster (style names -> indexes, colors kept, the rest from Looks.Default)
local NAME_LISTS = { hair = Looks.Hair, eyes = Looks.Eyes, mouth = Looks.Mouths, shirt = Looks.Shirts, pants = Looks.Pants, shoes = Looks.Shoes }
function L.Look(id)
	local e = ById[id]
	if not e then
		return nil
	end
	local out = {}
	for k, v in pairs(e) do
		local list = NAME_LISTS[k]
		if list then
			out[k] = table.find(list, v) or 1
		elseif type(v) == "string" then
			out[k] = v
		end
	end
	out.hair2 = out.hair2 or out.hair1
	out.pants2 = out.pants2 or out.pants1
	out.shoes1 = out.shoes1 or "462C1E"
	out.shoes2 = out.shoes2 or "1C1A22"
	local res = Looks.Sanitize(out)
	res.mark = e.mark -- face mark image (VoxelChar faceLayer "mark<Name>"), monsters only
	return res
end

-- race body for a monster (nil = plain human): returns heritage id, variant index
function L.Race(id)
	local e = ById[id]
	return e and e.race, e and e.variant or 1
end

-- self-check: every style name and accessory exists (a typo would silently fall back to the defaults)
do
	local Acc = require(script.Parent.Accessories)
	for id, e in pairs(ById) do
		for k, list in pairs(NAME_LISTS) do
			assert(e[k] == nil or table.find(list, e[k]), "MonsterLooks." .. id .. ": unknown " .. k .. " " .. tostring(e[k]))
		end
		assert(e.mark == nil or table.find(L.Marks, e.mark), "MonsterLooks." .. id .. ": unknown mark " .. tostring(e.mark))
		for _, a in ipairs(e.acc or {}) do
			assert(Acc[a], "MonsterLooks." .. id .. ": unknown accessory " .. a)
		end
		assert(e.race == nil or Looks.Variant(e.race, e.variant or 1), "MonsterLooks." .. id .. ": unknown race " .. tostring(e.race))
		assert(e.held == nil or Acc[e.held], "MonsterLooks." .. id .. ": unknown held " .. tostring(e.held))
	end
end

return L
