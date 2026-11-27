-- Wind (Mastery v2 M5, remake): the wind's DIRECTION over the sea. SeaZones still gives its strength (Lane 1, Edge
-- fading, Doldrums ~0). The direction turns slowly with server time and bends a little from one part of the sea to
-- the next, so the server (ShipService) and every client (Sailing HUD arrow) work it out alone, with no network.
-- A ship's sails draw by the angle between its bow and the wind: running with it is fastest, a beam reach a bit
-- slower, beating into it slow. Oars ignore the wind.
local W = {}

W.Period = 1800 -- seconds for the wind to go once round the compass
W.With = 1.15 -- sail factor running straight downwind
W.Beam = 0.95 -- wind from the side
W.Against = 0.6 -- straight into the wind
W.ReaderMin = 0.25 -- Wind Reader (Navigator Lv 10) counts from this much "with the wind" (cos of the angle)

-- angle in radians (0 = blowing toward +Z), at map position x, z and server time t
function W.Angle(x, z, t)
	return (t / W.Period) * 2 * math.pi + math.sin(x / 2600) * 0.9 + math.cos(z / 2200) * 0.5
end

-- unit vector the wind blows TOWARD (flat)
function W.Dir(x, z, t)
	local a = W.Angle(x, z, t)
	return Vector3.new(math.sin(a), 0, math.cos(a))
end

-- cos of the angle between the bow (flat unit vector) and the wind: 1 = with it, -1 = into it
function W.Cos(fwd, x, z, t)
	return fwd:Dot(W.Dir(x, z, t))
end

-- how hard the sails draw for that cos; reader = the Wind Reader bonus (0.15 at Navigator Lv 10)
function W.SailK(cos, reader)
	local k
	if cos >= 0 then
		k = W.Beam + (W.With - W.Beam) * cos
	else
		k = W.Beam + (W.Beam - W.Against) * cos
	end
	if reader and reader > 0 and cos > W.ReaderMin then
		k *= 1 + reader * (cos - W.ReaderMin) / (1 - W.ReaderMin)
	end
	return k
end

-- a compass name for the HUD ("N", "NE", ...): +X is east, -Z is north (the map window's up)
local NAMES = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
function W.FromName(dir)
	-- sailors name a wind by where it comes FROM
	local from = -dir
	local a = math.atan2(from.X, -from.Z) -- 0 = north, clockwise
	local i = math.floor((a / (2 * math.pi)) * 8 + 0.5) % 8
	return NAMES[i + 1]
end

return W
