--!strict
--[[
	VoteController: what a vote looks like (bible Section 8): "a slim banner under the year clock
	shows who proposed what, the cost, the tally and a timer, with large yes and no buttons. It
	never blocks the screen. The proposed room appears as a ghost outline in the Command View. One
	chime plays when a vote opens, another when it passes." Run place only.

	* The telegram (StarterGui.Votes.VoteBanner, above The Frame, so a vote can be answered from
	  the Command View or any other screen) shows the live vote from the Votes collection
	  (VoteService):
	  * what, and its cost: "KITCHEN  ·  120 SCRAP", or what comes back: "TEAR DOWN KITCHEN  ·
	    50 SCRAP BACK";
	  * who, the tally and the time: "LANDON  ·  YES 2  ·  NO 1  ·  12 S", plus what it needs when
	    that isn't the usual more yes than no ("3 OF 4 MUST SAY YES"), and "1 WAITING";
	  * the timer strip running down;
	  * YES and NO. Your vote stays pressed in, and you can change it until the vote closes.
	  When a vote closes the telegram shows PASSED or FAILED and why, then the next vote.
	* On PC the mouse belongs to the camera: click the mouse wheel to free the cursor and click
	  the buttons (the HUD's rule). On a controller (Landon, Nov 8, 2026): tap Y for yes, hold Y
	  for no (HOLD_SECONDS). The Frame's screens use Y for their main action, so while your
	  ballot is still open Y votes on any screen (a binding above The Frame's); once you have
	  voted, Y changes your vote only outside the screens. The buttons show their key chips
	  whenever Y would vote, on a gamepad. Touch players tap the buttons.
	* Ghost outlines in the Command View for open proposals ("KITCHEN?") and for construction
	  sites ("KITCHEN 45%"; an upgrade on Nightmare: "LEVEL 2 45%"), from the Votes and Sites
	  collections.
	* The Command View's Propose (SetHandler for Build, Upgrade, Merge and TearDown) sends the
	  Propose remote. BuildService answers on the telegram, or with an alert when it refuses.
	* Chimes: SoundService.VoteOpen and SoundService.VotePassed, when they exist (Prompt 32's
	  audio).
	* The blueprint draft (Prompt 19; Landon: "3 small catalog cards drop under the clock; tap one
	  to vote; you can still move and fight"): a vote with Options. The telegram names the draft,
	  counts the picks and runs the timer; the cards (Votes.Draft, up to four: three drawn and a
	  found blueprint stamped FOUND) hang below it, each in its kind's colours with its name, its
	  short text and its picks so far. Click or tap a card to pick it (PC: free the cursor first);
	  your pick has an orange frame, and you can change it until the draft closes. On a controller
	  a tap of Y moves your pick to the next card, a hold to the one before. When it closes the
	  winner glows for a moment. A player with a free reroll (the level 3 Mad Scientist's
	  DraftRerolls attribute) gets REROLL where YES and NO are.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local Draft = require(Shared.Rules.Draft)
local Lib = script.Parent.Parent:WaitForChild("Lib")
local KitRuntime = require(Lib:WaitForChild("KitRuntime"))
local UIKit = require(Lib:WaitForChild("UIKit"))

local log = Log.new("VoteController")

local ACTIONS = { "Build", "Upgrade", "Merge", "TearDown" }
local RESULT_WITH_NEXT = 1.5 -- seconds a result stays when another vote is already live
local LEAF = Color3.fromHex("#6F9B4C")
local RUST = Color3.fromHex("#B5412B")
local INK = Color3.fromHex("#2A3B4C")

local VoteController = {
	Name = "VoteController",
	Dependencies = { "ReplicaController", "CommandViewController", "InputController" },
}

local HOLD_SECONDS = 0.5 -- a controller's Y held this long votes no; a shorter tap votes yes
local VOTE_NOW = "100Y_VoteNow" -- Y above The Frame's main action while your ballot is open
local VOTE_NOW_PRIORITY = Enum.ContextActionPriority.High.Value + 30

local replica: any = nil
local commandView: any = nil
local input: any = nil
local yDownAt: number? = nil -- when Y went down (a controller's vote)
local yHeld = false -- this press already voted no
local voteNowBound = false
local yVotes = false -- would Y vote right now (the key chips show)
local showKeys: () -> () -- below
local bindVoteNow: (pending: boolean) -> () -- below
local gui: ScreenGui? = nil
local banner: any = nil
local draftFrame: any = nil -- Votes.Draft (Prompt 19)
local shownId: string? = nil -- the vote on the telegram
local shownStatus: string? = nil
local resultUntil = 0
local ghosts: { [string]: boolean } = {} -- the ghost ids this controller made
local missingChimes: { [string]: boolean } = {}

local function chime(name: string)
	local sound = SoundService:FindFirstChild(name)
	if sound and sound:IsA("Sound") then
		SoundService:PlayLocalSound(sound)
	elseif not missingChimes[name] then
		missingChimes[name] = true
		log:Debug("no SoundService.%s yet (the audio prompt adds it)", name)
	end
end

local function myBallot(vote: any): string?
	local ballots = vote.Ballots
	return if type(ballots) == "table" then ballots[tostring(Players.LocalPlayer.UserId)] else nil
end

-- The vote the telegram shows: a result just in, else the live vote.
local function pick(): (string?, any)
	local votes = replica:All("Votes")
	local shown = if shownId then votes[shownId] else nil
	if shown and (shown.Status == "Passed" or shown.Status == "Failed") and os.clock() < resultUntil then
		return shownId, shown
	end
	for id, vote in votes do
		if type(vote) == "table" and vote.Status == "Live" then
			return id, vote
		end
	end
	return nil, nil
end

local function waitingCount(): number
	local n = 0
	for _, vote in replica:All("Votes") do
		if type(vote) == "table" and vote.Status == "Queued" then
			n += 1
		end
	end
	return n
end

local function anotherLive(except: string?): boolean
	for id, vote in replica:All("Votes") do
		if id ~= except and type(vote) == "table" and vote.Status == "Live" then
			return true
		end
	end
	return false
end

local function optionIds(vote: any): { string }
	local ids = {}
	for _, option in (if type(vote.Options) == "table" then vote.Options else {}) do
		table.insert(ids, option.Id)
	end
	return ids
end

local function isDraft(vote: any): boolean
	return type(vote) == "table" and type(vote.Options) == "table"
end

-- The draft's cards under the telegram (Prompt 19).
local function renderDraft(vote: any?)
	if not draftFrame then
		return
	end
	if not vote or not isDraft(vote) then
		draftFrame.Visible = false
		return
	end
	draftFrame.Visible = true
	local mine = myBallot(vote)
	local row = draftFrame.Cards
	for i = 1, 4 do
		local card = row:FindFirstChild(`Card{i}`)
		if card then
			local option = vote.Options[i]
			card.Visible = option ~= nil
			if option then
				local sprite = `Draft_{option.Kind or "Room"}`
				if card:GetAttribute("Sprite") ~= sprite then
					KitRuntime.SetSprite(card, sprite)
				end
				card.Title.Text = option.Title or option.Id
				card.Text.Text = option.Text or ""
				card.Votes.Count.Text = tostring(option.Votes or 0)
				card.Pick.Visible = vote.Status == "Live" and mine == option.Id
				card.Won.Visible = vote.Status == "Passed" and vote.Winner == option.Id
				card.Found.Visible = option.Found ~= nil
				card.FoundBy.Visible = option.Found ~= nil
				card.FoundBy.Text = option.Found or ""
			end
		end
	end
end

local function render()
	if not banner then
		return
	end
	-- a vote that just closed: note when its result stops showing, and chime a pass
	if shownId then
		local current = replica:Get("Votes", shownId)
		local status = if type(current) == "table" then current.Status else nil
		if status ~= shownStatus and (status == "Passed" or status == "Failed") then
			resultUntil = os.clock() + (if anotherLive(shownId) then RESULT_WITH_NEXT else Config.Get("Tuning", "Votes").ResultSeconds)
			if status == "Passed" then
				chime("VotePassed")
			end
		end
		shownStatus = status
	end
	local id, vote = pick()
	renderDraft(vote)
	if not id or not vote then
		banner.Visible = false
		shownId, shownStatus = nil, nil
		yVotes = false
		bindVoteNow(false)
		showKeys()
		return
	end
	if id ~= shownId then
		shownId, shownStatus = id, vote.Status
		if vote.Status == "Live" then
			chime("VoteOpen")
		end
	end
	banner.Visible = true
	local yes, no = banner.Yes, banner.No
	local fill = banner.Timer.Fill
	local drafting = isDraft(vote)
	yes.Visible = not drafting
	no.Visible = not drafting
	local reroll = banner:FindFirstChild("Reroll")
	if reroll then
		local free = Players.LocalPlayer:GetAttribute("DraftRerolls")
		reroll.Visible = drafting and vote.Status == "Live" and type(free) == "number" and free > 0
	end
	if drafting then
		-- the blueprint draft (Prompt 19): the cards below are the buttons
		banner.Proposal.Text = `{vote.Title}  ·  PICK A CARD`
		if vote.Status == "Live" then
			local left = math.max(0, (vote.EndsAt or 0) - workspace:GetServerTimeNow())
			local waiting = waitingCount()
			local key = if input:Device() == "Gamepad" then "  ·  Y: NEXT CARD" else ""
			banner.Tally.Text = `{vote.Picked or 0} OF {vote.Team or 1} PICKED  ·  {math.ceil(left)} S{key}`
				.. (if waiting > 0 then `  ·  {waiting} WAITING` else "")
			banner.Tally.TextColor3 = INK
			fill.Size = UDim2.fromScale(math.clamp(left / math.max(vote.Seconds or 1, 1), 0, 1), 1)
			local ballot = myBallot(vote)
			bindVoteNow(ballot == nil)
			yVotes = ballot == nil or not input:IsBlocked()
		else
			banner.Tally.Text = tostring(vote.Result or vote.Status)
			banner.Tally.TextColor3 = if vote.Status == "Passed" then LEAF else RUST
			fill.Size = UDim2.fromScale(0, 1)
			bindVoteNow(false)
			yVotes = false
		end
		showKeys()
		return
	end
	-- line 1: what and what it costs; line 2: who, the tally, the time and what it needs
	local cost = if type(vote.Cost) == "string" and vote.Cost ~= "" and vote.Cost ~= "FREE" then `  ·  {vote.Cost}`
		elseif type(vote.Refund) == "string" then `  ·  {vote.Refund} BACK`
		else ""
	banner.Proposal.Text = `{vote.Title}{cost}`
	if vote.Status == "Live" then
		local left = math.max(0, (vote.EndsAt or 0) - workspace:GetServerTimeNow())
		local waiting = waitingCount()
		local need = if vote.Rule ~= "MoreYes" then `  ·  {vote.Need}` else "" -- "more yes than no" is the usual rule
		banner.Tally.Text = `{vote.ProposerName}  ·  YES {vote.Yes}  ·  NO {vote.No}  ·  {math.ceil(left)} S{need}`
			.. (if waiting > 0 then `  ·  {waiting} WAITING` else "")
		banner.Tally.TextColor3 = INK
		fill.Size = UDim2.fromScale(math.clamp(left / math.max(vote.Seconds or 1, 1), 0, 1), 1)
		local ballot = myBallot(vote)
		bindVoteNow(ballot == nil)
		-- Y votes while the ballot is open, and outside the screens afterwards (to change it)
		yVotes = ballot == nil or not input:IsBlocked()
		showKeys()
		KitRuntime.SetEnabled(yes, true)
		KitRuntime.SetEnabled(no, true)
		KitRuntime.SetLatched(yes, ballot == "Yes")
		KitRuntime.SetLatched(no, ballot == "No")
	else
		banner.Tally.Text = tostring(vote.Result or vote.Status)
		banner.Tally.TextColor3 = if vote.Status == "Passed" then LEAF else RUST
		fill.Size = UDim2.fromScale(0, 1)
		KitRuntime.SetLatched(yes, false)
		KitRuntime.SetLatched(no, false)
		KitRuntime.SetEnabled(yes, false)
		KitRuntime.SetEnabled(no, false)
		bindVoteNow(false)
		yVotes = false
		showKeys()
	end
end

local function cast(ballot: string)
	local id, vote = pick()
	if id and vote and vote.Status == "Live" and not isDraft(vote) then
		Remotes.FireServer("CastVote", id, ballot)
	end
end

-- A draft pick (Prompt 19): a card's option id.
local function castPick(optionId: string?)
	local id, vote = pick()
	if optionId and id and vote and vote.Status == "Live" and isDraft(vote) then
		Remotes.FireServer("CastPick", id, optionId)
	end
end

-- A controller's Y on a draft: the next card (a tap) or the one before (a hold).
local function stepPick(back: boolean)
	local _, vote = pick()
	if not vote or not isDraft(vote) then
		return
	end
	local ids = optionIds(vote)
	if back then
		local reversed = {}
		for i = #ids, 1, -1 do
			table.insert(reversed, ids[i])
		end
		ids = reversed
	end
	castPick(Draft.NextPick(ids, myBallot(vote)))
end

-- Ghost outlines in the Command View: open proposals and construction sites.
local function syncGhosts()
	local want: { [string]: { any } } = {}
	for id, vote in replica:All("Votes") do
		local subject = if type(vote) == "table" then vote.Subject else nil
		if type(subject) == "table" and (vote.Status == "Live" or vote.Status == "Queued") then
			want["vote:" .. id] = { subject.Floor, subject.Column, subject.Span, subject.Label }
		end
	end
	for id, site in replica:All("Sites") do
		if type(site) == "table" then
			local info = Config.Find("Rooms", site.Type)
			local name = if site.Kind == "Upgrade" then `LEVEL {site.Level}`
				elseif info then string.upper(info.Name)
				else tostring(site.Type)
			want["site:" .. id] = { site.Floor, site.Column, site.Span, `{name} {math.floor((site.Progress or 0) * 100)}%` }
		end
	end
	for key, g in want do
		if ghosts[key] then
			commandView:SetGhostLabel(key, g[4])
		else
			commandView:ShowGhost(key, g[1], g[2], g[3], g[4])
			ghosts[key] = true
		end
	end
	for key in ghosts do
		if not want[key] then
			commandView:HideGhost(key)
			ghosts[key] = nil
		end
	end
end

function VoteController:State(): { [string]: any }
	local id, vote = pick()
	return {
		Shown = id,
		Visible = banner ~= nil and banner.Visible,
		Proposal = if banner then banner.Proposal.Text else nil,
		Tally = if banner then banner.Tally.Text else nil,
		Mine = if vote then myBallot(vote) else nil,
		Draft = if vote and isDraft(vote) then table.concat(optionIds(vote), ",") else nil,
		DraftShown = draftFrame ~= nil and draftFrame.Visible,
		Ghosts = (function()
			local keys = {}
			for key in ghosts do
				table.insert(keys, key)
			end
			table.sort(keys)
			return table.concat(keys, ",")
		end)(),
	}
end

-- The key chips show on a gamepad while Y would vote (PC clicks, touch taps).
showKeys = function()
	if not banner then
		return
	end
	local visible = yVotes and input:Device() == "Gamepad"
	for _, name in { "Yes", "No" } do
		local key = banner[name]:FindFirstChild("Key")
		if key and key.Visible ~= visible then
			key.Visible = visible
		end
	end
end

-- A controller's Y: a tap votes yes; held for HOLD_SECONDS it votes no (once per press).
local function yBegan()
	yDownAt = os.clock()
	yHeld = false
end

local function drafting(): boolean
	local _, vote = pick()
	return isDraft(vote)
end

local function yEnded()
	if yDownAt and not yHeld then
		if drafting() then
			stepPick(false)
		else
			cast("Yes")
		end
	end
	yDownAt = nil
	yHeld = false
end

local function checkHold()
	if yDownAt and not yHeld and os.clock() - yDownAt >= HOLD_SECONDS then
		yHeld = true
		if drafting() then
			stepPick(true)
		else
			cast("No")
		end
	end
end

-- While your ballot is open (and while Y is still held), Y is bound above The Frame's main action.
bindVoteNow = function(pending: boolean)
	local want = pending or yDownAt ~= nil
	if want == voteNowBound then
		return
	end
	voteNowBound = want
	if want then
		ContextActionService:BindActionAtPriority(VOTE_NOW, function(_name, state: Enum.UserInputState): Enum.ContextActionResult
			if state == Enum.UserInputState.Begin then
				yBegan()
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				yEnded()
			end
			return Enum.ContextActionResult.Sink
		end, false, VOTE_NOW_PRIORITY, Enum.KeyCode.ButtonY)
	else
		ContextActionService:UnbindAction(VOTE_NOW)
	end
end

function VoteController:Init(registry)
	replica = registry.ReplicaController
	commandView = registry.CommandViewController
	input = registry.InputController
end

function VoteController:Start()
	if Constants.PlaceKind() ~= "Run" then
		return
	end
	for _, action in ACTIONS do
		commandView:SetHandler(action, function(choice: any)
			local detail = if action == "Build" then (choice.RoomType or "") elseif action == "Merge" then (choice.Other or "") else ""
			Remotes.FireServer("Propose", action, choice.Floor, choice.Column, detail)
		end)
	end
	replica:Changed("Votes"):Connect(syncGhosts)
	replica:Changed("Sites"):Connect(syncGhosts)
	syncGhosts()

	local found = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Votes", 20)
	if not found or not found:IsA("ScreenGui") then
		log:Warn("no Votes ScreenGui in this place: the vote telegram can't show")
		return
	end
	gui = found
	KitRuntime.Watch(found)
	banner = found:FindFirstChild("VoteBanner")
	if not banner then
		log:Warn("the Votes ScreenGui has no VoteBanner")
		return
	end
	banner.Yes.Activated:Connect(function()
		cast("Yes")
	end)
	banner.No.Activated:Connect(function()
		cast("No")
	end)
	-- the blueprint draft (Prompt 19)
	draftFrame = found:FindFirstChild("Draft")
	if draftFrame then
		-- load the card atlases now, so the first draft's cards show at once
		task.spawn(function()
			local images: { string } = {}
			for _, kind in { "Room", "BunkerPerk", "ResidentBoon", "PlayerBoon", "RiskDeal" } do
				local sprite = UIKit.Sprites[`Draft_{kind}`]
				if sprite and not table.find(images, sprite.image) then
					table.insert(images, sprite.image)
				end
			end
			local holders = {}
			for _, image in images do
				local label = Instance.new("ImageLabel")
				label.Image = image
				table.insert(holders, label)
			end
			pcall(function()
				game:GetService("ContentProvider"):PreloadAsync(holders)
			end)
		end)
		for i = 1, 4 do
			local card = draftFrame.Cards:FindFirstChild(`Card{i}`)
			if card then
				card.Activated:Connect(function()
					local _, vote = pick()
					if vote and isDraft(vote) then
						local option = vote.Options[i]
						castPick(if option then option.Id else nil)
					end
				end)
			end
		end
	else
		log:Warn("the Votes ScreenGui has no Draft: the blueprint draft can't show (studio/ui/patches/Votes_P19.lua)")
	end
	local reroll = banner:FindFirstChild("Reroll")
	if reroll then
		reroll.Activated:Connect(function()
			local id, vote = pick()
			if id and vote and isDraft(vote) and vote.Status == "Live" then
				Remotes.FireServer("RerollDraft", id)
			end
		end)
	end
	input:On("Vote", yBegan, yEnded)
	input.DeviceChanged:Connect(showKeys)
	showKeys()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		checkHold()
		elapsed += dt
		if elapsed >= 0.1 then
			elapsed = 0
			render()
		end
	end)
	render()
	log:Debug("vote telegram ready")
end

return VoteController
