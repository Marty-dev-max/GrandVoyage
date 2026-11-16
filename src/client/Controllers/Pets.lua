-- Pets (client): draws every player's active Sea Companion from the "Pet" attribute ("Species:stage:level") and
-- makes it follow its owner with a little hop. Purely local (no network traffic per frame).
-- Low-poly placeholder bodies built from parts; drop real models into ReplicatedStorage.Assets.Pets/<Species>_<stage>.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetsCfg = require(ReplicatedStorage.Shared.Config.Pets)

local PetsCtl = {}
local folder = Instance.new("Folder")
folder.Name = "PetsFX"
folder.Parent = workspace
local active = {} -- player -> { model, key, pos }

local function part(m, shape, size, color, offset, material)
	local p = Instance.new("Part")
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p:SetAttribute("Offset", offset)
	p.Parent = m
	return p
end

local function eyes(m, s, z, y, x)
	for _, side in ipairs({ -1, 1 }) do
		part(m, Enum.PartType.Ball, Vector3.new(0.35, 0.35, 0.35) * s, Color3.new(1, 1, 1), CFrame.new(side * x * s, y * s, z * s))
		part(m, Enum.PartType.Ball, Vector3.new(0.18, 0.18, 0.18) * s, Color3.new(0.05, 0.05, 0.08), CFrame.new(side * x * s, y * s, (z - 0.12) * s))
	end
end

local builders = {
	crab = function(m, sp, s)
		part(m, Enum.PartType.Ball, Vector3.new(2.2, 1.3, 1.8) * s, sp.color, CFrame.new())
		part(m, Enum.PartType.Ball, Vector3.new(1.6, 1.4, 1.5) * s, sp.accent, CFrame.new(0, 0.7 * s, 0.3 * s)) -- shell
		for _, side in ipairs({ -1, 1 }) do
			part(m, Enum.PartType.Ball, Vector3.new(0.8, 0.6, 0.6) * s, sp.color, CFrame.new(side * 1.3 * s, 0.1 * s, -0.8 * s))
		end
		eyes(m, s, -0.9, 0.6, 0.35)
	end,
	boar = function(m, sp, s)
		part(m, Enum.PartType.Ball, Vector3.new(1.8, 1.5, 2.6) * s, sp.color, CFrame.new())
		part(m, Enum.PartType.Ball, Vector3.new(1.2, 1.1, 1.1) * s, sp.color, CFrame.new(0, 0.2 * s, -1.4 * s))
		for _, side in ipairs({ -1, 1 }) do
			part(m, Enum.PartType.Block, Vector3.new(0.15, 0.15, 0.6) * s, sp.accent, CFrame.new(side * 0.35 * s, -0.1 * s, -2 * s) * CFrame.Angles(0.5, 0, 0))
		end
		eyes(m, s, -1.85, 0.45, 0.3)
	end,
	bird = function(m, sp, s)
		part(m, Enum.PartType.Ball, Vector3.new(1.3, 1.2, 1.7) * s, sp.color, CFrame.new())
		part(m, Enum.PartType.Block, Vector3.new(0.3, 0.25, 0.6) * s, sp.accent, CFrame.new(0, 0.1 * s, -1.05 * s))
		for _, side in ipairs({ -1, 1 }) do
			part(m, Enum.PartType.Block, Vector3.new(1.4, 0.12, 0.8) * s, sp.color:Lerp(Color3.new(0.6, 0.6, 0.65), 0.3), CFrame.new(side * 1.1 * s, 0.2 * s, 0.1 * s)):SetAttribute("Wing", side)
		end
		eyes(m, s, -0.7, 0.35, 0.3)
	end,
	puffer = function(m, sp, s)
		part(m, Enum.PartType.Ball, Vector3.new(1.8, 1.8, 1.8) * s, sp.color, CFrame.new())
		for i = 0, 9 do
			local a = i / 10 * math.pi * 2
			part(m, Enum.PartType.Block, Vector3.new(0.18, 0.18, 0.6) * s, sp.accent, CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -1 * s) * CFrame.Angles(0, 0, 0))
		end
		eyes(m, s, -0.85, 0.3, 0.4)
	end,
	lantern = function(m, sp, s)
		part(m, Enum.PartType.Ball, Vector3.new(1.4, 1.3, 2) * s, sp.color, CFrame.new())
		part(m, Enum.PartType.Block, Vector3.new(0.08, 0.08, 1) * s, sp.color, CFrame.new(0, 1 * s, -0.7 * s) * CFrame.Angles(0.8, 0, 0))
		local lure = part(m, Enum.PartType.Ball, Vector3.new(0.45, 0.45, 0.45) * s, sp.accent, CFrame.new(0, 1.3 * s, -1.2 * s), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = sp.accent
		light.Range = 10
		light.Parent = lure
		eyes(m, s, -0.95, 0.3, 0.35)
	end,
	serpent = function(m, sp, s)
		for i = 0, 4 do
			local k = 1 - i * 0.14
			part(m, Enum.PartType.Ball, Vector3.new(1.2, 1.2, 1.2) * s * k, i % 2 == 0 and sp.color or sp.color:Lerp(sp.accent, 0.25), CFrame.new(0, 0, i * 0.9 * s)):SetAttribute("Seg", i)
		end
		eyes(m, s, -0.55, 0.3, 0.3)
	end,
}

local function build(key)
	local species, stage = string.match(key, "^(%w+):(%d+)")
	local sp = PetsCfg.ById[species or ""]
	if not sp then
		return nil
	end
	stage = tonumber(stage) or 1
	local m = Instance.new("Model")
	m.Name = sp.id
	local custom = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Pets")
	custom = custom and custom:FindFirstChild(sp.id .. "_" .. stage)
	if custom then
		local c = custom:Clone()
		m:SetAttribute("HalfHeight", c:GetAttribute("HalfHeight"))
		for _, p in ipairs(c:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
				p:SetAttribute("Offset", c:GetPivot():ToObjectSpace(p.CFrame))
				p.Parent = m
			end
		end
	else
		local s = 0.8 + (stage - 1) * 0.35
		builders[sp.shape](m, sp, s)
	end
	m.Parent = folder
	return m, sp
end

local function place(m, cf, t)
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") then
			local off = p:GetAttribute("Offset") or CFrame.new()
			local wing = p:GetAttribute("Wing")
			if wing then
				off = off * CFrame.Angles(0, 0, wing * math.sin(t * 14) * 0.5)
			end
			local seg = p:GetAttribute("Seg")
			if seg then
				off = CFrame.new(math.sin(t * 4 - seg) * 0.4, 0, 0) * off
			end
			p.CFrame = cf * off
		end
	end
end

function PetsCtl.Start()
	-- Blender models arrive from the server a few seconds after join (AssetService): rebuild pets that still use placeholders
	task.spawn(function()
		local assets = ReplicatedStorage:WaitForChild("Assets", 120)
		local pets = assets and assets:WaitForChild("Pets", 120)
		if pets then
			pets.ChildAdded:Connect(function()
				for pl, a in pairs(active) do
					a.model:Destroy()
					active[pl] = nil
				end
			end)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for _, pl in ipairs(Players:GetPlayers()) do
			local key = pl:GetAttribute("Pet")
			local a = active[pl]
			if a and a.key ~= key then
				a.model:Destroy()
				active[pl] = nil
				a = nil
			end
			local root = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
			if key and root then
				if not a then
					local m, sp = build(key)
					if m then
						a = { model = m, key = key, pos = root.Position, sp = sp }
						active[pl] = a
					end
				end
				if a then
					-- follow behind-right of the owner, flyers hover higher
					local flyer = a.sp.shape == "bird" or a.sp.shape == "lantern" or a.sp.shape == "serpent"
					-- Blender models know their height: walkers stand on the ground (root is ~3 studs above it)
					local half = a.model:GetAttribute("HalfHeight")
					local y = flyer and 2.5 or (half and (half - 2.9) or -1.6)
					local goal = (root.CFrame * CFrame.new(3, y, 3.5)).Position
					a.pos = a.pos:Lerp(goal, math.clamp(dt * 6, 0, 1))
					if (a.pos - goal).Magnitude > 60 then
						a.pos = goal
					end
					local hop = flyer and math.sin(t * 3) * 0.4 or math.abs(math.sin(t * 8)) * 0.6 * math.clamp((goal - a.pos).Magnitude / 3, 0, 1)
					local look = root.Position + root.CFrame.LookVector * 40
					local cf = CFrame.lookAt(a.pos + Vector3.new(0, hop, 0), Vector3.new(look.X, a.pos.Y + hop, look.Z))
					place(a.model, cf, t)
				end
			end
		end
		for pl, a in pairs(active) do
			if not pl.Parent then
				a.model:Destroy()
				active[pl] = nil
			end
		end
	end)
end

return PetsCtl
