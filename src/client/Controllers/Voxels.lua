-- Voxels (client, v0.24.0, owner): the voxel / pixel layer every effect is built from.
--  * Voxels.Blocks(pos, opts): real little cubes that fly, tumble, bounce on the ground and shrink away
--    (death debris, hits on wood/stone, level-up cubes, loot pops).
--  * Voxels.Pixels(pos, opts): a burst of flat square pixels (ParticleEmitter with the px_square / px_cube textures)
--    for dust, sparks and magic. Both take a list of colors so each effect can look like what it is made of.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tex = require(ReplicatedStorage.Shared.Config.Textures)
local Settings = require(script.Parent.Settings)

local Voxels = {}
local folder = Instance.new("Folder")
folder.Name = "VoxelFX"
folder.Parent = workspace

local live = 0
local MAX_LIVE = 260

local function quality()
	local q = Settings.Values and Settings.Values.quality
	return (q == "Low" and 0.35) or (q == "Medium" and 0.7) or (q == "Ultra" and 1.3) or 1
end

local function pick(colors, i)
	if typeof(colors) == "Color3" then
		return colors
	end
	if type(colors) ~= "table" or #colors == 0 then
		return Color3.new(1, 1, 1)
	end
	return colors[((i - 1) % #colors) + 1]
end

-- opts: count, colors, size (number or {min,max}), speed, up, spread (start radius), life, collide (true = bounce),
-- material, neon (glow), gravity (true), dir (Vector3 bias), spin
function Voxels.Blocks(pos, opts)
	opts = opts or {}
	local n = math.floor((opts.count or 10) * quality() + 0.5)
	n = math.min(n, MAX_LIVE - live)
	if n <= 0 then
		return
	end
	local smin, smax = 0.3, 0.6
	if type(opts.size) == "table" then
		smin, smax = opts.size[1], opts.size[2]
	elseif type(opts.size) == "number" then
		smin, smax = opts.size * 0.75, opts.size * 1.25
	end
	local life = opts.life or 0.9
	for i = 1, n do
		local s = smin + math.random() * (smax - smin)
		local c = Instance.new("Part")
		c.Name = "Vox"
		c.Size = Vector3.new(s, s, s)
		local col = pick(opts.colors, i)
		local v = math.random()
		c.Color = v < 0.25 and col:Lerp(Color3.new(1, 1, 1), 0.18) or (v > 0.8 and col:Lerp(Color3.new(0, 0, 0), 0.2) or col)
		c.Material = opts.neon and Enum.Material.Neon or (opts.material or Enum.Material.SmoothPlastic)
		c.TopSurface = Enum.SurfaceType.Smooth
		c.BottomSurface = Enum.SurfaceType.Smooth
		c.CastShadow = false
		c.CanQuery = false
		c.CanTouch = false
		c.Massless = true
		c.CanCollide = opts.collide ~= false
		local spread = opts.spread or 0.6
		local offset = Vector3.new((math.random() - 0.5) * 2, (math.random() - 0.5) * 2, (math.random() - 0.5) * 2) * spread
		c.CFrame = CFrame.new(pos + offset) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		if opts.anchored then
			c.Anchored = true
		end
		c.Parent = folder
		live += 1
		if not opts.anchored then
			local out = offset.Magnitude > 0.01 and offset.Unit or Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
			local speed = (opts.speed or 12) * (0.6 + math.random() * 0.7)
			local vel = out * speed + Vector3.new(0, (opts.up or 10) * (0.7 + math.random() * 0.6), 0)
			if opts.dir then
				vel += opts.dir * (0.5 + math.random())
			end
			c.AssemblyLinearVelocity = vel
			local spin = opts.spin or 14
			c.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * spin
		end
		local t = life * (0.75 + math.random() * 0.5)
		task.delay(t, function()
			if c.Parent then
				TweenService:Create(c, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = c.Size * 0.15, Transparency = 0.4 }):Play()
			end
		end)
		task.delay(t + 0.38, function()
			live -= 1
			c:Destroy()
		end)
	end
end

-- opts: count, colors, size (pixel size in studs), speed, up, life, spread, drag, gravity (studs/s^2 down),
-- glow (LightEmission 0..1), texture ("px_square" | "px_cube" | "px_sparkle" ...)
function Voxels.Pixels(pos, opts)
	opts = opts or {}
	local n = math.floor((opts.count or 24) * quality() + 0.5)
	if n <= 0 then
		return
	end
	local a = Instance.new("Part")
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.CanTouch = false
	a.Transparency = 1
	a.Size = Vector3.one * (opts.spread or 1)
	a.CFrame = CFrame.new(pos)
	a.Parent = folder
	local colors = opts.colors
	if typeof(colors) == "Color3" then
		colors = { colors }
	end
	colors = colors or { Color3.new(1, 1, 1) }
	local per = math.max(1, math.floor(n / #colors))
	for _, col in ipairs(colors) do
		local e = Instance.new("ParticleEmitter")
		e.Texture = Tex[opts.texture or "px_square"] or Tex.px_square or ""
		e.Color = ColorSequence.new(col)
		local s = opts.size or 0.35
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s), NumberSequenceKeypoint.new(0.7, s), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1) })
		local life = opts.life or 0.7
		e.Lifetime = NumberRange.new(life * 0.6, life * 1.2)
		local sp = opts.speed or 12
		e.Speed = NumberRange.new(sp * 0.4, sp)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, -(opts.gravity or 20), 0) + Vector3.new(0, opts.up or 0, 0)
		e.Drag = opts.drag or 2.5
		e.RotSpeed = NumberRange.new(0, 0)
		e.Rotation = NumberRange.new(0, 0)
		e.LightEmission = opts.glow or 0
		e.LightInfluence = (opts.glow or 0) > 0.5 and 0 or 1
		e.Orientation = Enum.ParticleOrientation.FacingCamera
		e.Shape = Enum.ParticleEmitterShape.Box
		e.Rate = 0
		e.Enabled = false
		e.Parent = a
		e:Emit(per)
	end
	Debris:AddItem(a, (opts.life or 0.7) * 1.4 + 0.2)
end

return Voxels
