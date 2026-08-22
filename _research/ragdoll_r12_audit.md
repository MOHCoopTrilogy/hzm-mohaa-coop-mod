# Ragdoll R12 — FOLLOW ONE BULLET AND FIND WHERE THE MOTION DIES

**Lens:** forensic trace, not design. One rifle round into the left forearm of a corpse lying on
the ground, followed through every stage with arithmetic at each, saying how much of the injected
velocity survives.

**Date:** 2026-08-20. **Subject:** `openmohaa-hzm/code/cgame/cg_ragdoll.c` (2177 lines, read
complete and current — the file changed several times today; every line number below was read out
of the 16:27 file, not carried from an earlier round). Entry points
`openmohaa-hzm/code/cgame/cg_parsemsg.cpp`. Server side
`openmohaa-hzm/code/fgame/weaputils.cpp`, `openmohaa-hzm/code/server/sv_world.c`,
`openmohaa-hzm/code/qcommon/cm_trace_lbd.cpp`, `openmohaa-hzm/code/qcommon/cm_trace.c`,
`openmohaa-hzm/code/qcommon/q_math.c`, `openmohaa-hzm/code/qcommon/msg.cpp`.

**Prior art:** `ragdoll_r9_impact.md` (the impulse design — its one load-bearing assumption is the
defect found here), `ragdoll_r11_solver.md`, `ragdoll_r11_truss.md`, `ragdoll_r11_topology.md`,
`ragdoll_r11_risk.md`, `.wolf/buglog.json` bug-1962 … bug-1975.

**Numeric model:** every "measured" figure below comes from a faithful line-by-line Python port of
`RagStep` / `RagShapeMatch` / `RagCollideWorld` / `RagResolveHit` / `CG_RagdollImpulse` with the
constants copied verbatim from the current file, run on a synthetic supine landed pose with a floor
plane at z=0. The port is
`C:\Users\curry\AppData\Local\Temp\claude\C--mohaa-coop-dev\277135cf-ad44-4f7d-b2d4-b293580237c0\scratchpad\ragbudget.py`
and `ragbudget2.py`. Where a number can be derived by hand it is derived by hand as well, and the
two agree.

---

## 0. THE ANSWER IN ONE PARAGRAPH

**The motion dies at stage 1, before the solver ever sees it.** The direction we push the limb with
is not the bullet's direction and never was. It is `trace.plane.normal` from a trace that **never
writes `plane`** on the code path a flesh hit actually takes. For a point-blank corpse shot the
normal arrives as **exactly `(0,0,0)`**, `DirToByte` maps a zero vector to index 0, and every single
shot therefore pushes the limb along the **same constant vector, 58.3° into the floor**. The solver
then does exactly what it should with a vector aimed at the ground: `RagResolveHit` annihilates 90%
of it against the floor plane on substep 1, and the resting-contact gate finishes it on substep 2.
**220 u/s of nominal force becomes 0 u/s in 16 ms and 5.8° of bone rotation** — invisible. Give the
same solver, unchanged, a horizontal direction and the identical arm swings **37.8°**. The lead
hypothesis is half right: the corpse's ground contact *is* the executioner, but the crime is the
direction, and the executioner is the restitution/friction split, not the resting-contact gate
(disabling the gate changes 5.8° to 5.8°).

---

## 1. STAGE 1 — `cg_parsemsg.cpp`: WHAT ACTUALLY ARRIVES

### 1.1 The call site

`cg_parsemsg.cpp:1774-1822`, `case CGM_BULLET_8` / `CGM_BULLET_9`:

```c
vStart[0] = cgi.MSG_ReadCoord();          // :1774-1776
vStart[1] = cgi.MSG_ReadCoord();
vStart[2] = cgi.MSG_ReadCoord();
cgi.MSG_ReadDir(vEnd);                    // :1777
iLarge = cgi.MSG_ReadBits(2);             // :1778
...
case CGM_BULLET_8:
    if (flesh_impact_count < MAX_IMPACTS) {
        VectorNegate(vEnd, vEnd);         // :1802
        ...
    }
    CG_RagdollImpulse(vStart, vEnd, 150.0f + 70.0f * iLarge, 15.0f + 1.5f * iLarge,
                      600 + 70 * iLarge);  // :1808
```

**Position — good.** `MSG_ReadCoord` (`qcommon/msg.cpp:659-670`) is 19 bits, value/16, so the
quantisation is **1/16 u = 0.0625 u** over ±16384 u. `vStart` is the server's `trace.endpos`, which
`CM_TraceDeepSuccess` (`cm_trace_lbd.cpp:345-358`) computes along the world segment using the
fraction returned by the per-bone sphere intersect. That fraction is frame-independent, so **the
position is the true world point where the round entered the bone's hit sphere**, to 1/16 u. This
half of the message is sound and needs no change.

One caveat worth stating as INFERENCE, not proof: the server poses the corpse with its own frozen
death-anim state, so `vStart` is the bone in the **authored** pose. The client sim starts at exactly
that pose (`RagCapture` captures the same frameInfo, `cg_ragdoll.c:549-582`) and drifts from it
afterward. As drift grows, `pos` names a bone the client's skeleton has already moved. Measured
settle drift is 0-20 u, so on a fresh corpse the two coincide and the segment search picks the right
bone; on a heavily worked-over corpse it can pick the wrong one.

**`iLarge` — 0..3.** For rifles `bulletlarge = damage >= 41.f` (`weaputils.cpp:2359`), so a rifle is
**iLarge 1 → force 220, radius 16.5, limpMs 670**. That is the case traced below.

| iLarge | force (u/s) | radius (u) | limpMs |
|---|---|---|---|
| 0 (pistol/SMG) | 150 | 15.0 | 600 |
| **1 (rifle)** | **220** | **16.5** | **670** |
| 2 | 290 | 18.0 | 740 |
| 3 | 360 | 19.5 | 810 |

**Direction — the defect.** Everything below is the proof.

### 1.2 What the server writes

`weaputils.cpp:2621-2628`, the flesh branch of `BulletAttack`:

```c
gi.MSG_StartCGM(BG_MapCGMToProtocol(g_protocol, CGM_BULLET_8));
gi.MSG_WriteCoord(vTmpEnd[0..2]);
gi.MSG_WriteDir(trace.plane.normal);          // <-- :2625
```

It writes the **surface normal of the trace**, not the bullet direction. That is the correct vanilla
choice *for a blood decal*. It is the wrong quantity for an impulse, and — worse — on this code path
it is not even a surface normal.

### 1.3 `trace.plane` is never written by the flesh path

The bullet trace is a **deep** trace: `weaputils.cpp:2436-2438`

```c
trace = G_Trace(vTraceStart, vec_zero, vec_zero, vTraceEnd, newowner,
                MASK_SHOT_TRIG, false, "BulletAttack", true);
//                                                     ^^^^ tracedeep
```

`sv_world.c:582-590` routes any character tiki to `SV_TraceDeep`:

```c
if (clip->traceDeep && touch->tiki != NULL && touch->tiki->a->bIsCharacter) {
    SV_TraceDeep(&trace, clip->start, clip->end, clip->contentmask, touch);
}
```

A corpse is still an `Actor` with a character tiki (`BecomeCorpse` clears `SVF_MONSTER`,
`actor.cpp:12471`, but the gate is on the **tiki**), and it is `SOLID_BBOX` with
`CONTENTS_WEAPONCLIP` and box `(-32,-32,0)..(32,32,16)` (`actor.cpp` `BecomeCorpse`, the
`coop_corpseShootable` block). So corpse hits take the deep path.

Now follow `plane` through `SV_TraceDeep` (`cm_trace_lbd.cpp:444-500`):

1. **`CM_TraceDeepSimple`** (`:215-263`) — the **only** thing on this path that ever writes
   `results->plane`:
   ```c
   vNewMins = vEntMins - 40.0;  vNewMaxs = vEntMaxs + 40.0;         // :232-238
   clipHandle = CM_TempBoxModel(vNewMins, vNewMaxs, iEntContents);  // :240
   AngleVectorsLeft(vEntAngles, vForward, vLeft, vUp);              // :241
   vTransStart = (dot(t,vForward), dot(t,vLeft), dot(t,vUp));       // :243-247  <-- ENTITY-LOCAL
   vTransEnd   = ...                                                // :249-253
   CM_BoxTrace(results, vTransStart, vTransEnd, 0, 0, clipHandle, iBrushMask, qfalse); // :257
   ```
2. **`CM_TraceDeepSimple2`** (`:271-320`) → `LineSegmentToSphereIntersect` (`:111-172`), whose last
   line is `pTrace->fraction = ...; return qtrue;` — **it writes `fraction` and nothing else.**
3. **`CM_TraceDeepSuccess`** (`:345-358`) writes `endpos`, `allsolid`, `startsolid`, `contents`,
   `entityNum`, `location`, `ent` — **`plane` is not in the list.**
4. `sv_world.c:611-620`: `clip->trace = trace;` — whole-struct copy. `SV_Trace` (`:799-841`) ends
   `*results = clip.trace;` with no fix-up.

So `trace.plane.normal` for a flesh hit is whatever step 1 left there. Two cases:

**Case A — the muzzle is inside the inflated box → the normal is exactly zero.**
`CM_BoxTrace` opens with `Com_Memset(&tw, 0, sizeof(tw)); tw.trace.fraction = 1;`
(`cm_trace.c:1286-1287`), so `plane` starts zeroed. When the ray starts inside a brush,
`CM_TraceThroughBrush` (`cm_trace.c:661-670`) takes

```c
if (!startout) {                       // original point was inside brush
    tw->trace.startsolid = qtrue;
    if (!getout) { tw->trace.fraction = 0; tw->trace.allsolid = qtrue; }
    return;                            // <-- plane NEVER assigned
}
```

`CM_TraceDeepSimple`'s guard is
`if (results->fraction == 1.0 && !results->startsolid && !results->allsolid) return qfalse;` —
`startsolid` is set, so it returns `qtrue` and the bone spheres are tested normally. **The hit
registers; the normal stays `(0,0,0)`.**

The inflated box is the corpse slab ±40 u = **`(-72,-72,-40)..(72,72,56)`, i.e. 144 × 144 × 96 u**.
A player shooting a body he is standing next to is inside it (72 u ≈ 6 ft; the muzzle sits below
`DEFAULT_VIEWHEIGHT 82`, `bg_public.h:42`, and the box top is at +56 relative to the corpse origin —
so crouched, prone, leaning, on a step, or with the corpse on a slope, you are inside).

Now the payload. `PF_MSG_WriteDir` (`sv_game.c:368-380`) is `b = DirToByte(dir)`, and `DirToByte`
(`q_math.c`) is:

```c
bestd = 0; best = 0;
for (i=0; i<NUMVERTEXNORMALS; i++) { d = DotProduct(dir, bytedirs[i]); if (d > bestd) {...} }
return best;
```

With `dir == (0,0,0)` every dot product is 0, `d > bestd` is never true, and it returns **0**.
`ByteToDir(0)` = `bytedirs[0]` = **`(-0.525731, 0.000000, 0.850651)`** (`q_math.c:75-76`).
The client negates (`cg_parsemsg.cpp:1802`) and hands `CG_RagdollImpulse`:

> ### `dir = (+0.525731, 0.000000, -0.850651)` — a CONSTANT, 58.3° below horizontal, on every
> point-blank corpse shot, independent of where the shooter is standing.

(`atan(0.850651 / 0.525731) = atan(1.618) = 58.28°`. The golden ratio is not a coincidence — it is
an icosahedron vertex, which is what the `anorms` table is built from.)

**Case B — the muzzle is outside the inflated box → an axis-snapped normal in the wrong frame.**
`CM_TempBoxModel` (`cm_load.c:1499-1518`) is a plain AABB: six axis-aligned planes. So `plane.normal`
is one of `±X, ±Y, ±Z` — **six possible directions for the whole game** — and it is expressed in the
frame `AngleVectorsLeft(vEntAngles, …)` rotated into at `cm_trace_lbd.cpp:241-253` and **never
rotated back**. A corpse at yaw 90° therefore reports a local `+X` face as world `(1,0,0)` when the
face actually faces world `(0,1,0)`: a 90° error, uncorrelated with the shot. And because the box is
144 u wide, the face the ray crosses is chosen 72 u away from the body, not at the body.

Both cases are consistent with the user's evidence, and Case A explains the most damning datum in
the whole investigation: with **every** anti-pile brace switched off (`coop_ragdollTruss 0`, a body
with no scaffolding at all) the limbs still "don't really seem to move at all". Of course they
don't — the solver was never the problem; it was being handed a vector aimed at the floor.

### 1.4 Two secondary defects on this same path

- **`trace.location >= 0` gates the whole message** (`weaputils.cpp:2606`). `CM_TraceDeepFail` sets
  `results->location = LOCATION_FAIL` = **-2** (`cm_trace_lbd.cpp:28, 336`). The corpse slab is
  64 × 64 u but the hit-location spheres cover only the actual body (`fLocRadius[]`, 4.0-9.0 u,
  `cm_trace_lbd.cpp:62-64`). A round that passes through the slab and misses every sphere sends
  **nothing at all** — no blood, no impulse — because `CONTENTS_WEAPONCLIP` is not `CONTENTS_SOLID`
  so the `CGM_BULLET_7` fallback (`weaputils.cpp:2630`) does not fire either. Some fraction of
  "I shot the body and nothing happened" is literally nothing happening.
- **`VectorNegate` is inside the `if`** (`cg_parsemsg.cpp:1800-1802`). Past `MAX_IMPACTS` (64,
  `cg_parsemsg.cpp:48`) flesh impacts in one frame, the negate is skipped and `CG_RagdollImpulse`
  receives the **outward** normal — the limb is pushed toward the shooter. `flesh_impact_count`
  resets once per frame at `cg_parsemsg.cpp:1398`, so this needs 64 flesh hits in one frame. Real,
  rare, one-line fix (hoist the negate out of the `if`).

---

## 2. STAGE 2 — `CG_RagdollImpulse`: HOW MUCH SPEED IS ACTUALLY INJECTED

`cg_ragdoll.c:1384-1556`.

**Eligibility.** `if (!s->active || s->state < 1) continue;` (`:1396`) — state 2 (sleeping) passes,
so a settled corpse is a valid target. Correct.

**Segment selection** (`:1405-1432`). Point-to-segment over `j = 1..14`, so **14 segments**, min
distance wins, `bestT` clamped to [0,1]. Note the indexing that matters for stage 7: segment `j`
runs `pt[parent[j]] → pt[j]`, so the **forearm's flesh is segment j = 7** (`pt[6]` elbow → `pt[7]`
wrist), and `bestJ = 7` is the **hand point**, `bestP = 6` the elbow.

**`k2` — the first real loss.** `k2 = 1 - bestD/radius` (`:1435`). `bestD` is the distance from the
impact point to the bone axis. The impact point is the **entry point on the hit sphere**, and the
forearm's spheres are r = 5.5 (offset 5 u down the bone) and r = 5.0 (offset 11.5 u), so for a
roughly perpendicular shot `bestD ≈ 4-5.5 u`.

> `k2 = 1 − 5.0 / 16.5 = **0.697**` — 30% of the force gone to falloff on a dead-centre bone hit.

**Distal / proximal split** (`:1445-1448`):
`w[0] = 0.80 + 0.20·bestT` on `bestJ`; `w[1] = 0.15·(1 − bestT)` on `bestP`, skipped when < 0.05
(i.e. whenever `bestT > 0.667`).

At `bestT = 0.45`: `w[0] = 0.89`, `w[1] = 0.0825`.

**Injection** (`:1456`): `VectorMA(ptPrev[q], −(force·k2·w·subDt), dir, ptPrev[q])` with
`subDt = 0.008`. Moving `ptPrev` backward by `X` raises the Verlet gap `pt − ptPrev` by `X`, so

> `v_distal = force · k2 · w[0] = 220 × 0.697 × 0.89 = **136.5 u/s**`
> `v_proximal = 220 × 0.697 × 0.0825 = **12.6 u/s**`

**Accumulation clamp** (`:1457-1463`): `vmax = force · 1.6 = 352 u/s`. 136.5 ≪ 352, so a first hit
is not clamped. This clamp only bites on sustained fire, which is what it was built for.

**Chain limp** (`:1469-1478`): walks parents looking for `bestJ`. For a forearm hit `bestJ = 7` is a
**leaf**, so nothing is below it and this loop does nothing. Harmless here; it matters for torso and
upper-arm hits.

**Wake** (`:1542-1550`). `sleepMs`, `lifeMs`, `accumMs` are reset **only if `state == 2`**. See
stage 8 — this is a real bug.

**Stage 2 verdict: 220 → 136.5 u/s (62.0% retained).** The losses are deliberate and defensible.

---

## 3. STAGE 3 — `RagStep` INTEGRATE

`cg_ragdoll.c:950-973`.

- **Damping 0.98 per substep** (`RAG_DAMPING`, `:60`). Per second: `0.98^125 = e^{-2.525} = 0.080`
  → 92%/s. Over the 600 ms limp window: `0.98^75 = e^{-1.515} = **0.220**`. Over the first 100 ms:
  `0.98^12.5 = **0.777**`. **Damping is not the killer in the window that matters.**
- **Velocity cap** (`:961-968`). `rag_velcap` default **8**, clamped to [1,64], compared against
  `|vel|` which is a **per-substep displacement in units** — so the cap is `8 u / 0.008 s =
  1000 u/s`. Our 136.5 u/s = 1.09 u/substep. **Never binding.** (Even the clamp ceiling
  `force·1.6 = 352 u/s` = 2.8 u/substep is under it.)
- **Gravity** (`:953`, `:971`). `g = gravity · dt² = 800 × 0.000064 = **0.0512 u/substep**` (0.0328 u
  at the code comment's 512). Against 1.09 u of impulse displacement that is **4.7% of one
  substep**. Negligible over the two substeps this impulse survives.

**Stage 3 verdict: 136.5 → 133.8 u/s on substep 1 (98.0% retained).**

---

## 4. STAGE 4 — THE CONSTRAINT SWEEP: DOES THE SOLVER SHARE THE MOTION AWAY?

`cg_ragdoll.c:974-1011`. 14 parent links at 0.5 correction × 6 iterations, plus 16 braces.

### 4.1 The concrete two-point example

Link `6→7` (elbow → wrist), rest length `L`. The code is

```c
d = pt[i] - pt[p];  len = |d|;  corr = (len - restLen[i]) * 0.5f / len;
pt[i] += -corr*d;   pt[p] += +corr*d;                       // :979-986
```

**Axial displacement.** Displace `pt[7]` by `δ` straight along the bone. `len = L + δ`,
`corr·len = 0.5δ`. `pt[7]` moves back `0.5δ`, `pt[6]` moves forward `0.5δ`. **The separation is
restored exactly in one iteration**; iterations 2-6 are no-ops for the isolated pair. Net result:
the pair's centroid moved `0.5δ` and the **articulation is zero**.

> **An axial impulse is converted into a rigid translation of the chain, at exactly 50% per link.**
> That is a real and complete answer to "the whole body just kinda moves with it".

**Perpendicular displacement.** Displace `pt[7]` by `δ` perpendicular to the bone.
`len = sqrt(L² + δ²) ≈ L(1 + δ²/2L²)`, so the length error is `δ²/2L`. With `δ = 1.09 u` (one
substep at 136.5 u/s) and `L = 14 u`:

> `error = 1.09² / (2 × 14) = 1.188 / 28 = **0.0424 u = 3.9% of δ**` → **96.1% of a perpendicular
> displacement survives the sweep untouched.**

**So the "the solver simply shares the motion out until nothing is visible" hypothesis is REFUTED
for the case that matters and CONFIRMED for the axial case.** A rotation-inducing push is preserved
almost perfectly; a push along the bone is halved into translation.

### 4.2 The braces

Of the 16 braces (`:123-140`), only two touch points 6 or 7: `{2,6}` (min factor 0.70) and `{5,7}`
(min 0.75). Both are **inequality** braces — `if (braceMinFactor > 0 && len >= braceLen) continue;`
(`:1004-1006`) — and the arm sits near its capture length, so both are **inert** for a forearm hit.
The equality braces (`{5,8}`, `{11,13}`, `{5,13}`, `{8,11}`, `{3,1}`, `{0,2}`) do not involve the
arm at all.

> **This is why `coop_ragdollTruss 0` changed nothing for the user.** For an arm hit the truss was
> never in the loop. (It very much *is* for a leg hit — `{11,13}` welds thigh to thigh, which is
> exactly "when I shoot one leg they both move".)

**Stage 4 verdict: 133.8 → ~128.6 u/s for a perpendicular push (96.1%); 133.8 → ~66.9 u/s of
articulated motion for an axial push (50%, the rest becoming translation).**

---

## 5. STAGE 5 — `RagShapeMatch`: THE CARRY, AND WHAT IT REALLY DOES

`cg_ragdoll.c:915-948`, called last in `RagStep` (`:1032`).

```c
d = want - pt[i];                                    // want = pt[0] + S*(goal[i]-goal[0])
a = alpha;                                           // rag_stiff 0.25
if (contact[i]) a *= RAG_CONTACT_RELAX;              // 0.15
if (limpMs[i] > 0) { k = 1 - limpMs[i]/600; a *= 0.05 + 0.95*k; }
VectorMA(pt[i],     a,               d, pt[i]);      // :940
VectorMA(ptPrev[i], a*rag_carry(0.85), d, ptPrev[i]); // :946
```

### 5.1 The carry does NOT erase the impulse — proven

Both `pt` and `ptPrev` move in the **same direction** by `a·d` and `0.85·a·d`. The change in the
velocity vector is

> `Δ(pt − ptPrev) = a·d − 0.85·a·d = **+0.15·a·d**`

— i.e. the shape-match **adds** velocity, always toward the pose target, and can never subtract the
impulse's velocity. The prompt names this a prime suspect; it is **refuted, both algebraically and
empirically**: in the port, running the shipped direction with `RagShapeMatch` entirely disabled
gives a peak bone rotation of **5.1°** against **5.8°** with it on. It made no difference.

### 5.2 What it does instead: it erases the RESIDUE, and it prefers translation

`u = pt[i] − want` decays by `(1 − a)` per substep, so the time constant is `8 ms / a`:

| condition | `a` | τ | deviation left after 1 s |
|---|---|---|---|
| full pull (limp expired, no contact) | 0.25 | **32 ms** | `0.75^125 ≈ 2e-16` |
| at world contact | 0.0375 | 213 ms | 0.9% |
| limp floor, first substep after a hit | 0.0157 | 510 ms | 13.8% |

Over the whole 600 ms limp ramp, the cumulative pull is
`Σa = 0.25 · Σ_{n=1..75}(0.05 + 0.95n/75) = 0.25 × 39.85 = 9.96`, so retention is
`e^{-9.96} = **4.7 × 10⁻⁵**.

> **The shape-match removes 99.995% of any articulated deviation over the limp window.** It does not
> prevent the swing; it undoes it.

And the asymmetry that produces the user's exact words: **`pt[0]` is never pulled** — the loop is
`for (i = 1; i < RAG_PTS; i++)` (`:924`). The attractor is a rigid body pinned to an unanchored
pelvis. Relative motion is destroyed with τ = 32 ms; **whole-body translation is opposed by
nothing**. Measured in the port, shipped direction, 800 ms after one rifle round:

| | wrist displacement | pelvis displacement | RELATIVE (articulated) |
|---|---|---|---|
| shipped dir | 1.79 u | 1.84 u | **0.68 u** |
| horizontal dir | 1.98 u | 2.03 u | **0.68 u** |

> **The entire surviving net motion is a rigid translation.** "The body kinda just slowly slides as
> a whole" is not a perception — it is arithmetic.

### 5.3 A NEW BUG: `limpMs > 600` makes alpha NEGATIVE

`k = 1.0f - (float)s->limpMs[i] / (float)RAG_IMPACT_LIMP_MS` (`:937`) with
`RAG_IMPACT_LIMP_MS 600` (`:67`). Nothing clamps `k`. But the call sites pass **larger** values:

| caller | `limpMs` | `k` on the first substep | factor | **alpha** | per-substep deviation multiplier |
|---|---|---|---|---|---|
| `cg_parsemsg.cpp:1808`, iLarge 0 | 600 | +0.0000 | +0.050 | +0.0125 | 0.9875 (converging) |
| **iLarge 1 (rifle)** | **670** | −0.1167 | −0.0608 | **−0.0152** | **1.0152 (diverging)** |
| iLarge 2 | 740 | −0.2333 | −0.1717 | −0.0429 | 1.0429 |
| iLarge 3 | 810 | −0.3500 | −0.2825 | −0.0706 | 1.0706 |
| **`cg_parsemsg.cpp:1867`, explosion 1** | **1200** | **−0.9867** | **−0.8873** | **−0.2218** | **1.2218** |
| explosion 4 | 1410 | −1.3367 | −1.2198 | −0.3050 | 1.3050 |

A negative alpha means `pt += a·d` moves the point **away from** the pose target, and the deviation
grows geometrically. For a grenade: `1.2218^N = 200` → `N = ln200 / ln1.2218 = 5.30 / 0.2004 =
**26.4 substeps = 212 ms**`, and the negative window lasts `(1200−600)/8 = 75 substeps = 600 ms`.
**The divergence has three times the runway it needs.**

Measured in the port (grenade at 60 u, force 400, radius 180): relative deviation runs
0.57 → 0.99 → 4.37 → **27.6** → 21.2 → **36.6** u at 8/24/48/96/200/400 ms, with the mean point
speed oscillating 90-345 u/s. With `limpMs` clamped to 600 the same grenade produces a clean 24 u
whole-body toss with relative deviation ≤ 2.5 u.

In the live game that divergence trips `RagSane`'s 200 u span test or the 128 u pelvis leash
(`:1219-1236`), which sets `s_ragNeverArm[entnum] = 1` and `CG_RagdollClearEnt` — the corpse
**silently reverts to the server-driven anim pose and can never ragdoll again this map**. All the
user then sees is the server's own `g_corpseImpulse` toss (bug-1974). That is, verbatim, "grenades
lift the body up and throw it slightly as a whole, individual limbs not really reacting."

**One-line fix:** `if (limpMs > RAG_IMPACT_LIMP_MS) limpMs = RAG_IMPACT_LIMP_MS;` at the top of
`CG_RagdollImpulse`. (Or, better, store a per-point `limpTotal` so long windows work as intended.)

**Stage 5 verdict on velocity: 100% retained (it adds, never subtracts). Stage 5 verdict on
displacement: 99.995% destroyed over 600 ms, and what is left is translation.**

---

## 6. STAGE 6 — `RagCollideWorld` / `RagResolveHit`: THE EXECUTIONER

`cg_ragdoll.c:1104-1146` and `1038-1071`.

### 6.1 The per-bone radius is ~1 u for a limb lying on the ground

`RagCapture:716-733` clamps each point's collision radius to the floor clearance the **authored**
pose already has, min 1.0 (bug-1970). For a forearm resting on the floor the clamp lands at
`clear ≈ 1.0-3.0 u`, and — critically — **the box bottom is flush with the floor at capture.**
Any downward motion at all hits on the first sweep. There is no free travel.

### 6.2 The arithmetic of one downward substep

Substep 1, `v = 133.8 u/s × 0.008 = 1.070 u` along `(0.5257, 0, −0.8507)` → `v = (0.563, 0, −0.910)`.
The floor normal is `n = (0,0,1)`. `RagResolveHit:1045-1063`:

```
d  = v·n              = −0.910
vn = n·d              = (0, 0, −0.910)
vt = v − vn           = (0.563, 0, 0)
                                        // gate: |v| = 1.070 > 0.35  →  NOT taken on substep 1
vn *= −0.1  (restitution)  → (0, 0, +0.0910)
vt *= 0.45  (floor friction) → (0.253, 0, 0)
v' = (0.253, 0, 0.0910)   |v'| = 0.269 u/substep = 33.6 u/s
```

> **Substep 1 retention: 33.6 / 133.8 = 25.1%.** The normal component — **85% of the vector's
> magnitude, because the direction is 58° down** — is multiplied by 0.1 and gone.

Substep 2: `|v| = 0.269 × 0.98 = 0.264 u/substep`, which is **below the 0.35 gate**, so
`RagResolveHit:1053-1058` fires:

```c
if (tr->plane.normal[2] > 0.7f && VectorLength(v) < 0.35f) {
    VectorCopy(pos, s->pt[i]);
    VectorCopy(pos, s->ptPrev[i]);   // pt AND ptPrev — all velocity, including tangential, gone
    s->contact[i] = 2;
    return;
}
```

> **Substep 2 retention: 0%.**
> **The whole event is over in 16 ms.** 136.5 → 33.6 → 0 u/s.

### 6.3 The lead hypothesis, adjudicated

The maintainer's hypothesis was that the resting-contact full-stop is the killer. **It is the second
executioner, not the first.** Measured in the port, shipped direction, **resting gate disabled
entirely**: peak bone rotation **5.8°** — identical to 5.8° with the gate on. The restitution ×0.1
on the normal component had already taken 75% before the gate ever got a look, and the residual
tangential slide it preserves is invisible anyway.

The hypothesis was right about *where* (the ground contact) and right that the direction points into
the floor. It was wrong about *which line*, and it under-called the cause: the direction is not
"largely into the floor because the body is prone" — **it is a hard-coded constant that has nothing
to do with the shot at all.**

### 6.4 What happens when the sweep starts flush

`RagCollideWorld:1114-1119` skips a point whose substep displacement is < 0.01 u, then sweeps
`subStart → pt`. Because the capture clamp seats the box bottom on the floor, the sweep returns
`fraction ≈ 0`; `pos = tr->endpos + 0.25·n` (`:1043`) puts the point back essentially where it
started, 0.25 u proud. **The point does not move at all on substep 1** — it only has its velocity
rewritten. That is why the port's "peak deviation" for the shipped direction never exceeds 0.77 u:
the limb is not pushed anywhere, it is stopped.

**Stage 6 verdict: 133.8 → 33.6 → 0 u/s. 100% of the injected velocity destroyed in 2 substeps.**

---

## 7. STAGE 7 — `RagPush`: DOES A POINT MOVE PRODUCE A VISIBLE BONE ROTATION?

`cg_ragdoll.c:1240-1340`. **Yes. This stage is clean and swallows nothing.**

For a forearm hit (`bestJ = 7` = hand point, `bestP = 6` = elbow):

| bone | driver | moved? | visible? |
|---|---|---|---|
| 6 `L Forearm` | `s_ragDriveChild[6] = 7` → `pt[6] → pt[7]` (`:1288`) | `pt[7]` moved a lot, `pt[6]` barely | **rotates** |
| 7 `L Hand` | leaf, falls back to `pt[6] → pt[7]` (`:1291`) | same segment | **rotates** |
| 5 `L UpperArm` | `→ pt[6]` | `pt[6]` moved `w[1]` | small rotation |

Channel positions are `pt[anchor] + rotNow[anchor]·relPos[ch]` (`:1312-1313`), and the hand's own
channel self-anchors to sim point 7 (`:783-788`), so the mesh follows the point that actually moved.
The finger nubs anchor to 7 via `s_ragAnchorTable` (`:266-267`). Nothing is anchored to a point that
did not move when it should have.

I checked the one structural trap the prompt asked about — a channel anchored to a stationary point
— across all five leaves (`4 Head`, `7/10 Hand`, `12/14 Calf`). All five fall back to the incoming
segment `pt[i] − pt[parent]` (`:1291`), which still changes when `pt[i]` moves. **No swallow.**

**Stage 7 verdict: 100% of point motion reaches the mesh.** The rotation math (bug-1963/1966) is
correct as it stands; this is not where the motion is lost.

**Angle sensitivity, for calibration:** a 14 u forearm needs `atan(δ/14)` of lateral wrist
displacement per degree — **1 u ≈ 4.1°, 3 u ≈ 12°, 5 u ≈ 20°**. The 0.77 u the shipped path
achieves is **3.1°**. The 5.34 u a horizontal push achieves is **21°**.

---

## 8. STAGE 8 — SLEEP: CAN THE BODY RE-SLEEP BEFORE THE MOTION IS VISIBLE?

`cg_ragdoll.c:1726-1747`.

```c
for (j...) speed += |pt[j] - ptPrev[j]|;
speed = speed / RAG_PTS / (RAG_SUBSTEP_MS*0.001f);      // MEAN over all 15 points, u/s
if (speed < 10.0f) s->sleepMs += ms; else s->sleepMs = 0;
if (s->sleepMs > 1000 || s->lifeMs > 6000) -> state 2
```

**The metric is the mean over 15 points.** One limb moving at `V` u/s contributes `V/15` to the
mean, so a single point must exceed **150 u/s on its own** to clear the 10 u/s gate. Our forearm
gets 136.5 u/s — **9.1 u/s of mean, i.e. below the gate from the very first substep.** Every rifle
shot on a corpse is, by this metric, indistinguishable from a body at rest.

**Two consequences:**

1. **`sleepMs` is not reset for an awake body.** `cg_ragdoll.c:1542-1548` resets `sleepMs`, `lifeMs`
   and `accumMs` **only inside `if (s->state == 2)`**. A corpse that landed 950 ms ago is awake with
   `sleepMs ≈ 950`; shooting it does not reset that, and it sleeps 50 ms later — mid-swing. Shots in
   the first ~2 s after a body lands are the worst case, which is exactly when a player shoots it.
2. **Testable prediction:** the *second* shot on a corpse should look better than the first, because
   the first put it to sleep (`state == 2`) and the second therefore takes the wake path and gets a
   fresh 1000 ms budget. If the user has noticed "sometimes the second or third shot does something"
   that is the mechanism.

**Fix:** move `s->sleepMs = 0;` (and `lifeMs`) out of the `state == 2` guard, and/or change the
sleep metric from mean to max point speed.

**Stage 8 verdict: not the primary killer of a fresh wake (1000 ms budget), but a real truncation of
any shot landing in the settling window, and structurally blind to single-limb motion.**

---

## 9. THE BUDGET, ON ONE LINE

Rifle round, iLarge 1, into a forearm lying on the ground. `force = 220 u/s` nominal.

| # | stage | code | in | out | retained |
|---|---|---|---|---|---|
| 1 | server `plane.normal` | `cm_trace_lbd.cpp:345-358` | true bullet dir | `(0,0,0)` | **direction: 0% correlated** |
| 1 | `DirToByte(0,0,0)` | `q_math.c` | zero | index 0 → 58.3° into floor | — |
| 2 | falloff `k2` | `cg_ragdoll.c:1435` | 220 | 153.3 | 69.7% |
| 2 | distal weight `w[0]` | `:1446` | 153.3 | **136.5 u/s** | 89.0% |
| 2 | accumulation clamp | `:1457-1463` | 136.5 | 136.5 | 100% (vmax 352) |
| 3 | damping ×0.98 | `:959` | 136.5 | 133.8 | 98.0% |
| 3 | velcap | `:961-968` | 1.07 u | 1.07 u | 100% (cap 8 u) |
| 3 | gravity | `:971` | — | −0.051 u | 4.7% of one substep |
| 4 | constraints (perp) | `:974-1011` | 133.8 | 128.6 | 96.1% |
| 4 | constraints (axial) | `:979-986` | 133.8 | 66.9 articulated | 50% |
| 4 | braces | `:988-1010` | inert for an arm | — | 100% |
| 5 | shape-match velocity | `:940-946` | 133.8 | 133.8 | **100%** (adds, never subtracts) |
| **6** | **`RagResolveHit` normal ×0.1** | **`:1059`** | **133.8** | **33.6 u/s** | **25.1%** |
| **6** | **resting gate, substep 2** | **`:1053-1058`** | **33.0** | **0 u/s** | **0%** |
| 7 | `RagPush` | `:1274-1334` | point motion | bone rotation | 100% |
| 5 | shape-match displacement, 600 ms | `:915-948` | any deviation | ×4.7e-5 | **0.005%** |
| 8 | sleep gate | `:1726-1747` | 136.5 u/s on 1 point | mean 9.1 < 10 | body reads as at rest |

**End to end: 220 u/s of nominal force produces 5.8° of peak bone rotation and 0.77 u of articulated
displacement, all of it gone in 16 ms, with a 1.8 u whole-body slide left behind.**
**The same solver, unchanged, given a horizontal direction, produces 37.8° and 5.34 u.**

---

## 10. RANKED SUSPECTS

| rank | suspect | evidence | measured cost | fix size |
|---|---|---|---|---|
| **1** | **`trace.plane.normal` is never written on the flesh path; zero → `bytedirs[0]` → a constant 58.3° into the floor** | `cm_trace_lbd.cpp:111-172, 215-263, 345-358`; `cm_trace.c:661-670, 1286`; `q_math.c` `DirToByte`; `sv_game.c:368-380` | **6.5× on peak bone rotation** (5.8° vs 37.8°) | 1 line, `game.dll` |
| **2** | `RagResolveHit` annihilates the normal component (×0.1) of a downward impulse on substep 1 | `cg_ragdoll.c:1059`; hand-derived 25.1%, port-confirmed | 75% of the velocity, in 8 ms | ~4 lines, `cgame.dll` |
| **3** | `RagShapeMatch` erases the residue: τ=32 ms at full pull, 4.7e-5 over the limp window; and `pt[0]` is never pulled, so translation is free while articulation is not | `cg_ragdoll.c:915-948` (loop starts at `i=1`, `:924`) | articulated deviation 5.34 u → 0.68 u by 800 ms | ~10 lines (goal rebase) |
| **4** | **`limpMs > 600` makes alpha NEGATIVE** — mild on rifles, catastrophic on explosions (`a = −0.222`, 22.2% divergence/substep for 600 ms) | `cg_ragdoll.c:937` vs `cg_parsemsg.cpp:1808, 1867`; blowup in 212 ms of a 600 ms window | grenades blow the sim up → `s_ragNeverArm` → permanent revert | **1 line** |
| **5** | Sleep metric is the **mean** of 15 points; one limb needs >150 u/s to register. `sleepMs` not reset for an awake body | `cg_ragdoll.c:1731-1747`, `:1542-1548` | truncates any shot in the settling window | 2 lines |
| 6 | Resting-contact full-stop | `cg_ragdoll.c:1053-1058` | **0°** — gate off changes 5.8° to 5.8° | (do not touch first) |
| 7 | `trace.location >= 0` gate drops hits that miss every bone sphere inside the 64×64 slab | `weaputils.cpp:2606`, `cm_trace_lbd.cpp:28, 336` | some shots produce no message at all | probe first |
| 8 | `VectorNegate` inside the `if (flesh_impact_count < MAX_IMPACTS)` | `cg_parsemsg.cpp:1800-1802` | direction flips after 64 flesh hits/frame | 1 line |
| — | **The truss** | `coop_ragdollTruss` | **inert for arm hits** (both braces touching pts 6/7 are inequality and slack) | — |

Two hypotheses named in the brief are **refuted with arithmetic**:

- *"the constraint solver shares the motion out until nothing is visible"* — **no.** 96.1% of a
  perpendicular displacement survives 6 iterations (§4.1). Only **axial** pushes are shared, at
  exactly 50% per link, and those become translation.
- *"the `ptPrev` carry erases the impulse's velocity"* — **no.** `pt` and `ptPrev` both move the same
  way, so `Δ(pt−ptPrev) = +0.15·a·d`; it adds. Disabling `RagShapeMatch` entirely changes the shipped
  result from 5.8° to 5.1° (§5.1).

---

## 11. THE ONE INSTRUMENT

**Goal:** in one playtest, one line per shot, separate *direction* from *solver* from *articulation
vs translation* — the three questions eleven rounds have been unable to tell apart.

### 11.1 State to add to `ragSim_t` (`cg_ragdoll.c:155-225`)

```c
    // R12 probe: one line per bullet, answers direction-vs-solver in a single playtest
    int    probeEnd;        // cg.time the window closes (0 = idle)
    byte   probeBone;       // bestJ
    vec3_t probeDir;        // the direction we were HANDED
    vec3_t probeAxis0;      // world drive direction of the struck bone at the instant of impact
    vec3_t probeRel0;       // pt[bestJ] - pt[0] at impact  (articulation baseline)
    vec3_t probePelvis0;    // pt[0] at impact              (translation baseline)
    float  probeV0, probeV1, probeVMax, probeAngMax, probeRelMax;
    short  probeSubs;       // substeps whose point speed stayed above 20 u/s
    byte   probeSub1;       // 1 once substep 1 has been sampled
```

### 11.2 Arm it — `CG_RagdollImpulse`, immediately after the `for (e = 0; e < 2; e++)` loop closes (`cg_ragdoll.c:1465`)

```c
{   // R12 probe arm
    int dch = s_ragDriveChild[bestJ];
    vec3_t vv;
    s->probeEnd  = cg.time + 600;
    s->probeBone = (byte)bestJ;
    VectorCopy(dir, s->probeDir);
    if (dch >= 0) VectorSubtract(s->pt[dch], s->pt[bestJ], s->probeAxis0);
    else          VectorSubtract(s->pt[bestJ], s->pt[bestP], s->probeAxis0);
    VectorNormalize(s->probeAxis0);
    VectorSubtract(s->pt[bestJ], s->pt[0], s->probeRel0);
    VectorCopy(s->pt[0], s->probePelvis0);
    VectorSubtract(s->pt[bestJ], s->ptPrev[bestJ], vv);
    s->probeV0 = VectorLength(vv) / subDt;
    s->probeV1 = s->probeVMax = s->probeAngMax = s->probeRelMax = 0;
    s->probeSubs = 0;  s->probeSub1 = 0;
}
```

### 11.3 Sample it — `CG_RagdollFrame`, inside the substep loop, immediately after `RagCollideWorld(s, subStart);` (`cg_ragdoll.c:1639`)

```c
if (s->probeEnd) {   // sample AFTER collide: this is the state the renderer will see
    int    b = s->probeBone, dch = s_ragDriveChild[b];
    vec3_t vv, ax, rel, dd;
    float  sp, c;
    VectorSubtract(s->pt[b], s->ptPrev[b], vv);
    sp = VectorLength(vv) / (RAG_SUBSTEP_MS * 0.001f);
    if (!s->probeSub1) { s->probeV1 = sp; s->probeSub1 = 1; }
    if (sp > s->probeVMax) s->probeVMax = sp;
    if (sp > 20.0f) s->probeSubs++;
    if (dch >= 0) VectorSubtract(s->pt[dch], s->pt[b], ax);
    else          VectorSubtract(s->pt[b], s->pt[s_ragBones[b].parent], ax);
    if (VectorNormalize(ax) > 0.01f) {
        c = DotProduct(ax, s->probeAxis0);
        if (c >  1.0f) c =  1.0f;
        if (c < -1.0f) c = -1.0f;
        c = (float)acos(c) * 180.0f / (float)M_PI;
        if (c > s->probeAngMax) s->probeAngMax = c;
    }
    VectorSubtract(s->pt[b], s->pt[0], rel);          // articulation only: pelvis removed
    VectorSubtract(rel, s->probeRel0, dd);
    if (VectorLength(dd) > s->probeRelMax) s->probeRelMax = VectorLength(dd);
}
```

### 11.4 Print it — `CG_RagdollFrame`, after the substep `while` loop, before the `RagSane` block (`cg_ragdoll.c:1646`)

```c
if (s->probeEnd && cg.time >= s->probeEnd) {
    vec3_t tr3;
    VectorSubtract(s->pt[0], s->probePelvis0, tr3);
    cgi.Printf("^~^~^ RAGDOLL probe ent=%d bone=%d dir=(%.3f %.3f %.3f) elev=%.0fdeg "
               "v0=%.0f v1=%.0f vmax=%.0f subs=%d ang=%.1fdeg artic=%.2fu trans=%.2fu "
               "rad=%.1f ctc=%d limp=%d state=%d\n",
               s->entnum, (int)s->probeBone,
               s->probeDir[0], s->probeDir[1], s->probeDir[2],
               (float)(-asin(s->probeDir[2] /
                        (VectorLength(s->probeDir) > 0.001f ? VectorLength(s->probeDir) : 1.0f))
                       * 180.0 / M_PI),
               s->probeV0, s->probeV1, s->probeVMax, (int)s->probeSubs, s->probeAngMax,
               s->probeRelMax, VectorLength(tr3), s->ptRadius[s->probeBone],
               (int)s->contact[s->probeBone], (int)s->limpMs[s->probeBone], s->state);
    s->probeEnd = 0;
}
```

Gate the three blocks on a new `coop_ragdollProbe` (`CVAR_TEMP`, default `"0"`, added alongside the
others in `RagCvars`, `cg_ragdoll.c:300-328`) so the whole instrument is a console keypress and
costs nothing when off.

### 11.5 How to read it — and what I predict it will say

| field | what it settles |
|---|---|
| `dir` + `elev` | **The whole stage-1 question.** Fire from three positions and compare. |
| `v0` | Confirms stage 2 (`force·k2·w`). Predicted **120-155** for a rifle. |
| `v1 / v0` | **Stage 6.** Below 0.35 → the collision resolve is the executioner. |
| `subs` | How many substeps stayed above 20 u/s. Predicted **0-1** shipped, **6-12** with a good direction. |
| `ang` | **The only number that matters to the eye.** < 8° invisible, > 25° obvious. |
| `artic` vs `trans` | **Articulation vs translation**, separated for the first time. `trans ≈ artic` means the body slid instead of moving a limb. |
| `state` | 1 = it was awake and `sleepMs` was not reset (stage 8); 2→1 = it took the wake path. |

**My prediction, stated up front so it can be falsified:**

```
^~^~^ RAGDOLL probe ent=NN bone=7 dir=(0.526 0.000 -0.851) elev=58deg
      v0=136 v1=25 vmax=136 subs=1 ang=5.8deg artic=0.77u trans=1.80u rad=1.0 ...
```

with **`dir` byte-identical on all three shots**, from three completely different angles. If `dir`
varies with the shot position, my stage-1 diagnosis is wrong and suspects 2/3/5 own the failure.

### 11.6 Acceptance test and rollback

**Test (one playtest, ~90 seconds):**

```
coop_ragdoll 1 ; coop_ragdollMode 1 ; r_ragdollDebug 1 ; coop_ragdollProbe 1
```

Kill one rifleman, wait for `RAGDOLL settle-armed`, then fire **one** rifle round into the same
forearm from each of three positions:

1. standing directly over the body (~30 u away) — predicts `startsolid`, `dir=(0.526 0 -0.851)`;
2. 200 u away at standing eye level — predicts *outside* the inflated box, `dir` = a negated
   axis-aligned face normal in the corpse's local frame (`±1 0 0` or `0 ±1 0`);
3. prone/crouched, level with the body, 100 u away — predicts inside the box again,
   `dir=(0.526 0 -0.851)`.

Then throw one grenade near a second corpse and look for
`RAGDOLL blowup ... reason=span` or `reason=leash` within ~200-400 ms — that confirms §5.3
independently.

**Pass:** three probe lines with an identical `dir` on shots 1 and 3.
**Rollback:** `coop_ragdollProbe 0` — one command, no rebuild, no behaviour change (the probe is
read-only; it writes only its own fields and never touches `pt`/`ptPrev`).

### 11.7 If the probe confirms the diagnosis — the fix queue, each with its own rollback cvar

| # | change | file | rollback |
|---|---|---|---|
| 1 | Send the **bullet direction** (`-vDir`, so the client's existing `VectorNegate` yields `+vDir`) instead of `trace.plane.normal` on `CGM_BULLET_8/9`. `vDir` is already normalised and in scope at `weaputils.cpp:2411-2413`. Wire cost unchanged (1 byte, 162 dirs, ≤9° error). **Note it also re-aims the blood spray — an improvement, since that vector is a constant today.** | `fgame/weaputils.cpp:2625` (+ `:2604` for `CGM_BULLET_6`? no — leave wall impacts alone) | `coop_bulletFleshDir 0` |
| 2 | `if (limpMs > RAG_IMPACT_LIMP_MS) limpMs = RAG_IMPACT_LIMP_MS;` at the top of `CG_RagdollImpulse` | `cgame/cg_ragdoll.c:1384` | none needed — it is a clamp to the documented range |
| 3 | While `limpMs[i] > 0`, do not annihilate the normal component; project onto the contact plane and keep tangential at ~0.9. Exempt limp points from the resting gate as well | `cgame/cg_ragdoll.c:1053-1060` | `coop_ragdollHitSlide 0` |
| 4 | **Rebase the goal**: when `limpMs[i]` falls to 0, write `goal[i]` from the pose the limb actually reached, so the shape-match holds the new silhouette instead of undoing the hit. This is the change that answers *"I want to shoot the body and it still has physics"* | `cgame/cg_ragdoll.c:1012-1019` | `coop_ragdollRebase 0` |
| 5 | Move `s->sleepMs = 0; s->lifeMs = 0;` out of the `if (s->state == 2)` guard | `cgame/cg_ragdoll.c:1542-1548` | — |

**Do fix 1 and fix 2 alone in the first build.** They are two lines between them, they are the two
findings with the largest measured effect, and running them without fixes 3-5 tells you exactly how
much of the remaining problem is direction and how much is solver — which is the next question, and
the one nobody has yet been able to ask cleanly.

---

## 12. WHAT I PROVED VS WHAT I INFER

**PROVED (read out of source, every link cited, arithmetic shown):**

- `LineSegmentToSphereIntersect` writes only `fraction`; `CM_TraceDeepSuccess` never writes `plane`;
  `CM_BoxTrace` memsets it; the startsolid path returns without assigning it; `SV_Trace` does no
  fix-up. Therefore the flesh-hit normal is either zero or the local-frame face normal of a
  144×144×96 box.
- `DirToByte((0,0,0)) == 0` and `bytedirs[0] = (-0.525731, 0, 0.850651)`.
- The corpse box is `(-32,-32,0)..(32,32,16)`, so the inflated box is `(-72,-72,-40)..(72,72,56)`.
- `RagShapeMatch` moves `pt` and `ptPrev` in the same direction, so it cannot subtract velocity.
- `k = 1 - limpMs/600` is unclamped and every caller but `iLarge 0` passes `limpMs > 600`, so alpha
  goes negative; the divergence rate and time-to-blowup are arithmetic.
- The sleep metric is the mean over 15 points, so a single limb needs >150 u/s to register; and
  `sleepMs` is reset only when `state == 2`.
- `s_ragDriveChild` and the anchor table route a forearm hit to a visible rotation of bones 5, 6
  and 7 — no swallow in `RagPush`.
- Both braces touching points 6/7 are inequality braces at slack length, so the truss is inert for
  an arm hit.

**MEASURED (faithful port of the shipped solver, synthetic supine pose, floor at z=0):**
5.8° vs 37.8° peak bone rotation for shipped vs horizontal direction; 25.1% substep-1 retention;
0% substep-2; gate-off makes no difference; shape-match-off makes no difference to the shipped case
but preserves 42.5° in the horizontal case; grenade relative deviation diverging to 36.6 u with
`limpMs 1200` vs ≤2.5 u clamped.

**INFERRED (reasonable, not proven — the probe settles all three):**

- That a player shooting a corpse he is standing over is in fact inside the inflated box (muzzle
  height vs box top +56 is close; `DEFAULT_VIEWHEIGHT` is 82 but the muzzle is a barrel tag, not the
  eye). If he is above it, the normal is the top face → straight down → **worse**, not better
  (measured: 5.8° and stop at 24 ms).
- That the synthetic supine pose is representative. The *ratios* are robust — they follow from
  restitution 0.1, friction 0.45 and a 58° incidence — but the absolute degrees are not a
  measurement of the game.
- That the grenade blowup trips `RagSane` in the live game specifically. The port's bounded synthetic
  pose kept the span under 200 u; the relative deviation and the 90-345 u/s mean-speed oscillation
  are unambiguous either way.

---

## 13. VERDICT

**The motion dies at stage 1 — the direction — and is buried at stage 6.**

The single most valuable line of code in this whole system is `weaputils.cpp:2625`, and it has been
sending the wrong quantity from a field that the flesh code path never fills in. Every round of
solver tuning since the impulses shipped has been tuning a solver that was being asked to push a
limb into the ground.

Confidence: **high** for stage 1 (the code path is short, every link is cited, and the zero-normal
→ `bytedirs[0]` mapping is deterministic and reproducible on paper). **High** for the relative
ranking of stages 4, 5 and 6 (each was isolated in the port by switching exactly one thing off).
**Medium** for the absolute degree figures, which depend on the synthetic pose.

The strongest single piece of supporting evidence is the user's own decisive test: with **every
brace off**, a body with no scaffolding at all still would not articulate. No solver-side hypothesis
survives that observation. A direction-side one explains it completely.
