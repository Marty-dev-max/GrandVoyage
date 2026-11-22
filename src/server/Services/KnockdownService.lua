-- Knockdown (v0.25.14, owner): lethal MONSTER damage does not kill at once. The player collapses into a ragdoll
-- (character attribute Downed = time it happened; v0.25.25: HP creeps back and they get up by themselves at
-- Knockdown.StandAt of max HP, Knockdown.RecoverSeconds after going down). A monster that attacks a downed
-- player winds up an EXECUTE (red circle) and kills them when it lands. Another player hitting that monster during
-- the wind-up interrupts it (the monster turns on them); any other player can hold the Revive prompt to bring the
-- downed player back. Alone, nobody breaks the execute: you die. PvP kills keep the old rules (duels, bounties).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local KD = {}
local R
local CFG = GameConfig.Knockdown

function KD.Init(registry)
	R = registry
end

function KD.IsDowned(player)
	local char = player.Character
	return char ~= nil and char:GetAttribute("Downed") ~= nil
end

local function kill(player, text)
	local hum = R.PlayerService.Humanoid(player)
	local root = R.PlayerService.Root(player)
	if hum and hum.Health > 0 then
		if root and text then
			Net.FX("Miss", { pos = root.Position + Vector3.new(0, 3, 0), text = text }, root.Position, 200)
		end
		hum.Health = 0
	end
end

-- ragdoll: every body joint but the root swaps its Motor6D for a ball socket (the client puts the humanoid in the
-- Physics state, it owns the character's physics). Undone by unragdoll.
local function ragdoll(char, hum)
	hum.RequiresNeck = false
	hum.BreakJointsOnDeath = false
	for _, m in ipairs(char:GetDescendants()) do
		if m:IsA("Motor6D") and m.Name ~= "Root" and m.Name ~= "RootJoint" and m.Part0 and m.Part1 and m.Part0.Parent == char and m.Part1.Parent == char then
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Name, a1.Name = "RagA0", "RagA1"
			a0.CFrame, a1.CFrame = m.C0, m.C1
			a0.Parent, a1.Parent = m.Part0, m.Part1
			local bs = Instance.new("BallSocketConstraint")
			bs.Name = "RagSocket"
			bs.Attachment0, bs.Attachment1 = a0, a1
			bs.LimitsEnabled = true
			bs.UpperAngle = 70
			bs.TwistLimitsEnabled = true
			bs.TwistLowerAngle, bs.TwistUpperAngle = -40, 40
			bs.Parent = m.Part0
			m.Enabled = false
		end
	end
end

local function unragdoll(char, hum)
	for _, o in ipairs(char:GetDescendants()) do
		if o:IsA("Motor6D") then
			o.Enabled = true
		elseif o.Name == "RagSocket" or o.Name == "RagA0" or o.Name == "RagA1" then
			o:Destroy()
		end
	end
	hum.RequiresNeck = true
end

local function standUp(player, hpRatio)
	local char = player.Character
	local hum = R.PlayerService.Humanoid(player)
	local root = R.PlayerService.Root(player)
	if not char or not hum or not root then
		return
	end
	char:SetAttribute("Downed", nil)
	unragdoll(char, hum)
	hum.PlatformStand = false
	hum.Health = math.max(hum.Health, hum.MaxHealth * hpRatio)
	root.CFrame = CFrame.new(root.Position + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, select(2, root.CFrame:ToEulerAnglesYXZ()), 0)
	local prompt = root:FindFirstChild("RevivePrompt")
	if prompt then
		prompt:Destroy()
	end
	Net.Push(player, "Downed", { downed = false })
end

-- WILL POWER (v0.25.33, owner): the downed player's own try at getting up, LUK raises it
function KD.WillChance(player)
	local d = R.PlayerService.Derived(player)
	local luk = d and d.LUK or 0
	return math.min(CFG.WillMax, CFG.WillBase + luk * CFG.WillPerLuk)
end

-- called by CombatService.DamagePlayer when a monster hit would bring HP to 0
function KD.Down(player)
	local char = player.Character
	local hum = R.PlayerService.Humanoid(player)
	local root = R.PlayerService.Root(player)
	if not char or not hum or not root or KD.IsDowned(player) then
		return
	end
	local stamp = os.clock()
	char:SetAttribute("Downed", stamp)
	hum.Health = 1
	ragdoll(char, hum)
	R.CombatService.ClearBuffs(player)
	Net.FX("Miss", { pos = root.Position + Vector3.new(0, 3, 0), text = "DOWNED!" }, root.Position, 250)
	Net.Push(player, "Downed", { downed = true, seconds = CFG.RecoverSeconds })
	-- any other player can hold E / tap to revive
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RevivePrompt"
	prompt.ActionText = "Revive"
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = CFG.ReviveHold
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Will", KD.WillChance(player)) -- the downed player's own card shows it (Interact)
	prompt.Parent = root
	prompt.Triggered:Connect(function(helper)
		if helper == player then
			-- one try per knockdown
			if not KD.IsDowned(player) or char:GetAttribute("WillTried") == stamp then
				return
			end
			char:SetAttribute("WillTried", stamp)
			local chance = KD.WillChance(player)
			if math.random() < chance then
				standUp(player, CFG.WillHp)
				Net.FX("Miss", { pos = root.Position + Vector3.new(0, 3, 0), text = "WILL POWER!" }, root.Position, 250)
				R.PlayerService.Notify(player, "Will power! You got back up.", "good")
			else
				R.PlayerService.Notify(player, string.format("Not enough strength... (%d%%)", math.floor(chance * 100 + 0.5)), "bad")
			end
			return
		end
		if helper ~= player and KD.IsDowned(player) and R.PlayerService.Humanoid(helper) and R.PlayerService.Humanoid(helper).Health > 0 and not KD.IsDowned(helper) then
			standUp(player, CFG.ReviveHp)
			R.PlayerService.Notify(player, helper.DisplayName .. " revived you!", "good")
			R.PlayerService.Notify(helper, "You revived " .. player.DisplayName .. "!", "good")
		end
	end)
	-- HP creeps back; at StandAt of max HP they get up on their own
	task.spawn(function()
		local goal = hum.MaxHealth * CFG.StandAt
		local perTick = (goal - 1) / CFG.RecoverSeconds * 0.5
		while char.Parent and char:GetAttribute("Downed") == stamp and hum.Health > 0 do
			task.wait(0.5)
			if char:GetAttribute("Downed") ~= stamp or hum.Health <= 0 then
				return
			end
			hum.Health = math.min(goal, hum.Health + perTick)
			if hum.Health >= goal - 0.01 then
				standUp(player, CFG.StandAt)
				R.PlayerService.Notify(player, "You got back up!", "good")
				return
			end
		end
	end)
end

-- a monster attacking a downed player: wind up the execute instead of a normal hit
function KD.TryExecute(mob, player)
	if mob.executing or mob.dead then
		return
	end
	local root = R.PlayerService.Root(player)
	if not root then
		return
	end
	local token = {}
	mob.executing = { player = player, token = token }
	local pos = root.Position - Vector3.new(0, 2.5, 0)
	Net.FX("MobAlert", { model = mob.model }, mob.root.Position, 250)
	Net.FX("Telegraph", { kind = "circle", pos = pos, radius = 6, time = CFG.ExecuteWindup }, pos, 300)
	R.PlayerService.Notify(player, "A monster is about to EXECUTE you! An ally can stop it.", "bad")
	task.delay(CFG.ExecuteWindup, function()
		if mob.executing and mob.executing.token == token then
			mob.executing = nil
			if not mob.dead and KD.IsDowned(player) and (mob.root.Position - root.Position).Magnitude < 16 then
				Net.Push(player, "Executed", { by = mob.def.name, level = mob.def.level })
				kill(player, "EXECUTED")
			end
		end
	end)
end

-- MonsterService.Damage: someone else's hit breaks the execute and pulls the monster onto them
function KD.OnMobHit(mob, attacker)
	local ex = mob.executing
	if not ex or not attacker or attacker == ex.player then
		return
	end
	mob.executing = nil
	Net.FX("Miss", { pos = mob.root.Position + Vector3.new(0, 5, 0), text = "INTERRUPTED!" }, mob.root.Position, 250)
	local aroot = R.PlayerService.Root(attacker)
	if aroot then
		R.MonsterService.Knockback(mob, aroot.Position, 6, 1.5)
	end
	mob.target = nil
	R.MonsterService.Provoke(mob, attacker)
end

function KD.Start()
	Net.Handle("GiveUp", function(player)
		if not KD.IsDowned(player) then
			return false
		end
		kill(player, nil)
		return true
	end, 1)
end

return KD
