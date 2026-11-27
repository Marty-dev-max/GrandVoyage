-- CookService (Mastery v2 M2, docs/Plan-Mastery-v2.md sec 2): cook at any campfire of the map.
-- Every Fire instance under workspace.World / workspace.Handmade gets a "Cook" ProximityPrompt on its part (tag
-- CookFire); E -> push OpenPanel Cook -> client UI/Cook.lua. "CookStart" { recipe } checks the fire, the Cook
-- level and the ingredients and starts a Timing Bar (MasteryService.TimingStart); "CookFinish" { token, t } takes
-- the ingredients and gives the dish with 1-3 stars (Config/Recipes ItemId) + Cook Mastery XP.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Recipes = require(Shared.Config.Recipes)
local MasteryCfg = require(Shared.Config.Mastery)
local ItemDB = require(Shared.Modules.ItemDB)
local Net = require(Shared.Modules.Net)

local CS = {}
local R

local TAG = "CookFire"
local REACH = 14

function CS.Init(registry)
	R = registry
end

local function inMap(inst)
	local world = workspace:FindFirstChild("World")
	local hand = workspace:FindFirstChild("Handmade")
	return (world and inst:IsDescendantOf(world)) or (hand and inst:IsDescendantOf(hand))
end

-- a shop NPC's walk-in ring nearby (the Blacksmith's forge burns inside the smithy): not a cooking fire
local function byShopNpc(pos)
	for _, m in ipairs(CollectionService:GetTagged("NPC")) do
		if m:GetAttribute("ZoneColor") and m.PrimaryPart and (m.PrimaryPart.Position - pos).Magnitude < 20 then
			return true
		end
	end
	return false
end

local function dress(fire)
	local part = fire.Parent
	if not part or not part:IsA("BasePart") or not inMap(part) or part:FindFirstChild("CookPrompt") or byShopNpc(part.Position) then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CookPrompt"
	prompt.ActionText = "Cook"
	prompt.ObjectText = "Campfire"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	CollectionService:AddTag(part, TAG)
	prompt.Triggered:Connect(function(player)
		Net.Push(player, "OpenPanel", { name = "Cook" })
	end)
end

function CS.NearFire(player)
	local root = R.PlayerService.Root(player)
	if not root then
		return false
	end
	for _, part in ipairs(CollectionService:GetTagged(TAG)) do
		if part.Parent and (part.Position - root.Position).Magnitude <= REACH then
			return true
		end
	end
	return false
end

local function hasAll(player, recipe)
	for ing, n in pairs(recipe.needs) do
		if R.InventoryService.Count(player, ing) < n then
			return false, ItemDB.Get(ing) and ItemDB.Get(ing).name or ing
		end
	end
	return true
end

function CS.Start()
	-- dress the fires once the map is there, and any made later (MobZones camps, a rebuilt World)
	task.spawn(function()
		while not workspace:FindFirstChild("World") do
			task.wait(1)
		end
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("Fire") then
				dress(d)
			end
		end
	end)
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("Fire") then
			task.defer(dress, d)
		end
	end)

	Net.Handle("CookStart", function(player, data)
		local p = R.PlayerService.Profile(player)
		local recipe = type(data) == "table" and type(data.recipe) == "string" and Recipes.ById[data.recipe]
		if not p or not recipe then
			return false, "Unknown recipe"
		end
		if not CS.NearFire(player) then
			return false, "Stand by a campfire"
		end
		if MasteryCfg.Level(p, "Cook") < recipe.lv then
			return false, "Needs Cook Mastery Lv." .. recipe.lv
		end
		local ok, missing = hasAll(player, recipe)
		if not ok then
			return false, "Not enough " .. missing
		end
		local run = R.MasteryService.TimingStart(player, "Cook", recipe.id)
		if not run then
			return false
		end
		return { ok = true, data = run }
	end, 0.5)

	Net.Handle("CookFinish", function(player, data)
		if type(data) ~= "table" or type(data.token) ~= "string" then
			return false
		end
		local q, recipeId = R.MasteryService.TimingFinish(player, data.token, data.t)
		local recipe = recipeId and Recipes.ById[recipeId]
		if not q or not recipe then
			return false, "Nothing on the fire"
		end
		if not CS.NearFire(player) then
			return false, "You walked away from the fire"
		end
		local ok, missing = hasAll(player, recipe)
		if not ok then
			return false, "Not enough " .. missing
		end
		local out = Recipes.ItemId(recipe.id, q)
		for ing, n in pairs(recipe.needs) do
			R.InventoryService.RemoveItem(player, ing, n)
		end
		if not R.InventoryService.AddItem(player, out, 1) then
			-- bag full: give the ingredients back
			for ing, n in pairs(recipe.needs) do
				R.InventoryService.AddItem(player, ing, n)
			end
			return false, "Your bag is full"
		end
		R.MasteryService.Add(player, "Cook", Recipes.Xp(recipe, q))
		local root = R.PlayerService.Root(player)
		if root then
			Net.FX("UseItem", { pos = root.Position, id = out }, root.Position, 200)
		end
		local def = ItemDB.Get(out)
		return { ok = true, msg = (def and def.name or out) .. string.rep(" *", q), data = { stars = q, item = out } }
	end, 0.3)
end

return CS
