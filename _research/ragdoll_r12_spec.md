# RAGDOLL R12 — SPEC: making a shot corpse react

**Status:** buildable. **Target:** `openmohaa-hzm/code/cgame/cg_ragdoll.c`, `cg_parsemsg.cpp`,
`fgame/weaputils.cpp`. **Baseline:** HEAD `15a8f5c5` "fix: bullet impulses must ROTATE a limb, not
translate it" (2026-08-20 16:27:23).

Supersedes the recommendation sections of `ragdoll_r12_audit.md`, `_arch.md`, `_grounded.md`,
`_reference.md` and the four adversarial verifications. Where this document and those disagree, the
disagreement is named and the arithmetic is shown.

Reproducible harness for every number below:
`C:\Users\curry\AppData\Local\Temp\claude\C--mohaa-coop-dev\277135cf-ad44-4f7d-b2d4-b293580237c0\scratchpad\r12.py`
(+ `r12b.py`, `r12c.py`) — a 15-point replica of `RagStep`/`RagShapeMatch`/`RagCollideWorld`/
`RagResolveHit`/`CG_RagdollImpulse` with every constant read out of the file.

---

## 0. THE ANSWER — why limbs do not move

### 0.1 The unit

Twelve rounds have been judged in `drift=`, `span=`, `maxspd=` and adjectives. None of those is what
the eye watches. The renderer aims bone *i* with `normalize(pt[child] − pt[i])` measured against the
captured direction `driveDir0[i]` — `cg_ragdoll.c:1286-1299`, and `RagMat3FromTo(ref, dNow, S)` at
`:1298` turns exactly that pair into the bone's rotation. **The angle between those two vectors is
the whole of what a limb visibly does.** Everything below is measured in it.

### 0.2 The measurement

Rifle round (`force 220`, `radius 16.5`, `limp 670` — `cg_parsemsg.cpp:1808`) into the middle of a
settled corpse's left forearm, 1.5 u off the bone axis. Peak swing of that forearm over 1.5 s:

| case | forearm swing | vs control |
|---|---:|---:|
| **control — never shot at all** | **0.05°** | — |
| **SHIPPED, standing shooter inside ~111 u** | **2.34°** | ×47 |
| SHIPPED, crouched / point-blank | 5.00° | ×100 |
| SHIPPED, `coop_ragdollTruss 0` (the user's own decisive A/B) | **2.35°** | ×47 |
| with the real bullet direction | 10.05° | ×201 |
| **+ torque-couple impulse (this spec, `c = 0.6`)** | **21.1°** | ×422 |

A 2.34° swing on a 14 u forearm moves the hand **0.57 u** — about a third of a pixel at normal
viewing distance, and less than the 1.34 u the pelvis drifts on its own while settling. **That is
the whole answer: a rifle round into a settled corpse today produces a limb motion smaller than the
corpse's own idle settle noise.** The user is not misperceiving. There is nothing to see.

Note the fourth row. `coop_ragdollTruss 0` — the experiment whose result ("no, they don't really
seem to move at all") the maintainer took as decisive evidence against the loose-body hypothesis —
measures **2.35° against 2.34°**. It was not a null result about the truss. It was a null
*experiment*: run under an impulse direction that makes every solver knob null. The same is true of
`coop_ragdollStiff`, of `coop_ragdollCarry`, and of the force constant.

### 0.3 The mechanisms, ranked by how much motion each destroys

---

#### **RANK 1 — the "bullet direction" is not a bullet direction. It is one of three constants.** *(costs 77% of the available swing: 10.05° → 2.34°)*

**PROVEN**, end to end, from source. Every link:

1. The flesh-impact message writes the *trace plane normal*:
   `fgame/weaputils.cpp:2625`, `gi.MSG_WriteDir(trace.plane.normal)`, inside the
   `trace.location >= 0 && ent->IsSubclassOfSentient()` branch.

2. A corpse takes the **bone-accurate deep-trace** path. `Actor::BecomeCorpse` sets
   `SOLID_BBOX` + `CONTENTS_WEAPONCLIP` and the slab `(-32,-32,0)..(32,32,16)`
   (`fgame/actor.cpp:12492-12494`); `MASK_SHOT_TRIG` contains `CONTENTS_WEAPONCLIP`
   (`fgame/bg_public.h:651-653`); `BulletAttack` traces with `G_Trace(..., "BulletAttack", true)`
   — the trailing `true` is *deep* (`weaputils.cpp:2435-2437`); and `sv_world.c:582`
   (`if (clip->traceDeep && touch->tiki && touch->tiki->a->bIsCharacter)`) routes it to
   `SV_TraceDeep`.

3. **`SV_TraceDeep` never writes a bone normal into `plane`.** Its only plane writer is the coarse
   pre-test `CM_TraceDeepSimple` (`qcommon/cm_trace_lbd.cpp:215-264`), which
   - inflates the entity box by **+40 u on every axis** (`:234-239`) — the corpse's 64×64×16 slab
     becomes a **144×144×96 box**, `(-72,-72,-40)..(72,72,56)`;
   - rotates the ray endpoints into the corpse's **yaw-local frame** by hand (`:242-252`) and calls
     raw `CM_BoxTrace` (`:256`) — **never rotating the resulting plane normal back to world**
     (contrast `CM_TransformedBoxTrace`, `cm_trace.c:1498-1507`, which does).

   The per-bone sphere test that follows writes **only `fraction`**
   (`LineSegmentToSphereIntersect`, `:111-171`), and `CM_TraceDeepSuccess` (`:345-360`) writes
   `endpos/allsolid/startsolid/contents/entityNum/location/ent` — **not `plane`**. So the coarse
   AABB face normal, in the corpse's local frame, is what reaches `MSG_WriteDir`.

4. `PF_MSG_WriteDir` is `DirToByte(dir)` → one byte (`server/sv_game.c:368-372`), and
   `DirToByte` opens `bestd = 0; best = 0;` with a **strict** `d > bestd`
   (`qcommon/q_math.c:412-421`) — so a **zero** vector returns index 0, and
   `bytedirs[0] = (-0.525731, 0, 0.850651)` (`q_math.c:75-76`).

5. The client reads it and negates: `cgi.MSG_ReadDir(vEnd)` (`cg_parsemsg.cpp:1777`),
   `VectorNegate(vEnd, vEnd)` (`:1802` / `:1814`), then
   `CG_RagdollImpulse(vStart, vEnd, ...)` (`:1808` / `:1820`).

**Therefore the client receives exactly one of three constants**, chosen by geometry:

| shooter geometry | face hit | `dir` delivered |
|---|---|---|
| standing, horizontal range **< 111 u** | inflated **top** face | **exactly `(0, 0, −1)`** — straight into the floor |
| muzzle **inside** the 144×144×96 box (crouched at 48 u eye; prone; corpse on a ledge above you) | none — `startsolid`, plane left zeroed | **`(0.5257, 0, −0.8507)`** — 58.28° down, always toward world +X |
| standing, range **> 111 u** | a **side** face | a world axis (`±1,0,0` / `0,±1,0`) — **in the corpse's yaw frame**, read as world |

Crossover re-derived: eye `(D,0,82)` → chest `(0,0,8)`; `DEFAULT_VIEWHEIGHT 82`,
`CROUCH_VIEWHEIGHT 48` (`bg_public.h:42,45`); the fire origin is the eye
(`Weapon::GetMuzzlePosition`, `weapon.cpp:1680`, `VectorCopy(player->m_vViewPos, position)`).
Top face at local z = +56 is crossed at `t = (82−56)/74 = 0.35135`; lateral offset there is
`0.64865 D`, which stays inside ±72 while **D ≤ 111.0 u**. Corpse angles are yaw-only, so local +Z
is world +Z and `(0,0,1)` round-trips through `bytedirs[5] = (0,0,1)` losslessly.

**Why this alone destroys the reaction:** a settled corpse lies on the ground. `(0,0,−1)` drives the
struck limb *into* the floor, where the swept-box collision has ≈1 u of travel before `RagResolveHit`
takes 90% of the normal component (`VectorScale(vn, -0.1f, vn)`, `cg_ragdoll.c:1059`). Measured
result: 2.34°, i.e. nothing.

**This is a vanilla MOHAA defect, not an HZM regression** — retail's deep-trace path never filled
`plane` either. Independent field corroboration: on 2026-08-19 the user asked for blood to "shoot
upwards when they get hit" because the along-the-normal puff read wrong, and the fix bolted a
*synthetic* upward vector onto it (`coop_bloodSpurtUp 40`, `cg_parsemsg.cpp:1334-1348`). A constant
`(0,0,−1)` puff on every close-range flesh hit is exactly that symptom, reported independently a day
before anyone looked at the trace.

---

#### **RANK 2 — the impulse still translates the bone instead of rotating it.** *(costs a further 60%: 21.1° → 10.05°)*

HEAD `15a8f5c5` identified the right disease and under-dosed the cure. `cg_ragdoll.c:1445-1448`:

```c
ends[0] = bestJ;  w[0] = 0.80f + 0.20f * bestT;
ends[1] = bestP;  w[1] = 0.15f * (1.0f - bestT);
```

Both weights are **positive**. A mid-segment hit (`bestT = 0.5`) delivers `w = (0.90, 0.075)` — a net
linear impulse of **0.975** of the force with a differential of only 0.825. The proximal end is
"nearly planted" by *weight*, but nothing anchors it: the parent link is a two-way 50/50 projection
(`corr * 0.5`, `:984-986`), so the six Gauss-Seidel iterations immediately drag the joint along
behind its child. The bone translates, and translation is what the renderer is blind to — `RagPush`
reads only `normalize(pt[child] − pt[i])`, which a pure translation leaves unchanged.

The fix is a **torque couple**: `w[0] = 1 + c`, `w[1] = −c`. Net linear impulse is preserved exactly
at `1.0`; the differential rises from 0.825 to `1 + 2c`. Because the two ends move in opposite
directions along the same axis, a couple about the segment midpoint **preserves link length to first
order**, so the distance constraint does not fight it — which is why it converts into angle instead
of being eaten.

Measured, `c` swept with the accumulation clamp scaled (see §4, this matters):

| `c` | true bullet, standing 60 u | shipped `(0,0,−1)` | sentinel 58° | stretch |
|---:|---:|---:|---:|---:|
| 0.0 *(≈ HEAD)* | 10.96° | 2.71° | 6.93° | 1.021 |
| 0.3 | 14.33° | 1.70° | 15.28° | 1.024 |
| **0.6** | **21.14°** | **17.37°** | **37.65°** | **1.024** |
| 0.8 | 26.52° | 26.08° | 47.55° | 1.024 |
| 1.0 | 30.96° | 32.83° | 51.47° | 1.024 |

Two things fall out of this table that no lens reported:

- **The couple works even before the direction is fixed** (`(0,0,−1)`: 2.71° → 17.37°). A couple
  rotates the bone about its own midpoint; the floor can absorb the *linear* part and the rotation
  survives. The two fixes are therefore genuinely independent levers, and shipping both is not
  redundancy.
- **`stretch` does not move** (1.021 → 1.024, against a healthy band of 1.01–1.07 and a blowup gate
  at span 200 u). The couple is free of the instability that killed rounds 8–10.

---

#### **RANK 3 — the pose attractor erases whatever survives, with a ~19–32 ms half-life.** *(bounds every reaction to <500 ms and guarantees a return to the animator's pose)*

`RagShapeMatch` (`:915-948`) pulls every non-pelvis point toward `pt[0] + S·(goal[i] − goal[0])` with
`alpha = coop_ragdollStiff 0.25` per 8 ms substep. `goal[]` is written **once**, at
`cg_ragdoll.c:1985`, and read at `:927` and `:1767` — nowhere else in 2176 lines. The pose is
immutable. A struck point gets `RAG_IMPACT_RELAX 0.05` easing back to full over
`RAG_IMPACT_LIMP_MS 600` (`:66`, `:934-939`); a contacting point gets `RAG_CONTACT_RELAX 0.15`
(`:64`, `:931-933`).

Measured decay of the forearm swing after a single round (`c = 0.6`, real direction):

```
   0 ms   5.5°      120 ms  22.0°      400 ms   2.7°
  40 ms  18.8°      200 ms  15.2°      600 ms   0.6°
  80 ms  24.2°  ←peak                 1200 ms   1.2°
```

**This is not why limbs do not move today** — at 2.34° there is nothing to snap back from. It is why
they will not *stay* moved after Stage 1, and it is the direct answer to the user's second sentence:
*"I want to be able to shoot the body that is dead and it still has physics."* A half-second swing
that returns home is a flinch, not physics. Removing that ceiling is **Stage 2**, and it is a
separate, riskier change — see §7.

---

#### **RANK 4 — every grenade observation the user has ever given was taken on a corpse whose ragdoll had already killed itself.** *(explosions: 100% loss)*

`cg_ragdoll.c:937`:

```c
float k = 1.0f - (float)s->limpMs[i] / (float)RAG_IMPACT_LIMP_MS;   // denominator 600
a *= RAG_IMPACT_RELAX + (1.0f - RAG_IMPACT_RELAX) * k;
```

Nothing clamps `k`. The explosion path passes `limpMs = 1200 + 70·(iType − CGM_EXPLOSION_EFFECT_1)`
= **1200 / 1270 / 1340 / 1410** (`cg_parsemsg.cpp:1867-1869`). Re-derived:

```
limp 1200 -> k = 1 - 2.000 = -1.000 -> factor 0.05 + 0.95(-1.000) = -0.9000 -> alpha = -0.2250
limp 1410 -> k = 1 - 2.350 = -1.350 -> factor 0.05 + 0.95(-1.350) = -1.2325 -> alpha = -0.3081
```

A negative alpha inverts `pt += a·d`: the error `e` from the pose grows as `e' = (1 − a)e = 1.225 e`
**per substep**. Over the 1200 ms window (75 substeps): `1.225^75 = e^(75 × 0.20294) = e^15.22 =
4.07 × 10⁶`. **The pose attractor becomes a pose repeller.**

Simulated blast (force 400, radius 180, limp 1200, origin 50 u from the pelvis), gates as shipped
(`RagSane`, `:1219-1236`: span 200 u, pelvis leash `coop_ragdollLeash 128`):

| | peak span | peak pelvis excursion | stretch | outcome |
|---|---:|---:|---:|---|
| `k` unclamped **(shipped)** | 69.6 u | **181.1 u** | 1.48 | **trips the 128 u leash** |
| `k` clamped at 0 | 48.5 u | 27.8 u | 1.03 | survives |

Tripping `RagSane` sets `s_ragNeverArm[entnum] = 1` and calls `CG_RagdollClearEnt`
(`:1721-1722`) — **permanent for that body**. From that instant the corpse is a rigid server-posed
mesh, and the only thing still moving it is the server's own `g_corpseImpulse` toss. That is,
verbatim, the user's report: *"lift the body up and throw it slightly as a whole, individual limbs
not really reacting."*

Cross-check: `ragdoll_r12_arch.md`'s independent replica measured 160.6 u for the same case; mine
measures 181.1 u. Two independently written models, same conclusion, ~12% apart.

---

#### **RANK 5 — the whole-body slide is a settle artifact, not an impulse artifact.**

`RagShapeMatch` loops `for (i = 1; ...)` (`:924`) and targets `pt[0] + S·(goal[i] − goal[0])`
(`:927-929`). The pelvis is never pulled and the attractor is anchored to it, so the construction is
**translation-invariant**: the entire authored silhouette rides wherever the pelvis wanders. Only
`coop_ragdollLeash 128` bounds it (`:1229-1236`).

But the measurement says it is not the bullet's doing. Pelvis displacement over 1.5 s:

| | pelvis slide |
|---|---:|
| control, never shot | 1.34 u |
| shipped, one round | 1.38 u |
| this spec, `c = 0.6`, one round | 1.80 u |
| this spec, **ten rounds** 200 ms apart | 6.42 u |

Ten rounds is 6.4 u against a 128 u leash — a 20× margin, and the accumulation ceiling at `:1457`
is doing its job. **"The body kinda just slowly slides as a whole" is what the corpse does while it
settles, with or without being shot.** It is real, it is worth fixing, and it is Stage 3 — but it is
not competing for the same budget as "the arm doesn't move".

---

#### **RANK 6 — cross-body coupling: real arithmetic, small measured effect.**

Six of the sixteen braces are **equality** braces (`s_ragBraceMinFactor[0..5] == 0`,
`cg_ragdoll.c:145-153`), including `{11,13}` thigh↔thigh, `{5,8}` shoulder↔shoulder and the two
torso crosses `{5,13}`/`{8,11}`. The inequality skip at `:1004-1005` does not apply to them, so each
transfers 50% of any separation error in one iteration (`corr = (len − braceLen) * 0.5 * tstiff /
len`, `:1007`), six iterations per substep.

Measured on the thigh (the user's "when I shoot one leg they both move"):

| | struck L thigh | far R thigh | ratio |
|---|---:|---:|---:|
| shipped | 7.84° | 0.80° | 0.10 |
| + couple 0.6 | 20.03° | 1.40° | 0.07 |
| + cross braces halved | 20.44° | 1.64° | 0.08 |
| + `coop_ragdollTruss 0` | 31.32° | 0.57° | 0.02 |

**The far leg moves 7% as much as the struck one. This is no longer the defect the user described.**
It was — before `663bd1bd` made bullets target the bone *segment* and `cad7efcb` localized the
radius. The complaint predates both. The braces barely load in a swing, because a 20° thigh rotation
changes the thigh↔thigh distance almost not at all (the motion is perpendicular to the brace).
`ragdoll_r12_grounded.md` §C1 is arithmetically correct about the constraint and empirically wrong
about its consequence; this spec demotes it accordingly.

---

#### **RANK 7 — the maintainer's lead hypothesis: half right, and not the executioner.**

*Hypothesis:* the resting-contact full-stop in `RagResolveHit` (`:1053-1058` — a point on a floor
moving under 0.35 u/substep ≈ 44 u/s has `pt` **and** `ptPrev` set to the contact position, killing
all velocity including the tangential component) is what kills a grounded limb's reaction.

**Confirmed:** the direction really does point into the floor. That half of the premise is exactly
right, and it is the thread that led to Rank 1.

**Refuted:** the gate is not the mechanism.

- The impulse arrives at `220 × k2 × w × subDt`. With `bestD ≈ 3.5 u` on a 5.5 u forearm sphere,
  `k2 = 1 − 3.5/16.5 = 0.788`; with `w[0] = 0.90`, `Δv = 220 × 0.788 × 0.90 = 156 u/s =
  1.25 u/substep` — **3.6× above the 0.35 gate.** The gate cannot fire on the first contact.
- What fires is restitution: `VectorScale(vn, -0.1f, vn)` (`:1059`) removes 90% of the normal
  component in one substep, and `RagResolveHit` reseats the point at `endpos + 0.25·normal`
  (`:1043`) plus `SURFACE_CLIP_EPSILON`, so the point is ejected ~0.375 u clear and **glides for
  several substeps with no contact at all**. Traced per-substep, the gate first fires at substep 6,
  by which time the solver has already removed ~94% of the injected speed.
- Direct A/B: shipped `(0,0,−1)` gives 2.34°; `coop_ragdollTruss 0` gives 2.35°; disabling the gate
  entirely (in the replica) buys ~0.2–0.3 u of excursion. All three are inside the noise of a 0.05°
  control.

**Operational consequence: do not touch `cg_ragdoll.c:1053-1058`.** It is bug-1962's fix, it is
what lets bodies speed-sleep instead of micro-skidding off ledges for their whole 6 s life, and it is
provably not in the path. Every lens that attacked it was attacking a bystander.

---

### 0.4 The fact that governs everything below

**There has never been a single live measurement of any impulse behaviour.**

- The impulse feature landed at **14:12:45** (`27f90ff1`); segment targeting at 16:03 (`663bd1bd`);
  the asymmetric distal drive at **16:27:23** (`15a8f5c5`).
- The three archived sessions carry 165 / 200 / 88 `^~^~^ RAGDOLL` lines and **zero**
  `RAGDOLL impulse` lines. The newest is 12:48 — 84 minutes *before* the feature existed.
- The live log `G:/mohaa-gl2/home/maintt/qconsole.log` (1.22 MB, mtime 16:27) contains **zero**
  `RAGDOLL` lines of any kind.
- The deployed `G:\mohaa-gl2\cgame.dll` has mtime 16:27, and HEAD is authored 16:27:23 — its own
  commit message cites the 16:25 `coop_ragdollTruss 0` result as motivation. **The user's decisive
  verdict was rendered against `a0122287`, whose impulse used the symmetric split
  `w = (bestT, 1−bestT)`. HEAD's asymmetric distal drive has never been run live.**

Every number in this document, and in all four lens reports, is a model. That is why **Stage 1 ships
the instrument in the same build as the fix**, and why the acceptance test in §5 is written to
falsify §0.3 rather than to confirm it.

---

## 1. ARCHITECTURE VERDICT

> **KEEP the 15-point particle solver and extend it. Do not replace it.**

The defect is not in the solver. It is in the **two lines that hand the solver its input**: a
direction that carries no information (Rank 1) and a weight pair that produces translation instead of
rotation (Rank 2). A replaced solver fed the same `(0,0,−1)` would move a forearm 2.34° as well.

The solver's own measured health is good: coverage 41/42 kills, rotation after landing 0–28°, spin at
rest 0–3°/s, stretch 1.01–1.07, zero NaN, median `drift` 0.7 u across 41 bodies. Four of the five
historical ragdoll defects (bug-1963/1964/1966 in `RagPush`, bug-1962 in collision ordering) were in
the synthesis and collision layers, not the particle integrator. It works.

**Rejected, one sentence each:**

- **Per-bone rigid bodies (14 boxes + joints).** The renderer bridge genuinely favours it — `R_SetRagdollPose`
  takes one absolute orientation + origin per channel (`tiki_shared.h:419-422`,
  `tr_ragdoll.cpp:113-172`), which *is* a rigid body — but it is a two-to-three-week rewrite that
  discards the four rounds of stability work encoded in bug-1962/1963/1964/1966 and trades a
  guaranteed-acceptable look (the animator's pose, median drift 0.7 u) for a tunable one, to fix a
  defect that lives upstream of the solver entirely.
- **Impulse-only, no solver (script the limb).** Cannot produce secondary motion, cannot collide,
  and reduces to the flinch this spec already gets in Stage 1 — at the cost of the drape that
  currently makes corpses land correctly on geometry.
- **Full articulated-body dynamics (Featherstone / Bullet).** No migration path, no budget, and the
  renderer bridge would still be the only integration point; the project has no evidence it needs
  joint torques rather than a working impulse.
- **Revert to server-authored death poses (no ragdoll).** Throws away a working 98% coverage
  feature to avoid fixing two lines.

**The one thing the verdict does buy:** because the solver stays, `RagPush`, `RagCapture` and the
capture-space contract are **untouched in every stage of this spec**. The F7 freeze drill remains a
valid proof, and the four space-contract defects cannot recur.

---

## 2. BUILD SEQUENCE

Four stages. Each answers exactly one question. **Nothing from a later stage may be smuggled into an
earlier one** — the reason twelve rounds produced no signal is that every build changed several
things under a null experiment.

| stage | the ONE question | ships |
|---|---|---|
| **1** | *Does a struck limb move at all?* | direction + torque couple + the swing instrument |
| **2** | *Does it STAY where the bullet put it?* | tracking goal rebase |
| **3** | *Does the body stop moving as one lump?* | pelvis anchoring / brace decoupling |
| **4** | *Can physics own the fall itself?* | mode 4 — death impulse as a torque seed |

---

### STAGE 1 — "Does a struck limb move at all?"

**Deliverable:** the smallest change that produces a *visible* limb reaction, shipping with the
instrument that proves it numerically.

**IN (five items, one build):**

| # | change | file | lines |
|---|---|---|---|
| 1A | server sends the real bullet travel direction | `fgame/weaputils.cpp` | ~6 |
| 1B | client sanity net — reject the three degenerate signatures | `cg_ragdoll.c` | ~28 |
| 1C | torque-couple impulse + couple-scaled accumulation clamp | `cg_ragdoll.c` | ~10 |
| 1D | clamp `k` at 0 | `cg_ragdoll.c` | 3 |
| 1E | the swing instrument | `cg_ragdoll.c` | ~40 |

**OUT — explicitly excluded from Stage 1:**
`goal[]` rebasing · any brace change · any change to `RagResolveHit`'s resting gate, restitution or
friction · any change to `coop_ragdollStiff`, `Carry`, `Slew`, `VelCap`, `Leash` defaults · raising
`force` · `RAG_IMPACT_LIMP_MS` · the sleep gate · `RagPush` / `RagCapture` / the space contract ·
server-side corpse bbox or hit-sphere changes · anything in `renderergl1` / `renderergl2`.

---

#### 1A — the server sends a direction that means something

`fgame/weaputils.cpp`, the `CGM_BULLET_8` emit at **`:2625`**.

`vDir` is the **true normalized bullet travel direction including spread**, built at `:2411-2413`
(`vDir = vTraceEnd − start; VectorNormalizeFast(vDir);`) inside the same `for (i = 0; i < count; i++)`
pellet loop — it is already in scope at the emit site. The client negates what it receives
(`cg_parsemsg.cpp:1802`), so the server writes the **negated** travel direction and the client's
existing negate restores it.

```c
                            // HZM coop R12 - THE FLESH IMPACT DIRECTION.
                            // trace.plane.normal is MEANINGLESS on this path: SV_TraceDeep's only
                            // plane writer is its coarse pre-test (cm_trace_lbd.cpp:256), a
                            // CM_BoxTrace against the entity box INFLATED 40u on every axis and
                            // traced in the corpse's own YAW-LOCAL frame, never rotated back;
                            // CM_TraceDeepSuccess (:345-358) then overwrites endpos/location and
                            // leaves plane untouched. The client therefore receives exactly one of
                            // three constants: (0,0,-1) from the top face inside ~111u, bytedirs[0]
                            // (0.53,0,-0.85) when the muzzle is INSIDE the inflated box, or a raw
                            // world axis in the CORPSE's frame beyond that. vDir is the real
                            // travel direction (:2411) and is already in scope. Wire-neutral:
                            // PF_MSG_WriteDir is DirToByte -> 1 byte (sv_game.c:368) either way.
                            {
                                static cvar_t *pFD = NULL;
                                if (!pFD) { pFD = gi.Cvar_Get("g_fleshImpactDir", "1", CVAR_ARCHIVE); }
                                if (pFD->integer) {
                                    Vector vFleshDir = vDir * -1.0f; // client negates on receipt
                                    gi.MSG_WriteDir(vFleshDir);
                                } else {
                                    gi.MSG_WriteDir(trace.plane.normal);
                                }
                            }
```

*(replacing the bare `gi.MSG_WriteDir(trace.plane.normal);` at `:2625` — the `CGM_BULLET_8` branch
**only**. Leave `CGM_BULLET_6` / `_7` / `_10` / `_11` alone: those are wall impacts, where the
surface path fills `plane` correctly.)*

**Blast radius: exactly one other consumer.** `flesh_impact_norm[]` is read only by
`sfxManager.MakeEffect_Normal` at `cg_parsemsg.cpp:1331`, `:1354`, `:1377`. Today it receives a
constant; after this it receives the bullet direction — which is what a blood puff should follow,
and which makes the `coop_bloodSpurtUp 40` hack (`:1339`) redundant rather than broken. `Vector`
converts to `float*` implicitly (`vector.h`), so `gi.MSG_WriteDir(vFleshDir)` compiles.

`Actor::EventDamagePuff` (`fgame/actor.cpp:6040-6046`) is a second `CGM_BULLET_8` emitter with a
script-supplied direction; it is rare and correct already. Left alone.

---

#### 1B — the client rejects the three signatures anyway

Stage 1A fixes the server, but a client must survive an unpatched server, a mid-build mismatch, and
`Actor::EventDamagePuff`. Insert in `CG_RagdollImpulse` **after** the segment search succeeds
(so `bestJ` and `pt[0]` are known) and **before** the `for (e = 0; e < 2; e++)` loop at `:1449`:

```c
            // R12 - THE INCOMING DIRECTION MAY BE A BOX FACE, NOT A BULLET. See 1A: the server's
            // flesh normal is one of three constants unless g_fleshImpactDir is on. Detect all
            // three and derive a direction from the BODY instead - never from cg.refdef.vieworg,
            // which is the local viewer's eye and would kick a teammate's shots toward MY camera.
            vec3_t useDir;
            int    subbed = 0;
            VectorCopy(dir, useDir);
            if (rag_hitdir->integer) {
                static const vec3_t sentinel = {0.525731f, 0.0f, -0.850651f}; // -bytedirs[0]
                float                ax = (float)fabs(useDir[0]);
                float                ay = (float)fabs(useDir[1]);
                float                az = (float)fabs(useDir[2]);
                if (az > 0.98f                                    // top / bottom face
                    || DotProduct(useDir, sentinel) > 0.999f      // zero plane -> bytedirs[0]
                    || (az < 0.02f && (ax > 0.98f || ay > 0.98f)) // side face, corpse-local
                ) {
                    VectorSubtract(pos, s->pt[0], useDir); // outward from the pelvis through the hit
                    useDir[2] += 0.20f;                    // ... with a small lift: a limb pushed
                    if (VectorNormalize(useDir) < 0.01f) { // straight down has ~1u of travel before
                        VectorSet(useDir, 0, 0, 1);        // the floor eats it (bug-1970's clamp)
                    }
                    subbed = 1;
                }
            }
```

then use `useDir` in place of `dir` at `:1456`. The substituted vector is derived from the corpse's
own geometry, so it tends to be **perpendicular** to the struck limb — the most effective possible
lever arm, and measurably *more* dramatic than a real bullet (replica: 99° vs 26.5° at `c = 0.8`).
Scale it down when it fires:

```c
                    float useForce = subbed ? force * 0.60f : force;
```

`0.60` is a first guess and it is the number `swing=` exists to correct. It is a fallback for a path
that 1A makes rare; do not tune it before the log says it fires.

---

#### 1C — the torque couple

Replace `cg_ragdoll.c:1445-1448`:

```c
                // R12 - A COUPLE, NOT A SPLIT. HEAD's w = (0.80+0.20t, 0.15(1-t)) is two POSITIVE
                // pushes: net linear 0.975, differential 0.825, and the parent link (a 50/50
                // two-way projection, :984-986) drags the proximal end along behind its child
                // within one iteration - the bone TRANSLATES, and RagPush reads only
                // normalize(pt[child]-pt[i]), which a translation leaves unchanged. Driving
                // (1+c, -c) keeps the net linear impulse at exactly 1.0 while raising the
                // differential to 1+2c, and a couple about the segment midpoint preserves link
                // length to first order, so the distance constraint does not fight it.
                // Measured (15-pt replica, rifle into a settled forearm, peak swing of that bone):
                //   c=0.0  10.96 deg      c=0.6  21.14 deg      c=1.0  30.96 deg
                // ... and it works even under the broken (0,0,-1) direction (2.71 -> 17.37 deg),
                // so 1B and 1C are independent levers, not one fix twice.
                float c = rag_couple->value;
                if (c < 0.0f) { c = 0.0f; }
                if (c > 1.2f) { c = 1.2f; }   // past this the arm flails past anatomy (no joint
                                              // limits exist yet); swing= is the gate, see the
                                              // FAIL signature in the acceptance test
                ends[0] = bestJ;
                w[0]    = 1.0f + c;
                ends[1] = bestP;
                w[1]    = -c;
```

and the accumulation ceiling at `:1457` **must** scale with it:

```c
                    vmax = force * 1.6f * (1.0f + c);
```

**This line is not optional and is the subtlest thing in Stage 1.** With the ceiling left at
`force * 1.6f`, the distal end's `(1+c)·k2·force` crosses it at `c ≈ 0.8` and the clamp rescales the
*total* point velocity — which, on the counter-driven proximal end, sign-flips the couple. Measured
with the unscaled clamp: `c = 1.5` gives 54°, `c = 2.0` collapses to **1.29°**, a non-monotone cliff
that would read live as "it worked, then I turned it up and it stopped working". With the ceiling
scaled, the sweep is monotone from `c = 0` to `c = 2.0`.

Also change `if (w[e] < 0.05f) continue;` at `:1453` to `if (fabs(w[e]) < 0.05f) continue;` — `w[1]`
is now negative and would otherwise be skipped every time.

---

#### 1D — clamp `k`

`cg_ragdoll.c:937`, one line inserted:

```c
            float k = 1.0f - (float)s->limpMs[i] / (float)RAG_IMPACT_LIMP_MS;
            if (k < 0.0f) {
                k = 0.0f; // R12: callers pass limpMs up to 1410 (cg_parsemsg.cpp:1867) against a
            }             // 600ms denominator, so k reaches -1.35 and the POSE ATTRACTOR BECOMES A
                          // REPELLER (alpha -0.225 .. -0.308; error grows 1.225x per substep,
                          // 1.225^75 = 4.1e6 over one grenade window). Measured: pelvis excursion
                          // 181u, past the 128u leash -> RagSane blowup -> s_ragNeverArm ->
                          // PERMANENT revert to the anim pose. Every grenade the user has judged
                          // was judged on a corpse whose ragdoll had already killed itself.
```

**Do not raise `RAG_IMPACT_LIMP_MS`.** `ragdoll_r12_grounded.md` FIX 4 proposes 600 → 1500 alongside
the clamp; re-derived at the instant of a rifle impact (`limpMs = 670`): clamp-only gives
`k = 0 → a = +0.0125` (fully limp, correct), while clamp + 1500 gives `k = 1 − 670/1500 = +0.553 →
a = +0.1438` — **11.6× stiffer at the moment of impact**, the exact opposite of the intent. Rejected.

**Do not expect a bullet benefit from 1D.** Measured: it *costs* ~1.5° on bullets (10.05° → 8.59°),
because at limp 670 the mildly-negative alpha was acting as a weak outward push. It ships because it
converts a guaranteed explosion blowup into a survivable 27.8 u toss. Sell it as the explosion fix it
is.

---

#### 1E — the instrument

Twelve rounds have been judged subjectively. This build ends that.

**New `ragSim_t` fields** (after `float maxSpeed;`, `:221`):

```c
    float    swingMax[RAG_PTS];   // peak |angle| each bone has swung from its captured drive dir
    float    swingPeak;           // ... and the worst of them
    byte     swingBone;
```

**Peak-swing scan**, inside the existing `if (rag_debug->integer)` block in `CG_RagdollFrame`,
immediately after the `stretch` scan (`:1697`):

```c
            { // R12 - THE NUMBER THE USER ACTUALLY JUDGES. RagPush aims bone i with
              // normalize(pt[child]-pt[i]) against driveDir0[i] (:1286-1299), so the angle between
              // those two IS the visible limb motion. drift=/span=/maxspd= are all blind to it: a
              // forearm can swing 25 deg while drift moves under 2u.
                int k;
                for (k = 0; k < RAG_PTS; k++) {
                    vec3_t dn;
                    float  cs, ang;
                    int    dch = s_ragDriveChild[k];
                    if (dch < 0 || !s->driveOk[k]) {
                        continue;
                    }
                    VectorSubtract(s->pt[dch], s->pt[k], dn);
                    if (VectorNormalize(dn) < 0.01f) {
                        continue;
                    }
                    cs = DotProduct(dn, s->driveDir0[k]);
                    if (cs > 1.0f)  { cs = 1.0f; }
                    if (cs < -1.0f) { cs = -1.0f; }
                    ang = (float)acos(cs) * 180.0f / (float)M_PI;
                    if (ang > s->swingMax[k]) {
                        s->swingMax[k] = ang;
                    }
                    if (ang > s->swingPeak) {
                        s->swingPeak = ang;
                        s->swingBone = (byte)k;
                    }
                }
            }
```

**The impulse print** replaces `:1551-1554`. Every field here exists to falsify a specific claim in
§0.3:

```c
        if (rag_debug->integer) {
            vec3_t vv;
            float  v0;
            VectorSubtract(s->pt[bestJ], s->ptPrev[bestJ], vv);
            v0 = VectorLength(vv) / subDt;
            cgi.Printf("^~^~^ RAGDOLL impulse ent=%d bone=%d par=%d d=%.1f t=%.2f "
                       "raw=(%.3f %.3f %.3f) use=(%.3f %.3f %.3f) sub=%d grnd=%d "
                       "force=%.0f c=%.2f v0=%.0f limp=%d\n",
                       s->entnum, bestJ, bestP, bestD, bestT,
                       dir[0], dir[1], dir[2], useDir[0], useDir[1], useDir[2],
                       subbed, (int)s->contact[bestJ],
                       force, rag_couple->value, v0, limpMs);
        }
```

*(the explosion branch keeps a `bone=-1` variant with `raw=` zeroed — it has no `bestJ`.)*

**The sleep line** gains one field. Append to the `RAGDOLL sleep-rot` format at `:1801-1807`:

```c
                                   "... swing=%.0fdeg/bone%d",
                                   s->swingPeak, (int)s->swingBone
```

**Cost:** 14 `acos` per awake body per frame, only when `r_ragdollDebug` is on. Zero when off.

---

#### 1F — the cvars and cfgs

`RagCvars()`, appended after `rag_truss` (`:326`):

```c
        // R12 - post-death impact. coop_ragdollImpact 0 restores HEAD behaviour verbatim
        // (no direction substitution, no couple); coop_ragdollCouple is the ONE knob to sweep live.
        rag_impact = cgi.Cvar_Get("coop_ragdollImpact", "1", CVAR_TEMP);
        rag_hitdir = cgi.Cvar_Get("coop_ragdollHitDir", "1", CVAR_TEMP);
        rag_couple = cgi.Cvar_Get("coop_ragdollCouple", "0.6", CVAR_TEMP);
```

`coop_ragdollImpact 0` forces `rag_hitdir` and `c` to their HEAD-equivalent values at the top of
`CG_RagdollImpulse` — one gate, one rollback.

New `hzm-mohaa-coop-mod/coop_mod/cfg/` files, matching the F7/F8 convention already in
`autoexec.cfg:1244-1248`:

```
rag_r12off.cfg   coop_ragdollImpact 0 ; g_fleshImpactDir 0    <- THE rollback, both DLLs
rag_c40.cfg      coop_ragdollCouple 0.4
rag_c60.cfg      coop_ragdollCouple 0.6
rag_c100.cfg     coop_ragdollCouple 1.0
```

bound `F2 / F3 / F4 / F5`. (`F1`, `F7`, `F8`, `F10`, `F11` keep their existing ragdoll bindings.)

---

### STAGE 2 — "Does it STAY where the bullet put it?"

Only after Stage 1's numbers are in. This is the change that delivers the user's second sentence
(*"it still has physics… can move around still"*) rather than a flinch that returns home.

**IN:** `goal[]` rebasing, done in the one form that is not a measured no-op.

Three corrections to the naive version, each of which sinks it on its own:

1. **Frame.** The target is `want = pt[0] + S·(goal[i] − goal[0])`, so a rebase must write
   `goal[i] = goal[0] + Sᵀ·(pt[i] − pt[0])`, **not** `goal[i] = pt[i]`. The naive form
   double-applies the body rotation and warps the corpse on the next substep.
2. **Timing.** Rebasing at limp *expiry* is a measured no-op — the limp ease climbs back toward full
   alpha across the window (`a = 0.1175` at `limpMs = 300`) while the ballistic excursion lasts only
   ~350 ms, so the limb is already home before the trigger fires. Final displacement measured
   0.21 u vs 0.20 u unrebased. **The rebase must TRACK `pt` continuously while `limpMs > 0`.**
3. **Companions.** `restLen[]` and `braceLen[]` are not rebased by a `goal[]` write, so the six
   equality braces would fight the new pose indefinitely — a permanent tug-of-war that never reaches
   the 10 u/s sleep gate and rides the 6 s cap, which is precisely the defect the comment at
   `:1739-1741` records fixing. Rebase them in the same transaction, or accept a never-sleeping
   corpse.

Plus a radial cap that actually binds (a tracking rebase reached 53 u on a repeatedly-shot point in
one lens's model) and a joint-angle sanity so a magazine cannot memorise an anatomically impossible
pose. `s->bodyRot` / `restDir[1]` / `hipDir0` / `rotLocked` form a four-field transaction with
`goal[]` — `RagRawFit` is identity at capture *because* `restDir[1]` and `hipDir0` are built from the
capture `pt[]` (`:837-839`), and that identity is what makes the `rot=` instrument meaningful.

**OUT:** everything else. This stage ships alone.

**Note:** Stage 2 destroys the `drift=` instrument's meaning (it measures distance from `goal[]`).
`swing=` from Stage 1E becomes the primary metric, which is the other reason 1E ships first.

---

### STAGE 3 — "Does the body stop moving as one lump?"

**IN, one of these two, decided by Stage 1's `swing=` data:**

- **(a) Anchor the pelvis.** `RagShapeMatch` is translation-invariant by construction (§0.3 Rank 5),
  which is why the silhouette rides wherever `pt[0]` wanders. A weak spring from `pt[0]` toward
  `cent->lerpOrigin + captureOffset`, active only when the body has ≥3 contacts, removes the
  free translation without touching the shape.
- **(b) Convert the four lateral equality braces** (`{11,13}`, `{5,8}`, `{5,13}`, `{8,11}`,
  `cg_ragdoll.c:124-127`) to inequality, or halve their stiffness, behind `coop_ragdollCross`.

Measured, (b) is worth little for a limb swing (far-thigh ratio 0.10 → 0.08) and full `truss 0`
buys 0.10 → 0.02 at the cost of the anti-pile scaffolding. Measured, the slide is ~1.3 u on a corpse
that was **never shot**, which points at (a). **Prefer (a); hold (b) unless the log says otherwise.**

**Risk:** MEDIUM against bug-1962/1963 (piles). Ships alone, with the pile census from the r9
methodology (span < 35 u on every axis = a bead-chain pile) as the regression gate.

---

### STAGE 4 — "Can physics own the fall itself?"

The user's actual goal. See §8.

---

## 3. CODE-SHAPE CONVENTIONS (this file's, honoured above)

- **Row-vector matrices.** `v' = v·S`. `RagMat3Mul(A, B, out)` is `out = A·B`;
  `RagMat3TransMul(A, B, out)` is `Aᵀ·B`; `RagMat3RotateVec(S, v, out)` applies a row-vector
  rotation. Any new rotation must compose on the same side — the frame mismatch that cost bug-1963
  was exactly this.
- **`CVAR_TEMP` for every experimental knob**; `CVAR_ARCHIVE` only for a player-facing setting
  (`coop_ragdoll` at `:306` is the sole archived one, and its comment says why).
- **`^~^~^ ` prefix** on every machine-parseable print, `key=value` fields, one line per event.
  Watched by `maptest_monitor.ps1`.
- **Impulses go on `ptPrev`, never `pt`** (`:1381-1383`). In Verlet the gap *is* the velocity;
  moving `pt` teleports. Every Stage 1 item honours this: 1A/1B/1C touch only the direction and the
  weights feeding the existing `VectorMA(s->ptPrev[q], ...)` at `:1456`; 1D only shrinks an `a` that
  already moves `pt` and `ptPrev` together (`:940`, `:946`); 1E writes nothing but its own debug
  fields. **No Verlet energy is injected anywhere in Stage 1.**
- **Every API verified against `cgame/cg_public.h`:** `Printf` `:103`, `Cvar_Get` `:122`,
  `CM_BoxTrace` `:177`. No new imports are needed by any stage.

---

## 4. PARAMETER TABLE

| # | parameter | cvar | default | range | what it does | source |
|---|---|---|---|---|---|---|
| 1 | master impact gate | `coop_ragdollImpact` | **1** | 0/1 | 0 = HEAD behaviour verbatim | new, `CVAR_TEMP` |
| 2 | **couple strength `c`** | **`coop_ragdollCouple`** | **0.6** | 0 – 1.2 | `w = (1+c, −c)`. **THE ONE TO SWEEP LIVE.** | new, `CVAR_TEMP` |
| 3 | client direction substitution | `coop_ragdollHitDir` | 1 | 0/1 | reject the three degenerate signatures | new, `CVAR_TEMP` |
| 4 | server sends real `vDir` | `g_fleshImpactDir` | 1 | 0/1 | game.dll half of #3 | new, `CVAR_ARCHIVE` |
| 5 | fallback force scale | *(literal `0.60f`)* | 0.60 | — | the substituted direction is perpendicular to limbs and over-reads | 1B |
| 6 | fallback up-bias | *(literal `0.20f`)* | 0.20 | — | keeps the fallback off the floor | 1B |
| 7 | accumulation ceiling | *(literal)* | `force·1.6·(1+c)` | — | **must scale with `c`** or the couple sign-flips | `:1457` |
| 8 | bullet force | *(literal)* | `150 + 70·iLarge` | — | **do not raise.** Force is a weak lever: 4× force → 3× angle | `cg_parsemsg.cpp:1808` |
| 9 | bullet falloff radius | *(literal)* | `15 + 1.5·iLarge` | — | Stage 3 candidate: LBD spheres reach 9 u, so a torso hit attenuates to `k2 ≈ 0.45` | `cg_parsemsg.cpp:1808` |
| 10 | impact limp window | `RAG_IMPACT_LIMP_MS` | 600 | — | **do not raise** — 11.6× stiffer at impact | `:66` |
| 11 | pose stiffness | `coop_ragdollStiff` | 0.25 | 0 – 1 | not a lever: 0.25 → 0.05 buys 24.5° → 27.0° | `:311` |
| 12 | truss | `coop_ragdollTruss` | 1 | 0/1 | **regression control only.** Stage 1 must not change it | `:326` |
| 13 | pelvis leash | `coop_ragdollLeash` | 128 | — | blowup net. Ten rounds measure 6.4 u — 20× margin | `:319` |
| 14 | debug | `r_ragdollDebug` | 0 | 0/1/2 | 1 = prints, 2 = skeleton dots | `:303` |

**The one to sweep live is `coop_ragdollCouple`.** Everything else is either a defect fix with a
correct value, a regression control, or measured not to matter.

Predicted `swing=` by `c` (rifle into a settled forearm, perpendicular):

| `c` | 0.0 | 0.3 | **0.6** | 0.8 | 1.0 |
|---|---:|---:|---:|---:|---:|
| real direction | 11° | 14° | **21°** | 27° | 31° |
| `(0,0,−1)` | 3° | 2° | **17°** | 26° | 33° |

---

## 5. ACCEPTANCE EVIDENCE — STAGE 1

### 5.1 Setup

```
F8                      // rag_run.cfg: developer 1, r_ragdollDebug 1, coop_ragdoll 1,
                        //   coop_ragdollMode 1, stiff 0.25, drive 1  -- and the reset key
F7                      // rag_drill.cfg: THE FREEZE DRILL. Run this FIRST, every session.
```

**F7 is a gate, not a step.** Kill one soldier with `coop_ragdollTest 2`: he must freeze looking
like a normal soldier. Any warp, stretch, twist or shrink means the render path is broken and
**nothing else in the build can be judged**. Stop and report. (Stage 1 touches nothing in that path,
so a failure here is a pre-existing defect, not this build's.)

### 5.2 The drill — four shots, ~3 minutes

Press **F8**. Kill one rifleman on **flat open ground**. Wait for `^~^~^ RAGDOLL sleep`.
Then, **aiming perpendicular to the forearm** (shot geometry dominates — a round fired along a
bone's axis correctly rotates it barely at all: 200 u down-the-arm measures 1.4°):

| shot | position | proves |
|---|---|---|
| **a** | standing, ~30 u | the top-face constant, and the couple under it |
| **b** | standing, ~200 u | the side-face constant |
| **c** | crouched, ~60 u | the `bytedirs[0]` sentinel |
| **d** | one grenade beside the corpse | Rank 4 |

Then `F2` (`coop_ragdollImpact 0 ; g_fleshImpactDir 0`) and repeat **a**. Then `F8`, `F3`/`F4`/`F5`
to sweep `coop_ragdollCouple` 0.4 / 0.6 / 1.0 and repeat **a** at each.

### 5.3 PASS — exact log fields

**Diagnostic first (this is the point of the build).** With `g_fleshImpactDir 0` the `raw=` field
must read one of exactly three constants, and *which* one must match the position:

```
shot a   ^~^~^ RAGDOLL impulse ... raw=(0.000 0.000 -1.000) ... sub=1
shot b   ^~^~^ RAGDOLL impulse ... raw=(±1.000 0.000 0.000) or (0.000 ±1.000 0.000) ... sub=1
shot c   ^~^~^ RAGDOLL impulse ... raw=(0.526 0.000 -0.851) ... sub=1
```

With `g_fleshImpactDir 1`, `raw=` must **track the shot** (a different vector from each position,
roughly the direction you were looking) and `sub=0`.

**Then the numbers:**

| metric | field | PASS |
|---|---|---|
| struck-bone swing | `swing=NNdeg/boneK` on the `sleep-rot` line | **≥ 15°** at `c = 0.6`, and `boneK` is the bone you shot (6/9 = forearm, 11/13 = thigh, 5/8 = upper arm) |
| swing with impact off | same, after **F2** | **≤ 5°** |
| segment targeting | `bone= par= d= t=` | `d=` under ~6 u and `bone=` is the limb you aimed at |
| injected speed | `v0=` | 120–350 u/s. Above 600 = the clamp scaling is wrong |
| explosion survives | *(absence of)* `^~^~^ RAGDOLL blowup ... reason=leash` within 400 ms of shot **d** | zero such lines |
| solver health | `stretch=` on `sleep-rot` | ≤ 1.10 (control band 1.01–1.07) |
| slide unchanged | `drift=` on `sleep` | within ~2 u of the pre-build value |
| coverage unchanged | `sleep` lines ÷ kills | ≥ 95% (the r9 measurement was 41/42) |

### 5.4 The visual verdict, in one sentence

> Fire one rifle round into the outstretched arm of a corpse lying on flat ground: **the forearm
> visibly swings about the elbow, peaks about a tenth of a second later, and settles back over
> roughly half a second.** Not a jitter, not a slide of the whole body — a limb rotating about a
> joint.

Stage 1's honest ceiling: **it returns to the authored pose.** If the user says *"yes, it moves now,
but it goes back"* — that is a **PASS**, and it is Stage 2's question.

### 5.5 FAIL signatures, and where each one redirects the project

| what you see | what it means | where the project goes |
|---|---|---|
| **`raw=` is NOT one of the three predicted constants** | §0.3 Rank 1 is wrong at its root | **STOP.** Re-derive the trace path from the observed value before building anything else. The whole spec hangs off this line. |
| `swing=` ≥ 15° but the user says it doesn't move | the solver moved; the **renderer** did not consume it | **F7** freeze drill, then **F10** (`coop_ragdollDrive 0/1`) A/B. The project pivots to the render bridge — `RagPush` `:1274-1333` — and the solver is exonerated |
| `swing=` ≤ 5° with `c = 1.0` and a tracking `raw=` | the impulse is arriving and being absorbed anyway | the constraint tree is the wall. Escalate to Stage 3(b) `coop_ragdollTruss 0` **with `swing=` running**, which is the experiment the user's original A/B could not be |
| `swing=` > 70° on any bone, or the arm visibly bends backwards | no joint limits exist; the couple over-drives | drop `coop_ragdollCouple` to 0.4 (**F3**), and joint limits move ahead of Stage 2 |
| `RAGDOLL blowup reason=leash` after a grenade | 1D did not take, **or** the server toss is diverging from the client sim | check the `k` clamp compiled in; if it did, the cause is `g_corpseImpulse` vs the client sim (see bug-1974) and that is a separate, server-side investigation |
| `RAGDOLL blowup reason=span` | the couple destabilised the solver | `coop_ragdollCouple 0` immediately; this is the one Stage 1 outcome that is a genuine regression |
| no `RAGDOLL impulse` line at all when you clearly hit | either the corpse's death anim is still playing (`CG_RagdollImpulse` skips `state < 1`, `:1396`, and death anims run up to 4.7 s), or the shot missed the server's hit spheres | fire `coop_bloodDebug 1` and count `^~^~^ FLESHHIT` lines against rounds fired; the shortfall is the silent-miss rate |
| `sub=1` on most shots with `g_fleshImpactDir 1` | 1A did not deploy (game.dll) | check the game.dll deploy; `build.ps1` must reach **`G:\mohaa-gl2\`**, not just the GOG root (bug-1634) |

---

## 6. ROLLBACK

| stage | one command | restores |
|---|---|---|
| **1** | `exec coop_mod/cfg/rag_r12off.cfg` | `coop_ragdollImpact 0 ; g_fleshImpactDir 0` — HEAD behaviour verbatim, both DLLs, no rebuild. Bound to **F2**. |
| 2 | `coop_ragdollRebase 0` | goal rebasing off; `goal[]` reverts to write-once |
| 3 | `coop_ragdollAnchor 0` *(or `coop_ragdollCross 1`)* | pelvis spring off / equality braces restored |
| 4 | `coop_ragdollMode 1` | back to the settle branch |

**Not covered by rollback, deliberately:** the `k` clamp (1D). It is a sign fix restoring a
documented 0..1 range, it is provably a strict reduction in divergence, and leaving it live in the
"off" configuration is what makes the A/B in §5.2 a clean test of the couple rather than a test of
two things at once.

---

## 7. RISK REGISTER

Ranked probability × impact.

### R1 — Stage 1 lands, `swing=` reads 20°, and the user still says it doesn't move — MEDIUM × HIGH

The model says 21° at `c = 0.6`; a 21° swing on a 14 u forearm moves the hand ~5 u. That is
suprathreshold but not dramatic, and every absolute in this document rests on an invented supine
pose (ratios are trustworthy; absolutes are indicative — three independently written replicas agree
on the ordering and disagree by 3–7× on magnitudes).

**Mitigation:** `swing=` makes this the *only* failure mode that resolves without another
investigation. If the number is there and the eye is not, the answer is the renderer (F7/F10), not
another round of solver tuning. And `coop_ragdollCouple` sweeps 0 → 1.2 live: if 0.6 reads thin, F5
is 1.0 (31°) at zero rebuild cost. **This is why the sweep knob and the instrument ship in the same
build as the fix.**

### R2 — the couple over-drives into anatomically impossible poses — MEDIUM × MEDIUM

There are **no joint limits**. The fold-limit braces are *inequality* braces (`:1004-1005`) that only
resist *tightening*, so nothing stops a forearm rotating 100° the wrong way about an elbow. The
client fallback direction (1B) is derived from body geometry and therefore tends to be perpendicular
to the struck limb — the maximum-lever case — and measured **99°** at `c = 0.8` in the replica.

**Mitigation:** `c` hard-clamped to 1.2 in code; default 0.6; fallback force scaled 0.60; `swing=`
prints the peak per body and §5.5 names >70° as the signature that promotes joint limits ahead of
Stage 2. `stretch` stayed 1.024 across the whole sweep, so this is a *pose plausibility* risk, not a
stability risk.

### R3 — regression against bug-1962 (piles) / bug-1963 (never sleeping, 6 s cap) — LOW × HIGH

**bug-1962** was collision *ordering* — world collision moved inside every substep, plus the capture
pre-lift. **bug-1963** was five coupled defects: the `RagPush` frame mismatch, the pelvis triad, the
Hook A offset conversion, the 0.35 rest gate (150 → 44 u/s) and the grandparent fold braces.

**Stage 1 touches none of it.** The per-substep sequence at `:1633-1642` is unchanged; `RagResolveHit`
`:1038-1071` is unchanged including the 0.35 gate; the pre-lift at `:716-733` is unchanged; the
braces are unchanged; `RagPush` is unchanged. The only shared surface is that a couple raises point
speed, which could delay sleep — measured: 10 rounds 200 ms apart leave the body at 6.4 u drift with
no blowup, and the 6 s per-wake cap (`:1747`) bounds it regardless.

**Mitigation:** the regression battery in §5.3 (`stretch`, `drift`, span, coverage) runs on the same
ten kills as the acceptance test. `coop_ragdollTruss` stays at 1 through Stage 1 — the pile
scaffolding is not in scope.

### R4 — regression against bug-1964 (the space contract) — VERY LOW × VERY HIGH

bug-1964 was `RagPush` converting world→model with the placement frozen at capture while the renderer
recomposes with the current placement. It is the fourth of four defects in the same layer
(bug-1963/1964/1966 plus the original), and it is the class of defect that has cost this project the
most.

**Mitigation:** structural. `RagPush`, `RagCapture`, `RagCaptureToWorld`, `relPos[]`, `mat0[]`,
`entOrigin`/`entAxis` are **not touched in any stage of this spec**. The F7 freeze drill remains a
valid proof of the contract and is a mandatory gate in §5.1.

### R5 — the coverage win (22% → 98%) regresses — LOW × HIGH

bug-1969 raised arming from ~30% of kills to 41/42 by dropping the `cent->interpolate` requirement.
`CG_RagdollImpulse` runs strictly *downstream* of arming and cannot affect it.

There is, however, a hidden coverage leak Stage 1 **improves**: `s_ragNeverArm[entnum] = 1` is
permanent, and today every grenaded corpse trips the leash (Rank 4) and burns itself out of the
system. Clamping `k` (1D) returns those bodies to the population.

**Mitigation:** count `RAGDOLL sleep` lines against kills in the same session; ≥ 95% is the gate.
Count `RAGDOLL blowup` lines — the target is zero, and any non-zero count names its own `reason=`.

### R6 — bug-1971 — NOT IN THE BLAST RADIUS

Recorded for completeness because it was named in the brief. bug-1971 is *"some germans run around
with their gun on their back, posed as if holding it, and never fire"* — a script-side defect in
`coop_mod/officer.scr` (the `coop_squad_surrender` holster loop) and `mg42_hack.scr`, fixed by
re-asserting `enableEnemy = 0` before `anim_scripted` and adding entry guards to three bouncer
threads. It shares no file, no data structure and no execution path with `cg_ragdoll.c`. **Nothing in
this spec can regress it, and nothing in it constrains this spec.**

### R7 — the change of blood-spray direction is judged a regression — LOW × LOW

1A alters the one other consumer of `flesh_impact_norm[]` (`cg_parsemsg.cpp:1331/1354/1377`). Today
every close-range flesh hit sprays along a constant `(0,0,−1)`; after 1A it sprays along the bullet.
This is strictly more correct and it is the defect the user independently reported on 2026-08-19
(`coop_bloodSpurtUp`). If the *look* is preferred as-is, `g_fleshImpactDir 0` restores it and
`coop_ragdollHitDir 1` keeps the ragdoll fix — the client net (1B) is deliberately independent of the
server change for exactly this reason.

---

## 8. ROADMAP — physics owning the fall

> *"realistically when someone is shot and killed, the life comes out of their body… they fall
> lifeless in one direction or another. of course physics does the rest."*

That is a different feature from the one this spec fixes, and it is currently blocked by the same two
defects.

**Where it stands.** The settle branch (bug-1965) exists because capturing at the `EF_DEAD` edge
captured the *living* pose — the engine does not request the death animation until a Think *after*
the edge. So today MOHAA's ~30 authored death animations own the entire fall and physics owns only
the landing. That was the right call: it is why median `drift` is 0.7 u and why corpses look like
corpses.

**What Stage 1 unlocks.** The death handoff has exactly the same defect the bullet impulse had. The
free branch seeds the sim by differencing two snapshot origins — a **whole-body translation**, which
is the thing `RagPush` is structurally blind to. That is why mode 3 always looked like a dropped
mannequin: the killing shot deposits no rotation anywhere. **A working torque couple is precisely the
primitive a death seed needs.** Once `swing=` proves the couple converts into visible bone rotation,
the same call — with the killing round's real direction (1A), applied to the bone the killing round
actually struck (the segment search already finds it), at a larger force and a long limp — *is* "the
life comes out of their body".

**The stage-4 shape (mode 4), for the record:**

1. Arm at the `EF_DEAD` edge as mode 3 does, but capture the pose one Think **later**, once the death
   anim has been requested — so the seed is a dying pose, not a standing one.
2. Seed with the killing shot: `CG_RagdollImpulse` at `force ≈ 600`, `c ≈ 1.0`, `limp = full flight`,
   on the struck segment.
3. `gravScale` full from frame 0; **shape-match alpha 0 during flight**, engaging only on the first
   world contact (`s->touched`, `:1064`) and ramping to `coop_ragdollStiff` over ~250 ms.
4. `goal[]` written at that first contact, not at capture — which **requires Stage 2**, because
   `goal[]` is write-once today.
5. Joint limits, because a free fall with no shape-match is exactly the bead-chain pile the truss
   comment at `:320-325` warns about — which **requires Stage 3's decoupling** to be safe.

**So the dependency chain is: Stage 1 proves rotation is visible → Stage 2 makes the pose mutable →
Stage 3 makes a loose body survivable → Stage 4 hands physics the fall.** Each stage is independently
shippable and independently valuable, and the first one is four small edits and an instrument.

**One honest counter-case, worth reading before Stage 4 is scheduled.** Median drift 0.7 u across 41
bodies means today's corpse *is* the animator's pose, and the animator's pose is a professionally
authored, guaranteed-good-looking dead body. Stage 4 trades that guarantee for a tunable. The user
should see Stage 1 and Stage 2 land, and judge whether a corpse that *keeps* the shape a bullet gave
it is already what they were asking for, before the fall itself is handed to a solver.

---

## 9. DEFECTS TO FILE (`.wolf/buglog.json`)

This spec is read-only; these are the entries the work earns.

1. **`fgame/weaputils.cpp:2625`** — the flesh-impact direction is not a bullet direction.
   `SV_TraceDeep`'s only plane writer is its coarse pre-test (`cm_trace_lbd.cpp:256`), a
   `CM_BoxTrace` against the entity box inflated 40 u and traced in the corpse's yaw-local frame,
   never rotated back; `CM_TraceDeepSuccess` (`:345-360`) leaves `plane` untouched. The client
   therefore gets `(0,0,−1)`, `bytedirs[0]`, or a corpse-local world axis. Vanilla defect, not an HZM
   regression. Affects blood spray on **every** flesh hit, living or dead, and is the reason
   `coop_bloodSpurtUp` exists. `tags: ["ragdoll","trace","protocol","vanilla-defect"]`
2. **`cg_ragdoll.c:937`** — `k = 1 − limpMs/600` is unclamped while callers pass 670–1410
   (`cg_parsemsg.cpp:1809, 1867-1869`). The pose attractor becomes a repeller at `alpha` −0.225 to
   −0.308; error grows 1.225× per substep, 4.07 × 10⁶ over one grenade window. Measured pelvis
   excursion 181 u past the 128 u leash → `RagSane` blowup → `s_ragNeverArm` → **permanent** revert.
   `tags: ["ragdoll","explosion","divergence"]`
3. **`cg_ragdoll.c:1445-1457`** — the "asymmetric" impulse is two positive pushes (net linear 0.975)
   and the 50/50 parent-link projection drags the proximal end along, so the bone translates;
   `RagPush` reads only `normalize(pt[child] − pt[i])` and is blind to translation.
   `tags: ["ragdoll","impulse","rotation"]`
4. **`cg_parsemsg.cpp:1802, 1814, 2226, 2238`** — `VectorNegate(vEnd, vEnd)` sits **inside** the
   `if (flesh_impact_count < MAX_IMPACTS)` guard while `CG_RagdollImpulse(vStart, vEnd, ...)` at
   `:1808` / `:1820` sits outside it. On impact-array overflow (`MAX_IMPACTS 64`, `:48`) the impulse
   receives the un-negated vector and pushes the wrong way. Latent; free to fix; hoist the negate
   above the guard at all four sites. `tags: ["ragdoll","latent","impulse"]`
5. **`cg_ragdoll.c:1059-1063`** — the friction branch of `RagResolveHit` never sets `contact[i]`
   (only the resting branch, `:1056`, does). A *sliding or bouncing* limb is therefore never flagged
   in contact and `RagShapeMatch` gives it the full 0.25 alpha instead of the contact-relaxed 0.0375;
   and on any surface with `normal[2] ≤ 0.7` `contact` is never set at all, which is why 8 of 41
   logged bodies read `contacts=0` and never latch `rotLocked` (which needs `nContact ≥ 3`, `:890`).
   `tags: ["ragdoll","contact","shape-match"]`
6. **`cg_parsemsg.cpp:1808`** — the impulse falloff radius is `15 + 1.5·iLarge` = 16.5 u while the
   server's own hit spheres reach `fLocRadius[] = 9.0` for pelvis/spine
   (`cm_trace_lbd.cpp:53-55`), so a legitimate torso hit can sit 9 u off the bone axis and is
   attenuated to `k2 = 1 − 9/16.5 = 0.45` before anything else in the chain. Torso and thigh hits are
   structurally the weakest, which inverts anatomy. `tags: ["ragdoll","impulse","falloff"]`

---

## 10. WHAT THIS SPEC PROVED vs INFERRED

**PROVED (source, arithmetic re-derived, or measured on the replica):**
the three-constant direction chain and every link in it · `bytedirs[0]` and the `DirToByte(0,0,0)`
sentinel · the 111 u crossover · `MSG_WriteDir` wire neutrality · `goal[]` written once at `:1985` ·
the negative-alpha divergence and its 4.07 × 10⁶ growth · that the explosion case trips the 128 u
leash · that the resting gate cannot fire on the first contact · that `coop_ragdollTruss 0` and the
shipped build are indistinguishable (2.35° vs 2.34°) · that force is a weak lever and stiffness is
not a lever · that the couple is monotone in `c` only when the accumulation clamp scales with it ·
that no `RAGDOLL impulse` line has ever been printed.

**INFERRED (model-dependent — trust the ratios, not the absolutes):**
every degree figure, including 21.1° at `c = 0.6` and the 99° fallback flail. All rest on an invented
supine pose. Three independently written replicas (this one, `_arch`'s, `_grounded`'s) agree on
ordering and on the direction of every effect, and disagree by 3–7× on magnitude. **This is precisely
why §1E ships in the same build as the fix and why §5.5 gives every FAIL signature its own
redirect.**

**The single most valuable line in this build is `raw=`.** It turns §0.3 Rank 1 from a derivation
into an observation, and it is the one field that can be *wrong* in a way that would tell us to stop.
