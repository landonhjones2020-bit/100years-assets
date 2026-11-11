# Prompt 22: The Intro Cutscene

Every run now opens with the 30-second cutscene of bible Section 4, played live in the engine with
the party's own avatars, and its last shot pushes in on the player's own character and hands over
the controls. Built and tested on 2026-11-10. The final build is `p22-f333523` (code asset
95026446991297, revision 96), installed in Run and Lobby: StructureCheck 0 errors (Run 577 checks,
Lobby 356), 121 data tests.

What is in it:

* **The six shots**, as ten camera set-ups with hard cuts between them: the billboard and Main
  Street (0 to 5 s), the sprint up the hillside path (5 to 7.6), into the blast door (7.6 to 10),
  the bomb over the town (10 to 12.5), the door rolling shut and sealing (12.5 to 15), the flash,
  the shockwave and the cloud (15 to 21), the dive into the hill (21 to 22.2), the plunge down the
  lift shaft past the bunker's rooms (22.2 to 25.7), the Source opening its eyes (25.7 to 27), the
  title and "Survive. Dig. Don't wake it." over the bunker, then the push down to your character
  (27 to 30).
* **The party and the founders run it.** Each party member's avatar is built from their avatar
  description (a copy of their character stands in until it arrives), this player's own in front,
  then the run's six founders, sprinting with a clip made for it.
* **The rules**: an account's first run plays it in full (no Skip); after that Skip appears at 2
  seconds, bottom right. Skipping is personal: the skipper gets their camera back and a telegram
  that counts down to the run, which starts at the 30-second mark for everyone. Letterbox bars, the
  HUD and every menu hidden, a late joiner comes in at the right moment.
* **The set (art step A9, the other half)**: Main Street is the lobby's own blocks, so the street
  the player just left is the street that is destroyed. New: Mine Hill with its stepped path, the
  Steadfast blast door, the bomb, the shockwave, the mushroom cloud, the ground between the hill
  and the bunker cut open, the glimpse of the Source, the title's two sprites and the sprint.
  24 models, 100 placements on the street and the hill, 194,000 triangles.

Captures from the playtest: `previews/Game/P22_Intro_sheet.jpg` (16 moments on one sheet) and
`previews/Game/P22_Intro_*.jpg`. Blender sheets: `previews/Cutscene/` (each model, and
`Storyboard.png`, the whole cutscene as 24 frames rendered in Blender) and
`previews/Clips/R15_IntroSprint_sheet.png`.

**Not in it: sound.** Section 4's siren, radio static, bomb whistle, blast and music sting come
with Prompt 32 (audio). Every one of them has a named moment to hang on (`Beats` in the data).

## Design Notes

**Decisions**
1. **The whole cutscene is a function of one number.** `Rules.Cutscene` (pure) and
   `CutsceneController` set the camera, the runners, the door, the bomb, the blast, the light and
   the words from the seconds since it began, every frame; nothing is fired off and left to run.
   The seconds come from the run's clock (`RunDirector`'s Intro phase, `IntroEndsAt`), so the
   cutscene ends exactly as the run starts whatever the frame rate, a player who arrives late joins
   at the right moment, and a dev command can hold any moment for a capture (`cutscene.at`).
2. **The camera is animated in Blender and played from data**, as Section 4 says. The scene
   (`generators/Cutscene/Intro_Scene.py`) assembles the set from the same exported models, keys
   the camera, renders the storyboard, and writes `Config.CutscenePaths`: the shots' keys (about
   15 a second: position, rotation, field of view), where every piece of the set stands, the
   runners' line and places, named points and the beats. The game reads it; nobody types a
   coordinate into Luau. Words and lighting are `Config.Cutscenes`, written by hand.
3. **The set is the lobby's Main Street.** The Run place now holds the lobby's showroom, frontage
   and six blocks, the town's cars, trees, bunting, hills and water tower, laid out exactly as in
   the lobby, with Mine Hill added at the east end of the street. The first shot starts on the
   showroom's own billboard, "Built to Last A CENTURY".
4. **Each client plays its own.** The server only assembles the set in `ReplicatedStorage` (the
   art is in `ServerStorage`) and says whose first run it is. Each client clones the set 1,400
   studs above the run's world, where nothing else is, and takes it down at the end; the server
   frees it 10 seconds into the run. Nothing of the set ever stands in the server's world, so
   nobody can walk onto it and it costs the run nothing.
5. **The plunge is shot in front of the real bunker.** From 22.2 s the camera is in the run's own
   world, looking at the bunker the way the Command View does (its front walls faded, its light
   lifted: `CommandViewController:Present`), so "past the bunker's rooms" shows this run's actual
   rooms and founders. Above it stands the cut-open ground with the shelter's lift shaft, below it
   the game's own rock in its band colours, and at the bottom the Source's mouth in the Source
   Chamber's red rock.
6. **The hand-over is a push-in, ended in code.** The last shot settles into the Command View's
   pose over the player's own character, wherever they stand and whatever the screen's shape, then
   their own over-the-shoulder camera is switched back on (pointed into the bunker) and the
   picture is pushed down to it: what it shows shrinks steadily while the lens opens, so the move
   ends on exactly the camera the player then controls, with no cut and no jump.
7. **Skip is a press.** A click, a tap, Space or B on a controller. `Tuning.Cutscene.SkipHoldSeconds`
   is 0; set it above 0 and the key must be held that long (the button shows the fill and the key).
8. **One sprint for everyone.** `R15_IntroSprint` is on the standard R15 skeleton, so it plays on
   any avatar and on the residents, at the run speed the data gives (27 studs a second).
9. **Comfort.** `CutsceneController:SetComfort(flash, shake)` turns off the white flash (a soft
   wash instead, and no burst of light) and the camera shake, for Section 18's accessibility
   settings when the Settings screen is built. Both are on until then.
10. **The title never goes missing.** If the title's sprites have not loaded when the card lands,
    the same words are set in type in their place.

**What the blast does** (all from the data, per piece): the door's leaves roll in on their rail
with the beacons flashing, the wheel spins, the SEALED lamp lights; the bomb flies its line with a
vapour trail; white; the fireball swells and dims; the cloud's stem, cap and skirt climb and
spread; the ring crosses the town at its own speed and, as it reaches each piece, buildings sink
and lean away from the blast, trees and the water tower go over, cars are thrown down the street,
the bunting is gone and every lamp goes out; dust takes the camera, then ash and embers fall.
The light goes from the lobby's morning to the flash, the blast's orange and the dead red after.

**Scope Risks**
* The founders all wear the one resident model the game has (Resident_Common), so the six look
  alike; they will differ when residents get their looks.
* Digby is not in it. Section 4 does not ask for him; the billboard would be his place.

**Bible Questions** (each is how it is built now; say the word and it changes)
1. **The hillside path** is a broad flight of steps straight up Mine Hill from the east end of
   Main Street, with a "STEADFAST SHELTER / Built to Last a Century" arch at its foot, lamps, three
   landings and a terrace in front of the door. Is that the path you pictured?
2. **The blast door** is two steel leaves that roll together on an overhead rail, a sunburst
   across the pair, "STEAD / FAST" and "SHELTER / No. 1" on them, a wheel that locks them and a
   SEALED lamp above. The surface map's shelter entrance (Prompt 16) and the bunker's Blast Door
   room should match it when the town is rebuilt: keep this design?
3. **Names on the set that the bible does not give**: "Brightwater Community Shelter" (the door's
   sign), "BRIGHTWATER RADIO" (the bulletin's station), "BRIGHTWATER MINE, CLOSED 1931" (the old
   adit on the hill), and a notice by the door, "DRILL TODAY, ALL RESIDENTS, 10 A.M. SHARP" (why
   everyone knew where to run). Keep, change or drop?
4. **The bulletin's wording** (scrolls once, 0.5 to 10.4 s): "...A STEADFAST SHELTER IS BUILT TO
   LAST A CENTURY!  -  WE INTERRUPT THIS PROGRAM  -  THIS IS NOT A TEST  -  ALL BRIGHTWATER
   RESIDENTS: GO TO THE STEADFAST SHELTER ON MINE HILL AT ONCE  -  THIS IS NOT A TEST  -".
5. **The Source's glimpse**: a dark mass in a mouth of the Source Chamber's rock, glowing green
   veins, one great eye and six small ones that open one after another. It is a glimpse, not the
   boss's design: is a many-eyed thing right, or should it be one pair of eyes?
6. **What the plunge passes above the bunker** is invented dressing: the lift shaft and its car,
   the town's water main, a Steadfast conduit, the bones of a sea creature, an old mine gallery
   with a cart, and in the topsoil a buried time capsule, a boot and a bottle.
7. **A skipper waits in the bunker** with their own camera and no HUD (the HUD comes on with the
   run), free to walk, with a "THE RUN STARTS IN 0:15" telegram. Should they be held on a still
   picture instead?
8. **Skip: a press, or press and hold?** A press now (decision 7).
9. **The Run place's leftovers.** The template's Baseplate and SpawnLocation and the style test's
   `A0_Showroom` still stand at the world's origin, in the plunge's way; the cutscene hides them
   for this client while it passes. May they be deleted from the Run place?

**Recommended Improvements**
* The shop signs and the hotel's sign could flicker before they die, and windows could blow out a
  moment before each building goes: both are a few lines against data that is already there.
* A second sprint (a stumble, a look back at the sky) for one or two runners.
* The founders could be seen again in the plunge, stepping out of the lift into the bunker.

**Technical Risks**
* **A clip loaded before its model is in the world never gets its keys** (it "plays" with no
  length and no weight, and no error). The runners' sprint is loaded the first time each one stands
  in `workspace`. Found in the first playtest; the same trap waits for any clone that is animated.
* **An image in a ScreenGui that was never shown has not been fetched.** The cutscene preloads
  its two screens with the set, and the title has its fallback in type (decision 10).
* **Studio remembers a failed download until it restarts.** The title's atlas timed out once in
  the Run studio tonight ("HttpError: Timedout") and `rbxassetid://71612230706016` then stayed
  blank in that Studio for the rest of the session, while it loaded in the Lobby's Studio and
  through another address. The title card was therefore judged in the Run playtest with its two
  images pointed at that other address for that playtest only; the screen itself uses the normal
  id. After a Studio restart it should simply show (if not, tell me).
* **The lowest graphics level** draws about 500 studs. Every camera on the set stays within 520
  studs of the blast (a data test) and both ends of the street were checked at quality level 1.
* The set is 194,000 triangles, cloned on each client for 30 seconds and held in
  `ReplicatedStorage` until 10 seconds into the run. Not measured on a phone.

## Delivery Report

**Overview.** The intro cutscene: a pure rules module, two data modules (one generated from
Blender), a small server service, a client controller, two screens, and the set's art. The run's
clock, its Intro phase and the profile's first-run flag were already there; this prompt plays the
30 seconds they leave room for.

**Files created**
* `game/shared/Rules/Cutscene.luau`: the arithmetic (clock, who may skip, the shot and camera at
  t, the runners' line and places, the door, bomb, ring, cloud and eyes at t).
* `game/shared/Config/CutscenePaths.luau`: generated (the camera's 462 keys in 10 shots, 100
  placements, 69 ground blocks, the run line, anchors, beats). Don't edit: see "Changing it".
* `game/shared/Config/Cutscenes.luau`: the bulletin, the title and its line, the four lighting
  looks and their keys.
* `game/places/Run/server/Services/CutsceneService.luau`: assembles `ReplicatedStorage.CutsceneSet`
  (Pieces, Ground, Effects), sets each player's `IntroFirstRun`, frees the set after the start.
  Dev: `intro`, `intro.first [true|false] [player]`.
* `game/places/Run/client/Controllers/CutsceneController.luau`: plays it. API: `IsPlaying()`,
  `State()`, `SetComfort(flash, shake)`, the `Finished` signal (true: skipped). Dev: `cutscene`,
  `cutscene.play [from]`, `cutscene.at <seconds>`, `cutscene.stop`, `cutscene.skip`,
  `cutscene.comfort [flash] [shake]`.
* `studio/ui/Cutscene.lua`: the two screens. `CutsceneBars` (no insets: the bars, black, the
  flash, dust, the radio bulletin on the lower bar) and `Cutscene` (the title card, Skip, the
  telegram for a skipper).
* Art: `generators/Cutscene/cutscene_plan.py` (the set's plan), `scenelib.py`, `Intro_Scene.py`
  (the Blender scene, the storyboard, the data), `Cutscene_Hill.py`, `Cutscene_BlastDoor.py`,
  `Cutscene_Effects.py` (bomb, shockwave, cloud), `Cutscene_Under.py` (strata, the Source's
  glimpse), `generators/UI/UI_Title.py`, `generators/Clips/R15_IntroSprint.py`,
  `tools/cutscene_config.py`, `cutscene/IntroPath.luau` (the art repo's copy of the data).

**Files modified**
* `Config/Tuning.luau`: `Cutscene` (where the set stands, bars, fades, shakes, the late-join and
  avatar limits, `SkipHoldSeconds`). `Config/Animations.luau`: `IntroSprint`.
* `UIController`: `Lock(reason, on)` (no screen opens during the cutscene), `IsLocked()`.
* `CommandViewController`: `Present(reason, on)` (the bunker shown as the Command View shows it,
  without opening it) and `Pose(at, floors)` (its camera for a point), both used by the cutscene.
* `DevController`: `Register(name, handler)` so a controller can add its own client commands.
* `UIContract` (the two screens; a screen may now say `Insets = "None"`), `StructureCheck`,
  `DataTests` (5 new tests), `UIKit` (the title's sprites).

**Architecture.** Server: `CutsceneService` after `RunDirector`, `SessionService`,
`ProfileService`. Client: `CutsceneController` after the camera, UI, HUD and Command View
controllers; it binds one render step after the player's camera (`Camera + 5`) while playing. It
asks for the camera with `CameraController:Suspend("Cutscene")`, hides the HUD and locks the
screens by the same reason, and gives each back at the end, by skip, or if the run starts.

**Integration notes**
* A new place needs the set's art in `ServerStorage.Assets` (`Lobby`, `Town`, `Cutscene`); the
  service warns by name about anything missing and the cutscene plays without it.
* `Tuning.Clock.IntroSeconds` and the data's 30 seconds must agree (a data test).
* `DevTools.SkipIntro` (Studio) still skips the Intro phase entirely; the cutscene then never
  starts.

**Changing it**
* A camera move, a beat, where something stands: `generators/Cutscene/cutscene_plan.py` and
  `Intro_Scene.py` (`SHOTS`), then `python3 generators/Cutscene/Intro_Scene.py` (the storyboard),
  `python3 generators/Cutscene/Intro_Scene.py --data` and `python3 tools/cutscene_config.py`.
* Words and light: `Config/Cutscenes.luau`. Shakes, fades, the bars: `Tuning.Cutscene`.

**Testing checklist** (all in Run playtests on 2026-11-10 unless marked)
* [x] The intro starts with the Intro phase and ends as the run starts (30.0 s by the run's clock);
  all ten shots in order, no errors. The only warnings were Roblox's own, about fetching two
  images (Technical Risks).
* [x] Each moment held and looked at (`cutscene.at`): the 16 captures on the sheet.
* [x] The runners: this player's avatar (built from its description on the client, 0.4 s) and six
  founders, the sprint playing on all seven, inside before the door moves.
* [x] The door's leaves meet, the wheel turns, SEALED lights; the bomb and its trail; the flash;
  the ring flattens the town piece by piece; lamps out; ash.
* [x] The plunge: the strata and the lift shaft, the run's real rooms, the Source's eyes opening.
* [x] The title, its line word group by word group, the bunker coming up behind it.
* [x] The hand-over: what the picture shows goes 103, 80, 53, 33, 21, 15, 13 studs tall from 28.8 to
  29.95 s (never backs away), ending on the player's own camera; the HUD returns with the run.
* [x] Skip: not offered on a first run (`intro.first true`: no button, `cutscene.skip` does
  nothing); offered from 2 s otherwise; skipping at 10 s gave the camera back and the telegram
  ("0:20" counting down), which went when the run started.
* [x] Stopping it mid-blast restores the light, the camera, the HUD and Roblox's own menus.
* [x] Quality level 1: the street, the hill, the blast and the cloud all draw.
* [x] Both places: StructureCheck 0 errors, 121 data tests.
* [ ] Two or more players, and a player joining during the intro: the code path is the same as the
  start (the seconds come from the run's clock), but it needs the live game.
* [ ] A phone: the bars and the bulletin are sized in proportion; not seen on one.
* [ ] The title's sprites through the normal id in the Run place (see Technical Risks).

**Future extension notes.** The rules and the two data shapes would carry another cutscene (an
ending, a boss's entrance): another entry in `Config.Cutscenes` with its own path. The controller
is written for the intro (its start and its hand-over), so that part would need opening up. Sound
hooks onto the beats. The comfort switches wait for the Settings screen.
