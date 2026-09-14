# MP buildout roadmap (post-v1.6.0)

Ground truth after v1.6.0: mp.scr (entry, seeds coop_mpRun/gametype, per-frame poll on team-flip
+ spawn edges, hp=100 at spawn), mp_armory.scr (live dispatcher, only P1 free starters unlock),
engine E4/E5 hooks live. SEC filter admits exactly two server->client shapes with NO new grammar:
`set coop_mp*` and `exec ui/coop_mp*`. Any other new S->C shape needs a filter grammar entry + a
cgame.dll ship. Per-map colour grade = DONE (57 campaign maps, case-insensitive cvar lookup).

## Slice order (each independently deployable + coop-safe; guard every mode on level.coop_mpRun)

PURE SCRIPT (no engine/cgame ship; reuse the shipped set coop_mp* / exec ui/coop_mp* filter):
1. Mode scaffold + Gun Game (FFA, gt1) -- FIRST, the dependency root. coop_mpMode cvar + per-kill
   & per-tick dispatch hook in mp.scr; mp_gungame.scr new in MP_MANIFEST. Tier ladder, per-kill
   advance, melee-demote (M8), suicide-demote, final bash-only tier (M7), weighted credit (M10),
   bot advance/win (M11), tier mirrored into stock Kills column (addkills), end on fraglimit.
   Gun Game bypasses the armory (mode owns the spawn kit). No new S->C shape.
2. Weapon presets (Rifles / Snipers / Rifles+Snipers) -- M5 modifier row on every mode; armory
   already enforces classBanned. Pistols+grenades stay (M4).
3. S&D (stock gt4 bomb + no-respawn round) and LMS (gt3 + last-man callout). Round-state helper.
4. KOTH -- rides the built compass-bar objective marker channel; rebuild from Klownterfit/ViPER.
5. Freeze Tag -- UBER recipe; injail scoreboard marker is stock; thawed stay in place (M13).
6. Push -- rebuild OwN-3m-All recipe; bulk = per-map checkpoints on the 7 SP maps (M19).
7. Select Game Type grid (ui/multiplayerstart.urc 3x6) + Host Rules screens (UI only; engine-toggle
   rows start greyed). H8/H9. Regenerate selectgame jpg (jpg loads before tga).
8. Colour-grade full coverage -- DONE already (verified). Data-only if any map wants retuning.

ENGINE SLICES (need game.dll/cgame.dll ship; do config-fossil de-forcing FIRST -- move toggled
cvars out of autoexec.cfg to seeds, else hosts can't opt out):
9.  Host toggles ADS/Prone/Cover/3P -- g_mpOff serverinfo bitmask (0=stock) + cgame enforcement.
    New g_mp* archived prefs, pre-registered in G_InitGame; NEVER reuse coop_* names or autoexec.
10. Demolition + CTF -- Mefy MIT libs (credit). CTF flag/score HUD likely first new S->C grammar.
11. Voice nationality (A8) -- game.dll, follow the worn armory skin not the model name.
12. MP progression -- attribution + unlock table + save store + signing builtins (T1). Largest lift.
13. Build-A-Base + Base Assault -- new MP builder (coop buildmode NOT reusable); bots can't build.
14. DBNO / Medkits ON port -- deferred/greyed (H4) until team-revive/heal port avoids coop.

## Hard isolation rules for every mode
New coop_mod/mp_*.scr in MP_MANIFEST, guarded on level.coop_mpRun, dispatched from mp.scr. NEVER
giveInventory/changeGameType (forces gt2) or write coop_health/coop_lockLoadout/coop_*. Round
restart wipes coop_mpRun + delegates -> cross-round state lives in cvars. teamwin only gt>=4; map
refuses dm/ under gt4; bots never press USE / play objectives. check_mp_isolation.py 0 FAILED,
coop_loadout.urc sha unchanged, gen_loadout 615/615 on every slice.

## Dependency note (user, 2026-09-14): MP progression <-> MP Service Record
If we build weapon-unlock progression for the Allied/Axis inventories (roadmap slice 12: per-kill
class+weapon attribution, unlock tables, save store - decisions P1-P14), it REQUIRES Multiplayer
challenges in the Service Record to drive and display that progress. This mirrors the existing coop
challenge/Service Record system (challenges.scr -> 445 challenges w/ writer+target+reward, coop_sr*
view-state cvars, coop_sr_medals.tga, the coop_sr pin cfgs) but must be MP-OWNED and separate:
- MP challenges live in their own file/rows (not challenges.scr's coop set), MP-side (Allied/Axis)
  unlock counters as the "stat writers", with the armory unlock as the reward.
- Its own Service Record page/tab + save store (P13 "offline Service Record and pins: later";
  S8 a homepath-root progress file by new exe code is acceptable), never writing coop challenge
  state or coop_sr* cvars (coop-isolation clause set F: MP gets its own files/verbs/cvars/HUD slots).
- So slice 12 (MP progression) is really two coupled pieces: the unlock engine AND an MP Service
  Record (MP challenges + page + medals/pins) - plan them together; the challenge rows ARE the
  progression spec (kills-per-tier / headshot / picked-up-enemy-weapon per P4/P5/P8).

### Wiring requirement (user, 2026-09-14): "ensure it's all wired up"
The MP progression + MP Service Record must be END-TO-END WIRED and gate-validated, exactly like
the coop challenge system already is at build time ("challenges: 445 | stat writers found: 188 |
OK - every challenge has a writer, a reachable target and a real reward"). For the MP set that means
a build-gate assertion (extend the coop challenge validator or add an MP twin) proving, for every MP
challenge: (1) it has a STAT WRITER (some gameplay event actually increments its counter -
kill/headshot/picked-up-enemy-weapon per P4/P5/P8), (2) a REACHABLE target, and (3) a real REWARD
that maps to an actual armory unlock (the unlock id exists in mpa_roster/mpx_roster and the armory
honours it). No orphan challenges, no unlocks with no driver, no rewards pointing at a missing gun.
Plus: the Service Record page reads the live counters/unlock state, and the save store round-trips
(write on unlock, read back on next session) - proven, not assumed. Bake this into slice 12 from the
start; it is the same "every challenge has a writer/target/reward" discipline the coop packer enforces.

## Hardcore modifier (user, 2026-09-14) - first engine slice
A host toggle "Hardcore" enable-able on ALL modes (a modifier, like weapon presets), coop_mpHardcore 0/1:
- Remove the crosshair.
- Remove the health/stamina HUD indicators.
- Half health (the MP spawn gives 50 instead of 100).
- Everything a bit slower - reduced movement (walk-ish speed).
Shape: an MP-owned SERVERINFO cvar the cgame reads via cgs.serverinfo; mp.scr sets it when the host
enables Hardcore. cgame hides crosshair + health/stamina when the flag is set (gated to MP only, so
coop HUD is untouched - coop never sets the flag). Script (mp_hardcore.scr / mp seam) sets half
health at spawn and lowers movement (g_speed reduced on the MP server, restored off). Matched cgame
+ script deploy (T10). Composes with every mode. Coop-safe: flag only set on MP; coop HUD/health/
speed unchanged. This establishes the serverinfo->cgame enforcement pattern the ADS/prone/cover/3P
host toggles (slice 9) reuse.
