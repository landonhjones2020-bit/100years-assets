# Prompt 6: The Frame and HUD skeleton, ready for the AutoScale Lite pass

The one menu layout and the run HUD (bible Section 18), built in Studio from the UI kit and
driven by the game code. Built and tested on 2026-11-08: latest build `p6-c29648b` (code
asset 95026446991297 revision 15). The Frame is in both places; the HUD is in the Run place.

## Design Notes

**Decisions**
1. **Layout in Studio, code fills it in** (Section 18, rule 1).
   * `studio/ui/Frame.lua` and `studio/ui/HUD.lua` build the instances through the connector,
     with a new layout-only builder (`studio/ui/Builder.lua`).
   * The new GUIs carry no scripts, unlike the A0 samples. The runtime work that the A0 GUIs
     did in embedded scripts (9-slice and stroke scaling, push-button states) is now game
     code: `Lib.KitRuntime`.
   * The A0 sample screens moved to `ServerStorage.UIArchive` in the Run place.
2. **A contract between layout and code.** `Shared.UIContract` lists the 98 parts the
   controllers use. StructureCheck fails if one is missing, so a rebuilt or hand-edited
   screen can't drift away from the code. StructureCheck also checks Section 18's rules:
   * safe insets, ResetOnSpawn off and Sibling ZIndex;
   * Scale-only sizes;
   * TextScaled text with a 12-pixel minimum;
   * no scripts inside a GUI.
3. **One Frame, pages per screen.**
   * Zones as the bible draws them: A top bar 10%, B tab rail 16%, C content about 54%,
     D detail 30%, E footer 7%. The look is the approved A0 Class Shop.
   * A screen is a page filling B, C and D: a clone of `Templates.Page` (a card grid at
     1:1.25, or list rows), or a page built for it under `Cabinet.Pages`.
   * The main action and the close button are part of the Frame, so they never move.
   * Docked mode (the Command View) hides the dim and the backplate and shows dock plates
     around an open zone C.
4. **Menus and input.** While a screen is open:
   * the cursor is free, gameplay actions are held off (new `InputController:Block`) and the
     HUD hides;
   * Backspace or B closes, Enter or Y presses the main action, and L1 and R1 switch tabs.
   * Escape stays Roblox's menu key.
5. **The HUD keeps the approved A0 positions**, with these additions:
   * a Phase chip (DAY 3, SIREN, SURGE, BOSS) mirroring the time chip;
   * the Ready button beside the year counter, with the team's count;
   * a full-width banner;
   * the touch cluster;
   * eight stockpile chips (Section 18 lists power, Food, Water, Scrap, ore and Ammo; the
     ore is Iron, Copper and Crystal).
6. **What's live now:**
   * Clock: the year flip counter (the tiles flip), the era, the cycle dial, the phase and the
     time left. A boss Surge shows BOSS and no timer.
   * Ready, through the SetReady remote.
   * Banners: the siren, and each Surge's start (a boss Surge names the boss).
   * Health from the character, the class and its ability (the Survivor until the loadout
     exists), the hotbar's selection, and the Command View button.
   * The mini-map: 5 columns and 5 floors around the player, drawn from the replicated
     cells and rooms, with an orange lamp on the player's cell.
   * The touch buttons, bound through InputController. Sprint is a toggle, as in the
     controls table. Roblox's own jump button is hidden while ours shows.
   Everything else rests until its system arrives: stamina, radiation, stockpile values,
   Disturbance, votes, alerts and hotbar items.
7. **The HUD hides** during the intro (Section 4: the HUD hidden) and while a Frame screen is
   open.
8. **On PC, holding Left Alt frees the cursor** to click HUD buttons. The camera locks the
   mouse, and Ready has no key in the controls table (see Bible Question 1).
9. **The UI kit grew by 16 sprites** in a new atlas (group `hud`), so the approved A0 atlases
   kept their ids:
   * round enamel touch buttons, up and down, with a bigger signal-orange Fire button;
   * flat tintable icons: Fire, Aim, Melee, Interact, Jump, Dodge, Sprint, Ping, Shoulder and
     the breach arrow;
   * Copper and Crystal ore.
   The atlas is decal 113747766925760, image 129337851835347. `tools/pack_ui.py` now also
   writes the client's `Lib.UIKit`.
10. **Dev samples** (`Lib.UISamples`, dev commands only) exercise every template before the
    real screens arrive: a class catalog from Config (cards in each rarity, the detail
    panel, Buy), a list of the stockpile's resources (rows), and docked mode.

**Design Risks**
* TextScaled sizes each label on its own, so a long passive and a short one end up at
  different sizes. Fixed-size text would break the AutoScale Lite rules; the pass and the
  Device Emulator check (rule 9) will show whether it matters.
* The HUD is busy on a small phone: vitals, clock, stockpile, mini-map, alerts, hotbar and
  ten touch buttons. Only the Device Emulator pass can tell; the mini-map is the first
  candidate to shrink or fold away on phones.
* The touch cluster's layout is my own reading of the bible's list. It needs thumbs on a real
  phone.

**Scope Risks**
* Not wired yet, waiting for their prompts:
  * the vote telegram (Prompt 8);
  * stockpile values and power lamps (Prompt 9);
  * stamina, radiation and hotbar items (Prompt 11);
  * alerts, breach arrows and mini-map blinking (Prompt 12);
  * the seismograph (Prompt 14);
  * the Command View page (Prompt 7);
  * ability icons for every class (A11).
* The Lobby has the Frame but no HUD: its hub screen comes with Prompt 21.

**Bible Questions**
1. Ready has no key in the controls table. As built:
   * on PC, players hold Left Alt and click Ready;
   * on touch, players tap it;
   * a gamepad can't reach it yet.
   Should Ready get a key and a console button, or live in the Command View for PC and
   console?
2. Is Left Alt (hold to free the cursor) all right as an extra PC control?
3. Copper and Crystal chips show from the start. Should each ore's chip appear only once the
   team reaches its band (floors 4 and 7)?

**Recommended Improvements**
* Preload the four kit atlases while the intro plays (ContentProvider), so icons never pop
  in. A new atlas takes 3 to 4 s to appear the first time.
* The Settings screen (Section 18), on The Frame:
  * camera sensitivity (`CameraController:SetSensitivity`) and invert Y;
  * the colour-blind palette;
  * screen shake and flashing toggles.
* Mechanical motion for The Frame: the cabinet slides in like a drawer and the main action
  depresses (Section 18: "drawers slide, buttons depress").

**Technical Risks**
* **The AutoScale Lite pass is manual.** After Landon's pass, rebuilding a screen from its
  builder loses the pass, so later changes edit the instances in place (and the builder file
  to match).
* **Hiding Roblox's jump button** reaches into Roblox's TouchGui (`TouchControlFrame.JumpButton`),
  which Roblox could rename. If it does, both jump buttons show; nothing breaks.
* **Gamepad.** The Frame selects its first tab for a gamepad and lets Enter through on a
  keyboard. HUD buttons have no gamepad route yet (Bible Question 1).

## Delivery Report

**Overview.** Every menu screen now has The Frame to open into, and the run has a working
HUD. Both are themed with the Steadfast kit and Scale-only, waiting for Landon's AutoScale
Lite pass. The HUD already runs the clock, Ready, banners, health, the hotbar, the mini-map and
the touch buttons.

**Files created**
* `studio/ui/Builder.lua`, `studio/ui/Frame.lua`, `studio/ui/HUD.lua`.
* `game/client/Controllers/UIController.luau`, `HUDController.luau`, `MiniMapController.luau`.
* `game/client/Lib/KitRuntime.luau`, `UIKit.luau` (generated), `UISamples.luau`.
* `game/shared/UIContract.luau`, `game/shared/Rules/Hud.luau`.
* `ui/atlas_hud.png` and 16 sprites in `ui/sprites/`.
* `game/reports/P06_FrameHUD.md`.
* `previews/Game/P06_Studio_*.jpg` and `P06_Studio_sheet.jpg`.

**Files modified**
* `generators/UI/UI_Kit.py`: the HUD pieces (group `hud`).
* `tools/pack_ui.py`: groups from specs; writes `game/client/Lib/UIKit.luau`.
* `tools/ui_luau.py`: picks `Builder.lua`, or `A0_Builder.lua` for A0 screens.
* `ui/kit.json`, `ui/specs.json`, `ui/upload_ids_2026-11-08.json`, `previews/UI/UI_Kit_sheet.jpg`.
* `game/client/Controllers/InputController.luau`: `Block` and `IsBlocked`.
* `game/client/Controllers/DevController.luau`: the `ui.*` and `hud.*` commands.
* `game/server/DevTools/StructureCheck.luau`: the UI checks and new skeleton entries.
* `game/server/DevTools/DataTests.luau`: HUD maths and contract tests (64 in all).
* `game/docs/ARCHITECTURE.md` (The UI section, layout, controllers, dev commands, prompt
  log) and `game/BUILD.json` (prompt 6).

**Architecture**
* Client controllers, in order: InputController, ReplicaController, CameraController,
  UIController, HUDController, then DevController and MiniMapController.
* UIController owns StarterGui.Frame. HUDController owns StarterGui.HUD; MiniMapController
  owns the HUD's mini-map paper.
* Both GUIs run through `Lib.KitRuntime.Watch`. Pure arithmetic (clock text, year tiles, the
  dial, needles, the map window) is in `Rules.Hud`, tested on the server.

**Integration notes**
* **Command View (Prompt 7).** Register with `Docked = true` and a page built under
  `Cabinet.Pages` with an open zone C. The Tab key and the HUD button press the
  `CommandView` action, which passes through the menu block so it can close the screen too.
* **Votes (Prompt 8).** Fill `HUD.VoteBanner` (Proposal, Tally, Yes, No; buttons are kit
  push-buttons) and show it. It sits just under the cycle dial.
* **Economy (Prompt 9).** `HUDController:SetResource(id, text, lamp)`; Power's lamp is
  `Lamp_Green`, `Lamp_Amber` or `Lamp_Red`.
* **Screens (Prompts 10, 15, 19 to 21, 26 to 30).** `UIController:Register` and `Open`, filled
  with `Clone("Card")`, `Clone("Row")`, `Clone("Section")`, `SetRarity`, `SetMainAction`,
  `SetChips` and `SetFooterActions`.
* **Combat (Prompt 11).** `SetVital("Stamina"/"Radiation", fraction)`, `SetSlot(i, icon, ammo)`
  and `HotbarSelected`. The touch Fire, Aim, Melee, Dodge and Interact buttons already press
  their actions.
* **Threats (Prompt 12).** `HUDController:Alert(kind, text)`, `MiniMapController:Blink(key,
  on)`, and `HUD.Arrows` with `Templates.EdgeArrow` for the screen-edge arrows.
* **Disturbance (Prompt 14).** `HUD.Disturbance.Trace` holds 46 segments to move;
  `DisturbanceLevel` is the word under the label.
* **Classes and loadout (Prompts 20 and 21).** `HUDController:SetClass(id, level)`.

**Testing checklist (done in Studio, 2026-11-08)**
* [x] Installed in both places: StructureCheck 0 errors (Run 257 checks with the HUD and the
  Frame, Lobby 184 with the Frame), 64 data tests passed.
* [x] Run playtest, the HUD:
  * Year 001, ERA I SETTLING IN, DAY 1, the time counting down, health 100, the Survivor's
    SECOND WIND, the stockpile chips and the mini-map around the Medbay.
  * A real Left Alt plus a click on Ready skipped the day to the siren (one player). Ready
    then hid until the next day.
  * SIREN in yellow; at the Surge, SURGE with "SURGE · HOLD THE BUNKER".
  * Year 24 to 25 flipped the tiles. The Brood Mother's Surge showed BOSS, --:--, the pointer
    parked, and "BROOD MOTHER · THE SURGE ENDS WHEN IT FALLS".
  * A real 3 key press selected hotbar slot 3.
  * Moving the character to floor 1, column -2 moved the mini-map window: Blast Door, both
    shafts, Kitchen, Water Purifier, the lamp on the player's cell.
  * `hud.touch` showed the ten touch buttons; alerts and the banner rendered
    (`P06_Studio_hud.jpg`).
* [x] Run playtest, The Frame:
  * `ui.sample` opened the class catalog: 19 cards, tabs, 70 Glowshards from the profile.
  * A real click on the Security card filled the detail panel and BUY 40.
  * A real Backspace closed it, gave the cursor back to the camera and unblocked input.
  * `ui.list` showed the rows; `ui.dock` showed docked mode with the world in zone C.
* [x] Lobby playtest: no HUD; the same Frame opens with the catalog (`P06_Studio_lobby_frame.jpg`).
* [ ] **Landon's AutoScale Lite pass** on StarterGui.Frame (both places) and StarterGui.HUD (Run).
* [ ] Device Emulator: a small phone, a tablet, 1080p and a 4K TV (rule 9).
* [ ] A real phone: the touch buttons, Sprint as a toggle, Roblox's jump button hidden, pinch
  and drag beside them.
* [ ] A gamepad in the Frame (tab selection, B, Y, L1 and R1).
* [ ] Two players: the Ready count with two.

**Future extension notes**
* A new screen is a Register call plus, if the generic page doesn't fit, a page built under
  `Cabinet.Pages` with its parts added to `Shared.UIContract`.
* A new HUD element: add it to `studio/ui/HUD.lua`, build it in place (after the AutoScale
  pass, add it by hand or rebuild and redo the pass), and list its paths in the contract.
