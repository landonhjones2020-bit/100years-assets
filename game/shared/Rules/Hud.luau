--!strict
--[[
	Rules.Hud: the HUD's arithmetic (bible Section 18), pure so the data tests can check it.

	* Clock(seconds): "m:ss", rounded up, so "0:01" shows until the very end.
	* YearDigits(year): the three tiles of the year flip counter.
	* DialPosition(...): where the cycle dial's pointer sits across the face. The day fills the
	  first DaySeconds / CycleSeconds of the scale and the Surge the rest, as the dial is printed.
	  A Surge with no timer (a boss Surge) parks at the start of its part.
	* NeedleRotation(fraction): a gauge needle's rotation (the sweep runs -135 to +135 degrees).
	* Numeral(n): Roman numerals for the eras.
	* MapWindow(...): which cells the side-view mini-map shows around the player.
]]

local Hud = {}

-- The printed face of the cycle dial spans this much of the sprite's width.
Hud.DialFace = table.freeze({ From = 0.023, To = 0.977 })

function Hud.Clock(seconds: number?): string
	if seconds == nil then
		return "--:--"
	end
	local whole = math.max(0, math.ceil(seconds - 1e-6))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

function Hud.YearDigits(year: number): { string }
	local text = string.format("%03d", math.clamp(math.floor(year), 0, 999))
	return { string.sub(text, 1, 1), string.sub(text, 2, 2), string.sub(text, 3, 3) }
end

-- phase: "Day", "Surge" or nil (before the first day); timeLeft in seconds (nil if unknown);
-- open: the phase has no timer.
function Hud.DialPosition(
	phase: string?,
	phaseLength: number?,
	timeLeft: number?,
	open: boolean?,
	daySeconds: number,
	surgeSeconds: number
): number
	local split = daySeconds / (daySeconds + surgeSeconds)
	local done = 0
	if phaseLength and phaseLength > 0 and timeLeft then
		done = math.clamp(1 - timeLeft / phaseLength, 0, 1)
	end
	local value = 0
	if phase == "Day" then
		value = done * split
	elseif phase == "Surge" then
		value = if open then split else split + done * (1 - split)
	end
	return Hud.DialFace.From + (Hud.DialFace.To - Hud.DialFace.From) * value
end

function Hud.NeedleRotation(fraction: number): number
	return -135 + 270 * math.clamp(fraction, 0, 1)
end

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }

function Hud.Numeral(n: number): string
	return ROMAN[n] or tostring(n)
end

-- The window of `columns` columns centred on the player's column and `rows` floors starting
-- one above the player's floor, kept on the grid. Returns the first column and first floor.
function Hud.MapWindow(
	floor: number,
	column: number,
	grid: { ColumnMin: number, ColumnMax: number, FloorMin: number, FloorMax: number },
	columns: number,
	rows: number
): (number, number)
	local half = (columns - 1) // 2
	local firstColumn = math.clamp(column - half, grid.ColumnMin, math.max(grid.ColumnMin, grid.ColumnMax - columns + 1))
	local firstFloor = math.clamp(floor - 1, grid.FloorMin, math.max(grid.FloorMin, grid.FloorMax - rows + 1))
	return firstColumn, firstFloor
end

return Hud
