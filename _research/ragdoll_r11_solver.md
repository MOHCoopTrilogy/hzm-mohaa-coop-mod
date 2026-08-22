# RAGDOLL ROUND 11 — THE LIMIT SOLVER

Re-derivation of `_research/ragdoll_joints_design.md` against `openmohaa-hzm/code/cgame/cg_ragdoll.c`
**as it stands 2026-08-20** (2142 lines, read in full for this document). The joints design predates
the settle architecture, `s_ragDriveChild`, `RagShapeMatch`, `CG_RagdollImpulse` and the orientation
latch. Roughly half of it has already shipped by another route; a third of it is now unnecessary;
and two of its load-bearing derivations are **wrong in a way that would produce exactly the symptom
it was written to kill.** This document is the version you can implement.

Everything here ships in `cgame.dll` alone. No engine, protocol, renderer or `game.dll` change.

---

## 0. THE HEADLINE

| | |
|---|---|
| **Final limit count** | **19** (21 minus J1/J2), of which 4 require the feet |
| **Without feet** | **15** — the four knee limits become unevaluable, not merely unhelpful |
| **Braces** | `s_ragBraces` rows 6-15 stop being evaluated in the same build. Atomic, and made atomic **by one cvar value** rather than by a deletion |
| **Two corrections to the design** | the flex/extension **sign is inverted** for every joint whose neutral is `−U` (both shoulders, both hips) — §2.3; and the hinge sign invariant is **provably vacuous in one branch and degenerate in the other** — §3.4 |
| **Cost** | ~2.4× today's `RagStep` arithmetic, ≈ **0.26 ms/frame at 8 bodies** — a *minority* of the collision cost that already runs (§6) |
| **Rollback** | `coop_ragdollLimits 0` — one console word, restores today's constraint set byte-for-byte |

**The one property that makes this safe**, and the reason the atomic brace deletion is not a leap:
after rows 6-15 stop firing, the six surviving equality braces touch only points
`{0,1,2,3,5,8,11,13}`. Every limb limit's moving set is drawn from `{4,6,7,9,10,12,14,15,16}`.
**The intersection is empty.** No limb limit can fight any surviving brace, and no surviving brace
can undo any limb limit. That is not a tuning hope; it is a property of the two tables, and it is
checkable by eye in ten seconds (§4.2).

---

## 1. WHAT THE DESIGN ASSUMED THAT IS NO LONGER TRUE

| joints design | status today | consequence for round 11 |
|---|---|---|
| §1.1 every bone driven by the wrong segment | **FIXED, differently** — `s_ragDriveChild[]` (`cg_ragdoll.c:100-116`, bug-1966) measures bone `i` on `pt[i] → pt[child]` | §3.4/§3.5's `RagBuildFrames` + push rewrite lose their primary motivation. **Do not do them.** They are RISK 1 of the design and they buy only twist inheritance now |
| §1.2 twist never reconstructed | **still true** — `RagMat3FromTo` (`:449-504`) is a pure swing and `RagPush` (`:1259-1290`) adds no roll | Out of scope this round. It is a *render* defect, orthogonal to limits, and it does not gate them |
| §1.3 the knee is not simulated | **still true** — `s_ragDriveChild[12] = s_ragDriveChild[14] = -1` (`:113,:115`), so bones 11 and 12 receive the *same* swing (`RagPush:1276`, `ref = restDir[12]`, both built from `pt[12]−pt[11]`) and the calf renders rigidly parallel to the thigh | **In scope. Feet are points 15/16.** This is the one piece of the design that is still fully load-bearing |
| §3.4 needs `W[i]` bone frames every substep | **avoidable** — §3.4 of this document derives the hinge axis by *parallel transport of the point cloud*, needing no bone frames at all | RISK 1 is not incurred. `RagPush` is not touched by a single line |
| §5.6 capture may be outside the anatomical range | **rarer, and now with a named mechanism** — the settle capture is an *authored landed pose*, legal by construction; the only thing that can bend it illegally is the capture pre-lift (`:610-634`), which moves points vertically with no regard for joint angles | Keep the widening. It is insurance against a specific mechanism, not superstition (§5.1) |
| §9 delayed capture / powered onset | **SHIPPED as the settle branch** — `RagPendingThink` (`:1870-1973`) captures at the server park | Delete from the roadmap. It is done, better than proposed |
| — | **NEW: `CG_RagdollImpulse` (`:1369-1522`) and the per-point limp window** | §5.2 — a struck limb driven into a limit is now the *primary* thing the limits have to get right |
| — | **NEW: the orientation latch and `RagRawFit` (`:832-846`)** | §4.3 — a hard requirement that the limits cannot perturb the fit's four inputs. They provably cannot |

---

## 2. THE LIMIT SET

### 2.1 J1 and J2 are dead. The arithmetic, not the opinion.

Brace row 5 is `{0,2}` at `s_ragBraceMinFactor[5] = 0` — an **equality** brace (`:128`, `:146`).
Links `1→0` and `2→1` are equality distance links (`:967-979`). So `|p0−p1|`, `|p1−p2|` and
`|p0−p2|` are all pinned, six times per substep, at full stiffness. Triangle 0-1-2 is rigid, and
by the law of cosines the **angle at `p1` between `(p1−p0)` and `(p2−p1)` is a constant for the
life of the corpse.** Call it `θ`.

J1 and J2 measure `b = unit(p2 − p1)` against the pelvis triad `T₀`, whose up-row is
`U = unit(p1 − p0)`. Write `b` in `T₀`:

```
b = cosθ·U + sinθ·( cosφ·L + sinφ·F )          F = T0[0], L = T0[1], U = T0[2],  L×U = F
```

`θ` is pinned; the azimuth `φ` about the spine axis is free. With `U×L = −F` and `U×F = +L`:

```
U×b = sinθ·( −cosφ·F + sinφ·L )
J1 = signedAngle(U → b about L) = atan2( (U×b)·L , U·b ) = atan2( sinθ·sinφ , cosθ )
J2 = signedAngle(U → b about F) = atan2( (U×b)·F , U·b ) = atan2( −sinθ·cosφ , cosθ )
```

As `φ` sweeps 0→2π, `(J1,J2)` traces a closed loop through `(0,−θ) → (θ,0) → (0,+θ) → (−θ,0)` —
a diamond of radius `θ`. Therefore:

- **`θ ≤ 20°`** → the loop is inside both boxes (`J1 ∈ [−20,+40]`, `J2 ∈ [−25,+25]`) for every `φ`.
  Neither limit can ever fire. They are 2 × 6 iterations × 4 substeps × 8 bodies of `atan2` for
  nothing.
- **`θ > 25°`** → at `φ = 180°`, `J2 = +θ > 25°`. The limit fires. Its correction is a rigid
  rotation of `subtree(2)` about `pt[1]`, which moves `pt[2]` and **changes `|p0−p2|`**. The
  equality brace restores `|p0−p2|` on the next projection. The limit fires again. The two feasible
  sets are **disjoint**, so this is a permanent limit cycle from the moment the range finishes
  tightening (300 ms) until sleep.

`θ` is the lower-spine bend of the *authored death pose*. On `unarmed_pain_kneestodeath`,
`death_chest`, `death_fall_back` — a curled or piked torso puts `θ` in the 25-40° band trivially.
So this is not a corner case; it is a coin flip per corpse, and the losing side buzzes for six
seconds.

**J1 and J2 are cut. 21 → 19.** The DOF they would govern is already frozen by the truss, so
nothing is lost — and keeping brace `{0,2}` is what protects `RagRawFit`'s primary axis
`unit(p1−p0)` from wobbling, which is the single most direct way to re-open the spin problem the
project has already closed (§4.3).

### 2.2 J3 stays, at reduced authority, and it is the only limit that touches a brace

J3's moving set is `subtree(2) = {2,3,4,5,6,7,8,9,10}`, pivoted at `pt[2]`. Rotation about `pt[2]`
leaves `|p0−p2|` **exactly** invariant, so J3 cannot fight brace `{0,2}`. It does perturb three
others: `{3,1}` (3 moves, 1 does not), `{5,13}` and `{8,11}` (the torso crosses).

The distinction from J1/J2 is decisive. Count the residual freedom: with triangle `{0,1,2}` rigid,
points `{5,8,11,13}` carry 12 DOF against 8 equality constraints (links `5−2, 8−2, 11−0, 13−0`;
braces `{5,8}, {11,13}, {5,13}, {8,11}`) = **4 residual DOF**. Torso twist is reachable within
those 4, merely resisted. The feasible sets **overlap**, so Gauss-Seidel converges into the overlap
rather than cycling. J1/J2's sets provably do not.

J3 therefore ships with `μ = 0.35` and a net stiffness of 0.50 (vs 0.98 for the hinges), and with a
removal trigger: **if the `lim=` telemetry shows J3 projecting on fewer than 1 % of bodies over 40
kills, delete it in round 12.** Its range is corrected from ±35° to **±45°** — it measures hip-line
against shoulder-line, i.e. *total* spine axial rotation (thoracic ≈ 35° + lumbar ≈ 5-13°), not the
thoracic-only figure the design used.

### 2.3 ⚠ THE SIGN CORRECTION — implement the design's table verbatim and you get the symptom back

Convention chain, each link verified against the source:

1. `AnglesToAxis` rows are **(Forward, Left, Up)** — `q_math.c:769-791`. Checked at yaw 0
   (`axis[1] = (0,1,0)`) and yaw 90 (`axis[0] = (0,1,0)` forward ⇒ `axis[1] = (−1,0,0)` = left).
   Right-handed: `L×U = F`, `U×F = L`, `F×L = U`.
2. `RagMat3FromAxisAngle(n, θ)` uses the row layout lifted from `RagMat3FromTo` (`:494-503`), for
   which `v*M` rotates `v` by `+θ` about `n` **right-handedly**. Checked with `n = +z`:
   `(1,0,0)*M = (cosθ, sinθ, 0)`.
3. `RagSignedAngle(n1, n2, n) = atan2((n1×n2)·n, n1·n2)` returns the `θ` with
   `n1` rotated `+θ` about `n` equal to `n2` — because for unit `n1 ⊥ n`,
   `n2 = n1 cosθ + (n×n1) sinθ` gives `(n1×n2)·n = sinθ` and `n1·n2 = cosθ`.

Therefore **positive `φ` moves the measured direction `b` toward `n × n1`**:

| neutral `n₁` | axis `n` | `n × n₁` | positive means |
|---|---|---|---|
| `+U` (head up) | `L` | `L×U = +F` | **forward** → neck FLEXION ✔ design agrees |
| `+U` | `F` | `F×U = −L` | body's **right** → neck lateral right |
| `−U` (limb hangs down) | `L` | `L×(−U) = −F` | **backward** → **EXTENSION**, not flexion |
| `−U` | `F` | `F×(−U) = +L` | body's **left** → abduction for a LEFT limb ✔ design agrees |

The design's table gives the shoulder `[−60°, +170°]` and the hip `[−25°, +110°]` with `n₁ = −T[2]`
and `n = T[1]`. Under the convention above those read as **60° of flexion and 170° of extension**
at the shoulder, and **25° of flexion and 110° of extension** at the hip. A hip that can only lift
25° forward but swings 110° backward is *literally* "legs folded up behind the back" — the exact
symptom §1.3 of the design was written to kill.

**Corrected: flex/ext ranges for `−U`-neutral joints are `[−flexion, +extension]`.**

### 2.4 Ranges, re-derived from clinical ROM rather than copied

| joint | motion | ROM used | note |
|---|---|---|---|
| neck | flex 50° / ext 60° / lateral 45° | cervical spine | the head is one segment here, so use the whole cervical range |
| shoulder | flex 170° / ext 60° / abd 150° / add 45° | gleno­humeral + scapulothoracic **combined** | `pt[5]` is pinned to the torso by three equality constraints, so the scapula's contribution has nowhere to go but this joint. Abduction stops at 150°, not 180°, because at 180° `b = +U` is the antipode of the neutral and the two-angle box is singular there |
| elbow | flex 145°, floor +2° | `+2°` keeps the joint off the straight singularity; 2° of residual bend is sub-pixel at any view distance | |
| elbow out-of-plane | ±12° | real carrying angle 5-15°, and our axis is approximate | |
| hip | flex 115° / ext 25° / abd 45° / add 25° | the design's `add 15°` forbids crossed legs, which death poses have | |
| knee | flex 145°, floor +2° | | |
| knee out-of-plane | ±8° | a real knee carries 0-5° of varus/valgus | |
| torso twist | ±45° | thoracic 35° + lumbar 5-13°, measured hip-line to shoulder-line | corrected from the design's ±35° |

The design's shoulder adduction `−20°` is widened to `−45°`: arms crossed on the chest is a common
death pose, and at `−20°` the 300 ms tightening would visibly *uncross* them.

### 2.5 THE FINAL TABLE — 19 limits

Frames: `T₀` = pelvis triad, `T₂` = chest triad, rows `[F, L, U]` (§3.2). Degrees here, radians in
code. `μ` = reaction fraction applied to the complement of the moving set. `k` = net per-substep
stiffness; the per-iteration value is `k' = 1 − (1−k)^(1/RAG_ITERS)`.

| # | joint | pivot | measured `b` | axis | neutral `n₁` | range | moving set | μ | k |
|---|---|---|---|---|---|---|---|---|---|
| **J3** | torso twist | 2 | proj. hip-left → proj. chest-left | `T₂[2]` | `T₀[1]`→plane | **[−45°, +45°]** | `subtree(2)` = {2,3,4,5,6,7,8,9,10} | 0.35 | 0.50 |
| **J4** | neck flex/ext | 3 | `unit(p4−p3)` | `T₂[1]` | `+T₂[2]` | **[−60°, +50°]** | {4} | 0 | 0.90 |
| **J5** | neck lateral | 3 | `unit(p4−p3)` | `T₂[0]` | `+T₂[2]` | **[−45°, +45°]** | {4} | 0 | 0.90 |
| **J6** | L shoulder flex/ext | 5 | `unit(p6−p5)` | `T₂[1]` | `−T₂[2]` | **[−170°, +60°]** | {6,7} | 0 | 0.90 |
| **J7** | R shoulder flex/ext | 8 | `unit(p9−p8)` | `T₂[1]` | `−T₂[2]` | **[−170°, +60°]** | {9,10} | 0 | 0.90 |
| **J8** | L shoulder abd/add | 5 | `unit(p6−p5)` | `T₂[0]` | `−T₂[2]` | **[−45°, +150°]** | {6,7} | 0 | 0.90 |
| **J9** | R shoulder abd/add | 8 | `unit(p9−p8)` | `T₂[0]` | `−T₂[2]` | **[−150°, +45°]** | {9,10} | 0 | 0.90 |
| **J10** | L elbow flexion | 6 | hinge `g=5, c=7` | derived `h` | — | **[+2°, +145°]** | {7} | 0 | 0.98 |
| **J11** | R elbow flexion | 9 | hinge `g=8, c=10` | derived `h` | — | **[+2°, +145°]** | {10} | 0 | 0.98 |
| **J12** | L elbow out-of-plane | 6 | `asin(b·h)` | `unit(b×h)` | — | **\|ψ\| ≤ 12°** | {7} | 0 | 0.98 |
| **J13** | R elbow out-of-plane | 9 | `asin(b·h)` | `unit(b×h)` | — | **\|ψ\| ≤ 12°** | {10} | 0 | 0.98 |
| **J14** | L hip flex/ext | 11 | `unit(p12−p11)` | `T₀[1]` | `−T₀[2]` | **[−115°, +25°]** | {12,15} | 0 | 0.90 |
| **J15** | R hip flex/ext | 13 | `unit(p14−p13)` | `T₀[1]` | `−T₀[2]` | **[−115°, +25°]** | {14,16} | 0 | 0.90 |
| **J16** | L hip abd/add | 11 | `unit(p12−p11)` | `T₀[0]` | `−T₀[2]` | **[−25°, +45°]** | {12,15} | 0 | 0.90 |
| **J17** | R hip abd/add | 13 | `unit(p14−p13)` | `T₀[0]` | `−T₀[2]` | **[−45°, +25°]** | {14,16} | 0 | 0.90 |
| **J18** | L knee flexion | 12 | hinge `g=11, c=15` | derived `h` | — | **[+2°, +145°]** | {15} | 0 | 0.98 |
| **J19** | R knee flexion | 14 | hinge `g=13, c=16` | derived `h` | — | **[+2°, +145°]** | {16} | 0 | 0.98 |
| **J20** | L knee out-of-plane | 12 | `asin(b·h)` | `unit(b×h)` | — | **\|ψ\| ≤ 8°** | {15} | 0 | 0.98 |
| **J21** | R knee out-of-plane | 14 | `asin(b·h)` | `unit(b×h)` | — | **\|ψ\| ≤ 8°** | {16} | 0 | 0.98 |

Numbering keeps the design's ids so cross-references survive; J1, J2 are simply absent.

**`μ = 0` for every limb joint.** The parent side of a shoulder is the torso truss (8 points, 6
equality braces, 7 links); the child side is a forearm and a hand. Segmental mass fractions
(Dempster): trunk 0.497 + head 0.081 = 0.578 against forearm 0.016 + hand 0.006 = 0.022 — a **26:1**
ratio, so treating the parent as infinitely heavy is a 3.7 % error, and it removes an entire class
of feedback loop for free. Note the honest consequence: with `μ = 0` a limit correction is an
external torque on the point cloud. It is *supposed* to be — the whole point is that a struck limb
moves. If the round-11 sleep line shows `spin` rising above round 10's 0-3 °/s, raise `μ` to 0.15
on the hips (the heaviest limbs) before touching anything else.

### 2.6 Feet — points 15 and 16

`Bip01 L/R Foot` are in the engine's own 19-name hitloc table (`qcommon/cm_trace_lbd.cpp:31-51`)
and were verified present on 39/39 humanoid SKDs during vet1. Append them so existing indices never
move:

```c
#define RAG_PTS 17
    ...
    {"Bip01 L Calf",    11}, // 12   <-- now has a child
    {"Bip01 R Calf",    13}, // 14
    {"Bip01 L Foot",    12}, // 15  NEW, terminal
    {"Bip01 R Foot",    14}, // 16  NEW, terminal
static const int s_ragDriveChild[RAG_PTS] = { ... 15, /*12*/ ... 16, /*14*/ ... -1, -1 };
static const float s_ragPtRadius[RAG_PTS] = { ...,  3.0f, 3.0f };
```

Anchor-table (`:261-286`) edits: `"Bip01 L Foot" → 15`, `"Bip01 L Toe" → 15`,
`"Bip01 R Foot" → 16`, `"Bip01 R Toe" → 16`. Sim channels self-anchor at step 1 of the anchor loop
(`:775-780`) before the table runs, so the `Foot` rows only ever catch child nubs.

**⚠ Feet must be OPTIONAL, and the design gets this wrong.** It says "`RagCapture`'s existing
bail-clean on a missing tag name covers any skd that lacks a foot bone" — but that bail
(`:592-598`) **refuses to arm the corpse at all**. On an imported skeleton without feet, that is a
100 % coverage loss on that model, i.e. bug-1969 by a new route, against the one metric this project
fought hardest for (22 % → 98 %). Instead:

```c
int nPts;   // 17 when BOTH feet resolve, else 15. Feet are LAST, so every
            // for (i = 0; i < RAG_PTS; i++) becomes for (i = 0; i < s->nPts; i++)
```

and the four knee limits are simply not added to the per-sim active list when `nPts == 15`. Feet are
all-or-nothing; no humanoid skd has one.

**If the topology lens does NOT land feet:** the table drops to **15 limits** (J18-J21 out — they are
unevaluable, not merely unhelpful, because `c` has no point); brace rows 11-12 `{0,12}/{0,14}` still
go, because they were mislabelled — `pt[12]` *is* the knee, so `|p0−p12|` is a function of the hip
angle and is already covered by J14/J16; `s_ragDriveChild[12]/[14]` stay `−1` and the calves keep
rendering rigidly parallel to the thighs, which is a *visible* defect independent of any limit.

> **Side note worth one live print.** The prompt records "~46 u of shin per leg". Derived from the
> living bbox `{-15,-15,0}..{15,15,94}` (`:1849-1851`) and standard proportions (tibiale height
> ≈ 0.246 × stature), knee→ankle should be **≈ 23 u**, and femur ≈ 23 u. 46/23 ≈ 2.0 ≈ 1/0.52 —
> and 0.52 is exactly the human `load_scale` that `tr_ragdoll.cpp:147` divides out. **Hypothesis:**
> the 46 u figure was measured in raw skeletor space rather than the world space `TIKI_Orientation`
> returns. One-line check: print `|pt[12] − pt[15]|` at capture under `r_ragdollDebug 3`. It matters
> because `RagSane`'s 200 u span gate (`:1204-1209`) and the r9 plan to tighten it to
> "measured max × 1.25" are sized against it.

**`RagSane` span: leave the 200 u gate alone this round.** r9 measured a max AABB span of 88 u over
41 bodies with 15 points; feet extend the leg chain by ~23 u each, so a fully extended body reaches
~110 u. The r9 roadmap's "tighten to measured max × 1.25" must be **re-baselined after feet land**,
or it fires on legitimate corpses.

---

## 3. DERIVATION AT CAPTURE — no hand-authoring, per model

All of this runs once, in `RagCapture`, **after** the pre-lift (`:610-634`) and the buried refusal
(`:639-657`), so the geometry it measures is the geometry the sim will actually start from.

### 3.1 New helpers, in the file's conventions

```c
// row-vector rotation of 'ang' radians about unit axis n. Same row layout as RagMat3FromTo
// (cg_ragdoll.c:494-503), which the numeric harness already pins as v*M == rotate(v).
static void RagMat3FromAxisAngle(const vec3_t n, float ang, float out[3][3])
{
    float c = (float)cos(ang), s = (float)sin(ang), t = 1.0f - c;
    float x = n[0], y = n[1], z = n[2];
    out[0][0] = t*x*x + c;   out[0][1] = t*x*y + s*z; out[0][2] = t*x*z - s*y;
    out[1][0] = t*x*y - s*z; out[1][1] = t*y*y + c;   out[1][2] = t*y*z + s*x;
    out[2][0] = t*x*z + s*y; out[2][1] = t*y*z - s*x; out[2][2] = t*z*z + c;
}

// signed angle taking n1 to n2 about n, in (-PI, PI]. atan2 replaces Mueller's asin + quadrant
// fixups: same quantity, better conditioned, three fewer branches. math.h is unconditional
// (q_shared.h:167) and cg_view.c:2204 already calls atan2.
static float RagSignedAngle(const vec3_t n1, const vec3_t n2, const vec3_t n)
{
    vec3_t x;
    CrossProduct(n1, n2, x);
    return (float)atan2(DotProduct(x, n), DotProduct(n1, n2));
}

// rigid rotation of a masked point set about a pivot, applied to pt AND ptPrev (see 4.5)
static void RagRotateSet(ragSim_t *s, unsigned mask, const vec3_t pivot, const float R[3][3])
{
    vec3_t rel, rot;
    int    i;
    for (i = 0; i < s->nPts; i++) {
        if (!(mask & (1u << i))) { continue; }
        VectorSubtract(s->pt[i], pivot, rel);
        RagMat3RotateVec(R, rel, rot);
        VectorAdd(pivot, rot, s->pt[i]);
        VectorSubtract(s->ptPrev[i], pivot, rel);
        RagMat3RotateVec(R, rel, rot);
        VectorAdd(pivot, rot, s->ptPrev[i]);
    }
}

// FLU triad from a tip/base direction and a right->left socket line. Rows = [F, L, U].
// DISTINCT from the existing RagTriad (:410-431), which is [primary, GS-secondary, cross]
// and feeds RagRawFit. Do not merge them: RagRawFit is the round-10 spin instrument and its
// basis must not move.
static qboolean RagBodyTriad(const vec3_t tip, const vec3_t base,
                             const vec3_t sockR, const vec3_t sockL,
                             float faceSign, float T[3][3])
{
    vec3_t U, L, F;
    VectorSubtract(tip, base, U);
    if (VectorNormalize(U) < 0.001f) { return qfalse; }
    VectorSubtract(sockL, sockR, L);
    VectorMA(L, -DotProduct(L, U), U, L);          // Gram-Schmidt against U
    if (VectorNormalize(L) < 0.001f) { return qfalse; }
    VectorScale(L, faceSign, L);
    CrossProduct(L, U, F);                          // right-handed FLU
    VectorCopy(F, T[0]); VectorCopy(L, T[1]); VectorCopy(U, T[2]);
    return qtrue;
}
```

> **Trap.** `VectorNormalize` (`q_math.c:2018-2033`) returns the **squared** length and leaves `v`
> untouched when `|v|² ≤ FLT_EPSILON`. The `< 0.001f` guards above are still correct (1e-8 < 0.001)
> but the returned number is not a length on that path, and the vector is **not normalized**. Every
> caller must branch, never use the value.

### 3.2 The two anatomical triads

Both lines run between points that are rigidly attached to the same bone in any pose — the hip
sockets *are* the thigh bone origins, the shoulder sockets *are* the upper-arm bone origins — so
this derivation is pose-independent and needs no bind pose.

| frame | tip | base | sockR | sockL |
|---|---|---|---|---|
| pelvis `T₀` | `pt[1]` Spine1 | `pt[0]` Pelvis | `pt[13]` R Thigh | `pt[11]` L Thigh |
| chest `T₂` | `pt[3]` Neck | `pt[2]` Spine2 | `pt[8]` R UpperArm | `pt[5]` L UpperArm |

`faceSign` is resolved **once at capture** against the entity axis — the corpse's facing at death,
which only has to be right to within 90°:

```c
RagBodyTriad(tip, base, sockR, sockL, +1.0f, T);
s->faceSign[k] = (DotProduct(T[0], s->entAxis[0]) >= 0.0f) ? +1.0f : -1.0f;
```

`s->entAxis[0]` is forward (`q_math.c:784-786`, `AnglesToAxis` row 0). On a correctly named
skeleton this always resolves `+1`; it exists to catch an imported SKD whose `Bip01 L Thigh` is
actually on the model's right, which would otherwise mirror every asymmetric range at once.

**Degeneracy.** `T₀` fails only if `|p1−p0| ≈ 0` (impossible — the bind check at `:659-670` already
requires `|p4−p0| ≥ 4`) or if the hip line becomes parallel to the spine direction, which the
`{11,13}` brace plus the `11→0`/`13→0` links make geometrically unreachable. `T₂` is protected the
same way by `{5,8}`. If either fails anyway: **set `s->limitsOk = 0`, keep simulating, print.**
Never bail the capture — that is the coverage regression (RISK 4 of the r9 spec) and the sim without
limits is exactly today's behaviour, which is acceptable. Runtime degeneracies get their own
counter, `limBad`, alongside the existing `rawBad` (`:219`, `:866`).

### 3.3 Swing joints — nothing to derive

Every swing limit's axis and neutral are rows of `T₀` or `T₂`, rebuilt each substep from the live
points. There is no per-joint capture state except the widened range (§5.1). That is the whole
appeal of the rectangular form: two `atan2`s in a frame you already have.

**One guard is required.** `RagSignedAngle(n₁, b, axis)` measures the angle of `b`'s *projection*
onto the plane ⊥ `axis`, which is meaningless when `b ≈ ±axis`. For J6/J7 (axis = chest-left) that
is an arm flung straight out to the side — a common death pose. Skip the projection when
`|b·axis| > 0.94` (`b` within 20° of the axis, projection length < 0.34):

```c
if (fabs(DotProduct(b, axis)) > 0.94f) { continue; }   /* 1 dot + 1 compare */
```

The box degrades gracefully under this rule: with the arm straight out to the left, J6 (flex/ext)
is skipped as undefined while J8 (abd/add) correctly reports +90° abduction and still constrains.
Exactly one of the pair goes dark, never both.

### 3.4 Hinge axes — and why the design's sign invariant does not work

**The design's sign fix is vacuous in one branch and degenerate in the other.** It rotates `b₀` by
+10° about `h₀` and negates `h₀` if the child moves *away* from the grandparent. With
`L1 = |p−g|`, `L2 = |c−p|`, interior angle `γ` at `p`, and `φ = 180° − γ`:

```
|c−g|² = L1² + L2² − 2·L1·L2·cos γ = L1² + L2² + 2·L1·L2·cos φ
```

- **Bent branch** (`h₀ = +unit(a₀×b₀)`): by construction `(a₀×b₀)·h₀ = |a₀×b₀| > 0`, so `φ₀ ∈ (0°,180°)`,
  so `d|c−g|/dφ < 0`, so the test **always passes and never negates**. It is a no-op.
- **Straight branch** (`φ₀ ≈ 0`): `|c−g|²` is an **even function of `φ`**. A finite ±10° rotation
  gives the *identical* distance either way. The test is degenerate exactly where it was needed.

**The replacement: the medio-lateral rule, derived.** In anatomical position the shin points `−U`
and knee flexion carries the foot posteriorly, toward `−F`. The axis `n` with `n × (−U) ∝ −F` is
`n = +L`, since `L×(−U) = −(L×U) = −F`. The forearm points `−U` and elbow flexion carries the hand
anteriorly, toward `+F`; `(−L)×(−U) = L×U = +F`, so `n = −L`. **Both sides of the body agree**,
because both limbs flex the same way in world terms.

```
KNEE flexion axis h  ≈  +T₀[1]   (pelvis LEFT)
ELBOW flexion axis h ≈  −T₂[1]   (chest RIGHT)
```

This is pose-independent to within the long-axis roll `ρ` of the parent bone: `h·(±L) ≈ cos ρ`.
Requiring `|h·(±L)| ≥ 0.35` accepts `|ρ| ≤ acos(0.35) = 69.5°`, against a femoral rotation range of
±45° and a resting humeral rotation of ~±30°. It rejects exactly the poses where it should.

**The capture procedure, staged:**

```c
VectorSubtract(pt[p], pt[g], a0); VectorNormalize(a0);
VectorSubtract(pt[c], pt[p], b0); VectorNormalize(b0);
CrossProduct(a0, b0, h0); sn = VectorLength(h0);

if (sn > 0.4226f) {                       /* sin(25 deg): unambiguously bent */
    VectorScale(h0, 1.0f / sn, h0);
    /* TRUST THE CAPTURE. The authored death pose is anatomically legal, therefore the way this
       joint is bent right now IS flexion. This is the settle architecture's whole premise,
       applied to anatomy. Cross-check against the medio-lateral rule and PRINT agreement -
       do not act on it: one session of AGREE/DISAGREE lines is the corpus that makes the
       straight branch exact (see below). */
    d = DotProduct(h0, sgnRef);
    J->resolved = 1;
    J->agree    = (d > 0.0f);
} else {                                  /* straighter than 25 deg: the plane is unusable */
    int k, best = 0; float bd = 2.0f;     /* parent bone's own capture world frame, W0 = rot0*E */
    for (k = 0; k < 3; k++) {
        float dd = (float)fabs(DotProduct(W0p[k], a0));
        if (dd < bd) { bd = dd; best = k; }
    }
    VectorMA(W0p[best], -DotProduct(W0p[best], a0), a0, h0);
    VectorNormalize(h0);
    d = DotProduct(h0, sgnRef);           /* sgnRef = +T0cap[1] knee, -T2cap[1] elbow */
    if (fabs(d) < 0.35f) {
        J->resolved = 0;                  /* DISABLE flexion for this corpse. Keep the OOP
                                             clamp: |psi| <= psiMax is symmetric in h and needs
                                             only the axis LINE, not its sense. */
    } else {
        if (d < 0.0f) { VectorNegate(h0, h0); }
        J->resolved = 1;
    }
}
VectorCopy(h0, s->hAxis[J]);
VectorCopy(a0, s->hPrev[J]);
J->capPhi = RagSignedAngle(a0, b0, h0);
```

`W0p = rot0[p] * E` — one `RagMat3Mul` per hinge at capture, using state the file already stores
(`rot0` at `:673-680`, `entAxis` at `:570`). No new capture machinery.

**The staging that makes this converge.** The `AGREE/DISAGREE` print over one 40-kill session,
together with the local components `RagMat3TransRotateVec(W0p, h0, ...)` of every *resolved* axis,
gives the modal `(row, sign)` per joint under the 3ds Max Biped convention MOHAA's exporter uses on
all 39 humanoid SKDs — the same premise `s_ragDriveChild` was measured against and shipped on
(bug-1966). Round 12 hard-codes four constants and the straight branch becomes exact, with the
medio-lateral rule demoted to a cross-check. **This build measures the thing that makes the next
build exact.**

### 3.5 The runtime hinge axis — parallel transport, no bone frames

The design reconstructs `h` each substep as `hLocal * W[p]`, which requires `RagBuildFrames` and
therefore the whole `RagPush` rewrite — RISK 1, on the exact code that carried a 120° frame-mismatch
bug and a wrong-side composition bug through multiple sessions, and which the freeze drill is
structurally blind to. **That price does not have to be paid.** A limp limb adds no twist of its
own, so the hinge axis is simply parallel-transported along the parent segment's motion:

```c
/* RagLimitPrepare, once per substep, per hinge */
VectorSubtract(s->pt[p], s->pt[g], a); VectorNormalize(a);
RagMat3FromTo(s->hPrev[J], a, R);                 /* minimal rotation: zero twist added */
RagMat3RotateVec(R, s->hAxis[J], h);
VectorMA(h, -DotProduct(h, a), a, h);             /* re-orthogonalize against the new a */
if (VectorNormalize(h) > 0.5f) { VectorCopy(h, s->hAxis[J]); }
VectorCopy(a, s->hPrev[J]);
```

Properties, each one a reason to prefer this to the frame chain:

1. **`RagPush` is not touched.** Zero exposure to the render path that has broken twice.
2. **Always defined**, including for a perfectly straight limb — the failure the design's
   `a × b` needed a whole second branch for.
3. **Physically the right model.** Minimal-rotation transport *is* "no twist added"; it has the
   correct holonomy for a limp segment, and it is the same primitive the shipped swing already uses.
4. **Drift is bounded by float error, not by a systematic term**, and the re-orthogonalization
   against `a` runs every substep.

**Do not snap `h` to the live plane normal `unit(a×b)`.** That is tempting and it is a trap: snapping
forces `h ⊥ b`, which makes `ψ = asin(b·h) ≡ 0` and silently turns the out-of-plane clamp into a
no-op — after which a knee can swing sideways freely and merely re-defines its own "sagittal plane"
as it goes. The out-of-plane clamp is what makes the hinge a hinge, and it only has meaning against
a *transported* reference.

One belt, for transport drift on a long-lived corpse: if `|a×b| > sin40° = 0.643` **and**
`|b·h| > sin25° = 0.4226`, the transported axis has drifted far from the observable plane —
re-anchor `h ← ±unit(a×b)` with the sign that preserves `dot(n, h) ≥ 0`. Expected frequency: zero;
it costs one dot and one compare.

At solve time:

```c
VectorSubtract(s->pt[c], s->pt[p], b); VectorNormalize(b);
phi = RagSignedAngle(a, b, h);     /* 0 = straight, + = flexion, - = hyperextension */
```

A hyperextended capture yields `capPhi < 0`, which §5.1's widening admits at `t = 0` and then
tightens toward `+2°` over 300 ms — the solver **gently straightens an illegal capture back into
range**. That is a visible improvement, delivered by the anti-pop rule rather than in spite of it.

---

## 4. SOLVER INTEGRATION

### 4.1 Where it runs

```
RagStep(s, dt):                                              /* cg_ragdoll.c:942 */
  1. integrate: damping 0.98, velcap, gravity                /* :947-965  unchanged */
  2. RagLimitPrepare(s)                          <-- NEW: T0, T2, 4 transported hinge axes
  3. for it = 0 .. RAG_ITERS-1:                              /* :966 */
       a. parent distance links, i = 1 .. nPts-1             /* :967-979 unchanged */
       b. braces  -- rows 0-5 only under mode 1              /* :980-995 gated */
       c. RagLimitSweep(s, k'), order reversed on odd 'it'   <-- NEW
  4. limp windows tick down                                  /* :997-1004 unchanged */
  5. RagBodyRotationAdvance(s)                               /* :1005     unchanged */
  6. if (branch) RagShapeMatch(s, alpha)                     /* :1006-1018 unchanged */
  7. RagLimitSweep(s, kPost)                     <-- NEW: one final pass, see 4.4
CG_RagdollFrame:
  8. RagCollideWorld(s, subStart)                            /* :1605     unchanged, STILL LAST */
```

### 4.2 Why limits go *after* links and braces inside each iteration

Because a limit correction is a **rigid rotation of a subtree about the joint pivot**, and a rigid
rotation preserves every distance inside the rotated set. Concretely, for a limit with pivot `P` and
moving set `M = subtree(child)`:

- every link **inside** `M` — preserved exactly (isometry);
- the link **crossing** the pivot, `|pt[child] − pt[P]|` — preserved exactly, because `P` is on the
  rotation axis and is not in `M`;
- links from `M` to points outside `M ∪ {P}` — **there are none**, because `M` is a subtree.

So limits-after-links converges: the limits cannot undo the links. The converse is false — a
distance projection moves individual points and violates angles freely — so limits-before-links
would have the link pass destroy the limit's work every iteration.

**The brace check, done explicitly.** Surviving braces (rows 0-5) touch points
`{0, 1, 2, 3, 5, 8, 11, 13}`. Limb-limit moving sets are drawn from `{4}, {6,7}, {9,10}, {12,15},
{14,16}, {7}, {10}, {15}, {16}`. **Empty intersection.** Only J3's set (`subtree(2)`, containing 5
and 8) touches braces — it perturbs `{3,1}`, `{5,13}` and `{8,11}`, which is why it ships at
`k = 0.50` and `μ = 0.35` (§2.2). This emptiness is *created* by deleting rows 6-15: rows 7-10 and
11-12 are precisely the ones that reach into limb subtrees (`{2,6}, {2,9}, {5,7}, {8,10}, {0,12},
{0,14}`). **That is the mechanical content of the atomicity rule** — braces and limits are not two
tunings of one thing, they are two constraint systems whose supports must not overlap.

### 4.3 Why the ordering is irrelevant to `RagBodyRotationAdvance` — and must be

`RagRawFit` (`:832-846`) reads exactly four points: `pt[0]`, `pt[1]`, `pt[11]`, `pt[13]`.

Scan the moving sets in §2.5: `{2..10}`, `{4}`, `{6,7}`, `{9,10}`, `{7}`, `{10}`, `{12,15}`,
`{14,16}`, `{15}`, `{16}`. **None of them contains 0, 1, 11 or 13.** J1/J2 would have moved
`pt[1]` — one more reason they are gone.

Therefore **no limit can perturb the orientation fit, in any ordering.** The round-10 result (total
rotation 0-28°, spin at rest 0-3 °/s, `yawf ≈ 0`) is structurally protected. The limits cannot
re-open the spin problem, and this is provable from the two tables rather than measured after the
fact.

### 4.4 The post-shape-match sweep, and why nothing goes after collision

`RagShapeMatch` (`:907-940`) runs last in `RagStep` and applies **different alphas to different
points** — 1.0 baseline, ×0.15 where `contact[i]`, ×0.05 where `limpMs[i] > 0`. A non-uniform pull
is not a rigid motion, so it can re-violate a limit that the iteration loop just satisfied. This is
the identical mechanism the file already documents for the distance links at `:1648-1650` ("nothing
re-enforces distance after it, while per-point alphas differ across a link"), whose measured
magnitude is the live `stretch=` of 1.01-1.07 — **small**. One extra limit sweep at `kPost = k'`
closes it for ~1/6 of the loop's limit cost.

**Do not put it after `RagCollideWorld`.** Collision is the last word by design: the per-substep
ordering integrate → constraints → collide is what makes every substep end penetration-clean, and it
was bought with bug-1962 (bodies sinking under the map, points frozen in solid pinning corpses into
piles). A limit sweep after collision could push a point back into a wall. The worst case with the
sweep *before* collision is that the final rendered pose of a frame is off by one collision resolve
— a sub-degree residual on the contacting point only.

**Do not add a distance pass after the shape-match either.** The r9 spec's trigger for that was
`stretch > 1.3`; live readings are 1.01-1.07, so the trigger did not fire. One change per question.

### 4.5 The primitive, and the five anti-jitter rules

```c
static void RagLimit(ragSim_t *s, const ragLimit_t *J, const vec3_t axis,
                     float phi, float lo, float hi, float k)
{
    float target = (phi < lo) ? lo : ((phi > hi) ? hi : phi);
    float d, band, R[3][3];

    if (target == phi) { return; }                 /* inequality: project only when violated */
    d = target - phi;
    band = (float)fabs(d) / RAG_LIMIT_BAND;        /* smoothstep ramp over the first 4 deg */
    if (band > 1.0f) { band = 1.0f; }
    band = band * band * (3.0f - 2.0f * band);
    d *= k * band;
    if (d >  RAG_LIMIT_MAX_STEP) { d =  RAG_LIMIT_MAX_STEP; }   /* 12 deg, pathological belt */
    if (d < -RAG_LIMIT_MAX_STEP) { d = -RAG_LIMIT_MAX_STEP; }

    RagMat3FromAxisAngle(axis, d * (1.0f - J->mu), R);
    RagRotateSet(s, J->mask, s->pt[J->pivot], R);
    if (J->mu > 0.0f) {
        RagMat3FromAxisAngle(axis, -d * J->mu, R);
        RagRotateSet(s, s->allMask & ~J->mask, s->pt[J->pivot], R);
    }
    s->limFires++;
    if (fabs(target - phi) > s->limMaxViol) { s->limMaxViol = (float)fabs(target - phi); }
}
```

| failure mode | rule | verification |
|---|---|---|
| the limit injects energy each step, the limb buzzes at the stop | **`RagRotateSet` moves `pt` and `ptPrev` by the same rigid rotation** | Verlet implied velocity `v = pt − ptPrev`. After `pt' = q + (pt−q)R` and `ptPrev' = q + (ptPrev−q)R`: `v' = (pt−ptPrev)R = vR`, so `\|v'\| = \|v\|` **exactly**. Zero energy added, zero removed; the velocity is rotated onto the constraint surface, so the limb *slides along* the stop instead of re-violating it. It also cannot breach the `rag_velcap` clamp, and it leaves the sleep meter's input (mean `\|pt−ptPrev\|`) untouched — so this cannot regress bug-1962's sleep fix |
| axis flips near degeneracy | hinge axes come from **transport**, never a live `a×b` (§3.5); swing axes are triad rows, plus the `\|b·axis\| > 0.94` skip (§3.3) | |
| constraint chatters on/off each iteration | `k' < 1` **plus** the smoothstep ramp over the first 4° of violation, above | |
| Gauss-Seidel order bias stiffens one side | sweep order reversed on odd iterations | |
| redundant constraints fight | brace rows 6-15 stop firing in the same build; §4.2's empty-intersection check is the proof that nothing is doubly constrained | |

**The two burns this rule exists for**, both recorded in the file itself: `RagShapeMatch` used to
move `pt` alone, injecting `(a·|d|)/dt` of speed every substep — "spassing and flying across the
world" (`:933-938`, r9 fix R6, now `coop_ragdollCarry` 0.85); and `CG_RagdollImpulse` had to be
built the exact opposite way, on `ptPrev` and never `pt`, or it would teleport bodies instead of
pushing them (`:1366-1368`). *(The prompt cites bug-1971 for the first; bug-1971 in `buglog.json`
is the surrender/holster defect. The energy-injection record is r9's R6 and the code comment at
`:933-938`.)*

### 4.6 Stiffness and iteration count

Müller 2007's transform makes tuning iteration-count independent: `k' = 1 − (1−k)^(1/n)`.
At `RAG_ITERS = 6` (`:61`):

| net `k` | `k'` | arithmetic | used by |
|---|---|---|---|
| 0.98 | **0.4790** | `1 − exp(ln 0.02 / 6) = 1 − exp(−0.65200) = 1 − 0.52102` | J10-J13, J18-J21 (hinges — exact axes, hard anatomy) |
| 0.90 | **0.3187** | `1 − exp(ln 0.10 / 6) = 1 − exp(−0.38376) = 1 − 0.68129` | J4-J9, J14-J17 (swings — derived axes, capsular ROM) |
| 0.50 | **0.1091** | `1 − exp(ln 0.50 / 6) = 1 − exp(−0.11552) = 1 − 0.89090` | J3 (known soft coupling with the crosses) |

**`RAG_ITERS` stays at 6 and the timestep stays at 8 ms × 4.** Macklin 2019's "substeps beat
iterations" is right, but `RAG_SUBSTEP_MS`/`RAG_MAX_STEPS` also set the collision rate, the sleep
meter's units, the impulse's `subDt` (`:1372`) and the limp decrement (`:999`). Changing them in the
same build as the limits would confound every reading. Round 12, alone.

**Axis refresh once per substep, not per iteration.** Re-derive the error: round 10 measured total
rotation-since-capture of 0-28° over a settle of ~1.5 s, i.e. ≤ ~19 °/s, i.e. **≤ 0.15° of axis lag
per 8 ms substep** — an order of magnitude under the 4° smoothstep band. Refreshing per iteration
costs 6× for a provably invisible gain. The constraint *values* (`φ`, `ψ`) are of course recomputed
every iteration; only the axes are frozen.

---

## 5. THE SHAPE-MATCH INTERACTION

### 5.1 "The authored pose is legal, so they rarely disagree" — verified, with the exception named

**At `t = 0` this is a proof, not an assumption.** `goal[]` is a verbatim copy of the capture
`pt[]` (`:1950-1952`), and every limit's `capPhi` is measured from those same points. The widening
rule then makes each range admit its own capture value:

```c
J->lo0 = MIN(J->lo, J->capPhi - DEG2RAD(5.0f));
J->hi0 = MAX(J->hi, J->capPhi + DEG2RAD(5.0f));
/* per substep */
t  = clamp(s->limAgeMs / (float)RAG_TIGHTEN_MS, 0.0f, 1.0f);
lo = J->lo0 + (J->lo - J->lo0) * t;
hi = J->hi0 + (J->hi - J->hi0) * t;
```

So the goal is *exactly* inside every range at `t = 0`, by construction.

**⚠ `limAgeMs`, not `lifeMs`.** `lifeMs` is reset to 0 on every wake — impulse (`:1512`) and mover
(`:1572`). Driving the tightening from `lifeMs` would silently re-widen every limit back to its
capture value for 300 ms **the instant a corpse is shot** — i.e. the limits would be at their
weakest during exactly the event this whole round exists to make look right. Add a monotone
`int limAgeMs`, incremented beside `lifeMs` at `:1590` and never zeroed.

**After tightening, the one mechanism that can leave the goal illegal is the capture pre-lift**
(`:610-634`). It raises buried points by up to a 40 u trace with no regard for joint angles, so it
can bend a knee or hip out of range in a way the animator never authored. (Secondary: a crossblend
of two death anims — `frameInfo` carries up to `MAX_FRAMEINFOS` weighted entries — is a linear blend
of two legal poses and can stray slightly out of range.) Both are absorbed by the widening and then
gently unwound over 300 ms.

**What a permanent disagreement actually does — and it is benign.** If `capPhi` stays outside
`[lo,hi]` after tightening, the shape-match pulls toward an illegal pose while the limit pushes
away. Both are position projections toward different fixed points, so the composite is a contraction
and converges to a **steady offset**, not an oscillation. The offset is roughly
`alpha/(alpha + k') = 0.25/0.729 = 34 %` of the excess. The residual per-substep motion is only what
the shape-match leaves unabsorbed, `(1 − rag_carry) · alpha · |d| = 0.15 × 0.25 × |d|` per substep;
for a 5° offset on a 6 u lever (`|d| ≈ 0.5 u`) that is `0.0188 u / 0.008 s ≈ 2.3 u/s`, comfortably
under the 10 u/s sleep gate (`:1708`). **It still sleeps.**

**The failsafe, unchanged from the design and worth keeping:** if `capPhi` lands more than 30°
outside the widened range, the derivation is suspect (bad axis sign, exotic skeleton) — **disable
that one limit for that corpse** and print under `r_ragdollDebug 3`. Never snap.

### 5.2 A struck limb driven into a limit — the payoff case

`CG_RagdollImpulse` (`:1369-1522`) finds the closest of the 14 bone segments, splits the force
between its two ends by `bestT` (`:1428-1444`), puts it on `ptPrev`, and sets `limpMs` on **both
ends**. During the 600 ms window the shape-match alpha on those points is scaled to
`RAG_IMPACT_RELAX + (1−RAG_IMPACT_RELAX)·k` (`:926-931`), i.e. `0.25 × 0.05 = 0.0125` per substep at
the instant of impact — the limb is essentially free and travels on its injected velocity. It will
reach a limit.

What happens then, exactly:

1. `RagRotateSet` rotates the subtree **and its `ptPrev`**, so the limb's speed is preserved and its
   velocity is rotated tangent to the limit surface (§4.5). A forearm that hits the 145° elbow stop
   does not halt and does not bounce — **the whole arm keeps rotating about the shoulder.** That is
   the difference between "twitch" and "whip", and it is the single visual result this round is for.
2. Energy is bounded by the existing damping alone: `0.98^75 = 0.2198` over the 600 ms window
   (`exp(75 · ln 0.98) = exp(−1.5152)`). No special-case braking needed.
3. **The correction can never be a flick.** Maximum per-substep violation growth on a limp limb is
   bounded by the velocity cap: 8 u/substep on a hand 25 u from its elbow is
   `8/25 = 0.32 rad = 18.3°` of new violation per substep, of which the first iteration removes
   47.9 %. There is no path to a 60° single-substep unwind. `RAG_LIMIT_MAX_STEP` (12°) is a belt
   against a case this arithmetic says cannot arise.

**A defect worth fixing in the same build, because it is in the way of the acceptance test.**
`CG_RagdollImpulse` limps only the two ends of the struck *segment* (`:1443`). Hit the forearm
(segment 6→7) and points 6 and 7 go limp; hit the upper arm (segment 5→6) and points 5 and 6 go
limp while **the hand, point 7, keeps the full 0.25 pull** and is reeled home at 68 % per frame
(`1 − 0.75⁴`), dragging the forearm back with it. The arm bends at the wrist instead of swinging at
the shoulder. One line: after selecting `bestJ`, also set `limpMs` on `subtree(bestJ)` at half the
window. This is why "arms aren't moving" survived the bone-segment targeting fix.

---

## 6. COST

Flop counts are for the arithmetic in `RagStep`; transcendentals are counted separately because they
dominate. `RAG_ITERS = 6`, `RAG_SUBSTEP_MS = 8`, `RAG_MAX_STEPS = 4`, `RAG_MAX_SIMS = 8`.

| per body per substep | today (15 pts) | round 11 (17 pts) | Δ |
|---|---:|---:|---:|
| integrate | 450 | 510 | +60 |
| distance links × 6 | 2 700 | 3 072 | +372 |
| braces × 6 | **3 072** | **1 152** | **−1 920** |
| angular limits × 6 | 0 | 9 180 | +9 180 |
| `RagLimitPrepare` | 0 | 470 | +470 |
| `RagLimitPost` | 0 | 1 530 | +1 530 |
| `RagBodyRotationAdvance` | 200 | 200 | 0 |
| `RagShapeMatch` | 560 | 640 | +80 |
| **total** | **≈ 6 980** | **≈ 16 754** | **≈ 2.4×** |

Deleting ten braces pays back a fifth of the limits' cost before anything else happens.

Per-limit means assume a 15 % violation rate (capture is legal, the shape-match holds near it):
swing ≈ 84 flops (64 idle / 198 firing), hinge flexion ≈ 95, hinge out-of-plane ≈ 49 (it reuses
`a`, `b`, `h` from its paired flexion entry — **pair them in the table or you pay twice**), J3 ≈ 114
at a 2 % rate. Per sweep: `10×84 + 4×95 + 4×49 + 114 = 1 530`.

**Transcendentals per body per substep:** 19 `atan2`/`asin` × 6 iterations = 114, plus ~34
`sin`/`cos` pairs in `RagMat3FromAxisAngle` for the firing subset, plus ~250 `sqrt` in the
normalizations. At representative x86 costs (atan2 ≈ 30 ns, sin/cos ≈ 25 ns, sqrt ≈ 7 ns):
`114×30 + 34×25 + 250×7 ≈ 3.4 + 0.85 + 1.75 = 6.0 µs`, plus ~2 µs for the rest ≈ **8 µs**.

```
8 us  x  4 substeps  x  8 bodies  =  256 us  =  0.26 ms / frame worst case
```

**Against what already runs.** World collision is `nPts × substeps × bodies` = `17 × 4 × 8` = **544
`CM_BoxTrace` calls per frame**, up from 480. At 1-5 µs per BSP box sweep that is **0.5-2.7 ms** —
so the limit solver is a *minority* cost next to the traces the system already pays every frame, and
its 64 extra traces are a 13 % increase on a counter whose observed peak was 75 (r9), against a
budget of 240 that world traces do not even draw from (`:1107-1108`, bug-1967).

Memory: `+2` points across `pt/ptPrev/goal/restDir/rot0/driveDir0/…` ≈ 264 B, hinge state
(4 × 2 × vec3) 96 B, per-sim limit runtime (`lo0/hi0/capPhi/flags` × 19) ≈ 304 B ⇒ **≈ 670 B per
sim, ≈ 5.4 KB across the pool of 8**, against ~77 KB today. Noise.

Available headroom if it is ever needed: the swing limits only need to know *whether* `φ` is outside
`[lo,hi]` and by how much; comparing against precomputed `sin`/`cos` of the bounds removes about half
the `atan2` calls. Not worth the complexity today — state it, do not build it.

---

## 7. TUNING VALUES AND CVARS

```c
#define RAG_PTS               17     /* was 15 (:57); feet appended, no index renumbered */
#define RAG_LIMITS            19
#define RAG_HINGES             4
#define RAG_ITERS              6     /* :61 unchanged */
#define RAG_LIMIT_K_HINGE   0.98f    /* net; k' = 1 - powf(1-k, 1.0f/RAG_ITERS) = 0.4790 */
#define RAG_LIMIT_K_SWING   0.90f    /*                                          = 0.3187 */
#define RAG_LIMIT_K_TWIST   0.50f    /*                                          = 0.1091 */
#define RAG_LIMIT_BAND      DEG2RAD(4.0f)    /* smoothstep ramp at the boundary */
#define RAG_LIMIT_MAX_STEP  DEG2RAD(12.0f)   /* per-projection belt */
#define RAG_HINGE_FLOOR     DEG2RAD(2.0f)    /* never fully straight: singularity guard */
#define RAG_HINGE_BENT_SIN  0.4226f  /* sin 25 deg: capture bend that is unambiguously flexion */
#define RAG_HINGE_SNAP_SIN  0.6428f  /* sin 40 deg: transport-drift re-anchor belt */
#define RAG_SIGN_MIN_DOT    0.35f    /* |h . bodyLeft|; acos(0.35) = 69.5 deg of parent roll */
#define RAG_SWING_AXIS_MAX  0.94f    /* skip a swing angle when b is within 20 deg of its axis */
#define RAG_TIGHTEN_MS      300      /* aligned with the alpha ramp at :1016, not the design's 250 */
#define RAG_SPINE_MU        0.35f    /* J3 only */
```

```c
/* RagCvars(), cg_ragdoll.c:299-320 */
rag_limits = cgi.Cvar_Get("coop_ragdollLimits",     "1",   CVAR_TEMP);
rag_limk   = cgi.Cvar_Get("coop_ragdollLimitStiff", "1.0", CVAR_TEMP); /* scalar on all three k */
```

**`coop_ragdollLimits` carries the atomicity rule as a single value**, so the pair can never be
half-shipped and the rollback is one word:

| value | points | braces | limits | purpose |
|---|---|---|---|---|
| **0** | 15 | all 16 | none | **ROLLBACK — today's build, byte for byte** |
| **1** | 17 | rows 0-5 | 19 | **SHIP DEFAULT** |
| 2 | 17 | all 16 | 19 | over-constrained control: if this looks like 1, the braces were never the stiffness |
| 3 | 17 | rows 0-5 | none | null control: **expect a pile.** Proves the limits are load-bearing |

Rows 6-15 and `s_ragBraceMinFactor` **stay in the source** and are gated at `:989`, rather than
being deleted — that is what makes modes 0/2/3 reachable without a rebuild, and it is a strictly
stronger form of the atomicity rule than "delete both together".

⚠ Mode and feet are decided **at capture**, so a cvar change applies to the *next* corpse. Say this
in the echo line. `coop_ragdollLimitStiff` is read live and applies immediately.

New hotkey cfg, matching the existing `rag_*.cfg` convention:

```
// hzm-mohaa-coop-mod/coop_mod/cfg/rag_lim.cfg   [bind F9]
// Cycles the limit solver: 1 = ship, 0 = pre-r11 rollback, 3 = null control (expect a pile),
// 2 = braces AND limits. Applies to the NEXT corpse - kill a fresh one after each press.
```

`rag_run.cfg` (F8, the reset key) gains `coop_ragdollLimits 1` and `coop_ragdollLimitStiff 1.0`.

New instrument — a **third** sleep line, never fields appended to the existing two (they are the
round-10 acceptance channel and something parses `^~^~^`):

```
^~^~^ RAGDOLL sleep-lim ent=%d mode=%d pts=%d lim=%d limmax=%.1f limoff=%04x
      hinge=%d/%d agree=%d/%d limbad=%d
```

and at capture under `r_ragdollDebug 3`, one line per hinge: `capPhi`, the branch taken, the
medio-lateral dot `d`, AGREE/DISAGREE, and `RagMat3TransRotateVec(W0p, h0, ...)` — the local
components that become round 12's four hard-coded constants (§3.4).

---

## 8. ACCEPTANCE — LIVE-OBSERVABLE, AND THE ONE-COMMAND ROLLBACK

**Rollback:** `coop_ragdollLimits 0` — then kill a fresh corpse. Restores today's constraint set
exactly. If anything about this build is worse, that is the whole recovery.

| # | what the user does | PASS |
|---|---|---|
| **G0** | F7 freeze drill | unchanged from today. Fails here ⇒ nothing else is readable. The limits are structurally invisible to it (frozen points ⇒ zero violation), so a failure is a *different* regression |
| **G1** | 40 kills, `r_ragdollDebug 1` | ≥ 38 arms, zero `capture FAILED`, zero `arm refused`, zero blowups. **Coverage is a hard stop** — bug-1969's 22 % → 98 % is not being handed back |
| **G2** | **shoot a settled corpse three times in one forearm** | the forearm swings about the **elbow** and stops around 145° instead of folding through the upper arm. Under `coop_ragdollLimits 0` the same shots barely move it. `lim=` > 0, `limmax` ≤ 12° |
| **G3** | **grenade ~60 u from a corpse** | limbs move *independently* — the "still kind of as a whole body" verdict must break. No knee bends backwards, no elbow inverts, in any frame |
| **G4** | F9 → mode 3 (null control), kill two | **a pile.** If mode 3 looks like mode 1, the limits are not firing and `lim=` will confirm it |
| **G5** | F9 → mode 2, kill two | if this is indistinguishable from mode 1, the braces were never what made corpses stiff and §2's whole premise needs revisiting — a genuinely useful negative |
| **G6** | round-10 numbers must not regress | `spin` at sleep < 3 °/s, `rot` < 30°, `yawf` ≈ 0, `stretch` ≤ 1.10, zero leash trips. §4.3 says these are structurally protected; G6 is the check that the proof is real |
| **G7** | `r_ragdollDebug 3`, look at the capture lines | ≥ 80 % of hinges resolved by the bent branch; `limoff` = 0 on a normal standing death; record the AGREE/DISAGREE tally — **that tally is the deliverable of this session** |
| **G8** | look at a corpse's legs | the calf is visibly no longer parallel to the thigh. This one is the feet, not the limits, and it is visible at mode 3 vs mode 0 |

---

## 9. THE THREE HAZARDS

**H1 — the sign convention. Highest probability, worst symptom, and it is invisible until a body
lands.** The design's shoulder and hip flex/ext ranges are inverted under MOHAA's FLU axis order
(§2.3). Ship them verbatim and hips get 25° of flexion against 110° of extension — corpses whose
legs fold backwards, i.e. the exact complaint, delivered by the fix for it. Nothing in the freeze
drill, the numeric harness, or any span/spin metric can see it, because it is a *range* error and
not a math error. **Mitigation:** the derivation table in §2.3 is the check — for each joint,
compute `n × n₁` by hand once and confirm it points where the range's positive end says; and G3
watches specifically for a backwards knee, which is the loudest possible signature.

**H2 — the hinge sign on a straight-limb capture.** The bent branch trusts the authored pose and is
exact; the straight branch falls back to the medio-lateral rule, which degrades when the parent bone
is rolled more than 69.5° (arm flung out to the side with a rolled humerus). The failure is not a
backwards knee — it is a **limb locked straight**, because the flexion range `[+2°,+145°]` measured
through a negated axis clamps every real bend back to +2°. **Mitigation:** `RAG_SIGN_MIN_DOT`
disables the flexion limit for that joint on that corpse rather than guessing (the out-of-plane
clamp survives, because it needs only the axis line); `limoff` reports it per body; and G7's
AGREE/DISAGREE corpus is designed to retire the whole branch in round 12.

**H3 — coverage regression through the new capture code.** Three of this round's items sit in or
beside the capture path that bug-1969 fought over: two new tag lookups (`Bip01 L/R Foot`), two triad
derivations that can fail, and four hinge derivations that can fail. A single careless `return
qfalse` there costs the whole session. **Mitigation, stated as a rule:** *nothing in §3 may ever
fail the capture.* Every failure path sets `limitsOk = 0` or `J->resolved = 0`, keeps the sim, and
prints. `nPts` degrades 17 → 15 on a missing foot tag instead of refusing to arm. G1 is a hard stop
and is checked before any visual verdict is taken.

---

## 10. WHAT THIS DOCUMENT DELIBERATELY DOES NOT DO

| not doing | round | why |
|---|---|---|
| `RagBuildFrames` + the `RagPush` rewrite (design §3.4/§3.5) | 12+, if ever | Its primary motivation (the off-by-one bone driver) shipped as `s_ragDriveChild`; what remains is twist inheritance, a render defect orthogonal to limits. §3.5's transport gets the hinge axes without touching the render path that has broken twice and that the freeze drill cannot see |
| self-collision pairs (design §7) | 12 | Genuinely cheap and genuinely wanted (forearm-through-torso), but it is a second question in the same build. The shoulder abduction limit and the self-collision pairs are complementary; land the limit first so the pairs are measured against it |
| twist limits (design §4 Option B) | never, under Option A | Nothing generates relative twist, so nothing can violate a twist range. J3 is the only real twist DOF and it is in the table |
| `RAG_ITERS` 6 → 4, substeps 8 ms → 4 ms | 12 | Right per Macklin 2019, and it moves the collision rate, the sleep meter's units, the impulse `subDt` and the limp decrement all at once. It would confound every reading in this build |
| `RagSane` span 200 → tighter | 12 | Must be re-baselined **after** feet extend the leg chain (§2.6), not before |
| distance re-enforcement after `RagShapeMatch` | not triggered | The r9 trigger was `stretch > 1.3`; live is 1.01-1.07 |
| touching `RagRawFit`, `RagBodyRotationAdvance`, the latch, or `RagPush` | — | The spin problem is solved. §4.3 proves the limits cannot reach it; that proof is worth more than any tuning it might buy |

---

## 11. IN-REPO ANCHORS

- `openmohaa-hzm/code/cgame/cg_ragdoll.c` — the system. Key sites: `s_ragBones:73`,
  `s_ragDriveChild:100`, `s_ragBraces:123`, `s_ragBraceMinFactor:145`, `s_ragPtRadius:248`,
  `s_ragAnchorTable:261`, `RagCvars:299`, `RagTriad:410`, `RagMat3FromTo:449`, `RagCapture:530`,
  pre-lift `:610`, radius clamp `:708`, `RagRawFit:832`, `RagBodyRotationAdvance:859`,
  `RagShapeMatch:907`, `RagStep:942`, links `:967`, braces `:980`, `RagCollideWorld:1089`,
  `RagSane:1184`, `RagPush:1225`, `CG_RagdollImpulse:1369`, substep loop `:1599`,
  stretch instrument `:1648`, sleep `:1693`, `RagPendingThink:1870`, goal copy `:1950`
- `openmohaa-hzm/code/renderergl1/tr_ragdoll.cpp:158-171` (byte-identical to the gl2 copy) — Hook A
  copies the pushed 3×3 straight into `skelBoneCache_t::matrix` with **no** re-orthonormalization.
  Nothing in this round produces a bone matrix, so that hazard is not touched — but it is why §3.4's
  frame chain would have needed a mandatory `RagMat3Ortho`
- `openmohaa-hzm/code/cgame/cg_public.h:406-409, :453-454` — `Tag_NumForName`, `Tag_NameForNum`,
  `ForceUpdatePose`, `TIKI_Orientation`, `R_SetRagdollPose`, `R_ClearRagdoll`. **This round adds no
  import.**
- `openmohaa-hzm/code/qcommon/q_math.c:769-791` `AnglesToAxis` (FLU rows, verified at yaw 0 and 90);
  `:2018-2033` `VectorNormalize` (returns the **squared** length on the degenerate path)
- `openmohaa-hzm/code/qcommon/q_shared.h:167` `math.h`; `:430` `M_PI`; `:525` `DEG2RAD`;
  `:531` `Q_clamp` **assigns to its first argument — a statement, not an expression**; `:820` `Q_acos`
- `openmohaa-hzm/code/qcommon/cm_trace_lbd.cpp:31-51` — the 19-name hitloc table containing
  `Bip01 L/R Foot`
- `_research/ragdoll_joints_design.md` — the design this re-derives; §2.3 and §3.4 correct it
- `_research/ragdoll_r9_spec.md` §3.5, §8 — the deferral ledger this round draws from
- `_research/ragdoll_r9_impact.md` §4.3 — the limp-window design §5.2 builds on
- `.wolf/buglog.json` — 1962 (collision ordering, sleep gate), 1963 (push math), 1964 (space
  contract), 1965 (settle handoff), 1966 (`s_ragDriveChild`), 1967 (trace budgets), 1969 (coverage),
  1970 (radius clearance clamp)
- `hzm-mohaa-coop-mod/coop_mod/cfg/rag_*.cfg` — the hotkey set; `rag_lim.cfg` is the new F9
