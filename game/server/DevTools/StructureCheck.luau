--!strict
--[[
	StructureCheck: is the place built the way Documentation.ARCHITECTURE says?

	Checks the code skeleton, every installed file in BuildInfo, the service dependency
	graph, stray scripts and remotes, Config data, place identity and leftovers that must
	never be here (ServerStorage.NS_Pipeline from the Night Shift importer plugin).

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
	{ "ReplicatedStorage.Shared.Config", "ModuleScript" },
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
	{ "ServerStorage.Documentation", "Folder" },
	{ "ServerStorage.Documentation.ARCHITECTURE", "ModuleScript" },
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

	-- 1. The skeleton
	for _, item in SKELETON do
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
			if not found then
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

	-- 8. Leftovers that must never be here
	if ServerStorage:FindFirstChild("NS_Pipeline") then
		fail("ServerStorage.NS_Pipeline exists: the Night Shift importer plugin is still active; delete the folder and disable the plugin")
	else
		pass()
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
