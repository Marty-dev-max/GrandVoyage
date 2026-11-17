-- usage: lune run tools/export_island.luau build/GrandVoyage.rbxl Daybreak out.json
-- Export World.<Island> parts + dressing props to JSON for a Blender preview render
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")
local place = roblox.deserializePlace(fs.readFile(process.args[1]))
local world = place:GetService("Workspace"):FindFirstChild("World")
local isl = world:FindFirstChild(process.args[2])
local out = { parts = {}, props = {}, envparts = {} }
local function cfArr(cf)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 }
end
local mesaDressed = {}
for _, d in isl:GetDescendants() do
	if d:IsA("BasePart") and d:HasTag("EnvPart") and d:GetAttribute("MesaId") then
		mesaDressed[d:GetAttribute("MesaId")] = true
	end
end
for _, d in isl:GetDescendants() do
	if d:IsA("Model") and d:HasTag("EnvProp") then
		local b = d:GetAttribute("Base")
		table.insert(out.props, { kind = d:GetAttribute("Kind"), base = { b.X, b.Y, b.Z }, h = d:GetAttribute("Height") })
	elseif d:IsA("BasePart") then
		local m = d.Parent
		local inProp = m and m:IsA("Model") and m:HasTag("EnvProp")
		if d:HasTag("EnvPart") then
			table.insert(out.envparts, { kind = d:GetAttribute("Kind"), cf = cfArr(d.CFrame), size = { d.Size.X, d.Size.Y, d.Size.Z } })
		elseif inProp then
			-- dressed at runtime: placeholder parts vanish (colliders are invisible)
		elseif d:GetAttribute("MesaId") and mesaDressed[d:GetAttribute("MesaId")] then
			-- hidden once the mesa is dressed
		elseif d.Transparency < 0.98 then
			local shape = "Block"
			if d.ClassName == "WedgePart" then
				shape = "Wedge"
			elseif d.ClassName == "Part" then
				shape = d.Shape.Name
			end
			local c = d.Color
			table.insert(out.parts, { shape = shape, cf = cfArr(d.CFrame), size = { d.Size.X, d.Size.Y, d.Size.Z }, color = { c.R, c.G, c.B }, mat = d.Material.Name, t = d.Transparency })
		end
	end
end
fs.writeFile(process.args[3], serde.encode("json", out))
print(#out.parts, "parts", #out.props, "props", #out.envparts, "envparts")
