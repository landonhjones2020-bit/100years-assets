--!strict
--[[
	Bootstrap: the only server Script (bible Section 23). It creates the remotes, loads every
	service in ServerScriptService.Services, runs every Init in dependency order and then
	every Start, and marks the server ready.

	Never add another Script: write a service (see Documentation.ARCHITECTURE).
]]

local began = os.clock()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildInfo = require(Shared:WaitForChild("BuildInfo")) :: any
local Constants = require(Shared:WaitForChild("Constants"))
local Loader = require(Shared.Utilities:WaitForChild("Loader"))
local Log = require(Shared.Utilities:WaitForChild("Log"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local log = Log.new("Bootstrap")
local place = Constants.PlaceKind()

Remotes.Setup()

local services = Loader.Collect(ServerScriptService:WaitForChild("Services"), "Service")
local report = Loader.Run(services, log)

local broken = {}
for name in report.Failed do
	table.insert(broken, name)
end
for name in report.Skipped do
	table.insert(broken, name)
end
table.sort(broken)

ReplicatedStorage:SetAttribute("PlaceKind", place)
ReplicatedStorage:SetAttribute("Build", BuildInfo.Label)
ReplicatedStorage:SetAttribute("ServerBroken", if #broken > 0 then table.concat(broken, ",") else nil)
ReplicatedStorage:SetAttribute("ServerReady", true)

if #broken > 0 then
	log:Error("%s server started with broken services: %s", place, table.concat(broken, ", "))
end
log:Info(
	"%s server ready: %d services (%s) in %.1f ms, build %s",
	place,
	#report.Order,
	table.concat(report.Order, ", "),
	(os.clock() - began) * 1000,
	BuildInfo.Label
)
