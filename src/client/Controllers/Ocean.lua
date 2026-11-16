-- Ocean (client): makes the flat sea parts look alive, Anime-Vanguards style.
--   * two scrolling wave-crest layers moving in different directions (reads as rolling water)
--   * drifting foam streaks
--   * sun glitter: sparse sparkles whose layer shimmers (transparency flicker) and drifts
--   * shore foam: pulsing foam rings around every island, plus a second ring that rolls in and fades
-- Everything is Texture/Decal overlays on the existing water parts (world.Ocean), animated on the client only.
-- Texture ids: Config/WaterTextures (tools/gen_materials.py -> upload_images.py). Low graphics = fewer layers.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Islands = require(ReplicatedStorage.Shared.Config.Islands)
local Tex = require(ReplicatedStorage.Shared.Config.WaterTextures)
local Settings = require(script.Parent.Settings)

local Ocean = {}

local layers = {} -- { tex, du, dv, flicker }
local rings = {} -- { part, decal, base, phase, roll }

local function texture(part, image, studs, transparency, color, z)
	local t = Instance.new("Texture")
	t.Face = Enum.NormalId.Top
	t.Texture = image
	t.StudsPerTileU = studs
	t.StudsPerTileV = studs
	t.Transparency = transparency
	t.Color3 = color or Color3.new(1, 1, 1)
	t.ZIndex = z or 1
	t.Parent = part
	return t
end

local function dress(part, low)
	local calm = part.Name == "CalmWater"
	-- crest lines: two layers crossing at different speeds/scales
	table.insert(layers, { tex = texture(part, Tex.waves, 70, calm and 0.55 or 0.3, Color3.fromRGB(220, 250, 255), 1), du = 3.2, dv = 1.4 })
	if not low then
		table.insert(layers, { tex = texture(part, Tex.waves, 46, calm and 0.7 or 0.45, Color3.fromRGB(200, 245, 255), 2), du = -1.8, dv = 2.6 })
		table.insert(layers, { tex = texture(part, Tex.foam, 120, calm and 0.75 or 0.35, Color3.new(1, 1, 1), 3), du = 4.5, dv = 0.6 })
	end
	-- sun glitter (warm white sparkles), shimmering
	table.insert(layers, { tex = texture(part, Tex.glitter, 38, 0.2, Color3.fromRGB(255, 250, 225), 4), du = 1.2, dv = -0.8, flicker = math.random() * 10 })
	if not low then
		table.insert(layers, { tex = texture(part, Tex.glitter, 23, 0.4, Color3.fromRGB(255, 255, 255), 5), du = -0.9, dv = 1.5, flicker = math.random() * 10 })
	end
end

local function shoreRing(center, radius, folder, roll)
	-- the ring texture sits at 86% of the decal's half size; put it just outside the beach
	local half = radius * 1.07 / 0.86
	local p = Instance.new("Part")
	p.Name = "ShoreFoam"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(half * 2, 0.2, half * 2)
	p.CFrame = CFrame.new(center.X, 0.12 + (roll and 0.02 or 0), center.Z)
	p.Parent = folder
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Top
	d.Texture = Tex.shorefoam
	d.Transparency = roll and 1 or 0.15
	d.Parent = p
	table.insert(rings, { part = p, decal = d, base = half * 2, center = center, phase = math.random() * 6, roll = roll })
end

function Ocean.Start()
	task.spawn(function()
		local world = workspace:WaitForChild("World", 60)
		local ocean = world and world:WaitForChild("Ocean", 60)
		if not ocean then
			return
		end
		local low = Settings.Values and Settings.Values.quality == "Low"
		for _, p in ipairs(ocean:GetDescendants()) do
			if p:IsA("BasePart") and (p.Name == "Water" or p.Name == "CalmWater") then
				dress(p, low)
			end
		end
		local folder = Instance.new("Folder")
		folder.Name = "OceanFX"
		folder.Parent = workspace
		for _, isl in ipairs(Islands.List) do
			if type(isl) == "table" and isl.x and isl.radius then
				local c = Vector3.new(isl.x, 0, isl.z or 0)
				shoreRing(c, isl.radius, folder, false)
				shoreRing(c, isl.radius, folder, true)
			end
		end

		local acc = 0
		RunService.RenderStepped:Connect(function(dt)
			acc += dt
			if acc < 1 / 30 then -- 30 Hz is plenty for texture scrolling
				return
			end
			local step = acc
			acc = 0
			local t = os.clock()
			for _, l in ipairs(layers) do
				local tex = l.tex
				tex.OffsetStudsU = (tex.OffsetStudsU + l.du * step) % tex.StudsPerTileU
				tex.OffsetStudsV = (tex.OffsetStudsV + l.dv * step) % tex.StudsPerTileV
				if l.flicker then
					-- shimmer: sparkles fade in and out like light catching the waves
					tex.Transparency = 0.15 + 0.55 * (0.5 + 0.5 * math.sin(t * 2.3 + l.flicker)) ^ 2
				end
			end
			for _, r in ipairs(rings) do
				if r.roll then
					-- an incoming wave: starts wide and faint, rolls onto the beach and fades out
					local k = ((t * 0.18 + r.phase) % 1)
					local s = r.base * (1.14 - 0.14 * k)
					r.part.Size = Vector3.new(s, 0.2, s)
					r.decal.Transparency = 0.35 + 0.65 * math.abs(k * 2 - 1) ^ 0.6
				else
					local s = r.base * (1 + 0.012 * math.sin(t * 0.9 + r.phase))
					r.part.Size = Vector3.new(s, 0.2, s)
					r.decal.Transparency = 0.15 + 0.15 * (0.5 + 0.5 * math.sin(t * 1.3 + r.phase))
				end
			end
		end)
	end)
end

return Ocean
