--!strict
--[[
	Rules.Classes: class abilities and class levels (bible Section 14; Section 9: Q is the class
	ability). Pure, so ClassService, the client and the data tests share it. The numbers are
	Config.Classes (each ability's cooldown, uses, options) and Tuning.Classes (provisional).

	Abilities
	* Ability(classId): the class's Ability row. Options(classId): its option names ({} when it has
	  none). A tap of the ability key uses the selected option; a hold picks the next one.
	* An ability waits on a cooldown in seconds (CooldownSeconds), a cooldown in cycles
	  (CooldownCycles: the Cook's Hearty Meal), or uses that come back each Surge, cycle or era
	  (Uses). UsesFor(classId, level) is how many: the Radio Operator's level 2 makes Supply Call
	  twice an era (SupplyCallsPerEra). The Mad Scientist's gadgets each keep their own cooldown
	  (Config.Classes' note: "40 s each"): OwnCooldowns(classId).
	* Duration(classId, level): how long an ability's effect lasts (Hold the Line, Rally Call,
	  Drone Mode...), times TurretDuration for the Engineer's turret.

	Class levels (Section 14: levels 1 to 3 with experience earned while playing the class, about 3
	runs for level 2 and 10 for level 3; Tuning.ClassShop.ClassLevelRuns)
	* A run with a class earns Tuning.Classes.XPPerYear for each year it reached, paid when the run
	  ends (ResultsService, with the run's Glowshards). A level takes ClassLevelRuns runs of
	  TypicalRunYears years: LevelXP(2) and LevelXP(3). LevelFor(xp) is the level that experience
	  reaches; only owned classes keep experience.
]]

local Config = require(script.Parent.Parent.Config)
local Modifiers = require(script.Parent.Modifiers)

local Classes = {}

export type Ability = {
	Name: string,
	Text: string,
	CooldownSeconds: number?,
	CooldownCycles: number?,
	DurationSeconds: number?,
	Uses: { Per: string, Count: number }?,
	Options: { string }?,
	Modifiers: { any }?,
}

function Classes.Tuning(): { [string]: any }
	return Config.Get("Tuning", "Classes")
end

function Classes.Ability(classId: string?): Ability?
	local class = Config.Find("Classes", classId or "")
	return if class then class.Ability else nil
end

function Classes.Options(classId: string?): { string }
	local ability = Classes.Ability(classId)
	return if ability and ability.Options then ability.Options else {}
end

-- The option at an index, wrapped (1 when the ability has none).
function Classes.OptionIndex(classId: string?, index: number?): number
	local count = #Classes.Options(classId)
	if count == 0 then
		return 1
	end
	local i = math.floor(index or 1)
	return ((i - 1) % count) + 1
end

function Classes.OptionName(classId: string?, index: number?): string?
	local options = Classes.Options(classId)
	if #options == 0 then
		return nil
	end
	return options[Classes.OptionIndex(classId, index)]
end

-- The Mad Scientist's gadgets keep a cooldown each; other options share one.
function Classes.OwnCooldowns(classId: string?): boolean
	return classId ~= nil and Classes.Tuning().OwnCooldownClasses[classId] == true
end

-- Uses each period (nil: the ability waits on a cooldown instead).
function Classes.UsesFor(classId: string?, level: number?): number?
	local ability = Classes.Ability(classId)
	local uses = ability and ability.Uses
	if not uses then
		return nil
	end
	local calls = Modifiers.ClassValue(classId, "SupplyCallsPerEra", level)
	if type(calls) == "number" and calls > uses.Count then
		return calls
	end
	return uses.Count
end

function Classes.UsesPer(classId: string?): string?
	local ability = Classes.Ability(classId)
	return if ability and ability.Uses then ability.Uses.Per else nil
end

-- How long the ability's effect lasts, in seconds (0 when it is instant).
function Classes.Duration(classId: string?, level: number?): number
	local ability = Classes.Ability(classId)
	local seconds = if ability and ability.DurationSeconds then ability.DurationSeconds else 0
	if classId == "Engineer" then
		seconds *= Modifiers.ClassValue(classId, "TurretDuration", level) or 1
	end
	return seconds
end

-- The experience a level needs, in total (level 1: 0).
function Classes.LevelXP(level: number): number
	if level <= 1 then
		return 0
	end
	local t = Classes.Tuning()
	local runs = Config.Get("Tuning", "ClassShop").ClassLevelRuns
	local count = runs[math.clamp(level - 1, 1, #runs)]
	return count * t.TypicalRunYears * t.XPPerYear
end

function Classes.LevelFor(xp: number): number
	local level = 1
	for l = 2, Classes.Tuning().LevelMax do
		if xp >= Classes.LevelXP(l) then
			level = l
		end
	end
	return level
end

-- The experience a run pays for the years it reached (beyond those already paid).
function Classes.RunXP(years: number, paidYears: number?): number
	return math.max(0, math.floor(years) - math.floor(paidYears or 0)) * Classes.Tuning().XPPerYear
end

-- "READY", "12 S", "2 CYCLES": what the HUD shows under the ability.
function Classes.WaitText(seconds: number?, cycles: number?): string
	if cycles and cycles > 0 then
		return if cycles == 1 then "1 CYCLE" else `{cycles} CYCLES`
	end
	if seconds and seconds > 0.05 then
		return `{math.ceil(seconds)} S`
	end
	return "READY"
end

return table.freeze(Classes)
