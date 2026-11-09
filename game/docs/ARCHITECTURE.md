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
  View's footer: tabs All, Working, Idle, Hurt; a resident card; Assign (the free job on their
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
    team's Ammo);
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
| Run | PowerService | service | BunkerGrid, EconomyService, SessionService, ReplicationService, DevService | the power balance, dark rooms (lights, fittings, alerts) |
| Run | ResidentService | service | BunkerGrid, EconomyService, PowerService, CycleClock, RunDirector, SessionService, ReplicationService, DevService | residents: records, jobs, needs, levels, death |
| Run | ResidentBrain | service | ResidentService, BunkerGrid, CycleClock, DevService | residents' bodies, routines, walking (Lib.PathGraph) |
| Run | VoteService | service | SessionService, ReplicationService, DevService | votes: the live vote and the queue, ballots, rules, solo, cooldowns, the Votes collection |
| Run | BuildService | service | BunkerGrid, EconomyService, VoteService, SessionService, RunDirector, ReplicationService, DevService | proposals, construction and upgrade sites, upgrades, merges, teardown and refunds, unlocks |
| Run | CombatService | service | SessionService, BunkerGrid, PowerService, ResidentService, DevService | everyone who can be hurt: combatants, history, damage, down, revive, death, respawn |
| Run | WeaponService | service | CombatService, EconomyService, BunkerGrid, SessionService, DevService | loadouts, the hotbar, held items, shots and their checks, reloads, melee, dodge, sprint, stamina, restocking |
| both | ReplicaController | controller | | the delta channel mirror (client) |
| both | InputController | controller | | devices, the bible's action bindings, look and zoom input |
| both | CameraController | controller | InputController, ReplicaController | the over-the-shoulder camera: shoulder, aim, zoom caps, wall fade, the mouse lock and reticle |
| both | UIController | controller | InputController, CameraController | The Frame: screens, pages, tabs, chips, the main action, footer |
| both | HUDController | controller | InputController, UIController, CameraController, ReplicaController | the run HUD (Run; nothing in the Lobby yet) |
| both | MiniMapController | controller | ReplicaController, HUDController | the HUD's side-view mini-map and its pings (Run) |
| both | CommandViewController | controller | InputController, CameraController, UIController, ReplicaController, HUDController | the Command View (Run): its camera, picking, detail panel, build menu, overlays, ghosts, pings |
| both | VoteController | controller | ReplicaController, CommandViewController, InputController | the vote telegram (Run) and Y to vote, the Command View's vote and site ghosts, its Propose handlers |
| both | NPCAnimator | controller | | residents' clips from their Activity attribute (Run) |
| both | ResidentsController | controller | UIController, ReplicaController | the Residents screen (Run) |
| Run | CombatController | controller | InputController, CameraController, HUDController | the local player's fighting: input, feedback, aim assist, the hotbar, stamina, life overlays, clips |
| Run | PromptController | controller | HUDController, CombatController | the themed interaction prompts |
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
