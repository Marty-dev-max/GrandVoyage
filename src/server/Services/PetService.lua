-- PetService: Sea Companions (Config/Pets). Capture, eggs, levels, evolution, the active pet's attacks and bonus.
-- Profile: pets = { { uid, species, level, exp, stage } }, activePet = uid
-- The client draws every player's active pet from the "Pet" attribute ("Species:stage:level"), so nothing moves
-- over the network except attack FX.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Pets = require(Shared.Config.Pets)
local Rarity = require(Shared.Modules.Rarity)
local Formulas = require(Shared.Modules.Formulas)
local Net = require(Shared.Modules.Net)

local PetS = {}
local R
local lastHit = {} -- player -> { mob, t }

local function prof(player)
	local p = R.PlayerService.Profile(player)
	if p then
		p.pets = p.pets or {}
	end
	return p
end

local function findPet(p, uid)
	for i, pet in ipairs(p.pets) do
		if pet.uid == uid then
			return pet, i
		end
	end
	return nil
end
PetS.Find = findPet

local function setAttr(player, p)
	local pet = p.activePet and findPet(p, p.activePet)
	player:SetAttribute("Pet", pet and (pet.species .. ":" .. pet.stage .. ":" .. pet.level) or nil)
end
PetS.SetAttributes = setAttr

local function refresh(player, p)
	setAttr(player, p)
	R.PlayerService.Recompute(player)
	R.PlayerService.MarkDirty(player)
end

function PetS.Add(player, speciesId, how)
	local p = prof(player)
	local sp = Pets.ById[speciesId]
	if not p or not sp then
		return false
	end
	if #p.pets >= Pets.MaxPets then
		R.PlayerService.Notify(player, "Your pet roster is full (" .. Pets.MaxPets .. ")", "bad")
		return false
	end
	local pet = { uid = R.DataService.NewUid(), species = speciesId, level = 1, exp = 0, stage = 1 }
	table.insert(p.pets, pet)
	if not p.activePet then
		p.activePet = pet.uid
	end
	refresh(player, p)
	Net.Push(player, "Banner", { title = "New Companion!", subtitle = sp.icon .. " " .. sp.stages[1] .. "  (" .. how .. ")" })
	if Rarity.Get(sp.rarity).rank >= 5 then
		Net.PushAll("Announce", { text = sp.icon .. " " .. player.DisplayName .. " got a " .. sp.stages[1] .. "!", rarity = sp.rarity })
	end
	return true
end

local function pickWeighted(weights)
	local total = 0
	for _, w in pairs(weights) do
		total += w
	end
	local r = math.random() * total
	for id, w in pairs(weights) do
		r -= w
		if r <= 0 then
			return id
		end
	end
	return next(weights)
end

-- Base EXP earned by the owner also feeds the active pet
function PetS.OnBaseExp(player, base)
	local p = prof(player)
	local pet = p and p.activePet and findPet(p, p.activePet)
	if not pet or pet.level >= Pets.MaxLevel or base <= 0 then
		return
	end
	pet.exp += math.floor(base * Pets.ExpShare)
	local leveled = false
	while pet.level < Pets.MaxLevel and pet.exp >= Pets.ExpToNext(pet.level) do
		pet.exp -= Pets.ExpToNext(pet.level)
		pet.level += 1
		leveled = true
		if pet.level == Pets.EvolveAt[1] or pet.level == Pets.EvolveAt[2] then
			Net.Push(player, "Toast", { text = "Your companion can evolve! (Pets window)", kind = "good" })
		end
	end
	if leveled then
		setAttr(player, p)
	end
	R.PlayerService.MarkDirty(player)
end

function PetS.OnOwnerHit(player, mob)
	lastHit[player] = { mob = mob, t = os.clock() }
end

-- Egg drop from exploration chests
function PetS.RollChestEgg(player, tier)
	local e = Pets.ChestEggs[tier]
	if e and math.random() < e.chance then
		R.InventoryService.AddItem(player, e.egg, 1)
		Net.Push(player, "Loot", { items = { { id = e.egg, qty = 1 } } })
	end
end

function PetS.Init(registry)
	R = registry
end

function PetS.Start()
	Players.PlayerRemoving:Connect(function(pl)
		lastHit[pl] = nil
	end)
	R.DataService.Loaded:Connect(function(player) -- v0.24.0: once a character slot is loaded (title menu)
		task.delay(3, function()
			local p = prof(player)
			if p then
				setAttr(player, p)
			end
		end)
	end)

	-- active pet attacks whatever its owner hit recently
	task.spawn(function()
		while true do
			task.wait(Pets.AttackEvery)
			for player, h in pairs(lastHit) do
				local mob = h.mob
				local p = player.Parent and prof(player)
				local pet = p and p.activePet and findPet(p, p.activePet)
				local root = R.PlayerService.Root(player)
				if not pet or not root or mob.dead or os.clock() - h.t > 6 or (mob.root.Position - root.Position).Magnitude > 45 then
					if mob.dead or os.clock() - h.t > 6 then
						lastHit[player] = nil
					end
				else
					local d = R.PlayerService.Derived(player)
					local atk = d and math.max(d.atk, d.matk) or 10
					local dmg = atk * (Pets.AttackScale.base + Pets.AttackScale.perLevel * pet.level) * (1 + 0.25 * (pet.stage - 1))
					Net.FX("PetHit", { from = root.Position + Vector3.new(2, 3, 2), to = mob.root.Position, species = pet.species }, root.Position, 250)
					R.MonsterService.Damage(mob, math.max(1, dmg), player, false, "pet")
				end
			end
		end
	end)

	Net.Handle("PetSetActive", function(player, data)
		local p = prof(player)
		if data.uid == nil then
			p.activePet = nil
		elseif findPet(p, data.uid) then
			p.activePet = data.uid
		else
			return false, "Pet not found"
		end
		refresh(player, p)
		return true
	end, 0.5)

	Net.Handle("PetEvolve", function(player, data)
		local p = prof(player)
		local pet = findPet(p, data.uid)
		if not pet then
			return false, "Pet not found"
		end
		local sp = Pets.ById[pet.species]
		if pet.stage >= 3 then
			return false, "Already fully evolved"
		end
		if pet.level < Pets.EvolveAt[pet.stage] then
			return false, "Reach Lv." .. Pets.EvolveAt[pet.stage] .. " first"
		end
		local cost = Pets.EvolveCost[pet.stage]
		local beli = math.floor(cost.beli * (Pets.RarityMult[sp.rarity] or 1))
		if R.InventoryService.Count(player, sp.material) < cost.material then
			return false, "Needs " .. cost.material .. "x " .. sp.material
		end
		if not R.PlayerService.AddBeli(player, -beli) then
			return false, "Needs " .. beli .. " Doubloons"
		end
		R.InventoryService.RemoveItem(player, sp.material, cost.material)
		pet.stage += 1
		refresh(player, p)
		local root = R.PlayerService.Root(player)
		if root then
			Net.FX("JobChange", { pos = root.Position, color = sp.color }, root.Position, 300)
		end
		Net.Push(player, "Banner", { title = "Evolution!", subtitle = sp.icon .. " " .. sp.stages[pet.stage] })
		return true
	end, 1)

	Net.Handle("PetRelease", function(player, data)
		local p = prof(player)
		local pet, i = findPet(p, data.uid)
		if not pet then
			return false, "Pet not found"
		end
		if p.activePet == pet.uid then
			return false, "Unsummon it first"
		end
		table.remove(p.pets, i)
		refresh(player, p)
		return true, "Released into the sea"
	end, 0.5)

	Net.Handle("HatchEgg", function(player, data)
		local p = prof(player)
		local entry = Formulas.FindItem(p, data.uid)
		local egg = entry and Pets.Eggs[entry.id]
		if not egg then
			return false, "That is not an egg"
		end
		if #p.pets >= Pets.MaxPets then
			return false, "Your pet roster is full"
		end
		R.InventoryService.RemoveUid(player, entry.uid, 1)
		local species = pickWeighted(egg.weights)
		PetS.Add(player, species, "hatched")
		return true
	end, 1)

	Net.Handle("CapturePet", function(player, data)
		local p = prof(player)
		local mob = R.MonsterService.FromInstance(data.target)
		local root = R.PlayerService.Root(player)
		if not mob or mob.dead or not root then
			return false, "No target"
		end
		local sp = Pets.ByMonster[mob.def.id]
		if not sp then
			return false, "This creature cannot be tamed"
		end
		if (mob.root.Position - root.Position).Magnitude > Pets.Capture.Range then
			return false, "Too far away"
		end
		local ratio = mob.hp / mob.maxHp
		if ratio > Pets.Capture.MaxHpRatio then
			return false, "Weaken it below " .. math.floor(Pets.Capture.MaxHpRatio * 100) .. "% HP first"
		end
		if R.InventoryService.Count(player, Pets.Capture.BaitItem) < 1 then
			return false, "You need Sea Bait (General Store)"
		end
		if #p.pets >= Pets.MaxPets then
			return false, "Your pet roster is full"
		end
		R.InventoryService.RemoveItem(player, Pets.Capture.BaitItem, 1)
		-- lower HP = better odds
		local chance = sp.capture.chance * (1 + (Pets.Capture.MaxHpRatio - ratio) * 3)
		if math.random() < chance then
			R.MonsterService.Remove(mob)
			PetS.Add(player, sp.id, "tamed")
			return true, "Tamed!"
		end
		return false, "It broke free! (" .. math.floor(chance * 100) .. "% chance)"
	end, 0.8)
end

return PetS
