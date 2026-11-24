-- GrassField (client): makes the island plants feel alive without the cost of a grass carpet.
-- The server scatters a modest number of stylized plants (World.Greenery: tall grass tufts, ferns, leafy plants,
-- flowers...). Here only the plants near the camera sway in the wind, all moved in one workspace:BulkMoveTo call.
-- (A dense carpet of 3D grass patches was tried in v0.10.1 and lagged; the ground is the painted GV_Grass texture.)
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local GrassField = {}

local RANGE = 48 -- studs around the camera that sway
local base = {} -- part -> { cf = original CFrame, phase, amp }
-- v0.25.134 (owner): trees + bushes sway too (dressed EnvProp models), slower and smaller than the plants, the
-- whole tree leaning from its foot (Base attribute); the invisible Collider part never moves
local TREE_RANGE = 170
local TREE_MAX = 260
local TREE_AMP = { RoundTree = 0.022, BroadTree = 0.018, PineTree = 0.016, Pine = 0.016, Palm = 0.03, Bush = 0.035 }
local treeBase = {} -- part -> { cf, rel = foot:Inverse() * cf, foot, phase, amp }

function GrassField.Start()
	task.spawn(function()
		local world = workspace:WaitForChild("World", 120)
		if not world then
			return
		end
		local near = {}
		local trees = {}
		local treeAcc = 1
		local scanAcc, swayAcc = 0, 0
		RunService.Heartbeat:Connect(function(dt)
			scanAcc += dt
			swayAcc += dt
			local cam = workspace.CurrentCamera
			if not cam then
				return
			end
			local focus = cam.Focus.Position
			-- every 0.5 s: which plants are close enough to bother animating
			if scanAcc >= 0.5 then
				scanAcc = 0
				local folder = world:FindFirstChild("Greenery")
				near = {}
				if folder and focus.Y < 160 then
					for _, m in ipairs(folder:GetChildren()) do
						local p = m:FindFirstChildWhichIsA("BasePart")
						if p then
							local e = base[p]
							if not e then
								local s = p.Size.Y
								e = { cf = p.CFrame, phase = (p.Position.X * 0.37 + p.Position.Z * 0.21) % 6.28, amp = s > 2 and 0.06 or 0.09, lift = CFrame.new(0, s / 2, 0) }
								e.root = e.cf * CFrame.new(0, -s / 2, 0) -- sway pivots at the plant's foot
								base[p] = e
							end
							local d = e.cf.Position - focus
							if d.X * d.X + d.Z * d.Z < RANGE * RANGE then
								table.insert(near, p)
							end
						end
					end
				end
			end
			-- every 1 s: dressed trees near the camera (parts parented to nil by WorldCull are skipped)
			treeAcc += dt
			if treeAcc >= 1 then
				treeAcc = 0
				trees = {}
				if focus.Y < 220 then
					for _, m in ipairs(CollectionService:GetTagged("EnvProp")) do
						local foot = m:GetAttribute("Base")
						local amp = TREE_AMP[m:GetAttribute("Kind") or ""]
						if amp and foot and m:GetAttribute("Dressed") and m.Parent then
							local dx, dz = foot.X - focus.X, foot.Z - focus.Z
							if dx * dx + dz * dz < TREE_RANGE * TREE_RANGE then
								local phase = (foot.X * 0.13 + foot.Z * 0.29) % 6.28
								for _, p in ipairs(m:GetChildren()) do
									if p:IsA("BasePart") and not p:GetAttribute("Collider") then
										local e = treeBase[p]
										if not e then
											local f = CFrame.new(foot)
											e = { foot = f, rel = f:Inverse() * p.CFrame, phase = phase, amp = amp }
											treeBase[p] = e
										end
										table.insert(trees, p)
									end
								end
								if #trees >= TREE_MAX then
									break
								end
							end
						end
					end
				end
			end
			local tick = swayAcc >= 1 / 20
			if tick then
				swayAcc = 0
			end
			if tick and #trees > 0 then
				local t = os.clock()
				local cfs = table.create(#trees)
				for i, p in ipairs(trees) do
					local e = treeBase[p]
					local gust = 0.55 + 0.45 * math.sin(t * 0.45 + e.phase * 0.5)
					cfs[i] = e.foot * CFrame.Angles(math.sin(t * 1.1 + e.phase) * e.amp * gust, 0, math.cos(t * 0.8 + e.phase) * e.amp * 0.7 * gust) * e.rel
				end
				workspace:BulkMoveTo(trees, cfs, Enum.BulkMoveMode.FireCFrameChanged)
			end
			if tick and #near > 0 then
				local t = os.clock()
				local cfs = table.create(#near)
				for i, p in ipairs(near) do
					local e = base[p]
					local gust = 0.6 + 0.4 * math.sin(t * 0.7 + e.phase * 0.3)
					cfs[i] = e.root * CFrame.Angles(math.sin(t * 2.0 + e.phase) * e.amp * gust, 0, math.cos(t * 1.6 + e.phase) * e.amp * 0.6 * gust) * e.lift
				end
				workspace:BulkMoveTo(near, cfs, Enum.BulkMoveMode.FireCFrameChanged)
			end
		end)
	end)
end

return GrassField
