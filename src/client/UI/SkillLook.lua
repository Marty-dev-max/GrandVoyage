-- SkillLook: how a skill is drawn everywhere (hotbar, Skills window): its icon and its color.
-- v0.24.14: every skill has its own pixel-art icon (tools/gen_skill_icons.py -> Config/SkillIcons); new skills without
-- one fall back to the 3D icon pack: fruit skills show their fruit, heals a potion,
-- buffs a sparkle, ship skills a ship, everything else the class weapon.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClassesCfg = require(ReplicatedStorage.Shared.Config.Classes)
local FruitsCfg = require(ReplicatedStorage.Shared.Config.Fruits)
local SkillIcons = require(ReplicatedStorage.Shared.Config.SkillIcons) -- v0.24.14: one pixel-art icon per skill
local MasteryCfg = require(ReplicatedStorage.Shared.Config.Mastery)
local UI = require(script.Parent.UIKit)

local SkillLook = {}
local CLASS_ICON = { Brawler = "knuckles", Swordsman = "sword", Sniper = "slingshot", Cook = "boots", Navigator = "staff", Doctor = "medkit", Shipwright = "hammer", Common = "knuckles" }

function SkillLook.IconId(sk)
	if sk.id and SkillIcons[sk.id] then
		return SkillIcons[sk.id]
	end
	if sk.fruit then
		return UI.IconId("fruit_" .. string.lower(sk.fruit))
	end
	if sk.toki then
		return UI.IconId("crown") -- Toki skills (v0.25.70)
	end
	local k = sk.kind
	if k == "Heal" or k == "PartyHeal" then
		return UI.IconId(sk.id == "HeartyMeal" and "meat" or "potion")
	elseif k == "Buff" or k == "PartyBuff" then
		return UI.IconId("skills")
	elseif k == "ShipBuff" then
		return UI.IconId("ship")
	elseif k == "ShipRepair" then
		return UI.IconId("repairkit")
	end
	return UI.IconId(CLASS_ICON[sk.class] or "sword")
end

-- its class color, or its fruit's color for Cursed Fruit skills
function SkillLook.Color(sk)
	if not sk then
		return UI.Theme.Panel
	end
	local cls = ClassesCfg.Classes[sk.class]
	if cls then
		return cls.color
	end
	local f = sk.fruit and FruitsCfg.ById[sk.fruit]
	if sk.mastery then
		local field = MasteryCfg.Fields[sk.mastery] -- remake M4 Mastery skills: the field's color
		return field and field.color or UI.Theme.Accent
	end
	if sk.toki then
		-- your own Toki color
		local hex = game:GetService("Players").LocalPlayer:GetAttribute("TokiColor_" .. sk.toki)
		local ok, c = pcall(Color3.fromHex, hex or "")
		return ok and c or UI.Theme.Gold
	end
	return f and f.color or UI.Theme.Accent
end

-- attack skills hit enemies; support skills heal/buff/repair
local SUPPORT = { Heal = true, PartyHeal = true, Buff = true, PartyBuff = true, ShipBuff = true, ShipRepair = true }
function SkillLook.IsSupport(sk)
	return SUPPORT[sk.kind] == true
end

return SkillLook
