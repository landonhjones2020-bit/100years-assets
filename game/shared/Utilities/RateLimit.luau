--!strict
--[[
	RateLimit: a token bucket per key (usually a Player).

		local limiter = RateLimit.new(5, 2)   -- bursts of 5, then 2 per second
		if not limiter:Take(player) then return end
		...
		limiter:Forget(player)                -- on PlayerRemoving

	`clock` can be replaced for tests; it defaults to os.clock.
]]

export type Limiter = {
	Take: (self: Limiter, key: any, cost: number?) -> boolean,
	Forget: (self: Limiter, key: any) -> (),
	Reset: (self: Limiter) -> (),
}

type Bucket = { tokens: number, at: number }

local LimiterClass = {}
LimiterClass.__index = LimiterClass

function LimiterClass.Take(self: any, key: any, cost: number?): boolean
	local price = cost or 1
	local now = self._clock()
	local bucket: Bucket? = self._buckets[key]
	if not bucket then
		local fresh: Bucket = { tokens = self._burst, at = now }
		self._buckets[key] = fresh
		bucket = fresh
	end
	local b = bucket :: Bucket
	b.tokens = math.min(self._burst, b.tokens + (now - b.at) * self._rate)
	b.at = now
	if b.tokens >= price then
		b.tokens -= price
		return true
	end
	return false
end

function LimiterClass.Forget(self: any, key: any)
	self._buckets[key] = nil
end

function LimiterClass.Reset(self: any)
	table.clear(self._buckets)
end

local RateLimit = {}

function RateLimit.new(burst: number, perSecond: number, clock: (() -> number)?): Limiter
	assert(burst > 0 and perSecond >= 0, "RateLimit.new: burst must be positive and perSecond not negative")
	return setmetatable({
		_burst = burst,
		_rate = perSecond,
		_clock = clock or os.clock,
		_buckets = {},
	}, LimiterClass) :: any
end

return table.freeze(RateLimit)
