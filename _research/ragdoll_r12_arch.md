# RAGDOLL R12 — THE ARCHITECTURE DECISION

**Lens:** what should we actually build. Not "what is broken today" (that is `ragdoll_r11_*`),
but "does the 15-point Verlet model have a ceiling, and is that ceiling below what the user asked
for".

**Read complete and current, 2026-08-20:**
`openmohaa-hzm/code/cgame/cg_ragdoll.c` (2176 lines) ·
`renderergl1/tr_ragdoll.cpp` = `renderergl2/tr_ragdoll.cpp` (196 lines, byte-identical) ·
`renderergl1/tr_model.cpp:849-861` (Hook A) and `:1819` (Hook B) ·
`cgame/cg_parsemsg.cpp:1770-1870`, `:2226-2250` (impulse entry) ·
`cgame/cg_public.h:165-205, 400-460` (import struct — every API below verified against it) ·
`fgame/weaputils.cpp:2596-2648, 3520-3551` · `fgame/sentient.cpp:3030-3100` ·
`fgame/actor.cpp:5464-5481` · `server/sv_world.c:555-623` · `qcommon/cm_trace_lbd.cpp:441-502` ·
`tiki/tiki_shared.h:419-422`.

**Measured from:** `_research/ragdoll_r9_session_live.log` (41 complete `RAGDOLL sleep` records).
The live log `G:/mohaa-gl2/home/maintt/qconsole.log` was re-copied and **contains zero `RAGDOLL`
lines** — it has rotated since the r11 session, so the 16:00-16:03 window r11 quotes is gone. All
numbers below are either re-derived from source arithmetic or read out of the archived r9 set.

**Prior art consumed, not repeated:** `ragdoll_r11_truss.md` §4 (the arm chain, step by step),
`ragdoll_r11_risk.md` §0 (the negative-alpha finding), `ragdoll_r11_solver.md`,
`ragdoll_r11_topology.md`, `ragdoll_r9_impact.md`. `.wolf/buglog.json` bug-1962 … bug-1975.

---

## 0. VERDICT IN FIVE LINES

1. The lead hypothesis is **CONFIRMED, and it is the smaller of the two blockers.**
2. The larger blocker is that `RagShapeMatch` is a rigid-pose attractor with a **19 ms half-life**
   (`cg_ragdoll.c:915-948`, `rag_stiff` 0.25/substep). Every bullet's effect is arithmetically
   guaranteed to be erased. The corpse is not a soft body with a hint of pose; it is the authored
   pose with a hint of softness.
3. **The measurement proves it, not the theory.** Over 41 bodies the median `drift` — the mean
   per-point deviation from the rigidly-refitted authored pose — is **0.7 u**, and 25 of 41 are
   under 1.0 u (`RAGDOLL sleep` lines, r9 log). After six seconds of "physics" the skeleton has
   changed shape by less than one inch. The settle branch is, empirically, an expensive identity
   function.
4. **A Verlet particle has no angular momentum.** The user's primary sentence — "the life comes
   out of their body, they fall lifeless in one direction or another, physics does the rest" —
   describes rotational dynamics under a lever arm. That is a rigid-body phenomenon. Ten rounds
   have been spent trying to synthesise it out of distance constraints; it is not in there.
5. **Recommend option C: per-bone rigid bodies.** ~900-1000 changed lines, all inside
   `cg_ragdoll.c`, **cgame.dll alone**, zero renderer change — because the renderer contract is
   *already* one absolute orientation+position per bone (`tiki_shared.h:419-422`), which is
   exactly a rigid body's state. Ship the ~20-line option-A patch first, in the same session, so
   the user gets a visible win while C is built.

---

## 1. WHAT I PROVED ABOUT THE CURRENT SYSTEM

Constants used throughout, all read from the file:
`RAG_SUBSTEP_MS 8` (`:58`) → `subDt = 0.008 s`; `RAG_DAMPING 0.98` (`:60`); `RAG_ITERS 6` (`:61`);
`RAG_CONTACT_RELAX 0.15` (`:64`); `RAG_IMPACT_RELAX 0.05` (`:65`); `RAG_IMPACT_LIMP_MS 600`
(`:66`); `coop_ragdollStiff` default 0.25 (`:311`); `sv_gravity` 512 → per-substep drop
`512 × 0.008² = 0.032768 u` (`:953`, `:971`).

### 1.1 The lead hypothesis — CONFIRMED, with the arithmetic

**The claim.** `RagResolveHit` (`:1038-1071`) contains a resting-contact branch that stops a slow
point dead on a floor; the bullet direction is the inward impact normal, which on a grounded corpse
points into the floor; therefore the impulse is destroyed on contact.

**Verified, clause by clause.**

*The direction is inward and points at the floor.* The server writes `trace.plane.normal` from the
bone-sphere hit (`cm_trace_lbd.cpp:296` `LineSegmentToSphereIntersect`, result routed through
`CM_TraceDeepSuccess:345-358`), emitted at `weaputils.cpp:2621-2627`. cgame then negates it —
`cg_parsemsg.cpp:1802` / `:1814` `VectorNegate(vEnd, vEnd)` — and passes it as `dir`. For a player
standing over a body lying on its back, the entry point is on the *top* of the bone sphere, so the
inward normal is ≈ (0,0,−1). **Proved.**

*The gate is where it was said to be.* `:1053`
```c
if (tr->plane.normal[2] > 0.7f && VectorLength(v) < 0.35f) {
    VectorCopy(pos, s->pt[i]);
    VectorCopy(pos, s->ptPrev[i]);   // pt == ptPrev  =>  velocity identically zero
```
`v` is the per-substep displacement, so `0.35 u/substep ÷ 0.008 s = 43.75 u/s`. **Proved.**

*The impulse starts above the gate, and dies anyway.* Current call sites are
`force = 150 + 70·iLarge`, `radius = 15 + 1.5·iLarge` (`cg_parsemsg.cpp:1808/1820/2232/2244`). The
distal end takes `force · k2 · w0` where `k2 = 1 − d/radius` (`:1435`) and `w0 = 0.80 + 0.20·t`
(`:1446`). A mid-forearm hit with a 3 u skin offset:

| iLarge | force | radius | distal Δv | u/substep |
|---|---:|---:|---:|---:|
| 0 | 150 | 15.0 | **108 u/s** | 0.864 |
| 1 | 220 | 16.5 | **162 u/s** | 1.296 |

Both clear the 43.75 u/s gate on the *first* substep, so the branch that fires is the elastic one:
```c
VectorScale(vn, -0.1f, vn);                                    // :1059  restitution 0.10
VectorScale(vt, (n[2] > 0.7f) ? 0.45f : 0.75f, vt);            // :1060  floor friction
```

- **Shot straight down at a grounded limb** (`dir` ≈ −z, contact normal ≈ +z): the whole impulse is
  normal. One contact removes **90 %** of it. 0.864 → 0.086 u/substep. The limb travels the ~1 u of
  free clearance the capture clamp left it (`:711-733` sets the collision half-extent to the
  clearance the authored pose already had, minus 1 u from the probe geometry) and stops. **Total
  visible travel ≈ 1 u ≈ 1 inch, inside 8 ms.** This is the user's "they don't really seem to move
  at all."
- **Shot sideways** (`dir` tangential): the point glides — a flat sweep parked 0.25 u proud
  (`:1043`) misses the floor until gravity closes the gap, ~4 substeps (r11 measured the same
  re-kill period independently). Each re-contact keeps 45 %. From 0.864: → 0.389 → 0.175, which is
  below 0.35, so the **second** floor contact stamps it dead. Two contacts. ~64 ms. Travel ≈ 4-5 u,
  and it is a **slide**, not a rotation. This is the user's "the body kinda just slowly slides."

*The contrast that names the problem.* Integrating the same impulse ballistically with only damping
and gravity — i.e. a limb **in free air** — gives a peak excursion of **8.9 u** (iLarge 0) to
**17.5 u** (iLarge 1). So the impulse is not too small in the abstract; it is **5-17× larger in
free air than on the ground**, and corpses are on the ground. **The lead hypothesis is confirmed:
world contact is destroying 80-95 % of every bullet's effect on a settled corpse.**

*One correction to the hypothesis as stated.* The 0.35 dead-stop is **not** the main killer for the
shipped force values — it only fires on the second contact. The main killer is the **restitution
0.10 on the normal component**, which is a single-substep 90 % loss and needs no gate at all. Fixing
only the gate (r11's `&& !s->limpMs[i]` clause, `ragdoll_r11_truss.md` §4.2) buys `+0.10 u` on their
own numbers. **The gate is a symptom; the contact model is the cause.**

### 1.2 The larger blocker: the pose attractor's 19 ms half-life

`RagShapeMatch` (`:915-948`) pulls every non-pelvis point toward `pt[0] + S·(goal[i] − goal[0])` —
the authored capture pose, rigidly re-anchored — by fraction `a` **every substep**:

```c
VectorSubtract(want, s->pt[i], d);
VectorMA(s->pt[i], a, d, s->pt[i]);                          // :940
VectorMA(s->ptPrev[i], a * rag_carry->value, d, s->ptPrev[i]); // :946
```

Offset decays as `(1−a)^n`. Half-lives:

| state | `a` | half-life |
|---|---:|---:|
| normal (`stiff 0.25`) | 0.2500 | **2.4 substeps = 19 ms** |
| in world contact (`×0.15`) | 0.0375 | 18 substeps = 145 ms |
| struck, t = 8 ms into the limp window | 0.0157 | 44 substeps = 350 ms |
| struck, t = 300 ms into the window | 0.1310 | 4.9 substeps = 39 ms |

Integrating the ramp `a(t) = 0.0125 + 0.000396·t` over the 600 ms window gives a cumulative decay
exponent of **9.85** → the excursion is reduced to **5 × 10⁻⁵** of its peak by the window's end;
73 % of it is gone by 200 ms.

**Consequences, all arithmetic, none observational:**

1. `goal[]` is written once, at capture (`:1984-1986`), and never again. **A corpse in this
   architecture can never take a new resting pose.** Not "rarely" — never. The attractor is
   unconditional and the only relaxations are bounded (contact ×0.15, limp for 600 ms).
2. Every bullet is a **twitch by construction**: peak at ~150 ms, 95 % erased by 400 ms. The user's
   word for it — "both twitch" — is the correct description of the designed behaviour.
3. The two things the user wants are **the same knob pulled in opposite directions**. Raise
   `coop_ragdollStiff` → the corpse holds a believable pose and reacts to nothing. Lower it → it
   reacts, and piles, because the only remaining shape authority is 14 distance links and 16 braces
   that are sign-blind (a distance constraint cannot tell a bent knee from a backwards one). The
   `coop_ragdollTruss 0` experiment the user ran is exactly this: with the truss off there is no
   shape authority except the attractor, so lowering the attractor was never on the table.

### 1.3 The measurement that settles it

41 complete `RAGDOLL sleep` records, r9 live session, `branch=settle`, `alpha=0.25`, `drive=1`:

| metric | min | median | max |
|---|---:|---:|---:|
| `drift` (mean per-point deviation from the refitted authored pose) | 0.1 | **0.7** | 9.1 |
| `contacts` (points touching the world at sleep) | 0 | 3 | 11 |
| `maxspd` (peak mean point speed, u/s) | 16 | 107 | 1611 |

- **25 of 41 bodies (61 %) finish under 1.0 u of drift.** The file's own comment predicted "~0 on
  flat ground, 5-20 u draped on geometry" (`:1761-1762`). The measured median is 0.7 u. The drape
  the settle branch exists to produce is **not happening**, and `drift` is precisely the right
  instrument because a rigid re-fit is divided out first — it measures shape change only.
- **8 of 41 bodies sleep with zero world contacts.** They are held in the animator's pose by the
  attractor, in mid-air, not resting on anything.
- **36 of 41 ride to the 6000 ms life cap** (`:1747`) rather than speed-sleeping: they jitter above
  10 u/s for six seconds and go nowhere.

**PROVED: the current system is a rigid transform of the authored pose with sub-inch deformation.**
Everything the last ten rounds tuned was tuning the last 0.7 u.

### 1.4 Two contaminants in the evidence base — both real, both must be cleared

**(a) The negative-alpha defect (r11's finding, independently re-verified here).** `:937`
computes `k = 1 − limpMs / 600`, but the call sites pass `limpMs` **larger than 600**:
`600 + 70·iLarge` for bullets (`cg_parsemsg.cpp:1808`) and `1200 + 70·n` for explosions (`:1867`).

| site | `limpMs` | `k` | effective `a` |
|---|---:|---:|---:|
| bullet iLarge 0 | 600 | +0.000 | +0.0125 ✔ |
| bullet iLarge 1 | 670 | −0.117 | **−0.0153** ✘ |
| bullet iLarge 3 | 810 | −0.350 | **−0.0707** ✘ |
| grenade | 1200 | −1.000 | **−0.2250** ✘ |

A negative `a` at `:940` pushes `pt` **away** from `want`. For a grenade this runs for 600 ms
(75 substeps) at −0.225: growth factor `1.225^75 = 4 × 10⁶`. That is a runaway, and the pelvis leash
(`:1229-1236`) is what catches it. **Every explosion observation the user has ever reported was
taken on a build where the pose attractor was a pose repeller.** 1-3 lines to fix (clamp `k` to
`[0,1]`, or store the granted window per point).

**(b) The leash is not a pure sanity net — it is a "the server disagreed" detector.** `RagSane`
compares `pt[0]` against `cg_entities[entnum].lerpOrigin` (`:1231`). But
`weaputils.cpp:3526-3550` gives every settled corpse in blast radius
`velocity += 300·fFrac` lateral and `+210·fFrac` vertical (`g_corpseImpulse`, default 1), and
`actor.cpp:5464-5481` adds up to another `420 ×` on an explosive kill. The server entity moves;
the sim points do not follow it (`RagPush` renders at the sim's world positions, `:1307-1334`).
So an explosion **manufactures** leash divergence. Both r11 blowups were `reason=leash` on grenaded
bodies, and that outcome is over-determined between (a) and (b). Either fix the leash to track the
server's *displacement* rather than its position, or exempt a body for ~1 s after an explosion.

### 1.5 The structural fact behind all of it

`s_ragBones` (`:73-92`) stores **positions only**. Bone *orientations* do not exist in the sim
state; `RagPush` (`:1274-1305`) manufactures them each frame from point directions —
`RagMat3FromTo(ref, dNow, S)` (`:1298`), then a change-of-basis sandwich
`conj = Ecap · S · Enow^T` (`:1302-1303`), plus the `s_ragDriveChild` table (`:100-116`) that
exists purely to pick which segment stands in for a bone's missing orientation.

**That synthesis layer is where three of the four historical defects lived** — bug-1963 (the
`rot0·S` frame mismatch), bug-1964 (capture-frame vs. current-frame conversion), bug-1966 (driving
bone *i* with the wrong segment). And the regression drill cannot see them: the file itself records
that `coop_ragdollTest 2` is "structurally blind to this (S = I kills the difference)" (`:98`).

Two consequences:

- **No angular momentum.** A particle chain carries linear momentum only. A body that "falls
  lifeless in one direction" is a torso rotating about a lever arm — a moment of inertia doing its
  job. There is no representation of that quantity anywhere in the file.
- **No angular limits.** Distance constraints are sign-blind. `s_ragBraces` (`:123-153`) is a
  16-strut truss trying to fake a joint limit with a scalar length, and the file's own comment on
  the truss cvar says why it fails: "the corpse is nearly rigid: a bullet anywhere slides the whole
  body instead of moving the limb, and kicking one leg drags the other" (`:320-325`).

---

## 2. THE FOUR OPTIONS, AGAINST THE CURRENT FILE

Goal (a) = per-limb reaction to bullets/blast on a corpse.
Goal (b) = physics owns the *fall*.

### A. Keep the particle model, fix the impact path

**Changes.** Clamp `k` to `[0,1]` at `:937`. Exempt limp points from the resting kill at `:1053`.
Raise restitution for limp points (the 0.10 at `:1059` is the real thief). Bias `dir` away from the
contact plane when the struck point is grounded — i.e. project out the into-floor component and add
a small +z, so a downward shot lifts the limb instead of pressing it. Sweep `force` and
`coop_ragdollStiff`.

**Effort.** ~20-30 lines, one file. **Ship unit: cgame.dll alone.** Rollback: `coop_ragdollStiff`
/ existing cvars, plus one new `coop_ragdollImpact 0`.

**What the user sees.** Bullets produce a visible limb kick of maybe 4-8 u instead of 1 u, and it
still returns to the authored pose in 300-600 ms. Grenades stop blowing bodies across the map and
start producing a coherent whole-body toss with limb flap on top.

**Ceiling, stated exactly.** Per-limb reaction on a grounded corpse is **achievable as a transient
and impossible as a state**. The attractor's half-life is 19 ms and `goal[]` is immutable; the limb
must return. Realism ceiling: *"the arm jumps when you shoot it."* Not reachable: a limb that stays
where the bullet put it, a corpse that changes shape, or anything about goal (b). **Satisfies (a)
partially. Satisfies (b) not at all.**

**Risk to what works.** Low, and it is the only option with genuinely low risk. Every change is
inside a bounded window (`limpMs != 0`) on one corpse.

### B. Particle model + the r11 package (feet, angular limits, per-limb softness)

The parallel effort is well advanced: `ragdoll_r11_topology.md` (feet as points 15/16 — the shin
currently has **no** simulated direction, `s_ragDriveChild[12] = s_ragDriveChild[14] = −1` at
`:113/:115`), `ragdoll_r11_solver.md` (19 limits, derived at capture), `ragdoll_r11_truss.md`
(dismantling the 16 braces), `ragdoll_r11_risk.md` (S0-S4 staging).

**Does it fix impact response?** *No, and r11 says so itself, with a measurement:* "deleting all 16
braces, at any force — **no change (±0.01 u)**" (`ragdoll_r11_truss.md` §4.2). Limits add no energy;
they remove illegal configurations.

**But it is the prerequisite that makes A's fix mean anything.** Limits are the only thing that can
hold a plausible pose *without* the attractor. With them you can drop `coop_ragdollStiff` from 0.25
toward 0.05, which multiplies the half-life by ~5 and lets a limb's new position persist for ~1 s
instead of 150 ms. **That is the whole value of B: it decouples "holds a pose" from "reacts".**

**Effort.** r11 estimates ~4 staged builds (S0-S3), several hundred lines, all in `cg_ragdoll.c`.
**Ship unit: cgame.dll alone.** Per-stage cvar rollback already designed.

**Ceiling.** Goal (a) becomes *"the arm moves and mostly stays."* Goal (b) still unreachable: even
with perfect limits, a chain of massless particles falling under gravity **sags**; it does not
topple, because there is no rotational inertia to carry it over. **Satisfies (a) well. Satisfies (b)
not at all.**

**Risk.** Medium-high. r11's own §5 asks "could the limits make it WORSE than today's
stiff-but-stable corpse?" and does not answer no. 19 limits derived per-model at capture is a large
new surface on a file with four historical convention defects.

### C. Replace the solver with per-bone rigid bodies

**What it is.** Each of 15-17 bones becomes `{ vec3 x; float R[3][3]; vec3 v, w; float invMass;
float invIiw[3][3]; }`. 14-16 ball joints solved by sequential impulse, plus cone/twist/hinge limits.
Contacts as impulses at a point, with Coulomb friction. This is what every shipping ragdoll since
2001 is.

**The thing that makes this cheaper than it sounds.** The renderer bridge already takes exactly this
data. `skelBoneCache_t` is `{ float offset[4]; float matrix[3][4]; }` (`tiki_shared.h:419-422`), and
`R_RagdollApplyToCache` (`tr_ragdoll.cpp:113-172`) writes one **absolute model-space
orientation + origin per channel**. A rigid body *is* an absolute orientation + origin.
**The renderer needs no change at all**, and `RagPush`'s entire synthesis layer — `RagMat3FromTo`,
the `Ecap·S·Enow^T` sandwich, `s_ragDriveChild`, `driveDir0/driveOk`, `restDir`, `rot0` as a
rotation *source* — **is deleted, not ported.** Two of the four historical defect classes
(bug-1963, bug-1966) become structurally unrepresentable, and the freeze drill stops being blind
(`:98`): with no synthesis, `coop_ragdollTest 2` exercises the same code path the sim does.

**Data layout (concrete).**
```c
typedef struct {
    vec3_t x, v;          // CoM world position / linear velocity
    float  R[3][3];       // world orientation, row-vector convention (matches the file)
    vec3_t w;             // angular velocity
    float  invMass;
    float  invI[3][3];    // world inverse inertia, refreshed per substep as R^T·Ibody^-1·R
    float  halfLen, rad;  // capsule: bone origin -> child, per-bone radius (s_ragPtRadius)
    vec3_t rBind[2];      // body-local anchors: this bone's joint, and its parent's
} ragBody_t;              // 128 B/bone × 17 × 8 sims = 17 KB — the sim struct SHRINKS
```
Mass from bone volume (`π r² L`, human density normalised so total = 1); `Ibody` = the analytic
capsule tensor. Bind anchors come straight out of the existing capture: `s->mat0[ch]` already holds
each channel's origin and axes in the exact space the push needs (`:584-594`).

**Solver loop (per substep, 8 ms):**
```
1. integrate         v += g·dt;  x += v·dt;  R = expmap(w·dt)·R;  renormalise every 4th substep
2. joints × 8-10 it  ball-socket at each child bone origin (3-DOF positional impulse)
                     + cone/twist limit (angular impulse when the relative rotation leaves the cone)
3. contacts          per bone, sweep both capsule ends (CM_BoxTrace, MASK_DEADSOLID, radius box);
                     normal impulse with Baumgarte push-out + Coulomb friction at the contact point
4. sleep             |v| and |w| below threshold for 1 s — the existing gate, one term added
```

**Per-frame cost, derived.** Steady state is 1-3 *awake* bodies (the existing `state == 2` sleep
already gates the loop, `:1601-1618`). Worst case 8 awake × 17 bones × 4 substeps:
- integration 544 × ~60 flops = 33 kflop
- joints 128 joints × 10 iters × 4 substeps = 5120 solves × ~120 flops = **614 kflop**
- limits ≈ same again ≈ 600 kflop
- **traces: 17 bones × 2 ends × 4 substeps × 8 = 1088/frame** vs. today's `15 × 4 × 8 = 480`
  (`:1109-1145`). At realistic 1-3 awake bodies that is 136-408 traces/frame — *below* today's
  worst case. ~1.3 Mflop/frame is ~0.05 ms on any CPU that runs this game.
**Cost is not the risk. Convention is.**

**What survives from the current 2176 lines** (this is the honest inventory):

| block | lines | fate |
|---|---:|---|
| header/tables/struct/cvars `:1-330` | 330 | survives, tables re-shaped |
| gravity, slot lookup, mat3 helpers, world↔capture `:333-534` | 200 | **verbatim** |
| `RagCapture` `:538-827` | 290 | **~95 % verbatim** — already captures per-channel orientations |
| `RagRawFit`/`RagBodyRotation*`/`RagShapeMatch`/`RagStep` `:840-1034` | 195 | **deleted** |
| collision `:1038-1197` | 160 | rewritten (same APIs), ~60 % structure kept |
| `RagSane` `:1199-1238` | 40 | **verbatim** (+ an angular-velocity term) |
| `RagPush` `:1240-1340` | 100 | **shrinks to ~50**, synthesis deleted |
| debug skeleton `:1345-1373` | 30 | verbatim |
| `CG_RagdollImpulse` `:1384-1556` | 173 | rewritten to ~90 — *simpler*: impulse at a point is `v += J/m; w += invI·(r × J)`; the whole segment-search / asymmetric-split / accumulation-clamp apparatus (`:1399-1478`) exists only to fake a lever arm and **is deleted** |
| frame loop `:1558-1814` | 256 | survives, `RagStep` call swapped |
| lifecycle / pending / transition `:1818-2176` | 358 | **verbatim** — the settle handoff, `RagServerParked`, the pending pool, the clear signals |

**≈ 1200 lines survive untouched; ≈ 900-1000 are new or rewritten.**

**What the user sees.** Shoot an arm: it swings about the shoulder, hits the ground, and **stays
there**. Shoot the head: it rolls. Grenade: limbs flail independently because each has its own
inertia. And goal (b) becomes reachable for the first time.

**Ship unit: cgame.dll alone** — with one caveat, §3.3.

**Satisfies (a) fully. Satisfies (b)** — the only option that does.

### D. Hybrid — particles for the drape, rigid bodies for struck limbs

**Verdict: strictly dominated by C. Do not build it.**

1. You must build **all** of C's machinery anyway — integrator, inertia tensors, joints, limits,
   contact impulses — and then add a two-way boundary at the shoulder/hip that C does not need.
2. The boundary can only realistically be one-way (particle torso drives the rigid arm root; the arm
   cannot push back), which means the torso never reacts — **that is the user's exact complaint**
   ("the body kinda just slides as a whole").
3. The renderer would be fed from **two orientation sources** — synthesised for particle bones,
   native for rigid bones. That seam is precisely the class that produced bug-1963/1964/1966. On a
   file with four convention defects, deliberately introducing a fifth convention boundary is the
   single worst available decision.
4. It does nothing for goal (b).

The *body-level* variant ("particles while settling, rigid when awake from an impact") has the same
objection plus a state-conversion step, and buys nothing C does not already have — C's own sleep
state is exactly "stop integrating", which is what the particle drape was doing anyway.

**The legitimate idea inside D is a rollout strategy, not an architecture**: build C behind
`coop_ragdollSolver` (0 = today's particles, 1 = rigid), keep both in the file for 2-3 sessions, A/B
live, then delete the loser. That is in the recommendation.

### Summary table

| | user sees | effort | ship unit | risk to what works | goal (a) | goal (b) |
|---|---|---|---|---|---|---|
| **A** fix impact path | limb jumps, returns in 300 ms | **20-30 lines** | cgame.dll | **low** | partial | **no** |
| **B** + feet/limits/softness | limb moves and mostly stays | ~400-600 lines, 4 builds | cgame.dll | medium-high | good | **no** |
| **C** rigid bodies | limb moves and **stays**; body falls | ~900-1000 lines, 4-6 builds | cgame.dll | **high** | **full** | **yes** |
| **D** hybrid | torso still inert | ≥ C | cgame.dll | **highest** | partial | no |

*(A dismissed fifth option, for the record: play a canned hit-reaction animation on the corpse. No
such anims exist in the TIKI set, and the user has already rejected the animated-corpse look —
bug-1965 is exactly that verdict.)*

---

## 3. RECOMMENDATION — C, staged, with A shipping first

### 3.1 Why C and not B

The user's request has two halves and they stated the *fall* first and at length. Option B cannot
deliver it at any amount of tuning, for a reason that is not a bug and cannot be patched: **there is
no angular momentum in the state vector.** A particle chain released in mid-air sags into a
catenary; it does not topple, twist, or carry a limb through an arc. Every "physics owns the fall"
attempt (mode 3, `:2162-2166`) failed for that reason, and bug-1965's diagnosis — "captured the
living pose" — is only the *first* reason it looked wrong.

B is also not free of C's central risk. Nineteen angular limits derived per-model at capture, in a
file that has had four space/convention defects, is a comparable convention surface to C's — and it
buys one of the user's two goals instead of both.

### 3.2 Staging — four builds, one live question each

Every stage is `cgame.dll` alone and has a one-command rollback.

| # | build | the one question | acceptance (live-observable) | rollback |
|---|---|---|---|---|
| **S0** | clamp `k` to `[0,1]` (`:937`); exempt `limpMs != 0` from the resting kill (`:1053`); leash exempt for 1 s after an explosion | *what does a clean impulse actually look like?* | grenade a corpse: no `RAGDOLL blowup reason=leash`, `stretch` stays ≤ 1.15 (r9 healthy band 1.01-1.09). User verdict on grenades. | `coop_ragdollImpact 0` |
| **S1** | rigid solver behind `coop_ragdollSolver 1`, **joints only, no limits**, shape-match retired on that path | *does the space contract hold?* | `coop_ragdollTest 2` renders a pixel-perfect soldier **on the new path**; `coop_ragdollSolver 1` + a fresh kill: the body is a recognisable soldier, no NaN, `span` 55-75 / 8-20 u | `coop_ragdollSolver 0` |
| **S2** | cone/twist/hinge limits + contact friction tuning | *does it hold a pose without an attractor?* | corpse settles in a plausible pose with **no** knee/elbow inversion; `drift` instrument replaced by a per-joint "limit violated" counter reading 0 | `coop_ragdollLimits 0` |
| **S3** | physics owns the fall: arm at the `EF_DEAD` edge, seed from the last flesh impact, **soft-leash the pelvis to `cent->lerpOrigin`** | *does it fall like a body?* | user verdict; corpse's final position within ~16 u of the server's parked origin | `coop_ragdollMode 1` (today's settle handoff) |

**S0 ships in the same session as S1's first commit.** It is 20-30 lines, it fixes a confirmed live
defect, and it gives the user something to look at while C is built. It is also the only way to know
what A's real ceiling is — which is the honest hedge against this whole recommendation (§4).

### 3.3 The one place the "cgame.dll alone" claim is soft

Goal (b) has a server coupling that no option escapes. While the death animation plays, the server
is still moving the corpse (`Actor::FinishedAnimation_Killed` → `BecomeCorpse`, then `droptofloor
64`), and the corpse's hit volume is the 64×64×16 slab. Corpse shots are traced against the
**server's** bone spheres (`sv_world.c:582` gates `SV_TraceDeep` on `tiki->a->bIsCharacter`, so a
corpse still gets bone-accurate hit locations — `cm_trace_lbd.cpp:444-502`), and those spheres sit
on the **server's animated pose**, not our simulated one.

So if the client ragdoll falls one way and the server's anim falls another, the visible body and the
shootable body diverge.

**S3's answer, and it keeps the ship unit at cgame.dll:** do not let the pelvis go free. Soft-leash
`x[pelvis]` to `cent->lerpOrigin + captured offset` with a spring, and let every other bone run
free. The server's own death anim + `droptofloor` then supplies a plausible *trajectory* while
physics supplies the *pose*. That is "the life comes out of their body" with the hit volume still
under the mesh. Going fully client-authoritative on the fall would require suppressing the server's
death anim (`game.dll`) and is a separate decision.

**Note that this coupling already limits corpse shooting today**, independent of any of this: the
coarse gate at `cm_trace_lbd.cpp:258-261` requires the ray to intersect the 64×64×16 slab before any
bone sphere is tested, so an outstretched arm or a head above `z = 16` on a sprawled corpse **is not
hittable at all**. Worth a separate look; it is a `game.dll` change (`Actor::BecomeCorpse` bounds).

### 3.4 Acceptance instruments to keep

`RagSane`'s span/leash/NaN ladder (`:1199-1238`), the coverage count (bug-1969: pendings vs. arms —
this is the highest-value regression signal in the file), the freeze drill, and the sleep line. Add
one: **`restdrift`** — distance from each bone's rest position to where it was 1 s ago. On today's
build that is ~0 by construction; on C it is the number that says whether the corpse actually
changed shape.

---

## 4. THE STRONGEST CASE AGAINST MY OWN RECOMMENDATION

**You have never once run a clean experiment, and you are proposing to rewrite the solver on the
strength of dirty data.**

The r11 finding is not a footnote. Every grenade observation the user has given — "lift the body up
and throw it slightly as a whole, individual limbs not really reacting" — was taken on a build where
`a = −0.225`, i.e. where the pose attractor was actively **repelling** all 15 points in lockstep,
which produces a coherent rigid drift and is *precisely* the symptom reported. And every bullet
observation was taken with the resting kill and restitution 0.10 both live and untouched. The
`coop_ragdollTruss 0` test — the one the user calls decisive — changed the one variable that r11
independently measured as worth **±0.01 u**. It was never going to show anything.

The A-package is **20-30 lines**: clamp `k`, exempt limp from the resting kill, raise limp
restitution, project the impulse off the contact plane, sweep force and stiffness. That is one
session. If it lands above the user's visibility threshold, C's entire justification collapses back
to goal (b) alone — and goal (b) may itself be satisfiable by something far cheaper than a rigid
solver (S3's pelvis-leash idea plus B's limits might read as "lifeless" well enough on a 2002 model
at 2002 draw distances).

**And the thing C destroys is not nothing.** Today's corpse looks *correct*. Median drift 0.7 u
means it is the animator's pose, and the animator's pose is by definition a good-looking dead body.
Coverage is 41/42, zero NaN, spin 0-3 °/s at rest. C throws away a guaranteed-acceptable look for a
tunable one, and **every real ragdoll's first live build looks worse than a good death animation**
— rubbery joints, feet through floors, the classic head-on-a-string. The user has already sat
through ten rounds and one build per session. C plausibly costs **six to ten more sessions of "it
looks worse than before"** before it crosses back over. That is a real risk of the user simply
switching `coop_ragdoll 0` off and never turning it back on, at which point ten rounds *and* C are
both sunk.

**The counter to the counter, stated so the user can weigh it:** A's ceiling is not a tuning
question, it is `(1 − 0.25)^n`. A twitch that returns is what A can produce, forever. If the user
looks at S0 and says "that is what I wanted", stop — genuinely stop, and do not build C. If they
say "closer, but the arm still snaps back", then the 19 ms half-life is the wall, and C is the only
thing on this list that removes it.

**S0 is therefore not a hedge. It is the experiment that decides between A and C, it costs one
session, and it should be run before a single line of C is written.**

---

## 5. WHAT I DID NOT VERIFY

- **Inferred, not proved:** that most user shots at corpses are downward. It follows from a
  standing player and a grounded body, but no log records the impact normals. `r_ragdollDebug`'s
  impulse line (`:1551-1554`) prints force/radius/limp but **not `dir`** — adding
  `n=(%.2f %.2f %.2f)` there is one line and would settle it in one session.
- **Inferred:** that the mesh's visual response to a bone rotation is faithful. The push is
  verified; the skinning is not, and the freeze drill cannot test it (`:98`).
- **Not measured:** the r11 session log is gone (live `qconsole.log` re-copied, 14 285 lines, zero
  `RAGDOLL` lines). All impulse-era numbers here are re-derived from source, not observed. The r9
  set predates the impulse work entirely — it has 41 sleeps and **zero** impulse lines.
- **Not costed:** `CM_BoxTrace` wall-clock per call. The 1088-traces/frame worst case for C assumes
  it is comparable to today's 480; if a short sweep is unexpectedly expensive, the mitigation is one
  sample per bone rather than two.
