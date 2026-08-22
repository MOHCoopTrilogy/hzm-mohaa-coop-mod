# RAGDOLL ROUND 10 — FINAL CORRECTED SPEC

Supersedes the reactive-fix set R1-R8 as the authority on what ships next.
Written 2026-08-20 after five review lenses (spin / diffs / arch / scripts / forensics) were each
adversarially verified. Every number below was re-derived from the archived logs and every code
claim re-read from source; where a lens and the code disagreed, the code won.

Prior art: `ragdoll_r8_spec.md` (the vetted build this came from), `ragdoll_r9_{spin,diffs,arch,scripts,forensics}.md`
(the five lenses), `.wolf/buglog.json` bug-1962 … bug-1971.

---

## 0. EXECUTIVE SUMMARY

**The most important fact in round 9 is not in round 9's log.**

`G:\mohaa-gl2\cgame.dll` is **12:32:10, md5 `3634849fab5461d3fc51ce69f40617f4`**.
The build tree's `cgame.dll` is **12:44:37, md5 `6f46c1687a3ac940974214ef5ccf7fcf`**.
The r9 session loaded its cgame at 12:40:15 and ran to 12:47:14.

So the live game has been running **R1 + R2 + R3 + R4 only**. **R5 (spin), R6 (energy) and R7 (velocity
cap + AABB net) have never executed once.** The user's second spin report — "basically every body
spins after it hits the ground" — was made against a build that does not contain the spin fix. Every
verdict any lens reached about whether R5/R6/R7 work is a prediction, not an observation.

**And in nine rounds, nobody has ever measured a rotation.** `drift=` is provably blind to it: with
`goal[i] = pt[i]` at capture (`cg_ragdoll.c:1569-1571`), a rigid rotation `R` about `pt[0]` gives
`raw = T0ᵀ·T0·R = R` identically, so `want` rotates with the body and the residual is exactly zero.
A body standing on its head reads `drift = 1.1` (ent 681, `span=(12 48 72)`). The one quantity the
user is complaining about is the one quantity the instrument cannot see.

**Round 10 is therefore one build answering one question: is the corpse actually rotating after it
lands, and by how much?** It ships the three untested fixes, adds a rotation instrument that is
structurally independent of them, and puts every reactive fix behind a `CVAR_TEMP` so the next A/B is
a console line instead of a tenth rebuild.

Two other findings survived verification and are worth stating up front:

- **R6 alone arithmetically explains the 88 % life-capping**, and the mechanism is exact, not
  approximate. Pre-R6, `RagShapeMatch` moved `pt` without `ptPrev` (`:839`), and the sleep meter reads
  exactly `|pt − ptPrev|` (`:1337-1341`) — so the meter was reading the shape-match pull *as velocity*.
  The artifact is `(1/15)·Σ aᵢ·|dᵢ|/dt`, and `mean|d|` **is** `drift` by construction (same formula,
  `:1372-1379`). At the observed median drift 0.70 with no contacts that is **20.4 u/s against a 10 u/s
  gate**. Re-derived across all 41 bodies: **every body with `drift ≥ 0.6` was life-capped, 23 of 23.**
  R6 divides that term by 6.7×. This is the single highest-confidence prediction in the batch.
- **One body in three is stretched past the skeleton's own length, and it is getting worse.** Max-axis
  span > 57.5 u (the r8 spec's measured full cloud extension): p3 1/22 = 4.5 %, r8 2/18 = 11.1 %,
  **r9 13/41 = 31.7 %**, with 7 above 65 u and a maximum of 88 u. Three of them are *static* —
  ent 695 spans 74 u at `maxspd=16`, which no dynamic blowup can produce. Nothing re-enforces the
  distance constraints after `RagShapeMatch`, which runs last in `RagStep` (`:902-914`). This is a
  hypothesis with a strong signature; round 10 **measures** it (`stretch=`) rather than fixing it blind.

**The architecture lens's rewrite does not win.** Stated plainly in §3.4 with reasons.

---

## 1. VERDICT ON EVERY REACTIVE FIX

| # | Fix | Verdict | One-line reasoning |
|---|---|---|---|
| **R1** | Settle releases a `startsolid` point instead of freezing it (`:1013-1019`) | **KEEP-WITH-CHANGE** | The release is right — freezing anchors a limb inside a wall and the body tears around it — but the released point then integrates *freely inside solid* with its accumulated velocity intact (`:1016-1018` corrects neither position nor velocity), so add one line killing the velocity; it cannot re-freeze and it bounds the escape to a creep. |
| **R2** | Pending drop / eviction / clear diagnostics | **KEEP** | Prints only; it is what proved R3 and it costs nothing — but it did not finish the job: four silent returns remain (`:517`, `:528`, `:557`, `:1410`) and ent 145 vanished through one of them in **both** archived sessions. |
| **R3** | Drop `cent->interpolate` from the pending lifecycle check (`:1504`) | **KEEP — do not touch** | `interpolate` is cleared unconditionally at `cg_snapshot.c:151` at the end of every `CG_TransitionEntity`, eleven lines after the ragdoll call site, so it was never a validity signal for a settle capture; measured end-to-end, r9 is 42 server kills → 42 pendings → 41 arms (97.6 %) against r8's 18/85 (21.2 %). |
| **R4** | Clamp each point's collision radius to the authored pose's floor clearance (`:661-678`) | **KEEP-WITH-CHANGE (change deferred to round 11)** | It fixed the hover (bug-1970) and improved every logged axis — r8 100 % cap-riders at mean drift 3.82 → r9 88 % at 1.75 — but its arithmetic is 1 u short (the ±1 probe box's lower face starts 1 u below `pt`, so true clearance is `(r+2)·f + 1`, not `(r+2)·f`) and the clamp is measured on one axis and applied to three; both corrections change drape depth on **every** body and would confound the spin measurement, so they land in round 11. |
| **R5a** | `RagBodyRotation` slews at 0.12 instead of adopting (`:800-810`) | **KEEP-WITH-CHANGE** | A first-order lag on the goal orientation is a legitimate rotational damper, but the function is an impure mutator called from **three** sites (`:828`, `:1145`, `:1371`) so the effective rate is frame-rate dependent (150 blends/s at 30 fps, 375 at 250 fps) and `r_ragdollDebug 1` perturbs the simulation it is measuring — make it pure, advance it from exactly one site, and put the rate behind `coop_ragdollSlew`. |
| **R5b** | Latch the lock permanently once 3+ points are in contact (`:796-799`) | **KEEP-WITH-CHANGE, cvar-gated** | Three of four lenses favour it — `S` is *exactly* identity at capture (`T1 == T0` ⟹ `raw = T0ᵀT0 = I`), so an early latch freezes the goal at the animator's own orientation, which is the design intent, not its opposite — but it shipped on a 53-second turnaround with zero field evidence, it never clears on a mover-wake (`:1280-1292` resets four fields and not this one), and its reachability has never been measured; gate it on `coop_ragdollRotLock`, clear it on wake, and log `rotlockAt=`. |
| **R6** | `RagShapeMatch` advances `ptPrev` by 0.85 of each pull (`:845`) | **KEEP — highest-confidence fix in the batch** | The pre-R6 form injected `a·|d|/dt` of velocity every substep straight into the quantity the sleep gate reads, which is why 23 of 23 bodies with `drift ≥ 0.6` rode the 6 s cap; put the carry behind `coop_ragdollCarry` (default 0.85 as committed) so its strength is A/B-able without a rebuild. |
| **R7a** | Velocity cap 24 → 8 u/substep (`:860-865`) | **KEEP, cvar-gated** | 1000 u/s is already far past anything a corpse legitimately does and 7 r9 bodies logged `maxspd > 1000`; behind `coop_ragdollVelCap` so the pre-R7 value is one console line away. |
| **R7b** | `RagSane` fails on an AABB span > 200 u (`:1094-1097`) | **KEEP AS WRITTEN — but it is not the net you think it is** | It would have fired **0 of 41** times in r9: the seven fastest bodies (`maxspd` 1087-1611) had spans of only 38-58 u — they were **translating coherently, not stretching**, because nothing anchors `pt[0]` (the shape-match ties all 14 points *to* the pelvis, `:832-834`, and the pelvis is free); the actual net for "a body flew across the world" is a pelvis leash, which round 10 adds. |
| **R8** | officer.scr surrender re-assert + 3 entry guards; mg42_hack.scr re-gives from the stored weapon entity | **KEEP-WITH-CHANGE** | The fix works, but for a different reason than its comment claims and it is not complete: on an `Actor`, `self use X` **is** `self.gun = X` (`actor.cpp:2567` rebinds `EV_Sentient_UseItem` → `Actor::EventGiveWeapon`, and `ClassDef::BuildResponseList` takes the most-derived binding), so the old call was a no-op because `.gun` read `""` (bug-1957), not because `FindItem` missed; the three guards are entry-only on threads whose bounce lives *inside* an unbounded loop; and the mg42 rescue re-arms the very man the surrender loop just holstered. |

**Two fixes made under fire were wrong about themselves, and this is what this round is for:**

- **R5's stated theory is ~60 % wrong as worded.** Its comment (`:781-784`) blames a direct feedback
  loop "shape-match → estimate → goal → points → estimate". That direct path is provably closed:
  `RagTriad` commutes with proper rotations, so `S` is a **fixed point** of `RagShapeMatch` — `pt[0]`
  never moves (`:829`), `pt[1]` moves only radially so `x₁` is unchanged, and `pt[11]/pt[13]` move only
  within the `x₁y₁` plane so `y₁` and `z₁` are unchanged. Applying the shape-match cannot change the
  estimate it was computed from **at all**. What R5's author had right is that a *positional* feedback
  path exists (shape-match displaces slaved points → the torque-free constraint solver redistributes
  into the core → the core rotates → `S` rotates). Right shape, wrong mechanism — which is exactly why
  the fix must be measured rather than trusted.
- **R7b's AABB gate is insurance against a failure mode that did not occur.** See the table.

---

## 2. CONFLICTS BETWEEN LENSES — DECIDED

| Conflict | Positions | **Decision** | Why (one sentence) |
|---|---|---|---|
| **Keep or kill R5's latch?** | spin: kill if torque-free ships (they are mutually destructive); diffs + arch: keep, it already delivers `S ≈ I` for grounded bodies; forensics: unmeasured, and it corrupts any `bodyRot`-based instrument | **KEEP, cvar-gated, and measure it** | Since `S` is *exactly* `I` at capture, an early latch holds the animator's own orientation — the design goal — and the only lens against it objects solely in combination with a torque-free shape-match that round 10 is not shipping. |
| **What instrument measures the spin?** | arch: `rot = acos((tr S −1)/2)` from `s->bodyRot`; spin: `yaw` from `bodyRot_now · bodyRot_1s_agoᵀ`; forensics: **both are self-fulfilling** because R5b freezes `bodyRot` on latch | **Forensics wins — instrument the stateless raw fit, never `bodyRot`** | A metric that reads the variable the fix under test freezes would print `spin=0` for every latched body and be misread as proof R5 worked, which is the identical error that made `drift=` useless for nine rounds. |
| **Lower the sleep gate 10 → 4 u/s?** | spin §9 fix 1 tail: yes; every other lens + spin's own verifier: no | **REJECT, permanently** | The 10 u/s value has its own recorded cause — truss-supported points carry a ~4-6 u/s gravity-vs-constraint jitter floor (`:1345-1347`, live 21:46) — which R6 does not remove, so a 4 u/s gate sits at the jitter floor and nothing ever sleeps (bug-1962's documented regression). |
| **Which net catches "a body flew across the world"?** | arch + forensics: tighten the AABB span to 100-110 u; diffs: an AABB cannot see translation — add a pelvis leash | **Pelvis leash at 128 u; leave the 200 u span alone this round** | The seven fastest r9 bodies had spans of 38-58 u, so the span gate provably misses the reported symptom; and tightening a gate while simultaneously measuring the quantity it gates would censor round 10's stretch data. |
| **Is the R4 clearance bug (F6, missing `+1.0f`) shippable now?** | diffs: F1 and F6 must ship together or neither is correct; every other lens: silent | **F1 IN, F6 OUT (round 11)** | F6 changes the collision radius of **every point of every body** by up to 1 u — a drape-depth change in the direction that re-opens bug-1970 (hover) — on a build whose only job is measuring rotation; F1 alone is strictly better than today, because today a capture-buried point is handed the *full* anatomical radius and then gets no world collision at all on settle. |
| **How much life-capping should R6 produce?** | diffs: ~50-60 % still capped; forensics: ~20-37 % capped | **Predict 15-45 % capped (55-85 % sleeping); do not gate acceptance on the point estimate** | Re-derived across all 41 bodies with the exact per-body contact counts: post-R6 speed-sleep is **83 %** with no jitter floor and **61 %** with a 6 u/s floor, so the honest interval spans both lenses and a single number would fail a correct fix. |
| **Does the architecture rewrite (option B) win?** | arch: proposes it; arch's own verifier: "not next, and not as specified" | **No. It does not win.** | See §3.4 — its costing is refuted by a factor of ~50, it deletes the cgame-side owner of a renderer pool that silently wedges when full, and it is a ~175-line rewrite of code that has broken in four separate bugs. |
| **`self use X` vs `self.gun = X` for the AI weapon rescue?** | scripts report B1: `use` avoids the Delete/respawn churn; scripts verifier: **refuted** | **R8's form stands; delete B1 and fix R8's comment** | `actor.cpp:2567` rebinds `EV_Sentient_UseItem` to `Actor::EventGiveWeapon` on Actors, so the two calls are the *same function* — B1 would have been a behavioural no-op shipping a misleading comment. |

---

## 3. THE NEXT BUILD

### 3.1 The one question

> **Does the corpse's point cloud actually rotate after it lands — how fast, about which axis, and
> does R5 stop it?**

Everything in this build is either the instrument that answers that, a fix that has never run and must
run to be judged, or a change so cheap and provably-safe it cannot move the answer. Everything else is
in §3.5 with the round it lands in.

### 3.2 Files touched

| File | Change |
|---|---|
| `openmohaa-hzm/code/cgame/cg_ragdoll.c` | all engine work below (~150 lines net) |
| `hzm-mohaa-coop-mod/coop_mod/cfg/rag_run.cfg` | reset key seeds the five new cvars |
| `hzm-mohaa-coop-mod/coop_mod/cfg/rag_drill.cfg` | freeze drill moves to the **settle** branch |
| `hzm-mohaa-coop-mod/coop_mod/cfg/rag_carry.cfg` | **new** — R6 strength A/B |
| `hzm-mohaa-coop-mod/autoexec.cfg` | `bind F6`, and `seta coop_weapDebug 1` (track B) |
| `hzm-mohaa-coop-mod/coop_mod/officer.scr` | track B: guards into loop bodies, comment fix |
| `hzm-mohaa-coop-mod/coop_mod/mg42_hack.scr` | track B: surrender guard |
| `hzm-mohaa-coop-mod/coop_mod/wounded.scr` | track B: surrender filter |
| `hzm-mohaa-coop-mod/coop_mod/aisquad.scr` | track B: surrender filters (2 blocks) |
| `hzm-mohaa-coop-mod/coop_mod/replace.scr` | track B: repeat-holster guard |

**No renderer change.** `renderergl1/tr_ragdoll.cpp` ≡ `renderergl2/tr_ragdoll.cpp` (byte-identical) and
both `tr_model.cpp` hooks are untouched — `git log ff57cdff..HEAD` over those four files is empty and
stays empty. **No new cgame import.** Every API used is already in the struct: `Printf`
(`cg_public.h:103`), `CM_PointContents` (`:173`), `CM_BoxTrace` (`:177`), `CM_TransformedBoxTrace`
(`:187`), `ForceUpdatePose` (`:408`), `TIKI_Orientation` (`:409`), `R_SetRagdollPose` (`:453`),
`R_ClearRagdoll` (`:454`). **`game.dll` and `openmohaa.exe` do not ship** — cgame.dll only.

### 3.3 IN — engine (`cg_ragdoll.c`)

---

**E0 — DEPLOY. This is item zero and it is not optional.**

The live install carries the 12:32:10 binary. `.\build.ps1` from `C:\mohaa-coop-dev` after
`cmake --build . --config Release`. Before reading a single round-10 number, confirm
`md5sum /g/mohaa-gl2/cgame.dll` differs from `3634849fab5461d3fc51ce69f40617f4`. Nine rounds of
evidence have been read off builds whose identity was assumed; this one is checked.

---

**E1 — Five `CVAR_TEMP` knobs, every one defaulting to the as-committed behaviour.**

This is the highest-leverage line in the spec: it converts every reactive fix from "a rebuild per
hypothesis" into "a console line per hypothesis". Added in `RagCvars()` alongside the existing block
at `:283-288`, same style:

```c
        // Round 10: every reactive fix from the 2026-08-20 playtest is a console line now, so the
        // next A/B costs a keypress instead of a build. Defaults == the committed behaviour.
        rag_rotlock = cgi.Cvar_Get("coop_ragdollRotLock", "1",    CVAR_TEMP); // R5b latch (0 = off)
        rag_slew    = cgi.Cvar_Get("coop_ragdollSlew",    "0.12", CVAR_TEMP); // R5a (1 = pre-R5 adopt)
        rag_carry   = cgi.Cvar_Get("coop_ragdollCarry",   "0.85", CVAR_TEMP); // R6  (0 = pre-R6)
        rag_velcap  = cgi.Cvar_Get("coop_ragdollVelCap",  "8",    CVAR_TEMP); // R7a (24 = pre-R7)
        rag_leash   = cgi.Cvar_Get("coop_ragdollLeash",   "128",  CVAR_TEMP); // E6  (0 = off)
```

Wire-in: `:800` `a = s->rotLocked ? 0.0f : 0.12f` → `rag_slew->value`, and gate the latch at `:796` on
`rag_rotlock->integer`; `:845` `a * 0.85f` → `a * rag_carry->value`; `:860-861` `8.0f` → `rag_velcap->value`
(clamped to `[1, 64]`); E6 reads `rag_leash->value`.

---

**E2 — `RagRawFit()`: one pure producer of the anatomical fit.**

The instrument must never read `s->bodyRot`, because R5b freezes it. Lift the fit out of
`RagBodyRotation` verbatim — same math, same order, so it is a provable no-op:

```c
// The raw anatomical fit, capture basis -> current basis. PURE: touches no state, so the debug
// instrument and the filter cannot perturb each other (r_ragdollDebug used to change the sim).
// Exactly identity at capture: restDir[1] is built from the capture pt[] and hipDir0 likewise,
// so T1 == T0 and raw = T0^T*T0 = I. That is what makes rot= below a total-rotation-from-capture.
static qboolean RagRawFit(const ragSim_t *s, float raw[3][3])
{
    float  T0[3][3], T1[3][3];
    vec3_t spineNow, hipNow;

    VectorSubtract(s->pt[1], s->pt[0], spineNow);
    VectorSubtract(s->pt[13], s->pt[11], hipNow);
    if (RagTriad(s->restDir[1], s->hipDir0, T0) && RagTriad(spineNow, hipNow, T1)) {
        RagMat3TransMul(T0, T1, raw); // row-vector: v' = v*S
        return qtrue;
    }
    VectorNormalize(spineNow);
    RagMat3FromTo(s->restDir[1], spineNow, raw); // degenerate: 1-axis fallback, roll unconstrained
    return qfalse;
}
```

---

**E3 — `RagBodyRotation` becomes a pure reader; the filter advances from exactly one site.**

Today `RagBodyRotation` is an impure mutator called from `:828` (per substep), `:1145` (`RagPush`, per
frame — which only wants to read, and which can *set the latch*) and `:1371` (the sleep debug print,
which therefore changes the simulation). Split it:

1. `RagCapture` seeds the filter — **provably identical to today's first push**, because `raw == I` at
   capture. Add next to the existing capture bookkeeping (after the `restDir`/`hipDir0` block, ~`:682`):
   ```c
   RagMat3Identity(s->bodyRot);   // raw is EXACTLY I at capture (see RagRawFit); today the first
   s->bodyRotValid = 1;           // RagPush seeded this - it no longer may, so seed it here
   s->rotLockAtMs  = -1;          // memset gives 0, which would read as "latched at frame 0"
   ```
2. New `RagBodyRotationAdvance(ragSim_t *s)` holds everything from `:787-811` (seed / latch / slew /
   re-orthonormalise), reading the fit from `RagRawFit`, plus two corrections:
   - **use the return value** — on a degenerate triad keep the previous `bodyRot` instead of blending
     in the roll-free `RagMat3FromTo` fallback (an unconstrained roll axis is itself a spin source that
     R5a only smooths), and count it in `s->rawBad`;
   - the latch is gated on `rag_rotlock->integer`, and stamps `s->rotLockAtMs = s->lifeMs` and
     `s->rotAtLock` = the current total rotation in degrees.
3. Call it **once per substep from `RagStep`**, immediately after the constraint loop closes (`:901`)
   and before the `if (s->branch)` shape-match block (`:902`) — so on the settle branch the advance
   happens at exactly the same point in the ordering it does today, and on the free branch (mode 3) the
   filter keeps advancing even though `RagShapeMatch` never runs there.
4. `RagShapeMatch` (`:828`), `RagPush` (`:1145`) and the sleep print (`:1371`) all become
   `memcpy(S, s->bodyRot, sizeof(s->bodyRot))`.

Side effect, flagged deliberately: the slew's effective rate becomes fps-invariant at 125 applications/s
(today it is 150/s at 30 fps and 375/s at 250 fps). That is the point — but it means round 10's R5a is
~25-33 % gentler than the committed code at typical frame rates. The instrument is unaffected, because
it reads `RagRawFit`, not the filter. See RISK-3.

---

**E4 — The spin instrument. This is the deliverable.**

New state on `ragSim_t` (~60 bytes on a ~9.66 KB struct):

```c
    float    rotSample[3][3];  // raw fit at the last spin sample
    int      rotSampleMs;      // lifeMs at that sample
    float    spinRate;         // deg/s over the most recent window
    float    spinMax;          // peak deg/s over life
    float    spinYawFrac;      // |world-z share| of the last window's rotation, 0..1
    int      rotLockAtMs;      // lifeMs when rotLocked latched (-1 = never)
    float    rotAtLock;        // total degrees from capture at the latch
    byte     ctcMax;           // PEAK simultaneous contact count over life
    float    stretchMax;       // peak len/restLen over the 14 parent links
    vec3_t   capSpan;          // AABB of goal[] at capture
    byte     preLifted;        // points the capture pre-lift actually moved
    short    rawBad;           // frames the anatomical triad was degenerate
```

Sampling, once per frame in `CG_RagdollFrame` after the substep loop (`:1321`), under `rag_debug`:

```c
// SPIN: nine rounds have tuned a rotation nobody measured. drift= is provably blind to it (a rigid
// rotation cancels exactly, so a body standing on its head reads drift=1.1), so measure the point
// cloud directly and NEVER via s->bodyRot - R5b freezes that on latch, and a metric that reads the
// variable the fix under test freezes prints spin=0 for every latched body and reads as success.
{
    float rawNow[3][3];
    if (!RagRawFit(s, rawNow)) {
        s->rawBad++;
    } else if (s->lifeMs - s->rotSampleMs >= 500) {
        if (s->rotSampleMs > 0) {
            float dR[3][3], tr3, ang, sn;
            float dt = (s->lifeMs - s->rotSampleMs) * 0.001f;
            RagMat3TransMul(s->rotSample, rawNow, dR); // sample -> now (row-vector composition)
            tr3 = dR[0][0] + dR[1][1] + dR[2][2];
            if (tr3 >  3.0f) { tr3 =  3.0f; }
            if (tr3 < -1.0f) { tr3 = -1.0f; }
            ang = (float)acos((tr3 - 1.0f) * 0.5f);      // radians, always >= 0
            sn  = (float)sin(ang);
            // yaw share, sign-free so a row/column-convention slip cannot corrupt it: a pure
            // spin about world z reads 1.0, a pure topple about a horizontal axis reads 0.0.
            s->spinYawFrac = (sn > 0.0087f) ? (float)fabs(dR[0][1] - dR[1][0]) / (2.0f * sn) : 0.0f;
            s->spinRate    = ang * 180.0f / (float)M_PI / dt;
            if (s->spinRate > s->spinMax) { s->spinMax = s->spinRate; }
        }
        memcpy(s->rotSample, rawNow, sizeof(rawNow));
        s->rotSampleMs = s->lifeMs;
    }
}
```

`rot=` (total rotation from capture) is the same trace formula applied to `rawNow` itself, valid
because `raw == I` at capture. Compute it at the sleep print.

---

**E5 — Collateral instruments that make round 10's numbers readable.** All debug-gated, all print-only.

- **`ctcMax`** — `contacts=` has a ~50 % duty cycle by construction: `RagResolveHit` snaps a resting
  point to `endpos + 0.25·n` with `ptPrev = pt` (`:935-936`), the next substep it falls only
  `512 × 0.008² = 0.0328 u`, its box bottom is still 0.25 u clear so `tr.fraction == 1.0` and no contact
  is re-armed, and `contact[i]` decays to 0 in two substeps (`:991-993`). Every latch-reachability
  argument in every lens keyed on this number is reading a flicker. Track the peak: one `byte`, updated
  where the contacts are already counted.
- **`stretch=`** — peak `len / restLen[i]` over the 14 parent links, updated once per frame after the
  substeps. `RagShapeMatch` runs **last** in `RagStep` (`:902-914`) and nothing re-enforces distance
  afterwards, while per-point alphas differ across a mixed link (0.25 vs `0.25 × RAG_CONTACT_RELAX`,
  `:836-838`) and `pt[0]` is never pulled at all (`:829`). If the 31.7 %-over-57.5 u finding is real
  this reads > 1.3; if it is a measurement artefact it reads ~1.0.
- **`capspan=`** — the AABB of `goal[]` at capture, printed on the `settle-armed` line. This settles
  outright the question `drift` provably cannot touch: whether a high-z corpse was captured upright or
  captured flat and then rotated. Six lines, zero risk, strictly better than any inference.
- **`prelift=`** — how many points the capture pre-lift actually moved (`:582-586`), so E7's affected
  population stops being unmeasured.
- **`rawbad=`** — degenerate-triad frames.
- **Four silent-return prints** — `RagCapture:517` (no tiki), `:528` (no channels), `:557` (missing
  Bip01 tag, name it), and `RagAllocSlot:1410` (already simming / never-arm). ent 145 pended in **both**
  archived sessions and printed nothing again in either; R2 closed most of the ladder, not all of it.
- **Move the `touched` latch above `:938`** — `RagResolveHit` returns from the resting-contact branch
  *before* the `!s->touched` print at `:945-951`, so a body that lands gently never prints a `contact`
  line at all. ent 692 is exactly that: no contact print, yet `contacts=3` at sleep. Today every
  `contact` line means *impact*, never *touch*.

**Print formats** (the existing `sleep` line is unchanged so the r9 baseline stays parseable; the new
data goes on a second line):

```
^~^~^ RAGDOLL settle-armed ent=%d channels=%d after=%dms via=solid anim=%s buried=%d prelift=%d capspan=(%.0f %.0f %.0f)
^~^~^ RAGDOLL sleep ent=%d life=%dms span=(%.0f %.0f %.0f) branch=%s drift=%.1f maxspd=%.0f contacts=%d alpha=%.2f drive=%d worldtr=%d
^~^~^ RAGDOLL sleep-rot ent=%d rot=%.0fdeg spin=%.1f spinmax=%.1f yawf=%.2f rotlockAt=%d rotAtLock=%.0f ctcmax=%d stretch=%.2f rawbad=%d lock=%d slew=%.2f carry=%.2f vcap=%.0f
^~^~^ RAGDOLL capture FAILED ent=%d reason=%s
^~^~^ RAGDOLL slot refused ent=%d (already simming or never-arm)
^~^~^ RAGDOLL leash ent=%d dist=%.0f - reverting to anim pose
```

The trailing `lock=/slew=/carry=/vcap=` self-documents which configuration produced each body, so a
session in which the user pressed F6 halfway through is still readable.

---

**E6 — Pelvis leash in `RagSane`. The only net that targets the reported symptom.**

```c
    // The sim has left its own corpse. Max observed AABB span over 41 r9 bodies was 88u while seven
    // bodies hit maxspd 1087-1611 u/s with spans of only 38-58u: they were TRANSLATING coherently,
    // not stretching, because nothing anchors pt[0] - the shape-match ties all 14 points TO the
    // pelvis and the pelvis is free. The 200u span gate cannot see that; this can.
    if (rag_leash->value > 0) {
        vec3_t dd;
        VectorSubtract(s->pt[0], cg_entities[s->entnum].lerpOrigin, dd);
        if (VectorLengthSquared(dd) > rag_leash->value * rag_leash->value) {
            return qfalse;
        }
    }
```

`cg_entities[].lerpOrigin` is already read at `:1110`/`:1119`; no new API. Failure mode is the same
silent revert-to-authored-pose the existing ladder already produces (`:1324-1330`), and `s_ragNeverArm`
still clears on the usual edges (`:1626`).

---

**E7 — R1 velocity kill + F1 pre-lift radius. Two one-line correctness fixes.**

*R1 (`:1016-1018`):* the released point keeps its accumulated velocity and integrates freely inside
solid until it emerges — anywhere. Add the kill:

```c
            } else {
                s->contact[i] = 0;                     // full-strength pull home, not the relaxed one
                VectorCopy(s->pt[i], s->ptPrev[i]);    // ... but do not let it keep the speed it had:
            }                                          // a released point then CREEPS out along the
                                                       // pull instead of being launched along it
```

*F1 (`:579-580`):* the pre-lift builds its sweep box from `s->ptRadius[i]`, which is written at `:677`
— **96 lines later** — and the slot is `memset` before every capture (`:1435`, `:1554`, `:1560`), so it
is always `0.0f`, which `cm_trace.c:1377-1379` turns into a point trace. Change both `VectorSet` lines
to `s_ragPtRadius[i]`, the static anatomical table, which is what round 8 intended. Today's consequence
is worse than a missed lift: a capture-buried point is seated flush by the point trace, then the ±1
clearance probe at `:663-667` startsolids (its lower face starts 1 u below `pt`, i.e. 0.625 u inside the
brush), so `clear` keeps its line-664 initialiser — the **full** anatomical radius — and that point is
`startsolid` on every sweep forever: permanently released on settle (no collision at all) and
permanently frozen at `subStart` on free, which is precisely the pin bug-1962 was filed against.

---

**E8 — Clear the latch on a mover-wake.**

`:1282-1289` resets `state`, `sleepMs`, `lifeMs`, `accumMs` — and not `rotLocked`, `bodyRotValid` or
`contact[]`. An elevator can carry a corpse but never re-orient it. Add three lines. Zero mover-wakes
fired across all three archived sessions, so this cannot regress anything that has ever been measured;
it is free correctness.

---

**E9 — Make the freeze drill reachable on the branch that ships.**

`:1702` requires `!rag_test->integer` to enter settle, and the `freezePose` flag is only ever set at
`:1750-1753`, reachable only through `RagArm` on mode 3 — so `coop_ragdollTest 2`, the **only**
regression test this feature has, cannot run on `coop_ragdollMode 1`. Change `:1702` to
`rag_mode->integer == 1 && rag_test->integer != 1`, and set `s->freezePose = (rag_test->integer == 2)`
in the pending-fire block immediately before `RagPush(s)` at `:1572`. Two lines; it adds a test path and
changes nothing when `rag_test` is 0.

This matters *this* round specifically, because E3 modifies `RagPush`'s inputs.

---

**E10 — Header rewrite.** `:2-42` still describes the round-7 architecture: it headlines "PHASE 3",
documents only the free branch, calls `coop_ragdoll` `CVAR_TEMP` when `:282` made it `CVAR_ARCHIVE` with
a three-line justification, and documents `coop_ragdollTest 1` but not 2. A fresh session currently
reads a false map at the top of the file. Rewrite for: the settle branch, the pending pool, the
server-park handoff, `coop_ragdollTest 2`, and the five new cvars.

### 3.4 The architecture lens does not win — plainly

The arch lens proposed **option B**: replace the 6-second continuous simulation with a one-shot
relaxation (~0.2 s of iteration at capture, then an ease-in), deleting `RagMoverHash`, the sleep block,
the substep loop, the seed path and `RagBodyRotation` — about **176 lines** by its own count, which I
reproduce exactly. It is directionally interesting and it is **not shipping in round 10 or round 11.**

1. **Its own verifier withdrew it.** Ranked "not next, and not as specified", with three unresolved
   defects.
2. **Its costing is refuted by ~50×.** B claims the capture pool "disappears as a concept", replaced by
   "a small per-entity blend record (15 vec3 + entnum + start time ≈ 200 B)". But `RagPush` reads
   `s->mat0[128]`, `s->anchor[128]`, `s->relPos[128]`, `s->rot0`, `s->driveDir0`, `s->driveOk`,
   `s->restDir`, `s->count`, `s->tiki`, `s->scale`, `s->entAxis` (`:1102-1201`). You cannot push without
   the whole ~9.66 KB capture. 16 records is **~155 KB — twice the ~77 KB pool it claims to replace.**
   What B actually buys is *residency* (6 s → 0.2 s, a ~30× improvement in slot turnover). Real, but a
   different and much smaller claim.
3. **It deletes the owner of a pool that wedges silently when full.** `RE_SetRagdollPose` returns
   without comment when the renderer's 8 slots are exhausted (`tr_ragdoll.cpp:75-77`), with the header
   comment "plan eviction lives cgame-side". B deletes the cgame-side eviction; after 8 drapes the
   renderer pool never frees and every later corpse silently fails to override. B is not specifiable
   until it carries its own renderer-slot LRU.
4. **Its integrator is unstated and the choice is worth 12×.** Under Verlet a limb falls 10 u in
   ~25 iterations (`½·512·(n·0.008)² = 10`); under the position-based variant B's §3 proposes
   (`ptPrev = pt` each iteration, which destroys accumulation) it needs ~305. B costs the 305 case and
   then "solves" it by raising `dt`, without ever connecting the two sections.
5. **Trap 2.** It is a large rewrite of code that has broken in bug-1962, 1963, 1964 and 1966, and the
   only regression test it has — `coop_ragdollTest 2` — is structurally blind to the estimator
   (`RagMat3Identity(S)` at `:1141-1143`), which is exactly what `:94` records about bug-1966.

**Migration, if it ever ships (round 12 at the earliest, and only after round 10 and 11 data):**
(a) retain the full capture record — B's memory argument is dead, its residency argument is the real
one; (b) add a cgame-side renderer-slot LRU keyed on entnum before deleting the sim-side eviction;
(c) state the integrator up front and cost it; (d) split the mover work — delete the *wake* hash
(`:955-977`, `:1280-1293`, zero fires in 145 corpses) and **keep** `RagCollideMovers`, which bug-1967
just fixed; (e) gate on the freeze drill passing in **both** modes plus a ≥40-kill session with an
unchanged `after=` distribution (r9 median 1352 ms, min 297, max 2852).

The arch lens's genuinely correct call is its own §7 self-criticism: *measure first*. That is round 10.

### 3.5 OUT — and the round each lands in

| Deferred | Round | Why it is not in this build |
|---|---|---|
| **F6** — `clear = (r+2)·f **+ 1.0f**` (`:669`) | **11** | Changes the collision radius of every point of every body by up to 1 u, i.e. drape depth everywhere, in the direction that re-opens bug-1970; it would confound the one measurement this build exists to take. |
| **F4** — clearance measured on one axis, applied to three (`:661-678`) | **11** | Same class, larger blast radius. Correct the arithmetic first: the deficits are forearm 2 u and calf 3 u (the report's 3/4 are the radii, not the deficits), and the worst cases are **spine2 7.5→6.5** and **pelvis 7.0→6.0**. Scope any asymmetric box to the world pass — `CM_TransformedBoxTrace` interprets mins/maxs in the bmodel's local frame. |
| **Torque-free / momentum-conserving `RagShapeMatch`** | **11, cvar-gated**, only if round 10 shows real rotation on *grounded* bodies | The loop starts at `i = 1` and `want` is anchored at `pt[0]` (`:829-834`), so every correction is an external impulse about the pelvis with no reaction — a genuine per-substep torque that neither R5 nor R6 touches. But it is mutually destructive with R5b's latch (with `S` frozen, the `ω × r` term is the *only* thing restoring the body toward `S_lock`), so the two must be A/B'd against each other, which is what `coop_ragdollRotLock` now makes possible. |
| **Polar-decomposition fit over all 15 points** | **12, gated** | It replaces the estimator `RagPush` uses for the pelvis at `:1145` — the exact rotation math that bug-1963 needed two adversarial vets to get right and bug-1964 broke again — and the freeze drill is structurally blind to it. The torque-free shape-match delivers the same property without touching it. |
| **Arch option B** (one-shot relaxation, −176 lines) | **12 at the earliest** | §3.4. |
| **Arch option D** (decline to drape when the pose already agrees with the floor) | **11, MEASURE-ONLY** | As an on/off gate it re-creates bug-1969's user-visible signature exactly — a declined corpse keeps the authored pose, pixel-identical to a dropped pending — and its own acceptance criterion wants *most* corpses to stop ragdolling. Ship the detector as a logged verdict first; then, if it earns it, use it to pick `alpha` (agreement → rigid, disagreement → 0.25) rather than to refuse. |
| **`RagSane` span 200 → 100/110** | **11**, set from round 10's measured `stretch=` distribution | Tightening a gate while measuring the quantity it gates censors the data; and 88 u observed against a 100 u gate is uncomfortably little headroom when R6 is about to change the dynamics. |
| **Sleep gate 10 → 4 u/s** | **never** | Reverses bug-1962's recorded fix; the ~4-6 u/s gravity-vs-constraint jitter floor is not what R6 removes. |
| **Delete `RagMoverHash` + the `state==2` rehash** | **11** | Free (zero fires in 145 corpses) but it is not this build's question; E8 makes the existing path correct in the meantime. Keep `RagCollideMovers` either way. |
| **F5 / F8 / F10** — mover-aware clamp, mover `startsolid` parity with R1, snapshot-based `pendStatic` | **11** | All three are zero-frequency across three sessions (0 mover-wakes, 1 `CORPSEFALL`). Batch them the next time anyone opens the mover path. |
| **R1 release at the contact gain (`:1017` `= 0` → `= 2`)** | **11 if needed** | E7's velocity kill removes the launch; revisit only if round 10 still shows `maxspd ≥ 600` with `ctcmax ≤ 1`. |
| **Raise `RAGDOLL_MAX_SLOTS`** | **with B or never** | A no-op while `RAG_MAX_SIMS` is 8 (cgame evicts first), and it is a two-renderer DLL ship. |
| **`.gun` / `.weapon` getter split** (`game.dll`) | **11**, staged | The real global fix for the unarmed-actor problem — it covers all 95 raw `holster` sites, the mg42 spotters, the halftrack gunner and the card players, not just surrendered men. Stage it: (a) a script-only commit changing `itemhandler.scr:480/486/505` `.gun` → `.weapon`, which is a **provable no-op today** because both bind to `EventGetWeapon` (`actor.cpp:2570/2573`); then (b) a one-line engine rebind. Do not ship it in the same session as the ragdoll build. |
| **A4** (`coop_deathReact` surrender filter) / **A6** (`m_bForceAttackPlayer` clear) | **later** | A4 is dead code — the cvar is seeded nowhere and `officer.scr:3394` says "default off". A6's only consumer is `EnemyIsDisguised` (`actor.h:2181`), so clearing the latch re-opens disguise-fooling and needs its own playtest. |
| **B1** (`self use local.coop_w.model`) | **dropped permanently** | Refuted: on an `Actor` it is the same function as R8's form. |

### 3.6 IN — track B, script-only (same deploy, different subsystem)

These ride the same `build.ps1` and cannot confound the ragdoll measurement — different binary,
different subsystem. Ordering matters: **instrument before filtering.**

| # | File | Change |
|---|---|---|
| B1 | `autoexec.cfg` | `seta coop_weapDebug 1` — `Actor::EventGiveWeaponInternal:5244-5254` already prints `^~^~^ WEAPDBG GIVE-FAILED actor=… weapName=…`, and the probe was **off** all session (the cvar is seeded nowhere), so zero WEAPDBG lines excluded nothing. It is the only thing that distinguishes the four candidate producers; every surrender-specific filter below is a guess until it runs. |
| B2 | `officer.scr` | Move the three surrender guards **into their loop bodies** — after the loop's NULL check at `:2002`, `:4761`, `:4841` — and keep the entry guards at `:1940`, `:4755`, `:4837`. `coop_suppress_react` is threaded at `:1840`, three lines above `coop_squad_surrender` at `:1843`: the *same* personality pass starts both for the *same* actor, its trigger is being shot at, it has no cvar gate, and `local.wg` is cached at `:4838` so the weapon-group whitelist cannot save it after the holster. This is the most reachable surrender producer in the mod. |
| B3 | `mg42_hack.scr` | Surrender guard immediately after `:18`. R8's two halves genuinely fight: the global unarmed rescue re-gives a weapon to the very man the surrender loop just holstered, and `Actor::Holster` → `DeactivateWeapon(WEAPON_MAIN)` → `sentient_combat.cpp:775 activeWeaponList[hand] = NULL` makes every deliberately-holstered actor read `"unarmed"`. Must land **before or with** the getter split, or that split arms every surrendered man. |
| B4 | `wounded.scr` | Surrender filter in the `coop_checkTacticalRetreat` block (~`:133`). Live via `autoexec.cfg:612` and it committed 4× in a 6-minute session (`RETREATDBG` at 12:40:40 / 12:41:48 / 12:42:22 / 12:42:24) — though never co-occurring with a surrender in the observed window, which is why it is #4 and not #1. |
| B5 | `aisquad.scr` | Surrender filters in both blocks (`:207` SS1, `:149` SB2). Measured 63 go-loud alerts and 47 search moves in ~6 minutes. SS1 is the branch that actually re-enables (`enableEnemy = 0` + `runto` + `forceactivate` → `aimaneuver_reengage`, whose first two statements are `enableEnemy = 1; forceactivate`); SB2 is cheap insurance and does not latch. |
| B6 | `replace.scr` | Repeat-call guard at the top of `holster:` (`:2021`). Verified on the code: the label sets `self.flags["coop_holsterGun"] = self.gun` **unconditionally** and the `coop_isHolstered` flag is only tested by `unholster:`. `global/cardgame.scr` calls it at `:124`, `:179` and `:205` with no intervening unholster — second call reads `""` (bug-1957) and clobbers the stored gun, so the card player stands up with his rifle slung and never draws it. That is the user's exact symptom with no surrender anywhere in the chain, across 53 call sites. |
| B7 | `officer.scr:1941-1943` | Correct the comment. It says "Holster does NOT clear the slot"; it does (B3). It is cited as the justification for the guard design. |

**Track B is one producer among several.** The direct log evidence is four `Crouch Aim Default case for
unarmed weapon group` lines from `anim/aim.scr:92` at 12:44:43-44 — proof that *an* actor was in a live
aim think with an empty hand, and no identification of which producer. `maps/M3L3.scr:140` holsters
`$halftrack_gunner` with no capture and no restore path anywhere; `:1610-1626` threads five
`mg42_active` nests whose spotters are holstered at `global/mg42_active.scr:476` and unholstered only on
gunner death, immediately followed by `attackplayer` at `:497`. 95 raw `holster` command lines exist
across `maps/`, `global/` and `coop_mod/`. B1 exists precisely because the surrender story is a
plausible verified mechanism, not an established cause.

---

## 4. PARAMETER TABLE

### 4.1 New this round

| Parameter | Site | Recommended | Reasoning |
|---|---|---|---|
| `coop_ragdollRotLock` | `:796` | **1** | R5b as committed. `0` restores pre-R5b in one console line — and it is the A/B partner for round 11's torque-free shape-match, which is mutually destructive with the latch. |
| `coop_ragdollSlew` | `:800` | **0.12** | R5a as committed. `1.0` = pre-R5 instant adoption. Now fps-invariant at 125 applications/s (E3), where the committed code ran 150/s at 30 fps and 375/s at 250 fps. |
| `coop_ragdollCarry` | `:845` | **0.85** | R6 as committed — the one untested fix with a hard arithmetic case behind it. `0` = pre-R6 exactly; `1.0` injects zero velocity but makes the sleep meter fully blind to the shape-match, which is RISK-2. Bound `[0, 1]`. |
| `coop_ragdollVelCap` | `:860` | **8** | R7a as committed = 1000 u/s, already ~50 % above free-fall terminal for a 2 s drop at `sv_gravity 512`. `24` = pre-R7. Clamp `[1, 64]`. |
| `coop_ragdollLeash` | `RagSane` | **128** | Max observed AABB span across 41 r9 bodies was 88 u and a parked corpse does not move, so 128 u from the parked origin is unambiguously a runaway; `0` disables. This is the net R7b is not. |
| spin sample window | E4 | **500 ms** | Long enough that a 3 °/s body turns 1.5° (well above the `acos` noise floor near identity), short enough to resolve "spins then stops" from "spins to sleep" inside a 6 s life. |
| `spinYawFrac` cutoff | E4 | **sin θ > 0.0087** (≈0.5°) | Below half a degree per window the rotation axis is numerically meaningless; report 0 rather than a random direction. |

### 4.2 Existing — reviewed, unchanged, with the reason each value stands

| Parameter | Site | Value | Reasoning |
|---|---|---|---|
| sleep speed gate | `:1348` | **10 u/s** | **Do not touch.** Truss-supported points carry a ~4-6 u/s gravity-vs-constraint jitter floor (`:1345-1347`); at 4 nothing ever speed-slept. R6 removes the shape-match artifact, not the jitter. |
| sleep hold | `:1353` | 1000 ms | Unchanged; R6's whole predicted effect is on this gate and it must be measured against the same threshold. |
| life cap | `:1353` | 6000 ms | Unchanged for the same reason. |
| `coop_ragdollStiff` (alpha) | `:287` | **0.25** | The only alpha in every archived log. Do **not** vary it in the same session as R5/R6's first run — F11 (0.10) / F1 (0.50) are round-11 tools. |
| stiff ramp | `:912` | 300 ms | No evidence against it. |
| `gravScale` ramp | `:1302` | 250 ms | No evidence against it. |
| `RAG_CONTACT_RELAX` | `:64` | 0.15 | Where a point touches, the ground gets the last word. Its asymmetry across a mixed link is a *suspect* for the stretch finding — measured this round, not changed. |
| `RAG_ITERS` | `:61` | 6 | Candidate to raise **if** `stretch=` reads high; not changed blind. |
| `RAG_SUBSTEP_MS` / `RAG_MAX_STEPS` | `:58-59` | 8 / 4 | 125 Hz fixed; supported minimum ~31 fps. Unchanged. |
| `RAG_DAMPING` | `:60` | 0.98 | Unchanged. |
| rest-contact gate | `:934` | `n.z > 0.7`, `|v| < 0.35` | **Do not widen.** `fd903d6a` narrowed 1.2 → 0.35 for bug-1963; the recorded defect at 1.2 was "froze the landing slide, folding bodies vertically over their first contact". It is also the confound that invalidates every p3-vs-r9 sleep comparison. |
| restitution / friction | `:940-941` | 0.1 / 0.45 floor / 0.75 wall | Unchanged. |
| resolve lift | `:924` | 0.25 u | Predates R4 by five commits (`git log -L 924,924` → `3248723d`), so it is *not* R4-caused; with `SURFACE_CLIP_EPSILON 0.125` the resting point sits ~0.375 u proud. Leave it — it is bug-1962/1970 ground. |
| pre-lift probe height | `:577` | 40 u | Unchanged; 24 was too short on stepped geometry. |
| pre-lift box | `:579-580` | **`s_ragPtRadius[i]`** | **CHANGED (E7).** Was `s->ptRadius[i]`, always 0 at that point in the function. |
| radius clamp floor | `:674-675` | 1.0 u | Never zero — a zero-size box tunnels. |
| radius clamp arithmetic | `:669` | `(r+2)·f` | 1 u short; **deferred to round 11** (§3.5) so it cannot confound the spin measurement. |
| `RagSane` AABB span | `:1095` | **200 u** | Held this round *because* `stretch=` is being measured; round 11 sets it from that distribution. It fired 0/41 in r9. |
| `RagSane` position | `:1086` | 65536 | Unchanged. |
| buried refusal | `:603` | torso > 0 **or** total ≥ 4 | Unchanged; 0 refusals in r9. |
| bind/degenerate span | `:617` | 4 u | Unchanged. |
| `RAG_PEND_CAP_MS` | `:66` | 8000 ms | r9 `after=` ran 297-2852 ms (median 1352), so 8 s has ~2.8× headroom over the worst observed park. |
| `RAG_MAX_PEND` | `:65` | 16 | 0 evictions in r9. |
| `RAG_MAX_SIMS` | `:55` | 8 | ≥33 sleeping-slot evictions were deducted in r9 with 0 `arm refused`, so the awake pool never starved. Raising it is a no-op without the renderer half. |
| `RAG_TRACE_BUDGET` / `RAG_MOVER_PER_BODY` | `:62-63` | 240 / 60 | Peak `worldtr` observed was 75. Unchanged. |
| seed jitter / timeout | `:1648-1650`, `:1271` | 0.08 / 0.06, 500 ms | Free-branch only; dead code under mode 1. |
| `pendStatic` threshold | `:1543` | 2 frames | 1 `CORPSEFALL` in r9, 0 in r8. Unchanged. |

---

## 5. ACCEPTANCE EVIDENCE

### 5.1 What the user does, key by key

| Key | Cfg | Purpose |
|---|---|---|
| **F7** | `rag_drill.cfg` — **now `coop_ragdollMode 1` + `coop_ragdollTest 2`** | The safety gate, moved onto the branch that ships (E9). Kill **one** soldier. |
| **F8** | `rag_run.cfg` — settle test + reset (now also seeds the five new cvars to their defaults) | The measurement session. |
| **F6** | `rag_carry.cfg` — **new**, `coop_ragdollCarry 1.0` | R6 strength A/B, live. (F2-F6 are free; F9/F10/F11 collide with the video-clip binds at `autoexec.cfg:72-74`.) |
| **F10** | `rag_ab.cfg` — `coop_ragdollDrive 0` | Bone-driver A/B. **Not used this round** unless the mesh redirect below fires. |
| **F11 / F1** | `rag_soft.cfg` 0.10 / `rag_firm.cfg` 0.50 | Alpha A/B. **Not used this round** — varying alpha in R5/R6's first live session makes every number incomparable. |

**Session protocol.** F7, kill one soldier, verify. F8. Then **40+ kills on m3l3** (the r9 map, so the
comparison is like-for-like), deliberately including men near sandbags, crates, rubble, slopes, ledges
and walls. Do not press F1/F10/F11. Press F6 only after at least 25 kills, and say so, so the log splits
cleanly on `carry=`.

### 5.2 Gate 0 — the drill (F7). Fails here, nothing else is readable.

```
^~^~^ RAGDOLL freeze-pose armed ent=NNN
```
**Visual: the corpse must render as a pixel-perfect, completely normal soldier, frozen mid-death.**
Any warp, stretch, twist, shrink or limb-detach means the render path broke — **stop, report, do not
run the session.** E3 changes `RagPush`'s inputs, so this drill is doing real work this round.

Run it again on `coop_ragdollMode 3; coop_ragdollTest 2` from the console — both branches must pass.

### 5.3 Gate 1 — coverage. Protects bug-1969's 22 % → 98 %.

```
^~^~^ RAGDOLL pending-arm ent=NNN (waiting on server park)
^~^~^ RAGDOLL settle-armed ent=NNN channels=72 after=NNNNms via=solid anim=... buried=0 prelift=N capspan=(NN NN NN)
```
**PASS:** `settle-armed` ≥ 40 for 42 pendings; **zero** `pending dropped`; **zero** `pending gave-up`;
**zero** `capture FAILED`; `after=` median 1000-1800 ms (r9: 1352, range 297-2852).
**FAIL:** any drops, or arms below 38/42 → the coverage fix regressed. **Stop, revert the batch,
nothing else in the log means anything.**

### 5.4 Gate 2 — THE QUESTION. The spin, measured for the first time.

```
^~^~^ RAGDOLL sleep-rot ent=NNN rot=NNdeg spin=N.N spinmax=N.N yawf=N.NN rotlockAt=NNN rotAtLock=NN ctcmax=N stretch=N.NN rawbad=N lock=1 slew=0.12 carry=0.85 vcap=8
```

Read `spinmax` (peak rate over life) and `spin` (rate in the final window before sleep), over **≥ 35
bodies**. Split by `ctcmax ≥ 3` (grounded) vs `< 3`.

| Reading | Verdict | Next |
|---|---|---|
| **`spinmax` median < 3 °/s** and the user still reports spin | **The skeleton is not spinning.** The whole spin thesis — R5's and every lens's — is wrong. | Redirect to §5.7 R-1 (the mesh). |
| `spinmax` median 3-15 °/s, **`spin` at sleep ≈ 0**, `rotlockAt` fires early | Bodies turn while settling and stop. That is **drape**, not spin. | R5 is unnecessary; A/B it off with `coop_ragdollRotLock 0` in the same session and confirm the visual is unchanged. Revert R5 in round 11. |
| **`spin` at sleep > 5 °/s on a majority**, `yawf` > 0.6 | **The spin is real, ongoing, and is a yaw.** | Read `rotlockAt`: fired early (< 300 ms) on the spinners ⟹ the latch does not work ⟹ round 11 ships the torque-free shape-match, cvar-gated, with `coop_ragdollRotLock 0`. Never fired (`-1`) on the spinners ⟹ R5 is simply not reaching them ⟹ round 11 latches on `ctcMax` instead of the flickering instantaneous count. |
| `spin` high but `yawf` < 0.3 | Not a spin — a **topple** about a horizontal axis, i.e. the body is still falling over at sleep. | Round 11 lengthens the settle window or firms alpha; it is not a rotation-estimator problem at all. |

**Visual verdict, recorded in the user's own words alongside the numbers:** watch three or four corpses
for a full six seconds after they land. *Do they turn on the spot?* If the numbers and the eyes
disagree, **the eyes win and the instrument is wrong** — that is the failure that ends this line of
work and sends round 11 to §5.7 R-1.

### 5.5 Gate 3 — R6, R7 and the collateral instruments

**R6 (`life=`).** Predicted **55-85 % of bodies now speed-sleep** (I derive 83 % with no jitter floor,
61 % with a 6 u/s floor, across the exact r9 per-body drift and contact counts). Baseline: r9 was
**5/41 = 12 %**.
- **PASS:** ≥ 45 % sleep before 6000 ms, **and** the `drift`↔`life` relationship inverts — the bodies
  that still ride the cap are the high-`drift` ones, not a random half. In r9, `drift ≥ 0.6` → capped
  **23 of 23**; that separation must break.
- **Do not** use "the majority sleep" as a hard gate: a correct R6 can land at 50 % and a naive
  criterion would revert it.
- **RISK-2 signature:** any body sleeping at 1000-1600 ms with `drift > 2` is **freezing mid-settle** —
  R6 has made the sleep meter blind to an active pull. If that appears, drop `coop_ragdollCarry` to
  0.6 for the rest of the session and note it.

**R7 (`maxspd`).** Judge only against round 10's own distribution — R6 makes every prior speed number
incomparable. **PASS:** no body above ~1000 u/s, and no `leash` line. **FAIL:** any
`^~^~^ RAGDOLL leash ent=NNN dist=NNN` is a genuine runaway caught, which is a **pass for the net and a
fail for the sim** — record the ent and its `sleep-rot` line if it produced one.

**`stretch=`.** **PASS:** ≤ 1.15 on the large majority. **FAIL:** > 1.3 on a meaningful fraction ⟹ the
31.7 %-over-57.5 u finding is a live constraint violation ⟹ §5.7 R-2.

**`capspan=` vs `span=`.** For every body with `span.z > 25` (r9: 11 of 41, max 72), compare. `capspan.z`
already high ⟹ the corpse was captured upright and the sim is faithful. `capspan.z` low and `span.z`
high ⟹ the sim stood a flat body up, which no lens has yet explained and which is a round-11 headline.

**`ctcmax` vs `contacts`.** Expect `ctcmax` to run roughly 2× `contacts`. If it does, every
latch-reachability claim in every round-9 lens (including "the latch can never fire for 20 % of bodies")
was reading a flicker, and `ctcMax` becomes the latch's input in round 11.

**Silent paths.** `capture FAILED` / `slot refused` should print **zero** times. If ent 145 appears
there, a three-session mystery closes.

### 5.6 Gate 4 — track B

With `coop_weapDebug 1`: **PASS** = zero `^~^~^ WEAPDBG GIVE-FAILED` lines and zero
`Crouch Aim Default case for unarmed weapon group` lines from `anim/aim.scr:92`, and the user sees no
German running with his gun on his back. **FAIL with WEAPDBG lines** = the give itself is failing, which
is the getter-split problem (§3.5), not a surrender problem. **FAIL with aim.scr lines but no WEAPDBG** =
a producer outside the surrender set — most likely `M3L3.scr:140`'s uncaptured `$halftrack_gunner` or
the five `mg42_active` spotters.

### 5.7 Redirect signatures — what sends round 11 somewhere else entirely

**R-1 · `spinmax` reads near zero but the user still sees spin ⟹ it is the MESH, not the skeleton.**
The suspect is `conj = Ecap · S · Enowᵀ` at `:1165`: `Ecap` is frozen at capture (`:534`) while `Enow`
is rebuilt from `cent->lerpAngles` **every frame** (`:1120`). Any yaw the server applies to the corpse
entity after capture rotates the rendered mesh about the entity origin while the sim points sit still —
visually indistinguishable from a spinning body, and invisible to every point-based metric in this spec.
**Test:** `r_ragdollDebug 2` draws the 15 sim points as depth-hacked sprites (`:1207-1235`). If the dots
are static and the mesh turns, it is `:1165`, and round 11 is a placement-tracking question (freeze
`Enow` to `Ecap` once the server has parked, or re-capture `entAxis` at park) — not a physics question
at all. Note this path was *deliberately* introduced by bug-1964's fix, so it must be narrowed, never
reverted.

**R-2 · `stretch=` > 1.3 ⟹ constraint convergence, not rotation.** Nothing re-enforces distance after
`RagShapeMatch`, which is last in `RagStep` (`:902-914`). Round 11 either re-runs the distance pass
after the shape-match or raises `RAG_ITERS`; the `stretch=` number tells you which, and the three static
stretchers (ent 148 @ 71 u/46 u/s, ent 695 @ 74 u/16 u/s, ent 658 @ 70 u/32 u/s) are the regression set.

**R-3 · Coverage below 38/42, or any `pending dropped` ⟹ stop everything.** bug-1969 is back and no
other number in the log is interpretable. Revert the whole engine batch (§6) before doing anything else.

**R-4 · The freeze drill warps ⟹ stop everything.** The render path broke; this has happened three
times (bug-1963, 1964, 1966) and every one of them made an entire session's data worthless.

---

## 6. ROLLBACK — one command per piece

**Console, no rebuild, mid-session** (this is the point of E1):

| Piece | Command |
|---|---|
| R5b latch | `coop_ragdollRotLock 0` |
| R5a slew | `coop_ragdollSlew 1.0` (instant adopt = pre-R5) |
| R6 energy carry | `coop_ragdollCarry 0` (= pre-R6 exactly) |
| R7a velocity cap | `coop_ragdollVelCap 24` (= pre-R7) |
| E6 pelvis leash | `coop_ragdollLeash 0` |
| All instrumentation output | `r_ragdollDebug 0` |
| The whole feature | `exec coop_mod/cfg/rag_off.cfg` |
| Back to the round-10 defaults | **F8** (`rag_run.cfg`) |

**Source, per piece:**

| Piece | Command |
|---|---|
| Entire engine batch | `git -C openmohaa-hzm checkout HEAD -- code/cgame/cg_ragdoll.c` then rebuild + `.\build.ps1` |
| R5 (both halves) at source | `git -C openmohaa-hzm revert --no-commit 35428898` and revert the `RagBodyRotation` hunk of `877b132f` |
| R6 + R7 at source | `git -C openmohaa-hzm revert --no-commit 877b132f` |
| R3 (coverage) | **Do not revert.** 42 kills → 42 pendings → 41 arms. |
| E7 pre-lift radius | revert `:579-580` to `s->ptRadius[i]` (restores today's defect; only do this to bisect) |
| Track B, all script files | `git checkout HEAD -- hzm-mohaa-coop-mod/coop_mod/{officer,mg42_hack,wounded,aisquad,replace}.scr` then `.\build.ps1` |
| Track B, per file | `git checkout HEAD -- hzm-mohaa-coop-mod/coop_mod/<file>.scr` then `.\build.ps1` |
| Restore the previously-deployed binary | copy `G:\mohaa-gl2\cgame.dll` aside **before** building; md5 `3634849fab5461d3fc51ce69f40617f4` is the r9 build |

**Deploy reminder (bug-1634):** `cgame.dll` must reach **both** `G:\mohaa-gl2\` (the LIVE install) and
the GOG root. `build.ps1` does both; deploying to the GOG root alone never reaches the running game.

---

## 7. RISK REGISTER — top 5 by probability × impact

| # | Risk | P | Impact | Mitigation |
|---|---|---|---|---|
| **1** | **The spin instrument measures the wrong thing and round 10 burns a session.** Nine rounds have already been spent on unmeasured quantities; `drift=` failed exactly this way. | Med | **Very high** — a tenth inconclusive playtest | Instrument the *stateless* `RagRawFit`, never `s->bodyRot`, so R5b's latch cannot zero it (this is the single change that separates this spec from the arch and spin lenses' proposals). Report `rot`, `spin`, `spinmax` **and** `yawf` so a topple cannot masquerade as a spin. Record the user's visual verdict in the same session and treat the eyes as authoritative if they disagree (§5.4). Keep `r_ragdollDebug 2` as the independent cross-check (§5.7 R-1). |
| **2** | **R6 makes the sleep meter blind and bodies freeze mid-settle.** With `ptPrev` carrying 85 % of the pull, a body still being actively reeled toward its goal reads as slow. | Med | High — a *new* visible defect introduced by the fix for the old one | `coop_ragdollCarry` is live-tunable (F6). Explicit watch signature in §5.5: sleep at 1000-1600 ms with `drift > 2`. If it appears, drop to 0.6 mid-session; the sleep hold stays 1000 ms and the gate stays 10 u/s so the meter is otherwise unchanged from r9. |
| **3** | **E3's refactor changes behaviour while claiming to be a no-op.** The filter moves from 150-375 blends/s (fps-dependent) to a fixed 125/s, and `RagPush` stops being the seeder. | Med | High — it would silently re-tune R5a in the same session R5a is first measured | The seed is provably identical (`raw == I` at capture, so `RagMat3Identity` in `RagCapture` == today's first push) — this is the mandatory precondition, and without it the first frame renders an all-zero rotation matrix. The freeze drill (E9, now reachable in **both** modes) is the gate. `coop_ragdollSlew` makes the rate itself an experiment rather than a hidden constant, and the instrument reads `RagRawFit`, which the filter cannot touch. |
| **4** | **Coverage regresses and bug-1969 comes back.** Three of round 10's items sit in or beside the capture/pending path (E5's prints, E7's pre-lift, E9's `freezePose`). | Low | **Very high** — it hands back the round that took coverage 22 % → 98 %, and invalidates the whole session | Gate 1 is a hard stop (§5.3): ≥ 40/42 arms, zero drops, zero `capture FAILED`. `cg_ragdoll.c:1504`'s four-condition guard is not touched. E9's `freezePose` is set only when `rag_test == 2`, which is 0 in the measurement session. The four new prints are pure `Printf`. |
| **5** | **The stretch defect is real and R6 makes it worse.** R6 softens the effective spring (the injected velocity was acting as over-relaxation), so `drift` should *rise*, and per-point alpha asymmetry across a mixed link is the suspected stretch mechanism. | Med | Med — mangled-looking corpses, i.e. the original complaint returning by a different route | `stretch=` measures it this round instead of inferring it. `RagSane`'s 200 u span gate is deliberately **left alone** so the data is uncensored, and the pelvis leash catches the runaway case. If `stretch > 1.3`, round 11 re-runs the distance pass after the shape-match (§5.7 R-2) — a ~6-line change, well-understood. |

---

## 8. ROADMAP AFTER THIS BUILD

Each item states the round-10 reading that triggers it. Nothing here ships on a hunch.

**Round 11 — the fix round.** Trigger: round 10 returns ≥ 35 `sleep-rot` lines and passes Gates 0 and 1.

| Item | Trigger condition |
|---|---|
| Torque-free / momentum-conserving `RagShapeMatch`, cvar-gated, A/B'd against `coop_ragdollRotLock 0` | `spin` at sleep > 5 °/s with `yawf` > 0.6 on a majority of `ctcmax ≥ 3` bodies |
| Latch on `ctcMax` instead of the instantaneous count | `rotlockAt = -1` on the spinning bodies while `ctcmax ≥ 3` |
| Revert R5 entirely (`coop_ragdollRotLock` default 0, then delete) | `spinmax` median < 3 °/s, i.e. there was never a spin to fix |
| Re-run the distance constraints after `RagShapeMatch`, or raise `RAG_ITERS` | `stretch=` > 1.3 on a meaningful fraction |
| **F6** clearance `+1.0f` **and** **F4** vertical-only clamp, shipped as one drape-depth change | Gates 0-3 pass and no drape complaint outstanding — these are the round that is *allowed* to change how deep bodies sit |
| `RagSane` span 200 → measured max × 1.25 | round 10's `stretch=` and `span=` distributions exist |
| Delete `RagMoverHash` + the `state==2` rehash; keep `RagCollideMovers` | any round-10 profiling concern, or opportunistically with F5/F8/F10 |
| Option D as an **alpha selector** (agreement → rigid, disagreement → 0.25), measure-only first | round 10 shows a population of bodies whose `capspan` already agrees with the floor and whose `drift` stays < 0.3 |
| `.gun`/`.weapon` getter split, staged script-then-engine, `game.dll` only | track B's `coop_weapDebug 1` session shows `WEAPDBG GIVE-FAILED` lines, or shows unarmed actors outside the surrender set |
| Mesh-placement narrowing at `:1165` | §5.7 R-1 fires |

**Round 12 — architecture, if it is still wanted.** Trigger: rounds 10 and 11 both pass their gates and
the *look* is signed off, **and** profiling shows the 6 s residency actually costs something.

- Arch option B, re-specified per §3.4 (a)-(e): full capture retained, cgame-side renderer-slot LRU
  added first, integrator stated, mover work split, gated on the freeze drill in both modes plus a
  ≥ 40-kill session with an unchanged `after=` distribution.
- Polar-decomposition 15-point fit, cvar-gated, **only** if round 11's torque-free shape-match is
  insufficient — and only with a non-identity-`S` drill, because `coop_ragdollTest 2` is structurally
  blind to the estimator.

**Ship gate — the thing all of this is for.** `coop_ragdoll` defaults `0` (`:282`, `CVAR_ARCHIVE`) and
stays dark until: the freeze drill passes in both modes; a ≥ 40-kill session shows ≥ 95 % coverage,
`stretch` ≤ 1.15, zero leash trips, and `spin` at sleep under 3 °/s; and the user watches a full
firefight and says the deaths look right. That last one is the only acceptance criterion that has ever
actually mattered, and it is the one nine rounds have been trying to earn.
