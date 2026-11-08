--!strict
--[[
	Trove: collects things to clean up and cleans them all at once, newest first.

		local trove = Trove.new()
		trove:Connect(part.Touched, onTouched)
		trove:Add(effect)                 -- an Instance: destroyed
		trove:Add(function() ... end)     -- a function: called
		trove:Clean()

	Accepts RBXScriptConnections, Instances, functions, threads (cancelled), and tables with a
	Destroy or Disconnect method (Signals, connections, other troves).
]]

export type Trove = {
	Add: <T>(self: Trove, item: T) -> T,
	Connect: (self: Trove, signal: any, handler: (...any) -> ()) -> any,
	Clean: (self: Trove) -> (),
	Destroy: (self: Trove) -> (),
}

local function cleanUp(item: any)
	local kind = typeof(item)
	if kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		item:Destroy()
	elseif kind == "function" then
		item()
	elseif kind == "thread" then
		pcall(task.cancel, item)
	elseif kind == "table" then
		if type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.Disconnect) == "function" then
			item:Disconnect()
		end
	end
end

local TroveClass = {}
TroveClass.__index = TroveClass

function TroveClass.Add(self: any, item: any): any
	local kind = typeof(item)
	if kind ~= "RBXScriptConnection" and kind ~= "Instance" and kind ~= "function" and kind ~= "thread" then
		if kind ~= "table" or (type(item.Destroy) ~= "function" and type(item.Disconnect) ~= "function") then
			error(`Trove can't clean up a {kind}`, 2)
		end
	end
	table.insert(self._items, item)
	return item
end

function TroveClass.Connect(self: any, signal: any, handler: (...any) -> ()): any
	return TroveClass.Add(self, signal:Connect(handler))
end

function TroveClass.Clean(self: any)
	local items = self._items
	self._items = {}
	for index = #items, 1, -1 do
		cleanUp(items[index])
	end
end

TroveClass.Destroy = TroveClass.Clean

local Trove = {}

function Trove.new(): Trove
	return setmetatable({ _items = {} }, TroveClass) :: any
end

return table.freeze(Trove)
