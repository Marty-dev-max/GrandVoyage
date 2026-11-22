-- Monsters: field mobs, bosses (MVP), dungeon bosses and Leviathans
-- style.shape: crab | monkey | boar | humanoid | wolf | lion | cat | fishman | seaking | snail
-- drops: { item, chance(0-1), min, max }
-- card: card drop (low rate, Ragnarok-style)
local M = {}

local function mob(id, def)
	def.id = id
	def.aggro = def.aggro or false
	def.attackRange = def.attackRange or 7
	def.moveSpeed = def.moveSpeed or 14
	def.attackSpeed = def.attackSpeed or 1.6
	def.cardChance = def.cardChance or 0.002
	def.card = def.card or (id .. "Card")
	def.respawn = def.respawn or 8
	-- Regular mobs use 60% of listed HP for a snappier farming pace (bosses unchanged)
	if not def.isBoss and not def.isLeviathan then
		def.hp = math.floor(def.hp * 0.6)
	end
	M[id] = def
end

-- Daybreak Island (1-10)
-- Story order from the jungle camp: Forest Monkey (1) -> Jungle Tiger (4) -> Wild Boar (6) -> Mountain Bandit (8)
mob("ForestMonkey", { name = "Forest Monkey", level = 1, hp = 60, atk = 8, def = 2, exp = 12, jobExp = 8, beli = { 5, 12 },
	style = { shape = "monkey", color = Color3.fromRGB(170, 110, 70), scale = 1 },
	-- monkeys hoard shells stolen from the shore (Crab Shell is the Hermit companion's evolution material)
	drops = { { "MonkeyFur", 0.6, 1, 2 }, { "CrabShell", 0.2, 1, 1 }, { "MeatOnBone", 0.15, 1, 1 }, { "Bandana", 0.02, 1, 1 } } })
mob("JungleTiger", { name = "Jungle Tiger", level = 4, hp = 150, atk = 17, def = 4, exp = 32, jobExp = 22, beli = { 10, 25 },
	style = { shape = "cat", color = Color3.fromRGB(250, 160, 60), scale = 1.1 }, moveSpeed = 16,
	drops = { { "TigerPelt", 0.5, 1, 2 }, { "MeatOnBone", 0.2, 1, 1 } } })
mob("WildBoar", { name = "Wild Boar", level = 6, hp = 230, atk = 24, def = 8, exp = 50, jobExp = 34, beli = { 15, 35 },
	style = { shape = "boar", color = Color3.fromRGB(140, 95, 75), scale = 1.2 }, -- not aggressive (v0.25.4: new players got mobbed)
	drops = { { "BoarTusk", 0.5, 1, 2 }, { "MeatOnBone", 0.3, 1, 2 } } })
mob("MountainBandit", { name = "Mountain Bandit", level = 8, hp = 320, atk = 32, def = 10, exp = 75, jobExp = 50, beli = { 30, 60 },
	style = { shape = "humanoid", color = Color3.fromRGB(120, 100, 80), scale = 1, hat = "bandana" }, aggro = true, aggroRadius = 14,
	drops = { { "Sword_Plain", 0.03, 1, 1 }, { "SteelOre", 0.08, 1, 1 }, { "BeardDark", 0.01, 1, 1 } } })

-- Conch Bay (10-20)
mob("MarineRecruit", { name = "Rogue Marine Recruit", level = 12, hp = 520, atk = 42, def = 14, exp = 120, jobExp = 80, beli = { 40, 80 },
	style = { shape = "humanoid", color = Color3.fromRGB(240, 240, 255), scale = 1, hat = "marine" },
	drops = { { "MarineBadge", 0.4, 1, 2 }, { "MarineCap", 0.01, 1, 1 } } })
mob("GuardWolf", { name = "Guard Wolf", level = 14, hp = 600, atk = 52, def = 12, exp = 150, jobExp = 100, beli = { 30, 70 },
	style = { shape = "wolf", color = Color3.fromRGB(150, 150, 165), scale = 1.2 }, aggro = true, moveSpeed = 18,
	drops = { { "MeatOnBone", 0.3, 1, 2 }, { "SteelOre", 0.1, 1, 1 } } })
mob("MarineRifleman", { name = "Rogue Rifleman", level = 17, hp = 700, atk = 60, def = 16, exp = 190, jobExp = 130, beli = { 50, 100 },
	style = { shape = "humanoid", color = Color3.fromRGB(220, 230, 255), scale = 1, hat = "marine" }, attackRange = 30, aggro = true,
	drops = { { "Gunpowder", 0.3, 1, 2 }, { "Slingshot_Keen", 0.005, 1, 1 } } })

-- Marmalade Town (20-30)
mob("ClownGrunt", { name = "Clown Pirate Grunt", level = 21, hp = 950, atk = 76, def = 20, exp = 260, jobExp = 180, beli = { 60, 120 },
	style = { shape = "humanoid", color = Color3.fromRGB(255, 120, 120), scale = 1, hat = "clown" },
	drops = { { "ClownPaint", 0.4, 1, 2 }, { "ClownNose", 0.01, 1, 1 }, { "ClownWig", 0.008, 1, 1 } } })
mob("CircusAcrobat", { name = "Circus Acrobat", level = 24, hp = 1050, atk = 88, def = 18, exp = 300, jobExp = 210, beli = { 70, 140 },
	style = { shape = "humanoid", color = Color3.fromRGB(255, 200, 80), scale = 0.95, hat = "clown" }, aggro = true, moveSpeed = 20,
	drops = { { "ClownPaint", 0.3, 1, 2 }, { "Shoes_Keen", 0.006, 1, 1 }, { "ClownWig", 0.008, 1, 1 } } })
mob("CircusLion", { name = "Circus Lion", level = 27, hp = 1500, atk = 105, def = 26, exp = 420, jobExp = 290, beli = { 90, 160 },
	style = { shape = "lion", color = Color3.fromRGB(240, 180, 80), scale = 1.5 }, aggro = true,
	drops = { { "MeatOnBone", 0.5, 2, 3 }, { "TidecoreShard", 0.01, 1, 1 } } })

-- Honeyslope Village (30-40)
mob("NightCatPirate", { name = "Night Cat Pirate", level = 31, hp = 1800, atk = 122, def = 30, exp = 520, jobExp = 360, beli = { 100, 200 },
	style = { shape = "humanoid", color = Color3.fromRGB(70, 60, 80), scale = 1, hat = "cat" },
	drops = { { "CatClaw", 0.4, 1, 2 }, { "Sword_Keen", 0.006, 1, 1 }, { "CatEars", 0.006, 1, 1 } } })
mob("HypnoThug", { name = "Hypnotized Thug", level = 34, hp = 2100, atk = 140, def = 34, exp = 600, jobExp = 420, beli = { 110, 210 },
	style = { shape = "humanoid", color = Color3.fromRGB(200, 120, 220), scale = 1.1 }, aggro = true,
	drops = { { "TangerineJuice", 0.3, 1, 2 }, { "StormBaton_Keen", 0.006, 1, 1 }, { "HypnoGoggles", 0.006, 1, 1 } } })
mob("ClawCat", { name = "Claw Cat Brawler", level = 37, hp = 2600, atk = 165, def = 38, exp = 760, jobExp = 530, beli = { 140, 260 },
	style = { shape = "cat", color = Color3.fromRGB(90, 70, 110), scale = 1.3 }, aggro = true, moveSpeed = 22,
	drops = { { "CatClaw", 0.5, 2, 3 }, { "TidecoreShard", 0.02, 1, 1 } } })

-- Barracuda Bistro (40-50)
mob("ArmadaRaider", { name = "Armada Raider", level = 41, hp = 3100, atk = 185, def = 44, exp = 900, jobExp = 630, beli = { 160, 300 },
	style = { shape = "humanoid", color = Color3.fromRGB(150, 150, 160), scale = 1.1, hat = "helmet" },
	drops = { { "ArmorRivet", 0.4, 1, 2 }, { "Hammer_Keen", 0.006, 1, 1 }, { "IronHelmet", 0.006, 1, 1 } } })
mob("StarvedPirate", { name = "Starved Pirate", level = 44, hp = 3300, atk = 200, def = 40, exp = 1000, jobExp = 700, beli = { 170, 320 },
	style = { shape = "humanoid", color = Color3.fromRGB(180, 140, 110), scale = 0.95 }, aggro = true,
	drops = { { "BigFeast", 0.15, 1, 1 }, { "MedKit_Keen", 0.006, 1, 1 }, { "BeardBrown", 0.008, 1, 1 } } })
mob("ArmoredGunner", { name = "Armored Gunner", level = 47, hp = 4000, atk = 225, def = 60, exp = 1200, jobExp = 850, beli = { 200, 380 },
	style = { shape = "humanoid", color = Color3.fromRGB(110, 110, 120), scale = 1.3, hat = "helmet" }, attackRange = 32, aggro = true,
	drops = { { "Gunpowder", 0.5, 1, 3 }, { "IronIngot", 0.3, 1, 2 }, { "CaptainCoat", 0.004, 1, 1 }, { "IronHelmet", 0.006, 1, 1 } } })

-- Mikan Isles (50-60)
mob("SharkfolkBrawler", { name = "Sharkfolk Brawler", level = 52, hp = 5200, atk = 260, def = 62, exp = 1500, jobExp = 1050, beli = { 240, 450 },
	style = { shape = "fishman", color = Color3.fromRGB(90, 170, 220), scale = 1.3 },
	drops = { { "SharkfolkFin", 0.4, 1, 2 }, { "SharkscaleMail", 0.003, 1, 1 } } })
mob("SawfolkRaider", { name = "Sawfolk Raider", level = 55, hp = 5800, atk = 290, def = 66, exp = 1700, jobExp = 1200, beli = { 260, 480 },
	style = { shape = "fishman", color = Color3.fromRGB(110, 120, 200), scale = 1.35 }, aggro = true,
	drops = { { "SharkfolkFin", 0.5, 1, 2 }, { "SharkToothNecklace", 0.004, 1, 1 } } })
mob("OctofolkBrute", { name = "Octofolk Brute", level = 58, hp = 6600, atk = 315, def = 70, exp = 1950, jobExp = 1380, beli = { 280, 520 },
	style = { shape = "fishman", color = Color3.fromRGB(230, 120, 160), scale = 1.4 }, aggro = true,
	drops = { { "SharkfolkFin", 0.5, 1, 3 }, { "TidecoreShard", 0.04, 1, 1 }, { "Sword_Master", 0.002, 1, 1 } } })

-- Epilogue (60-70)
mob("BountyHunter", { name = "Bounty Hunter", level = 61, hp = 7400, atk = 345, def = 76, exp = 2300, jobExp = 1600, beli = { 320, 600 },
	style = { shape = "humanoid", color = Color3.fromRGB(100, 80, 60), scale = 1.1, hat = "bandana" }, aggro = true,
	drops = { { "WantedPoster", 0.4, 1, 2 }, { "Slingshot_Master", 0.002, 1, 1 } } })
mob("MarineElite", { name = "Elite Marine", level = 64, hp = 8200, atk = 370, def = 84, exp = 2600, jobExp = 1800, beli = { 340, 640 },
	style = { shape = "humanoid", color = Color3.fromRGB(255, 255, 255), scale = 1.15, hat = "marine" }, aggro = true,
	drops = { { "MarineBadge", 0.6, 2, 4 }, { "Hammer_Master", 0.002, 1, 1 }, { "PureTidecore", 0.003, 1, 1 } } })
mob("MistSoldier", { name = "Mist Squad Soldier", level = 67, hp = 9000, atk = 400, def = 90, exp = 3000, jobExp = 2100, beli = { 360, 700 },
	style = { shape = "humanoid", color = Color3.fromRGB(200, 200, 210), scale = 1.2, hat = "marine" }, aggro = true,
	drops = { { "TidecoreShard", 0.08, 1, 1 }, { "Shoes_Master", 0.002, 1, 1 }, { "StormBaton_Master", 0.002, 1, 1 } } })

-- ===== Bosses (MVP) =====
local function boss(id, def)
	def.isBoss = true
	def.aggro = true
	def.cardChance = def.cardChance or 0.01
	def.attackRange = def.attackRange or 12
	def.attackSpeed = def.attackSpeed or 2.2
	def.moveSpeed = def.moveSpeed or 16
	mob(id, def)
end
-- v0.22.5: a full-length serpent (head = the monster model, body + tail follow its path: Modules/SerpentChain,
-- Controllers/SerpentBody). Story boss of quest T12, so tuned for one Lv ~10-12 player with care (or a small party).
-- Attacks are telegraphed with red lines/circles on the deck: lunge bite, water spit, tail slam (MonsterService).
boss("BaySerpent", { name = "Bay Serpent", level = 12, hp = 4800, atk = 46, def = 16, exp = 1500, jobExp = 1000, beli = { 2000, 4000 },
	style = { shape = "seaking", color = Color3.fromRGB(70, 140, 120), scale = 2.2 }, attackRange = 22, attackSpeed = 4.2, moveSpeed = 16,
	-- segments overlap a lot (spacing well under the 10.8-stud segment length) so the body reads as one piece (v0.22.8)
	serpent = { segments = 13, spacing = 6.4, shrink = 0.024, radius = 6.6, tailLength = 25 },
	drops = { { "LeviathanScale", 1, 1, 2 }, { "Sword_Keen", 0.15, 1, 1 }, { "SunHat", 0.2, 1, 1 } } })
boss("AxeCaptain", { name = "Axe-Arm Captain", level = 22, hp = 22000, atk = 120, def = 40, exp = 4500, jobExp = 3000, beli = { 5000, 9000 },
	style = { shape = "humanoid", color = Color3.fromRGB(240, 240, 250), scale = 2.2, hat = "marine" },
	drops = { { "MarineCoat", 0.3, 1, 1 }, { "Hammer_Keen", 0.2, 1, 1 }, { "TidecoreShard", 0.5, 1, 2 }, { "CapeNavy", 0.1, 1, 1 }, { "BeardBrown", 0.15, 1, 1 } } })
boss("CaptainConfetti", { name = "Captain Confetti", level = 32, hp = 42000, atk = 190, def = 50, exp = 9000, jobExp = 6000, beli = { 9000, 15000 },
	style = { shape = "humanoid", color = Color3.fromRGB(255, 80, 80), scale = 2.1, hat = "clown" },
	drops = { { "ClownNose", 0.4, 1, 1 }, { "Shoes_Master", 0.05, 1, 1 }, { "TidecoreShard", 0.6, 1, 3 }, { "ConfettiWig", 0.15, 1, 1 }, { "CapePurple", 0.1, 1, 1 } } })
boss("SilentClaw", { name = "Silent Claw Captain", level = 42, hp = 70000, atk = 270, def = 64, exp = 16000, jobExp = 11000, beli = { 14000, 22000 },
	style = { shape = "humanoid", color = Color3.fromRGB(60, 50, 70), scale = 2.2, hat = "cat" }, moveSpeed = 26,
	drops = { { "Sword_Master", 0.05, 1, 1 }, { "TangerinePin", 0.3, 1, 1 }, { "TidecoreShard", 0.8, 2, 3 }, { "GlowVisor", 0.12, 1, 1 }, { "CapeShadow", 0.1, 1, 1 } } })
boss("ArmadaAdmiral", { name = "Iron Armada Admiral", level = 52, hp = 115000, atk = 360, def = 95, exp = 26000, jobExp = 18000, beli = { 22000, 35000 },
	style = { shape = "humanoid", color = Color3.fromRGB(230, 190, 60), scale = 2.5, hat = "helmet" }, attackRange = 30,
	drops = { { "CaptainCoat", 0.3, 1, 1 }, { "Hammer_Master", 0.06, 1, 1 }, { "PureTidecore", 0.05, 1, 1 }, { "AdmiralCrown", 0.08, 1, 1 }, { "CapeCrimson", 0.08, 1, 1 } } })
boss("SawtoothOverlord", { name = "Sawtooth Overlord", level = 62, hp = 170000, atk = 450, def = 110, exp = 40000, jobExp = 28000, beli = { 30000, 50000 },
	style = { shape = "fishman", color = Color3.fromRGB(90, 120, 210), scale = 2.6 },
	drops = { { "SharkToothNecklace", 0.4, 1, 1 }, { "Sword_Grand", 0.01, 1, 1 }, { "PureTidecore", 0.1, 1, 1 }, { "CapeShadow", 0.08, 1, 1 } } })
boss("MistCommodore", { name = "Mist Commodore", level = 72, hp = 260000, atk = 540, def = 130, exp = 60000, jobExp = 42000, beli = { 45000, 70000 },
	style = { shape = "humanoid", color = Color3.fromRGB(235, 235, 245), scale = 2.4, hat = "marine" }, attackRange = 20,
	drops = { { "StormBaton_Grand", 0.01, 1, 1 }, { "Slingshot_Grand", 0.01, 1, 1 }, { "PureTidecore", 0.15, 1, 2 }, { "TreasureWood", 0.2, 1, 1 }, { "CapeSlate", 0.08, 1, 1 }, { "BeardGrey", 0.1, 1, 1 } } })

-- ===== Dungeon bosses =====
boss("RingMaster", { name = "Circus Ringmaster", level = 30, hp = 30000, atk = 170, def = 45, exp = 6000, jobExp = 4000, beli = { 6000, 9000 },
	style = { shape = "humanoid", color = Color3.fromRGB(200, 60, 160), scale = 2, hat = "clown" },
	drops = { { "Shoes_Keen", 0.3, 1, 1 }, { "TidecoreShard", 0.6, 1, 2 }, { "RingmasterHat", 0.15, 1, 1 }, { "CapeGold", 0.1, 1, 1 } } })
boss("DepthsWarden", { name = "Depths Warden", level = 58, hp = 140000, atk = 420, def = 100, exp = 32000, jobExp = 22000, beli = { 25000, 38000 },
	style = { shape = "fishman", color = Color3.fromRGB(40, 90, 150), scale = 2.6 },
	drops = { { "SharkscaleMail", 0.3, 1, 1 }, { "PureTidecore", 0.15, 1, 1 }, { "CapeSlate", 0.08, 1, 1 } } })

-- ===== Leviathans (Doldrums) =====
mob("Leviathan", { name = "Leviathan", level = 99, hp = 60000, atk = 900, def = 200, exp = 9000, jobExp = 5000, beli = { 3000, 6000 },
	style = { shape = "seaking", color = Color3.fromRGB(120, 60, 160), scale = 3 }, aggro = true, isLeviathan = true, cardChance = 0.005,
	drops = { { "LeviathanScale", 0.8, 1, 3 }, { "TreasureWood", 0.05, 1, 1 } } })

-- ===== Guild War core (Giant Signal Conch) =====
mob("FortCore", { name = "Giant Signal Conch", level = 80, hp = 60000, atk = 0, def = 60, exp = 0, jobExp = 0,
	style = { shape = "snail", color = Color3.fromRGB(120, 200, 120), scale = 3 }, static = true, isCore = true, cardChance = 0, card = false, drops = {} })

-- ===== monster types + difficulty stars (v0.25.18, owner) =====
-- Each type has its own fighting style, applied to the definitions below so every system sees the same numbers:
--   STR = raw power, heavy hitter (hits harder, swings slower)  -- like a Brawler
--   AGI = blades and martial precision (more accurate, can crit) -- like a Swordsman
--   DEX = raw speed and reflexes (moves and attacks faster)
--   INT = tactics: stuns / crowd control on hit
--   (v0.25.38: PHY is gone; its two gunners keep their long range below: Rifleman = DEX, Armored Gunner = STR)
local TYPE_OF = {
	STR = { "ArmoredGunner", "WildBoar", "MountainBandit", "CircusLion", "ArmadaRaider", "SharkfolkBrawler", "AxeCaptain", "ArmadaAdmiral", "Leviathan" },
	AGI = { "MarineRecruit", "NightCatPirate", "SawfolkRaider", "MarineElite", "BountyHunter", "SilentClaw", "SawtoothOverlord", "ClawCat" },
	DEX = { "MarineRifleman", "ForestMonkey", "JungleTiger", "GuardWolf", "CircusAcrobat", "StarvedPirate", "BaySerpent", "DepthsWarden" },
	INT = { "ClownGrunt", "HypnoThug", "MistSoldier", "CaptainConfetti", "RingMaster", "MistCommodore", "OctofolkBrute" },
}
-- stars: 1 = plain animals, 2 = regular fighters, 3 = elites, 4 = bosses, 5 = the strongest bosses
local STARS = {
	ForestMonkey = 1, JungleTiger = 1, WildBoar = 1, GuardWolf = 1, CircusLion = 1,
	ClawCat = 3, ArmoredGunner = 3, OctofolkBrute = 3, MarineElite = 3, MistSoldier = 3, BountyHunter = 3,
	MistCommodore = 5, DepthsWarden = 5, Leviathan = 5,
}
local STYLE = {
	STR = { atk = 1.25, attackSpeed = 1.2 },
	AGI = { hitBonus = 0.25, crit = 0.1 },
	DEX = { moveSpeed = 1.25, attackSpeed = 0.8 },
	INT = { stun = 0.15 },
}
local LONG_RANGE = { MarineRifleman = 2.5, ArmoredGunner = 2.5 } -- the gunners shoot from afar whatever their type
for t, ids in pairs(TYPE_OF) do
	for _, id in ipairs(ids) do
		local def = M[id]
		if def then
			def.mtype = t
			local st = STYLE[t]
			def.atk = math.floor(def.atk * (st.atk or 1))
			def.attackSpeed = def.attackSpeed * (st.attackSpeed or 1)
			def.moveSpeed = def.moveSpeed * (st.moveSpeed or 1)
			def.attackRange = def.attackRange * (st.attackRange or 1) * (LONG_RANGE[id] or 1)
			def.hitBonus = st.hitBonus
			def.critChance = st.crit
			def.stunChance = st.stun
		end
	end
end
for id, def in pairs(M) do
	if type(def) == "table" and def.level then
		def.stars = STARS[id] or (def.isBoss and 4 or 2)
	end
end

return M
