# Coop Lobby Phases B & C — engine-verified implementation plan (agents, 2026-07-07)

## Phase B — pose / nameplate / music

### Pose (IMPLEMENTED 2026-07-07)
- Root cause of "holds rifle / invisible gun": `forcelegsstate EMOTE_ATEASE` only drives the LEGS; the
  TORSO keeps its weapon-raise unless forced to an `action none` state (which sets torso frame-slot
  weight 0 so the legs anim owns the whole skeleton — player.cpp:5661 StopPartAnimating, player_animation.cpp:388).
- `coop_emote_atease` = `misc/00A100_idle.skc` = SAME file as `americanselectionidle1` (anims_shared.txt:453/10) —
  the MP menu hands-on-hips at-ease idle, full-body. Anim was always correct.
- FIX (shipped): remove `takeall` (it fires EMOTE_ATEASE's `STAND : -HAS_WEAPON` exit = the invisible-gun bounce);
  after `forcelegsstate "EMOTE_ATEASE"` add `forcetorsostate "STAND"` (STAND torso = action none; while frozen its
  weapon edges eval false → weight 0). `lobbyPoseMaintain` re-forces both every 1s to self-heal spawn-settle.
- If STAND flickers: add a dedicated `EMOTE_ATEASE_TORSO` state to `coop_mod/player_Torso.st` (mirror COVER_TORSO
  byte-shape, action `none:default`, cancels mirror the legs EMOTE_ATEASE exits, NO +/-HAS_WEAPON edges). `.st` edits
  ERR_DROP on bad parse — boot-test.
- DO NOT use `immobile`/FL_IMMOBILE to lock: EvaluateState early-returns on FL_IMMOBILE (player.cpp:5571), blocking
  forcelegs/torsostate. `freezecontrols`/`freezeplayer` (PMF_FROZEN) do NOT block EvaluateState — correct primitive.
- Global emote fix (TODO, enhancement): in `player.scr::playerEmote` (~566) add `forcetorsostate` after the
  forcelegsstate so the in-game emote bus (salute/atease/stretch, idx 23-25) reads full-body too.

### Weighted idle rotation (TODO)
- `lobbyIdleRotate` per-player: every ~6-12s weighted-random pick, re-force legs+torso: EMOTE_ATEASE (base, high
  weight, self-loops), EMOTE_SALUTE (player_Legs.st:1438, one-shot→STAND, re-force ATEASE after), EMOTE_STRETCH (1618).
- Do weighting in SCRIPT (TIKI `weight` flag pools aliases & makes them unaddressable — bug-260). Use direct
  weight-free aliases coop_emote_* (anims_shared.txt:452-454).
- Smoke/lean = donor .skc on new_generic_human.tik (idle/atease.skc:1495, scripted/lean.tik, cigarette
  attachmodel :1594). Port like coop_cover_* borrows AI .skc (anims_shared.txt:478-479): add weight-free player
  aliases + EMOTE_SMOKE/LEAN legs+torso states + script-attach cigarette. Follow-on.

### Nameplate (TODO — Option A, no rebuild)
- Rank per player = `self.flags["coop_xp_rank"]` (0-12, xp.scr:153); emblem art ships `textures/hud/coop_rank_00..12.tga`
  (drawn today xp.scr:574). Name = `waitthread game.player::playerCleanName self.netname`.
- Static camera + fixed slots → each head projects to a fixed screen spot. Per viewer, per occupied slot draw
  `ihuddraw_shader <slot> "textures/hud/coop_rank_"+rank` + `ihuddraw_string <slot> <name>` positioned via
  ihuddraw_rect/align/virtualsize/color (scriptthread.cpp:1281-1367). Map slot→player via coop_lobbySlot.
- USE SLOTS 100-107 — clear of lobbyHideHud band (20-90), XP (62-72), build (54-59). Positions as cvars
  coop_lobbyPlateN_X/Y read with int() like applyLobbyCam.
- Option B (later, rebuild): CG_PlayerRankNameplate next to cg_modelanim.c:1685 ET_PLAYER hook, clone
  CG_ActorOverheadIcon (RT_SPRITE over head tag); needs \rank\N in CS_PLAYERS configstring.

### Music (TODO)
- In lobbyMapMain after camera/props: `waitthread coop_mod/replace.scr::tmstartloop "music/kleveburg.mp3"` — registers
  level.coop_musicCommand so late joiners auto-get it (player.scr:1234-1239). Ship music/kleveburg.mp3 MP3@22050.
- Stop on launch: `waitthread coop_mod/replace.scr::tmstop` (or tmfade for smooth). tm* takes a file path, no aliascache.

## Phase C — ready / skins / countdown

### Bindable bus (how a key reaches server script)
- ui/BIND.SCR binds key → `append name ,<marker><data>`; player.scr manage detects netname delta →
  manageNamechange → playerExtract → playerNameCommand `arrayIndex` switch (player.scr:495-549). Markers declared
  in variables.scr::getNameAppendCommands (124-157). Indices 0-30 taken; 31 next free. Emote (23-25) = the template.

### Auto-spawn latch fix (IMPLEMENTED) + freeze (IMPLEMENTED)
- lobbyAutoSpawnLoop one-shot latch gave up after a failed first deploy → host stuck clicking. FIX (shipped):
  retry skipTeamAndWeaponSelect every scan while dmteam=="spectator".
- Jump: freezecontrols m_bFrozen resets every respawn (player.cpp:2240). FIX (shipped): `freezeplayer` in
  lobbyMapMain = level.playerfrozen (Level flag, reset only at level load, respawn-proof; pmove-only, menu/chat OK).

### Ready system (TODO)
- Native `ready`/notready exist (gamecmds.cpp:98) but m_bReady defaults TRUE on spawn (player.cpp:2156) + resets per
  respawn + DM_Team::NumNotReady is broken (dm_manager.cpp:601, always 0) → DON'T use as store.
- Script-side: variables.scr add index 31 `" ,rk"`; player.scr playerNameCommand case 31 →
  lobby.scr::lobbyReadyToggle (flip self.flags["coop_lobbyReady"]); BIND.SCR `binditem "Coop Lobby: Ready" "append name ,rkx"`.
- lobbyReadyMonitor loop: count deployed (coop_lobbySlot!=NIL & !spectator) vs ready; all ready & >0 → countdown.

### Skin cycle (TODO)
- InitModel (player.cpp:2502) reads userinfo dm_playermodel on spawn; allies must start "american"/"allied" else
  fallback american_army. Setting cvar alone does NOT re-init live.
- LIVE change: `self model ("models/player/"+skin+".tik")` swaps immediately; re-assert pose after (model change
  resets legs). Persist to mission: `self stufftext ("set dm_playermodel "+skin+"\n")`.
- Allied roster (cl_uiplayermodelpicker.cpp:44-113): american_army, american_ranger, allied_101st_captain/infantry/scout,
  allied_501st_pir_scout/soldier, allied_airborne, allied_manon, allied_pilot, allied_sas, allied_british_6th_airborne_captain/
  paratrooper, allied_british_tank_corporal, allied_british_Cmd, allied_british_Tank, allied_russian_corporal/crazy_boris/
  recon_scout/recon_soldier/seaman, allied_technician, allied_US_Tank, allied_US_Mask, allied_Wheathers.
- variables.scr idx 32 `" ,sn"` (next) + 33 `" ,sp"` (prev); TWO handlers (no bare -1 arg = parse killer);
  BIND.SCR next/prev; lobby.scr::lobbySkinNext/Prev cycle level.coop_lobbySkins[] wrap, apply model + re-pose + stufftext.

### Countdown + launch (TODO)
- co_lobby1.scr::main: set `level.coopNextMap = "briefing/briefing1"` (chain: lobby→briefing1 video→m1l1).
- lobbyCountdownAndLaunch: n=5→1, each sec iprintlnbold_noloc "Mission starting in n..." to all; abort if a ready toggles off.
- Launch: set coop_lobbyActive=0 (loops exit) + restore stashed cvars (g_inactivespectate/forcerespawn/inactivekick),
  then `exec global/missioncomplete.scr level.coopNextMap` (coop-safe wrapper). Fallback: `stuffsrv ("map "+level.coopNextMap)`.

### Parse-killer reminders
- No bare negative-in-parens as a call arg (use 2 handlers not `-1`); ASCII only; no func-call in vector literal;
  unique 2-char name-append markers; gate loops on coop_lobbyActive + NULL-check self each iter.

## Phase C — REFINEMENTS (2nd agent, engine-verified, supersede where they conflict)
- **Name-bus works even while frozen** and OUTSIDE the coop_isActive gate (manage detects the dirty name every tick,
  player.scr:105-117) — so ready/skin binds work even before spawn-lifecycle is perfect. Data byte (the `x` in `,ryx`)
  is MANDATORY (empty payloads ignored, player.scr:343).
- **HUD-slot safety:** lobbyHideHud wipes 20-90 every 0.5s. Put lobby UI OUTSIDE that band: ready counter slot 15,
  skin-name slot 16 (below 20), nameplates 100-107 (above 90). A single `-1` as a plain call arg is fine (only
  dangerous inside parens/vectors) — but two handlers (lobbyCycleSkin 1 / lobbyCycleSkin -1) is cleanest.
- **LAUNCH — use the CLEAN transition, NOT global/missioncomplete.scr.** missioncomplete runs xp_summary (a MISSION
  debrief, incoherent for a lobby) then `bsptransition` (the silent-archive coop crash path, main.scr:1543/maptest.scr:132).
  Instead mirror `coop_mod/maptest.scr::coop_maptest_transition` (:145-163) / `main.scr::restartMap` (:1522-1570):
  g_scriptcheck 0; `waitthread coop_mod/xp.scr::xp_flush` (existing persist entry point — do NOT modify xp); stash+clear
  sv_maplist; level.coop_preventGameTypeChanges=game.true; game.loadout=false; then `stuffsrv ("map "+level.coop_lobbyNextMap)`
  (SV_Map_f hardcodes bTransition=false → no archive → no crash). Set coop_lobbyActive=0 + restore stashed cvars first.
- **Next map:** set `level.coop_lobbyNextMap` in co_lobby1.scr::main, cvar-overridable: `getcvar "coop_lobbyNextMap"`,
  default `"briefing/briefing1"` (chains to m1l1). Keep it DISTINCT from level.coopNextMap (used by vote/auto-tour).
- **Ready:** native getter `self.ready` (player.cpp:1226/11754) + `ready`/`notready` cmds EXIST and are usable, BUT
  m_bReady defaults TRUE on connect (player.cpp:2156) and is respawn-fragile → use script flag coop_lobbyReady as truth;
  native getter = optional cross-check only. Do NOT rely on DM_Team::NumNotReady (broken, always 0, dm_manager.cpp:601).
- **Skin live-change confirmed:** `self model "models/player/<allied>.tik"` updates modelindex live + replicates
  (Player is an Entity; entity.cpp:1568/1997). Pair with `self stufftext ("dm_playermodel "+skin+"\n")` to persist into
  the launched mission (InitModel reads it, player.cpp:2542; allied names MUST start american/allied). Re-force the pose
  after (model swap resets legs). Build the list with makeArray/endArray (maplist.scr pattern), not a vector literal.
