# Standard MP + co-op coexistence: the `g_modernmp` plan

> Produced 2026-08-30 by a 13-agent survey (6 surfaces mapped, every finding adversarially
> verified, then one design pass) against the requirement the user set:
>
> *"honestly if it could be an on/off switch for server hosts that would be ideal. by default
> I'd like those mechanics all enabled in mp, but a simple switch to toggle it off to be more
> like classic mohaa."*
>
> Decision record: `docs/DECISIONS.md` - "Standard MP: ONE host switch, modern mechanics ON by
> default". Verified coupling counts: 59 CONFIRMED, 3 UNDERSTATED, 19 OVERSTATED, 2 WRONG.

## Verdict

Feasible, and the switch itself is the small part. The replication channel already exists end to end — a CVAR_SERVERINFO cvar is rebuilt into CS_SERVERINFO by SV_Frame (openmohaa-hzm/code/server/sv_main.c:1120-1122) and re-parsed by cgame on `case CS_SERVERINFO: CG_ParseServerinfo();` (code/cgame/cg_main.c:539-540), so one cvar plus two lines in CG_ParseServerinfo (code/cgame/cg_servercmds.c:125-140) reaches every client, and one pmove_t field beside the existing coopCoverLeanSide (code/fgame/bg_public.h:314) reaches the shared predictor with no protocol change. The discriminator is equally small and already half-built: coop is opt-in per map via level.coop_mainScriptLoaded (coop_mod/main.scr:46 → :327) and only needs a Level flag copied verbatim from the m_bStealthNative getter/setter pattern (level.cpp:185-203, :683-684, :2162-2170) to reach the engine. What is large is everything the switch cannot touch: the coop pk3's global/ and ubersound/ overrides load in every gametype because pak priority is global, 60 stock ui/hud_ammo_*.urc are shadowed by empty stubs, the stock SelectPrimaryWeapon menu is destroyed at UI init, and ~333 forced lines in autoexec.cfg execute AFTER the player's saved config (common.c:1848 then :1862). So OFF cannot honestly mean "classic" until a packaging pass lands, and that pass is most of the work. Two things also have to be fixed before a switch is even meaningful: player-vs-player damage is currently zeroed in every MP gametype (sentient.cpp:1706-1712), and standard MP is unstartable for the default allied model because the weapon picker menu was deleted.

## The switch

NAME: `g_modernmp`. Default "1" (modern mechanics ON in standard MP, which is what the user asked for). `g_modernmp 0` = classic MOHAA feel.

FLAGS: `CVAR_SERVERINFO | CVAR_ARCHIVE | CVAR_LATCH`, registered in `G_InitGame` (code/fgame/g_main.cpp:258) inside the existing pre-registration block at :283-345 — that block exists precisely so an engine default beats a script `getcvar`, which creates cvars EMPTY (bug-1669, documented at g_main.cpp:271-283). Registering here also means the latch is applied on every map load, because G_InitGame runs on every map load.

WHY SERVERINFO AND NOT SYSTEMINFO: SYSTEMINFO keys really are set as cvars on the client (code/client/cl_parse.cpp:487-497), but a client cvar that does not already carry CVAR_SYSTEMINFO or CVAR_SERVER_CREATED is refused with "server is not allowed to set %s" (cl_parse.cpp:492-496) — and cgame would register its own copy without that flag. SERVERINFO is the route cgame already uses for exactly this: CG_ParseServerinfo pulls g_gametype/dmflags/fraglimit/timelimit straight out of `CG_ConfigString(CS_SERVERINFO)` (cg_servercmds.c:134-140) and mirrors them into cg_* cvars (:148-152).

REPLICATION, all existing plumbing:
  server: any SERVERINFO cvar change → `SV_SetConfigstring(CS_SERVERINFO, Cvar_InfoString(CVAR_SERVERINFO))` (sv_main.c:1120-1122; also at spawn, sv_init.c:937-938)
  client: gamestate/configstring update → `CG_ProcessConfigString` → `case CS_SERVERINFO: CG_ParseServerinfo()` (cg_main.c:539-540); parsed once at connect (cg_main.c:725) and on CG_ServerRestarted (:758)
  cgame: add `cgs.modernmp = atoi(Info_ValueForKey(info, "g_modernmp"));` plus `cgi.Cvar_Set("cg_modernmp", ...)` beside cg_servercmds.c:148 so .urc widgets can use `enabledcvar` too.
MISSING KEY MEANS CLASSIC. Info_ValueForKey returns "" → atoi 0. A retail server, an upstream OpenMOHAA server, or any build older than this change therefore reads classic. That is correct by construction: game.dll and cgame.dll ship together, so the key exists exactly when the modern server does.

THE PMOVE HALF IS NOT A CVAR. bg_pmove.cpp compiles into cgame.dll as well as game.dll (code/cgame/CMakeLists.txt:21 GLOBs "../fgame/bg_pmove.cpp" into the cgame target), and its own banner at bg_pmove.cpp:40-52 states the tuning values are constants deliberately, because "a cvar could differ between the two; a constant cannot". So add `qboolean modernMove;` to pmove_t beside `coopCoverLeanSide` (bg_public.h:314) — pmove_t is side-local, not on the wire, and coopCoverLeanSide already establishes the pattern. Server fills it in Player::SetMoveInfo next to player.cpp:4410; client fills it in cg_predict.c next to :661. Both sides then select one of two constant sets (5.5/4.5/0.72 modern vs upstream 8.0/6.0/0.80) and branch PM_Friction's stance floor (bg_pmove.cpp:205-226) and PM_CmdScale's L1 diagonal blend (:293-344).

ONE READ SITE PER SIDE, never a scatter of cvar reads:
  fgame:  `bool G_ModernOn()  { return level.m_bCoopSession || g_modernmp->integer; }`
  cgame:  `qboolean CG_ModernOn(void) { return cgs.coopSession || cgs.modernmp; }`
  pmove:  `pm->modernMove`
Co-op IGNORES the switch — co-op is always modern, because DBNO/sprint/prone are load-bearing there. That is a deliberate decision, stated so a host is never surprised.

THE SWITCH GATES AT THE CALL SITE, NOT BY ZEROING CVARS. fgame registers 244 unique coop_*/g_coop* names across 317 sites and only 36 default to "0" (reproduced: `grep -rhn 'Cvar_Get("\(coop_\|g_coop\)' code/fgame/*.cpp`), so "it is cvar-gated" is true for 36 features and false for 208 — and three of the biggest (turret overheat at weapturret.cpp:887-957, the two hard-coded coop script launches at weaputils.cpp:3578-3587 and weapon.cpp:1908-1920, and the pmove constants) have no cvar at all. Keep the per-feature cvars as tuning knobs underneath the switch.

MID-GAME FLIP: LATCHED, take effect at the next map load. Three code-grounded reasons.
1. Prediction. The server's value changes on the frame it is set; the client's arrives one CS_SERVERINFO update later. Every frame in between is a pmove mismatch, and pmove is the one thing that must be bit-identical on both sides.
2. The statemap. `g_statefile` is read once per player in Player::LoadStateTable (player.cpp:6480-6483) from Player::Init (:2609). Flipping mid-map leaves already-spawned players on the other animation set — the exact leak the bootstrap survey found on coop→DM transitions.
3. Precedent in this engine: `g_gametype` itself is `CVAR_SERVERINFO | CVAR_LATCH` (sv_init.c:1068).
Mechanically, `set g_modernmp 0` mid-round prints the standard "will be changed upon restarting" and is applied at the next `Cvar_Get` registration, i.e. the next G_InitGame. Serverinfo continues to publish the value actually in force, so what the host and the clients see always agrees with what is running.

## The discriminator (separate from the switch)

THE TEST IS "the map script called coop_mod/main.scr::main and it completed" — never gametype, never the map name, and never the switch.

SCRIPT SIDE (exists today). `level.coop_mainScriptLoaded` is set to 0 at coop_mod/main.scr:46 (right after the re-entry guard at :43-45) and to `game.true` at main.scr:327. `game.true = bool 1` (coop_mod/variables.scr:19). The single-player early-out at main.scr:102-105 (`if( level.gametype == 0 ){ thread spWaitForPlayer; end }`) returns 223 lines BEFORE :327, so the value is 1 only after a completed non-SP coop boot.
Use `if (!level.coop_mainScriptLoaded){ end }` — booleanValue() returns false for VARIABLE_NONE (code/script/scriptvariable.cpp:843-846) and the VM uses it for every if/while/!/&& (scriptvm.cpp:1228, 1232, 1244, 1250, 1823). Do NOT write `!= NIL` (true in single-player, because :46 already wrote 0) and do NOT write `== game.true` (game.true is itself NIL when coop never booted, so NIL == NIL passes).
DO NOT BUILD ON `coop_active`. autoexec.cfg:8 sets it 0 once at launch, coop_mod/cfg/detect.cfg:7 sets it 1 on coop join, and nothing ever clears it — after one coop session it stays 1 for the rest of the process, including on the next DM server. It also lives in the `coop_` namespace that cg_servercmds_filter.cpp:173 lets ANY server write.

ENGINE SIDE (new, ~30 lines). `qboolean Level::m_bCoopSession`, cleared in `Level::Init` beside `m_bStealthNative` (level.cpp:797) so it cannot survive a map change, a console `map`, a crash or a dedicated restart — the reasoning is already recorded at level.h:157-162. Expose it with a getter/setter Event pair named `coopsession`, copied verbatim from EV_Level_Get/SetStealthNative (declarations level.cpp:185-203, response-table rows :683-684, implementations :2162-2170). coop_mod/main.scr sets `level.coopsession = 1` on the line beside `level.coop_mainScriptLoaded = game.true` (main.scr:327).

PROPAGATION TO THE CLIENT, on the same channel as the switch. `Level::SetCoopSession` also does `gi.cvar_set("g_coopsession","1")`; `Level::Init` does `gi.cvar_set("g_coopsession","0")`. Register once in G_InitGame as `CVAR_SERVERINFO | CVAR_ROM` — ROM so console/rcon cannot forge it (Cvar_Get and the non-forced set path refuse ROM changes: cvar.c:453, :584, :667) while `gi.cvar_set` forces. The cvar is a MIRROR, never the authority: it is rewritten on every Level::Init, which is what makes it structurally incapable of the leak that g_statefile suffers (an unlatched cvar survives the game module being unloaded on every different-map load, sv_game.c:1597-1609).

THE WINDOW BEFORE THE FLAG IS KNOWN — order established by reading Level::SpawnEntities (level.cpp:1121):
  1. world spawn (:1154-1156), PathManager.LoadNodes (:1161)
  2. every BSP entity spawns (:1171-1206). This is where the 429 model TIKI `init { server { exec coop_mod/... } }` hooks fire — verified `grep -rl "exec coop_mod/" models/` = 429 (1 aihandler, 428 itemhandler; e.g. models/human/new_generic_human.tik:7-13)
  3. `PostEvent(EV_Level_PreSpawnSentient)` then `L_ProcessPendingEvents()` (:1218-1221) → Level::PreSpawnSentient → `Director.ExecuteThread(m_mapscript)` (:1494) → maps/<map>.scr::main → `waitthread coop_mod/main.scr::main`, which by project rule contains no wait/waitframe and therefore completes synchronously. THE FLAG IS SET BEFORE SpawnEntities RETURNS.
  4. `dmManager.InitGame()` (:1226-1228), then prespawn/spawn, then clients enter.
SAFE DEFAULT: 0 (not co-op). PROOF IT CANNOT MIS-FIRE A CO-OP SYSTEM IN MP:
  • In standard MP the correct answer throughout the window is "not co-op", and 0 gives exactly that. There is nothing to prove on the MP side — the default IS the answer.
  • On a co-op map the window is a false negative for steps 1-2 only. Every co-op engine subsystem the surveys identified is reached from Player::ClientThink (player.cpp:5655; tick blocks :5688-5696 and :5792-5810), Player::Postthink (:17585), Weapon::Shoot under `owner->client` (weapon.cpp:1814, :1961-1969), Weapon::ApplyFireKickback (:2900), or TurretGun::P_ThinkActive with an owner (weapturret.cpp:820). Every one of them requires a Player object. No Player exists in the window: level.cpp:1230-1233 pre-creates one only when `game.maxclients == 1 && g_gametype == GT_SINGLE_PLAYER`; in all other cases Player::Init runs at client entry, after SV_SpawnServer returns. The co-op code that genuinely does run at spawn — the Sentient/Player constructor seeds (sentient.cpp:823-836, player.cpp:2262-2401) and Sentient::SetBloodModel's CacheResources (sentient.cpp:980-985) — is unconditional today and stays unconditional; it is not part of this gate.

THE TRAP THAT WOULD MAKE THIS INERT. `coop_mod/main.scr::inCoopMode` (main.scr:2027-2045) must NOT simply become the flag. It is evaluated SYNCHRONOUSLY at entity-spawn time (step 2) by all 429 TIKI hooks — aihandler.scr:23 `if (!waitthread coop_mod/main.scr::inCoopMode){ end }` and itemhandler.scr:38 — i.e. before the flag exists. Replacing its body with the flag switches all 429 hooks OFF on real co-op maps. The correct edit is in the two handlers:
    if (!self){ end }
    waitframe                                   // step 3 has now run
    if (!level.coop_mainScriptLoaded){ end }
    if (!self){ end }
Both handlers already block immediately afterwards (`waitthread coop_mod/main.scr::waitForMainScript`, and aihandler.scr:44 `wait game.ms`), so this removes a wait rather than adding one.
This also fixes a live co-op defect. `mapname` carries the directory — sv_init.c:729 sets it from SV_Map_f's raw argument and the MP picker builds "dm/mohdm1" (cl_uimpmappicker.cpp:296; coop_mod/cfg/maptour.cfg:8 `set ui_dmmap dm/Ramelle`) — so isCoopEnabledMap (main.scr:2051-2070) switches on 'd'/'o' and returns FALSE for all 23 of the mod's own arenas under maps/dm and maps/obj, every one of which calls `waitthread coop_mod/main.scr::main`. The AI handler and item handler have therefore never run on any of them.
Keep isCoopEnabledMap for the menu/map list only. Leave inCoopMode as the pre-script answer but harden it to `end(level.coop_mainScriptLoaded || (local.isCoopMap && level.gametype))`, so it becomes authoritative the moment the flag exists and stops guessing for the rest of the map.

## bug-330 / the crash

HONEST LIMIT FIRST. The tree that crashed is not recoverable from this repo. The engine's HZM history is two squashed checkpoints — `eaac51be 2026-07-01 "HZM coop: engine working baseline (restore point)"` and `06e36f7d 2026-08-03` — with nothing between them, so `git log -S` reports one of those two dates for every HZM change and cannot separate the state on 2026-07-07 from the state a fortnight later. Any narrative about "what the code looked like then" would be invented. bug-330 itself says root cause UNRESOLVED and no later buglog entry re-reports it.

MOST PROBABLE ROOT CAUSE: precache index exhaustion on the coop content set, taken on a code path that was fatal at the time.
The evidence is first-hand and still in the file. code/server/sv_init.c:193-196 — "HZM: warn and return 0 instead of fatal error — coop mod precaches >512 sounds in MP mode. Slot 0 = 'no sound' which is safe. Sounds past the limit just don't play." That is a contemporaneous record that this overflow WAS being hit, IN MP MODE, on this content, and that the pre-fix behaviour was fatal. Every index funnels through the same function: SV_SoundIndex → SV_FindIndex(name, CS_SOUNDS, MAX_SOUNDS) (sv_init.c:235) and SV_ModelIndex → SV_FindIndex(name, CS_MODELS, MAX_MODELS) (:210). It is reached from fgame's CacheResource during Level::Precache (level.cpp:1600-1640) and during entity spawn — exactly "loading the map" — and a Com_Error longjmp out of gi.soundindex unwinds across the DLL boundary through C++ frames without running destructors, leaving the game module half-initialised. That is a crash, not a clean drop.
Magnitude (the globals verifier's measurement, reproduced from the engine's own bLoadForMap rule — not mine): a plain dm/mohdm1 load registers 6870 alias entries (4814 `alias` + 2056 `aliascache`) against retail's 1589, precaching 1396 unique sound files against retail's 413. `aliascache` reaches gi.soundindex via RegisterAliasAndCache → CacheResource (scriptmaster.cpp:443-500, g_utils.cpp:1569-1605). So the coop ubersound overrides alone consume roughly two thirds of today's 2048-slot budget before the map registers anything of its own; at the older 512/1024 ceiling they exceed it outright.
The DM-vs-coop asymmetry: stock MP maps additionally exec global/DMprecache.scr — 337 `cache` lines, almost all models/player/* and every MP weapon (original-scripts/breakthrough/global/DMprecache.scr) — which co-op campaign maps never run. It partially overlaps Level::Precache's own non-SP player-model sweep (level.cpp:1618-1638), so I will not claim the delta is large; only that it is the one asymmetry on the load path pointing in the right direction.

SECOND CANDIDATE, and not weak: the sound-done callback abort logged as bug-931 and fixed 07-20, i.e. AFTER bug-330. G_SoundCallback (g_main.cpp:1063-1097) previously raised a ScriptError from a callback "invoked by the CLIENT sound system across the DLL boundary - there is NO script-VM exception handler above it, so the old ScriptError here THREW straight into std::terminate -> abort (0xC0000409)", and the in-code note records it firing "at e1l2 map load right after the spawn FadeSound". Map-load abort, same shape. Its DM/coop asymmetry is plausible via Entity::Sound (entity.cpp:3690-3699), where the non-SP callback suppression is now taken only when the `dedicated` cvar is set — and bug-330 was reported on a dedicated server.

THIRD: already fixed incidentally. Three ScriptError→guard conversions of exactly the "a map the coop scripts never initialised" shape sit at g_main.cpp:1074-1090, trigger.cpp:445-448 and entity.cpp:2137-2139. Given the squash, the dating that put two of them after the report is weak evidence.

THE ONE-BOOT DIAGNOSTIC — every line it needs already exists in the build; nothing has to be added:
  openmohaa.exe +set dedicated 1 +set developer 1 +set logfile 2 +set com_target_game 2 \
                +set g_gametype 4 +set sv_maxclients 8 +set maxentities 2048 +map obj/obj_team1
then grep qconsole.log, in this order:
  1. `^~^~^ FPRINT game <date> <time> ENTBITS=%d MAX_SOUNDS=%d` (g_main.cpp:265-268) — proves which game.dll loaded and what its limits are. Absent ⇒ the fault is before G_InitGame and none of these hypotheses apply.
  2. `WARNING: SV_FindIndex overflow (max=%d, start=%d): %s` (sv_init.c:195). PRESENT ⇒ hypothesis 1 confirmed, and `start` says sounds (CS_SOUNDS) or models (CS_MODELS). ABSENT ⇒ hypothesis 1 is dead, because the fatal it replaced can no longer be reached.
  3. `-------------------- Actual Spawning Entities Done ------------------ %i ms` (level.cpp:1211). Reached ⇒ the fault is at or after the map script (`Adding script: 'maps/obj/obj_team1.scr'`, level.cpp:1492). Not reached ⇒ it is in world spawn or entity spawn, which points at the 429 TIKI hooks and at ProcessInitCommands.
  4. `^~^~^ Callback of sound '%s' ignored.` (entity.cpp:3697) — presence proves the dedicated suppression branch is live, retiring hypothesis 2 for this boot.
Run the identical command with `+map m1l1` as the control. Two boots, one grep, three hypotheses separated.

SECONDARY FINDING, worth a buglog entry regardless of bug-330: SV_FindIndex dereferences `sv.configstrings[start + i][0]` with NO NULL guard (sv_init.c:167 and :181), while SV_PVSSoundIndex (:1264-1266) and SV_CleanupNonPVSSound (:1341) guard the same array explicitly. Configstrings are re-initialised to CopyString("") only in the `differentmap` branch of SV_SpawnServer (sv_init.c:684-687), and SV_ClearServer memsets them to NULL (:547-556, also called from SV_Shutdown at :1221). A spawn reaching SV_FindIndex after a clear without that re-init hands it a NULL to index. I did not prove that sequence is reachable — I am reporting the asymmetry, not claiming the bug.

## Honest exceptions - what OFF cannot turn off

| mechanic | gateable? | why it is stuck |
|---|---|---|
| The 72 global/*.scr overrides and the whole of ubersound/ load in EVERY gametype | `cheap-gate` | Pak priority is global, not per-mode. FS_AddGameDirectory prepends each pak (files.cpp:3136-3140) and the coop pk3 sorts last, so its copies of ambient.scr, exploder.scr, minefield.scr, weather.scr, friendly.scr, ai.scr, spotlight.scr, bomber.scr and disable_ai.scr win on every stock MP map that execs them — ambient.scr alone is exec'd by 34 stock MP map scripts. No cvar can un-shadow a file, and  |
| ubersound alias re-scoping — retail player_pain01-09 and player_death01-08 are permanently replaced by the coop definitions | `permanent-exception` | `alias` registration happens at G_RegisterSounds parse time with no per-alias condition, and Alias_ListAdd dedupes FIRST-WINS (qcommon/alias.c:313-354). The coop copies at ubersound/uberdialog.scr:2563-2570 and :2650-2658 are registered before retail's at :31073-31094, so retail's are discarded. 95 of the 96 duplicate names are retail names; 17 differ in volume (1.3→1.0), pitch jitter, min/max dis |
| 60 empty ui/hud_ammo_*.urc stubs delete the stock per-weapon ammo readout | `permanent-exception` | Every stock ui/hud_ammo_*.urc is shadowed (60 stock, 60 mod, 60/60 overlap, zero mod-only files) by a 5-line empty menu, and there is no fallback ui/hud_ammo.urc anywhere in the paks — these 60 files ARE the stock ammo HUD. Menus are built once from FS_ListFiles at CL_InitializeUI (cl_ui.cpp:5634-5645), long before any server exists, so no server cvar can restore widgets that are not in the VFS. T |
| ui/coop_weaponselect_suppress.urc destroys the stock SelectPrimaryWeapon menu for every gametype | `permanent-exception` | Same menu NAME in a different FILE (the stock one lives in ui/dm_primaryselect.urc). The coop pk3's copy is registered first and UIWindowManager::CreateMenus keeps the first and deletes the later duplicate (uiwinman.cpp:640-659) — proven live by the single line at G:/mohaa-gl2/home/maintt/qconsole.log:4691. Decided at UI init, so unreachable by any cvar. It makes standard MP UNSTARTABLE for the de |
| ~115 engine cvars forced by autoexec.cfg after the player's saved config | `cheap-gate` | `exec autoexec.cfg` runs at common.c:1862, AFTER configs/<name>.cfg at :1848 and coop_defaults.cfg at :1841, and the shipped autoexec is packed at the pak ROOT of zzzzzz_co-op_hzm_mod_code.pk3 as well as deployed loose to three targets by build.ps1:176-182. The engine reads the cvar, not the switch, so no runtime gate can undo a value re-forced every launch. Includes sv_dmspeedmult 0.6 (autoexec.c |
| coop_mod/cfg/lobbytest.cfg caps every server this build hosts at 4 players | `cheap-gate` | autoexec.cfg:1221 `exec coop_mod/cfg/lobbytest.cfg` is unconditional and the file resolves at the pak path it asks for. lobbytest.cfg:17-18 set sv_maxclients and ui_maxclients to 4; UI_StartDMMap_f reads ui_maxclients back and pushes it as sv_maxclients (cl_ui.cpp:3376-3384 and the Cbuf at :3452), and a dedicated `+map` boot keeps the already-created value against sv_init.c:422's default of 8. Bec |
| sv_team_spawn_interval 0 converts Team Match, Tug-of-War and Liberation from wave respawn to instant respawn | `cheap-gate` | coop_mod/start_server.cfg:32 sets it; the engine default is 15 for MOHTA+ (gamecvars.cpp:404) and it carries CVAR_ARCHIVE, so cvar.c:477-479 marks it for the config write and it survives a restart on every machine that has run this build. It drives DM_Manager::GetTeamSpawnTimeLeft (dm_manager.cpp:1770-1779) and the scheduling at :2027/:2032. This is a GAMETYPE RULE, not feel — the switch must neve |
| g_statefile leaks the co-op player statemap into the next map | `cheap-gate` | It is a plain unlatched cvar (gamecvars.cpp:431, default "global/mike") set by coop_mod/server.scr:23 and read once per player in Player::LoadStateTable (player.cpp:6480-6483) from Player::Init (:2609). The game module is unloaded on every different-map load (sv_game.c:1597-1609), which wipes game.* script state but cannot touch an engine cvar, so it is one of the few things that provably survives |
| Anything the statemap selects — sprint, prone, cover, ADS and emote poses — cannot be flipped per player mid-map | `cheap-gate` | LoadStateTable runs once at Player::Init, so a mid-map change leaves already-spawned players on the other animation set. coop_mod/player_Torso.st also carries 18 `exec coop_mod/*` hooks (:330 through :2225 weaponstate, :3230 events playerdeath, :3544-3645 ladder_state), so the statemap is a script entry point as well as an animation set; those three entry points must self-gate on the flag rather t |
| bg_pmove tuning constants and the PM_CmdScale / PM_Friction rewrites | `cheap-gate` | bg_pmove.cpp:53/:57/:61 are module-scope constants (5.5 / 4.5 / 0.72 against upstream 8.0 / 6.0 / 0.80) and the file's banner at :40-52 says they are constants DELIBERATELY, because the file compiles into both cgame.dll (cgame/CMakeLists.txt:21) and game.dll and "a cvar could differ between the two; a constant cannot". Turning them into cvars reintroduces exactly the client/server pmove divergence |
| cmpatch brush surgery rewrites world collision on every map in every gametype | `expensive-gate` | qcommon/cm_load.c:1239-1310 zeroes `cm.brushes[idx].contents` for every index listed in `cmpatch/<map>.txt` (shipped in the coop pk3) and again from a LOOSE `cmpatch/<map>_local.txt` overlay that no pk3 ships, inside CM_LoadMap — roughly 120 lines AFTER the map checksum is taken (cm_load.c:1117-1118), so nothing can detect a client/server disagreement. `cm_killbrush` / `cm_restorebrush` are regist |
| The mouse2 → BUTTON_COOPADS rebind and the client-side ADS zoom | `permanent-exception` | autoexec.cfg:1004 binds mouse2 to `+button13` (BUTTON_COOPADS_BITINDEX 13, q_shared.h:1976) and moves +attacksecondary to V (:1008); cg_adsZoom 0.5 (:102) stacks with cg_breathZoom 0.85 (:267) at cg_view.c:4676-4682 for roughly a 0.425 FOV multiplier. All of it is client-side and CVAR_ARCHIVE, so a server switch cannot revoke it and should not try — CG_AimingDownSights reads the LOCAL usercmd bit  |
| The network protocol fork | `permanent-exception` | GENTITYNUM_BITS 11 (q_shared.h:1667, packed on the wire at msg.cpp:1938/1943/2085/2090), MAX_MODELS 2048 (:1679), MAX_SOUNDS 2048 with SOUND_INDEX_BITS 11 (:1742/:1763, msg.cpp:3231/3299), MAX_WEAPONS 128 (:1776), MAX_CONFIGSTRINGS 8192 (:1801), the computed configstring block after CS_SOUNDS (bg_public.h:103-115) and a new STAT_MGHEAT. None of it is conditional. No switch restores wire compatibil |
| 429 model TIKI files start a coop script thread on every spawning weapon, ammo box, health box and human actor | `cheap-gate` | `init { server { exec coop_mod/aihandler.scr "actorHandler" } }` / `itemhandler.scr "initialiseItem"` are TIKI data (models/human/new_generic_human.tik:7-13 and 428 others); ProcessInitCommands runs them for every spawning entity regardless of gametype, before the map script exists. The script can gate its own body, but the thread will always be created — so a busy DM map pays 429-plus thread star |

## Staging

### Stage 1 - Unblock standard MP — it is currently unstartable and mis-configured before any switch exists  *(small)*

**Ship unit:** pk3 (plus the loose autoexec.cfg / coop_defaults.cfg that build.ps1:176-189 deploys)

**Work.** pk3/cfg only, no code. Delete ui/coop_weaponselect_suppress.urc (it destroys the stock SelectPrimaryWeapon menu, uiwinman.cpp:640-659). Remove sv_maxclients/ui_maxclients from coop_mod/cfg/lobbytest.cfg:17-18 (they cap every hosted server at 4). Split autoexec.cfg: move sv_dmspeedmult (:24), the penetration trio (:250-256), g_adsRecoilKick (:244), g_droppeditemlife (:375), sv_fps (:736) and the dev/ragdoll/armory/numpad binds (:1326-1346, :345-354, :76-78) into a coop-only cfg exec'd from coop_mod/start_server.cfg; delete `set developer 1` (:40, whose own comment says REVERT) and the rcon lines (:13, :17) from the shipped file, and add autoexec.cfg to build.ps1's $excludeNames so the pak stops shipping a published rcon password. Restore `stuffcommand "playermodel 0"` on ui/multiplayeroptions.urc:174 and give the Armory its own button. Remove sv_team_spawn_interval 0 from coop_mod/start_server.cfg:32 and restore the engine default for standard MP.

**Proof it actually runs.** Cold boot `+set dedicated 1 +set g_gametype 2 +map obj/obj_team1`. qconsole.log must NOT contain `dropping duplicate menu container 'SelectPrimaryWeapon'`. Over rcon: sv_maxclients = 8, sv_dmspeedmult = 1.1, cheats = 0, sv_team_spawn_interval = 15, `bind F1` = `vote y`. Then join: the weapon picker must draw, a primary must be selectable, and the player must leave spectator and spawn.

### Stage 2 - Restore player-vs-player damage — no MP gametype can currently score a kill  *(trivial)*

**Ship unit:** game.dll

**Work.** sentient.cpp:1706-1712. The upstream leading clause `((g_gametype->integer != GT_SINGLE_PLAYER) || ...)` was deleted, making the same-team damage filter unconditional; Sentient::m_Team is TEAM_AMERICAN for every MP client because the only three writes in the module are the constructor (sentient.cpp:892) and the script events german/american (:4933, :4962), so attacker->m_Team == m_Team and `health -= damage` is skipped. MP teams live in the separate client->pers.dm_team namespace and never feed m_Team. Restore the clause; once stage 4 lands, key it on G_CoopSession() instead of the raw gametype. Note the guard ignores meansofdeath, so bash and MOD_TELEFRAG are zeroed too — only world damage currently survives.

**Proof it actually runs.** Two clients on obj/obj_team1 with `coop_dmgProbe 1` (player.cpp:11494-11522): a DMG line per hit and health visibly falling. Then two clients on m1l1 in co-op: a teammate hit must print nothing and take no health.

### Stage 3 - bug-330: measure it, and clamp the world-edict allocation  *(small)*

**Ship unit:** game.dll

**Work.** Run the two-boot diagnostic in crashPlan (no code change) and log the result to .wolf/buglog.json whichever way it falls. Separately, clamp game.maxentities to MAX_GENTITIES in G_AllocGameData (g_main.cpp:194-201): ENTITYNUM_WORLD is the compile-time constant 2046 (q_shared.h:1667/:1674) and level.cpp:1156 sets spawn_entnum = ENTITYNUM_WORLD and constructs the world edict at that index before g_spawn.cpp:1253-1254 ever runs, so an operator `+set maxentities 1024` writes ~2.4 MB past the end of the block on the first spawn. Add the clamped value to the existing FPRINT line.

**Proof it actually runs.** The four log lines listed in crashPlan, from obj/obj_team1 and the m1l1 control. For the clamp: boot with `+set maxentities 1024` — the `^~^~^ FPRINT game` line must report the clamped value and the map must load without a fault.

### Stage 4 - The discriminator — build the predicate that ten later gates depend on  *(medium)*

**Ship unit:** game.dll + pk3

**Work.** Add Level::m_bCoopSession, cleared in Level::Init beside m_bStealthNative (level.cpp:797). Add a `coopsession` getter/setter Event pair copied from EV_Level_Get/SetStealthNative (level.cpp:185-203, response rows :683-684, impls :2162-2170). Add G_CoopSession(). Add the g_coopsession SERVERINFO|ROM mirror, written from SetCoopSession and cleared in Level::Init. In coop_mod/main.scr add `level.coopsession = 1` beside :327. Rework aihandler.scr:23 and itemhandler.scr:38 to the deferred test (waitframe, then `if (!level.coop_mainScriptLoaded){ end }`) so the 429 TIKI hooks stop guessing from the map name. Harden inCoopMode to `end(level.coop_mainScriptLoaded || (local.isCoopMap && level.gametype))`.

**Proof it actually runs.** Add one line to the existing FPRINT block: `^~^~^ COOPSESS map=%s coop=%d` printed on the first server frame. Must read coop=1 on m1l1 AND on dm/Ramelle (which today reads 0 despite booting coop), and coop=0 on obj/obj_team1 and on m1l1 launched with g_gametype 1. On m1l1, coop_selftest_scaling.scr (which already reads coop_mainScriptLoaded at :63) must still pass, and the AI/item handlers must still initialise — count them with a one-shot `^~^~^ COOPHOOK actors=%d items=%d` print.

### Stage 5 - The switch, server side  *(large)*

**Ship unit:** game.dll

**Work.** Register g_modernmp and G_ModernOn(). Gate at the call site: the 13-tick block (player.cpp:5688-5696, :5792-5810) and the four usercmd rewrites (:5721-5726, :5731-5733, :5735-5776, :5779-5789, :5801-5803); Postthink blood/grenade-kick/vault (:17597, :17614-17688, :17746-17762) and make the blood cvar pointer static; the FT_BULLET spread terms (weapon.cpp:1983-2085 and the duplicate at :2400-2470) and CoopApplyAuthoredKick (:2929); penetration and accuracy (weapon.cpp:2295-2312, weaputils.cpp:2725-2738, :2763-2771); the one-mag ammo economy (weapon.cpp:3869-3969, which today overrides `dm startammo` for every ground and corpse pickup); turret overheat (weapturret.cpp:887-957); the two hard-coded coop script launches (weaputils.cpp:3578-3587, weapon.cpp:1908-1920) and drop their two unconditional gi.Printf; pain tiers (player.cpp:3860-3879); disguise parity (:6040-6068); the ten coop stufftext publishers; and the GUNNERPROBE print at :5812-5827.

**Proof it actually runs.** On a `g_modernmp 0` DM server: `coop_stressDebug 1` and `coop_proneDebug 1` (player.cpp:14263, :13995) print nothing; STAT_MGHEAT stays 0 while a player holds a turret trigger (published every frame at weapturret.cpp:988); qconsole.log carries no COOP_SMOKE_CHECK, no `^~^~^ KICKICON` and no `^~^~^ GUNNERPROBE`; a Kar98 picked off the ground gives its `dm startammo`, not one clip. Every one of those must still fire on a coop map with the same cvar still 0.

### Stage 6 - The switch, client side  *(medium)*

**Ship unit:** cgame.dll

**Work.** Parse g_modernmp and g_coopsession in CG_ParseServerinfo (cg_servercmds.c:125-140) into cgs and mirror them into cg_* cvars beside :148. Add CG_ModernOn()/CG_CoopSession(). Gate the CG_Draw2D coop layer (cg_drawtools.cpp:2657-2682 — skip CG_DrawCoopIcons, it is an empty stub at cg_modelanim.c:370-372), the PMF_COOP_COVER third-person forces (cg_view.c:5437, cg_modelanim.c:1733, cg_view.c:4258) and the lean fill (cg_predict.c:661-664), the three key swallows (cg_ui.cpp:205-217, :218-241, :254-262), the daylight grade (cg_view.c:6097-6165) plus add coop_daylight to hzmClearFx (cg_main.c:824), the hit marker (cg_parsemsg.cpp:2032-2044), the damage indicator (cg_drawtools.cpp:2416-2442) and the suppression vignette (cg_parsemsg.cpp:986-989). Narrow the coop_ namespace blanket at cg_servercmds_filter.cpp:173 to non-archived forms (it currently lets any server `seta` coop_clipStripZones, which rewrites the client's collision tracemask at cg_predict.c:589-631) and replace the exec directory-prefix test at :337-349 with an explicit allow-list.

**Proof it actually runs.** Connect to a `g_modernmp 0` DM server: no hit pip on a hit, no directional damage arc, no near-miss vignette, no colour grade change on the first frame, crouching still for two seconds does not flip to third person, and the mouse wheel still cycles weapons while in third person. Connect to the coop server and all of them return. `seta coop_dbnoView 1` sent from a server must be refused with the existing WARNING line.

### Stage 7 - pmove and the overloaded prone bit  *(medium)*

**Ship unit:** game.dll + cgame.dll TOGETHER (bg_pmove.cpp compiles into both, cgame/CMakeLists.txt:21)

**Work.** Add `qboolean modernMove` to pmove_t beside bg_public.h:314; fill it server-side near player.cpp:4410 and client-side near cg_predict.c:661. Select one of two constant sets for pm_accelerate/pm_friction/pm_backspeed (bg_pmove.cpp:53/:57/:61) and branch PM_Friction's stance floor (:205-226) and PM_CmdScale's L1 diagonal blend (:293-344). Separately fix the PMF_VIEW_PRONE / PMF_DAMAGE_ANGLES aliasing: they are the same bit (bg_public.h:257-258) and bg_pmove.cpp:1109 collapses the hull to 20u / viewheight 16 while :1407-1410 kills lean, both keyed on a bit the engine also sets for the damage-angles reason (player.cpp:8125). Mirror the real decision — player.cpp:15195 already computes it correctly — through the same pmove_t mechanism instead of the overloaded bit.

**Proof it actually runs.** Extend both FPRINT lines (g_main.cpp:265-268 and cg_main.c:796) with a pmove struct signature and refuse to predict on mismatch — that alone catches a half-deploy, which is this project's most-repeated engine failure. Then on a classic server measure ps.speed over a fixed forward run and the same run with W+D: the diagonal must equal the straight-line value (today it is ~7.5% slower), and prediction error must stay zero over 60 s of movement on both settings.

### Stage 8 - Statemap selection becomes engine-owned  *(small)*

**Ship unit:** game.dll + pk3

**Work.** Level::Init sets g_statefile to "global/mike"; Level::SetCoopSession and the modern-MP path set "coop_mod/player" — both before any Player::Init can run, which the stage-4 ordering proof guarantees. Delete the script-side reset at global/ambient.scr:14-19 and the late repair at coop_mod/weaponstate.scr:9-16, or change their gate from inCoopMode to the flag. Self-gate coop_mod/weaponstate.scr::main, coop_mod/events.scr::main and coop_mod/ladder_state.scr on the flag so a leaked statemap can never drive coop script again.

**Proof it actually runs.** Start a coop mission, then `stuffsrv "map obj/obj_team1"`, then `rcon echo $g_statefile`: must read global/mike with g_modernmp 0 and coop_mod/player with 1. Repeat with obj/mp_bizertefort_obj and lib/mp_ship_lib — the two stock MP maps that never exec global/ambient.scr and therefore have no script reset path today.

### Stage 9 - Stop shadowing the stock HUD; draw the modern extras from cgame instead  *(medium)*

**Ship unit:** pk3 + cgame.dll (+ exe for the cl_ui.cpp fade exemption)

**Work.** Stop shipping the 60 empty ui/hud_ammo_*.urc stubs. Restore playerstat 17 / 18 (the objective-extent balls) to ui/hud_compass.urc and the numeric health readout plus the potential-health meter (playerstat 11) to ui/hud_health.urc, or ship the coop versions under distinct menu names. Move the modern magazine counter entirely into cgame under CG_ModernOn() — CG_DrawMagazines already exists (cg_drawtools.cpp:1977-2005, called at :2680). Add hud_score / hud_fraglimit / hud_timelimit to the HUD-fade exemption list that currently protects only coop_jeepEnter (cl_ui.cpp:1878-1884).

**Proof it actually runs.** Stock FFA with a fraglimit: the frag counter is still fully opaque after 10 idle seconds, and current-clip rounds are readable on screen. Stock TOW on obj/mp_kasserine_tow: the compass shows the objective-extent spread, not just the centre arrow. Coop m1l1: the magazine counter still appears.

### Stage 10 - Data scoping — ubersound and the reachable global/ overrides  *(large)*

**Ship unit:** pk3

**Work.** Remove `dm obj` from the 2313 re-scoped SP dialogue lines in ubersound/uberdialog.scr, or rename the 95 colliding retail names so retail's own definitions win the first-wins dedupe (alias.c:313-354). Convert every `level.gametype != 0` coop gate inside the eleven global/ overrides that stock MP maps actually reach to `level.coop_mainScriptLoaded`: weather.scr:146 and :327, minefield.scr:56, exploder.scr:193, bomber.scr:163, ambient.scr:15/:249/:301/:323, ai.scr, friendly.scr:372-375, mg42init.scr:112 and :193-194, pain.scr:54, weapon.scr:367 and moveto.scr:6-14 (the last is engine-invoked from Actor::RunTo at actor.cpp:4711 and currently sends every scripted actor to itself when coop is not initialised).

**Proof it actually runs.** Re-run the surveyor's bLoadForMap model on dm/mohdm1: the alias count must return to ~739 with 0 duplicate names, and the unique precached-sound count to ~413. `WARNING: SV_FindIndex overflow` must be absent from a DM boot log. Audibly, a DM death plays the retail player_death pool. On breakthrough/maps/obj/MP_Ardennes_TOW, `self runto self.target` must move the actor rather than freeze it.

## Competitive honesty

With `g_modernmp 1` this build is a MOD RULESET, not stock MOHAA, and a public server running it should advertise itself that way. Splitting the list into three honest buckets:

SYMMETRIC BUT NON-STANDARD (everyone gets it; the mode is simply not MOHAA any more).
Movement: sv_dmspeedmult 0.6 against the engine's 1.1 (autoexec.cfg:24, applied for every non-SP gametype at player.cpp:4961-4963 and baked into the sprint/aimed-walk floors at :4997/:5060/:5079) — roughly 55% of stock pace. pm_accelerate 5.5 / pm_friction 4.5 / pm_backspeed 0.72 against upstream 8.0 / 6.0 / 0.80 (bg_pmove.cpp:53/:57/:61), plus the L1 diagonal blend that makes W+D ~7.5% slower (PM_CmdScale, :293-344). Sprint at coop_sprintMult with a 30 s stamina pool (autoexec.cfg:287, :291-292 against engine 5 / 0.6) and coop_sprintNoFire stripping the fire buttons while sprinting (player.cpp:5721-5726, default on).
Lethality: coop_playerRifleSpread 0.5 halves every player's rifle cone (weaputils.cpp:2763-2771, engine default also 0.5). g_penChance 0.5 with g_bulletThroughAny 250 against engine 0.1 / 70 (autoexec.cfg:255-256 vs weapon.cpp:2305/:2308) — about half of all rifle and MG rounds ignore hard cover, on a block gated only by "the shooter is a player" (weapon.cpp:2299), a distinction that does not exist in PvP. coop_smgPenetrate gives SMGs a 10% any-surface punch (weaputils.cpp:2725-2738). Per-gun authored recoil replaces the flat kick for the whole retail arsenal (weapon.cpp:2929 → CoopApplyAuthoredKick, table at coop_mod/recoil_table.txt).
Economy and rules: coop_pickupOneMag clamps ground pickups to one magazine and makes a full player consume the pickup anyway (weapon.cpp:3869-3969) — on a DM map, ammo placement IS the balance. g_healrate 100000 against 10 (start_server.cfg:26 vs gamecvars.cpp:478) makes health packs apply instantly. g_droppeditemlife 60 against 30. sv_fps 40 against 20, doubling snapshot cost per client. sv_team_spawn_interval 0 converts Team Match, Tug-of-War and Liberation from wave respawn to instant (dm_manager.cpp:1770-1779) — that is a gametype rule, and it must be restored for standard MP regardless of the switch.

GENUINELY UNFAIR — asymmetric, and the server cannot fully revoke them.
cg_adsZoom 0.5 stacked with cg_breathZoom 0.85 (autoexec.cfg:102, :267 → cg_view.c:4676-4682). This is entirely client-side: CG_AimingDownSights reads the local usercmd bit and a local cvar (cg_view.c:4150-4189), so a player carrying this config gets ~2.3x iron sights on ANY server they join, including a stock one, while nobody else does. It should be OFF in standard MP even at g_modernmp 1, and it must not be forced from the shipped autoexec at all.
Auto-cover forced third person (player.cpp:16302-16312, coop_coverAuto default "1", no gametype term → cg_view.c:5437 and cg_modelanim.c:1733). A crouched, still player is put into third person without opting in. That is a wall-peek in a competitive mode, on by default. cg_3rd_person is also registered with flags 0, i.e. NOT cheat-protected (cg_main.c:165), and this fork made third-person aim accurate (cg_crosshair3p default 1, cg_drawtools.cpp:1534) — so third-person peeking is available to any client on any server and the server has no clean lever against it.

INFORMATION THE STOCK GAME DOES NOT GIVE.
Hit markers ride the stock CGM_NOTIFY_HIT/KILL messages that player.cpp:3819 already sends for every non-SP gametype (cg_parsemsg.cpp:2032-2044, coop_hitMarker default "1") — they confirm hits through smoke and geometry. The directional damage indicator (cg_drawtools.cpp:2416-2442, driven by the stock STAT_DAMAGEDIR) tells you the bearing of your attacker. The near-miss suppression vignette (cg_parsemsg.cpp:986-989 → cg_view.c:1249) tells you a round passed close. All three are meaningful DM balance changes rather than decoration, and all three should be listed to the host explicitly.

HONEST NEGATIVE, so nobody spends effort on it: the RADAR is NOT an added advantage. cg_radar.cpp has zero HZM edits and CG_IsTeamGame is still upstream's `cgs.gametype >= GT_TEAM` (cg_radar.cpp:51-53), with CG_ValidRadarClient unchanged. cg_scoreboard.cpp is likewise untouched, and the CGM message enum (bg_public.h:763-806) is unmodified — no new wire messages were added.

NOT A COMPETITIVE ISSUE BUT A HOSTING ONE, and it outranks everything above: `set rconpassword "hzmdev"` is at autoexec.cfg:13 and the file is packed at the root of the shipped public pk3 (verified: root entry autoexec.cfg, password present), so any server built from this tree accepts remote console with a published password. And `set developer 1` (autoexec.cfg:40) skips SV_Map_f's cheat reset (sv_ccmds.c:228-242), leaving `cheats` at its default of 1 on any server started by console, rcon or a dedicated `+map` — which is CVAR_SYSTEMINFO, so it reaches every client and stops them resetting their CVAR_CHEAT cvars (cl_parse.cpp:449-453), unlocking r_drawworld (tr_init.c:1960, i.e. see through all world geometry) and the `script` console command (gamecmds.cpp:688). Neither of these may ship on a build anyone hosts publicly.

## Risk to co-op (co-op is the shipping product)

CO-OP IS THE SHIPPING PRODUCT. Ranked by what could actually regress it.

1. The inCoopMode rework is the single riskiest edit in the plan — 429 spawn-time call sites plus ~15 global/ gates depend on it. If it is changed to read the flag naively, all 429 TIKI hooks evaluate it at entity-spawn time (level.cpp:1171-1206), before the map script has run (:1218-1221), and every actor and item handler dies on real co-op maps. GUARD: do not touch inCoopMode's early-window behaviour; put the authoritative test in aihandler.scr and itemhandler.scr behind one waitframe, and ship the `^~^~^ COOPHOOK actors=%d items=%d` counter in the same commit so a zero is visible in the first boot log rather than three sessions later.

2. Making the flag correct on the 23 arenas turns ON code that has never run there. maps/dm/*.scr and maps/obj/*.scr all call coop_mod/main.scr::main but fail today's name test, so coop_mod/aihandler.scr::main and coop_mod/itemhandler.scr::main have always ended at line 23/38 on those maps. Fixing the predicate enables AI difficulty scaling, item respawn and the weapon-juggle path on 23 maps at once — a genuinely untested path. GUARD: stage it separately from stage 4, behind a per-map opt-in (`level.coop_arenaHandlers`), default off, and turn it on a few maps at a time with playtests.

3. A half-deployed pair. Adding a pmove_t field costs no protocol change (precedent: coopCoverLeanSide, bg_public.h:314) but game.dll and cgame.dll must ship together or the field is garbage on one side and every player mispredicts. This project has shipped mismatched binaries before. GUARD: extend the two existing fingerprint prints (g_main.cpp:265-268, cg_main.c:796) with a pmove struct signature and refuse to predict on mismatch — cheap, and it converts a silent desync into a visible line.

4. The gate failing closed is the inverse inert-feature failure. If a coop map's script errors before main.scr:327, or a map author forgets `level.coopsession = 1`, co-op silently loses sprint, prone, ADS, cover and the spread model with nothing logged. GUARD: one cross-check print on the first frame after prespawn — if level.coop_mainScriptLoaded is set but Level::m_bCoopSession is 0 (or vice versa), print a loud `^~^~^ COOPSESS MISMATCH` line and an iprintlnbold to the host. Ten lines, and it makes the whole design self-testing.

5. Latching surprises the host. A coop or MP host who types `set g_modernmp 0` and sees nothing change will file it as broken. GUARD: print the standard latch message plus a one-line explanation, and echo the effective value in the FPRINT block at every map load so the log always answers "what was actually running".

6. g_statefile timing. If Level::Init resets it to global/mike and the script sets it back later, any player whose Player::Init lands in between gets the wrong animation set. GUARD: write it from Level::SetCoopSession, which the ordering proof puts inside SpawnEntities and therefore before any Player::Init — not from a script that runs afterwards.

7. Removing `set developer 1` from the shipped autoexec turns off script println and script compile-error visibility, which this project's own notes call REQUIRED for development. That is a co-op development regression, not a player-facing one. GUARD: keep it in a loose, unpacked dev cfg the developer execs; never in the shipped file.

8. Rescoping ubersound (stage 10) can silence co-op dialogue if a coop line loses a token it actually needed. GUARD: run the existing bLoadForMap model over m1l1/e1l1/t1l1 before and after and diff the registered-name sets — a coop map must lose zero names.

MEASUREMENT GAPS, stated rather than papered over:
• I have not booted anything. Every claim above is read from source. The two runtime numbers I leaned on are other agents' measurements, not mine: the `dropping duplicate menu container 'SelectPrimaryWeapon'` line in qconsole.log:4691, and the alias/precache counts for dm/mohdm1.
• I do not know whether bug-330 still reproduces on the current build. Stage 3 exists to answer that before anyone spends on it.
• I have not measured the frame cost of 429 deferred TIKI threads on a busy DM map, nor how many of the 23 arenas actually break when the handlers start running.
• I have not verified that CVAR_LATCH and CVAR_SERVERINFO compose exactly as g_gametype does at every code path — only that g_gametype carries both flags (sv_init.c:1068), which is strong precedent, not proof.
