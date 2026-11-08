-- In-place patch (Prompt 8): the vote telegram moves from the HUD into its own ScreenGui,
-- StarterGui.Votes (DisplayOrder 6, above The Frame), so it stays up while a Frame screen hides
-- the HUD. The banner moves as it is (keeping any AutoScale Lite pass) and gains its timer strip.
local StarterGui = game:GetService("StarterGui")
local hud = StarterGui:WaitForChild("HUD")
local sg = StarterGui:FindFirstChild("Votes")
if not sg then
	sg = Instance.new("ScreenGui")
	sg.Name = "Votes"
	sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	sg.IgnoreGuiInset = hud.IgnoreGuiInset
	sg.DisplayOrder = 6
	sg:SetAttribute("Kit", true)
	sg.Parent = StarterGui
end
local vote = hud:FindFirstChild("VoteBanner") or sg:FindFirstChild("VoteBanner")
assert(vote, "no VoteBanner in the HUD or the Votes ScreenGui")
vote.Parent = sg
if not vote:FindFirstChild("Timer") then
	local timer = Instance.new("Frame")
	timer.Name = "Timer"
	timer.Position = UDim2.fromScale(0.045, 0.86)
	timer.Size = UDim2.fromScale(0.58, 0.05)
	timer.BackgroundColor3 = Color3.fromHex("#1B2A3A")
	timer.BackgroundTransparency = 0.8
	timer.BorderSizePixel = 0
	timer.Parent = vote
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Position = UDim2.fromScale(0, 0)
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromHex("#E8743B")
	fill.BackgroundTransparency = 0
	fill.BorderSizePixel = 0
	fill.Parent = timer
end
return "Votes ScreenGui ready: " .. #sg:GetDescendants() .. " instances; HUD has VoteBanner: " .. tostring(hud:FindFirstChild("VoteBanner") ~= nil)
