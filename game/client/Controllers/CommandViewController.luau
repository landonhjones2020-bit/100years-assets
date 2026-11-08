--!strict
--[[
	CommandViewController: the Command View (bible Section 7), a flat side view of the whole
	bunker that any player opens with one button, anywhere, while the character stays in the
	world and can be hit. Run place only.

	* Open and close: the CommandView action (Tab, the console's View button, the HUD button).
	  It is The Frame in docked mode (Section 18): top bar, tab rail and detail panel, with the
	  live bunker in zone C (the page Cabinet.Pages.CommandView, built in Studio).
	* Camera: far away with a narrow field of view, looking at the bunker's front, so it reads
	  nearly flat. It opens centred on the character with a 0.3 s move and moves back over the
	  shoulder on close. Front walls fade out (Lib.Fade, source "CommandView") and the lighting
	  lifts a little so the rock reads. The character's controls are off while it's open.
	* Moving the view: drag (mouse or one finger), WASD or the arrow keys, the left stick; zoom
	  with the wheel, a pinch or the right stick.
	* Picking: click or tap a cell; on a gamepad, A picks the cell under the centre mark. The
	  detail panel shows a room (level, cells, condition, power, output; actions: upgrade, merge,
	  tear down), an open cell (the build menu: every room type with its cost, or why it's
	  locked) or rock (whether it can be dug, its band and ore).
	* Proposals go through handlers the votes set (SetHandler: "Build", "Upgrade", "Merge",
	  "TearDown"; Prompt 8). Without a handler the main action stays greyed out.
	* Overlays (tabs Power, Morale, Threat, Production) colour the room labels' lamps from
	  providers later systems register (SetOverlay); without one they read "no readings yet".
	* Ping: the footer's Ping button or the Ping key (G, the D-pad's up) pings the selected cell
	  (the PingCell remote); every player sees it here and on the mini-map.
	* Taking damage while the view is open flashes the screen edge red.

	API for later prompts: SetHandler(action, fn(choice)), SetOverlay(name, provider),
	ShowGhost(id, floor, column, span, label) and HideGhost(id) for open votes, Blink(key, on)
	for alerts, Select(floor, column), IsOpen(), State().
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bunker = require(Shared.Rules.Bunker)
local CV = require(Shared.Rules.CommandView)
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Grid = require(Shared.Rules.Grid)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local RunState = require(Shared.RunState)
local Signal = require(Shared.Utilities.Signal)
local UIContract = require(Shared.UIContract)
local Lib = script.Parent.Parent:WaitForChild("Lib")
local Fade = require(Lib:WaitForChild("Fade"))
local KitRuntime = require(Lib:WaitForChild("KitRuntime"))

local log = Log.new("CommandViewController")

export type Choice = {
	Action: string, -- "Build", "Upgrade", "Merge", "TearDown"
	Floor: number,
	Column: number,
	RoomType: string?, -- Build
	RoomId: string?, -- Upgrade, Merge, TearDown
	Other: string?, -- Merge: the room it joins
	Level: number?, -- Upgrade: the new level
}
export type Overlay = (roomId: string, room: any) -> (string?, string?) -- lamp sprite, legend text

local SCREEN = "CommandView"
local FADE_SOURCE = "CommandView"
local FRONT_WALL_TAG = "FrontWall"
local RENDER_NAME = "100Y_CommandView"
local RENDER_PRIORITY = Enum.RenderPriority.Camera.Value - 1 -- before CameraController drains zoom input
local PING_ACTION = "100Y_CVPing"
local PICK_ACTION = "100Y_CVPick"
local HOLD_ACTION = "100Y_CVHold"
local TABS = {
	{ Id = "Build", Label = "Build", Icon = "Icon_Grid" },
	{ Id = "Power", Label = "Power", Icon = "Icon_Power" },
	{ Id = "Morale", Label = "Morale", Icon = "Icon_Check" },
	{ Id = "Threat", Label = "Threat", Icon = "Icon_Shield" },
	{ Id = "Production", Label = "Production", Icon = "Icon_Scrap" },
}
local OVERLAY_TEXT: { [string]: string } = { -- bible Section 7's overlays
	Power = "Rooms by power: lit or dark.",
	Morale = "Rooms by their workers' morale.",
	Threat = "Likely breach points.",
	Production = "Rooms by what they make each cycle.",
}
local PAN_KEYS: { [Enum.KeyCode]: Vector2 } = {
	[Enum.KeyCode.W] = Vector2.new(0, 1),
	[Enum.KeyCode.Up] = Vector2.new(0, 1),
	[Enum.KeyCode.S] = Vector2.new(0, -1),
	[Enum.KeyCode.Down] = Vector2.new(0, -1),
	[Enum.KeyCode.A] = Vector2.new(-1, 0),
	[Enum.KeyCode.Left] = Vector2.new(-1, 0),
	[Enum.KeyCode.D] = Vector2.new(1, 0),
	[Enum.KeyCode.Right] = Vector2.new(1, 0),
}
local CREAM = Color3.fromHex("#F2E6C9")
local RUST = Color3.fromHex("#B5412B")

local CommandViewController = {
	Name = "CommandViewController",
	Dependencies = { "InputController", "CameraController", "UIController", "ReplicaController", "HUDController" },
	Opened = Signal.new() :: Signal.Signal<()>,
	Closed = Signal.new() :: Signal.Signal<()>,
	Selected = Signal.new() :: Signal.Signal<number?, number?>,
}

local input: any = nil
local cameraController: any = nil
local ui: any = nil
local replica: any = nil
local inRun = false

local t: { [string]: any } = {}
local open = false
local center = Vector2.zero -- the view's centre: world X and Y
local height = 60 -- studs of the bunker that fit the view's height
local gridZ = 0
local bounds: CV.Bounds = { Left = 0, Right = 0, Top = 0, Bottom = 0 }
local moving: { Alpha: number, From: CFrame, FromFov: number, To: (() -> (CFrame, number))?, Back: boolean, Done: (() -> ())? }? = nil
local before: { CFrame: CFrame, FieldOfView: number }? = nil
local lightingBefore: { [string]: any }? = nil
local selected: { number }? = nil
local choice: Choice? = nil
local tab = "Build"
local bunker: any = nil
local bunkerDirty = true
local labels: { [string]: any } = {}
local labelsDirty = true
local ghosts: { [string]: { Frame: any, Floor: number, Column: number, Span: number } } = {}
local pings: { { Frame: any, Floor: number, Column: number, Until: number } } = {}
local blinking: { [string]: boolean } = {}
local handlers: { [string]: (Choice) -> () } = {}
local overlays: { [string]: Overlay } = {}
local selectionMark: any = nil
local drag: { Start: Vector2, Last: Vector2, Moved: boolean, Touch: InputObject? }? = nil
local pinch: { [InputObject]: Vector2 } = {}
local lastHealth: number? = nil
local frontWalls: { [BasePart]: boolean } = {}
local connections: { RBXScriptConnection } = {}

-- Layout --------------------------------------------------------------------------------------

local function gui(): ScreenGui?
	return ui:Gui()
end

local function part(path: string): any
	local root = gui()
	assert(root, "CommandViewController: no Frame")
	local found = UIContract.Find(root, path)
	assert(found, `CommandViewController: Frame.{path} is missing (see Shared.UIContract)`)
	return found
end

local function page(): any
	return part("Cabinet.Pages.CommandView")
end

local function clone(template: string): any
	local copy = part("Templates." .. template):Clone()
	copy.Visible = true
	return copy
end

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- Screen and world ---------------------------------------------------------------------------

-- Zone C's rectangle in viewport pixels (GUI coordinates plus the top inset).
local function viewRect(): (Vector2, Vector2)
	local view = part("Cabinet.Pages.CommandView.View")
	local inset = GuiService:GetGuiInset()
	return view.AbsolutePosition + inset, view.AbsoluteSize
end

local function inView(point: Vector2): boolean
	local origin, size = viewRect()
	return point.X >= origin.X and point.Y >= origin.Y and point.X <= origin.X + size.X and point.Y <= origin.Y + size.Y
end

-- The camera for the current centre and zoom: far away along +Z, looking at the bunker's front,
-- shifted so the centre shows in the middle of zone C rather than the middle of the screen.
local function viewCFrame(): (CFrame, number)
	local camera = workspace.CurrentCamera
	local distance = CV.DistanceFor(height, t.FieldOfView)
	local viewport = camera.ViewportSize
	local origin, size = viewRect()
	local zoneCentre = origin + size / 2
	local offset = zoneCentre - viewport / 2
	local perPixel = height / math.max(viewport.Y, 1)
	local position = Vector3.new(center.X - offset.X * perPixel, center.Y + offset.Y * perPixel, gridZ + distance)
	return CFrame.lookAt(position, position - Vector3.zAxis), t.FieldOfView
end

-- The cell under a viewport point: the ray meets the plane of the cells' centres.
local function cellAt(point: Vector2): (number?, number?)
	local ray = workspace.CurrentCamera:ViewportPointToRay(point.X, point.Y)
	if math.abs(ray.Direction.Z) < 1e-6 then
		return nil, nil
	end
	local along = (gridZ - ray.Origin.Z) / ray.Direction.Z
	if along <= 0 then
		return nil, nil
	end
	local floor, column = Grid.CellAt(ray.Origin + ray.Direction * along)
	if floor and column and Grid.OnGrid(floor, column) then
		return floor, column
	end
	return nil, nil
end

-- A world rectangle (cells from column to column + span - 1 on a floor) in zone C's scale.
local function cellRect(floor: number, column: number, span: number): (UDim2, UDim2, boolean)
	local camera = workspace.CurrentCamera
	local pitch = Grid.Pitch()
	local left = Grid.CellPosition(floor, column) - Vector3.new(pitch.X / 2, -pitch.Y / 2, 0)
	local right = Grid.CellPosition(floor, column + span - 1) + Vector3.new(pitch.X / 2, -pitch.Y / 2, 0)
	local a = camera:WorldToViewportPoint(Vector3.new(left.X, left.Y, gridZ))
	local b = camera:WorldToViewportPoint(Vector3.new(right.X, right.Y, gridZ))
	local origin, size = viewRect()
	local x0, y0 = (math.min(a.X, b.X) - origin.X) / size.X, (math.min(a.Y, b.Y) - origin.Y) / size.Y
	local x1, y1 = (math.max(a.X, b.X) - origin.X) / size.X, (math.max(a.Y, b.Y) - origin.Y) / size.Y
	local visible = x1 > 0 and y1 > 0 and x0 < 1 and y0 < 1
	return UDim2.fromScale(x0, y0), UDim2.fromScale(x1 - x0, y1 - y0), visible
end

-- A world point in zone C's scale.
local function pointIn(world: Vector3): (UDim2, boolean)
	local p = workspace.CurrentCamera:WorldToViewportPoint(world)
	local origin, size = viewRect()
	local x, y = (p.X - origin.X) / size.X, (p.Y - origin.Y) / size.Y
	return UDim2.fromScale(x, y), x >= 0 and y >= 0 and x <= 1 and y <= 1
end

-- The bunker -----------------------------------------------------------------------------------

local function currentBunker(): any
	if bunkerDirty or not bunker then
		bunker = Bunker.FromSnapshot(replica:All("Cells"), replica:All("Rooms"))
		bunkerDirty = false
	end
	return bunker
end

local function context(): CV.Context
	local era = table.find(Config.Ids("Eras"), RunState.Get("Era") or "") or 1
	return { Era = era, Deepest = currentBunker():DeepestFloor(), Unlocked = nil }
end

local function roomName(roomType: string): string
	local info = Config.Find("Rooms", roomType)
	return if info then info.Name else roomType
end

-- Labels, marks and pings ---------------------------------------------------------------------

local function overlayLamp(roomId: string, room: any): string?
	if tab == "Build" then
		return nil
	end
	local provider = overlays[tab]
	if not provider then
		return nil
	end
	local ok, lamp = pcall(provider, roomId, room)
	return if ok then lamp else nil
end

local function rebuildLabels()
	labelsDirty = false
	local holder = part("Cabinet.Pages.CommandView.View.Labels")
	clear(holder)
	table.clear(labels)
	for id, room in replica:All("Rooms") do
		local label = clone("RoomLabel")
		label.Name = id
		label:FindFirstChild("Name").Text = `{string.upper(roomName(room.Type))}  ·  L{room.Level}`
		label.Parent = holder
		labels[id] = label
	end
end

local function placeLabels()
	local pitch = Grid.Pitch()
	for id, label in labels do
		local room = replica:Get("Rooms", id)
		if room then
			local first = Grid.CellPosition(room.Floor, room.Column)
			local last = Grid.CellPosition(room.Floor, room.Column + room.Span - 1)
			local top = Vector3.new((first.X + last.X) / 2, first.Y + pitch.Y / 2 - 1.5, gridZ)
			local position, visible = pointIn(top)
			label.Position = position
			label.Visible = visible
			label.ImageColor3 = if blinking[id] then RUST else Color3.new(1, 1, 1)
			local lamp = label:FindFirstChild("Lamp")
			local sprite = overlayLamp(id, room)
			lamp.Visible = sprite ~= nil
			if sprite then
				KitRuntime.SetSprite(lamp, sprite)
			end
		end
	end
end

local function placeMarks()
	if selectionMark then
		local floor, column, span = selected and selected[1], selected and selected[2], 1
		if selected and floor and column then
			local roomId = currentBunker():UnitAt(floor, column)
			local room = roomId and currentBunker():Room(roomId)
			if room then
				column, span = room.Column, room.Span
			end
			local position, size, visible = cellRect(floor, column, span)
			selectionMark.Position = position
			selectionMark.Size = size
			selectionMark.Visible = visible
		else
			selectionMark.Visible = false
		end
	end
	for _, ghost in ghosts do
		local position, size, visible = cellRect(ghost.Floor, ghost.Column, ghost.Span)
		ghost.Frame.Position = position
		ghost.Frame.Size = size
		ghost.Frame.Visible = visible
	end
	local now = os.clock()
	for i = #pings, 1, -1 do
		local ping = pings[i]
		if now > ping.Until then
			ping.Frame:Destroy()
			table.remove(pings, i)
		else
			local cell = Grid.CellPosition(ping.Floor, ping.Column)
			local position, visible = pointIn(Vector3.new(cell.X, cell.Y, gridZ))
			ping.Frame.Position = position
			ping.Frame.Visible = visible
		end
	end
end

-- The detail panel ------------------------------------------------------------------------------

local function section(order: number, label: string, body: string)
	local s = ui:Clone("Section")
	s.LayoutOrder = order
	s:FindFirstChild("Label").Text = string.upper(label)
	s:FindFirstChild("Body").Text = body
	s.Parent = part("Cabinet.Pages.CommandView.Detail.Body")
end

local rowConnections: { RBXScriptConnection } = {}
local refreshDetail: () -> ()

local function optionRow(order: number, name: string, value: string, enabled: boolean, pick: Choice?)
	local row = clone("OptionRow")
	row.LayoutOrder = order
	row:FindFirstChild("Name").Text = string.upper(name)
	row:FindFirstChild("Value").Text = value
	row.ImageTransparency = if enabled then 0 else 0.35
	local lamp = row:FindFirstChild("Lamp")
	local isChosen = pick ~= nil and choice ~= nil and choice.Action == pick.Action and choice.RoomType == pick.RoomType
		and choice.Other == pick.Other and choice.RoomId == pick.RoomId
	KitRuntime.SetSprite(lamp, if isChosen then "Lamp_Orange" elseif enabled then "Lamp_Off" else "Lamp_Off")
	lamp.Visible = pick ~= nil
	if pick and enabled then
		table.insert(rowConnections, row.Activated:Connect(function()
			choice = pick
			refreshDetail()
		end))
	end
	row.Parent = part("Cabinet.Pages.CommandView.Detail.Options")
end

local function setMainAction()
	local current = choice
	if not current then
		ui:SetMainAction(nil)
		return
	end
	local label = if current.Action == "Build" then `Propose {roomName(current.RoomType or "")}`
		elseif current.Action == "Upgrade" then `Propose level {current.Level}`
		elseif current.Action == "Merge" then "Propose merge"
		else "Propose teardown"
	local handler = handlers[current.Action]
	ui:SetMainAction({
		Label = label,
		Enabled = handler ~= nil,
		OnPress = function()
			local h = handlers[current.Action]
			if h then
				h(current)
			end
		end,
	})
end

local function showRoom(roomId: string)
	local b = currentBunker()
	local room = b:Room(roomId) :: any
	local info = Config.Get("Rooms", room.Type)
	local detail = part("Cabinet.Pages.CommandView.Detail")
	detail:FindFirstChild("Name").Text = string.upper(info.Name)
	detail:FindFirstChild("Sub").Text = `LEVEL {room.Level}  ·  {room.Span} CELL{if room.Span > 1 then "S" else ""}  ·  FLOOR {room.Floor}`
	section(1, "Condition", if room.HP <= 0 then `Wrecked: 0 of {room.MaxHP} HP` else `{room.HP} of {room.MaxHP} HP`)
	if info.PowerOutput then
		section(2, "Power", `Makes {info.PowerOutput[room.Level] * room.Span}`)
	elseif info.Power[room.Level] > 0 then
		section(2, "Power", `Draws {info.Power[room.Level] * room.Span}`)
	end
	if info.Output and info.Output.Resource then
		local resource = Config.Get("Resources", info.Output.Resource)
		section(3, "Output", `{info.Output.Base} {resource.Name} per cell a cycle at level 1, with average workers`)
	end
	section(4, "What it does", info.Text)
	local order = 1
	if room.Level < 3 then
		local nextLevel = room.Level + 1
		local costs = {}
		for resource, amount in info.Costs[nextLevel] or {} do
			costs[resource] = amount * room.Span
		end
		local research = if nextLevel == 3 and info.Research then `  ·  {info.Research} LAB RESEARCH` else ""
		optionRow(order, `Upgrade to level {nextLevel}`, CV.CostText(costs) .. research, true,
			{ Action = "Upgrade", Floor = room.Floor, Column = room.Column, RoomId = roomId, Level = nextLevel })
		order += 1
	end
	for _, column in { room.Column - 1, room.Column + room.Span } do
		local otherId = b:UnitAt(room.Floor, column)
		local other = otherId and b:Room(otherId)
		if other and other.Id ~= roomId then
			local ok, why = b:CanMerge(roomId, other.Id)
			if ok or other.Type == room.Type then
				optionRow(order, `Merge with the {roomName(other.Type)}`, if ok then `{room.Span + other.Span} cells together` else (why or ""), ok,
					{ Action = "Merge", Floor = room.Floor, Column = room.Column, RoomId = roomId, Other = other.Id })
				order += 1
			end
		end
	end
	local canRemove, why = b:CanRemove(roomId)
	optionRow(order, "Tear down", if canRemove then "Its cells become open cells again" else (why or ""), canRemove,
		{ Action = "TearDown", Floor = room.Floor, Column = room.Column, RoomId = roomId })
end

local function showOpenCell(floor: number, column: number)
	local detail = part("Cabinet.Pages.CommandView.Detail")
	detail:FindFirstChild("Name").Text = "OPEN CELL"
	detail:FindFirstChild("Sub").Text = `FLOOR {floor}  ·  COLUMN {column}  ·  {string.upper(Grid.BandOf(floor).Name)}`
	section(1, "Build here", "Pick a room type, then propose it to the team.")
	local b = currentBunker()
	local ctx = context()
	local available, locked = {}, {}
	for _, roomType in Config.Ids("Rooms") do
		local ok, why = CV.RoomChoice(b, roomType, floor, column, ctx)
		table.insert(if ok then available else locked, { Type = roomType, Why = why })
	end
	local order = 1
	for _, entry in available do
		local info = Config.Get("Rooms", entry.Type)
		optionRow(order, info.Name, CV.CostText(info.Costs[1]), true,
			{ Action = "Build", Floor = floor, Column = column, RoomType = entry.Type })
		order += 1
	end
	for _, entry in locked do
		optionRow(order, Config.Get("Rooms", entry.Type).Name, entry.Why or "", false, nil)
		order += 1
	end
end

local function showRock(floor: number, column: number)
	local detail = part("Cabinet.Pages.CommandView.Detail")
	local band = Grid.BandOf(floor)
	detail:FindFirstChild("Name").Text = "ROCK"
	detail:FindFirstChild("Sub").Text = `FLOOR {floor}  ·  COLUMN {column}  ·  {string.upper(band.Name)}`
	local b = currentBunker()
	local ok, why = b:CanDig(floor, column)
	section(1, "Digging", if ok then "Can be dug: it touches an open cell." else `Can't be dug yet: {why}.`)
	if band.Ore then
		section(2, "Ore", `{Config.Get("Resources", band.Ore).Name} in the {band.Name}.`)
	end
	if Grid.IsBandStart(floor) and floor > b:DeepestFloor() then
		section(3, "Next band", `The first cell of the {band.Name}: opening it needs a Push Deeper vote.`)
	end
end

local function showNothing()
	local detail = part("Cabinet.Pages.CommandView.Detail")
	local b = currentBunker()
	local rooms, open = 0, 0
	for _ in replica:All("Rooms") do
		rooms += 1
	end
	for _, cell in replica:All("Cells") do
		if type(cell) == "table" and cell.Room == nil then
			open += 1
		end
	end
	detail:FindFirstChild("Name").Text = "BUNKER SECTION"
	detail:FindFirstChild("Sub").Text = `{rooms} ROOMS  ·  {open} OPEN CELL{if open == 1 then "" else "S"}  ·  DEPTH {b:DeepestFloor()}`
	section(1, "Pick a cell", "A room to upgrade, merge or tear down, an open cell to build on, or rock to dig.")
end

local function showOverlayLegend()
	local text = OVERLAY_TEXT[tab]
	if not text then
		return
	end
	optionRow(100, tab, if overlays[tab] then text else `{text} No readings yet.`, false, nil)
end

refreshDetail = function()
	if not open then
		return
	end
	for _, connection in rowConnections do
		connection:Disconnect()
	end
	table.clear(rowConnections)
	clear(part("Cabinet.Pages.CommandView.Detail.Body"))
	clear(part("Cabinet.Pages.CommandView.Detail.Options"))
	local cell = selected
	if not cell then
		choice = nil
		showNothing()
	else
		local state, roomId = currentBunker():State(cell[1], cell[2])
		if state == "Room" and roomId then
			showRoom(roomId)
		elseif state == "Dug" then
			showOpenCell(cell[1], cell[2])
		else
			choice = nil
			showRock(cell[1], cell[2])
		end
	end
	showOverlayLegend()
	setMainAction()
end

-- Selecting and pinging -------------------------------------------------------------------------

function CommandViewController:Select(floor: number?, column: number?)
	if floor and column and Grid.OnGrid(floor, column) then
		local same = selected ~= nil and selected[1] == floor and selected[2] == column
		selected = { floor, column }
		if not same then
			choice = nil
		end
	else
		selected = nil
		choice = nil
	end
	refreshDetail()
	CommandViewController.Selected:Fire(floor, column)
end

local function pingSelected()
	if selected and Remotes.InPlace("PingCell") then
		Remotes.FireServer("PingCell", selected[1], selected[2])
	end
end

local function onPinged(floor: number, column: number)
	if not open or type(floor) ~= "number" or type(column) ~= "number" then
		return
	end
	local mark = clone("PingMark")
	mark.Parent = part("Cabinet.Pages.CommandView.View.Marks")
	table.insert(pings, { Frame = mark, Floor = floor, Column = column, Until = os.clock() + Config.Get("Tuning", "Ping").Seconds })
end

-- Moving the camera -----------------------------------------------------------------------------

local function panBy(world: Vector2)
	center = CV.Clamp(center + world, bounds)
end

local function zoomBy(factor: number)
	local pitch = Grid.Pitch()
	height = math.clamp(height * factor, t.MinFloors * pitch.Y, t.MaxFloors * pitch.Y)
end

local function readInput(dt: number)
	-- wheel and pinch (InputController gathers both; we take them before CameraController)
	local zoom = input:TakeZoom()
	if zoom ~= 0 then
		local step = Config.Get("Tuning", "Camera").ZoomStep
		zoomBy(1 + t.ZoomStep * zoom / step)
	end
	input:TakeLook(dt) -- one-finger drags arrive here too; the view pans from its own touch tracking
	local perSecond = height * t.PanFloorsPerSecond / t.StartFloors
	local move = Vector2.zero
	if not UserInputService:GetFocusedTextBox() then
		for key, direction in PAN_KEYS do
			if UserInputService:IsKeyDown(key) then
				move += direction
			end
		end
	end
	for _, state in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
		if state.KeyCode == Enum.KeyCode.Thumbstick1 and state.Position.Magnitude > t.StickDeadzone then
			move += Vector2.new(state.Position.X, state.Position.Y)
		elseif state.KeyCode == Enum.KeyCode.Thumbstick2 and math.abs(state.Position.Y) > t.StickDeadzone then
			zoomBy(1 - state.Position.Y * dt * 1.5)
		end
	end
	if move.Magnitude > 0 then
		panBy(move.Unit * math.min(move.Magnitude, 1) * perSecond * dt)
	end
end

local function render(dt: number)
	if not open and not moving then
		return
	end
	local camera = workspace.CurrentCamera
	if open and not (moving and moving.Back) then
		readInput(dt)
	end
	local current = moving
	if current then
		current.Alpha = math.min(1, current.Alpha + dt / math.max(t.MoveSeconds, 0.01))
		local eased = TweenService:GetValue(current.Alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		local toCFrame, toFov = (current.To :: any)()
		camera.CFrame = current.From:Lerp(toCFrame, eased)
		camera.FieldOfView = current.FromFov + (toFov - current.FromFov) * eased
		if current.Alpha >= 1 then
			moving = nil
			if current.Done then
				current.Done()
			end
		end
	else
		local cframe, fov = viewCFrame()
		camera.CFrame = cframe
		camera.FieldOfView = fov
	end
	if open then
		if labelsDirty then
			rebuildLabels()
		end
		placeLabels()
		placeMarks()
		local cursor = part("Cabinet.Pages.CommandView.View.Cursor")
		cursor.Visible = input:Device() == "Gamepad"
	end
end

-- Input handlers ---------------------------------------------------------------------------------

local function onInputBegan(io: InputObject)
	if not open then
		return
	end
	if io.UserInputType == Enum.UserInputType.MouseButton1 then
		local point = UserInputService:GetMouseLocation()
		if inView(point) then
			drag = { Start = point, Last = point, Moved = false, Touch = nil }
		end
	elseif io.UserInputType == Enum.UserInputType.Touch then
		local point = Vector2.new(io.Position.X, io.Position.Y) + GuiService:GetGuiInset()
		if inView(point) then
			pinch[io] = point
			local count = 0
			for _ in pinch do
				count += 1
			end
			drag = if count == 1 then { Start = point, Last = point, Moved = false, Touch = io } else nil
		end
	end
end

local function onInputChanged(io: InputObject)
	if not open then
		return
	end
	local current = drag
	if io.UserInputType == Enum.UserInputType.MouseMovement and current and not current.Touch then
		local point = UserInputService:GetMouseLocation()
		local delta = point - current.Last
		current.Last = point
		if (point - current.Start).Magnitude > t.DragPixels then
			current.Moved = true
		end
		if current.Moved then
			local perPixel = height / math.max(workspace.CurrentCamera.ViewportSize.Y, 1)
			panBy(Vector2.new(-delta.X, delta.Y) * perPixel)
		end
	elseif io.UserInputType == Enum.UserInputType.Touch and pinch[io] then
		local point = Vector2.new(io.Position.X, io.Position.Y) + GuiService:GetGuiInset()
		pinch[io] = point
		if current and current.Touch == io then
			local delta = point - current.Last
			current.Last = point
			if (point - current.Start).Magnitude > t.DragPixels then
				current.Moved = true
			end
			if current.Moved then
				local perPixel = height / math.max(workspace.CurrentCamera.ViewportSize.Y, 1)
				panBy(Vector2.new(-delta.X, delta.Y) * perPixel)
			end
		end
	end
end

local function onInputEnded(io: InputObject)
	local current = drag
	if io.UserInputType == Enum.UserInputType.MouseButton1 and current and not current.Touch then
		drag = nil
		if open and not current.Moved then
			CommandViewController:Select(cellAt(current.Start))
		end
	elseif io.UserInputType == Enum.UserInputType.Touch then
		pinch[io] = nil
		if current and current.Touch == io then
			drag = nil
			if open and not current.Moved then
				CommandViewController:Select(cellAt(current.Start))
			end
		end
	end
end

-- Open and close ---------------------------------------------------------------------------------

-- The character stays where it was left: its movement keys and sticks are sunk while the view is
-- open (Roblox's PlayerModule isn't an instance in every place, so this goes through
-- ContextActionService rather than its controls object).
local function holdCharacter(on: boolean)
	if not on then
		ContextActionService:UnbindAction(HOLD_ACTION)
		return
	end
	ContextActionService:BindActionAtPriority(HOLD_ACTION, function()
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 20,
		Enum.PlayerActions.CharacterForward, Enum.PlayerActions.CharacterBackward,
		Enum.PlayerActions.CharacterLeft, Enum.PlayerActions.CharacterRight, Enum.PlayerActions.CharacterJump,
		Enum.KeyCode.Thumbstick1, Enum.KeyCode.Space)
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:Move(Vector3.zero)
	end
end

local function fadeFrontWalls(on: boolean)
	if on then
		for _, item in CollectionService:GetTagged(FRONT_WALL_TAG) do
			if item:IsA("BasePart") then
				Fade.Set(item, FADE_SOURCE, 1)
				frontWalls[item] = true
			end
		end
	else
		Fade.ClearSource(FADE_SOURCE)
		table.clear(frontWalls)
	end
end

local function liftLighting(on: boolean)
	if on then
		lightingBefore = {
			Ambient = Lighting.Ambient,
			OutdoorAmbient = Lighting.OutdoorAmbient,
			ExposureCompensation = Lighting.ExposureCompensation,
		}
		Lighting.Ambient = Color3.fromHex(t.Ambient)
		Lighting.OutdoorAmbient = Color3.fromHex(t.OutdoorAmbient)
		Lighting.ExposureCompensation = t.ExposureCompensation
	elseif lightingBefore then
		Lighting.Ambient = lightingBefore.Ambient
		Lighting.OutdoorAmbient = lightingBefore.OutdoorAmbient
		Lighting.ExposureCompensation = lightingBefore.ExposureCompensation
		lightingBefore = nil
	end
end

local function flashEdge()
	local edge = part("DamageEdge")
	edge.Visible = true
	for _, strip in edge:GetChildren() do
		if strip:IsA("Frame") then
			strip.BackgroundTransparency = 0
			TweenService:Create(strip, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
			}):Play()
		end
	end
	task.delay(0.65, function()
		if edge.Parent then
			edge.Visible = false
		end
	end)
end

local function helpText(): string
	local device = input:Device()
	if device == "Gamepad" then
		return "LEFT STICK MOVE  ·  RIGHT STICK ZOOM  ·  A PICK  ·  D-PAD UP PING"
	elseif device == "Touch" then
		return "DRAG TO MOVE  ·  PINCH TO ZOOM  ·  TAP A CELL"
	end
	return "DRAG OR WASD TO MOVE  ·  SCROLL TO ZOOM  ·  CLICK A CELL  ·  G PING"
end

local function bindKeys(on: boolean)
	if not on then
		ContextActionService:UnbindAction(PING_ACTION)
		ContextActionService:UnbindAction(PICK_ACTION)
		return
	end
	ContextActionService:BindActionAtPriority(PING_ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			pingSelected()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 20, Enum.KeyCode.G, Enum.KeyCode.DPadUp)
	ContextActionService:BindActionAtPriority(PICK_ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			local origin, size = viewRect()
			CommandViewController:Select(cellAt(origin + size / 2))
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 30, Enum.KeyCode.ButtonA)
end

local function onOpen(_page: Frame)
	open = true
	local camera = workspace.CurrentCamera
	before = { CFrame = camera.CFrame, FieldOfView = camera.FieldOfView }
	cameraController:Suspend(SCREEN)
	camera.CameraType = Enum.CameraType.Scriptable
	holdCharacter(true)
	bounds = CV.Bounds()
	gridZ = Grid.CellPosition(1, 0).Z
	height = t.StartFloors * Grid.Pitch().Y
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	center = CV.Clamp(if root and root:IsA("BasePart") then Vector2.new(root.Position.X, root.Position.Y) else Vector2.zero, bounds)
	selected = nil
	choice = nil
	labelsDirty = true
	fadeFrontWalls(true)
	liftLighting(true)
	selectionMark = clone("CellMark")
	selectionMark.Visible = false
	selectionMark.Parent = part("Cabinet.Pages.CommandView.View.Marks")
	part("Cabinet.Pages.CommandView.View.Help.Text").Text = helpText()
	ui:SetFooterActions({ { Label = "Ping", OnPress = pingSelected } })
	bindKeys(true)
	GuiService.SelectedObject = nil
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	lastHealth = if humanoid then humanoid.Health else nil
	moving = { Alpha = 0, From = camera.CFrame, FromFov = camera.FieldOfView, To = viewCFrame, Back = false, Done = nil }
	refreshDetail()
	CommandViewController.Opened:Fire()
end

local function onClose()
	if not open then
		return
	end
	open = false
	bindKeys(false)
	drag = nil
	table.clear(pinch)
	for _, ping in pings do
		ping.Frame:Destroy()
	end
	table.clear(pings)
	if selectionMark then
		selectionMark:Destroy()
		selectionMark = nil
	end
	for _, connection in rowConnections do
		connection:Disconnect()
	end
	table.clear(rowConnections)
	fadeFrontWalls(false)
	liftLighting(false)
	holdCharacter(false)
	local camera = workspace.CurrentCamera
	local back = before
	before = nil
	if back then
		local target = back
		moving = {
			Alpha = 0,
			From = camera.CFrame,
			FromFov = camera.FieldOfView,
			To = function()
				return target.CFrame, target.FieldOfView
			end,
			Back = true,
			Done = function()
				cameraController:Resume(SCREEN)
			end,
		}
	else
		cameraController:Resume(SCREEN)
	end
	CommandViewController.Closed:Fire()
end

-- API ----------------------------------------------------------------------------------------------

function CommandViewController:Toggle()
	if not inRun or not ui:Gui() then
		return
	end
	if ui:Current() == SCREEN then
		ui:Close()
	elseif not ui:IsOpen() then
		ui:Open(SCREEN)
	end
end

function CommandViewController:IsOpen(): boolean
	return open
end

-- A proposal's handler: "Build", "Upgrade", "Merge" or "TearDown" (the votes, Prompt 8).
function CommandViewController:SetHandler(action: string, handler: ((Choice) -> ())?)
	handlers[action] = handler
	if open then
		setMainAction()
	end
end

-- An overlay's provider: (roomId, room) -> lamp sprite (Lamp_Green, Lamp_Amber, Lamp_Red...).
function CommandViewController:SetOverlay(name: string, provider: Overlay?)
	assert(OVERLAY_TEXT[name], `CommandViewController: no overlay {name}`)
	overlays[name] = provider
	if open then
		refreshDetail()
	end
end

-- A ghost outline for an open vote (Section 7), until HideGhost.
function CommandViewController:ShowGhost(id: string, floor: number, column: number, span: number, label: string?)
	CommandViewController:HideGhost(id)
	if not gui() then
		return
	end
	local mark = clone("CellMark")
	mark.BackgroundColor3 = CREAM
	local stroke = mark:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = CREAM
	end
	local text = mark:FindFirstChild("Label")
	if text and label then
		text.Text = string.upper(label)
		text.Visible = true
	end
	mark.Parent = part("Cabinet.Pages.CommandView.View.Marks")
	ghosts[id] = { Frame = mark, Floor = floor, Column = column, Span = span }
end

function CommandViewController:HideGhost(id: string)
	local ghost = ghosts[id]
	if ghost then
		ghost.Frame:Destroy()
		ghosts[id] = nil
	end
end

-- Lights a room's label (by room id) rust red while on.
function CommandViewController:Blink(key: string, on: boolean)
	blinking[key] = if on then true else nil
end

function CommandViewController:State(): { [string]: any }
	local pitch = Grid.Pitch()
	return {
		Open = open,
		Center = center,
		Floors = height / pitch.Y,
		Selected = if selected then Grid.Key(selected[1], selected[2]) else nil,
		Choice = if choice then `{choice.Action} {choice.RoomType or choice.RoomId or ""}` else nil,
		Tab = tab,
		Labels = (function()
			local n = 0
			for _ in labels do
				n += 1
			end
			return n
		end)(),
		Pings = #pings,
		FieldOfView = workspace.CurrentCamera.FieldOfView,
	}
end

-- Lifecycle ------------------------------------------------------------------------------------------

function CommandViewController:Init(registry)
	input = registry.InputController
	cameraController = registry.CameraController
	ui = registry.UIController
	replica = registry.ReplicaController
	inRun = Constants.PlaceKind() == "Run"
	t = CV.Tuning()
end

function CommandViewController:Start()
	if not inRun then
		return
	end
	local waited = 0
	while not ui:Gui() and waited < 20 do
		waited += task.wait(0.25)
	end
	local root = ui:Gui()
	if not root or not UIContract.Find(root, "Cabinet.Pages.CommandView") then
		log:Warn("the Frame has no Command View page; it can't open")
		return
	end
	ui:Register(SCREEN, {
		Title = "Command View",
		Subtitle = "STEADFAST SHELTER CO.  ·  BUNKER IN SECTION",
		Tabs = TABS,
		Page = SCREEN,
		Docked = true,
		GamepadSelect = false,
		Hint = "Your character stays where you left it, and can be hit.",
		OnOpen = function(p: Frame)
			onOpen(p)
		end,
		OnTab = function(id: string)
			tab = id
			if open then
				refreshDetail()
			end
		end,
		OnClose = onClose,
	})
	input:On("CommandView", function()
		CommandViewController:Toggle()
	end)
	replica:Changed("Cells"):Connect(function()
		bunkerDirty = true
		if open then
			refreshDetail()
		end
	end)
	replica:Changed("Rooms"):Connect(function()
		bunkerDirty = true
		labelsDirty = true
		if open then
			refreshDetail()
		end
	end)
	Remotes.OnClient("CellPinged", onPinged)
	CollectionService:GetInstanceAddedSignal(FRONT_WALL_TAG):Connect(function(item: Instance)
		if open and item:IsA("BasePart") then
			Fade.Set(item, FADE_SOURCE, 1)
		end
	end)
	input.DeviceChanged:Connect(function()
		if open then
			part("Cabinet.Pages.CommandView.View.Help.Text").Text = helpText()
		end
	end)
	table.insert(connections, UserInputService.InputBegan:Connect(onInputBegan))
	table.insert(connections, UserInputService.InputChanged:Connect(onInputChanged))
	table.insert(connections, UserInputService.InputEnded:Connect(onInputEnded))
	local function watchHealth(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.HealthChanged:Connect(function(health: number)
				if open and lastHealth and health < lastHealth then
					flashEdge()
				end
				lastHealth = health
			end)
		end
	end
	Players.LocalPlayer.CharacterAdded:Connect(watchHealth)
	if Players.LocalPlayer.Character then
		task.spawn(watchHealth, Players.LocalPlayer.Character)
	end
	RunService:BindToRenderStep(RENDER_NAME, RENDER_PRIORITY, render)
	log:Debug("Command View ready")
end

return CommandViewController
