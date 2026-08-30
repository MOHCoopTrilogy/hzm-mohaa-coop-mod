# Composure system + ADS transition unification — design plan

Status: **PART A IS BUILT, SHIPPED AND DEPLOYED.** Parts B-H remain plan-only.
Written 2026-08-20 for vetting before any code; Part A landed the same evening (9e71d739) and
shipped in v1.4.4. The header used to read "PLAN ONLY — nothing built", which on 2026-08-24 sent a
session to re-fix an already-fixed defect. **The Part A text below is the ORIGINAL diagnosis and is
wrong in two places** — read the "REVISION after three independent reviews" section near the end of
this file before acting on anything in it.

Scope requested by the user, in their priority order:
1. Composure signal (foundation)
2. Idle inspect, "per gun if possible"
3. Sprint-to-fire recovery
4. Low-ammo tell
5. Then: stress expressed by layering additive perturbation
6. **Plus a defect**: entering and leaving ADS is jolting. Treated as priority ONE — it is a
   regression-class bug in a thing the player does every few seconds, not a new feature.

---

## PART A — the ADS jolt (defect) — **DONE, shipped v1.4.4. Do not re-implement.**

> **Superseded diagnosis below.** Verified against the live source 2026-08-24:
> * source 1 (shift unscaled) — FIXED, `cg_view.c` scales it by `CG_AdsPoseFactor()` and settles to exact 0.
> * source 3 (three ease clocks) — FIXED, one ease in `CG_AdsFactorAdvance`, advanced once per frame
>   from `CG_DrawActiveFrame` before every consumer; the zoom is derived from it, not eased separately.
> * source 2 (the 0.05° renderer gate) — deliberately NOT changed, and the reasoning below for it is
>   wrong. With source 1 fixed the gate closes at ADS factor ≈ 0.0037 (see the revision for the algebra),
>   so what vanishes at the crossing is ~0.4% of the shift. Sub-pixel, not a jolt.
> * a FOURTH source this text never named — the crouch rotation at full strength — was the big one,
>   and is fixed via `CG_AdsCrouchBlend()`.
> * the residual "STG44 still jolts leaving ADS" was none of these: it was the third-person camera
>   minimum-distance fallback gated on proximity instead of obstruction (bug-2000). Seven reasoned
>   fixes failed before a live trace (`coop_adsTrace 1`) found it.

### What the user reported

> "still really not smooth going ADS and out of ADS, since I had to adjust the guns position for
> various ADS positions per gun to line up, when you go out of ads it is very jolting (IE gun may be
> way to the right aiming up because of the manipulation to get ADS right so it snaps back into its
> non ADS position)"

### Root cause — THREE independent snap sources, not one

The per-gun ADS tune is a 10-field struct (`adsGunTune_t`, `cg_local.h:533`): pitch/yaw/roll plus a
2-axis screen shift, standing and crouch. **Its halves are applied in two different files under two
different rules**, and the header comment says so plainly:

> "cg_modelanim applies pitch/yaw/roll, cg_view the screen shift."

**Source 1 — the shift is never scaled by the ADS pose factor.**
`cg_modelanim.c:1700` scales the rotation by the eased pose:
```c
fAdsPitch *= s_fAdsPose;   // full at 1, nothing at 0
fAdsYaw   *= s_fAdsPose;
fAdsRoll  *= s_fAdsPose;
```
`cg_view.c:2336` does no such thing — it writes the tune value at **full strength**:
```c
cgi.Cvar_Set("r_weaponshiftx", va("%g", fShiftX));
cgi.Cvar_Set("r_weaponshifty", va("%g", fShiftY));
```
So the rotation fades out over ~120 ms while the translation is binary.

**Source 2 — the renderer drops the whole weapon projection at a threshold.**
`tr_main.c:609` gates the *entire* weapon projection — which is what carries the shift — on the
weapon fov differing from the world fov:
```c
tr.viewParms.weaponFovActive = qfalse;
if ( r_weaponfovx && r_weaponfovx->value > 1.0f
     && fabs( r_weaponfovx->value - tr.refdef.fov_x ) > 0.05f ) {
    ... weaponProjectionMatrix[8] = r_weaponshiftx->value;   // the shift lives HERE
    tr.viewParms.weaponFovActive = qtrue;
}
```
On ADS exit the zoom eases back toward 1.0. The instant it brings the weapon fov within **0.05
degrees** of the world fov, `weaponFovActive` flips false and the shift — which may be a large
offset, because it is exactly the manipulation the user did to line the sights up — vanishes in a
single frame. This is the jolt the user is describing, and it happens at an arbitrary point partway
through the transition rather than at either end.

**Source 3 — three easing rates running concurrently.**
- rotation: `s_fAdsPose`, in at 15/s, out at 8.5/s (`cg_modelanim.c`)
- world zoom: `s_adsZoomCur`, 12/s both directions (`cg_view.c:2297`)
- shift: instant

Even with sources 1 and 2 fixed, three different clocks mean the gun un-rotates on one schedule and
un-shifts on another. The sight picture would come apart mid-transition instead of moving as one
rigid object.

### Fix — one canonical ADS factor, consumed everywhere

Introduce a single eased scalar, computed **once per frame in one place**, and make every consumer
read it. Nothing else eases ADS any more.

```
CG_AdsFactor()  ->  float 0..1
```
- 0 = pure hip pose, 1 = full sight alignment
- eased asymmetrically (in faster than out — the user liked the current in-feel)
- the ONLY ADS ease in the codebase after this change

Consumers:

| consumer | file | today | after |
|---|---|---|---|
| pitch / yaw / roll | cg_modelanim.c | `* s_fAdsPose` | `* CG_AdsFactor()` |
| screen shift X / Y | cg_view.c | full strength, instant | `* CG_AdsFactor()` |
| world zoom | cg_view.c | own 12/s ease | `lerp(1, target, CG_AdsFactor())` |

Because all three now come off one number, the gun is guaranteed to translate and rotate as a
**single rigid motion**. That is the property the current code cannot have at any tuning.

### The renderer gate — the risky part, handle explicitly

Scaling the shift toward zero is necessary but **not sufficient**: source 2 still drops the
projection at the 0.05-degree crossing. Two candidate fixes:

- **A1 (preferred)** — widen the gate to `fov differs OR shift is non-zero`:
  ```c
  if ( r_weaponfovx && r_weaponfovx->value > 1.0f
       && ( fabs(r_weaponfovx->value - tr.refdef.fov_x) > 0.05f
            || (r_weaponshiftx && r_weaponshiftx->value != 0.0f)
            || (r_weaponshifty && r_weaponshifty->value != 0.0f) ) ) {
  ```
  With the shift now eased to exactly 0.0 at hip, the gate closes at the same moment the shift
  reaches zero — continuous by construction.

- **A2 (fallback)** — leave the renderer alone and have cgame hold `r_weaponfovx` slightly detuned
  while the factor is non-zero. Rejected as a hack: it keeps a second projection alive purely to
  smuggle a translation through, and couples two unrelated quantities.

**Known risk with A1**: `weaponFovActive` also selects the weapon's pulled-in near clip plane
(`r_weaponznear`, `tr_main.c:628`). Widening the gate means the near-plane hack becomes active in
some frames where it was not before. Needs checking that hip-fire rendering is unchanged when
shift == 0 — it should be, since at shift 0 and fov equal the weapon projection is identical to the
world projection, but this must be verified, not assumed.

**Default-off switch**: `coop_adsUnify 1`. Setting 0 restores today's behaviour exactly, so the
change is A/B-able in one console command like `coop_weaponFeel`.

### What this does NOT fix

The user has also said the *animation* coming out of ADS is choppy. That is the viewmodel anim
crossblend (`cg_viewmodelanim.c:560`, `fCrossblendAmount`), a separate system. **Deliberately out of
scope here** — fixing the pose transition first may well resolve the perception, and stacking two
changes onto the same transition is exactly how the weapon-feel batch went wrong this morning.

---

## PART B — the composure signal (foundation)

One client-side scalar. Everything downstream reads it; nothing downstream defines its own idea of
"stressed".

```
CG_Composure()  ->  float 0..1   (1 = calm, 0 = maximum stress)
```

**Inputs, all already available client-side — no server change, no protocol change, no desync risk:**

| input | source | contribution |
|---|---|---|
| recent damage taken | `STAT_HEALTH` delta over a window | largest term |
| health fraction | `STAT_HEALTH / STAT_MAXHEALTH` | sustained floor |
| near-miss fire | existing suppression system (ZING / `r_ppSuppress`) | sharp spike, fast decay |
| stamina | existing sprint/stamina system | exertion term |
| time since last damage | timer | recovery |

**Shape**: stress *spikes fast and recovers slowly* — the reverse of the usual ease, and the same
asymmetry that makes recoil read as weight. Two separate rates, not one.

**Hard rules** (both learned from bugs shipped this morning — see `docs/TRAPS.md`):
1. Composure is a **state** variable. No periodic term may ever be written into it.
2. Any oscillator that reads it must **integrate its phase**, never compute `time × frequency`.

**Debug**: mirrored to `coop_composure` (read-only, non-archived) so it can be watched live rather
than inferred from behaviour.

**Cvars**: `coop_composure_enable 1`, plus per-term weights so it can be tuned without a rebuild.

---

## PART C — idle inspect

### Correction to an earlier assumption

`VM_ANIM_IDLE_0/1/2` exist in the enum (`bg_public.h:173`), are settable server-side
(`player.cpp:13126`) and are handled client-side (`cg_viewmodelanim.c:538`) — the plumbing is
complete. **But a scan of all 688 retail weapon tiks found `idle0/idle1/idle2` on only 16 files, and
every one of them is a mine detector or a mine-detector skin variant.** No actual gun authors a
fidget animation.

So "per gun if possible" **is not possible via authored animation** — the animations do not exist,
and authoring 69 of them is a modelling project, not a code change.

### What is possible

A **procedural** inspect: an additive transform on the viewmodel (rotate the weapon toward the
camera, tilt, hold, return). This is the same additive technique as the recoil and sway, so it
carries no glitch risk — the authored idle keeps playing underneath, untouched.

Per-gun *tuning* is straightforward using the existing `adsGunTune_t` table pattern: a small table of
per-weapon inspect angles, with a sane class default for anything untabled. So it is per-gun in
character, just not per-gun in authorship. Worth saying plainly to the user rather than quietly
shipping a one-size-fits-all motion.

**Trigger**: composure high (calm) AND no fire/damage/reload for N seconds AND on the ground AND not
ADS. **Interrupt**: instantly and non-negotiably on any of fire, ADS, reload, damage, sprint.

**Risk**: an inspect that does not abort fast enough is worse than no inspect. The abort path is the
part to get right; the motion is easy.

---

## PART D — sprint-to-fire recovery

On leaving sprint the weapon needs time to come back on target. Implemented as an additive offset
eased out over a per-class time, so a pistol recovers fast and an MG slowly.

**Design decision to confirm with the user**: purely cosmetic (the weapon *looks* unready but fires
normally) versus functional (an actual fire delay). Cosmetic is safe and needs no server change.
Functional changes combat balance and must be identical on every client — a server change.
**Recommend cosmetic first**, judge it, then decide.

---

## PART E — low-ammo tell

`STAT_CLIPAMMO` is already read client-side every frame by the recoil code, so the signal is free.

When the clip is at or below a threshold (per-class, roughly 20–25%), the weapon idles slightly
differently — a small mag-glance tilt folded into the idle drift, more pronounced at empty. Additive,
so no glitch risk. Suppressed while ADS, firing, or reloading.

This teaches ammo state through the weapon instead of the HUD, which is the modern-feel goal, and it
composes with the inspect motion (same machinery, different trigger).

---

## PART F — stress perturbation layer

Only after B is live and judged. Additive perturbation scaled by `1 - CG_Composure()`:

- wider settle after recoil
- hands do not return to exactly the same rest point twice
- more overshoot on pull-out and bolt-cycle
- breathing amplitude and rate already have the hooks (Part B replaces their health-only input)

**Reload timing is deliberately excluded.** The user asked about calm-vs-stressed reload speed; the
recommendation on record is to keep timing identical and change only character, because slowing a
reload under stress punishes the player exactly when they are already losing. Also, the functional
reload time is server-side while the viewmodel clock (`cg_viewmodelanim.c:620`) is client-side —
scaling only the visible half desynchronises the animation from when ammo actually returns.

---

## Build order

1. **Part A** alone. Deploy. User judges. It is a defect fix and must not be bundled.
2. **Part B** alone, with `coop_composure` visible for verification but nothing consuming it yet.
3. **Parts C / D / E**, one at a time, each behind its own cvar.
4. **Part F** last.

One change per deploy, each with its own off switch. The weapon-feel batch shipped five layers at
once and produced three bugs that took a live playtest to find; the cost of that was a whole session
of the user's evening.

## Open questions for the user

- **D**: cosmetic or functional sprint-to-fire?
- **C**: how long is "idle" before an inspect fires — 15 s? 30 s?

---

## Addendum — injured weapon shake (user, 2026-08-20)

> "when you are injured I think gun shaking should be more prevelant when ads and also when not but
> that can also be based on compose/stress we build."

Folds into Part F with no new machinery: health is already a composure input (Part B), so an injured
player is a low-composure player by construction and inherits the perturbation automatically.

Two specifics this adds:

- **It must be present in ADS, not merely scaled down there.** Every existing perturbation in this
  codebase damps hard under sights (`coop_reloadSwayAds 0.15`, footfall halved, breathing x0.35)
  because the assumption was that sight-picture disturbance is always unwanted. For injury that
  assumption is wrong — an unsteady sight picture when hurt is the entire point. Injury shake needs
  its **own ADS multiplier**, well above the others, rather than inheriting the shared damping.

- **It must not become an accuracy change by the back door.** Everything in this system so far moves
  the *view weapon model*, never the aim vector, so it is cosmetic. Shaking the sight picture while
  bullets keep going exactly where the reticle points is honest here (the player's perceived aim is
  disturbed, their actual aim is not). Making it functional would be a combat-balance change and a
  separate decision — flag it, do not slide into it.

Cvars: `coop_injuryShake` (amount), `coop_injuryShakeAds` (ADS multiplier, deliberately high).

---

## PART G — lean vs ADS (user, 2026-08-20)

> "could we just rebuild lean mechanic so that our ADS isnt impacted? cause currently ads doesnt
> work with leaning properly I think due to the fact that we would have to force the camera/gun in a
> certain way like we already had to do for ads in crouch/stand per gun"

**The user's diagnosis is correct.** `adsGunTune_t` has exactly two pose columns — standing
(absolute) and crouch (extra added on top). Lean is a THIRD pose with no column, so no per-gun
alignment exists for it and the sights cannot line up while leaning at any tuning.

### What lean actually does today

- `fLeanAngle` is real pmove state: predicted, networked, interpolated
  (`cg_predict.c:444`), with `leanMax` 40-45 deg depending on target game (`cg_predict.c:638-652`).
- `cg_view.c:1025` converts it to **view roll**: `cg.refdefViewAngles[2] += fLeanAngle * leanRoll`.
- There is ALREADY a damper for exactly this problem, added previously:
  ```c
  cvar_t *pALR = cgi.Cvar_Get("cg_adsLeanRoll", "1.0", CVAR_ARCHIVE);
  leanRoll *= (pALR ? pALR->value : 0.25f);
  ```
  **Note the mismatch: the registered default is `"1.0"` (full lean tilt during ADS) while the
  null-fallback is `0.25f`.** The fallback encodes the intended value; the registered default does
  not. Anyone reading the fallback would conclude lean roll is damped to a quarter under sights when
  in fact it is at full strength. Worth confirming this is not simply a typo that has been defeating
  the feature since it was written.
- `vm_lean_lower` (0.1, `cg_main.c:230`) additionally lowers the viewmodel while leaning.

### Two possible directions

- **G1 — add a lean column to the tune table.** Rejected. It is 69 guns x a new pose the user would
  have to dial in by hand, and lean is continuous (0..45 deg) rather than a discrete pose like
  crouch, so a single extra column could not even represent it correctly.

- **G2 — make lean stop disturbing the sight picture (recommended, and what the user proposed).**
  While ADS, lean should *translate* the view (peek past cover) while contributing little or no
  **roll**, and the weapon stays locked to the aim axis. The existing standing/crouch tune then
  remains valid while leaning, with zero new per-gun tuning. This is the standard modern-shooter
  treatment and it is mostly a matter of making `cg_adsLeanRoll` actually take effect, plus deciding
  what happens to `vm_lean_lower` under sights.

### Open question for the user

Full lean roll is a real readability cue when hip-firing — it tells you that you are leaning. G2
removes it *only while aiming*. Confirm that trade is wanted, or pick a partial value (e.g. 0.25)
that keeps a hint of tilt while leaving the sights usable.

---

## Incoming requests — captured, not yet planned

Logged here so they are not lost while Parts A-G are in flight.

1. **Medkit self-heal animation** (user): using a medkit on yourself should have its own animation,
   and plausibly stows the weapon first — "you probably wouldn't have a gun out when doing that".
   Belongs with Part C/F (procedural viewmodel work) since no authored medkit anim is likely to
   exist; needs the same tik survey Part C got before promising anything.

2. **Bombing-run approach warning** (user): when the officer calls in a bombing run, the aircraft
   should be audible **at least 10 seconds** before impact, and loud, so it functions as a warning
   rather than a surprise. This is a script change in `coop_mod/officer.scr` plus a sound alias, and
   is independent of every other part of this plan - it can ship on its own.

3. **Allied callout VO for the bombing run** (user): "if there is any allied dialogue that says
   airstrike or bombing run or stuka or something too that should play". Ships with item 2 - the
   approach sound and the callout are one feature. Needs a survey of the retail VO pool for existing
   air-attack lines before assuming any exist; this project has form for finding never-wired retail
   VO (see the e2l1 work), so search before recording or synthesising anything.

4. **Blood on the weapon at close range** (user): shooting an enemy at very close range should leave
   blood on the gun. Plausible via the existing gore-skin machinery (`coop_goreSkins`) applied to the
   VIEW weapon rather than the actor, with a decay so it wipes off over time. Needs a check of
   whether viewmodel skins can be swapped per-instance without disturbing the third-person weapon
   other players see. Related: the existing blood-trail and gore-tier work.
   **Rain washes it off** (user): the mod already has a dynamic weather system driving native SP
   weather, so rain state is queryable client-side - blood on the gun should decay much faster while
   it is raining, and slowly or not at all when dry. That coupling is the whole charm of the idea and
   should be built in from the start rather than added later.

### PART G — CORRECTED after reading all three lean consumers

The user's recollection ("we probably built that and probably killed it for not working as
intended") is almost certainly right, and the reason it did not work is now identifiable. Lean has
THREE visual effects. Two were given ADS dampers; the third — the one that actually breaks sight
alignment — was never touched.

| # | effect | site | ADS damper | registered default | fallback in code |
|---|---|---|---|---|---|
| 1 | camera ROLL | `cg_view.c:1025` | `cg_adsLeanRoll` | **1.0** (full) | 0.25 |
| 2 | lateral eye SHIFT | `cg_view.c:1103-1117` | `cg_adsLeanShift` | **1.0** (full) | 0.2 |
| 3 | viewmodel LOWERED | `cg_viewmodelanim.c:750` | **none** | — | — |

**#2 is the good one and must be KEPT.** It rotates the eye POSITION about a pivot 28.7 units below
the eye (`vStart[2] -= 28.7f`, then `RotatePointAroundVector(..., vForward, ...)`) — a waist pivot,
which is anatomically right. Critically it moves the origin only and leaves `refdefViewAngles`
alone, so **it does not change the aim direction**. This is exactly the user's "stay in the same
exact ADS but just lean left or right".

**#3 is the culprit.**
```c
vMovement[2] -= fabs(cg.predicted_player_state.fLeanAngle) * vm_lean_lower->value;
```
`vm_lean_lower` is 0.1 and `leanMax` is 40-45 deg, so this drops the VIEW WEAPON by up to **4.0-4.5
units** — while the camera does not move down with it. The sights therefore fall below the aim point
by an amount that scales continuously with lean angle. No per-gun tune column could ever compensate,
because the error is a continuous function of a continuous input, which is precisely what the user
intuited when they said a lean column would mean "forcing the camera/gun a certain way" per gun.
Note also the `fabs()`: it lowers identically leaning left or right, so it is a pure vertical
misalignment, not a directional one.

**Why it was probably abandoned**: someone added dampers #1 and #2, found the sights STILL did not
line up while leaning (because #3 was untouched and is the dominant term), concluded the approach
did not work, and restored vanilla behaviour by registering both defaults at 1.0 — leaving the
fallback constants (0.25 / 0.2) behind as fossils of the intended values.

### Revised fix

While ADS, and only while ADS:
- **#3 -> 0** (new `cg_adsLeanLower`, default 0). The single most important change.
- **#1 -> 0 or near 0.** Rolling the camera rolls the weapon with it, so the gun does not tilt
  relative to the screen — but the WORLD does, which is what reads as the sight picture tilting off
  target. Recommend 0, per the user: "the same exact ADS from a camera/gun standpoint".
- **#2 -> 1.0, unchanged.** This is the peek and it is already correct.

Result: leaning under sights becomes a pure lateral eye translation with an unchanged sight picture
and unchanged aim vector — which is the request, and needs no new per-gun tuning for any of the 69
weapons.

**Verify before shipping**: that #2 alone still reads as a visible lean when #1 and #3 are zero. If
the peek turns out to be too subtle without the roll cue, the answer is to INCREASE #2 under ADS
(above 1.0), never to reintroduce #1 or #3.

---

## PART H — cover overrides the ADS first-person handoff (defect)

> "scrolling up to go ads when behind cover and aiming puts the camera behind the players head, not
> actually down their sights properly"
> "did you by chance turn off the behind cover change shoulder and ads feature we were working on"

**Not turned off.** `autoexec.cfg:160` still sets `cg_adsShoulder 1`, and no change made on 2026-08-20
touches the cover or shoulder-ADS code. This is a real defect and it has a precedent in this very
file.

### Cause

`cg_view.c:2922` forces third person while in cover, unconditionally:
```c
if (ps->pm_flags & PMF_COOP_COVER) { cg.renderingThirdPerson = qtrue; }
```
`cg_modelanim.c:1394` mirrors it for the body draw:
```c
bThirdPerson |= (cg.snap->ps.pm_flags & PMF_COOP_COVER) ? qtrue : qfalse;
```
Neither has an exemption for the ADS first-person handoff. So when the player scrolls up to commit to
first-person sights while covered, the cover force runs afterwards and puts the camera back behind
the head — the scroll appears to do nothing except break the view.

### This exact bug already happened once, and the fix is in the lines immediately below it

The comment at `cg_view.c:2923-2926` documents the same collision for the NATIVE sniper scope:

> "NATIVE ZOOM IS FINAL: re-assert first person AFTER every 3P force above. The cover force-3P ran
> after the zoom force, so scoping while covered/peeking left the camera in third person with the
> scope overlay drawn over the back of your own head ('scope is looking into the back of the players
> head' - user)."

So the ordering hazard was found, understood, and fixed — **but only for `STAT_INZOOM`**. The coop ADS
handoff (`CG_AdsForceFirstPerson()`) is a second, later way of arriving at first person and never got
the same treatment.

### Fix

Apply the proven pattern: after the cover force, re-assert first person when the ADS handoff has
flipped to first person, exactly as the native zoom already does. Both sides must change in lockstep
(`cg_view.c` camera and `cg_modelanim.c` body draw) — this is "turret-camera-regression rule 2", cited
in the comment at `cg_modelanim.c:1393`, and violating it is what produces a camera inside a drawn
head.

Ships with PART A: same subsystem, same deploy, one ADS verification pass for the user instead of two.

---

## User answers received (2026-08-20)

- **PART D sprint-to-fire: COSMETIC ONLY.** The weapon looks unready; it still fires normally. No
  server change, no balance change. Settled - do not revisit.
- **PART C idle inspect: 15 seconds, RANDOMISED.** "make it kinda random so it isn't every 15
  seconds". Implementation note: the randomisation must be re-rolled per trigger and must not be
  derived from a frame-varying quantity, or a hitch re-rolls it and the interval jitters. Roll once
  when the idle timer arms, then hold that value.
- **PART G lean: no roll under sights.** "stay in the same exact ads from a camera/gun standpoint but
  just lean left or right" - confirms G2, keep the lateral peek, zero the roll and the viewmodel drop.

---
---

# REVISION after three independent reviews (2026-08-20)

Three reviewers with different lenses - engine correctness, adversarial edge cases, and this
project's own recorded history. Every one of them found something the plan would otherwise have
shipped. Findings are recorded as CONFIRMED only where verified directly against source.

## PART A - BUILT AND COMMITTED (9e71d739)

**The plan was wrong about which snap mattered.** All three reviewers independently found a FOURTH
source the plan had assumed was already handled: the crouch rotation at `cg_modelanim.c:1729-1750`
was never multiplied by `s_fAdsPose` at all. Values reach `cYaw = -38.5` (Garand), `-34.5` (KAR98),
`-43.0` (shotgun) - applied at full strength for the whole ~0.73 s ease-out, then gone in one frame.
That is the user's "way to the right aiming up", and it explains why crouched was worse. The user
later confirmed the jolt happens on "basically all weapons", which is the second source below.

**The plan's reasoning for source 2 (the renderer gate) was wrong.** Working the algebra from real
defaults (`cg_adsZoom 0.70`, `cg_adsGunZoom 0.5`, fov 90), the 0.05-degree gate is crossed at factor
~0.0037 - so once the shift is scaled by the factor, what vanishes at the crossing is 0.4% of the
shift, sub-pixel. **A1 was therefore NOT built**, which also avoids its real hazards:

- `r_weaponshifty` defaults to `-0.05`, so `shift != 0` is true on a clean profile and the widened
  gate would never close again.
- `%g` of an eased float prints `1e-05` long before it prints `0`, so an exact float compare latches.
- The weapon near plane is `r_weaponznear 1` vs `r_znear 4` **always**, so at shift 0 the weapon
  projection is NOT identical to the world projection. Widening the gate trades a translation pop for
  geometry popping in and out near the camera. Any future attempt must ease `wzNear` by the same
  factor via a flags-0 `r_weaponznearfrac`, and must also account for the other `RF_DEPTHHACK`
  consumers: muzzle-flash sprites (bug-108), vehicle turret guns, and script-set entities.

**Shipped instead:** scale the shift by the same factor (safe, cgame-only), ease the crouch blend,
hoist the factor out of the first-person weapon-tag branch (it froze in 3P / cover / cutscene /
dead), skip zero-dt frames rather than snapping, and drop `CVAR_ARCHIVE` from `r_weaponshiftx/y`
(they now change every frame of every transition, and `Com_Frame` calls `Com_WriteConfiguration()`
every frame - a whole-config disk write per frame).

**Correction to the plan's text:** there are at least a dozen ADS-derived consumers, not three. The
claim "the ONLY ADS ease in the codebase" was false; `s_adsShoulderEnv` and `s_adsFpEnv` still keep
their own. They drive the 3P camera rather than the gun, and were deliberately left alone.

## PARTS B / D / F - the plan proposed building things that ALREADY EXIST

- **A stress scalar is already designed.** `_research/weapon_feel_r1_variation.md` section 3 defines
  `CoopWFeelStress()` with the *same five inputs*, with magnitudes and cited sources - written
  earlier the same evening. **Extend or rename that; do not create a second scalar.** Note also a
  naming clash: an AI **morale** system already ships (`coop_moraleEnable`, `coop_mod/morale.scr`).
- **Injury shake already ships.** `coop_injurySway` / `coop_injuryStart` / `coop_dbnoSwayMult`
  (`cg_view.c:2765-2812`), health-ramped, since 2026-08-02 - and **with no ADS damping at all**. The
  addendum's premise ("every existing perturbation damps hard under sights, so injury needs its own
  high ADS multiplier") is therefore backwards. **Strengthen the existing system**; a second injury
  oscillator would stack two wobbles at two frequencies in the one state that needs precision.
- **Sprint-lower already exists**: `cg_sprintLower*`, `cg_view.c:1671-1711`. Part D is a modulation
  of it, not a new system. Confirmed cosmetic-only by the user.
- **Recoil settle**: `viewkick` is per-gun TIKI data, already randomised per shot. The prior analysis
  records the rule as **"Modulate, do not replace"** - Part F's "wider settle after recoil" must obey
  it or recoil double-applies.

## PART B - the health input is not what the plan assumed

- **`STAT_HEALTH` is a PERCENTAGE (0..100), not HP** (`player.cpp:8402`). At `coop_health 750`, one
  integer step is 7.5 HP, so the "recent damage delta" term is quantised to 1%.
- **Vehicles hijack it**: `player.cpp:8404-8408` reports the VEHICLE's health as the player's while
  riding. This mod has rides on m1l3a / m1l3b / t2l2, so boarding a damaged halftrack reads as an
  instant near-death and dismounting as an instant heal.
- **DBNO reads as FULL health**: `dbno.scr:49` sets `healthonly 9999`. A bleeding-out player would
  get maximum composure - the exact inverse of intent. The codebase already works around this twice
  via the explicit `coop_dbnoView` marker; composure must do the same.
- **There is an existing shipped unit bug to fix first**: the suppression spike at `cg_view.c:2402`
  divides a 0..100 percentage by `coop_health` (750), making the severity term ~7.5x too weak and
  effectively dead. Part B was about to build on exactly that term.

## PART C - two blocking constraints

- **There is no channel that rotates hands and gun together.** The FPS arms and the gun are separate
  render entities; every existing feel layer writes `pREnt->origin` only, and the ADS tune is the
  only rotation - applied to the **gun alone**, capped near 12 degrees precisely because more
  visibly detaches it from the hand. An inspect that rotates the weapon at inspect-scale angles
  pulls the gun out of the hands. **The inspect must be translation-only**, or the arms entity needs
  a rotation of its own with the attach proven to still resolve. This also explains why the ADS
  translation had to be smuggled through the renderer as a screen shift in the first place: it is
  the only channel that moves hands and gun as one (bug-105).
- **"Abort instantly on reload" is not achievable.** `reload` is a server console command
  (`gamecmds.cpp:104`), not a usercmd bit - the client's only signal is `iViewModelAnim` arriving in
  a snapshot, i.e. RTT plus one snapshot interval, 100-300 ms on a remote server. Damage is equally
  late (`STAT_HEALTH` is snapshot data). Fire, ADS, sprint and weapon switch ARE same-frame and safe.
  Either hook `reload` client-side before forwarding it, or drop it from the "instant" list and say
  so. A one-frame-late abort means the player pulls the trigger with the gun pointed at their face.
- **Idle is already defined elsewhere**: the HUD fade computes a richer "calm" set
  (`cg_drawtools.cpp:1975-1995`). Reuse it rather than inventing a second, disagreeing clock - and
  make sure the inspect never calls `CG_HudFadeTouch()`, or the HUD pops back on at every fidget.
- **User decision recorded**: 15 seconds, randomised. Roll the interval ONCE when the idle timer
  arms and hold it; a per-frame re-roll makes the interval jitter and a hitch re-rolls it.

## PART E - one line that would have broken it outright

`STAT_CLIPAMMO` is **-1** for clipless weapons (`weapon.cpp:3946-3957`) and `STAT_MAXCLIPAMMO` is 0,
so "clip <= 22% of max" evaluates to `-1 <= 0` = **true**: grenades, knife, binoculars and the mine
detector would idle with a permanent maximum low-ammo tell. The shipped recoil code already guards
this with an `s_lastClip >= 0` gate - copy it. Manning a turret also overwrites `STAT_CLIPAMMO` and
`activeItems[1]`, which breaks the per-gun table lookup Part C uses as well.

## State and timing rules for everything that follows

- **cgame statics DO reset on map change** - the DLL is genuinely unloaded and reloaded. The plan's
  worry there was misplaced. The real gap is **within** a map.
- **`CG_TransitionPlayerState` is an empty stub** (`cg_playerstate.c:38`) - there is no respawn /
  death / spectate hook in cgame at all. Either add one, or gate every new static on the `bAlive`
  predicate bug-1306 had to introduce:
  `h > 0 && snap && !(pm_flags & (PMF_SPECTATING|PMF_INTERMISSION))`. Never `h <= 0` alone -
  `Player::Spectator()` leaves health at max, so that guard never fires for a spectator.
- **A zero-length frame must be SKIPPED, not snapped.** The idiom `(cg.frametime > 0) ? dt*rate : 1.0f`
  jumps straight to target when dt is 0, and dt is 0 whenever `CL_AdjustTimeDelta` nudges server time
  backwards - exactly the packet-loss jitter where a snap is worst.
- **Clamp dt in every phase integrator.** `cg.frametime` clamps at 5000 ms for a client of a remote
  server; an unclamped 5 s hitch advances a phase ~20 radians, reintroducing the very teleport the
  integrators exist to prevent. (Fixed in 9e71d739 for the two shipped integrators.)
- **Two-sided eases have no floor to rescue them.** The existing one-sided decays survive `k >> 1`
  because of their `< 0.002 -> 0` floors. A composure ease toward a target in [0,1] does not; it
  needs the `if (k > 1) k = 1` clamp unconditionally, or it overshoots and oscillates divergently.
- **`coop_composure` must be flags 0**, not merely non-archived, and must be added to the explicit
  clear-list in `CG_Init` (`cg_main.c:815-836`) - published cvars otherwise keep their last value
  forever when the connection drops. A `CVAR_USERINFO` value changing every frame would send a
  userinfo packet every frame.
- **`CG_AimingDownSights()` has a spectator hole** (`cg_view.c:1886-1901`): it checks health,
  `STAT_INZOOM` and `PMF_CAMERA_VIEW` but not `PMF_SPECTATING`, and a spectator reads full health.
  Worth confirming before it becomes the single input driving everything.
- **The map tester** (`coop_maptest 2`) runs multi-hour teleporting patrols and will exercise idle
  timers and recovery clocks in ways no human session reaches. Give them an off-switch under it.

## Build order (revised)

1. ~~Part A~~ - **done, committed 9e71d739**, awaiting deploy and the user's verdict.
2. Fix the `STAT_HEALTH` unit bug at `cg_view.c:2402` (an existing shipped defect, and Part B's input).
3. Part B as an EXTENSION of `CoopWFeelStress()`, with the vehicle / DBNO / spectator gates above.
4. Parts C / D / E one at a time, each behind its own cvar.
5. Part F last, strengthening `coop_injurySway` rather than paralleling it.
