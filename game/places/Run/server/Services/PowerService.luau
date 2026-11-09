--!strict
--[[
	PowerService: the power balance and dark rooms (bible Sections 6 and 23). Run place only.

	Power is a live balance, not a stock. The Reactor Core and Generators make power from the
	residents working in them (Landon, Nov 8, 2026); every room draws Power[level] for each of
	its cells. When the draw passes what is made, rooms go dark farthest first: steps along the
	room graph from the nearest Reactor Core or Generator, dug cells counting (Rules.Economy
	.Balance has the rule). The balance is worked out again whenever the bunker, a crew or an
	output modifier changes, and every second in case.

	Dark rooms stop working (EconomyService.SetPowered), their lights drop to a dim red emergency
	glow and their Neon fittings (light strips, pendants) go dull; the room model carries a Dark
	attribute. Their morale loss (Prompt 10) and
	doubled monster spawns (Prompt 12) ask IsDark. The team gets an alert when rooms go dark
	and when the power comes back.

	Blackouts (Prompt 13, Section 10: a floor or the whole grid goes dark): DisasterService sets
	the units a blackout darkens (SetBlackout). They are dark on top of the balance, whatever
	power is made: lights, fittings, work and IsDark all follow, but the power alerts and
	DarkRooms count only rooms dark for want of power.

	Replication: RunState PowerMade, PowerUsed, PowerNeeded and DarkRooms; the Power collection,
	room id -> { Draw, Made, Dark, Steps, Blackout } for every room that draws or makes power.

	API:
		PowerService:IsDark(roomId): boolean            -- for want of power or in a blackout
		PowerService:IsBlackout(unit): boolean
		PowerService:SetBlackout(units?)                -- the units a blackout darkens; nil: none
		PowerService:Balance(): Economy.Balance
		PowerService:Refresh()
		PowerService.DarkChanged: Signal<{ string }, { string }>  -- went dark, lit again
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Economy = require(Shared.Rules.Economy)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local RunState = require(Shared.RunState)
local Signal = require(Shared.Utilities.Signal)
local BunkerKit = require(ServerScriptService.Lib.BunkerKit)

local log = Log.new("PowerService")
local set = RunState.Writer("PowerService")

local PowerService = {
	Name = "PowerService",
	Dependencies = { "BunkerGrid", "EconomyService", "SessionService", "ReplicationService", "DevService" },
	DarkChanged = Signal.new() :: Signal.Signal<{ string }, { string }>,
}

-- A dark room's lights: a dim red emergency glow (art direction, not a rule).
local EMERGENCY = Color3.fromRGB(255, 72, 48)
local DARK_BRIGHTNESS = 0.18 -- of the light's own brightness
local DARK_FITTING = Color3.fromRGB(64, 30, 26) -- a Neon fitting with the power off
local REFRESH_SECONDS = 1

local grid: any = nil
local economy: any = nil
local session: any = nil
local powerCollection: any = nil
local balance: Economy.Balance = { Made = 0, Needed = 0, Used = 0, Dark = {}, Draw = {}, MadeBy = {}, Steps = {} }
local published: { [string]: string } = {} -- room id -> what was last sent (to send only changes)
local pending = false
local blackout: { [string]: boolean } = {} -- units dark in a blackout (Prompt 13)
local darkNow: { [string]: boolean } = {} -- the balance's dark rooms plus the blackout

local function isDarkNow(unit: string): boolean
	return darkNow[unit] == true
end

local function announce(kind: string, text: string)
	Remotes.FireClients("Alert", session:ReadyPlayers(), kind, text)
end

local function roomName(roomType: string): string
	return Config.Get("Rooms", roomType).Name
end

local function round1(value: number): number
	return math.floor(value * 10 + 0.5) / 10
end

-- Lights ---------------------------------------------------------------------------------------

local function setLight(light: Instance, isDark: boolean)
	if not light:IsA("Light") then
		return
	end
	if (light:GetAttribute("PowerDark") == true) == isDark then
		return
	end
	if light:GetAttribute("LitBrightness") == nil then
		light:SetAttribute("LitBrightness", light.Brightness)
		light:SetAttribute("LitColor", light.Color)
	end
	local brightness = light:GetAttribute("LitBrightness")
	local color = light:GetAttribute("LitColor")
	if isDark then
		light.Brightness = (if type(brightness) == "number" then brightness else light.Brightness) * DARK_BRIGHTNESS
		light.Color = EMERGENCY
	else
		if type(brightness) == "number" then
			light.Brightness = brightness
		end
		if typeof(color) == "Color3" then
			light.Color = color
		end
	end
	light:SetAttribute("PowerDark", isDark)
end

-- A dark room's Neon fittings go dull (SmoothPlastic, dark red); lit again, they come back.
local function setFittings(model: Model, isDark: boolean)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and (item.Material == Enum.Material.Neon or item:GetAttribute("LitMaterial") ~= nil) then
			if isDark then
				if item:GetAttribute("LitMaterial") == nil then
					item:SetAttribute("LitMaterial", item.Material.Name)
					item:SetAttribute("LitColor", item.Color)
				end
				item.Material = Enum.Material.SmoothPlastic
				item.Color = DARK_FITTING
			else
				local material, color = item:GetAttribute("LitMaterial"), item:GetAttribute("LitColor")
				if type(material) == "string" then
					item.Material = (Enum.Material :: any)[material]
				end
				if typeof(color) == "Color3" then
					item.Color = color
				end
				item:SetAttribute("LitMaterial", nil)
				item:SetAttribute("LitColor", nil)
			end
		end
	end
end

local function applyLights()
	for _, light in CollectionService:GetTagged(BunkerKit.ROOM_LIGHT_TAG) do
		local unit = light:GetAttribute("Unit")
		if type(unit) == "string" then
			setLight(light, isDarkNow(unit))
		end
	end
	for _, room in grid:Rooms() do
		local model = grid:RoomModel(room.Id)
		if model then
			local isDark = isDarkNow(room.Id)
			if (model:GetAttribute("Dark") == true) ~= isDark then
				model:SetAttribute("Dark", isDark)
				setFittings(model, isDark)
			end
		end
	end
end

-- The balance ------------------------------------------------------------------------------------

local function publish()
	set("PowerMade", round1(balance.Made))
	set("PowerUsed", round1(balance.Used))
	set("PowerNeeded", round1(balance.Needed))
	local darkCount = 0
	for _ in balance.Dark do
		darkCount += 1
	end
	set("DarkRooms", darkCount)
	local seen: { [string]: boolean } = {}
	for _, room in grid:Rooms() do
		local draw, made = balance.Draw[room.Id], balance.MadeBy[room.Id]
		if draw or made then
			seen[room.Id] = true
			local entry = {
				Draw = draw or 0,
				Made = round1(made or 0),
				Dark = isDarkNow(room.Id),
				Steps = balance.Steps[room.Id] or -1, -- -1: nothing reaches it
				Blackout = blackout[room.Id] == true,
			}
			local key = `{entry.Draw}|{entry.Made}|{entry.Dark}|{entry.Steps}|{entry.Blackout}`
			if published[room.Id] ~= key then
				published[room.Id] = key
				powerCollection:Set(room.Id, entry)
			end
		end
	end
	for id in table.clone(published) do
		if not seen[id] then
			published[id] = nil
			powerCollection:Remove(id)
		end
	end
end

function PowerService:Refresh()
	pending = false
	local before = balance.Dark
	balance = Economy.Balance(grid:Bunker(), function(roomId: string): Economy.Crew?
		return economy:Crew(roomId)
	end, function(roomType: string): number
		return economy:OutputMultiplier(roomType)
	end)
	local wentDark, litAgain = {}, {}
	for id in balance.Dark do
		if not before[id] then
			table.insert(wentDark, id)
		end
	end
	for id in before do
		if not balance.Dark[id] and grid:Room(id) then
			table.insert(litAgain, id)
		end
	end
	local wasDark = darkNow
	darkNow = table.clone(balance.Dark)
	for unit in blackout do
		darkNow[unit] = true
	end
	economy:SetPowered(darkNow)
	publish()
	applyLights()
	local blackoutChanged = false
	for unit in darkNow do
		if not wasDark[unit] then
			blackoutChanged = true
		end
	end
	for unit in wasDark do
		if not darkNow[unit] then
			blackoutChanged = true
		end
	end
	if #wentDark > 0 or #litAgain > 0 then
		table.sort(wentDark)
		table.sort(litAgain)
		log:Info("power %.1f made, %.1f needed: dark %s", balance.Made, balance.Needed,
			if next(balance.Dark) then table.concat(wentDark, ", ") else "none")
		if #wentDark > 0 then
			local room = grid:Room(wentDark[1])
			local what = if #wentDark == 1 and room then `THE {string.upper(roomName(room.Type))} WENT DARK`
				else `{#wentDark} ROOMS WENT DARK`
			announce("Warning", `NOT ENOUGH POWER: {what}`)
		elseif not next(balance.Dark) then
			announce("Info", "POWER RESTORED: EVERY ROOM IS LIT")
		end
		PowerService.DarkChanged:Fire(wentDark, litAgain)
	elseif blackoutChanged then
		PowerService.DarkChanged:Fire({}, {})
	end
end

-- Many changes in one frame (a merge, a crew shuffle) make one refresh.
local function soon()
	if pending then
		return
	end
	pending = true
	task.defer(function()
		if pending then
			PowerService:Refresh()
		end
	end)
end

function PowerService:IsDark(roomId: string): boolean
	return darkNow[roomId] == true
end

function PowerService:IsBlackout(unit: string): boolean
	return blackout[unit] == true
end

-- The units (room ids, dug nodes) a blackout darkens; nil or {} ends it (DisasterService).
function PowerService:SetBlackout(units: { [string]: boolean }?)
	blackout = if units then table.clone(units) else {}
	PowerService:Refresh()
end

function PowerService:Balance(): Economy.Balance
	return balance
end

-- DevTools ---------------------------------------------------------------------------------------

local function describe(): string
	local lines = { string.format("power: %.1f made, %.1f used, %.1f needed", balance.Made, balance.Used, balance.Needed) }
	local rooms = grid:Rooms()
	table.sort(rooms, function(a, b)
		return Economy.Order(a.Id) < Economy.Order(b.Id)
	end)
	for _, room in rooms do
		local draw, made = balance.Draw[room.Id], balance.MadeBy[room.Id]
		if draw or made then
			table.insert(lines, string.format("%s %s L%d: %s, steps %s%s%s", room.Id, room.Type, room.Level,
				if made then string.format("makes %.1f", made) else `draws {draw}`,
				tostring(balance.Steps[room.Id] or "none"), if balance.Dark[room.Id] then ", DARK" else "",
				if blackout[room.Id] then ", BLACKOUT" else ""))
		end
	end
	return table.concat(lines, "\n")
end

function PowerService:Init(registry)
	grid = registry.BunkerGrid
	economy = registry.EconomyService
	session = registry.SessionService
	powerCollection = registry.ReplicationService:Collection("Power")
	registry.DevService:Register("power", {
		Description = "The power balance: what each room makes or draws, its steps and whether it is dark.",
		Usage = "power",
		Run = function(): string?
			PowerService:Refresh()
			return describe()
		end,
	})
end

function PowerService:Start()
	grid.RoomChanged:Connect(soon)
	grid.Changed:Connect(soon) -- digging changes the graph's steps
	economy.CrewChanged:Connect(soon)
	PowerService:Refresh()
	local since = 0
	RunService.Heartbeat:Connect(function(dt: number)
		since += dt
		if since >= REFRESH_SECONDS then
			since = 0
			PowerService:Refresh()
		end
	end)
end

return PowerService
