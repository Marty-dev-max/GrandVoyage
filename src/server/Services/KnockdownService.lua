-- Knockdown (v0.25.14, owner): lethal MONSTER damage does not kill at once. The player collapses (character
-- attribute Downed = time it happened) and bleeds out over Knockdown.BleedSeconds. A monster that attacks a downed
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

local function standUp(player, hpRatio)
	local char = player.Character
	local hum = R.PlayerService.Humanoid(player)
	local root = R.PlayerService.Root(player)
	if not char or not hum or not root then
		return
	end
	char:SetAttribute("Downed", nil)
	hum.PlatformStand = false
	hum.Health = math.max(1, hum.MaxHealth * hpRatio)
	root.CFrame = CFrame.new(root.Position + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, select(2, root.CFrame:ToEulerAnglesYXZ()), 0)
	local prompt = root:FindFirstChild("RevivePrompt")
	if prompt then
		prompt:Destroy()
	end
	Net.Push(player, "Downed", { downed = false })
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
	hum.PlatformStand = true -- collapses on the ground
	root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, select(2, root.CFrame:ToEulerAnglesYXZ()), 0) * CFrame.Angles(math.rad(-85), 0, 0)
	R.CombatService.ClearBuffs(player)
	Net.FX("Miss", { pos = root.Position + Vector3.new(0, 3, 0), text = "DOWNED!" }, root.Position, 250)
	Net.Push(player, "Downed", { downed = true, seconds = CFG.BleedSeconds })
	-- any other player can hold E / tap to revive
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RevivePrompt"
	prompt.ActionText = "Revive"
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = CFG.ReviveHold
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(helper)
		if helper ~= player and KD.IsDowned(player) and R.PlayerService.Humanoid(helper) and R.PlayerService.Humanoid(helper).Health > 0 and not KD.IsDowned(helper) then
			standUp(player, CFG.ReviveHp)
			R.PlayerService.Notify(player, helper.DisplayName .. " revived you!", "good")
			R.PlayerService.Notify(helper, "You revived " .. player.DisplayName .. "!", "good")
		end
	end)
	task.delay(CFG.BleedSeconds, function()
		if char.Parent and char:GetAttribute("Downed") == stamp then
			kill(player, "BLED OUT")
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
