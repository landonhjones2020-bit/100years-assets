# Prompt 7: Command View

The flat side view of the whole bunker (bible Section 7), opened with one button while the
character stays in the world. Built and tested on 2026-11-08: final build `p7-719607b` (code
asset 95026446991297 revision 21), installed in Run and Lobby. The Command View works in the
Run place; the Lobby has the code and the Frame's page but keeps the view off.

## Design Notes

**Decisions**
1. **The Frame in docked mode** (Section 7's last rule, Section 18).
   * The page is `Cabinet.Pages.CommandView`, built by `studio/ui/Frame_CommandView.lua`. It
     went into Studio as a patch, so the rest of the Frame keeps any AutoScale Lite pass.
   * The tab rail holds Build plus the bible's four overlays: Power, Morale, Threat and
     Production.
   * Zone C is open on the live bunker, with room labels, selection marks, ghosts and pings
     over it, clipped to the zone.
   * Zone D is the detail panel. The footer has Ping, and the main action is "Propose ...".
2. **The camera: far and narrow, but never more than 440 studs away.** Section 7 asks for "a
   far-away camera with a very narrow field of view".
   * Measured in Studio: at the lowest graphics level, Roblox stops drawing parts about 500
     studs from the camera (markers at 500 drew, 525 didn't; level 2 draws to about 800).
   * The first version put the camera 794 studs out. At level 1, the view showed nothing but
     the labels (`P07_Studio_before_fix.jpg`). Many phone players run level 1.
   * So the camera stops at `MaxDistance` (440 studs). Zoomed out past that, the field of view
     widens instead: 8 degrees close in, 14 at the opening 6 floors, 25 at the 11-floor limit
     (`Rules.CommandView.Lens`).
   * The view stays nearly flat, with a slight diorama look when zoomed far out.
   * Opening and closing: it opens centred on the character with a 0.3 s move (the bible's
     numbers). Closing moves back and hands the camera to CameraController.
   * Front walls hide while it's open, and the lighting lifts so rooms read from outside.
3. **The character stays and can be hit.**
   * Movement is held with a ContextActionService sink on the movement actions and jump.
   * Roblox's touch thumbstick and jump button hide (`GuiService.TouchControlsEnabled`).
   * A drop in health flashes the rust edge (`DamageEdge`).
4. **Opening and closing.**
   * Opens with Tab, the HUD's Command View button (top right), or the gamepad's View button.
   * Closes with Tab, Backspace, B or the close button.
   * Roblox marks Tab as processed before ContextActionService sees it, so InputController
     also reads it from UserInputService.
   * The same goes for the View button. `GuiService.AutoSelectGuiEnabled` is off so Roblox
     doesn't take that button for its own UI selection; our screens select for the gamepad
     themselves.
   * Roblox's player list is off in the run so Tab has one job (Bible Question 1).
5. **Moving around.**
   * PC: drag or WASD/arrows to pan, the wheel to zoom (1.5 to 11 floors), click a cell.
   * Touch: drag, pinch, tap.
   * Gamepad: the left stick pans, the right stick zooms, A picks the cell under the centre
     cursor, and D-pad up pings.
   * Picking casts from the camera through the point onto the cells' plane.
6. **The detail panel, by what's picked.** The client runs the bunker rules on the replicated
   cells and rooms (`Bunker.FromSnapshot`).
   * A room: condition, power draw, what it does. Options: Upgrade to the next level (with its
     cost), Merge with a matching neighbour (or why not), Tear Down.
   * An open cell: the build menu. Available rooms come first with their level-1 costs, then
     locked rooms with the reason: a blueprint draft, a draft or depth 2, Era II, or the first
     cryo pod. Fixed rooms (the Blast Door and the Reactor Core) come with the bunker and
     aren't listed.
   * Rock: whether it can be dug, using the bible's rule (left of, right of or below a dug cell
     or room), and the band's ore. A band's first floor notes that opening it needs a Push
     Deeper vote.
   * Nothing picked: rooms, open cells and depth.
7. **Proposals wait for votes.**
   * Choosing an option arms the main action ("PROPOSE LEVEL 2"). It stays greyed until a
     system calls `SetHandler`, which Prompt 8 does for Build, Upgrade, Merge and TearDown.
   * Nothing here spends or builds.
8. **Pings.**
   * The footer's Ping button, or G / D-pad up, sends `PingCell(floor, column)`. It is checked
     (floor 1 to 10, column -6 to 6) and rate-limited (3 at once, then one per 2 s).
   * `PingService` checks the session and the cell, then sends `CellPinged` to every ready
     player.
   * The pin shows for 6 s in the view and on each player's mini-map (Section 7: "it shows on
     every player's mini-map").
9. **Hooks for the systems that fill the view** (Section 7's other lines):
   * `SetOverlay(name, provider)`: a lamp per room on its label, with the legend at the top of
     the panel.
   * `ShowGhost` / `HideGhost`: a vote's outline.
   * `Blink(roomId, on)`: breaches and disasters.
   * Until those systems arrive, the dev commands show a sample of each.

**Design Risks**
* **The widest view shows about 5 columns by 8 floors.** The grid is 13 columns wide, so you
  pan to see the rest. Fitting all 13 columns within the 440-stud cap would need a 55 degree
  view, and rooms near the edges would show their side walls (Bible Question 2).
* At the 25 degree limit, rooms at the edges show a little of their side walls. If Landon
  wants it flatter, lower `MaxFloors`.
* **Labels at the far zoom nearly fill a one-cell room**, so two one-cell neighbours' labels
  may touch. A bigger bunker will show whether they need to shrink with the zoom.
* **The detail panel's text** is TextScaled per label (Prompt 6's Section template). A short
  line ("Iron in the Mines.") comes out large and a sentence comes out small. It reads like a
  stat over a description, but it isn't uniform.
* **The client's menu is a preview.** It runs the server's rules on replicated data, so for a
  moment after a change it could offer something the server will refuse. Prompt 8 re-checks
  everything on the server.

**Scope Risks**
These parts of Section 7 wait for their systems:
* Proposals and votes, and ghosts for open votes: Prompt 8.
* Power and Production readings, and rooms going dark: Prompt 9.
* Residents in the view and dragging them onto rooms:
  * portraits in their rooms, tap for the card, drag onto a room, Auto-Assign;
  * a room's workers and output.
  These come with Prompt 10.
* The Threat overlay and blinking breaches and monsters: Prompt 12.
* Status icons: burning and wrecked (Prompt 13), flooded (Prompt 23).
* Rock marked for the Drill Bay's dig queue and Push Deeper: Prompt 14. Cave hints: Prompt 17.
* The Morale overlay: Prompts 10 and 26.
* Unlocks won from the blueprint draft (Prompt 19) and from cryo pods (Prompt 17).
  `RoomChoice` already takes them; until then, every Draft room shows as locked.

**Bible Questions**
1. **Tab and Roblox's player list.** Section 7 gives Tab to the Command View, but Roblox uses
   Tab for its player list. As built, the player list is off during a run. Should the team
   list appear somewhere of ours (the Frame's top bar, or the HUD)? The vote kick in Prompt 30
   will need one anyway.
2. **The widest view vs "nearly flat".**
   * Phones on low graphics only draw about 500 studs, so the camera can't back off far
     enough to show the whole 13-column grid while staying flat.
   * As built, the widest view shows about 5 columns by 8 floors and you pan for the rest.
   * Alternatively, it could zoom out to the full width with clear perspective (rooms near the
     edges showing their side walls). Which do you want?

**Recommended Improvements**
* A "find me" key and footer button that re-centres on your character after panning away.
* Remember the zoom between openings. Section 7 fixes the centre, not the zoom.
* Name tags for other players in the view: at 6 floors a character is about 30 pixels tall.
* A slower, animated pin (a drop and a ripple) so a ping catches the eye on a busy HUD.

**Technical Risks**
* **Draw distance.** The 500-stud cut-off was measured in Studio's renderer. A live client on
  a real phone may differ, and Roblox can change it. Check on a phone with graphics at 1; if
  the bunker drops out, lower `MaxDistance`.
* **Mesh detail.** At 440 studs, meshes set to automatic detail may draw a lower level of
  detail. In Studio the A1 rooms looked right.
* **The gamepad's View button is untested.** The harness sends gamepad keys as keyboard
  input, which ContextActionService doesn't match. Turning off `AutoSelectGuiEnabled` also
  turns off Roblox's automatic gamepad selection everywhere; our Frame selects its first tab
  itself.
* **Holding the character** relies on Roblox's movement actions going through
  ContextActionService. If Roblox moves its controls elsewhere, keys could leak through. Tested
  on keyboard: D held for a second moved the character 0.00 studs, and Space didn't jump.

## Delivery Report

**Overview.** Tab, the HUD button or the View button opens the Command View in the run. It
shows a flat side view of the live bunker, with labels, selection, a build menu with costs and
unlocks, room options, rock details, overlays and pings. The character stays where it was and
the screen edge flashes when it is hit. It draws on the lowest graphics level too. Proposals are
armed but greyed out until votes arrive in Prompt 8.

**Files created**
* `game/client/Controllers/CommandViewController.luau`.
* `game/places/Run/server/Services/PingService.luau`.
* `game/shared/Rules/CommandView.luau`.
* Layout:
  * `studio/ui/Frame_CommandView.lua` and `studio/ui/HUD_MapPing.lua`, included by
    `Frame.lua` and `HUD.lua`;
  * the patches `studio/ui/patches/Frame_P07.lua`, `Frame_P07b.lua` (zone C clips, in place)
    and `HUD_P07.lua`.
* `game/reports/P07_CommandView.md`.
* `previews/Game/P07_Studio_*.jpg` and `P07_Studio_sheet.jpg`.

**Files modified**
* Shared:
  * `game/shared/Rules/Bunker.luau`: `FromSnapshot`; the dig reason worded as in the bible.
  * `game/shared/Config/Tuning.luau`: `CommandView` (with `MaxDistance`) and `Ping`.
  * `game/shared/Remotes.luau`: `PingCell` and `CellPinged`.
  * `game/shared/UIContract.luau`: the page, the damage edge, the templates, and the HUD's
    `MapPing`.
* Client controllers:
  * `InputController.luau`: Tab and the View button read when processed, and
    `AutoSelectGuiEnabled` off.
  * `UIController.luau`: the `GamepadSelect` option.
  * `HUDController.luau`: the player list off in the run.
  * `MiniMapController.luau`: pings.
  * `DevController.luau`: the `cv.*` commands.
* Server checks:
  * `StructureCheck.luau`: the new skeleton entries.
  * `DataTests.luau`: 68 tests, including the lens, the cell box, the bounds, the build menu
    and `FromSnapshot`.
* `studio/ui/Builder.lua`: a `clip` option.
* `game/docs/ARCHITECTURE.md`: a Command View section, input notes, services, dev commands
  and the prompt log.
* `game/BUILD.json`: prompt 7.

**Architecture**
* `CommandViewController` (client) depends on InputController, CameraController,
  UIController, ReplicaController and HUDController. It registers its screen with
  UIController and borrows the camera from CameraController (`Suspend` / `Resume`).
* It updates each frame just before Roblox's camera step (`RenderPriority.Camera - 1`).
* The arithmetic is in `Rules.CommandView`, which the server tests: lens, cell boxes, bounds,
  clamping, the build menu's unlock rules and cost text.
* `PingService` (Run, server) is the only writer of pings. `MiniMapController` and the view
  both listen to `CellPinged`.

**Integration notes**
* **Votes (Prompt 8).**
  * `CommandViewController:SetHandler("Build" | "Upgrade" | "Merge" | "TearDown", function(choice) ... end)`.
    The choice has Action, Floor, Column, RoomType, Level, RoomId and Other (the room a merge
    joins).
  * `ShowGhost(voteId, floor, column, span, label)` while a vote is open, `HideGhost(voteId)`
    when it closes.
  * The HUD's `VoteBanner` is ready from Prompt 6.
* **Power and production (Prompt 9).** Call `SetOverlay("Power", function(roomId, room) return "Lamp_Green" end)`.
  Use `Lamp_Amber` or `Lamp_Red` for other readings. The same goes for `Production`.
* **Residents (Prompt 10).** Add a portrait layer over zone C (a new template), a resident card
  in the detail panel, and the room's workers in `showRoom`.
* **Threats and disasters (Prompts 12 and 13).** `Blink(roomId, true)` and
  `SetOverlay("Threat", ...)`.
* **Digging (Prompt 14).** A "Mark for the Drill Bay" option in `showRock`. Push Deeper is a
  vote (Prompt 8's handler).
* **Unlocks (Prompts 17 and 19).** Fill `context().Unlocked` with the room types won.

**Testing checklist (done in Studio, 2026-11-08)**
* [x] Installed in both places: StructureCheck 0 errors (Run 282 checks, Lobby 206), 68 data
  tests passed.
* [x] Run playtests with real input (Studio's input tool, whose y excludes the 87-pixel top
  bar, confirmed against `GetMouseLocation`):
  * **Opening.** A real Tab opened it at 6 floors, 440 studs and 14 degrees, centred on the
    character. A real Left Alt and a click on the HUD's Command View button also opened it.
  * **Zoom.** The wheel zoomed out to 11 floors (25.4 degrees, still 440 studs) and back. The
    wheel over the menu scrolled the menu without zooming.
  * **Picking with real clicks.**
    * Open cell 2,3: 9 rooms with costs, then 10 locked with reasons.
    * The Quarters: 1000 of 1000 HP, Draws 2, Upgrade at 360 SCRAP · 30 IRON, and Tear Down.
    * Rock 3,2: can be dug, Iron in the Mines.
  * **Proposing.** A click on Upgrade armed "PROPOSE LEVEL 2", greyed out.
  * **Panning.**
    * A 300-pixel drag panned 29 studs and kept the selection.
    * D held for 1 s panned 33 studs. The character moved 0.00 studs and Space didn't jump.
  * **Pings.** The footer's Ping and G each reached the server ("pinged 2,3" twice). The pin
    showed in the view and on the HUD mini-map.
  * **Damage.** Two hits from the server flashed the edge twice.
  * **Closing.** Tab and Backspace each closed it: the camera came back to the shoulder at 70
    degrees and the HUD returned. Touch controls were off while it was open and back on after.
  * **Hooks.** With dev samples: overlay lamps on the labels and the legend at the top, a ghost
    outline, and a blinking label.
  * **Graphics level 1.**
    * Before the fix the view was empty.
    * Measured cut-offs: level 1 draws to 500 studs but not 525; level 2 to 800 but not 900.
    * After the fix, level 1 draws the bunker at 6 and at 11 floors.
* [x] Lobby playtest: a clean start with 8 controllers. The Command View stays off.
* [ ] A gamepad: the View button, the sticks, A and D-pad up.
* [ ] A phone:
  * tap, drag and pinch;
  * the HUD button;
  * Roblox's thumbstick hidden while the view is open;
  * graphics level 1 on the device.
* [ ] Two players: one player's ping on the other's view and mini-map.
* [ ] Landon's AutoScale Lite pass, including the new page.

**Future extension notes**
* A new kind of detail (a resident card) is a `showX` function using `section` and
  `optionRow`, called from `refreshDetail`.
* A new overlay needs a tab in the layout, a line in `OVERLAY_TEXT` and a provider from its
  system.
* Anything new drawn over zone C goes in `View.Marks` or `View.Labels` and is placed each frame
  from world positions (`cellRect`, `pointIn`), so it follows pan and zoom.
