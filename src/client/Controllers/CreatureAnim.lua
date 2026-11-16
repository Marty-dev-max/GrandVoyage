-- CreatureAnim (client): procedural animation for the voxel monsters (no animation assets).
-- AssetService rigs every voxel part to the HumanoidRootPart with a Motor6D at its joint (Leg*, Arm*, Head, Tail,
-- Wing*, Body); here we pose those joints (on C0) every frame for monsters near the camera:
--   walk cycle (legs swing in pairs, arms counter-swing, body bounces), idle breathing, tail wag, head look-around,
--   attack (wind-up -> strike, lunge for beasts), hit flinch + white flash, and a voxel shatter on death.
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Net)

local CreatureAnim = {}

local RANGE = 160
local rigs = {} -- model -> state
CreatureAnim.Stats = { rigged = 0, plain = 0, animated = 0, attacks = 0, hits = 0 }

local function getRig(model)
	local st = rigs[model]
	if st ~= nil then
		return st or nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local motors = {}
	local count = 0
	if root then
		for _, m in ipairs(root:GetChildren()) do
			if m:IsA("Motor6D") then
				motors[m.Name] = { motor = m, base = m.C0 }
				count += 1
			elseif m:IsA("AnimationConstraint") and m.Attachment0 then
				motors[m.Name] = { motor = m, att = m.Attachment0, base = m.Attachment0.CFrame }
				count += 1
			end
		end
	end
	if count == 0 then
		-- placeholder body (nothing to animate), or its joints have not replicated yet: look again in a moment
		if root then
			rigs[model] = false
			CreatureAnim.Stats.plain += 1
			task.delay(2, function()
				if rigs[model] == false then
					rigs[model] = nil
					CreatureAnim.Stats.plain -= 1
				end
			end)
		end
		return nil
	end
	CreatureAnim.Stats.rigged += 1
	local h = model:GetAttribute("Height") or 6
	local quad = motors.LegFL ~= nil
	st = { root = root, motors = motors, h = h, quad = quad, phase = math.random() * 6, walk = 0, attackAt = -10, hitAt = -10, seed = math.random() * 10 }
	rigs[model] = st
	model.Destroying:Connect(function()
		rigs[model] = nil
		CreatureAnim.Stats.rigged -= 1
	end)
	return st
end

-- poses go on C0 (base * pose): the Humanoid's Animator rewrites Motor6D.Transform every frame, C0 it leaves alone
local function setT(st, name, cf)
	local j = st.motors[name]
	if j then
		if j.att then
			j.att.CFrame = j.base * cf
		else
			j.motor.C0 = j.base * cf
		end
	end
end

local function animate(st, dt, t)
	local root = st.root
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	st.walk += (math.clamp(speed / 7, 0, 1) - st.walk) * math.min(1, dt * 8)
	st.phase += dt * (3 + speed * 0.55)
	local w, ph, h = st.walk, st.phase, st.h
	local swing = math.sin(ph) * 0.75 * w
	local bob = math.abs(math.sin(ph)) * 0.06 * h * w + math.sin(t * 2.2 + st.seed) * 0.012 * h
	local lift = CFrame.new(0, bob, 0)

	-- attack: 0-0.12 s wind-up, 0.12-0.22 strike, then recover
	local a = t - st.attackAt
	local atk, lunge = 0, 0
	if a < 0.5 then
		if a < 0.12 then
			atk = a / 0.12 * 2.3
		elseif a < 0.22 then
			atk = 2.3 - (a - 0.12) / 0.1 * 2.6
		else
			atk = -0.3 * (1 - (a - 0.22) / 0.28)
		end
		lunge = math.sin(math.clamp(a / 0.3, 0, 1) * math.pi)
	end
	-- hit flinch: lean back briefly
	local hk = t - st.hitAt
	local flinch = hk < 0.18 and math.sin(hk / 0.18 * math.pi) * 0.22 or 0

	local body = lift * CFrame.new(0, 0, -lunge * 0.06 * h) * CFrame.Angles(-lunge * 0.12 + flinch * -1, 0, math.sin(ph) * 0.03 * w)
	setT(st, "Body", body)
	-- head looks around a little when idle, lunges on attack
	local look = (1 - w) * math.sin(t * 0.6 + st.seed) * 0.25
	setT(st, "Head", body * CFrame.Angles(-lunge * 0.35 + math.sin(t * 1.3 + st.seed) * 0.04, look, 0))
	setT(st, "Tail", lift * CFrame.Angles(0, math.sin(t * 3 + st.seed) * 0.35 + math.sin(ph) * 0.2 * w, 0))
	setT(st, "WingL", lift * CFrame.Angles(0, 0, math.sin(t * 11) * 0.5))
	setT(st, "WingR", lift * CFrame.Angles(0, 0, -math.sin(t * 11) * 0.5))
	if st.quad then
		setT(st, "LegFL", CFrame.Angles(swing, 0, 0))
		setT(st, "LegBR", CFrame.Angles(swing, 0, 0))
		setT(st, "LegFR", CFrame.Angles(-swing, 0, 0))
		setT(st, "LegBL", CFrame.Angles(-swing, 0, 0))
	else
		-- bipeds (crabs use the same pair of side-leg parts: they scuttle)
		setT(st, "LegL", CFrame.Angles(swing, 0, 0))
		setT(st, "LegR", CFrame.Angles(-swing, 0, 0))
		setT(st, "ArmL", body * CFrame.Angles(-swing * 0.6 + math.sin(t * 2.2 + st.seed) * 0.03, 0, 0))
		setT(st, "ArmR", body * CFrame.Angles(swing * 0.6 + atk, 0, 0))
	end
end

-- white flash on hit (a short-lived Highlight, so we never keep dozens alive)
local function flash(model)
	local hl = Instance.new("Highlight")
	hl.FillColor = Color3.new(1, 1, 1)
	hl.OutlineTransparency = 1
	hl.FillTransparency = 0.2
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Adornee = model
	hl.Parent = model
	TweenService:Create(hl, TweenInfo.new(0.16), { FillTransparency = 1 }):Play()
	Debris:AddItem(hl, 0.2)
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

function CreatureAnim.Start()
	Net.OnFX(function(kind, d)
		if type(d) ~= "table" or typeof(d.model) ~= "Instance" then
			return
		end
		local st = getRig(d.model)
		if kind == "MobAttack" then
			if st then
				st.attackAt = os.clock()
				CreatureAnim.Stats.attacks += 1
			end
		elseif kind == "Damage" then
			if st then
				st.hitAt = os.clock()
				CreatureAnim.Stats.hits += 1
				-- hitstop: the monster freezes for a beat when struck (longer on crits)
				st.freezeUntil = os.clock() + (d.crit and 0.09 or 0.05)
			end
			flash(d.model)
		elseif kind == "MobDeath" then
			shatter(d.model, d.color, d.boss)
		end
	end)

	local folder = workspace:WaitForChild("Monsters", 60)
	RunService.Stepped:Connect(function(_, dt)
		if not folder then
			return
		end
		local cam = workspace.CurrentCamera
		local focus = cam and cam.Focus.Position or Vector3.zero
		local t = os.clock()
		local n = 0
		for _, model in ipairs(folder:GetChildren()) do
			local root = model:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - focus).Magnitude < RANGE then
				local st = getRig(model)
				if st and not (st.freezeUntil and t < st.freezeUntil) then
					animate(st, dt, t)
					n += 1
				end
			end
		end
		CreatureAnim.Stats.animated = n
	end)
end

return CreatureAnim
