--!strict
--[[
	DevService: DevTools commands (bible Section 23: test commands gated to Studio and
	admins).

	Services register their own commands in Init:

		registry.DevService:Register("year", {
			Description = "Set the year counter.",
			Usage = "year <number>",
			Run = function(player, args) ... return "Year is now 25" end,
		})

	Three ways in, all through Execute:
	* in a game, an allowed player types `/dev <command> [args]` in chat (DevController sends
	  the DevCommand remote; permission is checked here, never trusted from the client);
	* in a Studio playtest, tools call ServerScriptService.DevTools.Invoke (a
	  BindableFunction made only in Studio): `Invoke:Invoke("test")`;
	* in Studio, the data tests and StructureCheck run once when the server starts.

	Allowed: everyone in Studio; outside Studio only Constants.ADMIN_USER_IDS. Players get a
	DevAllowed attribute so their client can show the command.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local BuildInfo = require(Shared.BuildInfo) :: any
local Constants = require(Shared.Constants)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local TableUtil = require(Shared.Utilities.TableUtil)
local Types = require(Shared.Types)

local log = Log.new("DevService")
local IS_STUDIO = RunService:IsStudio()
local MAX_OUTPUT = 3000

local DevService = {
	Name = "DevService",
	Dependencies = {},
}

local commands: { [string]: Types.DevCommand } = {}

function DevService:IsAllowed(player: Player?): boolean
	if IS_STUDIO then
		return true
	end
	return player ~= nil and Constants.ADMIN_USER_IDS[player.UserId] == true
end

function DevService:Register(name: string, command: Types.DevCommand)
	assert(type(name) == "string" and string.find(name, "^[%w_%.%-]+$"), "DevService: command names are words")
	assert(commands[name] == nil, `DevService: command {name} is already registered`)
	assert(type(command.Run) == "function" and type(command.Description) == "string", "DevService: bad command")
	commands[name] = command
end

-- Runs a command for a player (nil = Studio tooling). Returns ok and the output text.
function DevService:Execute(player: Player?, name: string, args: { any }): (boolean, string)
	if not DevService:IsAllowed(player) then
		return false, "not allowed"
	end
	local command = commands[name]
	if not command then
		return false, `no command {name}; try help`
	end
	local who = if player then player.Name else "studio"
	local shown = {}
	for _, arg in args do
		table.insert(shown, tostring(arg))
	end
	log:Info("%s ran %s %s", who, name, table.concat(shown, " "))
	local ok, result = xpcall(command.Run, debug.traceback, player, args)
	if not ok then
		log:Error("%s failed: %s", name, tostring(result))
		return false, `{name} failed: {tostring(result)}`
	end
	local text = if result == nil then "done" else tostring(result)
	if #text > MAX_OUTPUT then
		text = string.sub(text, 1, MAX_OUTPUT) .. "\n...(cut)"
	end
	return true, text
end

local function splitLine(line: string): (string, { any })
	local words = {}
	for word in string.gmatch(line, "%S+") do
		local number = tonumber(word)
		if word == "true" then
			table.insert(words, true)
		elseif word == "false" then
			table.insert(words, false)
		elseif number ~= nil and number == number and math.abs(number) ~= math.huge then
			table.insert(words, number)
		else
			table.insert(words, word)
		end
	end
	local name = table.remove(words, 1)
	return tostring(name or "help"), words
end

local function runChecks(): string
	local DevTools = ServerScriptService:FindFirstChild("DevTools")
	if not DevTools then
		return "DevTools folder missing"
	end
	local lines = {}
	local structure = require(DevTools:FindFirstChild("StructureCheck") :: ModuleScript) :: any
	local tests = require(DevTools:FindFirstChild("DataTests") :: ModuleScript) :: any
	table.insert(lines, structure.Format(structure.Run({ Runtime = true })))
	table.insert(lines, tests.Format(tests.Run()))
	return table.concat(lines, "\n")
end

local function registerBuiltIns()
	DevService:Register("help", {
		Description = "List commands.",
		Run = function(): string?
			local lines = {}
			for _, name in TableUtil.SortedKeys(commands) do
				local command = commands[name]
				table.insert(lines, `{command.Usage or name}: {command.Description}`)
			end
			return table.concat(lines, "\n")
		end,
	})
	DevService:Register("version", {
		Description = "Build, place and server.",
		Run = function(): string?
			return `{Constants.GAME_NAME} {BuildInfo.Label} | {Constants.PlaceKind()} | job {game.JobId} | Studio {IS_STUDIO}`
		end,
	})
	DevService:Register("ping", {
		Description = "Round trip check.",
		Run = function(player: Player?): string?
			local who = if player then player.Name else "studio"
			return `pong {who} at {string.format("%.3f", workspace:GetServerTimeNow())}`
		end,
	})
	DevService:Register("structure", {
		Description = "Run StructureCheck (instances, scripts, remotes, config).",
		Run = function(): string?
			local DevTools = ServerScriptService:FindFirstChild("DevTools")
			local structure = require((DevTools :: Instance):FindFirstChild("StructureCheck") :: ModuleScript) :: any
			return structure.Format(structure.Run({ Runtime = true }))
		end,
	})
	DevService:Register("test", {
		Description = "Run the data tests.",
		Usage = "test [name filter]",
		Run = function(_player: Player?, args: { any }): string?
			local DevTools = ServerScriptService:FindFirstChild("DevTools")
			local tests = require((DevTools :: Instance):FindFirstChild("DataTests") :: ModuleScript) :: any
			return tests.Format(tests.Run(if args[1] then tostring(args[1]) else nil))
		end,
	})
	DevService:Register("log", {
		Description = "Show or set the server log level (Debug, Info, Warn, Error).",
		Usage = "log [level]",
		Run = function(_player: Player?, args: { any }): string?
			local level = args[1]
			if level ~= nil then
				if not Log.IsLevel(level) then
					return "levels: Debug, Info, Warn, Error"
				end
				Log.SetLevel(level :: Log.Level)
			end
			return `server log level {Log.GetLevel()}`
		end,
	})
	DevService:Register("logs", {
		Description = "The last server log lines.",
		Usage = "logs [count]",
		Run = function(_player: Player?, args: { any }): string?
			local count = if type(args[1]) == "number" then args[1] else 20
			return table.concat(Log.Recent(count), "\n")
		end,
	})
	DevService:Register("remotes", {
		Description = "Traffic and rejections per remote.",
		Run = function(): string?
			local lines = {}
			local stats = Remotes.Stats()
			for _, name in TableUtil.SortedKeys(stats) do
				local s = stats[name]
				table.insert(
					lines,
					`{name}: received {s.Received}, rejected {s.Rejected}, rate-limited {s.Limited}, failed {s.Failed}`
				)
			end
			return table.concat(lines, "\n")
		end,
	})
	DevService:Register("players", {
		Description = "Players and their session state.",
		Run = function(): string?
			local lines = {}
			for _, player in Players:GetPlayers() do
				table.insert(
					lines,
					`{player.Name} ({player.UserId}) ready={tostring(player:GetAttribute("ClientReady") == true)}`
				)
			end
			return if #lines > 0 then table.concat(lines, "\n") else "no players"
		end,
	})
end

function DevService:Init(_registry)
	registerBuiltIns()
	Remotes.OnServer("DevCommand", function(player: Player, name: string, args: { any })
		local ok, text = DevService:Execute(player, name, args)
		if not ok and text == "not allowed" then
			log:Warn("%s (%d) tried dev command %s without permission", player.Name, player.UserId, name)
			return
		end
		local prefix = if ok then "" else "error: "
		Remotes.FireClient("Notice", player, prefix .. text)
	end)
end

function DevService:Start()
	local function mark(player: Player)
		player:SetAttribute("DevAllowed", DevService:IsAllowed(player))
	end
	Players.PlayerAdded:Connect(mark)
	for _, player in Players:GetPlayers() do
		mark(player)
	end

	if IS_STUDIO then
		local DevTools = ServerScriptService:FindFirstChild("DevTools")
		if DevTools then
			local invoke = Instance.new("BindableFunction")
			invoke.Name = "Invoke"
			invoke.OnInvoke = function(line: any, ...: any): string
				if type(line) ~= "string" then
					return "usage: Invoke:Invoke(\"command arg1 arg2\")"
				end
				local name, args = splitLine(line)
				for _, extra in { ... } do
					table.insert(args, extra)
				end
				local ok, text = DevService:Execute(nil, name, args)
				return (if ok then "" else "error: ") .. text
			end
			invoke.Parent = DevTools
			if DevTools:GetAttribute("RunChecksOnStart") ~= false then
				task.defer(function()
					log:Info("Studio start checks:\n%s", runChecks())
				end)
			end
		end
	end
end

return DevService
