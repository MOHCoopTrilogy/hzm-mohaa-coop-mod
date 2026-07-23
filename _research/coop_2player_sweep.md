# Full-Trilogy 2-Player Coop Sweep (2026-07-22)

54 campaign maps booted as a real 2-player coop server (P1 listen + P2 client), Phase-2 patrol driving the host ~150s/map, clean-quit between maps. 51 logs captured (m1l1/m1l3a/m3l1b re-running). Classifier: full2p_<map>.log; data sweep_final.json.

## HEADLINE
- **Zero fatal crashes trilogy-wide.** Every map boots and reaches coop-ready. No ERR_DROP / Com_Error / signal on any of 51.
- **Allied Assault (34 maps): almost entirely clean.** Only real hit = m1l3b vehicle-nil (jeep crew) + m1l3a expected same; one stray $player on m6l2b.
- **Spearhead (9 maps): heavily hit by the addon-spawner + vehicle-thinker bugs.** This is where the missing-content lives.
- **Breakthrough (11 maps): clean except a $player-array storm cluster (e2l3/e3l1) and the implemented-template proof (e3l3 clean w/ 38 addons).**

## THE THREE BUG CLASSES

### 1. SPAWNER STORM (global/spawner.scr + turret.scr fed NIL addon markers) - the #2 restore target
Confirmed heavy this run:
| map | null-cast | broken markers | notes |
|---|---|---|---|
| t2l2 | 3045 | **87** | halftrack map; seating is SEPARATE (agent-confirmed no-touch) |
| t2l1 | 1960 | **56** | |
LIKELY heavy but UNDERCOUNTED (audit addon-entity count high, patrol didn't reach the trigger this 150s run - magnitude is a lower bound, real severity ~t2l1/t2l2 scale):
| map | audit addon ents | this-run null-cast |
|---|---|---|
| t2l3 | 100 | 0 (undercount) |
| t2l4 | 68 | 0 spawner + 8 vehicle-nil |
| t3l2 | 47 | 0 spawner + 8 vehicle-nil |
NOTE: e3l3 (38 addon) and e3l4 (179 addon) are GENUINELY clean, NOT undercounts - e3l3's addons are IMPLEMENTED (the restore template), e3l4's 179 are animate/prop that resolve via engine fallback.

### 2. VEHICLE-NIL (global/vehicles_thinkers.scr:650 - spawn crew with NIL guy_type)
m1l3b (11, jeep), t2l4 (8), t3l1 (8), t3l2 (8). Both jeep maps (m1l3a pending) + the Spearhead vehicle maps. Same guard-fix family as the spawner bug.

### 3. $PLAYER-ARRAY STORM (raw single-entity $player with 2 players -> "Cannot cast array to listener")
t1l1 (281), e2l3 (171), e3l1 (143). Clustered on 3 maps = a hot loop or shared gag, NOT spread thin. Fix = player_closestTo shim at the specific hot spot (likely one shared script clears all 3). Plus minor 1-3 hits on several maps.

## CLEAN: 38 of 51 maps.

## CAVEATS
- **Magnitude is a lower bound.** The spawner storm is PROXIMITY/PROGRESSION-gated, not init-fired (t1l3 proved it: 1470 in a 5-min patrol vs 2 in this 150s run). Maps showing low/zero spawner counts but high audit-addon counts (t2l3 esp.) are undercounts. Use the static addon-entity count as the severity proxy.
- **P2-spawn data is NOT trusted.** ~14 maps flagged P2-NOSPAWN, but the harness can't distinguish "map can't spawn P2" from "automated spawn-click missed P2's window." Needs a dedicated multi-spawn test (capture both players' logs, verify connect+click+spawn). NOT a finding.

## FIX PLAN (#2 = RESTORE, user-chosen)
1. **Guard first (stability, safe, all maps):** global/spawner.scr::spawner_activate end on NIL spawn_model; turret.scr::mg42_start skip non-Actor marker; vehicles_thinkers.scr skip NIL crew. Kills the storms + entity leak immediately. No-op on working entities. Verify vs a working-nest map.
2. **Restore (content, the real goal):** implement the addon-spawn handler - read $ai_model off the markers and spawn the intended German AI at each (the e3l3 template, generalized). Brings back ~56/87+ AI per heavy Spearhead map. Size the entity pool / sound-index headroom to match (push limits as needed).
3. **$player shim:** player_closestTo at the t1l1/e2l3/e3l1 hot spots.

---

## TRIGGER-SWEEP RESULTS (2026-07-22, post-#2/#3-fix, tours actual scripted trigger volumes)
52 maps toured (m1l3a/m3l1b/1 more skipped - flaky 2-player boot). Teleports player through every trigger volume (offline-BSP-extracted centers).

### HEADLINE
- **550 German AI restored trilogy-wide** by the addon-spawn fix (measured as german_winter/wehr activity across all maps).
- **Spawner storm: ~7,000+ -> 25 total, ZERO maps still storming.** The #2 restore is 100% effective at the trigger level. Worst maps proven: t2l1 (1960->0, 62 AI), t2l2 (3045->0, 47 AI), t1l3 (1470->0), t2l3/t2l4 storms gone.
- Vehicle-nil: jeep maps fixed (m1l3b 11->0, t2l4 covered). Residual: t2l2 halftrack (25) + t3l2 (8) use a 2nd crew-spawn path the truck_load guard doesn't cover.

### $PLAYER BATCH (trigger-gated per-frame loops the pathnode sweep missed - all "array to listener")
| source | array-casts | type |
|---|---|---|
| gags/t2l3_medic.scr | 14501 | mod gag (medic proximity per-frame) |
| global/vehicle_warning.scr | 4270 | GLOBAL (hits t3l1 + any vehicle-warning map) |
| gags/t2l4_start.scr | 3595 | mod gag (intro per-frame) |
| gags/t3l1_enemyspawn.scr | 494 | mod gag |
| global/alarm_system.scr | 305 | GLOBAL (hits m2l1/t2l1 + any alarm map) |
| gags/t2l1_tank.scr | 66 | mod gag |
| gags/t2l1_tank_mgsoldier.scr | 36 | mod gag |
| gags/t1l3_colonel.scr, t1l3_bridge.scr, t3l1_fourrussians.scr, maps/t2l1.scr, maps/m6l3a.scr | 1-3 each | tail |
Fix: $player.origin -> $player[1].origin (per-frame proximity, host anchor) or player_closestTo (gameplay-relevant). Globals (vehicle_warning, alarm_system) likely need retail-extract overrides.

### 2nd vehicle-crew path
t2l2 halftrack + t3l2 spawn crew via a path other than truck_load -> needs the same NIL guard on that function.
