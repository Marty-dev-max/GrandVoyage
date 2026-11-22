-- Combat (client): two modes (owner, v0.22.3)
--  * Manual (Auto Battle off): you steer yourself; click / tap (hold to keep swinging) attacks the monster under the
--    pointer, or the closest one in front of you within weapon reach. Nothing walks you anywhere; skills fire only in reach.
--  * Auto Battle (T / AUTO): finds, chases and fights monsters near where it was switched on, with auto skills + potions.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local ClassesCfg = require(Shared.Config.Classes)
local Reach = require(Shared.Modules.Reach)
local Net = require(Shared.Modules.Net)
local State = require(script.Parent.Parent.State)
local UI = require(script.Parent.Parent.UI.UIKit)

local Combat = {}
local player = Players.LocalPlayer
local RunService = game:GetService("RunService")
-- client walking range = a bit inside the server limit (Modules/WeaponInfo)
local WeaponRange = {}
for k, v in pairs(require(game:GetService("ReplicatedStorage").Shared.Modules.WeaponInfo).Range) do
	WeaponRange[k] = v - 1
end
local lastAttack = 0
-- M1 strings (GameConfig.M1, mirrors CombatService.m1Gap): quick inside a 4-hit string, end-lag after the finisher
local m1 = { n = 0, at = 0 }

-- turn the body to face a point; with Shift Lock on the camera owns the facing (snapping the body toward a target
-- every swing while the humanoid turned it back to the camera shook the view: v0.25.26)
local function turnTo(r, point)
	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		return
	end
	r.CFrame = CFrame.lookAt(r.Position, point)
end

local function m1Ready(interval)
	local M1 = GameConfig.M1
	local inString = os.clock() - m1.at < M1.Reset
	local gap = interval * ((inString and m1.n >= M1.Hits) and M1.End or M1.Quick)
	return os.clock() - lastAttack >= gap
end
local function m1Swing()
	local M1 = GameConfig.M1
	m1.n = (os.clock() - m1.at < M1.Reset) and (m1.n % M1.Hits) + 1 or 1
	m1.at = os.clock()
	lastAttack = os.clock()
end
local anchor -- where Auto Battle was started
local busy = false
local lastPotion = 0

local function char()
	return player.Character
end
local function root()
	local c = char()
	return c and c:FindFirstChild("HumanoidRootPart")
end
local function hum()
	local c = char()
	return c and c:FindFirstChildOfClass("Humanoid")
end

local WeaponInfo = require(game:GetService("ReplicatedStorage").Shared.Modules.WeaponInfo)
local function weaponType()
	return WeaponInfo.TypeOf(State.profile)
end

local function mobModel(inst)
	-- a serpent's body piece (Controllers/SerpentBody) points at its head model
	local of = inst and inst:GetAttribute("SerpentOf")
	if of then
		local folder = workspace:FindFirstChild("Monsters")
		for _, m in ipairs(folder and folder:GetChildren() or {}) do
			if m:GetAttribute("MobUid") == of then
				return m
			end
		end
		return nil
	end
	while inst and inst ~= workspace do
		if inst:IsA("Model") and inst:GetAttribute("MobUid") then
			return inst
		end
		inst = inst.Parent
	end
	return nil
end

local function alive(model)
	return model and model.Parent and (model:GetAttribute("HP") or 0) > 0 and model.PrimaryPart ~= nil
end

function Combat.SetTarget(model)
	State.target = model
	State.Fire("target")
end

local function onShip()
	local r = root()
	if not r then
		return false
	end
	for _, s in ipairs(workspace:FindFirstChild("Ships") and workspace.Ships:GetChildren() or {}) do
		local sr = s.PrimaryPart
		if sr and (Vector2.new(sr.Position.X, sr.Position.Z) - Vector2.new(r.Position.X, r.Position.Z)).Magnitude < sr.Size.Magnitude / 2 + 4 then
			return true
		end
	end
	return false
end
Combat.OnShip = onShip

-- manual mode aiming (v0.24.6, owner): skills go where you point (mouse, or the screen center with Shift Lock /
-- touch), no monster lock needed. Returns flat direction, aimed world point, monster under the pointer (or nil)
local function aimInfo()
	local r = root()
	local cam = workspace.CurrentCamera
	if not r or not cam then
		return nil
	end
	local vp = cam.ViewportSize
	local pt = UserInputService.MouseEnabled and UserInputService:GetMouseLocation() or Vector2.new(vp.X / 2, vp.Y / 2)
	local ray = cam:ViewportPointToRay(pt.X, pt.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char(), workspace:FindFirstChild("ClientFX"), workspace:FindFirstChild("VoxelFX"), workspace:FindFirstChild("ReadabilityFX") }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	local pos = hit and hit.Position or (ray.Origin + ray.Direction * 80)
	local flat = Vector3.new(pos.X - r.Position.X, 0, pos.Z - r.Position.Z)
	if flat.Magnitude < 1 then
		local lv = cam.CFrame.LookVector
		flat = Vector3.new(lv.X, 0, lv.Z)
	end
	local mob = hit and mobModel(hit.Instance)
	return flat.Unit, pos, (mob and alive(mob)) and mob or nil
end
Combat.AimInfo = aimInfo

-- the monster a manual skill should hit: the one under the pointer, else the closest one inside a cone along the aim
local function aimedTarget(dir, mob, range)
	local r = root()
	if not r then
		return nil
	end
	if mob and Reach.Gap(r.Position, mob) <= range + 2 then
		return mob
	end
	local folder = workspace:FindFirstChild("Monsters")
	local best, bestD
	for _, m in ipairs(folder and folder:GetChildren() or {}) do
		if alive(m) and m:GetAttribute("MonsterId") ~= "FortCore" then
			local gap = Reach.Gap(r.Position, m)
			local to = (m.PrimaryPart.Position - r.Position) * Vector3.new(1, 0, 1)
			if gap <= range + 2 and to.Magnitude > 0.1 and dir:Dot(to.Unit) > 0.72 and (not bestD or gap < bestD) then
				best, bestD = m, gap
			end
		end
	end
	return best
end

function Combat.CastSkill(skillId, targetModel)
	local skill = ClassesCfg.SkillById[skillId]
	if not skill then
		return false
	end
	local now = os.clock()
	if (State.cooldowns[skillId] or 0) > now then
		return false
	end
	if (player:GetAttribute("SP") or 0) < skill.sp then
		UI.Toast("Not enough SP", "bad")
		return false
	end
	local target = targetModel or State.target
	local payload = { skillId = skillId }
	local kind = skill.kind
	-- on a ship skills always fire along the aim (v0.25.17: Auto mode needed a monster target, and at sea there are ships)
	if (not State.auto or onShip()) and not targetModel and (kind == "Melee" or kind == "Ranged" or kind == "GroundAoE" or kind == "Dash") then
		-- manual mode: aim with the pointer / crosshair, turn that way, fire even with nothing there
		local dir, pos, mob = aimInfo()
		local r = root()
		if dir and r then
			local aimed = kind ~= "GroundAoE" and aimedTarget(dir, mob, skill.range or 10) or nil
			local face = aimed and ((aimed.PrimaryPart.Position - r.Position) * Vector3.new(1, 0, 1)) or dir
			if face.Magnitude > 0.1 then
				turnTo(r, r.Position + face.Unit)
			end
			if kind == "GroundAoE" then
				local off = pos - r.Position
				local range = skill.range or 40
				if off.Magnitude > range then
					pos = r.Position + off.Unit * range
				end
				payload.pos = pos
			elseif aimed then
				payload.target = aimed
				payload.pos = aimed.PrimaryPart.Position
				if aimed ~= State.target then
					Combat.SetTarget(aimed)
				end
			else
				payload.dir = dir
			end
			State.cooldowns[skillId] = now + skill.cd
			State.Fire("cooldown")
			task.spawn(function()
				local res = Net.Request("CastSkill", payload)
				if not res.ok then
					State.cooldowns[skillId] = 0
					State.Fire("cooldown")
					if res.msg and res.msg ~= "On cooldown" then
						UI.Toast(res.msg, "bad")
					end
				end
			end)
			return true
		end
	end
	if kind == "Dash" and alive(target) then
		payload.target = target -- dash toward the target; without one it dashes straight ahead
	end
	if kind == "Melee" or kind == "Ranged" or kind == "GroundAoE" then
		if not alive(target) then
			UI.Toast("Select a target first", "info")
			return false
		end
		payload.target = target
		payload.pos = target.PrimaryPart.Position
		local r = root()
		local range = (skill.range or 10)
		if r and Reach.Gap(r.Position, target) > range + 2 then
			if State.auto then
				local h = hum()
				if h then
					h:MoveTo(Reach.Closest(r.Position, target))
				end
			else
				UI.Toast("Too far: get closer", "info")
			end
			return false
		end
	end
	State.cooldowns[skillId] = now + skill.cd -- optimistic
	State.Fire("cooldown")
	task.spawn(function()
		local res = Net.Request("CastSkill", payload)
		if not res.ok then
			State.cooldowns[skillId] = 0
			State.Fire("cooldown")
			if res.msg and res.msg ~= "On cooldown" then
				UI.Toast(res.msg, "bad")
			end
		end
	end)
	return true
end

-- Pick the monster under a screen point (InputObject.Position space, which excludes the top-bar inset).
-- 1) exact raycast through the click; 2) if that misses, the monster whose body is closest on screen within a
-- forgiving radius, so small crabs and fast taps on phones still connect.
local SOFT_RADIUS_PX = 70
function Combat.PickMob(screenPos)
	local cam = workspace.CurrentCamera
	if not cam then
		return nil
	end
	local ray = cam:ScreenPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char(), workspace:FindFirstChild("ClientFX"), workspace:FindFirstChild("ReadabilityFX") }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	local m = hit and mobModel(hit.Instance)
	if m and alive(m) then
		return m
	end
	local folder = workspace:FindFirstChild("Monsters")
	if not folder then
		return nil
	end
	local best, bestD = nil, math.huge
	for _, mob in ipairs(folder:GetChildren()) do
		if alive(mob) and mob:GetAttribute("MonsterId") ~= "FortCore" then
			local _, size = mob:GetBoundingBox()
			local center = mob.PrimaryPart.Position
			local sp, onScreen = cam:WorldToScreenPoint(center)
			if onScreen and sp.Z > 0 then
				-- grow the radius with the monster's on-screen size
				local edge = cam:WorldToScreenPoint(center + cam.CFrame.RightVector * size.Magnitude * 0.5)
				local bodyPx = (Vector2.new(edge.X, edge.Y) - Vector2.new(sp.X, sp.Y)).Magnitude
				local d = (Vector2.new(sp.X, sp.Y) - screenPos).Magnitude
				if d < SOFT_RADIUS_PX + bodyPx and d - bodyPx < bestD then
					best, bestD = mob, d - bodyPx
				end
			end
		end
	end
	return best
end

-- ===== Manual mode =====
local function attackReach()
	return (WeaponRange[weaponType()] or 8) + 2.5 -- the server allows a little more (lag)
end

-- what a swing should hit: the monster under the pointer, the current target, else the closest one within reach
-- (monsters in front of you win over ones behind)
local function manualTarget(screenPos)
	local r = root()
	if not r then
		return nil
	end
	local reach = attackReach()
	local picked = screenPos and Combat.PickMob(screenPos)
	if picked and Reach.Gap(r.Position, picked) <= reach then
		return picked
	end
	if alive(State.target) and Reach.Gap(r.Position, State.target) <= reach then
		return State.target
	end
	local folder = workspace:FindFirstChild("Monsters")
	local best, bestScore
	local look = r.CFrame.LookVector
	for _, m in ipairs(folder and folder:GetChildren() or {}) do
		if alive(m) and m:GetAttribute("MonsterId") ~= "FortCore" then
			local gap = Reach.Gap(r.Position, m)
			if gap <= reach then
				local to = (m.PrimaryPart.Position - r.Position) * Vector3.new(1, 0, 1)
				local facing = to.Magnitude > 0.1 and look:Dot(to.Unit) or 1
				local score = gap - facing * 4
				if not bestScore or score < bestScore then
					best, bestScore = m, score
				end
			end
		end
	end
	return best
end

-- one swing (rate-limited to your attack speed); screenPos = pointer position or nil (attack button)
function Combat.ManualAttack(screenPos)
	if State.auto or State.build.active or player:GetAttribute("Vending") or onShip() then
		return
	end
	local r, h = root(), hum()
	if not r or not h or h.Health <= 0 then
		return
	end
	local target = manualTarget(screenPos)
	if not target then
		-- nothing in reach: still select what you clicked (HP bar, skills), never walk there, and swing anyway:
		-- toward the pointer, else the way you face (v0.22.8)
		local picked = screenPos and Combat.PickMob(screenPos)
		if picked and picked ~= State.target then
			Combat.SetTarget(picked)
		end
		local d = State.derived
		if not m1Ready(d and d.attackInterval or 1.2) then
			return
		end
		m1Swing()
		local dir = r.CFrame.LookVector
		local cam = workspace.CurrentCamera
		if screenPos and cam then
			local ray = cam:ScreenPointToRay(screenPos.X, screenPos.Y)
			if math.abs(ray.Direction.Y) > 1e-3 then
				local t = (r.Position.Y - 2.5 - ray.Origin.Y) / ray.Direction.Y
				if t > 0 then
					local hitPos = ray.Origin + ray.Direction * t
					local flat = Vector3.new(hitPos.X - r.Position.X, 0, hitPos.Z - r.Position.Z)
					if flat.Magnitude > 1 then
						dir = flat.Unit
					end
				end
			end
		end
		turnTo(r, r.Position + Vector3.new(dir.X, 0, dir.Z))
		task.spawn(Net.Request, "Swing", { dir = dir })
		return
	end
	if target ~= State.target then
		Combat.SetTarget(target)
	end
	local d = State.derived
	local interval = d and d.attackInterval or 1.2
	if not m1Ready(interval) then
		return
	end
	m1Swing()
	local tpos = target.PrimaryPart.Position
	local lookAt = Vector3.new(tpos.X, r.Position.Y, tpos.Z)
	if (lookAt - r.Position).Magnitude > 0.5 then
		turnTo(r, lookAt)
	end
	task.spawn(Net.Request, "Attack", { target = target })
end

function Combat.ClickAt(screenPos)
	if State.build.active or onShip() then
		return
	end
	local pos = Vector2.new(screenPos.X, screenPos.Y)
	if State.auto then
		-- Auto Battle: a click picks what it fights next
		local m = Combat.PickMob(pos)
		if m then
			Combat.SetTarget(m)
		end
		return
	end
	Combat.ManualAttack(pos)
end

-- Chase the target, then attack at the ASPD interval
local function engage(target, useSkills)
	local r, h = root(), hum()
	if not r or not h or h.Health <= 0 or not alive(target) then
		return false
	end
	local wType = weaponType()
	local range = WeaponRange[wType] or 9
	local tpos = target.PrimaryPart.Position
	-- distance to the target's BODY (big bosses have their root high up in the middle)
	local near = Reach.Closest(r.Position, target)
	local dist = Reach.Gap(r.Position, target)
	-- Auto skills
	if useSkills and State.profile then
		for _, id in ipairs(State.profile.skillBar) do
			if State.profile.autoSkills[id] then
				local s = ClassesCfg.SkillById[id]
				if s and (State.cooldowns[id] or 0) <= os.clock() and (player:GetAttribute("SP") or 0) >= s.sp then
					local srange = s.range or 0
					if s.kind == "AoE" then
						srange = (s.radius or 10) - 2
					end
					if s.kind == "Buff" or s.kind == "PartyBuff" then
						if not string.find(player:GetAttribute("Buffs") or "", id) then
							Combat.CastSkill(id, target)
							return true
						end
					elseif s.kind == "Heal" or s.kind == "PartyHeal" then
						if h.Health / h.MaxHealth < 0.6 then
							Combat.CastSkill(id, target)
							return true
						end
					elseif dist <= srange then
						Combat.CastSkill(id, target)
						return true
					end
				end
			end
		end
	end
	if dist > range - 1.5 then
		local flat = Vector3.new(near.X, r.Position.Y, near.Z)
		local away = r.Position - flat
		h:MoveTo(away.Magnitude > 0.1 and (flat + away.Unit * math.min(range * 0.4, away.Magnitude)) or flat)
		return true
	end
	local d = State.derived
	local interval = d and d.attackInterval or 1.2
	if m1Ready(interval) then
		m1Swing()
		local look = Vector3.new(tpos.X, r.Position.Y, tpos.Z)
		if (look - r.Position).Magnitude > 0.5 then
			turnTo(r, look)
		end
		task.spawn(Net.Request, "Attack", { target = target })
	end
	return true
end

-- Give up on targets that are too far away or that we cannot get closer to (on a cliff, across water...)
local function maxChase()
	return State.SearchRadius() + 30
end
local chase = { target = nil, best = math.huge, since = 0 }
local function shouldDrop(target)
	local r = root()
	if not r or not alive(target) then
		return true
	end
	local d = Reach.Gap(r.Position, target)
	if d > maxChase() then
		return true
	end
	local reach = (WeaponRange[weaponType()] or 9) + 2
	if chase.target ~= target then
		chase.target, chase.best, chase.since = target, d, os.clock()
		return false
	end
	if d <= reach then
		chase.since = os.clock() -- in range and fighting: not stuck
	elseif d < chase.best - 1.5 then
		chase.best, chase.since = d, os.clock()
	elseif os.clock() - chase.since > 3.5 then
		return true -- no progress for 3.5 s while out of range: unreachable
	end
	return false
end

local function findNearestMob(center, radius, exclude)
	local best, bestD = nil, radius
	local folder = workspace:FindFirstChild("Monsters")
	if not folder then
		return nil
	end
	for _, m in ipairs(folder:GetChildren()) do
		if alive(m) and m ~= exclude and m:GetAttribute("MonsterId") ~= "FortCore" then
			local d = (m.PrimaryPart.Position - center).Magnitude
			-- monsters already attacking you count as closer, so Auto Battle defends itself first
			if m:GetAttribute("TargetId") == player.UserId then
				d *= 0.5
			end
			if d < bestD then
				best, bestD = m, d
			end
		end
	end
	return best
end

function Combat.SetAuto(on)
	State.auto = on
	local r = root()
	anchor = on and r and r.Position or nil
	State.Fire("auto")
	UI.Notice(on and "AUTO BATTLE ON" or "AUTO BATTLE OFF", on and UI.Theme.Green or UI.Theme.Grey)
	if on then
		task.spawn(Net.Request, "QuestPing", { kind = "Auto" })
	end
end

-- ===== Dash (Q) =====
-- The character's physics belong to this client, so the burst happens here (instant, no lag); the server only checks
-- the cooldown and tells everyone else to draw the streak.
Combat.dashReadyAt = 0
function Combat.Dash()
	-- v0.25.27 (owner): ONE dash on the ground, in a jump and in flight: same cooldown, trail and server FX
	local Flight = require(script.Parent.Flight)
	local r, h = root(), hum()
	local cfg = GameConfig.Dash
	if not r or not h or h.Health <= 0 or os.clock() < Combat.dashReadyAt then
		return
	end
	if h.Sit or h:GetState() == Enum.HumanoidStateType.Swimming then
		return
	end
	Combat.dashReadyAt = os.clock() + cfg.Cooldown
	if Flight.IsFlying() then
		-- flying: a burst along where the camera looks, added to the flight velocity and fading out (momentum)
		local look = workspace.CurrentCamera.CFrame.LookVector
		Flight.Shove(look * cfg.Speed)
		require(script.Parent.VFX).Afterimages(r.Parent, cfg.Duration + 0.06, 0.03)
		task.spawn(Net.Request, "Dash", { dir = look })
		return
	end
	local dir = h.MoveDirection
	if dir.Magnitude < 0.1 then
		dir = r.CFrame.LookVector
	end
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local att = Instance.new("Attachment")
	att.Parent = r
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = math.huge
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.PlaneVelocity = Vector2.new(dir.X, dir.Z) * cfg.Speed
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = r
	turnTo(r, r.Position + dir)
	-- ghost trail right away (others see it from the Dash FX) and a quick FOV kick
	local char = r.Parent
	require(script.Parent.VFX).Afterimages(char, cfg.Duration + 0.02, 0.03)
	local cam = workspace.CurrentCamera
	local fov0 = cam.FieldOfView
	TweenService:Create(cam, TweenInfo.new(cfg.Duration * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = fov0 + 9 }):Play()
	task.delay(cfg.Duration, function()
		lv:Destroy()
		att:Destroy()
		-- v0.25.27 (owner): no hard stop, the body keeps its momentum and slows down by itself
		TweenService:Create(cam, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = fov0 }):Play()
	end)
	task.spawn(Net.Request, "Dash", { dir = dir })
end

function Combat.ToggleAuto()
	Combat.SetAuto(not State.auto)
end

local function autoPotion()
	local h = hum()
	local p = State.profile
	if not h or not p or h.Health <= 0 then
		return
	end
	if h.Health / h.MaxHealth * 100 < (p.settings.autoPotionPct or 35) and os.clock() - lastPotion > 2 then
		for _, e in ipairs(p.inventory) do
			if e.id == "MeatOnBone" or e.id == "BigFeast" then
				lastPotion = os.clock()
				task.spawn(Net.Request, "UseItem", { uid = e.uid })
				return
			end
		end
	end
	local sp, max = player:GetAttribute("SP") or 0, player:GetAttribute("MaxSP") or 1
	if sp / max < 0.2 and os.clock() - lastPotion > 2 then
		for _, e in ipairs(p.inventory) do
			if e.id == "TangerineJuice" then
				lastPotion = os.clock()
				task.spawn(Net.Request, "UseItem", { uid = e.uid })
				return
			end
		end
	end
end

local function tick()
	if busy then
		return
	end
	busy = true
	local r = root()
	if r and not player:GetAttribute("Vending") and not State.build.active then
		if State.auto then
			autoPotion()
			if not onShip() then
				if anchor and (r.Position - anchor).Magnitude > GameConfig.AutoBattle.LeashRadius then
					Combat.SetTarget(nil)
					local h = hum()
					if h then
						h:MoveTo(anchor)
					end
				else
					if State.target and alive(State.target) and shouldDrop(State.target) then
						Combat.SetTarget(findNearestMob(r.Position, State.SearchRadius(), State.target))
					elseif not alive(State.target) then
						Combat.SetTarget(findNearestMob(r.Position, State.SearchRadius()))
					end
					if State.target then
						engage(State.target, true)
					end
				end
			end
		end
		if State.target and not alive(State.target) then
			Combat.SetTarget(nil)
		end
	end
	busy = false
end

local SKILL_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six,
	Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine, Enum.KeyCode.Zero, Enum.KeyCode.Minus, Enum.KeyCode.Equals }
local ITEM_KEYS = { Enum.KeyCode.F1, Enum.KeyCode.F2, Enum.KeyCode.F3, Enum.KeyCode.F4, Enum.KeyCode.F5, Enum.KeyCode.F6, Enum.KeyCode.F7, Enum.KeyCode.F8 }
Combat.SKILL_KEY_LABELS = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" }

-- quick item slot i (F1-F8): use one of that item from the bag
local lastItemUse = 0
function Combat.UseQuickItem(i)
	local p = State.profile
	local id = p and p.itemBar and p.itemBar[i]
	if not id or id == "" or os.clock() - lastItemUse < 0.25 then
		return
	end
	lastItemUse = os.clock()
	task.spawn(function()
		local res = Net.Request("UseItem", { id = id })
		if not res.ok and res.msg then
			local UI = require(script.Parent.Parent.UI.UIKit)
			UI.Toast(tostring(res.msg), "bad")
		end
	end)
end

-- dash skills (Fire Dash, Slick Slide...): the server says where, we slide there fast (CombatService CastSkill Dash)
local function skillDash(d)
	local r, h = root(), hum()
	if not r or not h or h.Health <= 0 or typeof(d.dir) ~= "Vector3" then
		return
	end
	local dir = Vector3.new(d.dir.X, 0, d.dir.Z)
	if dir.Magnitude < 0.1 then
		return
	end
	dir = dir.Unit
	local speed = tonumber(d.speed) or 60
	local dur = math.clamp((tonumber(d.dist) or 0) / speed, 0.05, 0.8)
	turnTo(r, r.Position + dir)
	local att = Instance.new("Attachment")
	att.Parent = r
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = math.huge
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.PlaneVelocity = Vector2.new(dir.X, dir.Z) * speed
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = r
	task.delay(dur, function()
		-- ease out instead of a dead stop
		if lv.Parent then
			lv.PlaneVelocity = Vector2.new(dir.X, dir.Z) * speed * 0.25
		end
		task.wait(0.08)
		lv:Destroy()
		att:Destroy()
	end)
end

-- v0.25.17 (owner): a boss blow knocks you away from it; in the air it pushes the flight instead of dropping you
local function knocked(d)
	local r, h = root(), hum()
	if not r or not h or h.Health <= 0 or typeof(d.dir) ~= "Vector3" then
		return
	end
	local power = tonumber(d.power) or 40
	local Flight = require(script.Parent.Flight)
	if Flight.IsFlying() then
		Flight.Shove(d.dir * power + Vector3.new(0, power * 0.25, 0))
		return
	end
	local att = Instance.new("Attachment")
	att.Parent = r
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = math.huge
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = d.dir * power + Vector3.new(0, power * 0.35, 0)
	lv.Parent = r
	task.delay(0.18, function()
		lv:Destroy()
		att:Destroy()
	end)
end

function Combat.Start()
	Net.OnPush("SkillDash", skillDash)
	Net.OnPush("Knock", knocked)
	-- Left click: attack (manual) / pick a target (Auto). Holding the button keeps swinging in manual mode.
	local holding, holdPos = false, nil
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			holding, holdPos = true, input.Position
			Combat.ClickAt(input.Position)
		elseif input.KeyCode == Enum.KeyCode.T then
			Combat.ToggleAuto()
		elseif input.KeyCode == Enum.KeyCode.Q then
			Combat.Dash()
		elseif input.KeyCode == Enum.KeyCode.Tab then
			local r = root()
			if r then
				Combat.SetTarget(findNearestMob(r.Position, State.SearchRadius()))
			end
		else
			-- skills: 1-6 on the main row, 7 8 9 0 - = on the second row; quick items: F1-F8
			local idx = table.find(SKILL_KEYS, input.KeyCode)
			local id = idx and State.profile and State.profile.skillBar[idx]
			if id and id ~= "" then
				Combat.CastSkill(id)
			end
			local f = table.find(ITEM_KEYS, input.KeyCode)
			if f then
				Combat.UseQuickItem(f)
			end
		end
	end)
	-- Taps (not drags, not on buttons) select monsters on touch screens
	UserInputService.TouchTapInWorld:Connect(function(pos, processedByUI)
		if not processedByUI then
			Combat.ClickAt(pos)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if holding and input.UserInputType == Enum.UserInputType.MouseMovement then
			holdPos = input.Position
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			holding = false
		end
	end)
	RunService.Heartbeat:Connect(function()
		if holding and holdPos and not State.auto then
			Combat.ManualAttack(Vector2.new(holdPos.X, holdPos.Y))
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			local ok, err = pcall(tick)
			if not ok then
				busy = false
				warn("[Combat]", err)
			end
		end
	end)
	player.CharacterAdded:Connect(function()
		Combat.SetTarget(nil)
		if State.auto then
			Combat.SetAuto(false)
		end
	end)
end

-- Mobile attack button: swing at the closest monster in reach (manual), or pick the nearest one for Auto Battle
function Combat.AttackNearest()
	if not State.auto then
		Combat.ManualAttack(nil)
		return
	end
	local r = root()
	if r and not alive(State.target) then
		Combat.SetTarget(findNearestMob(r.Position, 60))
	end
end

return Combat
