--!strict
--[[
	Fade: see-through world parts on this client only, shared by the camera (walls and
	furniture between the camera and the character) and the Command View (front walls).

	Each source asks for an amount per part (0 opaque, 1 hidden); a part shows the largest ask,
	eased over `seconds`, through BasePart.LocalTransparencyModifier, which is local to this
	client and never replicates. Parts that leave the game drop out by themselves.

		Fade.Set(part, "Camera", 0.8)
		Fade.Clear(part, "Camera")
		Fade.ClearSource("Camera")
]]

local RunService = game:GetService("RunService")

local Fade = {}

local DEFAULT_SECONDS = 0.12

local asks: { [BasePart]: { [string]: number } } = {}
local shown: { [BasePart]: number } = {}
local seconds = DEFAULT_SECONDS
local connection: RBXScriptConnection? = nil

local function target(part: BasePart): number
	local best = 0
	for _, amount in asks[part] or {} do
		best = math.max(best, amount)
	end
	return best
end

local function step(dt: number)
	local rate = if seconds > 0 then dt / seconds else 1
	local busy = false
	for part, current in shown do
		if part.Parent == nil then
			shown[part] = nil
			asks[part] = nil
			continue
		end
		local goal = target(part)
		local nextValue = if current < goal then math.min(current + rate, goal) else math.max(current - rate, goal)
		if nextValue ~= current then
			part.LocalTransparencyModifier = nextValue
		end
		if nextValue <= 0 and goal <= 0 then
			shown[part] = nil
			asks[part] = nil
		else
			shown[part] = nextValue
			busy = true
		end
	end
	if not busy and connection then
		connection:Disconnect()
		connection = nil
	end
end

local function wake()
	if not connection then
		connection = RunService.RenderStepped:Connect(step)
	end
end

-- How long a fade in or out takes (the camera sets this from Tuning.Camera.FadeSeconds).
function Fade.SetSeconds(value: number)
	seconds = math.max(0, value)
end

function Fade.Set(part: BasePart, source: string, amount: number)
	local list = asks[part]
	if not list then
		list = {}
		asks[part] = list
	end
	list[source] = math.clamp(amount, 0, 1)
	if shown[part] == nil then
		shown[part] = part.LocalTransparencyModifier
	end
	wake()
end

function Fade.Clear(part: BasePart, source: string)
	local list = asks[part]
	if list then
		list[source] = nil
	end
	if shown[part] ~= nil then
		wake()
	end
end

-- Drops every ask a source made (when the camera stops, or the Command View closes).
function Fade.ClearSource(source: string)
	for part, list in asks do
		if list[source] ~= nil then
			list[source] = nil
			wake()
		end
	end
end

-- The parts a source is fading now (DevTools).
function Fade.Count(source: string?): number
	local count = 0
	for _, list in asks do
		if source == nil or list[source] ~= nil then
			count += 1
		end
	end
	return count
end

return Fade
