-- AssetService: loads the Blender models listed in Config/Models (made by tools/blender/build_models.py, uploaded by
-- tools/upload_models.py) with InsertService and files them under ReplicatedStorage.Assets, where the game already
-- looks for real models before building placeholder bodies:
--   Pets/<Species>_<stage>   (client Controllers/Pets)
--   Fruits/<FruitId>         (FruitService world fruit, inventory 3D showcase)
--   Env/<Kind>_<n>           (stylized trees/bushes/boulders/cliffs; DressWorld swaps the World's placeholder props)
--   Monsters/<MonsterId>     (ModelFactory.Monster; "Mon_<MonsterId>" models, wrapped in HumanoidRootPart + Humanoid)
-- Every model is normalized here: one Model, anchored non-colliding parts, pivot at the bounding-box center,
-- scaled so its largest side is SIZE studs. Loading needs the asset owner = the game owner (it is: Treezaa2).
local InsertService = game:GetService("InsertService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Models = require(ReplicatedStorage.Shared.Config.Models)
local Greenery = require(script.Parent.Parent.World.Greenery)

local AS = {}
local R

-- largest side in studs
local PET_SIZE = { 2.6, 3.3, 4.2 }
local PET_SIZE_MULT = { Leviathan = 1.25, Puffer = 0.9 }
local FRUIT_SIZE = 2.6
local MonstersCfg = require(ReplicatedStorage.Shared.Config.Monsters)
-- explicit sizes (longest side); otherwise size = base-by-shape x the monster's style.scale
local MONSTER_SIZE = { BaySerpent = 35, Leviathan = 46, FortCore = 20 }
-- Bay Serpent body pieces (tools/blender/serpent.py, same scale as the 35-stud head): longest side in studs
local SERPENT_SIZE = { Seg = 13.8, Tail = 25.2 }
local SHAPE_SIZE = { humanoid = 6.5, fishman = 6.8, crab = 6, monkey = 5.5, snail = 7, seaking = 14 }
-- if an import ever faces the wrong way, fix it here (radians around Y) instead of re-exporting everything
local YAW_FIX = 0

AS.Loaded = {} -- name -> true
AS.Failed = {} -- name -> error

local function assetsFolder(name)
	local root = ReplicatedStorage:FindFirstChild("Assets")
	if not root then
		root = Instance.new("Folder")
		root.Name = "Assets"
		root.Parent = ReplicatedStorage
	end
	local f = root:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = root
	end
	return f
end

-- class weapons (tools/blender/voxel_weapons.py): longest side in studs, and where the hand grips it, as a fraction of
-- the length from the handle end (+Z; the striking end points -Z). nil grip = the pivot stays at the center.
AS.WEAPONS = {
	Sword = { size = 4.6, grip = 0.13 }, Hammer = { size = 4.8, grip = 0.1 }, StormBaton = { size = 5.4, grip = 0.35 },
	Slingshot = { size = 1.9, grip = 0.23 }, Knuckles = { size = 1.3 }, Shoes = { size = 1.55 }, MedKit = { size = 1.05 },
	-- worn / holstered gear (pivot at the center)
	StormBatonPack = { size = 1.7 }, SwordSheathed = { size = 4.5 }, Scabbard = { size = 3.4 }, SlingBag = { size = 1.6 },
}

local ENV_HEIGHT = 10 -- Env models are normalized to this height with the pivot at the bottom center

local function target(name)
	local wep = string.match(name, "^Wep_(%w+)$")
	if wep then
		return "Weapons", wep, (AS.WEAPONS[wep] or { size = 3 }).size
	end
	local serp = string.match(name, "^Serp_(%w+)$")
	if serp then
		return "Serpent", serp, SERPENT_SIZE[serp] or 12
	end
	local env = string.match(name, "^Env_(%w+_%d+)$")
	if env then
		return "Env", env, ENV_HEIGHT
	end
	local mon = string.match(name, "^Mon_(%w+)$")
	if mon then
		local def = MonstersCfg[mon]
		local style = def and def.style or {}
		return "Monsters", mon, MONSTER_SIZE[mon] or (SHAPE_SIZE[style.shape or ""] or 8) * (style.scale or 1)
	end
	local fruit = string.match(name, "^Fruit_(%w+)$")
	if fruit then
		return "Fruits", fruit, FRUIT_SIZE
	end
	local species, stage = string.match(name, "^(%w+)_(%d)$")
	if species then
		stage = tonumber(stage)
		return "Pets", name, (PET_SIZE[stage] or 3) * (PET_SIZE_MULT[species] or 1)
	end
	return nil
end

-- InsertService result -> one clean Model
local function normalize(container, name, size, folder)
	local m = Instance.new("Model")
	m.Name = name
	local parts = {}
	for _, d in ipairs(container:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	if #parts == 0 then
		return nil, "no parts in asset"
	end
	for _, p in ipairs(parts) do
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.CastShadow = true
		-- matte: SmoothPlastic gave rocks and ledges a plastic sheen under Future lighting
		p.Material = folder == "Env" and Enum.Material.Plastic or Enum.Material.SmoothPlastic
		p.Reflectance = 0
		if p:IsA("MeshPart") then
			-- the toon outline is an inverted hull: it only works with back faces culled
			pcall(function()
				p.DoubleSided = false
			end)
		end
		p.Parent = m
	end
	local cf, ext = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(cf.Position)
	local biggest = folder == "Env" and ext.Y or math.max(ext.X, ext.Y, ext.Z)
	if biggest > 0 then
		m:ScaleTo(size / biggest)
	end
	m:PivotTo(CFrame.Angles(0, YAW_FIX, 0))
	m.WorldPivot = CFrame.new(m.WorldPivot.Position) -- bake the fix so later PivotTo calls keep it
	if folder == "Env" then
		-- props stand on the ground: pivot at the bottom center
		local c2, e2 = m:GetBoundingBox()
		m.WorldPivot = CFrame.new(c2.Position - Vector3.new(0, e2.Y / 2, 0))
		m:PivotTo(CFrame.new())
	end
	if folder == "Weapons" then
		-- pivot on the grip so WeaponService can put the pivot straight into the hand
		local spec = AS.WEAPONS[name]
		local c2, e2 = m:GetBoundingBox()
		local z = spec and spec.grip and (e2.Z / 2 - spec.grip * e2.Z) or 0
		m.WorldPivot = CFrame.new(c2.Position + Vector3.new(0, 0, z))
		m:PivotTo(CFrame.new())
	end
	m:SetAttribute("HalfHeight", select(2, m:GetBoundingBox()).Y / 2)
	return m
end

-- monsters walk with a Humanoid: invisible HumanoidRootPart at the model's center, mesh welded to it,
-- HipHeight puts the feet on the ground
local function monsterRig(m)
	local cf, ext = m:GetBoundingBox()
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Transparency = 1
	root.CanCollide = true
	root.Size = Vector3.new(math.max(2, ext.X * 0.6), 2, math.max(2, ext.Z * 0.6))
	root.CFrame = CFrame.new(cf.Position)
	root.Parent = m
	-- every voxel part hangs off the root on a Motor6D at its natural joint, so the client can animate it
	-- (Controllers/CreatureAnim sets Motor6D.Transform: legs swing from the hip, head nods from the neck...)
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") and p ~= root then
			p.Anchored = false
			p.CanQuery = true -- click-to-target hits the mesh
			local size, n = p.Size, p.Name
			local hinge = Vector3.zero
			if string.sub(n, 1, 3) == "Leg" or string.sub(n, 1, 3) == "Arm" then
				hinge = Vector3.new(0, size.Y / 2, 0) -- hip / shoulder
			elseif n == "Head" then
				hinge = Vector3.new(0, -size.Y / 2, 0) -- neck
			elseif string.sub(n, 1, 4) == "Wing" then
				hinge = Vector3.new((p.Position.X > cf.Position.X) and -size.X / 2 or size.X / 2, 0, 0)
			elseif n == "Jaw" then
				hinge = Vector3.new(0, size.Y * 0.3, size.Z / 2) -- the back of the lower jaw (+Z = back)
			elseif n == "Tail" then
				hinge = Vector3.new(0, 0, -size.Z / 2) -- where it meets the body (front end)
			end
			local hingeCF = CFrame.new((p.CFrame * CFrame.new(hinge)).Position)
			local motor = Instance.new("Motor6D")
			motor.Name = n
			motor.Part0 = root
			motor.Part1 = p
			motor.C0 = root.CFrame:ToObjectSpace(hingeCF)
			motor.C1 = p.CFrame:ToObjectSpace(hingeCF)
			motor.Parent = root
		end
	end
	m:SetAttribute("Height", ext.Y)
	m.PrimaryPart = root
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = math.max(0.1, ext.Y / 2 - 1)
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = m
end

local function load(name, id)
	local folder, key, size = target(name)
	if not folder then
		return
	end
	local ok, res = pcall(InsertService.LoadAsset, InsertService, id)
	if not ok then
		AS.Failed[name] = tostring(res)
		warn("[AssetService] could not load", name, id, res)
		return
	end
	local m, err = normalize(res, key, size, folder)
	res:Destroy()
	if not m then
		AS.Failed[name] = err
		warn("[AssetService]", name, err)
		return
	end
	if folder == "Monsters" then
		monsterRig(m)
	end
	local dest = assetsFolder(folder)
	local old = dest:FindFirstChild(key)
	if old then
		old:Destroy()
	end
	m.Parent = dest
	AS.Loaded[name] = true
end

function AS.Init(registry)
	R = registry
end

function AS.Start()
	task.spawn(function()
		local t0 = os.clock()
		local pending = 0
		for name, id in pairs(Models) do
			pending += 1
			task.spawn(function()
				load(name, id)
				pending -= 1
			end)
		end
		while pending > 0 and os.clock() - t0 < 60 do
			task.wait(0.2)
		end
		local n, f = 0, 0
		for _ in pairs(AS.Loaded) do
			n += 1
		end
		for _ in pairs(AS.Failed) do
			f += 1
		end
		print(string.format("[AssetService] %d models loaded, %d failed (%.1fs)", n, f, os.clock() - t0))
		AS.DressWorld()
		local swapped = R and R.MonsterService and R.MonsterService.RefreshModels and R.MonsterService.RefreshModels() or 0
		print("[AssetService] swapped " .. swapped .. " placeholder monsters for real models")
	end)
end

-- ===== world dressing: placeholder props -> stylized meshes =====
local function envVariants(kind)
	local env = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Env")
	local out = {}
	for _, m in ipairs(env and env:GetChildren() or {}) do
		if string.match(m.Name, "^(%w+)_%d+$") == kind then
			table.insert(out, m)
		end
	end
	table.sort(out, function(a, b)
		return a.Name < b.Name
	end)
	return out
end

local function hashPos(p)
	return math.abs(math.floor(p.X * 7.31 + p.Z * 13.17 + p.Y * 3.7))
end

function AS.DressWorld()
	local t0 = os.clock()
	local cache = {}
	local function variants(kind)
		cache[kind] = cache[kind] or envVariants(kind)
		return cache[kind]
	end
	local props, parts = 0, 0
	-- whole props (trees, palms, pines, bushes): Model with Kind/Base/Height attributes
	for _, m in ipairs(CollectionService:GetTagged("EnvProp")) do
		local list = variants(m:GetAttribute("Kind") or "")
		local base, h = m:GetAttribute("Base"), m:GetAttribute("Height")
		if m:IsA("Model") and #list > 0 and base and h and not m:GetAttribute("Dressed") then
			local hv = hashPos(base)
			local c = list[hv % #list + 1]:Clone()
			c:PivotTo(CFrame.new(base) * CFrame.Angles(0, (hv % 628) / 100, 0))
			c:ScaleTo(c:GetScale() * h / ENV_HEIGHT)
			for _, p in ipairs(m:GetChildren()) do
				if p:IsA("BasePart") then
					if p:GetAttribute("Collider") then
						p.Transparency = 1
					else
						p:Destroy()
					end
				end
			end
			for _, p in ipairs(c:GetChildren()) do
				if p:IsA("BasePart") then
					p.CanQuery = false -- clicks and ground raycasts pass through foliage
					p.CanTouch = false
					p.Parent = m
				end
			end
			c:Destroy()
			m:SetAttribute("Dressed", true)
			props += 1
		end
	end
	-- single-part replacements (cliff slabs, boulders): the mesh takes the part's exact box
	for _, p in ipairs(CollectionService:GetTagged("EnvPart")) do
		local list = variants(p:GetAttribute("Kind") or "")
		if p:IsA("BasePart") and #list > 0 and not p:GetAttribute("Dressed") then
			local src = list[hashPos(p.Position) % #list + 1]
			local mesh = src:FindFirstChildWhichIsA("MeshPart")
			if mesh then
				local mp = mesh:Clone()
				local rel = src:GetPivot():ToObjectSpace(mesh.CFrame)
				local grow = p:GetAttribute("Kind") == "Boulder" and 1.15 or 1.0
				mp.Size = p.Size * grow
				mp.CFrame = p.CFrame * (rel - rel.Position)
				mp.Anchored = true
				mp.CanCollide = false
				mp.CanQuery = false
				mp.CanTouch = false
				mp.Parent = p.Parent
				p.Transparency = 1
				p.CastShadow = false
				p:SetAttribute("Dressed", true)
				parts += 1
			end
		end
	end
	-- organic ledges replace the mesa's visible cylinder + grass cap (both stay as invisible collision)
	local dressedMesa = {}
	for _, p in ipairs(CollectionService:GetTagged("EnvPart")) do
		local kind = p:GetAttribute("Kind")
		if (kind == "Mesa" or kind == "GrassCap") and p:GetAttribute("Dressed") then
			dressedMesa[p:GetAttribute("MesaId")] = true
		end
	end
	if next(dressedMesa) then
		local world = workspace:FindFirstChild("World")
		for _, d in ipairs(world and world:GetDescendants() or {}) do
			if d:IsA("BasePart") and not CollectionService:HasTag(d, "EnvPart") then
				local id = d:GetAttribute("MesaId")
				if id and dressedMesa[id] then
					d.Transparency = 1
					d.CastShadow = false
				end
			end
		end
	end
	print(string.format("[AssetService] dressed %d props + %d cliff/rock/ledge parts (%.2fs)", props, parts, os.clock() - t0))
	-- scattered stylized plants on the island grass (grass blades: client GrassField)
	local world = workspace:FindFirstChild("World")
	if world and not world:FindFirstChild("Greenery") then
		local t1 = os.clock()
		local plants = Greenery.Scatter(world, variants, 110)
		print(string.format("[AssetService] %d plants scattered (%.2fs)", plants, os.clock() - t1))
	end
end

-- dev: line every loaded model up in front of a player for a minute (Dev tab -> "Model Gallery")
function AS.Gallery(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return 0
	end
	local base = assetsFolder("Fruits").Parent
	local list = {}
	for _, folder in ipairs({ "Pets", "Fruits", "Monsters" }) do
		local f = base:FindFirstChild(folder)
		for _, m in ipairs(f and f:GetChildren() or {}) do
			table.insert(list, m)
		end
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	local gallery = Instance.new("Model")
	gallery.Name = "ModelGallery"
	local origin = root.CFrame * CFrame.new(-(math.min(#list, 6) - 1) * 3, 0, -10)
	for i, m in ipairs(list) do
		local c = m:Clone()
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
			elseif d:IsA("Humanoid") then
				d:Destroy()
			end
		end
		local col, row = (i - 1) % 6, math.floor((i - 1) / 6)
		-- facing the player
		c:PivotTo(origin * CFrame.new(col * 6, row * 5.5 + (c:GetAttribute("HalfHeight") or 1) - 2.5, -row * 3) * CFrame.Angles(0, math.pi, 0))
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromOffset(120, 20)
		tag.StudsOffsetWorldSpace = Vector3.new(0, (c:GetAttribute("HalfHeight") or 1) + 0.8, 0)
		tag.AlwaysOnTop = true
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = m.Name
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.3
		label.Font = Enum.Font.Arcade
		label.TextSize = 14
		label.Parent = tag
		tag.Adornee = c.PrimaryPart or c:FindFirstChildWhichIsA("BasePart")
		tag.Parent = c
		c.Parent = gallery
	end
	gallery.Parent = workspace
	task.delay(60, function()
		gallery:Destroy()
	end)
	return #list
end

return AS
