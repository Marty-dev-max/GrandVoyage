-- ShipModel: builds ship part models (server for real ships, client for placement previews)
-- Orientation: plot -Z = bow (LookVector), r = 90-degree yaw steps
-- A model at ReplicatedStorage.Assets.ShipParts.<PartId> replaces the placeholder (PrimaryPart must match the grid size)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)
local ShipParts = require(Shared.Config.ShipParts).Parts
local ShipStats = require(Shared.Modules.ShipStats)

local SM = {}
local G = GameConfig.Ship.GridSize

local function mk(parent, class, size, color, cf, material)
	local p = Instance.new(class)
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = cf
	p.Anchored = true
	p.Parent = parent
	return p
end

local function cyl(parent, length, diameter, color, cf, material)
	local p = mk(parent, "Part", Vector3.new(length, diameter, diameter), color, cf, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Part center CFrame in plot space (origin = bottom corner of cell 0,0,0)
function SM.LocalCFrame(p)
	local def = ShipParts[p.id]
	local fp = ShipStats.Footprint(def, p.r or 0)
	return CFrame.new((p.x + fp.X / 2) * G, (p.y + fp.Y / 2) * G, -(p.z + fp.Z / 2) * G) * CFrame.Angles(0, (p.r or 0) * math.pi / 2, 0)
end

-- Build one part model centered at cf
function SM.BuildPart(p, cf, colorOverride)
	local def = ShipParts[p.id]
	local model = Instance.new("Model")
	model.Name = p.id
	local color = colorOverride or def.color
	local material = def.material and Enum.Material[def.material] or Enum.Material.SmoothPlastic
	local sz = def.size * G

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local custom = assets and assets:FindFirstChild("ShipParts") and assets.ShipParts:FindFirstChild(p.id)
	if custom then
		local c = custom:Clone()
		c:PivotTo(cf)
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		c.Parent = model
		model.PrimaryPart = c.PrimaryPart
		return model
	end

	local main
	if def.wedge then
		main = mk(model, "WedgePart", sz, color, cf * CFrame.Angles(0, 0, math.pi), material)
	elseif def.slab then
		main = mk(model, "Part", Vector3.new(sz.X, G * 0.35, sz.Z), color, cf * CFrame.new(0, -G / 2 + G * 0.175, 0), material)
	elseif def.category == "Hull" then
		main = mk(model, "Part", sz, color, cf, material)
		-- Darker plank trim for a cartoon look
		local trim = mk(model, "Part", Vector3.new(sz.X + 0.05, 0.25, sz.Z + 0.05), color:Lerp(Color3.new(0, 0, 0), 0.25), cf * CFrame.new(0, sz.Y / 2 - 0.12, 0), material)
		trim.CanCollide = false
	elseif p.id == "Helm" then
		main = mk(model, "Part", Vector3.new(G, G * 0.25, G), color, cf * CFrame.new(0, -G / 2 + G * 0.125, 0), Enum.Material.WoodPlanks)
		local post = mk(model, "Part", Vector3.new(0.6, G * 0.7, 0.6), color, cf * CFrame.new(0, 0, -G * 0.35), Enum.Material.Wood)
		post.CanCollide = false
		local wheelCf = cf * CFrame.new(0, G * 0.3, -G * 0.42)
		local rim = cyl(model, 0.3, G * 0.8, Color3.fromRGB(120, 70, 35), wheelCf * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.Wood)
		rim.CanCollide = false
		for i = 0, 3 do
			local spoke = mk(model, "Part", Vector3.new(0.2, G * 1.0, 0.2), Color3.fromRGB(230, 190, 120), wheelCf * CFrame.Angles(0, 0, i * math.pi / 4), Enum.Material.Wood)
			spoke.CanCollide = false
		end
		-- VehicleSeat gives ThrottleFloat/SteerFloat from keyboard, mobile thumbstick and gamepad (no wheels, so it never drives itself)
		local seat = Instance.new("VehicleSeat")
		seat.Name = "HelmSeat"
		seat.MaxSpeed = 0
		seat.Torque = 0
		seat.HeadsUpDisplay = false
		seat.Size = Vector3.new(2, 0.4, 2)
		seat.Transparency = 1
		seat.CFrame = cf * CFrame.new(0, -G / 2 + G * 0.35, G * 0.1)
		seat.Anchored = true
		seat.Parent = model
	elseif def.category == "Sail" and def.thrust then
		local h = sz.Y
		main = cyl(model, h, 0.9, Color3.fromRGB(130, 85, 50), cf * CFrame.Angles(0, 0, math.pi / 2), Enum.Material.Wood)
		local sailColor = color
		local sail = mk(model, "Part", Vector3.new(G * 2.6, h * 0.55, 0.3), sailColor, cf * CFrame.new(0, h * 0.08, -0.3), Enum.Material.Fabric)
		sail.Name = "Sail"
		sail.CanCollide = false
		local boom = cyl(model, G * 2.8, 0.4, Color3.fromRGB(130, 85, 50), cf * CFrame.new(0, h * 0.36, 0) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.Wood)
		boom.CanCollide = false
		local nest = cyl(model, 0.8, 2.2, Color3.fromRGB(150, 100, 60), cf * CFrame.new(0, h / 2 - 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2), Enum.Material.WoodPlanks)
		nest.CanCollide = false
		if def.faction == "Pirate" or def.faction == "Marine" then
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Back
			gui.LightInfluence = 0.5
			gui.Parent = sail
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, 1)
			t.TextScaled = true
			t.Font = Enum.Font.FredokaOne
			t.Text = def.faction == "Pirate" and "☠" or "MARINE"
			t.TextColor3 = def.faction == "Pirate" and Color3.new(1, 1, 1) or Color3.fromRGB(40, 90, 200)
			t.Parent = gui
		end
	elseif p.id == "OarBench" then
		main = mk(model, "Part", Vector3.new(G, G * 0.3, G * 0.5), color, cf * CFrame.new(0, -G / 2 + G * 0.3, 0), Enum.Material.Wood)
		for _, side in ipairs({ -1, 1 }) do
			local oar = mk(model, "Part", Vector3.new(G * 1.6, 0.25, 0.25), Color3.fromRGB(200, 150, 90), cf * CFrame.new(side * G * 0.9, -G * 0.2, 0) * CFrame.Angles(0, 0, side * 0.35), Enum.Material.Wood)
			oar.Name = "Oar"
			oar.CanCollide = false
		end
	elseif def.cannon then
		local heavy = p.id == "HeavyCannon"
		main = mk(model, "Part", Vector3.new(G * 0.8, G * 0.35, G * 0.8), Color3.fromRGB(120, 80, 45), cf * CFrame.new(0, -G / 2 + G * 0.175, 0), Enum.Material.Wood)
		local barrel = cyl(model, G * (heavy and 1.25 or 1.05), G * (heavy and 0.5 or 0.4), color, cf * CFrame.new(0, -G * 0.05, -G * 0.15) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, -0.08), Enum.Material.Metal)
		barrel.Name = "Barrel"
		barrel.CanCollide = false
		local muzzle = Instance.new("Attachment")
		muzzle.Name = "Muzzle"
		muzzle.Position = Vector3.new(barrel.Size.X / 2, 0, 0) -- local +X = muzzle (faces -Z)
		muzzle.Parent = barrel
		for _, side in ipairs({ -1, 1 }) do
			local wheel = cyl(model, 0.3, G * 0.4, Color3.fromRGB(70, 45, 25), cf * CFrame.new(side * G * 0.42, -G / 2 + G * 0.2, 0), Enum.Material.Wood)
			wheel.CanCollide = false
		end
	elseif p.id == "CrewCabin" then
		main = mk(model, "Part", Vector3.new(sz.X, sz.Y * 0.7, sz.Z), color, cf * CFrame.new(0, -sz.Y * 0.15, 0), Enum.Material.WoodPlanks)
		for _, side in ipairs({ -1, 1 }) do
			local roof = mk(model, "WedgePart", Vector3.new(sz.X + 0.6, sz.Y * 0.32, sz.Z / 2 + 0.3), Color3.fromRGB(200, 70, 60), cf * CFrame.new(0, sz.Y * 0.36, side * sz.Z / 4) * CFrame.Angles(0, side > 0 and math.pi or 0, 0))
			roof.CanCollide = false
		end
		local door = mk(model, "Part", Vector3.new(G * 0.6, G * 0.9, 0.2), Color3.fromRGB(90, 55, 30), cf * CFrame.new(0, -sz.Y * 0.5 + G * 0.45, -sz.Z / 2 - 0.05), Enum.Material.Wood)
		door.CanCollide = false
		local win = mk(model, "Part", Vector3.new(G * 0.5, G * 0.4, 0.2), Color3.fromRGB(255, 230, 150), cf * CFrame.new(sz.X * 0.25, 0, -sz.Z / 2 - 0.05), Enum.Material.Neon)
		win.CanCollide = false
	elseif p.id == "RamHead" or p.id == "LionHead" then
		main = mk(model, "Part", Vector3.new(G * 0.6, G * 0.6, G * 0.6), Color3.fromRGB(196, 140, 88), cf * CFrame.new(0, -G * 0.2, 0), Enum.Material.Wood)
		local head = mk(model, "Part", Vector3.new(G * 1.1, G * 1.1, G * 1.1), color, cf * CFrame.new(0, G * 0.25, -G * 0.2))
		head.Shape = Enum.PartType.Ball
		head.CanCollide = false
		if p.id == "RamHead" then
			for _, side in ipairs({ -1, 1 }) do
				local horn = mk(model, "Part", Vector3.new(G * 0.5, G * 0.5, G * 0.5), Color3.fromRGB(240, 200, 120), cf * CFrame.new(side * G * 0.5, G * 0.4, -G * 0.1))
				horn.Shape = Enum.PartType.Ball
				horn.CanCollide = false
			end
		else
			local mane = cyl(model, G * 0.35, G * 1.7, Color3.fromRGB(230, 120, 40), cf * CFrame.new(0, G * 0.25, 0) * CFrame.Angles(0, math.pi / 2, 0))
			mane.CanCollide = false
		end
	elseif p.id == "Lantern" then
		main = mk(model, "Part", Vector3.new(G * 0.3, G * 0.5, G * 0.3), color, cf * CFrame.new(0, -G * 0.2, 0), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Range = 22
		light.Brightness = 1.6
		light.Color = Color3.fromRGB(255, 200, 120)
		light.Parent = main
	else
		main = mk(model, "Part", sz, color, cf, material)
	end
	main.Name = "Main"
	model.PrimaryPart = main
	return model
end

-- Build a whole (anchored) ship from a design
function SM.BuildDesign(design, originCf, colorFn)
	local model = Instance.new("Model")
	model.Name = design.name or "Ship"
	for i, p in ipairs(design.parts) do
		if ShipParts[p.id] then
			local m = SM.BuildPart(p, originCf * SM.LocalCFrame(p), colorFn and colorFn(p) or p.c)
			m:SetAttribute("Index", i)
			m.Parent = model
		end
	end
	return model
end

-- Design bounds in grid cells (used to center the root)
function SM.Bounds(design)
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(design.parts) do
		local def = ShipParts[p.id]
		if def then
			local fp = ShipStats.Footprint(def, p.r or 0)
			minV = minV:Min(Vector3.new(p.x, p.y, p.z))
			maxV = maxV:Max(Vector3.new(p.x + fp.X, p.y + fp.Y, p.z + fp.Z))
		end
	end
	if minV.X == math.huge then
		return Vector3.zero, Vector3.one
	end
	return minV, maxV
end

return SM
