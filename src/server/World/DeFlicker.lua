-- DeFlicker (v0.25.112, owner: "fix every flicker in the game"): runs once over a freshly built World, after Voxelize.
-- Two blocks whose faces lie in the same plane, point the same way and overlap z-fight (paths on the ground, beams on
-- walls, dock planks, awning stripes, NPC outfit pieces). For every such stack the bigger face stays and each smaller
-- one is lifted off it along the face normal by STEP per level (a piece over two others goes two steps out).
-- Bottom faces are skipped (nobody looks at them). Deterministic, no rng, so the Lune bake and runtime builds match.
local D = {}

local STEP = 0.04 -- studs per level; enough for the depth buffer at ~150 studs, too small to see as a lip
local MAX_LEVEL = 4
local CELL, BIG = 16, 256 -- plane grid cell (studs); a face covering more cells than BIG is checked against all

local function q(x, s)
	return math.floor(x / s + 0.5)
end

-- v0.25.112: the first runtime pass hit the server script timeout (whole Init aborted); yield every ~50 ms so a big
-- world spreads over a few frames (results do not depend on timing)
local lastYield = 0
local function breathe()
	if os.clock() - lastYield > 0.05 then
		task.wait()
		lastYield = os.clock()
	end
end

function D.Run(root)
	local t0 = os.clock()
	local buckets = {}
	lastYield = os.clock()
	for _, p in ipairs(root:GetDescendants()) do
		breathe()
		if p.ClassName == "Part" and (p.Shape == nil or p.Shape == Enum.PartType.Block) and p.Transparency < 0.9 and p.Name ~= "Water" then -- (the Lune bake leaves Shape unset = block)
			local cf, sz = p.CFrame, p.Size / 2
			local axes = {
				{ cf.RightVector, sz.X, cf.UpVector * sz.Y, cf.LookVector * sz.Z },
				{ cf.UpVector, sz.Y, cf.RightVector * sz.X, cf.LookVector * sz.Z },
				{ cf.LookVector, sz.Z, cf.RightVector * sz.X, cf.UpVector * sz.Y },
			}
			for _, a in ipairs(axes) do
				for _, sgn in ipairs({ 1, -1 }) do
					local n = a[1] * sgn
					if n.Y > -0.5 then
						local center = cf.Position + n * a[2]
						local key = q(n.X, 0.01) .. "," .. q(n.Y, 0.01) .. "," .. q(n.Z, 0.01) .. "|" .. q(n:Dot(center), 0.02)
						local u = math.abs(n.Y) < 0.9 and n:Cross(Vector3.new(0, 1, 0)).Unit or n:Cross(Vector3.new(1, 0, 0)).Unit
						local v = n:Cross(u)
						local cu, cv = center:Dot(u), center:Dot(v)
						local hu = math.abs(a[3]:Dot(u)) + math.abs(a[4]:Dot(u))
						local hv = math.abs(a[3]:Dot(v)) + math.abs(a[4]:Dot(v))
						local b = buckets[key]
						if not b then
							b = {}
							buckets[key] = b
						end
						table.insert(b, { p = p, n = n, u0 = cu - hu, u1 = cu + hu, v0 = cv - hv, v1 = cv + hv, area = hu * hv })
					end
				end
			end
		end
	end
	local moves, moved = {}, 0
	for _, b in pairs(buckets) do
		breathe()
		if #b > 1 then
			-- biggest face first: it stays, the pieces on it get levels
			table.sort(b, function(x, y)
				if x.area ~= y.area then
					return x.area > y.area
				end
				return x.p.Name < y.p.Name
			end)
			-- earlier (bigger) faces are found through a CELL grid on the plane; faces wider than BIG cells go in a list
			local grid, big = {}, {}
			for i = 1, #b do
				if i % 64 == 0 then
					breathe()
				end
				local A = b[i]
				local c0u, c1u, c0v, c1v = math.floor(A.u0 / CELL), math.floor(A.u1 / CELL), math.floor(A.v0 / CELL), math.floor(A.v1 / CELL)
				local level, seen = 0, {}
				local function test(B)
					if not seen[B] and B.p ~= A.p and math.min(A.u1, B.u1) - math.max(A.u0, B.u0) > 0.02 and math.min(A.v1, B.v1) - math.max(A.v0, B.v0) > 0.02 then
						level = math.max(level, B.level + 1)
					end
					seen[B] = true
				end
				for _, B in ipairs(big) do
					test(B)
				end
				local wide = (c1u - c0u + 1) * (c1v - c0v + 1) > BIG
				if not wide then
					for cu = c0u, c1u do
						for cv = c0v, c1v do
							for _, B in ipairs(grid[cu * 65536 + cv] or {}) do
								test(B)
							end
						end
					end
				else
					-- a wide face can't use the grid: test every earlier one
					for j = 1, i - 1 do
						test(b[j])
					end
				end
				A.level = math.min(level, MAX_LEVEL)
				if wide then
					table.insert(big, A)
				else
					for cu = c0u, c1u do
						for cv = c0v, c1v do
							local k = cu * 65536 + cv
							local cell = grid[k]
							if not cell then
								cell = {}
								grid[k] = cell
							end
							table.insert(cell, A)
						end
					end
				end
				if A.level > 0 then
					local m = moves[A.p]
					if not m then
						m = {}
						moves[A.p] = m
					end
					-- one push per direction; a part fighting on two faces moves along both
					local k = q(A.n.X, 0.01) .. "," .. q(A.n.Y, 0.01) .. "," .. q(A.n.Z, 0.01)
					if not m[k] or m[k].level < A.level then
						m[k] = { n = A.n, level = A.level }
					end
				end
			end
		end
	end
	for p, m in pairs(moves) do
		local off = Vector3.new(0, 0, 0)
		for _, e in pairs(m) do
			off += e.n * (e.level * STEP)
		end
		p.CFrame = p.CFrame + off
		moved += 1
	end
	print(string.format("[DeFlicker] %d parts lifted off coplanar faces in %.2fs", moved, os.clock() - t0))
	return moved
end

return D
