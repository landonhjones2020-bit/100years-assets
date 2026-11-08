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
    Config                       content aggregator; one child ModuleScript per content type
    Utilities                    Check, Delta, Loader, Log, RateLimit, Signal, TableUtil, Trove
ServerScriptService
  Bootstrap                      (Script) the only server script
  Services                       one ModuleScript per service
  DevTools                       StructureCheck, DataTests (+ Invoke in Studio playtests)
StarterPlayer.StarterPlayerScripts
  ClientBootstrap                (LocalScript) the only client script
  Controllers                    one ModuleScript per controller
ServerStorage
  Documentation.ARCHITECTURE     this document
  Assets                         models from the art pipeline (Run)
  ArtPipeline.AssetSetup         art pipeline helper (Run; not game code)
```

Rules: only the two bootstraps are scripts; everything else is a ModuleScript. No `_G`, no
`shared`: modules `require` each other. Server-only code never goes in ReplicatedStorage.
Objects named `A0_...` (showroom, sample screens) are art-pipeline samples, allowed until
gameplay replaces them.

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

* Every RemoteEvent is an entry in `Shared.Remotes` (`To`, `Args`, `Rate`, `Doc`). Nothing else
  creates remotes; StructureCheck flags any that appear elsewhere.
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

## Content

All content is data in `Shared.Config` (bible Section 23). Each content type is a child
ModuleScript returning `{ Schema = Check.shape(...), Entries = { Id = entry }, Order = {...}? }`.
Config validates every entry at load (fields, ids, `Check.ref` cross-references), freezes
it and adds `Id`. Read with `Config.Get(type, id)` (errors if missing), `Config.Find` (for ids
from players or saves), `Config.All(type)`, `Config.Ids(type)`. Problems are listed by
`Config.Errors()`, logged, and fail StructureCheck and the data tests.

## DevTools

* `/dev <command>` in chat for allowed players (everyone in Studio; outside Studio only the
  admins in `Constants.ADMIN_USER_IDS`); `/dev help` lists commands. Services add their own
  in `Init` with `DevService:Register`.
* In a Studio playtest: `ServerScriptService.DevTools.Invoke:Invoke("test")` on the server,
  `PlayerScripts.DevInvoke:Invoke("replica Rooms")` on a client.
* `structure`: StructureCheck. `test [filter]`: DataTests. Both run once whenever a Studio
  playtest starts (set the `RunChecksOnStart` attribute on DevTools to false to stop that).
* Other built-ins: `version`, `ping`, `players`, `remotes`, `log [level]`, `logs [count]`,
  `rep`, `rep.selftest`; on the client `replica <collection>` and `client`.

## Conventions

* `--!strict` in every file. Tabs. PascalCase for modules, types, methods and content ids;
  camelCase for locals. Content ids: letters, digits and `_`, starting with a letter.
* Logging through `Utilities.Log` (`Log.new("Tag")`), never bare `print`.
* Tunables are content (Config); identity and engine limits are `Constants`.
* Every prompt ends with Design Notes and a Delivery Report in `game/reports/`.

## Services and controllers

| Place | Name | Kind | Depends on | Owns |
|---|---|---|---|---|
| both | SessionService | service | | player sessions: client ready, leaving |
| both | DevService | service | | DevTools commands and permission |
| both | ReplicationService | service | SessionService, DevService | the delta channel (server) |
| both | ReplicaController | controller | | the delta channel mirror (client) |
| both | DevController | controller | ReplicaController | `/dev` chat command, Studio DevInvoke |

## Prompt log

* **Prompt 0 (2026-11-08)**: architecture foundation in both places. Shared modules, Config
  aggregator, remotes with validation and rate limits, the delta channel, bootstraps with
  declared dependencies, DevTools, this document. No gameplay.
