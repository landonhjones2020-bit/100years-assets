--!strict
--[[
	NPCAnimator: plays residents' (and later monsters') animations from replicated state (bible
	Section 23: animations play on clients from a replicated Activity attribute, which keeps the
	server light and avoids Animate scripts in NPCs). Run place only.

	It watches workspace.Bunker.Residents. For each body, the clip in Config.Animations whose Rig
	and Activity match the body's Activity attribute plays, looped as the clip says; any other
	activity stops it. Today there is the walk (A0); A3 adds working, eating and sleeping clips
	with no code change.
]]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Log = require(Shared.Utilities.Log)

local log = Log.new("NPCAnimator")

local NPCAnimator = {
	Name = "NPCAnimator",
	Dependencies = {},
}

type Watched = { Tracks: { [string]: AnimationTrack }, Playing: AnimationTrack?, Connections: { RBXScriptConnection } }

local watched: { [Model]: Watched } = {}
local clips: { [string]: any } = {} -- activity -> Config.Animations entry (R15)

local function trackFor(model: Model, state: Watched, activity: string): AnimationTrack?
	local clip = clips[activity]
	if not clip then
		return nil
	end
	local existing = state.Tracks[activity]
	if existing then
		return existing
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = clip.Id
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	if not ok or not track then
		log:Warn("couldn't load %s for %s: %s", clip.Id, model.Name, tostring(track))
		return nil
	end
	track.Looped = clip.Looped
	state.Tracks[activity] = track
	return track
end

local function apply(model: Model)
	local state = watched[model]
	if not state then
		return
	end
	local activity = model:GetAttribute("Activity")
	local track = if type(activity) == "string" then trackFor(model, state, activity) else nil
	if state.Playing and state.Playing ~= track then
		state.Playing:Stop(0.2)
		state.Playing = nil
	end
	if track and not track.IsPlaying then
		track:Play(0.2)
		state.Playing = track
	end
end

local function watch(model: Instance)
	if not model:IsA("Model") or watched[model] then
		return
	end
	local state: Watched = { Tracks = {}, Playing = nil, Connections = {} }
	watched[model] = state
	table.insert(state.Connections, model:GetAttributeChangedSignal("Activity"):Connect(function()
		apply(model)
	end))
	table.insert(state.Connections, model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			for _, connection in state.Connections do
				connection:Disconnect()
			end
			watched[model] = nil
		end
	end))
	-- the Animator arrives from the server with the body
	task.defer(apply, model)
end

function NPCAnimator:Init() end

function NPCAnimator:Start()
	if Constants.PlaceKind() ~= "Run" then
		return
	end
	local ids = {}
	for _, clip in Config.All("Animations") do
		if clip.Rig == "R15" then
			clips[clip.Activity] = clip
			table.insert(ids, clip.Id)
		end
	end
	task.spawn(function()
		local animations = {}
		for _, id in ids do
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			table.insert(animations, animation)
		end
		pcall(function()
			ContentProvider:PreloadAsync(animations)
		end)
	end)
	task.spawn(function()
		local bunker = workspace:WaitForChild("Bunker", 60)
		local holder = bunker and bunker:WaitForChild("Residents", 60)
		if not holder then
			log:Warn("no workspace.Bunker.Residents: residents won't animate")
			return
		end
		for _, model in holder:GetChildren() do
			watch(model)
		end
		holder.ChildAdded:Connect(watch)
		log:Debug("watching residents (%d clips)", #ids)
	end)
end

return NPCAnimator
