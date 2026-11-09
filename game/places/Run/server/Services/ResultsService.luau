--!strict
--[[
	ResultsService: the run's results (bible Sections 5, 16, 18 and 21). Run place only; Prompt 15.
	The arithmetic is Shared.Rules.Results; payouts are Config.GlowshardRewards, the difficulty's
	PayoutMultiplier and Tuning.Account; the MVP weights are Tuning.Results.

	* While the run plays it counts each player's part (damage to monsters, kills, damage to
	  bosses, revives, cells dug, repairs) and the team's (monsters killed, cells dug, rooms built,
	  residents lost, disasters, bosses beaten), and keeps the run's story: the moments worth
	  telling, each with its year (a boss beaten, a resident's death, a Push Deeper, a Tremor, a
	  meltdown stopped, the end).
	* The Deep (Prompt 17): caves found, Lost Crews brought home and cryo pods thawed go in the
	  story; so do expeditions home, distress calls answered and recruits (Prompt 18); Glowshard chests pay when they are opened (DeepService), and the results show them as
	  a line of their own (already paid).
	* When the run ends (RunDirector.RunEnded) it pays everyone still in it: Glowshards
	  (Rules.Results.Payout: years, depth bands, a victory, bosses, the difficulty, the first win of
	  the day), account experience and levels, the profile's Stats (Runs, Wins, BestYear, Deepest,
	  BossesKilled, MonstersKilled, LastWinDay) and FirstRunDone, then saves. A run that ends again
	  after Keep Going pays only what is new (a ledger per player).
	* It publishes the Results collection ("Run" -> the results below) for the results screen.
	* The results screen's buttons (Section 21): Play Again opens a team vote (Config.Votes
	  PlayAgain; solo applies at once) that sends everyone to a fresh Run server; Keep Going, after a
	  victory, opens the Keep Going vote (Endless, RunDirector:KeepGoing); Return to Lobby sends the
	  player to the lobby. Teleports don't work in Studio: there it says so. Prompt 21 adds the
	  party list and loadouts in MemoryStore.

	Results: { Outcome, DefeatReason, Victory, Endless, Year, Cycle, Era, Difficulty, Seconds,
	DeepestFloor, Band, Team = { MonstersKilled, CellsDug, RoomsBuilt, ResidentsAlive, ResidentsLost,
	Disasters, Hauled, Rescued, Bosses }, Stories = { string }, MVP = user id (string) or nil, Players = { [user id]
	= { Name, Class, Damage, Kills, BossDamage, Revives, CellsDug, Repairs, Hauled, Rescues, Score, Glowshards,
	Lines = { { Text, Amount } }, XP, Level, LevelUp, Paid } }, At }.

	Dev: results, results.pay.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Grid = require(Shared.Rules.Grid)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local Residents = require(Shared.Rules.Residents)
local Results = require(Shared.Rules.Results)
local RunState = require(Shared.RunState)

local log = Log.new("ResultsService")

local ResultsService = {
	Name = "ResultsService",
	Dependencies = {
		"RunDirector", "CycleClock", "SessionService", "ProfileService", "CombatService", "MonsterService", "ResidentService",
		"BuildService", "DigService", "DisasterService", "ObjectiveService", "BossService", "BunkerGrid", "VoteService",
		"InventoryService", "RescueService", "DeepService", "ExpeditionService", "ReplicationService", "DevService",
	},
}

local STAT_KEYS = { "Damage", "Kills", "BossDamage", "Revives", "CellsDug", "Repairs", "Hauled", "Rescues" } -- Hauled, Rescues: Prompt 16

local director: any = nil
local clock: any = nil
local session: any = nil
local profiles: any = nil
local combat: any = nil
local residents: any = nil
local objectives: any = nil
local grid: any = nil
local votes: any = nil
local collection: any = nil

local stats: { [number]: { [string]: number } } = {} -- user id -> stats
local names: { [number]: string } = {}
local team = { MonstersKilled = 0, CellsDug = 0, RoomsBuilt = 0, ResidentsLost = 0, Disasters = 0, Hauled = 0, Rescued = 0 }
local bosses: { string } = {}
local stories: { string } = {}
local lastHit: { [string]: string } = {} -- combatant id -> who hit it last ("P<user id>")
local ledgers: { [number]: Results.Ledger } = {}
local paidKills: { [number]: number } = {} -- kills already added to the profile's MonstersKilled
local counted: { [number]: boolean } = {} -- the run counted in the profile's Runs
local deepest = 0
local chestShards: { [number]: number } = {} -- user id -> Glowshards from chests (paid when opened, Prompt 17)
local bandsWithCaves: { [string]: boolean } = {}
local voteOpen: { [string]: string } = {} -- vote kind -> id
local published: { [string]: any }? = nil

-- Counting -------------------------------------------------------------------------------------------

local function userOf(source: string?): number?
	if source and string.sub(source, 1, 1) == "P" then
		return tonumber(string.sub(source, 2))
	end
	return nil
end

local function bump(userId: number?, key: string, amount: number)
	if not userId then
		return
	end
	local s = stats[userId]
	if not s then
		s = {}
		for _, k in STAT_KEYS do
			s[k] = 0
		end
		stats[userId] = s
	end
	s[key] = (s[key] or 0) + amount
end

local function story(text: string)
	local year = clock:Year()
	table.insert(stories, `Year {year} · {text}`)
	local max = Results.Tuning().StoriesMax * 3
	if #stories > max then
		table.remove(stories, 1)
	end
end

local function residentName(id: string): string
	local r = residents:Get(id)
	return if r then Residents.Name(r) else "A resident"
end

-- The results -------------------------------------------------------------------------------------------

local function playerClass(player: Player): string
	local class = player:GetAttribute("Class")
	local entry = if type(class) == "string" then Config.Find("Classes", class) else nil
	return if entry then entry.Name else "Survivor"
end

local function teamNumbers(): { [string]: any }
	local alive, lost = 0, 0
	for _, r in residents:All() do
		if r.State == "Dead" then
			lost += 1
		else
			alive += 1
		end
	end
	local names_ = {}
	for _, bossId in bosses do
		table.insert(names_, Config.Get("Bosses", bossId).Name)
	end
	return {
		MonstersKilled = team.MonstersKilled,
		CellsDug = team.CellsDug,
		RoomsBuilt = team.RoomsBuilt,
		ResidentsAlive = alive,
		ResidentsLost = lost,
		Disasters = team.Disasters,
		Hauled = team.Hauled,
		Rescued = team.Rescued,
		Bosses = names_,
	}
end

local function endingStory(summary: any): string
	if summary.Outcome == "CenturyVictory" then
		return "The blast door opens on a clearing sky: a Century Victory"
	elseif summary.Outcome == "DeepVictory" then
		return "The Source is destroyed in its chamber: a Deep Victory"
	elseif summary.DefeatReason == "ReactorDestroyed" then
		return "The Reactor Core melted down and the bunker fell"
	elseif summary.DefeatReason == "ResidentsLost" then
		return "The last resident died and the bunker fell"
	end
	return "The run ended"
end

-- Pays one player and returns their row of the results.
local function pay(player: Player, summary: any, run: Results.Run): { [string]: any }
	local userId = player.UserId
	names[userId] = player.DisplayName
	local s = stats[userId] or {}
	local paid = ledgers[userId] or Results.EmptyLedger()
	local profile = profiles:Get(player)
	local today = Results.Day(os.time())
	local stats_ = if profile then profile.Stats else {}
	local firstWinToday = run.Victory ~= nil and (stats_.LastWinDay or -1) ~= today
	local payout = Results.Payout(run, paid, { FirstWinToday = firstWinToday })
	local xp = Results.AccountXP(run.Year, paid.Years)
	local level, levelUp = if profile then profile.AccountLevel else 1, false
	local ok = true
	if profile then
		ok = profiles:Update(player, function(data)
			data.Glowshards += payout.Total
			local newLevel, newXP = Results.LevelUp(data.AccountLevel, data.AccountXP, xp)
			levelUp = newLevel > data.AccountLevel
			data.AccountLevel, data.AccountXP = newLevel, newXP
			level = newLevel
			local st = data.Stats
			if not counted[userId] then
				st.Runs = (st.Runs or 0) + 1
			end
			if run.Victory and not paid.Victory then
				st.Wins = (st.Wins or 0) + 1
				st.LastWinDay = today
			end
			st.BestYear = math.max(st.BestYear or 0, run.Year)
			st.Deepest = math.max(st.Deepest or 0, run.DeepestFloor)
			local newBosses = 0
			for _, bossId in run.Bosses do
				if not paid.Bosses[bossId] then
					newBosses += 1
				end
			end
			st.BossesKilled = (st.BossesKilled or 0) + newBosses
			st.MonstersKilled = (st.MonstersKilled or 0) + math.max(0, (s.Kills or 0) - (paidKills[userId] or 0))
			data.FirstRunDone = true
		end)
	end
	if ok then
		ledgers[userId] = payout.Ledger
		paidKills[userId] = s.Kills or 0
		counted[userId] = true
		log:Info("%s paid %d Glowshards and %d experience (%s)", player.Name, payout.Total, xp, summary.Outcome or "?")
		task.spawn(function()
			profiles:SaveNow(player)
		end)
	else
		log:Warn("%s: the payout couldn't be written", player.Name)
	end
	local lines = table.clone(payout.Lines)
	local fromChests = chestShards[userId] or 0
	if fromChests > 0 then
		table.insert(lines, { Text = "Glowshard chests (paid when opened)", Amount = fromChests })
	end
	local row: { [string]: any } = {
		Name = player.DisplayName,
		Class = playerClass(player),
		Score = Results.Score(s),
		Glowshards = (if ok then payout.Total else 0) + fromChests,
		Lines = lines,
		XP = xp,
		Level = level,
		LevelUp = levelUp,
		Paid = ok and profile ~= nil,
	}
	for _, key in STAT_KEYS do
		row[key] = math.floor((s[key] or 0) + 0.5)
	end
	return row
end

local function build(summary: any)
	deepest = math.max(deepest, grid:DeepestFloor())
	local run: Results.Run = {
		Year = summary.Year,
		DeepestFloor = deepest,
		Victory = summary.Victory,
		Bosses = table.clone(bosses),
		Difficulty = summary.Difficulty,
	}
	story(endingStory(summary))
	local rows = {}
	local scoring: { [number]: { [string]: number } } = {}
	for _, player in session:ReadyPlayers() do
		rows[tostring(player.UserId)] = pay(player, summary, run)
		scoring[player.UserId] = stats[player.UserId] or {}
	end
	local mvp = Results.MVP(scoring)
	local shown = {}
	local max = Results.Tuning().StoriesMax
	for i = math.max(1, #stories - max + 1), #stories do
		table.insert(shown, stories[i])
	end
	local band = if deepest >= 1 then Grid.BandOf(deepest).Name else "Mines"
	published = {
		Outcome = summary.Outcome,
		DefeatReason = summary.DefeatReason,
		Victory = summary.Victory,
		Endless = summary.Endless,
		Year = summary.Year,
		Cycle = summary.Cycle,
		Era = summary.Era,
		Difficulty = summary.Difficulty,
		Seconds = math.floor(summary.Seconds),
		DeepestFloor = deepest,
		Band = band,
		Team = teamNumbers(),
		Stories = shown,
		MVP = if mvp then tostring(mvp) else nil,
		Players = rows,
		At = workspace:GetServerTimeNow(),
	}
	collection:Set("Run", published)
	log:Info("results: %s in Year %d, %d players, MVP %s", tostring(summary.Outcome), summary.Year, #session:ReadyPlayers(),
		if mvp then tostring(mvp) else "-")
end

-- The results screen's buttons ------------------------------------------------------------------------------

local function alert(player: Player, kind: string, text: string)
	Remotes.FireClient("Alert", player, kind, text)
end

local function teleport(placeId: number, list: { Player }, reserved: boolean): (boolean, string?)
	if RunService:IsStudio() then
		return false, "TELEPORTS DON'T WORK IN STUDIO"
	end
	local options = Instance.new("TeleportOptions")
	if reserved then
		local ok, code = pcall(function()
			return TeleportService:ReserveServer(placeId)
		end)
		if not ok then
			return false, `NO SERVER: {tostring(code)}`
		end
		options.ReservedServerAccessCode = code
	end
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(placeId, list, options)
	end)
	if not ok then
		return false, `THE TELEPORT FAILED: {tostring(err)}`
	end
	return true, nil
end

local function openVote(player: Player, kind: string, title: string, onPass: () -> ())
	if voteOpen[kind] then
		alert(player, "Info", "THAT VOTE IS ALREADY ON: VOTE ON THE BANNER")
		return
	end
	local id, why = votes:Open({
		Kind = kind,
		Proposer = nil, -- the run is over, so the game opens it; the asker's yes goes in at once
		Title = title,
		OnPass = function()
			voteOpen[kind] = nil
			onPass()
		end,
		OnFail = function(reason: string)
			voteOpen[kind] = nil
			log:Info("%s failed: %s", kind, reason)
		end,
	})
	if not id then
		alert(player, "Warning", string.upper(why or "THE VOTE COULDN'T START"))
		return
	end
	if id ~= "solo" then
		voteOpen[kind] = id
		votes:Cast(player, id, "Yes")
	end
end

local function onPlayAgain(player: Player)
	if director:Phase() ~= "Ended" then
		alert(player, "Info", "THE RUN ISN'T OVER YET")
		return
	end
	openVote(player, "PlayAgain", `PLAY AGAIN? ({string.upper(player.DisplayName)} ASKS)`, function()
		local list = session:ReadyPlayers()
		local ok, why = teleport(Constants.PLACE_IDS.Run, list, true)
		Remotes.FireClients("Alert", list, if ok then "Info" else "Warning",
			if ok then "PLAY AGAIN: OFF TO A FRESH BUNKER" else `PLAY AGAIN PASSED · {why}`)
		log:Info("Play Again passed (%s)", if ok then "teleporting" else tostring(why))
	end)
end

local function onKeepGoing(player: Player)
	local summary = director:Summary()
	if director:Phase() ~= "Ended" or not summary.Victory or summary.Endless then
		alert(player, "Info", "KEEP GOING COMES AFTER A VICTORY")
		return
	end
	openVote(player, "KeepGoing", `KEEP GOING: ENDLESS MODE? ({string.upper(player.DisplayName)} ASKS)`, function()
		if director:KeepGoing() then
			Remotes.FireClients("Alert", session:ReadyPlayers(), "Info", "KEEP GOING: ENDLESS MODE STARTS NOW")
		end
	end)
end

local function onReturnToLobby(player: Player)
	if director:Phase() ~= "Ended" then
		alert(player, "Info", "THE RUN ISN'T OVER YET")
		return
	end
	local ok, why = teleport(Constants.PLACE_IDS.Lobby, { player }, false)
	if not ok then
		alert(player, "Warning", `RETURN TO LOBBY · {why}`)
	end
	log:Info("%s returns to the lobby (%s)", player.Name, if ok then "teleporting" else tostring(why))
end

-- DevTools -----------------------------------------------------------------------------------------------------

local function describe(): string
	local lines = { string.format("team: %d monsters killed, %d cells dug, %d rooms built, %d residents lost, %d disasters, bosses %s",
		team.MonstersKilled, team.CellsDug, team.RoomsBuilt, team.ResidentsLost, team.Disasters,
		if #bosses > 0 then table.concat(bosses, ", ") else "none") }
	for userId, s in stats do
		local parts = {}
		for _, key in STAT_KEYS do
			table.insert(parts, `{key} {math.floor(s[key] or 0)}`)
		end
		table.insert(lines, `{names[userId] or tostring(userId)}: {table.concat(parts, ", ")} (score {Results.Score(s)})`)
	end
	for _, line in stories do
		table.insert(lines, line)
	end
	if published then
		table.insert(lines, `published: {tostring(published.Outcome)}, MVP {tostring(published.MVP)}`)
		for id, row in published.Players do
			table.insert(lines, `  {id} {row.Name}: {row.Glowshards} Glowshards, +{row.XP} xp, level {row.Level}{if row.LevelUp then " (up)" else ""}`)
		end
	end
	return table.concat(lines, "\n")
end

local function registerCommands(dev: any)
	dev:Register("results", {
		Description = "The run's numbers so far, its story, and the published results.",
		Run = function(): string?
			return describe()
		end,
	})
	dev:Register("results.stat", {
		Description = "Add to a player's results stat (Studio testing of the MVP).",
		Usage = "results.stat <Damage|Kills|BossDamage|Revives|CellsDug|Repairs|Hauled|Rescues> <amount>",
		Run = function(player, args): string?
			local key, amount = tostring(args[1] or ""), tonumber(args[2])
			if not table.find(STAT_KEYS, key) or not amount or not player then
				return "usage: results.stat <stat> <amount> (as a player)"
			end
			names[player.UserId] = player.DisplayName
			bump(player.UserId, key, amount)
			return describe()
		end,
	})
end

-- Lifecycle ---------------------------------------------------------------------------------------------------

local services: { [string]: any } = {}

function ResultsService:Init(registry)
	director = registry.RunDirector
	clock = registry.CycleClock
	session = registry.SessionService
	profiles = registry.ProfileService
	combat = registry.CombatService
	residents = registry.ResidentService
	objectives = registry.ObjectiveService
	grid = registry.BunkerGrid
	votes = registry.VoteService
	services.Build = registry.BuildService
	services.Dig = registry.DigService
	services.Disaster = registry.DisasterService
	services.Boss = registry.BossService
	services.Inventory = registry.InventoryService
	services.Rescue = registry.RescueService
	services.Deep = registry.DeepService
	services.Expedition = registry.ExpeditionService
	collection = registry.ReplicationService:Collection("Results")
	registerCommands(registry.DevService)
end

function ResultsService:Start()
	-- Monsters' ids are M<n> (CombatService). A killing blow is Damaged after the target is
	-- unregistered, so the id says what it was, not CombatService:Get.
	combat.Damaged:Connect(function(id: string, amount: number, source: string?, _how: string?)
		if source then
			lastHit[id] = source
		end
		local userId = userOf(source)
		if userId and string.sub(id, 1, 1) == "M" then
			bump(userId, "Damage", amount)
			if services.Boss:IsBoss(id) then
				bump(userId, "BossDamage", amount)
			end
		end
	end)
	combat.Died:Connect(function(id: string)
		local source = lastHit[id]
		lastHit[id] = nil
		if string.sub(id, 1, 1) == "M" and not services.Boss:IsEggSac(id) then
			team.MonstersKilled += 1
			bump(userOf(source), "Kills", 1)
		end
	end)
	combat.Revived:Connect(function(_id: string, byUserId: number?)
		if byUserId then
			bump(byUserId, "Revives", 1)
		end
	end)
	residents.Died:Connect(function(id: string, how: string)
		team.ResidentsLost += 1
		story(`{residentName(id)} died ({how})`)
	end)
	services.Dig.Dug:Connect(function(floor: number, _column: number, result: string, _cause: string, finisher: Player?)
		team.CellsDug += 1
		deepest = math.max(deepest, floor)
		if finisher then
			bump(finisher.UserId, "CellsDug", 1)
		end
		if result == "Nest" then
			story("digging broke into a monster nest")
		end
	end)
	services.Build.Built:Connect(function(_roomId: string, kind: string)
		if kind == "Build" then
			team.RoomsBuilt += 1
		end
	end)
	services.Build.Repaired:Connect(function(_roomId: string, amount: number, _how: string, player: Player?)
		if player then
			bump(player.UserId, "Repairs", amount)
		end
	end)
	services.Disaster.Started:Connect(function(_id: string, kind: string)
		team.Disasters += 1
		if kind == "Meltdown" then
			story("the Reactor Core began to melt down")
		end
	end)
	services.Disaster.Ended:Connect(function(_id: string, kind: string, how: string)
		if kind == "Meltdown" and how == "Fixed" then
			story("three valves turned together stopped the meltdown")
		end
	end)
	-- the surface (Prompt 16): what players hauled home and who they rescued
	services.Inventory.Unloaded:Connect(function(player: Player, delivered: { [string]: number })
		local n = 0
		for _, amount in delivered do
			n += amount
		end
		team.Hauled += n
		bump(player.UserId, "Hauled", n)
	end)
	services.Inventory.Delivered:Connect(function(player: Player, kind: string, given: { any })
		local n = 0
		for _, drop in given do
			n += drop.Count or 0
		end
		team.Hauled += n
		bump(player.UserId, "Hauled", n)
		local entry = Config.Find("LootTables", kind)
		local dug = Config.Find("DigResults", kind) -- a cryo pod (Prompt 17)
		local what = if entry then string.lower(entry.Text) elseif dug then `a {string.lower(dug.Name)}` else kind
		story(`{player.DisplayName} hauled {what} home`)
	end)
	services.Rescue.Joined:Connect(function(residentId: string, leader: Player?, _kind: string, where: string)
		team.Rescued += 1
		if leader then
			bump(leader.UserId, "Rescues", 1)
		end
		story(`{if leader then leader.DisplayName else "the team"} rescued {residentName(residentId)} from {where}`)
	end)
	-- the Deep (Prompt 17)
	services.Deep.CaveOpened:Connect(function(_key: string, band: string, _pieces: number)
		if not bandsWithCaves[band] then
			bandsWithCaves[band] = true
			local entry = Config.Find("DepthBands", band)
			story(`digging broke into a cave in the {if entry then entry.Name else band}`)
		end
	end)
	services.Deep.CrewHome:Connect(function(objectiveId: string, leader: Player?)
		local objective = Config.Find("Objectives", objectiveId)
		local crew = if objective then (string.gsub(objective.Name, "^Lost Crew: ", "")) else "a lost"
		story(`{if leader then leader.DisplayName else "the team"} brought {crew} crew home`)
	end)
	-- Prompt 18: expeditions home, distress calls answered, recruits
	services.Expedition.Returned:Connect(function(_id: string, destination: string, names: string, finds: string)
		story(`{names} came back from {if destination == "Deep" then "the Deep" else "the surface"}`
			.. (if finds ~= "" then ` ({string.lower(finds)})` else ""))
	end)
	services.Expedition.Reached:Connect(function(_id: string, player: Player)
		story(`{player.DisplayName} answered a distress call`)
	end)
	services.Expedition.Recruited:Connect(function(residentId: string, how: string)
		story(`{residentName(residentId)} {how}`)
	end)
	services.Deep.Thawed:Connect(function(residentId: string, tier: string)
		story(`{residentName(residentId)} ({string.lower(tier)}) thawed out of a cryo pod`)
	end)
	services.Deep.ChestOpened:Connect(function(opener: Player, shards: number)
		for _, player in session:ReadyPlayers() do
			chestShards[player.UserId] = (chestShards[player.UserId] or 0) + shards
		end
		story(`{opener.DisplayName} opened a Glowshard chest`)
	end)
	services.Boss.Defeated:Connect(function(bossId: string, killer: Player?)
		if not table.find(bosses, bossId) then
			table.insert(bosses, bossId)
		end
		local name = Config.Get("Bosses", bossId).Name
		story(if killer then `{killer.DisplayName} struck the {name} down` else `the {name} fell`)
	end)
	objectives.BossDefeated:Connect(function(bossId: string)
		if not table.find(bosses, bossId) then
			table.insert(bosses, bossId) -- beaten another way (DevTools' boss.beat)
		end
	end)
	local lastLimit = RunState.Get("DigLimit")
	RunState.Changed("DigLimit"):Connect(function()
		local value = RunState.Get("DigLimit")
		if type(value) == "number" and type(lastLimit) == "number" and value > lastLimit then
			story(`the team pushed deeper, into the {Grid.BandOf(value).Name}`)
		end
		lastLimit = value
	end)
	RunState.Changed("TremorAt"):Connect(function()
		if type(RunState.Get("TremorAt")) == "number" then
			story("a Tremor shook the bunker and the Deep broke in")
		end
	end)
	director.RunEnded:Connect(function(summary: any)
		local ok, err = pcall(build, summary)
		if not ok then
			log:Error("results: %s", tostring(err))
		end
	end)
	Remotes.OnServer("PlayAgain", onPlayAgain)
	Remotes.OnServer("KeepGoing", onKeepGoing)
	Remotes.OnServer("ReturnToLobby", onReturnToLobby)
	log:Info("results ready")
end

return ResultsService
