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

function FruitAlert.Start()
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
