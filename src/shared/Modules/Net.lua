-- Net: central networking
--  * Request  (RemoteFunction) : client -> server action, returns { ok, msg, data }
--  * Push     (RemoteEvent)    : server -> client state updates / open UI / notifications
--  * FX       (Unreliable)     : server -> client effects / damage numbers
--  * ShipInput(Unreliable)     : client -> server throttle/steer
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}
local IS_SERVER = RunService:IsServer()
local folder

local function getFolder()
	if folder then
		return folder
	end
	if IS_SERVER then
		folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
		local function make(class, name)
			if not folder:FindFirstChild(name) then
				local r = Instance.new(class)
				r.Name = name
				r.Parent = folder
			end
		end
		make("RemoteFunction", "Request")
		make("RemoteEvent", "Push")
		make("UnreliableRemoteEvent", "FX")
		make("UnreliableRemoteEvent", "ShipInput")
	else
		folder = ReplicatedStorage:WaitForChild("Remotes")
	end
	return folder
end

function Net.Get(name)
	return getFolder():WaitForChild(name)
end

-- ===== SERVER =====
local handlers = {}
local lastCall = {}

-- open = true: allowed before the player has entered the game (title menu / character slots)
function Net.Handle(action, fn, minInterval, open)
	handlers[action] = { fn = fn, interval = minInterval or 0.08, open = open }
end

-- gate(player) -> true when the player is in the game (a character slot is loaded). Requests that are not `open`
-- are refused until then, so no handler ever sees a player without a profile.
local gate
function Net.SetGate(fn)
	gate = fn
end

-- Hooks run after every handled request with (player, action, payload, result). Used by QuestService so services
-- do not need to know about quests.
local afterHooks = {}
function Net.AfterHandle(fn)
	table.insert(afterHooks, fn)
end
local function runAfter(player, action, payload, result)
	for _, fn in ipairs(afterHooks) do
		task.spawn(function()
			local ok, err = pcall(fn, player, action, payload, result)
			if not ok then
				warn("[Net] after-hook " .. action .. ": " .. tostring(err))
			end
		end)
	end
	return result
end

function Net.StartServer()
	local rf = Net.Get("Request")
	rf.OnServerInvoke = function(player, action, payload)
		local h = type(action) == "string" and handlers[action]
		if not h then
			return { ok = false, msg = "unknown action" }
		end
		local key = player.UserId .. action
		local now = os.clock()
		if lastCall[key] and now - lastCall[key] < h.interval then
			return { ok = false, msg = "Too fast", throttled = true }
		end
		lastCall[key] = now
		if gate and not h.open and not gate(player) then
			return { ok = false, msg = "Choose a character first", notInGame = true }
		end
		payload = type(payload) == "table" and payload or {}
		local ok, a, b, c = pcall(h.fn, player, payload)
		if not ok then
			warn("[Net] " .. action .. " error: " .. tostring(a))
			return { ok = false, msg = "server error" }
		end
		if type(a) == "table" then
			return runAfter(player, action, payload, a)
		end
		return runAfter(player, action, payload, { ok = a == true, msg = b, data = c })
	end
end

function Net.Push(player, kind, data)
	Net.Get("Push"):FireClient(player, kind, data)
end

function Net.PushAll(kind, data)
	Net.Get("Push"):FireAllClients(kind, data)
end

function Net.FX(kind, data, nearPos, radius)
	local fx = Net.Get("FX")
	if nearPos then
		radius = radius or 400
		for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - nearPos).Magnitude <= radius then
				fx:FireClient(p, kind, data)
			end
		end
	else
		fx:FireAllClients(kind, data)
	end
end

-- ===== CLIENT =====
function Net.Request(action, payload)
	local ok, result = pcall(function()
		return Net.Get("Request"):InvokeServer(action, payload)
	end)
	if not ok then
		return { ok = false, msg = tostring(result) }
	end
	return result or { ok = false }
end

-- Net.OnPush(fn(kind, data)) = every push; Net.OnPush(kind, fn(data)) = only that kind.
-- v0.25.63: the second form was used (FruitAlert "FruitSpawn", Combat "SkillDash" / "Knock") but never supported, so
-- those handlers never ran (the Fruit Notifier showed nothing at all)
function Net.OnPush(a, b)
	if type(a) == "string" then
		return Net.Get("Push").OnClientEvent:Connect(function(kind, data)
			if kind == a then
				b(data or {})
			end
		end)
	end
	return Net.Get("Push").OnClientEvent:Connect(a)
end

function Net.OnFX(fn)
	return Net.Get("FX").OnClientEvent:Connect(fn)
end

return Net
