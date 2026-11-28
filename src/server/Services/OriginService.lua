-- OriginService (remake R2, Config/Origins): the Origin + starting weapon picked when a character is created.
-- Apply() writes them into a slot's save (title menu, before the game loads), SpawnCFrame() is the Origin's start
-- spot on its island, Mult() feeds the Origin perks into rewards and damage.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Origins = require(Shared.Config.Origins)
local MonsterLooks = require(Shared.Config.MonsterLooks)
local Quests = require(Shared.Config.Quests)
local ItemDB = require(Shared.Modules.ItemDB)

local O = {}
local R

function O.Init(registry)
	R = registry
end

function O.Start() end

-- a slot save picks its Origin once. Returns true, or false + reason.
function O.Apply(d, originId, weaponId)
	local o = Origins.List[originId or ""]
	local w = Origins.Weapons[weaponId or ""]
	if not o then
		return false, "Pick an Origin"
	end
	if not w or not ItemDB.Get(w.item) then
		return false, "Pick a starting weapon"
	end
	if d.origin then
		return false, "This character already has an Origin"
	end
	d.origin = o.id
	d.originWeapon = weaponId
	d.originSpawn = true -- the first spawn goes to the Origin's spot (PlayerService onCharacter)
	-- R5: a new character starts on its Origin's home island (an older save that already played somewhere stays put)
	if (d.level or 1) <= 1 and o.island then
		d.unlocked = d.unlocked or {}
		d.unlocked[o.island] = true
		d.lastIsland = o.island
		-- R5 (0.1.27): the Origin's prologue quest on that island runs before the Daybreak tutorial
		if Quests.Prologue[o.id] then
			d.quest = type(d.quest) == "table" and d.quest or { step = 1, progress = 0 }
			if (d.quest.step or 1) == 1 and (d.quest.progress or 0) == 0 then
				d.quest.pro = { origin = o.id, i = 1 }
			end
		end
	end
	-- the starting weapon: the starter knuckles become the chosen weapon (an older slot gets it added + equipped)
	d.inventory = d.inventory or {}
	d.equipment = d.equipment or {}
	local starter
	for _, e in ipairs(d.inventory) do
		if e.uid == "starter_w" and e.id == "Knuckles_Plain" then
			starter = e
		end
	end
	if starter then
		starter.id = w.item
		d.equipment.weapon = starter.uid
	else
		table.insert(d.inventory, { uid = "origin_w", id = w.item, qty = 1, refine = 0, cards = {} })
		d.equipment.weapon = "origin_w"
	end
	for i, k in ipairs(o.kit or {}) do
		local def = ItemDB.Get(k[1])
		if def then
			local entry = { uid = "origin_k" .. i, id = k[1], qty = k[2] or 1 }
			if def.slot then
				entry.refine, entry.cards = 0, {}
			end
			table.insert(d.inventory, entry)
		end
	end
	if o.faction then
		d.faction = o.faction
	end
	if o.bounty then
		d.bounty = math.max(d.bounty or 0, o.bounty)
	end
	return true
end

-- the Origin's start spot: in front of its NPC on its island (nil = the island's normal spawn)
function O.SpawnCFrame(p)
	local o = p and Origins.List[p.origin or ""]
	if not o or not o.npc or p.lastIsland ~= o.island then
		return nil
	end
	local n = R.WorldBuilder.FindNPC(o.npc, o.island)
	if not n or not n.model or not n.model.Parent then
		return nil
	end
	local pivot = n.model:GetPivot()
	local look = pivot.LookVector * Vector3.new(1, 0, 1)
	look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
	local spot = pivot.Position + look * 8
	-- stand on whatever is under the spot (a floor inside a building, the street...)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { n.model, workspace:FindFirstChild("Monsters") }
	local hit = workspace:Raycast(spot + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), params)
	local y = hit and hit.Position.Y or (pivot.Position.Y - 2.6)
	local at = Vector3.new(spot.X, y + 0.5, spot.Z)
	return CFrame.lookAt(at, Vector3.new(pivot.Position.X, at.Y, pivot.Position.Z))
end

-- is a monster definition a person (bandits, Marines, pirates, fish-folk...)?
function O.IsHuman(def)
	return def ~= nil and (MonsterLooks.ById[def.id] ~= nil or (def.style and (def.style.shape == "humanoid" or def.style.shape == "fishman")))
end

-- reward multiplier for an EXP / Doubloon source: src = { kind = "mob" | "boss" | "chest" | "dungeon", human = bool }
function O.RewardMult(p, src, what)
	if not p or not p.origin or type(src) ~= "table" then
		return 1
	end
	local k = 1
	if src.kind == "boss" then
		k *= Origins.Mult(p.origin, what == "beli" and "bossBeli" or "bossExp")
	elseif src.kind == "mob" and what == "exp" then
		k *= Origins.Mult(p.origin, "mobExp")
	elseif src.kind == "chest" or src.kind == "dungeon" then
		k *= Origins.Mult(p.origin, what == "beli" and "chestBeli" or "chestExp")
	end
	if src.human then
		k *= Origins.Mult(p.origin, what == "beli" and "humanBeli" or "humanExp")
	end
	return k
end

-- damage multiplier from the Origin (Relic Seeker hits softer early on)
function O.DamageMult(p)
	return p and Origins.Mult(p.origin, "damage", p.baseLevel) or 1
end

return O
