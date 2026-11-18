-- Voxelize (v0.24.0, owner: the whole map goes voxel, island layouts unchanged). Runs once over a freshly built World
-- (WorldBuilder.Build, so the Lune bake and runtime rebuilds both get it):
--  * Ball parts become cubes (same part, Shape = Block, a bit smaller so they read the same size)
--  * Cylinders become square posts when thin; thick ones become a blocky "plus" prism (two crossed boxes, plus two
--    more steps when they are big) so a round tower / mesa reads as a stepped voxel circle
--  * Wedges (roofs, ramps, bows) keep their wedge as an INVISIBLE collider (walking feels the same) and show a
--    staircase of blocks instead of the slope
-- Hidden parts (colliders, triggers) and anything inside workspace.Handmade are left alone. Deterministic: no rng.
local V = {}

local function copyLook(src, dst)
	dst.Color = src.Color
	dst.Material = src.Material
	pcall(function()
		dst.MaterialVariant = src.MaterialVariant
	end)
	dst.Reflectance = src.Reflectance
	dst.Transparency = src.Transparency
	dst.CastShadow = src.CastShadow
	dst.Anchored = true
	dst.TopSurface = Enum.SurfaceType.Smooth
	dst.BottomSurface = Enum.SurfaceType.Smooth
	pcall(function()
		for _, tag in ipairs(src:GetTags()) do
			if tag ~= "EnvPart" and tag ~= "EnvProp" then
				dst:AddTag(tag)
			end
		end
	end)
end

local function visualBlock(src, size, cf, name)
	local p = Instance.new("Part")
	p.Name = name or (src.Name .. "_Vox")
	copyLook(src, p)
	p.Size = size
	p.CFrame = cf
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = src.Parent
	return p
end

-- returns how many parts were changed / added
local function ball(p)
	local d = math.min(p.Size.X, p.Size.Y, p.Size.Z) * 0.86
	p.Shape = Enum.PartType.Block
	p.Size = Vector3.new(d, d, d)
	return 1, 0
end

local function cylinder(p)
	-- Roblox cylinders run along X; the round section is Y x Z
	local L, D = p.Size.X, math.min(p.Size.Y, p.Size.Z)
	p.Shape = Enum.PartType.Block
	if D < 6 then
		p.Size = Vector3.new(L, D * 0.88, D * 0.88)
		return 1, 0
	end
	-- plus-shaped prism: this part is one bar, a crossed copy is the other
	p.Size = Vector3.new(L, D * 0.72, D)
	visualBlock(p, Vector3.new(L, D, D * 0.72), p.CFrame, p.Name .. "_VoxB").CanCollide = p.CanCollide
	local added = 1
	if D >= 18 then
		-- two more steps: an octagon-ish voxel circle
		visualBlock(p, Vector3.new(L, D * 0.9, D * 0.44), p.CFrame, p.Name .. "_VoxC")
		visualBlock(p, Vector3.new(L, D * 0.44, D * 0.9), p.CFrame, p.Name .. "_VoxD")
		added += 2
	end
	return 1, added
end

-- WedgePart in its own space: bottom at -Y, the tall vertical face at +Z, the slope runs from the top-back edge
-- (y = +h/2, z = +d/2) down to the bottom-front edge (y = -h/2, z = -d/2)
local function wedge(p)
	local s = p.Size
	local n = math.clamp(math.floor(math.max(s.Y, s.Z) / 3), 2, 4)
	local dz = s.Z / n
	for k = 0, n - 1 do
		local h = s.Y * (k + 0.5) / n
		visualBlock(p, Vector3.new(s.X, h, dz), p.CFrame * CFrame.new(0, -s.Y / 2 + h / 2, -s.Z / 2 + (k + 0.5) * dz), p.Name .. "_Step")
	end
	p.Transparency = 1
	p.CastShadow = false
	return 1, n
end

function V.Run(root)
	local t0 = os.clock()
	local changed, added = 0, 0
	local list = {}
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.98 and not d:GetAttribute("NoVoxel") and not d:GetAttribute("MesaId") then
			if d.ClassName == "Part" and (d.Shape == Enum.PartType.Ball or d.Shape == Enum.PartType.Cylinder) then
				table.insert(list, d)
			elseif d.ClassName == "WedgePart" then
				table.insert(list, d)
			end
		end
	end
	for _, d in ipairs(list) do
		local c, a = 0, 0
		if d.ClassName == "WedgePart" then
			c, a = wedge(d)
		elseif d.Shape == Enum.PartType.Ball then
			c, a = ball(d)
		else
			c, a = cylinder(d)
		end
		changed += c
		added += a
	end
	print(string.format("[Voxelize] %d parts turned voxel (+%d step blocks) in %.2fs", changed, added, os.clock() - t0))
	return changed, added
end

return V
