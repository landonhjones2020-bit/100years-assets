--!strict
--[[
	Rules.Draft: the blueprint draft (bible Section 8 and the Appendix's card pool). Pure, so
	DraftService, the vote telegram and the data tests share it.

	* After every Surge, Tuning.Draft.Cards (3) cards are drawn from the pool and the team votes
	  for one (Config.Votes.Draft: most votes after 20 s, ties picked at random). A card taken
	  leaves the pool for the run.
	* Draws are weighted by each card's Weight; in Era I a card's EarlyWeight is used instead, so
	  room cards come up more early and every run gets its key rooms.
	* Found blueprints (Landon, Prompt 19): a blueprint found in loot or brought home by an
	  expedition is one card, drawn the same way. Once it's home it joins the next draft as an
	  extra choice (FoundPerDraft a draft); the team still votes. Cards waiting like that are held
	  out of the normal draw.
	* Only cards the run can use are offered (DraftService passes `usable`): every modifier the
	  card carries has a system that applies it, a room card's room isn't unlocked already, and
	  so on.
]]

local Config = require(script.Parent.Parent.Config)

export type Face = { Id: string, Name: string, Kind: string, Label: string, Text: string, Room: string? }

local Draft = {}

-- The words on a card's kind tag.
Draft.KIND_LABEL = table.freeze({
	Room = "ROOM",
	BunkerPerk = "BUNKER PERK",
	ResidentBoon = "RESIDENT BOON",
	PlayerBoon = "PLAYER BOON",
	RiskDeal = "RISK DEAL",
})

function Draft.Tuning(): { [string]: any }
	return Config.Get("Tuning", "Draft")
end

-- A card's draw weight in era number `era` (EarlyWeight applies in Era I).
function Draft.Weight(card: { [string]: any }, era: number): number
	if era <= 1 and type(card.EarlyWeight) == "number" then
		return card.EarlyWeight
	end
	return card.Weight
end

-- The cards that can come up: in the pool (not taken, not held back) and usable, in Config order.
function Draft.Pool(
	taken: { [string]: boolean },
	held: { [string]: boolean }?,
	usable: ((card: { [string]: any }) -> boolean)?
): { string }
	local out = {}
	for _, id in Config.Ids("DraftCards") do
		if not taken[id] and not (held and held[id]) then
			local card = Config.Get("DraftCards", id)
			if not usable or usable(card) then
				table.insert(out, id)
			end
		end
	end
	return out
end

-- Up to n cards from `pool`, no repeats, each drawn by its weight in era number `era`.
function Draft.Draw(pool: { string }, n: number, era: number, random: Random): { string }
	local left = table.clone(pool)
	local out = {}
	while #out < n and #left > 0 do
		local total = 0
		for _, id in left do
			total += Draft.Weight(Config.Get("DraftCards", id), era)
		end
		local pick = random:NextInteger(1, #left)
		if total > 0 then
			local roll = random:NextNumber() * total
			for i, id in left do
				roll -= Draft.Weight(Config.Get("DraftCards", id), era)
				if roll < 0 then
					pick = i
					break
				end
			end
		end
		table.insert(out, table.remove(left, pick) :: string)
	end
	return out
end

-- What a card's face shows.
function Draft.Face(id: string): Face
	local card = Config.Get("DraftCards", id)
	return {
		Id = id,
		Name = card.Name,
		Kind = card.Kind,
		Label = Draft.KIND_LABEL[card.Kind] or string.upper(card.Kind),
		Text = card.Short or card.Text,
		Room = card.Room,
	}
end

-- Votes for each option from ballots (voter -> option id); ballots for anything else don't count.
function Draft.Tally(ballots: { [any]: string }, options: { string }): { [string]: number }
	local counts: { [string]: number } = {}
	for _, option in options do
		counts[option] = 0
	end
	for _, choice in ballots do
		if counts[choice] ~= nil then
			counts[choice] += 1
		end
	end
	return counts
end

-- A controller's Y steps a draft vote along the cards (Prompt 19): the option after `current`
-- (the first when there is none), wrapping round.
function Draft.NextPick(options: { string }, current: string?): string?
	if #options == 0 then
		return nil
	end
	local at = if current then table.find(options, current) else nil
	return options[if at then at % #options + 1 else 1]
end

return table.freeze(Draft)
