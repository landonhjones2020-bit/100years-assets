--!strict
--[[
	Traits: two per resident (bible Section 11 and the Appendix). Commons roll one good and one
	bad; Rares two good, or one good with higher stats; Legendaries a signature trait plus one
	good. Amounts the bible leaves open are provisional (Notes).
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

local function good(text: string, modifiers: { any }, notes: string?): { [string]: any }
	return { Type = "Good", Text = text, Modifiers = modifiers, Notes = notes }
end

local function bad(text: string, modifiers: { any }, notes: string?): { [string]: any }
	return { Type = "Bad", Text = text, Modifiers = modifiers, Notes = notes }
end

local entries = {
	Brave = good("Never panics; defends their room even without a weapon.", { mod("NeverPanics", 1), mod("DefendsUnarmed", 1) }),
	Tough = good("+25% max health.", { mod("MaxHealthMult", 1.25) }),
	FastLearner = good("+25% experience.", { mod("ResidentXP", 1.25) }),
	GreenThumb = good("+20% output in the Kitchen and Greenhouse.", {
		mod("RoomOutput", 1.2, { Room = "Kitchen", Scope = "Self" }),
		mod("RoomOutput", 1.2, { Room = "Greenhouse", Scope = "Self" }),
	}),
	Tinkerer = good("+20% Workshop speed; slowly repairs their room.", { mod("CraftSpeed", 1.2), mod("RepairsRooms", 1, { Scope = "Room" }) }),
	SteadyHands = good("+20% output in the Medbay and Lab.", {
		mod("RoomOutput", 1.2, { Room = "Medbay", Scope = "Self" }),
		mod("RoomOutput", 1.2, { Room = "Lab", Scope = "Self" }),
	}),
	StrongBack = good("+20% output in the Reactor Core, Generators and Drill Bay; carries more on expeditions.", {
		mod("RoomOutput", 1.2, { Room = "ReactorCore", Scope = "Self" }),
		mod("RoomOutput", 1.2, { Room = "Generator", Scope = "Self" }),
		mod("RoomOutput", 1.2, { Room = "DrillBay", Scope = "Self" }),
		mod("ExpeditionCarry", 1.25),
	}, "Expedition carry x1.25 is provisional"),
	Firefighter = good("Puts out fires 3x faster; fire spreads slower from their room.", {
		mod("ExtinguishSpeed", 3),
		mod("FireSpread", 0.5, { Scope = "Room" }),
	}, "Spread x0.5 from their room is provisional"),
	Lucky = good("Chance of double output each cycle; better expedition loot.", {
		mod("DoubleOutputChance", 0.1),
		mod("ExpeditionLoot", 1.25),
	}, "10% double output and x1.25 loot are provisional"),
	Chatterbox = good("Raises roommates' morale.", { mod("RoommateMorale", 3) }, "+3 a cycle is provisional"),
	NaturalLeader = good("+10% output for everyone in their room.", { mod("AllOutput", 1.1, { Scope = "Room" }) }),
	Hardy = good("Resists radiation and gas.", { mod("RadiationGain", 0.5), mod("GasDamageTaken", 0.5) }, "Halved is provisional"),
	NightVision = good("No penalty in dark rooms.", { mod("NoDarkPenalty", 1) }),
	IronStomach = good("Eats half as much.", { mod("FoodUse", 0.5) }),
	Scrounger = good("Extra Scrap from expeditions and a small Scrap find each cycle.", {
		mod("ExpeditionScrap", 1.5),
		mod("ScrapPerCycle", 5),
	}, "x1.5 and +5 a cycle are provisional"),
	Sharpshooter = good("+30% gun damage.", { mod("GunDamage", 1.3) }),
	CoolHead = good("Never panics and calms panicked roommates.", { mod("NeverPanics", 1), mod("CalmsRoommates", 1) }),
	HardWorker = good("+10% output in any job.", { mod("AllOutput", 1.1) }),
	Coward = bad("Panics easily and flees breaches.", { mod("PanicChance", 2), mod("FleesBreaches", 1) }, "Panic x2 is provisional"),
	Clumsy = bad("Small chance each cycle of a minor fire or flood in their room.", { mod("AccidentChance", 0.04) }, "4% is provisional"),
	Glutton = bad("Eats twice as much.", { mod("FoodUse", 2) }),
	Lazy = bad("-15% output.", { mod("AllOutput", 0.85) }),
	Grumpy = bad("Lowers roommates' morale.", { mod("RoommateMorale", -3) }, "-3 a cycle is provisional"),
	Jumpy = bad("Panics at the first sign of danger and may run into hazards.", { mod("PanicChance", 3), mod("RunsIntoHazards", 1) }, "Panic x3 is provisional"),
	Sleepyhead = bad("Needs 50% more rest.", { mod("RestNeed", 1.5) }),
	Frail = bad("-25% max health.", { mod("MaxHealthMult", 0.75) }),
	Claustrophobic = bad("Morale drops at depth 4 and below.", { mod("Claustrophobic", 1) }),
	AfraidOfTheDark = bad("Morale crashes in dark rooms and refuses to work there.", { mod("AfraidOfDark", 1) }),
	Hothead = bad("Starts fights with rivals.", { mod("Hothead", 1) }),
	Homesick = bad("Morale slowly drains unless they spend time in the Lounge.", { mod("Homesick", 1) }),
}

local names = {
	Brave = "Brave", Tough = "Tough", FastLearner = "Fast Learner", GreenThumb = "Green Thumb", Tinkerer = "Tinkerer",
	SteadyHands = "Steady Hands", StrongBack = "Strong Back", Firefighter = "Firefighter", Lucky = "Lucky",
	Chatterbox = "Chatterbox", NaturalLeader = "Natural Leader", Hardy = "Hardy", NightVision = "Night Vision",
	IronStomach = "Iron Stomach", Scrounger = "Scrounger", Sharpshooter = "Sharpshooter", CoolHead = "Cool Head",
	HardWorker = "Hard Worker", Coward = "Coward", Clumsy = "Clumsy", Glutton = "Glutton", Lazy = "Lazy",
	Grumpy = "Grumpy", Jumpy = "Jumpy", Sleepyhead = "Sleepyhead", Frail = "Frail", Claustrophobic = "Claustrophobic",
	AfraidOfTheDark = "Afraid of the Dark", Hothead = "Hothead", Homesick = "Homesick",
}
for id, entry in entries do
	entry.Name = names[id]
end

return {
	Schema = Check.shape({
		Name = F.Name,
		Type = Check.enum({ "Good", "Bad" }),
		Text = F.Text,
		Modifiers = F.Modifiers,
		Notes = Check.optional(F.Short),
	}),
	Order = {
		"Brave", "Tough", "FastLearner", "GreenThumb", "Tinkerer", "SteadyHands", "StrongBack", "Firefighter",
		"Lucky", "Chatterbox", "NaturalLeader", "Hardy", "NightVision", "IronStomach", "Scrounger", "Sharpshooter",
		"CoolHead", "HardWorker", "Coward", "Clumsy", "Glutton", "Lazy", "Grumpy", "Jumpy", "Sleepyhead", "Frail",
		"Claustrophobic", "AfraidOfTheDark", "Hothead", "Homesick",
	},
	Entries = entries,
}
