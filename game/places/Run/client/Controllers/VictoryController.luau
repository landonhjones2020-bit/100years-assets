--!strict
--[[
	VictoryController: the moment of a victory, before the run report opens (bible Section 5;
	Prompt 25). Run place only. RunDirector decides the outcome; this shows it.

	* Century Victory ("The blast door opens on a clearing sky."): the camera stands in the Blast
	  Door hall, the door's leaves lift, daylight pours in over the floor and the picture goes up
	  into the sky's white.
	* Deep Victory ("destroy the Source in its chamber"): the camera stands in front of the Source
	  as it dies (BossService plays its Death clip and DeepService takes its light out of the
	  rock), pushing in, and the picture goes down into the dark.
	* On screen (StarterGui.Victory, studio/ui/Victory.lua): letterbox bars, the card with the
	  year, the victory's name and its line typed out, the wash. The HUD is hidden and the camera
	  held for Tuning.Results.VictoryDelaySeconds; then ResultsController opens the report and this
	  lets go. It also lets go at once if the run carries on (Keep Going) or the player has no
	  character to stand anywhere.
	Everything it moves in the world is this client's own copy (the door's leaves, a card of sky,
	a lamp): nothing replicates, and it is all put back.

	Dev (client): `victory.play [century|deep]` plays the moment without ending the run.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Log = require(Shared.Utilities.Log)
local RunState = require(Shared.RunState)

local log = Log.new("VictoryController")
local player = Players.LocalPlayer

local VictoryController = {
	Name = "VictoryController",
	Dependencies = { "HUDController", "CameraController", "ReplicaController", "DevController" },
}

local hud: any = nil
local camera: any = nil
local replica: any = nil

local REASON = "Victory"
local SKY = Color3.fromRGB(255, 246, 228)
local DARK = Color3.fromRGB(8, 18, 12)
local WORDS: { [string]: { Title: string, Line: string } } = {
	Century = { Title = "CENTURY VICTORY", Line = "The blast door opens on a clearing sky." },
	Deep = { Title = "DEEP VICTORY", Line = "The Source is destroyed in its chamber." },
}

local playing = false
local token = 0
local undo: { () -> () } = {}

local function gui(): ScreenGui?
	local found = player:WaitForChild("PlayerGui"):FindFirstChild("Victory")
	return if found and found:IsA("ScreenGui") then found else nil
end

local function tween(object: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	TweenService:Create(object, TweenInfo.new(seconds, style or Enum.EasingStyle.Sine, Enum.EasingDirection.Out), goal):Play()
end

-- The Blast Door's room: where its door stands (the kit's Door socket), which way the hall lies
-- from it, and the leaves that close it.
local function blastDoor(): (Vector3?, Vector3?, BasePart?)
	local bunker = workspace:FindFirstChild("Bunker")
	local rooms = bunker and bunker:FindFirstChild("Rooms")
	if not rooms then
		return nil, nil, nil
	end
	for _, room in rooms:GetChildren() do
		if room:IsA("Model") and room:GetAttribute("RoomType") == "BlastDoor" then
			local middle = room:GetBoundingBox().Position
			for _, d in room:GetDescendants() do
				local socket = d:GetAttribute("Socket_Door")
				if d:IsA("Model") and typeof(socket) == "CFrame" then
					local at = (d:GetPivot() * socket).Position
					local leaves = d:FindFirstChild("Leaves", true)
					-- the door is in the hall's back wall: the hall lies towards the room's middle
					local inward = Vector3.new(0, 0, if middle.Z >= at.Z then 1 else -1)
					return at, inward, if leaves and leaves:IsA("BasePart") then leaves else nil
				end
			end
		end
	end
	return nil, nil, nil
end

-- The Source where it is dying: the boss's model in workspace.Monsters.
local function source(): Model?
	local monsters = workspace:FindFirstChild("Monsters")
	if not monsters then
		return nil
	end
	for _, model in monsters:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("Boss") == "Source" and model:GetAttribute("Tendril") == nil then
			return model
		end
	end
	return nil
end

local function local_(part: Part, cframe: CFrame, size: Vector3, color: Color3, material: Enum.Material): Part
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = material
	part.Color = color
	part.Size = size
	part.CFrame = cframe
	part.Parent = workspace.CurrentCamera or workspace
	table.insert(undo, function()
		part:Destroy()
	end)
	return part
end

-- The shot for a victory: where the camera starts and ends and what it looks at; nil when the
-- place it needs isn't there (the moment is then the card alone, over the player's own view).
local function centuryShot(seconds: number): (CFrame?, CFrame?)
	local at, inward, leaves = blastDoor()
	if not at or not inward then
		return nil, nil
	end
	local right = inward:Cross(Vector3.yAxis)
	local open = at + Vector3.new(0, 5.5, 0) -- the middle of the doorway
	local behind = at - inward * 3.4
	if leaves then
		local home = leaves.CFrame
		open = Vector3.new(leaves.Position.X, leaves.Position.Y, at.Z)
		behind = leaves.Position - inward * 1.1
		table.insert(undo, function()
			leaves.CFrame = home
		end)
		task.delay(0.9, function()
			if playing then
				tween(leaves, seconds * 0.5, { CFrame = home + Vector3.new(0, leaves.Size.Y + 1.5, 0) }, Enum.EasingStyle.Quad)
			end
		end)
	end
	-- the sky behind the leaves, and its light over the hall's floor
	local sky = local_(Instance.new("Part"), CFrame.lookAt(behind, behind + inward),
		Vector3.new(if leaves then leaves.Size.X + 0.6 else 14.5, if leaves then leaves.Size.Y + 0.6 else 11.6, 0.4),
		Color3.fromRGB(214, 236, 255), Enum.Material.Neon)
	local lamp = Instance.new("SpotLight")
	lamp.Face = Enum.NormalId.Front
	lamp.Angle = 110
	lamp.Range = 60
	lamp.Color = Color3.fromRGB(255, 240, 208)
	lamp.Brightness = 0
	lamp.Shadows = true
	lamp.Parent = sky
	task.delay(0.9, function()
		if playing then
			tween(lamp, seconds * 0.55, { Brightness = 9 }, Enum.EasingStyle.Quad)
		end
	end)
	local from = CFrame.lookAt(at + inward * 27 + right * 8 + Vector3.new(0, 6, 0), open + Vector3.new(0, 0.5, 0))
	local to = CFrame.lookAt(at + inward * 17 + right * 2.5 + Vector3.new(0, 4.5, 0), open + Vector3.new(0, 1.5, 0))
	return from, to
end

local function deepShot(): (CFrame?, CFrame?)
	local model = source()
	if not model then
		return nil, nil
	end
	local pivot = model:GetPivot()
	local eye = pivot * Vector3.new(0, 6, 0)
	local from = CFrame.lookAt(pivot * Vector3.new(11, 10, -42), eye)
	local to = CFrame.lookAt(pivot * Vector3.new(5, 7, -27), eye)
	return from, to
end

local function stop()
	if not playing then
		return
	end
	playing = false
	token += 1
	RunService:UnbindFromRenderStep("VictoryShot")
	for i = #undo, 1, -1 do
		local ok, err = pcall(undo[i])
		if not ok then
			log:Warn("putting things back: %s", tostring(err))
		end
	end
	table.clear(undo)
	camera:Resume(REASON)
	hud:Hide(REASON, false)
	local screen = gui()
	if screen then
		screen.Enabled = false
	end
end

local function play(kind: string, seconds: number)
	local words = WORDS[kind]
	local screen = gui()
	if not words or playing then
		return
	end
	playing = true
	token += 1
	local mine = token
	hud:Hide(REASON, true)
	local from: CFrame?, to: CFrame? = nil, nil
	if kind == "Century" then
		from, to = centuryShot(seconds)
	else
		from, to = deepShot()
	end
	if from and to then
		camera:Suspend(REASON)
		local view = workspace.CurrentCamera
		local started = os.clock()
		local shotFrom, shotTo = from, to
		RunService:BindToRenderStep("VictoryShot", Enum.RenderPriority.Camera.Value + 2, function()
			if view then
				local k = math.clamp((os.clock() - started) / seconds, 0, 1)
				local eased = k * k * (3 - 2 * k)
				view.CameraType = Enum.CameraType.Scriptable
				view.CFrame = shotFrom:Lerp(shotTo, eased)
				view.FieldOfView = 62 - 8 * eased
			end
		end)
		table.insert(undo, function()
			if view then
				view.FieldOfView = 70
			end
		end)
	end
	if screen then
		local top, bottom = screen:FindFirstChild("Top"), screen:FindFirstChild("Bottom")
		local wash, card = screen:FindFirstChild("Wash"), screen:FindFirstChild("Card")
		if top and bottom and wash and card and top:IsA("Frame") and bottom:IsA("Frame") and wash:IsA("Frame") and card:IsA("ImageLabel") then
			top.AnchorPoint, bottom.AnchorPoint = Vector2.new(0, 1), Vector2.new(0, 0)
			wash.BackgroundColor3 = if kind == "Century" then SKY else DARK
			wash.BackgroundTransparency = 1
			card.Visible = false
			screen.Enabled = true
			tween(top, 0.6, { AnchorPoint = Vector2.new(0, 0) })
			tween(bottom, 0.6, { AnchorPoint = Vector2.new(0, 1) })
			local title, line, kicker = card:FindFirstChild("Title"), card:FindFirstChild("Line"), card:FindFirstChild("Kicker")
			if title and title:IsA("TextLabel") then
				title.Text = words.Title
			end
			if kicker and kicker:IsA("TextLabel") then
				local year = RunState.Get("Year")
				kicker.Text = if kind == "Century" then "YEAR 100 · THE BUNKER HELD" else `YEAR {if type(year) == "number" then year else 1} · FLOOR 10`
			end
			if line and line:IsA("TextLabel") then
				line.Text = ""
			end
			task.delay(1.1, function()
				if token ~= mine then
					return
				end
				card.Visible = true
				local scale = card:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
				scale.Scale = 1.16
				scale.Parent = card
				tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
				-- the line types itself out
				if line and line:IsA("TextLabel") then
					for i = 1, #words.Line do
						if token ~= mine then
							return
						end
						line.Text = string.sub(words.Line, 1, i)
						task.wait(0.035)
					end
				end
			end)
			task.delay(seconds * 0.62, function()
				if token == mine then
					tween(wash, seconds * 0.36, { BackgroundTransparency = if kind == "Century" then 0.04 else 0.1 })
				end
			end)
		end
	end
	log:Info("%s Victory", kind)
end

local function consider()
	local outcome = RunState.Get("Outcome")
	if RunState.Get("RunPhase") == "Ended" and (outcome == "CenturyVictory" or outcome == "DeepVictory") then
		local seconds = Config.Get("Tuning", "Results").VictoryDelaySeconds
		play(if outcome == "CenturyVictory" then "Century" else "Deep", seconds)
		local mine = token
		task.delay(seconds + 0.4, function()
			if token == mine then
				stop() -- the report is open over it
			end
		end)
	else
		stop()
	end
end

function VictoryController:Init(registry)
	hud = registry.HUDController
	camera = registry.CameraController
	replica = registry.ReplicaController
	registry.DevController:Register("victory.play", function(args: { any }): string?
		local kind = if string.lower(tostring(args[1] or "century")) == "deep" then "Deep" else "Century"
		stop()
		local seconds = Config.Get("Tuning", "Results").VictoryDelaySeconds
		play(kind, seconds)
		local mine = token
		task.delay(seconds + 0.4, function()
			if token == mine then
				stop()
			end
		end)
		return `{kind} Victory's moment, {seconds} s`
	end)
end

function VictoryController:Start()
	if Constants.PlaceKind() ~= "Run" then
		return
	end
	RunState.Changed("RunPhase"):Connect(consider)
	RunState.Changed("Outcome"):Connect(consider)
	if replica:IsReady() then
		consider()
	else
		replica:Ready():Connect(consider)
	end
end

return VictoryController
