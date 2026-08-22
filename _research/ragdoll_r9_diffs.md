# Ragdoll round 9 — line-by-line audit of the reactive playtest diffs (R1–R7)

Audit date 2026-08-20. Subject: `openmohaa-hzm/code/cgame/cg_ragdoll.c` (1759 lines) as of
`35428898`, and the five commits made after the round-8 spec build `ff57cdff`.

| tag | commit | time | what it did |
|---|---|---|---|
| R1 | `c009ca62` | 12:14:50 | settle branch releases wall-clipped (startsolid) points instead of freezing them |
| R2 | `5deb1132` | 12:19:24 | pending-eviction print (diagnostics only) |
| R3+R4 | `62b92b14` | 12:33:21 | drop the `cent->interpolate` gate from the pending lifecycle; clamp per-point collision radii to authored-pose floor clearance |
| R6+R7+R5a | `877b132f` | 12:43:44 | shape-match carries `ptPrev`; velocity cap 24→8 u/substep; `RagSane` 200u AABB; `RagBodyRotation` 0.12 slew |
| R5b | `35428898` | 12:44:37 | latch the rotation lock permanently at 3 contacts |

## What is and is not backed by live data

`git diff --stat ff57cdff..HEAD` = **one file, 138 insertions / 22 deletions**. The renderer
bridge (`renderergl1/tr_ragdoll.cpp`, `renderergl2/tr_ragdoll.cpp`, both `tr_model.cpp`) was
**not touched by any commit in this batch** — verified with
`git log ff57cdff..HEAD -- <those four paths>` returning empty, and gl1/gl2 `tr_ragdoll.cpp`
still byte-identical. So bug-1963's Hook-A `load_scale` contract and bug-1964's conjugation
cannot have been regressed on the renderer side.

`ragdoll_r9_session_live.log` was archived 12:48; the live `qconsole.log` is the same 1621793
bytes and was last written 12:47. **That session ran the `62b92b14` build.** Therefore:

- **R1, R2, R3, R4 are exercised by the r9 log.**
- **R5, R6 and R7 have never been run.** Every claim about them below is static analysis.

---

# ⚑ R3 VERDICT — the `lerpOrigin` question, answered definitively

**R3 IS SAFE. `cent->lerpOrigin` / `cent->lerpAngles` are neither stale nor garbage for a
non-interpolating corpse, and R3 is NOT the cause of the spinning or the flying.**

The proof, from the engine, not from the ragdoll code:

1. **What `interpolate` means.** It is set `qtrue` in exactly one place —
   `cg_snapshot.c:339`, inside `CG_SetNextSnap` — and only for entities that were in the
   previous snapshot with an unchanged `parent` and `modelindex` and no `EF_TELEPORT_BIT`
   toggle (`cg_snapshot.c:330-340`). It means precisely *"`cent->nextState` is valid to
   interpolate toward"*, nothing else. It carries no information about `currentState`.
2. **It is cleared unconditionally on every transition.** `cg_snapshot.c:151`,
   `cent->interpolate = qfalse;` at the end of every `CG_TransitionEntity`. So it is false in
   the whole window between a snapshot transition and the arrival of the next snapshot — for
   *every* entity in the game, alive or dead. That is why 63 of 63 dropped pendings printed
   `interp=0`, and why the minimum drop age was **0 ms** (re-derived below): the pending was
   created inside `CG_TransitionEntity` (call site `cg_snapshot.c:140`) and the very next line
   of engine code set `interpolate` false.
3. **What is consumed instead.** `CG_CalcEntityLerpPositions`, `cg_ents.c:499-503`:

   ```c
   if (!cent->interpolate) {
       VectorCopy(cent->currentState.angles, cent->lerpAngles);
       VectorCopy(cent->currentState.origin, cent->lerpOrigin);
       return;
   }
   ```

   A **defined, snapshot-exact value**, not a stale one. It is refreshed **every frame** —
   `CG_AddPacketEntities` (`cg_ents.c:669-685`) calls `CG_AddCEntity` → this function for
   every entity in `cg.snap->entities`, unconditionally. `CG_ResetEntity` (`cg_snapshot.c:44-46`)
   also seeds both fields from `currentState` on the non-interpolating transition, so there is
   no uninitialised window either.
4. **The set `CG_AddPacketEntities` covers is exactly the set `currentValid` describes** —
   `cg_snapshot.c:229-232` clears `currentValid` for the old snap, `241-251` sets it for the
   new one. R3 kept `cent->currentValid` in the guard (`cg_ragdoll.c:1504`). So every corpse
   that survives the pending check is an entity whose `lerpOrigin` was written this frame.
5. **The value it holds is the right one anyway.** By the time `RagServerParked()` is true,
   `Actor::BecomeCorpse` has already run `CheckGround()` / `droptofloor(64)` and called
   `setMoveType(MOVETYPE_NONE)` (`fgame/actor.cpp:12501-12520`). The origin is final. Snapping
   and lerping give the same number.

The only behavioural difference R3 introduces is that `lerpOrigin` **snaps at snapshot
boundaries instead of ramping**, and for a parked corpse the ramp is flat. The r9 evidence
agrees: 41/42 clean arms, `drift ≤ 2.0u` on 33 of 41, and the 8 pathological bodies correlate
with `contacts=0` and `maxspd > 1000`, not with placement error.

**Two real but minor consequences of R3 are logged as F10 and F16 below.** Neither is the
artifact the user is seeing.

---

# Invariant regression check (the five hard-won ones)

| # | invariant | anchor | status |
|---|---|---|---|
| 1 | current-frame entity placement in `RagPush` (bug-1964) | `cg_ragdoll.c:1119-1120`, `1177-1185` | **INTACT** — untouched by the batch |
| 2 | `Ecap * S * Enow^T` rotation conjugation (bug-1963) | `cg_ragdoll.c:1163-1166`, applied `1190-1195` | **INTACT** |
| 3 | `load_scale` offset contract, other half in the renderer (bug-1963) | `cg_ragdoll.c:541-543` ÷ entity scale; `tr_ragdoll.cpp:147-156` `×(1/load_scale) − load_origin` | **INTACT** — renderer files not in the diff |
| 4 | split of the position path (`rotNow`) from the rotation path (`conj`) | `cg_ragdoll.c:1174` vs `1192` | **INTACT structurally**, but see **F2/F3** — the `S` fed into *both* is no longer the measured pelvis |
| 5 | per-substep collision ordering (bug-1962) | `cg_ragdoll.c:1308-1317` `subStart` → `RagStep` → `RagCollideWorld` | **INTACT** |

No commit in this batch reverses bug-1962, 1963 or 1964. **Nothing in the batch is critical by
that test.** The critical findings below are new defects, not regressions of the old ones.

---

# Findings, ranked

## S1 — definite defects, fix before the next playtest

### F1 · R4 · `ptRadius[]` is READ 98 lines before it is WRITTEN — the capture pre-lift now runs a POINT trace

`cg_ragdoll.c:579-581` (read) vs `cg_ragdoll.c:677` (write).

```c
579:  VectorSet(pm, -s->ptRadius[i], -s->ptRadius[i], -s->ptRadius[i]);
580:  VectorSet(px,  s->ptRadius[i],  s->ptRadius[i],  s->ptRadius[i]);
581:  cgi.CM_BoxTrace(&tr, above, s->pt[i], pm, px, 0, MASK_DEADSOLID, qfalse);
...
677:  s->ptRadius[i] = clear;
```

R4 rewrote the pre-lift's box from the const table `s_ragPtRadius[i]` to the new member
`s->ptRadius[i]`, but the member is not filled until the clamp loop at 661-678, *after* the
pre-lift. The slot arrives from `RagAllocSlot` `memset` to zero (`cg_ragdoll.c:1435`; both
`RagCapture` call sites, 1446 and 1559, pass a freshly-memset slot). **`s->ptRadius[i]` is
therefore identically 0.0 at line 579 on every capture, every time.**

What that does live, verified in the collision model:

- `cm_trace.c:1377-1380` — a zero-size box sets `tw.isPoint = qtrue`. The pre-lift is now a
  **point trace**, not a box sweep.
- `cm_trace.c:538` — `if (!(brush->contents & CONTENTS_FENCE) || !tw->isPoint)`. A point trace
  **skips every `CONTENTS_FENCE` brush**. `MASK_DEADSOLID` includes `CONTENTS_FENCE`
  (`fgame/bg_public.h:643`), so the pre-lift now sees straight through railings, grates and
  fence brushes it was written to lift off.
- The lift target changes meaning. `tr.endpos` for a 7u box is 7u above the surface; for a
  point it is *on* the surface (+0.25 at line 584). So a pre-lifted point is now seated flush.
  The clamp loop at 661-678 then measures ~0.25u of clearance under it and clamps that point's
  radius to the 1u floor (line 674-676) — **F1 silently forces F4 and F6 to their worst case on
  exactly the points that most needed the standoff.**

**Fix:** revert lines 579-580 to `s_ragPtRadius[i]`, *or* move the clamp loop (661-678) to run
before the pre-lift and re-run it afterwards on the lifted positions. The first is one line and
restores round-8 behaviour exactly; the second is more correct but is a design change.

### F2 · R5 · `RagBodyRotation` became a stateful mutator but still has three callers, two of which are not the simulation

`cg_ragdoll.c:763` (signature changed `const ragSim_t *` → `ragSim_t *`), call sites at
**828** (`RagShapeMatch`, per substep, settle branch only), **1145** (`RagPush`, per frame,
*both* branches) and **1371** (the sleep debug print, inside `if (rag_debug->integer)`).

Every call now advances the 0.12 slew (`cg_ragdoll.c:800-810`) and can set the permanent latch
(`797`). Three consequences, all live:

1. **The filter rate is frame-rate dependent and caller-count dependent.** Per rendered frame
   the function runs `steps + 1` times (`steps` is 0–4, `cg_ragdoll.c:1308`). At 30 fps a body
   takes 4 substeps → 5 blends/frame → 150 blends/s. At 250 fps typically 0–1 substeps → 1–2
   blends/frame → ~375 blends/s. **The rate at which the spin decays changes by 2.5× with the
   player's framerate.** Whatever tuning comes out of the next playtest is only valid at that
   player's fps.
2. **`r_ragdollDebug 1` changes the simulation.** The call at 1371 is inside the debug-only
   block and mutates `bodyRot` / can flip `rotLocked`. The instrument perturbs what it measures;
   any A/B run with debug on and off is not comparable.
3. **The free branch (mode 3, the live A/B control) is now filtered and latched too.**
   `RagShapeMatch` is gated by `if (s->branch)` (`cg_ragdoll.c:902`), so on mode 3 the *only*
   caller is `RagPush`. Free-branch corpses do reach the resting-contact branch —
   `RagResolveHit` sets `contact[i] = 2` with no branch test (`cg_ragdoll.c:937`) — so a mode-3
   corpse that lands **latches `rotLocked` and freezes its rendered pelvis orientation while the
   sim keeps tumbling.** Mode 3 no longer renders what it simulates, which quietly invalidates
   it as the A/B baseline.

**Fix:** split the function. `RagBodyRotationRaw(const ragSim_t*, float S[3][3])` = the pure
fit (no state). One advance-the-filter call per *substep*, made from `RagStep` before
`RagShapeMatch`, gated on `s->branch`. `RagPush` and the debug print read `s->bodyRot` directly
(or call the raw fit on the free branch). That restores "ONE producer" as the function's own
banner at `cg_ragdoll.c:761-762` claims.

### F3 · R5b · `rotLocked` never unlatches — a corpse on a rotating mover renders permanently mis-oriented

`cg_ragdoll.c:796-799` sets `s->rotLocked = 1` and nothing anywhere clears it short of the slot
being memset.

The mover-wake path (`cg_ragdoll.c:1280-1292`) resets `state`, `sleepMs`, `lifeMs` and
`accumMs` — **but not `rotLocked` and not `bodyRotValid`**. `RagMoverHash` explicitly includes
`movers[m]->lerpAngles[1]` (`cg_ragdoll.c:974`), i.e. it is *designed* to wake bodies on
rotating bmodels. So the one case the wake exists for — a corpse on a rotating door or a
turning platform — wakes up and then refuses to re-fit its orientation for the rest of the map.
The pelvis and every channel the anchor table binds to sim point 0 (`"Bip01 Spine"` →
`cg_ragdoll.c:266`, plus the nearest-fallback gear bones) render at the pre-mover orientation
around a pelvis that has moved.

Second, weaker case: the latch fires on `nContact >= 3` measured on the **2-substep contact
memory**, which is a transient. Three points can touch during a tumble, well before the body is
at rest. Once that happens the shape-match goal is frozen at a mid-landing orientation and every
subsequent pull drags the corpse back toward it — the opposite of "physics only DRAPES".

**Fix:** clear `rotLocked` (and let `bodyRotValid` stand) in the mover-wake block at
`cg_ragdoll.c:1283-1286`. And require the latch to be *earned*: `nContact >= 3` sustained for N
consecutive substeps, or `nContact >= 3 && meanSpeed < gate`, rather than one transient frame.

---

## S2 — high: reachable regressions

### F4 · R4 · the clearance is measured on ONE axis and applied to THREE

`cg_ragdoll.c:661-678` traces **straight down only** (`down[2] -= s_ragPtRadius[i] + 2.0f`),
then the resulting scalar is used as a symmetric box everywhere:
`cg_ragdoll.c:1001-1002` (world) and `1061-1062` (movers) both do
`VectorSet(pm, -r, -r, -r); VectorSet(px, r, r, r)`.

A hand lying flat on the floor measures ~1u of vertical clearance and is given a **1u box
horizontally as well**. Live consequences:

- limbs sink into stair risers, crate faces and wall bases by (anatomical radius − 1u), i.e. up
  to 3u for a forearm and 4u for a calf — the pancake the per-bone radii were added to prevent
  (bug-1970's own note: "a uniform box seated every point at the same height");
- a 1u box fits through gaps a 2.5–4u box would be stopped by — railings, grates, ladder rungs,
  brush seams. The code's own comment at `cg_ragdoll.c:675` ("never zero: a zero-size box
  tunnels through everything") is the same argument one order of magnitude up.

**Fix:** clamp the **vertical minimum only**. Keep the anatomical radius on x/y and on `+z`,
and clamp `mins[2]` to the measured clearance:

```c
VectorSet(pm, -s_ragPtRadius[i], -s_ragPtRadius[i], -s->ptClearZ[i]);
VectorSet(px,  s_ragPtRadius[i],  s_ragPtRadius[i],  s_ragPtRadius[i]);
```

That delivers R4's whole purpose (stop the floor lifting the body off its authored pose) with
none of the lateral cost.

### F5 · R4 · the clamp is blind to movers, so the hover it fixes persists on exactly the geometry the mover code exists for

`cg_ragdoll.c:667` — `cgi.CM_BoxTrace(&tr, s->pt[i], down, tiny, tinyx, 0, MASK_DEADSOLID, qfalse)`.
Model `0` is the **world only**; brush entities are not in it (that is why
`RagCollideMovers` exists and uses `cgi.CM_InlineModel` + `CM_TransformedBoxTrace`,
`cg_ragdoll.c:1047`, `1064`).

A soldier who dies on a door, an elevator, a lift, or a moving platform traces down into empty
space → `tr.fraction == 1.0` → `clear` keeps the full anatomical radius → **the pelvis hovers
7u off the mover**, which is the exact symptom R4 was written to remove, and it is silent.

**Fix:** after the world trace, run the same downward trace against each bmodel from one
`CG_GetBrushEntitiesInBounds` query (the pattern is already written at
`cg_ragdoll.c:1036-1065`) and take the *smallest* clearance.

### F6 · R4 · the clearance arithmetic is 1u short on every point

`cg_ragdoll.c:669` — `clear = (s_ragPtRadius[i] + 2.0f) * tr.fraction;`

The probe box is `tiny = {-1,-1,-1} … {1,1,1}`, so its **lower face starts 1u below `pt`**.
`fraction` is how far that face travelled before touching. The true point-centre-to-surface
distance is `(radius + 2) * fraction + 1`. Every point therefore gets a collision box **1u
smaller than the authored pose actually permits**, systematically re-introducing 1u of the
pancake. Compounds with F1 (which drives most pre-lifted points to the 1u floor anyway) and
with F4 (which spends that 1u laterally as well).

**Fix:** `clear = (s_ragPtRadius[i] + 2.0f) * tr.fraction + 1.0f;`

Two lesser cases in the same block, both acceptable but worth a comment:
- **slope:** a straight-down trace over-reads perpendicular clearance by `1/cos θ` (41 % at
  45°), so partial hover survives on slopes;
- **startsolid** (`cg_ragdoll.c:668`): `clear` keeps the *full* anatomical radius for a point
  the pre-lift could not free — the largest box on the worst point. Given F1 makes the pre-lift
  weaker, this path is now more reachable than it was.

### F7 · R1 · a released startsolid point is integrated freely inside solid, with nothing but the pull acting on it

`cg_ragdoll.c:1006-1020`. On the settle branch a startsolid sweep now does
`s->contact[i] = 0; continue;` — **no position correction, no velocity kill, no clamp.** The
point keeps whatever the integrator and the constraint solver gave it, inside the brush, and
the next substep integrates from there.

The rationale ("the authored pose is a valid attractor") holds only while the attractor is on
the *near* side of the surface. `RagShapeMatch` pulls toward
`pt[0] + S·(goal[i] − goal[0])` (`cg_ragdoll.c:832-835`) — the rigidly-refitted authored
position. For a body clipped into a thin wall, a doorframe reveal or a crate corner, that
target can be on the **far** side. Nothing in the code opposes it: the sweep startsolids every
substep, so there is no collision response at all, and the parent/brace links then drag the
neighbouring points after it. That is a body walking through a wall, and it is the same class
of failure the freeze was protecting against (the freeze's own comment, `cg_ragdoll.c:1013`,
says so).

The free branch is unaffected — `if (!s->branch)` at 1013 preserves the freeze, and mode-3 sims
are created by `RagArm` from a memset slot so `s->branch == 0`. ✔

**Fix (keeps R1's benefit, closes the hole):** release the point *only when the pull points
outward*. Compute the extraction direction once per substep for released points and reuse the
capture pre-lift's own recipe (`cg_ragdoll.c:570-587`): trace from `pt + 40z` down to `pt`; if
that lands, snap the point to the surface. Otherwise fall back to the free-branch freeze. That
gives the "let the pull extract it" behaviour on a wall without ever handing the truss a path
through one.

### F8 · R1 · the mover path did not get the same treatment and is now inconsistent

`cg_ragdoll.c:1066-1069` still does, on both branches:

```c
if (tr.startsolid) {
    s->pt[i][2] += 2.5f;
    VectorCopy(s->pt[i], s->ptPrev[i]);
    continue;
}
```

An unconditional **+2.5u per point per mover per frame** upward ratchet, with the velocity
zeroed. A settle-branch corpse resting against a door frame gets shoved up while the
shape-match pulls it back down every substep — a visible buzz, and on multiple overlapping
bmodels the ratchet multiplies. R1's whole argument (freezing/forcing a settle-branch point
anchors it and the body tears around it) applies here verbatim and was not carried over.

---

## S3 — medium

### F9 · R5 · the latch can never fire for ~20 % of bodies, and ~32 % never reach the threshold

Re-derived from `ragdoll_r9_session_live.log`, `contacts=` at sleep across 41 bodies:

| contacts | 0 | 1 | 2 | 3 | 4 | 5 | 7 | 11 |
|---|---|---|---|---|---|---|---|---|
| bodies | **8** | 5 | 6 | 14 | 4 | 2 | 1 | 1 |

**8 / 41 (19.5 %) end with zero contacts; 13 / 41 (31.7 %) with ≤ 1.** Those bodies can never
satisfy `nContact >= 3` (`cg_ragdoll.c:796`) and keep only the 0.12 slew — a brake, not a stop.
The user's report was *"basically every body spins"*; R5 addresses at most the ~54 % that reach
3 contacts.

**This is a HYPOTHESIS the evidence does not close:** `contacts=` is a snapshot at sleep, not a
maximum over life, so some of those 13 may have latched earlier and then lost contact. What the
data *does* establish is that the eight zero-contact bodies are also the high-`drift` /
high-`maxspd` set (724: drift 7.6 · 704: 9.1 / maxspd 1432 · 700: 6.1 / 1611 · 729: 8.7 / 1125
· 694: 7.4 · 703: 1087 · 681: 305 · 443: 107) — i.e. **the bodies that were never in contact
with anything are the ones that flew.** Chasing the spin through the rotation estimate will not
reach them; F13 will.

### F10 · R3 · `pendStatic` is now satisfiable by intra-snapshot frame repetition

`cg_ragdoll.c:1518-1520` counts consecutive **render frames** in which `cent->lerpOrigin` moved
< 0.5u, and `1543-1545` requires 2 of them before capture ("the park itself moves the origin
(droptofloor 64u): let it land first").

With `interpolate` true, `lerpOrigin` advances every frame and the counter measures real
stillness. With `interpolate` false — the state R3 now tolerates — `lerpOrigin` is
`currentState.origin` verbatim (`cg_ents.c:501`) and therefore **identical across every render
frame within one 50 ms snapshot interval**. At 125 fps that is ~6 identical frames, so
`pendStatic` reaches 2 in ~16 ms regardless of how fast the body is actually moving.

Impact is genuinely small: the capture only runs *after* `RagServerParked()`, and by then
`BecomeCorpse` has set `MOVETYPE_NONE` in both the grounded and the `droptofloor` paths
(`fgame/actor.cpp:12501-12520`) — the origin is final. The exposed case is the
`MOVETYPE_TOSS` fall-through (`actor.cpp:12523`), which fired **once** in the r9 session
(`CORPSEFALL`, 1 occurrence) and zero times in r8. Low frequency, but when it hits you capture a
body mid-fall and the sim's ramped gravity (`gravScale` 0→1 over 250 ms, `cg_ragdoll.c:1302`)
diverges from the server's.

**Fix:** make the gate snapshot-based rather than frame-based — compare
`cs->origin` against a stored `pendOrigin` and only count when
`cent->snapShotTime` has advanced.

### F11 · R7 · the 8 u/substep cap is not a speed limit, and it does change the free branch

`cg_ragdoll.c:860-865`. The cap is applied to the *damped Verlet velocity before integration*.
Everything that runs after it — the 6 constraint iterations (871-901), `RagShapeMatch`
(913), `RagResolveHit`'s `ptPrev = pos − v` re-encode (944) — can move `pt` arbitrarily further.
So 8 u/substep is a floor on how fast a *blowup* can restart, not a ceiling on point speed. The
r9 log confirms the measured mean speed exceeds the equivalent 1000 u/s on 7 of 41 bodies
(max 1611).

On the **free branch**, which shares `RagStep`, the cap bites at 1000 u/s. A corpse blown off a
roof reaches that after ~2 s of `sv_gravity 512` free fall (≈1000 u of drop); past that it
descends visibly slower than the player would. Rare, cosmetic. The seed path is unaffected —
`CG_RagdollTransition:1636-1641` seeds from one snapshot's origin delta (~20u / 50 ms = 400 u/s
= 3.2 u/substep), comfortably under.

**Verdict: acceptable.** Worth a comment noting the cap is shared and what it costs mode 3.

### F12 · R7 · the 200u AABB test is safe — it is not reachable in legitimate play

`cg_ragdoll.c:1092-1098`. The 15 points are bound by the parent-link distance constraints
(`cg_ragdoll.c:872-884`, 6 Gauss-Seidel iterations per substep) plus 16 braces. Pelvis→head is
~28u and pelvis→hand ~50u at capture, and the equality links are enforced every iteration, so a
non-diverging solver cannot exceed ~76u on any axis regardless of what the body is draped over
— a staircase, a mover, or a grenade throw does not stretch a truss. **200u is only reachable
when the solver is already diverging, which is exactly what it is testing for.**

A false positive would present as a **single-frame pop back to the authored death pose**: the
renderer table is cleared (`CG_RagdollClearEnt` → `R_ClearRagdoll`), so the vanilla anim frame
renders from the server's parked corpse. With normal drift at 0.1–2.0u that pop is
sub-perceptual; on a body that had already flown it is strictly better than the alternative.
Setting `s_ragNeverArm[entnum]` (line 1328) is correct and is cleared on the usual edges
(`cg_ragdoll.c:1626`).

### F13 · R6 · the ptPrev carry is mathematically correct — and it, not R5, is the load-bearing spin fix

`cg_ragdoll.c:839-845`. With `d = want − pt` computed before the move:
`pt' = pt + a·d`, `ptPrev' = ptPrev + 0.85·a·d`, so `v' = v + 0.15·a·d`. Direction correct,
magnitude reduced by 85 %. ✔

Re-deriving what the r9 log actually measured makes R6 the more important of the two:

The sleep gate (`cg_ragdoll.c:1334-1352`) computes `speed = Σ|pt − ptPrev| / 15 / 0.008`.
In the r9 build `RagShapeMatch` moved `pt` alone, so a *persistent* residual `d` fabricated an
apparent velocity of `alpha·|d| / 0.008 = 31.25·|d|` u/s per point at the default
`coop_ragdollStiff 0.25`. Median drift at sleep in the r9 log is **0.5 u**, giving **≈ 15.6 u/s
of pure artifact** on top of the ~6 u/s constraint jitter the code already documents at
`cg_ragdoll.c:1345-1347`. Total ≈ 21 u/s, against a 10 u/s gate.

That predicts, with no further assumptions, that **essentially nothing ever speed-sleeps** —
and the log agrees: **36 of 41 bodies rode the 6000 ms life cap** (only 4277, 2927, 2243, 1277,
1226 ms slept early). It also matches the user's *"they eventually stop"*: the spin stops at 6 s
because `lifeMs > 6000` freezes it, not because it converged.

Post-R6 the same arithmetic gives `0.15 · 0.25 · 0.5 / 0.008 ≈ 2.3 u/s` of artifact, total
≈ 8 u/s — under the gate. **Predicted: bodies begin speed-sleeping at ~1–1.5 s.**

Two follow-ups this creates:

1. **Every speed number in every prior log is now incomparable.** `maxspd`, the sleep gate and
   the "10 not 4" tuning note at `cg_ragdoll.c:1345-1347` were all calibrated against the
   inflated figure. Re-measure the distribution on the next session before touching them.
2. **Bodies may now sleep before the drape finishes.** The gate becomes a genuine stillness
   test, so a corpse still sliding down a sandbag at 8 u/s will freeze mid-slide. Watch
   `life=` and `drift=` together: if `life` collapses to ~1000 ms *and* `drift` drops, the
   settle is being cut short and the gate wants lowering (or a minimum `lifeMs` before sleep is
   permitted).

---

## S4 — coherence, dead code, stale documentation

### F14 · `coop_ragdollTest 2` (the freeze drill) is unreachable in the default mode

`cg_ragdoll.c:1702` — `if (rag_mode->integer == 1 && !rag_test->integer)` — the settle path is
skipped whenever `rag_test` is non-zero. `cg_ragdoll.c:1745` — `if (rag_mode->integer != 3) return;`
— so with the shipped default `coop_ragdollMode 1`, `coop_ragdollTest 2` falls through and
**returns without arming anything.** The drill only runs under `coop_ragdollMode 3`.

The "verified live, pixel-perfect normal soldier" result therefore validates the round-trip for
a **free-branch, EF_DEAD-edge, standing capture** — a real and sufficient proof of the render
math, but it does *not* exercise the settle capture, the pending handoff, or (F2) the rotation
latch. The drill is otherwise unaffected by R5: `RagPush` takes `RagMat3Identity(S)` for every
point when `freezePose` is set (`cg_ragdoll.c:1141-1143`), so `RagBodyRotation` is never called
and `rotLocked` never latches. ✔

**Fix:** either document "`coop_ragdollTest 2` requires `coop_ragdollMode 3`" in the header, or
make the settle branch honour `rag_test == 2` so the drill covers the shipping path.

### F15 · stale header comments that now contradict the code

- `cg_ragdoll.c:39-41` — "coop_ragdoll (CVAR_TEMP, dark until P5)". It is `CVAR_ARCHIVE`
  (`cg_ragdoll.c:282`), deliberately, with its own three-line justification.
- `cg_ragdoll.c:28-33` — the "Seed (vet2/F8)" and "Timestep" paragraphs describe **only the free
  branch**. The header never mentions the settle branch, the pending pool, or the server-park
  handoff, which is the shipping default. A fresh session reading the top of the file gets the
  round-7 architecture.
- `cg_ragdoll.c:41` documents `coop_ragdollTest 1` and never mentions `2`, whose only
  description is the struct comment at `205-206`.
- `cg_ragdoll.c:2-6` still headlines "PHASE 3" and the 2026-08-19 21:15 P2 result.

### F16 · the arm-side `interpolate` gate survives R3 and rejects silently

`cg_ragdoll.c:1677` — `if (!cent->interpolate) return;` — is still in `CG_RagdollTransition`.

This is **correct and should stay**: at that call site (`cg_snapshot.c:140`, before
`currentState = nextState`) `interpolate` carries "the entity was in the previous snapshot with
the same modelindex", which is exactly the "first-seen-dead never arms" rule the line above it
states (`cg_ragdoll.c:1674`). The asymmetry with R3 is justified, not an oversight.

But it is the **one remaining un-instrumented rejection** in the arming chain, and the batch's
whole diagnostic effort (R1, R2) was about closing silent paths. Coverage is measured as
arms/pendings (41/42 = 97.6 %); kills that never became a pending are invisible.

**Fix:** one debug line beside 1677, symmetric with the pending-drop print.

### F17 · minor

- `RagBodyRotation`'s `qboolean` return (`ok`, `cg_ragdoll.c:778`, `813`) is discarded at all
  three call sites. The degenerate one-axis fallback is blended into `bodyRot` on equal terms
  with a good fit and nothing records that it happened.
- `s->buried` (`cg_ragdoll.c:594-609`) can only ever print 0–3: `nTorso > 0 || buried >= 4`
  refuses to arm. r9: 36×0, 4×1, 1×2 — the refusal never fired in 41 captures, so the pre-lift
  is doing its job (or, per F1, is now so permissive that it always "succeeds").
- `s->seedOrigin` / `s->seedServerTime` / the 500 ms seed timeout (`cg_ragdoll.c:1269-1279`) are
  free-branch-only and dead under the default mode; `s->armTime` on the settle branch survives
  only to feed the `after=` print. Not defects — worth one comment so the next reader does not
  hunt for a settle-branch seed.
- `s_ragPtRadius[]` is still read directly at `cg_ragdoll.c:664, 666, 669, 671, 672` — all
  inside the clamp that derives `ptRadius`, which is correct. No stale direct reads remain
  outside it.

---

# Recommended order of work

1. **F1** — one-line revert of `cg_ragdoll.c:579-580` to `s_ragPtRadius[i]`. It silently
   degrades F4/F6 to their worst case and blinds the pre-lift to fence brushes.
2. **F2** — split the pure fit from the filter. Until this is done, R5 cannot be tuned (the rate
   depends on framerate) and cannot be measured (debug perturbs it), and mode 3 is not a valid
   control.
3. **F4 + F6** — vertical-only clamp, `+1.0f` on the arithmetic. Small, mechanical, and they
   restore lateral collision the drape actually depends on.
4. **F3** — clear `rotLocked` on mover-wake; require the latch to be sustained.
5. **F7 + F8** — make the two startsolid paths agree and give the released point a bounded
   extraction.
6. **Then playtest with `r_ragdollDebug 1` and judge on `drift` / `contacts` / `life`,** not on
   `maxspd` — F13 changes what that number means. Acceptance for R6 is
   *"`life` < 6000 on the majority of bodies"*; acceptance for R5 is *"`drift` unchanged while
   the visible spin is gone"*. If `drift` collapses toward 0 on stairs and sandbags, the latch
   is over-rigidifying and F3's sustained-latch condition is the lever.

---

# Appendix — numbers re-derived for this audit

All from `_research/ragdoll_r9_session_live.log` and `_research/ragdoll_r8_session_1230.log`,
recomputed, not quoted.

**r8 (pre-R3), 63 pending drops:** every one printed `valid=1 interp=0 midx=<varies> etype=1
dead=1` — the `interpolate` guard was the *sole* cause in 63/63. Drop ages: min **0 ms**,
median **142 ms**, p90 **600 ms**, max **2069 ms**. Rejection rate 63/82 = **76.8 %**; arms
18/82 = **22.0 %**. (The commit message's "~70 %" and "22 %" both check out.)

**r9 (post-R3):** 42 pending-arms · 41 settle-armed · 41 sleeps · 40 first-contacts · **0**
drops · **0** give-ups · **0** evictions · **0** NaN/blowups · **0** buried refusals · **0**
mover-wakes · **1** `CORPSEFALL`. Coverage **41/42 = 97.6 %**.

**Time from death edge to capture (`after=`):** min 297 ms, median 1346 ms, max 2852 ms —
comfortably inside `RAG_PEND_CAP_MS 8000`, and long enough that the round-8 anim-end *guess*
could never have hit it.

**Death animations captured (19 distinct):** death_chest ×5 · death_fall_back ×4 ·
rifle_pain_kneestodeath ×4 · death_backgrenade ×3 · death_back ×3 · unarmed_pain_kneestodeath ×2
· death_frontcrouch ×2 · unarmed_pain_floortodeath ×2 · death_shoot ×2 · rifle_wall_death_right
×2 · death_run ×2 · death_crotch ×2 · death_twist ×2 · death_frontchoke · death_grenade ·
death_collapse · death_knockedup · unarmed_pain_crawltodeath · mp40_wall_death_right.
The authored-anim half of the architecture is working.

**`maxspd` (mean point speed, u/s):** n=41, min 16, median 75, max 1611. **10/41 (24 %) > 300;
7/41 (17 %) > 1000.** Per F13, most of this is the shape-match's own pull artifact, not motion.

**`drift` (mean per-point offset from the refitted authored pose, u):** 33/41 ≤ 2.0. The
outliers are 724 = 7.6 · 704 = 9.1 · 729 = 8.7 · 694 = 7.4 · 700 = 6.1 · 680 = 5.0 — **all six
have `contacts` of 0 or 1.**

**`life`:** 36/41 hit the 6000 ms cap; only 5 slept on speed (4277, 2927, 2243, 1277, 1226 ms).

**`worldtr`:** 15–75 per frame against a construction bound of 15 pts × 4 substeps × 8 sims =
480. The bug-1967 budget split is not being stressed.
