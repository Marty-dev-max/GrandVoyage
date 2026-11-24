-- Waves (v0.25.144, owner: the sea should be voxel waves with real water physics, white crests, dark troughs, not too
-- tall). One height function shared by the server (ships ride it: ShipService) and the client (Controllers/VoxelSea
-- draws it as block columns). Time = workspace:GetServerTimeNow() on both sides so they agree.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Islands = require(ReplicatedStorage.Shared.Config.Islands)

local W = {}

W.Amp = 1.5 -- max crest height above sea level in open water (studs); troughs go as deep
local CALM_Z = GameConfig.Lane.HalfWidth + GameConfig.Lane.EdgeWidth
local CALM = 0.25 -- Doldrums: glassy water
local SHORE = 45 -- waves die down over this many studs before an island's edge
local SHORE_MIN = 0.2

-- { dirX, dirZ, wavelength, speed, weight } ; weights sum to 1
local TRAINS = {
	{ 0.8, 0.6, 96, 9, 0.5 },
	{ -0.3, 0.95, 58, 7, 0.3 },
	{ 0.95, -0.3, 31, 5, 0.2 },
}
for _, t in ipairs(TRAINS) do
	local m = math.sqrt(t[1] * t[1] + t[2] * t[2])
	t[1], t[2] = t[1] / m, t[2] / m
	t.k = 2 * math.pi / t[3]
end

-- 0..1 amplitude factor at a spot (calm belt + near islands)
function W.Damp(x, z)
	local a = math.abs(z) > CALM_Z and CALM or 1
	for _, isl in ipairs(Islands.List) do
		if type(isl) == "table" and isl.x and isl.radius then
			local dx, dz = x - isl.x, z - (isl.z or 0)
			local edge = math.sqrt(dx * dx + dz * dz) - isl.radius
			if edge < SHORE then
				a = math.min(a, math.max(SHORE_MIN, edge / SHORE))
			end
		end
	end
	return a
end

-- raw wave height in -1..1 (no damping)
function W.Raw(x, z, t)
	local h = 0
	for _, tr in ipairs(TRAINS) do
		h += tr[5] * math.sin((tr[1] * x + tr[2] * z) * tr.k - t * tr[4] * tr.k)
	end
	return h
end

-- surface height above SeaLevel (studs)
function W.Height(x, z, t, damp)
	return W.Raw(x, z, t) * W.Amp * (damp or W.Damp(x, z))
end

function W.Now()
	return workspace:GetServerTimeNow()
end

-- assert-based self-check: heights stay inside the amplitude
do
	for i = 1, 50 do
		local h = W.Height(i * 37.3, -i * 11.1, i * 0.7, 1)
		assert(math.abs(h) <= W.Amp + 1e-6, "Waves.Height out of range")
	end
end

return W
