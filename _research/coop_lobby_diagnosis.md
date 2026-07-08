# Coop Lobby (co_lobby1) — Diagnosis & Architecture (2026-07-07)

## The vision
A between-mission staging area. Each connected player, wearing **their own MP skin**, stands
at-ease at a slot; everyone views one shared static camera framing the squad; no HUD/crosshair;
frozen (no move/look); then a ready-up flow launches the next mission.

## What WORKS (verified this session)
- co_lobby1 loads; coop framework inits; **props spawn** (tent/desk/typewriter/truck/crates); camera spawns.
- **isCoopEnabledMap fix** (bug-357/359): `case c` now whitelists `co_lobby*`, so `inCoopMode` is true,
  the coop statefile (`coop_mod/player`) stays loaded, and `EMOTE_ATEASE` resolves. The
  `ForceLegsState ... not found in global/mike` error is GONE. CONFIRMED via log.
- **Primitives are all proven in this mod:**
  - `player freezecontrols 1/0` — engine lock (`PMF_FROZEN`): blocks move + mouselook. Used by map
    intros: `maps/t1l2.scr::coop_introFreeze/coop_introRelease`, `maps/t2l2.scr` end-cutscene.
  - `cuecamera <cam>` — one shared camera view broadcast to all clients (t2l2, e2l2, e3l4).
  - `forcelegsstate EMOTE_ATEASE` — at-ease pose on the player's OWN model (coop_mod/player.scr::playerEmote,
    state in coop_mod/player_Legs.st).
  - Slot spawn origins already defined: `spawnlocations.scr::co_lobby1` sets `coop_spawn1-4origin`.

## What's BROKEN and WHY (root causes, most→least certain)

### R1. Player never completes coop spawn — `coop_isActive` stuck at `-1`  (THE blocker)
Log spams `player.scr::manage - PLAYER HIT BACKUP SPAWN` every frame. That branch fires when a
NON-spectator player has `coop_isActive == -1`. `coop_isActive` only becomes `1` at the very end of
`player.scr::manageAliveSpawning` (line 916), after `playerPlaceAtSpawn` (line 876) and the
`coop_playerJustSpawned` callback (line 877). Stuck at `-1` ⇒ `manageAliveSpawning` exits early
(candidates: line 857 `dmteam=="spectator" || forceValidTeam → resetSpawn; end`, or line 908 spectator)
OR the spawn EVENT (`main.scr::playerSpawnEvent`) never fires because the player never truly deploys.
**Consequence:** the `coop_playerJustSpawned` callback → `lobby.scr::lobbyOnSpawn` (our freeze / pose /
camera / slot-warp) NEVER runs. So HUD stays, view is free (jerky), player sits at the raw spawn.
NEEDS a diagnostic print to see the exact exit.

### R2. Out-of-bounds spawn — contradictory spawn config
`co_lobby1.scr` sets `level.coop_disableSpawnWarper = game.true` ("no respawn warper in the lobby"),
while `spawnlocations.scr::co_lobby1` defines `coop_spawn1-4origin` at the slots. `playerPlaceAtSpawn`
(main.scr:546) reads those origins and warps the player — but it only runs if R1 is fixed. Net today:
player lands at the training map's raw DM spawn (the OOB tree field). Note `playerPlaceAtSpawn` does
NOT gate on `coop_disableSpawnWarper`; that flag only affects respawn-at-death tracking (player.scr:82).

### R3. Still "click to spawn" — auto-deploy not engaging
`lobbyMapMain` sets `g_forcerespawn 1` + threads `lobbyAutoSpawnLoop` (skipTeamAndWeaponSelect for
spectators), but the player still gets the manual deploy. Likely tied to R1 (never fully deploys).

### R4. (earlier, now moot) stand-in actor could not wear the player's MP skin
A `models/player/*.tik` has no Actor classname, so it can't be `spawn`ed as an actor (bug-355). Only
the REAL player wears the chosen skin. Abandoned the stand-in. This is settled.

## The architectural lesson (from the campaign itself)
Map intros (t1l2 `coop_introFreeze`) freeze players who have **already spawned normally**
(`coop_isActive == 1`) and THEN apply freeze + camera. We were doing it DURING spawn (via the
`coop_playerJustSpawned` callback), racing/fighting the lifecycle. Briefings (briefing1.scr) show the
between-mission "advance to next map" mechanism (`exec global/missioncomplete.scr "m1l1"`) but are 2D
overlays that never place a player body — not enough for a 3D squad view.

## Recommended architecture — "let them spawn, THEN lock" (Option B, true 3D squad)
Stop intercepting the spawn. Instead:
1. **Place at slots via the normal warper:** REMOVE `coop_disableSpawnWarper` from co_lobby1 (match every
   working coop map, which sets `coop_spawnNorigin` and leaves the warper on). Players deploy AT the slots.
2. **Auto-deploy:** confirm/repair the skip-team/weapon path so there's no manual click.
3. **Lock AFTER active, intro-style:** a per-player watcher that WAITS for `coop_isActive == 1`, then
   applies `freezecontrols 1` + `cuecamera` + `forcelegsstate EMOTE_ATEASE` + hide HUD. Do NOT drive this
   from the spawn callback (which races the lifecycle).
4. Keep props + shared camera as-is; keep the `isCoopEnabledMap` and statefile fixes.
5. **Add diagnostics** first: print the `manageAliveSpawning` exit path and `coop_isActive` transitions so
   the next test pinpoints R1 instead of guessing.

## Open question for the next test
Exactly where does `manageAliveSpawning` exit for co_lobby1 (forceValidTeam? spectator?)? A one-line print
at each early-exit + at line 916 will answer it in one run.
