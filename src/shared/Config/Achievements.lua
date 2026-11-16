-- Achievements: one-time goals that pay Pearls (bounded, so they skip the daily Pearl cap) and can unlock a title
-- shown above your head. counter = counts events (QuestService.Event kinds, "Kill:<monster>" for one monster);
-- state = checked from your profile.
local A = {}

A.List = {
	-- hunting
	{ id = "Hunter1", name = "First Blood", desc = "Defeat 100 monsters", counter = "Kill", count = 100, pearls = 10, icon = "⚔️" },
	{ id = "Hunter2", name = "Veteran Hunter", desc = "Defeat 1,000 monsters", counter = "Kill", count = 1000, pearls = 30, icon = "⚔️", title = "Veteran Hunter" },
	{ id = "Hunter3", name = "Legendary Hunter", desc = "Defeat 10,000 monsters", counter = "Kill", count = 10000, pearls = 100, icon = "⚔️", title = "Legendary Hunter", rarity = "Legendary" },
	{ id = "Crabs", name = "Crab Crusher", desc = "Defeat 200 Beach Crabs", counter = "Kill:BeachCrab", count = 200, pearls = 10, icon = "🦀", title = "Crab Crusher" },
	{ id = "Boss1", name = "MVP!", desc = "Win an MVP boss fight", counter = "Boss", count = 1, pearls = 20, icon = "👑" },
	{ id = "Boss2", name = "Boss Slayer", desc = "Win 25 MVP boss fights", counter = "Boss", count = 25, pearls = 80, icon = "👑", title = "Boss Slayer", rarity = "Epic" },
	-- sea
	{ id = "Sink1", name = "Cannon Fodder", desc = "Sink 10 NPC ships", counter = "Sink", count = 10, pearls = 15, icon = "💥" },
	{ id = "Sink2", name = "Terror of the Seas", desc = "Sink 200 NPC ships", counter = "Sink", count = 200, pearls = 80, icon = "💥", title = "Terror of the Seas", rarity = "Epic" },
	{ id = "Explorer", name = "Explorer", desc = "Discover every island of the Azure East", state = "islands", count = 7, pearls = 40, icon = "🧭", title = "Explorer" },
	{ id = "Chests1", name = "Treasure Hunter", desc = "Open 10 exploration chests", state = "chests", count = 10, pearls = 15, icon = "🧰" },
	{ id = "Chests2", name = "Every Last Chest", desc = "Open 40 exploration chests", state = "chests", count = 40, pearls = 60, icon = "🧰", title = "Treasure Hunter", rarity = "Epic" },
	-- powers and companions
	{ id = "Fruit1", name = "Cursed!", desc = "Eat a Cursed Fruit", state = "fruit", count = 1, pearls = 15, icon = "🍎" },
	{ id = "Fruit2", name = "Fruit Master", desc = "Reach Fruit Mastery 100", state = "mastery", count = 100, pearls = 80, icon = "🍎", title = "Fruit Master", rarity = "Legendary" },
	{ id = "Pet1", name = "New Friend", desc = "Get your first companion", state = "pets", count = 1, pearls = 10, icon = "🐾" },
	{ id = "Pet2", name = "Menagerie", desc = "Own 10 companions", state = "pets", count = 10, pearls = 40, icon = "🐾", title = "Beast Tamer" },
	{ id = "Pet3", name = "Full Evolution", desc = "Evolve a companion to its final stage", state = "petStage", count = 3, pearls = 40, icon = "🐾" },
	{ id = "Refine1", name = "Blacksmith's Friend", desc = "Refine gear 30 times", counter = "Refine", count = 30, pearls = 20, icon = "🔨" },
	-- progress
	{ id = "Tutorial", name = "Set Sail", desc = "Finish the Daybreak tutorial", state = "tutorial", count = 1, pearls = 10, icon = "⛵" },
	{ id = "Story", name = "Azure East Legend", desc = "Finish the Azure East story", state = "story", count = 1, pearls = 100, icon = "📜", title = "Legend of the Azure East", rarity = "Legendary" },
	{ id = "Level30", name = "Seasoned Sailor", desc = "Reach Base Lv.30", state = "level", count = 30, pearls = 20, icon = "⭐" },
	{ id = "Level70", name = "Ready for the Wall", desc = "Reach Base Lv.70", state = "level", count = 70, pearls = 60, icon = "⭐", title = "Wall Climber", rarity = "Epic" },
	{ id = "Daily7", name = "Creature of Habit", desc = "Finish all dailies on 7 days", counter = "DailyAll", count = 7, pearls = 40, icon = "📅", title = "Ever Faithful" },
	{ id = "Rich", name = "Treasure Hoard", desc = "Hold 1,000,000 Doubloons", state = "beli", count = 1000000, pearls = 30, icon = "🪙", title = "Tycoon" },
}

A.ById = {}
for _, a in ipairs(A.List) do
	A.ById[a.id] = a
end

return A
