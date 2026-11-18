-- ModelFactory: procedural chibi models (placeholders until Blender models arrive)
-- A model at ReplicatedStorage.Assets.Monsters.<MonsterId> automatically replaces the placeholder
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MF = {}

local function part(parent, shape, size, color, cf, opts)
	local p = Instance.new("Part")
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = (opts and opts.material) or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = cf
	p.CanCollide = opts and opts.collide or false
	p.Massless = true
	p.CastShadow = true
	p.Name = (opts and opts.name) or "Part"
	p.Parent = parent
	return p
end
MF.Part = part

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function eyes(model, head, size, forwardOffset, spacing, height)
	local white = Color3.new(1, 1, 1)
	for _, side in ipairs({ -1, 1 }) do
		local cf = head.CFrame * CFrame.new(side * spacing, height, -forwardOffset)
		local e = part(model, Enum.PartType.Ball, Vector3.new(size, size, size), white, cf)
		local pupil = part(model, Enum.PartType.Ball, Vector3.new(size * 0.55, size * 0.55, size * 0.55), Color3.fromRGB(25, 25, 35), cf * CFrame.new(0, 0, -size * 0.3))
		weld(head, e)
		weld(head, pupil)
	end
end

local function hat(model, head, kind, s)
	if not kind then
		return
	end
	local top = head.CFrame * CFrame.new(0, head.Size.Y * 0.45, 0)
	local h
	if kind == "marine" then
		h = part(model, Enum.PartType.Cylinder, Vector3.new(0.5 * s, 2.2 * s, 2.2 * s), Color3.new(1, 1, 1), top * CFrame.Angles(0, 0, math.pi / 2))
		local band = part(model, Enum.PartType.Cylinder, Vector3.new(0.25 * s, 2.25 * s, 2.25 * s), Color3.fromRGB(40, 90, 200), top * CFrame.new(0, -0.2 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))
		weld(head, band)
	elseif kind == "bandana" then
		h = part(model, Enum.PartType.Ball, Vector3.new(2.1 * s, 1.1 * s, 2.1 * s), Color3.fromRGB(220, 60, 60), top * CFrame.new(0, -0.3 * s, 0))
	elseif kind == "clown" then
		h = part(model, Enum.PartType.Ball, Vector3.new(0.7 * s, 0.7 * s, 0.7 * s), Color3.fromRGB(255, 40, 40), head.CFrame * CFrame.new(0, 0, -head.Size.Z * 0.5))
	elseif kind == "cat" then
		for _, side in ipairs({ -1, 1 }) do
			local ear = part(model, Enum.PartType.Block, Vector3.new(0.5 * s, 0.8 * s, 0.3 * s), Color3.fromRGB(40, 35, 45), top * CFrame.new(side * 0.6 * s, 0.2 * s, 0) * CFrame.Angles(0, 0, side * -0.3))
			weld(head, ear)
		end
		return
	elseif kind == "captain" then
		-- tricorn: dark crown + wide brim + gold band, so quest guides read from far away
		h = part(model, Enum.PartType.Cylinder, Vector3.new(1.1 * s, 2.0 * s, 2.0 * s), Color3.fromRGB(40, 30, 30), top * CFrame.new(0, 0.3 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))
		local brim = part(model, Enum.PartType.Cylinder, Vector3.new(0.2 * s, 3.4 * s, 3.4 * s), Color3.fromRGB(50, 36, 34), top * CFrame.new(0, -0.15 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))
		weld(head, brim)
		local band = part(model, Enum.PartType.Cylinder, Vector3.new(0.25 * s, 2.05 * s, 2.05 * s), Color3.fromRGB(255, 200, 60), top * CFrame.new(0, 0.05 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))
		weld(head, band)
	elseif kind == "helmet" then
		h = part(model, Enum.PartType.Ball, Vector3.new(2.3 * s, 1.6 * s, 2.3 * s), Color3.fromRGB(150, 150, 160), top * CFrame.new(0, -0.35 * s, 0), { material = Enum.Material.Metal })
	end
	if h then
		weld(head, h)
	end
end

-- Build a monster: Model + HumanoidRootPart + Humanoid
function MF.Monster(def)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local custom = assets and assets:FindFirstChild("Monsters") and assets.Monsters:FindFirstChild(def.id)
	if custom then
		local m = custom:Clone()
		m.Name = def.id
		m:SetAttribute("RealModel", true)
		return m
	end

	local style = def.style or {}
	local s = style.scale or 1
	local c = style.color or Color3.fromRGB(200, 200, 200)
	local shape = style.shape or "humanoid"
	local model = Instance.new("Model")
	model.Name = def.id

	local rootSize = Vector3.new(2.4, 2.4, 2.4) * s
	local root = part(model, Enum.PartType.Block, rootSize, c, CFrame.new(0, 0, 0), { name = "HumanoidRootPart" })
	root.Transparency = 1
	root.Massless = false
	root.CanCollide = true
	local base = root.CFrame
	local body, head

	if shape == "crab" then
		body = part(model, Enum.PartType.Ball, Vector3.new(3.2, 1.8, 2.6) * s, c, base)
		for _, side in ipairs({ -1, 1 }) do
			local claw = part(model, Enum.PartType.Ball, Vector3.new(1.3, 1.1, 1.3) * s, c:Lerp(Color3.new(1, 1, 1), 0.15), base * CFrame.new(side * 1.9 * s, 0.4 * s, -1.2 * s))
			weld(body, claw)
			for i = -1, 1 do
				local leg = part(model, Enum.PartType.Block, Vector3.new(1.2, 0.25, 0.25) * s, c, base * CFrame.new(side * 1.6 * s, -0.7 * s, i * 0.6 * s) * CFrame.Angles(0, 0, side * 0.5))
				weld(body, leg)
			end
		end
		head = body
		eyes(model, body, 0.6 * s, 1.1 * s, 0.5 * s, 0.9 * s)
	elseif shape == "snail" then
		body = part(model, Enum.PartType.Block, Vector3.new(2.2, 1.2, 4.4) * s, Color3.fromRGB(255, 220, 170), base * CFrame.new(0, -0.6 * s, 0))
		local shell = part(model, Enum.PartType.Ball, Vector3.new(3, 3, 3) * s, c, base * CFrame.new(0, 1.1 * s, 0.7 * s))
		weld(body, shell)
		local swirl = part(model, Enum.PartType.Ball, Vector3.new(1.4, 1.4, 1.4) * s, c:Lerp(Color3.new(1, 1, 1), 0.35), shell.CFrame * CFrame.new(1.05 * s, 0, 0))
		weld(shell, swirl)
		head = part(model, Enum.PartType.Ball, Vector3.new(1.6, 1.6, 1.6) * s, Color3.fromRGB(255, 220, 170), base * CFrame.new(0, 0.4 * s, -1.9 * s))
		weld(body, head)
		local receiver = part(model, Enum.PartType.Block, Vector3.new(1.8, 0.4, 0.5) * s, Color3.fromRGB(40, 40, 40), base * CFrame.new(0, 2.8 * s, 0.7 * s))
		weld(shell, receiver)
		eyes(model, head, 0.4 * s, 0.7 * s, 0.35 * s, 0.6 * s)
	elseif shape == "seaking" then
		body = part(model, Enum.PartType.Ball, Vector3.new(4, 4, 4) * s, c, base * CFrame.new(0, 1 * s, 0))
		local prev = body
		for i = 1, 4 do
			local seg = part(model, Enum.PartType.Ball, Vector3.new(3.4, 3.4, 3.4) * s * (1 - i * 0.12), c:Lerp(Color3.new(0, 0, 0), i * 0.05), base * CFrame.new(0, (1 - i * 0.6) * s, i * 2.4 * s))
			weld(prev, seg)
		end
		local belly = part(model, Enum.PartType.Ball, Vector3.new(3, 3, 3) * s, Color3.fromRGB(250, 230, 180), base * CFrame.new(0, 0.6 * s, -0.8 * s))
		weld(body, belly)
		head = body
		eyes(model, body, 1 * s, 1.8 * s, 0.9 * s, 0.9 * s)
		for _, side in ipairs({ -1, 1 }) do
			local fin = part(model, Enum.PartType.Block, Vector3.new(0.3, 2.2, 1.6) * s, Color3.fromRGB(255, 120, 80), base * CFrame.new(side * 2 * s, 2.5 * s, 0.5 * s) * CFrame.Angles(0, 0, side * 0.5))
			weld(body, fin)
		end
	elseif shape == "boar" or shape == "wolf" or shape == "lion" or shape == "cat" then
		body = part(model, Enum.PartType.Ball, Vector3.new(2.6, 2.2, 3.6) * s, c, base)
		head = part(model, Enum.PartType.Ball, Vector3.new(2.2, 2.1, 2.1) * s, c:Lerp(Color3.new(1, 1, 1), 0.08), base * CFrame.new(0, 0.7 * s, -1.9 * s))
		weld(body, head)
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local leg = part(model, Enum.PartType.Block, Vector3.new(0.6, 1.2, 0.6) * s, c:Lerp(Color3.new(0, 0, 0), 0.2), base * CFrame.new(sx * 0.8 * s, -1.1 * s, sz * 1.1 * s))
				weld(body, leg)
			end
		end
		if shape == "boar" then
			for _, sx in ipairs({ -1, 1 }) do
				local tusk = part(model, Enum.PartType.Block, Vector3.new(0.2, 0.6, 0.2) * s, Color3.new(1, 1, 0.95), head.CFrame * CFrame.new(sx * 0.5 * s, -0.3 * s, -1 * s) * CFrame.Angles(0.4, 0, 0))
				weld(head, tusk)
			end
		elseif shape == "lion" then
			local mane = part(model, Enum.PartType.Ball, Vector3.new(3.2, 3, 1.6) * s, Color3.fromRGB(180, 90, 40), head.CFrame * CFrame.new(0, 0, 0.5 * s))
			weld(head, mane)
		elseif shape == "wolf" or shape == "cat" then
			for _, sx in ipairs({ -1, 1 }) do
				local ear = part(model, Enum.PartType.Block, Vector3.new(0.4, 0.8, 0.3) * s, c, head.CFrame * CFrame.new(sx * 0.6 * s, 1.1 * s, 0))
				weld(head, ear)
			end
		end
		eyes(model, head, 0.55 * s, 0.95 * s, 0.45 * s, 0.25 * s)
	else
		-- humanoid / monkey / fishman: big head, small body (chibi)
		local skin = shape == "fishman" and c or Color3.fromRGB(255, 215, 180)
		if shape == "monkey" then
			skin = c:Lerp(Color3.new(1, 0.9, 0.8), 0.4)
		end
		body = part(model, Enum.PartType.Block, Vector3.new(2, 2, 1.3) * s, c, base * CFrame.new(0, -0.2 * s, 0))
		head = part(model, Enum.PartType.Ball, Vector3.new(2.4, 2.4, 2.4) * s, skin, base * CFrame.new(0, 2 * s, 0))
		weld(body, head)
		for _, sx in ipairs({ -1, 1 }) do
			local arm = part(model, Enum.PartType.Block, Vector3.new(0.6, 1.6, 0.6) * s, skin, base * CFrame.new(sx * 1.35 * s, -0.2 * s, 0))
			arm.Name = sx < 0 and "LeftArm" or "RightArm"
			weld(body, arm)
			local leg = part(model, Enum.PartType.Block, Vector3.new(0.75, 1.1, 0.75) * s, c:Lerp(Color3.new(0, 0, 0), 0.35), base * CFrame.new(sx * 0.5 * s, -1.75 * s, 0))
			weld(body, leg)
		end
		if shape == "fishman" then
			local fin = part(model, Enum.PartType.Block, Vector3.new(0.3, 1.4, 1.4) * s, c:Lerp(Color3.new(0, 0, 0), 0.25), head.CFrame * CFrame.new(0, 1.2 * s, 0.3 * s) * CFrame.Angles(0.6, 0, 0))
			weld(head, fin)
			if def.isBoss then
				local nose = part(model, Enum.PartType.Block, Vector3.new(0.35, 0.35, 2.2) * s, Color3.fromRGB(230, 230, 230), head.CFrame * CFrame.new(0, 0, -1.8 * s))
				weld(head, nose)
			end
		elseif shape == "monkey" then
			local tail = part(model, Enum.PartType.Block, Vector3.new(0.3, 0.3, 1.8) * s, c, base * CFrame.new(0, -0.8 * s, 1.2 * s) * CFrame.Angles(0.6, 0, 0))
			weld(body, tail)
		end
		eyes(model, head, 0.55 * s, 1.05 * s, 0.45 * s, 0.15 * s)
		hat(model, head, style.hat, s)
	end
	weld(root, body)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root then
			weld(root, d)
		end
	end

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	-- HipHeight = distance from the bottom of HumanoidRootPart to the ground
	if shape == "crab" or shape == "snail" then
		hum.HipHeight = 0.1
	elseif shape == "seaking" then
		hum.HipHeight = 0.5
	elseif shape == "boar" or shape == "wolf" or shape == "lion" or shape == "cat" then
		hum.HipHeight = 0.5 * s
	else
		hum.HipHeight = 1.1 * s
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.Parent = model
	model.PrimaryPart = root
	return model
end

-- Town NPC (with ProximityPrompt)
function MF.NPC(name, color, hatKind)
	local def = { id = "NPC", style = { shape = "humanoid", color = color, scale = 1.1, hat = hatKind } }
	local m = MF.Monster(def)
	m.Name = name
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:Destroy()
	end
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
	return m
end

function MF.Billboard(adornee, title, subtitle, color, height)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Nameplate"
	bb.Size = UDim2.fromOffset(220, 60)
	bb.StudsOffsetWorldSpace = Vector3.new(0, height or 4, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 140
	bb.Adornee = adornee
	local t = Instance.new("TextLabel")
	t.Name = "Title"
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0.55, 0)
	t.Font = Enum.Font.Arcade
	t.TextScaled = true
	t.Text = title
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.3
	t.Parent = bb
	if subtitle then
		local s = t:Clone()
		s.Name = "Subtitle"
		s.Position = UDim2.new(0, 0, 0.55, 0)
		s.Size = UDim2.new(1, 0, 0.4, 0)
		s.Text = subtitle
		s.TextColor3 = Color3.fromRGB(255, 240, 200)
		s.Font = Enum.Font.Arcade
		s.Parent = bb
	end
	bb.Parent = adornee
	return bb
end

return MF
