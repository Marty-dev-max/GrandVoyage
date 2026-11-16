-- DungeonService: per-party instanced dungeons: clear waves -> boss -> rewards
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Dungeons = require(Shared.Config.Dungeons)
local Islands = require(Shared.Config.Islands)
local Net = require(Shared.Modules.Net)
local ModelFactory = require(script.Parent.Parent.World.ModelFactory)

local DS = {}
local R
local instances = {}
local playerInstance = {}
local slot = 0

function DS.Init(registry)
	R = registry
end

local function buildRoom(def, origin)
	local folder = Instance.new("Model")
	folder.Name = "Dungeon_" .. def.name
	local P = ModelFactory.Part
	local floor = P(folder, Enum.PartType.Block, Vector3.new(150, 4, 150), def.theme.floor, CFrame.new(origin), { collide = true, material = Enum.Material.Slate })
	floor.Anchored = true
	for i = 0, 3 do
		local a = i * math.pi / 2
		local w = P(folder, Enum.PartType.Block, Vector3.new(150, 40, 6), def.theme.wall, CFrame.new(origin) * CFrame.Angles(0, a, 0) * CFrame.new(0, 20, 75), { collide = true })
		w.Anchored = true
	end
	-- Decorative pillars + lights
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local pillar = P(folder, Enum.PartType.Cylinder, Vector3.new(30, 5, 5), def.theme.wall:Lerp(Color3.new(0, 0, 0), 0.3), CFrame.new(origin + Vector3.new(math.cos(a) * 55, 15, math.sin(a) * 55)) * CFrame.Angles(0, 0, math.pi / 2), { collide = true })
		pillar.Anchored = true
		local light = Instance.new("PointLight")
		light.Range = 30
		light.Brightness = 2
		light.Color = Color3.fromRGB(255, 200, 140)
		light.Parent = pillar
	end
	for _, p in ipairs(folder:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Massless = false
		end
	end
	folder.Parent = workspace
	return folder
end

local function finish(inst, success)
	if inst.done then
		return
	end
	inst.done = true
	local def = inst.def
	for _, pl in ipairs(inst.players) do
		if pl.Parent then
			if success then
				R.PlayerService.AddBeli(pl, def.reward.beli)
				R.PlayerService.GiveExp(pl, def.reward.exp, def.reward.exp * 0.7)
				R.MonsterService.RollDrops(pl, { drops = def.reward.items, beli = nil }, 1)
				Net.Push(pl, "Banner", { title = "DUNGEON CLEAR!", subtitle = def.name })
				R.QuestService.Event(pl, "Dungeon", def.id)
			else
				Net.Push(pl, "Banner", { title = "TIME UP", subtitle = def.name })
			end
		end
	end
	task.delay(8, function()
		for _, pl in ipairs(inst.players) do
			if pl.Parent and playerInstance[pl] == inst then
				playerInstance[pl] = nil
				R.PlayerService.TeleportTo(pl, R.PlayerService.SpawnCFrame(def.island))
			end
		end
		for _, mob in ipairs(inst.mobs) do
			if not mob.dead then
				R.MonsterService.Kill(mob)
			end
		end
		inst.room:Destroy()
		instances[inst] = nil
	end)
end

local function spawnWave(inst)
	local def = inst.def
	inst.wave += 1
	local wave = def.waves[inst.wave]
	local list = wave
	local isBoss = false
	if not wave then
		list = { { def.boss, 1 } }
		isBoss = true
	end
	inst.alive = 0
	for _, group in ipairs(list) do
		for _ = 1, group[2] do
			inst.alive += 1
			local pos = inst.origin + Vector3.new(math.random(-45, 45), 3, math.random(-45, 45))
			local mob = R.MonsterService.Spawn(group[1], pos, {
				zone = { center = inst.origin, radius = 60 },
				noRespawn = true,
				parent = inst.room,
				onDeath = function()
					inst.alive -= 1
					if inst.alive <= 0 and not inst.done then
						if isBoss then
							finish(inst, true)
						else
							task.wait(2)
							spawnWave(inst)
						end
					end
				end,
			})
			if mob then
				mob.target = inst.players[math.random(1, #inst.players)]
				table.insert(inst.mobs, mob)
			end
		end
	end
	for _, pl in ipairs(inst.players) do
		Net.Push(pl, "Banner", { title = isBoss and "BOSS!" or ("WAVE " .. inst.wave .. "/" .. #def.waves), subtitle = def.name })
	end
end

function DS.Start()
	Net.Handle("DungeonEnter", function(player, data)
		local def = Dungeons[data.id]
		if not def then
			return false, "Dungeon not found"
		end
		if playerInstance[player] then
			return false, "Already in a dungeon"
		end
		if not R.WorldBuilder.NearNPC(player, "Dungeon") then
			return false, "Stand at the dungeon entrance"
		end
		local island = Islands.ById[def.island]
		local root = R.PlayerService.Root(player)
		local group = {}
		for _, m in ipairs(R.PartyService.Members(player)) do
			local r2 = R.PlayerService.Root(m)
			local p = R.DataService.Get(m)
			if r2 and p and (r2.Position - root.Position).Magnitude < 60 and not playerInstance[m] then
				if p.baseLevel < def.minLevel then
					return false, m.DisplayName .. " needs Lv." .. def.minLevel
				end
				if (p.dungeonCooldowns[data.id] or 0) > os.time() then
					return false, m.DisplayName .. " is on dungeon cooldown"
				end
				table.insert(group, m)
			end
			if #group >= def.maxParty then
				break
			end
		end
		slot += 1
		local origin = Vector3.new(island.x, 2400 + (slot % 20) * 120, 6000 + (slot % 20) * 200)
		local inst = { def = def, players = group, origin = origin, wave = 0, mobs = {}, alive = 0 }
		inst.room = buildRoom(def, origin)
		instances[inst] = true
		for _, m in ipairs(group) do
			local p = R.DataService.Get(m)
			p.dungeonCooldowns[data.id] = os.time() + def.cooldown
			playerInstance[m] = inst
			R.PlayerService.TeleportTo(m, CFrame.new(origin + Vector3.new(0, 4, 60)))
		end
		task.delay(3, spawnWave, inst)
		task.delay(def.timeLimit, function()
			finish(inst, false)
		end)
		return true
	end, 2)

	Players.PlayerRemoving:Connect(function(pl)
		playerInstance[pl] = nil
	end)
end

return DS
