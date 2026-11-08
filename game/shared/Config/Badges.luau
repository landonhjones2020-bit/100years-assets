--!strict
--[[
	Badges (bible Section 16): survival, depth, victories, residents and combat. 5 to 50
	Glowshards each, once; some unlock Legends (Legends.Get). Hidden lore badges arrive with
	the Codex (Prompt 29). BadgeId is set when the Roblox badges are created.
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

local function b(name: string, group: string, text: string, glowshards: number): { [string]: any }
	return { Name = name, Group = group, Text = text, Glowshards = glowshards }
end

return {
	Schema = Check.shape({
		Name = F.Name,
		Group = Check.enum({ "Survival", "Depth", "Victory", "Residents", "Combat", "Lore" }),
		Text = F.Short,
		Glowshards = Check.integer(5, 50),
		BadgeId = Check.optional(F.PositiveInt),
	}),
	Order = {
		"Year25", "Year50", "Year75", "Year100", "DepthFlooded", "DepthCrystal", "Depth10",
		"CenturyVictory", "DeepVictory", "HardVictory", "NightmareVictory",
		"Year100With30", "NoDeaths", "Rescue50", "LetIn10Wanderers",
		"BeatBroodMother", "BeatDeluge", "BeatCrystalColossus", "BeatSource", "Monsters1000",
	},
	Entries = {
		Year25 = b("Settled In", "Survival", "Reach Year 25.", 5),
		Year50 = b("Halfway There", "Survival", "Reach Year 50.", 10),
		Year75 = b("Three Quarters", "Survival", "Reach Year 75.", 15),
		Year100 = b("Built to Last", "Survival", "Reach Year 100.", 25),
		DepthFlooded = b("Wet Feet", "Depth", "Reach the Flooded Caverns.", 5),
		DepthCrystal = b("Into the Glow", "Depth", "Reach the Crystal Hollows.", 10),
		Depth10 = b("Rock Bottom", "Depth", "Reach depth 10, the Source Chamber.", 20),
		CenturyVictory = b("A Clearing Sky", "Victory", "Win a Century Victory.", 25),
		DeepVictory = b("Dug Too Deep", "Victory", "Win a Deep Victory.", 40),
		HardVictory = b("Hard Times", "Victory", "Win on Hard.", 40),
		NightmareVictory = b("Nightmare's End", "Victory", "Win on Nightmare.", 50),
		Year100With30 = b("Full House", "Residents", "Reach Year 100 with 30 residents alive.", 30),
		NoDeaths = b("Nobody Left Behind", "Residents", "Finish a run with no resident deaths.", 25),
		Rescue50 = b("Search and Rescue", "Residents", "Rescue 50 survivors in total.", 20),
		LetIn10Wanderers = b("Open Door", "Residents", "Let in 10 genuine wanderers.", 15),
		BeatBroodMother = b("Egg Breaker", "Combat", "Beat the Brood Mother.", 10),
		BeatDeluge = b("High and Dry", "Combat", "Beat The Deluge.", 15),
		BeatCrystalColossus = b("Shatterproof", "Combat", "Beat the Crystal Colossus.", 20),
		BeatSource = b("Lights Out", "Combat", "Beat the Source.", 30),
		Monsters1000 = b("Exterminator", "Combat", "Defeat 1,000 monsters.", 20),
	},
}
