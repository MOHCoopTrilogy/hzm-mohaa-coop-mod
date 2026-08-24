# Adversarial review — the six 2026-08-23 changes

Reviewed 2026-08-23. Scope: the six changes named in the brief, as they sit in the working tree
(uncommitted). Verdict: **NOT approvable.** Four of the six changes are inert as written — three of
them provably so against engine source, the fourth against the shipped `autoexec.cfg`.

The scanner sweep is clean; the *engine-contract* checks are where this batch fails, and it fails in
the exact shape [TRAPS T3](../../docs/TRAPS.md#t3) / the `turrets` section names: **the value was
set, and nothing reads it.**

---

## Scanner sweep — CLEAN (all categories)

Run on `officer.scr`, `probe.scr`, `challenges.scr`, `helmet.scr`, `loadoutpick.scr`,
`unlockreq_gen.scr` and (bonus, same batch) `gloves.scr`:

| check | result |
|---|---|
| `docs/tools/depthscan2.py` | **OK** — all 7 files |
| `docs/tools/linecheck.py` | **OK** — all 7 files |
| `docs/tools/quotecheck.py` | **OK** — all 7 files |
| `docs/tools/scrlint.py` (the build gate) | **exit 0**, 772 files clean; no new warns from this batch |
| BOM / non-ASCII / mixed line endings | **none** in any of the 7 (`unlockreq_gen.scr` is 268 lines, pure ASCII, uniform LF) |

Per T1 this proves the files *parse*; it proves nothing below.

---

# BLOCKERS

### 1. BLOCKER — `waittill damage` NEVER fires for a Player. The whole damage probe is inert.
**`coop_mod/probe.scr:161`** (`self waittill damage`), rationale at **`coop_mod/probe.scr:127-131`**.

The comment states the fix was verified rather than assumed:

> "Entity::Damage Unregisters STRING_DAMAGE on BOTH the killed and the pain path (entity.cpp:2874,
> 2901) and Player does NOT override Damage, so this fires for players"

Both halves are wrong in the way that matters.

* `Entity::Damage(...)` at **`openmohaa-hzm/code/fgame/entity.cpp:2690`** does **not** contain those
  lines. It is a 40-line wrapper that builds an `EV_Damage` event and `ProcessEvent`s it. The
  `Unregister(STRING_DAMAGE)` calls at **`entity.cpp:2874`** and **`entity.cpp:2901`** live inside
  **`Entity::DamageEvent`** (`entity.cpp:2731`) — the `EV_Damage` *handler* for a plain Entity.
* Player **does** override that handler: **`fgame/player.cpp:2095`** maps
  `{&EV_Damage, &Player::ArmorDamage}`. Sentient does the same at **`fgame/sentient.cpp:715`**.
  `Player::ArmorDamage` (`player.cpp:11011`) calls `Sentient::ArmorDamage` (`sentient.cpp:1505`),
  which runs to `delegate_damage.Execute(*ev)` at **`sentient.cpp:1874`** and **never calls
  `Unregister(STRING_DAMAGE)`**.
* There are exactly **four** `Unregister(STRING_DAMAGE)` sites in `fgame/`: `entity.cpp:2874`,
  `entity.cpp:2901`, `scriptslave.cpp:1399`, `trigger.cpp:821`. None is on a Sentient path.

`AddWaitTill(STRING_DAMAGE)` in the Entity constructor (`entity.cpp:1739`) means the waittill
*registers* — so there is no `invalid waittill` line, no error, no tell. This is
[T16](../../docs/TRAPS.md#t16): a wait that never completes.

**The project already knew this.** `.wolf/buglog.json`, on the `coop_blownOnDamage` watcher:

> "Polling not waittill damage — player damage routes through ArmorDamage where the script
> unregister is not guaranteed"

That recorded finding was not consulted ([T11](../../docs/TRAPS.md#t11)). The idiom looks safe
because it *does* work on Entity/ScriptSlave (the `JeepExplosion` truck loop, `scriptslave.cpp:1399`)
— it is Sentients it silently fails on.

**Player-facing scenario:** the user asks again "what is hurting me?", `coop_dmgProbe 1` is set,
`^~^~^ DMG watch armed on ent=N` appears once per player, and **not one `DMG` line is ever printed**
for the rest of the session. The probe built to end four rounds of guessing produces a fifth round of
guessing, and its silence is indistinguishable from "nothing hit you".

**Corroborating (pre-existing, out of scope but the same defect):**
`coop_mod/officer.scr:878` `local.officer waittill damage` — the officer retreat monitor. An Actor is
a Sentient, so `coop_officer_retreat_monitor` (threaded at `officer.scr:622`) has never fired either.

**Fix direction:** poll (`coop_blownOnDamage`'s recipe), or hook `Player::ArmorDamage` /
`scriptedEvents[SE_DAMAGE]` in the engine, or add the `Unregister` to `Sentient::ArmorDamage`.

---

### 2. BLOCKER — `self.fact` is never populated on a Player. If #1 were fixed, the probe would print a confident WRONG answer.
**`coop_mod/probe.scr:169`, `:175`, `:179`, `:181`, `:186`.**

`fact` is **not an engine field** — grep of `fgame/` and `script/` returns zero hits. It is a mod
convention, and it has exactly two writers, both the **AI pain handler**:
`coop_mod/aihandler.scr:964` and `global/pain.scr:40`. The mod's own notes say so twice:
`coop_mod/aihandler.scr:1631` and `coop_mod/xp.scr:1121` — *"self.fact is written ONLY by
actorPainHandler — the PAIN hook."* Neither runs for a Player.

So on a Player `self.fact` is `none`; `self.fact.attacker` throws, and per
[TRAPS](../../docs/TRAPS.md#script-error) a `Script Error` **skips the statement**, not the thread.
Trace the fall-through:

* `probe.scr:169` — the whole `if( self.fact.attacker != NIL ... )` block is skipped, so
  `local.acls` stays `"WORLD"`, `local.atn` `"-"`, `local.aent` `-1`, `local.dist` `-1`.
* `probe.scr:179` `local.dmg = self.fact.damage` throws → `local.dmg` unset → `:180` sets it `-1`.
* `probe.scr:181` `local.mod = self.fact.meansofdeath` throws → `:182` sets it `-1`.

Every line would read `atk=WORLD atkEnt=-1 dmg=-1 mod=-1 dist=-1`. Now read the probe's own legend at
**`probe.scr:137-140`**:

> "A script `radiusdamage` call has NO owner, so it lands as attacker=WORLD with mod=9
> (MOD_EXPLOSION) — which is precisely the signature of an invisible area hazard"

The probe would report `attacker=WORLD` on **every hit from every source**, and its author has
pre-committed to reading that as the area-hazard hypothesis. This is worse than the T3 blind probe:
it is a probe that manufactures evidence for one of the three candidates it exists to separate.

**Player-facing scenario:** the bombing-run / crater-fire hypothesis gets "confirmed", the prone
rifleman keeps killing paratroopers invisibly, and the next fix lands on the wrong system.

---

### 3. BLOCKER — `tracerfreq` on `script_aimedstrafinggunfire` is a WRITE-ONLY member. No tracer is produced.
**`coop_mod/officer.scr:2203-2206`** (`local.gun tracerfreq local.tfreq`).

The event is real — `EV_ScriptSimpleStrafingGunfire_TracerFreq` at
**`openmohaa-hzm/code/fgame/scriptslave.cpp:2280-2287`**, bound at `:2311`, and
`ScriptAimedStrafingGunfire` inherits it (`CLASS_DECLARATION(ScriptSimpleStrafingGunfire,
ScriptAimedStrafingGunfire, ...)`, `scriptslave.cpp:2395`). So the call is syntactically valid and
throws nothing. **It is also completely ignored.**

Every occurrence of `tracerFrequency` / `tracerCount` in `fgame/`:

| site | role |
|---|---|
| `scriptslave.cpp:2327-2328` | constructor init to 0 |
| `scriptslave.h:387-388` | the setter (`SetTracerFreq`) |
| `scriptslave.cpp:2380-2381` | `Archive` |
| `scriptslave.h:315-316` | member declaration |

**Zero readers.** Both fire paths ignore it: `ScriptSimpleStrafingGunfire::GunFire`
(`scriptslave.cpp:2347-2365`) and the override `ScriptAimedStrafingGunfire::GunFire`
(`scriptslave.cpp:2406-2429`) each end in the same call —
`ProjectileAttack(origin, dir, this, projectileModel, 1, 0, NULL)` — with no tracer argument and no
reference to the member.

The misleading neighbour is `Weapon`'s **`tracerfrequency`** (`fgame/weapon.cpp:423`), which *is*
consumed at `weapon.cpp:2061`. Different class, different member, one letter apart in the command
name. This is the `turrets` trap verbatim: *"before tuning a value, prove the failing PATH reads it —
grep the consumer, not the setter."*

**Player-facing scenario:** exactly the reported bug, unchanged. The prone rifleman's round is still
`scale 0.04` (`coop_ai_rifleround.tik`), still has no tracer, and the player still takes
unattributable damage from a man he cannot locate. The only thing that changed is that the bug now
has a comment saying it is fixed.

**Corroborating:** `officer.scr:3211` and `:3220` already set `tracerfreq 1` on other guns — that has
never rendered either, and nobody noticed, which is why this looked like a working lever.

**Fix direction:** the visible object is the projectile model. Raise `scale` on
`coop_ai_rifleround.tik`, or give it a tracer shader / trail, or add a `tracerFrequency` reader to
`ScriptSimpleStrafingGunfire::GunFire`.

---

### 4. BLOCKER — the `coop_sprintMult` default change is inert: the shipped `autoexec.cfg` forces 1.9, and execs LAST.
**`openmohaa-hzm/code/fgame/player.cpp:4709`** vs **`hzm-mohaa-coop-mod/autoexec.cfg:283`**.

Registration confirmed: `cvar_t *pMult = gi.Cvar_Get("coop_sprintMult", "1.05", CVAR_ARCHIVE);`
inside `Player::ClientMove` (`player.cpp:4561`), fgame = **server side**, so yes — this is a server
cvar and the host's value applies to every player. That part of the comment is correct.

Everything else is not. `hzm-mohaa-coop-mod/autoexec.cfg:283` contains:

```
seta coop_sprintMult 1.9
```

Per [T7](../../docs/TRAPS.md#t7) the engine execs `default.cfg` → saved config → **`autoexec.cfg`
LAST**, and `build.ps1` deploys `autoexec.cfg` to every maintt target. The deployed live copy
confirms it: **`G:\mohaa-gl2\home\maintt\autoexec.cfg:283`** is byte-identical. So on every launch,
after the engine default (1.05) and after `omconfig.cfg`, the value lands on **1.9**.

**1.15 → 1.05 changes nothing for anybody.** Sprint stays at 1.9 — the very value the change set out
to remove.

Two records assert the opposite and are both false:

* **`player.cpp:4704-4705`**: *"the reporter was running an ARCHIVED 1.9 (a tuning fossil; **1.9 was
  never shipped** and is not in coop_defaults.cfg)"* — 1.9 **is** shipped, in `autoexec.cfg:283`, and
  re-applied every launch. It is not a fossil on the reporter's machine; it is the shipped value on
  everyone's.
* **`docs/tools/config_fossils.py:11-13`** repeats the same claim in its docstring, and the tool only
  scans `omconfig.cfg` (`DEFAULT_CFG`, line ~35). Because `autoexec.cfg` execs *after* the saved
  config, a fossil tool that ignores `autoexec.cfg` cannot see the value that actually wins. It will
  report "no fossil" on a machine running 1.9.

This is [T7](../../docs/TRAPS.md#t7) (exec order) sitting inside
[T11](../../docs/TRAPS.md#t11) (acting on the record instead of the code) — the same pairing that
produced the wrong MSAA fix on 2026-08-21.

Secondary: the doc block at **`autoexec.cfg:279`** still recommends `1.9` as the tuned value, so the
cfg comment, the cfg `seta` and the engine default now state three different numbers (1.9 / 1.9 /
1.05).

**Player-facing scenario:** the friend reports sprint is too fast, a fix ships, a build is deployed,
and sprint is still 1.9 for both of them.

**Fix direction:** delete or lower `autoexec.cfg:283` (and the matching comment at `:279`). Until
that line moves, no engine default for this cvar can ever be observed.

---

# BUGS

### 5. BUG — 59 of 252 generated requirement strings are hard-truncated mid-word.
**`docs/tools/armory_unlocks.py:213`** — `return sanitise(out)[:80]`.

A blind 80-character slice, no ellipsis, no word boundary. Measured on the emitted file: **59 of 252
entries** sit at the cap. Samples straight out of `coop_mod/unlockreq_gen.scr`:

```
models/player/ramsey.tik    = "...Keep Captain Ramsey alive through the Nebelwer"
glv_mittens                 = "...Finish 5 missions without dying to unlock the Wool Mit"
models/player/mcmartin.tik  = "...Save the trooper hanging from the power pole on "
models/player/johnson_e2l1.tik = "...Finish Crete with Hudson, McMartin, Phillips, Johnson,"
```

The 80 was chosen (comment at `armory_unlocks.py:210-212`) to leave room for the caller's prefix —
but the truncation is applied to the *requirement alone*, and the callers then **prepend** more text
(`helmet.scr:488` `"Helmet locked: " + name + " - " + req`), so the budget is exceeded anyway while
the string is already mutilated.

**Player-facing scenario:** a player clicks a locked cosmetic and is told to *"Keep Captain Ramsey
alive through the Nebelwer"*. The whole point of bug-2078 was replacing a vague message with a
specific one; a sentence that stops mid-word is not more actionable than "via challenges/ranks", and
it looks like a shipping defect.

**Fix direction:** truncate on a word boundary with an ellipsis, or shorten the *source* descriptions,
or raise the cap and shorten the caller prefixes.

---

### 6. BUG — three challenges pay a reward every player already owns. The new validator finds it; nothing fixes it, and the build does not block.
**`hzm-mohaa-coop-mod/coop_mod/helmet.scr:1536-1560`** (`cosmetic_gatedBuild`).

`python docs/tools/check_challenges.py --warn` now reports:

```
NO-OP REWARD - cosmetic is ungated, so every player already has it (3):
  wpn_garand_e   The Tell-Tale Ping   -> models/player/american_army.tik
  wpn_johnson_e  The Better Rifle     -> models/player/american_army.tik
  wpn_m10_e      Six for Sure         -> models/player/american_army.tik

3 challenge(s) cannot be completed as shipped.
```

`python docs/tools/armory_unlocks.py` independently flags the same token:
`UNIFORM american_army ... <-- a challenge/rank points at it, but the gate list omits it`, plus two
more ungated uniforms (`allied_british_6th_airborne_captain`, `american_ranger3_hbt`).

The detector is new and correct. The **defect it detects was left in place**, and `build.ps1:228`
runs the validator with `--warn`, so the build prints the finding and proceeds. `american_army` is
absent from `cosmetic_gatedBuild` — which is *precisely* the mistake `helmet.scr:1537-1539` warns
about in the comment added by this same batch.

**Player-facing scenario:** a player grinds 3 elite weapon challenges for a uniform he could already
wear from his first spawn. `cosmetic_isUnlocked` only gates listed tokens, so the reward is a no-op.

---

### 7. BUG — the `flank` role is unreachable in the shipped configuration, so a third of the new leash rule is dead code.
**`coop_mod/officer.scr:2067`** (prone gate) vs **`:2095-2110`** (the new thresholds).

`randomint 100` yields 0..99. The prone branch takes `roll >= 100 - pchance` and `end`s.
`hzm-mohaa-coop-mod/autoexec.cfg:604` ships **`seta coop_aiProneChance 45`**, so prone claims rolls
**55–99** and only 0–54 reach the new thresholds. With the defaults `aggrThresh = 35`,
`coverThresh = 75`:

| role | condition | reachable rolls (shipped) | share |
|---|---|---|---|
| prone | `roll >= 55` | 55–99 | 45% |
| aggr | `roll < 35` | 0–34 | 35% |
| cover | `roll < 75` | 35–54 | 20% |
| **flank** | else | **none — `roll >= 75` is always prone** | **0%** |

So `officer.scr:2107-2110` — the flank branch and its new `base + (lbonus * 3) / 4` leash — never
executes as shipped. The comment at **`officer.scr:2087-2088`** ("*Defaults reproduce the current
split EXACTLY (35 aggr / 40 cover / 25 flank)*") is true only against the *old code*, not against the
*shipped configuration*: the real distribution is 45/35/20/0.

The flank arm of the new `coop_aiCoverShare` dial is therefore inoperable for any
`coop_aiProneChance >= 25`, at any value of `coop_aiCoverShare` (including 100, which yields
cover 55% / prone 45% / aggr 0 / flank 0).

The threshold structure is pre-existing; what is new is a dial and a comment that both describe a
partition the shipped config cannot produce.

**Player-facing scenario:** an operator lowers `coop_aiCoverShare` expecting fewer relocating enemies
and more flankers; flankers never existed, and the change silently converts cover actors into aggr
actors instead.

---

# RISKS

### 8. RISK — leash is re-anchored to the actor's CURRENT position, so it is a rolling radius, not a tether to his post.
**`coop_mod/officer.scr:2020-2022`** claims:

> "it is measured from m_vHome, which is the actor's SPAWN POINT (actor.cpp:3873) — so leash is
> precisely 'how far from his post may this defender roam'."

`m_vHome = origin` at `actor.cpp:3873` is correct **at spawn**. It does not stay there.
`Actor::SetLeashHome(vHome)` (`actor.cpp:4038-4043`) writes `m_vHome = vHome` whenever
`m_bFixedLeash` is false — and `m_bFixedLeash` defaults **false** (`actor.cpp:3055`) and is set only
by the separate `fixedleash` script event (`actor.cpp:11692`). `Actor::EventSetLeash`
(`actor.cpp:6732-6736`) does **not** set it.

`SetLeashHome(origin)` is called from every think this change touches:

| site | think | condition |
|---|---|---|
| `fgame/actor_turret.cpp:791` | turret (the **aggr** branch) | unconditional in `Begin_Turret` |
| `fgame/actor_cover.cpp:211` | cover (the **cover** and **flank** branches) | `level.inttime < m_iEnemyChangeTime + 200` |
| `fgame/actor_curious.cpp:66` | curious | unconditional |

So a defender who re-enters his think state carries his leash circle with him and can ratchet across
a map in leash-sized hops. Additive-not-assign is still strictly better than the old flat 4096, but
the mechanism the comment sells ("the territory goes back to whoever owns it") is weaker than stated,
and the m3l2 symptom ("everyone leaves the house") may not fully close.

*(Confirmed clean in the same check: leash **is** genuinely enforced. `actor_cover.cpp:92` and `:616`
call `SetPathWithLeash`, `:655` calls `MovePathWithLeash`; `Actor::SetPathWithLeash`
(`actor.cpp:11449-11469`) clears the path when either the destination or the actor is beyond
`m_fLeashSquared` of `m_vHome`. Turret think uses `CanMovePathWithLeash` at `actor_turret.cpp:582`,
`:650`. The brief's question "is leash respected by the movement paths that run" — **yes**.)*

---

### 9. RISK — `coop_aiCoverShare 0` is not "vanilla"; it is 100% aggressive with `nosurprise` and the largest leash bonus.
**`coop_mod/officer.scr:2095-2102`.**

At `cshare = 0`: `aggrThresh = 100`, `coverThresh = 100 + 0 = 100`, and `randomint 100` never exceeds
99 — so **every** non-prone actor takes the aggr branch. The comment at **`officer.scr:2085-2086`**
says *"lowering the share hands actors back to vanilla"*, but the aggr branch also writes
`local.actor.nosurprise = 1` (`:2102`) and the **full** `local.base + local.lbonus` leash (`:2101`).
Vanilla actors have neither. The dial's "off" position is the most aggressive setting available, not
the least.

No degenerate maths, though — see the clean list below.

---

### 10. RISK — the `<= 0` guard silently un-pins an actor a map deliberately pinned.
**`coop_mod/officer.scr:2046`** — `if( local.base == NIL || local.base <= 0 ){ local.base = 512 }`.

`leash 0` is a real authored value in this tree (`maps/M1L3c.scr:304-305` sets `leash 0` to pin two
actors). The guard cannot distinguish "unset" from "deliberately pinned to zero", so any actor
carrying leash 0 at read time is promoted to 512 and then handed a bonus on top — up to 1024 units of
roam for a man the designer nailed down. `M1L3c:304` happens to run later than the roll, so it is not
live today; a BSP `leash 0` spawn keyvalue would be.

*(The guard itself is safe from throwing — see clean list, `||` short-circuits.)*

---

### 11. RISK — the base leash is read ~1 s after spawn, which is the wrong side of some map assignments.
**`coop_mod/officer.scr:2045`**, dispatched from **`coop_mod/aihandler.scr:110`**.

`officer.scr:1872` records that *"coop_apply_personality runs ~1s after actor spawn (bug-1648)"*, and
[T3](../../docs/TRAPS.md#t3) already burned this exact function once (the scene-actor exemption keyed
on `alarmthread`, assigned 23 s later, and matched nothing).

Consequence: for a BSP garrison, `local.base` is the spawn keyvalue — correct. For an actor whose map
script sets leash **after** that first second (`maps/M3L3.scr:1048` pins Ramsey at 64 at a story
beat; `maps/M3L3.scr:1519` sets 800), the map's write lands *on top of* ours and the bonus is
discarded — which is benign, but is not the "base + bonus" the code claims to compute. The comment at
**`officer.scr:2027-2029`** cites `m3l2:780` and `M3L3:1048` as maps that *we* were stomping; for
`M3L3:1048` the ordering is the reverse.

Not observed to break anything. Flagged because the comment's causal story is used to justify the
design and is not reliable at both anchors it cites.

---

### 12. RISK — the probe's anti-ambiguity arm-receipt is defeated by the `developer` gate.
**`coop_mod/probe.scr:147`** and **`:186`**.

`ScriptThread::Println` opens with `if (!developer->integer) { return; }`
(**`fgame/scriptthread.cpp:2889-2892`**, via `Print` at `:2878-2881`). With `developer 0` **both**
the `DMG watch armed` receipt and every `DMG` line vanish together — which is exactly the ambiguity
the receipt was added at `probe.scr:144-146` to remove ("*two opposite diagnoses*"). The receipt only
disambiguates when it is already visible.

Known project rule, so this is a risk rather than a defect — but the receipt does not buy what its
comment says it buys, and given #1 it is currently the *only* line the probe can emit.

---

### 13. RISK — unbounded print rate on a probe with no throttle.
**`coop_mod/probe.scr:186`.**

One `println` per damage event per player, with no rate limit and no dedupe. An MG42 burst or a
`radiusdamage` tick against 4 players is tens of lines a second, and `autoexec.cfg` runs `logfile 2`
(per-line flush) for live tailing. Dormant today because of #1; it becomes live the moment #1 is
fixed. Also note `probe.scr:186` concatenates `self.origin` (a vector) as the **last** field — the
safest position, but per [T3](../../docs/TRAPS.md#t3) any field that throws truncates everything after
it, so the ordering should stay deliberate.

*(Thread-safety of the watcher is clean — see below.)*

---

### 14. RISK — the no-op reward check sees challenge rewards only; rank grants can pay the same no-op.
**`docs/tools/check_challenges.py:324-348`.**

The new loop iterates `chals` only. A cosmetic granted by `xp.scr::coop_xp_rankUnlock` but absent
from `cosmetic_gatedBuild` is exactly as worthless and is invisible to this validator — it shows up
only in `armory_unlocks.py`, which is not wired into `build.ps1`. Two of the three ungated uniforms
(`allied_british_6th_airborne_captain`, `american_ranger3_hbt`) are in that blind spot today.

Consider running `armory_unlocks.py` from `build.ps1` too, or folding the rank table into this check.

---

### 15. RISK — three new cvars are seeded nowhere, so their "defaults" are branches.
**`coop_aiLeashBonus`** (`officer.scr:2048`), **`coop_aiCoverShare`** (`officer.scr:2091`),
**`coop_aiProneTracer`** (`officer.scr:2204`), **`coop_dmgProbe`** (`probe.scr:136`, `:163`).

Grepped across `*.cfg`, `*.cpp`, `*.h`, `*.urc`: **zero hits** for all four. Per the closing paragraph
of [T7](../../docs/TRAPS.md#t7), a cvar seeded nowhere returns `""` from `getcvar` on a clean profile
and a script fallback branch decides behaviour — *"calling such a cvar 'default N' describes a branch,
not a default."*

Consequences: the values are undiscoverable by rcon on a clean profile, absent from
`docs/generated/CVARS_COOP.md`, and cannot be documented as defaults. Contrast the sibling the brief
asked about: `coop_aiProneChance` uses the **identical** `getcvar`/`!= ""`/`int()` idiom
(`officer.scr:2063-2065`) *and* is seeded at `autoexec.cfg:604` — which is why its live value is 45
and not the script's 12. The new cvars have the idiom but not the seed.

*(The `getcvar` idiom itself is safe here — none of the four is engine-registered, so the T7 bug-1669
"getcvar defeats the engine default" hazard does not apply. It **would** apply the moment any of them
is added to `G_InitGame`.)*

---

# NITS

16. **`coop_mod/challenges.scr:1155-1178`** — `chal_reqText` was inserted *between* `chal_add_unlock`'s
    doc header ("*Record an unlock id into the player's unlock set (dedup) + persist to the companion
    cvar/file...*", `:1150-1152`) and the `chal_add_unlock` label itself (`:1180`). The header now
    documents the wrong function.

17. **`hzm-mohaa-coop-mod/coop_mod/helmet.scr:1541`** — *"The other six are gated: three by challenge,
    three by rank."* Five tokens are listed (`:1542-1546`), and `gloves.scr:34-56` declares 7 gloves
    (indices 0–6), so 7 − 2 free = **five** gated, **two** by challenge (`challenges.scr:147-148`
    adds `glv_wool_unlock` and `glv_mittens_unlock`) and three by rank. Both numbers in the comment
    are wrong. No leak today — `armory_unlocks.py` reports 0 ungated gloves — but this is the
    allow-list whose own comment says an omission is silently free.

18. **`openmohaa-hzm/code/fgame/player.cpp:4710`** — `float mult = pMult ? pMult->value : 1.3f;`
    retains the pre-change `1.3` fallback, now inconsistent with the `1.05` registration one line
    above. Dead (`Cvar_Get` never returns NULL), but it is a third number in a three-number
    disagreement (see #4).

19. **`coop_mod/officer.scr:2048`** — `getcvar` is called once per actor per spawn for
    `coop_aiLeashBonus`, and it is read *before* the prone branch (`:2067`) that `end`s without using
    it. On a 55-actor map that is 55 wasted string lookups per map load. Trivial; noted only because
    `coop_aiCoverShare` (`:2091`) is correctly placed *after* the prone `end`.

---

# Explicitly CLEAN

These were checked against source and found sound. Stated so the next session does not re-litigate
them.

* **Parse safety — CLEAN.** `depthscan2.py`, `linecheck.py`, `quotecheck.py` and the build-gating
  `scrlint.py` all pass on all 7 files. No BOM, no non-ASCII, no mixed line endings.
  `unlockreq_gen.scr` is 268 lines of pure-ASCII LF with no parse killers.

* **`local.actor.leash` is genuinely readable — CLEAN.** `EV_Actor_GetLeash` is a real **`EV_GETTER`**
  (`fgame/actor.cpp:1170-1178`), bound to `Actor::EventGetLeash` at `:2634`, which returns
  `m_fLeash` (`:6722-6725`). `officer.scr:2045` uses **property** syntax, which is the required form
  per [T1](../../docs/TRAPS.md#t1). This is **not** the `enableEnemy` bug-2034 shape (that one is a
  lone `EV_SETTER`, `actor.cpp:1470`).

* **The NIL guard cannot throw — CLEAN.** `officer.scr:2046`'s `||` short-circuits:
  `OP_BOOL_LOGICAL_OR` / `OP_VAR_LOGICAL_OR` (`script/scriptvm.cpp:1239`, `:1250`) both use
  `doJumpVarIf` and skip the RHS when the LHS is true, so `local.base <= 0` is never evaluated on a
  NIL. (In practice the NIL arm is dead anyway — `m_fLeash` is initialised to 512 at
  `actor.cpp:2984`, so the getter always returns a float.)

* **The threshold math reproduces 35/40/25 EXACTLY at the default — CLEAN, computed.**
  `ScriptVariable::operator/=` (`script/scriptvariable.cpp:1670-1677`) truncates for int/int, and
  both operands here are integers. At `cshare = 65`:
  `aggrThresh = 100 - 65 = 35`; `coverThresh = 35 + ((65 * 40) / 65) = 35 + 40 = **75**`.
  Identical to the old literals `roll < 35` / `roll < 75`. Rounding drift elsewhere is benign
  (`cshare 50` → 50/30/20).

* **No divide-by-zero, no inversion — CLEAN.** The divisor at `officer.scr:2096` is the **literal
  65**, never a variable, so `operator/=`'s zero-check (`scriptvariable.cpp:1671`) can never fire.
  `(cshare * 40) / 65 >= 0` for all clamped inputs, so `coverThresh >= aggrThresh` always — the split
  cannot invert. Both extremes are clamped at `:2093-2094` and are well-defined:
  `cshare 0` → 100% aggr (but see risk #9); `cshare 100` → 0% aggr / 61% cover / 39% flank
  (`4000/65 = 61` after truncation).

* **The `getcvar` empty-string idiom matches the sibling — CLEAN.** `officer.scr:2048-2049`,
  `:2091-2092` and `:2204-2205` are structurally identical to `coop_aiProneChance` at
  `officer.scr:2063-2065`. (Seeding is a separate issue — risk #15.)

* **Leash is enforced by the paths that run — CLEAN.** See risk #8's parenthetical: cover think
  (`actor_cover.cpp:92`, `:616`, `:655`) and turret think (`actor_turret.cpp:582`, `:650`) both gate
  on the leash, via `Actor::SetPathWithLeash` (`actor.cpp:11449`) and
  `Actor::CanMovePathWithLeash` (`actor.cpp:11144`). `aimaneuver.scr:151-164` correctly hands
  flank/cover to the engine and issues **no** `runto`, as its comment claims.

* **`tracerfreq` is a valid setter — CLEAN (the call, not the effect).** `scriptslave.cpp:2280-2287`
  / `:2311` / `:2395`. It throws nothing and costs nothing. Its **cost** question is moot and its
  **entity-pool** question is moot: no tracer is emitted at all (blocker #3), so there is no
  MAX_SOUNDS or T4 pool exposure from this change. Had it worked, the fire path
  (`scriptslave.cpp:2427`) spawns one projectile per shot regardless of tracer setting, so the
  incremental cost would have been client-side FX only.

* **`$player.size` on an empty array — CLEAN.** `ScriptVariable::size()`
  (`script/scriptvariable.cpp:778-781`) returns **-1** for `VARIABLE_NONE`, so
  `probe.scr:139`'s `for( local.i = 1; local.i <= $player.size; ... )` simply does not run. The new
  loop is byte-for-byte the same idiom the file already uses at `probe.scr:139` and `:665` and that
  `aicombat.scr:29`, `aihandler.scr:1452` etc. use — no new exposure. The `NIL || NULL` guard at
  `probe.scr:141` follows [T5](../../docs/TRAPS.md#t5)'s "guard with BOTH".

* **The watcher does not duplicate or leak — CLEAN.** `probe.scr:142-143` latches
  `self.coop_dmgWatchOn` before threading, so re-entry of the 1 s poll cannot stack watchers.
  `ScriptVariable::operator==` returns **false** for mismatched types without throwing
  (`scriptvariable.cpp:1987-1990`), so `none != 1` is true on the first pass and the latch arms
  correctly. The latch lives on the Player object, so a reconnect (new object) re-arms and a
  respawn (same object) does not. The `continue` at `probe.scr:164` returns to a blocking
  `waittill`, not a spin. *(Its only defect is that it never wakes — blocker #1.)*

* **`chal_reqText`'s return idiom matches the codebase — CLEAN.** `end "<literal>"` and
  `}end <value>` are established: `aivoice.scr:113`, `:128`, `:130`; `ambience.scr:119`, `:123`;
  `developer.scr:359-363`; `aihandler.scr:1460`, `:1477`, `:1490`; `blueprint.scr:45`, `:54`, `:75`.
  All four call sites use `waitthread` (`helmet.scr:487`, `:1362`; `loadoutpick.scr:106`;
  `gloves.scr:162`), which is required to receive a value.

* **`unlockreq_gen.scr::main` is reachable and re-entrant — CLEAN.** Path
  `coop_mod/unlockreq_gen.scr` matches the `waitthread` at `challenges.scr:1173`. The guard
  `level.coop_unlockReqBuilt` (lines 14-15) is assigned before any read, so [T17](../../docs/TRAPS.md#t17)'s
  "reading a level var creates it as `none`" is harmless here (`none == 1` is false, no throw).
  `build.ps1:85` packs `$srcDir` recursively minus `$excludeTop`, so both new untracked files
  (`unlockreq_gen.scr`, `gloves.scr`) ship.

* **Token keys MATCH the call sites — CLEAN.** Cross-checked by extraction:

  | call site | token shape | match |
  |---|---|---|
  | `helmet.scr:487` — `level.coop_helmetTik[idx]` | `models/coop_helmets/*.tik` | **45 / 45** |
  | `helmet.scr:1362` — `"models/player/" + skin + ".tik"` | `models/player/*.tik` | **132 / 135** |
  | `loadoutpick.scr:106` — `local.r["give"]` | `models/weapons/*.tik` | present in table |
  | `gloves.scr:162` — `level.coop_gloveTok[idx]` | `glv_*` | **5 / 5** gated |

  Case matches exactly; no case-only mismatches found. The 3 skin misses are precisely the 3 ungated
  uniforms of bug #6 — they are never gated, so they never produce a lock message and never reach the
  fallback. **No silent fallback-to-generic-string defect exists.** Helmet indices 1–2 (`"std"`,
  `"none"`) are not in the table and correctly take the fallback at `challenges.scr:1174`.

* **`armory_unlocks.py` audit — CLEAN on the metric asked.** `guns 74 | helmets 47 | uniforms 135 |
  gloves 7 | gated 182 | sources 275`; **UNOBTAINABLE: 0**; **DEAD REWARDS: 0**. (The 3 UNGATED are
  bug #6.)

* **`check_challenges.py` gate-list regex — CLEAN.**
  `r'coop_cosmeticGatedTok\["([^"]+)"\]\s*=\s*1'` matches `helmet.scr`'s actual syntax
  (`level.coop_cosmeticGatedTok["<tok>"] = 1`) at every one of its sites, and the `l.split("//")[0]`
  comment strip does not damage any token (no `//` occurs inside a token). Exclusions verified
  correct: `perk_`, `finish_` and the newly added `glv_` are the non-asset families, and weapons are
  deliberately out of scope (their gate is `loadout_isUnlocked`'s free-starter list). Imports resolve
  — the tool runs and produces output, so `io`/`os`/`re`/`MOD` are all in scope and the
  `except OSError` is never reached via `NameError`. **No false positives found**; the one false
  negative class is risk #14.

* **`build.ps1` summary filter — CLEAN.** `build.ps1:229`'s
  `"^challenges:|cannot be completed|^OK - every|^NO-OP REWARD|^DEAD -|^SHORT -|^MISSING -"` matches
  the real header text at `check_challenges.py:297` (`"\nDEAD - ..."`), `:301` (`"\nSHORT - ..."`),
  `:305` (`"\nMISSING - ..."`) and `:346` (`"\nNO-OP REWARD - ..."`) — the leading `\n` produces a
  separate line, so the `^` anchors hold. Verified live against the tool's actual output.

---

## Summary

| # | severity | change | one line |
|---|---|---|---|
| 1 | **blocker** | (3) probe | `waittill damage` never fires on a Sentient — probe 100% inert |
| 2 | **blocker** | (3) probe | `self.fact` is actor-only; every field would read `WORLD/-1`, the exact signature it calls "invisible area hazard" |
| 3 | **blocker** | (2) tracer | `tracerfreq` has **zero readers** in the engine — no tracer, bug unchanged |
| 4 | **blocker** | (6) sprint | `autoexec.cfg:283 seta coop_sprintMult 1.9` execs LAST — 1.15→1.05 reaches nobody |
| 5 | bug | (4) text | 59/252 requirement strings truncated mid-word at 80 chars |
| 6 | bug | (4)(5) | 3 challenges pay `american_army.tik`, which is ungated and free; build only warns |
| 7 | bug | (1) leash | `flank` unreachable at shipped `coop_aiProneChance 45`; documented split never occurs |
| 8 | risk | (1) leash | `SetLeashHome(origin)` re-anchors `m_vHome` — rolling radius, not a tether |
| 9 | risk | (1) leash | `coop_aiCoverShare 0` = 100% aggr + `nosurprise` + full bonus, not "vanilla" |
| 10 | risk | (1) leash | `<= 0` guard promotes a deliberate `leash 0` to 512 |
| 11 | risk | (1) leash | base read ~1 s post-spawn; the comment's two cited map anchors order the other way |
| 12 | risk | (3) probe | `println` is `developer`-gated, so the arm receipt cannot disambiguate |
| 13 | risk | (3) probe | unthrottled print, `logfile 2` per-line flush |
| 14 | risk | (5) validator | no-op check covers challenge rewards only, not rank grants |
| 15 | risk | (1)(2)(3) | 4 new cvars seeded nowhere — "defaults" are branches (T7) |
| 16-19 | nit | — | misplaced doc header; glove count comment wrong; stale `1.3f` fallback; per-actor `getcvar` |

**Method note.** Everything above was confirmed by reading engine or script source; each claim
carries its `file:line`. Nothing here is inferred — the two places I could have inferred instead
(blocker #1's dispatch path and blocker #3's reader set) were settled by enumerating *all*
`Unregister(STRING_DAMAGE)` and *all* `tracerFrequency` occurrences in `fgame/`, not by reading the
one function that looked relevant. No runtime measurement was taken; blockers #1–#3 are static
proofs that a code path cannot execute, which is the class of claim source reading can settle.
