-- Combat (client): click-to-target, Ragnarok-style chase & attack, skills, Auto Battle + auto potions
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local ClassesCfg = require(Shared.Config.Classes)
local ItemDB = require(Shared.Modules.ItemDB)
local Formulas = require(Shared.Modules.Formulas)
local Net = require(Shared.Modules.Net)
local State = require(script.Parent.Parent.State)
local UI = require(script.Parent.Parent.UI.UIKit)

local Combat = {}
local player = Players.LocalPlayer
local WeaponRange = { Knuckles = 8, Sword = 9, Shoes = 8, Hammer = 9, Slingshot = 44, StormBaton = 31, MedKit = 24 }
local lastAttack = 0
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

local function weaponType()
	local p = State.profile
	if not p or not p.equipment.weapon then
		return "Sword"
	end
	local e = Formulas.FindItem(p, p.equipment.weapon)
	local def = e and ItemDB.Get(e.id)
	return def and def.weaponType or "Sword"
end

local function mobModel(inst)
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
		if r and (r.Position - target.PrimaryPart.Position).Magnitude > range + 3 then
			local h = hum()
			if h then
				h:MoveTo(target.PrimaryPart.Position)
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

function Combat.ClickAt(screenPos)
	if State.build.active or onShip() then
		return
	end
	local m = Combat.PickMob(Vector2.new(screenPos.X, screenPos.Y))
	if m then
		Combat.SetTarget(m)
		State.chasing = true
	end
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
	local dist = (tpos - r.Position).Magnitude
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
	if dist > range then
		h:MoveTo(tpos - (tpos - r.Position).Unit * (range * 0.6))
		return true
	end
	local d = State.derived
	local interval = d and d.attackInterval or 1.2
	if os.clock() - lastAttack >= interval then
		lastAttack = os.clock()
		local look = Vector3.new(tpos.X, r.Position.Y, tpos.Z)
		if (look - r.Position).Magnitude > 0.5 then
			r.CFrame = CFrame.lookAt(r.Position, look)
		end
		task.spawn(Net.Request, "Attack", { target = target })
	end
	return true
end

-- Give up on targets that are too far away or that we cannot get closer to (on a cliff, across water...)
local MAX_CHASE = GameConfig.AutoBattle.SearchRadius + 30
local chase = { target = nil, best = math.huge, since = 0 }
local function shouldDrop(target)
	local r = root()
	if not r or not alive(target) then
		return true
	end
	local d = (target.PrimaryPart.Position - r.Position).Magnitude
	if d > MAX_CHASE then
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
						Combat.SetTarget(findNearestMob(r.Position, GameConfig.AutoBattle.SearchRadius, State.target))
					elseif not alive(State.target) then
						Combat.SetTarget(findNearestMob(r.Position, GameConfig.AutoBattle.SearchRadius))
					end
					if State.target then
						engage(State.target, true)
					end
				end
			end
		elseif State.chasing and alive(State.target) then
			if shouldDrop(State.target) then
				Combat.SetTarget(nil)
				State.chasing = false
				local h = hum()
				if h then
					h:MoveTo(r.Position) -- stop walking toward it
				end
				UI.Toast("Target out of reach", "info")
			else
				engage(State.target, false)
			end
		end
		if State.target and not alive(State.target) then
			Combat.SetTarget(nil)
			State.chasing = false
		end
	end
	busy = false
end

function Combat.Start()
	-- Click a monster to attack it (keeps attacking the same target)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			Combat.ClickAt(input.Position)
		elseif input.KeyCode == Enum.KeyCode.T then
			Combat.ToggleAuto()
		elseif input.KeyCode == Enum.KeyCode.Tab then
			local r = root()
			if r then
				Combat.SetTarget(findNearestMob(r.Position, GameConfig.AutoBattle.SearchRadius))
				State.chasing = State.target ~= nil
			end
		else
			local keys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight }
			local idx = table.find(keys, input.KeyCode)
			if idx and State.profile and State.profile.skillBar[idx] then
				Combat.CastSkill(State.profile.skillBar[idx])
			end
		end
	end)
	-- Taps (not drags, not on buttons) select monsters on touch screens
	UserInputService.TouchTapInWorld:Connect(function(pos, processedByUI)
		if not processedByUI then
			Combat.ClickAt(pos)
		end
	end)
	-- Moving manually cancels the chase
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local k = input.KeyCode
		if k == Enum.KeyCode.W or k == Enum.KeyCode.A or k == Enum.KeyCode.S or k == Enum.KeyCode.D then
			State.chasing = false
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

-- Mobile attack button: target the nearest monster and attack
function Combat.AttackNearest()
	local r = root()
	if not r then
		return
	end
	if not alive(State.target) then
		Combat.SetTarget(findNearestMob(r.Position, 60))
	end
	State.chasing = State.target ~= nil
end

return Combat
