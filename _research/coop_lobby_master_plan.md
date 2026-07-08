# HZM Coop Pre-Mission Lobby - Master Implementation Plan

> Definitive, no-guesswork build plan to finish `co_lobby1`. Every claim is cited `file:function:line`
> against the tree as of 2026-07-08. Supersedes / reconciles `coop_lobby_diagnosis.md`,
> `coop_lobby_phaseBC_plan.md`, `coop_lobby1_build.md`, `coop_lobby.md`, `lobby_idle_anims.md`.
> Implement top-to-bottom. Foundation (F1-F4) first; it stabilises everything after it.

---

## 0. How to use this document

- **Section 1** = the frozen surface. Do not redesign any of it.
- **Section 2** = the proof layer: the engine/script facts every task leans on, each with a citation.
  If an implementation ever "doesn't match", re-read the cited line before improvising.
- **Section 3** = the ordered task list. Each task is self-contained: files+lines, the exact code
  shape, sequencing, the verification test, the risks, the rollback.
- **Section 4** = every prior disagreement, resolved with the code evidence.
- **Section 5** = what to test first tomorrow (the already-deployed, untested pose).
- **Section 6** = the only things that genuinely need an in-game test, each with the exact test.
- **Section 7** = the full new-surface registry (cvars, name-bus markers, ihuddraw slots, files).

Build/deploy is `.\build.ps1` from `C:\mohaa-coop-dev` (packs the mod pk3 + deploys). Engine changes
(none required for the recommended path) need the CMake rebuild in `openmohaa-hzm/`. Test with the
console line `exec coop_mod/cfg/campaign_start.cfg`.

---

## 0b. VERIFICATION PASS (adversarial self-review, 2026-07-08)

Re-opened the plan and re-checked every load-bearing citation against source, hunted for interference
on the lobby map, and resolved the launch. Honest results below.

### Corrections made (I was wrong / incomplete)

1. **The "briefing launch" Open Question was a FALSE unknown - now RESOLVED to a shipping path.**
   `ui/coop_start/m1.cfg:8-9` already offers `briefing/briefing1` as a **selectable coop start map**:
   `stuffcommand "set ui_dmmap briefing/briefing1;seta coop_mapcmd map briefing/briefing1"`. So
   `briefing/briefing1` running under coop gametype 2 is a **shipped, user-facing** path (menu tile ->
   `ui_startdmmap 2`), not a guess. Cross-confirmed: `briefing1.scr:7` runs `coop_mod/main.scr::main`,
   `:23` uses the coop `waitForPlayer`, `:108-116` has coop-SPECIFIC slide handling (the devs ran it in
   coop and worked around a slide that "did not show right in coop" - proof execution reaches past the
   `level waittill spawn` at `:15`), and `:130-137 endbriefing` does `exec global/missioncomplete.scr
   "m1l1"` when `level.gametype != 0`. FIXED: T7 now uses the proven in-session equivalent
   `stuffsrv ("map " + level.coop_lobbyNextMap)` (the maptest.scr:162 / restartMap:1569 mechanism) with
   default `briefing/briefing1`; briefing1 self-advances to m1l1 via its own coop `endbriefing`. Removed
   from Open Questions.

2. **Teardown under-specified.** Round 1 hardcoded `g_inactivekick "0"` on restore and under-emphasized
   `g_forcerespawn`. FIXED in T7 + new T10: also stash `coop_lobbyPrevInactiveKick` in `lobbyMapMain`,
   and treat the `g_forcerespawn` restore as CORRECTNESS-critical - leaking `g_forcerespawn 1` into the
   mission would auto-respawn DBNO'd/dead players in 1s and fight the coop respawn/DBNO logic.

3. **New interference found - the name-append bus is NOT lobby-gated.** A lobby player can still fire
   `noclip` (bus idx 15 -> developer.scr::noclip_toggle, which BYPASSES the cheat gate per BIND.SCR:47),
   `medkit`/`cover`/`ammobox`/`dbno-test`, etc. `noclip` sets `MOVETYPE_NOCLIP`, which makes
   `EvaluateState` early-return (player.cpp:5567) => the pose is lost AND the player flies out of the
   freeze. Deployables would spawn sandbags/ammo in the staging area. ADDED task **T9** to lobby-gate
   the gameplay bus actions in `playerNameCommand`.

### Confirmed correct (re-read the exact lines; no change needed)

- **Pose (F1):** torso STAND `action { none : default }` (player_Torso.st:41-44) -> `StopPartAnimating(torso)`
  (player.cpp:5661-5663); EMOTE_ATEASE legs = `coop_emote_atease` = `misc/00A100_idle.skc`
  (anims_shared.txt:453; player_Legs.st:1596-1599); the `STAND : -HAS_WEAPON` exit (player_Legs.st:1614)
  is why holster (keeps the weapon in inventory, replace.scr:1897-1904) works and `takeall` breaks it.
- **Lock (F2):** `freezecontrols` -> `m_bFrozen` (player.cpp:13089-13092) -> PMF_FROZEN (player.cpp:4049);
  PMF_FROZEN blocks view (bg_pmove.cpp:1250-1253) + move/jump (bg_pmove.cpp:1426-1429); FL_IMMOBILE is the
  ONLY thing that early-returns EvaluateState (player.cpp:5571) besides NOCLIP - `freezecontrols` does NOT.
  m_bFrozen resets on respawn (player.cpp:2240). All verbatim as claimed.
- **Star vs nameplate (F4/T3) - two SEPARATE layers, re-verified:** the star is an engine-UI **menu**
  (`hud_health`, cl_ui.cpp:57) hidden by PMF_NO_HUD in `UI_Update` (cl_ui.cpp:2040-2064). The nameplates
  are the cgame **ihuddraw** layer (`CG_HudDrawElements`, cg_drawtools.cpp:587-596) gated only by
  `cg_hud`/`cg_huddraw_force`, which does NOT check PMF_NO_HUD. `drawhud 0` (scriptthread.cpp:4630) sets
  PMF_NO_HUD globally; respawn clears it (player.cpp:2201). So `drawhud 0` hides the star AND leaves the
  nameplates drawn. Claim holds.
- **Name bus (T5/T6):** next free marker index is 31 (variables.scr:126-156 end at 30); the dispatch loop
  `playerNameCommand` (player.scr:501-548) already reaches case 30, so adding cases 31/32/33 + array keys
  "31"/"32"/"33" is correct; the `while(local.command[string(local.i)])` extractor (player.scr:333) walks
  every key. `,rk`/`,sn`/`,sp` collide with no existing marker. Works while frozen (name detection is in
  the ALWAYS block, player.scr:105-117, outside the isActive gate; UI command, not pmove).
- **Skin swap (T6):** `model` IS an Entity script event (entity.cpp:426/433 -> EV_SetModel ->
  `Entity::SetModelEvent` entity.cpp:1569 -> `gi.setmodel` entity.cpp:2066, updates modelindex, replicates);
  `dm_playermodel` is the userinfo key read into `client->pers.dm_playermodel` (g_client.cpp:781-788), which
  `InitModel` uses on the mission spawn (player.cpp:2536-2547, must be `american`/`allied`, non-`_fps`). So
  the live `self model` + `set dm_playermodel` persist recipe is correct. (Nuance: the live swap is
  cosmetic-only for the frozen lobby; the authoritative model + controller tags are re-set by InitModel on
  the mission spawn.)
- **Instant deploy (F3):** mechanism (lobbyAutoSpawnLoop -> skipTeamAndWeaponSelect -> join_team) and the
  BACKUP-SPAWN-is-a-harmless-print claim re-verified (player.scr:62-68 placement commented at :66-67).

### System-interference sweep on co_lobby1 (job 3) - what fires, what is already gated

- **Officer / boss waves: ALREADY GATED (effective, verified).** `officer.scr::coop_officer_policy:34`
  returns "none" when `level.coop_lobbyMap == 1`, and the officer init `end`s early on "none"
  (officer.scr:156-158 "policy NONE - officer disabled on this map"). No officer spawns. **Minor cosmetic
  gap:** officer.scr:155/157 print the policy via UNGATED `iprintlnbold`, so the lobby shows
  "OFFICER: spawn policy = none" / "policy NONE ..." on screen. Optional polish (T10): wrap those two
  debug prints in `if( !level.coop_lobbyMap )`, exactly like objectives.scr:155/161 already does.
- **Side objectives: ALREADY GATED (via the officer policy).** `objectives.scr:153-156` reads
  `coop_officer_policy` (="none" on lobby maps, officer.scr:34) and `end`s early -> no side objectives
  registered; the `!level.coop_lobbyMap` guards at :155/161 only silence the diagnostic print. No action.
- **Weather: gated.** `co_lobby1.scr:19` sets `level.coop_weatherTheme = "none"`.
- **DBNO / spawn-protection / tinnitus / ADS monitors: run, but inert.** They thread per player in
  `manageAliveSpawning` (player.scr:943-960). co_lobby1 is a stripped training BSP with the training/AI
  scripts removed and the officer gated, so there is NO damage source -> DBNO never triggers; spawn
  protection gives `nodamage` for 8s then `takedamage` with nothing to hurt the frozen player. Harmless.
  (Optional hardening in T10: keep lobby players `nodamage` for the whole lobby.)
- **preventSpawnStuck: self-neutralizes.** It threads per player (player.scr:936) and would fire after 20s
  of not moving - but its AFK check (player.scr:981-987) resets the timer every ~11s whenever `viewangles`
  are unchanged, and a FROZEN player's viewangles never change, so it never reaches the 20s "press use to
  switch spawn" warp. Robust while frozen. No action needed (noted for future freeze changes).
- **XP: exactly what we want.** No kills in the lobby => no XP awards; `xp_identify` (manageSetup ->
  xp.scr) still loads the player's saved record and sets `flags["coop_xp_rank"]` which the T3 nameplate
  READS; `xp_flush` on launch persists. Read-only, correct.

### Multiplayer / late-joiner / dedicated (job 3)

- **Shared camera with N players:** `cuecamera` is a GLOBAL command (all clients bind to the one camera);
  `lobbyOnSpawn:187-190` re-cues on each (re)spawn (a re-cut to the same static cam is a visual no-op). So
  all 1-4 players see the SAME framed squad shot - the intended design. No per-player camera needed.
- **Slots:** `lobbyOnSpawn:154-159` round-robins slots 1..4 and assigns once (kept across respawns).
  **Gap:** if `sv_maxclients > 4`, a 5th player wraps to slot 1 and overlaps player 1's origin. The lobby
  is a 4-slot staging area - cap or accept overlap (see T10).
- **Late joiners:** `lobbyAutoSpawnLoop` force-joins them, `lobbyOnSpawn` seats+poses+freezes+cues+hides
  HUD, and music replays via `level.coop_musicCommand` (player.scr:1234-1240). Works.
- **Dedicated vs listen:** the whole flow is server-side (auto-join, ready, `stuffsrv` launch) so it works
  on both. The "Begin Full Campaign" menu button (T8) is listen-only (a dedicated server sets
  `ui_dmmap co_lobby1` in its start cfg). Dedicated-empty just never trips the ready monitor (deployed 0).

---

## 1. KNOWN-GOOD - DO NOT TOUCH

| Thing | Where | Why it is done |
|---|---|---|
| **Lobby camera** | `lobby.scr::spawnLobbyCamera`/`applyLobbyCam`/`lobbyCamTune` (58-123) | Camera IGNORES `.origin`/`.angles` (bug-360/363); it is positioned by `movetopos` + aimed by `watch` a `script_origin` look-at, the t2l2 recipe. Baked defaults = user viewpos `-5304 -248 -237` yaw 230; cvar-tunable `coop_lobbyCam*`/`coop_lobbyLook*`/`coop_lobbyCamFov`. Working. |
| **`isCoopEnabledMap` co_lobby whitelist** | `main.scr:1641-1642` (`case c`) | `co_lobby*` returns `game.true` so `inCoopMode` is true, the `coop_mod/player` statefile stays loaded, and `EMOTE_ATEASE` resolves (bug-357/359). CONFIRMED via log. |
| **XP system** | `coop_mod/xp.scr` (whole file) | Read-only from the lobby. We READ `flags["coop_xp_rank"]` and CALL `xp_flush` (:951). Never modify xp.scr. |
| **Coop framework spawn lifecycle** | `player.scr::manage`/`manageSpectator`/`manageAliveSpawning`, `main.scr::playerSpawnEvent` | Works for 55 campaign maps. Lobby integrates via `level.coop_lobbyMap`-gated hooks only (the established pattern - see the existing gated lines at player.scr:859/909/919). Do not restructure it. |
| **Campaign chain briefing1 -> m1l1** | `maps/briefing/briefing1.scr:5,133-135` | Vanilla; `level.coopNextMap="m1l1"` then `spmap m1l1`/`missioncomplete m1l1`. The lobby only kicks off the chain. |
| **Existing emote statemaps** | `player_Legs.st` EMOTE_SALUTE(1438)/EMOTE_ATEASE(1589)/EMOTE_STRETCH(1618); aliases anims_shared.txt:452-454 | The 3 shipped emotes + the `coop_emote_*` weight-free aliases. Reuse the SHAPE; do not edit the existing 3. |
| **Name-append command bus** | `variables.scr::getNameAppendCommands` (124-157), `player.scr::playerNameCommand` (495-549), `ui/BIND.SCR` | The bindable-action pipeline. We APPEND markers (next free index 31); do not renumber 0-30. |
| **build/deploy + start_server chain** | `build.ps1`, `coop_mod/start_server.cfg`, `coop_mod/cfg/campaign_start.cfg` | `campaign_start.cfg` (set ui_dmmap co_lobby1 + exec start_server.cfg) already exists and is correct; `start_server.cfg` ends with `ui_startdmmap 2` (reads ui_dmmap). |
| **The props + auto-spawn loop + HUD-wipe loop** | `lobby.scr::spawnProps`/`lobbyAutoSpawnLoop`/`lobbyHideHud` | Working. F3 only TUNES the auto-spawn cadence; F4 only ADDS `drawhud 0` re-assertion. |

---

## 2. Load-bearing code facts (the proof layer)

### 2.1 Freeze / pose / lock

- `player freezecontrols 1` -> `Player::FreezeControls` sets `m_bFrozen = ev->GetBoolean(1)` (**player.cpp:13089-13092**).
- Each server frame the flag is re-derived: `pm_flags &= ~(PMF_FROZEN|...)` then `if (level.playerfrozen || m_bFrozen) pm_flags |= PMF_FROZEN` (**player.cpp:4045-4051**). So BOTH `freezecontrols` (per-player `m_bFrozen`) and `freezeplayer` (global `level.playerfrozen`) set `PMF_FROZEN`.
- `PMF_FROZEN` blocks ALL view change (**bg_pmove.cpp:1250-1253**, `PM_UpdateViewAngles` early-returns) and ALL movement/jump (**bg_pmove.cpp:1426-1429**, PmoveSingle returns after only `PM_CheckDuck`). So a frozen player cannot rotate, walk, or jump. Menu/console/chat/quit are UI-layer, unaffected.
- `PMF_FROZEN` is NOT in the per-frame clear mask, so it must be re-asserted only when it is lost. It is lost on **respawn**: the ctor sets `m_bFrozen = false` (**player.cpp:2240**), and the spawn setup does not restore it. => a per-frame re-assert (`lobbyLockWatch`) survives the coop respawn churn.
- **`freezecontrols` does NOT block the animation statemap.** `EvaluateState` early-returns ONLY on `MOVETYPE_NOCLIP` and `FL_IMMOBILE` (**player.cpp:5567-5574**) - not on `PMF_FROZEN`. So `forcelegsstate`/`forcetorsostate` still work while frozen.
- **`immobile`/`FL_IMMOBILE` is the WRONG lock** - it makes `EvaluateState` early-return (player.cpp:5571) so the pose can never be forced, AND it only sets `PMF_NO_MOVE` (player.cpp:4053-4056), not the view lock. Never use it to lock the lobby.
- **Torso "action none" makes the legs clip own the whole skeleton.** `ForceTorsoState` -> `EvaluateState(ts)` (**player.cpp:8218-8228**); STAND's action is `none : default` (**player_Torso.st:41-44**); when `torsoAnim == "none"` the engine calls `StopPartAnimating(torso); animdone_Torso = true` (**player.cpp:5661-5663**), dropping torso frame-slot weight so the full-body legs anim (EMOTE_ATEASE) shows with no rifle-carry over the top. This is the pose fix for bug-368.
- **`EMOTE_ATEASE` legs = the MP at-ease idle.** State at **player_Legs.st:1589-1615** plays alias `coop_emote_atease` = `misc/00A100_idle.skc` (**anims_shared.txt:453**) = the selection-screen hands-on-hips idle. Its exits bounce to STAND on `FORWARD/BACKWARD/STRAFE/+JUMP/+CROUCH/+ATTACK/+HAS_WEAPON/-HAS_WEAPON` and self-loop on `ANIMDONE_LEGS`.
- **Why holster works and `takeall` does not:** the `STAND : -HAS_WEAPON` exit (player_Legs.st:1614) fires when the weapon leaves inventory. `takeall` empties inventory => `-HAS_WEAPON` => bounce to `unarmed_stand_idle` = the "invisible rifle" (bug-368). `replace.scr::holster` (**replace.scr:1897-1904**) only *puts the weapon away* (stays in inventory), so `HAS_WEAPON` stays true and no bounce. A frozen player sends no move/attack/jump input, so none of the other exits fire either.
- The spawn-crouch cause (bug-370): `freezeplayer` set BEFORE deploy pinned `PMF_FROZEN` while the player was still in the spawn crouch, and `PM_CheckDuck` still runs under freeze (bg_pmove.cpp:1427) so it never stood him up. Fix = pose STANDING **while unfrozen** (`moveposflags "standing"` in the EMOTE entrycommands, player_Legs.st:1591-1594, lets pmove stand him), THEN freeze.

### 2.2 The deploy path (the "still have to click to spawn" 5s limbo)

- A connecting player is put in spectator by `manageSetup` (**player.scr:262** `local.player spectator`), then `manageSpectator` sets `coop_isActive = -1` on first sight (**player.scr:689-695**).
- **The ONLY thing that deploys a fresh spectator is `join_team`.** `manageSpectator`'s in-spectator branch calls `skipTeamAndWeaponSelect` **only if `primaryfireheld`** (**player.scr:788-794**). The lobby's `lobbyAutoSpawnLoop` (**lobby.scr:129-142**) calls it unconditionally every `wait 0.5`.
- `skipTeamAndWeaponSelect` (**main.scr:325-363**) sets `primarydmweapon "rifle"` then `join_team "allies"` (with `g_teamswitchdelay` forced to 0) + a `popmenu 0` stagger to beat the engine's 1s weapon-picker re-push.
- `join_team` -> engine respawn -> `playerSpawnEvent` (**main.scr:253-282**, sets rifle + popmenu, then `manageAliveSpawning`) -> `manageAliveSpawning` (**player.scr:833-964**): past the spectator/forceValidTeam early-exit (857-863) it runs `playerPlaceAtSpawn` + `coop_playerJustSpawned` callback (876-879) and finally `coop_isActive = 1` (**player.scr:918**).
- **`g_forcerespawn 1` (lobby.scr:27) is NOT the deploy mechanism.** It only auto-respawns players who are already DEAD; a fresh spectator is never "dead". The lobby.scr:25-27 comment is misleading - keep the cvar (harmless for later respawns) but do not rely on it to deploy.
- **BACKUP SPAWN spam is harmless.** `player.scr:62-68` prints when a NON-spectator has `coop_isActive == -1` (the window between `join_team` and `coop_isActive=1`). Its placement call is **commented out (player.scr:66-67)** - it is a bare `println`, nothing else. ~196 prints == the deploy window in frames.
- Diagnostic already wired: `LOBBYDBG: manageAliveSpawning EXIT-A ...` (player.scr:859), `... reached NO-SPEC gate ...` (:909), `... REACHED active=1 ...` (:919). These print only when `level.coop_lobbyMap` is set.

### 2.3 The vanilla bottom-left STAR and the HUD chrome

- The bottom-left star = the vanilla **`hud_health`** menu (**cl_ui.cpp:57** `static Menu *hud_health`). The mod's HUD-fade multiplies its alpha by `ui_hudAlpha` (**cl_ui.cpp:1871** `UI_SetMenuWidgetsAlpha(hud_health, fHudA)`); `ui_hudAlpha` is published by the cgame every frame from activity (**cg_drawtools.cpp:2016** `cgi.Cvar_Set("ui_hudAlpha", ...)`). The COMPASS is deliberately exempt (never in the fade set).
- **The clean, total hide is `drawhud 0`.** `ScriptThread::EventDrawHud` (**scriptthread.cpp:4604-4635**) sets `PMF_NO_HUD` on ALL clients (state 0 => `|= PMF_NO_HUD`). The client hides the ENTIRE engine HUD when `pm_flags & PMF_NO_HUD` - health(star)/ammo/compass/weapons/crosshair all `ForceHide()` (**cl_ui.cpp:2040-2064**).
- **The catch: every respawn CLEARS `PMF_NO_HUD`** (**player.cpp:2201** `client->ps.pm_flags &= ~PMF_NO_HUD`). So a single `drawhud 0` is undone by the next respawn - it must be re-asserted per spawn (and the coop respawn churn is exactly why the star kept coming back).
- **DECISIVE for the nameplate:** the custom `ihuddraw` layer is drawn by `CG_HudDrawElements` (**cg_drawtools.cpp:587-596**), gated ONLY by `cg_huddraw_force`/`cg_hud` - it does **NOT** check `PMF_NO_HUD`. So `drawhud 0` hides the vanilla star while `ihuddraw` nameplates (slots 100-107) stay visible. Route A works alongside the star-hide.
- `ihuddraw` builtin signatures (verified **scriptthread.cpp:5150-5410**): `ihuddraw_shader p idx name`, `ihuddraw_align p idx h(left|center|right) v(top|center|bottom)`, `ihuddraw_rect p idx x y w h`, plus `_virtualsize p idx bool`, `_color p idx r g b`, `_alpha p idx a`, `_string p idx s`, `_font p idx name`. `idx` accepts any int (0-255 nominal).

### 2.4 Ready flag, skin model, music, launch

- Native ready: `ready`/`notready` cmds + getter exist (`EventSetReady`/`EventSetNotReady`/`EventGetReady` **player.cpp:11759-11777/11754**, `IsReady` **:12841** = `m_bReady && !IsDead()`), BUT `m_bReady` **defaults true on every spawn** (**player.cpp:2156**) and is respawn-fragile => use it as an optional cross-check only, store truth in `flags["coop_lobbyReady"]`.
- `InitModel` (**player.cpp:2502-2559**): in MP-allied it reads `client->pers.dm_playermodel`; if the name does NOT begin with `american`(8) or `allied`(6), or ends in `_fps`, it falls back to `american_army` (**player.cpp:2536-2547**). So the skin roster MUST be `american*`/`allied*`, non-`_fps`.
- The vetted allied roster is the game's own picker (**cl_uiplayermodelpicker.cpp:44-113**), the `allied_*`/`american_*` rows only (24): `american_army, american_ranger, allied_101st_captain, allied_101st_infantry, allied_101st_scout, allied_501st_pir_scout, allied_501st_pir_soldier, allied_airborne, allied_manon, allied_british_6th_airborne_captain, allied_british_6th_airborne_paratrooper, allied_pilot, allied_russian_corporal, allied_russian_crazy_boris, allied_russian_recon_scout, allied_russian_recon_soldier, allied_sas, allied_british_tank_corporal, allied_russian_seaman, allied_technician, allied_Wheathers, allied_US_Tank, allied_US_Mask, allied_british_Cmd, allied_british_Tank`. (The "~70" in the vision counted both teams/`_fps`; this 24-entry set is the authoritative, guaranteed-present allied list.)
- Music: `replace.scr::tmstartloop <path>` (**replace.scr:553-582**) sends `tmstop` + `tmstartloop <path>` to every client and stores `level.coop_musicCommand`; late joiners auto-replay it in `player.scr::setupCmds` (**player.scr:1234-1240**). **Asset ships: `sound/music/Kleveburg.mp3`** (already used by `e1l4.scr:397`). `tmstop` (**replace.scr:534-545**) clears it.
- Rank emblem naming (reuse verbatim, xp.scr:526-531/574): `local.rn = flags["coop_xp_rank"]` (0-12); `if(local.rn < 10){ local.rn = "0"+local.rn }`; shader = `"textures/hud/coop_rank_" + local.rn` (=> `coop_rank_00`..`coop_rank_12`, all shipped).
- Clean map transition (the launch): mirror `maptest.scr::coop_maptest_transition` (**maptest.scr:145-163**) / `main.scr::restartMap` (**main.scr:1522-1570**): `g_scriptcheck 0`; `xp_flush`; stash `sv_maplist` -> `coop_prevMapList` then clear; `level.coop_preventGameTypeChanges = game.true` + end the changeGameType thread; `game.loadout = false`; `stuffsrv ("map " + next)`. `SV_Map_f` hardcodes `bTransition=false` -> no persistant archive -> no crash. **Do NOT** route through `global/missioncomplete.scr` (runs the mission XP debrief + `bsptransition` archive-crash path).
- Menu button pattern (**ui/coop_start.urc:348-401**): a `Button` resource with `stuffcommand "wait 250;exec <cfg>"`; the "apply" button already does `exec coop_mod/start_server.cfg`.

---

## 3. ORDERED TASK LIST

### FOUNDATION - do first, in order. Each stabilises the next.

---

#### F1. Finalize the at-ease POSE  (already deployed, UNTESTED - verify, then harden)

**Goal:** each real player stands in their own MP skin at parade-rest/hands-on-hips (`EMOTE_ATEASE`),
rifle slung on the back, no rifle-carry over the top, not crouched, not invisible-rifle.

**Files/functions:** `lobby.scr::lobbyPoseAndFreeze` (203-236), reads statemap `player_Legs.st:1589`
(EMOTE_ATEASE) + `player_Torso.st:30` (STAND). No engine change.

**Exact current recipe (verify it is intact):**
```
lobbyPoseAndFreeze:
  wait 0.5                               // let the spawn loadout settle
  self.origin    = flags["coop_lobbyOrg"]
  self.viewangles = (0 flags["coop_lobbyYaw"] 0)
  self waitthread coop_mod/replace.scr::holster   // slings rifle, STAYS in inventory (no -HAS_WEAPON)
  wait 0.3
  self forcetorsostate "STAND"           // action none -> torso weight 0 -> legs own skeleton
  self forcelegsstate  "EMOTE_ATEASE"    // full-body at-ease, WHILE UNFROZEN (pmove stands him)
  wait 0.2
  self freezecontrols 1                  // NOW lock (does not block the statemap)
  thread lobbyLockWatch                  // re-assert per frame (respawn clears m_bFrozen)
```
This is sound per 2.1: holster (not takeall) keeps `HAS_WEAPON` true; STAND torso is `action none`;
pose is set while unfrozen so `moveposflags "standing"` stands him out of the spawn crouch; freeze is
last and does not block `EvaluateState`.

**Fallback (only if STAND-torso visibly flickers during the long idle rotation of T2):** add a
dedicated torso state to `player_Torso.st`, byte-mirroring `COVER_TORSO` (player_Torso.st:206-238) -
`movetype legs`, `camera behind`, `action { none : default }`, and a MINIMAL `states` block (KILLED,
vehicle/turret/ladder, PUTAWAY_MAIN:PUTAWAYMAIN, RAISE_WEAPON:NEW_WEAPON, RELOAD_WEAPON:RELOAD - NO
attack/AIM/movement edges). Name it `EMOTE_ATEASE_TORSO`. Then `forcetorsostate "EMOTE_ATEASE_TORSO"`
instead of `"STAND"`. It has strictly fewer edges than STAND, so it cannot be pulled off `action none`.

**Sequencing:** F1 is independent; it is already deployed. Verify FIRST (Section 5).

**Verification:** `exec coop_mod/cfg/campaign_start.cfg`. Correct = standing, hands-on-hips, rifle on
back, still. Failure reads: crouched => pose ran after/without the unfrozen stand; rifle in hands =>
torso not `none` (use the fallback torso state); invisible rifle => a `-HAS_WEAPON` bounce (a `takeall`
crept back - there must be none). `qconsole.log`: any `^~^~^ ForceLegsState: state EMOTE_ATEASE not
found in <file>` means the statefile was reset (isCoopEnabledMap regressed) - should not happen now.

**Risks:** `.st` edits (fallback only) ERR_DROP the server on a bad parse and the error surfaces ONLY
on a real client (not dedicated) - boot on a listen server; run a brace-depth scan (depth never < 0,
== 0 at every `state` line). ASCII only.

**Rollback:** the pose block is self-contained in `lobbyPoseAndFreeze`; reverting to the prior
`forcelegsstate` only is one edit. The `.st` fallback is additive (a new state); delete the state block
to revert.

---

#### F2. The clean LOCK  (already deployed - confirm it is the ONLY lock)

**Goal:** move + look + fire locked; menu/console/chat/quit usable; respawn-proof; no crouch.

**Files/functions:** `lobby.scr::lobbyPoseAndFreeze` (freezecontrols, 231) + `lobby.scr::lobbyLockWatch`
(244-250). Confirm **`freezeplayer` is NOT called anywhere** in lobby.scr (it was removed in bug-370;
lobbyMapMain:15-17 documents the removal).

**Exact code shape (lobbyLockWatch, already present):**
```
lobbyLockWatch:
  while( level.coop_lobbyActive == 1 && self != NULL && self.flags["coop_lobbyFrozen"] == 1 ){
    self freezecontrols 1     // re-assert; respawn resets m_bFrozen (player.cpp:2240)
    waitframe
  }
```
Do NOT re-force the pose in this loop (re-forcing a live idle restarts the clip = visible stutter,
bug-370); the pose self-loops on `ANIMDONE_LEGS` and `lobbyOnSpawn` re-applies it on each respawn.

**Definitive decision:** use `freezecontrols` (per-player `m_bFrozen`), NOT `freezeplayer`
(global `level.playerfrozen`). Evidence: both set `PMF_FROZEN` (player.cpp:4049) so both lock equally,
but `freezeplayer` is global (would also freeze a late connector mid-spawn in the crouch) and was the
direct cause of the spawn-crouch (bug-370). `freezecontrols` per-player + `lobbyLockWatch` per-frame
re-assert is the correct primitive.

**Sequencing:** depends on F1 (freeze is the last step of the pose). Once F3 removes the respawn churn,
`lobbyLockWatch` rarely has to do anything, but keep it (belt-and-suspenders).

**Verification:** in the lobby, try WASD/mouse/jump/fire (no movement, no view turn, no shots); press
Esc (menu opens), `~` (console opens), Enter (chat opens). All four must work.

**Risks:** none new. `freezecontrols` is pmove-only; UI is unaffected by design.

**Rollback:** single-line (`freezecontrols 0` + stop the watch via `coop_lobbyFrozen = NIL`).

---

#### F3. INSTANT DEPLOY  (kill the 5s limbo / click-to-spawn)

**Goal:** the squad appears in the lobby immediately, with no manual "press fire to spawn" and no
multi-second limbo.

**Root cause (proven, 2.2):** deploy = `lobbyAutoSpawnLoop` -> `skipTeamAndWeaponSelect` ->
`join_team "allies"`. The latency is the loop's `wait 0.5` poll granularity plus the connect ->
`manageSetup` -> spectator -> `manageSpectator(isActive=-1)` settle plus the engine team-join ->
respawn -> `manageAliveSpawning` chain. `g_forcerespawn` does nothing here (only respawns the dead).
During that window the player is non-spectator with `coop_isActive==-1` => the harmless BACKUP SPAWN
print (placement is commented out, player.scr:66-67).

**Primary fix (stays entirely in lobby.scr - lowest risk):** change `lobbyAutoSpawnLoop` from a 0.5s
poll to a per-frame poll so a spectator is force-joined the same frame it becomes one:
```
lobbyAutoSpawnLoop:
  while( level.coop_lobbyActive == 1 ){
    for( local.i = 1; local.i <= $player.size; local.i++ ){
      local.player = $player[local.i]
      if( local.player != NULL && local.player.dmteam == "spectator" ){
        waitthread coop_mod/main.scr::skipTeamAndWeaponSelect local.player
      }
    }
    waitframe                 // was: wait 0.5   -- per-frame = deploy within 1-2 frames of spectator
  }
```
`join_team` while already on allies is a no-op, so per-frame calls cost nothing once deployed; only the
~1-2 spectator frames trigger it. Also fix the misleading comment at lobby.scr:25-27 (g_forcerespawn is
NOT the deploy mechanism) - keep `g_forcerespawn 1` for later dead-respawns.

**If the diagnostic still shows a slow deploy (see Verification), add the framework-gated fast path**
(guarded so normal maps are untouched): in `manageSpectator`'s in-spectator branch (player.scr:788-794),
force-join on lobby maps without waiting for `primaryfireheld`:
```
// player.scr:791 (inside the `else` / WHILE-in-spectator block)
if( level.coop_lobbyMap ){
    thread coop_mod/main.scr::skipTeamAndWeaponSelect local.player
}
else if( local.player.primaryfireheld ){
    thread coop_mod/main.scr::skipTeamAndWeaponSelect local.player
}
```
`manageSpectator` runs every manage frame, so this fires the same frame the player reaches the
`isActive==-1` spectator state - the earliest possible deploy. It is `level.coop_lobbyMap`-gated so
non-lobby maps keep the exact `primaryfireheld` behavior (nothing that works changes).

**Sequencing:** F3 before F4 - once deploy is instant there is at most one respawn, so the F4 `drawhud 0`
re-assert has to fire only once; and before all features (they need a deployed, active player).

**Verification:** the diag prints are already in place (player.scr:859/909/919). Read `qconsole.log`:
count frames/time from the first `LOBBYDBG: manageAliveSpawning reached NO-SPEC gate` to
`LOBBYDBG: manageAliveSpawning REACHED active=1`. Target: sub-second, no repeated EXIT-A cycling. On a
listen server the host should simply appear posed in the lobby with no click. Remove the diag prints
once satisfied.

**Risks:** per-frame `join_team` spam is bounded (stops the instant `dmteam != spectator`), and
`skipTeamAndWeaponSelect` already zeroes `g_teamswitchdelay` around the call (main.scr:348-351). The
gated player.scr edit is additive and lobby-only.

**Rollback:** revert `waitframe` -> `wait 0.5`; delete the `level.coop_lobbyMap` branch in
`manageSpectator`.

---

#### F4. Hide the vanilla STAR (bottom-left)

**Goal:** the vanilla `hud_health` star (and the rest of the engine chrome) is hidden in the lobby,
without touching XP and without disabling the HUD-fade for real missions.

**Mechanism (proven, 2.3):** `drawhud 0` -> `PMF_NO_HUD` hides the whole engine HUD incl. the star
(cl_ui.cpp:2040-2064). Respawn clears `PMF_NO_HUD` (player.cpp:2201), so re-assert per spawn. The
custom `ihuddraw` nameplates are NOT affected by `PMF_NO_HUD` (CG_HudDrawElements ignores it,
cg_drawtools.cpp:594) - so T3 nameplates survive this.

**Exact change:** `drawhud 0` is already called at `co_lobby1.scr:26` (prespawn) and inside
`lobby.scr::lobbyHideHud` (263) every 0.5s. Add ONE re-assert at the end of `lobbyOnSpawn` (after the
pose thread is started, ~lobby.scr:193) so the star is gone the instant the (single, post-F3) deploy
completes rather than up to 0.5s later:
```
// lobby.scr::lobbyOnSpawn, after `local.player thread lobbyPoseAndFreeze`
drawhud 0     // re-assert PMF_NO_HUD (respawn cleared it at player.cpp:2201); hides the hud_health star
```
`drawhud` is a level command that iterates all clients (scriptthread.cpp:4611), which is fine - every
client is in the lobby. Keep the `lobbyHideHud` 0.5s loop (it also wipes the coop CUSTOM ihuddraw HUD -
XP bar 62-72, deployables 40-47, dbno 27-39 - via `ihuddraw_alpha 20..90 = 0`, which `drawhud 0` does
NOT cover because that layer ignores PMF_NO_HUD).

**Optional cleaner refinement (reduces the 0.5s wipe fighting the coop monitors):** gate the
HUD-drawing coop monitors off on lobby maps in `manageAliveSpawning` (player.scr:947-959) with
`if( !level.coop_lobbyMap ){ ... }` around the medkit/cover/ammobox HUD monitor threads. This removes
the flicker source (bug-361) entirely. Lobby-gated, additive; skip if you want minimal churn (the wipe
loop already works).

**Do NOT** set `ui_hudAlpha` from script to hide the star - the cgame republishes it every frame
(cg_drawtools.cpp:2016), so a server `stufftext "ui_hudAlpha 0"` is overwritten. `drawhud 0` is the
correct lever.

**Sequencing:** after F3 (so the re-assert fires once, not per churn-respawn).

**Verification:** in the lobby the bottom-left star, compass, ammo, and crosshair are all gone; the
nameplates (T3) still show. On launch to the mission the star returns (fresh map load re-inits the
client HUD and clears PMF_NO_HUD on spawn) - confirm the star is normal in m1l1.

**Risks:** none for missions - `drawhud`/`PMF_NO_HUD` is per-session per-client state cleared on the
next map's spawn; the HUD-fade code and XP are untouched.

**Rollback:** delete the one `drawhud 0` re-assert; the star behaves as before.

---

### FEATURES - after the foundation is verified.

---

#### T2. Weighted idle EMOTE rotation

**Goal:** the 4 soldiers loiter with a weighted-random idle rotation (smoke/scan/talk/lean/stand-still
with ~23% deliberate quiet beats), staggered so they never move in unison. Pool + weights = the
18-entry table in `_research/lobby_idle_anims.md` section 3.

**Files:**
1. `models/player/base/anims_shared.txt` - append weight-free aliases (mirror the shape at 452-454).
2. `coop_mod/player_Legs.st` - append one `EMOTE_*` legs state per new emote (mirror EMOTE_ATEASE,
   player_Legs.st:1589-1615).
3. `coop_mod/lobby.scr` - a per-player driver `lobbyIdleRotate` (threaded from `lobbyOnSpawn`).

**Alias shape (anims_shared.txt, all weight-free per bug-260; every `.skc` verified present in a mounted
pak by lobby_idle_anims.md appendix):**
```
// HZM coop [lobby] idle rotation aliases - weight-free direct (bug-260)
coop_idle_generic     idle/generic_idle_a01(loop).skc
coop_idle_scan        weapon_rifle/curious/rifle_stand_curious.skc
coop_idle_chatter1    idle/chatter01.skc
coop_idle_chatter3    idle/chatter03.skc
coop_idle_oshoulder   idle/rifle_idle_oshoulder01(loop).skc
coop_idle_tough       idle/unarmed_idle_moretough01(loop).skc
coop_idle_cleanshoes  misc/00A102_cleanshoes.skc
coop_idle_nervous     misc/nervousb.skc
coop_idle_alert       weapon_rifle/alert/rifle_stand_alert_a(action).skc
// (salute/atease/stretch already exist as coop_emote_* :452-454; reuse them)
```
Smoking chain (the marquee, `lobby_idle_anims.md` section 4) needs the cigarette PROP frame-commands.
Copy the exact `server { first removeattachedmodel "Bip01 L Finger11" ; 16 attachmodel
models/items/cigarette.tik "Bip01 L Finger11" }` block from the source `new_generic_human.tik` smoking
alias into a `coop_idle_smoke*` alias block (same pattern as the `coop_blindfire_wall` frame block at
anims_shared.txt:481-489). This is the ONE content item that needs a live prop check (Open Question 4).

**Legs-state shape (player_Legs.st, one per alias, mirror EMOTE_ATEASE exactly):**
```
state EMOTE_IDLE_SCAN
{
    entrycommands { moveposflags "standing" }
    legs { coop_idle_scan : default }
    states
    {
        EMOTE_IDLE_SCAN : ANIMDONE_LEGS      // self-loop / hold
        STAND : FORWARD
        STAND : BACKWARD
        STAND : STRAFE_LEFT
        STAND : STRAFE_RIGHT
        STAND : +JUMP
        STAND : +CROUCH
        FALL  : FALLING
        STAND : +ATTACK_PRIMARY_BUTTON
        STAND : +ATTACK_SECONDARY_BUTTON
        STAND : +HAS_WEAPON
        STAND : -HAS_WEAPON
    }
}
```
For a one-shot emote that should return to the base hold rather than loop, point the `ANIMDONE_LEGS`
edge at `EMOTE_ATEASE` (or the generic hold) instead of itself.

**Driver shape (lobby.scr::lobbyIdleRotate, per-player, threaded from lobbyOnSpawn AFTER the pose
settles; gate every iteration on active+frozen+NULL):**
```
lobbyIdleRotate:                    // self = player
  wait ( randomfloat 4 )           // 0-4s initial stagger so the 4 are never in lock-step
  while( level.coop_lobbyActive == 1 && self != NULL && self.flags["coop_lobbyFrozen"] == 1 ){
    local.pick = <weighted pick from the section-3 table>   // ~25% weight => keep EMOTE_ATEASE hold
    self forcetorsostate "STAND"          // keep torso action-none so the legs clip owns the body
    self forcelegsstate  local.pick
    wait ( 5 + randomfloat 7 )            // dwell 5-12s, randomised
  }
```
Do the weighting in SCRIPT (a cumulative-weight roll), NOT via TIKI `weight` flags (bug-260 pools the
aliases and makes them unaddressable). Re-force `forcetorsostate "STAND"` each cycle so a settle can't
leak the torso back. The player stays FROZEN throughout (F2), so the state's movement/attack exits
never fire; the emote only ends on your dwell timer or `ANIMDONE_LEGS`.

**Sequencing:** after F1/F2 (needs the pose + lock proven). Ship the SAFE drop-in idles first (the ones
needing only alias + mirror state); add the smoking PROP chain as a follow-on once Open Question 4 is
confirmed.

**Verification:** watch 4 soldiers for 60s - varied gestures, staggered, with visible still beats;
no T-pose, no snap between clips (a snap = the state's `ANIMDONE` edge is wrong). `qconsole.log` for
`unknown animation <alias>` = a bad alias path.

**Risks:** `.st` ERR_DROP on bad parse, surfaces only on a real client - boot-test on a listen server,
brace-depth scan. Every `.skc` must physically ship (verified). If STAND-torso flickers here, switch to
the F1 dedicated `EMOTE_ATEASE_TORSO`. Smoking PROP: add a safety `removeattachedmodel "Bip01 L
Finger11"` in the chain's `exitcommands` so a cancelled smoke never leaves a stuck cigarette.

**Rollback:** aliases + states are purely additive; the driver is one thread. Remove `lobbyIdleRotate`
to fall back to the static EMOTE_ATEASE hold.

---

#### T3. Overhead NAMEPLATE (rank emblem + clean name)  - Route A (ihuddraw, no rebuild)

**Goal:** above each occupied slot, the player's rank emblem (`textures/hud/coop_rank_NN`, READ from
`flags["coop_xp_rank"]`) + their clean name, framed by the shared static camera.

**Why Route A:** the camera is static and the 4 slots are fixed, so each head projects to a FIXED screen
position for EVERY viewer (they all see the same shot). So we do not need world->screen projection - we
place 4 nameplates at 4 cvar-tuned screen positions (tuned live like the camera), and `ihuddraw`
survives `drawhud 0` (2.3). Route B (engine RT_SPRITE billboard) would need a cgame rebuild + a
`\rank\N` configstring; not worth it here.

**Files:** `coop_mod/lobby.scr` only. New `lobbyNameplates` level thread (started from `lobbyMapMain`).
Reads `flags["coop_xp_rank"]` (xp.scr, read-only) + `player.scr::playerCleanName` (472).

**Slots (all in 100-107, OUTSIDE the 20-90 lobbyHideHud wipe and clear of XP 62-72 / build 54-59):**
shaders 100-103 (rank emblem per slot 1-4), strings 104-107 (name per slot 1-4).

**Positions:** 8 cvars `coop_lobbyPlate1_X/Y` .. `coop_lobbyPlate4_X/Y` (virtual 640x480), read with
`int()` like `applyLobbyCam` (lobby.scr:85). Tune live once against the camera framing.

**Code shape:**
```
lobbyNameplates:                     // level thread; runs while lobby active
  while( level.coop_lobbyActive == 1 ){
    for( local.v = 1; local.v <= $player.size; local.v++ ){      // v = viewer (per-client draw)
      local.viewer = $player[local.v]
      if( local.viewer == NULL ){ continue }
      for( local.s = 1; local.s <= 4; local.s++ ){               // s = slot
        local.occ = <player whose flags["coop_lobbySlot"] == s, else NULL>
        local.shaderSlot = 99 + local.s          // 100..103
        local.nameSlot   = 103 + local.s         // 104..107
        if( local.occ == NULL || !isAlive local.occ ){
          ihuddraw_alpha local.viewer local.shaderSlot 0
          ihuddraw_alpha local.viewer local.nameSlot   0
          continue
        }
        local.px = int( getcvar ("coop_lobbyPlate"+local.s+"_X") )   // default per-slot below
        local.py = int( getcvar ("coop_lobbyPlate"+local.s+"_Y") )
        local.rn = local.occ.flags["coop_xp_rank"]
        if( local.rn == NIL ){ local.rn = 0 }
        if( local.rn < 10 ){ local.rn = "0" + local.rn }           // xp.scr:530-531 formatting
        local.nm = waitthread coop_mod/player.scr::playerCleanName local.occ.netname
        // rank emblem
        ihuddraw_virtualsize local.viewer local.shaderSlot 1
        ihuddraw_align  local.viewer local.shaderSlot center bottom
        ihuddraw_rect   local.viewer local.shaderSlot local.px local.py 24 24
        ihuddraw_color  local.viewer local.shaderSlot 1 1 1
        ihuddraw_alpha  local.viewer local.shaderSlot 1
        ihuddraw_shader local.viewer local.shaderSlot ("textures/hud/coop_rank_" + local.rn)
        // name
        ihuddraw_virtualsize local.viewer local.nameSlot 1
        ihuddraw_align  local.viewer local.nameSlot center bottom
        ihuddraw_font   local.viewer local.nameSlot "verdana-12"
        ihuddraw_rect   local.viewer local.nameSlot (local.px - 60) (local.py + 24) 144 16
        ihuddraw_color  local.viewer local.nameSlot 1 1 1
        ihuddraw_alpha  local.viewer local.nameSlot 1
        ihuddraw_string local.viewer local.nameSlot local.nm
      }
    }
    wait 0.5
  }
```
Default plate positions: derive live from the framing (the 4 heads sit roughly across the middle of the
shot). Start with `Plate1 300,150 / Plate2 210,150 / Plate3 360,150 / Plate4 300,150` and nudge via
cvar in-game (same live-tune workflow as the camera). Store `flags["coop_lobbySlot"]` is already
assigned in `lobbyOnSpawn` (154-159).

**Sequencing:** after F3/F4 (needs deployed players + the star hidden so the plate is the only chrome)
and after the slot assignment exists (already does).

**Verification:** each posed soldier shows the correct rank emblem + name above the head, aligned by
the shared camera; empty slots draw nothing; on a rank change (won't happen in-lobby, but cross-check)
the emblem tracks `coop_xp_rank`. Wrong emblem => `coop_rank_NN` padding bug; missing => slot->player
map or the alpha wipe band (must be 100-107, not 20-90).

**Risks:** never write `coop_xp_rank` (read-only). Keep plates in 100-107 (the wipe is 20-90). `ihuddraw`
throws a Script exception if the player entity is NULL (scriptthread.cpp:5163) - the `!= NULL` guards
above are required.

**Rollback:** one thread; setting all 100-107 alphas to 0 and not starting `lobbyNameplates` removes it.

**Route B (documented alternative, NOT recommended):** clone `CG_ActorOverheadIcon`
(cg_modelanim.c:227-320, an `RT_SPRITE` billboard tagged to `eyes bone`/`Bip01 Head`) into a
`CG_PlayerRankNameplate` called next to the `ET_PLAYER` hook (cg_modelanim.c:1684-1686); pass rank via a
`\rank\N` key in the `CS_PLAYERS` configstring. Requires a cgame rebuild + configstring plumbing.
Only pursue if the fixed-screen plates feel wrong when the camera is later re-framed per mission.

---

#### T4. Kleveburg MUSIC bed

**Goal:** `sound/music/Kleveburg.mp3` loops throughout the lobby; late joiners get it; it stops on launch.

**Files:** `coop_mod/lobby.scr::lobbyMapMain` (one line).

**Code shape (add in lobbyMapMain, after the camera/props/auto-spawn are threaded, ~lobby.scr:51):**
```
waitthread coop_mod/replace.scr::tmstartloop "sound/music/Kleveburg.mp3"
```
`tmstartloop` (replace.scr:553-582) sends `tmstop`+`tmstartloop` to all clients and stores
`level.coop_musicCommand`, which `player.scr::setupCmds` (1234-1240) replays to any late joiner
automatically. No aliascache (tm* takes a file path). The track loops until stopped.

**Stop on launch:** the clean map transition (T7) tears down the server; to be tidy, call
`waitthread coop_mod/replace.scr::tmstop` in the launch teardown just before `stuffsrv`. (Optionally
`tmfade 1 0 0.7` first, replace.scr:593-607, for a smooth out.)

**Sequencing:** independent (can land any time after F-block). Asset already ships - NOT blocked.

**Verification:** Kleveburg plays on entering the lobby; a second player connecting mid-lobby hears it
from the start of their join; it stops when the mission launches. Silence => wrong path (must be
`sound/music/Kleveburg.mp3`, capital K - confirmed by e1l4.scr:397).

**Risks:** none. Do not combine `tmstop;tmstartloop` into one stufftext (the cgame filter drops it -
replace.scr already sends them separately, replace.scr:561-573).

**Rollback:** remove the one line + the teardown `tmstop`.

---

#### T5. F = READY (cancelable), works with 1+ player

**Goal:** a bindable "Ready" toggles `flags["coop_lobbyReady"]`; a monitor shows "READY n/m"; all
deployed players ready (n>=1 and n==m) -> hand off to T7 countdown.

**Files:** `variables.scr::getNameAppendCommands` (append idx 31), `player.scr::playerNameCommand`
(add case 31), `ui/BIND.SCR` (binditem), `coop_mod/lobby.scr` (`lobbyToggleReady` + `lobbyReadyMonitor`).

**Marker + dispatch:**
```
// variables.scr getNameAppendCommands, after :156 (idx 30)
local.command["31"]=" ,rk"   //[lobby] ready toggle (data: x)
// player.scr::playerNameCommand, after :548 (case 30)
else if(local.arrayIndex==31){ thread coop_mod/lobby.scr::lobbyToggleReady local.player }
// ui/BIND.SCR, after :57
binditem "Coop Lobby: Ready"    "append name ,rkx"
```
The data byte `x` is MANDATORY (empty payloads are ignored, player.scr:343). `,rk` does not collide
with any existing 0-30 marker (checked: `,rv`/`,rd` differ). The name-bus is detected every manage tick
OUTSIDE the `coop_isActive` gate (player.scr:105-117), so Ready works even while frozen.

**Handler + monitor (lobby.scr):**
```
lobbyToggleReady:                    // arg: local.player
  if( local.player == NULL ){ end }
  if( local.player.flags["coop_lobbyReady"] == 1 ){
    local.player.flags["coop_lobbyReady"] = NIL
    local.player iprint "Not ready"
  } else {
    local.player.flags["coop_lobbyReady"] = 1
    local.player iprint "READY"
  }

lobbyReadyMonitor:                   // level thread from lobbyMapMain
  while( level.coop_lobbyActive == 1 ){
    local.deployed = 0; local.ready = 0
    for( local.i = 1; local.i <= $player.size; local.i++ ){
      local.p = $player[local.i]
      if( local.p == NULL || local.p.dmteam == "spectator" ){ continue }
      if( local.p.flags["coop_lobbySlot"] == NIL ){ continue }
      local.deployed++
      if( local.p.flags["coop_lobbyReady"] == 1 ){ local.ready++ }
      // per-client "READY n/m" on slot 15 (below the 20-90 wipe)
      ihuddraw_virtualsize local.p 15 1
      ihuddraw_align local.p 15 center top
      ihuddraw_font  local.p 15 "facfont-20"
      ihuddraw_rect  local.p 15 220 8 200 20
      ihuddraw_color local.p 15 1 1 1
      ihuddraw_alpha local.p 15 1
      ihuddraw_string local.p 15 ("READY " + local.ready + "/" + local.deployed)
    }
    if( local.deployed >= 1 && local.ready == local.deployed && level.coop_lobbyCountdownActive != 1 ){
      thread lobbyCountdownAndLaunch          // T7
    }
    wait 0.5
  }
```

**Definitive decision:** truth is the script flag `coop_lobbyReady`, NOT native `m_bReady`
(defaults true every spawn, player.cpp:2156; respawn-fragile; `DM_Team::NumNotReady` is inert in
GT_TEAM). The native getter is at most an optional cross-check.

**Cancelable:** pressing Ready again flips the flag; `lobbyCountdownAndLaunch` (T7) aborts if `ready`
drops below `deployed` before it fires.

**Sequencing:** after F3 (needs deployed players with slots). Pair with T7.

**Verification:** press the bound key -> "READY 1/1" (solo) -> countdown starts; press again before the
handoff -> "Not ready", counter drops. With 2 clients, both must ready.

**Risks:** name length - appended markers must not push the name past 31 chars (player.scr:369 warns).
Slot 15 is below the wipe band. ASCII only.

**Rollback:** remove idx 31 + case 31 + the binditem + the two lobby labels.

---

#### T6. L / R SKIN cycle (~24 allied models)

**Goal:** Left/Right cycles the player through the vetted allied roster live, re-poses after the swap,
and persists the choice into the launched mission.

**Files:** `variables.scr` (idx 32/33), `player.scr::playerNameCommand` (cases 32/33), `ui/BIND.SCR`
(two binditems), `coop_mod/lobby.scr` (roster array + `lobbySkinNext`/`lobbySkinPrev`).

**Markers + dispatch (TWO handlers - never pass a bare `-1` as a call arg):**
```
// variables.scr getNameAppendCommands
local.command["32"]=" ,sn"   //[lobby] skin next (data: x)
local.command["33"]=" ,sp"   //[lobby] skin prev (data: x)
// player.scr::playerNameCommand
else if(local.arrayIndex==32){ thread coop_mod/lobby.scr::lobbySkinNext local.player }
else if(local.arrayIndex==33){ thread coop_mod/lobby.scr::lobbySkinPrev local.player }
// ui/BIND.SCR
binditem "Coop Lobby: Skin Next"  "append name ,snx"
binditem "Coop Lobby: Skin Prev"  "append name ,spx"
```

**Roster (build with makeArray/endArray, NOT a vector literal; the 24 vetted allied names from
cl_uiplayermodelpicker.cpp - InitModel requires `american`/`allied` prefix, player.cpp:2542):**
```
lobbyBuildSkins:                     // called once from lobbyMapMain; stores level.coop_lobbySkins[]
  level.coop_lobbySkins = makeArray
    american_army
    american_ranger
    allied_101st_captain
    allied_101st_infantry
    allied_101st_scout
    allied_501st_pir_scout
    allied_501st_pir_soldier
    allied_airborne
    allied_manon
    allied_british_6th_airborne_captain
    allied_british_6th_airborne_paratrooper
    allied_pilot
    allied_russian_corporal
    allied_russian_crazy_boris
    allied_russian_recon_scout
    allied_russian_recon_soldier
    allied_sas
    allied_british_tank_corporal
    allied_russian_seaman
    allied_technician
    allied_Wheathers
    allied_US_Tank
    allied_US_Mask
    allied_british_Cmd
    allied_british_Tank
  endArray
```

**Cycle handlers (share a core; +1 / -1 via two entry points):**
```
lobbySkinNext:  local.player thread lobbySkinCycle local.player 1
lobbySkinPrev:  local.player thread lobbySkinCycle local.player 0    // 0 = previous (no bare -1 arg)

lobbySkinCycle:                      // args: local.player local.dir(1=next,0=prev)
  if( local.player == NULL ){ end }
  local.n = level.coop_lobbySkins.size
  local.cur = local.player.flags["coop_lobbySkinIdx"]
  if( local.cur == NIL ){ local.cur = 1 }
  if( local.dir == 1 ){ local.cur++ } else { local.cur-- }
  if( local.cur > local.n ){ local.cur = 1 }
  if( local.cur < 1 ){ local.cur = local.n }
  local.player.flags["coop_lobbySkinIdx"] = local.cur
  local.skin = level.coop_lobbySkins[local.cur]
  local.player model ( "models/player/" + local.skin + ".tik" )       // live swap (replicates)
  local.player stufftext ( "set dm_playermodel " + local.skin + "\n" )// persist into the mission (InitModel reads it)
  local.player iprint ( "Skin: " + local.skin )
  // model swap resets the legs -> re-pose
  local.player thread lobbyPoseAndFreeze
  // per-client skin name on slot 16 (below the wipe band)
  ihuddraw_virtualsize local.player 16 1
  ihuddraw_align local.player 16 center bottom
  ihuddraw_font  local.player 16 "verdana-12"
  ihuddraw_rect  local.player 16 220 452 200 16
  ihuddraw_color local.player 16 1 1 1
  ihuddraw_alpha local.player 16 1
  ihuddraw_string local.player 16 local.skin
```
`self model "models/player/X.tik"` updates the model index live and replicates (Player is an Entity);
`stufftext "set dm_playermodel X"` sends the client userinfo so `InitModel` (player.cpp:2536-2547)
uses it on the mission map. Re-`lobbyPoseAndFreeze` because the model swap resets the legs state.

**Sequencing:** after F1/F2 (re-pose depends on the pose recipe) and after the roster build.

**Verification:** Left/Right swaps the visible soldier through the roster (wrapping both ways); the pose
re-holds after each swap; the chosen skin carries into m1l1 (spawn wearing it). A fallback to
`american_army` in the mission = the name was not `american`/`allied` (roster is clean) or `_fps`.

**Risks:** re-posing on every press could stutter if spammed - the pose has its own `wait` settle, so
rapid presses queue harmlessly. Never include a `_fps` or axis model. `makeArray`/`endArray` (maplist.scr
pattern), not a vector literal (parse-killer). Two handlers avoid the bare-negative-in-parens killer.

**Rollback:** remove idx 32/33 + cases + binditems + the lobby labels; players keep their menu skin.

---

#### T7. COUNTDOWN + LAUNCH

**Goal:** all-ready -> a visible countdown to every client (cancelable if someone un-readies) -> the
CLEAN transition to `level.coop_lobbyNextMap` (default `briefing/briefing1`), persisting XP.

**Files:** `co_lobby1.scr::main` (set the next-map cvar-overridable default), `coop_mod/lobby.scr`
(`lobbyCountdownAndLaunch` + teardown). Mirrors `maptest.scr::coop_maptest_transition` (145-163).

**Next map (co_lobby1.scr::main, after the coop init):**
```
level.coop_lobbyNextMap = getcvar "coop_lobbyNextMap"
if( level.coop_lobbyNextMap == "" ){ level.coop_lobbyNextMap = "briefing/briefing1" }
```
Keep it DISTINCT from `level.coopNextMap` (used by the vote/auto-tour).

**Launch target is RESOLVED (known-good, not a guess):** `briefing/briefing1` under coop gametype 2 is
a SHIPPED path - `ui/coop_start/m1.cfg:8-9` already offers it as a selectable coop start map
(`set ui_dmmap briefing/briefing1` + `coop_mapcmd map briefing/briefing1`), and `briefing1.scr` is
coop-integrated (`:7` coop init, `:23` `waitForPlayer`, `:108-116` coop-specific slide handling, `:130-137
endbriefing` -> `exec global/missioncomplete.scr "m1l1"` when `gametype != 0`). The lobby reaches it with
the PROVEN in-session server transition `stuffsrv ("map " + level.coop_lobbyNextMap)` - byte-for-byte the
mechanism `coop_maptest_transition` (maptest.scr:162) and `restartMap` (main.scr:1569) already use, which
keeps gametype 2 (`map`, unlike `spmap`, does not force SP). briefing1 then self-advances to m1l1 via its
OWN coop `endbriefing` (the existing, off-limits campaign chain). Zero new untested path.
**Last-resort fallback:** `seta coop_lobbyNextMap m1l1` launches the mission directly (the single most
-exercised coop map-load in the mod - every maptest advance uses `stuffsrv "map m1l1"`), skipping the
briefing video.

**Countdown + launch (lobby.scr):**
```
lobbyCountdownAndLaunch:
  if( level.coop_lobbyCountdownActive == 1 ){ end }
  level.coop_lobbyCountdownActive = 1
  local.n = 10
  while( local.n > 0 ){
    // abort if anyone un-readies or drops below 1 deployed
    if( !thread lobbyAllReady ){
      iprintlnbold_noloc "Launch cancelled"
      level.coop_lobbyCountdownActive = NIL
      end
    }
    iprintlnbold_noloc ( "Mission starting in " + local.n + "..." )
    wait 1
    local.n--
  }
  // ---- teardown ----
  level.coop_lobbyActive = 0                 // all lobby loops exit on this
  waitthread coop_mod/replace.scr::tmstop    // stop Kleveburg
  // restore the cvars lobbyMapMain stashed (so the mission is not left in lobby state).
  // CRITICAL: g_forcerespawn - leaving it at 1 into the mission auto-respawns dead/DBNO'd players in 1s
  // and fights the coop respawn/DBNO logic. lobbyMapMain MUST also stash coop_lobbyPrevInactiveKick.
  setcvar "g_forcerespawn"     level.coop_lobbyPrevForceRespawn
  setcvar "g_inactivespectate" level.coop_lobbyPrevInactiveSpec
  setcvar "g_inactivekick"     level.coop_lobbyPrevInactiveKick
  // ---- clean transition (mirror coop_maptest_transition:145-163 / restartMap:1557-1569) ----
  setcvar "g_scriptcheck" "0"
  waitthread coop_mod/xp.scr::xp_flush       // persist XP totals (existing entry point; do NOT modify xp)
  exec coop_mod/replace.scr::stopwatch 0
  setcvar "coop_prevMapList" ( getcvar "sv_maplist" )
  setcvar "sv_maplist" ""
  level.coop_preventGameTypeChanges = game.true
  if( level.coop_changeGameTypeThread ){ level.coop_changeGameTypeThread end }
  game.loadout = false
  stuffsrv ( "map " + level.coop_lobbyNextMap )

lobbyAllReady:                    // helper: end 1 if >=1 deployed and all deployed are ready
  local.deployed = 0; local.ready = 0
  for( local.i = 1; local.i <= $player.size; local.i++ ){
    local.p = $player[local.i]
    if( local.p == NULL || local.p.dmteam == "spectator" || local.p.flags["coop_lobbySlot"] == NIL ){ continue }
    local.deployed++
    if( local.p.flags["coop_lobbyReady"] == 1 ){ local.ready++ }
  }
  if( local.deployed >= 1 && local.ready == local.deployed ){ end 1 }
}end 0
```

**Definitive decision:** the launch uses `stuffsrv ("map " + next)`, NOT `global/missioncomplete.scr`.
Evidence: `missioncomplete` runs the mission XP debrief (`xp_summary`) - incoherent for a lobby - then
`bsptransition`, which is the silent persistant-archive coop-crash path (main.scr:1543-1545,
maptest.scr:132-139). `SV_Map_f` hardcodes `bTransition=false` (no archive, no crash) and `map` (unlike
`spmap`) does not force SP gametype. Call `xp_flush` (xp.scr:951) for persistence - it is the existing
entry point; do not touch xp otherwise.

**Sequencing:** after T5 (triggered by the ready monitor). Works with 1 player (deployed>=1).

**Verification:** ready up -> "Mission starting in 10..1" on every client -> lobby unloads -> the next
map loads and every player re-joins coop normally. Un-ready mid-count -> "Launch cancelled", loops
resume. Confirm XP total survives into the next map (read the save file / rank).

**Risks:** `coop_lobbyCountdownActive` guards against double-trigger from the 0.5s monitor. Restore the
stashed cvars BEFORE `stuffsrv` (esp. `g_forcerespawn`, T10). Launch target is resolved (see the block
above) - `briefing/briefing1` is a shipped coop path; the `m1l1` cvar override is the last-resort fallback.

**Rollback:** the whole feature is `lobbyCountdownAndLaunch`; not threading it leaves the lobby static.

---

#### T8. "Begin Full Campaign" MENU button

**Goal:** a button in the HZM Coop menu that launches the lobby (`co_lobby1`).

**Files:** `ui/coop_start.urc` - add one `Button` resource (mirror the "apply" button at :348-362 /
the `coop_serverNetConfigurationBtn` at :387-401). The target cfg already exists.

**Code shape (add before `end.` at coop_start.urc:402):**
```
resource
Button
{
    title "Begin Full Campaign"
    name "coop_beginCampaignBtn"
    rect 10 122 264 24
    fgcolor 0.00 0.00 0.00 0.00
    bgcolor 0.80 0.90 0.10 0.90
    borderstyle "NONE"
    shader "menu_button_trans"
    hovershader "menu_button_glow"
    clicksound "sound/menu/apply.wav"
    stuffcommand "wait 250;exec coop_mod/cfg/campaign_start.cfg"
    font verdana-12
}
```
`campaign_start.cfg` (exists) does `set ui_dmmap co_lobby1` + `exec coop_mod/start_server.cfg`, and
`start_server.cfg` ends with `ui_startdmmap 2` (reads `ui_dmmap`, launches a listen server at
gametype 2). The `wait 250` matches the existing apply button.

**Sequencing:** independent; do last (it just fronts the whole feature). The lobby must be functional
first (it launches immediately on click).

**Verification:** open the HZM Coop menu -> click "Begin Full Campaign" -> the lobby loads (same as
`exec coop_mod/cfg/campaign_start.cfg` from console). Adjust the `rect` if it overlaps another widget
(coop_start.urc is a busy menu; view the layout and nudge y).

**Risks:** `.urc` parse is fragile - mirror an existing `Button` block exactly, keep the
`resource\n<Type>\n{...}` shape, ASCII only. UI is pk3-side (no rebuild; next launch).

**Rollback:** delete the `Button` block.

---

#### T9. Gate the gameplay name-bus actions off in the lobby  (found in the verification pass)

**Goal:** a lobby player cannot `noclip` out of the freeze or deploy sandbags/ammo/medkit in the staging
area via their existing binds.

**Root cause:** `playerNameCommand` (player.scr:501-548) dispatches EVERY bound action regardless of map.
In the lobby the harmful ones are: 15 `noclip` (sets MOVETYPE_NOCLIP -> EvaluateState early-returns,
player.cpp:5567 -> pose lost + flies out of freeze), 8 `medkit`, 9 `cover`, 16 `ammobox`, 14 `dbno-test`,
and the DEBUG give-weapon set 17-22. The Ready/Skin markers (31/32/33) and the emotes (23-25, harmlessly
overridden by the idle rotation) stay live.

**Fix (lobby-gated, additive - guarded so normal maps are byte-for-byte unchanged):** wrap the harmful
cases in `playerNameCommand`:
```
// player.scr::playerNameCommand - wrap the movement/deploy/debug cases
else if(local.arrayIndex==8){  if( !level.coop_lobbyMap && level.coop_noMedkit != 1 ){ local.player thread coop_mod/medkit.scr::medkit_use local.player } }
else if(local.arrayIndex==9){  if( !level.coop_lobbyMap ){ local.player thread coop_mod/cover.scr::cover_place local.player } }
else if(local.arrayIndex==14){ if( !level.coop_lobbyMap ){ thread coop_mod/dbno.scr::dbno_enter local.player "chest" } }
else if(local.arrayIndex==15){ if( !level.coop_lobbyMap ){ local.player thread coop_mod/developer.scr::noclip_toggle } }
else if(local.arrayIndex==16){ if( !level.coop_lobbyMap ){ local.player thread coop_mod/ammobox.scr::ammobox_place local.player } }
// (17-22 debug give-weapons: same !level.coop_lobbyMap guard)
```
Leave 23-25 (emotes) and 31-33 (ready/skin) ungated.

**Sequencing:** with T5/T6 (same file). **Verification:** in the lobby, the noclip/medkit/cover/ammobox
binds do nothing; on a normal mission they work exactly as before. **Risks:** none - a `!level.coop_lobbyMap`
guard is inert off lobby maps. **Rollback:** remove the guards.

---

#### T10. Multiplayer + teardown hardening  (found in the verification pass)

**Goal:** correct 2-4 player behavior, a clean cvar restore on launch, and no leftover lobby state.

**Fixes (all in `coop_mod/lobby.scr`, small):**
1. **Stash `g_inactivekick` in `lobbyMapMain`** (next to the existing stashes at lobby.scr:21-27):
   `level.coop_lobbyPrevInactiveKick = getcvar "g_inactivekick"`. T7 restores it. Without this the mission
   inherits the lobby's `g_inactivekick 0`.
2. **`g_forcerespawn` restore is correctness-critical (already in T7)** - re-stated here: leaving it at 1
   auto-respawns dead/DBNO'd players in the mission.
3. **Slot cap for >4 players:** `lobbyOnSpawn` round-robins slots 1..4 (lobby.scr:154-159); a 5th+ player
   overlaps slot 1. Either document "lobby is 4 slots" or, cleaner, when all 4 slots are taken, seat extra
   players at a small per-player offset from slot 4 (or hide+free-spectate them). Recommend: for the MVP,
   set `sv_maxclients 4` expectation in `campaign_start.cfg`/docs; the overlap is only cosmetic (frozen,
   no telefrag since they are notsolid-adjacent) but two heads at one slot looks wrong.
4. **Optional lobby-wide `nodamage`:** re-arm `nodamage` on each lobby spawn (lobbyOnSpawn) so the 8s
   spawn-protection window never lapses into a damageable frozen player (defense-in-depth; co_lobby1 has no
   AI so damage is not expected).
5. **Optional: silence the officer policy debug prints in the lobby.** officer.scr:155/157 print
   "OFFICER: spawn policy = none" / "policy NONE ..." via ungated `iprintlnbold`. Wrap both in
   `if( !level.coop_lobbyMap )` (mirroring objectives.scr:155/161) so the lobby is not spammed. Lobby-gated,
   cosmetic-only.

**Sequencing:** alongside F-block / T7. **Verification:** with 2 clients, both deploy to distinct slots,
both posed/frozen, both see the shared shot, both nameplates show; ready flow needs both; on launch the
mission runs with the pre-lobby `g_forcerespawn`/`g_inactivespectate`/`g_inactivekick` (check a DBNO death
in the mission still holds the player instead of insta-respawning). **Risks:** none new. **Rollback:**
each item is independent and additive.

---

## 4. RECONCILED DECISIONS

| # | Prior conflict | DECISION | Code evidence |
|---|---|---|---|
| 1 | `freezecontrols` vs `freezeplayer` for the lock | **`freezecontrols`** (per-player `m_bFrozen`) + per-frame re-assert (`lobbyLockWatch`). `freezeplayer` is global and pinned the spawn crouch (bug-370). | Both set PMF_FROZEN: player.cpp:4049. m_bFrozen resets on respawn: player.cpp:2240. Neither blocks EvaluateState: player.cpp:5571 (only FL_IMMOBILE does). |
| 2 | The launch path | **Clean `stuffsrv ("map " + next)`** (mirror coop_maptest_transition), NOT `global/missioncomplete.scr`. | missioncomplete runs xp_summary + bsptransition (archive crash): main.scr:1543-1545; maptest.scr:126-163; SV_Map_f bTransition=false. |
| 3 | ihuddraw slots for lobby UI | **Nameplates 100-103/104-107, ready 15, skin 16.** All clear of the 20-90 `lobbyHideHud` wipe and of XP 62-72 / dbno 27-39 / cover 40-47 / build 54-59. | lobby.scr:261 (wipe band); cerebrum slot map; nameplates survive drawhud 0 (cg_drawtools.cpp:594). |
| 4 | native ready vs script flag | **Script flag `flags["coop_lobbyReady"]`.** Native getter = optional cross-check only. | m_bReady defaults true every spawn: player.cpp:2156; respawn-fragile; NumNotReady inert in GT_TEAM. |
| 5 | pose: torso STAND vs dedicated EMOTE_ATEASE_TORSO | **STAND (deployed) primary**; dedicated `EMOTE_ATEASE_TORSO` (mirror COVER_TORSO) is the fallback if STAND flickers. Both are `action none`, so both let the legs clip own the body; the dedicated one has fewer edges. | player_Torso.st:30-44 (STAND action none), :206-238 (COVER_TORSO shape); player.cpp:5661 (none -> StopPartAnimating). Frozen players fire none of STAND's extra edges. |
| 6 | nameplate Route A (ihuddraw) vs B (RT_SPRITE) | **Route A** - fixed screen coords (shared static camera), no rebuild, survives `drawhud 0`. | CG_HudDrawElements ignores PMF_NO_HUD: cg_drawtools.cpp:587-596. Route B template: cg_modelanim.c:227/1684 (needs rebuild + configstring). |
| 7 | how to hide the vanilla star | **`drawhud 0`** (PMF_NO_HUD) re-asserted per spawn; NOT `ui_hudAlpha` from script (cgame republishes it). | Star = hud_health: cl_ui.cpp:57,1871,2040-2064. drawhud sets PMF_NO_HUD: scriptthread.cpp:4630. Respawn clears it: player.cpp:2201. ui_hudAlpha republished: cg_drawtools.cpp:2016. |
| 8 | deploy mechanism / the 5s limbo | **`lobbyAutoSpawnLoop` -> `skipTeamAndWeaponSelect` -> `join_team`, polled per-frame** (was 0.5s). `g_forcerespawn` is NOT it (dead-only). BACKUP SPAWN spam is a harmless print. | Deploy chain: lobby.scr:129-142 -> main.scr:325-363 -> playerSpawnEvent main.scr:253 -> manageAliveSpawning player.scr:918. Placement commented out: player.scr:66-67. |

---

## 5. MORNING FIRST-STEP

**Test the already-deployed pose (F1) before writing any new code.**

1. Launch OpenMOHAA, open the console (`~`), run: `exec coop_mod/cfg/campaign_start.cfg`
2. When the lobby loads and your soldier deploys, look at the third-person body.

**Read the result:**
- **Correct:** standing, hands on hips / at-ease, rifle slung on the back, holding still. F1 is good -
  proceed to F3 (instant deploy), then F4 (star), then features.
- **Crouched, holding rifle:** the freeze landed before the unfrozen stand, or `freezeplayer` crept
  back. Confirm `lobbyPoseAndFreeze` order is holster -> forcetorsostate STAND -> forcelegsstate
  EMOTE_ATEASE (unfrozen) -> freezecontrols, and that `freezeplayer` is nowhere in lobby.scr.
- **Standing but rifle held out front:** the torso is not `action none`. Switch `forcetorsostate
  "STAND"` to the dedicated `EMOTE_ATEASE_TORSO` fallback (F1).
- **Invisible rifle / arms-down idle:** a `-HAS_WEAPON` bounce - a `takeall` is present somewhere;
  remove it (holster only).
- **Wrong spot / free camera / normal HUD:** the coop spawn did not complete (F3 territory) or the
  statefile reset - check `qconsole.log` for `LOBBYDBG` lines and any `ForceLegsState ... not found`.

Then read `%APPDATA%\openmohaa\maintt\qconsole.log` for the `LOBBYDBG` deploy timing (F3 verification)
and note whether the bottom-left star is present (F4).

---

## 6. OPEN QUESTIONS (need an in-game test - kept minimal)

> The round-1 "briefing launch" question is RESOLVED - see 0b + T7. `briefing/briefing1` under coop gt2
> is a shipped menu path (ui/coop_start/m1.cfg:8-9); the lobby reaches it with the proven `stuffsrv "map"`
> transition; briefing1 self-advances to m1l1. Not an open question anymore.

1. **After the per-frame deploy poll (F3), is deploy effectively instant (<1s)?** *Test:* read the
   `LOBBYDBG` gap between `reached NO-SPEC gate` and `REACHED active=1` in qconsole.log. If still slow,
   add the `level.coop_lobbyMap`-gated force-join in `manageSpectator` (F3, second code block).
   (Measurable, not unknowable - kept only to confirm the sub-second target.)

2. **Does the STAND-torso pose stay stable across the full T2 idle rotation** (holstered, many different
   emote clips over minutes)? *Test:* watch one soldier for 60-90s cycling emotes. If the torso ever
   snaps to a weapon-carry, switch to the dedicated `EMOTE_ATEASE_TORSO` (F1 fallback).

3. **Does the smoking PROP chain attach the cigarette to the player** when the frame-command block is
   copied onto our alias? *Test:* trigger the smoke emote, look for `models/items/cigarette.tik` in the
   left hand; confirm it is removed on emote exit. If not, verify the exact `server { first
   removeattachedmodel ...; 16 attachmodel ... }` block against the source `new_generic_human.tik`
   smoking alias. (Ship the SAFE non-prop idles first; smoking is a follow-on.)

---

## 7. New surface summary

**Cvars (seta in autoexec.cfg; read with getcvar):**
`coop_lobbyNextMap` (default `briefing/briefing1`), `coop_lobbyPlate1_X/Y` .. `coop_lobbyPlate4_X/Y`
(nameplate screen positions). Runtime-stashed for restore on launch: `coop_lobbyPrevForceRespawn`,
`coop_lobbyPrevInactiveSpec`, `coop_lobbyPrevInactiveKick` (T10). Existing lobby cvars unchanged
(`coop_lobbyCam*`, `coop_lobbyLook*`, `coop_lobbyCamFov`, `coop_lobbyFeetDrop`).

**Name-append markers (variables.scr getNameAppendCommands; next free was 31):**
31 `" ,rk"` ready, 32 `" ,sn"` skin-next, 33 `" ,sp"` skin-prev. Dispatch cases 31/32/33 in
player.scr::playerNameCommand. BIND.SCR: "Coop Lobby: Ready" `,rkx`, "Coop Lobby: Skin Next" `,snx`,
"Coop Lobby: Skin Prev" `,spx`.

**ihuddraw slots (all outside the 20-90 lobbyHideHud wipe):**
15 ready counter, 16 skin name, 100-103 nameplate rank emblems, 104-107 nameplate names.

**Files touched:**
- `coop_mod/lobby.scr` - `lobbyAutoSpawnLoop` (F3 waitframe), `lobbyOnSpawn` (F4 drawhud re-assert),
  `lobbyMapMain` (T4 music, T3 `lobbyNameplates`, T5 `lobbyReadyMonitor`, T6 `lobbyBuildSkins`),
  new labels `lobbyIdleRotate` (T2), `lobbyNameplates` (T3), `lobbyToggleReady`/`lobbyReadyMonitor` (T5),
  `lobbySkinNext`/`lobbySkinPrev`/`lobbySkinCycle` (T6), `lobbyCountdownAndLaunch`/`lobbyAllReady` (T7).
- `models/player/base/anims_shared.txt` - append weight-free idle aliases (T2). ADDITIVE.
- `coop_mod/player_Legs.st` - append `EMOTE_IDLE_*` states (T2), optional `EMOTE_ATEASE_TORSO` in
  `coop_mod/player_Torso.st` (F1 fallback). ADDITIVE. `.st` boot-test on a real client.
- `coop_mod/variables.scr` - `getNameAppendCommands` idx 31/32/33 (T5/T6). ADDITIVE.
- `coop_mod/player.scr` - `playerNameCommand` cases 31/32/33 (T5/T6) + lobby-gate the gameplay bus actions
  8/9/14/15/16/17-22 (T9); optional lobby-gated force-join in `manageSpectator` (F3 fallback). ADDITIVE +
  lobby-gated branches.
- `ui/BIND.SCR` - three binditems (T5/T6). ADDITIVE.
- `co_lobby1.scr::main` - set `level.coop_lobbyNextMap` (T7). ONE line.
- `coop_mod/lobby.scr::lobbyMapMain` - stash `coop_lobbyPrevInactiveKick`; slot-cap / lobby `nodamage`
  hardening (T10). ADDITIVE.
- `ui/coop_start.urc` - one `Button` (T8). ADDITIVE.

**Engine:** none required for the recommended path (Route A nameplate, drawhud-based star hide,
script-flag ready, live `model` swap, `freezecontrols` lock all use existing builtins). Route B
nameplate is the only engine-rebuild option and is not recommended.

**Do-not-touch reaffirmed:** camera, xp.scr, the coop framework spawn design, the campaign chain, the
existing 3 emote statemaps, build/deploy.

---

## 8. SOURCE-OF-TRUTH CROSS-CHECK (against `memory/master_source_of_truth.md`, 2026-07-08)

Every task cross-checked against the project source of truth (build/deploy, working-style rules, the
parse-killer/catastrophic-break checklist, engine rules, do-not-touch). PASS = compliant with the
citation; FLAG = a caution the implementer must honor.

### A. Parse-killers / catastrophic-break checklist (per planned edit)

- **Duplicate label (the #1 silent whole-file killer) - GREP-VERIFIED PASS.** Grepped every NEW label
  this plan introduces against its target file; ALL returned zero matches (no collision):
  - `lobby.scr` new functions `lobbyIdleRotate`, `lobbyNameplates`, `lobbyToggleReady`,
    `lobbyReadyMonitor`, `lobbyBuildSkins`, `lobbySkinNext`, `lobbySkinPrev`, `lobbySkinCycle`,
    `lobbyCountdownAndLaunch`, `lobbyAllReady` -> none exist (grep 2026-07-08).
  - `player_Legs.st` new states `EMOTE_IDLE_*` / `EMOTE_SMOKE_*` -> none exist.
  - `player_Torso.st` new state `EMOTE_ATEASE_TORSO` -> does not exist.
  - `variables.scr` markers `,rk` / `,sn` / `,sp` -> none exist (and none is a substring of an existing
    marker, so `containsText` cannot false-match).
  - player.scr / variables.scr get only NEW CASES/KEYS inside EXISTING functions (playerNameCommand,
    getNameAppendCommands) - no new top-level labels there. **Re-run these greps at implementation time**
    (labels can be added between now and then).
- **UTF-8 BOM - PASS with instruction.** Make ALL implementation edits with the **Edit tool** (never adds
  a BOM), never PowerShell `Set-Content -Encoding utf8`. Run the 3-byte BOM scan (`efbbbf`) on every
  touched .scr/.st/.txt/.urc before `build.ps1`.
- **Non-ASCII / em-dash - PASS.** All new code and all display strings are ASCII: skin display uses the
  raw model filenames (`american_army`, `allied_sas`, ... - ASCII); countdown = `"Mission starting in " +
  n + "..."`; ready = `"READY n/m"`. No em-dash, no accented chars. (Verify at edit time.)
- **Bare negative after `(` - PASS.** Skin cycle uses TWO handlers (`lobbySkinNext` -> `lobbySkinCycle .. 1`,
  `lobbySkinPrev` -> `lobbySkinCycle .. 0`); the direction arg is a plain `0`/`1`, never `(-1)`. Decrement is
  `local.cur--` (statement, not a parenthesised negative). Nameplate math is `(local.px - 60)` (starts with
  a var, not `-`) - safe.
- **`wait`/`waitframe` in or before `main.scr::main` - PASS.** No task edits `main.scr::main`. The only
  `co_lobby1.scr::main` addition (`level.coop_lobbyNextMap = ...`, T7) is a var assignment placed AFTER the
  existing `waitthread coop_mod/main.scr::main` (co_lobby1.scr:16), next to the existing `coop_weatherTheme`
  line - no wait added anywhere in the single-frame init path.
- **MAX_TIKI_ANIMS overflow - FLAG (T2).** T2 appends ~10-15 idle aliases (+ the smoking chain) to
  `models/player/base/anims_shared.txt`, which every player TIK `$include`s. The engine was hardened for
  this ([[engine-tiki-anim-overrun-fix]], arrays sized by MAX_TIKI_LOAD_ANIMS), but a large add can still
  approach the cap and DROP anims from the end silently. Mitigation: add the aliases incrementally and
  BOOT-TEST on a real client (watch qconsole for missing-anim / overrun warnings); ship the safe idle set
  first, the smoking chain second.
- **Wrong map-transition on a live coop server - PASS.** T7 launch uses `stuffsrv ("map " + next)`
  (SV_Map_f, no persistant archive) - the exact `coop_maptest_transition` (maptest.scr:162) mechanism.
  Never `bsptransition`/`loadMap`/`leveltransition`. (briefing1's OWN advance to m1l1 uses the existing
  campaign chain, which is off-limits and unchanged.)
- **`;`-joined server->client stufftext - PASS.** Music uses `replace.scr::tmstartloop`, which sends
  `tmstop` and `tmstartloop <file>` as SEPARATE stufftexts (replace.scr:572-573) - the safe wrapper.
  Late-joiner replay (setupCmds:1234-1240) also sends them separately. The skin-persist stufftext is a
  single `set dm_playermodel <name>\n` (no `;`). No `;`-joined cgame-filtered command anywhere.
- **Label/brace mismatch - PASS with instruction.** New `.st` states mirror the byte shape of existing
  balanced blocks (EMOTE_ATEASE for legs, COVER_TORSO for the torso fallback). REQUIRED: after editing,
  run a running-depth brace scan (depth never negative; 0 at every `state` line) AND boot-test on a real
  client - a bad `.st` ERR_DROPs the server and the error surfaces ONLY on a client, not a dedicated boot.
- **`spawn ClassName targetname "x"` - N/A / PASS.** The lobby prop spawns (existing, lobby.scr:275-414)
  use inline keyvalues, which the source of truth explicitly confirms are FINE (not a parse killer). No
  new spawns added by these tasks.

### B. Working-style rules - every mechanism copies a proven in-mod recipe (cited)

| Task | Mechanism | Proven call-site it mirrors |
|---|---|---|
| F1 pose | holster + forcetorsostate/forcelegsstate | `replace.scr::holster` (e1l4 intro, cardgame); force*state used by dbno.scr:402, medkit.scr:316, playerGlue main.scr:1196 |
| F2 lock | `freezecontrols` + per-frame re-assert | map intros t1l2/t2l2 (freezecontrols); the lobby's own `lobbyLockWatch` |
| F4 star | `drawhud 0` | co_lobby1.scr:26, briefing1.scr:13, lobbyHideHud |
| T2 idle | new EMOTE_* states + weight-free aliases | EMOTE_ATEASE (player_Legs.st:1589) + coop_emote_* (anims_shared.txt:452-454); DBNO per-frame force loop |
| T3 nameplate | `ihuddraw_*` per-viewer | canonical block dbno.scr:389-394; rank formatting xp.scr:526-531/574 (READ-only) |
| T4 music | `tmstartloop` | e1l4.scr:397, e2l3.scr:254-288, e1l2.scr:108 |
| T5/T6 ready/skin | name-append bus | emote entries 23-25 (variables.scr:149-151 + playerNameCommand:541-543 + BIND.SCR:51-53) are the exact template |
| T6 skin swap | `self model` + `dm_playermodel` | **weakest precedent** - see FLAG below |
| T7 launch | `stuffsrv "map"` transition | maptest.scr:162, main.scr:1569 |
| T8 button | `.urc` Button + `stuffcommand exec` | coop_start.urc apply button :360, coop_serverNetConfigurationBtn :399 |

- **FLAG (T6 skin swap):** the LIVE `self model "models/player/X.tik"` mid-life swap is the one mechanism
  with NO exact in-mod script precedent (the mod sets the player model only at spawn via InitModel today).
  It is grounded in the ENGINE (the `model` event replicates - entity.cpp:1569/2066; `dm_playermodel` is
  the userinfo key - g_client.cpp:781-788; InitModel applies it on the next spawn - player.cpp:2536-2547),
  not invented. Per rule 1, treat it as the item to prove LIVE first: swap one skin in the lobby, confirm
  the model changes + the pose re-holds + the choice carries into the mission. Fallback if the live swap
  misbehaves: defer the swap to spawn-time only (set `dm_playermodel` and force a single respawn).
- **Live-tunability (rule 3) - PASS with a refinement.** Camera (done, cvars), nameplate positions
  (`coop_lobbyPlateN_X/Y`), feet drop (existing cvar) are all live-tunable. **Refinement for T2:** expose
  the idle-rotation feel as live cvars too (per-bucket weight, dwell min/max, stagger) so it is tuned by
  screenshot+cvar iteration, NOT blind-shipped - directly honoring "never ship pose/statemap edits blind."
  The F1 pose is validated live FIRST (Section 5 morning step) before anything builds on it.

### C. Do-not-touch list - PASS

- **Camera:** untouched (no task edits spawnLobbyCamera/applyLobbyCam/lobbyCamTune).
- **XP:** READ-only (`flags["coop_xp_rank"]` for the nameplate) + CALL the existing `xp_flush` (xp.scr:951).
  Never modifies xp.scr.
- **Coop framework:** the only framework-file edits are `player.scr` T9 (wrap the gameplay name-bus cases
  in `!level.coop_lobbyMap`) and the OPTIONAL F3 fallback branch in `manageSpectator` - both **lobby-gated
  and additive**, byte-for-byte inert on every non-lobby map, matching the already-shipped gated-hook
  pattern (officer.scr:34, objectives.scr:155). They do not restructure the spawn lifecycle. Diff these two
  files carefully after editing (the engine-repo diff discipline, applied to scripts too).
- **Campaign chain:** T7 only LOADS `briefing/briefing1`; briefing1's own `endbriefing` runs the existing
  (unchanged) `missioncomplete -> m1l1` chain.

### D. Engine / deploy - PASS (100% script-only, ZERO rebuilds in the recommended path)

- **Every task is script/asset-only, deployed by `build.ps1` (pk3):** F1-F4, T2-T10 use only EXISTING
  engine builtins (`freezecontrols`, `forcelegsstate`/`forcetorsostate`, `drawhud`, `ihuddraw_*`,
  `cuecamera`, `model`, `stuffsrv`, `tmstartloop`, the name-bus). `.st` / `anims_shared.txt` / `.urc` are
  all pk3-side assets. **No `cgame.dll` / `game.dll` / exe rebuild is required.**
- **The ONLY engine option is Route B nameplate** (RT_SPRITE billboard, cg_modelanim.c) - explicitly NOT
  recommended; Route A (ihuddraw) achieves it script-side. If Route B is ever chosen it needs a `cgame.dll`
  rebuild deployed to the GOG **root** (not maintt) + a `\rank\N` configstring; flag it as the sole engine
  touch and diff cg_modelanim.c before/after (detached-HEAD discipline).
- **Deploy hygiene:** close `openmohaa.exe` before `build.ps1` (force-kill permitted); test via
  `ui_startdmmap 2` (the lobby launch already respects this through campaign_start.cfg -> start_server.cfg).

**Net:** the plan is clean against the source of truth. Hard requirements: BOM-safe Edit-tool edits, the
`.st` boot-test, and re-run the duplicate-label greps at implementation. Two live-validate flags (T2 anim
count / rotation feel; T6 live skin swap). Zero engine rebuilds.
