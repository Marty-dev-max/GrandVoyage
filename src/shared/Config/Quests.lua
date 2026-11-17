-- Main story quests ("Azure East Saga"). One linear chain: the Daybreak tutorial, then a short chapter per island.
--
-- goal.kind:
--   Talk     target = NPC role on the step's island ("Guide", "JobMaster", "Shipwright", "Tavern", "Blacksmith", ...)
--   Kill     target = monster id (nil = any monster), count
--   Skill    use any skill, count
--   Auto     switch Auto Battle on
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
--
-- at (where the quest marker points): { npc = role } | { spawn = monsterId } | { island = id } | { sea = true }
-- reward: { beli, exp, job, items = { { id, qty } } }
local Q = {}

Q.Guide = {
	Daybreak = "Old Salt Rowan",
	ConchBay = "Lieutenant Pell",
	Marmalade = "Mayor Biscuit",
	Honeyslope = "Nanny Clove",
	Barracuda = "Head Chef Gusto",
	Mikan = "Granny Rind",
	Epilogue = "Harbor Master Vane",
}

Q.Main = {
	-- ========== Daybreak Island: tutorial ==========
	-- Route: jungle camp (spawn) -> monkey grove -> tiger den -> windmill village (Job Master) -> boar meadow
	--        -> bandit windmill hill -> harbor (Shipwright) -> sea.
	{
		id = "T01", island = "Daybreak", title = "Ahoy, Greenhorn!",
		dialog = { "Easy now, you washed up half-drowned. Name's Rowan. Thirty years at sea, and this jungle camp is where I fish strays out of the surf.", "Want to sail the Azure East? Then you'll need muscle, a crew and a ship. Talk to me and we'll get you started." },
		goal = { kind = "Talk", target = "Guide" }, text = "Talk to Old Salt Rowan",
		hint = "Walk up to the glowing NPC by the campfire and press E (tap Talk on phones).",
		at = { npc = "Guide" }, reward = { beli = 100, exp = 20, job = 10 },
	},
	{
		id = "T02", island = "Daybreak", title = "Monkey Business",
		dialog = { "Forest Monkeys raided my camp and ran off with the supplies. They're in the grove just north of the fire.", "Click a monkey to chase and attack it. Tab picks the nearest one. The white ring is your attack range, the blue ring is how far you look for prey." },
		goal = { kind = "Kill", target = "ForestMonkey", count = 5 }, text = "Defeat Forest Monkeys",
		hint = "Click or tap a monkey. Press Tab to target the nearest.",
		at = { spawn = "ForestMonkey" }, reward = { beli = 150, exp = 60, job = 40, items = { { "MeatOnBone", 5 } } },
	},
	{
		id = "T03", island = "Daybreak", title = "Show Some Technique",
		dialog = { "Swinging wildly won't cut it. Use a skill! Press 1, or tap the first slot on your skill bar." },
		goal = { kind = "Skill", count = 2 }, text = "Use a skill",
		hint = "Press 1-6 or tap a skill slot. Skills cost SP (blue bar).",
		at = { spawn = "ForestMonkey" }, reward = { beli = 100, exp = 40, job = 40 },
	},
	{
		id = "T04", island = "Daybreak", title = "Let the Sea Do the Work",
		dialog = { "A good sailor knows when to let the tide carry him. Switch on Auto Battle with T, or the big AUTO button.", "You'll fight everything inside the blue ring, use ticked skills and eat when you're hurt." },
		goal = { kind = "Auto" }, text = "Turn on Auto Battle",
		hint = "Press T or tap AUTO.",
		at = { spawn = "JungleTiger" }, reward = { beli = 100, exp = 30, job = 20 },
	},
	{
		id = "T05", island = "Daybreak", title = "Stripes in the Grass",
		dialog = { "Jungle Tigers prowl the den south of camp, down by the old stones. Bigger than monkeys, so let Auto Battle and your skills share the work." },
		goal = { kind = "Kill", target = "JungleTiger", count = 6 }, text = "Defeat Jungle Tigers",
		hint = "Follow the path south of the camp to the Tiger Den. Stand near the tigers with Auto Battle on.",
		at = { spawn = "JungleTiger" }, reward = { beli = 200, exp = 120, job = 80, items = { { "Bandana", 1 } } },
	},
	{
		id = "T06", island = "Daybreak", title = "Train Your Body",
		dialog = { "You've earned stat points. STR hits harder, AGI attacks faster, VIT keeps you alive, DEX lands hits, LUK finds treasure.", "Open Stats with C (or the STATS tile) and spend a few." },
		goal = { kind = "Stat", count = 3 }, text = "Spend stat points",
		hint = "Press C, then +1 next to a stat.",
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
		id = "T08", island = "Daybreak", title = "Boar Hunt",
		dialog = { "Wild Boars trample the farm meadow south of the village. Hunt them until you reach Job Lv.10, then the Job Master in the plaza will take you seriously.", "Your fists are a Brawler's best friend. Learn new skills with K whenever you have skill points." },
		goal = { kind = "JobLevel", count = 10 }, text = "Reach Job Lv.10",
		hint = "Fight Wild Boars in the south meadow. Your Job EXP is the right half of the level ring.",
		at = { spawn = "WildBoar" }, reward = { beli = 300, exp = 150, items = { { "TangerineJuice", 5 } } },
	},
	{
		id = "T09", island = "Daybreak", title = "Find Your Calling",
		dialog = { "Job Lv.10! Go see the Job Master by the fountain. Swordsman, Sharpshooter, Sea Cook, Navigator, Doctor or Shipwright... or stay a Brawler. Every crew needs all of them.", "Don't worry about choosing wrong: each class keeps its own progress, and you can switch back later." },
		goal = { kind = "Talk", target = "JobMaster" }, text = "Visit the Job Master",
		hint = "The Job Master stands in the village plaza. Pick a new class, or keep punching as a Brawler.",
		at = { npc = "JobMaster" }, reward = { beli = 500, exp = 200, job = 100 },
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
		id = "T12", island = "Daybreak", title = "Next Port: Conch Bay",
		dialog = { "Sail east, follow the yellow dots and stay in the windy lane. The dark, still water at the edges is the Doldrums: no wind, and Leviathans." },
		goal = { kind = "Reach", target = "ConchBay" }, text = "Sail to Conch Bay",
		hint = "Follow the dotted line east. Dock with E near the pier.",
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
		dialog = { "One ship, two cannons, one crewman? Each cannon needs a hand to fire. Hire crew at the Tavern." },
		goal = { kind = "Hire" }, text = "Hire crew at the Tavern",
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
		dialog = { "Last job: the riflemen on the south wall are getting trigger-happy." },
		goal = { kind = "Kill", target = "MarineRifleman", count = 10 }, text = "Defeat Marine Riflemen",
		at = { spawn = "MarineRifleman" }, reward = { beli = 1200, exp = 2200, job = 1100 },
	},
	{
		id = "C07", island = "ConchBay", title = "Circus Lights",
		dialog = { "Word is a circus gang took over Marmalade Town to the east. Go see what's happening." },
		goal = { kind = "Reach", target = "Marmalade" }, text = "Sail to Marmalade Town",
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
		dialog = { "Thank you, sailor! Further east there's a quiet village on a hill. Too quiet, some say." },
		goal = { kind = "Reach", target = "Honeyslope" }, text = "Sail to Honeyslope Village",
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
		dialog = { "The claw-cats guard the north cliffs. Be careful." },
		goal = { kind = "Kill", target = "ClawCat", count = 8 }, text = "Defeat Claw Cats",
		at = { spawn = "ClawCat" }, reward = { beli = 4000, exp = 20000, job = 10000, items = { { "TidecoreShard", 2 } } },
	},
	{
		id = "H05", island = "Honeyslope", title = "Smell of Dinner",
		dialog = { "Sailors say there's a restaurant floating out at sea, shaped like a giant fish." },
		goal = { kind = "Reach", target = "Barracuda" }, text = "Sail to Barracuda Bistro",
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
		goal = { kind = "Reach", target = "Mikan" }, text = "Sail to the Mikan Isles",
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
		goal = { kind = "Reach", target = "Epilogue" }, text = "Sail to Epilogue Town",
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

Q.TutorialEnd = 12 -- steps 1..12 are the Daybreak tutorial (skippable)

Q.ById = {}
for i, s in ipairs(Q.Main) do
	s.index = i
	Q.ById[s.id] = s
end

return Q
