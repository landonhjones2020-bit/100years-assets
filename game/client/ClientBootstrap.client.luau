--!strict
--[[
	ClientBootstrap: the only LocalScript (bible Section 23). It loads every controller in
	the Controllers folder beside it, runs every Init in dependency order and then every
	Start, waits for the server to be ready and tells it the client is ready (ClientReady),
	which makes the server send the replication snapshot.

	Never add another LocalScript: write a controller (see Documentation.ARCHITECTURE).
]]

local began = os.clock()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Utilities = Shared:WaitForChild("Utilities")
local Loader = require(Utilities:WaitForChild("Loader"))
local Log = require(Utilities:WaitForChild("Log"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local SERVER_WAIT_SECONDS = 30

local log = Log.new("ClientBootstrap")

local controllers = Loader.Collect(script.Parent:WaitForChild("Controllers"), "Controller")
local report = Loader.Run(controllers, log)

local waited = 0
while ReplicatedStorage:GetAttribute("ServerReady") ~= true and waited < SERVER_WAIT_SECONDS do
	waited += task.wait(0.1)
end
if ReplicatedStorage:GetAttribute("ServerReady") ~= true then
	log:Warn("the server isn't ready after %d s; continuing", SERVER_WAIT_SECONDS)
end

Remotes.FireServer("ClientReady")
log:Info(
	"client ready: %d controllers (%s) in %.1f ms",
	#report.Order,
	table.concat(report.Order, ", "),
	(os.clock() - began) * 1000
)
