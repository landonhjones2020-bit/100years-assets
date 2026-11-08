-- Reticle: the aim sight in the screen's centre (Prompt 5, bible Section 9). Run in Edit with
-- execute_luau in both places; it replaces StarterGui.Reticle. Scale-only with aspect
-- constraints, ready for the AutoScale Lite pass. CameraController only switches it on and
-- off and shows Hip or Aim; nothing here is laid out by code at run time.
--
-- ScreenInsets None and IgnoreGuiInset: the sight must sit on the viewport's true centre,
-- where the camera aims, so it doesn't use the CoreUISafeInsets of menu screens (rule 7).

local StarterGui = game:GetService("StarterGui")
local CREAM = Color3.fromHex("F2E6C9")
local NAVY = Color3.fromHex("1B2A3A")

local old = StarterGui:FindFirstChild("Reticle")
if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "Reticle"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None
gui.DisplayOrder = 2
gui.Enabled = false

local sight = Instance.new("Frame")
sight.Name = "Sight"
sight.AnchorPoint = Vector2.new(0.5, 0.5)
sight.Position = UDim2.fromScale(0.5, 0.5)
sight.Size = UDim2.fromScale(0.07, 0.07)
sight.BackgroundTransparency = 1
sight.Parent = gui
local square = Instance.new("UIAspectRatioConstraint")
square.AspectRatio = 1
square.Parent = sight

local function piece(parent: Instance, name: string, anchor: Vector2, position: UDim2, size: UDim2, round: boolean)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = anchor
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = CREAM
	frame.BorderSizePixel = 0
	local stroke = Instance.new("UIStroke")
	stroke.Color = NAVY
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = frame
		local keep = Instance.new("UIAspectRatioConstraint")
		keep.AspectRatio = 1
		keep.Parent = frame
	end
	frame.Parent = parent
	return frame
end

piece(sight, "Dot", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.08, 0.08), true)

-- Four ticks around the centre: gap and length are fractions of the sight.
local function ticks(name: string, gap: number, length: number, thickness: number, visible: boolean)
	local group = Instance.new("Frame")
	group.Name = name
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.Visible = visible
	group.Parent = sight
	local near, far = 0.5 - gap, 0.5 + gap
	piece(group, "Top", Vector2.new(0.5, 1), UDim2.fromScale(0.5, near), UDim2.fromScale(thickness, length), false)
	piece(group, "Bottom", Vector2.new(0.5, 0), UDim2.fromScale(0.5, far), UDim2.fromScale(thickness, length), false)
	piece(group, "Left", Vector2.new(1, 0.5), UDim2.fromScale(near, 0.5), UDim2.fromScale(length, thickness), false)
	piece(group, "Right", Vector2.new(0, 0.5), UDim2.fromScale(far, 0.5), UDim2.fromScale(length, thickness), false)
end
ticks("Hip", 0.15, 0.2, 0.055, true) -- walking: an open sight
ticks("Aim", 0.08, 0.15, 0.045, false) -- aiming: tight around the dot

gui.Parent = StarterGui
return "StarterGui.Reticle built"
