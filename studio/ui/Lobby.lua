-- The lobby's own GUI (Prompt 21; bible Sections 14, 18 and 21), Lobby place. Below The Frame
-- (DisplayOrder 4): the Class Shop and Loadout screens are Frame pages; this is what stays on
-- screen while a player walks the showroom. LobbyController and PadController fill it.
--
-- * Class: the equipped class (portrait or icon, name, level), top left, with the CLASS SHOP and
--   LOADOUT buttons under it.
-- * Wallet: Glowshards, top right.
-- * Alert: the lobby's messages (a purchase, a refusal, an invitation), top centre.
-- * Pad: the panel of the pad the player stands on: its title, its countdown, up to six riders,
--   and the buttons the rider can use (LOADOUT, DIFFICULTY, INVITE, START). The camera holds the
--   mouse, as in a run, so every button carries its key (a chip the controllers fill per device).
-- * Invite: a private pad's guest list (players in this lobby) and INVITE FRIENDS.
-- * Rejoin: "Rejoin your run".
-- * Templates.PadSign: the sign on each pad's board (a SurfaceGui). Templates.Prompt: the booths' prompts.
local sg = screen("Lobby", 4)

-- the equipped class
local class = new("ImageButton", sg, "Class", { pos = { 0.012, 0.022 }, size = { 0.2, 0.09 }, aspect = 4.3, sprite = "Plate_Cream" })
local well = new("ImageLabel", class, "Well", { pos = { 0.035, 0.5 }, anchor = { 0, 0.5 }, size = { 1, 0.78 }, aspect = 1, dom = "H",
	sprite = "Well_Teal", z = 2 })
new("ImageLabel", well, "Icon", { pos = { 0.5, 0.5 }, anchor = { 0.5, 0.5 }, size = { 0.86, 0.86 }, sprite = "Icon_Wrench", z = 3 })
text(class, "Name", "SURVIVOR", { pos = { 0.25, 0.14 }, size = { 0.7, 0.44 }, font = F.title, color = COL.navy, z = 2 })
text(class, "Sub", "LEVEL 1  ·  EQUIPPED", { pos = { 0.25, 0.58 }, size = { 0.7, 0.26 }, font = F.typed, color = COL.ink, z = 2 })

local buttons = new("Frame", sg, "Buttons", { pos = { 0.012, 0.122 }, size = { 0.2, 0.05 }, aspect = 7.7 })
for i, v in { { "Shop", "CLASS SHOP", "K" }, { "Loadout", "LOADOUT", "L" } } do
	local b = button(buttons, v[1], { pos = { (i - 1) * 0.51, 0 }, size = { 0.49, 1 } }, { "Button_Teal_Up", "Button_Teal_Down" })
	text(b.Content, "Label", v[2], { pos = { 0.1, 0.22 }, size = { 0.6, 0.56 }, font = F.title, color = COL.cream })
	local key = new("ImageLabel", b.Content, "Key", { pos = { 0.83, 0.5 }, anchor = { 0.5, 0.5 }, size = { 1, 0.56 }, aspect = 1.55,
		dom = "H", sprite = "Chip_Cream", z = 2 })
	text(key, "Text", v[3], { pos = { 0.1, 0.12 }, size = { 0.8, 0.76 }, font = F.num, color = COL.navy, alignX = CENTER, z = 3 })
end

-- Glowshards
local wallet = new("ImageLabel", sg, "Wallet", { pos = { 0.988, 0.022 }, anchor = { 1, 0 }, size = { 0.115, 0.05 }, aspect = 3.6,
	sprite = "Chip_Navy" })
new("ImageLabel", wallet, "Icon", { pos = { 0.06, 0.5 }, anchor = { 0, 0.5 }, size = { 1, 0.74 }, aspect = 1, dom = "H",
	sprite = "Icon_Glowshard", z = 2 })
text(wallet, "Amount", "0", { pos = { 0.32, 0.16 }, size = { 0.6, 0.68 }, font = F.num, color = COL.cream, alignX = RIGHT, z = 2 })

-- messages
local alert = new("ImageLabel", sg, "Alert", { pos = { 0.5, 0.022 }, anchor = { 0.5, 0 }, size = { 0.4, 0.062 }, aspect = 11.5,
	sprite = "Telegram", visible = false })
new("ImageLabel", alert, "Lamp", { pos = { 0.03, 0.5 }, anchor = { 0, 0.5 }, size = { 1, 0.5 }, aspect = 1, dom = "H",
	sprite = "Lamp_Amber", z = 2 })
text(alert, "Text", "", { pos = { 0.085, 0.2 }, size = { 0.88, 0.6 }, font = F.typed, color = COL.navy, z = 2 })

-- the pad the player stands on
local pad = new("ImageLabel", sg, "Pad", { pos = { 0.5, 0.1 }, anchor = { 0.5, 0 }, size = { 0.4, 0.2 }, aspect = 3.55,
	sprite = "Panel_Navy", visible = false })
text(pad, "Title", "PUBLIC · NORMAL", { pos = { 0.04, 0.07 }, size = { 0.56, 0.18 }, font = F.title, color = COL.cream })
text(pad, "Timer", "", { pos = { 0.6, 0.07 }, size = { 0.36, 0.18 }, font = F.num, color = COL.hazard, alignX = RIGHT })
local riders = new("Frame", pad, "Riders", { pos = { 0.04, 0.29 }, size = { 0.92, 0.38 } })
for i = 1, 6 do
	local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
	local slot = new("ImageLabel", riders, "Slot" .. i, { pos = { col * 0.337, row * 0.52 }, size = { 0.325, 0.46 }, sprite = "Chip_Cream" })
	new("ImageLabel", slot, "Lamp", { pos = { 0.05, 0.5 }, anchor = { 0, 0.5 }, size = { 1, 0.6 }, aspect = 1, dom = "H",
		sprite = "Lamp_Off", z = 2 })
	text(slot, "Name", "", { pos = { 0.2, 0.1 }, size = { 0.76, 0.46 }, font = F.label, color = COL.navy, z = 2 })
	text(slot, "Class", "", { pos = { 0.2, 0.54 }, size = { 0.76, 0.36 }, font = F.typed, color = COL.ink, z = 2 })
end
local padButtons = new("Frame", pad, "Buttons", { pos = { 0.04, 0.72 }, size = { 0.92, 0.22 } })
for i, v in {
	{ "Loadout", "LOADOUT", "L", "Button_Teal_Up", "Button_Teal_Down" },
	{ "Difficulty", "DIFFICULTY", "H", "Button_Signal_Up", "Button_Signal_Down" },
	{ "Invite", "INVITE", "G", "Button_Teal_Up", "Button_Teal_Down" },
	{ "Start", "START", "Y", "Button_Leaf_Up", "Button_Leaf_Down" },
} do
	local b = button(padButtons, v[1], { pos = { (i - 1) * 0.2525, 0 }, size = { 0.2425, 1 } }, { v[4], v[5] })
	text(b.Content, "Label", v[2], { pos = { 0.07, 0.24 }, size = { 0.6, 0.52 }, font = F.title, color = COL.cream })
	local key = new("ImageLabel", b.Content, "Key", { pos = { 0.82, 0.5 }, anchor = { 0.5, 0.5 }, size = { 1, 0.58 }, aspect = 1.55,
		dom = "H", sprite = "Chip_Cream", z = 2 })
	text(key, "Text", v[3], { pos = { 0.08, 0.12 }, size = { 0.84, 0.76 }, font = F.num, color = COL.navy, alignX = CENTER, z = 3 })
end

-- a private pad's guest list
local invite = new("ImageLabel", sg, "Invite", { pos = { 0.5, 0.32 }, anchor = { 0.5, 0 }, size = { 0.3, 0.5 }, aspect = 1.07,
	sprite = "Panel_Cream", visible = false })
text(invite, "Title", "INVITE TO YOUR PAD", { pos = { 0.06, 0.04 }, size = { 0.7, 0.08 }, font = F.title, color = COL.navy })
local closeInvite = button(invite, "Close", { pos = { 0.94, 0.08 }, anchor = { 0.5, 0.5 }, size = { 0.09, 0.09 }, aspect = 1 },
	{ "Close_Up", "Close_Down" })
closeInvite.ZIndex = 3
text(invite, "Empty", "NOBODY ELSE IS IN THIS LOBBY", { pos = { 0.06, 0.2 }, size = { 0.88, 0.08 }, font = F.typed, color = COL.ink,
	alignX = CENTER, visible = false })
local rows = new("Frame", invite, "Rows", { pos = { 0.06, 0.15 }, size = { 0.88, 0.66 } })
for i = 1, 8 do
	local row = new("ImageButton", rows, "Row" .. i, { pos = { 0, (i - 1) * 0.125 }, size = { 1, 0.113 }, sprite = "Chip_Navy", visible = false })
	new("ImageLabel", row, "Lamp", { pos = { 0.03, 0.5 }, anchor = { 0, 0.5 }, size = { 1, 0.6 }, aspect = 1, dom = "H",
		sprite = "Lamp_Off", z = 2 })
	text(row, "Name", "", { pos = { 0.12, 0.18 }, size = { 0.6, 0.64 }, font = F.label, color = COL.cream, z = 2 })
	text(row, "State", "INVITE", { pos = { 0.72, 0.22 }, size = { 0.25, 0.56 }, font = F.num, color = COL.hazard, alignX = RIGHT, z = 2 })
end
local friends = button(invite, "Friends", { pos = { 0.06, 0.84 }, size = { 0.88, 0.11 } }, { "Button_Teal_Up", "Button_Teal_Down" })
text(friends.Content, "Label", "INVITE ROBLOX FRIENDS TO THIS LOBBY", { pos = { 0.06, 0.24 }, size = { 0.88, 0.52 }, font = F.title,
	color = COL.cream, alignX = CENTER })

-- "Rejoin your run"
local rejoin = new("ImageLabel", sg, "Rejoin", { pos = { 0.5, 0.74 }, anchor = { 0.5, 0 }, size = { 0.44, 0.12 }, aspect = 7,
	sprite = "Telegram", visible = false })
text(rejoin, "Title", "REJOIN YOUR RUN", { pos = { 0.04, 0.2 }, size = { 0.46, 0.34 }, font = F.title, color = COL.navy })
text(rejoin, "Sub", "NORMAL  ·  YOUR CREW IS HOLDING THE BUNKER", { pos = { 0.04, 0.56 }, size = { 0.48, 0.24 }, font = F.typed, color = COL.ink })
for _, v in { { "Yes", "REJOIN", "R", 0.54, 0.21, "Button_Leaf_Up", "Button_Leaf_Down" }, { "No", "NOT NOW", "N", 0.765, 0.205, "Button_Rust_Up", "Button_Rust_Down" } } do
	local b = button(rejoin, v[1], { pos = { v[4], 0.22 }, size = { v[5], 0.56 } }, { v[6], v[7] })
	text(b.Content, "Label", v[2], { pos = { 0.08, 0.24 }, size = { 0.58, 0.52 }, font = F.title, color = COL.cream })
	local key = new("ImageLabel", b.Content, "Key", { pos = { 0.82, 0.5 }, anchor = { 0.5, 0.5 }, size = { 1, 0.58 }, aspect = 1.3,
		dom = "H", sprite = "Chip_Cream", z = 2 })
	text(key, "Text", v[3], { pos = { 0.08, 0.12 }, size = { 0.84, 0.76 }, font = F.num, color = COL.navy, alignX = CENTER, z = 3 })
end

local T = folder(sg, "Templates")

-- The sign over a pad: a SurfaceGui on the front of the pad's Sign part (12 by 4.4 studs).
local sign = new("SurfaceGui", T, "PadSign", {})
sign.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
sign.PixelsPerStud = 40
sign.Face = Enum.NormalId.Front
sign.MaxDistance = 260
sign.LightInfluence = 0
sign.Brightness = 1.2
sign.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sign.ResetOnSpawn = false
sign.Enabled = false
local board = new("ImageLabel", sign, "Board", { pos = { 0, 0 }, size = { 1, 1 }, sprite = "Panel_Navy" })
text(board, "Kind", "PUBLIC", { pos = { 0.06, 0.08 }, size = { 0.6, 0.3 }, font = F.title, color = COL.cream, z = 2 })
text(board, "Count", "0/6", { pos = { 0.66, 0.08 }, size = { 0.28, 0.3 }, font = F.num, color = COL.cream, alignX = RIGHT, z = 2 })
local band = new("Frame", board, "Band", { pos = { 0.06, 0.42 }, size = { 0.88, 0.24 }, bg = COL.teal, z = 2 })
text(band, "Difficulty", "NORMAL", { pos = { 0.04, 0.1 }, size = { 0.92, 0.8 }, font = F.title, color = COL.cream, alignX = CENTER, z = 3 })
text(board, "Timer", "STEP ON TO START", { pos = { 0.06, 0.7 }, size = { 0.88, 0.22 }, font = F.typed, color = COL.hazard, alignX = CENTER, z = 2 })

-- The interaction prompt (the HUD's, for the showroom's booths).
local prompt = new("BillboardGui", T, "Prompt", {})
prompt.Size = UDim2.fromScale(5.6, 1.5)
prompt.StudsOffsetWorldSpace = Vector3.new(0, 1.2, 0)
prompt.AlwaysOnTop = true
prompt.LightInfluence = 0
prompt.ResetOnSpawn = false
prompt.Enabled = false
local plate = new("ImageButton", prompt, "Plate", { pos = { 0, 0 }, size = { 1, 1 }, sprite = "Plate_Cream" })
local key = new("ImageLabel", plate, "Key", { pos = { 0.12, 0.5 }, anchor = { 0.5, 0.5 }, size = { 0.17, 0.66 }, sprite = "Chip_Navy", z = 2 })
text(key, "Text", "E", { pos = { 0.5, 0.5 }, anchor = { 0.5, 0.5 }, size = { 0.7, 0.6 }, font = F.num, color = COL.cream, alignX = CENTER,
	z = 3 })
text(plate, "Action", "CLASS SHOP", { pos = { 0.25, 0.14 }, size = { 0.7, 0.42 }, font = F.title, color = COL.navy, z = 2 })
text(plate, "Object", "Steadfast showroom", { pos = { 0.25, 0.56 }, size = { 0.7, 0.28 }, font = F.typed, color = COL.ink, z = 2 })

sg.Parent = game:GetService("StarterGui")
return "Lobby GUI built: " .. #sg:GetDescendants() .. " instances"
