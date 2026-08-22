# Weapon feel R1 — the variation model: no two reloads the same

Research note, 2026-08-20. Lens: **the model that makes no two reloads the same.**
Scope: first-person camera + view-weapon motion for reloads and the neighbouring actions.
Status: design only. Nothing here is implemented. Every code claim is cited `file:line` and
marked **PROVEN** (read out of the source this session) or **INFERRED** (reasoned, needs a
runtime check).

---

## 0. What is there today, and what is actually wrong with it

`CG_ApplyReloadSway` — `openmohaa-hzm/code/cgame/cg_view.c:106-151`, called unconditionally at
`cg_view.c:2643`, immediately before the final `AnglesToAxis(cg.refdefViewAngles,
cg.refdef.viewaxis)` at `:2645`.

```
:127   iAnim = cg.snap->ps.iViewModelAnim;
:128   if (iAnim != s_iLastVMA) { s_iLastVMA = iAnim; s_iVMAStart = cg.time; }
:132   if (iAnim == 6) { fPhase = (cg.time - s_iVMAStart) * (1.0f/900.0f); ... fTarget = pRS->value * (0.62f + 0.38f*fPhase); }
:139   else if (iAnim == 7) { fTarget = pRS->value * 0.7f; }
:141   else if (iAnim == 8) { fTarget = pRS->value * -0.28f; }
:146   fRate = (iAnim == 8) ? 11.0f : ((fTarget > s_reloadLift) ? 7.0f : 4.5f);
:147   s_reloadLift += (fTarget - s_reloadLift) * fRate * fDt;
:149   vAngles[0] -= s_reloadLift;
:150   vAngles[2] += s_reloadLift * 0.3f;
```

Five separate defects, all of which the variation model has to fix anyway — so fixing them is
not extra scope, it is the same work:

1. **Fully deterministic.** No stochastic term anywhere. Same gun ⇒ byte-identical curve. This is
   the user's complaint. **PROVEN.**
2. **The 900 ms is a lie for every gun.** `1.0f/900.0f` at `:133` is a hardcoded reload length.
   A Colt .45 mag swap and a BAR mag swap ramp over the same 900 ms. The real per-gun length is
   available client-side and free (§4). **PROVEN.**
3. **Single-loaders get exactly one event, ever.** The edge test at `:128` is
   `iAnim != s_iLastVMA`. A shotgun/Kar98 stripper reload replays `VM_ANIM_RELOAD_SINGLE` (7)
   per shell; the value stays 7, so `iAnim != s_iLastVMA` is false for every shell after the
   first. `fTarget` is pinned flat at `0.7 * coop_reloadSway` for the whole sequence. The engine
   *does* signal each restart — `ps.iViewModelAnimChanged` is bumped on every set including
   `force_restart` (`fgame/player.cpp:13150-13151`) and is networked as a 2-bit field
   (`qcommon/msg.cpp:3358`) — the sway code just never reads it. **PROVEN.** This is why
   single-loaders feel the most robotic of all.
4. **Pitch + roll only, no yaw.** A reload is a two-handed asymmetric action; strictly in-plane
   camera motion is the single strongest "this is a canned curve" tell. **PROVEN.**
5. **It runs in third person too.** `:2643` sits after the `cg.renderingThirdPerson` /
   `CG_OffsetThirdPersonView()` branch at `:2600-2603`, and is not gated. Reloading in 3P pitches
   the whole chase camera, which is meaningless — there is no head to lift. **PROVEN.**

### The three placements that have already burned this project

Do not re-litigate these. From `.wolf/buglog.json`:

| bug | lesson |
|---|---|
| **165 / 168** | The *first* reload-camera attempt nudged `pREnt->origin` inside `CG_OffsetFirstPersonView`. `pREnt` is the **weapon model**, and the reload animation moves it far more than the effect did — the effect was invisible. The fix moved it to the world camera. **⇒ the reload channel is the CAMERA, never the viewmodel origin.** |
| **1238** | `cg_dbnoEyeDrop` written to `cg.refdef.vieworg` in `CG_CalcViewValues` did nothing, three times. `CG_OffsetFirstPersonView` runs **after** `CG_CalcViewValues` (called from `cg_modelanim.c:1910` / `:2039`, in the entity-add pass) and rebuilds the eye from the `"eyes bone"` tag: `VectorCopy(pCent->lerpOrigin, origin)` at `cg_view.c:786/802`. **⇒ POSITIONAL camera offsets must be applied at the END of `CG_OffsetFirstPersonView`; ANGULAR offsets at the tail of `CG_CalcViewValues` survive**, because `cg_modelanim.c:2042` re-runs `AnglesToAxis(cg.refdefViewAngles, cg.refdef.viewaxis)` after that call. |
| **1942** | `CG_ApplyShellShock` was spliced by regex onto the *first* `AnglesToAxis(cg.refdefViewAngles` in the file — which is inside the `PMF_CAMERA_VIEW` cutscene branch and never runs in normal play. The effect was stone dead and the user reported it as missing. **⇒ verify WHICH occurrence, always.** |

---

## 1. The layer stack

Six layers. Each is a pure function of `(normalised phase, seed, context)` or a first-order
filter toward a bounded target — **no layer integrates without a bound**, which is the whole
anti-accumulation argument (§6).

```
        L5  weight scalar w        (per-gun, derived)      multiplies L1..L4 amplitude, divides L1 rate
         |
  L1 base curve(type, p')  ──┐
  L2 per-instance variation ─┤─► ACTION target (pitch,yaw,roll) ─► first-order ease ─► A
  L3 context modifier      ──┘
                                                                                       +
  L4 continuous tremor  ───────────────────────────────────────────────────────────►   T
                                                                                       +
      (existing) injury sway, shell shock, viewkick, damage_angles ─────────────────►   X
                                                                                       |
                                                             L6 budget clamp  ◄─────────┘
                                                                     |
                                                          cg.refdefViewAngles
```

### L1 — base curve, per reload TYPE, in normalised ANIM PHASE

The shape of the action, and nothing else. Keyed on `ps.iViewModelAnim` — which already gives
free mutual exclusion, because it is a single integer: a reload and a melee cannot both be the
active action (§5).

**Function of:** the VM anim state (`bg_public.h:161-175` — `VM_ANIM_RELOAD` 6,
`VM_ANIM_RELOAD_SINGLE` 7, `VM_ANIM_RELOAD_END` 8, `VM_ANIM_PULLOUT` 9, `VM_ANIM_PUTAWAY` 10,
`VM_ANIM_FIRE_SECONDARY` 4) and the **normalised phase `p ∈ [0,1]`**, *not* wall-clock ms.

`p` comes from the animation system itself — no table, no networking:

```
slot = cgi.anim->g_iCurrentVMAnimSlot;                       // q_shared.h:2285
idx  = cgi.anim->g_VMFrameInfo[slot].index;                  // q_shared.h:2281
tEl  = cgi.anim->g_VMFrameInfo[slot].time;                   // seconds elapsed, cg_viewmodelanim.c:646
tLen = cgi.Anim_Time(cg.pPlayerFPSModel, idx);               // seconds, cg_public.h:387
p    = (tLen > 0.01f) ? (tEl / tLen) : 0.0f;                 // tEl already clamped to tLen, cg_viewmodelanim.c:648-651
```

`cg.pPlayerFPSModel` is a plain `dtiki_t *` on `cg_t` (`cg_local.h:265`) and is exactly the tiki
`CG_ViewModelAnimation` uses — `cg_modelanim.c:1949` assigns `model.tiki = cg.pPlayerFPSModel`
immediately before calling it, and `cg_viewmodelanim.c:471` does `pTiki = pModel->tiki`.
**PROVEN.** So `cg_view.c` can read the held gun's real reload length with zero new plumbing.

Curves as keyframes in `(p, unit amplitude)`, smoothstep-interpolated. Amplitude 1.0 = one unit
of `coop_reloadSway` (today 1.6°).

```
RELOAD (mag swap)      (0.00, 0.00) (0.18, 0.85) (0.34, 0.62) (0.52, 1.00) (0.68, 0.55) (0.86,-0.15) (1.00, 0.00)
                        heft ──────► mag clears ──► settle ──► seat it ──► drop ──► under-shoot ──► level
RELOAD_SINGLE (1 shell)(0.00, 0.00) (0.30, 0.70) (0.70, 0.45) (1.00, 0.10)
RELOAD_END  (cock)     (0.00, 0.00) (0.25,-0.30) (0.55, 0.10) (1.00, 0.00)
PULLOUT   (raise)      (0.00,-0.55) (0.35, 0.25) (0.70,-0.08) (1.00, 0.00)
PUTAWAY   (lower)      (0.00, 0.00) (0.40, 0.30) (1.00,-0.40)
FIRE_SECONDARY (bash)  (0.00, 0.00) (0.22,-0.45) (0.45, 0.75) (1.00, 0.00)
```

The `RELOAD` and `RELOAD_END` shapes reproduce today's feel (two-step up, then a snap down
through baseline) — deliberately: the user asked for variation, not a different gesture.
**When it dominates:** a clean, readable "heft–seat–drop", recognisable as *the* reload of that
gun. **Range:** ±1.0 × `coop_reloadSway` before L2/L3/L5.

### L2 — per-instance variation (the answer to the ask)

**Function of:** the per-event seed only (§2). Evaluated fresh every frame from the stored seed —
never re-rolled, never stored as floats. Five continuous draws:

| draw | symbol | applied as | range | what it does |
|---|---|---|---:|---|
| amplitude | `gA` | `× (1 + 0.28·gA)` | 0.72 … 1.28 | this reload was hefted harder / lazier |
| duration warp | `gT` | `p' = p^(1 + 0.22·gT)` | p^0.78 … p^1.22 | front-loaded (brisk) vs back-loaded (dragging) |
| step skew | `gS` | key at p=0.34 shifted by `0.07·gS` | ±0.07 | the pause between mag-out and mag-in moves |
| yaw | `gY` | `yaw = 0.35 · gY · w · ctx` (deg) | ±0.35° at w=1 | **the asymmetry.** Highest value-per-degree in the model |
| roll bias | `gR` | `roll = pitch · (0.30 + 0.16·gR)` | 0.14…0.46 × pitch | body lean varies independently of pitch |

Plus one **discrete** draw, `uF`: if `uF < coop_reloadFumble` (default `0.06`) this instance is a
**fumble** — the p=0.52 "seat" key is delayed to 0.60, a stall key `(0.46, 0.30)` is inserted,
the yaw draw is doubled (still ≤ 0.70°) and `p'` is stretched 12%. **Why discrete:** continuous
jitter reads as *noise*; a rare, recognisable variant reads as *a person*. One reload in ~16
being visibly clumsy is what actually sells non-repetition. Bounded by construction, so it can
never be comical.

**When L2 dominates** (`coop_reloadVary` high): the gesture stays the same but the *timing* stops
being predictable — you can no longer pre-aim the exact frame the sights come back.

### L3 — context modifier (hurried vs calm)

**Function of:** the context signals in §3, sampled **once, at the seed edge**, and frozen for
the instance. Freezing matters: sampling suppression per frame would make the curve wobble as the
fight ebbs, which reads as a bug, not as stress.

Output is a single scalar `c ∈ [0.75, 1.45]` on amplitude and `1/c` on duration — hurried means
*bigger and faster*, calm means *smaller and slower*. **When it dominates:** the same gun feels
brisk and jerky under fire and unhurried in a cleared room. That is the "belongs to the action"
half of the ask.

### L4 — continuous hand tremor

**Function of:** `cg.time` only — a zero-mean 3-octave value noise, always running, never seeded
per event (it is the *hands*, not the *action*).

```
n(t) = ( sin(t·1.70) + 0.45·sin(t·3.90 + 1.7) + 0.20·sin(t·8.30 + 4.1) ) / 1.65
```

Divisor 1.65 = 1 + 0.45 + 0.20, so `|n| ≤ 1` exactly. Three detuned harmonics at ratios
1 : 2.29 : 4.88 so the composite period is long enough not to read as a metronome — the same
trick the injury sway already uses at `cg_view.c:2460-2461`.

Amplitude `A_T = coop_handTremor · (0.10 + 0.35·stress)` degrees, `stress ∈ [0,1]` from §3.
The 0.10° floor ≈ 2 px at 1080p / fov 80 (§3.1) — below conscious notice, above "dead still".
**When it dominates** (idle, hurt, winded): the gun is never perfectly still, which is the
cheapest possible "a person is holding this".

### L5 — weight scalar `w` (derivation in §4)

Multiplies L1–L4 amplitude; **divides** the ease rate, so a heavy gun both moves further and
tracks its own curve more lazily. Clamped `w ∈ [0.50, 1.80]`.
**When it dominates:** a Thompson snaps, a BAR wallows. Same curve, different animal.

### L6 — the budget clamp

Not a feel layer. §6.

---

## 2. Randomness discipline — the seed

### The bug this exists to prevent

The classic failure in this class of feature is re-rolling inside the per-frame evaluation, which
turns "variation" into 60 Hz jitter. The discipline that prevents it: **store one integer seed
per event; derive every float from it, every frame, by hashing.** There are no random floats in
persistent state, so there is nothing to keep in sync and nothing to serialise.

### Why not `rand()` / `random()`

`random()` exists (`q_shared.h:826`, `crandom()` at `:828`) and is used in cgame
(`cg_ragdoll.c:2240`, `cg_view.c:2694`, and by the vanilla `viewkick` command at
`cg_commands.cpp:5938-5942`). **PROVEN.** But `rand()` is one global stream shared with the
ragdoll solver, tempmodels and viewkick — so a reload's character would depend on how many
bullets were fired and how many corpses were settling. That is a real reproducibility hazard for
A/B testing and a real "why did that feel different" mystery in play. The per-frame path here is
hash-only; `random()` is not used at all.

### Seed derivation — at the edge, once

The edge test must include the change counter, or single-loaders never re-seed (§0 defect 3).

```c
/* --- edge --- */
qboolean bEdge = (iAnim != s_iLastAnim) || (ps->iViewModelAnimChanged != s_iLastChanged);
if (bEdge) {
    s_iLastAnim    = iAnim;
    s_iLastChanged = ps->iViewModelAnimChanged;
    s_uSeed = CoopHash32(
          (unsigned int)cg.time                          * 2654435761u
        ^ (unsigned int)ps->iViewModelAnimChanged        * 0x85EBCA6Bu   /* 2-bit ctr: shell N vs N+1 */
        ^ (unsigned int)iAnim                            * 0xC2B2AE35u
        ^ (unsigned int)ps->stats[STAT_CLIPAMMO]         * 0x165667B1u   /* dry reload != top-up */
        ^ (unsigned int)ps->stats[STAT_MAXCLIPAMMO]      * 0x9E3779B1u
        ^ (unsigned int)ps->stats[STAT_EQUIPPED_WEAPON]  * 0x27D4EB2Fu   /* class bits, bg_public.h:371-378 */
        ^ (unsigned int)cg.snap->ps.clientNum            * 0x7FEB352Du );/* two players do not sync */
    CoopWFeelSampleContext(&s_ctx);   /* L3 frozen here, NOT per frame */
}
```

`cg.time` is the only genuinely per-event varying input and it is monotonic in ms, so two reloads
a frame apart already differ in every hashed bit. The rest are decorrelators, not entropy.

### Hash and draws — the same numbers every frame

```c
static unsigned int CoopHash32(unsigned int x)          /* Wang/Jenkins 32-bit avalanche */
{
    x = (x ^ 61u) ^ (x >> 16);
    x = x + (x << 3);
    x = x ^ (x >> 4);
    x = x * 0x27D4EB2Du;
    x = x ^ (x >> 15);
    return x;
}

/* uniform [0,1), 24-bit mantissa - exact in float */
static float CoopU(unsigned int seed, int chan)
{
    return (float)(CoopHash32(seed ^ (0x9E3779B9u * (unsigned int)(chan + 1))) >> 8)
           * (1.0f / 16777216.0f);
}
```

### The distribution — centred, hard-bounded, occasional outliers

Uniform is wrong: it makes every deviation equally likely, so the mean reload never happens and
the extremes happen constantly. Use **Irwin–Hall n = 3** — the sum of three independent uniforms,
re-centred:

```c
/* g in [-1, 1] EXACTLY (support, not a clamp). mean 0. sd = 1/3. */
static float CoopG(unsigned int seed, int chan)
{
    float s = CoopU(seed, chan*3 + 0) + CoopU(seed, chan*3 + 1) + CoopU(seed, chan*3 + 2);
    return (s - 1.5f) * (1.0f / 1.5f);
}
```

Derivation: `S = u1+u2+u3 ∈ [0,3]`, `E[S] = 1.5`, `Var[S] = 3·(1/12) = 0.25`.
`g = (S − 1.5)/1.5` ⇒ `g ∈ [−1,1]`, `E[g] = 0`, `Var[g] = 0.25/2.25 = 1/9`, `sd = 1/3`.

Consequences, which are exactly the properties asked for:

- **≈68%** of reloads land within `|g| ≤ 0.333` — within ±9.3% amplitude at the 0.28 gain. Most
  reloads feel *normal*.
- **≈4.3%** exceed `|g| > 0.667` (±18.7%) — the noticeable ones.
- **`|g| ≤ 1` is a property of the support, not of a clamp.** There is no tail to truncate and no
  branch that can be got wrong, so an outlier is *physically incapable* of producing a comical
  result. This is the whole reason to prefer Irwin–Hall over a Box–Muller normal here.

**Bounding, restated as invariants** (each checkable by inspection):

1. every `g ∈ [−1,1]` by construction;
2. every gain multiplying a `g` is a compile-time constant ≤ 0.35;
3. the fumble is a single boolean with fixed, bounded consequences;
4. the sum still passes through L6.

---

## 3. The context map

All signals are **client-side and already present**. Nothing new crosses the wire.

| signal | source (verified) | modulates | magnitude | why the player should feel it |
|---|---|---|---|---|
| **crouched** | `ps->pm_flags & PMF_DUCKED` (`bg_public.h:256`) | L1 amp, L4 amp | `×0.72` amp, `×0.65` tremor | braced on a knee; the elbow has somewhere to rest |
| **prone** | *not reachable* — `PMF_VIEW_PRONE` collides with `PMF_DAMAGE_ANGLES` at bit 1 in protocol ≥ 15 (`bg_public.h:255-256`). **Do not use it.** MOHAA has no player prone | — | — | — |
| **movement speed** | `VectorLength(ps->velocity) / ps->speed` (`ps.speed` networked, `msg.cpp:3362`) | L1 amp, L4 amp | `amp × (1 + 0.30·v)`, `v∈[0,1]` | reloading at a dead run should be visibly worse than standing still |
| **stamina** | client mirror `s_spStam`, `cg_view.c:1336-1339` — **file-static today; needs a `CG_GetStamina(float*)` accessor** (2 lines, same pattern as `CG_IsBreathSteady`, `cg_view.c:738`) | L4 amp, L3 `c` | `tremor × (1 + 0.9·(1−stam))`; `c += 0.10·(1−stam)` | winded hands shake; this is where tremor earns its keep |
| **health** | `ps->stats[STAT_HEALTH]` vs the tracked peak — the same self-calibrating idea as the injury sway, `cg_view.c:2568-2580` | L4 amp, L3 `c` | `tremor × (1 + 1.2·(1−hp))`; `c += 0.12·(1−hp)` | hurt ⇒ unsteady, *not* bigger gestures (bigger would fight the injury sway) |
| **under fire** | `s_coopSuppress` (`cg_view.c:538`, decayed `:2085`) — **needs `CG_GetSuppression()`; value is ONE FRAME STALE**, because `CG_CalcFov` (which updates it, `:2037-2114`) runs *after* the sway hook at `:2643`. 16 ms at 60 fps: invisible, but say so | L3 `c`, L4 amp, fumble | `c += 0.25·supp`; `tremor × (1+0.8·supp)`; `P_fumble × (1 + 2.0·supp)` | **the headline context.** A reload under fire is faster, jerkier and much more likely to fumble: 6% → 18% at full suppression |
| **dry vs partial reload** | `ps->stats[STAT_CLIPAMMO] == 0` at the seed edge (`STAT_MAXCLIPAMMO` = `GetClipSize`, `player.cpp:8471`) | L1 amp, L3 `c` | dry: `amp ×1.10`, `c ×1.06`. partial: `amp ×0.94` | a dry gun needs the bolt worked; a top-up is a smaller, tidier motion. Free, and the difference is legible |
| **shell index (single-load)** | running count since the last non-7 state | L1 amp | `amp × (1 − 0.06·min(shell,5))` | shells get *tidier* as you find the rhythm — then `RELOAD_END` resets it |
| **ADS** | `CG_AimingDownSights()` (`cg_view.c:1540`) or `ps->stats[STAT_INZOOM]` | **everything** | §3.1 | sacred |
| **breath held** | `CG_IsBreathSteady()` (`cg_view.c:738`, exported `cg_local.h:658`) | L4 amp | `tremor × 0.15` | the hold-breath key must visibly kill the tremor, or it is not a steady-aim key |
| **third person** | `cg.renderingThirdPerson` | L1, L4 | **× 0** on the camera | no head to lift. Fixes §0 defect 5 |
| **turret / cutscene** | `PMF_TURRET` (`bg_public.h:273`), `PMF_CAMERA_VIEW` (`:269`) | all | **× 0** | the server owns that camera (bug-296, bug-329) |
| **DBNO** | `coop_dbnoView` (`cg_view.c:200`) | L1 | `× 0.5` | the DBNO sway is already ~4.8° of roll (§6); do not add to it |
| **dead / spectating** | `h > 0 && !(pm_flags & (PMF_SPECTATING\|PMF_INTERMISSION))` — the exact `bAlive` predicate bug-1306 had to introduce, because `Player::Spectator()` leaves `STAT_HEALTH` at max so `h <= 0` never fires | all | **× 0** | bug-1306, verbatim. Do not re-invent the `h<=0` guard |

### 3.1 ADS — the exact rule

Sacred, and the arithmetic is why. In **first person** the crosshair is drawn at screen centre
(`cg_drawtools.cpp:1477-1478`) unless free-aim moves it (`:1535-1540`); bullets leave along
`ps->viewangles`; the camera renders along `cg.refdefViewAngles`. **So any angular layer of δ
degrees makes the 1P crosshair lie by δ.** At 1080p / `cg_fov 80`
(`tan(fov_y/2) = tan40° · 1080/1920 = 0.4720`) that is
`(1080/2)/0.4720 · π/180 = 19.97 ≈ 20 px per degree`. Today's 1.6° peak ⇒ **32 px of lie**.

In **third person** it does not lie: `CG_DrawCrosshair3P` re-projects the real bullet impact
through `cg.refdef.viewaxis` (`cg_drawtools.cpp:1519-1528`), and that axis already contains the
sway. **PROVEN.**

Rule, in order:

1. **Roll → `× coop_viewMotionAdsRoll`, default `0.20`.** Roll tilts the sight picture off level.
   This is precisely the failure the lean damp already exists for — `cg_adsLeanRoll`,
   `cg_view.c:2413-2416`, added because the user could not "see down my front sight".
2. **Yaw → `× 0`, hard.** Lateral motion reads as the gun being knocked off target and is the
   most disorienting axis behind a sight post.
3. **Pitch → `× coop_viewMotionAds`, default `0.35`.** Pitch is the safe axis: camera, viewmodel
   and sights rotate *together* (`cg_modelanim.c:2042` rebuilds `viewaxis` from the swayed angles
   after the viewmodel is placed), so the sight picture stays internally aligned — only the
   screen-centre crosshair lies, and 1.6° → 0.56° ⇒ **11 px**, inside a typical crosshair glyph.
4. **Native zoom (`STAT_INZOOM`) → `× 0`.** A scoped reticle at magnification turns 0.5° into a
   large apparent movement, and the gun model is hidden anyway — `cg_view.c:1103-1110` already
   treats `bScoped` as its own case.
5. **The settle rule (hard requirement).** `|A| ≤ 0.05°` (≈1 px) before the weapon is fire-ready.
   Because the curve is keyed on *anim phase* and every base curve ends at 0.0 at `p = 1.0`, this
   is satisfied **structurally** rather than by a timer — which is exactly what the hardcoded
   900 ms at `cg_view.c:133` cannot promise for a gun whose reload anim is shorter than 900 ms.
6. **Optional, phase 2:** expose `CG_GetViewMotionOffset(&yaw,&pitch)` and subtract it in
   `CG_DrawCrosshair`'s `!bProjected` branch, beside the existing free-aim correction
   (`cg_drawtools.cpp:1537-1540`) — for the **continuous** layers only (L4 tremor). Do *not*
   correct the transient action layer: a crosshair that swims during a reload is worse than one
   that is briefly wrong while you cannot fire.

---

## 4. Weight per weapon, without a 69-gun table

**Verdict: a derived scalar plus zero shipped overrides is enough.** A hand-tuned table of 69+
guns is a maintenance liability, and the mod already has the evidence that a *derived* answer is
good enough — the ADS table (`cg_modelanim.c:1187-1240`) has 45 hand-dialled rows and then an
explicit donor-alias fallback (`:1275-1285`) added because the user said *"I wish there was a
simpler way to get these new guns ads done and accurate without having to manually do it."*

Three inputs, all already networked or already local:

| input | source | status |
|---|---|---|
| `w_class` | `ps->stats[STAT_EQUIPPED_WEAPON]` bits vs `WEAPON_CLASS_*` (`bg_public.h:371-378`) | **PROVEN** — already used twice in this file: lag weights `cg_view.c:1274-1278`, recoil kick `cg_view.c:1117-1121` |
| magazine size | `ps->stats[STAT_MAXCLIPAMMO]` = `activeweap->GetClipSize(FIRE_PRIMARY)` (`player.cpp:8471`), networked, already read by the HUD (`cg_drawtools.cpp:1945`) | **PROVEN** |
| reload anim length | `cgi.Anim_Time(cg.pPlayerFPSModel, idx)` (§1) | API + tiki reachability **PROVEN**; that the lengths meaningfully separate guns is **INFERRED** — measure it (below) |

```c
/* w_class: reuse the LAG numbers (cg_view.c:1274-1278) - the "mass" set, already felt in play.
   Do NOT reuse the recoil set at :1117-1121; that is the "kick" set and means something else. */
w  = (cls & WEAPON_CLASS_PISTOL) ? 0.55f
   : (cls & WEAPON_CLASS_SMG)    ? 0.80f
   : (cls & WEAPON_CLASS_RIFLE)  ? 1.10f
   : (cls & WEAPON_CLASS_MG)     ? 1.50f
   : (cls & WEAPON_CLASS_HEAVY)  ? 1.35f : 1.00f;

/* magazine: 8 rounds is the pivot (Garand clip). A 32-round MP40 stick is heavier than a
   7-round Colt mag; a belt is a different animal. Bounded so a belt cannot run away. */
mag = ps->stats[STAT_MAXCLIPAMMO];
w  *= 1.0f + 0.35f * CoopClamp((mag - 8) / 24.0f, -0.30f, 1.00f);      /* 0.895 .. 1.35  */

/* animation length: the ANIMATORS already encoded weight. A stripper-clip Kar98 reload is
   long; a pistol mag swap is short. 1.4 s is the pivot. */
w  *= 0.78f + 0.44f * CoopClamp(tLen / 1.4f, 0.35f, 1.60f);            /* 0.934 .. 1.484 */

w   = CoopClamp(w, 0.50f, 1.80f);
```

**Worked bounds:** pistol floor `0.55 × 0.895 × 0.934 = 0.46 → clamped 0.50`; MG ceiling
`1.50 × 1.35 × 1.484 = 3.01 → clamped 1.80`. The clamps bind at both ends by design — the formula
*orders* the guns, the clamps stop it being silly.

**Overrides:** reuse the existing three-step name ladder — exact row → `CoopStripSkinSuffix`
(`cg_modelanim.c:1250-1270`, so "Thompson (Gold)" resolves to "Thompson") → donor alias
(`:1275-1285`). **Ship with the override table EMPTY.** Add a row only when the user names a
specific gun that feels wrong. One row is cheap; 69 rows is a liability.

**How to find out whether it is enough, in one session:** `coop_wfeelDebug 1` prints one
`^~^~^ WFEEL` line per event (§7) carrying `mag`, `T` and the derived `w`. Cycle the armory
through the guns you care about, reload each once, and the real distribution can be read out of
`qconsole.log`. That turns "is a derived scalar enough" from an opinion into a measurement,
without hand-writing anything.

---

## 5. The other actions

| action | signal | shares the L1–L5 stack? | notes |
|---|---|---|---|
| **reload** (3 states) | `iViewModelAnim` 6/7/8 | **yes** — the reference case | |
| **weapon raise / lower** | `VM_ANIM_PULLOUT` 9 / `VM_ANIM_PUTAWAY` 10 | **yes**, own base curves | Free: same enum, same phase source, same seed machinery. Gets variation for nothing |
| **weapon switch** | the `PUTAWAY → PULLOUT` pair | **yes** | Two consecutive action events; carry the *same* seed across the pair (`seed_pullout = CoopHash32(seed_putaway ^ 0xA5A5A5A5)`) so put-away and raise read as one continuous motion by one person |
| **melee / bash** | `VM_ANIM_FIRE_SECONDARY` 4 | **yes**, own curve | |
| **firing recoil recovery** | — | **NO. Do not rebuild it.** | `viewkick` already exists, is **per-gun TIKI data** (`entry viewkick <min> <max> …` — `models/weapons/G43.tik:199`, `FG42.tik:199`, `DeLisle.tik:257`), is **already randomised per shot** via `random()` (`cg_commands.cpp:5938-5942`), and is integrated + decayed by the engine at `cg_view.c:2467-2504`. Duplicating it would double-apply recoil. **Modulate, do not replace:** scale `cg.viewkickRecenter` / `cg.viewkickMaxDecay` by `1/w` at the fire edge so a heavier gun recovers more slowly, and let L4 tremor ride on top. The separate viewmodel-only recoil (`s_recoil`, `cg_view.c:1244-1252`) — leave alone |
| **sprint start / stop** | already built: `cg_sprintLower*`, `cg_view.c:1329+` | **no — own envelope** | It is a *sustained state*, not an *event*: no phase, no end, so L1/L2 do not apply. It must still pass through L5 (weight) and L6 (budget). Route it into the same clamp; do not merge it into the action channel |
| **landing** | **edge already computed**: `cg.bFPSOnGround != cg.predicted_player_state.walking`, `cg_modelanim.c:1891` | **yes**, own curve + own seed | Amplitude from impact speed (`|ps->velocity[2]|` on the frame before the edge). The one new signal worth adding, and it costs nothing because the edge already exists driving `CG_LandingSound` |
| **taking a hit** | `damage_angles` (`player.cpp:7313-7323`, clamped ±30/±30/±25) + `s_coopHit` (`cg_view.c:543`) | **no — separate IMPACT channel** | Server-authoritative, already subtracted at `cg_view.c:2467` |

### Priority / ordering rule

**The action channel needs no arbiter.** `ps->iViewModelAnim` is a single integer
(`q_shared.h:1905`), so reload / raise / lower / bash are *mutually exclusive by construction*.
That is a genuine simplification, not an assumption. **PROVEN.**

Between channels:

```
final = clamp_budget( ACTION·duck + IMPACT + CONTINUOUS + EVENT + vanilla )
```

1. **ACTION never cancels.** If you are shot mid-reload the reload *animation* keeps playing (the
   server does not restart it — `player.cpp:13150` bumps the counter only when the anim actually
   changes). If the camera layer stopped, camera and gun would visibly desync. It is **ducked**,
   not killed: `duck = 1 − 0.40·hitEnv`, `hitEnv` decaying over 250 ms.
2. **The envelope integrator is never reset on a state change** — only its *target* changes.
   `s_reloadLift += (fTarget − s_reloadLift)·rate·dt` (`cg_view.c:147`) already does exactly this
   and it is correct: an interrupted reload glides from wherever it was into the new curve
   instead of snapping. **Keep this. Do not "fix" it to a reset.**
3. **A new seed on every edge, including an interruption.** `RELOAD → RELOAD_END` re-seeds, so the
   bolt-work is not correlated with the mag swap that preceded it.
4. Ease rate: `rate = clamp(14.0 / w, 6.0, 20.0)` s⁻¹, replacing the fixed 7.0 / 4.5 / 11.0 at
   `cg_view.c:146`. Heavier gun ⇒ lazier tracking ⇒ reads heavier, for free.

---

## 6. The anti-sickness rule

### The present, unbounded worst case (derived, not asserted)

Nothing in `cg_view.c` bounds the *sum* of the coop view-motion layers today. Adding them up:

| layer | roll (°) | pitch (°) | yaw (°) | source |
|---|---:|---:|---:|---|
| reload sway (peak) | `1.6 × 0.30 = 0.48` | `1.6` | 0 | `cg_view.c:149-150`, `coop_reloadSway 1.6` |
| injury sway, DBNO | `1.45 × 2.2 × 0.933 × 1.6 = 4.76` | `1.3 × 0.933 × 1.6 = 1.94` | 0 | `cg_view.c:2458-2461`; DBNO forces `frac=0.02`, `amt ×1.6` at `:2589-2593` ⇒ `ramp = 0.96`, `injury = 0.30·0.96 + 0.70·0.96² = 0.933` |
| shell shock, sev 1 | `5.5` | `2.8` | `1.6` | `cg_view.c:2585-2587` |
| **coop total** | **≈10.7** | **≈6.3** | **1.6** | |

≈**10.7° of roll** ≈ **214 px** at 1080p / fov 80 — and that is *before* `damage_angles` (±25 roll,
`player.cpp:7323`) and `viewkick`, both vanilla and additive at `cg_view.c:2467-2469`. It is
reachable: be downed, near an explosion, reloading the pistol. **PROVEN by arithmetic on cited
constants.**

### The rule

```c
/* Applied once, at the very end, after every coop layer and before AnglesToAxis (cg_view.c:2645). */
mag = sqrtf(dP*dP + dY*dY + dR*dR);
if (pMax->value > 0.0f && mag > pMax->value) {
    float s = pMax->value / mag;
    dP *= s;  dY *= s;  dR *= s;        /* UNIFORM scale */
}
```

`coop_viewMotionMax`, default **6.0** degrees (≈120 px). **Uniform** scaling, not per-axis: a
per-axis clamp rotates the apparent *direction* of the motion when it engages, so the camera
appears to bend — an artefact more noticeable than the overshoot it prevents.

`coop_viewMotionMax 0` = unclamped = today's behaviour exactly, for the one-command rollback.

### Why it cannot accumulate — four invariants

1. **Every action layer is a pure function of `(p', seed, frozen context)`** and every base curve
   ends at exactly `0.0` at `p = 1.0`. There is no state carried between events except the
   integrator, which is a first-order filter toward a bounded target — it converges, it does not
   sum.
2. **The tremor is zero-mean and stateless** — `n(t)` is evaluated from `cg.time`, never
   integrated, and `|n| ≤ 1` by construction (§1 L4).
3. **Every stochastic term is `g ∈ [−1,1]` by *support*, not by clamp** (§2), multiplied by a
   compile-time constant ≤ 0.35.
4. **The budget clamp is the last write** before `AnglesToAxis`. Nothing downstream can add.

### Turning it off

| cvar | flags | default | effect |
|---|---|---|---|
| `coop_viewMotion` | `CVAR_ARCHIVE` | `1` | master 0..1 on **every** coop view-motion layer, including today's reload and injury sway. `0` = a dead-still camera, for the player who hates it |
| `coop_reloadVary` | `CVAR_ARCHIVE` | **`0`** | **ships OFF = today's exact deterministic behaviour.** `1` = the model |
| `coop_handTremor` | `CVAR_ARCHIVE` | `1` | L4 scale; `0` disables |
| `coop_viewMotionMax` | `CVAR_ARCHIVE` | `6.0` | degrees; `0` = unclamped (today) |
| `coop_viewMotionAds` | `CVAR_ARCHIVE` | `0.35` | pitch scale while ADS |
| `coop_viewMotionAdsRoll` | `CVAR_ARCHIVE` | `0.20` | roll scale while ADS |
| `coop_reloadFumble` | `CVAR_ARCHIVE` | `0.06` | base fumble probability; `0` disables |
| `coop_reloadSway` | `CVAR_ARCHIVE` | `1.6` | unchanged, still the amplitude unit |
| `coop_wfeelDebug` | **`CVAR_TEMP`** | `0` | one `^~^~^` line per event. **`CVAR_TEMP`, never `CVAR_ARCHIVE`** — `docs/TRAPS.md` T7: an archived diagnostic is a latch that rides `omconfig.cfg` forever (bug-1427, bug-1148) |

**Registration:** these are `cgi.Cvar_Get` in cgame with real non-empty defaults, and — as long as
**no script `getcvar`s them** — T7's `getcvar`-creates-it-empty trap (bug-1669) does not apply. If
any of them ever needs to be read from a `.scr`, it must first be pre-registered in `G_InitGame`
(`fgame/g_main.cpp`). Seed the archived ones in `coop_defaults.cfg` (which execs **before** the
saved config, so a menu change persists), **not** in `autoexec.cfg` (which execs after and would
re-force the default every launch — T7 / bug-710).

---

## 7. Implementation sketch, in the project's conventions

Placement, decided by §0's three bugs:

| channel | where | why |
|---|---|---|
| **angular** (all of L1–L4) | end of `CG_ApplyReloadSway`, called at `cg_view.c:2643` | bug-1942: the one hook every view path flows through, immediately before the final `AnglesToAxis` at `:2645` |
| **positional** (optional eye rise, §7.3) | very end of `CG_OffsetFirstPersonView`, after every other write to `origin[2]` | bug-1238: `CG_OffsetFirstPersonView` runs *after* `CG_CalcViewValues` and rebuilds `vieworg` from the eyes bone (`cg_view.c:786/802`) |
| **viewmodel origin** | **not used for the reload channel** | bug-165/168: the reload animation swallows it |

### 7.1 The function

```c
/* HZM coop [user 2026-08-20] WEAPON FEEL R1 - per-instance reload/action variation.
   "no reload should feel the same with the camera movements".
   Replaces the deterministic two-step ramp (was cg_view.c:106-151). Layers:
     L1 base curve keyed on ps.iViewModelAnim, in NORMALISED ANIM PHASE (not a hardcoded 900ms)
     L2 per-instance seeded amplitude / timing / yaw / fumble
     L3 context, sampled ONCE at the seed edge and frozen
     L4 continuous zero-mean hand tremor
     L5 derived per-gun weight (class + STAT_MAXCLIPAMMO + Anim_Time) - no per-gun table
     L6 uniform budget clamp (CoopClampViewMotion)
   Client-side and cosmetic: writes cg.refdefViewAngles only. Never touches ps.viewangles,
   never affects where bullets go, and nothing crosses the wire. */
static void CG_ApplyWeaponFeel(vec3_t vAngles)
{
    static cvar_t *pOn = NULL, *pVary = NULL, *pSway = NULL, *pTrem = NULL, *pFum = NULL,
                  *pAds = NULL, *pAdsR = NULL, *pDbg = NULL;
    static int          s_iLastAnim = -1, s_iLastChanged = -1, s_iShell = 0;
    static unsigned int s_uSeed     = 0;
    static wfeelCtx_t   s_ctx;
    static float        s_envP = 0.0f, s_envY = 0.0f, s_envR = 0.0f;   /* eased envelopes */

    float p, pw, amp, w, dP, dY, dR, rate, dt, tLen, tEl;
    int   iAnim, slot, idx;

    if (!pOn) {
        pOn   = cgi.Cvar_Get("coop_viewMotion",       "1",    CVAR_ARCHIVE);
        pVary = cgi.Cvar_Get("coop_reloadVary",       "0",    CVAR_ARCHIVE); /* SHIPS OFF */
        pSway = cgi.Cvar_Get("coop_reloadSway",       "1.6",  CVAR_ARCHIVE);
        pTrem = cgi.Cvar_Get("coop_handTremor",       "1",    CVAR_ARCHIVE);
        pFum  = cgi.Cvar_Get("coop_reloadFumble",     "0.06", CVAR_ARCHIVE);
        pAds  = cgi.Cvar_Get("coop_viewMotionAds",    "0.35", CVAR_ARCHIVE);
        pAdsR = cgi.Cvar_Get("coop_viewMotionAdsRoll","0.20", CVAR_ARCHIVE);
        pDbg  = cgi.Cvar_Get("coop_wfeelDebug",       "0",    CVAR_TEMP);    /* NEVER ARCHIVE - T7 */
    }

    /* --- suppression gates, in the order that matters --- */
    if (!cg.snap || pOn->value <= 0.0f) { s_envP = s_envY = s_envR = 0.0f; return; }
    /* bug-1306: a spectator keeps STAT_HEALTH at max, so h<=0 is NOT a liveness test. */
    if (!(cg.snap->ps.stats[STAT_HEALTH] > 0
          && !(cg.snap->ps.pm_flags & (PMF_SPECTATING | PMF_INTERMISSION)))) {
        s_envP = s_envY = s_envR = 0.0f; return;
    }
    if (cg.snap->ps.pm_flags & (PMF_TURRET | PMF_CAMERA_VIEW)) {
        s_envP = s_envY = s_envR = 0.0f; return;
    }
    if (cg.renderingThirdPerson) {                 /* fixes defect 5 */
        s_envP = s_envY = s_envR = 0.0f; return;
    }

    /* --- L1 phase, from the animation system: no hardcoded ms, no per-gun table --- */
    iAnim = cg.snap->ps.iViewModelAnim;
    slot  = cgi.anim->g_iCurrentVMAnimSlot;
    idx   = cgi.anim->g_VMFrameInfo[slot].index;
    tLen  = (cg.pPlayerFPSModel && idx >= 0) ? cgi.Anim_Time(cg.pPlayerFPSModel, idx) : 0.0f;
    tEl   = cgi.anim->g_VMFrameInfo[slot].time;
    p     = (tLen > 0.01f) ? (tEl / tLen) : 0.0f;
    if (p > 1.0f) { p = 1.0f; }

    /* --- the edge. MUST include iViewModelAnimChanged or single-loaders never re-seed --- */
    if (iAnim != s_iLastAnim || cg.snap->ps.iViewModelAnimChanged != s_iLastChanged) {
        s_iShell = (iAnim == VM_ANIM_RELOAD_SINGLE && s_iLastAnim == VM_ANIM_RELOAD_SINGLE)
                   ? s_iShell + 1 : 0;
        s_iLastAnim    = iAnim;
        s_iLastChanged = cg.snap->ps.iViewModelAnimChanged;
        s_uSeed        = CoopWFeelSeed();          /* §2 */
        CoopWFeelSampleContext(&s_ctx);            /* L3, frozen for the instance */
        if (pDbg->integer) {
            cgi.Printf("^~^~^ WFEEL ev=%s wpn=\"%s\" cls=0x%02x clip=%d/%d T=%.2fs seed=0x%08X "
                       "amp=%.2f dur=%.2f yaw=%+.2f fum=%d w=%.2f shell=%d "
                       "ctx=[ads=%d crouch=%d spd=%.2f supp=%.2f hp=%.2f stam=%.2f]\n", ...);
        }
    }

    /* --- L2 / L3 / L5 --- */
    w   = CoopWFeelWeight(tLen);                                     /* §4, clamped [0.50,1.80] */
    pw  = powf(p, 1.0f + 0.22f * (pVary->integer ? CoopG(s_uSeed, WF_CH_TIME) : 0.0f));
    amp = pSway->value * w * s_ctx.ctxAmp
        * (pVary->integer ? (1.0f + 0.28f * CoopG(s_uSeed, WF_CH_AMP)) : 1.0f);

    dP  = CoopWFeelCurve(iAnim, pw, s_uSeed, pFum->value * s_ctx.fumbleMul) * amp;
    dR  = dP * (0.30f + (pVary->integer ? 0.16f * CoopG(s_uSeed, WF_CH_ROLL) : 0.0f));
    dY  = (pVary->integer) ? 0.35f * w * s_ctx.ctxAmp * CoopG(s_uSeed, WF_CH_YAW) : 0.0f;

    /* --- ease: heavier gun tracks its own curve more lazily --- */
    dt   = (cg.frametime > 0) ? cg.frametime * 0.001f : 0.0f;
    rate = CoopClamp(14.0f / w, 6.0f, 20.0f);
    s_envP += (dP - s_envP) * rate * dt;
    s_envY += (dY - s_envY) * rate * dt;
    s_envR += (dR - s_envR) * rate * dt;

    /* --- L4 continuous tremor: zero-mean, stateless, |n| <= 1 by construction --- */
    {
        float t = cg.time * 0.001f, n, aT;
        n  = ((float)sin(t * 1.70)
           + 0.45f * (float)sin(t * 3.90 + 1.7)
           + 0.20f * (float)sin(t * 8.30 + 4.1)) * (1.0f / 1.65f);
        aT = pTrem->value * (0.10f + 0.35f * CoopWFeelStress());
        if (CG_IsBreathSteady()) { aT *= 0.15f; }
        s_envP += n * aT;
        s_envR += n * aT * 0.6f;
    }

    /* --- ADS: sacred (§3.1) --- */
    if (cg.snap->ps.stats[STAT_INZOOM]) {
        s_envP = s_envY = s_envR = 0.0f;
    } else if (CG_AimingDownSights()) {
        s_envP *= pAds->value;
        s_envR *= pAdsR->value;
        s_envY  = 0.0f;                  /* hard zero - no lateral drift behind a sight post */
    }

    /* --- L6 budget (§6). Applies to the coop TOTAL, not just this function's share --- */
    CoopClampViewMotion(&s_envP, &s_envY, &s_envR);

    vAngles[0] -= s_envP * pOn->value;
    vAngles[1] += s_envY * pOn->value;
    vAngles[2] += s_envR * pOn->value;
}
```

Debug line, as it should read in `qconsole.log`:

```
^~^~^ WFEEL ev=RELOAD wpn="M1 Garand" cls=0x02 clip=0/8 T=2.35s seed=0x8F3A21C4 amp=1.11 dur=1.07
      yaw=-0.21 fum=0 w=1.24 shell=0 ctx=[ads=0 crouch=1 spd=0.00 supp=0.31 hp=0.62 stam=0.88]
```

### 7.2 Two supporting accessors to add (2 lines each, `cg_view.c` + `cg_local.h`)

```c
float    CG_GetSuppression(void);        /* returns s_coopSuppress. ONE FRAME STALE - CG_CalcFov
                                            (:2037) runs after the sway hook (:2643). 16 ms @60fps */
qboolean CG_GetStamina(float *outFrac);  /* exposes s_spStam (cg_view.c:1336-1339); mirrors the
                                            existing CG_IsBreathSteady pattern at :738 */
```

### 7.3 Optional phase 2: move some energy from rotation into translation

A rotation lies to the 1P crosshair by 20 px per degree (§3.1). **A translation does not** — it
moves the eye, not the aim ray, and the parallax at weapon range is negligible. So a 1.0–1.5 unit
(≈1–1.5 inch; 1 u ≈ 1 in in this project) eye rise on the "heft" beat is crosshair-honest and
motion-sickness-cheap — and this channel is **currently unused for reloads**.

Applied at the very end of `CG_OffsetFirstPersonView`, immediately before
`VectorCopy(origin, cg.playerHeadPos)` — the exact placement bug-1238 had to find. It must be
**traced** the way bug-1250 forced (`CG_Trace` with `MASK_CAMERASOLID`, scale by the hit fraction,
minus 2 u) so the eye cannot be pushed through a low ceiling.

Recommend: ship phase 1 rotation-only (parity with today), and evaluate 7.3 after the user has
felt phase 1. **INFERRED** value; do not build both at once.

---

## 8. Acceptance — six live-observable tests, one build

The user tests one build per session and reports what they **see**. Every test below is a thing
you can see, not a number you have to trust.

| # | test | pass |
|---|---|---|
| 1 | `coop_reloadVary 1`, `coop_wfeelDebug 1`. Stand still, reload the same gun 6×. | 6 different `seed=` values in `qconsole.log`, and the user can *name* which one felt heaviest. If they cannot tell them apart, raise the L2 gains — the model works, the amplitude is too shy |
| 2 | **The single-loader test.** Shotgun or Kar98: fire 4, reload. | The camera moves **per shell**, differently each shell, then the `RELOAD_END` bolt snaps down. Today the camera is *flat* for the whole sequence (§0 defect 3) — the clearest before/after in the feature |
| 3 | **The honesty test.** Reload, then fire the *instant* the gun is ready, at a wall corner. | The round lands exactly on the crosshair. Fails if the envelope has not settled to ≤0.05° — which the phase-keyed curve guarantees and the hardcoded 900 ms does not |
| 4 | **The ADS test.** Hold ADS through a full reload with a front-post rifle. | The sight post stays **level** (roll ≤0.20×) and does not swing **sideways** (yaw hard 0). The sight picture stays usable throughout |
| 5 | **The rollback test.** `coop_reloadVary 0` mid-session, reload 4×. | Reloads become identical again, and identical to the current build. No restart needed |
| 6 | **The 3P test.** `cg_3rd_person 1`, reload. | The chase camera does **not** pitch. Today it does (`cg_view.c:2643` is ungated) |

Bonus, for §6: get downed near a grenade and reload the pistol. With `coop_viewMotionMax 6` the
combined roll is bounded; with `coop_viewMotionMax 0` it reaches ~10.7° and should be visibly
worse. That is the anti-sickness clamp being *demonstrated*, not asserted.

### Rollback — one command

`hzm-mohaa-coop-mod/coop_mod/cfg/wfeel_off.cfg`, in the house style of `rag_soft.cfg`:

```
// HZM coop - WEAPON FEEL: back to the pre-R1 deterministic reload sway  [suggested bind F7]
// Restores exactly the behaviour of the 2026-08-19 build: one fixed curve per reload type, no
// per-instance variation, no tremor, no budget clamp. Use this to A/B against coop_reloadVary 1.
coop_reloadVary    0
coop_handTremor    0
coop_viewMotion    1
coop_viewMotionMax 0
coop_reloadSway    1.6
echo "WEAPON FEEL: OFF (pre-R1 deterministic). exec coop_mod/cfg/wfeel_on.cfg to switch back."
```

Ship `wfeel_on.cfg` as the mirror. Bind both in `autoexec.cfg` beside the existing ragdoll A/B
pair, and **do not `seta`** either file's cvars there (T7 / bug-710): the archived defaults belong
in `coop_defaults.cfg`, which execs before the saved config so a menu change persists.

---

## 9. Networking — the answer is no

**Nothing in this design needs a new networked field.** Everything it reads is already on the wire
or already local:

| needed | already available |
|---|---|
| which action is playing | `ps.iNetViewModelAnim`, 4 bits, `msg.cpp:3366` → `ps.iViewModelAnim` via `CPT_NormalizeViewModelAnim` (`client/cl_parse.cpp:347`) |
| that the action **restarted** | `ps.iViewModelAnimChanged`, 2 bits, `msg.cpp:3358` |
| animation length + elapsed | local: `cgi.Anim_Time` + `cgi.anim->g_VMFrameInfo[].time` |
| magazine size / current clip | `ps.stats[STAT_MAXCLIPAMMO]` / `[STAT_CLIPAMMO]` |
| weapon class | `ps.stats[STAT_EQUIPPED_WEAPON]` |
| weapon name | `CG_ConfigString(CS_WEAPONS + ps.activeItems[1])` |
| stance / speed / health / suppression | `pm_flags`, `ps.velocity`, `ps.speed`, `ps.stats[STAT_HEALTH]`, local `s_coopSuppress` |

**Ship footprint: `cgame.dll` only.** No `exe`, no `game.dll`, no protocol constant. That is the
whole point of keeping it client-side — contrast the `GENTITYNUM_BITS` and `MAX_SNAPSHOT_ENTITIES`
changes (bugs 914-927, 1186), which forced `exe + cgame + game` to ship together and produced a
silent-discard class of bug when one member was missed.

**If a later phase ever wants a server-authored cue** (e.g. "this reload was interrupted by a
scripted event"), the established cheap channel is a server-stuffed per-client cvar consumed and
cleared on the client — exactly the `coop_dizzy` pattern at `cg_view.c:158-168`. That is a
stufftext, so it is subject to T8's lossy-channel rules (bug-758: quotes get truncated on the
wire; use unquoted tokens). **Do not add a playerState field for feel.**

---

## 10. Open questions (require a running build, not more reading)

1. **Do the reload `Anim_Time` values actually separate the guns?** The whole no-table weight
   argument rests on it. `coop_wfeelDebug 1` + one armory sweep answers it in a single session.
   **INFERRED.**
2. **Does `g_VMFrameInfo[slot].time` behave during the crossblend?** `cg_viewmodelanim.c:620-636`
   keeps two slots weighted while `g_bCrossblending` is true. `g_iCurrentVMAnimSlot` is the
   *incoming* anim, so `p` should be correct from frame 1, but it wants a look at the first 2-3
   frames of a reload. **INFERRED.**
3. **Is `0.35°` of yaw enough to read, or does it need `0.6°`?** Yaw is the highest-value addition
   and also the one most likely to feel wrong. Tune from test 1.
4. **`coop_viewMotionMax 6.0` — right number?** Derived to sit above the current single-effect peak
   (5.5° roll from shell shock) so it only bites on a genuine stack. If the user finds the
   downed + dizzy + reload case still unpleasant at 6.0, drop to 4.5 before touching any layer.
