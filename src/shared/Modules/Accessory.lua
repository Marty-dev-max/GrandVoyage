-- Accessory (v0.25.32): builds a Config/Accessories model. The same code dresses players (worn items), monsters
-- (Config/MonsterLooks) and offline previews (tools/export_char.luau), so an accessory always looks the same.
local Cfg = require(script.Parent.Parent.Config.Accessories) -- relative: the Lune export tools load it too
local Coplanar = require(script.Parent.Coplanar)

local Accessory = {}
Accessory.Cfg = Cfg

function Accessory.Has(id)
	return Cfg[id] ~= nil
end

-- limbOf(name) -> (CFrame, Size) of that limb ("Head" = the voxel head cube) or nil;
-- emit(size, cframe, color, material, limbName) places one block
function Accessory.Build(id, limbOf, emit)
	for _, b in ipairs(Cfg[id] or {}) do
		local cf, size = limbOf(b[1])
		if cf then
			emit(size * b[2], cf * CFrame.new(size * b[3]), b[4], b[5], b[1])
		end
	end
end

-- weld an accessory onto a live (voxel) character; returns the model ("GVOutfit_<id>" by default)
function Accessory.Wear(char, id, name)
	local model = Instance.new("Model")
	model.Name = name or ("GVOutfit_" .. id)
	model:SetAttribute("GVOutfit", id)
	local limbs = {}
	Accessory.Build(id, function(limbName)
		local limb = (limbName == "Head" and char:FindFirstChild("VoxelHead", true)) or char:FindFirstChild(limbName)
		if not limb then
			return nil
		end
		limbs[limbName] = limb
		return limb.CFrame, limb.Size
	end, function(size, cf, color, material, limbName)
		local part = Instance.new("Part")
		part.Name = "Outfit"
		part.Size = size
		part.CFrame = cf
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0 = limbs[limbName]
		w.Part1 = part
		w.Parent = part
	end)
	-- v0.25.149: pieces lying in the same plane as a body / other outfit face flickered (Sailor Vest on the shirt)
	local items, fixed = {}, {}
	for _, p in ipairs(model:GetChildren()) do
		table.insert(items, { p, p.CFrame })
	end
	for _, m in ipairs(char:GetChildren()) do
		if m.Name == "VoxelBody" or m:GetAttribute("GVOutfit") then
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") then
					table.insert(fixed, { p, p.CFrame })
				end
			end
		end
	end
	Coplanar.Fix(items, fixed)
	model.Parent = char
	return model
end

return Accessory
