-- FruitAlert (v0.25.33, owner): Fruit Notifier holders hear a fruit twinkle + a narrator saying WHERE a Cursed Fruit
-- appeared (never which fruit) and get an on-screen marker over the spot until it is picked up or rots.
-- Narrator = uploaded Narr_Fruit<IslandId> sound when it has an id, else Roblox text-to-speech (AudioTextToSpeech)
-- shortcut: TTS is a fallback while the audio upload quota is spent; drop it once the Narr_ ids are uploaded.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Audio = require(script.Parent.Audio)
local Tex = require(ReplicatedStorage.Shared.Config.Textures)
local TweenService = game:GetService("TweenService")

local FruitAlert = {}

local function speak(text)
	local ok, err = pcall(function()
		local tts = Instance.new("AudioTextToSpeech")
		tts.Text = text
		tts.VoiceId = "1"
		tts.Volume = 1.6
		local out = Instance.new("AudioDeviceOutput")
		local wire = Instance.new("Wire")
		wire.SourceInstance = tts
		wire.TargetInstance = out
		tts.Parent = workspace.CurrentCamera
		out.Parent = tts
		wire.Parent = tts
		tts:Play()
		task.delay(10, function()
			tts:Destroy()
		end)
	end)
	if not ok then
		warn("[FruitAlert] text-to-speech unavailable: " .. tostring(err))
	end
end

local marker
local function mark(pos, life)
	if marker then
		marker:Destroy()
	end
	local anchor = Instance.new("Part")
	anchor.Name = "FruitMarker"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = pos + Vector3.new(0, 4, 0)
	local bb = Instance.new("BillboardGui")
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Size = UDim2.fromOffset(150, 46)
	bb.Parent = anchor
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.FontFace = Font.fromEnum(Enum.Font.Arcade)
	t.TextSize = 16
	t.TextColor3 = Color3.fromRGB(255, 220, 120)
	t.TextStrokeTransparency = 0.2
	t.Parent = bb
	anchor.Parent = workspace
	marker = anchor
	local t0 = os.clock()
	task.spawn(function()
		while anchor.Parent and os.clock() - t0 < (life or 600) do
			local char = Players.LocalPlayer.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local d = root and math.floor((root.Position - pos).Magnitude) or 0
			t.Text = "? FRUIT ?\n" .. d .. "m"
			task.wait(0.5)
		end
		anchor:Destroy()
	end)
end

-- every player near a spawned Cursed Fruit (v0.25.34, owner): it twinkles (looping hum), flashes when it appears
-- and keeps blinking: a double flash of its light + glow + a burst of sparkles every couple of seconds
local function dress(m)
	local body = m:WaitForChild("Body", 5)
	if not body or not m.Parent then
		return
	end
	local light = body:FindFirstChildOfClass("PointLight")
	local color = light and light.Color or Color3.fromRGB(255, 220, 120)
	Audio.Attach("FruitHum", body, 90)
	Audio.Play("FruitTwinkle", { pos = body.Position })
	local hl = Instance.new("Highlight")
	hl.FillColor = color
	hl.OutlineColor = Color3.new(1, 1, 1)
	hl.FillTransparency = 1
	hl.OutlineTransparency = 1
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = m
	local e = Instance.new("ParticleEmitter")
	e.Texture = Tex.px_sparkle or Tex.px_square or ""
	e.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.4, 0.8)
	e.Speed = NumberRange.new(4, 8)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.Parent = body
	local function flash(strength)
		hl.FillTransparency = 1 - 0.55 * strength
		hl.OutlineTransparency = 1 - 0.8 * strength
		TweenService:Create(hl, TweenInfo.new(0.35), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
		if light then
			light.Brightness = 3 + 6 * strength
			TweenService:Create(light, TweenInfo.new(0.35), { Brightness = 3 }):Play()
		end
	end
	-- the moment it appears: a big flash and burst
	flash(1)
	e:Emit(30)
	task.spawn(function()
		while m.Parent and body.Parent do
			task.wait(1.8 + math.random() * 0.6)
			flash(0.8)
			e:Emit(8)
			task.wait(0.22)
			flash(0.5)
		end
	end)
end

function FruitAlert.Start()
	for _, m in ipairs(CollectionService:GetTagged("CursedFruit")) do
		task.spawn(dress, m)
	end
	CollectionService:GetInstanceAddedSignal("CursedFruit"):Connect(function(m)
		task.spawn(dress, m)
	end)
	Net.OnPush("FruitSpawn", function(d)
		Audio.Play("FruitTwinkle")
		local key = "Narr_Fruit" .. tostring(d.island)
		task.delay(0.8, function()
			local def = Sounds[key]
			if def and def.id and def.id ~= "" then
				Audio.Play(key)
			else
				speak("A Cursed Fruit has appeared on " .. tostring(d.name) .. ".")
			end
		end)
		if typeof(d.pos) == "Vector3" then
			mark(d.pos, d.life)
		end
	end)
	-- picked up (or rotted): the marker goes with it
	CollectionService:GetInstanceRemovedSignal("CursedFruit"):Connect(function()
		if marker then
			marker:Destroy()
			marker = nil
		end
	end)
end

return FruitAlert
