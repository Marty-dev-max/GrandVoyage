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
local Anim = require(Shared.Modules.Anim)
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

-- every monster you can fight: workspace.Monsters + NPC ship crew (they ride inside their ship model, v0.25.42)
local CollectionService = game:GetService("CollectionService")
local function mobList()
	local folder = workspace:FindFirstChild("Monsters")
	local list = folder and folder:GetChildren() or {}
	for _, m in ipairs(CollectionService:GetTagged("ShipCrew")) do
		table.insert(list, m)
	end
	return list
end

local function alive(model)
	return model and model.Parent and (model:GetAttribute("HP") or 0) > 0 and model.PrimaryPart ~= nil
end

function Combat.SetTarget(model)
	State.target = model
	State.Fire("target")
end

-- mine = only your own ship counts (there a click fires the cannons; on an NPC deck you fight the crew)
local function onShip(mine)
	local r = root()
	if not r then
		return false
	end
	for _, s in ipairs(workspace:FindFirstChild("Ships") and workspace.Ships:GetChildren() or {}) do
		local sr = s.PrimaryPart
		if sr and (not mine or s:GetAttribute("OwnerId") == player.UserId) and (Vector2.new(sr.Position.X, sr.Position.Z) - Vector2.new(r.Position.X, r.Position.Z)).Magnitude < sr.Size.Magnitude / 2 + 4 then
			return true
		end
	end
	return false
end
Combat.OnShip = onShip

-- v0.25.53 (owner: on deck the click fired cannons, so you could not fight the Bay Serpent): only the helm belongs to
-- sailing (click = cannons, E / F = dock / fire); anywhere else on your ship you fight normally
local function atHelm()
	local h = hum()
	return h ~= nil and h.SeatPart ~= nil and h.SeatPart.Name == "HelmSeat"
end
Combat.AtHelm = atHelm

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
	-- 3D aim (v0.25.48): toward chest height above the pointed spot, so pointing at flat ground aims level and pointing
	-- up a hill / at the sky / down a cliff tilts the skill (the server clamps the tilt)
	local h = hum()
	local lift = hit and ((h and h.HipHeight or 2) + r.Size.Y / 2) or 0
	local d3 = pos + Vector3.new(0, lift, 0) - r.Position
	local dir3 = d3.Magnitude > 1 and d3.Unit or flat.Unit
	return flat.Unit, pos, (mob and alive(mob)) and mob or nil, dir3
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
	local best, bestD
	for _, m in ipairs(mobList()) do
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

-- charge (v0.25.65, docs/Plan-Fruits-v2.md): 0..1 for skills with `charge = true` (how long the key was held)
function Combat.CastSkill(skillId, targetModel, aim, charge)
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
	if skill.charge then
		payload.charge = math.clamp(charge or (State.auto and 0.25 or 0), 0, 1)
	end
	local kind = skill.kind
	-- on a ship skills always fire along the aim (v0.25.17: Auto mode needed a monster target, and at sea there are ships)
	if (not State.auto or onShip()) and not targetModel and (kind == "Melee" or kind == "Ranged" or kind == "GroundAoE" or kind == "Dash") then
		-- manual mode: aim with the pointer / crosshair, turn that way, fire even with nothing there
		local dir, pos, mob, dir3 = aimInfo()
		if aim then
			dir, pos, mob, dir3 = aim[1], aim[2], aim[3], aim[4] -- a touch aim (Combat.TouchAim)
		end
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
				payload.dir = dir3 or dir
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
	local best, bestD = nil, math.huge
	for _, mob in ipairs(mobList()) do
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
	local best, bestScore
	local look = r.CFrame.LookVector
	for _, m in ipairs(mobList()) do
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
	if State.auto or State.build.active or player:GetAttribute("Vending") or atHelm() then
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
		-- an NPC hull in reach takes the blow (v0.25.42, owner: wreck ships by hand, not only with cannons)
		for _, s in ipairs(workspace:FindFirstChild("Ships") and workspace.Ships:GetChildren() or {}) do
			if s:GetAttribute("NPC") and s.PrimaryPart and (s:GetAttribute("HP") or 0) > 0 and Reach.Gap(r.Position, s) <= attackReach() then
				local sp = s.PrimaryPart.Position
				turnTo(r, Vector3.new(sp.X, r.Position.Y, sp.Z))
				task.spawn(Net.Request, "Attack", { target = s.PrimaryPart })
				return
			end
		end
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
	if State.build.active or atHelm() then
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
	local aboard = onShip(true) -- sailing your own ship: Auto Battle never walks you off it after enemy crew
	for _, m in ipairs(mobList()) do
		if alive(m) and m ~= exclude and m:GetAttribute("MonsterId") ~= "FortCore" and not (aboard and CollectionService:HasTag(m, "ShipCrew")) then
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

-- v0.25.55 (owner): F1 = HP potion, F2 = SP potion. Each uses the item picked in its gear popup (settings.hpItem /
-- spItem; "Auto" = the smallest one you own that fills the gap, else the biggest) and drinks by itself below
-- settings.hpPct / spPct (0 = off), in Auto Battle and manual play alike (the old "Eat below" only ran in Auto).
local ItemDB = require(Shared.Modules.ItemDB)
Combat.POTION_DEFAULT = { hp = "MeatOnBone", sp = "TangerineJuice" }
Combat.POTION_PCT = { hp = 50, sp = 30 }
local function potionPower(def, kind)
	return def and def.kind == "Consumable" and not def.special and (kind == "hp" and def.heal or def.healSp) or nil
end
Combat.PotionPower = potionPower
-- every potion of that kind in the bag: { id, power, qty }, weakest first
function Combat.PotionsOwned(kind)
	local p = State.profile
	local byId, list = {}, {}
	for _, e in ipairs(p and p.inventory or {}) do
		local def = ItemDB.Get(e.id)
		local power = potionPower(def, kind)
		if power then
			if not byId[e.id] then
				byId[e.id] = { id = e.id, power = power, qty = 0 }
				table.insert(list, byId[e.id])
			end
			byId[e.id].qty += e.qty or 1
		end
	end
	table.sort(list, function(a, b)
		return a.power < b.power
	end)
	return list, byId
end
local function missing(kind)
	if kind == "hp" then
		local h = hum()
		return h and h.MaxHealth > 0 and 1 - h.Health / h.MaxHealth or 0
	end
	return 1 - (player:GetAttribute("SP") or 0) / math.max(1, player:GetAttribute("MaxSP") or 1)
end
-- the item a slot would use now (nil = none owned) + the item it shows
function Combat.PotionPick(kind)
	local s = State.profile and State.profile.settings or {}
	local pref = s[kind .. "Item"] or "Auto"
	local list, byId = Combat.PotionsOwned(kind)
	if pref ~= "Auto" then
		return byId[pref] and pref or nil, pref
	end
	if #list == 0 then
		return nil, Combat.POTION_DEFAULT[kind]
	end
	local gap = missing(kind)
	for _, it in ipairs(list) do
		if it.power >= gap then
			return it.id, it.id
		end
	end
	return list[#list].id, list[#list].id
end
local lastDrink = { hp = 0, sp = 0 }
function Combat.UsePotion(kind, auto)
	local id = Combat.PotionPick(kind)
	if not id then
		if not auto then
			UI.Toast(kind == "hp" and "No HP potions in your bag" or "No SP potions in your bag", "bad")
		end
		return
	end
	if os.clock() - lastDrink[kind] < 0.4 then
		return
	end
	lastDrink[kind] = os.clock()
	task.spawn(function()
		local res = Net.Request("UseItem", { id = id })
		if not res.ok and res.msg and not auto and res.msg ~= "On cooldown" then
			UI.Toast(tostring(res.msg), "bad")
		end
	end)
end

local function autoPotion()
	local h = hum()
	local p = State.profile
	local c = player.Character
	if not h or not p or h.Health <= 0 or (c and c:GetAttribute("Downed")) then
		return
	end
	local s = p.settings or {}
	for _, kind in ipairs({ "hp", "sp" }) do
		local pct = s[kind .. "Pct"] or Combat.POTION_PCT[kind]
		if pct > 0 and (1 - missing(kind)) * 100 < pct and os.clock() - lastDrink[kind] > 1.5 then
			Combat.UsePotion(kind, true)
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
		autoPotion()
		if State.auto then
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

-- v0.25.44 (owner): skill keys are rebindable (Controllers/Hotkeys; defaults E R F Z X C, then 1-6)
local Hotkeys = require(script.Parent.Hotkeys)
local ITEM_KEYS = { Enum.KeyCode.F1, Enum.KeyCode.F2 } -- v0.25.55: F1 = HP potion, F2 = SP potion
Combat.SKILL_KEY_LABELS = setmetatable({}, {
	__index = function(_, i)
		return Hotkeys.Label("Skill" .. i)
	end,
})

-- quick slot i: F1 = HP potion, F2 = SP potion (v0.25.55)
function Combat.UseQuickItem(i)
	Combat.UsePotion(i == 1 and "hp" or "sp")
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

-- hold-to-aim (v0.25.48, owner): in manual mode a held skill key shows where the skill will go (a line that follows
-- the pointer, or the screen center with Shift Lock, up and down too; a square on the ground for ground skills) and the
-- character turns with it; letting go casts it there. Auto mode and skills without a direction cast on the press.
local AIM_KINDS = { Melee = true, Ranged = true, GroundAoE = true, Dash = true }
local CHARGE_TIME = 1.2 -- seconds of holding for a full charge (server: CombatService CHARGE_BONUS)
local holding -- { id, slot, conn, line, spot, rot }
local function stopAim()
	if not holding then
		return
	end
	holding.conn:Disconnect()
	holding.line:Destroy()
	holding.spot:Destroy()
	local h = hum()
	if holding.chargeAnim and h then
		-- the release clip (skill `anim`) starts from the same wind-up pose, so a short fade blends straight into it
		Anim.Stop(h, holding.chargeAnim, 0.2)
	end
	if holding.rot and h then
		h.AutoRotate = true
	end
	holding = nil
end
local function aimPart(name, color, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.45
	p.Size = Vector3.new(1, 1, 1)
	p.Parent = parent
	return p
end
-- src (v0.25.50): where the aim comes from. nil = keyboard (pointer / crosshair aim, held while the key is down);
-- a touch = the finger dragged away from the skill button steers it like a joystick, held until the finger lifts
local function touchAim(skill, input, startPos)
	local r = root()
	local cam = workspace.CurrentCamera
	if not r or not cam then
		return nil
	end
	local drag = Vector2.new(input.Position.X, input.Position.Y) - startPos
	if drag.Magnitude < 14 then
		return aimInfo() -- barely moved: straight where the camera looks, like a tap
	end
	local cf = cam.CFrame
	local right = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z).Unit
	local fwd = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z).Unit
	local dir = (right * drag.X - fwd * drag.Y).Unit -- screen down = toward the camera
	local reach = skill.range or 20
	local pos = r.Position + dir * reach * math.clamp(drag.Magnitude / 150, 0.15, 1) - Vector3.new(0, 2.5, 0)
	-- tilt follows the camera's pitch (looking up aims up)
	local y = math.clamp(cf.LookVector.Y + 0.25, -0.8, 0.8)
	return dir, pos, nil, dir * math.sqrt(1 - y * y) + Vector3.new(0, y, 0)
end

local function startAim(id, slot, src)
	local skill = ClassesCfg.SkillById[id]
	if (State.cooldowns[id] or 0) > os.clock() then
		return
	end
	if (player:GetAttribute("SP") or 0) < skill.sp then
		UI.Toast("Not enough SP", "bad")
		return
	end
	local fx = workspace:FindFirstChild("ClientFX") or workspace
	local hold = { id = id, slot = slot, t0 = os.clock() }
	if skill.charge then
		-- power gathers in the hand while you hold (full at CHARGE_TIME)
		local c = char()
		local hand = c and c:FindFirstChild("RightHand")
		local fdef = skill.fruit and require(Shared.Config.Fruits).ById[skill.fruit]
		local col = fdef and fdef.color or Color3.fromRGB(255, 220, 140)
		pcall(require(script.Parent.VFX).Charge, hand, col, CHARGE_TIME + 0.2)
		if skill.chargeAnim == "Bounce_WindBoth" then -- both arms wind back: both hands gather power
			pcall(require(script.Parent.VFX).Charge, c and c:FindFirstChild("LeftHand"), col, CHARGE_TIME + 0.2)
		end
		-- v0.25.66: the wind-up pose loops while the key is held (replicates: everyone sees the arm pulled back)
		local h = hum()
		if skill.chargeAnim and h then
			Anim.Play(h, skill.chargeAnim, { fade = 0.1 })
			hold.chargeAnim = skill.chargeAnim
		end
	end
	hold.line = aimPart("AimLine", Color3.fromRGB(255, 230, 120), fx)
	hold.spot = aimPart("AimSpot", Color3.fromRGB(255, 150, 60), fx)
	-- v0.25.49 (owner: the aim line stayed after letting go): the key-up event from ContextActionService did not arrive
	-- in Studio, so the key's real state is checked every frame too (whichever sees the release first casts)
	local keyName = not src and Hotkeys.Key("Skill" .. slot)
	local keyCode = keyName and Enum.KeyCode[keyName]
	local startPos = src and Vector2.new(src.Position.X, src.Position.Y)
	hold.conn = RunService.RenderStepped:Connect(function()
		if holding ~= hold then
			return
		end
		local released
		if src then
			released = src.UserInputState == Enum.UserInputState.End or src.UserInputState == Enum.UserInputState.Cancel
		else
			released = not keyCode or not UserInputService:IsKeyDown(keyCode)
		end
		if released then
			stopAim()
			-- the aim shown last frame (a lifted finger has no pointer) + how long it was charged
			Combat.CastSkill(hold.id, nil, hold.aim, (os.clock() - hold.t0) / CHARGE_TIME)
			return
		end
		local r, h = root(), hum()
		local dir, pos, mob, dir3
		if src then
			dir, pos, mob, dir3 = touchAim(skill, src, startPos)
		else
			dir, pos, mob, dir3 = aimInfo()
		end
		if not r or not dir then
			return
		end
		hold.aim = src and { dir, pos, mob, dir3 } or nil
		-- face the aim (Shift Lock already turns the body with the camera)
		if h and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
			h.AutoRotate = false
			hold.rot = true
			turnTo(r, r.Position + dir)
		end
		local to
		if skill.kind == "GroundAoE" then
			local off = pos - r.Position
			local range = skill.range or 40
			to = off.Magnitude > range and r.Position + off.Unit * range or pos
			local rad = skill.radius or 6
			hold.spot.Size = Vector3.new(rad * 2, 0.2, rad * 2)
			hold.spot.CFrame = CFrame.new(to) * CFrame.Angles(0, math.atan2(-dir.X, -dir.Z), 0)
		else
			-- same tilt clamp as the server (CombatService aim3)
			local y = math.clamp(dir3.Y, -0.8, 0.8)
			local d = dir * math.sqrt(1 - y * y) + Vector3.new(0, y, 0)
			if skill.kind == "Dash" then
				d = dir -- dashes stay on the ground
			end
			to = r.Position + d * (skill.range or 10)
			hold.spot.Size = Vector3.new(1.2, 1.2, 1.2)
			hold.spot.CFrame = CFrame.lookAt(to, to + d)
		end
		local len = (to - r.Position).Magnitude
		hold.line.Size = Vector3.new(0.35, 0.35, math.max(0.1, len))
		hold.line.CFrame = CFrame.lookAt(r.Position, to) * CFrame.new(0, 0, -len / 2)
	end)
	holding = hold
end
Combat.CancelAim = stopAim

-- touch hotbar (HUD): true when this skill aims by holding (manual mode, a skill with a direction)
function Combat.AimableSkill(id)
	local skill = ClassesCfg.SkillById[id]
	return skill ~= nil and AIM_KINDS[skill.kind] == true and (not State.auto or onShip())
end

-- touch hotbar: hold the skill button and drag to aim, lift to cast
function Combat.TouchAim(id, slot, input)
	if holding then
		local held = holding.id
		stopAim()
		Combat.CastSkill(held)
	end
	startAim(id, slot, input)
	return holding ~= nil
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
			if require(script.Parent.Slingshot).Busy() then -- v0.25.66: Bounce Slingshot Launch owns the click
				return
			end
			if State.heldFruit then -- v0.25.33: a held Cursed Fruit takes the click (Eat / Store / Drop)
				State.heldFruit.choose()
				return
			end
			holding, holdPos = true, input.Position
			Combat.ClickAt(input.Position)
		else
			-- quick items: F1-F8 (skills, Dash, Auto, Tab target go through Hotkeys below)
			local f = table.find(ITEM_KEYS, input.KeyCode)
			if f then
				Combat.UseQuickItem(f)
			end
		end
	end)
	local Interact = require(script.Parent.Interact)
	for i = 1, GameConfig.SkillBarSize do
		Hotkeys.On("Skill" .. i, function()
			local key = Hotkeys.Key("Skill" .. i)
			-- E still talks / opens what you stand by (a prompt card is up), and at your ship's helm E docks and F fires
			-- the cannons (Sailing): those keys pass on there instead of casting
			if State.build.active or (key == "E" and Interact.AnyShown()) or ((key == "E" or key == "F") and atHelm()) then
				return false
			end
			local id = State.profile and State.profile.skillBar[i]
			if id and id ~= "" then
				local skill = ClassesCfg.SkillById[id]
				if skill and AIM_KINDS[skill.kind] and (not State.auto or onShip()) then
					if holding then -- another skill key while aiming: the held one goes first
						local held, t0 = holding.id, holding.t0
						stopAim()
						Combat.CastSkill(held, nil, nil, (os.clock() - t0) / CHARGE_TIME)
					end
					startAim(id, i)
				else
					Combat.CastSkill(id)
				end
			end
		end)
		Hotkeys.OnRelease("Skill" .. i, function(cancelled)
			if holding and holding.slot == i then
				local id, t0 = holding.id, holding.t0
				stopAim()
				if not cancelled then
					Combat.CastSkill(id, nil, nil, (os.clock() - t0) / CHARGE_TIME)
				end
			end
		end)
	end
	Hotkeys.On("Auto", function()
		Combat.ToggleAuto()
	end)
	Hotkeys.On("Dash", function()
		Combat.Dash()
	end)
	Hotkeys.On("Target", function()
		local r = root()
		if r then
			Combat.SetTarget(findNearestMob(r.Position, State.SearchRadius()))
		end
	end)
	-- Taps (not drags, not on buttons) select monsters on touch screens
	UserInputService.TouchTapInWorld:Connect(function(pos, processedByUI)
		if not processedByUI then
			if State.heldFruit then
				State.heldFruit.choose()
				return
			end
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
		State.heldFruit = nil -- the held fruit model went with the old body
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
