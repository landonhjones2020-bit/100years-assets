# Prompt 5: Over-the-shoulder camera with wall fade and zoom caps

The player's camera and the input layer under it (bible Sections 9 and 26: "wall fade and
zoom caps built and tested in prompt 5, before anything depends on them"). Built and tested
in Studio on 2026-11-08, latest build `p5-d690a7c` (code asset 95026446991297 revision 12),
both places. The same builds carry Landon's answers to the
Prompt 3 and 4 Bible Questions; see the addenda in `P03_RunLifecycle.md` and
`P04_BunkerGrid.md`.

## Design Notes

**Decisions**
1. **Four pieces, one job each.**
   * `InputController` turns PC, touch and gamepad input into the actions of the bible's
     controls table.
   * `CameraController` is the camera.
   * `Lib.Fade` makes world parts see-through on this client only.
   * `Shared.Rules.CameraRig` is the geometry, pure and tested; `Tuning.Camera` holds the
     numbers (all provisional).
2. **Our own camera, with Roblox's kept as the fallback.** The controller sets the camera to
   Scriptable and updates it in `BindToRenderStep` just after Roblox's camera step. Roblox's
   camera scripts stay loaded. If the update errors 5 times in a row, the controller stops and
   hands the camera back to Roblox, with Invisicam set in both places
   (`StarterPlayer.DevCameraOcclusionMode`). That is the bible's fallback.
3. **The mouse is locked to the centre on PC.** The controls table puts Aim on the right
   mouse button, so looking can't be Roblox's right-drag. Mouse movement looks, the cursor is
   hidden and a sight sits in the centre. Roblox's own shift-lock option is turned off so
   there is only one mode. The cursor is free while the Roblox menu is open, on touch, and
   whenever a screen asks for it (`FreeCursor`).
4. **The shoulder.** Over the right shoulder by default; Swap Shoulder (V, the right stick
   click) slides it to the other side in 0.18 s.
5. **Aim (Run place only; the lobby has no guns).**
   * The view narrows from 70 to 50 (`Tuning.Player.AimFieldOfView`, the bible's numbers).
   * The camera comes in to 6 studs and moves 1.25 studs off the shoulder, so the head never
     covers the sight.
   * Walking slows to 60% (provisional; the bible says only "slows walking").
   * The character turns with the camera, so what the sight covers is what a gun will face.
6. **Zoom caps.**
   * The wheel or a pinch zooms between 4 and 16 studs (default 9), and at most 11 in a
     bunker cell (provisional).
   * A sphere cast from the head out to the shoulder, then back along the view, stops the
     camera at floors, walls, slabs and rock. The camera pulls in at once and eases back out,
     so it never shows the inside of rock.
   * In a cell the camera also stays between the floor and the ceiling panels by sliding in
     along its view. Shafts are open overhead and exempt, so the stair climb works.
7. **Wall fade.**
   * Front walls (`FrontWall` tag) and furniture, rails, the stair and dug-cell props
     (`CameraFade` tag) never stop the camera.
   * Each frame, rays from the camera to the head, the root and the shoulder find the tagged
     parts in the way, and a small sphere around the camera finds the parts it touches. Those
     fade: front walls fully, furniture to 80%, over 0.12 s.
   * So the camera can stand outside a room's open front, and players see their character
     instead of a wall.
   * The local character fades as the camera comes within 2.2 studs of the head.
   * Fades use `LocalTransparencyModifier`, so each player's fades are their own.
8. **Characters never block the camera**, and anything tagged `CameraIgnore` is passed
   through. Residents and monsters will carry that tag.
9. **Input actions** come from the controls table: Fire, Aim, Melee, Reload, Interact,
   Ability, Sprint, Dodge, Swap Shoulder, Hotbar 1 to 5, Ping and Command View.
   * They are bound with ContextActionService above Roblox's priority and pass the input on,
     so moving and jumping stay Roblox's.
   * Look speed is multiplied by the player's own Roblox camera sensitivity, so their
     settings carry over.
10. **The sight.** `StarterGui.Reticle` (built by `studio/ui/Reticle.lua` in each place):
    * a dot, plus four ticks that close in when aiming;
    * cream with a navy outline, from the palette;
    * `ScreenInsets None` and `IgnoreGuiInset`, because it must sit on the viewport's true
      centre, where the camera looks, not the centre of the safe area;
    * shown only while the mouse is locked; the lobby shows the dot only.
11. **A new character looks the way it spawned**, into the room from the Medbay pad.
12. **Seams closed (found by the camera tests).** Multi-cell rooms showed a 2-stud gap between
    cells in the ceiling, the back wall's wainscot and the front wall's trim. BunkerKit now
    puts a steel beam (palette steel) across the ceiling seam and steel posts on the back and
    front seams. They don't collide, and the front post fades with its wall.

**Design Risks**
* The zoom range (4 to 16, 11 indoors), the aim distance and the 60% aim walk speed are
  provisional and need a playtest by people.
* The locked mouse is normal for shooters but new to some Roblox players. Menus must free the
  cursor (Integration notes), or players will feel trapped.
* Steep looks up or down in a 16-stud cell slide the camera in toward the character. This
  keeps the camera out of the ceiling, but it needs a person's feel test.

**Scope Risks**
* Aim assist (Section 9: "a soft pull toward the nearest target in a small cone") needs
  targets, so it comes with combat (Prompt 11). `Tuning.Player.AimAssistDegrees` is ready.
* Touch Aim and Shoulder buttons come with the HUD (Prompt 6); the actions already work.
* The Marksman's "longer aim zoom" (Prompt 20) needs a hook in the camera's aim distance.

**Bible Questions**
1. The controls table has no zoom for console players. As built, gamepads keep the default
   distance (9 studs) unless aiming. Should D-pad down step through three zoom distances, or
   is one fixed distance right for console?

**Recommended Improvements**
* Settings screen (its Controls rows, bible Section 18): camera sensitivity
  (`CameraController:SetSensitivity`), aim sensitivity, invert Y and the starting shoulder.
* A small camera-kick API for combat feel (recoil, hits, explosions), added with Prompt 11.
* Command View (Prompt 7): reuse `Lib.Fade` for the front walls (Integration notes) rather than
  changing their real transparency, so each player's view stays their own.

**Technical Risks**
* **Untested look input.** Studio's synthetic mouse moves give no movement while the mouse is
  locked, and a synthetic stick press doesn't turn the camera. Mouse look, stick look, touch
  drag and pinch need a person (Testing checklist).
* **Frame cost.** Per frame the camera runs two sphere casts, up to three rays with up to four
  hits each, and one small overlap query. It should cost well under a millisecond, but the
  phone pass (Prompt 34) must measure it.
* **Walk speed.** The camera sets the walk speed while aiming and puts back the speed it found.
  Once Sprint, classes (the Scout's +20% on the surface) and conditions also change it, one
  movement owner must combine them (Prompt 11).
* **Facing.** While aiming, the client turns its own character, and the turn replicates
  through physics ownership. Server gun checks (Prompt 11) must not trust facing; Section 9
  already checks line of sight and the target's position.

## Delivery Report

**Overview.** Both places now use the game's own camera, over the right shoulder.
* V or the right stick swaps shoulders.
* In the Run, the right mouse button or left trigger aims: the view narrows to 50, the camera
  comes in, walking slows and the character turns with the camera.
* The wheel or a pinch zooms, capped at 11 studs inside a cell.
* The camera never ends up inside rock or the ceiling.
* Front walls and furniture fade out when they come between the camera and the player.

**Files created**
* `game/client/Controllers/InputController.luau`: actions, devices, look and zoom input,
  touch-button hookup.
* `game/client/Controllers/CameraController.luau`: the camera.
* `game/client/Lib/Fade.luau`: see-through parts on this client, several sources per part.
* `game/shared/Rules/CameraRig.luau`: the camera's geometry, pure.
* `studio/ui/Reticle.lua`: builds `StarterGui.Reticle` and sets `StarterPlayer`'s camera
  settings; run once per place.
* `game/reports/P05_Camera.md`.
* `previews/Game/P05_Studio_shoulder.jpg`, `_aiming.jpg`, `_front_fade.jpg`, `_lobby.jpg` and
  `_seams.jpg`.

**Files modified**
* `game/shared/Config/Tuning.luau`: the `Camera` block (schema and values).
* `game/client/Controllers/DevController.luau`: camera commands; `clock` shows when a Surge has
  no timer.
* `game/server/DevTools/StructureCheck.luau`:
  * the new controllers, `Lib.Fade`, `Rules.CameraRig` and the Reticle;
  * Invisicam set and shift-lock off.
* `game/server/DevTools/DataTests.luau`: camera geometry tests (and the answer tests); 60 in
  all.
* `game/places/Run/server/Lib/BunkerKit.luau`:
  * `CameraFade` tags on interiors, the Blast Door, the stair, vents, hole rails and props;
  * the seam beam and posts.
* `game/docs/ARCHITECTURE.md` (The camera and input, services, dev commands) and
  `game/BUILD.json`.
* Landon's answers: `Rules/Clock`, `RunState`, `ObjectiveService`, `CycleClock` and
  `Rules/Bunker` (see the P03 and P04 addenda).

**Architecture**
* Client controllers, in order: InputController, then CameraController (which also needs
  ReplicaController), then DevController.
* CameraController owns, while it is active:
  * the camera itself;
  * the mouse behaviour and the Reticle's visibility;
  * the local character's fade;
  * the Humanoid's `WalkSpeed` and `AutoRotate` while aiming.
* `Lib.Fade` lets several sources (the camera now, the Command View later) fade the same part.
  The strongest fade wins, and each source clears only its own.
* The geometry is pure (`Rules.CameraRig`), so the data tests run it on the server in Edit.

**Integration notes**
* **HUD (Prompt 6).**
  * Touch buttons for the controls table: `InputController:BindButton("Aim", button)`,
    `BindButton("SwapShoulder", button)` and the rest.
  * Draw the HUD under the Reticle (Reticle `DisplayOrder` is 2). The camera already shows
    and hides the sight.
* **Menus and the Frame.** `CameraController:FreeCursor("<screen>", true)` when a screen opens,
  `false` when it closes.
* **Command View (Prompt 7).**
  1. `CameraController:Suspend("CommandView")` and `FreeCursor("CommandView", true)`.
  2. `Fade.Set(part, "CommandView", 1)` for every `FrontWall` part (watch the tag, because
     rebuilt rooms get new walls).
  3. On close: `Fade.ClearSource("CommandView")`, then `Resume`.
* **Cutscene (Prompt 22).** `Suspend("Cutscene")` and `Resume("Cutscene")`.
* **Combat (Prompt 11).**
  * `CameraController:IsAiming()` and the `AimChanged` signal.
  * `State()` gives yaw and pitch for firing from the camera's look.
  * Aim assist uses `Tuning.Player.AimAssistDegrees`.
  * Take over walk speed (see Technical Risks).
* **Residents and monsters (Prompts 10 and 12).** Tag their models `CameraIgnore` so they never
  push the camera in.
* **New world parts.** Tag them `CameraFade` if they should fade rather than block, or
  `FrontWall` if the Command View should hide them too.
* **Classes (Prompt 20).** The Marksman's longer aim zoom is a modifier the camera should read
  for its aim distance.
* **Settings.** `CameraController:SetSensitivity(multiplier)`.

**Testing checklist (done in Studio, 2026-11-08)**
* [x] Installed `p5-d690a7c` in both places: StructureCheck 0 errors, 60 data tests passed.
* [x] Run playtest:
  * The camera starts over the right shoulder.
  * A real V key press (Studio's keyboard input) swapped it to the left.
* [x] Holding the right mouse button aimed: field of view 50, distance 6, walk speed 9.6,
  AutoRotate off, the character turned to the camera. Releasing it put back 70, 16 and
  AutoRotate. Screenshot `P05_Studio_aiming.jpg`.
* [x] Zoom and blocking:
  * The scroll wheel zoomed, capped at 11 studs indoors.
  * The back wall and solid side walls pulled the camera in (to 3.2 studs).
  * Through a doorway the camera went into the open room next door.
* [x] Standing near a room's front, the camera went outside it and the front wall faded
  (`P05_Studio_front_fade.jpg`).
* [x] Floor and ceiling limits held. 48 random looks and zooms across the rooms left the
  camera in rock 0 times.
* [x] Climbing the Shaft stair: the camera followed, with a brief pull-in at the slab.
* [x] Lobby: no aiming, dot-only sight (`P05_Studio_lobby.jpg`).
* [x] Multi-cell rooms: the ceiling beam and wall posts close the seams
  (`P05_Studio_seams.jpg`).
* [ ] Mouse look, gamepad stick look, touch drag and pinch: need a person, because synthetic
  input gives no movement while the mouse is locked.
* [ ] Phone frame rate and the Device Emulator.
* [ ] The AutoScale Lite pass on the Reticle (bible Section 18).
* [ ] Two players (each client fades only its own view): Team Test.

**Future extension notes**
* Other views (the Command View, cutscenes, a downed spectate if the bible adds one) suspend
  this camera instead of adding modes inside it.
* All numbers are in `Tuning.Camera`; the controller holds only tags and render priorities.
* A console zoom binding (Bible Question 1) is one line in InputController's `BINDINGS` plus
  `TakeZoom`.
