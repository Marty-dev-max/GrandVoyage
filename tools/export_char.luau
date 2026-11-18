-- Export voxel characters (Shared/Modules/VoxelChar) to JSON for an offline Blender render (tools/blender/render_parts.py)
--   lune run tools/export_char.luau build/GrandVoyage.rbxlx out.json [lineup|styles]
-- lineup: a row of random looks + each Heritage; styles: every hair / shirt / pants style in rows
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
		if d:IsA("BasePart") and d.Transparency < 0.98 then
			local cf = roblox.CFrame.new(offset) * d.CFrame
			local c = d.Color
			table.insert(out.parts, { shape = "Block", cf = cfArr(cf), size = { d.Size.X, d.Size.Y, d.Size.Z }, color = { c.R, c.G, c.B }, mat = "SmoothPlastic", t = 0 })
			-- face images: textured planes on the cube's front (tools/blender/render_parts.py draws "img" parts)
			local sg = d:FindFirstChild("Face")
			if sg then
				local s = d.Size
				for _, im in sg:GetChildren() do
					local key = im:GetAttribute("Img")
					if key then
						local u, v = im.Position.X.Scale, im.Position.Y.Scale
						local w, h = im.Size.X.Scale, im.Size.Y.Scale
						-- front = -Z; screen-left = +X
						local lx = s.X / 2 - (u + w / 2) * s.X
						local ly = s.Y / 2 - (v + h / 2) * s.Y
						local pcf = cf * roblox.CFrame.new(lx, ly, -s.Z / 2 - 0.005 - im.ZIndex * 0.003)
						local tc = im.ImageColor3
						table.insert(out.parts, { img = "assets/faces/" .. key .. ".png", cf = cfArr(pcf), size = { w * s.X, h * s.Y, 0 }, color = { tc.R, tc.G, tc.B } })
					end
				end
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
