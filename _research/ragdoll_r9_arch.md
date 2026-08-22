# Ragdoll round 9 — architecture review: is the SETTLE the right shape?

**Lens:** not "are the reactive fixes correct" but "is a continuous 6-second simulation of an
already-landed corpse the right mechanism for realistic deaths at all".

**Verdict up front:** No. The continuous sim is the wrong shape, and the live data says so in the
system's own instrumentation. Recommendation is **D+B**: gate on whether the authored pose actually
disagrees with the geometry, and for the ones that do, run a bounded one-shot relaxation and push
the result once, eased in over ~200 ms. Full reasoning, alternatives and the strongest counter-
argument are below.

---

## 0. Method and provenance

Every number in §1 was re-derived from
`hzm-mohaa-coop-mod/_research/ragdoll_r9_session_live.log` by parsing the 41 `RAGDOLL sleep`
lines emitted by `cg_ragdoll.c:1390-1394`, not copied from any prior document. Counts of event
types come from grepping the same file for the print strings at `cg_ragdoll.c:605, 948, 1288,
1326, 1390, 1431, 1509, 1536, 1586, 1729, 1740`.

**Build identity of the r9 log — important.** The session's sleep lines run 12:40:48 → 12:46:44
with no map load or restart marker in between. The three stability commits are timestamped
`62b92b14` 12:33 (coverage + hover), `877b132f` 12:43:44 (slew + ptPrev carry + caps),
`35428898` 12:44:37 (latch). Only the first predates the session. **Therefore the r9 log measures
the build containing R1–R4 only. R5 (slew/latch), R6 (ptPrev carry) and R7 (caps) have no live
data of any kind** — they were authored in response to this session. The task brief's
"VERIFIED LIVE" list correctly contains none of them. Nothing below treats R5/R6/R7 as verified.

---

## 1. What the live data actually says

41 corpses armed, 41 slept, 0 dropped, 0 give-ups, 0 evictions, 0 blowup-reverts, 0 buried-refusals.
Coverage is genuinely fixed. Everything else is not.

| measurement | derived value | what it means |
|---|---|---|
| ran the full 6 s life cap | **36 / 41 (88 %)** | the sleep heuristic is not a heuristic, it is a fallback that almost never fires. `lifeMs > 6000` (`cg_ragdoll.c:1353`) is the *primary* termination path. |
| speed-slept | 5 / 41 (12 %) | lives 1226, 1277, 2243, 2927, 4277 ms |
| drift ≤ 1.0 u at sleep | **25 / 41 (61 %)** | six seconds of continuous simulation moved the median corpse **0.7 u** off the pose the animator authored. On a 76-u skeleton that is 0.9 % of body length. |
| drift > 2 u | 7 / 41 | see the correlation below — none of these is a drape |
| mean point speed ≥ 100 u/s | **21 / 41 (51 %)**, median 107, max 1611 | on a body captured *already at rest on the ground*. A landed corpse moving at 107 u/s (≈ 2.7 m/s mean over every joint) is the "spinning / spassing" the user reported. |
| vertical span > 25 u at sleep | **11 / 41 (27 %)**, max **72 u** | the file's own acceptance note (`cg_ragdoll.c:1358-1360`) says a sprawled body is z 8–20 u. `ent=681` finished at span (12, 48, **72**) — a skeleton standing on end. |
| zero world contacts at sleep | 8 / 41 | not touching anything |
| < 3 contacts at sleep | 19 / 41 (46 %) | R5's rotation latch requires `nContact >= 3` (`cg_ragdoll.c:796`). For nearly half the corpses there is no evidence it ever engaged. |
| `mover-wake` events | **0** across all three archived sessions | r9 (41 bodies), r8 (82 pendings), p3 (free-fall era) |
| `pending EVICTED` / `arm refused` | 0 / 0 | neither pool has ever been the binding constraint |

### 1.1 The correlation that decides the question

Sorting the 41 bodies by drift:

```
ent=704 drift=9.1 contacts=0 maxspd=1432 zspan=42
ent=729 drift=8.7 contacts=0 maxspd=1125 zspan=52
ent=724 drift=7.6 contacts=0 maxspd= 185 zspan=11
ent=694 drift=7.4 contacts=0 maxspd= 131 zspan=41
ent=700 drift=6.1 contacts=0 maxspd=1611 zspan=38
ent=680 drift=5.0 contacts=1 maxspd=1604 zspan=31
ent=663 drift=2.5 contacts=1 maxspd= 658 zspan=20
```

**All 7 bodies with drift > 2 u had ≤ 1 world contact.** Of the 22 bodies genuinely resting on the
world (contacts ≥ 3), the **maximum** drift in the entire session is **2.0 u** and the median is
0.5 u.

That inverts the design's premise. Drift is supposed to measure the drape — "~0 on flat ground,
5-20 u draped on geometry" (`cg_ragdoll.c:1367-1368`). In 41 corpses it never once measured a
drape. Large drift only ever co-occurred with *no contact and high speed*, i.e. with the blowup.
**The largest deformation any successfully-grounded corpse received from six seconds of physics
was 2.0 units.**

### 1.2 Sleeping and draping are mutually exclusive in this design

The 5 bodies that speed-slept had drifts `0.5, 0.2, 0.2, 0.1, 0.4` — every one at or below the
session median. **Zero of the 7 drift > 2 bodies ever slept on speed.**

The mechanism is structural, not a tuning miss. The sleep gate (`cg_ragdoll.c:1337-1348`) measures
`|pt - ptPrev|` summed over the 15 points. But `RagShapeMatch` writes into exactly that quantity:
pre-R6 it moved `pt` alone (so the whole pull registered as velocity), and post-R6 it moves
`ptPrev` by `0.85·a·d` (`cg_ragdoll.c:845`), so `0.15·a·|d|` still registers as velocity every
substep. **The sleep detector is reading the solver's own residual, not the body's motion.** The
residual `d` for a contacted point is precisely the disagreement between the authored pose and the
surface — which *is* the drape. So the gate can only pass when there is nothing to drape onto.

R6 does not repair this. It divides the injection by 6.67 (from `a·d` to `0.15·a·d`); the ratio
between the drape residual and the sleep threshold is unchanged in kind. 0.85 is a tuning constant
chosen to "leave a little genuine settling motion" (`cg_ragdoll.c:843-844`) — i.e. it deliberately
retains the energy source.

### 1.3 R5's slew constant does not mean what it says

`RagBodyRotation` mutates `s->bodyRot` on every call, and it is called from three places:
`RagShapeMatch` once per substep (`cg_ragdoll.c:828`), `RagPush` once per frame for the pelvis
(`cg_ragdoll.c:1145`), and — a bug in its own right — from inside the debug print block
(`cg_ragdoll.c:1371`). With up to 4 substeps per frame that is **5 slew applications per frame**,
so the effective per-frame blend is `1 − 0.88^5 ≈ 0.47`, not 0.12, and it varies with frame rate
and substep count. `r_ragdollDebug 1` also perturbs the simulation. The estimator has hysteresis
and is being called from query paths; that is a design error independent of the constant chosen.

### 1.4 R1 removed a penetration guard without addressing the cause

On the settle branch a `startsolid` point now has its contact flag cleared and is *left where it
is* (`cg_ragdoll.c:1013-1019`) — `pt[i]` is not restored to `subStart[i]`. How does a point become
startsolid at all? Not by sweeping: a sweep from outside to inside returns `fraction < 1`, not
`startsolid`, and is resolved. It becomes startsolid because **the constraint solver and the
shape-match both move points unswept**, after `RagStep`'s integrate and before `RagCollideWorld`
runs (`cg_ragdoll.c:871-914` then `1313-1314`). Those are teleports through thin geometry. R1
converts "anchored inside the wall" into "free to keep marching into the wall with zero
resistance". The reported symptom (mangling) plausibly improves; the cause is untouched. R1 is a
**hypothesis**, and the capture pre-lift at `cg_ragdoll.c:570-587` is the correct re-projection
primitive it should have reused.

### 1.5 The renderer pool already concedes the argument

`RAGDOLL_MAX_SLOTS 8` (`tr_ragdoll.cpp:19`). 41 corpses armed in one session. Since `arm refused`
never printed, `RagAllocSlot`'s sleeping-sim eviction (`cg_ragdoll.c:1420-1427`) fired at least 33
times, each silently calling `R_ClearRagdoll` and snapping that corpse back to its server anim
pose. **The current design already asserts, in code, that reverting a settled corpse to the
authored pose is visually acceptable** — it does it to 80 % of them. It also means flat-ground
corpses that needed nothing are evicting the rare corpse that actually draped.

---

## 2. The four options

Common to all four: `RagCapture` (`cg_ragdoll.c:500-756`), `RagPush` (`1102-1202`),
`RagServerParked` (`1476-1485`), `RagPendingThink`'s park detection (`1491-1546`), the matrix
helpers, the space contract and both renderer hooks are **untouched**. That is the vetted,
live-proven machinery and none of these options disturbs it.

Every API named below already exists in the cgame import struct: `CM_BoxTrace`
(`cg_public.h:177`), `CM_PointContents` (`:173`), `CM_TransformedBoxTrace` (`:187`),
`CM_InlineModel` (`:171`), `R_SetRagdollPose` (`:453`), `R_ClearRagdoll` (`:454`),
`Milliseconds` (`:116`). **No option requires a new import.**

---

### A — keep the continuous sim, fixed (status quo + R5/R6/R7)

**What the user sees.** Unknown — R5/R6/R7 have never been played. The mechanism arguments say:
the spin is damped but not eliminated (§1.3: the constant is 4× stronger than believed and frame-
rate dependent, and the latch cannot be confirmed to have engaged on 46 % of bodies); the launch
is bounded but not prevented (§1.2: the injector is retained at 15 % strength by design); the
"rides the life cap" behaviour is untouched by construction (§1.2), so 88 % of corpses will still
simulate for exactly 6 seconds. On the evidence, round 10 is another playtest reporting a subtler
version of the same three artifacts.

**Per-frame cost.** Up to 8 awake bodies × 4 substeps × 15 points of Verlet + 6 constraint
iterations + shape-match, plus up to 480 world traces/frame (observed peak 75, `worldtr=75`),
plus one `CG_GetBrushEntitiesInBounds` per body. **Plus** — and this is the cost nobody has
counted — **every sleeping body runs `RagMoverHash` every frame forever**
(`cg_ragdoll.c:1282`), and that is a linear scan of `cg_numSolidEntities` with an
`R_GetInlineModelBounds` call per solid entity (`cg_predict.c:96-113`). Eight slept corpses pay
that scan eight times per frame, permanently, for a wake path that has fired **zero** times in
three sessions.

**Lines changed.** 0 more (already written).

**Eliminated by construction.** Nothing. Every artifact remains representable; only its
magnitude is tuned.

---

### B — one-shot relaxation at capture, pushed once

At the park frame, run N bounded solver iterations with no rendering in between, push the result
once, free the sim. Never simulate again.

**What the user sees.** The authored death plays untouched (median 1352 ms, max 2852 ms of pure
vanilla — derived from the `after=` field of the 41 `settle-armed` lines). At the park instant the
corpse drapes onto whatever it landed on. With the 200 ms ease-in described in §4 there is no
visible pop; without it, a one-frame jump of ≤ 2.0 u for a genuine drape (§1.1's measured ceiling)
and ≤ 1.0 u for 61 % of corpses. **No spin, no launch, no life cap, no corpse that keeps twitching
while the player watches.**

**Per-frame cost.** Zero, permanently, for every corpse in the map. The entire cost is one burst
at the park frame. Sizing it honestly: gravity as a Verlet displacement at dt = 8 ms is
`512 × 0.000064 = 0.033 u/iteration`, so a limb falling 10 u needs ~305 iterations — too slow.
Use dt = 32 ms (`0.52 u/iteration`, ~20 iterations for 10 u); stability across frames is not a
requirement when there are no frames. **N = 60–120 iterations × 15 points = 900–1800 world traces
in one frame**, versus the observed steady-state peak of 75. That is a real single-frame spike
(~1–4 ms). Mitigations, in order of preference: (a) the shape-match is a convergence accelerator —
`a = 0.25` closes 99 % of the residual in 17 iterations, so N = 60 is defensible; (b) skip most of
the work entirely via option D, which is what makes this affordable; (c) admit at most 2 parks per
frame, deferring the rest one frame each (parks are already spread — the `after=` values span
297–2852 ms — and a grenade multi-kill is the only clustering case).

**Lines changed.** Delete ≈ 175: `RagMoverHash` (24), the sleep block (67), the substep/accum/ramp
loop (30), the `state == 0` / `state == 2` handling (25), R5's slew+latch block (31). Add ≈ 90:
`RagRelax()` (~45) and the ease-in blend (~45). **Net ≈ −85 lines**, and `RAG_MAX_SIMS`,
`RagAllocSlot`'s eviction policy, `sleepMs`, `lifeMs`, `accumMs`, `rampMs`, `gravScale`,
`moverHash`, `rotLocked` and `bodyRotValid` all disappear as *concepts*, not as tuning.

**Which code survives.** Everything in the "common to all four" list, plus `RagStep`'s integrate
and constraint loops, `RagResolveHit`, `RagCollideWorld`, `RagSane`, `RagShapeMatch` (see §3).
`RagCollideMovers` (50 lines) goes with the mover system.

**Eliminated by construction.**
- **Spin.** With one rigid fit computed *after* the loop and applied *once* (§3), the estimator has
  no output that feeds back into its own input. Precession is unrepresentable.
- **Launch.** Nothing runs after the push. A diverging solver is caught by one `RagSane` and
  reverted to the authored pose. There is no 6-second window for energy to accumulate.
- **"Rides the life cap."** There is no cap because there is no clock; termination is a fixed
  iteration count, deterministic and frame-rate independent (today's is not: the hitch-discard at
  `cg_ragdoll.c:1318-1320` silently gives a hitching client fewer substeps).
- **Sim-pool eviction.** One static scratch `ragSim_t` suffices; the 8-slot cgame pool
  (~75 KB) and its "never evict an awake sim" rule are deleted outright.

**What is honestly lost.** (i) No visible settling motion — but §1.1 shows the settling motion
currently visible is the artifact, not the feature. (ii) Later events (movers, explosions) need an
explicit re-run — but the sim is asleep within ≤ 6 s today, so a grenade at t = 7 s already does
nothing; this is not a regression. (iii) A body balanced on a crate edge is a *static* equilibrium
the one-shot will happily find and a continuous sim would tip off. Vanilla MOHAA never tips
corpses off ledges either, so this is a regression against an aspiration, not against shipping
behaviour.

---

### C — short bounded sim (400–800 ms), then freeze

**What the user sees.** A brief, visible settle; then the pose holds. The spin and the launch are
*bounded to ≤ 800 ms* rather than removed — they are produced by the same solver, and neither
needs 6 s to appear (`ent=700` reached 1611 u/s, `ent=680` 1604 u/s). After nine playtests,
"the spinning now only lasts 0.8 s" is a weak deliverable.

**Per-frame cost.** Same as A for 400–800 ms per corpse, then zero (freeze, no wake hash). Peak is
lower than B's burst — the work is spread over ~25–50 frames instead of one — which is C's one
genuine advantage.

**Lines changed.** ≈ 60 deleted (sleep block, mover hash), ≈ 10 added (a frozen-at check). Smallest
diff of the three changes.

**Which code survives.** Everything A keeps except `RagMoverHash`, the sleep heuristic and the
life cap.

**Eliminated by construction.** Only the life-cap-vs-sleep ambiguity and the mover-wake scan.
Spin, launch and shape-match energy injection all remain representable — C is a duration cap on
the artifact class, which is tuning wearing an architecture's clothes.

---

### D — no sim at all unless the authored pose disagrees with the geometry

At the park frame, trace all 15 points against the world. If the authored pose is already
consistent with the surface under it, **push nothing, allocate nothing, clear nothing** — the
corpse stays byte-identical vanilla.

**Detector, concretely.** R4 already wrote 90 % of it (`cg_ragdoll.c:661-678`): a downward
`CM_BoxTrace` per point measuring the clearance the authored pose already has. Reuse the same
loop with a longer ray (48 u) and record the *floor height* under each point rather than just the
fraction. Engage physics only if either:
- the floor heights under the 15 points are not co-planar to within ~4 u (stairs, sandbag stack,
  crate, rubble, corpse-on-corpse), **or**
- any point has more air under it than its anatomical radius + ~6 u (a limb over a ledge or a
  stair nose).
Otherwise the animator's pose is already correct and there is nothing to drape. ~30 lines, 15
traces, once.

**What the user sees.** On flat ground: literally vanilla, forever, with no renderer slot consumed
and no possibility of any artifact. On stairs, sandbags, crates and ledges: a drape.

**Per-frame cost.** Zero. The detector cost is 15 traces once per corpse — cheaper than a single
frame of the current sim.

**Lines changed.** ≈ 30 added, plus whatever solver it gates (D is a gate, not a solver — it must
be paired with A, B or C for the cases that pass).

**Which code survives.** All of it; D only decides whether to run it.

**Eliminated by construction.** Every artifact, on every corpse that does not need physics — which
on the evidence is the large majority. It also fixes the slot economy of §1.5: with only the drape
cases occupying renderer slots, a genuine drape stops being evicted by the next eight flat-ground
kills, so **drapes persist instead of being the first thing thrown away**.

---

## 3. Should the shape-match exist under B/C/D?

**Yes — but its job changes, and that change deletes R5 and R6 rather than tuning them.**

The shape-match is not decoration. It is the anti-pile term. The braces alone were tried and
failed: "pure neighbor links = heap", the P3 live finding recorded at `cg_ragdoll.c:117`. A pure
relaxation of a 15-point chain from a rigid start under gravity + collision, with 14 distance links
and 16 braces, reproduces the bead-chain pile that eight rounds of work went into escaping. Keep it.

What changes is the rotation:

- **During the relaxation, `S` is the identity.** At capture `pt[i] == goal[i]` exactly
  (`cg_ragdoll.c:1569-1571`), so the rigid fit *is* identity at iteration 0, and across the whole
  loop the body moves at most ~2 u on the measured evidence (§1.1) — under 2° of body rotation.
  Freezing `S = I` for the loop is accurate to well within the error of the anatomical-triad
  estimator itself, and it makes the feedback loop (goal rotated by an estimate derived from the
  points that the goal then pulls) **structurally impossible**, not damped.
- **One rigid fit at the end, for the push only.** After the last iteration call
  `RagBodyRotation` exactly once to get the pelvis orientation for `RagPush`. There is no
  subsequent iteration for it to influence. That is a pure query with no consumer — which is what
  it should always have been.
- **Consequently R5 is deleted, not tuned.** No slew constant, no latch, no `nContact >= 3`
  condition that failed to confirm on 46 % of bodies, no frame-rate dependence, no debug print that
  mutates the sim.
- **And R6 becomes moot.** Zero `ptPrev` each iteration (position-based / Gauss-Seidel relaxation
  rather than Verlet): gravity contributes a fixed displacement per iteration and nothing
  accumulates. Delete two lines from `RagStep` and the `0.85` magic number has no meaning left to
  get wrong. Energy injection ceases to be a category of bug.

Under **C** the shape-match must stay in its current dynamic form, because C still renders between
iterations — which is exactly why C does not eliminate the spin.

---

## 4. Is the 6 s life cap defensible in any design?

**No, in none of them.**

In A it is not a cap, it is the primary exit: 36/41 = 88 % (§1). Describing it as a safety net
misreports what the system does, which is "simulate every corpse for exactly six seconds". And
corpses persist for *minutes* — `coop_corpseLife` defaults to 0 = off
(`coop_mod/aihandler.scr:132, 604`) — so 6 s is not tied to anything the corpse does. It is a
wall-clock number with no physical referent.

In B/C/D there is no clock at all. Termination is a fixed iteration count: deterministic,
frame-rate independent, and identical for every client. That is strictly better than a wall-clock
cap whose effective substep budget already varies with frame rate through the hitch-discard at
`cg_ragdoll.c:1318-1320`.

---

## 5. What removing the sleep system, the mover hash and the life cap actually costs

The file header advertises "an elevator carries corpses instead of leaving them in the air"
(`cg_ragdoll.c:15-16`). Assessment:

- **It has never been observed to work.** `mover-wake` has fired **0 times** across all three
  archived sessions (r9: 41 bodies; r8: 82 pendings; p3: the free-fall era).
- **It was structurally broken until yesterday and nobody noticed.** bug-1967: `RagCollideWorld`
  incremented the shared trace counter without checking it, so world traces exhausted the 240
  budget and **every body after the third lost bmodel collision entirely.** The feature was dead
  in all but the trivial case for its whole life, through nine playtests, without a single report.
- **Shipping maps do contain movers.** `elevator_cab` appears in `maps/M1L3c.scr`, `maps/m4l2.scr`,
  `maps/m6l3b.scr`, `maps/m6l3c.scr`, `maps/m6l3d.scr`. m4l2's is a scripted 4-second cab gated by
  two doors (`maps/m4l2.scr:541-547, 601-606, 658-663`) — a player transport that opens, admits,
  closes, moves, opens. An enemy dying *inside the closed cab* is possible but is not a case any
  map is built around, and it is not in any logged session.
- **The wake path costs more than it delivers.** Every sleeping body pays a full linear scan of
  `cg_numSolidEntities` with an `R_GetInlineModelBounds` per entity, every frame, forever
  (`cg_ragdoll.c:1282` → `cg_predict.c:96-113`). There is also a latent defect: the hash is a
  float sum over at most 4 bmodels (`centity_t *movers[4]`), and which 4 are returned depends on
  `cg_solidEntities` ordering, which is rebuilt per frame — in a room with 5+ bmodels the returned
  set can change and spuriously wake bodies forever. Not observed; flagged as a **hypothesis**.

**Verdict: not worth keeping.** If corpse-on-elevator ever matters, the cheap correct answer is not
a per-frame hash on every sleeping body — it is to re-run the one-shot on demand, which under B is
a single function call. That is a 5-line "wake" if a specific map ever needs it, versus a permanent
per-frame scan for a case that has never occurred.

---

## 6. Recommendation: D + B

**Gate on geometric disagreement (D); one-shot relax the ones that pass (B); ease the result in
over ~200 ms.**

They are not competitors — D is a gate and B is a solver, and each fixes the other's weakness. D
removes B's single-frame trace spike by skipping most corpses entirely; B gives D something worth
running when the gate opens.

Sketch, all against existing APIs:

1. **`RagPendingThink`, after `RagCapture` succeeds** — run the 15-point clearance/co-planarity
   test (§2 D). If the authored pose already agrees with the geometry: `memset` the scratch sim,
   return, push nothing. The corpse is vanilla and consumes no renderer slot. *(~30 lines)*
2. **Otherwise `RagRelax(s)`** — N = 60–120 position-based iterations of
   `gravity displacement → 6 constraint iterations → shape-match toward `goal` with `S = I` →
   `RagCollideWorld` with the previous iteration's positions as the sweep start`. Set
   `ptPrev = pt` each iteration so no velocity exists to inject or diverge. *(~45 lines, reusing
   `RagStep`'s constraint loops and `RagCollideWorld` verbatim)*
3. **One `RagSane`.** Fail → revert to the authored pose, `s_ragNeverArm`, done. Same failure
   ladder, one evaluation instead of ~750.
4. **One `RagBodyRotation`** for the final pelvis orientation, then store `pt[]` as the target.
5. **Ease-in:** hold a small per-entity blend record (15 vec3 + entnum + start time ≈ 200 B; a
   16-entry array is 3.2 KB versus the ~75 KB sim pool it replaces) and for ~200 ms lerp the 15
   points from the capture pose to the relaxed pose, calling `RagPush` each frame. Twelve frames
   of pure interpolation, no solver, no collision, no traces. Then free the record; the renderer
   table holds the final pose. *(~45 lines)*
6. **Delete:** `RagMoverHash`, `RagCollideMovers`, the sleep block, the substep/accum/ramp loop,
   the `state == 0`/`state == 2` machinery, R5's slew+latch, and the `RAG_MAX_SIMS` pool with its
   eviction policy.

Also worth doing once the per-frame cost is zero: **raise `RAGDOLL_MAX_SLOTS`**
(`tr_ragdoll.cpp:19`) from 8. At 12,288 B/slot, 32 slots costs 393 KB. Combined with D — where only
corpses that genuinely draped occupy a slot — that means a drape on a staircase survives the rest
of the firefight instead of being evicted by the next eight flat-ground kills (§1.5).

**Acceptance test for round 10**, and it must be measurable, not "does it look better":
- `after=` distribution unchanged (the authored death still owns the fall) — expect median ~1.3 s;
- gate skip rate: what fraction of corpses the detector declines. If it is not the large majority
  on an ordinary map, the detector is mis-tuned;
- for corpses that pass the gate, log the final relaxation residual and the iteration count at
  convergence;
- zero corpses moving after the 200 ms blend, by construction — assert it rather than measure it;
- and the one thing the current instrumentation cannot do: **screenshot the same kill twice, with
  the feature on and off.** Every metric in this file is a number the system computed about
  itself.

---

## 7. The single strongest argument against this recommendation

**The evidence that "flat ground needs nothing" is produced by the very system being judged, and
it demonstrably cannot see the artifacts the user reports.**

`drift` is computed against `goal` rotated by `S` — the same estimator §1.3 shows is mis-slewed and
frame-rate dependent — and it is sampled **once, at sleep**. A limb that swung 6 u out and came
back reports ~0. Concretely: the user's hover complaint, the spin complaint and the mangle complaint
all arose in sessions whose bodies reported drift 0.1–0.5. **If drift is blind to every artifact the
user actually saw, it is equally blind to whatever value the sim added** — and both §1.1's
"largest real drape was 2.0 u" and option D's entire premise rest on it.

The failure mode this permits is specific and bad: tune the D gate against a blind metric,
conclude flat ground needs nothing, ship it, and discover that the drape it silently disabled was
the one case the feature existed for — with the difference now invisible because physics never
runs there to be compared against.

The mitigation is cheap and should be a precondition, not a follow-up: before deleting anything,
add a second, independent measurement that does not route through `S` — per-point displacement from
the capture position, tracked as a running maximum over the body's life, in world space. Run one
session with the current build. If that maximum is also ~1 u for the majority, D's premise is
established on evidence the estimator cannot contaminate, and the deletions are safe. If it is
large where drift was small, then the sim has been doing something visible all along that no metric
has ever named, and options B and D are both premature.

That is one session's cost against deleting ~175 lines and the last nine rounds' worth of
assumptions. Pay it.
