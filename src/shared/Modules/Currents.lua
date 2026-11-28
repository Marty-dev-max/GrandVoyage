-- Currents (Mastery v2 M5, remake): sea currents between the islands. For every pair of neighbouring islands
-- (Islands.List order) there are two lanes side by side: one flowing on toward the next island, one flowing back.
-- In a lane a ship sailing with the flow is up to Boost faster (against it that much slower) and every ship drifts
-- with it a little. Navigators Lv 10+ see the water streaming (client Sailing), Lv 30 later on the map (M6).
-- Shared by ShipService and the client; pure math, built once from the island list.
local Shared = script.Parent.Parent
local Islands = require(Shared.Config.Islands)

local C = {}
C.HalfWidth = 70 -- studs from a lane's middle to its edge (strength fades to 0 there)
C.Side = 160 -- the outbound and return lanes sit this far either side of the straight line
C.Clear = 140 -- lanes start / stop this far outside each island's radius
C.Boost = 0.25 -- x(1 + Boost) top speed sailing straight down a lane's middle, x(1 - Boost) straight against
C.Drift = 5 -- studs/s every ship is carried along in a lane's middle
-- R5: the world (islands, sea spacing, ships) is GameConfig.WorldScale bigger: lanes widen and drift faster with it
do
	local S = Islands.Scale or 1
	C.HalfWidth *= S
	C.Side *= S
	C.Clear *= S
	C.Drift *= S
end

C.Lanes = {}
do
	-- R5: the story route island to island, plus one current from each Origin island to Daybreak
	local pairsList = {}
	local route = Islands.Route or Islands.List
	for i = 1, #route - 1 do
		table.insert(pairsList, { route[i], route[i + 1] })
	end
	for _, isl in ipairs(Islands.List) do
		if isl.origin and isl.nextId and Islands.ById[isl.nextId] then
			table.insert(pairsList, { isl, Islands.ById[isl.nextId] })
		end
	end
	for _, pr in ipairs(pairsList) do
		local a, b = pr[1], pr[2]
		local pa = Vector3.new(a.x, 0, a.z or 0)
		local pb = Vector3.new(b.x, 0, b.z or 0)
		local d = pb - pa
		if d.Magnitude > (a.radius + b.radius + 2 * C.Clear + 200) then
			local dir = d.Unit
			local side = Vector3.new(-dir.Z, 0, dir.X)
			local s = pa + dir * (a.radius + C.Clear)
			local e = pb - dir * (b.radius + C.Clear)
			-- outbound on one side, the way back on the other
			table.insert(C.Lanes, { from = s + side * C.Side, to = e + side * C.Side, dir = dir, len = (e - s).Magnitude, out = true, a = a.id, b = b.id })
			table.insert(C.Lanes, { from = e - side * C.Side, to = s - side * C.Side, dir = -dir, len = (e - s).Magnitude, out = false, a = b.id, b = a.id })
		end
	end
end

-- the strongest lane at (x, z): flow direction (unit, flat) and strength 0..1, or nil
function C.At(x, z)
	local p = Vector3.new(x, 0, z)
	local bestK, bestDir = 0, nil
	for _, l in ipairs(C.Lanes) do
		local rel = p - l.from
		local along = rel:Dot(l.dir)
		if along >= 0 and along <= l.len then
			local off = (rel - l.dir * along).Magnitude
			if off < C.HalfWidth then
				-- smooth across the lane, and eased in / out over the first and last 120 studs
				local k = 1 - (off / C.HalfWidth) ^ 2
				k *= math.clamp(math.min(along, l.len - along) / 120, 0, 1)
				if k > bestK then
					bestK, bestDir = k, l.dir
				end
			end
		end
	end
	return bestDir, bestK
end

return C
