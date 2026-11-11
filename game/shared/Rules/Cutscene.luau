--!strict
--[[
	Rules.Cutscene: the intro cutscene's arithmetic (bible Section 4), pure so the data tests can
	check it and so the whole cutscene is a function of one number: the seconds since it began.
	The client's CutsceneController asks these every frame, which is what lets a player who arrives
	late join it at the right moment, and a dev command stop it at any moment for a capture.

	The data is Config.CutscenePaths (the camera's keys, the set and the beats, made in Blender)
	and Config.Cutscenes (the words and the looks).

	* Elapsed, CanSkip: where the cutscene is from the run's clock, and who may skip (an account's
	  first run plays it in full; after that, after IntroSkipAfterSeconds).
	* ShotAt, CameraAt: the shot playing at t and the camera in that shot's own space, with smooth
	  interpolation between the keys (Catmull-Rom on the position, the shortest turn on the
	  rotation). Shots never blend into each other: a new shot is a cut.
	* PathLength, PathAt, Runner: the line the party and the founders sprint and where one of them
	  is at t.
	* Beat, Progress, Smooth and the named moves built on them: DoorShut, Bomb, WaveRadius,
	  WaveArrival, CloudAt, EyesOpen.
]]

export type Shot = {
	Name: string,
	From: number,
	To: number,
	Space: string,
	Rate: number,
	Handover: boolean,
	Text: string,
	Keys: { { number } },
}
export type Runner = { Delay: number, Side: number }
export type Path = {
	Seconds: number,
	Shots: { Shot },
	Set: { any },
	Ground: { any },
	RunPath: { { number } },
	Runners: { Runner },
	RunSpeed: number,
	Anchors: { [string]: { number } },
	Beats: { [string]: number },
	WaveReach: number,
	Cloud: { StemRadius: number, CapRadius: number, Top: number },
}
export type Cloud = { Rise: number, Top: number, CapRadius: number, StemRadius: number }

local Cutscene = {}

Cutscene.SPREAD_STUDS = 60 -- the pack starts scattered and has closed up after this far
Cutscene.SPREAD = 1.6 -- how much wider than their files they stand at the start

-- Seconds into a cutscene `seconds` long with `timeLeft` to go (RunState.TimeLeft in the Intro phase).
function Cutscene.Elapsed(seconds: number, timeLeft: number): number
	return math.clamp(seconds - timeLeft, 0, seconds)
end

-- Bible Section 4: "An account's first run plays it in full. After that, each player can skip it
-- after 2 seconds."
function Cutscene.CanSkip(firstRun: boolean, elapsed: number, skipAfter: number): boolean
	return not firstRun and elapsed >= skipAfter
end

function Cutscene.Smooth(x: number): number
	local c = math.clamp(x, 0, 1)
	return c * c * (3 - 2 * c)
end

function Cutscene.Beat(path: Path, name: string): number
	local at = path.Beats[name]
	assert(at ~= nil, `no beat named {name}`)
	return at
end

-- How far t is between two beats, from 0 to 1.
function Cutscene.Progress(path: Path, from: string, to: string, t: number): number
	local a, b = Cutscene.Beat(path, from), Cutscene.Beat(path, to)
	if b <= a then
		return if t >= b then 1 else 0
	end
	return math.clamp((t - a) / (b - a), 0, 1)
end

-- The camera ---------------------------------------------------------------------------------

-- The shot playing at t, and its place in the list. Past the end it is the last one.
function Cutscene.ShotAt(path: Path, t: number): (Shot, number)
	local shots = path.Shots
	for i, shot in shots do
		if t < shot.To then
			return shot, i
		end
	end
	return shots[#shots], #shots
end

local function keyCFrame(key: { number }): CFrame
	return CFrame.new(key[1], key[2], key[3], key[4], key[5], key[6], key[7])
end

local function catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, f: number): Vector3
	local f2, f3 = f * f, f * f * f
	return 0.5 * ((2 * p1) + (p2 - p0) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f2 + (3 * p1 - p0 - 3 * p2 + p3) * f3)
end

-- The camera at t in one shot: its CFrame in the shot's own space and its field of view.
function Cutscene.ShotCamera(shot: Shot, t: number): (CFrame, number)
	local keys = shot.Keys
	local count = #keys
	local u = math.clamp((t - shot.From) * shot.Rate, 0, count - 1)
	local i = math.min(math.floor(u), count - 2)
	local f = u - i
	local k0, k1, k2, k3 = keys[math.max(i, 1)], keys[i + 1], keys[i + 2], keys[math.min(i + 3, count)]
	local position = catmull(
		Vector3.new(k0[1], k0[2], k0[3]),
		Vector3.new(k1[1], k1[2], k1[3]),
		Vector3.new(k2[1], k2[2], k2[3]),
		Vector3.new(k3[1], k3[2], k3[3]),
		f
	)
	local rotation = keyCFrame(k1).Rotation:Lerp(keyCFrame(k2).Rotation, f)
	return CFrame.new(position) * rotation, k1[8] + (k2[8] - k1[8]) * f
end

-- The camera at t: its CFrame in the shot's space, its field of view, and the shot.
function Cutscene.CameraAt(path: Path, t: number): (CFrame, number, Shot)
	local shot = Cutscene.ShotAt(path, t)
	local cframe, fieldOfView = Cutscene.ShotCamera(shot, t)
	return cframe, fieldOfView, shot
end

-- The runners --------------------------------------------------------------------------------

local function point(p: { number }): Vector3
	return Vector3.new(p[1], p[2], p[3])
end

function Cutscene.PathLength(points: { { number } }): number
	local length = 0
	for i = 2, #points do
		length += (point(points[i]) - point(points[i - 1])).Magnitude
	end
	return length
end

-- The point `distance` studs along the line and the way the line heads there.
function Cutscene.PathAt(points: { { number } }, distance: number): (Vector3, Vector3)
	local left = math.max(distance, 0)
	local count = #points
	for i = 2, count do
		local a, b = point(points[i - 1]), point(points[i])
		local span = (b - a).Magnitude
		if left <= span or i == count then
			local direction = if span > 0 then (b - a) / span else Vector3.xAxis
			return a + direction * math.min(left, span), direction
		end
		left -= span
	end
	return point(points[count]), Vector3.xAxis
end

-- Runner `index` at t: where its feet are (set space), the way it heads, how far it has run, and
-- whether it has gone inside (the end of the line, in the hall behind the door).
function Cutscene.Runner(path: Path, index: number, t: number): (Vector3, Vector3, number, boolean)
	local runner = path.Runners[index]
	assert(runner, `no runner {index}`)
	local length = Cutscene.PathLength(path.RunPath)
	local run = math.clamp((t - Cutscene.Beat(path, "RunStart") - runner.Delay) * path.RunSpeed, 0, length)
	local position, direction = Cutscene.PathAt(path.RunPath, run)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	local heading = if flat.Magnitude > 0.001 then flat.Unit else Vector3.xAxis
	local right = heading:Cross(Vector3.yAxis)
	local spread = 1 + Cutscene.SPREAD * math.max(0, 1 - run / Cutscene.SPREAD_STUDS)
	return position + right * runner.Side * spread, direction, run, run >= length - 1
end

-- The named moves -----------------------------------------------------------------------------

-- The blast door: 0 standing open, 1 shut.
function Cutscene.DoorShut(path: Path, t: number): number
	return Cutscene.Smooth(Cutscene.Progress(path, "DoorFrom", "DoorTo", t))
end

-- The bomb in flight: where it is (set space) and the way it flies; nil before and after.
function Cutscene.Bomb(path: Path, t: number): (Vector3?, Vector3)
	local from, to = point(path.Anchors.BombFrom), point(path.Anchors.BombTo)
	local direction = (to - from).Unit
	if t < Cutscene.Beat(path, "BombFrom") or t >= Cutscene.Beat(path, "BombTo") then
		return nil, direction
	end
	return from:Lerp(to, Cutscene.Progress(path, "BombFrom", "BombTo", t)), direction
end

-- The shockwave's ring: how far from the blast it has spread; nil before it starts.
function Cutscene.WaveRadius(path: Path, t: number): number?
	if t < Cutscene.Beat(path, "WaveFrom") then
		return nil
	end
	return path.WaveReach * (t - Cutscene.Beat(path, "WaveFrom")) / (Cutscene.Beat(path, "WaveTo") - Cutscene.Beat(path, "WaveFrom"))
end

-- The second the ring reaches something `distance` studs from the blast.
function Cutscene.WaveArrival(path: Path, distance: number): number
	local from, to = Cutscene.Beat(path, "WaveFrom"), Cutscene.Beat(path, "WaveTo")
	return from + (to - from) * distance / path.WaveReach
end

-- The mushroom cloud: Rise 0 to 1, its top's height, its cap's and stem's radius.
function Cutscene.CloudAt(path: Path, t: number): Cloud
	local rise = Cutscene.Progress(path, "CloudFrom", "CloudTo", t)
	local eased = 1 - (1 - rise) * (1 - rise) -- fast at first, slowing as it climbs
	return {
		Rise = rise,
		Top = path.Cloud.Top * (0.22 + 0.78 * eased),
		CapRadius = path.Cloud.CapRadius * (0.34 + 0.66 * eased),
		StemRadius = path.Cloud.StemRadius * (0.75 + 0.35 * eased),
	}
end

-- The Source's eyes: 0 shut, 1 open.
function Cutscene.EyesOpen(path: Path, t: number): number
	return Cutscene.Smooth(Cutscene.Progress(path, "EyesFrom", "EyesTo", t))
end

return Cutscene
