-- Main story quests ("Azure East Saga"). One linear chain: the Daybreak tutorial, then a short chapter per island.
--
-- goal.kind:
--   Talk     target = NPC role on the step's island ("Guide", "Shipwright", "Tavern", "Blacksmith", ...)
--   Kill     target = monster id (nil = any monster), count
--   Skill    use any skill, count
--   Auto     switch Auto Battle on (unused in the remake)
--   Guard    block or parry a monster hit
--   Stat     spend stat points, count
--   Equip    equip any item
--   Refine   attempt a refine at the Blacksmith
--   Buy      buy something at the General Store
--   Hire     hire crew at the Tavern
--   Launch   launch your ship from a dock
--   Sink     sink NPC ships at sea, count
--   Dungeon  clear a dungeon (target = dungeon id)
--   Reach    discover an island (target = island id)            [checked from player state]
--   JobLevel reach Job Lv.count                                  [checked from player state]
--   Level    reach Base Lv.count                                 [checked from player state]
--   Class    pick a class at the Job Master                      [checked from player state]
--   Talent   own count Talent cards (remake: replaces the Job Master visit) [checked from player state]
--   Arrive   stand on island `target` (QuestService checks every 2 s)    [checked from player state]
--
-- at (where the quest marker points): { npc = role } | { spawn = monsterId } | { island = id } | { sea = true }
-- reward: { beli, exp, job, items = { { id, qty } } }
-- speaker: who says the dialog (default: the island's Guide). originDialog[originId]: lines that replace `dialog`
-- for players of that Origin (Quests.DialogFor).
local Q = {}

Q.Guide = {
	Daybreak = "Rowan", -- v0.25.112 (owner): short and easy to remember (was Old Salt Rowan)
	ConchBay = "Lieutenant Pell",
	Marmalade = "Mayor Biscuit",
	Honeyslope = "Nanny Clove",
	Barracuda = "Head Chef Gusto",
	Mikan = "Granny Rind",
	Epilogue = "Harbor Master Vane",
	-- R5 Origin home islands
	BastionRock = "Instructor Halyard",
	SmugglersHollow = "Old Gaff",
	ShackleReef = "Rattle Jack",
	InkwellIsle = "Sage Quill",
}

Q.Main = {
	-- ========== Daybreak Island: tutorial ==========
	-- Route: jungle camp (spawn) -> monkey grove -> tiger den -> windmill village (Job Master) -> boar meadow
	--        -> bandit windmill hill -> harbor (Shipwright) -> sea.
	{
		id = "T01", island = "Daybreak", title = "Ahoy, Greenhorn!",
		dialog = { "Easy now, you washed up half-drowned. Name's Rowan. Thirty years at sea, and this jungle camp is where I fish strays out of the surf.", "Want to sail the Azure East? Then you'll need muscle, a crew and a ship. Talk to me and we'll get you started." },
		originDialog = {
			MarineCadet = { "A cadet from Bastion Rock! Name's Rowan. Your Instructor sent word you'd be coming.", "Before the Marines hand you a ship, they want you blooded. Talk to me and we'll get you started." },
			BountyHunter = { "Old Gaff sent you, eh? Name's Rowan. That Bandit Chief poster won't collect itself.", "But a hunter needs muscle, a crew and a ship first. Talk to me and we'll get you started." },
			Outlaw = { "Shackle Reef, you say? Then I never saw you. Name's Rowan, and this camp asks no questions.", "Want to stay free? You'll need muscle, a crew and a ship. Talk to me and we'll get you started." },
			RelicSeeker = { "Sage Quill's student! Name's Rowan. So the old map points under Daybreak, does it?", "Ruins or not, you'll need muscle, a crew and a ship to go digging. Talk to me and we'll get you started." },
		},
		goal = { kind = "Talk", target = "Guide" }, text = "Talk to Rowan",
		hint = "Walk up to the glowing NPC by the campfire and press E (tap Talk on phones).",
		at = { npc = "Guide" }, reward = { beli = 100, exp = 20, job = 10 },
	},
	{
		id = "T02", island = "Daybreak", title = "Monkey Business",
		dialog = { "Forest Monkeys raided my camp and ran off with the supplies. They're in the grove just north of the fire.", "Walk up to a monkey and click to punch it (hold to keep swinging). Hold F to block their swipes." },
		goal = { kind = "Kill", target = "ForestMonkey", count = 5 }, text = "Defeat Forest Monkeys",
		hint = "Walk close, then click or tap the attack button. Hold to keep swinging.",
		at = { spawn = "ForestMonkey" }, reward = { beli = 150, exp = 60, job = 40, items = { { "MeatOnBone", 5 } } },
	},
	{
		id = "T03", island = "Daybreak", title = "Show Some Technique",
		dialog = { "Swinging wildly won't cut it. Use a skill! Press 3 for your Basic set, then E (or tap the first slot of the top row)." },
		goal = { kind = "Skill", count = 2 }, text = "Use a skill",
		hint = "Keys 1-6 pick a skill set, E R F Z X C use its skills (or tap them). Skills cost SP (blue bar).",
		at = { spawn = "ForestMonkey" }, reward = { beli = 100, exp = 40, job = 40 },
	},
	{
		id = "T04", island = "Daybreak", title = "Guard Up",
		dialog = { "Tigers hit hard. Hold F to raise your guard and take the blows on your arms.", "Tap F just before a hit lands and you parry it: the beast is left dazed. Your guard cracks if you hold it too long." },
		goal = { kind = "Guard", count = 3 }, text = "Block or parry hits",
		hint = "Face the monster and hold F (or the BLOCK button). Tap F right before it strikes to parry.",
		at = { spawn = "JungleTiger" }, reward = { beli = 100, exp = 30, job = 20 },
	},
	{
		id = "T05", island = "Daybreak", title = "Stripes in the Grass",
		dialog = { "Jungle Tigers prowl the den south of camp, down by the old stones. Bigger than monkeys, so keep your guard up and use your skills." },
		goal = { kind = "Kill", target = "JungleTiger", count = 6 }, text = "Defeat Jungle Tigers",
		hint = "Follow the path south of the camp to the Tiger Den. Block their swipes, then hit back.",
		at = { spawn = "JungleTiger" }, reward = { beli = 200, exp = 120, job = 80, items = { { "Bandana", 1 } } },
	},
	{
		id = "T06", island = "Daybreak", title = "Train Your Body",
		dialog = { "You've earned stat points. Vitality keeps you alive, Endurance fuels your dashes and climbs, Willpower steadies the mind. Weaponry, Martial Arts and Fruit Mastery decide how you fight.", "You can't master everything: 300 points is the most any body can hold. Open Stats with Y and spend a few." },
		goal = { kind = "Stat", count = 3 }, text = "Spend stat points",
		hint = "Press Y, then + next to a stat, then Apply.",
		at = { npc = "Guide" }, reward = { beli = 100, exp = 40, job = 30 },
	},
	{
		id = "T07", island = "Daybreak", title = "Dress the Part",
		dialog = { "Here, take my old bandana. Open your Bag with I and equip it.", "Then follow the trail east out of the jungle: the windmill village is just past the hills." },
		goal = { kind = "Equip" }, text = "Equip the Bandana",
		hint = "Press I, click the Bandana, then Equip.",
		at = { npc = "Guide" }, reward = { beli = 150, exp = 40, job = 30 },
	},
	{
		id = "T08", island = "Daybreak", title = "Ready for a Calling",
		dialog = { "Keep at those tigers until your weapon arts reach Lv.5. Whatever you hold, fists or blade, learns with you.", "Learn new skills with K whenever you have skill points." },
		goal = { kind = "JobLevel", count = 5 }, text = "Reach Arts Lv.5",
		hint = "Fight Jungle Tigers in the den. Every weapon keeps its own Arts level.",
		at = { spawn = "JungleTiger" }, reward = { beli = 300, exp = 150, items = { { "TangerineJuice", 5 } } },
	},
	{
		id = "T09", island = "Daybreak", title = "Find Your Calling",
		-- remake 0.1.10 (owner): no Job Master; this step teaches the Talent cards instead (same slot, no save shift)
		dialog = { "Every time you level up, the sea offers you a Talent card. Press T and pick one of three.", "Repairing, cooking, steering, healing and gunnery all grow too: check the Mastery tab." },
		goal = { kind = "Talent", count = 1 }, text = "Pick a Talent card",
		hint = "Press T (or the Talents button in the menu) and pick 1 of the 3 cards.",
		reward = { beli = 500, exp = 200, job = 100 },
	},
	{
		-- v3 (owner, v0.25.4): class first at Job Lv.5, THEN the boars (they were the Job Lv.10 grind before)
		id = "T09B", island = "Daybreak", title = "Boar Hunt",
		dialog = { "Wild Boars trample the farm meadow south of the village. Try your weapon arts on them!" },
		goal = { kind = "Kill", target = "WildBoar", count = 6 }, text = "Defeat Wild Boars",
		hint = "The boar meadow is south of the village. Use your weapon arts (K opens the skill tree).",
		at = { spawn = "WildBoar" }, reward = { beli = 350, exp = 220, job = 140, items = { { "MeatOnBone", 5 } } },
	},
	{
		id = "T10", island = "Daybreak", title = "Bandit Hill",
		dialog = { "Mountain Bandits have taken the windmill hill behind the village and raid the mills every night. Test your new class on them before you set sail." },
		goal = { kind = "Kill", target = "MountainBandit", count = 6 }, text = "Defeat Mountain Bandits",
		hint = "Climb the stairs up Bandit Hill, west of the village. Try your new class skills (K opens the skill tree).",
		at = { spawn = "MountainBandit" }, reward = { beli = 400, exp = 300, job = 200, items = { { "SteelOre", 3 } } },
	},
	{
		id = "T11", island = "Daybreak", title = "Set Sail!",
		dialog = { "You're ready. Your little dinghy is waiting at the Shipwright down at the harbor, past the plaza.", "Talk to the Shipwright, press Launch, then steer with A/D and raise sails with W." },
		goal = { kind = "Launch" }, text = "Launch your ship",
		hint = "Talk to the Shipwright at the dock and press Launch.",
		at = { npc = "Shipwright" }, reward = { beli = 300, exp = 100, job = 50, items = { { "RepairKit", 2 } } },
	},
	{
		id = "T12", island = "Daybreak", title = "The Serpent at the Gate",
		dialog = { "Hold fast! A Bay Serpent lurks in the water right outside our harbor. Nothing sails past it to the open sea.", "Sail south of the island and it will rise to meet you. Fight it from your deck: punch it when it comes close, fire your cannons, and watch the water: red lines show where it lunges and spits.", "It will chew planks off your hull, so keep your eye on your ship's health. Beat it and this old compass is yours." },
		goal = { kind = "Kill", target = "BaySerpent", count = 1 }, text = "Defeat the Bay Serpent",
		hint = "Sail out south of Daybreak: it rises when you come near. Bring friends if it is too strong.",
		at = { boss = "Daybreak" }, reward = { beli = 600, exp = 500, job = 250, items = { { "SeaCompass", 1 }, { "MeatOnBone", 5 } } },
	},
	{
		id = "T13", island = "Daybreak", title = "Next Port: Conch Bay",
		dialog = { "Sail west and follow the yellow dots. Keep north of the dark, still water far to the south: that is the Doldrums, no wind and Leviathans." },
		goal = { kind = "Reach", target = "ConchBay" }, text = "Reach Conch Bay",
		hint = "Follow the dotted line west. Dock with E near the pier.",
		at = { island = "ConchBay" }, reward = { beli = 800, exp = 400, job = 200 },
	},

	-- ========== Conch Bay: Marine Outpost ==========
	{
		id = "C01", island = "ConchBay", title = "Under the Axe",
		dialog = { "A pirate? A Marine? Nobody's decided yet, eh. Lieutenant Pell. This outpost is run by a brute with an axe for an arm.", "Before we talk business, thin out the rowdy recruits on the training grounds." },
		goal = { kind = "Talk", target = "Guide" }, text = "Talk to Lieutenant Pell",
		at = { npc = "Guide" }, reward = { beli = 200, exp = 200, job = 100 },
	},
	{
		id = "C02", island = "ConchBay", title = "Drill Sergeant",
		dialog = { "Ten recruits. Don't hurt them too badly." },
		goal = { kind = "Kill", target = "MarineRecruit", count = 10 }, text = "Defeat Marine Recruits",
		at = { spawn = "MarineRecruit" }, reward = { beli = 600, exp = 900, job = 500 },
	},
	{
		id = "C03", island = "ConchBay", title = "Hands on Deck",
		dialog = { "One ship, two cannons, one crewman? Each cannon needs a hand to fire. Sailors looking for a ship hang around the Tavern: talk to one and recruit them." },
		goal = { kind = "Hire" }, text = "Recruit a sailor at the Tavern",
		hint = "More crew = more cannons fire per volley.",
		at = { npc = "Tavern" }, reward = { beli = 500, exp = 300, job = 150 },
	},
	{
		id = "C04", island = "ConchBay", title = "Guard Dogs",
		dialog = { "The guard wolves broke loose again. Round them up." },
		goal = { kind = "Kill", target = "GuardWolf", count = 8 }, text = "Defeat Guard Wolves",
		at = { spawn = "GuardWolf" }, reward = { beli = 800, exp = 1300, job = 700, items = { { "SteelOre", 5 } } },
	},
	{
		id = "C05", island = "ConchBay", title = "Baptism of Fire",
		dialog = { "Real sailors fight at sea. Sail out and sink an enemy ship. Click the water to fire, F fires at the nearest target." },
		goal = { kind = "Sink", count = 1 }, text = "Sink an NPC ship",
		hint = "Green firing arcs = cannons ready. Lead moving ships.",
		at = { sea = true }, reward = { beli = 1500, exp = 1600, job = 800, items = { { "IronIngot", 4 }, { "Gunpowder", 4 } } },
	},
	{
		id = "C06", island = "ConchBay", title = "Riflemen on the Wall",
		dialog = { "Last job: the riflemen on the garrison wall are getting trigger-happy." },
		goal = { kind = "Kill", target = "MarineRifleman", count = 10 }, text = "Defeat Marine Riflemen",
		at = { spawn = "MarineRifleman" }, reward = { beli = 1200, exp = 2200, job = 1100 },
	},
	{
		id = "C07", island = "ConchBay", title = "Circus Lights",
		dialog = { "Word is a circus gang took over Marmalade Town to the south-west. Go see what's happening." },
		goal = { kind = "Reach", target = "Marmalade" }, text = "Reach Marmalade Town",
		at = { island = "Marmalade" }, reward = { beli = 2000, exp = 2500, job = 1200 },
	},

	-- ========== Marmalade Town ==========
	{
		id = "M01", island = "Marmalade", title = "Empty Streets",
		dialog = { "Shh! Mayor Biscuit. The whole town is hiding from Captain Confetti's circus. Help us, will you?" },
		goal = { kind = "Talk", target = "Guide" }, text = "Talk to Mayor Biscuit",
		at = { npc = "Guide" }, reward = { beli = 500, exp = 1500, job = 700 },
	},
	{
		id = "M02", island = "Marmalade", title = "Send in the Clowns",
		dialog = { "Clown grunts everywhere. Twelve should send a message." },
		goal = { kind = "Kill", target = "ClownGrunt", count = 12 }, text = "Defeat Clown Grunts",
		at = { spawn = "ClownGrunt" }, reward = { beli = 1500, exp = 5000, job = 2500 },
	},
	{
		id = "M03", island = "Marmalade", title = "Sharpen Up",
		dialog = { "Your gear's looking dull. The Blacksmith can refine it: +1 to +4 never fails." },
		goal = { kind = "Refine" }, text = "Refine a piece of gear",
		hint = "Talk to the Blacksmith, pick an item, press Refine.",
		at = { npc = "Blacksmith" }, reward = { beli = 1000, exp = 2000, job = 1000, items = { { "SteelOre", 8 } } },
	},
	{
		id = "M04", island = "Marmalade", title = "Acrobatics",
		dialog = { "The acrobats jump between the rooftops. Knock them down." },
		goal = { kind = "Kill", target = "CircusAcrobat", count = 10 }, text = "Defeat Circus Acrobats",
		at = { spawn = "CircusAcrobat" }, reward = { beli = 2000, exp = 6500, job = 3200 },
	},
	{
		id = "M05", island = "Marmalade", title = "Lion Tamer",
		dialog = { "And the lions. Of course there are lions." },
		goal = { kind = "Kill", target = "CircusLion", count = 8 }, text = "Defeat Circus Lions",
		at = { spawn = "CircusLion" }, reward = { beli = 2500, exp = 8000, job = 4000, items = { { "TidecoreShard", 1 } } },
	},
	{
		id = "M06", island = "Marmalade", title = "Up the Slope",
		dialog = { "Thank you, sailor! North-west of here there's a quiet village on a hill. Too quiet, some say." },
		goal = { kind = "Reach", target = "Honeyslope" }, text = "Reach Honeyslope Village",
		at = { island = "Honeyslope" }, reward = { beli = 3000, exp = 9000, job = 4500 },
	},

	-- ========== Honeyslope Village ==========
	{
		id = "H01", island = "Honeyslope", title = "Nanny's Worry",
		dialog = { "Oh dear, a visitor. I'm Nanny Clove, I look after the manor. Strange cat-eyed pirates prowl at night." },
		goal = { kind = "Talk", target = "Guide" }, text = "Talk to Nanny Clove",
		at = { npc = "Guide" }, reward = { beli = 1000, exp = 5000, job = 2500 },
	},
	{
		id = "H02", island = "Honeyslope", title = "Night Prowlers",
		dialog = { "They come down the slope by the dozen." },
		goal = { kind = "Kill", target = "NightCatPirate", count = 12 }, text = "Defeat Night Cat Pirates",
		at = { spawn = "NightCatPirate" }, reward = { beli = 3000, exp = 14000, job = 7000 },
	},
	{
		id = "H03", island = "Honeyslope", title = "Snap Out of It",
		dialog = { "Some of the villagers were hypnotized into joining them!" },
		goal = { kind = "Kill", target = "HypnoThug", count = 10 }, text = "Defeat Hypno Thugs",
		at = { spawn = "HypnoThug" }, reward = { beli = 3500, exp = 17000, job = 8500 },
	},
	{
		id = "H04", island = "Honeyslope", title = "Sharp Claws",
		dialog = { "The claw-cats guard the cliffs behind the manor. Be careful." },
		goal = { kind = "Kill", target = "ClawCat", count = 8 }, text = "Defeat Claw Cats",
		at = { spawn = "ClawCat" }, reward = { beli = 4000, exp = 20000, job = 10000, items = { { "TidecoreShard", 2 } } },
	},
	{
		id = "H05", island = "Honeyslope", title = "Smell of Dinner",
		dialog = { "Sailors say there's a restaurant floating out at sea, shaped like a giant fish." },
		goal = { kind = "Reach", target = "Barracuda" }, text = "Reach Barracuda Bistro",
		at = { island = "Barracuda" }, reward = { beli = 5000, exp = 24000, job = 12000 },
	},

	-- ========== Barracuda Bistro ==========
	{
		id = "B01", island = "Barracuda", title = "Table for One",
		dialog = { "Welcome to the Barracuda! Head Chef Gusto. Sit, eat... and maybe help us with the pirates banging on the doors." },
		goal = { kind = "Talk", target = "Guide" }, text = "Talk to Head Chef Gusto",
		at = { npc = "Guide" }, reward = { beli = 2000, exp = 12000, job = 6000 },
	},
	{
		id = "B02", island = "Barracuda", title = "No Shoes, No Service",
		dialog = { "Raiders from the Iron Armada. Throw them out." },
		goal = { kind = "Kill", target = "ArmadaRaider", count = 12 }, text = "Defeat Armada Raiders",
		at = { spawn = "ArmadaRaider" }, reward = { beli = 5000, exp = 32000, job = 16000 },
	},
	{
		id = "B03", island = "Barracuda", title = "Hungry Pirates",
		dialog = { "The starving ones are the worst. They eat the furniture." },
		goal = { kind = "Kill", target = "StarvedPirate", count = 10 }, text = "Defeat Starved Pirates",
		at = { spawn = "StarvedPirate" }, reward = { beli = 6000, exp = 38000, job = 19000 },
	},
	{
		id = "B04", island = "Barracuda", title = "Armada at Sea",
		dialog = { "Their fleet is circling the restaurant. Sink a few ships." },
		goal = { kind = "Sink", count = 3 }, text = "Sink NPC ships",
		at = { sea = true }, reward = { beli = 9000, exp = 45000, job = 22000, items = { { "TreasureMap", 1 } } },
	},
	{
		id = "B05", island = "Barracuda", title = "Tangerine Breeze",
		dialog = { "You've a good appetite for trouble. The Mikan Isles are next. Watch out for the sharkfolk." },
		goal = { kind = "Reach", target = "Mikan" }, text = "Reach the Mikan Isles",
		at = { island = "Mikan" }, reward = { beli = 10000, exp = 50000, job = 25000 },
	},

	-- ========== Mikan Isles ==========
	{
		id = "K01", island = "Mikan", title = "The Grove Keeper",
		dialog = { "Granny Rind, I tend the tangerine groves. The sharkfolk from Sawtooth Park take a 'tax' every month. I'm tired of paying." },
		goal = { kind = "Talk", target = "Guide" }, text = "Talk to Granny Rind",
		at = { npc = "Guide" }, reward = { beli = 3000, exp = 25000, job = 12000 },
	},
	{
		id = "K02", island = "Mikan", title = "Fin Collectors",
		dialog = { "Start with the brawlers by the windmill." },
		goal = { kind = "Kill", target = "SharkfolkBrawler", count = 12 }, text = "Defeat Sharkfolk Brawlers",
		at = { spawn = "SharkfolkBrawler" }, reward = { beli = 9000, exp = 65000, job = 32000 },
	},
	{
		id = "K03", island = "Mikan", title = "Sawteeth",
		dialog = { "Then the saw-nosed raiders." },
		goal = { kind = "Kill", target = "SawfolkRaider", count = 10 }, text = "Defeat Sawfolk Raiders",
		at = { spawn = "SawfolkRaider" }, reward = { beli = 10000, exp = 75000, job = 37000 },
	},
	{
		id = "K04", island = "Mikan", title = "Eight Arms",
		dialog = { "The octopus brutes guard the park gate." },
		goal = { kind = "Kill", target = "OctofolkBrute", count = 8 }, text = "Defeat Octofolk Brutes",
		at = { spawn = "OctofolkBrute" }, reward = { beli = 12000, exp = 85000, job = 42000, items = { { "TidecoreShard", 3 } } },
	},
	{
		id = "K05", island = "Mikan", title = "Last Harbor",
		dialog = { "Every pirate's last stop before the Crimson Wall is Epilogue Town. Go, and don't forget us." },
		goal = { kind = "Reach", target = "Epilogue" }, text = "Reach Epilogue Town",
		at = { island = "Epilogue" }, reward = { beli = 15000, exp = 100000, job = 50000 },
	},

	-- ========== Epilogue Town ==========
	{
		id = "E01", island = "Epilogue", title = "Town of Beginnings and Ends",
		dialog = { "Harbor Master Vane. Everyone who's anyone passed through this harbor. Bounty hunters too, and they're looking at you." },
		goal = { kind = "Talk", target = "Guide" }, text = "Talk to Harbor Master Vane",
		at = { npc = "Guide" }, reward = { beli = 5000, exp = 50000, job = 25000 },
	},
	{
		id = "E02", island = "Epilogue", title = "Hunted",
		dialog = { "Turn the tables on the bounty hunters." },
		goal = { kind = "Kill", target = "BountyHunter", count = 12 }, text = "Defeat Bounty Hunters",
		at = { spawn = "BountyHunter" }, reward = { beli = 15000, exp = 140000, job = 70000 },
	},
	{
		id = "E03", island = "Epilogue", title = "Elite Patrol",
		dialog = { "Marine elites patrol the plaza. Show them you're ready." },
		goal = { kind = "Kill", target = "MarineElite", count = 10 }, text = "Defeat Marine Elites",
		at = { spawn = "MarineElite" }, reward = { beli = 18000, exp = 160000, job = 80000 },
	},
	{
		id = "E04", island = "Epilogue", title = "Into the Mist",
		dialog = { "The mist soldiers came with the fog. Nobody knows who leads them." },
		goal = { kind = "Kill", target = "MistSoldier", count = 10 }, text = "Defeat Mist Soldiers",
		at = { spawn = "MistSoldier" }, reward = { beli = 20000, exp = 180000, job = 90000, items = { { "PureTidecore", 1 } } },
	},
	{
		id = "E05", island = "Epilogue", title = "The Crimson Wall",
		dialog = { "Beyond this town stands the Crimson Wall, and water that flows uphill. Only the strong climb Backflow Peak. Reach Lv.70 and the Grand Current awaits." },
		goal = { kind = "Level", count = 70 }, text = "Reach Base Lv.70",
		at = { island = "Epilogue" }, reward = { beli = 50000, items = { { "TreasureWood", 1 } } },
	},
}

-- R5 (0.1.27): a short prologue on each Origin's home island (World/OriginIslands), played before the Daybreak
-- tutorial: meet your Origin's NPC, clear the island's own troublemakers, report, then make your way to Daybreak.
-- Saved as quest.pro = { origin, i } (OriginService.Apply starts it); the Castaway has none.
local SAIL_HINT = "Call your ship at a dock (MENU > Ships), then row or sail toward the arrow. Or fly with the Courier Gull Post (100 Doubloons)."
local SAIL_LINES = { "Daybreak lies west. Call your ship at a dock and follow the arrow, or let the Courier Gull Post fly you over." }
Q.Prologue = {
	MarineCadet = {
		{
			id = "PM1", island = "BastionRock", title = "Last Day at the Academy", speaker = "Marine Registrar",
			dialog = { "Cadet! Stand up straight. Your papers are signed: as of today you serve the Marines.", "One last duty before your posting: the supply sheds. Instructor Halyard will tell you the rest." },
			goal = { kind = "Talk", target = "Marine" }, text = "Report to the Marine Registrar",
			hint = "The Marine Registrar stands in front of the academy. Walk up and press E.",
			at = { npc = "Marine" }, reward = { beli = 100, exp = 20, job = 10 },
		},
		{
			id = "PM2", island = "BastionRock", title = "Thieves in the Stores",
			dialog = { "Instructor Halyard. Gull Thieves keep raiding our supply sheds on the far shore. Shameful, on an academy island.", "Clear them out, cadet. Hold F to block their clubs, then hit back." },
			goal = { kind = "Kill", target = "GullThief", count = 5 }, text = "Defeat Gull Thieves",
			hint = "The supply sheds are past the drill yard. Click to attack, hold F to block.",
			at = { spawn = "GullThief" }, reward = { beli = 150, exp = 60, job = 40, items = { { "MeatOnBone", 3 } } },
		},
		{
			id = "PM3", island = "BastionRock", title = "Your First Posting",
			dialog = { "Not bad for a greenhorn. Your posting is Daybreak Island, just west of here. Old Rowan there trains every new sailor in these waters.", "Your dinghy waits at the dock. Off you go, and make the academy proud." },
			goal = { kind = "Talk", target = "Guide" }, text = "Report to Instructor Halyard",
			hint = "Instructor Halyard stands beside the Registrar in front of the academy.",
			at = { npc = "Guide" }, reward = { beli = 100, exp = 30, job = 20 },
		},
		{
			id = "PM4", island = "BastionRock", title = "Posted to Daybreak",
			dialog = SAIL_LINES,
			goal = { kind = "Arrive", target = "Daybreak" }, text = "Reach Daybreak Island",
			hint = SAIL_HINT,
			at = { island = "Daybreak" }, reward = { beli = 200, exp = 50, job = 30, items = { { "TangerineJuice", 3 } } },
		},
	},
	BountyHunter = {
		{
			id = "PB1", island = "SmugglersHollow", title = "Fresh Paper", speaker = "Bounty Board",
			dialog = { "WANTED: Ragmaw, Bandit Chief of Daybreak. 200 Doubloons. Last seen on the windmill hill.", "Under it, scrawled in charcoal: 'New in town? Ask Old Gaff on the wharf about small jobs. Small jobs pay rent.'" },
			goal = { kind = "Talk", target = "BossBoard" }, text = "Read the Bounty Board",
			hint = "The Bounty Board stands by the wanted wall. Walk up and press E.",
			at = { npc = "BossBoard" }, reward = { beli = 100, exp = 20, job = 10 },
		},
		{
			id = "PB2", island = "SmugglersHollow", title = "Rats on the Wharf",
			dialog = { "Old Gaff. You want work? Dock Rats cut purses all along the wharf and the bar is losing customers.", "Thin them out and I'll pay. Watch their blades: hold F to block." },
			goal = { kind = "Kill", target = "DockRat", count = 5 }, text = "Defeat Dock Rats",
			hint = "The Dock Rats loiter at the far end of the wharf town. Click to attack, hold F to block.",
			at = { spawn = "DockRat" }, reward = { beli = 150, exp = 60, job = 40, items = { { "MeatOnBone", 3 } } },
		},
		{
			id = "PB3", island = "SmugglersHollow", title = "Small Jobs Pay Rent",
			dialog = { "Here's your pay. Now, that Ragmaw poster: you're not ready for him. Not yet.", "Go to Daybreak. Rowan trains every greenhorn in these waters, and Ragmaw's hill is right behind his village." },
			goal = { kind = "Talk", target = "Guide" }, text = "Collect your pay from Old Gaff",
			hint = "Old Gaff waits on the wharf street in front of the cave.",
			at = { npc = "Guide" }, reward = { beli = 100, exp = 30, job = 20 },
		},
		{
			id = "PB4", island = "SmugglersHollow", title = "The Hunt Begins",
			dialog = SAIL_LINES,
			goal = { kind = "Arrive", target = "Daybreak" }, text = "Reach Daybreak Island",
			hint = SAIL_HINT,
			at = { island = "Daybreak" }, reward = { beli = 200, exp = 50, job = 30, items = { { "TangerineJuice", 3 } } },
		},
	},
	Outlaw = {
		{
			id = "PO1", island = "ShackleReef", title = "Out of the Hulk",
			dialog = { "Another one walked out of that wreck? Ha! Name's Rattle Jack. The storm cracked the hulk open, and half the cells with it.", "Sit by the fire. Then we talk about staying free." },
			goal = { kind = "Talk", target = "Guide" }, text = "Talk to Rattle Jack",
			hint = "Rattle Jack sits at the escapees' camp by the fire. Walk up and press E.",
			at = { npc = "Guide" }, reward = { beli = 100, exp = 20, job = 10 },
		},
		{
			id = "PO2", island = "ShackleReef", title = "The Jailers Still Walk",
			dialog = { "The Hulk Jailers lived through the wreck and they still count heads. They come for us at night.", "Push them back to their hulk. They hit hard: hold F to block, and tap it right before a blow to parry." },
			goal = { kind = "Kill", target = "HulkJailer", count = 5 }, text = "Defeat Hulk Jailers",
			hint = "The jailers guard the wrecked hulk on the rocky shore. Click to attack, hold F to block.",
			at = { spawn = "HulkJailer" }, reward = { beli = 150, exp = 60, job = 40, items = { { "MeatOnBone", 3 } } },
		},
		{
			id = "PO3", island = "ShackleReef", title = "A Price on Your Head",
			dialog = { "You did it. But your face is on a poster now, and the Marines will sail by sooner or later.", "Go to Daybreak. Old Rowan there asks no questions, and he'll make a sailor of you." },
			goal = { kind = "Talk", target = "Guide" }, text = "Report to Rattle Jack",
			hint = "Back to the camp fire.",
			at = { npc = "Guide" }, reward = { beli = 100, exp = 30, job = 20 },
		},
		{
			id = "PO4", island = "ShackleReef", title = "Slip Away",
			dialog = SAIL_LINES,
			goal = { kind = "Arrive", target = "Daybreak" }, text = "Reach Daybreak Island",
			hint = SAIL_HINT,
			at = { island = "Daybreak" }, reward = { beli = 200, exp = 50, job = 30, items = { { "TangerineJuice", 3 } } },
		},
	},
	RelicSeeker = {
		{
			id = "PR1", island = "InkwellIsle", title = "Overdue", speaker = "Librarian",
			dialog = { "Shh! You're the one who borrowed the old sea map? It came back with pages missing.", "Sage Quill is down by the garden path. He'll want to hear about this." },
			goal = { kind = "Talk", target = "Shop" }, text = "Talk to the Librarian",
			hint = "The Librarian stands inside the library on the hill. Walk into the ring in front of the counter.",
			at = { npc = "Shop" }, reward = { beli = 100, exp = 20, job = 10 },
		},
		{
			id = "PR2", island = "InkwellIsle", title = "Torn Pages",
			dialog = { "Sage Quill. The missing pages were torn out by Tomb Robbers, the ones digging in the old ruins beyond the library hill.", "Get them back. They fight dirty: hold F to block." },
			goal = { kind = "Kill", target = "TombRobber", count = 5 }, text = "Defeat Tomb Robbers",
			hint = "The ruins are beyond the library hill. Click to attack, hold F to block.",
			at = { spawn = "TombRobber" }, reward = { beli = 150, exp = 60, job = 40, items = { { "MeatOnBone", 3 } } },
		},
		{
			id = "PR3", island = "InkwellIsle", title = "Under Daybreak",
			dialog = { "Look: with the pages back, the map lines up. The ruins lie under Daybreak Island!", "Rowan lives there. He knows every cave on that island. Go, and write to me." },
			goal = { kind = "Talk", target = "Guide" }, text = "Bring the pages to Sage Quill",
			hint = "Sage Quill waits by the path below the library.",
			at = { npc = "Guide" }, reward = { beli = 100, exp = 30, job = 20 },
		},
		{
			id = "PR4", island = "InkwellIsle", title = "Follow the Map",
			dialog = SAIL_LINES,
			goal = { kind = "Arrive", target = "Daybreak" }, text = "Reach Daybreak Island",
			hint = SAIL_HINT,
			at = { island = "Daybreak" }, reward = { beli = 200, exp = 50, job = 30, items = { { "TangerineJuice", 3 } } },
		},
	},
}

Q.TutorialEnd = 13 -- steps 1..13 are the Daybreak tutorial (skippable)
-- quest save version: v2 inserted T12 (Bay Serpent) before "Next Port: Conch Bay" (QuestService migrates old saves)
Q.SaveVersion = 3 -- v2: Bay Serpent step inserted at 12; v3: Boar Hunt inserted at 10

Q.ById = {}
for i, s in ipairs(Q.Main) do
	s.index = i
	Q.ById[s.id] = s
end
for origin, chain in pairs(Q.Prologue) do
	for i, s in ipairs(chain) do
		s.index = i
		s.prologue = origin
		Q.ById[s.id] = s
	end
end

-- the lines a step's speaker says to this player (Origin-specific greetings on Daybreak)
function Q.DialogFor(step, origin)
	return step and (step.originDialog and origin and step.originDialog[origin] or step.dialog) or nil
end

function Q.SpeakerOf(step)
	return step and (step.speaker or Q.Guide[step.island]) or "Guide"
end

return Q
