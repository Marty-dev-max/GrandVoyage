-- Rarity: tier colors shared by items, cards, enemies, ships and UI.
-- Each tier has a solid color, a two-stop gradient for card backgrounds, and a glow color.
-- "Mythic" is rainbow prismatic (bright pastel rainbow that shimmers), "Secret" a dark face with a rainbow rim;
-- both are animated by the client UIKit. Cards show stars by tier (Rarity.Stars): owner's ladder (v0.22.2)
-- Common gray 1, Uncommon green 2, Rare blue 3, Epic purple 4, Mythic rainbow prismatic 5.
local Rarity = {}

Rarity.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

Rarity.Tiers = {
	Common = { rank = 1, color = Color3.fromRGB(176, 184, 196), top = Color3.fromRGB(214, 220, 230), bottom = Color3.fromRGB(122, 132, 148) },
	Uncommon = { rank = 2, color = Color3.fromRGB(88, 222, 112), top = Color3.fromRGB(150, 255, 160), bottom = Color3.fromRGB(32, 150, 70) },
	Rare = { rank = 3, color = Color3.fromRGB(62, 156, 255), top = Color3.fromRGB(130, 205, 255), bottom = Color3.fromRGB(28, 82, 210) },
	Epic = { rank = 4, color = Color3.fromRGB(178, 92, 255), top = Color3.fromRGB(222, 160, 255), bottom = Color3.fromRGB(104, 34, 200) },
	Legendary = { rank = 5, color = Color3.fromRGB(255, 196, 38), top = Color3.fromRGB(255, 236, 120), bottom = Color3.fromRGB(230, 120, 10) },
	Mythic = { rank = 6, color = Color3.fromRGB(255, 120, 220), top = Color3.fromRGB(255, 214, 246), bottom = Color3.fromRGB(150, 200, 255), prismatic = true },
	Secret = { rank = 7, color = Color3.fromRGB(250, 250, 255), top = Color3.fromRGB(40, 40, 50), bottom = Color3.fromRGB(10, 10, 16), rainbow = true },
}
for id, t in pairs(Rarity.Tiers) do
	t.id = id
end

-- card stars per tier
Rarity.Stars = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 4, Mythic = 5, Secret = 5 }
function Rarity.StarsOf(id)
	return Rarity.Stars[id or "Common"] or 1
end

function Rarity.Get(id)
	return Rarity.Tiers[id or "Common"] or Rarity.Tiers.Common
end

-- Color for an enemy nameplate based on level difference (readability helper)
function Rarity.LevelColor(playerLevel, enemyLevel)
	local d = enemyLevel - playerLevel
	if d <= -10 then
		return Color3.fromRGB(170, 175, 185) -- trivial
	elseif d <= -3 then
		return Color3.fromRGB(110, 230, 120) -- easy
	elseif d <= 3 then
		return Color3.fromRGB(255, 225, 90) -- even
	elseif d <= 8 then
		return Color3.fromRGB(255, 150, 60) -- hard
	end
	return Color3.fromRGB(255, 70, 80) -- deadly
end

return Rarity
