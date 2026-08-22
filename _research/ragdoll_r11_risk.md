# Ragdoll round 11 — RISK, STAGING AND ACCEPTANCE

**Lens:** what can re-break, in what order to find out, and what evidence closes each question.
**Date:** 2026-08-20. **Subject:** `openmohaa-hzm/code/cgame/cg_ragdoll.c` (2142 lines, read
complete and current), renderer bridge `renderergl1/tr_ragdoll.cpp` ≡ `renderergl2/tr_ragdoll.cpp`
(196 lines, byte-identical, last touched `902d2cd5`).
**Prior art:** `ragdoll_joints_design.md` (the 21-limit design), `ragdoll_r9_spec.md` (round 10),
`ragdoll_r9_impact.md` (impulses, shipped), `ragdoll_pile_findings.md`, `ragdoll_r8_spec.md`,
`.wolf/buglog.json` bug-1962 … bug-1975.

Every number below is re-derived from the source or measured from
`G:\mohaa-gl2\home\maintt\qconsole.log` (the LIVE homepath log, 14 729 lines, 83 `RAGDOLL` lines,
session 2026-08-20 16:00:31 – 16:03:03). Where this document and an older one disagree, this one
was read off the code and the log.

---

## 0. THE FINDING THAT CHANGES THE ROUND

**The observations that justify this project were taken on a build in which every grenade turns
the pose attractor into a pose *repeller*.**

`RagShapeMatch` eases the struck-limb relaxation back in with (`cg_ragdoll.c:926-931`):

```c
if (s->limpMs[i] > 0) {
    float k = 1.0f - (float)s->limpMs[i] / (float)RAG_IMPACT_LIMP_MS;   // :66  == 600
    a *= RAG_IMPACT_RELAX + (1.0f - RAG_IMPACT_RELAX) * k;              // :65  == 0.05
}
...
VectorSubtract(want, s->pt[i], d);        // :922   d = want - pt
VectorMA(s->pt[i], a, d, s->pt[i]);       // :932   pt += a*d
VectorMA(s->ptPrev[i], a * rag_carry->value, d, s->ptPrev[i]);   // :938
```

`k` is only in `[0,1]` when `limpMs ≤ 600`. The shipped call sites pass more than that:

| call site | force | radius | `limpMs` | `k` | shape-match factor | effective `a` at `stiff 0.25` |
|---|---:|---:|---:|---:|---:|---:|
| `cg_parsemsg.cpp:1808/1820/2232/2244`, `iLarge 0` | 150 | 15 | **600** | 0.00 | +0.050 | **+0.0125** ✔ |
| same, `iLarge 1` | 220 | 16 | **670** | −0.117 | −0.061 | **−0.0153** ✘ |
| same, `iLarge 3` | 360 | 19.5 | **810** | −0.35 | −0.283 | **−0.0707** ✘ |
| `cg_parsemsg.cpp:1867`, grenade | 400 | **180** | **1200** | **−1.00** | **−0.900** | **−0.2250** ✘ |
| same, tank shell | 460 | 345 | 1410 | −1.35 | −1.233 | −0.3083 ✘ |

A negative `a` moves `pt` **away** from `want` by a fixed fraction every substep. Because `want`
is the rigid authored pose anchored at `pt[0]` (`:919-921`), pushing all 14 slaved points away
from their own targets simultaneously is a *coherent* divergence: the distance links resist the
scaling mode, so what survives is a rigid drift of the whole cloud relative to its goal frame,
and the goal frame chases it (it is anchored to `pt[0]`, which the links drag along). That is a
runaway translation, and the net that catches it is the pelvis leash.

**It is not a hypothesis. It is in the log:**

```
16:01:05  RAGDOLL impulse ent=148 force=400 radius=180 limp=1200
16:01:11  RAGDOLL impulse ent=148 force=400 radius=180 limp=1200
16:01:11  RAGDOLL blowup ent=148 reason=leash life=5316ms stretch=2.18 spinmax=8.2 - reverting to anim pose
```

The same body had already absorbed three `limp=670` rifle rounds and slept twice at
`stretch=1.04`. Two grenades took it to **stretch 2.18** — against a session-wide healthy range
of **1.01–1.09** — and past the 128 u leash. `RagSane` then set `s_ragNeverArm[148] = 1`
(`:1687`), so that corpse can never ragdoll again this map. Both blowups in the session were
`reason=leash`; there were 2 blowups against 8 arms.

**And the sub-threshold version of this is the user's exact sentence.** A grenade at
`radius 180` limps *every* point of *every* corpse within 180 u (`:1500`, `k > 0.15`), then
repels all of them from their targets in lockstep. "They get thrown up slightly and moved but
still kind of as a whole body" is a description of a coherent whole-cloud drift — which is what a
uniform negative alpha produces, and is the *opposite* of what the limp mechanism was written to
produce.

Cost to fix: clamp `k` to `[0,1]`, or store the window per point so the ramp divides by the
window that was actually granted. **1–3 lines.**

The consequence for this project is not that the limits are wrong. It is that **the evidence
base is contaminated**, and the first build of round 11 should be the one that de-contaminates
it. Everything else in this document is written on the assumption that S0 (below) has landed and
the user has looked at grenades again.

---

## 1. REGRESSION SURFACE

### 1.1 The five invariants

For each: what round 11 would have to touch to break it, and the test that proves it did not.

| # | Invariant | Site | Does the limits project touch it? | What would break it | Proof it did not |
|---|---|---|---|---|---|
| **I1** | **Current-frame entity placement.** `RagPush` converts world→model against `cent->lerpOrigin` / `AnglesToAxis(cent->lerpAngles)` **every frame**, never the capture placement | `:1242-1243`, consumed `:1302-1308` | **No — and it must not.** Limits move `pt[]`; they never enter `RagPush` | Any "optimisation" that caches the placement, or the joints design §3.5's proposal to move `relPos` into a world frame and delete the `conj[]` sandwich | Freeze drill (F7): the mesh must sit exactly on the corpse. bug-1964's signature is mesh sliding/sinking while the debug dots (`r_ragdollDebug 2`, `:1549-1551`) stay correct |
| **I2** | **`conj = Ecap · S · Enow^T`.** The channel rotation is `chRot0 · conj[anchor]` | `:1287-1288`, consumed `:1313-1318` | **No.** Only the *content* of `S` changes, and only for bones 12/14 if feet ship | Deleting `rot0`/`conj` for a bone-frame chain (joints design §3.4-§3.5). That is a rewrite of the exact code that carried bug-1963's 120° frame mismatch and bug-1964's wrong-side composition | Freeze drill **plus** a yaw sweep: kill four AI facing 0/90/180/270 in the same world configuration. A frame-mismatch bug is yaw-dependent by construction and invisible at yaw 0 |
| **I3** | **`load_scale` offset contract.** `R_RagdollApplyToCache` writes `offset[k] = mat[i][k][3] / load_scale − load_origin[k]`, and copies `matrix` with **no** re-orthonormalisation | `tr_ragdoll.cpp:146-171` | **No.** No renderer change. `git log ff57cdff..HEAD` over the four renderer files is empty and must stay empty | Any push of a non-orthonormal 3×3. Today `S` comes from `RagMat3FromTo` (`:449-504`), which is orthonormal by construction. A *composed* frame chain is not, and the renderer will not fix it | Freeze drill catches a shear immediately. If anything ever composes matrices, `RagMat3Ortho` on every pushed frame becomes mandatory, not optional |
| **I4** | **Position path / rotation path split.** `relPos[ch]` is stored against the **rows of `rot0[anchor]`** (`:811`), so the position path must use `rotNow = rot0 · S` (`:1286`) — the `rot0` cancels exactly. The rotation path uses `conj` | capture `:811`; use `:1286`, `:1297-1298` vs `:1287-1288`, `:1313-1318` | **No** — unless someone "simplifies" one of the two paths | Changing `relPos`'s storage frame without changing `rotNow` in the same edit, or vice versa. The two are a matched pair and there is no compile error if they diverge | Freeze drill (`S = I` makes both paths trivially agree — **so the drill is blind here**). The real test is the yaw sweep plus `r_ragdollDebug 2`: dots forming a body while the mesh separates from them is the I4 signature |
| **I5** | **Per-substep collision ordering.** integrate → constraints → *(advance filter)* → shape-match → `RagCollideWorld` | `RagStep` `:942-1019`; loop `:1599-1608` | **Yes — this is the one the project actually touches.** Limits insert a new constraint class into `RagStep` | Placing limits **after** `RagCollideWorld`, or moving collision back out of the substep (bug-1962's sink-under-the-map) | `contacts=` / `ctcmax=` must not fall; no body may sink. See §1.4 |

**I5 in detail — the ordering defect the limits will inherit.** Nothing re-enforces *any*
constraint after `RagShapeMatch`, which is the last writer of `pt[]` before collision
(`:1006-1018`, then `:1605`). The shape-match applies **three different alphas** to different
points in the same frame — full `0.25`, contact-relaxed `×0.15` (`:923-925`), limp-relaxed
(`:926-931`) — so a mixed pull across one bone changes that joint's angle arbitrarily. This is
already the leading suspect for `stretch=`; it will be *exactly* the same suspect for limit
violation. **If the limits are placed inside the Gauss-Seidel loop only, the shape-match will
re-violate them every substep and they will be measurably weaker than designed.** The fix is one
limit pass (and, per the round-10 roadmap's R-2, one distance pass) after `RagShapeMatch` — ~8
lines — and it must be in the same build as the limits or the limits are not being tested.

### 1.2 Coverage (bug-1969, 22 % → 98 %) — **the highest-impact regression path, and it is reachable**

The prompt says this project "should not touch the pending/server-park path at all". Agreed, and
that is enforceable: `RagPendingThink` (`:1870-1973`), `RagServerParked` (`:1855-1864`) and
`CG_RagdollTransition` (`:1996-2142`) must have **zero diff**. But coverage is not decided only
there — `RagCapture` has **five** `return qfalse` paths (`:546-551`, `:560-565`, `:591-598`,
`:639-657`, `:661-670`) and it is on the arm path. The feet stage touches two of them:

1. **New required tags.** `:591-598` bails the whole capture if any `s_ragBones[]` name is
   missing. Adding `"Bip01 L Foot"`/`"Bip01 R Foot"` to that table makes them *mandatory*. The
   design's evidence (39/39 humanoid SKDs; the engine's own 19-name hitloc table) is good, but
   the failure mode is silent and total — one imported skeleton without a foot bone and that
   whole model class stops ragdolling. **Requirement: feet must be optional.** On a missing foot
   tag, fall back to the 15-point roster for that corpse (`s->nPts = 15`) rather than bailing.
   The file's own comment at `:597` already says "a miss = bail clean" — that reasoning was
   correct when every name was already verified; it is not correct for a *newly added* name.

2. **The buried refusal is an absolute count, and feet are the most-buried points.** `:639-657`
   refuses to arm when `nTorso > 0 || s->buried >= 4`. The pre-lift comment at `:606-609` says
   in so many words that "death poses routinely bury calves/feet slightly in the floor". Adding
   two points that are *more likely than any others* to sit in solid, against a threshold that
   does not scale with the roster, mechanically increases refusals. Measured baseline: the live
   log already shows **1 `capture BURIED` in 9 pendings (11 %)**, against r9's 0 in 42.
   **Prediction: `buried=` rises and `capture BURIED` refusals rise when feet ship.**
   Mitigations, in preference order: exclude feet from the `buried` count entirely (they are
   leaves — a buried foot pins nothing that the pre-lift cannot free); or raise the threshold to
   5; or measure first with feet counted but the threshold left at 4 and accept one wasted
   session. Take the first.

3. **`RagAllocSlot` and the pending pool are untouched.** `RAG_MAX_SIMS 8` (`:55`),
   `RAG_MAX_PEND 16` (`:69`), the eviction rule (`:1798-1807`). Nothing in this project changes
   residency. Live log: 0 `arm refused`, 0 `EVICTED`.

**Hard gate for every stage:** `settle-armed` ≥ 95 % of `pending-arm`, zero `pending dropped`,
zero `pending gave-up`, zero `capture FAILED`. Baseline from the live log: 9 pending-arm →
8 settle-armed → **89 %**, one loss and it was a `capture BURIED`, not a drop. If drops or
give-ups appear, stop — nothing else in the log means anything (r9 spec §5.7 R-3).

### 1.3 The spin (bug-1971) — **provably safe, if and only if `mu = 0` everywhere**

`RagRawFit` (`:832-846`) reads exactly four points: `pt[0]`, `pt[1]` (spine vector) and
`pt[11]`, `pt[13]` (hip line). It is the input to `RagBodyRotationAdvance` (`:859-901`), the
one filter advance, and to the whole spin instrument (`:1620-1647`). Round 10's key result is
that `RagShapeMatch` is a **fixed point** of that fit, so the shape-match cannot perturb the
estimator that drives it.

A joint limit applied as a rigid rotation of `subtree(dirTo)` about the joint pivot preserves
that property **iff the moving set never contains 0, 1, 11 or 13.** Enumerating the design's own
table (`ragdoll_joints_design.md` §11) with `mu = 0`:

| limits | pivot | moving set |
|---|---|---|
| J4/J5 neck | 3 | {4} |
| J6/J8 L shoulder | 5 | {6,7} |
| J7/J9 R shoulder | 8 | {9,10} |
| J10/J12 L elbow | 6 | {7} |
| J11/J13 R elbow | 9 | {10} |
| J14/J16 L hip | 11 | {12,15} |
| J15/J17 R hip | 13 | {14,16} |
| J18/J20 L knee | 12 | {15} |
| J19/J21 R knee | 14 | {16} |
| **J1/J2 spine1, J3 twist** | **1 / 2** | **{2,3,4,5,6,7,8,9,10}** |

Union of the first nine rows = `{4,6,7,9,10,12,14,15,16}`. **It contains none of 0, 1, 11, 13.**
So **the 18 non-spine limits cannot move a single input of `RagRawFit`** — the rotation filter,
the latch, `rot=`, `spin=`, `spinmax=` and `yawf=` are insulated *by construction*, not by
tuning.

The three spine limits are different. J1/J2/J3 move `pt[2]` and `pt[5]`/`pt[8]`, and the design
gives them `mu = 0.35` — a reaction rotation applied to the **complement** set, which contains
`pt[0]`, `pt[11]`, `pt[13]`. That is a direct write into the estimator's inputs, i.e. a new
closed loop `limit → raw fit → bodyRot → shape-match goal → points → limit`. **That is the spin
risk, re-opened, by exactly the mechanism round 10 spent a session proving was absent.**

**Requirement: `mu = 0` on all limits, and J1/J2/J3 out of the first limits build.** With that,
`spinmax` is a *falsifier*: it must not move. Measured baseline to beat — spin at sleep 1.1–8.2
(median ≈ 1.8) °/s, `spinmax` 1.8–11.8 (median ≈ 8.2) °/s, `yawf` 0.05–0.40, `rot` 1–16°. (Note
these are the real numbers; the brief's "0–3 °/s at rest, 0–28° rotation" understates the spin
tail — two of ten bodies slept at 8.2 °/s.)

### 1.4 The hover fix (bug-1970)

`ptRadius[i]` is clamped **once, at capture**, to the floor clearance that point already has in
the authored pose (`:708-725`), floor 1.0 u. Two exposures:

- **New points.** A foot resting flush gets `tr.fraction ≈ 0` → `clear ≈ 0` → clamped to the
  1.0 u floor. That is correct (it reproduces the animator's own drape) but it means feet
  collide as near-points. Swept `CM_BoxTrace` means no tunnelling, but a foot will visually sink
  into thin geometry more than a calf does. Acceptable; watch for it visually.
- **Limits move limbs where the authored pose never was.** A knee limit swinging a shin means
  the foot's 1.0 u radius, measured against the floor it was lying on, now applies on top of a
  crate. Expect *less* hover, never more — the failure direction is sink, not float. There is no
  instrument for this; the check is `r_ragdollDebug 2` (dots at the surface, mesh through it).

The deferred F6/F4 clearance corrections (`+1.0f`; one-axis clamp applied to three) are **still
deferred**. They change drape depth on every point of every body and would confound a limits
measurement exactly as they would have confounded round 10's spin measurement. Do not bundle.

### 1.5 The blowup nets

- **`RagSane` span 200 u** (`:1204-1209`). A rigid subtree rotation about a pivot preserves every
  distance *within* the moving set and every distance from the pivot to the moving set, so the
  maximum span change from one limit is bounded by twice the subtree's radius from its pivot
  (≤ ~50 u for an arm, ≤ ~46 u for a shin). **Limits cannot cause a span blowup.** Leave the gate
  at 200 — it fired 0/8 in the live session, and both blowups were `leash`, not `span`.
- **Pelvis leash 128 u** (`:1214-1221`). With `mu = 0`, no limit can move `pt[0]` at all, so
  limits cannot trip the leash either. **Both live leash trips are impulse-side** — see §0.
- **`s_ragNeverArm` is permanent per map** (`:1687`). Every blowup permanently retires that
  corpse. At 2 blowups / 8 arms the current build is retiring 25 % of ragdolls. That is a real
  cost of *not* fixing §0, and an argument for S0 going first on its own merits.
- **Velocity cap** `coop_ragdollVelCap 8` u/substep (`:953-960`). A rigid rotation of `pt` and
  `ptPrev` together preserves `|pt − ptPrev|`, so limits are cap-neutral. This is also the
  anti-jitter property that makes the design's `RagRotateSet` mandatory: it must move **both**
  arrays or every limit correction injects velocity into the sleep meter.

### 1.6 The freeze drill (`coop_ragdollTest 2`) — what it does and does not prove

`CG_RagdollFrame` short-circuits a freeze-pose sim before any physics (`:1552-1555`), and
`RagPush` forces `S = I` for it (`:1264-1266`). Therefore:

- **It proves I1, I2, I3 and the capture/channel/anchor plumbing.** That is exactly what round 11
  needs from it, *provided round 11 does not change `RagPush`.*
- **It is structurally blind to everything the limits do** (no `RagStep` runs at all), and blind
  to the *content* of `S` — which is how bug-1966 (every bone driven by the wrong segment) lived
  through eight rounds of "the render pipeline is proven correct".
- **Therefore: if a stage changes `RagPush`, the drill is not its gate, and a new drill mode
  must ship in the same build** (joints design T2: run the new orientation path on frozen
  points). The corollary is the central staging recommendation — **keep round 11 out of
  `RagPush`.** The limits need nothing from it. The feet need exactly two table entries
  (`s_ragDriveChild[12] = 15`, `[14] = 16`), which change `S` for two bones and are A/B-able.

**Two live gaps in the drill's own harness, found while reading the cfgs:**

1. `coop_mod/cfg/rag_drill.cfg:9` still sets **`coop_ragdollMode 3`**. The round-10 spec (E9)
   moved the drill onto the shipping branch and the engine half landed (`:1948`,
   `s->freezePose = (rag_test->integer == 2)` in the pending path; gate `:2085`), but the cfg was
   never updated. **F7 today drills the free branch, not the settle branch.** One-line fix.
2. `coop_mod/cfg/rag_run.cfg` (F8, "the reset key") does **not** seed the five round-10 cvars
   (`coop_ragdollRotLock`, `Slew`, `Carry`, `VelCap`, `Leash`). The spec required it. If the user
   changed any of them during round 10, F8 will not reset them and round 11's data is silently
   mixed. The sleep-rot line self-documents (`lock=/slew=/carry=/vcap=`) so it is *detectable* —
   but it should be *prevented*. Also: `rag_carry.cfg` on F6, which the round-10 spec listed as
   shipping, does not exist.

---

## 2. STAGING — one build, one question

The user tests one build per session. Below: the order, what each makes observable, and which
orderings are traps.

### S0 — the limp-ramp sign fix, alone. **Do this first.**

**Change:** clamp `k` to `[0,1]` in `RagShapeMatch:929` (or store the granted window per point).
1–3 lines. Optionally, in the same build, make `RAG_IMPACT_RELAX`/`RAG_IMPACT_LIMP_MS` cvars —
they are compile-time constants today (`:65-66`), so every impulse-feel question currently costs
a rebuild.

**Question it answers:** *with the repeller removed, do grenades and rifle fire already move
limbs the way the user asked for?*

**Why first:** §0. Two of eight arms blew up; the surviving grenade signature is a coherent
whole-body drift, which is verbatim what the user reported and what the limits project was
commissioned to fix. Running a 500-line constraint-topology change on top of an uncorrected sign
error is how a project gets attributed to the wrong cause for three more rounds.

**It is also the cheapest possible test of the project's premise.** If S0 alone produces "yes,
that's what I wanted", the limits project's *stated* justification evaporates and it reverts to
what it actually is — the prerequisite for the *next* goal (physics owning the fall), which can
then be scheduled on its own merits instead of on a contaminated symptom.

### S1 — feet / knee topology alone (`coop_ragdollFeet`)

**Change:** `RAG_PTS` 15 → 17 (dynamic per sim, see §1.2), `s_ragBones` + `s_ragPtRadius` + two
`s_ragDriveChild` entries, `s_ragAnchorTable` `"Bip01 L/R Toe"` → 15/16, feet excluded from the
`buried` count. **No brace change, no limit, no `RagPush` math change.**

**Question:** *does simulating the ankle fix the shin, and does it cost coverage?*

**Why it is separable:** the two new points appear in **no brace** (`s_ragBraces` endpoints are
{0,1,2,3,4,5,6,7,8,9,10,11,12,13,14} but never 15/16) and in **no limit** at this stage. They are
pure leaves on a distance link. Today ~46 u of shin per leg has no simulated direction —
`s_ragDriveChild[12] = -1` (`:113`, with the comment already anticipating this change) — so the
calf renders parallel to the thigh and the knee is frozen at its death-pose bend forever. This is
the one visible win available without touching a single constraint.

**Why it is not free** (state this up front so it is not misread as a regression):
- `span=` grows on the long axis by roughly the foot's reach, ~8–14 u. Baseline max axis is
  39–63 u; expect 50–75 u. Not a failure.
- `drift=` divides by `RAG_PTS − 1` (`:1739`) — 16 instead of 14, plus two new terms. Not
  comparable to round 10's numbers without care.
- `contacts=` / `ctcmax=` rise (feet touch the floor). Baseline `ctcmax` 3–11.
- `RAG_MOVER_PER_BODY 60` (`:63`) buys `60/17 = 3.5` movers per body instead of `60/15 = 4.0`.
  Raise it to 68 to hold parity; otherwise mover collision silently degrades on the 4th bmodel —
  the same class of silent budget starvation as bug-1967.
- World traces per body per frame go 60 → 68 (`RAG_PTS × RAG_MAX_STEPS`); 8 bodies = 544/frame.
  Budget-exempt by construction. Live `worldtr=` is 15–45. No concern.
- Sleep is *not* a risk, because it has no headroom left: **10 of 10 sleeps in the live log are
  `life=6001–6011 ms`, i.e. 100 % ride the cap.** More on that in §4.4.

### S2 — the 18 non-spine limits, `mu = 0`, **with** the fold braces deleted **and** a stiffness sweep in the same session

**Change:** J4–J21 from the design's table (`ragdoll_joints_design.md` §11), `mu = 0` on every
one; delete `s_ragBraces` rows 6–15 and their `s_ragBraceMinFactor` entries (`:130-139`,
`:147-152`); keep rows 0–5, the equality torso truss; add one limit + one distance pass after
`RagShapeMatch` (§1.1 I5); add the `lim=` instrument (§4.3).

**Question:** *with anatomical limits holding the pose, how loose can the corpse be before it
mangles?*

**The atomicity rule, and why it is exactly rows 6–15.** Enumerate which braces a limit's rigid
subtree rotation would fight — a brace survives untouched iff both its endpoints are outside the
moving set, or one of them **is the pivot** (distance to the pivot is preserved exactly):

| brace | endpoints | fate under J4–J21 |
|---|---|---|
| rows 0–5 `{5,8} {11,13} {5,13} {8,11} {3,1} {0,2}` | 0,1,2,3,5,8,11,13 | **none appear in any moving set** → provably no conflict → **KEEP** |
| row 9 `{5,7}` elbow fold | 7 moves under J10, pivot is 6 — but 5 is *not* the pivot | conflicts → delete |
| rows 6,7,8,10,11,12,13,14,15 | 4, 6, 9, 10, 12, 14 all appear in moving sets with a non-pivot partner | conflict → delete |

So: **the 18 non-spine limits are orthogonal to the equality truss and in direct conflict with
every fold brace.** That is the atomicity rule made mechanical, and it also proves the converse
direction — deleting rows 6–15 without landing limits removes the only thing stopping a full
jackknife (bug-1963 FIX 5, which added rows 14/15 precisely because "a full jackknife is
constraint-legal").

**Why the stiffness sweep is not optional.** At `coop_ragdollStiff 0.25`, the shape-match removes
`1 − 0.75^4 = 68 %` of every point's deviation from the authored pose *per frame*. The authored
pose is anatomically legal by construction, and the design widens every range at capture to admit
the capture angle ±5° (§5.6). **Therefore, at the shipped stiffness, essentially no limit will
ever activate**, and S2 will render pixel-identical to S1. A build that answers nothing is worse
than no build. The session must therefore sweep `coop_ragdollStiff` — 0.25 (baseline, expect
`lim=0`), F11 → 0.10, and a new `rag_limp.cfg` at 0.05 — and the acceptance question is *at which
alpha do the limits start doing work, and does the body stay anatomical there.*

### S3 — spine limits J1/J2/J3, and the equality-truss decision. **Last, and separately.**

**Question:** *can the torso soften without re-opening the spin?*

J1/J2/J3 are the only limits whose moving set overlaps the surviving equality truss (`{5,13}`,
`{8,11}` cross the subtree(2) boundary), and — at any `mu > 0` — the only ones that can perturb
`RagRawFit`. They carry the entire spin risk and the entire limit-vs-truss conflict of the whole
project. They are also what the user's complaint is really about: `pt[5]` is pinned by **three**
equality constraints (parent link to `pt[2]`, plus `{5,8}` and `{5,13}`), which is enough to fix
a point in space up to reflection, so the shoulder cannot translate at all. Loosening that is a
distinct experiment with a distinct failure mode, and it must not be bundled with S2.

### S4 — earlier animation→physics handoff (physics owns the fall)

The strategic goal. Only after S2/S3 are signed off, because a free fall with no limits picks
anatomically impossible configurations — that is the eight-round history this whole line of work
is trying not to repeat. Not scoped here.

### Orderings that are traps

| Ordering | Why it is a trap |
|---|---|
| **(b) limits with the truss intact and alpha unchanged** | The brief's own suspicion is right, and the reason is arithmetic: at `stiff 0.25` the body sits within 0.7–3.1 u (`drift=`, live) of a legal authored pose, and every range is widened to admit it. `lim=0` on every joint of every body. **A guaranteed null result.** It only becomes informative when shipped with the stiffness sweep. |
| **(c) truss loosening without limits** | Two failures, and the second is the interesting one. (i) It re-opens the pile — bug-1962/1963's recorded finding, "pure neighbour links = heap". (ii) **The truss is not what makes the corpse stiff.** The 10 fold braces are *inequality* constraints that only act when a joint folds below 60–80 % of its capture separation (`:989-991`); at rest the body sits at ~100 % of capture distances, so **they exert exactly zero force on a settled corpse.** Deleting them changes nothing the user can see. The rigidity is `RagShapeMatch` at 68 %/frame. |
| **feet + limits in one build** | Confounds the coverage question (does `buried=` refuse arms?) with the activation question (do limits ever fire?). Both are yes/no and both need clean attribution. |
| **anything bundled with a `RagPush` change** | The freeze drill is blind to `S`'s content, so a render regression would survive its own gate. This has happened three times (bug-1963, 1964, 1966) and each one voided a whole session. |
| **limits + the deferred F6/F4 clearance corrections** | Drape depth changes on every point of every body; every visual verdict becomes unattributable. Still deferred, still for the same reason. |

---

## 3. CVAR PLAN

All `CVAR_TEMP` (non-archived, so bug-1961's stale-archive trap cannot apply), registered in
`RagCvars` (`:299-320`) alongside the existing eleven, each defaulting to **the old behaviour**.

| Cvar | Default | 1 / on means | Stage | Rollback |
|---|---|---|---|---|
| `coop_ragdollFeet` | **0** | 17-point roster: feet as points 15/16, `s_ragDriveChild[12]=15`/`[14]=16`, toe anchors retargeted, feet excluded from the `buried` count — **one atomic switch** | S1 | `coop_ragdollFeet 0` |
| `coop_ragdollLimits` | **0** | J4–J21 active, `mu = 0`, brace rows 6–15 skipped (gate the brace loop on the same cvar so the atomicity rule is enforced *at runtime*, not just in the diff) | S2 | `coop_ragdollLimits 0` |
| `coop_ragdollLimitStiff` | **0.98** | net per-substep limit stiffness; per-iteration `k' = 1 − (1−k)^(1/RAG_ITERS)` so tuning survives an `RAG_ITERS` change | S2 | tuning only |
| `coop_ragdollLimitSpine` | **0** | J1/J2/J3 on | S3 | `coop_ragdollLimitSpine 0` |
| `coop_ragdollImpactRelax` | **0.05** | today's `RAG_IMPACT_RELAX` (`:65`) as a live knob | S0 | set to 0.05 |
| `coop_ragdollImpactWindow` | **600** | today's `RAG_IMPACT_LIMP_MS` (`:66`); also becomes the ramp denominator, which is the §0 fix | S0 | set to 600 |

**Gating the brace loop on `coop_ragdollLimits` is deliberate.** It makes "limits on ⇒ fold
braces off" a runtime invariant that cannot be violated by a partial revert, which is exactly the
failure the atomicity rule exists to prevent.

**No `coop_ragdollImpact` master switch exists today** — `CG_RagdollImpulse` (`:1369-1377`)
checks only the bridge pointer, `force` and `radius`. The r9 impact design specified one; it was
not implemented. Add `coop_ragdollImpact` (default **1**, `CVAR_ARCHIVE`, matching `coop_ragdoll`
at `:305`) so the impulse feature has a one-command off, which it currently does not.

**The `getcvar` trap (bug-1669): checked, and clear.** A script `getcvar` is
`gi.Cvar_Get(name, "", 0)` (`scriptthread.cpp:2628`), which creates the cvar **empty** and
permanently defeats a later engine default. Grepping `--include=*.scr` across
`hzm-mohaa-coop-mod/` for `ragdoll` returns exactly one hit —
`gags/t2l1_tank.scr:390`, an unrelated animation name `"21A201_RagDollDeath"`. **No script reads
any `coop_ragdoll*` cvar.** The rule to carry forward: keep every ragdoll cvar console/cfg-only.
A `.cfg` `set`/`seta` is safe (it sets a value); a script `getcvar` is not (it creates one
empty). If a future round wants a script-side toggle, it must be pre-registered engine-side
before any script runs, per bug-1669's fix.

**Hotkeys.** Bound today (`autoexec.cfg:1244-1248`): F7 drill, F8 run/reset, F10 driver A/B,
F11 soft 0.10, F1 firm 0.50. F9 is `clip_toggle` (`:72`); F10/F11 are double-bound over the
video-clip binds at `:73-74` (later wins). **Free: F2, F3, F4, F5, F6, F12.** Proposed:

- **F6** → `rag_limp.cfg`: `coop_ragdollStiff 0.05` (the low end of the S2 sweep).
- **F5** → `rag_lim_off.cfg`: `coop_ragdollLimits 0` — the one-key rollback mid-session.
- **F4** → `rag_feet_off.cfg`: `coop_ragdollFeet 0`.
- **Fix `rag_drill.cfg:9`** to `coop_ragdollMode 1` (§1.6 gap 1).
- **Add the five round-10 cvars + the new ones to `rag_run.cfg`** so F8 is a true reset
  (§1.6 gap 2).

---

## 4. ACCEPTANCE EVIDENCE

Baselines, all measured from `G:\mohaa-gl2\home\maintt\qconsole.log`, 2026-08-20 16:00–16:03,
8 arms / 10 sleeps / 35 impulses / 2 blowups:

| field | live baseline |
|---|---|
| `settle-armed` / `pending-arm` | 8 / 9 = **89 %**; 0 dropped, 0 gave-up, 0 FAILED, **1 `capture BURIED`** |
| `life=` | **6001–6011 ms on 10 / 10** — every body rides the cap |
| `span=` | (39 57 10) … (63 52 5); max axis **39–63 u** |
| `drift=` | **0.7 – 3.1** (median ≈ 1.0) |
| `maxspd=` | **22 – 51** u/s |
| `contacts=` / `ctcmax=` | 1–10 / **3–11** |
| `stretch=` | **1.01 – 1.09** healthy; **2.18** on the blown-up body |
| `rot=` | **1 – 16°** |
| `spin=` at sleep | **1.1 – 8.2** °/s (median ≈ 1.8) |
| `spinmax=` | **1.8 – 11.8** °/s |
| `yawf=` | **0.05 – 0.40** — bodies topple, they do not spin |
| `rawbad=` | **0 / 10** |
| `worldtr=` | 15 – 45 |
| blowups | **2 / 8 arms, both `reason=leash`**, both after impulses |

### 4.0 Gate 0 — the drill, every stage, before anything else

F7 (with `rag_drill.cfg` corrected to mode 1), kill **one** soldier.
**PASS:** a pixel-perfect, completely normal soldier frozen mid-death.
**FAIL:** any warp, stretch, twist, shrink or detached limb ⇒ the render path broke ⇒ **stop, do
not run the session**. Re-run on `coop_ragdollMode 3; coop_ragdollTest 2` from the console; both
branches must pass.
**Know what it does not prove:** nothing about the limits, and nothing about the *content* of `S`
(§1.6). If a stage changed `RagPush`, this gate is void and that stage is unshippable without a
new drill.

### 4.1 Gate 1 — coverage, every stage (bug-1969)

**PASS:** `settle-armed` ≥ 95 % of `pending-arm`, zero `pending dropped`, zero `pending gave-up`,
zero `capture FAILED`. **`capture BURIED` ≤ 1 in 20.**
**FAIL:** any drop or give-up ⇒ revert the batch; nothing else in the log is interpretable.
**S1-specific watch:** `buried=` on the `settle-armed` line and the `capture BURIED` count. If
`BURIED` rises above the 11 % baseline, the feet are being counted (§1.2 item 2) — fix and
re-run rather than tuning around it.

### 4.2 S0 — the limp ramp

**Log:** `stretch=` on any body that took a grenade must fall from the 2.18 outlier into the
healthy 1.01–1.09 band; `RAGDOLL blowup … reason=leash` must go to **zero** across ≥ 3 grenade
tests; `RAGDOLL leash` and `s_ragNeverArm` retirements go to zero.
**Visual, in the user's words:** throw a grenade beside two settled corpses. Do the **limbs**
flail while the body arcs, or does the body translate as a slab? Shoot a corpse three times with
an SMG (`iLarge 1`, the `limp=670` case): does the limb stay put after the third round, or does
it drift?
**Failure signature that sends S0 back:** stretch still > 1.3 after a grenade with `k` clamped ⇒
the divergence has a second source (the leading candidate is the impulse accumulation ceiling at
`:1486-1499` interacting with `RagShapeMatch`'s `ptPrev` carry at `:938`), and the impulse path
needs its own round before anything else does.

### 4.3 S1 / S2 — the instruments that must be added

Neither stage is readable without new fields. Both are print-only, `rag_debug`-gated, on the
existing `sleep-rot` line:

| field | what it is | why it is load-bearing |
|---|---|---|
| `lim=` | joints that were clamped at least once this life (0–21) | **The single number that says whether S2 did anything.** Predicted `lim=0` at `stiff 0.25`; the whole point of the alpha sweep is to find where it becomes non-zero |
| `limmax=` | peak violation in degrees *before* clamping | Separates "the limits are load-bearing" from "the limits are firing on 0.3° of noise" |
| `limoff=` | limits disabled by the §5.6 capture failsafe (capture angle > 30° outside its widened range) | A derived hinge axis that is wrong on some model shows up here rather than as a backwards knee on screen |
| `spdend=` | mean point speed at the sleep instant | **The missing instrument.** With 10/10 bodies riding the 6 s cap, `life=` carries no information; `spdend=` is the only thing that distinguishes "settled and the timer expired" from "still moving at 30 u/s when we gave up" |
| `pts=` | 15 or 17 | So the log self-documents which roster produced each body, as `lock=/slew=/carry=/vcap=` already do for round 10's knobs |

### 4.4 S1 — feet / knee

**Log — must move:** `contacts=` / `ctcmax=` up by roughly 1–2; `span=` max axis up ~8–14 u;
`pts=17` present.
**Log — must NOT move:** `stretch=` stays ≤ 1.15 (feet add distance links, not constraint
conflicts); `spinmax=`, `spin=`, `yawf=`, `rot=` unchanged in distribution — feet are not
`RagRawFit` inputs, so **any movement in the spin fields is a build defect, not a tuning
outcome**; `rawbad=` stays 0.
**`life=` is not evidence here** — it is already saturated at 100 % cap-riding. Judge `spdend=`.
**Visual verdict:** watch a corpse whose legs are bent. Does the shin now point where the shin
should point, and does the ankle bend, or is the calf still a rigid extension of the thigh?
Cross-check with `coop_ragdollFeet 0` (F4) on the next kill — the difference *is* the knee.
**Failure signature:** feet flapping loosely, ankles bending backwards, or feet penetrating the
floor. Feet at this stage are restrained only by their distance link and the shape-match (which
does hold them at 68 %/frame); if that is not enough, the answer is J18–J21 in S2, not a hack.

### 4.5 S2 — limits + fold-brace deletion + alpha sweep

Session protocol: F7 drill → F8 → **≥ 25 kills at `stiff 0.25`** → F11 (0.10) → **≥ 15 kills** →
F6 (0.05) → **≥ 15 kills**. Say which segment each block belongs to; the `alpha=` field on the
sleep line splits the log cleanly.

**Must move, in this direction:**
- `lim=` rises monotonically as alpha falls: predicted ~0 at 0.25, non-zero at 0.10, several
  joints at 0.05. **If `lim=` is 0 at every alpha, the limits are unreachable and the build
  answered nothing — that is the null result, and it is the predicted outcome at 0.25.**
- `drift=` rises as alpha falls (by construction — the pose pull is weaker). Baseline 0.7–3.1 at
  0.25. This is expected and is not a regression.

**Must NOT move — these are falsifiers of the §1.3 and §1.5 proofs:**
- `stretch=` stays ≤ 1.15. Every limit in S2 preserves every surviving distance constraint
  exactly (§2, S2 table). **If `stretch` rises when `coop_ragdollLimits` goes 0 → 1 at the same
  alpha, the implementation deviates from the spec** — most likely `RagRotateSet` is not rigid,
  or a moving mask includes its own pivot.
- `spinmax=` / `spin=` / `yawf=` / `rot=` unchanged. `mu = 0` makes this provable. **Any change
  is a `mu` leak or a mask error.**
- `span=` unchanged from S1. Limits cannot grow it (§1.5).

**Visual verdict:** at 0.10 and 0.05 — do knees and elbows still bend the correct way? Are arms
outside the torso? Does the corpse still read as a body rather than a heap? Then, the actual
question: **shoot an arm and a leg. Do they now move more than they did at 0.25?**

**Failure signatures that send S2 back to design:**
- A backwards knee or elbow on any body ⇒ a derived hinge-axis sign is wrong on some model. Check
  `limoff=` and `r_ragdollDebug 3`'s capture dump first — a *disabled* limit is the failsafe
  working; a *reversed* one is the failsafe missing.
- Limbs buzzing or chattering at rest ⇒ the anti-jitter rules were not all implemented; the first
  suspect is `RagRotateSet` failing to move `ptPrev` with `pt`.
- `stretch` > 1.3 with `lim` > 0 ⇒ the limits are fighting something. With the fold braces gone,
  the only remaining candidate is `RagShapeMatch`'s mixed alphas (§1.1 I5), i.e. the
  after-the-shape-match pass was omitted or is in the wrong place.
- The pile returns at 0.05 ⇒ 18 limits are not sufficient without the spine limits, and S3 is
  mandatory rather than optional.

### 4.6 A free side-experiment worth one console line

Ten of ten bodies ride the 6 s cap, against round 10's prediction of 55–85 % speed-sleeping. The
arithmetic explains it: `RagShapeMatch` leaves `a·(1 − carry)·|d|` of apparent velocity in the
sleep meter every substep, `= 0.25 × 0.15 × drift / 0.008 = 4.69 × drift` u/s. At the measured
drift range 0.7–3.1 that is **3.3 – 14.5 u/s** against a 10 u/s gate (`:1708`) — and ent 482,
at `drift=3.1`, exceeds the gate on the shape-match term *alone*. **Press `coop_ragdollCarry 1.0`
mid-session and see whether bodies start speed-sleeping.** It costs nothing, it settles round
10's outstanding R6 question, and it carries round 10's own RISK-2 as the counter-signature: any
body sleeping at 1000–1600 ms with `drift > 2` is freezing mid-settle, and the answer is 0.6, not
1.0.

---

## 5. THE HONEST QUESTION — could the limits make it WORSE than today's stiff-but-stable corpse?

Argued as strongly as the evidence allows. There are five distinct ways, and the first two are
likely rather than merely possible.

**(1) The most likely outcome is a null result, not a regression — and a null result costs the
same session.** At `coop_ragdollStiff 0.25` the shape-match removes 68 % of every point's
deviation from the authored pose per frame. The authored pose is anatomically legal by
construction. The design widens every range at capture to admit the capture angle ±5° and
tightens over 250 ms. Live `drift=` is 0.7–3.1 u across 15 points. **A limit whose range contains
the pose the body is being pulled into 68 %-per-frame will never fire.** The predicted reading is
`lim=0` on the majority of bodies, the corpse looks pixel-identical, and the session ends with
the user having watched forty deaths to learn nothing. This is not a hypothetical failure mode;
it is the *base case* unless the stiffness sweep ships in the same build.

**(2) The project is aimed at a constraint that is already inert.** The user's complaint is
rigidity. The 10 fold braces the project deletes are *inequality* constraints that act only when
a joint has folded below 60–80 % of its capture separation (`:989-991`). A settled corpse sits at
~100 % of its capture distances. **They contribute exactly zero force to the body the user is
complaining about.** What makes it stiff is (a) `RagShapeMatch` at 68 %/frame, (b) the six
*equality* braces the design explicitly keeps — `{5,8}`, `{5,13}`, `{8,11}` pin each shoulder
with three constraints, which fixes it in space — and (c) the limp mechanism reaching only the
two ends of the struck bone (`:1443`, `:1500-1502`), so a shot to the forearm frees `pt[5]`
(already truss-pinned) and `pt[6]`, while `pt[7]`, the hand, is still being reeled home at full
alpha and drags the elbow back through the converged `6→7` link. **Every one of (a), (b), (c) is
cheaper to change than the limits project, and (c) in particular is ~3 lines — limp the struck
bone's whole distal subtree instead of its two endpoints.** Shipping 500 lines of constraint
topology that leaves all three in place is a real risk of doing a large correct thing that does
not address the reported symptom.

**(3) Anatomically legal is not the same as looking right — and a wrong axis is worse than no
limit.** The hinge-axis derivation has two branches (bent limb → cross product; straight limb →
the parent bone's most-perpendicular local axis) plus a sign fix from the anatomical invariant.
Straight limbs are common in death poses, so the *fragile* branch is the *common* one. A sign
flip on a knee produces a corpse with a reversed leg — which reads as a total regression, is far
more visible than today's frozen shin, and would be a genuine "worse than before". The design's
failsafe (disable any limit whose capture angle is > 30° outside its widened range) catches a bad
*range*, not a bad *sign*. `limoff=` and `r_ragdollDebug 3` are the mitigations, and neither is
automatic.

**(4) Every stage is a fresh chance to re-break a fix that took a session each.** Coverage went
22 % → 98 % on a single `interpolate` guard (bug-1969); this project adds two `RagCapture` bail
paths unless they are explicitly neutralised (§1.2). The hover fix (bug-1970) is a
capture-time-only measurement that limits can move limbs away from (§1.4). The spin fix
(bug-1971) is safe only because `mu = 0` (§1.3) — set `mu = 0.35` on the spine limits as the
design specifies and it is re-opened by construction. The render path has broken three times and
its only regression test is structurally blind to half of what round 11 could change (§1.6).
Today's corpse is stiff, but it is stable, it arms 89 % of the time, and it does not spin.

**(5) The strategic case is sound and the tactical case is weak, and those must not be
conflated.** Joint limits genuinely *are* the prerequisite for the next goal — physics owning the
fall — because a passive skeleton released cold will pick impossible configurations without them.
Nothing here argues against that. What it argues is that "limits, therefore the arms will react"
is a non-sequitur, and the project should be justified as *infrastructure for S4* rather than as
*a fix for the arm complaint*, because if it is sold as the latter it will be judged as the
latter and it will fail that test.

### The early signal, within the first few kills

Three readings, all available before the tenth body, any of which says stop:

1. **`lim=0` on the first five bodies at `stiff 0.25`.** The limits are unreachable. Do not
   spend the session — go straight to the alpha sweep, and if `lim` is still 0 at 0.05, the
   design's range-widening is too generous and the ranges, not the machinery, are the problem.
2. **`stretch=` above 1.15 on any body with `lim > 0`.** The limits are fighting a constraint.
   Since the fold braces are gone by construction, that means the after-the-shape-match pass is
   missing or misplaced (§1.1 I5), and the build is not testing what it claims to test.
3. **`spinmax=` moves at all.** `mu = 0` makes limits provably unable to touch `RagRawFit`'s four
   inputs. Any movement means a mask contains 0, 1, 11 or 13, or `mu` is non-zero somewhere. That
   is a *correctness* failure, and it re-opens bug-1971 — stop and fix rather than tune.

And one that needs no log at all: **a knee or an elbow bending the wrong way.** One is enough.

---

## 6. ROLLBACK — one command per piece

**Console, mid-session, no rebuild:**

| Piece | Command |
|---|---|
| Feet / knee topology | `coop_ragdollFeet 0` (F4) |
| All 18 limits **and** the fold-brace deletion (they are one gate) | `coop_ragdollLimits 0` (F5) |
| Spine limits | `coop_ragdollLimitSpine 0` |
| Limit stiffness | `coop_ragdollLimitStiff <v>` |
| Impulse feel | `coop_ragdollImpactRelax` / `coop_ragdollImpactWindow` |
| Impulses entirely | `coop_ragdollImpact 0` *(does not exist today — add it)* |
| Round-10 knobs | `coop_ragdollRotLock 0` / `Slew 1.0` / `Carry 0` / `VelCap 24` / `Leash 0` |
| Back to the round-11 defaults | **F8** (`rag_run.cfg`, once it seeds them all) |
| The whole feature | `exec coop_mod/cfg/rag_off.cfg` |
| All instrumentation | `r_ragdollDebug 0` |

**Source:**

| Piece | Command |
|---|---|
| Entire engine batch | `git -C openmohaa-hzm checkout HEAD -- code/cgame/cg_ragdoll.c` → rebuild → `.\build.ps1` |
| Impulse call-site tuning | `git -C openmohaa-hzm checkout HEAD -- code/cgame/cg_parsemsg.cpp` |
| Post-death impacts entirely | `git -C openmohaa-hzm revert --no-commit 663bd1bd cad7efcb 27f90ff1` |
| Round 10 | `git -C openmohaa-hzm revert --no-commit c2e9bef1` |
| Cfg/hotkeys | `git checkout HEAD -- hzm-mohaa-coop-mod/coop_mod/cfg/rag_*.cfg hzm-mohaa-coop-mod/autoexec.cfg` → `.\build.ps1` |
| Restore the previously-deployed binary | copy `G:\mohaa-gl2\cgame.dll` aside **before** building |

**Deploy (bug-1634):** `cgame.dll` must reach **both** `G:\mohaa-gl2\` (the live install) and the
GOG root. `build.ps1` does both; the GOG root alone never reaches the running game. **Verify the
md5 of `G:\mohaa-gl2\cgame.dll` changed before reading a single number** — round 10's own
executive summary exists because a whole session's evidence was read off a binary that was never
deployed.

**Ship unit for every stage: `cgame.dll` alone.** No renderer, no `game.dll`, no
`openmohaa.exe`, no protocol constant. Every API used is already in the import struct —
`Printf` (`cg_public.h:103`), `CM_PointContents` (`:173`), `CM_BoxTrace` (`:177`),
`CM_TransformedBoxTrace` (`:187`), `CM_InlineModel` (`:171`), `ForceUpdatePose` (`:408`),
`TIKI_Orientation` (`:409`), `Tag_NumForName`/`Tag_NameForNum` (`:406-407`),
`Anim_NameForNum` (`:383`), `R_AddRefEntityToScene` (`:295`), `R_SetRagdollPose` (`:453`),
`R_ClearRagdoll` (`:454`) — and the limits need only `acos`, `atan2`, `sin`, `fabs`, all already
used in this file (`:1636-1639`).

---

## 7. RISK REGISTER — top 6 by probability × impact

| # | Risk | P | Impact | Mitigation |
|---|---|---|---|---|
| **1** | **The build answers nothing.** At `stiff 0.25` no limit ever activates; the corpse renders identically; a session is spent | **High** | High — a tenth inconclusive playtest | `lim=` / `limmax=` instruments so the null result is *readable* rather than invisible; the stiffness sweep in the same session; the prediction stated up front so it is not mistaken for a bug |
| **2** | **The symptom that justified the project has a one-line cause that was never fixed.** `k` goes negative for 13/35 shipped impulses; measured `stretch=2.18` and 2/8 leash blowups | **Confirmed** | Very high — the project is being justified by a corrupted observation | S0 first, alone: clamp `k`, re-observe grenades, and let the user say whether the complaint survives |
| **3** | **Coverage regresses via `RagCapture`.** Two new mandatory tags + an absolute `buried` threshold that feet make easier to trip | Med | **Very high** — hands back bug-1969's 22 % → 98 % and voids the session | Feet optional (fall back to 15 points on a missing tag, never bail); exclude feet from the `buried` count; Gate 1 is a hard stop at ≥ 95 % arms |
| **4** | **A derived hinge axis is wrong and a knee bends backwards** — visibly worse than today's frozen shin | Med | High — reads as a total regression | Sign fixed by the pose-independent anatomical invariant, not an axis guess; `limoff=` + `r_ragdollDebug 3` dump every derived axis and capture angle; the failsafe disables rather than snaps; `coop_ragdollLimits 0` is one key |
| **5** | **The spin returns.** The design's `mu = 0.35` on J1/J2/J3 rotates the complement set, which contains `pt[0]`, `pt[11]`, `pt[13]` — a direct write into `RagRawFit`'s inputs | Med | High — re-opens bug-1971, which the brief says is solved and must not be re-opened | `mu = 0` on every limit (which makes non-interference *provable*, §1.3); J1/J2/J3 excluded from S2 entirely and gated separately in S3; `spinmax=` treated as a correctness falsifier, not a tuning dial |
| **6** | **The render path breaks and its only test is blind to it** — as in bug-1966, which survived eight rounds because `coop_ragdollTest 2` forces `S = I` | Low *(if the project stays out of `RagPush`)* | Very high — three prior occurrences, each voiding a session | Hard rule: round 11 changes `RagPush` only via two `s_ragDriveChild` entries, gated on `coop_ragdollFeet`; reject the joints design's §3.4/§3.5 frame-chain rewrite for this round; if any stage *does* touch `RagPush`, it must ship a `coop_ragdollTest 3` (new orientation path, frozen points) in the same build |

---

## 8. WHAT THIS DOCUMENT RECOMMENDS, IN ONE PARAGRAPH

Fix the limp ramp and let the user look at a grenade again (**S0**, 1–3 lines) — two of eight
corpses in the last session were permanently retired by a sign error that turns the pose
attractor into a repeller, and it produces exactly the whole-body motion the project was
commissioned to fix. Then ship the ankle (**S1**, `coop_ragdollFeet`), which is the only visible
win available without touching a constraint, and whose one real hazard is coverage. Then ship the
18 non-spine limits with `mu = 0`, the fold braces deleted under the same gate, one enforcement
pass after the shape-match, and a stiffness sweep in the same session (**S2**) — because limits
without the stiffness reduction they exist to enable are a guaranteed null result. Keep the spine
limits, the equality truss, the clearance corrections and every line of `RagPush` out of all
three (**S3/S4**, later). At no point during round 11 should `spinmax`, `stretch` or the arm
count move for a reason that was not predicted here.
