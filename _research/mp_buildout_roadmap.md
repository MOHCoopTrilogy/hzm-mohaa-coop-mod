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
