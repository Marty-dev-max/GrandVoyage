-- SerpentChain (v0.22.5): the body of a full-length serpent boss follows the path its head took, like a real snake.
-- The head is the monster model (it walks with a Humanoid); the body segments + tail are placed along a trail of the
-- head's past positions. The same math runs on the server (hit areas, the BodyPts attribute that Reach uses) and on
-- the client (Controllers/SerpentBody draws the segments smoothly every frame, plus a visual side-to-side wiggle).
-- spec (Config/Monsters def.serpent): segments, spacing (studs between segment centers at full size), shrink (size
-- lost per segment toward the tail), radius (body radius), tailLength.
local C = {}
local STEP = 1.5 -- studs between stored trail points

function C.New(spec)
	return { spec = spec, pts = {} }
end

local function scaleOf(spec, i)
	return 1 - (spec.shrink or 0.035) * i
end
C.ScaleOf = scaleOf

-- distance along the body (from the neck) of every piece's center; the last entry is the tail
function C.Offsets(spec)
	local out = {}
	local d = spec.spacing * 0.45
	for i = 0, spec.segments - 1 do
		local k = scaleOf(spec, i)
		table.insert(out, { d = d, scale = k })
		d += spec.spacing * k
	end
	local kt = scaleOf(spec, spec.segments)
	table.insert(out, { d = d - spec.spacing * kt * 0.5 + spec.tailLength * kt * 0.5, scale = kt, tail = true })
	return out
end

function C.Length(spec)
	local o = C.Offsets(spec)
	return o[#o].d + spec.tailLength
end

-- start straight out behind the head
function C.Reset(ch, anchor, backDir)
	ch.pts = {}
	local total = C.Length(ch.spec) + 8
	local d = STEP
	while d <= total do
		table.insert(ch.pts, anchor + backDir * d)
		d += STEP
	end
end

-- call with the neck anchor whenever the head may have moved
function C.Push(ch, anchor)
	local first = ch.pts[1]
	if not first then
		return
	end
	local dist = (anchor - first).Magnitude
	if dist >= STEP then
		local n = math.floor(dist / STEP)
		for k = 1, n do
			-- newest first: the point nearest the head goes to index 1
			table.insert(ch.pts, 1, first:Lerp(anchor, k / n))
		end
		local keep = math.ceil((C.Length(ch.spec) + 12) / STEP) + 2
		while #ch.pts > keep do
			table.remove(ch.pts)
		end
	end
end

-- position along the trail `dist` studs behind the anchor, and the direction pointing toward the head there
function C.Sample(ch, anchor, dist)
	local prev = anchor
	local walked = 0
	for _, p in ipairs(ch.pts) do
		local seg = (p - prev).Magnitude
		if seg > 1e-4 then
			if walked + seg >= dist then
				local t = (dist - walked) / seg
				return prev:Lerp(p, t), (prev - p).Unit
			end
			walked += seg
		end
		prev = p
	end
	local last = ch.pts[#ch.pts] or anchor
	local before = ch.pts[#ch.pts - 1] or anchor
	local dir = (before - last).Magnitude > 1e-4 and (before - last).Unit or Vector3.new(0, 0, -1)
	return last - dir * math.max(0, dist - walked), dir
end

-- every piece: { pos, dir (toward the head), scale, tail }
function C.Pieces(ch, anchor)
	local out = {}
	for _, o in ipairs(C.Offsets(ch.spec)) do
		local pos, dir = C.Sample(ch, anchor, o.d)
		table.insert(out, { pos = pos, dir = dir, scale = o.scale, tail = o.tail, d = o.d })
	end
	return out
end

-- "x,y,z;x,y,z;..." for the BodyPts attribute (Reach measures players against these)
function C.Pack(pieces)
	local parts = table.create(#pieces)
	for i, p in ipairs(pieces) do
		parts[i] = string.format("%.1f,%.1f,%.1f", p.pos.X, p.pos.Y, p.pos.Z)
	end
	return table.concat(parts, ";")
end

function C.Unpack(s)
	local out = {}
	for x, y, z in string.gmatch(s or "", "([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)") do
		table.insert(out, Vector3.new(tonumber(x), tonumber(y), tonumber(z)))
	end
	return out
end

return C
