--!strict
--[[
	CutsceneService: the server's small part in the intro cutscene (bible Section 4; Prompt 22).
	The cutscene itself is played by each client (CutsceneController): it is personal, a player can
	skip it, and the run's clock starts at the 30-second mark whatever anyone does (RunDirector's
	Intro phase).

	* The set. The client can't reach ServerStorage, so at the start this puts the set together in
	  ReplicatedStorage.CutsceneSet from Config.CutscenePaths (made in Blender) and the art in
	  ServerStorage.Assets: Pieces (every placed model, with its Kind and its place in the list),
	  Ground (roads, pavements and grass as plain blocks) and Effects (the Cutscene models that
	  stand nowhere until the client moves them: the bomb, the cloud, the ring, the rock above the
	  bunker, the Source's hollow). It is laid out around the world's origin: the client clones it
	  and moves the copy to Tuning.Cutscene.SetOrigin. Nothing of it is ever in workspace on the
	  server, so nobody can walk onto it. KeepSetSeconds into the run it is destroyed, which frees
	  it on every client (in Studio it stays, for the dev replay).
	* The first run. "An account's first run plays it in full": each player's IntroFirstRun
	  attribute says whether this is theirs (the profile's FirstRunDone), set as their session
	  becomes ready.

	Dev: `intro` (the set and each player's flag), `intro.first [true|false] [player]`.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Utilities.Log)

local log = Log.new("CutsceneService")

local SET_NAME = "CutsceneSet"
local ASSET_TAG = "Asset" -- marks the source models in ServerStorage.Assets; copies drop it
local ATTRIBUTE = "IntroFirstRun"

local CutsceneService = {
	Name = "CutsceneService",
	Dependencies = { "RunDirector", "SessionService", "ProfileService", "DevService" },
}

local run: any = nil
local session: any = nil
local profiles: any = nil
local dev: any = nil
local missing: { string } = {}
local placed = 0

local function art(category: string, name: string): Model?
	local assets = ServerStorage:FindFirstChild("Assets")
	local folder = if assets then assets:FindFirstChild(category) else nil
	local found = if folder then folder:FindFirstChild(name) else nil
	return if found and found:IsA("Model") then found else nil
end

-- Scenery: nothing touches it, nothing queries it, nothing is simulated.
local function still(root: Instance)
	for _, item in root:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
		end
	end
end

local function copy(source: Model, name: string): Model
	local model = source:Clone()
	model.Name = name
	CollectionService:RemoveTag(model, ASSET_TAG)
	local colliders = model:FindFirstChild("Colliders")
	if colliders then
		colliders:Destroy()
	end
	return model
end

local function build(): Model
	local path = Config.Get("CutscenePaths", "Intro")
	local set = Instance.new("Model")
	set.Name = SET_NAME
	local pieces = Instance.new("Folder")
	pieces.Name = "Pieces"
	pieces.Parent = set
	local used: { [string]: boolean } = {}
	table.clear(missing)
	placed = 0
	for index, spot in path.Set do
		used[spot.Asset] = true
		local source = art(spot.Category, spot.Asset)
		if not source then
			if not table.find(missing, spot.Asset) then
				table.insert(missing, spot.Asset)
			end
			continue
		end
		local model = copy(source, spot.Name)
		if spot.Kind ~= "Still" then
			local lights = model:FindFirstChild("Lights") -- street lamps and signs are off: it is morning
			if lights then
				lights:Destroy()
			end
		end
		if math.abs(spot.Scale - 1) > 0.001 then
			model:ScaleTo(spot.Scale)
		end
		model:PivotTo(CFrame.new(spot.P[1], spot.P[2], spot.P[3]) * CFrame.Angles(0, math.rad(spot.Yaw), 0))
		if spot.Paint then
			local paint = model:FindFirstChild("Paint")
			if paint and paint:IsA("BasePart") then
				paint.Color = Color3.fromHex(spot.Paint)
			end
		end
		still(model)
		model:SetAttribute("Kind", spot.Kind)
		model:SetAttribute("Index", index)
		model.Parent = pieces
		placed += 1
	end
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = set
	for _, slab in path.Ground do
		local part = Instance.new("Part")
		part.Name = slab.Name
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Color = Color3.fromHex(slab.Hex)
		part.Size = Vector3.new(slab.Size[1], slab.Size[2], slab.Size[3])
		part.CFrame = CFrame.new(slab.P[1], slab.P[2], slab.P[3])
		part.Parent = ground
	end
	local effects = Instance.new("Folder")
	effects.Name = "Effects"
	effects.Parent = set
	local assets = ServerStorage:FindFirstChild("Assets")
	local category = if assets then assets:FindFirstChild("Cutscene") else nil
	if category then
		for _, source in category:GetChildren() do
			if source:IsA("Model") and not used[source.Name] then
				local model = copy(source, source.Name)
				still(model)
				model.Parent = effects
			end
		end
	end
	return set
end

local function flag(player: Player)
	local data = profiles:Get(player)
	player:SetAttribute(ATTRIBUTE, data ~= nil and data.FirstRunDone == false)
end

local function describe(): string
	local set = ReplicatedStorage:FindFirstChild(SET_NAME)
	local lines = {
		if set
			then `intro set: {placed} pieces, {#set.Ground:GetChildren()} ground blocks, {#set.Effects:GetChildren()} effects`
			else "intro set: gone (the run has started)",
	}
	if #missing > 0 then
		table.insert(lines, `  not in ServerStorage.Assets: {table.concat(missing, ", ")}`)
	end
	for _, player in session:ReadyPlayers() do
		table.insert(lines, `  {player.Name}: first run {tostring(player:GetAttribute(ATTRIBUTE))}`)
	end
	return table.concat(lines, "\n")
end

function CutsceneService:Init(registry)
	run = registry.RunDirector
	session = registry.SessionService
	profiles = registry.ProfileService
	dev = registry.DevService
	dev:Register("intro", {
		Description = "the intro cutscene's set and each player's first-run flag",
		Run = function(_player: Player?, _args: { any }): string
			return describe()
		end,
	})
	dev:Register("intro.first", {
		Description = "say whether this is the player's first run (the cutscene plays in full, no Skip)",
		Usage = "intro.first [true|false] [player]",
		Run = function(player: Player?, args: { any }): string
			local target = player
			if type(args[2]) == "string" then
				for _, other in session:ReadyPlayers() do
					if string.lower(other.Name) == string.lower(args[2]) then
						target = other
					end
				end
			end
			target = target or session:ReadyPlayers()[1]
			if not target then
				return "no player"
			end
			target:SetAttribute(ATTRIBUTE, args[1] ~= false)
			return describe()
		end,
	})
end

function CutsceneService:Start()
	local began = os.clock()
	local set = build()
	set.Parent = ReplicatedStorage
	if #missing > 0 then
		log:Warn("the intro's set is missing art: %s", table.concat(missing, ", "))
	end
	log:Info("the intro's set is ready: %d pieces in %.0f ms", placed, (os.clock() - began) * 1000)
	for _, player in session:ReadyPlayers() do
		flag(player)
	end
	session.PlayerReady:Connect(flag)
	run.PhaseChanged:Connect(function(new: string)
		if new == "Playing" and not RunService:IsStudio() then
			task.delay(Config.Get("Tuning", "Cutscene").KeepSetSeconds, function()
				local live = ReplicatedStorage:FindFirstChild(SET_NAME)
				if live then
					live:Destroy()
				end
			end)
		end
	end)
end

return CutsceneService
