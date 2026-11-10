--!strict
--[[
	Lib.ClassArt: how a class is shown on cards, plates and detail panels (the Class Shop, the
	Loadout, the lobby's class plate; bible Sections 14 and 18). Reads Config.Classes and the UI kit.

	* Portrait(classId, large): the class's portrait sprite, when its look has been made
	  (Portrait_<Class>, Portrait_<Class>_Large); nil otherwise.
	* Icon(classId): a kit icon that stands for the class (its signature item) for places too small
	  for a portrait, and for cards whose portrait doesn't exist yet.
	* Rarity(classId): the card frame for its tier (the free Survivor uses Common).
	* Kit(classId): its starting items by name. Sections(classId): the detail panel's text.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local UIKit = require(script.Parent:WaitForChild("UIKit"))

local ClassArt = {}

local RARITY: { [string]: string } = { Free = "Common", Common = "Common", Rare = "Rare", Epic = "Epic", Legendary = "Legendary" }

local ICONS: { [string]: string } = {
	Survivor = "Icon_Survivor", Engineer = "Icon_Turret", Medic = "Icon_DefibPaddles", Firefighter = "Icon_FireAxe",
	Cook = "Icon_Food", Security = "Icon_Shield", Scout = "Icon_LeverRifle", Quartermaster = "Icon_Scrap",
	RadioOperator = "Icon_Radio", HazmatTech = "Icon_GeigerCounter", Exterminator = "Icon_Flamethrower", Marksman = "Icon_Aim",
	Driller = "Icon_Drill", Scavenger = "Icon_Backpack", Warden = "Icon_Crew", Demolitionist = "Icon_GrenadeLauncher",
	Spelunker = "Icon_Grapple", MadScientist = "Icon_ArcRifle", Tinkerer = "Icon_CombatDrone",
}

function ClassArt.Portrait(classId: string, large: boolean?): string?
	local name = `Portrait_{classId}` .. (if large then "_Large" else "")
	if UIKit.Sprites[name] then
		return name
	end
	return if large then ClassArt.Portrait(classId, false) else nil
end

function ClassArt.Icon(classId: string): string
	local icon = ICONS[classId]
	return if icon and UIKit.Sprites[icon] then icon else "Icon_Interact"
end

function ClassArt.Rarity(classId: string): string
	local class = Config.Find("Classes", classId)
	return if class then RARITY[class.Tier] or "Common" else "Common"
end

function ClassArt.Kit(classId: string): string
	local class = Config.Get("Classes", classId)
	local names = {}
	for _, stack in class.Kit do
		local item = Config.Find("Items", stack.Item)
		local name = if item then item.Name else tostring(stack.Item)
		table.insert(names, if stack.Count and stack.Count > 1 then `{stack.Count} {name}s` else name)
	end
	return table.concat(names, " · ")
end

-- The detail panel's sections for a class: { { Label, Text } } in order.
function ClassArt.Sections(classId: string, level: number?): { { Label: string, Text: string } }
	local class = Config.Get("Classes", classId)
	local out = {
		{ Label = "Kit", Text = ClassArt.Kit(classId) },
		{ Label = "Passive", Text = class.Passive.Text },
		{ Label = `Ability  ·  {class.Ability.Name}`, Text = class.Ability.Text },
	}
	if class.Level2 then
		table.insert(out, { Label = `Level 2{if level and level >= 2 then "  ·  yours" else ""}`, Text = class.Level2.Text })
	end
	if class.Level3 then
		table.insert(out, { Label = `Level 3{if level and level >= 3 then "  ·  yours" else ""}`, Text = class.Level3.Text })
	end
	return out
end

return table.freeze(ClassArt)
