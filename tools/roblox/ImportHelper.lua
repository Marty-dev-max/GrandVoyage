--[[
Grand Voyage: Studio import helper for the Blender assets (tools/blender/generate_assets.py).

1. In Studio: Avatar/Home tab -> Import 3D -> select the FBX files from assets/models/<category>/
   (scale unit: Stud). Put the imported results into a folder  workspace.GV_Import  (any nesting).
2. Paste this whole file into the Command Bar and press Enter.

What it does:
  * Monster meshes  -> ReplicatedStorage.Assets.Monsters.<Id>   (adds HumanoidRootPart + Humanoid, welds the mesh)
  * Ship part meshes -> ReplicatedStorage.Assets.ShipParts.<Id> (sized exactly to the 4-stud grid, pivot centered)
  * Everything else -> ReplicatedStorage.Assets.Props.<Name>
The game automatically prefers these assets over the procedural placeholders.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local ShipParts = require(ReplicatedStorage.Shared.Config.ShipParts).Parts
local GRID = 4

local import = workspace:FindFirstChild("GV_Import")
assert(import, "Create workspace.GV_Import and put the imported meshes inside it first")

local assets = ReplicatedStorage:FindFirstChild("Assets") or Instance.new("Folder")
assets.Name = "Assets"
assets.Parent = ReplicatedStorage
local function folder(name)
	local f = assets:FindFirstChild(name) or Instance.new("Folder")
	f.Name = name
	f.Parent = assets
	return f
end
local monstersF, shipsF, propsF = folder("Monsters"), folder("ShipParts"), folder("Props")

-- find the first MeshPart for each imported asset name
local found = {}
for _, d in ipairs(import:GetDescendants()) do
	if d:IsA("MeshPart") then
		local name = d.Name
		local m = d:FindFirstAncestorOfClass("Model")
		if m and m ~= import and (Monsters[m.Name] or ShipParts[m.Name]) then
			name = m.Name
		end
		if not found[name] then
			found[name] = d
		end
	end
end

local counts = { monsters = 0, ships = 0, props = 0 }
for name, mesh in pairs(found) do
	mesh = mesh:Clone()
	mesh.Name = "Mesh"
	mesh.Anchored = false
	mesh.PivotOffset = CFrame.new()
	if Monsters[name] then
		local old = monstersF:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		local model = Instance.new("Model")
		model.Name = name
		local size = mesh.Size
		local hip = math.max(0.1, size.Y * 0.3)
		mesh.CFrame = CFrame.new(0, size.Y / 2, 0)
		mesh.CanCollide = false
		mesh.Massless = true
		mesh.Parent = model
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(math.max(2, size.X * 0.6), 2, math.max(2, size.Z * 0.6))
		root.CFrame = CFrame.new(0, hip + 1, 0)
		root.Transparency = 1
		root.CanCollide = true
		root.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = mesh
		weld.Parent = root
		local hum = Instance.new("Humanoid")
		hum.RigType = Enum.HumanoidRigType.R15
		hum.HipHeight = hip
		hum.Parent = model
		model.PrimaryPart = root
		model.Parent = monstersF
		counts.monsters += 1
	elseif ShipParts[name] then
		local old = shipsF:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		local def = ShipParts[name]
		local sz = def.size * GRID
		local model = Instance.new("Model")
		model.Name = name
		-- slabs/cannons/props are shorter than a full cell; keep their aspect but fit the footprint
		local k = math.min(sz.X / mesh.Size.X, sz.Z / mesh.Size.Z)
		mesh.Size = mesh.Size * k
		mesh.Anchored = true
		mesh.Parent = model
		model.PrimaryPart = mesh
		model.Parent = shipsF
		counts.ships += 1
	else
		local old = propsF:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		mesh.Name = name
		mesh.Anchored = true
		mesh.Parent = propsF
		counts.props += 1
	end
end
print(string.format("[GV Import] monsters %d, ship parts %d, props %d -> ReplicatedStorage.Assets", counts.monsters, counts.ships, counts.props))
