# Ragdoll twist inheritance — integration, blast radius, and the drill

Lens: **what it would take, and what it could break.** The math is assumed to work (a math-vet
already confirmed the frame chain reduces to today's push in the flat case). This document is
about the surgery: the exact diff, the five space invariants, the interaction with everything
that shipped today, the test that would catch the change's own failure, the rollback, and the
cost.

Everything below was re-derived against HEAD (`cg_ragdoll.c` 2909 lines, read complete), not
carried from the design documents. Where a design document and the code disagree, the code wins
and it is called out.

---

## 0. THE HEADLINE, BEFORE THE DETAIL

The design document (`ragdoll_joints_design.md:230-320`) proposes a rewrite: new capture fields
`W0[]`, `Lrel[]`, `uLocal[]`, `A_k`, `relW[ch]`; `relPos` re-based from the `rot0` basis to a
`W0` basis; `rot0`, `restDir`, `hipDir0`, `conj[]` and the pelvis special case all deleted; the
frame build run inside the substep loop. That is roughly 120 lines touched across the capture
path and the push path, ~5 KB of new state per corpse, and it lands on the render path the
freeze drill is structurally blind to.

**That rewrite is not necessary to get twist inheritance.** Written in delta form, the whole
chain collapses to a substitution inside `RagPush` with **zero capture-path changes and zero new
`ragSim_t` fields**:

```
W_i = L_i * W_p * S_i        (the doc's frame chain)
    = W0_i * W0_p^T * W0_p * D_p * S_i        with W_p = W0_p * D_p
    = W0_i * (D_p * S_i)
=>  D_i = D_p * S_i          the ONLY quantity the push needs
```

and the reference the swing is measured against becomes

```
fCand_i = driveDir0[i] * D_p     (the captured down-bone axis, carried on the parent's delta)
S_i     = FromTo(fCand_i, dNow_i)
```

because `uLocal[i] * (L_i * W_p) = driveDir0[i] * W0_i^T * W0_i * D_p = driveDir0[i] * D_p`.
`W0`, `Lrel`, `uLocal` and `A_k` are all algebraically eliminated. `relW[ch]` is eliminated too:
`mat[ch] = mat0[ch] * E * D_a * Enow^T`, which is today's `mat0[ch] * conj[a]` with
`conj[a] = E * D_a * Enow^T` — the identical shape to today's `E * S_a * Enow^T`
(`cg_ragdoll.c:1881-1882`).

Consequences of the delta form, each of which is a risk reduction:

| doc's form | delta form |
|---|---|
| `relPos` must move from the `rot0` basis to a `W0` basis (math-vet caveat 1) | **`relPos` never moves.** It is only ever used sandwiched as `relPos * rot0[a] * X` (`:1195` stores, `:1880`+`:1891` consume), so `rot0` cancels exactly and only `X` changes: `S_a` becomes `D_a`. |
| a 3x4 is passed where `float[3][3]` is expected (math-vet caveat 2) | **never arises.** The per-channel compose at `:1906-1911` stays an explicit element-wise loop writing `mat[ch][r][c]` for `c<3` only. `RagMat3MulTrans(a,b,out)` (`:504`) takes `float out[3][3]`; passing `mat[ch]` (`float[3][4]`) is an incompatible pointer type that MSVC accepts with C4133 and which would write at stride 3 into a stride-4 buffer, corrupting both the rotation and the translation column. Do not "simplify" into it. |
| new `s_ragFrameOrder[]` table | **not needed.** `s_ragBones` (`:74-96`) is already topologically sorted — every parent index is strictly less than its child's (verified for all 17). A plain `for (i = 0; i < RAG_PTS; i++)` is parent-first. |
| `RagMat3Ortho` declared MANDATORY (`ragdoll_joints_design.md:290-296`) | **optional.** Max chain depth is 5 (pelvis→spine1→spine2→upperarm→forearm→hand), and `D` is rebuilt from scratch every push — it is never persistent state, so there is no cross-frame accumulation. Inputs are exactly orthonormal (`RagMat3FromTo` output; `bodyRot` is re-orthonormalized through `RagTriad` at `:1288`). Worst-case drift ~5e-7. The doc's "mandatory" was written for a formulation that stored `W` across frames. |
| frame build inside the substep loop | **stays in `RagPush`,** which is a pure reader. See invariant 5 — this is the single largest risk reduction available. |
| ~5 KB new state per corpse (`relW[128][3][3]` alone is 4608 B, +74 KB across the 16-slot pool) | **0 bytes.** One 612 B stack array in `RagPush`. |

Everything from here on assumes the delta form.

---

## 1. THE DIFF, PRECISELY

**One file. One function. `cgame.dll` only** — `tr_ragdoll.cpp` (both renderers, byte-identical,
verified by `diff`) is untouched, `cg_public.h` is untouched, so there is no ABI change and no
`.exe`/`game.dll` pairing requirement.

### 1.1 Capture path (`RagCapture`, `:816-1203`) — NOTHING CHANGES

The capture path is busier than the design documents describe. It now does, in order:
channel-count walk (`:839-845`), `ForceUpdatePose` + per-channel `TIKI_Orientation` into `mat0`
(`:859-872`), sim-point tag resolution with the footless seed (`:874-903`), the buried-point
pre-lift (`:905-931`), the buried refusal (`:933-950`), the bind-pose check (`:952-964`), rest
lengths / rest directions / `rot0` (`:976-1000`), brace lengths (`:1001-1010`), per-point
collision-radius clamping (`:1012-1034`), `hipDir0` (`:1036`), the orientation-filter seed
(`:1041-1043`), `capSpan` (`:1045-1053`), **the 18 per-corpse joint-limit derivations**
(`:1056-1122`), **the drive directions** (`:1124-1138`), and the per-channel anchor assignment
(`:1140-1198`).

The delta form consumes only quantities this path already produces:

| needed | already captured at |
|---|---|
| `driveDir0[i]`, `driveOk[i]` | `:1124-1138` |
| `restDir[i]` (leaf / `coop_ragdollDrive 0` fallback) | `:993-999` |
| `rot0[i]` | `:978-984` |
| `relPos[ch]` in the `rot0` basis | `:1195` |
| `bodyRot` (the root delta) | seeded `:1041-1043`, advanced `:1244-1291` |
| parent table, already topological | `:74-96` |

**Zero lines change in `RagCapture`. Zero fields are added to or deleted from `ragSim_t`.**
This is what makes the rollback exact and mid-session (section 5).

### 1.2 Push path (`RagPush`, `:1819-1922`) — the whole change

Replace the sim-point loop at `:1855-1883`:

```c
    float D[RAG_PTS][3][3];                       /* + 1 declaration line, 612 B stack */

    for (i = 0; i < RAG_PTS; i++) {
        int    p = s_ragBones[i].parent;
        float  S[3][3], tmp[3][3];
        vec3_t dNow, ref;

        if (s->freezePose) {
            RagMat3Identity(S);
            RagMat3Identity(D[i]);
        } else if (p < 0) {
            RagBodyRotation(s, S);                /* pelvis: the filtered anatomical delta */
            memcpy(D[i], S, sizeof(S));           /* ... IS the root of the chain */
        } else {
            const float *ref0;
            int          dch = rag_drive->integer ? s_ragDriveChild[i] : -1;
            if (dch >= 0 && s->driveOk[i]) {
                VectorSubtract(s->pt[dch], s->pt[i], dNow);
                ref0 = s->driveDir0[i];
            } else {
                VectorSubtract(s->pt[i], s->pt[p], dNow);
                ref0 = s->restDir[i];
            }
            if (rag_chain->integer) {
                RagMat3RotateVec(D[p], ref0, ref); /* THE CHANGE: the reference rides */
            } else {                               /* the parent instead of being frozen */
                VectorCopy(ref0, ref);
            }
            if (VectorLength(dNow) < 0.01f) {
                RagMat3Identity(S);
            } else {
                VectorNormalize(dNow);
                RagMat3FromTo(ref, dNow, S);
            }
            if (rag_chain->integer) {
                RagMat3Mul(D[p], S, D[i]);         /* D_i = D_p * S_i  (row-vector order) */
            } else {
                memcpy(D[i], S, sizeof(S));
            }
        }
        RagMat3Mul(s->rot0[i], D[i], rotNow[i]);   /* was: (..., S, ...) */
        RagMat3Mul(E, D[i], tmp);                  /* was: (E, S, tmp)   */
        RagMat3MulTrans(tmp, Enow, conj[i]);       /* unchanged */
    }
```

Plus one cvar: `rag_chain = cgi.Cvar_Get("coop_ragdollChain", "0", CVAR_TEMP);` in `RagCvars`
(`:353-431`) and its `static cvar_t *` beside the other 19 at `:341-352`.

**Line count: ~14 added, 3 modified, 0 deleted, 1 function.** Nothing else in the file is
touched. The per-channel loop (`:1885-1912`) is untouched — it already reads `rotNow[a]` and
`conj[a]` and never learns that their meaning changed.

Verification of the substitution, both directions:

- **Rotation.** `mat[ch] = mat0[ch] * conj[a] = mat0[ch] * E * D_a * Enow^T`. With
  `D_a = W0_a^T W_a` this is `W0_ch W0_a^T W_a Enow^T = relW[ch] * W_a * Enow^T` — the doc's
  §3.5 push, exactly. With `D_a = S_a` it is today's line at `:1909-1910`, byte for byte.
- **Position.** `off = relPos[ch] * rotNow[a] = (rel * rot0[a]^T) * rot0[a] * D_a = rel * D_a`,
  where `rel` is the capture-time world offset from `pt[a]` to the channel origin (`:1194`).
  A vector rigidly attached to bone `a` transforms as `v -> v * D_a`. Correct by construction,
  and with `D_a = S_a` it is today's `rel * S_a`.
- **Aim.** `driveDir0[i] * D_i = driveDir0[i] * D_p * S_i = fCand_i * S_i = dNow_i`. The
  reconstructed bone axis lands exactly on the measured segment — the property that makes the
  runtime assertion in section 4 possible.
- **Twist purity.** `D_p^T D_i = S_i`, and `S_i` is minimal (`RagMat3FromTo`, `:556-607`), so the
  relative rotation across every joint has an axis perpendicular to the bone. **No joint can
  twist relative to its parent.** This is why the chain needs no twist limits — a genuine
  simplification, and specifically it does **not** want the torso twist limit that was reverted
  today (see section 3.9).

### 1.3 Instrumentation (separable, `rag_debug`-gated, ~40 lines)

Section 4 specifies what to print. It is the part that should ship **first**, and alone.

---

## 2. THE FIVE INVARIANTS

Each is stated with its file:line, what the delta form does to it, and — because this is how it
will actually be caught — **what a violation looks like on screen**.

### 2.1 Current-frame entity placement

- **Where:** `cg_ragdoll.c:1836-1837` (`cent->lerpOrigin` / `AnglesToAxis(cent->lerpAngles)`),
  consumed at `:1898-1901`. Capture placement lives separately in `s->entOrigin` / `s->entAxis`
  (`:855-856`) and is used only by `RagCaptureToWorld`/`RagWorldToCapture` (`:615-633`) and as
  `E` (`:1848`).
- **Verdict: PRESERVED, untouched.** The delta form changes only rotation deltas. Lines
  `:1894-1904` are not in the diff.
- **Hazard:** the doc's §3.5 rewrite deletes `conj[]` and the `E` factor; a careless
  implementation of it can reach for `s->entAxis` while reorganising, which is bug-1964 exactly.
  The delta form never opens that door because it keeps both `E` and `Enow` in the same
  positions in the same product.
- **On screen:** the mesh renders offset from its own simulated skeleton by every unit of
  post-capture entity drift — bodies slide forward, clip into rocks, sink through floors, while
  `r_ragdollDebug 2` skeleton dots (`:1924-1961`) sit correctly on the ground. That split
  (dots right, mesh wrong) is the diagnostic.

### 2.2 The `Ecap * S * Enow^T` conjugation

- **Where:** `E`/`Enow` built at `:1846-1851`, composed at `:1881-1882`, applied at
  `:1906-1911`.
- **Verdict: PRESERVED in form, `S` substituted by `D`.** The bone cache is model space and the
  renderer post-multiplies the entity axis; `D` is built from world point directions exactly as
  `S` was, so it lives in the same space and needs the same conjugation.
- **On screen:** a frame-mixing error is **invisible at yaw 0 and grows to ~120 deg of bone
  error at yaw 90 with a 90 deg swing** (bug-1963's measured figure). Limbs render rotated about
  the world vertical relative to where the joints are, so the mesh shears away from the dots
  while the dots stay correct.
- **Naming this now because nobody has:** `coop_ragdollTest 2` cannot test this invariant **at
  any yaw**. The drill freezes the corpse, so `E == Enow` and the sandwich collapses to identity
  regardless of the entity's heading. Invariant 2 has **no test today**. Section 4 fixes that.

### 2.3 The `load_scale` offset contract, split across two files

- **Where, half one:** `cg_ragdoll.c:860-863` — `mat0[ch][*][3] = TIKI_Orientation(...).origin /
  s->scale`, i.e. TIKI-orientation space with the *entity* scale divided out.
- **Where, half two:** `renderergl1/tr_ragdoll.cpp:146-157` (and gl2, byte-identical) —
  `cache[i].offset[k] = mat[i][k][3] / tiki->load_scale - load_origin[k]`, converting
  TIKI-orientation space to raw skeletor space because the skinner re-applies
  `load_scale * e.scale` afterwards.
- **Verdict: PRESERVED, both halves untouched.** The delta form changes the *value* of
  `mat[ch][*][3]` for anchored channels (because `off` now carries inherited twist), but not its
  *units* or its *frame*. `tr_ragdoll.cpp` does not need recompiling and must not be edited.
- **On screen:** a uniform ~52 % compaction of the whole skeleton into a pile on every human
  corpse, present from the very first push (human tikis carry `load_scale` 0.52). This one *is*
  freeze-visible and unmistakable — it is the one contract violation the existing drill catches.

### 2.4 The position / rotation path split

- **Where:** declared and justified at `:1822-1823`; position path `rotNow` at `:1880` consumed
  at `:1891`; rotation path `conj` at `:1881-1882` consumed at `:1906-1911`.
- **Verdict: PRESERVED, and this is the invariant most at risk.** The delta form feeds both
  paths from the same `D[i]` at `:1880-1881`, keeping them separate expressions. The doc's §3.5
  **merges** them into one `W` — mathematically fine, defensively worse: today a wrong position
  path and a wrong rotation path produce two *distinguishable* symptoms, and merging them
  destroys that.
- **On screen, if half-applied** (position gets `D`, rotation keeps `S`, or vice versa): the
  helmet is the canary. `"helmet"` anchors to sim 4 (`s_ragAnchorTable`, `:317`), so its origin
  is `pt[4] + rel * X` and its axes are `mat0[helmet] * E * Y * Enow^T`. With `X != Y` the helmet
  slides around the skull as the head rolls, or holds position while rolling independently of it.
  Same for `tag_weapon` on sim 10 (`:314`) — a rifle orbiting the hand rather than held by it.
- **On screen, if the split is merged and then broken:** everything moves and shears together
  and the symptom is just "mangled", which is the state five rounds of this project already
  burned on.

### 2.5 Per-substep collision ordering

- **Where:** `CG_RagdollFrame:2339-2350` — `subStart` snapshot, `RagStep` (`:2344`),
  `RagCollideWorld` (`:2345`), decrement; movers once per frame at `:2353`; `RagPush` **once, at
  the very end**, `:2543`.
- **Verdict: PRESERVED, and strengthened.** The delta form is a **pure reader of `pt[]`**. It
  writes no simulation state, so it cannot perturb the integrate → constraints → collide order
  that bug-1962 paid a live round for.
- **This is the single most important design decision in the whole change,** and it is where the
  design document must be overruled: `ragdoll_joints_design.md:236-238` says to run the frame
  build "once per substep, before the Gauss-Seidel iteration loop". Its reason was that the
  chain would supply joint axes to the limits. **That reason no longer exists** — the 18 limits
  that shipped today build their own axes from `RagLimitFrames` (`:1364-1368`) and the
  per-corpse `limACap`/`limHCap` captured at `:1103-1104`, and never ask for a bone frame.
  Moving the chain into the substep would put it upstream of the solver, where it could change
  point positions, and would forfeit both the exact rollback and the "existing numbers must not
  move" test in section 4.
- **On screen if violated:** bodies sink under the map, and buried points freeze and pin the
  corpse while the rest drapes onto it — the 21:47 pile.

---

## 3. INTERACTION WITH EVERYTHING THAT SHIPPED TODAY

All eight post-date the twist design. Each is judged on "does a frame chain change this
subsystem's behaviour, even if the math is right?"

### 3.1 The child-driven driver table (`s_ragDriveChild`, `:113-131`)

**Changed, load-bearing.** The chain does not replace the driver — it re-points its *reference*.
Today `RagMat3FromTo(s->driveDir0[i], dNow, S)` measures against a world direction frozen at
capture; with the chain it measures against `driveDir0[i] * D_p`, a moving one.

The consequence is bigger than the prompt's framing suggests. "A forearm can never roll" is
true, but the chain changes the rendered roll of **every one of the 16 non-root bones**, not
just the extremities. A bone that has followed its parent exactly now gets `S_i = I` and
`D_i = D_p`, where today it would have carried a full swing-from-capture and a completely
different roll. **The playtest verdict will be about the whole body**, and that must be said to
the user before he looks, or he will report "everything changed" as a defect.

### 3.2 The 17-point skeleton with feet (points 15/16, `:92-96`)

**Changed, and this is the strongest visual argument for the feature.** Feet are leaves
(`s_ragDriveChild[15] = [16] = -1`, `:129-130`), so they are driven by their incoming segment and
today freeze their roll at the death pose. A foot rolled 90 deg relative to its own shin is the
classic broken-doll read. With the chain `D_15 = D_12 * S_15` and the boot follows the shin.

Note the ordering dependency: this payoff **did not exist before today**. Until feet became sim
points, the calf rendered as a bit-identical copy of the thigh (`:97-100`), so there was nothing
below the knee to inherit anything.

Footless models and the `coop_ragdollFeet 0` rollback (`:877-879`, `:884-892`) seed the foot on
the knee, so `dNow` is degenerate, the existing guard at `:1877` gives `S = I`, and `D_15 = D_12`
— which is exactly right, and better than today's frozen `restDir`.

### 3.3 The 18 anatomical joint limits (`:139-142`, table `:700-720`, `RagLimitApply:1370-1408`)

**Interaction is one-way and beneficial, with one new failure mode.**

Beneficial: `RagRotateSet` (`:782-801`) rotates a child *subtree* rigidly about the pivot. A
rigid rotation carries the subtree's drive segments with it, so a knee correction now propagates
into the ankle's rendered roll instead of shearing it. Today a limit correction visibly twists
the shin's mesh away from the foot's.

New failure mode: **twist chatter amplification.** `RagLimitApply` can fire up to 18 times per
iteration, 6 iterations per substep, 4 substeps per frame, and it has a documented chatter
problem that the smoothstep ramp at `:1379-1386` only *reduces* ("sometimes the head kinda
stutters after being shot up"). Today a buzzing shoulder buzzes alone. After the chain, a
buzzing shoulder rolls the entire arm — forearm, hand, and every finger channel anchored to
them (`s_ragAnchorTable:305-306`). This is a motion-only defect, invisible to the freeze drill,
and it is the first thing the section 4 instrument must measure.

### 3.4 Self-collision (`RAG_SELF_PAIRS`, `:637-666`; called `:1578`, `:1600`)

**No direct coupling.** Push-apart moves `pt` and `ptPrev` by the same delta (`:659-663`), so it
is a clean position change the chain simply reads. Second-order only: separating a hand from the
chest changes the forearm's drive segment, hence `S_6`, hence the hand's roll — which is correct
behaviour, not a defect.

### 3.5 The sticky-damage goal rewrite (`RagShapeMatch:1318-1341`)

**No coupling — but a shared producer that must not be touched.** The rewrite expresses a struck
point in the body frame via `RagMat3TransRotateVec(S, rel, inv)` at `:1332`, where `S` is
`RagBodyRotation` — the *same* quantity the chain uses as `D_0`. The "ONE producer" rule at
`:1204-1206` exists because the push's pelvis orientation and the shape-match's goal frame must
never disagree. **The chain must consume `bodyRot` strictly read-only.** It must not switch its
root to `RagRawFit` (`:1217-1233`) to dodge the filter — that would silently re-open the
disagreement the rule forbids.

### 3.6 The impulse torque couple (`CG_RagdollImpulse:1963`, couple at `:2074-2098`)

**No coupling, and it hands us a free regression check.** The couple acts on `ptPrev` only; the
chain reads `pt`. More usefully, the swing instrument (`:2151-2166`, `swingMax`/`swingLast`)
measures the *angle between the bone's direction now and at impact* — a swing, not a twist. The
chain changes no point position, therefore **`swing=` must be bit-identical with the chain on
and off.** So must `drift=`, `span=`, `maxspd=`, `stretch=`, `contacts=`, `ctcmax=`, `lim=`,
`limmax=`, `limsat=`, `limoff=`, `limbad=`, `rot=`, `spin=`, `spinmax=`, `yawf=`, `rotlockAt=`
and `rawbad=` — every one of them is a function of the point cloud alone. That is a
motion-covering invariant the freeze drill can never supply, and it costs nothing.

### 3.7 The orientation filter and latch (`RagRawFit:1217`, `RagBodyRotationAdvance:1244-1291`)

**Changed, and this is the largest hidden cost of the feature.**

Today `bodyRot` — slewed at `coop_ragdollSlew 0.12`, latched by `coop_ragdollRotLock` once three
points contact the world (`:1268-1271`), held on a degenerate triad (`:1250-1252`), reset on
impulse (`:2216-2217`) and on mover-wake (`:2295-2297`) — is the rendered rotation of **one
bone**, the pelvis, plus the shape-match frame. Every other bone reacts instantaneously to the
point cloud.

After the chain, `bodyRot` is the root of **all 17**. Precisely:

- **Swing stays unfiltered.** Each `S_i` is still an instantaneous fit to the current segment, so
  limb *aiming* gains no lag. Good.
- **Roll becomes filtered, latched and slew-limited, body-wide.** `coop_ragdollSlew` and
  `coop_ragdollRotLock` change from pelvis-only knobs to whole-body roll knobs. A corpse that has
  latched has every bone's roll pinned to the latch instant while its swings keep moving; a
  corpse shot after latching clears the latch and all 17 rolls slew back together at 0.12 per
  substep, which may read as rubbery.

This is defensible — roll has no independent measurement, so filtering it is the right call —
but it is a real semantic broadening of two shipped cvars and it must be recorded, or a future
session will tune `coop_ragdollSlew` for the torso and be baffled by what it does to the hands.

### 3.8 NEW FAILURE MODE: the 180-degree reference flip

**This is the defect I would expect to ship if this goes in unmeasured.**

`RagMat3FromTo` (`:556-607`) has an antiparallel branch: when `|a x b| < 0.0001` and `a.b < 0`
it constructs a pi rotation about an arbitrary perpendicular chosen by a discrete argmin over
`a`'s smallest component (`:568-576`). That choice **jumps** as `a` varies continuously, and in
the whole neighbourhood of antiparallel the axis is nearly degenerate and swings wildly for tiny
input changes.

Today `a = driveDir0[i]` is *fixed*, so this is only reachable when a limb's own direction
reverses relative to the pose it died in — rare on a settling corpse. With the chain
`a = driveDir0[i] * D_p` is *moving*, and antiparallel becomes reachable whenever a limb stays
put while the torso rolls through 180 deg — which the existing `spinmax=` data says happens, and
which blast-tossed and free-branch corpses do routinely.

**On screen:** a hand or a boot snapping palm-up-to-palm-down in a single frame, repeatedly, for
no visible reason. Motion-only. Freeze-blind.

**Mitigation** (do not build it before measuring it): count frames where
`dot(fCand, dNow) < -0.95` per corpse as `flip=`. If it is ever non-zero in a live session, the
chain needs a fallback (`D_i = S_i` for that bone in that neighbourhood) before it can ship.

### 3.9 THE REVERTED TORSO TWIST LIMIT (bug-1981) — the standing instruction

The design document's chain has **two** roots: the pelvis triad *and* a chest triad
(`ragdoll_joints_design.md:255-260`), so that torso twist is simulated rather than inherited.
The delta form above deliberately uses **one root**. This is not a simplification for its own
sake:

- With a single root, `D_2 = D_1 * S_2` and `S_1`, `S_2` are pure swings, so the chest bone
  carries no twist of its own about the spine axis — exactly as today (`RagMat3FromTo` discards
  it). The chain adds nothing to the torso.
- With a chest root, `D_2` comes from the shoulder-line triad, and the point cloud's shoulder
  line **can wind around the spine axis without bound** — nothing in a distance-constraint model
  forbids it. That winding is currently invisible because the render path throws the twist away.
  A chest root would **make it visible**: corpses reading as twisted at the torso.

The bound for it is a torso twist limit. That limit was added on request, shipped, and reverted
within minutes (bug-1981): its moving set contains `pt[5]` and `pt[8]`, which are endpoints of
the equality braces `{5,13}` and `{8,11}` (`s_ragBraces`, `:135-137`); `RagRotateSet` moves `pt`
**and** `ptPrev` (`:790-800`) so it is energy-neutral, while the brace correction at `:1521-1524`
moves `pt` **alone** and therefore changes implied velocity in a Verlet integrator — a cycle that
pumps rotational energy until damping wins. The vetted design had already cut that limit for
exactly this reason. The comment block at `:797-812` is what remains of it, deliberately kept as
prose rather than dead code.

A chest root cannot itself pump energy (it is a pure reader), but it re-exposes the user-reported
symptom minus the spin, and the only thing that would bound it is the limit that cannot safely
exist. **Single root only. Do not add the chest triad root. If a future session proposes it,
this paragraph is the reason it was rejected.**

### 3.10 Incidental finding, unrelated to twist but adjacent to the diff

`cg_ragdoll.c:982` reads `s->mat0[s->simChan[i]]` unconditionally, but `simChan[i]` is set to
`-1` for a seeded foot (`:884-892`) — on a footless model **or on the documented
`coop_ragdollFeet 0` rollback path, which affects every corpse**. `mat0[-1]` is an in-struct
under-read of the 12 floats preceding `mat0` (`:192`), which are `entOrigin` (`:188`) and
`entAxis` (`:189`), so `rot0[15]`'s first row becomes the entity's **world origin** — magnitudes
in the hundreds or thousands.

It is currently unreachable in practice: no anchor-table row maps to sim 15/16 (`:305-312` route
feet to 12/14), self-anchoring cannot match `simChan = -1`, and the nearest-fallback (`:1178-1191`)
uses a strict `<` while scanning ascending, so a foot seeded exactly on its knee always loses the
tie to index 12. But the pre-lift (`:905-931`) and the radius clamp (`:1012-1034`) both run
*before* the anchor assignment and use different radii for 12 and 15 (`s_ragPtRadius`: 4.0 vs
3.0, `:290-297`), so a buried knee can separate them and break the tie. A channel anchored to 15
would then be positioned by `relPos * (garbage * D)` and fly thousands of units; `RagSane`
(`:1778-1817`) checks `pt[]`, not the pushed matrices, so nothing would catch it.

One-line fix, independent of this proposal: when `simChan[i] < 0`, copy `rot0[i]` from the seed
parent (12 or 14) instead of indexing with -1.

---

## 4. THE TEST GAP, AND THE DRILL I WOULD DEMAND

### 4.1 Why the freeze drill cannot help here

`coop_ragdollTest 2` (`:1867-1869`, armed at `:2714`/`:2884-2891`) sets `S = I` on every channel
and pushes the capture verbatim. In the delta form, freeze also gives `D_i = I` for all `i`, and
the two code paths emit **identical bytes**. That is a correctness property — but it means the
drill is structurally incapable of distinguishing a correct chain from a wrong one, exactly as
`ragdoll_r11_spec.md:1055-1059` predicted. Worse, section 2.2 established that the drill also
cannot test the `E`/`Enow` conjugation *at all*, because it freezes the entity too.

Two motion-only defects have already slipped past this drill (bug-1966's off-by-one bone driver,
bug-1964's capture-frame placement). The chain would be the third of that class. **A drill is
required as a condition of the change, not as a follow-up.**

### 4.2 SHIP THE MEASUREMENT FIRST — one session, zero visual risk

This is the recommendation. Build the instrument with `coop_ragdollChain` defaulting to **0**,
so `D[]` is *computed* and *reported* but never *applied*. The shipping visuals are byte-for-byte
today's. The user plays one session, kills things, and the log answers "is this worth building"
from live data before a single pixel moves.

Per corpse, accumulate during the push (all `rag_debug`-gated, all peak-hold):

| field | definition | what it decides |
|---|---|---|
| `rollmax` | max over bones of `angle(S_i^T * D_i)` — the roll the chain would add | **the go/no-go number.** `S_i` is what ships today, `D_i` is what would ship; the angle between them is exactly the visual delta |
| `rollhand`, `rollfoot` | the same, restricted to sims 7/10 and 15/16 | the extremities are where twist is legible; a torso-only number is not a reason to ship |
| `rollrate` | max per-frame change in any bone's roll, deg/frame | **section 3.3's chatter amplification.** > ~20 deg/frame means the chain is amplifying limit buzz |
| `flip` | frames with `dot(fCand, dNow) < -0.95` | **section 3.8's 180-degree flip.** Any non-zero value blocks the ship |
| `aim` | max `angle(driveDir0[i] * D_i, normalize(pt[child] - pt[i]))` | must be ~0 by construction; non-zero means the chain is mis-built |
| `perp` | max `|dot(axis(D_p^T D_i), fCand_i)|` | **the discriminating assertion.** `D_p^T D_i` must be a *pure swing*: its axis perpendicular to the bone. An order slip (`S_i * D_p` instead of `D_p * S_i`) preserves the rotation *angle* — conjugation does — so an angle check passes and only this axis check fails |
| `ortho` | max `\|D_i D_i^T - I\|` | float drift and bad multiplies; expect < 1e-6 at depth 5 |
| `ptsum` | checksum of `pt[]` + `ptPrev[]` taken before and after `RagPush` | **non-perturbation.** Any mismatch prints `TWIST PERTURBED` and means the change has leaked into the simulation, which invalidates the rollback |

Emitted as one line beside the existing sleep-rot print (`:2528-2537`):

```
^~^~^ RAGDOLL twist ent=%d rollmax=%.0f rollhand=%.0f rollfoot=%.0f rollrate=%.0f
      flip=%d aim=%.4f perp=%.5f ortho=%.6f ptsum=%s chain=%d
```

**Stated decision rule, before the data arrives, so it cannot be rationalised afterwards:**

- ship if `rollhand`/`rollfoot` exceed ~25 deg on a meaningful fraction of corpses, **and**
  `rollrate` stays under ~20 deg/frame, **and** `flip` is 0 across the session;
- **do not ship** if `rollmax` is under ~10 deg — the feature would be invisible and the
  blast radius in section 3 is not worth an invisible change;
- do not ship if `flip` is ever non-zero — build the neighbourhood fallback first.

### 4.3 The drill for the session that flips it on

If 4.2 justifies the change, the enabling session runs a drill the freeze drill cannot be:

1. **Single-corpse live A/B.** Because there is **no capture-path change**, `coop_ragdollChain`
   toggles on an *existing* corpse. The user stands over one body, presses a bound key, and
   watches the same corpse under both behaviours. That is a *motion* A/B on one subject, not a
   static pose comparison.
2. **What the user must be told to look at, explicitly:** the hands and the boots. On `0`, a dead
   man's palms and soles point wherever they pointed at the instant the server parked him, and
   never change no matter how the arm or leg moves. On `1` they follow the forearm and the shin.
   If **nothing** changes on toggle, the patch is inert — a wiring bug. If the **whole body
   jumps**, the patch has leaked into the sim and `ptsum` will already have said so.
3. **The number-identity check.** Every existing sleep-print metric (`drift=`, `span=`,
   `maxspd=`, `swing=`, `stretch=`, `contacts=`, `ctcmax=`, `lim=`, `limmax=`, `limsat=`,
   `limoff=`, `limbad=`, `rot=`, `spin=`, `spinmax=`, `yawf=`, `rotlockAt=`, `rawbad=`) must be
   statistically identical across the toggle, because all of them are functions of the point
   cloud alone (section 3.6). Any drift in them is proof the change is not a pure reader.
4. **A non-axis-aligned corpse.** At least one kill on a soldier facing roughly 45 deg. Invariant
   2.2 is invisible at yaw 0 and has no test at all today; a corpse at an oblique heading is the
   only way an `E`/`Enow` slip becomes visible, and it should be an explicit instruction rather
   than luck.
5. **A shot corpse after it has latched.** Section 3.7's broadened latch is only observable here:
   shoot a settled body and watch whether all 17 bones' rolls slew back together (rubbery) or
   read naturally.

---

## 5. THE ROLLBACK

**Yes — provably byte-for-byte, and mid-session on existing corpses.**

The delta form's `rag_chain 0` branches take the identical operations in the identical order on
the identical inputs: `ref` is a value-copy of `ref0`, `D[i]` is a `memcpy` of `S`, and the two
composes at `:1880-1881` receive the same matrix they receive today. Same floats, same order,
same result. Not "equivalent" — identical.

The important part is what does **not** change: **`RagCapture` is untouched, and `ragSim_t` gains
no fields.** So the usual caveat — "a cvar toggled mid-session applies to NEW corpses only" —
**does not apply here.** Every corpse in the pool, including ones armed minutes earlier, flips
behaviour on the next frame's push. That is what makes drill 4.3.1 possible.

Contrast with the doc's form, where this would *not* hold: re-basing `relPos` into the `W0`
frame is a capture-time change, so a mid-session toggle would apply the wrong basis to
already-captured corpses. `off` would pick up a spurious `E` factor (`rel * E * S` instead of
`rel * S`) — invisible at yaw 0, catastrophic elsewhere. Storing both bases to allow the toggle
would double the `relPos` array. Another reason the doc's form should not be built.

**Name the cvar `coop_ragdollChain`, not `coop_ragdollTwist`.** `coop_ragdollTwist` was the
reverted torso-limit's cvar (bug-1981); reusing the name would make an old autoexec or the user's
muscle memory silently disable a different feature, and would make the buglog read as though the
chain were the thing that was reverted.

Default `0` for the measurement session (4.2), flipped to `1` only after the numbers justify it.

---

## 6. COST

Re-derived, not asserted. Flop counts from the helpers as written: `RagMat3Mul` /
`RagMat3MulTrans` = 27 mul + 18 add = 45 (`:483-515`); `RagMat3RotateVec` = 9 mul + 6 add = 15
(`:540-546`); `RagMat3FromTo` ~60 incl. one sqrt and three divides (`:556-607`);
`VectorNormalize` ~13.

| | today | with chain |
|---|---:|---:|
| per sim bone (17) | 208 | 268 (non-root) |
| per channel (72) | 90 | 90 (unchanged) |
| **per push, one corpse** | **10,016** | **10,976  (+9.6 %)** |
| **per frame, 16 corpses** | **160,256** | **175,616  (+15,360)** |

At 60 fps that is +0.92 MFLOP/s of scalar float work for the entire pool. Put against what the
ragdoll already spends per frame at 16 corpses:

- `RagCollideWorld` runs per substep over all 17 points: 17 x 4 x 16 = **1088 `CM_BoxTrace`
  calls per frame** (`:1683-1725`; world traces are budget-exempt by construction, `:1707-1709`).
- movers add up to `RAG_TRACE_BUDGET` 272 more (`:64-65`).
- the solver runs 6 iterations x 4 substeps of 16 links + 18 braces + an 18-limit sweep + 16
  self-collision pairs per body.

**A single `CM_BoxTrace` costs more than the entire twist chain for all 16 corpses.** The chain
is roughly 0.2-0.5 % of the ragdoll's existing per-frame cost, and RagPush as a whole is a small
fraction of it.

Memory: **zero** added to `ragSim_t` (the 16-slot pool is ~11.5 KB per slot, ~184 KB total, and
stays exactly that). Stack: `D[17][3][3]` = 612 B in `RagPush`, whose frame already holds
`rotNow` (612) and `conj` (612); `mat[128][3][4]` is `static` (6 KB, `.bss`) and unchanged. For
contrast, the doc's `relW[RAG_MAX_CH][3][3]` would have added 4608 B per slot = **+74 KB** to the
pool for a quantity that is algebraically eliminable.

---

## 7. VERDICT

**Buildable, small, and cheap — but only in the delta form, only single-rooted, and only after
the number in 4.2 says it is visible.**

The surgery is 14 added lines in one function of one file, `cgame.dll` only, no capture change,
no renderer change, no ABI change, and a rollback that is byte-for-byte exact and applies to
corpses that already exist. All five space invariants are preserved by construction, and one of
them (per-substep collision ordering) is *strengthened*, because keeping the chain in `RagPush`
makes it a provable pure reader — which in turn is what makes the "every existing metric must be
bit-identical" test possible.

Against that: it changes the rendered roll of every bone, it broadens two shipped cvars from
pelvis-only to body-wide, it can amplify joint-limit chatter down a limb, and it opens a
180-degree reference-flip neighbourhood that does not meaningfully exist today. All four are
motion-only and all four are invisible to the only drill that exists. That is precisely the
profile of the two defects that already shipped past that drill, and of the torso twist limit
that shipped and was reverted the same session because an existing analysis was not re-read.

So the recommendation is not "build it" or "don't". It is: **build the instrument, keep the
default off, and let one session of live corpses decide.** If `rollhand`/`rollfoot` come back
under 10 degrees, this is an invisible change with a real blast radius and the answer is no.
