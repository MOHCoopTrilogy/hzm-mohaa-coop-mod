# Ragdoll — Anatomical Joints Design (2026-08-19)

Successor to `ragdoll_pile_findings.md`. That document closed the *mechanical* defects (space
contract, push conjugation, collision ordering, anchoring, contact friction) — all fixed and
live-verified, with `coop_ragdollTest 2` now rendering a pixel-perfect frozen soldier.

This document specifies the *anatomical* layer: joint limits, bone-frame reconstruction, twist,
and self-collision. Target file: `openmohaa-hzm/code/cgame/cg_ragdoll.c`. Nothing here needs an
engine, protocol or `game.dll` change — **every change in the recommended option ships in
`cgame.dll` alone.**

---

## 0. The one-line diagnosis, restated precisely

> Distance constraints are *symmetric*: `|p_a − p_b|` is invariant under reflecting the joint
> through the plane normal to `p_a − p_b`. Every anatomical limit is *antisymmetric* — a knee
> bends one way and not the other. **No set of distance constraints, of any size, can encode a
> joint limit.** The 10 "fold limit" braces in `s_ragBraces` are therefore not an approximation
> of anatomy; they are a different constraint that happens to reduce the worst tangles.

The live sleep spans confirm the point cloud is *not* collapsed:

| span at sleep | horizontal diagonal | vs ~57 u full extension |
|---|---|---|
| (41 41 6) | 58.0 | 102 % |
| (38 41 7) | 55.9 | 98 % |
| (52 33 5) | 61.6 | 108 % |
| (38 45 5) | 58.9 | 103 % |
| (32 38 5) | 49.6 | 87 % |

Four of five bodies reach full length. They are extended *and* wrong — which is exactly the
signature of "legal by distance, illegal by anatomy", plus a render-frame defect (§1.1) that
makes even legal configurations look mangled.

---

## 1. Three defects, ranked, that this design fixes

### 1.1 CRITICAL — every bone is driven by the wrong segment (off-by-one)

`RagPush` computes, for sim bone `i` with parent `p`:

```c
VectorSubtract(s->pt[i], s->pt[p], dNow);          // cg_ragdoll.c:863
RagMat3FromTo(s->restDir[i], dNow, S);             // :868
RagMat3Mul(s->rot0[i], S, rotNow[i]);              // :871
```

`pt[p] → pt[i]` is the segment **above** bone `i`. But a bone's origin is at its own head and
its skinned mesh runs from there to its *child*. `Bip01 L UpperArm`'s origin is the shoulder;
the upper-arm mesh spans shoulder→elbow; therefore the segment that must drive bone 5's
rotation is `pt[5] → pt[6]`, not `pt[2] → pt[5]`.

Consequence, concretely: rotate the whole arm at the shoulder. Under the current code the elbow
point `pt[6]` moves, so bone 6 (Forearm) is rotated — but `pt[5]` does not move relative to
`pt[2]`, so bone 5 (UpperArm) is **not** rotated. The upper-arm mesh keeps pointing where it
died while the forearm bone is repositioned at the new elbow. The mesh tears/shears across the
elbow. Every limb, every frame. This reads exactly as "hyperextended joints" and "arms bent
through the torso" even when the points are fine.

It is invisible in the freeze drill because at capture `S = I` for every choice of segment.

**Confirmation test (10 lines, do this first).** At capture, for each sim bone with a sim child,
print the two angles

```
angPar   = acos( dot( row0(W0_i), unit(pt0_i − pt0_parent) ) )
angChild = acos( dot( row0(W0_i), unit(pt0_child − pt0_i) ) )
```

where `W0_i = rot0[i] * E` is bone `i`'s **world** frame at capture. If `angChild ≈ 0` and
`angPar` is large, the off-by-one is confirmed and the bone frames are down-`+X` (the 3ds Max
Biped convention that MOHAA's exporter uses). If neither is ≈ 0 the bone frames are not
down-bone at all — the design below still works, because it derives the down-bone direction
per bone at capture (`uLocal[i]`, §3.3) instead of assuming an axis.

### 1.2 HIGH — bone twist is never reconstructed

`RagMat3FromTo` returns the *minimal* rotation between two directions: pure swing, zero twist,
by construction. Nothing else in the push supplies twist. So every bone renders with its
capture-pose roll about its own axis, unchanged, no matter how the body has tumbled. Forearms,
hands, shins and feet — the bones with the largest twist offset relative to their parent — are
the ones that read as "rolled".

Note the *right* fix here is not "simulate twist". A limp forearm has no twist source of its
own; its roll is entirely the humerus's roll. The fix is to make twist **inherit** (§4).

### 1.3 HIGH — the knee is not simulated at all, and the shin is not either

The sim ends at `Bip01 L/R Calf`. `pt[12]` **is** the knee. Therefore:

- `|pt[0] − pt[12]|` (the "knee fold limit" brace, `s_ragBraces` rows 11-12) is a function of
  the **hip** angle, not the knee angle. It has never constrained a knee.
- The shin has no direction of its own. Bone 12 renders with the swing of `pt[11] → pt[12]`,
  i.e. the *thigh*'s direction (see §1.1) — the shin follows the thigh rigidly and the knee
  stays frozen at its death-pose bend forever. "Legs folded up behind the back" is largely this.

Adding `Bip01 L Foot` / `Bip01 R Foot` as points 15 and 16 costs 2 points and 2 links and makes
the knee both observable and constrainable. Both names are in the engine's own 19-entry LBD
hitloc table (`qcommon/cm_trace_lbd.cpp:31-51`) and were verified present in every skd checked
during vet1 (AA `usarmy.skd`, BT `SC_AL_US_INF.skd`, SH `brit_tank_corp.skd`, and the mod's
imported `brit_para.skd` / `battledress.skd`).

---

## 2. What the literature actually says

| source | what it gives us |
|---|---|
| Jakobsen, *Advanced Character Physics*, GDC 2001 (§ constraints / articulated bodies) | Verlet + Gauss-Seidel projection is our exact foundation. Two directly relevant statements: **inequality constraints** are "only enforced if distance falls below threshold" — the correct shape for a limit; and **angular constraints** are done by "restricting the angle between vectors `a` and `b` by enforcing a dot-product constraint", i.e. *angles are projected as positions*. Also: Hitman's own humans were "stick figures … rotation around limb length axis not simulated", relying on the animation skeleton for knee/elbow plausibility. Relaxation counts shipped were **1-10**, "3 to 4 … enough" for rigid bodies. Friction is applied by moving the *previous* position, not by zeroing velocity. |
| Müller, Heidelberger, Hennix, Ratcliff, *Position Based Dynamics*, VRIPhys/JVCIR 2007 | The constraint-projection framework: `Δp_i = −w_i · C / (Σ w_j |∇_j C|²) · ∇_i C`; type `inequality` ⇒ "the projection is only performed if `C(p) < 0`"; Gauss-Seidel (immediate write-back) converges far faster than Jacobi and is order-dependent. Two things we use verbatim: (a) the **bending constraint** `C = acos(n̂₁ · n̂₂) − φ₀` — the canonical proof that an *angle* is a legal position-based constraint; (b) the **stiffness transform** `k′ = 1 − (1 − k)^(1/n_s)`, which makes a per-iteration stiffness produce an iteration-count-independent net stiffness. |
| Müller, Macklin, Chentanez, Jeschke, Kim, *Detailed Rigid Body Simulation with Extended Position Based Dynamics*, CGF 39(8) 2020 | The joint-limit recipe we adopt wholesale, Algorithm 3: `LimitAngle(n, n₁, n₂, α, β)` — signed angle about a common axis, clamped, projected as an angular correction. Plus the axis choices: hinge ⇒ `[n,n₁,n₂] = [a₁, b₁, b₂]`; spherical **swing** ⇒ `[a₁×a₂, a₁, a₂]`; spherical **twist** ⇒ `n = (a₁+a₂)/|a₁+a₂|`, `n₁ = normalize(b₁ − (n·b₁)n)`, `n₂ = normalize(b₂ − (n·b₂)n)` — "twist must be decoupled from swing". Soft limits fall out of a non-zero compliance. |
| Macklin, Storey, Lu, Terdiman, Chentanez, Jeschke, Müller, *Small Steps in Physics Simulation*, SCA 2019 | Given a fixed time budget `n_substeps × n_iters`, accuracy is maximised at **max substeps, one iteration each**. Restated in the 2020 paper: "numPosIters is typically set to 1". Our current 4×8 ms substeps × 6 iterations is on the wrong side of that trade, and is worth revisiting once limits land. |
| Zordan & Hodgins, *Motion capture-driven simulations that hit and react*, SCA 2002; Zordan, Majkowska, Chiu, Fast, *Dynamic response for motion capture animation*, SIGGRAPH 2005; Shapiro, Pighin, Faloutsos, *Hybrid control for interactive character animation*, PG 2003 | The literature's answer to §9: passive simulation from an animated pose does not look right on its own. Every published approach blends — track the animation with a controller, release over a short window, and (optionally) blend back. |
| Holden, *Joint Limits* (theorangeduck) | Swing-twist decomposition `p = (q_xyz · â)â ; twist = normalize(q_w, p) ; swing = q · twist⁻¹`. Also the practical warning we heed in §5.4: rectangular (box) limits are cheap and tight but have "discontinuity around the box corners"; ellipsoids are smooth but loose. |

**What this means for us.** Jakobsen's own ragdoll dodged the problem (no twist, joint
plausibility from the skeleton). Müller 2020 gives a joint-limit primitive that is *purely* a
signed angle about an axis, clamped, applied as a rotation — and that primitive works just as
well on a point cloud rotated about a pivot as it does on a rigid body. We do not need rigid
bodies to get real joint limits. We do need **bone frames**, because the axes `n`, `a₁`, `b₁`
are frame quantities. §3 builds those frames from the point cloud.

---

## 3. Shared prerequisites (needed by BOTH options)

### 3.1 Point roster grows to 17

Append, do not renumber (existing indices 0-14 keep their meaning; only the anchor table moves):

```c
#define RAG_PTS 17
static const struct { const char *name; int parent; int child; } s_ragBones[RAG_PTS] = {
    {"Bip01 Pelvis",    -1,  1},  // 0   child = PRIMARY child (spine), for the forward axis
    {"Bip01 Spine1",     0,  2},  // 1
    {"Bip01 Spine2",     1,  3},  // 2   frame comes from its own triad, see 3.2
    {"Bip01 Neck",       2,  4},  // 3
    {"Bip01 Head",       3, -1},  // 4   terminal
    {"Bip01 L UpperArm", 2,  6},  // 5
    {"Bip01 L Forearm",  5,  7},  // 6
    {"Bip01 L Hand",     6, -1},  // 7   terminal
    {"Bip01 R UpperArm", 2,  9},  // 8
    {"Bip01 R Forearm",  8, 10},  // 9
    {"Bip01 R Hand",     9, -1},  // 10  terminal
    {"Bip01 L Thigh",    0, 12},  // 11
    {"Bip01 L Calf",    11, 15},  // 12  <-- now has a child
    {"Bip01 R Thigh",    0, 14},  // 13
    {"Bip01 R Calf",    13, 16},  // 14
    {"Bip01 L Foot",    12, -1},  // 15  NEW, terminal
    {"Bip01 R Foot",    14, -1},  // 16  NEW, terminal
};
static const float s_ragPtRadius[RAG_PTS] = {
    7.0f,7.0f,7.5f,4.0f,5.0f,  4.0f,3.0f,2.5f,  4.0f,3.0f,2.5f,
    5.0f,4.0f, 5.0f,4.0f,  3.0f,3.0f            // feet
};
```

Anchor-table changes (`s_ragAnchorTable`): `"Bip01 L Foot" → 15`, `"Bip01 L Toe" → 15`,
`"Bip01 R Foot" → 16`, `"Bip01 R Toe" → 16`. Everything else is unchanged. `RagCapture`'s
existing bail-clean on a missing tag name covers any skd that lacks a foot bone.

Subtree masks (`unsigned s_ragSubtree[RAG_PTS]`, bit `i` set ⇒ point `i` is at or below that
point) are computed once at init by a reverse walk; they are the moving set for every angular
correction. With 17 points a `u32` suffices.

### 3.2 Two anatomical triads, derived from the model's own socket geometry

The pelvis and the chest are the only two places where the point cloud carries enough
information for a full 3-DOF frame (a direction *and* a lateral line). Both lines are between
points that are rigidly attached to the same bone in any pose — the hip sockets are the thigh
bone origins, the shoulder sockets are the upper-arm bone origins — so this derivation is
**pose-independent** and needs no bind pose.

MOHAA convention throughout: row-vector, rows are **F**orward / **L**eft / **U**p
(`AnglesToAxis`, `q_math.c:784`), right-handed with `L × U = F`.

```c
// T rows = [F, L, U]; 'up' from tip-base, 'left' from right-socket -> left-socket
static qboolean RagBodyTriad(const vec3_t tip, const vec3_t base,
                             const vec3_t sockR, const vec3_t sockL,
                             float faceSign, float T[3][3])
{
    vec3_t U, L, F, tmp;
    VectorSubtract(tip,   base,  U);  if (VectorNormalize(U) < 0.001f) return qfalse;
    VectorSubtract(sockL, sockR, L);
    VectorMA(L, -DotProduct(L, U), U, L);            // Gram-Schmidt against U
    if (VectorNormalize(L) < 0.001f) return qfalse;
    VectorScale(L, faceSign, L);                     // sign fixed once at capture
    CrossProduct(L, U, F);                           // right-handed FLU
    VectorCopy(F, T[0]); VectorCopy(L, T[1]); VectorCopy(U, T[2]);
    return qtrue;
}
```

Call sites:

| frame | tip | base | sockR | sockL |
|---|---|---|---|---|
| pelvis `T₀` | `pt[1]` (Spine1) | `pt[0]` | `pt[13]` (R Thigh) | `pt[11]` (L Thigh) |
| chest `T₂` | `pt[3]` (Neck) | `pt[2]` | `pt[8]` (R UpperArm) | `pt[5]` (L UpperArm) |

`faceSign` is resolved **once, at capture**, from the entity axis — which is the corpse's
facing at the moment of death and only has to be right to within 90°:

```c
RagBodyTriad(..., +1.0f, T);
s->faceSign[k] = (DotProduct(T[0], s->entAxis[0]) >= 0.0f) ? +1.0f : -1.0f;
```

Store `A_k = W0_k * T0_k^T` (row-vector: `W = A·T` ⇒ `A = W·T^T`), so at runtime
`W[k] = A_k * T_k(current)`. This makes the reconstruction **exact at capture** by
construction — `T = T₀ ⇒ W = W₀` — which is the invariant the freeze drill tests.

### 3.3 Per-bone capture data (replaces `restDir` / `rot0` / `relRot`)

At capture, for every sim bone `i`:

```c
W0[i]        = rot0[i] * E                    // bone world frame at capture  (3x3, orthonormal)
L_i          = W0[i] * W0[parent]^T           // capture-local rotation w.r.t. parent
uLocal[i]    = expressInFrame(W0[i], unit(pt0[child] − pt0[i]))   // derived down-bone axis
```

`expressInFrame(M, v)` is the existing `RagMat3TransRotateVec(M, v, out)` — components of `v`
along the rows of `M`.

`uLocal[i]` is the whole point of §1.1's "no assumption": whatever axis the exporter chose,
`uLocal[i]` records where the child sits in the bone's own frame, and the reconstruction just
keeps it pointing at the child.

Per channel, replacing today's `relPos`/`mat0`-rotation path:

```c
relW[ch]   = W0_ch * W0_anchor^T                            // constant world-relative rotation
relPos[ch] = expressInFrame(W0_anchor, worldPos_ch − pt0[anchor])
```

(Today `relPos` is stored in the anchor's *model* frame `rot0`; it must move to the *world*
frame `W0`. This is a two-line capture change, and the whole `conj[] = E·S·Eᵀ` sandwich in
`RagPush` disappears with it.)

### 3.4 Frame reconstruction — the core new routine

Run **once per substep**, before the Gauss-Seidel iteration loop (the axes it produces are used
by every iteration; an 8 ms lag on a joint axis is invisible and saves ~40 % of the cost). The
two anatomical triads are cheap enough to refresh per iteration if wanted.

```c
static const int s_ragFrameOrder[RAG_PTS] = { 0,2, 1,3,4, 5,6,7, 8,9,10, 11,12,15, 13,14,16 };

static void RagBuildFrames(ragSim_t *s, float W[RAG_PTS][3][3])
{
    float T[3][3];
    int   k, oi, i, p;

    // roots: the two anatomical triads
    if (RagBodyTriad(s->pt[1], s->pt[0], s->pt[13], s->pt[11], s->faceSign[0], T))
        RagMat3Mul(s->A[0], T, W[0]);
    else memcpy(W[0], s->W0[0], sizeof(T));            // degenerate: hold capture
    if (RagBodyTriad(s->pt[3], s->pt[2], s->pt[8], s->pt[5], s->faceSign[2], T))
        RagMat3Mul(s->A[2], T, W[2]);
    else memcpy(W[2], s->W0[2], sizeof(T));

    // everything else: inherit the parent's FULL frame (this is where twist comes from),
    // then swing so the bone still points at its child.
    for (oi = 2; oi < RAG_PTS; oi++) {
        float  C[3][3], S[3][3];
        vec3_t fCand, fMeas;
        i = s_ragFrameOrder[oi];
        p = s_ragBones[i].parent;
        RagMat3Mul(s->Lrel[i], W[p], C);               // C = L_i * W_p
        if (s_ragBones[i].child >= 0) {
            RagMat3RotateVec(C, s->uLocal[i], fCand);  // where the child SHOULD be
            VectorSubtract(s->pt[s_ragBones[i].child], s->pt[i], fMeas);
            if (VectorNormalize(fMeas) > 0.01f) {
                RagMat3FromTo(fCand, fMeas, S);        // pure swing, zero twist added
                RagMat3Mul(C, S, W[i]);
            } else memcpy(W[i], C, sizeof(C));
        } else {
            memcpy(W[i], C, sizeof(C));                // terminal bone: pure inheritance
        }
        RagMat3Ortho(W[i]);                            // MANDATORY, see risk 1
    }
}
```

`RagMat3Ortho` is Gram-Schmidt on the rows. It is **not optional**: `tr_ragdoll.cpp`
(`R_RagdollApplyToCache`, renderergl1 and gl2 are byte-identical) copies the pushed 3×3 into
`skelBoneCache_t::matrix` element by element with no normalization, determinant check or
quaternion round-trip. Any drift from repeated matrix products becomes a visible mesh
shear/scale.

Three properties worth stating explicitly, because they are the payoff:

1. **Off-by-one gone.** Bone `i` is driven by `pt[i] → pt[child]`, the segment it skins.
2. **Twist inherited.** `S` is a pure swing, so no bone ever twists relative to its parent —
   which is precisely how a limp limb behaves. Forearms roll with the humerus, shins with the
   thigh, hands with the forearm. Nothing renders "rolled" any more, and there is no twist DOF
   left un-reconstructed. Torso twist *is* simulated, because the chest gets its own triad from
   the shoulder line.
3. **Every joint now has an axis-carrying frame**, which is what §5 needs.

### 3.5 The push, simplified

```c
for (ch = 0; ch < s->count; ch++) {
    int a = s->anchor[ch];
    float Wch[3][3];
    vec3_t off, world, relw;

    RagMat3RotateVec(W[a], s->relPos[ch], off);          // anchor world frame
    VectorAdd(s->pt[a], off, world);

    RagMat3Mul(s->relW[ch], W[a], Wch);                  // world channel frame
    RagMat3MulTrans(Wch, Enow, /*rows of*/ mat[ch]);     // world -> model (current placement)

    VectorSubtract(world, curOrigin, relw);              // positions: unchanged, already correct
    mat[ch][0][3] = DotProduct(relw, axisNow[0]) * invScale;
    mat[ch][1][3] = DotProduct(relw, axisNow[1]) * invScale;
    mat[ch][2][3] = DotProduct(relw, axisNow[2]) * invScale;
}
```

`rot0`, `restDir`, `hipDir0`, `conj[]` and the pelvis special case all disappear. The *space*
contract (world → model against the **current** `lerpOrigin` / `AnglesToAxis(lerpAngles)`) is
byte-for-byte the one that is already proven correct — do not touch it.

### 3.6 New helpers

```c
// row-vector rotation of 'ang' radians about unit axis n (right-handed: v*M rotates v by +ang)
static void RagMat3FromAxisAngle(const vec3_t n, float ang, float out[3][3]);
// signed angle taking n1 to n2 measured about n, in (-PI, PI]
static float RagSignedAngle(const vec3_t n1, const vec3_t n2, const vec3_t n)
{
    vec3_t x; CrossProduct(n1, n2, x);
    return (float)atan2(DotProduct(x, n), DotProduct(n1, n2));
}
// rigid rotation of a point set about a pivot, applied to pt AND ptPrev (full absorption)
static void RagRotateSet(ragSim_t *s, unsigned mask, const vec3_t pivot, const float R[3][3]);
static void RagMat3Ortho(float m[3][3]);   // Gram-Schmidt rows
```

`RagMat3FromAxisAngle` is a straight extraction of the body of the existing `RagMat3FromTo`
(same `t*x*x + c` row layout — that layout is already verified as the row-vector Rodrigues form,
`a * M == b` to 1e-9 in `scratchpad/rag_math_check.py`). Refactor `RagMat3FromTo` to call it;
the antiparallel special case then becomes `FromAxisAngle(anyPerp(a), PI)` and the existing
hand-rolled `2uuᵀ − I` branch can go.

`atan2` is used in place of Müller's `arcsin` + quadrant fixups (Algorithm 3 lines 1-4): it is
the same quantity, better conditioned, and removes three branches. `math.h` is unconditionally
included by `q_shared.h:167` for the native build; `cg_view.c:2204` already calls `atan2`.
`Q_acos` (`q_shared.h:820`) is the clamped variant if a dot product ever needs `acos`.

`RagRotateSet` rotating **both** `pt` and `ptPrev` about the same pivot is the single most
important anti-jitter decision in this design — see §5.5.

---

## 4. TWIST (task item 3) — the answer for both options

**Option A.** Twist is not simulated; it is *inherited*, exactly as §3.4 constructs it. Because
`S` is a minimal (pure-swing) rotation, `W_i = L_i · W_p · S_i` carries the parent's full roll
into the child and adds none of its own. Relative twist is identically zero at every joint, so:

- forearms/hands/shins/feet stop rendering rolled (they now share their parent's roll instead of
  being frozen at a capture-pose roll composed through a mismatched frame);
- **no twist limits are needed** — nothing generates twist, so nothing can violate a twist range.
  This is a genuine simplification, not a shortcut;
- the one twist DOF that *is* real for a corpse — the torso wringing between hips and shoulders —
  is simulated, because the chest frame comes from its own triad rather than from inheritance.
  That is the only twist limit in the whole table (J3, ±35°).

**Option B.** Twist is a free DOF stored in each body's quaternion. The push reads the bone
frame straight out of `q` (`QuatToMat`, `q_math.c:1783`, xyzw storage per `q_shared.h:419`), so
twist is free at render time — but it must then be *constrained*, or forearms and shins will
spin. Use Müller 2020's decoupled twist axes verbatim:

```
n  = (a1 + a2) / |a1 + a2|
n1 = normalize(b1 − (n·b1) n)
n2 = normalize(b2 − (n·b2) n)
LimitAngle(n, n1, n2, −twistMax, +twistMax)
```

with `[a,b,c]` the per-body perpendicular axis triad, `a` down-bone. Ranges: forearm ±80°,
humerus ±45°, shin ±25°, thigh ±40°, neck ±60°, spine segments ±25°.

---

## 5. OPTION A — Verlet point cloud + angular constraints (RECOMMENDED)

### 5.1 The primitive

Every anatomical limit reduces to Müller 2020 Algorithm 3, adapted to a point cloud: measure a
signed angle about a known axis, clamp it, and apply the *difference* as a rigid rotation of the
child subtree about the joint pivot.

```c
typedef struct {
    byte     pivot;        // point the rotation is about
    byte     dirFrom;      // b = unit(pt[dirTo] - pt[dirFrom]) ; usually == pivot
    byte     dirTo;
    byte     kind;         // RAGL_SWING_F, RAGL_SWING_L, RAGL_HINGE, RAGL_HINGE_OOP, RAGL_TWIST
    byte     frame;        // 0 = pelvis triad, 2 = chest triad, 255 = derived hinge axis
    byte     grand;        // hinge only: the grandparent point (a = unit(pt[pivot]-pt[grand]))
    float    lo, hi;       // radians, anatomical
    float    lo0, hi0;     // radians, widened to include the capture value (see 5.6)
    float    mu;           // reaction fraction applied to the complement set
    unsigned mask;         // moving set = subtree(dirTo)
    vec3_t   hLocal;       // hinge only: axis in the PARENT bone's capture-local frame
} ragLimit_t;
```

```c
static void RagLimit(ragSim_t *s, ragLimit_t *J, const vec3_t axis,
                     float phi, float lo, float hi, float k)
{
    float target = (phi < lo) ? lo : ((phi > hi) ? hi : phi);
    float d, R[3][3];
    if (target == phi) return;                          // inequality: project only when violated
    d = (target - phi) * k;
    RagMat3FromAxisAngle(axis, d * (1.0f - J->mu), R);
    RagRotateSet(s, J->mask, s->pt[J->pivot], R);
    if (J->mu > 0.0f) {
        RagMat3FromAxisAngle(axis, -d * J->mu, R);
        RagRotateSet(s, s->allMask & ~J->mask, s->pt[J->pivot], R);
    }
}
```

Rotating the whole subtree rather than nudging one point is what makes this stable: a rigid
rotation of a point set preserves **every** distance inside that set, so a limit correction can
never fight the distance links it passes through. Only the single link crossing the pivot is
affected, and it is preserved too because the pivot is on the rotation axis.

`mu = 0` means the parent side is treated as infinitely heavy for that limit. For limb joints
this is invisible on a corpse (a knee limit does not kick the torso) and it removes an entire
class of feedback loop. Spine joints use `mu = 0.35` because the "child subtree" there is most
of the body.

### 5.2 Swing limits (shoulder, hip, neck, spine) — two signed angles in a body frame

Müller's spherical-swing axes `[a₁×a₂, a₁, a₂]` give one symmetric cone. Human ROM is not
symmetric — a hip flexes 110° forward and extends 25° back — so use the *rectangular* form:
two `LimitAngle` calls about the two axes perpendicular to the neutral direction. Per Holden,
the box has a corner discontinuity; on a corpse settling in under two seconds it is invisible,
and the asymmetry it buys is exactly what stops "legs folded up behind the back".

Given joint pivot `P`, limb direction `b = unit(pt[dirTo] − pt[P])`, body frame `T` (rows
F/L/U from §3.2), and neutral direction `n₁` (a fixed row of `T`, or its negation):

```c
// flex/extension: signed angle from n1 to b, about the frame's LEFT axis
phi = RagSignedAngle(n1, b, T[1]);   RagLimit(s, J, T[1], phi, lo, hi, k);
// abduction/adduction: signed angle from n1 to b, about the frame's FORWARD axis
phi = RagSignedAngle(n1, b, T[0]);   RagLimit(s, J, T[0], phi, lo, hi, k);
```

Neutral directions, all derived (no per-model authoring):

| joint | frame | neutral `n₁` | meaning |
|---|---|---|---|
| L/R hip | pelvis `T₀` | `−T₀[2]` | thigh straight down |
| L/R shoulder | chest `T₂` | `−T₂[2]` | arm hanging down |
| neck | chest `T₂` | `+T₂[2]` | head straight up |
| spine1 | pelvis `T₀` | `+T₀[2]` | torso straight up |

Right-side limbs measure about the same axes; their abduction range is the mirror
(`[-hi, -lo]`), which is one table entry, not a code path.

### 5.3 Hinge limits (elbow, knee) — derived axis + anatomical sign invariant

The hinge axis must be derived, and must be derived in a way that survives a **straight** limb
at capture (common in death poses), where `a × b ≈ 0`.

```c
// ---- at capture, per hinge joint J = (g = grandparent, p = pivot, c = child) ----
VectorSubtract(pt0[p], pt0[g], a0); VectorNormalize(a0);
VectorSubtract(pt0[c], pt0[p], b0); VectorNormalize(b0);
CrossProduct(a0, b0, h0);
if (VectorLength(h0) > 0.208f) {              // sin(12 deg): the limb is bent, trust the plane
    VectorNormalize(h0);
} else {                                       // straight limb: take the parent bone's local
    int  k, best = 0; float bestd = 2.0f;      // axis most perpendicular to the bone
    for (k = 0; k < 3; k++) {
        float d = (float)fabs(DotProduct(W0[p][k], a0));
        if (d < bestd) { bestd = d; best = k; }
    }
    VectorMA(W0[p][best], -DotProduct(W0[p][best], a0), a0, h0);
    VectorNormalize(h0);
}
// ---- sign fix: the ANATOMICAL INVARIANT. Positive flexion must bring the child toward the
//      grandparent. True for every elbow (hand toward shoulder) and every knee (foot toward
//      hip) in every pose, which is why it works when the plane test does not.
{
    vec3_t bt, ct, dRef, dTest; float Rt[3][3], pc;
    vec3_t pcv; VectorSubtract(pt0[c], pt0[p], pcv); pc = VectorLength(pcv);
    RagMat3FromAxisAngle(h0, DEG2RAD(10.0f), Rt);
    RagMat3RotateVec(Rt, b0, bt);                     // b0 rotated +10 deg about h0
    VectorMA(pt0[p], pc, bt, ct);                     // where the child would move to
    VectorSubtract(pt0[c], pt0[g], dRef);
    VectorSubtract(ct,     pt0[g], dTest);
    if (VectorLengthSquared(dTest) > VectorLengthSquared(dRef)) VectorNegate(h0, h0);
}
J->hLocal = expressInFrame(W0[p], h0);        // carried in the PARENT bone's frame -> rides its twist
J->capPhi = RagSignedAngle(a0, b0, h0);
```

At solve time:

```c
RagMat3RotateVec(W[p], J->hLocal, h);                    // world hinge axis, this substep
VectorSubtract(s->pt[p], s->pt[g], a); VectorNormalize(a);
VectorSubtract(s->pt[c], s->pt[p], b); VectorNormalize(b);
phi = RagSignedAngle(a, b, h);                           // 0 = straight, + = flexion
RagLimit(s, J, h, phi, J->lo, J->hi, k);                 // lo = +2 deg, hi = +150 deg
```

The `lo = +2°` (not 0°) keeps the joint just off the straight singularity where the flexion
plane is undefined; the 2° residual bend is well under a pixel at any viewing distance and it
removes an entire failure mode.

**Out-of-plane clamp.** A hinge must also keep `b` in the plane spanned by `a` and `h × a`:

```c
float bh = DotProduct(b, h);
Q_clamp(bh, -1.0f, 1.0f);          // NOTE: q_shared.h:531 Q_clamp ASSIGNS to its first
                                   // argument - it is a statement, not an expression.
psi = (float)asin(bh);
if (fabs(psi) > psiMax) {
    vec3_t n; CrossProduct(b, h, n);
    if (VectorNormalize(n) > 0.001f) {
        float d = -(psi - (psi > 0 ? psiMax : -psiMax));
        RagMat3FromAxisAngle(n, d * k, R);
        RagRotateSet(s, J->mask, s->pt[p], R);
    }
}
```

(Rotating `b` about `unit(b × h)` by `+α` increases `b·h`, so the correction is `−Δψ`. This
constraint uses only `b` and `h`, so it stays well-defined when `a ∥ b`.) `psiMax` = 12° for
elbows (real elbows carry ~10° of carrying angle, and our derived axis is approximate), 8° for
knees.

### 5.4 Torso twist (the only twist limit in Option A)

Both `T₀` and `T₂` are measured from points, so the relative twist between hips and shoulders is
observable:

```c
// project both LEFT axes onto the plane normal to the chest UP axis, then take the signed angle
VectorMA(T0[1], -DotProduct(T0[1], T2[2]), T2[2], n1); VectorNormalize(n1);
VectorMA(T2[1], -DotProduct(T2[1], T2[2]), T2[2], n2); VectorNormalize(n2);
phi = RagSignedAngle(n1, n2, T2[2]);
RagLimit(s, &twistJoint, T2[2], phi, -35deg, +35deg, k);   // mask = subtree(2), mu = 0.35
```

This is Müller's twist recipe (eqs. 22-24) with `a₁ = a₂ = T₂[2]` — the degenerate-but-exact
case where the two bone axes are already aligned, which they are here because both frames share
the spine direction closely enough.

### 5.5 Solver ordering, stiffness, and the anti-jitter rules

Per substep:

```
1. integrate  (unchanged: Verlet, damping 0.98, 24 u/substep speed cap)
2. RagBuildFrames(s, W)                      <-- once per substep
3. for it = 0 .. RAG_ITERS-1:
     a. parent distance links, root -> leaf (i = 1..16)          [equality]
     b. structural braces  (the 6 EQUALITY rows only)            [equality]
     c. refresh T0, T2 from the current points                   [cheap, 2 triads]
     d. angular limits, root -> leaf, order reversed on odd 'it' [inequality]
     e. self-collision min-distance pairs                        [inequality]
4. RagCollideWorld(...)   (unchanged, per substep, after the constraints)
```

**Delete `s_ragBraces` rows 6-15 and the whole `s_ragBraceMinFactor` table.** Those ten
"fold limit" braces are superseded by real limits and will actively fight them (a min-distance
brace pushing a hand away from spine2 while the shoulder limit pulls the arm across is a
guaranteed limit cycle). Keep exactly the six equality rows — `{5,8} {11,13} {5,13} {8,11}
{3,1} {0,2}` — which are the rigid torso truss, not limits.

**Stiffness.** Apply limit corrections with a per-iteration factor `k′` derived from a net
stiffness `k` by Müller 2007's transform, so tuning is iteration-count independent:

```
k' = 1 - powf(1.0f - k, 1.0f / RAG_ITERS)
k = 0.98, RAG_ITERS = 6  ->  k' = 0.478       // 98% of any violation removed per substep
k = 0.98, RAG_ITERS = 4  ->  k' = 0.605
```

**The five anti-jitter rules** (PBD angular limits jitter for well-understood reasons; each is
addressed):

| failure mode | rule |
|---|---|
| limit injects energy every step, limb buzzes at the boundary | `RagRotateSet` moves **`pt` and `ptPrev` by the same rigid rotation** ⇒ the correction changes position with *zero* change to implied velocity. The joint stop is perfectly inelastic. The rotated velocity is tangent to the limit surface, so the limb *slides along* the stop instead of re-violating it. This is Jakobsen's "friction by previous-position manipulation" applied to joints. |
| axis flips near a degenerate configuration | The hinge axis comes from the **frame chain** (`hLocal * W_p`), never from a live `a × b`. It is always defined, even for a perfectly straight limb. |
| constraint activates/deactivates each iteration (chatter) | `k′ < 1` plus, optionally, a smoothstep ramp over the first 4° of violation: `k_eff = k′ · smoothstep(0, 4°, |violation|)`. |
| Gauss-Seidel order bias makes one side of the body stiffer | Reverse the limit sweep order on odd iterations. |
| redundant constraints fight | Ten fold-limit braces removed (above); no joint is constrained twice about the same axis. |

**Cost.** Per substep: 17 integrations (~340 flops) + 1 frame build (~2 700) + 6 × [16 links +
6 braces + 2 triads + ~21 limits + 15 self-collision pairs] ≈ 6 × 6 400 ≈ 38 k + 3 k ≈ **41 k
flops/substep**. Worst case 4 substeps × 8 sims = **1.3 Mflop/frame ≈ 0.2-0.4 ms**. Trace count
rises from 15 to 17 sweeps per body per substep — still far under the existing 240/frame ceiling
(world traces are already budget-exempt and hard-bounded). Dropping `RAG_ITERS` to 4 (per
Macklin 2019: substeps beat iterations) recovers a third of that.

### 5.6 Capture-time range widening — the anti-pop rule

The death pose may already sit outside a derived range (approximate axes; hyperextended anim
frames; unusual gear). Snapping it into range on the first simulated frame is a visible pop.

At capture, widen each range to admit the capture value plus 5°, then tighten linearly to the
anatomical value over `T_tighten = 250 ms`:

```c
J->lo0 = min(J->lo, capPhi - DEG2RAD(5));
J->hi0 = max(J->hi, capPhi + DEG2RAD(5));
// per substep:
t   = clamp(s->lifeMs / 250.0f, 0, 1);
lo  = J->lo0 + (J->lo - J->lo0) * t;
hi  = J->hi0 + (J->hi - J->hi0) * t;
```

Failsafe: if `capPhi` is outside `[lo − 30°, hi + 30°]` the derivation is suspect (bad axis
sign, weird skeleton) — **disable that one limit for that corpse** and print it under
`r_ragdollDebug 3`. Never snap.

---

## 6. OPTION B — per-bone oriented bodies + XPBD joints

### 6.1 Data layout

```c
#define RAG_BODIES 16                    // one per bone that has a child (17 points - 1)

typedef struct {
    vec3_t x, xPrev;                     // centre of mass, world
    vec4_t q, qPrev;                     // orientation, world, XYZW (q_shared.h:419)
    vec3_t v, w;                         // linear / angular velocity, world
    float  invMass;
    vec3_t invInertia;                   // DIAGONAL, body frame (capsule about local +X)
    float  halfLen, radius;
} ragBody_t;

typedef struct {
    byte   a, b;                         // parent body, child body
    vec3_t rA, rB;                       // attachment point, each body's REST frame
    float  axA[3][3], axB[3][3];         // [a,b,c] perpendicular unit axes, rest frame
    byte   kind;                         // hinge | spherical
    float  swingLo[2], swingHi[2];       // two swing ranges (radians)
    float  twistLo, twistHi;
    float  complSwing, complTwist;       // XPBD compliance; 0 = infinitely stiff
    float  lamSwing[2], lamTwist;        // Lagrange multipliers, zeroed each substep
} ragJoint_t;
```

Capsule inertia for a bone of length `2h`, radius `r`, mass `m`, about local `+X`:
`Ixx = ½ m r²`, `Iyy = Izz = m (3r² + 4h²)/12` (cylinder approximation is fine here).
Masses from a 75 kg human distribution: pelvis 0.14, spine1 0.10, spine2 0.14, neck 0.02,
head 0.08, upper arm 0.027, forearm 0.016, hand 0.006, thigh 0.10, calf 0.046, foot 0.014.

### 6.2 Solver loop (Müller 2020 Algorithm 1, `numPosIters = 1`)

```
h = dt / nSub
for nSub:
    for each body:  xPrev = x; x += h*v + h*h*g;
                    qPrev = q; q  += 0.5*h*[w,0]*q;  q = normalize(q)
    for each joint: solvePositional(attachment)     // Δx = r2 - r1, compliance 0
                    solveSwing0(); solveSwing1(); solveTwist()
    for each contact: solveContact()
    for each body:  v = (x - xPrev)/h
                    Δq = q * conj(qPrev);  w = 2*Δq.xyz/h;  if (Δq.w < 0) w = -w
```

Positional correction (eqs. 2-9), angular correction (eqs. 11-16), and `LimitAngle`
(Algorithm 3) go in verbatim; project `n`, `r`, `p` into the rest frame before touching `I⁻¹`
so the inertia stays diagonal, exactly as the paper prescribes.

Available helpers: `MatToQuat` / `QuatToMat` (`float[3][3]` ↔ `float[4]`, `q_math.c:1823/1783`),
`QuatNormalize` (`:3834`), `QuatFromRotAngleAxis` (`:4026`), `QuatMultiply1` (`:4092`, "rotate
by qa then qb"). **Do not** mix `QuatMultiply1` with `QuaternionMultiply` — the latter
(`q_math.c:4078`) composes in the opposite argument order. `QuatSlerp` does not normalize its
output.

### 6.3 Cost

Per substep: 16 bodies × ~50 flops (integrate + renormalize) + 15 joints × ~520 flops
(1 positional attach ≈ 120, 3 `LimitAngle` + angular corrections ≈ 400) ≈ **8.6 k flops**.
At 4 substeps × 8 sims: **275 kflop/frame ≈ 0.1 ms** — cheaper than Option A per substep,
because there is no per-iteration frame reconstruction.

**But the paper's whole result is that you should take many substeps.** At 8 ms substeps we get
4/frame; Müller uses 20-40. Going to 2 ms substeps (8/frame at 60 fps, 16 at 30 fps) is free for
the solver and *not* free for collision: 16 oriented segments want 16 **capsule** sweeps per
substep, i.e. 128-256 traces per body per frame against a 240/frame global ceiling for eight
bodies. Option B therefore drags a collision redesign with it — proxy spheres, or collision on a
subset of substeps, or a raised budget. That is the hidden cost, and it is the decisive one.

### 6.4 Render push under B

```
W_body_world = QuatToMat(q)                             // full frame, twist included
W_ch_world   = relW[ch] * W_body_world[anchorBody]      // relW as in 3.3
mat[ch] rows = W_ch_world * Enow^T
origin_world = x_body + (localOffset_ch) * W_body_world
```

Simpler than today's push and simpler than Option A's — no frame reconstruction at all. Twist is
free. The space contract is unchanged.

---

## 7. SELF-COLLISION (task item 4)

Cheap, and it directly targets the user's words ("arms bent through the torso"). Implement as
Jakobsen inequality sticks in the same Gauss-Seidel sweep as the limits, push-apart only, with
`ptPrev` moved by the same delta (same absorption rule as §5.5).

```c
static const struct { byte a, b; float min; } s_ragSelf[] = {
    { 6, 2, 9.0f}, { 9, 2, 9.0f},          // forearm  vs chest     <-- the headline pair
    { 7, 2, 9.0f}, {10, 2, 9.0f},          // hand     vs chest
    { 7, 1, 9.0f}, {10, 1, 9.0f},          // hand     vs spine1
    { 7, 0, 9.0f}, {10, 0, 9.0f},          // hand     vs pelvis
    { 7,13, 7.0f}, {10,11, 7.0f},          // hand     vs OPPOSITE thigh
    {12,14, 7.0f},                         // knee     vs knee
    {15,16, 6.0f},                         // foot     vs foot
    {12,16, 6.0f}, {14,15, 6.0f},          // knee     vs opposite foot
    { 4, 5, 7.0f}, { 4, 8, 7.0f},          // head     vs shoulder
};
```

16 pairs × 6 iterations × 8 sims = 768 distance tests/frame. Nothing.

**Which pairs actually matter, honestly:**

| pair class | benefit | why |
|---|---|---|
| forearm/hand vs chest, spine1, pelvis | **HIGH** | This is literally the reported symptom. The shoulder abduction limit (J8/J9) stops the *humerus* crossing the midline; only these pairs stop the *forearm* swinging through the ribcage. The two are complementary and neither alone is sufficient. |
| knee/foot vs opposite knee/foot | MEDIUM-HIGH | Stops scissored legs, which is the second-most-visible tangle and is not preventable by any single-joint limit. |
| hand vs opposite thigh | MEDIUM | Arms come to rest *on* the legs instead of inside them. Very visible on a settled corpse, which is what players actually look at. |
| head vs shoulder | LOW | The neck limit already prevents most of it. Keep it — it costs two comparisons — but do not expect to see a difference. |
| upper arm vs chest, thigh vs pelvis | SKIP | Already rigid struts in the truss (`{5,8}`, `{11,13}`, the crosses). Adding them would be a redundant constraint, i.e. a jitter source. |

**Limitation to state up front:** these are point-vs-point spheres at the *joints*. They stop
the wrist and elbow entering the torso volume; they do not stop the mid-forearm mesh clipping a
shoulder pad. Segment-vs-segment (capsule) self-collision would, at roughly 4× the cost and a
much fussier closest-point-between-segments routine. **Not worth it** — the joint spheres catch
the configurations a player reads as "wrong", and the mesh-level clipping reads as "cloth".

---

## 8. THE HONEST COMPARISON, AND THE RECOMMENDATION (task item 5)

| | Option A — points + angular constraints | Option B — oriented bodies + XPBD |
|---|---|---|
| Files touched | `cg_ragdoll.c` only | `cg_ragdoll.c` (near-total rewrite); collision path also |
| Lines | **≈ +520 / −110** (net +410) | **≈ +850 / −450** (net +400, but 850 of it is *new and unproven*) |
| Ships as | `cgame.dll` alone | `cgame.dll` alone |
| New math primitives | 4 small helpers (axis-angle, signed angle, rotate-set, ortho) | quaternion body integrator, generalized inverse mass, XPBD multipliers, swing-twist |
| Reuses proven code | **All of it** — collision, sweeps, sleep, mover wake, space contract, anchoring, seed | Collision needs redesign (capsules or proxies); sleep metric needs re-deriving from body velocities |
| Risk to the now-correct render path | **Moderate.** The orientation half is rewritten, but the freeze drill + the numeric harness pin it exactly (§10). | **Moderate-high.** Push is *simpler*, but everything feeding it is new. |
| Risk elsewhere | Low | **High** — reopens the collision path, the part that cost the most live rounds (bodies through floors, pinning, piles). |
| Expected live iteration rounds | 1-2 | 3-5 |
| Twist | Inherited (correct for a limp body); zero twist limits needed | A real DOF; must be limited or limbs spin |
| Angular momentum | Approximated by the point cloud's own inertia | Exact per body |
| Contacts | Point spheres (today's, +2 points) | Wants capsules |
| Per-frame cost, 8 corpses | 0.2-0.4 ms | 0.1 ms solver, but 2-4× the traces |

### What the user will actually see

Both options deliver the same three things, and those three things ARE the complaint:

1. **Anatomically legal configurations.** Knees and elbows bend one way, within 150°; hips and
   shoulders live inside asymmetric ranges; the neck does not fold backwards. Distance
   constraints cannot do this at any size; angular constraints do it in both options identically.
2. **Bones aimed by the segment they skin, with inherited twist.** No more sheared elbows, no
   more rolled forearms and shins. Option A reconstructs the frame; Option B integrates it. The
   *rendered result for a limp body is the same*, because a limp forearm has no independent
   twist to integrate.
3. **Limbs that do not pass through the torso**, from the shoulder/hip limits plus the
   self-collision pairs — identical work in both options.

Where they differ, on a corpse that reaches sleep in under two seconds:

- B gives a limb *independent* twist. On a corpse there is nothing to twist it, so this is a
  difference you can measure and not one you can see.
- B gives exact per-body inertia — a body spun by an explosion would carry angular momentum
  through the shoulder more convincingly. This *is* visible, but only on high-energy deaths, and
  our seed velocities are a coarse origin-difference anyway (§9).
- B gives capsule contacts — a forearm resting across a crate edge instead of a wrist sphere
  hovering. Visible on close inspection of settled bodies. This is B's one genuine, everyday win,
  and it is also the thing that blows the trace budget.

### RECOMMENDATION: **Option A**, staged.

Reasoning, in terms of what the user sees:

- Everything they complained about is fixed by A. The list above is not a subset — items 1-3 are
  the entire reported symptom, and A delivers all three.
- B's exclusive wins (independent twist, exact inertia, capsule contacts) are invisible or
  near-invisible on a body that stops moving in 1.5 s, which is what this system produces.
- B forces us to reopen collision. Collision is the subsystem that took the most live rounds to
  get right and whose failure modes (bodies through floors, bodies pinned into piles) are exactly
  the ones the user has already sat through. Trading a visible, certain win for a re-run of that
  is a bad trade.
- A is not a dead end. `RagBuildFrames` produces per-bone `W[i]` every substep — the same state
  B stores as `q`. Migrating later is "stop reconstructing `W`, start integrating `q`", with the
  push, the limit table, the derived axes, the self-collision pairs and the onset logic all
  carried over unchanged. A is a strict prefix of B.

**Landing order — each step is separately visible and separately revertable:**

| step | change | look at it alone? |
|---|---|---|
| A0 | 17 points (feet), anchor-table fix | no (mechanical) |
| **A1** | **§3.4 frame reconstruction + §3.5 push, limits OFF** | **YES — this alone may account for most of the "unnatural" verdict.** Fixes off-by-one, twist, and the frozen shin in one change. |
| A2 | angular limits, `coop_ragdollLimits 1` | YES |
| A3 | self-collision pairs, `coop_ragdollSelfCol 1` | YES |
| A4 | delayed capture + per-point seed (§9) | YES |
| A5 | tuning pass: `RAG_ITERS`, sleep gate back to 6 u/s, damping ramp | no |

A1 must be judged alone. It is the change most likely to be misattributed if bundled: if A1 and
A2 ship together and the result is still wrong, there is no way to tell which one is wrong.

---

## 9. INITIAL CONDITIONS AND LIMP ONSET (task item 6)

### The honest answer

**No.** A joint-limited passive ragdoll released from a standing pose under gravity cannot look
as natural as MOHAA's hand-authored death animations, and no amount of joint tuning will close
the gap. The reason is not the solver — it is that the first 300-500 ms of a real death is
**active**: the knees buckle because muscle tone fails progressively, the trunk pikes, an arm
comes up. A passive skeleton has no mechanism for any of that. Released standing, it falls like
a plank, pivoting about whichever foot is loaded, and every ragdoll ever shipped does this if
released cold.

This is a named, well-studied problem and the literature's answer is unanimous: **do not start
passive.** Zordan & Hodgins (SCA 2002) drive the simulated character with PD servos tracking the
motion-capture pose and release them on impact; Zordan et al. (SIGGRAPH 2005) generalise it to a
blend out of, and back into, animation; Shapiro et al. (PG 2003) formalise it as hybrid
kinematic/dynamic control with explicit transition windows. NaturalMotion's euphoria took the
same premise commercially. Every shipping engine exposes the same knob under a different name
(`PhysicsBlendWeight`, "ragdoll blend-in"), and the values used are in the 150-400 ms band.

### What to do here, cheaply

Two mechanisms, in cost order. **The first is the recommendation.**

**A4 — delayed capture with a two-sample per-point seed.** (~35 lines, no extra pose evaluations,
no new engine surface.)

Instead of arming and capturing at the `EF_DEAD` rising edge, arm at the edge and *capture* at
edge + `D` (cvar `coop_ragdollDelay`, default **300 ms**). During `D` the corpse plays its
authored death animation exactly as it does today — so the buckle, the pike and the stagger are
the animator's, free, and correct. At capture time the skeleton is already *in a collapsing
pose*, so physics starts from a falling body instead of a standing statue, which is the single
biggest determinant of whether the fall reads as natural.

Seed the same way, but per point: sample the sim-bone world positions at `D − 50 ms` and again
at `D`, and difference them.

```
seedVel[i] = (pt_D[i] - pt_(D-50)[i]) / 0.050
ptPrev[i]  = pt[i] - seedVel[i] * subDt
```

This replaces the current uniform origin-difference seed (`CG_RagdollTransition:1163-1180`) with
a per-point velocity field — the arm that was swinging in the anim keeps swinging, the torso
that was already tipping keeps tipping. The `crandom()*0.08` jitter can then go entirely; the
animation supplies the desynchronisation.

Guards: if the two samples are identical (short anim already at its last frame), fall back to
today's origin-difference seed; cap `D` so a corpse never sits un-armed for long; the existing
clear-signal set in `CG_RagdollTransition` must also clear a *pending* capture, not just an
active sim.

**A6 (optional, phase 2) — powered onset.** (~60 lines, +1 skeleton evaluation per awake corpse
per frame.)

Keep tracking the live animation after capture. Each frame while `lifeMs < T_pow` (default
350 ms), pose a scratch `refEntity_t` from `cent->currentState.frameInfo`, read the 17 sim
channels via `TIKI_Orientation`, map to world with the *current* placement, and pull each point
toward its animated target:

```
w  = kPow * (1 - smoothstep(0, T_pow, lifeMs))       // kPow ~ 0.35
pt[i] += w * (target[i] - pt[i])                     // NOTE: do NOT move ptPrev here --
                                                     // letting this change velocity is the point
```

Not absorbing the delta is deliberate and is the opposite of the §5.5 rule: here we *want* the
animation to inject momentum, because that momentum is the hand-off. Ramp the joint-limit
tightening (§5.6) over the same window so the two blends finish together.

Cost and risk: one extra `ForceUpdatePose` per awake corpse per frame (8 max). It stamps
`tr.skel_index[entnum]` — the capture path already flags this (`RagCapture`, plan note C1) — so
do it *before* anything else that poses that entity in the frame, and re-verify live that Hook A
still sees the right skeleton. Gate it behind `coop_ragdollPowered` so it can be turned off in
one command if it misbehaves.

**Expected outcome, stated plainly:** A4 gets us from "mannequin topples" to "the death you
already shipped, which then goes limp and settles physically". That is the realistic ceiling for
this system, and it is a good ceiling — most shipped ragdolls are exactly this. A6 smooths the
seam. Neither will beat a good hand-authored death anim *for the first half second*; both beat
it from the moment the body touches anything, which is what a ragdoll is for.

---

## 10. ACCEPTANCE TESTS (do not skip — the render path has been wrong twice)

| # | test | pass criterion |
|---|---|---|
| T1 | `coop_ragdollTest 2` (freeze) after A1 | pixel-perfect normal soldier, unchanged from today |
| T2 | **new** `coop_ragdollTest 3`: run `RagBuildFrames` + the new push, but hold `pt[]` at their capture values | pixel-perfect normal soldier. This is the invariant `W[i](capture points) == W0[i]`, and it is the one thing that proves the frame chain is not a new mangle. |
| T3 | numeric harness: extend `scratchpad/rag_math_check.py` with the frame chain | `‖W[i] − W0[i]‖∞ < 1e-5` for all 17 bones, at entity yaws 0/45/90/180/270; `‖W[i]ᵀW[i] − I‖∞ < 1e-6` after 500 randomised swing compositions (orthogonality drift) |
| T4 | `r_ragdollDebug 3` at capture | every derived hinge axis prints with `capPhi` inside its widened range; every `faceSign` prints; no limit disabled by the §5.6 failsafe on a normal standing death |
| T5 | `r_ragdollDebug 2` (skeleton dots) with limits on | dots form a recognisable body; span at sleep has one lateral axis 55-75 u and z 8-20 u |
| T6 | yaw sweep: kill four AI facing 0/90/180/270 | identical *world* result for identical world sim state (this is the regression that caught the original 120° frame mismatch) |
| T7 | 20 kills, `r_ragdollDebug 1` | zero NaN/blowup lines, zero `arm refused`, all bodies sleep < 3 s |

---

## 11. PER-JOINT LIMIT TABLE

Frames: `T₀` = pelvis triad, `T₂` = chest triad, rows `[F, L, U]` (forward/left/up, §3.2).
Ranges are **radians in code**, degrees here. Sign: positive = the right-handed rotation about
the listed axis taking `n₁` toward the measured direction. `μ` = reaction fraction applied to
the complement of the moving set.

| # | joint | pivot | measured direction `b` | axis | neutral `n₁` | range | moving set | μ |
|---|---|---|---|---|---|---|---|---|
| J1 | spine1 flex/ext | 1 | `unit(pt2−pt1)` | `T₀[1]` (left) | `+T₀[2]` | **[−20°, +40°]** | subtree(2) | 0.35 |
| J2 | spine1 lateral | 1 | `unit(pt2−pt1)` | `T₀[0]` (fwd) | `+T₀[2]` | **[−25°, +25°]** | subtree(2) | 0.35 |
| J3 | torso twist | 2 | shoulder line vs hip line | `T₂[2]` (up) | `T₀[1]`→plane | **[−35°, +35°]** | subtree(2) | 0.35 |
| J4 | neck flex/ext | 3 | `unit(pt4−pt3)` | `T₂[1]` | `+T₂[2]` | **[−55°, +45°]** | {4} | 0 |
| J5 | neck lateral | 3 | `unit(pt4−pt3)` | `T₂[0]` | `+T₂[2]` | **[−40°, +40°]** | {4} | 0 |
| J6 | L shoulder flex/ext | 5 | `unit(pt6−pt5)` | `T₂[1]` | `−T₂[2]` | **[−60°, +170°]** | subtree(6) | 0 |
| J7 | R shoulder flex/ext | 8 | `unit(pt9−pt8)` | `T₂[1]` | `−T₂[2]` | **[−60°, +170°]** | subtree(9) | 0 |
| J8 | L shoulder abd/add | 5 | `unit(pt6−pt5)` | `T₂[0]` | `−T₂[2]` | **[−20°, +150°]** | subtree(6) | 0 |
| J9 | R shoulder abd/add | 8 | `unit(pt9−pt8)` | `T₂[0]` | `−T₂[2]` | **[−150°, +20°]** | subtree(9) | 0 |
| J10 | L elbow flexion | 6 | hinge, `g=5, c=7` | derived `h` | — | **[+2°, +150°]** | subtree(7) | 0 |
| J11 | R elbow flexion | 9 | hinge, `g=8, c=10` | derived `h` | — | **[+2°, +150°]** | subtree(10) | 0 |
| J12 | L elbow out-of-plane | 6 | `b·h` | `unit(b×h)` | — | **\|ψ\| ≤ 12°** | subtree(7) | 0 |
| J13 | R elbow out-of-plane | 9 | `b·h` | `unit(b×h)` | — | **\|ψ\| ≤ 12°** | subtree(10) | 0 |
| J14 | L hip flex/ext | 11 | `unit(pt12−pt11)` | `T₀[1]` | `−T₀[2]` | **[−25°, +110°]** | subtree(12) | 0 |
| J15 | R hip flex/ext | 13 | `unit(pt14−pt13)` | `T₀[1]` | `−T₀[2]` | **[−25°, +110°]** | subtree(14) | 0 |
| J16 | L hip abd/add | 11 | `unit(pt12−pt11)` | `T₀[0]` | `−T₀[2]` | **[−15°, +55°]** | subtree(12) | 0 |
| J17 | R hip abd/add | 13 | `unit(pt14−pt13)` | `T₀[0]` | `−T₀[2]` | **[−55°, +15°]** | subtree(14) | 0 |
| J18 | L knee flexion | 12 | hinge, `g=11, c=15` | derived `h` | — | **[+2°, +150°]** | {15} | 0 |
| J19 | R knee flexion | 14 | hinge, `g=13, c=16` | derived `h` | — | **[+2°, +150°]** | {16} | 0 |
| J20 | L knee out-of-plane | 12 | `b·h` | `unit(b×h)` | — | **\|ψ\| ≤ 8°** | {15} | 0 |
| J21 | R knee out-of-plane | 14 | `b·h` | `unit(b×h)` | — | **\|ψ\| ≤ 8°** | {16} | 0 |

21 limits. No wrist, ankle or spine2-swing entries: those bones are terminal or inherit, so
their relative rotation is identically zero and there is nothing to limit (§4).

**Option B additionally needs twist limits**, which Option A does not: forearm ±80°, humerus
±45°, shin ±25°, thigh ±40°, neck ±60°, spine ±25°, using Müller's eqs. 22-24.

### Tuning constants

```c
#define RAG_ITERS            6      // 4 is defensible per Macklin 2019; measure both
#define RAG_LIMIT_STIFFNESS  0.98f  // net; per-iteration k' = 1 - powf(1-k, 1/RAG_ITERS)
#define RAG_LIMIT_BAND       DEG2RAD(4.0f)   // smoothstep ramp at the boundary
#define RAG_HINGE_FLOOR      DEG2RAD(2.0f)   // never fully straight (singularity guard)
#define RAG_TIGHTEN_MS       250    // capture-widened -> anatomical
#define RAG_SPINE_MU         0.35f
#define RAG_HINGE_PLANE_SIN  0.208f // sin(12 deg): bent-enough test for the capture axis
// new cvars, all CVAR_TEMP
//   coop_ragdollDelay    300   ms from EF_DEAD edge to capture (0 = today's behaviour)
//   coop_ragdollLimits     1   master gate for the 21 angular limits (live A/B in one command)
//   coop_ragdollSelfCol    1   master gate for the 16 self-collision pairs
//   coop_ragdollPowered    0   phase-2 animation-tracked onset
//   coop_ragdollTest       3   frames-from-points with points frozen (T2)
//   r_ragdollDebug         3   dump derived axes, faceSigns, capture angles, disabled limits
```

---

## 12. TOP-3 RISKS

**RISK 1 — Re-breaking the render path that was just proven correct.**
`RagPush`'s orientation half is rewritten (`rot0`/`restDir`/`conj` all deleted, `relPos` changes
frame). This is the exact code that carried a 120° frame-mismatch bug and a wrong-side
composition bug through multiple sessions, and it is invisible in the freeze drill because
`S = I` hides everything. Compounding it: `tr_ragdoll.cpp` performs **no** re-orthonormalization
— it copies the pushed 3×3 straight into `skelBoneCache_t::matrix` — so drift from repeated
matrix products lands directly on screen as mesh shear.
*Mitigation:* `RagMat3Ortho` on every reconstructed frame, mandatory, not optional (§3.4);
acceptance tests **T2** and **T3** (a freeze mode that runs the *new* frame chain on frozen
points, plus the numeric harness asserting `W[i] == W0[i]` and orthogonality after 500 random
compositions); land A1 alone and look at it before any limit exists.

**RISK 2 — Delayed capture destabilises the arm lifecycle.**
Today the capture is atomic with the `EF_DEAD` rising edge inside `CG_RagdollTransition`. A
300 ms delay introduces a *pending* state that must survive PVS churn, `modelindex`/`eType`
changes, the teleport bit, and the `centity` clientFlags zeroing on PVS re-entry — and the
existing clear-signal set (`:1152-1156`) knows nothing about it. Get this wrong and corpses
either never arm, arm twice, or arm against a stale `centity`. Secondary: on short death anims
the body may already be at its final frame at `D`, giving a zero seed; on long ones the server
may have moved the corpse far from where the player saw it die.
*Mitigation:* the pending record lives in the same `ragSim_t` slot with `state = -1`, so every
existing clear path already frees it; add the pending case explicitly to the clear-signal branch;
zero-seed fallback when the two samples match; `coop_ragdollDelay 0` restores today's behaviour
in one command for a live A/B.

**RISK 3 — A derived joint axis is wrong on some model or pose, and a knee bends backwards.**
The hinge-axis derivation has two branches (limb bent → cross product; limb straight → parent's
most-perpendicular local axis) and a sign fix from the anatomical invariant. A sign flip on a
knee is not subtle — it produces a corpse with a reversed leg, which is *worse* than today's
tangle and will read as a total regression. The straight-limb branch is the fragile one, and
straight limbs are common in death poses.
*Mitigation:* the sign is fixed by the pose-independent invariant ("flexion reduces
|child − grandparent|"), not by an axis guess; `r_ragdollDebug 3` prints every derived axis,
`faceSign` and `capPhi` at capture; the §5.6 failsafe **disables** any limit whose capture angle
is more than 30° outside its widened range rather than snapping to it; ranges are widened to the
capture value at t=0 and tightened over 250 ms, so even a marginal derivation cannot pop; and
`coop_ragdollLimits 0` turns all 21 off in one command.

---

## 13. REFERENCES

- Jakobsen, T. *Advanced Character Physics*. GDC 2001.
  <https://www.cs.cmu.edu/afs/cs/academic/class/15462-s13/www/lec_slides/Jakobsen.pdf>
- Müller, M., Heidelberger, B., Hennix, M., Ratcliff, J. *Position Based Dynamics*. VRIPhys
  2006 / J. Vis. Commun. Image R. 18(2), 2007.
  <https://matthias-research.github.io/pages/publications/posBasedDyn.pdf>
- Müller, M., Macklin, M., Chentanez, N., Jeschke, S., Kim, T.-Y. *Detailed Rigid Body
  Simulation with Extended Position Based Dynamics*. Computer Graphics Forum 39(8), 2020.
  <https://matthias-research.github.io/pages/publications/PBDBodies.pdf> — Algorithm 3 and
  eqs. 18-25 are the source of §5.1-§5.4.
- Macklin, M., Müller, M., Chentanez, N. *XPBD: Position-Based Simulation of Compliant
  Constrained Dynamics*. MIG 2016. <https://matthias-research.github.io/pages/publications/XPBD.pdf>
- Macklin, M., Storey, K., Lu, M., Terdiman, P., Chentanez, N., Jeschke, S., Müller, M.
  *Small Steps in Physics Simulation*. SCA 2019. <https://mmacklin.com/smallsteps.pdf>
- Zordan, V., Hodgins, J. *Motion capture-driven simulations that hit and react*. SCA 2002.
- Zordan, V., Majkowska, A., Chiu, B., Fast, M. *Dynamic response for motion capture animation*.
  ACM TOG (SIGGRAPH) 24(3), 2005.
- Shapiro, A., Pighin, F., Faloutsos, P. *Hybrid control for interactive character animation*.
  Pacific Graphics 2003.
- Holden, D. *Joint Limits*. <https://theorangeduck.com/page/joint-limits> — swing-twist
  decomposition and the box-vs-ellipsoid-vs-k-DOP trade.

### In-repo context

- `openmohaa-hzm/code/cgame/cg_ragdoll.c` — the system under design
- `openmohaa-hzm/code/renderergl1/tr_ragdoll.cpp` (byte-identical to the gl2 copy) — Hook A/B;
  **no re-orthonormalization**; `skelBoneCache_t` keeps translation in `offset[4]`, not
  `matrix[*][3]`
- `openmohaa-hzm/code/qcommon/q_math.c` — `AnglesToAxis` :769 (row-vector FLU),
  `MatrixTransformVector` :2189 (= `RagMat3RotateVec`), `VectorRotate` :863
  (= `RagMat3TransRotateVec`), `MatToQuat` :1823 / `QuatToMat` :1783 (xyzw), `Q_acos`
- `openmohaa-hzm/code/qcommon/cm_trace_lbd.cpp:31-51` — the 19-name hitloc table that proves
  `Bip01 L/R Foot` resolve on every human model
- `_research/ragdoll_pile_findings.md` — the render-math audit this document succeeds
- `_research/ragdoll_plan.md`, `ragdoll_vet1_facts.md` — bone roster verification, space contract
- `.wolf/buglog.json` bug-1962 / 1963 / 1964 — the mechanical fixes already landed
- `scratchpad/rag_math_check.py` — numeric harness; extend it per T3 before building
