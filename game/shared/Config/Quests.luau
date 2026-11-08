--!strict
--[[
	Quests (bible Section 16): 3 daily (3 to 5 Glowshards each) and 3 weekly (15 each) are drawn
	from these; both reset at 00:00 UTC. Goal.Event names the run event that counts toward it
	(Prompt 29 wires them); Class narrows it to playing one class.
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

local function q(period: string, text: string, event: string, count: number, reward: number, class: string?): { [string]: any }
	return { Period = period, Text = text, Goal = { Event = event, Count = count, Class = class }, Glowshards = reward }
end

return {
	Schema = Check.shape({
		Period = Check.enum({ "Daily", "Weekly" }),
		Text = F.Short,
		Goal = Check.shape({
			Event = Check.enum({ "RescueSurvivor", "PassVote", "DigCell", "SurviveSurge", "DefeatMonster", "BuildRoom", "FinishExpedition", "ReachYear", "BeatBoss", "FreeLostCrew" }),
			Count = F.PositiveInt,
			Class = Check.optional(Check.ref("Classes")),
		}),
		Glowshards = Check.integer(3, 15),
	}),
	Entries = {
		Rescue2 = q("Daily", "Rescue 2 survivors", "RescueSurvivor", 2, 4),
		PassVotes3 = q("Daily", "Pass 3 votes", "PassVote", 3, 3),
		Dig15 = q("Daily", "Dig 15 cells", "DigCell", 15, 4),
		SurgesAsMedic = q("Daily", "Survive 3 Surges as a Medic", "SurviveSurge", 3, 5, "Medic"),
		Defeat50 = q("Daily", "Defeat 50 monsters", "DefeatMonster", 50, 4),
		Build5 = q("Daily", "Build 5 rooms", "BuildRoom", 5, 3),
		Expeditions2 = q("Daily", "Finish 2 resident expeditions", "FinishExpedition", 2, 4),
		Year25 = q("Daily", "Reach Year 25", "ReachYear", 25, 5),
		Rescue10 = q("Weekly", "Rescue 10 survivors", "RescueSurvivor", 10, 15),
		Dig100 = q("Weekly", "Dig 100 cells", "DigCell", 100, 15),
		BeatBoss = q("Weekly", "Beat an era boss", "BeatBoss", 1, 15),
		Surges20 = q("Weekly", "Survive 20 Surges", "SurviveSurge", 20, 15),
		FreeCrews = q("Weekly", "Free 2 Lost Crews", "FreeLostCrew", 2, 15),
	},
}
