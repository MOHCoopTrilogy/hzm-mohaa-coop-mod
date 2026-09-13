> Research-only web pass, 2026-09-13 (community-modes-deepdive workflow, 9 agents). Written BEFORE the Ubermod V2 pack was downloaded and before the Kings Push hunt finished: where this file and ubermod_v2_source_notes.md or kings_push_hunt.md disagree, those two are the stronger evidence (read from the real files / archived pages).

# Community MP game modes for HZM: Push ("Kings Push"), Ubermod V2, UBER Mods, Mefy and others

Synthesis of four research passes: Ubermod V2, UBER Mods source, the wider mod survey, and Reborn portability. Where a verifier refuted or partly refuted a claim, the corrected version is used. **[UNVERIFIED]** marks a load-bearing fact that rests only on search-engine snippets.

---

## 1. Bottom line

### Is Push Mod the user's "Kings Push"?

**Probably yes. Confidence is medium-low.**

Evidence for it:
- A search snippet ties the OwN-3m-All Push Mod to a server file named **`zZzZzZz_kingofmap_push.pk3`**. "King of Map Push" is the only "King" link found to any push mode. The snippet came from searching `"kingofmap" mohaa`, and the snippet's source is https://own3mall.com/modules.php?cid=3&name=Downloads&orderby=dateD. **[UNVERIFIED]**: own3mall.com never loaded ("socket hang up").
- Searches for "Kings Push", "King's Push" and "KingsPush" found no MOHAA mod under that name. Two sites the search engines barely index (mohaaaa.co.uk and x-null.net) sit behind an Anubis bot wall, so "not found" is weak evidence.
- A snippet lists own3mall's download as "Fight / Push Your Way to Victory Mod", with 1,014 downloads. That makes it a reasonably popular server mod, one a player could plausibly remember (same own3mall.com listing).

Evidence against it, or other explanations:
- MOHAA **King of the Hill** content exists:
  - a mohaaaa.co.uk page titled "King of the Hill - SH" (http://www.mohaaaa.co.uk/AAAAMOHAA/content/king-hill-sh, blocked)
  - a thread on mffclan.org (https://mffclan.org/index.php?topic=20031.0, unreachable)
  - a KOTH-themed map, Outpost1369 (https://www.x-null.net/forums/threads/3835-Outpost1369)

  "Kings Push" could be a memory that blends KOTH with Push.
- A **Gain Ground Mod** also exists (`zzzzz-Gain_Ground_mod.pk3`, 51 downloads; http://www.mohaaaa.co.uk/AAAAMOHAA/content/gain-ground-mod), and so does a "Push / Gain Ground Mod 2.0" page (http://www.mohaaaa.co.uk/AAAAMOHAA/content/push-gain-ground-mod-20). Their authors, and whether they are separate from own3mall's Push, are unknown.
- The claim that the file installs together with `push.cfg` could not be reproduced by the verifier. The archive name `own3mall_push_mod.zip` also turned up no match in an exact-string search.

**The cheapest way to settle it:** ask the user whether "King of the Map", or a server or clan called "kingofmap", sounds familiar. Or ask them to open the own3mall.com MOHAA Mods downloads page in a normal browser.

**Ruled out:** searingwolfe's UBER Mods contains no Push, KOTH or checkpoint mode. Code search found "push" only in an admin `pushmenu` player list and a pushable cabinet prop on mohdm6, and "king" only in King Tiger tank assets (https://github.com/searingwolfe/UBER-MODS-v8.00-MOHAA).

### Most promising modes to add, in suggested order

1. **Push.** The user asked for it, and no other mod in the catalogue does what it does. It needs no Reborn features. The work is mostly per-map checkpoint data. HZM's `coop_mod/holdout.scr` already has checkpoints, respawns that follow the squad, and in-game F5-F8 placement. That is the recipe to *copy*; it is a co-op-side mode, so it should not be called from MP. One decision is needed first: Push relocates spawns, and DECISIONS.md lists spawn warping as never used in standard MP (see §7).
2. **Search & Destroy / Cyber Attack.** The mechanics are the best documented of anything found, because we read the full source on GitHub. The mode logic uses nothing Reborn-specific. It needs bombsite coordinates for each map.
3. **Freeze Tag.** The classic community mode (Mefy's, and UBER's replica). It is round-based and uses only commands HZM has. It overlaps conceptually with HZM's DBNO revive, which raises an isolation question.
4. **Rabbit** and **Last Man Standing / Survivor.** Simple rules and little per-map data.
5. **Weapon-class-only modes** and **Gun Game.** Close to trivial on top of `mp.scr`'s loadout path.
6. **CTF.** Well understood, but needs flag bases on every map, and the exact Mefy rules conflict between sources.
7. **Base Builder.** Popular, but has the most code and the highest entity-budget risk.

---

## 2. Mode catalogue

Difficulty is our own estimate for a script-level rebuild on the HZM OpenMOHAA fork, on the MP side of the MP/co-op isolation contract.

| Mode | Source mod(s) | Rules (short) | Team/FFA | Mechanics needed | Reborn dependence | HZM rebuild difficulty | Source |
|---|---|---|---|---|---|---|---|
| **Push** (Gain Ground; probable "Kings Push") | OwN-3m-All Push Mod, standalone and bundled in Ubermod V2 | A team's spawn moves forward when one of its players reaches the next unmarked checkpoint. Push all the way across to score. Score zones are sparks for Allies and smoke for Axis [snippet] | Team (TDM only) | Ordered per-map checkpoints, per-team spawn index, spawn relocation, end-zone scoring, round reset, FX | Ubermod needs Reborn 1.12. The core mechanic needs nothing Reborn-only | **Medium.** Code is modest; per-map checkpoint authoring is the cost | https://own3mall.com/modules.php?cid=3&name=Downloads&orderby=dateD |
| Push / Gain Ground 2.0; Gain Ground | mohaaaa.co.uk listings, author unknown | Unverified; the title suggests the same idea | Team? | Same as Push | Unknown | Same as Push | http://www.mohaaaa.co.uk/AAAAMOHAA/content/push-gain-ground-mod-20 |
| **Freeze Tag** (ft) | Mefy Extended-Gametypes 1.2.2; UBER Mods `ft` (near replica); RaMsOc2 repacks | A killed player freezes. Teammates thaw them by proximity. Freeze the whole enemy team to win the round | Team, rounds | Frozen body with marker, thaw zone and timer, alive counts, round manager, spectate | None in the mode logic | **Medium** | https://github.com/searingwolfe/UBER-MODS-v8.00-MOHAA/blob/main/global/cyberattack_searchdestroy.scr ; https://mefy.moh-central.net/ |
| FT-Objective / FT-CTF / FT-TOW / FT-Demolition | Mefy 1.2.2 | Freeze Tag respawning layered on OBJ, CTF, TOW (SH/BT TOW maps) or Demolition. FT-CTF uses freeze respawning only while both flags are home [snippet] | Team | FT plus the base mode | Unknown (Mefy is server-side) | **Medium-High** | https://mefy.moh-central.net/ |
| **Cyber Attack** (cyb) | UBER Mods; standalone Cyber Attack/S&D v11.00 | One central bomb that either team plants at the enemy site. Dead players freeze and can be revived with USE. Wipe or detonate to win the round; first to 5 | Team, rounds | FT mechanics plus bomb pickup, carry, plant, defuse, bombsite props, fuse, explosion, side swap | None in the mode logic | **Medium-High** | https://github.com/searingwolfe/UBER-MODS-v8.00-MOHAA/blob/main/global/cyberattack_searchdestroy.scr |
| **Search & Destroy** (snd) | UBER Mods; DoubleKill "Bomb - ConterStrike" (lighter) | Attackers plant at one of two or more sites; defenders defuse. No revives. Roles swap every 3 rounds; first to 5 | Team, rounds | Round manager, team spectate, bomb, role locks, defuse wins | None in the mode logic; bomb_cs says it is Reborn-compatible | **Medium** | same UBER file ; https://www.moh-db.com/mods/42957-bomb-conterstrike |
| **Base Builder** (bb) | AlienX original; searingwolfe Uber Basebuilder / UBER `bb` | Timed build phase with no weapons, pickup stations and a build laser, under an object limit. Then combat | Team or FFA | Carried ghost objects, placement trace, input polling, owner tracking, entity budget, phase timer, cvar juggling | Reborn extras: secfireheld trimming, name-based admin removal, ihuddraw HUD. Also uses `isadmin` | **High** | https://github.com/searingwolfe/UBER-MODS-v8.00-MOHAA/blob/main/alienx/basebuild.scr |
| Build-A-Base | "Build=A=Base 1.0", author not retrieved | Same concept as Base Builder, free rewrite | Team | As Base Builder | Unknown | **High** | https://mohaaaa.co.uk/AAAAMOHAA/content/buildabase-10 |
| **Rabbit** | OwN-3m-All Rabbit Mod AA (v4.0 in 2012, v6.1.1 on 2016-09-01); in Ubermod | One marked Rabbit scores extra per kill plus a survival bonus over time. Killing the Rabbit makes you the Rabbit [snippet] | FFA and TDM | Marker/radar, role transfer on kill, timed scoring, HUD | Ubermod needs Reborn; standalone requirements unknown | **Low-Medium** | https://www.x-null.net/forums/threads/1466-Rabbit-Mod-AA-Release-Version-6-1-1 |
| **CTF** | Mefy 1.2.2; in Ubermod | Take the enemy flag to your base. One snippet: hold it there 15 s, first to 4. Another summary gives classic "return while your flag is home" (conflict) | Team | Flags, carry/drop/return, base zones, per-map bases (g_ctf_settings) | Unknown | **Medium** | https://mefy.moh-central.net/ |
| Demolition (dem, formerly Voodoo Dolls) | Mefy (renamed in v1.1.2) | Bomb-objective team mode. `g_dem_respawn 0` removes respawns | Team | Plant/defuse targets, respawn setting, rounds | Unknown | **Medium** | http://www.mohaaaa.co.uk/AAAAMOHAA/content/mefys-gametype-addon-tutorial |
| Countdown / Hold The Radio (HTR) | Bundled in UBER (HTR/); possibly COUNTDOWN-LIGHT; Ubermod's "Countdown" link unconfirmed | Holding the radio runs your team's 3:00 clock down; the carrier glows. First clock to zero wins | Team, rounds | Pickup carried on the player, per-team clocks, location announcements, idle respawn | None noted; uses Admin-Pro settings and libmef | **Medium** | https://github.com/searingwolfe/UBER-MODS-v8.00-MOHAA/tree/main/HTR |
| Last Man Standing / Survivor | OwN-3m-All LMS + Team Balance HUD; UBER Survivor/ | Limited lives per round (Survivor default 3). Out of lives means spectator. Last team or player alive wins | Team and FFA | Life counter, alive HUD, round reset | LMS pk3 unknown; Survivor ends the map with bsptransition (banned in HZM) | **Low-Medium** | https://www.moh-db.com/mods/18029-last-man-standing-team-balance-hud ; https://github.com/searingwolfe/UBER-MODS-v8.00-MOHAA/tree/main/Survivor |
| Liberation | Stock Breakthrough mode; Ubermod's AA-side author unknown | Dead players go unarmed to a jail in the enemy camp. A switch frees them. Jail everyone to win [snippet] | Team | Jails and switches per map | Native to BT | **Unclear**, see §3 | https://medalofhonor.fandom.com/wiki/Liberation_(Multiplayer_gamemode) |
| Base Assault | Port of the CoD:UO mode, author unconfirmed | Destroy the enemy base using vehicles, emplacements, classes and bought strikes | Team | Destructible bases, vehicles, economy, classes, airstrikes | Server-side; details unknown | **Very High** | https://www.moddb.com/mods/base-assault |
| Weapon-class-only | Weapon Manager v20 (30 modes); Snipers + Rifles Only (searingwolfe) | Everyone limited to one weapon class | Any | Spawn loadout override plus pickup filter | Server-side | **Low** | https://www.moh-db.com/mods/17803-weapon-manager-v20 |
| Gun Game | Unfinished x-null thread; a Spearhead server reportedly ran one | Next weapon per kill, back one step when bashed, win with the last weapon | FFA | Weapon ladder, kill/bash hooks | Unknown | **Low-Medium** | https://www.x-null.net/forums/threads/2526-COD-Mods-for-MoH-AA-Gun-Game |
| Survival Horror (juggernaut / hide-and-seek style) | inequation/MoHAAMods `horror` | One invisible, instant-kill player hunts the others | FFA | Invisibility, damage override, role pick | Not examined | **Medium** | https://github.com/inequation/MoHAAMods |
| Nazi Zombies | mohaaaa.co.uk page; YouTube video | Not retrieved | ? | Unknown | Unknown | Unknown | http://www.mohaaaa.co.uk/AAAAMOHAA/content/nazi-zombies |
| Snowball Fight | \|DOS\| 1.3, on jv_map's Snow Contest | Holiday mode with snowballs | Any | Custom projectile; client content | Client pk3s | **Medium** (distribution cost) | https://www.moddb.com/mods/snowball |
| Beach Soccer | Ubermod V2 | Undocumented | Team? | Physics ball, goals | Unknown | Unknown | https://www.moh-db.com/mods/11686-own-3m-all-s-ubermod-v2 |
| DM-to-OBJ / SP-to-MP conversions | Ubermod V2 | Undocumented; SP-to-MP overlaps what HZM already does | n/a | Per-map scripting | Unknown | n/a | same moh-db page |
| Mixing Gametypes | Crow King | Maplist mixes DM and OBJ per map | n/a | Rotation logic | Unknown | **Low** | https://www.moh-db.com/mods/17855-mixing-gametypes |

Not found anywhere: Rocket/Clan Arena, headhunters, domination, VIP/escort, and a KOTH *gametype* script (only a KOTH map and a KOTH page of unknown type).

---

## 3. Detailed mechanics

### 3.1 Push (OwN-3m-All)

**What is known** (all from snippets of https://own3mall.com/modules.php?cid=3&name=Downloads&orderby=dateD; the page never loaded):
- TDM only. Both teams start at their own end of the map and fight across it.
- There is a chain of checkpoints between the two ends. Checkpoints are **not marked**.
- As soon as **any one** player of a team reaches that team's next checkpoint, the team's spawn moves up to it.
- A team scores by pushing all the way across. The score zones **are** marked: Allies head for sparks, Axis head for smoke. The exact source of the sparks/smoke detail is uncertain.
- Install (snippet): `zZzZzZz_kingofmap_push.pk3`, probably with `push.cfg`, into the server's main folder. **[UNVERIFIED]**

**Unknown, and needed before a faithful design:**
- How many checkpoints there are per map.
- Whether a team's spawn can be *pushed back* when the enemy advances, or whether the two teams advance independently.
- What happens on a score: round reset, points to a limit, or map end.
- How checkpoints are defined: per-map script, cfg or cvar.
- Which maps are supported.

**Buildable design (our rules, drawn from the above):**
1. **Per-map data.** An ordered list `cp[0..N]` of volumes, each an origin plus a radius or box. `cp[0]` is the Allied home and `cp[N]` the Axis home. Each checkpoint carries a set of spawn origins for each team.
2. **State.** Allies hold `front_allies`, which starts at 0 and rises toward N. Axis hold `front_axis`, which starts at N and falls toward 0.
3. **Advance.** Poll players at about 10 Hz (or use trigger volumes). When a living Allied player enters `cp[front_allies+1]`, increase `front_allies` and announce it; the same in reverse for Axis. If the "push back" rule applies, clamp the fronts so the teams never cross (`front_allies < front_axis`), or make a checkpoint contested. Decide this in §7.
4. **Spawn relocation.** On each player spawn, warp them to a spawn origin of their team's current front. Both `registerev spawn` and `event_subscribe player_spawned` fire in this engine (fires at player.cpp:18604). Alternatively, move or enable `info_player_allied/axis` groups.
5. **Score.** An Allied player entering the Axis end zone (sparks FX) scores, and likewise for Axis in the smoke zone. Then reset both fronts, respawn everyone, and count toward a limit, ending with `teamwin`.
6. **HUD.** Per-team front progress through global `huddraw_*`.
7. **Recipe to copy:** `coop_mod/holdout.scr`, which has checkpoints, respawns that follow the squad, and F5-F8 in-game authoring for placing checkpoints on MP maps. It is co-op-side and set up through `coop_mod/cfg/holdout.cfg` with `coop_holdout*` cvars, so **copy the recipe into an MP-side script; do not call it**. Source: holdout.scr header, verified.

### 3.2 Freeze Tag (UBER `ft`, modelled on Mefy)

All of this is from the source at https://github.com/searingwolfe/UBER-MODS-v8.00-MOHAA/blob/main/global/cyberattack_searchdestroy.scr unless noted.

- **Round framework** (shared by ft, cyb and snd):
  - Pre-round countdown of 8 s by default; deaths respawn normally during it.
  - After that, a 1 Hz scan builds per-team alive and total counts, keyed by entity number. A player found dead is "frozen". Freezing comes from this poll, not a death event.
  - A per-frame judge checks for a team wipe.
  - On a win: about 3 s of spectating, then everyone respawns for the next round.
  - First to `rounds_towin` (default 5) wins; the map ends via a victory podium or `timelimit 1`.
  - ft never swaps sides.
- **Frozen representation:**
  - (a) *Fake spectator camera.* The real player respawns, is stripped of weapons, hidden, made non-solid and put in noclip. Every frame they are teleported behind a target's view, with `physics_off` and `face`. FIRE steps to the next target and USE to the previous one. Targets are living teammates or teammates' frozen bodies, and enemies once the round is won. This also runs in snd.
  - (b) *Body* (cyb and ft only). A `script_model` copy of the player model dropped to the floor, three vertical `func_beam` pillars (blue for Allies, red for Axis, purple while an enemy touches the body), and a 70×70×110 `trigger_use` box.
- **Melting (thawing)** in ft:
  - Standing in the box is enough; no USE needed.
  - Alternatively, holding USE for at least 10 frames fires a long-range melt laser, traced up to 10240 units from the head tag. It is invisible unless `level.meltlaser` is 1.
  - Melt time `level.melttime` defaults to 3 s.
- **Melt finish (corrected):**
  - The melted player is always brought back if dead, teleported to the body, shown, made solid and given their weapon class.
  - If `meltrespawn` is 1 (the ft default), they are then respawned normally at a spawn point.
  - The "wait until nobody overlaps the body" step only runs when `meltrespawn` is not 1. With `meltrespawn` 0, a player who still overlaps someone is force-respawned.
- **Late joiners:** a player who joins mid-round while both teams have living players is killed immediately with `killent` and must be melted.
- **Mefy's version** [snippets]: freeze-tag is the default when `g_extgametype` is unset, and `g_extgametype` overrides `g_gametype`. There is a settings cvar, e.g. `g_ft_settings`. A snippet shows melt options such as a melt gun and a melt time. Mefy's exact melt timings are unverified.
- **HZM design note:** UBER's teleport-every-frame camera will jitter under ping and clashes with HZM's per-frame player loop. Prefer a real spectator follow (`setteam spectator`, player.cpp:1807) and a revive loop modelled on `coop_mod/dbno.scr`. Copy the recipe; DBNO itself must not run in MP (§4, §7).

### 3.3 Cyber Attack (UBER `cyb`, port of the MW2 2022 mode)

- Uses the §3.2 round framework and frozen bodies. **Melting requires touching the body and holding USE** for melttime; there is no laser. The melted player returns **at the body** by default (`meltrespawn` 0).
- **Bombsites:**
  - At least one per team (blue for Allies, red for Axis).
  - Built from a bunker table, radar and radio props, a lit 60-unit `trigger_use`, and an overhead team icon made from a `func_beam` shader.
  - Placed by the map script after `level waittill spawn`.
- **Bomb:**
  - One purple radio bomb at a central origin, picked up with a `trigger_use`. `attachmodel` puts it on the carrier's right thigh.
  - Nobody can pick it up before the round starts.
  - If the carrier dies it drops where they fell. If the carrier leaves or goes spectator, it returns to where it was last picked up.
- **Plant:**
  - Touch an enemy site, look at its crate (`cansee` within 90°) and hold USE for **1.5 s**.
  - The fuse is 45 s: a ticking loop, switching to a final-countdown loop for the last 10 s.
- **Defuse:** 1.5 s. It hands the bomb to the defuser; it does not win the round.
- **Detonation:**
  - A random 0.1-2.0 s delay, then an optional bomb camera (`func_camera`/`cuecamera`/`freezeplayer`/`drawhud 0`, everyone invulnerable and hidden for about 6 s).
  - Then `radiusdamage` 1000 over 600 units at two points, an earthquake, and a round point.
- **Win:** wipe the enemy or detonate their site. If a team is wiped while its bomb is still planted, the round waits for the defuse or the blast.
- **Side swap:** sites swap every 3 total rounds unless `keepsamesides` is set.
- **HUD:**
  - Global `huddraw` slots 202-211: mode title, team round scores, status line ("Bomb Planted" and similar), alive/total per team.
  - Per-player `stopwatch` progress bars and stock MP voice lines.
- **Quirk:** if `g_ubergametype` is not cyb, snd or ft when the script's `main` runs, the script picks one at random.

### 3.4 Search & Destroy (UBER `snd`)

- Same round framework, **without bodies or revives**. The dead use the fake team spectator until the round ends.
- One attacking team (Allies first by default). **Defenders cannot pick up the bomb.**
- Two or more sites made from TNT crates. Plant and defuse take **5 s in code** (the README says 4.5 s).
- The fuse is 45 s. **A defuse wins the round for the defenders at once.**
- Win by wiping the enemy, detonating a site, or defusing.
- Roles swap every 3 rounds. The bomb spawn alternates between an Allied and an Axis origin, and map scripts can move the sites when sides change.
- First to 5 wins.
- Per-map data: site origins and yaws, plus Allied and Axis bomb origins.
- A lighter alternative is DoubleKill's `bomb_cs`: maps opt in with `exec global/bomb_cs.scr`, and `cs_bomb_end_round` ends the round on defuse (https://www.moh-db.com/mods/42957-bomb-conterstrike).

### 3.5 Base Builder (AlienX / searingwolfe)

Source: https://github.com/searingwolfe/UBER-MODS-v8.00-MOHAA/blob/main/alienx/basebuild.scr

- **Parameters** passed by the map script: build time, object limit, build run speed, take weapons, fall damage, hide countdown, hide HUD, console print. The mohdm1 example is roughly 800 s and 1000 objects. The portability pass's summariser reported a "default 500 s", so treat build time as per-map and confirm against the README.
- **Build phase:**
  - `sv_runspeed` raised; `dmflags 8` (no fall damage) unless fall damage is on; `g_kblock 1`.
  - Weapons stripped every second.
  - A HUD shows seconds left and objects used. The last 70 s get a colour-cycling countdown with music (`tmstart`).
  - Admin cvars (`alx_basebuild`, `alx_timeboost/timedown`, `alx_objectlimitboost/down`, `alx_remove*`) are polled every second.
- **Pickup stations:** spinning, lit `script_model`s with a `trigger_multiple`, placed per map between prespawn and spawn. Each has model, colour, spin, scale, and lift/teleporter/solid flags. Touching one gives a non-solid ghost copy that follows the player.
- **Placement:**
  - USE shows a green build laser (a traced `func_beam`); lean rotates; hold FIRE to place.
  - The object becomes solid, and a player inside it is respawned.
  - MG42 and mini-flak88 (flamethrower) turrets are real statweapons with a bipod and count as 2 objects.
  - Lifts and teleporters come in pairs.
  - A yellow remover laser picks objects back up for their owner, or for admins via `isadmin` or an `admin_name_priority` fallback.
- **Entity budget:** `objectlimit_fix` scans `getentity 0..868` and lowers the limit to stay under 1024 entities (mohdm1 sets `maxentities 2000`).
- **End of phase:** stations removed, every non-spectator respawned, cvars restored, turrets made usable. The timelimit is only extended when the build time is at least 3600 s.

### 3.6 Rabbit (OwN-3m-All)

Rules [snippets, own3mall.com and https://www.x-null.net/forums/threads/1466-Rabbit-Mod-AA-Release-Version-6-1-1]:
- One specially marked player is the Rabbit.
- The Rabbit earns extra points per kill, plus bonus points at intervals for staying alive.
- Whoever kills the Rabbit becomes the Rabbit.
- Works in FFA and TDM.
- v6.1.1 (2016-09-01) added radar improvements, a cvar that prints the Rabbit's name, an FFA respawn-cvar fix, and crash fixes.

Design: a marker on the Rabbit (FX, glow or radar blip), a timer that adds score, a kill hook that transfers the role (`registerev kill` / `player_killed` both fire), a HUD announcement, and a pick rule when there is no Rabbit (first kill, or random).

### 3.7 Countdown / Hold The Radio (UBER HTR/)

Source: https://github.com/searingwolfe/UBER-MODS-v8.00-MOHAA/tree/main/HTR

- The radio spawns at a random per-map origin (`countdown/<map>.scr`; many of these files are placeholders). It is picked up with USE and carried on the pelvis.
- While the carrier lives, their team's clock (default 3:00) counts down. The carrier glows red and the radio's location is announced every few seconds.
- A dropped radio can be shot and knocked around. It drops where the carrier dies and respawns after 300 s untouched.
- When a team's clock reaches zero, explosions spawn on every enemy and an orbit camera shows the winner.
- The map changes after 3 rounds by default.
- This is the repo's closest thing to KOTH. It is gated by `level.run["countdown"]` from the Admin-Pro settings system; whether UBER enables it by default is unverified.

### 3.8 Last Man Standing / Survivor

- **OwN-3m-All LMS + Team Balance HUD** (https://www.moh-db.com/mods/18029-last-man-standing-team-balance-hud): announces each team's last survivor and warns when teams are unbalanced (cvars `lastManStanding`, `teamBalance`).
- **UBER Survivor:**
  - A warmup waits for at least 2 players; each player gets lives per round (settings default 3, script fallback 5).
  - At zero lives: death camera, then spectator. Late joiners wait.
  - TDM ends when a team is wiped, FFA when one player is left. A draw calls `DM_Manager doroundtransition`.
  - The map changes after N rounds using `bsptransition` with a gametype flip, which HZM's CLAUDE.md forbids. Any rebuild must use `stuffsrv "map <name>"`.
  - `coop_lmsLives` exists for co-op but must not be reused in MP (isolation contract).

### 3.9 Liberation (needs care)

- Rules [snippet, fandom page returned HTTP 402]: dead players respawn unarmed in a jail in the enemy camp. Teammates free them with a switch, usually near the enemy spawn. Maps have 2 jails and 2 switches. A team wins by jailing the whole enemy side.
- **Correction:** `bg_public.h:136-147` defines `GT_TOW = 5` and `GT_LIBERATION = 6`, but the source comments label them "Team Assault" and "Team Tactics". **Do not assume value 6 implements the Liberation rules** until the game code using it has been read. Stock BT Liberation maps would carry the jail and switch entities; other maps would need jails authored.

---

## 4. Portability: Reborn features compared with the HZM engine

Findings come from reading `openmohaa-hzm/code/fgame`; line numbers are as reported and verified.

| Reborn feature | In HZM? | Porting impact |
|---|---|---|
| `registerev` / `unregisterev` | Registered (scriptthread.cpp:1672/1681). All 9 names accepted, but **only connected, kill, damage, disconnected and spawn fire** (player.cpp:2646, 3654, 11645, 11654, 18604). **keypress, servercommand, intermission and changeteam return success and never trigger.** | Kill, spawn and connect handlers work. Hotkeys, chat commands and round-end hooks break *silently*. Use `useheld`-style polling, `player_textMessage` or our own round logic. |
| `event_subscribe` (OpenMOHAA) | Yes (1690). Delegates: player_connected, player_disconnecting, player_spawned, player_damaged, player_killed, player_textMessage. `level_exit` and `level_intermission` are **absent** in this fork. | Preferred for new code; allows several subscribers. The coop mod uses neither registerev nor event_subscribe today; a ported mode would be the first user. |
| Admin system (`isadmin`, `adminrights`, admins.ini, `ad_*`, callvote) | `isadmin` and `adminrights` are **stubs returning 0** (player.cpp:18937-18949). No admin manager. | Ubermod's admin menus lock everyone out. Base Builder's `isadmin` branches only work through its `admin_name_priority` fallback. Needs an HZM auth scheme (`coop_check` or admin.scr). |
| `getconnstate` | Hard-coded to 4 (player.cpp:19035), deprecated | UBER's zombie-client check (`== 1`) is dead code. Harmless. |
| `stufftext` | Sent by the server (player.cpp:1264), but **the client filter drops non-allow-listed commands** (cg_servercmds.c:465-482, cg_servercmds_filter.cpp) | `spectator`, `say`, `bind` and `alias` are dropped. The allow-list includes tmstart/tmstop, play, playmp3, pushmenu, echo, globalwidgetcommand, ui_addhud and similar. Cvar rule: coop_* allowed; `set` of non-existent or user-created cvars allowed; engine-owned cvars and non-whitelisted `seta`/`sets` blocked. Drops are silent unless `coop_covtrace 1`. UBER's stuffed `spectator` must become `setteam spectator`; Base Builder's `say` must become `iprint`. |
| File I/O (`fopen` family, `fwrite`, `fread`, `freadall`, `fsaveall`) | Names present (1420-1816). **`fwrite` and `fread` are empty bodies.** `fopen` uses an unsandboxed raw path relative to the process cwd (G:\mohaa-gl2), max 32 files. | Use `fs_read_content`, `fs_write_content`, `fs_open_*` (2077-2133). Correction: nothing found shows Ubermod uses script file I/O for configuration; that needs its source. |
| Per-player HUD `ihuddraw_*` (+ `_timer`, `_3d`) | Yes (1281-1367). The index guard uses `&&` and never rejects. | Scoreboards and timers port directly; validate indices ourselves. |
| Input getters: `useheld`, `fireheld`, `secfireheld`, `leanleftheld`/`leanrightheld`, `runheld` | Yes | Everything revive, plant/defuse and Base Builder need is present. |
| Player info and stats (`netname`, `getip`, `getping`, `addkills`, `adddeaths`, `getkills`, `getactiveweap`, `bindweap`) | Yes | None. |
| Misc (`getentity`, `stuffsrv`, `trace`, `angles_toforward`, `cuecamera`, `freezeplayer`, `killent`, `stopwatch`, `tele`, `face`, `physics_off`, `attachmodel`, `istouching`, `cansee`) | Yes. The used-by-core-modes check covered only three files: cyb/snd/ft, basebuild and get_player_weaponclass. | The wider UBER package (killstreaks, HUD, admin, HTR) was not checked command by command. |
| Math, date/time, `md5string`, `typeof`, `getarraykeys` | Yes; `md5file` event name not found | Not load-bearing. |
| Team and round controls | `setteam` (no respawn, 1807), `respawn` (385), `join_team` (899, flagged EV_CONSOLE; untested from script), `teamwin` (scriptthread.cpp:1078), `roundlimit` (a cvar, not a command) | Replacements for stuffed client commands. |
| Reborn server cvars (`sv_antiwh`, `sv_stufftextdetection`, `sv_kickping`, …) and `sv_reborn` | Absent (sv_reborn only in commented-out code) | Not needed by game modes. |
| `g_kblock` (Base Builder) | **Absent** from the engine | Effect unknown (possibly blocking the kill command during building). |
| Gametype enum | Stock values only, GT_SINGLE_PLAYER..GT_LIBERATION; no `g_extgametype` / freeze-tag in engine code | Modes should be script-level on g_gametype 2/3/4 with an HZM mode cvar, as Mefy and UBER do. |

**UBER mode logic is not Reborn-dependent.** The Reborn and NOT_REBORN copies of `cyberattack_searchdestroy.scr` differ only in `getconnstate` checks and `self.inventory` vs `mef_weaponclass` (verified by full diff, this file only).

**Project-side hazards that come with a port** (repo docs and verifiers):
- **MP/co-op isolation contract.**
  - DECISIONS.md:630-662 says co-op-only systems (AI scaling, DBNO, officer waves, co-op objectives, spawn warping) must NEVER run in standard MP.
  - `docs/tools/check_mp_isolation.py` enforces this and is gated in build.ps1:362-366.
  - Later decisions narrow it: bug-2564 put co-op feel into PvP and `mp.scr`'s death path runs `player.scr::manageDead`; bug-2571 gave MP its own Allied and Axis armories. Both are recorded in `mp.scr`, not DECISIONS.md.
  - Correction: `changeGameType` sets `g_gametype` from its argument. The hardcoded 2 comes from its caller, the `giveInventory` wrap (main.scr:1067/1084).
- **Map change.** UBER and Survivor end maps with `timelimit 1`, a podium, or `bsptransition` plus a gametype flip. HZM must use `stuffsrv "map <name>"`.
- **HUD slot collisions.** cyb/snd/ft use global huddraw 202-211, Base Builder 9-10, alienx/hud.scr 24/26. Check these against HZM's HUD indices.
- **Entity budget.** Base Builder, flags and bomb props risk the entity-pool exhaustion already tied to bugs 914-927 in holdout.scr's header.
- **Poll load.** UBER uses 1 Hz scans, per-frame judges, a per-player melt-laser loop, and stufftext spam every 3 s. The script itself warns about CGM buffer overflow.

---

## 5. Licensing and permissions

| Work | Licence status | Source |
|---|---|---|
| searingwolfe UBER Mods v7.994 | **None.** GitHub licence field is null; no LICENSE, COPYING or CREDITS in 2,947 files; nothing in the README. Nexus and ModDB permission tabs unread (403). | https://github.com/searingwolfe/UBER-MODS-v8.00-MOHAA |
| Third-party code inside UBER | AlienX Base Builder (credited in in-game prints, not the header); Freeze Tag "almost identical" to Mefy's (README); Elgan's Admin-Pro menu; =ROCK= clan SP scripts (old readmes) | same repo |
| `global/libmef/mapdesc.scr` inside UBER | **MIT-style permission notice**, Copyright 2003-2005 Mark Follett (mef123). Covers that file only. That mef123 is "Mefy" is a reasonable inference, not stated. | https://raw.githubusercontent.com/searingwolfe/UBER-MODS-v8.00-MOHAA/main/global/libmef/mapdesc.scr |
| OwN-3m-All Ubermod V2, Push, Rabbit, LMS | Unknown; no licence seen on moh-db | https://www.moh-db.com/mods/11686-own-3m-all-s-ubermod-v2 |
| Mefy Extended-Gametypes 1.2.2 | Unknown (site 403) | https://mefy.moh-central.net/ |
| RaMsOc2 "JV Eaglear Bots + Extended Game Types" | **CC BY-NC-ND 4.0** (no derivatives, non-commercial) | https://gamebanana.com/apiv11/Mod/629093/ProfilePage |
| B3none mohaa-uber-basebuilder mirror | No licence; maintainer says none of it is their code | https://github.com/B3none/mohaa-uber-basebuilder |
| Base Assault, Build-A-Base, bomb_cs, Weapon Manager | Unknown | respective pages |

**What that allows (not legal advice):**
- **Rebuilding from the rules is the safe route.** Game rules and mechanics described in our own words, written as fresh HZM script, do not copy anyone's expression.
- **Copying scripts, models, sounds or HUD assets needs permission.** With no licence the default is "all rights reserved". UBER also bundles other people's code, so permission from searingwolfe alone may not cover AlienX's, Mefy's or Elgan's parts. CC BY-NC-ND forbids adapted versions outright.
- Using UBER's source as a *reference* to understand timings and edge cases while writing our own code is fine. Keep the implementation independent, and credit the original designers in HZM's docs as a courtesy.
- Credit correctly: Freeze-Tag, CTF and Demolition are Mefy's designs, not OwN-3m-All's. moh-db credits OwN-3m-All only with Push, Rabbit, Special Teleporter, LMS, Team Balancer, configs and some scripts.

**Contacts:**
- **searingwolfe:** GitHub profile `searingwolfe` (no public email); https://www.searingwolfe.com, which links YouTube @SearingWolfe, SoundCloud, ModDB and Nexus.
- **OwN-3m-All:** https://own3mall.com; GitHub https://github.com/own3mall (none of the visible repos are MOHAA); x-null.net forums.
- **Mefy (Mark Follett):** https://mefy.moh-central.net/; x-null / MOH community forums.
- **RaMsOc2:** GameBanana profile (via the mod pages above).
- **AlienX, Elgan:** x-null.net forums, author unconfirmed.

---

## 6. Downloads the user could approve

Nothing was downloaded. UBER Mods needs no download: every script can be read as plain text on GitHub.

| Priority | URL | File | Size | Why |
|---|---|---|---|---|
| **1** | https://own3mall.com/modules.php?cid=3&name=Downloads&orderby=dateD (listing) | `own3mall_push_mod.zip` (reported; name unverified). Reportedly contains `zZzZzZz_kingofmap_push.pk3` (+ `push.cfg`) | unknown | The actual Push mod. Would confirm the "kingofmap" link, checkpoint format, scoring and supported maps. |
| **1 (alt)** | https://api.moh-db.com/api/v1/downloads/mods/8555 (page: https://www.moh-db.com/mods/11686-own-3m-all-s-ubermod-v2) | `Ubermod Public Release V2.zip` | **10.07 MB** | The only confirmed-reachable source of Push, plus Rabbit, LMS, Countdown, Beach Soccer and Liberation-AA scripts, and the Reborn calls they make. **Contains a Windows .exe (MohaaConfigGenerator.exe): treat as untrusted, never run it.** |
| 2 | http://www.mohaaaa.co.uk/AAAAMOHAA/content/push-gain-ground-mod-20 | Push / Gain Ground Mod 2.0 (file name unknown) | unknown | Author and rules; is it the same as own3mall's Push? |
| 2 | http://www.mohaaaa.co.uk/AAAAMOHAA/content/gain-ground-mod | `zzzzz-Gain_Ground_mod.pk3` | unknown | Probable predecessor of Push |
| 3 | https://mefy.moh-central.net/ | `user-mefy-extgametypes-1_2_2-STOCKMAPS.pk3` / `-CUSTOMMAPS.pk3` | unknown | Mefy's original FT, CTF and Demolition rules and settings docs; settles the CTF rule conflict |
| 3 | https://gamebanana.com/mods/628682 | `user-freeze-telemaps-ramsoc2-merge.rar` | 167 KB | Small Mefy FT 1.2.2 repack (read-only reference; derived work) |
| 4 | https://www.x-null.net/forums/threads/1466-Rabbit-Mod-AA-Release-Version-6-1-1 | Rabbit Mod AA 6.1.1 (attachment name unknown) | unknown | Rabbit scoring details |
| 4 | https://www.moh-db.com/mods/18029-last-man-standing-team-balance-hud | `FilezZzZz_lastManStanding_mod.pk3` | 3.62 KB | LMS HUD rules |
| 4 | https://www.moh-db.com/mods/42957-bomb-conterstrike | `Filezzzzz_bomb_cs.pk3` | 4.84 KB | Minimal S&D bomb recipe |
| 5 | https://www.moh-db.com/mods/17803-weapon-manager-v20 | `zzzzz[BR_MOB]WeaponManagerV2.0.pk3` | 14.35 KB | 30 weapon-class-only modes |
| 5 | https://www.moh-db.com/mods/17855-mixing-gametypes | `Mixing_Game_Types.zip` | 87.12 KB | Per-map gametype rotation |
| 5 | https://gamebanana.com/mods/629093 | `jv_eaglear_bots_extended_game_types_standalone_.rar` | 9.66 MB | Mefy 1.2.2 plus bots, CC BY-NC-ND (reference only) |
| — | https://github.com/searingwolfe/UBER-MODS-v8.00-MOHAA/archive/refs/heads/main.zip | `UBER-MODS-v8.00-MOHAA-main.zip` | about 28 MB (repo size) | **Not needed**: the source is readable online |

For the .pk3, .zip and .rar files: inspect them as archives only; do not install them into the live game paths.

---

## 7. Open questions

**About "Kings Push" and Push rules**
1. Does "King of the Map" or `kingofmap` ring a bell for the user, or was it King of the Hill? This is the fastest way to settle it. **(load-bearing)**
2. Does `own3mall_push_mod.zip` really contain `zZzZzZz_kingofmap_push.pk3`? Is Push / Gain Ground 2.0 the same mod, and who wrote Gain Ground?
3. Push rules still unknown: number of checkpoints, whether a front can be pushed back, what scoring does (round reset, points, map end), how checkpoints are stored, and which maps are supported. **(load-bearing for design)**

**Project decisions for the user**

4. **Isolation vs Push and Freeze Tag.** DECISIONS.md says spawn warping and DBNO never run in *standard* MP. Push relocates spawns, and FT/cyb revive the dead. Should new modes count as separate gametypes with their own mode cvar, and so outside the "standard MP" rule, with their own MP-side copies of the recipes? And does that mode cvar fall under the single classic/modern host switch? **(load-bearing)**
5. Should new modes use g_gametype 2/3/4 plus an HZM mode cvar (the Mefy `g_extgametype` / UBER `g_ubergametype` pattern)?
6. Ask searingwolfe for permission to adapt UBER scripts, or rebuild entirely from the rules? Same question for OwN-3m-All regarding Push.

**Technical checks**

7. What does `GT_LIBERATION` (6, commented "Team Tactics") actually implement in fgame? Can stock BT Liberation be enabled natively before any script-only modes?
8. Which Reborn calls do Ubermod's Push and Rabbit actually make? This needs the zip.
9. Should the engine gain real `keypress` / `servercommand` / `intermission` triggers, and wire `isadmin` to HZM's admin mechanism, so community scripts don't fail silently?
10. What did `g_kblock` do on Reborn, and does its absence matter for a Base Builder rebuild?

**Rules still to pin down**

11. Mefy CTF rules: "hold the flag at base 15 s, first to 4", or classic "return while your flag is home"? Sources conflict.
12. Base Builder default build time: 800 s (mohdm1 example) or 500 s (summariser)? It is per-map, but confirm the README default.
13. Rules still missing for Countdown (Ubermod's version vs HTR vs COUNTDOWN-LIGHT), Beach Soccer, Base Assault, Build-A-Base, the DM-to-OBJ conversions and Nazi Zombies.
14. Are HTR and Survivor enabled anywhere in UBER by default, or are they dormant leftovers?
15. Who is "Merlin" and "Creaper" in the Ubermod credits? The roles attributed earlier had no source.
