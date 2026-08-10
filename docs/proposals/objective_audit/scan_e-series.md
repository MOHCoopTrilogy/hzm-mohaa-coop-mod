# Objective Toast Audit - e-series (e1l1 .. e3l4) [user 2026-08-09]

Scanner output for the objective-announcement defect class (found live on m2l2b/m2l2a).
Ground truth used for classification (same as scan_m-series.md, plus two e-series-specific
mechanisms):

- `global/objectives.scr::add_objectives` (line 43-45): toasts via
  `coop_mod/objectives.scr::coop_obj_toast_all` ONLY when status == 2. Status 1 (hidden) and
  status 3 (complete) never toast. `current_objectives` never toasts.
- **TEXT-LESS STATUS-2 ADDS NEVER TOAST.** The hook at global/objectives.scr:44 passes the RAW
  text argument; the stored-text backfill (level.coopObjectiveNText read, line 113+) happens
  AFTER the hook fires. `coop_obj_toast_all` exits on NIL/empty text
  (coop_mod/objectives.scr:680). The BT convention `add_objectives N 2` (no text) is therefore
  silent even with players present. This is the DOMINANT e-series failure mode - the m-series
  defect was pre-player timing; the e-series defect is mostly missing text.
- `coop_obj_toast_all` (coop_mod/objectives.scr:679-692) also early-exits on
  `$player.size < 1` and skips players whose `flags["coop_isActive"] != 1`
  (set at coop_mod/player.scr:1047, from the per-frame manage loop AFTER the engine spawn).
  Keyed per index per player (coop_mod/objectives.scr:72), so a later same-index status-2
  re-add WITH text announces normally if the first one never landed - which is why several
  maps below are rescued by their own count/compass updaters.
- **Third channel: `global/ObjMgr.scr`** (used by e1l3, e2l3, e3l2). Its refresh path
  `priv_RefreshObjNum` (ObjMgr.scr:653) DOES pass the stored desc to add_objectives, so
  `RevealObj` (status 1 -> 2, ObjMgr.scr:338-352) toasts correctly whenever players exist.
  `InitObj` registers at status 1 (ObjMgr.scr:147) - no toast, correct.
- `coop_mod/replace.scr::waitForPlayer` (line 99): blocks until `level.coop_playerReady == 1`
  (replace.scr:123), which player.scr:1070 sets right after coop_isActive=1 - so anything
  after waitForPlayer reliably reaches at least one active player.
- `level waittill playerspawn` is NOT equivalent: the engine event fires at the spawn moment,
  possibly frames BEFORE the manage loop stamps coop_isActive=1 - a toast in the same frame
  can skip the only player (see e2l3).

Classification: OK / PARTIAL / BROKEN / N/A per the task rubric. Line numbers verified
2026-08-09 against the working tree.

---

## Summary

| Map | Class | Player-wait before status-2 adds | Start toast | Mid-mission toasts |
|---|---|---|---|---|
| e1l1 | BROKEN | waitForPlayer e1l1.scr:183 (timing fine) | **none - text-less** | **none - ALL status-2 adds text-less** |
| e1l2 | OK | waitForPlayer e1l2.scr:67 | yes (count text) | yes (objs 2-4 with text) |
| e1l3 | OK | waitForPlayer e1l3.scr:129 | yes (ObjMgr reveals post-briefing) | yes (ObjMgr reveals) |
| e1l4 | PARTIAL | waitForPlayer e1l4.scr:64 (timing fine) | **obj1 silent/late/wrong-text** | objs 2-5 yes; **obj6 never** |
| e2l1 | PARTIAL | waitForPlayer e2l1.scr:80 (timing fine) | yes (obj1 count text) | **objs 2,3,4 never** |
| e2l2 | PARTIAL | waitForPlayer e2l2.scr:46 (timing fine) | yes (obj1 with text) | obj4 yes; **objs 3,5,6 never** (obj2 has no text at all) |
| e2l3 | PARTIAL | only `waittill playerspawn` e2l3.scr:70 (race) | **obj1 unreliable (coop_isActive race)** | yes (ObjMgr reveals) |
| e3l1 | PARTIAL | waitForPlayer e3l1.scr:104 (timing fine) | **obj1 never** | objs 2,3,4 yes; **obj5 never** |
| e3l2 | OK | waitForPlayer e3l2.scr:45 | yes (ObjMgr reveal) | yes (ObjMgr reveals) |
| e3l3 | PARTIAL | waitForPlayer e3l3.scr:65 (timing fine) | yes (obj2 with text) | **objs 3,4 never** |
| e3l4 | OK | waitForPlayer e3l4.scr:28 | yes | yes (all 7 first adds carry text) |
| e3l4_arena | N/A | - | no objective chain (holdout arena) | - |
| e*_precache | N/A | - | precache only | - |

---

## e1l1 - BROKEN (zero objective toasts on the whole map)

Channel: per-map state machine `maps/e1l1/objectives.scr` (init called e1l1.scr:81, pre-player
- harmless, registrations are status 1). All transitions run post-waitForPlayer
(e1l1.scr:183), so TIMING is fine - but every status-2 add on this map is text-less:

- `RevealObj` = `add_objectives local.num 2` NO TEXT (maps/e1l1/objectives.scr:254)
- `move_curr_compass_point` :77, `leadToFlaks` :291, `leadToBunker` :300 - all `2 NIL <pos>`
- maps/e1l1/scene2.scr:111 and :119 - `2 NIL <pos>`

Result: not a single New Objective card, ever. Registered texts exist (InitObj list,
maps/e1l1/objectives.scr:28-34).

| Idx | Text | Revealed (transition key -> caller) | Completed |
|---|---|---|---|
| 1 | Fight Through Enemy Lines | didIntro -> e1l1.scr:201 | commanderGagStart -> scene3.scr:1738 |
| 2 | Locate and Seize Enemy Artillery | didIntro -> e1l1.scr:201 (current at commanderGagEnd e1l1.scr:212) | seizedFlaks -> scene3.scr:1143 |
| 3 | Find a Way Through the Fortified Gate | hitGateTrigger -> objectives.scr:45-57 ($scene3Trigger3) | openedGate -> e1l1.scr:543 |
| 4 | Locate Enemy Bunker | seizedFlaks case -> objectives.scr:118 | foundBunker/reachedBunkers -> e1l1.scr:216 |
| 5 | Destroy Enemy Communications | talkedToSoldier -> scene3.scr:1251 | killedRadios -> scene5.scr:286 |
| 6 | Search the Bunker for Intelligence | talkedToSoldier -> scene3.scr:1251 | foundDocs -> scene5.scr:262 |
| 7 | Rendezvous with 1st Armored Division | UpdateCurrObj all-done -> objectives.scr:196 | foundAlliedArmorDivision -> scene6.scr:99 |

Fix sites (single choke point - inside `transition` cases in maps/e1l1/objectives.scr, gated
`if( level.gametype != 0 )`): didIntro -> toast 1; commanderGagEnd -> toast 2; hitGateTrigger
-> toast 3; seizedFlaks -> toast 4; talkedToSoldier -> toast 5 and 6; and next to the
RevealObj at objectives.scr:196 -> toast 7. Texts from the InitObj list above. Note
`warpObjectives` (e1l1.scr:581) replays transitions on dev warps - per-index dedupe makes the
extra toasts harmless.

## e1l2 - OK

All objective flow is in main after waitForPlayer (e1l2.scr:67); every objective's first
status-2 add carries text:

| Idx | Text | First status-2 add (toast) | Completed |
|---|---|---|---|
| 1 | Destroy Enemy Artillery [N Remaining] | maps/e1l2/Artillery.scr:237 (UpdateArtilleryObjective, from ObjectiveArtillery:122 <- e1l2.scr:107) | e1l2.scr:108 |
| 2 | Escort the Minesweeper Tank | e1l2.scr:109 | e1l2.scr:116 |
| 3 | Locate and Detonate German Munitions Depot | e1l2.scr:117 | e1l2.scr:120 |
| 4 | Rendezvous with Tank Convoy | e1l2.scr:121 | e1l2.scr:125 |

Note (no action): `UpdateEscortObjectiveLocation` (e1l2.scr:262/265) references undefined
`level.ObjEscortText` (init defines ObjEscortColumnText, e1l2.scr:249) -> NIL -> those
re-points are toast-quiet; harmless since :109 already announced index 2.

## e1l3 - OK

Channel: global/ObjMgr.scr (start_init e1l3.scr:82, finish_init :102 - registrations only).
In coop, main waits for a player (e1l3.scr:129) and then itself fires
$start_wall_battle_trigger (:130), which runs the briefing; all reveals are mid-mission with
players present and carry desc text through ObjMgr.scr:653.

| Obj | Text | Revealed | Completed |
|---|---|---|---|
| crossCanal | Successfully Cross the Canal | gotBriefing -> maps/e1l3/Briefing.scr:281 -> Objectives.scr:61 | boating.scr:825 |
| freeBrits | Free the British Prisoners | gotBriefing -> Objectives.scr:62 | JailBreak.scr:165 |
| takeFort | Secure the Fortress | freedBrits -> Objectives.scr:73 | Conquest.scr:427 |
| meetKlaus | Locate Klaus Knefler | tookFort -> Objectives.scr:77 | Sneakers.scr:139 |
| protectKlaus | Follow Klaus | metKlaus -> Objectives.scr:83 | FinalEscape.scr:616 |

catchup paths (boating.scr:19 etc.) are dev-warp CatchUpObjs - not player-facing flow.

## e1l4 - PARTIAL

All flow post-waitForPlayer (e1l4.scr:64). Registrations GiveObjectives e1l4.scr:369-383
(status 1 + texts; runs pre-player via InitLevel :58 - correct, no toast). Objs 2-5 are
rescued by `Ship.scr::compassTracker` (maps/e1l4/Ship.scr:260/265/270 - every branch passes
the objective text, first tick toasts):

| Idx | Text | Announced by | Completed |
|---|---|---|---|
| 1 | Find a Way Aboard the Freighter | **BROKEN - see below** | e1l4.scr:113 |
| 2 | Obtain the Troop Roster | tracker thread e1l4.scr:126 | e1l4.scr:130 |
| 3 | Search the Freighter for Explosive Charges | tracker thread e1l4.scr:138 | e1l4.scr:142 |
| 4 | Locate Engine Room and Set Explosives | tracker thread e1l4.scr:150 | e1l4.scr:154 |
| 5 | Rendezvous with Klaus | tracker thread e1l4.scr:159 (also :174 re-add w/ text) | e1l4.scr:179 |
| 6 | Escape the City | **NEVER - reveal e1l4.scr:188 is text-less, no tracker** | e1l4.scr:219 |

obj1 detail: the reveal at e1l4.scr:96 is `add_objectives level.objObtainPapers 2` (text-less
-> silent). The first text-carrying add for index 1 is e1l4.scr:103 - AFTER
PreShip.scr::ObtainPapers completes, i.e. the map's opening objective is announced only
mid-way. Worse, trigger label `UpdateObtainPapers` (e1l4.scr:390) re-adds index 1 with the
WRONG text `level.objReturnToSpyText` ("Rendezvous with Klaus" - retail variable bug); if a
player touches that trigger before :103, the one-shot index-1 toast shows the wrong line.

Fix sites: gated toast after e1l4.scr:96-97 (index level.objObtainPapers,
level.objObtainPapersText) and after e1l4.scr:188-189 (index level.objEscape, "Escape the
City"). The early toast at :96 also neutralizes the :390 wrong-text hazard via dedupe.

## e2l1 - PARTIAL

Channel: per-map maps/e2l1/objectives.scr (init e2l1.scr:176, post-waitForPlayer :80;
registrations status 1 + texts, objectives.scr:9-12). RevealObj here is text-less
(objectives.scr:224); the only text-carrying status-2 path is UpdateObj (objectives.scr:241).

| Idx | Text | Announced by | Completed |
|---|---|---|---|
| 1 | Locate and Destroy Anti-Aircraft Artillery [6 Remaining] | transition "start" (gliderride.scr:435) -> DoAAGunObjective -> UpdateObj count text (objectives.scr:99); kill updates re-run it (aaguns.scr:381) | all-dead branch objectives.scr:108 |
| 2 | Rendezvous with your Allies | **NEVER** (only text-less RevealObj, objectives.scr:31) | rendezvou_done -> paraBattle.scr:129 -> :38 |
| 3 | Destroy the Italian Rail Tank | **NEVER** (destroyAB41 -> SetCurrObj 3 -> text-less, objectives.scr:42; fired from DoAB41Objective:154) | destroyAB41_done -> objectives.scr:45 |
| 4 | Protect the 505th Airborne from Ambush | **NEVER** (protect505 -> `UpdateObj 4 NIL` - NIL text, objectives.scr:49; FinalBattle.scr:159) | protect505_done -> objectives.scr:53 |

Fix sites (inside `transition` in maps/e2l1/objectives.scr, gated): case "start" -> toast 2
"Rendezvous with your Allies"; case "destroyAB41" -> toast 3 "Destroy the Italian Rail Tank";
case "protect505" -> toast 4 "Protect the 505th Airborne from Ambush".

## e2l2 - PARTIAL

Channel: per-map maps/e2l2/objectives.scr; init is called POST-waitForPlayer (e2l2.scr:46 ->
:91), so its status-2-with-text add works:

| Idx | Text | Announced by | Completed |
|---|---|---|---|
| 1 | Destroy the Communications Tower | init add, objectives.scr:27 (post-player) | objectives.scr:43 |
| 2 | (getToJeep - registered with NIL text, objectives.scr:28; compass-only retail objective) | nothing to toast (no text exists) | flag only (:47) |
| 3 | Reach the Airfield at Caltagirone | **NEVER** (reveal objectives.scr:82 is `2 NIL`) | objectives.scr:51 |
| 4 | Sabotage Italian Fighters [4 Remaining] | planeGags.scr:77 count re-add (AirplaneObjCompass_Thread <- objectives.scr:87) | objectives.scr:56 |
| 5 | Sound Alarm to Scramble the Fighters | **NEVER** (reveal objectives.scr:97 is `2 NIL`) | objectives.scr:62 |
| 6 | Locate the British Officer and Escape the Airfield | **NEVER** (reveal objectives.scr:104 is `2 NIL`) | objectives.scr:67 |

Fix sites (inside `transition` else-chain in maps/e2l2/objectives.scr, gated): after :82 ->
toast 3 (text from :29); after :97 -> toast 5 (text from :31); after :104 -> toast 6 (text
from :32). obj2: leave (no retail text) or supply one - fixer/user call.

## e2l3 - PARTIAL (start toast is a race)

Channel: global/ObjMgr.scr. The start reveal `RevealObj "meet82nd"` (e2l3.scr:86) runs after
`level waittill playerspawn` (e2l3.scr:70) - a player EXISTS, but the toast also requires
`flags["coop_isActive"] == 1`, which the manage loop stamps at player.scr:1047 possibly
frames AFTER the engine spawn event. The section Inits between (:76-83) may or may not burn a
frame, so the sole connected player can be skipped and the start toast lost. main has NO
waitForPlayer gate before :86 (the waitForPlayer at e2l3.scr:208 lives in the PARALLEL
InitLevel thread, started at :46).

| Obj | Text | Revealed | Completed |
|---|---|---|---|
| meet82nd | Rendezvous with 82nd Airborne | e2l3.scr:86 (**racy**) | BattleHouse.scr:48 / :147 |
| assist82nd | Assist 82nd Airborne | BattleHouse.scr:49 / :149 (mid-mission, fine) | JohnsonThinker.scr:281 |
| clearTown | Secure the Village | JohnsonThinker.scr:282 (fine) | FinalHouse.scr:119 |
| repelTanks | Repel Tank Assault | FinalHouse.scr:120 (fine) | FinalHouse.scr:123 |

Fix site: thread the m2l2a `coop_objToastStart` pattern from main (waitForPlayer -> wait 2 ->
`coop_obj_toast_all 1 "Rendezvous with 82nd Airborne"`). Idempotent: if the :86 auto-toast did
land, per-player dedupe (coop_mod/objectives.scr:72) suppresses the second card.

## e3l1 - PARTIAL

Registrations GiveObjectives e3l1.scr:292-308 (status 1 + texts; runs pre-player via
InitLevel :97 -> InitPlayer :241 - correct, no toast). All status-2 flow is post-waitForPlayer
(e3l1.scr:104).

| Idx | Text | Announced by | Completed |
|---|---|---|---|
| 1 | Report to the British Field HQ | **NEVER** (reveal e3l1.scr:109 text-less; no text re-add exists) | e3l1.scr:113 |
| 2 | Escort the Medic to the British Wounded | e3l1.scr:121 (text) - LATE: the :116 reveal (get-on-jeep phase) is text-less | e3l1.scr:130 |
| 3 | Eliminate Snipers [3 Remaining] | UpdateSniperObjective count text (Courtyard.scr:549-555, first call DoObjectiveSnipers -> Courtyard.scr:260) | e3l1.scr:145 |
| 4 | Retrieve Munitions from the Supply House | BringInMedic (Courtyard.scr:576, piatstring) and GetPIAT compassTracker (AfterSnipers.scr:66/70) | e3l1.scr:153 |
| 5 | Escort the Wounded Out of the Area | **NEVER** (reveal e3l1.scr:156 text-less; no text re-add exists) | e3l1.scr:169 |

Fix sites (main flow, gated): after e3l1.scr:109-110 -> toast 1 (level.hqstring); after
:156-157 -> toast 5 (level.citystring). Optional: after :116-117 -> toast 2
(level.escortstring) so the escort announces when the phase starts; the later :121 add then
dedupe-quiets. Note (no action): :144 re-adds snipers with text and :145 completes it - in
normal play dedupe keeps it quiet; only dev-skip paths would toast-at-completion.

## e3l2 - OK

Channel: global/ObjMgr.scr (InitObjectives at e3l2.scr:68, post-waitForPlayer :45).
IMPORTANT for future greps: the whole numbered legacy system in maps/e3l2/objectives.scr
(lines 16-55 init, 61-207 Transition body) is INSIDE /* */ comment blocks - dead code; its
`Transition` label is a live no-op shell. Do not count its add_objectives lines.

| Obj | Text | Revealed | Completed |
|---|---|---|---|
| findPOWs | Search the City for Allied Survivors | AirplaneBomb_Section.scr:95 | final_section_pows.scr:198 |
| killModellos | Destroy Enemy Artillery [3 Remaining] | cannon_section_1.scr:277 | parts: e3l2.scr:277 / :297 / :317 |
| protectPOWs | Cover the Allied Prisoners' Escape | final_section_pows.scr:201 | final_section_pows.scr:424 |
| escape | Make your Escape | final_section_pows.scr:425 | final_section_pows.scr:601 |

SetObjDesc updates (e3l2.scr:288/:308/:330) refresh with text - dedupe-quiet. Dev-skip blocks
e3l2.scr:202-216 are also post-player.

## e3l3 - PARTIAL

waitForPlayer at e3l3.scr:65. GiveObjectives (e3l3.scr:293-308) runs post-player via
InitLevel(:66) -> InitPlayer(:204) -> GiveObjectives(:230), after Fadein+Briefing - so its
status-2-with-text add for the convoy toasts correctly.

| Idx | Text | Announced by | Completed |
|---|---|---|---|
| 2 | Destroy the Munitions Convoy | GiveObjectives e3l3.scr:304 (status 2 + text, post-player) | scene1.scr:643 |
| 3 | Search the House for Intelligence | **NEVER** (reveal e3l3.scr:92 `add_objectives 3 2` text-less) | e3l3.scr:97 |
| 4 | Locate and Destroy K5 Railway Guns | **NEVER** (reveal e3l3.scr:98 text-less; all updates NIL: :104 :111 :116 :121, scene2.scr:512) | scene3.scr:208 |

(There is no objective index 1 on this map; scene1's DoObjective1/DoObjective2 are convoy
phases of index 2. The index-2 NIL-text compass updates scene1.scr:486/640/703/711/719 are
quiet - fine, index 2 already announced.)

Fix sites (main flow, gated): after e3l3.scr:92-93 -> toast 3 "Search the House for
Intelligence"; after e3l3.scr:98-99 -> toast 4 "Locate and Destroy K5 Railway Guns" (texts
match GiveObjectives :305/:306).

## e3l4 - OK

waitForPlayer at e3l4.scr:28; registrations InitObjectives e3l4.scr:249-256 (status 1, no
text - called from InitLevel :46, post-player, still no toast because status 1). Every
objective's FIRST status-2 add carries text:

| Idx | Text | First status-2 add | Completed |
|---|---|---|---|
| 1 | Deliver Supplies to Able Bunker | e3l4.scr:63 | e3l4.scr:66 |
| 2 | Deliver Supplies to Baker Bunker | e3l4.scr:69 | e3l4.scr:75 |
| 3 | Reinforce Charlie Bunker | e3l4.scr:78 | e3l4.scr:85 |
| 4 | Regroup with Allied Forces in the Castle | e3l4.scr:90 (text set :258) | e3l4.scr:95 |
| 5 | Send a Distress Signal from the Castle Tower | e3l4.scr:98 (text set :259) | e3l4.scr:103 |
| 6 | Defend the Communications Tower | e3l4.scr:104 | e3l4.scr:108 |
| 7 | Confirm the Airstrike | e3l4.scr:109 | e3l4.scr:113 |

Known-quiet nuances (design, no action): the phase-two texts on REUSED indices - :72 "Repel
the Attack on Baker Bunker" and :82 "Repel the Attack on Charlie Bunker" - are suppressed by
the per-index dedupe (same behavior the recipe defines for republished counts). Update loops
:277/:297/:313 re-add with text - dedupe-quiet. Obj 8 (Escape the Castle) chain is fully
commented out (:117-124).

## e3l4_arena - N/A

Holdout arena build: none of e3l4's objective chain is threaded (e3l4_arena.scr:23, :49);
setup only, no objectives run.

## Precache scripts - N/A

e1l1_precache .. e3l4_precache, e1l3_precache__original, e3l4_arena_precache: precache only,
no objective calls.

---

## Fixer work queue (additive lines only, tag [user 2026-08-09], gate every toast with
`if( level.gametype != 0 )`, never renumber/reorder retail statements)

1. e1l1 - 7 toasts inside maps/e1l1/objectives.scr transition cases (+1 next to :196).
2. e1l4 - toast idx 1 after e1l4.scr:96-97; toast idx 6 after e1l4.scr:188-189.
3. e2l1 - toasts idx 2/3/4 inside maps/e2l1/objectives.scr transition cases start /
   destroyAB41 / protect505.
4. e2l2 - toasts idx 3/5/6 inside maps/e2l2/objectives.scr transition else-chain (:82 /
   :97 / :104).
5. e2l3 - coop_objToastStart thread in maps/e2l3.scr main (waitForPlayer -> wait 2 -> toast 1
   "Rendezvous with 82nd Airborne").
6. e3l1 - toast idx 1 after e3l1.scr:109-110; toast idx 5 after :156-157; optional idx 2
   after :116-117.
7. e3l3 - toast idx 3 after e3l3.scr:92-93; toast idx 4 after :98-99.
