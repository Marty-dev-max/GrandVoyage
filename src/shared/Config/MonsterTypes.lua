-- Monster types (v0.25.18, owner): badge kanji + color per type. The fighting styles live in Config/Monsters.
local T = {
	STR = { name = "Strength", kanji = "力", color = Color3.fromRGB(230, 60, 55) },
	AGI = { name = "Agility", kanji = "技", color = Color3.fromRGB(70, 200, 90) },
	DEX = { name = "Dexterity", kanji = "速", color = Color3.fromRGB(60, 140, 240) },
	INT = { name = "Intelligence", kanji = "心", color = Color3.fromRGB(170, 80, 230) },
}

-- v0.25.37 (owner): every class has a type too (Config/Classes mtype). v0.25.38 (owner): four types in a cycle,
-- PHY is gone (it was only toughness, nothing to beat): each type beats one, is weak to one, even with the opposite.
--   AGI beats STR (dodges slow heavy blows) · STR beats INT (casters are frail up close)
--   INT beats DEX (spells hit an area, no aim to dodge) · DEX beats AGI (a precise shot catches the dodger)
-- The attacker deals Bonus x damage to a type it beats, Penalty x to one that beats it (players vs monsters and
-- monsters vs players). Shown on the Job Master as a green (beats) / red (weak to) disc.
T.AGI.beats = { "STR" }
T.STR.beats = { "INT" }
T.INT.beats = { "DEX" }
T.DEX.beats = { "AGI" }
T.Order = { "STR", "AGI", "DEX", "INT" }
T.Bonus, T.Penalty = 1.2, 0.85

function T.Beats(a, b)
	local ta = T[a or ""]
	return ta ~= nil and type(ta) == "table" and ta.beats ~= nil and table.find(ta.beats, b) ~= nil
end
function T.WeakTo(a)
	local out = {}
	for _, id in ipairs(T.Order) do
		if T.Beats(id, a) then
			table.insert(out, id)
		end
	end
	return out
end
-- damage multiplier for an attacker of type a hitting a defender of type b
function T.Mult(a, b)
	return (T.Beats(a, b) and T.Bonus) or (T.Beats(b, a) and T.Penalty) or 1
end

-- self-check: each type beats exactly one and is weak to exactly one
for _, id in ipairs(T.Order) do
	assert(#T[id].beats == 1 and #T.WeakTo(id) == 1, "MonsterTypes cycle broken at " .. id)
end

return T
