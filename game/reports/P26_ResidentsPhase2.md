# Prompt 26: Residents, phase 2 (traits, gear, conditions, morale's bottom)

Bible Section 11. Build `p26-1cd0910` (code asset 95026446991297, revision 122), installed in the
Run and Lobby places on 2026-11-12: StructureCheck 0 errors (Run 580 checks, Lobby 356), 133 data
tests. Captures: `previews/Game/P26_PersonnelFile.jpg`, `P26_GearSlots.jpg`.

Landon asked at 12:59 to finish testing and wrap up, so this report says plainly what was played
and what was not.

## Design Notes

What the bible says and what I had to decide. Every number below marked "prov." is in
`Config.Tuning` (`Residents`, `Morale`) or `Config.Traits` and waits for Landon.

1. **Traits (two each).** `Config.Traits` has 30 rows since Prompt 1. A Common (and a founder)
   rolls one good and one bad; a Rare rolls two good. The bible's other form for a Rare ("one good
   with higher stats") is not built (question 1). A Legendary's signature trait is Prompt 27.
2. **What each trait does now.** Traits act through the same `Config.Modifiers` keys as classes
   and draft cards (`Rules.Residents.Trait`, `Has`):
   * output: Hard Worker, Lazy, Green Thumb, Steady Hands, Strong Back (their own work, by room),
     Natural Leader (everyone in their room), Lucky (10% of cycles at double output);
   * body: Tough and Frail (max health), Iron Stomach and Glutton (meals eaten), Sleepyhead (rest),
     Hardy (half gas damage, half radiation);
   * morale: Chatterbox and Grumpy (roommates, +3 and -3 a cycle), Night Vision (no dark-room
     penalty), Afraid of the Dark (-15 in a dark room, and they refuse to work there), Claustrophobic
     (-4 a cycle on floor 4 and below), Homesick (-2 a cycle while the bunker has no working Lounge);
   * danger: Brave (fights bare-handed in their room, never panics), Cool Head (never panics, and
     the panicked in their room calm in half the time), Coward and Jumpy (panic two and three times
     as long), Sharpshooter (gun damage), Firefighter (three times the weight when a room's fire is
     fought);
   * the rest: Scrounger (+5 Scrap a cycle and expedition Scrap), Fast Learner (experience),
     Tinkerer (mends their room, as a Wrench does), Clumsy (4% a cycle: a half-strength fire or a
     small flood in their room), and the expedition modifiers (loot, Scrap, carry) of Lucky,
     Scrounger and Strong Back.
3. **Traits that wait for their system** (rows exist, nothing reads them yet): Tinkerer's Workshop
   speed (crafting, Prompt 30), Hothead and anything about rivals or grief (phase 3, Prompt 36),
   Jumpy's "may run into hazards", Coward's "flees breaches" beyond the longer panic, Firefighter's
   "fire spreads slower from their room".
4. **Gear has three slots and lives in a gear locker.** The bible names the slots and the pieces
   but not where gear is kept or how it is handed out. I made one bunker-wide **gear locker**
   (the `Gear` replication collection). Found gear goes into it, a resident's card takes from it,
   and what a resident wore goes back. No room or walk is involved (question 2).
5. **Where gear comes from.** The loot tables already had `Gear` lines (surface containers, raiders,
   caches, nests, the Deep's finds, expeditions) that nothing handed out. Each is now one piece
   from `Tuning.Residents.GearPool` (14 items: the six outfits, the five tools, Lead Pipe, Pocket
   Pistol, Service Revolver); an outfit rolls Standard 60, Reinforced 30, Prototype 10 (prov.).
   Players' finds announce on the HUD; an expedition's gear comes home with its other finds.
6. **What gear does.** Outfit: +1, +2 or +3 to its stat by rarity (never past 15), the Security
   Vest +20 health as well, the Hazmat Suit ignores gas. Tool: +20% to its holder's work in its room
   (Stethoscope Medbay, Hand Drill Drill Bay, Radio Headset Radio Room, Ladle Kitchen; prov.); the
   Wrench mends 15 HP of their room a cycle (prov.). Weapon: "armed residents defend their room",
   so anyone armed (or Brave) fights the nearest monster in the room they are in while the rest
   flee. A gun takes 1 Ammo a shot from the shared pool (the bible's words); with the pool empty
   they use their hands and the HUD says the guns are empty. This also applies to the Warden's
   rallied residents from Prompt 20, who used no Ammo before.
7. **Conditions.** Injured: below 35% health while standing, and after any revive; 60% output
   (`Config.Conditions`); cleared by a crewed, powered Medbay at the next cycle or by healing past
   75% (prov.). Panicked: set while fleeing monsters and for 12 s after (prov.); no work while it
   lasts. Sick, Irradiated and Exhausted are unchanged from Prompts 10 and 24.
8. **Morale's bottom** (the bible: "may refuse work, start fights or leave the bunker for good").
   Each cycle a Miserable resident (morale under 20): after 3 cycles at the bottom, 25% leave for
   good; otherwise 15% start a fight with a roommate (10 damage each, the other -5 morale);
   otherwise 40% refuse work that cycle (no output, no experience). All prov. Someone who leaves
   is recorded as having left, not died (run log, results story); their gear stays in the locker.
9. **Gear and death.** A resident who dies in the bunker leaves their gear in the locker; one lost
   on an expedition takes it with them (question 9).
10. **The resident card became a personnel file.** The kit's detail panel gave half its height to
    the portrait, which left two lines of the file in view once traits and gear were added. On the
    Residents page only, the photo sits small at the top left with the name, level, age and rarity
    beside it, and the file below scrolls: Job, Stats (an outfit's bonus shows as "Smarts 6 +2"),
    Needs (with every condition), Traits, Gear, Experience, Run log. Gear is three teal slot
    buttons in the card; a press fits the next piece in the locker that suits the slot, and after
    the last takes the piece off. Every line of the file is one text size now.

Suggestions (not built, for Landon to accept or drop):

* A GEAR tab on the Residents screen showing the locker as item cards with their icons, so a piece
  is picked, not cycled to.
* A speech bubble or a small icon over a resident who is Panicked, Injured or refusing work (the
  bible's speech bubbles are not built yet).

## Delivery Report

### What changed

| Area | Files |
| --- | --- |
| Rules | `shared/Rules/Residents.luau`: `Trait`, `Has`, `RollTraits`, `Piece`, `PieceKey`, `PieceName`, `Slot`, `OutfitBonus`, `EffectiveStats`, `ToolBonus`, `Repairs`, `InjuredAt`, `Recovered`, `PanicSeconds`, `RollGear`, `MaxHealthOf`, `FoodUse`, `GasTaken`, `Working`, `Miserable`, `LEFT`; `Roll`, `Crew`, `Cycle` and `AddXP` take traits, gear and conditions |
| Tuning | `shared/Config/Tuning.luau`: `Morale.AfraidOfDark`, `Claustrophobic`, `ClaustrophobicFloor`, `Homesick`, `Miserable`; `Residents.ToolRooms`, `ToolOutput`, `RepairTools`, `RepairPerCycle`, `GearPool`, `GearRarity`, `InjuredBelow`, `InjuredClearAt`, `PanicSeconds`, `CalmedMultiplier` |
| Server | `ResidentService` (the locker, `AddGear`, `FindGear`, `Equip`, `Panic`, the cycle's trait and morale events, the `EquipResident` remote, `Accident` signal), `ResidentBrain` (armed and Brave fight, panic, Ammo), `EconomyService:Use`, `DisasterService` (gas and radiation by trait and outfit, Clumsy accidents, Firefighter), `ExpeditionService` (traits and outfits on a team, gear home), `InventoryService`, `SurfaceService`, `DeepService`, `DigService` (gear handed out), `ResultsService` (left, not died) |
| Remote | `EquipResident(id, slot, piece)` to the server, Run place, rate limited |
| Client | `client/Controllers/ResidentsController.luau`: the personnel-file card, the gear slots |
| Dev commands | `gear`, `gear.add <piece or random> [count]`, `resident.equip <id> <Weapon or Outfit or Tool> <piece or none>`, `resident.trait <id> <Trait> [Trait]`, `resident.morale <id or all> <0-100> [cycles low]`, `pack.add Gear <n>` |
| Data tests | one new test (about 90 checks): trait rolls by tier, each trait's arithmetic, slots, outfit bonuses and the stat cap, tools, found gear, Injured, Panicked, the cycle's morale terms, the three Miserable outcomes |

### Tested in Studio (Run place, three playtests, one player, god mode on)

| What | Result |
| --- | --- |
| Start of a run | Six founders each rolled one good and one bad trait; no warnings or errors in the console in any playtest |
| Outfit | A Reinforced Lab Coat took Water from 8.8 to 10.4 a cycle (Smarts 11 to 13); a Security Vest took a resident from 142 to 168 health (Grit +1, +20) |
| Tool | A Ladle took the Kitchen from 11.4 to 13.2 Food a cycle; a Wrench mended the Medbay from 300 to 345 HP over three cycles |
| Natural Leader, Homesick, Glutton, Scrounger | The Kitchen's pair made 10% more with the leader in the room; the Homesick founder sat 2 morale under the rest; six residents ate 7 Food with a Glutton; Scrap rose 5 at the cycle with a Scrounger |
| Locker rules | Wrong slot, a piece not in the locker and an unknown resident were each refused with their reason; a Medkit is "not a resident's gear" |
| Found gear | `pack.add Gear` (the same path a container's loot takes) put pieces in the locker and announced them |
| The card | Opened on the personnel-file layout; real mouse clicks on OUTFIT and WEAPON swapped a Lab Coat for a Security Vest (health 106 to 132, "Grit 6 +1") and fitted a Pocket Pistol; the old piece went back to the locker; the card kept its scroll position |
| Injured | 21 of 76 health set Injured and cut that worker's output to 60%; a crewed Medbay cleared it at the next cycle and healed 20 a cycle |
| Armed and Brave | A Hollow Miner spawned in the Quarters: the Brave resident (bare hands), one with a Lead Pipe and one with a Service Revolver fought it and killed it in about 7 s; the other three fled and were Panicked; Ammo went from 200 to 195 |
| A lone Burrow Tick | Still swatted by everyone in the room, as before |
| Morale's bottom | Two residents left for good after cycles at the bottom (their names announced, the roster down by two); one refused work three cycles running; a fight showed as 10 health off two roommates |

### Not tested

* The last build's two small changes (no experience while refusing work, larger section labels on
  the card) were installed and passed the checks but were not played again.
* Two or more players, a phone, a gamepad on the gear buttons.
* A real surface container, cache or nest giving gear, and an expedition bringing gear home (only
  the shared hand-out path was played).
* A Clumsy accident (4% a cycle never came up), Afraid of the Dark in a dark room, Claustrophobic
  on floor 4, Hardy or a Hazmat Suit in gas, radiation, Sharpshooter, Firefighter, Lucky, Cool Head
  calming a roommate, residents' guns with the Ammo pool empty, gear returning to the locker at a
  death. Their arithmetic is in the data test; their wiring was not seen in play.
* A fight's HUD line and console line (the console line was added after the fight was seen only by
  its damage).

### Seen while testing, not changed

* **An undefended Tutorial Surge is deadly.** With the player standing still, a Spitter Grub and
  two Burrow Ticks killed four of six founders in 90 seconds: two Ticks make a room flee, the Ticks
  stay latched to a fleeing resident, and everyone keeps fleeing. This is Prompt 12's behaviour,
  not new, but a new player's first Surge should not go this way (question 12).
* **Armed residents hit hard.** Three residents ended a 206-health Hollow Miner in about 7 s.

## Bible Questions

1. Rares: the bible says "two good, or one good with higher stats". Only "two good" is built.
   Do you want the second form, and how much higher should the stats be?
2. The gear locker: one bunker-wide store, used from a resident's card anywhere. Should gear live
   in a room instead (the Armory or Storage), or need a player beside the resident?
3. Found gear: one piece from 14, outfits at Standard 60%, Reinforced 30%, Prototype 10%. Right
   pool and odds? Should a resident's weapon or tool have a rarity too?
4. Tools give +20% in their room, and the Wrench mends 15 HP a cycle. Right sizes?
5. Residents' guns take 1 Ammo a shot from the shared pool and fall back to bare hands when it is
   empty. Should a resident's gun do a player's full damage (three armed residents killed a Hollow
   Miner in 7 s)?
6. Injured: below 35% health or after a revive, 60% output, cleared by a crewed Medbay at the next
   cycle or by healing past 75%. Right?
7. Panic: 12 s after reaching safety, twice that for a Coward, three times for the Jumpy, half with
   a Cool Head in the room. Right?
8. Morale's bottom: 40% refuse work, 15% start a fight (10 damage each), 25% leave after 3 cycles at
   the bottom. Right odds? Should the team get a warning the cycle before someone leaves?
9. A resident who dies in the bunker leaves their gear in the locker; one lost on an expedition
   takes it with them. Right?
10. Clumsy: a half-strength fire or a small flood in their room, 4% a cycle. Right?
11. Prompt 23's question 8 (the Hardy trait and the gas-proof outfit): built for gas only. Hardy
    halves gas damage, the Hazmat Suit ignores gas, neither helps in a flood. Right?
12. The Tutorial Surge with no one defending killed four of six founders. Should residents with
    two or more Burrow Ticks in the room fight them instead of fleeing, or should the Tutorial
    Surge be gentler?
13. The card's new layout (small photo, name beside it, the file below): keep it, and should the
    other screens' detail panels follow?
