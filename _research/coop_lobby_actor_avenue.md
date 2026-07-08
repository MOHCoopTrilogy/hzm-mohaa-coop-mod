# Coop Lobby - Actor / Stand-in Avenue (fluid, own-skin, animated squad)

Research report, 2026-07-08. RESEARCH ONLY - no code changed. Goal: make each visible lobby
soldier (a) wear the player's OWN chosen MP skin, (b) fluidly cycle the downtime idle library
exactly like the MP skin-select menu, (c) show overhead name + rank, (d) never freeze the player.

TL;DR: the whole "frozen-player-mannequin" fight is avoidable. The MP menu proves the engine can
render an arbitrary-skinned player TIKI running the full fluid idle pool because it drives a bare
`refEntity` skeletor directly, with NO Player class, NO statemap, NO weapon system. The in-world
equivalent already exists and needs ZERO engine edits for the body+skin+animation: a
`spawn script_model` wearing `models/player/<skin>.tik`, driven by `self anim "<pool>"` +
`waittill animdone`. `ScriptModel::SetAnimEvent` resolves the weight-pooled name to a random pick
each call - the identical re-pick loop the menu uses. Hide + view-lock the real player to the
shared camera; the mannequin is the visible body. Nameplate/rank is the only piece that benefits
from a (small, optional) cgame edit.

---

## 1. HOW the MP skin-select / netgame-room menu renders a skinned, fully-animated model

The menu's soldier is NOT an entity. It is a **pure client-side `refEntity_t` rendered into a HUD
sub-viewport**, animated by a trivial client timer. Three layers:

### 1a. The picker just writes cvars (no 3D here)
`code/client/cl_uiplayermodelpicker.cpp` - `PlayerModelPickerClass` is only a listbox of `.tik`
filenames (roster table `pickerModels[]`, lines 44-113; view models `*_fps` and `_`-hidden files
skipped, lines 247-255). Double-click -> `FileChosen` (307-326) stuffs
`ui_dm_playermodel "<name>" ; ui_dm_playermodel_set <file> ; ui_disp_playermodel <file>.tik`.

The cvar plumbing lives in `code/client/cl_ui.cpp`:
- `UI_ApplyPlayerModel_f` (3443) -> `Cvar_Set("dm_playermodel", ui_dm_playermodel_set)` - this is
  the real, persisted, replicated model cvar the game reads at spawn.
- `UI_GetPlayerModel_f` (3468) -> `Cvar_Set("ui_disp_playermodel", va("models/player/%s.tik", ...))`
  (line 3479). **`ui_disp_playermodel` = the full tik path the preview widget renders.**

### 1b. The widget: `UIFakkLabel` with `rendermodel`
The preview is a menu widget of class **`UIFakkLabel`** (`code/client/cl_uistd.cpp:213`), a
`UILabel` subclass. Its `.urc` resource keywords (Event table 213-238):
- `rendermodel <bool>` (156/407 -> `m_rendermodel`) - "render the model specified by the cvar"
- `cvar <name>` (inherited from `UILabel` -> `m_cvarname`) - set to `ui_disp_playermodel`
- `modelanim <s>` / `anim <s>` (196/201 -> `m_anim`, handler 435) - set to `americanselectionidle`
  (or `germanselectionidle`)
- `modeloffset` / `modelrotateoffset` / `modelangles` / `modelscale` (164-194) - framing

`UIFakkLabel::Draw()` (1400) render-model branch (1598-1697):
```
handle    = re.RegisterModel(Cvar_VariableString(m_cvarname));   // 1603  <- ui_disp_playermodel
sAnimName = m_anim;                                              // 1612  <- "americanselectionidle"
...
CL_Draw3DModel(x,y,w,h, handle, origin, rotateoffset, offset, angles, color, sAnimName);  // 1685
```
So a skin change is literally `re.RegisterModel` of a different tik path - a new render handle.
No entity, no classname, no spawn. (The 2.11 "tunak" easter egg at 1616-1624 swaps the anim to
`zzamericanspecialidle` - proof the anim is just a string handed to the renderer.)

### 1c. The animator: `CL_Draw3DModel` (`code/client/cl_invrender.cpp:60`)
This is THE reusable "UI model animator" (also used by the weapon inventory screen). Mechanism:
- Builds a private `refdef_t` with `rdflags = RDF_HUD | RDF_NOWORLDMODEL`, fov 30, into the widget
  rect (74-86). It is an off-world HUD render, not the game scene.
- Gets the TIKI handle: `ent.tiki = re.R_Model_GetHandle(model)` (99).
- Animation (104-188): keeps 8 static per-model slots tracking `fAnimTime`. Each frame it advances
  `fAnimTime += dt` (163); when `TIKI_Anim_Time(tiki, index) < fAnimTime` (166) it sets
  `iIndex = -1`, which forces a **re-resolve**: `iIndex = TIKI_Anim_NumForName(ent.tiki, animName)`
  (179) and `fAnimTime = 0` (180). It then feeds a single `frameInfo[0]` (index/time/weight 1) to
  the renderer (184-187).
- Submits: `re.AddRefEntityToScene(&ent, ENTITYNUM_NONE)` + `re.RenderScene(&inv_refdef)` (211-212).

### 1d. WHERE the fluid variety comes from - the weight pool
`americanselectionidle` / `germanselectionidle` are **weight-pooled alias names**, not single
clips. `hzm-mohaa-coop-mod/models/player/base/anims_shared.txt`:
```
americanselectionidle1  misc/00A100_idle.skc          weight 0.25   (arms-at-side idle)
americanselectionidle2  misc/00A101_salute.skc        weight 0.25   (salute)
americanselectionidle3  misc/00A102_cleanshoes.skc    weight 0.25
americanselectionidle4  misc/00A103_pullups.skc       weight 0.25
americanselectionidle5  misc/00A104_stretches.skc     weight 0.55 dontrepeate
americanselectionidle6  misc/00A105_pushups.skc       weight 0.25
americanselectionidle7  misc/00A106_jumpingjacks.skc  weight 0.25
germanselectionidle1..9 misc/00G1xx_Axis_*.skc                       (hands-on-hips idle, etc.)
```
The TIKI `weight` flag pools numbered aliases under the digit-stripped base name;
`TIKI_Anim_NumForName("americanselectionidle")` returns a **random member each call** (numbered
names return -1 - cerebrum 2026-07-06). So each time `CL_Draw3DModel` re-resolves the name at the
end of a clip, it random-picks the next idle. That is the entire "fluid variety" mechanism: a
weighted random walk over one nationality's clip set, and the cuts read as seamless because every
clip in a national set begins and ends in the same neutral stance.

### 1e. WHY the menu is fluid+unfrozen while the in-game player fights us
| Menu preview (fluid) | In-game player (fought us) |
|---|---|
| A bare `refEntity_t`; renderer skeletor only | A full `Player` entity |
| Anim = one `frameInfo[0]` from a client timer | Anim = `Player::EvaluateState` statemap re-run EVERY frame (player.cpp:5571) |
| No weapon, no holster, no loadout | Weapon/holster/loadout code direct-`SetPartAnim`s the skeleton |
| No statemap edges | STAND `RAISE_WEAPON:NEW_WEAPON` redraws gun; EMOTE_ATEASE `STAND:+/-HAS_WEAPON` kicks pose |
| Skin = `re.RegisterModel(path)` | Skin = the Player's model; changing it re-inits legs |
| `FL_IMMOBILE` irrelevant | `FL_IMMOBILE` freezes statemap -> kills variety (freeze vs fluid are mutually exclusive) |

The menu wins by **never touching the Player/statemap/weapon stack at all**. The takeaway for the
lobby: put the visible body on something that also has none of that stack - and hide the real
player. That thing already exists in the game code: `script_model` (or a disable_ai'd Actor).

---

## 2. Options to replicate this on an in-MAP entity (ranked)

### OPTION 1 (RECOMMENDED) - `script_model` mannequin wearing the player skin. ZERO engine edits for body/skin/anim.
`code/fgame/scriptslave.cpp:1999` `CLASS_DECLARATION(ScriptSlave, ScriptModel, "script_model")`:
- ctor sets `edict->s.eType = ET_MODELANIM` and `AddWaitTill(STRING_ANIMDONE)` (2012-2014) - so you
  can `self waittill animdone`.
- `EV_Model` -> `SetModelEvent` (2017): loads any tik + computes bounds. A player tik loads fine as
  a model (it is just a skelmodel + anim includes).
- `EV_ScriptModel_SetAnim` = the `anim` command -> `SetAnimEvent` (2026):
  `animnum = gi.Anim_NumForName(edict->tiki, animname)` (2034) then
  `NewAnim(animnum, EV_ScriptModel_AnimDone)` + `RestartAnimSlot(0)`. **`gi.Anim_NumForName` on a
  weight-pooled name random-picks - identical to the menu's `TIKI_Anim_NumForName`.** On clip end
  it fires `animdone`.

So the menu's exact loop, in map script:
```
mannequin model "models/player/american_army.tik"   // any skin, sidesteps bug-355 (see below)
// loop thread:
while (active) { mannequin anim "coop_lobbyselect"   // weighted pool already authored
                 mannequin waittill animdone }
```
Each `anim` call re-random-picks from the pool -> fluid variety, no freeze, no twitch, because a
script_model has **no statemap, no weapon system, no Player class**. It is the in-world twin of the
menu's refEntity.

Why this beats the prior dead-ends:
- **bug-355 does NOT apply.** bug-355 was `spawn models/player/x.tik` (using the tik as the
  classname), which the engine rejects because a player tik has no Actor classname.
  `spawn script_model` supplies the classname `script_model` explicitly; `self model
  "models/player/<skin>.tik"` then just assigns the model - the exact pattern `lobby.scr::spawnProps`
  already uses for 22 static props. The prior session concluded "player skins cannot be actors" but
  never tried the script_model (or post-spawn setModel) path.
- **Shared skeleton is proven.** Player and AI share the Bip01 rig; the cover system and emotes play
  AI `.skc` on the player, and here the clips (`misc/00A1xx`) are native player anims on a player
  tik, so they resolve directly.
- The weighted pool `coop_lobbyselect1..12` is ALREADY authored (anims_shared.txt:484-495,
  allied+axis mix pre-curated, glitchy pullups/lean excluded).

Feasibility: HIGH. Engine edits for the mannequin body/skin/animation: **none**. Only the
nameplate/rank piece (Task 5) optionally wants a cgame edit.

Small risk to verify on first boot: skeletal render path. `ScriptModel` sets `ET_MODELANIM`; the
engine promotes skeletal tikis to `ET_MODELANIM_SKEL` (bg_public.h:501; e.g. lodthing.cpp:197). If a
raw script_model renders a player tik as static/T-pose, use OPTION 2 instead (an Actor is
unambiguously skeletal). This is the single thing to smoke-test.

### OPTION 2 (STRONG FALLBACK) - Actor spawned, then `setModel` to the player skin.
bug-355's own fix already spawns a WORKING actor in the lobby (`Sc_AL_US_inf.tik`, `disable_ai`,
holds a natural idle). The only missing piece was the skin. Post-spawn `self model
"models/player/<skin>.tik"` (EV_Model on Entity, entity.cpp:1587; Phase B/C confirmed
`self model "models/player/<x>.tik"` is a live, replicated Entity change, entity.cpp:1568/1997)
re-skins the already-spawned actor without ever hitting the spawn-time classname check.
- Animation: a `disable_ai` actor holds its idle; drive the pool with a script loop (or
  `global/loopanim.scr::LoopAnim <alias>` for a single clip). Actors have their own anim/think
  system (no player statemap), so no twitch. Slightly less "menu-exact" than the script_model
  `anim`+`animdone` loop, but robustly skeletal.
Feasibility: HIGH. Engine edits: none. Use if OPTION 1's script_model skeletal render disappoints.

### OPTION 3 - New lightweight engine entity that literally wraps `CL_Draw3DModel` semantics in-world.
A dedicated `coop_lobby_mannequin` server class exposing (skin, animPool, ownerClientNum) and
driving `NewAnim` server-side. This is just OPTION 1 hard-coded into C++; it buys nothing over a
script_model + 20 lines of `.scr` and costs a game.dll rebuild + deploy. Only worth it if we want
the identity/skin/rank routing baked into replication. Feasibility: MEDIUM, unnecessary now.

### OPTION 4 - Give player tikis an Actor classname (engine/tik edit so they are spawnable).
Directly "fixes" bug-355 by making `models/player/*.tik` spawnable as actors (add classname to each
tik, or a fallback classname in the misc-tik spawn path). Broad blast radius (touches every player
model + the spawn validator that intentionally rejects classless tikis). Options 1/2 get the same
result with no such risk. Feasibility: LOW-value, do not pursue.

### OPTION 5 - Reuse the menu's `CL_Draw3DModel` to draw the squad as a HUD overlay.
Render 4 HUD-space refEntities over the camera view instead of world entities. Rejected: they are
not in the world (no world lighting, no shadows, no depth vs props, fixed screen rects), and
compositing 4 correctly-placed HUD models over a 3D camera shot is far more fragile than 4 real
world mannequins the camera already frames. Keep this only as the proof-of-concept it already is.

---

## 3. RECOMMENDED end-to-end approach

Replace the "real frozen player is the visible body" model with "**hidden, view-locked real player +
one script_model mannequin per player**." This deletes the entire CoopLobbyPose / FL_IMMOBILE /
`coop_lobbyholdpose` per-frame re-assert machinery for the visible body (the body is now a
statemap-less prop), and delivers the user's fluid-variety goal directly.

### 3.1 The real player (identity + view only, never seen)
On each spawn/respawn (`lobby.scr::lobbyOnSpawn`, already the dispatch point):
- `local.player hide` and keep it hidden (re-assert; respawn shows it). Optionally `notsolid`.
- `local.player freezecontrols 1` - PMF_FROZEN blocks movement AND mouselook (bug-356), menu/console/
  chat still work. Re-assert each frame (m_bFrozen resets on respawn) - the existing `lobbyLockWatch`
  loop already does this; just drop the `coop_lobbyholdpose` call from it.
- `cuecamera level.coop_lobbyCam` - the one shared static shot (already built,
  `spawnLobbyCamera`/`applyLobbyCam`, movetopos+watch, cvar-tunable).
- `drawhud 0` + the existing `lobbyHideHud` (ihuddraw + ui_removehud). Unchanged.
- **Drop `self coop_lobbypose` / `coop_lobbyholdpose` / the FL_IMMOBILE dance entirely** for the
  visible representation. (Keep the engine events in the tree as dead code / revert insurance, or
  remove later - they are no longer on the hot path.)

Net: the real player is an invisible, frozen camera-viewer. Any residual weapon-edge twitch is
invisible, so the problem that consumed a whole session simply stops mattering.

### 3.2 The mannequin (visible body)
One `script_model` per player, spawned when the player deploys, deleted on disconnect/launch:
```
level.coop_lobbyMannequin[slot] = spawn script_model
mann model  ("models/player/" + skin + ".tik")     // skin from the player (3.3)
mann.origin = feetOrigin(slot)                       // reuse coop_lobbySlotOrg - coop_lobbyFeetDrop
mann.angles = ( 0 coop_lobbySlotYaw[slot] 0 )
mann notsolid                                        // players never collide with it
mann thread lobbyMannequinIdleLoop                   // the menu loop, section 2 OPTION 1
mann.owner  = player ; player.flags["coop_lobbyMannequin"] = mann   // 2-way identity link
```
`lobbyMannequinIdleLoop`: `while(active){ self anim "coop_lobbyselect"; self waittill animdone }`
(null-guard self + gate on `level.coop_lobbyActive`). This is the exact menu re-pick loop.

### 3.3 Skin: apply + live cycle
Source of the player's chosen skin (two equivalent reads):
- Simplest: the real player already wears their skin - read `local.player.model` (an Entity model
  getter) and assign it straight to the mannequin.
- Explicit: `info_valueforkey (local.player userinfo) "dm_playermodel"` -> build
  `"models/player/" + skin + ".tik"` (InitModel reads this same userinfo key at spawn,
  player.cpp:2502/2542; the guid-from-userinfo read is already used in the mod).

Live cycle (Phase C L/R): change `mann model ("models/player/"+skin+".tik")` (instant, replicated),
and persist for the launched mission via `player stufftext ("dm_playermodel "+skin+"\n")` so the
real player spawns into m1l1 with the same skin. Restrict the roster to non-`_fps` allied tikis
(picker roster `pickerModels[]`, cl_uiplayermodelpicker.cpp:44-113; allied list already enumerated
in coop_lobby_phaseBC_plan.md:72-75). No re-pose needed after a skin swap on a mannequin (unlike the
real player, whose legs reset) - just keep the idle loop running; the next `anim` call re-applies.

### 3.4 Overhead nameplate + rank
The head-anchored render path already exists: `CG_ActorOverheadIcon` (cg_modelanim.c:227) draws a
world-space `RT_SPRITE` at the `"Bip01 Head"` / `"eyes bone"` tag +20u, distance-scaled/faded, for
any `ET_MODELANIM`/`ET_MODELANIM_SKEL` entity carrying `renderfx & RF_COOP_BOSS` (call site
1689-1707). `RF_COOP_BOSS` is set from script by `self rendereffects "+coopboss"` (entity.cpp:4015).
A script_model mannequin can therefore get a head-anchored sprite with one script line. Two routes:

- Route A (script-only, ship first): rank emblem via `self attachmodel` (EV_AttachModel,
  entity.cpp:379/1587) - attach the rank sprite (`textures/hud/coop_rank_NN.spr`, NN =
  `player.flags["coop_xp_rank"]` from xp.scr) to the mannequin's head tag. Player NAME: because the
  camera is static and slots are fixed, each head projects to a fixed screen point - draw
  `ihuddraw_string` at `coop_lobbyPlateN_X/Y` (slots 100-107, clear of the 20-90 hide band and the
  62-72 XP band) with the clean netname (`game.player::playerCleanName self.netname`). This is the
  Phase B/C nameplate plan and needs no rebuild.

- Route B (cgame, nicer, later): add a small `CG_LobbyNameplate` beside `CG_ActorOverheadIcon` that,
  for lobby mannequins, draws (i) the rank emblem as an `RT_SPRITE` over the head and (ii) the owner
  netname as world-anchored 2D text (project the head tag to screen with the exact recipe already in
  cg_view.c / CG_DrawCrosshair true-aim projection; cerebrum 2026-07-06). Route the owner's
  clientNum + rank to the cgame via one entityState field or a spare renderfx/eFlags bit on the
  mannequin (the officer eagle proves the render-bit -> icon routing works). This gives head-locked,
  distance-scaled plates that stay correct if the camera framing changes.

Recommendation: ship Route A, upgrade to Route B if head-locked text is wanted.

### 3.5 Ready-up, countdown, launch (unchanged from Phase B/C, they don't touch the body)
- Ready: name-append bus index 31 (`,rk`) -> `lobbyReadyToggle` flips
  `player.flags["coop_lobbyReady"]`; a monitor counts deployed vs ready. On ready, optionally have
  that player's mannequin play a one-shot (salute) then resume the pool.
- Launch handoff: set `coop_lobbyActive=0` (all loops exit), **delete every mannequin**
  (`mann delete` definitively stops its anim loop), `player show` + `freezecontrols 0` + restore
  stashed cvars (`g_inactivespectate`/`g_forcerespawn`/`g_inactivekick`), then the CLEAN transition
  mirroring `coop_mod/maptest.scr::coop_maptest_transition` -> `stuffsrv ("map "+coop_lobbyNextMap)`
  (SV_Map_f, no archive). NEVER `bsptransition`/`missioncomplete` on the live coop server. Default
  `coop_lobbyNextMap = "briefing/briefing1"` (chains to m1l1).

### 3.6 What gets deleted / simplified vs today
- Remove from the hot path: `coop_lobbypose`, `coop_lobbyholdpose`, the FL_IMMOBILE reliance, the
  hide-until-posed reveal dance, and the g100 single-pose. The mannequin makes them moot.
- Keep: the shared camera, auto-deploy loop, HUD hiding, slot anchors, prop spawn - all reused as-is.

---

## 4. Exact engine edits required and where

**Body / skin / animation: NONE.** Options 1 and 2 are pure `.scr` + the already-authored
`anims_shared.txt` pools. This is the headline result - the fluid animated own-skin squad needs no
engine change at all.

Optional edits, only for the nicer nameplate (Task 5, Route B) - a single game.dll+cgame.dll pair:
1. `code/cgame/cg_modelanim.c` - add `CG_LobbyNameplate(refEntity_t*, ownerClientNum, rank)` next to
   `CG_ActorOverheadIcon` (227); call it from the actor-render path (~1689) when a lobby-mannequin
   render bit is set. Draw the rank `RT_SPRITE` over the head tag (clone `CG_ActorOverheadIcon`,
   swap the sprite for `textures/hud/coop_rank_NN.spr`) and the netname via head-tag world->screen
   projection + `cgi.R_DrawString` (projection recipe already in cg_view.c). Read the name from
   `cgs.clientinfo[ownerClientNum]`.
2. Identity routing (pick ONE): reuse `rendereffects "+coopboss"` on the mannequin and add a spare
   `eFlags`/renderfx bit (or one `entityState` field) carrying the owner clientNum + rank so the
   cgame can resolve the plate. The officer eagle path (RF_COOP_BOSS + RF_ADDITIVE_DLIGHT) is the
   working template for "script sets a render bit -> cgame draws a head sprite."

If OPTION 1's script_model renders a player tik non-skeletally (verify on boot), the fix is to use
OPTION 2 (Actor + setModel) - still no engine edit - not to modify the engine.

Deploy reminders (cerebrum): `build.ps1` does NOT deploy game.dll; fgame changes need
`cmake --build .cmake --config Release --target fgame` + hand-copy to GOG root. cgame.dll is deployed
by build.ps1. Any DLL swap requires the game closed. The `.scr`/`anims_shared.txt`/UI work ships in
the pk3 with a normal `build.ps1`.

---

## 5. Risks + open questions

1. **script_model skeletal render (the one real unknown).** `ScriptModel` ctor sets `ET_MODELANIM`;
   confirm a player tik animates skeletally (not static/T-pose) as a script_model. If not, switch to
   OPTION 2 (Actor + `setModel`), which is unambiguously skeletal. 15-minute boot test with one
   mannequin + `anim "coop_lobbyselect"`.
2. **Does `anim` crossblend between pool picks on a script_model?** `SetAnimEvent` calls `NewAnim`
   (single slot) - blending relies on the alias `crossblend` flags (coop_lobbyselect has
   `crossblend 0.5`) and on all clips sharing a neutral stance (the same reason the menu looks
   seamless with a single frameInfo). Expected to look at least as good as the menu; verify, and if a
   pick lands hard, curate the pool (already excludes pullups/lean).
3. **Hidden real player + cued camera edge cases.** Confirm a hidden, frozen, deployed player renders
   nothing (no floating weapon viewmodel) while `cuecamera` holds - the current lobby already
   hides/shows the player and cues the camera, so this is low risk, but re-verify with the body
   permanently hidden.
4. **Mannequin lifecycle vs late joiners / disconnects.** Spawn a mannequin on deploy, delete on
   disconnect and at launch. `mann delete` is the definitive loop-stop (a NULL owner otherwise leaves
   an orphan idle thread). Round-robin slot assignment already exists (`coop_lobbySlot`).
5. **Skin roster hygiene.** Restrict to non-`_fps` allied tikis; a bad/German skin on an allied slot
   is only cosmetic here but persist (`stufftext dm_playermodel`) must use an allied name so the
   launched mission's InitModel doesn't fall back to american_army.
6. **Nameplate Route A projection.** Fixed-slot `ihuddraw` plates assume the static camera framing;
   if `coop_lobbyCam*` cvars are retuned, the plate X/Y cvars must follow. Route B (head-locked)
   removes this coupling but costs the cgame edit.
7. **Feet/height + facing.** Slot origins were captured at EYE height (viewpos); reuse
   `coop_lobbyFeetDrop` (~82u) for the mannequin feet, and set yaw from `coop_lobbySlotYaw`.
8. **Do we still need to deploy the real player at all?** Keeping them deployed-but-hidden is the
   low-risk path (coop lifecycle + cuecamera already assume a deployed player). A pure-spectator +
   cuecamera variant is possible but unproven; not recommended for v1.

---

## Key file:line index
- MP menu picker + cvars: `cl_uiplayermodelpicker.cpp` (roster 44-113, FileChosen 307-326);
  `cl_ui.cpp` UI_ApplyPlayerModel_f 3443 (`dm_playermodel`), UI_GetPlayerModel_f 3468/3479
  (`ui_disp_playermodel`).
- Preview widget: `cl_uistd.cpp` `UIFakkLabel` 213; render-model branch 1598-1697; `CL_Draw3DModel`
  call 1685; resource events `rendermodel` 156/407, `anim`/`modelanim` 196/201/435.
- UI animator: `cl_invrender.cpp` `CL_Draw3DModel` 60; anim re-pick 104-188; RenderScene 211-212;
  RDF_HUD|RDF_NOWORLDMODEL 84.
- Anim pools: `models/player/base/anims_shared.txt` selection idles 10-26; `coop_lobbyselect1..12`
  484-495; `coop_pose_*` 458-470.
- In-world entity: `scriptslave.cpp` `ScriptModel` 1999; `SetAnimEvent` 2026 (gi.Anim_NumForName ->
  NewAnim -> animdone); `SetModelEvent` 2017; ctor eType=ET_MODELANIM + AddWaitTill(ANIMDONE)
  2012-2014. `bg_public.h:501` / `lodthing.cpp:197` ET_MODELANIM_SKEL.
- Player statemap conflict: `player.cpp:5571` (EvaluateState FL_IMMOBILE early-return).
- Overhead icon: `cg_modelanim.c` `CG_ActorOverheadIcon` 227, call 1689-1707; `RF_COOP_BOSS` set by
  `rendereffects "+coopboss"` `entity.cpp:4015`; `EV_AttachModel` `entity.cpp:379/1587`.
- Existing lobby: `coop_mod/lobby.scr`, `maps/co_lobby1.scr`, engine events `Player::CoopLobbyPose`
  / `coop_lobbyholdpose` in `player.cpp`.
- Related notes: bug-355 (spawn player tik), bug-378/379/380/382 (pose/twitch/statemap), cerebrum
  2026-07-08 (FL_IMMOBILE vs animation), `_research/coop_lobby_phaseBC_plan.md` (skins/nameplate/
  ready/launch already scoped for the real-player approach - reuse wholesale).
```
