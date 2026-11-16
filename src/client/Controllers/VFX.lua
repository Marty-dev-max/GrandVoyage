-- VFX: cartoon effects (damage numbers, slashes, explosions, cannonballs, splashes...) built from Parts + Tweens
-- Put ParticleEmitter/Blender effects in ReplicatedStorage.Assets.VFX.<Name> to replace these automatically
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Audio = require(script.Parent.Audio)
local Settings = require(script.Parent.Settings)

local VFX = {}
local fxFolder = Instance.new("Folder")
fxFolder.Name = "ClientFX"
fxFolder.Parent = workspace

local function part(size, color, cf, shape, material, transparency)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.CFrame = cf
	p.Material = material or Enum.Material.Neon
	p.Transparency = transparency or 0
	if shape then
		p.Shape = shape
	end
	p.Parent = fxFolder
	return p
end

local function tween(inst, t, props, style)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function fadeOut(p, t, grow)
	local props = { Transparency = 1 }
	if grow then
		props.Size = p.Size * grow
	end
	tween(p, t, props)
	Debris:AddItem(p, t + 0.05)
end

local function custom(name, cf)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local fx = assets and assets:FindFirstChild("VFX") and assets.VFX:FindFirstChild(name)
	if fx then
		local c = fx:Clone()
		if c:IsA("Model") then
			c:PivotTo(cf)
		elseif c:IsA("BasePart") then
			c.CFrame = cf
		end
		c.Parent = fxFolder
		for _, e in ipairs(c:GetDescendants()) do
			if e:IsA("ParticleEmitter") then
				e:Emit(e:GetAttribute("EmitCount") or 20)
			end
		end
		Debris:AddItem(c, 4)
		return true
	end
	return false
end

-- ===== primitives =====
function VFX.Ring(pos, radius, color, t, height)
	local p = part(Vector3.new(height or 0.6, 2, 2), color, CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), Enum.PartType.Cylinder, Enum.Material.Neon, 0.2)
	tween(p, t or 0.4, { Size = Vector3.new(height or 0.6, radius * 2, radius * 2), Transparency = 1 })
	Debris:AddItem(p, (t or 0.4) + 0.05)
end

function VFX.Burst(pos, radius, color, t)
	local p = part(Vector3.new(1, 1, 1), color, CFrame.new(pos), Enum.PartType.Ball, Enum.Material.Neon, 0.1)
	tween(p, t or 0.35, { Size = Vector3.one * radius * 2, Transparency = 1 })
	Debris:AddItem(p, (t or 0.35) + 0.05)
end

function VFX.Sparks(pos, color, count, speed)
	for _ = 1, count or 8 do
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5).Unit
		local p = part(Vector3.new(0.5, 0.5, 0.5), color, CFrame.new(pos), Enum.PartType.Ball)
		tween(p, 0.5, { Position = pos + dir * (speed or 8), Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1 })
		Debris:AddItem(p, 0.55)
	end
end

function VFX.Projectile(from, to, color, size, t, arc, trailColor)
	local p = part(Vector3.one * (size or 1), color, CFrame.new(from), Enum.PartType.Ball)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, size and size * 0.4 or 0.4, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -(size and size * 0.4 or 0.4), 0)
	a1.Parent = p
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(trailColor or color)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = 0.25
	trail.LightEmission = 0.6
	trail.Parent = p
	t = t or 0.25
	local start = os.clock()
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		local k = math.min((os.clock() - start) / t, 1)
		local pos = from:Lerp(to, k) + Vector3.new(0, math.sin(k * math.pi) * (arc or 0), 0)
		p.CFrame = CFrame.new(pos)
		if k >= 1 then
			conn:Disconnect()
			p:Destroy()
		end
	end)
end

function VFX.Slash(cf, color, size)
	size = size or 8
	local p = part(Vector3.new(size, 0.3, size * 0.35), color, cf, nil, Enum.Material.Neon, 0.1)
	tween(p, 0.22, { CFrame = cf * CFrame.Angles(0, -1.6, 0), Transparency = 1, Size = Vector3.new(size * 1.3, 0.1, size * 0.45) })
	Debris:AddItem(p, 0.25)
end

-- Damage number. Crits get a Hunting-Together-style red starburst behind the number.
function VFX.Number(pos, text, color, big, burst)
	local holder = part(Vector3.new(0.2, 0.2, 0.2), color, CFrame.new(pos + Vector3.new(math.random() * 2 - 1, 0, math.random() * 2 - 1)), nil, nil, 1)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(big and 170 or 110, big and 90 or 44)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 220
	bb.Parent = holder
	if burst then
		local star = Instance.new("Frame")
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.fromScale(0.5, 0.5)
		star.Size = UDim2.fromScale(0.62, 0.7)
		star.BackgroundTransparency = 1
		star.Parent = bb
		for i = 0, 3 do
			local spike = Instance.new("Frame")
			spike.AnchorPoint = Vector2.new(0.5, 0.5)
			spike.Position = UDim2.fromScale(0.5, 0.5)
			spike.Size = UDim2.fromScale(1, 0.62)
			spike.Rotation = i * 22.5
			spike.BackgroundColor3 = burst
			spike.BorderSizePixel = 0
			spike.Parent = star
			local st = Instance.new("UIStroke")
			st.Thickness = 2
			st.Color = Color3.fromRGB(60, 10, 20)
			st.Parent = spike
		end
		local sc = Instance.new("UIScale")
		sc.Scale = 0.2
		sc.Parent = star
		tween(sc, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(star, 0.9, { Rotation = 30 })
	end
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color
	t.ZIndex = 3
	t.Parent = bb
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(30, 30, 45)
	stroke.Parent = t
	local sc = Instance.new("UIScale")
	sc.Scale = big and 1.6 or 1.2
	sc.Parent = t
	tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(holder, 0.9, { Position = holder.Position + Vector3.new(0, 5, 0) })
	task.delay(0.55, function()
		tween(t, 0.35, { TextTransparency = 1 })
		tween(stroke, 0.35, { Transparency = 1 })
		for _, f in ipairs(bb:GetDescendants()) do
			if f:IsA("Frame") then
				tween(f, 0.35, { BackgroundTransparency = 1 })
			elseif f:IsA("UIStroke") then
				tween(f, 0.35, { Transparency = 1 })
			end
		end
	end)
	Debris:AddItem(holder, 1)
end

function VFX.Beam(from, to, color, width, t)
	local dist = (to - from).Magnitude
	local p = part(Vector3.new(width or 1, width or 1, dist), color, CFrame.lookAt(from:Lerp(to, 0.5), to))
	tween(p, t or 0.3, { Size = Vector3.new(0.05, 0.05, dist), Transparency = 1 })
	Debris:AddItem(p, (t or 0.3) + 0.05)
end

function VFX.Aura(char, color, t)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	for i = 0, 2 do
		task.delay(i * 0.12, function()
			VFX.Ring(root.Position - Vector3.new(0, 2.5, 0) + Vector3.new(0, i * 1.5, 0), 4, color, 0.5, 0.4)
		end)
	end
	local p = part(Vector3.new(6, 7, 6), color, root.CFrame, Enum.PartType.Ball, Enum.Material.ForceField, 0.4)
	tween(p, t or 0.8, { Transparency = 1, Size = Vector3.new(8, 9, 8) })
	Debris:AddItem(p, (t or 0.8) + 0.05)
end

function VFX.Splash(pos, size)
	size = size or 10
	local base = Vector3.new(pos.X, 0.2, pos.Z)
	local col = part(Vector3.new(size * 0.5, 1, size * 0.5), Color3.fromRGB(230, 250, 255), CFrame.new(base), Enum.PartType.Cylinder, Enum.Material.SmoothPlastic, 0.1)
	col.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.pi / 2)
	col.Size = Vector3.new(1, size * 0.5, size * 0.5)
	tween(col, 0.35, { Size = Vector3.new(size * 1.6, size * 0.35, size * 0.35), CFrame = CFrame.new(base + Vector3.new(0, size * 0.8, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
	task.delay(0.35, function()
		fadeOut(col, 0.4)
	end)
	VFX.Ring(base, size, Color3.fromRGB(255, 255, 255), 0.6, 0.3)
	VFX.Sparks(base + Vector3.new(0, 1, 0), Color3.fromRGB(200, 240, 255), 10, size)
end

function VFX.Explosion(pos, radius)
	if custom("Explosion", CFrame.new(pos)) then
		return
	end
	VFX.Burst(pos, radius * 0.8, Color3.fromRGB(255, 200, 60), 0.3)
	task.delay(0.05, function()
		VFX.Burst(pos, radius, Color3.fromRGB(255, 110, 40), 0.4)
	end)
	VFX.Sparks(pos, Color3.fromRGB(255, 160, 40), 12, radius)
	local smoke = part(Vector3.one * radius, Color3.fromRGB(70, 70, 75), CFrame.new(pos + Vector3.new(0, 2, 0)), Enum.PartType.Ball, Enum.Material.SmoothPlastic, 0.3)
	tween(smoke, 1.2, { Size = Vector3.one * radius * 1.8, Transparency = 1, Position = pos + Vector3.new(0, 8, 0) })
	Debris:AddItem(smoke, 1.25)
end

-- ===== Skill FX table =====
local SkillFX = {}
SkillFX.Slash = function(d)
	VFX.Slash(CFrame.lookAt(d.from, d.to or d.from + Vector3.new(0, 0, -1)) * CFrame.new(0, 0, -3), Color3.fromRGB(255, 255, 255), 8)
end
SkillFX.CrossSlash = function(d)
	local cf = CFrame.lookAt(d.to, d.to + (d.to - d.from).Unit)
	VFX.Slash(cf * CFrame.Angles(0, 0, 0.8), Color3.fromRGB(120, 255, 150), 12)
	task.delay(0.12, function()
		VFX.Slash(cf * CFrame.Angles(0, 0, -0.8), Color3.fromRGB(120, 255, 150), 12)
	end)
	VFX.Sparks(d.to, Color3.fromRGB(180, 255, 180), 10)
end
SkillFX.Tornado = function(d)
	local r = d.radius or 12
	for i = 0, 4 do
		task.delay(i * 0.06, function()
			VFX.Ring(d.to + Vector3.new(0, -2 + i * 2, 0), r * (0.6 + i * 0.12), Color3.fromRGB(200, 255, 230), 0.4, 0.5)
		end)
	end
end
SkillFX.WaveSlash = function(d)
	local p = part(Vector3.new(9, 0.4, 2.5), Color3.fromRGB(150, 255, 180), CFrame.lookAt(d.from, d.to))
	tween(p, 0.25, { CFrame = CFrame.lookAt(d.to, d.to + (d.to - d.from).Unit), Size = Vector3.new(12, 0.3, 3) })
	task.delay(0.25, function()
		fadeOut(p, 0.15)
		VFX.Burst(d.to, 5, Color3.fromRGB(150, 255, 180), 0.3)
	end)
end
SkillFX.Bullet = function(d)
	VFX.Projectile(d.from, d.to, Color3.fromRGB(255, 230, 120), 0.8, 0.18, 1)
	task.delay(0.18, function()
		VFX.Burst(d.to, 2.5, Color3.fromRGB(255, 230, 120), 0.2)
	end)
end
SkillFX.Firebird = function(d)
	VFX.Projectile(d.from, d.to, Color3.fromRGB(255, 120, 40), 2.4, 0.35, 4, Color3.fromRGB(255, 220, 60))
	task.delay(0.35, function()
		VFX.Explosion(d.to, 7)
	end)
end
SkillFX.Smoke = function(d)
	for _ = 1, 8 do
		local p = part(Vector3.one * 5, Color3.fromRGB(200, 200, 205), CFrame.new(d.to + Vector3.new(math.random(-8, 8), 1, math.random(-8, 8))), Enum.PartType.Ball, Enum.Material.SmoothPlastic, 0.3)
		tween(p, 2, { Size = Vector3.one * 12, Transparency = 1 })
		Debris:AddItem(p, 2.05)
	end
end
SkillFX.Kick = function(d)
	VFX.Slash(CFrame.lookAt(d.from, d.to) * CFrame.new(0, -1, -3) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 170, 60), 9)
	VFX.Burst(d.to, 4, Color3.fromRGB(255, 200, 80), 0.25)
end
SkillFX.SpinKick = function(d)
	VFX.Ring(d.from - Vector3.new(0, 1.5, 0), d.radius or 12, Color3.fromRGB(255, 170, 60), 0.35, 1.2)
	VFX.Ring(d.from - Vector3.new(0, 0.5, 0), (d.radius or 12) * 0.7, Color3.fromRGB(255, 230, 120), 0.3, 0.8)
end
SkillFX.Food = function(d)
	VFX.Sparks(d.from + Vector3.new(0, 3, 0), Color3.fromRGB(255, 220, 120), 16, 10)
	VFX.Ring(d.from - Vector3.new(0, 2.5, 0), d.radius or 25, Color3.fromRGB(255, 200, 120), 0.7, 0.3)
end
SkillFX.Lightning = function(d)
	local top = d.to + Vector3.new(0, 60, 0)
	local prev = top
	for i = 1, 6 do
		local nextP = top:Lerp(d.to, i / 6) + (i < 6 and Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)) or Vector3.zero)
		VFX.Beam(prev, nextP, Color3.fromRGB(190, 220, 255), 1.4, 0.35)
		prev = nextP
	end
	VFX.Burst(d.to, d.radius or 10, Color3.fromRGB(170, 210, 255), 0.35)
	VFX.Ring(d.to, d.radius or 10, Color3.fromRGB(255, 255, 255), 0.4)
end
SkillFX.Heal = function(d)
	VFX.Ring(d.from - Vector3.new(0, 2.5, 0), d.radius or 25, Color3.fromRGB(120, 255, 150), 0.6, 0.3)
	VFX.Sparks(d.from, Color3.fromRGB(150, 255, 170), 14, 8)
end
SkillFX.Burst = function(d)
	VFX.Burst(d.from, d.radius or 10, Color3.fromRGB(255, 120, 200), 0.35)
end
SkillFX.Smash = function(d)
	VFX.Ring((d.to or d.from) - Vector3.new(0, 2, 0), 8, Color3.fromRGB(255, 220, 140), 0.35, 1)
	VFX.Sparks(d.to or d.from, Color3.fromRGB(255, 200, 120), 10, 7)
end
SkillFX.Explosion = function(d)
	VFX.Projectile(d.from + Vector3.new(0, 20, 0), d.to, Color3.fromRGB(40, 40, 45), 2.2, 0.25, 0)
	task.delay(0.25, function()
		VFX.Explosion(d.to, d.radius or 10)
	end)
end
SkillFX.Repair = function(d)
	VFX.Sparks(d.from, Color3.fromRGB(255, 230, 120), 18, 12)
end
SkillFX.Wind = function(d)
	for i = 0, 5 do
		task.delay(i * 0.08, function()
			VFX.Ring(d.from + Vector3.new(0, 2 + i, 0), (d.radius or 12) + i * 2, Color3.fromRGB(230, 255, 255), 0.6, 0.3)
		end)
	end
end
local auraColors = { AuraGreen = Color3.fromRGB(120, 255, 150), AuraYellow = Color3.fromRGB(255, 230, 80), AuraFire = Color3.fromRGB(255, 120, 40), AuraBlue = Color3.fromRGB(120, 180, 255), AuraPink = Color3.fromRGB(255, 140, 200) }
for name, color in pairs(auraColors) do
	SkillFX[name] = function(d)
		VFX.Aura(d.char, color)
	end
end

local weaponFX = {
	Sword = function(d)
		VFX.Slash(CFrame.lookAt(d.from, d.to) * CFrame.new(0, 0, -3), Color3.new(1, 1, 1), 6)
	end,
	Hammer = function(d)
		VFX.Burst(d.to, 3, Color3.fromRGB(255, 220, 140), 0.2)
	end,
	Knuckles = function(d)
		VFX.Burst(d.to, 2.4, Color3.fromRGB(255, 150, 120), 0.15)
		VFX.Sparks(d.to, Color3.fromRGB(255, 230, 200), 5, 8)
	end,
	Shoes = function(d)
		VFX.Slash(CFrame.lookAt(d.from, d.to) * CFrame.new(0, -1.5, -3) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 190, 90), 5)
	end,
	Slingshot = function(d)
		VFX.Projectile(d.from, d.to, Color3.fromRGB(255, 240, 160), 0.6, 0.18, 1)
	end,
	StormBaton = function(d)
		VFX.Projectile(d.from, d.to, Color3.fromRGB(140, 200, 255), 1, 0.22, 2)
	end,
	MedKit = function(d)
		VFX.Projectile(d.from, d.to, Color3.fromRGB(255, 160, 200), 0.6, 0.2, 1)
	end,
}

-- ===== event handler =====
local handlers = {}
local localPlayer = game:GetService("Players").LocalPlayer
handlers.Damage = function(d)
	local color = d.toPlayer and Color3.fromRGB(255, 90, 90) or (d.crit and Color3.new(1, 1, 1) or Color3.new(1, 1, 1))
	VFX.Number(d.pos, tostring(d.amount), color, d.crit, d.crit and Color3.fromRGB(235, 40, 60) or nil)
	if d.src == localPlayer.UserId then
		local UI = require(script.Parent.Parent.UI.UIKit)
		UI.ComboHit()
	end
end
handlers.Miss = function(d)
	VFX.Number(d.pos, d.text or "MISS", Color3.fromRGB(180, 190, 210))
end
handlers.Heal = function(d)
	VFX.Number(d.pos, "+" .. tostring(d.amount), Color3.fromRGB(110, 255, 140))
end
handlers.BasicAttack = function(d)
	local f = weaponFX[d.weapon] or weaponFX.Sword
	f(d)
end
handlers.Skill = function(d)
	local f = SkillFX[d.fx]
	if not custom(d.fx or "", CFrame.new(d.to or d.from)) and f then
		f(d)
	end
end
handlers.LevelUp = function(d)
	local p = part(Vector3.new(6, 1, 6), Color3.fromRGB(255, 220, 80), CFrame.new(d.pos - Vector3.new(0, 3, 0)), Enum.PartType.Cylinder, Enum.Material.Neon, 0.2)
	p.CFrame = CFrame.new(d.pos - Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	tween(p, 0.8, { Size = Vector3.new(40, 6, 6), CFrame = CFrame.new(d.pos + Vector3.new(0, 17, 0)) * CFrame.Angles(0, 0, math.pi / 2), Transparency = 1 })
	Debris:AddItem(p, 0.85)
	VFX.Ring(d.pos - Vector3.new(0, 2.5, 0), 12, Color3.fromRGB(255, 230, 120), 0.7, 0.5)
	VFX.Sparks(d.pos, Color3.fromRGB(255, 240, 150), 20, 14)
end
handlers.PetHit = function(d)
	VFX.Projectile(d.from, d.to, Color3.fromRGB(150, 255, 190), 0.6, 0.25, 2)
end
handlers.ChestOpen = function(d)
	local Rarity = require(game:GetService("ReplicatedStorage").Shared.Modules.Rarity)
	local c = Rarity.Get(d.rarity).color
	VFX.Sparks(d.pos + Vector3.new(0, 3, 0), c, 26, 16)
	VFX.Ring(d.pos, 8, c, 0.6, 0.4)
	VFX.Burst(d.pos + Vector3.new(0, 2, 0), 6, Color3.new(1, 1, 1), 0.4)
end
handlers.JobChange = function(d)
	for i = 0, 3 do
		task.delay(i * 0.15, function()
			VFX.Ring(d.pos - Vector3.new(0, 2.5, 0), 6 + i * 4, d.color or Color3.new(1, 1, 1), 0.6, 0.6)
		end)
	end
	VFX.Burst(d.pos, 10, d.color or Color3.new(1, 1, 1), 0.6)
end
handlers.RefineSuccess = function(d)
	VFX.Sparks(d.pos + Vector3.new(0, 2, 0), Color3.fromRGB(255, 230, 80), 24, 10)
	VFX.Burst(d.pos + Vector3.new(0, 2, 0), 5, Color3.fromRGB(255, 255, 200), 0.4)
end
handlers.RefineFail = function(d)
	VFX.Sparks(d.pos + Vector3.new(0, 2, 0), Color3.fromRGB(90, 90, 100), 14, 6)
end
handlers.UseItem = function(d)
	VFX.Sparks(d.pos, Color3.fromRGB(150, 255, 170), 8, 5)
end
handlers.MobAttack = function(d)
	if d.ranged then
		VFX.Projectile(d.from, d.to, Color3.fromRGB(255, 120, 120), 0.8, 0.28, 2)
	else
		VFX.Burst(d.to, 2.5, Color3.fromRGB(255, 160, 160), 0.18)
	end
end
handlers.MobDeath = function(d)
	VFX.Burst(d.pos, d.boss and 18 or 5, Color3.fromRGB(255, 255, 255), 0.35)
	VFX.Sparks(d.pos, d.color or Color3.new(1, 1, 1), d.boss and 30 or 10, d.boss and 20 or 8)
end
handlers.Telegraph = function(d)
	local p = part(Vector3.new(0.4, d.radius * 2, d.radius * 2), Color3.fromRGB(255, 60, 60), CFrame.new(d.pos - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), Enum.PartType.Cylinder, Enum.Material.Neon, 0.6)
	local inner = part(Vector3.new(0.5, 1, 1), Color3.fromRGB(255, 120, 60), p.CFrame, Enum.PartType.Cylinder, Enum.Material.Neon, 0.3)
	tween(inner, d.time, { Size = Vector3.new(0.5, d.radius * 2, d.radius * 2) }, Enum.EasingStyle.Linear)
	Debris:AddItem(p, d.time)
	Debris:AddItem(inner, d.time)
end
handlers.Slam = function(d)
	VFX.Ring(d.pos - Vector3.new(0, 2, 0), d.radius, Color3.fromRGB(255, 180, 100), 0.45, 2)
	VFX.Sparks(d.pos, Color3.fromRGB(200, 160, 120), 20, d.radius * 0.6)
end
handlers.Cannonball = function(d)
	VFX.Burst(d.from, 3, Color3.fromRGB(255, 200, 80), 0.15)
	local smoke = part(Vector3.one * 3, Color3.fromRGB(220, 220, 220), CFrame.new(d.from), Enum.PartType.Ball, Enum.Material.SmoothPlastic, 0.2)
	tween(smoke, 0.8, { Size = Vector3.one * 8, Transparency = 1 })
	Debris:AddItem(smoke, 0.85)
	local dist = (d.to - d.from).Magnitude
	VFX.Projectile(d.from, d.to, Color3.fromRGB(35, 35, 40), 1.6, d.t, math.clamp(dist * 0.12, 6, 40), Color3.fromRGB(150, 150, 150))
end
handlers.Splash = function(d)
	VFX.Splash(d.pos, 10)
end
handlers.Explosion = function(d)
	VFX.Explosion(d.pos + Vector3.new(0, 3, 0), d.radius or 12)
	VFX.Splash(d.pos, 8)
end
handlers.ShipHit = function(d)
	VFX.Number(d.pos + Vector3.new(0, 18, 0), "-" .. d.amount, Color3.fromRGB(255, 150, 60))
end
handlers.ShipSink = function(d)
	for i = 0, 4 do
		task.delay(i * 0.3, function()
			VFX.Explosion(d.pos + Vector3.new(math.random(-10, 10), 4, math.random(-10, 10)), 10)
		end)
	end
	VFX.Splash(d.pos, (d.radius or 20) * 1.2)
end
handlers.SeaKingRise = function(d)
	VFX.Splash(d.pos, 20)
end
handlers.Repair = function(d)
	VFX.Sparks(d.pos + Vector3.new(0, 6, 0), Color3.fromRGB(120, 255, 160), 24, d.radius or 15)
	VFX.Ring(d.pos + Vector3.new(0, 4, 0), d.radius or 15, Color3.fromRGB(120, 255, 160), 0.6, 0.4)
end

-- Sounds tied to effects (3D positioned)
local fxSounds = {
	Damage = function(d)
		return d.crit and "Crit" or "Hit", d.pos
	end,
	BasicAttack = function(d)
		local melee = d.weapon == "Sword" or d.weapon == "Hammer" or d.weapon == "Shoes"
		return melee and "Slash" or "Whoosh", d.from
	end,
	Skill = function(d)
		if d.fx == "Heal" or d.fx == "Food" then
			return "Heal", d.from
		end
		return "MagicCast", d.from
	end,
	LevelUp = function(d)
		return "LevelUp", d.pos
	end,
	MobDeath = function(d)
		return d.boss and "BossRoar" or "MonsterDie", d.pos
	end,
	Telegraph = function(d)
		return "BossRoar", d.pos
	end,
	Cannonball = function(d)
		return "Cannon", d.from
	end,
	Splash = function(d)
		return "Splash", d.pos
	end,
	Explosion = function(d)
		return "Explosion", d.pos
	end,
	ShipHit = function(d)
		return "ShipHit", d.pos
	end,
	ShipSink = function(d)
		return "Explosion", d.pos
	end,
	SeaKingRise = function(d)
		return "BossRoar", d.pos
	end,
	RefineSuccess = function(d)
		return "RefineSuccess", d.pos
	end,
}

function VFX.Start()
	Net.OnFX(function(kind, data)
		local h = handlers[kind]
		local snd = fxSounds[kind]
		if snd and type(data) == "table" then
			local ok, name, pos = pcall(snd, data)
			if ok and name then
				Audio.Play(name, { pos = pos })
			end
		end
		if kind == "Damage" and not Settings.Values.damageNumbers then
			return
		end
		if h and type(data) == "table" then
			local ok, err = pcall(h, data)
			if not ok then
				warn("[VFX]", kind, err)
			end
		end
	end)
end

VFX.Handlers = handlers
return VFX
