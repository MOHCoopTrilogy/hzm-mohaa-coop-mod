# Objective Toast Audit - m-series (m1l1 .. m6l3e) [user 2026-08-09]

Scanner output for the pre-player add_objectives defect class (found live on m2l2b/m2l2a).
Ground truth used for classification:

- `global/objectives.scr::add_objectives` (line 43-45): toasts via
  `coop_mod/objectives.scr::coop_obj_toast_all` ONLY when status == 2. Status 1 (hidden) and
  status 3 (complete) never toast. `current_objectives` never toasts.
- `coop_mod/objectives.scr::coop_obj_toast_all` (line 679-692): early-exits when
  `$player.size < 1`. Keyed per index per player, so a later same-index status-2 re-add
  updates quietly ONLY if a player already received the first toast; if the first add fired
  into an empty server, no key was set and the next status-2 re-add announces normally.
- `coop_mod/replace.scr::waitForPlayer` (line 99): the ONLY shim that blocks until a player
  exists.
- **`waitTillSpawn` does NOT wait for players**: `$coop_levelWaitTillSpawn` is triggered from
  `coop_mod/player.scr::manage` startup (player.scr lines 36-38) during map-load init, before
  any client connects. A map that "waits" with waitTillSpawn and then adds objectives is
  still pre-player. Same for a raw `level waittill spawn`.

Classification: OK / PARTIAL / BROKEN / N/A per the task rubric. Line numbers verified
2026-08-09 against the working tree.

Reference implementations (do not touch): `maps/m2l2a.scr` (coop_objToastStart label at 498,
gated mid-transition toasts at 421 and 435), `maps/m2l2b.scr` (start toast inside the enigma
prop thread at 1439-1446, explicit toasts at 1045, 1057, 1155).

---

## Summary

| Map | Class | Player-wait before adds | Start toast | Mid-mission toasts |
|---|---|---|---|---|
| m1l1 | OK | waitForPlayer :299 | yes (state machine post-player) | yes (status-2 re-adds) |
| m1l2a | PARTIAL | none (raw waittill spawn :118) | **missing obj1** | yes (status-2 re-adds) |
| m1l2b | OK | waitForPlayer :52 | yes | yes |
| M1L3a | BROKEN | waitTillSpawn :138 (no player wait) | **missing (only obj)** | none exist |
| m1l3b | OK | waitForPlayer :117 | yes | yes (same-index updates) |
| M1L3c | PARTIAL | adds threaded before waitForPlayer :63 | **missing obj1** | yes (status-2 re-adds) |
| m2l1 | OK | waitForPlayer :55 | yes (burst of 3) | quiet by design, all announced at start |
| m2l2a | OK (ref) | fixed | wired :498 | wired :421 :435 |
| m2l2b | OK (ref) | fixed | wired :1444 | wired :1045 :1057 :1155 |
| m2l2c | BROKEN | none (raw waittill spawn :18) | **missing (only obj)** | none exist |
| m2l3 | OK | waitForPlayer :26 | yes | yes (2:2 at :550) |
| m3l1a | OK | waitForPlayer :237 | yes (1:2 at :2290 post-player) | yes (all 7 objs status-2) |
| m3l1b | PARTIAL | none (raw waittill spawn :63) | **missing obj1** | yes (status-2 re-adds) |
| m3l2 | OK | waitForPlayer :162 | yes | yes (objs 2-9 status-2) |
| M3L3 | PARTIAL | none (waitForPlayer commented :149) | **missing obj1** | first NW kill announces late |
| m4l0 | BROKEN | none (raw waittill spawn :46) | **missing obj1** | **obj2 transition untoasted** |
| m4l1 | OK | waitForPlayer :88 | yes | yes |
| m4l2 | OK | waitForPlayer :54 | yes | yes (objs 2-7 status-2) |
| m4l3 | OK | waitForPlayer :63 | yes | yes (objs 2-6 status-2) |
| m5l1a | PARTIAL | none (raw waittill spawn :82) | **missing obj1** | yes (2:2/3:2 re-adds) |
| m5l1b | OK | waitForPlayer :44 | yes (burst of 4) | quiet by design, all announced at start |
| M5L2A | BROKEN | none (raw waitTill spawn :101) | **missing (only obj)** | none exist |
| m5l2b | BROKEN | none (raw waitTill spawn :177) | **missing (only obj)** | none exist |
| m5l3 | OK | waitForPlayer :124 | yes (burst of 3) | yes (4:2 at :580) |
| m6l1a | OK | waitForPlayer :32 | yes | yes (count updates) |
| M6L1b | OK | waitForPlayer :32 | yes | complete-only, both announced at start |
| m6l1c | OK | waitForPlayer :39 | yes (burst of 5, :97 -> :413-417) | complete-only, all announced at start |
| m6l2a | OK | waitForPlayer :94 | yes | yes (2:2 at :283) |
| m6l2b | BROKEN | none (raw waittill spawn :71) | **missing all 3** | **none - zero status-2 re-adds** |
| m6l3a | OK | waitForPlayer :296 | yes | yes (objs 2-5 status-2) |
| m6l3b | PARTIAL | waitTillSpawn :42 (no player wait) | **missing obj1** | yes (2:2 at :141) |
| m6l3c | BROKEN | adds threaded before waitForPlayer :49 | **missing (only obj)** | none exist (obj never even completes) |
| m6l3d | OK | waitForPlayer :34 | yes (burst of 3) | yes (status-2 re-adds) |
| m6l3e | BROKEN | adds threaded before waitForPlayer :66 | **missing (only obj)** | complete-only :130 |

Counts: 20 OK, 6 PARTIAL, 8 BROKEN, 0 N/A. All 34 m-series maps are coop-integrated and
have objectives.

---

## Per-map evidence

### m1l1 - OK
All adds run through the `completedobjective` state machine (m1l1.scr:2002), keyed on
`$world.objs`. First invocation: main threads the intro at :330 (AFTER waitForPlayer :299)
-> `scenestart` :915 -> `thread scene1` :1115 -> `objectives` :2150 -> `thread
completedobjective` :2152. Every later call is from a mid-mission trigger (:2406, :2440,
:2612, :2661, :2827, :2892, :2911). Status-2 adds therefore always run with players present
and the add_objectives hook toasts them.

Objectives: 1 "Infiltrate the German occupied village." (2 at :2011, 3 at :2019);
2 "Check the door." (2 at :2028, 3 at :2037); 3 "Man the MG42 mounted machine gun."
(2 at :1954 inside spawndoorguy :1901, 3 at :2047); 4 "Hold off the reinforcements."
(2 at :2048, 3 at :2056); 5 "Continue on your mission." (2 at :2057, 3 at :2066).

### m1l2a - PARTIAL
Adds-at-load path: main has raw `level waittill spawn` :118 (no waitForPlayer anywhere in
main), then `thread objectives` :175 -> objectives :433 adds 1:2 "Find and rescue the SAS
Agent." :435 pre-player. Toast void.

Mid-mission transitions all carry their own status-2 add (toast fires via hook):
- :776-781 (ossdoor block, label :741): 1:3, 2:2 "Follow the SAS Agent.", current 2
- :2333-2335 (flagthread19): 2:2, 3:2 "Steal explosives from the fortress.", current 2
- :1774-1793 (flagthread7): 2:3 then conditional 3:2 / 4:2 / 5:2 / 6:2
- :3224-3227 (gotexplosives): 3:3, 4:2 "Use explosives to escape."
- :3057-3060, :3071-3074 (explosives): 4:3 + 5:2 "Use explosives to destroy a Flak88.";
  5:3 + 6:2 "Meet Grillo by the gate and exfiltrate."
- :3925 (endtrigger): 6:3

Dead code note for the fixer: `papersthread:` :1674 is immediately followed by `end` :1675;
the untoasted `current_objectives 3/4/5/6` block at :1699-1722 is unreachable. Do not "fix"
it.

MISSING: start toast only. Fix = m2l2a coop_objToastStart recipe threaded from main:
waitForPlayer -> wait 2 -> `coop_obj_toast_all 1 "Find and rescue the SAS Agent."`.

### m1l2b - OK
waitForPlayer :52, then adds 1:2/2:2/3:2/4:2 at :60-63 + current 1 :64 with players
present -> all four toast at start. Every transition re-adds status 2 (:467-:502 truck
counts, :522-:588 tank counts, :657 obj4 re-add at jeep sequence) or completes (:448, :507,
:593, :914).

### M1L3a - BROKEN
Single objective. main: waitTillSpawn :138 (NOT a player wait - see ground truth above),
then 1:2 "Reach the airfield." :156 + current 1 :157 pre-player -> toast void.
`objective1` :316 completes 1:3 :318. No status-2 re-add exists, so this map never shows a
single objective card in coop.

Fix: coop_objToastStart recipe -> `coop_obj_toast_all 1 "Reach the airfield."`.

### m1l3b - OK
waitForPlayer :117, then MP-branch add 1:2 (variable text local.obj_text) :155 + current 1
:156 post-player -> toasts. plane_exploded re-adds same index (1:2 :723, 1:3 :725) = quiet
update then complete. Single-objective map, announced at start.

### M1L3c - PARTIAL
main: `thread level_setup` :60 runs BEFORE waitForPlayer :63; level_setup -> `thread
objectives` :100 -> adds 1:2 "Destroy all communications equipment." :118, 2:2 "Make your
way to the lighthouse." :119, 3:2 "Signal the fleet with the lighthouse beacon." :120 +
current 1 :121, all pre-player -> toasts void.

Mid-mission transitions re-add status 2 (announce fine, keys were never set):
- objectiveupdate1 :128 -> 1:3 :130
- objectiveupdate2step :154 -> 2:2 :156 + current 2
- objectiveupdate2 :165 -> 2:2 :169 + current 2
- objectiveupdate3 :177 -> 2:3 :181, 3:2 :182 + current 3
- objectiveupdate4 :190 -> 3:3 :194, 4:2 "Meet up with Major Grillo in the truck and
  escape." :195 + current 4
- the_end :1003 -> 4:3 :1008

MISSING: start toast obj1. Fix = coop_objToastStart ->
`coop_obj_toast_all 1 "Destroy all communications equipment."`.

### m2l1 - OK
waitForPlayer :55, then adds 1:2 "Enter the complex with the assistance of Major Grillo."
:76, 2:2 level.objective2_text :77, 3:2 "Enter the main facility." :78 + current 1 :80,
post-player -> all three toast at start. Transitions are complete+current only (objective1
:96 -> 1:3 :99 current 2; objective3 :218 -> 2:3 :219 current 3, 3:3 :232) plus quiet
same-index count re-add 2:2 :183 - acceptable because every objective already announced at
start (matches SP behavior).

### m2l2a - OK (reference implementation)
coop_objToastStart :498-502 (waitForPlayer -> wait 2 -> toast 1 "Find a disguise."),
threaded from the MP add block :50. Gated toasts after transitions: :421 (toast 2 "Destroy
the Naxos Prototype.") and :435 (toast 3 "Enter the 2nd U-boat.").

### m2l2b - OK (reference implementation)
MP adds 1-4 at :24-28 pre-player by design; start toast lives in the enigma prop thread
:1439-1446 (waitForPlayer -> wait 2 -> toast 1 "Decrypt the Enigma."). Explicit toasts at
:1045 (2 "Steal the Enigma contents."), :1057 (3 "Plant the bombs."), :1155 (5 "Eliminate
the enemies and Exfiltrate."); obj4 escape toast via coop_obj_toast_all 4 at :367.

### m2l2c - BROKEN
Single objective. main: raw `level waittill spawn` :18 (no waitForPlayer in file), then
1:2 "Exfiltrate." :28 + current 1 :29 pre-player -> toast void. endlevelthread :115
completes 1:3 :117 + current 0 :118. No status-2 re-add -> never announces anything.

Fix: coop_objToastStart recipe -> `coop_obj_toast_all 1 "Exfiltrate."`.

### m2l3 - OK
waitForPlayer :26, then 1:2 "Exfiltrate the base." :36 (toasts) and 2:1 hidden "Meet up
with allies at train station." :37 + current 1 :38. objectiveupdate1 :546 -> 1:3 :549 +
2:2 :550 (toasts) + current 2 :551. objectiveupdate2 :554 completes both.

### m3l1a - OK
waitForPlayer :237 in main; boat ride threaded :263. Retail load-time adds are commented
out (:202-205). Every objective receives its status-2 add mid-mission with players present:
1:1 hidden :2256 then 1:2 :2290 (main_boat_ride) + current 1 :2293; 1:3 :4756; 2:2 :4807;
2:3 :4861; 3:2 :4892; 3:3 :3371; 4:2 :3372 (playeritem_bangalore_give); 5:2 :5257; 5:3
:5353; 6:2 :5481; 6:3 :3387 (enter_trench); 7:2 :3321 (mg42_bunker); 7:3 :3399 (end_level).

### m3l1b - PARTIAL
main: raw `level waittill spawn` :63, no waitForPlayer anywhere. Add 1:2 "Clear out the
bunker." :77 + current 1 :78 (and again :91) pre-player -> toast void. (Retail 4-objective
block :71-74 is commented out.)

Mid-mission status-2 adds announce fine: 2:2 "Eliminate the MG42 machine gunners." :1160
(seq_bunker_upper_start); 2:3 + 3:2 "Exit the bunker." :536-539
(beach_scene_targeting_done); 3:2 "Destroy the 2 FLAK 88 artillery emplacements" :2118
(coop_flak88_objective); 3:3 + 4:2 "Clear the backline of enemies." :2312-2316
(coop_flak88_complete); count updates 4:2 :2790; 4:3 :2812; repurpose 4:2 "Exit the
bunker." :2877 (quiet update - key already set by :2315, pre-existing design, not this
defect class); completes :765, :783, :798, :820.

MISSING: start toast obj1. Fix = coop_objToastStart ->
`coop_obj_toast_all 1 "Clear out the bunker."`.

### m3l2 - OK
waitForPlayer :162, then 1:2 "Search the house." :193 + current 1 :195 post-player ->
toasts. Objectives 2-9 all added status 2 mid-mission: 2:2 :631 (scene3), 3:2 :1004
(scene4), 4:2 :1314 (scene5_captain_speech), 5:2 :1532 / :1739, 6:2 :1552 / :1807, 7:2
:1968 (scene10_bomb_explodes), 8:2 :2867, 9:2 :2086 (scene13_bomb_explodes); completes
:516, :1002, :1313, :1531/:1550, :1551/:1806/:1813, :1965, :2084, :2384.

### M3L3 - PARTIAL
Single (count-updating) objective. main: raw `level waittill spawn` :148 with the
waitForPlayer alternative COMMENTED OUT :149; add 1:2 level.locationchecktext :301 +
current 1 :302 pre-player -> start toast void. Initial text set at :135:
"Locate and destroy the Nebelwerfers.    [4 remaining]" (level.scene7_bombcount = 4 :134).

scene7_bombtracker :5376 re-adds 1:2 with the decremented count after each nebelwerfer
(:5394, :5397, :5400, :5404) -> because no key was ever set, the FIRST kill announces the
objective (late); completes 1:3 :5382.

MISSING: start toast. Fix = coop_objToastStart ->
`coop_obj_toast_all 1 "Locate and destroy the Nebelwerfers.    [4 remaining]"` (match the
:135 string exactly so the index key lines up and later count re-adds stay quiet).

### m4l0 - BROKEN
main: raw `level waittill spawn` :46, no waitForPlayer. Adds :81-84 pre-player: 1:2 "Find
allied soldiers.", 2:2 "Take secret German documents.", 3:1 hidden "Exfiltrate." + current
1 -> obj1 AND obj2 toasts void.

Transitions:
- enemythread1 :338 -> 1:3 :340 only; its `current_objectives 2` and 2:2 re-add are
  commented (:341-342) -> obj2 is NEVER announced.
- objective2 :354 -> 2:3 :356, current 3 :357, 3:2 "Exfiltrate." :358 -> obj3 toasts.
- objective3 :398 -> 3:3 :400.

Fix (two pieces, both m2l2a recipe): coop_objToastStart ->
`coop_obj_toast_all 1 "Find allied soldiers."`; plus one gated line after :340 in
enemythread1: `if( level.gametype != 0 ){ waitthread coop_mod/objectives.scr::coop_obj_toast_all 2 "Take secret German documents." }`.

### m4l1 - OK
waitForPlayer :88, then 1:2 "Locate the downed G3 pilot." :94 and 2:2 "Escort the pilot to
the Maquis hideout." :95 + current 1 :96 post-player -> both toast at start.
pilot_waittill_rescue :271 -> 1:3 + current 2 (obj2 already announced). altar_think :567
re-adds 2:2 (quiet update). endlevel :622 -> 2:3.

### m4l2 - OK
waitForPlayer :54, then 1:2 "Infiltrate the tank park." :148 + current 1 :149 post-player.
All later objectives added status 2 mid-mission: 2:2 :272 (obj1_complete), counts :442-476,
3:2 :493 / 4:2 :496 (obj2or4), 5:2 :300 (obj4_complete), 6:2 :507 / 7:2 :510 (obj5or7);
completes :271, :481, :289, :299, :318, :335, :344.

### m4l3 - OK
waitForPlayer :63, then 1:2 "Infiltrate the perimeter." :91 + current 1 :92 post-player.
objective1_complete :1050 -> 1:3 :1053 + 2:2 :1055 + 3:2 :1056 + 4:2 :1057 (+ current 2
:1059) -> triple toast. objective5_add :1201 -> 5:2 :1209. check_current_objective :1137 /
cheatend :1178 -> 6:2 :1156 / :1180 "Escape and meet up with Manon." Completes :1077,
:1093, :1111, :1126, :1253.

### m5l1a - PARTIAL
main: raw `level waittill spawn` :82, no waitForPlayer; `thread objectives` :180 ->
objectives :211 adds 1:2 "Locate the bazooka team." :213, 2:2 "Get past the gate into the
rest of the town." :214, 3:2 "Proceed to the south edge of town." :215 + current 1 :216,
pre-player -> all void.

Mid-mission: bazookathread :1458 -> 1:3 :1486 + 2:2 :1487 + 3:2 :1488 + current 2 :1489
(obj2+obj3 announce); throughgate :1602 -> 2:3 :1616 + 3:2 :1617 + current 3 :1618;
endlevel :314 -> 3:3 :321 (also :1628).

MISSING: start toast obj1. Fix = coop_objToastStart ->
`coop_obj_toast_all 1 "Locate the bazooka team."`.

### m5l1b - OK
waitForPlayer :44, then adds 1:2 "Find the tank crew." :130, 2:2 "Defeat the Panzer tank."
:131, 3:2 "Keep the tank crew alive and infiltrate city hall." :132, 4:2 "Steal the King
Tiger with the tank crew." :133 + current 1 :134 post-player -> all four toast at start.
Transitions are complete+current only (newobjective :798-807 switcher; 2:3 :872; 1:3 :954;
3:3 :990; 4:3 :1099) - fine, everything announced at start. Quirk: 5:3 :1102 completes an
obj5 that was never added active (retail leftover, no coop action).

### M5L2A - BROKEN
Single objective. Raw `level waitTill spawn` :101 (no waitForPlayer), then 1:2 "Escape
with the King Tiger tank." :115 + current 1 :116 pre-player -> void. level_end :521 ->
1:3 :543. No re-add -> never announces.

Fix: coop_objToastStart -> `coop_obj_toast_all 1 "Escape with the King Tiger tank."`.

### m5l2b - BROKEN
Identical twin of M5L2A: raw `level waitTill spawn` :177, 1:2 "Escape with the King Tiger
tank." :199 + current 1 :200 pre-player; level_end :430 -> 1:3 :447. Never announces.

Fix: coop_objToastStart -> `coop_obj_toast_all 1 "Escape with the King Tiger tank."`.

### m5l3 - OK
waitForPlayer :124, then `thread objectives` :126 post-player -> objectives :201 adds 1:2
"Sneak in and find a high position overlooking the bridge." :202, 2:2 "Snipe the Germans
that try to blow up the bridge." :203, 3:2 "Use high vantage points to call in artillery
strikes on all approaches to the bridge." :204 (toast burst) + 4:1 hidden :205 + current 1
:206. objgen :389 does its own waitForPlayer :414 before 1:3 :450 + current 2 :454.
4:2 "Destroy the enemy King Tiger." :580 mid-mission -> toasts. Completes :1129, :579,
:645.

### m6l1a - OK
waitForPlayer :32, then 1:2 "Find and destroy the 20mm Flaks.         [2 remaining]" :44
and 2:2 "Keep tracking towards the rally point." :45 + current 1 :48 post-player -> both
toast. Count updates / completes: :77-83, :97-103, 2:3 :160.

### M6L1b - OK
waitForPlayer :32, then 1:2 "Find and destroy the 20mm Flak." :39 and 2:2 "Keep tracking
towards the rally point in the nearby town." :40 + current 1 :43 post-player -> both toast.
Completes 1:3 :68 (+ current 2 :69), 2:3 :140.

### m6l1c - OK
waitForPlayer :39; main threads giveobjectives :97 (post-player) -> adds 1:2..5:2 :413-417
+ current 1 :418 -> all five toast at start. Transitions complete+current only
(soldierchatsequence 1:3 :559 current 2; blueprintobj 2:3 :952; stealtheguns 3:3 :938 +
current :942/:945; setusupthebomb 4:3 :634 current 5; endmission 5:3 :405) - fine, all
announced at start.

### m6l2a - OK
waitForPlayer :94, then 1:2 "Plant explosives in the radio command post, in the northeast
corner of the town. [6 remaining]" :107 + current 1 :110 post-player -> toasts.
objective1_bombtracker :265 -> 1:3 :282 + 2:2 "Escape through the Commandant's residence on
the south side of town." :283 + current 2 :284 -> obj2 toasts. Count updates
:321-343 (objective1_locationcheck, quiet). m6l2a_changelevel :522 -> 2:3 :525.

### m6l2b - BROKEN
main: raw `level waittill spawn` :71 (no waitForPlayer in file), then adds 1:2 "Find the
train station." :79, 2:2 "Cut the electrical power to the fences." :80, 3:2 "Send the radio
transmission." :81 + current 1 :82, all pre-player -> all three toasts void.

Transitions have ZERO status-2 re-adds (every candidate is commented out :186-187,
:197-198, :204-205, :254-255, :260-261):
- objective1 :178 -> 1:3 :190 + current 2 :191
- obj2_used_powerbox :217 -> 2:3 :224 + current 3 :225
- obj3_used_radio :265 -> 3:3 :272

The player never sees a single objective card on this map.

Fix (m2l2a recipe, three pieces): coop_objToastStart ->
`coop_obj_toast_all 1 "Find the train station."`; gated toast after :191 ->
`coop_obj_toast_all 2 "Cut the electrical power to the fences."`; gated toast after :225 ->
`coop_obj_toast_all 3 "Send the radio transmission."`.

### m6l3a - OK
waitForPlayer :296, then 1:2 "Snipe the tower guards. Do not lose more than 9 men of the
assault team across the two boxcars." :402 + current 1 :403 post-player -> toasts.
Casualty-count re-add 1:2 :1204 (quiet). scene2_complete :1238 -> 1:3 :1250 + 2:2 "Unlock
the cellblock doors and free the POWs." :1251 -> toasts. scene5 :2090 -> 2:3 :2093 + 3:2
:2094 + 4:2 :2095 -> toasts. Bomb count updates 3:2 :2575/:2581/:2586 (quiet). 4:3 :2624.
5:2 "Find a way to the inner facility. Check elevators for enemy reinforcements." :2838 ->
toasts. 5:3 :3013.

### m6l3b - PARTIAL
main: waitTillSpawn :42 (NOT a player wait), then 1:2 "Acquire a gas mask." :49 and 2:2
"Make your way to the lower level." :50 + current 1 :53 pre-player -> both void.

elevator2 :98 -> 1:3 :140 + 2:2 re-add :141 + current 2 :142 -> obj2 announces mid-mission
(no key was set at load). Completes 2:3 :65 (end_of_level) / :160 (levelbluh).

MISSING: start toast obj1. Fix = coop_objToastStart ->
`coop_obj_toast_all 1 "Acquire a gas mask."`.

### m6l3c - BROKEN
main threads level_setup :40 BEFORE waitForPlayer :49; level_setup -> thread
objectives_setup :63 -> 1:2 "Escape Fort Schmerzen." :133 + current 1 :134 pre-player ->
void. These two lines are the ONLY objective calls in the file - no complete, no re-add
(change_level :191 does not touch objectives). Never announces.

Fix: coop_objToastStart -> `coop_obj_toast_all 1 "Escape Fort Schmerzen."`.

### m6l3d - OK
waitForPlayer :34, then 1:2 "Open the main gas valves. [2 remaining]" :92, 2:2 "Plant the
explosives." :93, 3:2 "Return to the elevator." :94 + current 1 :95 post-player -> all
toast. Transitions re-add status 2: setvalveobjective :339 (1:2 count :342 + 2:2 :343 +
3:2 :344), setobjective2 :354 (1:3 :357 + 2:2 :358 + 3:2 :359 + current 2),
explode_controller :364 (1:3 + 2:3 + 3:2 :373 + current 3). Completes 2:3 :114, 3:3 :280.

### m6l3e - BROKEN
level_setup :34 threads objectives_setup :60 BEFORE its own waitForPlayer :66 ->
1:2 "Escape Fort Schmerzen." :100 + current 1 :101 pre-player -> void. train_move :124 ->
1:3 :130 + current 0 :131. No status-2 re-add -> never announces.

Fix: coop_objToastStart -> `coop_obj_toast_all 1 "Escape Fort Schmerzen."`.

---

## Notes for the fixer

1. The m2l2a recipe verbatim (maps/m2l2a.scr:498-502): a column-0 label, threaded from the
   MP add block in main (`thread coop_objToastStart`), body =
   `waitthread coop_mod/replace.scr::waitForPlayer` -> `wait 2` ->
   `waitthread coop_mod/objectives.scr::coop_obj_toast_all <idx> "<text>"`.
2. Gated mid-transition toast verbatim (maps/m2l2a.scr:421):
   `if( level.gametype != 0 ){ waitthread coop_mod/objectives.scr::coop_obj_toast_all N "text" }`
   - only needed where a transition has NO status-2 add (m4l0 obj2; m6l2b objs 2+3).
3. Do NOT add toasts to maps whose transitions already re-add with status 2 - the
   add_objectives hook already announces those; a second explicit toast would be silent
   (keyed) at best and a duplicate at worst.
4. waitTillSpawn is not a player wait. Do not accept it as evidence a map is safe
   (M1L3a, m6l3b were classified on this exact distinction).
5. Toast text should match the objective text on screen at that moment (see M3L3: match the
   initial "[4 remaining]" string built at :135).
6. m1l2a papersthread :1674-1722 is dead code (label followed immediately by `end`). Leave
   it alone.
