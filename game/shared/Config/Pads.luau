--!strict
--[[
	Pads (bible Section 21): the elevator pads in the Steadfast showroom that start runs.
	* Public: anyone, up to Tuning.Lobby.PartyMax. A countdown starts with the first rider and the
	  pad leaves when it is full or the time runs out. Its difficulty is fixed.
	* Private: the first rider leads. Only players the leader invited may step on; the leader picks
	  the difficulty and starts when ready.
	* Solo: one rider; it leaves at once (after Tuning.Lobby.SoloCountdownSeconds, so a mis-step can
	  be undone).
	A pad in the world is a model with a `PadId` attribute naming an entry here (PadService).
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

return {
	Schema = Check.shape({
		Name = F.Name,
		Kind = Check.enum({ "Public", "Private", "Solo" }),
		Difficulty = Check.optional(Check.ref("Difficulties")), -- fixed (public pads); nil: its leader picks
		Text = F.Short,
	}),
	Order = { "PublicNormal", "PublicHard", "PublicNightmare", "PrivateA", "PrivateB", "Solo" },
	Entries = {
		PublicNormal = { Name = "Public", Kind = "Public", Difficulty = "Normal", Text = "Anyone, up to six. Leaves 20 seconds after the first rider, or when full." },
		PublicHard = { Name = "Public", Kind = "Public", Difficulty = "Hard", Text = "Anyone who has unlocked Hard, up to six." },
		PublicNightmare = { Name = "Public", Kind = "Public", Difficulty = "Nightmare", Text = "Anyone who has unlocked Nightmare, up to six." },
		PrivateA = { Name = "Private", Kind = "Private", Text = "The first rider leads: invite friends, pick the difficulty, start when ready." },
		PrivateB = { Name = "Private", Kind = "Private", Text = "The first rider leads: invite friends, pick the difficulty, start when ready." },
		Solo = { Name = "Solo", Kind = "Solo", Text = "Just you. Pick the difficulty and go." },
	},
}
