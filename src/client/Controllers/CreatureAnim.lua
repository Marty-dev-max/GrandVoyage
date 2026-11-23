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

-- v0.25.81 (owner: monsters' FACES stayed floating after death): voxel faces are Decals on invisible plates
-- (Transparency 1), so "visible" = a see-able part OR a plate carrying a decal; hiding one hides its decals too
local function seen(p)
	return p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and (p.Transparency < 1 or p:FindFirstChildOfClass("Decal") ~= nil)
end
local function hide(p)
	p.LocalTransparencyModifier = 1
	for _, d in ipairs(p:GetChildren()) do
		if d:IsA("Decal") then
			d.LocalTransparencyModifier = 1
		end
	end
end
CreatureAnim.Stats = { rigged = 0, plain = 0, animated = 0, attacks = 0, hits = 0 }

-- white flash on hit (a short-lived Highlight, so we never keep dozens alive)
local function flash(model)
	-- red hit flash (owner: monsters blink red when struck)
	local hl = Instance.new("Highlight")
	-- v0.25.77 (owner): a PERFECT hit flashes YELLOW instead (VFX BasicAttack marks the target with PerfectUntil)
	local perfect = (model:GetAttribute("PerfectUntil") or 0) > os.clock()
	hl.FillColor = perfect and Color3.fromRGB(255, 225, 60) or Color3.fromRGB(255, 40, 40)
	hl.OutlineColor = perfect and Color3.fromRGB(255, 250, 200) or Color3.fromRGB(255, 220, 220)
	hl.OutlineTransparency = 0.4
	hl.FillTransparency = 0.15
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Adornee = model
	hl.Parent = model
	TweenService:Create(hl, TweenInfo.new(0.2), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	Debris:AddItem(hl, 0.25)
end

-- v0.25.77 (owner): a Swordsman skill kill cuts the monster in two: "h" = top and bottom (Tornado Cut, Flying Slash),
-- "v" = left and right along the blow (Demon Cross). A bright cut line, the halves slide apart and drop, then dissolve.
function CreatureAnim.SplitDeath(model, _color, mode, dir)
	local ok, bcf, bsize = pcall(model.GetBoundingBox, model)
	if not ok or not model.Parent then
		return
	end
	local center = bcf.Position
	dir = (typeof(dir) == "Vector3" and dir.Magnitude > 0.1) and dir.Unit or Vector3.zAxis
	local side = dir:Cross(Vector3.yAxis).Unit -- the cut plane of a "v" split runs along the blow
	local halves = { {}, {} }
	local orig = {}
	for _, p in ipairs(model:GetDescendants()) do
		if seen(p) then
			local rel = p.Position - center
			local a = mode == "v" and (rel:Dot(side) > 0 and 1 or 2) or (rel.Y > bsize.Y * 0.05 and 1 or 2)
			table.insert(halves[a], p)
			orig[p] = p.CFrame
		end
	end
	-- the cut: a thin white-hot line through the body
	local cutCF = mode == "v" and CFrame.lookAt(center, center + side) * CFrame.Angles(0, 0, math.pi / 2) or CFrame.new(center + Vector3.new(0, bsize.Y * 0.05, 0))
	local line = Instance.new("Part")
	line.Anchored, line.CanCollide, line.CanQuery, line.CanTouch, line.CastShadow = true, false, false, false, false
	line.Material = Enum.Material.Neon
	line.Color = Color3.fromRGB(255, 250, 235)
	line.Size = mode == "v" and Vector3.new(bsize.Y * 1.3, 0.12, math.max(bsize.X, bsize.Z) * 1.3) or Vector3.new(math.max(bsize.X, bsize.Z) * 1.4, 0.12, math.max(bsize.X, bsize.Z) * 1.4)
	line.CFrame = cutCF
	line.Parent = workspace
	TweenService:Create(line, TweenInfo.new(0.25), { Transparency = 1, Size = line.Size * Vector3.new(1.2, 0.2, 1.2) }):Play()
	Debris:AddItem(line, 0.3)
	-- v0.25.80 (owner: the halves floated and the shatter lagged): each half becomes a LOCAL physics copy (the real
	-- parts hide) that falls, tumbles and lands on the ground, then fades. One invisible box collider per half (cut at
	-- the plane, so the two never overlap and explode apart); the visible blocks are welded to it, massless, no collision.
	local keep = { SpecialMesh = true, Decal = true, Texture = true, SurfaceAppearance = true }
	for i, list in ipairs(halves) do
		if #list > 0 then
			-- this half's world box
			local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
			for _, p in ipairs(list) do
				local h = p.Size / 2
				lo = lo:Min(p.Position - h)
				hi = hi:Max(p.Position + h)
			end
			local cut = center + Vector3.new(0, bsize.Y * 0.05, 0)
			if mode == "v" then
				-- keep the collider on its own side of the cut plane
				local away = side * (i == 1 and 1 or -1)
				local mid = (lo + hi) / 2
				local d0 = (mid - center):Dot(away)
				if d0 < 0.3 then
					lo, hi = lo + away * (0.3 - d0), hi + away * (0.3 - d0)
				end
			elseif i == 1 then
				lo = Vector3.new(lo.X, math.max(lo.Y, cut.Y + 0.1), lo.Z)
			else
				hi = Vector3.new(hi.X, math.min(hi.Y, cut.Y - 0.1), hi.Z)
			end
			local size = (hi - lo):Max(Vector3.one * 0.6)
			local box = Instance.new("Part")
			box.Name = "SplitHalf"
			box.Transparency = 1
			box.Size = size * 0.85
			box.CFrame = CFrame.new((lo + hi) / 2)
			box.CanQuery, box.CanTouch, box.CastShadow = false, false, false
			box.CustomPhysicalProperties = PhysicalProperties.new(2, 0.6, 0.2)
			local copies = {}
			for _, p in ipairs(list) do
				local was = p.Archivable
				p.Archivable = true
				local c = p:Clone()
				p.Archivable = was
				if c then
					for _, ch in ipairs(c:GetChildren()) do
						if not keep[ch.ClassName] then
							ch:Destroy()
						end
					end
					c.Anchored = false
					c.CanCollide, c.CanQuery, c.CanTouch = false, false, false
					c.Massless = true
					c.CFrame = p.CFrame
					c.LocalTransparencyModifier = 0
					local w = Instance.new("WeldConstraint")
					w.Part0, w.Part1 = box, c
					w.Parent = c
					c.Parent = box
					table.insert(copies, c)
				end
				hide(p)
			end
			box.Parent = workspace
			-- the push: the top slides off along the blow and tips over / the two sides fall apart
			local push, spin
			if mode == "v" then
				local away = side * (i == 1 and 1 or -1)
				push = away * 9 + Vector3.new(0, 6, 0)
				spin = Vector3.yAxis:Cross(away).Unit * 3.5
			elseif i == 1 then
				push = dir * 10 + Vector3.new(0, 9, 0)
				spin = Vector3.yAxis:Cross(dir).Unit * 4
			else
				push = -dir * 1.5
				spin = Vector3.yAxis:Cross(-dir).Unit * 1.5
			end
			box.AssemblyLinearVelocity = push
			box.AssemblyAngularVelocity = spin
			task.delay(2.4, function()
				for _, c in ipairs(copies) do
					if c.Parent then
						TweenService:Create(c, TweenInfo.new(0.5), { Transparency = 1 }):Play()
					end
				end
				Debris:AddItem(box, 0.55)
			end)
		end
	end
	-- keep the real model hidden until the server removes it
	task.spawn(function()
		while model.Parent do
			for _, list in ipairs(halves) do
				for _, p in ipairs(list) do
					hide(p)
				end
			end
			task.wait(0.1)
		end
	end)
	Voxels.Pixels(center, { count = 26, colors = { Color3.fromRGB(255, 250, 235), Color3.fromRGB(200, 40, 50) }, size = 0.3, speed = 12, gravity = 10, life = 0.5, spread = 1 })
end

-- death: the voxel body breaks into tumbling cubes
local function shatter(model, color, boss)
	local parts = {}
	for _, p in ipairs(model:GetDescendants()) do
		if seen(p) then
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
		hide(p)
		if p.Transparency >= 1 then
			continue -- a face plate: hidden, no cubes
		end
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
CreatureAnim.Shatter = shatter

local function deathFall(model, color, boss)
	if not model.Parent then
		return
	end
	color = color or Color3.fromRGB(220, 220, 220)
	local parts, orig = {}, {}
	for _, p in ipairs(model:GetDescendants()) do
		if seen(p) then
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
			hide(p)
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
			if d.split and typeof(d.model) == "Instance" then
				CreatureAnim.SplitDeath(d.model, d.color, d.split, d.splitDir)
			else
				deathFall(d.model, d.color, d.boss)
			end
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
