--!strict
--[[
	Constants: identity and engine limits that every module may need.

	Gameplay numbers (costs, timings, stats) are content and live in Config, never here.
	These are the facts about the game itself and the provisional limits from bible
	Section 23 that size the simulation.
]]

export type PlaceKind = "Lobby" | "Run"

local Constants = {}

Constants.GAME_NAME = "100 Years Of Fallout"
Constants.UNIVERSE_ID = 10775267993
Constants.OWNER_USER_ID = 9768530298

-- Place ids (bible Section 23: two places, Lobby is the start place)
Constants.PLACE_IDS = table.freeze({
	Lobby = 135073046693952,
	Run = 72892455946761,
})

Constants.MAX_PLAYERS = table.freeze({
	Lobby = 30,
	Run = 6,
})

-- Simulation caps (provisional, bible Section 23)
Constants.CAPS = table.freeze({
	Residents = 40,
	Monsters = 25,
	Players = 6,
})

Constants.RESIDENT_TICK_HZ = 5 -- residents are simulated at 5 Hz along the room graph
Constants.SHOT_HISTORY_SECONDS = 0.25 -- gun checks look this far back for the target
Constants.AUTOSAVE_SECONDS = 120 -- profiles autosave this often (plus on leave and shutdown)
Constants.DELTA_HZ = 10 -- the delta channel flushes this often

-- Who may run DevTools commands outside Studio (Studio allows everyone in a playtest)
Constants.ADMIN_USER_IDS = table.freeze({
	[9768530298] = true,
})

--[[
	Which place this is. The PlaceId decides; a copied or local place falls back on the
	`PlaceKind` attribute the installer sets on Workspace.
]]
function Constants.PlaceKind(): PlaceKind
	local placeId = game.PlaceId
	if placeId == Constants.PLACE_IDS.Lobby then
		return "Lobby"
	elseif placeId == Constants.PLACE_IDS.Run then
		return "Run"
	end
	local attribute = workspace:GetAttribute("PlaceKind")
	if attribute == "Lobby" then
		return "Lobby"
	elseif attribute == "Run" then
		return "Run"
	end
	error(`Unknown place: PlaceId {placeId} and no PlaceKind attribute on Workspace`)
end

return table.freeze(Constants)
