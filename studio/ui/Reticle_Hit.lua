-- The reticle's hit markers (Prompt 11, bible Section 9): four short diagonal ticks around the
-- dot when a shot hits a monster (Hit, cream) and longer ones when it kills (Kill, signal
-- orange). Included by Reticle.lua and patches/Reticle_P11.lua; needs `sight`.
local CREAM_ = Color3.fromHex("F2E6C9")
local NAVY_ = Color3.fromHex("1B2A3A")
local SIGNAL_ = Color3.fromHex("E8743B")
local function marker(name: string, gap: number, length: number, thickness: number, color: Color3)
	local group = Instance.new("Frame")
	group.Name = name
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.Visible = false
	group.Parent = sight
	for i, corner in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
		local tick = Instance.new("Frame")
		tick.Name = "Tick" .. i
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		local d = gap + length / 2
		tick.Position = UDim2.fromScale(0.5 + corner[1] * d * 0.7071, 0.5 + corner[2] * d * 0.7071)
		tick.Size = UDim2.fromScale(length, thickness)
		tick.Rotation = if corner[1] == corner[2] then 45 else -45
		tick.BackgroundColor3 = color
		tick.BorderSizePixel = 0
		local stroke = Instance.new("UIStroke")
		stroke.Color = NAVY_
		stroke.Thickness = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = tick
		tick.Parent = group
	end
end
marker("Hit", 0.14, 0.2, 0.05, CREAM_)
marker("Kill", 0.16, 0.3, 0.065, SIGNAL_)
