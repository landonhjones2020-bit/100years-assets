--!strict
--[[
	ProfileSchema: the shape of a player's saved data (bible Section 23), its defaults, its
	migrations, and the load pipeline: migrate, then reconcile, then validate. Pure (no
	DataStores), so the data tests can run it on fixtures. ProfileService does the I/O.

	Version history:
	  1  2026-11-08  first version (Prompt 2)

	To change the shape: raise VERSION, add MIGRATIONS[old] that turns version old into old+1,
	and update Default() and SHAPE. Never rename or drop a field without a migration: during
	a rolling update old and new servers run side by side, and an old server refuses (never
	overwrites) data newer than it knows.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Check = require(Shared.Utilities.Check)
local Config = require(Shared.Config)
local TableUtil = require(Shared.Utilities.TableUtil)

local ProfileSchema = {}

ProfileSchema.VERSION = 1
ProfileSchema.RECEIPTS_KEPT = 200

-- version -> function turning a profile of that version into the next version
local MIGRATIONS: { [number]: (data: { [string]: any }) -> { [string]: any } } = {}

-- Fields whose value is a fixed-shape record (reconciled field by field); every other table
-- field is a map whose keys belong to the player (classes owned, badges earned...).
local RECORDS: { [string]: boolean } = {
	Talents = true,
	Cosmetics = true,
	Stats = true,
	Quests = true,
	ClassShop = true,
	Loadout = true,
}

local Id = Check.string(64, { pattern = "^[%a][%w_]*$" })

local SHAPE = Check.shape({
	Version = Check.integer(1),
	Glowshards = Check.integer(0, 1e9),
	Classes = Check.map(Id, Check.shape({ Level = Check.integer(1, 3), XP = Check.number({ min = 0 }) }), 100),
	Talents = Check.shape({ Slots = Check.integer(0, 3), Equipped = Check.array(Id, 3) }),
	Legends = Check.map(Id, Check.shape({ Renown = Check.integer(1, 5) }), 200),
	Cosmetics = Check.shape({
		Owned = Check.map(Id, Check.boolean(), 2000),
		Equipped = Check.map(Id, Id, 32),
	}),
	Stats = Check.map(Id, Check.number({ min = 0 }), 64),
	Badges = Check.map(Id, Check.number({ min = 0 }), 500),
	Quests = Check.shape({
		Daily = Check.array(Check.any(), 10),
		Weekly = Check.array(Check.any(), 10),
		LastReset = Check.number({ min = 0 }),
	}),
	ClassShop = Check.shape({
		Day = Check.integer(0), -- the shop day (Rules.ClassShop.Day) these slots are for
		Slots = Check.array(Id, 4),
		RerollsUsed = Check.integer(0),
		Wishlist = Check.optional(Id),
		WishDay = Check.optional(Check.integer(0)), -- the shop day the wish was made, or last shown (Prompt 21)
		Trial = Check.optional(Id), -- today's free-trial class, one of the slots
		TrialUsed = Check.optional(Check.boolean()), -- today's trial run has launched
	}),
	-- What the player brings to a run (Section 14: set in the lobby). Talents, the Legend, the
	-- outfit and skins join it with their prompts.
	Loadout = Check.shape({ Class = Id }),
	AccountLevel = Check.integer(1, 100),
	AccountXP = Check.number({ min = 0 }),
	Settings = Check.map(Id, Check.primitive(64), 64),
	Receipts = Check.array(Check.string(64, { min = 1 }), 200),
	FirstRunDone = Check.boolean(),
})

-- A new player's profile: the free class and the starter Legend are theirs (bible Sections
-- 14 and 15).
function ProfileSchema.Default(): { [string]: any }
	local classes: { [string]: any } = {}
	for _, class in Config.All("Classes") do
		if class.Tier == "Free" then
			classes[class.Id] = { Level = 1, XP = 0 }
		end
	end
	local legends: { [string]: any } = {}
	local starter = Config.Get("Tuning", "Legends").StarterLegend
	legends[starter] = { Renown = 1 }
	return {
		Version = ProfileSchema.VERSION,
		Glowshards = 0,
		Classes = classes,
		Talents = { Slots = 0, Equipped = {} },
		Legends = legends,
		Cosmetics = { Owned = {}, Equipped = {} },
		Stats = { Runs = 0, Wins = 0, BestYear = 0, Deepest = 0 },
		Badges = {},
		Quests = { Daily = {}, Weekly = {}, LastReset = 0 },
		ClassShop = { Day = 0, Slots = {}, RerollsUsed = 0 },
		Loadout = { Class = "Survivor" },
		AccountLevel = 1,
		AccountXP = 0,
		Settings = {},
		Receipts = {},
		FirstRunDone = false,
	}
end

-- Runs every migration from data.Version up to VERSION. Errors if a step is missing.
function ProfileSchema.Migrate(data: { [string]: any }): { [string]: any }
	local version = data.Version
	if type(version) ~= "number" then
		version = 1
		data.Version = 1
	end
	while version < ProfileSchema.VERSION do
		local step = MIGRATIONS[version]
		if not step then
			error(`no migration from profile version {version}`)
		end
		data = step(data)
		version += 1
		data.Version = version
	end
	return data
end

-- Fills in fields the profile is missing (new fields, new record fields) from the defaults.
-- Never touches the player's own keys in maps.
function ProfileSchema.Reconcile(data: { [string]: any }): { [string]: any }
	local defaults = ProfileSchema.Default()
	for field, value in defaults do
		local current = data[field]
		if current == nil then
			data[field] = value
		elseif RECORDS[field] and type(current) == "table" and type(value) == "table" then
			for subField, subValue in value do
				if current[subField] == nil then
					current[subField] = subValue
				end
			end
		end
	end
	return data
end

function ProfileSchema.Validate(data: any): (boolean, string?)
	return SHAPE(data)
end

export type LoadStatus = "New" | "Loaded" | "TooNew" | "Invalid"

--[[
	The whole load pipeline for stored Data (nil for a new player): returns the profile to use
	and a status. TooNew and Invalid return no profile: the player must not play on it (and
	nothing may be written).
]]
function ProfileSchema.Load(stored: any): ({ [string]: any }?, LoadStatus, string?)
	if stored == nil then
		return ProfileSchema.Default(), "New", nil
	end
	if type(stored) ~= "table" then
		return nil, "Invalid", `stored data is a {type(stored)}`
	end
	if type(stored.Version) == "number" and stored.Version > ProfileSchema.VERSION then
		return nil, "TooNew", `version {stored.Version} is newer than {ProfileSchema.VERSION}`
	end
	local data = TableUtil.DeepCopy(stored)
	local ok, result = pcall(ProfileSchema.Migrate, data)
	if not ok then
		return nil, "Invalid", tostring(result)
	end
	data = ProfileSchema.Reconcile(result)
	local valid, why = ProfileSchema.Validate(data)
	if not valid then
		return nil, "Invalid", why
	end
	return data, "Loaded", nil
end

-- What the player's own client sees: everything except the receipt log.
function ProfileSchema.Public(data: { [string]: any }): { [string]: any }
	local copy = TableUtil.DeepCopy(data)
	copy.Receipts = nil
	return copy
end

-- Adds a receipt id, keeping the newest RECEIPTS_KEPT.
function ProfileSchema.AddReceipt(data: { [string]: any }, receiptId: string)
	local receipts = data.Receipts
	table.insert(receipts, receiptId)
	while #receipts > ProfileSchema.RECEIPTS_KEPT do
		table.remove(receipts, 1)
	end
end

ProfileSchema._MIGRATIONS = MIGRATIONS -- for the data tests

return ProfileSchema
