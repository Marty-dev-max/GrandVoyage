-- BossService: timed MVP bosses per island, server-wide announcements, spawn board
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Islands = require(Shared.Config.Islands)
local Monsters = require(Shared.Config.Monsters)
local Net = require(Shared.Modules.Net)

local Boss = {}
local R
local state = {} -- islandId -> { alive=bool, nextSpawn=os.time }

function Boss.Init(registry)
	R = registry
end

local function spawnBoss(island)
	local b = island.boss
	local def = Monsters[b.id]
	local x, z = island.x + b.offset.X, (island.z or 0) + b.offset.Y
	-- sea bosses lie under the water at their spot until a ship comes near (MonsterService seaStep)
	local pos = b.sea and Vector3.new(x, -30, z) or R.MonsterService.GroundAt(x, z, b.indoorY) -- indoorY: cast from under the roof of its building (v0.25.146)
	local st = state[island.id]
	st.alive = true
	R.MonsterService.Spawn(b.id, pos, {
		zone = { center = pos, radius = b.sea and (b.wakeRadius or 150) or ((b.arenaRadius or 42) - 8) },
		seaBoss = b.sea == true,
		noRespawn = true,
		onDeath = function()
			st.alive = false
			st.nextSpawn = os.time() + b.respawn
			Boss.Broadcast()
		end,
	})
	Net.PushAll("Announce", { text = "⚠️ BOSS " .. def.name .. " Lv." .. def.level .. " has appeared at " .. island.name .. "!", kind = "boss" })
	Boss.Broadcast()
end

function Boss.Broadcast()
	local list = {}
	for _, island in ipairs(Islands.List) do
		local st = state[island.id]
		if st then
			local def = Monsters[island.boss.id]
			table.insert(list, { island = island.name, name = def.name, level = def.level, alive = st.alive, nextSpawn = st.nextSpawn })
		end
	end
	Net.PushAll("BossBoard", { list = list, serverTime = os.time() })
end

-- Store "Boss Respawn" (v0.24.0): every defeated boss on this server comes back within a few seconds
function Boss.RespawnAllNow()
	local n = 0
	local now = os.time()
	for _, island in ipairs(Islands.List) do
		local st = state[island.id]
		if st and not st.alive then
			st.nextSpawn = now
			n += 1
		end
	end
	return n
end

-- how many bosses are down right now (the Store refuses Boss Respawn at 0)
function Boss.DownCount()
	local n = 0
	for _, st in pairs(state) do
		if not st.alive then
			n += 1
		end
	end
	return n
end

function Boss.Start()
	for _, island in ipairs(Islands.List) do
		if island.boss then
			-- On server start, bosses spawn after 1-3 minutes
			state[island.id] = { alive = false, nextSpawn = os.time() + 60 + island.index * 20 }
		end
	end
	Net.Handle("GetBossBoard", function()
		Boss.Broadcast()
		return true
	end, 2)
	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.time()
			for _, island in ipairs(Islands.List) do
				local st = state[island.id]
				if st and not st.alive and now >= st.nextSpawn then
					spawnBoss(island)
				end
			end
		end
	end)
end

return Boss
