--!strict
--[[
	CutsceneController: the intro cutscene (bible Section 4; Prompt 22). "Every run opens with a
	30-second cutscene played live in the engine, starring the party's own avatars, and its last
	shot hands control straight to the players." Run place only.

	The whole cutscene is a function of one number, the seconds since it began: every frame the
	camera, the runners, the door, the bomb, the blast, the light and the words are set from that
	number (Shared.Rules.Cutscene and the two data modules, Config.CutscenePaths made in Blender
	and Config.Cutscenes). Nothing is fired off and left to run, so:
	* it follows the run's clock: RunDirector's Intro phase ends at IntroEndsAt on the server, and
	  the seconds are counted back from that, so the cutscene ends as the run starts whatever the
	  frame rate, and a player who arrives a few seconds late joins it at the right moment;
	* a dev command can stop it at any second for a capture (`cutscene.at`).

	What it does:
	* The set. A copy of ReplicatedStorage.CutsceneSet (CutsceneService) is put up at
	  Tuning.Cutscene.SetOrigin, far above the run's world, for this client only, and taken down
	  when the cutscene ends. The rock above the bunker and the Source's hollow are stood in front
	  of the run's real bunker for the plunge.
	* The camera plays the keys shot by shot. Shots in the "Bunker" space run in front of the real
	  bunker, shown as the Command View shows it (CommandViewController:Present). The last shot is
	  ended here: it settles into the Command View's pose over the player's own character, then
	  the over-the-shoulder camera is switched back on and the picture is blended down to it, so
	  the move ends exactly where the player's own camera is.
	* The runners: each party member's avatar is rebuilt from their avatar description (a copy of
	  their character if that fails or is slow), this player's own first, then the six founders
	  (copies of the residents' models). They sprint along RunPath, each in its place in the pack.
	* The blast: the door's leaves, the bomb and its trail, the flash, the fireball, the cloud, the
	  ring, every building, tree and car going over as the ring reaches it, the dust.
	* On screen (StarterGui.CutsceneBars and Cutscene): letterbox bars, the radio bulletin, the
	  title and its line, Skip. Everything else is hidden: the HUD, the screens (UIController:Lock),
	  Roblox's chat and menus, the touch controls. The character is held still.
	* Skip (Section 4): not on an account's first run (the player's IntroFirstRun attribute); after
	  Clock.IntroSkipAfterSeconds otherwise. A click or a tap skips; the key (Space, or B on a
	  controller) is held for Tuning.Cutscene.SkipHoldSeconds. Skipping is this player's own: the
	  run's clock starts at the 30-second mark for everyone, so a plate counts down to it.

	Dev (client): `cutscene` (state), `cutscene.play [from]`, `cutscene.at <seconds>` (hold a
	moment), `cutscene.stop`, `cutscene.skip`, `cutscene.comfort [flash] [shake]` (true or false).
]]

local ContentProvider = game:GetService("ContentProvider")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Utilities.Log)
local RunState = require(Shared.RunState)
local Signal = require(Shared.Utilities.Signal)
local Cutscene = require(Shared.Rules.Cutscene)
local Grid = require(Shared.Rules.Grid)
local Lib = script.Parent.Parent:WaitForChild("Lib")
local KitRuntime = require(Lib:WaitForChild("KitRuntime"))

local log = Log.new("CutsceneController")

local REASON = "Cutscene"
local RENDER_NAME = "100Y_Cutscene"
local RENDER_PRIORITY = Enum.RenderPriority.Camera.Value + 5 -- after the player's camera: the hand-over reads it
local HOLD_ACTION = "100Y_CutsceneHold"
local SKIP_ACTION = "100Y_CutsceneSkip"
local SET_NAME = "CutsceneSet"
local DEFAULT_RUN = "rbxassetid://913376220" -- Roblox's own R15 run, until the art's sprint is in Config.Animations
local CORE_GUI = { Enum.CoreGuiType.Chat, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.EmotesMenu, Enum.CoreGuiType.Health }
-- What the Run place still has from its first days, standing where the plunge's camera looks: the
-- template's baseplate and spawn pad and the style test's room (workspace, around the origin).
local LEFTOVERS = { "Baseplate", "SpawnLocation", "A0_Showroom" }
local TITLE_SCRIM = 0.5 -- how dark the picture stays behind the title card
local SEALED_OFF, SEALED_ON = Color3.fromHex("#3A1E18"), Color3.fromHex("#FF4A2A")
local BEACON_DIM, BEACON_LIT = Color3.fromHex("#8A6A20"), Color3.fromHex("#FFC83A")

local CutsceneController = {
	Name = "CutsceneController",
	Dependencies = { "InputController", "CameraController", "UIController", "HUDController", "CommandViewController", "DevController" },
	Finished = Signal.new() :: Signal.Signal<boolean>, -- true: the player skipped it
}

type Lamp = { Part: BasePart, Color: Color3 }
type Piece = {
	Model: Model, Kind: string, Rest: CFrame, Away: Vector3, Arrival: number, Height: number, Seed: number,
	Hidden: { BasePart }?, Lamps: { Lamp }, Dark: boolean?,
}
type Runner = {
	Model: Model, Root: BasePart, Lift: number, Animator: Animator?, Track: AnimationTrack?, Tried: boolean, Running: boolean, Shown: boolean,
	Own: boolean, -- its clip is the art's sprint, made for the run's speed (false: Roblox's run, sped up, the body leant by hand)
}
type Door = { Model: Model, Travel: number, Right: Vector3, Parts: { [string]: BasePart }, Rest: { [string]: CFrame }, Sealed: boolean?, Lit: boolean? }
type World = {
	Set: Model,
	Origin: CFrame,
	Pieces: { Piece },
	Door: Door?,
	Bomb: Model?,
	BombRest: CFrame?,
	Fireball: BasePart?,
	Trail: { BasePart },
	Ash: BasePart?,
	Cloud: Model?,
	CloudParts: { [string]: BasePart },
	CloudRest: { [string]: { CFrame: CFrame, Size: Vector3 } },
	Ring: BasePart?,
	Strata: Model?,
	Source: Model?,
	Eyes: { { Part: BasePart, Size: Vector3, Order: number } }, -- Order: the number in its name; an eye and its pupil share it
	Runners: { Runner },
	Loaded: boolean,
	RevealedAt: number?, -- os.clock() when the picture began to come up out of black
}

local input: any = nil
local cameraController: any = nil
local ui: any = nil
local hud: any = nil
local commandView: any = nil
local dev: any = nil

local tuning: any = nil
local path: Cutscene.Path = nil :: any
local words: any = nil
local skipAfter = 2

local playing = false
local live = false -- following the run's clock (false: a dev replay on this client's own clock)
local devAt = 0 -- a dev replay: the cutscene's second at devFrom
local devFrom = 0
local devHeld = false
local world: World? = nil
local lookBefore: { [string]: any }? = nil
local made: { Instance } = {} -- Lighting instances this made (Clouds, ColorCorrection)
local presented = false
local resumed = false -- the player's camera has been switched back on for the hand-over
local hidden: { BasePart } = {} -- the place's own leftovers, hidden while the camera passes the bunker
local coreBefore: { [Enum.CoreGuiType]: boolean } = {}
local touchBefore: boolean? = nil
local skipHeldFor = 0
local skipHeld = false
local skipped = false
local waiting = false -- skipped: the plate counts down to the run
local lastT = 0
local startedClock = 0 -- os.clock() when this playing began
local bulletinReady = false
local lastShot = ""
-- Bible Section 18: "screen shake and flashing can be turned off". The Settings screen (a later
-- prompt) calls SetComfort; until then both are on.
local flashing = true
local shaking = true

-- The screen -------------------------------------------------------------------------------------

local function gui(name: string): ScreenGui?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local found = playerGui and playerGui:FindFirstChild(name)
	return if found and found:IsA("ScreenGui") then found else nil
end

local function find(root: Instance?, pathTo: string): any
	local node: Instance? = root
	for name in string.gmatch(pathTo, "[^%.]+") do
		node = if node then node:FindFirstChild(name) else nil
	end
	return node
end

local function barsPart(pathTo: string): any
	return find(gui("CutsceneBars"), pathTo)
end

local function screenPart(pathTo: string): any
	return find(gui("Cutscene"), pathTo)
end

-- The clock --------------------------------------------------------------------------------------

local function seconds(): number
	if live then
		local left = RunState.TimeLeft()
		if RunState.Get("RunPhase") ~= "Intro" or left == nil then
			return path.Seconds
		end
		return Cutscene.Elapsed(path.Seconds, left)
	end
	return if devHeld then devAt else devAt + (os.clock() - devFrom)
end

-- The player -------------------------------------------------------------------------------------

local function holdCharacter(on: boolean)
	if not on then
		ContextActionService:UnbindAction(HOLD_ACTION)
		if touchBefore ~= nil then
			GuiService.TouchControlsEnabled = touchBefore
			touchBefore = nil
		end
		return
	end
	if touchBefore == nil then
		touchBefore = GuiService.TouchControlsEnabled
	end
	GuiService.TouchControlsEnabled = false
	ContextActionService:BindActionAtPriority(HOLD_ACTION, function()
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 40,
		Enum.PlayerActions.CharacterForward, Enum.PlayerActions.CharacterBackward,
		Enum.PlayerActions.CharacterLeft, Enum.PlayerActions.CharacterRight, Enum.PlayerActions.CharacterJump,
		Enum.KeyCode.Thumbstick1)
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:Move(Vector3.zero)
	end
end

local function hideCore(on: boolean)
	if on then
		for _, kind in CORE_GUI do
			local ok, was = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, kind)
			coreBefore[kind] = if ok then was else true
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, kind, false)
		end
	else
		for kind, was in coreBefore do
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, kind, was)
		end
		table.clear(coreBefore)
	end
	pcall(StarterGui.SetCore, StarterGui, "TopbarEnabled", not on)
end

local function hideLeftovers(on: boolean)
	if not on then
		for _, part in hidden do
			part.LocalTransparencyModifier = 0
		end
		table.clear(hidden)
		return
	end
	if #hidden > 0 then
		return
	end
	for _, name in LEFTOVERS do
		local item = workspace:FindFirstChild(name)
		if item then
			for _, part in if item:IsA("BasePart") then { item } else item:GetDescendants() do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = 1
					table.insert(hidden, part)
				end
			end
		end
	end
end

local function characterRoot(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- The light --------------------------------------------------------------------------------------

local LOOK_NUMBERS = {
	ClockTime = "ClockTime", GeographicLatitude = "GeographicLatitude", Brightness = "Brightness",
	Exposure = "ExposureCompensation", EnvironmentDiffuse = "EnvironmentDiffuseScale", EnvironmentSpecular = "EnvironmentSpecularScale",
}
local LOOK_COLOURS = { Ambient = "Ambient", OutdoorAmbient = "OutdoorAmbient", ColorShiftTop = "ColorShift_Top" }

local function atmosphere(): Atmosphere?
	return Lighting:FindFirstChildOfClass("Atmosphere")
end

local function bloom(): BloomEffect?
	return Lighting:FindFirstChildOfClass("BloomEffect")
end

local function captureLook()
	if lookBefore then
		return
	end
	local before: { [string]: any } = {}
	for _, property in LOOK_NUMBERS do
		before[property] = (Lighting :: any)[property]
	end
	for _, property in LOOK_COLOURS do
		before[property] = (Lighting :: any)[property]
	end
	local atmo = atmosphere()
	if atmo then
		before.Atmosphere = { Density = atmo.Density, Offset = atmo.Offset, Color = atmo.Color, Decay = atmo.Decay, Glare = atmo.Glare, Haze = atmo.Haze }
	end
	local glow = bloom()
	if glow then
		before.Bloom = { Intensity = glow.Intensity, Size = glow.Size, Threshold = glow.Threshold }
	end
	lookBefore = before
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if not clouds then
		local sky = Instance.new("Clouds")
		sky.Name = "CutsceneClouds"
		sky.Density = 0.55
		sky.Cover = 0
		sky.Parent = workspace.Terrain
		table.insert(made, sky)
	end
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "CutsceneGrade"
	grade.Parent = Lighting
	table.insert(made, grade)
end

local function restoreLook()
	local before = lookBefore
	if not before then
		return
	end
	lookBefore = nil
	for _, property in LOOK_NUMBERS do
		(Lighting :: any)[property] = before[property]
	end
	for _, property in LOOK_COLOURS do
		(Lighting :: any)[property] = before[property]
	end
	local atmo = atmosphere()
	if atmo and before.Atmosphere then
		for property, value in before.Atmosphere do
			(atmo :: any)[property] = value
		end
	end
	local glow = bloom()
	if glow and before.Bloom then
		for property, value in before.Bloom do
			(glow :: any)[property] = value
		end
	end
	for _, item in made do
		item:Destroy()
	end
	table.clear(made)
end

local function mixNumber(a: number, b: number, f: number): number
	return a + (b - a) * f
end

local function mixHex(a: string, b: string, f: number): Color3
	return Color3.fromHex(a):Lerp(Color3.fromHex(b), f)
end

-- The look at t: the two keys around it, blended.
local function applyLook(t: number)
	captureLook()
	local keys = words.LookKeys
	local from, to = keys[1], keys[1]
	for i, key in keys do
		if key.At <= t then
			from = key
			to = keys[i + 1] or key
		end
	end
	local f = if to.At > from.At and not to.Cut then math.clamp((t - from.At) / (to.At - from.At), 0, 1) else 0
	local fromLook, toLook = from.Look, to.Look
	if not flashing then -- no burst of light: straight from the morning to the blast's own light
		fromLook = if fromLook == "Flash" then "Blast" else fromLook
		toLook = if toLook == "Flash" then "Blast" else toLook
	end
	local a, b = words.Looks[fromLook], words.Looks[toLook]
	for field, property in LOOK_NUMBERS do
		(Lighting :: any)[property] = mixNumber(a[field], b[field], f)
	end
	for field, property in LOOK_COLOURS do
		(Lighting :: any)[property] = mixHex(a[field], b[field], f)
	end
	local atmo = atmosphere()
	if atmo then
		atmo.Density = mixNumber(a.AtmosphereDensity, b.AtmosphereDensity, f)
		atmo.Offset = mixNumber(a.AtmosphereOffset, b.AtmosphereOffset, f)
		atmo.Color = mixHex(a.AtmosphereColor, b.AtmosphereColor, f)
		atmo.Decay = mixHex(a.AtmosphereDecay, b.AtmosphereDecay, f)
		atmo.Glare = mixNumber(a.AtmosphereGlare, b.AtmosphereGlare, f)
		atmo.Haze = mixNumber(a.AtmosphereHaze, b.AtmosphereHaze, f)
	end
	local glow = bloom()
	if glow then
		glow.Intensity = mixNumber(a.BloomIntensity, b.BloomIntensity, f)
		glow.Size = mixNumber(a.BloomSize, b.BloomSize, f)
		glow.Threshold = mixNumber(a.BloomThreshold, b.BloomThreshold, f)
	end
	local clouds = workspace.Terrain:FindFirstChild("CutsceneClouds")
	if clouds and clouds:IsA("Clouds") then
		clouds.Cover = mixNumber(a.CloudCover, b.CloudCover, f)
		clouds.Color = mixHex(a.CloudColor, b.CloudColor, f)
	end
	local grade = Lighting:FindFirstChild("CutsceneGrade")
	if grade and grade:IsA("ColorCorrectionEffect") then
		grade.TintColor = mixHex(a.Tint, b.Tint, f)
		grade.Saturation = mixNumber(a.Saturation, b.Saturation, f)
		grade.Contrast = mixNumber(a.Contrast, b.Contrast, f)
	end
end

-- The set ----------------------------------------------------------------------------------------

local function setCFrame(): CFrame
	local o = tuning.SetOrigin
	return CFrame.new(o.X, o.Y, o.Z)
end

local function gridCFrame(): CFrame
	return CFrame.new(Grid.CellPosition(1, 0))
end

local function anchor(name: string): Vector3
	local p = path.Anchors[name]
	return Vector3.new(p[1], p[2], p[3])
end

local function quiet(root: Instance)
	for _, item in root:GetDescendants() do
		if item:IsA("BasePart") then
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
		end
	end
end

local function baseParts(root: Instance): { BasePart }
	local parts = {}
	for _, item in root:GetDescendants() do
		if item:IsA("BasePart") then
			table.insert(parts, item)
		end
	end
	return parts
end

-- A runner's model made ready: no scripts, nothing touches it, its root held, an Animator to
-- play the sprint on. Lift is its root's height above its feet.
local function readyRunner(model: Model): Runner?
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	for _, item in model:GetDescendants() do
		if item:IsA("BaseScript") or item:IsA("ForceField") or item:IsA("BillboardGui") or item:IsA("ProximityPrompt") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = item == root
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.Massless = true
		end
	end
	for _, item in model:GetDescendants() do
		if item:IsA("AnimationConstraint") then
			pcall(function()
				(item :: any).IsKinematic = true -- follows the held root exactly, as a Motor6D would
			end)
		end
	end
	local lift = 3
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.EvaluateStateMachine = false
		humanoid.BreakJointsOnDeath = false
		lift = humanoid.HipHeight + root.Size.Y / 2
		if humanoid.RigType == Enum.HumanoidRigType.R6 then
			lift = 3
		end
	end
	local animator: Animator? = model:FindFirstChildWhichIsA("Animator", true)
	if not animator then
		local made_ = Instance.new("Animator")
		made_.Parent = humanoid or model
		animator = made_
	end
	model.Name = "Runner"
	return { Model = model, Root = root, Lift = lift, Animator = animator, Track = nil, Tried = false, Running = false, Shown = false, Own = false }
end

-- The sprint, loaded the first time the runner stands in the world: a clip loaded on an Animator
-- that is not in workspace yet never gets its keys (it "plays" with no length and no weight).
local function sprintTrack(runner: Runner): AnimationTrack?
	if runner.Track or runner.Tried then
		return runner.Track
	end
	local animator = runner.Animator
	if not animator or not animator:IsDescendantOf(workspace) then
		return nil
	end
	runner.Tried = true
	local clip = Config.Find("Animations", "IntroSprint")
	local animation = Instance.new("Animation")
	animation.AnimationId = if clip then clip.AssetId else DEFAULT_RUN
	runner.Own = clip ~= nil
	local ok, loaded = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if ok and loaded then
		loaded.Looped = true
		loaded.Priority = Enum.AnimationPriority.Action
		runner.Track = loaded
	else
		log:Debug("no sprint for a runner: %s", tostring(loaded))
	end
	return runner.Track
end

local function copyOf(source: Model): Model?
	local was = source.Archivable
	source.Archivable = true
	local ok, copy = pcall(function()
		return source:Clone()
	end)
	source.Archivable = was
	return if ok and copy then copy else nil
end

-- The party's avatars and the founders, in the order they run: this player first.
local function castRunners(target: World)
	local slots = #path.Runners
	local players = { Players.LocalPlayer }
	for _, other in Players:GetPlayers() do
		if other ~= Players.LocalPlayer and #players < slots then
			table.insert(players, other)
		end
	end
	local function add(index: number, model: Model?)
		if world ~= target or not model then
			if model then
				model:Destroy()
			end
			return
		end
		local runner = readyRunner(model)
		if not runner then
			model:Destroy()
			return
		end
		local old = target.Runners[index]
		if old then
			old.Model:Destroy()
		end
		target.Runners[index] = runner
	end
	for index, player in players do
		-- a copy of the character at once, so there is someone to run; the avatar proper replaces it
		local character = player.Character
		if character then
			add(index, copyOf(character))
		end
		if player.UserId > 0 then -- a Studio test player has no avatar to ask for
			task.spawn(function()
				local began = os.clock()
				local ok, model = pcall(function()
					local description = Players:GetHumanoidDescriptionFromUserId(player.UserId)
					return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
				end)
				if ok and model and os.clock() - began <= tuning.AvatarSeconds then
					add(index, model)
				elseif ok and model then
					model:Destroy()
				elseif not ok then
					log:Debug("no avatar for %s from its description: %s", player.Name, tostring(model))
				end
			end)
		end
	end
	local index = #players
	local bunker = workspace:FindFirstChild("Bunker")
	local residents = bunker and bunker:FindFirstChild("Residents")
	if residents then
		local list = residents:GetChildren()
		table.sort(list, function(a, b)
			return a.Name < b.Name
		end)
		for _, resident in list do
			if index >= slots then
				break
			end
			if resident:IsA("Model") then
				index += 1
				add(index, copyOf(resident))
			end
		end
	end
end

local function build(): World?
	local source = ReplicatedStorage:WaitForChild(SET_NAME, 5)
	if not (source and source:IsA("Model")) then
		log:Warn("no %s in ReplicatedStorage: the cutscene has no set", SET_NAME)
		return nil
	end
	local origin = setCFrame()
	local set = source:Clone()
	local target: World = {
		Set = set, Origin = origin, Pieces = {}, Trail = {}, CloudParts = {}, CloudRest = {}, Eyes = {}, Runners = {}, Loaded = false,
	}
	local blast = anchor("Blast")
	local piecesFolder = set:FindFirstChild("Pieces")
	local groundFolder = set:FindFirstChild("Ground")
	local effects = set:FindFirstChild("Effects")
	-- the set was laid out around the world's origin: move it up to its place
	local function raise(folder: Instance?)
		if folder then
			for _, item in folder:GetChildren() do
				if item:IsA("PVInstance") then
					item:PivotTo(origin * item:GetPivot())
				end
			end
		end
	end
	raise(piecesFolder)
	raise(groundFolder)
	if piecesFolder then
		for _, model in piecesFolder:GetChildren() do
			if not model:IsA("Model") then
				continue
			end
			local kind = model:GetAttribute("Kind")
			if model.Name == "Door" then
				local door: Door = {
					Model = model,
					Travel = (model:GetAttribute("LeafTravel") :: number?) or 10.6,
					Right = model:GetPivot().RightVector,
					Parts = {},
					Rest = {},
				}
				for _, name in { "LeafLeft", "LeafRight", "Wheel", "BeaconLeft", "BeaconRight", "Sealed" } do
					local part = model:FindFirstChild(name, true)
					if part and part:IsA("BasePart") then
						door.Parts[name] = part
						door.Rest[name] = part.CFrame
					end
				end
				target.Door = door
			elseif type(kind) == "string" and kind ~= "Still" then
				local box, size = model:GetBoundingBox()
				local local_ = origin:PointToObjectSpace(box.Position)
				local flat = Vector3.new(local_.X - blast.X, 0, local_.Z - blast.Z)
				local piece: Piece = {
					Model = model,
					Kind = kind,
					Rest = model:GetPivot(),
					Away = if flat.Magnitude > 1 then flat.Unit else Vector3.xAxis,
					Arrival = Cutscene.WaveArrival(path, flat.Magnitude),
					Height = size.Y,
					Seed = ((model:GetAttribute("Index") :: number?) or 1) * 0.6180339 % 1,
					Lamps = {},
				}
				if kind == "Bunting" then
					piece.Hidden = baseParts(model)
				else
					for _, part in baseParts(model) do -- shop signs, street lamps, headlamps: out when the ring arrives
						if part.Material == Enum.Material.Neon then
							table.insert(piece.Lamps, { Part = part, Color = part.Color })
						end
					end
				end
				table.insert(target.Pieces, piece)
			end
		end
	end
	if effects then
		local bomb = effects:FindFirstChild("Cutscene_Bomb")
		if bomb and bomb:IsA("Model") then
			target.Bomb = bomb
			target.BombRest = bomb:GetPivot()
		end
		local cloud = effects:FindFirstChild("Cutscene_MushroomCloud")
		if cloud and cloud:IsA("Model") then
			cloud:PivotTo(origin * CFrame.new(blast))
			target.Cloud = cloud
			for _, part in baseParts(cloud) do
				target.CloudParts[part.Name] = part
				target.CloudRest[part.Name] = { CFrame = cloud:GetPivot():ToObjectSpace(part.CFrame), Size = part.Size }
			end
		end
		local ring = effects:FindFirstChild("Cutscene_Shockwave")
		local ringPart = ring and ring:FindFirstChildWhichIsA("BasePart", true)
		if ringPart then
			target.Ring = ringPart
		end
		local strata = effects:FindFirstChild("Cutscene_Strata")
		if strata and strata:IsA("Model") then
			strata:PivotTo(gridCFrame() * CFrame.new(anchor("StrataFoot")) * CFrame.Angles(0, math.pi, 0))
			target.Strata = strata
		end
		local hollow = effects:FindFirstChild("Cutscene_SourceGlimpse")
		if hollow and hollow:IsA("Model") then
			hollow:PivotTo(gridCFrame() * CFrame.new(anchor("Source")) * CFrame.Angles(0, math.pi, 0))
			target.Source = hollow
			for _, part in baseParts(hollow) do
				if string.sub(part.Name, 1, 3) == "Eye" then
					table.insert(target.Eyes, { Part = part, Size = part.Size, Order = tonumber(string.match(part.Name, "%d+")) or 1 })
				end
			end
		end
	end
	-- the fireball: a ball of light behind the cloud's foot
	local fireball = Instance.new("Part")
	fireball.Name = "Fireball"
	fireball.Shape = Enum.PartType.Ball
	fireball.Material = Enum.Material.Neon
	fireball.Color = Color3.fromHex("#FFE9A8")
	fireball.Anchored = true
	fireball.CastShadow = false
	fireball.Size = Vector3.one
	fireball.Transparency = 1
	fireball.Parent = set
	target.Fireball = fireball
	-- the bomb's vapour trail: a thin bright line behind it and a wider, fainter one further back
	for index, look in { { Width = 1.5, Transparency = 0.08 }, { Width = 3.4, Transparency = 0.5 } } do
		local trail = Instance.new("Part")
		trail.Name = "Trail" .. index
		trail.Shape = Enum.PartType.Cylinder
		trail.Material = Enum.Material.SmoothPlastic
		trail.Color = Color3.fromHex("#FFFFFF")
		trail.Anchored = true
		trail.CastShadow = false
		trail.Size = Vector3.new(1, look.Width, look.Width)
		trail.Transparency = look.Transparency
		trail.LocalTransparencyModifier = 1
		trail.Parent = set
		table.insert(target.Trail, trail)
	end
	-- ash and embers drifting past the camera once the dust has gone by
	local ash = Instance.new("Part")
	ash.Name = "Ash"
	ash.Anchored = true
	ash.Transparency = 1
	ash.CastShadow = false
	ash.Size = Vector3.new(150, 70, 110)
	for _, look in {
		{ Name = "Flakes", Color = Color3.fromHex("#3B3431"), Size = 0.36, Rate = 190, Speed = 9, Light = 0, Life = 5 },
		{ Name = "Embers", Color = Color3.fromHex("#FF8A3A"), Size = 0.22, Rate = 50, Speed = 5, Light = 1, Life = 3.5 },
	} do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = look.Name
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Color = ColorSequence.new(look.Color)
		emitter.Size = NumberSequence.new(look.Size)
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.1), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1) })
		emitter.Lifetime = NumberRange.new(look.Life * 0.7, look.Life)
		emitter.Rate = look.Rate
		emitter.Speed = NumberRange.new(look.Speed * 0.6, look.Speed)
		emitter.EmissionDirection = Enum.NormalId.Bottom
		emitter.SpreadAngle = Vector2.new(25, 25)
		emitter.Acceleration = Vector3.new(7, -2, 0) -- the wind off the blast
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-90, 90)
		emitter.LightEmission = look.Light
		emitter.LightInfluence = 1 - look.Light
		emitter.Shape = Enum.ParticleEmitterShape.Box
		emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		emitter.Enabled = false
		emitter.Parent = ash
	end
	ash.Parent = set
	target.Ash = ash
	quiet(set)
	set.Name = "CutsceneSet"
	set.Parent = workspace
	return target
end

local function preload(target: World)
	task.spawn(function()
		pcall(function()
			-- the screens too: an image in a ScreenGui that was never shown has not been fetched
			local list: { Instance } = { target.Set }
			for _, name in { "CutsceneBars", "Cutscene" } do
				local screen = gui(name)
				if screen then
					table.insert(list, screen)
				end
			end
			ContentProvider:PreloadAsync(list)
		end)
		target.Loaded = true
		target.RevealedAt = os.clock()
	end)
end

-- What moves ---------------------------------------------------------------------------------------

local function moveDoor(door: Door, t: number)
	local open = 1 - Cutscene.DoorShut(path, t)
	local slide = door.Right * door.Travel * open
	local left, right, wheel = door.Parts.LeafLeft, door.Parts.LeafRight, door.Parts.Wheel
	if left then
		left.CFrame = door.Rest.LeafLeft + slide
	end
	if right then
		right.CFrame = door.Rest.LeafRight - slide
	end
	if wheel then
		local turn = Cutscene.Smooth(Cutscene.Progress(path, "WheelFrom", "WheelTo", t)) * math.rad(540)
		local rest = door.Rest.Wheel
		local axis = rest:VectorToObjectSpace(door.Model:GetPivot().LookVector)
		wheel.CFrame = (rest - slide) * CFrame.fromAxisAngle(axis, turn)
	end
	local sealed = t >= Cutscene.Beat(path, "Sealed")
	local lamp = door.Parts.Sealed
	if lamp and door.Sealed ~= sealed then
		door.Sealed = sealed
		lamp.Material = if sealed then Enum.Material.Neon else Enum.Material.SmoothPlastic
		lamp.Color = if sealed then SEALED_ON else SEALED_OFF
	end
	-- the beacons flash while the leaves roll
	local rolling = t >= Cutscene.Beat(path, "DoorFrom") - 0.7 and t < Cutscene.Beat(path, "Sealed")
	local lit = rolling and (t * 5) % 1 < 0.5
	if door.Lit ~= lit then
		door.Lit = lit
		for _, name in { "BeaconLeft", "BeaconRight" } do
			local beacon = door.Parts[name]
			if beacon then
				beacon.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
				beacon.Color = if lit then BEACON_LIT else BEACON_DIM
			end
		end
	end
end

-- A piece of the town as the ring reaches it: buildings sink and lean away, trees and the water
-- tower go over, cars are thrown along the street, bunting is gone.
local function movePiece(piece: Piece, t: number, origin: CFrame)
	local since = t - piece.Arrival
	local kind = piece.Kind
	if kind == "Bunting" then
		local gone = since >= 0
		local parts = piece.Hidden
		if parts then
			for _, part in parts do
				part.LocalTransparencyModifier = if gone then 1 else 0
			end
		end
		return
	end
	local dark = since > 0
	if piece.Dark ~= dark then
		piece.Dark = dark
		for _, lamp in piece.Lamps do
			lamp.Part.Material = if dark then Enum.Material.SmoothPlastic else Enum.Material.Neon
			lamp.Part.Color = if dark then lamp.Color:Lerp(Color3.new(0, 0, 0), 0.72) else lamp.Color
		end
	end
	if since <= 0 then
		if piece.Model:GetPivot() ~= piece.Rest then
			piece.Model:PivotTo(piece.Rest)
		end
		return
	end
	local away = origin:VectorToWorldSpace(piece.Away)
	local rest = piece.Rest
	local axis = Vector3.yAxis:Cross(away) -- turning about it tips the top away from the blast
	if kind == "Block" then
		local f = Cutscene.Smooth(since / 0.55)
		local lean = math.rad(14 + 16 * piece.Seed) * f
		local sink = piece.Height * (0.5 + 0.2 * piece.Seed) * f
		piece.Model:PivotTo(CFrame.new(rest.Position - Vector3.yAxis * sink) * CFrame.fromAxisAngle(axis, lean) * rest.Rotation)
	elseif kind == "Car" then
		local f = 1 - (1 - math.clamp(since / 1.1, 0, 1)) ^ 2
		local slide = away * (26 + 30 * piece.Seed) * f
		local roll = math.rad(140 + 220 * piece.Seed) * f
		local hop = math.sin(f * math.pi) * (5 + 6 * piece.Seed)
		piece.Model:PivotTo(CFrame.new(rest.Position + slide + Vector3.yAxis * hop) * CFrame.fromAxisAngle(axis, roll) * rest.Rotation)
	else -- trees and the water tower
		local f = Cutscene.Smooth(since / 0.4)
		piece.Model:PivotTo(CFrame.new(rest.Position) * CFrame.fromAxisAngle(axis, math.rad(78 + 10 * piece.Seed) * f) * rest.Rotation)
	end
end

local function moveBlast(target: World, t: number)
	local origin = target.Origin
	local blast = origin * anchor("Blast")
	-- the bomb
	local bomb = target.Bomb
	if bomb then
		local at, direction = Cutscene.Bomb(path, t)
		if at then
			local position = origin * at
			bomb:PivotTo(CFrame.lookAt(position, position + origin:VectorToWorldSpace(direction)))
			if bomb.Parent ~= target.Set then
				bomb.Parent = target.Set
			end
		elseif bomb.Parent then
			bomb.Parent = nil
		end
		-- the trail: from where it came into the sky to its tail, the last stretch bright
		local from = origin * anchor("BombFrom")
		local tail = if at then origin * at else nil
		for index, trail in target.Trail do
			if not tail or (tail - from).Magnitude < 2 then
				trail.LocalTransparencyModifier = 1
				continue
			end
			local length = (tail - from).Magnitude
			local near = math.min(length, 110)
			local a = if index == 1 then tail + (from - tail).Unit * near else from
			local b = if index == 1 then tail else tail + (from - tail).Unit * near
			if (b - a).Magnitude < 1 then
				trail.LocalTransparencyModifier = 1
				continue
			end
			trail.LocalTransparencyModifier = 0
			trail.Size = Vector3.new((b - a).Magnitude, trail.Size.Y, trail.Size.Z)
			trail.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
		end
	end
	-- the fireball: swells, then dims into the cloud
	local fireball = target.Fireball
	if fireball then
		local swell = Cutscene.Smooth(Cutscene.Progress(path, "FireballFrom", "FireballTo", t) * 2.2)
		local dim = Cutscene.Smooth((t - Cutscene.Beat(path, "FireballTo") + 0.9) / 1.6)
		if t < Cutscene.Beat(path, "Flash") or dim >= 1 then
			fireball.Transparency = 1
		else
			local size = (40 + 110 * swell) * (1 - 0.35 * dim)
			fireball.Size = Vector3.one * size
			fireball.CFrame = CFrame.new(blast + Vector3.yAxis * (18 + 34 * swell))
			fireball.Transparency = dim * 0.9
			fireball.Color = Color3.fromHex("#FFF3CF"):Lerp(Color3.fromHex("#FF7A2E"), math.clamp(swell * 0.7 + dim, 0, 1))
		end
	end
	-- the cloud
	local cloud = target.Cloud
	if cloud then
		local state = Cutscene.CloudAt(path, t)
		local shown = t >= Cutscene.Beat(path, "CloudFrom")
		local base = CFrame.new(blast)
		local full = path.Cloud
		for name, part in target.CloudParts do
			local rest = target.CloudRest[name]
			part.LocalTransparencyModifier = if shown then 0 else 1
			if not shown then
				continue
			end
			local wide = state.CapRadius / full.CapRadius
			local tall = state.Top / full.Top
			if name == "Stem" or name == "StemGlow" then
				local thick = state.StemRadius / full.StemRadius
				part.Size = Vector3.new(rest.Size.X * thick, rest.Size.Y * tall, rest.Size.Z * thick)
				part.CFrame = base * CFrame.new(rest.CFrame.X * thick, rest.CFrame.Y * tall, rest.CFrame.Z * thick) * rest.CFrame.Rotation
			elseif name == "Base" then
				local spread = 0.5 + 0.5 * Cutscene.Smooth(state.Rise * 1.6)
				part.Size = Vector3.new(rest.Size.X * spread, rest.Size.Y * (0.6 + 0.4 * spread), rest.Size.Z * spread)
				part.CFrame = base * CFrame.new(rest.CFrame.X * spread, rest.CFrame.Y * (0.6 + 0.4 * spread), rest.CFrame.Z * spread) * rest.CFrame.Rotation
			else -- the cap and everything that rides on it: placed from the top down
				local below = full.Top - rest.CFrame.Y
				part.Size = rest.Size * wide
				part.CFrame = base * CFrame.new(rest.CFrame.X * wide, state.Top - below * wide, rest.CFrame.Z * wide) * rest.CFrame.Rotation
			end
		end
	end
	-- the ring
	local ring = target.Ring
	if ring then
		local radius = Cutscene.WaveRadius(path, t)
		if radius and radius < path.WaveReach * 1.15 then
			local f = radius / path.WaveReach
			ring.Size = Vector3.new(radius * 2, 10 + 26 * f, radius * 2)
			ring.CFrame = CFrame.new(blast + Vector3.yAxis * (ring.Size.Y / 2 - 1))
			ring.LocalTransparencyModifier = math.clamp((f - 0.8) / 0.35, 0, 1)
		else
			ring.LocalTransparencyModifier = 1
		end
	end
	for _, piece in target.Pieces do
		movePiece(piece, t, origin)
	end
end

local function moveRunners(target: World, t: number)
	local origin = target.Origin
	for index = 1, #path.Runners do
		local runner = target.Runners[index]
		if not runner then
			continue
		end
		local position, direction, run, inside = Cutscene.Runner(path, index, t)
		local show = not inside and t < Cutscene.Beat(path, "DoorTo")
		if show ~= runner.Shown or (show and runner.Model.Parent == nil) then
			runner.Shown = show
			runner.Running = false -- a track stops when its model leaves the world
			runner.Model.Parent = if show then target.Set else nil
		end
		if not show then
			continue
		end
		local flat = Vector3.new(direction.X, 0, direction.Z)
		local heading = origin:VectorToWorldSpace(if flat.Magnitude > 0.001 then flat.Unit else Vector3.xAxis)
		local running = run > 0
		local feet = origin * position
		local track = sprintTrack(runner)
		-- into the slope a little; Roblox's own run stands upright, so that one is leant by hand
		local lean = if running then (if runner.Own then 0 else math.rad(-10)) - math.asin(math.clamp(direction.Y, -0.7, 0.7)) * 0.35 else 0
		runner.Root.CFrame = CFrame.lookAt(feet + Vector3.yAxis * runner.Lift, feet + Vector3.yAxis * runner.Lift + heading) * CFrame.Angles(lean, 0, 0)
		if track and running ~= runner.Running then
			runner.Running = running
			if running then
				track:Play(0.1, 1, if runner.Own then 1 else path.RunSpeed / 16)
				track.TimePosition = (index * 0.137) % math.max(track.Length, 0.1)
			else
				track:Stop(0.1)
			end
		end
	end
end

local function moveEyes(target: World, t: number)
	local open = Cutscene.EyesOpen(path, t)
	for _, eye in target.Eyes do
		-- the great eye first, each of the others a little after the last; a slit, then wide
		local mine = math.clamp(open * 1.7 - (eye.Order - 1) * 0.1, 0, 1)
		local tall = 0.04 + 0.96 * Cutscene.Smooth(mine)
		eye.Part.Size = Vector3.new(eye.Size.X, eye.Size.Y * tall, eye.Size.Z)
		eye.Part.LocalTransparencyModifier = if mine <= 0 then 1 else 0
	end
end

-- The camera ---------------------------------------------------------------------------------------

local function shake(t: number): Vector3
	local amount = 0
	local slam = t - Cutscene.Beat(path, "DoorTo")
	if slam >= 0 and slam < 0.45 then
		amount = math.max(amount, tuning.DoorShake * (1 - slam / 0.45))
	end
	local hit = t - Cutscene.Beat(path, "DustFrom")
	if hit >= -0.5 and hit < tuning.WaveShakeSeconds then
		local grow = if hit < 0 then (hit + 0.5) / 0.5 else 1 - hit / tuning.WaveShakeSeconds
		amount = math.max(amount, tuning.WaveShake * grow)
	end
	if t >= Cutscene.Beat(path, "DiveFrom") and t < Cutscene.Beat(path, "PlungeTo") then
		amount = math.max(amount, tuning.PlungeShake)
	end
	if amount <= 0 or not shaking then
		return Vector3.zero
	end
	return Vector3.new(math.noise(t * 23, 1.3), math.noise(t * 27, 7.7), math.noise(t * 19, 13.1)) * amount * 2
end

-- Between the Command View's pose and the player's own camera: what the picture shows at the
-- player's depth shrinks steadily (in proportion, so the push feels even) while the lens opens, and
-- the distance follows from the two. A plain blend of the two cameras backs away before it closes in.
local function pushIn(pose: CFrame, poseFov: number, mine: CFrame, mineFov: number, subject: Vector3, f: number): (CFrame, number)
	local far = math.max((subject - pose.Position):Dot(pose.LookVector), 1)
	local near = math.max((subject - mine.Position):Dot(mine.LookVector), 1)
	local tallFar = 2 * far * math.tan(math.rad(poseFov) / 2)
	local tallNear = 2 * near * math.tan(math.rad(mineFov) / 2)
	local fieldOfView = poseFov + (mineFov - poseFov) * f
	local tall = tallFar * (tallNear / tallFar) ^ f
	local distance = tall / (2 * math.tan(math.rad(fieldOfView) / 2))
	local centre = (pose.Position + pose.LookVector * far):Lerp(mine.Position + mine.LookVector * near, f)
	return CFrame.new(centre) * pose.Rotation:Lerp(mine.Rotation, f) * CFrame.new(0, 0, distance), fieldOfView
end

local function moveCamera(target: World?, t: number)
	local camera = workspace.CurrentCamera
	local cframe, fieldOfView, shot = Cutscene.CameraAt(path, t)
	local space = if shot.Space == "Set" then (if target then target.Origin else setCFrame()) else gridCFrame()
	local world_ = space * cframe
	if shot.Handover then
		-- The last shot ends on this player: the Command View's pose over their own character,
		-- then down to their own camera.
		local root = characterRoot()
		local at = if root then Vector2.new(root.Position.X, root.Position.Y + 4) else Vector2.new(world_.Position.X, world_.Position.Y)
		local close = Cutscene.Smooth(Cutscene.Progress(path, "SettleFrom", "SettleTo", t))
		local floorsNow = Config.Get("Tuning", "CommandView").StartFloors * (0.78 + 0.22 * close)
		local pose, poseFov = commandView:Pose(at, floorsNow)
		local zoom = Cutscene.Progress(path, "ZoomFrom", "ZoomTo", t)
		if zoom > 0 and root then
			if not resumed then
				resumed = true
				cameraController:SetLook(0, -6) -- into the bunker, the way the Command View looks: the move is a push, not a turn
				cameraController:Resume(REASON)
				return -- the player's camera takes a frame to come round
			end
			-- the player's own camera has just set this frame's picture: push in to it
			local eased = Cutscene.Smooth(zoom)
			local cframe_, fov_ = pushIn(pose, poseFov, camera.CFrame, camera.FieldOfView, root.Position, eased)
			camera.CFrame = cframe_
			camera.FieldOfView = fov_
			return
		end
		world_, fieldOfView = pose, poseFov
	end
	if resumed then
		resumed = false
		cameraController:Suspend(REASON)
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = world_ + world_:VectorToWorldSpace(shake(t))
	camera.FieldOfView = fieldOfView
end

-- The screen's furniture -----------------------------------------------------------------------------

local function prepareBulletin()
	local line = barsPart("Bottom.Bulletin.Ticker.Line")
	local plate = barsPart("Bottom.Bulletin.Plate")
	if not line or not plate then
		return
	end
	local bulletin = words.Bulletin
	line.Text = bulletin.Text
	plate.Station.Text = bulletin.Station
	plate.Tag.Text = bulletin.Tag
	bulletinReady = false
	task.spawn(function()
		-- the line's shape: as wide as its text, so it scales with the bar and can be run across
		local params = Instance.new("GetTextBoundsParams")
		params.Text = bulletin.Text
		params.Font = line.FontFace
		params.Size = 100
		params.Width = 1e6
		local ok, bounds = pcall(function()
			return TextService:GetTextBoundsAsync(params)
		end)
		local ratio = if ok and bounds.Y > 0 then bounds.X / bounds.Y else #bulletin.Text * 0.55
		local constraint = line:FindFirstChildOfClass("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint")
		constraint.AspectRatio = ratio
		constraint.DominantAxis = Enum.DominantAxis.Height
		constraint.Parent = line
		line.Size = UDim2.fromScale(ratio, 0.62) -- wide enough for the constraint to take the height
		bulletinReady = true
	end)
end

local function showScreen(t: number, target: World?)
	local bars = gui("CutsceneBars")
	local screen = gui("Cutscene")
	if not bars or not screen then
		return
	end
	local fraction = tuning.BarFraction
	-- the bars slide in at the start and away at the end
	local barIn = math.clamp(t / 0.5, 0, 1)
	local barOut = math.clamp((path.Seconds - t) / 0.45, 0, 1)
	local shown = Cutscene.Smooth(math.min(barIn, barOut))
	local top, bottom = barsPart("Top"), barsPart("Bottom")
	top.Size = UDim2.fromScale(1, fraction)
	bottom.Size = UDim2.fromScale(1, fraction)
	top.Position = UDim2.fromScale(0, fraction * shown)
	bottom.Position = UDim2.fromScale(0, 1 - fraction * shown)
	-- black: the picture comes up out of it once the set has loaded (or PreloadSeconds have gone
	-- by), and the title lands on it
	local black = 0
	if target then
		if not target.RevealedAt and os.clock() - startedClock >= tuning.PreloadSeconds then
			target.RevealedAt = os.clock()
		end
		local revealed = target.RevealedAt
		black = if revealed then 1 - math.clamp((os.clock() - math.max(revealed, startedClock + 0.25)) / tuning.FadeInSeconds, 0, 1) else 1
	end
	local title = Cutscene.Beat(path, "Title")
	if t >= title then
		-- the card lands on black; the bunker comes up behind it, dimmed until the card has gone
		local up = Cutscene.Smooth((t - title - 0.45) / 0.85)
		local clear = Cutscene.Smooth((t - words.TitleTo) / 0.5)
		black = math.max(black, 1 - up * (1 - TITLE_SCRIM * (1 - clear)))
	end
	barsPart("Black").BackgroundTransparency = 1 - black
	-- white: the flash, and the instant before it on the door
	local flashAt = Cutscene.Beat(path, "Flash")
	local white = 0
	if t >= flashAt - 0.14 and t < flashAt then
		white = (t - (flashAt - 0.14)) / 0.14
	elseif t >= flashAt then
		white = 1 - Cutscene.Smooth((t - flashAt - 0.18) / 0.9)
	end
	if not flashing then
		white = math.min(white, 0.3) -- a soft wash where the flash would be, so the cut still reads
	end
	barsPart("Flash").BackgroundTransparency = 1 - math.clamp(white, 0, 1)
	-- dust: the ring reaches the camera
	local dust = Cutscene.Progress(path, "DustFrom", "DustTo", t)
	local thick = if dust <= 0 or dust >= 1 then 0 else math.sin(dust * math.pi) ^ 0.6 * 0.88
	barsPart("Dust").BackgroundTransparency = 1 - thick
	-- the bulletin
	local bulletin = words.Bulletin
	local frame = barsPart("Bottom.Bulletin")
	local on = t >= bulletin.From and t <= bulletin.To + 0.3
	frame.Visible = on
	if on then
		local ticker, line = barsPart("Bottom.Bulletin.Ticker"), barsPart("Bottom.Bulletin.Ticker.Line")
		local across = math.clamp((t - bulletin.From) / (bulletin.To - bulletin.From), 0, 1)
		local wide = if bulletinReady and ticker.AbsoluteSize.X > 0 then line.AbsoluteSize.X / ticker.AbsoluteSize.X else 3
		line.Position = UDim2.fromScale(1 - across * (1 + wide), 0.5)
		barsPart("Bottom.Bulletin.Plate.LampOn").Visible = (t * 2) % 1 < 0.6
	end
	-- the title and its line
	local card = screenPart("Title")
	local showTitle = t >= words.TitleFrom and t < words.TitleTo + 0.5
	card.Visible = showTitle
	if showTitle then
		local land = math.clamp((t - words.TitleFrom) / 0.22, 0, 1)
		local leave = math.clamp((t - words.TitleTo) / 0.5, 0, 1)
		local scale = card:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		scale.Scale = 1.18 - 0.18 * Cutscene.Smooth(land)
		scale.Parent = card
		card.Years.ImageTransparency = math.max(1 - land, leave)
		card.Below.ImageTransparency = math.max(1 - math.clamp((t - words.TitleFrom - 0.12) / 0.22, 0, 1), leave)
		-- the title in type, should its pictures not have arrived (a slow connection)
		local plain = card:FindFirstChild("Words")
		if plain and plain:IsA("TextLabel") then
			plain.Visible = not (card.Years.IsLoaded and card.Below.IsLoaded)
			plain.Text = words.Title
			plain.TextTransparency = math.max(1 - land, leave)
		end
		local said = ""
		for _, part in words.Tagline do
			if t >= part.At then
				said ..= (if said == "" then "" else "  ") .. part.Text
			end
		end
		card.Tagline.Text = said
		card.Tagline.TextTransparency = leave
	end
	-- Skip
	local skip = screenPart("Skip")
	local firstRun = Players.LocalPlayer:GetAttribute("IntroFirstRun") == true
	local can = playing and not skipped and Cutscene.CanSkip(firstRun and live, t, skipAfter) and t < path.Seconds - 1.2
	skip.Visible = can
	if can then
		local device = input:Device()
		skip.Key.Visible = device ~= "Touch" and tuning.SkipHoldSeconds > 0
		skip.Key.Text.Text = if device == "Gamepad" then "HOLD B" else "HOLD SPACE"
		local hold = tuning.SkipHoldSeconds
		skip.Content.Fill.Size = UDim2.fromScale(if hold > 0 then 0.84 * math.clamp(skipHeldFor / hold, 0, 1) else 0, 0.08)
	end
end

-- Start and finish ---------------------------------------------------------------------------------

local function present(on: boolean)
	if presented ~= on then
		presented = on
		commandView:Present(REASON, on)
	end
end

local function waitPlate(on: boolean)
	waiting = on
	local screen = gui("Cutscene")
	local plate = screenPart("Wait")
	if screen and plate then
		screen.Enabled = on
		plate.Visible = on
		screenPart("Skip").Visible = false
		screenPart("Title").Visible = false
	end
end

local function finish(bySkip: boolean)
	if not playing then
		return
	end
	playing = false
	RunService:UnbindFromRenderStep(RENDER_NAME)
	ContextActionService:UnbindAction(SKIP_ACTION)
	local target = world
	world = nil
	if target then
		for _, runner in target.Runners do
			runner.Model:Destroy()
		end
		if target.Bomb then
			target.Bomb:Destroy()
		end
		target.Set:Destroy()
	end
	restoreLook()
	present(false)
	hideLeftovers(false)
	local bars = gui("CutsceneBars")
	if bars then
		bars.Enabled = false
	end
	local screen = gui("Cutscene")
	if screen then
		screen.Enabled = false
	end
	if not resumed then
		cameraController:Resume(REASON)
	end
	resumed = false
	cameraController:FreeCursor(REASON, false)
	hud:Hide(REASON, false)
	input:Block(REASON, false)
	ui:Lock(REASON, false)
	holdCharacter(false)
	hideCore(false)
	if bySkip and live and RunState.Get("RunPhase") == "Intro" then
		waitPlate(true)
	end
	log:Info("the intro %s at %.1f s", if bySkip then "was skipped" else "ended", lastT)
	CutsceneController.Finished:Fire(bySkip)
end

local function skip()
	if not playing or skipped then
		return
	end
	local firstRun = Players.LocalPlayer:GetAttribute("IntroFirstRun") == true
	if not Cutscene.CanSkip(firstRun and live, lastT, skipAfter) then
		return
	end
	skipped = true
	finish(true)
end

local function step(dt: number)
	local t = seconds()
	if live and (t >= path.Seconds or RunState.Get("RunPhase") ~= "Intro") then
		lastT = path.Seconds
		finish(false)
		return
	end
	t = math.clamp(t, 0, path.Seconds)
	if not live and t >= path.Seconds and not devHeld then
		lastT = t
		finish(false)
		return
	end
	local target = world
	local inBunker = t >= Cutscene.Beat(path, "DiveTo")
	if inBunker then
		restoreLook() -- the run's own light before the Command View lifts it
		present(true)
		hideLeftovers(true)
	else
		present(false)
		hideLeftovers(false)
		applyLook(t)
	end
	if target then
		if target.Door then
			moveDoor(target.Door, t)
		end
		moveBlast(target, t)
		moveRunners(target, t)
		moveEyes(target, t)
	end
	moveCamera(target, t)
	if target and target.Ash then
		local falling = not inBunker and t >= Cutscene.Beat(path, "DustTo") - 0.4
		local camera = workspace.CurrentCamera.CFrame
		target.Ash.CFrame = CFrame.new(camera.Position + camera.LookVector * 62 + Vector3.yAxis * 6)
		for _, emitter in target.Ash:GetChildren() do
			if emitter:IsA("ParticleEmitter") and emitter.Enabled ~= falling then
				emitter.Enabled = falling
				if not falling then
					emitter:Clear()
				end
			end
		end
	end
	showScreen(t, target)
	local shot = Cutscene.ShotAt(path, t)
	if shot.Name ~= lastShot then
		lastShot = shot.Name
		log:Debug("shot %s at %.2f s", shot.Name, t)
	end
	-- the Skip key, held
	if skipHeld then
		skipHeldFor += dt
		if skipHeldFor >= tuning.SkipHoldSeconds then
			skipHeld = false
			skip()
		end
	else
		skipHeldFor = 0
	end
	lastT = t
end

local function begin(followClock: boolean, from: number?)
	if playing then
		return
	end
	local bars, screen = gui("CutsceneBars"), gui("Cutscene")
	if not bars or not screen then
		log:Warn("no Cutscene screens in this place: the intro is not shown")
		return
	end
	playing = true
	live = followClock
	skipped = false
	skipHeld = false
	skipHeldFor = 0
	resumed = false
	lastShot = ""
	devAt, devFrom, devHeld = from or 0, os.clock(), false
	startedClock = os.clock()
	waitPlate(false)
	pcall(function()
		ReplicatedFirst:RemoveDefaultLoadingScreen()
	end)
	-- "It doubles as the loading screen: the bunker and nearby zones stream in behind it" (Section 4)
	task.spawn(function()
		pcall(function()
			Players.LocalPlayer:RequestStreamAroundAsync(Grid.CellPosition(1, 0), 10)
		end)
	end)
	ui:Lock(REASON, true)
	input:Block(REASON, true)
	hud:Hide(REASON, true)
	holdCharacter(true)
	hideCore(true)
	cameraController:Suspend(REASON)
	cameraController:FreeCursor(REASON, true)
	workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	barsPart("Black").BackgroundTransparency = 0
	bars.Enabled = true
	screen.Enabled = true
	prepareBulletin()
	local target = build()
	world = target
	if target then
		castRunners(target)
		preload(target)
	end
	ContextActionService:BindActionAtPriority(SKIP_ACTION, function(_name: string, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			skipHeld = true
			if tuning.SkipHoldSeconds <= 0 then
				skipHeld = false
				skip()
			end
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			skipHeld = false
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 50, Enum.KeyCode.Space, Enum.KeyCode.ButtonB)
	RunService:BindToRenderStep(RENDER_NAME, RENDER_PRIORITY, step)
	log:Info("the intro begins at %.1f s (%s)", seconds(), if followClock then "the run's clock" else "a dev replay")
end

-- Should the cutscene be playing? Called when the run's phase changes and at the start.
local function consider()
	local phase = RunState.Get("RunPhase")
	if phase == "Intro" then
		local left = RunState.TimeLeft()
		if not playing and not skipped and left and left > tuning.LateJoinSeconds then
			begin(true)
		end
	else
		if waiting then
			waitPlate(false)
		end
		skipped = false
	end
end

-- API ----------------------------------------------------------------------------------------------

function CutsceneController:IsPlaying(): boolean
	return playing
end

-- The accessibility settings: no white flash, no camera shake (bible Section 18).
function CutsceneController:SetComfort(flash: boolean, shake: boolean)
	flashing = flash
	shaking = shake
end

function CutsceneController:State(): { [string]: any }
	local target = world
	local runners = 0
	if target then
		for _ in target.Runners do
			runners += 1
		end
	end
	return {
		Playing = playing,
		Live = live,
		Seconds = if playing then seconds() else lastT,
		Shot = lastShot,
		Pieces = if target then #target.Pieces else 0,
		Runners = runners,
		Loaded = target ~= nil and target.Loaded,
		Waiting = waiting,
		FirstRun = Players.LocalPlayer:GetAttribute("IntroFirstRun") == true,
	}
end

local function describe(): string
	local state = CutsceneController:State()
	return string.format(
		"cutscene: %s, %.2f s, shot %s, %d pieces that the blast moves, %d runners, set %s, first run %s%s",
		if state.Playing then (if state.Live then "playing with the run's clock" else "a dev replay") else "not playing",
		state.Seconds, if state.Shot == "" then "-" else state.Shot, state.Pieces, state.Runners,
		if state.Loaded then "loaded" else "loading or none", tostring(state.FirstRun),
		if state.Waiting then ", waiting for the run to start" else ""
	)
end

function CutsceneController:Init(registry)
	input = registry.InputController
	cameraController = registry.CameraController
	ui = registry.UIController
	hud = registry.HUDController
	commandView = registry.CommandViewController
	dev = registry.DevController
	tuning = Config.Get("Tuning", "Cutscene")
	words = Config.Get("Cutscenes", "Intro")
	path = Config.Get("CutscenePaths", words.Path) :: any
	skipAfter = Config.Get("Tuning", "Clock").IntroSkipAfterSeconds
	dev:Register("cutscene", function(): string?
		return describe()
	end)
	dev:Register("cutscene.play", function(args: { any }): string?
		finish(false)
		begin(false, tonumber(args[1]) or 0)
		return describe()
	end)
	dev:Register("cutscene.at", function(args: { any }): string?
		if not playing or live then
			finish(false)
			begin(false, 0)
		end
		devAt, devFrom, devHeld = math.clamp(tonumber(args[1]) or 0, 0, path.Seconds), os.clock(), true
		task.wait(0.25)
		return describe()
	end)
	dev:Register("cutscene.stop", function(): string?
		finish(false)
		return describe()
	end)
	dev:Register("cutscene.skip", function(): string?
		skip()
		return describe()
	end)
	dev:Register("cutscene.comfort", function(args: { any }): string?
		CutsceneController:SetComfort(args[1] ~= false, args[2] ~= false)
		return `cutscene: flash {if flashing then "on" else "off"}, shake {if shaking then "on" else "off"}`
	end)
end

function CutsceneController:Start()
	for _, name in { "CutsceneBars", "Cutscene" } do
		local found = gui(name) or Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild(name, 10)
		if found then
			KitRuntime.Watch(found)
		end
	end
	local skipButton = screenPart("Skip")
	if skipButton then
		skipButton.Activated:Connect(skip)
	end
	RunState.Changed("RunPhase"):Connect(consider)
	RunState.Changed("IntroEndsAt"):Connect(consider)
	-- the plate that counts down to the run for a player who skipped
	task.spawn(function()
		while true do
			if waiting then
				local left = RunState.TimeLeft()
				local label = screenPart("Wait.Time")
				if label and left then
					label.Text = string.format("0:%02d", math.ceil(left))
				end
			end
			task.wait(0.2)
		end
	end)
	consider()
end

return CutsceneController
