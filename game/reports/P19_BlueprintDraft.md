# Prompt 19: The blueprint draft

After every Surge the team now drafts one blueprint card (bible Section 8 and the Appendix's card
pool). Three cards drop under the year clock; each player picks one, the card with the most picks
wins after 20 seconds (ties at random) and applies at once, and it leaves the pool for the run. A
blueprint found in loot or brought home by an expedition joins the next draft as a fourth card,
stamped FOUND with its finder's name. The level 3 Mad Scientist has one free reroll an era. Built
and tested on 2026-11-09 (Landon's answers to the two Prompt 19 questions came first: the cards
under the clock, and found blueprints joining the next draft). The final install is in
`BUILD_LOG.md` (code asset 95026446991297), in Run and Lobby.

Landon's answers to the Bible Questions of Prompts 13, 14, 16 and 17 were built in the same pass:
see "Landon's answers" at the end.

## Design Notes

**Decisions**
1. **A service for the cards, the votes in VoteService** (Section 23: VoteService owns "Proposals,
   tallies, drafts, kicks").
   * `VoteService` runs the draft vote: a vote whose spec has `Options` is a MostVotes vote. Each
     player picks one option (the `CastPick` remote) and can change it until it closes; the most
     picks wins when time is up, ties at random (`Rules.Votes.Winner`); everyone having picked
     closes it at once. `SetOptions` swaps an open draft's cards for a reroll.
   * `DraftService` (new) owns the cards: drawing, what each card does, found blueprints, rerolls,
     the Bounty Contract's count and the Overclock's overloads. Section 23 has no service for it: a
     Bible Question.
   * `Shared.Rules.Draft` (pure): the pool, weighted draws, a card's face, tallies, a controller's
     next pick. Numbers are `Tuning.Draft`; the cards stay `Config.DraftCards` (each gained a
     `Short` line for its face; `Text` keeps the bible's words).
2. **When a draft opens** (Section 8: "After every Surge"): at `CycleClock.SurgeEnded`, so after the
   tutorial wave, boss Surges and Endless Surges too. Not after the final Surge: the run is over. The
   draft joins the vote queue like any vote (one vote on the banner at a time).
3. **The cards under the clock** (Landon, Prompt 19). The vote telegram names the draft ("BLUEPRINT
   DRAFT · PICK A CARD"), counts the picks and runs the timer; up to four cards hang below it
   (`StarterGui.Votes.Draft`). Each card is a catalog card in its kind's colours (Room teal, Bunker
   Perk steel blue, Resident Boon green, Player Boon orange, Risk Deal rust) with an emblem, its
   name, its short text and a chip with its picks. Your pick gets an orange frame and a YOUR PICK
   ribbon; the winner glows for the 3 seconds the result shows. Nothing covers the middle of the
   screen, so players can move and fight.
4. **Picking.** PC: click a card (the cursor is freed with the wheel click, as for every vote).
   Touch: tap. Controller: tap Y to move your pick to the next card, hold Y for the one before.
5. **Solo** (Section 8, rule 6: "the player picks the draft card"): the same cards; the player's
   pick applies at once (it closes the vote). With no pick, a card comes at random when time is up.
6. **Only usable cards come up.** A card is offered when every modifier it carries has a system
   that applies it (`DraftService`'s HANDLERS), a room card's room isn't unlocked already (the Drill
   Bay at depth 2), and the Steel Blast Door only below level 3. Sump Pumps and Gas Filters wait for
   Prompt 23, Ammo Press and Black Market for Prompt 30: 25 of the 29 cards come up today.
7. **What each card does.**
   * Room cards unlock their room (`BuildService:Unlock`).
   * Reinforced Walls: RoomHP x1.25 (`BunkerGrid`). Sprinklers and Insulated Grid:
     `DisasterService`'s FireSpread and BlackoutDuration. Deep Lamps: a dark room's extra breach
     weight halved (`BreachService`, DarkRoomWeight 2 becomes 1.5). Steel Blast Door: the door goes
     up a level (its HP with it).
   * Field Training: every resident (the away too) goes up a level, the stat by their job as usual.
     Morale Broadcast: +15 morale for everyone. Radio Booster: two recruits at the Blast Door (Rare at
     the Radio Room's 15%). Veteran Recruit: a Rare resident.
   * Armory Shipment: every player's guns and melee weapon one rarity up, and every kit made later
     (players who join, a new class). Med Cache: +2 carried Medkits for everyone in the run now.
     Field Rations: max stamina x1.2 for the rest of the run (a `StaminaMax` player attribute the
     HUD reads).
   * Deep Charges: DigSpeed x2 and DigDisturbance x1.5 (`DigService`). Overclock: the Reactor Core
     makes x1.5 power (`EconomyService`, which `PowerService` reads) and each Surge has a 15% chance
     of a Reactor overload, 10 to 50 s into it (`DisasterService:StartMeltdown`, the 60 s meltdown
     and its three valves). Bounty Contract: monster kills are counted until the next Surge starts;
     30 pays 500 Scrap at once; progress alerts every 10. Salvage Rights: containers roll twice as
     many times until the next storm, and the next storm hits 30 s before its Surge (players up top
     get a 10 s warning).
8. **Found blueprints** (Landon, Prompt 19: they join the next draft). A blueprint in loot is one
   card, drawn from the pool when it's found.
   * On the surface (the Hardware Store, the radio tower and the Steadfast showroom hold them) it
     goes into the finder's pack as its own slot ("1 BLUEPRINT: LOUNGE") and counts once unloaded at
     the hall or a Storage room, like any loot (Section 12).
   * Found in the bunker it is home at once. Expeditions bring theirs home with the team ("A
     BLUEPRINT" in the finds).
   * A card that's home waits for the next draft and joins it as an extra card, one a draft
     (`FoundPerDraft`), stamped FOUND with who found it. The team still votes; if it isn't picked it
     goes back to the pool. A card drafted meanwhile is swapped for another when it comes home.
   * Caches don't hold blueprints: the bible's cache is "Scrap, gear or a radio log".
9. **Rerolls.** The level 3 Mad Scientist's free reroll (one per era, Section 14) is a REROLL
   button where YES and NO sit, shown only to a player who has one (the `DraftRerolls` attribute).
   It draws fresh cards (the found one stays), clears the picks and starts the 20 s over. The paid
   Blueprint Reroll (49 Robux, Section 17) is Prompt 28's shop; it will call
   `DraftService:Reroll(player, "Paid")`.

**Design Risks**
* Room cards weigh twice as much in Era I, so early drafts are often three rooms (the first
  playtest drew Drill Bay, Lab and Training Room). That is the bible's intent ("every run gets its
  key rooms"); playtests will say if perks come too late.
* Bounty Contract's 30 kills before the next Surge are hard in a quiet day; playtests will tell.
* Overclock's overload can come in any Surge, a boss Surge included.

**Scope Risks**
* Four cards wait for later systems. The pool has 25 cards, so a long run (more than 25 Surges)
  runs out of cards; after that no draft opens (logged).

**Bible Questions**

(Landon answered these on 2026-11-12: `game/reports/Answers_2026-11-12.md`.)

1. **DraftService.** Section 23 gives drafts to VoteService and has no service for the cards. Built:
   VoteService runs the vote; a new DraftService owns the cards, their effects and found blueprints.
   Add DraftService to Section 23?
2. **A found blueprint not picked.** Built: it goes back to the pool (it may come up again in a later
   draft). Or should it stay as an extra card until the team takes it?
3. **Med Cache over the carry limit.** Built: +2 carried Medkits for everyone in the run, even past
   the 3 a player can carry (the Medbay only restocks up to 3). Right?
4. **Overclock's overload.** Built: a 15% chance each Surge, starting 10 to 50 s into it, boss
   Surges included. Right?
5. **Bounty kills.** Built: every monster killed anywhere (bunker, surface, the Deep) counts, by
   anyone, residents and turrets included. Right?
6. **Salvage Rights' "next surface trip".** Built: double loot from the moment it's drafted until
   the next storm starts. Right?
7. **When the pool runs dry.** Built: no draft. Should the pool refill (taken cards come back), or
   should Endless have a card pool of its own?

**Recommended Improvements**
* The cards could show what they unlock: a room card's room rendered from its A7 art in the window.
* A short card flip when the draft opens and a "PICKED" stamp landing on the winner.
* The results screen could list the run's cards in the order drafted.

**Technical Risks**
* On phones the cards are small (about 75 x 80 points on a 390-point-tall screen): the text is held
  at 12 points and may clip on the longest lines. Prompt 34's phone pass should check them.
* Studio's simulated mouse can't press the wheel, so a PC click on a card was only possible while
  the cursor was free; with the cursor locked to the camera (the game's default) a person has to
  free it with the wheel first, as for every vote.
* The draft atlases load on first use; VoteController preloads them when the telegram starts.

## Delivery Report

**Overview.** The blueprint draft: after every Surge, three cards (four with a found blueprint)
under the year clock, a 20 s team pick, each card's effect, found blueprints, the Mad Scientist's
free reroll.

**Files created**
* `game/places/Run/server/Services/DraftService.luau`
* `game/shared/Rules/Draft.luau`
* `studio/ui/Votes_Draft.lua`, `studio/ui/patches/Votes_P19.lua` (applied in Run)
* `ui/atlas_draft_a.png`, `ui/atlas_draft_b.png` (the five draft cards and the FOUND stamp,
  `generators/UI/UI_Kit.py`: `Draft_<Kind>`, `Stamp_Found`)
* `game/reports/P19_BlueprintDraft.md`

**Files modified**
* `VoteService` (draft votes with options, `CastPick`, `SetOptions`, `Live`, `vote.pick`),
  `Remotes` (`CastPick`, `RerollDraft`), `VoteController` (the cards, picks, Y, reroll, preload),
  `UIContract` (Votes.Draft, VoteBanner.Reroll).
* Homes for card effects: `BreachService:SetModifier` (DarkSpawnBonus), `WeaponService:SetModifier`
  (WeaponRarityUp, StaminaMult), `:AddMedkits`, `:Rarities`; `ResidentService:AddLevels`,
  `:AddMorale`; `SurfaceService:SetLootBoost`, `:SetStormEarly`.
* Blueprints as finds: `InventoryService` (`GiveCard`, `CardsHome`, unloading, a handler's card kept
  in the pack, `pack.add Blueprint`), `SurfaceService`, `DeepService`, `DigService` (no longer skip
  them), `ExpeditionService` (`Blueprints`, `BlueprintsHome`), `Rules.Surface` (a card's name in the
  pack), `Rules.Loot` (special names in alerts).
* `ResultsService` (drafted cards in the run's story), `CombatController` (stamina max),
  `Config.DraftCards` (Short, Order), `Config.Tuning` (Draft), `DataTests`.

**Architecture.** VoteService stays the one place votes are decided; DraftService only draws cards
and applies winners, through each owning service's modifier hook (the effects are data:
`Config.DraftCards` modifiers, `Config.Modifiers` naming the system). A card is offered only when its
keys have handlers, so Prompts 23 and 30 bring their cards in by adding handlers.

**Integration notes.**
* The paid Blueprint Reroll (Prompt 28): `DraftService:Reroll(player, "Paid")`.
* Prompt 23: handlers for FloodDrainSpeed and GasStrength bring Sump Pumps and Gas Filters in.
  Prompt 30: AmmoCraftCost and the trader's keys bring Ammo Press and Black Market in; the trader's
  blueprint cards can come home with `DraftService:AddFound(card, by, how)`.
* Class levels (Prompt 20) set `ClassLevel`; the free reroll reads it.

**Testing checklist (Run playtests, 2026-11-09)**
* [x] A real Surge end opened the draft (the tutorial wave's end: Drill Bay, Lab, Training Room).
* [x] A real click picked the Lab; solo, it applied at once; the Armory stayed locked, the Lab built.
* [x] Two pretend voters picked Deep Lamps; with time up it won 2 picks to 0; the found card that
      wasn't picked went back to the pool.
* [x] A controller's Y (simulated) picked the first card.
* [x] A found blueprint as a fourth card with the FOUND stamp and the finder's name; picked when time
      ran out (at random among unpicked cards).
* [x] The Mad Scientist at level 3 had one free reroll: the REROLL button, real click, new cards,
      the timer started over, the button gone.
* [x] Every usable card applied (dev `draft.take`): Reinforced Walls and the Steel Blast Door (the
      door L1 1,250 HP to L2 2,000 HP), Field Training (L1 to L2, Str 10 to 11), Morale Broadcast (67
      to 82), Radio Booster and Veteran Recruit (three newcomers), Armory Shipment (Standard to
      Reinforced, and a new class's kit too), Med Cache (0 to 2), Field Rations (stamina 120), Insulated
      Grid (a blackout 30 s), Deep Lamps (dark vents 1.5), Deep Charges (+7.5 Disturbance a dig),
      Overclock (power 63 to 94.5, 15% each Surge), Bounty Contract (30 kills, +500 Scrap), Salvage
      Rights (the storm 30 clock-seconds early at x10 speed), Lab, Radio Room and Trading Post unlocked.
* [x] A blueprint into the pack on the surface (`pack.add Blueprint`), carried down and unloaded with
      a real E press at the hall: it waited for the next draft and joined it.
* [x] A blueprint found in the bunker went straight to the next draft.
* [x] A surface expedition brought a blueprint home (second try with `exp.cycle`).
* [ ] Not seen: real teammates, touch, a real wheel click on PC, the Overclock overload rolled in a
      real Surge, Sprinklers' slower spread, a blueprint from a real container search (four Showroom
      searches gave none).

**Future extension notes.** Cards are rows in `Config.DraftCards`; a new card needs only its
modifiers' handlers. Event cards and a season's cards can be added the same way.

## Landon's answers to the Prompt 13, 14, 16 and 17 questions (2026-11-09)

Landon answered all 30 open Bible Questions of Prompts 13, 14, 16 and 17 at the start of this
prompt (addenda in those reports). 26 approve what was built. Four changed it, built here:
* **Surge disasters** (Prompt 13, question 4): Surges also bring cave-ins from Era I, and floods and
  gas leaks from Era II. `Config.Disasters` gives CaveIn, Flood and GasLeak a Surge weight and
  "Surges" in their causes; `Rules.Disasters.SurgePick` takes the disasters a service can start, so
  floods and gas leaks join when Prompt 23 starts them; a Surge's cave-in falls in a random doorway.
* **Radiation and death** (Prompt 16, question 6): a respawn keeps half the radiation the last life
  had (`SurfaceService`).
* **Ash Raiders** (Prompt 16, question 7): about a third fight hand to hand
  (`Config.Monsters.AshRaiderMelee`, `Tuning.Surface.RaiderMeleeShare` 0.33), for the town's groups
  and the raider camp's guards. Until the melee raider's own art comes (with A2's pipe), they use the
  rifle raider's model.
* **Ore veins** (Prompt 17, question 2): only a player carrying a Drill or a Pickaxe can mine one
  (`DeepService`); the prompt says so.
