# OwN-3m-All Push / "King of the Map" — real mechanic (decoded from the shipped mod)

Source: `own3mall_push_mod.zip` (257,309 bytes, SHA256 c60d100775…5dcb; storage.moh-db.com mirror), pulled
2026-09-17 with the user's permission. Contains `zZzZzZz_kingofmap_push.pk3` + `push.cfg`. No executable.
Built on ViPER's Gain Ground; released 11/19/2013 for Reborn 1.12. Credit OwN-3m-All + ViPER in any port.
Raw scripts kept in the session scratchpad (`push_mod/extracted/`), NOT committed (downloaded content).

## The mode in one paragraph
A **moving battle line** on a linear SP-map corridor. Each team has an ORDERED set of spawn points laid along
the corridor: allies `alh,al2..al9`, axis `axh,ax2..ax9` (`h` = home). A per-team index — `level.sflag`
(allies) / `level.sflagx` (axis) — is where that team currently spawns. Big `trigger_multipleall` zone volumes
`sptrg1..sptrgN` (allies) and `sptrg1x..sptrgNx` (axis) span the corridor at each checkpoint; when a player of
the right team stands in the **next-forward** zone, that team's index advances and its spawns relocate forward
(the enemy's effectively pushed back). Reach the enemy's END zone (`endtrgal`/`endtrgax`) and your team scores
a point + you're teleported back. Both teams push the SAME corridor from opposite ends — genuine tug-of-war.
Win by score at `timelimit` (push.cfg: timelimit 15, fraglimit 0). This is progress-by-PRESENCE/reaching, NOT
hold-over-time — which is the correction the user asked for vs. our current `mp_push.scr` (banks seconds while
sole attacker holds one point).

## The pieces (per-map script, e.g. maps/m1l2b.scr, ~1900 lines)
- `setup:` — enable home spawns (`$axh/$alh enablespawn`), disable all forward ones; `level.alliesscore=0`,
  `level.axisscore=0`, `level.sflag=1`, `level.sflagx=1`.
- `triggers:` — spawns every `sptrgN`/`sptrgNx` zone volume (hand-authored origin+setsize per map) and the two
  end zones `endtrgal`/`endtrgax`; then `thread pushtrgcheck2 / pushtrgcheck2x` (if `push==1`), `endtriggeral`,
  `endtriggerax`, `triggerstart`.
- `pushtrgcheckN:` (chain) — `$sptrgN waittill trigger; if(parm.other.dmteam==allies){ level.sflag=N; goto
  pushtrgcheck(N+1) } else { level.sflag=(N-1); wait 1; goto pushtrgcheckN }`. The else-branch REGRESSION is
  the tug-of-war: the line falls back when the forward zone isn't held. Mirror `…x` chain for axis.
- `spawnswitch:` — `while(1){ switch(level.sflag){ case N: enable $al(N-1),$alN; disable the rest; set the HUD
  battle-line markers (huddraw 220-227) } … }`. Same for `sflagx` on the axis spawns. This is what makes spawns
  crawl across the map as the index climbs.
- `endtriggeral:` / `endtriggerax:` — `$endtrgal waittill trigger; if allies: alliesscore++; Scorethread;
  iprintlnbold "Allies Score!"; teleport the scorer home`.
- `Scorethread:` — writes `g_obj_alliedtext3`/`g_obj_axistext*` (scoreboard objective text) + the huddraw score.
- `hudstuff:` — the "Gain Ground" HUD, per-team point totals, battle-line strip.
- helpers `global/push_spawn.scr::main x y z angle targName type` (spawns one info_player_*), and
  `global/trigger.scr::main x1 y1 z1 x2 y2 z2 name` (spawns a sized trigger; also drops the colored corona
  checkpoint markers when `showPushMarkers 1`).

## Maps shipped (push.cfg maplist): m3l3 m2l1 m1l2b m4l1 m5l1a m4l2 m5l1b (7 SP→MP corridors).

## Why the user's "the gate isn't opened, can't go anywhere" happens
The original per-map scripts ARE the full converted SP map (note m1l2b.scr's `gatecrash`, `opentruck0*`,
`activate_smoker_sequence`, tank/crate threads…) — they keep the SP map's own door/gate/sequence scripting so
the corridor is actually traversable end-to-end. Our force-arena reuse loads these maps through a generic MP
path that never runs that SP door-opening, so gates stay shut. A faithful port needs either (a) each corridor's
gates forced open at setup, or (b) checkpoint placement that stays within the reachable area.

## Port decisions for HZM (MP-only, coop-safe — all in mp_push*.scr, gated coop_mpRun)
1. Replace the hold-over-time capture in `mp_push.scr` with the battle-line model: per-team index +
   presence-advance/regress on ordered checkpoints; spawns relocate to the index.
2. Author per-map checkpoint + spawn data. Cheapest: transcribe the original's exact `sptrgN` volumes and
   `al*/ax*` spawn origins for the 7 shipped maps (they're in the extracted map scripts) into our generated
   per-map data table (like `mp_push_maps.scr` / `gen_push_maps.py`), crediting the authors.
3. Gate handling: force the SP corridor's gates open on push setup per map (the (a) option), or clamp
   checkpoints to reachable space.
4. Keep our modern HUD + the Phase-6 bot director pointed at the current battle-line zone.
