-- Hunts (v0.25.18, owner: levels came too slowly from farming alone): a repeatable "Defeat <monster> x Count" for
-- every monster that lives on an island. One hunt is active at a time; claiming pays out and starts it again.
-- Rewards on top of the kills themselves: EXP/Job EXP = the kills' own EXP x ExpMult, Doubloons = average drop x
-- Count x BeliMult, plus a few healing items.
return {
	Count = 40,
	ExpMult = 1.5,
	BeliMult = 0.5,
	Items = { { "MeatOnBone", 5 } },
	LevelLead = 2, -- a hunt opens at (monster level - LevelLead)
}
