--!strict
--[[
	RadioLogs: recordings found in the Deep and on the surface (bible Sections 3 and 12; Prompt 17).
	"The company's cover-up comes out piece by piece": the story is the bible's (the Brightwater
	mine, the glowing mass, Steadfast building anyway, the century, Digby). A log with Hint = "Crew"
	ends with where an unfound Lost Crew was last heard from ("Radio logs and the Radio Room give
	hints about where each crew is"). The Codex keeps them later (Prompt 29). Draft text: Landon's
	to change.
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

return {
	Schema = Check.shape({
		Title = F.Name,
		From = F.Short,
		Text = F.Text,
		Hint = Check.optional(Check.enum({ "Crew" })),
		MinEra = Check.optional(Check.integer(1, 4)),
	}),
	Order = {
		"SiteSurvey", "CrewSeven", "DigbyMemo", "CivilDefense", "SampleG11", "FloodedGalleries",
		"ChairmansCable", "ShiftChange", "RaiderBroadcast", "TrainingFilm",
	},
	Entries = {
		SiteSurvey = {
			Title = "Site survey 4", From = "Steadfast survey office",
			Text = "Shaft 3 of the old Brightwater mine breaks into a cavern nine hundred feet down. The crew reports a green light in the rock and warm air coming up. Recommend we seal the shaft and say nothing until the sales office decides.",
		},
		CrewSeven = {
			Title = "Foreman's log, work crew 7", From = "A Steadfast foreman",
			Text = "Lost the lift cable at noon. We're dug in behind the rock fall with water, two lamps and the radio. Whoever hears this: we're Steadfast men, and Steadfast doesn't leave its own.",
			Hint = "Crew",
		},
		DigbyMemo = {
			Title = "Memo: the Digby campaign", From = "Steadfast advertising",
			Text = "Test families love the gopher. Keep him smiling in every film. Under no circumstances is Digby to be drawn underground, or near anything that glows.",
		},
		CivilDefense = {
			Title = "Brightwater Civil Defense", From = "A radio bulletin",
			Text = "This is Civil Defense. Proceed calmly to your Steadfast shelter. Bring water, a blanket and your ration card. The doors close in ten minutes.",
		},
		SampleG11 = {
			Title = "Lab note, sample G-11", From = "A Steadfast chemist",
			Text = "The beetles we kept beside the sample doubled in size in a week and stopped needing food. The rats got out. Requesting a steel cage and a raise.",
		},
		FloodedGalleries = {
			Title = "Survey crew, channel 2", From = "A Steadfast survey crew",
			Text = "Water's up to our knees in the lower galleries. The pumps quit when the power did. Something big is moving in the flooded cuts, and it's patient.",
			Hint = "Crew",
		},
		ChairmansCable = {
			Title = "The chairman's cable", From = "Steadfast head office",
			Text = "Construction proceeds. The Source, as the engineers call it, stays our secret. A century is a long time. By then it will be somebody else's problem.",
			MinEra = 2,
		},
		ShiftChange = {
			Title = "Transcript: shift change", From = "Mine office, night shift",
			Text = "That's the third man this month who says he dreams about the glow. Pull him off the deep crew and put him topside. And don't write any of this down.",
			Hint = "Crew",
		},
		RaiderBroadcast = {
			Title = "On the open band", From = "The Ash Raiders",
			Text = "Steadfast! We've got three of yours in the pen. Bring us Scrap and maybe they walk home. Or come and take them.",
			Hint = "Crew",
		},
		TrainingFilm = {
			Title = "Training film 12, sound reel", From = "Digby the Gopher",
			Text = "Remember, family: your bunker is built to last a century! Dig only where Digby says it's safe, and never, ever dig toward the glow.",
		},
	},
}
