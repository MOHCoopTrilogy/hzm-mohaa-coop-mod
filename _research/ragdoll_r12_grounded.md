# Ragdoll round 12 — THE GROUNDED CORPSE

**Lens:** every failing case the user reports is a body already lying on the floor. This
document studies only that situation, exhaustively, and ends with one build.

**Date:** 2026-08-20. **Sources:** `cg_ragdoll.c` as of 16:27 today (2176 lines, read in
full), `cg_parsemsg.cpp`, `weaputils.cpp`, `weapon.cpp`, `sv_world.c`, `cm_trace_lbd.cpp`,
`cm_trace.c`, `q_math.c`, `cg_public.h`, `ragdoll_r9_session_live.log` (41 bodies),
`.wolf/buglog.json` bug-1962…bug-1975.

---

## 0. VERDICT, in one paragraph

The lead hypothesis is **confirmed, and it is worse than stated**. The impulse direction we
receive for a flesh hit is not "the inward impact normal, coarse but usable" (the round-9
assumption, `ragdoll_r9_impact.md` §4.5). It is the face normal of a box inflated **40 units**
around the corpse, taken in the **corpse's own yaw-rotated local frame** and never rotated back
to world — and when the shooter's eye is inside that inflated box, which is every point-blank
shot, the plane is never written at all and the client receives a **fixed constant vector aimed
58° into the ground**. For the single most common test — a standing player closer than 111
units to a corpse — the direction is exactly `(0, 0, −1)`. Driven straight down, a grounded
limb travels **0.25 units for 16 milliseconds** before the collision resolve annihilates it.
That is the whole report: the corpse does not move because we are shooting it into the floor.

The resting-contact full stop *is* a suppressor, but a **secondary** one: switching it off
while leaving the direction broken takes the point-blank case from 1.75 u to 2.07 u. Fixing the
direction alone, changing nothing else, takes it from 1.75 u / 64 ms to 9.71 u / 272 ms.

---

## 1. WHAT IS PROVED vs WHAT IS INFERRED

| # | Claim | Status |
|---|---|---|
| 1 | The flesh-impact normal is produced by a `+40u` inflated box trace in the corpse's local frame and is never rotated back | **PROVED** — code path read end to end, §3 |
| 2 | A muzzle inside that inflated box yields `plane.normal == (0,0,0)`, which `DirToByte` encodes as index 0 | **PROVED** — `cm_trace.c:662-668`, `q_math.c:412-424`, arithmetic in §3.3 |
| 3 | `bytedirs[0]` is unreachable from any legitimate box-face normal, so index 0 is an unambiguous "no plane" sentinel | **PROVED** — enumerated all six axis normals, §3.3 |
| 4 | Shipped point-blank behaviour: a struck limb moves 0.25–1.75 u for 16–64 ms | **PROVED by arithmetic**, reproduced by a faithful solver model, §4.4. Not yet observed in a log — the impulse code has never run with `r_ragdollDebug 1` (no `RAGDOLL impulse` line exists in any log on disk) |
| 5 | ~6 of 15 points are in resting floor contact on a settled corpse; `contacts=` under-reports by 2.5× | **PROVED** — duty cycle measured at exactly 40.0 % from the code semantics, cross-checked against 41 live bodies, §2.2 |
| 6 | `RagShapeMatch` runs at **negative alpha** for the first 70–210 ms of every bullet hit and the first 600 ms of every explosion | **PROVED by arithmetic**, §5.1. Unobserved |
| 7 | The explosion "moves as a slab" is the negative-alpha divergence tripping `RagSane` and reverting to the authored pose, leaving only the server's `g_corpseImpulse` toss | **INFERRED** — consistent with the user's exact words and with `weaputils.cpp:3526`, but no `RAGDOLL blowup` line has been captured |
| 8 | The solver has no mass, so a hand and a pelvis respond identically | **PROVED** — `cg_ragdoll.c:984` splits every correction 50/50 |

---

## 2. INVENTORY OF THE RESTING STATE

### 2.1 Where a settled point actually sits

`RagResolveHit` places every resolved point at `tr->endpos + 0.25 * plane.normal`
(`cg_ragdoll.c:1043`). `tr->endpos` is where the point's ±`ptRadius` box first touched. So a
grounded point's **centre rests at `ptRadius + 0.25` above the surface**, and its box bottom
sits 0.25 u clear of it.

`ptRadius` is not the anatomical table. At capture (`cg_ragdoll.c:716-733`) each radius is
clamped to the clearance the authored pose already has:

```c
down[2] -= s_ragPtRadius[i] + 2.0f;
cgi.CM_BoxTrace(&tr, s->pt[i], down, tiny, tinyx, 0, MASK_DEADSOLID, qfalse);   // tiny = ±1
if (!tr.startsolid && tr.fraction < 1.0f) clear = (s_ragPtRadius[i] + 2.0f) * tr.fraction;
if (clear > s_ragPtRadius[i]) clear = s_ragPtRadius[i];
if (clear < 1.0f)             clear = 1.0f;
```

Because the probe box is ±1, `tr.fraction` stops the *centre* 1 u above the surface, so
`clear = (true clearance − 1)`. Net: a point the animator rested flush ends up with
`ptRadius = 1.0` and settles at **1.25 u**; a point with 6 u of authored clearance keeps
`clear = 5.0`. Anatomical maxima (`cg_ragdoll.c:248-254`): pelvis/spine1 7.0, spine2 7.5, neck
4.0, head 5.0, upper-arm 4.0, forearm 3.0, hand 2.5, thigh 5.0, calf 4.0.

**Consequence for this lens:** the sim's collision geometry is seated *at the animator's own
resting heights*. Every limb the animator drew touching the ground is, in the sim, touching the
ground — there is no clearance for it to swing through.

### 2.2 The contact[] duty cycle — measured, not guessed

`contact[i]` is set to 2 in `RagResolveHit` (`:1056`, `:1062` path also sets it) and decremented
once per substep at the top of `RagCollideWorld` (`:1109-1113`). A fully-stopped point then
free-falls under gravity until it re-touches. Gravity per substep is

```
g = sv_gravity · dt²  =  512 × 0.008²  =  0.032768 u/substep²
```

so falling the 0.25 u lift takes `n(n+1)/2 = 0.25/0.032768 = 7.63` → **n ≈ 3.4 substeps**. The
cycle is therefore 5 substeps long with `contact` non-zero for 2 of them.

Simulated with the exact code semantics (`scratchpad/duty.py`):

```
  hand 2.5      contact-flag duty=40.0%   height above surface 0.054..0.250u
  forearm 3.0   contact-flag duty=40.0%   height above surface 0.054..0.250u
  thigh 5.0     contact-flag duty=40.0%   height above surface 0.054..0.250u
  spine2 7.5    contact-flag duty=40.0%   height above surface 0.054..0.250u
  clamped 1.0   contact-flag duty=40.0%   height above surface 0.054..0.250u
```

**Duty = exactly 40 %, independent of radius.** The prior finding ("decays in two substeps,
re-armed only on a fresh resolve") is right; the number is 40 %, so a `contacts=N` snapshot
under-reports by **2.5×**.

Live cross-check, `ragdoll_r9_session_live.log`, 41 settled bodies:

```
contacts=  0:8   1:5   2:6   3:14   4:4   5:2   7:1   11:1      mean 2.51, median 3
```

`2.51 / 0.40 = 6.3`. **About 6 of the 15 points are in resting floor contact on a settled
corpse; the median body has 7.** The z-span distribution from the same 41 bodies is
4,5,5,5,6,6,6,7,7,7,8,8,8,9,10,10,10,11,11,12,12,12,14,14,14,17,17,17,20,25,26,31,31,31,32,32,
38,41,42,52,72 — median 12 u, i.e. the typical corpse is genuinely flat.

`ctcmax` (the peak instrument added in round 10) has **never produced a line**: no log on disk —
not the three archived sessions, not the live `G:/mohaa-gl2/home/maintt/qconsole.log`, not any
of the ~100 rotated logs — contains the string `ctcmax` or `sleep-rot`. The round-10
instruments have not yet been exercised. Numbers above come from the code, not from them.

### 2.3 Micro-bounce

A settled point is not still: it oscillates between **0.054 u and 0.250 u** above its touching
height, on a 5-substep (40 ms) period — a 25 Hz, 0.2 u tremor. Invisible on screen, but it means
the resting-contact full stop fires ~25 times per second per grounded point, and it is why the
sleep gate had to be raised from 4 to 10 u/s (`cg_ragdoll.c:1739-1742`).

---

## 3. THE DIRECTION — the actual root cause

### 3.1 What the server sends

`weaputils.cpp:2621-2627`, the only emitter of `CGM_BULLET_8` in the bullet path:

```c
gi.MSG_StartCGM(BG_MapCGMToProtocol(g_protocol, CGM_BULLET_8));
gi.MSG_WriteCoord(vTmpEnd[0]); … 
gi.MSG_WriteDir(trace.plane.normal);          // <-- 2625
```

`trace` comes from `G_Trace(..., "BulletAttack", true)` (`weaputils.cpp:2436-2438`) — the last
argument is `traceDeep`. For any entity whose tiki is a character, `SV_ClipMoveToEntities`
takes the location-based-damage branch (`sv_world.c:582-591`) and calls `SV_TraceDeep`.

### 3.2 `SV_TraceDeep` never writes a plane

`cm_trace_lbd.cpp:444-502`. The only thing that ever touches `results->plane` is the first
gate, `CM_TraceDeepSimple` (`:215-264`):

```c
vNewMins[0] = vEntMins[0] - 40.0;   …   vNewMaxs[2] = vEntMaxs[2] + 40.0;      // :234-239
clipHandle = CM_TempBoxModel(vNewMins, vNewMaxs, iEntContents);
AngleVectorsLeft(vEntAngles, vForward, vLeft, vUp);                             // :242
vTransStart[0] = DotProduct(vTemp, vForward); …                                 // :245-252
CM_BoxTrace(results, vTransStart, vTransEnd, vCntr, vCntr, clipHandle, iBrushMask, qfalse); // :256
```

Three separate defects compound here:

1. **The box is 40 u larger than the corpse on every side.** A parked corpse is
   `{-32,-32,0}..{32,32,16}` (`Actor::BecomeCorpse`, the same slab `RagServerParked` decodes at
   `cg_ragdoll.c:1889-1898`). Inflated: `{-72,-72,-40}..{72,72,56}`. The normal we send is a
   face of *that*, not of the body.
2. **The trace is done in the entity's local frame and the plane is never rotated back.**
   `CM_TransformedBoxTrace` does rotate its plane back (`cm_trace.c:1499-1500`); the raw
   `CM_BoxTrace` used here cannot, because the rotation was applied by hand to the endpoints.
   `CM_TraceDeepSuccess` (`:345-358`) writes `endpos/allsolid/startsolid/contents/entityNum/
   location/ent` — **not `plane`**. `SV_ClipMoveToEntities` copies the whole struct
   (`sv_world.c:619`) and `SV_Trace` returns it verbatim (`:840`). So a local `+x` face normal
   arrives at the client as world `+X`, wrong by the corpse's yaw.
3. **A muzzle inside the inflated box produces no plane at all.** `CM_BoxTrace` zeroes its work
   struct (`cm_trace.c:1287`), and `CM_TraceThroughBrush` on a start-inside case returns before
   any plane assignment:

   ```c
   if( !startout ) {              // original point was inside brush        cm_trace.c:661-668
       tw->trace.startsolid = qtrue;
       …
       return;                    // clipplane never stored -> trace.plane stays zero
   }
   ```
   `CM_TraceDeepSimple` explicitly *proceeds* on `startsolid` (`:258-263`), so the bone spheres
   still resolve the hit and the message is still sent — carrying a zero plane.

### 3.3 A zero plane is not delivered as zero

`DirToByte` (`q_math.c:404-425`) initialises `bestd = 0; best = 0;` and only updates on
`d > bestd`. Every dot product with `(0,0,0)` is 0, so it returns **index 0**.
`ByteToDir(0)` → `bytedirs[0]` = **`(-0.525731, 0.000000, 0.850651)`** (`q_math.c:77`). The
client then negates it (`cg_parsemsg.cpp:1802`), giving

> **dir = (+0.525731, 0.000000, −0.850651)** — a constant, 58.28° below horizontal, with
> **85 % of the impulse pointed into the floor**, regardless of where the shooter stands.

Enumerated to prove index 0 is a unique sentinel:

```
DirToByte (1,0,0)  -> 52     DirToByte (0,1,0)  -> 32     DirToByte (0,0,1)  -> 5
DirToByte (-1,0,0) -> 143    DirToByte (0,-1,0) -> 104    DirToByte (0,0,-1) -> 84
DirToByte (0,0,0)  -> 0   (= bytedirs[0], reachable no other way)
```

**No legitimate axis-aligned box face maps to index 0.** The sentinel is exact and safe to test
for on the client.

### 3.4 Which case fires when — the geometry

The bullet trace starts at the player's **eye**: `VectorCopy(player->m_vViewPos, position)`
(`weapon.cpp:1680`), and that `position` is `pos`, the first argument of `BulletAttack`
(`weapon.cpp:2085`). Viewheights (`bg_public.h:42-46`): standing 82, crouch-run 64, crouched
48, prone 16. The inflated box top is at local **z = 56**.

Aiming at a corpse's chest (z ≈ 8) from horizontal distance D, the ray crosses z = 56 at
fraction `(82−56)/(82−8) = 0.351`, leaving `0.649 D` of horizontal distance. Top-face entry
requires `0.649 D < 72` → **D < 111 u**.

| Shooter | Received `dir` (after the client's negate) | How often |
|---|---|---|
| Standing, **D < 111 u** (≈ 9 ft) | **`(0, 0, −1)`** — straight into the floor | the default way anyone tests this |
| Crouched or prone, within 72 u laterally | **`(0.5257, 0, −0.8507)`** — the `bytedirs[0]` sentinel, 58° into the floor | every close crouched shot |
| Standing, **D > 111 u** | horizontal, but **rotated by the corpse's yaw** — a coin flip | mid/long range |
| Any range, bottom face | unreachable (box floor is 40 u below the map floor) | never |

Note the top-face case has *no* yaw error — local `(0,0,1)` is world `(0,0,1)` — so it is
reliably, exactly, straight down. That is the worst possible outcome and the most common one.

### 3.5 What `cg_parsemsg.cpp` then does with it

```c
case CGM_BULLET_8:
    if (flesh_impact_count < MAX_IMPACTS) {       // MAX_IMPACTS 64, cg_parsemsg.cpp:48
        VectorNegate(vEnd, vEnd);                 // <-- 1802, INSIDE the if
        …
    }
    CG_RagdollImpulse(vStart, vEnd, 150.0f + 70.0f*iLarge, 15.0f + 1.5f*iLarge, 600 + 70*iLarge);
```

The negate is inside the array-bounds guard. Past 64 flesh impacts in one client frame the
ragdoll receives the **un-negated** vector — the exact opposite direction. Same defect at
`:1814`, `:2226`, `:2238`. Low frequency, trivial fix, but it is a real sign inversion.

---

## 4. THE RESTING-CONTACT FULL STOP — exactly what it can and cannot kill

### 4.1 The code

```c
static void RagResolveHit(ragSim_t *s, int i, const trace_t *tr)              // cg_ragdoll.c:1038
{
    VectorMA(tr->endpos, 0.25f, tr->plane.normal, pos);
    VectorSubtract(s->pt[i], s->ptPrev[i], v);
    d = DotProduct(v, tr->plane.normal);
    VectorScale(tr->plane.normal, d, vn);
    VectorSubtract(v, vn, vt);
    if (tr->plane.normal[2] > 0.7f && VectorLength(v) < 0.35f) {              // :1053
        VectorCopy(pos, s->pt[i]);
        VectorCopy(pos, s->ptPrev[i]);
        s->contact[i] = 2;
        return;
    }
    VectorScale(vn, -0.1f, vn);                                               // :1059 restitution
    VectorScale(vt, (tr->plane.normal[2] > 0.7f) ? 0.45f : 0.75f, vt);        // :1060 friction
    VectorAdd(vn, vt, v);
    VectorCopy(pos, s->pt[i]);
    VectorSubtract(pos, v, s->ptPrev[i]);
```

Two things matter and are easy to miss:

* the gate tests **`VectorLength(v)`, the full velocity**, not the normal component — so a
  point sliding purely tangentially at 0.34 u/substep (42 u/s) is stopped dead, tangential
  velocity and all;
* `0.35 u/substep = 43.75 u/s`, not 44 by coincidence — it is `0.35 / 0.008`.

### 4.2 What the impulse actually delivers

```
force  = 150 + 70·iLarge          → 220 at iLarge 1   (cg_parsemsg.cpp:1808)
radius = 15 + 1.5·iLarge          → 16.5
subDt  = 0.008
k2     = 1 − bestD/radius         → bestD ≈ 5 (the impact point is on a 5.5 u LBD sphere,
                                     cm_trace_lbd.cpp:52-53) → k2 = 1 − 5/16.5 = 0.697
w[0]   = 0.80 + 0.20·bestT        → 0.90 at bestT 0.5   (cg_ragdoll.c:1446)

Δ|ptPrev| = 220 × 0.697 × 0.90 × 0.008 = 1.104 u/substep = 138 u/s
```

The much-quoted "220 u/s" is the *ceiling* (`k2 = w = 1`, a shot exactly on the bone axis at
the distal end). The realistic delivery is **138 u/s = 1.104 u/substep**, i.e. **3.2× the
0.35 gate**, not 5×.

The proximal end takes `w[1] = 0.15·(1−bestT) = 0.075` → 11.5 u/s, and is skipped entirely when
`bestT > 2/3` (`if (w[e] < 0.05f) continue;`, `:1453`).

### 4.3 Which impulses the gate can kill — the arithmetic

The gate cannot kill the *first* substep of any bullet impulse: 1.104 > 0.35. What it kills is
what survives one or two floor contacts.

* **Tangential impulse.** Each floor contact multiplies it by 0.45. Starting at 1.104:
  1.104 → 0.497 → 0.224. **Two contacts and the gate closes.** With the 0.25 u lift and gravity
  0.0328 u/substep², contacts are ≈ 3.4 substeps apart, so the whole life of a horizontal
  impulse is ~7 substeps = **56 ms**.
* **Normal (into-floor) impulse.** Restitution 0.1 on the very first contact: 1.104 → 0.110,
  already below the gate. **One contact and it is over.** The gate does not even need to fire —
  restitution has done the work; the gate just tidies up.
* **Away-from-floor impulse.** Never touches the floor on the way up, so neither friction nor
  the gate applies. It decays only at `RAG_DAMPING 0.98` per substep and gravity, and lives
  ~130-290 ms.

**Conclusion for task item 2:** the gate can kill *any* tangential impulse below ≈ 2.2 u/substep
(275 u/s) within two floor contacts, and it kills everything with a normal component instantly
by proxy through restitution 0.1. It **cannot** touch an impulse aimed away from the floor.

### 4.4 A point pushed INTO the floor — trace by trace

Task item 2 asks specifically whether such a point start-solids, takes the settle release, or
takes the freeze path. **None of them.** Walking it:

1. Rest at `z = R + 0.25`. Impulse `(0,0,−1)` at 1.104 u/substep.
2. `RagStep` integrates: `z → R + 0.25 − 1.104 − 0.0328 = R − 0.887`. The box bottom is now
   0.887 u *below* the surface.
3. `RagCollideWorld` sweeps `subStart` (box bottom at **+0.25**, clear) → `pt`. **Not
   startsolid** — the 0.25 u lift guarantees the sweep starts outside. So neither the
   `!s->branch` freeze (`:1133-1134`) nor the settle release (`:1136-1137`) runs.
4. `tr.fraction = 0.25/1.137 = 0.22` → `RagResolveHit`. `|v| = 1.137 > 0.35`, so the friction
   path. `vt = 0`, `vn = −1.137 → +0.1137`. `pt` is snapped back to `R + 0.25`; the dip is
   never rendered.
5. Next substep the point rises 0.111 − 0.033 = 0.079 u; three substeps later it falls back,
   contacts at `|v| ≈ 0.11 < 0.35`, and is stopped dead.

**Net rendered motion: +0.08 u of rise, plus the 0.25 u reset, over ~3 substeps.** The
shape-match does nothing here: `want` is the authored resting position, the point is at the
authored resting position, so `d ≈ 0`.

### 4.5 The numbers, from a faithful model

`scratchpad/grounded.py` reimplements `RagStep` + `RagShapeMatch` + `RagCollideWorld` for one
point on a flat floor with every shipped constant. Forearm, R = 3.0, force 220, k2 0.697,
w 0.90:

| Case | peak displacement | horizontal travel | moving for |
|---|---:|---:|---:|
| **SHIPPED-1** standing D<111 → `(0,0,−1)` | **0.25 u** | 0.00 u | **16 ms** |
| **SHIPPED-2** crouched <72 u → `bytedirs[0]` | **1.75 u** | 1.75 u | **64 ms** |
| **SHIPPED-3** standing D>111 → horizontal | 5.65 u | 5.65 u | 96 ms |
| resting stop DISABLED, bad direction kept | 2.07 u | 2.07 u | 96 ms |
| shape-match OFF, bad direction kept | 1.79 u | 1.78 u | 64 ms |
| friction .95 / restitution .35, bad direction kept | 5.56 u | 5.56 u | 152 ms |
| 45° up + horizontal (direction fixed only) | **9.67 u** | 8.27 u | **272 ms** |

Read the last four rows as a controlled experiment. **Removing the resting stop buys 0.3 u.
Removing the shape-match buys nothing. Fixing the direction buys 5.5× the distance and 4.3× the
duration.** The user's own decisive test — `coop_ragdollTruss 0`, "no — they don't really seem
to move at all" — is explained: with the direction broken, no amount of loosening the body can
help, because there is nothing to loosen *toward*.

---

## 5. THE OTHER SUPPRESSORS

### 5.1 `RagShapeMatch` runs at NEGATIVE alpha — a hard defect

```c
if (s->limpMs[i] > 0) {                                            // cg_ragdoll.c:934-939
    float k = 1.0f - (float)s->limpMs[i] / (float)RAG_IMPACT_LIMP_MS;   // LIMP_MS = 600
    a *= RAG_IMPACT_RELAX + (1.0f - RAG_IMPACT_RELAX) * k;              // RELAX = 0.05
}
VectorMA(s->pt[i], a, d, s->pt[i]);
VectorMA(s->ptPrev[i], a * rag_carry->value, d, s->ptPrev[i]);
```

The callers pass windows **larger than `RAG_IMPACT_LIMP_MS`**:

| Caller | `limpMs` passed | `k` at t=0 | factor | `a` (alpha 0.25) |
|---|---:|---:|---:|---:|
| bullet, iLarge 0 (`cg_parsemsg.cpp:1809`) | 600 | 0.000 | +0.050 | +0.0125 |
| bullet, iLarge 1 | 670 | −0.117 | −0.061 | **−0.0152** |
| bullet, iLarge 3 | 810 | −0.350 | −0.283 | **−0.0706** |
| explosion, type 1 (`:1867-1869`) | **1200** | **−1.000** | **−0.900** | **−0.2250** |
| explosion, type 4 | **1410** | **−1.350** | **−1.233** | **−0.3082** |

Negative `a` means `pt += a·(want − pt)` moves the point **away** from its goal, amplifying the
deviation by |a| every substep. For an explosion that is `1.225^n`; over the 600 ms the window
stays above `RAG_IMPACT_LIMP_MS` (75 substeps) the amplification factor is
`e^(75·ln 1.225) = e^15.2 ≈ 4×10⁶`. The distance constraints cap the *lengths*, but nothing
caps a rigid rotation away from `goal`, so the limb spins off until `RagSane` trips on `span`
(200 u, `:1220`) or `leash` (128 u, `:1229-1235`) and the sim reverts to the authored pose
(`:1721-1722`).

**This predicts exactly what the user reports for grenades:** "lift the body up and throw it
slightly as a whole, individual limbs not really reacting" — a corpse frozen in its authored
pose, riding the *server's* `g_corpseImpulse` toss (`weaputils.cpp:3526-3538`, whose measured
throw is 121→441 u on open ground). **Inferred, not observed** — no `RAGDOLL blowup` line has
been captured, because `r_ragdollDebug` has never been on while the impulse code ran.

### 5.2 The pose pull reels a struck limb home in two frames

Even with the sign fixed, `goal[]` is frozen at the authored pose (`:1984-1986`) and
`RagShapeMatch` pulls every point back to a **rigid** copy of it. Once `limpMs` expires, alpha
returns to the full 0.25 per substep, and with 4 substeps per frame that is
`1 − 0.75⁴ = 68 %` of the gap closed **per frame**. A limb that swung 20 u is back within 2 u of
its authored position in **two frames (~33 ms)**.

That is the mechanism behind "it still seems like both twitch", and it is the single change
that stands between the current build and the user's stated goal — *"I want to be able to shoot
the body that is dead and it still has physics"*. A body cannot keep the damage you did to it
while the target silhouette is permanently the pose it died in.

### 5.3 Friction, restitution, sleep and the life cap

| Knob | Value | Site | Fights a struck limb? |
|---|---|---|---|
| floor friction | 0.45 tangential | `:1060` | **Yes** — two contacts (≈ 56 ms) kills any tangential impulse |
| restitution | 0.1 | `:1059` | **Yes, hardest** — 90 % of any into-floor impulse gone in one contact |
| resting-contact stop | `< 0.35 u/substep` on `n.z > 0.7` | `:1053` | **Secondary** — worth 0.3 u in isolation (§4.5) |
| damping | 0.98/substep | `:60` | No — 0.98⁵⁰ = 0.36 over 400 ms, gentle |
| velcap | 8 u/substep = 1000 u/s | `:318` | No — never binding at these forces |
| impulse result clamp | `force × 1.6` = 352 u/s | `:1457-1463`, `:1524-1533` | No for one hit; correct for magazine-dumping |
| **sleep gate** | **mean** point speed < 10 u/s for 1000 ms | `:1735-1746` | **Latent** — see below |
| life cap | 6000 ms per wake | `:1747` | No — reset on every impulse (`:1546`) |
| `RAG_ITERS` × equal-mass split | 6 iterations, 50/50 | `:974-987` | **Yes** — see §5.4 |

**The sleep gate is a mean over all 15 points and cannot see one moving limb.** A hand swinging
at 100 u/s contributes `100/15 = 6.7 u/s` to the mean — *below* the 10 u/s gate. Today this is
harmless only because nothing swings for long enough to matter; the moment the impulse is
fixed, it becomes a live suppressor that can freeze a body mid-swing 1000 ms after a hit.

### 5.4 There is no mass in this solver

```c
corr = (len - s->restLen[i]) * 0.5f / len;      // cg_ragdoll.c:984
VectorMA(s->pt[i], -corr, d, s->pt[i]);
VectorMA(s->pt[p], +corr, d, s->pt[p]);
```

Every correction is split 50/50. A hand and the pelvis have identical inertia. A kick at the
hand leaks `0.5³ = 12.5 %` of its displacement into the torso through three joints — which is
precisely "when I shoot one leg they both move… the whole body just kinda moves with it". The
quadratic falloff added at `:1500-1501` treats the symptom; the equal-mass constraint is the
cause. It also explains why the model shows **no difference at all between a hand (R 2.5) and
the spine (R 7.5)** under the same impulse.

---

## 6. WHAT IT SHOULD LOOK LIKE — concrete targets

Reference scale: a forearm is ≈ 11 u, an upper arm ≈ 12 u, a whole arm from shoulder to
fingertip ≈ 26 u, a thigh ≈ 18 u, shoulder-to-shoulder ≈ 24 u, hip-to-hip ≈ 18 u. One unit ≈
one inch.

| Scenario | Target | Rationale |
|---|---|---|
| **Rifle round into the forearm of a prone corpse** | the hand and forearm swing **12–20 u** about the elbow over **250–450 ms**, then stay roughly where they land (≤ 4 u of creep back). Upper arm moves ≤ 5 u; the torso moves ≤ 2 u; the far arm and both legs do not move at all. | The bone must rotate about its joint, and the limb must not drag the body. "Stay where they land" is the user's "it still has physics" requirement. |
| **Rifle round into the thigh** | the knee and calf swing **10–18 u** over **250–400 ms**; the pelvis moves ≤ 3 u; the *other* leg does not move. | Today both legs twitch — the equal-mass constraint plus the `{11,13}` thigh-thigh equality brace weld them. |
| **Rifle round into the torso** | the whole upper body **rocks 4–8 u** and returns to a *slightly different* rest, over **200–350 ms**. Arms trail by 3–6 u. No net translation of the corpse. | A torso hit legitimately should not throw a body; it should jolt it. Under-reacting here is correct — over-reacting is the "slides as a whole" complaint. |
| **Grenade beside a settled body** | the body **lifts 10–25 u**, rotates 30–90°, and lands in a visibly different pose; **individual limbs trail the torso by 15–30 u** during the flight and settle asymmetrically. Total motion 800–1500 ms. | The server's `g_corpseImpulse` already supplies the toss. What is missing is limb lag, which is what makes it read as a body rather than a prop. |
| **Any of the above, then walk away and come back** | the corpse is still in the pose the last bullet left it in. | This is the acceptance test for §5.2 (goal rebasing). |

Non-goals, explicitly: no corpse should **skid**. `scratchpad/grounded.py` case H (friction
0.95 with the resting stop permanently off) travels 16.5 u but never stops — 3.2 s of gliding.
That is the failure the resting stop was added to fix (`:1049-1052`) and it must not come back.

---

## 7. RANKED LIST — what suppresses a grounded limb's reaction

Ranked by measured contribution to the shipped point-blank case.

| # | Suppressor | Site | Measured cost | Sev |
|---|---|---|---:|---|
| **1** | **Impulse direction is aimed into the floor.** `(0,0,−1)` standing <111 u; the fixed `bytedirs[0]` sentinel crouched/prone; yaw-rotated horizontal beyond 111 u. | `cm_trace_lbd.cpp:234-256` + `weaputils.cpp:2625` + `q_math.c:412` | 9.67 u → **0.25 u** (39×) | **P0** |
| **2** | **Restitution 0.1** annihilates any into-floor component in one contact. | `cg_ragdoll.c:1059` | 90 % of the normal component per contact | **P0** |
| **3** | **`RagShapeMatch` negative alpha** for the first 70–210 ms of a bullet and 600 ms of an explosion — divergent, trips `RagSane`, reverts to the authored pose. | `cg_ragdoll.c:934-939` vs `cg_parsemsg.cpp:1809,1867` | explosions: total loss of limb motion | **P0** |
| **4** | **`goal[]` is frozen at the authored pose**, so the pose pull reels a struck limb home at 68 %/frame once `limpMs` expires. | `cg_ragdoll.c:1984-1986`, `:915-948` | turns any swing into a twitch | **P1** |
| **5** | **Equal-mass distance constraint** — no inertia anywhere; a hand kick leaks 12.5 % into the torso and the whole body slides. | `cg_ragdoll.c:984` | the "slides as a whole" report | **P1** |
| **6** | **Impulse pushes both bone ends the same way** — a net translation instead of a couple, so the limb drags the body instead of rotating. | `cg_ragdoll.c:1446-1448` | reinforces #5 | **P1** |
| **7** | **Floor friction 0.45** kills any tangential impulse in two contacts (≈ 56 ms). | `cg_ragdoll.c:1060` | 5.65 u → 2.5 u of the far-shot case | **P2** |
| **8** | **Resting-contact full stop** at 0.35 u/substep zeroes both `pt` and `ptPrev`. | `cg_ragdoll.c:1053-1058` | 0.30 u in isolation | **P2** |
| **9** | **Sleep gate is a mean** — cannot see one limb moving; latent once #1 is fixed. | `cg_ragdoll.c:1735-1746` | 0 today, blocking after the fix | **P2** |
| **10** | **`VectorNegate` inside the `MAX_IMPACTS` guard** — sign inversion past 64 flesh impacts/frame. | `cg_parsemsg.cpp:1802,1814,2226,2238` | rare, total | **P3** |
| **11** | The 16-brace truss makes the body near-rigid, so differential impulses are projected out. | `cg_ragdoll.c:123-153`, `:988-1010` | user already A/B'd with `coop_ragdollTruss 0`: not the cause | **P3** |

Note the ordering against the lead hypothesis: the resting-contact stop is real and worth
fixing, but it is **eighth**. Fixing it without fixing #1 buys 0.3 units.

---

## 8. THE BUILD — specific changes with values

Everything below ships as **one build**, defaults set to the recommended values, with a single
master cvar for rollback. `cgame.dll` carries fixes 2–10; `game.dll` carries fix 1. Both already
deploy together via `build.ps1`.

### FIX 1 (P0, `game.dll`) — send a direction that means something

`weaputils.cpp:2625`. `vDir` is in scope, normalized at `:2411-2413`.

```c
/* HZM coop r12: trace.plane.normal is USELESS for physics on a character hit. The LBD path
   (cm_trace_lbd.cpp:234-256) box-traces a bbox inflated 40u, in the ENTITY'S LOCAL FRAME, and
   never rotates the plane back (CM_TraceDeepSuccess writes no plane at all); point-blank the
   muzzle starts inside that box, CM_BoxTrace returns startsolid with the plane zeroed, and
   DirToByte(0,0,0) sends index 0 = bytedirs[0] - a constant 58 deg into the ground. Send the
   bullet's TRAVEL direction instead, negated so the client's own VectorNegate restores it.
   Only consumers are the blood puff (cg_parsemsg.cpp:1329) and CG_RagdollImpulse. */
{
    static cvar_t *pFD = NULL;
    Vector         vN;
    if (!pFD) { pFD = gi.Cvar_Get("g_fleshImpactDir", "1", CVAR_ARCHIVE); }
    if (pFD->integer) { vN = vDir * -1.0f; } else { vN = Vector(trace.plane.normal); }
    gi.MSG_WriteDir(vN);
}
```

Rollback: `g_fleshImpactDir 0`. Wire format unchanged (one byte either way), so no protocol
risk. `CGM_BULLET_9` has no emitter in this codebase — only `CGM_BULLET_8` needs changing, plus
optionally `Actor::EventDamagePuff` (`actor.cpp:6047`), which is script-driven and rare.

### FIX 2 (P0, `cgame.dll`) — client-side repair, so it works against any server

In `CG_RagdollImpulse`, before the segment search (`cg_ragdoll.c:1405`):

```c
static const vec3_t s_ragNullDir = { 0.525731f, 0.0f, -0.850651f }; /* -bytedirs[0] */
vec3_t useDir;
qboolean haveDir = qfalse;

if (dir && (dir[0] || dir[1] || dir[2])) {
    VectorCopy(dir, useDir);
    /* index 0 is unreachable from any legitimate box-face normal (all six map to
       52/143/32/104/5/84), so this vector is an exact "server had no plane" sentinel. */
    if (DotProduct(useDir, s_ragNullDir) > 0.999f || useDir[2] < -0.98f) {
        haveDir = qfalse;   /* degenerate: synthesize below */
    } else {
        haveDir = qtrue;
    }
}
if (!haveDir && dir) {
    /* fall back to the local view ray: always available, always plausible, never vertical. */
    VectorSubtract(pos, cg.refdef.vieworg, useDir);
    useDir[2] *= 0.35f;
    if (VectorNormalize(useDir) < 0.01f) { VectorSet(useDir, 1, 0, 0); }
    haveDir = qtrue;
}
```

`cg.refdef` is `refdef_t` at `cg_local.h:249` and `cg.refdef.vieworg` is already used in cgame
(`cg_beam.cpp:446`). No new import needed.

### FIX 3 (P0, `cgame.dll`) — ground projection at the struck point

A grounded limb cannot accept an impulse aimed into the floor; convert the floor's reaction into
lift instead of letting restitution eat it.

```c
#define RAG_GROUND_PROBE 4.0f
static qboolean RagPointGrounded(const ragSim_t *s, int i)
{
    trace_t tr; vec3_t down, pm, px;
    if (s->contact[i]) return qtrue;      /* 40% duty cycle, so also probe */
    VectorCopy(s->pt[i], down);
    down[2] -= s->ptRadius[i] + RAG_GROUND_PROBE;
    VectorSet(pm, -s->ptRadius[i], -s->ptRadius[i], -s->ptRadius[i]);
    VectorSet(px,  s->ptRadius[i],  s->ptRadius[i],  s->ptRadius[i]);
    cgi.CM_BoxTrace(&tr, s->pt[i], down, pm, px, 0, MASK_DEADSOLID, qfalse);
    return (!tr.startsolid && tr.fraction < 1.0f) ? qtrue : qfalse;
}
```
(`cgi.CM_BoxTrace` verified at `cg_public.h:177`.) Then, per struck point:

```c
if (rag_gkick->value > 0.0f && RagPointGrounded(s, q) && useDir[2] < 0.0f) {
    float dn = useDir[2];                       /* n = (0,0,1) for a floor */
    useDir[2] = 0.0f;                           /* drop the into-floor component ... */
    useDir[2] = -dn * rag_gkick->value;         /* ... and return part of it as lift */
    if (VectorNormalize(useDir) < 0.01f) { VectorSet(useDir, 0, 0, 1); }
}
```

`coop_ragdollGroundKick` default **0.60**. Effect: `(0,0,−1)` → `(0,0,+1)`;
`(0.5257,0,−0.8507)` → `(0.717, 0, 0.697)`. At most **≤ 3 traces per bullet** (the two driven
ends), negligible against the existing 240-trace budget.

### FIX 4 (P0, `cgame.dll`) — clamp the limp ease, one line

`cg_ragdoll.c:937`:

```c
float k = 1.0f - (float)s->limpMs[i] / (float)RAG_IMPACT_LIMP_MS;
if (k < 0.0f) { k = 0.0f; }   /* callers pass up to 1410ms (explosions) into a 600ms window;
                                 without this `a` goes NEGATIVE and the pose pull becomes a
                                 divergent 1.225^n push AWAY from the goal. */
```

Also raise `RAG_IMPACT_LIMP_MS` 600 → **1500** so the ease actually spans the explosion window
rather than clipping to zero for its first 600 ms.

### FIX 5 (P1, `cgame.dll`) — rebase the goal when the limp window expires

This is what makes damage persist. In `RagStep`'s limp tick (`cg_ragdoll.c:1012-1019`):

```c
for (i = 0; i < RAG_PTS; i++) {
    if (s->limpMs[i] > 0) {
        s->limpMs[i] -= RAG_SUBSTEP_MS;
        if (s->limpMs[i] <= 0) {
            s->limpMs[i] = 0;
            if (i > 0 && rag_rebase->integer) {
                /* The pose the corpse is pulled toward becomes the pose it actually ended up
                   in, so a struck limb STAYS where the bullet put it instead of being reeled
                   home at 68%/frame. Exactly zero pull at the rebase instant: substituting
                   back, want = pt[0] + (rel*S^T)*S = pt[i]. */
                float  S[3][3]; vec3_t cur, rel, cap;
                float  lim;
                RagBodyRotation(s, S);
                VectorSubtract(s->pt[i], s->pt[0], cur);
                RagMat3TransRotateVec(S, cur, rel);       /* rel = cur * S^T  (cg_ragdoll.c:449) */
                VectorSubtract(s->goal[i], s->goal[0], cap);
                lim = VectorLength(cap) * 1.35f;          /* bounded drift: the anti-pile
                                                             invariant must survive N hits */
                if (lim > 1.0f && VectorLength(rel) > lim) {
                    VectorNormalize(rel); VectorScale(rel, lim, rel);
                }
                VectorAdd(s->goal[0], rel, s->goal[i]);
            }
        }
    }
}
```

`RagMat3TransRotateVec` computes `out = v · m^T` (`:449-454`), the exact inverse of the
`RagMat3RotateVec` (`out = v · m`, `:441-447`) that `RagShapeMatch` uses at `:928`. Verified by
substitution above. `coop_ragdollRebase` default **1**.

### FIX 6 (P1, `cgame.dll`) — give the solver mass

```c
/* inverse mass: a hand must not move the pelvis. Ratios from a 70 kg adult's segment masses
   (pelvis+abdomen ~28%, thorax ~20%, thigh ~10%, shank ~4.5%, upper arm ~2.7%, forearm ~1.6%,
   hand ~0.6%, head+neck ~8%), normalized so the mean is 1.0 and the shipped 50/50 split is
   recovered when two neighbours match. */
static const float s_ragInvMass[RAG_PTS] = {
    0.35f, 0.45f, 0.45f, 0.85f, 0.70f,   /* pelvis, spine1, spine2, neck, head   */
    0.90f, 1.30f, 1.80f,                 /* L upperarm, forearm, hand            */
    0.90f, 1.30f, 1.80f,                 /* R                                    */
    0.70f, 1.00f,                        /* L thigh, calf                        */
    0.70f, 1.00f,                        /* R                                    */
};
```
Constraint (`cg_ragdoll.c:984-986`):
```c
if (rag_mass->integer) {
    float wi = s_ragInvMass[i], wp = s_ragInvMass[p], ws = wi + wp;
    corr = (len - s->restLen[i]) / len / ws;
    VectorMA(s->pt[i], -corr * wi, d, s->pt[i]);
    VectorMA(s->pt[p], +corr * wp, d, s->pt[p]);
} else {
    corr = (len - s->restLen[i]) * 0.5f / len;   /* shipped */
    …
}
```
Torso leakage from a hand kick: `1.30/(1.80+1.30) × 0.90/(1.30+0.90) × 0.45/(0.90+0.45)
= 0.419 × 0.409 × 0.333 = 5.7 %`, versus `0.5³ = 12.5 %` today — **2.2× better limb isolation**.
Scale the impulse by `s_ragInvMass[q]` too, so a hand takes more velocity from the same round
than a thigh. `coop_ragdollMass` default **1**.

### FIX 7 (P1, `cgame.dll`) — make the impulse a couple, not a push

`cg_ragdoll.c:1447-1448` and `:1453`:

```c
ends[1] = bestP;
w[1]    = -rag_couple->value * (1.0f - bestT);   /* NEGATIVE: a rifle round carries ~0.1 m/s of
                                                    momentum against an 80 kg body. Every bit of
                                                    visible ragdoll motion is ROTATION. Pushing
                                                    both ends the same way translates the limb
                                                    and drags the body - the "slides as a whole"
                                                    report. A counter-impulse at the proximal end
                                                    is a torque couple: pure rotation, zero net
                                                    momentum into the corpse. */
…
if (fabs(w[e]) < 0.05f) { continue; }            /* was w[e] < 0.05f - a negative weight would
                                                    have been silently dropped */
```
`coop_ragdollCouple` default **0.30** (0 = shipped behaviour).

### FIX 8 (P2, `cgame.dll`) — a softer floor, but only while limp

`RagResolveHit` needs the limp state, so pass it in or read `s->limpMs[i]`:

```c
qboolean limp = (rag_limpfloor->integer && s->limpMs[i] > 0);
if (tr->plane.normal[2] > 0.7f && VectorLength(v) < (limp ? 0.12f : 0.35f)) { …full stop… }
VectorScale(vn, limp ? -0.30f : -0.10f, vn);
VectorScale(vt, (tr->plane.normal[2] > 0.7f) ? (limp ? 0.80f : 0.45f) : 0.75f, vt);
```

**This cannot reintroduce skidding**, because it reverts the instant `limpMs` hits 0 and the
shipped 0.45/0.1/0.35 triple takes over — the model's runaway case (H, 3.2 s of gliding) only
occurs with the resting stop permanently disabled. `coop_ragdollLimpFloor` default **1**.

### FIX 9 (P2, `cgame.dll`) — force calibration, as a cvar

`cg_parsemsg.cpp:1808/1820/2232/2244`: replace the literal with a cvar read.

```
coop_ragdollHitForce   default 380   (shipped equivalent: 220 at iLarge 1)
```
i.e. `force = rag_hitforce->value * (0.68f + 0.32f * iLarge)` → 258 / 380 / 502 / 623.

Model output for the recommended stack (force 380, ground kick 0.60, limp floor on):

| Scenario | peak displacement | horizontal | moving for |
|---|---:|---:|---:|
| forearm, straight-down shot | 17.1 u | 0.0 u | 152 ms |
| forearm, crouched point-blank | 18.1 u | 14.6 u | 392 ms |
| forearm, standing far | 16.2 u | 16.2 u | 176 ms |
| thigh, mid-bone | 18.1 u | 14.6 u | 392 ms |
| hand, near the wrist (t = 0.9) | 23.1 u | 18.1 u | 416 ms |
| blast 30 u away (radial, force 400) | 20.4 u | 10.1 u | 384 ms |
| **no hit — does a settled point stay put?** | **0.25 u** | 0.00 u | 8 ms | ✅ |

That lands inside the §6 target band (12–20 u over 250–450 ms) on every case.

### FIX 10 (P2, `cgame.dll`) — do not sleep a body with a limb still moving

`cg_ragdoll.c:1742`:

```c
{
    int k, anyLimp = 0;
    float peak = 0;
    for (k = 0; k < RAG_PTS; k++) {
        vec3_t vk; float sk;
        if (s->limpMs[k] > 0) { anyLimp = 1; }
        VectorSubtract(s->pt[k], s->ptPrev[k], vk);
        sk = VectorLength(vk) / (RAG_SUBSTEP_MS * 0.001f);
        if (sk > peak) { peak = sk; }
    }
    if (peak > s->peakSpeed) { s->peakSpeed = peak; }   /* new acceptance instrument */
    /* the MEAN is blind to one limb: a hand at 100 u/s contributes 100/15 = 6.7 to it. */
    if (speed < 10.0f && peak < 30.0f && !anyLimp) { s->sleepMs += ms; } else { s->sleepMs = 0; }
}
```

### FIX 11 (P3, `cgame.dll`) — hoist the negate

`cg_parsemsg.cpp:1802`, `:1814`, `:2226`, `:2238`: move `VectorNegate(vEnd, vEnd);` **above** the
`if (flesh_impact_count < MAX_IMPACTS)` block. Past 64 flesh impacts in one frame the ragdoll
currently receives the exact opposite direction.

### FIX 12 (MANDATORY instrument) — log the direction

Without this the next session is still guessing. Replace `cg_ragdoll.c:1551-1554`:

```c
cgi.Printf("^~^~^ RAGDOLL impulse ent=%d pt=%d/%d t=%.2f d=%.1f raw=(%.3f %.3f %.3f) "
           "use=(%.3f %.3f %.3f) grnd=%d force=%.0f limp=%d v0=%.0f\n",
           s->entnum, bestJ, bestP, bestT, bestD,
           dir ? dir[0] : 0, dir ? dir[1] : 0, dir ? dir[2] : 0,
           useDir[0], useDir[1], useDir[2], (int)grounded, force, limpMs, v0);
```

A single log line then answers, permanently: which bone the round found, how far off-axis, what
direction arrived, what direction we used, whether the point was grounded, and what velocity it
got. `raw=(0.526 0.000 -0.851)` in the log is the §3.3 sentinel, visible at a glance.

---

## 9. ACCEPTANCE TEST AND ROLLBACK

**One master gate.** `coop_ragdollR12` (default 1) gates fixes 2–10 as a set; the individual
cvars stay available for tuning.

**Rollback, one command:**
```
coop_ragdollR12 0 ; g_fleshImpactDir 0
```
This restores byte-identical shipped behaviour (`RagPointGrounded` is never called, the direction
repair is skipped, `k` clamping is the only change that survives and it can only *reduce*
divergence).

**Live-observable acceptance, in order — 4 kills, ~3 minutes:**

1. `coop_ragdoll 1 ; r_ragdollDebug 1 ; developer 1`. Kill an AI, let it settle.
2. **Stand within 6 ft and shoot the forearm once.**
   - PASS: the forearm and hand visibly swing about the elbow — roughly a hand's length —
     and *stay* in the new position. The other arm and both legs do not move. The corpse does
     not slide.
   - Log must show `use=` with `|z| < 0.85` and `grnd=1`; `v0` ≈ 240.
   - FAIL diagnostic: `raw=(0.526 0.000 -0.851)` **and** `use=(0.526 0.000 -0.851)` means
     FIX 2/3 did not run — check `coop_ragdollR12`.
3. **Crouch and shoot the same forearm again.** Same result; the limb should end up further from
   the authored pose, not snapped back to it. That is FIX 5.
4. **Shoot the torso.** The upper body should rock and settle; the corpse must **not** translate
   more than a couple of inches. If it slides, lower `coop_ragdollHitForce` or raise
   `coop_ragdollCouple`.
5. **Grenade beside a settled corpse.** Limbs must trail the torso during the throw. No
   `^~^~^ RAGDOLL blowup` line may appear — if one does with `reason=span` or `reason=leash`,
   FIX 4 did not take.
6. **Walk away 10 s and come back.** The corpse is still in the shot-up pose.
7. **Regression:** kill 3 more AI without shooting the bodies. Every `RAGDOLL sleep` line must
   still show `drift` ≤ 1.0 and `maxspd` ≤ 120, and no body may skid. Watch for `peakspd` in the
   new sleep line — a settled body should read < 15.

**Tuning ladder if step 2 under-delivers:** `coop_ragdollHitForce` 380 → 500 → 620 (model:
23 u → 31 u). If step 4 over-delivers: `coop_ragdollCouple` 0.30 → 0.45.

---

## 10. WHAT THIS LENS DID NOT COVER

* **The truss / angular joint limits.** `coop_ragdollTruss 0` was the user's own A/B and it did
  not help — because the direction bug dominates. Once FIX 1–3 land, the truss experiment
  becomes meaningful again and should be re-run. The round-11 documents
  (`ragdoll_r11_truss.md`, `ragdoll_r11_solver.md`, `ragdoll_r11_topology.md`) are the input.
* **Whether the explosion inference (§5.1, table row 7) is right.** It is arithmetic plus the
  user's phrasing. FIX 12 plus one grenade in a debug session confirms or kills it in 30
  seconds; do that before building anything on it.
* **The 1 u understatement in the capture-time radius clamp** (§2.1): every point settles ~0.75 u
  below its authored height, and a point authored flush is lifted to 1.25 u. Both are sub-pixel
  and were not pursued.
* **`Sentient::CoopGoreCorpseDamage`** (bug-1975) deliberately applies no knockback. If the user
  later wants a server-authoritative limb hit, that is the hook — but round 9 §7 already ruled
  it out for cost, and nothing found here changes that.
