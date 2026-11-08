# 100 Years Of Fallout: ARCHITECTURE

The living map of the code (bible Section 23). Every prompt updates it. The bible wins: if
this document, the code and the bible disagree, the bible is right and the difference is a
bug or a Bible Question.

## Places

| Place | Id | Players | Role |
|---|---|---|---|
| Lobby (start place) | 135073046693952 | 30 | hub, shops, Legends Hall, quests, leaderboards, elevator pads |
| Run (reserved servers) | 72892455946761 | 6 | the bunker, the surface and the Deep |

Both places run the same shared code, bootstraps and infrastructure services. Each adds its
own services and controllers on top (Run: RunDirector, BunkerGrid...; Lobby: PadService,
ClassShopService...). `Constants.PlaceKind()` says which place is running.

## Where code lives (both places)

```
ReplicatedStorage
  Shared                         (Folder) code both sides run
    BuildInfo                    which build is installed; written by the installer
    Constants                    identity and engine limits (never gameplay numbers)
    Types                        types that cross module or network boundaries
    Remotes                      the one list of RemoteEvents + the only API to use them
    RunState                     the run's small values, replicated as attributes on it (Run)
    UIContract                   the parts of the UI layout the code uses (StructureCheck checks them)
    Config                       content aggregator; one child ModuleScript per content type
    Rules                        pure game rules both sides share (Clock, Grid, Bunker, CameraRig, Hud)
    Utilities                    Check, Delta, Loader, Log, RateLimit, Signal, TableUtil, Trove
ServerScriptService
  Bootstrap                      (Script) the only server script
  Services                       one ModuleScript per service
  Lib                            server-only modules that aren't services (ProfileSchema; Run: BunkerKit)
  DevTools                       StructureCheck, DataTests (+ Invoke in Studio playtests)
StarterPlayer.StarterPlayerScripts
  ClientBootstrap                (LocalScript) the only client script
  Controllers                    one ModuleScript per controller
  Lib                            client-only modules that aren't controllers (Fade, KitRuntime, UIKit, UISamples)
StarterGui
  Reticle                        the aim sight (built in Studio, studio/ui/Reticle.lua)
  Frame                          The Frame, the one menu layout (both places; studio/ui/Frame.lua)
  HUD                            the run HUD (Run; studio/ui/HUD.lua)
ServerStorage
  Documentation.ARCHITECTURE     this document
  Assets                         models from the art pipeline (Run)
  ArtPipeline.AssetSetup         art pipeline helper (Run; not game code)
```

Rules: only the two bootstraps are scripts; everything else is a ModuleScript. No `_G`, no
`shared`: modules `require` each other. Server-only code never goes in ReplicatedStorage.
Objects named `A0_...` (showroom, sample screens) are art-pipeline samples, allowed until
gameplay replaces them; the A0 sample screens now sit in `ServerStorage.UIArchive` (Run).

## Where code comes from

The source of truth is the repo `landonhjones2020-bit/100years-assets`, folder `game/`
(Rojo naming: `init.luau` makes the folder a module, `.server.luau` is a Script,
`.client.luau` a LocalScript). `game/shared`, `game/server`, `game/client` and `game/docs`
go to both places; `game/places/<Place>/...` only to that place.

`tools/game_sync.py build` turns the tree into one Model asset (`exports/Code/GameCode.rbxmx`,
holding a Lobby and a Run variant), which is uploaded through Open Cloud like the art and
installed into each place by the Luau that `tools/game_sync.py install <assetId> <Place>`
prints. The install replaces the managed folders wholesale and refuses to run if a script was
edited in Studio since the last install (StructureCheck's Sources check), so nothing written
in Studio is lost: bring such edits back into the repo first.

## Lifecycle

Server: `Bootstrap` → `Remotes.Setup()` → `Loader.Collect(Services)` → every `Init` in
dependency order → every `Start` on its own thread → `ReplicatedStorage` attributes
`PlaceKind`, `Build`, `ServerReady` (and `ServerBroken` if a service failed).

Client: `ClientBootstrap` → every controller's `Init`, then `Start` → waits for `ServerReady`
→ fires `ClientReady` → the server marks the session ready and sends the snapshot.

## Writing a service or controller

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Utilities.Log)

local log = Log.new("CycleClock")

local CycleClock = {
	Name = "CycleClock",                 -- must equal the ModuleScript name
	Dependencies = { "DevService" },    -- only these can be read from the registry
}

function CycleClock:Init(registry)     -- wire up: remotes, signals, dev commands. No loops.
	registry.DevService:Register("year", { Description = "...", Run = function(player, args) ... end })
end

function CycleClock:Start()            -- runs after every Init: loops, timers, world state
end

return CycleClock
```

* Top-level code in a module has no side effects (StructureCheck requires modules at edit
  time to validate them). Do the work in `Init` and `Start`.
* `Init` must not yield or loop; it is timed and anything over 0.5 s is reported.
* A module whose `Init` errors is reported; modules depending on it are skipped, and the
  server sets `ServerBroken`.
* Talk across modules through methods and Signals the other module exposes, never by
  reaching into its internals.

## Networking

* Every RemoteEvent is an entry in `Shared.Remotes` (`To`, `Args`, `Rate`, `Doc`, and `Place`
  for remotes only one place has). Nothing else creates remotes; StructureCheck flags any that
  appear elsewhere.
* Clients send intentions (propose this room, fire at this point), never results. Each
  client → server remote checks every argument (`Utilities.Check`: finite numbers, valid
  UTF-8, lists without holes, shapes without unknown fields) and rate-limits each player
  before its handler runs. Handlers still check ownership, ranges and game state.
* Small values (year, resources, cycle phase) replicate as attributes.
* Collections (rooms, residents, votes...) go through the delta channel:
  `ReplicationService:Collection("Rooms")` with `Set`, `Patch`, `Remove`, `Clear` on the
  server, `ReplicaController:Get/All/Changed` on the client. Changes are batched and sent
  `Constants.DELTA_HZ` times a second; a player gets a snapshot when their session becomes
  ready. Values must be remote-safe (`Delta.IsRemoteSafe`): lists or string-keyed tables,
  finite numbers, no Instances, no functions. Per-player collections pass `Visible`.

## The run (Run place)

`RunDirector` owns the lifecycle and how a run ends; `CycleClock` owns cycles, phases, the year
counter, Years per Cycle and skips; `ObjectiveService` keeps the Lost Crews rescued and era
bosses beaten (bible Sections 4, 5 and 23). The century's arithmetic is `Shared.Rules.Clock`,
pure functions the data tests hold to the bible.

```
Waiting --first player ready--> Intro (30 s) --> Playing --> Ended --Keep Going--> Playing (Endless)
                                                    |  Day 3:00 (siren at 2:40) -> Surge 1:30 -> year jump -> next Day
```

* The run clock starts at the 30-second mark for everyone; skipping the cutscene is personal.
* Years per Cycle = 1 + the `YearsPerCycle` of every objective done (`Config.Objectives`: +2 a
  Lost Crew, +1 an era boss), at most 12. The year jumps at the end of each cycle.
* A jump that reaches or passes 25, 50 or 75 makes that era's boss the next Surge (once, unless
  already beaten). At 100 the year stops and the next Surge is the final one (the Source); when
  it ends the clock halts and RunDirector declares a Century Victory.
* Surges end when their time is up, or earlier through `CycleClock:EndSurge()` (ThreatDirector,
  when the last monster is dead and the disaster fixed). A boss Surge (an era boss or the final
  Surge) has no timer (`PhaseOpen`) and ignores EndSurge: it ends when its boss is beaten,
  `ObjectiveService:BossBeaten(bossId)` -> `BossDefeated` (Landon, 2026-11-08).
* Skips: when every player in the run has pressed Ready (`SetReady` remote) or rests in a
  Quarters bed (`CycleClock:SetResting`), the day jumps to the siren. Both count only during a
  day before the siren and both reset at the siren (Landon, 2026-11-08).
* Keep Going after any victory, even an early Deep Victory, starts Endless at once (Landon).
* Defeat: `RunDirector:Lose("ReactorDestroyed" | "ResidentsLost")`; Deep Victory:
  `RunDirector:Win("Deep")`; Keep Going: `RunDirector:KeepGoing()` (no more era bosses or year
  cap, Endless Surges). The results screen reads `RunDirector:Summary()`.
* Signals for other systems: `CycleClock.CycleStarted` (residents eat and drink), `YearChanged`
  (aging), `EraChanged`, `SirenStarted`, `SurgeStarted`, `SurgeEnded` (the blueprint draft),
  `Skipped`; `RunDirector.PhaseChanged`, `RunEnded`; `ObjectiveService.Changed`.

**RunState** (`Shared.RunState`): the run's small values, replicated as attributes on that
ModuleScript. Each has one writer, which gets a setter from `RunState.Writer(name)`; anyone
reads `RunState.Get`, `RunState.Changed`, `RunState.TimeLeft()` (times are server time, so
every client counts down to the same moment).

| Writer | Values |
|---|---|
| RunDirector | RunPhase, IntroEndsAt, Difficulty, Outcome, DefeatReason, Victory, Endless |
| CycleClock | Cycle, Year, Era, YearsPerCycle, CyclePhase, PhaseLength, PhaseEndsAt, PhaseLeft, PhaseOpen, Siren, SurgeKind, SurgeBoss, ReadyCount, ReadyNeeded, Paused, TimeScale |
| ObjectiveService | LostCrews, BossesBeaten |

Players carry `Ready` and `Resting` attributes (CycleClock). In Studio, set the attribute
`SkipIntro` on `ServerScriptService.DevTools` to true to start runs without the 30 s intro.

## The bunker (Run place)

`BunkerGrid` holds the run's bunker (bible Section 6): the data and rules are
`Shared.Rules.Bunker`, the geometry `Shared.Rules.Grid`, and `Lib.BunkerKit` builds the world.

* Cells: columns -6 to 6, floors 1 to 10 (the depth; floor 10 is the Source Chamber). Every cell
  is Rock, Dug or part of a room. Rooms are 1 to 3 cells side by side on one floor.
* Rules (Rules.Bunker): dig a Rock cell left of, right of or below an open cell; place a room
  on Dug cells (MaxCells, Unique, a room's own Floor, never in the Source Chamber); merge two
  matching rooms of one level side by side (never different levels); Fixed rooms (Blast Door,
  Reactor Core) never merge or go; levels 1 to 3. HP is per cell: `Tuning.Rooms.HP[level]`
  times the cells (Landon, 2026-11-08); a merged room keeps both rooms' HP. Votes, costs,
  build and dig times come from BuildService and DigService.
* The room graph: a node per room (`R3`) and per Dug cell (`D:2,3`); edges through doorways
  (side-by-side open cells of different units) and between stacked Shafts. A dug cell is a step
  when power counts steps from a Reactor Core or a Generator (Landon, 2026-11-08).
* The run starts with `Tuning.StartingBunker`: floor 1 Blast Door (2 cells), Shaft, Quarters
  (2 cells), a dug cell; floor 2 Kitchen, Water Purifier, Shaft, Reactor Core, Medbay, a dug
  cell; the Shafts in column 0, rock at column -3 (the bible's diagram).
* World (Rules.Grid): `Tuning.Grid.Origin` is the interior floor centre of floor 1, column 0
  (0, -120, 0). Cells repeat every 34 studs along +X and 18 down; the front, where the Command
  View camera sits, faces +Z. Art models face -Z: place them with `Grid.CellCFrame`.
* `workspace.Bunker` (built at server start, rebuilt around each change) from the A1 art in
  `ServerStorage.Assets.Kit` and `.Rooms`, each piece falling back to the Prompt 4 graybox when
  missing: `Frame` (a ring of rock cells), `Rock` (models named by cell key), `Dug` (models
  `D:<key>`), `Rooms` (models named by room id, with RoomId, RoomType, Floor, Column, Span,
  Level and Art attributes). Every unit is Persistent. Players spawn in the Medbay; the place's
  other spawns are disabled when the server starts.
* Tags: `FrontWall` (front wall parts: hidden in the Command View), `CameraFade` (furniture,
  the Blast Door set, the stair, vents, lamps, cave props: the camera passes through and fades
  them), `RoomLight` (PointLights, with a `Unit` attribute, for the power system). Floors,
  walls, ceilings and rock stop the camera.
* Gameplay points: each room's `Sockets` part holds an Attachment per socket of its art
  (WorkSpot1.., Bed1.., Seat1.., Core, Valve1.., FuseBox, Breaker, Tap, Bench, Respawn, Door,
  SurfaceExit, Vent, Lift, Chute, Top, Bottom, Light1..), numbered across the room's cells.
  Read them with `BunkerKit.Socket(model, name)` and `BunkerKit.Sockets(model, pattern)`.
* Replication: the `Cells` collection (`"floor,column"` -> `{ Room = id }`, `{}` when Dug) and
  the `Rooms` collection (id -> Type, Floor, Column, Span, Level, HP, MaxHP).

## The camera and input (both places)

`InputController` turns PC, touch and gamepad input into actions; `CameraController` is the
over-the-shoulder camera (bible Section 9); `Lib.Fade` makes world parts see-through on this
client only. The camera's geometry is `Shared.Rules.CameraRig`, its numbers `Tuning.Camera`.

* Actions follow the bible's controls table (`BINDINGS` in InputController). Listen with
  `InputController:On(action, began, ended)`; HUD touch buttons join with
  `BindButton(action, button)`. Moving and jumping stay Roblox's.
* Right shoulder by default; `SwapShoulder` (V, right stick click) swaps. `Aim` (right mouse,
  left trigger; Run place only) narrows the view 70 to 50, brings the camera in, slows walking
  and turns the character with the camera.
* Zoom caps: the wheel or a pinch zooms between `Distance.Min` and `Distance.Max`, at most
  `IndoorMax` in a bunker cell. A spherecast from the shoulder stops the camera at floors, walls,
  ceilings and rock (in at once, out gently); in a cell it also stays between the floor and the
  ceiling panels (not in a Shaft, which is open overhead).
* Wall fade: `FrontWall` and `CameraFade` parts never stop the camera and fade while they hide
  the character or touch the camera; characters and `CameraIgnore` are passed through. The
  local character fades when the camera reaches its head.
* PC: the mouse is locked to the centre and `StarterGui.Reticle` shows the sight.
  `CameraController:FreeCursor(reason, true)` frees it for menus; `Suspend(reason)` and
  `Resume(reason)` hand the camera to another view (Command View, cutscenes).
* Fallback: repeated errors stop the controller and give the camera to Roblox's, set to
  Invisicam in both places (`StarterPlayer.DevCameraOcclusionMode`); `EnableMouseLockOption` is
  off. StructureCheck checks both settings and the Reticle.

## The UI (both places)

Bible Section 18. The layout is real instances in StarterGui, built through the Studio
connector by `studio/ui/*.lua` (`python3 tools/ui_luau.py studio/ui/<Screen>.lua` prints the
Luau; send it with `execute_luau`, Edit) and then given Landon's AutoScale Lite pass. Code
never builds layout: it clones templates and sets text and images.

* `Shared.UIContract` lists every part of `StarterGui.Frame` and `StarterGui.HUD` the code
  uses. StructureCheck fails if one is missing, and also checks ScreenInsets
  CoreUISafeInsets, ResetOnSpawn off, ZIndexBehavior Sibling, Scale-only sizes, TextScaled
  text with a UITextSizeConstraint of at least 12, and no scripts inside a GUI.
* `Lib.UIKit` is generated from `ui/kit.json` by `tools/pack_ui.py` (the sprite table).
  `Lib.KitRuntime.Watch(gui)` keeps 9-slice corners, strokes and scroll bars in step with the
  screen height and runs the push-buttons (RectUp/RectDown/RectHover/RectDisabled attributes).
* `UIController` is The Frame: `Register(name, screen)`, `Open(name, args)`, `Close()`,
  `SetChips`, `SetMainAction`, `SetHint`, `SetFooterActions`, `Clone(template)`,
  `SetSprite`, `SetRarity`, `Clear`. A screen is a page (a clone of `Templates.Page`, or a page
  built for it under `Cabinet.Pages`) filling zones B, C and D; `Docked = true` is the Command
  View's mode (zone C shows the world). While a screen is open the cursor is free, gameplay
  input is blocked (`InputController:Block`) and the HUD hides. Backspace or B closes; Enter
  or Y presses the main action; L1 and R1 switch tabs.
* `HUDController` fills the run HUD: the year flip counter, era, cycle dial, phase and time
  left, Ready (the SetReady remote), siren and Surge banners, health, the class and ability,
  stockpile chips, the hotbar's selection, the Command View button and the touch buttons
  (through `InputController:BindButton`; Roblox's jump button hides while ours shows). On PC,
  holding Left Alt frees the cursor to click HUD buttons. For later systems: `Alert`,
  `Banner`, `SetVital`, `SetClass`, `SetResource`, `SetSlot`, `HotbarSelected`.
* `MiniMapController` draws the side-view mini-map around the player from the Cells and Rooms
  collections; `Blink(key, on)` for alerts.
* Changing a screen after Landon's AutoScale Lite pass: edit the instances in place (and the
  builder file to match), or rebuild and ask for the pass again.

## Saved data

One profile per player (bible Section 23), shape and migrations in `Lib.ProfileSchema`, I/O in
`ProfileService`. The stored record is `{ Data, Lock, Meta }` in the `PlayerProfiles` DataStore
(`PlayerProfiles_Studio` in Studio, so tests never touch live saves), key `Player_<userId>`.

* Load claims the lock through UpdateAsync. A fresh lock from another server: wait and retry
  (8 tries, 2 s apart), then kick with a message. A stale lock (3 autosaves old; 30 s in
  Studio): taken over. A newer version: refused, nothing written. Then migrate, reconcile,
  validate; a failure kicks the player and writes nothing.
* Saves: every 120 s (staggered; refreshes the lock), on leaving (releases it) and on
  shutdown (BindToClose waits for every release). A save writes only if this server still
  holds the lock and the profile validates; losing the lock kicks the player.
* Gameplay calls `ProfileService:Update(player, fn)` (undone if it errors or leaves the profile
  invalid), `AddGlowshards`, `SpendGlowshards`, and `GrantPurchase(player, receiptId, grant)`
  for ProcessReceipt: grant, record the receipt, save, then report granted; a repeated
  receipt is never granted twice.
* The player's client reads its own profile (minus receipts) from the `Profiles` collection.
* A session isn't ready until its profile loads (SessionService gate `Profile`).
* Changing the shape: raise `ProfileSchema.VERSION`, add a migration, update `Default` and the
  shape. Old servers refuse newer saves, so a rolling update can't corrupt them.

## Content

All content is data in `Shared.Config` (bible Section 23). Each content type is a child
ModuleScript returning `{ Schema = Check.shape(...), Entries = { Id = entry }, Order = {...}? }`
(or `Schemas`, one checker per entry, for Tuning). Config validates every entry at load
(fields, ids, `Check.ref` cross-references), freezes it and adds `Id`. Read with
`Config.Get(type, id)` (errors if missing), `Config.Find` (for ids from players or saves),
`Config.All(type)`, `Config.Ids(type)`. Problems are listed by `Config.Errors()`, logged, and
fail StructureCheck and the data tests. `Config._Fields` holds checkers the content modules
share (modules starting with `_` are helpers, not types).

Content types (Prompt 1): Badges, Bosses, Classes, Conditions, DepthBands, DigResults,
Difficulties, Disasters, DraftCards, Eras, GamePasses, GlowshardPacks, GlowshardRewards,
ItemRarities, Items, Leaderboards, Legends, LootTables, Modifiers, MoraleStates, Monsters,
Objectives, Quests, Recipes, ResidentNames, Resources, Rooms, Stats, SurfaceLocations,
TalentSlots, TeamBoosts, Tiers, Traits, Tuning, Votes, WandererOutcomes.

**Effects are data.** Classes, traits, Legends, draft cards and passes describe what they do
as modifiers: `{ Key = "RoomOutput", Value = 1.25, Room = "Medbay", Scope = "Bunker" }`.
`Config.Modifiers` is the vocabulary: each key's unit (Multiplier, Add, Set, Flag, Chance),
default scope, and the prompt whose system applies it. A system reads the keys it owns; a new
effect is a new key plus the code that honours it.

**Rule numbers** live in `Config.Tuning`, one entry per system (Clock, Grid, StartingBunker,
Rooms, Votes, Player, Digging, Disturbance, Threat, Residents, Aging, Morale, Trader,
Wanderers, Expeditions, Surface, Legends, ClassShop, Account, Lobby).

## DevTools

* `/dev <command>` in chat for allowed players (everyone in Studio; outside Studio only the
  admins in `Constants.ADMIN_USER_IDS`); `/dev help` lists commands. Services add their own
  in `Init` with `DevService:Register`.
* In a Studio playtest: `ServerScriptService.DevTools.Invoke:Invoke("test")` on the server,
  `PlayerScripts.DevInvoke:Invoke("replica Rooms")` on a client.
* `structure`: StructureCheck. `test [filter]`: DataTests. Both run once whenever a Studio
  playtest starts (set the `RunChecksOnStart` attribute on DevTools to false to stop that).
* Other built-ins: `version`, `ping`, `players`, `remotes`, `log [level]`, `logs [count]`,
  `rep`, `rep.selftest`; on the client `replica <collection>`, `client`, `clock`,
  `ready [true|false]` (fires SetReady like the HUD button), `camera`, `camera.shoulder`,
  `camera.aim [bool]`, `camera.look <yaw> <pitch>`, `camera.zoom <studs>`, `camera.cursor`,
  `ui`, `ui.sample`, `ui.list`, `ui.dock`, `ui.open <screen>`, `ui.close`, `ui.tab <id>`,
  `ui.main`, `hud`, `hud.alert <Danger|Warning|Info> <text>`, `hud.banner <text>`,
  `hud.slot <n>`, `hud.touch [bool]`.
* The bunker (Run place): `grid` (map), `grid.rooms`, `grid.graph`, `grid.dig <floor> <column>`,
  `grid.build <Type> <floor> <column> [span] [level]`, `grid.remove <id>`, `grid.merge <id> <id>`,
  `grid.level <id> <level>`, `grid.rebuild`, `grid.sockets <id>`, `grid.art`.
* The run (Run place): `run`, `run.skipintro`, `run.win <century|deep>`,
  `run.lose <reactor|residents>`, `run.keepgoing`; `clock`, `clock.speed <x>`, `clock.pause`,
  `clock.resume`, `clock.next`, `clock.clear`, `boss.beat [bossId]`, `year <n>`,
  `ready.all [bool]`, `rest.all [bool]`; `objectives`, `objective <id>`.

## Conventions

* `--!strict` in every file. Tabs. PascalCase for modules, types, methods and content ids;
  camelCase for locals. Content ids: letters, digits and `_`, starting with a letter.
* Logging through `Utilities.Log` (`Log.new("Tag")`), never bare `print`.
* Tunables are content (Config); identity and engine limits are `Constants`.
* Every prompt ends with Design Notes and a Delivery Report in `game/reports/`.

## Services and controllers

| Place | Name | Kind | Depends on | Owns |
|---|---|---|---|---|
| both | SessionService | service | | player sessions: gates (client ready, profile loaded), ready, leaving |
| both | DevService | service | | DevTools commands and permission |
| both | ReplicationService | service | SessionService, DevService | the delta channel (server) |
| both | ProfileService | service | SessionService, ReplicationService, DevService | saved data: session-locked profiles, Glowshards, purchase receipts |
| Run | ObjectiveService | service | DevService | Lost Crews rescued, era bosses beaten, their Years per Cycle bonuses |
| Run | CycleClock | service | SessionService, ObjectiveService, DevService | 4:30 cycles, day and Surge phases, the year counter, Years per Cycle, skips |
| Run | RunDirector | service | SessionService, CycleClock, DevService | the run's lifecycle (intro, playing, ended), win and lose, Endless, the summary |
| Run | BunkerGrid | service | ReplicationService, DevService | cells, rooms, levels, merges, the room graph; builds `workspace.Bunker` |
| both | ReplicaController | controller | | the delta channel mirror (client) |
| both | InputController | controller | | devices, the bible's action bindings, look and zoom input |
| both | CameraController | controller | InputController, ReplicaController | the over-the-shoulder camera: shoulder, aim, zoom caps, wall fade, the mouse lock and reticle |
| both | UIController | controller | InputController, CameraController | The Frame: screens, pages, tabs, chips, the main action, footer |
| both | HUDController | controller | InputController, UIController, CameraController | the run HUD (Run; nothing in the Lobby yet) |
| both | MiniMapController | controller | ReplicaController, HUDController | the HUD's side-view mini-map (Run) |
| both | DevController | controller | ReplicaController, InputController, CameraController, UIController, HUDController | `/dev` chat command, Studio DevInvoke |

## Prompt log

* **Prompt 0 (2026-11-08)**: architecture foundation in both places. Shared modules, Config
  aggregator, remotes with validation and rate limits, the delta channel, bootstraps with
  declared dependencies, DevTools, this document. No gameplay.
* **Prompt 1 (2026-11-08)**: content definitions. 36 content types with schemas and the
  bible's starter data (provisional numbers marked), the modifier vocabulary, Tuning for
  every system, and data tests that hold the content to the bible.
* **Prompt 2 (2026-11-08)**: saved data. ProfileService with session locks, migrations,
  autosave, release and shutdown saves, purchase receipts; SessionService gates.
* **Prompt 3 (2026-11-08)**: the run lifecycle and the cycle clock (Run place). RunDirector,
  CycleClock, ObjectiveService, Shared.Rules.Clock, Shared.RunState, the SetReady remote,
  place-only remotes and code (`game/places/Run`); win and lose stubs for later prompts.
* **Prompt 4 (2026-11-08)**: the bunker grid (Run place). BunkerGrid, Rules.Grid, Rules.Bunker,
  Lib.BunkerKit (graybox kit), the starting bunker centred on the Shaft column as the bible's
  diagram draws it, the Cells and Rooms collections, spawning in the Medbay.
* **A1 in the bunker (2026-11-08)**: BunkerKit builds from the art kit (graybox fallback per
  piece), a Sockets part per room, room lights, vents, the frame as rock cells.
* **Prompt 5 (2026-11-08)**: the over-the-shoulder camera with wall fade and zoom caps
  (CameraController, InputController, Lib.Fade, Rules.CameraRig, StarterGui.Reticle) in both
  places. Landon's answers to the Prompt 3 and 4 questions: boss Surges and the final Surge run
  until the boss is beaten, resting resets at the siren, HP per cell, dug cells count as power
  steps.
* **Prompt 6 (2026-11-08)**: The Frame and the HUD skeleton, ready for the AutoScale Lite pass.
  StarterGui.Frame (both places) and StarterGui.HUD (Run) built from the UI kit; UIController,
  HUDController, MiniMapController, Lib.KitRuntime, Lib.UIKit, Lib.UISamples (dev samples),
  Shared.UIContract, Rules.Hud; a HUD atlas (touch buttons, action icons, copper and crystal).
