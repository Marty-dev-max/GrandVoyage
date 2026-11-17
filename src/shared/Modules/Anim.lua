-- Anim: plays the game's animation clips through Roblox's own Animator (works with both Motor6D and the newer
-- AnimationConstraint joints, blends with walk/idle, and replicates: the server plays monsters, each client plays
-- its own character). Clips live in Config/AnimClips; uploaded ids in Config/Animations (tools/build_anims.luau +
-- upload_models.py --type Animation). A clip without an id, or whose asset will not load (e.g. a group-owned place
-- that cannot use the owner's animations), is built at runtime and registered locally with KeyframeSequenceProvider.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Clips = require(ReplicatedStorage.Shared.Config.AnimClips)
local AnimBuild = require(ReplicatedStorage.Shared.Modules.AnimBuild)
local okIds, Ids = pcall(require, ReplicatedStorage.Shared.Config.Animations)
if not okIds then
	Ids = {}
end

local Anim = {}
Anim.Clips = Clips
Anim.Stats = { played = 0, loaded = 0, fallback = 0, failed = 0, last = "-" }

local animations = {} -- name -> Animation instance
local localIds = {} -- name -> registered temp id
local tracks = setmetatable({}, { __mode = "k" }) -- animator -> { name -> AnimationTrack }

local function registered(name)
	if localIds[name] == nil then
		local clip = Clips[name]
		local ok, id = pcall(function()
			local kfs = AnimBuild.Build(name, clip, { Instance = Instance, CFrame = CFrame, Enum = Enum })
			return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(kfs)
		end)
		localIds[name] = ok and id or false
		if ok then
			Anim.Stats.fallback += 1
		else
			warn("[Anim] could not build " .. name .. ": " .. tostring(id))
		end
	end
	return localIds[name] or nil
end

local function animation(name, forceLocal)
	if not forceLocal and animations[name] then
		return animations[name]
	end
	local id = (not forceLocal and Ids[name]) and ("rbxassetid://" .. Ids[name]) or registered(name)
	if not id then
		return nil
	end
	local a = Instance.new("Animation")
	a.Name = name
	a.AnimationId = id
	animations[name] = a
	return a
end

function Anim.Animator(humanoid)
	if not humanoid then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator and RunService:IsServer() then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	return animator
end

-- the track for `name` on this humanoid (loaded once and cached)
function Anim.Track(humanoid, name)
	local clip = Clips[name]
	local animator = Anim.Animator(humanoid)
	if not clip or not animator then
		return nil
	end
	local list = tracks[animator]
	if not list then
		list = {}
		tracks[animator] = list
	end
	local tr = list[name]
	if tr then
		return tr
	end
	local a = animation(name)
	if not a then
		return nil
	end
	local ok, res = pcall(animator.LoadAnimation, animator, a)
	if not ok then
		warn("[Anim] LoadAnimation " .. name .. " failed: " .. tostring(res))
		Anim.Stats.failed += 1
		return nil
	end
	tr = res
	tr.Priority = Enum.AnimationPriority[clip.priority or "Action"]
	tr.Looped = clip.loop == true
	list[name] = tr
	Anim.Stats.loaded += 1
	-- an uploaded asset that never loads (Length stays 0): fall back to the local build on clients
	if Ids[name] and RunService:IsClient() then
		task.delay(3, function()
			if tr.Length == 0 and list[name] == tr then
				Anim.Stats.failed += 1
				warn("[Anim] " .. name .. " (" .. Ids[name] .. ") did not load; using a local copy")
				local la = animation(name, true)
				if la then
					local ok2, t2 = pcall(animator.LoadAnimation, animator, la)
					if ok2 then
						t2.Priority = tr.Priority
						t2.Looped = tr.Looped
						list[name] = t2
						Ids[name] = nil
					end
				end
			end
		end)
	end
	return tr
end

-- play a clip; opts = { fade, speed, weight }
function Anim.Play(humanoid, name, opts)
	local tr = Anim.Track(humanoid, name)
	if not tr then
		return nil
	end
	opts = opts or {}
	tr:Play(opts.fade or 0.06, opts.weight or 1, opts.speed or 1)
	Anim.Stats.played += 1
	Anim.Stats.last = name
	return tr
end

function Anim.Stop(humanoid, name, fade)
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local list = animator and tracks[animator]
	local tr = list and list[name]
	if tr and tr.IsPlaying then
		tr:Stop(fade or 0.2)
	end
end

function Anim.Strike(name)
	local c = Clips[name]
	return c and c.strike or 0.12
end

return Anim
