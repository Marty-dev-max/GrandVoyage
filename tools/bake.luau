local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local process = require("@lune/process")

-- usage: lune run tools/bake.luau <input.rbxlx> <output.rbxl>
-- Runs WorldBuilder outside Studio to bake the map into Workspace (visible and editable on open)
local placePath = process.args[1]
local outPath = process.args[2] or placePath
roblox.implementMethod("Model", "GetPivot", function(self)
	return self.PrimaryPart and self.PrimaryPart.CFrame or roblox.CFrame.new()
end)
roblox.implementMethod("Model", "PivotTo", function(self, cf)
	local pp = self.PrimaryPart
	if not pp then return end
	local inv = pp.CFrame:Inverse()
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then d.CFrame = cf * (inv * d.CFrame) end
	end
end)
local place = roblox.deserializePlace(fs.readFile(placePath))
local RS = place:GetService("ReplicatedStorage")
local SSS = place:GetService("ServerScriptService")
local ws = place:GetService("Workspace")
local collection = { AddTag = function(_, inst, tag) inst:AddTag(tag) end }
local gameProxy = setmetatable({}, { __index = function(_, k)
	if k == "GetService" then
		return function(_, name)
			if name == "CollectionService" then return collection end
			return place:GetService(name)
		end
	end
	return place[k]
end })
-- workspace proxy: Raycast -> nil
local wsProxy = setmetatable({ Raycast = function() return nil end }, { __index = function(_, k)
	local v = ws[k]
	if type(v) == "function" then return function(_, ...) return v(ws, ...) end end
	return v
end, __newindex = function(_, k, v) ws[k] = v end })

-- Lune's CFrame.lookAt points the wrong way along Z (lookAt(0, (0,0,-1)).LookVector = (0,0,1)), which turned every
-- lookAt-placed part of the baked map (path segments, quay blocks, houses, signs, docks) the wrong way round (fixed
-- v0.22.5). Build the frame ourselves, exactly like Roblox does.
local CFrameFixed = setmetatable({
	lookAt = function(at, target, up)
		up = up or roblox.Vector3.new(0, 1, 0)
		local look = target - at
		if look.Magnitude < 1e-6 then
			return roblox.CFrame.new(at.X, at.Y, at.Z)
		end
		look = look.Unit
		local right = look:Cross(up)
		if right.Magnitude < 1e-6 then
			right = look:Cross(roblox.Vector3.new(0, 0, 1))
		end
		right = right.Unit
		return roblox.CFrame.fromMatrix(at, right, right:Cross(look))
	end,
}, { __index = roblox.CFrame })

local cache = {}
local function req(mod)
	local key = mod:GetFullName()
	if cache[key] then return cache[key] end
	local env = setmetatable({ script = mod, require = req, game = gameProxy, workspace = ws,
		Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, Color3 = roblox.Color3, CFrame = CFrameFixed,
		UDim2 = roblox.UDim2, UDim = roblox.UDim, Enum = roblox.Enum, Instance = roblox.Instance, Random = { new = function(seed) local s = (math.floor(math.abs(seed or 1)) % 2147483646) + 1; local function nxt() s = (s * 48271) % 2147483647; return s / 2147483647 end; return { NextNumber = function(_, a, b) a = a or 0; b = b or 1; return a + nxt() * (b - a) end, NextInteger = function(_, a, b) return a + math.min(b - a, math.floor(nxt() * (b - a + 1))) end } end },
		Font = roblox.Font,
		ColorSequence = roblox.ColorSequence, NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		NumberRange = roblox.NumberRange, PhysicalProperties = roblox.PhysicalProperties }, { __index = getfenv() })
	local fn = luau.load(mod.Source, { debugName = mod:GetFullName(), environment = env })
	local r = fn()
	cache[key] = r
	return r
end
local WB = req(SSS.Server.World.WorldBuilder)
local world = WB.Build()
local n = 0
for _ in world:GetDescendants() do n += 1 end
print("baked instances:", n)
fs.writeFile(outPath, roblox.serializePlace(place))
