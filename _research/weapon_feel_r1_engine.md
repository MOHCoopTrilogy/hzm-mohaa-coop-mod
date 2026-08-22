# Weapon Feel R1 - Engine Surface Map

Lens: **what the engine actually gives us.** Every claim carries `file:line` from
`openmohaa-hzm/code/` unless another root is named. APIs are verified against
`cgame/cg_public.h`. Numbers are re-derived from source constants, not asserted.

Status legend: **[P]** proven by reading the code; **[I]** inferred, with the inference named.

---

## 0. The frame timeline (everything else hangs off this)

`CG_DrawActiveFrame` (`cgame/cg_view.c:2902`) runs, in this order:

| # | call | file:line | what it settles |
|---|---|---|---|
| 1 | `CG_ProcessSnapshots` | cg_view.c:2921 | `cg.snap->ps` (the wire state) |
| 2 | `CG_RagdollFrame` | cg_view.c:2927 | - |
| 3 | `CG_PredictPlayerState` | cg_view.c:2957 | `cg.predicted_player_state` |
| 4 | **`CG_CalcViewValues`** | cg_view.c:2960 | the CAMERA (`cg.refdef.vieworg`, `cg.refdefViewAngles`, `cg.refdef.viewaxis`, fov) |
| 5 | **`CG_AddPacketEntities`** | cg_view.c:3066 | the VIEWMODEL - and it *re-writes* the camera axis |
| 6 | `CG_DrawActive` | cg_view.c:3097 | render |

**The single most load-bearing fact in this document:** the first-person viewmodel is
positioned *inside step 5*, and step 5 re-derives `cg.refdef.viewaxis` at
`cg_modelanim.c:2042`. So `CG_CalcViewValues` is **not** the last word on the camera.
Anything written into `cg.refdefViewAngles` in step 4 survives, because nothing resets it
between the two - `cg.refdefViewAngles` is seeded once per frame at `cg_view.c:2311`
(`VectorCopy(ps->viewangles, cg.refdefViewAngles)`) and mutated from there. **[P]**

Inside step 5, the first-person block of `CG_AddPacketEntities` runs:

```
cg_modelanim.c:1954   CG_ViewModelAnimation(&model)          <- advances the VM anim clock
cg_modelanim.c:1955   model.renderfx |= RF_FRAMELERP
cg_modelanim.c:1956   cgi.ForceUpdatePose(&model)
cg_modelanim.c:2039   CG_OffsetFirstPersonView(&model, qfalse)   <- camera origin AND gun origin
cg_modelanim.c:2042   AnglesToAxis(cg.refdefViewAngles, cg.refdef.viewaxis)   <- FINAL camera axis
cg_modelanim.c:2054   cgi.R_AddRefEntityToScene(&model, s1->parent)
```

This chain runs backwards from most engines: the hands model is posed **first**, then the
camera is derived from it - the function's own banner says so at `cg_view.c:1478-1484`. **[P]**

---

## 1. The view pipeline, in execution order

### 1a. Inside `CG_CalcViewValues` (`cg_view.c:2300-2652`)

| order | stage | file:line | acts on |
|---:|---|---|---|
| 1 | seed from predicted state | cg_view.c:2310-2311 | `vieworg`, `refdefViewAngles` |
| 2 | **free-aim deadzone + camera low-pass** (`cg_freeAim`) | cg_view.c:2313-2404 | overwrites `refdefViewAngles[0]`,`[1]` with smoothed `s_faCamPitch/Yaw` |
| 3 | lean view-roll (damped by `cg_adsLeanRoll`) | cg_view.c:2406-2417 | `refdefViewAngles[2]` |
| 4 | **injury sway** (`coop_injurySway`, health-driven lissajous) | cg_view.c:2419-2469 | roll + pitch |
| 5 | damage angles + `cg.viewkick[]` decay (**the recoil kick**) | cg_view.c:2471-2510 | pitch + yaw |
| 6 | prediction error decay | cg_view.c:2515-2527 | `vieworg` |
| 7 | `vieworg[2] += viewheight`; `playerHeadPos`; **SoundOrg/SoundAxis** | cg_view.c:2530-2543 | audio is frozen HERE, before steps 8-11 |
| 8 | `CG_UpdateAdsStage` / `CG_UpdateFreecam` / `CG_UpdateDbnoCam`; decide `cg.renderingThirdPerson` | cg_view.c:2556-2558 | envelopes |
| 9 | `CG_OffsetThirdPersonView` (3P only) | cg_view.c:2588-2591 | `vieworg` + angles |
| 10 | camera-view (cutscene/turret) override | cg_view.c:2597-2626 | replaces both outright |
| 11 | **`CG_ApplyReloadSway`** then **`CG_ApplyShellShock`** | cg_view.c:2635-2636 | `refdefViewAngles` |
| 12 | `AnglesToAxis(refdefViewAngles, refdef.viewaxis)` | cg_view.c:2637 | *provisional* axis |
| 13 | `CG_CalcFov` (ADS zoom, underwater, publishes `r_pp*`) | cg_view.c:2643 | fov |

Note step 7: `cg.SoundAxis` is baked **before** steps 8-11, so nothing added at step 11 can
rotate the listener. A free property worth preserving. **[P]**

### 1b. Inside `CG_OffsetFirstPersonView` (`cg_view.c:749-1518`), first-person path

Called at `cg_modelanim.c:2039` with `bUseWorldPosition = qfalse`.

| order | stage | file:line |
|---:|---|---|
| 1 | eyes-bone block - **discarded in FP** (see below) | cg_view.c:762-822 |
| 2 | `origin[0..1] = predicted origin`; smoothed `cg.fCurrentViewHeight` **hard-assigns `origin[2]`** | cg_view.c:829-863 |
| 3 | pitch-pivot rotation of the eye | cg_view.c:865-884 |
| 4 | lateral lean eye-shift (damped by `cg_adsLeanShift`) | cg_view.c:886-903 |
| 5 | limp envelope `s_limpEnv` (`coop_limpView`) | cg_view.c:913-926 |
| 6 | **walk bob** phase/amp, sprint swell, ADS damp `x0.25` | cg_view.c:928-980 |
| 7 | bob applied: lateral, vertical foot-dip, limp roll | cg_view.c:990-1043 |
| 8 | two `CG_Trace` height/lateral clamps (eye can't punch geometry) | cg_view.c:1048-1064 |
| 9 | **`vDelta = origin - vOldOrigin`; `pREnt->origin += vDelta`** | cg_view.c:1069-1072 |
| 10 | build `mat[]` from `refdefViewAngles` with **pitch x0.5, roll x0.75** | cg_view.c:1075-1080 |
| 11 | `CG_CalcViewModelMovement` -> stock VM bob/offset, added to `pREnt->origin` | cg_view.c:1082-1090 |
| 12 | ADS sway (gun) / scope sway (**view**) / breath-hold / audio duck | cg_view.c:1128-1230 |
| 13 | ADS recoil kick on the **gun origin** | cg_view.c:1232-1256 |
| 14 | **weapon weight / lag spring** on the gun origin | cg_view.c:1258-1322 |
| 15 | free-aim gun lead | cg_view.c:1324-1334 |
| 16 | sprint gun-lower | cg_view.c:1336-1417 |
| 17 | weapon-collision retract (forward trace) | cg_view.c:1419-1449 |
| 18 | DBNO eye drop (camera **and** gun, water-traced) | cg_view.c:1473-1515 |
| 19 | `VectorCopy(origin, cg.playerHeadPos)` | cg_view.c:1517 |

**Why step 1 is discarded in FP:** the eyes-bone branch writes `origin` from
`pCent->lerpOrigin` + the tag, then step 2 does the hard assignment
`origin[2] = cg.fCurrentViewHeight` (`cg_view.c:865`) and `origin[0..1] = predicted origin`
(`cg_view.c:830-831`). Anything written to `origin` before step 2 is simply gone. This is the
`bug-1238` lesson, recorded in the function's own comment at `cg_view.c:1454-1471`. **[P]**

### 1c. Where a new ADDITIVE layer must go

Two different insertion points, for two different kinds of layer. Do not confuse them.

**Camera-angle layer** -> immediately before `AnglesToAxis` at `cg_view.c:2637`, i.e. next to
the two existing calls at `cg_view.c:2635-2636`.

This is the `bug-1942` lesson and it is worth restating exactly, because the failure was
silent. `CG_ApplyShellShock` was first spliced by a regex anchored on the *first*
`AnglesToAxis(cg.refdefViewAngles` in the file - which is at `cg_view.c:2621`, **inside** the
`PMF_CAMERA_VIEW` `camera_posofs` branch. That branch only runs for cutscene/turret cameras,
so in ordinary first-person play the effect never executed at all. The user reported "grenade
went off right beside me and I didn't get the effect" and the code looked correct. The correct
anchor is the **final, unconditional** `AnglesToAxis` at the function tail (`cg_view.c:2637`),
which every view path - 1P, 3P, camera - flows through. **[P]**

One caveat the existing code does **not** honour (section 6): "every path flows through it" is
a virtue for shellshock, which *should* shake a cutscene camera, and a defect for reload sway,
which should not.

**Viewmodel layer** -> inside `CG_OffsetFirstPersonView`, in the `if (!bUseWorldPosition)`
block after `mat[]` is built at `cg_view.c:1080`, alongside the six existing gun layers
(steps 12-17). This block is already gated: it only runs when `PMF_CAMERA_VIEW` is clear and
the player is alive (`cg_modelanim.c:2037-2038`), and it only runs in first person at all
(`cg_modelanim.c:1907`, `if (!bThirdPerson)`). That gating is free and is exactly what a
first-person-only motion layer needs. **This is the recommended home.**

---

## 2. The viewmodel - and whether it moves independently of the camera

### **Yes. Definitively, and the codebase already does it in six places.**

`pREnt` in `CG_OffsetFirstPersonView` is `&model` from `cg_modelanim.c` - the **first-person
hands/arms model** (`model.tiki = cg.pPlayerFPSModel`, `cg_modelanim.c:1949`; the `_fps.tik`
is resolved at `cg_modelanim.c:1913-1946`).

The coupling is **one-directional**:

- Camera -> gun: at `cg_view.c:1069-1072` the gun origin is moved by the *same* delta the
  camera eye moved (`vDelta = origin - vOldOrigin`). The gun follows the eye.
- Gun -> camera: **nothing.** Every `VectorMA(pREnt->origin, ...)` after line 1072 touches only
  the model. `cg.refdef.vieworg` is already finished. **[P]**

Existing proof-by-precedent - all write `pREnt->origin`, none touch the camera:

| layer | file:line | axis used |
|---|---|---|
| stock VM bob/offset | cg_view.c:1086-1090 | `mat[0..2]` |
| ADS breathing sway | cg_view.c:1204-1210 | `mat[1]`, `mat[2]` |
| ADS recoil kick | cg_view.c:1248-1250 | `mat[2]` up, `-mat[0]` back |
| weapon weight/lag | cg_view.c:1319-1320 | `mat[1]`, `mat[2]` |
| free-aim lead | cg_view.c:1330-1331 | `mat[1]`, `mat[2]` |
| sprint lower | cg_view.c:1408-1410 | `-mat[2]` dip, `-mat[0]` back, `-mat[1]` tilt |
| weapon collision | cg_view.c:1445-1446 | `-mat[0]`, `-mat[2]` |

The basis: `mat[]` is built at `cg_view.c:1075-1080` by `AngleVectorsLeft` from a **modified**
copy of `refdefViewAngles` - pitch halved, roll x0.75. `mat[0]` = forward, `mat[1]` = left,
`mat[2]` = up. **[P]**

### The gun itself is a separate entity that inherits the hands

The held weapon is a child entity attached at tag `tag_weapon_right` / `tag_weapon_left`
(`cg_modelanim.c:1627-1630`). Its parent refEntity is fetched from the renderer with
`parent = cgi.R_GetRenderEntity(cent->currentState.parent)` (`cg_modelanim.c:1572`) - the hands
model **as already submitted**, with all offsets applied. **[P]**

Consequence: a nudge to `pREnt->origin` moves **hands + gun rigidly together**. No relative
slide between the hand and the grip.

### Rotation is also available

`model.axis` for the hands is set at `cg_modelanim.c:1484` from
`AnglesToAxis(cent->lerpAngles, model.axis)` - the player entity's **body** angles, not the
view angles. In the first-person path nothing derives the camera from `model.axis` (that only
happens on the `bUseWorldPosition == qtrue` branch, `cg_view.c:765-782`, the dead/cinematic
path). So rotating `model.axis` in first person is purely cosmetic, and rotates hands + gun as
a rigid body. **[P]** The idiom to copy is the ADS grip rotation at `cg_modelanim.c:1655-1673`
(`RotatePointAroundVector` on pairs of axes).

**Design consequence:** a *rotation* of the gun (muzzle tips down and rolls out as the magazine
comes free) is available, is far more expressive than translation, and - unlike moving the
camera - causes no motion sickness. This is the lever the feature should pull hardest.

### ADS: what the sight picture is actually made of

Three separate layers, verified:

1. **World/gun fov split.** `s_adsZoomCur` eased at `cg_view.c:1926-1964`; the *un-zoomed*
   weapon fov is published as `r_weaponfovx` at `cg_view.c:1966`. The renderer builds a second
   projection for the gun only when `r_weaponfovx > 1 && |r_weaponfovx - refdef.fov_x| > 0.05`
   (`renderergl1/tr_main.c:610`) - i.e. **only while the ADS zoom is engaged**. **[P]**
2. **Per-gun grip rotation.** `s_adsGunTune[]` (`cg_modelanim.c:1187`), resolved by
   `CG_FindAdsTune` (`cg_modelanim.c:1303`), applied as pitch/yaw/roll about the weapon tag at
   `cg_modelanim.c:1655-1673`, plus a crouch-only extra at `cg_modelanim.c:1680-1703`. **[P]**
3. **Screen-space shift.** `r_weaponshiftx/y` published at `cg_view.c:1987-1988`, consumed by
   the renderer inside the same ADS-only gate (`tr_main.c:610`, cvars `tr_init.c:50-51`). **[P]**

Alignment is therefore a *rotation* correction putting rear and front sights on the camera
axis, plus a *screen* correction. It follows that:

- **Translating** the hands during ADS slides both sights relative to the eye, so the aligned
  sight line no longer passes through screen centre -> point of aim drifts off the crosshair.
  This is precisely why every existing gun layer damps in ADS: `cg_weaponLagADS 0.35`
  (`cg_view.c:1113`, applied `:1270`), head-bob `x0.25` (`cg_view.c:974`), sprint-lower gated
  off while `bAiming` (`cg_view.c:1386`), scope sway killed by breath-hold (`cg_view.c:1213`).
  **[I]** - geometry, not a code read.
- **Rotating** the hands during ADS is *worse* than translating: the pivot is the hands origin,
  well behind the sights, so a degree of roll swings the front post visibly.

**Rule for the new layer:** expose an explicit `...Ads` scale cvar, default it low (house
precedent 0.25-0.35), and make 0 a legal value that fully suppresses the layer. Follow the
`cg_weaponLagADS` shape exactly.

### Third-person and camera views

`cg_modelanim.c:1907` gates the whole first-person block on `!bThirdPerson`, and
`cg_modelanim.c:2037` gates the `CG_OffsetFirstPersonView(&model, qfalse)` call on
`!(pm_flags & PMF_CAMERA_VIEW)`. A viewmodel layer placed inside that block is therefore
**automatically inert** in 3P, in the shoulder-ADS stage, in freecam, and in cutscenes, with no
extra guard. A camera-angle layer at `cg_view.c:2635` is **not**. **[P]**

---

## 3. Animation state - and reload progress

### The enum (`fgame/bg_public.h:160-176`)

| value | name | note |
|---:|---|---|
| 0 | `VM_ANIM_DISABLED` | moving too fast to hold the gun steady (`player.cpp:13140-13147`) |
| 1 | `VM_ANIM_IDLE` | |
| 2 | `VM_ANIM_CHARGE` | **the ADS / steady-aim pose** (used as the ADS test at `cg_modelanim.c:2013`) |
| 3 | `VM_ANIM_FIRE` | |
| 4 | `VM_ANIM_FIRE_SECONDARY` | |
| 5 | `VM_ANIM_RECHAMBER` | bolt cycle between shots |
| 6 | `VM_ANIM_RELOAD` | **magazine reload** - one shot, whole cycle |
| 7 | `VM_ANIM_RELOAD_SINGLE` | **shell-by-shell insert** - repeats once per round |
| 8 | `VM_ANIM_RELOAD_END` | **close/cock after single-loading** |
| 9 | `VM_ANIM_PULLOUT` | draw |
| 10 | `VM_ANIM_PUTAWAY` | holster |
| 11 | `VM_ANIM_LADDERSTEP` | |
| 12-14 | `VM_ANIM_IDLE_0/1/2` | idle variants |

The magic `6 / 7 / 8` in the current `CG_ApplyReloadSway` (`cg_view.c:130,137,139`) is
confirmed correct - RELOAD / RELOAD_SINGLE / RELOAD_END. They should be the symbols;
`cg_modelanim.c:2013` proves the enum is visible from cgame. **[P]**

### Which reload states each weapon class actually uses

Determined by which anims the `_fps.tik` defines, resolved by name at
`cg_viewmodelanim.c:505-547` (`"%s_%s"`, prefix + suffix), with a silent fallback to `"idle"`
when `Anim_NumForName` returns -1 (`cg_viewmodelanim.c:583-586`). Evidence from the shipped
anim tables (paths under `hzm-mohaa-coop-mod/models/player/base/`):

| class | reload states | evidence |
|---|---|---|
| box-mag semi/auto (Garand, Thompson, MP40, Sten, PPSh, SVT, G43, Enfield, Mosin, Kar98) | **6 only** | `fps_anims_rifle.txt:18,79,168,199,222,245`; `fps_anims_smg.txt:18,53,87,117` |
| single-loaders (Springfield, Kar98-sniper) | **6 -> 7 (xN) -> 8** | `fps_anims_rifle.txt:46-48,127-129` |
| shotgun | 6/7/8 family | `fps_anims_shotgun.txt` |
| bolt rifles | 5 `RECHAMBER` between shots, then 6 | `fps_anims_rifle.txt:102` |

The two single-loaders use **three distinct `.skc` files** (`springfield_reload_start` /
`_fill` / `_end`), so the three states genuinely have different lengths per weapon. A hardcoded
900 ms cannot represent that. The measured length can.

### Networking - the price list

| field | bits | file:line |
|---|---:|---|
| `iNetViewModelAnim` | **4** | `qcommon/msg.cpp:3367` and `:3429` |
| `iViewModelAnimChanged` | **2** | `qcommon/msg.cpp:3358` and `:3420` |

Decoded on the client into `ps.iViewModelAnim` at `client/cl_parse.cpp:347` via
`CPT_NormalizeViewModelAnim` (protocol-version shim, `qcommon/bg_compat.cpp:100-127`). **[P]**

4 bits = 16 codes; the enum uses 0-14. **Exactly one spare code.** A new viewmodel anim state
is a 1-slot budget; a second is a protocol change.

`iViewModelAnimChanged` is a 2-bit wrapping counter, `(x + 1) & 3` at `fgame/player.cpp:13151`,
bumped when the anim differs **or** on `force_restart` (`player.cpp:13150`). It is a *change
edge*, not a counter - and it is the correct restart signal.
`cg_viewmodelanim.c:500` uses it exactly that way. **[P]**

`ps.stats[]` is **full**: `STAT_LAST_STAT` evaluates to 32, `bg_public.h:534` says "may not
have more than 32", and `STAT_MGHEAT` (`bg_public.h:567`) is annotated "uses the last free
MAX_STATS slot". **No new stat without a protocol change.** **[P]**

### >>> RELOAD PROGRESS: **YES - a true normalised 0..1 is available client-side.** <<<

`CG_ViewModelAnimation` maintains a real animation clock in `cgi.anim` (`clientAnim_t`,
`qcommon/q_shared.h:2280-2295`, exposed at `cg_public.h:442`):

- **reset to 0** when the anim changes: `cg_viewmodelanim.c:587`
- **advanced every frame**: `cg_viewmodelanim.c:641`,
  `g_VMFrameInfo[i].time += cg.frametime / 1000.0`
- **clamped to the anim length** for non-`TAF_DELTADRIVEN` anims: `cg_viewmodelanim.c:645-647`
  (delta-driven anims wrap instead, `:646`)
- the length: `cg_viewmodelanim.c:640`, `fAnimLength = cgi.Anim_Time(pTiki, index)`

So:

```c
/* valid anywhere inside CG_OffsetFirstPersonView, first-person path */
int   slot = cgi.anim->g_iCurrentVMAnimSlot;          /* q_shared.h:2285 */
int   idx  = cgi.anim->g_VMFrameInfo[slot].index;     /* q_shared.h:2281 */
float tSec = cgi.anim->g_VMFrameInfo[slot].time;      /* seconds elapsed */
float tLen = cgi.Anim_Time(cg.pPlayerFPSModel, idx);  /* cg_public.h:387  */
float prog = (tLen > 0.0f) ? (tSec / tLen) : 0.0f;    /* TRUE 0..1        */
```

`cg.pPlayerFPSModel` is a `dtiki_t *` on `cg_t` (`cgame/cg_local.h:265`), assigned at
`cg_modelanim.c:1920/1938/1943` and used as `model.tiki` at `:1949` - the exact `pTiki`
`CG_ViewModelAnimation` reads (`cg_viewmodelanim.c:470`). Same handle. **[P]**

Ordering proof the value is **fresh, not stale**: `CG_ViewModelAnimation`
(`cg_modelanim.c:1954`) runs **before** `CG_OffsetFirstPersonView` (`cg_modelanim.c:2039`),
inside the same `if (!bThirdPerson)` block. The clock is already advanced for this frame. **[P]**

Properties that matter:

- **Per-weapon.** `Anim_Time` reads the actual `.skc` length. A Thompson and a Garand yield
  different real durations with no table anywhere.
- **Saturating, not wrapping,** for reload anims (they are not delta-driven; delta-driven means
  root motion, used by legs). `prog` reaches 1.0 and *holds* until the state changes. That is
  extra information: `prog == 1 && still in state 6` means "anim finished, server hasn't moved
  on yet".
- **Crossblend-aware.** `g_iCurrentVMAnimSlot` is the newest anim; during a crossblend other
  slots still carry weight (`cg_viewmodelanim.c:637-673`, `MAX_FRAMEINFOS` = 16,
  `q_shared.h:2141`). Reading the current slot is the right answer.

**Cheaper alternative** if the tiki handle is inconvenient: `cgi.anim->g_iCurrentVMDuration`
(`q_shared.h:2286`) is milliseconds since the current anim started - reset at
`cg_viewmodelanim.c:617`, accumulated at `:627`. Not normalised, but needs no tiki and no
`Anim_Time` call.

**If the layer is placed at `cg_view.c:2635` instead** (the camera hook), the same read works
but the value is **one frame stale**, because `CG_CalcViewValues` runs before
`CG_AddPacketEntities`. At 60-125 fps that is 8-17 ms. Real, and invisible.

### What is NOT available: authored beats

`cgi.Frame_CommandsTime(tiki, animnum, start, end, &cmds)` exists (`cg_public.h:397`) and would
in principle let the layer fire on the *authored* beats of a reload. Dead end here: the shipped
viewmodel reload anims carry **no** frame-command blocks. Checked
`models/player/base/fps_anims_smg.txt:18,53,87,117` and
`fps_anims_rifle.txt:18,46-48,79,168,199,222,245` - every `*_reload` line ends at its
`crossblend` value; `{ client { enter sound ... } }` blocks appear only on `*_pullout`. Reload
sounds live on the **world** weapon's anims, server-side. **[P]**

Therefore: **normalised progress is the mechanism; there are no beats to snap to.** Beats must
be synthesised as fractions of `prog` - which is the honest way anyway, since `prog` is already
scaled to the real per-weapon duration.

---

## 4. Context signals available client-side

All from `cg.snap->ps` (wire state) or `cg.predicted_player_state` (locally predicted).
Predicted fields have **zero** latency; snapshot fields lag up to one snapshot interval.

| signal | exact source | net/local | latency | notes |
|---|---|---|---|---|
| stance (crouch) | `predicted_player_state.pm_flags & PMF_DUCKED` | predicted | 0 | `cg_view.c:1985`, `cg_modelanim.c:1643` |
| lean | `predicted_player_state.fLeanAngle` | predicted | 0 | `cg_view.c:886`, `:2416` |
| eye height / stance proxy | `predicted_player_state.viewheight` vs `CROUCH_EYE_HEIGHT` | predicted | 0 | `cg_viewmodelanim.c:693` |
| **speed** | `VectorLength(predicted_player_state.velocity)` | predicted | 0 | `cg_view.c:824-833`, used `:944` |
| on ground | `predicted_player_state.walking` | predicted | 0 | `cg_view.c:940` |
| **sprint intent** | recomputed client-side: `BUTTON_RUN` clear + `!BUTTON_COOPWALK` + `forwardmove > 0` | local (usercmd) | 0 | `cg_view.c:1379-1385` |
| **stamina** | `s_spStam`, a *client mirror* of the server pool, same cvars (`coop_sprintStamina`, `coop_sprintRegen`) | local mirror | 0, drifts | `cg_view.c:1341-1343`, `:1388-1396`. Not authoritative - a mirror by design |
| **breath-hold** | `s_breathSteady` / `CG_IsBreathSteady()` | local | 0 | `cg_view.c:1170-1181`; accessor `cg_view.c:738` |
| breath remaining | `CG_GetBreathState(&frac, &cooldown)` | local | 0 | `cg_view.c:708` |
| health | `cg.snap->ps.stats[STAT_HEALTH]` | net | 1 snapshot | `bg_public.h:536` |
| health *fraction* | self-calibrating `s_peakHealth` | local derived | 1 snapshot | `cg_view.c:1996+`. Do **not** divide by `STAT_MAXHEALTH` (hardwired 100 per the comment at `cg_view.c:2005-2009`) or by `coop_health` |
| **clip ammo** | `stats[STAT_CLIPAMMO]` | net | 1 snapshot | `bg_public.h:542` |
| reserve ammo | `stats[STAT_AMMO]`, `[STAT_MAXAMMO]`, `[STAT_MAXCLIPAMMO]` | net | 1 snapshot | `bg_public.h:540,541,543` |
| **shot fired** | clip drop of 1-4 on the same weapon | net, derived | 1 snapshot | the existing idiom, `cg_view.c:1235-1243` |
| weapon identity | `CG_ConfigString(CS_WEAPONS + ps.activeItems[1])` | net | configstring | `cg_view.c:1979-1981` |
| weapon **class** | `stats[STAT_EQUIPPED_WEAPON]` masked by `WEAPON_CLASS_*` | net | 1 snapshot | enum `bg_public.h:371-378`; used `cg_view.c:1117-1121`, `:1265-1269` |
| **under fire (near-miss)** | `s_coopSuppress`, bumped by `CG_AddSuppression` from bullet-zing messages | local | 0 | state `cg_view.c:538`, bump `cg_view.c:546-557`. **File-static; no accessor exists yet - one must be added** |
| took a hit | `s_coopHit` (a round actually landed) | local | 0 | `cg_view.c:543` |
| took damage (wire) | `stats[STAT_LAST_PAIN]` | net | 1 snapshot | `bg_public.h:546` |
| nearby explosion | `s_coopHeat` / `CG_AddHeat` | local | 0 | `cg_view.c:562` |
| shellshock severity | `s_dizzySev` / `s_dizzyStart`, seeded by server `set coop_dizzy` | server-stuffed cvar | stufftext | `cg_view.c:92-93`, `:153-197` |
| **ADS state** | `CG_AimingDownSights()` | local (usercmd `BUTTON_COOPADS`) | 0 | `cg_view.c:1540` |
| native scope | `stats[STAT_INZOOM]` | net | 1 snapshot | `bg_public.h:544` |
| view mode | `cg.renderingThirdPerson` | local | 0 | `cg_local.h:227`; decided `cg_view.c:2559` |
| DBNO | `coop_dbnoView` | server-stuffed | stufftext | `cg_view.c:2447` |
| limping | `coop_limpView` (server stuffs on change, `Player::TickLimp`) | server-stuffed | stufftext | `cg_view.c:917` |
| time since last shot | derive from the clip-drop edge + `cg.time` | local derived | - | no engine field; trivially maintained |
| frame dt | `cg.frametime` (ms) | local | 0 | |

**On "is ammo known before the reload completes?"** `Weapon::StartReloading`
(`fgame/weapon.cpp:3718`) plays the world reload anim and defers `EV_Weapon_DoneReloading` to
its end (`weapon.cpp:3724`). The clip is filled by `Weapon::FillAmmoClip`
(`weapon.cpp:3608`) - a *separate* event bound at `weapon.cpp:926`, fired either by a
`fillclip` frame command partway through the world reload anim, or, if that anim is missing,
immediately at `weapon.cpp:3727`. So `STAT_CLIPAMMO` steps up **mid-animation**, at whatever
frame the world weapon's anim commands, not at the end. **[P]** for the code path,
**[I]** for the exact frame - the mod ships no weapon `.tik` containing `fillclip` (grep over
`hzm-mohaa-coop-mod/models/weapons/*.tik` returns 0 files), so the commands live in the retail
paks and the precise frame was not read.

Practical consequence: **the count you had *before* the reload started is the reliable one.**
Latch `stats[STAT_CLIPAMMO]` on the transition into a reload state (the same edge that seeds
the per-reload random) and use the latched value. Do not sample it live during the reload - it
will step under you at an unspecified moment.

---

## 5. Randomness, and making variation debuggable

Available: `random()` / `crandom()` (`qcommon/q_shared.h:826-828`, `rand()`-backed) and
`Q_random(int *seed)` / `Q_crandom(int *seed)` (`q_shared.h:823-824`, **explicitly seeded** -
the better choice here). cgame already uses `crandom()` freely: `cg_ragdoll.c:2240-2242`,
`cg_ents.c:280`, `cg_view.c:2694`.

**Recommended shape - one seed per reload, not per frame.** Seed once on the reload edge, then
derive every per-reload constant deterministically from it. Per-frame `random()` produces
jitter, which is noise; a per-reload seed produces *character*, which is what "no reload should
feel the same" actually means.

The edge to seed on is **`ps.iViewModelAnimChanged`**, not the anim value. It is bumped once
per anim start including a forced restart (`fgame/player.cpp:13150-13152`) and is exactly how
`cg_viewmodelanim.c:500` detects the same event. Keying on `iViewModelAnim != last` (what the
current code does, `cg_view.c:124-129`) **misses repeats of the same state** - see D1.

Reproducibility for debugging: mix a *cvar-overridable* seed, e.g.

```
seed = pForce->integer ? pForce->integer
                       : (cg.time ^ (clip << 8) ^ (iWpn << 16) ^ animChanged);
```

so `coop_reloadSeed <n>` freezes the variation and makes A/B comparison possible.

### Multiplayer: nothing needs to agree across clients - **confirmed**

Every input in section 4 is either predicted locally, read from the client's own usercmd, or
read from `cg.snap->ps` - the client's **own** player state. `cg.refdefViewAngles` and
`pREnt->origin` live only in the local client's `cg_t` and refdef; neither is transmitted. The
one thing the mod deliberately mirrors back to the server is the *view mode* (`u_view3p`,
`cg_view.c:2582-2586`), for an unrelated entity-filtering reason. A remote player's rendered
arms are the third-person body model, driven by their own networked `torso_anim`/`legs_anim`,
never by this code path (`cg_modelanim.c:1907` gates the whole FP block on
`!bThirdPerson`). **[P]**

The layer is free to differ on every client and every reload. No determinism budget.

---

## 6. Defects found in the existing `CG_ApplyReloadSway` (`cg_view.c:98-151`)

Reported, not fixed - this pass is read-only.

**D1 - the phase timer never restarts on a repeat of the same state.** The start time is
latched on `iAnim != s_iLastVMA` (`cg_view.c:124-129`). A shotgun / Springfield single-load
holds `VM_ANIM_RELOAD_SINGLE` across **every** shell - `iViewModelAnim` does not change, only
`iViewModelAnimChanged` does (`fgame/player.cpp:13150-13152`). Same for a reload interrupted
and restarted. The correct edge is `ps.iViewModelAnimChanged`, as `cg_viewmodelanim.c:500`
uses it. Today state 7 papers over this with a constant (`cg_view.c:137`), which is also *why*
single-loading feels flat.

**D2 - the ease has no `k` clamp, unlike every neighbour.** `cg_view.c:149`:
`s_reloadLift += (fTarget - s_reloadLift) * fRate * fDt;` with `fRate` up to 11.0
(`cg_view.c:148`). Solving `fRate * fDt >= 1`: the RELOAD_END branch overshoots below
**11.0 fps** (dt >= 90.9 ms) and oscillates below **5.5 fps** (dt >= 181.8 ms); the rise branch
(7.0) overshoots below 7.0 fps. Every adjacent system clamps - `cg_view.c:1277-1278`
(`if (k > 1.0f) k = 1.0f`), `cg_view.c:922-923` (dt clamped to 0.25), `cg_view.c:1401-1402`,
`cg_view.c:1435-1436`. A hitch mid-reload can snap the camera. One line.

**D3 - it applies in third person and in cutscene cameras.** The call sits at
`cg_view.c:2635`, after `CG_OffsetThirdPersonView` (`:2589`) and after the `PMF_CAMERA_VIEW`
override (`:2597-2626`), with no view-mode guard. In 3P the chase camera's *position* is
already fixed, so a pitch lift rotates the view without moving the eye - the world tips. In a
scripted camera, reloading tilts the cinematic. `CG_ApplyShellShock` beside it *should* be
unguarded (a blast shakes any camera); reload sway should not be. The flip side of `bug-1942`:
the tail hook reaches every path, which is only a virtue when you want every path.

**D4 - the lift feeds the weapon-lag spring.** `CG_ApplyReloadSway` writes
`cg.refdefViewAngles[0]` at `cg_view.c:145`; the weapon-lag spring later differences that same
field frame-to-frame (`cg_view.c:1281-1289`, `s_prevPitch`). The reload lift is read as a
player turn and pushes the gun. Magnitude at `coop_reloadSway 1.6`: the RELOAD_END branch moves
at up to `11.0 * 0.448 = 4.93 deg/s`, so ~0.082 deg/frame at 60 fps, into
`tY = dPitch * fGain(0.7) * fWeight(<=1.5)` ~= 0.086 units. Small, but unintended, and it
scales with `coop_reloadSway`. A viewmodel-space layer has no such coupling.

**D5 - magic numbers for enum values** at `cg_view.c:130,137,139`, where `VM_ANIM_RELOAD`,
`VM_ANIM_RELOAD_SINGLE`, `VM_ANIM_RELOAD_END` are in scope.

**D6 - the hardcoded 900 ms is wrong for most weapons.** `cg_view.c:132`
(`fPhase = (cg.time - s_iVMAStart) * (1.0f / 900.0f)`) assumes every reload is 0.9 s. The real
per-weapon length is one `cgi.Anim_Time` call away (section 3). **This is the direct cause of
the user's complaint** - it is the same curve over the same 900 ms for every gun in the game.

### Current sway magnitudes, re-derived from `coop_reloadSway` = 1.6

| state | target pitch | target roll (`x0.3`, `cg_view.c:146`) | ease rate | 1/e settle |
|---|---:|---:|---:|---:|
| `VM_ANIM_RELOAD` start (`0.62x`) | 0.992 deg | 0.298 deg | 7.0 /s | 143 ms |
| `VM_ANIM_RELOAD` end (`1.00x`) | 1.600 deg | 0.480 deg | 7.0 /s | 143 ms |
| `VM_ANIM_RELOAD_SINGLE` (`0.70x`) | 1.120 deg | 0.336 deg | 7.0 /s | 143 ms |
| `VM_ANIM_RELOAD_END` (`-0.28x`) | -0.448 deg | -0.134 deg | 11.0 /s | 91 ms |
| return to neutral | 0 | 0 | 4.5 /s | 222 ms |

---

## 7. Cost of anything that needs the wire

The constraint is client-side and cosmetic, and everything this feature needs already is
client-side. For completeness, the price if that ever changes:

| want | cost |
|---|---|
| a new `VM_ANIM_*` state | 1 spare code in `iNetViewModelAnim`'s 4 bits (`msg.cpp:3367`). The 16th is free; the 17th is a protocol change |
| a new `ps.stats[]` entry | **not available** - `STAT_LAST_STAT` == 32, capped at 32 (`bg_public.h:534`) |
| a new `playerState_t` field | protocol change: `msg.cpp` field tables + `bg_compat.cpp` version shims; **exe + cgame + game must ship together** (precedent: `GENTITYNUM_BITS`, `MAX_SNAPSHOT_ENTITIES` 1024->2048) |
| server -> one client, low rate | **free** - stufftext a per-client cvar, as `coop_dizzy` / `coop_limpView` / `coop_dbnoView` already do (`cg_view.c:92`, `:917`, `:2447`). cgame-only |

**Nothing in section 3 or 4 requires any of these.** The recommendation is a cgame-only change:
one DLL, `build.ps1` deploys it, rollback is a cvar.

---

## 8. Bottom line for the design pass

1. Put the new layer in the **viewmodel**, in `CG_OffsetFirstPersonView` after `mat[]` is built
   (`cg_view.c:1080`), alongside the six existing gun layers. It is automatically inert in 3P,
   freecam, cutscenes and while dead; it does not touch the camera; it cannot cause motion
   sickness.
2. Drive it from **real normalised animation progress**, not wall-clock:
   `g_VMFrameInfo[g_iCurrentVMAnimSlot].time / cgi.Anim_Time(cg.pPlayerFPSModel, index)`.
   Per-weapon durations come free, which alone kills D6.
3. Prefer **rotation of `model.axis`** (the `cg_modelanim.c:1655-1673` idiom) over pure
   translation - a gun that tips and rolls reads as weight; a gun that slides reads as a bug.
4. Seed the per-reload variation **once**, on the `ps.iViewModelAnimChanged` edge, with a
   `coop_reloadSeed` override so it is reproducible under test.
5. Scale to near-zero in ADS via an explicit `...Ads` cvar (house default 0.25-0.35), and make
   the master cvar default to **today's behaviour** so the build is a no-op until switched on.
6. Leave `CG_ApplyReloadSway` in place but ship `coop_reloadSway 0` alongside the new layer, so
   rollback is `coop_reloadSway 1.6; <newcvar> 0` - one console line, no rebuild. Test cfgs
   belong in `hzm-mohaa-coop-mod/coop_mod/cfg/` on the `rag_ab.cfg` pattern (a cvar set plus an
   `echo` telling the user what to look at), bound from `hzm-mohaa-coop-mod/autoexec.cfg`.
