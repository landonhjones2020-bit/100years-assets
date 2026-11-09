--!strict
--[[
	Votes: what the team votes on and how each passes (bible Section 8). General rules
	(abstaining, ties, the 40% rule, cooldowns, solo runs, the Warden) are in Tuning.Votes.
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

return {
	Schema = Check.shape({
		Name = F.Name,
		StartsWhen = F.Short,
		Seconds = F.Seconds,
		Rule = Check.enum({ "MoreYes", "WholeTeamMajority", "MostVotes", "TwoThirdsOfOthers" }),
		Text = F.Short,
	}),
	Order = { "Build", "PushDeeper", "Draft", "LetThemIn", "KeepGoing", "PlayAgain", "Kick" },
	Entries = {
		Build = {
			Name = "Build, upgrade, merge or tear down",
			StartsWhen = "A player proposes it in the Command View",
			Seconds = 15,
			Rule = "MoreYes",
			Text = "More yes than no after 15 seconds",
		},
		PushDeeper = {
			Name = "Push Deeper",
			StartsWhen = "Someone tries to open the first cell of floor 4, 7 or 10",
			Seconds = 20,
			Rule = "WholeTeamMajority",
			Text = "A majority of the whole team says yes",
		},
		Draft = {
			Name = "Blueprint draft",
			StartsWhen = "After every Surge",
			Seconds = 20,
			Rule = "MostVotes",
			Text = "Most votes after 20 seconds; ties are picked at random",
		},
		LetThemIn = {
			Name = "Let them in?",
			StartsWhen = "A wanderer knocks at the blast door",
			Seconds = 15,
			Rule = "MoreYes",
			Text = "More yes than no after 15 seconds",
		},
		KeepGoing = {
			Name = "Keep Going",
			StartsWhen = "After a victory",
			Seconds = 20,
			Rule = "WholeTeamMajority",
			Text = "A majority of the whole team",
		},
		PlayAgain = { -- Section 21: after a run, a vote sends the same party to a fresh Run server (Prompt 15)
			Name = "Play Again",
			StartsWhen = "Someone presses Play Again on the results screen",
			Seconds = 20,
			Rule = "WholeTeamMajority",
			Text = "A majority of the whole team",
		},
		Kick = {
			Name = "Kick a player",
			StartsWhen = "Any player starts it against one person",
			Seconds = 20,
			Rule = "TwoThirdsOfOthers",
			Text = "Two thirds of the other players",
		},
	},
}
