--!strict
--[[
	DigController: what players see of digging (bible Sections 6, 7, 10 and 14). Run place only;
	Prompt 14. The server's DigService decides everything; this draws it from the Digs collection,
	RunState and the dig prompts.

	* Dig prompts (workspace.Bunker.Digging) show only to players who carry a Drill or a Pickaxe;
	  their gauge shows the cell's shared progress (PromptController reads the Progress attribute).
	* Dust and falling chips at every face of a cell being dug (by players or the Drill Bay), and a
	  burst of dust when a cell opens.
	* A Tremor (RunState.TremorAt) shakes the over-the-shoulder camera.
	* The Command View: a rock cell says how long it takes to dig here, how far along it is, where
	  it is on the Drill Bay's queue (and whether a Drill Bay is digging), whether it needs a Push
	  Deeper vote, and, for a class that sees ore and caves (the Driller's OreSightCells), what it
	  holds. Its options put it on the queue or take it off (MarkDig, no vote). A dug cell says
	  what it holds: a cave opening, a cache to open, a nest to destroy.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Dig = require(Shared.Rules.Dig)
local Grid = require(Shared.Rules.Grid)
local Log = require(Shared.Utilities.Log)
local Modifiers = require(Shared.Rules.Modifiers)
local Remotes = require(Shared.Remotes)
local RunState = require(Shared.RunState)

local log = Log.new("DigController")
local player = Players.LocalPlayer

local DigController = {
	Name = "DigController",
	Dependencies = { "ReplicaController", "CommandViewController", "CameraController" },
}

local DUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local DUST_COLOR = Color3.fromRGB(150, 138, 120)
local CHIP_COLOR = Color3.fromRGB(98, 90, 82)
-- What the client can know of the roll (the same results DigService rolls; the rest are Empty).
local AVAILABLE: { [string]: boolean } = { Empty = true, OrePocket = true, CaveOpening = true, Cache = true, Nest = true, CryoPod = true }

local replica: any = nil
local commandView: any = nil
local camera: any = nil

local digPrompts: { [ProximityPrompt]: boolean } = {}
local dust: { [string]: { Instance } } = {} -- cell key -> emitters at its faces

-- Prompts ----------------------------------------------------------------------------------------------

local function carried(): { string }
	local items = {}
	for i = 1, 5 do
		local item = player:GetAttribute(`Item{i}`)
		if type(item) == "string" then
			table.insert(items, item)
		end
	end
	local melee = player:GetAttribute("MeleeItem")
	if type(melee) == "string" then
		table.insert(items, melee)
	end
	return items
end

local function gate(prompt: Instance)
	if prompt:IsA("ProximityPrompt") and prompt:GetAttribute("Kind") == "DigCell" then
		digPrompts[prompt] = true
		prompt.Enabled = Dig.CanDigWith(carried())
		prompt.AncestryChanged:Connect(function()
			if not prompt:IsDescendantOf(workspace) then
				digPrompts[prompt] = nil
			end
		end)
	end
end

local function regate()
	local can = Dig.CanDigWith(carried())
	for prompt in digPrompts do
		prompt.Enabled = can
	end
end

-- Dust ----------------------------------------------------------------------------------------------------

local function facePoints(key: string): { Vector3 }
	local points = {}
	for prompt in digPrompts do
		if prompt:GetAttribute("Cell") == key and prompt.Parent and prompt.Parent:IsA("BasePart") then
			table.insert(points, (prompt.Parent :: BasePart).Position)
		end
	end
	return points
end

local function anchorAt(position: Vector3): Attachment
	local part = workspace.Terrain
	local at = Instance.new("Attachment")
	at.WorldPosition = position
	at.Parent = part
	return at
end

local function emitterAt(position: Vector3, burst: boolean): { Instance }
	local at = anchorAt(position)
	local cloud = Instance.new("ParticleEmitter")
	cloud.Name = "DigDust"
	cloud.Texture = DUST_TEXTURE
	cloud.Color = ColorSequence.new(DUST_COLOR)
	cloud.LightInfluence = 0.8
	cloud.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 4.5) })
	cloud.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	cloud.Lifetime = NumberRange.new(1.2, 2.2)
	cloud.Speed = NumberRange.new(1.5, 4)
	cloud.SpreadAngle = Vector2.new(80, 80)
	cloud.Acceleration = Vector3.new(0, -1.5, 0)
	cloud.Rate = if burst then 0 else 14
	cloud.Parent = at
	local chips = Instance.new("ParticleEmitter")
	chips.Name = "DigChips"
	chips.Color = ColorSequence.new(CHIP_COLOR)
	chips.LightInfluence = 1
	chips.Size = NumberSequence.new(0.22)
	chips.Lifetime = NumberRange.new(0.5, 0.9)
	chips.Speed = NumberRange.new(6, 11)
	chips.SpreadAngle = Vector2.new(60, 60)
	chips.Acceleration = Vector3.new(0, -40, 0)
	chips.Rate = if burst then 0 else 18
	chips.Parent = at
	if burst then
		cloud:Emit(40)
		chips:Emit(30)
		task.delay(3, function()
			at:Destroy()
		end)
	end
	return { at }
end

local function stopDust(key: string)
	local list = dust[key]
	if list then
		for _, item in list do
			item:Destroy()
		end
		dust[key] = nil
	end
end

local function syncDust()
	local active: { [string]: boolean } = {}
	for id, entry in replica:All("Digs") do
		if string.sub(id, 1, 2) == "S:" and type(entry) == "table" and ((entry.Diggers or 0) > 0 or entry.Bay) then
			active[Grid.Key(entry.Floor, entry.Column)] = true
		end
	end
	for key in dust do
		if not active[key] then
			stopDust(key)
		end
	end
	for key in active do
		if not dust[key] then
			local list = {}
			for _, point in facePoints(key) do
				for _, item in emitterAt(point, false) do
					table.insert(list, item)
				end
			end
			dust[key] = list
		end
	end
end

-- A cell that opens bursts dust (after the first snapshot: a cell that wasn't open before).
local burstsFrom = math.huge

local function onCells(key: string?, value: any, old: any)
	if not key or os.clock() < burstsFrom then
		return
	end
	if value ~= nil and old == nil then
		local floor, column = Grid.Parse(key)
		if floor and column then
			emitterAt(Grid.CellPosition(floor, column) + Vector3.new(0, 4, 0), true)
		end
		stopDust(key)
	end
end

-- The Command View ------------------------------------------------------------------------------------------

local function siteAt(floor: number, column: number): any
	local entry = replica:Get("Digs", `S:{Grid.Key(floor, column)}`)
	return if type(entry) == "table" then entry else nil
end

local function featureAt(floor: number, column: number): any
	local entry = replica:Get("Digs", `F:{Grid.Key(floor, column)}`)
	return if type(entry) == "table" then entry else nil
end

local function drillBays(): number
	local n = 0
	for _, room in replica:All("Rooms") do
		if type(room) == "table" and room.Type == "DrillBay" then
			n += 1
		end
	end
	return n
end

local function sight(): number
	return Modifiers.ClassValue(player:GetAttribute("Class") :: string?, "OreSightCells") or 0
end

local function eraNumber(): number
	return table.find(Config.Ids("Eras"), RunState.Get("Era") or "") or 1
end

local function currentBunker(): any
	local Bunker = require(Shared.Rules.Bunker)
	return Bunker.FromSnapshot(replica:All("Cells"), replica:All("Rooms"))
end

local FEATURE_NOTES = {
	CaveOpening = { Title = "Cave opening", Text = "A way into the Deep (the caves open later): monsters can break in through it, so nothing is built here." },
	Cache = { Title = "Cache", Text = "A crate dug up with the rock: hold Interact at it to open it for the team." },
	Nest = { Title = "Nest", Text = "Monsters came out of it and more will: it raises Disturbance every cycle. Destroy it; it pays well." },
}

local function notes(floor: number, column: number, state: string): { any }
	local list = {}
	if state == "Dug" then
		local f = featureAt(floor, column)
		local note = f and FEATURE_NOTES[f.Kind]
		if note then
			table.insert(list, note)
		end
		return list
	end
	local site = siteAt(floor, column)
	local limit = RunState.Get("DigLimit") or Dig.StartLimit()
	local seconds = Dig.Seconds(floor)
	table.insert(list, { Title = "Dig time", Text = `{seconds} s for one player with a Drill or a Pickaxe (hold Interact at its face); players on one cell add up, the Driller digs twice as fast.` })
	if site and (site.Progress or 0) > 0 then
		table.insert(list, { Title = "Dug so far", Text = `{math.floor((site.Progress or 0) * 100)}%{if (site.Diggers or 0) > 0 then ` · {site.Diggers} digging` else ""}{if site.Bay then " · the Drill Bay is on it" else ""}.` })
	end
	if site and site.Queue then
		table.insert(list, { Title = "Dig queue", Text = if drillBays() > 0
			then `Number {site.Queue} on the Drill Bay's queue.`
			else `Number {site.Queue} on the queue: build a Drill Bay to dig it.` })
	end
	if Dig.NeedsVote(floor, limit) then
		table.insert(list, { Title = "Push Deeper", Text = `Past floor {limit}: trying to dig it asks the team to push deeper (a vote).` })
	end
	local reach = sight()
	if reach > 0 then
		local depth = Dig.Depth(currentBunker(), floor, column, reach)
		local seed = RunState.Get("DigSeed")
		if depth and type(seed) == "number" then
			local hint = Dig.Hint(seed, floor, column, eraNumber(), AVAILABLE, Dig.DecodeOverrides(RunState.Get("DigOverrides")))
			table.insert(list, { Title = "Driller's eye", Text = if hint == "OrePocket" then "An ore pocket is in this rock."
				elseif hint == "CaveOpening" then "A cave lies behind this rock."
				else "No ore or cave here." })
		end
	end
	return list
end

local function options(floor: number, column: number): { any }
	local site = siteAt(floor, column)
	if site and site.Queue then
		return { { Name = "Take off the dig queue", Value = `NUMBER {site.Queue}`, Choice = {
			Action = "UnmarkDig", Floor = floor, Column = column, Label = "Take off the queue" } } }
	end
	return { { Name = "Queue for the Drill Bay", Value = if drillBays() > 0 then "RESIDENTS DIG IT" else "NEEDS A DRILL BAY", Choice = {
		Action = "MarkDig", Floor = floor, Column = column, Label = "Queue for the Drill Bay" } } }
end

-- Lifecycle ----------------------------------------------------------------------------------------------------

function DigController:Init(registry)
	replica = registry.ReplicaController
	commandView = registry.CommandViewController
	camera = registry.CameraController
end

function DigController:Start()
	commandView:SetCellNotes(notes)
	commandView:SetRockOptions(options)
	commandView:SetHandler("MarkDig", function(choice: any)
		Remotes.FireServer("MarkDig", choice.Floor, choice.Column, true)
	end)
	commandView:SetHandler("UnmarkDig", function(choice: any)
		Remotes.FireServer("MarkDig", choice.Floor, choice.Column, false)
	end)
	replica:Changed("Digs"):Connect(function()
		local ok, err = pcall(syncDust)
		if not ok then
			log:Warn("dust: %s", tostring(err))
		end
		commandView:Refresh()
	end)
	replica:Changed("Cells"):Connect(onCells)
	if replica:IsReady() then
		burstsFrom = os.clock()
	else
		replica:Ready():Connect(function()
			burstsFrom = os.clock() + 1
		end)
	end
	RunState.Changed("TremorAt"):Connect(function()
		camera:Shake(2.2, 1.6)
	end)
	RunState.Changed("DigLimit"):Connect(function()
		commandView:Refresh()
	end)

	-- the dig prompts live in workspace.Bunker.Digging
	local function watchFolder(folder: Instance)
		for _, item in folder:GetDescendants() do
			gate(item)
		end
		folder.DescendantAdded:Connect(gate)
	end
	task.spawn(function()
		local bunker = workspace:WaitForChild("Bunker", 60)
		if not bunker then
			return
		end
		local existing = bunker:FindFirstChild("Digging")
		if existing then
			watchFolder(existing)
		end
		bunker.ChildAdded:Connect(function(child: Instance)
			if child.Name == "Digging" then
				watchFolder(child)
			end
		end)
	end)
	for _, name in { "Item1", "Item2", "Item3", "Item4", "Item5", "MeleeItem" } do
		player:GetAttributeChangedSignal(name):Connect(regate)
	end
	-- dust follows prompts that come and go
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= 1 then
			acc = 0
			pcall(syncDust)
		end
	end)
	log:Debug("digging display ready")
end

return DigController
