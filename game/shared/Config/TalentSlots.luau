--!strict
--[[
	TalentSlots: a slot adds the passive of another owned class to the current one (bible
	Section 14). Talents are passives only (Classes.Talentable, Classes.TalentExclude).
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

return {
	Schema = Check.shape({
		Slot = Check.integer(1, 3),
		AccountLevel = Check.optional(F.PositiveInt),
		Glowshards = F.Glowshards,
		Pass = Check.optional(Check.ref("GamePasses")),
		Text = F.Short,
	}),
	Order = { "Slot1", "Slot2", "Slot3" },
	Entries = {
		Slot1 = { Slot = 1, AccountLevel = 5, Text = "Unlocks at account level 5" },
		Slot2 = { Slot = 2, Glowshards = 150, Pass = "ExtraTalentSlot", Text = "150 Glowshards or the Extra Talent Slot pass" },
		Slot3 = { Slot = 3, Glowshards = 300, Text = "300 Glowshards" },
	},
}
