--!strict
--[[
	StructureCheck: is the place built the way Documentation.ARCHITECTURE says?

	Checks the code skeleton, every installed file in BuildInfo, the service dependency
	graph, stray scripts and remotes, Config data, place identity and leftovers
	(ServerStorage.NS_Pipeline, an outside plugin's working folder: a warning, an error only
	if scripts appear in it).

	Run({ Runtime = true }) inside a running server (DevService `structure`) also checks
	the remotes and the boot result. Run({ Sources = true }) from a Studio plugin or the
	command bar also compares every script's Source with the hash BuildInfo recorded, to
	catch edits made in Studio that the repo doesn't have.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

export type Options = { Runtime: boolean?, Sources: boolean? }
export type Result = { Errors: { string }, Warnings: { string }, Passed: number, Notes: { string } }

local SKELETON: { { string } } = {
	{ "ReplicatedStorage.Shared", "Folder" },
	{ "ReplicatedStorage.Shared.BuildInfo", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Constants", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Types", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Remotes", "ModuleScript" },
	{ "ReplicatedStorage.Shared.RunState", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Config", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Rules", "Folder" },
	{ "ReplicatedStorage.Shared.Rules.Bunker", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Rules.CameraRig", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Rules.Clock", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Rules.Grid", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Rules.Hud", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Rules.CommandView", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Rules.Construction", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Rules.Economy", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Rules.Residents", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Rules.Disasters", "ModuleScript" }, -- Prompt 13
	{ "ReplicatedStorage.Shared.Rules.Modifiers", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Rules.Dig", "ModuleScript" }, -- Prompt 14
	{ "ReplicatedStorage.Shared.Rules.Loot", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Rules.Combat", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Rules.Threat", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Rules.Votes", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Rules.Boss", "ModuleScript" }, -- Prompt 15
	{ "ReplicatedStorage.Shared.Rules.Results", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Rules.Surface", "ModuleScript" }, -- Prompt 16
	{ "ReplicatedStorage.Shared.Rules.Deep", "ModuleScript" }, -- Prompt 17
	{ "ReplicatedStorage.Shared.Utilities", "Folder" },
	{ "ReplicatedStorage.Shared.Utilities.Check", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Utilities.Delta", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Utilities.Loader", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Utilities.Log", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Utilities.RateLimit", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Utilities.Signal", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Utilities.TableUtil", "ModuleScript" },
	{ "ReplicatedStorage.Shared.Utilities.Trove", "ModuleScript" },
	{ "ServerScriptService.Bootstrap", "Script" },
	{ "ServerScriptService.Services", "Folder" },
	{ "ServerScriptService.Lib", "Folder" },
	{ "ServerScriptService.Lib.ProfileSchema", "ModuleScript" },
	{ "ServerScriptService.DevTools", "Folder" },
	{ "ServerScriptService.DevTools.StructureCheck", "ModuleScript" },
	{ "ServerScriptService.DevTools.DataTests", "ModuleScript" },
	{ "StarterPlayer.StarterPlayerScripts.ClientBootstrap", "LocalScript" },
	{ "StarterPlayer.StarterPlayerScripts.Controllers", "Folder" },
	{ "StarterPlayer.StarterPlayerScripts.Controllers.CameraController", "ModuleScript" },
	{ "StarterPlayer.StarterPlayerScripts.Controllers.InputController", "ModuleScript" },
	{ "StarterPlayer.StarterPlayerScripts.Controllers.UIController", "ModuleScript" },
	{ "StarterPlayer.StarterPlayerScripts.Controllers.HUDController", "ModuleScript" },
	{ "StarterPlayer.StarterPlayerScripts.Controllers.MiniMapController", "ModuleScript" },
	{ "StarterPlayer.StarterPlayerScripts.Controllers.CommandViewController", "ModuleScript" },
	{ "StarterPlayer.StarterPlayerScripts.Controllers.VoteController", "ModuleScript" },
	{ "StarterPlayer.StarterPlayerScripts.Controllers.NPCAnimator", "ModuleScript" },
	{ "StarterPlayer.StarterPlayerScripts.Controllers.ResidentsController", "ModuleScript" },
	{ "StarterPlayer.StarterPlayerScripts.Lib", "Folder" },
	{ "StarterPlayer.StarterPlayerScripts.Lib.Fade", "ModuleScript" },
	{ "StarterPlayer.StarterPlayerScripts.Lib.Movement", "ModuleScript" },
	{ "StarterPlayer.StarterPlayerScripts.Lib.KitRuntime", "ModuleScript" },
	{ "StarterPlayer.StarterPlayerScripts.Lib.UIKit", "ModuleScript" },
	{ "StarterPlayer.StarterPlayerScripts.Lib.UISamples", "ModuleScript" },
	{ "ReplicatedStorage.Shared.UIContract", "ModuleScript" },
	{ "StarterGui.Reticle", "ScreenGui" },
	{ "ServerStorage.Documentation", "Folder" },
	{ "ServerStorage.Documentation.ARCHITECTURE", "ModuleScript" },
}

-- What only one place has (from game/places/<Place>).
local PLACE_SKELETON: { [string]: { { string } } } = {
	Run = {
		{ "ServerScriptService.Services.RunDirector", "ModuleScript" },
		{ "ServerScriptService.Services.CycleClock", "ModuleScript" },
		{ "ServerScriptService.Services.ObjectiveService", "ModuleScript" },
		{ "ServerScriptService.Services.BunkerGrid", "ModuleScript" },
		{ "ServerScriptService.Services.PingService", "ModuleScript" },
		{ "ServerScriptService.Services.EconomyService", "ModuleScript" },
		{ "ServerScriptService.Services.PowerService", "ModuleScript" },
		{ "ServerScriptService.Services.ResidentService", "ModuleScript" },
		{ "ServerScriptService.Services.VoteService", "ModuleScript" },
		{ "ServerScriptService.Services.BuildService", "ModuleScript" },
		{ "ServerScriptService.Lib.BunkerKit", "ModuleScript" },
		{ "ServerScriptService.Lib.PathGraph", "ModuleScript" },
		{ "ServerScriptService.Services.ResidentBrain", "ModuleScript" },
		{ "ServerScriptService.Services.CombatService", "ModuleScript" },
		{ "ServerScriptService.Services.WeaponService", "ModuleScript" },
		{ "StarterPlayer.StarterPlayerScripts.Controllers.CombatController", "ModuleScript" },
		{ "StarterPlayer.StarterPlayerScripts.Controllers.PromptController", "ModuleScript" },
		{ "ServerScriptService.Services.MonsterService", "ModuleScript" }, -- Prompt 12
		{ "ServerScriptService.Services.BreachService", "ModuleScript" },
		{ "ServerScriptService.Services.ThreatDirector", "ModuleScript" },
		{ "StarterPlayer.StarterPlayerScripts.Controllers.ThreatController", "ModuleScript" },
		{ "ServerScriptService.Services.DisasterService", "ModuleScript" }, -- Prompt 13
		{ "ServerScriptService.Lib.Hazards", "ModuleScript" },
		{ "StarterPlayer.StarterPlayerScripts.Controllers.DisasterController", "ModuleScript" },
		{ "ServerScriptService.Services.DigService", "ModuleScript" }, -- Prompt 14
		{ "StarterPlayer.StarterPlayerScripts.Controllers.DigController", "ModuleScript" },
		{ "ServerScriptService.Services.BossService", "ModuleScript" }, -- Prompt 15
		{ "ServerScriptService.Services.ResultsService", "ModuleScript" },
		{ "StarterPlayer.StarterPlayerScripts.Controllers.BossController", "ModuleScript" },
		{ "StarterPlayer.StarterPlayerScripts.Controllers.ResultsController", "ModuleScript" },
		{ "ServerScriptService.Services.SurfaceService", "ModuleScript" }, -- Prompt 16
		{ "ServerScriptService.Services.InventoryService", "ModuleScript" },
		{ "ServerScriptService.Services.RescueService", "ModuleScript" },
		{ "StarterPlayer.StarterPlayerScripts.Controllers.SurfaceController", "ModuleScript" },
		{ "ServerScriptService.Services.DeepService", "ModuleScript" }, -- Prompt 17
		{ "StarterPlayer.StarterPlayerScripts.Controllers.DeepController", "ModuleScript" },
		{ "StarterGui.HUD.BossBar", "ImageLabel" },
		{ "StarterGui.Reticle.Sight.Hit", "Frame" },
		{ "StarterGui.Reticle.Sight.Kill", "Frame" },
	},
	Lobby = {},
}

-- The only scripts: everything else is a ModuleScript (bible Section 23).
local ENTRY_SCRIPTS: { [string]: string } = {
	["ServerScriptService.Bootstrap"] = "Script",
	["StarterPlayer.StarterPlayerScripts.ClientBootstrap"] = "LocalScript",
}

-- Roblox's own player and character scripts, which it inserts under StarterPlayer when a
-- playtest starts (PlayerModule also carries InputSetup and ServerAuthority scripts).
local ROBLOX_DEFAULTS: { [string]: boolean } = {
	PlayerModule = true,
	PlayerScriptsLoader = true,
	RbxCharacterSounds = true,
	Animate = true,
	Health = true,
}

-- Scripts inside a player's character (Roblox copies Animate and Health into it).
local function inCharacter(instance: Instance): boolean
	local players = game:GetService("Players")
	local model = instance:FindFirstAncestorOfClass("Model")
	while model do
		if players:GetPlayerFromCharacter(model) then
			return true
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return false
end

local function isRobloxDefault(instance: Instance): boolean
	local node: Instance? = instance
	while node and node.Parent ~= game do
		if ROBLOX_DEFAULTS[node.Name] then
			return node:FindFirstAncestorOfClass("StarterPlayer") ~= nil
		end
		node = node.Parent
	end
	return false
end

local SCRIPT_ROOTS = {
	"Workspace",
	"ReplicatedFirst",
	"ReplicatedStorage",
	"ServerScriptService",
	"ServerStorage",
	"StarterGui",
	"StarterPack",
	"StarterPlayer",
	"Lighting",
	"SoundService",
}

local function find(path: string): Instance?
	local node: Instance? = game
	for segment in string.gmatch(path, "[^%.]+") do
		if node == game then
			local ok, service = pcall(game.GetService, game, segment)
			node = if ok then service else nil
		else
			node = (node :: Instance):FindFirstChild(segment)
		end
		if not node then
			return nil
		end
	end
	return node
end

local function pathOf(instance: Instance): string
	return instance:GetFullName()
end

-- An art-pipeline sample (A0_Showroom, A0_HUD...): allowed until gameplay replaces it.
local function isSample(instance: Instance): boolean
	local node: Instance? = instance
	while node and node ~= game do
		if string.sub(node.Name, 1, 3) == "A0_" then
			return true
		end
		node = node.Parent
	end
	return false
end

local function fnv1a(text: string): string
	local hash = 2166136261
	for index = 1, #text do
		hash = bit32.bxor(hash, string.byte(text, index))
		hash = (bit32.lshift(hash, 24) + hash * 403) % 4294967296
	end
	return string.format("%08x", hash)
end

local StructureCheck = {}

StructureCheck.Hash = fnv1a

function StructureCheck.Run(options: Options?): Result
	local runtime = options ~= nil and options.Runtime == true
	local sources = options ~= nil and options.Sources == true
	local result: Result = { Errors = {}, Warnings = {}, Passed = 0, Notes = {} }
	local function pass()
		result.Passed += 1
	end
	local function fail(message: string)
		table.insert(result.Errors, message)
	end
	local function warnOf(message: string)
		table.insert(result.Warnings, message)
	end

	-- 1. The skeleton (shared, then this place's own)
	local placeKind: string? = nil
	do
		local constantsModule = find("ReplicatedStorage.Shared.Constants")
		if constantsModule and constantsModule:IsA("ModuleScript") then
			local ok, kind = pcall((require(constantsModule) :: any).PlaceKind)
			placeKind = if ok then kind else nil
		end
	end
	local skeleton = table.clone(SKELETON)
	for _, item in (if placeKind then PLACE_SKELETON[placeKind] else nil) or {} do
		table.insert(skeleton, item)
	end
	for _, item in skeleton do
		local path, className = item[1], item[2]
		local found = find(path)
		if not found then
			fail(`missing {path} ({className})`)
		elseif found.ClassName ~= className then
			fail(`{path} is a {found.ClassName}, should be a {className}`)
		else
			pass()
		end
	end
	for kind, items in PLACE_SKELETON do
		if kind ~= placeKind then
			for _, item in items do
				if find(item[1]) then
					fail(`{item[1]} belongs to the {kind} place only`)
				end
			end
		end
	end

	-- 2. Every installed file, and (from a plugin) whether it was edited after install
	local buildInfo: any = nil
	local buildModule = find("ReplicatedStorage.Shared.BuildInfo")
	if buildModule and buildModule:IsA("ModuleScript") then
		local ok, info = pcall(require, buildModule)
		if ok and type(info) == "table" and type(info.Files) == "table" then
			buildInfo = info
			pass()
		else
			fail("BuildInfo doesn't load or has no Files")
		end
	end
	if buildInfo then
		table.insert(result.Notes, `build {buildInfo.Label}`)
		for path, file in buildInfo.Files do
			local found = find(path)
			if not found then
				fail(`installed file missing: {path} ({file.Class})`)
			elseif found.ClassName ~= file.Class then
				fail(`{path} is a {found.ClassName}, installed as a {file.Class}`)
			else
				pass()
				if sources and found:IsA("LuaSourceContainer") then
					local ok, source = pcall(function()
						return (found :: any).Source
					end)
					if ok and fnv1a(source) ~= file.Hash then
						warnOf(`{path} was edited in Studio after install (the repo copy differs)`)
					end
				end
			end
		end
	end

	-- 3. Services: names, shape and a dependency order with no cycle
	local servicesFolder = find("ServerScriptService.Services")
	if servicesFolder then
		local Loader = require(ReplicatedStorage.Shared.Utilities.Loader) :: any
		local ok, modules = pcall(Loader.Collect, servicesFolder, "Service")
		if not ok then
			fail(tostring(modules))
		else
			local order, problem = Loader.Order(modules)
			if order then
				pass()
				table.insert(result.Notes, `services: {table.concat(order, ", ")}`)
			else
				fail(`services: {problem}`)
			end
		end
		for _, child in servicesFolder:GetChildren() do
			if not child:IsA("ModuleScript") then
				warnOf(`{pathOf(child)}: only ModuleScripts belong in Services`)
			end
		end
	end
	local controllers = find("StarterPlayer.StarterPlayerScripts.Controllers")
	if controllers then
		for _, child in controllers:GetChildren() do
			if not child:IsA("ModuleScript") then
				warnOf(`{pathOf(child)}: only ModuleScripts belong in Controllers`)
			else
				pass()
			end
		end
	end

	-- 4. Stray scripts: only the two bootstraps run code
	local samples = 0
	for _, rootName in SCRIPT_ROOTS do
		local ok, root = pcall(game.GetService, game, rootName)
		if not ok then
			continue
		end
		for _, descendant in (root :: Instance):GetDescendants() do
			if not descendant:IsA("BaseScript") then
				continue
			end
			local path = pathOf(descendant)
			if ENTRY_SCRIPTS[path] == descendant.ClassName then
				pass()
			elseif isSample(descendant) then
				samples += 1
			elseif isRobloxDefault(descendant) or inCharacter(descendant) then
				continue
			else
				warnOf(`stray {descendant.ClassName} {path}: only Bootstrap and ClientBootstrap are scripts; make it a module`)
			end
		end
	end
	if samples > 0 then
		table.insert(result.Notes, `{samples} script(s) in A0_ art samples (allowed until gameplay replaces them)`)
	end

	-- 5. Remotes: only the ones Shared.Remotes defines
	local remotesModule = find("ReplicatedStorage.Shared.Remotes")
	for _, rootName in { "ReplicatedStorage", "Workspace", "ReplicatedFirst" } do
		local root = game:GetService(rootName :: any) :: Instance
		for _, descendant in root:GetDescendants() do
			if
				(descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") or descendant:IsA("UnreliableRemoteEvent"))
				and descendant.Parent ~= remotesModule
			then
				warnOf(`stray remote {pathOf(descendant)}: add it to Shared.Remotes instead`)
			end
		end
	end
	if runtime and remotesModule then
		local Remotes = require(remotesModule :: ModuleScript) :: any
		for name, definition in Remotes.Definitions do
			local found = remotesModule:FindFirstChild(name)
			local className = if definition.Unreliable then "UnreliableRemoteEvent" else "RemoteEvent"
			if not Remotes.InPlace(name) then
				if found then
					fail(`remote {name} exists, but it belongs to the {definition.Place} place only`)
				else
					pass()
				end
			elseif not found then
				fail(`remote {name} wasn't created`)
			elseif found.ClassName ~= className then
				fail(`remote {name} is a {found.ClassName}, should be a {className}`)
			else
				pass()
			end
		end
		for _, child in remotesModule:GetChildren() do
			if Remotes.Definitions[child.Name] == nil then
				warnOf(`unknown remote {child.Name} under Shared.Remotes`)
			end
		end
	end

	-- 6. Config data
	local configModule = find("ReplicatedStorage.Shared.Config")
	if configModule and configModule:IsA("ModuleScript") then
		local ok, Config = pcall(require, configModule)
		if not ok then
			fail(`Config doesn't load: {Config}`)
		else
			local errors = (Config :: any).Errors()
			if #errors == 0 then
				pass()
				table.insert(result.Notes, `config types: {#(Config :: any).Types()}`)
			end
			for _, problem in errors do
				fail(`config: {problem}`)
			end
		end
	end

	-- 7. Place identity
	local constantsModule = find("ReplicatedStorage.Shared.Constants")
	if constantsModule and constantsModule:IsA("ModuleScript") then
		local Constants = require(constantsModule) :: any
		local ok, kind = pcall(Constants.PlaceKind)
		if not ok then
			fail(tostring(kind))
		else
			pass()
			table.insert(result.Notes, `place {kind} ({game.PlaceId})`)
			local attribute = workspace:GetAttribute("PlaceKind")
			if attribute ~= nil and attribute ~= kind then
				fail(`Workspace PlaceKind says {attribute} but this is {kind}`)
			end
			if buildInfo and buildInfo.Place ~= kind then
				fail(`installed build is for {buildInfo.Place}, but this place is {kind}`)
			end
		end
	end

	-- 8. Leftovers. ServerStorage.NS_Pipeline is the working folder of an outside Studio plugin
	-- (the Night Shift importer) that Landon can't remove (2026-11-08: not in Manage Plugins, its
	-- file deleted). It holds an empty Jobs folder and MeshCache, so it is only a warning; scripts
	-- inside it would be an error.
	local leftover = ServerStorage:FindFirstChild("NS_Pipeline")
	if leftover then
		local scripts = 0
		for _, item in leftover:GetDescendants() do
			if item:IsA("LuaSourceContainer") then
				scripts += 1
			end
		end
		if scripts > 0 then
			fail(`ServerStorage.NS_Pipeline (an outside plugin's folder) holds {scripts} script(s): delete it`)
		else
			warnOf("ServerStorage.NS_Pipeline is back (an outside Studio plugin's empty working folder; harmless)")
		end
	else
		pass()
	end

	-- 8b. Place settings the camera relies on (Prompt 5): Roblox's shift lock off (the camera
	-- locks the mouse itself) and Invisicam for Roblox's camera, the fallback
	local StarterPlayer = game:GetService("StarterPlayer")
	if StarterPlayer.EnableMouseLockOption then
		fail("StarterPlayer.EnableMouseLockOption must be off: the over-the-shoulder camera locks the mouse itself")
	else
		pass()
	end
	if StarterPlayer.DevCameraOcclusionMode ~= Enum.DevCameraOcclusionMode.Invisicam then
		fail("StarterPlayer.DevCameraOcclusionMode must be Invisicam (the camera's fallback, bible Section 9)")
	else
		pass()
	end

	-- 8c. The UI layout (bible Section 18, Prompt 6): the Frame (both places) and the HUD (Run)
	-- exist with every part the code uses (Shared.UIContract), ScreenGui settings per rule 7,
	-- Scale-only sizes, text that scales and never drops below 12, and no scripts inside
	local contractModule = find("ReplicatedStorage.Shared.UIContract")
	if contractModule and contractModule:IsA("ModuleScript") then
		local UIContract = require(contractModule) :: any
		local StarterGui = game:GetService("StarterGui")
		for screenName, screen in UIContract.Screens do
			local wanted = placeKind ~= nil and table.find(screen.Places, placeKind) ~= nil
			local gui = StarterGui:FindFirstChild(screenName)
			if not wanted then
				if gui then
					fail(`StarterGui.{screenName} belongs to the {table.concat(screen.Places, " and ")} place only`)
				end
				continue
			end
			if not gui or not gui:IsA("ScreenGui") then
				fail(`missing StarterGui.{screenName} (ScreenGui): build it with tools/ui_luau.py studio/ui/{screenName}.lua`)
				continue
			end
			pass()
			if
				gui.ResetOnSpawn
				or gui.ZIndexBehavior ~= Enum.ZIndexBehavior.Sibling
				or gui.ScreenInsets ~= Enum.ScreenInsets.CoreUISafeInsets
			then
				fail(`StarterGui.{screenName} needs ScreenInsets CoreUISafeInsets, ResetOnSpawn off and ZIndexBehavior Sibling (bible Section 18)`)
			else
				pass()
			end
			if gui.DisplayOrder ~= screen.DisplayOrder then
				warnOf(`StarterGui.{screenName} DisplayOrder is {gui.DisplayOrder}, expected {screen.DisplayOrder}`)
			end
			local missing = {}
			for _, path in screen.Paths do
				if UIContract.Find(gui, path) then
					pass()
				else
					table.insert(missing, path)
				end
			end
			if #missing > 0 then
				fail(`StarterGui.{screenName} lacks {#missing} part(s) the code uses: {table.concat(missing, ", ", 1, math.min(#missing, 6))}`)
			end
			local offsets, unreadable, scripts = 0, 0, 0
			for _, item in gui:GetDescendants() do
				if item:IsA("GuiObject") then
					local size, position = item.Size, item.Position
					if size.X.Offset ~= 0 or size.Y.Offset ~= 0 or position.X.Offset ~= 0 or position.Y.Offset ~= 0 then
						offsets += 1
					end
				end
				if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
					local limit = item:FindFirstChildOfClass("UITextSizeConstraint")
					if not (item :: any).TextScaled or not limit or limit.MinTextSize < 12 then
						unreadable += 1
					end
				end
				if item:IsA("BaseScript") then
					scripts += 1
				end
			end
			if offsets > 0 then
				fail(`StarterGui.{screenName}: {offsets} element(s) use pixel offsets; all UI is Scale (bible Section 18)`)
			else
				pass()
			end
			if unreadable > 0 then
				fail(`StarterGui.{screenName}: {unreadable} text element(s) without TextScaled and a UITextSizeConstraint of at least 12`)
			else
				pass()
			end
			if scripts > 0 then
				fail(`StarterGui.{screenName} holds {scripts} script(s); the game code drives the UI`)
			else
				pass()
			end
		end
	end

	-- 9. The architecture document
	local doc = find("ServerStorage.Documentation.ARCHITECTURE")
	if doc and doc:IsA("ModuleScript") then
		local ok, text = pcall(require, doc)
		if ok and type(text) == "string" and #text > 200 then
			pass()
		else
			fail("Documentation.ARCHITECTURE must return the document text")
		end
	end

	-- 10. The boot result
	if runtime then
		if ReplicatedStorage:GetAttribute("ServerReady") == true then
			pass()
		else
			fail("ServerReady isn't set: Bootstrap didn't finish")
		end
		local broken = ReplicatedStorage:GetAttribute("ServerBroken")
		if broken then
			fail(`services that failed to start: {broken}`)
		end
		local DevTools = ServerScriptService:FindFirstChild("DevTools")
		if DevTools and not DevTools:FindFirstChild("Invoke") and game:GetService("RunService"):IsStudio() then
			warnOf("DevTools.Invoke wasn't created (DevService didn't start?)")
		end
		-- The run's replicated values (Run place): set, and each one allowed
		local runStateModule = find("ReplicatedStorage.Shared.RunState")
		if placeKind == "Run" and runStateModule and runStateModule:IsA("ModuleScript") then
			local RunState = require(runStateModule) :: any
			if RunState.Get("RunPhase") == nil then
				fail("RunState.RunPhase isn't set: RunDirector didn't start")
			else
				pass()
			end
			for name, value in runStateModule:GetAttributes() do
				local ok, why = RunState.Check(name, value)
				if ok then
					pass()
				else
					fail(`RunState: {why}`)
				end
			end
		end
		-- The bunker's world (Run place): BunkerGrid built it
		if placeKind == "Run" then
			local bunker = workspace:FindFirstChild("Bunker")
			if not bunker then
				fail("workspace.Bunker is missing: BunkerGrid didn't build the bunker")
			else
				for _, name in { "Frame", "Rock", "Dug", "Rooms" } do
					if bunker:FindFirstChild(name) then
						pass()
					else
						fail(`workspace.Bunker.{name} is missing`)
					end
				end
				local rooms = bunker:FindFirstChild("Rooms")
				if rooms and #rooms:GetChildren() == 0 then
					fail("workspace.Bunker.Rooms is empty")
				end
				-- Every room carries its gameplay points; the art kit, when the place has it,
				-- built every room; the Medbay has the spawn and the Blast Door its exit.
				local ServerStorage = game:GetService("ServerStorage")
				local assets = ServerStorage:FindFirstChild("Assets")
				local kit = assets and assets:FindFirstChild("Kit")
				local hasArt = kit ~= nil and kit:FindFirstChild("Kit_Floor") ~= nil
				for _, room in if rooms then rooms:GetChildren() else {} do
					local kind = room:GetAttribute("RoomType")
					local sockets = room:FindFirstChild("Sockets")
					if sockets and sockets:IsA("BasePart") then
						pass()
					else
						fail(`room {room.Name} ({kind}) has no Sockets part`)
					end
					if hasArt and room:GetAttribute("Art") ~= true then
						fail(`room {room.Name} ({kind}) was built from the graybox although the art kit is in ServerStorage.Assets`)
					elseif hasArt then
						pass()
					end
					if kind == "Medbay" then
						if room:FindFirstChild("MedbaySpawn") then
							pass()
						else
							fail(`Medbay {room.Name} has no MedbaySpawn`)
						end
					elseif kind == "BlastDoor" then
						if sockets and sockets:FindFirstChild("SurfaceExit") then
							pass()
						else
							fail(`Blast Door {room.Name} has no SurfaceExit socket`)
						end
					end
				end
			end
		end
	end

	return result
end

function StructureCheck.Format(result: Result): string
	local lines = {
		`StructureCheck: {#result.Errors} errors, {#result.Warnings} warnings, {result.Passed} checks passed`,
	}
	for _, message in result.Errors do
		table.insert(lines, `  ERROR {message}`)
	end
	for _, message in result.Warnings do
		table.insert(lines, `  warn  {message}`)
	end
	for _, message in result.Notes do
		table.insert(lines, `  note  {message}`)
	end
	return table.concat(lines, "\n")
end

return StructureCheck
