-- PartyService: parties of up to 6, even-share EXP with a per-member bonus
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Net)

local Party = {}
local R
local parties = {} -- id -> { id, leader, members = {player} }
local partyOf = {} -- player -> party
local invites = {} -- player -> { from, partyId, expires }
local nextId = 0
local MAX = 6
local SHARE_RANGE = 120

function Party.Init(registry)
	R = registry
end

local function push(party)
	local list = {}
	for _, m in ipairs(party.members) do
		table.insert(list, { userId = m.UserId, name = m.DisplayName, leader = m == party.leader })
	end
	for _, m in ipairs(party.members) do
		Net.Push(m, "Party", { members = list })
		m:SetAttribute("PartyId", party.id)
	end
end

function Party.Members(player)
	local p = partyOf[player]
	return p and p.members or { player }
end

function Party.Same(a, b)
	return partyOf[a] ~= nil and partyOf[a] == partyOf[b]
end

function Party.Leave(player)
	local p = partyOf[player]
	if not p then
		return
	end
	partyOf[player] = nil
	player:SetAttribute("PartyId", nil)
	Net.Push(player, "Party", { members = {} })
	local idx = table.find(p.members, player)
	if idx then
		table.remove(p.members, idx)
	end
	if #p.members <= 1 then
		for _, m in ipairs(p.members) do
			partyOf[m] = nil
			m:SetAttribute("PartyId", nil)
			Net.Push(m, "Party", { members = {} })
		end
		parties[p.id] = nil
	else
		if p.leader == player then
			p.leader = p.members[1]
		end
		push(p)
	end
end

-- v0.25.108 (crews): put `player` (not in a party) into `mate`'s party, making one if needed; false when full
function Party.Join(player, mate)
	if partyOf[player] or not mate.Parent then
		return false
	end
	local p = partyOf[mate]
	if p and #p.members >= MAX then
		return false
	end
	if not p then
		nextId += 1
		p = { id = nextId, leader = mate, members = { mate } }
		parties[p.id] = p
		partyOf[mate] = p
	end
	table.insert(p.members, player)
	partyOf[player] = p
	push(p)
	return true
end

-- Share EXP with nearby party members
function Party.ShareExp(player, base, job, pos)
	local p = partyOf[player]
	if not p then
		R.PlayerService.GiveExp(player, base, job, pos)
		return
	end
	local near = {}
	for _, m in ipairs(p.members) do
		local root = R.PlayerService.Root(m)
		if root and (root.Position - pos).Magnitude <= SHARE_RANGE then
			table.insert(near, m)
		end
	end
	if #near == 0 then
		near = { player }
	end
	local bonus = 1 + 0.1 * (#near - 1)
	for _, m in ipairs(near) do
		R.PlayerService.GiveExp(m, base * bonus / #near, job * bonus / #near, pos)
	end
end

function Party.Start()
	Net.Handle("PartyInvite", function(player, data)
		local target = Players:GetPlayerByUserId(tonumber(data.userId) or 0)
		if not target or target == player then
			return false, "Player not found"
		end
		if partyOf[target] then
			return false, "That player is already in a party"
		end
		local p = partyOf[player]
		if p and #p.members >= MAX then
			return false, "Party is full"
		end
		invites[target] = { from = player, expires = os.clock() + 30 }
		Net.Push(target, "Prompt", { kind = "PartyInvite", text = player.DisplayName .. " invited you to a party", from = player.UserId })
		return true, "Invite sent"
	end, 1)

	Net.Handle("PartyRespond", function(player, data)
		local inv = invites[player]
		invites[player] = nil
		if not inv or os.clock() > inv.expires or not inv.from.Parent then
			return false, "Invite expired"
		end
		if not data.accept then
			return true
		end
		local leader = inv.from
		local p = partyOf[leader]
		if not p then
			nextId += 1
			p = { id = nextId, leader = leader, members = { leader } }
			parties[p.id] = p
			partyOf[leader] = p
		end
		if #p.members >= MAX then
			return false, "Party is full"
		end
		Party.Leave(player)
		table.insert(p.members, player)
		partyOf[player] = p
		push(p)
		return true, "Joined the party"
	end, 0.5)

	Net.Handle("PartyLeave", function(player)
		Party.Leave(player)
		return true
	end, 0.5)
end

return Party
