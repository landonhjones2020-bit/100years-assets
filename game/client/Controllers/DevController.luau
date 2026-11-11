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
	  and reports what the server did;
	* `/dev camera` prints the over-the-shoulder camera's state; `camera.shoulder`,
	  `camera.aim [true|false]`, `camera.look <yaw> <pitch>` (degrees), `camera.zoom <studs>`
	  and `camera.cursor` (frees or locks the mouse) drive it for tests.
	* `/dev ui` prints The Frame's state; `ui.sample`, `ui.list` and `ui.dock` open the dev sample screens
	  (Lib.UISamples), `ui.open <screen>` any registered screen, `ui.close` closes, `ui.tab <id>`
	  switches tabs, `ui.main` presses the main action.
	* `/dev hud` prints the HUD's state; `hud.alert <Danger|Warning|Info> <text>`,
	  `hud.banner <text>`, `hud.slot <1-5>` and `hud.touch [true|false]` (shows the touch
	  buttons on any device, for screenshots) drive it.
	* `/dev vote` prints the vote telegram (what it shows, your vote) and the Command View's
	  ghosts; the server's `votes`, `vote.yes|no [n]`, `vote.end` and `vote.bots` run votes.
	* `/dev cv` prints the Command View's state (with the detail panel's options); `cv.open`,
	  `cv.close`, `cv.select <floor> <column>` and `cv.ping` drive it; `cv.ghost <floor> <column>
	  <span> [label]` / `cv.unghost` show a vote's ghost outline, `cv.blink <roomId> [false]` blinks
	  a room's label, `cv.overlay <Power|Morale|Threat|Production> [false]` sets a sample reading.

	In Studio it also makes PlayerScripts.DevInvoke (a BindableFunction) so tools can run the
	same commands from the Client datamodel: DevInvoke:Invoke("replica _SelfTest").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Utilities.Log)
local UISamples = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UISamples"))
local Remotes = require(Shared.Remotes)
local RunState = require(Shared.RunState)
local TableUtil = require(Shared.Utilities.TableUtil)

local log = Log.new("DevController")
local CHAT_LINES = 12

local DevController = {
	Name = "DevController",
	Dependencies = {
		"ReplicaController",
		"InputController",
		"CameraController",
		"UIController",
		"HUDController",
		"CommandViewController",
		"VoteController",
	},
}

local replica: any = nil
local camera: any = nil
local ui: any = nil
local hud: any = nil
local registryInput: any = nil
local commandView: any = nil
local voteView: any = nil
local devCursorFree = false
local extra: { [string]: (args: { any }) -> string? } = {} -- client commands other controllers add (DevController:Register)
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
	local leftText = if RunState.Get("PhaseOpen") then "no timer (until its boss is beaten)"
		elseif left then string.format("%.1f s left", left)
		else "stopped"
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

local function describeUI(): string
	task.wait()
	local gui = ui:Gui()
	if not gui then
		return "ui: no Frame in this place"
	end
	local page = ui:Page()
	local items = 0
	if page then
		local content = page:FindFirstChild("Content")
		for _, name in { "Grid", "List" } do
			local holder = content and content:FindFirstChild(name)
			if holder and holder:IsA("GuiObject") and holder.Visible then
				for _, child in holder:GetChildren() do
					if child:IsA("GuiObject") then
						items += 1
					end
				end
			end
		end
	end
	return string.format(
		"ui: %s, screen %s, tab %s, %d items, cursor free %s, input blocked %s",
		if gui.Enabled then "open" else "closed",
		tostring(ui:Current()),
		tostring(ui:CurrentTab()),
		items,
		tostring(camera:State().CursorFree),
		tostring(registryInput:IsBlocked())
	)
end

local function describeHUD(): string
	task.wait()
	local state = hud:State()
	if not state.Present then
		return "hud: no HUD in this place"
	end
	return string.format(
		"hud: %s, year %s, phase %s, time %s, ready button %s, slot %d, touch %s, class %s",
		if state.Enabled then "shown" elseif state.Hidden then "hidden (a menu is open)" else "hidden",
		tostring(state.Year),
		tostring(state.Phase),
		tostring(state.TimeLeft),
		tostring(state.Ready),
		state.Slot,
		tostring(state.Touch),
		tostring(state.Class)
	)
end

local function describeCommandView(): string
	task.wait()
	task.wait()
	local state = commandView:State()
	local main = ""
	local gui = ui:Gui()
	local button = gui and gui:FindFirstChild("Cabinet") and gui.Cabinet:FindFirstChild("MainAction")
	if button and button.Visible then
		main = `, main action "{button.Content.Label.Text}" ({if button:GetAttribute("Disabled") then "greyed out" else "live"})`
	end
	local detail = ""
	local page = gui and gui:FindFirstChild("Cabinet") and gui.Cabinet.Pages:FindFirstChild("CommandView")
	if page then
		local options = {}
		for _, row in page.Detail.Options:GetChildren() do
			if row:IsA("GuiObject") then
				table.insert(options, { row.LayoutOrder, `{row:FindFirstChild("Name").Text} ({row:FindFirstChild("Value").Text})` })
			end
		end
		table.sort(options, function(a, b)
			return a[1] < b[1]
		end)
		local names = {}
		for i, option in options do
			if i <= 24 then
				table.insert(names, `{i}. {option[2]}`)
			end
		end
		detail = `\n  detail: {page.Detail:FindFirstChild("Name").Text} / {page.Detail.Sub.Text}`
			.. (if #names > 0 then "\n  options: " .. table.concat(names, "; ") else "")
	end
	return string.format(
		"command view: %s, centre (%.0f, %.0f), %.1f floors high, camera %.0f studs away, FOV %.1f, selected %s, choice %s, tab %s, %d labels, %d pings",
		if state.Open then "open" else "closed",
		state.Center.X,
		state.Center.Y,
		state.Floors,
		state.Distance,
		state.FieldOfView,
		tostring(state.Selected),
		tostring(state.Choice),
		state.Tab,
		state.Labels,
		state.Pings
	) .. (if state.Ghosts > 0 then `, {state.Ghosts} ghost(s)` else "")
		.. (if state.Blinking ~= "" then `, blinking {state.Blinking}` else "") .. main .. detail
end

local function describeCamera(): string
	task.wait() -- let a frame apply what the command changed
	task.wait()
	local state = camera:State()
	local p = state.Position
	return string.format(
		"camera: %s, %s shoulder, yaw %.0f, pitch %.0f, zoom %.1f (wanted %.1f), %s%s, FOV %.0f, %s%s, %d faded, device %s%s at (%.1f, %.1f, %.1f)",
		if state.Stopped then "STOPPED (Roblox camera)" elseif state.Active then "on" else "suspended",
		state.Shoulder,
		state.Yaw,
		state.Pitch,
		state.Distance,
		state.Wanted,
		if state.Indoors then "indoors" else "outdoors",
		if state.Blocked then ", held in by a wall" else "",
		state.FieldOfView,
		if state.Aiming then "aiming" else "not aiming",
		if state.CursorFree then ", cursor free" else "",
		state.Fading,
		state.Device,
		if state.Suspended then ", suspended" else "",
		p.X,
		p.Y,
		p.Z
	)
end

-- Runs a command line; client-side commands answer here, the rest go to the server.
local function run(text: string): string?
	local name, args = parse(text)
	local handler = extra[name]
	if handler then
		return handler(args)
	end
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
	elseif name == "camera" then
		return describeCamera()
	elseif name == "camera.shoulder" then
		camera:SwapShoulder()
		return describeCamera()
	elseif name == "camera.aim" then
		camera:SetAiming(args[1] ~= false)
		return describeCamera()
	elseif name == "camera.look" then
		camera:SetLook(tonumber(args[1]) or 0, tonumber(args[2]) or 0)
		return describeCamera()
	elseif name == "camera.zoom" then
		camera:SetZoom(tonumber(args[1]) or 9)
		return describeCamera()
	elseif name == "camera.cursor" then
		devCursorFree = not devCursorFree
		camera:FreeCursor("DevTools", devCursorFree)
		return describeCamera()
	elseif name == "ui" then
		return describeUI()
	elseif name == "ui.sample" or name == "ui.list" or name == "ui.dock" then
		UISamples.Register(ui, replica)
		ui:Open(if name == "ui.sample" then "Sample" elseif name == "ui.list" then "SampleList" else "SampleDocked")
		return describeUI()
	elseif name == "ui.open" then
		UISamples.Register(ui, replica)
		ui:Open(tostring(args[1] or "Sample"))
		return describeUI()
	elseif name == "ui.close" then
		ui:Close()
		return describeUI()
	elseif name == "ui.tab" then
		ui:SelectTab(tostring(args[1] or ""))
		return describeUI()
	elseif name == "ui.main" then
		ui:PressMainAction()
		return describeUI()
	elseif name == "hud" then
		return describeHUD()
	elseif name == "hud.alert" then
		local kind = tostring(args[1] or "Warning")
		local words = {}
		for i = 2, #args do
			table.insert(words, tostring(args[i]))
		end
		hud:Alert(if kind == "Danger" or kind == "Info" then kind else "Warning", table.concat(words, " "))
		return describeHUD()
	elseif name == "hud.banner" then
		local words = {}
		for _, word in args do
			table.insert(words, tostring(word))
		end
		hud:Banner(table.concat(words, " "), "Warning", 6)
		return describeHUD()
	elseif name == "hud.slot" then
		hud:SelectSlot(tonumber(args[1]) or 1)
		return describeHUD()
	elseif name == "hud.touch" then
		hud:SetForceTouch(args[1] ~= false)
		return describeHUD()
	elseif name == "vote" then
		local state = voteView:State()
		return `vote telegram: {if state.Visible then "showing " .. tostring(state.Shown) else "hidden"}`
			.. (if state.Visible then `\n  {state.Proposal}\n  {state.Tally}\n  your vote: {tostring(state.Mine)}` else "")
			.. `\n  ghosts: {if state.Ghosts ~= "" then state.Ghosts else "none"}`
	elseif name == "cv" then
		return describeCommandView()
	elseif name == "cv.open" or name == "cv.close" then
		if commandView:IsOpen() ~= (name == "cv.open") then
			commandView:Toggle()
		end
		task.wait(0.5)
		return describeCommandView()
	elseif name == "cv.select" then
		commandView:Select(tonumber(args[1]), tonumber(args[2]))
		return describeCommandView()
	elseif name == "cv.ping" then
		local state = commandView:State()
		if not state.Selected then
			return "cv.ping: select a cell first (cv.select <floor> <column>)"
		end
		local floor, column = string.match(state.Selected, "^(%-?%d+),(%-?%d+)$")
		Remotes.FireServer("PingCell", tonumber(floor), tonumber(column))
		task.wait(0.5)
		return describeCommandView()
	elseif name == "cv.ghost" then
		-- the outline a vote will show for a proposed room (Prompt 8 calls ShowGhost)
		commandView:ShowGhost("dev", tonumber(args[1]) or 2, tonumber(args[2]) or 3, tonumber(args[3]) or 1,
			if args[4] ~= nil then tostring(args[4]) else "Proposed")
		return describeCommandView()
	elseif name == "cv.unghost" then
		commandView:HideGhost("dev")
		return describeCommandView()
	elseif name == "cv.blink" then
		commandView:Blink(tostring(args[1] or "R1"), args[2] ~= false)
		return describeCommandView()
	elseif name == "cv.overlay" then
		-- a sample reading for screenshots (green, amber, red by room number), until the systems
		-- that own each overlay register real ones
		local overlay = tostring(args[1] or "Power")
		if args[2] == false then
			commandView:SetOverlay(overlay, nil)
		else
			local lamps = { "Lamp_Green", "Lamp_Amber", "Lamp_Red" }
			commandView:SetOverlay(overlay, function(roomId: string): string?
				return lamps[(tonumber(string.match(roomId, "%d+")) or 0) % 3 + 1]
			end)
		end
		return describeCommandView()
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

-- Adds a command that runs on this client: a place's own controllers use it (the Run place's
-- CutsceneController: `cutscene.play`). The handler returns the answer.
function DevController:Register(name: string, handler: (args: { any }) -> string?)
	extra[name] = handler
end

function DevController:Init(registry)
	replica = registry.ReplicaController
	camera = registry.CameraController
	ui = registry.UIController
	hud = registry.HUDController
	registryInput = registry.InputController
	commandView = registry.CommandViewController
	voteView = registry.VoteController
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
