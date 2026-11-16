-- Daily quests: 3 per player per day (UTC), picked from this pool by level, plus a bonus for finishing all 3.
-- kind matches QuestService.Event kinds (Kill, Sink, Skill, FruitSkill, Refine, Dungeon). target "local" = a monster
-- that lives on an island near your level.
local D = {}

D.Count = 3
D.Pool = {
	{ id = "HuntLocal", kind = "Kill", target = "local", count = 30, text = "Defeat %d %s", icon = "⚔️" },
	{ id = "HuntAny", kind = "Kill", count = 60, text = "Defeat %d monsters", icon = "💀" },
	{ id = "Skills", kind = "Skill", count = 40, text = "Use skills %d times", icon = "✨" },
	{ id = "Sink", kind = "Sink", count = 3, minLevel = 10, text = "Sink %d NPC ships", icon = "💥" },
	{ id = "Refine", kind = "Refine", count = 3, minLevel = 15, text = "Refine gear %d times", icon = "🔨" },
	{ id = "FruitSkills", kind = "FruitSkill", count = 30, needsFruit = true, text = "Use fruit skills %d times", icon = "🍎" },
	{ id = "Dungeon", kind = "Dungeon", count = 1, minLevel = 22, text = "Clear a dungeon", icon = "🏰" },
}

-- Rewards per daily (L = Base Lv)
D.Reward = {
	beliPerLevel = 300, -- Doubloons = beliPerLevel x L^0.85
	expPct = 0.10, -- of the EXP needed for your next level
	pearls = 10,
}
-- Bonus for claiming all 3
D.Bonus = { pearls = 25, items = { { "SeaBait", 3 } } }

return D
