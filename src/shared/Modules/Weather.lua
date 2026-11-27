-- Weather (Mastery v2 M6, remake): storms and whirlpools at sea.
-- The SERVER owns them (ShipService moves storms, switches whirlpools on and off) and publishes the list once a second
-- as the workspace attribute "Weather" (W.Encode); clients read it with W.Decode and move storms on between updates
-- with their velocity. Whirlpools can only open at fixed spots (W.Spots): halfway between two neighbouring islands,
-- on the straight line, which is the middle between the two sea-current lanes (Currents): the currents are the safe way.
-- Effects (player ships only, NPC ships ignore the weather like the wind):
--   storm     = hull damage (a share of max HP per second, more in the eye), water in the hull, a shove sideways,
--               lightning strikes now and then, stronger but gusty wind
--   whirlpool = pulls the ship to its middle and spins it around; the core grinds the hull
-- Navigator Lv 30 (Storm Sense) sees them coming (ship card warning + the map), Lv 50 (Master Helmsman) takes half
-- the weather damage and gets the Hard Turn skill.
local Shared = script.Parent.Parent
local Islands = require(Shared.Config.Islands)
local GameConfig = require(Shared.Config.GameConfig)

local W = {}

W.Storm = {
	Count = 3, -- storms out at sea at once
	Radius = { 150, 230 }, -- random per storm
	Speed = { 5, 10 }, -- studs/s drift
	Life = { 360, 600 }, -- seconds a storm lasts (it grows in / fades out over Fade)
	Fade = 45,
	Gap = { 60, 180 }, -- seconds before a gone storm comes back somewhere else
	DmgPerSec = 0.003, -- x max hull HP per second at strength 1 (the eye): a minute in the eye ~ 18% + lightning + leaks
	-- (0.1.19 test: 0.004 + strikes 0.12 x 3% took a galleon 16% in 28 s: lightning + water in the hull doubled it)
	Shove = 9, -- studs/s sideways push at strength 1
	WindK = 1.25, -- wind x this in a storm (more power, gusty)
	Strike = { Chance = 0.08, Dmg = 0.025 }, -- each second at strength >= 0.4: chance of a lightning hit, x max HP
	ClearIsland = 220, -- a storm never starts within an island's radius + this
}

W.Whirl = {
	Radius = 75, -- pull reaches this far
	Core = 16, -- inside the core the hull grinds
	Pull = 16, -- studs/s toward the middle at the core edge (fades to 0 at Radius)
	Swirl = 12, -- studs/s around it
	CoreDmg = 0.012, -- x max HP per second in the core
	On = { 180, 300 }, -- seconds open
	Off = { 120, 240 }, -- seconds closed
	EscapeFrom = 0.5, -- you "escape" when you were inside Radius x this and got back out of Radius
}

-- the sea weather lives in: east of the first island, short of the Red Line, inside the windy lane
W.MinX = -300
W.MaxX = Islands.RedLine.x - Islands.RedLine.thickness / 2 - 400
W.HalfZ = GameConfig.Lane.HalfWidth - 150

-- fixed whirlpool spots
W.Spots = {}
do
	local list = {}
	for _, isl in ipairs(Islands.List) do
		if type(isl) == "table" and isl.x and isl.radius then
			table.insert(list, isl)
		end
	end
	for i = 1, #list - 1 do
		local a, b = list[i], list[i + 1]
		local pa = Vector3.new(a.x, 0, a.z or 0)
		local pb = Vector3.new(b.x, 0, b.z or 0)
		local mid = (pa + pb) / 2
		local half = (pb - pa).Magnitude / 2
		if half >= math.max(a.radius, b.radius) + 300 then
			table.insert(W.Spots, { x = mid.X, z = mid.Z, id = i })
		end
	end
end

-- distance on the water plane
local function flat(x1, z1, x2, z2)
	local dx, dz = x1 - x2, z1 - z2
	return math.sqrt(dx * dx + dz * dz)
end
W.Flat = flat

-- storm strength at a point: 1 in the eye, 0 at the rim (smooth), x the storm's own fade in / out (s.k)
function W.StormK(s, x, z)
	local d = flat(x, z, s.x, s.z)
	if d >= s.r then
		return 0
	end
	local t = d / s.r
	return (1 - t * t) * (s.k or 1)
end

-- the strongest storm and the nearest open whirlpool at (x, z)
-- returns stormK, storm, whirlK (0..1 pull share), whirl, distance to the whirlpool's middle
function W.At(x, z, list)
	local bestK, best = 0, nil
	local wk, wbest, wd = 0, nil, math.huge
	for _, e in ipairs(list or {}) do
		if e.kind == "S" then
			local k = W.StormK(e, x, z)
			if k > bestK then
				bestK, best = k, e
			end
		else
			local d = flat(x, z, e.x, e.z)
			if d < e.r and d < wd then
				wd, wbest = d, e
				wk = 1 - math.max(0, d - W.Whirl.Core) / (e.r - W.Whirl.Core)
			end
		end
	end
	return bestK, best, wk, wbest, wd
end

-- wire format: "S,id,x,z,r,vx,vz,k;W,id,x,z,r;..." (whole studs, k in hundredths). `id` stays the same while that
-- storm / whirlpool lives, so clients keep its clouds / swirl across updates.
function W.Encode(list)
	local parts = {}
	local f = math.floor
	for _, e in ipairs(list) do
		if e.kind == "S" then
			table.insert(parts, string.format("S,%d,%d,%d,%d,%.1f,%.1f,%d", f(e.id or 0), f(e.x), f(e.z), f(e.r), e.vx or 0, e.vz or 0, f((e.k or 1) * 100 + 0.5)))
		else
			table.insert(parts, string.format("W,%d,%d,%d,%d", f(e.id or 0), f(e.x), f(e.z), f(e.r)))
		end
	end
	return table.concat(parts, ";")
end

function W.Decode(s)
	local out = {}
	if type(s) ~= "string" then
		return out
	end
	for item in string.gmatch(s, "[^;]+") do
		local f = string.split(item, ",")
		local n = function(i, default)
			return tonumber(f[i]) or default
		end
		if f[1] == "S" and #f >= 8 then
			table.insert(out, { kind = "S", id = n(2, 0), x = n(3, 0), z = n(4, 0), r = n(5, 1), vx = n(6, 0), vz = n(7, 0), k = n(8, 100) / 100 })
		elseif f[1] == "W" and #f >= 5 then
			table.insert(out, { kind = "W", id = n(2, 0), x = n(3, 0), z = n(4, 0), r = n(5, 1) })
		end
	end
	return out
end

-- compass word for a flat direction (map north = -Z, east = +X)
function W.Compass(dx, dz)
	local a = math.deg(math.atan2(dx, -dz)) % 360
	local names = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
	return names[math.floor((a + 22.5) / 45) % 8 + 1]
end

return W
