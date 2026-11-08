--!strict
--[[
	VoteController: what a vote looks like (bible Section 8): "a slim banner under the year clock
	shows who proposed what, the cost, the tally and a timer, with large yes and no buttons. It
	never blocks the screen. The proposed room appears as a ghost outline in the Command View. One
	chime plays when a vote opens, another when it passes." Run place only.

	* The telegram (StarterGui.Votes.VoteBanner, above The Frame, so a vote can be answered from
	  the Command View or any other screen) shows the live vote from the Votes collection
	  (VoteService):
	  * "LANDON PROPOSES: KITCHEN  ·  120 SCRAP";
	  * "YES 2  ·  NO 1  ·  12 S  ·  MORE YES THAN NO  ·  1 WAITING";
	  * the timer strip running down;
	  * YES and NO. Your vote stays pressed in, and you can change it until the vote closes.
	  When a vote closes the telegram shows PASSED or FAILED and why, then the next vote.
	* On PC the mouse belongs to the camera: hold Left Alt to click the buttons (the HUD's rule).
	* Ghost outlines in the Command View for open proposals ("KITCHEN?") and for construction
	  sites ("KITCHEN 45%"), from the Votes and Sites collections.
	* The Command View's Propose (SetHandler for Build, Upgrade, Merge and TearDown) sends the
	  Propose remote. BuildService answers on the telegram, or with an alert when it refuses.
	* Chimes: SoundService.VoteOpen and SoundService.VotePassed, when they exist (Prompt 32's
	  audio).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local Lib = script.Parent.Parent:WaitForChild("Lib")
local KitRuntime = require(Lib:WaitForChild("KitRuntime"))

local log = Log.new("VoteController")

local ACTIONS = { "Build", "Upgrade", "Merge", "TearDown" }
local RESULT_WITH_NEXT = 1.5 -- seconds a result stays when another vote is already live
local LEAF = Color3.fromHex("#6F9B4C")
local RUST = Color3.fromHex("#B5412B")
local INK = Color3.fromHex("#2A3B4C")

local VoteController = {
	Name = "VoteController",
	Dependencies = { "ReplicaController", "CommandViewController" },
}

local replica: any = nil
local commandView: any = nil
local gui: ScreenGui? = nil
local banner: any = nil
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
	if not id or not vote then
		banner.Visible = false
		shownId, shownStatus = nil, nil
		return
	end
	if id ~= shownId then
		shownId, shownStatus = id, vote.Status
		if vote.Status == "Live" then
			chime("VoteOpen")
		end
	end
	banner.Visible = true
	local cost = if type(vote.Cost) == "string" and vote.Cost ~= "" and vote.Cost ~= "FREE" then `  ·  {vote.Cost}` else ""
	banner.Proposal.Text = `{vote.ProposerName} PROPOSES: {vote.Title}{cost}`
	local yes, no = banner.Yes, banner.No
	local fill = banner.Timer.Fill
	if vote.Status == "Live" then
		local left = math.max(0, (vote.EndsAt or 0) - workspace:GetServerTimeNow())
		local waiting = waitingCount()
		banner.Tally.Text = `YES {vote.Yes}  ·  NO {vote.No}  ·  {math.ceil(left)} S  ·  {vote.Need}`
			.. (if waiting > 0 then `  ·  {waiting} WAITING` else "")
		banner.Tally.TextColor3 = INK
		fill.Size = UDim2.fromScale(math.clamp(left / math.max(vote.Seconds or 1, 1), 0, 1), 1)
		local ballot = myBallot(vote)
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
	end
end

local function cast(ballot: string)
	local id, vote = pick()
	if id and vote and vote.Status == "Live" then
		Remotes.FireServer("CastVote", id, ballot)
	end
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
			local name = if info then string.upper(info.Name) else tostring(site.Type)
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

function VoteController:Init(registry)
	replica = registry.ReplicaController
	commandView = registry.CommandViewController
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
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
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
