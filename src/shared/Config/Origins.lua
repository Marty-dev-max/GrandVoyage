-- Origins + starting weapons (remake R2, docs/Plan-Remake.md sec 6). Picked once when a character is created
-- (title menu: look -> ORIGIN -> WEAPON), saved as p.origin. Every Origin starts on Daybreak for now, each at its
-- own spot beside an NPC (`npc` role, `npcTitle` to pick one when an island has several); their own home islands
-- come with the world update (R5). Perks are plain numbers read by Origins.Mult (server: PlayerService.GiveExp,
-- MonsterService drops, ChestService, CombatService damage).
local O = {}

O.Order = { "Castaway", "MarineCadet", "BountyHunter", "Outlaw", "RelicSeeker" }
O.List = {
	Castaway = {
		name = "Castaway",
		icon = "compass",
		color = Color3.fromRGB(120, 200, 140),
		story = "Washed up on Daybreak with nothing but the clothes on your back.",
		perk = "Free path: join the Marines or the pirates whenever you like",
		limit = "No starting bonus",
		island = "Daybreak",
		npc = nil, -- the island spawn (camp fire)
	},
	MarineCadet = {
		name = "Marine Cadet",
		icon = "anchor",
		color = Color3.fromRGB(110, 160, 240),
		story = "Fresh out of the academy and posted to the Daybreak harbor.",
		perk = "Starts in the Marines: salary by rank + a Seastone Bracer to arrest pirates",
		limit = "Marine ships and Marines are your side: you can never attack them",
		island = "Daybreak",
		npc = "FastTravel", -- the harbor post
		faction = "Marine",
		kit = { { "SeastoneBracer", 1 } },
	},
	BountyHunter = {
		name = "Bounty Hunter",
		icon = "skull",
		color = Color3.fromRGB(240, 190, 80),
		story = "You came for the posters on the Bounty Board. Big heads pay big.",
		perk = "Bosses give +30% EXP and Doubloons",
		limit = "Regular monsters give 20% less EXP",
		island = "Daybreak",
		npc = "BossBoard",
		mult = { bossExp = 1.3, bossBeli = 1.3, mobExp = 0.8 },
	},
	Outlaw = {
		name = "Outlaw",
		icon = "flag",
		color = Color3.fromRGB(230, 90, 80),
		story = "You broke out of a prison ship and hid in the Daybreak tavern.",
		perk = "+20% EXP and Doubloons from humanoid enemies",
		limit = "Starts as a pirate with a bounty: Marines can arrest you",
		island = "Daybreak",
		npc = "Tavern",
		faction = "Pirate",
		bounty = 5000,
		mult = { humanExp = 1.2, humanBeli = 1.2 },
	},
	RelicSeeker = {
		name = "Relic Seeker",
		icon = "book",
		color = Color3.fromRGB(190, 140, 240),
		story = "An old map led you to the ruins said to lie under these islands.",
		perk = "Chests and dungeons give +30% EXP and Doubloons",
		limit = "Deals 10% less damage until Lv.20",
		island = "Daybreak",
		npc = "Shop", -- 0.1.10: no Job Master any more; the General Store keeper sells maps of the ruins
		mult = { chestExp = 1.3, chestBeli = 1.3, damage = 0.9, damageUntil = 20 },
	},
}
for id, o in pairs(O.List) do
	o.id = id
end
O.Default = "Castaway"

-- starting weapons: anyone can pick any of them (remake: no class locks). `item` = the Plain grade of that line.
O.WeaponOrder = { "Fists", "Kicks", "Katana", "Musket", "Hammer", "Powders" }
O.Weapons = {
	Fists = { name = "Fists", item = "Knuckles_Plain", dtype = "Blunt", stat = "MAR", icon = "w_Knuckles_Plain", desc = "Fast jabs, big finisher" },
	Kicks = { name = "Kicks", item = "Shoes_Plain", dtype = "Blunt", stat = "MAR", icon = "w_Shoes_Plain", desc = "Long reach, heavy kicks" },
	Katana = { name = "Katana", item = "Sword_Plain", dtype = "Slash", stat = "WPN", icon = "w_Sword_Plain", desc = "Balanced blade" },
	Musket = { name = "Musket", item = "Slingshot_Plain", dtype = "Pierce", stat = "WPN", icon = "w_Slingshot_Plain", desc = "Shoots from afar, needs Musket Balls" },
	Hammer = { name = "Hammer", item = "Hammer_Plain", dtype = "Blunt", stat = "WPN", icon = "w_Hammer_Plain", desc = "Slow, crushing blows" },
	Powders = { name = "Powders", item = "MedKit_Plain", dtype = "Element", stat = "WPN", icon = "w_MedKit_Plain", desc = "Thrown medicine dust, hits from range" },
}
O.DefaultWeapon = "Fists"

-- multiplier for one kind of reward / damage: kind = mobExp | bossExp | humanExp | humanBeli | bossBeli | chestExp |
-- chestBeli | damage. level is needed for "damage" (damageUntil).
function O.Mult(originId, kind, level)
	local o = O.List[originId or ""]
	local m = o and o.mult
	if not m or not m[kind] then
		return 1
	end
	if kind == "damage" and m.damageUntil and (level or 1) >= m.damageUntil then
		return 1
	end
	return m[kind]
end

return O
