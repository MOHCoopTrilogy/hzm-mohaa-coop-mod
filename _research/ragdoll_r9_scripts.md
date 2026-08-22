# Round-9 review — the R8 script patches (officer.scr, mg42_hack.scr)

Scope: the two live-written script edits made during the round-9 playtest, logged as **bug-1971**.
Both are **uncommitted working-tree changes** in the mod sub-repo
(`git -C hzm-mohaa-coop-mod status` → ` M coop_mod/officer.scr`, ` M coop_mod/mg42_hack.scr`).
There is no commit to `git show`; the diff below is the working tree vs `HEAD` (`db1f788`).

---

## 0. VERDICT — stated first

| file | parse verdict | evidence |
|---|---|---|
| `coop_mod/officer.scr` | **PARSE-SAFE** | 5 scanners clean + independent running-depth scan |
| `coop_mod/mg42_hack.scr` | **PARSE-SAFE** | 5 scanners clean + independent running-depth scan |

**Correctness verdict: the surrender half of R8 is INCOMPLETE, and the mg42 half actively
undoes it.** Neither is a regression on the pre-R8 state — both make things strictly better than
they were — but the reported symptom ("germans run around with their gun on their back and don't
pull it out") will still occur, via at least **four producers R8 did not guard**, one of which is
reached by the single most likely player interaction with a surrendered man: shooting him.

Ranked findings are in §3. Two are marked **HYPOTHESIS** where the code path is confirmed but the
live occurrence is not.

---

## 1. PARSE SAFETY (detailed)

### 1.1 What was run

All of `docs/tools/`'s scanners, on both files:

```
python docs/tools/depthscan2.py   <both>   -> OK   OK        exit 0
python docs/tools/linecheck.py    <both>   -> OK   OK        exit 0
python docs/tools/quotecheck.py   <both>   -> OK, no unterminated string literals in 2 file(s)
python docs/tools/scrlint.py      <both>   -> 0 warns
python docs/tools/check_empty_rhs.py <both>-> 0 script(s) clean   (the bug-1908 class)
```

`depthscan2.py` was read before being trusted: it is comment- and string-aware (it skips `//` to
EOL, tracks `/* */`, and skips over `"…"` with backslash handling), so it is not the invalid raw
brace count that TRAPS T1 rule 2 forbids.

### 1.2 Independent running-depth scan (not the project tool)

Re-derived from scratch, CRLF-normalised, comment/string-aware, reporting the depth **at every
column-0 label** and detecting duplicate labels:

| | `officer.scr` | `mg42_hack.scr` |
|---|---:|---:|
| bytes | 222,934 | 1,930 |
| newlines | 4,944 | 35 |
| depth ever negative | **no** | **no** |
| depth at EOF | **0** | **0** |
| unterminated `/* */` at EOF | no | no |
| column-0 labels | 111 | 1 |
| labels at depth ≠ 0 | **none** | **none** |
| duplicate label names | **none** | **none** |

### 1.3 Byte-level hazards

| check | `officer.scr` | `mg42_hack.scr` |
|---|---|---|
| UTF-8 BOM | absent (`b'// Offic'`) | absent (`b'//======'`) |
| bytes > 0x7F (em-dash, smart quote, any non-ASCII) | **0** | **0** |
| line endings | 4,944 LF, 0 CRLF | 35 CRLF |

The mixed convention between the two files is pre-existing and harmless — the Morpheus lexer
treats `\r` as whitespace, and `officer.scr` has been LF-only across many shipped sessions.
Note for anyone editing `mg42_hack.scr` with a tool: it is **CRLF**, and git reports
`LF will be replaced by CRLF` for `officer.scr`, so a careless round-trip through a text-mode
Python script is the T2 hazard here, not the current content.

### 1.4 Expression syntax of the added constructs

TRAPS T1 is explicit that all three scanners pass files that cannot compile — they check depth,
line shape and string termination, **not expression syntax**. Each new construct was therefore
checked against working precedent in the current (compiling) tree:

| new construct | site | precedent |
|---|---|---|
| `if( local.actor.flags["coop_surrendered"] == 1 ){ end }` | `officer.scr:1940, 4755, 4837` | `aisquad.scr:146-149`, `aihandler.scr:1379`, `aimaneuver.scr:147` — 55 `local.actor.flags[` reads in the tree |
| `end` inside an `if` block at depth ≥ 2 | `officer.scr:1940` etc., `mg42_hack.scr:29` | `officer.scr:4901`, `:4913`, `:4912` (depth 3) |
| `local.actor.enableEnemy = 0` | `officer.scr:4936` | 35 `.enableEnemy =` sites in `officer.scr` alone, incl. `:1985`, `:2033`, `:4915` |
| `local.coop_w = self.flags["coop_mainActorWeapon"]` | `mg42_hack.scr:26` | `itemhandler.scr:463` reads the same key the same way |
| `local.coop_w != NULL && local.coop_w != NIL` | `mg42_hack.scr:27` | the documented NIL≠NULL idiom; `surrender.scr:85` uses the `== NIL \|\| == ""` variant |
| `self.gun = local.coop_w.model` (property read on RHS of a property write) | `mg42_hack.scr:28` | `aihandler.scr:229` `local.omodel = self.model`; `officer.scr:4919` `= local.actor.weapon`; `aihandler.scr:1685` `self.weapon = "<path>"` |

None of the added lines contains a `println` with an unparenthesised `+` chain (the bug-1751
blind spot), a vector literal, a bare parenthesised negative, an unquoted `+`/`-` directive
argument, a backslash path, or an empty-array literal. The seven new comment lines in
`mg42_hack.scr` and the ten in `officer.scr` contain `->`, `0->1` and `""` — all inside `//`
comments, all ASCII, and `quotecheck` confirms no odd-quote line.

**Residual risk statement (honest):** per TRAPS T1, none of this is *verified* until a server has
loaded a map and `qconsole.log` shows no `Script Error` / `parse error` with `developer 1` set.
Static analysis says PARSE-SAFE with high confidence; only a boot proves it.

### 1.5 One thing worth fixing before ship (cosmetic, not a parse issue)

`mg42_hack.scr:26-30` is indented with **tabs**, while the surrounding `[200] Smithy` block at
:31-34 uses **4 spaces + tab**. Purely cosmetic; the file is depth-clean either way.

---

## 2. THE ENGINE FACTS THE REVIEW RESTS ON

Every claim below is re-derived from source, not from prior notes.

### 2.1 `enableEnemy` is a *deferred, edge-triggered* field

* The script setter writes only the **desired** value:
  `Actor::EventEnableEnemy` — `actor.cpp:10931-10934` → `m_bDesiredEnableEnemy = ev->GetBoolean(1)`.
* It is applied once per think: `Actor::Think` — `actor.cpp:7914` calls `UpdateEnableEnemy()`.
* `Actor::UpdateEnableEnemy` — `actor.cpp:8776-8795`:
  * `8778-8781`: **early-out when `m_bEnableEnemy == m_bDesiredEnableEnemy`.**
  * `8785-8786`: on 0→1, `SetLeashHome(origin)`.
  * `8788-8791`: on 1→0, `SetThinkState(THINKSTATE_IDLE, THINKLEVEL_IDLE)` **only if** the
    idle-level think state is currently `ATTACK`, `CURIOUS` or `DISGUISE`.
  * `8793`: `SetEnemy(NULL, false)`.

**Consequences for R8's `local.actor.enableEnemy = 0` re-assert (officer.scr:4936):**

1. **It is free when unchanged** — CONFIRMED. An unchanged re-assert costs one `bool` store in
   the event handler and one `bool` compare + `return` in `UpdateEnableEnemy`. No think-state
   churn, no `SetEnemy`, no allocation. Re-asserting every 2.5 s is genuinely negligible.
2. **It does return a bounced actor to `THINKSTATE_IDLE`** — CONFIRMED, *provided the bouncer
   actually completed the 0→1 transition*, which it does: the bounce pairs are two adjacent
   statements in one frame, so `m_bDesiredEnableEnemy` ends the frame at `1` against a current
   value of `0`, and the next `Think` applies it. The surrender loop's next tick then drives
   `1→0`, and because the bounced actor is by then in `ATTACK` (that is what the bounce is *for*),
   the `8788` condition holds and he is forced back to idle. The comment at `officer.scr:4933-4935`
   is accurate.
3. **But the correction is late by up to one full tick.** The loop is `enableEnemy=0;
   anim_scripted; behav_bump; wait 2.5` (`officer.scr:4936-4939`). A bounce landing just after the
   re-assert leaves the man fully hostile — running, holstered, posed as if armed — for up to
   **2.5 s**, every time. That *is* the user's reported behaviour, just time-boxed. It is a
   suppressor, not a cure.

### 2.2 `Holster()` DOES clear the active slot — the in-code comment is wrong

* `Actor::Holster` — `actor.cpp:11691-11697` → `DeactivateWeapon(WEAPON_MAIN)`.
* `Actor::Unholster` — `actor.cpp:11715` tests `if (!activeWeaponList[WEAPON_MAIN])`, which only
  makes sense if `Holster` cleared it.
* `SimpleActor::EventGetWeaponGroup` — `simpleactor.cpp:1192-1207`: returns `STRING_UNARMED`
  whenever `GetActiveWeapon(WEAPON_MAIN)` is NULL.

**Therefore a holstered actor reads `weapongroup == "unarmed"` and `.weapon`/`.gun` == `""`.**

The comment at **`officer.scr:1941-1943`** — *"weapongroup reads 'unarmed' until the engine
finishes assigning/drawing the weapon (Holster does NOT clear the slot)"* — is **incorrect on the
parenthetical**. The retry loop it justifies is still right for the *spawn* race; the claim about
Holster is not. This matters because it is the stated reason the R8 guards were thought necessary.

Two direct consequences:

* The guards at `officer.scr:4755` (`coop_arrival_slide`) and `officer.scr:4837`
  (`coop_suppress_react`) are **redundant**: the very next line reads `weapongroup`, and the
  whitelist immediately below (`:4757`, `:4839`) rejects `"unarmed"` and `end`s. They are harmless
  and self-documenting, so keep them — but they are not what was protecting anything.
* A surrendered man **does** satisfy `anim/attack.scr:10`'s `self.weapongroup == "unarmed"` gate —
  which is how the mg42 rescue reaches him. See §3, finding **A2**.

### 2.3 `.gun` and `.weapon` are one getter and one setter

```
actor.cpp:2569  {&EV_Actor_SetWeapon,  &Actor::EventGiveWeapon}   // .weapon = x   (EV_SETTER, "weapon_modelname")
actor.cpp:2570  {&EV_Actor_GetWeapon,  &Actor::EventGetWeapon }   // = .weapon     (EV_GETTER)
actor.cpp:2571  {&EV_Actor_SetGun,     &Actor::EventGiveWeapon}   // ent gun "x"   (EV_NORMAL, actor.cpp:66-74)
actor.cpp:2572  {&EV_Actor_SetGun2,    &Actor::EventGiveWeapon}   // .gun = x      (EV_SETTER, actor.cpp:75-83)
actor.cpp:2573  {&EV_Actor_GetGun,     &Actor::EventGetWeapon }   // = .gun        (EV_GETTER, actor.cpp:84-91)
```

`Actor::EventGetWeapon` — `actor.cpp:5301`: returns the **held** weapon's lowercased, variant-
stripped display name (bug-1943/1948/1960), and — bug-1957 — the **empty string** when
`GetActiveWeapon(WEAPON_MAIN)` is NULL, with the `m_csWeapon` fallback deliberately removed.

So `.gun` is now read-as-*display-name-of-held* and written-as-*model-name-to-give*. That
asymmetry is the whole root cause. §4 specifies the split.

### 2.4 The give path, and what `.gun = <path>` actually does

`Actor::EventGiveWeapon` — `actor.cpp:5265-5290`:
`tolower()` → empty-guard → `m_csLoadOut = weapName` (`:5278`) → `m_csWeapon` → **`setModel()`** →
`ExecuteScript(global/weapon.scr, weapName)`.

`global/weapon.scr` maps display names to tik paths, and its **default** case
(`global/weapon.scr:349-361`) now passes any name containing `.tik` straight through (bug-1959),
then calls `self weapon_internal local.name` and threads
`coop_mod/itemhandler.scr::storeActorWeapon` (`global/weapon.scr:366-370`).

`Actor::EventGiveWeaponInternal` — `actor.cpp:5226-5255`: empty-give guard (bug-1959b), then
`Holster(); RemoveWeapons(); if (giveItem(...)) Unholster();`.

`Sentient::RemoveWeapons` — `sentient.cpp:1030-1042`: **`item->Delete()` on every inventory
weapon.** So a `.gun` give *destroys* the stored `coop_mainActorWeapon` entity; `storeActorWeapon`
then re-captures the replacement. The R8 line is safe here because
`local.coop_w.model` is evaluated **before** the assignment executes.

### 2.5 `.model` on a weapon entity is a full canonical tik path

`Entity::GetModelEvent` — `entity.h:743-762`: returns `gi.TIKI_NameForNum(edict->tiki)`, falling
back to the stored `model` string, and **`AddNil()` when `edict->tiki` is NULL**.
`Entity::setModel(str)` — `entity.cpp:2044` stores `model = CanonicalTikiName(mdl)`, and
`CanonicalTikiName` — `g_utils.cpp:1524-1536` **prepends `"models/"`** to anything not already
starting with it, then canonicalises. So `local.coop_w.model` is e.g.
`models/weapons/mp40.tik`. R8's give is therefore a legal tik-path give.

### 2.6 `use` accepts a model path — the safer primitive R8 didn't take

`Sentient::EventUseItem` → `Sentient::useWeapon(const char*, hand)` — `sentient_combat.cpp:1227-1248`
→ `FindItem(name)` — `sentient.cpp:1148-1162` → `FindItemByExternalName` (display name) →
**`FindItemByModelname`** — `sentient.cpp:1084-1109`, which prepends `"models/"` and
case-insensitively compares against `item->model`, the exact string `.model` returns.

**`self use local.coop_w.model` therefore resolves the stored weapon entity directly** — with no
`Holster`, no `RemoveWeapons`/`Delete`, no re-`giveItem`, no `weapon.scr` round trip, no
`m_csLoadOut` write and no `setModel()`. See finding **B1**.

### 2.7 `forceactivate`, `attackplayer` and the permanent latch

`Actor::ForceAttackPlayer` — `actor.cpp:9517-9521`:
`m_PotentialEnemies.ConfirmEnemy(this, G_GetEntity(0)); m_bForceAttackPlayer = true;`
`m_bForceAttackPlayer` is cleared at **exactly one** site, `actor.cpp:3110`, in the constructor.
It is a **one-way, per-life latch** (the same defect bug-1704/1708 chased). `enableEnemy = 0`
cannot clear it, so a surrendered man who is ever `attackplayer`ed keeps the player confirmed as a
potential enemy for the rest of the map.

---

## 3. RANKED CORRECTNESS FINDINGS

### A. The surrender fix is incomplete — four unguarded producers

> R8 guarded three long-lived per-actor threads. `coop_surrendered` is read in **exactly four
> places in the entire mod**, all four inside `officer.scr` (`:1940`, `:4755`, `:4837`, `:4913`).
> Nothing in `aisquad.scr`, `aimaneuver.scr`, `morale.scr`, `wounded.scr` or `aihandler.scr`
> honours it — and neither does `officer.scr`'s own `coop_officer_death_reaction`.
>
> Mod-wide census of the mechanism (comment-stripped, so these are live statements only):
>
> | file | `.enableEnemy =` writes | `forceactivate` |
> |---|---:|---:|
> | `officer.scr` | 35 | 29 |
> | `paradrop.scr` | 9 | 5 |
> | `wounded.scr` | 7 | 8 |
> | `aimaneuver.scr` | 3 | 3 |
> | `aihandler.scr` | 3 | 1 |
> | `surrender.scr` | 2 | 1 |
> | `aisquad.scr` | 1 | 2 |
> | `morale.scr`, `replace.scr`, `coop_selftest_weapons.scr` | 0 | 1 each |
>
> Adjacent `0` → `1` **bounce pairs** (the exact pattern the R8 comment names) exist at:
> `officer.scr:2033-2034`, `:4775-4776`, `:4867-4868`; `wounded.scr:222-223`;
> `surrender.scr:59-60`; `paradrop.scr:584-585`, `:637-638`, `:690-691`.
> **R8 covers three of the eight**, and the three it covers are covered only at thread *entry*.

---

**A1 — HIGHEST. `wounded.scr::coop_checkTacticalRetreat` bounces a surrendered man, and it is
reached by shooting him.**

*Path:* `aihandler.scr::handlePain` (label `:1031`) threads it on **every survived hit**
(`aihandler.scr:1047`). Also threaded from `officer.scr:3430` and `morale.scr:60`.
Its eligibility filter (`wounded.scr:112-136`) rejects protected actors, non-germans,
`coop_limping`, `coop_actorStopPainHandler`, `coop_waveActor`, `coop_role == "prone"`,
`coop_retreating`, the officer and turret gunners — **but not `coop_surrendered`**.
It then reaches the bounce at `wounded.scr:222-223` + `forceactivate` at `:224`.

*Why this is the worst one:* a player who does not want to recruit a surrendered german will
often shoot him. A non-lethal hit therefore *re-arms his hostility* — and, via §3-A2, gets his
rifle handed back. This is the most reachable producer and R8 does not touch it.

*Fix:* add `if( local.actor.flags["coop_surrendered"] == 1 ){ end }` to the filter block at
`wounded.scr:~130`, alongside the `coop_retreating` line.

---

**A2 — HIGHEST. The mg42 rescue re-arms and UN-HOLSTERS the surrendered man. The two halves of
R8 fight each other.**

*Chain, every link confirmed in source:*

1. Any producer bounces the surrendered actor to hostile → he enters the attack think.
2. `anim/attack.scr:10` — `if(self.weapongroup == "unarmed")` — is **TRUE** for a holstered actor
   (§2.2), so `AttackMain` calls `self waitthread coop_mod/mg42_hack.scr::main`.
   `anim/motionblend.scr:181-186` has the same gate.
3. `mg42_hack.scr:18` — `returnActiveWeapon` returns NULL for a holstered actor
   (`itemhandler.scr:2829-2840`, via `weaponcommand "dual"`), so the rescue branch runs.
4. `mg42_hack.scr:26-29` — the stored weapon entity is present (holster does not delete it), so
   `self.gun = local.coop_w.model` fires → `EventGiveWeapon` → `weapon_internal` →
   `giveItem` → **`Unholster()`** (`actor.cpp:5240-5243`).

**Result: the man puts his hands down, draws his rifle, and fights.** Before R8, `self use
self.gun` was a no-op because `.gun` read `""` (bug-1957) — which is precisely why the pre-R8
symptom was *"gun on their back… never fire"*. R8 fixed the no-op without teaching the rescue
that some unarmed actors are unarmed **on purpose**.

*Fix:* one line at the top of the `mg42_hack.scr` rescue branch:

```
if( self.flags["coop_surrendered"] == 1 ){ end }
```

placed immediately after `mg42_hack.scr:18`. It is the same shape and the same NIL-safety as the
three officer.scr guards.

---

**A3 — HIGH. The three R8 entry guards fire once and the surrender happens later, so they cannot
catch the case they were written for.**

* `coop_suppress_react` (`officer.scr:4835`) is an **unbounded** `while( local.actor != NULL &&
  isAlive local.actor )` loop polling at 0.3 s (`:4841-4870`). Its bounce is at `:4867-4869`,
  **inside** the loop. The guard at `:4837` runs once, at thread start.
* `coop_arrival_slide` (`officer.scr:4753`) loops up to 40 × 0.5 s = **20 s** (`:4761`); bounce at
  `:4775-4777`. Guard at `:4755`, once.
* `coop_prone_shooter` (`officer.scr:1936`) loops until sight is lost (`:2002-2023`); bounce at
  `:2033-2035`. Guard at `:1940`, once.

`coop_squad_surrender` cannot fire until **every** spawn-time squadmate is dead
(`officer.scr:4902-4911`), i.e. minutes into a firefight — always long after these three threads
started. So for `coop_suppress_react` in particular the guard is structurally unable to help.

*Mitigating fact:* because `Holster` clears the slot (§2.2), the re-read of `weapongroup` inside
those loops would reject a surrendered actor at `:4839`/`:4757` anyway — **for
`coop_suppress_react` and `coop_arrival_slide`, whose `local.wg` is cached at entry, that
protection does NOT apply**: `local.wg` was captured while he was armed and is never re-read.
The loop at `:4841` therefore proceeds to the bounce with a stale `"rifle"`.

*Fix:* move the check **into** each loop body, immediately after the `wait`:
`officer.scr:4844` (before reading `coop_suppressedAt`), `officer.scr:4765`, and
`officer.scr:2003`. Keep the entry guards too — they cost nothing and document intent.

---

**A4 — HIGH. `coop_officer_death_reaction` fans out to every german in 1200 u and has no
surrender filter — and it lives in the same file R8 edited.**

`officer.scr:3400-3445` walks `level.coop_actorArray["german"]` and, for up to 10 living actors
within 1200 u of a dead officer, either threads `coop_checkTacticalRetreat` (`:3430`, → A1) or
runs `attackplayer` + `forceactivate` (`:3437-3438`).
Its `continue` filters (`:3413-3419`) cover `coop_actorStopPainHandler`, `coop_limping`,
`coop_role == "prone"` and turret gunners — **not `coop_surrendered`**.

The `attackplayer` branch is worse than a bounce: `Actor::ForceAttackPlayer` (`actor.cpp:9517`)
sets the **permanent** `m_bForceAttackPlayer` latch and confirms the player as an enemy (§2.7).
`enableEnemy = 0` cannot undo either.

*Fix:* add the filter at `officer.scr:~3419`.

---

**A5 — MEDIUM. `aisquad.scr`'s squad brain *preferentially selects* surrendered men.**

* **SB2 go-loud** (`aisquad.scr:140-186`): the candidate test at `:144` is
  `if( local.m.enemy != NULL … ){ continue }` — *skip the already-engaged*. A surrendered man's
  `.enemy` was NULLed by `UpdateEnableEnemy`'s `SetEnemy(NULL)` (`actor.cpp:8793`), so he is
  **always** a candidate. Filters at `:145-149` cover role/limping/retreating/painhandler —
  not surrender. Ends in `attackPlayer` + `forceactivate` (`:183-184`).
* **SS1 search sweep** (`aisquad.scr:200-237`): filters at `:204-205` only; sets
  `enableEnemy = 0`, `runto`, `forceactivate` (`:233-235`) and threads
  `aimaneuver_reengage`, whose *first* action is `enableEnemy = 1` + `forceactivate`
  (`aimaneuver.scr:57-58`) — a full bounce with a `runto` attached.

*Not affected:* `aimaneuver.scr`'s own main loop, which requires `local.e.enemy != NULL`
(`aimaneuver.scr:~102`) — a surrendered man has none.
`morale.scr:47` has the same `.enemy != NULL` requirement, so its berserk/falter branches are also
naturally exempt **as long as nothing has already re-armed him**; once A1/A4/A5 do, he becomes
eligible for those too.

*Fix:* add the filter to both `aisquad.scr` filter blocks.

---

**A6 — MEDIUM (HYPOTHESIS as to live occurrence). An engine-side re-enable that no script guard
can reach.**

`Actor::GetMoveInfo` — `actor.cpp:3381`, obstacle branches at `:3417-3433` (ANIM_MODE_NORMAL) and
`:3448-3463` (ANIM_MODE_PATH): when a **non-teammate player physically bumps** the actor,

```c
if (!m_bEnableEnemy) { m_bDesiredEnableEnemy = true; UpdateEnableEnemy(); }   // 3418-3421
if (!CoopMannedTurretHold() && !CoopSceneAnimHold()) { BecomeTurretGuy(); }   // 3429
ForceAttackPlayer();                                                          // 3432
```

`CoopSceneAnimHold()` (`actor.cpp:3369-3371`) is `CurrentThink() == THINK_ANIM`, so an actor in
`anim_scripted scientist_surrender` is protected from `BecomeTurretGuy` — **but not from the
`enableEnemy` write, and not from `ForceAttackPlayer` and its permanent latch.**

Walking into a surrendered german is exactly what a player does while trying to hold USE at him
to recruit him (`surrender.scr:33` requires range < 110 u).

**HYPOTHESIS flag:** the code path is certain; that it actually fired in the round-9 session is
not established — `GetMoveInfo` runs on the *moving* actor's own move, and a surrendered man
standing in `anim_scripted` may never call it. Testing it needs a probe print in that branch. The
script-side re-assert at `officer.scr:4936` *does* undo the `enableEnemy` half within 2.5 s; the
`m_bForceAttackPlayer` latch it cannot undo.

---

**A7 — LOW. Exits that *should* restore hostility: checked, and they are all safe.**

The task asked whether the permanent `enableEnemy = 0` blocks any legitimate re-hostility. Enumerated:

| exit | verdict |
|---|---|
| **Player converts him** (`surrender.scr::convert`) | **SAFE.** `convert` sets `coop_converted = 1` *first* (`surrender.scr:53`), then bounces `enableEnemy 0→1` + `forceactivate` (`:59-61`). Morpheus threads are cooperative — they yield only at `wait`/`waitthread` — and `officer.scr:4925`'s loop body from the condition test through `enableEnemy = 0` / `anim_scripted` / `thread` to `wait 2.5` contains **no yield**, so `convert` can never interleave *inside* it. Either it runs during the 2.5 s wait (then the loop exits at the next test) or before it (same). The last write always ends up `enableEnemy = 1`. |
| **Surrender feature disabled mid-map** (`coop_aiSurrenderChance` → 0) | **SAFE but inert.** The cvar is only read at the decision point (`officer.scr:4912`); already-surrendered men are unaffected either way. There is no "un-surrender" path — by design. |
| **Officer wave ends / mission reset** | **SAFE.** The loop's own condition (`officer.scr:4925`) is death-or-convert; a map change tears down all script threads. |
| **A scripted event needing him hostile** | **NONE EXISTS.** `coop_squad_surrender` is personality-attached only, and `coop_isProtectedActor` already excludes scene actors, alarm runners and disguise-keyed actors from personality assignment. |
| **`recruitable` never starts** (`coop_surrenderRecruit 0`, `surrender.scr:22`) | **Intended.** He stays hands-up until killed. |

So the "blocks forever" risk is **not** realised. The `enableEnemy = 0` re-assert is safe to keep.

---

**A8 — Live measurement from the round-9 log (population, not a defect).**

`_research/ragdoll_r9_session_live.log` carries the `AIBEHAV3` odometer every 30 s.
`behav_bump "surrender"` has exactly one call site — `officer.scr:4938`, **inside** the 2.5 s
re-assert loop — so the counter measures *ticks*, i.e. `12 ticks per 30 s per living surrendered
man`. Re-derived deltas:

| window (UTC-6) | `surrender=` | Δ | ⇒ concurrent surrendered men |
|---|---:|---:|---:|
| 12:44:19 → 12:44:49 | 8 → 24 | +16 | ≈ 1.3 |
| 12:44:49 → 12:45:19 | 24 → 48 | +24 | **2.0** |
| 12:45:19 → 12:45:49 | 48 → 77 | +29 | ≈ 2.4 |
| 12:45:49 → 12:46:19 | 77 → 92 | +15 | ≈ 1.25 |
| 12:46:19 → 12:46:49 | 92 → 104 | +12 | **1.0** |

`convert=0` for the whole session — **not one man was ever recruited**, so every surrendered actor
stayed in the loop until death or session end. That matches the user's plural report and confirms
the surrender feature is firing at a rate that makes A1–A6 routinely reachable, not exotic.
(`dropgun=3` is a *pain animation* only — `aihandler.scr:1886` selects `<wg>_pain_dropgun`, no
weapon is removed — so it is not a second producer of unarmed men. `SQUAD` printed 244 times with
`alerts=0 search=0` in the tail, so A5's two branches were idle in *this* window.)

---

### B. The mg42 rescue net (`mg42_hack.scr`)

**B1 — HIGH. `self.gun = <path>` is the wrong primitive; `self use <path>` does the same job
without side effects.**

The stored entity is *already in the actor's inventory* — `Holster` only deactivates
(§2.2), it does not remove. All the rescue needs is to re-activate it.

| | `self.gun = local.coop_w.model` (R8) | `self use local.coop_w.model` (proposed) |
|---|---|---|
| resolves the stored entity | indirectly, by re-creating it | directly, `FindItemByModelname`, `sentient.cpp:1084-1109` |
| `Holster()` + `RemoveWeapons()` → `item->Delete()` | **yes** (`actor.cpp:5239-5240`, `sentient.cpp:1030-1042`) | no |
| re-`giveItem` + fresh entity + new entnum | yes | no |
| `global/weapon.scr` round trip + re-`storeActorWeapon` | yes | no |
| writes `m_csLoadOut` and calls `setModel()` | **yes** (`actor.cpp:5278-5284`) | no |
| preserves the weapon's ammo state | no (new entity) | **yes** |
| entity-pool churn per rescue | 1 delete + 1 spawn | 0 |

The last row matters given the entity-pool history (bugs 914-927, 1186): `anim/attack.scr:10`
re-enters `AttackMain` on **every attack think** while `weapongroup == "unarmed"`, so any actor
the rescue fails to fix churns a weapon entity per think tick.

**Recommended replacement for `mg42_hack.scr:26-30`:**

```
		local.coop_w = self.flags["coop_mainActorWeapon"]
		if( local.coop_w != NULL && local.coop_w != NIL ){
			self use local.coop_w.model
			self activatenewweapon "dual"
			end
		}
```

(`activatenewweapon "dual"` mirrors `:32` and the `aihandler.scr:1557-1558` idiom.)

---

**B2 — MEDIUM (HYPOTHESIS on the visible effect). A tik path in `m_csLoadOut` is baked into the
actor's model configstring.**

`Actor::setModel()` — `actor.cpp:11349-11382` — composes:

```c
if (m_csLoadOut != STRING_EMPTY) name = "weapon|" + Director.GetString(m_csLoadOut) + "|";   // 11355-11356
name += "headmodel|…|headskin|…|";                                                            // 11364, 11372
name += model;                                                                                // 11375
gi.setmodel(edict, name);                                                                     // 11380
```

`EventGiveWeapon` sets `m_csLoadOut = weapName` and then calls `setModel()` (`actor.cpp:5278-5284`).
With R8's give, `weapName` is `models/weapons/mp40.tik`, so the composite becomes

```
weapon|models/weapons/mp40.tik|headmodel|head4|headskin|…|models/human/german_…tik
```

The `weapon|<key>|` token is retail's **short loadout key** (`mp40`, `kar98`) used by the TIKI
setup to select the carried-weapon surface. Two consequences:

* **CERTAIN: configstring churn.** Every distinct composite mints a new `CS_MODELS` slot. The
  codebase already worries about exactly this — `aihandler.scr:233-237` snapshots head model/skin
  specifically "instead of the engine minting a fresh … (a new CS_MODELS slot) for every clone".
  A per-think rescue path is a far higher-volume source than clone spawning.
* **HYPOTHESIS: the on-back weapon surface may not resolve** from a path-shaped key, which would
  produce a german whose slung rifle is missing. This is the same shape as the confirmed
  `sentient.cpp:3245-3249` gib defect ("`models/headmodel|head4|…`… could never resolve"). It is
  **not verified** here — I did not trace the TIKI `weapon|` consumer — and it is not a *new*
  hazard: `aihandler.scr:1685/1696/1730/1735` and `surrender.scr:81/86` already give tik paths.
  R8 promotes it from a handful of variant sites to the mod's hottest re-arm path.

B1's `use` form sidesteps this entirely — it never touches `m_csLoadOut` or `setModel()`.

---

**B3 — MEDIUM. Loop analysis: no runaway, but a silent dead-end.**

`mg42_hack.scr::main` is called from `anim/attack.scr:10-14` and `anim/motionblend.scr:181-186`,
both gated on `weapongroup == "unarmed"` and both re-entered on **every** think while that holds.

* **Success:** `giveItem` → `Unholster` → `weapongroup` is no longer `"unarmed"` → the gate closes.
  `weapon.scr:368` threads `storeActorWeapon`, which re-captures the new entity
  (`itemhandler.scr:444-448`), so the flag self-heals. **Terminates.**
* **Failure** (`giveItem` returns NULL — `actor.cpp:5244-5254`, the `WEAPDBG GIVE-FAILED` branch):
  the actor is left holstered + weaponless, `storeActorWeapon` finds nothing and sets the flag to
  **`NULL`** (`itemhandler.scr:451`). The *next* pass therefore fails `!= NULL` and falls through
  to `self use self.gun` — which is the pre-R8 no-op, since `.gun` now reads `""`. **No infinite
  give loop**, but a per-think `Holster + RemoveWeapons(Delete)` churn until something else changes.
  A `use`-based rescue (B1) has no failure branch that deletes anything.
* **`edict->tiki == NULL`:** `.model` returns **NIL** (`entity.h:745-748`). `self.gun = NIL` →
  `ev->GetString(1)` is empty → `EventGiveWeapon`'s empty-guard returns (`actor.cpp:5271-5273`) →
  harmless — **but R8's `end` at `:29` has already fired, so the `self use self.gun` fallback at
  `:31` is skipped.** A tiki-less stored weapon silently gets *no* rescue at all. Low impact,
  worth a comment.

---

**B4 — CONFIRMED, no action. The stored value is the right thing.**

`self.flags["coop_mainActorWeapon"]` genuinely holds a weapon **entity**:
`itemhandler.scr:444-448` does `weaponcommand "dual" targetname ("actorGun"+entnum)`, then
`local.weap = $("actorGun"+entnum)`, stores it, and blanks the targetname again (`:449`).
It is set to `NULL` on the no-weapon path (`:451`) and NULLed on death by `enableWeapon`
(`itemhandler.scr:463-464`), so a live holstered actor's entry is valid.
`.model` is the correct property to feed back (§2.5), and the R8 guard checks **both** `NULL` and
`NIL` — correct per the project's NIL≠NULL rule, since an actor whose `storeActorWeapon` never ran
reads NIL, not NULL.

---

## 4. THE ROOT CAUSE AND THE ENGINE SPLIT

### 4.1 Every consumer of `.gun` and `.weapon`

`.gun` **reads** (all now receive display-name-of-held / `""`):

| site | wants | broken by bug-1957? |
|---|---|---|
| `mg42_hack.scr:31` `self use self.gun` | **SHOULD hold** | **YES** — the whole bug |
| `aihandler.scr:1557` `self use self.gun` (`leaveTurretUnholstered`) | **SHOULD hold** | **YES** — same defect, second site, *not patched by R8* |
| `aihandler.scr:231` `local.ogun = self.gun` (`coop_spawnReplica` snapshot) | **SHOULD hold** | **YES if parent is holstered** — clone gets `""`; note `:282`'s guard is `!= NIL`, and `""` is not NIL, so `local.r gun ""` runs and the empty-guard silently no-ops → unarmed clone |
| `replace.scr:2025` `coop_holsterGun = self.gun` | SHOULD hold | no — read *before* `self holster`, so still armed |
| `itemhandler.scr:480` `!self.gun` gate (`restoreNadeCount`) | IS holding | no — correct as-is |
| `itemhandler.scr:486, 505` `switch (self.gun)` — cases `"mauser kar 98k"`, `"g 43"`, `"shotgun"` … | **IS holding, display name** | no — **improved** by bug-1943/1960; tik-armed actors now resolve |
| `aihandler.scr:66` `coop_actorGun = self.gun` | — | **inside a `/* */` block, dead code** |
| `gags/t1l1_end.scr:636-717` `self.gun pitchCaps` / `setAimTarget` | — | different class entirely (a tank's turret entity), no `Actor` getter involved |

`.weapon` **reads** — `anim/aim.scr:158`, `anim/attack.scr:982/1263/1419`, `anim/reload.scr:24/125/257/298`,
`anim/cornerleft.scr:202`, `anim/cornerright.scr:206`, `aihandler.scr:1673/1694/1733`,
`officer.scr:4919`, `surrender.scr:75/85` — **all want "what he IS holding", as a lowercase display
name.** That is precisely what `EventGetWeapon` gives today. **`.weapon` is correct. Do not touch it.**

`.gun` **writes** — ~20 command-form sites in `officer.scr` (`:555`, `:706`, `:2120-2131`, `:2213-2217`,
`:2328-2332`, `:2423`, `:2485`, `:2634`, `:3098`, `:3117`, `:3328`) all pass display names
(`"stg44"`, `"mauser kar 98k"`, `"panzerschrek"`), which `global/weapon.scr` maps. Unaffected by a
getter split.

### 4.2 The split, specified

**Engine change — `openmohaa-hzm/code/fgame/actor.cpp` + `actor.h`:**

1. Declare `void EventGetGun(Event *ev);` in `actor.h` beside `EventGetWeapon` (near `actor.h:1499`).
2. Implement, next to `Actor::EventGetWeapon` (`actor.cpp:5301`):

```c
/*
===============
Actor::EventGetGun

`.gun` is the LOADOUT — "what this actor should be holding" — the mirror of the
EV_Actor_SetGun/SetGun2 setters, which write m_csLoadOut. It must stay non-empty while a
weapon is merely HOLSTERED (Actor::Holster clears activeWeaponList[WEAPON_MAIN], actor.cpp:11691),
because every re-arm site in the mod (`self use self.gun`) reads it exactly then.
`.weapon` (Actor::EventGetWeapon) keeps the other semantics: the display name of what is
actually IN HAND, "" when nothing is - which is what every retail anim switch needs.
Do NOT re-merge these two: bug-1957 broke every re-arm site by doing so.
===============
*/
void Actor::EventGetGun(Event *ev)
{
    if (m_csLoadOut != STRING_EMPTY) {
        ev->AddConstString(m_csLoadOut);
        return;
    }
    if (m_csWeapon != STRING_EMPTY) {
        ev->AddConstString(m_csWeapon);
        return;
    }
    // last resort: the held weapon's model path, so a tik-armed actor
    // (never given through the setter) still names something `use` can resolve
    Weapon *pActive = GetActiveWeapon(WEAPON_MAIN);
    if (pActive) {
        ev->AddString(pActive->model);
        return;
    }
    ev->AddString("");
}
```

3. Rebind **one line**, `actor.cpp:2573`:
   `{&EV_Actor_GetGun, &Actor::EventGetWeapon}` → `{&EV_Actor_GetGun, &Actor::EventGetGun}`.
   Leave `:2570` (`EV_Actor_GetWeapon`) alone.

`m_csLoadOut` and `m_csWeapon` are both `const_str` members (`actor.h:689`, and `m_csWeapon` in
`SimpleActor`), already archived (`actor.h:1939`), and `m_csLoadOut` is set on every give
(`actor.cpp:5278`) — so both the value and the archive round-trip already exist. `Weapon::model`
is a plain `Entity` member; `AddString` on it yields the canonical path, which
`Sentient::useWeapon` → `FindItemByModelname` resolves (§2.6).

**Who breaks, precisely:**

| site | effect of the split | required follow-up |
|---|---|---|
| `itemhandler.scr:486, 505` `switch (self.gun)` | `m_csLoadOut` is a *loadout* string (`"mp40"`, `"models/weapons/g43.tik"`), not a display name — the display-name cases stop matching and the switch falls to `default`, so SP grenade counts stop being restored | **change both switches to `switch (self.weapon)`** — that getter already returns exactly the lowercase base display name these cases were written for |
| `itemhandler.scr:480` `!self.gun` gate | becomes true for holstered actors (loadout is non-empty) so `restoreNadeCount` runs on them | **change to `!self.weapon`** — the label is about what is in hand |
| `mg42_hack.scr:31`, `aihandler.scr:1557` `self use self.gun` | **fixed** — this is the point | none |
| `aihandler.scr:231` `local.ogun = self.gun` | **fixed** — a holstered parent now clones armed | none |
| `replace.scr:2025` `coop_holsterGun = self.gun` | unchanged semantics (still armed at read time), value shape changes from display name to loadout key | verify the `unholster` label at `replace.scr:2031+` re-gives via a path that accepts either — `use` accepts both (§2.6) |
| all `.weapon` readers (retail `anim/*.scr`, `aihandler.scr:1673/1694/1733`, `surrender.scr:75/85`) | **untouched** | none |
| `gags/t1l1_end.scr` `self.gun` | different class | none |

**Cost:** one new engine function, one response-table line, two `.scr` word changes in
`itemhandler.scr`. **Ships as `game.dll` only** — no cgame, no exe, no protocol constant.

### 4.3 Ordering recommendation

The split (§4.2) makes `self use self.gun` work again for *every* re-arm site, at which point the
`mg42_hack.scr` patch is no longer load-bearing and could be reduced back to `self use self.gun`.
But `use <model path>` (B1) is correct **with or without** the split and costs nothing, so:

1. **Now, script-only, zero build:** B1 (`use` instead of `.gun =`), A2 (surrender guard in
   `mg42_hack.scr`), A1 + A4 + A5 (surrender filters in `wounded.scr`, `officer.scr:3419`,
   `aisquad.scr` ×2), A3 (move the three guards into their loops).
2. **Next `game.dll` build:** §4.2's `EventGetGun` split, plus the two `itemhandler.scr` word
   changes in the same commit.
3. **Optional, if A6 is ever observed:** clear `m_bForceAttackPlayer` inside
   `UpdateEnableEnemy`'s `1→0` branch (`actor.cpp:8787-8794`), next to `SetEnemy(NULL)`. That
   would make the latch reversible for *every* consumer — which is what bug-1704 and bug-1708
   both wanted and neither got. It is a behaviour change beyond this review's scope; flag it,
   don't ship it blind.

### 4.4 Correction owed to the source

`officer.scr:1941-1943`'s "(Holster does NOT clear the slot)" is wrong (§2.2) and is cited as
justification for the guard design. It should be corrected in place, since a future session
reading it will reach the same wrong conclusion about which actors read `"unarmed"`.

---

## 5. SUMMARY TABLE

| # | finding | severity | file:line | fix cost |
|---|---|---|---|---|
| A1 | `coop_checkTacticalRetreat` bounces surrendered men; reached by shooting one | **HIGH** | `wounded.scr:222-224`, entered from `aihandler.scr:1047` | 1 line |
| A2 | mg42 rescue un-holsters and re-arms the surrendered man — R8 fights R8 | **HIGH** | `mg42_hack.scr:26-29` ← `anim/attack.scr:10` | 1 line |
| A3 | the three guards are entry-only on threads that outlive the surrender; `local.wg` is cached | **HIGH** | `officer.scr:4837/4755/1940` vs loops `:4841`, `:4761`, `:2002` | 3 lines moved |
| A4 | `coop_officer_death_reaction` fans `attackplayer`+`forceactivate` with no surrender filter | **HIGH** | `officer.scr:3413-3438` | 1 line |
| B1 | `.gun =` re-give where `use` suffices: deletes + respawns the weapon entity every rescue | **HIGH** | `mg42_hack.scr:28` | 2 lines |
| A5 | `aisquad.scr` SB2 selects *exactly* the enemy-less, i.e. surrendered, actors | MED | `aisquad.scr:144-184`, `:204-235` | 2 lines |
| B2 | tik path in `m_csLoadOut` → composite model configstring churn (+ possible surface loss, **HYPOTHESIS**) | MED | `actor.cpp:11355-11356` ← `:5278` | fixed by B1 |
| B3 | give-failure path churns entity delete/spawn per think; NIL `.model` skips the fallback | MED | `mg42_hack.scr:29`, `actor.cpp:5239-5254` | fixed by B1 |
| A6 | engine bump path re-enables + latches `m_bForceAttackPlayer`, unreachable from script (**HYPOTHESIS** as to occurrence) | MED | `actor.cpp:3417-3432`, `:9517-9521` | engine, optional |
| — | `.gun`/`.weapon` share one getter — the root cause | ROOT | `actor.cpp:2570` vs `:2573` | §4.2 |
| A7 | surrender exits (convert, cvar, wave end) — **all verified safe**, no action | — | `surrender.scr:52-61` | none |
| §4.4 | `officer.scr:1942`'s Holster claim is factually wrong | DOC | `officer.scr:1941-1943` | comment |
