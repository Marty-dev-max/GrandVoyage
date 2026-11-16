-- Dungeons: instanced per party (a fresh arena is built for each run)
return {
	CircusTent = {
		name = "Big Top Nightmare",
		island = "Marmalade",
		minLevel = 22,
		maxParty = 4,
		timeLimit = 15 * 60,
		cooldown = 30 * 60,
		theme = { floor = Color3.fromRGB(200, 60, 60), wall = Color3.fromRGB(255, 220, 90) },
		waves = {
			{ { "ClownGrunt", 6 } },
			{ { "CircusAcrobat", 5 }, { "ClownGrunt", 3 } },
			{ { "CircusLion", 4 }, { "CircusAcrobat", 3 } },
		},
		boss = "RingMaster",
		reward = { beli = 8000, exp = 9000, items = { { "TidecoreShard", 1, 1, 2 }, { "RefineGuard", 0.05, 1, 1 } } },
	},
	SawtoothDepths = {
		name = "Sawtooth Depths",
		island = "Mikan",
		minLevel = 52,
		maxParty = 4,
		timeLimit = 20 * 60,
		cooldown = 45 * 60,
		theme = { floor = Color3.fromRGB(40, 80, 110), wall = Color3.fromRGB(70, 150, 170) },
		waves = {
			{ { "SharkfolkBrawler", 6 } },
			{ { "SawfolkRaider", 5 }, { "SharkfolkBrawler", 3 } },
			{ { "OctofolkBrute", 5 }, { "SawfolkRaider", 3 } },
		},
		boss = "DepthsWarden",
		reward = { beli = 40000, exp = 50000, items = { { "PureTidecore", 0.3, 1, 1 }, { "RefineGuard", 0.15, 1, 1 } } },
	},
}
