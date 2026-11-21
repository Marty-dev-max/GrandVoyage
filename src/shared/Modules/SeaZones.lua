-- SeaZones: which sea zone a position is in (Lane / Edge / Doldrums)
local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)
local Islands = require(Shared.Config.Islands)

local Z = {}
local lane = GameConfig.Lane

-- Returns zoneName, windFactor(0..1)
function Z.Get(pos)
	local az = math.abs(pos.Z)
	if pos.X > Islands.RedLine.x - Islands.RedLine.thickness / 2 - 40 then
		return "RedLine", 0.6
	end
	if az <= lane.HalfWidth then
		return "Lane", 1
	elseif az <= lane.HalfWidth + lane.EdgeWidth then
		local t = (az - lane.HalfWidth) / lane.EdgeWidth
		return "Edge", 1 - t * 0.75
	else
		return "CalmBelt", GameConfig.CalmBelt.WindFactor
	end
end

-- segment = index of the last island passed (used for NPC ship tiers)
function Z.Segment(x)
	local seg = 1
	for i, island in ipairs(Islands.List) do
		if x >= island.x then
			seg = i
		end
	end
	return seg
end

function Z.NearestIsland(pos)
	local best, bestD = nil, math.huge
	for _, island in ipairs(Islands.List) do
		local d = (Vector2.new(pos.X, pos.Z) - Vector2.new(island.x, island.z or 0)).Magnitude
		if d < bestD then
			best, bestD = island, d
		end
	end
	return best, bestD
end

function Z.OnIslandLand(pos)
	local island, d = Z.NearestIsland(pos)
	return island ~= nil and d <= island.radius - 10, island
end

return Z
