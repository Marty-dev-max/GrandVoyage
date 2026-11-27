-- GuardService (remake R1, docs/Plan-Movement-Combat-v3.md sec 3-4): Block / Parry / Posture, dash i-frames and
-- fall damage. Every monster blow reaches the player through CombatService.MonsterHit and every PvP hit through
-- hitTarget: both call GS.Check before any damage lands.
--   Block (hold F): blows from the front deal Guard.BlockMult and fill Posture (char attr Posture, drains after a
--     beat); a full gauge = GUARD BREAK (stunned Guard.BreakStun s, the blow lands in full).
--   Parry: a blow landing within ParryWindow (+ ParryGrace) of the F press does nothing and stuns the attacker.
--     Pressing again within ParryCooldown opens no window, so mashing F never parries.
--   Dodge: CombatService's Dash handler calls GS.OnDash; blows inside the i-frames miss ("DODGE").
--   Falls: watched on the server from the replicated root velocity (no client report to trust).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local GS = {}
local R
local G = GameConfig.Guard
local F = GameConfig.Fall
local st = {} -- player -> { on, t0, lastStart, parryOpen, posture, hitAt, brokenUntil, dodgeUntil }

function GS.Init(registry)
	R = registry
end

local function S(player)
	local s = st[player]
	if not s then
		s = { posture = 0, hitAt = 0, lastStart = -99, brokenUntil = 0, dodgeUntil = 0 }
		st[player] = s
	end
	return s
end

local function publish(player, s)
	local char = player.Character
	if char then
		char:SetAttribute("Blocking", s.on or nil)
		char:SetAttribute("Posture", s.posture > 0.5 and math.floor(s.posture + 0.5) or nil)
	end
end

local function fxAt(player, kind)
	local root = R.PlayerService.Root(player)
	if root then
		local at = root.Position + root.CFrame.LookVector * 1.6 + Vector3.new(0, 1.2, 0)
		Net.FX("Guard", { kind = kind, pos = at, char = player.Character }, at, 200)
	end
end

function GS.IsBlocking(player)
	local s = st[player]
	return s ~= nil and s.on == true
end

function GS.OnDash(player)
	local s = S(player)
	s.dodgeUntil = os.clock() + GameConfig.Dodge.IFrames + GameConfig.Dodge.Grace
	if s.on then
		s.on = false
		publish(player, s)
	end
end

-- dmg = what the blow would deal; fromPos = where it comes from (the attacker's root).
-- returns (damage to deal or nil, kind) with kind "dodge" | "parry" | "block" | "break" | nil (nothing guarded)
function GS.Check(player, fromPos, dmg, opts)
	local s = st[player]
	if not s then
		return dmg
	end
	local now = os.clock()
	local root = R.PlayerService.Root(player)
	if now < s.dodgeUntil then
		if root then
			Net.FX("Miss", { pos = root.Position + Vector3.new(0, 3, 0), text = "DODGE" }, root.Position, 150)
		end
		return nil, "dodge"
	end
	if not s.on or now < s.brokenUntil or not root or not fromPos then
		return dmg
	end
	local to = (fromPos - root.Position) * Vector3.new(1, 0, 1)
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if to.Magnitude < 0.1 or look.Magnitude < 0.1 or to.Unit:Dot(look.Unit) < G.FrontDot then
		return dmg -- from the side / behind: the guard does nothing
	end
	if s.parryOpen and now - s.t0 <= G.ParryWindow + G.ParryGrace then
		s.parryOpen = false -- one parry per press
		s.posture = math.max(0, s.posture - G.ParryHeal)
		publish(player, s)
		fxAt(player, "parry")
		return nil, "parry"
	end
	local hum = R.PlayerService.Humanoid(player)
	local maxHp = hum and math.max(1, hum.MaxHealth) or 100
	local k = (opts and opts.boss) and G.PostureBoss or 1
	s.posture += (G.PostureFlat + dmg / maxHp * 100 * G.PostureK) * k
	s.hitAt = now
	if s.posture >= G.PostureMax then
		s.posture = 0
		s.on = false
		s.brokenUntil = now + G.BreakStun
		publish(player, s)
		fxAt(player, "break")
		Net.Push(player, "Stun", { seconds = G.BreakStun })
		Net.Push(player, "GuardBreak", { seconds = G.BreakStun })
		return dmg, "break"
	end
	publish(player, s)
	fxAt(player, "block")
	return math.max(1, math.floor(dmg * G.BlockMult)), "block"
end

-- a fall of `drop` studs: lethal falls knock down (CombatService.DamagePlayer without a killer), DownAt always does
local function fallHit(player, drop)
	local hum = R.PlayerService.Humanoid(player)
	if not hum or hum.Health <= 0 or player.Character:GetAttribute("Invulnerable") then
		return
	end
	local k = math.min(F.Max, (drop - F.Safe) * F.PerStud)
	local dmg = math.max(1, math.floor(hum.MaxHealth * k))
	local root = R.PlayerService.Root(player)
	if root then
		Net.FX("Guard", { kind = "land", pos = root.Position - Vector3.new(0, 2.6, 0), char = player.Character, k = k }, root.Position, 200)
	end
	R.CombatService.DamagePlayer(player, dmg, nil)
	if drop >= F.DownAt and not R.KnockdownService.IsDowned(player) and hum.Health > 0 then
		R.KnockdownService.Down(player)
	end
end

function GS.Start()
	Net.Handle("Guard", function(player, data)
		if type(data) ~= "table" then
			return false
		end
		local s = S(player)
		local now = os.clock()
		if data.on == true then
			local hum = R.PlayerService.Humanoid(player)
			if now < s.brokenUntil or not hum or hum.Health <= 0 or R.KnockdownService.IsDowned(player) then
				return false
			end
			if not s.on then
				s.on = true
				s.t0 = now
				s.parryOpen = now - s.lastStart >= G.ParryCooldown
				s.lastStart = now
			end
		else
			s.on = false
		end
		publish(player, s)
		return true
	end, 0.02)

	Players.PlayerRemoving:Connect(function(player)
		st[player] = nil
	end)

	-- posture drains a beat after the last blocked blow
	task.spawn(function()
		while true do
			local now = os.clock()
			for player, s in pairs(st) do
				if s.posture > 0 and now - s.hitAt > G.DrainDelay then
					s.posture = math.max(0, s.posture - G.PostureDrain * 0.1)
					publish(player, s)
				end
				if s.on and R.KnockdownService.IsDowned(player) then
					s.on = false
					publish(player, s)
				end
			end
			task.wait(0.1)
		end
	end)

	-- falls: a drop starts when the root falls faster than FallVel and ends when it stops; teleports, flight,
	-- seats, swimming, the downed ragdoll and rubber (Bounce) bodies reset it
	local falls = {} -- player -> { peak, minV, last }
	local safeV = math.sqrt(2 * workspace.Gravity * F.Safe) * 0.7
	local SEA = GameConfig.SeaLevel or 0
	RunService.Heartbeat:Connect(function()
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 then
				local f = falls[player]
				local p = root.Position
				if not f or f.char ~= char then
					f = { last = p, char = char }
					falls[player] = f
				end
				if (p - f.last).Magnitude > 60 then
					f.peak = nil -- teleported (fast travel, respawn, summon)
				end
				f.last = p
				local vy = root.AssemblyLinearVelocity.Y
				local state = hum:GetState()
				if char:GetAttribute("Flying") or char:GetAttribute("Downed") or hum.Sit or root.Anchored
					or state == Enum.HumanoidStateType.Swimming or player:GetAttribute("Fruit") == "Bounce" then
					f.peak = nil
				elseif vy < -F.FallVel then
					if not f.peak then
						f.peak, f.minV = p.Y, vy
					end
					f.minV = math.min(f.minV, vy)
				elseif f.peak then
					local drop, impact = f.peak - p.Y, -f.minV
					f.peak = nil
					if drop > F.Safe and impact > safeV and p.Y > SEA + 3 then
						task.spawn(fallHit, player, drop)
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		falls[player] = nil
	end)
end

return GS
