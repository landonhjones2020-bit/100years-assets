--!strict
--[[
	Log: tagged output with levels and a ring buffer of recent lines.

		local log = Log.new("BunkerGrid")
		log:Info("built %s at %d,%d", roomId, x, y)
		log:Warn("...")      -- shows as a warning
		log:Error("...")     -- a warning marked ERROR; never throws

	Lines look like `[100Y S BunkerGrid] built Kitchen at 2,3` (S = server, C = client).
	The level starts at Debug in Studio and Info in live servers; DevTools can change it
	(`/dev log Debug`). Log.Recent() returns the last lines for `/dev logs`.
]]

local RunService = game:GetService("RunService")

export type Level = "Debug" | "Info" | "Warn" | "Error"

export type Logger = {
	Tag: string,
	Debug: (self: Logger, format: string, ...any) -> (),
	Info: (self: Logger, format: string, ...any) -> (),
	Warn: (self: Logger, format: string, ...any) -> (),
	Error: (self: Logger, format: string, ...any) -> (),
}

local RANK: { [Level]: number } = { Debug = 1, Info = 2, Warn = 3, Error = 4 }
local RECENT_MAX = 200
local SIDE = if RunService:IsServer() then "S" else "C"

local threshold: Level = if RunService:IsStudio() then "Debug" else "Info"
local recent: { string } = {}
local recentNext = 1

local function remember(line: string)
	recent[recentNext] = line
	recentNext = recentNext % RECENT_MAX + 1
end

local function emit(level: Level, tag: string, format: string, ...: any)
	if RANK[level] < RANK[threshold] then
		return
	end
	local ok, message = pcall(string.format, format, ...)
	if not ok then
		message = `{format} (bad log format: {message})`
	end
	local line = if level == "Error"
		then `[100Y {SIDE} {tag}] ERROR {message}`
		else `[100Y {SIDE} {tag}] {message}`
	remember(`{string.format("%.2f", os.clock())} {level} {line}`)
	if level == "Warn" or level == "Error" then
		warn(line)
	else
		print(line)
	end
end

local LoggerClass = {}
LoggerClass.__index = LoggerClass

function LoggerClass.Debug(self: Logger, format: string, ...: any)
	emit("Debug", self.Tag, format, ...)
end

function LoggerClass.Info(self: Logger, format: string, ...: any)
	emit("Info", self.Tag, format, ...)
end

function LoggerClass.Warn(self: Logger, format: string, ...: any)
	emit("Warn", self.Tag, format, ...)
end

function LoggerClass.Error(self: Logger, format: string, ...: any)
	emit("Error", self.Tag, format, ...)
end

local Log = {}

function Log.new(tag: string): Logger
	return setmetatable({ Tag = tag }, LoggerClass) :: any
end

function Log.SetLevel(level: Level)
	assert(RANK[level], "Log.SetLevel: level must be Debug, Info, Warn or Error")
	threshold = level
end

function Log.GetLevel(): Level
	return threshold
end

function Log.IsLevel(value: any): boolean
	return type(value) == "string" and RANK[value :: Level] ~= nil
end

-- The last `count` lines (default 30), oldest first.
function Log.Recent(count: number?): { string }
	local wanted = math.clamp(count or 30, 1, RECENT_MAX)
	local lines = {}
	for offset = 0, RECENT_MAX - 1 do
		local line = recent[(recentNext - 1 + offset) % RECENT_MAX + 1]
		if line then
			table.insert(lines, line)
		end
	end
	return table.move(lines, math.max(1, #lines - wanted + 1), #lines, 1, {})
end

return table.freeze(Log)
