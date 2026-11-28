-- WorldShape (W1, owner 28 Nov 2026, docs/Plan-WorldMap.md): the shape of the whole world.
-- Four seas around a cross: the Crimson Wall runs north-south through the middle of the world, the Grand Current
-- band runs east-west across it, Backflow Peak stands where they cross. The Azure East (sea 1, every island so far)
-- is the north-east quarter: the Crimson Wall on its west side, the world-edge wall on its north and east sides and
-- the Doldrums along its south side, past which the Grand Current band runs (locked until sea 2).
-- Numbers are WORLD studs (already x WorldScale), in the game's frame: Daybreak at (0, 0), +X east, -Z north.
-- Peak = the cross; sea 1 runs from the wall (x West) to the world edge (x East), from the north edge to the belt.
local Shared = script.Parent.Parent
local Islands = require(Shared.Config.Islands)

local G = {}

G.Peak = Vector2.new(-15600, 6200) -- Backflow Peak (the middle of the world)
G.WallHalf = 300 -- the middle wall is x Peak.X +- this
G.Edge = 500 -- thickness of the world-edge walls
G.MountR = 2600 -- Backflow Peak's foot (radius around Peak)

-- sea 1 (the Azure East) water, inside the walls
G.West = G.Peak.X + G.WallHalf -- -15300
G.East = 2400
G.North = -3800
G.BeltN = 3900 -- the Doldrums start here (south side of sea 1)
G.BandN = 4700 -- the Grand Current band
G.BandS = 7700
G.BeltS = 8500
G.FarS = 10500 -- water is drawn this far south (looking across the band)

-- the canal up Backflow Peak starts here, at the mountain's north-east foot (in sea 1, just north of the Doldrums)
do
	local a = math.rad(-60) -- from the Peak: 60 degrees north of east
	G.MouthDir = Vector2.new(math.cos(a), math.sin(a))
	G.Mouth = G.Peak + G.MouthDir * (G.MountR + 100)
end

-- the box the world is drawn in (ocean tiles, sea floor)
G.DrawMinX = G.Peak.X - G.WallHalf
G.DrawMaxX = G.East + G.Edge
G.DrawMinZ = G.North - G.Edge
G.DrawMaxZ = G.FarS

local function flat(a, b)
	return (a - b).Magnitude
end
G.Flat = flat

-- true inside the Azure East's open water box (walls and the Grand Current band excluded, the Doldrums included)
function G.InSea1(x, z)
	return x > G.West and x < G.East and z > G.North and z < G.BandN
end

-- distance to the nearest wall or mountain face (negative = inside the rock)
function G.WallDist(x, z)
	local d = math.min(x - G.West, G.East - x, z - G.North)
	local m = flat(Vector2.new(x, z), G.Peak) - G.MountR
	return math.min(d, m)
end

-- the story route as points: every route island, then the canal mouth
function G.RoutePoints()
	local pts = {}
	for _, isl in ipairs(Islands.Route) do
		table.insert(pts, Vector2.new(isl.x, isl.z or 0))
	end
	table.insert(pts, G.Mouth)
	return pts
end

-- distance from p to the segment a-b, and how far along it (0..1)
function G.SegDist(p, a, b)
	local ab = b - a
	local len2 = ab:Dot(ab)
	local t = len2 > 0 and math.clamp((p - a):Dot(ab) / len2, 0, 1) or 0
	return flat(p, a + ab * t), t
end

-- keep a point inside sea 1, margin studs from every wall and north of the Doldrums
function G.ClampSea1(x, z, margin)
	margin = margin or 200
	x = math.clamp(x, G.West + margin, G.East - margin)
	z = math.clamp(z, G.North + margin, G.BeltN - margin)
	local v = Vector2.new(x, z) - G.Peak
	if v.Magnitude < G.MountR + margin then
		local p = G.Peak + v.Unit * (G.MountR + margin)
		x, z = p.X, p.Y
	end
	return x, z
end

return G
