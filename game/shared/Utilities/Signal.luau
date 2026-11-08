--!strict
--[[
	Signal: a typed event without an Instance.

		local Changed: Signal.Signal<string, number> = Signal.new()
		local connection = Changed:Connect(function(key, value) ... end)
		Changed:Fire("Year", 12)
		connection:Disconnect()

	Handlers run on a recycled thread, so a handler may yield without holding up the others
	or the caller. Handlers connected during a Fire wait for the next Fire. The order in which
	handlers run is not guaranteed.
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Wait: (self: Signal<T...>) -> T...,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

type Node = {
	Connected: boolean,
	_signal: any,
	_handler: (...any) -> (),
	_next: Node?,
}

-- A thread kept for running handlers; it is handed out again once a handler returns
-- without yielding, so firing a signal rarely creates a thread.
local freeRunner: thread? = nil

local function runHandler(handler: (...any) -> (), ...: any)
	local runner = freeRunner
	freeRunner = nil
	handler(...)
	freeRunner = runner
end

local function runnerLoop(...: any)
	runHandler(...)
	while true do
		runHandler(coroutine.yield())
	end
end

local ConnectionClass = {}
ConnectionClass.__index = ConnectionClass

function ConnectionClass.Disconnect(self: Node)
	if not self.Connected then
		return
	end
	self.Connected = false
	local signal = self._signal
	if signal._head == self then
		signal._head = self._next
	else
		local previous = signal._head
		while previous and previous._next ~= self do
			previous = previous._next
		end
		if previous then
			previous._next = self._next
		end
	end
end

local SignalClass = {}
SignalClass.__index = SignalClass

function SignalClass.Connect(self: any, handler: (...any) -> ()): Connection
	local node: Node = setmetatable({
		Connected = true,
		_signal = self,
		_handler = handler,
		_next = self._head,
	}, ConnectionClass) :: any
	self._head = node
	return node :: any
end

function SignalClass.Once(self: any, handler: (...any) -> ()): Connection
	local connection: Connection
	connection = SignalClass.Connect(self, function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function SignalClass.Fire(self: any, ...: any)
	local node: Node? = self._head
	while node do
		if node.Connected then
			if not freeRunner then
				freeRunner = coroutine.create(runnerLoop)
			end
			task.spawn(freeRunner :: thread, node._handler, ...)
		end
		node = node._next
	end
end

function SignalClass.Wait(self: any): ...any
	local thread = coroutine.running()
	SignalClass.Once(self, function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function SignalClass.DisconnectAll(self: any)
	local node: Node? = self._head
	while node do
		node.Connected = false
		node = node._next
	end
	self._head = nil
end

SignalClass.Destroy = SignalClass.DisconnectAll

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	return setmetatable({ _head = nil }, SignalClass) :: any
end

return table.freeze(Signal)
