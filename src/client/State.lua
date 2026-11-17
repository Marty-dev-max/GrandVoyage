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

-- the player's Auto Battle search radius (Skills -> Loadout or Settings -> Auto Battle), clamped like the server does
function State.SearchRadius()
	local GameConfig = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)
	local ab = GameConfig.AutoBattle
	local r = State.profile and State.profile.settings and State.profile.settings.autoRadius
	return math.clamp(tonumber(r) or ab.SearchRadius, ab.MinRadius, ab.SearchRadius)
end

function State.Set(kind, value)
	State[kind] = value
	changed:Fire(kind)
end

return State
