-- GrassField (client): makes the island plants feel alive without the cost of a grass carpet.
-- The server scatters a modest number of stylized plants (World.Greenery: tall grass tufts, ferns, leafy plants,
-- flowers...). Here only the plants near the camera sway in the wind, all moved in one workspace:BulkMoveTo call.
-- (A dense carpet of 3D grass patches was tried in v0.10.1 and lagged; the ground is the painted GV_Grass texture.)
local RunService = game:GetService("RunService")

local GrassField = {}

local RANGE = 48 -- studs around the camera that sway
local base = {} -- part -> { cf = original CFrame, phase, amp }

function GrassField.Start()
	task.spawn(function()
		local world = workspace:WaitForChild("World", 120)
		if not world then
			return
		end
		local near = {}
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
			if swayAcc >= 1 / 20 and #near > 0 then
				swayAcc = 0
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
