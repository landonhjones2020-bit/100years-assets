--!strict
--[[
	Movement: the local character's walk speed, from everything that changes it, so no two
	controllers fight over Humanoid.WalkSpeed (aiming slows it, sprinting speeds it up and a
	downed player crawls; bible Section 9).

		Movement.Set(reason, multiplier?)  -- a multiplier on the base speed; nil removes it
		Movement.Override(reason, speed?)  -- a fixed speed that wins over the multipliers (the
		                                    -- slowest override wins); nil removes it
		Movement.Speed(): number
		Movement.Apply()                   -- after the character changes

	The base speed is StarterPlayer.CharacterWalkSpeed.
]]

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local Movement = {}

local multipliers: { [string]: number } = {}
local overrides: { [string]: number } = {}

function Movement.Speed(): number
	local slowest: number? = nil
	for _, speed in overrides do
		slowest = if slowest then math.min(slowest, speed) else speed
	end
	if slowest then
		return slowest
	end
	local speed = StarterPlayer.CharacterWalkSpeed
	for _, multiplier in multipliers do
		speed *= multiplier
	end
	return speed
end

function Movement.Apply()
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local speed = Movement.Speed()
		if math.abs(humanoid.WalkSpeed - speed) > 1e-3 then
			humanoid.WalkSpeed = speed
		end
	end
end

function Movement.Set(reason: string, multiplier: number?)
	if multipliers[reason] == multiplier then
		return
	end
	multipliers[reason] = multiplier
	Movement.Apply()
end

function Movement.Override(reason: string, speed: number?)
	if overrides[reason] == speed then
		return
	end
	overrides[reason] = speed
	Movement.Apply()
end

function Movement.Has(reason: string): boolean
	return multipliers[reason] ~= nil or overrides[reason] ~= nil
end

return Movement
