> Generated 2026-09-13 by the mp-gamemodes-understand workflow (26 agents: 6 readers incl. a web survey, 6 adversarial verifiers, a critic, gap readers + verifiers, synthesis). Research only.

> **USER DECISIONS (2026-09-13, after this map):**
> - Modes wanted: "I'd like the Push mod, king of the hill, ctf, search and destroy, gun game, last man standing, and demolition" -
>   in addition to the Freeze Tag, Rifles Only and base-building modes named in the original request.
> - Base building is undecided until the difference between Build-A-Base and Base Builder (and what Base Assault is) has been explained.
> - Push is the MOHAA push mod from "King's LMAO server" (see _research/kings_push_hunt.md); the approved Ubermod V2 download is being read for the
>   surviving implementations. Nothing here is decided about licensing: rebuild from rules unless the authors give permission.

# HZM MP Game Modes, Host Toggles and the SELECT THE GAME TYPE Menu: Verified Research Map

Status: research synthesis only. Nothing has been built, edited or playtested. Date: 2026-09-13.

## How to read this document

**Path prefixes**
- `fgame/`, `cgame/`, `client/`, `server/`, `qcommon/` and `uilib/` mean `openmohaa-hzm/code/<dir>/`.
- `mod/` means `hzm-mohaa-coop-mod/`.
- `coop_mod/`, `ui/`, `global/` and `maps/` sit under `mod/`.
- `docs/` sits at the repo root.
- Retail pak files are cited as `maintt/pakN.pk3:<file>:<line>`, under the GOG install.

**Evidence tags.** These mark load-bearing facts only. Supporting facts carry no tag.
- **[C]**: confirmed by a verify pass.
- **[P]**: partly confirmed. The text already carries the correction.
- **[NV]**: not independently verified. Treat it as provisional.
- **[R]**: refuted. The corrected statement is given.

---

## 1. Executive summary

### What the user asked

1. **More modes under Start Game.** The user named Freeze Tag, Rifles Only, BaseBuilder and Gun Game, and asked for any other big modes. Every mode must be hostable and must work with the mod.
2. **Host options for any non-coop game type.** DBNO, Healing/Medkits, ADS, Prone, Cover and Third Person, each switchable on or off in Start Game.
3. **A cleanup of the SELECT THE GAME TYPE board**, whose buttons are oversized. It has to hold the new modes.

All of this comes with a hard constraint: nothing may change coop behaviour, coop cvars, coop saves or coop menus.

### What is feasible soon (script-first, little or no engine work)

- **Weapon-class filters: Rifles, Snipers, Rifles+Snipers.**
  - The engine already bans classes through dmflags bits 22-28 (`fgame/bg_public.h:638-644`).
  - The planned MP armory must enforce the same mask itself. The engine checks bans only on the `dm_primary` class path, never on script gives (`_research/mp_armories_understanding.md:924-927`) [C].
- **Gun Game on gametype 1 (FFA).**
  - The stock Kills column, the leader-first sort and the fraglimit HUD already carry a per-player number (`fgame/dm_manager.cpp:833-880`, `fgame/player.cpp:8882-8912`) [NV].
  - Three live "[Gun-Game AA/SH/BT] + Bots" servers run it on OpenMOHAA today. Their script is not public.
- **Freeze Tag on the proven UBER recipe** (script only, gametype 2), or on gametype 3 with frozen players left engine-dead. See section 3.
- **Team Last Man Standing / Arena.** This is stock gametype 3 plus a loadout preset.
- **Search & Destroy on obj maps.** The stock gametype-4 bomb game already implements it (`fgame/dm_manager.cpp:1276-1364`) [NV].
- **Menu cleanup.** Shrink the rects on `ui/multiplayerstart.urc` into a 3x6 grid. No new widget classes are needed, and the coop plaque stays byte-identical.
- **DBNO off and Medkits off.** Both are already the state in MP today. Neither system is started on MP maps (`coop_mod/player.scr:1228-1255`, `coop_mod/mp.scr:224-256`) [C].
- **Prone off and Cover off.** Each is a small game.dll gate. The client follows server state (`fgame/player.cpp:14032-14090`, `:17423-17452`) [C].

### What is hard

- **DBNO or Medkits ON in MP.** This is a port, not a toggle. It needs:
  - team-tested revive and heal;
  - kill credit;
  - an elimination bridge for round modes;
  - a heal ceiling that does not use `level.coop_health`;
  - removal of the `changeGameType` 0/2 re-give, which converts OBJ/Round/TOW/Lib servers to Team Match;
  - removal of the `xp_award` path that writes coop XP.

  Every one of these lives in scripts that every coop map runs.
- **ADS off and Third Person off.** Both need game.dll and cgame.dll changes. Third Person can only be enforced in our own cgame.
- **A leak-free "Healing off".** `DF_NO_HEALTH` leaks into the next coop map. `g_healthdrop` has no reader in this engine.
- **BaseBuilder** (L). Bots cannot build, and coop `buildmode.scr` cannot be reused.
- **Objective modes on bot-filled servers** (CTF, KOTH, Kill Confirmed). Bots have no objective AI.
- **One in the Chamber lives and FFA Last Man Standing.** The engine has no per-player respawn lock, and rounds exist only for allies vs axis.
- **The decision record.** `docs/DECISIONS.md:630-660` records ONE host switch and "DBNO NEVER in MP". It must be superseded before building [C].

### The three biggest risks

1. **Leaks into coop through shared process state.** Several cvars persist across map changes, and some are saved to config and survive a restart:
   - `dmflags`, including `DF_NO_HEALTH`, which acts before coop's script runs;
   - `g_realismmode`, which is latched, and coop's reset for it is commented out;
   - the four bot cvars;
   - `fraglimit`;
   - `sv_team_spawn_interval` (archived);
   - any `coop_*` cvar an MP path writes.

   Reusing `dbno.scr`, `medkit.scr` or `ammobox.scr` unmodified also reaches `xp_award`, which writes coop XP state.
2. **Engine round rules that do not fit the modes.**
   - `map` refuses dm/ maps under gametype 4.
   - `teamwin` works only on gametype 4 and above.
   - `DM_Team::IsDead` ignores frozen or downed players.
   - A round restart wipes level vars, game vars, entities and delegate subscriptions.
   - A `killhandler` stops `player_killed` from firing.
   - Bots never press USE on players and never play objectives.

   The failure modes are modes that silently fail to start, rounds that never end, and kills that credit nobody.
3. **Toggles that promise more than they deliver, and edits to shared code.** DECISIONS.md requires that "OFF must mean classic". Today several mechanics have no gate at all (auto-cover, prone, the ADS monitor). ADS and 3P need both DLLs. DBNO and medkit changes touch files shared with every coop map. The menu edit touches the one screen every coop host passes through.

---

## 2. Mode catalog

Each row gives the base gametype recommended by this research. The gametype-4 refusal of dm/ maps changes several earlier recommendations. Effort: S under a week of script, M is a multi-file script system, L is a large system or engine work. Popularity rests on one game-state.com snapshot on 2026-09-13 with almost zero players [NV], plus accessible pages.

| # | Mode | Origin | Rules (one line) | Team/FFA | Base gt | Mechanics needed | Mod already has | Work | Effort | Popularity | Key risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Freeze Tag | MOHAA community (Mefy Extended-Gametypes; UBER `g_ubergametype ft`) | Death freezes you; a teammate melts you in 3 s (UBER default); wipe the enemy team to win the round; 5 rounds to win (UBER) | Team | gt2 (UBER script rounds) or gt3 (engine-dead frozen) | Frozen state, melt trigger + timer, round counter, wipe detection, bot thaw path, round HUD | freezecontrols/physics_off, coop_setdbno, DBNO down/revive recipe to copy | Script; optional engine "counts as dead" flag | M | Highest in MOHAA: only featured gametype mod on moh-db (4.2K), 5 live AA/SH servers [NV] | Round deadlock if frozen stay alive on gt3; gt3 thaw trap; killhandler variant starves progression; bots do not seek thaws |
| 2 | Rifles / Snipers / Rifles+Snipers Only (weapon-class filter family) | MOHAA community (AA RifleMod/RifleModSV, SH Riflemod) | Only the allowed classes can be selected | Modifier on any base | Any 1-6 | dmflags preset, armory mask enforcement, dontdropweapons, pickup filter, deploy class | Engine class bans; mp.scr clears coop's dmflags | Script + armory UI | S | About 7 live servers across AA/SH/BT incl. openmohaa.org [NV] | Armory bypasses dmflags; dmflags persists into next MP map; snipers-only deploy stuck in spectate |
| 3 | Gun Game (+ OITC, Sharpshooter, Sticks and Stones variants) | Modern (CS GunGame / Arms Race, CoD, Valorant Escalation); live OpenMOHAA servers | Each kill swaps you to the next tier; melee demotes the victim; suicide demotes; last-tier kill wins | FFA (team variant possible) | gt1 | player_killed hook, tier table, kit swap, no drops, tier/leader HUD | Engine Kills column + fraglimit end; `docs/tools/loadout_weapons.tsv` roster | Script | M | High outside MOHAA; 3 live MOHAA servers [NV] | event_subscribe never run in mod; progression farming with bots; FFA spawns missing on some maps; no stock knife tik found |
| 4 | BaseBuilder | MOHAA community (UBER Basebuilder, SearingWolfe / ])ar]{, v7.994 2026-01-10) | Timed build phase with object cap, then fight | Team | gt2 (UBER base gametype unproven) | Prop carry/place, budget, phase timer, noclip scoping, entity/precache headroom | cover.scr placement, bunker.scr/blueprint.scr prefabs, buildmode_catalog.scr, wallgun player-clip barriers | Script + content | L | Long-lived, single lineage | Bots cannot build; buildmode.scr unusable; timelimit ends map mid-build; entity limits unmeasured |
| 5 | CTF / Freeze-Tag CTF | MOHAA community (Mefy; older server pk3, search text only) | Carry the enemy flag home | Team | gt2 | Flag entity, attach, drop, return, capture trigger, per-map bases | attach, triggers | Script + content; optional engine score flag | M-L | Moderate | No carryable flag model; every kill adds to gt2 team score; bots ignore flags |
| 6 | S&D / Demolition / Cyber Attack | MOHAA community (UBER snd/cyb; Mefy Demolition) | Plant/defuse, one life per round (Cyber Attack allows freeze-revive) | Team | gt4 on obj maps; gt3 + script bombsites on dm maps | Bomb sites, timers, side swap | Engine Objective bomb logic | Script (+ content for dm) | S (obj) / M (dm) | Moderate | gt4 refuses dm/ via `map`; bots ignore bombs |
| 7 | Infection / Survival Horror | MOHAA niche (inequation 'horror'; MOHAA Reunited server); CoD MW Infected | Killed survivors join the infected; survivors win on time | Asymmetric teams | gt6 (per-team respawn + teamwin) or gt2 | Forced setteam, switch lock, infected kit, round timer, conversion | setteam + model swap | Script | M | Niche, recurring | No stock melee tik found; auto-balance fights conversion; Lib scoreboard look |
| 8 | King of the Hill family (Capture the Church, Domination, HQ, Hardpoint) | UBER Capture the Church; modern CoD | Hold zones to score | Team | gt2 | Zone triggers, contest rule, per-map zones, score HUD | Primitives only | Script + content | M | Low in MOHAA, high in modern CoD | Kill score pollution on gt2; bots do not contest; Hardpoint rules unfetched |
| 9 | Kill Confirmed | Modern CoD | Pick up enemy tags to score, friendly tags to deny | Team | gt2 | Tag spawn/pickup/expiry, score override | papers.tik as stand-in | Script; optional engine score flag | M | Modern staple | No dog-tag model; bots do not collect |
| 10 | One in the Chamber / Sharpshooter | Modern CoD | 1 bullet, a kill earns a bullet, 3 lives (OITC) | FFA | gt1 | Clip control, lives, last-alive win | Clip commands | Script + engine (no-respawn flag, end-match) | M | Modern | No per-player respawn lock; no FFA end-match command |
| 11 | Team LMS / Clan Arena | Stock MOHAA Round-Based; Q3 CPMA | Everyone kitted, no respawn until a side is wiped | Team | gt3 (stock) | Loadout preset | Stock | Preset | S | Stock | mp.scr per-round redeploy may override class |
| 12 | FFA Last Man Standing | - | Last one alive wins | FFA | None fits (engine rounds are allies vs axis) | FFA rounds | - | Engine | L | Low | - |
| 13 | Liberation / TOW | Stock BT | Jail and switch; toggleable objectives | Team | gt6 / gt5 | - | Already on the board | None | - | Stock | - |
| 14 | Pistol/Knife/Bash-only, Hide and Seek, Instagib, Rocket Arena, Juggernaut, VIP | No MOHAA evidence found | - | - | - | Pistol/knife/bash-only need a script weapon strip (no dmflags bit exists) | - | - | - | Low | - |

### Supporting facts for the catalog

- **UBER mode selection.** One cvar, `g_ubergametype`, takes the values bb/cyb/snd/ft. Current version 7.994, updated 2026-01-10. The README says nothing about bots (https://github.com/searingwolfe/UBER-MODS-v8.00-MOHAA) [P].
  - Not "server-side": UBER also ships client UI (a menu skin pk3, an Admin Menu that needs a keybind).
  - There is no blanket "limited features without Reborn" statement.
- **UBER Freeze Tag rules** [P]:
  - Melt time is 3 s, teammates only, and the first team to kill all enemies wins the round.
  - `level.meltrespawn` defaults to 1, meaning a regular respawn: the player is teleported to the body and then respawned at a spawn point (`global/cyberattack_searchdestroy.scr:25`, `:697`, `:707`).
  - 0 keeps the player at the body. "Respawn where they froze" is Cyber Attack behaviour.
  - The "g_gametype 1 or 2" line refers to an unset `g_ubergametype`. The README states gametype 2 for the cyb/snd family, and Freeze Tag shares that script.
- **UBER Freeze Tag mechanics** [P]. The player really dies. The script waits for the engine respawn, then applies takeall/hide/notsolid/noclip and sets `.dead=1`. A `script_model` body plus a 70x70x110 `trigger_use` marks the spot. Round results come from script counts, with no teamwin (`global/cyberattack_searchdestroy.scr:176-210`, `:324-326`, `:441-452`, `:735-760`).
  - Gametype 2 is documented for cyb/snd and applies to ft by inference. The script never reads `g_gametype`.
  - The scratchpad copy of that script has no fetched upstream URL, so its provenance is unverified.
- **Bots and melting** [R]. In ft mode a teammate melts a frozen player just by touching the trigger. USE is required only for the remote melt-laser or in cyb (`global/cyberattack_searchdestroy.scr:354`). So a bot that walks into the trigger does melt the player. Bots simply have no logic to seek bodies out.
- **UBER BaseBuilder parameters.** Eight positional parameters (build time, object limit, build speed with a floor of 250, take weapons, fall damage, hide countdown, hide HUD, console print). Example `800 1000 250 1 1 0 0 0`. No separate prep phase. timelimit is extended only when build time is 3600 s or more (`alienx/basebuild.scr:45`, `:70-75`, `:92-98`; README.MD:143-154) [NV].
  - The base gametype is disputed: the repo page says 4, the README summary says 1/2. The script itself is gametype-agnostic.
- **Bots.** OpenMOHAA bots do not complete objectives; they only navigate and fight (https://docs.openmohaa.org/md_docs_2markdown_203-configuration_201-configuration.html) [C].
  - The fork has no objective, bomb or capture logic in any `playerbot*.cpp`. Gametype use is only same-team checks at `fgame/playerbot.cpp:445` and `:744`, plus single-player gates in `g_bot.cpp:624` and `:768` [P].
- **Bot targeting.** Bots skip hidden, notarget, dead, SOLID_NOT and same-team players (`fgame/playerbot.cpp:726-751`) [NV].
- **Gun Game rules**: https://en.wikipedia.org/wiki/Gun_game and https://segmentnext.com/call-of-duty-black-ops-gun-game-wager-match-guide/. The Wikipedia article also says a killed player's progress resets when they respawn, a variant detail.
- **Infected**: https://blog.activision.com/call-of-duty/2019-12/Mode-Recon-Infected.
- **Kill Confirmed**: https://gamewith.net/cod-coldwar/article/show/22178.
- **Domination and HQ**: https://diamondlobby.com/call-of-duty/black-ops-cold-war/how-to-win-domination/ and https://www.codforums.com/threads/how-does-headquarters-work.12832/.
- **Capture the Church**: https://raw.githubusercontent.com/B3none/mohaa-uber-basebuilder/master/Extra%20Info%20About%20Capture%20The%20Church.txt.
- **Horror mod**: https://github.com/inequation/MoHAAMods.
- **Clan Arena**: https://en.wikipedia.org/wiki/Challenge_ProMode_Arena.
- **ProBaseBuilder (CS)** has a Build phase and a Prep phase, a guns menu, zombie knives and zombie respawn on a timer. The page names no "Fight" phase (https://github.com/amirwolf5122/ProBaseBuilder) [P].
- **Unfetchable sources**: Mefy's rule set (mefy.moh-central.net 403), JV Eaglear Bots, gamefront CTF/Sniper Only, mohaaaa.co.uk (Anubis block), and the Hardpoint guides. Their rules rest on search text only.
- **No stock carryable flag or dog-tag model** exists in the paks. Only static flags and papers item tikis (scratchpad tik scan).
- **Maps with no `info_player_deathmatch`**, which rules out FFA-based modes (pak entity scan) [NV]:
  - obj/bastogne, bobobjaa01-03, capturedbase, dogwhite, obj_team1/3/4, obj_hms_hood, obj_lakeside_ai, obj_praha1945, obj_radararea, omaha_beach, stalingrad_3_obj, wilhelmstein_1767_obj;
  - dm/ramelle, dm/saving_private_ryan.
  - FFA picks spawns only from DM points (`fgame/dm_manager.cpp:1083-1110`, `:389`).

---

## 3. Recommended first set

### Order and reasoning

0. **Foundation, before any mode.** None of these is visible to players, but every mode depends on them.
   - The mode dispatcher in mp.scr.
   - The toggle delivery channel (section 5).
   - The isolation clauses (section 7).
   - An MP rule baseline, meaning explicit rule cvars written on every MP start.
   - The bot-cvar policy.
   - Test K1: does `event_subscribe player_killed coop_mod/<file>.scr::label` fire at all? It has never run in this mod (`_research/mp_progression_understanding.md:548-600`) [C].
1. **Weapon-class filter family (S).** Cheapest, highest live demand, and bots stay legal because they deploy through `primarydmweapon auto`, which respects dmflags.
2. **Gun Game (M).** Kill-only, so bots work. A live OpenMOHAA precedent exists. The stock scoreboard and HUD carry the tier.
3. **Freeze Tag (M).** The signature MOHAA mode, with a proven script recipe.
4. **Team LMS preset (S) and S&D on obj maps (S).** Nearly free.
5. **BaseBuilder (L), last among the named modes.** Largest system, bots cannot build, and entity budgets are unmeasured.
6. **Later, "best with humans"**: Infection, then CTF, KOTH and Kill Confirmed.

### Gametype constraints every sketch obeys

- **The gametype-4 refusal.** `SV_Map_f` refuses a dm/ map only when the latched `g_gametype` is exactly 4 (`server/sv_ccmds.c:216`, `:222-226`) [C]. `gamemap`, which sv_maplist rotation uses, has no such check (`server/sv_ccmds.c:283-314`; `fgame/g_main.cpp:2115`) [C]. So a gt4 mode on dm maps fails from the menu but loads on rotation. **No mode pairs gt4 with dm/ maps.**
- **teamwin** throws unless gametype >= 4, so it is legal on 4, 5 and 6 (`fgame/scriptthread.cpp:4354-4356`) [C].
- **Respawn and round model**: gt1-2 respawn with no rounds; gt5-6 respawn with rounds; gt3-4 have rounds with no respawn (`fgame/dm_manager.cpp:1130-1141`) [C].
  - Nuance: `AllowRespawn()` is still true while a team is empty and has never spawned anyone (`:1613-1619`).
- **gt3 round end** [P]. Elimination ends the round on its own through `DM_Team::IsDead`. So do the round clock (roundlimit + clockside) and fraglimit.
  - IsDead is also true for an empty team while the game is active (`:536-538`).
  - IsDead is false before the team has spawned (`:540-542`) and whenever respawns are allowed (`:548-549`). Turning `level.dmrespawning` on disables elimination.
- **Round restarts wipe everything.** A round restart (`restart` -> `SV_MapRestart_f` -> `SV_SpawnServer`) deletes every entity and clears level, parm and game vars (`fgame/level.cpp:913-918`, `:943-950`) [P]. Delegate subscriptions are reset too (`scriptmaster.cpp:784`) [NV].
  - Cross-round mode state must live in cvars, as the engine's own g_temp* scores do (`fgame/dm_manager.cpp:1480-1484`) [NV].
  - Side note: game vars are wiped too, which contradicts the comment at `coop_mod/mp.scr:63-64` that `game.*` persists across maps.
- **killhandler.** Once set, `Player::Killed` runs the handler and returns before AddDeaths, the obituary, kill credit, the death drop and the `player_killed` delegate (`fgame/player.cpp:3534-3544`) [C]. Any mode built on a killhandler blinds MP progression unless it emits credit itself.
- **Map pools.** 23 HZM dm/ and obj/ maps are coop-integrated: their scripts call `coop_mod/main.scr::main` (e.g. `maps/dm/Ramelle.scr:11`, `maps/obj/obj_hms_hood.scr:11`; full list in section 4) [P]. A folder-based picker would offer them.
  - Separately, `mp_ship_lib` and `mp_bizertefort_obj` never reach `ambient.scr`, so mp.scr never runs on them (`_research/mp_armories_understanding.md:1003-1010`) [P].
  - Every mode needs an explicit, generated per-mode map whitelist.

### 3.1 Gun Game (sketch)

**Base.** gt1 FFA. Respawns are on (`fgame/dm_manager.cpp:1131-1133`). FFA PvP always counts (`fgame/sentient.cpp:1663-1665`) [NV].

**Start.**
- `ui_startdmmap 1 Gun-Game <mode maplist cvar>`, after the plaque sets the mode cvar.
- The mode script must re-set `g_gametypestring` every map. CVAR_Init overwrites it from `g_gametype` (`fgame/gamecvars.cpp:530-552`) [NV]. UBER does the same (`global/cyberattack_searchdestroy.scr:10-14`).

**Ladder.**
- An MP-owned tier table seeded from `docs/tools/loadout_weapons.tsv` (cls and give columns), never from coop's `loadoutroster.scr` (isolation clause 10).
- No stock melee weapon tik was found, so the final rung is a user decision: bash-only, pistol, or a last rifle. MOHAA's melee is MOD_BASH (`fgame/bg_public.h:479-514`).

**Advance and demote.**
- One `player_killed` subscription in mp.scr.
  - Args: attacker arg 1, means of death arg 9, victim arg 11 (`fgame/player.cpp:3639-3654`) [NV].
  - Handler runs synchronously with self = victim (`_research/mp_progression_understanding.md:548-575`) [C].
- Promote the killer. On MOD_BASH, demote the victim instead. Suicide demotes.
- Keep the tier in player flags. The engine's own kill count drifts: suicide is -1 (`fgame/player.cpp:3752-3753`) and bash demotions are not engine events. Mirror the tier into the Kills column with `addkills`/deltas (`fgame/player.cpp:18531-18538`) [NV].
- Re-subscribe on every map load (`_research/mp_loadout_plan_v1.md:153`).

**Kit.**
- Apply on the spawn edge after the engine's +0.3 s "use primary" event (`fgame/player.cpp:10756`, `:10991-10992`) [NV], and one frame after each credited kill, never inside the synchronous handler.
- Recipe: `takeall` -> `item <tik>` -> `ammo` -> `use`. Research grades it untested (`_research/mp_armories_understanding.md:913-929`) [P].
- Never use `changeGameType`, `giveInventory` or `giveWeaponLoadout` (`coop_mod/mp.scr:17-21`).

**Drops.**
- Set per-player `dontdropweapons` on every spawn.
- `level nodropweapons` does NOT govern the player MP death drop (`fgame/player.cpp:3658-3667`; `fgame/sentient.cpp:6005`) [P].
- `DF_NO_DROP_WEAPONS` is defined but read nowhere (`fgame/bg_public.h:631`) [P].
- The death drop also always spawns a `dm_50_healthbox` (`fgame/player.cpp:3669-3685`) [P]. That is a Healing-toggle decision.

**Win.**
- Option 1: set fraglimit to the ladder length and let the engine end the match on player kills >= fraglimit (`fgame/dm_manager.cpp:1245-1248`, `:1395-1399`) [NV].
- Risk: `fraglimit` persists in-process and coop resets it only in `coop_mod/start_server.cfg:30` / `server.cfg:29`. `server.scr::fixServer` has no caller (`coop_mod/server.scr:295-311`) [NV]. Coop AI kills feed the gt2 team score via `addkills` (`coop_mod/aihandler.scr:1753`), so a coop map loaded without start_server.cfg could hit intermission.
- Option 2: an engine end-match command, which does not exist today (section 9).

**HUD and scoreboard.**
- The tier shows in the Kills column. The leader is the top row.
- The stock `hud_fraglimit` shows "your kills / limit (best)" when fraglimit != 0 (`cgame/cg_servercmds.c:199-209`) [NV].
- Weapon-up and leader changes go out as `iprintlnbold` announcements.
- Stock HUD panels fade when `coop_hudFade` is on (`client/cl_ui.cpp:1876-1885`) [NV].

**Options.** Seeded from GunGame:SM defaults (https://raw.githubusercontent.com/altexdim/sourcemod-plugin-gungame/master/cfg/gungame/css/gungame.config.txt):
- kills per level 1;
- knife/bash steal on;
- suicide loses a level on;
- late-joiner handicap = lowest level;
- turbo off;
- bots can win off.

These need user sign-off.

**Maps.** FFA whitelist only: maps with `info_player_deathmatch`, excluding the 23 coop maps.

**Armory.**
- Policy "none". Skip the armory spectate hold and deploy immediately.
- The F7 and ESC -> Multiplayer Options routes into the COOP armory are live in MP and write archived `coop_lo*` picks. They must be blocked for this mode (`_research/mp_armories_understanding.md:950-953`) [C].

**Progression.**
- User decision. With forced rotation plus cross-team class counting, every class levels for everyone, and bot kills count (`_research/mp_loadout_plan_v1.md:23-39`) [C], so a bot-filled server becomes a farm.
- Options: credit by the weapon actually used with a weight or cap, or count mode challenges only.

**Bots.**
- Kill-driven, so bots play normally.
- Bots re-roll class and model on every death (`BotController::Killed`) and send `primarydmweapon auto` only while `dm_primary` is empty (`fgame/playerbot.cpp:133`) [P]. Re-kit them on each spawn edge.
- Open: do bots hold a script-given weapon for a whole life?

### 3.2 Freeze Tag (sketch)

Two viable bases. Choosing between them needs one playtest.

**FT-A: UBER copy on gt2.**
- Real death. The engine respawns the player, who is then hidden, notsolid, noclip and stripped (takeall) with `.dead=1`.
- A body `script_model` plus a `trigger_use` marks the spot. Melt by touch in `level.melttime` 3 s with a stopwatch.
- Script round counter (`rounds_towin` 5, `round_starttime` 8). Team-switchers mid-round are killed.
- Pros:
  - Proven code to copy (fix methodology).
  - Death is a real `Player::Killed`, so the kill delegate and progression credit fire naturally.
  - Hidden and notsolid players are skipped by bot targeting.
  - Bots melt incidentally by touch.
- Cons:
  - gt2 has no `teamwin` and no native round scoreboard. Round score must come from a script counter, the DM_Scoreboard right-panel lines (`g_obj_alliedtext1-3` / `axistext1-3`), or `team_setscore`.
  - On gt2, `team_setscore` is re-polluted by every kill: `DM_Team::AddKills` adds to `m_teamwins` (`fgame/dm_manager.cpp:258-276`; `fgame/scriptthread.cpp:5493-5538`) [NV].

**FT-B: gt3 with frozen players left engine-dead.**
- The dead player becomes a temp spectator (`fgame/player.cpp:6194-6212`) [P]. A script body prop marks the spot.
- Thaw = script `respawn` (no AllowRespawn gate, `fgame/player.cpp:3096-3143`) [P] + `tele` to the body.
- Engine elimination ends the round, and `TeamWin` gives the native "N Wins" header (`fgame/dm_manager.cpp:1404-1438`, `:1528-1558`; `cgame/cg_scoreboard.cpp:344-348`) [NV].
- **Thaw trap** [C]:
  - `Player::Init` -> `InitDeathmatch` puts a respawned player back into spectator once more than `g_allowjointime` (default 30) seconds have passed since the round started, while `AllowRespawn()` is false (`fgame/player.cpp:10546-10565`, `fgame/gamecvars.cpp:336`).
  - FT-B therefore needs `g_allowjointime 0` in its own start cfg, never coop's.
  - Toggling `level.dmrespawning` instead opens a window where every frozen player can click-respawn.

**Rejected: a killhandler freeze on gt4.** This was proposed in the engine report. gt4 refuses dm maps. A killhandler also suppresses `player_killed`, kill credit and the obituary.

**Common to both.**
- DBNO is forced off by the mode, and the host toggle is greyed out.
- Frozen players must be hidden or notsolid to bots, or bots keep shooting them.
- Bots never press USE on players: they toggle USE only at closed doors and ladders (`fgame/playerbot.cpp:186-226`) [P]. If the melt needs USE, bots need either a proximity melt (isBot branch) or an auto-thaw timeout, or a bot-heavy team soft-locks.
- Round state (round scores, `rounds_towin`) lives in cvars, because gt3 restarts wipe level vars.
- Visible frozen marker on the scoreboard: `injail 1` makes the row send as dead (red). Its only game.dll consumer is the scoreboard, and coop never uses it (`fgame/dm_manager.cpp:2014-2018`; `fgame/player.cpp:12186-12194`) [NV]. The script must clear it on melt and round reset.

**Options.** UBER defaults (`global/cyberattack_searchdestroy.scr:4-32`) [NV]:
- melt time 3;
- round start delay 8;
- rounds to win 5;
- respawn at body: off (UBER `meltrespawn 1`; label the UI "Respawn at frozen body" and store the inverse);
- melt laser 0;
- spectators may join 0.

The engine's `roundlimit` is minutes per round, not rounds to win (`fgame/g_main.cpp:1226-1227`) [NV].

**Armory.** Normal side armory, re-offered each round.

**Progression.** Kills credit through the real death (both options). A melt can be a challenge stat, fed through the MP progression API, never `chal_*` or `xp_*`.

### 3.3 Rifles Only and the weapon-class filter family (sketch)

**Presets.** Absolute dmflags values. The arithmetic from `fgame/bg_public.h:638-644` is [NV] as arithmetic only.
- Rifles only: 528482304 (bans sniper, smg, mg, rocket, shotgun, landmine).
- Snipers only: 524288000.
- Rifles + Snipers: 520093696.
- Coop's all-banned value is 532676608 (`coop_mod/itemhandler.scr:3485`), and mp.scr clears only that exact value (`coop_mod/mp.scr:84-88`) [C].
- No dmflags bit exists for pistols or grenades. They stay in the kit through the separate "Pistols and grenades" block of EquipWeapons (`fgame/player.cpp:10994-10996`). Pistol-only, knife-only and bash-only need a script weapon strip.

**Engine enforcement.**
- Three sites check bans, all on the `dm_primary` class path: `EventPrimaryDMWeapon` (`fgame/player.cpp:12028-12068`), `EnsurePlayerHasAllowedWeapons` (`:10674-10734`) and `EquipWeapons` (`:10737+`) [P].
- The rifle is re-allowed in TWO places if everything is banned (`:10732`, `:18469-18473`) [P]. That could rewrite coop's 532676608 to 528482304, which mp.scr's exact-value test would miss. The logs show no such event; this is unproven.

**Deploy.** mp.scr deploys the hard-coded class `rifle` and retries with `auto` only in gt2 (`coop_mod/mp.scr:189`, `:200-213`) [NV]. Snipers-only would leave players in spectate on FFA and round modes. The deploy class must follow the preset.

**Armory.**
- The MP armory gives tiks directly, which bypasses dmflags. It must enforce the class mask at commit and give time.
- A widget takes exactly one `enabledcvar`, so the tab mask must fold into the planned page-flag family `coop_mpP0A..P5A` / `coop_mpP0X..P5X` (`_research/mp_loadout_plan_v1.md:122-124`) [C]. It cannot be ANDed on a widget.
- Owned guns outside the mask are ignored, not unlocked.

**Drops and pickups.**
- `dontdropweapons` on every spawn.
- Map-placed off-class pickups must be counted and removed. The count is an open question.

**Persistence.** dmflags is SERVERINFO, not archived, and survives map changes (`coop_mod/mp.scr:84-88`) [C]. The mode must restore dmflags when the next map's mode is "none". Coop overwrites dmflags on its own next map, but only in main.scr, after BSP entities spawn.

**Form.** User decision: a modifier row on every MP screen, or its own plaque.

**Progression.** Counts. Only the allowed classes can advance.

**Bots.** Legal automatically, because `primarydmweapon auto` respects the dmflags bits.

### 3.4 BaseBuilder (sketch)

**Base.** gt2. The UBER script is gametype-agnostic and respawns every non-spectator when the build phase ends (scratchpad `alienx_basebuild.scr:273-276`). Its real base gametype is unproven.
- A build-then-fight round variant would go on gt3.
- gt4 is excluded on dm maps.

**Roles.** User decision:
- UBER style: both teams build, then fight.
- ProBaseBuilder style: builders vs zombies, with an infection element.

**Builder.** An MP-owned file. Reuse the recipes, not the coop files:
- `coop_mod/cover.scr`: traced placement, floor fallback, 9 safesolid colliders (`:24-54`, `:95-110`). It calls no other coop_mod script [C].
- `coop_mod/bunker.scr` and `blueprint.scr`: prefabs with a piece budget (`blueprint.scr:390`, default 600).
- `coop_mod/buildmode_catalog.scr`: a data-only list of about 300 models.
- `coop_mod/wallgun.scr`: `coop_playerclip` barriers that block players only (`fgame/entity.cpp:659-667`), usable as build-zone walls.
- Do NOT call `coop_mod/buildmode.scr`. It needs `flags coop_isHost`, which isolation clause 9 forbids MP to set. It waits on `main.scr::waitForMainScript`, which never completes on MP maps. It writes `coop_mod/save/build_<map>.dat` (`coop_mod/buildmode.scr:41`, `:82-91`, `:140`, `:921`) [C].
- Do not write `coop_build_*` cvars. The isolation checker does not forbid them today.

**Phase timer.**
- UBER extends timelimit only when build time is 3600 s or more (`alienx/basebuild.scr:70-75`) [NV]. The mode must extend or validate timelimit itself, or the map ends mid-build.
- Noclip and nodamage are scoped to the build phase.
- `moveto` no-ops on `script_model`; use origin stepping (CLAUDE.md gotcha).

**Unknowns.** Model precache and entity headroom for catalog props on stock MP maps are unmeasured. Test: spawn 100 catalog models on `dm/mohdm1` and log `SV_FindIndex` warnings.

**Armory.**
- Build and prep phases: no weapons.
- Builders: normal or masked armory at fight start.
- Zombies (if that role exists): no armory, a fixed melee kit (no stock knife), and health and speed set on the spawn edge.

**Progression.** Exclude or weight kills of respawning zombies, a farm risk. Zombie melee kills credit challenges only.

**Bots.** Cannot build (no build AI). They can fight in the fight phase. Label the tile "best with humans".

**Options.** From UBER: build time (800 example, 500 in map calls), object limit, build speed (floor 250), take weapons while building, fall damage while building. A separate prep time is a new concept for the user to define.

---

## 4. Start Game, the SELECT THE GAME TYPE cleanup, and hosting

### 4.1 Current flow

**Entry.**
- `ui/main.urc:297` -> multiplayer room (`ui/multiplayer.urc:171-179`, Start New hotspot) -> `ui/multiplayerstart.urc`.
- The mod's `multiplayerstart.urc` is the retail Breakthrough file plus one coop button. It is byte-identical to the deployed pk3 copy.
- Git history is the first commit plus a441e669, which only renamed the plaque title to "MOH Trilogy Coop" (`ui/multiplayerstart.urc:256-272`) [NV].

**Stock types.**
- Each is a picture Label (`m_*button` art) under a transparent Button (`menu_button_trans`, hover `m_buttonhighlight`) with the same rect (`ui/multiplayerstart.urc:40-105` Labels, `:166-254` Buttons).
- Three picture Labels route to `_ffa` exactly as in retail. The later-declared Buttons get the click because FindResponder walks children last-to-first (`uilib/uiwidget.cpp:1744`). This is harmless, but `_research/mp_feature_buildout.md:68` calls it a misroute.
- Each Button pushes a RETAIL options menu (`multiplayerstart_ffa/team/round/obj/tow/lib`). The mod ships none of these.
- maintt `pak4` overrides `_round` and `_team`, and those differ from `pak1`: for example `_team` `dmmapselect 'dm obj'` vs `'dm -'` [NV].

**Retail Start buttons.** `ui_startdmmap <gt> <string> <maplist cvar>`:
- FFA `ui_startdmmap 1 Free-For-All ui_maplist_ffa` (`maintt/pak1.pk3:ui/multiplayerstart_ffa.urc:373`)
- `2 Team-Match ui_maplist_team` (`pak4 _team.urc:521`)
- `3 Round-Based-Match ui_maplist_round` (`pak4 _round.urc:676`)
- `4 Objective-Based-Match ui_maplist_obj` (`pak1 _obj.urc:688`)
- `5 Tug-Of-War ui_maplist_tow` (`pak1 _tow.urc:611`)
- `6 Liberation ui_maplist_lib` (`pak1 _lib.urc:424`)

All [NV].

**Coop.**
- Plaque: `set ui_dmmap nomap;pushmenu coop_start` (`ui/multiplayerstart.urc:270`).
- Tile: `set ui_dmmap m1l1;seta coop_mapcmd map m1l1` (`ui/coop_maps.inc:13`).
- Apply: `exec coop_mod/start_server.cfg` (`ui/coop_start.urc:360`). That cfg ends in `ui_startdmmap 2` (`coop_mod/start_server.cfg:49`) [NV].
- Coop and stock Team-Match share gametype 2. `global/ambient.scr:34-35` hooks mp.scr only when `level.gametype != 0` and coop_mainScriptLoaded != 1, and mp.scr refuses again (`coop_mod/mp.scr:46-49`) [C].

**What `UI_StartDMMap_f` does** (`client/cl_ui.cpp:3331-3480`) [NV]:
- Returns if `ui_dmmap` is empty.
- Queues `set dedicated, sv_maxclients, sv_gamespy, g_gametype, g_gametypestring, fraglimit, timelimit, g_teamdamage, g_inactivespectate, g_inactivekick, sv_maplist, sv_hostname, cheats 0; wait; map <ui_dmmap>`.
- Argument 3 can name any cvar (`:3438`).
- Upstream OpenMOHAA pushes the same set (https://raw.githubusercontent.com/openmoh/openmohaa/main/code/client/cl_ui.cpp).

### 4.2 Why the buttons look massive

- `virtualres 1` scales by (vidWidth/640, vidHeight/480) unless `ui_menuCenter` is nonzero. Nonzero switches to a uniform min() scale with centering (`uilib/uiwidget.cpp:667-675`, `:2555-2590`) [NV].
- `ui_menuCenter` defaults to 0 by the user's 2026-07-27 verdict ("width over proportion"). No shipped cfg or urc sets it.
- At the user's 3440x1440 (bug-1127), a 256x64 plaque renders 1376x192 px. With `ui_menuCenter 1` it would be 768x192.
- **The "compact board on a wall" screenshot is not a menu** [NV]. It is the painted hover art `textures/mohmenu/multi_startgame.tga` (2048x2048), drawn by Label `joingame_bg` while hovering Start New (`ui/multiplayer.urc:158-165`, `:171-179`). It still shows the old "HaZardModding Coop Mod" plaque and came from the menu edit-kit (`_menu_pilot/`; `docs/FEATURES.md:650`). Confirm with the user in one question.

### 4.3 Concrete new layout

Canvas 640x479 (unchanged). The board art is unchanged.

```
+---------------------------------------------------------------+
| selectgame_a/b title strip (0..128)                           |
|                [ MOH Trilogy Coop ]  190,96 256x32 UNCHANGED  |
| CLASSIC (48,134)       HZM MODES (236,134)                    |
| [FFA      ] 48,152     [Freeze Tag ] 236,152  [Gun Game  ] 424,152
| [Team     ] 48,200     [Rifles     ] 236,200  [Snipers   ] 424,200
| [Round    ] 48,248     [Team LMS   ] 236,248  [S&D       ] 424,248
| [Objective] 48,296     [BaseBuilder] 236,296  [ ...      ] 424,296
| [TOW      ] 48,344     [ ...       ] 236,344  [ ...      ] 424,344
| [Liberation] 48,392    [ ...       ] 236,392  [ ...      ] 424,392
| [Back] 8,448 96x24                          [<] 540,440 [>] 580,440
+---------------------------------------------------------------+
```

- **Plaques.** 176x44, exactly 4:1 so the baked 256x64-proportion art does not distort. Columns x = 48 / 236 / 424; rows y = 152 / 200 / 248 / 296 / 344 / 392. The last row ends at 436, above the board edge (~445) and Back (448).
- **Column 1**: the six stock types with their existing `m_*button` art, as picture Label + transparent Button pairs. Keep the pair: single-Button hover semantics are unverified (`uilib/uibutton.cpp` not read).
- **Columns 2-3**: up to 12 modes. Use `weapon_sign` plaques with facfont-20 title text, the coop plaque precedent (`ui/multiplayerstart.urc:257-272`), so no new art is needed to ship. Baked plaques can come later from the edit-kit.
- **Column headers**: verdana-12 Labels, no background.
- **Coop plaque**: rect, shader and command byte-identical. It must never write any MP mode or toggle cvar.
- **Commands.**
  - Every plaque, stock ones included, writes the mode cvar explicitly. Stock plaques write "none".
  - Then: `exec <mode defaults cfg>; set ui_dmmap <default map>; pushmenu <options menu>`.
  - Otherwise an archived or process-lived mode silently applies to a later classic start (`docs/TRAPS.md:366-372`) [NV].
- **Overflow beyond 12 modes**: page with `enabledcvar` gating (bug-461/587/593/589 pattern; `uilib/uiwidget.cpp:1697-1736`) [NV]. No mod urc uses UIListBox or UIListCtrl, so a scrolling list has no precedent here.
- **Rendered size** at 3440x1440 with the current stretch: 946x132 px per plaque, vs 1376x192 today. With `ui_menuCenter 1`: 528x132.
- **Canvas trap**: a widget placed below the declared canvas height draws nothing (`docs/TRAPS.md:435`) [NV]. This menu declares 479, the retail options menus 480.
- **Art traps**:
  - The engine loads `.jpg` before `.tga`. The rendered `selectgame_a/b` and `serverback_a/b` jpgs are untracked (`*.jpg` gitignored, `mod/.gitignore:13`), so TGA-only edits are shadowed (`docs/TRAPS.md:316`) [NV].
  - Re-bake `multi_startgame.tga` after the board changes, or the room hover previews a screen that no longer exists.
- **UI working rules on record** (`docs/TRAPS.md:185-187`; `docs/21-user-preferences.md`) [NV]:
  - The user's screenshot is a .urc's only oracle.
  - Two failed attempts means revert via `git show HEAD`.
  - Never trade a working widget for an unverified one.
  - "A setting is a promise."

### 4.4 Per-mode options screens and host options

**New screens.** Each mode gets `ui/multiplayerstart_<mode>.urc` with a unique menu name:
- clone maintt pak4 Team (team modes);
- clone pak4 Round (round modes);
- clone pak1 FFA (Gun Game).

**Six dead retail controls** [NV]:
- Health Drop, Heal Rate, Realistic Mode, Fast Run Speed, Team Spawn Delay, Round Limit (`ui_healthdrop`, `ui_healrate`, `ui_realismmode`, `ui_sprinton`, `ui_team_spawn_interval`, `ui_roundlimit`).
- Retail `moh_breakthrough.exe` contains all six names. The live `G:\mohaa-gl2\openmohaa.exe` and the fork source contain none.
- The host's `omconfig.cfg:4609-4630` still holds saved values for them.
- Cloned screens must drop these controls, or have the apply cfg set the real cvars (`g_healrate`, `g_realismmode`, `sv_sprinton`, `sv_team_spawn_interval`, `roundlimit`). `g_healthdrop` itself has no reader (section 5).
- `docs/tools/audit_menu_cvars.py` never scans `multiplayerstart*` (MENU_HINTS at `:43-44`) [NV], so nothing catches this today.

**Space.** The retail Team screen is full, with about 48 virtual px free at y 367-416 on the right (widget dump of `pak1 _team.urc`) [NV].

**Host Rules screen.**
- One shared `ui/mp_hostrules.urc`, pushed by a button in that free band on every MP options screen (stock copies and new modes). Share it via include, as `ui/serverback.inc` and `ui/coop_maps.inc` are shared.
- `coop_start.urc` never reaches it. That keeps coop out structurally.
- The six stock screens get the button only if the mod ships its own copies of all six retail screens (team/round from pak4). That is a user decision.

**Mode options.** Seeded with UBER and GunGame:SM defaults (section 3). Per-mode map list:
- A text Field plus a "Default Rotation" button that execs `coop_mod/cfg/mp_maplist_<mode>.cfg`.
- The stock Setup Rotation editor writes only the six `ui_maplist_*` cvars, and "tow" writes `ui_maplist_obj` (`client/cl_uimaprotationsetup.cpp:64-77`, `:339-355`) [NV]. Drop its button unless the exe gains a filter branch.

**How values must be applied.**
- A cfg cannot copy a menu value into a server cvar. There is no `$` expansion in `qcommon/cmd.c` and no copy command among the cvar commands (`qcommon/cvar.c:1780-1806`) [NV].
- `reset` restores the wrong default before the game module registers the cvar (`qcommon/cvar.c:544`) [NV].
- So: per-screen apply cfgs write explicit values, the checkboxes bind non-latched cvars, and mp.scr snapshots them once at map init. Alternatively, an MP-only engine start command.
- Coop's `ui_startdmmap 2` path must stay unchanged.

**Stomp class to avoid (bug-1326).** `ui_startdmmap` re-pushes archived `ui_*` values after any cfg. Any new widget bound to a cvar it writes inherits the stomp (`coop_mod/start_server.cfg:20-21`) [NV].

### 4.5 What is latched, and when things take effect

- **`g_gametype`** is USERINFO|SERVERINFO|LATCH (`fgame/gamecvars.cpp:471`). SV_Map_f re-registers it and applies the pending value before loading, so `set g_gametype N` then `map` in one buffer applies N to that map (`server/sv_ccmds.c:210-226`; `qcommon/cvar.c:489-495`) [NV]. `gamemap` also picks up a latched value at DLL re-init (`fgame/gamecvars.cpp:471`; trace in gap 1).
- **Other latched cvars**: `g_realismmode` (`fgame/gamecvars.cpp:473`), `maxentities`, `sv_maxbots` and `sv_sharedbots` (`:675-676`) [P]. Each applies at the next map load.
- **Checkbox trap**: a checkbox `linkcvar`'d to an already-registered LATCH cvar stores `latchedString` and looks as if it did not toggle (`qcommon/cvar.c:685-702`) [NV]. Bind non-latched host prefs instead.
- **Mode cvar and toggles**: read once at map init. A mid-map change applies at the next map, announced retail-style with `reloadmap`.
- **Statefile**: `g_statefile` is set by mp.scr at the ambient prespawn, before any player Init (`coop_mod/mp.scr:77`).

### 4.6 Listen vs dedicated

- `ui_startdmmap` exists only in the client (`client/cl_ui.cpp:5540`) [NV]. A dedicated server uses `+set` cvars or a cfg, then `map`.
- The code trace says a cfg `set g_gametype N; map X` works (`qcommon/cvar.c:685-697`; `server/sv_ccmds.c:216`). This contradicts the comment at `coop_mod/cfg/dedicated_example.cfg:11-14`. One dedicated boot settles it.
- Ship a separate `mp_dedicated_example.cfg` that sets gametype, mode cvar, host prefs, bot cvars and rule baseline before `map dm/...`. Leave the coop `dedicated_example.cfg` untouched.

### 4.7 Callvote

- The engine loads a root `callvote.cfg` for any non-single-player gametype (`fgame/level.cpp:1903-1909`) [NV]. The live list is retail `maintt/pak3.pk3:callvote.cfg`. It already has compound entries (`1; map obj/MP_Palermo_OBJ`, `g_realismmode 1;reloadmap`) and `bitset dmflags 22..28` weapon votes (`:30-40`, `:177-197`, `:211-221`) [NV].
- The mod's `_callvote/callvote.cfg` ships at a non-root path and is inert (`build.ps1:118`).
- **Typed votes** accept only restart/nextmap/map/g_gametype/kick/clientkick/fraglimit, reject `;`, and range-check `g_gametype` to 1-6 (`fgame/player.cpp:11661-11790`) [NV]. A custom mode needs a menu (numeric) LIST entry.
- **Maplist override**: a passed vote containing `g_gametype` runs SetupMaplist, which execs `maplist_<gt>.cfg` and overwrites `sv_maplist` with the stock `ui_maplist_<gt>` (`fgame/level.cpp:2078-2128`) [NV]. A mode vote therefore lands the server on stock rotation, and the mode cvar persists.
- **Coop exposure**: a mod-shipped root `callvote.cfg` replaces the vote list on coop servers too. Coop lobbies can already vote the server out of coop with `g_gametype N; map dm/...`. Whether coop servers see MP entries is a user decision.

### 4.8 Map pool rules for every mode

**Exclude the 23 coop-integrated maps** (repo and deployed pk3) [P]:
- dm/: thesiege_dm, bot_Foy_West, Ramelle, german, stalingrad_3_dm, bot_Foy_East, siegecastle_dm, operation_fubar, SAVING_PRIVATE_RYAN.
- obj/: wilhelmstein_1767_obj, omaha_beach, obj_radararea, obj_praha1945, bobobjaa01, bobobjaa02, bobobjaa03, bastogne, LastStand, obj_lakeside_ai, dogwhite, CapturedBase, blitzschnee, obj_hms_hood.
- They are routed through `coop_mod/cfg/maptour.cfg:6-29`.

**Other filters.**
- FFA modes need `info_player_deathmatch` (section 2 list).
- gt4 lists only obj maps. The stock obj picker already filters to `*_obj*` / `*_ship*` (`client/cl_uimpmappicker.cpp:159-192`).
- Derive the lists from a scan, never by hand.

---

## 5. Host toggles

### 5.1 Current MP state (before any work)

| Feature | MP today | Why |
|---|---|---|
| DBNO | OFF | `dbno_start` is threaded only from coop `coop_mod/player.scr:1228`. `manageDead` (reachable in MP via the coop statefile, `coop_mod/player_Torso.st:3230` -> `events.scr:46-50` -> `main.scr:500`) enters DBNO only when `coop_dbno_cumulative > 0`, which is never assigned in MP (`coop_mod/player.scr:1567-1578`) [C] |
| Medkits / team heal | OFF | Name bus index 8 plus monitors started only on coop spawn (`coop_mod/player.scr:644`, `:1231-1236`) [C]. Engine death healthbox and health pickups are stock and ON (`fgame/player.cpp:3669-3685`) [P] |
| ADS | ON | `BUTTON_COOPADS` (bit 13) is read engine-side in every gametype. mp.scr threads the ADS walk slowdown (`coop_mod/mp.scr:238`) [P] |
| Prone | ON | `TickCoopProne` gated only by `coop_prone`, no gametype term (`fgame/player.cpp:5719`, `:14032-14090`) [C] |
| Cover | Auto ON, manual OFF | `TickCoopCover` gated by `coop_coverAuto` (flags 0) (`fgame/player.cpp:5817`, `:17423-17452`) [C]. Manual cover goes through name bus 26, which MP does not dispatch |
| Third person | Uncontrolled | `cg_3rd_person` registered with flags 0, CVAR_CHEAT removed from upstream (`cgame/cg_main.c:165` vs `git show eaac51be~1`) [C]. Coop's 3P cycle never runs in MP |

### 5.2 Delivery channel (research verdict; alternatives in section 9)

**The verdict.** One server-wide integer bitmask `g_mpOff` of DISABLED features.
- Registered CVAR_SERVERINFO|CVAR_ROM in game.dll.
- Zeroed in `Level::Init` beside `m_bStealthNative` (`fgame/level.cpp:795-797`).
- Written non-zero only by `coop_mod/mp.scr::main`, after its coop refusal guard and before its first wait.
- Bit layout: 1 DBNO, 2 heal/medkits, 4 ADS, 8 prone, 16 cover, 32 third person.

**Why it works.**
- **Precedent**: dmflags -> `pmove_t.alwaysAllowLean`. The server reads the cvar, cgame reads the serverinfo copy (`fgame/player.cpp:4399-4403`; `cgame/cg_predict.c:636`) [C].
- **Replication**: any CVAR_SERVERINFO change is pushed into CS_SERVERINFO by SV_Frame (`server/sv_main.c:1120-1122`), and cgame re-parses it (`cgame/cg_main.c:546-547`; `cgame/cg_servercmds.c:125-152`) [C].
- **Timing** [P]:
  - Stock MP scripts exec `ambient.scr` right after `level waittill prespawn`. Prespawn is released inside `Level::SpawnEntities` (`fgame/level.cpp:1241-1242`; `server/sv_init.c:845`), before the gamestate CS_SERVERINFO is built (`server/sv_init.c:966`). So the value is in the first gamestate.
  - Under BT the loaded `obj_team1.scr` is the maintt pak1 copy (prespawn `:36`, ambient `:43`).
  - The `:966` snapshot runs only on a different-map load. On a same-map restart the value arrives through SV_Frame.
- **Must be engine-registered.** Script `setcvar` is a forced set that ignores ROM and LATCH (`fgame/scriptthread.cpp:3096-3098` -> `qcommon/cvar.c:735-737`) [C]. A forced set on a non-existent cvar creates it with flags 0 (`qcommon/cvar.c:634-639`), so it would never reach serverinfo.
- **What ROM still does**: it refuses console, cfg and rcon non-forced sets, and it sorts the key first in the 1350-byte info string (`qcommon/cvar.c:1564-1575`; `qcommon/q_shared.h:301`).
- **Level::Init runs on every map load**, via `Level::SetMap` from `SV_SpawnServer` on every path (`fgame/level.cpp:1550-1556`) [P]. That includes round restarts, so mp.scr must re-write the mask after each restart. The restart re-runs the map script and wipes `level.coop_mpRun`. Whether there is a one-frame 0 flash on round restart is a playtest item.
- **Polarity**: disabled bits mean 0 = today's behaviour on coop maps, single player and non-HZM servers (a missing key is atoi 0). Coop needs no code path of its own.

**Rejected per-player carriers** [C]:
- `pm_flags`: a hard 16-bit wire field with bits 0-15 all assigned (`qcommon/msg.cpp:3379`, `:3441`; `fgame/bg_public.h:256-276`; `cgame/cg_predict.c:645-646`).
- `stats[]`: full at 32/32 (`fgame/bg_public.h:581-592`).
- `camera_flags`: spare wire bits, but wiped to CF_CAMERA_CUT_BIT at `fgame/player.cpp:8189`, `:8217`, `:8238`, `:8305`.
- A new netfield: a protocol change.
- Per-client stufftext cvars: they linger in the client across servers, and a listen host shares one cvar table (`cgame/cg_predict.c:649-656`).
- mp.scr's 0.5 s poll would also leave each life's first half-second ungated (`coop_mod/mp.scr:107`, `:117`, `:172-173`).

**Listen-host trap** [C]. On a listen host fgame and cgame share one cvar table. cgame must read only the serverinfo-parsed `cgs` copy, never `cgi.Cvar_Get("g_mpOff")`, or every host test passes while remote clients differ (`cgame/cg_predict.c:649-655`).

**Engine predicate.**
- Factor `CoopMapNameIsCoop` plus the `coop_mainScriptLoaded` type test out of `fgame/sentient.cpp:1582-1657` into a shared `G_CoopLoaded()` [C].
- The test rejects when the variable exists with ANY type, and also rejects coop map names.
- Every engine gate treats coop as "all allowed". Never gate on gametype: coop is gametype 2.

### 5.3 Naming (unsettled, see 8a)

**Research recommendation: one `g_mp*` family.**
- Host prefs: `g_mpDbno`, `g_mpHeal`, `g_mpAds`, `g_mpProne`, `g_mpCover`, `g_mp3p`. Archived. Pre-registered in G_InitGame so a script `getcvar` cannot create them empty (`docs/TRAPS.md:374-382`; `fgame/g_main.cpp:298-312`) [NV].
- Plus the mirror `g_mpOff`.
- Collisions: zero hits for `g_mp`, `mp_`, `hzm` cvars in the engine.

**Why not `coop_mp*`.** The cgame stufftext filter lets any server `seta` any `coop_*` cvar into a client (`cgame/cg_servercmds_filter.cpp:173-175`, `:206-208`) [P]. Any server a player visits could rewrite archived `coop_mp*` host prefs.

**Competing proposals in the corpus**:
- `hzmp_*`: 0 hits (armory/progression report).
- `coop_mpMode` / `coop_mpGG*` / `coop_mpFT*` / `coop_mpBB*` / `coop_mpRF*`: options report. It avoids `coop_mpa<digit>`, `coop_mpx<digit>`, `coop_mpm*` (3 existing hits, likely `coop_mpmenu`) and `coop_lo*`.

**Constraints whichever family is chosen.**
- Never reuse coop names: `coop_dbno`, `coop_prone`, `coop_coverAuto`, `coop_ads*`, `cg_3rd_person`.
- Never add the new family to `autoexec.cfg`. It force-sets `coop_dbno 1` (`:32`), `coop_sprint 1` (`:300`), `coop_adsSpeedMult 1.0` (`:326`), `cg_adsZoom 0.5` (`:110`) and `bind mouse2 +button13` (`:1134`) every launch [C].

### 5.4 Per toggle

**Default policy (user decision).** One option: match today's MP (ADS, prone, cover, 3P on; DBNO and medkits off). The recorded decision says "modern ON by default" (`docs/DECISIONS.md:630-660`). DBNO and medkits should stay greyed out until the port lands.

#### DBNO

- **Mechanism.**
  - OFF is today's state and also expressible through the existing per-map level var `level.coop_dbno_disabled` (`coop_mod/dbno.scr:43`) [C].
  - ON means mp.scr threads an MP DBNO start after `health 100`. That is a port, not a toggle.
- **What the port must fix.**
  - **Team test.** The revive candidate scan has no team test (`coop_mod/dbno.scr:844-848`, label `dbno_teamrevive_monitor` `:750`). A second filter at `:1013` also lacks one [C]. The scan has no spectator test either, and spectators carry full health (`coop_mod/mp.scr:156`) [C].
  - **Down banner.** Goes to every other player with `coop_isActive == 1`, with no team test (`coop_mod/dbno.scr:241-257`) [C].
  - **$world kills** [P]. Only three: head-hit instakill `:152`, bleed-out `dbno_die` `:705`, give-up `:1370`. They credit nobody, because the frag gate requires a Player attacker (`fgame/player.cpp:3563-3565`). Enemy finishers do get credit through normal damage (`coop_mod/dbno.scr:335-365`).
  - **Round deadlock** [P]. `DM_Team::IsDead` has no IsCoopDbno bridge (`fgame/dm_manager.cpp:552-562`; `fgame/player.h:1236`), and a downed player at health 100 reads alive. In gt3-6 an all-downed team never loses by elimination. The round clock and the default 60 s bleed-out still eventually end it (`coop_mod/dbno.scr:199-200`, `:413-424`).
  - **Gametype conversion** [C]. The revive re-give runs `main.scr::changeGameType 0` then a hardcoded 2 (`coop_mod/dbno.scr:1202`, `:1262`; `coop_mod/medkit.scr:614`, `:675`; `coop_mod/main.scr:1802-1843`). Script `setcvar` is a forced set that bypasses the latch, so the server becomes Team Match immediately.
  - **XP leak** [C]. `xp_award` calls from revive paths (`coop_mod/dbno.scr:407`, `:974`, `:976`, `:1141`) run `xp_init`, which enables XP before its MP guard (`coop_mod/xp.scr:20`, `:23`, `:309`). Every passing award writes server cvar `coop_xp_<id>` (`:502`), which coop's `xp_identify` reads FIRST on the next coop map (`:363-365`). Rank unlock writes `coop_unlocks_<id>` and `unlocks_<id>.dat` (`coop_mod/challenges.scr:1239-1240`).
  - **Health model.** `dbno_start` sets `healthonly 9999` (`coop_mod/dbno.scr:47`), while mp.scr sets `health 100`. The threshold default of 250 assumes coop HP scaling (`:111-116`).
  - **Heal target.** Revive heals to `level.coop_health`, which is NIL on MP maps (`coop_mod/dbno.scr:1185`) [P].
  - **Coupling.** `dbno_start` also seeds `coop_medkits=1` and `coop_cover_placements=2` (`:35-36`).
- **Server enforcement**: script, plus engine for the IsDead bridge and optionally kill credit.
- **Client**: `coop_dbnoView` is stufftexted with `set` (not archived). The `coop_*` filter allows it.
- **FFA**: no teammates exist. Bleed-out only, or grey out.
- **Engine work**: an IsDead bridge for gt3-6, gated by the coop predicate.
- **Coop untouched**:
  - Never write `coop_dbno` (archived and force-set).
  - Every change inside `dbno.scr` must branch on `level.coop_mpRun`, or be copied into an MP-owned file.
  - Add `coop_dbno` to the isolation FORBIDDEN list.
- **Bots**: never hold USE on a body, so they cannot revive (`fgame/playerbot.cpp:186-226`) [P].

#### Healing / Medkits

"Healing" means three different things. The user must say which.

- **(a) Coop medkit system** (self-heal, refill from world packs, team heal).
  - Mechanism: mp.scr threads the medkit HUD and team-heal monitors plus `coop_scan_health_entities`.
  - Blockers:
    - `medkit_teamheal_pick` has no dmteam test (`coop_mod/medkit.scr:355-376`) [P].
    - It compares against NIL `level.coop_health` (`:52`, `:87`, `:145`, `:248`, `:369`, `:435`, `:590`) [P].
    - `xp_award` calls (`:449-450`, `:684`).
    - `changeGameType` in `dbno_selfrevive` (`:614`, `:675`).
    - The use key is name bus index 8, which MP does not dispatch. MP would need a narrow token whitelist in mp.scr before `mp_cleanName` (`coop_mod/mp.scr:131-133`, `:271-284`).
  - Never route MP input through `player.scr::playerNameCommand` [P]. godmode, noclip and give-all self-authenticate (`coop_mod/developer.scr:817-837`, `:873-885`, `:904-915`), but unauthenticated slots include 14 `dbno_enter`, 16 `ammobox_place` and 2 teleport (`coop_mod/player.scr:638`, `:656`, `:658`).
- **(b) Stock health pickups and the death healthbox.**
  - `g_healthdrop` has NO reader anywhere in the engine (`fgame/gamecvars.cpp:479` registration only) [P]. The retail "Health Drop" checkbox and coop's `g_healthdrop 0` are both inert.
  - Every MP death always drops `models/items/dm_50_healthbox.tik` (classname Health) (`fgame/player.cpp:3669-3685`) [P].
  - Only `DF_NO_HEALTH` removes Health entities. It does so at construction (`fgame/health.cpp:58-61`) [C], during `SpawnEntities`, before any map script runs (`fgame/level.cpp:1160-1221` vs `:1481-1493`) [NV]. dmflags survives the map change, so the next coop map would lose every BSP health pickup before coop re-stamps dmflags. **Do not use DF_NO_HEALTH.**
  - Leak-free alternative: script removal of Health entities on MP maps. Open: does `$health remove` catch all of them (`fgame/health.cpp:63-67`)? Plus an engine check that makes the MP death healthbox obey the MP rule, gated by the coop predicate.
  - Conflict in the corpus: one report cites `level.nodrophealth` (`fgame/sentient.cpp:4806-4808`, reset `fgame/level.cpp:848`) as controlling health drops. The verified correction says the player MP death path does not consult it. Treat `level.nodrophealth` as actor-only until read.
- **(c) Heal-over-time rate.**
  - `g_healrate` (no flags, default 10) heals `max_health*(g_healrate/100)` per second from pending heal. Values of 0 and very large values apply instantly (`fgame/player.cpp:6436-6450`; `fgame/health.cpp:84-120`) [NV].
  - Coop leaves it at 100000 in-process (`coop_mod/start_server.cfg:26`; `coop_mod/itemhandler.scr:79-88`) [NV]. The MP start must write it explicitly.
  - Coop re-asserts its own value once per map on the first item spawn, so MP cannot leak it back.
- **Default**: user decision. **Engine work**: only for the death-healthbox gate.

#### ADS

- **Server consumers of BUTTON_COOPADS** [P]:
  - statemap raise (`fgame/player_conditionals.cpp:1139`);
  - spread (`fgame/weapon.cpp:2046-2052`, `:2447`);
  - sniper zoom on the press edge (`fgame/player.cpp:5918`);
  - speed multiplier (`:4864-4870`);
  - brace force (`:5826-5828`);
  - supine (`:14790`, `:14822`), `:14943`, head tracking (`:15615`), sprint "aiming" (`:17013`), cover peek (`:17161`, `:18049`);
  - script `coopadsheld` (`:1345-1353`).
- **No master enable cvar exists**, only tuning cvars (`docs/generated/CVARS_COOP.md:225-231`) [C].
- **Server enforcement.** Strip BUTTON_COOPADS from `current_ucmd` in ClientThink before `last_ucmd = *current_ucmd` (`fgame/player.cpp:5879`) [P], for non-scoped weapons, when the bit is set and coop is not loaded.
  - Scope zoom is ALSO bound to BUTTON_ATTACKRIGHT (`fgame/player.cpp:5907-5912`), and autoexec binds V to `+attacksecondary` (`autoexec.cfg:1138`). Scopes stay reachable.
  - The spread bonus also applies while zoomed (`fgame/weapon.cpp:2049`). Decide whether that stays.
  - `TickCoopProne` (`:5719`) and `TickCoopCover` (`:5817`) read the previous `last_ucmd`.
- **Client.** `CG_AimingDownSights` reads the LOCAL usercmd bit (`cgame/cg_view.c:4962-5002`) [P], so a server-only strip leaves irons and zoom drawn.
  - It also returns true while `coop_braceMounted` is set, which the server stuffs (`fgame/player.cpp:15350`). That channel can force ADS on but not off.
  - cgame must also refuse ADS when the serverinfo bit says off.
- **Script.** mp.scr skips `ads.scr::coop_ads_monitor` (`moveSpeedScale 0.3`, `coop_mod/ads.scr:16-35`). The engine slowdown `coop_adsSpeedMult` defaults to 1.0, which is off (`fgame/player.cpp:4860-4865`).
- **Open**: what RMB does when ADS is off, since bash is on V.
- **Engine work**: game.dll + cgame.dll.
- **Coop untouched**: mask bit 0 on coop maps. `coop_adsSpeedMult` is already FORBIDDEN (`docs/tools/check_mp_isolation.py:185-187`).

#### Prone

- **Server.** In `TickCoopProne`, treat "bit set and coop not loaded" like `!pOn`. That branch already clears all prone state (`fgame/player.cpp:14032-14090`) [C]. Gate slide-to-prone (`coop_slideToProne`, `:16913`) the same way.
- **Client** follows server state [P]. `PMF_VIEW_PRONE` is set server-side only when `m_bCoopProne` (`fgame/player.cpp:4766-4767`), and pmove derives hull and view from it (`fgame/bg_pmove.cpp:1109-1131`). The stock `MOVECONTROL_CROUCH` path sets it regardless (`fgame/player.cpp:4793-4794`).
- **Engine work**: game.dll only.
- **Coop untouched**: never write `coop_prone` (archived, FORBIDDEN).
- **Keep** the coop statefile loaded in MP. The conditionals simply never fire, and there is no mid-map statemap swap.

#### Cover

- **Server** [C]:
  - In `TickCoopCover`, zero the auto dwell and clear `m_bCoopCoverRequested` when the bit is set (`fgame/player.cpp:17423-17452`).
  - Manual cover sets `m_bCoopCoverRequested` through the script event `coop_setcover`, which `coop_coverAuto` does not gate. Both paths must be gated.
  - `coop_coverAuto` is flags 0: process-lived, not archived.
- **Client**: the forced 3P while covered and lean prediction key off replicated `PMF_COOP_COVER` (`fgame/bg_public.h:274`; `cgame/cg_modelanim.c:2095`; `cgame/cg_predict.c:657-667`) [C]. If the server never grants cover, the client does nothing.
- **Interaction**: auto-cover drives a 3P shoulder camera. With 3P off, cover must fall back to a first-person view or be forced off.
- **Sandbag deployables**: a separate feature (`coop_mod/cover.scr`, name bus 9, `level.coop_noDeployables`), off in MP.
- **Engine work**: game.dll only.
- **Coop untouched**: never write `coop_coverAuto` (FORBIDDEN).

#### Third person

- **Client-only enforcement.** cgame forces first person and suppresses cover auto-3P and free cam when the bit is set (render decision `cgame/cg_view.c:6422`, `:6453`; `cgame/cg_modelanim.c:2082`, `:2095`) [C].
- **Cannot be enforced against a modified client.** The protocol fork keeps stock clients out (`_research/mp_coexistence_plan.md:118`).
- **Do NOT restore CVAR_CHEAT.** On a non-cheat server the client resets CHEAT cvars at connect and refuses non-forced sets. That breaks coop's stuffed 3P cycle (`client/cl_parse.cpp:449-453`; `qcommon/cvar.c:678-682`; `coop_mod/player.scr:1724-1734`) [C].
- **Do not stufftext `set cg_3rd_person 0` or `cg_freecam`** from MP. `cg_freecam` is CVAR_ARCHIVE on the client (`client/cl_main.cpp:4296`), so this rewrites the player's saved choice.
- **"ON" with a key**: an MP token handler reusing `thirdperson.scr` logic, but not `set3rdPerson`, which wraps `changeGameType 0/2` (`coop_mod/player.scr:1729`, `:1732`) [C].
- **Engine work**: cgame.dll only.

#### Candidate extra toggles

All are live in MP today with no coop term. Each could get its own toggle or ride one "classic" master switch; that is a user decision.

- **Sprint/stamina.** Server `TickSprint` (`fgame/player.cpp:16981`, `:5808-5815`) plus a client stamina mirror from the client's own archived cvars (`cgame/cg_view.c:3995-4050`) [C]. Needs both DLLs, or prediction mismatches. Never stufftext `coop_sprint*`.
- **Limp.** `TickLimp` gated by `coop_limp` (`fgame/player.cpp:13949-13985`). The warning banner is started by mp.scr (`coop_mod/mp.scr:242-245`). game.dll gate + mp.scr skip.
- **Tinnitus / injured muffle / wounded breathing.** Script monitors started by mp.scr (`coop_mod/mp.scr:239-241`). Script-only skip. Keep the `s_volume`/`s_sfxduck` safety stuffs (`:250-253`). The engine blast ping at `fgame/weaputils.cpp:3756-3761` may be inert without the monitor (unverified).
- **One-mag pickups.** `coop_pickupOneMag` (`fgame/weapon.cpp:3953-3957`). game.dll gate.
- **Damage falloff.** `coop_dmgFalloff`, applies to player fire (`fgame/weaputils.cpp:2948-2955`). game.dll gate.
- **Realism.**
  - `g_realismmode` is latched and forced to 0 only in single player (`fgame/gamecvars.cpp:473-476`) [P].
  - In MP it moves player head/helmet/neck multipliers from 2.0 to 5.0 (`fgame/sentient.cpp:965-972`; `fgame/player.cpp:10524-10545`) and gates realism TIKI commands (`fgame/entity.cpp:6574-6636`).
  - Coop's reset is commented out (`coop_mod/start_server.cfg:11`); only the dev `server.cfg:11` (via `coop.cfg:3`) sets 0. A realism toggle requires coop's start to restore 0 first. That is a coop change and needs approval.
- **Bots**: section 4 / 6.
- **Heal rate**: above.

### 5.5 Conflict with the decision record

`docs/DECISIONS.md:630-660` records [C]:
- ONE server cvar `g_modernmp`;
- per-system cvars REJECTED (`:640`);
- DBNO under co-op-only "NEVER" in standard MP (`:646-647`);
- "OFF must mean classic" (`:657-660`).

`g_modernmp` and the coop-session flag were never built: 0 hits in `openmohaa-hzm/code` [C]. The user's 2026-09-13 request must supersede the one-switch and DBNO rows. The "OFF means classic" requirement stays: each toggle ships only with a gate at every call site, or is listed on the Host Rules screen as a known exception. This is a docs task for a non-research session.

---

## 6. Interplay with the MP armories and MP progression

**Standing progression decisions** (`_research/mp_loadout_plan_v1.md:23-39`) [C]:
- MP-only challenges unlock gear.
- MP starts over.
- Guns unlock by kills per class (both teams).
- Variants and skins unlock by kills per weapon.
- Players carry their own progress, client-held and needing a tamper check.
- Bot kills count.
- One starter gun per class stays free (an open assumption).

**Per-mode policies.** Each mode declares an armory policy and a credit policy:
- Standard gametypes 1-6: full side armory with the spectate hold. Credit counts.
- Class filter family: masked armory, enforced at commit and give. Credit counts, only allowed classes advance.
- Gun Game: armory none, deploy immediately. Credit is a user decision (full, weighted, capped, or challenges only).
- Freeze Tag: full armory, re-offered per round. Freeze credit comes free with a real death (FT-A, FT-B). A killhandler variant would need explicit credit calls.
- BaseBuilder: builders full or masked, zombies none. Zombie kills excluded or weighted.
- S&D and Cyber Attack: full with round hold. Planter and defuser credit needs engine delegates (`_research/mp_progression_understanding.md:954-955`).
- Infection: fixed kits for both sides.

**Credit dispatch is a DESIGN, not code** [P]:
- `player_killed` rejects suicide, telefrag, team kills, bot attackers, and round-won or intermission kills.
- The class is frozen at kill time. MOD 16/9/14 kills resolve from the inflictor model. Turret and vehicle kills get no class credit (`_research/mp_progression_understanding.md:40`, `:557-567`, `:647-681`).
- Only kills BY humans earn credit, including kills of bots.

**Non-death events.**
- A freeze or DBNO down is not a death, so `player_killed` never fires.
- A set `killhandler` suppresses the delegate (`fgame/player.cpp:3534-3544`) [C].
- The DBNO bleed-out death has attacker $world and is rejected (`coop_mod/dbno.scr:705`).
- Modes must emit credit through the MP progression API. Never through `chal_*` or `xp_*`, and never by calling `xp_award`.

**Armory holds.**
- In round gametypes, a player who joins more than `g_allowjointime` after the round starts becomes a temp spectator (`fgame/player.cpp:10546-10569`) [C]. An armory hold can strand players, so modes without an armory must deploy immediately.
- mp.scr's per-player `coop_mpTeam` flag resets on every round restart, so its team-edge deploy may re-send `primarydmweapon rifle` each round and override the class (`coop_mod/mp.scr:136-151`). Not runtime-verified.

**Class masks and bots.**
- dmflags class bits remain the engine and bot layer. The armory mask folds into the page-flag family.
- The engine re-allows rifle when every class is banned. The armory must mirror that rule, or refuse all-banned masks.

**Kit ownership.** mp.scr today forces `health 100` per spawn (`coop_mod/mp.scr:229`) and deploys `rifle`. Both must become mode-aware (spawn health, kit, deploy) and survive round restarts.

**Farming.** Gun Game, BaseBuilder and bot-filled servers can farm client-carried progression, and listen hosts can mint (`_research/mp_progression_understanding.md:71`). The progression anti-farming policy needs a per-mode credit weight. Whether a host-visible "bots count for progress" toggle exists is a user decision.

**Toggle-dependent challenges.** Challenges that need revives, heals, prone or cover kills are unearnable on servers with that toggle off. The MP challenge table must tag toggle-dependent rows.

**Weapon finishes in Gun Game.** Whether the tier gun shows its owned finish is a user decision.

**Coop armory routes.** F7 and ESC -> Multiplayer Options -> "Allies Player Model" write archived `coop_lo*` picks even in MP (`autoexec.cfg:1378`; `ui/multiplayeroptions.urc:174`) [C]. Every MP mode, and plain MP, needs them blocked or redirected.

**Arena maps.** A host who picks a coop-integrated `y_hzm_maptour` arena for an MP mode gets the full coop framework with forced allies, and the mode silently does not run.

**HUD slots.**
- Slots below 100 fade when the player is calm (`cgame/cg_drawtools.cpp:696-697`), in MP too.
- The 100+ band is allocated on paper, but most tenants never run on MP maps: lobby 100-126, Service Record 150-249, objectives toast and panel (`_research/hud_slot_map.md:27-38`, `:87-90`) [P].
- Contention exists only with MP-reused features: DBNO 135-140 and 216, XP popup 142-144, cover 145-147, ammobox 148.
- Reserve an MP range (lobby 100-117 is cleanest) as a recorded never-concurrent double-booking. Verify with `docs/tools/hudslots.py`.

---

## 7. Isolation contract additions

`docs/tools/check_mp_isolation.py` today, as corrected:
- **Clause 1** walks every `maps/**/*.scr`.
- **Clause 2** (refusal guard), **clause 9** (`coop_isHost`) and **clause 10** (armory calls) read only `coop_mod/mp.scr`.
- **Clauses 4/5** (forbidden coop-cvar writes) scan `MP_FILES` = `mp.scr`, `cfg/mp_start.cfg`, `cfg/mp_reset.cfg` (`:180`, `:185-187`). The two cfgs do not exist and are silently skipped (`:189-202`).
- **Clause 7**: regex `coop_mp(?:a\d|x\d|FreeKit|LockLoadout)` over every `coop_mod/**/*.scr`, with `mp.scr` and `loadoutpick.scr` allowed (`:221-241`).
- **Clause 6**: diffs only `ui/coop_loadout.urc`.
- There is no bot clause and no engine-rule-cvar clause [P].

Proposed additions, consolidated:

1. **MP_GLOB.** MP files are enumerated by glob: `coop_mod/mp.scr`, `coop_mod/mp_*.scr` (or `coop_mod/mp/**`), `coop_mod/cfg/mp_*.cfg`, the MP start menus (`ui/multiplayerstart_<mode>.urc`, `ui/mp_hostrules.urc`, `ui/coop_mp*`).
   - Run clauses 2, 4/5, 9 and 10 over all of them.
   - Every mode script opens with the `coop_mainScriptLoaded` refusal guard.
   - A listed MP file that is missing FAILS instead of being skipped.
2. **Wider FORBIDDEN list** for MP_GLOB: add `coop_dbno*`, `coop_teamRevive*`, `coop_medkit*`, `coop_sprint`, `coop_sprintRegen`, `coop_tinnitus`, `coop_woundMuffle`, `coop_injuryCough`, `coop_coverLean`, `coop_build*`, `cg_3rd_person`, `cg_freecam`. Existing entries stay.
3. **Default-deny coop mechanics.** MP_GLOB may not reference `coop_mod/(dbno|medkit|buildmode|thirdperson|cover|ammobox|officer|lobby|xp|challenges).scr`, `main.scr::changeGameType`, `player.scr::set3rdPerson`, `player.scr::playerNameCommand`, or `itemhandler` `giveInventory` / `giveWeaponLoadout`, unless the label is on an allowlist carrying a DECISIONS.md anchor.
   - Add a transitive check against `dbno.scr::dbno_enter` / `dbno_ai_revive` and `medkit.scr::dbno_selfrevive`.
4. **Reverse namespace.** The MP host-pref, mode and mirror families never appear in coop-only files: `coop_mod` minus MP_GLOB, `maps/`, `global/` except the one gated ambient hook, `ui/coop_start*`, `ui/loadout/**`, `autoexec.cfg`, `coop_defaults.cfg`, `coop_mod/start_server.cfg`, non-MP `coop_mod/cfg`.
5. **Mirror writer (clause 11).**
   - `g_mpOff` is written by `set`/`seta`/`sets`/`setu`/`setcvar` only in `coop_mod/mp.scr`, after its refusal guard (`coop_mod/mp.scr:46`) and before its first wait.
   - Engine scope: the literal appears in exactly one `Cvar_Get` registration and one `gi.cvar_set` in `Level::Init`.
   - cgame reads it only via `Info_ValueForKey`.
   - No C++ `Cvar_Get` of host prefs outside the shared `G_CoopLoaded` predicate helper.
6. **Coop start never touches MP.** `ui/coop_start.urc`, `coop_mod/start_server.cfg` and `coop_mod/cfg/*` never write MP families. The MP start path never execs `start_server.cfg` or pushes `coop_start`. The coop plaque rect and command in `ui/multiplayerstart.urc` stay byte-identical to HEAD, a clause 6-style diff.
7. **Map lists.** No map offered by an MP mode list has a script calling `coop_mod/main.scr::main`. Every offered map reaches `ambient.scr` or has an MP override. Derived by scan.
8. **Credit writers.** Mode credit (freeze, thaw, tier, capture) calls only the MP progression API, never `chal_*` or `xp_*` (extends progression clause 17).
9. **Bots.** Bot cvars (`sv_maxbots`, `sv_numbots`, `sv_minPlayers`, `sv_sharedbots`, `bot_manualmove`) may be set only by MP start UI and cfg files, always all four and always with `set`, never `seta`. `seta` archives them at runtime (`fgame/gamecvars.cpp:675-678`) [P].
   - The proposed blanket clause 24 (`_research/mp_progression_understanding.md:1193`) would forbid the requested bot control. Replace it with this shape [C].
   - A coop-side zeroing requirement is a separate clause, pending user approval (see 8a).
10. **Engine rule cvars.** MP_GLOB may write `g_healrate`, `sv_team_spawn_interval`, `sv_invulnerabletime`, `roundlimit`, `g_realismmode`, `sv_sprinton`, `fraglimit`, `timelimit` and `dmflags` only through the approved baseline cfg or command.
    - Assert that coop start cfgs keep writing `sv_team_spawn_interval 0` (`coop_mod/start_server.cfg:33`; `coop_mod/server.cfg:32`). Coop depends on 0: above 0, gt2 deaths are forced to spectator and wait for the wave (`fgame/player.cpp:3486-3491`, `:18375-18428`; `fgame/dm_manager.cpp:1768-1779`) [NV].
    - Forbid `dmflags` values containing bit 0 (DF_NO_HEALTH) in MP files.
11. **Scoreboard.** No retail `*_scoreboard.urc` name (`dm_scoreboard.urc` etc.) exists in `mod/`. Any cgame scoreboard branch keys on a per-map-cleared serverinfo value coop never sets, and the gt2 default still resolves to `DM_Scoreboard` when that key is empty (`cgame/cg_scoreboard.cpp:57-75`).
12. **Menu audit.** Add `multiplayerstart` and `mp_hostrules` to `docs/tools/audit_menu_cvars.py` MENU_HINTS, so "a setting is a promise" is actually checked on these screens.
13. **Order.** The checker runs at `build.ps1:366`. It must gate every new mode script, cfg and urc from its first commit.

---

## 8. Open questions

### (a) User decisions

1. **Supersede DECISIONS.md:630-660** with per-feature toggles and DBNO host-selectable in MP. Keep "OFF means classic"? Cheapest: ask, then replace the record.
2. **Mode list for v1.** Which of CTF, S&D/Cyber Attack, Infection, KOTH, Kill Confirmed, OITC and Team LMS are in scope beyond the four named modes?
3. **Rifles scope.** Rifles only, Rifles+Snipers, Snipers only (all three presets?). Do pistols and grenades stay? A modifier row on every screen, or its own plaque?
4. **Gun Game.**
   - Final tier (no stock knife: bash-only, pistol, rifle?).
   - Melee demotion on or off.
   - FFA only, or also a team variant.
   - Progression credit: full, weighted, capped, or challenges only.
   - Do bot kills advance tiers? Can bots win?
5. **Freeze Tag.** FT-A (UBER gt2, script round score) vs FT-B (gt3, native round wins, needs `g_allowjointime 0`). Respawn at body or at a spawn point. Bot thaw policy: proximity, or auto-thaw timeout.
6. **BaseBuilder.** Roles (both teams build vs builders vs zombies), a prep phase, zombie kit, and whether zombie kills count.
7. **Healing/Medkits meaning.** The coop medkit system, stock health pickups and death healthboxes, heal rate, or all three.
8. **ADS off behaviour.** What RMB does, and whether scoped rifles keep zoom and the spread bonus.
9. **Extra toggles.** Sprint, limp, tinnitus/wound audio, one-mag pickups, damage falloff, realism: each its own toggle, always on, or one "classic" master?
10. **Defaults** per toggle. Grey out DBNO and medkits for gt3-6 and FFA until the port lands?
11. **Toggle timing.** Latched per map (recommended) or live mid-match?
12. **Naming family.** `g_mp*` (research recommendation, stufftext-safe), `hzmp_*`, or `coop_mp*`.
13. **Host settings.** Remembered last-used (archived) or always defaults per visit.
14. **Size fix.** Keep global stretch (`ui_menuCenter 0`) and shrink the rects, or give this screen its own uniform scale? The per-widget `scalecvar` path is unproven (`uilib/uiwidget.cpp:2551-2563`).
15. **Stock options screens.** Ship mod copies of all six retail options screens (so they get the Host Rules button and lose the dead controls), or leave them retail?
16. **Callvote.** Ship a root `callvote.cfg` with mode and toggle votes, and should coop servers see those entries?
17. **Coop-side reset points.** These are coop file changes; approval is required.
    - Zero all four bot cvars in `coop_mod/start_server.cfg`, plus a `setcvar sv_numbots 0` / `sv_minPlayers 0` guard early in `coop_mod/main.scr::main`.
    - Restore `g_realismmode 0` (uncomment `start_server.cfg:11`).
    - Enforce `fraglimit`, `timelimit` and `roundlimit` at 0 at coop load.
18. **Scoreboard columns.** Relabelled (Tier / Round Wins / Frozen: cgame + new urc + isolation clause), or stock numbers plus announcements?
19. **Compact screenshot.** Confirm it is the multiplayer-room hover art, not a separate older menu.
20. **Separately reported coop defects.** Whether to fix them later, out of this scope: see the end of this section.

### (b) Playtests (cheapest form)

1. **K1: `event_subscribe player_killed` with an unquoted `file::label`.** Throwaway label on a listen TDM with one bot, `iprintlnbold` the attacker's netname. Gun Game and all credit depend on it.
2. **gt4 refusal and gamemap bypass.** Dedicated `+set g_gametype 4 +map dm/mohdm1`; grep `server_home\maintt\qconsole.log` for "Can't load regular dm map in objective game type". Then rcon `set g_gametype 4; gamemap dm/mohdm1` and `serverinfo`.
3. **gt3 script thaw.** dm/mohdm1 at gt3 with 2 bots. Kill one player, wait 35 s, script `respawn`. Check for spectator. Repeat with `g_allowjointime 0`.
4. **gt6 on a dm map.** `set g_gametype 6; map dm/mohdm1`, script `teamwin`. Round restart, bot rejoin, and how the Lib scoreboard and compass look.
5. **Bot leak into coop.** Dedicated dm map with `+set sv_maxbots 4 +set sv_numbots 2`, then `rcon map m1l1`, `rcon status` (bots show ping "bot").
6. **Engine rule leak.** Host coop from the menu, disconnect, host FFA from the stock menu. In console: `g_healrate`, `sv_team_spawn_interval`, `sv_invulnerabletime`, `roundlimit`. Expected 100000, 0, 2, 0. The archived pair is already in `G:\mohaa-gl2\home\maintt\configs\omconfig.cfg:795`, `:800`.
7. **Coop with `sv_team_spawn_interval 15`.** Host coop, set it in console, die once, look for forced spectator and "Next respawn in N seconds". Restore 0.
8. **Dead retail controls.** Stock Team screen, untick Health Drop, start, read `g_healthdrop`, which should be unchanged. Also confirm dying still drops a healthbox.
9. **Dedicated cfg gametype.** Two-line cfg `set g_gametype 4; map obj/obj_team1`, then check `g_gametype` and the banner.
10. **Round restart wipe.** gt3 dedicated with 2 bots. Count mp.scr `^~^~^ MP` deploy lines per round. Also the `g_mpOff` value across a restart.
11. **freezecontrols and firing.** Does PMF_FROZEN block weapon fire? One listen test, or read `fgame/player.cpp` ~`:5290-5350`.
12. **`notarget` under cheats 0.** `$player[1] notarget 1` on a cheats-0 dedicated server; do bots still target?
13. **Bots holding script kits.** `sv_maxbots 2`, add bots, apply `takeall` + `item` on the spawn edge, watch the held weapon for a life.
14. **Prone and cover gate prediction.** MP boot with the gate forced off: crouch-hold and wall dwell with `coop_proneDebug 1`, watching for a view dip or 3P flicker.
15. **Name-bus tokens reaching mp.scr** before `mp_cleanName` (`coop_mod/mp.scr:131-133`). Press the medkit key with a temporary print.
16. **BaseBuilder headroom.** Spawn 100 catalog models on dm/mohdm1, log `SV_FindIndex` warnings.
17. **Stretch vs rect shrink.** Screenshot pass of the new board at 3440x1440. The coop flow gets its screenshot pass before anything else ships.

### (c) More research

1. **What the live "[Gun-Game AA/SH/BT] + Bots" and "[Rifle Server] + Bots | openmohaa.org" servers run.** Connect and read serverinfo / `sv_referencedPakNames`, or ask the OpenMOHAA community. It is not in the openmoh GitHub org (https://api.github.com/orgs/openmoh/repos).
2. **Mefy's Extended-Gametypes rules, cvars and base gametype.** Search text suggests Round-Based. Download the pk3 from moh-db (needs the user's OK for the download) and read its `.scr` files.
3. **UBER BaseBuilder's real base gametype.** Read UBER's `bb` dispatcher script (`cvars/ubergametype.scr` and callers) via `gh api`.
4. **Does `Level::SetMap` run on every restart path, and is there a 0-flash of the mirror?** Grep `SetMap(` in `fgame/level.cpp` and `fgame/g_main.cpp`.
5. **Can `$health remove` catch every pickup** (map targetname vs Health default, `fgame/health.cpp:63-67`)? And does `level.nodrophealth` affect the player death drop? Read `SpawnArgs` order and `fgame/sentient.cpp:4806-4808` vs `fgame/player.cpp:3669-3685`.
6. **Map-placed weapon and health pickup counts** on stock dm/obj BSPs. Extend the scratchpad `mapents.py`.
7. **Weapon clip commands on MP pistols for OITC.** Read the `fgame/weapon.cpp` handlers behind `:118-155`.
8. **Is there an FFA end-match primitive?** Grep `fgame/scriptthread.cpp` and `fgame/level.cpp` for intermission/endmatch.
9. **Single Button with `hovershader`: does the glow overlay or replace the art?** Read `uilib/uibutton.cpp`.
10. **Current CS_SERVERINFO size** on the fullest objective map. `serverinfo` on the dedicated harness.
11. **Free and usable HUD slots** once MP DBNO, cover and XP decisions are known. `python docs/tools/hudslots.py 100 255`.
12. **Does `xp_identify` misbehave for a bot with no `cl_guid`?** Read `coop_mod/xp.scr` `xp_identify` (`:331-387`).
13. **Hardpoint exact rules.** Retry the callofduty.com guide.
14. **Popularity beyond one snapshot.** mohaaaa.co.uk and gametracker through a browser session. Most MOHAA community sites block automated fetches.
15. **Does a gt4 server on an obj map behave sanely with a scripted S&D?** Existing obj scripts run bomb and teamwin logic only when gametype == 4 (scratchpad `maps__obj__mp_palermo_obj.scr:21`, `:64-99`).
16. **Does AI on stock MP maps use the recast navmesh** (loaded only when `sv_maxbots > 0`, `fgame/navigation_recast_load.cpp:729-732`)? This decides AI-based Infection. Grep actor pathing for the Recast API.

### Side findings to report to the user (coop defects, out of this scope)

- **coop_start field stomp.** `ui/coop_start.urc` Server Name, Max Players and Friendly Fire (`:34`, `:87`, `:113`) are overwritten at launch by `ui_startdmmap` from `ui_hostname`, `ui_maxclients` and `ui_teamdamage` (`client/cl_ui.cpp:3451-3466`) [NV]. `ui_maxclients` is forced to 4 by `coop_mod/cfg/lobbytest.cfg:17-18`.
- **Reverse leak from the MP menu.** The MP Team Damage checkbox sets coop friendly fire on the next coop start (`coop_mod/start_server.cfg:14` leaves `g_teamdamage` commented out) [NV].
- **Realism reset commented out.** `g_realismmode` reset is commented out in `coop_mod/start_server.cfg:11`, so a latched 1 from an MP host carries into coop [P].
- **Polluted archived values.** `sv_team_spawn_interval 0` and `sv_invulnerabletime 2` are archived into the live profile (`omconfig.cfg:795`, `:800`) and the dedicated harness (`server_home\maintt\configs\omconfig.cfg:112-113`). MP proofs expecting 15 will fail there.
- **Wrong cfg comment.** `coop_mod/cfg/dedicated_example.cfg:11-14` contradicts the code about setting `g_gametype` from a cfg.
- **Wrong script comment.** `coop_mod/mp.scr:63-64` says `game.*` persists across maps; `fgame/level.cpp:950` clears game vars.
- **Stale generated row.** `docs/generated/CVARS_COOP.md:418` cites `fgame/player.cpp:17400` for `coop_coverAuto`; the live site is `:17441`. Fix via docgen, not by hand.
- **Dead code.** `coop_mod/server.scr::fixServer` has no caller.

---

## 9. Candidate framework architectures (no pick)

### A. Thin script dispatcher (script-first, minimal engine)

**Shape.**
- `coop_mod/mp.scr::main` stays the only entry point.
  - Resolves the mode cvar against a whitelist (unknown = none).
  - Applies and restores a rules snapshot (dmflags, frag/time/round limits the mode owns, `g_healrate`, `sv_team_spawn_interval`).
  - Re-sets `g_gametypestring`.
  - Owns the single `player_killed` subscription and the spawn edge.
  - Computes and writes the toggle mask once.
- Per-mode logic lives in `coop_mod/mp_mode_<id>.scr` behind a fixed label contract: `init`, `armoryPolicy`, `creditPolicy`, `toggleOverrides`, `onSpawn`, `onKill`, `onRoundStart`.
- Mode overrides beat host toggles, and the UI greys out overridden toggles.
- Engine work is limited to the toggle gates:
  - `G_CoopLoaded` predicate;
  - `g_mpOff` registration and Level::Init reset;
  - prone, cover and ADS gates in game.dll;
  - ADS and 3P gates in cgame;
  - one `pmove_t` field.
- Modes live with the engine as-is: gt2 script rounds (UBER Freeze Tag), gt3 elimination, gt4 only on obj maps, gt1 fraglimit end.

**Pros.**
- Copies proven MOHAA recipes (UBER) per the fix methodology.
- The smallest game.dll/cgame.dll change set, and the least protocol risk.
- One entry point keeps the coop refusal in one place. The rejected alternative, hooking modes from ambient or map scripts, spreads it; clause 3 checks only the first `mp.scr` occurrence (`docs/tools/check_mp_isolation.py:172-177`).
- Everything fits the isolation checker's script-scanning model with MP_GLOB.

**Cons.**
- Engine gaps stay open. No per-player respawn lock (OITC lives, FFA LMS). No counts-as-dead flag, so a DBNO-downed team never loses by elimination. No script-owned team score, so CTF, KOTH and Kill Confirmed cancel each kill by hand and race the engine. No end-match command, so fraglimit is pushed, which risks the coop leak.
- Round-state survival needs cvars.
- Script errors silently end mode threads.
- Scoreboard labels stay retail.

### B. Engine-assisted mode layer (A plus a coop-gated hook set)

**Shape.** Same dispatcher and per-mode scripts as A. Add small game.dll and cgame hooks, each gated by `G_CoopLoaded` like `CoopMpPlayerHit` (`fgame/sentient.cpp:1612-1669`):
- a per-player no-respawn flag (`fgame/player.cpp:6196-6208` and deploy paths);
- a "counts as dead" flag read by `DM_Team::IsDead` and `IsAlivePlayer` (`fgame/dm_manager.cpp:552-562`, `:2014-2017`), for Freeze Tag and DBNO;
- a "script owns team score" flag that skips `m_teamwins += kills` (`fgame/dm_manager.cpp:273`);
- a script end-match command wrapping `G_BeginIntermission2` (`fgame/dm_manager.cpp:1225`, `:1246`, `:1252`), optionally allowing `teamwin` on gt2-3 in MP sessions;
- an MP-rule death-healthbox gate (`fgame/player.cpp:3669-3685`);
- a mode key in serverinfo, cleared per map, selecting mode scoreboard urcs in `CG_PrepScoreBoardInfo` (`cgame/cg_scoreboard.cpp:57-115`), with `DM_Scoreboard` staying the default.

**Pros.**
- Unblocks Freeze Tag elimination natively, DBNO in round modes, CTF/KOTH/KC scoring without per-kill cancels, OITC lives, and a leak-free Gun Game match end (no fraglimit write).
- A leak-free "Healing off" (no DF_NO_HEALTH).
- Mode-specific scoreboard columns.
- Engine behaviour is deterministic, not a script race.

**Cons.**
- Every hook edits engine functions coop also runs. Each needs the predicate done correctly; one wrong copy flips the feature in coop.
- Requires rebuilding and shipping matched game.dll and cgame.dll. A mismatched pair is the protocol-constant trap class, worst if the `scores` wire layout changes.
- More code to verify, and the isolation checker needs a new engine-scope scan.
- Diverges further from upstream OpenMOHAA, which complicates later merges of `g_bot.cpp` etc.

### C. Vendored per-mode packs on the UBER model (isolated, recipe-faithful)

**Shape.**
- Each mode is a near-verbatim port of an existing community implementation (UBER ft/snd/cyb/bb, later Mefy if obtainable), adapted into an MP-only directory.
- Selected by one MP-only mode cvar that the pack reads after mp.scr's refusal guard (the UBER `g_ubergametype` pattern).
- Each pack owns its own round loop, HUD slots, map scripts or per-map data, and admin commands.
- Host toggles and armory/progression integration are thin adapters at pack boundaries: a kit-override hook, a credit-emit hook, and a toggle read.
- Engine hooks are optional, as in A.

**Pros.**
- The fastest way to real, community-tested rules: melt timing, bombsites, BaseBuilder placement and budget.
- Modes are self-contained, so one can be removed without touching others.
- Matches how MOHAA-era servers actually ran modes: script pk3s over stock gametypes, never DLL mods.

**Cons.**
- UBER was written without this mod's constraints:
  - It uses archived `seta` selection.
  - It assumes Reborn for some BaseBuilder features.
  - It has no knowledge of the MP armory, MP progression, bots, the isolation contract or `coop_*` statefile interactions.
  - Its round scoring is script arrays plus prints only (`global/cyberattack_searchdestroy.scr:1679-1742`).
- Adapters may end up rewriting large parts anyway.
- Several packs duplicate primitives (HUD, round loop, credit) and drift apart.
- HUD slot collisions have to be audited per pack (UBER Freeze Tag uses huddraw 207).
- Provenance: the local scratchpad copies lack a fetched upstream URL. Re-fetch from https://github.com/searingwolfe/UBER-MODS-v8.00-MOHAA before copying.
- Mefy's source is currently unobtainable (403).
