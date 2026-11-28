-- SeaZones: which sea zone a position is in (Lane / Edge / CalmBelt = the Doldrums / RedLine = by a wall)
-- W1 (owner, 28 Nov 2026): the Azure East is the north-east quarter of the world (Shared/Modules/WorldShape): walls on
-- its west, north and east sides, the Doldrums along its south side, then the Grand Current band (locked).
local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)
local Islands = require(Shared.Config.Islands)
local G = require(Shared.Modules.WorldShape)

local Z = {}
local lane = GameConfig.Lane

-- Returns zoneName, windFactor(0..1)
function Z.Get(pos)
	local x, z = pos.X, pos.Z
	if G.WallDist(x, z) < 400 then
		return "RedLine", 0.6
	end
	if z >= G.BandN then
		return "GrandCurrent", 1
	end
	if z >= G.BeltN then
		return "CalmBelt", GameConfig.CalmBelt.WindFactor
	end
	if z >= G.BeltN - lane.EdgeWidth then
		local t = (z - (G.BeltN - lane.EdgeWidth)) / lane.EdgeWidth
		return "Edge", 1 - t * 0.75
	end
	return "Lane", 1
end

-- segment = the stretch of the route a position is on: i = between route island i and i + 1 (the last one runs from
-- the last island to the Backflow Peak canal). Used for NPC ship tiers and crew levels.
-- Accepts a Vector3 (or an x and z).
function Z.Segment(p, z)
	if typeof(p) == "Vector3" then
		p, z = p.X, p.Z
	end
	local q = Vector2.new(p, z or 0)
	local pts = G.RoutePoints()
	local best, bestD = 1, math.huge
	for i = 1, #pts - 1 do
		local d = G.SegDist(q, pts[i], pts[i + 1])
		if d <= bestD then -- a tie (standing on island i) counts as the stretch leaving it
			best, bestD = i, d
		end
	end
	return best
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
