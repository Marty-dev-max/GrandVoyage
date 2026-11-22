-- Monster types (v0.25.18, owner): badge kanji + color per type. The fighting styles live in Config/Monsters.
local T = {
	STR = { name = "Strength", kanji = "力", color = Color3.fromRGB(230, 60, 55) },
	AGI = { name = "Agility", kanji = "技", color = Color3.fromRGB(70, 200, 90) },
	DEX = { name = "Dexterity", kanji = "速", color = Color3.fromRGB(60, 140, 240) },
	INT = { name = "Intelligence", kanji = "心", color = Color3.fromRGB(170, 80, 230) },
	PHY = { name = "Physical", kanji = "知", color = Color3.fromRGB(240, 200, 50) },
}

-- v0.25.37 (owner): every class has a type too (Config/Classes mtype). A five-way cycle, each type beats two and
-- loses to two: the attacker deals Bonus x damage to a type it beats, Penalty x to one that beats it (both ways:
-- players vs monsters and monsters vs players). Shown on the Job Master as a green (beats) / red (weak to) disc.
T.STR.beats = { "AGI", "INT" }
T.AGI.beats = { "DEX", "PHY" }
T.DEX.beats = { "INT", "STR" }
T.INT.beats = { "PHY", "AGI" }
T.PHY.beats = { "STR", "DEX" }
T.Order = { "STR", "AGI", "DEX", "INT", "PHY" }
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

-- self-check: each type beats exactly two and is weak to exactly two
for _, id in ipairs(T.Order) do
	assert(#T[id].beats == 2 and #T.WeakTo(id) == 2, "MonsterTypes cycle broken at " .. id)
end

return T
