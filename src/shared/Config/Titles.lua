-- Titles: names shown above your head and in chat, in the color of their tier. Equip one in the Bag.
-- Built to grow with the world. A voyage climbs through ladders that mirror how a sea story escalates:
--   Voyage   - how far you have come (base level), sea by sea (Azure East now; Grand Current / Far Horizon later)
--   Pirate   - your bounty (unknown deckhand -> wanted rookie -> ... -> king of the endless sea)
--   Marine   - your merit, through a navy ladder (Recruit -> Fleet Admiral)
--   Class    - mastering a job (Job Lv.40) and, later, second jobs
--   Fruit    - mastering your Cursed Fruit
--   Feats    - achievements (Config/Achievements)
--   Special  - granted by events, the founders' playtest, seasons (never earned by grinding)
-- Tier = rarity id (Modules/Rarity): Common < Uncommon < Rare < Epic < Legendary < Mythic < Secret. The tier sets the color,
-- Legendary+ shimmer, Secret cycles colors. `soon = true` marks a title of a sea that is not out yet (shown locked).
-- Every name is original (no franchise terms).
--
-- need = { level = n } | { bounty = n } | { merit = n } | { job = n, class = id } | { mastery = n, fruit = id }
--      | { achievement = id } | { granted = true }
local T = { List = {}, ById = {} }

local function add(id, name, tier, category, need, desc, extra)
	local t = { id = id, name = name, tier = tier, category = category, need = need, desc = desc }
	for k, v in pairs(extra or {}) do
		t[k] = v
	end
	table.insert(T.List, t)
	T.ById[id] = t
end

T.Categories = { "Voyage", "Pirate", "Marine", "Class", "Fruit", "Feats", "Special" }
T.Default = "Greenhorn"

-- ===== Voyage (base level, sea by sea) =====
add("Greenhorn", "Larper", "Common", "Voyage", { level = 1 }, "Every voyage starts somewhere.")
add("Deckhand", "Deckhand", "Common", "Voyage", { level = 10 }, "Reach Base Lv.10.")
add("SeaRookie", "Sea Rookie", "Uncommon", "Voyage", { level = 20 }, "Reach Base Lv.20.")
add("SaltedSailor", "Salted Sailor", "Uncommon", "Voyage", { level = 35 }, "Reach Base Lv.35.")
add("Voyager", "Voyager", "Rare", "Voyage", { level = 50 }, "Reach Base Lv.50.")
add("WallClimber", "Wall Climber", "Epic", "Voyage", { level = 70 }, "Reach Base Lv.70: ready to climb the Crimson Wall.")
add("CurrentRider", "Current Rider", "Epic", "Voyage", { level = 90 }, "Reach Base Lv.90 in the Grand Current.", { soon = true })
add("StormVeteran", "Storm Veteran", "Legendary", "Voyage", { level = 120 }, "Reach Base Lv.120 in the Grand Current.", { soon = true })
add("HorizonSeeker", "Horizon Seeker", "Mythic", "Voyage", { level = 150 }, "Reach Base Lv.150 beyond the Far Horizon.", { soon = true })

-- ===== Pirate (bounty) =====
add("SmallFry", "Small Fry", "Common", "Pirate", { bounty = 1 }, "Get any bounty on your head.")
add("WantedRookie", "Wanted Rookie", "Uncommon", "Pirate", { bounty = 1000000 }, "Bounty of 1,000,000.")
add("RisingMenace", "Rising Menace", "Rare", "Pirate", { bounty = 10000000 }, "Bounty of 10,000,000.")
add("Notorious", "Notorious", "Rare", "Pirate", { bounty = 50000000 }, "Bounty of 50,000,000.")
add("SeaTerror", "Terror of the Tides", "Epic", "Pirate", { bounty = 150000000 }, "Bounty of 150,000,000.")
add("StormbornRookie", "Stormborn Rookie", "Epic", "Pirate", { bounty = 300000000 }, "Bounty of 300,000,000: one of the rookies everyone talks about.")
add("TideLord", "Tide Lord", "Legendary", "Pirate", { bounty = 1000000000 }, "Bounty of 1,000,000,000.", { soon = true })
add("SeaMonarch", "Monarch of the Sea", "Mythic", "Pirate", { bounty = 3000000000 }, "Bounty of 3,000,000,000.", { soon = true })
add("EndlessKing", "King of the Endless Sea", "Secret", "Pirate", { bounty = 5000000000 }, "The highest bounty the world has ever posted.", { soon = true })

-- ===== Marine (merit ladder) =====
add("Recruit", "Marine Recruit", "Common", "Marine", { merit = 1 }, "Earn your first merit.")
add("Seaman", "Seaman", "Common", "Marine", { merit = 50 }, "50 merit.")
add("PettyOfficer", "Petty Officer", "Uncommon", "Marine", { merit = 300 }, "300 merit.")
add("Ensign", "Ensign", "Uncommon", "Marine", { merit = 1000 }, "1,000 merit.")
add("Lieutenant", "Lieutenant", "Rare", "Marine", { merit = 3000 }, "3,000 merit.")
add("Commander", "Commander", "Rare", "Marine", { merit = 8000 }, "8,000 merit.")
add("MarineCaptain", "Marine Captain", "Epic", "Marine", { merit = 20000 }, "20,000 merit.")
add("Commodore", "Commodore", "Epic", "Marine", { merit = 50000 }, "50,000 merit.")
add("RearAdmiral", "Rear Admiral", "Legendary", "Marine", { merit = 100000 }, "100,000 merit.", { soon = true })
add("ViceAdmiral", "Vice Admiral", "Legendary", "Marine", { merit = 250000 }, "250,000 merit.", { soon = true })
add("Admiral", "Admiral", "Mythic", "Marine", { merit = 600000 }, "600,000 merit.", { soon = true })
add("FleetAdmiral", "Fleet Admiral", "Secret", "Marine", { merit = 1500000 }, "The whole navy answers to you.", { soon = true })

-- ===== Class mastery (Job Lv.40) =====
for _, c in ipairs({
	{ "Brawler", "Iron Knuckle" }, { "Swordsman", "Master Blade" }, { "Sniper", "Eagle Eye" }, { "Cook", "Kitchen Tempest" },
	{ "Navigator", "Weather Sage" }, { "Doctor", "Miracle Hands" }, { "Shipwright", "Master Builder" },
}) do
	add("Job_" .. c[1], c[2], "Epic", "Class", { job = 40, class = c[1] }, "Reach Job Lv.40 as " .. c[1] .. ".")
end

-- ===== Cursed Fruit mastery =====
for _, f in ipairs({
	{ "Slick", "Slippery One", "Rare" }, { "Split", "Thousand Pieces", "Epic" }, { "Ward", "Living Wall", "Epic" },
	{ "Haze", "Walking Fog", "Legendary" }, { "Blaze", "Living Wildfire", "Mythic" }, { "Bounce", "Rubber Legend", "Secret" },
}) do
	add("Fruit_" .. f[1], f[2], f[3], "Fruit", { mastery = 100, fruit = f[1] }, "Reach Mastery 100 with the " .. f[1] .. " " .. f[1] .. " no Mi.")
end

-- ===== Special (granted, never grinded) =====
add("Founder", "Founding Crew", "Legendary", "Special", { granted = true }, "Sailed in the first friends' playtest.")
-- v0.25.129 (owner): the beta's top pirates. Our own names (never the source's emperor / warlord titles).
add("FourTempests", "Four Tempests", "Mythic", "Special", { granted = true }, "One of the four pirates the whole sea fears.")
add("SevenPrivateers", "Seven Privateers", "Legendary", "Special", { granted = true }, "A licensed pirate: the navy looks the other way.")
add("Developer", "Shipwright of Worlds", "Secret", "Special", { granted = true }, "Built this sea.")

-- ===== Feats: every achievement title (ids = achievement ids, so old saves keep their equipped title) =====
local Achievements = require(script.Parent.Achievements)
for _, a in ipairs(Achievements.List) do
	if a.title and not T.ById[a.id] then
		add(a.id, a.title, a.rarity or "Rare", "Feats", { achievement = a.id }, a.desc)
	end
end

return T
