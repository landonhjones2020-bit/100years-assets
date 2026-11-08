--!strict
--[[
	DraftCards: the blueprint card pool (bible Section 8 and the Appendix). After every Surge
	three cards are drawn and the team votes for one; a card taken leaves the pool for the run.
	Room cards weigh more early (EarlyWeight applies in Era I), so every run gets its key rooms.
	Weights are provisional.
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

local function mod(key: string, value: number, extra: { [string]: any }?): { [string]: any }
	local t: { [string]: any } = { Key = key, Value = value }
	if extra then
		for k, v in extra do
			t[k] = v
		end
	end
	return t
end

local function roomCard(room: string, name: string): { [string]: any }
	return { Name = name, Kind = "Room", Room = room, Text = `Unlocks the {name} for the run.`, Weight = 10, EarlyWeight = 20 }
end

local function card(kind: string, name: string, text: string, modifiers: { any }, weight: number?): { [string]: any }
	return { Name = name, Kind = kind, Text = text, Modifiers = modifiers, Weight = weight or 8 }
end

return {
	Schema = Check.shape({
		Name = F.Name,
		Kind = Check.enum({ "Room", "BunkerPerk", "ResidentBoon", "PlayerBoon", "RiskDeal" }),
		Text = F.Text,
		Room = Check.optional(Check.ref("Rooms")),
		Modifiers = Check.optional(F.Modifiers),
		Weight = F.NonNegative,
		EarlyWeight = Check.optional(F.NonNegative),
	}),
	Entries = {
		ArmoryCard = roomCard("Armory", "Armory"),
		RadioRoomCard = roomCard("RadioRoom", "Radio Room"),
		LoungeCard = roomCard("Lounge", "Lounge"),
		LabCard = roomCard("Lab", "Lab"),
		DrillBayCard = roomCard("DrillBay", "Drill Bay"),
		GreenhouseCard = roomCard("Greenhouse", "Greenhouse"),
		TrainingRoomCard = roomCard("TrainingRoom", "Training Room"),
		TradingPostCard = roomCard("TradingPost", "Trading Post"),
		MemorialCard = roomCard("Memorial", "Memorial"),

		ReinforcedWalls = card("BunkerPerk", "Reinforced Walls", "+25% room HP.", { mod("RoomHP", 1.25) }),
		Sprinklers = card("BunkerPerk", "Sprinklers", "Fire spreads 50% slower.", { mod("FireSpread", 0.5) }),
		SumpPumps = card("BunkerPerk", "Sump Pumps", "Floods drain twice as fast.", { mod("FloodDrainSpeed", 2) }),
		InsulatedGrid = card("BunkerPerk", "Insulated Grid", "Blackouts last half as long.", { mod("BlackoutDuration", 0.5) }),
		DeepLamps = card("BunkerPerk", "Deep Lamps", "Halves the extra monster spawns in dark rooms.", { mod("DarkSpawnBonus", 0.5) }),
		SteelBlastDoor = card("BunkerPerk", "Steel Blast Door", "Blast Door +1 level.", { mod("BlastDoorLevel", 1) }),
		GasFilters = card("BunkerPerk", "Gas Filters", "Gas leaks 50% weaker.", { mod("GasStrength", 0.5) }),

		FieldTraining = card("ResidentBoon", "Field Training", "Every resident +1 level.", { mod("ResidentLevels", 1) }),
		MoraleBroadcast = card("ResidentBoon", "Morale Broadcast", "+15 morale for everyone.", { mod("MoraleNow", 15) }),
		RadioBooster = card("ResidentBoon", "Radio Booster", "Two recruits arrive now.", { mod("RecruitsNow", 2) }),
		VeteranRecruit = card("ResidentBoon", "Veteran Recruit", "A Rare resident joins.", { mod("RareRecruitNow", 1) }),

		ArmoryShipment = card("PlayerBoon", "Armory Shipment", "Every player's weapons +1 rarity.", { mod("WeaponRarityUp", 1) }),
		MedCache = card("PlayerBoon", "Med Cache", "+2 Medkits for every player.", { mod("MedkitsPerPlayer", 2) }),
		AmmoPress = card("PlayerBoon", "Ammo Press", "Ammo crafting costs 30% less.", { mod("AmmoCraftCost", 0.7) }),
		FieldRations = card("PlayerBoon", "Field Rations", "+20% stamina for the rest of the run.", { mod("StaminaMult", 1.2) }),

		DeepCharges = card("RiskDeal", "Deep Charges", "Digging twice as fast, but +50% Disturbance.", {
			mod("DigSpeed", 2, { Scope = "Team" }),
			mod("DigDisturbance", 1.5, { Scope = "Team" }),
		}, 5),
		Overclock = card("RiskDeal", "Overclock", "Reactor Core +50% power, with a chance of overload.", {
			mod("RoomOutput", 1.5, { Room = "ReactorCore" }),
			mod("ReactorOverloadChance", 0.15),
		}, 5),
		BlackMarket = card("RiskDeal", "Black Market", "The trader arrives now with rare stock at +50% prices.", {
			mod("TraderNow", 1),
			mod("TraderRareStock", 1),
			mod("TraderPrices", 1.5),
		}, 5),
		BountyContract = card("RiskDeal", "Bounty Contract", "Kill 30 monsters before the next Surge for 500 Scrap.", {
			mod("BountyKills", 30),
			mod("BountyScrap", 500),
		}, 5),
		SalvageRights = card("RiskDeal", "Salvage Rights", "Double loot on the next surface trip, but the next storm hits 30 seconds early.", {
			mod("NextTripLoot", 2),
			mod("NextStormEarlySeconds", 30),
		}, 5),
	},
}
