# Prompt 8: Votes and construction

Team votes (bible Section 8) and building, upgrading, merging and tearing down rooms (Section
6), with the team's stockpile they spend. Built and tested on 2026-11-08: final build
`p8-f9a192c` (code asset 95026446991297 revision 24), installed in Run and Lobby. Votes and
construction work in the Run place. This prompt also built Landon's answers to the Prompt 6
and 7 questions (addenda in `P06_FrameHUD.md` and `P07_CommandView.md`).

## Design Notes

**Decisions**
1. **The stockpile came with this prompt.** Construction has to pay, and Section 23 gives the
   stockpile to EconomyService.
   * Prompt 8 builds only the stock: every resource in Config.Resources from its Start amount
     (Section 6: 300 Scrap, 30 Food, 30 Water, 4 Medkits, 200 Ammo).
   * Caps: Cap, plus CapPerStorageCell for each Storage cell.
   * Lab research starts at 0.
   * Amounts replicate as RunState values (Section 23: resources as attributes), and the HUD's
     chips show them.
   * Production, consumption and power stay with Prompt 9.
2. **How votes run** (Section 8, using Rules.Votes):
   * a build passes with more yes than no after 15 s;
   * not voting is abstaining, and ties fail;
   * everyone yes passes at once;
   * one open proposal per player, and a failed one means a 20 s cooldown;
   * solo runs skip the vote;
   * costs are checked again when a vote passes.
   Where the bible doesn't say, I chose:
   * **The proposer counts as a yes** (Bible Question 4).
   * **A player can change their vote** until it closes.
   * **One vote is on the telegram at a time.** Later proposals queue, and each gets its full
     15 s once it is live, so no vote runs out unseen. The telegram shows "1 WAITING".
   * **"Spending more than 40% of a stockpile"** means any single resource costing more than
     40% of what the team holds of it. It is judged when the vote goes live.
3. **Construction** (Section 6: "a team vote, then 20 seconds of construction per cell...
   players and residents nearby speed it up"):
   * A new room becomes a construction site: 20 s a cell, and 25% faster for each player standing
     in its cells (Tuning.Rooms.HelperBuildSpeed). Residents join with Prompt 10.
   * In the world the site shows the coming room's art, see-through and firming up as it builds,
     behind a timber scaffold with a hazard-striped plank. It is graybox until there's scaffold
     art, and nothing on it collides.
   * Upgrades, merges and tear-downs apply as soon as their vote passes (Bible Question 2).
   * Upgrade costs are per cell, like HP and power, so a merged 2-cell room pays twice. Without
     that, merging and then upgrading would be a discount.
   * Level 3 needs Lab research. Research is a threshold the Lab reaches, not something spent
     (Section 6: research "unlocks" level 3).
   * Tearing down gives nothing back, because the bible names no refund (Bible Question 1).
4. **The vote telegram has its own ScreenGui above The Frame** (`StarterGui.Votes`).
   * The HUD hides whenever a Frame screen opens, and the Command View is a Frame screen. A
     vote is timed, so it has to be answerable from any screen.
   * It shows what is proposed and its cost, then who proposed it, the tally and the time. It
     also says what the vote needs when that isn't the usual more yes than no ("2 OF 3 MUST SAY
     YES"), and how many votes are waiting.
   * A strip along its foot runs down with the time, and YES and NO stay pressed in to show your
     vote.
5. **What the Command View shows now:**
   * an open cell under construction shows its progress and "stand in the cell to build it
     faster";
   * a cell or room with an open proposal shows the proposal and offers nothing else;
   * rows the stockpile can't pay show what's short ("150 SCRAP · 30 SCRAP SHORT");
   * in a solo run the main action says Build, Upgrade, Merge or Tear down instead of Propose;
   * ghosts mark open proposals ("KITCHEN?", "LEVEL 2?") and sites ("KITCHEN 45%").
6. **Alerts follow the player into menus.** While a Frame screen hides the HUD, its alerts (a
   refused proposal, "MEDBAY UPGRADED TO LEVEL 2", "SHAFT BUILT") show in the Frame's footer
   for 4 s.
7. **Landon's answers (Prompts 6 and 7):**
   * **Ready** has its own key: Z on PC and D-pad down on console. The bible gave no key, so the
     choice is mine: they are the free controls nearest each pad. The button shows a key chip.
   * **The cursor:** "use the scroll wheel" became a click of the mouse wheel to free the cursor
     for HUD buttons and the telegram, and another click to lock it again. This replaces holding
     Left Alt.
   * **The ore chips:** the Copper and Crystal chips appear once the team has dug into their
     bands.
   * **No team list:** Roblox's player list stays off.
   * **The Command View** pans for the rest of the bunker.

**Design Risks**
* **Silence passes proposals.** With the proposer's yes, a proposal nobody answers passes. That
  fits "silence counts as abstain", but an idle team can't stop a careless spender. A big spend
  (over 40%) still needs a majority, anyone can vote no, and the vote kick comes with Prompt 30.
* **Six proposals at once wait up to 90 s in the queue.** Playtests will show whether teams
  hit this.
* **Voting on PC mid-fight takes a wheel click, then a click** (Bible Question 3), and a gamepad
  can't vote yet.
* The telegram's lines are TextScaled, so a long player name shrinks line 2. A 20-character
  name still read at 12 px in Studio.

**Scope Risks**
* No vote sounds yet. VoteController plays `SoundService.VoteOpen` and `VotePassed` when they
  exist (Prompt 32, audio).
* Residents speeding up construction: Prompt 10.
* The Warden breaking ties: Prompt 20 (`VoteService:SetTieBreaker`).
* The other votes use the same service when their systems arrive:
  * Push Deeper (Prompt 14);
  * Keep Going (15);
  * the blueprint draft (19; `Rules.Votes.Winner` is ready);
  * Let them in? and kicks (30).
* Repairs: Prompt 13.
* Lab research production: Prompts 9 and 10. Until then level 3 can't be reached.
* The Power, Morale, Threat and Production overlays still show sample readings only.

**Bible Questions**
1. **Tear-down refunds.** Tearing down a room gives nothing back. Should it return part of the
   room's cost?
2. **Upgrade time.** Section 6 gives construction time for building (20 s a cell). Upgrades,
   merges and tear-downs apply as soon as their vote passes. Should upgrades take construction
   time too?
3. **Vote keys.** The controls table has none. On PC, players free the cursor with the mouse
   wheel and click YES or NO (in the Command View the cursor is already free); on touch they
   tap; a gamepad can't vote yet. Should votes get their own keys, and which?
4. **The proposer's vote.** The proposer counts as a yes, so a proposal nobody else answers
   passes. Is that right, or should a proposal need a second yes?

**Recommended Improvements**
* Vote chimes and a short "click" when a button latches (Prompt 32).
* Name the proposer's class colour on the telegram when classes arrive (Prompt 20).
* A "cancel my proposal" button for the proposer while their vote is queued.
* Scaffold art for construction sites (`Kit_Scaffold`) on the art track, with sparks and a
  little dust while it builds.

**Technical Risks**
* `StarterGui.Votes` draws above The Frame (DisplayOrder 6). It is slim and only shows during a
  vote, but it sits over the top of whatever screen is open.
* Site progress replicates at most once per 1%. The coming room's transparency changes in 5%
  steps on the server: about 12 changes per site.
* Pretend voters are Studio-only (`vote.bots`), and count in the team's size in every rule.

## Delivery Report

**Overview.** Players propose from the Command View, and the team votes on a telegram that
shows what, the cost, who, the tally and the time. Passed proposals pay from a real stockpile
and become construction sites, upgrades, merges or tear-downs. Solo players build at once. The
HUD shows the stockpile, Ready has its own key, and the vote telegram can be answered from any
screen.

**Files created**
* Server, Run place:
  * `game/places/Run/server/Services/EconomyService.luau`;
  * `VoteService.luau`;
  * `BuildService.luau`.
* `game/shared/Rules/Votes.luau`, `game/shared/Rules/Construction.luau`.
* `game/client/Controllers/VoteController.luau`.
* Layout:
  * `studio/ui/Votes.lua` (the telegram's ScreenGui) and `studio/ui/HUD_ReadyKey.lua`;
  * patches `studio/ui/patches/Votes_P08.lua` (moves the telegram out of the HUD, adds its
    timer, widens line 2), `HUD_P08.lua` (Ready's key chip) and `Frame_P08.lua` (ghost labels
    outlined, low in the cell).
* `game/reports/P08_VotesConstruction.md`.
* `previews/Game/P08_Studio_*.jpg` and `P08_Studio_sheet.jpg`.

**Files modified**
* Shared:
  * `game/shared/RunState.luau`: stock values from Config.Resources, Research, and the
    EconomyService writer.
  * `game/shared/Remotes.luau`: `Propose`, `CastVote`, `Alert`.
  * `game/shared/Config/Tuning.luau`: `Votes.ResultSeconds`.
  * `game/shared/UIContract.luau`: the Votes screen, the timer, Ready's key.
  * `game/shared/Rules/CommandView.luau`: unlocks and cost text from Rules.Construction.
* `game/places/Run/server/Lib/BunkerKit.luau`: `Site` and `SetSiteProgress`.
* Client controllers:
  * `CommandViewController.luau`:
    * sites, proposals and costs in the panel, Build in solo, ghost labels;
    * refreshes that keep the menu's scroll;
    * the main action clears after proposing.
  * `HUDController.luau`: stock chips, alerts (also to the Frame's footer), the Ready key, the
    wheel cursor, ore chips by depth.
  * `UIController.luau`: `Notice`.
  * `InputController.luau`: the Ready binding.
  * `DevController.luau`: `vote`.
* `game/client/Lib/KitRuntime.luau`: latched buttons.
* Server checks:
  * `StructureCheck.luau`: the new modules; NS_Pipeline is a warning.
  * `DataTests.luau`: 71 tests, including the vote rules, construction plans, upgrade costs per
    cell and RunState's stock.
* Layout builders: `studio/ui/HUD.lua` (no telegram; Ready's key), `studio/ui/Frame_CommandView.lua`
  (ghost labels).
* Docs and runbook:
  * `game/docs/ARCHITECTURE.md`;
  * `game/BUILD.json` (prompt 8);
  * `CLAUDE.md` (the NS_Pipeline rule).

**Architecture**
* **Server** (Run):
  * EconomyService depends on BunkerGrid, for the Storage caps.
  * VoteService depends on SessionService and ReplicationService.
  * BuildService depends on both, plus BunkerGrid.
  * Only BuildService opens construction votes, and only EconomyService changes the stock.
* **Client:** VoteController reads the Votes and Sites collections. It draws the telegram and
  the ghosts, and it gives the Command View its Propose handlers.
* **Rules:** the server and the Command View use the same pure rules (`Rules.Construction.Plan`,
  `Rules.Votes`). The client's menu is a preview, and the server checks everything again.

**Integration notes**
* **Economy and power (Prompt 9).** `EconomyService:Add(id, amount, reason)` for production; a
  consumption pass on `CycleClock.CycleStarted`; the HUD's Power chip and lamp
  (`HUDController:SetResource("Power", text, lamp)`); `CommandViewController:SetOverlay("Power",
  ...)`.
* **Residents (Prompt 10).** Count residents working in a site's cells in
  `BuildService`'s helpers.
* **Repairs (Prompt 13).** In BuildService, as Section 23 lists.
* **Push Deeper (Prompt 14).**
  `VoteService:Open({ Kind = "PushDeeper", Proposer = player, Title = "PUSH DEEPER", Check = ..., OnPass = dig })`.
  The kind's rule is already a whole-team majority.
* **Keep Going (15), Let them in? (30), kicks (30).** The same Open, with their kinds.
* **The draft (19).** It needs options on a vote (a MostVotes kind): add `Spec.Options` and
  pick the winner with `Rules.Votes.Winner`. The telegram needs a card layout for it.
* **The Warden (20).** `VoteService:SetTieBreaker(function(voteId) return wardenSaysYes end)`.
* **Drafts and cryo pods (17, 19).** `BuildService:Unlock(roomType)`.
* **Audio (32).** `SoundService.VoteOpen` and `SoundService.VotePassed`.

**Testing checklist (done in Studio, 2026-11-08)**
* [x] Installed in both places: StructureCheck 0 errors (Run 307 checks, Lobby 213), 71 data
  tests passed.
* [x] Run playtests, solo:
  * The HUD showed 30 Food, 30 Water, 300 Scrap, 0 Iron and 200 Ammo, with no Copper or Crystal
    chips.
  * **Build.** In the Command View, real clicks picked the open cell 2,3, then Workshop
    (scrolled into view), then "BUILD WORKSHOP". It applied at once: 150 Scrap spent, site S1,
    the panel at "UNDER CONSTRUCTION 23%", the ghost "WORKSHOP 25%".
  * **Helping.** With my character in the cell, 2.6 s of work went into 2 s (1.25x). The
    Workshop (R9) was placed when it finished.
  * **Merge.** A second Workshop at 2,4, then real clicks on "MERGE WITH THE WORKSHOP" and
    "MERGE": one 2-cell Workshop with 1000 HP. Its upgrade then showed 520 SCRAP · 60 IRON.
  * **Tear down.** The Kitchen went and its cell opened, with nothing refunded.
  * **Storage.** Building it raised every cap, to Scrap 1500 and Food 150.
* [x] Run playtests, a team of 3 (me and two pretend voters):
  * **The upgrade vote.** Real clicks proposed the Medbay upgrade. The telegram showed over the
    Command View with the Medbay's ghost. It passed after 15 s with one yes and two
    abstentions: level 2, 800 HP, 260 Scrap and 25 Iron spent.
  * **A tie** (1 yes, 1 no) failed: "FAILED: A TIE". Proposing again at once was refused (the
    cooldown).
  * **The 40% rule.** A Drill Bay costing 220 of 400 Scrap needed "2 OF 3 MUST SAY YES". It
    failed with one yes; after the cooldown, 2 yes kept it open and the 3rd passed it at once.
  * **The re-check.** A Generator vote passed with everyone yes after the stock dropped to 50.
    It failed with "THE STOCKPILE IS 100 SCRAP SHORT" and nothing was spent.
  * **The queue.** Two votes at once: the second waited ("1 WAITING") and went live with its
    full 15 s.
  * **The telegram's buttons.** A real click on YES latched it. Real clicks on YES then NO
    changed the vote to NO (only NO latched).
  * **The Quarters upgrade.** With its vote open, the Quarters offered nothing and said
    "PROPOSAL OPEN". Its ghost "LEVEL 2?" read over the cream room.
  * **Results.** PASSED and FAILED showed for 3 s, or 1.5 s when the next vote was waiting.
  * **Alerts.** "MEDBAY UPGRADED TO LEVEL 2" and "SHAFT BUILT" showed in the Command View's
    footer.
* [x] Landon's answers:
  * A real Z press at the start of a day marked me ready and skipped the day to the siren.
  * The Ready chip shows "Z" with a keyboard and "DOWN" with a gamepad.
  * The site in the world, seen from inside, showed the scaffold and the Workshop firming up.
* [ ] Two real players: a vote between two clients, and one player's ghost on the other's
  Command View.
* [ ] The mouse-wheel click freeing the cursor (Studio's input tool can't press the wheel).
* [ ] A gamepad: D-pad down for Ready. A phone: tapping YES and NO.
* [ ] Landon's AutoScale Lite pass, now including StarterGui.Votes (Run).

**Future extension notes**
* A new kind of vote is an entry in Config.Votes plus a `VoteService:Open` call. Its rule comes
  from the entry, and the telegram needs nothing new for yes/no votes.
* A new kind of construction is an action in `Rules.Construction.Plan`, a case in
  BuildService's `apply`, and a row in the Command View.
