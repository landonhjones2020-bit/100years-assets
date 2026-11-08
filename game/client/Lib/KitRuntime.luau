--!strict
--[[
	Lib.KitRuntime: keeps the UI kit right on every screen (bible Section 18).

	* 9-slice corners: kit sprites are drawn at twice their 1080p size, so a sliced image's
	  SliceScale is 0.5 x height / 1080 (times its SliceMul attribute, if any).
	* Strokes and scroll bars are pixels, so their 1080p sizes (BaseThickness, BaseScrollBar
	  attributes) follow the screen height too: the StrokeScaler of the AutoScale Lite rules.
	* Push-buttons: the builder writes RectUp, RectDown and optionally RectHover and
	  RectDisabled. The pressed sprite shows while the button is held, and its Content frame
	  sinks a little, like a real cap.

	Watch(gui) does all of this for a ScreenGui now, for anything cloned into it later, and
	again whenever its size changes. SetSprite points an image at a kit sprite and keeps a
	builder's crop. SetEnabled greys a button out.
]]

local UIKit = require(script.Parent.UIKit)

local KitRuntime = {}

local SINK = 0.06 -- how far a pressed button's Content moves down (of its height)

local hooked: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function heightOf(gui: Instance): number
	local h = 0
	if gui:IsA("LayerCollector") then
		local layer: any = gui
		h = layer.AbsoluteSize.Y
	end
	if h <= 0 then
		local camera = workspace.CurrentCamera
		h = if camera then camera.ViewportSize.Y else 1080
	end
	return math.max(h, 1)
end

local function scaleOne(o: Instance, k: number)
	local item: any = o
	if (o:IsA("ImageLabel") or o:IsA("ImageButton")) and item.ScaleType == Enum.ScaleType.Slice then
		local mul = o:GetAttribute("SliceMul")
		item.SliceScale = 0.5 * k * (if type(mul) == "number" then mul else 1)
	elseif o:IsA("UIStroke") then
		local base = o:GetAttribute("BaseThickness")
		if type(base) == "number" then
			item.Thickness = base * k
		end
	elseif o:IsA("ScrollingFrame") then
		local base = o:GetAttribute("BaseScrollBar")
		if type(base) == "number" then
			item.ScrollBarThickness = math.max(2, math.round(base * k))
		end
	end
end

local function rect(button: Instance, state: string): Vector2?
	local value = button:GetAttribute("Rect" .. state)
	return if typeof(value) == "Vector2" then value else nil
end

local function show(button: ImageButton, state: string)
	local r = rect(button, state) or rect(button, "Up")
	if r then
		button.ImageRectOffset = r
	end
	local content = button:FindFirstChild("Content")
	if content and content:IsA("GuiObject") then
		local home = content:GetAttribute("Home")
		if typeof(home) ~= "UDim2" then
			home = content.Position
			content:SetAttribute("Home", home)
		end
		local rest: UDim2 = home :: any
		content.Position = if state == "Down" then rest + UDim2.fromScale(0, SINK) else rest
	end
end

local function hook(button: ImageButton)
	if hooked[button] or not rect(button, "Up") or not rect(button, "Down") then
		return
	end
	hooked[button] = true
	local over = false
	local function settle()
		if button:GetAttribute("Disabled") == true then
			show(button, "Disabled")
		else
			show(button, if over and rect(button, "Hover") then "Hover" else "Up")
		end
	end
	button.MouseButton1Down:Connect(function()
		if button:GetAttribute("Disabled") ~= true then
			show(button, "Down")
		end
	end)
	button.MouseButton1Up:Connect(settle)
	button.MouseEnter:Connect(function()
		over = true
		settle()
	end)
	button.MouseLeave:Connect(function()
		over = false
		settle()
	end)
	button:GetAttributeChangedSignal("Disabled"):Connect(settle)
	settle()
end

-- Applies the kit's runtime rules to a ScreenGui. Returns a function that stops watching.
function KitRuntime.Watch(gui: Instance): () -> ()
	local function factor(): number
		return heightOf(gui) / 1080
	end
	local function applyAll()
		local k = factor()
		for _, o in gui:GetDescendants() do
			scaleOne(o, k)
		end
	end
	for _, o in gui:GetDescendants() do
		if o:IsA("ImageButton") then
			hook(o)
		end
	end
	applyAll()
	local connections = {
		gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyAll),
		gui.DescendantAdded:Connect(function(o: Instance)
			scaleOne(o, factor())
			if o:IsA("ImageButton") then
				hook(o)
			end
		end),
	}
	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end
end

-- Points an image at a kit sprite. An image the builder cropped (a card's rarity tag, say)
-- keeps its crop inside the new sprite.
function KitRuntime.SetSprite(image: ImageLabel | ImageButton, name: string)
	local sprite = UIKit.Sprites[name]
	assert(sprite, `KitRuntime: no sprite {name}`)
	local item: any = image
	item.Image = sprite.image
	local crop = image:GetAttribute("Crop")
	if typeof(crop) == "Vector2" then
		item.ImageRectOffset = sprite.offset + crop
	else
		item.ImageRectOffset = sprite.offset
		item.ImageRectSize = sprite.size
		if sprite.slice then
			item.ScaleType = Enum.ScaleType.Slice
			item.SliceCenter = sprite.slice
		else
			item.ScaleType = Enum.ScaleType.Stretch
		end
	end
	image:SetAttribute("Sprite", name)
	local gui = image:FindFirstAncestorWhichIsA("LayerCollector")
	scaleOne(image, heightOf(gui or image) / 1080)
end

-- Greys a push-button out (its Disabled sprite when it has one) or brings it back.
function KitRuntime.SetEnabled(button: ImageButton, on: boolean)
	button:SetAttribute("Disabled", if on then nil else true)
	if not hooked[button] then
		show(button, if on then "Up" else "Disabled")
	end
end

function KitRuntime.IsEnabled(button: Instance): boolean
	return button:GetAttribute("Disabled") ~= true
end

return KitRuntime
