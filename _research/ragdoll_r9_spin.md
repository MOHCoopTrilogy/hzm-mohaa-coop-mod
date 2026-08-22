# Ragdoll round 9 — what actually causes the spin

Lens: derive the real mechanism behind "basically every body spins after it hits the ground", judge
the reactive fixes R1–R7 against it, and recommend a fix. Every claim carries a `file:line`. Every
number is re-derived here, not quoted. Where the evidence does not establish something, it says so.

Subject: `openmohaa-hzm/code/cgame/cg_ragdoll.c` (1759 lines, read in full),
`openmohaa-hzm/code/renderergl1/tr_ragdoll.cpp` + the gl2 copy (identical, 7625 B each), hooks at
`renderergl1/tr_model.cpp:857-859` (Hook A) and `:1819` (Hook B).
Data: `hzm-mohaa-coop-mod/_research/ragdoll_r9_session_live.log` (42 pending-arms, 41 settle-arms,
41 sleeps, 0 drops, 0 give-ups, 0 evictions, 0 BURIED refusals, 0 NaN/blowups, 0 mover-wakes),
`ragdoll_r8_session_1230.log`, `ragdoll_p3_session_2200.log`.

---

## 0. Verdict up front

**R5's stated theory is false.** The rotation estimate does not have an error that precesses. It is
provably *exact* for rigid motion (§3), and the loop gain in the yaw mode is exactly 1 — a pure
integrator, never > 1. There is nothing to amplify.

**The real mechanism is the opposite of R5's story, and it is structural:**

> `RagShapeMatch` is the **only** term in the whole simulation that can rotate a grounded corpse
> about the vertical (§2 — gravity and the constraint solver are provably yaw-free, collision is
> provably yaw-dissipative). And `RagShapeMatch` is fitted to a 4-point core whose three rotational
> degrees of freedom lie **exactly in its own null space** (§3): it exerts no restoring torque of any
> kind on the frame it is measured from. So the body has one completely unopposed rigid mode — yaw —
> and one term that pumps it. It rotates until the 6 s life cap stops it.
>
> The *pump* is the contact-gain flicker: `RAG_CONTACT_RELAX` (`cg_ragdoll.c:64,837`) steps the pull
> gain by **6.67×** between flagged and unflagged points, the flag cycles every **4 substeps**
> (§5, derived from sv_gravity 512 and the +0.25 u lift at `:924`), and the phase is independent per
> point. Sustaining the observed spin needs a systematic tangential bias of only **0.33 %** (§5).
> A 6.67× out-of-phase modulation is two orders of magnitude more than enough.

**R5 (slew + permanent latch): masks the mechanism, by accident, at an unacceptable cost. Replace.**
**R6 (ptPrev carry 0.85): correct change, wrong stated reason, wrong dose. Keep; raise to 1.0.**
Recommended fix in §8: make the shape-match **torque-free** instead of locking the orientation.

---

## 1. The spin is DRIVEN, not ballistic — damping proves it

`RAG_DAMPING 0.98` per 8 ms substep (`cg_ragdoll.c:60`, applied at `:859`).

- 125 substeps/s ⇒ per-second retention `0.98^125 = e^(-2.5253) = 0.0800`. **Velocity decays 12.5× per second.**
- Over the 6 s life cap: `0.98^750 = e^(-15.15) = 2.6e-7`.

A yaw imparted at the landing would be invisible inside ~0.5 s. The user reports rotation that lasts
until the body stops — and 36 of 41 bodies stop at the 6000 ms life cap (`:1353`), not on the speed
gate. **Therefore something re-injects yaw every substep at roughly the rate damping removes it.**
This single number rules out every "leftover impulse" explanation and forces the search onto
continuously-acting terms.

---

## 2. Only one term in the system can yaw the body

Taken term by term, in the order `RagStep`/`RagCollideWorld` apply them.

| term | site | yaw torque τ_z |
|---|---|---|
| gravity | `:868` `next[2] -= g`, uniform | `[Σ rᵢ × (0,0,−g)]_z ≡ 0` for any rᵢ. **Exactly zero, algebraically.** |
| parent distance links | `:876-883` | each projection moves `a` by `−corr·d` and `b` by `+corr·d`, `d = ptₐ − p_b`. Torque about **any** point `O` = `(rₐ − r_b) × F = d × (−corr·d) = 0`. **Exactly zero.** |
| braces / fold limits | `:888-899` | identical collinear equal-and-opposite form. **Exactly zero.** |
| collision normal impulse | `:940` `vn *= −0.1` | on a floor `plane.normal[2] > 0.7` (`:934,941`) the impulse is near-vertical ⇒ near-zero τ_z. A *wall* normal is horizontal and can yaw — but that is a one-shot event, not a 6 s drive. |
| collision friction | `:941` `×0.45` floors / `×0.75` walls | strictly contractive on the tangential component. **Removes yaw only.** |
| resting-contact full stop | `:934-939` `pt = ptPrev = pos` | zeroes the point's velocity outright. **Removes yaw only.** |
| Verlet damping / velocity cap | `:859`, `:860-864` | isotropic per-point contractions. **Removes only.** |
| mover startsolid shove | `:1067` `pt[i][2] += 2.5f` | purely +z. **Zero τ_z.** |
| **`RagShapeMatch`** | **`:820-847`** | **unbounded.** See below. |

### Candidate 5 (Gauss-Seidel ordering bias) is falsified

The concern is real for solvers whose constraints are not collinear pairs. Here *every* constraint —
the 14 parent links and all 16 braces — is a two-body distance projection along the line joining, on
equal masses. Sweep order changes the *convergence rate*, never the momentum: the pair impulse is
parallel to the separation vector, so its torque about any origin is `d × (k·d) = 0` identically.
**Reversing the sweep would change nothing about the spin.** Cross off.

### Why `RagShapeMatch` is unbounded

It is an **external field**, not an interaction. The loop runs `for (i = 1; ...)` (`:829`) — `pt[0]`
is never moved by it — and nothing anywhere receives a reaction. So

```
τ_shape(about pt[0])  =  Σ_{i≥1} aᵢ · (ptᵢ − pt₀) × dᵢ ,   dᵢ = (pt₀ + S·relᵢ) − ptᵢ
```

has no constraint forcing it to zero. A textbook shape-match (Müller/Heidelberger 2005) derives `S`
as the least-squares rotation over *all* points, and the optimality condition of that fit is
precisely `Σ rᵢ × dᵢ = 0` — the property that makes shape matching torque-free. **This
implementation derives `S` from 4 points via a Gram-Schmidt triad, so it does not have that
property, and nothing else in the file restores it.**

---

## 3. The shape-match's null space *is* the estimator's rotational DOF (the enabler)

This is the structural core of the whole finding. Row-vector convention throughout (`v' = v·M`,
`RagMat3RotateVec` at `:403-409`).

**(a) `RagTriad` commutes with rotation, so the estimator is exact.**
`RagTriad(p, q, T)` (`:380-401`) returns rows `x = p̂`, `y = normalize(q − (q·x)x)`, `z = x × y`.
Normalisation, projection and cross products all commute with a proper rotation `R`, so
`RagTriad(pR, qR) = RagTriad(p, q)·R`. Hence for a rigidly rotated point cloud `T1 = T0·R`, and
`S = T0ᵀT1 = R` (`:773-774`). **The estimate carries zero error for rigid motion. R5's premise —
"any error in the estimate rotates the goal, which drags the points, which re-rotates the estimate" —
has no error term to start from, and the loop gain in that mode is exactly 1: a pure integrator,
neither growing nor decaying.**

**(b) The correction on `pt[1]` is a pure length change.**
`rel₁ = goal₁ − goal₀` (`:832`, with `goal[] = pt[]` at capture, `:1569-1571`) `= restLen[1]·restDir[1]`
(`:636-639`). `restDir[1]` is row 0 of `T0`, so `restDir[1]·T0ᵀ = (1,0,0)`, and `(1,0,0)·T1 = x₁ =
normalize(spineNow)`. Therefore

> **`want₁ − pt₀` is exactly parallel to the *current* spine.**

`d₁` has no tangential component. Zero angular authority over the primary axis.

**(c) The hip line's rotation about the spine axis is uncorrected.**
`want₁₃ − want₁₁ = (rel₁₃ − rel₁₁)·S = hipLen · hipDir0 · S`. By construction of `T0`, `hipDir0`
lies in `span(x₀, y₀)`, so `hipDir0·T0ᵀ = (c, s, 0)` and the product is `c·x₁ + s·y₁` — inside the
`x₁y₁` plane, which is the plane already containing `hipNow`.

> **Zero component along `z₁ = x₁ × y₁`.** The correction adjusts the hip–spine *angle* and the hip
> *length*, never the hip line's roll about the spine.

**(d) Conclusion.** The map (core orientation) → (shape-match correction) has a 3-dimensional null
space that coincides exactly with the 3 rotational DOF of the core `{0, 1, 11, 13}`. The shape-match
**slaves the other 11 points to whatever the core is doing and never argues with the core**.

**This answers the brief's candidate 3 directly: no, there is no term anywhere in the system that
opposes rotation of the body about a vertical axis through the pelvis.** Friction *could* — the
resting full-stop at `:934-939` is ferocious, it zeroes a point outright — but it only fires on
points whose swept box actually re-enters geometry, and §5 shows that a settled point spends most of
its time 0.25 u proud of the surface where a horizontal sweep misses entirely.

The estimator is not wrong. It is **complicit**: because it is definitionally consistent with the
core, it guarantees the shape-match can never object to the core rotating.

---

## 4. The lever arms — measured from the shipped data, not assumed

Parsed `models/human/allied_army_soldier/usarmy.skd` out of retail `main/Pak0.pk3` (`SKMD` v5,
42 bones) with a throwaway reader written against `code/skeletor/skeletor_model_file_format.h`
(`boneFileData_t` = 32 + 32 + 5×int = 84 B; `SKELBONE_ROTATION` base data = `offset[3]`,`length`,
`weight`,`bendRatio`, `skeletor_model_files.cpp:39-48`; `SKELBONE_IKSHOULDER` = quat[4] + pos[3]).
Game units = raw × the human TIK `load_scale` 0.52.

| segment | raw | game u |
|---|---:|---:|
| Pelvis → Spine1 — **estimator PRIMARY** (`:771`) | 20.198 | **10.50** |
| L Thigh → R Thigh — **estimator SECONDARY** (`:772`, `basePos.z = ±9.1826`) | 18.365 | **9.55** |
| Pelvis → Spine2 | 31.900 | 16.59 |
| Pelvis → Neck | 53.567 | 27.86 |
| Pelvis → Head | 59.779 | **31.09** |
| Thigh → Calf | 46.350 | 24.10 |
| UpperArm → Forearm / Forearm → Hand | 25.604 / 25.969 | 13.31 / 13.50 |

**Correction to the brief's premise.** The code's primary axis is Pelvis → **Spine1**, 10.50 u — not
31 u; 31 u is Pelvis → **Head**. So the two estimator legs are 10.50 u and 9.55 u: **near-identical,
and both ≈ 3× shorter than the body they steer.** The hip is not disproportionately noisy relative to
the spine (10 % difference); *both* are short.

**Angular sensitivity.** A transverse displacement ε (game u) of one estimator endpoint tilts that leg by

- spine: `ε / 10.50 = 0.0952 ε` rad = **5.46° per unit**
- hip: `ε / 9.55 = 0.1047 ε` rad = **6.00° per unit**

**Which axis.** Gram-Schmidt keeps the primary exact, so error in the **secondary (hip)** rotates the
goal frame **about the spine axis** — for a corpse lying down that is a *roll about its own long
axis*. Error in the **primary (spine)** rotates about axes perpendicular to the spine — **pitch and
yaw**. So the yaw the user sees is driven by motion of `Bip01 Spine1` relative to `Bip01 Pelvis`, a
10.5 u lever.

**Amplification at the shell.** head `31.09/10.50 = 2.96×`; calf `≈25/10.50 = 2.38×`; a fully
extended hand (shoulder ≈17 + 13.31 + 13.50 ≈ 44 u) `4.2×`. A 0.5 u wobble of Spine1 about the Pelvis
swings the goal head position ~1.5 u — the same order as the measured `drift` (0.1–9.1, **mean 1.96
across the 36 cap-riders**, mean 0.28 across the 5 speed-sleepers).

Sanity check against the log: sleep `span` is typically ~50 × 50 × 10 u, so mean shell radius from the
pelvis ≈ 20 u. Consistent.

---

## 5. THE DRIVE — the contact-gain flicker (ranked #1)

This is the brief's candidate 2, but not in the form it was posed. It is **not** a static
contact-vs-airborne split; it is a per-point, out-of-phase, 6.67× gain modulation applied to exactly
the points whose residual is largest.

**The gain step.** `RAG_CONTACT_RELAX 0.15` (`:64`) applied at `:836-838`; `alpha = rag_stiff = 0.25`
(all 41 sleep lines read `alpha=0.25`). Flagged point: `0.0375`. Unflagged: `0.25`. **Ratio 6.67×.**

**The flag is a 2-substep memory** decremented at the head of `RagCollideWorld` (`:991-993`) and
re-armed only when the swept box actually hits (`:1021-1023` → `:934-939`).

**The clock.** The resting branch parks the point at `tr.endpos + 0.25·normal` (`:924`) — i.e. **0.25 u
proud of the surface it was flush with** — with velocity zeroed. `sv_gravity` default is **512**
(`docs/generated/CVARS_ENGINE.md:2118` → `fgame/gamecvars.cpp:348`), read at `:297`. With
`dt = 8 ms`:

```
g_step = 512 × 0.008²                    = 0.032768 u per substep
Δz_n   = 0.98·Δz_(n-1) − g_step
cumulative drop: 0.0328, 0.0977, 0.1941, 0.3214   →  crosses 0.25 u on substep 4  (32 ms)
```

A purely *horizontal* sweep of a box whose bottom starts 0.25 u above the plane cannot hit it, so a
sliding settled point generates **no trace hit and therefore no friction** until gravity has pulled it
back through those 0.25 u.

**The cycle**, per settled point: hit → `contact = 2` → dec to 1 → dec to 0 → **1–2 substeps at the
full 0.25** → hit again. Time-averaged gain `= 0.4×0.25 + 0.6×0.0375 = 0.1225`, **3.3× the intended
contact gain, modulated at ~31 Hz, with a phase set independently per point** by its clearance,
radius and residual. Worse: a point that is *exactly* motionless is skipped entirely by the
early-out at `:998` (`VectorLengthSquared(d) < 0.0001`), so it never re-arms and sits at the full
0.25 indefinitely.

**How much bias does the spin actually need?** Steady state requires the pump to replace what damping
removes: 2 % of the tangential momentum per substep.

- Observed: 36/41 bodies never clear the 10 u/s sleep gate (`:1348`) for a full second. Mean shell
  radius ≈ 20 u (§4) ⇒ `ω ≈ 10/20 = 0.50 rad/s = 28.6 °/s` ⇒ **≈ 172° over the 6 s cap.** That is
  precisely "a very slow spin" that "eventually stops" — and it stops because `lifeMs > 6000` fires
  (`:1353`), not because the body came to rest.
- Required injection per point per substep = `0.02 × 20ω = 0.02 × 10 u/s = 0.2 u/s` of tangential
  speed = **0.0016 u of tangential displacement**.
- The pull supplies `a·d = 0.25·d`. With mean drift 1.96 u: required systematic tangential fraction
  = `0.0016 / (0.25 × 1.96)` = **0.33 %**. Even at the tightest observed drift (0.3 u): **2.1 %**.

**A 6.67× out-of-phase gain modulation is two orders of magnitude larger than the 0.3–2 % bias
needed.** The spin is not merely possible under this mechanism — it is overdetermined. The surprise
would be a body that *didn't* spin, which is exactly what the user reported ("basically every body").

---

## 6. THE TRANSPORT — the ptPrev omission (brief's candidate 4, R6's territory) — ranked #2

**As a launcher it is weak.** Linearise the pre-R6 pull about the target (`D = 0.98`, `a = 0.25`;
ordering: integrate `:854-870` → constraints `:871-901` → shape-match `:913`):

```
e_(n+1) = (1−a)(1+D)·e_n − (1−a)D·e_(n−1) = 1.485·e_n − 0.735·e_(n−1)
λ² − 1.485λ + 0.735 = 0 ,  disc = −0.735  ⇒  |λ| = √0.735 = 0.857 ,  θ = 0.5215 rad
```

⇒ a **10.4 Hz oscillation decaying with a 52 ms time constant**. The ordinary radial pull is a stiff,
well-damped spring; it does not compound into a launch on its own. (The launches came from R1 — §7.)

**As a spin driver it is essential.** Without it the §5 gain modulation would only jiggle positions;
with it, every modulated pull deposits `a·d` into the next substep's velocity, which is what carries
the tangential bias forward into sustained rotation.

**It also corrupts the sleep gate, which is why nothing sleeps.** The gate (`:1337-1341`) measures
`|pt − ptPrev|` **after** `RagShapeMatch` has moved `pt` alone, so it counts the pull itself as speed:
`0.25 × drift` per substep = **31.25 × drift u/s**. Against a 10 u/s gate:

> **any body with mean drift > 0.32 u can never speed-sleep — as a pure measurement artifact.**

Evidence, from `ragdoll_r9_session_live.log`:

| | n | mean drift | median maxspd |
|---|---:|---:|---:|
| rode the 6 s cap | **36** | **1.96** | 124.5 |
| speed-slept (1226–4277 ms) | **5** | **0.28** | 44 |

A 7× separation, and the sleepers cluster on the correct side of the 0.32 u prediction (3 of 5 below;
6 of 36 cap-riders below, i.e. the other contributions — constraint corrections and collision resolve —
account for the rest).

**Independent cross-check.** `ragdoll_p3_session_2200.log` is the mode-3 free branch, which never
calls `RagShapeMatch` (gated at `:902`). Sampled sleeps: 5709, 3262, 4243, 3204, 1948, 3578, 2248,
3763, 6019, 1744, 6018, 2317, 6004, 2762, 5964 ms — **11 of 15 speed-slept**, versus 5 of 41 on the
settle branch. **The shape-match is what stops bodies sleeping.** That is a clean A/B in the archived
data.

R6 carries 0.85, so the artifact term drops to `0.0375 × drift = 4.7 × drift u/s` and the sleep block
moves from `drift > 0.32` to `drift > 2.1` — which would flip roughly 31 of the 36 cap-riders to
speed-sleeping. **R6 is a real fix for a real defect.** But 15 % of the injection survives, so §5's
drive survives at 15 % strength: a slow spin becomes a slower spin, not no spin.

---

## 7. R1 as a resonant pump — explains the violent minority, not the universal spin (my candidate 6)

`c009ca62` made a `startsolid` point on the settle branch clear its contact flag (`:1013-1019`)
instead of freezing it. A point buried in a wall then receives the **full** 0.25 pull toward a goal
that may be 10–30 u away:

```
position jump      = 0.25 × 30 u  = 7.5 u in one substep
injected velocity  = 7.5 u / 8 ms = 937 u/s        (pre-R6 the pull did not carry ptPrev)
```

It is still in solid on the next substep, so it is released again — **a pump that re-fires every
substep, applied to exactly one point, i.e. maximum torque per unit of injection.**

Evidence: 9 of 41 bodies recorded `maxspd ≥ 613` (613, 658, 1087, 1098, 1125, 1153, 1432, 1604,
1611). Seven of those nine also show `contacts = 0` or `1`, and they carry the largest drifts (9.1,
8.7, 6.1, 5.0, 2.5). That is the "one body fell and started spassing and glitching across the world
(flying even)" report. (`maxspd` is measured after the shape-match and collision, so it is a
displacement rate, not a velocity — it can legitimately exceed the 3000 u/s pre-R7 cap.)

R7's 8 u/substep cap and 200 u AABB net are correct containment. **They bound the pump; they do not
remove it.** The release itself is right — freezing a buried point anchors the body and the rest
tears around it (the original `c009ca62` report) — but the release must not hand the point
full-strength authority.

---

## 8. Verdicts

### R5 — slew 0.12 + permanent latch. Right patch, wrong theory, cost far higher than stated. **Replace.**

**Theory falsified.** §3(a) proves `S = R` exactly for rigid motion. There is no estimation error to
precess and the loop gain is exactly 1, not ≥ 1. The comment at `:781-786` describes a mechanism that
does not exist.

**But the latch does hit the real mechanism, by accident.** Once `S` is frozen at `S_lock`,
`want₁ − pt₀` has a **fixed world direction** instead of tracking the current spine, and
`want₁₃ − want₁₁` likewise. The null space of §3 is destroyed and the shape-match acquires full
3-DOF orientation authority over the core — **which is exactly the missing restoring torque.** It
works for the opposite reason to the one written down.

**Cost, precisely:**

1. **It fires almost immediately, and it welds the corpse to its capture orientation.** `nContact >= 3`
   (`:796`) is sampled 3–5× per frame (see 3 below) on a body that was captured *already landed* with
   4–8 floor contacts. 40 of 41 bodies in the log registered a first world contact
   (`RAGDOLL contact` fires once per body, `:945-951`); mean flagged count at sleep is 2.51 with a
   max of 11, and §5 shows a resting point is flagged ~50 % of the time — so 3 simultaneous flags
   occurs within the first frames. That is while `rampMs < 300` still holds `alpha ≈ 1.0` (`:912`)
   and `gravScale` is still ramping 0→1 (`:1302`): **the body is welded before physics has taken the
   wheel at all.** The entire purpose of the settle branch — draping onto stairs, sandbags, a slope,
   a crate — *is a rotation*, and it is now forbidden. A slope can only tilt the body against a
   0.25/substep spring, i.e. barely.
2. **`rotLocked` has no clearing path.** The mover-wake block (`:1280-1292`) resets `state`,
   `sleepMs`, `lifeMs`, `accumMs` — and nothing else. `rotLocked`, `bodyRot`, `bodyRotValid` and
   `contact[]` all persist. **An elevator can carry a corpse but never tilt it**, and a body pushed
   later by a mover or an explosion cannot re-orient at all. `CG_RagdollClearEnt` (`:318`) memsets the
   whole sim, so only a *new* corpse gets a fresh orientation.
3. **The dose is wrong and frame-rate dependent, and the render path mutates the sim.**
   `RagBodyRotation` is not pure — it advances `s->bodyRot` on every call — and it is called from
   three places: `RagShapeMatch` (`:828`, once per substep), **`RagPush` (`:1145`, once per frame,
   which only wants to *read* the orientation)**, and **the sleep debug print (`:1371`, so
   `r_ragdollDebug 1` changes the simulation)**. Substeps per frame = `floor(frametime/8)` capped at 4
   (`:1308`). Effective per-frame adoption `= 1 − 0.88ⁿ`:

   | fps | substeps | calls/frame | adoption |
   |---:|---:|---:|---:|
   | 125 | 1 | 2 | 22.6 % |
   | 60 | 2 | 3 | **31.8 %** |
   | 30 | 4 | 5 | 47.2 % |

   Nominally 12 %. It is 2.7× that at 60 fps and varies 2× across the supported frame-rate range.

### R6 — carry ptPrev at 0.85. Correct change, wrong stated reason, arbitrary dose. **Keep, raise to 1.0.**

The commit's reason ("compounds into a launch") is wrong for the ordinary case — §6 shows a stable
10.4 Hz spring with a 52 ms decay. The launches were R1's (§7). But the change is important for two
reasons the commit does not name: it removes 85 % of the momentum transport that turns §5's gain
modulation into rotation, and 85 % of the sleep-gate artifact.

**0.85 has no derivation.** The comment's justification — "leaves a little genuine settling motion" —
is backwards: the settling motion should come from gravity and collision, not from the attractor.
**1.0** makes the shape-match a pure positional projection with zero momentum injection, which is
what a drape attractor should be; the distance links are the thing that is supposed to transmit
impulses.

### Others

- **R3 (drop the `interpolate` gate)** — unambiguously correct. 41 arms / 42 pendings vs 18 / 82, with
  0 drops, 0 give-ups, 0 evictions in the r9 log. Keep.
- **R4 (radius clamped to authored clearance)** — correct in principle and it fixed a real hover. But
  it is what makes the resolved point sit 0.25 u proud of a surface it was flush with, which is the
  clock driving §5's flicker. Address in fix 4 below, do not revert.
- **R7 (cap 24→8, 200 u AABB revert)** — sound containment. Keep.
- **R2 (diagnostics)** — keep, but see §9: the log carries no rotation instrument at all, which is why
  R5 could be written and shipped without evidence either way.
- **R8 (scripts)** — outside this lens; not evaluated here.

### Is "freeze the whole sim at rest and hold the pose" strictly better than the rotation latch?

**Yes on every axis — but it is not sufficient on its own.**

- **Reversible.** `state = 2` already has a tested wake path (`:1282-1289`), so a frozen body that a
  mover touches resumes with a live `S`. `rotLocked` has *no* clearing path at all.
- **Non-invasive.** A freeze only decides *when to stop*; the latch changes what the simulation
  computes from frame ~3 onward, for the entire settle.
- **It is what the user asked for.** "They eventually stop" is a request for rest, not for a welded
  orientation. A corpse at rest genuinely is a static pose; there is no visual cost.
- **But it cannot fire today.** The freeze can only trigger when the body is *measured* at rest, and
  §6 shows the measurement is corrupted, while §5 shows the body genuinely is not at rest. Freeze
  alone, with the current gate, *is* the 6 s life cap — i.e. exactly the current behaviour and the
  current complaint. Fixes 1 and 2 below are what make the freeze reachable.

---

## 9. Recommended fix

Do not lock the orientation. Give the shape-match the property it is missing — **be torque-free** —
and let the body sleep honestly. All of this is local to `cg_ragdoll.c`; no new cgame imports are
needed (`cg_public.h` already exposes everything used, and `q_math.c` is compiled into the cgame
module — `code/cgame/CMakeLists.txt:13`).

1. **`RagShapeMatch`: carry `ptPrev` fully.** `:845` → `VectorMA(s->ptPrev[i], a, d, s->ptPrev[i])`.
   Zero momentum injection; the pull becomes a pure positional projection. This also makes the sleep
   gate measure real motion, so the threshold at `:1348` can go back to ~4 u/s (its pre-bug-1962
   value) instead of the 10 that was raised to clear an artifact.

2. **Make the correction torque-free *and* force-free about the point cloud's own centroid.** After
   computing all `dᵢ` and before applying them:

   ```
   wᵢ = aᵢ ;  c = Σwᵢptᵢ / Σwᵢ ;  rᵢ = ptᵢ − c
   F  = Σwᵢdᵢ / Σwᵢ                       ;  dᵢ −= F
   τ  = Σwᵢ (rᵢ × dᵢ)
   I  = Σwᵢ (|rᵢ|²·Id − rᵢrᵢᵀ) ;  ω = I⁻¹τ ;  dᵢ −= ω × rᵢ
   ```

   ~40 lines and one 3×3 inverse. This makes §2's **sole** yaw source **provably zero**, so the only
   things that can rotate a corpse are gravity, collision and movers — which is the correct physics,
   and which *restores* the draping, rolling and mover response that the latch forbids.
   **Include `pt[0]` in the sums** (it is excluded from the pull entirely at `:829`) so the frame is
   the body's centroid rather than one un-corrected particle; that also removes the translation pump
   whereby the whole goal frame follows a single free pelvis.

3. **Optional, and it makes (2) automatic.** Replace the 4-point triad with a polar-decomposition fit
   over all 15 points — Müller's iterative rotation extraction, 3–5 iterations of
   `ω = (Σ r̂ᵢ × ĝᵢ)/(|Σ r̂ᵢ·ĝᵢ| + ε)`, `q ← exp(ω/2) ⊗ q`. At the optimum `Σ rᵢ × dᵢ ≡ 0` by
   construction — that *is* the classical shape-matching property — and it deletes the 2.4–4.2× lever
   amplification of §4. Verified available in cgame: `MatToQuat` (`qcommon/q_math.c:1823`),
   `QuatToMat` (`:1783`), `QuatFromRotAngleAxis` (`:4026`), `QuatMultiply1` (`:4092`).

4. **Stop the flicker.** Cheapest correct version: in the resting branch at `:934-939`, park the point
   at `tr.endpos` with **no** `+0.25·normal` lift, and set `contact[i] = 6` (≥ the 4-substep re-hit
   period of §5) instead of 2. Better still, hold the flag while the point is within
   `radius + 0.5 u` of a surface rather than only on the substep it hits.

5. **R1: release, but at the contact gain.** At `:1017`, set `s->contact[i] = 2` (relaxed pull) rather
   than `0`, or clamp the extraction to ≤ 1 u/substep along the shortest exit. A 30 u residual must
   not be able to become a 937 u/s impulse.

6. **Then freeze properly.** With (1) the gate reads real motion, so sleep at ~4 u/s sustained for
   250 ms and stop simulating. That delivers "it lands and stays landed" without forbidding
   re-orientation, because the mover-wake path re-enters with a live `S`. **If any latch is kept at
   all, clear `rotLocked`, `bodyRotValid` and `contact[]` in the mover-wake block (`:1280-1292`).**

7. **Housekeeping.** Make `RagBodyRotation` pure (compute-only, `const ragSim_t *`) and advance the
   filter from exactly one place, once per substep, so `RagPush` (`:1145`) and the debug print
   (`:1371`) stop mutating the simulation.

**Sequencing.** (1) + (4) + (5) are ~15 lines and should ship first — they are individually safe and
each has an independent justification. (2) is the actual spin fix. (3) is the principled version of
(2) and can wait. (6) is what the user perceives as "fixed".

---

## 10. The numbers that would confirm each candidate in the live log

The current log has **no rotation instrument at all** — which is precisely how R5 could be written,
escalated to a permanent latch 53 seconds later (`877b132f` 12:43:44 → `35428898` 12:44:37, far too
short to have built, deployed and playtested the first), and shipped, without evidence either way.
Add these to the sleep line:

| field | what it settles | prediction |
|---|---|---|
| **`yaw=`** — z-component of the axis-angle of `bodyRot_now · bodyRot_(1s ago)ᵀ`, in °/s | **the whole question.** Nothing today measures rotation. | §5 predicts **30–90 °/s** pre-fix; **< 3 °/s** after fix (2) |
| `tauz=` — `Σ aᵢ[(ptᵢ−pt₀) × dᵢ]_z` accumulated over the body's life | that `RagShapeMatch` is the sole yaw source (§2) | is the entire yaw budget pre-fix; **≈ 0 by construction** after fix (2) |
| `spd_real=` — the sleep metric recomputed on the velocity captured **before** `RagShapeMatch` | that the sleep failure is a measurement artifact (§6) | cap-riders show `spd_real` well **under** 10 while `speed` is over it |
| `fullpull=` — % of substeps a point with a floor contact in the last 8 substeps got the full alpha | the flicker drive (§5) | **~40 %** today; ~0 after fix (4) |
| `vinj=` — `Σ\|a·d\|` per substep | the transport (§6) | `31.25 × drift` u/s pre-R6, `4.7 × drift` at 0.85, **0** at 1.0 |
| `startsolid=` — count of settle-branch startsolid releases | R1's pump (§7) | strong correlation with `maxspd ≥ 500` (currently **9 / 41**) |
| `rotlockAt=` — `lifeMs` at which `rotLocked` latched | the latch's true cost (§8) | predicted **< 100 ms**, i.e. before the alpha/gravity ramps finish |

`rotlockAt=` is the cheapest and most decisive of the seven for the immediate decision: if it reads
under 100 ms on most bodies, the settle branch is currently disabled in all but name.

---

## 11. Confidence

- **§2 (only `RagShapeMatch` can yaw) and §3 (its null space is the estimator's rotational DOF)** —
  **high, ~90 %.** These are algebraic identities on code I read line by line, not inferences from
  behaviour. They are also the claims that matter most, because together they mean the fix is
  structural, not a tuning constant.
- **§4 (lever arms)** — **high.** Measured from shipped `Pak0.pk3` data with a reader written against
  the engine's own format header. It also corrects the brief's 18-vs-31 premise.
- **§6 (the sleep failure is largely a measurement artifact)** — **high, ~85 %.** Two independent
  confirmations: the 7× drift separation between cap-riders and speed-sleepers, and the mode-3 A/B
  where the same sim with no shape-match slept 11 of 15.
- **§5 (the contact flicker is the *dominant* drive)** — **medium-high, ~70 %.** The gain step, the
  4-substep clock and the 0.33 % bias budget are all derived, and the mechanism is
  order-of-magnitude sufficient. What I cannot do from the archived data is *rank* it against §6 and
  §7, because no logged field measures rotation. `yaw=` and `fullpull=` settle it in one session.
- **§7 (R1's pump)** — **medium, ~65 %.** The arithmetic is solid and the `maxspd ≥ 613` / `contacts ≤ 1`
  correlation is suggestive, but 9 of 41 is a small sample and both archived sessions are post-R1, so
  there is no clean A/B.
- **R5's stated theory is wrong** — **high, ~90 %.** §3(a) is a proof, not an argument.
