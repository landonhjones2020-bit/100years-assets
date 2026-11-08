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

	Server: Remotes.Setup() once (Bootstrap), then Remotes.OnServer(name, handler) and
	Remotes.FireClient / FireClients / FireAllClients. Client: Remotes.OnClient(name, handler)
	and Remotes.FireServer(name, ...). The RemoteEvents live under this ModuleScript.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Check = require(script.Parent.Utilities.Check)
local Log = require(script.Parent.Utilities.Log)
local RateLimit = require(script.Parent.Utilities.RateLimit)

export type Definition = {
	To: "Server" | "Client",
	Args: { Check.Checker }?,
	Rate: { Burst: number, PerSecond: number }?,
	Unreliable: boolean?,
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

	-- server -> client
	Delta = {
		To = "Client",
		Doc = "The delta channel: batched collection ops (see Utilities.Delta), plus a snapshot flag.",
	},
	Notice = {
		To = "Client",
		Doc = "A text message for one player (DevTools output for now).",
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

local function definitionOf(name: string, direction: "Server" | "Client"): Definition
	local definition = DEFINITIONS[name]
	if not definition then
		error(`Unknown remote {tostring(name)}`, 3)
	end
	if definition.To ~= direction then
		error(`Remote {name} goes to the {definition.To:lower()}, not the {direction:lower()}`, 3)
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
	for name, definition in DEFINITIONS do
		local className = if definition.Unreliable then "UnreliableRemoteEvent" else "RemoteEvent"
		local existing = script:FindFirstChild(name)
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
