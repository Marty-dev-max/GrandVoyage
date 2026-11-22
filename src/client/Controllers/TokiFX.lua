-- TokiFX (client, v0.25.70): Conqueror's Roar. A pulse of will in the roarer's own Toki color: a dark flash, voxel
-- rings racing out over the ground, jagged lightning bolts crackling outward (blocks, our voxel look), a camera jolt +
-- a colored screen edge for everyone it reaches, and "COWED" marks on the monsters that froze (the server sends Miss
-- texts for them). The color is random per player (Config/Toki Colors), not always black and red.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local TokiCfg = require(ReplicatedStorage.Shared.Config.Toki)
local Voxels = require(script.Parent.Voxels)

local TokiFX = {}
local folder

local function blk(size, color, cf, transp)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Size = size
	p.Color = color
	p.Transparency = transp or 0
	p.CFrame = cf
	p.Parent = folder or workspace
	return p
end

-- a jagged bolt of blocks from a to b
local function bolt(a, b, color, core, life)
	local pts = { a }
	local n = 6
	for i = 1, n - 1 do
		local p = a:Lerp(b, i / n)
		table.insert(pts, p + Vector3.new(math.random() - 0.5, (math.random() - 0.5) * 0.8, math.random() - 0.5) * 3.2)
	end
	table.insert(pts, b)
	for i = 1, #pts - 1 do
		local p0, p1 = pts[i], pts[i + 1]
		local len = (p1 - p0).Magnitude
		local cf = CFrame.lookAt(p0:Lerp(p1, 0.5), p1)
		local outer = blk(Vector3.new(0.55, 0.55, len), color, cf, 0.15)
		local inner = blk(Vector3.new(0.22, 0.22, len), core, cf, 0)
		for _, q in ipairs({ outer, inner }) do
			TweenService:Create(q, TweenInfo.new(life, Enum.EasingStyle.Quad), { Transparency = 1 }):Play()
			Debris:AddItem(q, life + 0.05)
		end
	end
end

local edgeGui
local function screenEdge(color)
	local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return
	end
	if not edgeGui then
		edgeGui = Instance.new("ScreenGui")
		edgeGui.Name = "GVTokiEdge"
		edgeGui.IgnoreGuiInset = true
		edgeGui.ResetOnSpawn = false
		edgeGui.DisplayOrder = 40
		edgeGui.Parent = pg
	end
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundTransparency = 1
	f.Parent = edgeGui
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 40
	stroke.Transparency = 0.2
	stroke.Parent = f
	TweenService:Create(stroke, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { Transparency = 1, Thickness = 6 }):Play()
	Debris:AddItem(f, 0.75)
end

local function shake(power, dur)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - t0) / dur
		if k >= 1 then
			conn:Disconnect()
			return
		end
		local cam = workspace.CurrentCamera
		local s = power * (1 - k)
		cam.CFrame = cam.CFrame * CFrame.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
	end)
end

local function roar(d)
	local char = d.char
	local root = typeof(char) == "Instance" and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local ok, color = pcall(Color3.fromHex, d.color or "")
	color = ok and color or TokiCfg.ColorOf(nil)
	-- the core of a bolt: white for dark colors, near-black for very light ones
	local lum = color.R * 0.3 + color.G * 0.59 + color.B * 0.11
	local core = lum > 0.75 and Color3.fromRGB(30, 26, 40) or Color3.new(1, 1, 1)
	local radius = math.min(tonumber(d.radius) or 36, 60)
	local at = root.Position
	local feet = at - Vector3.new(0, 2.7, 0)
	-- a dark flash sphere of blocks at the body
	local flash = blk(Vector3.new(2, 2, 2), color, CFrame.new(at), 0.1)
	TweenService:Create(flash, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = Vector3.new(14, 14, 14), Transparency = 1 }):Play()
	Debris:AddItem(flash, 0.4)
	-- three voxel rings racing out over the ground
	for ring = 0, 2 do
		task.delay(ring * 0.12, function()
			local n = 28
			for i = 1, n do
				local a = i / n * math.pi * 2
				local dir = Vector3.new(math.cos(a), 0, math.sin(a))
				local b = blk(Vector3.new(1.1, 0.5, 1.1), i % 3 == 0 and core or color, CFrame.new(feet + dir * 2 + Vector3.new(0, 0.3, 0)), 0.05)
				TweenService:Create(b, TweenInfo.new(0.5, Enum.EasingStyle.Quart), { CFrame = CFrame.new(feet + dir * radius + Vector3.new(0, 0.3, 0)), Transparency = 1 }):Play()
				Debris:AddItem(b, 0.55)
			end
		end)
	end
	-- lightning crackling outward, then a few more bolts flickering around the body
	for _ = 1, 10 do
		local a = math.random() * math.pi * 2
		local len = radius * (0.35 + math.random() * 0.5)
		local tip = at + Vector3.new(math.cos(a) * len, (math.random() - 0.3) * 6, math.sin(a) * len)
		task.delay(math.random() * 0.25, bolt, at, tip, color, core, 0.3)
	end
	for k = 1, 6 do
		task.delay(0.3 + k * 0.08, function()
			if root.Parent then
				local a = math.random() * math.pi * 2
				local p = root.Position
				bolt(p + Vector3.new(0, math.random() * 2, 0), p + Vector3.new(math.cos(a) * 5, math.random() * 4 - 1, math.sin(a) * 5), color, core, 0.18)
			end
		end)
	end
	pcall(function()
		local Audio = require(script.Parent.Audio)
		Audio.Play("ThunderCrack", { pos = at })
		Audio.Play("FinisherBoom", { pos = at })
	end)
	-- the roarer's own pose (it replicates)
	if char == Players.LocalPlayer.Character then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			require(ReplicatedStorage.Shared.Modules.Anim).Play(hum, "Skill_PowerUp")
		end
	end
	Voxels.Pixels(at, { count = 40, colors = { color, core }, size = 0.35, speed = 26, gravity = 0, life = 0.5, glow = 1, spread = 2 })
	-- everyone it reaches feels it
	local me = Players.LocalPlayer.Character
	local myRoot = me and me:FindFirstChild("HumanoidRootPart")
	if myRoot and (myRoot.Position - at).Magnitude <= radius + 10 then
		shake(myRoot == root and 0.6 or 1.1, 0.5)
		screenEdge(color)
	end
	-- a little bolt drops on every monster that froze
	for _, m in ipairs(type(d.cowed) == "table" and d.cowed or {}) do
		local mr = typeof(m) == "Instance" and (m.PrimaryPart or m:FindFirstChild("HumanoidRootPart"))
		if mr then
			task.delay(0.15, bolt, mr.Position + Vector3.new(0, 7, 0), mr.Position, color, core, 0.25)
		end
	end
end

function TokiFX.Start()
	folder = Instance.new("Folder")
	folder.Name = "TokiFX"
	folder.Parent = workspace
	Net.OnFX(function(kind, d)
		if kind == "TokiRoar" and type(d) == "table" then
			local ok, err = pcall(roar, d)
			if not ok then
				warn("[TokiFX]", err)
			end
		end
	end)
end

return TokiFX
