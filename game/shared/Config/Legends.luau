--!strict
--[[
	Legends: permanent legendary residents players collect and bring into runs (bible Section
	15). A Legend starts at level 5 with its signature trait, one good trait (rolled from
	Traits, Good) and signature gear; never ages; Renown 1 to 5 (Tuning.Legends). The first
	twelve of 24 are here; the rest arrive with Prompt 27. Each is one of a kind in looks too
	(Tiers.Legendary).
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

local function mod(key: string, value: number, extra: { [string]: any }?): { [string]: any }
	local t: { [string]: any } = { Key = key, Value = value }
	if extra then
		for k, v in extra do
			t[k] = v
		end
	end
	return t
end

return {
	Schema = Check.shape({
		Name = F.Name,
		Signature = Check.shape({ Name = F.Name, Text = F.Text, Modifiers = Check.optional(F.Modifiers) }),
		Gear = Check.optional(F.ItemStacks),
		Get = Check.shape({
			Kind = Check.enum({ "Starter", "Badge", "Glowshards", "Event" }),
			Glowshards = F.Glowshards,
			Badge = Check.optional(Check.ref("Badges")),
		}),
		BestStat = Check.ref("Stats"),
	}),
	Order = {
		"RosieKowalski", "AbnerPrice", "EarlHutch", "MabelFitz", "JuneOkafor", "IngridVale",
		"LouMarchetti", "TexDelgado", "WrenHolloway", "OldManHiggins", "IvyAlvarez", "DutchVanDorn",
	},
	Entries = {
		RosieKowalski = {
			Name = "Rosie 'Rivets' Kowalski",
			Signature = { Name = "Rivet Queen", Text = "Slowly repairs every room on her floor.", Modifiers = { mod("RepairsRooms", 1, { Scope = "Floor" }) } },
			Gear = { { Item = "Wrench" }, { Item = "WorkOveralls" } },
			Get = { Kind = "Starter" },
			BestStat = "Strength",
		},
		AbnerPrice = {
			Name = "Doc Abner Price",
			Signature = { Name = "House Calls", Text = "Residents he treats heal twice as fast.", Modifiers = { mod("TreatedHealSpeed", 2) } },
			Gear = { { Item = "Stethoscope" }, { Item = "LabCoat" } },
			Get = { Kind = "Badge", Badge = "Rescue50" },
			BestStat = "Smarts",
		},
		EarlHutch = {
			Name = "Big Earl Hutch",
			Signature = { Name = "Doorman", Text = "The Blast Door takes 50% less damage while he guards it.", Modifiers = { mod("BlastDoorDamageTaken", 0.5) } },
			Gear = { { Item = "Sledgehammer" }, { Item = "SecurityVest" } },
			Get = { Kind = "Glowshards", Glowshards = 200 },
			BestStat = "Grit",
		},
		MabelFitz = {
			Name = "Mabel Fitz",
			Signature = { Name = "Sunday Pies", Text = "+10 morale for everyone after each Surge survived.", Modifiers = { mod("SurgeSurvivedMorale", 10) } },
			Gear = { { Item = "Ladle" }, { Item = "SundayBest" } },
			Get = { Kind = "Glowshards", Glowshards = 150 },
			BestStat = "Speed",
		},
		JuneOkafor = {
			Name = "Captain June Okafor",
			Signature = { Name = "Steady Orders", Text = "Armed residents deal +20% damage.", Modifiers = { mod("ArmedResidentDamage", 1.2) } },
			Gear = { { Item = "ServiceRevolver" }, { Item = "SecurityVest" } },
			Get = { Kind = "Badge", Badge = "CenturyVictory" },
			BestStat = "Grit",
		},
		IngridVale = {
			Name = "Professor Ingrid Vale",
			Signature = { Name = "Breakthrough", Text = "Lab research twice as fast.", Modifiers = { mod("ResearchSpeed", 2) } },
			Gear = { { Item = "LabCoat" } },
			Get = { Kind = "Glowshards", Glowshards = 300 },
			BestStat = "Smarts",
		},
		LouMarchetti = {
			Name = "Lucky Lou Marchetti",
			Signature = { Name = "Lucky Streak", Text = "Double loot from expeditions.", Modifiers = { mod("ExpeditionLoot", 2) } },
			Gear = { { Item = "TrackJacket" } },
			Get = { Kind = "Glowshards", Glowshards = 250 },
			BestStat = "Speed",
		},
		TexDelgado = {
			Name = "Tex Delgado",
			Signature = {
				Name = "Quick Draw",
				Text = "Fires twice as fast and defends any room he stands in.",
				Modifiers = { mod("FireRate", 2), mod("DefendsAnyRoom", 1) },
			},
			Gear = { { Item = "ServiceRevolver" } },
			Get = { Kind = "Glowshards", Glowshards = 300 },
			BestStat = "Grit",
		},
		WrenHolloway = {
			Name = "Wren Holloway",
			Signature = { Name = "Silver Tongue", Text = "Radio recruits arrive twice as often.", Modifiers = { mod("RecruitRate", 2) } },
			Gear = { { Item = "RadioHeadset" }, { Item = "SundayBest" } },
			Get = { Kind = "Badge", Badge = "LetIn10Wanderers" },
			BestStat = "Charm",
		},
		OldManHiggins = {
			Name = "Old Man Higgins",
			Signature = { Name = "Mentor", Text = "Residents in his room gain double experience.", Modifiers = { mod("ResidentXP", 2, { Scope = "Room" }) } },
			Get = { Kind = "Badge", Badge = "Year100With30" },
			BestStat = "Charm",
		},
		IvyAlvarez = {
			Name = "Ivy 'Torch' Alvarez",
			Signature = { Name = "Firewall", Text = "Fires can't spread out of the room she is in.", Modifiers = { mod("FireContained", 1) } },
			Gear = { { Item = "Extinguisher" }, { Item = "WorkOveralls" } },
			Get = { Kind = "Glowshards", Glowshards = 200 },
			BestStat = "Grit",
		},
		DutchVanDorn = {
			Name = "Dutch van Dorn",
			Signature = { Name = "Deep Nose", Text = "Every cell he digs holds at least an ore pocket.", Modifiers = { mod("OrePocketGuaranteed", 1) } },
			Gear = { { Item = "HandDrill" }, { Item = "WorkOveralls" } },
			Get = { Kind = "Badge", Badge = "Depth10" },
			BestStat = "Strength",
		},
	},
}
