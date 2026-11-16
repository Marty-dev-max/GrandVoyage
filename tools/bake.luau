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

local cache = {}
local function req(mod)
	local key = mod:GetFullName()
	if cache[key] then return cache[key] end
	local env = setmetatable({ script = mod, require = req, game = gameProxy, workspace = ws,
		Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, Color3 = roblox.Color3, CFrame = roblox.CFrame,
		UDim2 = roblox.UDim2, UDim = roblox.UDim, Enum = roblox.Enum, Instance = roblox.Instance, Random = { new = function(seed) math.randomseed(seed) return { NextNumber = function(_, a, b) a = a or 0; b = b or 1; return a + math.random() * (b - a) end, NextInteger = function(_, a, b) return math.random(a, b) end } end },
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
