# Vault Camera — design + patch plan

**Status:** design only, nothing implemented. Source read-only for this pass.
**Date:** 2026-08-20
**Feature under design:** client-side camera/viewmodel feedback for the existing server-side vault.

---

## 0. What exists today

`openmohaa-hzm/code/fgame/player.cpp:14704-14734`, inside **`Player::Postthink`** (function opens at
`player.cpp:14562`). Verbatim core:

```cpp
14712            pGV = gi.Cvar_Get("coop_vault", "1", CVAR_ARCHIVE);
...
14714        if (pGV->integer && !IsDead() && !IsSpectator() && groundentity && current_ucmd
14715            && current_ucmd->upmove > 0 && client->ps.clientNum < MAX_CLIENTS
14716            && level.time >= s_fVaultOk[client->ps.clientNum]) {
...
14718            AngleVectors(Vector(0, GetViewAngles().y, 0), vFwd, NULL, NULL);
14719            if ((velocity * vFwd) > 40.0f) {
14720                trace_t trKnee = G_Trace(origin + Vector(0,0,20), ..., + vFwd * 46.0f, ...);
14721                if (trKnee.fraction < 1.0f && trKnee.plane.normal[2] < 0.7f) {
14722                    trace_t trChest = G_Trace(origin + Vector(0,0,56), ..., + vFwd * 52.0f, ...);
14723                    if (trChest.fraction >= 1.0f) {
14728                        s_fVaultOk[client->ps.clientNum] = level.time + 0.8f;
14729                        velocity                         = vFwd * 150.0f + Vector(0, 0, 310.0f);
```

No client feedback of any kind. `coop_vault` is **not** in `coop_defaults.cfg`, `autoexec.cfg`, or any
`.urc` — it exists only as an engine-side archived cvar with no menu entry.

### Measured physics (needed for the curve timings)

`sv_gravity` default 800.

| | value | derivation |
|---|---|---|
| launch v_z | **310** u/s | hard assignment, `player.cpp:14729` |
| launch horizontal | **150** u/s, exactly along view yaw | same line — note this **replaces**, so strafe is zeroed |
| apex | **+60.1 u** | 310² / (2·800) |
| time to apex | **388 ms** | 310 / 800 |
| total airtime | **≈775 ms** | 2 × 388 |
| re-trigger lockout | **800 ms** | `player.cpp:14728` |

The 800 ms cooldown matching the 775 ms airtime is strong evidence the 310 figure was tuned against a
*non-stacking* arc. **See Risk 2 — it probably does stack, and that must be measured before the curve
timings are trusted.**

Obstacle envelope: knee trace blocked at +20 u, chest trace clear at +56 u ⇒ the obstacle top sits
between 20 and 56 units. A 60 u apex clears a 56 u obstacle by 4 units. Tight, and consistent with
"waist-high only".

---

## 1. Signal audit — how does cgame learn a vault happened?

### 1a. Verdict table

| # | Candidate | Verdict | Evidence |
|---|---|---|---|
| **a** | Entity event (`s.event` / `EV_*` / `CG_EntityEvent`) | **IMPOSSIBLE — the system does not exist in this engine** | `entityState_t` (`qcommon/q_shared.h`) has **no `event` or `eventParm` field**. `CG_EntityEvent` does not exist. `entity_event_t` (`fgame/bg_public.h:216-232`) is only `EV_NONE, EV_FALL_*, EV_TERMINAL_VELOCITY, EV_WATER_*, EV_LAST_PREDICTED` — a **pmove-local** enum consumed **server-side only** at `fgame/player.cpp:7080`. Decisive: **`CG_TransitionPlayerState()` is an empty stub** — `cgame/cg_playerstate.c:38` reads `void CG_TransitionPlayerState(playerState_t *ps, playerState_t *ops) {}`. MOHAA replaced Q3 entity events with TIKI frame-commands. Adding one is not "a protocol change", it is **building a subsystem that was deleted**. |
| **b** | Stufftext / server command to that one client | **Works, proven in this exact file — but the most trap-laden option in the project** | Established change-only pattern at `player.cpp:13257` (`coop_limpView`) and `player.cpp:13505` (`coop_coverView`). But `docs/TRAPS.md:452-489` (**T8**) lists **eight** silent failure modes, and `MAX_RELIABLE_COMMANDS` overflow **disconnects the client** (bug-681, bug-1183, bug-1670). A vault is an *edge*, not a level, so the change-only guard that makes limp/cover cheap does not apply — you would send one reliable command per vault. |
| **c1** | Spare `pm_flags` bit | **FULL — no free bit** | `net_pm_flags` is a **16-bit** netfield (`qcommon/msg.cpp:3373` and `:3435`). All 16 bits are allocated (`bg_public.h:266-283`), bit 15 = `PMF_NO_HUD`. **This project already spent the last spare** — `PMF_COOP_COVER (1 << 13)`. Widening the field is a protocol change ⇒ **all four binaries** (`docs/ENGINE.md:60-80`). |
| **c2** | Spare `iViewModelAnim` value | **Technically one slot free, but hostile** | `iNetViewModelAnim` is a 4-bit netfield (`msg.cpp` PSF table); `vmAnim_e` (`bg_public.h:160-176`) defines 15 values (0-14), so **15 is unused**. But `CG_ApplyReloadSway` already *switches on this exact field* (`cg_view.c:130-146`), `CG_ViewModelAnimation` drives the gun from it, and it is semantically the weapon's animation state. Hijacking it means game.dll + cgame.dll agreement anyway, for a worse signal. |
| **c3** | `damage_angles` | **Already owned, wrong semantics** | Networked as 3 × 13-bit angle, gated by `PMF_DAMAGE_ANGLES (1<<1)`, applied at `cg_view.c:2618-2622` — **and only inside the `PMF_CAMERA_VIEW` branch**, i.e. it does not reach normal first-person play. It is the damage-kick channel; co-opting it collides with damage. |
| **d** | **Client-side, no server change** | **RECOMMENDED — but as *predicate recomputation*, not signature inference** | See 1b. |

### 1b. Why (d) wins — and the distinction that makes it work

**Signature inference would fail.** The naive form — "watch for a sharp upward velocity step" — is not
viable here, and the numbers say so:

- Normal jump: `Player::Jump` (`player.cpp:8867-8898`) does `velocity[2] += sqrt(2 * sv_gravity * maxheight)`
  with `maxheight = 56` (`coop_mod/player_legs.st:1236` and `:1272`, `commanddelay 0.05 jump 56`)
  ⇒ **+299.3 u/s**.
- Vault: **310 u/s**.

**3.6 % apart.** No threshold separates them. Worse, *normal jumps are also unpredicted* — jumping is
driven by the animation statemap firing a server-side `jump` event, not by `bg_pmove.cpp` — so "arrived
as an unpredicted velocity step" describes both.

**Predicate recomputation does work.** cgame has everything the server test needs, at the moment of input:

| Server needs | cgame has | Proof |
|---|---|---|
| `current_ucmd->upmove > 0` | `usercmd_t` incl. `upmove` | `cgi.GetUserCmd(cgi.GetCurrentCmdNumber(), &cmd)` — already used for exactly this class of thing at `cg_view.c:1356` (sprint), `:1147`, `:1554`, `:2338` |
| `groundentity` | `cg.predicted_player_state.walking` / `groundEntityNum` | used at `cg_modelanim.c:1890` for the landing sound |
| `origin`, `velocity`, view yaw | `cg.predicted_player_state.*` | throughout `cg_view.c` |
| `G_Trace(...)` × 2 | `CG_Trace(...)` | `cg_predict.c:216`; already used for a cosmetic camera trace at `cg_view.c:1505-1512` |
| the `coop_vault` cvar | `cgi.Cvar_Get` | listen host shares the cvar store (`cg_predict.c` bug-950 note) |

So cgame can run **the same two traces with the same constants on the same state** and fire at the exact
input instant — no latency, no snapshot delay, no ambiguity with ordinary jumps.

There is direct precedent for mirroring server movement logic client-side in this very file: the sprint
lower at `cg_view.c:1330-1398` mirrors the server's stamina pool and reads `scmd.buttons` to decide,
described in-source as *"a client-side mirror of the stamina pool (same cvars as the server, so it
tracks the listen-server host closely). VISUAL ONLY"*.

**False-positive analysis** (the thing the naive approach gets wrong, and this one gets right):

| Event | Fires? | Why |
|---|---|---|
| Ordinary jump in the open | **No** | knee trace is clear |
| Jump into a wall (chest blocked) | **No** | chest trace fails — same as the server |
| Jump pad / `push` trigger | **No** | no `upmove > 0` from the player |
| Explosion knockback | **No** | no `upmove > 0`, not on ground |
| Elevator / moving platform | **No** | no jump press, knee clear |
| Stairs | **No** | step geometry — knee trace hits a normal with `z >= 0.7`, rejected identically by both sides |
| Running up to a crate and jumping | **Yes — correctly**, this *is* the vault |

**Residual divergence** (honest list — these are the only ways it can be wrong):

1. **Server has `coop_vault 0`, remote client has it 1.** Client plays the camera, no vault happens.
   Only on a remote client (a listen host shares the cvar). Fixed by optional Stage 3.
2. **Cooldown desync.** Both sides run an 800 ms lockout off the same input, so they stay in step — but
   a server-side rejection the client did not predict (case 1, or a `IsDead`/`IsSpectator`/vehicle edge)
   arms the client's lockout without arming the server's.
3. **Sub-frame trace disagreement.** Client traces against the predicted origin, server against its own.
   At the 46 u / 52 u trace lengths a few units of prediction error can flip the result at the exact
   threshold distance. Rare, and the failure is a small camera dip with no vault — cosmetic.

All three degrade to *"a brief camera nudge that did not need to happen"*. Phase 1 is 70 ms and ~1.6°,
which is why it is deliberately the smallest phase (see §2).

### 1c. Recommendation

> **Option (d): recompute the vault predicate in cgame.**
> **Ship unit: `cgame.dll` alone.**

**Version-compat behaviour — this is the option's strongest property:**

| | Behaviour |
|---|---|
| Old client → new server | Vault works, no camera. Exactly today's behaviour. **No break.** |
| New client → old server | Vault works (the mechanic predates this work), camera works. **No break.** |
| New client → server with `coop_vault 0` | Camera fires on a vault that does not happen. Cosmetic only. Stage 3 removes it. |
| Mixed lobby | Each client independent. No shared state, no wire format touched. |

**Nothing is added to the wire.** No protocol constant, no netfield, no pm_flags bit, no reliable command.
Per `docs/ENGINE.md:60-80` a protocol raise ships **exe + cgame + game + renderer**; per bug-930 that
discipline was learned by crashing. This design does not enter that category at all.

**Optional Stage 3 (game.dll, tiny)** — only to close divergence case 1: mirror the server's `coop_vault`
to each client once, change-only, using the proven pattern verbatim from `player.cpp:13505`:

```cpp
// in Player::Postthink, beside the vault block
if (pGV->integer != m_iCoopVaultSent) {
    m_iCoopVaultSent = pGV->integer;
    gi.SendServerCommand(edict - g_entities, "stufftext \"set coop_vaultOn %d\"", pGV->integer);
}
```

Value **unquoted**, **one statement**, change-only — the three rules from bug-736 / bug-758. This is at
most one command per client per server-config change (effectively one per connect), nowhere near the
`MAX_RELIABLE_COMMANDS` 512 ceiling. cgame treats a missing `coop_vaultOn` as `1`, so an old game.dll
loses nothing.

---

## 2. The camera design

### 2a. Sign conventions (verified, not assumed)

- `cg.refdefViewAngles[0]` = **pitch, positive = DOWN**. Proof: `cg_view.c:1148` `vAngles[0] -= s_reloadLift; // pitch up with the lifted gun`.
- `cg.refdefViewAngles[2]` = **roll**.
- Viewmodel basis `mat[]`: `mat[0]` = forward, `mat[1]` = left, `mat[2]` = up. Proof: the sprint dip at
  `cg_view.c:1395-1397` — `-fDip` on `mat[2]` is "dip DOWN", `-fBack` on `mat[0]` is "pull BACK".
- **Aim is unaffected.** Bullets follow server-authoritative `ps->viewangles`, not `cg.refdefViewAngles` —
  stated in bug-168 and already relied on by free-aim, lean, viewkick, reload sway and shellshock.

### 2b. Phase-by-phase curve table

Clock `t` = ms since trigger. All magnitudes are **at scale 1.0**, multiplied by `coop_vaultCam`.
Roll additionally multiplied by `coop_vaultCamRoll`. Gun columns multiplied by `coop_vaultGun`.

| # | Phase | Window | Cam pitch (°, + = down) | Cam roll (°) | Eye Z (u) | Gun dip (u) | Gun back (u) | Gun tilt (u) | Ease |
|---|---|---|---|---|---|---|---|---|---|
| 1 | **PLANT** — legs load, lead hand reaches | 0 → 70 ms | 0 → **+1.6** | 0 → +0.6 | 0 → **−2.5** | 0 → −4 | 0 → −2 | 0 → −1 | ease-out (fast) |
| 2 | **PUSH / RISE** — extension, driven up+forward | 70 → 260 ms | +1.6 → **−2.8** | +0.6 → +1.8 | −2.5 → +1.5 | −4 → **−7** | −2 → −3.5 | −1 → −2.2 | ease-in-out |
| 3 | **PASS OVER** — hips clear, body horizontal | 260 → 460 ms | −2.8 → −0.4 | +1.8 → **+2.0** | +1.5 → 0 | −7 → −6 | −3.5 → −3 | −2.2 → −2 | linear (float) |
| 4 | **DROP** — falling far side, weight forward | 460 ms → **land** | −0.4 → +1.8 | +2.0 → +0.4 | 0 → −1 | −6 → −3 | −3 → −1 | −2 → −0.6 | ease-in |
| 5 | **LAND ABSORB** — knees take it | land → +90 ms | +1.8 → **+3.4** | +0.4 → 0 | −1 → **−6** | −3 → **−8** | −1 → −2 | → 0 | ease-out (hard) |
| 5b | **RECOVER** — stand up, slight overshoot | +90 → +330 ms | +3.4 → 0, overshoot **−0.6** at ~240 ms | 0 | −6 → 0, overshoot **+1.0** | −8 → 0 | −2 → 0 | 0 | critically-damped |

Total ≈ **1.10 s** trigger → settled (on a 775 ms airtime).

**Peak magnitudes:** pitch **3.4°**, roll **2.0°**, eye Z **6 u**, gun dip **8 u**.
For calibration against shipped effects in the same file: reload sway peak pitch = **1.6°** with roll =
`lift × 0.3` ≈ 0.5° (`coop_reloadSway` default 1.6); sprint gun dip = **3.0 u**, back 1.4, tilt 1.2.
The vault therefore sits at roughly **2× the reload sway** on the camera and **2.7× the sprint dip** on
the gun — a bigger event, still inside the family.

### 2c. If we can only afford two phases

> **Ship phases 1 (PLANT) and 5 (LAND ABSORB). Cut 2, 3, 4 first. Cut roll before you cut anything else.**

Reasoning: the mid-vault vertical translation is **already delivered for free** — the player's origin
really does rise 60 units and fall back, and the eye follows it. Phases 2-4 add rotation on top of motion
the player can already see. Phases 1 and 5 are the two *impulses* — the load and the impact — and the
engine provides neither. A dip at the start and a dip at the end reads as "I pushed off something and
landed" far more strongly than any amount of mid-air tilt.

Roll is simultaneously the least necessary (it is the phase-3 "float", the most decorative part) and the
best-documented motion-sickness trigger. It gets its own kill switch for that reason.

### 2d. Camera vs viewmodel — the split, and why the gun does most of the work

**The viewmodel can be offset independently of the camera. Confirmed.**

`CG_OffsetFirstPersonView(refEntity_t *pREnt, qboolean bUseWorldPosition)` (`cg_view.c:749`) receives the
first-person model as `pREnt` and moves it with `VectorMA(pREnt->origin, amount, mat[N], pREnt->origin)`.
Existing users of that exact idiom in the same function: recoil (`cg_view.c:1247-1248`), weapon lag
(`:1311-1312`), free-aim (`:1320-1321`), sprint lower (`:1395-1397`), wall-clip pullback (`:1447-1448`).

The call chain runs **backwards** relative to most engines, and this is the load-bearing fact —
`cg_view.c:1467-1471` states it in-source:

> *"cg_modelanim.c positions the first-person model FIRST, then calls in here to derive the CAMERA from
> its eyes bone (pREnt is that model, handed to R_AddRefEntityToScene right after we return). Dropping
> only the camera leaves the gun behind and it climbs the screen as the eye sinks; dropping both keeps
> the weapon at its usual screen position while the whole rig sits lower in the world."*

Therefore three distinct controls exist:

| Want | Do |
|---|---|
| Camera moves, gun stays put in world → gun **climbs the screen** | write `origin[2]` only |
| Whole rig moves, gun holds its screen position | write **both** `origin[2]` and `pREnt->origin[2]` |
| Gun moves **in frame**, camera still | write `pREnt->origin` only, via `mat[]` |

**The split for this feature.** The user's constraint is decisive: *"I know we cant really do any hand
animations"*. With no arms reaching over the obstacle, the **gun is the only object on screen that can
act**. So the gun carries the amplitude and the camera carries the subtlety:

- **Gun (large, 4-8 units):** drop it, pull it back toward the chest, tilt it in. This is what a soldier
  actually does going over a wall — the weapon comes in to the body. It is legible, it is large, and it
  costs no animation because it is pure origin displacement of an already-posed model.
- **Camera (small, 2-3.4°, ≤6 u):** the impulses only. Enough to register as body motion, small enough
  not to read as a glitch or provoke nausea.
- **Eye Z:** write `origin[2]` **and** `pREnt->origin[2]` together (the rigid case), then apply the gun's
  own `mat[]` offsets on top. That keeps the weapon at its normal screen height while the rig dips,
  exactly as the DBNO drop does at `cg_view.c:1515-1518`.

If forced to pick one channel only: **move the gun**. It cannot cause motion sickness, it cannot fight
the sight picture, and with no hands it is the only thing that can sell the action.

---

## 3. Insertion points

The project has put a view offset in the wrong place **four separate times**. The two correct sites are
both documented in-source by the comments left behind after those failures.

### 3a. Angles (pitch, roll) — `cgame/cg_view.c:2644`

Insert beside the two existing hooks, immediately **before** the final `AnglesToAxis`:

```c
2639:    // position eye reletive to origin
2640:    // HZM coop [user 2026-08-19] shell-shock dizziness sways the FINAL view angles for every
2641:    // path (bug-1942: the first hook landed inside the PMF_CAMERA_VIEW camera_posofs branch,
2642:    // which never runs in normal first-person play - the effect was stone dead).
2643:    CG_ApplyReloadSway(cg.refdefViewAngles);
2644:    CG_ApplyShellShock(cg.refdefViewAngles);
     +   CG_ApplyVaultCam(cg.refdefViewAngles);   // <-- HERE
2645:    AnglesToAxis(cg.refdefViewAngles, cg.refdef.viewaxis);
```

**Do not anchor a regex on `AnglesToAxis(cg.refdefViewAngles`.** There are three occurrences in this
function and the first two are decoys — that is precisely bug-1942:

| Line | What it is | Safe? |
|---|---|---|
| 2537 | `AnglesToAxis(SoundAngles, cg.SoundAxis)` | no — sound axis |
| 2626 | inside `PMF_CAMERA_VIEW` → `camera_posofs` branch | **NO — this is the bug-1942 dead branch** |
| 2636 | `cg.SoundAxis`, same dead branch | no |
| **2645** | `cg.refdef.viewaxis`, function tail, every path flows through it | **YES** |

bug-1942 root cause, verbatim: *"`CG_ApplyShellShock` was spliced in by a regex anchored on the FIRST
`'AnglesToAxis(cg.refdefViewAngles'` in the file — which sits inside the `PMF_CAMERA_VIEW`
`camera_posofs` branch. That branch never runs in normal first-person play, so the dizziness sway was
stone dead."* Its stated lesson: *"read the surrounding function, not just the matched line."*

Note this site runs in **third person too**, so the hook must self-gate — see §3d.

### 3b. Eye Z + viewmodel — end of `CG_OffsetFirstPersonView`, `cgame/cg_view.c:1518`

Immediately after the DBNO eye-drop block, immediately **before** `VectorCopy(origin, cg.playerHeadPos);`:

```c
1515:        origin[2] -= drop;
1516:        if (pREnt && !VectorCompare(pREnt->origin, vec3_origin)) {
1517:            pREnt->origin[2] -= drop;
1518:        }
1519:    }
     +   CG_ApplyVaultRig(origin, pREnt, mat);   // <-- HERE
1521:    VectorCopy(origin, cg.playerHeadPos);
```

This is the **only** safe place for a vertical view offset, and the reason is written into the file at
`cg_view.c:1455-1466` after bug-1238 was reported three times against three different placements:

> *"APPLIED HERE, AT THE END, AND NOWHERE ELSE. This value has been placed wrong twice: (1) in
> `CG_CalcViewValues` — discarded, because the eyes-bone block in this function does
> `VectorCopy(pCent->lerpOrigin, origin)` and rebuilds the eye from the model tag. It was not inert
> though: it silently moved the THIRD-person pivot and the camera trace start. (2) mid-function, right
> after the eyes-bone block — also discarded, because the view-height smoothing below it does a hard
> ASSIGNMENT, `origin[2] = cg.fCurrentViewHeight`. Anything written before that is simply gone."*

Two further traps at this site:

- **Do not use the `bUseWorldPosition` branch.** It is not the first-person path — that is
  `bug-lean-ads-wrong-branch`, where a lean-roll damp placed there simply never executed.
- **`mat[]` is valid here** (set from `pREnt->axis` in the eyes-bone block, and used by every viewmodel
  offset in the function through `:1448`), so the gun offsets can be applied in view basis at this point.

### 3c. Composition with existing systems

| System | Site | Interaction | Resolution |
|---|---|---|---|
| **Reload sway** (`CG_ApplyReloadSway`, `cg_view.c:106`) | 2643 | Purely additive on the same vector. Peak 1.6° pitch. | None needed. Both small; a reload cannot be in progress during a vault long enough to matter. |
| **Shellshock / tinnitus** (`CG_ApplyShellShock`, `:153`) | 2644 | Additive. Peak 5.5° roll + 2.8° pitch when severe. | Worst case 5.5 + 2.0 = 7.5° roll. **Apply a global clamp** (§3e). |
| **ADS / iron sights** (`CG_AimingDownSights`, `:1540`) | — | A vault **can** be started while aiming, and any view rotation swims the sight picture. | Damp to **30 %** and **zero the roll** while ADS, following the exact in-file precedent `cg_adsLeanRoll` (`cg_view.c:815-820`), which damps lean roll while aiming *"so the iron sights stay aligned instead of tilting off-screen"*. Gun offsets also damped — a gun that drops 8 u while ADS hides the sights entirely. |
| **Lean roll** | `:821` | Additive roll. | Covered by the clamp. |
| **Landing sound / land detection** | `cg_modelanim.c:1890-1901` | Already edge-detects `cg.predicted_player_state.walking`. | **Reuse the same edge** as the phase-5 trigger. Do not invent a second land detector. |
| **Existing landing view dip** | — | **There is none.** No landing camera dip exists today; `CG_LandingSound` is audio only. | Phase 5 is new behaviour, not a conflict. |
| **View bob** | `cg.fCurrentViewBobAmp`, `cg_view.c:969` | Bob is suppressed while airborne. | No conflict during phases 2-4. |
| **Free-aim** | `:1320-1321` | Offsets `pREnt->origin` on `mat[1]`/`mat[2]`. | Additive; both small. |
| **Weapon lag / sway** | `:1311-1312` | Same. | Additive. |

### 3d. Third person and free-cam

- **Eye Z + viewmodel (§3b):** `CG_OffsetFirstPersonView` is **not called in third person** — the call at
  `cg_modelanim.c:2039` sits inside `if (!bThirdPerson)`. Self-excluding, no gate needed.
- **Angles (§3a):** `cg_view.c:2644` **does** run in 3P. A first-person head-motion tilt applied to a chase
  camera reads as the world rotating. **Gate it:** `if (cg.renderingThirdPerson) return;` at the top of
  `CG_ApplyVaultCam`. This also covers free-cam, cutscene cameras (`PMF_CAMERA_VIEW`), turret cameras and
  the cover auto-3P, all of which set `cg.renderingThirdPerson` or the camera flags before this line.
- **Audio still plays in 3P** — it is triggered independently of the view path (§4).
- **Spectators:** guard with the bug-1306 form, not `health <= 0` — a spectator keeps full `STAT_HEALTH`
  because `Player::Spectator()` resets it. Use
  `!(cg.snap->ps.pm_flags & (PMF_SPECTATING | PMF_INTERMISSION))`.
- **Envelope reset:** clear the vault state on respawn / map change so a stale envelope cannot leak, the
  failure mode of bug-1306 and of the cover-lift note at `cg_view.c:2596-2599`.

### 3e. Clamp

After summing, before use:

```c
if (fPitch >  6.0f) fPitch =  6.0f;   if (fPitch < -6.0f) fPitch = -6.0f;
if (fRoll  >  4.0f) fRoll  =  4.0f;   if (fRoll  < -4.0f) fRoll  = -4.0f;
```

The eye-Z contribution must also **not carry the eye through a surface** — trace it exactly as the DBNO
drop does at `cg_view.c:1495-1512`. bug-1250: the underwater test runs in `CG_CalcFov` at the end of
`CG_CalcViewValues`, *before* this offset is applied, so an untraced drop can put the camera under water
with the engine still convinced you are dry. At 6 units the risk is small but the trace is 8 lines.

---

## 4. Audio

**A vault with no sound will feel weightless.** Three cues, and one is already free.

| Cue | Source | Cost |
|---|---|---|
| **Effort grunt** (phase 1-2) | `sound/coop_deathvox/dv_335.wav` … `dv_484.wav` — **150 MOH Frontline effort clips already shipped**, documented as effort takes at `hzm-mohaa-coop-mod/ubersound/coop_deathvox.scr:361-362` | **Zero new assets** |
| **Gear / cloth scuff** (phase 2-3) | new alias, or reuse `coop_kick`'s neighbours | 1 wav |
| **Landing thump** (phase 5) | **already fires** — `CG_LandingSound` at `cg_modelanim.c:1894`, surface-typed, throttled 200 ms | **Zero work** |

The vault already produces a jump→land arc, so the far-side landing sound plays today with no change.

**How to play it from cgame.** There is a constraint worth stating: **`cg_view.c` is C, not C++.** The
alias-resolving path (`commandManager.PlaySound`, `cg_commands.cpp:3841`, precedent `cg_parsemsg.cpp:2040`)
is a C++ method and **cannot be called from `cg_view.c`**. The C-callable path is:

```c
void (*S_StartLocalSound)(const char *soundName, qboolean forceLoad);   // cg_public.h:245
```

Raw `.wav` path only — **it does not resolve sound aliases**. That is fine, because the effort clips are
addressable by literal path. Precedent in the *same file*, the breath-hold at `cg_view.c:1167-1171`:

```c
cgi.S_StartLocalSound("sound/coop_breath/breath_in.wav", qfalse);
```

and the randomised, rate-limited form at `cg_parsemsg.cpp:1013-1015`. So:

```c
if (pSnd->integer) {
    cgi.S_StartLocalSound(va("sound/coop_deathvox/dv_%d.wav", 335 + (rand() % 150)), qfalse);
}
```

2D and local, which is correct — it is *your own* effort, and only you should hear it at full volume.
Rate-limiting is free: the 800 ms vault lockout already bounds it.

**Caveat to weigh:** `dv_335..484` are pooled with the 334 death grunts (`coop_deathvox1..334`) and the
whole 1..484 pool is drawn at random on death. Using 335-484 for vaulting is legitimate — they are effort
takes, not death cries — but you will occasionally hear the same actor's grunt in both contexts. If that
grates, the fix is to carve a dedicated subset (a handful of the least death-like takes) rather than
record anything new.

**If a server-side sound is preferred instead** (audible to teammates, 3D-positional), the one-line form
at `player.cpp:14729` following the `coop_kick` convention exactly is:

```cpp
Sound("coop_vault", CHAN_BODY, -1.0f, 200, NULL, -1.0f, 1, 0, 1, 1600);
```

with the alias added beside `coop_kick` at `ubersound/ubersound.scr:1547`:

```
aliascache coop_vault sound/<dir>/<file>.wav soundparms 1.0 0.1 1.0 0.1 200 1600 body loaded maps "m e t dm obj train"
```

That is a **game.dll** change, so it does not ship with Stage 1. Comments must be on their own line — a
trailing comment on an alias line kills the parse silently.

---

## 5. Cvars

| Cvar | Default | Flags | Owner | Purpose |
|---|---|---|---|---|
| `coop_vault` | `1` | `CVAR_ARCHIVE` | game.dll (**exists**, `player.cpp:14712`) | the mechanic itself |
| `coop_vaultCam` | `1.0` | `CVAR_ARCHIVE` | cgame | **master scale**, 0 = camera off entirely |
| `coop_vaultCamRoll` | `1.0` | `CVAR_ARCHIVE` | cgame | **roll-only scale** — the motion-sickness escape hatch |
| `coop_vaultGun` | `1.0` | `CVAR_ARCHIVE` | cgame | viewmodel motion scale |
| `coop_vaultSound` | `1` | `CVAR_ARCHIVE` | cgame | effort grunt on/off |
| `cg_vaultCamDebug` | `0` | none | cgame | phase + envelope print, tuning only |
| `coop_vaultOn` | `1` | none | cgame, server-written | Stage 3 only — server's `coop_vault` mirrored |

Defaults belong in **`hzm-mohaa-coop-mod/coop_defaults.cfg`** (`seta coop_vaultCam 1`), **not**
`autoexec.cfg` — `coop_defaults.cfg` runs *before* the saved player config so menu changes persist;
`autoexec.cfg` runs after and would clobber them.

These are cgame-side `cgi.Cvar_Get` cvars that no script reads, so the `G_InitGame` pre-registration rule
(`docs/TRAPS.md:419-420`, the `getcvar`-creates-an-empty-cvar trap that silently killed three features in
bug-1669) does not apply. **If any of them later gains a script reader, it must be pre-registered.**

### Menu placement

`hzm-mohaa-coop-mod/ui/coop_settings.urc` (369 lines) is **structurally full**: eleven Label+CheckBox
pairs in one flat column, last row at y=430-454, panel ends at y=458. **No tabs, no pages, and no `Slider`
anywhere in the file.** A twelfth row does not fit.

**Recommendation:** a new page **`ui/coop_settings2.urc`**, reached by a "MORE →" button, following the
established `coop_postfx` → `coop_postfx2` → `coop_postfx3` chain (`coop_postfx.urc:685`,
`coop_postfx2.urc:373`). It carries the two vault rows and leaves room for the next feature — which this
menu is going to need regardless of the vault.

Precedent for the checkbox: `coop_coverAuto` at `coop_settings.urc:313-337` is the exact analogue — a
game.dll movement mechanic exposed as a plain checkbox. Copy that block; use `font "facfont-20"` and the
dark-on-cream palette, **not** the postfx menus' `courier-16` light-on-dark.

**Parser hazard, stated in the file's own header at `coop_settings.urc:3-4`:** *"each resource field MUST
be on its own line — the URC parser silently drops single-line resource blocks (that was the 'empty menu'
bug)."*

For the *scale* controls (`coop_vaultCam`, `coop_vaultCamRoll`), sliders are the right widget, and
`coop_settings.urc` has none. Slider syntax, verbatim from `coop_postfx.urc:97-110`:

```
resource
Slider
{
	name "slThr"
	rect 205 168 105 16
	...
	linkcvar "r_ppBloomThreshold"
	slidertype float
	setrange 0 1
	stepsize 0.05
}
```

Put the checkbox on `coop_settings2.urc` and the two sliders beside it there, so the feature lives in one
place rather than split across the settings and post-FX menus.

---

## 6. Sharing the machinery with other movement events

The envelope engine is worth generalising into a small **one-shot view-impulse bus**, because four other
events want exactly this shape and one of them already has a detector.

| Event | Share it? | Why |
|---|---|---|
| **Landing** (any hard fall) | **Yes — highest value after the vault** | Trigger already exists (`cg_modelanim.c:1890`), scaled by fall speed. There is no landing dip today. |
| **Mantle** (if added later) | **Yes** | Same phases, different magnitudes. |
| **DBNO revive** | **Yes** | A "getting picked up" rise. Note `s_dbnoCamEnv` (`cg_view.c:199`) is a *sustained* envelope for the downed state; the revive *moment* is the one-shot. |
| **Weapon bash / melee** | **Yes** | Short, sharp, one-shot. |
| **Sprint start/stop** | **No** | Already correct as a sustained first-order envelope (`s_spEnv`, `cg_view.c:1376-1386`). A one-shot is the wrong model. |
| **Emotes** | **No** | Third-person body animations; the first-person camera should not editorialise. |

### Ordering rule when two fire at once

1. **Angles sum, then clamp** (±6° pitch, ±4° roll). They are individually small and rotation composes
   naturally.
2. **Eye Z takes the single largest-magnitude contributor — it does not sum.** Summing Z is how you punch
   the camera through the floor or the waterline; bug-1250 is that lesson already paid for once. On a tie,
   **landing wins**, because it is the impulse tied to a real physical impact.
3. **Same-source re-trigger re-arms the clock, it does not stack** — a second vault inside the envelope
   restarts phase 1 rather than adding a second envelope. (The 800 ms lockout makes this rare, but a
   vault landing *into* a fall makes vault+landing overlap routine.)
4. **Viewmodel offsets sum** without clamping — they are bounded by their own envelopes and a gun
   displaced too far simply leaves the frame, which is recoverable and non-nauseating.

The single most important part of this rule is #2. It is the only one whose violation can produce a
*wrong* image rather than an ugly one.

---

## 7. Motion sickness

This is a **bounded one-shot**, which is the safer category — the sustained, low-frequency, player-passive
oscillation that actually drives simulator sickness is absent here. Three deliberate mitigations:

1. **Roll capped at 2.0°** and given its own cvar (`coop_vaultCamRoll`). Roll around the view axis is the
   best-documented trigger of the three rotations, and it is also the most decorative part of this effect
   — so it is the cheapest thing to surrender.
2. **Total duration ~1.1 s**, entirely player-initiated. Player-initiated motion is far better tolerated
   than imposed motion.
3. **`coop_vaultCam 0` disables it completely** while leaving the vault mechanic working.

**Honest note on precedent:** grepping the full 1332-entry buglog and all authored docs for
`motion sick|nausea|nauseous|queasy|disorient` returns **zero** player complaints. This project's history
runs the *other* way — the user has repeatedly asked for *more* disorientation (bug-1233 chromatic
aberration with dizziness, bug-1322 "add a short period of dizziness after the glider crashes"). So the
magnitudes above are likely to be received as conservative, and there is headroom to raise them after a
playtest. The counterexample worth remembering is **bug-1547** — *"lets remove the frozen effect on screen
for when it snows it looks really bad"* — precedent that a screen-wide view effect can be pulled outright
on feel. Ship it scaled to 1.0, tune upward on request.

---

## 8. Staged implementation plan

Every stage ships **`cgame.dll` alone** unless stated. Back up as
`cgame_pre_vaultcam_bak.dll` before the first deploy — that hand-run convention *is* the rollback system
(`docs/TRAPS.md:518`).

### Stage 0 — Measure the real airtime *(no code ships)*

**This must happen first.** See Risk 2: the statemap fires `commanddelay 0.05 jump 56`
(`player_legs.st:1236`) on the same `+JUMP ONGROUND` input that triggers the vault, and `Player::Jump`
does `velocity[2] +=` (`player.cpp:8888`). If that lands after `Postthink`'s hard assignment, real airtime
is ~1.5 s, not 775 ms, and every timing in §2b is wrong.

- **Do:** add a temporary `cg_vaultCamDebug` print of `cg.predicted_player_state.velocity[2]` and the
  ground-transition timestamps. Vault a crate on `m1l1`.
- **Acceptance:** you can state the measured apex and airtime in ms.
- **Rollback:** delete the print.

### Stage 1 — Detection only, no visuals

Add `CG_VaultDetect()` (predicate recomputation, §1b), called once per frame from `CG_CalcViewValues`
alongside `CG_UpdateAdsStage` / `CG_UpdateFreecam` / `CG_UpdateDbnoCam` — the project's established
"update once, apply later" split. Output: a phase clock, nothing rendered.

- **Live-observable acceptance:** with `cg_vaultCamDebug 1`, run at a waist-high crate and press jump.
  Console prints `VAULT t=0` exactly once, and the player visibly goes over. Then: (i) jump in the open —
  **no print**; (ii) jump into a full wall — **no print**; (iii) walk up stairs jumping — **no print**;
  (iv) stand on a jump pad / take an explosion — **no print**. Ten vaults ⇒ ten prints, zero extras.
- **Rollback:** `copy cgame_pre_vaultcam_bak.dll cgame.dll` over both deploy targets.

### Stage 2 — Viewmodel only (phases 1 + 5)

Apply the gun columns of §2b at `cg_view.c:1519`. **No camera motion at all yet.** This is the
lowest-risk, highest-legibility half of the design and it cannot cause motion sickness.

- **Acceptance:** vaulting visibly drops and pulls the weapon in, then a harder dip on landing, settling
  with no residual offset. Sprint, reload, ADS and free-aim all still move the gun normally afterwards
  (proves no envelope leak). `coop_vaultGun 0` removes it entirely.
- **Rollback:** `coop_vaultGun 0` live, or restore the backup DLL.

### Stage 3 — Camera impulses (phases 1 + 5) + audio

Add `CG_ApplyVaultCam` at `cg_view.c:2644` with the 3P gate, the ADS damp, and the clamp; add the eye-Z
term (traced) at `:1519`; add the `S_StartLocalSound` grunt.

- **Acceptance:** the vault reads as a push and a landing absorb. **Then the leak checks, which matter
  more than the effect:** vault, then immediately enter third person — no residual tilt. Vault while ADS —
  sights stay usable, roll is zero. Vault, die, respawn — envelope is clear. Vault next to a grenade —
  shellshock and vault compose without exceeding the clamp.
- **Rollback:** `coop_vaultCam 0` live (instant, no redeploy).

### Stage 4 — Full five-phase curve

Add phases 2, 3, 4. Land-triggered phase 5 (reusing the `cg_modelanim.c:1890` edge), not clock-triggered,
so it survives whatever Stage 0 measured.

- **Acceptance:** the whole arc reads continuously with no visible seam at a phase boundary, and phase 5
  fires on ground contact regardless of actual airtime — verify by vaulting onto a raised surface (short
  airtime) and off a ledge (long airtime).
- **Rollback:** `coop_vaultCam 0`, or revert to the Stage 3 DLL.

### Stage 5 — Menu + defaults *(mod pk3, no DLL)*

`ui/coop_settings2.urc` with the checkbox and two sliders; `seta` lines in `coop_defaults.cfg`.

- **Acceptance:** the page opens (a silently-empty menu means a single-line resource block —
  `coop_settings.urc:3-4`), the checkbox round-trips `coop_vaultCam`, the sliders move it, and the value
  survives a restart.
- **Rollback:** `.\build.ps1` from the previous commit.

### Stage 6 *(optional)* — Server mirror, **game.dll**

The change-only `coop_vaultOn` stufftext from §1c. Only worth doing if a server is actually run with
`coop_vault 0`.

- **Acceptance:** set `coop_vault 0` on a dedicated server; a remote client stops playing the camera.
  `qconsole.log` shows exactly one `coop_vaultOn` command per client per change — **not per vault**.
- **Rollback:** restore `game_pre_vaultcam_bak.dll`.

---

## 9. Top risks

1. **Client/server predicate divergence.** The client recomputes the vault test rather than being told.
   Diverges when the server refuses a vault the client predicted — chiefly `coop_vault 0` server-side on a
   remote client. *Mitigation:* phase 1 is 70 ms and 1.6°, small enough that a false fire is barely
   perceptible; Stage 6 closes it properly. *Residual:* cosmetic only, never a gameplay difference.

2. **The vault velocity probably stacks with the statemap jump.** `commanddelay 0.05 jump 56`
   (`player_legs.st:1236`) fires on the same input, and `Player::Jump` (`player.cpp:8888`) uses `+=`
   against `Postthink`'s `=`. If it lands after, v_z ≈ 569 and airtime ≈ 1.5 s instead of 775 ms — every
   §2b timing would be wrong, and it also means **the shipped vault is roughly 3× as high as its own
   cooldown implies**. *Mitigation:* Stage 0 measures it before any curve ships; phase 5 is land-triggered,
   not clock-triggered, so the tail is correct either way. **This is worth reporting to the user as a
   possible defect in the vault itself, independent of the camera.**

3. **Insertion-point regression — the project's most repeated mistake.** A view offset has been placed
   wrongly four times here: bug-1942 (dead `PMF_CAMERA_VIEW` branch), bug-1238 (three placements, two of
   them silently clobbered by `origin[2] = cg.fCurrentViewHeight`), and `bug-lean-ads-wrong-branch` (the
   `bUseWorldPosition` branch is not the first-person path). All three failure sites are within ~100 lines
   of where this feature must go. *Mitigation:* §3 names the exact two lines and the three decoy
   `AnglesToAxis` calls; Stage 1 ships detection with no rendering so the hook is proven live before any
   maths depends on it.

**Runners-up:** envelope leak into 3P/spectator/respawn (the bug-1306 family — guard on `pm_flags`, not
`health <= 0`); eye-Z carrying the camera through a surface (bug-1250 — trace it, 8 lines, copied from the
DBNO drop).

---

## 10. New bug ids

`.wolf/buglog.json` holds **1332 entries**; highest numeric id **bug-1976**. Next free: **bug-1977**.
Nothing about `vault`, `mantle` or `climb over` has ever been logged — the single `vault` hit in the
buglog (bug-601) is a false positive about a data vault. The closest precedent for adding a movement verb
is the **ladder** family (bugs 1415, 1424, 1425, 1828, 1835, 1836, 1839, 1842), which took six rounds and
failed repeatedly at the `pm_flags` / statemap / server-authoritative-movement boundary — the exact
boundary this design deliberately does not cross.
