-- Kit: low-poly prop library used to dress the islands.
-- Every builder places parts under Kit.parent. Small purely-visual props are tagged "Decor"
-- (CanQuery off) so the client graphics settings can hide them on low-end devices and so
-- mouse clicks / monster ground raycasts pass through foliage.
local CollectionService = game:GetService("CollectionService")

local Kit = {}
Kit.parent = nil
-- Kit.rng is a thin proxy so one island can be built with its own stream (Kit.WithRng) without shifting the
-- random layout of every island built after it.
local rngInner = Random.new(1234)
local rngProxy = {}
function rngProxy:NextNumber(a, b)
	if a == nil then
		return rngInner:NextNumber()
	end
	return rngInner:NextNumber(a, b)
end
function rngProxy:NextInteger(a, b)
	return rngInner:NextInteger(a, b)
end
Kit.rng = rngProxy
local rng = Kit.rng

function Kit.WithRng(r, fn)
	local prev = rngInner
	rngInner = r
	local ok, err = pcall(fn)
	rngInner = prev
	if not ok then
		error(err, 0)
	end
end

local M = Enum.Material
Kit.Colors = {
	Wood = Color3.fromRGB(150, 98, 58),
	DarkWood = Color3.fromRGB(104, 66, 40),
	LightWood = Color3.fromRGB(206, 152, 96),
	Stone = Color3.fromRGB(176, 172, 166),
	DarkStone = Color3.fromRGB(122, 120, 122),
	Glass = Color3.fromRGB(170, 222, 255),
	Leaf = Color3.fromRGB(78, 188, 82),
	Leaf2 = Color3.fromRGB(118, 214, 92),
	Pine = Color3.fromRGB(46, 140, 82),
	Trunk = Color3.fromRGB(140, 94, 56),
	White = Color3.fromRGB(250, 248, 242),
	Marine = Color3.fromRGB(62, 124, 224),
	Orange = Color3.fromRGB(255, 150, 40),
	Rope = Color3.fromRGB(214, 186, 132),
}
local C = Kit.Colors

-- ===== primitives =====
function Kit.P(size, color, cf, opts)
	opts = opts or {}
	local p = Instance.new(opts.class or "Part")
	if opts.shape then
		p.Shape = opts.shape
	end
	p.Size = size
	p.Color = color
	p.Material = opts.material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = opts.collide ~= false
	p.CastShadow = opts.shadow ~= false
	if opts.transparency then
		p.Transparency = opts.transparency
	end
	if opts.reflectance then
		p.Reflectance = opts.reflectance
	end
	if opts.name then
		p.Name = opts.name
	end
	if opts.decor then
		p.CanQuery = false
		p.CanTouch = false
		CollectionService:AddTag(p, "Decor")
	end
	p.Parent = opts.parent or Kit.parent
	return p
end
local P = Kit.P

function Kit.Cyl(height, diameter, color, pos, opts)
	opts = opts or {}
	opts.shape = Enum.PartType.Cylinder
	return P(Vector3.new(height, diameter, diameter), color, CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), opts)
end
local Cyl = Kit.Cyl

-- Cylinder along an arbitrary CFrame's Y axis
function Kit.CylCF(height, diameter, color, cf, opts)
	opts = opts or {}
	opts.shape = Enum.PartType.Cylinder
	return P(Vector3.new(height, diameter, diameter), color, cf * CFrame.Angles(0, 0, math.pi / 2), opts)
end
local CylCF = Kit.CylCF

function Kit.Ball(d, color, pos, opts)
	opts = opts or {}
	opts.shape = Enum.PartType.Ball
	return P(Vector3.new(d, d, d), color, CFrame.new(pos), opts)
end
local Ball = Kit.Ball

function Kit.Wedge(size, color, cf, opts)
	opts = opts or {}
	opts.class = "WedgePart"
	return P(size, color, cf, opts)
end
local Wedge = Kit.Wedge

local function decor(opts)
	opts = opts or {}
	opts.decor = true
	return opts
end
Kit.decor = decor

function Kit.Model(name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = Kit.parent
	return m
end

-- Run fn with Kit.parent temporarily set to a new model
function Kit.Group(name, fn)
	local prev = Kit.parent
	local m = Kit.Model(name)
	Kit.parent = m
	fn(m)
	Kit.parent = prev
	return m
end

-- ===== stylized 3D props =====
-- Trees, bushes, boulders and cliff walls are built here as simple part placeholders and tagged; at runtime the server
-- (AssetService.DressWorld) swaps them for the stylized Blender meshes (tools/blender/envkit.py). Parts marked with the
-- "Collider" attribute stay as invisible collision. If the meshes are not loaded the placeholders remain visible.
local function prop(kind, base, height, fn)
	local m = Instance.new("Model")
	m.Name = kind
	m:SetAttribute("Kind", kind)
	m:SetAttribute("Base", base)
	m:SetAttribute("Height", height)
	m.Parent = Kit.parent
	local prev = Kit.parent
	Kit.parent = m
	fn()
	Kit.parent = prev
	CollectionService:AddTag(m, "EnvProp")
	return m
end

-- ===== signs =====
function Kit.Sign(text, cf, size, textColor, bg, opts)
	local board = P(Vector3.new(size.X, size.Y, 0.6), bg or C.Wood, cf, { material = M.Wood })
	P(Vector3.new(size.X + 0.8, 0.5, 0.8), C.DarkWood, cf * CFrame.new(0, size.Y / 2 + 0.2, 0), decor({ material = M.Wood }))
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.PixelsPerStud = 30
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.LightInfluence = 0.4
		gui.Parent = board
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.FontFace = Font.fromEnum(Enum.Font.Arcade)
		t.TextScaled = true
		t.Text = text
		t.TextColor3 = textColor or Color3.fromRGB(255, 240, 200)
		t.Parent = gui
		local st = Instance.new("UIStroke")
		st.Thickness = 3
		st.Color = Color3.fromRGB(40, 28, 20)
		st.Parent = t
	end
	return board
end

function Kit.PostSign(text, pos, facing, width)
	width = width or 10
	local cf = CFrame.lookAt(pos, pos + facing)
	P(Vector3.new(0.7, 7, 0.7), C.DarkWood, cf * CFrame.new(0, 3.5, 0), { material = M.Wood })
	Kit.Sign(text, cf * CFrame.new(0, 7, 0), Vector2.new(width, 2.6))
end

-- ===== nature =====
function Kit.Palm(pos, height)
	height = height or rng:NextNumber(16, 24)
	return prop("Palm", pos, height + 2, function()
		Kit._palm(pos, height)
	end)
end

function Kit._palm(pos, height)
	local lean = rng:NextNumber(-0.3, 0.3)
	local yaw = rng:NextNumber(0, math.pi * 2)
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local top = pos
	for i = 0, 5 do
		local seg = P(Vector3.new(1.7 - i * 0.14, height / 6 + 0.4, 1.7 - i * 0.14), C.Trunk:Lerp(Color3.fromRGB(110, 72, 40), (i % 2) * 0.45), base * CFrame.new(lean * i * 1.6, height / 6 * (i + 0.5), 0) * CFrame.Angles(0, 0, -lean * 0.35), { material = M.Wood })
		top = seg.CFrame.Position + Vector3.new(0, height / 12, 0)
		if i == 0 then
			seg:SetAttribute("Collider", true)
		end
	end
	for i = 0, 6 do
		local a = i / 7 * math.pi * 2
		Wedge(Vector3.new(0.4, 2.4, 9), (i % 2 == 0 and C.Leaf or C.Leaf2), CFrame.new(top) * CFrame.Angles(0, a, 0) * CFrame.new(0, -0.4, -4.4) * CFrame.Angles(-0.4, 0, math.pi / 2), decor({ collide = false, material = M.Grass }))
	end
	for i = 1, 3 do
		Ball(1.4, Color3.fromRGB(120, 80, 40), top + Vector3.new(math.cos(i * 2) * 0.9, -1, math.sin(i * 2) * 0.9), decor({ collide = false }))
	end
end

function Kit.RoundTree(pos, scale, color, fruit)
	scale = scale or 1
	return prop("BroadTree", pos, 14 * scale, function()
		Kit._roundTree(pos, scale, color, fruit)
	end)
end

function Kit._roundTree(pos, scale, color, fruit)
	color = color or C.Leaf
	P(Vector3.new(1.6, 7, 1.6) * scale, C.Trunk, CFrame.new(pos + Vector3.new(0, 3.5 * scale, 0)), { material = M.Wood }):SetAttribute("Collider", true)
	local crown = pos + Vector3.new(0, 9 * scale, 0)
	Ball(9 * scale, color, crown, decor({ material = M.Grass }))
	Ball(6.5 * scale, color:Lerp(Color3.new(1, 1, 0.7), 0.15), crown + Vector3.new(2, 2.4, 1) * scale, decor({ collide = false, material = M.Grass }))
	Ball(5.5 * scale, color:Lerp(Color3.new(0, 0.2, 0), 0.12), crown + Vector3.new(-2.4, 0.8, -1.5) * scale, decor({ collide = false, material = M.Grass }))
	if fruit then
		for i = 1, 9 do
			local a = i * 2.4
			Ball(1.1 * scale, fruit, crown + Vector3.new(math.cos(a) * 4.2, math.sin(i * 1.7) * 2.5, math.sin(a) * 4.2) * scale, decor({ collide = false }))
		end
	end
end

function Kit.PineTree(pos, scale)
	scale = scale or 1
	return prop("Pine", pos, 17 * scale, function()
		Kit._pine(pos, scale)
	end)
end

function Kit._pine(pos, scale)
	P(Vector3.new(1.4, 5, 1.4) * scale, C.Trunk, CFrame.new(pos + Vector3.new(0, 2.5 * scale, 0)), { material = M.Wood }):SetAttribute("Collider", true)
	for i = 0, 3 do
		local d = (9 - i * 2) * scale
		Cyl(3.2 * scale, d, C.Pine:Lerp(C.Leaf2, i * 0.08), pos + Vector3.new(0, (5 + i * 2.8) * scale, 0), decor({ material = M.Grass }))
	end
	Ball(1.6 * scale, C.Pine, pos + Vector3.new(0, 15.5 * scale, 0), decor())
end

function Kit.Bush(pos, size, color)
	size = size or 4
	return prop("Bush", pos, size * 1.15, function()
		Kit._bush(pos, size, color)
	end)
end

function Kit._bush(pos, size, color)
	color = color or C.Leaf2
	for i = 1, 3 do
		Ball(size * rng:NextNumber(0.7, 1), color:Lerp(Color3.new(0, 0.25, 0), rng:NextNumber(0, 0.2)), pos + Vector3.new(rng:NextNumber(-1, 1) * size * 0.4, size * 0.25, rng:NextNumber(-1, 1) * size * 0.4), decor({ collide = false, material = M.Grass }))
	end
end

local flowerColors = { Color3.fromRGB(255, 110, 140), Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 255, 255), Color3.fromRGB(180, 120, 255), Color3.fromRGB(255, 150, 60) }
-- a single stylized plant (Assets.Env kind: Flowers, LeafPlant, Fern, GrassTuft, Mushroom) standing on `base`; the
-- ball is only the placeholder until DressWorld swaps in the mesh. No rng.
function Kit.Plant(kind, base, height, color)
	return prop(kind, base, height, function()
		Ball(height * 0.7, color or C.Leaf, base + Vector3.new(0, height * 0.4, 0), decor({ collide = false, shadow = false, material = M.Grass }))
	end)
end

-- Each flower is an EnvProp "Flowers": DressWorld swaps the stem + ball placeholder for the petal flower meshes
-- (Assets.Env/Flowers_n), like the plants Greenery scatters (owner, v0.22.4: the round ball flowers looked wrong).
-- Same rng calls as before (2 numbers + 1 integer per flower) so every island keeps its layout.
function Kit.Flowers(pos, radius, count)
	for _ = 1, count or 8 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(0, radius or 4)
		local p = pos + Vector3.new(math.cos(a) * r, 0.5, math.sin(a) * r)
		local color = flowerColors[rng:NextInteger(1, #flowerColors)]
		prop("Flowers", p - Vector3.new(0, 0.5, 0), 1.4, function()
			P(Vector3.new(0.2, 1, 0.2), C.Leaf, CFrame.new(p), decor({ collide = false, shadow = false }))
			Ball(0.8, color, p + Vector3.new(0, 0.6, 0), decor({ collide = false, shadow = false }))
		end)
	end
end

function Kit.Rock(pos, size, color)
	local p = P(Vector3.new(size, size * 0.7, size * 0.9), color or C.DarkStone:Lerp(C.Stone, rng:NextNumber()), CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 0.25), rng:NextNumber(0, 6.28), rng:NextNumber(0, 0.25)), { material = M.Slate })
	p:SetAttribute("Kind", "Boulder")
	CollectionService:AddTag(p, "EnvPart")
	return p
end

function Kit.RockCluster(pos, size)
	Kit.Rock(pos, size)
	for i = 1, 3 do
		Kit.Rock(pos + Vector3.new(math.cos(i * 2.1) * size * 0.6, -size * 0.1, math.sin(i * 2.1) * size * 0.6), size * rng:NextNumber(0.4, 0.65))
	end
end

-- ===== town props =====
-- v0.25.113 (owner: the map barrels were plain blocky posts, make them like the title-menu ones): a bulging voxel
-- barrel = octagon slices (two crossed blocks each), iron hoops, a plank lid. No rng (keeps every island's stream).
function Kit.Barrel(pos)
	local k = 1.12
	local cf = CFrame.new(pos)
	local staves, hoop = Color3.fromRGB(150, 92, 50), Color3.fromRGB(58, 50, 46)
	for i, w in ipairs({ 1.45, 1.75, 1.9, 1.9, 1.75, 1.45 }) do
		local y = (i - 0.5) * 0.4 * k
		local c = i % 2 == 0 and staves or staves:Lerp(Color3.new(0, 0, 0), 0.1)
		local solid = i == 3 or i == 4
		P(Vector3.new(w, 0.4, w * 0.72) * k, c, cf * CFrame.new(0, y, 0), decor({ material = M.WoodPlanks, collide = solid }))
		P(Vector3.new(w * 0.72, 0.4, w) * k, c, cf * CFrame.new(0, y, 0), decor({ material = M.WoodPlanks, collide = solid }))
	end
	for _, y in ipairs({ 0.3, 1.2, 2.1 }) do
		P(Vector3.new(1.96, 0.16, 1.4) * k, hoop, cf * CFrame.new(0, y * k, 0), decor({ material = M.Metal, collide = false }))
		P(Vector3.new(1.4, 0.16, 1.96) * k, hoop, cf * CFrame.new(0, y * k, 0), decor({ material = M.Metal, collide = false }))
	end
	P(Vector3.new(1.2, 0.1, 1.2) * k, Color3.fromRGB(176, 120, 70), cf * CFrame.new(0, 2.43 * k, 0), decor({ material = M.WoodPlanks, collide = false }))
	P(Vector3.new(1.2, 0.12, 0.12) * k, Color3.fromRGB(110, 70, 40), cf * CFrame.new(0, 2.47 * k, 0), decor({ material = M.Wood, collide = false }))
end

-- v0.25.113: crates get a dark frame (corner posts + top and bottom rims) and a plank face, like voxel crates
function Kit.Crate(pos, size, yaw)
	size = size or 2.4
	local cf = CFrame.new(pos + Vector3.new(0, size / 2, 0)) * CFrame.Angles(0, yaw or rng:NextNumber(0, 1.5), 0)
	P(Vector3.one * size, C.LightWood, cf, decor({ material = M.WoodPlanks }))
	local h, e = size / 2, 0.32
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			P(Vector3.new(e, size + 0.06, e), C.DarkWood, cf * CFrame.new(sx * (h - e / 2 + 0.04), 0, sz * (h - e / 2 + 0.04)), decor({ material = M.Wood, collide = false }))
		end
	end
	for _, y in ipairs({ -1, 1 }) do
		P(Vector3.new(size + 0.08, e, e), C.DarkWood, cf * CFrame.new(0, y * (h - e / 2 + 0.03), -h + e / 2 - 0.05), decor({ material = M.Wood, collide = false }))
		P(Vector3.new(size + 0.08, e, e), C.DarkWood, cf * CFrame.new(0, y * (h - e / 2 + 0.03), h - e / 2 + 0.05), decor({ material = M.Wood, collide = false }))
		P(Vector3.new(e, e, size + 0.08), C.DarkWood, cf * CFrame.new(-h + e / 2 - 0.05, y * (h - e / 2 + 0.03), 0), decor({ material = M.Wood, collide = false }))
		P(Vector3.new(e, e, size + 0.08), C.DarkWood, cf * CFrame.new(h - e / 2 + 0.05, y * (h - e / 2 + 0.03), 0), decor({ material = M.Wood, collide = false }))
	end
end

function Kit.CrateStack(pos)
	Kit.Crate(pos, 2.6)
	Kit.Crate(pos + Vector3.new(2.8, 0, 0.4), 2.4)
	Kit.Crate(pos + Vector3.new(1.3, 2.6, 0.2), 2.2)
	Kit.Barrel(pos + Vector3.new(-2.2, 0, 1.6))
end

function Kit.Lamp(pos)
	P(Vector3.new(0.5, 8, 0.5), Color3.fromRGB(50, 50, 58), CFrame.new(pos + Vector3.new(0, 4, 0)), decor({ material = M.Metal }))
	local bulb = P(Vector3.new(1.4, 1.6, 1.4), Color3.fromRGB(255, 220, 140), CFrame.new(pos + Vector3.new(0, 8.6, 0)), decor({ material = M.Neon, collide = false }))
	Wedge(Vector3.new(2, 0.8, 1), Color3.fromRGB(50, 50, 58), CFrame.new(pos + Vector3.new(0, 9.7, 0.5)), decor({ collide = false }))
	Wedge(Vector3.new(2, 0.8, 1), Color3.fromRGB(50, 50, 58), CFrame.new(pos + Vector3.new(0, 9.7, -0.5)) * CFrame.Angles(0, math.pi, 0), decor({ collide = false }))
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 210, 140)
	light.Parent = bulb
	CollectionService:AddTag(light, "TownLight")
end

function Kit.Bench(cf)
	P(Vector3.new(5, 0.4, 1.6), C.LightWood, cf * CFrame.new(0, 1.4, 0), decor({ material = M.Wood }))
	P(Vector3.new(5, 1.4, 0.3), C.LightWood, cf * CFrame.new(0, 2.3, 0.7), decor({ material = M.Wood }))
	for _, x in ipairs({ -2, 2 }) do
		P(Vector3.new(0.4, 1.4, 1.4), C.DarkWood, cf * CFrame.new(x, 0.7, 0), decor())
	end
end

function Kit.Fence(a, b, color)
	color = color or C.LightWood
	local dir = b - a
	local len = dir.Magnitude
	local n = math.max(1, math.floor(len / 4))
	for i = 0, n do
		local p = a + dir * (i / n)
		P(Vector3.new(0.6, 3.2, 0.6), color, CFrame.new(p + Vector3.new(0, 1.6, 0)), decor({ material = M.Wood }))
	end
	local mid = a + dir / 2
	for _, y in ipairs({ 1.2, 2.5 }) do
		P(Vector3.new(0.3, 0.4, len), color, CFrame.lookAt(mid + Vector3.new(0, y, 0), b + Vector3.new(0, y, 0)), decor({ material = M.Wood, collide = false }))
	end
end

function Kit.Stall(cf, awning)
	awning = awning or Color3.fromRGB(240, 80, 70)
	P(Vector3.new(7, 2.6, 3), C.LightWood, cf * CFrame.new(0, 1.3, 0), decor({ material = M.WoodPlanks }))
	for _, x in ipairs({ -3.3, 3.3 }) do
		P(Vector3.new(0.4, 6.5, 0.4), C.DarkWood, cf * CFrame.new(x, 3.25, -1.3), decor())
		P(Vector3.new(0.4, 5.5, 0.4), C.DarkWood, cf * CFrame.new(x, 2.75, 1.3), decor())
	end
	for i = 0, 5 do
		P(Vector3.new(1.25, 0.25, 4.4), (i % 2 == 0) and awning or C.White, cf * CFrame.new(-3.1 + i * 1.24, 6.2, 0) * CFrame.Angles(0.25, 0, 0), decor({ material = M.Fabric, collide = false }))
	end
	for i = 1, 4 do
		Ball(0.9, flowerColors[i], (cf * CFrame.new(-2.4 + i * 1.1, 2.9, 0)).Position, decor({ collide = false }))
	end
end

function Kit.Flag(pos, color, height, emblem)
	height = height or 14
	P(Vector3.new(0.5, height, 0.5), Color3.fromRGB(230, 230, 236), CFrame.new(pos + Vector3.new(0, height / 2, 0)), { material = M.Metal })
	Ball(0.9, Color3.fromRGB(255, 210, 60), pos + Vector3.new(0, height + 0.3, 0), decor())
	local f = P(Vector3.new(5, 3.2, 0.15), color, CFrame.new(pos + Vector3.new(2.6, height - 1.8, 0)), decor({ material = M.Fabric, collide = false }))
	if emblem then
		Ball(1.4, Color3.new(1, 1, 1), f.CFrame.Position + Vector3.new(0, 0, -0.1), decor({ collide = false }))
	end
	return f
end

-- Triangle bunting between two points
function Kit.Bunting(a, b, colors)
	colors = colors or { Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 220, 60), Color3.fromRGB(80, 170, 255), Color3.fromRGB(110, 220, 110) }
	local dir = b - a
	local len = dir.Magnitude
	local mid = a + dir / 2 - Vector3.new(0, 1.2, 0)
	P(Vector3.new(0.12, 0.12, len), C.Rope, CFrame.lookAt(mid, mid + dir), decor({ collide = false, shadow = false }))
	local n = math.floor(len / 2.2)
	for i = 1, n - 1 do
		local t = i / n
		local sag = math.sin(t * math.pi) * 1.4
		local p = a:Lerp(b, t) - Vector3.new(0, sag, 0)
		Wedge(Vector3.new(0.1, 1.4, 1.2), colors[i % #colors + 1], CFrame.lookAt(p, p + dir) * CFrame.new(0, -0.8, 0) * CFrame.Angles(math.pi, 0, 0), decor({ collide = false, shadow = false, material = M.Fabric }))
	end
end

function Kit.Rowboat(cf, color)
	color = color or Color3.fromRGB(196, 120, 72)
	P(Vector3.new(3.4, 1.2, 8), color, cf * CFrame.new(0, 0.4, 0), decor({ material = M.WoodPlanks }))
	Wedge(Vector3.new(3.4, 1.2, 2.4), color, cf * CFrame.new(0, 0.4, -5.2) * CFrame.Angles(0, math.pi, math.pi), decor())
	P(Vector3.new(3.6, 0.3, 8.4), C.White, cf * CFrame.new(0, 1.05, 0), decor({ collide = false }))
	P(Vector3.new(3.2, 0.3, 1), C.DarkWood, cf * CFrame.new(0, 0.9, 1), decor({ collide = false }))
end

-- ===== buildings =====
-- house: ground-center CFrame (door faces -Z). opts: floors, chimney, sign, shutter, stone
function Kit.House(cf, w, d, wall, roof, opts)
	opts = opts or {}
	local floors = opts.floors or 1
	local fh = opts.floorHeight or 9
	local trim = opts.trim or C.DarkWood
	local shutter = opts.shutter or roof:Lerp(Color3.new(1, 1, 1), 0.25)
	local h = fh * floors
	P(Vector3.new(w + 1.2, 1.2, d + 1.2), opts.stone or C.Stone, cf * CFrame.new(0, 0.6, 0), { material = M.Cobblestone })
	local hollow = opts.hollow
	local DW, DH = 6, 7.6 -- open doorway of an enterable house
	if hollow then
		local t = 1
		local y0 = 1.2 + fh / 2
		P(Vector3.new(w, fh, t), wall, cf * CFrame.new(0, y0, d / 2 - t / 2), { material = M.Plaster })
		for _, sx in ipairs({ -1, 1 }) do
			P(Vector3.new(t, fh, d - 2 * t), wall, cf * CFrame.new(sx * (w / 2 - t / 2), y0, 0), { material = M.Plaster })
			local pw = (w - DW) / 2
			P(Vector3.new(pw, fh, t), wall, cf * CFrame.new(sx * (DW / 2 + pw / 2), y0, -d / 2 + t / 2), { material = M.Plaster })
		end
		P(Vector3.new(DW, fh - DH, t), wall, cf * CFrame.new(0, 1.2 + DH + (fh - DH) / 2, -d / 2 + t / 2), { material = M.Plaster })
		if floors > 1 then
			P(Vector3.new(w, h - fh, d), wall, cf * CFrame.new(0, 1.2 + fh + (h - fh) / 2, 0), { material = M.Plaster })
		else
			P(Vector3.new(w, 0.8, d), wall, cf * CFrame.new(0, 1.2 + fh - 0.4, 0), { material = M.Plaster })
		end
		-- ceiling beams + plank floor
		P(Vector3.new(w - 2 * t, 0.2, d - 2 * t), Color3.fromRGB(150, 102, 64), cf * CFrame.new(0, 1.3, 0), { material = M.WoodPlanks })
		for i = 1, 3 do
			P(Vector3.new(0.8, 0.7, d - 2 * t), trim, cf * CFrame.new(-w / 2 + w * i / 4, 1.2 + fh - 1.15, 0), decor({ material = M.Wood, collide = false }))
		end
		Kit.Interior(cf, w, d, hollow, fh)
	else
		P(Vector3.new(w, h, d), wall, cf * CFrame.new(0, 1.2 + h / 2, 0), { material = M.Plaster })
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			P(Vector3.new(0.9, h, 0.9), trim, cf * CFrame.new(sx * w / 2, 1.2 + h / 2, sz * d / 2), decor({ material = M.Wood }))
		end
	end
	for f = 1, floors do
		local y = 1.2 + fh * (f - 1)
		P(Vector3.new(w + 0.3, 0.7, d + 0.3), trim, cf * CFrame.new(0, y + fh - 0.2, 0), decor({ material = M.Wood }))
		local wy = y + fh * 0.55
		local cols = math.max(1, math.floor(w / 7))
		for i = 1, cols do
			local x = -w / 2 + w * (i - 0.5) / cols
			if not (f == 1 and math.abs(x) < (hollow and DW / 2 + 1.6 or 2.5)) then
				for _, side in ipairs({ -1, 1 }) do
					local zc = side * (d / 2 + 0.12)
					local frame = cf * CFrame.new(x, wy, zc)
					P(Vector3.new(2.8, 3.2, 0.25), trim, frame, decor())
					P(Vector3.new(2.2, 2.6, 0.3), C.Glass, frame, decor({ material = M.Glass, reflectance = 0.15 }))
					if side < 0 then
						for _, sh in ipairs({ -1, 1 }) do
							P(Vector3.new(0.9, 3.2, 0.2), shutter, frame * CFrame.new(sh * 1.9, 0, -0.1), decor({ collide = false }))
						end
						P(Vector3.new(2.8, 0.6, 0.9), C.LightWood, frame * CFrame.new(0, -1.9, -0.4), decor({ collide = false }))
						for k = -1, 1 do
							Ball(0.7, flowerColors[(i + k + f) % #flowerColors + 1], (frame * CFrame.new(k * 0.9, -1.4, -0.4)).Position, decor({ collide = false, shadow = false }))
						end
					end
				end
			end
		end
	end
	-- half-timbering (opts.timber): studs between the windows, a sill rail per floor and corner braces
	if opts.timber then
		local cols = math.max(1, math.floor(w / 7))
		for f = 1, floors do
			local y = 1.2 + fh * (f - 1)
			for _, side in ipairs({ -1, 1 }) do
				local zc = side * (d / 2 + 0.16)
				for i = 1, cols - 1 do
					local x = -w / 2 + w * i / cols
					if hollow and f == 1 and side < 0 and math.abs(x) < DW / 2 + 0.6 then
						continue
					end
					P(Vector3.new(0.6, fh, 0.25), trim, cf * CFrame.new(x, y + fh / 2, zc), decor({ material = M.Wood, collide = false }))
				end
				if hollow and f == 1 and side < 0 then
					local pw = (w - DW) / 2
					for _, sx in ipairs({ -1, 1 }) do
						P(Vector3.new(pw, 0.45, 0.25), trim, cf * CFrame.new(sx * (DW / 2 + pw / 2), y + fh * 0.28, zc), decor({ material = M.Wood, collide = false }))
					end
				else
					P(Vector3.new(w, 0.45, 0.25), trim, cf * CFrame.new(0, y + fh * 0.28, zc), decor({ material = M.Wood, collide = false }))
				end
				for _, sx in ipairs({ -1, 1 }) do
					local len = math.sqrt(2.6 ^ 2 + (fh * 0.62) ^ 2)
					local ang = math.atan2(fh * 0.62, 2.6)
					P(Vector3.new(len, 0.45, 0.25), trim, cf * CFrame.new(sx * (w / 2 - 1.5), y + fh * 0.6, zc) * CFrame.Angles(0, 0, sx * ang), decor({ material = M.Wood, collide = false }))
				end
			end
			for _, sx in ipairs({ -1, 1 }) do
				local xc = sx * (w / 2 + 0.16)
				P(Vector3.new(0.25, 0.45, d), trim, cf * CFrame.new(xc, y + fh * 0.28, 0), decor({ material = M.Wood, collide = false }))
				P(Vector3.new(0.25, fh, 0.6), trim, cf * CFrame.new(xc, y + fh / 2, 0), decor({ material = M.Wood, collide = false }))
			end
		end
	end
	-- door + step
	if hollow then
		-- open doorway: a thick frame (posts + lintel), the doors swung open against the wall
		for _, sx in ipairs({ -1, 1 }) do
			P(Vector3.new(0.8, DH + 0.8, 0.6), trim, cf * CFrame.new(sx * (DW / 2 + 0.4), 1.2 + (DH + 0.8) / 2, -d / 2 - 0.2), decor({ material = M.Wood }))
			P(Vector3.new(0.3, DH - 0.6, DW / 2 - 0.2), Color3.fromRGB(110, 70, 42), cf * CFrame.new(sx * (DW / 2 + 1.05), 1.2 + (DH - 0.6) / 2, -d / 2 - DW / 4 - 0.4), decor({ material = M.WoodPlanks, collide = false }))
		end
		P(Vector3.new(DW + 2.4, 0.9, 0.7), trim, cf * CFrame.new(0, 1.2 + DH + 0.45, -d / 2 - 0.2), decor({ material = M.Wood }))
		P(Vector3.new(DW + 0.6, 0.5, 2.4), C.Stone, cf * CFrame.new(0, 0.25, -d / 2 - 1.6), { material = M.Cobblestone })
		P(Vector3.new(DW, 0.2, 1.2), Color3.fromRGB(150, 102, 64), cf * CFrame.new(0, 1.1, -d / 2 + 0.5), { material = M.WoodPlanks })
	else
		P(Vector3.new(3.2, 5.6, 0.4), Color3.fromRGB(110, 70, 42), cf * CFrame.new(0, 1.2 + 2.8, -d / 2 - 0.1), { material = M.Wood })
		P(Vector3.new(3.8, 6.2, 0.3), trim, cf * CFrame.new(0, 1.2 + 3, -d / 2 - 0.02), decor())
		Ball(0.4, Color3.fromRGB(255, 210, 80), (cf * CFrame.new(1, 4, -d / 2 - 0.35)).Position, decor({ collide = false }))
		P(Vector3.new(4.6, 0.5, 2), C.Stone, cf * CFrame.new(0, 0.25, -d / 2 - 1.4), { material = M.Cobblestone })
	end
	-- roof with overhang + ridge
	local roofH = math.min(w, d) * 0.45 + 2
	local ry = 1.2 + h + roofH / 2
	for _, side in ipairs({ -1, 1 }) do
		Wedge(Vector3.new(w + 2.4, roofH, d / 2 + 1.4), roof, cf * CFrame.new(0, ry, side * (d / 4 + 0.35)) * CFrame.Angles(0, side > 0 and math.pi or 0, 0), { material = M.SmoothPlastic })
	end
	P(Vector3.new(w + 2.8, 0.8, 1), roof:Lerp(Color3.new(0, 0, 0), 0.25), cf * CFrame.new(0, 1.2 + h + roofH, 0), decor({ collide = false }))
	if opts.chimney ~= false then
		P(Vector3.new(1.8, roofH + 2.5, 1.8), Color3.fromRGB(176, 92, 70), cf * CFrame.new(w * 0.3, 1.2 + h + roofH / 2 + 1.5, d * 0.22), decor({ material = M.Brick }))
	end
	if opts.sign then
		Kit.Sign(opts.sign, cf * CFrame.new(0, (hollow and 1.2 + DH + 2.6 or 1.2 + fh * 0.92 + 1.6) + (opts.signLift or 0), -d / 2 - 0.5), Vector2.new(math.min(w - 1, 12), 2.6), nil, opts.signBg)
	end
	return 1.2 + h + roofH
end

-- ===== interiors (v0.25.140, owner reference clip: enterable important buildings with their NPC inside) =====
-- cf = the house's ground-center CFrame (door at -Z); the room spans +-(w/2-1) x +-(d/2-1), floor top at y 1.4.
-- The NPC stands at the back middle (Kit.InteriorSpot). No rng here: houses around it keep their random layout.
local FLOOR = 1.4
function Kit.InteriorSpot(d)
	return d / 2 - 3.2 -- local z of the NPC
end

local function lightAt(cf, range, brightness)
	local bulb = P(Vector3.new(1, 1, 1), Color3.fromRGB(255, 214, 140), cf, decor({ material = M.Neon, collide = false, shadow = false }))
	local l = Instance.new("PointLight")
	l.Range = range or 24
	l.Brightness = brightness or 1.3
	l.Color = Color3.fromRGB(255, 196, 130)
	l.Shadows = true
	l.Parent = bulb
	return bulb
end

local function stool(cf, color)
	P(Vector3.new(1.8, 0.5, 1.8), color, cf * CFrame.new(0, FLOOR + 2.1, 0), { material = M.Plaster }) -- Fabric renders dark
	P(Vector3.new(0.6, 1.9, 0.6), C.DarkWood, cf * CFrame.new(0, FLOOR + 0.95, 0), decor({ material = M.Wood }))
	P(Vector3.new(1.4, 0.3, 1.4), C.DarkWood, cf * CFrame.new(0, FLOOR + 0.15, 0), decor({ material = M.Wood }))
end

local function table1(cf)
	P(Vector3.new(4, 0.5, 4), C.LightWood, cf * CFrame.new(0, FLOOR + 2.9, 0), { material = M.WoodPlanks })
	P(Vector3.new(0.9, 2.7, 0.9), C.DarkWood, cf * CFrame.new(0, FLOOR + 1.35, 0), decor({ material = M.Wood }))
	P(Vector3.new(2.4, 0.3, 2.4), C.DarkWood, cf * CFrame.new(0, FLOOR + 0.15, 0), decor({ material = M.Wood }))
	P(Vector3.new(0.6, 0.8, 0.6), Color3.fromRGB(240, 196, 70), cf * CFrame.new(0.8, FLOOR + 3.55, -0.5), decor({ material = M.Metal, collide = false }))
end

local function shelf(cf, width, rows, fill)
	-- wall shelf unit: back board, shelves, and goods (fill(i, x, y) returns a color or nil)
	P(Vector3.new(width, rows * 2.4 + 0.6, 0.3), C.DarkWood, cf * CFrame.new(0, FLOOR + (rows * 2.4 + 0.6) / 2, 0), decor({ material = M.WoodPlanks }))
	for r = 0, rows do
		P(Vector3.new(width, 0.25, 1.4), C.Wood, cf * CFrame.new(0, FLOOR + 0.4 + r * 2.4, -0.7), decor({ material = M.Wood, collide = false }))
	end
	for r = 0, rows - 1 do
		local n = math.floor(width / 1.1)
		for i = 1, n do
			local col = fill(r * n + i, i, r)
			if col then
				local hgt = 1 + ((r * 7 + i * 3) % 3) * 0.35
				P(Vector3.new(0.7, hgt, 0.7), col, cf * CFrame.new(-width / 2 + (i - 0.5) * width / n, FLOOR + 0.55 + r * 2.4 + hgt / 2, -0.75), decor({ material = M.Glass, collide = false, shadow = false }))
			end
		end
	end
end

local function poster(cf, color)
	P(Vector3.new(2.6, 3.4, 0.12), Color3.fromRGB(236, 214, 168), cf, decor({ collide = false }))
	P(Vector3.new(1.8, 1.6, 0.14), color, cf * CFrame.new(0, 0.3, 0), decor({ collide = false }))
	P(Vector3.new(1.8, 0.3, 0.14), Color3.fromRGB(90, 60, 40), cf * CFrame.new(0, -1.1, 0), decor({ collide = false }))
end

local BOTTLES = { Color3.fromRGB(70, 150, 80), Color3.fromRGB(160, 70, 40), Color3.fromRGB(80, 110, 190), Color3.fromRGB(230, 190, 80), Color3.fromRGB(170, 60, 110) }

function Kit.Interior(cf, w, d, kind, fh)
	local iw, id = w / 2 - 1, d / 2 - 1 -- inner half sizes
	local npcZ = Kit.InteriorSpot(d)
	lightAt(cf * CFrame.new(0, FLOOR + fh - 2.6, 0), math.max(w, d) * 1.2, 1.4)
	lightAt(cf * CFrame.new(0, FLOOR + fh - 2.6, npcZ - 1), 16, 0.8)
	if kind == "tavern" then
		-- L-shaped bar in front of the keeper, red stools, bottle shelves on the back wall, tables by the windows
		local barZ = npcZ - 2.6
		local barW = math.min(w - 8, 18)
		P(Vector3.new(barW, 3.4, 1.6), Color3.fromRGB(120, 76, 44), cf * CFrame.new(-1, FLOOR + 1.7, barZ), { material = M.WoodPlanks })
		P(Vector3.new(barW + 0.6, 0.4, 2.2), C.LightWood, cf * CFrame.new(-1, FLOOR + 3.6, barZ), { material = M.Wood })
		local armX = -1 + barW / 2 - 0.8
		P(Vector3.new(1.6, 3.4, id - barZ - 0.6), Color3.fromRGB(120, 76, 44), cf * CFrame.new(armX, FLOOR + 1.7, (barZ + id) / 2 + 0.5), { material = M.WoodPlanks })
		P(Vector3.new(2.2, 0.4, id - barZ - 0.6), C.LightWood, cf * CFrame.new(armX, FLOOR + 3.6, (barZ + id) / 2 + 0.5), { material = M.Wood })
		for i = 0, math.floor(barW / 3.2) - 1 do
			stool(cf * CFrame.new(-1 - barW / 2 + 1.8 + i * 3.2, 0, barZ - 2.2), Color3.fromRGB(200, 50, 50))
		end
		shelf(cf * CFrame.new(-1, 0, id - 0.15), barW - 2, 3, function(n)
			return n % 4 ~= 0 and BOTTLES[n % #BOTTLES + 1] or nil
		end)
		for _, sx in ipairs({ -1, 1 }) do
			local tx = sx * (iw - 3.2)
			table1(cf * CFrame.new(tx, 0, -id + 4))
			stool(cf * CFrame.new(tx - 2.6, 0, -id + 4), Color3.fromRGB(200, 50, 50))
			stool(cf * CFrame.new(tx + 2.6, 0, -id + 4), Color3.fromRGB(200, 50, 50))
			poster(cf * CFrame.new(sx * (iw - 0.1), FLOOR + 5.4, -1) * CFrame.Angles(0, sx * math.pi / 2, 0), Color3.fromRGB(150, 60, 50))
		end
		-- barrels behind the bar end
		for k = 0, 1 do
			Kit.Barrel((cf * CFrame.new(-iw + 1.6, FLOOR, id - 1.6 - k * 2.6)).Position)
		end
	elseif kind == "smithy" then
		-- forge (glowing coals under a brick hood) back left, anvil in the middle, weapon rack right, water barrel
		local fx, fz = -iw + 2.6, id - 2.6
		P(Vector3.new(5, 2.6, 4.4), Color3.fromRGB(120, 60, 46), cf * CFrame.new(fx, FLOOR + 1.3, fz), { material = M.Brick })
		local coals = P(Vector3.new(3.6, 0.4, 3), Color3.fromRGB(255, 120, 30), cf * CFrame.new(fx, FLOOR + 2.7, fz), decor({ material = M.Neon, collide = false }))
		local glow = Instance.new("PointLight")
		glow.Range = 18
		glow.Brightness = 2
		glow.Color = Color3.fromRGB(255, 130, 50)
		glow.Parent = coals
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 4
		fire.Color = Color3.fromRGB(255, 140, 40)
		fire.SecondaryColor = Color3.fromRGB(255, 60, 20)
		fire.Parent = coals
		P(Vector3.new(5.4, 1.2, 4.8), Color3.fromRGB(96, 50, 40), cf * CFrame.new(fx, FLOOR + 6.4, fz), decor({ material = M.Brick }))
		P(Vector3.new(3, fh - 7, 3), Color3.fromRGB(96, 50, 40), cf * CFrame.new(fx, FLOOR + 7 + (fh - 7) / 2 - 0.4, fz + 0.4), decor({ material = M.Brick }))
		for _, sx in ipairs({ -1, 1 }) do
			P(Vector3.new(0.6, 3.6, 0.6), Color3.fromRGB(96, 50, 40), cf * CFrame.new(fx + sx * 2.3, FLOOR + 4.4, fz - 1.9), decor({ material = M.Brick }))
		end
		-- anvil on a stump, in front of the smith
		local ax = 0
		P(Vector3.new(2, 2, 2), C.DarkWood, cf * CFrame.new(ax, FLOOR + 1, npcZ - 3), { material = M.Wood })
		P(Vector3.new(1.2, 1, 1), Color3.fromRGB(60, 60, 66), cf * CFrame.new(ax, FLOOR + 2.5, npcZ - 3), decor({ material = M.Metal }))
		P(Vector3.new(3.2, 0.8, 1.4), Color3.fromRGB(70, 70, 78), cf * CFrame.new(ax + 0.3, FLOOR + 3.4, npcZ - 3), decor({ material = M.Metal }))
		P(Vector3.new(1, 0.5, 0.9), Color3.fromRGB(70, 70, 78), cf * CFrame.new(ax - 1.8, FLOOR + 3.5, npcZ - 3), decor({ material = M.Metal }))
		-- weapon rack on the right wall: blades + a hammer
		local rack = cf * CFrame.new(iw - 0.3, 0, 0) * CFrame.Angles(0, math.pi / 2, 0) -- local -Z faces into the room
		P(Vector3.new(7, 0.4, 0.5), C.DarkWood, rack * CFrame.new(0, FLOOR + 1.2, -0.3), decor({ material = M.Wood }))
		P(Vector3.new(7, 0.4, 0.5), C.DarkWood, rack * CFrame.new(0, FLOOR + 5.2, -0.3), decor({ material = M.Wood }))
		for i = -2, 2 do
			P(Vector3.new(0.35, 4.6, 0.2), Color3.fromRGB(205, 210, 220), rack * CFrame.new(i * 1.3, FLOOR + 3.6, -0.7), decor({ material = M.Metal, collide = false }))
			P(Vector3.new(1.1, 0.3, 0.35), Color3.fromRGB(200, 160, 60), rack * CFrame.new(i * 1.3, FLOOR + 1.6, -0.7), decor({ material = M.Metal, collide = false }))
		end
		Kit.Barrel((cf * CFrame.new(iw - 1.8, FLOOR, -id + 2)).Position)
		P(Vector3.new(2.6, 1.2, 2.6), Color3.fromRGB(40, 40, 44), cf * CFrame.new(-iw + 1.8, FLOOR + 0.6, -id + 2.2), decor({ material = M.Slate }))
	elseif kind == "shop" then
		-- counter across the room, shelves of goods on the back + side walls, sacks and crates
		local cz = npcZ - 2.6
		P(Vector3.new(w - 8, 3.4, 1.8), Color3.fromRGB(120, 76, 44), cf * CFrame.new(0, FLOOR + 1.7, cz), { material = M.WoodPlanks })
		P(Vector3.new(w - 7.4, 0.4, 2.4), C.LightWood, cf * CFrame.new(0, FLOOR + 3.6, cz), { material = M.Wood })
		P(Vector3.new(1.6, 0.6, 1.2), Color3.fromRGB(240, 196, 70), cf * CFrame.new(2.4, FLOOR + 4.1, cz), decor({ material = M.Metal, collide = false }))
		shelf(cf * CFrame.new(0, 0, id - 0.15), w - 6, 3, function(n)
			return ({ Color3.fromRGB(196, 120, 72), Color3.fromRGB(230, 70, 70), Color3.fromRGB(80, 170, 230), Color3.fromRGB(250, 220, 90) })[n % 4 + 1]
		end)
		for _, sx in ipairs({ -1, 1 }) do
			shelf(cf * CFrame.new(sx * (iw - 0.15), 0, -1) * CFrame.Angles(0, sx * math.pi / 2, 0), d - 10, 2, function(n)
				return n % 3 ~= 0 and BOTTLES[(n + 2) % #BOTTLES + 1] or nil
			end)
		end
		Kit.Crate((cf * CFrame.new(-iw + 2, FLOOR, -id + 2)).Position, 2.4, 0.3)
		Kit.Crate((cf * CFrame.new(iw - 2, FLOOR, -id + 2)).Position, 2.4, -0.2)
		P(Vector3.new(1.8, 2.2, 1.6), Color3.fromRGB(214, 190, 140), cf * CFrame.new(-iw + 4.6, FLOOR + 1.1, -id + 1.6), decor({ material = M.Fabric }))
	end
end

function Kit.Tower(pos, diameter, height, wall, roof, opts)
	opts = opts or {}
	Cyl(height, diameter, wall, pos + Vector3.new(0, height / 2, 0), { material = opts.material or M.Plaster })
	for i = 1, math.floor(height / 12) do
		Cyl(1.2, diameter + 0.6, opts.band or wall:Lerp(Color3.new(0, 0, 0), 0.15), pos + Vector3.new(0, i * 12, 0), decor())
	end
	if roof then
		for i = 0, 4 do
			Cyl(diameter * 0.18, diameter * (1.25 - i * 0.24), roof, pos + Vector3.new(0, height + i * diameter * 0.18, 0), {})
		end
	else
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			P(Vector3.new(diameter * 0.22, 2.4, 1.6), wall, CFrame.new(pos + Vector3.new(math.cos(a) * diameter * 0.45, height + 1.2, math.sin(a) * diameter * 0.45)) * CFrame.Angles(0, -a, 0), decor())
		end
	end
end

function Kit.Windmill(pos, scale, sailColor)
	scale = scale or 1
	local s = scale
	Cyl(22 * s, 11 * s, C.White, pos + Vector3.new(0, 11 * s, 0), { material = M.Plaster })
	Cyl(2 * s, 12 * s, C.Stone, pos + Vector3.new(0, 1 * s, 0), { material = M.Cobblestone })
	for i = 0, 3 do
		Cyl(2.2 * s, (12 - i * 2.6) * s, Color3.fromRGB(200, 90, 70), pos + Vector3.new(0, (23 + i * 2) * s, 0), {})
	end
	P(Vector3.new(3 * s, 5 * s, 0.4), Color3.fromRGB(110, 70, 42), CFrame.new(pos + Vector3.new(0, 2.5 * s, -5.5 * s)), { material = M.Wood })
	local hubPos = pos + Vector3.new(0, 20 * s, -6.2 * s)
	local blades = Instance.new("Model")
	blades.Name = "WindmillBlades"
	local hub = Kit.Ball(2.6 * s, C.DarkWood, hubPos, { parent = blades, collide = false })
	for i = 0, 3 do
		local arm = CFrame.new(hubPos) * CFrame.Angles(0, 0, i * math.pi / 2)
		P(Vector3.new(14 * s, 0.6 * s, 0.4), C.DarkWood, arm * CFrame.new(7 * s, 0, 0), { parent = blades, collide = false })
		P(Vector3.new(11 * s, 3.2 * s, 0.25), (i % 2 == 0) and (sailColor or C.White) or C.White, arm * CFrame.new(8 * s, 1.8 * s, 0.1), { parent = blades, collide = false, material = M.Fabric })
	end
	blades.PrimaryPart = hub
	blades:SetAttribute("SpinSpeed", 0.7 + rng:NextNumber() * 0.4)
	CollectionService:AddTag(blades, "Spin")
	blades.Parent = Kit.parent
end

function Kit.Statue(pos, scale, color, prop)
	local s = scale or 1
	color = color or Color3.fromRGB(220, 214, 200)
	P(Vector3.new(8, 3, 8) * s, C.DarkStone, CFrame.new(pos + Vector3.new(0, 1.5 * s, 0)), { material = M.Slate })
	P(Vector3.new(4.2, 6, 2.6) * s, color, CFrame.new(pos + Vector3.new(0, 7 * s, 0)), { material = M.Marble })
	Ball(4 * s, color, pos + Vector3.new(0, 12 * s, 0), { material = M.Marble })
	P(Vector3.new(1.6, 5.4, 1.6) * s, color, CFrame.new(pos + Vector3.new(-2.8 * s, 7.5 * s, 0)) * CFrame.Angles(0, 0, -0.25), { material = M.Marble })
	P(Vector3.new(1.6, 5.4, 1.6) * s, color, CFrame.new(pos + Vector3.new(2.8 * s, 9 * s, 0)) * CFrame.Angles(0, 0, 0.9), { material = M.Marble })
	P(Vector3.new(1.8, 4, 1.8) * s, color, CFrame.new(pos + Vector3.new(-1 * s, 3.6 * s, 0)), { material = M.Marble })
	P(Vector3.new(1.8, 4, 1.8) * s, color, CFrame.new(pos + Vector3.new(1 * s, 3.6 * s, 0)), { material = M.Marble })
	if prop == "axe" then
		local hand = pos + Vector3.new(5.2 * s, 11 * s, 0)
		P(Vector3.new(0.6, 8, 0.6) * s, C.DarkWood, CFrame.new(hand) * CFrame.Angles(0, 0, 0.9), {})
		Wedge(Vector3.new(0.6, 4, 3.5) * s, Color3.fromRGB(190, 196, 206), CFrame.new(hand + Vector3.new(2.6 * s, 2 * s, 0)) * CFrame.Angles(0, math.pi / 2, 0), { material = M.Metal })
	end
end

function Kit.Lighthouse(pos, scale)
	local s = scale or 1
	for i = 0, 5 do
		Cyl(6 * s, (12 - i) * s, i % 2 == 0 and C.White or Color3.fromRGB(230, 70, 60), pos + Vector3.new(0, (3 + i * 6) * s, 0), { material = M.Plaster })
	end
	local lamp = Cyl(4 * s, 7 * s, Color3.fromRGB(255, 240, 160), pos + Vector3.new(0, 38 * s, 0), { material = M.Neon })
	Cyl(3 * s, 9 * s, Color3.fromRGB(50, 50, 58), pos + Vector3.new(0, 41.5 * s, 0), {})
	local light = Instance.new("SpotLight")
	light.Range = 60
	light.Brightness = 3
	light.Parent = lamp
end

function Kit.CircusTent(pos, scale)
	local s = scale or 1
	local red, white = Color3.fromRGB(232, 58, 62), Color3.fromRGB(255, 250, 240)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		P(Vector3.new(30 * s * math.sin(math.pi / 16) * 2 + 0.4, 12 * s, 1), i % 2 == 0 and red or white, CFrame.new(pos) * CFrame.Angles(0, a, 0) * CFrame.new(0, 6 * s, 15 * s), { material = M.Fabric })
	end
	for i = 0, 6 do
		Cyl(3 * s, (34 - i * 4.6) * s, i % 2 == 0 and red or white, pos + Vector3.new(0, (13 + i * 2.6) * s, 0), { material = M.Fabric })
	end
	P(Vector3.new(0.6, 10, 0.6) * s, Color3.fromRGB(255, 210, 60), CFrame.new(pos + Vector3.new(0, 34 * s, 0)), {})
	P(Vector3.new(5, 3, 0.15) * s, Color3.fromRGB(255, 210, 60), CFrame.new(pos + Vector3.new(2.6 * s, 37 * s, 0)), decor({ material = M.Fabric }))
	-- entrance flaps
	P(Vector3.new(8, 10, 1) * s, Color3.fromRGB(30, 20, 30), CFrame.new(pos + Vector3.new(0, 5 * s, -15.3 * s)), decor({ collide = false }))
end

function Kit.Pagoda(pos, scale, wall, roof)
	local s = scale or 1
	local y = 0
	for tier = 0, 2 do
		local w = (26 - tier * 6) * s
		local h = 9 * s
		P(Vector3.new(w, h, w), wall, CFrame.new(pos + Vector3.new(0, y + h / 2, 0)), { material = M.Plaster })
		for k = 0, 3 do
			local cf = CFrame.new(pos + Vector3.new(0, y + h + 1.4 * s, 0)) * CFrame.Angles(0, k * math.pi / 2, 0)
			Wedge(Vector3.new(w + 8 * s, 2.8 * s, 5 * s), roof, cf * CFrame.new(0, 0, w / 2 + 1.3 * s), {})
			Wedge(Vector3.new(1.4 * s, 2.4 * s, 1.4 * s), roof, cf * CFrame.new(w / 2 + 3.5 * s, 1.6 * s, w / 2 + 3.5 * s), decor())
		end
		P(Vector3.new(w + 1, 1.2 * s, w + 1), roof, CFrame.new(pos + Vector3.new(0, y + h + 2.2 * s, 0)), {})
		y += h + 3 * s
	end
	P(Vector3.new(0.8, 8, 0.8) * s, Color3.fromRGB(255, 210, 60), CFrame.new(pos + Vector3.new(0, y + 4 * s, 0)), {})
end

function Kit.Junk(pos, radius)
	local rust = { Color3.fromRGB(150, 96, 70), Color3.fromRGB(120, 120, 125), Color3.fromRGB(96, 80, 64), Color3.fromRGB(170, 140, 100) }
	for _ = 1, 22 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(0, radius)
		local p = pos + Vector3.new(math.cos(a) * r, rng:NextNumber(0, 3), math.sin(a) * r)
		local sz = Vector3.new(rng:NextNumber(1.5, 5), rng:NextNumber(1, 4), rng:NextNumber(1.5, 5))
		P(sz, rust[rng:NextInteger(1, #rust)], CFrame.new(p) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, 6.28), rng:NextNumber(-0.6, 0.6)), decor({ material = rng:NextNumber() > 0.5 and M.CorrodedMetal or M.Wood }))
	end
	Kit.Barrel(pos + Vector3.new(radius * 0.4, 0, 0))
	Cyl(1.4, 4, Color3.fromRGB(40, 40, 44), pos + Vector3.new(-radius * 0.3, 1.4, radius * 0.2), decor({ material = M.Metal }))
end

-- ===== tiered terrain (Anime-Vanguards-style layer cake) =====
-- Grass blobs hanging over a cliff edge so the grass "drapes" down the rock
function Kit.Drapes(center, radius, topY, grass, skipFn)
	local n = math.floor(2 * math.pi * radius / 7)
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
		if not (skipFn and skipFn(a)) then
			local d = rng:NextNumber(4.5, 8)
			local p = center + Vector3.new(math.cos(a) * (radius + 0.4), topY - d * 0.32, math.sin(a) * (radius + 0.4))
			Ball(d, grass:Lerp(Color3.fromRGB(40, 120, 50), rng:NextNumber(0, 0.25)), p, decor({ collide = false, material = M.Grass, shadow = false }))
		end
	end
end

local mesaCount = 0

-- rock tone for the cliff meshes: grey rocks stay grey, everything else is the warm brown set ("Red" = the Red Line)
function Kit.RockTone(color)
	local _, sat = color:ToHSV()
	return sat < 0.2 and "Gray" or "Brown"
end

-- A mesa: organic rock body + strata + grass cap with overhang + accent rim + draping grass + rocks at its foot.
-- base = ground point under the center, h = height above base. Returns top Y.
function Kit.Mesa(base, radius, h, grass, rock, rim, opts)
	opts = opts or {}
	local top = base.Y + h
	local dark = rock:Lerp(Color3.new(0, 0, 0), 0.22)
	local tone = opts.tone or Kit.RockTone(rock)
	-- organic outline: a main cylinder plus offset lobes
	local lobes = { { 0, 0, radius } }
	for i = 1, opts.lobes or 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		table.insert(lobes, { math.cos(a) * radius * 0.35, math.sin(a) * radius * 0.35, radius * rng:NextNumber(0.62, 0.78) })
	end
	for li, l in ipairs(lobes) do
		local c = Vector3.new(base.X + l[1], 0, base.Z + l[2])
		-- collision body (visible fallback, hidden once dressed: same MesaId)
		mesaCount += 1
		local body = Cyl(h + 2, l[3] * 2, rock, c + Vector3.new(0, base.Y + h / 2 - 1, 0), { material = M.Rock })
		body:SetAttribute("MesaId", mesaCount)
		-- stylized rock cliff wall: a ring of slab modules facing outward (-> Cliff<Tone>_n meshes)
		local circ = 2 * math.pi * l[3]
		local n = math.max(5, math.ceil(circ / 11))
		local w = circ / n * 1.22
		local phase = rng:NextNumber(0, math.pi * 2)
		for i = 0, n - 1 do
			local a = phase + i / n * math.pi * 2
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local hh = h + 1.5 + rng:NextNumber(-0.6, 0.3)
			local depth = 5
			local center = c + dir * (l[3] - depth * 0.3 + rng:NextNumber(-0.3, 0.4)) + Vector3.new(0, base.Y + hh / 2 - 0.8, 0)
			local slab = P(Vector3.new(w, hh, depth), rock:Lerp(dark, rng:NextNumber(0, 0.5)), CFrame.lookAt(center, center + dir), { material = M.Rock, collide = false })
			slab:SetAttribute("Kind", "Cliff" .. tone)
			CollectionService:AddTag(slab, "EnvPart")
		end
		-- the grass layer on top (-> GrassCap_n mesh): flush with the rock rim (owner, v0.23.0: the overhanging grass
		-- stuck out past the cliff); no rng change, so every island keeps its layout. v0.25.112: each lobe's cap sits
		-- 0.08 above the one before (overlapping caps at one height z-fought = the flicker on the hills)
		local half = l[3] + 0.9
		local capH = 3.2
		local cap = P(Vector3.new(half * 2, capH, half * 2), grass, CFrame.new(c.X, top + 1.0 + (li - 1) * 0.08 - capH / 2, c.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), { material = M.Grass, collide = false, transparency = 1, shadow = false })
		cap.CanQuery = false
		cap:SetAttribute("Kind", "GrassCap")
		cap:SetAttribute("MesaId", mesaCount)
		CollectionService:AddTag(cap, "EnvPart")
		Cyl(2.2, l[3] * 2 + 1, grass, c + Vector3.new(0, top - 0.1 + (li - 1) * 0.08, 0), { material = M.Grass }):SetAttribute("MesaId", mesaCount)
	end
	for i = 1, math.floor(radius / 5) do
		local a = rng:NextNumber(0, math.pi * 2)
		Kit.Rock(Vector3.new(base.X + math.cos(a) * (radius + 1.5), base.Y + 1, base.Z + math.sin(a) * (radius + 1.5)), rng:NextNumber(2.5, 5), dark)
	end
	return top + 1
end

-- Solid stone staircase from the ground (at `foot`) climbing `rise` studs toward `dir` (unit, XZ).
function Kit.Stairs(foot, dir, rise, width, color)
	color = color or Color3.fromRGB(196, 182, 160)
	width = width or 10
	local steps = math.max(1, math.ceil(rise / 1.25))
	local stepH = rise / steps
	local depth = 2.3
	local cf0 = CFrame.lookAt(foot, foot + dir)
	for k = 1, steps do
		local h = k * stepH
		local cf = cf0 * CFrame.new(0, h / 2, -(k - 0.5) * depth)
		P(Vector3.new(width, h, depth + 0.05), (k % 2 == 0) and color or color:Lerp(Color3.new(0, 0, 0), 0.06), cf, { material = M.Cobblestone })
	end
	for _, sx in ipairs({ -1, 1 }) do
		local len = steps * depth
		local mid = cf0 * CFrame.new(sx * (width / 2 + 0.6), rise / 2 + 1.2, -len / 2) * CFrame.Angles(math.atan2(rise, len), 0, 0)
		P(Vector3.new(1.2, 1.2, math.sqrt(len * len + rise * rise)), C.DarkWood, mid, decor({ material = M.Wood }))
	end
	return steps * depth
end

return Kit
