-- MarineService (v0.25.129, owner: docs/Plan-Weapons-v2.md section 0): what being a Marine pays and what it can do.
--   * Salary: every Marine.SalaryEvery seconds online, Marines get Doubloons by rank (Marine titles met by merit).
--   * Seastone cuffs: a Marine wearing Seastone gear brings a Pirate DOWN instead of killing them (CombatService),
--     and any downed Pirate can be cuffed by such a Marine (hold the Arrest prompt) -> the Brig at Conch Bay.
--   * The Brig: a barred cell in the garrison (map part tagged JailCell). Jailed players are held there until
--     p.jailUntil (os.time, saved, so leaving the game does not free you); walking out puts you back.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ItemDB = require(ReplicatedStorage.Shared.Modules.ItemDB)
local Formulas = require(ReplicatedStorage.Shared.Modules.Formulas)
local TitlesCfg = require(ReplicatedStorage.Shared.Config.Titles)

local MS = {}
local R
local CFG = GameConfig.Marine

function MS.Init(registry)
	R = registry
end

-- 0 = no rank yet, then 1.. per Marine title (Recruit, Seaman, ...) the merit reaches
function MS.Rank(p)
	local n = 0
	for _, t in ipairs(TitlesCfg.List) do
		if t.category == "Marine" and t.need.merit and (p.merit or 0) >= t.need.merit then
			n += 1
		end
	end
	return n
end

-- a Marine with any equipped Seastone piece (Items `seastone`) can cuff
function MS.HasSeastone(player)
	local p = R.PlayerService.Profile(player)
	for _, uid in pairs(p and p.equipment or {}) do
		local entry = Formulas.FindItem(p, uid)
		local def = entry and ItemDB.ForEntry(entry)
		if def and def.seastone then
			return true
		end
	end
	return false
end

function MS.CanCuff(marine, victim)
	return marine:GetAttribute("Faction") == "Marine" and victim:GetAttribute("Faction") == "Pirate" and MS.HasSeastone(marine)
end

local function cell()
	local part = CollectionService:GetTagged("JailCell")[1]
	return part and part.Position + Vector3.new(0, 3.5, 0)
end

local function putInCell(player)
	local spot = cell()
	local char = player.Character
	if spot and char and char.PrimaryPart then
		char:PivotTo(CFrame.new(spot))
	end
end

function MS.Jailed(player)
	local p = R.PlayerService.Profile(player)
	return p ~= nil and (p.jailUntil or 0) > os.time()
end

function MS.Jail(victim, marine)
	local p, mp = R.PlayerService.Profile(victim), R.PlayerService.Profile(marine)
	if not p or not mp or MS.Jailed(victim) then
		return
	end
	local seconds = math.floor(math.clamp(CFG.JailBase + (p.bounty or 0) * CFG.JailPerBounty, CFG.JailBase, CFG.JailMax))
	p.jailUntil = os.time() + seconds
	victim:SetAttribute("JailUntil", p.jailUntil)
	R.KnockdownService.StandUp(victim, 0.5)
	putInCell(victim)
	local reward = math.floor((p.bounty or 0) * CFG.ArrestBountyShare)
	mp.merit = (mp.merit or 0) + CFG.ArrestMerit
	R.PlayerService.AddBeli(marine, reward)
	R.PlayerService.MarkDirty(victim)
	R.PlayerService.MarkDirty(marine)
	R.PlayerService.Notify(marine, string.format("Pirate captured! +%d Merit, %d Doubloons", CFG.ArrestMerit, reward), "good")
	R.PlayerService.Notify(victim, string.format("Cuffed with Seastone! The Brig holds you for %ds", seconds), "bad")
	Net.PushAll("Announce", { text = "⛓️ " .. marine.DisplayName .. " threw pirate " .. victim.DisplayName .. " into the Conch Bay Brig!", kind = "info" })
end

-- called by KnockdownService.Down: a downed Pirate gets an Arrest prompt only Marines see (Interact hides it for others)
function MS.OnDowned(player, root)
	if player:GetAttribute("Faction") ~= "Pirate" then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ArrestPrompt"
	prompt.ActionText = "Cuff (Seastone)"
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = CFG.CuffHold
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt:SetAttribute("OnlyFaction", "Marine")
	prompt.Parent = root
	prompt.Triggered:Connect(function(marine)
		if marine == player or not R.KnockdownService.IsDowned(player) then
			return
		end
		if not MS.CanCuff(marine, player) then
			R.PlayerService.Notify(marine, "You need Seastone gear equipped to cuff a pirate", "bad")
			return
		end
		prompt:Destroy()
		MS.Jail(player, marine)
	end)
	local char = player.Character
	local conn
	conn = char:GetAttributeChangedSignal("Downed"):Connect(function()
		if char:GetAttribute("Downed") == nil then
			conn:Disconnect()
			if prompt.Parent then
				prompt:Destroy()
			end
		end
	end)
end

function MS.Start()
	-- Salary (only while online and a Marine)
	task.spawn(function()
		while true do
			task.wait(CFG.SalaryEvery)
			for _, pl in ipairs(Players:GetPlayers()) do
				local p = R.PlayerService.Profile(pl)
				if p and p.faction == "Marine" then
					local pay = CFG.Salary[math.min(MS.Rank(p) + 1, #CFG.Salary)]
					R.PlayerService.AddBeli(pl, pay)
					R.PlayerService.Notify(pl, "⚓ Marine salary: +" .. pay .. " Doubloons", "good")
				end
			end
		end
	end)
	-- the Brig keeps its prisoners (also across respawns and rejoins)
	local function watch(pl)
		pl.CharacterAdded:Connect(function()
			task.wait(1)
			if MS.Jailed(pl) then
				putInCell(pl)
			end
		end)
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		watch(pl)
	end
	Players.PlayerAdded:Connect(watch)
	R.DataService.Loaded:Connect(function(pl)
		local p = R.PlayerService.Profile(pl)
		pl:SetAttribute("JailUntil", p and p.jailUntil or nil)
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local spot = cell()
			for _, pl in ipairs(Players:GetPlayers()) do
				local p = R.PlayerService.Profile(pl)
				local root = R.PlayerService.Root(pl)
				if p and p.jailUntil and root and spot then
					if p.jailUntil > os.time() then
						if (root.Position - spot).Magnitude > 9 then
							putInCell(pl)
						end
					else
						p.jailUntil = nil
						pl:SetAttribute("JailUntil", nil)
						R.PlayerService.MarkDirty(pl)
						local part = CollectionService:GetTagged("JailCell")[1]
						pl.Character:PivotTo(part.CFrame * CFrame.new(0, 3.5, 10)) -- out in front of the bars (gate side)
						R.PlayerService.Notify(pl, "You served your time. You are free.", "good")
					end
				end
			end
		end
	end)
end

return MS
