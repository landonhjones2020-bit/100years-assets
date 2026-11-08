--!strict
--[[
	GamePasses: bought once (bible Section 17). PassId is set when the passes are created
	(Prompt 28). Prices provisional.
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

local function mod(key: string, value: number): { [string]: any }
	return { Key = key, Value = value }
end

return {
	Schema = Check.shape({
		Name = F.Name,
		Robux = F.PositiveInt,
		Text = F.Text,
		Modifiers = Check.optional(F.Modifiers),
		NewPlayersOnly = F.Flag,
		PassId = Check.optional(F.PositiveInt),
	}),
	Order = { "VIP", "BigBackpack", "HelperDrone", "ExtraTalentSlot", "QuickRevive", "StarterPack" },
	Entries = {
		VIP = {
			Name = "VIP",
			Robux = 399,
			Text = "+25% Glowshards from runs, a second free class shop reroll each day, VIP lounge and tag in the lobby.",
		},
		BigBackpack = { Name = "Big Backpack", Robux = 199, Text = "+5 backpack slots.", Modifiers = { mod("BackpackSlots", 5) } },
		HelperDrone = {
			Name = "Helper Drone",
			Robux = 299,
			Text = "A personal drone that picks up loot and lights dark rooms; it doesn't fight.",
		},
		ExtraTalentSlot = { Name = "Extra Talent Slot", Robux = 249, Text = "Talent slot 2 without spending Glowshards." },
		QuickRevive = { Name = "Quick Revive", Robux = 249, Text = "Downed timer +50% and one free self-revive per run." },
		StarterPack = {
			Name = "Starter Pack",
			Robux = 199,
			Text = "New players only: 150 Glowshards, a Rare class of your choice, a Steadfast outfit.",
			NewPlayersOnly = true,
		},
	},
}
