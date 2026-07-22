# e1l2 SP→Coop Correctness Audit (authoritative)

Map: **e1l2** "Kasserine Pass — Destroy the Artillery / Munitions Depot" (Breakthrough theatre, runs under `com_target_game 2`).
Scope audited: `maps/e1l2.scr` + `maps/e1l2/{Intro,Artillery,Crab,Hideout,bohler,hacks}.scr` + `map_entities/e1l2_entities.txt`, cross-checked against the coop framework (`coop_mod/replace.scr`, `main.scr`, `aihandler.scr`, `itemhandler.scr`, `spawnlocations.scr`) and confirmed-working coop maps (e1l3, e1l4, e3l2, m1l2a).
Method: every cited line was read; the 43 raw findings were deduped to **25** and each was verified against source (dropped/downgraded where unsubstantiated). Read-only — no edits made.

Counts: **1 P0, 3 P1, 12 P2, 9 P3**, plus 4 documented "not-a-bug / false-lead" closers.

---

## Master table

| ID | Title | Category | Severity | Location (file:line) | Smallest script-only fix |
|----|-------|----------|----------|----------------------|--------------------------|
| E-01 | DoOutro approach-gate boolean inverted → level never completes | sequence | **P0** | `maps/e1l2/Hideout.scr:471` | Add `!`: `while (!(waitthread coop_mod/replace.scr::withinDistanceOf $commander 800))` |
| E-02 | MG42 gunner `mg42guy2` never pinned to a player → rakes own German crew / free-acquires | team-targeting | **P1** | `maps/e1l2/Artillery.scr:39, 63-69`; ent `e1l2_entities.txt:12092-12142` | In `WakeMe`, after `self ai_on`, coop-branch pin to nearest live player (recipe below) |
| E-03 | Artillery-gun defenders (`cannonguys`/`campguys`) absent at the guns — consumed before players arrive | enemy-spawn | **P1** | ents `e1l2_entities.txt:4376-4398, 5549-5612, 2196-2228`; `Artillery.scr:262-272` | Fix E-02 (stops the MG mowing them); gate `CleanupArtillery` delete-triggers on objective+all-players-past (see E-13) |
| E-04 | `coop_updateSpawn6` never threaded → respawns pinned to the minesweeper tank for the whole hideout+escape | other | **P1** | `maps/e1l2.scr:330-334` (orphan); `spawnlocations.scr:2309-2328, 2332-2338` | `thread coop_updateSpawn6` at the hideout handoff and give `e1l2_update5`'s loop an exit flag |
| E-05 | Second artillery MG42 turret has no gunner (the reported "inert MG") | enemy-spawn | P2 | ent `e1l2_entities.txt:12144-12153` | Attach a gunner via `global/mg42init.scr::AttachGuyToMG42` in `InitArtillery`, or leave (SP-identical) |
| E-06 | Bohler backup crewman never woken on proximity (line 81 duplicates `crew1`) | enemy-spawn | P2 | `maps/e1l2/bohler.scr:81` | Change `local.crew1` → `local.crew2` on line 81 |
| E-07 | `minesweeperDamagePlayer` clobbers `level.coop_player` follow-target every escort frame | player-ref | P2 | `maps/e1l2/Crab.scr:578` | Delete line 578 (`level.coop_player = local.player`); damage on 581 uses `local.player` directly |
| E-08 | Escape doors `$opendoordoor` re-lock on FIRST player crossing → straggler sealed in bunker during finale | invisible-wall | P2 | `maps/e1l2/Hideout.scr:462-463` | Before `$opendoordoor lock`, loop `while(withinDistanceOf $opendoordoor <r>) waitframe`, or drop the re-lock |
| E-09 | Raw engine `attackplayer` bypasses the coop shim (replacement MG-nest gunner + scripted guys) | team-targeting | P2 | `Intro.scr:77, 1065, 1147`; `bohler.scr:100` | Route through `thread coop_mod/replace.scr::attackplayer` |
| E-10 | Intro cutscene is a single point of failure for clip-removal + mine-detector + player-unglue (no failsafe) | sequence | P2 | `maps/e1l2/Intro.scr:1305-1380` (`playerExitTank`) | Move the 3 handoffs onto an independent time/proximity watchdog |
| E-11 | `clip1`–`clip9` invisible walls removed only inside `playerExitTank` | invisible-wall | P2 | `e1l2.scr:147-211`; `Intro.scr:1369-1376` | Currently OK; harden by duplicating the removal onto the E-10 watchdog |
| E-12 | 30 instant-kill `trigger_hurt` "impale" death planes along the escort route | invisible-wall | P2 | `e1l2_entities.txt` (30× `trigger_hurt damagetype impale`) | Audit the ~6 near the minefield/artillery; shrink any overlapping a coop spawn/warp origin |
| E-13 | Enemy-cleanup + barrage-stop keyed to first-player `trigger_multiple` crossings | sequence | P2 | `Artillery.scr:128-133, 262-272`; ents `1885-1902` | Gate on `level.artilleryDestroyed` AND all live players past the line (iterate `$player[]`) |
| E-14 | Enemy waves/barricade-clears gated on `trigger_vehicle` (need the tank; desync in coop) | enemy-spawn | P2 | `Crab.scr:25,30-41,180-181`; ents `trigger_vehicle` | Confirm escort drive completes in coop; add player-proximity fallback for must-fire waves |
| E-15 | Objective/compass update triggers may not push to all coop players | objective | P2 | `e1l2.scr:229-261`; ents `setthread ...UpdateHideout/UpdateEscapeObjective` | Verify `current_objectives` broadcasts to every `$player[]` (coop objectives HUD needs explicit per-player push) |
| E-16 | Dev-hack `ObjectiveGuardCrab` applies `notsolid`+`nodamage`+`hide` to all players with NO restore | player-ref | P2 (dev-gated) | `maps/e1l2/Crab.scr:116-136` | Drop the hide/nodamage/notsolid, or pair each with its restore; only fires if `level.hackGuardCrab==1` |
| E-17 | Mine detector on spectate→respawn — VERIFIED FIXED (bug-620); residual = registration timing | item | P3 | `Intro.scr:1337`; `itemhandler.scr:1265-1275, 1322-1329` | None for normal flow; optionally register earlier than intro-end |
| E-18 | `$deadend` seal wall can trap a straggler behind it | invisible-wall | P3 | `Hideout.scr:27-30, 351-354` | Leave `$deadend notsolid` in coop, or delay the seal until all live players are past |
| E-19 | `coop_trackUser` gun-handoff safeguard is dead code (never called) | other | P3 | `Artillery.scr:393-419` | Delete it, or wire it from `coop_GunOrExplosive` on mount |
| E-20 | Mine-detector post-intro give runs 3 async `thread`s; landmine `+4/-4` juggle nets zero (SP removed it) | item | P3 | `Intro.scr:1337-1339` | Sequence with `waitthread`; drop the `+4` if matching SP intent |
| E-21 | Both Bohler guns share `level.fireWeapon` / `level.playerBohlerTarget` (per-gun state in `level.*`) | sequence | P3 | `bohler.scr:136,148,166-172,193` | Move to `self.fireWeapon` / `self.bohlerTarget` (file already uses `self.*` for per-gun state) |
| E-22 | Destroying the minesweeper tank fails the mission for ALL coop players (by design) | objective | P3 | `Intro.scr:288-303` | Optional: grace window or make `$tank2` unkillable in coop |
| E-23 | Auto-driving flail deals 20 dmg/frame to any on-foot player it touches (by design) | sequence | P3 | `Crab.scr:570-582` | Design choice; optionally reduce damage or knock aside |
| E-24 | Dev-hack branches use singular `$player.origin` (array-malformed, dev-gated off) | player-ref | P3 | `Artillery.scr:85`; `Crab.scr:81`; `Hideout.scr:50` | Guard with `if(level.gametype==0)` or `playersWarpto`; harmless while hack flags `=0` |
| E-25 | `minefieldautosave` `trigger_once` drives a coop spawn relocation (redundant w/ `coop_updateSpawn2`) | sequence | P3 | `Artillery.scr:275-291`; ent `1585-1592` | Benign; confirm `e1l2_update2` double-invoke is harmless |

### Documented — NOT bugs / closed false leads (do not re-chase)
- **N-1** `mg42guy3`/`mg42guy4` bunker gunners are `ai_off` with `TurnOnMG42s` commented out (`Hideout.scr:17-20`) — **byte-identical to SP**, intentionally inert then `EntityCleanup`-deleted (`Hideout.scr:560-561`). The reported "inert MG" is E-05/E-06, not these.
- **N-2** `magazineBlown` `trigger_relay` (`Hideout.scr:12`) is spawned and never referenced — inert in SP too; destroy-hideout runs off `level.chargeset`. No coop hazard.
- **N-3** One `info_player_start` + `addon_*` escort/artillery classes: coop spawns via `spawnlocations.scr`, not `info_player_start`; the `addon_vehicle_tank_sherman`/`addon_turretweapon_*` classes ARE implemented here (escort + Destroy-Artillery function). `addon_*` is NOT why enemies are missing.
- **N-4** PARSE + player-ref health CLEAN: no non-ASCII/em-dash/bare-`(-N)`/BOM; every singular `$player` sits inside a `level.gametype==0` guard or a dev-hack branch; team-critical damage loops (`Artillery.scr::ChargeDamage`, `Crab.scr::minesweeperDamagePlayer`) correctly iterate `$player[]` with `dmteam`/`coop_isActive` checks; map transition uses framework-wrapped `exec global/missioncomplete.scr e1l3 1` (no `bsptransition`/`leveltransition`/`loadMap`).

---

## P0 detail

### E-01 — DoOutro approach-gate boolean is inverted → the mission can never complete (softlock)
**File:** `maps/e1l2/Hideout.scr:471`
```
while (waitthread coop_mod/replace.scr::withinDistanceOf $commander 800){
    waitframe
}
```
**SP original** (`original-scripts/.../Hideout.scr:426`): `while (vector_length ($player.origin - $commander.origin) > 800) waitframe` — blocks WHILE the player is far, PROCEEDS once a player gets within 800, then plays the commander's final lines and `fadeout 3 0 0 0 1`.

**Root cause:** `coop_mod/replace.scr::withinDistanceOf` (verified `replace.scr:1728-1783`) returns **1 while ANY active player is within the distance**. So `while (withinDistanceOf $commander 800)` loops (blocks) WHILE a player is CLOSE and only exits once EVERY player is farther than 800 — the exact opposite of SP. The `[205]` coop port swapped the `$player`-distance test for the shim but forgot to negate it (SP `dist > 800` ≡ "NOT within 800", which must be `while !(withinDistanceOf 800)`).

**Why it breaks the level:** The escape objective ("Rendezvous with Tank Convoy", `e1l2.scr:93`) drives players TO the commander/jeep, and `ObjectiveEscape` ends on `$deletetrigger4` right at that rendezvous (`Hideout.scr:462`, trigger at `4320 4320 496`). At `DoOutro` entry a player is essentially always within 800 of the commander, so the loop spins forever; the outro dialogue + `fadeout` never run, `waitthread DoOutro` (`e1l2.scr:96`) never returns, and `exec global/missioncomplete.scr e1l3 1` (`e1l2.scr:99`) is never reached. **The map cannot be finished.**

**Fix (one character):**
```
while (!(waitthread coop_mod/replace.scr::withinDistanceOf $commander 800)){
    waitframe
}
```
This is the confirmed-working recipe used by every other coop "wait until a player approaches" gate — `e1l3/Boating.scr:210,227` `while !( waitexec ...withinDistanceOf $Boat1 600 )`, `e3l2/prisoner_section_1.scr:294`, `e3l2/MiniCourtyard_Section.scr:87`, `e1l4/PostShip.scr:84`. Grep confirms **Hideout.scr:471 is the ONLY `withinDistanceOf` approach-gate in the entire mod missing the `!`**. Confidence: **high**.

---

## P1 detail

### E-02 — MG42 gunner `mg42guy2` is never pinned to a player (friendly-fire / free-acquisition)
**Files:** `maps/e1l2/Artillery.scr:39` (`$mg42guy2 thread WakeMe $wakemg42guy2`) and `:63-69` (`WakeMe`); entity `e1l2_entities.txt:12092-12142`.
```
WakeMe local.trigger:{
    self ai_off
    local.trigger waittill trigger
    self ai_on
}end
```
**Verified facts:** `WakeMe` is byte-identical to SP and **never sets an aim target or enemy**. `mg42guy2` (ent `12092`) is `ai_german_afrikacorps_soldier_nowrap`, `type_attack "turret"`, `type_disguise "salute"`, angle 180 (faces **west/−X**); its turret `mg42` (`12134-12143`, `target mg42guy2`, `maxYawOffset 50`) sits at `-1572 -5357 928`. The `cannonguys` crew (E-03) stand west of it at `-4076 -5684` and `-2930 -5714` — directly in the turret's westward beaten zone.

**Why coop breaks it:** In SP the scripted intro tank-run massacres the westward camp/parade Germans before the lone player trips `wakemg42guy2`, so nothing friendly survives in the arc. In coop the intro plays against a jeep-camera clone on a desynced clock (`Intro.scr::coop_startJeepSpawnManager`), so many Germans are still alive when players clear the minefield and approach from the west; the turret gunner — with no pinned enemy — free-acquires and his westward bursts pass through the living `cannonguys`. `coop_mod/aihandler.scr::isMachineGunner` (`aihandler.scr:877-881`) requires `type_attack=="machinegunner"`, so the coop MG handling never touches this `type_attack "turret"` gunner.

**Fix — copy the framework's player-pin recipe** (`coop_mod/aihandler.scr::attackPlayer` at `708-717`). Add a coop branch to `WakeMe`:
```
self ai_on
if (level.gametype != 0){
    local.p = waitexec coop_mod/replace.scr::player_closestTo self NIL
    self thread coop_mod/aihandler.scr::attackPlayer local.p   // sets attackplayer + favoriteenemy local.p
}
```
Leave the SP path untouched. If collateral through friendlies persists, the cheapest interim is a per-frame "hold fire when a German actor is between muzzle and target" check, or clear the camp Germans from his west arc before he wakes (mirror the SP pre-wake massacre). **Do not change the entity's team — the Germans are correctly teamed; this is target-selection / collateral bullet damage.** Confidence: **medium** (code fact confirmed; exact damage mechanism needs a live actor-count check).

### E-03 — Artillery-gun defenders appear absent in coop (consumed before players arrive)
**Entities:** `cannonguys` = **pre-placed** `ai_german_afrikacorps_soldier`/`officer` actors sitting AT the guns (`e1l2_entities.txt:4376-4398`, `5549-5612`; origins `-4076 -5684`, `-4368 -5616`, `-2930 -5714` next to `artillery1charge`/`artillery2charge`). `campguys` likewise pre-placed (`2196-2228`). **Verified: these are NOT `info_aispawnpoint` spawners and have no `waittrigger` gate — they exist and are active from map load.**

**Therefore the reported "enemies at the artillery guns do NOT spawn" is a mis-diagnosis: they don't fail to spawn, they are consumed/killed before players engage.** Strongest supported cause: **E-02** — `mg42guy2` faces west directly into the `cannonguys` and mows them down while players are still crossing the minefield. Secondary risk: `CleanupArtillery` (`Artillery.scr:269-271`) `EntityCleanup`s `cannonguys` on `deletetrigger3` (`trigger_multiple`, first-player-touch at `3696 -2960`), so a player who rushes/respawns east of the guns can delete them mid-fight for everyone (see E-13).

**Fix:** Resolve E-02 first (removes the friendly-fire that thins them), then gate the E-13 cleanup triggers so `cannonguys` can't be deleted while a live player is still fighting at the camp. **Confirm at runtime** with an actor-count print (`$cannonguys`/`campguys` size) at the moment players dismount, to separate "killed early" from "deleted early". Confidence: **medium**.

### E-04 — `coop_updateSpawn6` is orphaned → all players respawn on the minesweeper tank for the entire hideout + escape
**Files:** `maps/e1l2.scr:330-334` (definition) and `spawnlocations.scr:2309-2328` (`e1l2_update5`), `2332-2338` (`e1l2_update6`).

**Verified:** grep shows `coop_updateSpawn6` is **defined but never `thread`ed** anywhere (only self-references at `e1l2.scr:330,332`); `e1l2_update6` is reachable ONLY through it. Meanwhile `coop_updateSpawn5` IS threaded (`e1l2.scr:313`) and runs `e1l2_update5`, whose loop
```
while($coop_tank2PlayerSpawn != NULL && $tank2 != NULL){ ... pin all 8 spawns to the tank lantern ... }
```
never terminates: `$coop_tank2PlayerSpawn` (the lantern spawned at `e1l2.scr:62`) is **never removed**, and `$tank2` is only `hide`/`show`n (`Crab.scr:199`, `Hideout.scr:253`), **never deleted**. So both conditions stay true forever.

**Effect:** Through the whole bunker/hideout fight and the escape, all players respawn on top of `tank2` (parked at the post-repair rendezvous), often far from the interior fight; and `level.coop_disableSpawnWarper` (set `game.true` at `e1l2.scr:24`) is **never reset to `game.false`** — the only place that does it is `e1l2_update6:2335`, which never runs. The intended "respawn near hideout / where you died" handoff never activates. Always happens, every coop game.

**Fix:** `thread coop_updateSpawn6` at the hideout handoff (e.g. end of `Crab.scr::CleanupCrab` or `Hideout.scr::DoHideoutIntro`) and give `e1l2_update5`'s loop an exit flag (or test `level.crabdead`) so it stops pinning to the tank. Mirrors the existing `update1→2→3→4→5` chaining. Confidence: **high**.

---

## INVISIBLE WALLS section (every clip / trigger-wall on e1l2)

| Wall | Type / where | Extent | SP purpose | Coop verdict | Recommendation |
|------|--------------|--------|------------|--------------|----------------|
| **clip1–clip9** | Script-spawned solid `script_object` in `e1l2.scr::InitLevel` (`149-209`) | ~608u-tall slab spanning x≈3600–5450, y≈950–1520 (near jeep-intro / parade approach) | `[200]` dev-patch to plug an OOB gap; intro glues the SP player to the jeep anyway | **Removed in coop** — `Intro.scr::playerExitTank:1369-1376` deletes `clip1`–`clip9` for SP and coop (bug-624 fix). Residual: removal lives inside `playerExitTank`, so if the intro stalls (E-10) the walls persist = the reported "random invisible walls" return | **KEEP the removal**; harden by also removing them on the E-10 watchdog so a stalled intro can't leave them up. Do NOT gate the spawn out entirely (they plug a real OOB gap during the on-rails intro). |
| **`$deadend`** | Map entity, `hide`+`notsolid` at `Hideout.scr:27-30`, then `show`+`solid` at `Hideout.scr:351-354` after the magazine charge is set | One-way backtrack blocker at the bunker | Stops the lone SP player backtracking after the charge | **Coop hazard (P3):** a straggler still behind the line when it seals is walled off; must die/respawn to progress | **COOP-GATE:** leave `$deadend notsolid` in coop, or delay the seal until all live players are past (`withinDistanceOf` loop). |
| **`$opendoordoor`** (3× `func_rotatingdoor`) | Map entity; `unlock` at `Hideout.scr:456`, `lock` at `:463` after `$deletetrigger4` fires | Exit doors from the munitions bunker | Re-locks behind the lone player after they exit | **Coop hazard (P2, E-08):** `$deletetrigger4` is a `trigger_multiple` firing on the FIRST player; the re-lock then seals a lagging player inside the bunker seconds before the finale `radiusdamage 4000/600` (`Hideout.scr::ChainExplosion`) → trapped + likely killed. Compounds E-01. | **COOP-GATE or REMOVE the re-lock:** only lock once no live player remains bunker-side (`while(withinDistanceOf $opendoordoor <r>) waitframe` before `lock`), or drop the re-lock (the finale destroys the area anyway). |
| **30× `trigger_hurt` (impale)** | Map entities; ALL 30 are `damagetype "impale"` (instant kill), at ledges/trenches/OOB edges around the minefield & artillery | Instant-death planes | The rail-bound SP player never enters them | **Coop hazard (P2, E-12):** coop players free-roam off the escort line and hit these with no visual cue = "arbitrary death wall"; and an impale death right by the minefield compounds with respawn-placement (E-04) | **AUDIT & shrink:** verify none overlap a legitimate coop path or a coop spawn/warp origin (`e1l2_update2..6`); shrink/soft-push any that do. Start with the ~6 near the artillery/minefield. |

No `trigger_push`, `func_barrier`, or other barrier classes exist in the entity file — the four rows above are the complete inventory of walls/hurt-volumes on e1l2. The only script-spawned solids are `clip1`–`clip9`.

---

## Fix-priority queue
1. **E-01** (P0, 1-char) — unblocks level completion. Do first.
2. **E-02 → E-03** (P1) — one fix (pin the MG gunner) addresses both the friendly-fire and the "missing artillery defenders" symptoms; confirm with a runtime actor count.
3. **E-04** (P1) — thread `coop_updateSpawn6` + terminate the `e1l2_update5` loop.
4. **E-06, E-07, E-08** (P2, all one-liners) — quick, safe correctness wins.
5. Remaining P2/P3 as capacity allows; E-16/E-24 are dev-gated landmines (safe while hack flags `=0`).
