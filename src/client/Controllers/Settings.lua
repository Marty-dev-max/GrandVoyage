-- Settings (client): graphics quality presets + audio volumes + UI scale, saved to the player's profile.
-- Low   : hides all Decor props, no shadows / post-processing, minimal wind & VFX  (phones)
-- Medium: hides tiny decor (flowers, grass), light post-processing
-- High  : everything on (default for PC)
-- Ultra : High + depth of field + denser wind streaks
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Audio = require(script.Parent.Audio)

local Settings = {}
Settings.Presets = { "Low", "Medium", "High", "Ultra" }
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

Settings.Values = {
	quality = isMobile and "Low" or "High",
	master = 1,
	music = 0.6,
	sfx = 0.9,
	ui = 0.8,
	ambience = 0.7,
	uiScale = 1,
	damageNumbers = true,
	rangeRings = true,
	navGuide = true,
}

-- Per-preset knobs other systems read (VFX density, wind streaks, etc.)
Settings.Knobs = {
	Low = { vfx = 0.35, wind = 0.25, maxNumbers = 6, shadows = false, post = false, decor = "none", foam = false, lights = false },
	Medium = { vfx = 0.7, wind = 0.6, maxNumbers = 12, shadows = true, post = true, decor = "large", foam = true, lights = false },
	High = { vfx = 1, wind = 1, maxNumbers = 24, shadows = true, post = true, decor = "all", foam = true, lights = true },
	Ultra = { vfx = 1.25, wind = 1.4, maxNumbers = 40, shadows = true, post = true, decor = "all", foam = true, lights = true, dof = true },
}

function Settings.Knob(name)
	local k = Settings.Knobs[Settings.Values.quality] or Settings.Knobs.High
	return k[name]
end

-- ===== decor visibility =====
local stash = {} -- part -> original parent
local function isSmall(p)
	return p.Size.Magnitude < 3.2
end
local function applyDecor(mode)
	local hideAll = mode == "none"
	for _, p in ipairs(CollectionService:GetTagged("Decor")) do
		local hide = hideAll or (mode == "large" and isSmall(p))
		if hide and p.Parent then
			stash[p] = p.Parent
			p.Parent = nil
		end
	end
	for p, parent in pairs(stash) do
		local hide = hideAll or (mode == "large" and isSmall(p))
		if not hide and parent.Parent then
			p.Parent = parent
			stash[p] = nil
		end
	end
end

local function setEnabled(name, on)
	local e = Lighting:FindFirstChild(name)
	if e then
		e.Enabled = on
	end
end

function Settings.Apply()
	local v = Settings.Values
	local k = Settings.Knobs[v.quality] or Settings.Knobs.High
	Lighting.GlobalShadows = k.shadows
	setEnabled("Bloom", k.post)
	-- anime look: lower threshold so additive VFX and neon glow (the baked map ships 1.6, too high for particles)
	local bloom = game:GetService("Lighting"):FindFirstChild("Bloom")
	if bloom then
		bloom.Threshold = 1.05
		bloom.Intensity = v.quality == "Ultra" and 0.85 or 0.7
		bloom.Size = 26
	end
	local cc = game:GetService("Lighting"):FindFirstChild("Stylize")
	if cc then
		cc.Saturation = 0.32
		cc.Contrast = 0.1
	end
	setEnabled("SunRays", k.post and v.quality ~= "Medium")
	setEnabled("Stylize", true)
	local dof = Lighting:FindFirstChild("UltraDOF")
	if k.dof and not dof then
		dof = Instance.new("DepthOfFieldEffect")
		dof.Name = "UltraDOF"
		dof.FarIntensity = 0.25
		dof.FocusDistance = 120
		dof.InFocusRadius = 140
		dof.NearIntensity = 0
		dof.Parent = Lighting
	elseif dof then
		dof.Enabled = k.dof == true
	end
	applyDecor(k.decor)
	for _, f in ipairs(CollectionService:GetTagged("Foam")) do
		f.Transparency = k.foam and 0.35 or 1
	end
	for _, l in ipairs(CollectionService:GetTagged("TownLight")) do
		l.Enabled = k.lights
	end
	Audio.SetVolume("Master", v.master)
	Audio.SetVolume("Music", v.music)
	Audio.SetVolume("SFX", v.sfx)
	Audio.SetVolume("UI", v.ui)
	Audio.SetVolume("Ambience", v.ambience)
	local UI = require(script.Parent.Parent.UI.UIKit)
	UI.UserScale = v.uiScale
	UI.Rescale()
end

function Settings.Set(key, value)
	Settings.Values[key] = value
	Settings.Apply()
	task.spawn(Net.Request, "SaveClientSettings", { settings = Settings.Values })
end

-- Called when the profile arrives from the server
function Settings.Load(saved)
	if type(saved) == "table" then
		for k, val in pairs(saved) do
			if Settings.Values[k] ~= nil and type(val) == type(Settings.Values[k]) then
				Settings.Values[k] = val
			end
		end
	end
	Settings.Apply()
end

function Settings.Start()
	Settings.Apply()
	-- props streamed/created later also respect the setting
	CollectionService:GetInstanceAddedSignal("Decor"):Connect(function(p)
		local mode = Settings.Knob("decor")
		if mode == "none" or (mode == "large" and isSmall(p)) then
			task.defer(function()
				if p.Parent then
					stash[p] = p.Parent
					p.Parent = nil
				end
			end)
		end
	end)
end

return Settings
