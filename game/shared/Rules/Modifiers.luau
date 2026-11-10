--!strict
--[[
	Rules.Modifiers: reading the effects a player carries (bible Sections 14 and 23: effects are
	data, Config.Modifiers is the vocabulary). Pure, so both sides and the data tests share it.

	A class's Passive and its level 2 and 3 effects (Prompt 20; talents come with Prompt 27) list
	modifiers. ClassValue folds the ones with a key into one number by the key's unit:
	Multiplier and Chance multiply (1 when none), Add adds (0), Set and Flag take the last (nil
	when none). A level's modifier with the same key (and room) as an earlier part replaces it
	rather than stacking: the Quartermaster's level 3 build costs -20% replace the passive's -10%
	(Config.Classes' note).

		Modifiers.ClassValue("Firefighter", "ExtinguishSpeed") -- 3
		Modifiers.ClassValue("Engineer", "RepairSpeed")        -- 2
		Modifiers.ClassValue("Survivor", "RepairSpeed")        -- 1
		Modifiers.ClassValue("Quartermaster", "BuildCost", 3)  -- 0.8

	PlayerValue(player, key) reads the player's Class and ClassLevel attributes (ClassService sets
	them, Prompt 20), so every system honours level 2 and 3 the same way on both sides.
]]

local Config = require(script.Parent.Parent.Config)

local Modifiers = {}

-- The starting value of a key with nothing applied.
function Modifiers.Neutral(key: string): number?
	local info = Config.Find("Modifiers", key)
	if not info then
		return nil
	end
	if info.Unit == "Multiplier" or info.Unit == "Chance" then
		return 1
	elseif info.Unit == "Add" then
		return 0
	end
	return nil
end

-- Folds a list of { Key, Value } modifiers for one key.
function Modifiers.Fold(list: { any }?, key: string): number?
	local info = Config.Find("Modifiers", key)
	local value = Modifiers.Neutral(key)
	if not info then
		return nil
	end
	for _, modifier in list or {} do
		if modifier.Key == key then
			if info.Unit == "Multiplier" or info.Unit == "Chance" then
				value = (value or 1) * modifier.Value
			elseif info.Unit == "Add" then
				value = (value or 0) + modifier.Value
			else
				value = modifier.Value
			end
		end
	end
	return value
end

-- The modifiers a class carries at a level: its Passive, plus Level2 and Level3 at those levels.
-- A later part's modifier with the same Key and Room replaces the earlier one.
function Modifiers.ClassModifiers(classId: string?, level: number?): { any }
	local class = Config.Find("Classes", classId or "")
	local list = {}
	if not class then
		return list
	end
	local parts = { class.Passive }
	if (level or 1) >= 2 then
		table.insert(parts, class.Level2)
	end
	if (level or 1) >= 3 then
		table.insert(parts, class.Level3)
	end
	for _, part in parts do
		local fromThisPart: { [string]: boolean } = {}
		for _, modifier in (part and part.Modifiers) or {} do
			local key = `{modifier.Key}|{modifier.Room or ""}`
			if not fromThisPart[key] then
				for i = #list, 1, -1 do
					if `{list[i].Key}|{list[i].Room or ""}` == key then
						table.remove(list, i)
					end
				end
			end
			fromThisPart[key] = true
			table.insert(list, modifier)
		end
	end
	return list
end

-- A class's value for a key at a level (1 when not given).
function Modifiers.ClassValue(classId: string?, key: string, level: number?): number?
	return Modifiers.Fold(Modifiers.ClassModifiers(classId, level), key)
end

-- A player's value for a key: their class at their class level (the Class and ClassLevel
-- attributes). Talents (Prompt 27) will add theirs here.
function Modifiers.PlayerValue(player: Instance?, key: string): number?
	if not player then
		return Modifiers.Neutral(key)
	end
	local class = player:GetAttribute("Class")
	local level = player:GetAttribute("ClassLevel")
	return Modifiers.ClassValue(if type(class) == "string" then class else nil, key, if type(level) == "number" then level else nil)
end

return table.freeze(Modifiers)
