--!strict
--[[
	GlowshardPacks: the premium currency for Robux (bible Section 17). ProductId is set when the
	developer products are created (Prompt 28); prices are provisional.
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

return {
	Schema = Check.shape({
		Glowshards = F.PositiveInt,
		Robux = F.PositiveInt,
		ProductId = Check.optional(F.PositiveInt),
	}),
	Order = { "Pack25", "Pack140", "Pack300", "Pack650", "Pack1800" },
	Entries = {
		Pack25 = { Glowshards = 25, Robux = 99 },
		Pack140 = { Glowshards = 140, Robux = 499 },
		Pack300 = { Glowshards = 300, Robux = 999 },
		Pack650 = { Glowshards = 650, Robux = 1999 },
		Pack1800 = { Glowshards = 1800, Robux = 4999 },
	},
}
