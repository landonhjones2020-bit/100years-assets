--!strict
--[[
	Remotes: the one list of network events, and the only way code touches them
	(bible Section 23: a small set of typed RemoteEvents, each checked on the server and
	rate-limited per player; clients send intentions, never results).

	Adding a remote is one entry in DEFINITIONS:
	* To = "Server" (client -> server): Args holds one checker per argument (extra arguments
	  are rejected), Rate limits each player. The handler only runs for calls that pass.
	* To = "Client" (server -> client): the server is trusted; no checks.
	* Unreliable = true makes an UnreliableRemoteEvent (cosmetic, high-frequency traffic).
	* Place = "Run" or "Lobby" makes it exist in that place only (default: both).

	Server: Remotes.Setup() once (Bootstrap), then Remotes.OnServer(name, handler) and
	Remotes.FireClient / FireClients / FireAllClients. Client: Remotes.OnClient(name, handler)
	and Remotes.FireServer(name, ...). The RemoteEvents live under this ModuleScript.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Check = require(script.Parent.Utilities.Check)
local Constants = require(script.Parent.Constants)
local Log = require(script.Parent.Utilities.Log)
local RateLimit = require(script.Parent.Utilities.RateLimit)

export type Definition = {
	To: "Server" | "Client",
	Args: { Check.Checker }?,
	Rate: { Burst: number, PerSecond: number }?,
	Unreliable: boolean?,
	Place: Constants.PlaceKind?,
	Doc: string,
}

local DEFINITIONS: { [string]: Definition } = {
	-- client -> server
	ClientReady = {
		To = "Server",
		Args = {},
		Rate = { Burst = 2, PerSecond = 0.05 },
		Doc = "The client finished bootstrapping; the server sends it the replication snapshot.",
	},
	DevCommand = {
		To = "Server",
		Args = {
			Check.string(48, { pattern = "^[%w_%.%-]+$", min = 1 }),
			Check.array(Check.primitive(120), 8),
		},
		Rate = { Burst = 6, PerSecond = 2 },
		Doc = "A DevTools command (name, arguments) from a player; DevService checks permission.",
	},
	SetReady = {
		To = "Server",
		Place = "Run",
		Args = { Check.boolean() },
		Rate = { Burst = 4, PerSecond = 1 },
		Doc = "Ready (true) or not (false) to skip the rest of the day phase to the Surge siren (CycleClock).",
	},
	PingCell = {
		To = "Server",
		Place = "Run",
		Args = { Check.integer(1, 10), Check.integer(-6, 6) },
		Rate = { Burst = 3, PerSecond = 0.5 },
		Doc = "Ping a bunker cell (floor, column) from the Command View; PingService shows it to the team.",
	},

	Propose = {
		To = "Server",
		Place = "Run",
		Args = {
			Check.enum({ "Build", "Upgrade", "Merge", "TearDown" }),
			Check.integer(1, 10),
			Check.integer(-6, 6),
			Check.string(24, { pattern = "^%w*$" }),
		},
		Rate = { Burst = 3, PerSecond = 0.5 },
		Doc = "Propose construction from the Command View: action, floor, column, and the room type (Build) or the other room's id (Merge); BuildService checks it and VoteService puts it to the team.",
	},
	CastVote = {
		To = "Server",
		Place = "Run",
		Args = { Check.string(12, { pattern = "^V%d+$", min = 2 }), Check.enum({ "Yes", "No" }) },
		Rate = { Burst = 6, PerSecond = 2 },
		Doc = "Vote yes or no on the vote on the banner (VoteService); a player can change their vote until it closes.",
	},

	AssignResident = {
		To = "Server",
		Place = "Run",
		Args = { Check.string(12, { pattern = "^N%d+$", min = 2 }), Check.string(12, { pattern = "^R?%d*$" }) },
		Rate = { Burst = 8, PerSecond = 3 },
		Doc = "Give a resident a job (a room id) or take it away (\"\"); no vote (Section 8). ResidentService checks the room has a job and a free slot.",
	},
	AutoAssign = {
		To = "Server",
		Place = "Run",
		Args = {},
		Rate = { Burst = 2, PerSecond = 0.5 },
		Doc = "Auto-Assign (Section 7): fill empty job slots with idle residents by best stat.",
	},
	ReviveResident = {
		To = "Server",
		Place = "Run",
		Args = { Check.string(12, { pattern = "^N%d+$", min = 2 }) },
		Rate = { Burst = 3, PerSecond = 1 },
		Doc = "Revive a downed resident with a Medkit from the stockpile (the resident's prompt; Section 11).",
	},
	SelectSlot = {
		To = "Server",
		Place = "Run",
		Args = { Check.integer(0, 5) },
		Rate = { Burst = 10, PerSecond = 8 },
		Doc = "Hold a hotbar slot's item (1 to 5; 0 = the melee weapon) (WeaponService, Section 9).",
	},
	FireWeapon = {
		To = "Server",
		Place = "Run",
		Args = {
			Check.integer(1, 2), -- the gun's hotbar slot
			Check.integer(1, 2 ^ 30), -- the shot's number
			Check.vector3(20000), -- where it left the muzzle
			Check.vector3(1.01), -- the aim, before spread
			Check.number({ min = 0 }), -- the client's server time when it fired
			Check.array(Check.shape({
				Id = Check.string(12, { pattern = "^M%d+$", min = 2 }), -- monsters only: no friendly fire
				Point = Check.vector3(20000),
				Pellet = Check.integer(1, 16),
			}), 16),
		},
		Rate = { Burst = 24, PerSecond = 16 },
		Doc = "A shot: slot, shot number, origin, aim, time and the hits the client saw; the server checks it all (Section 23).",
	},
	ReloadWeapon = {
		To = "Server",
		Place = "Run",
		Args = {},
		Rate = { Burst = 4, PerSecond = 2 },
		Doc = "Reload the held gun from carried ammo (Section 9).",
	},
	MeleeSwing = {
		To = "Server",
		Place = "Run",
		Args = { Check.boolean(), Check.vector3(1.01) },
		Rate = { Burst = 6, PerSecond = 5 },
		Doc = "A melee swing: heavy or light, and the way the player faces; the hit is checked when it lands (Section 9).",
	},
	Dodge = {
		To = "Server",
		Place = "Run",
		Args = { Check.vector3(1.01) },
		Rate = { Burst = 3, PerSecond = 2 },
		Doc = "A dodge roll: costs stamina and gives a moment of invulnerability; the client moves the character (Section 9).",
	},
	Sprint = {
		To = "Server",
		Place = "Run",
		Args = { Check.boolean() },
		Rate = { Burst = 8, PerSecond = 4 },
		Doc = "Sprinting on or off, for the stamina it drains (Section 9).",
	},
	ThrowItem = {
		To = "Server",
		Place = "Run",
		Args = {
			Check.integer(4, 5), -- the throwable's hotbar slot
			Check.vector3(20000), -- where it leaves the hand
			Check.vector3(1.01), -- the aim
		},
		Rate = { Burst = 3, PerSecond = 2 },
		Doc = "Throw one of the held slot's throwables toward the aim (Landon, 2026-11-08: Fire throws).",
	},
	UseMedkit = {
		To = "Server",
		Place = "Run",
		Args = {},
		Rate = { Burst = 3, PerSecond = 2 },
		Doc = "Use a carried Medkit: it heals over Tuning.Player.MedkitSeconds (Landon, 2026-11-08: the Heal button).",
	},
	UseTool = {
		To = "Server",
		Place = "Run",
		Args = { Check.boolean() },
		Rate = { Burst = 8, PerSecond = 6 },
		Doc = "Start (true) or stop (false) using the held tool while Fire is held: the Extinguisher sprays, the Welder repairs what the player faces (WeaponService; Prompt 13).",
	},

	-- server -> client
	Delta = {
		To = "Client",
		Doc = "The delta channel: batched collection ops (see Utilities.Delta), plus a snapshot flag.",
	},
	Notice = {
		To = "Client",
		Doc = "A text message for one player (DevTools output for now).",
	},
	Alert = {
		To = "Client",
		Doc = "A message for the HUD's alert feed: kind (Danger, Warning, Info) and text (a refused proposal, a vote that failed...).",
	},
	CellPinged = {
		To = "Client",
		Place = "Run",
		Doc = "A player pinged a cell: floor, column, the player's UserId and display name (PingService).",
	},
	BreachWarning = {
		To = "Client",
		Place = "Run",
		Doc = "A breach is coming (Section 10): floor, column, seconds of warning, where (text), how many monsters, and the room id if it is a vent (BreachService).",
	},
	HitConfirmed = {
		To = "Client",
		Place = "Run",
		Doc = "What the player's shot or swing did: the combatant id, the damage, whether it died, and where (WeaponService).",
	},
}

local log = Log.new("Remotes")
local IS_SERVER = RunService:IsServer()
local WAIT_SECONDS = 15
local REJECTION_LOG_SECONDS = 10

export type Stats = { Received: number, Rejected: number, Limited: number, Failed: number }

local stats: { [string]: Stats } = {}
local limiters: { [string]: RateLimit.Limiter } = {}
local handled: { [string]: boolean } = {}
local lastRejectionLog: { [Player]: number } = {}

for name, definition in DEFINITIONS do
	assert(definition.To == "Server" or definition.To == "Client", `Remote {name}: To must be Server or Client`)
	assert(definition.Place == nil or definition.Place == "Lobby" or definition.Place == "Run", `Remote {name}: Place must be Lobby or Run`)
	if definition.To == "Server" then
		assert(definition.Args, `Remote {name}: a client -> server remote needs Args`)
		assert(definition.Rate, `Remote {name}: a client -> server remote needs a Rate`)
	end
	stats[name] = { Received = 0, Rejected = 0, Limited = 0, Failed = 0 }
	table.freeze(definition)
end
table.freeze(DEFINITIONS)

local Remotes = {}

Remotes.Definitions = DEFINITIONS

-- Does this remote exist in this place?
function Remotes.InPlace(name: string): boolean
	local definition = DEFINITIONS[name]
	return definition ~= nil and (definition.Place == nil or definition.Place == Constants.PlaceKind())
end

local function definitionOf(name: string, direction: "Server" | "Client"): Definition
	local definition = DEFINITIONS[name]
	if not definition then
		error(`Unknown remote {tostring(name)}`, 3)
	end
	if definition.To ~= direction then
		error(`Remote {name} goes to the {definition.To:lower()}, not the {direction:lower()}`, 3)
	end
	if definition.Place ~= nil and definition.Place ~= Constants.PlaceKind() then
		error(`Remote {name} only exists in the {definition.Place} place`, 3)
	end
	return definition
end

local function instanceOf(name: string): RemoteEvent
	local found = script:FindFirstChild(name)
	if not found then
		if IS_SERVER then
			error(`Remote {name} doesn't exist yet: call Remotes.Setup() first`, 3)
		end
		found = script:WaitForChild(name, WAIT_SECONDS)
		if not found then
			error(`Remote {name} didn't arrive within {WAIT_SECONDS} s`, 3)
		end
	end
	return found :: any
end

-- Server: create every RemoteEvent. Idempotent.
function Remotes.Setup()
	assert(IS_SERVER, "Remotes.Setup runs on the server")
	local place = Constants.PlaceKind()
	for name, definition in DEFINITIONS do
		local className = if definition.Unreliable then "UnreliableRemoteEvent" else "RemoteEvent"
		local existing = script:FindFirstChild(name)
		if definition.Place ~= nil and definition.Place ~= place then
			if existing then
				existing:Destroy()
			end
			continue
		end
		if existing and existing.ClassName ~= className then
			existing:Destroy()
			existing = nil
		end
		if not existing then
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = script
		end
		if definition.Rate then
			limiters[name] = RateLimit.new(definition.Rate.Burst, definition.Rate.PerSecond)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		for _, limiter in limiters do
			limiter:Forget(player)
		end
		lastRejectionLog[player] = nil
	end)
end

local function noteRejection(player: Player, name: string, why: string)
	local now = os.clock()
	local last = lastRejectionLog[player]
	if last and now - last < REJECTION_LOG_SECONDS then
		return
	end
	lastRejectionLog[player] = now
	log:Warn("rejected %s from %s (%d): %s", name, player.Name, player.UserId, why)
end

-- Server: the handler for a client -> server remote. One handler per remote.
function Remotes.OnServer(name: string, handler: (player: Player, ...any) -> ())
	assert(IS_SERVER, "Remotes.OnServer runs on the server")
	local definition = definitionOf(name, "Server")
	assert(not handled[name], `Remote {name} already has a handler`)
	handled[name] = true
	local checks = definition.Args :: { Check.Checker }
	local limiter = limiters[name]
	local counters = stats[name]
	instanceOf(name).OnServerEvent:Connect(function(player: Player, ...: any)
		counters.Received += 1
		if limiter and not limiter:Take(player) then
			counters.Limited += 1
			noteRejection(player, name, "rate limit")
			return
		end
		local count = select("#", ...)
		if count > #checks then
			counters.Rejected += 1
			noteRejection(player, name, `{count} arguments, expected at most {#checks}`)
			return
		end
		local args = { ... }
		for index, check in checks do
			local ok, why = check(args[index])
			if not ok then
				counters.Rejected += 1
				noteRejection(player, name, `argument {index}: {why}`)
				return
			end
		end
		local ok, err = xpcall(handler, debug.traceback, player, table.unpack(args, 1, count))
		if not ok then
			counters.Failed += 1
			log:Error("%s handler failed for %s: %s", name, player.Name, tostring(err))
		end
	end)
end

function Remotes.FireClient(name: string, player: Player, ...: any)
	definitionOf(name, "Client")
	instanceOf(name):FireClient(player, ...)
end

function Remotes.FireClients(name: string, players: { Player }, ...: any)
	definitionOf(name, "Client")
	local remote = instanceOf(name)
	for _, player in players do
		remote:FireClient(player, ...)
	end
end

function Remotes.FireAllClients(name: string, ...: any)
	definitionOf(name, "Client")
	instanceOf(name):FireAllClients(...)
end

-- Client: the handler for a server -> client remote.
function Remotes.OnClient(name: string, handler: (...any) -> ()): RBXScriptConnection
	assert(not IS_SERVER, "Remotes.OnClient runs on the client")
	definitionOf(name, "Client")
	return instanceOf(name).OnClientEvent:Connect(handler)
end

function Remotes.FireServer(name: string, ...: any)
	assert(not IS_SERVER, "Remotes.FireServer runs on the client")
	definitionOf(name, "Server")
	instanceOf(name):FireServer(...)
end

-- Server: counters per remote, for DevTools.
function Remotes.Stats(): { [string]: Stats }
	return stats
end

return table.freeze(Remotes)
