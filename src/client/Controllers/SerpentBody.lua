-- SerpentBody (client, v0.22.5): draws the body + tail of full-length serpent bosses (Bay Serpent). The server moves
-- only the head (the monster model); here the body follows the head's trail every frame (Shared/Modules/SerpentChain,
-- the same math the server uses for hit areas), with a side-to-side slither that grows while it moves and a slow
-- breathing sway at rest. A tail slam (SerpentTail FX) lifts the tail and brings it down on the telegraphed circle.
-- Pieces are Assets.Serpent.Seg / .Tail (tools/blender/serpent.py), scaled down toward the tail; plain parts if the
-- meshes are not loaded. Clicking a body piece targets the serpent (attribute SerpentOf = its MobUid).
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Chain = require(ReplicatedStorage.Shared.Modules.SerpentChain)

local SerpentBody = {}
local active = {} -- model -> state
local UP = Vector3.yAxis
-- how far each mesh's pivot (its bounding-box center) sits above the body's center line, at full size
local LIFT = { Seg = 1.8, Tail = 1.5 }

local function template(name)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local f = assets and assets:FindFirstChild("Serpent")
	return f and f:FindFirstChild(name)
end

local function fallback(spec, tail)
	local m = Instance.new("Model")
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * spec.radius * 2
	p.Color = tail and Color3.fromRGB(40, 140, 160) or Color3.fromRGB(50, 160, 180)
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = m
	m.PrimaryPart = p
	return m
end

local function build(model)
	local def = Monsters[model:GetAttribute("MonsterId") or ""]
	local spec = def and def.serpent
	local root = model.PrimaryPart
	if not spec or not root then
		return
	end
	local folder = Instance.new("Model")
	folder.Name = "GVSerpentBody"
	folder.Parent = workspace
	local uid = model:GetAttribute("MobUid")
	local pieces = {}
	for _, o in ipairs(Chain.Offsets(spec)) do
		local kind = o.tail and "Tail" or "Seg"
		local tpl = template(kind)
		local m = tpl and tpl:Clone() or fallback(spec, o.tail)
		if o.scale ~= 1 then
			m:ScaleTo(m:GetScale() * o.scale)
		end
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
				p.CanTouch = false
				p.CanQuery = true -- click the body to target the serpent
				p:SetAttribute("SerpentOf", uid)
			end
		end
		m.Parent = folder
		table.insert(pieces, { model = m, lift = (tpl and LIFT[kind] or 0) * o.scale, tail = o.tail })
	end
	local st = { model = model, spec = spec, folder = folder, pieces = pieces, chain = Chain.New(spec), phase = 0, slamUntil = 0, slamTime = 1 }
	local neck = model:GetAttribute("NeckOffset") or Vector3.new(0, -4, 8)
	Chain.Reset(st.chain, root.CFrame:PointToWorldSpace(neck), -root.CFrame.LookVector)
	active[model] = st
end

local function dissolve(st)
	for _, pc in ipairs(st.pieces) do
		for _, p in ipairs(pc.model:GetDescendants()) do
			if p:IsA("BasePart") then
				TweenService:Create(p, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			end
		end
	end
	task.delay(0.65, function()
		st.folder:Destroy()
	end)
end

-- tail slam: lift the tail for `time` seconds, then smash it down
function SerpentBody.TailSlam(model, time)
	local st = active[model]
	if st then
		st.slamTime = time or 1
		st.slamUntil = os.clock() + st.slamTime
	end
end

local function update(st, dt)
	local model = st.model
	local root = model.PrimaryPart
	if not model.Parent or not root or (model:GetAttribute("HP") or 1) <= 0 then
		active[model] = nil
		dissolve(st)
		return
	end
	local neck = model:GetAttribute("NeckOffset") or Vector3.new(0, -4, 8)
	local anchor = root.CFrame:PointToWorldSpace(neck)
	Chain.Push(st.chain, anchor)
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	st.moving = (st.moving or 0) + ((speed > 2 and 1 or 0) - (st.moving or 0)) * math.min(1, dt * 3)
	st.phase += dt * (1.4 + math.min(speed, 30) * 0.22)
	local amp = 0.5 + 1.8 * st.moving
	local now = os.clock()
	local slamLeft = st.slamUntil - now
	local n = #st.pieces
	for i, pc in ipairs(Chain.Pieces(st.chain, anchor)) do
		local piece = st.pieces[i]
		if piece then
			local dir = pc.dir
			local flat = Vector3.new(dir.X, 0, dir.Z)
			flat = flat.Magnitude > 1e-3 and flat.Unit or Vector3.new(0, 0, -1)
			local right = flat:Cross(UP)
			-- the slither: a sideways wave travelling down the body, none at the neck
			local wave = math.sin(st.phase - pc.d * 0.17) * amp * math.clamp(pc.d / 14, 0, 1)
			local pos = pc.pos + right * wave + UP * piece.lift
			-- tail slam: the last pieces rise while it winds up, then drop
			if slamLeft > -0.25 and i >= n - 2 then
				local k = (i - (n - 3)) / 3
				local up = slamLeft > 0 and (1 - slamLeft / st.slamTime) * 9 * k or 0
				pos += UP * up
			end
			local look = (flat + right * (math.cos(st.phase - pc.d * 0.17) * amp * 0.09)).Unit
			piece.model:PivotTo(CFrame.lookAt(pos, pos + look))
		end
	end
end

local function watch(m)
	if m:IsA("Model") and not active[m] then
		local def = Monsters[m:GetAttribute("MonsterId") or ""]
		if def and def.serpent then
			-- wait for the head to replicate its root + offsets
			task.delay(0.3, function()
				if m.Parent and not active[m] then
					build(m)
				end
			end)
		end
	end
end

function SerpentBody.Start()
	local folder = workspace:WaitForChild("Monsters", 60)
	if not folder then
		return
	end
	for _, m in ipairs(folder:GetChildren()) do
		watch(m)
	end
	folder.ChildAdded:Connect(function(m)
		task.wait(0.2)
		watch(m)
	end)
	RunService.RenderStepped:Connect(function(dt)
		for _, st in pairs(active) do
			local ok, err = pcall(update, st, dt)
			if not ok then
				warn("[SerpentBody]", err)
				active[st.model] = nil
			end
		end
	end)
end

return SerpentBody
