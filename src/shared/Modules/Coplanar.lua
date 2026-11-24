-- Coplanar (v0.25.149, owner: clothes kept flickering): two blocks of different color with faces in the same plane
-- that overlap z-fight. Fix(items, fixed) grows the smaller block of every such pair 0.024 along that face's axis
-- (its face moves 0.012 out) until none is left. Used by VoxelChar (whole body, in rest space) and Accessory.Wear
-- (worn pieces against the body). items / fixed = arrays of { part, cframe }; only items are resized.
local C = {}

local AX = { "RightVector", "UpVector", "LookVector" }
local EPS, MIN, STEP = 0.004, 0.01, 0.024

local function comp(v, i)
	return i == 1 and v.X or i == 2 and v.Y or v.Z
end

-- the axis of a and of b of a same-facing coplanar face pair that overlaps by more than MIN, or nil
function C.Pair(sa, ca, sb, cb)
	for ia = 1, 3 do
		local n0 = ca[AX[ia]]
		for ib = 1, 3 do
			if math.abs(n0:Dot(cb[AX[ib]])) > 0.999 then
				for _, sg in ipairs({ 1, -1 }) do
					local n = n0 * sg
					local fa = ca.Position + n * comp(sa, ia) / 2
					local fb = cb.Position + n * comp(sb, ib) / 2
					local d = fb - fa
					if math.abs(d:Dot(n)) < EPS then
						local ok = true
						for ja = 1, 3 do
							if ja ~= ia then
								local u = ca[AX[ja]]
								local hb = 0
								for jb = 1, 3 do
									if jb ~= ib then
										hb += math.abs(cb[AX[jb]]:Dot(u)) * comp(sb, jb) / 2
									end
								end
								if math.abs(d:Dot(u)) > comp(sa, ja) / 2 + hb - MIN then
									ok = false
									break
								end
							end
						end
						if ok then
							return ia, ib
						end
					end
				end
			end
		end
	end
	return nil
end

local function visible(p)
	return p.Transparency < 1
end
local function differ(a, b)
	return a.Color ~= b.Color or a.Material ~= b.Material
end
local function near(a, ca, b, cb)
	return (ca.Position - cb.Position).Magnitude < (a.Size.Magnitude + b.Size.Magnitude) / 2 + 0.05
end
local function grow(p, axis)
	p.Size += Vector3.new(axis == 1 and STEP or 0, axis == 2 and STEP or 0, axis == 3 and STEP or 0)
end

function C.Fix(items, fixed)
	fixed = fixed or {}
	for _ = 1, 4 do
		local changed = false
		for i, A in ipairs(items) do
			local a, ca = A[1], A[2]
			if visible(a) then
				for j = i + 1, #items do
					local b, cb = items[j][1], items[j][2]
					if visible(b) and differ(a, b) and near(a, ca, b, cb) then
						local ia, ib = C.Pair(a.Size, ca, b.Size, cb)
						if ia then
							-- the smaller block moves (a detail over a cover, not the cover)
							if a.Size.X * a.Size.Y * a.Size.Z <= b.Size.X * b.Size.Y * b.Size.Z then
								grow(a, ia)
							else
								grow(b, ib)
							end
							changed = true
						end
					end
				end
				for _, F in ipairs(fixed) do
					local b, cb = F[1], F[2]
					if visible(b) and differ(a, b) and near(a, ca, b, cb) then
						local ia = C.Pair(a.Size, ca, b.Size, cb)
						if ia then
							grow(a, ia)
							changed = true
						end
					end
				end
			end
		end
		if not changed then
			return
		end
	end
end

return C
