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
		if kind == "MobAttack" then
			CreatureAnim.Stats.attacks += 1
		elseif kind == "Damage" then
			CreatureAnim.Stats.hits += 1
			task.delay(0.12, flash, d.model) -- on the attacker's strike frame
		elseif kind == "MobDeath" then
			shatter(d.model, d.color, d.boss)
		end
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
