-- Underwater (client, owner v0.22.4): when the camera dips under the sea surface the world turns into the sea:
-- blue-green tint and short visibility (Atmos.SetUnderwater), a soft blur, bubbles and drifting specks around the
-- camera, a plunge sound going in and a splash coming out, every world sound muffled (Audio.SetUnderwater) under a
-- deep underwater ambience loop. Diving itself lives in Controllers/Swim.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Tex = require(ReplicatedStorage.Shared.Config.Textures)
local Audio = require(script.Parent.Audio)
local Atmos = require(script.Parent.Atmos)

local Underwater = {}
local k = 0 -- 0 dry .. 1 submerged (eased)
local under = false

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	for key, v in pairs(props) do
		e[key] = v
	end
	e.Parent = parent
	return e
end

function Underwater.IsUnder()
	return under
end

function Underwater.Start()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "GVUnderwater"
	cc.Enabled = false
	cc.Parent = Lighting
	local blur = Instance.new("BlurEffect")
	blur.Name = "GVUnderwaterBlur"
	blur.Size = 0
	blur.Enabled = false
	blur.Parent = Lighting

	-- an invisible box that follows the camera and fills the view with bubbles and specks
	local box = Instance.new("Part")
	box.Name = "GVUnderwaterFX"
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.Transparency = 1
	box.Size = Vector3.new(24, 14, 24)
	box.Parent = workspace
	local bubbles = emitter(box, {
		Texture = Tex.bubble, Enabled = false, Rate = 18, Lifetime = NumberRange.new(2.5, 4.5),
		Speed = NumberRange.new(2, 4.5), SpreadAngle = Vector2.new(12, 12), EmissionDirection = Enum.NormalId.Top,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.35) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(0.85, 0.45), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(220, 245, 255)), LightEmission = 0.4, Acceleration = Vector3.new(0, 1.5, 0),
		RotSpeed = NumberRange.new(-30, 30), Shape = Enum.ParticleEmitterShape.Box, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
	})
	local specks = emitter(box, {
		Texture = Tex.glow, Enabled = false, Rate = 26, Lifetime = NumberRange.new(4, 7),
		Speed = NumberRange.new(0.1, 0.5), SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(0.08), LightEmission = 0.2, Color = ColorSequence.new(Color3.fromRGB(200, 235, 220)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(0.7, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		Shape = Enum.ParticleEmitterShape.Box, Drag = 1,
	})

	RunService.RenderStepped:Connect(function(dt)
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local pos = cam.CFrame.Position
		-- below the surface (and not up in a sky dungeon / below the world)
		local now = pos.Y < GameConfig.SeaLevel - 0.25 and pos.Y > -300
		if now ~= under then
			under = now
			if now then
				Audio.Play("WaterPlunge", { volume = 0.9 })
				Audio.Loop("underwater", "AmbienceUnderwater", 0.4)
			else
				Audio.Play("WaterSurface")
				Audio.Loop("underwater", nil, 0.6)
			end
		end
		local target = under and 1 or 0
		-- snap in fast (you are wet at once), ease out a little slower
		k += (target - k) * math.min(1, dt * (under and 10 or 5))
		if math.abs(k - target) < 0.002 then
			k = target
		end
		local on = k > 0.01
		cc.Enabled = on
		blur.Enabled = on
		if on then
			cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(110, 200, 245), k)
			cc.Brightness = -0.06 * k
			cc.Contrast = 0.1 * k
			cc.Saturation = -0.18 * k
			blur.Size = 6 * k
			box.CFrame = cam.CFrame * CFrame.new(0, -2, -10)
		end
		bubbles.Enabled = k > 0.5
		specks.Enabled = k > 0.5
		Atmos.SetUnderwater(k)
		Audio.SetUnderwater(k)
	end)
end

return Underwater
