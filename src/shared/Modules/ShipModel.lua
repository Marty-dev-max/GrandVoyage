-- ShipModel: builds ship part models (server for real ships, client for placement previews)
-- Orientation: plot -Z = bow (LookVector), r = 90-degree yaw steps
-- A model at ReplicatedStorage.Assets.ShipParts.<PartId> replaces the placeholder (PrimaryPart must match the grid size)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
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

-- voxel style (v0.24.0): what used to be cylinders (masts, barrels, wheels, booms) are square beams
local function cyl(parent, length, diameter, color, cf, material)
	return mk(parent, "Part", Vector3.new(length, diameter, diameter), color, cf, material)
end

-- Part center CFrame in plot space (origin = bottom corner of cell 0,0,0)
function SM.LocalCFrame(p)
	local def = ShipParts[p.id]
	local fp = ShipStats.Footprint(def, p.r or 0)
	return CFrame.new((p.x + fp.X / 2) * G, (p.y + fp.Y / 2) * G, -(p.z + fp.Z / 2) * G) * CFrame.Angles(0, (p.r or 0) * math.pi / 2, 0)
end

local function dark(c, k)
	return c:Lerp(Color3.new(0, 0, 0), k)
end
-- a stable per-cell shade so a wall of planks is not one flat color (voxel boat refs)
local function cellShade(c, p)
	local h = ((p.x or 0) * 73 + (p.y or 0) * 151 + (p.z or 0) * 37) % 3
	return h == 0 and c or h == 1 and dark(c, 0.06) or c:Lerp(Color3.new(1, 1, 1), 0.05)
end
local GOLD_TRIM = Color3.fromRGB(214, 170, 74)
local function deco(part)
	part.CanCollide = false
	part.CanQuery = false
	return part
end

-- v0.25.150 (owner): Marines sail in a uniform livery (white hull, navy rails); used by the builder AND the launch,
-- so what you build is what you get. Pirates and the unaligned keep the block colors.
local MARINE = {
	PlankBlock = Color3.fromRGB(240, 241, 246), PlankWedge = Color3.fromRGB(240, 241, 246), OakBlock = Color3.fromRGB(220, 226, 238),
	Railing = Color3.fromRGB(44, 74, 150), CrewCabin = Color3.fromRGB(236, 238, 244), Barrel = Color3.fromRGB(60, 90, 160),
	-- v2 hull paint zones (ShipHull.PaintOf asks for "Paint:<zone>")
	["Paint:hull"] = Color3.fromRGB(240, 241, 246), ["Paint:bottom"] = Color3.fromRGB(40, 60, 120), ["Paint:stripe"] = Color3.fromRGB(232, 192, 80),
	["Paint:rail"] = Color3.fromRGB(44, 74, 150), ["Paint:sail"] = Color3.fromRGB(245, 248, 255),
}
function SM.FactionColorFn(faction)
	if faction == "Marine" then
		return function(p)
			return MARINE[p.id] or p.c
		end
	end
	return nil
end

-- Build one part model centered at cf
function SM.BuildPart(p, cf, colorOverride)
	local def = ShipParts[p.id]
	local model = Instance.new("Model")
	model.Name = p.id
	local color = colorOverride or def.color
	local material = def.material and Enum.Material[def.material] or Enum.Material.SmoothPlastic
	local sz = def.size * G * Vector3.new(p.sx or 1, p.sy or 1, p.sz or 1) -- v2 designs scale blocks, cabins, masts, rails

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
		-- voxel bow block: the (invisible) wedge keeps the old collision, two stepped blocks show it
		main = mk(model, "WedgePart", sz, color, cf * CFrame.Angles(0, 0, math.pi), material)
		main.Transparency = 1
		local top = mk(model, "Part", Vector3.new(sz.X, sz.Y / 2, sz.Z), color, cf * CFrame.new(0, sz.Y / 4, 0), material)
		top.CanCollide = false
		local low = mk(model, "Part", Vector3.new(sz.X * 0.7, sz.Y / 2, sz.Z / 2), color:Lerp(Color3.new(0, 0, 0), 0.15), cf * CFrame.new(0, -sz.Y / 4, sz.Z / 4), material)
		low.CanCollide = false
	elseif def.slab and p.id ~= "Lantern" then
		local base = colorOverride and color or cellShade(color, p)
		local t = sz.Y * 0.35
		main = mk(model, "Part", Vector3.new(sz.X, t, sz.Z), base, cf * CFrame.new(0, -sz.Y / 2 + t / 2, 0), material)
		for _, x in ipairs({ -sz.X / 4, sz.X / 4 }) do
			deco(mk(model, "Part", Vector3.new(0.12, t + 0.03, sz.Z + 0.01), dark(base, 0.28), cf * CFrame.new(x, -sz.Y / 2 + t / 2, 0), material))
		end
	elseif def.stairs then
		-- three walkable steps climbing toward the part's +Z (each step is its own collider)
		local base = colorOverride and color or cellShade(color, p)
		for i = 1, 3 do
			local h = sz.Y * i / 3
			local s = mk(model, "Part", Vector3.new(sz.X, h, sz.Z / 3), i % 2 == 0 and dark(base, 0.07) or base, cf * CFrame.new(0, -sz.Y / 2 + h / 2, -sz.Z / 2 + (i - 0.5) * sz.Z / 3), material)
			if i == 1 then
				main = s
			end
			deco(mk(model, "Part", Vector3.new(sz.X + 0.04, 0.14, 0.2), dark(base, 0.3), cf * CFrame.new(0, -sz.Y / 2 + h - 0.06, -sz.Z / 2 + (i - 1) * sz.Z / 3 + 0.1), material))
		end
		for _, sx in ipairs({ -1, 1 }) do
			deco(mk(model, "Part", Vector3.new(0.3, sz.Y + 0.6, sz.Z + 0.04), dark(base, 0.35), cf * CFrame.new(sx * (sz.X / 2 - 0.13), 0.3, 0), Enum.Material.Wood))
		end
	elseif def.railing then
		-- a fence along the part's X through the middle of the cell: posts at both ends, a top rail and a mid rail
		local Y = sz.Y
		main = mk(model, "Part", Vector3.new(sz.X, Y * 0.8, 0.5), color, cf * CFrame.new(0, -Y / 2 + Y * 0.4, 0), material)
		main.Transparency = 1
		for _, sx in ipairs({ -1, 1 }) do
			deco(mk(model, "Part", Vector3.new(0.55, Y * 0.85, 0.55), dark(color, 0.2), cf * CFrame.new(sx * (sz.X / 2 - 0.27), -Y / 2 + Y * 0.425, 0), material))
		end
		deco(mk(model, "Part", Vector3.new(sz.X + 0.02, 0.42, 0.62), color, cf * CFrame.new(0, -Y / 2 + Y * 0.82, 0), material))
		deco(mk(model, "Part", Vector3.new(math.max(sz.X - 0.6, 0.2), 0.26, 0.3), color, cf * CFrame.new(0, -Y / 2 + Y * 0.45, 0), material))
		for i = -1, 1 do
			deco(mk(model, "Part", Vector3.new(0.22, Y * 0.38, 0.22), dark(color, 0.1), cf * CFrame.new(i * sz.X / 4, -Y / 2 + Y * 0.62, 0), material))
		end
	elseif def.category == "Hull" and def.conform ~= "rail" and not def.balcony then
		local base = colorOverride and color or cellShade(color, p)
		main = mk(model, "Part", sz, base, cf, material)
		local metal = def.material == "DiamondPlate"
		-- top trim (cartoon edge) + plank seams on the sides: three boards per block like the voxel boat refs
		deco(mk(model, "Part", Vector3.new(sz.X + 0.05, 0.25, sz.Z + 0.05), dark(base, 0.25), cf * CFrame.new(0, sz.Y / 2 - 0.12, 0), material))
		if metal then
			deco(mk(model, "Part", Vector3.new(sz.X + 0.04, 0.22, sz.Z + 0.04), dark(base, 0.35), cf * CFrame.new(0, -sz.Y / 2 + 0.11, 0), material))
			for _, sx in ipairs({ -1, 1 }) do
				for _, sz2 in ipairs({ -1, 1 }) do
					deco(mk(model, "Part", Vector3.new(0.4, 0.4, 0.4), base:Lerp(Color3.new(1, 1, 1), 0.25), cf * CFrame.new(sx * (sz.X / 2 - 0.35), 0, sz2 * (sz.Z / 2 - 0.13)), Enum.Material.Metal))
				end
			end
		else
			for _, y in ipairs({ -sz.Y / 6, sz.Y / 6 }) do
				deco(mk(model, "Part", Vector3.new(sz.X + 0.03, 0.14, sz.Z + 0.03), dark(base, 0.3), cf * CFrame.new(0, y, 0), material))
			end
			if p.id == "OakBlock" or p.id == "TreasureBlock" then
				for _, sx in ipairs({ -1, 1 }) do
					for _, sz2 in ipairs({ -1, 1 }) do
						deco(mk(model, "Part", Vector3.new(0.5, sz.Y + 0.02, 0.5), dark(base, 0.4), cf * CFrame.new(sx * (sz.X / 2 - 0.22), 0, sz2 * (sz.Z / 2 - 0.22)), Enum.Material.Wood))
					end
				end
			end
		end
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
		local sail = mk(model, "Part", Vector3.new(sz.X * 2.6, h * 0.55, 0.3), sailColor, cf * CFrame.new(0, h * 0.08, -0.3), Enum.Material.Plaster) -- Fabric renders dark blue here
		sail.Name = "Sail"
		sail.CanCollide = false
		sail.CanQuery = false
		-- v0.25.150: every client hides this flat sheet and draws a furling, billowing block sail with the emblem
		sail:SetAttribute("Kind", def.faction or "")
		CollectionService:AddTag(sail, "ShipSail")
		local boom = cyl(model, sz.X * 2.8, 0.4, Color3.fromRGB(130, 85, 50), cf * CFrame.new(0, h * 0.36, 0) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.Wood)
		boom.CanCollide = false
		local nest = cyl(model, 0.8, 2.2, Color3.fromRGB(150, 100, 60), cf * CFrame.new(0, h / 2 - 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2), Enum.Material.WoodPlanks)
		nest.CanCollide = false
	elseif p.id == "OarBench" then
		main = mk(model, "Part", Vector3.new(G, G * 0.3, G * 0.5), color, cf * CFrame.new(0, -G / 2 + G * 0.3, 0), Enum.Material.Wood)
		-- R5 (owner ref photo): the oars rest in oarlocks on the gunwales, built by ShipHull.RowStation (it knows the hull)
	elseif def.cannon then
		-- v0.25.153: barrel look from the kind (bore / len) x the builder's bore (sx) and barrel (sz) scaling
		local c = def.cannon
		local bore = G * (c.bore or 0.4) * (p.sx or 1)
		local len = G * (c.len or 1.05) * (p.sz or 1)
		local floorY = -G / 2
		local wood = Color3.fromRGB(120, 80, 45)
		local barrelCf
		if c.swivel then
			main = mk(model, "Part", Vector3.new(0.5, G * 0.55, 0.5), wood, cf * CFrame.new(0, floorY + G * 0.275, 0), Enum.Material.Wood)
			deco(mk(model, "Part", Vector3.new(0.9, 0.25, 0.9), Color3.fromRGB(70, 70, 76), cf * CFrame.new(0, floorY + G * 0.58, 0), Enum.Material.Metal))
			barrelCf = cf * CFrame.new(0, floorY + G * 0.66, -len * 0.25)
		elseif c.lob then
			-- mortar: a squat block bed, the fat barrel tipped up 45 degrees
			main = mk(model, "Part", Vector3.new(G * 0.9, G * 0.3, G * 0.9), wood, cf * CFrame.new(0, floorY + G * 0.15, 0), Enum.Material.WoodPlanks)
			deco(mk(model, "Part", Vector3.new(G * 0.7, G * 0.18, G * 0.7), Color3.fromRGB(70, 70, 76), cf * CFrame.new(0, floorY + G * 0.39, 0), Enum.Material.Metal))
			barrelCf = cf * CFrame.new(0, floorY + G * 0.3 + bore * 0.5 + len * 0.3, -len * 0.2) * CFrame.Angles(math.rad(45), 0, 0)
		else
			main = mk(model, "Part", Vector3.new(math.max(G * 0.8, bore + 1), G * 0.35, math.max(G * 0.8, len * 0.7)), wood, cf * CFrame.new(0, floorY + G * 0.175, 0), Enum.Material.Wood)
			barrelCf = cf * CFrame.new(0, floorY + G * 0.35 + bore / 2, -len * 0.3) * CFrame.Angles(0.08, 0, 0)
			for _, side in ipairs({ -1, 1 }) do
				deco(cyl(model, 0.3, G * 0.4, Color3.fromRGB(70, 45, 25), cf * CFrame.new(side * (main.Size.X / 2 + 0.1), floorY + G * 0.2, 0), Enum.Material.Wood))
			end
		end
		local barrel = mk(model, "Part", Vector3.new(bore, bore, len), color, barrelCf, Enum.Material.Metal)
		barrel.Name = "Barrel"
		barrel.CanCollide = false
		deco(mk(model, "Part", Vector3.new(bore + 0.2, bore + 0.2, 0.3), dark(color, 0.3), barrelCf * CFrame.new(0, 0, -len / 2 + 0.15), Enum.Material.Metal))
		deco(mk(model, "Part", Vector3.new(bore + 0.14, bore + 0.14, 0.4), dark(color, 0.2), barrelCf * CFrame.new(0, 0, len / 2 - 0.2), Enum.Material.Metal))
		local muzzle = Instance.new("Attachment")
		muzzle.Name = "Muzzle"
		muzzle.Position = Vector3.new(0, 0, -len / 2) -- local -Z = muzzle
		muzzle.Parent = barrel
		if c.special == "harpoon" then
			-- v0.25.155: a barbed iron head out of the muzzle + a rope coil by the bed
			local steel = Color3.fromRGB(170, 175, 185)
			deco(mk(model, "Part", Vector3.new(bore * 0.6, bore * 0.6, 0.9), steel, barrelCf * CFrame.new(0, 0, -len / 2 - 0.45), Enum.Material.Metal))
			deco(mk(model, "Part", Vector3.new(bore * 2.2, 0.18, 0.35), steel, barrelCf * CFrame.new(0, 0, -len / 2 - 0.55), Enum.Material.Metal))
			deco(mk(model, "Part", Vector3.new(0.9, 0.35, 0.9), Color3.fromRGB(205, 175, 120), cf * CFrame.new(main.Size.X / 2 + 0.3, floorY + 0.18, 0.4), Enum.Material.Fabric))
		elseif c.special == "firepot" then
			-- a clay pot in the bucket with a little flame on top
			deco(mk(model, "Part", Vector3.new(bore * 1.1, bore * 0.9, bore * 1.1), Color3.fromRGB(190, 110, 60), barrelCf * CFrame.new(0, 0, -len / 2 - bore * 0.2), Enum.Material.Slate))
			deco(mk(model, "Part", Vector3.new(bore * 0.5, bore * 0.5, bore * 0.5), Color3.fromRGB(255, 150, 40), barrelCf * CFrame.new(0, bore * 0.2, -len / 2 - bore * 0.7), Enum.Material.Neon))
		end
	elseif def.rudder then
		-- blade hanging off the stern below the waterline + the post up to the deck
		main = mk(model, "Part", Vector3.new(0.6, sz.Y * 0.75, sz.Z * 0.8), color, cf * CFrame.new(0, -sz.Y * 0.125, sz.Z * 0.1), material)
		deco(mk(model, "Part", Vector3.new(0.7, sz.Y, 0.6), dark(color, 0.25), cf * CFrame.new(0, 0, -sz.Z / 2 + 0.3), Enum.Material.Wood))
		for _, y in ipairs({ -0.3, 0.1 }) do
			deco(mk(model, "Part", Vector3.new(0.75, 0.25, sz.Z * 0.82), Color3.fromRGB(70, 70, 76), cf * CFrame.new(0, y * sz.Y, sz.Z * 0.1), Enum.Material.Metal))
		end
	elseif def.keel then
		main = mk(model, "Part", sz, color, cf, material)
		deco(mk(model, "Part", Vector3.new(sz.X + 0.06, 0.35, sz.Z + 0.06), Color3.fromRGB(70, 70, 76), cf * CFrame.new(0, -sz.Y / 2 + 0.17, 0), Enum.Material.Metal))
	elseif def.jib then
		-- triangular staysail in block steps: wide at the foot, narrowing to the top, along the part's Z (bow = -Z)
		main = mk(model, "Part", Vector3.new(0.3, sz.Y, 0.3), Color3.fromRGB(130, 85, 50), cf * CFrame.new(0, 0, -sz.Z / 2 + 0.15), Enum.Material.Wood)
		local steps = 5
		for i = 0, steps - 1 do
			local h = sz.Y / steps
			local w = sz.Z * (1 - i / steps)
			deco(mk(model, "Part", Vector3.new(0.2, h + 0.02, w), color, cf * CFrame.new(0, -sz.Y / 2 + (i + 0.5) * h, -sz.Z / 2 + w / 2), Enum.Material.Plaster))
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
		-- v0.25.158 (owner: the ball heads looked like round blobs): carved block heads on an 8-cell grid of the
		-- footprint (so the builder's x / y / z scaling stretches them), facing -Z; color = the FIGURE paint zone
		local ux, uy, uz = sz.X / 8, sz.Y / 8, sz.Z / 8
		local function b(x, y, z, w, h, d, c, mat)
			local q = mk(model, "Part", Vector3.new(w * ux, h * uy, d * uz), c, cf * CFrame.new(x * ux, y * uy, z * uz), mat or Enum.Material.Wood)
			q.CanCollide = false
			return q
		end
		local function light(c, k)
			return c:Lerp(Color3.new(1, 1, 1), k)
		end
		local eye = Color3.fromRGB(28, 22, 20)
		main = b(0, -2.5, 2.5, 3, 3, 3, dark(color, 0.35)) -- mount against the stem
		main.CanCollide = true
		if p.id == "RamHead" then
			b(0, 1, 1, 3.6, 3.6, 3.6, color) -- skull
			b(0, 0.2, -2.0, 2.8, 3.0, 3.6, color) -- long face
			b(0, 1.8, -1.6, 1.6, 0.5, 2.8, light(color, 0.12)) -- roman nose ridge
			b(0, -0.4, -4.3, 2.2, 2.2, 1.2, light(color, 0.15)) -- muzzle
			b(0, -1.2, -4.4, 1.8, 0.2, 1.1, dark(color, 0.45)) -- mouth line
			b(0, 3.1, 1.0, 2.4, 0.8, 2.2, light(color, 0.25)) -- wool tuft
			local horn = color:Lerp(Color3.fromRGB(245, 232, 205), 0.55)
			for _, s in ipairs({ -1, 1 }) do
				b(s * 0.55, 0.1, -4.95, 0.3, 0.5, 0.2, dark(color, 0.6), Enum.Material.SmoothPlastic) -- nostril
				b(s * 1.85, 1.3, -0.3, 0.3, 0.7, 0.9, eye, Enum.Material.SmoothPlastic)
				b(s * 1.8, 1.9, -0.3, 0.5, 0.4, 1.2, dark(color, 0.2)) -- brow
				b(s * 2.3, 0.9, 1.0, 1.2, 0.5, 0.8, dark(color, 0.1)) -- ear
				-- curled horn: back over the head, out, down past the ear and forward along the cheek
				for i, pt in ipairs({ { 1.9, 2.9, 1.8, 1.8 }, { 2.8, 3.2, 2.8, 1.7 }, { 3.7, 2.7, 3.4, 1.6 }, { 4.2, 1.6, 3.2, 1.5 }, { 4.3, 0.5, 2.4, 1.4 },
					{ 4.0, -0.4, 1.2, 1.3 }, { 3.4, -0.6, 0.1, 1.1 }, { 3.0, 0.1, -0.7, 0.9 }, { 3.0, 1.0, -0.9, 0.7 } }) do
					b(s * pt[1], pt[2], pt[3], pt[4], pt[4], pt[4], i % 2 == 0 and dark(horn, 0.2) or horn)
				end
			end
		else
			local mane = color:Lerp(Color3.fromRGB(150, 62, 24), 0.55)
			b(0, 0.5, 1.5, 7, 5, 2, mane)
			b(0, 0.5, 1.5, 5, 7, 2, mane)
			for k = 0, 7 do
				local a = k * math.pi / 4 + math.pi / 8
				b(math.cos(a) * 4.2, 0.5 + math.sin(a) * 4.2, 1.2, 1.8, 1.8, 1.6, k % 2 == 0 and dark(mane, 0.15) or mane)
				local a2 = k * math.pi / 4
				b(math.cos(a2) * 3.2, 0.5 + math.sin(a2) * 3.2, 0.2, 1.5, 1.5, 1.4, k % 2 == 0 and light(mane, 0.1) or dark(mane, 0.08))
			end
			b(0, 0.3, -1.2, 4.4, 4.4, 3, color) -- face
			b(0, 1.7, -2.9, 4.6, 0.9, 0.8, dark(color, 0.12)) -- brow
			b(0, -0.8, -3.3, 3.2, 2, 1.6, light(color, 0.15)) -- muzzle
			b(0, 0.2, -4.0, 1.4, 0.9, 0.6, dark(color, 0.55)) -- nose
			b(0, -1.9, -3.3, 2.2, 0.5, 1.4, Color3.fromRGB(90, 30, 26), Enum.Material.SmoothPlastic) -- open mouth
			b(0, -2.5, -3.0, 2.4, 0.8, 1.6, color) -- chin
			for _, s in ipairs({ -1, 1 }) do
				b(s * 1.1, 1.0, -2.75, 0.9, 0.7, 0.3, eye, Enum.Material.SmoothPlastic)
				b(s * 0.6, -1.6, -4.0, 0.35, 0.6, 0.3, Color3.fromRGB(245, 240, 225), Enum.Material.SmoothPlastic) -- fang
				b(s * 1.9, 2.8, -0.4, 1.2, 1.2, 1.0, color) -- ear
				b(s * 1.9, 2.8, -0.95, 0.6, 0.6, 0.15, dark(color, 0.35))
			end
		end
	elseif p.id == "Barrel" then
		main = mk(model, "Part", Vector3.new(G * 0.66, G * 0.82, G * 0.66), color, cf * CFrame.new(0, -G / 2 + G * 0.41, 0), Enum.Material.Wood)
		deco(mk(model, "Part", Vector3.new(G * 0.74, G * 0.36, G * 0.74), color:Lerp(Color3.new(1, 1, 1), 0.06), cf * CFrame.new(0, -G / 2 + G * 0.41, 0), Enum.Material.Wood))
		for _, y in ipairs({ 0.12, 0.7 }) do
			deco(mk(model, "Part", Vector3.new(G * 0.7, 0.2, G * 0.7), Color3.fromRGB(70, 70, 76), cf * CFrame.new(0, -G / 2 + G * y, 0), Enum.Material.Metal))
		end
		deco(mk(model, "Part", Vector3.new(G * 0.5, 0.12, G * 0.5), dark(color, 0.25), cf * CFrame.new(0, -G / 2 + G * 0.82 + 0.05, 0), Enum.Material.Wood))
	elseif def.conform == "rail" then
		-- card / ghost preview of the edge rail (on a ship it follows the hull: ShipHull buildConform)
		main = mk(model, "Part", Vector3.new(sz.X, 0.25, 0.3), color, cf * CFrame.new(0, sz.Y / 2 - 0.12, 0), material)
		for i = -2, 2 do
			deco(mk(model, "Part", Vector3.new(0.22, sz.Y - 0.2, 0.22), dark(color, 0.15), cf * CFrame.new(i * sz.X / 4.4, -0.1, 0), material))
		end
	elseif def.conform == "awning" then
		main = mk(model, "Part", Vector3.new(sz.X, 0.25, sz.Z), color, cf * CFrame.new(0, sz.Y / 2 - 0.12, 0), Enum.Material.Plaster)
		for i = 0, 3 do
			deco(mk(model, "Part", Vector3.new(sz.X + 0.02, 0.27, sz.Z / 8), Color3.fromRGB(200, 60, 55), cf * CFrame.new(0, sz.Y / 2 - 0.12, -sz.Z / 2 + (i * 2 + 1.5) * sz.Z / 8), Enum.Material.Plaster))
		end
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz2 in ipairs({ -1, 1 }) do
				deco(mk(model, "Part", Vector3.new(0.25, sz.Y, 0.25), Color3.fromRGB(130, 85, 50), cf * CFrame.new(sx * (sz.X / 2 - 0.2), 0, sz2 * (sz.Z / 2 - 0.2)), Enum.Material.Wood))
			end
		end
	elseif def.balcony then
		-- stern gallery: plank floor on brackets, a rail on three sides (open toward the ship = +Z)
		local fl = 0.35
		main = mk(model, "Part", Vector3.new(sz.X, fl, sz.Z), color, cf * CFrame.new(0, -sz.Y / 2 + fl / 2, 0), Enum.Material.WoodPlanks)
		deco(mk(model, "Part", Vector3.new(sz.X + 0.1, 0.15, sz.Z + 0.1), dark(color, 0.3), cf * CFrame.new(0, -sz.Y / 2 + fl, 0), Enum.Material.Wood))
		for _, sx in ipairs({ -1, 1 }) do
			deco(mk(model, "Part", Vector3.new(0.3, 0.9, 0.3), dark(color, 0.35), cf * CFrame.new(sx * sz.X * 0.3, -sz.Y / 2 - 0.3, sz.Z / 2 - 0.4), Enum.Material.Wood))
			deco(mk(model, "Part", Vector3.new(0.25, 0.22, sz.Z), GOLD_TRIM, cf * CFrame.new(sx * (sz.X / 2 - 0.12), -sz.Y / 2 + 2.6, 0), Enum.Material.Wood))
		end
		deco(mk(model, "Part", Vector3.new(sz.X, 0.22, 0.25), GOLD_TRIM, cf * CFrame.new(0, -sz.Y / 2 + 2.6, -sz.Z / 2 + 0.12), Enum.Material.Wood))
		-- balusters
		local n = math.max(2, math.floor(sz.X / 0.9))
		for i = 0, n do
			local x = -sz.X / 2 + 0.12 + i * (sz.X - 0.24) / n
			deco(mk(model, "Part", Vector3.new(0.18, 2.2, 0.18), dark(color, 0.1), cf * CFrame.new(x, -sz.Y / 2 + fl + 1.1, -sz.Z / 2 + 0.12), Enum.Material.Wood))
		end
		for _, sx in ipairs({ -1, 1 }) do
			for j = 1, math.max(1, math.floor(sz.Z / 0.9)) - 1 do
				deco(mk(model, "Part", Vector3.new(0.18, 2.2, 0.18), dark(color, 0.1), cf * CFrame.new(sx * (sz.X / 2 - 0.12), -sz.Y / 2 + fl + 1.1, -sz.Z / 2 + j * 0.9), Enum.Material.Wood))
			end
		end
	elseif def.spar then
		-- bowsprit: a square spar raking up over the bow (-Z), iron bands, a little cap
		local len = sz.Z
		local th = math.max(0.5, sz.X)
		local sparCf = cf * CFrame.new(0, -sz.Y / 2 + th / 2, len * 0.05) * CFrame.Angles(math.rad(14), 0, 0)
		main = mk(model, "Part", Vector3.new(th, th, len), color, sparCf, Enum.Material.Wood)
		for _, f in ipairs({ 0.15, 0.45 }) do
			deco(mk(model, "Part", Vector3.new(th + 0.12, th + 0.12, 0.22), Color3.fromRGB(70, 70, 76), sparCf * CFrame.new(0, 0, len / 2 - len * f), Enum.Material.Metal))
		end
		deco(mk(model, "Part", Vector3.new(th * 0.7, th * 0.7, 0.6), Color3.fromRGB(232, 192, 80), sparCf * CFrame.new(0, 0, -len / 2 - 0.2), Enum.Material.Wood))
	elseif def.flagLine then
		-- signal flags: a line falling from the top (bow end, -Z) to the deck, alternating pennants hanging on it
		local len, Y = sz.Z, sz.Y
		local a = Vector3.new(0, Y / 2, -len / 2)
		local b = Vector3.new(0, -Y / 2, len / 2)
		local d = (b - a)
		main = mk(model, "Part", Vector3.new(0.08, 0.08, d.Magnitude), Color3.fromRGB(60, 45, 35), cf * CFrame.lookAt(a + d / 2, b), Enum.Material.Fabric)
		main.CanCollide = false
		local cols = { Color3.fromRGB(220, 60, 55), Color3.fromRGB(250, 210, 70), Color3.fromRGB(60, 120, 220), Color3.fromRGB(245, 245, 245), Color3.fromRGB(70, 170, 90) }
		local n = math.max(3, math.floor(d.Magnitude / 1.3))
		for i = 1, n do
			local pt = a + d * ((i - 0.5) / n)
			local c = cols[(i - 1) % #cols + 1]
			for k = 0, 2 do
				-- a stepped triangle: 3 rows shrinking downward
				deco(mk(model, "Part", Vector3.new(0.06, 0.25, 0.9 - k * 0.3), c, cf * CFrame.new(pt + Vector3.new(0, -0.15 - k * 0.25, 0)), Enum.Material.Plaster))
			end
		end
	elseif def.flag then
		-- pole + gold finial + a two-tone flag flying aft (+Z)
		local Y = sz.Y
		main = mk(model, "Part", Vector3.new(0.22, Y, 0.22), Color3.fromRGB(130, 85, 50), cf, Enum.Material.Wood)
		deco(mk(model, "Part", Vector3.new(0.4, 0.3, 0.4), Color3.fromRGB(232, 192, 80), cf * CFrame.new(0, Y / 2 + 0.15, 0), Enum.Material.Wood))
		local fw, fh = math.max(1.6, Y * 0.42), math.max(1, Y * 0.26)
		for i = 0, 3 do
			local c = i % 2 == 0 and color or color:Lerp(Color3.new(1, 1, 1), 0.75)
			local wave = (i % 2 == 0) and 0 or 0.1
			deco(mk(model, "Part", Vector3.new(0.12, fh / 4, fw - i * 0.12), c, cf * CFrame.new(wave, Y / 2 - 0.3 - (i + 0.5) * fh / 4, fw / 2 + 0.1 - i * 0.06), Enum.Material.Plaster))
		end
	elseif def.wall and def.ladder then
		-- rails + rungs flat against the hull side (the side is at local +Z)
		local W, Y = sz.X, sz.Y
		main = mk(model, "Part", Vector3.new(W, Y, 0.2), color, cf * CFrame.new(0, 0, sz.Z / 2 - 0.1), Enum.Material.Wood)
		main.Transparency = 1
		for _, sx in ipairs({ -1, 1 }) do
			deco(mk(model, "Part", Vector3.new(0.2, Y, 0.25), dark(color, 0.2), cf * CFrame.new(sx * (W / 2 - 0.1), 0, 0), Enum.Material.Wood))
		end
		local n = math.max(2, math.floor(Y / 0.8))
		for i = 1, n do
			deco(mk(model, "Part", Vector3.new(W, 0.16, 0.22), color, cf * CFrame.new(0, -Y / 2 + i * Y / (n + 1), 0), Enum.Material.Wood))
		end
	elseif def.wall then
		-- window / entry port: a frame on the hull side, warm glass with mullions (window) or a plank door (port)
		local W, Y = sz.X, sz.Y
		local back = sz.Z / 2
		main = mk(model, "Part", Vector3.new(W, Y, 0.2), dark(color, 0.1), cf * CFrame.new(0, 0, back - 0.1), Enum.Material.Wood)
		local fr = 0.22
		for _, sx in ipairs({ -1, 1 }) do
			deco(mk(model, "Part", Vector3.new(fr, Y, 0.3), GOLD_TRIM, cf * CFrame.new(sx * (W / 2 - fr / 2), 0, back - 0.25), Enum.Material.Wood))
		end
		for _, sy in ipairs({ -1, 1 }) do
			deco(mk(model, "Part", Vector3.new(W, fr, 0.3), GOLD_TRIM, cf * CFrame.new(0, sy * (Y / 2 - fr / 2), back - 0.25), Enum.Material.Wood))
		end
		if p.id == "Window" then
			local glass = deco(mk(model, "Part", Vector3.new(W - 2 * fr, Y - 2 * fr, 0.1), Color3.fromRGB(255, 214, 130), cf * CFrame.new(0, 0, back - 0.22), Enum.Material.Neon))
			glass.Transparency = 0.15
			deco(mk(model, "Part", Vector3.new(0.12, Y - 2 * fr, 0.2), dark(color, 0.3), cf * CFrame.new(0, 0, back - 0.28), Enum.Material.Wood))
			deco(mk(model, "Part", Vector3.new(W - 2 * fr, 0.12, 0.2), dark(color, 0.3), cf * CFrame.new(0, 0, back - 0.28), Enum.Material.Wood))
			deco(mk(model, "Part", Vector3.new(W + 0.2, 0.18, 0.45), dark(color, 0.2), cf * CFrame.new(0, -Y / 2 - 0.05, back - 0.3), Enum.Material.Wood))
		else
			local door = deco(mk(model, "Part", Vector3.new(W - 2 * fr, Y - fr, 0.14), Color3.fromRGB(96, 60, 34), cf * CFrame.new(0, -fr / 2, back - 0.24), Enum.Material.WoodPlanks))
			deco(mk(model, "Part", Vector3.new(0.2, 0.2, 0.2), Color3.fromRGB(232, 192, 80), cf * CFrame.new(door.Size.X * 0.3, -fr / 2, back - 0.34), Enum.Material.Metal))
			for _, y in ipairs({ 0.25, -0.25 }) do
				deco(mk(model, "Part", Vector3.new(W - 2 * fr, 0.14, 0.18), Color3.fromRGB(70, 70, 76), cf * CFrame.new(0, y * Y, back - 0.3), Enum.Material.Metal))
			end
		end
	elseif p.id == "Hatch" then
		main = mk(model, "Part", Vector3.new(sz.X, sz.Y, sz.Z), dark(color, 0.15), cf, Enum.Material.Wood)
		local n = math.max(2, math.floor(sz.X / 0.6))
		for i = 0, n do
			deco(mk(model, "Part", Vector3.new(0.14, 0.08, sz.Z), color, cf * CFrame.new(-sz.X / 2 + 0.07 + i * (sz.X - 0.14) / n, sz.Y / 2, 0), Enum.Material.Wood))
			deco(mk(model, "Part", Vector3.new(sz.X, 0.08, 0.14), color, cf * CFrame.new(0, sz.Y / 2, -sz.Z / 2 + 0.07 + i * (sz.Z - 0.14) / n), Enum.Material.Wood))
		end
		deco(mk(model, "Part", Vector3.new(sz.X + 0.3, sz.Y * 0.8, sz.Z + 0.3), dark(color, 0.35), cf * CFrame.new(0, -sz.Y * 0.1, 0), Enum.Material.Wood))
	elseif p.id == "RopeCoil" then
		-- stacked square rings, each a bit smaller (a voxel coil)
		main = mk(model, "Part", Vector3.new(sz.X * 0.5, sz.Y, sz.Z * 0.5), dark(color, 0.3), cf, Enum.Material.Fabric)
		local layers = 3
		for k = 0, layers - 1 do
			local w = sz.X * (1 - k * 0.15)
			local y = -sz.Y / 2 + (k + 0.5) * sz.Y / layers
			for _, s in ipairs({ -1, 1 }) do
				deco(mk(model, "Part", Vector3.new(w, sz.Y / layers, 0.3), k % 2 == 0 and color or dark(color, 0.12), cf * CFrame.new(0, y, s * (w / 2 - 0.15)), Enum.Material.Fabric))
				deco(mk(model, "Part", Vector3.new(0.3, sz.Y / layers, w), k % 2 == 0 and color or dark(color, 0.12), cf * CFrame.new(s * (w / 2 - 0.15), y, 0), Enum.Material.Fabric))
			end
		end
	elseif p.id == "Crate" then
		main = mk(model, "Part", sz, color, cf, Enum.Material.WoodPlanks)
		local fr = 0.22
		for _, a in ipairs({ -1, 1 }) do
			for _, b in ipairs({ -1, 1 }) do
				deco(mk(model, "Part", Vector3.new(fr, sz.Y + 0.04, fr), dark(color, 0.35), cf * CFrame.new(a * (sz.X / 2 - fr / 2 + 0.02), 0, b * (sz.Z / 2 - fr / 2 + 0.02)), Enum.Material.Wood))
				deco(mk(model, "Part", Vector3.new(sz.X + 0.04, fr, fr), dark(color, 0.35), cf * CFrame.new(0, a * (sz.Y / 2 - fr / 2 + 0.02), b * (sz.Z / 2 - fr / 2 + 0.02)), Enum.Material.Wood))
				deco(mk(model, "Part", Vector3.new(fr, fr, sz.Z + 0.04), dark(color, 0.35), cf * CFrame.new(a * (sz.X / 2 - fr / 2 + 0.02), b * (sz.Y / 2 - fr / 2 + 0.02), 0), Enum.Material.Wood))
			end
		end
	elseif p.id == "Lantern" then
		-- iron cage: base, roof, 4 corner bars, warm glow inside, a hanging ring
		local iron = Color3.fromRGB(60, 60, 66)
		main = mk(model, "Part", Vector3.new(G * 0.22, G * 0.36, G * 0.22), color, cf * CFrame.new(0, -G * 0.2, 0), Enum.Material.Neon)
		deco(mk(model, "Part", Vector3.new(G * 0.36, 0.18, G * 0.36), iron, cf * CFrame.new(0, -G * 0.2 - G * 0.18 - 0.09, 0), Enum.Material.Metal))
		deco(mk(model, "Part", Vector3.new(G * 0.4, 0.22, G * 0.4), iron, cf * CFrame.new(0, -G * 0.2 + G * 0.18 + 0.11, 0), Enum.Material.Metal))
		deco(mk(model, "Part", Vector3.new(G * 0.18, 0.18, G * 0.18), iron, cf * CFrame.new(0, -G * 0.2 + G * 0.18 + 0.3, 0), Enum.Material.Metal))
		for _, a in ipairs({ -1, 1 }) do
			for _, b in ipairs({ -1, 1 }) do
				deco(mk(model, "Part", Vector3.new(0.1, G * 0.36, 0.1), iron, cf * CFrame.new(a * G * 0.15, -G * 0.2, b * G * 0.15), Enum.Material.Metal))
			end
		end
		local light = Instance.new("PointLight")
		light.Name = "ShipLamp" -- v0.25.155 (#33): switched by the ship's Lights attribute (Controllers/Sailing)
		light.Range = 22
		light.Brightness = 1.6
		light.Color = Color3.fromRGB(255, 200, 120)
		light.Parent = main
		main:SetAttribute("Lamp", true)
	elseif def.light == "spot" then
		-- v0.25.155 (#33): searchlight = iron drum on a post, glass front (local -Z), a SpotLight beam ahead
		local iron = color
		local floorY = -sz.Y / 2
		deco(mk(model, "Part", Vector3.new(0.35, sz.Y * 0.5, 0.35), iron, cf * CFrame.new(0, floorY + sz.Y * 0.25, 0), Enum.Material.Metal))
		local drum = deco(mk(model, "Part", Vector3.new(sz.X * 0.8, sz.Y * 0.5, sz.Z * 0.8), iron, cf * CFrame.new(0, floorY + sz.Y * 0.7, 0.1), Enum.Material.Metal))
		main = mk(model, "Part", Vector3.new(sz.X * 0.62, sz.Y * 0.38, 0.15), Color3.fromRGB(255, 240, 200), cf * CFrame.new(0, floorY + sz.Y * 0.7, 0.1 - drum.Size.Z / 2 - 0.05), Enum.Material.Neon)
		local spot = Instance.new("SpotLight")
		spot.Name = "ShipLamp"
		spot.Face = Enum.NormalId.Front
		spot.Angle = 38
		spot.Range = 60
		spot.Brightness = 5
		spot.Color = Color3.fromRGB(255, 240, 210)
		spot.Parent = main
		main:SetAttribute("Lamp", true)
	elseif def.kegs then
		-- v0.25.155 (#30): a low rack with three powder kegs on their sides (black bands, a red skull mark)
		local floorY = -sz.Y / 2
		main = mk(model, "Part", Vector3.new(sz.X * 0.9, 0.4, sz.Z * 0.9), dark(color, 0.1), cf * CFrame.new(0, floorY + 0.2, 0), Enum.Material.WoodPlanks)
		for i = -1, 1 do
			local kcf = cf * CFrame.new(i * sz.X * 0.28, floorY + 0.4 + sz.X * 0.13, 0)
			deco(mk(model, "Part", Vector3.new(sz.X * 0.26, sz.X * 0.26, sz.Z * 0.7), color, kcf, Enum.Material.Wood))
			for _, zz in ipairs({ -0.25, 0.25 }) do
				deco(mk(model, "Part", Vector3.new(sz.X * 0.28, sz.X * 0.28, 0.15), Color3.fromRGB(40, 40, 44), kcf * CFrame.new(0, 0, zz * sz.Z), Enum.Material.Metal))
			end
			deco(mk(model, "Part", Vector3.new(0.3, 0.3, 0.05), Color3.fromRGB(200, 50, 45), kcf * CFrame.new(0, 0, -sz.Z * 0.35 - 0.03), Enum.Material.SmoothPlastic))
		end
	elseif def.spyglass then
		-- v0.25.155 (#31): crow's nest = a post up to a round lookout basket, a spyglass on the rim
		local floorY = -sz.Y / 2
		main = mk(model, "Part", Vector3.new(0.6, sz.Y * 0.85, 0.6), color, cf * CFrame.new(0, floorY + sz.Y * 0.425, 0), material)
		local basketY = floorY + sz.Y * 0.85
		deco(mk(model, "Part", Vector3.new(sz.X * 0.9, 0.3, sz.Z * 0.9), dark(color, 0.1), cf * CFrame.new(0, basketY, 0), Enum.Material.WoodPlanks))
		for i = 0, 7 do
			local a = i * math.pi / 4
			deco(mk(model, "Part", Vector3.new(sz.X * 0.4, sz.Y * 0.12, 0.25), dark(color, 0.2), cf * CFrame.new(math.sin(a) * sz.X * 0.42, basketY + sz.Y * 0.06 + 0.15, math.cos(a) * sz.Z * 0.42) * CFrame.Angles(0, a, 0), Enum.Material.Wood))
		end
		deco(mk(model, "Part", Vector3.new(0.22, 0.22, 1.4), GOLD_TRIM, cf * CFrame.new(0.6, basketY + sz.Y * 0.12 + 0.4, -sz.Z * 0.42) * CFrame.Angles(0.25, 0, 0), Enum.Material.Metal))
	elseif def.pump then
		-- v0.25.155 (#32): bilge pump = a square barrel with a rocking handle and a spout over the side
		local floorY = -sz.Y / 2
		main = mk(model, "Part", Vector3.new(sz.X * 0.7, sz.Y * 0.8, sz.Z * 0.7), color, cf * CFrame.new(0, floorY + sz.Y * 0.4, 0), Enum.Material.Wood)
		deco(mk(model, "Part", Vector3.new(sz.X * 0.75, 0.15, sz.Z * 0.75), Color3.fromRGB(70, 70, 76), cf * CFrame.new(0, floorY + sz.Y * 0.65, 0), Enum.Material.Metal))
		deco(mk(model, "Part", Vector3.new(0.2, 0.2, sz.Z * 1.1), Color3.fromRGB(70, 70, 76), cf * CFrame.new(0, floorY + sz.Y * 0.95, 0) * CFrame.Angles(0.3, 0, 0), Enum.Material.Metal))
		deco(mk(model, "Part", Vector3.new(0.35, 0.35, 0.8), dark(color, 0.2), cf * CFrame.new(sz.X * 0.45, floorY + sz.Y * 0.55, 0) * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.Wood))
	else
		main = mk(model, "Part", sz, color, cf, material)
	end
	main.Name = "Main"
	model.PrimaryPart = main
	return model
end

-- Build a whole (anchored) ship from a design
function SM.BuildDesign(design, originCf, colorFn)
	if design.v == 2 then
		return require(Shared.Modules.ShipHull).Build(design, originCf, colorFn, SM.BuildPart)
	end
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

-- ===== Hull dressing (owner, v0.22.5: launched ships looked like flat planks floating on the sea) =====
-- The block design still decides stats; around it we build a real hull: a stepped V-hull under the waterline that
-- narrows toward bow and stern, bulwarks with a rail and a painted stripe along the deck (gun ports left open where a
-- cannon sits at the edge), a pointed prow and a transom stern. By length: dinghy (plain), sloop (bowsprit + raised
-- stern deck), galleon (stern castle with lit windows + lanterns, forecastle rail, figurehead).
-- style = { hull = Color3, trim = Color3, stripe = Color3 }. Returns the size class.
local WOOD_DARK = Color3.fromRGB(92, 60, 38)
-- v0.24.0 (owner): sizes that fit their crew. A grid cell is 4 studs and a character ~5 studs tall:
-- Dinghy (<= 7 rows, ~28 studs) seats 1 comfortably, 2-3 at most; Sloop (<= 12 rows); Galleon above that.
function SM.SizeClass(lengthCells)
	if lengthCells <= 7 then
		return "Dinghy"
	elseif lengthCells <= 12 then
		return "Sloop"
	end
	return "Galleon"
end

function SM.DressHull(model, design, originCf, style)
	style = style or {}
	local hullC = style.hull or Color3.fromRGB(132, 86, 52)
	local trimC = style.trim or WOOD_DARK
	local stripeC = style.stripe or Color3.fromRGB(230, 190, 80)
	local folder = Instance.new("Model")
	folder.Name = "Hull"
	folder.Parent = model
	-- deck footprint: per row (z) the outermost hull cells at y = 0, and which edge cells carry a cannon
	local rows, gun = {}, {}
	for _, p in ipairs(design.parts) do
		local def = ShipParts[p.id]
		if def and def.category == "Hull" and p.y == 0 then
			local r = rows[p.z]
			if not r then
				r = { minX = p.x, maxX = p.x + 1 }
				rows[p.z] = r
			end
			r.minX = math.min(r.minX, p.x)
			r.maxX = math.max(r.maxX, p.x + 1)
		elseif def and def.cannon then
			gun[p.z .. ":" .. p.x] = true
		end
	end
	local zs = {}
	for z in pairs(rows) do
		table.insert(zs, z)
	end
	if #zs == 0 then
		return nil
	end
	table.sort(zs)
	local zMin, zMax = zs[1], zs[#zs]
	local L = zMax - zMin + 1
	local class = SM.SizeClass(L)
	local function at(x, y, z) -- plot cells -> world (z grows toward the bow = -Z)
		return originCf * CFrame.new(x * G, y, -z * G)
	end
	local function part(size, color, cf, opts)
		opts = opts or {}
		local pt = mk(folder, opts.class or "Part", size, color, cf, opts.material or Enum.Material.WoodPlanks)
		pt.CanCollide = opts.collide == true
		pt.CanTouch = false
		pt.CastShadow = opts.shadow ~= false
		return pt
	end
	local depth = ({ Dinghy = 2, Sloop = 3, Galleon = 4 })[class] -- layers under the deck
	local layerH = 1.3
	local rail = ({ Dinghy = 1.1, Sloop = 1.4, Galleon = 1.7 })[class]
	-- 1) under the waterline: each row gets stepped layers that narrow toward the keel, and toward the ends
	for _, z in ipairs(zs) do
		local r = rows[z]
		local endK = math.min(z - zMin, zMax - z) -- rows from the nearer end
		local w = (r.maxX - r.minX) * G
		local cx = (r.minX + r.maxX) / 2
		for k = 1, depth do
			local shrink = k * (w / (depth + 1.5)) / 2 + math.max(0, 2 - endK) * k * 0.9
			local lw = w - shrink * 2
			if lw > 0.8 then
				part(Vector3.new(lw, layerH, G), k == depth and trimC or hullC, at(cx, -layerH * (k - 0.5), z + 0.5))
			end
		end
	end
	-- 2) bulwarks + rail + stripe along both sides (skip where a cannon sits on that edge cell)
	local prowFrom = zMax + 1
	do
		local pr = rows[zMax - 1]
		if pr and (pr.maxX - pr.minX) > (rows[zMax].maxX - rows[zMax].minX) then
			prowFrom = zMax
		end
	end
	for _, z in ipairs(zs) do
		local r = rows[z]
		for _, side in ipairs(z < prowFrom and { -1, 1 } or {}) do
			local edgeX = side < 0 and r.minX or r.maxX
			local cellX = side < 0 and r.minX or r.maxX - 1
			local x = edgeX * G + side * 0.25
			-- sheer: the rail rises toward the bow and the stern
			local h = G + rail + math.max(0, 3 - (zMax - z)) * 0.45 + math.max(0, 2 - (z - zMin)) * 0.35
			local cf = originCf * CFrame.new(x, h / 2, -(z + 0.5) * G)
			part(Vector3.new(0.5, h, G), hullC, cf, { collide = not gun[z .. ":" .. cellX] })
			if gun[z .. ":" .. cellX] then
				-- gun port: the wall stays low here so the barrel shows
				part(Vector3.new(0.6, 0.5, G), trimC, originCf * CFrame.new(x, G + rail - 0.25, -(z + 0.5) * G))
			else
				part(Vector3.new(0.7, 0.3, G + 0.02), trimC, originCf * CFrame.new(x, h + 0.15, -(z + 0.5) * G)) -- rail cap
			end
			part(Vector3.new(0.56, 0.45, G + 0.02), stripeC, originCf * CFrame.new(x, G * 0.55, -(z + 0.5) * G), { material = Enum.Material.SmoothPlastic })
		end
	end
	-- 3) prow: two angled planks meet at a raised stem in front of the first row, decked over, with the hull
	--    narrowing to the keel underneath; the forward deck row (bow wedges) gets a flat plank cover
	local front, zFront = rows[zMax], (zMax + 1) * G
	local prev = rows[zMax - 1]
	if prev and (prev.maxX - prev.minX) > (front.maxX - front.minX) then
		-- the first row is narrower (bow wedges): the prow starts from the last full-width row and covers it
		front, zFront = prev, zMax * G
	end
	local fw = (front.maxX - front.minX) * G
	local fcx = (front.minX + front.maxX) / 2 * G
	-- voxel prow (v0.24.0, owner: no triangles): the bow narrows in square steps, each step a deck plank row with
	-- bulwark blocks at both edges rising toward the stem, and stepped hull layers under it
	local steps = ({ Dinghy = 2, Sloop = 3, Galleon = 4 })[class]
	local stepLen = G
	local bowLen = steps * stepLen
	local tipZ = zFront + bowLen
	if zFront == zMax * G then
		-- deck over the sloped wedge row
		part(Vector3.new(fw, 0.3, G), Color3.fromRGB(176, 128, 82), at((front.minX + front.maxX) / 2, G + 0.15, zMax + 0.5), { collide = true })
	end
	for i = 1, steps do
		local ww = fw * (1 - i / (steps + 1))
		local zz = zFront + stepLen * (i - 0.5)
		local rise = i * 0.45
		part(Vector3.new(ww, G + rise, stepLen), Color3.fromRGB(176, 128, 82), originCf * CFrame.new(fcx, (G + rise) / 2, -zz), { collide = true })
		for _, side in ipairs({ -1, 1 }) do
			local x = fcx + side * (ww / 2 + 0.25)
			local h = rail + 0.5 + rise
			part(Vector3.new(0.5, h, stepLen + 0.02), hullC, originCf * CFrame.new(x, G + rise + h / 2, -zz), { collide = true })
			part(Vector3.new(0.7, 0.3, stepLen + 0.04), trimC, originCf * CFrame.new(x, G + rise + h + 0.15, -zz))
			part(Vector3.new(0.56, 0.45, stepLen + 0.04), stripeC, originCf * CFrame.new(x, G * 0.55, -zz), { material = Enum.Material.SmoothPlastic })
			-- close the step: a short wall across the front of the wider row behind
			local prevW = fw * (1 - (i - 1) / (steps + 1))
			local gap = (prevW - ww) / 2
			if gap > 0.3 then
				part(Vector3.new(gap + 0.5, G + rail + rise, 0.5), hullC, originCf * CFrame.new(fcx + side * (ww / 2 + gap / 2), (G + rail + rise) / 2, -(zz - stepLen / 2)), { collide = true })
			end
		end
		for k = 1, depth do
			local lw = ww * (1 - k / (depth + 1))
			if lw > 0.6 then
				part(Vector3.new(lw, layerH, stepLen + 0.05), hullC, originCf * CFrame.new(fcx, -layerH * (k - 0.5), -zz))
			end
		end
	end
	local H = G + rail + steps * 0.45 + 1.5
	local yc = H / 2 - 1.5
	-- stem post at the tip
	local tip = tipZ
	part(Vector3.new(1.2, H + 1.2, 1.2), trimC, originCf * CFrame.new(fcx, yc + 0.6, -(tip + 0.3)), { material = Enum.Material.Wood })
	-- 4) stern: transom board across the back
	local back = rows[zMin]
	local bw = (back.maxX - back.minX) * G
	local bcx = (back.minX + back.maxX) / 2 * G
	part(Vector3.new(bw + 1, G + rail + depth * layerH * 0.6, 0.6), hullC, originCf * CFrame.new(bcx, (G + rail - depth * layerH * 0.6) / 2, -(zMin * G - 0.3)), { collide = true })
	part(Vector3.new(bw + 1.1, 0.35, 0.8), trimC, originCf * CFrame.new(bcx, G + rail + 0.17, -(zMin * G - 0.3)))
	-- 5) by size class
	if class ~= "Dinghy" then
		-- bowsprit
		local len = class == "Galleon" and 14 or 9
		local base = originCf * CFrame.new(fcx, G + rail + 0.6, -(tip - 1))
		cyl(folder, len, 0.6, trimC, base * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, math.rad(18)) * CFrame.new(len / 2, 0, 0), Enum.Material.Wood)
		-- raised stern deck: a short quarterdeck over the last rows
		local qLen = math.min(3, L - 2) * G
		local qh = class == "Galleon" and G * 1.2 or G * 0.6
		part(Vector3.new(bw, qh, qLen), hullC, originCf * CFrame.new(bcx, G + qh / 2, -(zMin * G + qLen / 2)), { collide = true })
		part(Vector3.new(bw + 0.4, 0.4, qLen + 0.4), trimC, originCf * CFrame.new(bcx, G + qh + 0.2, -(zMin * G + qLen / 2)), { collide = true })
		if class == "Galleon" then
			-- stern castle: windows on the back face, lanterns at the corners
			local wy = G + qh * 0.5
			for i = -1, 1 do
				local win = part(Vector3.new(bw / 5, qh * 0.4, 0.2), Color3.fromRGB(255, 214, 120), originCf * CFrame.new(bcx + i * bw / 3.6, wy, -(zMin * G - 0.65)), { material = Enum.Material.Neon, shadow = false })
				win.Transparency = 0.15
			end
			for _, sx in ipairs({ -1, 1 }) do
				local lp = originCf * CFrame.new(bcx + sx * (bw / 2 + 0.2), G + qh + 1.6, -(zMin * G - 0.2))
				part(Vector3.new(0.9, 1.2, 0.9), Color3.fromRGB(255, 200, 90), lp, { material = Enum.Material.Neon, shadow = false })
				part(Vector3.new(1.1, 0.25, 1.1), trimC, lp * CFrame.new(0, 0.72, 0))
			end
			-- forecastle rail at the bow
			part(Vector3.new(fw, 0.9, 0.5), hullC, originCf * CFrame.new(fcx, G + rail + 0.45, -((zMax + 1) * G - 1)), { collide = true })
			-- figurehead: a gilded block at the stem
			part(Vector3.new(1.2, 1.6, 1.4), Color3.fromRGB(235, 190, 70), originCf * CFrame.new(fcx, G * 0.5, -(tip + 0.6)), { material = Enum.Material.SmoothPlastic })
		end
	end
	return class
end

-- Design bounds in grid cells (used to center the root)
function SM.Bounds(design)
	if design.v == 2 then
		local a, b = require(Shared.Modules.ShipHull).Bounds(design)
		return a / G, b / G
	end
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
