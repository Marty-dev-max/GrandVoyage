-- VoxelAvatar (owner, v0.22.6): every player's own avatar, turned into the game's voxel style.
--  * body: the standard blocky R15 body (PlayerService.normalizeAvatar), their shirt / pants / skin colors kept;
--    layered 3D clothing is dropped (it cannot be made blocky)
--  * head: a cube with their face picture on the front (the face stays an image, like the owner's reference)
--  * hair, hats and other accessories: rebuilt from blocks. The game may not read other creators' meshes or textures,
--    so the SHAPE is sampled by raycasting the accessory (entry/exit along rows -> filled voxels, rows merged into
--    long blocks) and the COLOR is read from the item's name ("Black Messy Hair" -> black), with lighter highlight
--    blocks and a few spiky blocks on top. If the raycasts only see a box, a rounded cap of that size is used instead.
-- Called by PlayerService after the avatar is normalized (GameConfig.VoxelAvatars).
local Workspace = game:GetService("Workspace")

local VA = {}

local NAMED_COLORS = {
	{ "platinum", Color3.fromRGB(236, 228, 206) }, { "blonde", Color3.fromRGB(240, 206, 110) }, { "blond", Color3.fromRGB(240, 206, 110) },
	{ "golden", Color3.fromRGB(232, 182, 60) }, { "gold", Color3.fromRGB(232, 182, 60) }, { "ginger", Color3.fromRGB(214, 110, 46) },
	{ "orange", Color3.fromRGB(236, 128, 46) }, { "auburn", Color3.fromRGB(150, 62, 40) }, { "red", Color3.fromRGB(196, 42, 46) },
	{ "crimson", Color3.fromRGB(170, 24, 40) }, { "pink", Color3.fromRGB(246, 150, 196) }, { "rose", Color3.fromRGB(232, 120, 160) },
	{ "purple", Color3.fromRGB(130, 70, 200) }, { "violet", Color3.fromRGB(150, 90, 220) }, { "lavender", Color3.fromRGB(190, 160, 236) },
	{ "navy", Color3.fromRGB(30, 40, 96) }, { "blue", Color3.fromRGB(46, 96, 210) }, { "teal", Color3.fromRGB(30, 150, 150) },
	{ "cyan", Color3.fromRGB(80, 210, 230) }, { "mint", Color3.fromRGB(150, 230, 190) }, { "green", Color3.fromRGB(60, 160, 70) },
	{ "lime", Color3.fromRGB(150, 220, 60) }, { "silver", Color3.fromRGB(196, 200, 210) }, { "grey", Color3.fromRGB(130, 132, 140) },
	{ "gray", Color3.fromRGB(130, 132, 140) }, { "white", Color3.fromRGB(244, 244, 244) }, { "snow", Color3.fromRGB(244, 244, 244) },
	{ "chestnut", Color3.fromRGB(110, 60, 34) }, { "brunette", Color3.fromRGB(86, 52, 32) }, { "brown", Color3.fromRGB(96, 60, 36) },
	{ "chocolate", Color3.fromRGB(76, 44, 28) }, { "dark", Color3.fromRGB(34, 30, 36) }, { "black", Color3.fromRGB(24, 22, 28) },
	{ "raven", Color3.fromRGB(24, 22, 34) }, { "midnight", Color3.fromRGB(26, 26, 52) },
}

local function colorFromName(name, fallback)
	local n = string.lower(name or "")
	for _, e in ipairs(NAMED_COLORS) do
		if string.find(n, e[1], 1, true) then
			return e[2]
		end
	end
	return fallback
end

local function isHair(acc)
	local ok, t = pcall(function()
		return acc.AccessoryType
	end)
	if ok and t == Enum.AccessoryType.Hair then
		return true
	end
	return string.find(string.lower(acc.Name), "hair", 1, true) ~= nil
end

-- filled voxels of a part, sampled with rays along its local X axis; returns grid info or nil
local function sample(handle, voxel)
	local size = handle.Size
	local nx, ny, nz = math.max(1, math.ceil(size.X / voxel)), math.max(1, math.ceil(size.Y / voxel)), math.max(1, math.ceil(size.Z / voxel))
	if nx * ny * nz > 9000 then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { handle }
	local oldQuery = handle.CanQuery
	handle.CanQuery = true
	local cf = handle.CFrame
	local half = size / 2
	local filled, count = {}, 0
	for iy = 0, ny - 1 do
		for iz = 0, nz - 1 do
			local ly = -half.Y + (iy + 0.5) * voxel
			local lz = -half.Z + (iz + 0.5) * voxel
			local a = cf:PointToWorldSpace(Vector3.new(-half.X - 0.5, ly, lz))
			local b = cf:PointToWorldSpace(Vector3.new(half.X + 0.5, ly, lz))
			local h1 = Workspace:Raycast(a, b - a, params)
			local h2 = h1 and Workspace:Raycast(b, a - b, params)
			if h1 and h2 then
				local x1 = cf:PointToObjectSpace(h1.Position).X
				local x2 = cf:PointToObjectSpace(h2.Position).X
				local i1 = math.clamp(math.floor((x1 + half.X) / voxel), 0, nx - 1)
				local i2 = math.clamp(math.floor((x2 + half.X) / voxel), 0, nx - 1)
				for ix = math.min(i1, i2), math.max(i1, i2) do
					filled[ix + iy * nx + iz * nx * ny] = true
					count += 1
				end
			end
		end
	end
	handle.CanQuery = oldQuery
	return { nx = nx, ny = ny, nz = nz, filled = filled, count = count, voxel = voxel, size = size }
end

-- a rounded cap filling the part's box (used when the raycasts only see a box, or nothing)
local function cap(handle, voxel, hair, head)
	local size = handle.Size
	local nx, ny, nz = math.max(1, math.ceil(size.X / voxel)), math.max(1, math.ceil(size.Y / voxel)), math.max(1, math.ceil(size.Z / voxel))
	local filled, count = {}, 0
	local cf = handle.CFrame
	for ix = 0, nx - 1 do
		for iy = 0, ny - 1 do
			for iz = 0, nz - 1 do
				local u = ((ix + 0.5) / nx) * 2 - 1
				local v = ((iy + 0.5) / ny) * 2 - 1
				local w = ((iz + 0.5) / nz) * 2 - 1
				local inside = u * u + v * v + w * w <= 1.05
				if inside and hair and head then
					-- keep the face clear: no hair in front of and below the eyes
					local p = cf:PointToWorldSpace(Vector3.new(-size.X / 2 + (ix + 0.5) * voxel, -size.Y / 2 + (iy + 0.5) * voxel, -size.Z / 2 + (iz + 0.5) * voxel))
					local rel = head.CFrame:PointToObjectSpace(p)
					if rel.Z < -head.Size.Z * 0.2 and rel.Y < head.Size.Y * 0.2 then
						inside = false
					end
				end
				if inside then
					filled[ix + iy * nx + iz * nx * ny] = true
					count += 1
				end
			end
		end
	end
	return { nx = nx, ny = ny, nz = nz, filled = filled, count = count, voxel = voxel, size = size }
end

local function newBlock(parent, size, cf, color)
	local p = Instance.new("Part")
	p.Name = "Voxel"
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	p.Parent = parent
	return p
end

-- grid -> merged rows of blocks, welded to `limb`
local function build(grid, handle, color, limb, model, rng, spiky)
	local nx, ny, nz, v = grid.nx, grid.ny, grid.nz, grid.voxel
	local half = grid.size / 2
	local cf = handle.CFrame
	local light = color:Lerp(Color3.new(1, 1, 1), 0.28)
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.25)
	local n = 0
	for iy = 0, ny - 1 do
		for iz = 0, nz - 1 do
			local ix = 0
			while ix < nx do
				if grid.filled[ix + iy * nx + iz * nx * ny] then
					local start = ix
					while ix < nx and grid.filled[ix + iy * nx + iz * nx * ny] do
						ix += 1
					end
					local len = ix - start
					local lx = -half.X + (start + len / 2) * v
					local ly = -half.Y + (iy + 0.5) * v
					local lz = -half.Z + (iz + 0.5) * v
					local roll = rng:NextNumber()
					local c = roll < 0.14 and light or (roll > 0.86 and dark or color)
					local b = newBlock(model, Vector3.new(len * v, v, v), cf * CFrame.new(lx, ly, lz), c)
					local w = Instance.new("WeldConstraint")
					w.Part0 = limb
					w.Part1 = b
					w.Parent = b
					n += 1
					-- spiky top: a few chunky blocks poking up from the top layer
					local above = iy + 1 < ny and grid.filled[start + (iy + 1) * nx + iz * nx * ny]
					if spiky and not above and iy >= ny * 0.45 and rng:NextNumber() < 0.35 then
						local s = v * rng:NextNumber(1.1, 1.8)
						local tip = newBlock(model, Vector3.new(s, s * rng:NextNumber(1, 1.6), s), cf * CFrame.new(lx + rng:NextNumber(-0.3, 0.3) * len * v, ly + s * 0.6, lz) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4)), rng:NextNumber() < 0.3 and light or color)
						local w2 = Instance.new("WeldConstraint")
						w2.Part0 = limb
						w2.Part1 = tip
						w2.Parent = tip
						n += 1
					end
				else
					ix += 1
				end
			end
		end
	end
	return n
end

local function limbOf(handle)
	for _, j in ipairs(handle:GetChildren()) do
		if j:IsA("JointInstance") or j:IsA("WeldConstraint") then
			local other = j.Part0 == handle and j.Part1 or j.Part0
			if other and other ~= handle then
				return other
			end
		end
	end
	return nil
end

-- the cube head with the face picture
local function cubeHead(char)
	local head = char:FindFirstChild("Head")
	if not head or char:FindFirstChild("VoxelHead") then
		return head
	end
	local s = math.max(head.Size.X, head.Size.Z) * 1.04
	local cube = newBlock(char, Vector3.new(s, s, s), head.CFrame, head.Color)
	cube.Name = "VoxelHead"
	local w = Instance.new("WeldConstraint")
	w.Part0 = head
	w.Part1 = cube
	w.Parent = cube
	local face
	for _, d in ipairs(head:GetChildren()) do
		if d:IsA("Decal") then
			face = d
			break
		end
	end
	local decal = Instance.new("Decal")
	decal.Name = "face"
	decal.Face = Enum.NormalId.Front
	decal.Texture = face and face.Texture or "rbxasset://textures/face.png"
	decal.Parent = cube
	if face then
		face.Transparency = 1
	end
	head.Transparency = 1
	-- the skin tone follows the head (BodyColors may arrive late)
	head:GetPropertyChangedSignal("Color"):Connect(function()
		cube.Color = head.Color
	end)
	return head
end

function VA.Apply(char)
	if char:GetAttribute("Voxelized") then
		return
	end
	char:SetAttribute("Voxelized", true)
	local head = cubeHead(char)
	local model = Instance.new("Model")
	model.Name = "VoxelGear"
	model.Parent = char
	local rng = Random.new(#char.Name * 131 + 7)
	local made, blocks = 0, 0
	for _, acc in ipairs(char:GetChildren()) do
		if acc:IsA("Accessory") then
			local handle = acc:FindFirstChild("Handle")
			local limb = handle and limbOf(handle)
			if handle and handle:IsA("BasePart") and limb then
				local hair = isHair(acc)
				local maxDim = math.max(handle.Size.X, handle.Size.Y, handle.Size.Z)
				-- chunky blocks like the owner's reference (about 5-6 across a hairdo)
				local voxel = math.clamp(maxDim / (hair and 5.5 or 4.5), 0.3, 0.65)
				local okSample, grid = pcall(sample, handle, voxel)
				if not okSample then
					grid = nil
				end
				local total = grid and (grid.nx * grid.ny * grid.nz) or 1
				if not grid or grid.count == 0 or grid.count / total > 0.88 then
					-- the raycasts saw nothing or just a box: a rounded cap of that size reads better
					grid = cap(handle, voxel, hair, head)
				end
				local color = colorFromName(acc.Name, hair and Color3.fromRGB(70, 44, 30) or handle.Color)
				if color == Color3.new(1, 1, 1) and not hair then
					color = Color3.fromRGB(200, 200, 205)
				end
				local ok, n = pcall(build, grid, handle, color, limb, model, rng, hair)
				if ok then
					acc:Destroy()
					blocks += n
					made += 1
				else
					warn("[VoxelAvatar] " .. acc.Name .. ": " .. tostring(n))
				end
			end
		end
	end
	print(string.format("[VoxelAvatar] %s: cube head + %d accessories rebuilt from %d blocks", char.Name, made, blocks))
end

VA._cap, VA._build, VA._colorFromName = cap, build, colorFromName -- for the offline preview (tools)

return VA
