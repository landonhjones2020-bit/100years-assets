--!strict
--[[
	MiniMapController: the side-view mini-map on the HUD (bible Section 18: "a side-view
	mini-map of the bunker with alerts blinking").

	It draws a window of the bunker around the player (Rules.Hud.MapWindow: 5 columns, 5 floors)
	from the replicated Cells and Rooms collections: each room as one block across its cells with
	its short name, a dug cell as a faint block, rock as bare blueprint paper. The player's cell
	lights an orange pilot lamp. The footer names the deepest band and floor reached.
	Pinged cells (PingService, from the Command View) show a yellow pin for Tuning.Ping.Seconds.
	Blink(roomId, on) is for the alerts (AlertController, Prompt 12).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Grid = require(Shared.Rules.Grid)
local Hud = require(Shared.Rules.Hud)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)

local log = Log.new("MiniMapController")

local COLUMNS = 5
local ROWS = 5
local INSET = 0.05 -- of a cell, on each side
local POLL_SECONDS = 0.25
local NAVY = Color3.fromHex("#1B2A3A")
local RUST = Color3.fromHex("#B5412B")

local MiniMapController = {
	Name = "MiniMapController",
	Dependencies = { "ReplicaController", "HUDController" },
}

local replica: any = nil
local hud: any = nil
local cellsFrame: Frame? = nil
local you: ImageLabel? = nil
local depthLabel: TextLabel? = nil
local template: Frame? = nil
local playerCell: { number }? = nil
local dirty = true
local blinking: { [string]: boolean } = {}
local blocks: { [string]: Frame } = {}
local window = { 0, 1 } -- the first column and first floor shown
local pingTemplate: Instance? = nil
local pingMarks: { { Frame: any, Floor: number, Column: number, Until: number } } = {}

local function placePings()
	local now = os.clock()
	for i = #pingMarks, 1, -1 do
		local ping = pingMarks[i]
		if now > ping.Until then
			ping.Frame:Destroy()
			table.remove(pingMarks, i)
		else
			local x = (ping.Column - window[1] + 0.5) / COLUMNS
			local y = (ping.Floor - window[2] + 0.75) / ROWS
			ping.Frame.Position = UDim2.fromScale(x, y)
			ping.Frame.Visible = x > 0 and x < 1 and y > 0 and y <= 1
		end
	end
end

local function shortName(roomType: string): string
	local room = Config.Find("Rooms", roomType)
	local name = if room then room.Name else roomType
	return string.upper(string.match(name, "^(%S+)") or name)
end

local function block(key: string, floor: number, column: number, span: number, first: { number }, label: string, dug: boolean)
	local frame = (template :: Frame):Clone()
	frame.Name = key
	frame.Visible = true
	local c0, f0 = first[1], first[2]
	local from = math.max(column, c0)
	local to = math.min(column + span - 1, c0 + COLUMNS - 1)
	frame.Position = UDim2.fromScale((from - c0 + INSET) / COLUMNS, (floor - f0 + INSET) / ROWS)
	frame.Size = UDim2.fromScale((to - from + 1 - 2 * INSET) / COLUMNS, (1 - 2 * INSET) / ROWS)
	frame.BackgroundTransparency = if dug then 0.85 else 0.55
	frame.BackgroundColor3 = if blinking[key] then RUST else NAVY
	local text = frame:FindFirstChild("Label") :: TextLabel?
	if text then
		text.Text = label
		text.Visible = label ~= "" and (to - from + 1) >= 1
	end
	frame.Parent = cellsFrame
	blocks[key] = frame
end

local function redraw()
	dirty = false
	local holder = cellsFrame
	if not holder or not template then
		return
	end
	for _, child in holder:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(blocks)
	local grid = Grid.Tuning()
	local here = playerCell or { 1, 0 }
	local c0, f0 = Hud.MapWindow(here[1], here[2], grid, COLUMNS, ROWS)
	local first = { c0, f0 }
	window = first
	local seenRooms: { [string]: boolean } = {}
	local deepest = 0
	for key, cell in replica:All("Cells") do
		local floor, column = Grid.Parse(key)
		if floor and column then
			deepest = math.max(deepest, floor)
			if floor >= f0 and floor < f0 + ROWS and column >= c0 and column < c0 + COLUMNS then
				local roomId = if type(cell) == "table" then cell.Room else nil
				if roomId then
					if not seenRooms[roomId] then
						seenRooms[roomId] = true
						local room = replica:Get("Rooms", roomId)
						if room then
							block(roomId, room.Floor, room.Column, room.Span or 1, first, shortName(room.Type), false)
						end
					end
				else
					block(key, floor, column, 1, first, "", true)
				end
			end
		end
	end
	if you then
		you.Visible = playerCell ~= nil
		if playerCell then
			you.Position = UDim2.fromScale((playerCell[2] - c0 + 0.5) / COLUMNS, (playerCell[1] - f0 + 0.5) / ROWS)
		end
	end
	if depthLabel then
		if deepest > 0 then
			local band = Grid.BandOf(deepest)
			depthLabel.Text = `{string.upper(band.Name)}  ·  DEPTH {deepest}`
		else
			depthLabel.Text = ""
		end
	end
end

local function poll()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local floor, column = nil, nil
	if root and root:IsA("BasePart") then
		floor, column = Grid.CellAt(root.Position)
	end
	local cell = if floor and column then { floor, column } else nil
	local changed = (cell == nil) ~= (playerCell == nil)
		or (cell ~= nil and playerCell ~= nil and (cell[1] ~= playerCell[1] or cell[2] ~= playerCell[2]))
	if changed then
		playerCell = cell
		dirty = true
	end
	if dirty then
		redraw()
	end
	placePings()
end

-- Shows a pin on a cell for Tuning.Ping.Seconds (PingService's CellPinged).
function MiniMapController:Ping(floor: number, column: number)
	if not cellsFrame or not pingTemplate then
		return
	end
	local mark = pingTemplate:Clone() :: any
	mark.Visible = true
	mark.Parent = cellsFrame.Parent
	table.insert(pingMarks, { Frame = mark, Floor = floor, Column = column, Until = os.clock() + Config.Get("Tuning", "Ping").Seconds })
	placePings()
end

-- Lights a room's block (or a dug cell's, by "floor,column") rust red while on.
function MiniMapController:Blink(key: string, on: boolean)
	blinking[key] = if on then true else nil
	local frame = blocks[key]
	if frame then
		frame.BackgroundColor3 = if on then RUST else NAVY
	end
end

function MiniMapController:Init(registry)
	replica = registry.ReplicaController
	hud = registry.HUDController
end

function MiniMapController:Start()
	if Constants.PlaceKind() ~= "Run" then
		return
	end
	local gui = hud:Gui()
	local waited = 0
	while not gui and waited < 20 do -- HUDController finds the HUD in its own Start
		waited += task.wait(0.25)
		gui = hud:Gui()
	end
	if not gui then
		return
	end
	local paper = gui:FindFirstChild("MiniMap") and gui.MiniMap:FindFirstChild("Paper")
	cellsFrame = paper and paper:FindFirstChild("Cells")
	you = paper and paper:FindFirstChild("You")
	depthLabel = gui.MiniMap:FindFirstChild("Depth")
	template = gui:FindFirstChild("Templates") and gui.Templates:FindFirstChild("MapCell")
	if not cellsFrame or not template then
		log:Warn("the HUD has no mini-map")
		return
	end
	pingTemplate = gui.Templates:FindFirstChild("MapPing")
	if Remotes.InPlace("CellPinged") then
		Remotes.OnClient("CellPinged", function(floor: any, column: any)
			if type(floor) == "number" and type(column) == "number" then
				MiniMapController:Ping(floor, column)
			end
		end)
	end
	local function mark()
		dirty = true
	end
	replica:Changed("Cells"):Connect(mark)
	replica:Changed("Rooms"):Connect(mark)
	task.spawn(function()
		while true do
			poll()
			task.wait(POLL_SECONDS)
		end
	end)
	log:Debug("mini-map ready")
end

return MiniMapController
