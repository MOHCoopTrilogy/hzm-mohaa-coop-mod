# MP Armories - slice 1 build plan (reconciled)

Written 2026-09-13 by a READ-ONLY planning pass. Nothing in the project was edited, built, deployed or
launched except this note. Read-only checks that were run: check_mp_isolation.py (17 pass, 2 pending
[13][14], 0 fail) and gen_loadout.py check (615/615 byte-identical, exit 0).

Precedence used, highest first: mp_decisions_2026-09-13.md (S/T/P/A/F/M/H/C answers and chat decisions) >
mp_loadout_plan_v1.md header decisions 1-15 > mp_armories_understanding.md / mp_progression_understanding.md >
the plan body (sections 2-4). Where a record and the code disagree, the code won; every such case is named.

Path convention: coop_mod/, ui/, global/, models/, textures/, autoexec.cfg are under hzm-mohaa-coop-mod/.
code/ is under openmohaa-hzm/. docs/ and build.ps1 are at C:\mohaa-coop-dev.

---------------------------------------------------------------------------------------------------------------

## 0. Slice 1 in one paragraph, and the five choices that shape everything

Slice 1 delivers two MP-only armory screens (Allied, Axis) that replace the stock weapon picker in every
non-coop session, the Multiplayer Options side picker, one-primary kits with health 100 applied by the server
at spawn, bot kits, and the engine hooks that make the redirect total. Progression does not exist yet, so the
armory ships with its lock UI live and only the P1 starters unlocked. Coop is not touched except for three
approved-shape edits that carry no MP token (F7 bind, ARMORY button, removal of the mod's mpoptions menu),
each gated on a user decision in section E.

1. **Transport is client-origin only until a cgame ships.** Every pick is a client click that execs a
   static generated cfg, which `seta`s the archived pick and appends one `,q...` name-bus marker. Nothing in
   the MP UI trees uses `vstr`, and the server never execs a cfg that appends a marker. That keeps every new
   shape inside what the SHIPPED cgame filter already admits: zero grammar entries, zero guard-list entries
   (section C4). The carried default kit (decision 13, F3 across servers) comes with engine build B (E1:
   userinfo kit keys), which the progression research already recommends for kit picks (progression 2.6).
2. **The server owns the kit.** Chips on the client show what the server committed (server `set`s display
   cvars), never an unsent local archive. Before E1 a player on a new server sees the P1 starters until
   they pick.
3. **The stock picker is redirected in game.dll, not overridden in a .urc** (E5). Every `ui/*.urc` loads in
   every session including coop (code/client/cl_ui.cpp UI init), and same-named menus are keep-first
   (code/uilib/uiwinman.cpp:629-659). An MP file defining SelectPrimaryWeapon* would therefore change coop.
   UserSelectWeapon (code/fgame/player.cpp:18440) is the single choke point for team join, team switch,
   fire-click re-prompt, ESC "Select Weapon" and the P key.
4. **Separate generator, separate data.** A new docs/tools/gen_mp_armory.py writes both screens, both cfg
   trees and both server rosters from a new docs/tools/mp_armory_roster.tsv. gen_loadout.py,
   loadout_weapons.tsv and loadoutroster.scr stay byte-identical (gen_loadout check is a build gate, and
   unlock_audit fails any TSV row without a coop unlock path).
5. **The armory logic lives in its own MP script**, coop_mod/mp_armory.scr, with an explicit liveness
   check from mp.scr. A parse killer in the armory (T1: one bad token kills the whole file) then degrades
   to today's stock-class deploy instead of stranding everyone in spectate.

---------------------------------------------------------------------------------------------------------------

## A. Reconciliation table

Status key: BUILD = slice 1 builds it. INTERIM = slice 1 ships a stated stand-in. DEFER = later slice.
ENGINE = needs a binary (section C). **CONFLICT** = two records, or a record and the code, disagree; the
resolution is proposed and, where it is a real choice, raised as a user question (Ux, section E).

| id | decision (short) | slice 1 | status |
|---|---|---|---|
| Plan 1 | Three armories; Allies no non-Allied weapons | Two MP screens + trees + rosters; the coop armory untouched (LOCK on ui/coop_loadout.urc) | BUILD |
| Plan 2 | MP free floor removed | Verified gone: no coop_mpFreeKit in coop files (clause 7 passes) | done |
| Plan 3 | MP never calls coop armory code | Zero new MP_COOP_ALLOW entries. The generator READS coop data files at build time (skin tables, std-helmet map, xfm/stats); no runtime call | BUILD |
| Plan 4 | Axis 1P gloves on their own cvar (cgame) | E3. **CONFLICT (extension):** Allied MP gloves cannot use coop_gloveIdx either - gloves.scr stuffs it only when the value changes, so an MP write would stick into the next coop map. Proposal: one MP glove cvar read whenever the MP session flag is set, both sides | ENGINE, U7 |
| Plan 5 | Disguise tiks never modified; new Axis bodies are new files "starting german/axis/it/sc" | New bodies are new files. **CONFLICT with A5:** those prefixes put a body in the bot pool (code/fgame/g_bot.cpp:55-81) and the stock model picker (code/client/cl_uiplayermodelpicker.cpp:247-266). Resolution: MP never feeds its bodies to InitModel; it dresses with script `model` (no prefix check), so names use `hzmax_<stem>.tik` | BUILD (step 9) |
| Plan 6 | MP cfg trees under ui/coop_* | ui/coop_mpa_armory/ and ui/coop_mpx_armory/ (filter exec prefix `ui/coop_`, code/qcommon/cmd_filter.c:669) | BUILD |
| Plan 7 | FFA picks the armory by dmteam | Dispatcher keys on dmteam; anything not "axis" is Allied | BUILD |
| Plan 8 | MP progression unlocks ALL gear | Not built. Armory shows lock UI with only P1 starters unlocked; locked tiles preview but deny commit, hover text "Unlocks with MP progression" | INTERIM, U1 |
| Plan 9 | Start over in MP | Nothing reads a coop record | BUILD (free) |
| Plan 10 | Kills per class across both teams | Roster carries a `pclass` column so the later ladder keys on it | DEFER |
| Plan 11 | Players carry their own progress | E1 carries the kit (not the record); record is progression | DEFER / ENGINE |
| Plan 12 | Bot kills count | - | DEFER |
| Plan 13 | Multiplayer Options -> side picker -> side armory; Apply = default MP kit | Side picker BUILD. **CONFLICT 1:** menu "mpoptions" is owned today by coop file ui/multiplayeroptions.urc:9, and clause 7 bars coop files from naming an MP menu, so ownership must move into an MP-manifest file. That also changes coop's ESC > Multiplayer Options (its "Allies Player Model" button opens the coop armory, :174). **CONFLICT 2:** "Apply becomes your default" cannot reach a server without E1 or client vstr (section 0 choice 1); step 5 saves the default, step 7 delivers it | BUILD + ENGINE, U4 |
| Plan 14 | Stock picker gone incl. in-match ESC Select Weapon | E5 game.dll redirect. INTERIM before E5: mp.scr pops the engine's push and pushes the side armory on team join; mid-match ESC Select Weapon stays stock | ENGINE + INTERIM |
| S1 | MP may change game.dll, cgame.dll, exe, MP-gated | Every engine item sits in an HZM-MP-BEGIN/END block, registered in ENGINE_MP_HOOKS (clause 14) | BUILD |
| S2 | Script-less and third-party MP maps via an engine hook | E4 in Level::ServerSpawned. mp.scr must seed level.gametype itself (today it ends at mp.scr:53 when ambient.scr never ran) | ENGINE |
| S3 | Leave coop_weaponselect_suppress.urc alone; MP gets its own file | Suppress file untouched. **CONFLICT with the literal wording:** no MP-owned .urc may redefine the SelectPrimaryWeapon* names (loads in coop, keep-first dedup). The MP-owned files are the armory urcs plus the E5 redirect; new clause 16 forbids the shell route | BUILD |
| S4 | Coop couplings allowlisted now | No additions in slice 1 | BUILD |
| S5 | Shared assets acceptable | Weapon tiks, models/coop_helmets/*.tik, anim alias `americanselectionidle1` (same clip as coop's preview alias, anims_shared.txt:10 vs :21). **Code finding:** coop_lo_bg2.tga, coop_lo_lock.tga and `coop_loadout_idle` all match clause 12a's `coop_lo\w*`, so MP needs its own copies / the stock alias | BUILD |
| S6 | No coop hardening against operator bots | - | none |
| S7 | Zero bot cvars in start_server.cfg etc. | Not needed for slice 1 (bot tests use a separate server process) | DEFER |
| S8 | Homepath-root progress file | - | DEFER |
| P1 | One free starter per class per side = stock class kit gun | Interim unlocked set. Allied from the American stock kit, Axis from the German stock kit (code/fgame/player.cpp:10765-11024). **CONFLICT x2 on Axis**: stock German "sniper" on BT is g43.tik (:10797), which P3 moves to RIFLE; stock German "shotgun" is kar98_mortar.tik (:10901), while P11 says shotguns on both sides | INTERIM, U3 |
| P2 | HEAVY split into MG, Shotgun, Rocket | Tabs = RIFLE SNIPER SMG / MG SHOTGUN ROCKET / PISTOL NADES SAPPER (3x3; SAPPER only on landmine maps) | BUILD, U9 |
| P3 | Scoped rifles count toward the base gun's class | Tab follows pclass. **CONFLICT (ambiguity):** read literally, every purpose-built sniper in the roster has an unscoped base (Springfield 12 -> 06, Kar98K sniper 13 -> 03, Mosin sniper 20 -> 09, Carcano sniper 18 -> 07, Arisaka sniper 19 -> 10, L42A1 14 -> 05), leaving SNIPER almost empty while P1 grants it a starter | U2 |
| P11 | Shotguns on both sides | Trench Gun tile in both rosters (one tik, models/weapons/shotgun.tik) | BUILD |
| P12 | Stock kit items outside the roster where assets exist | Gewehrgranate (kar98_mortar.tik), Breda smoke (it_w_bombabreda.tik), Russian F1, RDG-1, both minedetectors (+ lite rifle companion). Type 97 has no tik: out | BUILD (steps 3-4) |
| A1 | Gewehr 98 gets its own tile | Axis RIFLE tile kar98_g98.tik; kept out of the MP G43 variant ring when finishes land | BUILD |
| A2 | MP Allied ring drops non-Allied bodies and the 24 prefix-failing skins | Ring = the 111 allied_/american_ skins, derived by the generator with the engine prefix test (player.cpp:2855-2857) from helmet.scr's table; s126/s129 fall out with the 24 | BUILD (step 8) |
| A3 | Axis bodies: 25 retail | INTERIM step 9a: worn as shipped (baked headgear); 9b: hatless forks | BUILD |
| A4 | HRRTM mandatory; lifting HRRTM geometry fine | Forks copy the WINNING tik content (the HRRTM Pak1 copy for 17 names) under new names | BUILD (9b) |
| A5 | New Axis bodies armory-only | `hzmax_` names (see Plan 5) | BUILD (9b) |
| A6 | Glasses only in the head slot | Axis head slot = Standard Issue, No Helmet, Eyeglasses (38), Aviator Glasses (39); Axis props added with 9b | BUILD |
| A7 | Japanese gaps accepted | Arisaka, Arisaka Sniper, Type 100, Nambu on Axis tabs (their tiks ship in zzzzz_xw_weapons.pk3, manifests/manifest-1.5.3.json:253); no Japanese grenade or body | BUILD |
| A8 | Voice nationality matches worn skin | E6 | ENGINE |
| F1 | F7 and Join Game ARMORY open the MP armory for the current side | E2 cgame command `hzm_armory`, then autoexec.cfg:1388 and ui/multiplayer.urc:210 call it. **CONFLICT:** the ARMORY button is on the disconnected Multiplayer screen, where there is no side, and it is coop's main-menu armory entry. Proposal: MP session -> side armory; otherwise the coop armory, unchanged | ENGINE, U5 |
| F2 | Disconnected padlocks from the carried record | INTERIM: the defaults screen shows the same static P1 padlocks | DEFER |
| F3 | Closed or idle armory auto-deploys last kit after 25 s | Server timer, re-armed by every `,q` marker. "Last kit" = the server-held kit (per player; per server process via an MP server cvar), else starters; E1 upgrades to the carried default | BUILD + ENGINE |
| F4 | Bots get random free-tier guns | isBot branch: random allowed class, that side's starter for it, re-applied each spawn edge | BUILD (step 2) |
| F5 | Bots dressed from the free tier | Free cosmetic tier is undefined in any record | BUILD (step 8-9), U6 |
| F6 | Per-map cap on bot-kill credit | - | DEFER |
| H9 | Mod copies of the six stock options screens + Host Rules | Not slice 1 (these are the multiplayerstart screens, not mpoptions). Note: the proposed name ui/mp_hostrules.urc (gamemodes 4.4) would fail clause 11a; use ui/coop_mp_hostrules.urc | DEFER |
| - | Health 100 per player at spawn | Already in mp.scr:229; kept in the new give path, never via the coop_health cvar (clause 4) | BUILD |
| - | One primary | Three slot cards: PRIMARY, SIDEARM, GRENADE. Each tile is legal in exactly one slot, so tile -> slot is static (no `vstr coop_loCcur` equivalent needed) | BUILD |

**Stale records found (fix when slice 1 lands, not in this pass):**
- docs/DECISIONS.md:542-551 "Axis loadout cosmetics are UNGATED; Axis weapons keep their unlocks" is
  superseded by plan decision 8.
- mp_armories_understanding.md 1.1 item 8 says `gen_loadout.py check` exits 1. It now passes 615/615 and is a
  build gate (build.ps1:59, bug-2577).
- mp.scr header (mp.scr:27-29, :255) says it never touches the picker and gives no kit. Both change here.
- mp_loadout_plan_v1.md body steps 1 and 4 (delete the `end.` lines in the suppress urc; reuse
  coop_loadout.urc for Allies; ui/mploadout/) are all superseded (S3, plan 1, plan 6).

---------------------------------------------------------------------------------------------------------------

## B. File plan

### B1. Naming rules (checked against check_mp_isolation.py as it stands)

| scope | glob (manifest) | may name | must never name |
|---|---|---|---|
| Allied-only | coop_mod/mpa_*.scr, ui/coop_mpa_*.urc, ui/coop_mpa_*/** (clause 13 ALLIED_GLOBS) | coop_mpa_*, shared coop_mp_* | coop_mpx_* (13a), coop_lo*, ui/loadout/ (12) |
| Axis-only | coop_mod/mpx_*.scr, ui/coop_mpx_*.urc, ui/coop_mpx_*/** | coop_mpx_*, shared coop_mp_* | coop_mpa_* (13b), coop_lo*, ui/loadout/ |
| Shared MP | coop_mod/mp.scr, coop_mod/mp_*.scr, ui/coop_mp_*.urc, ui/coop_mp_*/**, coop_mod/cfg/mp_*.cfg | both sides' tokens | coop_lo*, ui/loadout/, saved coop cvars (4), coop_isCoopSession/compassBar (15) |
| Coop | everything else | - | any coop_mp* token (7a) except coop_mpmenu / the coop_mpRun reads |

- Shared tokens always use `coop_mp_` (underscore) so they can never read as a side token by eye.
- Name-bus markers: `,q<side><field><data>`. `q` is unused by every coop key (armories 3.5), and w/f/s/h/g stay
  out of the first two characters. side `a`|`x`; field `1` primary, `2` sidearm, `3` grenade, `4` skin,
  `5` head, `6` gloves (3 digits of mpid or ring index), `d` deploy (no data). Longest marker `,qx1123`
  (7 chars + the space `append` inserts).
- Art: textures/mohmenu/coop_mp_armory_bg.tga, textures/mohmenu/coop_mp_lock.tga (clause 12a sees
  `coop_lo_bg2` / `coop_lo_lock` as coop armory names).
- Axis bodies: models/player/hzmax_<stem>.tik, hzmax_<stem>_fps.tik. Never a stock player path, never a
  german*/axis*/it*/sc* prefix, never listed in coop_armorySkins / coop_skinStdHelmet.

### B2. New files

| path | generated? | purpose |
|---|---|---|
| docs/tools/mp_armory_roster.tsv | source table (hand, one row per tile) | side, mpid, coop_id (for finish/xfm lookup), tab, pclass, dmclass (engine class for dmflags + primarydmweapon), slot, give (plain DM tik), preview tik, name, nation, starter, landmine_only, ammo type/count, note |
| docs/tools/gen_mp_armory.py | tool | `check` (regenerate in memory, byte-compare, exit 1) / `build`. Reads the TSV plus, read-only: loadout_weapons.tsv (xfm, stats, clip, desc by coop_id), coop_mod/helmet.scr skin + std-helmet tables, coop_mod/gloves.scr glove table. Writes only the MP outputs below |
| coop_mod/mpa_roster.scr, coop_mod/mpx_roster.scr | GEN | server rosters: mpid -> give, slot, dmclass, pclass, starter, ammo; bot starter lists; skin/head/glove tables; `alive` label returning 1 |
| ui/coop_mpa_armory.urc (menu coop_mpa_armory), ui/coop_mpx_armory.urc | GEN | in-match screens |
| ui/coop_mpa_defaults.urc (menu coop_mpa_defaults), ui/coop_mpx_defaults.urc | GEN | the same layout for the side picker / main menu: commits `seta` only and sends NO marker (a marker appended while disconnected would ride the saved name into the next server - bug-2571 class) |
| ui/coop_mpa_armory/*.cfg, ui/coop_mpx_armory/*.cfg | GEN | open.cfg (page flags + `pushmenu`), tab<N>.cfg, p<mpid>.cfg (preview page), c<mpid>.cfg (in-match commit: seta pick + name + tik, `append name ,q<s><f><mpid>`), d<mpid>.cfg (defaults commit, seta only), lk<N>.cfg (static padlocks), req<mpid>.cfg (hover text), deploy.cfg (`append name ,q<s>d`), skin/, head/, glove/ pages (step 8-9) |
| coop_mod/mp_armory.scr | hand | shared dispatcher: `alive`, token poll (every marker in the name, in order), side/slot/unlock/ban validation, commit to flags, chip push, hold + 25 s timer, deploy (class degrade), spawn-edge give, bot branch |
| ui/coop_mp_options.urc | hand (small) | menu "mpoptions" = the side picker: ALLIED -> `pushmenu coop_mpa_defaults`, AXIS -> `pushmenu coop_mpx_defaults`, plus a caption "Coop armory: F7" |
| textures/mohmenu/coop_mp_armory_bg.tga, coop_mp_lock.tga | art | 3-seat MP background (no coop caption), padlock copy |
| docs/tools/gen_mpx_bodies.py | tool (step 9b) | parameterised hatless fork of the 25 retail Axis bodies to hzmax_* (+ _fps twins, glove shader lists), refusing any disguise tik or stock path as a target |
| models/player/hzmax_*.tik | GEN (step 9b) | Axis armory bodies |
| models/coop_helmets/coop_mpx_std_*.tik ? | GEN (step 9b) | Standard Issue pieces for forks that need a new one (10 per armories 4.6). Name check: not under ui/ or coop_mod/, so clause 11 does not judge it, but clause 7 would fail if a COOP file ever names it - it never should |

### B3. Existing files touched

| file | owner | change | when |
|---|---|---|---|
| coop_mod/mp.scr | MP | seed `level.gametype` when NIL (E4 maps); `waitthread coop_mod/mp_armory.scr::alive` and require literal 1, else keep today's `primarydmweapon "rifle"` path; team-flip edge calls the armory hold instead of deploying; spawn edge calls the kit apply; `isBot` early-out before every stufftext (mp.scr:198, :252-253 leak a TAG_GAME buffer on bots, progression 8.1); header comments | step 2-3 |
| docs/tools/check_mp_isolation.py | tool | clauses 16-18 (section D step 1); ENGINE_MP_HOOKS entries as engine hooks land; LOCKS unchanged | steps 1, 6, 7, 10 |
| docs/tools/check_mp_isolation_selftest.py | tool | mutations for 13/14 activation and 16-18; HOOKS_ANCHOR rework (section D) | steps 1, 6 |
| docs/tools/ui_wiring_audit.py | tool | it fails any `append name` token not registered in coop_mod/variables.scr (ui_wiring_audit.py:125). Add an MP registry read from mp_armory.scr's token table, attributed by source tree, exact-family matching, and dispatch checked in mp_armory.scr - never variables.scr/player.scr (clause 7) | step 1 |
| build.ps1 | build | `python docs/tools/gen_mp_armory.py check` gate beside gen_loadout (:59); recommended: `sec2_guardlist.py --check` gate (not run by build.ps1 today) | step 1 |
| ui/multiplayeroptions.urc | coop | delete (menu "mpoptions" moves to ui/coop_mp_options.urc; two same-named containers must not rely on load order) | step 5, U4 |
| autoexec.cfg:1388 | coop | `bind F7 "hzm_armory"` - ONLY after the E2 cgame is deployed and its literal is confirmed in the DLL (an old cgame makes F7 an unknown command in coop) | step 7, U5 |
| ui/multiplayer.urc:210 | coop | ARMORY `stuffcommand "hzm_armory"` - same gating | step 7, U5 |

**Never touched:** ui/coop_weaponselect_suppress.urc (S3), ui/coop_loadout.urc (LOCK), ui/loadout/**,
docs/tools/loadout_weapons.tsv, gen_loadout.py, coop_mod/{loadoutpick, loadoutroster, loadout, loadoutskins,
loadoutskins_base, helmet, gloves, challenges, xp, player, main, itemhandler}.scr, global/ambient.scr, any
stock models/player path, models/player/base/anims_shared.txt.

### B4. Generator: new gen_mp_armory.py, not an extension of gen_loadout.py

Why not extend: gen_loadout.py is a coop build gate that must stay 615/615; it hard-codes `UI` = ui/loadout
(gen_loadout.py:30) and the coop_lo prefix; `build` splices coop_mod/loadoutroster.scr; `extract` rewrites the
TSV with only its 19 columns (an added column would vanish); and the coop page shape depends on `vstr`
gating that MP must not use (section 0 choice 1). Borrow its emitters by copying, not importing, so a coop
edit to it cannot move MP output.

Emitter assertions (fail the run, write nothing): zero `coop_lo` / `ui/loadout/` / `vstr` in any output;
zero cross-side tokens per clause 13; no `(tab, side)` cell over 9 rows; every exec target exists in the
output set; every marker matches the B1 grammar; ASCII only, no BOM, no empty right-hand sides (T1,
bug-1908), no newline inside a string; tile ids never renumbered (mpid is stable, holes stay holes); explicit
line endings written in binary mode (T2). `check` must be byte-exact so build.ps1 can gate on it.

Screen geometry reuses the coop recipe (armories 3.1), re-pitched for 3 tab rows:
- bg 0 0 640 480; DEPLOY 560 8 72 16 `popmenu 0 ; exec ui/coop_mpa_armory/deploy.cfg` (no fitunbind);
- charRender 12 82 134 312, per-widget cvars coop_mpa_Char / coop_mpa_Helm / coop_mpa_Prev /
  coop_mpa_XfmC, `modelanim americanselectionidle1`;
- 3 slot cards at 153 41+76k (k=0..2);
- 9 tabs, 3x3 at x306/361/416, y42/59/76, 52x15;
- tiles 306 97+19k 162 16 (k=0..8) with padlocks at x452;
- inspect/stats panel as coop (478 44 ...);
- no finish strip or fit-tune overlay in slice 1.
- Cosmetic prev/next arrows cannot be retargeted without `vstr`, so each ring page gets its own
  enabledcvar-gated arrow pair (generated, relies on the click-transparency patch at
  code/uilib/uiwidget.cpp:1736-1742, as the tiles do).

### B5. The five SelectPrimaryWeapon menus and in-match ESC "Select Weapon"

| entry | how it reaches the picker | slice 1 interim (mod only) | final (E5) |
|---|---|---|---|
| join_team with empty class | Join_DM_Team -> UserSelectWeapon(true), stuffs `wait 250;pushmenu SelectPrimaryWeapon[_nat]` (player.cpp:11406-11407, :18463-18495) | mp.scr on the team flip: `wait 300;popmenu 0;wait 300;popmenu 0` (existing bug-2564 recipe) then `exec ui/coop_<side>_armory/open.cfg`; hold in spectate; 25 s timer | redirect stuffs `exec ui/coop_mpa_armory/open.cfg` / mpx by GetTeam(); the pop is dropped once mp.scr sees the engine flag |
| alive team switch | UserSelectWeapon(false) (:11401) | flip edge offers the new side's armory | redirect |
| fire-click while teamed spectator, empty class | :6236, :6252 | American: empty shell; British/Russian/German/Italian: live stock picker, whose pick only sets the class - the MP kit is still what spawns | redirect |
| ESC > dm_main > Select Weapon (`popmenu 0;wait 50;pickweapon`, maintt/pak1.pk3:ui/dm_main.urc:64) and the P key | PickWeaponEvent -> UserSelectWeapon(false) (:18499-18506) | stays stock (known interim gap); F7 re-entry also waits for E2 | redirect |
| protocol < 15 | `pushmenu_weaponselect` (:18449-18457) | n/a on BT | redirect covers both branches |

Coop safety of the redirect: the gate is the level variable coop_mpRun == 1, which only mp.scr sets
(mp.scr:57-58) and which a level load wipes. mp.scr refuses on coop maps (mp.scr:46-49), so coop's own
`pickweapon` (coop_mod/main.scr:434) and its empty-shell pushes behave exactly as today.

### B6. Multiplayer Options side picker (decision 13)

- "Multiplayer Options" is `pushmenu mpoptions` from ui/multiplayer.urc:117 (disconnected) and from the stock
  in-match dm_main. Both keep working unchanged once the menu named "mpoptions" lives in
  ui/coop_mp_options.urc.
- Two buttons open the defaults screens (B2). They commit archived per-side picks: coop_mpa_P1..3 plus
  names/tiks, and coop_mpx_*.
- Apply = DONE on the defaults screen. It sends nothing. The defaults reach a server only after E1 (step 7).
- In a coop session the same ESC path now shows the side picker. It writes only coop_mpa_*/coop_mpx_*, never
  coop_lo*. The coop armory stays on F7, the lobby and ARMORY (U4).

### B7. F7 and the Join Game ARMORY button (F1)

cgame console command `hzm_armory` (E2):
- The MP session flag is 1: STAT_TEAM axis -> `exec ui/coop_mpx_armory/open.cfg`, else
  `exec ui/coop_mpa_armory/open.cfg`. A spectator with no team -> `pushmenu mpoptions`.
- Otherwise: `exec ui/loadout/open.cfg`, byte-for-byte today's coop behaviour.

Session flag coop_mp_session:
- Registered flags 0 and zeroed in CG_Init, the same pattern as coop_isCoopSession
  (code/cgame/cg_drawtools.cpp:2495-2503).
- mp.scr stuffs `set coop_mp_session 1` once per player. No coop file can name it (clause 7).

Until E2 ships, F7 in MP still opens the coop armory. The coop armory commits nothing server-side on an MP map:
mp.scr strips ",w" tokens (mp.scr:131-133).

### B8. Flow, timings and the give recipe (coop_mod/mp_armory.scr)

1. **Team flip** (spectator with no committed class):
   - mark `hold`;
   - push the side armory (B5 interim or E5);
   - push the server-held kit to the chips: `set coop_mpa_N1 <name>` and friends, one statement per
     stufftext, at most 8 per waitframe;
   - arm the 25 s timer.
2. **Marker** `,q<s><f><data>`:
   - The side must match dmteam, else deny.
   - mpid must be in that side's roster and slot-legal for field f.
   - Unlock (interim): starter == 1, or a dev override (U1).
   - dmflags class ban (DF_WEAPON_NO_* bits, player.cpp:10835/10861/10883): deny and push the previous
     chip back (bug-591 rule).
   - Commit to flags coop_mp_K1..K6 and to an MP server cvar keyed `"coop_mpk" + md5string(clean name)`.
     That join passes clause 12c: it steers into coop_mp space.
   - Re-arm the timer, clean the name (existing mp_cleanName).
   - The dispatcher reads EVERY `,q` marker in one name. It must not copy coop's lowest-index-wins rule
     (armories 3.4).
3. **Deploy** (`,q<s>d`, timer expiry, or ESC which sends nothing and so expires):
   - resolve the kit, fill gaps with starters;
   - degrade the primary's dmclass against dmflags to a legal class;
   - `primarydmweapon <class>` (self-deploys, player.cpp:12086-12101);
   - clear `hold`.
   - Gametype 3/4: deploys after g_allowjointime (30) become temporary spectators, so the 25 s timer
     stays under it.
4. **Spawn edge**:
   - `takeall`, then `item <give>` for primary, sidearm and grenade (plain DM tiks, never *_sp_start);
   - explicit `ammo` for grenade and smoke pools;
   - `use <primary>` re-asserted after 0.4 s, past the engine's +0.3 s useitem (player.cpp:10991-10992);
   - `health 100`.
   - Never changeGameType / giveInventory / spawnInventory (mp.scr:17-21).
   - Probe: `^~^~^ MPKIT e<n> side=<a|x> p=<tik> s=<tik> g=<tik> hp=<n> cause=<done|idle|bot>`.
5. **Death**: keep the kit, do not reopen. **Change while alive**: commit for the next life (the engine says
   so itself, player.cpp:12106-12109). **Round restart**: level vars and flags are wiped, so the server cvar
   memory re-seeds the kit.
6. **Poll latency**: players in `hold` or awaiting spawn are ticked every frame, everyone else at 0.5 s as
   today. That removes the 0.5 s window where the stock kit is visible. If the player_spawned delegate
   probe (step 0) passes, the spawn edge moves onto it.

### B9. Rosters (tabs follow the recommended P3 reading, U2; starters per U3)

| tab | Allied (starter in bold) | Axis (starter in bold) |
|---|---|---|
| RIFLE | **M1 Garand 01**, M1 Carbine 02, Lee-Enfield 05, Springfield M1903 06, SVT-40 08, Mosin 09, Garand Silenced 11, Johnson 70, Garand Scoped 15 | **Kar98K 03**, G43 04, Carcano 07, Arisaka 10, Gewehr 98 (new mpid, kar98_g98.tik) |
| SNIPER | **Springfield Sniper 12**, L42A1 14, Enfield Sniper 17, Mosin Sniper 20, Mosin Sniper Silenced 21, De Lisle 23 | **Kar98K Sniper 13**, G43 Sniper 16, Carcano Sniper 18, Arisaka Sniper 19, Kar98K Sniper Silenced 22 |
| SMG | **Thompson 24**, Thompson Drum 25, Sten 28, PPSh 29, PPS-43 Silenced 30, Grease Gun 31, Grease Silenced 32 | **MP40 26**, MP40 Silenced 27, Moschetto 33, Beretta M38A 34, Type 100 35 |
| MG | **BAR 36**, Vickers 40, .30 Cal 42, DP-28 72 | **StG 44 37**, StG 44 Scoped 38, FG 42 39, Breda M30 41, MG42 43 |
| SHOTGUN | **Trench Gun 44** | **Trench Gun 44** |
| ROCKET | **Bazooka 45**, PIAT 47 | **Panzerschreck 46**, Gewehrgranate (new mpid, kar98_mortar.tik, dmclass shotgun) |
| PISTOL | **Colt 48**, Colt Silenced 49, Hi-Standard 52, Webley 53, Nagant 54, TT-33 60, TT-33 Silenced 61, Welrod 63, S&W M10 75 | **P38 50**, P38 Silenced 51, Beretta 55, Beretta Silenced 56, Luger 57, Luger Silenced 58, PPK 59, Nambu 62, Mauser C96 74 |
| NADES | **M2 Frag** (m2frag_grenade.tik), Mills (mills_grenade.tik), M18 Smoke, Russian F1, RDG-1 Smoke | **Stielhandgranate** (steilhandgranate.tik), Nebelhandgranate, Breda Mod.35 (it_w_bomba.tik), Breda smoke (it_w_bombabreda.tik) |
| SAPPER (landmine maps only) | US Minedetector (+ m1_garand_lite if g_rifles_for_sweepers) | Minensuchgerat (+ kar98_lite) |

- Thompson Gold (71) is a finish of 24 in MP, not a tile.
- The largest cell is Allied RIFLE at 9, which fits.
- G43 (zoom 30) moves to RIFLE under P3, and the German stock sniper-class gun is exactly that G43, hence U3.
- The landmine-map list is generated from QueryLandminesAllowed's map table (player.cpp:10604-10669) into
  the roster, because script cannot call it.

### B10. Bots (F4, F5)

- Classify with `isBot` at the moment of use (code/fgame/scriptthread.cpp:2068), never by name, entnum or ip.
- No stufftext, menus, chips or timers for bots.
- Spawn edge: random class among the side's allowed classes, that class's starter, health 100.
- Re-applied every life, because bots re-roll class and model on death (playerbot.cpp:1247-1260).
- Dressing: script `model` from the side's free tier (U6). Axis bots never wear hzmax_* bodies (A5).

### B11. Every server->client command shape the armories use

| # | shape | origin | passes the shipped filter? |
|---|---|---|---|
| 1 | `wait 300;popmenu 0;wait 300;popmenu 0` | mp.scr (existing) | yes: wait and popmenu are whitelisted |
| 2 | `exec ui/coop_mpa_armory/open.cfg` / `exec ui/coop_mpx_armory/open.cfg` | mp.scr; E5 game.dll; E2 client-origin | yes: `ui/coop_` prefix (cmd_filter.c:669). Lines inside may only be set/seta coop_mp*, `pushmenu coop_mp*_armory` and popmenu (layer 2 filters them): no append, no vstr, no nested exec |
| 3 | `set coop_mpa_N1 <text>` (chip names, tiks, model ids, head/glove indices), `set coop_mpa_Lk<mpid> 0or1` | mp_armory.scr | yes: coop_ prefix, not in the guard list; unquoted, one statement per stufftext (T8) |
| 4 | `set coop_mp_ban<cls> 0or1`, `set coop_mp_mines 0or1` | mp_armory.scr | yes |
| 5 | `set coop_mp_session 1` | mp.scr (step 7) | yes (engine-registered flags 0) |
| 6 | `set name <clean>` | existing mp_cleanName | yes: marker-free value (cmd_filter.c:596-622) |
| 7 | `s_volume <v>`, `s_sfxduck 1` | existing, now skipped for bots | yes |

**Deliberately NOT used**, because each would need a grammar or guard entry plus a shipped cgame (and exe):
- a server-origin `append name ,q...` (name grammar, cmd_filter.c:534-590);
- an MP open-ping marker inside a server-exec'd cfg (the `,w0o` precedent at :556-563);
- any client or server `vstr coop_mp*` (the cmd_srvguard.h VALIDATE/REFUSE entries generated by
  docs/tools/sec2_guardlist.py, which sweeps every .cfg/.urc).

---------------------------------------------------------------------------------------------------------------

## C. Engine work

Queue: engine builds share openmohaa-hzm/.cmake with the visual-upgrade track, one build at a time. Mod steps
0-5 need no binary. Build A is server-only (hosts, not every client) so it queues first. Build B is the first
client binary. Every block is `// HZM-MP-BEGIN(<name>)` ... `// HZM-MP-END(<name>)` with the name in
ENGINE_MP_HOOKS (check_mp_isolation.py:108) in the same commit.

- The first registry entry breaks the self-test anchor `ENGINE_MP_HOOKS = {}`
  (check_mp_isolation_selftest.py HOOKS_ANCHOR / HOOKS_TEST, mutations P3 and M34). Rework it to patch an
  entry into a non-empty dict in the same change.
- Clause 14g forbids coop_lo* and ui/loadout/ INSIDE a block, and 14f forbids coop_mp* tokens and MP
  script paths OUTSIDE one. Mixed coop/MP functions (E2) must keep the coop branch outside the markers.
- After every build: `grep -a -c` one new string literal in the built DLL (T14e), then hash-verify the
  deployed copy (T10).

### Build A - game.dll (server)

**E4 `mp_mapscript_hook` - S2 script-less and third-party maps.**
- File/function: code/fgame/level.cpp Level::ServerSpawned (:1515), inside `if (!Spawned())`. That is after
  PreSpawnSentient ran the map script (:1480-1494) and after ambient.scr's prespawn hook.
- Fire `Director.ExecuteThread("coop_mod/mp.scr", "main")` only when ALL hold:
  - g_gametype != GT_SINGLE_PLAYER;
  - level vars coop_mpRun != 1, coop_mainScriptLoaded != 1 and ambient_script_run != 1 (engine precedent for
    reading level vars: bug-2574's CoopMpPlayerHit);
  - and either the map script file does not exist (`gi.FS_ReadFile(m_mapscript, NULL, qtrue) == -1`), or it
    exists AND compiled. ScriptMaster::GetScript returns NULL on a compile exception (scriptmaster.cpp:966-986),
    so "exists but NULL" means a parse-killed map, and the hook must NOT fire there. That is the case that
    would otherwise start MP on a broken coop map.
- Mod side: mp.scr seeds level.gametype from g_gametype when NIL.
- Covers mp_ship_lib / mp_bizertefort_obj (armories 5.11), siegecastle_obj / stalingrad_3_obj and third-party
  maps. The 23 y_hzm_maptour scripts run coop main first and are skipped by design.
- Risk: MEDIUM. Timing on round `restart` (level vars wiped, the hook re-fires like ambient does);
  ExecuteThread from outside a script context needs the same try/catch as G_ServerSpawned.

**E5 `mp_weaponselect_redirect` - plan 14.**
- File/function: code/fgame/player.cpp Player::UserSelectWeapon (:18440).
- At the top: if level var coop_mpRun == 1, send `stufftext "exec ui/coop_mpx_armory/open.cfg"` (GetTeam() ==
  TEAM_AXIS) or the mpa one, honouring bWait with `wait 250;`, and return. Covers both protocol branches.
- Also pre-register a server cvar coop_mp_engine "1" in G_InitGame inside the block (T7: script getcvar would
  otherwise create it empty), so mp.scr can drop the interim pop.
- Coop: coop_mpRun is never 1 on a coop map.
- Stock-cgame clients drop the exec and see nothing; the 25 s idle deploy covers them.
- Risk: LOW-MEDIUM. Bots also reach UserSelectWeapon, but server commands to bots are dropped (sv_game.c).

**Optional E4b `mp_model_override`.**
- A per-player model override that InitModel honours when coop_mpRun == 1.
- Removes the respawn frame in which InitModel re-applies dm_playermodel (the player's COOP skin) before
  mp_armory re-models (progression 5.7).
- Risk: MEDIUM. It touches the respawn path. Ship only if step 8 screenshots show the flash.

### Build B - cgame.dll (every client), exe only if the REFUSE entries are wanted

**E1 `mp_kit_userinfo` - carried default kit (decision 13, F3 across servers).**
- File: code/cgame/cg_main.c, CG_Init cvar registration.
- Register coop_mpa_k1..k6 and coop_mpx_k1..k6 CVAR_USERINFO|CVAR_ARCHIVE (precedent coop_pin1..5,
  code/client/cl_main.cpp:4183-4187).
- The defaults and commit cfgs then `seta` those keys. The server reads them with
  `info_valueforkey local.p.userinfo "coop_mpa_k1"` (both builtins exist: player.cpp:1670, scriptthread.cpp:1376;
  runtime untested), so deploy and first join use the carried kit with no marker. The name-bus markers
  remain the live pick path.
- About 170 of ~800 free userinfo bytes (progression 2.2).
- Optional hardening: REFUSE entries for these keys so a hostile server cannot overwrite them. Needs a static
  refuse list in sec2_guardlist.py, the regenerated code/qcommon/cmd_srvguard.h, and both cgame and exe
  rebuilt (the header is compiled into both).
- Risk: LOW (registration only). A cgame-registered USERINFO cvar created earlier by a menu `seta` merges
  flags and keeps its value: probe it.

**E2 `mp_armory_cmd` - F1.**
- File: code/cgame/cg_consolecmds.c, the command table (:698-762) plus the handler.
- `hzm_armory` as in B7. The coop branch sits outside the markers.
- The session flag coop_mp_session is registered flags 0 and zeroed in CG_Init inside the block (pattern:
  cg_drawtools.cpp:2495-2503).
- Mod follow-up: F7 bind and ARMORY button (B3), shipped strictly after the DLL.
- Risk: LOW.

**E3 `mp_glove_cvar` - plan 4 (+ U7).**
- File: code/cgame/cg_modelanim.c, the glove block (:3043-3060).
- When coop_mp_session == 1, read coop_mp_glove instead of coop_gloveIdx. Coop never sets the flag, so coop
  reads exactly what it reads today.
- Content dependency: Axis bodies need glove shader lists in the hzmax_* tiks and their _fps twins (step 9b).
- Risk: LOW.

### Build C - game.dll, then optional exe

**E6 `mp_voice_nationality` - A8.**
- File/function: code/fgame/player.cpp Player::GetNationalityPrefix (:12201), plus every other nationality
  consumer that picks voice.
- When coop_mpRun == 1, derive nationality from the worn model's stem (strip `hzmax_`, then
  GetPlayerAxisTeamType / GetPlayerAlliedTeamType) instead of client->pers.dm_player(german)model.
- Research first [NV]: the full consumer list. Known so far: the `nationalityprefix` getter (:944-946)
  used by the pak scripts' lib_dm.scr:636/651 and the `den`/`dfr` alias families that cgame keys subtitles
  on (cg_commands.cpp:3883). The instant-message sound choice has not been traced.
- Risk: MEDIUM. Nationality also feeds EquipWeapons and UserSelectWeapon, which must NOT change: gate only
  the voice consumers.

**E7 `mp_preview_keywords` - optional (exe).**
- Files: code/client/cl_uistd.cpp (rendermodel keywords :209-279) and cl_invrender.cpp (:285-331).
- Per-widget `modelglovecvar <cvar>` and `modelhidesurf <surface>` keywords. When absent, behaviour is exactly
  today's, so the locked coop urc is unaffected.
- Fixes two MP preview defects:
  - the global coop_loGlove index paints onto the MP mannequin's `hand` surface;
  - the helmet hide list knows only US surfaces, so Axis baked helmets stack under a head prop.
- Risk: LOW-MEDIUM. The exe is a staged client binary.

### C4. Stufftext-filter grammar

- Slice 1 as designed needs NO grammar entry and NO guard entry (B11).
- Grammar work is triggered only by a deliberate change of design: E1's optional REFUSE entries, a future
  `vstr`-gated padlock (progression) or a server-driven replay. Each needs the entry in
  code/qcommon/cmd_filter.c or the regenerated cmd_srvguard.h, a shipped cgame.dll and exe first, and a pass
  of docs/tools/sec1_filter_selftest/build.bat.
- New clause 18 (section D step 1) keeps `vstr` out of the MP UI trees, so this cannot happen by accident.

---------------------------------------------------------------------------------------------------------------

## D. Build order

**Every step's standing checks (not repeated below):**
1. `python docs/tools/check_mp_isolation.py -v`: 0 FAIL, and no clause that the step activates may still
   read PENDING.
2. `python docs/tools/check_mp_isolation_selftest.py`: `selftest: ok`.
3. `python docs/tools/gen_loadout.py check`: 615 byte-identical.
4. `python docs/tools/gen_mp_armory.py check` (from step 1).
5. `python docs/tools/ui_wiring_audit.py`, `scrlint.py`, `prosecheck.py` on changed .scr.

**COOP REGRESSION (every step), compared with the step-0 baseline:**
- **Static.** sha256 of the coop armory surface is unchanged, except files the step explicitly lists:
  - ui/loadout/**, ui/coop_loadout.urc, ui/coop_weaponselect_suppress.urc;
  - coop_mod/{loadout*, helmet, gloves, challenges, xp, player, main, itemhandler, variables}.scr;
  - models/player/**/*_nohat*.tik, autoexec.cfg, ui/multiplayer*.urc.
- **Runtime.**
  - Launch: `launch_dedicated_2player.ps1 -Map m1l1` (tell the user first: windows pop).
  - Remote Player2 opens the coop armory via rcon `script *1 stufftext "exec ui/loadout/open.cfg"` (python
    driver, T14f).
  - Pick via `script *1 stufftext "append name ,w124"` (a server-origin marker the grammar admits), then
    respawn.
  - Pass only if:
    - the coop `^~^~^` armory/loadout lines in server_home\maintt\qconsole.log match the baseline sequence;
    - Player2's weapon matches (screenshot);
    - the `seta coop_lo*` block of player2_home's omconfig.cfg hashes identically after the same pick;
    - `grep -a -c coop_mp` is 0 on the server log and player2 config;
    - the log count of `dropping duplicate menu container` is unchanged;
    - `coop_isCoopSession` still reads 1.
  - Whole-log sweep for new errors (user preference).

**MP runtime pattern:**
- Server: omohaaded with fs_homepath C:\mohaa-coop-dev\server_home_mp, net_port 12203, developer 1 (script
  cheats, T14), g_gametype 2, map dm/mohdm1, rconpassword seeded as in mp_bot_damage_test.ps1.
- Client: one openmohaa.exe from a scratch home copied from player1_home.
- Drive with `python docs/tools/rcon.py "script *0 join_team allies"`.
- Evidence: client window screenshots and `^~^~^ MP*` probe lines read from this run's log offset only.
- Clicks come from a click driver on virtual 640x480 coordinates (spawn_clicker pattern), because the pick
  markers must be client-origin.

### Step 0 - baselines and measurements (nothing shipped)

- Record the standing checks and the coop regression baseline above.
- Probe in a throwaway coop_mod/mp_probe.scr (manifest name), deleted afterwards:
  - (a) `event_subscribe "player_spawned" coop_mod/mp_probe.scr::x` with an unquoted label;
  - (b) `takeall` + `item` after EquipWeapons, and the +0.3 s useitem race;
  - (c) `info_valueforkey local.p.userinfo "name"`;
  - (d) grenade counts from `item` of plain DM tiks;
  - (e) `model` on an Axis player plus attachmodel on "Bip01 Head" for an Italian body.
- Check: each probe prints its line; coop baseline captured.

### Step 1 - data, generator skeleton, gates (ships two inert scripts)

- docs/tools/mp_armory_roster.tsv (B9) and gen_mp_armory.py emitting only coop_mod/mpa_roster.scr and
  coop_mod/mpx_roster.scr.
- mp.scr::main prints `^~^~^ MPROSTER a=<alive> x=<alive>` via waitthread. That is a real compile test on a
  dedicated MP boot (T1).
- build.ps1 gen_mp_armory check gate; ui_wiring_audit MP registry.
- **New checker clauses:**
  - **16 MENU NAMES.**
    - Every `menu "<n>"` in an MP urc is coop_mp* or in MP_OWNED_MENUS = {"mpoptions"}.
    - No MP urc declares SelectPrimaryWeapon*, coop_loadout or dm_main.
    - No coop urc declares a coop_mp* menu or an MP_OWNED_MENUS name.
  - **17 CHARACTER GEAR.** MP files never name dm_playermodel, dm_playergermanmodel, coop_gloveIdx,
    coop_helmetIdx or coop_armorySkin* (flags included).
  - **18 NO VSTR IN MP UI.** No `vstr` statement in ui/coop_mp*.urc or ui/coop_mp*/**, unless its cvar is
    listed in code/qcommon/cmd_srvguard.h.
- **Self-test additions:**
  - 13 activation:
    - plant ui/coop_mpa_armory/zzselftest.cfg (inside the REAL Allied tree) naming coop_mpx_N1 -> 13a;
    - plant coop_mod/mpx_zzselftest.scr naming coop_mpa_K1 -> 13b;
    - near-miss ui/coop_mp_zzselftest.urc naming both sides -> no 13 fail;
    - near-miss Allied file naming coop_mp_session -> no fail;
    - an EXPECT_ACTIVE = {"13"} assertion so a rename that drops the real files out of the globs fails the
      build instead of going PENDING.
  - 16: ui/coop_mp_zzselftest.urc declaring `menu "SelectPrimaryWeapon_german"` -> 16a; ui/zzselftest.urc
    (coop space) declaring `menu "mpoptions"` -> 16b.
  - 17: mp.scr appended `local.p stufftext "seta dm_playermodel x"` -> 17a.
  - 18: ui/coop_mpx_zzselftest/v.cfg `vstr coop_mpx_zz` -> 18a; near-miss the same text in a comment.
- **Check:** clause 13 PASS with Allied 1 / Axis 1; the MPROSTER line on dm/mohdm1; coop regression with
  `grep -a -c MPROSTER` = 0 in the coop log.

### Step 2 - server kit, no new UI

- coop_mod/mp_armory.scr: alive, kit resolve from starters, dmflags degrade, spawn-edge give (B8.4),
  health 100, bot branch (B10), per-frame tick while holding.
- mp.scr: level.gametype seed, isBot stufftext guard, the liveness fallback. Team flip still deploys at once:
  no hold yet, because there is no screen yet.
- **Runtime:**
  - rcon join_team allies -> `^~^~^ MPKIT ... p=m1_garand.tik s=colt45.tik g=m2frag_grenade.tik hp=100` and a
    Garand screenshot;
  - join_team axis -> Kar98K kit;
  - `set dmflags <no-rifle bit>` + map restart -> degraded class, no strand;
  - a second run with `sv_maxbots 2` -> MPKIT cause=bot lines, no stufftext to bots (no `s_volume` on bot
    entnums);
  - a gametype 4 map (obj/obj_team2) round restart -> kit re-applied.
- **Coop regression** as standard.

### Step 3 - Allied armory screen (weapons + lock UI), hold and 25 s

- Generate ui/coop_mpa_armory.urc, ui/coop_mpa_armory/*, the bg and lock art.
- Dispatcher markers, chip push, DEPLOY, timer, SAPPER visibility, P12 Allied extras.
- Axis players keep step 2 behaviour.
- **Runtime:**
  - join allies -> armory screenshot within 2 s;
  - click SMG tab, Thompson, DEPLOY -> `^~^~^ MPTOK e0 ,qa1024 ok` + `MPDEPLOY cause=done class=smg`, Thompson
    in hand;
  - click a locked tile -> `MPTOK ... deny locked`, chip unchanged;
  - no clicks -> `MPDEPLOY cause=idle` at 25 +/- 1 s;
  - ESC key -> idle deploy;
  - rapid double click then DEPLOY inside 0.5 s -> both markers applied in order;
  - a 20-character player name -> markers not truncated (32-byte cap);
  - stock-cgame-style drop simulated by removing the menu exec -> idle deploy still happens.
- **User eyes:** one screenshot per tab (blind URC surface; revert on the second failure, preferences).

### Step 4 - Axis armory weapons

- Generate the mpx screen and tree with G98, Gewehrgranate, Breda smoke, the Japanese guns, Trench Gun and
  Minensuchgerat.
- Runtime as step 3 with join_team axis, plus:
  - an Italian-model client (dm_playergermanmodel it_ax_ital_vol) gets the Axis armory;
  - a G98 pick gives kar98_g98.tik;
  - a landmine map shows SAPPER, mohdm1 does not.

### Step 5 - side picker and Multiplayer Options (after U4)

- ui/coop_mp_options.urc, the defaults screens, deletion of ui/multiplayeroptions.urc.
- **Runtime, disconnected client:**
  - main menu > Multiplayer > Options -> side picker screenshot;
  - Allied -> defaults screen;
  - pick + DONE -> omconfig.cfg gains `seta coop_mpa_*`;
  - the `seta coop_lo*` block hash is unchanged;
  - the saved name carries no `,q`.
- **Coop regression addition:** in the coop session, ESC > Multiplayer Options shows the side picker (the
  accepted change) and still writes no coop_lo*.

### Step 6 - engine build A (E4 + E5), then the mod follow-up

- Runtime:
  - mp_bizertefort_obj and mp_ship_lib -> `MP init` and the armory;
  - a scratch copy of a map with its .scr removed -> hook fires;
  - a scratch coop map with a planted parse error under g_gametype 2 -> hook does NOT fire;
  - allied_british and german model clients -> MP armory, never a stock picker;
  - ESC > Select Weapon and the P key -> armory screenshots.
- Coop regression, especially coop's pickweapon shell sequence and the duplicate-menu count.
- Self-test: HOOKS_ANCHOR rework, EXPECT_ACTIVE adds "14", and mutations planting a stray `coop_mpRun` read
  outside the new blocks in level.cpp (14f).

### Step 7 - engine build B (E1 + E2 + E3), then the mod follow-up

- Deploy cgame and confirm the literals (`grep -a -c hzm_armory cgame.dll`). Only then ship the F7 bind and
  the ARMORY button (B3).
- Runtime:
  - F7 in MP (key driver) -> side armory; F7 in coop -> coop armory (coop regression);
  - defaults set offline, then a fresh server_home_mp -> first deploy uses the carried kit with no clicks;
  - Axis client with a glove pick -> first-person glove screenshot;
  - the same client then on coop m1l1 -> coop glove unchanged.

### Step 8 - Allied cosmetics

- 111-skin ring (A2), Allied headgear, gloves.
- Server applies `model <skin>_nohat.tik`, then head attach (the helmet.scr:398 recipe mirrored, not
  called), then third-person glove surface bits; first person via E3.
- Free tier per U6; F5 bot dressing.
- Runtime: skin, head and glove screenshots (preview and world), and a respawn-flash check (decides E4b).

### Step 9 - Axis cosmetics

- 9a: the 25 retail bodies worn as shipped; head slot = Standard Issue, No Helmet, Eyeglasses, Aviator.
- 9b: gen_mpx_bodies.py hatless hzmax_* forks with _fps twins and glove lists, Standard Issue pieces, Axis
  head props.
- Runtime checks:
  - fit on Italian skeletons;
  - the first person of a fork;
  - `grep -a hzmax_` in bot model picks = 0;
  - the stock model picker does not list hzmax_*.
- Coop regression adds: disguise on m2l2a still wears german_waffenss_officer (HRRTM copy) unchanged.

### Step 10 - engine build C (E6, optional E7)

- An Axis player in an Italian hzmax_ body -> `nationalityprefix` returns `denit`, and instant-message
  voice is Italian.
- An American player's voice is unchanged.
- Coop: disguised coop players' voice is unchanged, because coop_mpRun is never 1.

---------------------------------------------------------------------------------------------------------------

## E. Risks and open questions

**User decisions (each with a recommendation):**
- **U1 Interim unlocks.**
  - Rec: only the P1 starters unlocked, lock UI live, and hover text naming MP progression as coming.
  - Rec: add a dedicated-server-only `g_mpArmoryUnlockAll` (H6 family, default 0, never seta'd by any
    shipped cfg) for testing every tile.
  - Shipping everything unlocked and taking it away later would be a visible regression for players.
- **U2 P3 scope.** Rec: P3 applies to scoped or zoom variants of non-sniper service weapons (scoped Garand,
  scoped StG44, SVT, G43). Purpose-built sniper rifles stay SNIPER. Read literally, the SNIPER class loses
  nearly every gun.
- **U3 Axis starters.**
  - Rec SNIPER = Kar98K Sniper (the stock kit under DF_OLD_SNIPER), not the G43 that U2 moves to RIFLE.
  - Rec SHOTGUN = Trench Gun (P11).
  - Rec the Gewehrgranate is a gated ROCKET tile (engine class stays shotgun for dmflags).
- **U4 mpoptions ownership.** Rec: accept. In coop sessions ESC > Multiplayer Options becomes the MP side
  picker, and the "Allies Player Model -> coop armory" button there goes away. F7, the lobby and ARMORY keep
  the coop armory.
- **U5 ARMORY button.** Rec: in an MP session it opens the side armory; everywhere else, including the
  disconnected main menu, it stays the coop armory.
- **U6 Free cosmetic tier** (interim unlocks and F5 bots).
  - Rec Allied: the free coop pages that pass A2 (s06, s14, s34, s55), Standard Issue, No Helmet, Bare,
    Leather.
  - Rec Axis: all 25 retail bodies (the stock model picker already offers them), Standard Issue, No Helmet,
    Bare, Leather.
- **U7 Allied MP first-person gloves on the MP glove cvar too.** Rec yes. Writing coop_gloveIdx from MP
  would persist into coop.
- **U8 Grenade parity.** Stock BT kits give a frag AND a smoke (player.cpp:10998-11024). Rec: when slot 3
  holds a frag, also give the side's smoke, so MP is not weaker than stock.
- **U9 SAPPER tab.** Rec: its own tab, landmine maps only, with no progression class in v1 (P2 lists none).
- **U10 Engine queue.** Rec: build A (server-only game.dll) takes the next shared-build turn after the
  current visual build, then build B.

**Risks:**
- **R1 Stranding in spectate.** ESC sends nothing; a stock cgame drops the exec; pushes are lost inside the
  menu lock; g_inactivekick is 900 s.
  - Mitigation: the 25 s server timer is the authority, and the armory liveness check falls back to today's
    rifle deploy.
- **R2 Name-bus limits** (32 bytes; server clean-up racing the next click).
  - Mitigation: one 7-character marker per click, a dispatcher that consumes every marker, per-frame ticks
    while holding, and server chips as the truth. E1 retires the race for defaults.
- **R3 dm_playermodel is shared with coop.** InitModel dresses MP players in their coop skin for a frame on
  every respawn. Mitigation: re-model in the spawn frame (delegate probe) or E4b.
- **R4 E4 on broken or tour maps.** Mitigation: the compile-success gate, the three level-variable gates,
  and the scratch parse-killer test in step 6.
- **R5 Preview leaks without E7.** The coop glove index shows on the MP mannequin, and Axis baked helmets
  stack under a head prop. Cosmetic only; E7 fixes both.
- **R6 Blind URC surface.** Screens cannot be observed from the dev box. Mitigation: generated layout,
  screenshots per tab, revert on the second failure (docs/21-user-preferences.md).
- **R7 Self-test anchor.** The first ENGINE_MP_HOOKS entry breaks HOOKS_ANCHOR and blocks every build until
  it is reworked. Planned into step 6.
- **R8 xw pak.** About 28 roster tiks exist only in zzzzz_xw_weapons.pk3 (progression 5.1), most of them
  slice-1 tiles. It ships in the 1.5.3 manifest, but a third-party server without it would hand out missing weapons. Mitigation: mp_armory.scr
  denies an mpid whose give tik fails to spawn (probe line), falling back to the starter.
