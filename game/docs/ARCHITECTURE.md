# 100 Years Below: ARCHITECTURE

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
    Rules                        pure game rules both sides share (Clock, Grid, Bunker, CameraRig, Hud,
                                 CommandView, Votes, Construction, Economy, Residents, Combat)
    Utilities                    Check, Delta, Loader, Log, RateLimit, Signal, TableUtil, Trove
ServerScriptService
  Bootstrap                      (Script) the only server script
  Services                       one ModuleScript per service
  Lib                            server-only modules that aren't services (ProfileSchema; Run: BunkerKit)
  DevTools                       StructureCheck, DataTests (+ Invoke in Studio playtests)
StarterPlayer.StarterPlayerScripts
  ClientBootstrap                (LocalScript) the only client script
  Controllers                    one ModuleScript per controller
  Lib                            client-only modules that aren't controllers (Fade, KitRuntime, Movement, UIKit, UISamples)
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
  cap, Endless Surges). The results (`ResultsService`, Prompt 15) read `RunDirector:Summary()`
  and `RunEnded`.
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
* Rules (Rules.Bunker): dig a Rock cell left of, right of or below a dug cell or room; place a room
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
  `BindButton(action, button)`. Moving and jumping stay Roblox's. `Block(reason)` stops gameplay
  actions while a screen is open (CommandView is never blocked).
* Roblox marks Tab as processed before ContextActionService sees it begin, so Tab (and the
  gamepad's View button) are also read from UserInputService when processed (no text box
  focused, Roblox's menu closed). `GuiService.AutoSelectGuiEnabled` is off: Roblox would take
  the View button for its own UI selection, and our screens select for the gamepad themselves.
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
  input is blocked (`InputController:Block`) and the HUD hides (its alerts then show in the
  Frame's footer for a few seconds: `UIController:Notice`). Backspace or B closes; Enter or Y
  presses the main action; L1 and R1 switch tabs.
* `HUDController` fills the run HUD: the year flip counter, era, cycle dial, phase and time
  left, Ready (the SetReady remote), siren and Surge banners, health, the class and ability,
  stockpile chips, the hotbar's selection, the Command View button and the touch buttons
  (through `InputController:BindButton`; Roblox's jump button hides while ours shows).
  Landon's answers (2026-11-08): Ready has its own key, Z on PC and D-pad down on console (a
  key chip on the button); on PC a click of the mouse wheel frees the cursor for HUD buttons and
  the vote telegram, and another click locks it again; the stockpile chips show the
  EconomyService amounts (RunState), and the Copper and Crystal chips appear only once the team
  has dug into their bands. Server alerts (the `Alert` remote) go to the alert feed. For later
  systems: `Alert`, `Banner`, `SetVital`, `SetClass`, `SetResource`, `SetSlot`,
  `HotbarSelected`.
* `MiniMapController` draws the side-view mini-map around the player from the Cells and Rooms
  collections; `Blink(key, on)` for alerts.
* Changing a screen after Landon's AutoScale Lite pass: edit the instances in place (and the
  builder file to match), or rebuild and ask for the pass again. `studio/ui/patches/` holds
  such in-place patches.

## The Command View (Run place)

Bible Section 7. `CommandViewController` registers the screen `CommandView`: the Frame in
docked mode (`Cabinet.Pages.CommandView`, zone C open on the live bunker), opened and closed
by Tab, the View button, the HUD's Command View button, Backspace or B. The character stays
where it was, held by a ContextActionService sink (its movement keys and jump) with Roblox's
touch thumbstick and jump button hidden (`GuiService.TouchControlsEnabled`), and can be hit:
`DamageEdge` flashes when its health drops. Its arithmetic and build-menu rules are
`Shared.Rules.CommandView` (pure, data-tested); numbers in `Tuning.CommandView`.

* Camera: straight at the bunker from +Z, at most `MaxDistance` (440 studs) away. At the
  lowest graphics level Roblox stops drawing parts about 500 studs from the camera (measured in
  Studio, 2026-11-08: 500 drew, 525 didn't; level 2 draws about 800), so the camera never backs
  off past the cap: `Rules.CommandView.Lens(height)` keeps the narrow 8 degree field of view
  while it fits, then widens it (14 degrees at the opening 6 floors, 25 at the 11-floor limit).
  The view's centre sits in zone C's centre; it opens centred on the character with a 0.3 s
  move, and the close moves back and resumes CameraController. `FrontWall` parts hide while it
  is open; the lighting lifts (`Ambient`, `OutdoorAmbient`, `ExposureCompensation`).
* Input: drag or WASD/arrows to pan, the wheel or a pinch to zoom (1.5 to 11 floors), click or
  tap a cell; gamepad: left stick pans, right stick zooms, A picks the centre (`Cursor`).
  Picking casts from the camera through the point onto the cells' plane (`Grid.CellAt`).
* Detail panel (zone D): a room (condition, power, what it does; Upgrade, Merge with a
  matching neighbour, Tear Down), an open cell (the build menu: available rooms with costs,
  then locked ones and why, from `RoomChoice`; Fixed rooms are never listed), rock (whether it
  can be dug, the band's ore, the next band's Push Deeper). Choosing an option arms the main
  action ("Propose ..."), greyed until a system calls `SetHandler(action, fn)` for Build,
  Upgrade, Merge or TearDown (Prompt 8: votes).
* For later systems: `SetOverlay(name, provider)` (Power, Morale, Threat, Production: the
  provider returns a lamp sprite and a short reading per room, shown on the room label and the
  reading chip under it; the legend sits at the top of the panel; Power and Production are
  registered from the `Power` and `Production` collections, Prompt 9),
  `ShowGhost(id, floor, column, span, label)` / `HideGhost(id)` (votes), `Blink(roomId, on)`
  (breaches, disasters), `Select(floor, column)`, `IsOpen`, `Toggle`, `State`, and the
  `Selected` signal. Labels, marks and pings cover cell interiors (`Rules.CommandView.CellBox`).
* Pings: the footer's Ping button or G / D-pad up sends `PingCell(floor, column)`;
  `PingService` checks the session and the cell and fires `CellPinged(floor, column, userId,
  name)` to every ready player. The pin shows in the Command View and on the HUD mini-map for
  `Tuning.Ping.Seconds` (6).
* Landon (2026-11-08): no team list replaces Roblox's player list (it stays off in the run),
  and the widest view stays as built: about 5 columns by 8 floors, panning for the rest.
* With votes (Prompt 8): an open cell under construction shows UNDER CONSTRUCTION and its
  progress, a cell or room with an open vote shows the proposal and offers nothing else, rows
  the stockpile can't pay show what's short, the main action says Build (not Propose) in a solo
  run, and ghosts mark open proposals ("KITCHEN?") and sites ("KITCHEN 45%").

## Votes, construction, the economy and power (Run place)

Bible Sections 5, 6, 8, 13 and 23. Rules are pure modules the data tests hold to the bible:
`Shared.Rules.Votes` (outcomes, the 40% rule, what a vote needs),
`Shared.Rules.Construction` (costs, refunds, unlocks, reserved cells, construction time, a plan
for each proposal) and `Shared.Rules.Economy` (Section 13's output formula, power made and
drawn, steps along the room graph, the dark order, eating with carry).

* `EconomyService` keeps the team's stockpile:
  * every stocked resource in `Config.Resources` from its Start amount;
  * caps: Cap plus CapPerStorageCell for each Storage cell, times StockpileCaps modifiers;
  * Lab research, from 0.
  * Amounts replicate as RunState values (one per resource, plus Research).
  * API: `Spend(costs, reason)`, `Add(id, amount, reason)` (capped), `CanAfford`, `Get`, `Stock`,
    `Cap`, `AddResearch`.
* Production (Prompt 9): rooms make things all the time while the clock runs. A room's output
  per cycle comes from its crew, level, span, light and modifiers, spread over a 270 s cycle;
  whole units go into the stockpile and the fractions carry. Production is published per room
  in the `Production` collection: { Rate, Makes, Idle, Workers }.
* Consumption (Prompt 9): at each `CycleStarted` every eater takes 1 Food (times FoodUse) and 1
  Water; a shortfall alerts the team and fires `Shortfall`.
* Crews and eaters come from `SetResidents({ Crew, Eaters })` (ResidentService, Prompt 10);
  call `RefreshCrew()` on changes.
* Other API: `SetModifier(source, key, value?, room?)` for RoomOutput, AllOutput,
  StockpileCaps and FoodUse; `Rate(roomId)`.
* `PowerService` keeps the live power balance:
  * the Reactor Core and Generators make power from their crews (Landon: they need residents);
  * every room draws Power[level] per cell, except a wrecked one (0 HP), which draws nothing
    until it is repaired;
  * when the draw passes what is made, rooms go dark farthest first by steps from the nearest
    power room (dug cells count; unreachable rooms first; at the same distance the biggest
    draw, then the newest);
  * rooms that draw nothing never go dark.
  * It pushes the dark rooms to EconomyService (`SetPowered`), dims their lights to emergency
    red and dulls their Neon fittings (the room model's `Dark` attribute), alerts the team, and
    publishes RunState PowerMade, PowerUsed, PowerNeeded, DarkRooms and the `Power` collection:
    { Draw, Made, Dark, Steps }.
  * API: `IsDark(roomId)`, `Balance()`, `Refresh()`, `DarkChanged`.
* `VoteService` runs votes (`Open(spec)`: kind, proposer, title, costs, the ghost's subject, the
  cells it holds, a re-check, OnPass, OnFail). One vote is live at a time; later ones queue and
  each gets its full time. The proposer counts as a yes; abstaining is not voting; a vote can be
  changed until it closes; everyone yes passes at once; ties fail unless a tie-breaker (the
  Warden, Prompt 20: `SetTieBreaker`) passes them; spending more than 40% of a stock needs a
  majority of the whole team. One open proposal per player; a failed one means a 20 s cooldown.
  Solo runs skip the vote (checked again, applied at once). The `Votes` collection carries what
  the telegram shows; a closed vote stays `Tuning.Votes.ResultSeconds` (3) with its result.
* `BuildService` takes the `Propose` remote (action, floor, column, room type or the other
  room), plans it (`Rules.Construction.Plan`: the bunker's rules, unlocks, the stockpile, Lab
  research for level 3, cells held by open votes and sites) and opens a vote. On a pass it plans
  again, pays, and: Build starts a construction site (20 s a cell, 25% faster per player standing
  in it, `Sites` collection, `workspace.Bunker.Sites` drawn by `BunkerKit.Site`), then places the
  room; Upgrade (costs per cell, so a merged room pays for each cell), Merge and TearDown apply at
  once. Tearing down gives back half of what the room cost (`Construction.Refund`, Landon). On a
  difficulty with `UpgradesTakeTime` (Nightmare) an upgrade is a site over the room instead
  (Kind "Upgrade"; the room works at its old level until it's done). `Unlock(roomType)` for drafts
  and cryo pods (`Unlocked` collection). Signals: `Proposed`, `Built`, `TornDown`.
* `VoteController` (client) fills the vote telegram, `StarterGui.Votes` (its own ScreenGui at
  DisplayOrder 6, above The Frame, so a vote can be answered from any screen): what and its cost,
  then who, the tally and the time, the timer strip, YES and NO (your vote stays pressed in:
  `KitRuntime.SetLatched`). On a controller Y votes: a tap for yes, a hold for no (Landon). While
  your ballot is open, Y is bound above The Frame's main action (Y), so it votes from any screen;
  key chips on YES and NO show on a gamepad. It draws the Command View's ghosts, sends `Propose`
  from the Command View's main action, and plays `SoundService.VoteOpen` / `VotePassed` when they
  exist (Prompt 32).
* Remotes: `Propose`, `CastVote` (client to server, Run), `Alert` (server to client: a message
  for the HUD's alert feed).

## Residents (Run place)

Bible Sections 11 and 23, phase 1. `Shared.Rules.Residents` is pure: rolls, max health (Grit),
levels, morale states, a room's crew, the Auto-Assign matching, one cycle of needs.

* `ResidentService` owns the records:
  * the six founders at the start, idle (Landon: the team, or the first-run tutorial, gives
    them jobs); when the run starts the alert feed says how many are waiting for jobs;
  * jobs: `Assign(id, roomId?)`, `AutoAssign()`, and the `AssignResident` and `AutoAssign`
    remotes, with no vote;
  * the crew and eater source for EconomyService (`SetResidents`);
  * needs, XP and Medbay healing after each meal (`EconomyService.Ate`; the newest arrivals go
    hungry first); Surge morale;
  * death: down for 20 s, `Revive` with a stockpile Medkit (the `ReviveResident` remote and a
    prompt), then gone; the last one gone loses the run.
  * away on an expedition (Prompt 18): `SetAway(id, on, health?)` (no job, no meals, no body),
    `Wound`, `GainXP`, `Note`, `Lose` (gone at once, no revive), `Count()` (the cap).
  * The `Residents` collection carries the records for the UI.
* `ResidentBrain` gives each resident a body (the A0 resident) in `workspace.Bunker.Residents`
  and runs the routine at 5 Hz:
  * the first 20 s of a day at a Kitchen seat, the rest at a work spot, the Surge in bed;
  * idle residents at a Lounge seat when there is a Lounge, otherwise by their bed;
  * down: lying with a revive prompt.
  * Bodies walk `Lib.PathGraph` routes (front aisles, doorways, Shaft stairs) with
    Humanoid:MoveTo and carry an `Activity` attribute. Residents don't collide with each other
    or players.
* `NPCAnimator` (client) plays `Config.Animations` clips for each body's Activity.
* `ResidentsController` (client): the Residents screen (Section 18), opened from the Command
  View's footer: tabs All, Working, Idle, Hurt, Away (Prompt 18); a resident card; Assign (the free job on their
  best stat) or Take off the job; the footer's Auto-Assign.
* The Command View lists a room's workers and the idle residents best at its job (Assign, Take
  off the job, Auto-Assign), and its Morale overlay reads the workers' average morale.

## Combat (Run place)

Bible Sections 9 and 23 (Prompt 11). `Shared.Rules.Combat` is pure: guns and melee weapons by
rarity, damage, fire intervals, pellets, the seeded spread, reloads, hit checks against position
history, cones and arcs, aim assist, combos, swing timing, stamina, the nearest respawn point.
The client predicts with it and the server checks with it.

* `CombatService` owns everyone who can be hurt:
  * `Register(model, spec)` for players (on spawn), residents' bodies (ResidentBrain) and
    monsters (Prompt 12; a dev dummy until then). Ids: `P<UserId>`, `N#`, `M#`.
  * Each combatant has a team, health, a reach and 1 s of positions at 20 Hz for the shot checks
    (Section 23: where the target was over the last 250 ms).
  * `Damage(id, amount, sourceId?, how?)`: no friendly fire, nothing during a dodge's
    invulnerable moment. A player's Humanoid never reaches 0 health: the lethal hit leaves it at
    1 and downs the player. All damage goes through here.
  * Players: Downed (20 s, crawling, a revive prompt for teammates), then Dead, then a respawn at
    the nearest working Medbay (not wrecked, not dark) or the Blast Door hall. The `Life`,
    `LifeEndsAt` and `InvulnerableUntil` attributes on the Player carry it. No natural
    regeneration.
  * Signals: `Damaged`, `Downed`, `Revived`, `Died`. Dead monsters dissolve.
* `WeaponService` owns what players carry and do:
  * the loadout (the class kit until Prompt 21): guns on hotbar slots 1 and 2, the tool on 3,
    throwables on 4 and 5, the melee weapon on its own button; the held item is a clone of its
    model welded to the hand at its Grip socket;
  * the remotes `SelectSlot`, `FireWeapon` (checked hits, then `HitConfirmed`), `ReloadWeapon`,
    `MeleeSwing`, `Dodge`, `Sprint`;
  * magazines, carried ammo and restocking at Workshop and Armory restock points (from the
    team's Ammo); Medkits restocked at the Medbay from the team's Medkits;
  * Landon's Prompt 11 answers: `UseMedkit` heals over `MedkitSeconds` (1.5 s, walking at
    `HealWalkMultiplier`; H, hold D-pad up, the Heal touch button), cancelled by being hit or
    swapping; `ThrowItem` throws the slot's throwable along an arc (Frag Grenade explodes, Flare
    lights, Foam Grenade puts out fire through `WeaponService.Foamed`, Shock Mine arms and stuns
    monsters through `StunnedUntil`); every class kit has a melee weapon;
  * stamina (sprint, dodge, heavy swings);
  * the Player attributes `Class`, `Slot`, `Item1` to `Item5`, `Mag1`, `Mag2`, `MeleeItem`,
    `CarriedAmmo`, `Stamina`, `ReloadEndsAt`, `ShotSalt`, `ShotNext`, `SwingEndsAt`.
* `CombatController` (client): input (fire, aim, reload, melee, dodge, sprint, the hotbar), the
  shot's feedback, recoil, aim assist on gamepad and touch, the roll, the HUD's hotbar and stamina
  gauge, hit and kill markers, damage numbers, health bars, the downed and out telegrams, the
  players' clips (`Config.Animations`).
* `PromptController` (client) draws every Custom-style ProximityPrompt from
  `HUD.Templates.Prompt` (the key's chip, the action, a hold gauge; on touch the plate is the
  button). Holding a revive prompt plays the kneel clip.
* `Lib.Movement` (client) works out one walk speed from several reasons (aiming, sprinting,
  crawling) on top of `StarterPlayer.CharacterWalkSpeed`.

## Threats and monsters (Run place)

Bible Section 10 (Prompt 12). `Shared.Rules.Threat` is pure: the threat level (year, deepest
floor, Disturbance, rooms and players, `Tuning.Threat`), Surge and trickle budgets (the
Tutorial Surge has its own; Boss and Final Surges spend nothing here; an account's first run in
Era I spends 70%), the era's roster (each era's new monsters up to now, never Surface-only),
groups bought from a budget (variety, group sizes), weighted breach picks and target order.

* `ThreatDirector` spends the budgets:
  * at each Surge: groups split into up to 4 waves `WaveSpacingSeconds` apart, at up to
    `MaxBreachPointsPerSurge` breach points, tagged `Surge:<cycle>`;
  * between Surges (the day, from cycle 2): single monsters when the trickle budget allows;
  * ends the Surge early (`CycleClock:EndSurge()`) once every wave is out, none of its monsters
    is left and no disaster holds it (`DisasterService:HoldsSurge`; `SetDisasterCheck` for tests);
  * pays for a Normal or Endless Surge's one disaster first (`DisasterService:SurgeDisaster`),
    and from the second day rolls a daily electrical surge (Prompt 13);
  * `ExtraBreach` and `Tremor` for Disturbance (Prompt 14); `RunState.Threat` and
    `RunState.Monsters` every second.
* `BreachService` owns breach points: room vents `V:<roomId>` (not the Shaft or the Blast Door;
  dark rooms weigh `DarkRoomWeight`, barricaded ones `BarricadeWeight`) and every dug cell at the
  rock edge, on any floor, `D:f,c` (Landon's Prompt 12 answer). `Open(point, groups, tag)` shows 10 s of dust and a pulsing
  red light, adds to the `Breaches` collection, sends `BreachWarning` to ready players, then
  spawns `SpawnSpacingSeconds` apart. Signal `Opened`.
* `MonsterService` owns monsters:
  * `Spawn(type, cframe, tag)` clones `ServerStorage.Assets.Monsters.<Asset>` (a graybox when
    missing), registers it with CombatService (team Monsters) and sets `Rig`, `MonsterType`,
    `Activity` and `AttackAt`; the server owns its physics; collision group Monsters. At most
    `MaxMonsters` (25) on the map, the rest queue; `Count(tag)` includes the queue.
  * The AI ticks every `MonsterAI.TickSeconds`: targets in the type's order (residents,
    machines, players who hit it, any player within `ProximityAggro` except Runners), walks the
    PathGraph (a stuck monster is moved on), attacks after a windup (the model's `HitTime`
    attribute, written from the generator's meta), damages rooms through `BunkerGrid:SetHP`
    (`RoomDamageMultiplier`, Brutes `SmashMultiplier`; a Reactor Core at 0 HP starts
    DisasterService's meltdown, Prompt 13), skips a target that rubble cuts off for a while
    (`Skip`) and plans again when `Lib.Hazards` changes,
    spits goo (`SlowedUntil`), latches ticks (a weld, bites every `AttackSeconds` ×
    `LatchIntervalMultiplier`), and obeys `StunnedUntil`.
  * Signals `Spawned` and `Died`; dev commands `monster`, `monsters`, `monsters.clear`.
* `ResidentBrain` (Prompt 12): residents near a monster flee to a safe room (no monster in or
  next to it) until `ResidentCalmSeconds` pass, swat a lone Burrow Tick, and walk slower while
  `SlowedUntil` lasts.
* `ThreatController` (client): the breach alert and mini-map blink, the Command View's Threat
  overlay (monsters, breach countdowns, likely dark rooms, vents) and the Slowed movement reason.
* `NPCAnimator` plays monsters' clips by `Rig:Activity` too (Attack replays on each
  `AttackAt`; Flee and Run fall back to Walk, Fight to Attack).
* Bosses: `Boss_BroodMother` in `ServerStorage.Assets.Bosses` has a `Belly` part with Role
  `WeakPoint`, sockets `Ovipositor`, `Maw` and `Slam`, `HitTime` 0.8 and `LayTime` 1.4, and seven
  clips in `Config.Animations` (Rig `BroodMother`); `Boss_BroodMother_EggSac` is what she lays.
  Her fight is `BossService` (see "Bosses and results").

## Disasters and repairs (Run place)

Bible Section 10, with Sections 5, 6 and 11 (Prompt 13). `Shared.Rules.Disasters` is pure: fire
growth, damage and spread targets (doorways on one floor; `Fireproof` rooms such as the Shaft
never burn), the Surge's pick (`SurgeWeight` disasters of the era and before that the budget
pays for), blackout floors and units, the valves (`ValveTurned`, `ValveReleased`, `ValvesOn`,
`MeltdownStopped`; solo players' turns last `SoloValveSeconds`, a team's while held), rubble HP,
dig times, damage and the passages it blocks, electrical surge odds and aftermath, repair rates.
The numbers are `Config.Disasters` and `Tuning.Disasters` / `Tuning.Repairs` (provisional).
`Shared.Rules.Modifiers.ClassValue(class, key, level?)` folds a class's passive modifiers
(ExtinguishSpeed, FireFloodDamageTaken, RepairSpeed; level 2 and 3 effects with Prompt 20).

* `DisasterService` owns every disaster and the `Disasters` collection (ids `F:<room>` fire,
  `B:<n>` blackout, `C:<n>` rubble, `M:<n>` meltdown, `S:<room>` electrical surge), RunState
  `Fires`, `BlackoutRooms`, `Rubble`, `Meltdown`, `MeltdownEndsAt`, `ValvesTurned`, and
  `workspace.Bunker.Disasters` (the fuse box, the valves, the rubble). It ticks every
  `TickSeconds` while the run is playing (also with the dev clock paused):
  * fires grow, burn rooms (`BunkerGrid:SetHP`), players (CombatService, the Firefighter a
    quarter) and residents, spread every `SpreadSeconds` (`SetModifier(source, "FireSpread",
    x)`), and go out under residents (ResidentBrain's Extinguish activity), the Extinguisher
    (`WeaponService.ToolTick`, the Firefighter 3x) and Foam Grenades (`WeaponService.Foamed`);
  * blackouts darken units through `PowerService:SetBlackout` until the fuse box in the Reactor
    Core is held for `FuseSeconds` or `DurationSeconds` pass (`BlackoutDuration` modifiers);
  * `CaveIn(floor, column, side?, cause)` drops rubble in a doorway or fills a dug cell: it
    blocks graph edges in `Lib.Hazards` (PathGraph routes round them or answers Blocked), hurts
    whoever is under it, shows `Kit_Rubble_Doorway` or `Kit_Rubble_Tunnel` (by the face's
    width; a filled tunnel's piles sit inside the tunnel) over an invisible block, and goes when
    a Drill or Pickaxe holder digs through (one hold) or melee smashes it (`WeaponService.Swung`;
    BreaksRubble weapons 3x); the pile sinks as it is hit;
  * a Reactor Core wrecked (`BunkerGrid.Wrecked`) starts the meltdown (`StartMeltdown`): a fire
    in the Reactor, the valves' prompts, `TimerSeconds` to turn all three; it ends Fixed, or
    Lost (`RunDirector:Lose("ReactorDestroyed")`);
  * electrical surges damage a room's machines until it is welded (`BuildService.Repaired`) or
    they expire into a fire or a floor blackout;
  * `SurgeDisaster(budget, rng)` buys the Surge's one disaster (started `SurgeDelaySeconds` in);
    `HoldsSurge()` keeps the Surge open while it, any fire or a meltdown is on.
  * Signals `Started` and `Ended`; dev commands `disasters`, `fire`, `fire.out`, `blackout`,
    `blackout.end`, `cavein`, `rubble.clear`, `meltdown`, `meltdown.stop`, `valve`, `esurge`,
    `disaster.surge`.
* Wrecked rooms (`Rules.Bunker`): a room at 0 HP is `Wrecked` (no output, power made or drawn,
  crew or machine target) until it is back to `RepairedAt` (25%) of its HP. `BunkerGrid` fires
  `Wrecked` and `Repaired` and applies HP modifiers (`SetHPModifier`, Reinforced Walls).
* Repairs (`BuildService`): the Welder held (`UseTool`) repairs the first damaged room ahead
  within `WelderReach` (`RepairSpeed`: the Engineer 2x); residents at work repair their own room
  by Smarts; `Repair(roomId, amount, how, player?)` and the `Repaired` signal; wreck and works
  again alerts; dev `repairs`, `repair`.
* `ResidentService:SetTrapped` and ResidentBrain: a resident whose route is Blocked waits,
  trapped (out of the crew), until the rubble goes; residents fight a fire where they stand
  until hurt below `ResidentFleeHealth`, then keep out of burning rooms.
* `WeaponService`: tools (`Kind = "Tool"`) are used by holding Fire (`UseTool` true/false); it
  fires `ToolTick` every `ToolTickSeconds` and sets the `ToolInUse` attribute; `Swung` for melee
  landings, `Foamed` for Foam Grenade bursts, `Items(player)`.
* `DisasterController` (client): flames, smoke, embers and light per burning cell, steam, surge
  sparks, the meltdown's alarm light, rubble dust, the tools' foam and sparks from the held
  model's Muzzle, the Welder's room HP bar, the HUD's Meltdown telegram and valve plates, the dig
  prompt shown only to Drill and Pickaxe holders, statuses and blinking in the Command View and
  on the mini-map (`CommandViewController:SetStatus`, `SetConditionNote`), and the named sounds
  once Prompt 32 adds them.
* Art: `Tool_Extinguisher` and `Tool_Welder` in `ServerStorage.Assets.Weapons` (Grip and Muzzle
  sockets), `Kit_Rubble_Doorway` and `Kit_Rubble_Tunnel` in `ServerStorage.Assets.Kit`, their
  icons in the items atlas.

## Digging, Disturbance and Push Deeper (Run place)

Bible Sections 6, 7, 10 and 14 (Prompt 14). `Shared.Rules.Dig` is pure: the faces a rock cell
is dug from (`Faces`: left, right or from the cell above) and where their prompts stand
(`FacePoint`), dig seconds by band (`Config.DepthBands`), stacking (`Rate`: the Driller's
`DigSpeed` 2), the Drill Bay's speed (`DrillBaySpeed`: `ResidentDigMultiplier` of a player per
unit of crew output), Push Deeper (`StartLimit` 3, `LimitAfter` the band's last floor,
`NeedsVote`), the roll (`Roll(seed, floor, column, era, available)`: the same for a cell all run,
results whose systems don't exist yet count as Empty; `Hint` for the Driller's eye; `Depth` into
rock), and Disturbance (`AddDisturbance`, `Crossed`: the extra breach and the Tremor,
`AfterTremor`, `Level` CALM, RISING, UNSETTLED, DANGER). `Shared.Rules.Loot` rolls
`Config.LootTables` (`BandOre` lines, skipped specials, `OreMultiplier`; `Text` for alerts). The
numbers are `Tuning.Digging` and `Tuning.Disturbance` (provisional).

* `DigService` owns digging and the `Digs` collection (`S:<floor>,<column>` a cell being dug or
  queued: Progress, Diggers, Queue, Bay, Vote; `F:<floor>,<column>` what a dug cell holds:
  CaveOpening, Cache or Nest), RunState `Disturbance`, `DigLimit`, `DigSeed`, `TremorAt`,
  `Nests`, and `workspace.Bunker.Digging` (the dig prompts, the Command View's markers, the
  features' models). It ticks every `TickSeconds` while the run is playing:
  * a dig prompt (Kind `DigCell`, attributes `Cell` and `Progress`) at every face of every
    diggable rock cell; `PromptButtonHoldBegan` adds the player as a digger if they carry a Drill
    or a Pickaxe (`WeaponService:Items`), `HoldEnded` takes them off; diggers must stay alive,
    armed and near; progress stays when they let go;
  * the Drill Bay digs the first diggable queued cell (`Mark(floor, column, on, player)`, the
    `MarkDig` remote, up to 12) at the summed speed of every working Drill Bay
    (`EconomyService:Rate`);
  * past `DigLimit` a hold opens a Push Deeper vote (`VoteService:Open`, Kind `PushDeeper`; solo
    applies at once); a pass moves `DigLimit` to the band's last floor, a failure waits
    `VoteRetrySeconds`;
  * a cell that opens (`BunkerGrid:Dig`) adds `DisturbancePerCell` (the Driller's level 3
    `DigDisturbance`, `SetModifier(source, "DigDisturbance", x)`), applies its roll, announces it,
    fires `Dug(floor, column, result, cause)`, and caves in the passage it was dug through
    `CaveInChance` of the time (`DisasterService:CaveIn`, sideways digs only);
  * results: an ore pocket pays band ore into the stockpile (`DugOre`); a cave opening shows
    `Kit_CaveMouth` 2 studs off the back wall and adds a breach point
    (`BreachService:SetExtraPoint`, Kind `Cave`); a cache shows `Prop_SupplyCrate` with an
    `OpenCache` prompt (resources to the stockpile, throwables to the opener's hotbar through
    `WeaponService:GiveThrowable`; gear and radio logs skipped until their prompts); a nest shows
    `Prop_Nest`, registers it with CombatService as a monster (an ordinary `M<n>` id, so
    FireWeapon accepts hits), adds a breach point (Kind `Nest`) and pours out
    `ThreatDirector:Burst(NestBudget)`; destroyed (`CombatService.Died`), it pays Loot `Nest` and
    drops Disturbance by `NestDestroyed`;
  * nothing is built on a feature's cell (`BuildService:SetCellCheck`);
  * Disturbance: explosions (`WeaponService.Exploded`) add `Explosive`; each new cycle living
    nests add `NestPerCycle` each and it falls `DecayPerCycle`; crossing `ExtraBreachAt` calls
    `ThreatDirector:ExtraBreach()`, reaching `TremorAt` calls `ThreatDirector:Tremor()`, caves in
    a doorway near the deepest floor, sets `TremorAt` and drops to `AfterTremor`;
  * API `Disturbance()`, `AddDisturbance(amount, source)`, `DigNow(floor, column, cause,
    player?)`, `Mark`, `SetModifier`, `Feature(floor, column)`; dev commands `digs`, `dig`,
    `dig.roll`, `dig.mark`, `disturbance`, `disturbance.add`, `tremor`, `pushdeeper`, `nest`,
    `cache`, `cave`.
* `ThreatDirector`: `Burst(fraction, at, tag)` spawns monsters at once at a spot; `ExtraBreach`
  and `Tremor` are priced as a quarter and a whole of a normal Surge's budget (the first run's
  Era I easing applies). `BreachService:SetExtraPoint(id, point?)` adds points other services
  own. `WeaponService`: `Exploded(position, radius, player)`, `GiveThrowable(player, item,
  count)`. `BuildService:SetCellCheck(fn)`.
* `DigController` (client): shows the dig prompts only to Drill and Pickaxe carriers; dust and
  chips at the faces of cells being dug and a burst when a cell opens; the camera shake at a
  Tremor (`CameraController:Shake`); the Command View's rock notes (dig time, progress, queue
  place, Push Deeper, the Driller's eye from `DigSeed` and `OreSightCells`), dug cells' notes
  (cave opening, cache, nest) and the queue options (`CommandViewController:SetCellNotes`,
  `SetRockOptions`, choices `MarkDig` and `UnmarkDig`, never voted).
* `HUDController`: the Disturbance seismograph (the level word and colour, a trace that swings
  harder as it rises, blinking at DANGER, a jump at a Tremor). `PromptController`: a prompt's
  `Progress` attribute drives its gauge (shared progress).
* Art: `Tool_Drill` and `Weapon_Pickaxe` in `ServerStorage.Assets.Weapons`, `Prop_Nest` in
  `Props`, `Kit_CaveMouth` in `Kit`, their icons in the items atlas.

## Bosses and results (Run place)

Bible Sections 5, 10, 16, 18, 21 and 22 (Prompt 15). `Shared.Rules.Boss` is pure: `Health(bossId,
players, firstRun)` (`Config.Bosses` Health times `Threat.PlayerScale`, times `FirstRunHealth` for
an Era I boss on an account's first run), `Phase(bossId, fraction)`, `ByPhase(list, phase)`,
`Arena(bunker)` (the longest dug run on the deepest floor, else its widest room that isn't the
Reactor Core or a Shaft, else any open cell), `ArenaMiddle`, `ArenaSpan(arena, margin)`,
`HitMultiplier(weak, classWeakPoint?)`, `OnPart(point, cframe, size, tolerance)`,
`Staggers(hits, now, window, threshold)`. `Shared.Rules.Results` is pure: `Payout(run, paid,
facts)` (lines, total and the new ledger, so a run that ends twice pays only what is new),
`BandsReached`, `AccountXP`, `XPToNext`, `LevelUp`, `Score`, `MVP` (ties to the lower user id),
`Day` (UTC). The numbers are `Tuning.Bosses`, `Tuning.<BossId>` (`Tuning.BroodMother`),
`Tuning.Results`, `Config.GlowshardRewards`, `Config.Difficulties` and `Tuning.Account`
(provisional).

* `BossService` runs a boss fight. `CycleClock.SurgeStarted("Boss", bossId)` (or `boss.start`)
  calls `BeginFight(bossId)`:
  * the warning (`ArrivalWarningSeconds`: dust and a blinking red light at the arena's middle, an
    alert), then the rise (`RiseSeconds`, a rock burst): a clone of `Config.Bosses` Asset from
    `ServerStorage.Assets.Bosses` in `workspace.Monsters` (graybox if missing), its root
    anchored and moved by the server (`PivotTo`), its root neither colliding nor queryable, a
    green light above it, attributes `Rig`, `MonsterType`, `Boss`, `Activity`, `AttackAt`,
    `ServerAnimated`; registered with CombatService as a monster with `KeepModel`;
  * its clips play on the server (`Config.Animations` with its id as Rig) and replicate:
    `NPCAnimator` skips `ServerAnimated` models, because the server judges weak-point hits
    against the parts' pose;
  * the tick (`TickSeconds`): phase changes (roar, alert), sacs hatching
    (`MonsterService:Spawn` of `Config.Bosses` Minions, tag `Boss:<id>`), turning
    (`TurnDegreesPerSecond`) and walking along the arena (`ArenaSpan`) towards the nearest
    standing player, slams (`SlamReach`, damage `SlamDamage` within `SlamRadius` of the `Slam`
    socket at the clip's `HitTime`), laying sacs at the `Ovipositor` socket (`LayTime`; each a
    CombatService monster, `MonsterType` EggSac);
  * hits: `WeaponService:SetHitModifier` scales hits on the boss (`ArmourMultiplier`, or
    `WeakPointMultiplier`/the class's own on a part with `Role` WeakPoint, within
    `WeakPointTolerance`, +2 for melee, +3 for blasts; renamed `weakpoint`) and fire on sacs
    (`BurnMultiplier`); weak-point damage in `StaggerWindowSeconds` reaching `StaggerFraction`
    of its health staggers it;
  * death (`CombatService.Died`): the Death clip held, sacs wither, `Defeated(bossId, killer?)`,
    then `ObjectiveService:BossBeaten` (which ends the boss Surge); `DeathSeconds` later it
    dissolves (`CombatService:Dissolve`). The run ending clears a fight.
  * the `Boss` collection, key `Fight`: Id, Name, Health, Max, Phase, Phases, State (Warning,
    Rising, Fighting, Dying), At, ArriveAt, Sacs. API `BeginFight`, `Active`, `IsBoss(combatId)`,
    `IsEggSac(combatId)`; dev `boss`, `boss.start [id]`, `boss.hurt <n> [weak]`, `boss.lay`,
    `boss.freeze [s]`, `boss.end`.
* `BossController` (client): the HUD's `BossBar` (name, BREAKING THROUGH, PHASE n OF m, DEAD, the
  fill) and camera shakes when the boss rises and when its slam lands near the player.
* `ResultsService` counts each player's Damage, Kills, BossDamage (`BossService:IsBoss`; a broken
  sac isn't a kill), Revives, CellsDug (`DigService.Dug`'s finisher) and Repairs
  (`BuildService.Repaired`), the team's totals, and the story (`story(text)`: resident deaths,
  nests, meltdowns, bosses, Push Deeper from `DigLimit`, Tremors from `TremorAt`, the ending).
  On `RunDirector.RunEnded` it pays every ready player through `ProfileService:Update`
  (Glowshards, `AccountLevel`/`AccountXP`, `Stats` Runs, Wins, LastWinDay, BestYear, Deepest,
  BossesKilled, MonstersKilled, `FirstRunDone`), saves (`SaveNow`) and publishes the `Results`
  collection, key `Run` (Outcome, DefeatReason, Victory, Endless, Year, Cycle, Era, Difficulty,
  Seconds, DeepestFloor, Band, Team, Stories, MVP, Players[userId] = Name, Class, the stats,
  Score, Glowshards, Lines, XP, Level, LevelUp, Paid). Remotes `PlayAgain` (a `PlayAgain` vote
  opened by the game with the asker's yes; a pass reserves a Run server and teleports
  everyone), `KeepGoing` (after a victory, the `KeepGoing` vote, `RunDirector:KeepGoing`) and
  `ReturnToLobby` (that player); Studio says teleports don't work. Dev `results`,
  `results.stat <stat> <n>`.
* `ResultsController` (client): the `Results` screen (RUN REPORT; tabs Summary, Residents,
  Rewards; the MVP card on the detail panel; Play Again as the main action; Keep Going and Return
  to Lobby in the footer), opened `OpenDelaySeconds` after the run ends.
* `CombatService`: `KeepModel` (a combatant whose model its own service removes), `Dissolve`,
  dev `god [seconds] [player]`. `ThreatDirector:IsFirstRun()`. `WeaponService:SetHitModifier`.
* Art: `Boss_BroodMother` and `Boss_BroodMother_EggSac` in `ServerStorage.Assets.Bosses`. Boss
  body parts use the `queryhull` collision kind (Hull raycast shapes), so shots reach the weak
  point.

## The surface (Run place)

Bible Sections 9, 12 and 13 (Prompt 16). `Shared.Rules.Surface` is pure: `Zone(position)` (Surface
above `Tuning.Surface.ZoneY`; Prompt 17: Deep behind `Tuning.Deep.GridBack`, else Bunker),
`Realm(zone)` and `SameRealm(a, b)` (the bunker and the Deep are one realm, Underground),
`RadiationRate(zone, storm, gain)`, backpacks as lists of stacks
(`Stack`, `Slots(extra)`, `Used`, `Fit(pack, slots, id, count)`, `Merge`, `Unload(pack, room)`,
`Totals`, `Summary`, `Encode`/`Decode` for the `Pack` attribute), `CarrySpeed(carriers)`,
`SpawnSpot(points, players, range, rng)`, `SurvivorTier(roll)`. The numbers are `Tuning.Surface`
and `Tuning.MonsterAI`'s surface values (provisional).

* The map is `workspace.Surface`, static in the place at Y = `BrightwaterMap.GROUND` (200), built in
  Studio by `ServerScriptService.Lib.BrightwaterMap.Build()` from `ServerStorage.Assets.Surface`
  (A5; graybox stand-ins otherwise). Each place is a model with `PlaceId` (and `Location`) holding
  its containers (models with `Container`, `Location`) and a `Markers` folder (`SurvivorSpot`,
  `BigFindSpot`, `ElevatorExit`, `ElevatorCall`); `Spawns` holds `SpawnPoint`s; gates carry
  `MinEra` and parts with `Barrier`. Signs (art parts with Role `Sign`) get a `Lettering`
  SurfaceGui. A rebuild keeps moved places and `workspace.Surface.Decor` (Landon's dressing).
* `SurfaceService` reads the map (never builds it): zones (`Zone` attribute, `ZoneChanged`), the
  elevator (`workspace.Bunker.Elevator` RIDE UP at the Blast Door's `Door` socket, RIDE DOWN at
  `ElevatorCall`; the `Elevator` remote fades the client, the server moves the rider and their
  followers), containers (SEARCH, `Loot.Roll` with `ExtraLootRolls`, leftovers, refills on
  `EraChanged`, locks below `MinEra`), storms (`SurgeStarted`/`SurgeEnded`, RunState `Storm` and
  `StormAt`, the siren alert and the Scout's `StormWarningSeconds`), radiation (the `Radiation`
  attribute, Decon Rooms, Clear-Rad pills at `PillUseAt`, health drain at the max, Wraith hits),
  and the creatures (jackals by day, raiders from `RaiderMinEra`, wraiths in storms, at
  `SpawnPoint`s, `MaxMonsters`, despawned when the surface empties, a fall guard). Each day may
  trap a survivor and place generator parts. Prompt 17: the raider camp holding the surface's
  Lost Crew (`workspace.SurfaceCamp`, at one of the map's `CampSpot`s, guards tagged `Camp`).
  API `Zone`, `Storm`, `Radiation`, `AddRadiation`, `Map`, `CrewWhere`; signals `ZoneChanged`,
  `Searched`.
* `InventoryService`: backpacks (`Give`, the `Pack`, `PackUsed`, `PackSlots`, `ClearRad`
  attributes), unloading (`workspace.Bunker.Hauling`: the hall's point 15 studs from the
  elevator and one per Storage room; `Unload(player)` within the stockpile's caps), big finds
  (`PlaceFind(kind, at, tag)` in `workspace.Finds`, CARRY, HELP CARRY, PUT DOWN, the `Carrying`
  and `Carriers` attributes, `SetDelivery(kind, fn)`, else the loot table of that name), dropped
  bags (`Prop_LootBag`, PICK UP), Clear-Rad pills (`TakePill`) and monster drops (a kill on the
  surface or in the Deep into the last hitter's pack, a bunker kill into the stockpile). Loot
  specials go to their owner's handler (`SetSpecial`, `GiveSpecial`; Prompt 17: radio logs,
  Glowshards). Signals `Unloaded`, `Delivered`.
* `RescueService`: `Trap(at, options)` (a `Resident_Common` clone in `workspace.Rescues`, rubble, a
  FREE prompt), freed people as CombatService combatants (Kind `Survivor`, team `Survivors`)
  following a leader with PathfindingService, a catch-up teleport, leader hand-overs within a
  realm, the elevator (`Followers`), and joining (`ResidentService:Add`; `SetArrival(kind, fn)`
  runs after joining). Kinds Survivor, Miner and Crew (Prompt 17); `Tagged(tag)`. Signals
  `Freed`, `Joined`, `Lost`.
* `MonsterService` knows realms: monsters only target things in their own realm (survivors count
  as residents, machines are bunker-only), surface and cave monsters path with
  PathfindingService, jackals circle, raiders shoot (trait `Shoots`), `Despawn(id)`, `ZoneOf(id)`.
  Prompt 17: a monster in a cave reaches the bunker through the cave's mouth and the other way
  round (`SetCaveExit`); guards (`Spawn(type, at, tag, { Guard = range })`) sleep at their post,
  wake to a player within range or a hit, keep within 1.6 times that of their post, and go back.
* `WeaponService` and `CombatController` refuse gun, melee, throws, tools, rolls and Medkits while
  a player's hands are busy (`Carrying`).
* `SurfaceController` (client): the surface's Lighting (Surface and Storm presets, the bunker's
  captured at start), the `SurfaceGrade` colour correction, ash and gusts round the camera,
  lightning, the elevator fade and the camera turn, the HUD's radiation gauge and `Backpack` chip,
  prompt gating (carry, help, put down and unload by attributes; PUT DOWN hides near a station),
  the carry and Scout speeds, the Scout's `LootOutline` highlights.

## The Deep (Run place)

Bible Sections 6, 11, 12 and 14 (Prompt 17). `Shared.Rules.Deep` is pure: `MouthCFrame(floor,
column)` (the dug cell's back wall, facing -Z into the rock) and `MouthPoint` (in front, in the
cell), `ExitCFrame`, `WorldBox`, `Overlaps`, `Inside`, `Pieces(band, kind?)`, `Plan(band, mouth,
rng, occupied, { Crew, Pieces })` (the cave planner: the Entry, then pieces grown from exits, each
clear of `occupied` but for the 4 studs of wall it shares with the piece it hangs off; plugs; the
crew's pocket; no plan when another cave fills the rock), `RollFind(roll, era, findChance)`,
`CryoTier`, `CrewCell(seed, band, isOpen)`, `Hint(floor, column)`, `FallDamage(drop, immune)`,
`LightRange(multiplier)`, `Roster(band, usable)`. The numbers are `Tuning.Deep`, the pieces
`Config.CavePieces` (generated from the A6 sidecars by `tools/cave_config.py`: don't edit by hand),
the logs `Config.RadioLogs`.

* `DeepService` builds a cave on `DigService.FeatureAdded("CaveOpening", floor, column)` in
  `workspace.Deep` ("Cave <key>", one model per piece from `ServerStorage.Assets.Caves`, a graybox
  floor otherwise): the dug cell's `BackRock` hidden and anything solid in the opening made
  non-colliding (again on `BunkerGrid.Changed`), `DigService:OpenCave` (the stand-in mouth goes),
  rubble plugs (`Kit_Rubble_Doorway` x1.45 and an invisible block), lantern lights at `Light`
  sockets, finds at `Find` sockets (models with a `Find` attribute and a Custom prompt: MINE, OPEN,
  LISTEN; trapped miners through RescueService; cryo pods through InventoryService), cave nests at
  `Nest` sockets (combatants with breach points `CN:<id>` at the mouth), guards at `Spawn` sockets
  (spawned when a player comes within `WakeRange`, tag `Cave:<key>`).
* The Lost Crews: `DigService:SetRoll` makes each band's crew cell a cave opening (RunState
  `DigOverrides`); its cave's crew pocket holds the three (Kind Crew, Tag the objective) and a
  nest. `RescueService:SetArrival("Crew")` completes the objective (any Lost Crew, the surface's
  too) when the first is home; `Lost` with none left loses the crew.
* Radio logs: `InventoryService:SetSpecial("RadioLog")` and the recorders play the next unheard
  story log, or (HintChance, while a crew is lost) that crew's own log with its hint; the
  `RadioLog` remote. Glowshard chests: `SetSpecial("Glowshards")` pays every ready player through
  `ProfileService:Update`; `ChestOpened` tells ResultsService.
* Cryo pods: `DigService:SetResultHandler("CryoPod")` and cave finds place them
  (`PlacePod`; the first unlocks the Cryo Bay); `InventoryService:SetDelivery("CryoPod")` adds
  one to RunState `CryoPods`; Cryo Bays' `EconomyService:Rate` thaws them (`ThawPoints` each, while
  the clock runs) into Rare or Legendary residents.
* Players in the Deep: a `DeepLight` PointLight on the root (`LightRange` x `LightRadius`); falls
  read from the root's vertical speed on Heartbeat (`FallDamage`, `NoFallDamage`).
* `MonsterService:SetCaveExit` is DeepService's: a cave position's mouth point.
* `DeepController` (client): the `RadioLog` sheet (UIKit `Paper`, Special Elite, typed out) and the
  Spelunker's eye (`SpelunkerEye` Highlights on finds, nests, cryo pods and the trapped within
  `RevealRange`). `SurfaceController` has the Deep's lighting preset; `DigController` reads the
  overrides for the Driller's eye.
* API `Caves()`, `CaveAt(position)`, `Pods()`, `PlacePod(at, tag)`. Signals `CaveOpened`,
  `CrewHome`, `Thawed`, `ChestOpened`. Dev: `deep`, `deep.cave`, `deep.find`, `deep.tp`,
  `cryo.add`, `radiolog`, `crews`.

## Expeditions and the radio (Run place)

Bible Sections 6, 8, 11, 12 and 14 (Prompt 18). `Shared.Rules.Expeditions` is pure: `Check(destination,
members, cycles, medkits)` (1 to 3 residents, alive, in the bunker, not cut off; 1 to 3 cycles; up to
`MedkitsMax` Medkits), `Supplies(members, cycles)` (Food and Water for every member for every cycle),
`Risk(team)` (the team's average of Grit and Speed against `StatPivot`), `Fast(team)` and
`Trip(cycles, team)` (a team averaging `FastSpeed` is away a cycle less, never under 1; Landon,
Prompt 18), `Odds(destination, team)`
(hurt, distress, lost: the bible's odds times the destination's `Danger` and the Risk), `Event(odds,
x)`, `RiskLabel`, `Carry(stats, effects)` and `Team(team, effects)` (Strength carries; a member's own
`ExpeditionCarry`, `ExpeditionLoot`, `ExpeditionScrap`), `Scale(drops, team)`, `Expected(...)` (a
cycle's average finds, for the screen), `Harm(maxHealth, x, medkit)`, `Deadline(cycle)`,
`RecruitTier`, `Names`, `Place`, `Fill`, `Lines(destination, event)`. The numbers are
`Tuning.Expeditions`, the log lines `Config.ExpeditionLogs`, the finds `LootTables` ExpeditionSurface
and ExpeditionDeep.

* `ExpeditionService` puts an EXPEDITIONS console prompt (Kind `Expeditions`) on the radio of the
  Blast Door guard's desk (`Kit_BlastDoor`'s `GuardDesk`; beside the door in a graybox hall) and in
  every Radio Room (`<bunker>.ExpeditionConsoles`, again on `BunkerGrid.Changed`). The
  `SendExpedition` remote (destination, resident ids, cycles, Medkits; no vote, Section 8) is
  checked: the sender within `UseRange` of a console, `Rules.Expeditions.Check`, the stockpile
  (`EconomyService:Spend` takes the Food, Water and Medkits). Each member leaves their job and goes
  Away (`ResidentService:SetAway`); `ResidentBrain` walks them out through the Blast Door and their
  body goes (no body while away). A Deep expedition goes to the band of the deepest floor (its ore).
* At each dawn (`CycleClock.CycleStarted`) an expedition out since an earlier cycle lives a cycle:
  packed Food and Water eaten, `XPPerExpeditionCycle` (`ResidentService:GainXP`), the loot table
  rolled and scaled by the team (`Scale`; gear and blueprints skipped until Prompts 26 and 19; one
  recruit at most a trip), and one event: nothing, someone hurt (`ResidentService:Wound`, never
  below 1; a packed Medkit halves it), someone lost (`ResidentService:Lose`; a packed Medkit makes
  it a bad hurt instead) or a distress call. Lines go in the expedition's log and the members' run
  logs (`ResidentService:Note`). After the last cycle they step into the hall with the finds and
  the supplies left (`EconomyService:Add`) and go back to their old jobs if there's room. A fast
  team (`Trip` < `Cycles`) turns for home after `Trip` cycles with the finds of every cycle picked
  (the missing cycles' loot is rolled as they leave; an `Early` line in the log), and the unused
  Food and Water come back with them.
* Distress calls: the call comes `CallDelay` running seconds into that day, less the team's best
  `DistressCallLeadSeconds` (the Radio Operator), on everyone's radio card (the `RadioLog` remote)
  and in the alerts. Only a working Radio Room (staffed and powered: `RunState.RadioWorks`, which
  the screen reads to warn before SEND) hears it (Landon, Prompt 18): unheard, every member still
  out is lost at once with the finds (an `Unheard` log line, one alert, no radio card). The team is pinned down at `SurfaceService:DistressSpot()` (a free survivor
  spot) or `DeepService:DistressSpot()` (a piece of an open cave; with none, the rock face of the
  deepest floor): each member is a RescueService rescue of Kind `Expedition` (`Resident` = their id,
  a HELP prompt with their name, their own health). Helped, they follow home; the arrival
  (`RescueService:SetArrival("Expedition")`) brings that resident back (`SetAway` off, the health
  the way left them, where they stood) and the first one home brings the finds. At the next cycle's
  Surge (`SurgeStarted`: the end of the next day phase) whoever is still pinned down is lost; with
  nobody left to bring them, the finds are lost too.
* The Radio Room: its `Recruits` output (`EconomyService:Rate`) times the team's best `RecruitRate`
  accrues while the clock runs (`Rules.Economy.Accrue`); each whole point is a recruit at the Blast
  Door (`Recruit(tier, how)`: Rare at `RadioRareChance` times `RareRecruitChance`; refused at
  `Constants.CAPS.Residents`). While a Lost Crew is out and a Radio Room works, every
  `RadioHintCycles` cycles it plays that crew's call (`DeepService:CrewCall`, `PlayLog`).
* `ExpeditionService:SetModifier(source, key, value?)` takes RecruitRate, RareRecruitChance and
  DistressCallLeadSeconds from draft cards and Legends; players' classes are read directly.
* The `Expeditions` collection (id -> Destination, Band, Members { Id, Name, Status }, Cycles, Done,
  LeftAt, Back, State, Log, Finds, Recruits, Food, Water, Medkits, CallCycle, Deadline, Marker, Where)
  feeds `ExpeditionsController` (client): the Expeditions screen (SURFACE and DEEP: pick the team
  from resident cards, the footer sets the length and the Medkits, zone D the supplies, risk and
  finds, SEND; ACTIVE: each expedition's team, deadline or return, finds, supplies and log) opened
  from the console prompts, and the distress markers (a red flare column, the `HUD.Templates.Distress`
  plate through walls with the time left, and a `HUD.Templates.EdgeArrow` while it's off screen).
* API `Send(destination, ids, cycles, medkits, player?)`, `Recruit(tier?, how)`, `SetModifier`,
  `Active()`. Signals `Sent`, `Returned`, `Lost`, `Distress`, `Reached`, `Recruited` (ResultsService
  tells their stories). Dev: `exp`, `exp.send`, `exp.cycle`, `exp.call`, `exp.home`,
  `exp.deadline`, `recruit`, `radio [call]`.

## The blueprint draft (Run place)

Bible Section 8 and the Appendix's card pool; Prompt 19. `Shared.Rules.Draft` (pure: the pool,
weighted draws with EarlyWeight in Era I, a card's face, tallies, a controller's next pick),
`Config.DraftCards` (each card's kind, modifiers, weights, `Short` face text), `Tuning.Draft`.

* `VoteService` runs draft votes: a spec with `Options` is a MostVotes vote. Players pick with the
  `CastPick` remote (changeable until it closes); time up, the most picks wins, ties at random;
  everyone having picked closes it. Solo runs vote too (the player's pick closes it). `SetOptions`
  swaps an open draft's cards (a reroll: picks cleared, the time restarted). `Live()` gives the vote
  on the banner. The Votes collection carries `Options` (with each one's `Votes`), `Picked` and
  `Winner`.
* `DraftService` opens a draft at every `CycleClock.SurgeEnded` (not after the final Surge), draws 3
  cards from the usable pool (every modifier has a handler in its HANDLERS; a room card's room not
  yet unlocked; the Steel Blast Door below level 3) plus the first found blueprint waiting, and
  applies the winner through each owning service's hook:
  `BuildService:Unlock`, `BunkerGrid:SetHPModifier`, `DisasterService:SetModifier`,
  `BreachService:SetModifier` (DarkSpawnBonus), `BunkerGrid:SetLevel` (the Blast Door),
  `ResidentService:AddLevels`/`AddMorale`, `ExpeditionService:Recruit`,
  `WeaponService:SetModifier` (WeaponRarityUp, StaminaMult) and `AddMedkits`,
  `DigService:SetModifier`, `EconomyService:SetModifier` (RoomOutput), and its own Overclock
  overload rolls (`DisasterService:StartMeltdown`), Bounty Contract kills (`MonsterService.Died`)
  and Salvage Rights (`SurfaceService:SetLootBoost`, `SetStormEarly`).
* Found blueprints: InventoryService's `Blueprint` special draws a card; on the surface or in the
  Deep it goes into the pack (`InventoryService:GiveCard`, its own slot) and comes home when
  unloaded (`InventoryService.CardsHome`); in the bunker it is home at once; expeditions bring
  theirs home (`ExpeditionService.BlueprintsHome`). `AddFound` queues a card that's home; the next
  draft shows it as a fourth card (FoundPerDraft), stamped FOUND with the finder's name.
* Rerolls: the `RerollDraft` remote uses a free reroll (FreeDraftRerollsPerEra: the level 3 Mad
  Scientist, one per era; players carry `DraftRerolls`). `Reroll(player, "Paid")` is for Prompt 28.
* `VoteController` shows a draft as the telegram ("BLUEPRINT DRAFT · PICK A CARD", picks, timer)
  with the cards below it (`StarterGui.Votes.Draft`, sprites `Draft_<Kind>` and `Stamp_Found` from
  the draft atlases): click or tap a card, or Y (tap: the next card; hold: the one before); REROLL
  where YES and NO sit for a player with a free reroll. It preloads the draft atlases.
* Signals: `DraftService.Drafted(card, how)` (ResultsService tells it in the story),
  `FoundHome(card, by)`. Dev: draft, draft.open, draft.take, draft.found, draft.reroll [paid],
  draft.cards, bounty [kills], vote.pick <n|id> [voter], pack.add Blueprint.

## Classes (Run place)

Bible Section 14 (classes, class levels) and Section 9 (Q is the class ability); Prompt 20.
`Shared.Rules.Classes` (pure: an ability's cooldown, uses, options and duration; levels from
experience), `Config.Classes` (kits, passives, abilities, level 2 and 3 as modifiers),
`Tuning.Classes` (everything the bible doesn't give; provisional).

* **Which class.** `Lib.RunRecord` is the record the Lobby writes to MemoryStore before the teleport
  (hash map `RunRecords`, key = the reserved server's id; `{ Version, Party, Difficulty, Loadouts =
  { [userId] = { Class, Trial } }, CreatedAt }`; Studio's key is "Studio"). When a session is ready
  `ClassService` gives the player the record's class if their profile owns it or it is their free
  trial (level 1, no experience), else the Survivor, and puts `Class`, `ClassLevel` and `ClassTrial`
  on the Player; `WeaponService:SetClass` hands out the kit.
* **Effects.** Every system reads a class effect with `Modifiers.PlayerValue` (a level's value
  replaces the passive's). Bunker-wide effects go to their systems as the strongest holder's value
  (`EconomyService:SetModifier`, `BuildService:SetModifier`, `ResidentService:SetModifier`,
  `DisasterService:SetModifier`, `BunkerGrid:SetHPModifier`, RunState `BuildCost`).
  `CombatService:AddDamageFilter` carries Hold the Line, the drone's Guard and residents' damage
  near a Security, armed, or rallied; `WeaponService:AddHitModifier` and its `Hit` signal (player,
  target, damage, how, point, the hit's own kind) carry creature damage, burning, boss staggers and
  the Exterminator's Disturbance. `VoteService:SetTieBreaker` is the Warden.
* **The ability.** `UseAbility(option, origin, look)` from `ClassController` (a tap of Q, LB or the
  touch button; a hold picks the next option, `PickAbilityOption`). `ClassService` checks the run,
  the player and readiness (seconds, cycles, or uses that return each Surge, cycle or era), then
  `Lib.ClassAbilities.Use(state, option, origin, look)` does it through the owning services and
  returns `(ok, text, effect, seconds)`: not ok costs nothing and the text says why. Devices that
  stay in the world (turret, barricades, crate, napalm, traps, the beacon, the gravity well, the
  drone) live in ClassAbilities and read their art's sockets (`Socket_<Name>` attributes).
* **What the client reads**, on the Player: `AbilityReadyAt`, `AbilityReadyCycle`, `AbilityUses`,
  `AbilityMax`, `AbilityOption`, `AbilityOptionReadyAt`, `AbilityEffect`, `AbilityActiveUntil`,
  `SteadyShots`. RunState: `LevelStat` (the level 2 Warden's choice, `ChooseLevelStat`),
  `BeaconUntil`, `BeaconBy`. Remotes: UseAbility, PickAbilityOption, TeleportToBeacon,
  ChooseLevelStat, Grapple, AbilityFx, ArcZap.
* **Class experience.** `ResultsService` pays it with the run's payout: `ClassService:RunXP(player,
  years, paidYears)` is `Rules.Classes.RunXP` (XPPerYear a year; none for a trial); the level
  follows the experience (`LevelFor`: 150 and 500) and `Refresh(player)` puts it in play.
* **Held weapons.** `Config.Items.Hold` (TwoHanded, Hip, Heavy) picks the player's clips in
  `CombatController` (RifleHold, RifleAim, RifleReload, HeavySwing1 and 2, Throw). Every long gun's
  `Support` socket is 1 stud ahead of its `Grip`, so one pair of clips fits them all.
* Dev: classes, class <Id> [level] [player], class.level, class.own, ability [option],
  ability.ready, classxp <years>, resident.arm <id|all> [item|none], record <Class> [trial].

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
TalentSlots, TeamBoosts, Tiers, Traits, Tuning, Votes, WandererOutcomes; Prompt 17: CavePieces
(generated by `tools/cave_config.py`) and RadioLogs; Prompt 18: ExpeditionLogs.

**Effects are data.** Classes, traits, Legends, draft cards and passes describe what they do
as modifiers: `{ Key = "RoomOutput", Value = 1.25, Room = "Medbay", Scope = "Bunker" }`.
`Config.Modifiers` is the vocabulary: each key's unit (Multiplier, Add, Set, Flag, Chance),
default scope, and the prompt whose system applies it. A system reads the keys it owns; a new
effect is a new key plus the code that honours it.

**Rule numbers** live in `Config.Tuning`, one entry per system (Clock, Grid, StartingBunker,
Rooms, Votes, Player, Digging, Disturbance, Bosses and one per boss fight (BroodMother),
Results, Threat, Residents, Aging, Morale, Trader, Wanderers, Expeditions, Surface, Deep, Legends,
ClassShop, Account, Lobby).

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
  `hud.slot <n>`, `hud.touch [bool]`, `cv` (the Command View's state and options), `cv.open`,
  `cv.close`, `cv.select <floor> <column>`, `cv.ping`, `cv.ghost <floor> <column> <span>
  [label]`, `cv.unghost`, `cv.blink <roomId> [false]`, `cv.overlay <name> [false]` (a sample
  reading for screenshots).
* The bunker (Run place): `grid` (map), `grid.rooms`, `grid.graph`, `grid.dig <floor> <column>`,
  `grid.build <Type> <floor> <column> [span] [level]`, `grid.remove <id>`, `grid.merge <id> <id>`,
  `grid.level <id> <level>`, `grid.rebuild`, `grid.sockets <id>`, `grid.art`.
* The run (Run place): `run`, `run.skipintro`, `run.win <century|deep>`,
  `run.lose <reactor|residents>`, `run.keepgoing`; `clock`, `clock.speed <x>`, `clock.pause`,
  `clock.resume`, `clock.next`, `clock.clear`, `boss.beat [bossId]`, `year <n>`,
  `ready.all [bool]`, `rest.all [bool]`; `objectives`, `objective <id>`; `cell.ping <floor>
  <column>` (pings as the first player).
* Votes and construction (Run place): `stock`, `stock.set <resource> <n>`, `stock.add
  <resource> <n>`, `research [n]`; `votes`, `vote.yes [n]`, `vote.no [n]` (as you, or as pretend
  voter n), `vote.end` (time is up now), `vote.test [title]` (a vote with no proposer and no
  effect), `vote.bots <n> [yes|no|abstain]` (Studio: pretend voters join the team); `build
  <Build|Upgrade|Merge|TearDown> <floor> <column> [roomType|otherRoomId]`, `sites`,
  `site.finish [id]`, `unlock <roomType>`. From Studio's server tools, `build` and `vote.yes|no`
  act as the first player in the run. On the client, `vote` prints the telegram and the ghosts.
* Residents (Run place): `residents`, `residents.auto`, `residents.add [count] [tier] [level]`,
  `resident.assign <id> <roomId|none>`, `resident.hurt <id> <amount>`, `resident.revive <id>`,
  `resident.set <id> <health|rest|morale|xp|stat> <value>`, `brains` (where each body is going).
* The economy and power (Run place): `production` (every room's rate and why idle rooms are
  idle), `staff <roomId|roomType> <statSum> [workers] [morale]` and `staff.clear` (Studio: pretend
  crews until residents arrive), `eaters <n>` (pretend eaters), `eat` (the start-of-cycle meal
  now), `power` (the balance, steps and dark rooms), `run.difficulty <Normal|Hard|Nightmare>`.
* `ServerStorage.NS_Pipeline` (an outside Night Shift importer plugin's empty working folder,
  which Landon can't remove) is only a StructureCheck warning; scripts inside it would be an
  error.

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
| Run | PingService | service | SessionService, DevService | cell pings (PingCell in, CellPinged out to every ready player) |
| Run | EconomyService | service | BunkerGrid, CycleClock, SessionService, ReplicationService, DevService | the stockpile (amounts, caps, spending, research), production, food and water, bunker-wide output modifiers |
| Run | PowerService | service | BunkerGrid, EconomyService, SessionService, ReplicationService, DevService | the power balance, dark rooms (lights, fittings, alerts), blackouts' dark units |
| Run | ResidentService | service | BunkerGrid, EconomyService, PowerService, CycleClock, RunDirector, SessionService, ReplicationService, DevService | residents: records, jobs, needs, levels, death |
| Run | ResidentBrain | service | ResidentService, BunkerGrid, CycleClock, DevService | residents' bodies, routines, walking (Lib.PathGraph) |
| Run | VoteService | service | SessionService, ReplicationService, DevService | votes: the live vote and the queue, ballots, rules, solo, cooldowns, draft votes with options (Prompt 19), the Votes collection |
| Run | BuildService | service | BunkerGrid, EconomyService, VoteService, SessionService, RunDirector, ReplicationService, WeaponService, CombatService, ResidentService, DevService | proposals, construction and upgrade sites, upgrades, merges, teardown and refunds, unlocks, repairs (the Welder, residents) |
| Run | CombatService | service | SessionService, BunkerGrid, PowerService, ResidentService, DevService | everyone who can be hurt: combatants, history, damage, down, revive, death, respawn |
| Run | WeaponService | service | CombatService, EconomyService, BunkerGrid, SessionService, DevService | loadouts, the hotbar, held items, shots and their checks, reloads, melee, dodge, sprint, stamina, restocking |
| Run | MonsterService | service | CombatService, BunkerGrid, ResidentService, RunDirector, DevService | monsters: spawning, the cap and queue, the AI, attacks, room damage, goo, latching, stuns |
| Run | BreachService | service | BunkerGrid, PowerService, MonsterService, SessionService, ReplicationService, DevService | breach points, warnings, the Breaches collection, spawning at a breach |
| Run | DisasterService | service | BunkerGrid, PowerService, CycleClock, RunDirector, CombatService, WeaponService, ResidentService, BuildService, SessionService, ReplicationService, DevService | fires, blackouts, cave-ins and rubble, the Reactor meltdown, electrical surges, the Surge's disaster, the Disasters collection |
| Run | ThreatDirector | service | CycleClock, RunDirector, BunkerGrid, SessionService, ProfileService, BreachService, MonsterService, DisasterService, DevService | the threat level, Surge waves and their disaster, the trickle, daily electrical surges, ending a cleared Surge, bursts, Disturbance's extra breach and Tremor, RunState Threat and Monsters |
| Run | DigService | service | BunkerGrid, CycleClock, RunDirector, SessionService, ReplicationService, EconomyService, WeaponService, CombatService, VoteService, BuildService, BreachService, ThreatDirector, DisasterService, InventoryService, DevService | digging, the dig prompts, the roll and what dug cells hold (ore, caves, caches, nests; cells with a fixed roll), Push Deeper, the Drill Bay's queue, Disturbance, the Digs collection |
| Run | BossService | service | CycleClock, RunDirector, BunkerGrid, SessionService, CombatService, MonsterService, WeaponService, ObjectiveService, ThreatDirector, ReplicationService, DevService | boss fights: the arena, arrival, the boss model and its clips (on the server), slams, egg sacs, weak points, staggers, phases, death, the Boss collection |
| Run | ResultsService | service | RunDirector, CycleClock, SessionService, ProfileService, CombatService, MonsterService, ResidentService, BuildService, DigService, DisasterService, ObjectiveService, BossService, BunkerGrid, VoteService, InventoryService, RescueService, DeepService, ExpeditionService, DraftService, ReplicationService, DevService | the run's stats and story, payouts, account experience and profile stats, the MVP, the Results collection, Play Again, Keep Going, Return to Lobby |
| Run | InventoryService | service | SessionService, BunkerGrid, EconomyService, CombatService, WeaponService, MonsterService, RunDirector, DevService | backpacks, unloading, big finds and carrying, dropped bags, Clear-Rad pills, monster drops |
| Run | RescueService | service | SessionService, CombatService, ResidentService, ResidentBrain, RunDirector, DevService | trapped people: freeing, the escort, joining the bunker |
| Run | SurfaceService | service | SessionService, CycleClock, RunDirector, BunkerGrid, PowerService, CombatService, MonsterService, InventoryService, RescueService, DevService | the surface map, zones, the elevator, containers, storms, radiation, surface creatures, the raider camp and the surface's Lost Crew |
| Run | DeepService | service | BunkerGrid, CycleClock, RunDirector, SessionService, DigService, InventoryService, RescueService, MonsterService, CombatService, ResidentService, ResidentBrain, EconomyService, BuildService, ObjectiveService, BreachService, ProfileService, SurfaceService, DevService | caves from the A6 pieces, finds, guards and cave nests, the Lost Crews, radio logs, Glowshard chests, cryo pods and thawing, the Deep's light and falls |
| Run | ExpeditionService | service | BunkerGrid, CycleClock, RunDirector, SessionService, EconomyService, ResidentService, ResidentBrain, RescueService, SurfaceService, DeepService, ReplicationService, DevService | resident expeditions (sending, cycles away, finds, harm, losses, coming home), distress calls and their markers, the Radio Room's recruits and crew calls |
| Run | DraftService | service | CycleClock, RunDirector, SessionService, VoteService, BuildService, BunkerGrid, EconomyService, DisasterService, DigService, BreachService, ResidentService, ExpeditionService, WeaponService, SurfaceService, MonsterService, InventoryService, DevService | the blueprint draft (Prompt 19): drawing cards, applying the winner, found blueprints, rerolls, the Bounty Contract and the Overclock's overloads |
| Run | ClassService | service | SessionService, RunDirector, CycleClock, ProfileService, CombatService, WeaponService, MonsterService, BossService, ResidentService, ResidentBrain, EconomyService, BuildService, BunkerGrid, DisasterService, DigService, DeepService, SurfaceService, InventoryService, RescueService, VoteService, BreachService, DevService | classes (Prompt 20): each player's class and level from the run record, abilities with cooldowns, uses and options (Lib.ClassAbilities does them), bunker-wide passives, the damage filter, class experience |
| both | ReplicaController | controller | | the delta channel mirror (client) |
| both | InputController | controller | | devices, the bible's action bindings, look and zoom input |
| both | CameraController | controller | InputController, ReplicaController | the over-the-shoulder camera: shoulder, aim, zoom caps, wall fade, the mouse lock and reticle |
| both | UIController | controller | InputController, CameraController | The Frame: screens, pages, tabs, chips, the main action, footer |
| both | HUDController | controller | InputController, UIController, CameraController, ReplicaController | the run HUD (Run; nothing in the Lobby yet) |
| both | MiniMapController | controller | ReplicaController, HUDController | the HUD's side-view mini-map and its pings (Run) |
| both | CommandViewController | controller | InputController, CameraController, UIController, ReplicaController, HUDController | the Command View (Run): its camera, picking, detail panel, build menu, overlays, ghosts, pings |
| both | VoteController | controller | ReplicaController, CommandViewController, InputController | the vote telegram (Run) and Y to vote, the blueprint draft's cards (Prompt 19), the Command View's vote and site ghosts, its Propose handlers |
| both | NPCAnimator | controller | | residents' and monsters' clips from their Rig and Activity attributes (Run); an attack plays over the rig's Idle when it has one; skips `ServerAnimated` models (bosses) |
| both | ResidentsController | controller | UIController, ReplicaController | the Residents screen (Run) |
| Run | CombatController | controller | InputController, CameraController, HUDController | the local player's fighting: input, feedback, aim assist, the hotbar, stamina, life overlays, clips |
| Run | ClassController | controller | InputController, CameraController, HUDController | the class ability key (tap to use, hold for the next option), the class plate and ability gauge, the beacon chip, the grapple's zip, class-only prompts, ability effects |
| Run | PromptController | controller | HUDController, CombatController | the themed interaction prompts |
| Run | ThreatController | controller | HUDController, MiniMapController, CommandViewController, ReplicaController | breach alerts, the Threat overlay, the Slowed movement reason |
| Run | DisasterController | controller | HUDController, MiniMapController, CommandViewController, ReplicaController | disasters' world effects, the tools' effects, the Welder's HP bar, the Meltdown telegram and valve plates, dig prompt gating, statuses in the Command View and mini-map |
| Run | DigController | controller | ReplicaController, CommandViewController, CameraController | dig prompt gating, dig dust, the Tremor's shake, the Command View's dig notes and queue options |
| Run | BossController | controller | ReplicaController, HUDController, CameraController | the HUD's boss bar, the camera shakes of a boss's rise and slam |
| Run | ResultsController | controller | UIController, ReplicaController | the Run Report (results screen) and its buttons |
| Run | SurfaceController | controller | HUDController, CameraController | the surface's and the Deep's light and weather, the elevator fade, the radiation gauge and backpack chip, prompt gating, carry speed, the Scout's outline |
| Run | DeepController | controller | HUDController | the radio log sheet, the Spelunker's eye |
| Run | ExpeditionsController | controller | UIController, ReplicaController | the Expeditions screen, distress markers and their edge arrows |
| both | DevController | controller | ReplicaController, InputController, CameraController, UIController, HUDController, CommandViewController, VoteController | `/dev` chat command, Studio DevInvoke |

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
* **Prompt 7 (2026-11-08)**: the Command View (Run). CommandViewController (docked Frame, a
  capped far camera that widens its field of view past 440 studs so the lowest graphics level
  still draws the bunker, pan, zoom, picking, room, open cell and rock details, the build menu
  with unlocks, overlays, vote ghosts, blinking labels, the damage edge), PingService and pings on
  the mini-map, Rules.CommandView, Bunker.FromSnapshot; Tab and the View button reach it
  although Roblox marks them processed; Roblox's player list is off in the run.
* **Prompt 8 (2026-11-08)**: votes and construction (Run). EconomyService (the stockpile, caps,
  research), VoteService (Section 8's rules, a queue, solo, cooldowns, pretend voters in Studio),
  BuildService (proposals, construction sites with helpers, upgrades, merges, teardown,
  unlocks), Rules.Votes and Rules.Construction, VoteController and the vote telegram in its own
  ScreenGui, the stockpile on the HUD. Landon's answers to the Prompt 6 and 7 questions: Ready on
  Z and D-pad down, the mouse wheel frees the cursor, ore chips by depth, no team list, the
  Command View pans.
* **Prompt 9 (2026-11-08)**: the economy and power (Run). Rules.Economy (Section 13's formula,
  the power balance and dark order, eating), EconomyService production and meals with a
  resident source for Prompt 10, PowerService (dark rooms in emergency red), the HUD's Power
  chip, the Command View's Power and Production overlays with readings. Landon's answers to the
  Prompt 8 questions: tear-down refunds half, upgrades take time on Nightmare, controllers vote
  with Y (tap yes, hold no), the proposer stays a yes; and to Prompt 9's: power needs crew.
* **Prompt 10 (2026-11-08)**: residents, phase 1 (Run). Rules.Residents, ResidentService (the
  founders, jobs and Auto-Assign by best match, needs, levels, death and defeat), ResidentBrain and
  Lib.PathGraph (eating, working and sleeping, walking doorways and Shaft stairs), NPCAnimator
  and Config.Animations, the Residents screen, workers and assigning in the Command View, the
  Morale overlay.
* **Prompt 11 (2026-11-08)**: the combat core (Run). Rules.Combat, CombatService (combatants,
  history, damage, down, revive, respawn at a working Medbay), WeaponService (loadouts, the
  hotbar, server-checked shots, reloads, melee combos and heavy swings, dodge, sprint, stamina,
  restocking), CombatController, PromptController (themed prompts), Lib.Movement, the players'
  11 clips, the Pocket Pistol (v2: the grip rakes back) and the Wrench. Before it, Landon's
  answers to the Prompt 9 and 10 questions: the biggest draw goes dark first, wrecked rooms draw
  nothing, the founders start idle, idle residents use the Lounge.
* **Landon's Prompt 11 answers (2026-11-08)**: carried ammo per player, the hotbar, a Heal
  button (Medkits over 1.5 s; H, hold D-pad up, a touch button) with Medkits restocked at the
  Medbay, throwables thrown with Fire (`ThrowItem`: Frag, Flare, Foam, Shock Mine), no
  regeneration, and a melee weapon in every kit (new: Defib Paddles, Antenna Whip, Hazard Hook,
  Hunting Knife, Power Wrench). The aim fixed: the clips' wrists, and the waist follows the aim.
* **Prompt 12 (2026-11-08)**: threats and monsters (Run). Rules.Threat, ThreatDirector,
  BreachService, MonsterService, the residents' flee and swat, ThreatController, monsters in
  NPCAnimator, the A4 Mines monsters and their clips. Then the A4 detail pass (Landon: more
  detailed monsters, scary bosses): the four monsters rebuilt (the Tunnel Hound gained a Jaw
  bone, the Spitter Grub four mouth petals), the Brood Mother with seven clips and her egg sac,
  generator meta written as model attributes.
* **Prompt 13 (2026-11-08 and 9)**: disasters and repairs (Run). Rules.Disasters,
  Rules.Modifiers, DisasterService (fires, blackouts and the fuse box, cave-ins with
  Lib.Hazards, the Reactor meltdown and its valves, electrical surges, the Surge's disaster),
  DisasterController, wrecked rooms and repairs (the Welder, residents), trapped residents,
  monsters skipping blocked targets, tools in WeaponService, the HUD's Meltdown telegram; art:
  the Extinguisher, the Welder, doorway and tunnel rubble and two hotbar icons.
* **Prompt 14 (2026-11-09)**: digging, depth bands, Disturbance and Push Deeper (Run).
  Rules.Dig, Rules.Loot, DigService (dig prompts, stacking, the roll: ore pockets, cave
  openings, caches, nests; Push Deeper votes, the Drill Bay's queue, Disturbance and its extra
  breach and Tremor), DigController, the HUD's seismograph, the camera shake, the Command View's
  dig notes and queue; ThreatDirector bursts; art: the Drill, the Pickaxe, the nest, the cave
  mouth and two hotbar icons.
* **Prompt 15 (2026-11-09)**: the Brood Mother and the results screen (Run). Rules.Boss,
  Rules.Results, BossService (the arena, warning and rise, slams, egg sacs, the belly, staggers,
  phases, death; her clips on the server), ResultsService (stats, the story, payouts, account
  experience, profile stats, the MVP, Play Again, Keep Going, Return to Lobby), BossController
  (the HUD's boss bar, shakes), ResultsController (the Run Report); WeaponService hit modifiers,
  CombatService `KeepModel`; the `queryhull` collision kind for bosses' bodies.
* **Prompt 16 (2026-11-09)**: the surface (Run). Rules.Surface, SurfaceService (the map, zones,
  the elevator, containers, storms, radiation, surface creatures), InventoryService (backpacks,
  unloading, big finds, bags, pills, monster drops), RescueService (trapped survivors, the escort,
  joining), SurfaceController, Lib.BrightwaterMap (the town, built in Studio at Y 200);
  MonsterService zones, pathing, circling and shooting; busy hands; hauls and rescues in the
  results; art: the A5 surface kit (11 buildings, props, the loot bag, generator parts, the Ash
  Jackal, Wraith and Raider with clips) and eight surface icons.
* **Prompt 17 (2026-11-09)**: the Deep (Run). Rules.Deep (the cave planner, finds, crews, hints,
  falls, light, guards), DeepService (caves, finds, guards, cave nests, the Lost Crews, radio
  logs, Glowshard chests, cryo pods and thawing, light and falls), DeepController (the radio log
  sheet, the Spelunker's eye), Config.CavePieces and RadioLogs; realms (the Deep zone) in
  Rules.Surface, MonsterService (cave walking, guards) and RescueService (miners, crews); the raider
  camp and the surface crew in SurfaceService; DigService's fixed rolls and FeatureAdded;
  InventoryService's loot specials; the Deep's lighting; art: A6 (16 cave pieces, the cryo pod,
  the radio log recorder, two ore veins, the Glowshard chest, the raider camp).
* **Prompt 18 (2026-11-09)**: resident expeditions and distress calls (Run). Rules.Expeditions,
  ExpeditionService (the consoles, sending, cycles away, finds, harm and losses, coming home,
  distress calls, the Radio Room's recruits and crew calls), ExpeditionsController (the
  Expeditions screen, distress markers and edge arrows), Config.ExpeditionLogs; residents Away
  (ResidentService, ResidentBrain), residents already in the run as rescues (RescueService),
  distress spots (SurfaceService, DeepService), the Residents screen's AWAY tab, expedition
  stories in the results; HUD.Templates.Distress. Landon's answers (same day): fast teams home a
  cycle early (`Rules.Expeditions.Fast`/`Trip`, `Tuning.Expeditions.FastSpeed`), unheard calls
  lose the team (`RunState.RadioWorks`), the `Early` and `Unheard` log lines.
* **Prompt 19 (2026-11-09)**: the blueprint draft (Run). Rules.Draft, DraftService (drafts after every
  Surge, the usable pool, each card's effect through its owning service, found blueprints, rerolls,
  the Bounty Contract, Overclock's overloads), draft votes with options in VoteService (`CastPick`,
  `SetOptions`), the draft's cards under the telegram (VoteController, `StarterGui.Votes.Draft`, the
  draft atlases), blueprints carried in packs and brought home by expeditions; modifier hooks in
  BreachService, WeaponService, ResidentService and SurfaceService. With it, Landon's answers to the
  Prompt 13, 14, 16 and 17 questions: Surges bring cave-ins (floods and gas leaks with Prompt 23), a
  respawn keeps half its radiation, a third of Ash Raiders fight hand to hand, ore veins need a
  Drill or a Pickaxe. The game is 100 Years Below (Constants.GAME_NAME).
* **Prompt 20 (2026-11-09 and 10)**: all 19 classes (Run). Rules.Classes, ClassService, Lib.ClassAbilities,
  Lib.RunRecord (the Lobby's record, read here, written by Prompt 21), ClassController; class
  effects wired into CombatService (the damage filter), WeaponService (kits per class, the shot
  hook, hit modifiers, the hit's own kind), MonsterService (Taunt), BossService (Stun), BuildService,
  EconomyService, ResidentService and ResidentBrain (rally, arming, touch heal, the level stat),
  VoteService (the tie breaker) and ResultsService (class experience). The A2 art: 27 models, six
  player clips (`Config.Items.Hold` picks them), 26 icons. The Ash Raider's detail pass:
  `Monster_AshRaider_Melee` (rig AshRaiderMelee), the rifle's own joint, Idle clips, and NPCAnimator
  playing an attack over the rig's Idle.
