# Prompt 2: Saved data

Profiles, session lock, migrations, receipt records (bible Sections 17 and 23). Built and
tested in Studio on 2026-11-08 against real DataStores, build `p2-3315fd7`, both places.

## Design Notes

**Decisions**
1. **Hand-written, not a library.** The bible names the pattern (Monster Lab's record of Data
   plus Lock, UpdateAsync with a session lock, migrate-reconcile-validate, autosave on 120 s,
   leave and shutdown, failed or newer loads never write); it is implemented exactly that way
   in `ProfileService`, with the pure parts in `Lib.ProfileSchema` so they can be tested.
2. **Lock rules.** A fresh lock from another server: wait and retry 8 times, 2 s apart (a
   Lobby to Run teleport releases on the way out), then kick with a message. A lock is stale
   after 3 autosave intervals (6 minutes; 30 s in Studio) and is then taken over. Every
   autosave refreshes the lock. A save only writes while this server holds the lock; losing
   it kicks the player rather than writing over another server.
3. **Studio uses its own store** (`PlayerProfiles_Studio`), so tests can't touch live saves;
   with no API access an in-memory store with the same semantics stands in.
4. **A new player owns the free class and the starter Legend** (the Free tier from Config and
   `Tuning.Legends.StarterLegend`), per Sections 14 and 15.
5. **Purchases**: `GrantPurchase` grants, records the receipt in the profile, saves, and only
   then returns PurchaseGranted. A receipt already recorded is never granted again; the save
   is simply redone. The newest 200 receipt ids are kept.
6. **Sessions wait for the profile**: SessionService now has gates (Client, Profile); a player
   is ready, and gets the replication snapshot, only when every gate has passed. A failed
   load kicks the player with a clear message.
7. **The player sees their own profile** (minus receipts) through the delta channel, in a
   per-player collection only they receive.

**Design Risks**
* None for gameplay. A player whose save is held by a crashed server waits up to 6 minutes
  before it is taken over (or is asked to rejoin); shorter would risk two servers writing.

**Scope Risks**
* Run-time state is never saved (Section 23); the rejoin record (MemoryStore) is Prompt 21.

**Bible Questions**
1. Admin profile tools (grant Glowshards, wipe) exist only as DevTools commands in Studio and
   for the owner. Do you want a live admin panel later (Prompt 29 or 35)?

**Recommended Improvements**
* A second Studio test with two servers (Team Test) at Prompt 21 to watch a real teleport
  handoff of the lock.

**Technical Risks**
* DataStore budget: autosaves skip a tick when the UpdateAsync budget is low; a long outage
  means players can't join (by design: never play on a default profile).
* `Profiles` replication sends the changed top-level fields of a profile on every change;
  fine at today's size, revisit if profiles grow large lists.

## Delivery Report

**Overview.** Both places load, save and release player profiles safely, share one store
(the Lobby read what a Run session saved), and gate sessions on the profile.

**Files created**: `game/server/Lib/ProfileSchema.luau`, `game/server/Services/ProfileService.luau`,
`studio/CodeInstaller.lua` (installs builds with one line), `game/reports/P02_SavedData.md`.

**Files modified**: `Services/SessionService.luau` (gates), `DevTools/DataTests.luau` (4 profile
tests), `DevTools/StructureCheck.luau` (Lib), `docs/ARCHITECTURE.md` (Saved data),
`tools/game_sync.py` (`tooling`, one-line `install`), `BUILD.json`.

**Integration notes**
* Read: `ProfileService:Get(player)`. Change: `ProfileService:Update(player, function(data) ... end)`.
* Glowshards: `AddGlowshards(player, n, reason)`, `SpendGlowshards(player, n, reason)`.
* ProcessReceipt (Prompt 28): `return ProfileService:GrantPurchase(player, receipt.PurchaseId, grant)`.
* Wait for a player's data with `SessionService.PlayerReady` or `ProfileService.Loaded`.
* Shape change: raise `ProfileSchema.VERSION`, add a migration, update `Default` and the shape.

**Testing checklist (done, 2026-11-08)**
* [x] Data tests (pure): new profile defaults; newer versions refused; missing fields
  reconciled without touching kept values; bad values rejected with the field named; a
  migration chain runs; receipts capped at 200 and hidden from the client.
* [x] Lock rules against the real Studio store (`profile.locktest`): new key claimed; fresh
  foreign lock refused; stale foreign lock taken over; newer version refused and left
  untouched; corrupt record refused.
* [x] Run playtest 1: new profile created, session ready only after it loaded, the client
  received its own profile; +25 Glowshards replicated and saved; stopping the playtest
  saved and released the lock (read back in Edit mode).
* [x] Run playtest 2: the profile reloaded with 25 Glowshards; receipt test-receipt-1 granted
  40 once, a repeat granted nothing more; a second receipt granted 5; all saved (70).
* [x] Lobby playtest: the same profile loaded in the other place (70 Glowshards, 2 receipts).
* [ ] Two servers at once (a real lock held by a live server): Prompt 21's teleport test.

**Future extension notes**
* Prompt 21 adds the MemoryStore rejoin record and the Lobby to Run handoff.
* Quests, class shop and badges (Prompts 21, 28, 29) write their fields through `Update`.
