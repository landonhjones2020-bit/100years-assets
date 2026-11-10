--!strict
--[[
	VoteService: team votes (bible Section 8). Run place only.

	Anything that spends the shared stockpile or changes the run for everyone goes to a quick
	vote. Prompt 8 runs construction votes (BuildService opens them). Push Deeper (Prompt 14),
	the blueprint draft (19), Keep Going (15), Let them in? (30) and kicks (30) will open theirs
	here too.

	How a vote runs:
	* One vote is live on the banner at a time. Later proposals wait in a queue, and each gets
	  its full time once it goes live, so nothing runs out of time unseen.
	* The proposer counts as a yes. Not voting is abstaining, and a player can change their
	  vote until it closes.
	* Rules (Rules.Votes):
	  * a build passes with more yes than no after 15 s;
	  * spending more than 40% of a stock needs a majority of the whole team;
	  * everyone yes passes at once;
	  * ties fail. A tie-breaker (the Warden, Prompt 20) can pass one: SetTieBreaker.
	* Each player has at most one open proposal (queued or live). A failed one gives that
	  player a 20 s cooldown.
	* Solo runs have no votes: a proposal is checked again and applies at once.
	* When a vote passes, its Check runs again (costs, the cells still free). If that fails
	  now, the vote fails with the reason.
	* The Votes collection (id -> what the banner shows) replicates to every player. A closed
	  vote stays ResultSeconds with PASSED or FAILED, then goes.
	* Studio: `vote.bots <n> [yes|no|abstain]` adds pretend voters to the team, so the team
	  rules can be tried in a one-player playtest.
	* Draft votes (Prompt 19, the blueprint draft): a spec with Options is a MostVotes vote. Each
	  player picks one option (CastPick) and can change it until the vote closes; when time is up
	  the option with the most picks wins, ties picked at random (Rules.Votes.Winner), and OnPass
	  gets the winner. Everyone having picked closes it at once. Solo runs vote too: the player's
	  pick is the team's (Section 8, rule 6), and it closes the vote at once. SetOptions swaps the
	  options of an open draft (a reroll): the picks are cleared and, with
	  Tuning.Draft.RerollRestartsTimer, the time starts over.

	API:
		VoteService:Open(spec): (string?, string?)     -- the vote id ("solo" when it applied at once), or why not
		VoteService:Cast(player, id, "Yes" | "No" | option id): (boolean, string?)
		VoteService:SetOptions(id, options): boolean           -- a draft's new cards (a reroll)
		VoteService:Live(): (string?, Spec?)                    -- the vote on the banner
		VoteService:CanPropose(player): (boolean, string?)
		VoteService:Reserved(exceptId?): { [string]: boolean }  -- cell keys held by open votes
		VoteService:TeamSize(): number
		VoteService:SetTieBreaker(fn: (voteId) -> boolean)
		VoteService.Opened: Signal<string>, VoteService.Closed: Signal<string, boolean, string?>
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Construction = require(Shared.Rules.Construction)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local RunState = require(Shared.RunState)
local Signal = require(Shared.Utilities.Signal)
local Votes = require(Shared.Rules.Votes)

local log = Log.new("VoteService")

export type Option = {
	Id: string, -- what OnPass gets when it wins (a draft card's id)
	Title: string, -- "REINFORCED WALLS"
	Kind: string?, -- a draft card's kind (Room, BunkerPerk...)
	Label: string?, -- its kind tag: "BUNKER PERK"
	Text: string?, -- its short text
	Found: string?, -- a found blueprint: who found it ("FOUND BY LANDON")
}

export type Spec = {
	Kind: string, -- a Config.Votes id
	Proposer: Player?, -- nil for votes the game opens
	Title: string, -- what is proposed: "KITCHEN", "QUARTERS TO LEVEL 2"
	Costs: { [string]: number }?, -- shown on the banner; a big spend needs a team majority
	Refund: { [string]: number }?, -- shown on the banner: what comes back (a tear-down)
	Subject: { Floor: number, Column: number, Span: number, Label: string }?, -- the ghost outline
	Cells: { string }?, -- cell keys it holds while open
	Check: (() -> (boolean, string?))?, -- run again when it passes
	Options: { Option }?, -- a MostVotes vote (Prompt 19's draft): one of these wins
	OnPass: (pick: string?) -> (), -- a draft's winner (nil for a yes or no vote)
	OnFail: ((reason: string) -> ())?,
}

type Ballot = string -- "Yes" or "No", or a draft option's Id
type Status = "Queued" | "Live" | "Passed" | "Failed"
type Vote = {
	Id: string,
	Spec: Spec,
	Rule: Votes.Rule,
	Status: Status,
	Ballots: { [number]: Ballot }, -- by UserId; pretend voters are negative
	EndsAt: number?,
	Result: string?,
	Winner: string?, -- a draft's winning option
}

local VoteService = {
	Name = "VoteService",
	Dependencies = { "SessionService", "ReplicationService", "DevService" },
	Opened = Signal.new() :: Signal.Signal<string>,
	Closed = Signal.new() :: Signal.Signal<string, boolean, string?>,
}

local session: any = nil
local collection: any = nil
local votes: { [string]: Vote } = {}
local queue: { string } = {} -- open votes in order; the first is live
local cooldowns: { [number]: number } = {} -- UserId -> os.clock() it ends
local nextId = 0
local tieBreaker: ((string) -> boolean)? = nil
local pickRandom = Random.new() -- draft ties
local bots: { [number]: Ballot | false } = {} -- Studio: pretend voters (-1, -2, ...); false abstains

local function now(): number
	return workspace:GetServerTimeNow()
end

local function tuning(): { [string]: any }
	return Votes.Tuning()
end

-- Everyone who can vote: ready players, plus pretend voters in Studio.
local function team(): { number }
	local ids = {}
	for _, player in session:ReadyPlayers() do
		table.insert(ids, player.UserId)
	end
	for id in bots do
		table.insert(ids, id)
	end
	return ids
end

function VoteService:TeamSize(): number
	return #team()
end

local function count(vote: Vote): (number, number, number)
	local members = team()
	local yes, no = 0, 0
	for _, id in members do
		local ballot = vote.Ballots[id]
		if ballot == "Yes" then
			yes += 1
		elseif ballot == "No" then
			no += 1
		end
	end
	return yes, no, #members
end

local function optionIds(vote: Vote): { string }
	local ids = {}
	for _, option in vote.Spec.Options or {} do
		table.insert(ids, option.Id)
	end
	return ids
end

-- A draft's picks: votes per option, and how many of the team have picked.
local function tallyOptions(vote: Vote): ({ [string]: number }, number)
	local counts: { [string]: number } = {}
	for _, option in vote.Spec.Options or {} do
		counts[option.Id] = 0
	end
	local picked = 0
	for _, id in team() do
		local choice = vote.Ballots[id]
		if choice and counts[choice] ~= nil then
			counts[choice] += 1
			picked += 1
		end
	end
	return counts, picked
end

local function nameOf(player: Player?): string
	return if player then string.upper(player.DisplayName) else "THE BUNKER"
end

local function publish(vote: Vote)
	local yes, no, size = count(vote)
	local ballots = {}
	for id, ballot in vote.Ballots do
		ballots[tostring(id)] = ballot
	end
	local position = table.find(queue, vote.Id)
	local spec = vote.Spec
	local options: { any }? = nil
	local picked = 0
	if spec.Options then
		local counts
		counts, picked = tallyOptions(vote)
		local list = {}
		for _, option in spec.Options do
			table.insert(list, {
				Id = option.Id,
				Title = option.Title,
				Kind = option.Kind,
				Label = option.Label,
				Text = option.Text,
				Found = option.Found,
				Votes = counts[option.Id] or 0,
			})
		end
		options = list
	end
	collection:Set(vote.Id, {
		Kind = spec.Kind,
		Title = spec.Title,
		Proposer = if spec.Proposer then spec.Proposer.UserId else 0,
		ProposerName = nameOf(spec.Proposer),
		Cost = if spec.Costs then Construction.CostText(spec.Costs) else "",
		Refund = if spec.Refund and next(spec.Refund) then Construction.CostText(spec.Refund) else nil,
		Rule = vote.Rule,
		Need = Votes.NeedText(vote.Rule, size),
		Status = vote.Status,
		EndsAt = vote.EndsAt,
		Seconds = Config.Get("Votes", spec.Kind).Seconds,
		Yes = yes,
		No = no,
		Team = size,
		Waiting = if position and position > 1 then position - 1 else 0,
		Ballots = ballots,
		Subject = spec.Subject,
		Result = vote.Result,
		Options = options, -- a draft's cards with their picks (Prompt 19)
		Picked = if options then picked else nil,
		Winner = vote.Winner,
	})
end

local function publishQueue()
	for _, id in queue do
		local vote = votes[id]
		if vote then
			publish(vote)
		end
	end
end

local function stockNow(): { [string]: number }
	local stockpile = {}
	for _, resource in Config.Ids("Resources") do
		local value = RunState.Fields[resource] and RunState.Get(resource)
		if type(value) == "number" then
			stockpile[resource] = value
		end
	end
	return stockpile
end

local function goLive()
	local id = queue[1]
	local vote = if id then votes[id] else nil
	if not vote or vote.Status ~= "Queued" then
		return
	end
	vote.Status = "Live"
	-- the 40% rule against the stockpile as it is when the team votes
	vote.Rule = Votes.RuleFor(vote.Spec.Kind, Votes.BigSpend(vote.Spec.Costs, stockNow()))
	vote.EndsAt = now() + Config.Get("Votes", vote.Spec.Kind).Seconds
	if not vote.Spec.Options then -- pretend voters pick draft cards only when told to (vote.pick)
		for botId, stance in bots do
			if stance then
				vote.Ballots[botId] = stance
			end
		end
	end
	log:Info("%s live: %s (%s)", vote.Id, vote.Spec.Title, vote.Rule)
	VoteService.Opened:Fire(vote.Id)
	publishQueue()
end

local function titleOf(vote: Vote, optionId: string?): string
	for _, option in vote.Spec.Options or {} do
		if option.Id == optionId then
			return option.Title
		end
	end
	return tostring(optionId)
end

local function close(vote: Vote, passed: boolean, reason: string?, pick: string?)
	if vote.Status ~= "Live" and vote.Status ~= "Queued" then
		return
	end
	if passed and vote.Spec.Check then
		local ok, why = vote.Spec.Check()
		if not ok then
			passed, reason = false, why or "it can't be done any more"
		end
	end
	vote.Status = if passed then "Passed" else "Failed"
	vote.Winner = if passed then pick else nil
	vote.Result = if passed and pick then `PICKED: {titleOf(vote, pick)}`
		elseif passed then "PASSED"
		else `FAILED: {string.upper(reason or "not enough yes")}`
	local index = table.find(queue, vote.Id)
	if index then
		table.remove(queue, index)
	end
	local spec = vote.Spec
	if passed then
		local ok, err = pcall(spec.OnPass, pick)
		if not ok then
			log:Error("%s passed but OnPass failed: %s", vote.Id, tostring(err))
		end
	else
		if spec.Proposer then
			cooldowns[spec.Proposer.UserId] = os.clock() + tuning().FailedCooldownSeconds
		end
		if spec.OnFail then
			local ok, err = pcall(spec.OnFail :: any, reason or "not enough yes")
			if not ok then
				log:Error("%s OnFail failed: %s", vote.Id, tostring(err))
			end
		end
	end
	log:Info("%s %s: %s", vote.Id, string.lower(vote.Status), reason or "")
	publish(vote)
	VoteService.Closed:Fire(vote.Id, passed, reason)
	task.delay(tuning().ResultSeconds, function()
		votes[vote.Id] = nil
		collection:Remove(vote.Id)
	end)
	goLive()
	publishQueue()
end

local function decide(vote: Vote)
	if vote.Spec.Options then
		-- a draft: the most picks wins, ties (none picked included) at random
		local counts = tallyOptions(vote)
		local winner = Votes.Winner(counts, optionIds(vote), pickRandom)
		close(vote, winner ~= nil, if winner then nil else "nothing to pick", winner)
		return
	end
	local yes, no, size = count(vote)
	local result = Votes.Outcome(vote.Rule, yes, no, size)
	if result == "Tie" and tieBreaker then
		local ok, pass = pcall(tieBreaker :: any, vote.Id)
		if ok and pass == true then
			close(vote, true, nil)
			return
		end
	end
	if result == "Pass" then
		close(vote, true, nil)
	elseif result == "Tie" then
		close(vote, false, "a tie")
	else
		close(vote, false, if vote.Rule == "MoreYes" then "more no than yes" else "not enough of the team said yes")
	end
end

-- API ---------------------------------------------------------------------------------------------

function VoteService:CanPropose(player: Player): (boolean, string?)
	if RunState.Get("RunPhase") ~= "Playing" then
		return false, "The run isn't under way."
	end
	if not session:IsReady(player) then
		return false, "You're not in the run yet."
	end
	for _, id in queue do
		local vote = votes[id]
		if vote and vote.Spec.Proposer == player then
			return false, "You already have a proposal open."
		end
	end
	local ends = cooldowns[player.UserId]
	if ends and os.clock() < ends then
		return false, `You can propose again in {math.ceil(ends - os.clock())} s.`
	end
	return true, nil
end

function VoteService:Reserved(exceptId: string?): { [string]: boolean }
	local cells = {}
	for _, id in queue do
		local vote = votes[id]
		if vote and id ~= exceptId and vote.Spec.Cells then
			for _, key in vote.Spec.Cells do
				cells[key] = true
			end
		end
	end
	return cells
end

function VoteService:Open(spec: Spec): (string?, string?)
	assert(Config.Find("Votes", spec.Kind), `VoteService: no vote kind {spec.Kind}`)
	if spec.Proposer then
		local ok, why = VoteService:CanPropose(spec.Proposer)
		if not ok then
			return nil, why
		end
	end
	-- Solo: no vote; check it and apply it at once (Section 8, rule 6).
	if tuning().SoloSkipsVotes and VoteService:TeamSize() <= 1 and not spec.Options then
		if spec.Check then
			local ok, why = spec.Check()
			if not ok then
				return nil, why
			end
		end
		local ok, err = pcall(spec.OnPass, nil)
		if not ok then
			log:Error("solo: %s failed to apply: %s", spec.Title, tostring(err))
			return nil, "That couldn't be done (see the server log)."
		end
		log:Info("solo: %s applied at once", spec.Title)
		return "solo", nil
	end
	nextId += 1
	local id = `V{nextId}`
	local vote: Vote = {
		Id = id,
		Spec = spec,
		Rule = Votes.RuleFor(spec.Kind, Votes.BigSpend(spec.Costs, stockNow())),
		Status = "Queued",
		Ballots = {},
	}
	if spec.Proposer then
		vote.Ballots[spec.Proposer.UserId] = "Yes"
	end
	votes[id] = vote
	table.insert(queue, id)
	log:Info("%s opened by %s: %s, %s", id, nameOf(spec.Proposer), spec.Title, vote.Rule)
	if #queue == 1 then
		goLive()
	else
		publish(vote)
	end
	return id, nil
end

-- A ballot from voter `voterId` (a player's UserId, or a pretend voter's negative id).
local function ballot(vote: Vote, voterId: number, choice: Ballot): (boolean, string?)
	if vote.Spec.Options then
		if not table.find(optionIds(vote), choice) then
			return false, "That isn't one of the cards."
		end
		vote.Ballots[voterId] = choice
		local _, picked = tallyOptions(vote)
		if picked >= #team() then
			decide(vote) -- everyone has picked
		else
			publish(vote)
		end
		return true, nil
	end
	if choice ~= "Yes" and choice ~= "No" then
		return false, "That vote is yes or no."
	end
	vote.Ballots[voterId] = choice
	local yes, _, size = count(vote)
	if Votes.AllYes(yes, size) then
		close(vote, true, nil)
	else
		publish(vote)
	end
	return true, nil
end

function VoteService:Cast(player: Player, id: string, choice: Ballot): (boolean, string?)
	local vote = votes[id]
	if not vote or vote.Status ~= "Live" then
		return false, "That vote isn't open."
	end
	if not session:IsReady(player) then
		return false, "You're not in the run yet."
	end
	return ballot(vote, player.UserId, choice)
end

-- A draft's new cards (a reroll): its picks are cleared and, with RerollRestartsTimer, the time
-- starts over. False when the vote isn't an open draft.
function VoteService:SetOptions(id: string, options: { Option }): boolean
	local vote = votes[id]
	if not vote or not vote.Spec.Options or (vote.Status ~= "Live" and vote.Status ~= "Queued") or #options == 0 then
		return false
	end
	vote.Spec.Options = options
	table.clear(vote.Ballots)
	if vote.Status == "Live" and Config.Get("Tuning", "Draft").RerollRestartsTimer then
		vote.EndsAt = now() + Config.Get("Votes", vote.Spec.Kind).Seconds
	end
	publish(vote)
	return true
end

-- The vote on the banner now, and its spec.
function VoteService:Live(): (string?, Spec?)
	local id = queue[1]
	local vote = if id then votes[id] else nil
	if vote and vote.Status == "Live" then
		return vote.Id, vote.Spec
	end
	return nil, nil
end

function VoteService:SetTieBreaker(fn: (string) -> boolean)
	tieBreaker = fn
end

-- Lifecycle --------------------------------------------------------------------------------------

local function alert(player: Player, kind: string, text: string)
	Remotes.FireClient("Alert", player, kind, text)
end

local function describe(): string
	if #queue == 0 then
		return `no open votes; team {VoteService:TeamSize()}`
	end
	local lines = {}
	for _, id in queue do
		local vote = votes[id]
		if vote then
			local left = if vote.EndsAt then string.format(", %.0f s left", math.max(0, vote.EndsAt - now())) else ""
			if vote.Spec.Options then
				local counts, picked = tallyOptions(vote)
				local parts = {}
				for i, option in vote.Spec.Options do
					table.insert(parts, `{i} {option.Id} {counts[option.Id] or 0}`)
				end
				table.insert(lines, `{id} {vote.Status} {vote.Spec.Title}: {table.concat(parts, ", ")}; {picked} of {#team()} picked ({vote.Rule}{left})`)
			else
				local yes, no, size = count(vote)
				table.insert(lines, `{id} {vote.Status} {vote.Spec.Title}: {yes} yes, {no} no of {size} ({vote.Rule}{left})`)
			end
		end
	end
	return table.concat(lines, "\n")
end

function VoteService:Init(registry)
	session = registry.SessionService
	collection = registry.ReplicationService:Collection("Votes")
	Remotes.OnServer("CastVote", function(player: Player, id: string, choice: string)
		local ok, why = VoteService:Cast(player, id, choice)
		if not ok and why then
			alert(player, "Info", why)
		end
	end)
	Remotes.OnServer("CastPick", function(player: Player, id: string, option: string)
		local vote = votes[id]
		if vote and not vote.Spec.Options then
			alert(player, "Info", "That vote is yes or no.")
			return
		end
		local ok, why = VoteService:Cast(player, id, option)
		if not ok and why then
			alert(player, "Info", why)
		end
	end)
	local dev = registry.DevService
	dev:Register("votes", {
		Description = "Open votes, their tallies and time left.",
		Usage = "votes",
		Run = function(): string?
			return describe()
		end,
	})
	for _, choice in { "Yes", "No" } do
		dev:Register(`vote.{string.lower(choice)}`, {
			Description = `Vote {string.lower(choice)} on the live vote, as you or as pretend voter n.`,
			Usage = `vote.{string.lower(choice)} [n]`,
			Run = function(player: Player?, args): string?
				local id = queue[1]
				local vote = if id then votes[id] else nil
				if not vote or vote.Status ~= "Live" then
					return "no live vote"
				end
				local bot = tonumber(args[1])
				if bot then
					if bots[-bot] == nil then
						return `no pretend voter {bot}`
					end
					local ok, why = ballot(vote, -bot, choice)
					if not ok then
						return why
					end
				else
					-- from Studio's server tools there's no caller: vote as the first player in the run
					local who = player or session:ReadyPlayers()[1]
					if not who then
						return "nobody is in the run to vote as"
					end
					local ok, why = VoteService:Cast(who, id :: string, choice)
					if not ok then
						return why
					end
				end
				return describe()
			end,
		})
	end
	dev:Register("vote.pick", {
		Description = "Pick a card on the live draft (its number or id), as you or as pretend voter n (Prompt 19).",
		Usage = "vote.pick <card number|card id> [n]",
		Run = function(player: Player?, args): string?
			local id = queue[1]
			local vote = if id then votes[id] else nil
			if not vote or vote.Status ~= "Live" or not vote.Spec.Options then
				return "no live draft"
			end
			local options = vote.Spec.Options :: { Option }
			local which = tostring(args[1] or "")
			local option = options[tonumber(which) or 0]
			local choice = if option then option.Id else which
			local bot = tonumber(args[2])
			if bot then
				if bots[-bot] == nil then
					return `no pretend voter {bot}`
				end
				local ok, why = ballot(vote, -bot, choice)
				if not ok then
					return why
				end
			else
				local who = player or session:ReadyPlayers()[1]
				if not who then
					return "nobody is in the run to pick as"
				end
				local ok, why = VoteService:Cast(who, id :: string, choice)
				if not ok then
					return why
				end
			end
			return describe()
		end,
	})
	dev:Register("vote.test", {
		Description = "Open a vote the game proposes (no proposer, no effect), to try the queue and the telegram.",
		Usage = "vote.test [title]",
		Run = function(_player: Player, args): string?
			local title = string.upper(tostring(args[1] or "TEST VOTE"))
			local id, why = VoteService:Open({
				Kind = "Build",
				Title = title,
				OnPass = function()
					log:Info("test vote %s passed", title)
				end,
			})
			return if id then `opened {id}\n{describe()}` else `not opened: {why}`
		end,
	})
	dev:Register("vote.end", {
		Description = "Time is up on the live vote now.",
		Usage = "vote.end",
		Run = function(): string?
			local id = queue[1]
			local vote = if id then votes[id] else nil
			if not vote or vote.Status ~= "Live" then
				return "no live vote"
			end
			decide(vote)
			return describe()
		end,
	})
	dev:Register("vote.bots", {
		Description = "Studio: n pretend voters join the team, voting yes, no or abstaining on each vote as it goes live.",
		Usage = "vote.bots <n> [yes|no|abstain]",
		Run = function(_player: Player, args): string?
			if not RunService:IsStudio() then
				return "pretend voters are for Studio"
			end
			local n = math.clamp(math.floor(tonumber(args[1]) or 0), 0, 5)
			local stance = string.lower(tostring(args[2] or "abstain"))
			local ballot: Ballot? = if stance == "yes" then "Yes" elseif stance == "no" then "No" else nil
			table.clear(bots)
			for i = 1, n do
				bots[-i] = ballot or false
			end
			publishQueue()
			return `{n} pretend voter(s), {stance}; team {VoteService:TeamSize()}`
		end,
	})
end

function VoteService:Start()
	task.spawn(function()
		while true do
			task.wait(0.25)
			local id = queue[1]
			local vote = if id then votes[id] else nil
			if vote and vote.Status == "Live" and vote.EndsAt and now() >= vote.EndsAt then
				decide(vote)
			end
		end
	end)
	session.PlayerLeaving:Connect(function(_player: Player)
		task.defer(publishQueue) -- the team is smaller: tallies and needs change
	end)
	session.PlayerReady:Connect(function(_player: Player)
		publishQueue()
	end)
end

return VoteService
