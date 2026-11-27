-- Parkour (remake R1, docs/Plan-Movement-Combat-v3.md sec 4: S1 slide, S2 climb, S3 wall run, S4 ledge hang + climb up,
-- S5 vault, S6 wall-to-wall jumps, S7 flip off a wall, S10 landing roll). Numbers in GameConfig.Parkour.
--
-- Controls (keyboard; touch uses the jump button + the thumbstick the same way):
--   Space in the air facing a wall        -> CLIMB   (push into the wall = up, away = down, sideways = sideways;
--                                                     Space = flip off the wall; reaching the top = hang)
--   Space in the air beside a wall, fast  -> WALL RUN (along the wall for WallRunTime; Space = jump off -> next wall)
--   falling past a ledge, pushing into it -> HANG    (into the wall / Space = climb up, away = let go)
--   Space (or running) into a low wall    -> VAULT   (thick blocks: climb up onto them)
--   Slide key (Ctrl) while running        -> SLIDE   (Space = slide jump keeps the speed)
--   Dash key just before a big landing    -> ROLL    (the server takes RollMult of the fall damage; running fast
--                                                     into a landing rolls by itself)
-- Climbing, wall running and hanging drain stamina (Controllers/Stamina); empty = you drop.
-- Movement is client physics (the character is ours): PlatformStand + LinearVelocity + AlignOrientation like Flight.
-- The server only hears "grab" (a wall stopped my fall: GuardService checks there is a wall) and "roll".
-- Animations: AnimClips Parkour_* (not uploaded yet: they play in Studio through the runtime fallback).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Anim = require(ReplicatedStorage.Shared.Modules.Anim)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Hotkeys = require(script.Parent.Hotkeys)
local Stamina = require(script.Parent.Stamina)

local Parkour = {}
local P = GameConfig.Parkour
local player = Players.LocalPlayer
local Y = Vector3.yAxis

local mode = nil -- nil | "climb" | "wallrun" | "hang" | "mantle" | "vault" | "slide"
local d = {} -- data of the current mode
local att, lv, ao
local clip -- the looping clip of the current mode
local jumpQueued = false -- a fresh jump press not handled yet
local lastJumpReq = 0
local lastWallN, kickAt = nil, -99 -- the wall we just left (no re-grab of the same wall for a moment)
local fall = { minV = 0, rollArmed = false } -- current airborne stretch
local rollAt = -99

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.RespectCanCollide = true
rp.IgnoreWater = true

local function parts()
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return c, h, r
end

local function refreshFilter(c)
	local list = { c }
	for _, name in ipairs({ "Monsters", "Pets", "Drops", "Effects", "FX", "FarIslands" }) do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= player and pl.Character then
			table.insert(list, pl.Character)
		end
	end
	rp.FilterDescendantsInstances = list
end

local function cast(origin, dir)
	return workspace:Raycast(origin, dir, rp)
end

-- a steep wall hit along dir from origin (len studs)
local function wall(origin, dir, len)
	local hit = cast(origin, dir.Unit * len)
	if hit and math.abs(hit.Normal.Y) < 0.35 then
		return hit
	end
	return nil
end

local function flat(v)
	v = Vector3.new(v.X, 0, v.Z)
	return v.Magnitude > 1e-3 and v.Unit or nil
end

local function rootH(h, r)
	return h.HipHeight + r.Size.Y / 2
end

local function grounded(h)
	return h.FloorMaterial ~= Enum.Material.Air
end

local function busyElsewhere(c, h)
	if c:GetAttribute("Downed") or h.Sit or h:GetAttribute("Stunned") or player:GetAttribute("Vending") then
		return true
	end
	if h:GetState() == Enum.HumanoidStateType.Swimming then
		return true
	end
	local okF, flying = pcall(function()
		return require(script.Parent.Flight).IsFlying()
	end)
	local okS, swimming = pcall(function()
		return require(script.Parent.Swim).IsSwimming()
	end)
	return (okF and flying) or (okS and swimming)
end

local function playClip(h, name, fade)
	if clip == name then
		return
	end
	if clip then
		Anim.Stop(h, clip, 0.12)
	end
	clip = name
	if name then
		Anim.Play(h, name, { fade = fade or 0.1 })
	end
end

local function attach(r, h)
	if not att then
		att = Instance.new("Attachment")
		att.Name = "ParkourAtt"
		att.Parent = r
		lv = Instance.new("LinearVelocity")
		lv.Attachment0 = att
		lv.MaxForce = 1e6
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VectorVelocity = Vector3.zero
		lv.Parent = r
		ao = Instance.new("AlignOrientation")
		ao.Attachment0 = att
		ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
		ao.MaxTorque = 1e6
		ao.Responsiveness = 30
		ao.CFrame = r.CFrame.Rotation
		ao.Parent = r
	end
	h.PlatformStand = true
	h.AutoRotate = false
end

local function detach(h)
	for _, o in ipairs({ lv, ao, att }) do
		if o then
			o:Destroy()
		end
	end
	att, lv, ao = nil, nil, nil
	if h then
		h.PlatformStand = false
		h.AutoRotate = true
	end
end

-- end the current mode; how = "fall" (keep momentum, freefall) | "land" (standing on top) | "keep" (slide: leave state)
local function stop(how)
	local _, h, r = parts()
	local was = mode
	mode = nil
	d = {}
	if h then
		playClip(h, nil)
	end
	if was == "slide" then
		detach(nil) -- the slide never set PlatformStand
		return
	end
	detach(h)
	if h and r and how ~= "keep" then
		h:ChangeState(how == "land" and Enum.HumanoidStateType.Landed or Enum.HumanoidStateType.Freefall)
	end
end

local function face(r, dir, roll)
	if ao and dir then
		ao.CFrame = CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles(0, 0, roll or 0)
	end
end

local function grabbed()
	task.spawn(Net.Request, "Parkour", { kind = "grab" })
end

-- ===== ledge: chest ray hits a wall, a ray above the head does not, the top is within reach =====
local function findLedge(r, h, dir)
	local base = r.Position
	local chest = wall(base + Y * 0.4, dir, 3)
	if not chest then
		return nil
	end
	local n = flat(chest.Normal)
	if not n then
		return nil
	end
	if wall(base + Y * 2.9, -n, 3.2) then
		return nil -- the wall goes on above the head: no ledge here
	end
	local probe = chest.Position - n * 0.7 + Y * 3.4
	local top = cast(probe, -Y * 3.6)
	if not top or top.Normal.Y < 0.7 then
		return nil
	end
	local topY = top.Position.Y
	if topY < base.Y - 0.2 or topY > base.Y + 3.2 then
		return nil
	end
	-- room to stand on the top
	if cast(Vector3.new(chest.Position.X, topY + 0.2, chest.Position.Z) - n * 1.4, Y * (rootH(h, r) * 2)) then
		return nil
	end
	return { n = n, edge = Vector3.new(chest.Position.X, topY, chest.Position.Z), topY = topY }
end

local function startHang(r, h, ledge)
	mode = "hang"
	d = { n = ledge.n, edge = ledge.edge, topY = ledge.topY }
	attach(r, h)
	face(r, -ledge.n)
	playClip(h, "Parkour_Hang")
	grabbed()
end

local function startMantle(r, h, edge, n, topY)
	mode = "mantle"
	local p0 = r.Position
	local p2 = Vector3.new(edge.X, topY + rootH(h, r) + 0.15, edge.Z) - n * 1.6
	d = { t = 0, p0 = p0, p1 = Vector3.new(p0.X, p2.Y + 0.6, p0.Z) + n * 0.1, p2 = p2, dur = P.MantleTime, n = n }
	attach(r, h)
	lv.MaxForce = 0
	face(r, -n)
	playClip(h, "Parkour_Mantle", 0.05)
end

local function startClimb(r, h, hit)
	local n = flat(hit.Normal)
	if not n then
		return false
	end
	mode = "climb"
	d = { n = n }
	attach(r, h)
	face(r, -n)
	playClip(h, "Parkour_Climb")
	grabbed()
	return true
end

local function startWallRun(r, h, hit, side, speed)
	local n = flat(hit.Normal)
	local v = flat(r.AssemblyLinearVelocity) or flat(r.CFrame.LookVector)
	if not n or not v then
		return false
	end
	local dir = flat(v - n * v:Dot(n))
	if not dir then
		return false
	end
	mode = "wallrun"
	d = { n = n, dir = dir, t = 0, side = side, speed = math.max(speed, P.WallRunMinSpeed) }
	attach(r, h)
	playClip(h, side == "L" and "Parkour_WallRunL" or "Parkour_WallRunR")
	grabbed()
	return true
end

-- jump away from a wall (from a wall run: forward + out; from a climb: a back flip)
local function kickOff(r, h, n, along, flip)
	stop("fall")
	lastWallN, kickAt = n, os.clock()
	local v = n * P.WallJumpOut + Y * P.WallJumpUp
	if along then
		v = along * 0.85 + n * P.WallJumpOut * 0.8 + Y * P.WallJumpUp * 0.85
	end
	if flip then
		r.CFrame = CFrame.lookAt(r.Position, r.Position + n)
	end
	r.AssemblyLinearVelocity = v
	Anim.Play(h, flip and "Parkour_WallFlip" or "Parkour_WallJump", { fade = 0.05 })
	Stamina.Drain(4)
end

local function recentlyLeft(n)
	return lastWallN and os.clock() - kickAt < 0.45 and n:Dot(lastWallN) > 0.9
end

-- ===== vault: a low obstacle ahead (VaultMin..VaultMax above the feet); thin = over it, thick = up onto it =====
local function tryVault(r, h, dir)
	local feet = r.Position.Y - rootH(h, r)
	local low = wall(Vector3.new(r.Position.X, feet + 1.0, r.Position.Z), dir, P.VaultReach)
	if not low then
		return false
	end
	local n = flat(low.Normal)
	if not n or dir:Dot(-n) < 0.5 then
		return false
	end
	local fwd = -n
	local o = Vector3.new(low.Position.X, feet + P.VaultMax + 1, low.Position.Z) + fwd * 0.6
	local top = cast(o, -Y * (P.VaultMax + 1))
	if not top or top.Normal.Y < 0.7 then
		return false
	end
	local topY = top.Position.Y
	local hgt = topY - feet
	if hgt < P.VaultMin or hgt > P.VaultMax then
		return false
	end
	local rh = rootH(h, r)
	if cast(top.Position + Y * 0.2, Y * (rh * 2 + 0.5)) then
		return false -- no headroom over it
	end
	-- how thick: walk along the top until it drops away
	local edgeK
	for k = 1, P.VaultDepth do
		local p = Vector3.new(low.Position.X, topY + 1, low.Position.Z) + fwd * (k + 0.4)
		local g = cast(p, -Y * 1.6)
		if not g or g.Position.Y < topY - 0.6 then
			edgeK = k
			break
		end
	end
	local p0 = r.Position
	if not edgeK then
		-- thick block: climb up onto it
		startMantle(r, h, Vector3.new(low.Position.X, topY, low.Position.Z), n, topY)
		return true
	end
	local far = Vector3.new(low.Position.X, topY, low.Position.Z) + fwd * (edgeK + 1.8)
	local g = cast(far + Y * 1, -Y * (hgt + 6))
	if not g then
		return false
	end
	mode = "vault"
	local p2 = Vector3.new(far.X, g.Position.Y + rh, far.Z)
	local mid = Vector3.new(low.Position.X, topY + rh * 0.55 + 0.6, low.Position.Z) + fwd * (edgeK * 0.5)
	local speed = math.max(flat(r.AssemblyLinearVelocity) and Vector3.new(r.AssemblyLinearVelocity.X, 0, r.AssemblyLinearVelocity.Z).Magnitude or 0, h.WalkSpeed)
	d = { t = 0, p0 = p0, p1 = mid + Y * 1.2, p2 = p2, dur = P.VaultTime, dir = fwd, speed = speed }
	attach(r, h)
	lv.MaxForce = 0
	face(r, fwd)
	playClip(h, "Parkour_Vault", 0.04)
	return true
end

-- ===== slide =====
local function startSlide(r, h)
	local base = player:GetAttribute("BaseSpeed") or 16
	local v = Vector3.new(r.AssemblyLinearVelocity.X, 0, r.AssemblyLinearVelocity.Z)
	local dir = flat(h.MoveDirection) or flat(r.CFrame.LookVector)
	if not dir then
		return false
	end
	local speed = math.max(v.Magnitude, base * GameConfig.Sprint.Mult) * P.SlideBoost
	mode = "slide"
	d = { t = 0, dir = dir, v0 = speed, v1 = base * 0.55 }
	att = Instance.new("Attachment")
	att.Name = "ParkourAtt"
	att.Parent = r
	lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = math.huge
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.PlaneVelocity = Vector2.new(dir.X, dir.Z) * speed
	lv.Parent = r
	r.CFrame = CFrame.lookAt(r.Position, r.Position + dir)
	h.AutoRotate = false
	playClip(h, "Parkour_Slide", 0.05)
	return true
end

local function stopSlide(h)
	stop("keep")
	if h then
		h.AutoRotate = true
	end
end

-- ===== public =====
function Parkour.Busy()
	return mode ~= nil
end

function Parkour.Mode()
	return mode
end

-- the Dash key in the air just before a landing = roll (Combat.Dash asks first; true = handled, no dash)
function Parkour.TryRoll()
	local c, h, r = parts()
	if not h or not r or grounded(h) or mode then
		return false
	end
	if r.AssemblyLinearVelocity.Y > -P.RollFall * 0.6 then
		return false
	end
	refreshFilter(c)
	if not cast(r.Position, -Y * (rootH(h, r) + P.RollNear)) then
		return false
	end
	rollAt = os.clock()
	fall.rollArmed = true
	task.spawn(Net.Request, "Parkour", { kind = "roll" })
	return true
end

local function onJumpPress()
	jumpQueued = true
end

function Parkour.Start()
	-- (Space is bound by Roblox's own jump action, so it always arrives "processed": only a focused text box stops it)
	UserInputService.InputBegan:Connect(function(io)
		if (io.KeyCode == Enum.KeyCode.Space or io.KeyCode == Enum.KeyCode.ButtonA) and not UserInputService:GetFocusedTextBox() then
			onJumpPress()
		end
	end)
	-- touch: the jump button only reaches us as JumpRequest (fires again while held: a gap = a fresh press)
	UserInputService.JumpRequest:Connect(function()
		local now = os.clock()
		if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and now - lastJumpReq > 0.18 then
			onJumpPress()
		end
		lastJumpReq = now
	end)
	Hotkeys.On("Slide", function()
		local c, h, r = parts()
		if not h or not r or mode or busyElsewhere(c, h) or not grounded(h) then
			return false
		end
		local running = require(script.Parent.Sprint).IsRunning()
		local speed = Vector3.new(r.AssemblyLinearVelocity.X, 0, r.AssemblyLinearVelocity.Z).Magnitude
		local base = player:GetAttribute("BaseSpeed") or 16
		if not running and speed < base * 1.25 then
			return false
		end
		if not Stamina.Use(P.SlideCost) then
			return true
		end
		startSlide(r, h)
		return true
	end)
	player.CharacterAdded:Connect(function()
		mode, d, clip = nil, {}, nil
		att, lv, ao = nil, nil, nil
		fall = { minV = 0, rollArmed = false }
	end)

	local filterAt = 0
	RunService.RenderStepped:Connect(function(dt)
		local c, h, r = parts()
		local jump = jumpQueued
		jumpQueued = false
		if not h or not r or h.Health <= 0 then
			return
		end
		local now = os.clock()
		if now - filterAt > 1 then
			filterAt = now
			refreshFilter(c)
		end
		if busyElsewhere(c, h) then
			if mode then
				stop(mode == "slide" and "keep" or "fall")
			end
			return
		end
		local md = h.MoveDirection
		local onGround = grounded(h)

		-- landing bookkeeping (roll)
		if onGround and not mode then
			if fall.minV < -P.RollFall and now - rollAt < P.RollWindow then
				local dir = flat(md) or flat(r.CFrame.LookVector)
				Anim.Play(h, "Parkour_Roll", { fade = 0.04 })
				if dir then
					r.AssemblyLinearVelocity = dir * 26 + Y * r.AssemblyLinearVelocity.Y
				end
			end
			fall.minV, fall.rollArmed = 0, false
		elseif not onGround then
			fall.minV = math.min(fall.minV, r.AssemblyLinearVelocity.Y)
		end

		if mode == "climb" then
			local hit = wall(r.Position + Y * 0.4, -d.n, 3)
			if not hit then
				local ledge = findLedge(r, h, -d.n)
				if ledge then
					startHang(r, h, ledge)
				else
					stop("fall")
				end
				return
			end
			d.n = flat(hit.Normal) or d.n
			local n = d.n
			if jump then
				kickOff(r, h, n, nil, true)
				return
			end
			if not Stamina.Drain(P.ClimbPerSec * dt) then
				stop("fall")
				return
			end
			-- top of the wall reached: hang on the ledge (and climb up if still pushing up)
			if not wall(r.Position + Y * 2.9, -n, 3.2) then
				local ledge = findLedge(r, h, -n)
				if ledge then
					startHang(r, h, ledge)
					return
				end
			end
			local right = (-n):Cross(Y).Unit
			local up = md:Dot(-n)
			local side = md:Dot(right)
			if up < -0.3 and cast(r.Position, -Y * (rootH(h, r) + 0.4)) then
				stop("land") -- climbed back down to the floor
				return
			end
			local dist = (hit.Position - r.Position):Dot(-n)
			lv.VectorVelocity = Y * (up * P.ClimbSpeed) + right * (side * P.ClimbSide) - n * (dist - 1.4) * 8
			face(r, -n)
			local tr = Anim.Track(h, "Parkour_Climb")
			if tr then
				tr:AdjustSpeed(math.clamp(math.abs(up) + math.abs(side), 0.05, 1.2))
			end
			return
		elseif mode == "hang" then
			local n = d.n
			if not Stamina.Drain(P.HangPerSec * dt) then
				stop("fall")
				return
			end
			local up = md:Dot(-n)
			if jump or up > 0.5 then
				startMantle(r, h, d.edge, n, d.topY)
				return
			end
			if up < -0.5 then
				lastWallN, kickAt = n, os.clock()
				stop("fall")
				return
			end
			local target = Vector3.new(d.edge.X, d.topY - rootH(h, r) * 0.55 - 0.9, d.edge.Z) + n * 1.25
			lv.VectorVelocity = (target - r.Position) * 12
			face(r, -n)
			return
		elseif mode == "mantle" or mode == "vault" then
			d.t += dt
			local k = math.clamp(d.t / d.dur, 0, 1)
			local e = 1 - (1 - k) ^ 2
			local a = d.p0:Lerp(d.p1, e)
			local b = d.p1:Lerp(d.p2, e)
			local p = a:Lerp(b, e)
			local look = d.dir or -d.n
			r.CFrame = CFrame.lookAt(p, p + look)
			r.AssemblyLinearVelocity = Vector3.zero
			if k >= 1 then
				local keep = mode == "vault" and d.dir * d.speed or nil
				stop("land")
				if keep then
					r.AssemblyLinearVelocity = keep
				end
			end
			return
		elseif mode == "wallrun" then
			d.t += dt
			local hit = wall(r.Position, -d.n, 3.4)
			if not hit or d.t > P.WallRunTime or onGround then
				stop("fall")
				return
			end
			if not Stamina.Drain(P.WallRunPerSec * dt) then
				stop("fall")
				return
			end
			local n = flat(hit.Normal) or d.n
			d.n = n
			d.dir = flat(d.dir - n * d.dir:Dot(n)) or d.dir
			if jump then
				kickOff(r, h, n, d.dir * d.speed, false)
				return
			end
			-- wall ahead along the run: stop
			if wall(r.Position, d.dir, 2.2) then
				stop("fall")
				return
			end
			local vy = P.WallRunUp * (1 - 2 * d.t / P.WallRunTime)
			local dist = (hit.Position - r.Position):Dot(-n)
			lv.VectorVelocity = d.dir * d.speed + Y * vy - n * (dist - 1.5) * 6
			face(r, d.dir, d.side == "L" and -0.28 or 0.28)
			return
		elseif mode == "slide" then
			d.t += dt
			local k = math.clamp(d.t / P.SlideTime, 0, 1)
			local speed = d.v0 + (d.v1 - d.v0) * (k ^ 0.8)
			if jump then
				stopSlide(h)
				r.AssemblyLinearVelocity = d.dir * speed * P.SlideJump + Y * math.max(r.AssemblyLinearVelocity.Y, 0)
				return
			end
			if k >= 1 or not onGround or wall(r.Position + Y * (-1.2), d.dir, 2.4) then
				stopSlide(h)
				return
			end
			lv.PlaneVelocity = Vector2.new(d.dir.X, d.dir.Z) * speed
			return
		end

		-- ===== not in a move: look for one =====
		if onGround then
			if jump and md.Magnitude > 0.3 then
				local dir = flat(md)
				if dir and tryVault(r, h, dir) then
					return
				end
			end
			-- running into a low wall vaults by itself
			if require(script.Parent.Sprint).IsRunning() and md.Magnitude > 0.5 then
				local dir = flat(md)
				local feet = r.Position.Y - rootH(h, r)
				if dir and wall(Vector3.new(r.Position.X, feet + 1.0, r.Position.Z), dir, 2.2) then
					tryVault(r, h, dir)
				end
			end
			return
		end

		local vel = r.AssemblyLinearVelocity
		local hspeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
		local look = flat(md) or flat(r.CFrame.LookVector)
		-- running fast into a landing: roll by itself
		if not fall.rollArmed and vel.Y < -P.RollFall and hspeed > (player:GetAttribute("BaseSpeed") or 16) * 1.35 then
			Parkour.TryRoll()
		end
		if jump and look then
			-- beside a wall while moving fast = wall run
			if hspeed >= P.WallRunMinSpeed and Stamina.Value() >= P.ClimbStart then
				local rightV = look:Cross(Y).Unit
				for _, s in ipairs({ { "R", rightV }, { "L", -rightV } }) do
					local hit = wall(r.Position, s[2], 3)
					local n = hit and flat(hit.Normal)
					if n and not recentlyLeft(n) and math.abs(look:Dot(n)) < 0.6 then
						if startWallRun(r, h, hit, s[1], hspeed) then
							return
						end
					end
				end
			end
			-- facing a wall = climb (or hang if the top is right there)
			local hit = wall(r.Position + Y * 0.4, look, 2.8)
			local n = hit and flat(hit.Normal)
			if n and look:Dot(-n) > 0.45 and not recentlyLeft(n) and Stamina.Value() >= P.ClimbStart then
				local ledge = findLedge(r, h, look)
				if ledge then
					startHang(r, h, ledge)
				else
					startClimb(r, h, hit)
				end
				return
			end
		end
		-- falling past a ledge while pushing into the wall = catch it
		if vel.Y < -4 and md.Magnitude > 0.5 and Stamina.Value() > 1 then
			local dir = flat(md)
			local ledge = dir and findLedge(r, h, dir)
			if ledge and dir:Dot(-ledge.n) > 0.5 and not recentlyLeft(ledge.n) then
				startHang(r, h, ledge)
			end
		end
	end)
end

return Parkour
