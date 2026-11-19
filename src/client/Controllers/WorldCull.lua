-- WorldCull (client, v0.24.14, mobile pass): the baked voxel map is ~41,000 parts and islands sit 1,800 studs apart,
-- so this client unloads the plain map pieces of islands far from the camera (parent = nil locally) and brings them
-- back as you come closer. Only untagged, anchored scenery is touched: NPCs, chests, docks, plots, spawns, prompts and
-- anything else carrying a CollectionService tag (or inside a tagged model) always stays, so quests, markers and
-- interactions keep working everywhere. The server is never affected (it is a local view change).
-- Distances follow the graphics preset (Settings.Knobs: cull), with a little hysteresis; work is spread over frames.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Islands = require(ReplicatedStorage.Shared.Config.Islands)
local Settings = require(script.Parent.Settings)

local WC = {}
local BATCH = 500 -- parts moved per frame
local CULL = { Low = 1150, Medium = 1500, High = 2100, Ultra = 2700 }
local zones = {} -- { model, center, radius, hidden = bool, stash = { {part, parent} }, busy }
WC.Stats = { hidden = 0 }

local function protected(inst, root)
	-- tagged itself or inside a tagged model, or something the player interacts with
	local a = inst
	while a and a ~= root do
		if #CollectionService:GetTags(a) > 0 then
			return true
		end
		a = a.Parent
	end
	return inst:FindFirstChildWhichIsA("ProximityPrompt", true) ~= nil
end

local function hide(z)
	z.busy = true
	z.stash = {}
	local list = {}
	for _, d in ipairs(z.model:GetDescendants()) do
		if d:IsA("BasePart") and d.Anchored and not protected(d, z.model) then
			table.insert(list, d)
		end
	end
	for i, p in ipairs(list) do
		if p.Parent then
			table.insert(z.stash, { p, p.Parent })
			p.Parent = nil
		end
		if i % BATCH == 0 then
			task.wait()
		end
	end
	WC.Stats.hidden += #z.stash
	z.hidden = true
	z.busy = false
end

-- now = true: everything at once (you are standing on it: a teleport, a respawn), else spread over frames, the
-- pieces nearest to the camera first
local function show(z, now, at)
	z.busy = true
	local stash = z.stash or {}
	z.stash = nil
	if at then
		table.sort(stash, function(a, b)
			return (a[1].Position - at).Magnitude < (b[1].Position - at).Magnitude
		end)
	end
	for i, e in ipairs(stash) do
		local p, parent = e[1], e[2]
		if parent.Parent or parent == z.model then
			p.Parent = parent
		end
		if not now and i % BATCH == 0 then
			task.wait()
		end
	end
	WC.Stats.hidden -= #stash
	z.hidden = false
	z.busy = false
end

function WC.Start()
	local world = workspace:WaitForChild("World", 60)
	if not world then
		return
	end
	task.wait(4) -- let the map finish streaming in / being dressed
	for _, isl in ipairs(Islands.List) do
		local m = world:FindFirstChild(isl.id)
		if m and m:IsA("Model") then
			local ok, cf, size = pcall(m.GetBoundingBox, m)
			if ok then
				table.insert(zones, { model = m, center = Vector3.new(cf.Position.X, 0, cf.Position.Z), radius = math.max(size.X, size.Z) / 2, hidden = false })
			end
		end
	end
	local acc = 0
	local player = game:GetService("Players").LocalPlayer
	RunService.Heartbeat:Connect(function(dt)
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		-- every frame (cheap): standing on / right next to a hidden island (teleport, respawn) -> bring it back NOW
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		for _, z in ipairs(zones) do
			if z.hidden and not z.busy then
				for _, at in ipairs({ cam.Focus.Position, root and root.Position }) do
					if at and Vector3.new(at.X - z.center.X, 0, at.Z - z.center.Z).Magnitude - z.radius < 120 then
						show(z, true)
						break
					end
				end
			end
		end
		acc += dt
		if acc < 1 then
			return
		end
		acc = 0
		local at = cam.Focus.Position
		local far = CULL[Settings.Values.quality] or CULL.High
		for _, z in ipairs(zones) do
			if not z.busy then
				local d = Vector3.new(at.X - z.center.X, 0, at.Z - z.center.Z).Magnitude - z.radius
				if not z.hidden and d > far then
					task.spawn(hide, z)
				elseif z.hidden and d < far - 200 then
					task.spawn(show, z, false, at)
				end
			end
		end
	end)
end

return WC
