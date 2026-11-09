--!strict
--[[
	Combat: the rules of fighting (bible Section 9, and Section 23's server checks). Pure:
	CombatService and WeaponService run them on the server, CombatController on the client, so
	both sides agree on spread, timing and reach; DataTests hold them to the bible.

	* Items: Gun(itemId) and Melee(itemId) read Config.Items; Damage(itemId, rarity, heavy?)
	  scales by Config.ItemRarities (Standard is 1).
	* Guns: Interval(itemId) between shots (1 / FireRate). ShotSeed(salt, shot) and
	  Spread(seed, direction, itemId) give every pellet's direction, the same on both sides, so a
	  client can't choose its own spread. Reload(magazine, carried, itemId) moves whole shots
	  from the player's carried ammo into the magazine, AmmoPerShot each (Section 9).
	* Hits (Section 23): a claimed hit must sit near the shot's ray, within the gun's range, and
	  near where the target was over the last LagSeconds (PathDistance over its position
	  history). The server checks the line of sight itself.
	* Melee: InArc (reach and arc in front of the attacker); the light combo's next step
	  (ComboSteps hits, each within ComboWindowSeconds of the last); Swing(itemId, heavy) gives
	  the windup (MeleeWindupFraction of the swing, when the hit lands) and the length (a heavy
	  swing takes HeavySwingMultiplier times as long and costs HeavySwingStamina).
	* Cones (the flamethrower's flame, aim assist): InCone, AssistTarget.
	* Stamina(current, max, dt, sprinting, sinceSpent): sprinting drains it; it grows back after
	  StaminaRegenDelay without spending.
	* Nearest(from, places): the closest place (the respawn Medbay).
]]

local Config = require(script.Parent.Parent.Config)

export type Sample = { T: number, P: Vector3 }
export type Place = { Id: string, Position: Vector3 }

local Combat = {}

Combat.UNARMED = "Unarmed"

local function tuning(): { [string]: any }
	return Config.Get("Tuning", "Combat")
end
Combat.Tuning = tuning

-- Items ------------------------------------------------------------------------------------

function Combat.Gun(itemId: string?): { [string]: any }?
	local item = Config.Find("Items", itemId)
	return if item and item.Kind == "Gun" then item.Gun else nil
end

-- A melee weapon's numbers; "Unarmed" is a punch, for kits with no melee weapon.
function Combat.Melee(itemId: string?): { [string]: any }?
	if itemId == Combat.UNARMED then
		return tuning().Unarmed
	end
	local item = Config.Find("Items", itemId)
	return if item and item.Kind == "Melee" then item.Melee else nil
end

function Combat.RarityMultiplier(rarity: string?): number
	local found = Config.Find("ItemRarities", rarity or "Standard")
	return if found then found.DamageMultiplier else 1
end

-- Damage of one hit (one pellet, one flame tick, one swing).
function Combat.Damage(itemId: string, rarity: string?, heavy: boolean?): number
	local gun = Combat.Gun(itemId)
	if gun then
		return gun.Damage * Combat.RarityMultiplier(rarity)
	end
	local melee = Combat.Melee(itemId)
	if melee then
		return (if heavy then melee.HeavyDamage else melee.Damage) * Combat.RarityMultiplier(rarity)
	end
	return 0
end

-- Guns -------------------------------------------------------------------------------------

function Combat.Interval(itemId: string): number
	local gun = Combat.Gun(itemId)
	return if gun and gun.FireRate > 0 then 1 / gun.FireRate else math.huge
end

function Combat.Pellets(itemId: string): number
	local gun = Combat.Gun(itemId)
	return if gun then gun.Pellets or 1 else 0
end

-- A shot's seed from the player's salt (given by the server when the gun is handed out) and the
-- shot's number, so the spread is fixed before the client fires.
function Combat.ShotSeed(salt: number, shot: number): number
	local mixed = bit32.bxor(salt % 2 ^ 31, (shot * 2654435761) % 2 ^ 32)
	return mixed % 2 ^ 31
end

-- A direction turned by `degrees` around an axis at `roll` radians about it.
local function deflect(direction: Vector3, degrees: number, roll: number): Vector3
	if degrees <= 0 then
		return direction
	end
	local d = direction.Unit
	local helper = if math.abs(d.Y) < 0.95 then Vector3.yAxis else Vector3.xAxis
	local right = d:Cross(helper).Unit
	local up = right:Cross(d).Unit
	local axis = right * math.cos(roll) + up * math.sin(roll)
	local angle = math.rad(degrees)
	-- Rodrigues: rotate d about the axis (perpendicular to d)
	return (d * math.cos(angle) + axis:Cross(d) * math.sin(angle)).Unit
end

-- Each pellet's direction: spread evenly over a disc of SpreadDegrees around the aim.
function Combat.Spread(seed: number, direction: Vector3, itemId: string): { Vector3 }
	local gun = Combat.Gun(itemId)
	if not gun then
		return {}
	end
	local rng = Random.new(seed)
	local out = {}
	for _ = 1, gun.Pellets or 1 do
		local degrees = gun.SpreadDegrees * math.sqrt(rng:NextNumber())
		local roll = rng:NextNumber() * 2 * math.pi
		table.insert(out, deflect(direction, degrees, roll))
	end
	return out
end

-- Whole shots loaded from carried ammo: the new magazine and what is left carried.
function Combat.Reload(magazine: number, carried: number, itemId: string): (number, number)
	local gun = Combat.Gun(itemId)
	if not gun then
		return magazine, carried
	end
	local per = math.max(gun.AmmoPerShot, 1)
	local room = math.max(gun.Magazine - magazine, 0)
	local shots = math.min(room, math.floor(carried / per))
	return magazine + shots, carried - shots * per
end

-- Hits -------------------------------------------------------------------------------------

-- How far a point is from a ray (perpendicular), and how far along the ray it is.
function Combat.RayDistance(origin: Vector3, direction: Vector3, point: Vector3): (number, number)
	local d = direction.Unit
	local offset = point - origin
	local along = offset:Dot(d)
	local closest = origin + d * math.max(along, 0)
	return (point - closest).Magnitude, along
end

-- Where a combatant was at time `t`, from its history (oldest first).
function Combat.PositionAt(history: { Sample }, t: number): Vector3?
	local count = #history
	if count == 0 then
		return nil
	end
	if t <= history[1].T then
		return history[1].P
	end
	if t >= history[count].T then
		return history[count].P
	end
	for i = 2, count do
		local b = history[i]
		if b.T >= t then
			local a = history[i - 1]
			local span = b.T - a.T
			local alpha = if span > 0 then (t - a.T) / span else 1
			return a.P:Lerp(b.P, alpha)
		end
	end
	return history[count].P
end

-- The nearest a point came to a combatant between `from` and `to` (its path over that time).
function Combat.PathDistance(history: { Sample }, from: number, to: number, point: Vector3): number
	local best = math.huge
	local start = Combat.PositionAt(history, from)
	if start then
		best = (start - point).Magnitude
	end
	local finish = Combat.PositionAt(history, to)
	if finish then
		best = math.min(best, (finish - point).Magnitude)
	end
	for _, sample in history do
		if sample.T >= from and sample.T <= to then
			best = math.min(best, (sample.P - point).Magnitude)
		end
	end
	return best
end

-- Is a claimed hit believable? `reach` is how far the target's body goes from its centre.
-- Returns false and why when it isn't.
function Combat.CheckHit(
	origin: Vector3,
	direction: Vector3,
	point: Vector3,
	range: number,
	history: { Sample },
	from: number,
	to: number,
	reach: number
): (boolean, string?)
	local t = tuning()
	local off, along = Combat.RayDistance(origin, direction, point)
	if along < -t.RayTolerance then
		return false, "behind the shot"
	elseif along > range + t.RayTolerance then
		return false, "out of range"
	elseif off > t.RayTolerance then
		return false, "off the shot's line"
	end
	if #history > 0 and Combat.PathDistance(history, from, to, point) > reach + t.HitTolerance then
		return false, "not where the target was"
	end
	return true, nil
end

-- Cones and arcs ---------------------------------------------------------------------------

-- Is a point (with a body of `radius`) in a cone of `halfDegrees` around the direction, within
-- `range`?
function Combat.InCone(origin: Vector3, direction: Vector3, point: Vector3, range: number, halfDegrees: number, radius: number?): boolean
	local offset = point - origin
	local distance = offset.Magnitude
	local r = radius or 0
	if distance - r > range then
		return false
	end
	if distance <= r or distance < 1e-6 then
		return true
	end
	local cos = offset.Unit:Dot(direction.Unit)
	local angle = math.deg(math.acos(math.clamp(cos, -1, 1)))
	local widen = math.deg(math.atan2(r, distance)) -- the body's own width
	return angle <= halfDegrees + widen
end

-- Is a point (with a body of `radius`) inside a swing: within reach of the attacker and inside
-- the arc in front of it (judged flat, and no higher or lower than the reach)?
function Combat.InArc(attacker: CFrame, point: Vector3, reach: number, arcDegrees: number, radius: number?): boolean
	local r = radius or 0
	local offset = point - attacker.Position
	if math.abs(offset.Y) > reach + r then
		return false
	end
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local distance = flat.Magnitude
	if distance - r > reach then
		return false
	end
	if distance <= r or distance < 1e-6 then
		return true
	end
	local look = Vector3.new(attacker.LookVector.X, 0, attacker.LookVector.Z)
	if look.Magnitude < 1e-6 then
		return true
	end
	local cos = flat.Unit:Dot(look.Unit)
	local angle = math.deg(math.acos(math.clamp(cos, -1, 1)))
	local widen = math.deg(math.atan2(r, distance))
	return angle <= arcDegrees / 2 + widen
end

-- The target aim assist pulls toward: the one closest to the aim within `maxDegrees`.
-- Returns its index and how far off the aim it is (degrees), or nil.
function Combat.AssistTarget(origin: Vector3, look: Vector3, points: { Vector3 }, maxDegrees: number, range: number): (number?, number)
	local best, bestAngle = nil, math.huge
	for i, point in points do
		local offset = point - origin
		local distance = offset.Magnitude
		if distance > 1e-3 and distance <= range then
			local angle = math.deg(math.acos(math.clamp(offset.Unit:Dot(look.Unit), -1, 1)))
			if angle <= maxDegrees and angle < bestAngle then
				best, bestAngle = i, angle
			end
		end
	end
	return best, bestAngle
end

-- Melee --------------------------------------------------------------------------------------

-- The light combo's next step: the next hit if the last one landed within the window,
-- otherwise the first again.
function Combat.NextCombo(lastStep: number, sinceLast: number): number
	local t = tuning()
	if lastStep >= 1 and lastStep < t.ComboSteps and sinceLast <= t.ComboWindowSeconds then
		return lastStep + 1
	end
	return 1
end

-- A swing's windup (when its hit lands) and its whole length, in seconds.
function Combat.Swing(itemId: string, heavy: boolean?): (number, number)
	local melee = Combat.Melee(itemId)
	if not melee then
		return 0, 0
	end
	local t = tuning()
	local length = melee.SwingSeconds * (if heavy then t.HeavySwingMultiplier else 1)
	return length * t.MeleeWindupFraction, length
end

-- Stamina ------------------------------------------------------------------------------------

-- Stamina after `dt` seconds: sprinting drains SprintStaminaPerSecond; otherwise it grows back
-- at StaminaRegenPerSecond once StaminaRegenDelay has passed since it was last spent.
function Combat.Stamina(current: number, max: number, dt: number, sprinting: boolean, sinceSpent: number): number
	local player = Config.Get("Tuning", "Player")
	if sprinting then
		return math.max(current - player.SprintStaminaPerSecond * dt, 0)
	end
	local t = tuning()
	if sinceSpent < t.StaminaRegenDelay then
		return current
	end
	return math.min(current + player.StaminaRegenPerSecond * dt, max)
end

-- Respawn ------------------------------------------------------------------------------------

function Combat.Nearest(from: Vector3, places: { Place }): Place?
	local best, bestDistance = nil, math.huge
	for _, place in places do
		local distance = (place.Position - from).Magnitude
		if distance < bestDistance or (distance == bestDistance and best and place.Id < best.Id) then
			best, bestDistance = place, distance
		end
	end
	return best
end

return Combat
