-- Export voxel characters (Shared/Modules/VoxelChar) to JSON for an offline Blender render (tools/blender/render_parts.py)
--   lune run tools/export_char.luau build/GrandVoyage.rbxlx out.json [lineup|styles]
-- lineup: a row of random looks + each Heritage; styles: every hair / shirt / pants style in rows; races: every
-- Skyborn / Tidekin / Oni variant
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")

local place = roblox.deserializePlace(fs.readFile(process.args[1]))
local mode = process.args[3] or "lineup"
local RS = place:GetService("ReplicatedStorage")

local function rng(seed)
	local s = (math.floor(math.abs(seed or 1)) % 2147483646) + 1
	local function nxt()
		s = (s * 48271) % 2147483647
		return s / 2147483647
	end
	return {
		NextNumber = function(_, a, b)
			a = a or 0
			b = b or 1
			return a + nxt() * (b - a)
		end,
		NextInteger = function(_, a, b)
			return a + math.min(b - a, math.floor(nxt() * (b - a + 1)))
		end,
	}
end

local cache = {}
local function req(mod)
	local key = mod:GetFullName()
	if cache[key] then
		return cache[key]
	end
	local env = setmetatable({
		script = mod, require = req, Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, Color3 = roblox.Color3, CFrame = roblox.CFrame,
		UDim2 = roblox.UDim2, UDim = roblox.UDim, Enum = roblox.Enum, Instance = roblox.Instance, Random = { new = rng },
		table = setmetatable({ clone = function(t) local o = {} for k, v in t do o[k] = v end return o end }, { __index = table }),
	}, { __index = getfenv() })
	local fn = luau.load(mod.Source, { debugName = key, environment = env })
	local r = fn()
	cache[key] = r
	return r
end

local VC = req(RS.Shared.Modules.VoxelChar)
local Looks = req(RS.Shared.Config.Looks)

local out = { parts = {} }
local function cfArr(cf)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 }
end
local function dump(model, offset)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and (d.Transparency < 0.98 or d:FindFirstChild("FaceDecal")) then
			local cf = roblox.CFrame.new(offset) * d.CFrame
			local c = d.Color
			if d.Transparency < 0.98 then
				table.insert(out.parts, { shape = "Block", cf = cfArr(cf), size = { d.Size.X, d.Size.Y, d.Size.Z }, color = { c.R, c.G, c.B }, mat = "SmoothPlastic", t = 0 })
			end
			-- face layers: decals on thin plates (tools/blender/render_parts.py draws "img" parts)
			local dec = d:FindFirstChild("FaceDecal")
			if dec then
				local tc = dec.Color3
				table.insert(out.parts, { img = "assets/faces/" .. dec:GetAttribute("Img") .. ".png", cf = cfArr(cf * roblox.CFrame.new(0, 0, -0.012)), size = { d.Size.X, d.Size.Y, 0 }, color = { tc.R, tc.G, tc.B } })
			end
		end
	end
end

if mode == "styles" then
	local base = Looks.Default()
	local rows = { { "hair", #Looks.Hair }, { "shirt", #Looks.Shirts }, { "pants", #Looks.Pants }, { "shoes", #Looks.Shoes } }
	local only = process.args[4]
	for r, row in rows do
		if only and only ~= row[1] then
			continue
		end
		for i = 1, row[2] do
			local look = table.clone(base)
			look[row[1]] = i
			look.hair1 = Looks.Presets[(i * 5) % #Looks.Presets + 1]
			look.shirt1 = Looks.Presets[(i * 3 + r) % #Looks.Presets + 1]
			look.pants1 = Looks.Presets[(i * 7 + r) % #Looks.Presets + 1]
			look.shoes1 = Looks.Presets[(i * 11 + r) % #Looks.Presets + 1]
			dump(VC.Preview(look, nil), roblox.Vector3.new((i - 1) * 4.2, 0, (r - 1) * 9))
		end
	end
	for i = 1, #Looks.Eyes do
		local look = table.clone(base)
		look.eyes = i
		look.mouth = ((i - 1) % #Looks.Mouths) + 1
		dump(VC.Preview(look, nil), roblox.Vector3.new((i - 1) * 4.2, 0, 4 * 9))
	end
elseif mode == "monsters" then
	-- every humanoid monster (Config/MonsterLooks) with its accessories, like MF.VoxelMonster builds them
	local ML = req(RS.Shared.Config.MonsterLooks)
	local Acc = req(RS.Shared.Modules.Accessory)
	local ids = {}
	for id in ML.ById do
		table.insert(ids, id)
	end
	table.sort(ids)
	local row = tonumber(process.args[4]) -- optional: only that row of 8 (front renders hide the rows behind)
	for i, id in ids do
		if row and math.floor((i - 1) / 8) + 1 ~= row then
			continue
		end
		print(i, id)
		local e = ML.ById[id]
		local race, variant = ML.Race(id)
		local m = VC.Preview(ML.Look(id), race, variant, nil, { lite = true })
		local list = table.clone(e.acc or {})
		if e.held then
			table.insert(list, e.held)
		end
		for _, a in list do
			Acc.Build(a, function(limb)
				if limb == "Head" then
					local h = m:FindFirstChild("VoxelHead", true)
					return h and h.CFrame, h and h.Size
				end
				local r = VC.Rest[limb]
				return r and roblox.CFrame.new(r[2]), r and r[1]
			end, function(size, cf, color)
				local p = roblox.Instance.new("Part")
				p.Size = size
				p.CFrame = cf
				p.Color = color
				p.Transparency = 0
				p.Parent = m
			end)
		end
		dump(m, roblox.Vector3.new(((i - 1) % 8) * 6, 0, row and 0 or math.floor((i - 1) / 8) * 9))
	end
elseif mode == "accessories" then
	-- every accessory's blocks on a rest-pose mannequin (head = the voxel head cube), for tools/gen_acc_icons.py
	local Acc = req(RS.Shared.Modules.Accessory)
	out.acc = {}
	local function limbCF(limb)
		if limb == "Head" then
			local r = VC.Rest.Head
			return roblox.CFrame.new(r[2] + roblox.Vector3.new(0, (VC.HEAD - r[1].Y) / 2, 0)), roblox.Vector3.new(VC.HEAD, VC.HEAD, VC.HEAD)
		end
		local r = VC.Rest[limb]
		return r and roblox.CFrame.new(r[2]), r and r[1]
	end
	for id in Acc.Cfg do
		local blocks, used = {}, {}
		Acc.Build(id, function(limb)
			used[limb] = true
			if limb == "Head" then
				local r = VC.Rest.Head
				return roblox.CFrame.new(r[2] + roblox.Vector3.new(0, (VC.HEAD - r[1].Y) / 2, 0)), roblox.Vector3.new(VC.HEAD, VC.HEAD, VC.HEAD)
			end
			local r = VC.Rest[limb]
			return r and roblox.CFrame.new(r[2]), r and r[1]
		end, function(size, cf, color)
			table.insert(blocks, { size = { size.X, size.Y, size.Z }, cf = cfArr(cf), color = { math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5) } })
		end)
		-- a plain stand the piece sits on (head / torso / hand), so the icon reads as "a hat", "a cape"...
		for limb in used do
			local cf, size = limbCF(limb)
			if cf then
				local gray = limb == "Head" and { 222, 200, 178 } or { 120, 126, 146 }
				table.insert(blocks, { size = { size.X, size.Y, size.Z }, cf = cfArr(cf), color = gray, stand = true })
			end
		end
		out.acc[id] = blocks
	end
elseif mode == "races" then
	-- every variant of the races with body parts (wings / fins / horns), seen from behind-left so backs show too
	local r = rng(11)
	local list = {}
	for _, h in Looks.Heritages do
		if h.id == "Skyborn" or h.id == "Tidekin" or h.id == "Oni" then
			for vi = 1, #h.variants do
				table.insert(list, { h.id, vi })
			end
		end
	end
	for i, h in list do
		dump(VC.Preview(Looks.Random(r), h[1], h[2]), roblox.Vector3.new((i - 1) * 5, 0, 0))
	end
else
	local r = rng(7)
	local hers = { { "Islander", 1 }, { "Skyborn", 1 }, { "Skyborn", 3 }, { "Tidekin", 2 }, { "Beastkin", 1 }, { "Beastkin", 2 }, { "Oni", 1 }, { "Oni", 3 }, { "Cinderwing", 1 } }
	for i, h in hers do
		local look = Looks.Random(r)
		dump(VC.Preview(look, h[1], h[2]), roblox.Vector3.new((i - 1) * 5, 0, 0))
	end
end
fs.writeFile(process.args[2], serde.encode("json", out))
print(#out.parts, "parts")
