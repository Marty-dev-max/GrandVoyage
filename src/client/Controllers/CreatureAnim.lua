-- CreatureAnim (client): hit flash and the voxel shatter on death for monsters.
-- The poses themselves (idle, walk, attack, hit) are real animations played by MonsterService on the server
-- (Shared/Modules/Anim, Config/AnimClips "Mon_*"), so every client sees them without work here.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Net)

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
		st = { ratio = ratio, chunk = chunk, scale = sc, token = 0 }
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
		st.scale.Scale = 1 + math.min(0.25, 0.08 + lost)
		TweenService:Create(st.scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
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
			shatter(d.model, d.color, d.boss)
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
