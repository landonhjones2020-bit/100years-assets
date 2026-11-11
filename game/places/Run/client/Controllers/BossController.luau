--!strict
--[[
	BossController: what players see of a boss fight beyond the boss itself (bible Sections 10 and
	18; Prompt 15). Run place only. The server's BossService decides everything; this draws the
	Boss collection's "Fight" entry.

	* The HUD's boss bar under the cycle bar: the boss's name, BREAKING THROUGH while it comes,
	  its phase (PHASE 1 OF 2), and its health draining; DEAD when it falls.
	* The camera shakes when the boss breaks through the floor, when its slam or bite lands near
	  the player (the model's AttackAt plus its HitTime) and when The Deluge surfaces near them
	  (SurfacedAt). The bar says whether The Deluge is under the floor or up (the fight's Mode).
	The boss's clips play through NPCAnimator (workspace.Monsters, Rig and Activity); the cracks,
	dust and rock bursts are the server's parts.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boss = require(Shared.Rules.Boss)
local Log = require(Shared.Utilities.Log)

local log = Log.new("BossController")
local player = Players.LocalPlayer

local BossController = {
	Name = "BossController",
	Dependencies = { "ReplicaController", "HUDController", "CameraController" },
}

local replica: any = nil
local hud: any = nil
local camera: any = nil
local lastState: string? = nil
local watched: { [Model]: RBXScriptConnection } = {}

local function myPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function bar(): any
	local gui = hud:Gui()
	return gui and gui:FindFirstChild("BossBar")
end

local function update()
	local f = replica:Get("Boss", "Fight")
	local b = bar()
	if not b then
		return
	end
	if type(f) ~= "table" then
		b.Visible = false
		lastState = nil
		return
	end
	b.Visible = true
	b:FindFirstChild("Name").Text = Boss.Title(f.Name or "Boss")
	local phase = b:FindFirstChild("Phase")
	if f.State == "Warning" or f.State == "Rising" then
		phase.Text = "BREAKING THROUGH"
	elseif f.State == "Dying" then
		phase.Text = "DEAD"
	else
		local where = if f.Mode == "Swim" or f.Mode == "Diving" then " · UNDER THE FLOOR" elseif f.Mode ~= nil then " · UP: HIT ITS HEAD" else ""
		phase.Text = `PHASE {f.Phase or 1} OF {f.Phases or 1}{where}`
	end
	local fill = b:FindFirstChild("Back") and b.Back:FindFirstChild("Fill")
	if fill then
		local fraction = if (f.Max or 0) > 0 then math.clamp((f.Health or 0) / f.Max, 0, 1) else 0
		fill.Size = UDim2.fromScale(fraction, 1)
	end
	if f.State == "Rising" and lastState ~= "Rising" then
		local me = myPosition()
		local at = if type(f.At) == "table" then Vector3.new(f.At.X, f.At.Y, f.At.Z) else nil
		local distance = if me and at then (me - at).Magnitude else math.huge
		camera:Shake(if distance < 80 then 2.5 else 1.2, if distance < 80 then 2.4 else 0.8)
	end
	lastState = f.State
end

-- A slam that lands near the player shakes the camera.
local function watch(model: Instance)
	if not model:IsA("Model") or model:GetAttribute("Boss") == nil or watched[model] then
		return
	end
	if model:FindFirstChildOfClass("Humanoid") == nil then
		return -- an egg sac
	end
	watched[model] = model:GetAttributeChangedSignal("AttackAt"):Connect(function()
		local hitTime = (model:GetAttribute("HitTime") :: number?) or 0.8
		task.delay(hitTime, function()
			local me = myPosition()
			if me and model.Parent and (me - model:GetPivot().Position).Magnitude < 32 then
				camera:Shake(0.5, 1.6)
			end
		end)
	end)
	-- The Deluge coming up out of the floor shakes it too.
	model:GetAttributeChangedSignal("SurfacedAt"):Connect(function()
		local me = myPosition()
		if me and model.Parent and (me - model:GetPivot().Position).Magnitude < 60 then
			camera:Shake(1.2, 1.4)
		end
	end)
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil and watched[model] then
			watched[model]:Disconnect()
			watched[model] = nil
		end
	end)
end

function BossController:Init(registry)
	replica = registry.ReplicaController
	hud = registry.HUDController
	camera = registry.CameraController
end

function BossController:Start()
	replica:Changed("Boss"):Connect(update)
	if replica:IsReady() then
		update()
	else
		replica:Ready():Connect(update)
	end
	task.spawn(function()
		local monsters = workspace:WaitForChild("Monsters", 120)
		if not monsters then
			return
		end
		for _, model in monsters:GetChildren() do
			watch(model)
		end
		monsters.ChildAdded:Connect(function(child: Instance)
			-- attributes arrive with the model; wait a frame for safety
			task.defer(watch, child)
		end)
	end)
	log:Debug("boss display ready")
end

return BossController
