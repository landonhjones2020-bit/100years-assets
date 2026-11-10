--!strict
--[[
	ExpeditionLogs: the lines a resident expedition's log gets (bible Section 12: "Every cycle their
	log gets a line (found a pharmacy, fought off jackals)"; Prompt 18). One is picked for what
	happened that cycle, for its destination (or Any). Blanks: {name} (one member), {names} (the
	team), {place} (a place in Brightwater Ruins, or the band they are in). Call is the distress
	call itself, read out on the radio card. Draft text: Landon's to change.

	Events: SetOut, Quiet, Hurt, Patched (a packed Medkit saved someone), Lost, Distress (the log's
	line), Call (the radio message), Home, Early (a fast team turns for home a cycle early; Landon,
	Prompt 18), Unheard (a call no Radio Room heard).
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

local function line(destination: string, event: string, text: string)
	return { Destination = destination, Event = event, Text = text }
end

return {
	Schema = Check.shape({
		Destination = Check.enum({ "Surface", "Deep", "Any" }),
		Event = Check.enum({ "SetOut", "Quiet", "Hurt", "Patched", "Lost", "Distress", "Call", "Home", "Early", "Unheard" }),
		Text = F.Short,
	}),
	Entries = {
		SetOutSurface = line("Surface", "SetOut", "set out for Brightwater Ruins with full packs"),
		SetOutDeep = line("Deep", "SetOut", "climbed down into {place} with lamps and rope"),

		Pharmacy = line("Surface", "Quiet", "found a pharmacy nobody had picked clean"),
		Searched = line("Surface", "Quiet", "searched {place} from top to bottom"),
		Rooftops = line("Surface", "Quiet", "crossed town on the rooftops, out of the ash"),
		Pantry = line("Surface", "Quiet", "found a cellar pantry behind {place}"),
		Junk = line("Surface", "Quiet", "stripped a burnt-out car for parts near {place}"),
		Camped = line("Surface", "Quiet", "sat out the storm in {place}"),

		CartTrack = line("Deep", "Quiet", "followed an old mine cart track through {place}"),
		Seam = line("Deep", "Quiet", "found a seam of ore the miners never reached"),
		Lockers = line("Deep", "Quiet", "pried open a Steadfast crew's lockers in {place}"),
		Echoes = line("Deep", "Quiet", "mapped a side tunnel by the sound of dripping water"),
		Camp = line("Deep", "Quiet", "slept in a dry pocket of {place}, lamps low"),
		Glow = line("Deep", "Quiet", "kept clear of a green glow in the rock"),

		Jackals = line("Surface", "Hurt", "fought off jackals at {place}; {name} was hurt"),
		Raiders = line("Surface", "Hurt", "ran from raiders near {place}; {name} took a hit"),
		Collapse = line("Surface", "Hurt", "a floor gave way in {place}; {name} was hurt"),
		Hounds = line("Deep", "Hurt", "fought off tunnel hounds in {place}; {name} was hurt"),
		RockFall = line("Deep", "Hurt", "a rock fall in {place} caught {name}"),
		Ticks = line("Deep", "Hurt", "{name} was bitten by burrow ticks in {place}"),

		Bandaged = line("Any", "Patched", "{name} was badly hurt, but a Medkit kept them going"),
		Splinted = line("Any", "Patched", "a packed Medkit pulled {name} through a bad night"),

		LostSurface = line("Surface", "Lost", "{name} went into {place} and never came out"),
		LostStorm = line("Surface", "Lost", "{name} was lost in the storm near {place}"),
		LostDeep = line("Deep", "Lost", "{name} fell behind in {place} and was gone"),
		LostDark = line("Deep", "Lost", "{name}'s lamp went out somewhere in {place}"),

		DistressSurface = line("Surface", "Distress", "radioed for help, pinned down at {place}"),
		DistressDeep = line("Deep", "Distress", "radioed for help from {place}"),

		CallSurface = line("Surface", "Call",
			"This is {name}! We're pinned down at {place} and we can't get back on our own. Come find us before tomorrow's storm!"),
		CallSurface2 = line("Surface", "Call",
			"{name} calling the bunker. Raiders all round {place}. We're holed up and hurt. Please hurry."),
		CallDeep = line("Deep", "Call",
			"{name} here... We're cut off in {place}. The lamps are low and something is moving down here. Come get us."),
		CallDeep2 = line("Deep", "Call",
			"Bunker, this is {name}. The way back fell in behind us in {place}. We can hear them digging. Please hurry."),

		HomeAny = line("Any", "Home", "came home through the Blast Door"),

		EarlySurface = line("Surface", "Early", "covered the town fast and turned for home a cycle early"),
		EarlyDeep = line("Deep", "Early", "moved fast through {place} and turned for home a cycle early"),

		UnheardAny = line("Any", "Unheard", "radioed for help from {place}, but no Radio Room heard the call"),
	},
}
