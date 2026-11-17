-- Audio: plays UI / SFX / music with per-group volume (Settings) and 3D positional sounds.
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local Audio = {}
local groups = {}
for _, name in ipairs({ "UI", "SFX", "Music", "Ambience" }) do
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Volume = 1
	g.Parent = SoundService
	groups[name] = g
end
local holder = Instance.new("Folder")
holder.Name = "ClientSounds"
holder.Parent = SoundService
local anchor = Instance.new("Part")
anchor.Anchored = true
anchor.CanCollide = false
anchor.CanQuery = false
anchor.Transparency = 1
anchor.Size = Vector3.one
anchor.Name = "SoundAnchor"
anchor.Parent = workspace
local master = 1
local lastPlayed = {}

local function source(def)
	if def.id and def.id ~= "" then
		return def.id
	end
	-- `alias` = reuse another sound's uploaded file (played with this one's pitch/volume)
	local other = def.alias and Sounds[def.alias]
	if other and other.id and other.id ~= "" then
		return other.id
	end
	return def.fallback
end

function Audio.SetVolume(group, v)
	if group == "Master" then
		master = v
		for _, g in pairs(groups) do
			g.Volume = (g:GetAttribute("Base") or 1) * master
		end
		return
	end
	local g = groups[group]
	if g then
		g:SetAttribute("Base", v)
		g.Volume = v * master
	end
end

-- opts: { pos = Vector3, pitch = n, volume = n }
function Audio.Play(name, opts)
	local def = Sounds[name]
	if not def then
		return
	end
	local id = source(def)
	if not id or id == "" then
		return
	end
	local now = os.clock()
	if lastPlayed[name] and now - lastPlayed[name] < 0.03 then
		return -- avoid stacking the same sound in one frame
	end
	lastPlayed[name] = now
	opts = opts or {}
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = (opts.volume or 1) * def.volume
	s.PlaybackSpeed = (opts.pitch or 1) * (def.pitch or 1) * (1 + (math.random() - 0.5) * 0.06)
	s.SoundGroup = groups[def.group]
	if opts.pos then
		local att = Instance.new("Attachment")
		att.WorldPosition = opts.pos
		att.Parent = anchor
		s.RollOffMaxDistance = def.rolloff or 260
		s.RollOffMinDistance = 12
		s.Parent = att
		Debris:AddItem(att, 6)
	else
		s.Parent = holder
		Debris:AddItem(s, 6)
	end
	s:Play()
	return s
end

-- Looping music/ambience with crossfade
local loops = {}
function Audio.Loop(channel, name, fade)
	local cur = loops[channel]
	if cur and cur.name == name then
		return
	end
	fade = fade or 1.5
	if cur then
		local old = cur.sound
		TweenService:Create(old, TweenInfo.new(fade), { Volume = 0 }):Play()
		Debris:AddItem(old, fade + 0.1)
	end
	loops[channel] = nil
	local def = name and Sounds[name]
	local id = def and source(def)
	if not def or not id or id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s.SoundGroup = groups[def.group]
	s.Parent = holder
	s:Play()
	TweenService:Create(s, TweenInfo.new(fade), { Volume = def.volume }):Play()
	loops[channel] = { name = name, sound = s }
end

return Audio
