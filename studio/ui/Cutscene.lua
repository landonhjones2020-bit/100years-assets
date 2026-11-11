-- The intro cutscene's screen furniture (bible Section 4: "Letterbox bars, the HUD hidden, a small
-- Skip button bottom right"; "a radio bulletin scrolls across the screen"; the title card and
-- "Survive. Dig. Don't wake it."), Run place. CutsceneController drives it.
--
-- Two ScreenGuis above everything else. CutsceneBars covers the whole screen (no insets, so the
-- black reaches every edge on a notched phone): the dust, the flash, the black, the two bars and
-- the radio bulletin that runs along the lower one. Cutscene keeps to the safe area: the title
-- card, Skip, and the plate that counts down to the run for a player who skipped.
local bars = screen("CutsceneBars", 20)
bars.ScreenInsets = Enum.ScreenInsets.None
bars.Enabled = false
new("Frame", bars, "Dust", { pos = { 0, 0 }, size = { 1, 1 }, bg = Color3.fromHex("#8A6648"), bgT = 1, z = 1 })
new("Frame", bars, "Flash", { pos = { 0, 0 }, size = { 1, 1 }, bg = Color3.fromHex("#FFF6E4"), bgT = 1, z = 2 })
new("Frame", bars, "Black", { pos = { 0, 0 }, size = { 1, 1 }, bg = Color3.new(0, 0, 0), bgT = 1, z = 3 })
new("Frame", bars, "Top", { pos = { 0, 0 }, anchor = { 0, 1 }, size = { 1, 0.11 }, bg = Color3.new(0, 0, 0), bgT = 0, z = 4 })
local bottom = new("Frame", bars, "Bottom", { pos = { 0, 1 }, anchor = { 0, 0 }, size = { 1, 0.11 }, bg = Color3.new(0, 0, 0), bgT = 0, z = 4 })

-- the bulletin: the station's plate with its lamp, and the teletype line running past it
local bulletin = new("Frame", bottom, "Bulletin", { pos = { 0, 0 }, size = { 1, 1 }, visible = false, z = 5 })
local ticker = new("Frame", bulletin, "Ticker", { pos = { 0.262, 0.14 }, size = { 0.6, 0.72 }, clip = true, z = 5 })
text(ticker, "Line", "", { pos = { 1, 0.5 }, anchor = { 0, 0.5 }, size = { 4, 0.62 }, font = F.typed, color = COL.cream, max = 160, z = 5 })
local plate = new("ImageLabel", bulletin, "Plate", { pos = { 0.04, 0.5 }, anchor = { 0, 0.5 }, size = { 0.21, 0.8 }, aspect = 4.6, dom = "H",
	sprite = "Plate_Cream", z = 6 })
new("ImageLabel", plate, "LampOff", { pos = { 0.075, 0.5 }, anchor = { 0, 0.5 }, size = { 0.12, 0.5 }, aspect = 1, dom = "H", sprite = "Lamp_Off", z = 7 })
new("ImageLabel", plate, "LampOn", { pos = { 0.075, 0.5 }, anchor = { 0, 0.5 }, size = { 0.12, 0.5 }, aspect = 1, dom = "H", sprite = "Lamp_Red", z = 8 })
text(plate, "Station", "BRIGHTWATER RADIO", { pos = { 0.215, 0.16 }, size = { 0.72, 0.36 }, font = F.title, color = COL.navy, z = 7, max = 120 })
text(plate, "Tag", "EMERGENCY BULLETIN", { pos = { 0.215, 0.52 }, size = { 0.72, 0.3 }, font = F.label, color = COL.rust, z = 7, max = 120 })

local sg = screen("Cutscene", 21)
sg.Enabled = false
-- the title card
-- the title card: "100 YEARS" as a Steadfast marquee, BELOW under it with the Source's green rising
-- through it, and the line typed out beneath
local title = new("Frame", sg, "Title", { pos = { 0.5, 0.46 }, anchor = { 0.5, 0.5 }, size = { 0.5, 0.62 }, aspect = 1.52, visible = false })
new("ImageLabel", title, "Years", { pos = { 0.5, 0 }, anchor = { 0.5, 0 }, size = { 0.86, 0.3 }, aspect = 1016 / 236, sprite = "Title_Years" })
new("ImageLabel", title, "Below", { pos = { 0.5, 0.32 }, anchor = { 0.5, 0 }, size = { 1, 0.5 }, aspect = 1016 / 336, sprite = "Title_Below" })
text(title, "Tagline", "", { pos = { 0.5, 0.93 }, anchor = { 0.5, 0.5 }, size = { 1, 0.1 }, font = F.typed, color = COL.cream, alignX = CENTER, max = 120 })

-- Skip: bottom right, small. A press of the key fills it; a click or a tap skips at once.
local skip = button(sg, "Skip", { pos = { 0.985, 0.975 }, anchor = { 1, 1 }, size = { 0.105, 0.072 }, aspect = 2.6, visible = false },
	{ "Button_Signal_Up", "Button_Signal_Down", "Button_Signal_Hover" })
new("Frame", skip.Content, "Fill", { pos = { 0.08, 0.76 }, size = { 0, 0.08 }, bg = COL.cream, bgT = 0, z = 3 })
text(skip.Content, "Label", "SKIP", { pos = { 0.12, 0.2 }, size = { 0.76, 0.52 }, font = F.title, color = COL.cream, alignX = CENTER, z = 3 })
local chip = new("ImageLabel", skip, "Key", { pos = { 0.5, 0.04 }, anchor = { 0.5, 1 }, size = { 0.8, 0.44 }, sprite = "Chip_Cream", z = 6, visible = false })
text(chip, "Text", "SPACE", { pos = { 0.1, 0.14 }, size = { 0.8, 0.72 }, font = F.num, color = COL.navy, alignX = CENTER, z = 7 })

-- for a player who skipped: the run starts for everyone at the same moment
local wait_ = new("ImageLabel", sg, "Wait", { pos = { 0.985, 0.975 }, anchor = { 1, 1 }, size = { 0.2, 0.09 }, aspect = 3.4, sprite = "Telegram", visible = false })
text(wait_, "Label", "THE RUN STARTS IN", { pos = { 0.08, 0.2 }, size = { 0.84, 0.28 }, font = F.typed, color = COL.navy, alignX = CENTER })
text(wait_, "Time", "0:00", { pos = { 0.08, 0.5 }, size = { 0.84, 0.36 }, font = F.num, color = COL.rust, alignX = CENTER })

bars.Parent = game:GetService("StarterGui")
sg.Parent = game:GetService("StarterGui")
return "Cutscene built: " .. (#bars:GetDescendants() + #sg:GetDescendants()) .. " instances"
