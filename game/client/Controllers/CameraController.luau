--!strict
--[[
	CameraController: the over-the-shoulder camera (bible Sections 9 and 26: "wall fade and zoom
	caps built and tested in prompt 5, before anything depends on them").

	* Over the right shoulder by default; SwapShoulder (V, the right stick click, the HUD's
	  Shoulder button) moves it to the other side in ShoulderSwapSeconds.
	* Aim (right mouse, the left trigger, the HUD's Aim button; Run place only) narrows the
	  field of view from 70 to 50 (Tuning.Player.AimFieldOfView), brings the camera in to
	  AimDistance, slows walking to AimWalkSpeed (Lib.Movement) and turns the character to where
	  the camera looks. Face(reason, on) turns it the same way without aiming (firing from the
	  hip, a swing; Prompt 11), and Nudge(yaw, pitch) turns the camera a little (recoil, aim
	  assist). Shake(seconds, degrees) shakes it (Prompt 14: a Tremor).
	* Zoom (the wheel, a pinch) between Distance.Min and Distance.Max, capped at IndoorMax while
	  the character is in a bunker cell.
	* Zoom caps: a spherecast from the shoulder keeps the camera out of walls, slabs and rock: it
	  pulls in at once and eases back out. In a bunker cell the camera also stays between the
	  floor and the ceiling panels, sliding in along its view (Shafts are open overhead).
	* Wall fade: front walls (FrontWall tag) and furniture (CameraFade tag) never stop the
	  camera; when they stand between the camera and the character, or touch the camera, they
	  fade (Lib.Fade, this client only). So the camera can stand outside a room's open front.
	  Characters and anything tagged CameraIgnore are passed through.
	* The local character fades as the camera comes within CharacterFadeDistance of the head.
	* PC: the mouse is locked to the centre with the cursor hidden and the Reticle shown; any
	  controller frees the cursor with FreeCursor(reason, true) (menus, the Command View).
	* Other views take the camera with Suspend(reason) and give it back with Resume(reason).
	* Fallback: if the update errors ErrorsBeforeFallback times in a row, the controller stops
	  and hands the camera to Roblox's default camera, which the places set to Invisicam
	  (StarterPlayer.DevCameraOcclusionMode).
]]

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CameraRig = require(Shared.Rules.CameraRig)
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Grid = require(Shared.Rules.Grid)
local Log = require(Shared.Utilities.Log)
local Signal = require(Shared.Utilities.Signal)
local Fade = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Fade"))
local Movement = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Movement"))

local log = Log.new("CameraController")

local FRONT_WALL_TAG = "FrontWall"
local FADE_TAG = "CameraFade"
local IGNORE_TAG = "CameraIgnore"
local FADE_SOURCE = "Camera"
local RENDER_NAME = "100Y_Camera"
local RENDER_PRIORITY = Enum.RenderPriority.Camera.Value + 1
local MAX_FADE_HITS = 4
local PIVOT_LAG = 2 -- the smoothed pivot never trails the head by more than this (studs)

local CameraController = {
	Name = "CameraController",
	Dependencies = { "InputController", "ReplicaController" },
	ShoulderChanged = Signal.new() :: Signal.Signal<number>,
	AimChanged = Signal.new() :: Signal.Signal<boolean>,
}

local input: any = nil
local replica: any = nil
local t: { [string]: any } = {}
local aimFieldOfView = 50
local inRun = false

local yaw = 0
local pitch = 0
local side = 1 -- 1: right shoulder, -1: left
local sideBlend = 1
local aiming = false
local aimBlend = 0
local wanted = 9 -- the zoom the player chose
local distance = 9 -- the camera's distance this frame
local pivotY: number? = nil
local sensitivity = 1
local suspended: { [string]: boolean } = {}
local cursorFree: { [string]: boolean } = {}
local errors = 0
local stopped = false
local wasActive = false
local faded: { [BasePart]: boolean } = {}
local characterFade = 0
local fadedCharacter: Model? = nil
local walkHumanoid: Humanoid? = nil
local slowed = false
local turned = false
local facers: { [string]: boolean } = {}
local reticle: { Gui: ScreenGui, Hip: GuiObject?, Aim: GuiObject? }? = nil
local lastFrame = { Distance = 0, Blocked = false, Indoors = false, Fading = 0, Position = Vector3.zero }

local blockParams = RaycastParams.new()
blockParams.FilterType = Enum.RaycastFilterType.Exclude
blockParams.IgnoreWater = true
local fadeParams = RaycastParams.new()
fadeParams.FilterType = Enum.RaycastFilterType.Include
fadeParams.IgnoreWater = true
local nearParams = OverlapParams.new()
nearParams.FilterType = Enum.RaycastFilterType.Include
local filtersDirty = true

-- Filters ------------------------------------------------------------------------------------

-- The camera passes through characters, CameraIgnore, CameraFade and front walls; it fades
-- the last two.
local function rebuildFilters()
	filtersDirty = false
	local passThrough: { Instance } = {}
	local fadeable: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(passThrough, player.Character)
		end
	end
	for _, item in CollectionService:GetTagged(IGNORE_TAG) do
		table.insert(passThrough, item)
	end
	for _, tag in { FADE_TAG, FRONT_WALL_TAG } do
		for _, item in CollectionService:GetTagged(tag) do
			table.insert(passThrough, item)
			table.insert(fadeable, item)
		end
	end
	blockParams.FilterDescendantsInstances = passThrough
	fadeParams.FilterDescendantsInstances = fadeable
	nearParams.FilterDescendantsInstances = fadeable
end

local function markDirty()
	filtersDirty = true
end

-- Fading -------------------------------------------------------------------------------------

-- A front wall fades as a whole piece; anything else fades alone.
local function fadeGroup(part: BasePart, into: { [BasePart]: number }, amount: number)
	if CollectionService:HasTag(part, FRONT_WALL_TAG) then
		local parent = part.Parent
		if parent and parent:IsA("Model") then
			for _, sibling in parent:GetChildren() do
				if sibling:IsA("BasePart") and CollectionService:HasTag(sibling, FRONT_WALL_TAG) then
					into[sibling] = math.max(into[sibling] or 0, t.FrontWallTransparency)
				end
			end
		end
		into[part] = math.max(into[part] or 0, t.FrontWallTransparency)
		return
	end
	into[part] = math.max(into[part] or 0, amount)
end

-- Fadeable parts on the lines from the camera to points on the character.
local function occluders(from: Vector3, targets: { Vector3 }, into: { [BasePart]: number })
	for _, target in targets do
		local origin = from
		for _ = 1, MAX_FADE_HITS do
			local delta = target - origin
			if delta.Magnitude < 0.05 then
				break
			end
			local hit = workspace:Raycast(origin, delta, fadeParams)
			if not hit then
				break
			end
			local part = hit.Instance
			if part:IsA("BasePart") then
				fadeGroup(part, into, t.FadeTransparency)
			end
			origin = hit.Position + delta.Unit * 0.05
		end
	end
end

local function applyFades(now: { [BasePart]: number })
	for part in faded do
		if now[part] == nil then
			Fade.Clear(part, FADE_SOURCE)
			faded[part] = nil
		end
	end
	for part, amount in now do
		Fade.Set(part, FADE_SOURCE, amount)
		faded[part] = true
	end
end

local function clearFades()
	Fade.ClearSource(FADE_SOURCE)
	table.clear(faded)
end

local function fadeCharacter(character: Model?, amount: number)
	if character ~= fadedCharacter then
		characterFade = -1
		fadedCharacter = character
	end
	if not character or math.abs(amount - characterFade) < 0.01 then
		return
	end
	characterFade = amount
	for _, item in character:GetDescendants() do
		if item:IsA("BasePart") or item:IsA("Decal") then
			local target: any = item
			target.LocalTransparencyModifier = amount
		end
	end
end

-- Mouse, reticle, walking --------------------------------------------------------------------

local function active(): boolean
	return not stopped and next(suspended) == nil
end

-- Shake (Prompt 14: a Tremor): a small turn that fades over the seconds given.
local shakeUntil, shakeSeconds, shakeDegrees = 0, 0, 0

local function shakeOffset(): CFrame
	local left = shakeUntil - os.clock()
	if left <= 0 then
		return CFrame.identity
	end
	local k = shakeDegrees * (left / math.max(shakeSeconds, 0.01))
	local t = os.clock() * 31
	return CFrame.Angles(math.rad(math.noise(t, 0.5) * k * 2), math.rad(math.noise(t, 7.5) * k * 2), 0)
end

local function updateMouse()
	local locked = active() and next(cursorFree) == nil and input:Device() ~= "Touch" and not GuiService.MenuIsOpen
	local behavior = if locked then Enum.MouseBehavior.LockCenter else Enum.MouseBehavior.Default
	if UserInputService.MouseBehavior ~= behavior then
		UserInputService.MouseBehavior = behavior
	end
	if UserInputService.MouseIconEnabled == locked then
		UserInputService.MouseIconEnabled = not locked
	end
end

local function findReticle()
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local gui = playerGui and playerGui:FindFirstChild("Reticle")
	if gui and gui:IsA("ScreenGui") then
		local hip = gui:FindFirstChild("Hip", true)
		local aim = gui:FindFirstChild("Aim", true)
		reticle = {
			Gui = gui,
			Hip = if hip and hip:IsA("GuiObject") then hip else nil,
			Aim = if aim and aim:IsA("GuiObject") then aim else nil,
		}
	else
		reticle = nil
	end
end

local function updateReticle()
	local current = reticle
	if not current or current.Gui.Parent == nil then
		findReticle()
		current = reticle
	end
	if not current then
		return
	end
	local show = active() and next(cursorFree) == nil
	if current.Gui.Enabled ~= show then
		current.Gui.Enabled = show
	end
	local aimed = aimBlend >= 0.5
	if current.Hip and current.Hip.Visible ~= (inRun and not aimed) then
		current.Hip.Visible = inRun and not aimed
	end
	if current.Aim and current.Aim.Visible ~= (inRun and aimed) then
		current.Aim.Visible = inRun and aimed
	end
end

-- Aiming slows walking (Lib.Movement); aiming and Face() turn the character with the camera.
local function updateWalking(humanoid: Humanoid, root: BasePart)
	if humanoid ~= walkHumanoid then
		walkHumanoid = humanoid
		slowed = false
		turned = false
		Movement.Apply()
	end
	if aiming ~= slowed then
		slowed = aiming
		Movement.Set("Aim", if aiming then t.AimWalkSpeed else nil)
	end
	local facing = aiming or next(facers) ~= nil
	if facing ~= turned then
		turned = facing
		humanoid.AutoRotate = not facing
	end
	if facing then
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
	end
end

local function releaseWalking()
	local humanoid = walkHumanoid
	if humanoid and turned and humanoid.Parent then
		humanoid.AutoRotate = true
	end
	Movement.Set("Aim", nil)
	slowed = false
	turned = false
end

-- Is the cell at this point a Shaft (open overhead for the stair)?
local function inShaft(point: Vector3): boolean
	local floor, column = Grid.CellAt(point)
	if not floor or not column then
		return false
	end
	local cell = replica:Get("Cells", Grid.Key(floor, column))
	local roomId = if type(cell) == "table" then cell.Room else nil
	local room = if type(roomId) == "string" then replica:Get("Rooms", roomId) else nil
	return type(room) == "table" and room.Type == "Shaft"
end

-- The frame ----------------------------------------------------------------------------------

local function step(dt: number)
	updateMouse()
	updateReticle()
	if not active() then
		if wasActive then
			wasActive = false
			clearFades()
			releaseWalking()
			fadeCharacter(fadedCharacter, 0)
		end
		input:TakeLook(dt)
		input:TakeZoom()
		return
	end
	wasActive = true
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not camera or not character or not humanoid or not root then
		input:TakeLook(dt)
		input:TakeZoom()
		return
	end
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	if filtersDirty then
		rebuildFilters()
	end

	-- Look, shoulder and aim
	local turn = input:TakeLook(dt) * sensitivity * (1 + (t.AimSensitivity - 1) * aimBlend)
	yaw -= math.rad(turn.X)
	pitch = CameraRig.ClampPitch(pitch - math.rad(turn.Y))
	sideBlend = CameraRig.MoveToward(sideBlend, side, dt * 2 / math.max(t.ShoulderSwapSeconds, 1e-3))
	aimBlend = CameraRig.MoveToward(aimBlend, if aiming then 1 else 0, dt / math.max(t.AimBlendSeconds, 1e-3))

	-- The pivot: head height, its height smoothed a little (stairs)
	local head = root.Position + Vector3.new(0, t.PivotHeight, 0)
	local smoothY = if pivotY then CameraRig.Approach(pivotY, head.Y, t.PivotFollowPerSecond, dt) else head.Y
	pivotY = math.clamp(smoothY, head.Y - PIVOT_LAG, head.Y + PIVOT_LAG)
	local pivot = Vector3.new(head.X, pivotY :: number, head.Z)

	-- Indoors: the bunker cell the character is in
	local low: number?, high: number? = nil, nil
	if inRun then
		low, high = CameraRig.CellHeights(pivot)
	end
	local indoors = low ~= nil
	if indoors and inShaft(pivot) then
		high = nil -- the Shaft is open overhead (the stair goes up through it)
	end

	-- Zoom
	local nearest, farthest = CameraRig.ZoomRange(indoors)
	local zoomInput = input:TakeZoom()
	if zoomInput ~= 0 then
		wanted = math.clamp(math.min(wanted, farthest) + zoomInput, nearest, if indoors then farthest else t.Distance.Max)
	end
	local zoomGoal = math.clamp(wanted, nearest, farthest)
	local goal = zoomGoal + (math.min(t.AimDistance, zoomGoal) - zoomGoal) * aimBlend

	-- The focus beside the head, kept out of a wall the character stands against
	local shoulder = t.ShoulderOffset * (1 + (t.AimShoulder - 1) * aimBlend)
	local focus = CameraRig.Focus(pivot, yaw, sideBlend, shoulder, t.ShoulderRaise)
	local toFocus = focus - pivot
	if toFocus.Magnitude > 1e-3 then
		local hit = workspace:Spherecast(pivot, t.CollisionRadius * 0.75, toFocus, blockParams)
		if hit then
			focus = pivot + toFocus.Unit * math.max(0, hit.Distance - t.WallMargin)
		end
	end

	-- How far back the camera can go: walls and rock, then the cell's floor and ceiling
	local rotation = CameraRig.Rotation(yaw, pitch)
	local look = rotation.LookVector
	local allowed = goal
	local blocked = false
	local hit = workspace:Spherecast(focus, t.CollisionRadius, -look * goal, blockParams)
	if hit then
		allowed = math.max(t.NearestDistance, hit.Distance - t.WallMargin)
		blocked = true
	end
	if indoors then
		local limit = CameraRig.HeightLimit(focus, look, low :: number, high or math.huge)
		if limit < allowed then
			allowed = math.max(t.NearestDistance, limit)
			blocked = true
		end
	end
	if allowed < distance then
		distance = allowed -- pull in at once
	else
		distance = CameraRig.Approach(distance, allowed, t.EaseOutPerSecond, dt)
	end

	local position = focus - look * distance
	camera.CFrame = CFrame.new(position) * rotation * shakeOffset()
	camera.Focus = CFrame.new(focus)
	camera.FieldOfView = t.FieldOfView + (aimFieldOfView - t.FieldOfView) * aimBlend

	-- Wall fade: between the camera and the character, and touching the camera
	local fades: { [BasePart]: number } = {}
	occluders(position, { head, root.Position, focus }, fades)
	for _, part in workspace:GetPartBoundsInRadius(position, t.NearFadeRadius, nearParams) do
		fadeGroup(part, fades, 1)
	end
	applyFades(fades)

	-- The character fades when the camera is at its head
	local gap = (position - head).Magnitude
	local closeness = math.clamp((t.CharacterFadeDistance - gap) / (t.CharacterFadeDistance * 0.5), 0, 1)
	fadeCharacter(character, closeness)

	updateWalking(humanoid, root)

	lastFrame.Distance = distance
	lastFrame.Blocked = blocked
	lastFrame.Indoors = indoors
	lastFrame.Fading = Fade.Count(FADE_SOURCE)
	lastFrame.Position = position
end

local function onRender(dt: number)
	if stopped then
		return
	end
	local ok, err = pcall(step, dt)
	if ok then
		errors = 0
		return
	end
	errors += 1
	log:Warn("camera update failed (%d): %s", errors, tostring(err))
	if errors >= t.ErrorsBeforeFallback then
		stopped = true
		clearFades()
		releaseWalking()
		local camera = workspace.CurrentCamera
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = t.FieldOfView
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		log:Error("the over-the-shoulder camera stopped; Roblox's camera (Invisicam) takes over")
	end
end

-- API ----------------------------------------------------------------------------------------

function CameraController:SwapShoulder()
	side = -side
	CameraController.ShoulderChanged:Fire(side)
end

function CameraController:SetShoulder(value: number)
	local wantedSide = if value < 0 then -1 else 1
	if wantedSide ~= side then
		CameraController:SwapShoulder()
	end
end

function CameraController:SetAiming(on: boolean)
	local value = on and inRun and active() and next(cursorFree) == nil
	if value == aiming then
		return
	end
	aiming = value
	CameraController.AimChanged:Fire(value)
end

function CameraController:IsAiming(): boolean
	return aiming
end

-- Turn the character to where the camera looks while `reason` holds (firing from the hip, a
-- melee swing), without aiming's zoom.
function CameraController:Face(reason: string, on: boolean)
	facers[reason] = if on then true else nil
end

-- Turn the camera by a few degrees (recoil kicks it up; aim assist pulls it toward a target).
-- Shake the over-the-shoulder camera for `seconds`, up to `degrees` (Prompt 14: Tremors).
function CameraController:Shake(seconds: number, degrees: number)
	shakeUntil = os.clock() + seconds
	shakeSeconds = seconds
	shakeDegrees = degrees
end

function CameraController:Nudge(yawDegrees: number, pitchDegrees: number)
	yaw += math.rad(yawDegrees)
	pitch = CameraRig.ClampPitch(pitch + math.rad(pitchDegrees))
end

-- Where the camera looks, as a ray from the camera (what the reticle covers).
function CameraController:AimRay(): Ray?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local size = camera.ViewportSize
	return camera:ViewportPointToRay(size.X / 2, size.Y / 2)
end

-- Point the camera (degrees): yaw 0 looks toward -Z, pitch below 0 looks down.
function CameraController:SetLook(yawDegrees: number, pitchDegrees: number)
	yaw = math.rad(yawDegrees)
	pitch = CameraRig.ClampPitch(math.rad(pitchDegrees))
end

function CameraController:SetZoom(studs: number)
	wanted = math.clamp(studs, t.Distance.Min, t.Distance.Max)
end

-- A sensitivity multiplier from the player's settings (Settings screen, later).
function CameraController:SetSensitivity(value: number)
	sensitivity = math.clamp(value, 0.1, 4)
end

-- Another view takes the camera (the Command View, a cutscene) until Resume(reason).
function CameraController:Suspend(reason: string)
	suspended[reason] = true
end

function CameraController:Resume(reason: string)
	suspended[reason] = nil
end

-- A menu frees the mouse cursor while it is open.
function CameraController:FreeCursor(reason: string, on: boolean)
	cursorFree[reason] = if on then true else nil
end

function CameraController:State(): { [string]: any }
	return {
		Active = active(),
		Stopped = stopped,
		Yaw = math.deg(yaw) % 360,
		Pitch = math.deg(pitch),
		Shoulder = if side > 0 then "right" else "left",
		Aiming = aiming,
		Wanted = wanted,
		Distance = lastFrame.Distance,
		Blocked = lastFrame.Blocked,
		Indoors = lastFrame.Indoors,
		Fading = lastFrame.Fading,
		Position = lastFrame.Position,
		FieldOfView = if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView else 0,
		Device = input:Device(),
		Suspended = next(suspended) ~= nil,
		CursorFree = next(cursorFree) ~= nil,
	}
end

-- Lifecycle ----------------------------------------------------------------------------------

function CameraController:Init(registry)
	input = registry.InputController
	replica = registry.ReplicaController
	t = CameraRig.Tuning()
	aimFieldOfView = Config.Get("Tuning", "Player").AimFieldOfView[2]
	inRun = Constants.PlaceKind() == "Run"
	pitch = math.rad(t.StartPitch)
	wanted = t.Distance.Default
	distance = wanted
	Fade.SetSeconds(t.FadeSeconds)
end

function CameraController:Start()
	input:On("SwapShoulder", function()
		CameraController:SwapShoulder()
	end)
	input:On("Aim", function()
		CameraController:SetAiming(true)
	end, function()
		CameraController:SetAiming(false)
	end)

	for _, tag in { FADE_TAG, FRONT_WALL_TAG, IGNORE_TAG } do
		CollectionService:GetInstanceAddedSignal(tag):Connect(markDirty)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(markDirty)
	end
	local function watch(player: Player)
		player.CharacterAdded:Connect(markDirty)
		player.CharacterRemoving:Connect(markDirty)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(markDirty)

	-- A new character looks the way it spawned facing
	local function faceSpawn(character: Model)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root and root:IsA("BasePart") then
			local lookVector = root.CFrame.LookVector
			yaw = math.atan2(-lookVector.X, -lookVector.Z)
			pitch = math.rad(t.StartPitch)
			pivotY = nil
			distance = math.min(wanted, select(2, CameraRig.ZoomRange(inRun)))
		end
		aiming = false
		aimBlend = 0
	end
	Players.LocalPlayer.CharacterAdded:Connect(faceSpawn)
	if Players.LocalPlayer.Character then
		task.spawn(faceSpawn, Players.LocalPlayer.Character)
	end

	RunService:BindToRenderStep(RENDER_NAME, RENDER_PRIORITY, onRender)
	log:Debug("over-the-shoulder camera on (%s)", if inRun then "Run" else "Lobby")
end

return CameraController
