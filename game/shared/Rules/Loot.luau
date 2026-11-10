--!strict
--[[
	Rules.Loot: rolling Config.LootTables (bible Sections 6, 10, 12 and 13). Pure, so the data
	tests and every service that hands out loot share it.

	Roll(tableId, rng, context) draws the table's Rolls lines by Weight; each gives Min..Max.
	Drops with the same resource, item or special add up:

		Loot.Roll("Cache", rng, { BandOre = "Iron" })
		-- { { Resource = "Scrap", Count = 62 }, { Item = "Flare", Count = 1 } }

	* context.BandOre is the ore a BandOre line gives (the band the loot is in). With none (the
	  Source Chamber) BandOre lines are left out of the draw.
	* context.Skip names Specials (or item ids) that nothing hands out yet (Gear before Prompt 26,
	  RadioLog before the Codex, the Lamp before placeables): their lines are left out of the draw
	  too, so the rest keep their odds between them.
	* context.OreMultiplier scales the ore a BandOre line gives (the Driller's DugOre).
	* context.ExtraRolls adds draws (the Scavenger's ExtraLootRolls on surface containers).
]]

local Config = require(script.Parent.Parent.Config)

local Loot = {}

export type Drop = { Resource: string?, Item: string?, Special: string?, Count: number }
export type Context = { BandOre: string?, Skip: { [string]: boolean }?, OreMultiplier: number?, ExtraRolls: number? }

-- The lines a table can give here, with their weights.
function Loot.Lines(tableId: string, context: Context?): { any }
	local entry = Config.Get("LootTables", tableId)
	local skip = if context then context.Skip else nil
	local list = {}
	for _, line in entry.Lines do
		local usable = line.Weight > 0
		if line.Special == "BandOre" and not (context and context.BandOre) then
			usable = false
		elseif line.Special and line.Special ~= "BandOre" and skip and skip[line.Special] then
			usable = false
		elseif line.Item and skip and skip[line.Item] then
			usable = false -- an item nothing hands out yet (a Lamp before placeables)
		end
		if usable then
			table.insert(list, line)
		end
	end
	return list
end

local function keyOf(drop: Drop): string
	return `{drop.Resource or ""}|{drop.Item or ""}|{drop.Special or ""}`
end

function Loot.Roll(tableId: string, rng: Random, context: Context?): { Drop }
	local entry = Config.Get("LootTables", tableId)
	local lines = Loot.Lines(tableId, context)
	local total = 0
	for _, line in lines do
		total += line.Weight
	end
	local byKey: { [string]: Drop } = {}
	local order: { string } = {}
	if total <= 0 then
		return {}
	end
	local rolls = entry.Rolls + math.max(math.floor((context and context.ExtraRolls) or 0), 0)
	for _ = 1, rolls do
		local pick = rng:NextNumber() * total
		local chosen = lines[#lines]
		for _, line in lines do
			pick -= line.Weight
			if pick <= 0 then
				chosen = line
				break
			end
		end
		local count = rng:NextInteger(chosen.Min, math.max(chosen.Min, chosen.Max))
		local drop: Drop
		if chosen.Special == "BandOre" then
			local ore = (context :: Context).BandOre
			count = math.floor(count * ((context :: Context).OreMultiplier or 1) + 0.5)
			drop = { Resource = ore, Count = count }
		elseif chosen.Resource then
			drop = { Resource = chosen.Resource, Count = count }
		elseif chosen.Item then
			drop = { Item = chosen.Item, Count = count }
		else
			drop = { Special = chosen.Special, Count = count }
		end
		if count > 0 then
			local key = keyOf(drop)
			local have = byKey[key]
			if have then
				have.Count += count
			else
				byKey[key] = drop
				table.insert(order, key)
			end
		end
	end
	local drops = {}
	for _, key in order do
		table.insert(drops, byKey[key])
	end
	return drops
end

-- "62 SCRAP · 1 FLARE" for alerts.
local SPECIAL_NAMES: { [string]: string } = {
	Blueprint = "blueprint", RadioLog = "radio log", Glowshards = "Glowshards", Gear = "gear", Recruit = "recruit",
	BandOre = "ore",
}

function Loot.Text(drops: { Drop }): string
	local parts = {}
	for _, drop in drops do
		local name = if drop.Resource then Config.Get("Resources", drop.Resource).Name
			elseif drop.Item then Config.Get("Items", drop.Item).Name
			else SPECIAL_NAMES[drop.Special or ""] or drop.Special or "?"
		table.insert(parts, `{drop.Count} {string.upper(name)}`)
	end
	return table.concat(parts, " · ")
end

return table.freeze(Loot)
