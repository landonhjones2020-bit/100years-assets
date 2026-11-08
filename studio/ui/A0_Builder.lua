-- A0 UI builder (bible Section 18): Scale-only instances skinned with the UI kit atlases.
-- tools/ui_luau.py prepends this to a screen file and fills in the sprites it uses.
local SPR: { [string]: { any } } = {--@SPRITES@
}
local VH = workspace.CurrentCamera.ViewportSize.Y
local SLICE = 0.5 * VH / 1080 -- sprites are drawn at 2x their 1080p size

local F = {
	title = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold),
	label = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Medium),
	typed = Font.new("rbxasset://fonts/families/SpecialElite.json"),
	num = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Bold),
	body = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Regular),
}
local COL = {
	navy = Color3.fromHex("#1B2A3A"), cream = Color3.fromHex("#F2E6C9"), teal = Color3.fromHex("#2F6F73"),
	signal = Color3.fromHex("#E8743B"), hazard = Color3.fromHex("#F2C14E"), rust = Color3.fromHex("#B5412B"),
	glow = Color3.fromHex("#7CFF9B"), leaf = Color3.fromHex("#6F9B4C"), ink = Color3.fromHex("#2A3B4C"),
}

local function skin(o: any, name: string, crop: { number }?)
	local s = SPR[name]
	assert(s, "no sprite " .. name)
	o.Image = s[1]
	o.BackgroundTransparency = 1
	if crop then -- {x, y, w, h} inside the sprite
		o.ImageRectOffset = Vector2.new(s[2] + crop[1], s[3] + crop[2])
		o.ImageRectSize = Vector2.new(crop[3], crop[4])
		o.ScaleType = Enum.ScaleType.Stretch
	else
		o.ImageRectOffset = Vector2.new(s[2], s[3])
		o.ImageRectSize = Vector2.new(s[4], s[5])
		if s[6] then
			o.ScaleType = Enum.ScaleType.Slice
			o.SliceCenter = Rect.new(s[6], s[7], s[4] - s[8], s[5] - s[9])
			o.SliceScale = SLICE
		else
			o.ScaleType = Enum.ScaleType.Stretch
		end
	end
	o:SetAttribute("Sprite", name)
end

local function rectOf(name: string): Vector2
	local s = SPR[name]
	return Vector2.new(s[2], s[3])
end

local function new(class: string, parent: Instance, name: string, p: { [string]: any }): any
	local o = Instance.new(class)
	o.Name = name
	if o:IsA("GuiObject") then
		o.BackgroundTransparency = 1
		o.BorderSizePixel = 0
	end
	if o:IsA("ImageButton") then
		o.AutoButtonColor = false
	end
	if p.pos then o.Position = UDim2.fromScale(p.pos[1], p.pos[2]) end
	if p.size then o.Size = UDim2.fromScale(p.size[1], p.size[2]) end
	if p.anchor then o.AnchorPoint = Vector2.new(p.anchor[1], p.anchor[2]) end
	if p.z then o.ZIndex = p.z end
	if p.rot then o.Rotation = p.rot end
	if p.sprite then skin(o, p.sprite, p.crop) end
	if p.tint then o.ImageColor3 = p.tint end
	if p.bg then
		o.BackgroundColor3 = p.bg
		o.BackgroundTransparency = p.bgT or 0
	end
	if p.aspect then
		local c = Instance.new("UIAspectRatioConstraint")
		c.AspectRatio = p.aspect
		if p.dom == "H" then c.DominantAxis = Enum.DominantAxis.Height end
		c.Parent = o
	end
	if p.states then -- {up, down, hover?}: KitButtons swaps the atlas rect
		o:SetAttribute("RectUp", rectOf(p.states[1]))
		o:SetAttribute("RectDown", rectOf(p.states[2]))
		if p.states[3] then o:SetAttribute("RectHover", rectOf(p.states[3])) end
	end
	o.Parent = parent
	return o
end

local function text(parent: Instance, name: string, str: string, p: { [string]: any }): TextLabel
	local t = new("TextLabel", parent, name, p)
	t.Text = str
	t.FontFace = p.font or F.body
	t.TextColor3 = p.color or COL.navy
	-- TextWrapped is linked to TextScaled: setting it false afterwards turns scaling off again
	t.TextWrapped = p.wrap or false
	t.TextScaled = true
	t.TextXAlignment = p.alignX or Enum.TextXAlignment.Left
	t.TextYAlignment = p.alignY or Enum.TextYAlignment.Center
	t.LineHeight = p.lineHeight or 1
	if p.transp then t.TextTransparency = p.transp end
	local c = Instance.new("UITextSizeConstraint")
	c.MinTextSize = 12
	c.MaxTextSize = p.max or 72
	c.Parent = t
	return t
end

local CENTER = Enum.TextXAlignment.Center
local RIGHT = Enum.TextXAlignment.Right

local SLICE_SCALER = [[
-- Keeps 9-slice corners the same size relative to the screen: kit sprites are drawn at 2x
-- their 1080p size (bible Section 18; the StrokeScaler does the same for UIStroke).
local gui = script.Parent
local cam = workspace.CurrentCamera
local function apply()
	local k = 0.5 * cam.ViewportSize.Y / 1080
	for _, o in gui:GetDescendants() do
		if (o:IsA("ImageLabel") or o:IsA("ImageButton")) and o.ScaleType == Enum.ScaleType.Slice then
			o.SliceScale = k * (o:GetAttribute("SliceMul") or 1)
		end
	end
end
cam:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
apply()
]]

local KIT_BUTTONS = [[
-- Mechanical push-buttons: swap the atlas rect for the pressed and hover sprites and push the
-- button's Content down while it is held (RectUp/RectDown/RectHover attributes).
local gui = script.Parent
local function hook(b: ImageButton)
	local up, down, hover = b:GetAttribute("RectUp"), b:GetAttribute("RectDown"), b:GetAttribute("RectHover")
	if not (up and down) then return end
	local content = b:FindFirstChild("Content")
	local home = content and content.Position
	local function set(r, pressed)
		b.ImageRectOffset = r
		if content then
			content.Position = if pressed then home + UDim2.fromScale(0, 0.06) else home
		end
	end
	b.MouseButton1Down:Connect(function() set(down, true) end)
	b.MouseButton1Up:Connect(function() set(hover or up, false) end)
	b.MouseEnter:Connect(function() set(hover or up, false) end)
	b.MouseLeave:Connect(function() set(up, false) end)
end
for _, o in gui:GetDescendants() do
	if o:IsA("ImageButton") then hook(o) end
end
]]

local function screen(name: string): ScreenGui
	local old = game:GetService("StarterGui"):FindFirstChild(name)
	if old then old:Destroy() end
	local sg = Instance.new("ScreenGui")
	sg.Name = name
	sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	for n, src in { SliceScaler = SLICE_SCALER, KitButtons = KIT_BUTTONS } do
		local s = Instance.new("LocalScript")
		s.Name = n
		s.Source = src
		s.Parent = sg
	end
	return sg
end
