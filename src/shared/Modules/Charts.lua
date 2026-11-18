-- Charts: which island names a player may see (owner, v0.22.4).
-- An island's name stays "???" until you have visited it, or your Sea Compass points to it: that happens when you
-- finish an island's story and the next main quest step is "Sail to <island>". Computed from the save (visited
-- islands + quest step), so old saves need no migration.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Islands = require(ReplicatedStorage.Shared.Config.Islands)
local Quests = require(ReplicatedStorage.Shared.Config.Quests)

local Charts = {}
Charts.Unknown = "???"
Charts.UnknownSubtitle = "Uncharted waters"

-- islandId -> index of the quest step that sends you there
local revealAt = {}
for i, s in ipairs(Quests.Main) do
	if s.goal.kind == "Reach" and s.goal.target and not revealAt[s.goal.target] then
		revealAt[s.goal.target] = i
	end
end
Charts.RevealStep = revealAt

function Charts.Known(islandId, unlocked, questStep)
	if islandId == Islands.StartIsland then
		return true
	end
	if unlocked and unlocked[islandId] then
		return true
	end
	local at = revealAt[islandId]
	return at ~= nil and (questStep or 1) >= at
end

-- the island id that becomes charted when the quest moves to this step (nil if none)
function Charts.RevealedBy(step)
	local s = Quests.Main[step]
	if s and s.goal.kind == "Reach" and revealAt[s.goal.target] == step then
		return s.goal.target
	end
	return nil
end

function Charts.Name(isl, unlocked, questStep)
	return Charts.Known(isl.id, unlocked, questStep) and isl.name or Charts.Unknown
end

return Charts
