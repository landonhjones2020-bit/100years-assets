--!strict
--[[
	BuildService: construction, upgrades, merges and teardown (bible Sections 6 and 8). Run
	place only.

	* Proposing: a player proposes from the Command View (the Propose remote).
	  Rules.Construction.Plan checks it against the bunker, the unlocks, the stockpile, Lab
	  research, and the cells already held by open votes and construction sites. Then
	  VoteService puts it to the team (in a solo run it applies at once).
	* When the vote passes, it is planned again (anything may have changed meanwhile) and paid
	  for (EconomyService), and then:
	  * Build: a construction site goes on the cell. It takes 20 s a cell
	    (Tuning.Rooms.BuildSecondsPerCell), 25% faster for every player standing in it
	    (HelperBuildSpeed; residents join with Prompt 10). When it's done the room is placed
	    (BunkerGrid).
	  * Upgrade: the room's level goes up at once (Landon, Nov 8, 2026). On a difficulty with
	    UpgradesTakeTime (Nightmare) it becomes a construction site over the room instead, as
	    long as building would take; the room keeps working at its old level until it is done.
	  * Merge: the two rooms become one at once.
	  * TearDown: the room goes at once and its cells are open cells again. Part of what it cost
	    comes back (Landon, Nov 8, 2026): the plan's Refund, Tuning.Rooms.TearDownRefund of every
	    level's cost so far (Rules.Construction.Refund), up to the stockpile's caps.
	* Sites replicate in the Sites collection: id -> { Kind ("Build" or "Upgrade"), Type, Floor,
	  Column, Span, Level (an upgrade's new level), RoomId (an upgrade's room), Progress (0 to
	  1), Helpers, Seconds }. In the world they stand in workspace.Bunker.Sites (BunkerKit.Site).
	* Rooms won from blueprint drafts and cryo pods: Unlock(roomType) (Prompts 17 and 19). They
	  replicate in the Unlocked collection (room type -> true) for the Command View's menu.
	Repairs come with Prompt 13.

	API:
		BuildService:Propose(player, proposal): (boolean, string?)
		BuildService:Unlock(roomType), :Unlocked(): { [string]: boolean }
		BuildService:Reserved(exceptVoteId?): { [string]: boolean }  -- votes' and sites' cells
		BuildService:FinishSite(id): boolean                           -- DevTools
		BuildService.Proposed: Signal<Player, string>   -- proposer, action (first-run objective 2)
		BuildService.Built: Signal<string, string>      -- room id, action (Build, Upgrade, Merge)
		BuildService.TornDown: Signal<string, string>   -- room id, room type
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Construction = require(Shared.Rules.Construction)
local Grid = require(Shared.Rules.Grid)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local RunState = require(Shared.RunState)
local Signal = require(Shared.Utilities.Signal)
local BunkerKit = require(ServerScriptService.Lib.BunkerKit)

local log = Log.new("BuildService")

local BuildService = {
	Name = "BuildService",
	Dependencies = { "BunkerGrid", "EconomyService", "VoteService", "SessionService", "RunDirector", "ReplicationService", "DevService" },
	Proposed = Signal.new() :: Signal.Signal<Player, string>,
	Built = Signal.new() :: Signal.Signal<string, string>,
	TornDown = Signal.new() :: Signal.Signal<string, string>,
}

type Site = {
	Id: string,
	Kind: "Build" | "Upgrade",
	RoomId: string?, -- Upgrade: the room
	Level: number?, -- Upgrade: its new level
	Type: string,
	Floor: number,
	Column: number,
	Span: number,
	Cells: { string },
	Seconds: number,
	Done: number, -- seconds of work done (helpers make it grow faster)
	Helpers: number,
	Sent: number, -- the progress last replicated
	Model: Model?,
}

local grid: any = nil
local economy: any = nil
local votes: any = nil
local session: any = nil
local director: any = nil
local sitesCollection: any = nil
local unlockedCollection: any = nil
local sites: { [string]: Site } = {}
local siteCount = 0
local unlocked: { [string]: boolean } = {}

local function roomName(roomType: string): string
	return Config.Get("Rooms", roomType).Name
end

local function alert(player: Player, kind: string, text: string)
	Remotes.FireClient("Alert", player, kind, text)
end

local function announce(text: string)
	Remotes.FireClients("Alert", session:ReadyPlayers(), "Info", text)
end

-- "The stockpile is 70 Scrap short." -> "the stockpile is 70 Scrap short" (the banner adds FAILED:)
local function clause(text: string): string
	local trimmed = string.gsub(text, "%.$", "")
	return (string.gsub(trimmed, "^%u", string.lower))
end

function BuildService:Reserved(exceptVoteId: string?): { [string]: boolean }
	local cells = votes:Reserved(exceptVoteId)
	for _, site in sites do
		for _, key in site.Cells do
			cells[key] = true
		end
	end
	return cells
end

local function context(exceptVoteId: string?): Construction.Context
	return {
		Era = table.find(Config.Ids("Eras"), RunState.Get("Era") or "") or 1,
		Deepest = grid:DeepestFloor(),
		Unlocked = unlocked,
		Stock = economy:Stock(),
		Research = economy:Research(),
		Reserved = BuildService:Reserved(exceptVoteId),
	}
end

-- Sites ---------------------------------------------------------------------------------------------

local function publishSite(site: Site)
	local progress = math.floor(math.min(1, site.Done / site.Seconds) * 100) / 100
	site.Sent = progress
	sitesCollection:Set(site.Id, {
		Kind = site.Kind,
		RoomId = site.RoomId,
		Level = site.Level,
		Type = site.Type,
		Floor = site.Floor,
		Column = site.Column,
		Span = site.Span,
		Progress = progress,
		Helpers = site.Helpers,
		Seconds = site.Seconds,
	})
end

local function sitesFolder(): Instance?
	local root = grid:Root()
	if not root then
		return nil
	end
	local folder = root:FindFirstChild("Sites")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Sites"
		folder.Parent = root
	end
	return folder
end

local function startSite(plan: Construction.Plan)
	siteCount += 1
	local upgrade = plan.Action == "Upgrade"
	local site: Site = {
		Id = `S{siteCount}`,
		Kind = if upgrade then "Upgrade" else "Build",
		RoomId = if upgrade then plan.RoomId else nil,
		Level = if upgrade then plan.Level else nil,
		Type = plan.RoomType,
		Floor = plan.Floor,
		Column = plan.Column,
		Span = plan.Span,
		Cells = Construction.Cells(plan),
		Seconds = Construction.Seconds(plan.Span),
		Done = 0,
		Helpers = 0,
		Sent = -1,
	}
	local folder = sitesFolder()
	if folder then
		site.Model = BunkerKit.Site(folder, site.Id, site.Type, site.Floor, site.Column, site.Span, upgrade)
	end
	sites[site.Id] = site
	publishSite(site)
	if upgrade then
		log:Info("%s: upgrading %s to level %d (%d s)", site.Id, tostring(site.RoomId), site.Level or 0, site.Seconds)
		announce(`UPGRADING THE {string.upper(roomName(site.Type))}: STAND IN IT TO HELP`)
	else
		log:Info("%s: building a %s at %s (%d s)", site.Id, site.Type, Grid.Key(site.Floor, site.Column), site.Seconds)
		announce(`BUILDING A {string.upper(roomName(site.Type))}: STAND IN IT TO HELP`)
	end
end

local function upgradeNow(roomId: string, roomType: string, level: number)
	local ok, err = grid:SetLevel(roomId, level)
	if ok then
		announce(`{string.upper(roomName(roomType))} UPGRADED TO LEVEL {level}`)
		BuildService.Built:Fire(roomId, "Upgrade")
	else
		log:Warn("upgrade of %s failed: %s", roomId, tostring(err))
	end
end

local function finishSite(site: Site)
	sites[site.Id] = nil
	sitesCollection:Remove(site.Id)
	if site.Model then
		site.Model:Destroy()
	end
	if site.Kind == "Upgrade" then
		log:Info("%s done: %s is level %d", site.Id, tostring(site.RoomId), site.Level or 0)
		upgradeNow(site.RoomId :: string, site.Type, site.Level :: number)
		return
	end
	local roomId, why = grid:PlaceRoom(site.Type, site.Floor, site.Column, site.Span)
	if roomId then
		log:Info("%s done: %s is %s", site.Id, site.Type, roomId)
		announce(`{string.upper(roomName(site.Type))} BUILT`)
		BuildService.Built:Fire(roomId, "Build")
	else
		log:Warn("%s couldn't place its %s: %s", site.Id, site.Type, tostring(why))
	end
end

function BuildService:FinishSite(id: string): boolean
	local site = sites[id]
	if not site then
		return false
	end
	finishSite(site)
	return true
end

-- Players standing in a site's cells (alive).
local function helpersAt(site: Site): number
	local n = 0
	for _, player in session:ReadyPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			local floor, column = Grid.CellAt(root.Position)
			if floor == site.Floor and column and column >= site.Column and column < site.Column + site.Span then
				n += 1
			end
		end
	end
	return n
end

local function tick(dt: number)
	for _, site in sites do
		site.Helpers = helpersAt(site)
		site.Done += dt * Construction.Rate(site.Helpers)
		if site.Done >= site.Seconds then
			finishSite(site)
		else
			local progress = site.Done / site.Seconds
			if site.Model then
				BunkerKit.SetSiteProgress(site.Model, progress)
			end
			local current = sitesCollection:Get(site.Id)
			if progress - site.Sent >= 0.01 or (current and current.Helpers ~= site.Helpers) then
				publishSite(site)
			end
		end
	end
end

-- Applying a passed proposal ------------------------------------------------------------------------

local function apply(plan: Construction.Plan)
	local paid, why = economy:Spend(plan.Costs, plan.Label)
	if not paid then
		log:Warn("%s passed but couldn't be paid: %s", plan.Label, tostring(why))
		announce(`{plan.Label}: {string.upper(why or "can't pay")}`)
		return
	end
	if plan.Action == "Build" then
		startSite(plan)
	elseif plan.Action == "Upgrade" then
		local difficulty = Config.Find("Difficulties", director:Difficulty())
		if difficulty and difficulty.UpgradesTakeTime then
			startSite(plan)
		else
			upgradeNow(plan.RoomId :: string, plan.RoomType, plan.Level :: number)
		end
	elseif plan.Action == "Merge" then
		local merged, err = grid:MergeRooms(plan.RoomId :: string, plan.Other :: string)
		if merged then
			announce(`{string.upper(roomName(plan.RoomType))} MERGED`)
			BuildService.Built:Fire(merged, "Merge")
		else
			log:Warn("merge of %s and %s failed: %s", tostring(plan.RoomId), tostring(plan.Other), tostring(err))
		end
	elseif plan.Action == "TearDown" then
		local roomId = plan.RoomId :: string
		local ok, err = grid:RemoveRoom(roomId)
		if ok then
			local back = {}
			for _, id in Config.Ids("Resources") do
				local amount = plan.Refund and plan.Refund[id]
				if amount and amount > 0 then
					local added = economy:Add(id, amount, `refund for {plan.Label}`)
					if added > 0 then
						back[id] = added
					end
				end
			end
			announce(if next(back) then `{string.upper(roomName(plan.RoomType))} TORN DOWN: {Construction.CostText(back)} BACK`
				else `{string.upper(roomName(plan.RoomType))} TORN DOWN`)
			BuildService.TornDown:Fire(roomId, plan.RoomType)
		else
			log:Warn("teardown of %s failed: %s", roomId, tostring(err))
		end
	end
end

-- Proposals ------------------------------------------------------------------------------------------

-- The ghost outline's label in the Command View: "KITCHEN?", "LEVEL 2?", "MERGE?", "TEAR DOWN?".
local function ghostLabel(plan: Construction.Plan): string
	if plan.Action == "Build" then
		return `{string.upper(roomName(plan.RoomType))}?`
	elseif plan.Action == "Upgrade" then
		return `LEVEL {plan.Level}?`
	elseif plan.Action == "Merge" then
		return "MERGE?"
	end
	return "TEAR DOWN?"
end

function BuildService:Propose(player: Player, proposal: Construction.Proposal): (boolean, string?)
	local ok, why = votes:CanPropose(player)
	if not ok then
		return false, why
	end
	local plan, reason = Construction.Plan(grid:Bunker(), proposal, context(nil))
	if not plan then
		return false, reason
	end
	local voteId: string? = nil
	local latest: Construction.Plan = plan
	local id, err = votes:Open({
		Kind = "Build",
		Proposer = player,
		Title = plan.Label,
		Costs = plan.Costs,
		Refund = plan.Refund,
		Subject = { Floor = plan.Floor, Column = plan.Column, Span = plan.Span, Label = ghostLabel(plan) },
		Cells = Construction.Cells(plan),
		Check = function(): (boolean, string?)
			local again, why2 = Construction.Plan(grid:Bunker(), proposal, context(voteId))
			if again then
				latest = again
				return true, nil
			end
			return false, clause(why2 or "it can't be done any more")
		end,
		OnPass = function()
			apply(latest)
		end,
	})
	if not id then
		return false, err
	end
	voteId = id
	log:Info("%s proposed %s (%s)", player.Name, plan.Label, id)
	BuildService.Proposed:Fire(player, plan.Action)
	return true, nil
end

function BuildService:Unlock(roomType: string)
	assert(Config.Find("Rooms", roomType), `BuildService: no room type {roomType}`)
	unlocked[roomType] = true
	unlockedCollection:Set(roomType, true)
end

function BuildService:Unlocked(): { [string]: boolean }
	return table.clone(unlocked)
end

-- Lifecycle ------------------------------------------------------------------------------------------

local function describeSites(): string
	local lines = {}
	for id, site in sites do
		table.insert(lines, string.format("%s %s %s at %s: %.0f%% (%d helping, %.1f of %d s)", id, site.Kind, site.Type,
			Grid.Key(site.Floor, site.Column), math.min(1, site.Done / site.Seconds) * 100, site.Helpers, site.Done, site.Seconds))
	end
	table.sort(lines)
	return if #lines > 0 then table.concat(lines, "\n") else "no construction sites"
end

function BuildService:Init(registry)
	grid = registry.BunkerGrid
	economy = registry.EconomyService
	votes = registry.VoteService
	session = registry.SessionService
	director = registry.RunDirector
	sitesCollection = registry.ReplicationService:Collection("Sites")
	unlockedCollection = registry.ReplicationService:Collection("Unlocked")
	Remotes.OnServer("Propose", function(player: Player, action: string, floor: number, column: number, detail: string)
		local proposal: Construction.Proposal = {
			Action = action :: Construction.Action,
			Floor = floor,
			Column = column,
			RoomType = if action == "Build" then detail else nil,
			Other = if action == "Merge" then detail else nil,
		}
		local ok, why = BuildService:Propose(player, proposal)
		if not ok and why then
			alert(player, "Warning", why)
		end
	end)
	local dev = registry.DevService
	dev:Register("build", {
		Description = "Propose construction as you would from the Command View.",
		Usage = "build <Build|Upgrade|Merge|TearDown> <floor> <column> [roomType|otherRoomId]",
		Run = function(caller: Player?, args): string?
			-- from Studio's server tools there's no caller: act as the first player in the run
			local player = caller or session:ReadyPlayers()[1]
			if not player then
				return "nobody is in the run to propose as"
			end
			local action, floor, column = tostring(args[1] or ""), tonumber(args[2]), tonumber(args[3])
			if not table.find({ "Build", "Upgrade", "Merge", "TearDown" }, action) or not floor or not column then
				return "usage: build <Build|Upgrade|Merge|TearDown> <floor> <column> [roomType|otherRoomId]"
			end
			local detail = if args[4] ~= nil then tostring(args[4]) else nil
			local ok, why = BuildService:Propose(player, {
				Action = action :: Construction.Action,
				Floor = floor,
				Column = column,
				RoomType = if action == "Build" then detail else nil,
				Other = if action == "Merge" then detail else nil,
			})
			return if ok then `proposed\n{describeSites()}` else `refused: {why}`
		end,
	})
	dev:Register("sites", {
		Description = "Construction sites and their progress.",
		Usage = "sites",
		Run = function(): string?
			return describeSites()
		end,
	})
	dev:Register("site.finish", {
		Description = "Finish a construction site now (or every site).",
		Usage = "site.finish [id]",
		Run = function(_player: Player, args): string?
			local id = if args[1] ~= nil then tostring(args[1]) else nil
			local done = 0
			for siteId in table.clone(sites) do
				if id == nil or siteId == id then
					if BuildService:FinishSite(siteId) then
						done += 1
					end
				end
			end
			return `finished {done} site(s)\n{describeSites()}`
		end,
	})
	dev:Register("unlock", {
		Description = "Unlock a room type as if a blueprint draft had won it.",
		Usage = "unlock <roomType>",
		Run = function(_player: Player, args): string?
			local roomType = tostring(args[1] or "")
			if not Config.Find("Rooms", roomType) then
				return "usage: unlock <roomType>"
			end
			BuildService:Unlock(roomType)
			return `unlocked {roomType}`
		end,
	})
end

function BuildService:Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= 0.25 then
			tick(acc)
			acc = 0
		end
	end)
end

return BuildService
