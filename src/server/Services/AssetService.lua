-- AssetService: loads the Blender models listed in Config/Models (made by tools/blender/build_models.py, uploaded by
-- tools/upload_models.py) with InsertService and files them under ReplicatedStorage.Assets, where the game already
-- looks for real models before building placeholder bodies:
--   Pets/<Species>_<stage>   (client Controllers/Pets)
--   Fruits/<FruitId>         (FruitService world fruit, inventory 3D showcase)
--   Monsters/<MonsterId>     (ModelFactory.Monster; "Mon_<MonsterId>" models, wrapped in HumanoidRootPart + Humanoid)
-- Every model is normalized here: one Model, anchored non-colliding parts, pivot at the bounding-box center,
-- scaled so its largest side is SIZE studs. Loading needs the asset owner = the game owner (it is: Treezaa2).
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Models = require(ReplicatedStorage.Shared.Config.Models)

local AS = {}

-- largest side in studs
local PET_SIZE = { 2.6, 3.3, 4.2 }
local PET_SIZE_MULT = { Leviathan = 1.25, Puffer = 0.9 }
local FRUIT_SIZE = 2.6
local MONSTER_SIZE = { GuardWolf = 7.5, BaySerpent = 40 } -- default 7
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

local function target(name)
	local mon = string.match(name, "^Mon_(%w+)$")
	if mon then
		return "Monsters", mon, MONSTER_SIZE[mon] or 7
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
local function normalize(container, name, size)
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
		p.Material = Enum.Material.SmoothPlastic
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
	local biggest = math.max(ext.X, ext.Y, ext.Z)
	if biggest > 0 then
		m:ScaleTo(size / biggest)
	end
	m:PivotTo(CFrame.Angles(0, YAW_FIX, 0))
	m.WorldPivot = CFrame.new(m.WorldPivot.Position) -- bake the fix so later PivotTo calls keep it
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
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") and p ~= root then
			p.Anchored = false
			p.CanQuery = true -- click-to-target hits the mesh
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = p
			w.Parent = root
		end
	end
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
	local m, err = normalize(res, key, size)
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

function AS.Init() end

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
	end)
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
		label.Font = Enum.Font.GothamBold
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
