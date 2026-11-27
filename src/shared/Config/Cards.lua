-- Cards: dropped by monsters, socketed into equipment slots.
-- slot: weapon | armor | headgear | accessory
-- bonus keys: VIT END WIL WPN MAR FRU (remake attributes) atk matk def mdef hit flee crit maxHp maxSp aspd
--             atkPct defPct hpPct expPct beliPct dmgVsBoss dmgVsSeafolk cannonDamage shipSpeed shipHp
-- rarity (owner's card ladder, stars in Modules/Rarity): Common gray 1 star, Uncommon green 2, Rare blue 3, Epic purple 4,
-- Mythic rainbow prismatic 5. Regular monster cards follow the monster level (CardTier below), MVP boss cards are Epic,
-- captain cards and the Leviathan are Mythic.
local Monsters = require(script.Parent.Monsters)
local C = {}
local function cardTier(monster)
	local m = Monsters[monster]
	local lv = m and m.level or 1
	if lv < 10 then
		return "Common"
	elseif lv < 30 then
		return "Uncommon"
	end
	return "Rare"
end
local function card(monster, slot, bonus, desc, rarity)
	local id = monster .. "Card"
	C[id] = { id = id, monster = monster, slot = slot, bonus = bonus, desc = desc, rarity = rarity or cardTier(monster) }
end

card("ForestMonkey", "accessory", { END = 2, flee = 5 }, "END +2, FLEE +5")
card("JungleTiger", "armor", { WPN = 1, def = 3, maxHp = 50 }, "WPN +1, DEF +3, Max HP +50")
card("WildBoar", "weapon", { WPN = 2, atk = 6 }, "WPN +2, ATK +6")
card("MountainBandit", "weapon", { atk = 10, crit = 2 }, "ATK +10, CRIT +2")
card("BanditChief", "weapon", { WPN = 3, atk = 14 }, "WPN +3, ATK +14", "Rare")
card("SpoiledEnsign", "accessory", { WIL = 4, beliPct = 0.06 }, "WIL +4, Doubloon drops +6%", "Rare")
card("BeastTamer", "armor", { VIT = 3, hpPct = 0.05 }, "VIT +3, Max HP +5%", "Rare")
card("MarineRecruit", "armor", { VIT = 2, defPct = 0.03 }, "VIT +2, DEF +3%")
card("GuardWolf", "accessory", { END = 3, aspd = 0.03 }, "END +3, Attack Speed +3%")
card("MarineRifleman", "weapon", { WPN = 3, hit = 10 }, "WPN +3, HIT +10")
card("ClownGrunt", "headgear", { WIL = 3, beliPct = 0.05 }, "WIL +3, Doubloon drops +5%")
card("CircusAcrobat", "accessory", { END = 4, flee = 10 }, "END +4, FLEE +10")
card("CircusLion", "weapon", { MAR = 4, atkPct = 0.04 }, "MAR +4, ATK +4%")
card("NightCatPirate", "weapon", { crit = 5, atk = 12 }, "CRIT +5, ATK +12")
card("HypnoThug", "headgear", { WIL = 4, maxSp = 60 }, "WIL +4, Max SP +60")
card("ClawCat", "weapon", { aspd = 0.05, MAR = 3 }, "Attack Speed +5%, MAR +3")
card("ArmadaRaider", "armor", { def = 12, VIT = 3 }, "DEF +12, VIT +3")
card("StarvedPirate", "accessory", { maxHp = 400, hpPct = 0.03 }, "Max HP +400, Max HP +3%")
card("ArmoredGunner", "weapon", { cannonDamage = 0.08, WPN = 4 }, "Cannon damage +8%, WPN +4")
card("SharkfolkBrawler", "armor", { MAR = 4, maxHp = 600 }, "MAR +4, Max HP +600")
card("SawfolkRaider", "weapon", { atkPct = 0.06, dmgVsSeafolk = 0.15 }, "ATK +6%, damage vs Seafolk +15%")
card("OctofolkBrute", "accessory", { WPN = 5, aspd = 0.05 }, "WPN +5, Attack Speed +5%")
card("BountyHunter", "weapon", { dmgVsBoss = 0.1, crit = 4 }, "Damage vs bosses +10%, CRIT +4")
card("MarineElite", "armor", { defPct = 0.08, mdef = 6 }, "DEF +8%, MDEF +6")
card("MistSoldier", "headgear", { FRU = 6, matk = 30 }, "FRU +6, MATK +30")
-- Boss cards (MVP)
card("BaySerpent", "armor", { shipHp = 0.15, maxHp = 300 }, "Ship HP +15%, Max HP +300", "Epic")
card("AxeCaptain", "weapon", { atkPct = 0.1, WPN = 5 }, "ATK +10%, WPN +5", "Epic")
card("CaptainConfetti", "headgear", { WIL = 10, crit = 8, beliPct = 0.1 }, "WIL +10, CRIT +8, Doubloons +10%", "Epic")
card("SilentClaw", "weapon", { aspd = 0.12, MAR = 8 }, "Attack Speed +12%, MAR +8", "Epic")
card("ArmadaAdmiral", "armor", { defPct = 0.15, def = 30 }, "DEF +15%, DEF +30", "Epic")
card("SawtoothOverlord", "weapon", { atkPct = 0.15, dmgVsSeafolk = 0.25 }, "ATK +15%, damage vs Seafolk +25%", "Epic")
card("MistCommodore", "accessory", { shipSpeed = 0.1, flee = 30, FRU = 8 }, "Ship speed +10%, FLEE +30, FRU +8", "Epic")
card("RingMaster", "accessory", { expPct = 0.1, WIL = 5 }, "EXP +10%, WIL +5", "Epic")
card("DepthsWarden", "armor", { hpPct = 0.12, mdef = 15 }, "Max HP +12%, MDEF +15", "Epic")
card("Leviathan", "weapon", { atkPct = 0.12, shipHp = 0.1 }, "ATK +12%, Ship HP +10%", "Mythic")
-- Captain cards from tier-3 NPC ships
card("MarineCaptain", "armor", { shipHp = 0.12, VIT = 5 }, "Ship HP +12%, VIT +5", "Mythic")
card("PirateCaptain", "weapon", { cannonDamage = 0.15, WIL = 5 }, "Cannon damage +15%, WIL +5", "Mythic")

return C
