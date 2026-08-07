# Raw `level waittill` race risk (2026-08-05 sweep)

m2l2a proved this is not theoretical: its main thread died on BOTH raw waittills and no player could
spawn (bug-1458). The failure needs the script to YIELD before the waittill - each yield gives the
engine a chance to fire the event first, and a waittill for a past event throws and kills the thread.
Every coop map's mandatory `waitthread coop_mod/main.scr::main` is discounted as baseline (it is
documented to complete in a single frame). Fix = replace with coop_mod/replace.scr::waitTillPrespawn
/ ::waitTillSpawn, the project's own SP->MP shims.

| extra yields | line | map | waittill |
|---:|---:|---|---|
| 45 | 806 | m1l3b | spawn |
| 25 | 329 | e1l1 | prespawn |
| 22 | 563 | m5l2b | spawn |
| 21 | 324 | M1L3a | spawn |
| 17 | 187 | e1l3 | spawn |
| 8 | 67 | e2l3 | spawn |
| 5 | 116 | m1l1 | spawn |
| 5 | 32 | m2l2b | spawn |
| 4 | 81 | m5l1a | spawn |
| 3 | 52 | e2l3 | prespawn |
| 3 | 41 | m6l3b | spawn |
| 3 | 26 | m2l2b | prespawn |
| 1 | 70 | m6l2b | spawn |
| 1 | 44 | e2l2 | spawn |
| 1 | 42 | e2l2 | prespawn |
| 1 | 29 | e1l3 | prespawn |
| 1 | 25 | e3l2 | prespawn |
| 1 | 22 | e3l4 | prespawn |
| 1 | 17 | e3l3 | prespawn |

**19 at-risk sites** across 15 maps.
Top of the list is where the window is widest; m1l1's `spawn` (6 extra yields) still wins its race
today, which shows the threshold is timing, not a hard count - more players and bigger asset packs
push more of these over the edge.
