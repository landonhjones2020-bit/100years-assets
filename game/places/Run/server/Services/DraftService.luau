--!strict
--[[
	DraftService: the blueprint draft (bible Section 8, the Appendix's card pool; Prompt 19). Run
	place only.

	* After every Surge (CycleClock.SurgeEnded) it draws Tuning.Draft.Cards (3) cards from the pool
	  (Rules.Draft: weighted, room cards heavier in Era I) and opens the team's draft vote
	  (VoteService, Config.Votes.Draft: most picks after 20 s, ties at random). The vote telegram
	  shows the cards under the year clock (Landon, Prompt 19). Solo runs pick too: the player's
	  pick is the card (Section 8, rule 6). The winning card applies at once and leaves the pool for
	  the run; the others go back.
	* Only cards the run can use come up: each of its modifiers has a home below (HANDLERS), a room
	  card's room isn't unlocked yet, the Steel Blast Door only below the door's top level. Cards
	  whose systems come with later prompts (Sump Pumps and Gas Filters: Prompt 23; Ammo Press and
	  Black Market: Prompt 30) stay out until their handlers exist.
	* What each card does (Config.Modifiers names the system):
	  * Room cards unlock their room (BuildService:Unlock).
	  * Bunker perks: RoomHP (BunkerGrid), FireSpread and BlackoutDuration (DisasterService),
	    DarkSpawnBonus (BreachService), BlastDoorLevel (the Blast Door goes up a level).
	  * Resident boons: ResidentLevels and MoraleNow (ResidentService), RecruitsNow and
	    RareRecruitNow (ExpeditionService:Recruit at the Blast Door).
	  * Player boons: WeaponRarityUp and StaminaMult (WeaponService; they hold for the rest of the
	    run, players who join later included), MedkitsPerPlayer (carried Medkits for everyone in the
	    run now).
	  * Risk deals: DigSpeed and DigDisturbance (DigService), RoomOutput on the Reactor Core
	    (EconomyService, which PowerService reads) and ReactorOverloadChance (each Surge, that
	    chance of the Reactor overload: DisasterService:StartMeltdown, OverloadDelay into the
	    Surge), BountyKills and BountyScrap (monster kills counted until the next Surge starts;
	    met, the Scrap is paid at once), NextTripLoot and NextStormEarlySeconds (SurfaceService:
	    double loot until the next storm, which hits that many seconds before its Surge).
	* Found blueprints (Landon, Prompt 19): a blueprint in loot is one card, drawn from the pool
	  when it's found (InventoryService's "Blueprint" special). Found on the surface or in the
	  Deep it goes into the finder's pack and counts once unloaded (InventoryService.CardsHome);
	  found in the bunker (a dug cache) or brought home by an expedition it is home at once. A card
	  that's home joins the next draft as an extra choice, FoundPerDraft at a time, stamped with
	  who found it; the team still votes, and if it isn't picked it goes back to the pool. A card
	  drafted meanwhile is swapped for another when it comes home.
	* Rerolls: RerollDraft (the remote) uses a free reroll, FreeDraftRerollsPerEra (the level 3
	  Mad Scientist: one per era). The paid Blueprint Reroll (49 Robux) is Prompt 28's and calls
	  Reroll(player, "Paid"). A reroll draws fresh cards (the found one stays), clears the picks
	  and starts the time over. Players carry DraftRerolls (free rerolls left this era).

	API:
		DraftService:Open(): (string?, string?)               -- a draft now (dev; normally after a Surge)
		DraftService:Reroll(player, how): (boolean, string?)  -- "Free" or "Paid"
		DraftService:AddFound(cardId?, by?, how): string?     -- a found blueprint is home
		DraftService:Take(cardId, how): boolean               -- apply a card (the vote's winner)
		DraftService:Taken(): { string }                      -- cards taken this run, in order
		DraftService.Drafted: Signal<string, string>          -- card id, how ("Draft", "Dev")
		DraftService.FoundHome: Signal<string, string>        -- card id, who or what found it
	Dev: draft, draft.open, draft.take <card>, draft.found [card], draft.reroll, draft.cards, bounty.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Draft = require(Shared.Rules.Draft)
local Expeditions = require(Shared.Rules.Expeditions)
local Log = require(Shared.Utilities.Log)
local Modifiers = require(Shared.Rules.Modifiers)
local Remotes = require(Shared.Remotes)
local RunState = require(Shared.RunState)
local Signal = require(Shared.Utilities.Signal)

local log = Log.new("DraftService")

local DraftService = {
	Name = "DraftService",
	Dependencies = {
		"CycleClock", "RunDirector", "SessionService", "VoteService", "BuildService", "BunkerGrid", "EconomyService",
		"DisasterService", "DigService", "BreachService", "ResidentService", "ExpeditionService", "WeaponService",
		"SurfaceService", "MonsterService", "InventoryService", "DevService",
	},
	Drafted = Signal.new() :: Signal.Signal<string, string>,
	FoundHome = Signal.new() :: Signal.Signal<string, string>,
}

type Found = { Card: string, By: string, UserId: number? }
type Current = { VoteId: string, Drawn: { string }, Found: Found? }

local clock: any = nil
local director: any = nil
local session: any = nil
local votes: any = nil
local build: any = nil
local grid: any = nil
local economy: any = nil
local disasters: any = nil
local dig: any = nil
local breaches: any = nil
local residents: any = nil
local expeditions: any = nil
local weapons: any = nil
local surface: any = nil
local monsters: any = nil
local inventory: any = nil

local taken: { [string]: boolean } = {}
local takenOrder: { string } = {}
local waiting: { Found } = {} -- found blueprints home, waiting for a draft
local current: Current? = nil
local rerollsUsed: { [number]: { [string]: number } } = {} -- UserId -> era -> free rerolls used
local overload: { [string]: number } = {} -- card -> chance of a Reactor overload each Surge
local bounty: { Need: number, Scrap: number, Kills: number, Card: string }? = nil
local rng = Random.new()

local function alertAll(kind: string, text: string)
	for _, player in Players:GetPlayers() do
		Remotes.FireClient("Alert", player, kind, text)
	end
end

local function alert(player: Player, kind: string, text: string)
	Remotes.FireClient("Alert", player, kind, text)
end

local function eraNumber(): number
	local era = Config.Find("Eras", clock:Era())
	return if era then era.Number else 1
end

local function blastDoor(): any
	return grid:RoomsOfType("BlastDoor")[1]
end

-- Modifier homes ----------------------------------------------------------------------------------

-- How each modifier a card carries is applied: (value, the modifier, the card's id). A card is
-- offered only when every one of its keys is here.
local HANDLERS: { [string]: (number, { [string]: any }, string) -> () } = {
	RoomHP = function(value, _m, card)
		grid:SetHPModifier(card, "RoomHP", value)
	end,
	FireSpread = function(value, _m, card)
		disasters:SetModifier(card, "FireSpread", value)
	end,
	BlackoutDuration = function(value, _m, card)
		disasters:SetModifier(card, "BlackoutDuration", value)
	end,
	DarkSpawnBonus = function(value, _m, card)
		breaches:SetModifier(card, "DarkSpawnBonus", value)
	end,
	BlastDoorLevel = function(value)
		local door = blastDoor()
		if door then
			local level = math.min(door.Level + math.floor(value), 3)
			grid:SetLevel(door.Id, level)
			alertAll("Info", `THE BLAST DOOR IS NOW LEVEL {level}`)
		end
	end,
	ResidentLevels = function(value, _m, card)
		residents:AddLevels(math.floor(value), Config.Get("DraftCards", card).Name)
	end,
	MoraleNow = function(value, _m, card)
		residents:AddMorale(value, Config.Get("DraftCards", card).Name)
	end,
	RecruitsNow = function(value, _m, card)
		local name = Config.Get("DraftCards", card).Name
		local chance = Config.Get("Tuning", "Expeditions").RadioRareChance
		for _ = 1, math.floor(value) do
			expeditions:Recruit(Expeditions.RecruitTier(rng:NextNumber(), chance), `answered the {name}`)
		end
	end,
	RareRecruitNow = function(value, _m, card)
		local name = Config.Get("DraftCards", card).Name
		for _ = 1, math.floor(value) do
			expeditions:Recruit("Rare", `joined as a {name}`)
		end
	end,
	WeaponRarityUp = function(value, _m, card)
		weapons:SetModifier(card, "WeaponRarityUp", value)
	end,
	StaminaMult = function(value, _m, card)
		weapons:SetModifier(card, "StaminaMult", value)
	end,
	MedkitsPerPlayer = function(value)
		for _, player in session:ReadyPlayers() do
			weapons:AddMedkits(player, math.floor(value))
		end
	end,
	DigSpeed = function(value, _m, card)
		dig:SetModifier(card, "DigSpeed", value)
	end,
	DigDisturbance = function(value, _m, card)
		dig:SetModifier(card, "DigDisturbance", value)
	end,
	RoomOutput = function(value, m, card)
		economy:SetModifier(card, "RoomOutput", value, m.Room)
	end,
	ReactorOverloadChance = function(value, _m, card)
		overload[card] = value
	end,
	BountyKills = function(value, _m, card)
		local b = bounty or { Need = 0, Scrap = 0, Kills = 0, Card = card }
		b.Need = math.floor(value)
		b.Card = card
		bounty = b
	end,
	BountyScrap = function(value, _m, card)
		local b = bounty or { Need = 0, Scrap = 0, Kills = 0, Card = card }
		b.Scrap = math.floor(value)
		bounty = b
	end,
	NextTripLoot = function(value)
		surface:SetLootBoost(value)
	end,
	NextStormEarlySeconds = function(value)
		surface:SetStormEarly(value)
	end,
}

-- Can the run use this card now?
local function usable(card: { [string]: any }): boolean
	for _, m in card.Modifiers or {} do
		if not HANDLERS[m.Key] then
			return false
		end
	end
	if card.Kind == "Room" then
		return card.Room ~= nil and not build:Unlocked()[card.Room]
	end
	for _, m in card.Modifiers or {} do
		if m.Key == "BlastDoorLevel" then
			local door = blastDoor()
			if not door or door.Level >= 3 then
				return false
			end
		end
	end
	return true
end

local function heldBack(): { [string]: boolean }
	local held: { [string]: boolean } = {}
	for _, f in waiting do
		held[f.Card] = true
	end
	if current then
		for _, id in current.Drawn do
			held[id] = true
		end
		if current.Found then
			held[current.Found.Card] = true
		end
	end
	return held
end

-- Applying a card ----------------------------------------------------------------------------------

function DraftService:Take(cardId: string, how: string): boolean
	local card = Config.Find("DraftCards", cardId)
	if not card or taken[cardId] then
		return false
	end
	taken[cardId] = true
	table.insert(takenOrder, cardId)
	if card.Kind == "Room" and card.Room then
		build:Unlock(card.Room)
	end
	for _, m in card.Modifiers or {} do
		local handler = HANDLERS[m.Key]
		if handler then
			local ok, err = pcall(handler, m.Value, m, cardId)
			if not ok then
				log:Error("%s: %s failed: %s", cardId, m.Key, tostring(err))
			end
		else
			log:Warn("%s: nothing applies %s yet", cardId, m.Key)
		end
	end
	if bounty and bounty.Card == cardId and bounty.Need > 0 then
		alertAll("Info", `BOUNTY: KILL {bounty.Need} MONSTERS BEFORE THE NEXT SURGE FOR {bounty.Scrap} SCRAP`)
	end
	log:Info("%s taken (%s)", cardId, how)
	DraftService.Drafted:Fire(cardId, how)
	return true
end

function DraftService:Taken(): { string }
	return table.clone(takenOrder)
end

-- Found blueprints ---------------------------------------------------------------------------------

-- A card for a blueprint just found (nil when the pool has nothing left to find).
local function drawFound(): string?
	local pool = Draft.Pool(taken, heldBack(), usable)
	return Draft.Draw(pool, 1, eraNumber(), rng)[1]
end

function DraftService:AddFound(cardId: string?, by: string?, how: string): string?
	local card = cardId
	if card and (taken[card] or heldBack()[card] or not Config.Find("DraftCards", card) or not usable(Config.Get("DraftCards", card))) then
		card = nil -- drafted meanwhile, or already waiting: another card
	end
	card = card or drawFound()
	if not card then
		log:Info("a blueprint came home (%s), but the pool has no card left for it", how)
		return nil
	end
	local finder = by or how
	table.insert(waiting, { Card = card, By = finder })
	local face = Draft.Face(card)
	alertAll("Info", `BLUEPRINT HOME: {string.upper(face.Name)} JOINS THE NEXT DRAFT`)
	log:Info("found blueprint %s home (%s, %s)", card, finder, how)
	DraftService.FoundHome:Fire(card, finder)
	return card
end

-- Drafts --------------------------------------------------------------------------------------------

local function optionFor(id: string, found: Found?): any
	local face = Draft.Face(id)
	return {
		Id = id,
		Title = string.upper(face.Name),
		Kind = face.Kind,
		Label = face.Label,
		Text = face.Text,
		Found = if found then string.upper(found.By) else nil, -- the card's FOUND stamp says the rest
	}
end

local function optionsOf(c: Current): { any }
	local options = {}
	for _, id in c.Drawn do
		table.insert(options, optionFor(id, nil))
	end
	if c.Found then
		table.insert(options, optionFor(c.Found.Card, c.Found))
	end
	return options
end

local function freeRerolls(player: Player): number
	local per = Modifiers.PlayerValue(player, "FreeDraftRerollsPerEra") or 0
	local used = (rerollsUsed[player.UserId] or {})[clock:Era()] or 0
	return math.max(math.floor(per) - used, 0)
end

local function publishRerolls()
	for _, player in Players:GetPlayers() do
		local left = freeRerolls(player)
		player:SetAttribute("DraftRerolls", if left > 0 then left else nil)
	end
end

local function closeDraft(c: Current, winner: string?)
	if current ~= c then
		return
	end
	current = nil
	if c.Found and winner ~= c.Found.Card then
		log:Info("found blueprint %s wasn't picked: back to the pool", c.Found.Card)
	end
	if winner then
		if director:Phase() == "Playing" then
			DraftService:Take(winner, "Draft")
		else
			log:Info("the run ended before %s could apply", winner)
		end
	end
end

function DraftService:Open(): (string?, string?)
	if director:Phase() ~= "Playing" then
		return nil, "the run isn't under way"
	end
	if current then
		return nil, "a draft is already open"
	end
	local t = Draft.Tuning()
	local held = heldBack()
	local found: Found? = nil
	if t.FoundPerDraft > 0 and #waiting > 0 then
		-- the next found card that can still be used (drafted meanwhile or no longer usable: back to the pool)
		while #waiting > 0 and not found do
			local f = table.remove(waiting, 1) :: Found
			held[f.Card] = nil
			if not taken[f.Card] and usable(Config.Get("DraftCards", f.Card)) then
				found = f
			end
		end
	end
	local pool = Draft.Pool(taken, held, usable)
	if found then
		local at = table.find(pool, found.Card)
		if at then
			table.remove(pool, at)
		end
	end
	local drawn = Draft.Draw(pool, t.Cards, eraNumber(), rng)
	if #drawn == 0 and not found then
		log:Info("no draft: the pool is empty")
		return nil, "the pool is empty"
	end
	local c: Current = { VoteId = "", Drawn = drawn, Found = found }
	current = c
	local id, why = votes:Open({
		Kind = "Draft",
		Title = "BLUEPRINT DRAFT",
		Options = optionsOf(c),
		OnPass = function(pick: string?)
			closeDraft(c, pick)
		end,
		OnFail = function(_reason: string)
			closeDraft(c, nil)
		end,
	})
	if not id then
		current = nil
		if found then
			table.insert(waiting, 1, found)
		end
		return nil, why
	end
	c.VoteId = id
	publishRerolls()
	log:Info("draft %s: %s%s", id, table.concat(drawn, ", "), if found then ` + found {found.Card}` else "")
	return id, nil
end

function DraftService:Reroll(player: Player, how: string): (boolean, string?)
	local c = current
	if not c then
		return false, "There's no draft to reroll."
	end
	local liveId = votes:Live()
	if liveId ~= c.VoteId then
		return false, "The draft isn't on the banner yet."
	end
	if how == "Free" and freeRerolls(player) <= 0 then
		return false, "You have no free reroll left this era."
	end
	-- fresh cards: the pool without the ones showing (unless that leaves nothing new)
	local held = heldBack()
	local pool = Draft.Pool(taken, held, usable)
	if #pool == 0 then
		return false, "There are no other cards to draw."
	end
	local drawn = Draft.Draw(pool, Draft.Tuning().Cards, eraNumber(), rng)
	c.Drawn = drawn
	if not votes:SetOptions(c.VoteId, optionsOf(c)) then
		return false, "The draft can't be rerolled now."
	end
	if how == "Free" then
		local used = rerollsUsed[player.UserId] or {}
		used[clock:Era()] = (used[clock:Era()] or 0) + 1
		rerollsUsed[player.UserId] = used
	end
	publishRerolls()
	alertAll("Info", `{string.upper(player.DisplayName)} REROLLED THE BLUEPRINTS`)
	log:Info("%s rerolled the draft (%s): %s", player.Name, how, table.concat(drawn, ", "))
	return true, nil
end

-- Risk deals over time ------------------------------------------------------------------------------

local function overloadChance(): number
	local none = 1
	for _, chance in overload do
		none *= 1 - math.clamp(chance, 0, 1)
	end
	return 1 - none
end

local function onSurgeStarted()
	-- Bounty Contract: time is up
	local b = bounty
	if b and b.Need > 0 then
		alertAll("Warning", `THE BOUNTY RAN OUT: {b.Kills} OF {b.Need} KILLS`)
		log:Info("bounty expired at %d of %d", b.Kills, b.Need)
		bounty = nil
	end
	-- Overclock: this Surge's chance of a Reactor overload
	local chance = overloadChance()
	if chance > 0 and rng:NextNumber() < chance then
		local delay = Draft.Tuning().OverloadDelay
		local cycle = clock:Cycle()
		task.delay(rng:NextNumber(delay.Min, delay.Max), function()
			if clock:Cycle() == cycle and clock:Phase() == "Surge" and director:Phase() == "Playing" then
				if disasters:StartMeltdown("Overclock") then
					alertAll("Danger", "THE OVERCLOCKED REACTOR IS OVERLOADING")
				end
			end
		end)
		log:Info("Overclock: a Reactor overload this Surge (chance %.2f)", chance)
	end
end

local function onMonsterDied()
	local b = bounty
	if not b or b.Need <= 0 or director:Phase() ~= "Playing" then
		return
	end
	b.Kills += 1
	if b.Kills >= b.Need then
		local paid = economy:Add("Scrap", b.Scrap, "the Bounty Contract")
		alertAll("Info", `BOUNTY MET: {b.Need} KILLS · +{paid} SCRAP`)
		log:Info("bounty met: +%d Scrap", paid)
		bounty = nil
	elseif b.Kills % math.max(Draft.Tuning().BountyAlertEvery, 1) == 0 then
		alertAll("Info", `BOUNTY: {b.Kills} OF {b.Need} KILLS`)
	end
end

-- Lifecycle -----------------------------------------------------------------------------------------

local function describe(): string
	local lines = {}
	if current then
		local found = if current.Found then ` + found {current.Found.Card} ({current.Found.By})` else ""
		table.insert(lines, `draft {current.VoteId}: {table.concat(current.Drawn, ", ")}{found}`)
	else
		table.insert(lines, "no draft open")
	end
	table.insert(lines, `taken ({#takenOrder}): {if #takenOrder > 0 then table.concat(takenOrder, ", ") else "none"}`)
	local w = {}
	for _, f in waiting do
		table.insert(w, `{f.Card} ({f.By})`)
	end
	table.insert(lines, `found, waiting: {if #w > 0 then table.concat(w, ", ") else "none"}`)
	local pool = Draft.Pool(taken, heldBack(), usable)
	table.insert(lines, `pool now ({#pool}): {table.concat(pool, ", ")}`)
	if bounty then
		table.insert(lines, `bounty: {bounty.Kills} of {bounty.Need} for {bounty.Scrap} Scrap`)
	end
	local chance = overloadChance()
	if chance > 0 then
		table.insert(lines, string.format("Reactor overload chance each Surge: %.2f", chance))
	end
	return table.concat(lines, "\n")
end

function DraftService:Init(registry)
	clock = registry.CycleClock
	director = registry.RunDirector
	session = registry.SessionService
	votes = registry.VoteService
	build = registry.BuildService
	grid = registry.BunkerGrid
	economy = registry.EconomyService
	disasters = registry.DisasterService
	dig = registry.DigService
	breaches = registry.BreachService
	residents = registry.ResidentService
	expeditions = registry.ExpeditionService
	weapons = registry.WeaponService
	surface = registry.SurfaceService
	monsters = registry.MonsterService
	inventory = registry.InventoryService

	-- found blueprints: a card goes into the finder's pack (surface, the Deep), or straight home (the bunker)
	inventory:SetSpecial("Blueprint", function(player: Player, count: number): number
		local took = 0
		for _ = 1, count do
			local card = drawFound()
			if not card then
				return count -- nothing left to find: the blueprint is taken, as nothing
			end
			if surface:Zone(player) == "Bunker" then
				DraftService:AddFound(card, player.DisplayName, "found in the bunker")
				took += 1
			elseif inventory:GiveCard(player, card) then
				took += 1
				alert(player, "Info", `BLUEPRINT: {string.upper(Draft.Face(card).Name)} · HAUL IT HOME FOR THE NEXT DRAFT`)
			end
		end
		return took
	end)

	Remotes.OnServer("RerollDraft", function(player: Player, voteId: string)
		if not current or current.VoteId ~= voteId then
			alert(player, "Info", "That draft is over.")
			return
		end
		local ok, why = DraftService:Reroll(player, "Free")
		if not ok and why then
			alert(player, "Info", why)
		end
	end)

	local dev = registry.DevService
	dev:Register("draft", {
		Description = "The draft: the open one, cards taken, found blueprints waiting, the pool (Prompt 19).",
		Usage = "draft",
		Run = function(): string?
			return describe()
		end,
	})
	dev:Register("draft.open", {
		Description = "Open a draft now (normally one opens after every Surge).",
		Usage = "draft.open",
		Run = function(): string?
			local id, why = DraftService:Open()
			return if id then `opened {id}\n{describe()}` else `no draft: {why}`
		end,
	})
	dev:Register("draft.take", {
		Description = "Apply a card now, as if the team had drafted it.",
		Usage = "draft.take <card id>",
		Run = function(_player: Player?, args): string?
			local id = tostring(args[1] or "")
			local card = Config.Find("DraftCards", id)
			if not card then
				return `no card {id}; ids: {table.concat(Config.Ids("DraftCards"), ", ")}`
			end
			if taken[id] then
				return `{id} is already taken`
			end
			if not usable(card) then
				return `{id} can't be used now (its system comes later, its room is unlocked, or the door is at its top level)`
			end
			DraftService:Take(id, "Dev")
			return describe()
		end,
	})
	dev:Register("draft.found", {
		Description = "A found blueprint is home (a card, else one drawn): it joins the next draft.",
		Usage = "draft.found [card id]",
		Run = function(player: Player?, args): string?
			local card = DraftService:AddFound(if args[1] then tostring(args[1]) else nil,
				if player then player.DisplayName else "the dev tools", "dev")
			return if card then `found {card}\n{describe()}` else "no card left to find"
		end,
	})
	dev:Register("draft.reroll", {
		Description = "Reroll the live draft as you (a free reroll, or 'paid' to skip the class check).",
		Usage = "draft.reroll [paid]",
		Run = function(player: Player?, args): string?
			local who = player or session:ReadyPlayers()[1]
			if not who then
				return "nobody is in the run"
			end
			local ok, why = DraftService:Reroll(who, if tostring(args[1] or "") == "paid" then "Paid" else "Free")
			return if ok then describe() else `no reroll: {why}`
		end,
	})
	dev:Register("draft.cards", {
		Description = "Every card: kind, weight now, usable, taken.",
		Usage = "draft.cards",
		Run = function(): string?
			local lines = {}
			for _, id in Config.Ids("DraftCards") do
				local card = Config.Get("DraftCards", id)
				table.insert(lines, `{id} ({card.Kind}) w{Draft.Weight(card, eraNumber())}{if taken[id] then " taken" elseif usable(card) then "" else " not usable"}`)
			end
			return table.concat(lines, "\n")
		end,
	})
	dev:Register("bounty", {
		Description = "Bounty Contract progress, or add kills to it.",
		Usage = "bounty [kills to add]",
		Run = function(_player: Player?, args): string?
			if not bounty then
				return "no bounty"
			end
			for _ = 1, math.clamp(math.floor(tonumber(args[1]) or 0), 0, 100) do
				onMonsterDied()
			end
			return if bounty then `bounty: {bounty.Kills} of {bounty.Need} for {bounty.Scrap} Scrap` else "bounty met"
		end,
	})
end

function DraftService:Start()
	clock.SurgeEnded:Connect(function(_kind: string, _how: string)
		-- after the final Surge the run is over (CenturySurvived): no draft
		task.defer(function()
			if director:Phase() == "Playing" then
				local _, why = DraftService:Open()
				if why then
					log:Debug("no draft after the Surge: %s", why)
				end
			end
		end)
	end)
	clock.SurgeStarted:Connect(onSurgeStarted)
	clock.EraChanged:Connect(publishRerolls)
	monsters.Died:Connect(onMonsterDied)
	inventory.CardsHome:Connect(function(player: Player, cards: { string })
		for _, card in cards do
			DraftService:AddFound(card, player.DisplayName, "hauled home")
		end
	end)
	expeditions.BlueprintsHome:Connect(function(count: number, destination: string)
		for _ = 1, count do
			DraftService:AddFound(nil, if destination == "Deep" then "the Deep expedition" else "the surface expedition", "an expedition")
		end
	end)
	session.PlayerReady:Connect(function(_player: Player)
		publishRerolls()
	end)
	for _, player in Players:GetPlayers() do
		player:GetAttributeChangedSignal("ClassLevel"):Connect(publishRerolls)
		player:GetAttributeChangedSignal("Class"):Connect(publishRerolls)
	end
	Players.PlayerAdded:Connect(function(player: Player)
		player:GetAttributeChangedSignal("ClassLevel"):Connect(publishRerolls)
		player:GetAttributeChangedSignal("Class"):Connect(publishRerolls)
	end)
	RunState.Changed("RunPhase"):Connect(function()
		if RunState.Get("RunPhase") ~= "Playing" then
			bounty = nil
		end
	end)
end

return DraftService
