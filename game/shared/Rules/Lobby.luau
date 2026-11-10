--!strict
--[[
	Rules.Lobby: the elevator pads' rules (bible Section 21; difficulty unlocks: Section 5). Pure,
	so PadService, the pad's panel and the data tests share it. Numbers are Tuning.Lobby; the pads
	are Config.Pads.

	* Difficulty: Normal from the start; Hard after a victory (the profile's Stats.Wins); Nightmare
	  after a Hard win (Stats.HardWins). Unlocked(stats, id); a pad's riders must all have its
	  difficulty unlocked.
	* A public pad counts down PadCountdownSeconds from its first rider and leaves when the time is
	  up or it is full. A private pad leaves when its leader says so. A solo pad leaves
	  SoloCountdownSeconds after its rider steps on.
	* MayBoard(pad, spec, rider) says whether a player may step on, and why not.
]]

local Config = require(script.Parent.Parent.Config)

local Lobby = {}

export type Pad = {
	Id: string,
	Kind: string, -- Public, Private, Solo
	Difficulty: string,
	Riders: { number }, -- user ids in the order they stepped on; the first leads a private pad
	Invited: { [number]: boolean }?, -- a private pad's guests
	Phase: string, -- Idle, Waiting (a private pad with its party), Counting, Launching
	LeavesAt: number?, -- server time the countdown ends
}

function Lobby.Unlocked(stats: { [string]: number }?, difficulty: string): boolean
	if difficulty == "Normal" then
		return true
	elseif difficulty == "Hard" then
		return stats ~= nil and (stats.Wins or 0) >= 1
	elseif difficulty == "Nightmare" then
		return stats ~= nil and (stats.HardWins or 0) >= 1
	end
	return false
end

-- The difficulties a profile can pick, easiest first.
function Lobby.Difficulties(stats: { [string]: number }?): { string }
	local out = {}
	for _, id in Config.Ids("Difficulties") do
		if Lobby.Unlocked(stats, id) then
			table.insert(out, id)
		end
	end
	return out
end

-- The difficulty after `current` among those every listed player has unlocked (wraps round).
function Lobby.NextDifficulty(current: string, statsList: { { [string]: number }? }): string
	local all = Config.Ids("Difficulties")
	local start = table.find(all, current) or 1
	for step = 1, #all do
		local id = all[(start - 1 + step) % #all + 1]
		local ok = true
		for _, stats in statsList do
			ok = ok and Lobby.Unlocked(stats, id)
		end
		if ok then
			return id
		end
	end
	return "Normal"
end

function Lobby.Capacity(kind: string): number
	return if kind == "Solo" then 1 else Config.Get("Tuning", "Lobby").PartyMax
end

-- Whether a player may step onto the pad now, and why not.
function Lobby.MayBoard(pad: Pad, userId: number, stats: { [string]: number }?): (boolean, string?)
	if table.find(pad.Riders, userId) then
		return true, nil
	end
	if pad.Phase == "Launching" then
		return false, "THIS PAD IS LEAVING"
	end
	if #pad.Riders >= Lobby.Capacity(pad.Kind) then
		return false, "THIS PAD IS FULL"
	end
	if pad.Kind == "Private" and #pad.Riders > 0 and not (pad.Invited and pad.Invited[userId]) then
		return false, "A PRIVATE PAD: ITS LEADER HAS TO INVITE YOU"
	end
	if not Lobby.Unlocked(stats, pad.Difficulty) then
		local spec = Config.Get("Difficulties", pad.Difficulty)
		return false, string.upper(`{spec.Name} UNLOCKS {spec.Unlock}`)
	end
	return true, nil
end

-- How long a pad counts down once it starts to.
function Lobby.CountdownSeconds(kind: string): number
	local t = Config.Get("Tuning", "Lobby")
	return if kind == "Solo" then t.SoloCountdownSeconds else t.PadCountdownSeconds
end

-- The words on a pad's sign: its kind and difficulty.
function Lobby.Title(pad: Pad): string
	local spec = Config.Find("Pads", pad.Id)
	local name = if spec then spec.Name else pad.Kind
	return string.upper(`{name} · {pad.Difficulty}`)
end

return table.freeze(Lobby)
