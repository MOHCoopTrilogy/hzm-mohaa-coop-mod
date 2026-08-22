# Ragdoll round 9 — POST-DEATH IMPACTS

**Status:** design, not built. Read-only audit + patch shape.
**Date:** 2026-08-20
**Supersedes:** `ragdoll_r8_gap.md` §5 (its architecture is right; three of its specifics are
wrong against the current `cg_ragdoll.c` — see "Where r8 §5 is wrong" below).

---

## 0. The requirement, and what it forbids

> "my issue with freezing the body is I want to be able to shoot the body that is dead and it
> still has physics (arms, legs, torso, head can move around still)" — user, 2026-08-20

Two things follow, and they are architectural, not cosmetic:

1. **Sleep must be an interruptible resting state, never a retirement.** `state == 2` today is
   already interruptible (the mover-wake at `cg_ragdoll.c:1280-1293` proves the pattern works),
   but the `lifeMs > 6000` cap (`:1353`) must not be allowed to mean "this body is finished".
   It doesn't — as long as every wake path resets `lifeMs`, which the mover-wake already does
   at `:1285`.
2. **The shape-match must yield locally, temporarily, and per-limb.** This is the whole
   difference between a *twitch* and a *movement*, and it is the part r8 §5 got wrong. See §4.3.

---

## 1. SIGNAL AUDIT — what actually reaches cgame when a corpse is hit

Every candidate, verified in the engine. **Verdict column is the answer to "can this drive a
ragdoll impulse today".**

| # | Candidate | Payload that reaches cgame | Evidence | Verdict |
|---|---|---|---|---|
| a | **Server moves the corpse** (difference the origin like `RagMoverHash`) — **BULLETS** | nothing — a bullet never changes the origin | `actor.cpp:12503`/`:12520` set `MOVETYPE_NONE`; `g_phys.cpp:1466-1474` makes `MOVETYPE_NONE` a bare `break` — physics never runs, `velocity` is inert | **DEAD for bullets** |
| a1 | Same, **EXPLOSIONS** — `g_corpseImpulse` | the origin **does** move: `RadiusDamage` flips a settled corpse back to `MOVETYPE_TOSS` and adds blast velocity | **two independent blocks**: `weaputils.cpp:3403-3421` (`ent->health <= 0` → `setMoveType(MOVETYPE_TOSS)`, `velocity += vImp * 350*fScale*fCI`, `:3417-3419`) **and** `weaputils.cpp:3507-3530` (`deadflag == DEAD_DEAD` → `MOVETYPE_TOSS`, `velocity += vPush*300*fFrac`, `velocity.z += 210*fFrac`, `:3527-3529`) | **ALIVE — and it creates a defect the ragdoll must handle. See §6.4** |
| a2 | `Sentient::CoopGoreDeathKinetics` (`sentient.cpp:2622`) — the mod's own corpse shove | `velocity += vDir*fPush + z` (`:2649`) | call site `sentient.cpp:1743-1744` is gated `fCoopPrevHealth > 0 && health <= 0` = **the killing blow only**. A corpse is already at `health <= 0`, so it can never re-enter. (Note `coop_corpseImpulse` at `:2629` governs *only* this pre-park death edge — it is a **different cvar with a disjoint scope** from `g_corpseImpulse` in row a1. Do not confuse them.) | **DEAD** (but see §4.4 — its *magnitudes* are the calibration source) |
| b1 | `CGM_BULLET_1 / _2` — tracer, every single-bullet shot | `vBarrel`, `vStart`, `vEndArray[0]` (= the server's own trace endpoint), `iLarge` (2 bits), alpha | parse `cg_parsemsg.cpp:1691-1731`; emit `weaputils.cpp:2789-2812`; endpoint written `weaputils.cpp:2758` `VectorCopy(vTmpEnd, vEndArray[i])` | **USABLE** — but fires on *every* shot, hit or miss |
| b2 | `CGM_BULLET_3 / _4` — multi-pellet volley | `vStart` + `iCount` × `vEndArray[i]` | `cg_parsemsg.cpp:1732-1767` | **USABLE** (shotguns) |
| b3 | **`CGM_BULLET_8 / _9` — FLESH IMPACT** | `vStart` = **bone-accurate impact position**, `vEnd` = surface normal **already negated to point into the body** (`:1802`), `iLarge` | parse `cg_parsemsg.cpp:1799-1818`; emit `weaputils.cpp:2606-2627` | **BEST — this is the one** |
| c | Blood/gore FX on a corpse hit | `CG_AddBulletImpacts` (`cg_parsemsg.cpp:1122`), flesh branch `:1306-1398`, consumes `flesh_impact_pos[]` / `flesh_impact_norm[]` — i.e. the b3 payload | same | already knows point + normal; hooking b3 gets the same data one step earlier |
| d1 | Explosions | `CGM_EXPLOSION_EFFECT_1..4` → **origin + a 4-value type discriminant. No radius, no magnitude** | parse `cg_parsemsg.cpp:1851-1859`; handler `CG_MakeExplosionEffect` `:1402` | **USABLE** with a client-side type→radius table |
| d2 | Tinnitus / dizziness (the existing blast-reaction system) | a bare scalar `0..1` closeness. **No position, no radius** | `weaputils.cpp:3335-3377` sets script var `coop_blastPing`; `cg_view.c:91-96,160-168` reads the stuffed `coop_dizzy` cvar | **DEAD** for this purpose |
| e | `CG_EntityEvent` / `EV_*` / `TE_*` | — | `cg_event.c:36` is `void CG_EntityEvent(centity_t *cent, vec3_t position) {}` — **an empty stub, zero `EV_` cases.** MOHAA replaced the Q3 entity-event machinery with CGM | **DOES NOT EXIST** |
| f | A **new** CGM message carrying entnum + `trace.location` + damage | everything, exactly | headroom exists: type field is 6 bits (`cg_parsemsg.cpp:1688`), highest used is `CGM_FENCEPOST = 41` (`bg_public.h:792`) → 42-63 free | **NOT NEEDED** — see §2.2 |

### 1.1 Do bullets actually hit a corpse? Yes, and bone-accurately.

Three facts chain together, and the third is the one r8 missed:

1. `Actor::BecomeCorpse` (`actor.cpp:12486-12498`) flattens the box to
   `(-32,-32,0)..(32,32,16)` and sets `CONTENTS_WEAPONCLIP` + `SOLID_BBOX` when
   `coop_corpseShootable 1` (default, `:12489`).
2. `CONTENTS_WEAPONCLIP` **is** in `MASK_SHOT` (`bg_public.h:648-650`) — so the bullet trace
   stops on the corpse. (It is deliberately *not* in `MASK_PLAYERSOLID`/`MASK_MONSTERSOLID`, so
   the corpse is not a body-block; nor is it in `MASK_DEADSOLID` (`:643`), which is why the
   ragdoll's own point collision does not collide with other corpse slabs.)
3. **The bullet trace is a DEEP trace.** `weaputils.cpp:2437-2439`:
   ```c
   trace = G_Trace(vTraceStart, vec_zero, vec_zero, vTraceEnd, newowner,
                   MASK_SHOT_TRIG, false, "BulletAttack", true);
   //                                                      ^^^^ traceDeep
   ```
   and `sv_world.c:582-590`:
   ```c
   if (clip->traceDeep && touch->tiki != NULL && touch->tiki->a->bIsCharacter) {
       SV_TraceDeep(&trace, clip->start, clip->end, clip->contentmask, touch);
   }
   ```
   A corpse is still an `Actor` with a character tiki, so it takes the **per-bone** path, not
   the flat-slab path. `trace.location` therefore comes back `>= 0`.

That matters because the flesh-message gate at `weaputils.cpp:2606` is exactly
`else if (trace.location >= 0 && ent->IsSubclassOfSentient())`. Both halves hold for a corpse.
**So `CGM_BULLET_8` fires on corpse hits, and its position is the bone the bullet actually
struck.**

### 1.2 ⚠ The FX message fires even though the *damage* does not — and that is what saves us

`BecomeCorpse`'s own comment (`actor.cpp:12474-12480`) claims post-death damage runs:

> "All models should be susceptible to complete annihilation by shooting them even if dead."
> ... `Sentient::Damage` has no `deadflag` early-out (vanilla's is commented out) ... the
> accumulate path still runs ...

**That comment is stale and half wrong.** `Sentient::ArmorDamage` — the `EV_Damage` handler
(registered `sentient.cpp:699`; `Actor` does not override it) — early-outs at
**`sentient.cpp:1517-1519`**:

```c
if (IsDead()) {
    return;
}
```

`IsDead()` is `deadflag != DEAD_NO` (`entity.cpp:6251-6254`) and `Actor::HandleKilled` sets
`deadflag = DEAD_DEAD` (`actor.cpp:5451`). The commented-out vanilla block the comment refers to
is a *different* one further down (`sentient.cpp:1606-1639`). The `takedamage` half of the claim
is correct (`DAMAGE_AIM` is never cleared on death, `actor.cpp:2929`); the "accumulate path still
runs" half is false. **Every gore, kinetics and prop path on a corpse hit is dead code today.**

**But the FX broadcast is not behind that gate.** In `BulletAttack` the block that emits
`CGM_BULLET_8` sits **outside** `if (ent->takedamage)` — verified by brace structure at
`weaputils.cpp:2552-2596`:

```c
if (ent && ent != world && ent != owner) {
    if (ent->takedamage) {
        ...
        ent->Damage(...);          // -> ArmorDamage -> IsDead() -> return. Dead end.
    }                              // <-- takedamage block CLOSES here

    if (ent->edict->solid == SOLID_BBOX && !(trace.contents & CONTENTS_CLAYPIDGEON)) {
        ...                        // <-- CGM_BULLET_6 / _8 / _7 emitted HERE, ungated
```

A `coop_corpseShootable 1` corpse is `SOLID_BBOX`, so it satisfies the outer test.
**`CGM_BULLET_8` therefore fires on a corpse hit even though the damage event is discarded.**

This is the load-bearing fact of the whole design: the one server→client message that already
reaches all relevant clients on a corpse hit, carrying impact position and direction, survives
the `IsDead()` gate. Nothing else on the corpse-hit path does.

**Net today: a bullet into a corpse costs a deep bone trace, dispatches an `EV_Damage` that is
thrown away, and broadcasts a flesh-impact FX message. The body does not move a millimetre —
and, contrary to r8 §5, its gore skin does not re-tier either.**

> ⚠ **Verify before building.** The `trace.location >= 0` chain above is read from source, not
> observed. There is a ready-made probe: `coop_bloodDebug 1` prints
> `^~^~^ FLESHHIT dist=%.0f loc=%d pos=(...)` at `weaputils.cpp:2612-2618` whenever a *player*
> lands a flesh hit. Set it, shoot a corpse, and confirm `FLESHHIT` prints with `loc >= 0`.
> Two minutes, and it de-risks the whole primary signal. **If it does not print, fall back to
> `CGM_BULLET_1/_2` (row b1) — same function, wider radius, one extra false-positive class.**

---

## 2. RECOMMENDATION

### 2.1 Signal: `CGM_BULLET_8` / `CGM_BULLET_9` (flesh) primary, `CGM_EXPLOSION_EFFECT_1..4` for blasts

**Ship unit: `cgame.dll` ALONE.** No `game.dll`, no `openmohaa.exe`, no protocol constant, no
new wire field. Nothing in `fgame/`, `qcommon/`, `server/` or `client/` is touched.

Why this one and not the tracer message:

- It fires **only when a Sentient bone was actually hit** — so a round that whistles past a
  corpse and buries itself in the wall behind never shakes the body. With the tracer message
  you must discriminate hit-from-miss yourself, using nothing but "did the endpoint land near
  a corpse", which false-positives on every wall directly behind a body.
- Its position is bone-accurate (§1.1), so a shot to the arm impulses the arm.
- Its `vEnd` is **already negated to point into the body** at `cg_parsemsg.cpp:1802` — the
  impulse direction is free, no arithmetic.
- It is broadcast to everyone who can see either the impact *or the muzzle*
  (`weaputils.cpp:2621` is preceded by `gi.SetBroadcastVisible(vTmpEnd, vBarrel)` — a coop fix
  in its own right), so **other players' shots move the body on your screen too, in stage 1**,
  with no extra work. The r8 plan treated "other players' shots" as a later stage; it is not,
  it comes free with this signal.

### 2.2 Why NOT a new protocol event

A new CGM type is *technically* cheap and there is headroom (42-63 free). It is still the wrong
call:

- **Ship cost.** A protocol constant means `openmohaa.exe` + `cgame.dll` + `game.dll` must ship
  in lockstep, forever, for every user. Precedents in `.wolf/buglog.json`: **bug-1864**
  (`MAX_GAMESTATE_CHARS` + `MAX_MSGLEN` raised in lockstep), **bug-1187** (`frameInfo` index
  widened 12→13 bits in `entityStateFields_ver_15` only), **bug-1198** (`SOUND_INDEX_BITS` —
  "not a protocol change, *but* `SOUND_INDEX_BITS` itself is protocol"). Every one of those cost
  a session and a coupled-binary hazard note.
- **Legacy protocol.** `BG_MapCGMToProtocol` (`bg_misc.cpp:392`) passes anything `> 40`
  through untranslated, but `CG_ParseCGMessage_ver_6` `ERR_DROP`s on an unknown type
  (`cg_parsemsg.cpp:2455`, `:2109`) — so emission would have to be gated on `g_protocol`, and
  an old client that missed the gate gets *dropped from the server*, not degraded.
- **It buys almost nothing.** The one thing a new message adds is the **entity number**. We do
  not need it: cgame already holds the 15 world points of every live sim, so **an impact
  position IS the routing key** — spatial routing, exactly how `RagMoverHash`
  (`cg_ragdoll.c:955-977`) already routes bmodels to bodies. Worst case two overlapping corpses
  both react to one grenade, which is correct anyway.

> A counter-analysis during this audit concluded "a new protocol event IS needed, because the
> hit entity is never transmitted". That is true about the payload and wrong about the
> requirement: `RagSimFor(entnum)` is not the only way to find a body when you are already
> holding its geometry.

**Deferred, not rejected:** if a future round wants true limb-*specific* server semantics
(`trace.location` → "the left forearm was hit", damage-scaled force, server-authoritative
knockback shared across clients), the insertion point is `weaputils.cpp:2606-2627`, where `ent`,
`trace.location`, `dir`, `knockback` and `newdamage` are **all in scope and all thrown away**.
That is a genuinely clean future hook. It is just not worth the trilogy ship for round 9.

---

## 3. Where `ragdoll_r8_gap.md` §5 is wrong

r8 §5 is directionally correct and its line numbers are stale. Three of its specifics would
cause live defects if implemented as written:

| r8 §5 said | Reality in the current file | Consequence |
|---|---|---|
| "Drop the shape-match for the rest of this body's life (`s->branch = 0`)" | `branch` also selects the **startsolid policy** in `RagCollideWorld` (`:1006-1020`). On the settle branch a point stuck in geometry is *released* so the pose attractor pulls it out; on the free branch it is **frozen in place**, anchoring the body and tearing the rest around it | Re-introduces the documented "corpse clipped into a wall got kinda mangled" defect (comment `:1008-1013`). Also permanently converts the corpse to free Verlet = the bead-chain pile of finding `:117` |
| "The existing per-substep velocity clamp (24 u/substep = 3000 u/s) is the blowup backstop" | The clamp is now **8.0 u/substep = 1000 u/s** (`:860-865`), lowered precisely because 3000 "let a launch build before the NaN ladder could catch it" | Any magnitude budgeted against 3000 u/s is 3× over the real ceiling |
| "`RagSane` (`:870`) is the ladder below that" | `RagSane` (`:1078-1100`) now also fails on a **200 u span on any axis** (`:1094-1098`), which reverts the body to the anim pose outright | A single-point impulse that stretches the skeleton past 200 u makes the corpse *snap back to its death pose* — the opposite of the requirement. Mitigated by radius-falloff (§4.2), not by luck |

r8 §5's line citations into `cg_ragdoll.c` (`:1052`, `:941-948`, `:672-674`, `:870`, `:181-187`)
all predate the round-8/9 edits. **Use the line numbers in this document.**

---

## 4. THE IMPULSE MODEL

### 4.1 The Verlet arithmetic (exact)

`RagStep` (`cg_ragdoll.c:854-870`) carries velocity implicitly:

```c
VectorSubtract(s->pt[i], s->ptPrev[i], vel);   // <-- units per SUBSTEP, not per second
VectorScale(vel, RAG_DAMPING, vel);            // 0.98
if (vlen > 8.0f) VectorScale(vel, 8.0f/vlen, vel);
VectorCopy(s->pt[i], s->ptPrev[i]);
VectorAdd(s->pt[i], vel, next);
next[2] -= g;
```

So the state variable is `(pt - ptPrev)` in **units per substep**. To inject a world velocity
`v` (u/s) along unit direction `n`:

```
    dt        = RAG_SUBSTEP_MS / 1000  = 0.008 s          (:58)
    want      = (pt - ptPrev) + v * dt * n
    therefore   ptPrev -= v * dt * n
```

```c
VectorMA(s->ptPrev[i], -(v * (RAG_SUBSTEP_MS * 0.001f)), n, s->ptPrev[i]);
```

**Move `ptPrev`, never `pt`.** Moving `pt` teleports the point without giving it velocity;
moving `ptPrev` gives it velocity without teleporting it. (This is the exact inverse of the
`RagShapeMatch` bug fixed at `:840-845`, where moving `pt` alone injected
`(a*|d|)/dt` of spurious speed every substep and blew bodies across the map.)

**Headroom check.** The clamp at `:860-865` is `8.0 u/substep = 8/0.008 = 1000 u/s`. Every
magnitude below is ≤ 460 u/s, so **no impulse in this design is ever silently clamped** — the
clamp stays a pure blowup backstop. Keep it that way: if a future tuning pass wants > 1000 u/s,
raise the clamp deliberately, do not let it eat the impulse.

**Decay check.** `RAG_DAMPING 0.98` per substep. Over 600 ms = 75 substeps, `0.98^75 = 0.22`.
A 200 u/s kick has decayed to ~44 u/s by the time the limp window closes — the body settles on
its own, without any special-case braking.

### 4.2 Which points receive it — radius falloff, not nearest-point

r8 §5 proposed nearest-point. Prefer **all points inside a radius, with linear falloff**, for a
concrete stability reason: a single point kicked hard stretches its distance links, and
`RagSane`'s 200 u span test (`:1094-1098`) reverts the whole body to the death pose if the
stretch wins. Spreading the impulse over the neighbours keeps the links near rest length and
turns the kick into limb *rotation* about the joint — which is also what looks right.

```c
for (i = 0; i < RAG_PTS; i++) {
    VectorSubtract(s->pt[i], pos, d);
    dist = VectorLength(d);
    if (dist >= radius) continue;
    k = 1.0f - (dist / radius);          // 1 at the impact, 0 at the rim
    v = force * k;
    VectorMA(s->ptPrev[i], -(v * SUBDT), n, s->ptPrev[i]);
    s->limpMs[i] = limpMs;               // see 4.3
}
```

**Radius for bullets: 30 u.** Not the 24 r8 suggested. The impact position is the *server's*
bone pose, while the rendered points are the *client's* draped pose, and the file's own
instrumentation measures that gap as `drift` — "~0 on flat ground, 5-20 u draped on geometry"
(`:1367-1379`). A 24 u radius can miss a draped limb outright; 30 absorbs the documented drift.
This is safe *because* the flesh message already told us something fleshy was hit — the radius
is choosing *which limb*, not deciding *whether* to react.

**Selecting the limb by ray instead of by point (optional refinement).** If the corpse's drape
has moved the struck limb further than 30 u, the fallback that keeps the beat correct is to
score points by distance to the bullet *segment* (`vStart` of the tracer → `pos`, extended ~32 u
past `pos`) rather than to `pos` alone, and impulse the best-scoring point plus its radius
neighbours. 15 point-to-segment tests, no traces. Worth doing only if playtest shows misses.

### 4.3 The shape-match interaction — this is the requirement

Leaving `RagShapeMatch` (`:820-847`) at full strength makes the impulse invisible. The
arithmetic: on the settle branch `alpha` relaxes to `rag_stiff->value` (default **0.25**,
`:288`) and is applied **per substep**, so per frame (4 substeps, `:1308`) the limb is reeled
`1 - 0.75^4 = 68%` of the way home. **The limb snaps back inside two frames. That is a twitch,
and the user explicitly rejected it.**

Fix: a **per-point, time-limited relaxation**, mirroring the shape of the existing
`contact[]` / `RAG_CONTACT_RELAX` mechanism at `:836-838` (which already yields the shape-match
where the body touches the world). New field, new constant, same idiom:

```c
// ragSim_s, next to contact[] at :196
short limpMs[RAG_PTS];   // >0 = recently struck: the shape-match yields here (30 bytes)
```

```c
// cg_ragdoll.c near :64
#define RAG_IMPACT_RELAX   0.05f   // struck limbs keep 5% of the pose pull at the instant of impact
#define RAG_IMPACT_LIMP_MS 600     // ... easing back to full over this long
```

In `RagShapeMatch`, immediately after the existing `contact[]` relax:

```c
if (s->contact[i]) {
    a *= RAG_CONTACT_RELAX;
}
if (s->limpMs[i] > 0) {
    /* k: 0 at the moment of impact -> 1 as the window expires. Ease the pose pull back in
       instead of restoring it in one step, or the limb visibly snaps home at the deadline. */
    float k = 1.0f - (float)s->limpMs[i] / (float)RAG_IMPACT_LIMP_MS;
    a *= RAG_IMPACT_RELAX + (1.0f - RAG_IMPACT_RELAX) * k;
}
```

and decrement once per substep in `RagStep`, alongside the existing per-substep bookkeeping:

```c
for (i = 0; i < RAG_PTS; i++) {
    if (s->limpMs[i] > 0) {
        s->limpMs[i] -= RAG_SUBSTEP_MS;
        if (s->limpMs[i] < 0) s->limpMs[i] = 0;
    }
}
```

**What this buys, in numbers.** At the instant of impact the struck limb's effective alpha is
`0.25 * 0.05 = 0.0125` per substep ≈ 5% per frame — the limb is essentially free and travels on
its injected velocity. By 600 ms it is back to the full 0.25 and the corpse has re-settled into
the animator's silhouette. **Visible movement, then a clean settle, with no permanent change to
the body's character.**

This is strictly better than r8's `s->branch = 0` because it is (i) local to the struck limb,
(ii) temporary, and (iii) **leaves `branch` alone**, so the settle branch's startsolid-release
policy (`:1016-1018`) stays in force and the wall-mangle defect is not re-opened. See §3.

### 4.4 Magnitudes — calibrated against the mod's own corpse shove

Do not invent these. `Sentient::CoopGoreDeathKinetics` (`sentient.cpp:2634-2650`) is the mod's
already-tuned answer to "how hard does a body get shoved", and matching it keeps a shot corpse
feeling like a freshly killed one:

```c
float fPush = fDamage * 3.2f;
if (fPush > 340.0f) fPush = 340.0f;
if (fPush <  90.0f) fPush =  90.0f;
if (bBoom) fPush *= 1.35f;                                  // -> 459 max
velocity += vDir * fPush + Vector(0, 0, bBoom ? 130.0f : 55.0f);
```

So the mod's own band is **90-340 u/s for bullets, up to 459 u/s for explosive**, with a
**+55 / +130 u/s upward bias**. Client-side we do not have `damage`, but we have `iLarge`
(2 bits, the bullet size class) — use it as the scalar:

| Event | force (u/s) | radius (u) | z-bias | limp (ms) | note |
|---|---:|---:|---:|---:|---|
| Bullet, `iLarge 0` (pistol/rifle) | **90** | 30 | +20 | 600 | the floor of the mod's own band |
| Bullet, `iLarge 1` | 145 | 30 | +20 | 600 | `90 + 55*iLarge` |
| Bullet, `iLarge 2` | 200 | 32 | +20 | 700 | |
| Bullet, `iLarge 3` (heavy/MG) | 255 | 34 | +25 | 800 | |
| Grenade `CGM_EXPLOSION_EFFECT_1` | 400 | **180** | +130 | 1200 | |
| Bazooka/'schreck `_2` | 430 | 220 | +130 | 1200 | |
| Heavy shell `_3` | 460 | 300 | +140 | 1400 | at the mod's own 459 ceiling |
| Tank `_4` | 460 | 340 | +140 | 1400 | |

Explosion radii mirror the mod's existing client-side blast constants, which already guess a
radius because none crosses the wire: `coop_heatRadius` default **700**
(`cg_parsemsg.cpp:1413-1425`) and `coop_explLight` default **420** (`:1427-1435`). Ours are
tighter on purpose — a body should be thrown only when the blast is genuinely close.

**Expected observable at 90 u/s.** Ignoring constraints, a 90 u/s kick under `0.98` damping
travels `v*dt*(1-0.98^75)/0.02 ≈ 28 u` over the limp window. The distance links (6 iterations,
`:871-884`) convert most of that into rotation about the joint rather than translation, so the
real figure is roughly **4-10 u of limb travel** — on a hand 25 u from its elbow, a swing of
~10-23°. Clearly visible, not comical. **Start at 90 and let the playtester move it.**

### 4.5 Direction

- **Bullets:** the negated plane normal that `cg_parsemsg.cpp:1802` has already computed —
  it points *into* the body. Free.
  ⚠ It is byte-quantized (`MSG_ReadDir` → `ByteToDir`, `msg.cpp:653-658`), so it is coarse.
  Coarse is fine for an impulse.
- **Explosions:** `normalize(pt[i] - blastOrigin)` per point, then add the z-bias **before**
  normalizing, so bodies are thrown up and outward rather than skidded sideways:
  ```c
  VectorSubtract(s->pt[i], pos, n);
  n[2] += zbias * 0.01f;   /* bias in the same u/s units as force, scaled to the unit dir */
  VectorNormalize(n);
  ```
- Positions arrive at 1/16 u resolution (`MSG_ReadCoord`, `msg.cpp:660-669`). Irrelevant here.

---

## 5. WAKE AND RE-SLEEP LIFECYCLE

### 5.1 Waking (state 2 → 1)

Copy the mover-wake recipe verbatim (`cg_ragdoll.c:1280-1293`) — it is proven and it already
handles the life cap correctly:

```c
s->state   = 1;
s->sleepMs = 0;
s->lifeMs  = 0;   /* CRITICAL: a fresh 6 s window. Without this a body slept via the
                     lifeMs > 6000 cap (:1353) re-sleeps on the very next frame. */
s->accumMs = 0;
```

**This is the whole answer to "a corpse shot 30 seconds after death must still react."** The
6 s cap at `:1353` is a *per-wake* budget, not a retirement — the mover-wake has relied on that
reading since P3, and the impulse path inherits it. Nothing about the cap needs to change.

### 5.2 The rotation lock — **must be released, and must be allowed to re-latch**

`s->rotLocked` (`:201`) latches at `:796-798` once three points are in world contact, and
`RagBodyRotation` then holds `bodyRot` frozen (`a = 0.0f`, `:800`). It is **never cleared except
by `memset`**.

If a woken body keeps `rotLocked`, `RagShapeMatch` rotates its goal by a **stale** orientation
anchored to `pt[0]`. A body rolled over by a grenade would then be fought by a shape-match
pulling toward the orientation it had *before* the blast — the exact "mangled" failure mode.

```c
s->rotLocked = 0;   /* released on every impulse-wake */
```

Do **not** also clear `bodyRotValid` — leaving it set means `RagBodyRotation` *slews* from the
current estimate at `a = 0.12` (`:800`) rather than snapping to a fresh fit, which is what keeps
the precession feedback loop (`:781-786`, the "slow spin" that stopped every body sleeping)
from re-opening. The lock then re-latches by its own `nContact >= 3` rule within about a second
of the body coming to rest. **Released while moving, locked while resting — which is what the
lock was always for.**

### 5.3 Bodies that cannot react — confirm graceful, confirm no crash

All four cases are no-ops today, and the impulse function must keep them that way:

| Case | State | Behaviour |
|---|---|---|
| **Evicted from the 8-slot pool** | `RagAllocSlot` (`:1421-1427`) evicted it → `CG_RagdollClearEnt` → `memset(s)` + `cgi.R_ClearRagdoll(entnum)` | `active == 0`, the loop skips it. The entity renders its normal server anim pose = **vanilla**. Nothing happens, nothing crashes |
| **Never armed** (`coop_ragdoll 0`, capture failed, buried `:603`, `s_ragNeverArm` `:1410`) | no sim exists | loop finds nothing. Vanilla |
| **Pending seed** (`state == 0`) | points exist but `CG_RagdollTransition` is about to overwrite `ptPrev` wholesale (`:1644`) | **must skip** — an impulse here is silently discarded by the seed, so skipping is honest rather than misleading |
| **Pending record** (`s_ragPend`) | authored death anim still playing; **no points at all** — the record is 32 B, outside the sim pool (`:210-219`) | different array, never iterated. Vanilla |

Two guards beyond r8's list:

```c
if (!s->active || s->state == 0 || s->freezePose) continue;   /* freezePose = test drill :205 */
if (!cg_entities[s->entnum].currentValid) continue;           /* corpse despawned - see §6.2 */
```

The `currentValid` guard is new. Without it, a sim whose entity was removed by the corpse
despawn keeps its pool slot and would be woken by a nearby explosion, burning traces to animate
a body nobody can see.

---

## 6. CORPSE PERSISTENCE AND GORE INTERACTION

### 6.1 Gore tiers do NOT clear the ragdoll — verified twice over

This was the live risk (a `modelindex` change clears our renderer override *by design*, at
`cg_ragdoll.c:1623-1626`). **It cannot fire, for two independent reasons.**

**Reason 1 — it never runs on a corpse at all.** Every gore-tier entry point lives downstream of
the `if (IsDead()) return;` gate at `sentient.cpp:1517` (§1.2): `CoopGoreUpdateSkinTier` is
called from `sentient.cpp:1693` and `:1785`, `CoopGoreTryGibSkins` from `:1790`,
`CoopGoreDisfigureHead` from `:1737` — all inside `ArmorDamage`, all past the gate. The terminal
lock at `sentient.cpp:2370-2375` (`if (m_iCoopGoreSkinTier >= 3) return;`), written expressly so
post-death hits could not re-tier a gibbed corpse downward, is currently unreachable code.

**Reason 2 — even if it ran, it is the wrong netfield.** `Sentient::CoopGoreUpdateSkinTier`
(`sentient.cpp:2353`) writes the tier into `edict->s.surfaces[i]`:

```c
edict->s.surfaces[i] =
    (edict->s.surfaces[i] & ~(MDL_SURFACE_SKINOFFSET_BIT0 | MDL_SURFACE_SKINOFFSET_BIT1)) | tier;
```

`surfaces[]` is a **separate netfield from `modelindex`**. The clear-signal set at `:1623-1624`
tests `EF_DEAD` falling edge, `EF_TELEPORT_BIT` toggle, `modelindex` change and `eType` change —
**none of which a gore tier touches.** Same for the terminal gib tier
(`sentient.cpp:3001-3007`, sets both skin bits → skin index 3) and the headshot head-gore
exemption (`sentient.cpp:2455-2462`).

`surfaces[]` is a **separate netfield from `modelindex`**, and the clear-signal set at
`:1623-1624` tests only `EF_DEAD` falling edge, `EF_TELEPORT_BIT` toggle, `modelindex` and
`eType`. **Even a working gore re-tier could not clear a ragdoll.**

**Net: the ragdoll impulse and the gore system cannot interfere with each other in either
direction.** One owns `surfaces[]`, the other owns the bone cache, and today only one of them
runs at all.

> **Adjacent defect, out of scope here:** the whole "shoot a corpse to pieces" feature
> (`actor.cpp:12474`, user standing rule, bug-1321) is silently dead behind
> `sentient.cpp:1517`. Shooting a corpse produces blood FX and nothing else — no tier flip, no
> gib skins, no chunks. If that is meant to work, it is its own fix (a `deadflag`-aware branch
> in `ArmorDamage` that runs the accumulate/gore paths but skips health, pain and AI reaction),
> and it is **independent of this design** — stage 1 needs nothing from the server.

> The one thing that *would* clear a ragdoll is a script or engine path that swaps the corpse's
> **model** (`setModel`). None exists on the post-death damage path. If one is ever added, the
> ragdoll drops to the anim pose cleanly — no crash, just a lost effect.

### 6.2 Corpse despawn (`coop_corpseLife`)

Lifetime is script-owned in coop — `Actor::BecomeCorpse` deliberately does **not** post
`EV_DeathSinkStart` outside single-player (`actor.cpp:12541-12546`), leaving it to
`coop_mod/corpse.scr` via `coop_corpseLife` (default **0 = keep forever**, per
`corpse_despawn` memory note).

- A **fade** is an alpha change — no clear signal, ragdoll unaffected.
- A **removal** drops the entity from the snapshot. The sim keeps its slot until it sleeps and
  is evicted by `RagAllocSlot` (`:1421-1427`). Pre-existing behaviour, harmless — but it is why
  the `currentValid` guard in §5.3 belongs in the impulse path.

### 6.3 The hitbox divergence — state it, accept it

The corpse's shot slab stays where the server parked it. A body shoved 20 u by a grenade
therefore keeps its bullet hitbox at the old origin. `RagPush` converts against
`cent->lerpOrigin` every frame (`:1119`, bug-1964's fix), so the *render* is correct; only the
*hitbox* lags. On an already-dead entity this is acceptable, and it is the standing price of a
client-side ragdoll.

**But bound it.** `RagSane` (`:1078-1100`) checks the skeleton's *span*, never its distance from
the entity origin — so nothing today stops repeated explosions walking a body arbitrarily far
from its own hitbox. Add a cheap leash in the impulse path:

```c
#define RAG_IMPACT_MAX_DRIFT 48.0f   /* how far the point cloud may wander from the server corpse */
```

Before applying, measure `|pt[0] - cent->lerpOrigin|`; if it already exceeds
`RAG_IMPACT_MAX_DRIFT`, scale the outward component of the impulse to zero (keep the inward and
vertical components, so a body can still be shaken and can still settle back). This is not in
r8 §5 and it is the difference between "a grenade jolts the bodies" and "grenades slowly sweep
corpses across the map away from their hitboxes."

### 6.4 ⚠ The server DOES toss corpses in a blast — and the ragdoll currently ignores it

This is the finding that neither r8 §5 nor the first pass of this document had, and it is a
**pre-existing latent defect** that the explosion stage would otherwise make obvious.

`RadiusDamage` flips a settled corpse **back to `MOVETYPE_TOSS`** and gives it blast velocity —
in two separate places, both gated on `g_corpseImpulse` (default `1.0`, `gamecvars.cpp:461`):

```c
// weaputils.cpp:3417-3419   (gate: ent->health <= 0)
ent->setMoveType(MOVETYPE_TOSS);
ent->edict->clipmask = MASK_SOLID;
ent->velocity += vImp * (350.0f * fScale * fCI);

// weaputils.cpp:3527-3529   (gate: deadflag == DEAD_DEAD && !IsSubclassOfPlayer())
pBody->setMoveType(MOVETYPE_TOSS);
pBody->velocity += vPush * (300.0f * fFrac * g_corpseImpulse->value);
pBody->velocity.z += 210.0f * fFrac * g_corpseImpulse->value;
```

So after a nearby grenade the corpse **entity origin genuinely moves**. Now look at what
`RagPush` does with it (`cg_ragdoll.c:1179-1185`):

```c
VectorSubtract(world, curOrigin, relw);
cap[0] = DotProduct(relw, axisNow[0]) * invScale;   /* ... */
```

The renderer then recomposes `curOrigin + axisNow * (cap*scale)` — which lands the bone back at
`world` **exactly**, whatever `curOrigin` is. That is correct and deliberate (bug-1964), but it
means the rendered skeleton is pinned to the *world sim points* and **does not follow the
entity**. A blast-tossed corpse therefore slides its hitbox, shadow and attachments out from
under a ragdoll that stays exactly where it was.

**Fix — a rigid carry term, ~8 lines, cgame-only.** Track the entity origin per sim and
translate the whole point cloud by any delta, moving `pt` **and** `ptPrev` together so the carry
adds *position* without injecting velocity (the same distinction as §4.1, inverted):

```c
// ragSim_s, next to entOrigin at :168
vec3_t lastEntOrigin;
byte   entOriginValid;
```

```c
// CG_RagdollFrame, per awake sim, BEFORE the substep loop
{
    vec3_t entNow, entDelta;
    VectorCopy(cg_entities[s->entnum].lerpOrigin, entNow);
    if (s->entOriginValid) {
        VectorSubtract(entNow, s->lastEntOrigin, entDelta);
        /* MOVETYPE_TOSS re-toss (weaputils.cpp:3417/3527) is the only way this is non-zero
           after the park. Carry pt AND ptPrev so the body RIDES the entity instead of being
           left behind - carrying both means no velocity is injected, exactly like the
           rest-contact freeze at :934-938 sets pt and ptPrev to the same place. */
        if (VectorLengthSquared(entDelta) > 0.01f) {
            for (j = 0; j < RAG_PTS; j++) {
                VectorAdd(s->pt[j],     entDelta, s->pt[j]);
                VectorAdd(s->ptPrev[j], entDelta, s->ptPrev[j]);
            }
        }
    }
    VectorCopy(entNow, s->lastEntOrigin);
    s->entOriginValid = 1;
}
```

This must also **wake a sleeping body** (a slept corpse being tossed is precisely the
`RagMoverHash` situation, one level up), so run the same wake block as §5.1 when the delta is
non-zero. With it, an explosion produces the right beat: the server arcs the body, the client
ragdoll rides it, and our own client-side impulse flails the limbs on top.

> **Separate defect worth logging on its own:** the two impulse blocks above are **redundant and
> both execute on every `RadiusDamage` call**. An AI corpse in a blast satisfies both gates
> (`health <= 0` *and* `deadflag == DEAD_DEAD`), so it receives `MOVETYPE_TOSS` twice and
> **~650 u/s horizontal + 210 u/s vertical instead of one impulse**. Both header comments are
> also stale — `weaputils.cpp:3399` says corpses have "takedamage off" and `:3503` says they are
> "SOLID_NOT + MOVETYPE_NONE", neither of which has been true since `coop_corpseShootable`
> landed. Not fixed here; this document is read-only.

---

## 7. STAGING

### Stage 1 — the smallest version that visibly delivers the requirement

**Ship unit: `cgame.dll` alone.** ~90 lines, two files.

1. `cg_ragdoll.c` — add `CG_RagdollImpulse(pos, dir, force, radius, limpMs)` (§8), the
   `limpMs[RAG_PTS]` field, the two constants, the `RagShapeMatch` relax clause, the `RagStep`
   decrement, and the wake block including `rotLocked = 0`.
2. `cg_local.h:572` — one declaration, immediately below `CG_RagdollFrame` at `:571`
   (**inside** the `extern "C" {` block that opens at `:40` and closes at `:941`, so the C++
   caller links against the C definition with no `extern "C"` wrapper of its own — verified).
3. `cg_parsemsg.cpp` — **two call sites**, in the `CGM_BULLET_8` and `CGM_BULLET_9` cases
   (`:1799-1818`), right after the existing `flesh_impact_*` bookkeeping.

**Call at parse time, inside the case — not from `CG_AddBulletImpacts`.** `CG_RagdollFrame()`
runs at `cg_view.c:2928`, ahead of `CG_AddBulletImpacts()` at `cg_view.c:3108`, so hanging the
impulse off the deferred impact array would cost a frame. Applying it at parse time is also
simply *correct*: the offset lands on `ptPrev`, which is state, and the next `RagStep` consumes
it whenever it runs. No ordering constraint at all.

This covers **every rifle, SMG, pistol and MG shot, from the local player and from every other
player and AI** (`gi.SetBroadcastVisible(vTmpEnd, vBarrel)`, `weaputils.cpp:2620`). The user
shoots a settled corpse; the struck limb swings and re-settles. **Requirement met.**

New cvars, following `RagCvars` (`:276-290`) conventions:

```c
rag_impact  = cgi.Cvar_Get("coop_ragdollImpact",      "1",  CVAR_ARCHIVE); /* user-facing on/off:
                 ARCHIVE for the same reason coop_ragdoll is (:281) - an "off" must survive relaunch */
rag_impForce = cgi.Cvar_Get("coop_ragdollImpactForce", "90", CVAR_TEMP);   /* tuning */
rag_impLimp  = cgi.Cvar_Get("coop_ragdollImpactLimp", "600", CVAR_TEMP);   /* tuning */
```

Debug print, `^~^~^` prefix per house convention (`:948`, `:1390`):

```c
if (rag_debug->integer) {
    cgi.Printf("^~^~^ RAGDOLL impulse ent=%d pts=%d force=%.0f r=%.0f woke=%d limp=%d\n",
               s->entnum, nHit, force, radius, bWoke, limpMs);
}
```

### Stage 2 — full coverage. **Still `cgame.dll` alone.**

- `CGM_EXPLOSION_EFFECT_1..4` (`:1851-1859`) with the §4.4 type→radius/force table, plus the
  §6.3 drift leash. This is the one that makes grenades feel right.
- **The §6.4 entity-carry term, which ships in the same stage and is not optional.** The server
  re-tosses corpses in a blast (`weaputils.cpp:3417`/`:3527`); without the carry the explosion
  stage makes a pre-existing divergence highly visible — the entity arcs away while the ragdoll
  stays put. Carry `pt` and `ptPrev` together, and wake on a non-zero delta.
- `CGM_BULLET_3 / _4` (`:1732-1767`) — shotgun volleys; loop `vEndArray[i]`, apply each at
  reduced force (`force / sqrt(iCount)`) so a buckshot pattern does not sum to a launch.
- `CGM_MELEE_IMPACT` (`:1842-1850`) — carries full start **and** end coords; bayonet/rifle-butt
  a corpse.
- The **protocol-6 mirrors**: `CGM6_BULLET_8/_9` (`:2222`, `:2232`), `CGM6_EXPLOSION_EFFECT_1/_2`
  (`:2264-2270`), `CGM6_MELEE_IMPACT` (`:2255`). Skipping these silently disables the whole
  feature under `com_target_game 0/1` — a classic half-shipped trap.

### Stage 3 — server-authoritative limb hits. **NOT recommended for round 9.**

Ship unit: **`openmohaa.exe` + `cgame.dll` + `game.dll` in lockstep.** New CGM type in
42-63, emitted at `weaputils.cpp:2606-2627` carrying `ent->entnum`, `trace.location`, `dir` and
`newdamage`; gated on `g_protocol >= PROTOCOL_MOHTA_MIN` or `CG_ParseCGMessage_ver_6` will
`ERR_DROP` old clients off the server (`:2109`, `:2455`). Buys: exact limb identity, damage-scaled
force, and identical poses on all clients. Costs: the trilogy ship, forever. **Revisit only if
playtest shows stages 1-2 are not precise enough.**

---

## 8. CODE SHAPE

Conventions matched to the file: row-vector matrices, `VectorMA` on `ptPrev`, `s_rag*` statics,
`RAG_*` constants, `^~^~^` prints, `CVAR_TEMP` for tuning / `CVAR_ARCHIVE` for user toggles.

```c
// ---------- post-death impacts (round 9) ---------------------------------------------------
// A settled corpse is a resting state, not a frozen one: a bullet or a blast wakes the sim,
// kicks the points nearest the impact, and RELAXES THE SHAPE-MATCH ON THOSE POINTS for a
// short window - without that last part the pose attractor reels the limb home inside two
// frames (0.25 alpha x 4 substeps = 68%/frame) and the hit reads as a twitch, not a movement.
//
// Everything here is client-side and driven by messages that already arrive: no new protocol
// constant, no server change, cgame.dll ships alone.
void CG_RagdollImpulse(const vec3_t pos, const vec3_t dir, float force, float radius, int limpMs)
{
    const float subDt = RAG_SUBSTEP_MS * 0.001f;
    vec3_t      n;
    int         i, k;

    RagCvars();
    if (!rag_impact->integer || !cgi.R_SetRagdollPose) {
        return;
    }
    VectorCopy(dir, n);
    if (VectorNormalize(n) < 0.001f || force <= 0.0f || radius <= 1.0f) {
        return;
    }

    for (k = 0; k < RAG_MAX_SIMS; k++) {
        ragSim_t *s = &s_ragSims[k];
        vec3_t    mn, mx, drift;
        int       nHit = 0, bWoke = 0;
        float     leash = 1.0f;

        // graceful no-ops (section 5.3): evicted / never-armed bodies simply are not here.
        // state 0 = pending seed - CG_RagdollTransition is about to overwrite ptPrev wholesale
        // (:1644), so an impulse there would be silently eaten; skipping is honest.
        if (!s->active || s->state == 0 || s->freezePose) {
            continue;
        }
        if (!cg_entities[s->entnum].currentValid) {
            continue; // corpse despawned out of the snapshot; slot awaits eviction
        }

        // cheap AABB reject. Spatial routing IS the entity routing here - the impact position
        // is the key, exactly as RagMoverHash (:955) routes bmodels to bodies by bounds.
        ClearBounds(mn, mx);
        for (i = 0; i < RAG_PTS; i++) {
            AddPointToBounds(s->pt[i], mn, mx);
        }
        for (i = 0; i < 3; i++) {
            if (pos[i] < mn[i] - radius || pos[i] > mx[i] + radius) {
                break;
            }
        }
        if (i < 3) {
            continue;
        }

        // section 6.3 leash: the server corpse's shot slab never moves, so let the point cloud
        // wander only so far from it before outward pushes stop counting.
        VectorSubtract(s->pt[0], cg_entities[s->entnum].lerpOrigin, drift);
        if (VectorLength(drift) > RAG_IMPACT_MAX_DRIFT) {
            leash = 0.0f;
        }

        for (i = 0; i < RAG_PTS; i++) {
            vec3_t d;
            float  dist, kf, v, out;
            VectorSubtract(s->pt[i], pos, d);
            dist = VectorLength(d);
            if (dist >= radius) {
                continue;
            }
            kf = 1.0f - (dist / radius);   // 1 at the impact, 0 at the rim
            v  = force * kf;
            // leash only the OUTWARD component, so a leashed body can still be shaken and can
            // still settle back toward its hitbox
            out = DotProduct(n, drift);
            if (out > 0.0f && leash == 0.0f) {
                v *= 0.25f;
            }
            // THE VERLET INJECTION: velocity lives in (pt - ptPrev), in units per SUBSTEP.
            // v u/s -> v*subDt u/substep, subtracted from ptPrev. Never touch pt: that
            // teleports without accelerating (the inverse of the :840-845 defect).
            VectorMA(s->ptPrev[i], -(v * subDt), n, s->ptPrev[i]);
            if (limpMs > s->limpMs[i]) {
                s->limpMs[i] = (short)limpMs; // a second hit refreshes, never shortens
            }
            nHit++;
        }
        if (!nHit) {
            continue;
        }

        if (s->state == 2) {
            // same recipe as the mover-wake (:1280-1293). lifeMs = 0 is load-bearing: the
            // 6 s cap at :1353 is a PER-WAKE budget, so a corpse shot 30 s after death gets a
            // fresh window instead of re-sleeping on the next frame.
            s->state   = 1;
            s->sleepMs = 0;
            s->lifeMs  = 0;
            s->accumMs = 0;
            bWoke      = 1;
        } else {
            s->sleepMs = 0; // already awake: just deny it the sleep it was accruing
        }
        // RELEASE THE ROTATION LATCH (:201, latched at :796). A woken body must be allowed to
        // re-orient, or the shape-match pulls it toward the orientation it had before the hit.
        // bodyRotValid is deliberately LEFT SET so RagBodyRotation slews at a=0.12 (:800)
        // rather than snapping - that is what keeps the :781 precession loop shut. The latch
        // re-arms by its own nContact >= 3 rule once the body rests again.
        s->rotLocked = 0;

        if (rag_debug->integer) {
            cgi.Printf("^~^~^ RAGDOLL impulse ent=%d pts=%d force=%.0f r=%.0f woke=%d limp=%d\n",
                       s->entnum, nHit, force, radius, bWoke, limpMs);
        }
    }
}
```

Call site, `cg_parsemsg.cpp`, inside `case CGM_BULLET_8:` after the existing flesh bookkeeping
(`:1799-1807`) — `vEnd` is **already negated to point into the body** at `:1802`:

```c
case CGM_BULLET_8:
    if (flesh_impact_count < MAX_IMPACTS) {
        // negative
        VectorNegate(vEnd, vEnd);
        VectorCopy(vStart, flesh_impact_pos[flesh_impact_count]);
        VectorCopy(vEnd, flesh_impact_norm[flesh_impact_count]);
        flesh_impact_large[flesh_impact_count] = iLarge;
        flesh_impact_count++;
    }
    // HZM coop - ragdoll round 9: a flesh hit on a settled corpse wakes it and moves the limb.
    // vStart is the server's BONE-ACCURATE impact point (the bullet trace is a deep trace,
    // sv_world.c:582), vEnd is already the inward normal. Live sentients have no sim, so the
    // AABB test inside makes this a no-op for them.
    CG_RagdollImpulse(vStart, vEnd, 90.0f + 55.0f * iLarge, 30.0f + 2.0f * iLarge, 600);
    break;
```

---

## 9. RISKS

| # | Risk | Why it bites | Mitigation |
|---|---|---|---|
| **1** | **`RagSane`'s 200 u span test reverts the body to its death pose** (`:1094-1098`). A hard impulse that stretches the skeleton past 200 u on any axis does not blow up — it makes the corpse *snap back to the animator's pose*, i.e. the exact opposite of the requirement, and it looks like a bug | The failure is silent unless `r_ragdollDebug 1` (which prints `NaN/blowup ... reverting`). Worse, `s_ragNeverArm[entnum] = 1` at `:1328` means that corpse **can never ragdoll again this map** | Radius falloff over neighbours instead of a nearest-point kick (§4.2); cap explosion force at the mod's own 460 ceiling; **watch for `RAGDOLL NaN/blowup` in `qconsole.log` during the first grenade test** — one line there means the magnitudes are too high |
| **2** | **The `trace.location >= 0` chain is read from source, not observed.** If a corpse hit does not set a location, `CGM_BULLET_8` never fires and stage 1 does nothing at all — silently | The whole primary signal rests on it. `SV_TraceDeep` is reached via `clip->traceDeep && touch->tiki && bIsCharacter` (`sv_world.c:582`) — all three verified to hold (`traceDeep` is the literal `true` at `weaputils.cpp:2438`; the gate is on the **tiki**, so `BecomeCorpse` clearing `SVF_MONSTER` at `actor.cpp:12472` does *not* disable it). Confidence is high but it is still inference | **Probe first, build second:** `coop_bloodDebug 1`, shoot a corpse, look for `^~^~^ FLESHHIT ... loc=`. That probe (`weaputils.cpp:2611-2619`) sits on the flesh branch itself, so it is a direct test of the exact `if` we depend on. Fallback is `CGM_BULLET_1/_2` (always emitted, `weaputils.cpp:2789-2798`) with an AABB-containment gate to reject passing rounds |
| **3** | **`rotLocked` released but never re-latched, or released too eagerly** | The latch exists because an unlatched fit precessed — "bodies sorta spinning on the ground, a very slow spin", and *every body rode to the 6 s cap instead of sleeping* (`:781-786`). Re-opening that turns every shot corpse into a permanently drifting body, and burns the trace budget for the whole pool | Release **only** in the impulse path, never clear `bodyRotValid` (so the slew brake at `a = 0.12` still applies), and rely on the existing `nContact >= 3` rule at `:796` to re-latch. **Acceptance test: shoot a corpse, confirm a `^~^~^ RAGDOLL sleep` line follows within ~2 s.** No sleep line = the latch is not re-arming |
| **4** | **A blast-tossed corpse leaves its ragdoll behind** (§6.4) — pre-existing, and the explosion stage is what makes it visible | `RagPush` pins bones to world sim points (`:1179-1185`), so the entity can slide out from under the rendered body. `g_corpseImpulse` defaults to `1.0`, so this is the *default* path, not an edge case | Ship the §6.4 carry term **in the same stage as explosions**, never after. Carry `pt` and `ptPrev` together so the ride injects no velocity, and wake on a non-zero delta |

**Secondary watch items:** the mover-wake and the impulse-wake now both reset `lifeMs`, so a
body in a firefight can stay awake indefinitely — bounded by the `RAG_TRACE_BUDGET 240`
(`:62`) and the 8-slot pool, both of which degrade gracefully by design. And `RAG_MAX_SIMS 8`
awake bodies during a grenade volley is the worst case the trace budget was sized for; if
`worldtr=` in the sleep print climbs past a few hundred, lower the explosion radii before
touching the budget.

---

## 10. ACCEPTANCE

1. `coop_ragdoll 1`, `r_ragdollDebug 1`, kill a soldier, wait for `^~^~^ RAGDOLL sleep`.
2. Shoot the settled corpse. **Expect:** `^~^~^ RAGDOLL impulse ent=.. pts=2..5 .. woke=1`, a
   visible limb swing of roughly 4-10 u, and a second `^~^~^ RAGDOLL sleep` within ~2 s.
3. Wait 30 s, shoot it again. **Expect:** identical behaviour — this is the life-cap test.
4. Grenade next to two corpses (stage 2). **Expect:** two `impulse` lines, both bodies lurch,
   no `NaN/blowup`, both sleep again. **Watch specifically for the §6.4 divergence** — the
   server also tosses the corpse (`g_corpseImpulse` default `1.0`), so without the carry term
   the shadow and hitbox slide away from the visible body. With the carry term they travel
   together. If you cannot tell, set `g_corpseImpulse 0` and re-run: the difference between the
   two runs *is* the server toss.
5. `coop_ragdollImpact 0` → shooting a corpse does nothing, no prints, vanilla behaviour.
6. Shoot a corpse while a second player also shoots it — both clients should see motion
   (the message is broadcast to the muzzle's PVS as well as the impact's).
