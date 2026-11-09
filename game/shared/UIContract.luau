--!strict
--[[
	UIContract: what the UI layout must provide for the code (bible Section 18).

	The layout is real instances in StarterGui, built through the Studio connector
	(studio/ui/Frame.lua and HUD.lua) and then given Landon's AutoScale Lite pass; code only
	clones templates and sets text and images. This list is the contract between the two: the
	controllers find these paths, and StructureCheck fails if one is missing, so a rebuilt or
	hand-edited screen can't drift away from the code.

	Paths are relative to the ScreenGui, with "." between names.
]]

export type Screen = {
	Places: { string }, -- "Lobby", "Run"
	DisplayOrder: number,
	Paths: { string },
}

local UIContract: { [string]: Screen } = {
	Frame = {
		Places = { "Lobby", "Run" },
		DisplayOrder = 5,
		Paths = {
			"Dim",
			"Cabinet.Backplate",
			"Cabinet.DockPlates",
			"Cabinet.TopBar.Title.Text",
			"Cabinet.TopBar.Subtitle",
			"Cabinet.TopBar.Chips",
			"Cabinet.TopBar.Close",
			"Cabinet.Pages",
			"Cabinet.MainAction.Content.Label",
			"Cabinet.MainAction.Content.Icon",
			"Cabinet.MainAction.Content.Price",
			"Cabinet.Footer.Actions",
			"Cabinet.Footer.Hint",
			"Cabinet.Footer.Keys",
			"Templates.Page.Tabs",
			"Templates.Page.Content.Grid",
			"Templates.Page.Content.List",
			"Templates.Page.Content.Empty",
			"Templates.Page.Detail.Hero.Image",
			"Templates.Page.Detail.Tag",
			"Templates.Page.Detail.Name",
			"Templates.Page.Detail.Sub",
			"Templates.Page.Detail.Body",
			"Templates.Tab.Content.Icon",
			"Templates.Tab.Content.Label",
			"Templates.Chip.Icon",
			"Templates.Chip.Amount",
			"Templates.Card.Portrait",
			"Templates.Card.Tag",
			"Templates.Card.Name",
			"Templates.Card.Sub",
			"Templates.Card.Lamp",
			"Templates.Card.Price.Amount",
			"Templates.Card.Stamp",
			"Templates.Row.Icon",
			"Templates.Row.Name",
			"Templates.Row.Value",
			"Templates.Section.Label",
			"Templates.Section.Body",
			"Templates.FooterButton.Content.Label",
			-- the Command View (Prompt 7)
			"DamageEdge",
			"Cabinet.Pages.CommandView.Tabs",
			"Cabinet.Pages.CommandView.View.Marks",
			"Cabinet.Pages.CommandView.View.Labels",
			"Cabinet.Pages.CommandView.View.Cursor",
			"Cabinet.Pages.CommandView.View.Help.Text",
			"Cabinet.Pages.CommandView.Detail.Name",
			"Cabinet.Pages.CommandView.Detail.Sub",
			"Cabinet.Pages.CommandView.Detail.Body",
			"Cabinet.Pages.CommandView.Detail.Options",
			"Templates.RoomLabel.Name",
			"Templates.RoomLabel.Lamp",
			"Templates.RoomLabel.Reading", -- Prompt 9: the overlay reading under a room label
			"Templates.RoomLabel.Reading.Text",
			"Templates.CellMark.Label",
			"Templates.PingMark",
			"Templates.OptionRow.Name",
			"Templates.OptionRow.Value",
			"Templates.OptionRow.Lamp",
		},
	},
	Votes = { -- the vote telegram (Prompt 8), above The Frame so a vote can be answered from any screen
		Places = { "Run" },
		DisplayOrder = 6,
		Paths = {
			"VoteBanner",
			"VoteBanner.Proposal",
			"VoteBanner.Tally",
			"VoteBanner.Timer",
			"VoteBanner.Timer.Fill",
			"VoteBanner.Yes",
			"VoteBanner.Yes.Content.Label",
			"VoteBanner.Yes.Key", -- Prompt 9: the controller's key chips (tap Y, hold Y)
			"VoteBanner.Yes.Key.Text",
			"VoteBanner.No",
			"VoteBanner.No.Content.Label",
			"VoteBanner.No.Key",
			"VoteBanner.No.Key.Text",
		},
	},
	HUD = {
		Places = { "Run" },
		DisplayOrder = 1,
		Paths = {
			"Vitals.Health.Needle",
			"Vitals.Health.Value",
			"Vitals.Stamina.Needle",
			"Vitals.Radiation.Needle",
			"Vitals.Ability.Icon",
			"Vitals.Ability.Cooldown",
			"Vitals.Ability.Key.Text",
			"Vitals.AbilityName",
			"Vitals.Class",
			"YearClock.Tile1.Digit",
			"YearClock.Tile2.Digit",
			"YearClock.Tile3.Digit",
			"YearClock.Era",
			"YearClock.EraName",
			"CycleDial.Pointer",
			"Phase.Text",
			"TimeLeft.Text",
			"Ready.Content.Lamp",
			"Ready.Content.Label",
			"Ready.Content.Count",
			"Ready.Key",
			"Ready.Key.Text",
			"Banner.Icon",
			"Banner.Text",
			"Stockpile.Resources",
			"Disturbance.Trace",
			"DisturbanceLabel",
			"DisturbanceLevel",
			"CommandView.Content.Key",
			"MiniMap.Paper.Cells",
			"MiniMap.Paper.You",
			"MiniMap.Depth",
			"Alerts",
			"Arrows",
			"Hotbar.Slot1.Item",
			"Hotbar.Slot2.Item",
			"Hotbar.Slot3.Item",
			"Hotbar.Slot4.Item",
			"Hotbar.Slot5.Ammo",
			"Touch.Fire.Content.Icon",
			"Touch.Aim",
			"Touch.Jump",
			"Touch.Melee",
			"Touch.Ability",
			"Touch.Interact",
			"Touch.Dodge",
			"Touch.Sprint",
			"Touch.Ping",
			"Touch.Shoulder",
			"Touch.Heal", -- Landon, 2026-11-08: the Heal button (CombatController)
			"Medkits.Count", -- carried Medkits and the heal in progress
			"Medkits.Fill",
			"Medkits.Key.Text",
			"Templates.ResourceChip.Icon",
			"Templates.ResourceChip.Value",
			"Templates.ResourceChip.Lamp",
			"Templates.AlertSlip.Icon",
			"Templates.AlertSlip.Text",
			"Templates.EdgeArrow",
			"Templates.MapCell.Label",
			"Templates.MapPing",
			"Downed.Title", -- Prompt 11: the downed and respawn telegram (CombatController)
			"Downed.Text",
			"Downed.Count",
			"Templates.Prompt.Plate.Key.Text", -- the themed interaction prompt (PromptController)
			"Templates.Prompt.Plate.Action",
			"Templates.Prompt.Plate.Object",
			"Templates.Prompt.Plate.Gauge.Fill",
			"Templates.DamageNumber.Value",
			"Templates.HealthBar.Back.Fill",
			"Meltdown", -- Prompt 13: the meltdown telegram (DisasterController)
			"Meltdown.Title",
			"Meltdown.Text",
			"Meltdown.Valves.Valve1.Lamp",
			"Meltdown.Valves.Valve2.Lamp",
			"Meltdown.Valves.Valve3.Lamp",
			"Meltdown.Count",
			"Templates.Valve.Plate.Lamp", -- a valve's plate in the world
			"Templates.Valve.Plate.Label",
			"Templates.Valve.Plate.State",
			"Templates.Valve.Plate.Gauge.Fill",
			"BossBar", -- Prompt 15: the boss bar (BossController)
			"BossBar.Name",
			"BossBar.Phase",
			"BossBar.Back.Fill",
			"Backpack", -- Prompt 16: the backpack chip and the elevator's fade (SurfaceController)
			"Backpack.Icon",
			"Backpack.Count",
			"Backpack.Fill",
			"Fade",
		},
	},
}

-- Finds a contract path under a ScreenGui (nil if any step is missing).
local function find(root: Instance, path: string): Instance?
	local node: Instance? = root
	for name in string.gmatch(path, "[^%.]+") do
		node = if node then node:FindFirstChild(name) else nil
	end
	return node
end

return table.freeze({
	Screens = UIContract,
	Find = find,
})
