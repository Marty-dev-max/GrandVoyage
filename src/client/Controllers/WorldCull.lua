-- WorldCull (client, v0.24.14, mobile pass): the baked voxel map is ~41,000 parts and islands sit 1,800 studs apart,
-- so this client unloads the plain map pieces of islands far from the camera (parent = nil locally) and brings them
-- back as you come closer. Only untagged, anchored scenery is touched: NPCs, chests, docks, plots, spawns, prompts and
-- anything else carrying a CollectionService tag (or inside a tagged model) always stays, so quests, markers and
-- interactions keep working everywhere. The server is never affected (it is a local view change).
-- v0.25.50: scenery tags (EnvProp/EnvPart) are culled too, and the sea-wide models (forts, islets, Red Line,
-- sea floor) hide in 600-stud chunks.
-- Distances follow the graphics preset (Settings.Knobs: cull), with a little hysteresis; work is spread over frames.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Islands = require(ReplicatedStorage.Shared.Config.Islands)
local Settings = require(script.Parent.Settings)
local Outline = require(ReplicatedStorage.Shared.Modules.IslandOutline)

local WC = {}
local BATCH = 500 -- parts moved per frame
local CULL = { Low = 1150, Medium = 1500, High = 2100, Ultra = 2700 }
local zones = {} -- { model, center, radius, hidden = bool, stash = { {part, parent} }, busy }
WC.Stats = { hidden = 0 }

-- v0.25.50 (owner: phones felt like the whole sea up to the Red Line was drawn): pure scenery tags may be culled too
-- (trees, bushes, boulders, cliff slabs, decor props were all kept before, so far islands stayed mostly visible)
local SCENERY = { EnvProp = true, EnvPart = true } -- (Decor stays: Settings hides/restores it per preset)
-- big models spread over the whole sea are cut into square chunks that hide one by one
-- W1: not "RedLine": the walls + Backflow Peak are the world's edge (seen from far) and their parts are up to 2000
-- studs long, so a chunk by part centre hid a wall whose face was right next to you
local CHUNKED = { "Forts", "Islets", "SeaFloor" }
local CHUNK = 600

-- v0.25.135 (owner: far islands should still show faintly): while an island's scenery is culled, a light stand-in
-- takes its place: the same organic outline (Shared IslandOutline) at 24-stud cells, rock body + grass cap, beaches,
-- tree clumps and a few roofs. Atmosphere haze makes it read as a faint silhouette on the horizon.
local impostorFolder
local function impostor(isl)
	local r = isl.radius
	local pal = isl.palette or {}
	local grass = pal.grass or Color3.fromRGB(120, 200, 90)
	local sand = pal.sand or Color3.fromRGB(240, 220, 170)
	local rockC = Color3.fromRGB(140, 128, 116)
	local base = CFrame.new(isl.x, 0, isl.z or 0) * CFrame.Angles(0, isl.yaw or 0, 0)
	local m = Instance.new("Model")
	m.Name = "Far_" .. isl.id
	local function part(size, lcf, color, mat)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = size
		p.CFrame = base * lcf
		p.Color = color
		p.Material = mat
		p.Parent = m
	end
	local CELL = 24
	local ext = math.ceil((r * 1.3 + 30) / CELL)
	for iz = -ext, ext do
		local cur, from = nil, nil
		local function flush(to)
			if cur then
				local x0, x1 = (from - 0.5) * CELL, (to + 0.5) * CELL
				local w, cx, z = x1 - x0, (x0 + x1) / 2, iz * CELL
				if cur == 1 then
					part(Vector3.new(w, 11, CELL), CFrame.new(cx, 1, z), rockC, Enum.Material.Rock)
					part(Vector3.new(w, 1, CELL), CFrame.new(cx, 7, z), grass, Enum.Material.Grass)
				else
					part(Vector3.new(w, 6, CELL), CFrame.new(cx, 0.6, z), sand, Enum.Material.Sand)
				end
			end
		end
		for ix = -ext, ext + 1 do
			local k = nil
			if ix <= ext then
				local x, z = ix * CELL, iz * CELL
				local d, a = math.sqrt(x * x + z * z), math.atan2(z, x)
				local R = Outline.Radius(isl, r, a)
				if d <= R then
					k = 1
				elseif d <= R + Outline.Beach(isl, r, a) then
					k = 2
				end
			end
			if k ~= cur then
				flush(ix - 1)
				cur, from = k, ix
			end
		end
	end
	-- tree clumps and roofs (deterministic per island)
	local rnd = Random.new(Outline.Hash(isl.id) + 7)
	for _ = 1, 46 do
		local a = rnd:NextNumber(0, math.pi * 2)
		local d = math.sqrt(rnd:NextNumber()) * (Outline.Radius(isl, r, a) - 18)
		local s = rnd:NextNumber(12, 26)
		local h = rnd:NextNumber(10, 22)
		local x, z = math.cos(a) * d, math.sin(a) * d
		if d < r * 0.42 and rnd:NextNumber() < 0.6 then
			part(Vector3.new(s * 0.6, h * 0.45, s * 0.5), CFrame.new(x, 7.5 + h * 0.22, z) * CFrame.Angles(0, a, 0), pal.wall or Color3.fromRGB(245, 235, 215), Enum.Material.SmoothPlastic)
			part(Vector3.new(s * 0.66, 3, s * 0.56), CFrame.new(x, 7.5 + h * 0.45 + 1.5, z) * CFrame.Angles(0, a, 0), pal.accent or Color3.fromRGB(220, 100, 70), Enum.Material.SmoothPlastic)
		else
			part(Vector3.new(s, h, s), CFrame.new(x, 7.5 + h / 2, z) * CFrame.Angles(0, a, 0), grass:Lerp(Color3.fromRGB(30, 90, 40), rnd:NextNumber(0.25, 0.45)), Enum.Material.Grass)
		end
	end
	return m
end

local function protected(inst, root)
	-- tagged itself or inside a tagged model (other than plain scenery), or something the player interacts with
	local a = inst
	while a and a ~= root do
		for _, tag in ipairs(CollectionService:GetTags(a)) do
			if not SCENERY[tag] then
				return true
			end
		end
		a = a.Parent
	end
	return inst:FindFirstChildWhichIsA("ProximityPrompt", true) ~= nil
end

local function hide(z)
	z.busy = true
	z.stash = {}
	local list = {}
	for _, d in ipairs(z.parts or z.model:GetDescendants()) do
		if d:IsA("BasePart") and d.Parent and d.Anchored and not protected(d, z.model) then
			table.insert(list, d)
		end
	end
	for i, p in ipairs(list) do
		if p.Parent then
			table.insert(z.stash, { p, p.Parent })
			p.Parent = nil
		end
		if i % BATCH == 0 then
			task.wait()
		end
	end
	WC.Stats.hidden += #z.stash
	z.hidden = true
	z.busy = false
	if z.far then
		z.far.Parent = impostorFolder
	end
end

-- now = true: everything at once (you are standing on it: a teleport, a respawn), else spread over frames, the
-- pieces nearest to the camera first
local function show(z, now, at)
	z.busy = true
	if z.far then
		z.far.Parent = nil
	end
	local stash = z.stash or {}
	z.stash = nil
	if at then
		table.sort(stash, function(a, b)
			return (a[1].Position - at).Magnitude < (b[1].Position - at).Magnitude
		end)
	end
	for i, e in ipairs(stash) do
		local p, parent = e[1], e[2]
		if parent.Parent or parent == z.model then
			-- v0.25.83: a stashed part can be destroyed meanwhile (AssetService swapping a placeholder): its Parent
			-- is locked, so skip it instead of erroring out halfway through the island
			pcall(function()
				p.Parent = parent
			end)
		end
		if not now and i % BATCH == 0 then
			task.wait()
		end
	end
	WC.Stats.hidden -= #stash
	z.hidden = false
	z.busy = false
end

function WC.Start()
	local world = workspace:WaitForChild("World", 60)
	if not world then
		return
	end
	task.wait(4) -- let the map finish streaming in / being dressed
	impostorFolder = Instance.new("Folder")
	impostorFolder.Name = "FarIslands"
	impostorFolder.Parent = workspace
	for _, isl in ipairs(Islands.List) do
		local m = world:FindFirstChild(isl.id)
		if m and m:IsA("Model") then
			local ok, cf, size = pcall(m.GetBoundingBox, m)
			if ok then
				local okF, far = pcall(impostor, isl)
				table.insert(zones, { model = m, center = Vector3.new(cf.Position.X, 0, cf.Position.Z), radius = math.max(size.X, size.Z) / 2, hidden = false, far = okF and far or nil })
			end
		end
	end
	for _, name in ipairs(CHUNKED) do
		local m = world:FindFirstChild(name)
		if m then
			local cells = {}
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					local p = d.Position
					local key = math.floor(p.X / CHUNK) .. ":" .. math.floor(p.Z / CHUNK)
					local c = cells[key]
					if not c then
						c = { model = m, parts = {}, center = Vector3.new((math.floor(p.X / CHUNK) + 0.5) * CHUNK, 0, (math.floor(p.Z / CHUNK) + 0.5) * CHUNK), radius = CHUNK * 0.71, hidden = false }
						cells[key] = c
						table.insert(zones, c)
					end
					table.insert(c.parts, d)
				end
			end
		end
	end
	local acc = 0
	local player = game:GetService("Players").LocalPlayer
	RunService.Heartbeat:Connect(function(dt)
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		-- every frame (cheap): standing on / right next to a hidden island (teleport, respawn) -> bring it back NOW
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		for _, z in ipairs(zones) do
			if z.hidden and not z.busy then
				for _, at in ipairs({ cam.Focus.Position, root and root.Position }) do
					if at and Vector3.new(at.X - z.center.X, 0, at.Z - z.center.Z).Magnitude - z.radius < 120 then
						show(z, true)
						break
					end
				end
			end
		end
		acc += dt
		if acc < 1 then
			return
		end
		acc = 0
		local at = cam.Focus.Position
		local far = CULL[Settings.Values.quality] or CULL.High
		for _, z in ipairs(zones) do
			if not z.busy then
				local d = Vector3.new(at.X - z.center.X, 0, at.Z - z.center.Z).Magnitude - z.radius
				if not z.hidden and d > far then
					task.spawn(hide, z)
				elseif z.hidden and d < far - 200 then
					task.spawn(show, z, false, at)
				end
			end
		end
	end)
end

return WC
