-- Hotkeys (v0.25.44, owner): every rebindable key in one place. Defaults (v0.25.71): 1-6 pick the skill set,
-- E R F Z X C cast its skills (manual mode plays like a normal action game), Stats on Y. Players rebind in
-- Settings -> Hotkeys; overrides are saved in Settings.Values.keys ("Action=KeyName;...").
-- Keys go through ContextActionService at high priority: Roblox's camera sinks I / O (keyboard zoom), which made the
-- Bag key dead when we listened to UserInputService. CAS also stays quiet while you type in a TextBox / the chat.
local ContextActionService = game:GetService("ContextActionService")
local Settings = require(script.Parent.Settings)

local Hotkeys = {}

-- { id, label, default key name }
Hotkeys.Actions = {
	{ "Skill1", "Skill 1", "E" }, { "Skill2", "Skill 2", "R" }, { "Skill3", "Skill 3", "F" },
	{ "Skill4", "Skill 4", "Z" }, { "Skill5", "Skill 5", "X" }, { "Skill6", "Skill 6", "C" },
	-- v0.25.71 (owner): 1-6 pick the skill SET (Shared/Modules/SkillSets), E R F Z X C cast that set's skills
	{ "Set1", "Set 1: Class", "One" }, { "Set2", "Set 2: Fruit", "Two" }, { "Set3", "Set 3: Basic", "Three" },
	{ "Set4", "Set 4: Armament", "Four" }, { "Set5", "Set 5: Observation", "Five" }, { "Set6", "Set 6: Conqueror", "Six" },
	{ "Dash", "Dash", "Q" }, { "Auto", "Auto / Manual", "T" }, { "Target", "Nearest target", "Tab" }, { "Race", "Race mode", "V" }, { "Sling", "Slingshot Launch (Bounce)", "U" },
	{ "Inventory", "Bag", "I" }, { "Skills", "Skills", "K" }, { "Quests", "Quests", "J" }, { "Map", "Map", "M" },
	{ "Pets", "Pets", "N" }, { "PearlShop", "Store", "H" }, { "Stats", "Stats", "Y" }, { "Guild", "Guild", "G" },
	{ "Party", "Party", "P" }, { "BossBoard", "Bosses", "B" }, { "Settings", "Settings", "O" }, { "MenuHub", "Menu", "L" },
}
local DEFAULT = {}
for _, a in ipairs(Hotkeys.Actions) do
	DEFAULT[a[1]] = a[3]
end

local SHORT = { One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9", Zero = "0", Minus = "-", Equals = "=", Tab = "TAB", LeftShift = "SHF", LeftControl = "CTL", Backquote = "`", Semicolon = ";", Quote = "'", Comma = ",", Period = ".", Slash = "/", LeftBracket = "[", RightBracket = "]", BackSlash = "\\" }
-- never rebindable (movement, chat, menus, quick items)
Hotkeys.Reserved = { W = true, A = true, S = true, D = true, Space = true, Escape = true, Slash = true, Return = true, Backspace = true, LeftShift = true, F1 = true, F2 = true, F3 = true, F4 = true, F5 = true, F6 = true, F7 = true, F8 = true }

Hotkeys.Changed = Instance.new("BindableEvent")
local keyOf, actionOf, cached = {}, {}, nil
local handlers = {} -- action -> fn() returning false to let the key pass on (e.g. E to a ProximityPrompt)
local releases = {} -- action -> fn(cancelled) when the key goes up (hold-to-aim skills)

local function decode(s)
	local out = {}
	for pair in string.gmatch(s or "", "[^;]+") do
		local a, k = string.match(pair, "^(%w+)=(%w+)$")
		if a and k and DEFAULT[a] and Enum.KeyCode[k] then
			out[a] = k
		end
	end
	return out
end

local function bind()
	-- (pcall: the headless UI harness has no ContextActionService)
	pcall(function()
		ContextActionService:UnbindAction("GVHotkeys")
	end)
	local keys = {}
	for k in pairs(actionOf) do
		table.insert(keys, Enum.KeyCode[k])
	end
	local function onKey(_, state, input)
		local a = actionOf[input.KeyCode.Name]
		if state ~= Enum.UserInputState.Begin then
			-- End = key up; Cancel = the binding was interrupted (a TextBox took focus...)
			if a and releases[a] and (state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel) then
				releases[a](state == Enum.UserInputState.Cancel)
			end
			return Enum.ContextActionResult.Pass
		end
		local fn = a and handlers[a]
		if fn and fn() ~= false then
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end
	pcall(function()
		ContextActionService:BindActionAtPriority("GVHotkeys", onKey, false, Enum.ContextActionPriority.High.Value, table.unpack(keys))
	end)
end

-- rebuild the maps when the saved string changed (Settings.Load / Set)
function Hotkeys.Sync()
	local s = Settings.Values.keys or ""
	if s == cached then
		return
	end
	cached = s
	local over = decode(s)
	keyOf, actionOf = {}, {}
	for _, a in ipairs(Hotkeys.Actions) do
		local k = over[a[1]] or a[3]
		if not actionOf[k] then
			keyOf[a[1]] = k
			actionOf[k] = a[1]
		end
	end
	bind()
	Hotkeys.Changed:Fire()
end

function Hotkeys.Key(action)
	return keyOf[action]
end

-- short text for key caps ("E", "1", "TAB"); "" when unbound
function Hotkeys.Label(action)
	local k = keyOf[action]
	return k and (SHORT[k] or k) or ""
end

function Hotkeys.On(action, fn)
	handlers[action] = fn
end

function Hotkeys.OnRelease(action, fn)
	releases[action] = fn
end

-- give `action` the key `keyName`; whoever had it gets this action's old key (a swap)
function Hotkeys.Set(action, keyName)
	if not DEFAULT[action] or not Enum.KeyCode[keyName] or Hotkeys.Reserved[keyName] then
		return false
	end
	local over = decode(Settings.Values.keys)
	local other = actionOf[keyName]
	if other and other ~= action then
		over[other] = keyOf[action]
	end
	over[action] = keyName
	local parts = {}
	for _, a in ipairs(Hotkeys.Actions) do
		local k = over[a[1]]
		if k and k ~= a[3] then
			table.insert(parts, a[1] .. "=" .. k)
		end
	end
	Settings.Set("keys", table.concat(parts, ";"))
	Hotkeys.Sync()
	return true
end

function Hotkeys.Reset()
	Settings.Set("keys", "")
	Hotkeys.Sync()
end

Settings.OnLoad = Hotkeys.Sync
Hotkeys.Sync()
return Hotkeys
