-- UI builder (bible Section 18): Scale-only instances skinned with the UI kit atlases.
-- tools/ui_luau.py prepends this to a screen file and fills in the sprites it uses.
-- Layout only: no scripts go into a GUI. The game code (client Lib.KitRuntime) keeps 9-slice
-- corners and strokes in step with the screen height and runs the push-buttons, using the
-- attributes written here (Kit, Sprite, RectUp/RectDown/RectHover/RectDisabled,
-- BaseThickness, BaseScrollBar).
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
	night = Color3.fromHex("#0B121A"),
}
local CENTER = Enum.TextXAlignment.Center
local RIGHT = Enum.TextXAlignment.Right

local function skin(o: any, name: string, crop: { number }?)
	local s = SPR[name]
	assert(s, "no sprite " .. name)
	o.Image = s[1]
	o.BackgroundTransparency = 1
	if crop then -- {x, y, w, h} inside the sprite
		o.ImageRectOffset = Vector2.new(s[2] + crop[1], s[3] + crop[2])
		o.ImageRectSize = Vector2.new(crop[3], crop[4])
		o.ScaleType = Enum.ScaleType.Stretch
		o:SetAttribute("Crop", Vector2.new(crop[1], crop[2]))
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
	assert(s, "no sprite " .. name)
	return Vector2.new(s[2], s[3])
end

local function aspect(o: Instance, ratio: number, dom: string?)
	local c = Instance.new("UIAspectRatioConstraint")
	c.AspectRatio = ratio
	if dom == "H" then
		c.DominantAxis = Enum.DominantAxis.Height
	end
	c.Parent = o
	return c
end

local function new(class: string, parent: Instance, name: string, p: { [string]: any }): any
	local o = Instance.new(class)
	o.Name = name
	if o:IsA("GuiObject") then
		o.BackgroundTransparency = 1
		o.BorderSizePixel = 0
	end
	if o:IsA("ImageButton") or o:IsA("TextButton") then
		o.AutoButtonColor = false
	end
	if p.pos then o.Position = UDim2.fromScale(p.pos[1], p.pos[2]) end
	if p.size then o.Size = UDim2.fromScale(p.size[1], p.size[2]) end
	if p.anchor then o.AnchorPoint = Vector2.new(p.anchor[1], p.anchor[2]) end
	if p.z then o.ZIndex = p.z end
	if p.rot then o.Rotation = p.rot end
	if p.order then o.LayoutOrder = p.order end
	if p.visible == false then o.Visible = false end
	if p.sprite then skin(o, p.sprite, p.crop) end
	if p.tint then o.ImageColor3 = p.tint end
	if p.bg then
		o.BackgroundColor3 = p.bg
		o.BackgroundTransparency = p.bgT or 0
	end
	if p.aspect then aspect(o, p.aspect, p.dom) end
	if p.states then -- {up, down, hover?, disabled?}: Lib.KitRuntime swaps the atlas rect
		o:SetAttribute("RectUp", rectOf(p.states[1]))
		o:SetAttribute("RectDown", rectOf(p.states[2]))
		if p.states[3] then o:SetAttribute("RectHover", rectOf(p.states[3])) end
		if p.states[4] then o:SetAttribute("RectDisabled", rectOf(p.states[4])) end
	end
	if p.attrs then
		for k, v in p.attrs do
			o:SetAttribute(k, v)
		end
	end
	o.Parent = parent
	return o
end

local function text(parent: Instance, name: string, str: string, p: { [string]: any }): TextLabel
	local t = new(p.class or "TextLabel", parent, name, p)
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
	c.MinTextSize = 12 -- bible Section 18: never below 12 on phones
	c.MaxTextSize = p.max or 72
	c.Parent = t
	return t
end

-- A pixel stroke; Lib.KitRuntime scales BaseThickness (1080p pixels) to the screen height.
local function stroke(parent: Instance, thickness: number, color: Color3, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness * VH / 1080
	s.Transparency = transparency or 0
	s:SetAttribute("BaseThickness", thickness)
	s.Parent = parent
	return s
end

-- A push-button: the cap sprite with its pressed states and a Content frame that sinks.
local function button(parent: Instance, name: string, p: { [string]: any }, states: { string }): ImageButton
	p.sprite = states[1]
	p.states = states
	local b = new("ImageButton", parent, name, p)
	new("Frame", b, "Content", { pos = { 0, 0 }, size = { 1, 1 } })
	return b
end

local function list(parent: Instance, dir: string, padding: number, alignH: string?, alignV: string?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = if dir == "H" then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	l.Padding = UDim.new(padding, 0)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	if alignH then l.HorizontalAlignment = Enum.HorizontalAlignment[alignH] end
	if alignV then l.VerticalAlignment = Enum.VerticalAlignment[alignV] end
	l.Parent = parent
	return l
end

local function scroller(parent: Instance, name: string, p: { [string]: any }): ScrollingFrame
	local s = new("ScrollingFrame", parent, name, p)
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.fromScale(0, 0)
	s.ScrollBarThickness = math.max(2, math.round(6 * VH / 1080))
	s.ScrollBarImageColor3 = COL.cream
	s.ScrollBarImageTransparency = 0.25
	s.BorderSizePixel = 0
	s:SetAttribute("BaseScrollBar", 6)
	return s
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- A ScreenGui per bible Section 18, rule 7: safe insets, kept across respawns, sibling order.
local function screen(name: string, order: number): ScreenGui
	local old = game:GetService("StarterGui"):FindFirstChild(name)
	if old then old:Destroy() end
	local sg = Instance.new("ScreenGui")
	sg.Name = name
	sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	sg.DisplayOrder = order
	sg:SetAttribute("Kit", true)
	return sg
end
