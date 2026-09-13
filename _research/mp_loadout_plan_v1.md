# MP Loadout - build plan v1

> **SUPERSEDED IN PART by the user's decisions of 2026-09-13. Where these conflict with anything below, these win.**
>
> 1. **THREE ARMORIES, not one.** Coop keeps its armory, unchanged. MP gets a separate **Allied armory** (Allied weapons
>    plus the shotgun, coop unlocks ENFORCED on every server) and a separate **Axis armory** (German, Italian and
>    Japanese weapons plus the shotgun, everything unlocked, full cosmetics: skins, headgear with glasses in the headgear
>    slot like US, gloves, weapon variants and weapon skins). Each has its own saved picks. "I don't want allies having
>    access to any non-allied weapons" - so the projection into coop's loSlot flags and the reuse of coop_loadout.urc
>    for Allies below are both OUT.
> 2. **The MP free floor is gone** (Kar98/MP40/P38/grenade in loadout_isUnlocked). It was team-blind, and the Axis
>    armory is fully unlocked anyway.
> 3. **MP never uses coop's armory code** (loadoutpick / challenges / xp / helmet / gloves / loadoutskins labels). That
>    was the source of the three coop leaks the isolation vet found; enforced by check_mp_isolation.py clause 10.
>    Read-only lookups (roster_get, skin tables, helmet/glove rosters, string helpers) may be allowlisted when the MP
>    armories are built.
> 4. **Axis first-person gloves get their OWN cvar** (a cgame change), not coop_gloveIdx.
> 5. **Never modify the German character tiks coop's stealth disguise uses.** Axis gloves / hat-free preview models are
>    NEW, separately named files (names must still start german/axis/it/sc for InitModel).
> 6. The Axis cfg tree must live under `ui/coop_*` - the stufftext filter drops server `exec` of `ui/mploadout/`.
> 7. FFA players are still allies/axis in this engine: choose the armory by dmteam in FFA too.
>
> **SUPERSEDED AGAIN ON UNLOCKS, later on 2026-09-13.** Decision 1's "coop unlocks ENFORCED" for Allies and "everything
> unlocked" for Axis are both OUT. In their place:
>
> 8. **MP HAS ITS OWN PROGRESSION.** MP-oriented challenges unlock ALL gear in MP, for both the Allied and the Axis
>    armory: weapons, weapon variants, weapon skins, character skins, headgear and glasses, gloves. User: "I think we
>    need to create challenges that are mp oreintated to unlock gear".
> 9. **START OVER IN MP.** Coop progress grants nothing in MP.
> 10. **GUNS UNLOCK BY KILLS PER CLASS, and class kills count across both teams** (a rifle kill as Axis advances the
>     Allied rifle ladder too). Variants and weapon skins unlock by kills with that weapon.
> 11. **PLAYERS CARRY THEIR OWN PROGRESS** to any server: "I don't think it should be per server, players carry their
>     own progress." The progress is client-held, so it needs a server-verified tamper check (to be designed).
> 12. **BOT KILLS COUNT** toward MP progression.
>
> Still standing: separate Allied and Axis armories, no non-Allied weapons for Allies, the shotgun on both, Italian and
> Japanese guns on Axis, glasses in the headgear slot, Axis gloves on their own cvar, the disguise tiks untouched, one
> primary, health 100, and MP never calling coop armory / challenge / xp code. Open assumption to confirm in design: one
> starter gun per class stays free, so a new player can always spawn armed.
>
> 13. **MULTIPLAYER OPTIONS OPENS THE MP LOADOUT SCREENS** (user, 2026-09-13): "in the 'Multiplayer Options' button, I
>     think we just need to make that go directly to the brand new loadout screens for both Allied and Axis (I guess you
>     have a picker to select which you want to change loadout for) applying that should make it become your default
>     for multiplayer (non coop modes)." So the entry point is a side picker (Allied / Axis) then that side's MP
>     armory, and Apply saves that side's default MP kit, used in every non-coop mode.
> 14. **THE STOCK WEAPON PICKER GOES** once the MP armories exist ("we dont need the stock picker do we?"): all five
>     SelectPrimaryWeapon menus, including the in-match ESC "Select Weapon" re-entry, lead to the MP armory instead.
>
> 15. **80 MORE DECISIONS, 2026-09-13, on the Multiplayer Decision Sheet:** see `_research/mp_decisions_2026-09-13.md`
>     (scope S1-S8, tamper T1-T7, progression P1-P14, armory A1-A8, flow and bots F1-F6, modes M1-M24, host H1-H9,
>     compass C1-C4). Chosen against the recommendation: third-party MP maps in scope now via an engine hook (S2);
>     scoped rifles count toward the base gun's class, not Sniper (P3); voice nationality must match the worn skin (A8).
>     The open assumption above is CLOSED: one free starter per class per side, the stock class kit gun (P1).

Authored 2026-09-09 from a 51-agent design pass with adversarial verification of every claim that
decides the design. Every file:line was read that session. **Zero binaries required.**

USER DECISIONS ALREADY MADE (2026-09-09):
  * a SEPARATE MP loadout, distinct from the coop/SP one, in the same UI idiom;
  * TWO of them - Allied and Axis;
  * it REPLACES the stock weapon-select screen;
  * Axis COSMETICS are ungated - pick German and you may use any German outfit, helmet or gloves.
    Axis WEAPONS keep the challenge unlocks they already have. See docs/DECISIONS.md.

  * THE MP FLOOR (decided 2026-09-09, bug-2557): "make sure the kar98, mp40 and walther p38 come
    free at least only on mp." Implemented in `loadout_isUnlocked` behind `level.coop_mpFreeKit`,
    which nothing sets yet, so it is inert until `mp.scr` exists. This is the narrow version of
    section 1's recommendation: progression decorates the MP kit, it never sets the floor.
    The STIELHANDGRANATE is included too ("yes give them the grenade too"), so the Axis floor is
    rifle + smg + sidearm + grenade, exactly matching the Allied free four that have shipped since
    2026-07-16. The MP floor question is now CLOSED.

  * ONE PRIMARY, not two (2026-09-09). The armory kit is 2 primaries + sidearm + grenade; retail MP
    is 1 primary, and shipping 2 would be a straight power increase over every stock server. MP uses
    slot 1 + sidearm + grenade; slot 2 is hidden on the MP screen. Coop keeps both.
  * MP HEALTH 100, not coop's 750 (2026-09-09). MUST be applied PER PLAYER at spawn in mp.scr, never
    by writing the `coop_health` CVAR: server.scr:238 re-seeds level.coop_health from that cvar on
    every map with a prevCoopHealth memo, so writing it would follow the player into the next COOP
    map. Enforced by docs/tools/check_mp_isolation.py clause 4.
  * ISOLATION IS A TESTED CONTRACT, not a promise (2026-09-09), at the user's explicit insistence.
    docs/tools/check_mp_isolation.py enforces seven clauses and build.ps1 ABORTS on any failure.
    Read its docstring before touching anything in this plan.

Read section 1 first - it is the reason the floor question existed at all.

---

# MP Loadout — Build Plan

**Verified against the code on 2026-09-09. Every file:line below was read this session or in the four preceding passes. Zero binaries required.**

---

## 1. The progression answer, first

**It works completely on your own server. It does not travel, and there is nothing to earn.** Both halves matter, and only one of them is fixable cheaply.

Unlocks are a **server-side file keyed by the client's GUID** — `challenges.scr:816-823` reads `coop_mod/save/unlocks_<id>.dat` and, on a miss, explicitly writes an **empty** unlock string (`:823`). So on your box, or any box you run, an MP loadout riding the SP progression behaves exactly as you pictured: the same padlocks, the same requirement text, the same armory. On someone else's dedicated server that has never seen your GUID, you arrive with **4 of 74 guns** — `loadoutpick.scr:779-782` hard-codes M1 Garand, Thompson, Colt .45, M2 frag as the only unconditional free items — and your archived picks are not quietly downgraded, they are **refused per slot with a toast**: `loadoutpick.scr:96-108` calls `loadout_deny ... 1`, which iprints `"Armory: <NAME> is LOCKED - <requirement>"`. Four slots, up to four toasts, on join.

Worse for the specific shape you asked for: **enforcing SP unlocks in MP takes weapons away that stock MOHAA gives free.** Stock MP does not pick a weapon, it picks a *class* — `client->pers.dm_primary` holds `rifle`/`sniper`/`smg`/`mg`/`shotgun`/`heavy`/`landmine` (`player.cpp:10674-10733`, exactly 7) — and `Player::EquipWeapons` (`player.cpp:10737`) resolves class × nationality into a hardcoded `giveItem`. An Axis player picking `smg` gets an MP40 **for free, every spawn, today**. The armory gates that same MP40 on `wpn_mp40 50` — fifty kills *with the MP40* (`challenges.scr:116`). I checked the whole stock German kit against `unlockreq_gen.scr`: Kar98 (rank 3), G43 (rank 5), MP40 (50 kills), StG44 (a campaign-scripted armory theft), Kar98 sniper (100 kills), Panzerschreck (15 kills), P38 (rank 1) — **all gated, including the sidearm**, and the roster's grenades use different tik paths (`steilhandgranate_start.tik`) than the engine's free ones, so they fail the allowlist too. A rank-0 account joining Axis under enforcement gets **no primary, no sidearm, no grenade**.

And nothing is earnable in PvP. `chal_init`/`xp_init` are threaded only from `coop_mod/main.scr::main`, which no stock MP map calls, so the challenge and XP systems are *inert* on MP maps. Even after you wire them, `chal_ai_killed` bails at `challenges.scr:1474` on `victim.team != "german"` — and a Player's script `.team` defaults to `"american"` (`sentient.cpp:958`) regardless of which MP team they joined, so **no PvP victim ever passes**. Then the rank wall: base kill is 3 XP (`xp.scr:753`, `int(3 * factor)`), rank 3 (Kar98) is 2,200 XP ≈ **733 kills**, rank 19 (FG42) is 330,000 XP ≈ **110,000 kills** (`xp.scr:232`, `:248`). Seven guns are outright circular with no source in MP once the picker is gone — De Lisle, MP40, .30 Cal, MG42, Bazooka, Panzerschreck, PIAT — and two more (MP40 Silenced, StG44 Scoped) sit inside the same closed loop, making it **nine**.

**So build it this way:** progression is the *decoration*, never the *gate floor*. The MP loadout has its own free floor — at minimum every weapon the stock nationality picker would have handed that player — and the SP unlocks add guns *above* that floor. Padlocks still show, requirement text still shows, your account still feels like it carries forward, and a stranger on a public server still gets a complete, legal kit. That is one `if` in `loadout_isUnlocked` and it costs nothing. Everything else in this plan is unchanged by the decision.

One distribution fact worth saying out loud, because it does not apply in coop: the armory's server→client `exec ui/loadout/*` push depends on an HZM patch in **cgame.dll** (`cg_servercmds_filter.cpp:337-349`, added for bug-597). A stock OpenMOHAA client silently drops it at `cg_servercmds.c:389` — no error, no menu. **The MP loadout only works for clients running your cgame.dll.** In coop everyone runs the mod; in MP that is a real constraint on who can join.

---

## 2. The design

### Binaries: zero

Everything below runs on the engine you already ship. The two engine features it depends on are already in the deployed DLLs (I verified the literals in `G:\mohaa-gl2\game.dll` and `cgame.dll`, both 2026-09-09 13:54): the path-scoped `exec` exemption in cgame, and the enabledcvar click-transparency patch in uilib (`uiwidget.cpp:1721-1741`). No new events, no new commands, no new cvars in C++.

### Storage

Three complete kits per player, not one. Coop keeps `coop_lo1..4` untouched.

| set | client archive (new) | server flags (new) |
|---|---|---|
| coop | `coop_lo1..4`, `coop_loA1..4`, `coop_loF*` | `coop_loSlot*` (existing) |
| MP Allied | `coop_mpa1..4`, `coop_mpaA1..4`, `coop_mpaF1..4` | `coop_mpaSlot*` |
| MP Axis | `coop_mpx1..4`, `coop_mpxA1..4`, `coop_mpxF1..4` | `coop_mpxSlot*` |

**Do not use `coop_loA*` or `coop_loX*` for "Allied/Axis".** `coop_loA<n>` is already the coop *resend recipe* (`ui/loadout/w01_s1.cfg:6` writes `seta coop_loA1 "append name ,w101"`; your live config has `seta coop_loA1 "append name ,w136"`), and `coop_loXfmC`/`coop_loXfmT1-4` are live modelxform bindings in `ui/coop_loadout.urc:53,344,417,490,563`. `coop_mpa*`/`coop_mpx*` are verified free — zero hits across the whole repo, the engine source, and your 4,549-line live `omconfig.cfg`.

**The projection trick — this is what keeps the change small.** Server-side, on team resolve, copy the active team's `coop_mpaSlot*`/`coop_mpxSlot*` into the *existing* `coop_loSlot<n>` / `coop_loSlotId<n>` / `coop_loFin<n>` / `coop_loWeapons` flags. Every downstream consumer already reads those and needs **zero edits**: `itemhandler.scr:1686/1689/1860/1863/2107`, `dbno.scr:277-278/1218-1219`, `loadout_rebuild:444`, `loadout_isPicked:629`, `loadout_ammoTopup:643`, `loadout_finResolve:1156`. A team switch re-projects and re-runs `loadout_rebuild`. The gametype gates in `itemhandler.scr` are all `if (level.gametype == 0){ end }` — an SP-only exit — so gametypes 2-8 pass every one of them already.

Cvar budget is a non-issue: 8 families × 4 slots × 2 teams ≈ 64 new names against `MAX_CVARS 8192` (`cvar.c:44`) and a 4,549-line archive.

### The screen

**A new file, `ui/coop_loadout_mp.urc`, menu name `coop_loadout_mp`. `ui/coop_loadout.urc` stays byte-identical.** This is not caution for its own sake — that file is 3,995 lines and **cannot be regenerated**: its own line 1 credits `scratchpad/gen_loadout3.py`, which exists in **no commit, branch or blob** in this repo. The surviving `docs/tools/gen_loadout.py` writes only the cfg half and never emits a `.urc`. A botched edit is recoverable only through `git show HEAD:`. Your own recorded rule (`docs/21-user-preferences.md:100-107`) puts the revert trigger on a `.urc` at the *second* failure, because you cannot see this surface from the dev box.

The 74-gun roster partitions cleanly: **42 Allied / 32 Axis**, and no `(tab, side)` cell exceeds **9 rows** — RIFLE 8/4, SNIPER 7/5, SMG 8/5, HEAVY 7/6, PISTOL 9/9, NADES 3/3 — against today's 12/12/13/13/18/6 physical rows. The MP screen is therefore a **re-layout of the same 148 tile+padlock widgets into a shorter grid**, not new widgets. Crucially, **no weapon appears on both sides**, so each tile's archive target is static — no runtime indirection needed.

The team dimension cannot be ANDed on a widget: `UIWidget::isEnabled` (`uiwidget.cpp:1695-1713`) takes exactly one cvar name with an optional leading `!`, and a second `enabledcvar` line silently overwrites the first (`:2545-2548`). So **fold team into the page flag**: 12 flags (`coop_mpP0A`…`coop_mpP5A`, `coop_mpP0X`…`coop_mpP5X`) instead of 6, and 12 generated `lktab` cfgs instead of 6. Keep tab 0 on the `!`-negated idiom (`!coop_mpNP0A`) — `UI_GetCvarInt` returns 0 for a missing cvar (`ui_init.cpp:57-63`), so a positive flag on the default page opens the menu **empty**, and there is no `showcommand` in the armory to seed it (I checked: zero hits).

Overlapping pages are safe, and this is already how the coop armory works — the 74 tiles occupy only **18 distinct rects** today (tile01/12/24/36/48/64 all sit at `rect 306 80 162 16`), and the HZM patch at `uiwidget.cpp:1721-1741` makes a gated-off tile both invisible and **click-transparent**.

**The padlock/unlock machinery is not duplicated per team.** A gun's unlock carries no nationality. The 148-command per-gun lock export (`loadout_ui_exportUnlocks`, `loadoutpick.scr:686`) and the ~183-command cosmetic export chain (`loadoutpick.scr:381-383`) serve all three sets unchanged. Budget the MP work against the *pick* block (28 cvars), not the lock block (345 of your 385 archived `coop_lo*` lines are lock state). The reliable ring is **1024** here (`qcommon.h:215`, raised for bug-1186), not 512.

### The entry flow, connect to spawned

```
connect
  → stock team menu (untouched)               engine
  → join_team allies|axis                     engine
  → Player::Join_DM_Team: dm_primary empty
    → stufftext "wait 250;pushmenu SelectPrimaryWeapon_<nat>"   player.cpp:11406 → 18422
  → that menu is a NEUTRAL SHELL (see step 1 of the build)
  → mp.scr per-player poll sees self.dmteam flip off "spectator"
    → stufftext "popmenu 0"
    → stufftext "exec ui/mploadout/open_a.cfg"   (or open_x.cfg)
  → player picks; tokens return on the name bus (,w1<id> … ,w0x, same vocabulary)
  → DONE → ,w0x
    → server: resolve kit → degrade against dmflags → self primarydmweapon <class>
    → engine EndSpectator + Respawn                              player.cpp:12088-12110
  → Player::Respawn → Init() → InitDeathmatch() → EquipWeapons()  player.cpp:3135 / 2621 / 10597
  → Player::Spawned() → scriptDelegate_spawned.Trigger           player.cpp:2649 → 18562
    → mp.scr::mp_onSpawn: takeall + give the picked tiks
```

Two things in that chain are worth calling out because they change the build.

**First — you get a free, per-respawn, post-equip hook, and nothing in the mod uses it.** I traced it this session: `Player::Respawn` (`:3075`) calls `Init()` at `:3135`; `Init()` calls `InitDeathmatch()` (which calls `EquipWeapons()` at `:10597`) and then `Spawned()` at `:2649`; `Spawned()` fires `scriptDelegate_spawned.Trigger(this, *ev)` at `:18562`. So `event_subscribe "player_spawned" coop_mod/mp.scr::mp_onSpawn` gives you a hook that runs **on every respawn, after the engine has already equipped the stock class kit, with the player as `self`**. That is exactly where `takeall` + the real gives belong — no polling loop, no race. (`registerev`/`event_subscribe`/`unregisterev` have **zero** occurrences in the mod's `.scr` tree, so there is no collision. Note the label reference must be **unquoted** — `coop_mod/mp.scr::mp_onSpawn`, not `"coop_mod/mp.scr::mp_onSpawn"` — the quoted form binds to the calling file and ScriptErrors. Precedent: `anim/cornerleft.scr:63`. Delegates are cleared per map at `scriptmaster.cpp:784`, so re-subscribe in `mp.scr::main`.)

**Second — do NOT reuse `giveInventory` to hand out the weapons.** `itemhandler.scr:2346` and `:2370` wrap the give in `main.scr::changeGameType 0 0` / `2 0`, and `changeGameType` ends in `setcvar "g_gametype" <n>` (`main.scr:1836`). On a live MP server that briefly sets gametype to 0 (zeroing every `DM_FLAG` macro, `bg_public.h:646`) and then restores it to a **hardcoded 2**, silently converting an Objective, Round, TOW or Liberation server into Team Match mid-match. Write a plain `takeall` + `give` path in `mp.scr` instead. Both `take`/`takeall` (`sentient.cpp:127-144`) and `stufftext` (`player.cpp:1262`) are `EV_DEFAULT` — no cheat gate, no gametype gate.

**The idle belt.** Only the DONE button emits `,w0x` (`ui/coop_loadout.urc:40` — the sole live emitter in the whole mod). ESC pops the menu with no token at all: `cl_keys.cpp:1207` intercepts K_ESCAPE *before* the bind table and routes to `UI_MenuEscape` → `PopMenu(qtrue)`, which additionally runs `Menu::RestoreCVars` (`uimenu.cpp:344-355`) and reverts all 28 `linkcvar` widgets. You already paid for trusting `,w0x` once — bug-588, the dead lobby cursor. So: arm a **25-second idle timer** on the armory push, **re-armed by every incoming pick token**, that fires `primarydmweapon` with the archived-or-seeded kit regardless. Do *not* fire on each pick — `EventPrimaryDMWeapon` self-deploys immediately (`player.cpp:12088-12110`), so a player would spawn on their first gun click with three slots unfilled.

**Degrade before you stufftext.** If the class is banned by dmflags, `EventPrimaryDMWeapon` prints "That weapon is currently banned" and **returns without writing `dm_primary`** (`:12079-12084`) — leaving the player parked in spectate forever at `player.cpp:6248-6252`. Read the ban bits first (`DF_WEAPON_NO_MG` at `:10835`, `NO_ROCKET` `:10861`, `NO_SHOTGUN` `:10883`) and substitute a legal class. MOHAA script has real bitwise operators (`parser/lex_source.txt:262-264`), so this is script, not engine.

### How the Allied/Axis split works

Team is server-side truth, read from `self.dmteam` (`"allies"` / `"axis"` / `"spectator"` — used throughout the mod, e.g. `aihandler.scr:1670`). There is **no team-join delegate**; `Join_DM_Team` fires no script hook, so `mp.scr` polls `self.dmteam` per player. On a flip:

1. project that side's `coop_mpaSlot*`/`coop_mpxSlot*` into the shared `coop_loSlot*` flags;
2. set the 12 page flags for that side (one `exec ui/mploadout/side_a.cfg` / `side_x.cfg`);
3. push the armory with the side's own `open_a.cfg` / `open_x.cfg`.

**You need two open/init cfgs, not one.** `ui/loadout/init.cfg:40-47` hardcodes `coop_loChar "models/player/american_army_nohat.tik"`, a US helmet, and the Allied skin ring. Reusing it for an Axis kit seeds an American mannequin. Both are generated files, so this is a generator change, not hand work.

Nothing else in the split is runtime. Because the partition is clean, tile→archive is static, and the side dimension lives entirely in generated page flags.

---

## 3. Build steps, in order

Each names the real file. **[D]** = same-day slice. **[M]** = multi-session.

**[D] 1. Neutralise all five weapon-select menu names.** `hzm-mohaa-coop-mod/ui/coop_weaponselect_suppress.urc` — delete the `end.` at lines **47, 57, 64 and 71**, keeping only the one at 78. Today the parser breaks at the first `end.` (`uilayout.cpp:112`) and the four nationality overrides at lines 52/59/66/73 are dead text — which is *why* only American-Allied players are locked out and Axis/British/Russian still get the stock picker. Runtime-confirmed: your 10.3 MB live `qconsole.log` has exactly **one** `dropping duplicate menu container` line, and it names `SelectPrimaryWeapon`. Do this step **only together with step 3** — on its own it extends the lockout to everyone.

**[D] 2. `hzm-mohaa-coop-mod/global/ambient.scr` — add the MP hook.** One line after the existing `level.gametype = int(getcvar(g_gametype))` at :22, guarded by the file's own idempotence flag (`level.ambient_script_run`, :3) and by `level.gametype != 0` plus "coop main not loaded". Measured coverage this session: of the **32 stock MP map scripts**, **30 exec `global/ambient.scr`**. The two that do not are `maps/lib/mp_ship_lib.scr` and `maps/obj/mp_bizertefort_obj.scr` (both in `maintt/pak3.pk3`, both exec `global/DMprecache.scr` instead). Ship mod copies of those two map scripts with the hook added — do **not** override `DMprecache.scr`, which would put stock precaching on you.

**[D] 3. New file `hzm-mohaa-coop-mod/coop_mod/mp.scr`.** Lean — not `main.scr::main`, which force-joins allies. It needs: `main` (subscribe `player_spawned`, start the per-player poll), a `dmteam` poll, its own netname/bus poller (the coop bus lives in `player.scr::manage`, launched only from `main.scr::main`, and will **not** run here — without it you receive nothing back, including the armory's own `,w0o` open ping), `mp_onSpawn` (takeall + give), the projection function, the dmflags degrade, and the idle belt.

**[D] 4. `coop_mod/loadoutpick.scr:779-782` — the MP floor.** Widen `loadout_isUnlocked` so that when the MP gate is active, every weapon the stock nationality picker would give that player is free. Add a **separate** `coop_mpLockLoadout` cvar; **do not reuse `coop_lockLoadout`** — `server.scr:28` seeds it only when empty, so once an MP map sets it to `0` it stays `0` for every coop map for the life of the server process. That is a real one-way latch, not a theoretical one.

**[M] 5. `docs/tools/loadout_weapons.tsv` + `docs/tools/gen_loadout.py` — add a `nation` column and an MP mode.** The generator currently hardcodes both the output dir (`UI` at `:30`) and the `coop_lo` prefix; both need parameterising so it can emit the MP cfg tree into `ui/mploadout/`. Add the `.urc` emitter here too, following `docs/tools/gen_service_record.py:1053` (which writes the 689 KB `ui/coop_sr.urc`) and `docs/tools/gen_glove_ui.py` (which already regex-rewrites `coop_loadout.urc` in place — precedent for the mechanical route). Keep the existing byte-compare `check` discipline.

**[M] 6. Generate `ui/coop_loadout_mp.urc` + the `ui/mploadout/` tree.** 12 page flags, 12 `lktab` cfgs, the two `init`/`open` pairs. Verify `git diff --exit-code -- hzm-mohaa-coop-mod/ui/coop_loadout.urc` comes back clean before every deploy.

**[M] 7. Wire the projection and the team-switch re-project** in `mp.scr`, plus reconnect persistence (replay a kit into the client chips via `exec ui/mploadout/w<id>_s<n>.cfg` — already proven in three places in the coop path).

**[M] 8. Optional: PvP progression feed.** `event_subscribe "player_killed" coop_mod/mp.scr::mp_onKill` — `Player::Killed` fires it at `player.cpp:3653`, **after** `KilledPlayerInDeathmatch` (`:3564`), with 11 args including meansofdeath (9), location (10) and victim (11). Two traps attached: `self.fact` is never written for a Player (`global/pain.scr` is dispatched only from `actor.cpp:5651`; the engine's own comment says so at `player.cpp:11559`), so you must synthesise a fact listener from args 9/10 or **13** fact-gated challenges score nothing; and `xp_killcap_factor` (`xp.scr:576-593`) counts `coop_isActive` players, which is 0 on an MP map and clamps to 1, collapsing the anti-farm thresholds to a server-wide 90/180 kills. Also guard against `killhandler` — if it is ever set, `player.cpp:3534-3541` returns before the trigger and silently kills progression with no error at the failure site.

**[D] 9. Fix the DONE-button bind vandalism** — unrelated to MP but it fires on every armory close and you are living with it now. `ui/coop_loadout.urc:40` runs `exec ui/loadout/fitunbind.cfg`, which unconditionally unbinds 15 keys. Three of them are bound in your **live** `omconfig.cfg` right now: `-` → `append name ,pgx` (line 9), `KP_PGUP` → `adsm_yaw` (65), `KP_PGDN` → `toggle cg_adsTune` (71). Every DONE click destroys them. Make `fitunbind` conditional on fit-tune mode actually having been entered.

---

## 4. First shippable slice

**Team Match, Allied side only, on the 17 stock DM maps** (`mohdm1`–`mohdm7` plus `mp_bahnhof/bazaar/brest/gewitter/holland/malta/palermo/stadt/unterseite/verschneit_dm`). Build steps 1, 2, 3, 4 and 9 — all marked [D]. Reuse `ui/coop_loadout.urc` unchanged for the Allied screen in this slice; the MP-specific `.urc` and the Axis half come in the second pass.

Why this one:

- **All 17 exec `global/ambient.scr`** — I verified it map by map. No straggler map scripts to override.
- The Allied path is the one that is **broken right now**, so slice 1 is a repair with a feature attached, not a pure feature. Today an American-Allied player joining any stock MP map is demoted to permanent spectator by the empty-shell suppression.
- The Allied armory is **already built**: 42 guns, 135 skins, every `w<id>_s<n>.cfg` page, the roster, the padlock export. Slice 1 writes no new UI files at all.
- **No landmine hole.** `QueryLandminesAllowed` (`player.cpp:10604-10669`) denies every `dm/mohdm*` map outright, so the minedetector question — the one stock class with no armory equivalent — does not arise. Same for the Gewehrgranate, which is German-model Axis only.
- **Axis keeps working the whole time.** Until step 1 lands you leave the four nationality overrides dead, so German/Italian/British/Russian players continue to get the stock picker. That is your fallback while the Allied path is under test. (Do step 1 *with* step 3, not before it.)
- No round or objective logic to fight — Team Match has no round restart to interact with the spawn gate.

One caveat inside the slice: **Free-For-All is not covered by "Allied only."** `GetTeam()` returns `dm_team`, which in GT_FFA is `TEAM_FREEFORALL` (`dm_manager.cpp:660-661`), so the `TEAM_AXIS` test at `player.cpp:18417` fails and *every* FFA player takes the Allied path against the default `american_army` model. That is actually convenient — the Allied fix repairs FFA for free — but `mp.scr` must treat `dmteam` values other than `"axis"` as Allied rather than switching on `"allies"` alone.

---

## 5. Decisions that are genuinely yours

- **MP floor policy.** Free floor = the stock nationality kit (my recommendation), vs. enforce SP unlocks strictly. Strict enforcement means a rank-0 Axis player spawns with nothing; the floor means progression only ever adds.
- **Axis cosmetics.** Hide the skin/helmet/glove tabs on the Axis page for v1, vs. build the Axis cosmetic roster now. All 142 armory skins are Allied and the spawn apply is guarded `dmteam != "axis"` (`player.scr:1275`, `:1299`) — but 88 Axis-legal models are already mounted, 85 have `_fps` twins, and 18 Axis headgear props already ship with four wired as axis rewards. The expensive `_nohat` pipeline can be skipped for Axis. Hiding is one page flag; building is a session. **Trap either way:** `InitModel` silently substitutes `german_wehrmacht_soldier` for any name not prefixed `german`/`axis`/`it`/`sc`.
- **Two primaries or one.** The armory kit is 2 primaries + sidearm + grenade; retail MP is 1 primary. Keeping 2 is a straight power increase over every stock server.
- **`coop_health 750` in PvP.** It follows the armory chain unless you branch it. 750 HP deathmatch is a different game.
- **Captured enemy weapons.** Allowing them breaks the clean 42/32 partition, makes each tile's archive target ambiguous, and costs a `vstr coop_loT<id>` indirection re-pointed by the side toggle — another 74-line cfg per side. Say no and the layout stays static.
- **The Gewehrgranate and both minedetectors.** They have no armory entry and replacing the picker deletes them across **10 Breakthrough maps** (`mp_bizertefort/bologna/castello/palermo_obj`, `mp_kasserine/montebattaglia/montecassino_tow`, `mp_anzio/bizerteharbor/tunisia_lib`). Cost to add: **three rows** in `loadout_weapons.tsv` — the tiks ship in stock paks and the armory skin variants for all three **already exist** (`loadoutskins.scr:44-50`, `:114-120`). Or leave the stock picker on those 10 maps.
- **Do MP unlocks write back to the same `unlocks_<guid>.dat` as SP,** or a separate MP file? Shared means PvP grinding advances your campaign armory. That is a design statement, not a technical one.
- **The 14 silenced weapons in PvP.** Silenced MP40 and De Lisle change deathmatch materially.
- **The 9 circular guns** (De Lisle, MP40, MP40 Silenced, .30 Cal, MG42, Bazooka, Panzerschreck, PIAT, StG44 Scoped): free in MP, or re-point their challenge at a stat PvP can produce? The floor policy answers this for 5 of them automatically, since they are in the stock class table.

---

## 6. What I could not determine, and the cheapest way to find out

1. **Does the `popmenu 0` land after the engine's `wait 250;pushmenu`?** Client `exec`/`vstr` **insert at the front** of the Cbuf while server stufftext **appends** (TRAPS T8), so the ordering is not FIFO and my entry flow assumes it resolves cleanly. — *Listen server, rcon, join a team, watch the screen. ~10 minutes. If it races, the fix is to push the armory with a small `wait` of its own rather than popping.*

2. **Does `event_subscribe` accept an unquoted label token against its `"ss"` typespec?** The signature says two strings; the quoted form provably fails (binds to the calling file); the unquoted CONSTARRAY form is what `SetThread` needs. Nothing in the mod uses this builtin, so it has never been exercised here. — *One `println` in a stub label on any coop map. 5 minutes. This gates step 8 and the `mp_onSpawn` hook.*

3. **Does the armory work at all for a remote client?** Every armory verification on record is on the **listen host** (bug-758: "Runtime-verified via rcon on a live m1l1 LISTEN server"). `loadout_hostSeed` is host-gated by design (`loadoutpick.scr:426`, the bug-715 rule) precisely because `coop_lo*` are the host's own archive. Remote-client armory is **untested**, and it is the entire premise of MP. — *One dedicated boot plus a second machine or a friend. This is the highest-value measurement on the list and it should happen before step 5.*

4. **Does `coopprof` actually work?** `coopprof <index> <data>` is a live `EV_CONSOLE` event reassembling up to 8192 bytes into `self.coop_profdata` (`player.cpp:328-336`, `:1997`, `:7542-7567`) — a far wider client→server channel than the name bus, and a whole kit is ~40 bytes. It has been run three times (08-13 and 08-15 logs) and reported `got=[NIL]` every time, because the probe delivers it by **stufftext** and `coopprof` fails the whitelist prefix test (`cg_servercmds_filter.cpp:173` requires `coop_`, and "coopp" has no underscore). That is a **false negative**, not a verdict. — *Change `coop_mod/profile.scr:57-58` to write the command into a `coop_*` cvar and `vstr` it, set `coop_profProbe 1`, read the PROFCHAN line. ~20 minutes.* Note the per-command payload is **255 bytes**, not 2048 — `Cmd_Args_Sanitize` truncates every argument at `MAX_CVAR_VALUE_STRING - 1` (`cmd.c:626-641`) with no error. Also note the probe's only caller is mis-nested inside `if (level.coop_noDeployables != 1)` at `player.scr:1239`, alongside `loadout_seedDefaults` at `:1251` — both should move out of that block regardless.

5. **Does the 74-tile stack behave with 12 page flags as it does with 6?** The click-transparency patch is real and the 18-rect overlap already ships, but nobody has stacked 12 pages. — *One screenshot per tab per side after slice 2. Cannot be checked from the dev box; it needs your eyes.*

6. **Whether an empty shell menu sitting on top of the armory eats the cursor.** The current suppression file has never been on screen *over* another menu. If step 1 + step 3 produce a dead cursor, the answer is to make the shell a zero-size container rather than an empty one. — *Same 10-minute listen test as (1).*