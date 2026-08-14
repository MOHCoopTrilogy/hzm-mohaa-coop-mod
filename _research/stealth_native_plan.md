# Stealth-Native Mode — research, vetting, and plan

**Goal (user, 2026-08-12):** *"a stealth system that can be chosen to play loud or go loud by failure
of stealth"* on **m6l2a**, without changing behaviour on any other mission.

**Framing.** These are not bugs in a stealth system. MOHAA's disguise system was built for exactly one
pattern — the one m2l2a uses: walk in, show papers, never fight, leave. Every shipped stealth map
obeys it. m6l2a wants *stealth with agency* — kill quietly, choose the moment, manipulate the
environment. The engine has no concept of that, so patching symptoms will keep failing. The work is
to add the concept, gated to one map.

---

## 1. Verified findings

Each anchored to source. Everything here was read, not inferred.

### 1.1 The silenced pistol was never silent — DATA, ours, now fixed

`weapon.cpp:2164`:

```c
if (!quiet[mode] && next_noise_time <= level.time) {
    if (g_gametype->integer == GT_SINGLE_PLAYER) {
        BroadcastAIEvent(AI_EVENT_WEAPON_FIRE, 1500);
    } else {
        BroadcastAIEvent(AI_EVENT_WEAPON_FIRE, Q_clamp_float(world->GetRadius() * 0.5, 1500, 8000));
    }
}
```

The engine **already supports silenced weapons** via the per-firemode `quiet` flag. Retail
`models/weapons/silencedpistol.tik` carries `quiet // don't notify AI of it being fired` on the
PRIMARY fire. **Our copy had only `secondary quiet`** (the melee), so every shot broadcast a
weapon-fire AI event. No git or buglog record of the removal being deliberate — it looks lost during
the `sp`/`dm`/`realism` damage restructure. Restored 2026-08-12.

This is most of the reported "they lose their shit when I kill him even if it is unseen".

### 1.2 Coop gunfire is up to 5x louder than single-player — ENGINE

Same block. SP broadcasts a flat **1500** units. Multiplayer — which is every coop game — uses
`clamp(world_radius * 0.5, 1500, 8000)`, an OPM addition. On a map the size of m6l2a a single shot
can alert AI **8000 units** away. This applies to *every* weapon, not just the pistol, so it governs
how far a firefight propagates on the loud path too.

### 1.3 A disguise interaction permanently stops a patrol — ENGINE

Every exit from the disguise think lands on `SetThinkState(THINKSTATE_IDLE, THINKLEVEL_IDLE)` —
`State_Disguise_Accept`, `_Deny` and `_Halt` all do (`actor_disguise_common.cpp:150-176`). Nothing
re-arms the patrol the actor was walking. He stands where the conversation ended, forever. The map's
own `patrol_ai_forceactivate` does that job but runs **once**, at init, long before any challenge.

Currently worked around from script (`m6l2a.scr::coop_m6l2aPatrolWatchdog`, `forceactivate` on a 3s
tick). A stealth-native map wants the engine to restore the prior think, because otherwise every
conversation subtracts one guard from the map's life.

### 1.4 Officers can never accept papers — ENGINE, by design

`State_Disguise_Papers` (sentry, `actor_disguise_common.cpp:96-121`) can reach
`ACTOR_STATE_DISGUISE_ACCEPT`. `State_Disguise_Fake_Papers` (officer, `:123-139`) has **no accept
branch at all** — only `DISGUISE_ENEMY` or `DISGUISE_HALT`. So an officer is a wall, and a sentry is a
door. Not a defect; it is the lever that makes a checker "see through" the disguise, and m6l2a now
uses it deliberately for the Reichsbahn Officer.

### 1.5 The alarm here is a TOGGLE, and the disguise flickers with it — ENGINE/DESIGN

`m_bIsDisguised` requires `!level.m_bAlarm` (`player.cpp:5535`). m6l2a's `threat_condition_delta`
sets `alarm_always_on` with a 6-10s re-ring, and this map's alarm can be switched **off** again —
unlike m2l2a's one-way alarm. So once that fires, cover flickers on and off every few seconds.
There is already a comment noting this at `m6l2a.scr:1095`.

**User decision 2026-08-12: once blown, permanently blown.** A latch, not a flicker.

### 1.6 The two alarm systems are not the same code

m2l2a and m6l1c use `global/alarm_system.scr`. m6l2a uses **`global/alarmer.scr`** — a different
system, reinforced from ~15 `alarm_spawndetector` entities. The disguise gate that `alarm_system.scr`
always had was hand-added to `alarmer.scr` on 2026-08-11. Assume nothing carries over between them.

### 1.7 The papers level is one engine integer, and only items.scr writes it

`State_Disguise_Papers` compares `level.m_iPapersLevel < m_iDisguiseLevel`
(`actor_disguise_common.cpp:112`). Its **script-visible name is `level.papers`** — an
EV_GETTER/EV_SETTER pair on Level (`level.cpp:163-181`). The ONLY writer anywhere in the mod is
`global/items.scr`: `add_item "papers_level1"` sets 1 (`:215`), `"papers_level2"` sets 2 (`:234`),
`remove_item` sets 0 (`:464`, `:469`).

**Caught by this vetting pass:** m6l2a's level-2 pickup set a private flag and never called
`add_item "papers_level2"`, so `level.papers` stayed at 1 and a `disguise_level 2` checker would have
denied forever. It had been masked by demoting the checker to level 1 — which removes the two-tier
gate entirely. Fixed 2026-08-12 with m2l2a's exact order (`m2l2a.scr:449-450`): **remove level 1
first**, which zeroes the field, **then add level 2**.

### 1.8 Actor composition was never authored for disguises

m2l2a ships 10 `type_disguise "none"` actors, m6l1c 29, **m6l2a zero** — and 40 saluters out of 44
disguise-keyed actors. Every checker on this map is one we retyped at init.

---

## 2. Hypotheses this vetting pass KILLED

Recorded because they were stated confidently and were wrong. Both would have produced engine changes
that fixed nothing.

### 2.1 "Holding a weapon blows your cover globally, to every actor" — FALSE

`Actor::EnemyIsDisguised()` (`actor.h:2163`) is an **OR**:

```c
if (!m_bEnemyIsDisguised && !m_Enemy->m_bIsDisguised) return false;
```

and `m_bEnemyIsDisguised` is computed at `actor.cpp:6946` as

```c
m_bEnemyIsDisguised = m_Enemy->m_bHasDisguise && (m_Enemy->m_bIsDisguised || !CanSeeEnemy(0));
```

so an actor **with no line of sight still treats the player as disguised** even when the global flag
is false. The engine already carries a witness term. Drawing a weapon does not, by itself, reveal you
to anyone who cannot see you.

### 2.1b Consequence: "pillar 1" as originally written is void

The first plan named as pillar 1: *"cover must be lost by being observed, not by inventory state —
today it's one line: weapon in hand -> not disguised, globally, instantly."* That premise is false,
per 2.1. The engine **already** loses cover by observation. There is no pillar-1 engine work; what
looked like it was 1.1, a missing `quiet` flag in our own weapon data.

### 2.2 "type_disguise \"none\" makes an actor see through the disguise" — FALSE

`PassesTransitionConditions_Attack` (`actor.cpp:9026`) returns false whenever `EnemyIsDisguised()`,
engine-wide and regardless of type. **No `type_disguise` value makes an actor attack a disguised
player.** `none` means: never enters the disguise think, so never salutes and never challenges — and
in *our* script it counts as an eligible witness in `bust.scr`. That is all it means.

---

## 3. Remaining engine work — scoped

All of it behind **one cvar, `g_coopStealthNative`, default `0`**, set by m6l2a at init. On every
other map the new branches are **unreachable**, not merely unused — which is the entire safety story.
Precedent exists in the exact function involved: the disguise block already hides behind
`g_coopDisgParity` (`player.cpp:5529`).

| # | change | file | risk |
|---|---|---|---|
| E1 | SP-parity gunfire radius (1500) instead of up to 8000 | `weapon.cpp:2164` | low — restores the value the game shipped with |
| E2 | Restore the prior think on exit from the disguise think | `actor_disguise_common.cpp` | medium — touches shared state machine |
| E3 | Alarm latch: once `level.m_bAlarm` has been true, keep the disguise dead for the mission | `player.cpp:5535` | low |

**Do these one at a time, testing between**, because 1.1 alone may resolve most of the observed
behaviour and we will not know which change bought what if they land together.

`fgame` only, so `game.dll` ships alone — no exe/cgame version coupling.

---

## 4. Verification

- **Regression gate:** the m2l2a acceptance run. It passed clean earlier (zero SALATK/latch restores
  against 1789 in the broken run), which makes it a measured baseline rather than a hope.
- **m6l1c** second, since it is the other live disguise map.
- Every engine change must be shown to be a **no-op with the cvar off**, by reading the branch, not by
  observing that nothing appeared to change.

---

## 5. Script-side items still open on m6l2a

Not engine, listed so they are not confused with it:

- The officer nearest radio 3 ignores the distraction when he is mid-papers-challenge —
  `coop_m6l2aRadioFind` picks him, but he cannot walk.
- Objective 1 displayed as the bomb plant despite `OBJDUMP` proving slot 1 holds the schedule; now
  side-stepped by hiding the charges until the gate opens, root cause still unexplained.
- Cutscene camera at `(-2838 -792 279)` still needs a look-at target.

---

## 6. Comparative trace — m2l2a, m6l1c, m1l2a (2026-08-12)

Three independent read-only passes. The headline is that **m2l2a is the wrong reference for m6l2a**
and m6l1c is the right one, because the two maps differ on whether stealth is a *choice*.

### 6.1 Which maps even have disguises

`level.coop_enableDisguises` is set in exactly three map scripts: `e1l4.scr:23`, `m2l2a.scr:27`,
`m2l2b.scr:15`. Nothing else can reach the disguise think, because `m_bHasDisguise` is written only by
`giveDisguiseToAll` (`itemhandler.scr:994/:1040`) behind that flag.

**m1l2a is NOT a disguise map.** Its ~41 "papers" references are `level.flags[papers]`, script
bookkeeping for the OSS documents objective — a different namespace from the engine's `level.papers`
(`Level::m_iPapersLevel`). A word-count grep said otherwise and was wrong.

### 6.2 The witness asymmetry — the single most useful measurement

Evaluating the witness predicates against each map's full actor list, with disguises live:

| map | stealth | eligible witnesses during a contain |
|---|---|---:|
| m2l2a | **mandatory**, flags set at map load (`:69-73`) | **0** |
| m6l1c | **opt-in** at a cache | ~33 (29 `type_disguise "none"` + 4 machinegunners) |
| m6l2a | **opt-in** at a cache | 44 -> **~40** after 2026-08-12 |

m2l2a can afford zero because it never offers a choice: the whole mission is the stealth run and the
difficulty lives in the isolating, not the act. m6l1c shares m6l2a's opt-in design and *does* have real
witnesses. m6l2a ships **zero** `none` actors, so the pool had to be bought via
`level.coop_bustWitnessAll` rather than inherited — a deliberate trade to keep all 40 salutes, which
are what make the map feel inhabited. Excluding officer/sentry/rover from the narrow predicate
(`bust.scr::coop_bustCanWitness`) aligns it with m6l1c, since those roles are structurally busy running
the disguise think and m6l1c's wide predicate blinds them.

### 6.3 The think model — why E2 was cancelled

The engine keeps **two independent layers**:

* `m_ThinkStates[level] -> state` — the current MODE (idle / attack / disguise), written by `SetThinkState`
* `m_ThinkMap[state] -> think` — the POLICY, i.e. what IDLE *means* for this actor, written by
  `SetThinkIdle` from `type_idle`, `patrolpath`, `runto` (`THINK_RUNNER`) and `anim_scripted` (`THINK_ANIM`)

`SetThinkState(THINKSTATE_IDLE, THINKLEVEL_IDLE)` at every disguise exit resets only the MODE.
`ThinkStateTransitions` (`actor.cpp:8677-8725`) then sees the policy differs from the current think and
runs `EndState` + `BeginState` on the **authored** behaviour. **The actor resumes its own job for free.**
So "a disguise interaction permanently stops a patrol" (old finding 1.3) was wrong, E2 is unnecessary,
and `m6l2a.scr::coop_m6l2aPatrolWatchdog` is at best redundant.

Waits are safe too: while in the disguise think the anim-done callback is
`FinishedAnimation_DisguiseSalute`, so `waittill animdone` cannot fire falsely; on return `Begin_Anim`
replays the animation from the top, so animdone is **delayed, never lost**. `End_Runner` sets
`parm.movefail` without unregistering movedone, and `m_patrolCurrentNode` survives, so `waittill
movedone` always returns.

### 6.4 The retype landmine

`InitDisguiseNone` (`actor_disguise_common.cpp:65-68`) installs **only** `IsState` — no `BeginState`,
no `ThinkState`. An actor swapped to `type_disguise "none"` *while inside* the disguise think takes the
one exit path carrying no `SetThinkState` call and is **pinned in DISGUISE permanently**. That is
bug-1631's shape, and `itemhandler.scr:1266-1281` records the same demotion being DELETED from
`coop_paperPassAll` for exactly this reason.

`m6l2a.scr` retypes the two dogs to `"none"`. It runs at `waitTillPrespawn`, before any actor can be
mid-challenge, which is the safe window — but the rule is: **only ever retype `type_disguise` on an
actor provably not currently in `THINKSTATE_DISGUISE`.**

### 6.5 Other structural differences worth carrying

* **m2l2a grants papers BEFORE the uniform** (`:1067-1068`) and its inventory calls the order
  load-bearing, since `add_item "uniform"` fires `giveDisguiseToAll` which reads state. m6l1c does the
  reverse and works. Unresolved; note it before touching either.
* **Per-actor `disguise_range` tuning has retail precedent** — one m2l2a officer ships with `64`
  rather than 256, so m6l2a's `disguise_range 1` silent-officer trick is in keeping with the data.
* **m2l2a declares 21 `level.coop_sceneActorNames`** (`:37-57`) protecting its conversations and work
  animations; m6l1c and m6l2a declare none.
* **`disable_ai` is a real disguise-immunity switch**, not just an enemy mute:
  `CheckForThinkStateTransition` short-circuits to IDLE when `!m_bEnableEnemy` (`actor.cpp:8920-8923`)
  and force-evicts an actor already in DISGUISE (`:8660-8666`). Bracket uninterruptible scenes with it,
  and always pair it with `enable_ai`.
* **Only `level.alarm` reaches `Level::m_bAlarm`.** Script-side names like `level.alarm_on` never do.
