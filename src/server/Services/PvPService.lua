-- PvPService: who can fight whom, duels, arena, Bounty and Merit
-- Fights allowed when: (1) dueling (2) both in the Epilogue arena (3) Guild War inside a fort, different guilds
-- Ships: Marines vs Pirates can always fire on each other at sea (Lv >= PvPMinLevel)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Islands = require(Shared.Config.Islands)
local Net = require(Shared.Modules.Net)

local PvP = {}
local R
local duels = {} -- player -> opponent
local duelInvites = {} -- target -> { from, expires }
local arena

function PvP.Init(registry)
	R = registry
	local logue = Islands.ById.Epilogue
	arena = { center = Vector3.new(logue.x + logue.arena.offset.X, 0, logue.arena.offset.Y), radius = logue.arena.radius }
end

local function flatDist(a, b)
	return (Vector2.new(a.X, a.Z) - Vector2.new(b.X, b.Z)).Magnitude
end

function PvP.InArena(player)
	local root = R.PlayerService.Root(player)
	return root ~= nil and flatDist(root.Position, arena.center) <= arena.radius
end

function PvP.CanFight(a, b)
	if a == b then
		return false
	end
	if R.PartyService.Same(a, b) then
		return false
	end
	if duels[a] == b then
		return true
	end
	if PvP.InArena(a) and PvP.InArena(b) then
		return true
	end
	if R.GuildWarService.CanFight(a, b) then
		return true
	end
	return false
end

-- Player ship vs player ship
function PvP.ShipsHostile(ownerA, ownerB)
	if not ownerA or not ownerB or ownerA == ownerB then
		return false
	end
	if R.PartyService.Same(ownerA, ownerB) then
		return false
	end
	local fa, fb = ownerA:GetAttribute("Faction"), ownerB:GetAttribute("Faction")
	local la, lb = ownerA:GetAttribute("Level") or 1, ownerB:GetAttribute("Level") or 1
	if la < GameConfig.PvPMinLevel or lb < GameConfig.PvPMinLevel then
		return false
	end
	return (fa == "Marine" and fb == "Pirate") or (fa == "Pirate" and fb == "Marine")
end

local function endDuel(a, winner)
	local b = duels[a]
	duels[a] = nil
	if b then
		duels[b] = nil
	end
	if winner then
		Net.PushAll("Announce", { text = "⚔️ " .. winner.DisplayName .. " won the duel!" })
	end
end

-- Pirates beating Marines gain Bounty; Marines catching Pirates gain Merit + a cut of the bounty
function PvP.OnPlayerKilled(victim, killer)
	if duels[victim] == killer then
		endDuel(victim, killer)
		local hum = R.PlayerService.Humanoid(victim)
		if hum then
			hum.Health = 1 -- duels are non-lethal
		end
		return
	end
	local kp, vp = R.DataService.Get(killer), R.DataService.Get(victim)
	if not kp or not vp then
		return
	end
	if kp.faction == "Pirate" and vp.faction == "Marine" then
		kp.bounty += 50000 + vp.baseLevel * 2000
		R.PlayerService.Notify(killer, "Your bounty rose to 🪙" .. kp.bounty .. "!", "good")
	elseif kp.faction == "Marine" and vp.faction == "Pirate" then
		kp.merit += 10
		local reward = math.floor(vp.bounty * 0.05)
		R.PlayerService.AddBeli(killer, reward)
		R.PlayerService.Notify(killer, "Pirate apprehended! +10 Merit, 🪙" .. reward, "good")
	end
	R.PlayerService.MarkDirty(killer)
end

function PvP.OnMobKilled(player, def)
	local p = R.DataService.Get(player)
	if not p then
		return
	end
	if def.isBoss then
		if p.faction == "Pirate" then
			p.bounty += def.level * 5000
		elseif p.faction == "Marine" then
			p.merit += math.floor(def.level / 5)
		end
	end
end

function PvP.OnShipSunk(player, npcDef)
	local p = R.DataService.Get(player)
	if not p or not npcDef then
		return
	end
	if p.faction == "Pirate" and npcDef.faction == "Marine" then
		p.bounty += npcDef.tier * 30000
	elseif p.faction == "Marine" and npcDef.faction == "Pirate" then
		p.merit += npcDef.tier * 3
	end
	R.PlayerService.MarkDirty(player)
end

function PvP.Start()
	Net.Handle("DuelRequest", function(player, data)
		local target = Players:GetPlayerByUserId(tonumber(data.userId) or 0)
		if not target or target == player or duels[target] or duels[player] then
			return false, "Cannot duel right now"
		end
		duelInvites[target] = { from = player, expires = os.clock() + 20 }
		Net.Push(target, "Prompt", { kind = "Duel", text = player.DisplayName .. " challenges you to a duel!", from = player.UserId })
		return true, "Challenge sent"
	end, 2)

	Net.Handle("DuelRespond", function(player, data)
		local inv = duelInvites[player]
		duelInvites[player] = nil
		if not inv or os.clock() > inv.expires or not inv.from.Parent then
			return false, "Challenge expired"
		end
		if not data.accept then
			return true
		end
		duels[player] = inv.from
		duels[inv.from] = player
		for _, pl in ipairs({ player, inv.from }) do
			Net.Push(pl, "Toast", { text = "Duel start! 3..2..1", kind = "pvp" })
		end
		task.delay(120, function()
			if duels[player] == inv.from then
				endDuel(player, nil)
			end
		end)
		return true
	end, 0.5)

	Players.PlayerRemoving:Connect(function(pl)
		if duels[pl] then
			endDuel(pl, duels[pl])
		end
		duelInvites[pl] = nil
	end)
end

return PvP
