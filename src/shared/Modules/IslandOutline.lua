--!strict
-- v0.25.134: the organic island outline (grass edge radius + beach width per local angle), shared by the server map
-- builder (World/IslandShape) and the client's far-island silhouettes (Controllers/WorldCull). Pure math per island id.
local O = {}

function O.Hash(s: string): number
	local h = 7
	for i = 1, #s do
		h = (h * 31 + string.byte(s, i)) % 2147483647
	end
	return h
end

local cache = {}
local function phases(island)
	local p = cache[island.id]
	if not p then
		local rnd = Random.new(O.Hash(tostring(island.id)))
		p = {}
		for i = 1, 6 do
			p[i] = rnd:NextNumber(0, math.pi * 2)
		end
		cache[island.id] = p
	end
	return p
end

-- 1 at angle b, 0 beyond w radians
function O.Near(a: number, b: number, w: number): number
	local d = math.abs(math.atan2(math.sin(a - b), math.cos(a - b)))
	return math.clamp(1 - d / w, 0, 1)
end

-- grass edge radius at local angle a (atan2(z, x)); never below r - 14, docks (+-x) and the south harbor kept at r
function O.Radius(island, r: number, a: number): number
	if island.floating then
		return r
	end
	local p = phases(island)
	local bump = 0.075 * math.sin(3 * a + p[1]) + 0.05 * math.sin(5 * a + p[2]) + 0.04 * math.sin(2 * a + p[3]) + 0.035
	local R = r - 14 + r * math.max(0, bump)
	local eastW = island.id == "Daybreak" and 1.05 or 0.35 -- Daybreak's stone quay spans +-0.5 rad
	local keep = math.max(O.Near(a, 0, eastW), O.Near(a, math.pi, 0.35), O.Near(a, math.pi / 2, 0.6))
	return math.max(R, (r - 14) + 14 * math.min(1, keep * 2))
end

-- sand beach width beyond the grass edge (0 = cliff straight into the sea)
function O.Beach(island, r: number, a: number): number
	if island.floating then
		return 0
	end
	local p = phases(island)
	return math.max(0, 26 * math.sin(4 * a + p[4]) + 10 * math.sin(7 * a + p[5]) - 4)
end

return O
