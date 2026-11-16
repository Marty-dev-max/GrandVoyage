local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local process = require("@lune/process")

local place = roblox.deserializePlace(fs.readFile(process.args[1] or "build/GrandVoyage.rbxlx"))
local RS = place:GetService("ReplicatedStorage")
local cache = {}
local function req(mod)
	local key = mod:GetFullName()
	if cache[key] then return cache[key] end
	local env = setmetatable({ script = mod, require = req, game = place,
		Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, Color3 = roblox.Color3, CFrame = roblox.CFrame,
		UDim2 = roblox.UDim2, Enum = roblox.Enum, Instance = roblox.Instance }, { __index = getfenv() })
	local fn = luau.load(mod.Source, { debugName = mod:GetFullName(), environment = env })
	local r = fn()
	cache[key] = r
	return r
end
local Shared = RS.Shared
local GameConfig = req(Shared.Config.GameConfig)
local Islands = req(Shared.Config.Islands)
local Monsters = req(Shared.Config.Monsters)
local ItemDB = req(Shared.Modules.ItemDB)
local F = req(Shared.Modules.Formulas)
local ShipStats = req(Shared.Modules.ShipStats)
local SeaZones = req(Shared.Modules.SeaZones)
local NPCShips = req(Shared.Config.NPCShips)
local Classes = req(Shared.Config.Classes)

local errors = 0
local function check(cond, msg) if not cond then errors += 1; print("FAIL: " .. msg) end end

-- 1) every drop / card references a real item
for id, m in pairs(Monsters) do
	for _, d in ipairs(m.drops or {}) do check(ItemDB.Get(d[1]) ~= nil, id .. " drop missing " .. d[1]) end
	if not m.isCore then check(ItemDB.Get(m.card) ~= nil, id .. " has no card def " .. tostring(m.card)) end
end
for id, s in pairs(NPCShips.Ships) do
	for _, d in ipairs(s.drops) do check(ItemDB.Get(d[1]) ~= nil, id .. " ship drop missing " .. d[1]) end
end
for _, isl in ipairs(Islands.List) do
	for _, sp in ipairs(isl.spawns) do check(Monsters[sp.monster] ~= nil, "spawn monster missing " .. sp.monster) end
	check(Monsters[isl.boss.id] ~= nil, "boss missing " .. isl.boss.id)
	for _, sp in ipairs(isl.spawns) do
		local d = sp.offset.Magnitude + sp.radius
		check(d <= isl.radius - 5, isl.id .. " spawn zone off island: " .. sp.monster .. " " .. d .. ">" .. isl.radius)
	end
end
for _, id in ipairs(ItemDB.Shop) do check(ItemDB.Get(id) ~= nil, "shop item missing " .. id) end
local Dungeons = req(Shared.Config.Dungeons)
for id, d in pairs(Dungeons) do
	check(Monsters[d.boss] ~= nil, "dungeon boss missing " .. id)
	for _, w in ipairs(d.waves) do for _, g in ipairs(w) do check(Monsters[g[1]] ~= nil, "dungeon mob missing " .. g[1]) end end
end
for cid, c in pairs(Classes.Classes) do
	for _, w in ipairs(c.weapons) do check(ItemDB.Get(w .. "_Plain") ~= nil, cid .. " weapon missing " .. w) end
end

-- 2) stat formulas
local profile = { class = "Swordsman", baseLevel = 30, stats = { STR = 40, AGI = 30, VIT = 30, INT = 5, DEX = 25, LUK = 10 },
	inventory = { { uid = "w", id = "Sword_Keen", qty = 1, refine = 7, cards = { "WildBoarCard" } }, { uid = "a", id = "MarineCoat", qty = 1, refine = 4, cards = {} } },
	equipment = { weapon = "w", armor = "a" } }
local d = F.Compute(profile, {})
print(string.format("Swordsman Lv30: HP %d SP %d ATK %d DEF %d HIT %d FLEE %d CRIT %.1f interval %.2f", d.maxHp, d.maxSp, d.atk, d.def, d.hit, d.flee, d.crit, d.attackInterval))
local mob = Monsters.NightCatPirate
local dmg = F.Damage(d.atk, mob.def, 1, 0)
print("  dmg vs NightCatPirate (hp " .. mob.hp .. "): ~" .. dmg .. " => hits to kill " .. math.ceil(mob.hp / dmg))
local mdmg = F.Damage(mob.atk, d.def, 1, 0)
print("  NightCatPirate hits player for ~" .. mdmg .. " (" .. math.floor(d.maxHp / mdmg) .. " hits to die)")
for lv = 1, 70, 10 do
	print(string.format("  Lv%d -> next %d exp", lv, F.BaseExpToNext(lv)))
end

-- 3) ships
local starter = ShipStats.StarterDesign()
local st = ShipStats.Compute(starter, 2, {})
print(string.format("Starter ship: parts %d weight %d hp %d thrust %d cannons %d crewCap %d valid %s", st.partCount, st.weight, st.hp, st.thrust, #st.cannons, st.crewCap, tostring(st.valid)))
print(string.format("  speed lane %.1f edge50%% %.1f calm %.1f  turn %.2f", ShipStats.Speed(st, 1), ShipStats.Speed(st, 0.5), ShipStats.Speed(st, 0), st.turnRate))
check(st.valid, "starter ship invalid")
-- occupancy overlap check
local occ = {}
for _, p in ipairs(starter.parts) do
	for _, c in ipairs(ShipStats.Cells(p)) do
		local k = ShipStats.CellKey(c)
		check(not occ[k], "starter overlap at " .. k)
		occ[k] = true
		check(c.X >= 0 and c.Y >= 0 and c.Z >= 0 and c.X < GameConfig.Ship.PlotSize.X and c.Y < GameConfig.Ship.PlotSize.Y and c.Z < GameConfig.Ship.PlotSize.Z, "starter out of plot " .. k)
	end
end
-- big ship
local big = { parts = {} }
for x = 0, 8 do for z = 0, 20 do table.insert(big.parts, { id = "OakBlock", x = x, y = 0, z = z, r = 0 }) end end
table.insert(big.parts, { id = "Helm", x = 4, y = 1, z = 2 })
for i = 1, 3 do table.insert(big.parts, { id = "LargeMast", x = 4, y = 1, z = i * 5 }) end
for i = 1, 8 do table.insert(big.parts, { id = "HeavyCannon", x = 0, y = 1, z = i * 2, r = 1 }) end
for i = 1, 3 do table.insert(big.parts, { id = "CrewCabin", x = 1, y = 1, z = 2 + i * 5 }) end
local bs = ShipStats.Compute(big, 14, {})
print(string.format("Big galleon: weight %d hp %d speed lane %.1f calm %.1f cannons %d manned %d turn %.2f", bs.weight, bs.hp, ShipStats.Speed(bs, 1), ShipStats.Speed(bs, 0), #bs.cannons, bs.cannonsManned, bs.turnRate))

-- 4) sea zones
for _, z in ipairs({ 0, 400, 560, 620, 700, 2000 }) do
	local zone, wind = SeaZones.Get(roblox.Vector3.new(2500, 0, z))
	print(string.format("  z=%d -> %s wind %.2f", z, zone, wind))
end
print("  x=12700 ->", SeaZones.Get(roblox.Vector3.new(12700, 0, 0)))
print(errors == 0 and "ALL CHECKS PASSED" or ("ERRORS: " .. errors))
if errors > 0 then
	process.exit(1)
end
