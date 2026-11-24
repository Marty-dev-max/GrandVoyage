-- RecruitService (v0.25.142, owner): sailors hang around every Tavern Keeper (inside the Daybreak tavern, by the
-- harbor elsewhere). Talk to one ("Talk" prompt -> push OpenPanel Recruit) to see who they are, what they do and what
-- they want; give it (`RecruitCrew` { key }) and they join: p.recruits (saved) + p.crew. They then stand at their
-- post on your ship (ShipService.addRecruits) and help (Config/Recruits Bonus: reload, speed, hull repair, healing).
-- The sailors at a tavern change every Recruits.Rotate seconds. Models are anchored at their spot on the server; the
-- client (Controllers/RecruitLife) walks them around it.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Recruits = require(ReplicatedStorage.Shared.Config.Recruits)
local ShipStats = require(ReplicatedStorage.Shared.Modules.ShipStats)
local ItemDB = require(ReplicatedStorage.Shared.Modules.ItemDB)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local VoxelChar = require(ReplicatedStorage.Shared.Modules.VoxelChar)
local ModelFactory = require(script.Parent.Parent.World.ModelFactory)
local Formulas = require(ReplicatedStorage.Shared.Modules.Formulas)

local RS = {}
local R
local taverns = {} -- { key, cf, folder, list = { [slot] = { c, model, home } } }
local rotation = -1

-- spots around the keeper, in the keeper's space (-Z = the way the keeper faces): outside its 7-stud walk-in ring,
-- v0.25.148 spread so the sailors (and their tags) never bunch up
local SPOTS = { Vector3.new(-9, 0, -6), Vector3.new(9, 0, -6), Vector3.new(-5, 0, -14), Vector3.new(5, 0, -14) }
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

function RS.Init(registry)
	R = registry
end

local function keyOf(t, slot)
	return t.key .. "#" .. slot .. "#" .. rotation
end

local function public(t, slot, player)
	local e = t.list[slot]
	local c = e.c
	local p = R.DataService.Get(player)
	local have = false
	for _, r in ipairs(p and p.recruits or {}) do
		if r.seed == c.seed then
			have = true
		end
	end
	return {
		key = keyOf(t, slot), seed = c.seed, name = c.name, race = c.race, variant = c.variant, prof = c.prof,
		stars = c.stars, skill = c.skill, trait = c.trait, want = c.want, line = c.line, have = have, model = e.model,
	}
end

local function buildModel(t, slot, c)
	local m = VoxelChar.Preview(Recruits.Look(c), c.race, c.variant, nil, { lite = true })
	m.Name = c.name
	local root = m.PrimaryPart
	root.Name = "HumanoidRootPart"
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p:SetAttribute("NoVoxel", true)
		end
	end
	local home = t.cf * CFrame.new(SPOTS[slot])
	-- v0.25.148 (owner: they floated): stand the feet on the floor under the spot (the keeper's pivot is not the floor)
	local bbCF, bbSize = m:GetBoundingBox()
	local footDrop = root.Position.Y - (bbCF.Position.Y - bbSize.Y / 2) -- root height above the soles
	local ignore = { t.folder }
	for _, n in ipairs(CollectionService:GetTagged("NPC")) do
		table.insert(ignore, n)
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then
			table.insert(ignore, pl.Character)
		end
	end
	groundParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(home.Position + Vector3.new(0, 3, 0), Vector3.new(0, -14, 0), groundParams)
	if hit then
		home = CFrame.new(home.Position.X, hit.Position.Y + footDrop, home.Position.Z) * home.Rotation
	end
	m:PivotTo(home * CFrame.Angles(0, math.rad((slot * 77) % 360), 0))
	m:SetAttribute("RecruitKey", keyOf(t, slot))
	m:SetAttribute("Home", home.Position)
	local prof = Recruits.Professions[c.prof]
	local tier = Recruits.Tier(c)
	local bb = ModelFactory.Billboard(root, c.name, prof.icon .. " " .. prof.name .. "  " .. string.rep("*", c.stars), tier.color, 5.2)
	-- sized in studs (shrinks with distance) and only near: fixed-pixel tags piled on top of each other
	bb.Size = UDim2.new(6, 0, 1.6, 0)
	bb.MaxDistance = 45
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = c.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		if t.list[slot] and t.list[slot].c == c then
			Net.Push(player, "OpenPanel", { name = "Recruit", args = public(t, slot, player) })
		end
	end)
	CollectionService:AddTag(m, "Recruit")
	m.Parent = t.folder
	return m, home
end

local function refresh()
	local rot = math.floor(os.time() / Recruits.Rotate)
	if rot == rotation then
		return
	end
	rotation = rot
	for _, t in ipairs(taverns) do
		for _, e in pairs(t.list) do
			e.model:Destroy()
		end
		t.list = {}
		for slot = 1, math.min(Recruits.PerTavern, #SPOTS) do
			local c = Recruits.Candidate(Recruits.Seed(t.key, slot, rot))
			local ok, model, home = pcall(buildModel, t, slot, c)
			if ok then
				t.list[slot] = { c = c, model = model, home = home }
			else
				warn("[RecruitService]", model)
			end
		end
	end
end

local function findCandidate(key)
	for _, t in ipairs(taverns) do
		for slot, e in pairs(t.list) do
			if keyOf(t, slot) == key then
				return e, t, slot
			end
		end
	end
end

-- one tick per second: Carpenters patch your ship, Cooks heal everyone aboard it
local function crewTick()
	for _, player in ipairs(Players:GetPlayers()) do
		local p = R.DataService.Get(player)
		if p and p.recruits and #p.recruits > 0 then
			local b = Recruits.Bonus(p.recruits)
			local ship = R.ShipService.GetShipOf(player)
			if ship and not ship.sinking and ship.root then
				if b.repair > 0 and ship.hp and ship.maxHp and ship.hp < ship.maxHp then
					R.ShipService.Patch(ship, ship.maxHp * b.repair)
				end
				if b.heal > 0 then
					for _, other in ipairs(Players:GetPlayers()) do
						local hum = R.PlayerService.Humanoid(other)
						local root = R.PlayerService.Root(other)
						if hum and root and hum.Health > 0 and hum.Health < hum.MaxHealth and not (hum.Parent and hum.Parent:GetAttribute("Downed")) then
							local d = root.Position - ship.root.Position
							if Vector2.new(d.X, d.Z).Magnitude <= (ship.radius or 20) + 4 and math.abs(d.Y) < 25 then
								hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * b.heal)
							end
						end
					end
				end
			end
		end
	end
end

function RS.Start()
	local folder = Instance.new("Folder")
	folder.Name = "Recruits"
	folder.Parent = workspace
	for _, m in ipairs(CollectionService:GetTagged("NPC")) do
		if m:GetAttribute("Role") == "Tavern" and m.PrimaryPart then
			local cf = m:GetPivot()
			-- stable key from the island + rounded spot (the same keeper keeps the same sailors pattern per rotation)
			local key = tostring(m:GetAttribute("Island")) .. "@" .. math.floor(cf.Position.X) .. "," .. math.floor(cf.Position.Z)
			table.insert(taverns, { key = key, cf = cf, folder = folder, list = {} })
		end
	end
	refresh()
	task.spawn(function()
		while true do
			task.wait(1)
			pcall(refresh)
			pcall(crewTick)
		end
	end)

	Net.Handle("RecruitCrew", function(player, data)
		local p = R.DataService.Get(player)
		if type(data) ~= "table" or type(data.key) ~= "string" then
			return false
		end
		local e = findCandidate(data.key)
		if not e then
			return false, "They already left the tavern"
		end
		local root = R.PlayerService.Root(player)
		if not root or (root.Position - e.home.Position).Magnitude > Recruits.TalkRange then
			return false, "Walk over and talk to them"
		end
		local c = e.c
		p.recruits = p.recruits or {}
		for _, r in ipairs(p.recruits) do
			if r.seed == c.seed then
				return false, c.name .. " already sails with you"
			end
		end
		local design = p.ships[p.activeShip] or p.ships[1]
		local st = ShipStats.Compute(design, p.crew)
		if p.crew + 1 > st.crewCap then
			return false, "No bunk for them (max " .. st.crewCap .. "). Build more Crew Cabins or dismiss someone."
		end
		local w = c.want
		if w.kind == "coin" then
			if not R.PlayerService.AddBeli(player, -w.amount) then
				return false, c.name .. " wants 🪙" .. w.amount
			end
		else
			local def = ItemDB.Get(w.id)
			if not R.InventoryService.RemoveItem(player, w.id, w.qty) then
				return false, c.name .. " wants " .. w.qty .. "x " .. (def and def.name or w.id)
			end
		end
		table.insert(p.recruits, Recruits.Record(c))
		p.crew += 1
		player:SetAttribute("Crew", p.crew)
		R.PlayerService.MarkDirty(player)
		return true, c.name .. " joined your crew!"
	end, 0.5)

	Net.Handle("DismissRecruit", function(player, data)
		local p = R.DataService.Get(player)
		local seed = type(data) == "table" and tonumber(data.seed)
		-- an old unnamed deckhand (saves from before recruiting) frees a bunk too
		if type(data) == "table" and data.deckhand == true and p.crew > #(p.recruits or {}) then
			p.crew -= 1
			player:SetAttribute("Crew", p.crew)
			R.PlayerService.MarkDirty(player)
			return true, "A deckhand left your crew"
		end
		for i, r in ipairs(p.recruits or {}) do
			if r.seed == seed then
				table.remove(p.recruits, i)
				p.crew = math.max(0, p.crew - 1)
				player:SetAttribute("Crew", p.crew)
				R.PlayerService.MarkDirty(player)
				return true, r.name .. " left your crew"
			end
		end
		return false
	end, 0.5)

	-- v0.25.148 (owner: players trade crew): a recruit leaves the crew as a Crew Contract item (entry.recruit), which
	-- moves like any gear (stalls, Gem stalls with the usual trade lock); signing it puts them in the signer's crew
	Net.Handle("MakeContract", function(player, data)
		local p = R.DataService.Get(player)
		local seed = type(data) == "table" and tonumber(data.seed)
		for i, r in ipairs(p.recruits or {}) do
			if r.seed == seed then
				if #p.inventory >= GameConfig.InventorySlots then
					return false, "Your bag is full"
				end
				if not R.InventoryService.AddItem(player, "CrewContract", 1) then
					return false, "Your bag is full"
				end
				p.inventory[#p.inventory].recruit = table.clone(r)
				table.remove(p.recruits, i)
				p.crew = math.max(0, p.crew - 1)
				player:SetAttribute("Crew", p.crew)
				R.PlayerService.MarkDirty(player)
				return true, r.name .. "'s contract is in your bag"
			end
		end
		return false
	end, 0.5)

	Net.Handle("SignContract", function(player, data)
		local p = R.DataService.Get(player)
		local entry = type(data) == "table" and Formulas.FindItem(p, data.uid)
		local r = entry and entry.id == "CrewContract" and entry.recruit
		if not Recruits.ValidRecord(r) then
			return false, "That contract is blank"
		end
		p.recruits = p.recruits or {}
		for _, o in ipairs(p.recruits) do
			if o.seed == r.seed then
				return false, r.name .. " already sails with you"
			end
		end
		local design = p.ships[p.activeShip] or p.ships[1]
		local st = ShipStats.Compute(design, p.crew)
		if p.crew + 1 > st.crewCap then
			return false, "No bunk for them (max " .. st.crewCap .. "). Build more Crew Cabins or dismiss someone."
		end
		for idx, e in ipairs(p.inventory) do
			if e == entry then
				table.remove(p.inventory, idx)
				break
			end
		end
		table.insert(p.recruits, Recruits.Record(r))
		p.crew += 1
		player:SetAttribute("Crew", p.crew)
		R.PlayerService.MarkDirty(player)
		return true, r.name .. " joined your crew!"
	end, 0.5)
end

return RS
