--!strict
--[[
	DevController: the client side of DevTools.

	For players the server marked DevAllowed (everyone in Studio, admins in a live game) it
	adds a chat command: `/dev <command> [args]` (or `/d`). Commands run on the server
	(DevService checks permission again); the answer comes back as a Notice, shown in the
	chat and the output. Four commands run on the client:
	* `/dev replica <collection>` prints this client's mirror of a collection;
	* `/dev client` prints the client's replication counters;
	* `/dev clock` prints the run state as this client sees it (Run place), with the time
	  left counted on this client from the replicated server time;
	* `/dev ready [true|false]` fires the SetReady remote, as the HUD's Ready button will,
	  and reports what the server did.

	In Studio it also makes PlayerScripts.DevInvoke (a BindableFunction) so tools can run the
	same commands from the Client datamodel: DevInvoke:Invoke("replica _SelfTest").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local RunState = require(Shared.RunState)
local TableUtil = require(Shared.Utilities.TableUtil)

local log = Log.new("DevController")
local CHAT_LINES = 12

local DevController = {
	Name = "DevController",
	Dependencies = { "ReplicaController" },
}

local replica: any = nil
local lastNotice: string? = nil
local commandMade = false

local function dump(value: any, depth: number?): string
	local level = depth or 0
	if type(value) == "string" then
		return if value == "\0none" then "NONE" else string.format("%q", value)
	elseif typeof(value) == "Vector3" then
		return string.format("(%g, %g, %g)", value.X, value.Y, value.Z)
	elseif type(value) ~= "table" then
		return tostring(value)
	elseif level > 4 then
		return "{...}"
	end
	local parts = {}
	for _, key in TableUtil.SortedKeys(value) do
		table.insert(parts, `{tostring(key)}={dump(value[key], level + 1)}`)
	end
	return "{" .. table.concat(parts, ", ") .. "}"
end

local function escape(text: string): string
	return (string.gsub(string.gsub(string.gsub(text, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

local function show(text: string)
	print(`[100Y dev] {text}`)
	local channels = TextChatService:FindFirstChild("TextChannels")
	local system = channels and channels:FindFirstChild("RBXSystem")
	if system and system:IsA("TextChannel") then
		local lines = string.split(text, "\n")
		for index = 1, math.min(#lines, CHAT_LINES) do
			pcall(system.DisplaySystemMessage, system, escape(lines[index]))
		end
		if #lines > CHAT_LINES then
			pcall(system.DisplaySystemMessage, system, `... {#lines - CHAT_LINES} more lines in the output (F9)`)
		end
	end
end

local function parse(text: string): (string, { any })
	local words = {}
	for word in string.gmatch(text, "%S+") do
		local number = tonumber(word)
		if word == "true" or word == "false" then
			table.insert(words, word == "true")
		elseif number ~= nil and number == number and math.abs(number) ~= math.huge then
			table.insert(words, number)
		else
			table.insert(words, string.sub(word, 1, 120))
		end
	end
	local name = table.remove(words, 1)
	return if type(name) == "string" then name else "help", words
end

local function describeClock(): string
	local runPhase = RunState.Get("RunPhase")
	if runPhase == nil then
		return "no run state in this place"
	end
	local left = RunState.TimeLeft()
	local leftText = if left then string.format("%.1f s left", left) else "stopped"
	local boss = RunState.Get("SurgeBoss")
	local bossText = if boss then ` ({boss})` else ""
	return `client sees: {runPhase}, cycle {RunState.Get("Cycle")}, Year {RunState.Get("Year")} ({RunState.Get("Era")}), `
		.. `{RunState.Get("CyclePhase") or "-"} {leftText}, siren {tostring(RunState.Get("Siren") == true)}, `
		.. `Surge {RunState.Get("SurgeKind") or "-"}{bossText}, {RunState.Get("YearsPerCycle")} years per cycle, `
		.. `ready {RunState.Get("ReadyCount") or 0}/{RunState.Get("ReadyNeeded") or 0}`
end

local function pressReady(on: boolean): string
	if not Remotes.InPlace("SetReady") then
		return "there is no run clock in this place"
	end
	local player = Players.LocalPlayer
	Remotes.FireServer("SetReady", on)
	local waited = 0
	while waited < 2 and player:GetAttribute("Ready") ~= on and not (on and RunState.Get("Siren") == true) do
		waited += task.wait()
	end
	return `SetReady {on}: my Ready is {tostring(player:GetAttribute("Ready"))}\n{describeClock()}`
end

-- Runs a command line; client-side commands answer here, the rest go to the server.
local function run(text: string): string?
	local name, args = parse(text)
	if name == "replica" then
		local collection = tostring(args[1] or "")
		local values = replica:All(collection)
		local keys = TableUtil.SortedKeys(values)
		if #keys == 0 then
			return `{collection}: empty on this client`
		end
		local lines = { `{collection}: {#keys} values` }
		for _, key in keys do
			table.insert(lines, `  {key} = {dump(values[key])}`)
		end
		return table.concat(lines, "\n")
	elseif name == "client" then
		local stats = replica:Stats()
		return `client: ready={tostring(replica:IsReady())}, delta events {stats.Events}, ops {stats.Ops}, snapshots {stats.Snapshots}`
	elseif name == "clock" then
		return describeClock()
	elseif name == "ready" then
		return pressReady(args[1] ~= false)
	end
	if #args > 8 then
		return "at most 8 arguments"
	end
	Remotes.FireServer("DevCommand", string.sub(name, 1, 48), args)
	return nil
end

local function makeChatCommand()
	if commandMade or Players.LocalPlayer:GetAttribute("DevAllowed") ~= true then
		return
	end
	commandMade = true
	local command = Instance.new("TextChatCommand")
	command.Name = "DevCommand"
	command.PrimaryAlias = "/dev"
	command.SecondaryAlias = "/d"
	command.Triggered:Connect(function(_source: TextSource, message: string)
		local rest = string.match(message, "^%S+%s*(.*)$") or ""
		local answer = run(if rest == "" then "help" else rest)
		if answer then
			show(answer)
		end
	end)
	command.Parent = TextChatService
	log:Debug("/dev ready")
end

function DevController:Init(registry)
	replica = registry.ReplicaController
	Remotes.OnClient("Notice", function(text: any)
		if type(text) == "string" then
			lastNotice = text
			show(text)
		end
	end)
end

function DevController:Start()
	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal("DevAllowed"):Connect(makeChatCommand)
	makeChatCommand()

	if RunService:IsStudio() then
		local invoke = Instance.new("BindableFunction")
		invoke.Name = "DevInvoke"
		invoke.OnInvoke = function(line: any): string
			if type(line) ~= "string" then
				return "usage: DevInvoke:Invoke(\"replica Rooms\")"
			end
			lastNotice = nil
			local answer = run(line)
			if answer then
				return answer
			end
			local waited = 0
			while lastNotice == nil and waited < 5 do
				waited += task.wait()
			end
			return lastNotice or "no answer from the server within 5 s"
		end
		invoke.Parent = script.Parent.Parent
	end
end

return DevController
