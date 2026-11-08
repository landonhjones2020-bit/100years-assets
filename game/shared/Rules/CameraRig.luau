--!strict
--[[
	Rules.CameraRig: the over-the-shoulder camera's geometry (bible Section 9), shared so the
	CameraController and the data tests agree. Pure functions, no instances.

	Angles are radians. Yaw turns about +Y; pitch tilts the view up (+) or down (-). The rig
	looks along its -Z, so at yaw 0 the camera looks toward -Z and its right is +X. `side` is
	1 for the right shoulder and -1 for the left (values between blend a swap).
]]

local Config = require(script.Parent.Parent.Config)
local Grid = require(script.Parent.Grid)

local CameraRig = {}

function CameraRig.Tuning(): { [string]: any }
	return Config.Get("Tuning", "Camera")
end

-- The camera's rotation for a yaw and a pitch.
function CameraRig.Rotation(yaw: number, pitch: number): CFrame
	return CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
end

function CameraRig.ClampPitch(pitch: number): number
	local t = CameraRig.Tuning()
	return math.clamp(pitch, math.rad(t.PitchMin), math.rad(t.PitchMax))
end

-- The point the camera orbits: beside the pivot (the character's head height), on the
-- camera's side, turned with the yaw only so looking up or down never swings it.
function CameraRig.Focus(pivot: Vector3, yaw: number, side: number, shoulder: number, raise: number): Vector3
	return pivot + CFrame.Angles(0, yaw, 0):VectorToWorldSpace(Vector3.new(side * shoulder, raise, 0))
end

-- Where the camera sits `distance` behind the focus.
function CameraRig.Position(focus: Vector3, yaw: number, pitch: number, distance: number): Vector3
	return focus - CameraRig.Rotation(yaw, pitch).LookVector * distance
end

-- A stick reading after a radial dead zone, with a squared response (0 to 1).
function CameraRig.Stick(input: Vector2, deadzone: number): Vector2
	local size = input.Magnitude
	if size <= deadzone or size == 0 then
		return Vector2.zero
	end
	local scaled = math.min((size - deadzone) / (1 - deadzone), 1)
	return input.Unit * scaled * scaled
end

-- The zoom range: the far end is capped indoors (in a bunker cell) so the camera stays in
-- the room.
function CameraRig.ZoomRange(indoors: boolean): (number, number)
	local t = CameraRig.Tuning()
	return t.Distance.Min, if indoors then math.min(t.Distance.Max, t.IndoorMax) else t.Distance.Max
end

-- The lowest and highest the camera may sit while its subject is in a bunker cell: above the
-- floor and under the ceiling panels. Nil outside the grid.
function CameraRig.CellHeights(pivot: Vector3): (number?, number?)
	local floor, column = Grid.CellAt(pivot)
	if not floor or not column then
		return nil, nil
	end
	local t = CameraRig.Tuning()
	local y = Grid.CellPosition(floor, column).Y
	return y + t.FloorMargin, y + Grid.Tuning().CellHeight - t.CeilingMargin
end

-- The farthest the camera can go back along its view from `focus` and stay between `low` and
-- `high` (it slides in along the view rather than leaving the aim point).
function CameraRig.HeightLimit(focus: Vector3, look: Vector3, low: number, high: number): number
	local limit = math.huge
	if look.Y < -1e-3 then -- looking down: the camera is above the focus
		limit = math.max(0, (high - focus.Y) / -look.Y)
	elseif look.Y > 1e-3 then -- looking up: the camera is below the focus
		limit = math.max(0, (focus.Y - low) / look.Y)
	end
	return limit
end

-- Eases `current` toward `target` at `rate` per second, frame-rate independent.
function CameraRig.Approach(current: number, target: number, rate: number, dt: number): number
	return target + (current - target) * math.exp(-rate * dt)
end

-- Moves `current` toward `target` by at most `step`.
function CameraRig.MoveToward(current: number, target: number, step: number): number
	if current < target then
		return math.min(current + step, target)
	end
	return math.max(current - step, target)
end

return table.freeze(CameraRig)
