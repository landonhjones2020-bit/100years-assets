--!nonstrict
--[[
	CodeInstaller (Studio tooling, not game code): installs a build of the game code asset into
	this place. Lives in ServerStorage.Tooling so each install is one line through the
	connector:

		return require(game.ServerStorage.Tooling.CodeInstaller)(95026446991297, "Run")

	It refuses if a script was edited in Studio since the last install (pass force = true to
	overwrite), replaces the managed folders wholesale, and returns StructureCheck and the
	data tests. Kept in the repo as studio/CodeInstaller.lua; reinstall with
	`python3 tools/game_sync.py tooling`.
]]

return function(ASSET_ID, PLACE, FORCE)
	local InsertService = game:GetService("InsertService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	local ServerStorage = game:GetService("ServerStorage")
	local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
	local PLACE_IDS = { Lobby = 135073046693952, Run = 72892455946761 }
	if game.PlaceId ~= 0 and PLACE_IDS[PLACE] ~= game.PlaceId then
		return "NOT INSTALLED: this studio is place " .. game.PlaceId .. ", not " .. PLACE
	end
	local tools = ServerScriptService:FindFirstChild("DevTools")
	local oldCheck = tools and tools:FindFirstChild("StructureCheck")
	if oldCheck and not FORCE then
		local ok, check = pcall(require, oldCheck)
		if ok then
			local edited = {}
			for _, line in check.Run({ Sources = true }).Warnings do
				if string.find(line, "edited in Studio", 1, true) then
					table.insert(edited, line)
				end
			end
			if #edited > 0 then
				return "NOT INSTALLED (bring these edits into the repo, or pass --force):\n" .. table.concat(edited, "\n")
			end
		end
	end
	local model = InsertService:LoadAssetVersion(InsertService:GetLatestAssetVersionAsync(ASSET_ID))
	local root = model:FindFirstChild(PLACE)
	if not root then
		model:Destroy()
		return "NOT INSTALLED: the build has no " .. PLACE .. " tree"
	end
	for _, item in model:GetDescendants() do
		if item:IsA("PackageLink") then
			item:Destroy()
		end
	end
	local function replaceChildren(from, into)
		for _, item in from:GetChildren() do
			local old = into:FindFirstChild(item.Name)
			if old then
				old:Destroy()
			end
			item.Parent = into
		end
	end
	replaceChildren(root.ReplicatedStorage, ReplicatedStorage)
	replaceChildren(root.ServerScriptService, ServerScriptService)
	replaceChildren(root.StarterPlayerScripts, StarterPlayerScripts)
	replaceChildren(root.ServerStorage, ServerStorage)
	model:Destroy()
	workspace:SetAttribute("PlaceKind", PLACE)
	local leftover = ServerStorage:FindFirstChild("NS_Pipeline")
	if leftover then
		leftover:Destroy()
	end
	local check = require(ServerScriptService.DevTools.StructureCheck)
	local tests = require(ServerScriptService.DevTools.DataTests)
	local info = require(ReplicatedStorage.Shared.BuildInfo)
	return "installed " .. info.Label .. " in " .. PLACE .. "\n" .. check.Format(check.Run({ Sources = true }))
		.. "\n" .. tests.Format(tests.Run())
end
