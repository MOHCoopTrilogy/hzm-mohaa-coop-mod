# RAGDOLL R13 — THE BLEND MECHANISM: a physically-driven limb riding a playing animation

**Lens:** how a partial, physics-driven override composes with an animation that keeps running.
**Status:** design, buildable. **Targets:** `renderergl1/tr_ragdoll.cpp` + `renderergl2/tr_ragdoll.cpp`
(identical), `renderergl1/tr_model.cpp` + `renderergl2/tr_model.cpp` (one call site each),
`renderercommon/tr_public.h`, `client/cl_cgame.cpp`, `cgame/cg_public.h`, and a new
`cgame/cg_hitreact.c` beside `cg_ragdoll.c`.
**Baseline read:** `cg_ragdoll.c` @ 2383 lines, `tr_ragdoll.cpp` @ 196 lines, 2026-08-20.

Everything below was read out of the code. Where a number came from the caller's brief rather than
from a file, it is labelled **[reported]** and not used to carry an argument.

---

## 0. THE ONE-PARAGRAPH ANSWER

Do **not** simulate a living soldier's skeleton. Simulate a **displacement field** `d[j]` — the
offset of each bone from where the animation says it should be — and let the animation itself be the
spring's rest state. `d = 0` *is* the animation, exactly, so the actor can never freeze, T-pose, or
slide: at rest the override is the identity transform on the anim pose. The renderer already stashes
that anim pose every frame into `slot->animPose` (`tr_ragdoll.cpp:120-138`) and nothing has ever read
it. Give `R_RagdollApplyToCache` a per-channel weight, blend position by lerp and rotation by
**shortest-arc quaternion nlerp**, and the reaction rides on top of a running, firing, cover-taking
man with a mathematically pop-free hand-off at both ends.

---

## 1. WHAT ALREADY EXISTS, RE-READ

| fact | where |
|---|---|
| Hook A rewrites the bone cache for flagged entities on every fill | `tr_model.cpp:857-859`, worker `tr_ragdoll.cpp:113` |
| `newFrame` (the **vanilla animation pose, current frame**) is alive at Hook A | filled `tr_model.cpp:823`, freed `:863` |
| The vanilla copy into `outbones` is **cull-gated** and can be skipped | `tr_model.cpp:826-847` |
| Hook A stashes `newFrame` into `slot->animPose`, never read by anything | `tr_ragdoll.cpp:120-138` |
| Hook A then overwrites `cache[i]` for **every** `i < min(num_tags, slot->count)` | `tr_ragdoll.cpp:139-171` |
| `num_tags = TIKI_GetNumChannels(tiki)` | `tr_model.cpp:763` |
| Slot pool: 16 slots × 128 channels, `byte s_ragSlotPlusOne[MAX_GENTITIES]` | `tr_ragdoll.cpp:19-34` |
| Hook B serves tag orientations from the override so attachments ride | `tr_model.cpp:1819`, `tr_ragdoll.cpp:176` |
| Bridge chain is **three binaries**: renderer → `re` → exe → `cgi` | `tr_init.c:2113`, `tr_public.h:189`, `cl_cgame.cpp:837`, `cg_public.h:453` |
| `CG_RagdollFrame` runs **before** entities are added | `cg_view.c:2928` |
| `R_AddSkelSurfaces` runs in the **render pass**, after cgame is done | `tr_main.c:1466` |
| The mod's authored flinch: `coop_hitReact`, `setmotionanim`, blendtime 0.15 | `coop_mod/aihandler.scr:1848-1893` |
| …fires on only **55%** of hits (`coop_aiHitReact`) | `aihandler.scr:1850-1852`, `coop_defaults.cfg:364` |
| …and is throttled to **one per 1.2 s per man** | `aihandler.scr:1861-1862` |
| The flesh-hit message is emitted for **any sentient**, living or dead | `weaputils.cpp:2606` (`trace.location >= 0 && ent->IsSubclassOfSentient()`) |
| …carrying the true wound→muzzle normal since the R12 fix | `weaputils.cpp:2638-2644` |
| Client consumers: `CGM_BULLET_8/9` and the legacy `CGM6_BULLET_7/8` | `cg_parsemsg.cpp:1808/1820`, `:2232/2244` |

### 1.1 The gap this fills — stated numerically

The authored layer fires on 55% of hits, at most once per 1.2 s, per man. A 5-round Kar98 burst into
one soldier over 3 s therefore produces at most **3** authored flinches and statistically about
**1.6**. The other 3.4 rounds produce nothing but blood. The procedural layer fires on **100%** of
hits with no throttle, lasts ~400 ms, and moves only the struck limb — so it composes with the
authored flinch instead of competing for the same slot. `setmotionanim` writes the *motion* anim; the
procedural layer writes the *render pose* downstream of every anim slot, so it cannot collide with it
by construction.

---

## 2. THE RENDERER SIDE

### 2.1 The change to `R_RagdollApplyToCache`

Add one array to the slot and one branch to the worker.

```c
/* tr_ragdoll.cpp — ragdollSlot_t additions */
    float    weight[RAGDOLL_MAX_CHANNELS]; /* 0 = animation, 1 = sim. Absent => all 1 (corpse). */
    qboolean hasWeights;
    int      animPoseFrame;                /* tr.frameCount at the last stash (staleness gate) */
```

```c
/* tr_ragdoll.cpp — R_RagdollApplyToCache, replacing the two unconditional loops at :139-171 */
{
    float ils = (slot->tiki && slot->tiki->load_scale > 0.0001f) ? 1.0f / slot->tiki->load_scale : 1.0f;
    vec3_t lo = {0,0,0};
    if (slot->tiki) { VectorCopy(slot->tiki->load_origin, lo); }

    for (i = 0; i < n; i++) {
        float w = slot->hasWeights ? slot->weight[i] : 1.0f;
        float simOfs[3], simRot[3][3];
        int   r, c;

        /* --- ENDPOINT 1: pure animation. Bit-exact, and it must COPY, not skip:
               the vanilla loop at tr_model.cpp:826 is cull-gated and may not have run,
               in which case cache[i] holds stale pool garbage from another entity. --- */
        if (w <= RAG_W_EPS) {
            if (newFrame) {
                cache[i].offset[0] = newFrame->bones[i][3][0];
                cache[i].offset[1] = newFrame->bones[i][3][1];
                cache[i].offset[2] = newFrame->bones[i][3][2];
                for (r = 0; r < 3; r++) {
                    cache[i].matrix[r][0] = newFrame->bones[i][r][0];
                    cache[i].matrix[r][1] = newFrame->bones[i][r][1];
                    cache[i].matrix[r][2] = newFrame->bones[i][r][2];
                    cache[i].matrix[r][3] = 0;
                }
            }
            continue;
        }

        /* SPACE CONVERSION, unchanged from :146-157 and still load-bearing (bug-1963 defect 2):
           the table is TIKI-orientation space, the cache is RAW skeletor space. */
        simOfs[0] = slot->mat[i][0][3] * ils - lo[0];
        simOfs[1] = slot->mat[i][1][3] * ils - lo[1];
        simOfs[2] = slot->mat[i][2][3] * ils - lo[2];
        for (r = 0; r < 3; r++) {
            simRot[r][0] = slot->mat[i][r][0];
            simRot[r][1] = slot->mat[i][r][1];
            simRot[r][2] = slot->mat[i][r][2];
        }

        /* --- ENDPOINT 2: pure sim. Byte-identical to today's shipped path. --- */
        if (w >= 1.0f - RAG_W_EPS || !newFrame) {
            VectorCopy(simOfs, cache[i].offset);
            for (r = 0; r < 3; r++) {
                cache[i].matrix[r][0] = simRot[r][0];
                cache[i].matrix[r][1] = simRot[r][1];
                cache[i].matrix[r][2] = simRot[r][2];
                cache[i].matrix[r][3] = 0;
            }
            continue;
        }

        /* --- THE BLEND. Both operands are the CURRENT frame: newFrame is this frame's
               animation, slot->mat is this frame's push. No staleness enters here. --- */
        cache[i].offset[0] = newFrame->bones[i][3][0] + w * (simOfs[0] - newFrame->bones[i][3][0]);
        cache[i].offset[1] = newFrame->bones[i][3][1] + w * (simOfs[1] - newFrame->bones[i][3][1]);
        cache[i].offset[2] = newFrame->bones[i][3][2] + w * (simOfs[2] - newFrame->bones[i][3][2]);
        {
            float animRot[3][3], out[3][3];
            for (r = 0; r < 3; r++) {
                animRot[r][0] = newFrame->bones[i][r][0];
                animRot[r][1] = newFrame->bones[i][r][1];
                animRot[r][2] = newFrame->bones[i][r][2];
            }
            R_RagNlerpMat3(animRot, simRot, w, out);   /* §2.3 */
            for (r = 0; r < 3; r++) {
                cache[i].matrix[r][0] = out[r][0];
                cache[i].matrix[r][1] = out[r][1];
                cache[i].matrix[r][2] = out[r][2];
                cache[i].matrix[r][3] = 0;
            }
        }
    }
}
```

`RAG_W_EPS = 1.0f/512.0f`. The two early-outs are not an optimisation, they are the **contract**:
`w == 0` renders bit-exactly the vanilla frame, `w == 1` executes the instruction sequence that ships
today. A corpse slot has `hasWeights == qfalse`, so every corpse takes the `w >= 1-eps` branch and
the R12 corpse behaviour is unchanged to the last bit. **That is the rollback.**

### 2.2 The bridge addition — a new import, not a changed one

Do **not** widen `RE_SetRagdollPose`. Its signature crosses three separately-shipped binaries
(`renderer_opengl1.dll` → `openmohaa.exe` → `cgame.dll`); a widened prototype with one stale binary
reads a garbage pointer. Append instead:

```c
/* renderercommon/tr_public.h, after :190 */
    void (*SetRagdollWeights)(int entityNumber, dtiki_t *tiki, int count, const float *w);
/* renderergl1|2/tr_init.c, beside :2113 */
    re.SetRagdollWeights = RE_SetRagdollWeights;
/* client/cl_cgame.cpp, beside :838 */
    cgi->R_SetRagdollWeights = re.SetRagdollWeights;
/* cgame/cg_public.h, after :454 */
    void (*R_SetRagdollWeights)(int entityNumber, dtiki_t *tiki, int count, const float *w);
```

`RE_SetRagdollWeights` finds the row exactly as `RE_SetRagdollPose` does (`tr_ragdoll.cpp:63-78`),
copies `count` floats, and sets `hasWeights`. It **never allocates**: a weights call with no matching
row is a silent no-op, so ordering is push-then-weights and a lost push cannot leave weights on a
stale row.

cgame guards with the established pattern — `if (!cgi.R_SetRagdollWeights) { return; }` — exactly as
`cg_ragdoll.c:1449` and `:1713` guard `R_SetRagdollPose` and `:396` guards `R_ClearRagdoll`. An older
exe therefore yields **no living reactions and unchanged corpses**, which is the correct degradation.

Also required: `RAGDOLL_MAX_SLOTS 16 → 32` (`tr_ragdoll.cpp:19`). Budget is in §7.

### 2.3 THE ROTATION BLEND — the choice and why

**Chosen: shortest-arc quaternion nlerp (normalised lerp), row-vector convention, no re-orthonormalisation.**

```c
/* Row-vector convention throughout: v' = v * R, i.e. R is the transpose of the textbook
   column form. This matches RagMat3RotateVec (cg_ragdoll.c:466-471) and the axis rows the
   bone cache carries. Getting the convention wrong here MIRRORS the rotation and is silent. */
static void R_RagMat3ToQuat(const float R[3][3], float q[4])   /* q = {w,x,y,z} */
{
    float tr = R[0][0] + R[1][1] + R[2][2], s;
    if (tr > 0.0f) {
        s = sqrt(tr + 1.0f) * 2.0f;                 /* s = 4w */
        q[0] = 0.25f * s;
        q[1] = (R[1][2] - R[2][1]) / s;
        q[2] = (R[2][0] - R[0][2]) / s;
        q[3] = (R[0][1] - R[1][0]) / s;
    } else if (R[0][0] > R[1][1] && R[0][0] > R[2][2]) {
        s = sqrt(1.0f + R[0][0] - R[1][1] - R[2][2]) * 2.0f;   /* s = 4x */
        q[0] = (R[1][2] - R[2][1]) / s;  q[1] = 0.25f * s;
        q[2] = (R[0][1] + R[1][0]) / s;  q[3] = (R[0][2] + R[2][0]) / s;
    } else if (R[1][1] > R[2][2]) {
        s = sqrt(1.0f + R[1][1] - R[0][0] - R[2][2]) * 2.0f;   /* s = 4y */
        q[0] = (R[2][0] - R[0][2]) / s;  q[1] = (R[0][1] + R[1][0]) / s;
        q[2] = 0.25f * s;                q[3] = (R[1][2] + R[2][1]) / s;
    } else {
        s = sqrt(1.0f + R[2][2] - R[0][0] - R[1][1]) * 2.0f;   /* s = 4z */
        q[0] = (R[0][1] - R[1][0]) / s;  q[1] = (R[0][2] + R[2][0]) / s;
        q[2] = (R[1][2] + R[2][1]) / s;  q[3] = 0.25f * s;
    }
}

static void R_RagQuatToMat3(const float q[4], float R[3][3])
{
    float w=q[0], x=q[1], y=q[2], z=q[3];
    R[0][0]=1-2*(y*y+z*z); R[0][1]=2*(x*y+w*z);   R[0][2]=2*(x*z-w*y);
    R[1][0]=2*(x*y-w*z);   R[1][1]=1-2*(x*x+z*z); R[1][2]=2*(y*z+w*x);
    R[2][0]=2*(x*z+w*y);   R[2][1]=2*(y*z-w*x);   R[2][2]=1-2*(x*x+y*y);
}

void R_RagNlerpMat3(const float A[3][3], const float B[3][3], float w, float out[3][3])
{
    float qa[4], qb[4], q[4], d, inv;
    int   k;
    R_RagMat3ToQuat(A, qa);
    R_RagMat3ToQuat(B, qb);
    d = qa[0]*qb[0] + qa[1]*qb[1] + qa[2]*qb[2] + qa[3]*qb[3];
    if (d < 0.0f) { for (k=0;k<4;k++) qb[k] = -qb[k]; }   /* SHORTEST ARC. Without this a
                                                            >180deg pair blends the long way. */
    for (k = 0; k < 4; k++) { q[k] = qa[k] + w * (qb[k] - qa[k]); }
    inv = q[0]*q[0]+q[1]*q[1]+q[2]*q[2]+q[3]*q[3];
    if (inv < 1e-12f) { R_RagQuatToMat3(qa, out); return; }   /* cannot occur after the sign
                                                                 flip; belt for a denormal input */
    inv = 1.0f / sqrt(inv);
    for (k = 0; k < 4; k++) { q[k] *= inv; }
    R_RagQuatToMat3(q, out);
}
```

**Why not element-wise matrix lerp.** `M = (1-w)A + wB` is not a rotation. With `θ` the angle between
`A` and `B`, `M`'s singular values in the plane of rotation are
`sqrt(1 - 2w(1-w)(1-cos θ))`, which at `w = 0.5` is exactly `cos(θ/2)`:

| θ | shrink at w=0.5 |
|---:|---:|
| 20° | 1.5 % |
| 30° | **3.4 %** |
| 60° | 13.4 % |
| 90° | 29.3 % |

That is a direct, non-uniform scale on the skinned limb — a squash, not a rotation. Fixing it needs
a Gram-Schmidt (2 `sqrt`), which costs the same as the whole quaternion path. Note the shipped code
already does exactly this lerp-then-Gram-Schmidt at `cg_ragdoll.c:926-933`, and it is safe there
*only* because `a = rag_slew 0.12` and the target is a near-identical matrix. That is not our case.

**Why not slerp.** nlerp and slerp trace the *same* great-circle arc; they differ only in rate, and
they agree exactly at `w ∈ {0, 0.5, 1}`. The full-angle deviation, from
`ψ(w) = atan2(w sin(θ/2), (1-w) + w cos(θ/2))` versus `wθ/2`, worst case over `w`:

| θ between anim and sim | max nlerp-vs-slerp full-angle deviation |
|---:|---:|
| 20° | 0.01° |
| 30° | 0.03° |
| 60° | 0.26° |
| 120° | 2.19° |

§4.4 caps the living swing at ~29°. The error is **0.03°** — three orders of magnitude below a pixel
at any viewing distance. slerp buys an `acos` and two `sin` per channel for nothing.

**Why not axis-angle about the joint.** Attractive in principle (it blends the *articulation* rather
than the absolute orientation), but: it needs `Rrel = A^T·B` (a 27-flop mat-mul) plus an axis-angle
extraction that carries a genuine 180° axis ambiguity — the exact degeneracy `RagMat3FromTo` needed a
special case for at `cg_ragdoll.c:490-518`, and which has already been a shipped defect once. And
once the extraction is done in quaternion form to avoid transcendentals, it *is* the quaternion path.
Rejected as "same answer, more code, one more degeneracy."

**nlerp has no degeneracy.** After the shortest-arc sign flip `d >= 0`, so the half-angle is `<= 90°`
and `|qa + w(qb-qa)| >= sqrt(2)/2` for every `w`. The norm can never approach zero. Contrast the
axis-angle route, which is ill-conditioned exactly where nlerp is best-behaved.

**Does the missing re-orthonormalisation matter?** No — and the choice is what keeps it that way.
Today nothing drifts because nothing is *integrated*: `RagPush` rebuilds `mat[]` from scratch every
frame (`cg_ragdoll.c:1333-1393`) as a product of matrices that are orthonormal by construction
(`rot0` from `TIKI_Orientation`, `S` from `RagMat3FromTo`/`RagTriad`). Round-off is ~1e-7 and
non-accumulating. nlerp's output is a matrix built from a **normalised** quaternion, so it is
orthonormal to the same ~1e-7, also non-accumulating. The one thing that would break this is feeding
the blended cache back into the next frame's sim — so:

> **INVARIANT B1.** cgame reads the animation only through `slot->animPose`, which Hook A writes
> from `newFrame` *before* any override touches `cache` (`tr_ragdoll.cpp:120-138` precedes `:139`).
> cgame must never read `cache`, and no blended value may ever re-enter `slot->mat`. Violating this
> turns a stable blend into a positive feedback loop within ~30 frames.

### 2.4 Hook B must blend too — and this closes a re-entrancy trap

`R_RagdollGetOrientation` (`tr_ragdoll.cpp:176`) currently returns the raw override for any
entity with a row. Two consequences once living actors carry rows:

1. **Attachments would over-react.** `tag_weapon_right` anchors to the right hand (§3), so a rifle
   would snap to the full-amplitude sim pose while the hand it is attached to renders at `w = 0.3`.
2. **`RagCapture` would photograph the override.** `RagCapture` reads the pose through
   `cgi.TIKI_Orientation` (`cg_ragdoll.c:610`) → `RE_TIKI_Orientation` (`tr_model.cpp:1813`) →
   Hook B. If the man dies mid-reaction, the corpse capture would read back *our own flinch pose*
   instead of the animator's death pose — silently poisoning the corpse ragdoll that R12 spent ten
   rounds getting right.

Both are fixed by one rule plus one belt:

```c
/* tr_ragdoll.cpp — R_RagdollGetOrientation, replacing the body after the bounds check */
    w = slot->hasWeights ? slot->weight[tagnum] : 1.0f;
    if (w <= RAG_W_EPS) {
        return qfalse;          /* fall through to R_UpdatePoseInternal + TIKI_OrientationInternal:
                                   the EXACT, non-stale vanilla answer. */
    }
    if (w >= 1.0f - RAG_W_EPS || !slot->animPoseValid) {
        ...today's verbatim copy...
        return qtrue;
    }
    /* blend against the stashed anim pose. NOTE: animPose is ONE FRAME STALE here (§2.5) and
       lives in RAW skeletor space, so it must be converted UP into TIKI-orientation space
       ( (raw + load_origin) * load_scale ) before it can be lerped with slot->mat. */
```

**Belt:** `RagCapture` calls `cgi.R_ClearRagdoll(ns->number)` as its first statement, before the
`TIKI_Orientation` loop at `cg_ragdoll.c:609`. The entity is about to be re-captured and re-pushed in
the same cgame frame (`RagArm` at `:2075`, `RagPendingThink` at `:2194`), both of which run before the
render pass, so there is no frame in which the entity loses its override. This makes the corpse
capture provably independent of anything the living layer did, rather than merely probably so.

### 2.5 Which operand is stale, and why it does not matter

Frame order, read out of the code:

| # | step | where | reads |
|---|---|---|---|
| 1 | `CG_RagdollFrame` — sims step, poses pushed | `cg_view.c:2928` | `slot->animPose` from **frame N-1** |
| 2 | `CG_AddPacketEntities` — attachments resolve tags | Hook B, `tr_model.cpp:1819` | `slot->animPose` from **frame N-1** |
| 3 | render pass — `R_AddSkelSurfaces` per entity per view | `tr_main.c:1466` → `tr_model.cpp:823,857` | `newFrame` = **frame N** |

So the **blend that reaches the screen (step 3) uses the current frame's animation on both sides**.
`w = 0` is therefore bit-exact against what the vanilla path would have drawn *this* frame, not last
frame. Staleness is confined to (a) cgame's spring target and (b) Hook B's attachment blend, and in
both cases it is one 16 ms frame of animation motion on a value that is already an offset.

Two footnotes. `R_AddSkelSurfaces` runs **once per entity per view** (`tiki_mesh.h:31-33`), so with a
portal or mirror the stash fires 2-3× per frame with identical `newFrame` content — harmless, one
producer, same data. And `animPoseFrame` must be stamped with `tr.frameCount` on every stash so cgame
can detect an entity that stopped being rendered (§6.2).

---

## 3. WHICH CHANNELS — the rule

### 3.1 The rule, stated

The existing tables already carry everything needed. Nothing is hand-written.

1. **Find the struck bone.** Run the *same* bone-segment search the corpse impulse uses
   (`cg_ragdoll.c:1515-1537`) against the **animated** point set, not a captured one. It returns
   `bestJ` (the distal sim point, always the child) and `bestP = s_ragBones[bestJ].parent`
   (`cg_ragdoll.c:74-93`). Reject if `bestD >= radius`, as `:1538` does.

2. **Assign an inverse mass per sim point**, walking the parent chain from `bestJ` — *not* a render
   weight (see §3.3 for why this distinction is load-bearing):

   | point set | derivation | `invMass` |
   |---|---|---|
   | the subtree of `bestJ`, inclusive | the depth-6 parent walk already at `cg_ragdoll.c:1600-1610` | **1.00** |
   | `bestP` (the pivot) | `s_ragBones[bestJ].parent` | **0.25** |
   | `s_ragBones[bestP].parent` | one more hop | **0.08** |
   | everything else | — | **0** (pinned = exactly the animation) |

3. **Two hard clamps**, and they are the whole reason the man cannot slide:
   - `invMass[0] = 0` **always**. The pelvis is the anchor of the entire `Bip01 Spine*` branch of
     `s_ragAnchorTable` (`cg_ragdoll.c:294`); moving it moves the whole soldier.
   - **The up-chain walk stops at the last limb-exclusive point.** For an arm that is the UpperArm
     (5 / 8); for a leg the Thigh (11 / 13); for the head/neck chain it is Spine2 (2). Concretely:
     `if (candidate <= 4 && bestJ >= 5) invMass = 0`. Without this, a hit on the right forearm would
     put mass on Spine2 — whose anchored channels include the **left** clavicle — and the man would
     visibly shrug the wrong shoulder.

4. **Per-channel weight is the anchor's participation**, using the table that already exists:
   `w[ch] = env(t) * (invMass[s->anchor[ch]] > 0 ? 1 : 0)`.
   `s->anchor[ch]` is built by `RagCapture` at `cg_ragdoll.c:797-849` — self, then the fixed
   `s_ragAnchorTable` hierarchy (`:271-296`), then nearest for gear.

### 3.2 What the rule actually selects — measured against a real skeleton

Bone lists parsed from the shipped SKDs (`docs/tools/ragdoll_channel_census.py` machinery, with the
**variable** `ofsEnd` stride from `count_skel_channels.py:126-129` — the census tool's fixed 84-byte
stride mis-parses and yields garbage names; that is a separate defect worth logging).
Largest human tiki on the roster: `models/human/1st-ranger_sergeant.tik`, **87 bones**.

A hit on **`Bip01 R Forearm`** (`bestJ = 9`) selects:

| channel | anchor | via | `invMass` |
|---|---:|---|---:|
| `Bip01 R Forearm` | 9 | self (`:808-813`) | 1.00 |
| `Bip01 R Hand` | 10 | self | 1.00 |
| `Bip01 R Finger0…Finger42` (**15 channels**) | 10 | table `"Bip01 R Finger"` (`:276`) | 1.00 |
| `tag_weapon_right` | 10 | table `"tag_weapon"` prefix (`:286`) | 1.00 |
| `helper Relbow` | 9 | nearest fallback (`:828-841`) | 1.00 |
| `Bip01 R UpperArm` | 8 | self | 0.25 |
| `helper Rshoulder` | 8 | nearest | 0.25 |
| `Bip01 R Clavicle` | 2 | table (`:284`) → **clamped by rule 3** | 0 |
| everything else (66 channels) | — | — | 0 |

**21 of 87 channels move.** The forearm, the hand, all fifteen finger bones, the elbow helper, and —
because `tag_weapon_right` anchors to the hand — **the rifle**, which rides via Hook B. That is
precisely the behaviour asked for, and it required no new table.

A hit on **`Bip01 Head`** (`bestJ = 4`, a leaf) selects: `Bip01 Head` + `tag_eyes` + `tag_head` +
`helmet bone` + `eyes bone` + `JAW` (table `:287-292`) at 1.00; `Bip01 Neck` at 0.25; `Bip01 Spine2`
at 0.08 — but Spine2's *channels* include both clavicles, so rule 3's clamp applies and Spine2 gets 0
unless the hit itself was on the spine chain. Net: **the head snaps, the neck gives slightly, the
shoulders do not move.**

### 3.3 Why the falloff is `invMass` and not an output scale — the artifact this avoids

The obvious design is "gain 1.0 on the subtree, 0.35 on the pivot" applied as a *post-hoc scale on
the displacement*. That is wrong, and the arithmetic says how wrong.

The bone cache is **absolute per channel**. If the wrist renders at `anim + 1.00·d` and the elbow at
`anim + 0.35·d`, the rendered forearm vector is `(anim_w − anim_e) + 0.65·d`, whose length is not
`L`. For `d = 6 u` on a 14 u forearm that is up to **43 % length error** — a rubber arm.

Making it an inverse mass instead puts the falloff *inside the solver*, where the distance
constraints (`cg_ragdoll.c:1009-1022`, with the 0.5/0.5 split generalised to
`invM_i/(invM_i+invM_p)`) enforce bone length exactly. A pinned point (`invMass 0`) simply does not
move; a 0.25 point moves a quarter as far *and the link between them still measures L*. The physics
and the anatomy agree: a shoulder resists a bullet more than a wrist does because there is 70 kg
behind it.

The only residual length error is then the **temporal blend** itself, and it is small — see §4.5.

---

## 4. THE TIME ENVELOPE, AND WHAT DRIVES THE LIMB

### 4.1 The state variable: displacement, not position

```
    d[j]      = model-space offset of sim point j from where the animation puts it
    dPrev[j]  = Verlet history of the same
    rendered position of point j = animPos[j] + d[j]
```

`d = 0` is the animation. This one choice answers most of the brief:

- *"the sim's start pose and the animation's current pose diverge"* — they cannot. The sim's rest
  state **is** the animation, re-read every frame.
- *"how does it return without a snap"* — the spring drives `d → 0`, and `d = 0` is the animation.
  The return is the spring, not a scripted retreat.
- *"what if the actor is running"* — the run cycle lives entirely in `animPos`; `d` never sees it.
  A soldier can sprint 400 u/s and the reaction is a bounded wobble superimposed on his arm swing.
- *"what if a scripted animation starts"* — a new anim changes `animPos`, and `d` rides on top of it
  unchanged. The mod's own `setmotionanim` flinch (`aihandler.scr:1891`) with its 0.15 blendtime is
  therefore composed with, not fought. A hard cut with blendtime 0 teleports `animPos`; `d` is
  unchanged and the flinch simply continues on the new pose. Correct in both cases, by construction.
- No leash, no `RagSane` span gate, no world collision, no pelvis anchor. All of
  `cg_ragdoll.c:1055-1078`, `:1258-1297`, `:1163-1257` are unnecessary here — they exist to stop an
  *absolute-space* body wandering, and this body has no absolute space.

**Space.** `d` lives in the **model frame**, the same space `slot->mat` uses (TIKI-orientation,
unscaled). The impulse position and direction are converted once, at seed, by the rotation half of
`RagWorldToCapture` (`cg_ragdoll.c:551-559`) against the **current** `lerpOrigin`/`lerpAngles`.
Consequence: the `Ecap · S · Enow^T` conjugation (`cg_ragdoll.c:1362`) — origin of bug-1963 defect 1
and bug-1964 — **does not exist on this path at all**, because there is no capture frame to differ
from the render frame. The rotation is built in model space and applied in model space:
`mat[ch] = animRot[ch] · S[anchor]`.

> **INVARIANT B2.** Never mix the two. The corpse path builds `S` in **world** space and needs the
> conjugation; the living path builds `S` in **model** space and must not have it. Copying a line
> between them is the shape of bug-1963.

Physical approximation, stated plainly: a model-space displacement **rotates with the actor**. A man
turning at 300 °/s for 300 ms carries the flinch through 90°. The error is largest at the tail, where
the amplitude is already under 20 % of peak. Accepted; the alternative (world-space `d` + the
conjugation) reintroduces the invariant that has broken four times.

### 4.2 The solver

```c
/* per RAG_SUBSTEP_MS (8 ms, cg_ragdoll.c:59). Same cadence and accumulator as CG_RagdollFrame
   (:1803-1829): accumMs += min(frametime,200), step while >= 8 && steps < 4, discard the rest. */
for (j = 0; j < RAG_PTS; j++) {
    vec3_t v;
    if (f->invMass[j] <= 0) { VectorClear(f->d[j]); VectorClear(f->dPrev[j]); continue; }
    VectorSubtract(f->d[j], f->dPrev[j], v);
    VectorScale(v, hr_damp->value, v);                    /* 0.812 */
    VectorCopy(f->d[j], f->dPrev[j]);
    VectorAdd(f->d[j], v, f->d[j]);
    VectorMA(f->d[j], -hr_k->value, f->d[j], f->d[j]);    /* spring to d = 0, k = 0.0246 */
    if (hr_grav->value > 0.0f) {                          /* default 0 - see 4.6 */
        f->d[j][2] -= hr_grav->value * RagGravity() * dt * dt;
    }
}
for (it = 0; it < 3; it++) {                              /* 3, not RAG_ITERS 6: <=8 live points */
    for (j = 1; j < RAG_PTS; j++) {
        int p = s_ragBones[j].parent; float wi, wp, sum, len, corr; vec3_t a, b, dv;
        wi = f->invMass[j]; wp = f->invMass[p]; sum = wi + wp;
        if (sum <= 0.0f) { continue; }
        VectorAdd(f->anim[j], f->d[j], a);                /* the RENDERED endpoints */
        VectorAdd(f->anim[p], f->d[p], b);
        VectorSubtract(a, b, dv);
        len = VectorLength(dv);
        if (len < 0.001f) { continue; }
        corr = (len - f->restLen[j]) / (len * sum);       /* restLen re-read from anim each frame */
        VectorMA(f->d[j], -corr * wi, dv, f->d[j]);
        VectorMA(f->d[p],  corr * wp, dv, f->d[p]);
    }
}
```

`restLen[j] = |animPos[j] − animPos[parent]|` is recomputed from `animPos` **every frame**, not
captured. It has to be: MOHAA anims are non-uniformly scaled per model and a captured rest length
would fight the animator on any model whose proportions differ from the capture instant.

### 4.3 The constants, derived

Substep `h = 8 ms`. The Verlet form above is a discrete damped oscillator with
`ω² h² = k` and `2 ζ ω h = 1 − damp`.

Target: rise to peak in ≈ 60 ms, first zero-crossing ≈ 200 ms, visually settled by 300 ms.

```
    ω   = 19.6 rad/s   (f = 3.12 Hz, period 320 ms)
    k   = (ω h)²       = (19.6 × 0.008)²        = 0.0246
    ζ   = 0.6
    damp = 1 − 2ζωh    = 1 − 2(0.6)(19.6)(0.008) = 0.812
    ω_d = ω√(1−ζ²)     = 15.68 rad/s
    t_peak = atan(√(1−ζ²)/ζ)/ω_d = 0.9273/15.68  = 59.1 ms          ✓
    zero crossing at π/ω_d                       = 200 ms           ✓
    amplitude at 300 ms: e^(−ζω·0.3) = e^(−3.53) = 2.9 % of peak    ✓
    peak displacement per unit seed velocity:
        d_p/v0 = (1/ω_d)·e^(−ζω t_peak)·sin(ω_d t_peak)
               = (1/15.68)(0.4990)(0.8000)       = 0.02546 s
```

### 4.4 The amplitude, derived — and the cap

Target swing on the struck bone: **δ ≈ 25°**, which is a soldier flinching, not a corpse flailing.
(The corpse target was 60.5° **[reported]**, instrument `swing=` on the `sleep-rot` line,
`cg_ragdoll.c:1866-1887` / `:2007-2013`.)

Forearm length **14 u** **[reported, `ragdoll_r12_spec.md` §0.2]**. The couple weights are
`w_distal = lin + c = 0.30 + 0.9 = 1.20` and `w_proximal = lin − c = −0.60`
(`cg_ragdoll.c:342`, `:348`, `:1571-1574`). With `invMass` 1.00 / 0.25 the elbow's response is
`(0.60/1.20) × 0.25 = 0.125` of the wrist's, opposite in sign, so the *relative* displacement is
`Δ ≈ 1.125 · d_wrist`.

```
    δ = 25°  ⇒  Δ = 14·sin 25° = 5.92 u  ⇒  d_wrist = 5.26 u  ⇒  v0 = 5.26/0.02546 = 207 u/s
```

What the shipped message already delivers (`cg_parsemsg.cpp:1808`,
`force = 150 + 70·iLarge`, `iLarge ∈ 0..3` via `MSG_ReadBits(2)` at `:1778`;
`k2 = 1 − bestD/radius` at `cg_ragdoll.c:1542`):

| round | force | `k2` | distal seed `v0 = force·k2·1.20` | δ |
|---|---:|---:|---:|---:|
| rifle, off-centre | 220 | 0.70 | 185 u/s | 22.3° |
| rifle, dead centre | 220 | 0.95 | 251 u/s | **clamped** |
| large / .50 | 360 | 1.00 | 432 u/s | **clamped** |

So the corpse impulse is already within ~12 % of the right magnitude for a *living* flinch, because
the living spring (ω = 19.6) is far stiffer than the corpse's free Verlet. `coop_hitreactForce`
therefore defaults to **1.0** — the same impulse the corpse gets — with a hard velocity clamp:

```
    coop_hitreactVMax = 240 u/s  ⇒  d_p = 6.11 u  ⇒  Δ = 6.87 u  ⇒  δ_max = 29.4°
```

The clamp preserves the "bigger round hits harder" ordering up to 240 and then saturates. It is the
same shape as the accumulation ceiling the corpse path already carries at `cg_ragdoll.c:1587`.

### 4.5 The envelope — and the only artifact it introduces

```
        t (ms)   0        16        56                 280          400
                 |  warm  |  ATTACK  |     SUSTAIN     |  RELEASE   |
        env      0    0   0 ───────► 1 ═══════════════ 1 ─────────► 0
```

| phase | length | `env` | why |
|---|---:|---|---|
| **warm** | 1 frame | 0 | the slot may not exist yet, so `animPose` may not be valid. Push identity matrices with all weights 0 — the renderer never reads `mat` at `w = 0`, and the frame renders bit-exact vanilla. See §5.2. |
| **attack** | 40 ms | smoothstep 0→1 | **not** needed for continuity (`d = 0` at seed, so `w = 1` would already be pop-free against `animPos`). It is needed to hide the **one-frame staleness** of cgame's `animPos`: at `w = 1` on the seed frame the struck limb would render last frame's animation, a ~5 u jump on an arm swinging at 300 u/s. Two to three frames of ramp removes it. |
| **sustain** | until 280 ms | 1 | the spring owns the *shape*; the envelope owns only the hand-off |
| **release** | 120 ms | smoothstep 1→0 | `3t²−2t³` so both value **and slope** reach 0. Combined with `|d|` already at 2.9 % of peak, the residual error at hand-off is (small) × (zero, with zero derivative). |
| **cap** | 400 ms limb / 550 ms head / 300 ms torso | | force release |

**Early release:** if `max |d| < 0.15 u` for 2 consecutive frames, jump to release immediately.
A grazing hit should not hold a slot for 400 ms.

**The one artifact.** During attack and release the per-channel blend is absolute, so a bone's two
endpoints lerp independently. With `A` the anim bone vector and `B` the sim bone vector, both of
length `L` (the constraints guarantee `|B| = L`), the rendered length is
`L·sqrt(1 − 2w(1−w)(1−cos δ))`, i.e. `L·cos(δ/2)` at `w = 0.5`:

| δ | worst-case length error, mid-envelope |
|---:|---:|
| 25° (design target) | **2.4 %** |
| 29.4° (`vMax` clamp) | **3.3 %** |
| 36° | 5.0 % ← the gate |
| 60° | 13.4 % ← visible rubber-arm |

It is **zero at `w = 0` and `w = 1`**, so it exists only during 160 ms of a 400 ms reaction and never
during sustain. Note the cross-check: the 36° stretch gate and the 29.4° swing cap are the same
constraint expressed twice, which is why `coop_hitreactVMax` is the single knob that bounds both.

### 4.6 Gravity: off

Constant acceleration in displacement space has a **steady-state offset** `d_ss = g/ω²`, not a decay:

```
    d_ss = 512 / 19.6² = 512 / 384.2 = 1.33 u   →  5.5° of permanent droop on a 14 u forearm
                                                   for as long as the reaction runs
```

That is a systematic bias fighting the animator on every single reaction. `coop_hitreactGrav`
defaults **0**; at 0.25 the sag is 0.33 u, which is the most that could ever be justified (a
"dead weight" feel on a limp arm). This is the cleanest divergence from the corpse sim, where gravity
is the *entire* point (`RagStep`, `cg_ragdoll.c:988`).

---

## 5. THE SEED, AND ENTITY RESOLUTION

### 5.1 Which soldier was hit

The flesh-hit message carries **position and direction only** — no entity number
(`weaputils.cpp:2621-2647` writes 3 coords + 1 dir + `bulletlarge`). Resolution is geometric, exactly
as the corpse path already resolves it, and the position is bone-accurate because it comes off the
deep trace.

```c
/* candidates: living AI actors whose bones could contain this point */
for (e = 0; e < cg.snap->numEntities; e++) {
    es = &cg.snap->entities[e];
    if (es->eType != ET_MODELANIM || (es->eFlags & EF_DEAD) || es->modelindex <= 0) continue;
    if (es->number < cgs.maxclients) continue;   /* never a player slot - cg_ragdoll.c:1468, :2304 */
    VectorSubtract(cg_entities[es->number].lerpOrigin, pos, dd);
    if (VectorLengthSquared(dd) > 96.0f*96.0f) continue;   /* same radius as :1473 */
    ...
}
```

Then, per candidate **that has a valid `animPose`**, run the segment search in model space and keep
the global best `bestD`. A candidate with no slot yet cannot be searched, so it gets a **warm slot**
and a pending-hit record; the search and seed happen on the next frame, one frame late.

Keeping a slot warm (`w = 0`) for **2 s after the last reaction** makes that latency a
first-bullet-only cost: in a firefight the second round onto the same man reacts instantly. This is
the right trade — it costs one 3.5 KB memcpy per frame per warm actor and buys zero-latency on every
round after the first.

Excluding players (`number < cgs.maxclients`) is a deliberate v1 scope call, matching the corpse
path. Enabling it later requires excluding `cg.snap->ps.clientNum` specifically, because the local
player's first-person view model shares the entity.

### 5.2 The seed

```c
/* frame N: hit arrives, no slot -> warm it and defer */
push_identity_matrices(entnum, tiki, count);      /* weights all 0: mat is never read at w=0,
                                                     but identity is pushed rather than zeros so
                                                     no path can ever read a degenerate matrix */
record_pending_hit(entnum, posWorld, dirWorld, force, radius, cg.time);

/* frame N+1: animPose is valid */
if (!cgi.R_RagdollGetAnimPose(entnum, tiki, count, animPose)) { drop(); }
posModel = rotate_world_to_model(posWorld - cent->lerpOrigin) / scale;
dirModel = rotate_world_to_model(dirWorld);
bestJ, bestP = segment_search(animPose, posModel, radius);      /* cg_ragdoll.c:1515-1537 */
if (bestJ < 0) { drop(); }
assign_invMass(bestJ, bestP);                                   /* §3.1 */
memset(d, 0, ...); memset(dPrev, 0, ...);                       /* d = 0: he IS the animation */
v_distal   = min(force * k2 * 1.20f * hr_force->value, hr_vmax->value);
v_proximal = min(force * k2 * 0.60f * hr_force->value, hr_vmax->value) * 0.5f;
VectorMA(dPrev[bestJ], -v_distal   * subDt, dirModel, dPrev[bestJ]);   /* push  */
VectorMA(dPrev[bestP], +v_proximal * subDt, dirModel, dPrev[bestP]);   /* pull  = TORQUE COUPLE */
```

The impulse goes on `dPrev`, never `d` — in Verlet the gap between them *is* the velocity
(`cg_ragdoll.c:1440-1442`, `:1583`). Moving `d` would teleport the limb, which is the exact defect
that once flung corpses across the map.

The couple is kept for the same reason it was added to the corpse path: two positive pushes make a
bone **translate**, and translation is invisible (`cg_ragdoll.c:1546-1557`). Push the distal end and
pull the proximal one and you have pure torque, which is what the eye reads.

`R_RagdollGetAnimPose` is the third and last new bridge entry point:

```c
qboolean RE_RagdollGetAnimPose(int entityNumber, dtiki_t *tiki, int count, float *out34);
```

It returns `qfalse` when there is no row, when `animPoseValid` is false, or when
`tr.frameCount - slot->animPoseFrame > 2` (the entity stopped being rendered). It converts
translations **up** into TIKI-orientation space — `(animPose + load_origin) * load_scale`, the exact
inverse of Hook A's `mat * ils − lo` at `tr_ragdoll.cpp:153-155` — and copies the axis rows verbatim.

> **This conversion must live in the renderer, and the compiler enforces it.** `dtiki_s` is
> **forward-declared only** in cgame's include set (`renderercommon/tr_types.h:93`
> `struct dtiki_s;`; `cg_local.h:31-35` pulls in nothing that completes it), so
> `dtiki_t::load_scale` / `load_origin` (`tiki_shared.h:198,202`) are not merely inconvenient to
> reach from cgame — dereferencing them there is a compile error. Handing cgame raw
> skeletor-space translations while
> `RE_SetRagdollPose` expects TIKI-orientation space would be **two spaces in one module** — the
> precise shape of bug-1963 defect 2, which rendered every human corpse at 52 % of its true bone
> offsets. One space in cgame, both conversions owned by `tr_ragdoll.cpp`.

---

## 6. ABORT PATHS

### 6.1 The actor dies mid-reaction

Order matters. `CG_RagdollTransition` sees the `EF_DEAD` rising edge (`cg_ragdoll.c:2298`) and
records a *pending* corpse arm; the corpse capture then happens up to `RAG_PEND_CAP_MS` = 8 s later,
when the server parks the body (`RagServerParked`, `:2095-2104`). So the two systems overlap by
seconds, not frames.

```
    EF_DEAD rising edge
      → CG_HitReactKill(entnum): force RELEASE with T_REL = 60 ms, set `dying` (no new impulses)
      → env reaches 0  →  free the flinch record  →  cgi.R_ClearRagdoll(entnum)
      → (much later) RagPendingThink → RagAllocSlot → RagCapture
                                        └─ first statement: cgi.R_ClearRagdoll(entnum)   [§2.4 belt]
```

Do **not** clear the renderer row on the death edge — that would drop the weights and pop the limb to
the animation in one frame, exactly when the player is watching. Ride the 60 ms release out; it is
far shorter than the crossblend into the death anim (`ChangeAnim m_fCrossblendTime` 0.5 s, cited at
`cg_ragdoll.c:2082-2084`), so the flinch is gone long before the animator's fall is visible. They
never fight for the same frames.

### 6.2 Leaves PVS / stops being rendered

Two independent detectors, because they fail differently:

- **PVS / snapshot:** `!cent->currentValid` → clear. Same test `RagPendingThink` uses at
  `cg_ragdoll.c:2123`. `centity` `clientFlags` are zeroed on PVS re-entry (file header, `:34`).
- **Not rendered (culled, off-screen, behind the player):** `R_AddSkelSurfaces` never runs, so
  `animPose` silently stops updating and the spring would chase a frozen target. `animPoseFrame`
  catches it: `R_RagdollGetAnimPose` returns `qfalse` after 2 stale frames → clear. This also makes
  an off-screen reaction cost exactly nothing, which is what keeps a 30-man firefight cheap.

### 6.3 Model or weapon change

`modelindex` change, `eType` change, and the teleport bit already clear the row unconditionally at
`cg_ragdoll.c:2247-2251`; hook the flinch pool into the same block. Second line of defence:
`R_RagdollSlotFor` ignores a row whose stored `tiki` no longer matches (`tr_ragdoll.cpp:46`), so a
mismatched model renders vanilla rather than garbage — this is the belt that makes an indexing error
across a different channel count impossible.

A **weapon** change does not change the actor's tiki. The weapon is an attached model resolved
through Hook B, which now blends (§2.4), so a swap mid-reaction just re-resolves against the blended
hand. No guard needed.

### 6.4 A scripted animation starts

**No guard needed, and this is the point of the displacement formulation.** A new anim moves
`animPos`; `d` is unchanged and rides on top. Three sub-cases:

| case | behaviour |
|---|---|
| the mod's own `coop_hitReact` flinch fires (`aihandler.scr:1891`, blendtime 0.15) | the procedural wobble rides the authored flinch. Both visible. Intended. |
| a crossblend (0.15–0.5 s) moves the pose fast | the spring lags the target slightly, which reads as extra weight. Arguably desirable. |
| a hard cut, blendtime 0 | `animPos` teleports; `d` is unchanged; the flinch continues on the new pose. Correct. |

The one thing that *would* break it is a change in channel count or ordering — i.e. a different tiki
— which §6.3 already covers.

Prone, mounted turrets and vehicle seats need no guard either: all three only move `animPos` or the
entity placement, both of which `d` is defined relative to. (Contrast the authored layer, which
*must* skip prone — `aihandler.scr:1859` — because a stand-flinch anim on a prone man is nonsense.)

### 6.5 Hit again mid-reaction

Do **not** restart the envelope — re-ramping through attack stutters the limb. Instead:

1. **Superpose the velocity** onto `dPrev` (physically correct; two impulses add).
2. **Extend** the release deadline to `now + 280 ms`, capped at 900 ms total.
3. If the new `bestJ` is a *different* limb, **union** the member sets and take the **max** `invMass`
   per point (the most-free wins).
4. Re-apply the `vMax` clamp to the **resulting** speed, not to the impulse — one hit lands at full
   strength, ten do not stack. Same reasoning and same shape as `cg_ragdoll.c:1669-1682`.
5. Hard caps: ≤ 8 points with `invMass > 0`, ≤ 900 ms total. A sustained burst must not leave a man
   permanently rubbery.

### 6.6 The failure ladder

`if (max |d| > 24 u)` → zero the reaction, clear the row, and set a **per-entnum 5 s cooldown**.
Deliberately **not** `s_ragNeverArm` (`cg_ragdoll.c:251`): that flag is permanent and shared with the
corpse path, so a transient in the living layer must never be able to retire an entity slot from
corpse ragdolling for the rest of the map. 24 u is chosen as roughly 1.7× the longest bone; no real
reaction can approach it.

---

## 7. BUDGET

**Renderer memory.** `ragdollSlot_t` today ≈ 12.34 KB (`mat` 6144 B + `animPose` 6144 B + header).
Adding `float weight[128]` (512 B) + `int animPoseFrame` → ≈ 12.86 KB.
`RAGDOLL_MAX_SLOTS 16 → 32` ⇒ **411 KB** of renderer BSS, up from 198 KB. `s_ragSlotPlusOne` is a
`byte` holding slot+1, so 32 is well inside its range.

**Slot policy — corpses must never starve.**
`32 = 16 corpse (RAG_MAX_SIMS) + 12 flinch (RAG_MAX_FLINCH) + 4 headroom`.
cgame refuses a new flinch when `activeCorpseSims + activeFlinches >= 28`. If the pool does fill
anyway, `RE_SetRagdollPose` already returns silently (`tr_ragdoll.cpp:75-77`) and the actor renders
vanilla — the correct degradation, unchanged.

**cgame memory.** A flinch record is `d[15] + dPrev[15] + anim[15]` (540 B) + `invMass[15]` +
`restLen[15]` + bookkeeping ≈ **660 B**; × 12 = 7.9 KB. Compare `ragSim_t` at ~9.4 KB *each*: the
living record is 1/14th the size, because it carries no `mat0`, no `relPos`, no `goal`, no collision
state, no rotation filter.

**Per-frame CPU, 12 reacting actors:**

| item | count | cost |
|---|---:|---:|
| solver: 8 live points × 2 substeps × (integrate + spring) + 7 links × 3 iters | 12 bodies | ≈ 5 k flops |
| `RE_SetRagdollPose` memcpy, `count·12·4` = 3456 B | 12 | 41 KB/frame ≈ 10 µs |
| `RE_SetRagdollWeights` memcpy, `count·4` = 288 B | 12 | 3.5 KB/frame |
| Hook A `w = 0` fast path (12-float copy) | 12 × ~66 ch | negligible |
| Hook A quaternion nlerp (~3 `sqrt` + 60 flops ≈ 80 cy) | 12 × ~21 ch = 252, ×3 views worst case = 756 | ≈ 60 k cycles ≈ **20 µs** |

Total well under **0.3 %** of a 16.7 ms frame. The memcpy is the largest single item and is pure
waste for the ~66 channels at `w = 0`; adding a `firstChannel/lastChannel` range to the push would
remove ~80 % of it. **Deferred** — v1 should differ from the proven corpse path in as few places as
possible.

---

## 8. ACCEPTANCE — one build, one session

### 8.1 Cvars

| cvar | default | meaning |
|---|---:|---|
| `coop_hitreact` | **0** | master gate. `CVAR_ARCHIVE`, dark until signed off — same pattern and same reasoning as `coop_ragdoll` (`cg_ragdoll.c:318-320`) |
| `coop_hitreactForce` | 1.0 | multiplier on the impulse the corpse path already receives |
| `coop_hitreactVMax` | 240 | u/s clamp on any member point's post-impulse speed. **The single knob that bounds both `swing` and `stretch`** (§4.4, §4.5) |
| `coop_hitreactK` | 0.0246 | spring, = (ωh)² |
| `coop_hitreactDamp` | 0.812 | = 1 − 2ζωh |
| `coop_hitreactRelease` | 120 | ms |
| `coop_hitreactGrav` | 0 | fraction of world gravity; 1.0 costs 1.33 u of permanent droop |
| `coop_hitreactLegs` | 1 | allow leg hits (see hazard 3) |

All `CVAR_TEMP` except the master, matching the R10 convention at `cg_ragdoll.c:327-351`.

### 8.2 The instruments

One line per reaction, at release, behind `r_ragdollDebug 1`:

```
^~^~^ FLINCH ent=%d bone=%s swing=%.1fdeg peak=%.2fu stretch=%.3f rise=%dms life=%dms pts=%d chans=%d seedv=%.0f
```

- **`swing`** — reuse the corpse swing instrument verbatim (`cg_ragdoll.c:1866-1887`): the angle
  between the struck bone's drive direction at seed and its peak, drive child from `s_ragDriveChild`
  (`:101-117`). This makes the living number **directly comparable** to the corpse's 60.5°
  **[reported]**, which is the whole reason to reuse it rather than invent a new metric.
- **`stretch`** — max over member links of `|rendered bone| / |anim bone|`, measured at the
  **blended** pose, not the sim pose. This is the only instrument that sees the §4.5 artifact, and it
  must be sampled at the rendered result or it is blind by construction (the same trap the R10 spin
  instrument had to be rewritten to avoid, `cg_ragdoll.c:1833-1837`).
- **`peak`** — max `|d|` over the reaction, in model units.
- **`chans`** — number of channels with `w > 0`. Predicted 21 for a right-forearm hit on the
  87-channel ranger (§3.2); a wildly different number means the anchor table or the subtree walk is
  selecting the wrong thing, and that is checkable **before** looking at the screen.

### 8.3 The live test

```
coop_hitreact 1 ; r_ragdollDebug 1
```

Stand ~10 m from **one** German. Fire **one** rifle round into his right forearm.

| # | expectation | instrument |
|---|---|---|
| 1 | exactly one `FLINCH` line, `bone="Bip01 R Forearm"` | console |
| 2 | `swing` between **18 and 30** | console |
| 3 | `stretch` between **0.95 and 1.05** | console |
| 4 | `chans` ≈ **21** | console |
| 5 | the forearm, hand **and the rifle** kick; the shoulders, torso and legs do not | eye |
| 6 | he keeps running, keeps firing, feet stay planted, no slide | eye |
| 7 | the authored `coop_hitReact` flinch still plays on the ~55 % of hits that roll it | eye + `hitreact=` counter |
| 8 | corpse ragdolls behave exactly as they did before this build | eye |

Then a magazine into one man: `chans` must not exceed ~34 (two limbs unioned), `life` must not exceed
900 ms on any line, and he must not become rubbery.

**Negative control:** `coop_hitreact 0` → zero `FLINCH` lines, and every corpse slot has
`hasWeights == qfalse` so Hook A takes the `w >= 1-eps` branch, which is today's shipped code.

### 8.4 Rollback

```
coop_hitreact 0
```

One console command, no rebuild, no restart. It is a true rollback rather than a mute because the
corpse path never sets `hasWeights`, so with the feature off the renderer executes the identical
instruction sequence it ships today.

---

## 9. THE TOP HAZARDS

1. **Two translation spaces in one module.** `slot->animPose` is **raw skeletor space** (Hook A copies
   `newFrame->bones[i][3]` verbatim, `tr_ragdoll.cpp:127/131/135`) while `slot->mat` is
   **TIKI-orientation space** (`(raw + load_origin) · load_scale`). Lerping them without converting
   is bug-1963 defect 2 re-committed — human tikis carry `load_scale` 0.52, so the blend would drag
   every reacting bone toward 52 % of its true offset, worst at mid-envelope, and it would look like
   "the limb sucks inward when it moves." *Mitigation:* the conversion appears exactly twice, both in
   `tr_ragdoll.cpp`, and they are literal inverses; cgame sees one space and *cannot* see
   `load_scale` at all — `dtiki_s` is forward-declared only in its include set
   (`renderercommon/tr_types.h:93`), so the mistake is a compile error there rather than a silent
   render defect.

2. **`RagCapture` reads its own override through Hook B.** `cgi.TIKI_Orientation`
   (`cg_ragdoll.c:610`) funnels into `RE_TIKI_Orientation` → `R_RagdollGetOrientation`. Once living
   actors carry rows, a man who dies mid-reaction has his *corpse* captured from the flinch pose
   instead of the animator's death pose — silently poisoning the R12 corpse ragdoll, with no error
   line, on some fraction of kills. *Mitigation:* Hook B returns `qfalse` at `w <= eps` (falling
   through to the exact vanilla answer) **and** `RagCapture` clears the row as its first statement.
   Two independent guards, because this one fails silently and intermittently.

3. **A leg reaction puts a foot through the floor.** The living path has no world collision by
   design, and the model-space displacement is blind to the ground. A 29° swing on a thigh moves the
   foot ~9 u, which on a man standing on a lip is under the geometry. *Mitigation:* `coop_hitreactLegs`
   (default 1, so it is one console command to disable), a hard `invMass = 0` on the pelvis so he can
   never be lifted or dropped as a whole, and the short envelope. If the live test shows it, the fix
   is a single downward `CM_BoxTrace` per foot point per frame — 24 traces/frame at 12 actors, well
   inside the existing `RAG_TRACE_BUDGET` of 240 (`cg_ragdoll.c:63`) — not a return to the corpse
   collision system.

**Runners-up worth naming:** the three-binary ABI (renderer → exe → cgame; mitigated by *appending*
`SetRagdollWeights` rather than widening `SetRagdollPose`, plus the `if (!cgi.…)` guard); and the
shared 16-slot pool, where an unbudgeted living layer would starve corpse ragdolls in a firefight
(mitigated by 32 slots and cgame's 28-slot refusal line).
