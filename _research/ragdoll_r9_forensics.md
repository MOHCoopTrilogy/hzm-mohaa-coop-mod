# Ragdoll round 9 — log forensics

**Lens:** what the measurements say. Every number below is re-derived from the archived logs by
`scratchpad/rag/{parse,stage2,stage3,stage4}.py`, not quoted from prior documents. Claims about
code cite `openmohaa-hzm/code/cgame/cg_ragdoll.c` by line.

Sources parsed (all `^~^~^ RAGDOLL` lines):

| log | lines | wall span | era |
|---|--:|--:|---|
| `ragdoll_r9_session_live.log` | 165 | 372 s | settle, post-coverage-fix |
| `ragdoll_r8_session_1230.log` | 200 | 632 s | settle, pre-coverage-fix |
| `ragdoll_p3_session_2200.log` | 88 | 116 s | free-fall (mode 3) |

---

## 0. PROVENANCE — the r9 log does not contain three of the seven fixes it is being used to judge

This is the first thing to settle, because it changes what every other number means.

| fact | value |
|---|---|
| r9 session wall clock | `12:39:53` → `12:47:14` (log first/last line) |
| deployed `G:\mohaa-gl2\cgame.dll` | mtime **12:32:10**, 658 432 B, md5 `3634849fab5461d3fc51ce69f40617f4` |
| deployed GOG-root `cgame.dll` | mtime **12:32**, 658 432 B (same build) |
| build-tree `.cmake/.../Release/cgame.dll` | mtime **12:44:37**, 659 456 B, md5 `6f46c1687a3ac940974214ef5ccf7fcf` |
| `62b92b14` coverage + hover (R3, R4) | committed 12:33:21 |
| `877b132f` spin slew + energy + blowup net (R5a, R6, R7) | committed 12:43:44 |
| `35428898` latch the rotation lock (R5b) | committed 12:44:37 |

The deployed DLL and the build-tree DLL are **different binaries** (different size, different md5).
The session ran against the 12:32:10 deployment. Builds precede their commits in this workflow —
the 12:32:10 binary is the one `62b92b14` was committed from, which the data independently confirms
(the coverage fix is unmistakably present: zero `pending dropped` lines in 42 deaths).

**Therefore the r9 log measures R1 + R2 + R3 + R4 only.**
**R5 (slew + latch), R6 (shape-match energy) and R7 (velocity cap 8, 200 u AABB sanity) have never
been playtested and have zero measurements of any kind.**

Two consequences:

1. r9 is the **"before"** for the spin fix, not the "after". Every spin number below describes the
   build the user complained about — which is exactly what you want for diagnosis, and exactly what
   you must not mistake for evidence that anything was fixed.
2. As of this writing the LIVE install still carries the 12:32:10 binary. If the next session
   launches without a `build.ps1` run, it will re-test the same build and reproduce the same spin.
   Verify the deployed md5 changes before drawing any conclusion from round 10.

---

## 1. THE FUNNEL

### 1.1 Per session

| stage | r8 (pre-fix) | r9 (post-fix) |
|---|--:|--:|
| `pending-arm` | 82 (100 %) | 42 (100 %) |
| → `settle-armed` (captured) | **18 (22.0 %)** | **41 (97.6 %)** |
| → `pending dropped` | 63 (76.8 %) | 0 (0.0 %) |
| → `pending EVICTED` | 0 | 0 |
| → `pending gave-up` | 0 | 0 |
| → `pending cleared` | 0 | 0 |
| → `capture BURIED` refusal | 0 | 0 |
| → `arm refused` (pool full) | 0 | 0 |
| → **unaccounted, no print at all** | 1 (1.2 %) | 1 (2.4 %) |
| armed → `contact` | 18/18 (100 %) | 40/41 (98 %) |
| armed → `sleep` | 18/18 (100 %) | 41/41 (100 %) |
| `NaN/blowup` reverts | 0 | 0 |

### 1.2 The coverage claim: CONFIRMED

**22.0 % → 97.6 %, a +75.7 pp jump, two-proportion z = 7.98.** The claimed "22 % → 98 %" is exact.

The r8 drop census is worth reading carefully, because it looks at first glance like it *refutes*
the diagnosis and in fact confirms it by elimination. Of the 63 dropped pendings:

- `valid=1` in 63/63, `midx > 0` in 63/63, `etype=1` in 63/63, `dead=1` in 63/63 — i.e. **all four
  conditions the print names were healthy in every single drop.**
- `interp=0` in **63/63 (100 %)**.

The printed guard (`cg_ragdoll.c:1504`) tests four conditions; the r8 build's guard had a fifth,
`!cent->interpolate`, which the print reports but does not test. With all four named conditions
healthy in every drop, the fifth term is the only remaining explanation. **R3 is vindicated by the
data, not merely by plausibility.** Drop age was short — median 143 ms, p75 364 ms, max 2069 ms —
consistent with a gate that fires as soon as interpolation lapses rather than a timeout.

### 1.3 The one remaining silent path — and it is the same entity twice

`ent=145` was pending-armed and then vanished with no arm, no drop, no give-up, no eviction and no
clear — **in both r8 and r9**. Same entity number, two independent sessions.

The model is not exotic: `models/human/german_wehrmact_soldier.tik` in both logs (`SKELDISP
ent=145 hModel=992`), the same 72-channel model that armed successfully 41 times in r9. In r9 the
kill is logged `XPKILL victim=scene4_sniper4`; in r8 the same slot gibbed (`GOREGIB ent=145
gib_surfs=3/3`). So it is a **per-entity property of a scripted scene actor**, not a race and not a
model-roster gap.

Given `rag_debug` was on and the pending pool never filled, the only paths that can consume a
pending record without printing are:

```
cg_ragdoll.c:517   !model.tiki                          -> return qfalse   (silent)
cg_ragdoll.c:528   channel count <= 0                   -> return qfalse   (silent)
cg_ragdoll.c:557   a Bip01 tag missing from the TIKI    -> return qfalse   (silent)
cg_ragdoll.c:1410  RagSimFor(ent) || s_ragNeverArm      -> return NULL     (silent)
```

`cg_ragdoll.c:1559` destroys the pending record at `:1554` *before* calling `RagCapture`, so any of
the first three consumes the pending and leaves no trace. **Which one fired is not determinable
from this log** — that is a statement about the instrumentation, not a hypothesis about the cause.
One `cgi.Printf` at each of the three closes it permanently. At 1/42 = 2.4 % this is a low-priority
instrumentation gap, not a coverage problem.

### 1.4 Arm latency (`after=`)

r9, n = 41: **min 297 ms, p25 677, median 1352, p75 1949, p90 2109, max 2852, mean 1448, sd 694.**

Nothing came within 3× of the 8000 ms give-up cap (`RAG_PEND_CAP_MS`, `cg_ragdoll.c:66`); the cap
is generous and fired zero times.

**Latency correlates strongly with the animation** — it is essentially a lookup table of animation
length, which is exactly what the server-park handoff is supposed to produce:

| anim | n | median `after=` | min | max |
|---|--:|--:|--:|--:|
| `death_frontchoke` | 1 | 2852 | 2852 | 2852 |
| `rifle_wall_death_right` | 2 | 2752 | 2739 | 2766 |
| `mp40_wall_death_right` | 1 | 2670 | 2670 | 2670 |
| `death_chest` | 5 | 2075 | 2070 | 2109 |
| `death_grenade` | 1 | 1949 | 1949 | 1949 |
| `death_crotch` | 2 | 1948 | 1945 | 1952 |
| `death_back` | 3 | 1920 | 1897 | 1928 |
| `death_fall_back` | 4 | 1631 | 1613 | 1635 |
| `death_collapse` | 1 | 1352 | 1352 | 1352 |
| `death_shoot` | 2 | 1350 | 1346 | 1353 |
| `death_backgrenade` | 3 | 1278 | 1273 | 1291 |
| `death_twist` | 2 | 1275 | 1268 | 1282 |
| `death_knockedup` | 1 | 1184 | 1184 | 1184 |
| `death_run` | 2 | 916 | 812 | 1019 |
| `rifle_pain_kneestodeath` | 4 | 674 | 657 | 677 |
| `unarmed_pain_kneestodeath` | 2 | 658 | 651 | 664 |
| `death_frontcrouch` | 2 | 590 | 589 | 590 |
| `unarmed_pain_floortodeath` | 2 | 442 | 436 | 447 |
| `unarmed_pain_crawltodeath` | 1 | 297 | 297 | 297 |

The within-anim spread is tiny (`death_chest` 2070–2109 ms across 5 kills; `rifle_pain_kneestodeath`
657–677 ms across 4) — **the handoff is repeatable to ±20 ms for a given animation.** That is a
genuinely strong result and the strongest evidence in the whole dataset that the server-park signal
is the right one.

Median `after=` doubled from r8 (680 ms) to r9 (1352 ms). That is not a regression: r8 was sampling
only the 22 % of deaths that survived the interpolate gate, and those were biased toward short,
close-range animations. The r9 median is the unbiased one.

---

## 2. SETTLE QUALITY

### 2.1 Distributions (r9, n = 41)

| metric | min | p25 | med | p75 | p90 | max | mean | sd |
|---|--:|--:|--:|--:|--:|--:|--:|--:|
| span X (u) | 12 | 39.0 | 47.0 | 54.0 | 56.0 | 74 | 46.5 | 12.6 |
| span Y (u) | 28 | 42.0 | 52.0 | 55.0 | 60.0 | 88 | 50.2 | 11.4 |
| span Z (u) | 4 | 8.0 | 12.0 | 26.0 | 38.0 | 72 | 18.2 | 14.7 |
| span lateral max(x,y) | 28 | 50.0 | 54.0 | 59.0 | 70.0 | 88 | 54.9 | 10.6 |
| drift (u) | 0.1 | 0.40 | 0.70 | 1.70 | 6.10 | 9.1 | 1.75 | 2.43 |
| maxspd (u/s) | 16 | 44 | 107 | 250 | 1125 | **1611** | 324 | 472 |
| contacts | 0 | 1.0 | 3.0 | 3.0 | 4.0 | 11 | 2.5 | 2.1 |
| life (ms) | 1226 | 6003 | 6007 | 6009 | 6012 | 6018 | 5566 | 1249 |
| worldtr | 15 | 30 | 30 | 30 | 45 | 75 | 33 | 12 |

### 2.2 Scoring against the spec's own criteria

Criteria: `ragdoll_r8_spec.md:686` and the brief — one lateral axis 45–58 u **and** z 8–20 u;
drift 0.5–3 (flat) or 5–20 (geometry); maxspd 30–120.

| criterion | pass | rate |
|---|--:|--:|
| lateral span in 45–58 u | 24/41 | 58.5 % |
| z span in 8–20 u | 19/41 | 46.3 % |
| **both span criteria together** | **14/41** | **34.1 %** |
| maxspd in 30–120 u/s | 20/41 | 48.8 % |
| drift in 0.5–3 or 5–20 | 27/41 | 65.9 % |
| **ALL FOUR** | **4/41** | **9.8 %** |

Failure directions:

| | count |
|---|--:|
| z below 8 u (pancake — flatter than the spec's floor) | 10 (median 6 u) |
| z above 20 u | 12 |
| **z above 25 u (not lying down at all)** | **11 = 26.8 %** |
| lateral below 45 u | 6 |
| lateral above 58 u | 11 |
| lateral < 35 u on *every* axis (the spec's "point pile") | **0** |
| drift below 0.5 (physics effectively inert) | 14 = 34.1 % |
| maxspd above 120 | 18 = 43.9 % |
| maxspd above 300 (spec F5: "the capture is not a landed pose") | 10 = 24.4 % |
| maxspd above 1000 | 7 = 17.1 % |

### 2.3 VERDICT: the build FAILS its own acceptance test

**9.8 % of bodies (4 of 41) satisfy all four of the spec's numeric criteria simultaneously.**
On the span pair alone it is 34.1 %. There is no reading of `ragdoll_r8_spec.md:686` under which
this passes.

Two honest qualifications, in the build's favour:

- **The pile is gone.** Zero bodies were under 35 u on every axis. The anti-pile truss works, and
  that was the round-3-through-7 failure mode. This is real progress.
- **The lateral axis is essentially right.** Median 54 u against a spec band of 45–58 whose upper
  end is itself the 15-point cloud's full extension (57.5 u). The misses are mostly z.

And one qualification against it: the spec's *narrative* pass mark (`cg_ragdoll.c:1358`, "one lateral
axis 55–75 u") disagrees with the spec's *table* (45–58 u). Under the code-comment band the lateral
pass rate is 39.0 % instead of 58.5 %. **These two numbers should be reconciled before round 10, or
the next verdict will be argued rather than measured.**

### 2.4 The high-z tail is two different defects wearing one number

26.8 % of corpses slept with a z-span above 25 u. Splitting on drift separates them cleanly:

**(a) The capture was never a landed pose — high z, LOW drift (n = 6, 14.6 %)**

| ent | anim | spanZ | drift | maxspd | after | ctc | life |
|---|---|--:|--:|--:|--:|--:|--:|
| 681 | `death_backgrenade` | **72** | 1.1 | 305 | 1273 | 0 | 6015 |
| 691 | `death_chest` | 32 | 0.8 | 68 | 2075 | 3 | 6005 |
| 122 | `death_chest` | 32 | 0.4 | 165 | 2109 | 3 | 6007 |
| 157 | `death_chest` | 31 | 0.4 | 112 | 2090 | 3 | 6006 |
| 676 | `death_chest` | 31 | 0.8 | 138 | 2070 | 5 | 6009 |
| 703 | `death_chest` | 26 | 1.4 | 1087 | 2073 | 0 | 6012 |

`drift ≈ 0` means the simulation reproduced its goal faithfully, and the goal *is* the capture. So
the capture itself photographed an upright or kneeling body. `RagServerParked` (`cg_ragdoll.c:1476-1485`)
proves the corpse *bounding box* was swapped and `droptofloor` ran; it does **not** prove the
visible pose is horizontal. Entity 681 slept with a 72 u z-span — taller than a standing soldier's
15-point cloud (~60 u) — at drift 1.1.

**(b) Solver blowup — high z, HIGH drift, high maxspd (n = 5, 12.2 %)**

| ent | anim | spanZ | drift | maxspd | ctc | life |
|---|---|--:|--:|--:|--:|--:|
| 700 | `death_crotch` | 38 | 6.1 | **1611** | 0 | 6005 |
| 680 | `mp40_wall_death_right` | 31 | 5.0 | **1604** | 1 | 6008 |
| 704 | `death_collapse` | 42 | 9.1 | 1432 | 0 | 6008 |
| 729 | `death_back` | 52 | 8.7 | 1125 | 0 | 6002 |
| 694 | `rifle_wall_death_right` | 41 | 7.4 | 131 | 0 | 6005 |

**Not one of these tripped `RagSane`** — and R7's new 200 u AABB test would not have caught them
either: the largest single-axis AABB anywhere in the session is **88 u**. R7's net is set far above
anything this session produced. It will catch the "flying across the world" event the user saw once,
but it is not a filter for the routine blowups, which live at 30–90 u.

### 2.5 `death_chest` is a systematic outlier

| | n | med z | med drift | med after | life-capped |
|---|--:|--:|--:|--:|--:|
| `death_chest` | 5 | **31 u** | 0.80 | 2075 ms | 5/5 |
| everything else | 36 | 11 u | 0.65 | 1286 ms | 31/36 |

5 of 5 `death_chest` bodies sleep at z 26–42 u with drift ≤ 1.4. The two wall-death anims behave
the same way (z 31 and 41). Together those three animations are **8 of 41 = 20 % of all kills**, and
they are the single largest contributor to the z-span failure. This is a *capture-timing* problem
specific to a handful of animations, not a physics problem — and it is invisible in every metric
except `span z`, which is why nine rounds have not named it.

---

## 3. THE SPIN, MEASURED

### 3.1 The signature: bodies do not stop, they time out

The sleep gate (`cg_ragdoll.c:1348, 1353`) fires on *either* mean point speed below 10 u/s held for
1000 ms, **or** `lifeMs > 6000`. So `life ≥ 6000` means: this body never held a mean point speed
below 10 u/s for one continuous second in six seconds of simulation.

| era | n | life-capped | median life |
|---|--:|--:|--:|
| p3 — free-fall, mode 3 (no shape-match at all) | 22 | **7 = 31.8 %** | 3833 ms |
| r8 — settle, pre-coverage | 18 | 18 = 100.0 % | 6005 ms |
| **r9 — settle, current** | **41** | **36 = 87.8 %** | **6007 ms** |

**That is the spin, in one number: 87.8 % of bodies never came to rest.** The user's "basically
every body spins after it hits the ground" is 88 %, and the "they eventually stop" is the 6-second
life cap terminating the simulation, not the motion decaying.

The comparison with p3 is the damning one. The free branch has **no shape-match whatsoever** and
slept 2.8× more often on the same maps with the same sleep gate (31.8 % vs 87.8 % capped,
two-proportion **z = 4.55**, p < 0.001). Whatever is keeping bodies awake arrived with the settle
branch's shape-match/rotation loop; it is not gravity, not the constraints, not collision, and not
the sleep threshold, all of which the free branch shares.

The r8 → r9 difference (100 % → 87.8 %) is **not** significant (z = 1.55). R3/R4 did not move this.

### 3.2 The population is bimodal — quiet bodies sleep, energetic ones never do

| | n | med maxspd | med contacts | med drift | med life |
|---|--:|--:|--:|--:|--:|
| speed-slept | 5 | **44** (max 46) | 3.0 | 0.20 | 2243 |
| life-capped | 36 | **124** (max 1611) | 2.5 | 0.80 | 6007 |

Every one of the five bodies that actually slept had `maxspd ≤ 46 u/s`. Not one body above 50 u/s
ever came to rest. The threshold is sharp.

Correlations (Spearman ρ, n = 41):

| pair | ρ | reading |
|---|--:|---|
| drift ↔ maxspd | **+0.736** | deformation and energy are the same phenomenon |
| contacts ↔ maxspd | **−0.568** | resting contacts are what remove energy |
| contacts ↔ drift | **−0.552** | contacts hold the body on its pose |
| drift ↔ life | +0.312 | weak |
| contacts ↔ life | −0.156 | weak |
| maxspd ↔ life | +0.121 | **none** |
| worldtr ↔ life | −0.052 | none — no trace-budget effect |
| worldtr ↔ maxspd | −0.053 | none |

`maxspd ↔ life` being ~0 is important: life-capping is **not** driven by violence. Quiet bodies
(maxspd 27, 40, 51) ride the cap just as reliably as the 1611 u/s ones. Whatever keeps them awake is
a low-amplitude, persistent motion — consistent with a slow rotation and inconsistent with a
bouncing or sliding body.

### 3.3 The zero-contact cohort

Eight bodies (19.5 %) slept with `contacts = 0` — not one point at rest on the world.

| ent | anim | life | spanZ | drift | maxspd | after | buried |
|---|---|--:|--:|--:|--:|--:|--:|
| 700 | `death_crotch` | 6005 | 38 | 6.1 | 1611 | 1945 | 0 |
| 704 | `death_collapse` | 6008 | 42 | 9.1 | 1432 | 1352 | 0 |
| 729 | `death_back` | 6002 | 52 | 8.7 | 1125 | 1897 | 0 |
| 703 | `death_chest` | 6012 | 26 | 1.4 | 1087 | 2073 | 1 |
| 681 | `death_backgrenade` | 6015 | 72 | 1.1 | 305 | 1273 | 0 |
| 724 | `death_crotch` | 6013 | 11 | 7.6 | 185 | 1952 | 0 |
| 694 | `rifle_wall_death_right` | 6005 | 41 | 7.4 | 131 | 2766 | 1 |
| 443 | `unarmed_pain_kneestodeath` | 6003 | 14 | 1.2 | 107 | 664 | 0 |

Median maxspd **696 u/s versus 68 u/s for the rest of the population — 10.2×.** All eight
life-capped. Contact is the only thing draining energy from this solver, and a fifth of bodies never
establish any.

### 3.4 Rotation rate implied by the data

The sleep gate bounds the residual: a life-capped body's mean point speed did not stay under
10 u/s. Taking the measured median box (54 × 44 × 12 u) and the uniform-box RMS radius
√((a²+b²+c²)/12) = **20.4 u**:

| mean point speed | ω | deg/s | degrees over the 6 s cap |
|--:|--:|--:|--:|
| 10 u/s (the gate — a lower bound) | 0.490 rad/s | **28.1** | 168° |
| 20 u/s | 0.980 rad/s | 56.2 | 337° |
| 44 u/s (the resting-contact threshold) | 2.156 rad/s | 123.6 | 741° |

**≈28 °/s at the low end — one revolution every 13 seconds.** That matches the user's description
("very slow spin") precisely, and the 168° of accumulated rotation over a corpse's visible lifetime
is exactly the amount that reads as "that body is turning" without reading as "that body is
spinning wildly".

### 3.5 Why `drift=` cannot see the spin — the measurement blind spot

`drift` is computed at `cg_ragdoll.c:1366-1379` as the mean of
`|pt[j] − (pt[0] + S·(goal[j] − goal[0]))|`, where `S = RagBodyRotation(s)` — **the same rotation
estimate the shape-match uses as its target.**

A rigid rotation of the whole point cloud is absorbed into `S` and cancels out of the difference.
**`drift` measures only non-rigid deformation. It is mathematically blind to rigid rotation, by
construction.** A body rotating steadily on the spot reads `drift ≈ 0` — "vanilla-identical" by the
spec's own interpretation of the field.

The data shows this happening: **14 of 41 bodies (34.1 %) slept with drift < 0.5, and 10 of those 14
(71.4 %) never slept at all.** The metric the project built to detect "how far the settle moved the
body off the animator's pose" was reporting *perfect* for a third of the population while those
bodies were visibly rotating. That is the mechanism by which nine rounds of instrumented playtesting
missed a defect the user spotted in one look.

### 3.6 What the arithmetic says about R5 (untested — this is prediction, not measurement)

**R5(a), the 0.12 slew, is close to a no-op as a brake.** `RagBodyRotation` is called from three
places, not one:

```
cg_ragdoll.c:828   RagShapeMatch -> once per SUBSTEP (called from RagStep:913)
cg_ragdoll.c:1145  RagPush pelvis-> once per FRAME
cg_ragdoll.c:1371  the sleep PRINT
```

| fps | frametime | substeps | calls/s | slew time constant = 1/(0.12 × calls) |
|--:|--:|--:|--:|--:|
| 60 | 16.7 ms | 2 | 180 | **46 ms** |
| 125 | 8.0 ms | 1 | 250 | 33 ms |
| 250 | 4.0 ms | 1 | 500 | 17 ms |

A 17–46 ms first-order lag removes only the fastest transient; it cannot brake a 28 °/s precession.
It also makes the effective damping **framerate-dependent**, which is a separate defect: the same
death behaves differently at 60 and 250 fps.

Worse, `RagPush` (the render path) and the sleep print both *mutate* `s->bodyRot`, and the sleep
print can *latch* `rotLocked` as a side effect (`:796-799` reached via `:1371`). **Turning
`r_ragdollDebug` on changes the physics.** Any A/B run with debug off is not comparable to these
logs.

**R5(b), the latch, is therefore the whole fix — and it is gated on a condition the spin suppresses.**
`contact[i]` is set in exactly one place, the *resting* branch of `RagResolveHit`
(`cg_ragdoll.c:934-938`): `plane.normal[2] > 0.7` **and** `|pt − ptPrev| < 0.35 u/substep`
(= 43.75 u/s). The bouncing branch (`:940-944`) never sets `contact[i]` at all. So the latch needs
three points simultaneously at rest on a floor — while the body's measured median peak speed is
107 u/s and half the population is above the 44 u/s threshold.

Measured latch reachability in r9:

| | n | share | life-capped |
|---|--:|--:|--:|
| reached `contacts ≥ 3` by sleep | 22 | **53.7 %** | 18/22 = 81.8 % |
| never reached `contacts ≥ 3` | 19 | **46.3 %** | 18/19 = **94.7 %** |

**R5's latch cannot fire for 46.3 % of bodies**, and 94.7 % of those are already life-capped.
Compounding it, R1 *clears* `contact[i]` for any `startsolid` point on the settle branch
(`cg_ragdoll.c:1017`), actively lowering the count R5 depends on — **R1 and R5 work against each
other.**

**Falsifiable prediction for round 10:** life-capped falls from 87.8 % to roughly **28–46 %**, not
to zero. If it lands above 40 %, the gate to widen is the contact test at `:934`, not the slew rate.
If it falls below 25 %, R5 worked and the residual tail is the capture-pose defect of §2.4(a).

### 3.7 The print that would measure the spin directly

Nothing currently logged can see a rigid rotation:

- `span=` is axis-aligned, so an in-plane rotation *does* make spanX/spanY oscillate — but span is
  sampled **once**, at sleep. One sample cannot observe an oscillation. Two samples 1 s apart could.
- `drift=` cancels the rotation (§3.5).
- `maxspd=` is a *peak over the whole life*, so it cannot distinguish "landed hard, then stopped"
  from "never stopped".
- `contacts=` is the best current proxy (ρ = −0.57 with maxspd) but measures resting points, not angle.

**The direct measurement.** All local math; no new entry in the cgame import struct is required —
`RagMat3MulTrans` already exists at `cg_ragdoll.c:367`, and `cgi.Printf` is the existing
`cg_public.h:103`.

Add to `ragSim_t`: `float rotRef[3][3]; float spinDeg; float spinRateMax;`
Once per frame in `CG_RagdollFrame`, after the substep loop and before `RagPush` (`:1399`):

```
R   = bodyRot * transpose(rotRef)                    /* RagMat3MulTrans, :367           */
ang = acos(clamp((R[0][0]+R[1][1]+R[2][2] - 1)*0.5f, -1, 1)) in degrees
s->spinDeg      += ang;
s->spinRateMax   = max(s->spinRateMax, ang * 1000.0f / ms);
memcpy(s->rotRef, s->bodyRot, sizeof(s->rotRef));
```

Extend the sleep line (`:1390`) with `spin=%.0fdeg rate=%.0fdeg/s locked=%d`
(`locked` = `s->rotLocked`, which also directly tests whether R5's latch ever fired).

Pass criterion: **`spin` < 15° total and `rate` < 5 °/s.** Predicted current value from §3.4:
**150–350°.** This one field converts the spin from a video impression into a number, and it is the
only field that can confirm or refute R5.

Cheaper alternative if a struct change is unwanted — sample the shoulder-line yaw
`atan2(pt[8][1] − pt[5][1], pt[8][0] − pt[5][0])` at arm and again at sleep and print both; one
subtraction gives net rotation mod 360°. This loses the accumulated path length (a body that turns
180° and back reads 0) but costs three lines.

---

## 4. PATTERNS NOT PREVIOUSLY NOTED

### 4.1 The settle branch demonstrably changed *where* bodies touch the ground

| session | n | top first-contact bones | legs | torso | arms |
|---|--:|---|--:|--:|--:|
| p3 (free-fall) | 22 | R Calf 11 (50 %), L Calf 9 (41 %) | **91 %** | 0 % | 9 % |
| r8 (settle, pre-R4) | 18 | Head 7 (39 %), Neck 3, R Hand 3 | 11 % | **67 %** | 22 % |
| r9 (settle, post-R4) | 40 | L Hand 8 (20 %), Spine2 6 (15 %), R UpArm 4 | 10 % | 32 % | **58 %** |

The free-fall era landed **feet-first 91 %** of the time — the body fell as a body. The settle era
first-touches are torso and limbs, which is exactly what a body already lying on the ground should
report. **This is independent confirmation that the server-park handoff is capturing a landed pose**
(for the 73 % of animations where it works — see §2.4a for the rest), and it is a cleaner proof than
the anim names.

The r8 → r9 shift from head-first to hand/arm-first is R4's radius clamp: the head lost its 5.0 u
box and no longer reaches the floor first.

### 4.2 R4 cut drift 5.7× and *raised* the blowup rate

| metric | r8 median | r9 median | change |
|---|--:|--:|--:|
| drift (u) | 4.00 | 0.70 | **0.17×** |
| maxspd (u/s) | 182 | 107 | 0.59× |
| contacts | 1.0 | 3.0 | **3.0×** |
| span lateral (u) | 51.5 | 54.0 | 1.05× |
| span z (u) | 18.5 | 12.0 | 0.65× |
| `contacts = 0` share | 38.9 % | 19.5 % | halved |
| `contacts ≥ 3` share | 22.2 % | 53.7 % | 2.4× |
| **`maxspd > 1000` share** | **0.0 %** | **17.1 %** | 0 → 7 bodies |

R4 did what it was meant to do — the body now sits on its authored pose (median drift 0.70) and
reaches the floor far more often. But `maxspd > 1000 u/s` went from **0 of 18 to 7 of 41**. The
two-proportion z is **1.87 (p ≈ 0.06)** — suggestive, **not significant**, and I will not claim it
as established; n = 18 is simply too small to rule out chance (P(0 of 18 | true rate 17.1 %) = 3.4 %).

The mechanism is plausible enough to be worth watching: R4 clamps `ptRadius` to as little as **1.0 u**
(`cg_ragdoll.c:674-676`). A 1 u sweep box on a fast point arrests far less motion than a 7 u one and
is far likelier to pass through thin geometry between substeps. **Flag it as a hypothesis to test in
round 10 by logging the minimum clamped radius per body**, not as a finding.

### 4.3 `buried=` correlates with blowup — directionally

| buried | n | med drift | med maxspd | med z | life-capped |
|--:|--:|--:|--:|--:|--:|
| 0 | 36 | 0.55 | **70** | 12 | 86.1 % |
| 1 | 4 | 1.65 | **387** | 26 | 100 % |
| 2 | 1 | 0.60 | 137 | 12 | 100 % |

buried = 1 carries **5.5× the median maxspd** and 2.2× the median z-span of buried = 0. n = 4, so
this is **directional only, not established** — but it says a single surviving buried point is a
plausible blowup seed, and it is cheap to act on.

Separately: the refusal gate at `cg_ragdoll.c:603` rejects `buried ≥ 4` or any buried torso point.
It fired **zero times in 41 captures**; observed `buried` is only ever 0, 1 or 2. The pre-lift at
`:570-587` is doing all the work and the gate is currently inert. Given the correlation above, the
gate threshold (4) may simply be set past where the damage happens.

### 4.4 Contact only engages *after* a point has already stopped

Because `contact[i]` is set only in the resting branch (§3.6), `RAG_CONTACT_RELAX` — the 0.15
shape-match yield that produces the "drape" (`cg_ragdoll.c:836-838`) — **also only applies to points
that are already at rest.** A limb sliding along the ground gets the *full-strength* pull back
toward the authored pose. The drape mechanism cannot engage during the settling motion it exists to
shape. This is a design consequence nobody appears to have written down, and it is consistent with
the observed drift < 0.5 for a third of bodies: the authored pose is winning almost everywhere.

### 4.5 Clean bills of health — things that are *not* the problem

| | evidence |
|---|---|
| slot reuse / double-arming | 42 pendings = 42 distinct entnums; 41 arms = 41 distinct; **zero** entity armed twice, in either session |
| armed-but-never-slept | 0 |
| slept-but-never-armed | 0 |
| pool pressure | peak concurrent awake sims **4** (r9) and **3** (r8), against `RAG_MAX_SIMS` 8 and a 16-slot pending pool; zero evictions, zero arm-refusals |
| trace budget | `worldtr` max **75**, median 30, against an unbounded world-trace path and a 240 mover ceiling. Histogram {15:5, 30:26, 45:7, 60:2, 75:1}. Nowhere near saturation; ρ with life and with maxspd both ≈ −0.05 |
| sim keeping up with wall clock | wall(sleep − armed) − printed `life=` has median **−8 ms** (n = 41). The sim runs essentially every frame; no starvation |
| NaN / 65536 failure ladder | 0 fires |
| `capture BURIED` / `BIND` refusals | 0 |
| give-ups at the 8 s cap | 0 (max `after=` 2852 ms = 36 % of cap) |
| first contact on a floor | r9 39/40 = 98 % have `nz > 0.7`; r8 18/18 = 100 % |
| kill rate | r9 7.1 kills/min, r8 7.9 — comparable workloads |

### 4.6 The `contact` print misses every gently-landing body — confirmed in the source

Exactly one r9 body, `ent=692`, armed and slept (life 2927 ms, maxspd 44, drift 0.2) with **no**
`RAGDOLL contact` line, yet reported `contacts=3` at sleep. That is not an inconsistency in the
data; it is a print-coverage bug I can name exactly:

```
cg_ragdoll.c:934-939   resting branch: sets s->contact[i] = 2, then RETURNS at :938
cg_ragdoll.c:945-951   the "!s->touched" contact print — reached ONLY by the bouncing branch
```

The resting branch returns *before* the `touched` latch. **A body whose first world interaction is
gentle enough to rest immediately sets its contact flag and never prints anything.** Consequences:

- The `armed → contact 40/41 (98 %)` figure in §1.1 undercounts: at least one body touched the
  world without saying so. True touch coverage is 41/41.
- Every `contact` line in every log describes a first **impact**, never a first **touch**. The
  first-contact bone census in §4.1 is therefore a census of impacts. The p3-vs-r9 comparison there
  remains valid — both eras use the identical print — but the label should read "first impact".
- Moving the print above the early return at `:938` costs two lines and makes the field mean what
  its name says.

---

## 5. BASELINE TABLE — judge round 10 against these

| metric | p3 free | r8 settle | **r9 settle** | target |
|---|--:|--:|--:|---|
| coverage armed/pending % | n/a | 22.0 | **97.6** | ≥ 95 |
| bodies slept (n) | 22 | 18 | **41** | — |
| **LIFE-CAPPED % ← THE SPIN** | 31.8 | 100.0 | **87.8** | **≤ 25** |
| median life (ms) | 3833 | 6005 | **6007** | ≤ 3000 |
| median span lateral (u) | 44.0 | 51.5 | **54.0** | 45–58 |
| span lateral in 45–58 % | 45.5 | 83.3 | **58.5** | ≥ 70 |
| median span z (u) | 5.5 | 18.5 | **12.0** | 8–20 |
| span z in 8–20 % | 27.3 | 55.6 | **46.3** | ≥ 70 |
| span z > 25 % (not lying down) | 0.0 | 27.8 | **26.8** | ≤ 5 |
| median drift (u) | n/a | 4.00 | **0.70** | 0.5–3 |
| drift < 0.5 % (physics inert) | n/a | 5.6 | **34.1** | ≤ 20 |
| median maxspd (u/s) | n/a | 182 | **107** | 30–120 |
| maxspd > 300 % | n/a | 22.2 | **24.4** | 0 |
| maxspd > 1000 % | n/a | 0.0 | **17.1** | 0 |
| median contacts | n/a | 1.0 | **3.0** | ≥ 4 |
| contacts = 0 % | n/a | 38.9 | **19.5** | 0 |
| contacts ≥ 3 % (R5 latch reach) | n/a | 22.2 | **53.7** | ≥ 90 |
| median after= (ms) | n/a | 681 | **1352** | ≤ 2500 |
| max after= (ms) | n/a | 1946 | **2852** | < 8000 (cap) |
| median worldtr | n/a | 30 | **30** | < 240 |
| **spin= (deg, total)** | — | — | **not instrumented** | **< 15** |
| **rate= (deg/s, peak)** | — | — | **not instrumented** | **< 5** |
| **locked= (R5 latch fired)** | — | — | **not instrumented** | **1 for ≥ 90 %** |

Minimum sample for a meaningful round-10 comparison: **≥ 35 slept bodies.** At n = 18 (r8's size) a
17 % effect is invisible — that is exactly why the maxspd regression in §4.2 cannot be called.

---

## 6. WHAT I WOULD CHANGE IN THE INSTRUMENTATION, RANKED

| # | change | site | why |
|--:|---|---|---|
| 1 | `spin=`, `rate=`, `locked=` on the sleep line | `cg_ragdoll.c:1390` | the only fields that can see the reported defect, or confirm R5 |
| 2 | Stop `RagPush` and the sleep print from mutating `bodyRot` | `:1145`, `:1371` | the render path and the debug print currently advance the physics and can latch `rotLocked`; debug-on ≠ debug-off |
| 3 | One `Printf` at each silent `RagCapture` return | `:517`, `:528`, `:557` | closes the last unlogged pending-loss path (§1.3) |
| 4 | Print `minRadius=` (the smallest clamped `ptRadius`) at arm | `:677` | the only way to test §4.2's hypothesis |
| 5 | Sample `span` a second time at t+1 s, print both | `:1390` | a rotating body's axis-aligned spans oscillate; one sample cannot show it, two can |
| 6 | Reconcile the two lateral-span pass bands | `:1358` vs `ragdoll_r8_spec.md:686` | 55–75 vs 45–58 changes the verdict by 19 pp |
| 7 | Move the `contact` print above the resting-branch return | `:938` / `:945` | today it fires only on impacts, never on gentle landings (§4.6) |

---

## APPENDIX — full r9 per-body table (41 bodies, chronological)

`bur` = `buried=` at capture. Life ≥ 6000 = never came to rest.

| ent | anim | after | life | spX | spY | spZ | drift | maxspd | ctc | wtr | bur |
|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| 482 | `unarmed_pain_kneestodeath` | 651 | 6004 | 53 | 39 | 12 | 0.3 | 49 | 4 | 15 | 0 |
| 157 | `death_chest` | 2090 | 6006 | 37 | 41 | 31 | 0.4 | 112 | 3 | 15 | 0 |
| 148 | `death_back` | 1920 | 4277 | 54 | 71 | 7 | 0.5 | 46 | 4 | 15 | 0 |
| 695 | `unarmed_pain_crawltodeath` | 297 | 6009 | 74 | 46 | 5 | 0.5 | 16 | 3 | 30 | 0 |
| 164 | `death_frontcrouch` | 589 | 6007 | 54 | 38 | 6 | 0.5 | 27 | 7 | 15 | 0 |
| 692 | `rifle_pain_kneestodeath` | 676 | 2927 | 44 | 53 | 8 | 0.2 | 44 | 3 | 30 | 0 |
| 146 | `death_back` | 1928 | 6010 | 52 | 55 | 17 | 2.0 | 69 | 3 | 30 | 0 |
| 95 | `death_fall_back` | 1613 | 6008 | 48 | 51 | 14 | 0.3 | 66 | 2 | 45 | 0 |
| 699 | `rifle_pain_kneestodeath` | 657 | 6003 | 48 | 53 | 10 | 1.4 | 250 | 1 | 15 | 0 |
| 649 | `death_twist` | 1268 | 6007 | 55 | 46 | 12 | 0.6 | 137 | 1 | 30 | 2 |
| 676 | `death_chest` | 2070 | 6009 | 40 | 36 | 31 | 0.8 | 138 | 5 | 30 | 0 |
| 724 | `death_crotch` | 1952 | 6013 | 33 | 42 | 11 | 7.6 | 185 | 0 | 30 | 0 |
| 703 | `death_chest` | 2073 | 6012 | 31 | 45 | 26 | 1.4 | 1087 | 0 | 30 | 1 |
| 219 | `death_fall_back` | 1627 | 6003 | 55 | 53 | 14 | 1.6 | 1153 | 3 | 30 | 0 |
| 704 | `death_collapse` | 1352 | 6008 | 47 | 50 | 42 | 9.1 | 1432 | 0 | 30 | 0 |
| 691 | `death_chest` | 2075 | 6005 | 30 | 44 | 32 | 0.8 | 68 | 3 | 30 | 0 |
| 122 | `death_chest` | 2109 | 6007 | 39 | 37 | 32 | 0.4 | 165 | 3 | 30 | 0 |
| 697 | `rifle_pain_kneestodeath` | 677 | 6004 | 46 | 56 | 7 | 0.3 | 33 | 4 | 60 | 0 |
| 642 | `rifle_pain_kneestodeath` | 671 | 6008 | 44 | 54 | 8 | 0.3 | 40 | 2 | 30 | 0 |
| 400 | `death_frontchoke` | 2852 | 6018 | 56 | 60 | 12 | 1.9 | 72 | 2 | 45 | 0 |
| 443 | `unarmed_pain_kneestodeath` | 664 | 6003 | 39 | 52 | 14 | 1.2 | 107 | 0 | 60 | 0 |
| 670 | `death_twist` | 1282 | 6007 | 46 | 55 | 6 | 0.7 | 613 | 3 | 30 | 1 |
| 646 | `death_run` | 1019 | 6013 | 47 | 48 | 8 | 1.7 | 51 | 3 | 30 | 0 |
| 663 | `death_backgrenade` | 1278 | 6012 | 22 | 69 | 20 | 2.5 | 658 | 1 | 30 | 0 |
| 656 | `rifle_wall_death_right` | 2739 | 6003 | 72 | 35 | 25 | 1.9 | 161 | 3 | 45 | 1 |
| 218 | `death_fall_back` | 1635 | 1277 | 55 | 60 | 7 | 0.2 | 46 | 1 | 30 | 0 |
| 700 | `death_crotch` | 1945 | 6005 | 24 | 28 | 38 | 6.1 | 1611 | 0 | 30 | 0 |
| 658 | `death_backgrenade` | 1291 | 6010 | 70 | 52 | 5 | 0.4 | 32 | 4 | 30 | 0 |
| 147 | `unarmed_pain_floortodeath` | 447 | 6009 | 52 | 39 | 10 | 0.3 | 37 | 5 | 45 | 0 |
| 165 | `death_run` | 812 | 1226 | 36 | 53 | 4 | 0.1 | 18 | 11 | 75 | 0 |
| 680 | `mp40_wall_death_right` | 2670 | 6008 | 44 | 88 | 31 | 5.0 | 1604 | 1 | 45 | 0 |
| 709 | `death_frontcrouch` | 590 | 6012 | 42 | 50 | 6 | 0.6 | 75 | 3 | 30 | 0 |
| 696 | `death_knockedup` | 1184 | 2243 | 55 | 63 | 5 | 0.4 | 30 | 3 | 30 | 0 |
| 36 | `death_fall_back` | 1635 | 6001 | 53 | 55 | 17 | 0.8 | 1098 | 3 | 45 | 0 |
| 729 | `death_back` | 1897 | 6002 | 52 | 58 | 52 | 8.7 | 1125 | 0 | 30 | 0 |
| 694 | `rifle_wall_death_right` | 2766 | 6005 | 34 | 56 | 41 | 7.4 | 131 | 0 | 30 | 1 |
| 681 | `death_backgrenade` | 1273 | 6015 | 12 | 48 | 72 | 1.1 | 305 | 0 | 30 | 0 |
| 127 | `death_grenade` | 1949 | 6006 | 56 | 28 | 17 | 0.7 | 118 | 2 | 30 | 0 |
| 142 | `death_shoot` | 1353 | 6001 | 46 | 59 | 11 | 0.4 | 39 | 2 | 45 | 0 |
| 815 | `unarmed_pain_floortodeath` | 436 | 6004 | 48 | 53 | 9 | 0.5 | 206 | 3 | 30 | 0 |
| 814 | `death_shoot` | 1346 | 6008 | 61 | 39 | 10 | 0.2 | 35 | 2 | 30 | 0 |

Plus one silent loss: `ent=145` (`german_wehrmact_soldier.tik`, `scene4_sniper4`) — pending-armed
12:42:23, never resolved. Same entity, same silent outcome, in the r8 session too.
