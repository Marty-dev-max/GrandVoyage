-- State: client-side copy of server data + change events
local State = {
	profile = nil,
	derived = nil,
	party = {},
	guild = nil,
	bossBoard = nil,
	guildWar = nil,
	build = { active = false },
	stall = { open = false },
	target = nil,
	auto = false,
	cooldowns = {},
}
local changed = Instance.new("BindableEvent")
State.Changed = changed.Event

function State.Fire(kind)
	changed:Fire(kind)
end

function State.Set(kind, value)
	State[kind] = value
	changed:Fire(kind)
end

return State
