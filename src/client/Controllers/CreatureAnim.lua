-- CreatureAnim (client): hit flash and the voxel shatter on death for monsters.
-- The poses themselves (idle, walk, attack, hit) are real animations played by MonsterService on the server
-- (Shared/Modules/Anim, Config/AnimClips "Mon_*"), so every client sees them without work here.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Voxels = require(script.Parent.Voxels)

local CreatureAnim = {}
CreatureAnim.Stats = { rigged = 0, plain = 0, animated = 0, attacks = 0, hits = 0 }

-- white flash on hit (a short-lived Highlight, so we never keep dozens alive)
local function flash(model)
	-- red hit flash (owner: monsters blink red when struck)
	local hl = Instance.new("Highlight")
	hl.FillColor = Color3.fromRGB(255, 40, 40)
	hl.OutlineColor = Color3.fromRGB(255, 220, 220)
	hl.OutlineTransparency = 0.4
	hl.FillTransparency = 0.15
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Adornee = model
	hl.Parent = model
	TweenService:Create(hl, TweenInfo.new(0.2), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	Debris:AddItem(hl, 0.25)
end

-- death: the voxel body breaks into tumbling cubes
local function shatter(model, color, boss)
	local parts = {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 then
			table.insert(parts, p)
		end
	end
	if #parts == 0 then
		return
	end
	local budget = boss and 70 or 26
	local per = math.max(2, math.floor(budget / #parts))
	color = color or Color3.fromRGB(220, 220, 220)
	for _, p in ipairs(parts) do
		p.LocalTransparencyModifier = 1
		local s = p.Size
		local cube = math.clamp(math.min(s.X, s.Y, s.Z) / 2.2, 0.35, boss and 2.4 or 1.2)
		for _ = 1, per do
			local c = Instance.new("Part")
			c.Size = Vector3.one * cube * (0.7 + math.random() * 0.6)
			c.Color = color:Lerp(math.random() < 0.5 and Color3.new(1, 1, 1) or Color3.new(0, 0, 0), math.random() * 0.35)
			c.Material = Enum.Material.SmoothPlastic
			c.CanQuery = false
			c.CanTouch = false
			c.CastShadow = false
			c.CFrame = p.CFrame * CFrame.new((math.random() - 0.5) * s.X, (math.random() - 0.5) * s.Y, (math.random() - 0.5) * s.Z)
			c.Parent = workspace
			local out = (c.Position - model:GetPivot().Position)
			out = (out.Magnitude > 0.01 and out.Unit or Vector3.yAxis) * (8 + math.random() * 10) + Vector3.new(0, 14 + math.random() * 10, 0)
			c.AssemblyLinearVelocity = out
			c.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 18
			task.delay(0.7 + math.random() * 0.3, function()
				if c.Parent then
					TweenService:Create(c, TweenInfo.new(0.45), { Transparency = 1, Size = c.Size * 0.3 }):Play()
				end
			end)
			Debris:AddItem(c, 1.4)
		end
	end
end

-- death (v0.24.0, owner): the monster does not vanish at once. It topples over to the ground (gravity ease + a small
-- bounce), lies there for a beat and blinks, then breaks apart into voxel blocks and pixel dust in its own colors.
-- The server keeps the (anchored) body ~2.6 s for this; every move here is local to this client.
local function deathFall(model, color, boss)
	if not model.Parent then
		return
	end
	color = color or Color3.fromRGB(220, 220, 220)
	local parts, orig = {}, {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Transparency < 1 then
			table.insert(parts, p)
			orig[p] = p.CFrame
		end
	end
	if #parts == 0 then
		return
	end
	local okBox, bcf, bsize = pcall(model.GetBoundingBox, model)
	if not okBox then
		return shatter(model, color, boss)
	end
	local base = bcf.Position - Vector3.new(0, bsize.Y / 2, 0)
	local serpent = model:GetAttribute("BodyPts") ~= nil or bsize.Y > 40
	-- fall sideways, to the camera's left or right so the player sees the body go down
	local cam = workspace.CurrentCamera
	local right = cam and cam.CFrame.RightVector or Vector3.xAxis
	local dir = Vector3.new(right.X, 0, right.Z)
	dir = (dir.Magnitude > 0.01 and dir.Unit or Vector3.xAxis) * (math.random() < 0.5 and -1 or 1)
	local axis = Vector3.yAxis:Cross(dir).Unit
	local reach = math.max(bsize.X, bsize.Z) * 0.35
	local pivot = base + dir * reach
	local fallT = boss and 0.85 or 0.45
	local t0 = os.clock()
	local done = false
	local conn
	local function pose(angle, drop)
		local r = CFrame.new(pivot - Vector3.new(0, drop, 0)) * CFrame.fromAxisAngle(axis, angle) * CFrame.new(-pivot)
		for _, p in ipairs(parts) do
			if p.Parent then
				p.CFrame = r * orig[p]
			end
		end
	end
	if not serpent then
		conn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			local a
			if t < fallT then
				local k = t / fallT
				a = (k * k) * math.rad(88)
			elseif t < fallT + 0.22 then
				-- bounce back up a little, then settle flat
				local k = (t - fallT) / 0.22
				a = math.rad(88) - math.sin(k * math.pi) * math.rad(10)
			else
				a = math.rad(88)
				if done then
					conn:Disconnect()
				end
			end
			pose(a, math.min(1, t / fallT) * bsize.Y * 0.04)
		end)
		task.delay(fallT, function()
			-- thud: a ring of dust where it lands
			Voxels.Pixels(pivot + dir * bsize.Y * 0.4, { count = boss and 40 or 16, colors = { Color3.fromRGB(196, 176, 140), Color3.fromRGB(150, 130, 100) }, size = boss and 0.9 or 0.35, speed = boss and 18 or 9, gravity = 14, life = 0.6 })
		end)
	end
	-- lie still, blink twice, then dissolve
	task.delay((serpent and 0.1 or fallT + 0.5), function()
		for _ = 1, 2 do
			local hl = Instance.new("Highlight")
			hl.FillColor = Color3.new(1, 1, 1)
			hl.FillTransparency = 0.35
			hl.OutlineTransparency = 1
			hl.DepthMode = Enum.HighlightDepthMode.Occluded
			hl.Adornee = model
			hl.Parent = model
			task.wait(0.08)
			hl:Destroy()
			task.wait(0.1)
		end
		done = true
		if not model.Parent then
			return
		end
		local cf2, size2 = model:GetBoundingBox()
		local vol = size2.X * size2.Y * size2.Z
		local blockSize = math.clamp(math.min(size2.X, size2.Y, size2.Z) / 4, 0.3, boss and 2.2 or 0.9)
		local cols = { color, color:Lerp(Color3.new(0, 0, 0), 0.3), color:Lerp(Color3.new(1, 1, 1), 0.25) }
		for _, p in ipairs(parts) do
			if p.Color ~= Color3.new(1, 1, 1) and p.Color ~= Color3.fromRGB(163, 162, 165) then
				table.insert(cols, p.Color)
			end
		end
		Voxels.Blocks(cf2.Position, { count = math.clamp(math.floor(vol / (blockSize ^ 3) / 6), 10, boss and 60 or 26), colors = cols, size = { blockSize * 0.7, blockSize * 1.2 }, speed = boss and 16 or 8, up = boss and 14 or 9, spread = math.max(size2.X, size2.Z) * 0.3, life = 0.9 })
		Voxels.Pixels(cf2.Position, { count = boss and 90 or 40, colors = cols, size = boss and 0.8 or 0.3, speed = boss and 22 or 12, gravity = -4, up = 6, life = 0.9, spread = math.max(size2.X, size2.Z) * 0.6 })
		for _, p in ipairs(parts) do
			p.LocalTransparencyModifier = 1
			for _, d in ipairs(p:GetDescendants()) do
				if d:IsA("Decal") or d:IsA("Texture") then
					d.Transparency = 1
				end
			end
		end
	end)
end

-- overhead HP bars (made on the server): drain smoothly with a red chunk of what was lost, and punch on big hits
local barState = setmetatable({}, { __mode = "k" })
local function juiceBar(model)
	local hp, max = model:GetAttribute("HP"), model:GetAttribute("MaxHP")
	local back = model:FindFirstChild("HPBack", true)
	local fill = back and back:FindFirstChild("Fill")
	if not hp or not max or not fill then
		return
	end
	local st = barState[model]
	local ratio = math.clamp(hp / math.max(1, max), 0, 1)
	if not st then
		local chunk = Instance.new("Frame")
		chunk.Name = "Chunk"
		chunk.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
		chunk.BorderSizePixel = 0
		chunk.Size = UDim2.new(ratio, 0, 1, 0)
		chunk.ZIndex = 0
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = chunk
		chunk.Parent = back
		fill.ZIndex = 1
		local sc = Instance.new("UIScale")
		sc.Parent = back
		-- dress the plain server bar like our HUD bars: thicker, dark outline, glossy gradient, a white hit flash
		back.Size = UDim2.new(back.Size.X.Scale, back.Size.X.Offset, 0, 11)
		back.Position = UDim2.new(back.Position.X.Scale, back.Position.X.Offset, 1, -9)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(24, 20, 36)
		stroke.Thickness = 2
		stroke.Parent = back
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(fill.BackgroundColor3:Lerp(Color3.new(1, 1, 1), 0.35), fill.BackgroundColor3:Lerp(Color3.new(0, 0, 0), 0.2))
		g.Rotation = 90
		g.Parent = fill
		local flashF = Instance.new("Frame")
		flashF.Name = "HitFlash"
		flashF.BackgroundColor3 = Color3.new(1, 1, 1)
		flashF.BackgroundTransparency = 1
		flashF.BorderSizePixel = 0
		flashF.Size = UDim2.fromScale(1, 1)
		flashF.ZIndex = 3
		local fc = Instance.new("UICorner")
		fc.CornerRadius = UDim.new(1, 0)
		fc.Parent = flashF
		flashF.Parent = back
		st = { ratio = ratio, chunk = chunk, scale = sc, token = 0, flash = flashF, back = back, home = back.Position }
		barState[model] = st
		return
	end
	if ratio < st.ratio then
		st.token += 1
		local token = st.token
		local lost = st.ratio - ratio
		fill.Size = UDim2.new(st.ratio, 0, 1, 0)
		TweenService:Create(fill, TweenInfo.new(0.12), { Size = UDim2.new(ratio, 0, 1, 0) }):Play()
		task.delay(0.3, function()
			if st.token == token then
				TweenService:Create(st.chunk, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.new(ratio, 0, 1, 0) }):Play()
			end
		end)
		st.scale.Scale = 1 + math.min(0.3, 0.12 + lost * 1.5)
		TweenService:Create(st.scale, TweenInfo.new(0.28, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		-- white flash + a short shake
		st.flash.BackgroundTransparency = 0.15
		TweenService:Create(st.flash, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play()
		task.spawn(function()
			for k = 1, 4 do
				if not st.back.Parent then
					return
				end
				st.back.Position = st.home + UDim2.fromOffset(math.random(-4, 4) * (5 - k) / 4, math.random(-2, 2))
				task.wait(0.03)
			end
			st.back.Position = st.home
		end)
	else
		st.chunk.Size = UDim2.new(ratio, 0, 1, 0)
	end
	st.ratio = ratio
end

local function watchMob(model)
	if not model:IsA("Model") then
		return
	end
	juiceBar(model)
	model:GetAttributeChangedSignal("HP"):Connect(function()
		juiceBar(model)
	end)
end

function CreatureAnim.Start()
	Net.OnFX(function(kind, d)
		if type(d) ~= "table" or typeof(d.model) ~= "Instance" then
			return
		end
		if kind == "MobAttack" then
			CreatureAnim.Stats.attacks += 1
		elseif kind == "Damage" then
			CreatureAnim.Stats.hits += 1
			flash(d.model) -- the server sends damage on the attacker's strike frame
		elseif kind == "MobDeath" then
			deathFall(d.model, d.color, d.boss)
		end
	end)
	task.spawn(function()
		local folder = workspace:WaitForChild("Monsters", 60)
		if not folder then
			return
		end
		for _, m in ipairs(folder:GetChildren()) do
			watchMob(m)
		end
		folder.ChildAdded:Connect(function(m)
			task.wait(0.2) -- let its nameplate replicate
			watchMob(m)
		end)
	end)
end

-- Dev tab: how many monsters nearby have joints and are playing animations right now
function CreatureAnim.Survey()
	local st = CreatureAnim.Stats
	st.rigged, st.plain, st.animated = 0, 0, 0
	local folder = workspace:FindFirstChild("Monsters")
	local cam = workspace.CurrentCamera
	if not folder or not cam then
		return st
	end
	for _, m in ipairs(folder:GetChildren()) do
		local root = m:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - cam.Focus.Position).Magnitude < 200 then
			if root:FindFirstChildOfClass("Motor6D") then
				st.rigged += 1
			else
				st.plain += 1
			end
			local hum = m:FindFirstChildOfClass("Humanoid")
			local animator = hum and hum:FindFirstChildOfClass("Animator")
			if animator and #animator:GetPlayingAnimationTracks() > 0 then
				st.animated += 1
			end
		end
	end
	return st
end

return CreatureAnim
