--!strict
--[[
	Rules.Results: what a run pays and who was its MVP (bible Sections 16 and 18; Prompt 15). Pure,
	so ResultsService, the results screen and the data tests agree. The amounts are
	Config.GlowshardRewards, Config.Difficulties' PayoutMultiplier and Tuning.Account (account
	experience); the MVP weights are Tuning.Results.

	* Payout(run, paid, facts): the lines a player is owed and the new ledger. `paid` is what this
	  run has already paid them, so a run that ends twice (a victory, then Keep Going and a later
	  end in Endless) only pays what is new: more years, deeper bands, a victory, bosses.
	    - Years survived: Amount per Every years (1 per 4).
	    - Depth bands reached: Amount each (a band counts once its first floor is open).
	    - A Century or a Deep Victory.
	    - Each boss killed.
	    - The difficulty's PayoutMultiplier, then the first win of the day doubles it all.
	* Account experience: XPPerYear for each new year survived; levels from XPToLevelBase plus
	  XPToLevelStep a level, up to LevelMax.
	* Score and MVP: a player's stats times Tuning.Results.MVP's weights; the highest wins (ties:
	  the lower user id, so every server agrees).
]]

local Config = require(script.Parent.Parent.Config)

local Results = {}

export type Run = {
	Year: number,
	DeepestFloor: number,
	Victory: string?, -- "Century" | "Deep"
	Bosses: { string }, -- bosses beaten this run
	Difficulty: string,
}
export type Ledger = { Years: number, Bands: number, Victory: boolean, Bosses: { [string]: boolean } }
export type Line = { Text: string, Amount: number }
export type Payout = { Lines: { Line }, Total: number, Ledger: Ledger }

function Results.Tuning(): { [string]: any }
	return Config.Get("Tuning", "Results")
end

function Results.EmptyLedger(): Ledger
	return { Years = 0, Bands = 0, Victory = false, Bosses = {} }
end

-- Bands whose first floor is open (the Mines count from the start).
function Results.BandsReached(deepestFloor: number): number
	local n = 0
	for _, band in Config.All("DepthBands") do
		if deepestFloor >= band.Floors.From then
			n += 1
		end
	end
	return n
end

local function reward(id: string): any
	return Config.Get("GlowshardRewards", id)
end

function Results.Payout(run: Run, paid: Ledger, facts: { FirstWinToday: boolean }): Payout
	local lines: { Line } = {}
	local ledger: Ledger = { Years = paid.Years, Bands = paid.Bands, Victory = paid.Victory, Bosses = table.clone(paid.Bosses) }
	local subtotal = 0
	local function add(text: string, amount: number)
		if amount > 0 then
			table.insert(lines, { Text = text, Amount = amount })
			subtotal += amount
		end
	end
	-- years survived
	local years = reward("Years")
	local yearsOwed = math.floor(math.max(run.Year, 0) / years.Every)
	local paidYears = math.floor(paid.Years / years.Every)
	if yearsOwed > paidYears then
		add(`Years survived: {run.Year}`, (yearsOwed - paidYears) * years.Amount)
	end
	ledger.Years = math.max(paid.Years, run.Year)
	-- depth bands
	local bands = Results.BandsReached(run.DeepestFloor)
	if bands > paid.Bands then
		add(`Depth bands reached: {bands}`, (bands - paid.Bands) * reward("Bands").Amount)
	end
	ledger.Bands = math.max(paid.Bands, bands)
	-- a victory
	if run.Victory and not paid.Victory then
		local id = if run.Victory == "Deep" then "DeepVictory" else "CenturyVictory"
		add(reward(id).Text, reward(id).Amount)
		ledger.Victory = true
	end
	-- bosses
	for _, bossId in run.Bosses do
		if not ledger.Bosses[bossId] then
			ledger.Bosses[bossId] = true
			add(`{Config.Get("Bosses", bossId).Name} killed`, reward("Bosses").Amount)
		end
	end
	local total = subtotal
	local difficulty = Config.Find("Difficulties", run.Difficulty)
	local multiplier = if difficulty then difficulty.PayoutMultiplier else 1
	if subtotal > 0 and multiplier ~= 1 then
		local extra = math.floor(subtotal * multiplier + 0.5) - subtotal
		table.insert(lines, { Text = `{difficulty.Name} difficulty x{multiplier}`, Amount = extra })
		total += extra
	end
	if total > 0 and facts.FirstWinToday and run.Victory then
		local double = reward("FirstWinOfDay").Multiplier or 2
		local extra = math.floor(total * double + 0.5) - total
		table.insert(lines, { Text = "First win of the day", Amount = extra })
		total += extra
	end
	return { Lines = lines, Total = math.floor(total + 0.5), Ledger = ledger }
end

-- Account experience for years survived since `paidYears`.
function Results.AccountXP(year: number, paidYears: number): number
	return math.max(0, year - paidYears) * Config.Get("Tuning", "Account").XPPerYear
end

-- Experience to go from `level` to the next.
function Results.XPToNext(level: number): number
	local t = Config.Get("Tuning", "Account")
	return t.XPToLevelBase + t.XPToLevelStep * (level - 1)
end

-- An account's level and experience after gaining `gained`.
function Results.LevelUp(level: number, xp: number, gained: number): (number, number)
	local t = Config.Get("Tuning", "Account")
	xp += gained
	while level < t.LevelMax and xp >= Results.XPToNext(level) do
		xp -= Results.XPToNext(level)
		level += 1
	end
	if level >= t.LevelMax then
		xp = math.min(xp, Results.XPToNext(level))
	end
	return level, xp
end

function Results.Score(stats: { [string]: number }): number
	local score = 0
	for key, weight in Results.Tuning().MVP do
		score += (stats[key] or 0) * weight
	end
	return math.floor(score + 0.5)
end

-- The MVP's user id (players: user id -> stats), or nil with nobody scoring.
function Results.MVP(players: { [number]: { [string]: number } }): number?
	local best: number? = nil
	local bestScore = 0
	for userId, stats in players do
		local score = Results.Score(stats)
		if score > bestScore or (score == bestScore and best ~= nil and score > 0 and userId < best) then
			best, bestScore = userId, score
		end
	end
	return best
end

-- The UTC day a moment falls on (for the first win of the day).
function Results.Day(unixSeconds: number): number
	return math.floor(unixSeconds / 86400)
end

return table.freeze(Results)
