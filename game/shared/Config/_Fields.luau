--!strict
--[[
	_Fields: checkers shared by the content modules (a helper, not a content type: Config
	skips child modules whose names start with _).
]]

local Check = require(script.Parent.Parent.Utilities.Check)

local Fields = {}

Fields.Name = Check.string(60, { min = 1 })
Fields.Short = Check.string(160)
Fields.Text = Check.string(600)
Fields.Count = Check.integer(0)
Fields.PositiveInt = Check.integer(1)
Fields.Number = Check.number()
Fields.NonNegative = Check.number({ min = 0 })
Fields.Fraction = Check.number({ min = 0, max = 1 })
Fields.Seconds = Check.number({ min = 0, max = 36000 })
Fields.Hex = Check.string(7, { pattern = "^#%x%x%x%x%x%x$" })
Fields.Flag = Check.optional(Check.boolean())

-- An art asset name from the pipeline (Category_Name or Category_Name_Variant).
Fields.Asset = Check.optional(Check.string(64, { pattern = "^%u%w*_%u[%w_]*$" }))

-- Where something comes from or how it unlocks.
Fields.Robux = Check.optional(Check.integer(0, 100000))
Fields.Glowshards = Check.optional(Check.integer(0, 100000))

-- A price or cost in stockpile resources: { Scrap = 100, Iron = 20 }
Fields.Costs = Check.map(Check.ref("Resources"), Check.integer(0), 9)

-- A low..high range of whole numbers.
Fields.Range = Check.shape({ Min = Check.number(), Max = Check.number() })

-- What an effect changes. Key names the modifier (Config.Modifiers says what it means, its
-- unit and which system applies it); Scope says who it reaches; Room narrows RoomOutput-style
-- keys to one room type.
Fields.Scope = Check.enum({ "Self", "Presence", "Room", "Nearby", "Floor", "Team", "Bunker" })
Fields.Modifier = Check.shape({
	Key = Check.ref("Modifiers"),
	Value = Check.number(),
	Room = Check.optional(Check.ref("Rooms")),
	Scope = Check.optional(Fields.Scope),
})
Fields.Modifiers = Check.array(Fields.Modifier, 12)

-- A described effect: the text players read and the modifiers systems apply.
Fields.Effect = Check.shape({
	Text = Fields.Text,
	Modifiers = Check.optional(Fields.Modifiers),
})

-- A list of item ids with counts (starting kits, loot, rewards).
Fields.ItemStack = Check.shape({ Item = Check.ref("Items"), Count = Check.optional(Check.integer(1, 999)) })
Fields.ItemStacks = Check.array(Fields.ItemStack, 12)

return table.freeze(Fields)
