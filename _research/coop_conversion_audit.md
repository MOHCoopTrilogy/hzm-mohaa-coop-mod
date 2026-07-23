# Coop-Conversion Audit — 10 Unconverted HZM Maps

Final static audit of the ten maps the original HZM mod left (or only half-) coop-converted.
Every map passed parse/QA (depthscan2 balanced, no BOM, no non-ASCII, no bare `(-N` in parens,
no duplicate labels, no reachable `waittill pain`) unless noted. Findings below are runtime/coop-logic
defects verified against OpenMOHAA engine source and the BSP entity dumps.

Severity: **P0** = mission uncompletable / server soft-lock in 2+ player · **P1** = major gate or
finale dead / stranding · **P2** = system dead but mission still winnable · **P3** = cosmetic /
retail-inherited noise / dev prints.

---

## 1. Executive Summary

| Map | Grade | P0 | P1 | Addon status | Headline |
|---|---|---|---|---|---|
| **m3l1a** | B+ | 0 | 0 | N/A (0 addon ents, AA-native) | cover_zone `$player istouching` throws with 2+ players (P2); dev prints leak |
| **m6l3a** | B− | 0 | 1 | N/A (0 addon ents) | spawn-warper re-enable has inverted polarity → respawners permanently stranded on platform |
| **t1l2** | B | 0 | 0 | unhandled (2 addon, 0 handled) — Opel truck = inert Object (dismissed cosmetic) | no `t1l2` spawnlocations label (P2); final objective bypasses coop panel (P3) |
| **t1l3** | **F** | 2 | 4 | handled (10/11 via TIKI fallback) | colonel/tank/flak/bridge gags never coop-converted — mission dead at obj1 in 2+ player |
| **t2l2** | A− | 0 | 0 | implemented (92 addon / 19 classes, all functional) | clean; only retail-inherited dead cleanup threads (P2/P3) |
| **t2l3** | **F** | 3 | 0 | **UNHANDLED (100 addon, 0 impl)** — the mission cast never spawns | no e3l3-style stand-in spawning; medic/captain gags never converted |
| **t2l4** | **F** | 2 | 0 | handled (68 addon via TIKI fallback) | vanilla start.scr freezes all players; captain.scr locks the church |
| **t3l2** | B | 0 | 0 | implemented (47 addon via TIKI fallback) | coop tank auto-drive fallback doubly broken → central T-34 bricked if unboarded (P2) |
| **e3l3** | C+ | 0 | 1 | partial (K5/AB41 handled; k5truckmove + aaguntruck respawn broken) | `$steal_ab_trigger` one-shot consumed unheard → obj5/6 softlock |
| **e3l4** | B | 0 | 1 | implemented (179 addon via TIKI fallback) | credits_done force-disconnects the whole session at the BT finale |

**Totals: 7 confirmed P0, 7 confirmed P1.** Three maps (t1l3, t2l3, t2l4) are hard-uncompletable in
real co-op and need the most work; t2l3 additionally needs a full e3l3-style addon respawn pass.

---

## 2. FIX QUEUE — confirmed P0 then P1, ready work list

### P0 (7) — mission uncompletable / soft-lock in 2+ player

**FQ-1 · t2l4 · `gags/t2l4_start.scr:46`** *(vanilla mainta pak1 — NOT overridden; must ship an override)*
- Issue: `DoStartup` runs SP intro `freezeplayer` (L44) + `LockView` + `$player physics_off` (L46). With ≥2 players L46 throws const-array cast, killing DoStartup **before** `$cappy thread DoOpeningDialog` (L47); LockView throws before `releaseplayer`.
- Impact: `level.playerfrozen` stays true forever → **all players frozen at spawn**; no objectives, no captain charge, no panzer/mg42/sniper init. Map completely inert regardless of any other fix.
- Fix: ship `gags/t2l4_start.scr` in the mod pk3; in MP skip freeze/LockView/physics juggling (gate `level.gametype==0`), `thread DoOpeningDialog` unconditionally, route the ReleasePlayer loadout through `replace.scr::item/ammo/useWeaponClass`.

**FQ-2 · t2l4 · `gags/t2l4_captain.scr:227`** *(mod-owned; only 3 refs were shimmed)*
- Issue: 20 unconverted raw `$player` refs. `self lookat/turnto $player` + `$player.origin` throw const-array cast. Deaths at DoPreChurch:227-228 (before `unlockchurch`), DoChurchToHotel:511, DoHotel:625 (before `unlockhotel`), DoEnding:729 (before `stuka_start`), CappyDoFinalDialog:781 (before coop missioncomplete t3l1), CappySayComeHere/RunTo/DoPlayerDeath.
- Impact: mission hard-stops at the **church (locked door)**; every later gate + the final map transition also dead.
- Fix: apply the `local.p = exec coop_mod/replace.scr::player_closestTo self` shim (already used in maps/t2l4.scr) to every turnto/lookat/aimat/runto; distance checks via player_closestTo + vector_length; DoPlayerDeath iterate `$player[1..size]` or drop.

**FQ-3 · t2l3 · `maps/t2l3.scr:16`** *(addon cast never spawns)*
- Issue: the scripted cast is addon AI that the engine can't spawn — `$medic`, `$webber`, `$privateparts`, `$soldier01-04`, 6 `$friendly` defenders. `t2l3_medic_init` dies at `$medic.maxhealth` (L36); the soldiers-talking gag dies on `$soldier01 exec…`, so its L549 `thread …artillery_barrage_1` (the **only** caller) never fires → physics_on, medic init, tree gag, waves all dead.
- Impact: no medic → objectives 2-6 unreachable; intro dead; players never released.
- Fix: spawn native actors for the 12 addon AI at their BSP origins with `$`-keys applied **before** `global/friendly.scr::friendlygen` (L20) and before the gag inits (medic `allied_usa_1st-Ranger_medic_snow.tik` @ (-3536 -5856 32); webber `private_snow3` @ (-2428 -5720 8) health 1 StG44; privateparts `private_snow2` @ (804 -788 -40); soldier01-04 ~(-700..-544, -2000, 48); 6 friendlies per dump groups/sets/guns).

**FQ-4 · t2l3 · `gags/t2l3_medic.scr:475`** *(mod-owned override; gag not converted)*
- Issue: `medic_start` computes `vector_length($medic.origin - $player.origin)`; single-listener use throws with ≥2 players (worldspawn.cpp:1054). Same at L504 (`$medic runto $player`) and L448 (`gettotheplayer`→L647).
- Impact: "Locate The Medic" can never complete → objective 3, webber heal, `triggercaptainike` (L349), waves never start; meanwhile `t2l3_iscaptainalive` counts down and missionfails on a loop.
- Fix: `local.np = exec coop_mod/replace.scr::player_closestTo $medic` at L475/L504, pass into gettotheplayer at L448; fix L366 `$player.origin`. (`$player playsound` at L444/814/825 is SAFE — command-methods iterate the array.)

**FQ-5 · t2l3 · `gags/t2l3_captainruntoandtalk.scr:52`** *(vanilla mainta pak1 — NOT overridden)*
- Issue: `t2l3_executecaptainwave2` does `level.globalcaptainike runto $player`; `gettotheplayer` L60/L67 read `$player.origin`/`runto $player`. Throws with ≥2 players **before** `thread …kommanderstartattack2` (L72/L94).
- Impact: **wave 2 never activates** — `$enemy5` stay ai_off, `$panzer` never drives, kommanderthink can only reach wave 3 on `$panzer` death → permanent softlock at wave 1→2.
- Fix: ship a mod override; swap L52/60/67 to `exec coop_mod/replace.scr::player_closestTo level.globalcaptainike` with NULL fallback to `$anchor3` (retail else-branch already provides the anchor path).

**FQ-6 · t1l3 · `gags/t1l3_colonel.scr:196`** *(coop OVERRIDE still uses bare `$player`)*
- Issue: `level.colonel aimat $player` at L106/121/150/196/219/412/452/473, `$balconyguy turnto $player` L152, `$player.origin` in colonelhider L626, `CanSeeTarget $player`/`$player damage` in KillPlayerOnTouch L314/319. With ≥2 players every Player has targetname `player`; `World::GetScriptTarget` throws (worldspawn.cpp:1054), killing the thread.
- Impact: **strands at objective 1** — trigger2 dies at L196 before the motorcycle ride/`pretrigger3`; trigger4 dies at L452 before `colonelatbalcony=1`; trigger5 (the only window the 4.16M-HP nodamage colonel is killable) is gated on `colonelatbalcony==1` and never fires → colonel unkillable → obj1 never completes → nothing downstream runs. Works solo, so host-only testing misses it.
- Fix: replace each bare `$player` with `local.p = exec coop_mod/replace.scr::player_closestTo self` (or `$player[1]` NULL-guarded) for aimat/turnto/distance; loop `$player[i]` for KillPlayerOnTouch damage.

**FQ-7 · t1l3 · `gags/t1l3_tank.scr:141`** *(vanilla mainta pak1 — NOT overridden; add to coop pk3)*
- Issue: `captainchase` L141 `if ( isAlive $player )` throws with ≥2 players, killing the thread before `level.captrunning=1` (L149) / `level.captreturnready=1` (L158). `captainstart` L255 `vector_length(self.origin - $player.origin)` same defect.
- Impact: `tankpath1` waits `while level.captreturnready == 0` (L494) **forever** → returnpath never set, tankpath3 never runs, the Tiger's `takedamage` (L520) never executes → tank stays permanently nodamage → **objective 2 impossible**. Map obj1 also hangs on `while level.captrunning == 0`.
- Fix: add `gags/t1l3_tank.scr` to the coop pk3 (repo already overrides 3 sibling t1l3 gags); replace L141 with a `$player.size>0` check (or drop), L255 with nearest-player via `player_closestTo`.

### P1 (7) — major gate / finale / stranding

**FQ-8 · m6l3a · `maps/m6l3a.scr:3130`** — *one-token fix*
- Issue: `coop_updateSpawningInTrain` ends with `level.coop_disableSpawnWarper = game.true` under the comment "//enable spawn warper now again". `game.true` = **disabled** (player.scr:82/1184 gate on `!coop_disableSpawnWarper`; the re-enable convention is `game.false`). Warper was turned off at L69 for the train ride and never actually turned back on.
- Impact: respawn-at-death-position dead map-wide — every respawn/late-join lands at the frozen platform coords. From scene4 the map seals that area (train teleports away L1664, hangar doors slam shut L1672-1680, entry gates already closed), so anyone dying in the jailbreak/catwalk/bomb/valve/elevator half respawns **permanently stranded**; a team wipe there makes the mission unwinnable.
- Fix: change L3130 to `level.coop_disableSpawnWarper = game.false`. Optionally re-snapshot `coop_spawnNorigin` after the scene4 train teleport so fallbacks follow the team indoors.

**FQ-9 · t1l3 · `gags/t1l3_colonel.scr:692`**
- Issue: `captcapcolonel` computes `vector_length($player.origin - $officerbalconytether.origin)` (also L697/698/717/718/721); throws with ≥2 players before `level.captain thread gags/t1l3_tank.scr::captainstart` (L751) and `level.starttank = 1` (L752).
- Impact: even with FQ-6 fixed, the captain never runs his post-kill sequence and the **tank phase never starts** → objective 2 unreachable → strands after balcony kill.
- Fix: nearest-player via `player_closestTo` (or `$player[1]`) for the two proximity gates; the dialogue-skip timeout already handles the nobody-close case.

**FQ-10 · t1l3 · `gags/t1l3_flak_cannon.scr:81`** *(vanilla mainta pak1 — NOT overridden)*
- Issue: `flak_destroyed` L81/84 `vector_length(level.captain.origin - $player.origin)` throw with ≥2 players, killing the thread after `level.flakdestroyed=1` but **before** `thread airdropdialog` (L87).
- Impact: the captain-proximity gate that launches the C-47 air drop dies. Only recovery is the single BSP trigger `airdrop` (maps/t1l3.scr:396) — if players don't walk that exact trigger, **objective 4 never starts**, demo charges never spawn, mission strands before the bridge. Scripted pacing lost even when recovered.
- Fix: coop override — replace the `$player` distance loop with `player_closestTo level.captain`, or simply `wait 3; thread airdropdialog` in MP.

**FQ-11 · t1l3 · `gags/t1l3_misc.scr:296`** *(vanilla mainta pak1 — NOT overridden)*
- Issue: `kalimbasays` (two hidden dev-letter `trigger_clickitem` easter eggs) runs GLOBAL `fadeout 0.25 0 0 0 1` + `drawhud 0`, then reads `$player.viewangles` (L296) which throws with ≥2 players; the matching `fadein`/`drawhud 1` (L375/381) never run and `level.kalimbasays` stays 1 so it can't re-run.
- Impact: the moment **any** player clicks either letter in a 2+ player game, **every client's screen fades to black with HUD off, permanently** — no in-game recovery; server visually soft-locked.
- Fix: coop override — in MP print the letter via `iprintln`/`huddraw` without fadeout/position-lock, or gate the whole gag to SP; alternatively neutralize the `clickitem` label in maps/t1l3.scr.

**FQ-12 · t1l3 · `gags/t1l3_bridge.scr:126`**
- Issue: `bridge_gag_start` `level.captain turnto $player` throws with ≥2 players. Thread dies after enabling the four plant boxes (L120-123) but before `level.bridgespawnerswitch=1.0` (L133), the train-sound ramp, the captain covering-fire timers (L142/154), and the `bridge_intact` timeout.
- Impact: the entire **bridge-defense finale is silently missing** — no spawner waves while planting, no covering fire, no train tension, no timed failure. Charges still plantable, so the mission would technically finish with an empty finale.
- Fix: `player_closestTo level.captain` for the turnto (or `$player[1]` guarded); everything after L126 is already multi-player-safe.

**FQ-13 · e3l3 · `maps/e3l3.scr:106`**
- Issue: `$steal_ab_trigger` is a BSP `trigger_once` reachable during the whole house/K5 phase, but `main` only starts `waittill trigger` **after** DoObjective4. A run-ahead player consumes the one-shot while nothing is listening.
- Impact: one player routinely explores past the K5 yard while others plant explosives; once the trigger_once fires unheard, `main` waits at L106 **forever** → DoObjective5/6 never run, AB41 ride never arms, mission cannot complete (needs map restart).
- Fix: latch it — spawn a watcher before prespawn returns (`$steal_ab_trigger waittill trigger; level.coop_stealAB = 1`) and replace L106 with `while (level.coop_stealAB != 1) { waitframe }`. Same recipe already used for other one-shot triggers in the mod.

**FQ-14 · e3l4 · `global/credits.scr:724`**
- Issue: `credits_done` (natural end-of-credits path from Outro.scr::RollTheCredits) runs `$player stufftext "disconnect"` with **no gametype guard**. Only the skip path (`credits_skip`→`coop_creditsSkip`, needs a fire-hold majority) routes to `exec global/missioncomplete.scr level.coopNextMap bsp2bsp`.
- Impact: at the Breakthrough campaign finale, any session that watches credits to the end has **every client force-disconnected to the main menu** instead of cycling to nextMap (t1l2). Session dies; server left empty on e3l4.
- Fix: mirror the credits_skip guard in credits_done — `if(level.gametype != 0){ exec global/missioncomplete.scr level.coopNextMap bsp2bsp; end }` before the ui_hud/disconnect stufftexts.

---

## 3. Per-Map Detail

### m3l1a — Grade B+ · 0 P0/P1
**Parse/QA:** PASS. depthscan2 balanced on all three scripts (the 3 depth-1 labels mortar_puzzle_loop / boarder_warning_loop / cover_zone_loop are legitimate internal goto labels). C-style `;` at coopified.scr:79 is a legal token. One `waittill pain` at m3l1a.scr:7537 is runtime-dead (only caller commented out at L7507).
**Addon:** N/A — implemented by absence. 0 `addon_*` entities in a 1870-entity AA-native BSP; all AI classes (ai_allied_dday_*, ai_german_wehrmact_grenadier) are engine-native.

| Sev | File | Issue |
|---|---|---|
| P2 | maps/m3l1a/coopified.scr | `manageRespawns` evaluates `flags["coverRespawnManageTime"] + 10` with no NIL guard; the flag is set by the coop_playerJustSpawned callback which lands 1+ frames after `coop_isActive=1` → `NIL+int` throw (scriptvariable.cpp:1496). |
| P2 | maps/m3l1a.scr | `cover_zone` threaded unconditionally per `$cover_trigger` (L912) using raw `$player istouching self` (L~1730) and `$player getposition` (L1743). With 2+ players `$player` is a container → `execMethodCommon`→`listenerValue()` throws "Cannot cast container to listener" (scriptvariable.cpp:1109). The mortar equivalent (L1450) already uses `replace.scr::istouching`; cover_zone was missed (comment at 1730 wrongly says "only done in sp"). |
| P3 | maps/m3l1a.scr + coopified.scr | Production dev prints to all players: m3l1a.scr:5109 "DEVDEBUG: allow all players to join the party" (every shingle blast), coopified.scr:194 "DEVDEBUG…spawn near shingle", coopified.scr:209 "krater koffer", m3l1a.scr:1440 "MORTAR PUZZLE multicall", :1641 "DEV: boarder_warning_loop, no player". |
| P3 | maps/m3l1a.scr | `boarder_warning_loop`: only the non-kill branch loops (L~1717); after the arty/MG kill path fires on an OOB player the thread falls to end. SP reloaded a save so the one-shot never mattered; in coop the boundary system is dead for the rest of the mission. |
| P3 | maps/m3l1a.scr | Registers only `coop_playerJustSpawned` (L167); respawns dispatch `coop_playerJustRespawned` (player.scr:937), unregistered → `coverRespawnManageTime` never refreshed on respawn, contradicting the design comment at L8245-8250. |
| P3 | maps/m3l1a.scr | `ai_friendly_pain` contains `self waittill pain` (invalid, blocks forever) — runtime-dead (only caller commented out at L7507). One of the known "5 m-series waittill pain pending". |

### m6l3a — Grade B− · 0 P0 / 1 P1 (FQ-8)
**Parse/QA:** PASS. All 116 labels enter at depth 0; no BOM, no non-ASCII, no waittill pain, no bare negatives, no dup labels. All 30 BSP setthread values resolve; every referenced `$targetname` exists in the dump or is script-spawned.
**Addon:** N/A — 0 `addon_*` entities (AA-native BSP: 756 info_pathnode, stock classes). Note: contrary to the task premise this map **was** converted by original HZM (chrissstrahl/Criminal/Smithy annotations); audited anyway.

Confirmed: **FQ-8** (spawn-warper inverted polarity, L3130).

| Sev | File | Issue |
|---|---|---|
| P3 | maps/m6l3a.scr | scene2 gate `while (level.scene2_snipers != 4)` is deliberately commented out (documented L660), so scene2_complete runs one frame after platform egress: obj1 auto-completes ~8 s after the train stops, the four tower-reinforcement spawners can never activate (gated on `objective1 != 1`), and the Ranger-casualty monitor `scene2_alliedspawn_showalive` exits immediately — its mission-fail branch (L1207, correctly via replace.scr::missionfailed) is dead code. |
| P3 | maps/m6l3a.scr | Objective 1 compass marker anchored to `$player.origin` — in MP resolves against player[1] (HZM flagged this wobble at L1198); every later add_objectives uses `$world.origin` (e.g. L1199). |
| P3 | maps/m6l3a.scr | `scene4_pow_sequence` spawns 10 POW actors (L1842-1851) never positioned/released — their placement block (L1853-1906) is commented out; a second for-loop (L1907) spawns the 10 that actually escape. Vanilla-identical (retail L2146-2155), inherited noise. |

### t1l2 — Grade B · 0 P0/P1 (1 dismissed)
**Parse/QA:** PASS on maps/t1l2.scr, t1l2_precache.scr, gags/t1l2_friend.scr, gags/T1L2_Flak88.scr. Caveat: depthscan reports `gags/t1l2_cappy.scr` ending at depth 1 — verified FALSE POSITIVE from a retail unterminated string at L565 (`dprintln "failed grenade test…`); the lexer terminates strings at newline so braces stay balanced and the file compiles (live-verified coop edits below it). Logged as P3 so the scanner comes back clean.
**Addon:** unhandled — 2 `addon_*`, 0 handled. (1) `addon_vehicle_german_Opel-Truck-All` "truck_1" @ (1823,-960,11) → generic Object fallback (model renders, vehicle events silently ignored) — this was raised as a P0 but **dismissed** (truck is a static prop here, no drive/vehicleanim scripted). (2) `addon_vehicle_allied_rowboat-1-2` (end-of-map river prop) → Object fallback, cosmetic. The e3l3 `coop_spawnOpel` recipe is absent from t1l2.

| Sev | File | Issue |
|---|---|---|
| P2 | coop_mod/spawnlocations.scr | No `t1l2` label anywhere (main threads the mapname as a label; ~50 other maps have labels + `_updateN` forward-respawn entries). BSP has zero DM spawns and one info_player_start @ (1689,-5055). |
| P3 | gags/T1L2_Flak88.scr | `CancelGagWait` uses `self waittill pain` — never fires; wound-triggered cancel of the flak-B loading gag is dead. Only `CancelGagOnDeath` (waittill death, L258) can cancel. |
| P3 | gags/t1l2_cappy.scr | Retail typo — unterminated string at L565. Harmless at runtime (lexer terminates at newline) but makes depthscan report the file brace-broken. |
| P3 | gags/t1l2_friend.scr | `FinishLevel` still drives native SH `func_objective` (`$Objective3` text/TurnOn/SetCurrent, L254-256) while objectives 1-2 were converted to the coop panel (maps/t1l2.scr:150). func_objective is implemented (Entities.cpp:2165) so nothing crashes, but the final objective bypasses the coop system. |

### t1l3 — Grade F · 2 P0 / 4 P1 (FQ-6, 7, 9, 10, 11, 12)
**Parse/QA:** PASS on all mod-owned files; no BOM, no non-ASCII, no waittill pain, no bare-neg-parens, no dup labels.
**Addon:** handled by engine TIKI fallback (not script) — 10/11 `addon_*` resolve to working native classes (4× mg42 turret→TurretGun, Opel→drivablevehicle, train + 3× bridge props→ScriptModel, 2× Tigertank-destroyed→ScriptSlave/VehicleTank). 1/11 unhandled: `addon_fx_sustained-fire` (client-only init, no server classname) → inert Object, effect never plays (P3 below). No e3l3-style respawn code needed.

Confirmed: **FQ-6** colonel.scr:196 (P0), **FQ-7** tank.scr:141 (P0, vanilla), **FQ-9** colonel.scr:692 (P1), **FQ-10** flak_cannon.scr:81 (P1, vanilla), **FQ-11** misc.scr:296 (P1, vanilla), **FQ-12** bridge.scr:126 (P1). 1 dismissed. *Note four of the six defects live in vanilla mainta pak1 gags the mod never overrode — those must be added to the coop pk3.*

| Sev | File | Issue |
|---|---|---|
| P2 | gags/t1l3_bridge.scr | Endgame cinematic threads keep bare `$player`: precameracut `$player physics_off`/`hide` (L501-502), camera_collapse `$player.origin=(0 0 6000)` (L440), camera_intact same (L487), bridge_kills_player `$player damage`/`isAlive $player` (L526-527). Each dies at its first `$player` line with 2+ players; bridge_kills_player dies **before** its own coop missionfailed shim (L530). |
| P3 | coop_mod/spawnlocations.scr | No `t1l3` label → main's dynamic `thread (mapname)` raises "label t1l3 does not exist" at init; `coop_spawnNorigin` flags stay NIL until maps/t1l3.scr `coop_endgameSpawn` sets them post-tank-kill. |
| P3 | maps/t1l3.scr | BSP `addon_fx_sustained-fire` (L18 @ -2376 4248 126, next to the dead Tiger) spawns as inert Object; `testanim idle` emitter never plays. |
| P3 | gags/t1l3_colonel.scr | `captaindeathcheck` in the coop OVERRIDE still calls raw `missionfailed` with no gametype guard, unlike t1l3_bridge.scr which routes through replace.scr::missionfailed. |

### t2l2 — Grade A− · 0 P0/P1
**Parse/QA:** PASS. Balanced, all 77 labels at depth 0, no dup labels, no BOM/non-ASCII/bare-neg/waittill pain, no bad map-transition. Subscripts (t2l2_camera/motorcycle/supply_truck_damage) are retail mainta pak scripts, retail-proven and player-safe in coop.
**Addon:** implemented — 92 `addon_*` / 19 classes, all functional (no shims needed). Mission-critical ride vehicles resolve via the model-TIK classname fallback: `$s1_jeep1`=snowy-halftrack-antitank, `$s1_truck1`=Opel-Truck cargo, panzer1-7=snowy-PanzerIV, sdkfz/sdkfz2, panzerwerfer, bmwbike — all script-driven. 3× mg42→TurretGun, 7× addon_ai_*→Actor, ~62× fallingtrees→DamageModel, 3× fx→effectentity/Animate. Non-addon nebelwerfer + ProjectileGenerator_Heavy also resolve.

| Sev | File | Issue |
|---|---|---|
| P2 | maps/t2l2.scr | All 7 axisNdelete cleanup threads (L410-463) reference `$axis1..$axis7` which don't exist — AI carry `$enemyname "axisN"` script-var keys instead, which `$`-targetname lookup never matches. Each dies on its first `$axisN delete`, so cascaded cleanups never run: axis3 never deletes panzer1/2+guns, axis4 never deletes panzer3+gun, axis5 never deletes nebel1 (nebelwerfer + ProjectileGenerator stay live if crew survives), axis6 never hides the sdkfz hulk. |
| P3 | maps/t2l2.scr | `coop_seatShield`'s comment (L760-763) claims it makes seated players NOTSOLID across path-snap lurches, but the code executes `local.p solid` (L769) — identical to the restore path (L784). The "shield" is a no-op; buglog bug-062 recorded the solid→notsolid fix but the current file has solid in both paths. |
| P3 | maps/t2l2.scr | `$(sdkfz.gunner) remove` (L491, L517) is malformed: inside `$()` the bare `sdkfz` is a string constant → `"sdkfz".gunner`→NIL→script error, killing sdkfzdead at its last statement. Should be `$sdkfz.gunner`. Retail-inherited. |
| P3 | maps/t2l2.scr | Truck speed-control dead: zero entities targetnamed `truckspeed`, so `truck_speed_controls` (L855) iterates empty; the truckspeed label (L862) falls through into truckhealthcheck (L876) with no goto → triggerloop (L904) unreachable. Byte-identical to retail. |
| P3 | maps/t2l2.scr | Route-explosion triggers `daveexplode21`/`daveexplode33` never wired to triggerexplode (wiring list L146-169 covers only the retail set). Retail-identical omission. |

### t2l3 — Grade F · 3 P0 (FQ-3, 4, 5)
**Parse/QA:** PASS on maps/t2l3.scr and gags/t2l3_medic.scr. No BOM/non-ASCII/dup-labels/waittill-pain/bare-neg. Coop path uses `exec global/missioncomplete.scr t2l4 1` (routes gametype!=0 through the coop transition; bsptransition only in the SP branch); maps/t2l4.scr exists; autosave.scr no-ops in MP.
**Addon:** **UNHANDLED — 100 `addon_*`, 0 implemented, 0 partial.** No e3l3-style [208] stand-in spawning at all, yet the addon entities ARE the cast: 3× snowy-PanzerIV, halftrack-nogun, Opel-Truck-All, granatwerfer turret, panzerschreck, 12× ai_allied_snow (medic/webber/privateparts/soldier01-04 + 6 friendlies), 78× fallingtrees (incl. script-ref `$playertree1`/`$panzer2tree`), 7× trench-shovel props. Engine implements no addon_ classes; e3l3 [208] blocks are the proven fix template (spawn native script_vehicle/script_model/actor at exact BSP origin/angles, reapply `$`-keys).

Confirmed: **FQ-3** t2l3.scr:16 (P0, cast never spawns), **FQ-4** medic.scr:475 (P0), **FQ-5** captainruntoandtalk.scr:52 (P0, vanilla). 3 dismissed.

| Sev | File | Issue |
|---|---|---|
| P2 | maps/t2l3.scr | `killplayer` (BSP setthread on 3 boundary trigger_multiples) kills **every** alive non-spectator player whenever ANY player touches one; SP killed only the offender. Contrast `takeoutplayer` (L3068) which correctly filters by `isTouching $killbrush` per player. |
| P2 | coop_mod/spawnlocations.scr | No `t2l3:` label → main's dynamic dispatch raises "label t2l3 does not exist" (same failure the empty t2l2/co_lobby labels were added to silence). BSP has one info_player_start, no DM spawns. |
| P2 | maps/t2l3.scr | 78 fallingtree props + 7 shovels never spawn, incl. script-ref `$panzer2tree` (nodamage L161, panzer2's aim target L851-859) and `$playertree1`; commands/tests on the missing targetnames throw / raise "Targetname does not exist". |
| P2 | gags/T2L3_Friendly.scr *(vanilla, no override)* | `TreeDeath` does `$TreeGuy1prop throw $TreeGuy1 100 $player` (and L148): `$player` as an entity arg throws with ≥2 players, killing both TreeDeath threads before the death anims at L152. |
| P3 | gags/t2l3_medic.scr | `change_fog`/`restore_fog` (BSP-wired) test `$player istouching $restorefog`/`$changefog` — single-listener, throws with ≥2 players after the first farplane step. |
| P3 | maps/t2l3.scr | Dev shortcut (`getcvar(start)=="end"`) assigns `$player.origin=(388 3811 1816)` — a field WRITE on the container, throws and kills main with 2+ players when the start cvar is set. |
| P3 | maps/t2l3.scr | `panzer2_target_preference` hard-skill branch does `$panzer2.gun = self QueryTurretSlotEntity 0` but self is the MEDIC actor (thread chain inherits self=$medic), not the tank — QueryTurretSlotEntity on an Actor throws. Retail bug preserved. |
| P3 | maps/t2l3.scr | Intro title cards use SP `showmenu bastogne1/2/3` + hidemouse; on a dedicated coop server these UI commands don't reach (all) clients. |

### t2l4 — Grade F · 2 P0 (FQ-1, 2) + 1 P2
**Parse/QA:** PASS on maps/t2l4.scr, t2l4_precache.scr, gags/t2l4_captain.scr, gags/t2l4_newstuka.scr; zero non-ASCII, no BOM/bare-neg/dup-labels. One invalid `waittill pain` (captain.scr:1181, retail-inherited, P3 below). Retail-served subscripts (t2l4_start, T2L4_End, T2L4_Friendly from mainta pak1) also clean.
**Addon:** unhandled by script / covered by engine fallback — 68 `addon_*` entities, NO e3l3-style [208] handling anywhere, but all load-bearing addons resolve to working native classes via the TIKI-classname fallback (g_spawn.cpp:242-306): human tiks→Actor, mg42_gun.tik→TurretGun, PanzerIV/panzerwerfer→VehicleTank (self-attaching cannons), flak/aagun→FixedTurret; sub-turrets named `<tn>_turret<N>` exactly as retail scripts expect (`$flak1_turret0`, `$aagun1_turret0_turret0`). So captain, ranger allies, MG nests, panzers, werfer, player aagun all spawn/function; the blockers are the script-side `$player` conversions, not addons.

Confirmed: **FQ-1** start.scr:46 (P0, vanilla), **FQ-2** captain.scr:227 (P0). Plus:

| Sev | File | Issue |
|---|---|---|
| P2 | gags/t2l4_start.scr *(vanilla, no override)* | Retail `main:` is exec'd at prespawn (maps/t2l4.scr:28) when no player entity exists yet on a coop server, so `$player stufftext tmstart…` throws and kills retail main **every coop load**. L13-37 never run: `$cappy`/`$startguy1`/`$startguy2`/`$sniper1` never get disable_ai/turndamageoff, `level.stop_running` never init'd, mission music lost. Impact: captain and church sniper are AI-active and damageable from level spawn until post-join protections apply; on a server idling before first join the escort NPC can wander/engage/die with no missionfail hook armed. Fix in the same t2l4_start override: split main — do NPC disable_ai/nodamage + level-var init unconditionally (no `$player`), move the `$player` music/takeall lines behind the waitForPlayer gate. |
| P2 | coop_mod/spawnlocations.scr | No `t2l4` label → "label t2l4 does not exist"; zero coopPlayerSpawn points placed. BSP has no DM spawns, one info_player_start → engine stacks every spawn on the single SP start. |
| P3 | gags/t2l4_captain.scr | `WakeupOnPain` uses `self waittill pain` — invalid; windowguy_5's wake-on-pain shortcut is dead. Retail-inherited. |
| P3 | maps/t2l4.scr | `give_sniper_rifle`: `$sniper_rifle playsound gewehr43_snd_pickup` targets a targetname that exists nowhere → NULL command kills the thread after the replace.scr::item give (L1012) but before the iprintln + auto-equip (L1016). |
| P3 | gags/t2l4_newstuka.scr | Retail `$player playsound stuka_by` is commented out (L179, no defect). Note killcaptain (L368-378) is correctly coop-shimmed; stuka_start's kill window relies on players manning the FixedTurret-fallback aagun while `$stuka` is immune bullet/explosion — engine-side, untestable statically. |
| P3 | maps/t2l4.scr | TurnTanksOn/Off/RemoveTanks/ChurchBoth/ChurchOutside/HotelBoth/HotelOutside are immediately followed by `end` with dead code below (L260-333) — identical in retail, intentionally disabled, not a conversion error. |

### t3l2 — Grade B · 0 P0/P1
**Parse/QA:** PASS. depthscan2 balanced, no dup labels, no reachable waittill pain (gags/t3l1_enemyspawn.scr:608 StopTruckOnPain has one but t3l2 calls DoTruck with bSmartPassengers=0 for both trucks so it's never threaded), no bare-neg. **DEFECT in the supplied dump:** `ents_t3l2.txt` is TRUNCATED — missing the final BSP entity `trigger_multiple "$targetname" "cheaterkiller" "setthread" "killcheater"` (model *343 @ 3342 4690 -32). Verified against the raw entity lump; the script's `$cheaterkiller` refs (L1054/1536) are NOT dangling, but **regenerate the dump before trusting it for other maps.**
**Addon:** implemented (engine-level) — all 47 `addon_*` resolve via the TIKI-classname fallback: T34tank→VehicleTankTandem, T34tank_ai/TigerTank/Panzerwerfer-AI→VehicleTank, Opel→DrivableVehicle, soviet_infantry→Actor, fx→effectentity/Animate. 20/47 degrade to Object (16× barrel-health4tanks + 4× fx sustained-fire) — acceptable (barrels are props; tank-heal is done by separate BSP triggers→health_pickup threads; Object derives from Animate so `anim start/stop` still works). No respawn shim needed; the map adds explicit coop T-34 driver plumbing (Pattern C, L46-83).

| Sev | File | Issue |
|---|---|---|
| P2 | maps/t3l2.scr | **coop_autoDriveTankFallback doubly broken:** (a) L1182 sets `level.coop_playerTank = $playertank`, which permanently exits `coop_selectDriverForTank`'s `while (coop_playerTank == NULL)` boarding loop (vehicles_thinkers.scr:62) — re-armed only at the end of coop_setDriverForTank which never ran, so boarding is dead for the session; (b) L1184 drives the tank toward `$playertank_trigger`, a trigger_multiple with NO `target` key (model *73) → Vehicle::SetupPath bails on the empty chain (vehicle.cpp:3618), AutoPilot self-disables (vehicle.cpp:3218-3221), drive_path's `waitTill drive` parks forever. If nobody boards the T-34 within ~20s the central vehicle is permanently unusable AND stationary; mission still completable on foot (bridgecollapsetrigger accepts any active player as shell owner, L1112-1117) but the tank mechanic is bricked. Fix: delete the claim + fake drive (bridge validator already accepts `$playertank`-owned shells independently, L1110); either end the fallback as a no-op (keep boarding open) or, if auto-drive is truly wanted, build a real info_waypoint chain (or reuse `$s5_tank_path`) and pass THAT to drive_path — never `$playertank_trigger`, and never assign a non-player to `level.coop_playerTank`. |
| P2 | maps/t3l2.scr | `exec gags/T3L2_KingTiger.scr` runs the vanilla base-pak gag whose main (L47, mainta/pak1, not overridden) re-clobbers `level.playertanktarget = $player`, undoing the coop assignment at L29-36. In MP `$player` is a CONSTARRAY and L143→187 run in one frame (no waits), so `$s45_tank1`'s enemy_tank_think reaches `self.gun setAimTarget level.playertanktarget` (vehicles_thinkers.scr:1110) with the array → "Cannot cast const array to entity" (scriptvariable.cpp:942), killing the s45 think thread before enemy_tank_attack_loop/tank_pain/TankExplodeOnDeath are threaded. `coop_trackTankTarget` (replace.scr:2850) heals the level var 0.5s later but s45's init already died. |
| P3 | maps/t3l2.scr | `self.driver thread GotoPosition $anchor8` — case mismatch vs the defined `GoToPosition` (L337). OpenMOHAA label lookup is case-sensitive (gamescript.cpp:256) → label-not-found kills DoFriendlyTruck at its final statement. Vanilla-inherited. |
| P3 | coop_mod/spawnlocations.scr | No `t3l2` label → "label t3l2 does not exist" every coop load. Functionally covered: the single info_player_start is the MP spawn fallback (GT_TEAM, zero DM spawns) and the respawn-warper snapshots living players ~2s and warps respawners to their last position. |

### e3l3 — Grade C+ · 0 P0 / 1 P1 (FQ-13)
**Parse/QA:** PASS on all 9 files. depth never negative, 0 at every label; FindTriggerEnd at depth 1 is a legit internal goto label. No BOM/non-ASCII/dup-labels; all 8 former `waittill pain` already converted to `waittill damage` [208]. No bad transition; ending routes through global/missioncomplete.scr (coop wrapper); autosave.scr coop-neutralized. All 15 BSP setthread labels resolve.
**Addon:** partial — 38 `addon_*`. **Handled:** 2× K5 (KFiveInit script_model swap + NULL guards), AB41 (TIKI-fallback drivablevehicle + full [208]/[209] coop ride: dual turret seating, hull-glue seats, stall watchdog, landing teleport), Anziomappuls (Object fallback so not stealable early; pickup sound shimmed), 6/7 Opel trucks respawned as native drivablevehicle, 4× mg42→TurretGun, 16 trees + 5 K5bullet + K5AmmoCart + Panzerwerfer via fallback. **Partial:** aaguntruck respawn drops its autotruck keys (#passengers 4, drivermodel/passengermodel, path target replaced with "dastruck_collide") and hidden-until-triggered state. **Unhandled:** k5truckmove (7th Opel, finale set-piece) never respawned — still the dead fallback.

Confirmed: **FQ-13** e3l3.scr:106 (P1, steal_ab trigger softlock).

| Sev | File | Issue |
|---|---|---|
| P2 | maps/e3l3.scr | aaguntruck respawn breaks the autotruck reinforcement set-piece: BSP addon carried #passengers 4 + driver/passenger models + path target t222665, driven by the global autotruck system. `coop_spawnOpel` is called without the crew arg and hardcodes target "dastruck_collide" (L832); auto.scr wakes at prespawn before e3l3 main, so autotruck::init runs on (and hides) the OLD fallback which is then removed — the replacement truck is never init'ed and has no crew/path/speed. |
| P2 | maps/e3l3/e3l3_AB41.scr | k5truckmove (7th Opel, BSP @ 4200 -5935 -1349, path t222624) is the only Opel NOT respawned by the [208] hardening. MoveTruck drives + waits on it (L620-625), RightSideExplosion fullstops/kills it (L534-535), MyTruckThink loads 4 crew (L621) — all against the dead fallback that never drives (`waittill drive` hangs) and can't take damage. |
| P2 | maps/e3l3/scene2.scr | KFiveKilled's second (ram) invocation dereferences entities that no longer/never exist: `$kfive_one_explosive1/2` removed by the first run (L404-405), `self.collision` NIL on the 2ndK5Fire gun (spawned without .collision, hit L415), `$k5kill2`/`$kfive_des_collide2` have zero BSP occurrences (L449-455). NULL-listener semantics → thread dies before the destroyed-model swap. |
| P3 | maps/e3l3/scene3.scr | DoObjective5 discards DistanceUse's return value (the exact player who pressed Use), then threads GetOnPathVehicle with inherited self=NULL, so its rider pick (`player_closestTo self`) degenerates to whichever player is closest to world origin (0 0 0). |
| P3 | maps/e3l3/scene1.scr | CleanupScene1 opens with `self stoploopsound` but is waitthread'ed from the level thread (e3l3.scr:83) where self isn't an entity — the command aborts the thread immediately, so the coop_releaseFire failsafe + var cleanup below never run, and nothing stops the `coop_truck_run` loopsounds started at L444-446. |
| P3 | maps/e3l3.scr | SpawnK5Guys does `$k5jumper thread InitK5GuySimple` but no BSP entity produces targetname `k5jumper` (only `$enemyname k5faller` exists) — NULL command aborts before L324, so the k5faller AI never get turret-lock/death-anim setup. Vanilla-inherited. |
| P3 | maps/e3l3/scene1.scr | LoadDriver/LoadPassenger spawn crew with extensionless model paths (`models/human/german_wehrmact_soldier`) — CanonicalTikiName only prepends `models/`, never appends `.tik`, so the tiki lookup can fail and fall back to a bare Object. Every mod-authored spawn uses the .tik suffix. |
| P3 | maps/e3l3/cleanup.scr | cleanup1 checks `$istcaveguys` but the BSP spawner is `1stcaveguys` (typo), and the gate triggers `$cleanup1/$cleanup2` have zero BSP occurrences, so cleanup1/cleanup2 are complete no-ops. Vanilla-inherited, all guarded. |

### e3l4 — Grade B · 0 P0 / 1 P1 (FQ-14)
**Parse/QA:** PASS on all 14 scripts; depth-balanced, no BOM/non-ASCII, no waittill pain, no dup labels. The suspicious `exec coop_mod/replace.scr::$radioguy turnto` constructs are compile-safe against the bison grammar (const_array allows nonident_prim_expr after `::`) — runtime no-ops, not file-killers.
**Addon:** implemented via engine TIKI-classname fallback (not scripts) — all 179 `addon_*` resolve: 14× 30cal-3rdperson→TurretGun (mannable via mg42init::AttachGuyToMG42), 111 candle FX→Object/ScriptModel, ~45 outro-cinematic FX/props→EffectEntity/ScriptModel/VehicleTank, 5 trees→DamageModel, 6 playerweapon props→Object/Weapon with script-side pickup triggers, 2 Panzerwerfer wrecks + jeep glider→static. `$bunker3mg1` etc. resolve via the `"$targetname"` setter path. Unlike e3l3, needs NO addon replacement work.

Confirmed: **FQ-14** credits.scr:724 (P1, credits_done disconnect). 1 dismissed.

| Sev | File | Issue |
|---|---|---|
| P2 | maps/e3l4/Bunker3.scr | SP anti-abandon fail triggers are any-player-tripped in coop: RetreatToBunker3Failure fires coop missionfailed (fade + full map restart) if `$canyonautosave` is touched while `currentobjective != ObjRegroupInCastle`; same in LeaveMissionFailure (Bunker2.scr:602-613, Bunker3.scr:214-225) for the bunker-leave triggers during defense objectives. |
| P3 | maps/e3l4/Tower.scr | Malformed shim `exec coop_mod/replace.scr::$radioguy turnto` (also L206 lookat, friendly.scr:54 `::self turnto`). Compiles as a const-array exec, throws at runtime (VM-recovered), so the intended replace.scr::turnto/lookat never runs. |
| P3 | maps/e3l4/Bunker2.scr | `$bunker2parade.totalguys = local.wave1 + local.wave2 + wave3 + 5` — `wave3` is a bareword (retail bug, byte-identical), so totalguys becomes the string "20wave35"; parade.scr:470 `spawncount >= totalguys` throws int-vs-string each tick (recovered→false), so the cap never applies — same net behavior as retail (battle ends via spawndead waits + DeleteParade). |
| P3 | maps/e3l4/castle.scr | `$armoireroomdoor open $player` — with 2+ players `$player` is a container, listenerValue() throws (recovered), so the armoire-room door isn't script-opened for the cabinet ambush gag. |
| P3 | maps/e3l4/Bunker3.scr | `$jeepdriver.origin = $jeepdriverwaitpoint` assigns an entity to the origin setter (missing `.origin`); vanilla-identical, throws (recovered), teleport no-ops. |
| P3 | maps/e3l4/Bunker1.scr | Dev hackskip warp paths still use SP `$player.origin = X` (also Bunker2.scr:188, castle.scr:40, Tower.scr:50, Escape.scr:23), which throws on the multi-player container and teleports nobody; the converted per-player loop pattern (Bunker3.scr:163-168) is used in only one place. |

---

## 4. Cross-Cutting Notes

- **Vanilla-not-overridden defects:** FQ-1, FQ-5, FQ-7, FQ-10, FQ-11 all live in retail mainta pak1 gags the mod never overrode. Fixing them means **adding those gag files to the coop pk3** (the repo already overrides sibling t1l3/t2l3 gags, so precedent + mechanism exist).
- **The recurring root cause** (11 of 14 confirmed findings): bare `$player` used as a single listener/entity in a context where, with ≥2 connected clients, `$player` is a const array / multi-targetname container → engine throws and silently kills the thread. Canonical shim: `local.p = exec coop_mod/replace.scr::player_closestTo self` (or `$player[1]` NULL-guarded) for aimat/turnto/lookat/runto/distance; iterate `$player[1..size]` for per-player damage/effects. Command-methods that iterate arrays (`$player playsound`, `$player hide/show`) are SAFE.
- **spawnlocations.scr:** t1l2, t1l3, t2l3, t2l4, t3l2 all lack a map label → benign "label does not exist" init error + spawns stacked on the single info_player_start (respawn-warper covers gameplay). Add empty labels (as done for t2l2/co_lobby) to silence.
- **t2l3 addon gap** is unique: it is the only map where the mission cast itself is unspawned addon AI with **no** e3l3-style [208] stand-in pass. That work is a prerequisite for any of its P0 fixes to matter.
- **ents_t3l2.txt dump is truncated** (missing the last entity). Regenerate entity dumps before reusing them for other audits.

---

## LIVE BOOT VERIFICATION (2026-07-22, solo coop listen-server, all 10 maps)

Harness: openmohaa.exe listen server, boot_<map>.cfg (set ui_dmmap; exec start_server.cfg), safe-mode dialog auto-dismissed. Read qconsole.log at coop-ready.

**HEADLINE: all 10 maps boot to coop-ready. ZERO of the static audit's "dead on load" F-grades reproduced.** The addon entities (AI, turrets, vehicles) spawn via the engine's TIKI-classname fallback, so the predicted NULL-listener load crashes never fire. Static audit systematically OVER-predicted load crashes and MIS-graded severity.

| Map | Live boot | Real load-time issue found |
|---|---|---|
| m3l1a | READY, clean | none |
| m6l3a | READY, clean | (spawn-warper inverted - static-airtight, not load-visible) FIXED |
| t1l2 | READY | 2x cmd-on-wrong-class (minor); missing spawnlabel (cosmetic, FIXED) |
| t1l3 | READY, clean | missing spawnlabel (cosmetic, FIXED). $player gag bugs need 2-player repro |
| t2l2 | READY | **REAL: 36x models/nil.tik + missing panzerwerfer42.tik + NIL misc-objects -> MG42 nest gunners & rocket-arty vehicle fail to spawn.** Audit graded this A- "clean" - WRONG |
| t2l3 | READY, cast spawns | missing spawnlabel (cosmetic, FIXED). Audit "F dead on load" = FALSE. Medic 2-player chain untested |
| t2l4 | READY | missing spawnlabel (cosmetic, FIXED). Audit "F inert/freeze" = FALSE at load; freezeplayer needs post-spawn 2-player test |
| t3l2 | READY, clean | missing spawnlabel (cosmetic, FIXED) |
| e3l3 | READY | 24x missing models/fx/fx-dummy.tik (cosmetic FX placeholder) + 1 collision-null |
| e3l4 | READY | **REAL: maps/e3l4/outro.scr failed to load -> 251-error arithmetic-on-none cascade; BT campaign ending/credits broken** |

### Honest repair queue (live-verified)
- **FIXED 07-22**: m6l3a spawn-warper one-liner (static-airtight); 5 empty spawnlocations labels (t1l2/t1l3/t2l3/t2l4/t3l2) silence the harmless log error, no behavior change.
- **REAL, to investigate**: (1) e3l4/outro.scr load failure (broken ending); (2) t2l2 addon spawn failures (unmanned MG42 nests + missing panzerwerfer vehicle).
- **COSMETIC**: e3l3 fx-dummy.tik missing FX.
- **UNTESTED (need 2 players)**: t1l3 gag $player chains, t2l3 medic chain, t2l4 captain freeze. Static-confirmed but not live-reproduced - do NOT fix from analysis alone.
