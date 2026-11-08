# Prompt 1: Content definitions

Every Config schema plus starter data (bible Section 24). Built and tested in Studio on
2026-11-08, build `p1-4d2a9d5`, installed in both places.

## Design Notes

**Decisions**
1. **36 content types**, one ModuleScript each under `Shared.Config`, every entry checked
   against its schema when Config loads, cross-references (`Check.ref`) resolved after all
   types load. The bible's tables are copied in as data: rooms, classes, traits, Legends,
   monsters, bosses, disasters, items, draft cards, eras, depth bands, dig results, votes,
   objectives, prices, passes, boosts, badges, quests, leaderboards, Glowshard rewards.
2. **Effects are data, through one vocabulary.** Classes, traits, Legends, draft cards and
   passes list modifiers (`{ Key, Value, Scope?, Room? }`). `Config.Modifiers` defines 119 keys,
   each with a unit, a default scope and the prompt whose system applies it, so no effect in
   the data lacks a home. A script check confirms every key used is defined and every key
   defined is used.
3. **Rule numbers in one place**: `Config.Tuning` has an entry per system (Clock, Grid,
   StartingBunker, Rooms, Votes, Player, Digging, Disturbance, Threat, Residents, Aging,
   Morale, Trader, Wanderers, Expeditions, Surface, Legends, ClassShop, Account, Lobby), each
   with its own schema (the aggregator now accepts `Schemas` per entry).
4. **Starting bunker**: from Section 6's order, the shaft is the third cell on both floors, so
   the layout runs from column -3 to 2 with the shaft in column -1 (Tuning.StartingBunker).
5. **Name pools**: 140 first names, 115 surnames and 31 nicknames for a 1950s American town
   of many backgrounds; nicknames for Rare and Legendary residents.
6. **Rarity shows in the look** is recorded on Tiers (the Look line per tier).

**Design Risks**
* Most numbers the bible leaves to Config are my provisional starting points (room costs,
  outputs and power, weapon and monster stats, loot, recipes, threat weights, resident
  needs and experience, morale amounts, trader prices, difficulty multipliers). They are
  marked provisional in the files and need playtests. The bible's own numbers are exact.

**Scope Risks**
* Cave pieces, radio logs, Codex pages, cosmetics, backstory lines and the other 12 Legends
  have no data yet. Each arrives with the prompt that uses it (17, 26, 27, 28, 29).

**Bible Questions**
1. Quartermaster level 3, "build costs -20%": I made it replace the passive's -10% (total
   -20%), not stack to -30%.
2. Cook's Hearty Meal "(2 cycles)": read as its cooldown.
3. Push Deeper, Keep Going and Kick have no duration in Section 8; set to 20 s.
4. The badge "30 alive in one run" (Section 16) and Old Man Higgins's "reach Year 100 with 30
   residents alive" (Section 15) are treated as one badge, at Year 100.
5. Gas leaks: the era table brings them in Era II, while hazard pockets in the Mines can
   release gas from the start. As a Surge disaster they begin in Era II; a hazard pocket can
   still burst gas in Era I.
6. The starting layout should be checked against the live doc's starting-bunker diagram in
   Prompt 4 (the copies in the Project only describe it).

**Recommended Improvements**
* A tuning sheet (a Sheets artifact) generated from Config, so Landon can read and adjust the
  provisional numbers without opening code.

**Technical Risks**
* Config validates on every server and client start. 36 types load in a few milliseconds
  today; keep an eye on it as content grows.

## Delivery Report

**Overview.** `Shared.Config` now holds the whole game's content as validated, frozen data,
readable on server and client. Nothing interprets it yet; Prompts 2 onward read from it.

**Files created** (repo `game/shared/Config/`): `_Fields` (shared checkers), Badges, Bosses,
Classes, Conditions, DepthBands, DigResults, Difficulties, Disasters, DraftCards, Eras,
GamePasses, GlowshardPacks, GlowshardRewards, ItemRarities, Items, Leaderboards, Legends,
LootTables, Modifiers, MoraleStates, Monsters, Objectives, Quests, Recipes, ResidentNames,
Resources, Rooms, Stats, SurfaceLocations, TalentSlots, TeamBoosts, Tiers, Traits, Tuning,
Votes, WandererOutcomes. `game/reports/P01_Content.md`.

**Files modified.** `Config/init.luau` (helper modules, per-entry schemas),
`DevTools/DataTests.luau` (12 content tests), `docs/ARCHITECTURE.md`, `BUILD.json`.

**Integration notes**
* Read content with `Config.Get("Rooms", "Kitchen")`, `Config.All("Classes")`,
  `Config.Get("Tuning", "Clock").DaySeconds`.
* A system applying effects reads the modifier keys it owns (`Config.Modifiers[key].Prompt`
  says which prompt that is) from the class, traits, Legend and draft cards in play.
* New content is a new entry; a new kind of content is a new ModuleScript with a Schema.

**Testing checklist (done, 2026-11-08)**
* [x] Edit mode, Run and Lobby: StructureCheck 0 errors (93 checks), Config 36 types with no
  errors, DataTests 39/39.
* [x] Run playtest: server boot with Config, DataTests 39/39 at runtime; the client reads
  Config (36 types, no errors; Kitchen, Mad Scientist spot-checked).
* [x] Content tests: starting bunker and stock match Section 6; three levels per room;
  one card per draft room; dig odds sum to 100 and wanderer odds to 1; eras cover Years 1
  to 100 and end in their boss's year; a cycle is day plus Surge; 18 buyable classes priced
  by tier; 30 traits (18/12); 12 Legends with one starter; RoomOutput modifiers name a room;
  loot lines are well formed; name pools have no repeats; morale states cover 0 to 100;
  Glowshard packs improve per Robux.

**Future extension notes**
* Product, pass and badge ids are empty until Prompt 28/29 creates them in Roblox.
* `Tuning.Threat` holds the threat formula's weights; Prompt 12 owns the formula itself.
