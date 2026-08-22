# RAGDOLL ROUND 11 — IMPLEMENTATION SPEC

**Anchor.** Every `cg_ragdoll.c` line number in this document is against
`openmohaa-hzm` commit **`15a8f5c5`** ("fix: bullet impulses must ROTATE a limb, not translate
it"), file length **2176 lines**, which is HEAD and is what is **built and deployed**
(`G:\mohaa-gl2\cgame.dll` and `openmohaa-hzm\.cmake\code\client\cgame\Release\cgame.dll` are
both md5 `c692f6ea…`, timestamped 16:27 — the same minute as the commit). The engine working
tree carries only `fgame/sentient.*` + `fgame/weaputils.cpp` edits; `cg_ragdoll.c` is clean at
HEAD.

Every number below was re-derived here, not carried over. Where a source document and the code
disagree, the code wins.

---

## 0. EXECUTIVE SUMMARY

**The premise this project was queued on is dead, and it must be re-motivated before a line is
written.** The user's own live experiment settled it: with `coop_ragdollTruss 0` — every
anti-pile brace switched off, the body completely slack — **limbs still did not move**
(`15a8f5c5` commit message, and the knob is real at `cg_ragdoll.c:298`, `:326`, gate `:991-998`).
The truss was never the limiter. The limiter was the impulse, and the symmetric force split that
made a struck bone *translate* instead of *rotate* is already fixed at `:1439-1448`.

So joint limits are **not** a fix for "arms aren't moving". They are **infrastructure for the
thing the user actually asked for** — "the life comes out of their body… physics does the rest".
A physics-owned fall picks anatomically impossible configurations unless something forbids them;
that is what eight rounds of mangled piles were. Limits are the prerequisite, and nothing else
on the roadmap is.

**Four things are wrong or missing today, in the order they must be fixed:**

1. **A confirmed sign error is actively pushing corpses away from their own pose.**
   `cg_ragdoll.c:937` computes `k = 1.0f - limpMs / RAG_IMPACT_LIMP_MS` with
   `RAG_IMPACT_LIMP_MS` fixed at 600 (`:66`), but explosions pass **1200–1410 ms**
   (`cg_parsemsg.cpp:1867-1869`) and bullets pass **600–810 ms** (`:1808`, `:1820`, `:2232`,
   `:2244`). Whenever `limpMs > 631.6` the shape-match alpha at `:938-940` goes **negative** —
   down to `0.25 × (0.05 + 0.95 × −1.00) = −0.225`. `VectorMA(pt, a, d, pt)` with `a < 0` moves
   the point *away* from its goal, and does so again next substep from further away: a
   positive-feedback anti-shape-match. It runs for **568 ms ≈ 71 substeps** on every grenade
   near a corpse. This is a live defect in exactly the code path the complaint is about.

2. **The ragdoll does not follow the server's corpse toss, and the code comment claims it
   does.** `weaputils.cpp:3526-3550` gives the corpse *entity* `velocity += vPush·300·fFrac`
   and `velocity.z += 210·fFrac`; its own instrumented A/B, in-comment at `:3502-3506`,
   measures the throw at **121 u → 441 u** on flat ground. The cgame sim's `pt[]` are
   world-anchored and never follow it. `RagPush` converts world→model against
   `cent->lerpOrigin` (`:1257`, `:1319-1323`) and the renderer recomposes with the same
   placement, so **the conversion cancels exactly and the mesh renders at the sim position, not
   the entity's**. Meanwhile `RagSane`'s leash (`:1229-1236`) measures `|pt[0] − lerpOrigin|`
   against 128 u and retires the corpse permanently via `s_ragNeverArm` (`:1721`) when it trips.
   The comment at `cg_parsemsg.cpp:1863-1865` — *"The server also tosses the corpse ENTITY and
   our pose already follows that"* — is false.

3. **The knee is not merely unsimulated; the calf receives a bit-identical copy of the thigh's
   rotation.** `s_ragDriveChild[12] = -1` (`:113`), so at `RagPush:1286-1293` bone 11 takes
   `(driveDir0[11], pt[12]−pt[11])` and bone 12 falls to the leaf path and takes
   `(restDir[12], pt[12]−pt[11])`. `driveDir0[11]` and `restDir[12]` are both set to
   `unit(pt[12]−pt[11])` at capture (`:694` and `:762-766`) — **the same vector**. Both call
   `RagMat3FromTo` with identical arguments, so **`S(12) ≡ S(11)` every frame, identically**.
   The knee angle is frozen at its capture value forever, and a measured **29–42 % (mean 35 %)**
   of the corpse mesh rides on it.

4. **There are no angular limits, so the body cannot be loosened without piling.** That is the
   whole of round 11's payload, and it is stage 3.

**Two numbers in circulation are wrong and are sizing safety gates. Both are corrected here from
the model data itself** (`scratchpad/spec_skd.py`, written from `skelHeader_t`
`tiki/tiki_shared.h:214-230` and `boneFileData_t`
`skeletor/skeletor_model_file_format.h:50-58`; 13 full-15-bone skeletons found in the mod tree,
all identical):

| quantity | circulated | **measured** |
|---|---|---|
| shin (Calf → Foot) | "~46 u" | 46.04 **cm** × `load_scale` 0.52 = **23.94 world units** |
| thigh (Thigh → Calf) | — | 46.35 cm × 0.52 = **24.10 world units** |

The 46 was the raw centimetre figure with the 0.52 load-scale dropped. Full leg extension is
**48.04 u**, not 92; the `RagSane` 200 u span gate (`:1219-1224`) keeps ample headroom and
does **not** need re-baselining this round.

**And the Calf's origin is the knee — by engine construction, not by inference.**
`tiki/tiki_skel.cpp:103-113` stores only `boneData->length` for `SKELBONE_IKELBOW`/`IKWRIST` (no
offset at all), and `skelBone_IKelbow::GetDirtyTransform` (`skeletor/skeletorbones.cpp:852-862`)
places the bone at `shoulder_origin + m_upperLength · row0` — the far end of the thigh.
`Bip01 L Calf` has boneType 3 (IKELBOW) and `Bip01 L Foot` boneType 4 (IKWRIST) on all 13
skeletons measured. The shin therefore has **no representation at all** in the 15-point cloud;
it is not under-constrained, it is *absent*.

**Feet exist everywhere it matters.** 13/13 full-skeleton SKDs in the mod tree carry both
`Bip01 L/R Foot` and both `Bip01 L/R Toe0`; zero `(skd, side)` pairs carry a Calf without a
Foot. The engine's own hit-location table lists them (`qcommon/cm_trace_lbd.cpp:31-51`, 19
entries ending `"Bip01 R Foot"`, `"Bip01 L Foot"`). A parallel sweep of 1575 SKDs / 1985
ragdoll-eligible TIKs found the same zero. **The build must still never bail on a missing foot**
— a bail is a permanent, silent coverage loss on that corpse, and coverage is the one number
this project is not handing back.

**No new engine import is required at any stage.** All ten calls used are already in
`clientGameImport_t`: `Printf:103`, `Cvar_Get:122`, `CM_InlineModel:171`, `CM_PointContents:173`,
`CM_BoxTrace:177`, `CM_TransformedBoxTrace:187`, `R_AddRefEntityToScene:295`,
`Tag_NumForName:406`, `Tag_NameForNum:407`, `ForceUpdatePose:408`, `TIKI_Orientation:409`,
`R_SetRagdollPose:453`, `R_ClearRagdoll:454`. **No renderer change either**:
`renderergl1/tr_ragdoll.cpp` and `renderergl2/tr_ragdoll.cpp` are byte-identical (`diff` clean)
and copy the 3×3 verbatim with no re-orthonormalisation (`:158-171`), so any matrix this build
produces must already be orthonormal — which every construction here is, being a composition of
rotations.

**The build sequence is four sessions.** Stage 0 costs no rebuild. Stages 1–3 are `cgame.dll`
only. Every stage has a one-word console rollback.

---

## 1. CONFLICT RECONCILIATION

The four design lenses were adversarially verified and disagree in twelve places. Each is
decided here, with the reason in one sentence.

| # | Conflict | **Decision** | Why |
|---|---|---|---|
| C1 | *truss lens:* "the truss is the slab, cutting it makes limbs move" vs *risk/solver:* refuted by the live `coop_ragdollTruss 0` test | **Refuted. Re-motivate the project as infrastructure for the earlier handoff.** | The user ran the experiment and limbs still did not move with every brace off, so any acceptance test written against the truss hypothesis is testing an answered question. |
| C2 | Feet first (topology) vs limits first (solver) vs playtest first (truss) vs impulse first (risk) | **Playtest → impulse → feet → limits.** | HEAD carries two substantive untested commits, and you cannot judge a new build stacked on an unjudged one; the impulse defect is confirmed and 3 lines; feet are the prerequisite for 4 of the 18 limits. |
| C3 | 21 limits (design) vs 19 (solver, cut J1/J2) vs 18 (solver, defer J3) vs 27 (truss) | **18 limits. J1, J2 and J3 are all cut.** | Their moving set `subtree(2) = {2..10}` contains `pt[5]` and `pt[8]`, which are endpoints of the equality braces `{5,13}` and `{8,11}` that must survive — so all three provably fight the truss regardless of `μ`. |
| C4 | `μ = 0.35` on spine limits (design) vs `μ = 0` everywhere (solver R1, risk) | **`μ = 0` on every limit, and the `μ` code path is not built at all.** | The complement of `subtree(2)` contains `pt[0]`, `pt[1]`, `pt[11]` and `pt[13]` — three of `RagRawFit`'s four inputs (`:845-846`) *and* the leashed pelvis (`:1231`) — so a non-zero `μ` injects body rotation into the spin instrument and translates a leashed pelvis. |
| C5 | Hip `[−25°, +110°]`, shoulder `[−60°, +170°]` (design) vs inverted (solver C1) | **Inverted; corrected to `[−115°, +25°]` and `[−170°, +60°]`.** | Re-derived from scratch in §3.2: positive rotation about `T[1]` from neutral `−T[2]` moves the limb toward `−F` = **backward**, so the design grants 110° of hip *extension*. |
| C6 | Hinge axis from `unit(a₀×b₀)` with a sign test (design) vs medio-lateral rule (solver) | **Neither as written: sign fixed analytically at capture from the body triad, axis carried on the parent segment's own swing.** | The design's sign test is a tautology in the bent branch (its `+10°` probe always shortens `\|c−g\|`, so it never negates) and a coin flip on animation noise in the straight branch, while the pure triad axis fails for an abducted arm. |
| C7 | Out-of-plane clamps: keep (design, solver) vs drop | **Keep, on the parent-carried axis.** | Without them the knee can bend laterally, which is the "broken leg" read; with a parent-carried axis they are well-conditioned in every limb orientation. |
| C8 | Delete `s_ragBraces` rows 6-15 (design §5.5) vs gate them at runtime (risk §12, topology #12) | **Runtime gate on the same cvar as the limits. Nothing is deleted this round.** | It satisfies the atomicity rule in *both* directions by construction (`coop_ragdollLimits 1` ⇒ limits on **and** folds off; `0` ⇒ the exact converse), and it turns the A/B into a keypress instead of a rebuild. |
| C9 | Row 13 `{1,11}` is in the conflict set (risk §2 table) vs is not (risk R-finding) | **Not in the conflict set. Keep it; fix its comment.** | Neither endpoint appears in any surviving moving set (`{4,6,7,9,10,12,14,15,16}`), and `\|pt[1]−pt[11]\|` is *not* fixed, so it is a live one-sided bound on a DOF no limit covers — the code comment at `:137` calling it "geometrically inert" is wrong. |
| C10 | `RAG_ITERS` 6 → 4 (design "defensible per Macklin 2019") | **Stays at 6.** | Independent measurement puts peak link stretch at 1.49 (6 iters) vs 1.62 (4) under load — a 9 % regression against a build whose own acceptance gate is `stretch ≤ 1.10`, bought for a budget saving the trace/flop accounting says is not needed. |
| C11 | Knee brace factor 0.75 (topology §6.2) vs derive it | **0.34.** | 0.75 of a straight-leg capture permits only 82.8° of knee flexion (re-derived below), which a kneeling or leg-folded death pose routinely exceeds; with the measured 24.10/23.94 u segments, 140° of flexion needs `f = 16.43 / 48.04 = 0.342`. |
| C12 | Compile-time table guard as `sizeof(tbl)/sizeof(tbl[0]) == RAG_PTS` on an explicitly-sized array | **Unsize the five tables first, then assert.** | The array is *declared* `[RAG_PTS]`, so C zero-fills the missing initialisers and the `sizeof` expression is tautologically true — the guard passes in precisely the case it claims to catch. |

**Two claims from the lenses I could not verify and am not building on:**
`drift= +11 %` after the feet land (plausible from geometry — the feet sit 48.3 u from the
pelvis vs the knees' 24.6 — but not re-derivable without live pose data), and the 43.2 u
minimum-compactness figure for self-collision (its harness was not accepted). Self-collision is
justified on mechanism in §8, never on that number.

---

## 2. THE BUILD SEQUENCE

Four stages. **One question each.** The user tests one build per session, so a stage is a
session. Items marked **ATOMIC** may never be split across a build boundary.

---

### STAGE 0 — "What does HEAD actually look like?"

**No engine rebuild. Mod-side only (`.\build.ps1`).** HEAD's `cgame.dll` is already deployed.

Two substantive commits shipped and were never seen: `cad7efcb` (bullet force `90+55·iLarge`
→ `150+70·iLarge`, radius `30+2·iLarge` → **`15+1.5·iLarge`** — the radius *halved*) and
`15a8f5c5` (asymmetric distal force split + distal-subtree limp). Stacking a new build on an
unjudged one makes every subsequent measurement uninterpretable.

**IN**
- `coop_mod/cfg/rag_run.cfg` (F8) becomes a **true** reset key. Today it seeds 8 cvars and its
  own comment promises "every ragdoll cvar" — it omits `coop_ragdollTruss`, `RotLock`, `Slew`,
  `Carry`, `VelCap`, `Leash`. If the user left `coop_ragdollTruss 0` from the experiment, every
  later measurement this session is silently taken on a braceless body.
- `coop_mod/cfg/rag_drill.cfg` (F7) `coop_ragdollMode 3` → **`1`**. The drill currently
  exercises the free branch, which does not ship; `:1982` already supports `coop_ragdollTest 2`
  on the settle branch.
- Correct three wrong comments (no behaviour change): `:135` `{0,12}` is a **hip** fold limit
  not a knee one (`\|pt0−pt12\|` is a pure function of the angle at `pt[11]`, since
  `\|pt0−pt11\|` and `\|pt11−pt12\|` are both fixed links); `:137` `{1,11}` is **not**
  geometrically inert; `cg_parsemsg.cpp:1863-1865` "our pose already follows that" is **false**.

**OUT** — everything else. No `.c` behaviour change, no DLL.

**Rollback:** `exec coop_mod/cfg/rag_off.cfg`.

---

### STAGE 1 — "Does a blasted corpse react without mangling, and if not, is it the solver or the server toss?"

`cgame.dll` only. ~40 lines. Touches nothing in `RagCapture`, `RagPush`, the space contract, or
the pending/server-park path.

**IN**

**1a. The limp ramp, monotone over the window actually granted.** The confirmed sign error.

```c
/* struct ragSim_s, beside limpMs[] at :202 */
short  limpMax[RAG_PTS];   /* the window the CALLER asked for. RAG_IMPACT_LIMP_MS is a
                              600ms CONSTANT but the call sites pass 600-810 (bullets,
                              cg_parsemsg.cpp:1808) and 1200-1410 (explosions, :1867), so
                              k = 1 - limpMs/600 went NEGATIVE for the first 568ms of every
                              grenade - and a negative alpha in RagShapeMatch moves the point
                              AWAY from its goal, further every substep. An anti-shape-match. */
```

`RagShapeMatch`, replacing `:937-938`:

```c
if (s->limpMs[i] > 0) {
    float win = (s->limpMax[i] > 0) ? (float)s->limpMax[i] : (float)RAG_IMPACT_LIMP_MS;
    float k   = 1.0f - (float)s->limpMs[i] / win;   /* now in [0,1] by construction */
    if (k < 0.0f) { k = 0.0f; }                     /* belt: limpMax can never be stale */
    a *= rag_limprelax->value + (1.0f - rag_limprelax->value) * k;
}
```

Every site that writes `limpMs` writes `limpMax` in the same statement — three of them:
`:1464` (the struck ends), `:1474` (the distal-subtree walk), `:1535` (the explosion path).
Scale the granted window by the new sweep cvar at the top of `CG_RagdollImpulse`:

```c
limpMs = (int)(limpMs * rag_limpscale->value);
if (limpMs < 0)     { limpMs = 0; }
if (limpMs > 30000) { limpMs = 30000; }   /* short fits limpMs/limpMax */
```

**1b. The sim rides the entity.** Makes the `cg_parsemsg.cpp:1864` comment true.

```c
/* struct ragSim_s */
vec3_t entTrack;     /* lerpOrigin the sim was last carried to */
float  entDrift;     /* |pt[0] - lerpOrigin| at the last sane check (instrument) */
```

In `CG_RagdollFrame`, immediately before `frameStart[]` is captured (`:1629`):

```c
/* THE SERVER TOSSES THE CORPSE ENTITY (weaputils.cpp:3526-3550: velocity += vPush*300*fFrac,
   z += 210*fFrac; its own instrumented A/B measures the throw at 121u -> 441u on flat ground).
   The sim's pt[] are world-anchored and RagPush converts against the CURRENT lerpOrigin, so the
   conversion cancels exactly and the mesh renders where the SIM is, not where the entity is:
   the body visibly refuses the toss, and RagSane's 128u pelvis leash (:1229) then retires it
   permanently. Carry the whole cloud by the entity's frame delta - pt AND ptPrev by the SAME
   vector, so it is a rigid translation with ZERO implied-velocity change. */
if (rag_carryent->integer) {
    vec3_t dEnt;
    VectorSubtract(cg_entities[s->entnum].lerpOrigin, s->entTrack, dEnt);
    if (VectorLengthSquared(dEnt) > 0.0001f && VectorLengthSquared(dEnt) < 1024.0f) {
        for (j = 0; j < RAG_PTS; j++) {           /* >32u in one frame is a teleport, not a  */
            VectorAdd(s->pt[j], dEnt, s->pt[j]);  /* toss - leave those to the clear signals */
            VectorAdd(s->ptPrev[j], dEnt, s->ptPrev[j]);
            VectorAdd(s->goal[j], dEnt, s->goal[j]);  /* the goal is a WORLD pose: it rides too */
        }
    }
}
VectorCopy(cg_entities[s->entnum].lerpOrigin, s->entTrack);
```

`s->entTrack` is seeded from `cent->lerpOrigin` at the end of `RagCapture` (`:826`) and in
`RagPendingThink` after `RagAllocSlot` succeeds. **`goal[]` must ride with the cloud** or the
shape-match instantly drags the body back to where the entity used to be — that is the one
non-obvious line in this stage.

**1c. Instruments.** `entdrift=` and `limpmax=` in the sleep line (`:1785-1789`) and
`entdrift=` in the blowup line (`:1717-1719`). `RagSane` records `s->entDrift` on the leash
test whether or not it fires.

**1d. Cvars.** `coop_ragdollLimpScale` (1.0), `coop_ragdollLimpRelax` (0.05),
`coop_ragdollCarryEnt` (1). All `CVAR_TEMP`, all defaults == the behaviour above.

**OUT** — no new points, no limits, no brace change, no `RAG_PTS` change, no touch of
`RagBodyRotationAdvance`/`RagRawFit`/`RagPush`/`RagCapture`'s bail ladder. Explicitly **not**
in this build: the `clear = (r+2)·f` clearance arithmetic at `:724` (the ±1 probe box's lower
face starts 1 u below `pt`, so true clearance is `1 + (r+2)·f`) and the `RagSane` span
re-baseline — both are drape-depth changes and both stay deferred, as `ragdoll_r9_spec.md:64,95`
already ruled.

**Rollback:** `coop_ragdollCarryEnt 0` (isolates 1b) · `coop_ragdollLimpScale 0` (isolates 1a)
· `coop_ragdoll 0` (kills the feature).

---

### STAGE 2 — "Does the shin get a direction of its own?"

`cgame.dll` only. ~90 lines + a 35-site audit. **This is the riskiest stage**, because its
failure mode is a silent, permanent coverage loss.

**IN**

**2a — FIRST COMMIT, BEFORE ANYTHING ELSE. Make the tables self-checking.**
Growing `RAG_PTS` from 15 to 17 silently zero-fills any table whose initialiser is not extended,
and three of the five zero-fills are invisible: `s_ragPtRadius[15] = 0` makes
`VectorSet(pm, -0,-0,-0)` at `:633-634` a **point** trace in the pre-lift (bug-1962's exact
pin); `s_ragDriveChild[15] = 0` passes the `dch >= 0` test at `:1286` and drives the foot by
`pt[0] − pt[15]` (ankle→pelvis); `s_ragBraceMinFactor[16] = 0` is read as an **equality** brace
at both `:707` and `:1004`, welding the ankle to the hip at capture distance so that the knee
freezes solid — *which would look exactly like the knee still doesn't bend.* And
`s_ragBones[15].name = NULL` does **not** fail gracefully: it reaches
`ChannelNameTable::FindIndexFromName`, whose body is `stricmp(name, ...)`
(`skeletor/bonetable.cpp:60-99`) — an access violation inside `cgame.dll` on the first kill.

Drop the explicit bound so a missing initialiser **shrinks** the array, then assert:

```c
static const struct { const char *name; int parent; } s_ragBones[]   = { ... };
static const int    s_ragDriveChild[]      = { ... };
static const float  s_ragPtRadius[]        = { ... };
static const int    s_ragBraces[][2]       = { ... };
static const float  s_ragBraceMinFactor[]  = { ... };

/* A table that forgot a row now SHRINKS, so these catch it at compile time. Sized arrays
   would not: C zero-fills the missing rows and sizeof() stays == RAG_PTS, i.e. the guard
   passes in exactly the case it exists to catch. */
typedef char rag_chk_bones [(sizeof(s_ragBones)/sizeof(s_ragBones[0])                 == RAG_PTS)    ? 1 : -1];
typedef char rag_chk_drive [(sizeof(s_ragDriveChild)/sizeof(s_ragDriveChild[0])       == RAG_PTS)    ? 1 : -1];
typedef char rag_chk_radius[(sizeof(s_ragPtRadius)/sizeof(s_ragPtRadius[0])           == RAG_PTS)    ? 1 : -1];
typedef char rag_chk_brace [(sizeof(s_ragBraces)/sizeof(s_ragBraces[0])               == RAG_BRACES) ? 1 : -1];
typedef char rag_chk_minf  [(sizeof(s_ragBraceMinFactor)/sizeof(s_ragBraceMinFactor[0]) == RAG_BRACES) ? 1 : -1];
```

**2b. Grow the tables. Append, never renumber.** Index 0 = pelvis, `i <= 4` = torso (`:653`),
`pt[4]`/`pt[0]` (`:671`), `pt[13]−pt[11]` (`:735`, `:846`), `pt[1]−pt[0]` (`:845`), leash
`pt[0]` (`:1231`) and the root-before-leaf link sweep are all load-bearing on the existing
numbering.

```c
#define RAG_PTS  17
    ...
    {"Bip01 L Calf",    11}, // 12  <- this point IS the KNEE (tiki_skel.cpp:103-113 stores only
    {"Bip01 R Thigh",    0}, // 13     a LENGTH for IKELBOW/IKWRIST, and skeletorbones.cpp:852-862
    {"Bip01 R Calf",    13}, // 14     places the bone at shoulder + upperLength*row0 = the far
    {"Bip01 L Foot",    12}, // 15     end of the thigh. Measured 46.35cm thigh / 46.04cm shin,
    {"Bip01 R Foot",    14}, // 16     x load_scale 0.52 = 24.10u / 23.94u world.
```

`s_ragDriveChild`: `[12] = 15`, `[14] = 16`, append `-1, -1`.
`s_ragPtRadius`: append `3.0f, 3.0f` (the extremity band of this table runs 0.42–0.63× the
engine's own `fLocRadius` at `cm_trace_lbd.cpp:53-55`; the foot's 6.0 × 0.50 = 3.0, and the
capture clearance clamp at `:716-733` tightens it per corpse anyway).
`s_ragAnchorTable` (`:269-272`): `"Bip01 L Foot"` 12 → **15**, `"Bip01 L Toe"` 12 → **15**,
`"Bip01 R Foot"` 14 → **16**, `"Bip01 R Toe"` 14 → **16**.

**2c. Two braces, `RAG_BRACES 16 → 18`.** These exist only in the window between stage 2 and
stage 3; stage 3's runtime gate switches them off along with the rest of the fold set.

```c
    {11, 15}, // L hip - L ankle  (KNEE fold limit: with 11->12 and 12->15 both fixed links,
    {13, 16}, // R hip - R ankle   |pt11-pt15| is a pure function of the knee angle)
```
```c
    0.34f, 0.34f,   // knees. DERIVED, not picked: thigh 24.10u, shin 23.94u, so
                    // |d|^2 = 1153.9*(1 - cos(gamma)) with gamma the interior angle at the
                    // knee. Straight leg |d| = 48.04u. 140 deg of flexion is gamma = 40 deg
                    // -> |d| = 16.43u -> 16.43/48.04 = 0.342. (0.75 would cap the knee at
                    // 82.8 deg, which a kneeling death pose already exceeds.)
```

**2d. Budgets, or the feet silently vanish on the 4th mover.** `RagCollideMovers` allows
`s_ragTraceCount + RAG_MOVER_PER_BODY` (`:1154`) and returns at `:1179-1181`. With 4 movers ×
17 points = 68 > 60, the 4th mover gets indices 0–8 and **drops 9–16 — both forearms, both
thighs, both calves and both feet** — and prints nothing. **ATOMIC with 2b:**
`RAG_MOVER_PER_BODY 60 → 68`, `RAG_TRACE_BUDGET 240 → 272` (both `4 × 68`). World traces are
budget-exempt with their own counter (`s_ragWorldTraces`, `:1122`, bug-1967) and rise
15×4×8 = 480 → 17×4×8 = **544**, +13.3 %.

**2e. Never bail; never lose a corpse.** `RagCapture:600-606` returns `qfalse` on *any* missing
`s_ragBones[]` name, which for a footless SKD would cost that corpse its ragdoll permanently.
Replace the bail **for points 15/16 only**:

```c
if (s->simChan[i] < 0 || s->simChan[i] >= s->count) {
    if (i >= 15) {
        /* FOOTLESS SKD (none found in 13 full skeletons here, nor in a 1575-file sweep, but a
           bail is a PERMANENT silent coverage loss and coverage is the number we are not
           handing back). Seed the foot ON the knee: RAG_PTS stays 17 so every one of the 35
           `< RAG_PTS` loops reads valid data, the zero-length link is already a no-op at
           :981, and driveOk[12] falls to 0 on its own because VectorNormalize(pt[15]-pt[12])
           returns 0 at :763 - which reverts bone 12 to exactly today's leaf behaviour with
           no special case in RagPush at all. */
        s->simChan[i] = -1;
        VectorCopy(s->pt[(i == 15) ? 12 : 14], s->pt[i]);
        VectorCopy(s->pt[i], s->ptPrev[i]);
        s->ptRadius[i] = 1.0f;
        s->footless    = 1;
        continue;
    }
    ... existing bail ...
}
```

Guard the two places that index by channel: the `mat0` read at `:607-609` (skip when
`simChan[i] < 0`) and the self-anchor loop at `:783-788` (never matches `-1`, already safe).

**2f. The burial gate.** `:658` refuses to arm at `buried >= 4`. Feet are the most
burial-prone points on a corpse and adding two of them tightens an absolute threshold. Make it
`coop_ragdollBuriedMax`, default **5**. `RagCvars()` has run on both paths into `RagCapture`
(`:1562`, `:2036`), so the read is safe.

**2g. The 35-site audit.** Every `< RAG_PTS` loop and every `[RAG_PTS]` declaration is swept and
signed off. With 2a + 2e in place the only remaining failure is a loop that *hard-codes* 15.

**OUT** — no limits, no deletion of any existing brace row, no `RagPush` conversion change, no
`RagShapeMatch` change, no self-collision, no Toe0 as points 17/18 (a measured **4.5–9.9 %,
mean 6.5 %** of the mesh, against a doubling of the ankle's contact geometry — not worth it).

**Known, priced regression.** Today `s_ragDriveChild[12] = -1` pins the knee angle at its
anatomically-legal capture value forever. After this stage the knee is a real 2-DOF joint whose
only restoring force is `RagShapeMatch` at alpha 0.25 — relaxed to 0.15× at contact
(`RAG_CONTACT_RELAX`, `:64`) and 0.05× under a limp window (`RAG_IMPACT_RELAX`, `:65`), i.e.
**weakest in exactly the two situations the visual test exercises**. The build converts *frozen
and wrong* into *articulated and possibly anatomically impossible*, and a backwards-bending knee
is a new failure it can produce. The `{11,15}` brace bounds over-folding but says nothing about
direction; only stage 3's `L14/L16` do. **The acceptance test is therefore directional (§6).**

**Rollback:** `coop_ragdollFeet 0` — at 0 the capture seeds `pt[15] = pt[12]`, `pt[16] = pt[14]`
by the same 2e path, `driveOk[12]`/`[14]` fall to 0, the two new braces get `braceLen = 0` and
skip at `:1001`, and the body is byte-for-byte today's 15-point sim in a 17-point array.

---

### STAGE 3 — "Can the body be loose without piling?" — **THE LIMITS**

`cgame.dll` only. ~450 lines. Solver-local: nothing here touches `RagCapture`'s bail ladder,
`RagPush`'s conversion, the space contract, the pending/server-park path, or the rotation
filter.

**IN — and these three are ATOMIC with each other. They ship in one commit or none.**

**3a. 18 angular limits** (§3, §4), all `μ = 0`, gated on `coop_ragdollLimits`.

**3b. The fold-brace gate, in the same branch.** `s_ragBraces` is **not edited**. In
`RagStep`'s brace loop, after the `rag_truss` block at `:991-998`:

```c
/* ATOMICITY, ENFORCED AT RUNTIME. Rows with a non-zero min factor are FOLD limits: each one
   caps a joint the angular limits now cap properly, with a direction instead of a distance,
   and a min-distance brace pushing a hand away from spine2 while the shoulder limit pulls the
   arm across is a guaranteed limit cycle. Row 13 {1,11} is the ONE exception: neither endpoint
   appears in any limit's moving set, and |pt1-pt11| is NOT fixed (the comment at :137 calling
   it inert is wrong), so it is a live one-sided bound on a lumbar DOF no limit covers.
   Gating rather than deleting means coop_ragdollLimits can never half-ship the pair, and the
   A/B is a console word instead of a rebuild. */
if (s_ragBraceMinFactor[i] > 0 && i != 13 && rag_limits->integer) {
    continue;
}
```

**Why this is safe, and it is provable, not hoped for.** With `J1/J2/J3` cut and `μ = 0`, the
union of every limit's moving set is `{4, 6, 7, 9, 10, 12, 14, 15, 16}`. A rigid rotation about
a pivot preserves `|a−b|` when both endpoints are inside the mask, both outside, or one of them
*is* the pivot. The endpoints of the seven surviving braces are
`{0,1,2,3,5,8,11,13}` — **disjoint from the moving-set union.** Therefore:

> **INVARIANT L1.** No surviving brace can be perturbed by any limit.
> **INVARIANT L2.** No limit can move `pt[0]`, `pt[1]`, `pt[11]` or `pt[13]` — which are
> exactly `RagRawFit`'s four inputs (`:845-846`) and the leashed pelvis (`:1231`). **The limits
> provably cannot re-open the spin problem or trip the leash.**

**3c. `coop_ragdollTruss` merged.** Its experiment has returned a decisive answer, so it stops
being a second, independent brace gate (two gates make the rollback promise false and the mode
matrix unreasonable). It becomes a **stiffness scalar on the surviving rows only**: the `break`
at `:993` becomes `continue`, and the existing `corr *= tstiff` stays. `coop_ragdollLimits`
becomes the single authority over `{fold rows, limits}`.

**3d. One extra limit sweep after `RagShapeMatch`, before `RagCollideWorld`.** The shape-match
(`:915-948`) moves points with per-point alphas — 0.25, ×0.15 at contact, ×(0.05…1) under a
limp — so it is **not** rigid and can re-violate a limit it was just corrected out of; nothing
re-enforces anything after it today (bug-1962's own note at `:1682-1683`). Collision must keep
the last word (that is what bug-1962 bought with a live round), so the sweep goes *between*
them, inside `RagStep`.

**3e. Instruments.** `lim=` (limit corrections applied this life), `limmax=` (largest single
correction, degrees), `limsat=` (times `RAG_LIMIT_MAX_STEP` clamped), `limoff=` (limits disabled
for this corpse by the capture validator), `limbad=` (frames a body triad was degenerate).

**OUT** — no `RagBuildFrames` per-bone frame chain (it buys only twist inheritance now that
`s_ragDriveChild` shipped, and it would put risk on the render path the freeze drill is
structurally blind to), no self-collision (stage 4), no `RAG_ITERS` change, no
`coop_ragdollStiff` change, no spine/torso-twist limits, no `μ` code path, no brace-row deletion.

**Rollback:** `coop_ragdollLimits 0` — restores today's constraint set exactly, provided
`coop_ragdollTruss` is 1, which F8 now guarantees.

---

## 3. THE LIMIT TABLE AND ITS DERIVATION

### 3.1 The two body frames

Both are built from points that are rigidly attached to the same bone in *any* pose — the hip
sockets are the thigh-bone origins, the shoulder sockets are the upper-arm origins — so the
derivation is pose-independent and needs no bind pose.

```c
/* T rows = [F, L, U]. MOHAA convention, verified against AnglesToAxis (q_math.c:769-795):
   at yaw 0 axis[0]=(1,0,0) forward, axis[1]=(0,1,0) LEFT, axis[2]=(0,0,1) up. Right-handed
   in the order (F,L,U): F = LxU implies FxL = (LxU)xL = U(L.L) - L(L.U) = U. */
static qboolean RagBodyTriad(const vec3_t tip, const vec3_t base,
                             const vec3_t sockR, const vec3_t sockL,
                             float faceSign, float T[3][3])
{
    vec3_t U, L, F;
    VectorSubtract(tip, base, U);         if (VectorNormalize(U) < 0.001f) return qfalse;
    VectorSubtract(sockL, sockR, L);
    VectorMA(L, -DotProduct(L, U), U, L);                       /* Gram-Schmidt against U */
    if (VectorNormalize(L) < 0.001f) return qfalse;
    VectorScale(L, faceSign, L);
    CrossProduct(L, U, F);
    VectorCopy(F, T[0]); VectorCopy(L, T[1]); VectorCopy(U, T[2]);
    return qtrue;
}
```

| frame | tip | base | sockR | sockL |
|---|---|---|---|---|
| pelvis `T₀` | `pt[1]` Spine1 | `pt[0]` Pelvis | `pt[13]` R Thigh | `pt[11]` L Thigh |
| chest `T₂` | `pt[3]` Neck | `pt[2]` Spine2 | `pt[8]` R UpperArm | `pt[5]` L UpperArm |

`faceSign` is resolved **once, at capture**, from the entity axis (the corpse's facing at death;
it only has to be right to within 90°):
`s->faceSign[k] = (DotProduct(T[0], s->entAxis[0]) >= 0.0f) ? +1.0f : -1.0f;`

Both triads are rebuilt from the *current* points once per solver iteration (~60 flops each).
On failure — a degenerate spine or a hip/shoulder line parallel to it — **every limit in that
frame is skipped for that iteration** and `limbad++`. `RagBodyTriad`'s two `VectorNormalize`
guards are load-bearing, not insurance: nothing pins `pt[1]`'s azimuth about `pt[0]` once the
fold rows are gated off, so "parallel" is reachable in principle.

> **Note on `VectorNormalize`** (`q_math.c:2018-2033`): on the degenerate path it returns the
> **squared** length and leaves `v` unmodified. Every guard above compares against a small
> positive threshold, which is correct for both branches.

### 3.2 The sign chain — re-derived from scratch, because the design table is inverted

`RagSignedAngle(n₁, n₂, n) = atan2((n₁×n₂)·n, n₁·n₂)`. For `n₂ = R(n, θ)·n₁` with `n ⊥ n₁`:
`n₁×n₂ = sinθ·n` and `n₁·n₂ = cosθ`, so it returns `θ`, and

> **positive `φ` moves `b` toward `n × n₁`.**

Apply that to the four swing families, with `(F, L, U)` right-handed so `L×U = F`, `U×F = L`,
`F×L = U`:

| joint family | axis `n` | neutral `n₁` | `n × n₁` | positive `φ` means | anatomical range |
|---|---|---|---|---|---|
| hip flex/ext | `T₀[1]` = L | `−T₀[2]` = −U | `L×(−U) = −F` | **backward = EXTENSION** | flex 115°, ext 25° |
| shoulder flex/ext | `T₂[1]` = L | `−T₂[2]` = −U | `−F` | **backward = EXTENSION** | flex 170°, ext 60° |
| hip / shoulder abd/add | `T[0]` = F | `−T[2]` = −U | `F×(−U) = +L` | **toward LEFT** | see table |
| neck flex/ext | `T₂[1]` = L | `+T₂[2]` = +U | `L×U = +F` | **forward = FLEXION** | flex 55°, ext 50° |

**Therefore `ragdoll_joints_design.md:957-958`'s hip `[−25°, +110°]` grants 110° of *extension*
and 25° of flexion, and `:962-963`'s shoulder `[−60°, +170°]` grants 170° of extension.** Ship
those verbatim and hips swing 110° backwards. Both are inverted; both are corrected below.

Corroboration that this is a two-row transcription slip and not a misread of the whole
convention: the *abduction* rows, whose axis is `F` rather than `L`, come out **correct** —
`J8` L shoulder `[−20°, +150°]` is 150° of abduction (toward +L, away from the body for the
left arm) and `J9` R shoulder `[−150°, +20°]` is its mirror. Same for `J16`/`J17` at the hips.

**This is the single most valuable line in the round, and no instrument can see it.** No freeze
drill, no span, no drift, no spin metric detects a range inversion — the body simply settles
into a wrong-looking but constraint-legal pose. The derivation above ships as a comment block
directly over the table so the next session cannot re-invert it.

### 3.3 The hinge axis — neither the design's test nor the pure triad

The design's sign fix (`ragdoll_joints_design.md:496-508`) rotates `b₀` by +10° about
`h₀ = +unit(a₀×b₀)` and negates `h₀` if the child moves *away* from the grandparent. It never
fires. Proof: `|c−g|² = L1² + L2² + 2·L1·L2·cos φ`, so `d|c−g|²/dφ = −2·L1·L2·sin φ < 0` for
`φ ∈ (0°, 180°)`; and with `h₀ = +unit(a₀×b₀)` the signed angle from `a₀` to `b₀` about `h₀` is
`atan2(|a₀×b₀|, cos φ) = +φ`, so the probe *increases* `φ` and always shortens `|c−g|`. The
test is a **tautology in the bent branch** (correct, and inert) and a **coin flip on animation
noise in the straight branch**, where `sin φ₀ ≈ 0` kills the discriminant.

The pure medio-lateral rule (`h = ±T[1]`) fixes the sign but is wrong for an abducted arm,
whose elbow axis has rotated with the humerus.

**Adopted: analytic sign at capture, axis carried on the parent segment's own swing.**

```c
/* ---- capture, per hinge (g = grandparent, p = pivot, c = child) ---- */
VectorSubtract(pt[p], pt[g], aCap);  VectorNormalize(aCap);
VectorSubtract(pt[c], pt[p], bCap);  VectorNormalize(bCap);

/* SIGN: analytic, from anatomy, not measured. A knee flexes so the ankle goes BACKWARD:
   b ~ -U must rotate toward -F, and h x (-U) = -F requires h x U = +F = L x U, so h = +T0[1].
   An elbow flexes so the hand goes FORWARD: h x (-U) = +F requires h = -T2[1].
   Opposite signs are the anatomy, not a bug - knees hinge back, elbows hinge forward. */
VectorScale(T[frame][1], hSign, hCap);                 /* hSign = +1 knee, -1 elbow */
VectorMA(hCap, -DotProduct(hCap, aCap), aCap, hCap);   /* Gram-Schmidt: hCap _|_ aCap */
if (VectorNormalize(hCap) < 0.001f) { J->off = 1; }    /* thigh parallel to the body left axis */

/* VALIDATOR, not a source. If the limb IS bent at capture, the real flexion plane must agree
   with the anatomical rule; if it does not, this skeleton is not the one we reasoned about,
   so DISABLE this hinge's flexion limit for this corpse and print it. Never guess, never snap. */
CrossProduct(aCap, bCap, x);
if (VectorNormalize(x) > 0.342f /* sin 20deg */ && DotProduct(x, hCap) < 0.0f) {
    J->off = 1;  s->limOff++;
}
VectorCopy(aCap, J->aCap);
VectorCopy(hCap, J->hCap);

/* ---- solve, every iteration ---- */
VectorSubtract(s->pt[p], s->pt[g], a);  VectorNormalize(a);
RagMat3FromTo(J->aCap, a, R);            /* the PARENT segment's own swing since capture */
RagMat3RotateVec(R, J->hCap, h);         /* minimal rotation: |h| = 1 and h _|_ a, preserved */
VectorSubtract(s->pt[c], s->pt[p], b);  VectorNormalize(b);
phi = RagSignedAngle(a, b, h);           /* 0 = straight, + = flexion, defined even at a || b */
```

This is always defined (no `a×b` at solve time), its sign cannot be flipped by animation noise,
it rides the parent bone's swing exactly (`RagMat3FromTo` is the minimal rotation, so it adds no
twist and preserves the 90° between `hCap` and `aCap`), and it costs one `FromTo` plus one
mat-vec per hinge per iteration (~50 flops). It also makes the out-of-plane clamp well-posed —
`b·h` is identically zero if `h` is taken live from `a×b`, which is why the live cross product
cannot be used for it.

### 3.4 The final limit table — 18 limits

`kind`: **S** = swing (two per joint, one about `T[1]`, one about `T[0]`), **H** = hinge
flexion, **O** = hinge out-of-plane. `frame`: **P** = pelvis `T₀`, **C** = chest `T₂`.
`b = unit(pt[child] − pt[pivot])`. Moving set = `subtree(child)`. **`μ = 0` on all eighteen.**

| # | joint | kind | frame | pivot | grand | child | axis | neutral | **range** | moving set |
|---|---|---|---|---|---|---|---|---|---|---|
| L0 | neck flex/ext | S | C | 3 | – | 4 | `+T₂[1]` | `+T₂[2]` | **[−50°, +55°]** | {4} |
| L1 | neck lateral | S | C | 3 | – | 4 | `+T₂[0]` | `+T₂[2]` | **[−40°, +40°]** | {4} |
| L2 | L shoulder flex/ext | S | C | 5 | – | 6 | `+T₂[1]` | `−T₂[2]` | **[−170°, +60°]** | {6,7} |
| L3 | L shoulder abd/add | S | C | 5 | – | 6 | `+T₂[0]` | `−T₂[2]` | **[−20°, +150°]** | {6,7} |
| L4 | R shoulder flex/ext | S | C | 8 | – | 9 | `+T₂[1]` | `−T₂[2]` | **[−170°, +60°]** | {9,10} |
| L5 | R shoulder abd/add | S | C | 8 | – | 9 | `+T₂[0]` | `−T₂[2]` | **[−150°, +20°]** | {9,10} |
| L6 | L elbow flexion | H | C | 6 | 5 | 7 | `h`, `hSign = −1` | – | **[+2°, +150°]** | {7} |
| L7 | L elbow out-of-plane | O | C | 6 | 5 | 7 | `unit(b×h)` | – | **\|ψ\| ≤ 12°** | {7} |
| L8 | R elbow flexion | H | C | 9 | 8 | 10 | `h`, `hSign = −1` | – | **[+2°, +150°]** | {10} |
| L9 | R elbow out-of-plane | O | C | 9 | 8 | 10 | `unit(b×h)` | – | **\|ψ\| ≤ 12°** | {10} |
| L10 | L hip flex/ext | S | P | 11 | – | 12 | `+T₀[1]` | `−T₀[2]` | **[−115°, +25°]** | {12,15} |
| L11 | L hip abd/add | S | P | 11 | – | 12 | `+T₀[0]` | `−T₀[2]` | **[−15°, +55°]** | {12,15} |
| L12 | R hip flex/ext | S | P | 13 | – | 14 | `+T₀[1]` | `−T₀[2]` | **[−115°, +25°]** | {14,16} |
| L13 | R hip abd/add | S | P | 13 | – | 14 | `+T₀[0]` | `−T₀[2]` | **[−55°, +15°]** | {14,16} |
| L14 | L knee flexion | H | P | 12 | 11 | 15 | `h`, `hSign = +1` | – | **[+2°, +150°]** | {15} |
| L15 | L knee out-of-plane | O | P | 12 | 11 | 15 | `unit(b×h)` | – | **\|ψ\| ≤ 8°** | {15} |
| L16 | R knee flexion | H | P | 14 | 13 | 16 | `h`, `hSign = +1` | – | **[+2°, +150°]** | {16} |
| L17 | R knee out-of-plane | O | P | 14 | 13 | 16 | `unit(b×h)` | – | **\|ψ\| ≤ 8°** | {16} |

**Union of moving sets = `{4, 6, 7, 9, 10, 12, 14, 15, 16}`. Pivots = `{3, 5, 6, 8, 9, 11, 12,
13, 14}`.** Endpoints of the seven surviving braces = `{0, 1, 2, 3, 5, 8, 11, 13}`. The two sets
are disjoint — invariants **L1** and **L2** of §2/3b.

**Cut, and why.** `J1` spine1 flex/ext, `J2` spine1 lateral, `J3` torso twist. All three have
moving set `subtree(2) = {2,3,4,5,6,7,8,9,10}`, which contains `pt[5]` and `pt[8]` — endpoints
of the equality braces `{5,13}` and `{8,11}`, whose other endpoints are outside the set and
whose pivots (1 and 2) are neither. They fight the surviving truss at `μ = 0`, and at `μ > 0`
they additionally rotate `pt[0]`, `pt[1]`, `pt[11]` and `pt[13]` — three of `RagRawFit`'s four
inputs and the leashed pelvis. There is no `μ` for which they are safe. Also cut: all twist
limits (nothing generates twist under this construction, so nothing can violate one) and all
wrist/ankle limits (terminal bones with no simulated child).

### 3.5 DOF accounting — what the limits cover and what still holds the rest

```
17 points x 3                                    = 51
- 16 parent distance links (equality)            = 35
- 6 structural equality braces (rows 0-5)        = 29
- 6 rigid-body DOF                               = 23 INTERNAL
```

Enumerated by hand: the `{0,1,2,3}` group carries 3 links + braces `{0,2}` and `{3,1}` = 5 bars
on 12 DOF ⇒ 6 rigid + **1 internal**; the four sockets `{5,8,11,13}` carry 4 links + 4 braces
`{5,8}{11,13}{5,13}{8,11}` = 8 bars on 12 DOF ⇒ **4 internal**; the remaining 9 points
`{4,6,7,9,10,12,14,15,16}` each carry one link ⇒ 2 DOF each = **18 internal**. Total 23. ✔

The 18 limits cover exactly those last 18 — two per limb/neck direction. **The other 5 (1 spine
dihedral + 4 socket directions) are covered by NO limit and are held only by the six equality
braces.** That is why rows 0–5 are permanent, and it is the concrete mechanism by which the pile
would return if a later round "loosens the torso". Row 13 `{1,11}` adds a one-sided bound on the
lumbar DOF, which is why it survives the gate.

> **BUILD RULE.** Rows 0–5 never leave, in any build, ever. Any future proposal to soften the
> torso must first answer: *what holds the four socket directions?*

---

## 4. THE PRIMITIVE, THE ORDERING, AND THE ANTI-JITTER RULES

### 4.1 `RagLimit` and `RagRotateSet`

```c
/* Rotating the whole child SUBTREE rather than nudging one point is what makes this stable: a
   rigid rotation preserves every distance inside the set, so a limit can never fight a link it
   passes through, and the one link crossing the pivot is preserved too because the pivot is on
   the axis. */
static void RagRotateSet(ragSim_t *s, unsigned mask, const vec3_t pivot, const float R[3][3])
{
    int i;
    for (i = 0; i < RAG_PTS; i++) {
        vec3_t r, o;
        if (!(mask & (1u << i))) { continue; }
        /* NON-NEGOTIABLE: pt AND ptPrev by the SAME rotation about the SAME pivot. In Verlet the
           gap between them IS the velocity, so v' = R(pt-q) - R(ptPrev-q) = R(pt-ptPrev) = vR
           and |v'| = |v| EXACTLY: the joint stop is perfectly inelastic and the rotated velocity
           is tangent to it, so the limb slides ALONG the stop instead of re-violating it. Moving
           pt alone is the pattern that produced the "spassing and flying" blowup (see the
           RagShapeMatch burn at :941-946 and the impulse burn at :1381-1383). Never optimize
           the ptPrev line away. It also leaves the sleep meter's input (:1731-1735) untouched
           and cannot breach rag_velcap. */
        VectorSubtract(s->pt[i], pivot, r);      RagMat3RotateVec(R, r, o);
        VectorAdd(pivot, o, s->pt[i]);
        VectorSubtract(s->ptPrev[i], pivot, r);  RagMat3RotateVec(R, r, o);
        VectorAdd(pivot, o, s->ptPrev[i]);
    }
}

static void RagLimit(ragSim_t *s, const ragLimit_t *J, const vec3_t axis,
                     float phi, float lo, float hi, float k)
{
    float target = (phi < lo) ? lo : ((phi > hi) ? hi : phi);
    float d, R[3][3];
    if (target == phi) { return; }              /* inequality: project only when violated */
    d = (target - phi) * k;
    if (d >  RAG_LIMIT_MAX_STEP) { d =  RAG_LIMIT_MAX_STEP; s->limSat++; }
    if (d < -RAG_LIMIT_MAX_STEP) { d = -RAG_LIMIT_MAX_STEP; s->limSat++; }
    RagMat3FromAxisAngle(axis, d, R);
    RagRotateSet(s, J->mask, s->pt[J->pivot], R);
    s->limCount++;
    if (fabs(d) > s->limMax) { s->limMax = (float)fabs(d); }
}
```

`RagMat3FromAxisAngle` is a straight extraction of `RagMat3FromTo`'s existing row block
(`:498-511`) — already the verified row-vector Rodrigues form. Refactor `RagMat3FromTo` to call
it; its antiparallel branch (`:467-492`) then becomes `FromAxisAngle(anyPerp(a), M_PI)`.

**`RAG_LIMIT_MAX_STEP` is 12° and it is a primary limiter, not a belt.** A hand travelling at
the `rag_velcap` ceiling of 8 u/substep about an elbow **13.7 u** away — not the 25 u sometimes
quoted; the engine's own secondary hit-sphere offset for `Bip01 L/R Forearm` is 11.5
(`cm_trace_lbd.cpp:79-101`) and the measured forearm on these skeletons is in that band — opens
`8 / 13.7 = 0.584 rad = 33.4°` of new violation in one substep. The first iteration at
`k′ = 0.479` removes 16.0°, which is above 12°. **It will fire on a struck forearm, which is the
payoff case.** `limsat=` reports how often; if it saturates on more than ~20 % of impulse frames
the fix is a per-substep sub-clamp, not a bigger belt.

### 4.2 Ordering inside `RagStep`

```
1. integrate                          (unchanged: :955-973, Verlet, damping 0.98, velcap)
2. for it = 0 .. RAG_ITERS-1:         (RAG_ITERS stays 6)
     a. parent distance links, root -> leaf      :975-987   [equality]
     b. braces, fold rows gated off by 3b        :988-1010  [equality + row 13]
     c. rebuild T0 and T2 from current points               [~120 flops]
     d. the 18 limits, order REVERSED on odd 'it'           [inequality]
3. limp windows tick                  (unchanged: :1012-1019)
4. RagBodyRotationAdvance             (unchanged: :1020, the ONE filter advance)
5. RagShapeMatch                      (unchanged: :1021-1033)
6. ONE limit sweep                    <-- NEW (3d): the shape-match is not rigid
--- RagStep returns ---
7. RagCollideWorld                    (unchanged: :1639, per substep, LAST WORD)
```

**Nothing runs after collision.** Per-substep ordering ending penetration-clean is what
bug-1962 cost a live round to establish.

### 4.3 Stiffness, widening, and the four anti-jitter rules

**Stiffness** uses Müller 2007's iteration-count-independent transform so tuning survives an
`RAG_ITERS` change: `k' = 1 − powf(1 − k, 1.0f / RAG_ITERS)`. At `k = 0.98`, `RAG_ITERS = 6`:
`1 − 0.02^(1/6) = 1 − e^(−0.652004) = **0.4790**` (98 % of any violation removed per substep).
At `k = 0.50`: `1 − 0.5^(1/6) = **0.1091**`.

**Capture-time range widening** — the anti-pop rule. The authored death pose may already sit
outside a derived range. Snapping it in on frame 1 is a visible pop.

```c
J->lo0 = min(J->lo, capPhi - DEG2RAD(5.0f));
J->hi0 = max(J->hi, capPhi + DEG2RAD(5.0f));
/* per substep, on a NEW monotone counter: */
t  = (s->limAgeMs >= 300) ? 1.0f : s->limAgeMs / 300.0f;
lo = J->lo0 + (J->lo - J->lo0) * t;
hi = J->hi0 + (J->hi - J->hi0) * t;
```

**It must be `limAgeMs`, not `lifeMs`.** `lifeMs` is reset to 0 on impulse-wake (`:1546`) and
on mover-wake (`:1606`), so a corpse shot 30 s after death would re-widen its ranges to include
a *stale* capture value at the exact moment the limits are needed. `limAgeMs` increments in
`RagStep` and is never reset. One `int`.

**Failsafe:** if `capPhi` is outside `[lo − 30°, hi + 30°]` the derivation is suspect (odd
skeleton, hyperextended anim frame) — **disable that one limit for that corpse**, bump
`limOff`, print under `r_ragdollDebug 3`. Never snap.

**The four anti-jitter rules**, each mapped to its failure mode:

| failure mode | rule |
|---|---|
| the limit injects energy every step and the limb buzzes at the boundary | `RagRotateSet` moves `pt` **and** `ptPrev` — zero implied-velocity change, perfectly inelastic stop, velocity tangent to the surface |
| the axis flips near a degenerate configuration | the hinge axis is carried on the parent segment's swing from a capture value whose sign is analytic; no live `a×b` at solve time |
| the constraint activates and deactivates each iteration (chatter) | `k′ < 1`, plus `RAG_LIMIT_MAX_STEP`; if chatter is still visible, ramp `k_eff = k′ · smoothstep(0, 4°, \|violation\|)` |
| Gauss-Seidel order bias makes one side of the body stiffer | reverse the limit sweep order on odd iterations |
| redundant constraints fight | the ten fold rows are gated off in the same branch that turns the limits on — atomicity enforced at runtime |

**Cost.** Per substep: 17 integrations + 6 × [16 links + 7 braces + 2 triads + 18 limits] ≈
**35 k flops**; worst case 4 substeps × 8 sims ≈ **1.1 Mflop/frame ≈ 0.2–0.4 ms**. Traces rise
480 → 544/frame (world, budget-exempt) and the mover budget goes 240 → 272. Not a constraint.

---

## 5. PARAMETER TABLE

Every tunable, its value, and where it lives. **`CVAR_TEMP` unless noted.** Defaults are chosen
so that a fresh install behaves exactly as the stage intends with no console input.

| parameter | value | cvar | stage | notes |
|---|---|---|---|---|
| **`coop_ragdoll`** | **0** | `coop_ragdoll` (**`CVAR_ARCHIVE`**) | shipped | master. Stays dark until the look is signed off. |
| `coop_ragdollMode` | 1 | `coop_ragdollMode` | shipped | 0 off / 1 settle / 3 legacy free-fall. |
| `coop_ragdollStiff` | 0.25 | `coop_ragdollStiff` | shipped | shape-match alpha. F11 = 0.10, F1 = 0.50. |
| `coop_ragdollDrive` | 1 | `coop_ragdollDrive` | shipped | child-driven bone rotation. F10 = 0. |
| `coop_ragdollRotLock` | 1 | `coop_ragdollRotLock` | shipped | the spin latch. **Do not touch.** |
| `coop_ragdollSlew` | 0.12 | `coop_ragdollSlew` | shipped | orientation filter slew. **Do not touch.** |
| `coop_ragdollCarry` | 0.85 | `coop_ragdollCarry` | shipped | fraction of the shape-match pull banked into `ptPrev`. |
| `coop_ragdollVelCap` | 8 | `coop_ragdollVelCap` | shipped | u/substep. |
| `coop_ragdollLeash` | 128 | `coop_ragdollLeash` | shipped | pelvis-to-entity, u. |
| `coop_ragdollTruss` | 1 | `coop_ragdollTruss` | 3 | repurposed: stiffness scalar on the **surviving** rows only (`break` → `continue`). |
| `RAG_ITERS` | **6** | — | — | **Do not lower.** 4 costs +9 % peak link stretch against a 1.10 gate. |
| `RAG_DAMPING` | 0.98 | — | — | unchanged. |
| `RAG_SUBSTEP_MS` / `RAG_MAX_STEPS` | 8 / 4 | — | — | unchanged. |
| **Stage 1** | | | | |
| limp window scale | 1.0 | **`coop_ragdollLimpScale`** | 1 | **← SWEEP THIS.** Multiplies the caller's `limpMs`. 0 = no limp at all (per-item rollback). |
| limp floor | 0.05 | `coop_ragdollLimpRelax` | 1 | was `RAG_IMPACT_RELAX` (`:65`). |
| entity carry | 1 | `coop_ragdollCarryEnt` | 1 | 0 = today's behaviour (sim ignores the server toss). |
| teleport guard | 32 u/frame | — | 1 | above it, do not carry. |
| **Stage 2** | | | | |
| feet enabled | 1 | `coop_ragdollFeet` | 2 | 0 seeds `pt[15]=pt[12]`, `pt[16]=pt[14]` ⇒ byte-identical 15-point behaviour. |
| burial refusal | **5** | `coop_ragdollBuriedMax` | 2 | was a hard `4` at `:658`. |
| foot radius | 3.0 u | — | 2 | 0.50 × the engine's own `fLocRadius` 6.0; clearance-clamped per corpse at `:716-733`. |
| knee brace factor | **0.34** | — | 2 | derived: 140° flexion on 24.10 u / 23.94 u segments. |
| `RAG_MOVER_PER_BODY` | 60 → **68** | — | 2 | **ATOMIC** with `RAG_PTS 17`. |
| `RAG_TRACE_BUDGET` | 240 → **272** | — | 2 | **ATOMIC** with the above. |
| **Stage 3** | | | | |
| limits + fold gate | 1 | **`coop_ragdollLimits`** | 3 | the single atomicity authority. |
| net limit stiffness `k` | 0.98 | **`coop_ragdollLimitK`** | 3 | **← SWEEP THIS.** `k' = 1 − (1−k)^(1/6)`; 0.98→0.479, 0.50→0.109. |
| `RAG_LIMIT_MAX_STEP` | 12° | — | 3 | per-application clamp; report `limsat=`. |
| range widen | ±5° at capture | — | 3 | tightens over 300 ms on `limAgeMs`. |
| tighten window | 300 ms | — | 3 | |
| validator threshold | sin 20° | `RAG_HINGE_MIN_BEND` | 3 | below it, the capture is too straight to validate; the limit stays enabled on its analytic sign. |
| failsafe margin | 30° | — | 3 | outside it, disable that limit for that corpse. |
| elbow / knee OOP | 12° / 8° | — | 3 | |

> **The ONE cvar the user sweeps live, per stage:**
> **Stage 1 → `coop_ragdollLimpScale`** (0.5 / 1.0 / 2.0). It is the knob that decides whether a
> struck limb reads as *moved* or *twitched*, and it is the one this stage's fix makes
> meaningful for the first time.
> **Stage 2 → `coop_ragdollFeet`** (0 / 1). A direct A/B on the same corpse.
> **Stage 3 → `coop_ragdollLimitK`** (0.50 / 0.98). Trades jitter against how hard the stops hold.

---

## 6. ACCEPTANCE EVIDENCE, PER STAGE

Every stage starts the same way: **press F7 first.** The freeze drill arms the ragdoll with the
simulation frozen, so the pose the renderer draws must be the death pose verbatim. One kill:
he must look like a perfectly normal soldier, frozen mid-death. **Any warp, stretch, twist or
shrink means the render path broke and nothing else in the build can be judged — stop and
report.** From Stage 0 the drill runs on **mode 1**, the branch that actually ships (`:1982`
already supports it); before Stage 0 it ran on mode 3 and was testing a branch nobody uses.

> **Gate 0, before any visual verdict in any stage:** `settle-armed` count ÷ `pending-arm`
> count ≥ **90 %** over 20+ kills. If coverage moved, the build is a regression regardless of
> how it looks, and `s_ragNeverArm` (`:1721`) makes the loss permanent per corpse.

### STAGE 1 — full acceptance evidence

**Console keys, in order**

| key | file | what it does |
|---|---|---|
| **F8** | `rag_run.cfg` | reset. Now also seeds `Truss 1`, `RotLock 1`, `Slew 0.12`, `Carry 0.85`, `VelCap 8`, `Leash 128`, `LimpScale 1`, `LimpRelax 0.05`, `CarryEnt 1`. **Press this first, then F7.** |
| **F7** | `rag_drill.cfg` | freeze drill, now on `coop_ragdollMode 1`. One kill. Must look like a normal soldier. |
| **F8** | | back to the live settle test |
| — | console | `coop_ragdollLimpScale 0.5`, then `2` — same corpse, same grenade distance |
| — | console | `coop_ragdollCarryEnt 0` then `1` — isolates the entity carry |
| **F11 / F1** | `rag_soft` / `rag_firm` | stiffness 0.10 / 0.50 on a blasted body |
| **F10** | `rag_ab.cfg` | not exercised this stage |

**Log fields and required directions** (`r_ragdollDebug 1`; `developer 1` is required or the
prints are gated)

| field | line | today | **required after Stage 1** |
|---|---|---|---|
| **`entdrift=`** | sleep, blowup | *new* | **0–8 u** on a grenade kill with `CarryEnt 1`. If it reads > 40, the carry is not working. With `CarryEnt 0` it should read **large** (tens to hundreds) — that contrast IS the measurement. |
| **`limpmax=`** | sleep | *new* | equals the caller's window × `LimpScale`: **600–810** on rifle kills, **1200–1410** on grenades. Confirms the window reached the sim. |
| `reason=leash` | blowup | present on grenade kills | **zero** on grenade kills. |
| `reason=span` | blowup | occasional | **zero.** Any `span` blowup on a grenade kill means a second divergence source survives — **stop, return to design.** |
| `stretch=` | sleep-rot | 1.01–1.07 live | **≤ 1.15.** Above 1.30 ⇒ the negative alpha is still live somewhere. |
| `drift=` | sleep | 0.7–3.1 u quiet | quiet settles unchanged; a blasted corpse may peak higher and must come back down. A monotone climb is the divergence. |
| `maxspd=` | sleep | — | expected to **rise** on blast kills — that is the point — but the body must still sleep. Watch for bodies riding `life=6000`. |
| `spinmax=` / `yawf=` | sleep-rot | 0–3 deg/s, ~0 | **UNCHANGED.** Stage 1 touches nothing in the rotation filter; any movement here means the carry is not rigid. |
| `rot=` | sleep-rot | 0–28° | unchanged for quiet settles. |

**The visual verdict**

1. Kill a soldier on flat ground. Let him settle (watch for the `sleep` line). Throw a grenade
   3–5 feet away.
   - **PASS** — the body is thrown, the **limbs trail and flop independently of the torso**, and
     it comes to rest in a **new** pose that is visibly not the death pose.
   - **FAIL-A** — thrown but arrives rigid in exactly its death pose ⇒ the limp window is not
     reaching the shape-match. Check `limpmax=`.
   - **FAIL-B** — the body inflates, limbs splay to impossible lengths, or it "spasses" ⇒ a
     negative alpha survives. Check `stretch=`.
   - **FAIL-C** — the body does not move at all while the *bullets* still push it ⇒ the server
     toss and the sim have diverged and the carry is not working. Check `entdrift=`.
2. Kill a soldier. Empty a rifle magazine into **one arm**.
   - **PASS** — that arm swings about its shoulder and stays where it lands.
   - **FAIL** — the whole body slides. (This is the symptom `15a8f5c5` claims to have fixed and
     which has never been seen; if it is still present, Stage 1's fix is not the last one and
     Stage 2 must not proceed.)
3. `coop_ragdollLimpScale 0.5` then `2` on identical grenade kills. The limb motion should
   visibly **last longer** at 2 and **snap home sooner** at 0.5. If the two are
   indistinguishable, the limp path is not reaching the shape-match at all and the sweep has
   told you more than the fix did.

**The failure signature that returns the project to design**
Any of: `reason=span` on a grenade kill · `stretch=` > 1.5 · `entdrift=` > 60 with
`CarryEnt 1` · `spinmax=` above ~10 deg/s. Each means a mechanism this spec has mis-modelled,
and Stages 2 and 3 are built on Stage 1's assumptions.

**Rollback** — one command
`coop_ragdollCarryEnt 0` (item 1b) · `coop_ragdollLimpScale 0` (item 1a) ·
`coop_ragdoll 0` or `exec coop_mod/cfg/rag_off.cfg` (everything).

---

### STAGE 2 — acceptance evidence

**Gate 0 is the hard stop and it is checked BEFORE anything is looked at.** 20+ kills,
`settle-armed / pending-arm ≥ 90 %`. Watch also for `capture FAILED … reason=missing-tag`
(must be zero — 2e removes the path) and `capture BURIED` (must not rise; that is what
`coop_ragdollBuriedMax` exists for).

| field | required |
|---|---|
| `span=` | **re-baselined.** Full extension goes 48.04 u further down each leg; do **not** compare `span=`, `capspan=`, `drift=`, `stretch=` or `ctcmax=` against any round-10 number. Record fresh. `rot=` / `spin=` / `spinmax=` / `yawf=` / `rawbad=` **stay comparable**. |
| `stretch=` | ≤ 1.15. The two new links are the same class as the 14 already shipped. |
| `contacts=` / `ctcmax=` | up by ~2 (two new ankle contact spheres). |
| `worldtr=` | ≈ +13 % (480 → 544). |
| `spinmax=` | unchanged. |

**The visual verdict is DIRECTIONAL — watch the boots.**
- **PASS** — a shin that follows a step or a slope **while the thigh keeps its own angle**.
  Boots point where a boot should point.
- **FAIL — the new one this build can produce** — a **boot pointing back up the thigh**, i.e.
  the knee bending backwards. This is not a rendering artifact; it is a real configuration the
  17-point cloud permits and no stage-2 constraint forbids. It is what `L14`/`L16` close.
- **FAIL — the old one** — the calf still renders rigidly parallel to the thigh ⇒ `s_ragDriveChild`
  was not extended, or `driveOk[12]` is 0 because the foot tag did not resolve.

`coop_ragdollFeet 0` / `1` on the same corpse is the A/B.
**Rollback:** `coop_ragdollFeet 0`.

---

### STAGE 3 — acceptance evidence

| field | required |
|---|---|
| **`lim=`** | **> 0.** If it is zero across 20 kills, the limits never fired and the build answered nothing. |
| **`limmax=`** | should sit well under 12°. Persistently at 12° means a limit is fighting something. |
| **`limsat=`** | ≤ ~20 % of impulse frames. Above that, add a per-substep sub-clamp — do **not** raise `RAG_LIMIT_MAX_STEP`. |
| **`limoff=`** | should be **0** on standard soldiers. A non-zero count on every corpse means the hinge validator disagrees with the anatomical rule on that skeleton family. |
| **`limbad=`** | near 0. High means a body triad is going degenerate, i.e. the spine or a socket line is collapsing. |
| `stretch=` | **≤ 1.10.** This is the gate the `RAG_ITERS` decision was made against. |
| `spinmax=` / `yawf=` / `rot=` | **UNCHANGED from Stage 2.** Invariant L2 says they must be. If they move, a limit is touching `pt[0]/[1]/[11]/[13]` and the moving-set table is wrong. |
| `reason=leash` | **zero.** Invariant L2 again. |
| bodies sleeping | ≥ 90 % speed-sleep rather than riding `life=6000`. A limit cycle shows up here first. |

**The visual verdict**
- **PASS** — with `coop_ragdollStiff 0.10` (**F11**), the corpse is visibly looser than at 0.25,
  limbs drape and react — **and it does not pile.** No arm through the ribcage, no leg folded up
  behind the back, no knee bending backwards, no head folded onto the chest.
- **FAIL — the null result** — `coop_ragdollLimits 0` and `1` are indistinguishable at
  `Stiff 0.25`. That is a *real answer*: the shape-match at 0.25 already keeps the body inside
  every range, and the limits only earn their keep in the loose regime. Re-run at `Stiff 0.10`
  and `0.05` before concluding.
- **FAIL — buzz** — a limb visibly vibrates at a joint stop. Drop `coop_ragdollLimitK` to 0.50
  (`k' = 0.109`); if that fixes it, ship 0.50 and note that the smoothstep ramp of §4.3 is the
  proper fix.
- **FAIL — a limb locked straight or snapped to a wrong pose** — a hinge sign is inverted for
  that skeleton. `limoff=` should already have caught it; if it did not, the validator's
  `sin 20°` threshold is too high.

**Rollback:** `coop_ragdollLimits 0` — restores today's constraint set **exactly** (all 16 fold
+ equality braces active, no limits), provided `coop_ragdollTruss` is 1, which F8 now guarantees.

---

## 7. RISK REGISTER — top 5 by probability × impact

| # | Risk | P | Impact | Mitigation |
|---|---|---|---|---|
| **1** | **Stage 2 zero-fills a grown table.** `RAG_PTS 15→17` silently leaves `s_ragPtRadius[15]=0` (point trace in the pre-lift = bug-1962's pin), `s_ragDriveChild[15]=0` (foot driven ankle→pelvis), `s_ragBraceMinFactor[16]=0` (**equality** brace welding the ankle to the hip — which *looks exactly like the knee still doesn't bend*), or `s_ragBones[15].name=NULL` (**access violation** in `stricmp` inside `cgame.dll` on the first kill). | **High** without the guard | Silent wrong behaviour, or a client crash | **Item 2a, unsized tables + `sizeof` asserts, is the FIRST commit of Stage 2.** The obvious guard on a sized array is tautologically true and is worse than nothing. |
| **2** | **Stage 3 ships an inverted range or hinge sign.** No instrument can see it — the body settles into a wrong-looking but constraint-legal pose, and every metric reads normal. | **Medium** (it is inverted in the source design *today*) | Whole stage silently worthless; loud but confusing | §3.2's derivation ships as a comment block over the table; hinge sign is **analytic** from the triad, never measured; capture validator disables a disagreeing hinge and reports `limoff=`; `coop_ragdollLimits 0`. |
| **3** | **Stage 2 loses coverage.** `RagCapture:600-606` bails the whole capture on a missing `Bip01 L Foot`, and the burial gate at `:658` tightens with two burial-prone points added. A lost corpse is retired **permanently** by `s_ragNeverArm`. | **Medium** | Coverage falls from 97 % and nobody notices until the next session | **Never bail** (item 2e seeds `pt[15]=pt[12]` and lets `driveOk` fall to 0 on its own); `coop_ragdollBuriedMax` cvar; **Gate 0 checked before any visual verdict**; `coop_ragdollFeet 0`. |
| **4** | **Stage 3's limits fight the truss** → chatter, limit cycle, bodies that never sleep. | **Low–Medium** | Jitter, sleep-rate collapse | Proved disjoint: moving-set union `{4,6,7,9,10,12,14,15,16}` ∩ brace endpoints `{0,1,2,3,5,8,11,13}` = ∅ (§3.4); `μ = 0`; `k′` transform; reverse sweep on odd iterations; `RAG_LIMIT_MAX_STEP`; the fold rows are gated off in the **same branch**; `limsat=` / `limmax=` telemetry. |
| **5** | **Stage 1's entity carry translates the sim into geometry**, or is not rigid and re-opens the solved spin problem. | **Low** | Corpses inside walls; or a regression on the one thing that is finished | Rigid by construction (`pt` **and** `ptPrev` by the same delta ⇒ zero implied-velocity change); `goal[]` carried too; 32 u/frame teleport guard; per-substep collision still runs after; `spinmax=` is an explicit **must-not-change** acceptance field; `coop_ragdollCarryEnt 0`. |

**Two risks deliberately accepted and priced:** (a) Stage 2 makes a backwards-bending knee
reachable — accepted for one build, made visible by a directional acceptance test, closed by
Stage 3. (b) The shape-match banks 15 % of every pull as velocity (`:940` vs `:946`), and the
feet are the points furthest from the pelvis anchor (48.3 u vs the knees' 24.6), so their banked
energy per correction is up to ~2× a knee's — the same mechanism `coop_ragdollCarry` was written
to tame. Watch `maxspd=` and the sleep rate; `coop_ragdollCarry 1.0` makes the pull
velocity-neutral and is a free console experiment.

---

## 8. WHAT COMES AFTER — the earlier animation-to-physics handoff

> *"realistically when someone is shot and killed, the life comes out of their body.. they fall
> lifeless in one direction or another. of course physics does the rest (what direction, speed,
> how limbs are effected etc.)"*

Today the **authored MOHAA death animation owns the entire fall** and physics only drapes the
landed corpse. That was the right call — round 8 established that arming at the `EF_DEAD` edge
photographs a *standing* soldier, because the engine does not request the death anim until a
Think after the edge and then crossblends it in over 0.5 s. Moving the handoff earlier means
physics owns some of the fall, and a falling body has far more freedom than a settling one.

**What joint limits unlock.** A free-falling 17-point cloud held only by distance constraints
reaches configurations no body can occupy — that is precisely what produced eight rounds of
mangled piles, and it is why every earlier attempt at an earlier handoff failed. With the 18
limits plus the six permanent equality braces, **23 of 23 internal DOF are bounded** (18 by
limits, 5 by the truss), so the reachable set is anatomically closed. Physics can then be given
the fall without the fall being able to produce a heap. **This is the hard prerequisite and
nothing substitutes for it.**

**What it will still need — five things, none of them in this round:**

1. **A trigger earlier than `Actor::BecomeCorpse`, and it must still be a server *fact*, not a
   guess.** The current signal is exact: `RagServerParked` (`:1889-1897`) reads the corpse-slab
   bbox out of the 32-bit `entityState.solid` netfield, which proves both that the death anim
   completed and that `droptofloor` has parked the body. An earlier handoff needs an equally
   hard signal for *"the fall direction is committed"* — the honest candidate is a second bit
   set at `Actor::FinishedAnimation_Killed`'s **entry**, delivered the same way. Guessing from
   the anim name or a timer is the exact failure mode the settle branch exists to end.

2. **An initial velocity that is not a guess.** The free branch's snapshot differencing
   (`state == 0`, `CG_RagdollTransition:2049-2073`) was measured to be poor. The better source
   already exists: the server sends a bone-accurate impact position and inward normal to
   everyone in PVS, and `CG_RagdollImpulse` already consumes it. Seed the fall from the killing
   blow rather than from origin deltas.

3. **A falling regime distinct from the settling one.** `gravScale` ramping 0→1 over 250 ms
   (`:1625-1628`) and `RagShapeMatch`'s alpha ramp over 300 ms (`:1029-1031`) are both settle
   artifacts: they exist so the corpse does not twitch at a handoff that happens *at rest*. A
   handoff that happens **in motion** needs a cross-fade of the shape-match `goal[]` from the
   live animated pose toward a frozen one over ~150 ms — the "life goes out of it" moment,
   authored as a blend rather than a cut.

4. **Self-collision becomes required, not optional.** A settling corpse rarely drives a forearm
   through its own ribcage; a falling one will. The 16 min-distance pairs of
   `ragdoll_joints_design.md:722-762` are the right set, they use the same
   `RagRotateSet`-style absorption rule, and at 16 pairs × 6 iterations × 4 substeps = 384
   comparisons per body per frame they are free. Justify them on **mechanism** — those pairs
   are the only thing stopping a limb passing through the torso — never on the unverified
   minimum-compactness figure.

5. **The per-bone frame chain (`RagBuildFrames`), deliberately deferred here, becomes worth
   its risk.** A falling body twists; twist inheritance is what stops forearms, hands, shins and
   feet rendering rolled. It was left out of this round because it buys little now that
   `s_ragDriveChild` shipped and it puts risk on the render path that `coop_ragdollTest 2` is
   structurally blind to (with `S = I` the freeze drill cannot distinguish a correct frame chain
   from a wrong one). If it lands, it needs its own drill.

**And one thing that must be decided, not discovered:** the fall is currently *authored* — 30
direction- and hitloc-aware death animations, hand-made, and better-looking than anything a
15-point Verlet solver will produce for the first second. The goal is not to replace them. It is
to let physics take over at the moment the body stops *acting* and starts *falling*, and to make
that moment early enough that the fall reads as caused by the shot. That is a **timing**
decision as much as a physics one, and it should be tuned live on a cvar before any of it is
made permanent.

---

## APPENDIX A — verification log

Everything below was re-derived or re-measured in-session against HEAD, not carried from a
source document.

| claim | how verified |
|---|---|
| `AnglesToAxis` rows are (Forward, Left, Up), right-handed | `q_math.c:769-795`; at yaw 0 → `(1,0,0)/(0,1,0)/(0,0,1)` |
| `RagSignedAngle` positive ⇒ `n₁` toward `n×n₁` | expanded `n₂ = R(n,θ)n₁`; `n₁×n₂ = sinθ·n`, `n₁·n₂ = cosθ` |
| hip + shoulder flex/ext ranges inverted | `L×(−U) = −F` = backward; abduction rows checked and found **correct**, so it is a two-row slip |
| design's hinge sign test never negates | `d\|c−g\|²/dφ = −2·L1·L2·sin φ < 0` and the probe increases `φ` |
| knee axis `+T₀[1]`, elbow axis `−T₂[1]` | `h×(−U) = ∓F` with `L×U = F` |
| `Bip01 L Calf` origin **is** the knee | `tiki/tiki_skel.cpp:103-113` stores only `length` for IKELBOW/IKWRIST; `skeletor/skeletorbones.cpp:852-862` places the bone at `shoulder + upperLength·row0`; `:837-840` feeds the Foot's length into `m_lowerLength` |
| `S(12) ≡ S(11)` identically today | `driveDir0[11]` (`:762-766`) and `restDir[12]` (`:691-694`) are both `unit(pt[12]−pt[11])`; `RagPush:1286-1293` calls `RagMat3FromTo` with identical arguments |
| thigh 24.10 u, shin 23.94 u, "46 u" is centimetres | `scratchpad/spec_skd.py`; 13/13 full skeletons, IKELBOW 46.35 cm / IKWRIST 46.04 cm × `load_scale` 0.52 |
| feet + Toe0 present on every full skeleton | same sweep: 26/26 `(skd, side)` calf pairs, zero missing a Foot or a Toe0; `cm_trace_lbd.cpp:31-51` lists both feet |
| limp ramp goes negative | `:937` with `RAG_IMPACT_LIMP_MS 600` (`:66`) vs `1200+70n` (`cg_parsemsg.cpp:1867-1869`); `a < 0` for `limpMs > 631.6`, i.e. 568 ms ≈ 71 substeps |
| server tosses the corpse entity 121→441 u | `weaputils.cpp:3526-3550`, in-comment instrumented A/B at `:3502-3506`; `g_corpseImpulse` default 1 `CVAR_ARCHIVE` (`gamecvars.cpp:461`) |
| the ragdoll does **not** follow that toss | `RagPush:1257` + `:1319-1323` convert against `cent->lerpOrigin`, and the renderer recomposes with the same placement ⇒ exact cancellation |
| `RagSane` leash targets `\|pt[0] − lerpOrigin\|` vs 128 | `:1229-1236`, `s_ragNeverArm` at `:1721` |
| the truss experiment ran and returned negative | `15a8f5c5` commit message; `coop_ragdollTruss` present in the deployed DLL; gate at `:991-998` `break`s the whole loop |
| mover budget drops points 9-16 at 17 points | `allow = count + 60` (`:1154`), return at `:1179-1181`; 4 movers × 17 = 68 > 60 |
| `stricmp(NULL, …)` is an AV, not a graceful bail | `skeletor/bonetable.cpp:60-99` |
| `Q_clamp` assigns to arg 1 (a statement) | `q_shared.h:531` |
| `VectorNormalize` returns the **squared** length on the degenerate path | `q_math.c:2018-2033` |
| gl1 ≡ gl2 `tr_ragdoll.cpp`, no re-orthonormalisation | `diff` clean; matrix copy `:158-171`, offsets `:146-155` |
| all cgame APIs exist | `cg_public.h:103,122,171,173,177,187,295,383,406,407,408,409,453,454` |
| `k' = 1 − 0.02^(1/6) = 0.4790`; `1 − 0.5^(1/6) = 0.1091` | `e^(−0.652004)`, `e^(−0.115525)` |
| knee brace 0.34 ⇒ 140° flexion | `\|d\|² = 1153.9(1 − cos γ)`; γ=40° ⇒ 16.43 u; 16.43 / 48.04 = 0.342 |
| 0.75 would cap the knee at 82.8° | 48.04 × 0.75 = 36.03; `cos γ = (1153.93 − 1298.2)/1153.9 = −0.1250` ⇒ γ = 97.2° |
| 12° step clamp fires on a struck forearm | 8 u/substep ÷ 13.7 u = 0.584 rad = 33.4°; first iteration removes 47.9 % = 16.0° > 12° |
| HEAD is built and deployed | `G:\mohaa-gl2\cgame.dll` and the CMake Release output are both md5 `c692f6ea…`, 16:27, matching `15a8f5c5` at 16:27:23 |
