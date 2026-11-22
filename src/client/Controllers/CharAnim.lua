-- CharAnim (client): the local player's combat animations + hit feel (hitstop, camera shake).
-- Clips are real Roblox animations (Config/AnimClips -> uploaded ids, see Shared/Modules/Anim) played on the character's
-- own Animator, so they blend with walk/idle, work with Motor6D and AnimationConstraint joints alike, and replicate:
-- every other player sees them without extra code. (v0.13/v0.14 posed joints by hand from a script; nothing moved.)
-- Per weapon (Config/AnimClips.Weapons): a combat stance while the weapon is out, a combo of basic attacks, and the
-- clip each skill kind uses.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Anim = require(ReplicatedStorage.Shared.Modules.Anim)
local ClassesCfg = require(ReplicatedStorage.Shared.Config.Classes)

local CharAnim = {}
local Clips = Anim.Clips
local player = Players.LocalPlayer

CharAnim.Stats = { posed = 0, kind = "none", lastClip = "-", lastFX = "-" }

local combo = { n = 0, last = 0 }
local action -- the attack track playing now (for hitstop)
local actionAt = 0
local stanceName

local function humanoid()
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid"), char
end

local function weaponOf(char, fallback)
	return (char and char:GetAttribute("Weapon")) or fallback or "Knuckles"
end

local function play(name, opts)
	local hum = humanoid()
	if not hum or not Clips[name] then
		return nil
	end
	local tr = Anim.Play(hum, name, opts)
	if tr then
		CharAnim.Stats.posed += 1
		CharAnim.Stats.lastClip = name
	end
	return tr
end

-- Dev tab "Test" buttons (and anything else that wants a one-off clip on the local character)
function CharAnim.Play(_, clipName)
	local tr = play(clipName)
	if tr then
		action, actionAt = tr, os.clock()
	end
	return tr
end

-- the combat stance loop follows the server's WeaponOut attribute (weapon in hand)
local movingWas -- last moving state the stance weight was set for
local function refreshStance()
	local hum, char = humanoid()
	if not hum then
		return
	end
	local w = Clips.Weapons[weaponOf(char)]
	local want = char:GetAttribute("WeaponOut") and w and w.stance or nil
	if stanceName and stanceName ~= want then
		Anim.Stop(hum, stanceName, 0.25)
		stanceName = nil
	end
	if want and stanceName ~= want then
		stanceName = want
		movingWas = nil
		play(want, { fade = 0.25 })
	end
end

local function onCharacter(char)
	stanceName = nil
	combo.n = 0
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then
		return
	end
	hum:WaitForChild("Animator", 10)
	local joints = 0
	local kind = "none"
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
			joints += 1
			kind = d.ClassName
		end
	end
	CharAnim.Stats.kind = kind .. " x" .. joints .. " (" .. tostring(hum.RigType.Name) .. ")"
	char:GetAttributeChangedSignal("WeaponOut"):Connect(refreshStance)
	char:GetAttributeChangedSignal("Weapon"):Connect(refreshStance)
	refreshStance()
end

-- ===== camera shake (local player) =====
local shake = 0
local function addShake(amount)
	shake = math.min(1.2, shake + amount)
end

-- hitstop: freeze my swing for a beat when it connects (at the strike frame)
local function hitstop(dur)
	local tr = action
	if not tr or not tr.IsPlaying then
		return
	end
	local strike = Anim.Strike(CharAnim.Stats.lastClip) / (CharAnim.Stats.speed or 1)
	local wait = math.max(0, strike - (os.clock() - actionAt))
	task.delay(wait, function()
		if tr.IsPlaying then
			local back = CharAnim.Stats.speed or 1
			tr:AdjustSpeed(0.02)
			task.delay(dur, function()
				tr:AdjustSpeed(back)
			end)
		end
	end)
end

function CharAnim.Start()
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)

	Net.OnFX(function(kind, d)
		if type(d) ~= "table" then
			return
		end
		CharAnim.Stats.lastFX = kind
		local mine = typeof(d.char) == "Instance" and d.char == player.Character
		if kind == "BasicAttack" and mine then
			local w = Clips.Weapons[weaponOf(d.char, d.weapon)] or Clips.Weapons[d.weapon or ""] or Clips.Weapons.Knuckles
			local list = w.combo
			-- the server says which hit of the combo this is (its damage lands on that clip's strike frame)
			combo.n = tonumber(d.combo) or ((os.clock() - combo.last < 1.2) and (combo.n % #list) + 1 or 1)
			combo.n = math.clamp(combo.n, 1, #list)
			combo.last = os.clock()
			-- played at the server's speed so the fist lands exactly when the damage does
			-- v0.25.17 (owner: faster strings should flow): crossfade out of the previous swing instead of letting it
			-- run on under the new one, with a fade that shortens as the swings speed up
			local spd = tonumber(d.speed) or 1
			local fade = math.clamp(0.1 / spd, 0.05, 0.12)
			local prev = action
			action, actionAt = play(list[combo.n], { speed = spd, fade = fade }), os.clock()
			if prev and prev ~= action and prev.IsPlaying then
				prev:Stop(fade)
			end
			CharAnim.Stats.speed = spd
			hitstop(0.05)
		elseif kind == "Skill" and mine and ClassesCfg.SkillById[d.skill or ""] then -- (FX-only "skills" like F_BalloonBounce play no clip)
			local sk = ClassesCfg.SkillById[d.skill or ""]
			local k = sk and sk.kind or ""
			local w = Clips.Weapons[weaponOf(d.char)] or {}
			local spd = tonumber(d.speed) or 1 -- v0.25.69: pumped Bounce moves play faster (server strike / speed)
			CharAnim.Stats.speed = spd
			local heavy = sk and sk.heavy and Clips.HeavyFor(weaponOf(d.char))
			action, actionAt = play((sk and sk.anim) or heavy or w[k] or Clips.SkillKinds[k] or "Skill_Cast", { speed = spd }), os.clock()
		elseif kind == "Damage" then
			if d.toPlayer and mine then
				play("Hurt", { fade = 0.03 })
				addShake(0.35)
			elseif d.src == player.UserId and d.kind ~= "burn" and d.kind ~= "poison" then
				-- damage now arrives on the strike frame: just the shake (the hitstop already ran on the swing)
				addShake(d.crit and 0.55 or 0.18)
			end
		end
	end)

	-- the combat stance softens while you run (arms swing a bit again) and comes back when you stop
	-- swimming (v0.24.14): front crawl while moving, treading water when still (Controllers/Swim keeps us afloat)
	local swimClip
	local sweepAt = 0
	RunService.Heartbeat:Connect(function()
		local hum, char = humanoid()
		local Swim = require(script.Parent.Swim)
		local want
		local Flight = require(script.Parent.Flight)
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local v = root and root.AssemblyLinearVelocity or Vector3.zero
		-- flight wins over swimming (skimming the sea used to leave the swim stroke playing in the air)
		if hum and hum.Health > 0 and Flight.IsFlying() then
			want = v.Magnitude > 6 and "Fly" or "FlyIdle"
		elseif hum and hum.Health > 0 and Swim.IsSwimming() then
			want = Vector3.new(v.X, 0, v.Z).Magnitude > 2 and "Swim" or "SwimIdle"
		end
		-- safety net (v0.25.27): neither flying nor swimming = no fly / swim clip may still be running
		if not want and hum and os.clock() > sweepAt then
			sweepAt = os.clock() + 0.5
			for _, n in ipairs({ "Fly", "FlyIdle", "Swim", "SwimIdle" }) do
				Anim.Stop(hum, n, 0.2)
			end
		end
		if want ~= swimClip then
			if hum then -- all of them: a quick Fly <-> FlyIdle flip could leave one running
				for _, n in ipairs({ "Fly", "FlyIdle", "Swim", "SwimIdle" }) do
					if n ~= want then
						Anim.Stop(hum, n, 0.3)
					end
				end
			end
			swimClip = want
			if want then
				play(want, { fade = 0.3 })
			end
		end
	end)
	RunService.Heartbeat:Connect(function()
		local hum = humanoid()
		if not hum or not stanceName then
			movingWas = nil
			return
		end
		local moving = hum.MoveDirection.Magnitude > 0.1
		if moving ~= movingWas then
			movingWas = moving
			local tr = Anim.Track(hum, stanceName)
			if tr and tr.IsPlaying then
				tr:AdjustWeight(moving and 0.45 or 1, 0.2)
			end
		end
	end)

	RunService:BindToRenderStep("GVShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if shake <= 0.001 then
			return
		end
		local cam = workspace.CurrentCamera
		local s = shake * shake * 0.6
		local t = os.clock() * 40
		cam.CFrame = cam.CFrame * CFrame.new(math.noise(t, 1) * s, math.noise(t, 2) * s, 0) * CFrame.Angles(0, 0, math.noise(t, 3) * s * 0.04)
		shake = math.max(0, shake - dt * 3.5)
	end)
end

return CharAnim
