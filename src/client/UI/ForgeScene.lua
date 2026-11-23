-- ForgeScene (v0.25.106, owner): FORGE / EVOLVE in the Blacksmith play a ~3 s 3D cutscene over the stage: a still copy
-- of the island's Blacksmith NPC hammers your item on an anvil three times (clang, sparks, shake), then the result shows.
-- The copy is posed here (anchored voxel blocks, like NpcLife does in the world): limbs found by their rest position in
-- the root's space, the right arm swings around the shoulder with a block hammer in the hand.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Audio = require(script.Parent.Parent.Controllers.Audio)
local NpcLife = require(script.Parent.Parent.Controllers.NpcLife)
local BladeModel = require(ReplicatedStorage.Shared.Modules.BladeModel)

local ForgeScene = {}

local SHOULDER_Y, ELBOW_Y, HIP_Y = 1.95, 0.94, 0.1 -- VoxelChar rest layout (root 2.6 above the feet), as in NpcLife
local ARM, HANDLE, HEAD_H = 2.0, 1.6, 0.95
local TOP = 2.2 -- anvil face top
local ROOT = CFrame.new(-1.5, TOP + 0.1 + HEAD_H / 2 - SHOULDER_Y + ARM, 1.6) -- the head lands on the item at arm angle 0
local FLOOR = ROOT.Y - 2.6
local UP = 2.3 -- arm angle at the top of the swing (radians, forward/up)
local DURATION = 3.0
local STRIKES = { 0.75, 1.55, 2.35 }
-- arm angle keys { time, angle }; a key that reaches 0 is the hammer coming down (ease in = it speeds up)
local KEYS = { { 0, 0.1 }, { 0.5, UP }, { 0.61, UP }, { 0.75, 0 }, { 0.85, 0 }, { 1.3, UP }, { 1.41, UP }, { 1.55, 0 }, { 1.65, 0 }, { 2.1, UP }, { 2.21, UP }, { 2.35, 0 }, { 2.45, 0 }, { 2.95, 0.1 } }

local function armAngle(t)
	for i = 2, #KEYS do
		local k0, k1 = KEYS[i - 1], KEYS[i]
		if t <= k1[1] then
			local x = math.clamp((t - k0[1]) / (k1[1] - k0[1]), 0, 1)
			x = k1[2] == 0 and x * x or x * x * (3 - 2 * x)
			return k0[2] + (k1[2] - k0[2]) * x
		end
	end
	return KEYS[#KEYS][2]
end

local function block(parent, size, cf, color, material)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

-- the Blacksmith nearest to you (the server only forges next to one)
local function blacksmith()
	local char = Players.LocalPlayer.Character
	local me = char and char:FindFirstChild("HumanoidRootPart")
	local best, bd
	for _, m in ipairs(CollectionService:GetTagged("NPC")) do
		local r = m:GetAttribute("Role") == "Blacksmith" and (m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart)
		if r and m.Parent then
			local d = me and (r.Position - me.Position).Magnitude or 0
			if not bd or d < bd then
				best, bd = m, d
			end
		end
	end
	return best
end

-- a still copy of the NPC with every tag, prompt, label and script stripped (NpcLife / Interact must not see it)
local function npcCopy(world)
	local src = blacksmith()
	if not src then
		return nil
	end
	NpcLife.Rest(src)
	local ok, m = pcall(function()
		return src:Clone()
	end)
	if not ok or not m then
		return nil
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("LuaSourceContainer") or d:IsA("Humanoid") or d:IsA("Sound") then
			d:Destroy()
		else
			for _, tag in ipairs(CollectionService:GetTags(d)) do
				CollectionService:RemoveTag(d, tag)
			end
		end
	end
	for _, tag in ipairs(CollectionService:GetTags(m)) do
		CollectionService:RemoveTag(m, tag)
	end
	local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
	if not root then
		m:Destroy()
		return nil
	end
	m:PivotTo(ROOT * root.CFrame:ToObjectSpace(m:GetPivot()))
	m.Parent = world
	-- limbs by rest position (NpcLife's rule): arms = |x| > 1 above the hand, legs below the hips
	local parts = {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root then
			local rel = ROOT:ToObjectSpace(d.CFrame)
			local p = rel.Position
			local kind = "body"
			if math.abs(p.X) > 1.0 and p.Y < SHOULDER_Y + 0.3 then
				kind = p.X >= 0 and "right" or "left"
			elseif p.Y < HIP_Y then
				kind = "leg"
			end
			table.insert(parts, { part = d, rel = rel, kind = kind })
		end
	end
	root.Transparency = 1
	return parts
end

-- the item lies on the anvil: swords flat with the blade under the hammer, other weapons fitted by their bounding box,
-- anything without a model (fists, legs, armor) is a glowing bar of hot metal
local function itemOnAnvil(world, def)
	if def and def.blade then
		local m = BladeModel.Build(def.blade, "drawn")
		-- flats up, tip toward +X, grip just off the anvil's left edge
		m:PivotTo(CFrame.fromMatrix(Vector3.new(-2.1, TOP + 0.05, 0), Vector3.yAxis, Vector3.new(0, 0, -1)))
		m.Parent = world
		return
	end
	local UI = require(script.Parent.UIKit)
	local tpl = def and def.weaponType and def.weaponType ~= "Knuckles" and def.weaponType ~= "Shoes" and UI.ModelAsset("Weapons", def.weaponType)
	if tpl then
		local m = tpl:Clone()
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		local _, ext = m:GetBoundingBox()
		local turn = (ext.Z >= ext.X and ext.Z >= ext.Y) and CFrame.Angles(0, math.pi / 2, 0) or (ext.Y >= ext.X and CFrame.Angles(0, 0, math.pi / 2) or CFrame.new())
		m:PivotTo(turn * m:GetPivot())
		local scale = 3.2 / math.max(ext.X, ext.Y, ext.Z, 0.1)
		pcall(function()
			m:ScaleTo(m:GetScale() * scale)
		end)
		local cf, size = m:GetBoundingBox()
		m:PivotTo(CFrame.new(0.2 - cf.X, TOP + size.Y / 2 - cf.Y, -cf.Z) * m:GetPivot())
		m.Parent = world
		return
	end
	block(world, Vector3.new(2.6, 0.22, 0.7), CFrame.new(0.2, TOP + 0.11, 0), Color3.fromRGB(255, 140, 50), Enum.Material.Neon)
end

-- plays over `parent` (fills it), calls onDone after ~3 s
function ForgeScene.Play(parent, def, onDone)
	local layer = Instance.new("Frame")
	layer.Size = UDim2.fromScale(1, 1)
	layer.BackgroundColor3 = Color3.fromRGB(26, 20, 22)
	layer.BorderSizePixel = 0
	layer.ZIndex = 40
	layer.Parent = parent
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.fromScale(1, 1)
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(130, 110, 100)
	vp.LightColor = Color3.fromRGB(255, 214, 170)
	vp.LightDirection = Vector3.new(-0.5, -1, 0.7)
	vp.ImageTransparency = 1
	vp.ZIndex = 41
	vp.Parent = layer
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 236, 190)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 42
	flash.Parent = layer
	local world = Instance.new("Model")
	world.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 38
	cam.Parent = vp
	vp.CurrentCamera = cam
	-- v0.25.110: pulled back so the whole smith (about 7 studs with the hat) and the anvil fit (the head was cut off)
	local camCF = CFrame.lookAt(Vector3.new(5.6, 6.4, -11.2), Vector3.new(-0.5, 3.5, 0.6))

	-- forge corner: stone floor, anvil (foot, waist, face, horn), a glowing hearth behind
	local iron, dark = Color3.fromRGB(92, 96, 112), Color3.fromRGB(62, 64, 78)
	block(world, Vector3.new(18, 0.4, 14), CFrame.new(0, FLOOR - 0.2, 2), Color3.fromRGB(74, 62, 58), Enum.Material.Slate)
	block(world, Vector3.new(2.8, 0.6, 1.6), CFrame.new(0, FLOOR + 0.3, 0), dark)
	block(world, Vector3.new(1.4, TOP - 0.7 - FLOOR - 0.6, 1.0), CFrame.new(0, (FLOOR + 0.6 + TOP - 0.7) / 2, 0), dark)
	block(world, Vector3.new(4.0, 0.7, 1.6), CFrame.new(0, TOP - 0.35, 0), iron)
	block(world, Vector3.new(1.2, 0.5, 1.0), CFrame.new(2.55, TOP - 0.3, 0), iron)
	block(world, Vector3.new(0.6, 0.3, 0.6), CFrame.new(3.35, TOP - 0.3, 0), iron)
	block(world, Vector3.new(5, 3.2, 1.2), CFrame.new(1.2, FLOOR + 1.6, 6.2), Color3.fromRGB(96, 70, 60), Enum.Material.Brick)
	block(world, Vector3.new(3, 1.2, 0.4), CFrame.new(1.2, FLOOR + 1.3, 5.5), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
	itemOnAnvil(world, def)
	local body = npcCopy(world)

	-- hammer (hand space at arm angle 0: handle forward along -Z, head at the end, striking face down)
	local hammer = {
		{ block(world, Vector3.new(0.22, 0.22, HANDLE), CFrame.new(), Color3.fromRGB(120, 78, 44), Enum.Material.Wood), CFrame.new(0, 0, -HANDLE / 2) },
		{ block(world, Vector3.new(0.55, HEAD_H, 0.55), CFrame.new(), Color3.fromRGB(70, 72, 84), Enum.Material.Metal), CFrame.new(0, 0, -HANDLE) },
	}
	local S = Vector3.new(1.5, SHOULDER_Y, 0)
	local SL = Vector3.new(-1.5, SHOULDER_Y, 0)

	local sparks = {}
	local function strike(i)
		Audio.Play("AnvilClang", { pitch = 0.95 + i * 0.05 })
		flash.BackgroundTransparency = 0.55
		local hit = Vector3.new(0, TOP + 0.2, 0)
		for _ = 1, 16 do
			local p = block(world, Vector3.new(0.14, 0.14, 0.14), CFrame.new(hit), Color3.fromRGB(255, 210, 90), Enum.Material.Neon)
			local a = math.random() * math.pi * 2
			local v = Vector3.new(math.cos(a) * (3 + math.random() * 5), 4 + math.random() * 6, math.sin(a) * (3 + math.random() * 5))
			table.insert(sparks, { p = p, v = v, life = 0.45 + math.random() * 0.25, t = 0 })
		end
	end

	local t0 = os.clock()
	local struck, shakeUntil = 0, 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not vp.Parent then -- the window redrew or closed mid-scene: still report back so the forge isn't stuck busy
			conn:Disconnect()
			task.spawn(onDone)
			return
		end
		local t = os.clock() - t0
		vp.ImageTransparency = math.max(0, 1 - t / 0.25)
		flash.BackgroundTransparency = math.min(1, flash.BackgroundTransparency + dt * 4)
		while struck < #STRIKES and t >= STRIKES[struck + 1] do
			struck += 1
			strike(struck)
			shakeUntil = t + 0.14
		end
		local shake = t < shakeUntil and Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * 0.25 or Vector3.zero
		cam.CFrame = camCF + shake
		local a = armAngle(t)
		local lean = -0.1 * (1 - a / UP) -- leans into each blow
		local torso = ROOT * CFrame.new(0, HIP_Y, 0) * CFrame.Angles(lean, 0, 0) * CFrame.new(0, -HIP_Y, 0)
		local right = torso * CFrame.new(S) * CFrame.Angles(a, 0, 0) * CFrame.new(-S)
		local left = torso * CFrame.new(SL) * CFrame.Angles(0.55, 0, 0) * CFrame.new(-SL) -- steadying the piece
		for _, b in ipairs(body or {}) do
			local base = (b.kind == "right" and right) or (b.kind == "left" and left) or (b.kind == "leg" and ROOT) or torso
			b.part.CFrame = base * b.rel
		end
		local hand = torso * CFrame.new(S) * CFrame.Angles(a, 0, 0) * CFrame.new(0, -ARM, 0)
		for _, h in ipairs(hammer) do
			h[1].CFrame = hand * h[2]
		end
		for i = #sparks, 1, -1 do
			local s = sparks[i]
			s.t += dt
			s.v += Vector3.new(0, -26 * dt, 0)
			s.p.CFrame += s.v * dt
			local k = 1 - s.t / s.life
			s.p.Size = Vector3.one * 0.14 * math.max(k, 0.05)
			if k <= 0 then
				s.p:Destroy()
				table.remove(sparks, i)
			end
		end
		if t >= DURATION then
			conn:Disconnect()
			layer:Destroy()
			task.spawn(onDone)
		end
	end)
end

return ForgeScene
