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
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UI = require(script.Parent.Parent.UI.UIKit)

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

-- v0.25.50 (owner: wanted to see WHERE from anywhere on the map + a sonar sound for about a minute): a tall pulsing
-- light pillar over a fresh fruit, a marker drawn on top of everything (any distance; v0.25.55 = black "?" fruit), a
-- looping directional sonar and a square ripple on the ground every 2 s. Runs BEACON seconds from the spawn.
-- v0.25.59: Fruit Notifier holders only (raised from the FruitSpawn push).
local BEACON = 60
-- v0.25.60 (owner: the beam's color told which fruit it was): pillar, ripples and the marker's aura cycle through a
-- pastel rainbow (prismatic) instead of the fruit's own color
local function prism(t)
	return Color3.fromHSV((t * 0.18) % 1, 0.45, 1)
end
local function beacon(m, body)
	local color = prism(os.clock())
	local born = m:GetAttribute("SpawnedAt")
	local left = born and BEACON - (workspace:GetServerTimeNow() - born) or 0
	if left <= 0 then
		return
	end
	local fx = workspace:FindFirstChild("ClientFX") or workspace
	local function block(size, cf, transparency)
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Size = size
		p.CFrame = cf
		p.Transparency = transparency
		p.Parent = fx
		return p
	end
	local base = body.Position
	local pillar = block(Vector3.new(3, 700, 3), CFrame.new(base + Vector3.new(0, 352, 0)), 0.45)
	local anchor = block(Vector3.new(0.2, 0.2, 0.2), CFrame.new(base + Vector3.new(0, 40, 0)), 1)
	local bb = Instance.new("BillboardGui")
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Size = UDim2.fromOffset(64, 64)
	bb.Parent = anchor
	-- v0.25.55 (owner reference): a black fruit silhouette with a white "?" (pixel icon fruit_unknown) in a white aura
	local aura = Instance.new("ImageLabel")
	aura.BackgroundTransparency = 1
	aura.Image = Tex.glow or ""
	aura.ImageColor3 = Color3.new(1, 1, 1)
	aura.ImageTransparency = 0.25
	aura.AnchorPoint = Vector2.new(0.5, 0.5)
	aura.Position = UDim2.fromScale(0.5, 0.5)
	aura.Size = UDim2.fromScale(1, 1)
	aura.Parent = bb
	local fruitIcon = Instance.new("ImageLabel")
	fruitIcon.BackgroundTransparency = 1
	fruitIcon.Image = Icons.fruit_unknown or ""
	fruitIcon.ResampleMode = Enum.ResamplerMode.Pixelated
	fruitIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	fruitIcon.Position = UDim2.fromScale(0.5, 0.5)
	fruitIcon.Size = UDim2.fromOffset(34, 34)
	fruitIcon.ZIndex = 2
	fruitIcon.Parent = bb
	local function ripple()
		-- a square ring of 4 neon bars growing outward on the ground and fading (voxel sonar wave)
		local bars = {}
		for i = 1, 4 do
			bars[i] = block(Vector3.new(1, 0.4, 1), CFrame.new(base), 0.2)
		end
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < 1.6 do
				local k = (os.clock() - t0) / 1.6
				local r = 4 + k * 60
				for i, b in ipairs(bars) do
					local a = (i - 1) * math.pi / 2
					b.Size = Vector3.new(r * 2, 0.4, 1)
					b.CFrame = CFrame.new(base + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, r)
					b.Transparency = 0.2 + 0.8 * k
				end
				task.wait()
			end
			for _, b in ipairs(bars) do
				b:Destroy()
			end
		end)
	end
	-- v0.25.59 (owner: the sonar sounded choppy, like a bad mp3, and came from everywhere): ONE looping sonar for the
	-- whole beacon (it used to restart a 12 s clip every 2 s = six copies on top of each other), fading in and out,
	-- played from a point 30 studs out in the fruit's direction so it pans around you as you turn, and louder when
	-- you face the fruit than when it is behind you
	local emitter = Instance.new("Attachment")
	emitter.Name = "FruitSonar"
	emitter.Parent = workspace.Terrain
	local sonar = Audio.Attach("FruitSonar", emitter, 600)
	if sonar then
		sonar.RollOffMinDistance = 60
		sonar.Volume = 0
		local eq = Instance.new("EqualizerSoundEffect")
		eq.HighGain, eq.MidGain, eq.LowGain = -9, 0, 2
		eq.Parent = sonar
	end
	local born0 = os.clock()
	local endAt = born0 + left
	local follow = RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local cp = cam.CFrame.Position
		local to = Vector3.new(base.X - cp.X, 0, base.Z - cp.Z)
		local dist = to.Magnitude
		local dir = dist > 1 and to.Unit or Vector3.new(0, 0, -1)
		emitter.WorldPosition = cp + dir * math.min(30, math.max(dist, 1))
		local look = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
		local facing = look.Magnitude > 0.01 and (look.Unit:Dot(dir) + 1) / 2 or 0.5 -- 1 = straight ahead, 0 = behind
		local near = math.clamp(1.2 - dist / 3500, 0.35, 1)
		local now = os.clock()
		color = prism(now)
		pillar.Color = color
		aura.ImageColor3 = color
		local env = math.clamp((now - born0) / 1.5, 0, 1) * math.clamp((endAt - now) / 2.5, 0, 1)
		if sonar then
			sonar.Volume = 0.9 * near * (0.3 + 0.7 * facing ^ 1.5) * env
		end
	end)
	task.spawn(function()
		local stop = endAt
		while os.clock() < stop and m.Parent and body.Parent do
			ripple()
			pillar.Transparency = 0.15
			TweenService:Create(pillar, TweenInfo.new(1.2), { Transparency = 0.6 }):Play()
			fruitIcon.Size = UDim2.fromOffset(44, 44)
			TweenService:Create(fruitIcon, TweenInfo.new(0.8), { Size = UDim2.fromOffset(34, 34) }):Play()
			aura.ImageTransparency = 0
			aura.Size = UDim2.fromScale(1.35, 1.35)
			TweenService:Create(aura, TweenInfo.new(1.4), { ImageTransparency = 0.35, Size = UDim2.fromScale(1, 1) }):Play()
			task.wait(2)
		end
		follow:Disconnect()
		emitter:Destroy()
		TweenService:Create(pillar, TweenInfo.new(1.5), { Transparency = 1 }):Play()
		task.wait(1.6)
		pillar:Destroy()
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

-- the whole screen twinkles when a fruit appears anywhere (v0.25.35, owner: people who never read the chat must
-- notice): gold edge glow blinks three times + a banner. Neutral gold so it never tells which fruit it is
local function screenBlink(knows, name)
	local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "FruitBlink"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 28
	gui.Parent = pg
	local edges = {}
	for _, e in ipairs({ { UDim2.fromScale(1, 0.2), UDim2.fromScale(0, 0), 90 }, { UDim2.fromScale(1, 0.2), UDim2.fromScale(0, 0.8), -90 }, { UDim2.fromScale(0.14, 1), UDim2.fromScale(0, 0), 0 }, { UDim2.fromScale(0.14, 1), UDim2.fromScale(0.86, 0), 180 } }) do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.fromRGB(255, 214, 110)
		f.BackgroundTransparency = 1
		f.Size, f.Position = e[1], e[2]
		local g = Instance.new("UIGradient")
		g.Rotation = e[3]
		g.Transparency = NumberSequence.new(0, 1)
		g.Parent = f
		f.Parent = gui
		table.insert(edges, f)
	end
	task.spawn(function()
		for i = 1, 3 do
			for _, f in ipairs(edges) do
				f.BackgroundTransparency = 0.25 + i * 0.1
				TweenService:Create(f, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
			end
			task.wait(0.55)
		end
		gui:Destroy()
	end)
	pcall(UI.Banner, "A Cursed Fruit appeared!", knows and ("On " .. tostring(name)) or "Somewhere in the sea...", Color3.fromRGB(255, 214, 110), "Legendary")
end

function FruitAlert.Start()
	for _, m in ipairs(CollectionService:GetTagged("CursedFruit")) do
		task.spawn(dress, m)
	end
	CollectionService:GetInstanceAddedSignal("CursedFruit"):Connect(function(m)
		task.spawn(dress, m)
	end)
	-- v0.25.59 (owner): the whole alert (twinkle, screen blink, banner, narrator, marker, pillar + sonar) is the Fruit
	-- Notifier's only; the server no longer tells anyone else
	Net.OnPush("FruitSpawn", function(d)
		if not d.knows then
			return
		end
		Audio.Play("FruitTwinkle")
		screenBlink(d.knows, d.name)
		if typeof(d.pos) == "Vector3" then
			task.spawn(function()
				-- the fruit model replicates around the push: wait for it, then raise its beacon
				for _ = 1, 30 do
					for _, fm in ipairs(CollectionService:GetTagged("CursedFruit")) do
						local b = fm:FindFirstChild("Body")
						if b and (b.Position - d.pos).Magnitude < 12 then
							beacon(fm, b)
							return
						end
					end
					task.wait(0.2)
				end
			end)
		end
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
