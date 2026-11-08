# Prompt 0: Architecture foundation

Bootstrap, Shared modules, Config aggregator, remotes, DevTools and docs, in both places.
No gameplay (bible Section 24). Built and tested in Studio on 2026-11-08, build `p0-d230b45`
(StructureCheck fix `e2b0e26` goes in with the next install).

## Design Notes

**Decisions**
1. **The code's source of truth is the repo, `game/`**, installed into both places as one
   Model asset (`100Y_GameCode`, id 95026446991297, a new version per build). Both places get
   byte-identical shared code, every change has history, and nothing depends on a Studio
   session surviving. It uses the same Open Cloud path as the art. Each installed script's
   hash is recorded in `Shared.BuildInfo`; the installer refuses to overwrite a script that
   was edited in Studio, so Landon's own edits are never lost.
2. **Three infrastructure services and two controllers** that Section 23's tables don't list:
   SessionService (a player is ready once their client has bootstrapped), ReplicationService
   (the delta channel Section 23 describes) and DevService (DevTools); ReplicaController and
   DevController on the client.
3. **The delta channel**: named collections of keyed values with set, patch, remove and clear;
   batched and flushed 10 times a second; a full snapshot when a session becomes ready;
   optional per-player visibility; values checked as remote-safe (an error in Studio, logged
   live). Patches send only changed fields.
4. **Remotes**: one list. A client → server remote must declare a checker per argument and a
   rate limit. The limiter runs first (cheapest), extra arguments are rejected, rejections
   are logged at most once per 10 s per player, and a handler error can't break the remote.
5. **Lifecycle**: deterministic dependency order (ties alphabetical); Init's registry only
   resolves declared dependencies; a failed Init skips its dependents and sets
   `ServerBroken` instead of starting half-wired.
6. **Config** loads and validates every content type, resolves cross-references and freezes
   entries, but holds none yet: content types are Prompt 1. Bad data doesn't stop the game;
   it fails StructureCheck and the data tests.
7. **DevTools** entry points: `/dev` in chat (everyone in Studio, only Landon live), Studio
   Bindables for tools (`DevTools.Invoke`, `PlayerScripts.DevInvoke`), and checks that run on
   every Studio playtest start.

**Design Risks**
* None for players: this prompt has no gameplay.
* The delta channel adds up to 100 ms before a collection change reaches clients. Right for
  rooms, residents and votes; combat will use its own remotes (Prompt 11).

**Scope Risks**
* The delta channel arrives before its first user (Prompt 3 or 4). It is small, isolated and
  tested end to end in both places, so later prompts build on a working piece.

**Bible Questions**
1. Add SessionService, ReplicationService, DevService, ReplicaController and DevController to
   Section 23's tables?
2. Section 19 calls the repo "the art repo"; the game code now lives there too (`game/`).
   Record that in Sections 19 and 23?
3. Who counts as an admin in live servers? Now only Landon (9768530298).

**Recommended Improvements**
* Machine type-checking (luau-lsp) in CI. It couldn't be installed in this workspace (the
  download was refused), so strict-mode types are checked by Studio's Script Analysis only.
* Disable the Night Shift importer plugin for this game: it recreates
  `ServerStorage.NS_Pipeline` in both places, even during playtests, and StructureCheck
  reports it as an error every time.

**Technical Risks**
* Strict-mode types haven't been machine-checked outside Studio; behaviour is tested.
* The installer replaces the managed folders wholesale. It is guarded by the Studio-edit check
  and only touches `Shared`, `Bootstrap`, `Services`, `DevTools`, `ClientBootstrap`,
  `Controllers` and `Documentation`.
* The code ships as a Model asset with scripts. Moderation approved both builds in seconds;
  a slow moderation would delay an install, not break the game.

## Delivery Report

**Overview.** Both places now run the same skeleton: one server Script and one LocalScript,
everything else ModuleScripts, started in declared dependency order; one validated, rate-
limited list of remotes; a working delta channel; a content aggregator; DevTools; the
architecture document inside each place.

**Files created** (repo `game/`)
* `shared/`: `Constants`, `Types`, `Remotes`, `Config/init` (aggregator),
  `Utilities/{Check, Delta, Loader, Log, RateLimit, Signal, TableUtil, Trove}`
* `server/`: `Bootstrap.server`, `Services/{SessionService, ReplicationService, DevService}`,
  `DevTools/{StructureCheck, DataTests}`
* `client/`: `ClientBootstrap.client`, `Controllers/{ReplicaController, DevController}`
* `docs/ARCHITECTURE.md` (installed as `ServerStorage.Documentation.ARCHITECTURE`),
  `BUILD.json` (prompt number, code asset id), `reports/P00_Architecture.md`
* `tools/game_sync.py`: builds `exports/Code/GameCode.rbxmx` and prints the install Luau.

**Files modified.** None in the game (both places had no code). Repo: `CLAUDE.md` (game code
workflow), `BUILD_LOG.md` (status).

**Architecture.** See `game/docs/ARCHITECTURE.md`: places, where code lives, where it comes
from, lifecycle, writing a service, networking, content, DevTools, conventions.

**Integration notes**
* A new service: a ModuleScript in `game/server/Services` (or `game/places/Run/server/Services`
  for Run only) with `Name`, `Dependencies`, `Init`, `Start`. A controller: the same in
  `Controllers`.
* A new remote: one entry in `Shared.Remotes` with checkers and a rate limit.
* A new content type (Prompt 1): a ModuleScript under `Shared.Config`.
* Replicated collections: `ReplicationService:Collection(name)` / `ReplicaController`.
* Install: commit, `python3 tools/game_sync.py build`, `device_commit_files`, PATCH asset
  95026446991297 with the `.rbxmx`, then `python3 tools/game_sync.py install 95026446991297
  <Place>` for each place.

**Testing checklist (done, 2026-11-08)**
* [x] Edit mode, both places: install, StructureCheck 0 errors / 0 warnings (56 checks,
  every script's hash matches the repo), DataTests 27/27.
* [x] Run playtest: server ready (3 services, 3.4 ms), client ready (2 controllers), Studio
  start checks ran, DataTests 27/27 on the server.
* [x] Delta channel end to end (Run and Lobby): `rep.selftest` on the server, the client
  mirror matched (set, patch with a removed field, remove, Vector3 value); snapshot on join.
* [x] `/dev` path: client DevInvoke → DevCommand → server → Notice (`ping`, unknown command).
* [x] Abuse: 11 malformed DevCommand calls (wrong type, extra argument, missing argument,
  overlong name, bad characters, invalid UTF-8, NaN, a dictionary for a list, too many items)
  all rejected before the handler; a flood of 30 calls and 10 ClientReady repeats
  rate-limited; no handler failures.
* [x] Lobby playtest: server and client ready; checks pass except the NS_Pipeline error.
* [ ] Live server (not Studio): `/dev` refused for non-admins. Needs a published test with a
  second account.
* [ ] Two players at once: snapshots per player. First run with two clients at Prompt 3.

**Future extension notes**
* Prompt 1 adds every content type under `Shared.Config` and its data tests.
* Prompt 2 makes SessionService wait for the profile before a session is ready.
* If the delta channel needs per-player visibility that changes over time (fog of war), add
  a re-evaluation call to ReplicationService rather than a second channel.
