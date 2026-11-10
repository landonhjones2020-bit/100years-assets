--!strict
--[[
	Rules.Votes: how a vote is decided (bible Section 8). Pure, so VoteService, the vote banner
	and the data tests share it.

	* Each kind of vote has a rule (Config.Votes):
	  * MoreYes: more yes than no when time is up.
	  * WholeTeamMajority: more than half of the whole team says yes.
	  * TwoThirdsOfOthers: a kick needs two thirds of the other players.
	  * MostVotes: a draft goes to the most votes, ties picked at random (Winner).
	* Not voting is abstaining. Ties fail, unless a tie-breaker (the Warden, Prompt 20) says yes;
	  a draft's tie goes to the Warden's pick when it is one of the tied.
	  A whole-team vote ties when the team splits evenly (2 yes and 2 no of 4).
	* Everyone saying yes passes a vote at once (Tuning.Votes.PassEarlyWhenAllYes).
	* Spending more than BigSpendFraction (40%) of any stock needs a majority of the whole team.
]]

local Config = require(script.Parent.Parent.Config)

export type Rule = "MoreYes" | "WholeTeamMajority" | "TwoThirdsOfOthers" | "MostVotes"
export type Result = "Pass" | "Fail" | "Tie"

local Votes = {}

function Votes.Tuning(): { [string]: any }
	return Config.Get("Tuning", "Votes")
end

-- The yes votes a majority of `team` needs: more than half.
function Votes.Majority(team: number): number
	return math.floor(team / 2) + 1
end

-- Two thirds of `others`, rounded up.
function Votes.TwoThirds(others: number): number
	return math.ceil(others * 2 / 3 - 1e-9)
end

-- The result when time is up. `team` is everyone who can vote, abstainers included (for a
-- kick, the players other than the one it's against).
function Votes.Outcome(rule: Rule, yes: number, no: number, team: number): Result
	if rule == "MoreYes" then
		return if yes > no then "Pass" elseif yes < no then "Fail" else "Tie"
	elseif rule == "WholeTeamMajority" then
		if yes * 2 > team then
			return "Pass"
		elseif yes == no and yes * 2 == team then
			return "Tie"
		end
		return "Fail"
	elseif rule == "TwoThirdsOfOthers" then
		return if team > 0 and yes >= Votes.TwoThirds(team) then "Pass" else "Fail"
	end
	error(`Rules.Votes.Outcome: a {rule} vote is decided by Winner`)
end

-- Everyone has said yes: the vote passes at once.
function Votes.AllYes(yes: number, team: number): boolean
	return team > 0 and yes >= team and Votes.Tuning().PassEarlyWhenAllYes == true
end

-- Does spending `costs` take more than BigSpendFraction of any stock?
function Votes.BigSpend(costs: { [string]: number }?, stock: { [string]: number }): boolean
	local fraction = Votes.Tuning().BigSpendFraction
	for id, amount in costs or {} do
		if amount > 0 and amount > fraction * (stock[id] or 0) then
			return true
		end
	end
	return false
end

-- The rule a vote of `kind` follows; a big spend turns "more yes than no" into a whole-team majority.
function Votes.RuleFor(kind: string, bigSpend: boolean): Rule
	local rule: Rule = Config.Get("Votes", kind).Rule
	if bigSpend and rule == "MoreYes" then
		return "WholeTeamMajority"
	end
	return rule
end

-- What the banner says a vote needs.
function Votes.NeedText(rule: Rule, team: number): string
	if rule == "MoreYes" then
		return "MORE YES THAN NO"
	elseif rule == "WholeTeamMajority" then
		return `{Votes.Majority(team)} OF {team} MUST SAY YES`
	elseif rule == "TwoThirdsOfOthers" then
		return `{Votes.TwoThirds(team)} OF {team} MUST SAY YES`
	end
	return "MOST VOTES WINS"
end

-- A MostVotes vote's leaders: the options with the most votes, in `order`.
function Votes.Tied(counts: { [string]: number }, order: { string }): { string }
	local best, tied = -1, {}
	for _, option in order do
		local n = counts[option] or 0
		if n > best then
			best, tied = n, { option }
		elseif n == best then
			table.insert(tied, option)
		end
	end
	return tied
end

-- A MostVotes vote: the option with the most votes, ties picked at random, unless `breaker` (a
-- Warden's pick, Prompt 20) is one of the tied. `order` lists the options (so ties break the same
-- way for the same Random); nil when there are none.
function Votes.Winner(counts: { [string]: number }, order: { string }, random: Random, breaker: string?): string?
	local tied = Votes.Tied(counts, order)
	if #tied == 0 then
		return nil
	end
	if breaker and #tied > 1 and table.find(tied, breaker) then
		return breaker
	end
	return tied[random:NextInteger(1, #tied)]
end

return Votes
