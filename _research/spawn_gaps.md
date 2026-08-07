# Coop spawn-point gaps (regenerated 2026-08-06, full 54-map trilogy)

Source: `coop_mod/spawnlocations.scr`, all three authoring styles handled (quoted-string keys,
bare-identifier keys, and the `for(local.i=1;local.i<=N;local.i++)` loop-built style). A **set**
writes `level.flags[coop_spawnNorigin/angles]`; more than one set (`<map>_update2`, `_update3`...)
means the squad's respawn point ADVANCES as the mission progresses. Every listed map still plays -
the fallback is the map's own default `info_player_start` - but with 4 players that means
telefragging at one point and, worse, a mid-map death sending you back to the level entrance.

**Corrects the 2026-08-05 version of this file**, which only scanned m-series + a handful of e-maps
and had zero t-series (Spearhead) coverage at all - it undercounted the real gap by 9 maps.

## A. Completely empty - genuine gap (10 maps)
The block exists but is a literal empty stub, `{ }end` - not even the fallback engine start is
customized. All 4 players land on whatever `info_player_start` the map author placed, at one point,
for the entire mission.

| map | note |
|---|---|
| t1l1 | Spearhead - block is a bare `{ }end`, same for every t-series map below |
| t1l2 | |
| t1l3 | |
| t2l1 | |
| t2l2 | |
| t2l3 | |
| t2l4 | |
| t3l1 | |
| t3l2 | |
| m3l1b | |

## A2. Intentionally not using this system (1 map) - not a gap
| map | note |
|---|---|
| m6l3a | armored train - `//moving train` comment; per-frame train-pinned spawn flags (bug-1438) handle this instead |

## B. Single set only - no mid-level advance (16 maps)
8 slots authored (fine for 4 players landing together), but the respawn point never moves as the
mission progresses - a death halfway through sends you back to the start.

| map | slots |
|---|---|
| e3l1 | 8 |
| e3l2 | 8 |
| e3l3 | 8 |
| e3l4 | 8 (campaign version; the arena/holdout variant has its own authored spawns) |
| m1l3a | 8 (sibling of m1l3b, same jeep-ride pattern) |
| m1l3b | 8 (jeep ride - uses its own coopPlayerRespawn warp on top of this) |
| m2l2a | 8 |
| m5l2a | 8 |
| m5l2b | 8 |
| m6l1a | 8 |
| m6l1b | 8 |
| m6l1c | 8 |
| m6l2a | 8 |
| m6l2b | 8 |
| m6l3b | 8 |
| m6l3d | 8 |
| m6l3e | 8 |

## B2. Single set with a defect - only 1 of 8 slots actually usable (1 map)
| map | issue |
|---|---|
| m5l3 | `coop_spawn1origin` is set, but `coop_spawn2origin` through `coop_spawn8origin` are MISSING - only their `angles` counterparts exist (copy-paste dropped the origin line 7 times). All 4 players will stack on slot 1. |

## C. Fewer than 8 slots authored
None found - every map that authors spawns authors 8 (or the loop-style maps build exactly 8 via `local.i<=8`).

## Healthy - multiple sets, mid-level advance (26 maps)
| map | sets | max slots |
|---|---:|---:|
| e1l1 | 12 | 8 |
| e1l3 | 12 | 8 |
| e1l4 | 11 | 8 |
| m6l3c | 9 | 8 |
| e1l2 | 7 | 8 |
| e2l2 | 7 | 8 |
| e2l3 | 6 | 8 |
| m2l1 | 6 | 8 |
| m3l3 | 6 | 8 |
| m4l2 | 6 | 8 |
| e2l1 | 5 | 8 |
| m1l2a | 5 | 8 |
| m1l1 | 4 | 8 |
| m1l2b | 4 | 8 |
| m1l3c | 4 | 8 |
| m2l3 | 4 | 8 |
| m4l0 | 4 | 8 |
| m4l1 | 4 | 8 |
| m4l3 | 4 | 8 |
| m5l1b | 4 | 8 |
| m5l1a | 3 | 8 |
| m2l2b | 2 | 8 |
| m2l2c | 2 | 8 |
| m3l1a | 2 | 8 |
| m3l2 | 2 | 8 |
| co_lobby1 | - | 8 (pre-mission lobby anchor, not a mission map) |

e1l1/e1l3 lead with 12 sets each - the model to copy for any map getting new mid-level spawns.
