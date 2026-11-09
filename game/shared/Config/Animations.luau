--!strict
--[[
	Animations: the clips the game plays (bible Section 19: clips are made in Blender, uploaded
	under the game's owner, and their ids go in Config). NPCAnimator (client) plays a rig's clip
	for the Activity attribute its model carries (Section 23: animations play on clients from a
	replicated Activity attribute). More clips come with the art steps (A3 residents working,
	eating and sleeping; A4 monsters).
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

return {
	Schema = Check.shape({
		Rig = Check.enum({ "R15" }),
		Activity = Check.enum({ "Walk", "Work", "Eat", "Sleep", "Idle", "Down" }),
		AssetId = Check.string(40, { pattern = "^rbxassetid://%d+$" }), -- (Config adds Id: the entry's key)
		Looped = Check.boolean(),
		Text = F.Short,
	}),
	Entries = {
		ResidentWalk = {
			Rig = "R15",
			Activity = "Walk",
			AssetId = "rbxassetid://125264708961546",
			Looped = true,
			Text = "A resident walking (A0, R15_ResidentWalk)",
		},
	},
}
