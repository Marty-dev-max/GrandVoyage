-- Export ships (ShipModel.BuildDesign + DressHull) to JSON for tools/blender/render_parts.py
--   lune run tools/export_ship.luau build/GrandVoyage.rbxlx out.json
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")
local place = roblox.deserializePlace(fs.readFile(process.args[1]))
local RS = place:GetService("ReplicatedStorage")
local CFrameFixed = setmetatable({
	lookAt = function(at, target, up)
		up = up or roblox.Vector3.new(0, 1, 0)
		local look = (target - at).Unit
		local right = look:Cross(up).Unit
		return roblox.CFrame.fromMatrix(at, right, right:Cross(look))
	end,
}, { __index = roblox.CFrame })
local gameProxy = setmetatable({}, { __index = function(_, k)
	if k == "GetService" then
		return function(_, name)
			return place:GetService(name)
		end
	end
	return place[k]
end })
local cache = {}
local function req(mod)
	local key = mod:GetFullName()
	if cache[key] then
		return cache[key]
	end
	local env = setmetatable({ script = mod, require = req, game = gameProxy, Vector3 = roblox.Vector3, Color3 = roblox.Color3, CFrame = CFrameFixed,
		UDim2 = roblox.UDim2, Enum = roblox.Enum, Instance = roblox.Instance, Font = roblox.Font, ColorSequence = roblox.ColorSequence, NumberSequence = roblox.NumberSequence }, { __index = getfenv() })
	local r = luau.load(mod.Source, { debugName = key, environment = env })()
	cache[key] = r
	return r
end
local SM = req(RS.Shared.Modules.ShipModel)
local SS = req(RS.Shared.Modules.ShipStats)
local NPC = req(RS.Shared.Config.NPCShips)
local G = 4
local function npcDesign(def)
	local parts = {}
	local W, L = def.width, def.length
	local hull = def.tier >= 3 and "OakBlock" or "PlankBlock"
	for x = 0, W - 1 do
		for z = 0, L - 1 do
			table.insert(parts, { id = hull, x = x, y = 0, z = z, r = 0 })
		end
	end
	for x = 1, W - 2 do
		table.insert(parts, { id = "PlankWedge", x = x, y = 0, z = L, r = 0 })
	end
	table.insert(parts, { id = "Helm", x = math.floor(W / 2), y = 1, z = 1, r = 0 })
	for i = 1, def.masts do
		table.insert(parts, { id = def.tier == 1 and "SmallMast" or (def.faction == "Pirate" and "JollySail" or "MarineSail"), x = math.floor(W / 2), y = 1, z = math.floor(L * (i / (def.masts + 1))) + 1, r = 0 })
	end
	local perSide = math.floor(def.cannons / 2)
	for i = 1, perSide do
		local z = math.floor((L - 2) * i / (perSide + 1)) + 1
		table.insert(parts, { id = def.tier >= 3 and "HeavyCannon" or "LightCannon", x = 0, y = 1, z = z, r = 1 })
		table.insert(parts, { id = def.tier >= 3 and "HeavyCannon" or "LightCannon", x = W - 1, y = 1, z = z, r = 3 })
	end
	return { name = def.name, parts = parts }
end
local out = { parts = {} }
local function cfArr(cf)
	local x, y, z, a, b, c, d, e, f, g, h, i = cf:GetComponents()
	return { x, y, z, a, b, c, d, e, f, g, h, i }
end
local list = { { SS.StarterDesign(), nil }, { npcDesign(NPC.Ships.Pirate1), { hull = roblox.Color3.fromRGB(70, 50, 40), trim = roblox.Color3.fromRGB(38, 28, 24), stripe = roblox.Color3.fromRGB(196, 44, 44) } },
	{ npcDesign(NPC.Ships.Marine2), { hull = roblox.Color3.fromRGB(240, 240, 246), trim = roblox.Color3.fromRGB(60, 100, 190), stripe = roblox.Color3.fromRGB(232, 192, 80) } },
	{ npcDesign(NPC.Ships.Pirate3), { hull = roblox.Color3.fromRGB(70, 50, 40), trim = roblox.Color3.fromRGB(38, 28, 24), stripe = roblox.Color3.fromRGB(196, 44, 44) } } }
local x0 = 0
for _, it in list do
	local origin = roblox.CFrame.new(x0, 0, 0)
	local model = SM.BuildDesign(it[1], origin, nil)
	local class = SM.DressHull(model, it[1], origin, it[2])
	print(it[1].name, class)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.98 then
			local c = d.Color
			table.insert(out.parts, { shape = d.ClassName == "WedgePart" and "Wedge" or "Block", cf = cfArr(d.CFrame), size = { d.Size.X, d.Size.Y, d.Size.Z }, color = { c.R, c.G, c.B } })
		end
	end
	x0 += 50
end
fs.writeFile(process.args[2], serde.encode("json", out))
print(#out.parts, "parts")
