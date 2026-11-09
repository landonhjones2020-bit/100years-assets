--!strict
--[[
	Rules.Modifiers: reading the effects a player carries (bible Sections 14 and 23: effects are
	data, Config.Modifiers is the vocabulary). Pure, so both sides and the data tests share it.

	A class's Passive (and, from Prompt 20, its level 2 and 3 effects; talents come with Prompt
	27) lists modifiers. ClassValue folds the ones with a key into one number by the key's
	unit: Multiplier and Chance multiply (1 when none), Add adds (0), Set and Flag take the last
	(nil when none).

		Modifiers.ClassValue("Firefighter", "ExtinguishSpeed") -- 3
		Modifiers.ClassValue("Engineer", "RepairSpeed")        -- 2
		Modifiers.ClassValue("Survivor", "RepairSpeed")        -- 1
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

-- A class's value for a key: its Passive, plus Level2 and Level3 at those class levels.
function Modifiers.ClassValue(classId: string?, key: string, level: number?): number?
	local class = Config.Find("Classes", classId or "")
	local list = {}
	if class then
		local parts = { class.Passive }
		if (level or 1) >= 2 then
			table.insert(parts, class.Level2)
		end
		if (level or 1) >= 3 then
			table.insert(parts, class.Level3)
		end
		for _, part in parts do
			for _, modifier in (part and part.Modifiers) or {} do
				table.insert(list, modifier)
			end
		end
	end
	return Modifiers.Fold(list, key)
end

return table.freeze(Modifiers)
