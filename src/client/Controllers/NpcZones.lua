-- NpcZones (v0.25.112, owner reference: a glowing ring on the ground, walk in and the window opens): every NPC with a
-- ZoneColor attribute (shop roles, WorldBuilder.ZONE_ROLES) gets a ring of neon blocks in its color around it. Stepping
-- into the ring asks the server ("ZoneEnter"), which checks the distance and opens the same window the old "Talk"
-- prompt did. Leave the ring and walk in again to reopen. Rings near the camera spin slowly and breathe.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local UI = require(script.Parent.Parent.UI.UIKit)

local NpcZones = {}

local RADIUS = 7 -- = WorldBuilder.ZONE_RADIUS
local BLOCKS = 30
local ANIM_RANGE = 140

local folder
local zones = {} -- { model, role, center, parts = {}, cfs = {}, glow }

local function build(m)
	local color = m:GetAttribute("ZoneColor")
	local role = m:GetAttribute("Role")
	if typeof(color) ~= "Color3" or type(role) ~= "string" then
		return
	end
	for _, z in ipairs(zones) do
		if z.model == m then
			return
		end
	end
	local root = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local center = root.Position - Vector3.new(0, 2.6 - 1.0, 0) -- feet + a hair above the NPC's glow disc
	local z = { model = m, role = role, center = center, parts = {}, inside = false }
	for i = 1, BLOCKS do
		local p = Instance.new("Part")
		p.Name = "ZoneBlock"
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Size = (i % 2 == 0) and Vector3.new(0.9, 0.25, 0.9) or Vector3.new(0.55, 0.2, 0.55)
		p.Transparency = 0.15
		p.Parent = folder
		z.parts[i] = p
	end
	local glow = Instance.new("Part")
	glow.Name = "ZoneGlow"
	glow.Shape = Enum.PartType.Cylinder
	glow.Anchored, glow.CanCollide, glow.CanQuery, glow.CanTouch, glow.CastShadow = true, false, false, false, false
	glow.Material = Enum.Material.Neon
	glow.Color = color
	glow.Transparency = 0.88
	glow.Size = Vector3.new(0.08, RADIUS * 2, RADIUS * 2)
	glow.CFrame = CFrame.new(center - Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	glow.Parent = folder
	z.glow = glow
	z.place = function(t)
		local cfs = {}
		for i = 1, BLOCKS do
			local a = (i / BLOCKS) * math.pi * 2 + t * 0.35
			local pos = center + Vector3.new(math.cos(a) * RADIUS, 0.04 * math.sin(t * 2 + i), math.sin(a) * RADIUS)
			cfs[i] = CFrame.new(pos) * CFrame.Angles(0, -a, 0)
		end
		workspace:BulkMoveTo(z.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
	z.place(0)
	table.insert(zones, z)
	m.Destroying:Connect(function()
		for i, zz in ipairs(zones) do
			if zz == z then
				table.remove(zones, i)
				break
			end
		end
		for _, p in ipairs(z.parts) do
			p:Destroy()
		end
		glow:Destroy()
	end)
end

function NpcZones.Start()
	folder = Instance.new("Folder")
	folder.Name = "NpcZones"
	folder.Parent = workspace
	for _, m in ipairs(CollectionService:GetTagged("NPC")) do
		build(m)
	end
	CollectionService:GetInstanceAddedSignal("NPC"):Connect(function(m)
		task.defer(build, m)
	end)
	local busy = false
	task.spawn(function()
		while true do
			task.wait(0.05)
			local t = os.clock()
			local cam = workspace.CurrentCamera
			local char = Players.LocalPlayer.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			for _, z in ipairs(zones) do
				if cam and (cam.CFrame.Position - z.center).Magnitude < ANIM_RANGE then
					z.place(t)
					z.glow.Transparency = 0.86 + 0.06 * math.sin(t * 2.4)
				end
				local inside = false
				if root and hum and hum.Health > 0 then
					local d = root.Position - z.center
					inside = Vector2.new(d.X, d.Z).Magnitude <= RADIUS and math.abs(d.Y) < 8
				end
				if inside and not z.inside and not busy and not UI.AnyOpen() then
					busy = true
					task.spawn(function()
						pcall(Net.Request, "ZoneEnter", { role = z.role })
						busy = false
					end)
				end
				z.inside = inside
			end
		end
	end)
end

return NpcZones
