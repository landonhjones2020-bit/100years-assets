--!strict
--[[
	Cutscenes: the words and the looks of the intro cutscene (bible Section 4). Where things are
	and when they move is Config.CutscenePaths, made in Blender; this is what is said on screen and
	how the light changes, written by hand.

	* Bulletin: "a radio bulletin scrolls across the screen" (shot 1). Text is one line, scrolled
	  once across the strip between From and To. The bible gives no wording: this one is ours
	  until Landon rewrites it (Prompt 22's Bible Questions).
	* Title, Tagline: the title card (shot 6) and its line, "Survive. Dig. Don't wake it.", one
	  word group at a time.
	* Looks: the Lighting each part of the cutscene is shot in. Morning is the lobby's Main Street
	  light (tools/lobby_world.py), so the street looks as it did a minute ago. LookKeys: which look
	  at which second; between two keys the light blends, and a key with Cut starts at once. From
	  the dive on (Beats.DiveTo) the light is the run's own again.
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

local S = F.Seconds
local Look = Check.shape({
	ClockTime = Check.number({ min = 0, max = 24 }),
	GeographicLatitude = F.Number,
	Brightness = F.NonNegative,
	Ambient = F.Hex,
	OutdoorAmbient = F.Hex,
	ColorShiftTop = F.Hex,
	Exposure = F.Number,
	EnvironmentDiffuse = F.Fraction,
	EnvironmentSpecular = F.Fraction,
	AtmosphereDensity = F.Fraction,
	AtmosphereOffset = F.Fraction,
	AtmosphereColor = F.Hex,
	AtmosphereDecay = F.Hex,
	AtmosphereGlare = F.NonNegative,
	AtmosphereHaze = F.NonNegative,
	BloomIntensity = F.NonNegative,
	BloomSize = F.NonNegative,
	BloomThreshold = F.NonNegative,
	CloudCover = F.Fraction,
	CloudColor = F.Hex,
	Tint = F.Hex, -- a ColorCorrection over the whole picture
	Saturation = F.Number,
	Contrast = F.Number,
})

return {
	Schema = Check.shape({
		Path = Check.ref("CutscenePaths"),
		Bulletin = Check.shape({ Station = F.Short, Tag = F.Short, Text = Check.string(400), From = S, To = S }),
		Title = F.Short,
		TitleFrom = S,
		TitleTo = S,
		Tagline = Check.array(Check.shape({ Text = F.Short, At = S }), 4),
		Looks = Check.map(Check.string(24), Look, 8),
		LookKeys = Check.array(Check.shape({ At = S, Look = Check.string(24), Cut = F.Flag }), 16),
	}),
	Entries = {
		Intro = {
			Path = "Intro",
			Bulletin = {
				Station = "BRIGHTWATER RADIO",
				Tag = "EMERGENCY BULLETIN",
				Text = "...A STEADFAST SHELTER IS BUILT TO LAST A CENTURY!  -  WE INTERRUPT THIS PROGRAM  -  THIS IS NOT A TEST  -  "
					.. "ALL BRIGHTWATER RESIDENTS: GO TO THE STEADFAST SHELTER ON MINE HILL AT ONCE  -  THIS IS NOT A TEST  -",
				From = 0.5,
				To = 10.4,
			},
			Title = "100 YEARS BELOW",
			TitleFrom = 27.0,
			TitleTo = 28.9,
			Tagline = {
				{ Text = "Survive.", At = 27.55 },
				{ Text = "Dig.", At = 27.95 },
				{ Text = "Don't wake it.", At = 28.35 },
			},
			Looks = {
				Morning = {
					ClockTime = 10, GeographicLatitude = -15, Brightness = 2.6,
					Ambient = "#464C5A", OutdoorAmbient = "#7C8494", ColorShiftTop = "#FFF4E0", Exposure = -0.2,
					EnvironmentDiffuse = 0.8, EnvironmentSpecular = 0.6,
					AtmosphereDensity = 0.22, AtmosphereOffset = 0.1, AtmosphereColor = "#CDE0F0", AtmosphereDecay = "#96B4D2",
					AtmosphereGlare = 0.15, AtmosphereHaze = 1.2,
					BloomIntensity = 0.2, BloomSize = 20, BloomThreshold = 2,
					CloudCover = 0.42, CloudColor = "#FFFFFF",
					Tint = "#FFFFFF", Saturation = 0.05, Contrast = 0.02,
				},
				Flash = { -- the instant of the blast: everything burnt out
					ClockTime = 10, GeographicLatitude = -15, Brightness = 8,
					Ambient = "#FFF6E0", OutdoorAmbient = "#FFF6E0", ColorShiftTop = "#FFF0D0", Exposure = 2.4,
					EnvironmentDiffuse = 1, EnvironmentSpecular = 0.2,
					AtmosphereDensity = 0.3, AtmosphereOffset = 0.3, AtmosphereColor = "#FFF2DC", AtmosphereDecay = "#FFE0B0",
					AtmosphereGlare = 2, AtmosphereHaze = 3,
					BloomIntensity = 1.2, BloomSize = 40, BloomThreshold = 0.9,
					CloudCover = 0.42, CloudColor = "#FFF0D8",
					Tint = "#FFF4E2", Saturation = -0.5, Contrast = -0.1,
				},
				Blast = { -- the fireball lights the town from the west
					ClockTime = 10, GeographicLatitude = -15, Brightness = 3.4,
					Ambient = "#7A4A30", OutdoorAmbient = "#B06C40", ColorShiftTop = "#FFB060", Exposure = 0.35,
					EnvironmentDiffuse = 0.7, EnvironmentSpecular = 0.3,
					AtmosphereDensity = 0.3, AtmosphereOffset = 0.2, AtmosphereColor = "#F0B078", AtmosphereDecay = "#E07830",
					AtmosphereGlare = 1.2, AtmosphereHaze = 2.6,
					BloomIntensity = 0.7, BloomSize = 32, BloomThreshold = 1.2,
					CloudCover = 0.5, CloudColor = "#F0A060",
					Tint = "#FFE2C2", Saturation = 0.1, Contrast = 0.12,
				},
				After = { -- dust and fire-light under the cloud
					ClockTime = 10, GeographicLatitude = -15, Brightness = 1.1,
					Ambient = "#3E2A22", OutdoorAmbient = "#6A4230", ColorShiftTop = "#E07840", Exposure = -0.15,
					EnvironmentDiffuse = 0.5, EnvironmentSpecular = 0.2,
					AtmosphereDensity = 0.42, AtmosphereOffset = 0.35, AtmosphereColor = "#B87850", AtmosphereDecay = "#8A4A2A",
					AtmosphereGlare = 0.5, AtmosphereHaze = 4.5,
					BloomIntensity = 0.5, BloomSize = 28, BloomThreshold = 1.4,
					CloudCover = 0.75, CloudColor = "#7A5440",
					Tint = "#F2C8A0", Saturation = -0.1, Contrast = 0.16,
				},
			},
			LookKeys = {
				{ At = 0, Look = "Morning" },
				{ At = 14.86, Look = "Morning" },
				{ At = 15.0, Look = "Flash" }, -- the door is lit white from behind the camera just before the cut
				{ At = 15.5, Look = "Flash" },
				{ At = 16.5, Look = "Blast" },
				{ At = 18.4, Look = "Blast" },
				{ At = 19.6, Look = "After" },
			},
		},
	},
}
