# Weapon Feel — R1 Reference

**Lens:** what makes first-person weapon handling read as *alive*.
**Written for:** the build spec that follows. This file sets the target and the numbers; it does not
write code.
**Date:** 2026-08-20. **Engine tree:** `openmohaa-hzm` (OpenMoHAA 2023+ rewrite), MOHAA:AA/SH/BT.

## How to read this file

Every claim about this codebase carries a `file:line`. Every claim carries one of:

| tag | means |
|---|---|
| **[P]** | **Proven** — read directly out of the source/asset in this tree, quoted or arithmetically re-derived here. |
| **[I]** | **Inferred** — a reasoned conclusion from proven facts. Falsifiable; the falsifying test is stated. |
| **[X]** | **External** — from a cited outside source, not this codebase. |

Numbers are re-derived in line, not asserted. Where a number came out of a binary asset, the parse is
reproducible (§3.4).

---

# §0 — The audit: what exists today, and the four things wrong with it

## 0.1 The reload camera, as shipped

`CG_ApplyReloadSway`, `openmohaa-hzm/code/cgame/cg_view.c:106-151`. Called once per frame from
`CG_CalcViewValues` at `cg_view.c:2643`, immediately before the final
`AnglesToAxis(cg.refdefViewAngles, cg.refdef.viewaxis)` at `cg_view.c:2645`. **[P]**

It writes two of the three final view angles:

```
cg_view.c:149   vAngles[0] -= s_reloadLift;          // pitch up with the lifted gun
cg_view.c:150   vAngles[2] += s_reloadLift * 0.3f;   // a touch of roll so it reads as body motion
```

Driver: `cg.snap->ps.iViewModelAnim` (`cg_view.c:127`), compared against the literals `6`, `7`, `8`.
Those literals are correct — `vmAnim_e` in `openmohaa-hzm/code/fgame/bg_public.h:160-175` ordinals as
`DISABLED 0, IDLE 1, CHARGE 2, FIRE 3, FIRE_SECONDARY 4, RECHAMBER 5, RELOAD 6, RELOAD_SINGLE 7,
RELOAD_END 8, PULLOUT 9, PUTAWAY 10, LADDERSTEP 11, IDLE_0 12, IDLE_1 13, IDLE_2 14`. **[P]**

Targets, with `coop_reloadSway` (default `1.6`, `CVAR_ARCHIVE`, `cg_view.c:113`) as peak `P`:

| state | target lift | at P = 1.6 |
|---|---|---|
| `RELOAD` (6) | `P * (0.62 + 0.38 * phase)`, `phase = (cg.time - start) / 900ms`, clamped **above only** | 0.99° → 1.60° pitch up |
| `RELOAD_SINGLE` (7) | `P * 0.70` | 1.12° pitch up, flat |
| `RELOAD_END` (8) | `P * -0.28` | 0.45° pitch **down** |
| anything else | `0` | 0 |

Roll is always `0.3 x` the pitch lift, so peak roll is `1.6 * 1.0 * 0.3 = 0.48°`. **[P]**

Smoothing, `cg_view.c:145-147`:

```
fDt   = cg.frametime * 0.001f;
fRate = (iAnim == 8) ? 11.0f : ((fTarget > s_reloadLift) ? 7.0f : 4.5f);
s_reloadLift += (fTarget - s_reloadLift) * fRate * fDt;
```

Time constants re-derived as `tau = 1/rate`: rise `tau = 143 ms` (95% settle at `3*tau = 429 ms`),
fall `tau = 222 ms` (667 ms), the `RELOAD_END` snap `tau = 91 ms` (273 ms). **[P]**

## 0.2 Defect 1 — the ramp is a fixed 900 ms; the reloads are not

The `900.0f` at `cg_view.c:133` is the same for every weapon in the game. The actual reload
animations are not. Parsed from the shipped `.skc` headers (`SKAN`, v13; layout from
`openmohaa-hzm/code/skeletor/skeletor_animation_file_format.h:36-48` — `frameTime` at byte 16,
`numFrames` at byte 44; duration = `numFrames * frameTime`): **[P]**

| weapon (world-model `.skc`) | frames | frameTime | duration |
|---|---:|---:|---:|
| M1 Garand `garand_reload.skc` | 60 | 0.0333 | **2.000 s** |
| SMLE `SMLE_reload_fill.skc` | 61 | 0.0330 | 2.013 s |
| Colt .45 / P38 `reload_colt45.skc`, `p38_reload.skc` | 73 | 0.0333 | 2.433 s |
| Thompson `ThompsonSMG_reload.skc` | 84 | 0.0320 | **2.688 s** |
| Webley `webley_reload.skc` | 86 | 0.0320 | 2.752 s |
| MP44 `mp44_reload.skc` | 83 | 0.0333 | 2.767 s |
| P14 `p14reload.skc` | 88 | 0.0320 | 2.816 s |
| MP40 `reload_mp40.skc` | 91 | 0.0320 | 2.912 s |
| Lewis `lewis_reload.skc` | 97 | 0.0320 | 3.104 s |
| BAR `reload_bar.skc` | 97 | 0.0333 | 3.233 s |
| G98 `g98reload.skc` | 99 | 0.0330 | **3.267 s** |
| SMLE `SMLE_reload_end.skc` (the cap) | 16 | 0.0330 | 0.528 s |

And from the mod's own **viewmodel** anims, which are the ones this layer actually rides
(`hzm-mohaa-coop-mod/models/human/animation/viewmodel/`): Johnson **2.002 s**, FG42 **2.343 s**,
M10 **2.409 s**, DP28 **3.201 s**. **[P]**

Spread: `3.267 / 2.000 = 1.63x` across the world set; `3.201 / 2.002 = 1.60x` across the four
viewmodel anims alone. **[P]**

**Consequence [I]:** the camera reaches full lift at wall-clock 900 ms on every weapon, then *sits at
the peak* for the remaining 1.1 s (Garand) to 2.3 s (DP28) before the anim ends. The motion is over
before the reload is a third done on a machine gun. This is the largest single reason the user's
complaint — *"no reload should feel the same"* — is literally true today: the camera's entire
performance is identical in shape **and in absolute timing**, and the only thing that varies between
guns is how long it holds still at the top afterwards.

*Falsifying test:* `coop_reloadSway 6`, reload a Garand then a BAR, watch when the lift stops
climbing. Same moment in both = confirmed.

## 0.3 Defect 2 — `RELOAD_SINGLE` is flat, and the per-shell restart is thrown away

`cg_view.c:128-131` detects a new reload only by `iAnim != s_iLastVMA` — a *value* change. A
single-loading weapon (Springfield, shotgun, SMLE) plays `VM_ANIM_RELOAD_SINGLE` **once per shell**,
re-triggering the same value `7` each time. The value never changes, the timer never restarts, and
`cg_view.c:139` holds a flat `P * 0.7` for the whole multi-shell sequence. **[P]**

The correct signal is already in the player state and already on the wire.
`playerState_t::iViewModelAnimChanged` (`openmohaa-hzm/code/qcommon/q_shared.h:1906`) is a 2-bit
wraparound counter bumped on every anim start *including a restart of the same anim*:

```
fgame/player.cpp:13150-13152
    if (viewModelAnim != playerState->iViewModelAnim || force_restart) {
        playerState->iViewModelAnimChanged = (playerState->iViewModelAnimChanged + 1) & 3;
    }
```

It is networked at `openmohaa-hzm/code/qcommon/msg.cpp:3358` and `:3420` as a 2-bit field, and the
cgame's own anim system already keys off it at `cg_viewmodelanim.c:500-504`. **[P]**

**Consequence [I]:** every shell of a shotgun reload is a dead flat camera today. Watching
`iViewModelAnimChanged` instead of the anim value gives a free per-shell pump — exactly the
"repeated action that must not repeat" the user is asking about — with **zero new networking**.

## 0.4 Defect 3 — it runs in third person, and in ADS, with no gate for either

`cg_view.c:2604` calls `CG_OffsetThirdPersonView()`, which places the chase camera by writing both
`cg.refdef.vieworg` and `cg.refdefViewAngles` (`cg_view.c:248-275`). `CG_ApplyReloadSway` then runs
**39 lines later** at `cg_view.c:2643` and rotates `cg.refdefViewAngles` again. **[P]**

There is no `cg.renderingThirdPerson` check and no `CG_AimingDownSights()` check anywhere in
`cg_view.c:106-151`. **[P]**

**Consequence [I]:** in third person a reload pitches the *chase camera about its own already-offset
position*, so the whole world swings while the character on screen does something unrelated — a
first-person eye motion applied to a camera that is not an eye. In ADS the sight picture pitches
1.6° up off the crosshair. Every neighbouring feature in this same file is gated: lean-roll is damped
by `cg_adsLeanRoll` under `CG_AimingDownSights()` (`cg_view.c:2407-2416`), sprint gun-lower checks
`!cg.renderingThirdPerson` (`cg_view.c:1359`), weapon-collision retract checks
`!cg.renderingThirdPerson` (`cg_view.c:1420`), the head-bob shaper damps under sights
(`cg_view.c:988-990`). The reload layer is the outlier.

## 0.5 Defect 4 — two unbounded arithmetic paths

**(a) The smoothing is not framerate-independent and is not clamped.** `cg_view.c:147` applies
`(target - s) * rate * dt` with no `if (k > 1) k = 1`. Every comparable block in this file clamps:
the weapon-lag spring clamps `k` (`cg_view.c:1292`), the free-aim camera weight clamps `k`
(`cg_view.c:2394`), the sprint envelope guards
`dt <= 0.0f || dt >= 0.5f` (`cg_view.c:1382`), the breath timer clamps `dt < 0 || dt > 500`
(`cg_view.c:1141`). **[P]**
Re-derived stability bound: `s += (T - s) * k` overshoots for `k > 1`, diverges for `k > 2`. With
`rate = 11.0` that is `dt > 90.9 ms` (**11.0 fps**) and `dt > 181.8 ms` (**5.5 fps**). A single
500 ms hitch — map load, alt-tab, shader compile — gives `k = 5.5` and slams the view. **[I,
arithmetic]**

**(b) `fPhase` is clamped above but not below.** `cg_view.c:134-136` clamps `fPhase > 1.0f` only.
`s_iVMAStart` is a `cg.time` stamp in a function-local `static` that survives a map change, while
`cg.time` restarts. A negative `cg.time - s_iVMAStart` makes `fPhase` strongly negative and
`fTarget = P * (0.62 + 0.38 * fPhase)` swings hard negative — a downward camera slam on the first
reload after a transition. **[I, arithmetic]** *Falsifying test:* start a reload, transition maps
mid-reload, reload again on arrival.

## 0.6 The neighbours this must not fight

Everything below already writes the first-person presentation. A new layer has to declare its
relationship to each. All **[P]**.

| system | writes | where | ADS behaviour today |
|---|---|---|---|
| view-weapon **ADS sway** (figure-8) | `pREnt->origin`, units | `cg_view.c:1208-1214`, `cg_adsSway` 0.4 | *only* in ADS; killed by breath-hold |
| **scope sway** | `cg.refdefViewAngles`, degrees | `cg_view.c:1218-1229`, `cg_scopeSway` 0.25 | scoped rifles only |
| view-weapon **recoil** | `pREnt->origin` | `cg_view.c:1231-1252`, `cg_adsRecoil` 0.5, decay rate 9.0 | ADS only; x0.5 on breath-hold |
| **weapon weight / lag** | `pREnt->origin` | `cg_view.c:1254-1312`, `cg_weaponLag` 0.7 / `Max` 3.5 / `Stiffness` 7 | scaled by `cg_weaponLagADS` **0.35**; off while scoped |
| **free-aim** gun shift | `pREnt->origin` | `cg_view.c:1316-1323`, `cg_freeAimGun` 0.18 | — |
| **sprint** gun-lower | `pREnt->origin` | `cg_view.c:1325-1397` | suppressed while aiming |
| **weapon collision** retract | `pREnt->origin` | `cg_view.c:1401-1450` | `!cg.renderingThirdPerson` |
| **head-bob** | view origin + angles | `cg_view.c:944-1055` (shaper `:976-992`), `cg_headbobScale` 1.35 | damped x0.25 under sights |
| **injury sway** | `cg.refdefViewAngles` | `cg_view.c:2419-2461`, `coop_injurySway` 1.0 | ungated |
| **shell-shock dizziness** | `cg.refdefViewAngles` | `cg_view.c:153-188`, `coop_dizzy` / `coop_dizzyTime` | ungated, by design |
| **engine view kick** | `cg.refdefViewAngles` | `cg_view.c:2466-2500` (`cg.viewkick[2]`) | ungated |
| **lean roll** | `cg.refdefViewAngles[2]` | `cg_view.c:2407-2416` | damped by `cg_adsLeanRoll` |
| **DBNO / freecam / staged-ADS** | camera placement | `cg_view.c:2550-2552` | own state machines |

**The dividing line that matters [P]:** `pREnt->origin` inside `CG_OffsetFirstPersonView` moves the
**hands and gun only** — it is the view-weapon `refEntity_t`, passed in from `cg_modelanim.c:1910`
and `:2039`, and the file says so at `cg_view.c:1094-1096`. `cg.refdefViewAngles` moves the
**camera**. That distinction is the whole architecture of this feature, and getting it backwards is
exactly how the previous attempt died (§4.3).

---

# §1 — The vocabulary, separated

Seven things get called "weapon feel" and they are not the same thing. What each *is*, what it
*communicates*, and whether it belongs on a reload.

## 1.1 View kick

**Is:** a discrete angular impulse applied to the camera on a discrete event (a shot, a hit), decaying
back toward the pre-kick angle. Rotation only, camera only, short.
**Communicates:** *"that just happened to me."* Force delivered at an instant. It is the single
strongest confirmation that a trigger pull produced an event.
**In this codebase:** two independent implementations. Server-authoritative, on the player's real
aim: `fgame/weapon.cpp:2284-2293` adds a random draw in `[viewkickmin, viewkickmax]` to
`owner->GetViewAngles()` per shot. Client-only, cosmetic: `cg.viewkick[2]` applied at
`cg_view.c:2466-2469` and decayed at `:2471-2500` with `viewkickRecenter` / `MinDecay` / `MaxDecay`.
**[P]**
**On a reload:** **No.** A reload has no impulse event. Using kick on a reload is the classic
mistake — it reads as being hit, not as handling a weapon.

## 1.2 Recoil pattern

**Is:** the *accumulated, remembered* aim displacement across a burst — the climb-and-drift a player
learns and compensates for. State that persists between shots.
**Communicates:** *"this weapon is controllable in this way."* It is a skill surface, not a feel
surface.
**In this codebase:** `m_fFireSpreadMult` accumulation at `fgame/weapon.cpp:2295-2310` is the spread
half; there is no per-weapon climb *pattern* (the kick draw at `:2285` is memoryless).
**On a reload:** **No** — and note the important negative: a reload is where a recoil pattern
*resets*, so the reload layer must never leave residue in an aim-affecting accumulator.

## 1.3 Weapon sway

**Is:** continuous, low-frequency, low-amplitude wander with no discrete trigger. Human idle noise.
Typically sub-1 Hz.
**Communicates:** *"a person is holding this, and people are never still."* Its absence is what makes
a gun feel welded to a tripod.
**In this codebase:** `cg_adsSway` figure-8 on the view weapon (`cg_view.c:1208-1214`, two detuned
sines at 1.1 and 1.7 rad/s = **0.175 Hz and 0.271 Hz**); `cg_scopeSway` on the camera for scoped
rifles (`cg_view.c:1218-1229`, 0.25° at the same frequencies); `coop_injurySway` (`cg_view.c:2460-2461`,
0.95 / 1.7 / 0.70 rad/s = **0.151 / 0.271 / 0.111 Hz**, up to 2.2° roll and 1.3° pitch at death's
door). **[P, frequencies re-derived as `rad_s / (2*pi)`]**
**On a reload:** **Yes, but inverted.** The interesting statement is that sway should *change* during
a reload — both hands are busy, the gun is no longer being aimed, so the idle sway should get
*larger and slower*, then snap back to tight when the weapon comes back on target. That transition is
free characterisation.

## 1.4 Positional lag / drag

**Is:** the view weapon trailing the camera when the camera turns, then springing back to rest. A
first-order (or second-order) filter on the look delta, expressed as *position*, not rotation.
**Communicates:** **mass.** This is the single highest-bandwidth weight channel in first person, and
it costs nothing per frame.
**In this codebase:** fully built, `cg_view.c:1254-1312`. `cg_weaponLag` 0.7 units of trail per
degree of turn, clamped at `cg_weaponLagMax` 3.5 units, spring rate `cg_weaponLagStiffness` 7 (so
`tau = 143 ms`), scaled to 0.35 in ADS, disabled while scoped. Per-class weight multipliers at
`cg_view.c:1274-1278`: **pistol 0.55, SMG 0.8, rifle 1.1, MG 1.5, heavy 1.35.** **[P]**
**On a reload:** **Yes, and this is the most under-used channel available.** During a reload the gun
is being moved by the hands, not by the camera — so the lag spring should be *softened* (lower
stiffness, higher max) for the duration, which makes the gun feel like it is being hefted rather than
carried. No new system, one multiplier on an existing one.

## 1.5 Procedural additive animation

**Is:** a code-generated offset (position and/or rotation) layered *on top of* an authored animation,
driven by game state rather than by a timeline. Additive layers add on top of the base pose; override
layers replace it. **[X]** — this is the standard separation in shipping animation stacks
([CryEngine procedural weapon animation](https://docs.cryengine.com/display/SDKDOC2/Procedural+Weapon+Animations),
[Dev_Unallocated layer breakdown](https://www.devunallocated.com/projects/project-killhouse/procedural-weapon-animations-condensed)).
**Communicates:** *"this action is happening in these particular circumstances,"* which is precisely
the thing an authored clip cannot say.
**In this codebase:** every `VectorMA(pREnt->origin, ...)` in `CG_OffsetFirstPersonView` is an
additive positional layer. There is currently **no additive rotational layer on the view weapon** —
`pREnt->axis` is never modified there. **[P]** That is a gap: rotation is where reload character
lives (a tilt to see the magazine well, a roll to work a bolt), and it is entirely unused.
**On a reload:** **Yes — this is the primary vehicle.** Everything else in this list is a supporting
channel.

## 1.6 Camera shake

**Is:** high-frequency, short-lived, multi-axis noise on the camera. Usually driven by a scalar
"trauma" that decays.
**Communicates:** *"the world just did something violent."* It is an environmental voice, not a
character voice.
**In this codebase:** the shell-shock layer, `cg_view.c:153-188`. Decaying sinusoids at
5.3 / 3.9 / 2.9 rad/s (**0.844 / 0.621 / 0.462 Hz**) with peaks of **5.5° roll, 2.8° pitch, 1.6° yaw**
at severity 1, over `coop_dizzyTime * severity` seconds (default 4.2), with a squared decay envelope
(`fDecay *= fDecay`, `cg_view.c:183`). **[P]**
**On a reload:** **No.** A reload is deliberate. Shake says involuntary. Mixing them is how a reload
starts reading as "I got shot mid-reload," which is a lie unless the player actually did.

## 1.7 Breathing

**Is:** a specific low-frequency sway locked to a respiratory cycle, with a hold-and-release state
machine.
**Communicates:** *"there is a body attached to this gun, and it has a physiological state."*
**In this codebase:** the breath-hold system, `cg_view.c:1123-1205`. `cg_breathHoldTime` 7 s,
`cg_breathCooldown` 5 s, edge SFX (`breath_in.wav` / `breath_out.wav`), a music/ambient duck to
`cg_breathDuck` 0.7. As of bug-1881 it is also *mechanically* real — `coop_breathAccuracy` 0.10
multiplies spread server-side. **[P]**
**On a reload:** **Yes, as a context input, not as a motion.** Whether the player is winded is one of
the best free variation sources this project has (§2.3).

## 1.8 The reload summary

| layer | on a reload? | why |
|---|---|---|
| view kick | **no** | no impulse event; reads as taking damage |
| recoil pattern | **no** (must not leave residue) | reload is where patterns reset |
| weapon sway | **yes, modulated** | should grow + slow while the gun is off-aim |
| positional lag / drag | **yes, softened** | cheapest weight channel; unused here |
| procedural additive | **yes — primary** | the only layer that can vary by context |
| camera shake | **no** | environmental voice, not character voice |
| breathing | **yes, as input** | drives amplitude; never draws its own motion |

---

# §2 — How shipping games make a repeated action feel non-repeating

Ranked by how "alive" the result reads per unit of effort, worst failure mode noted for each.

## 2.1 Per-instance randomised parameters (the baseline; not the answer on its own)

Draw the layer's parameters *once, at the start of the action*, and hold them constant for its
duration: peak amplitude x[0.85, 1.15], phase offset, a small yaw sign, timing jitter of a few tens of
milliseconds on the sub-beats.

**Why it works:** two reloads differ, but each individual reload is internally coherent — it still
looks like one intentional movement.
**Why the naive version fails:** randomising *per frame* instead of *per instance* produces jitter,
not variety. Jitter reads as a broken renderer or a drunk character. This is the single most common
way this class of feature makes a game worse (§7).
**Precedent in this engine [P]:** `fgame/weapon.cpp:2285` does exactly this for view kick —
`random() * (max - min) + min`, drawn once per shot, held for that shot.
**Available with no new API [P]:** `random()` and `crandom()` are macros in
`openmohaa-hzm/code/qcommon/q_shared.h:826-828`.

## 2.2 Smoothed noise instead of white noise (the technique that separates "alive" from "drunk")

Where a layer needs *continuous* variation rather than per-instance variation, drive it with
band-limited noise — Perlin/simplex or a sum of detuned sines — never with `random()` per frame.

This is the load-bearing point of Squirrel Eiserloh's GDC 2016 *Juicing Your Cameras With Math*:
smoothed fractal noise is *"WAY better than random for screen shake"* — it feels better, it survives
pause and slow-motion correctly, its frequency is adjustable, and it is reproducible on replay.
**[X]**

The same talk gives the escalation model worth stealing wholesale: maintain a scalar `trauma` in
`[0, 1]`, add to it on events, decay it linearly, and drive the shake by `trauma^2` or `trauma^3`.
Re-deriving the cubed curve: `0.30^3 = 0.027`, `0.60^3 = 0.216`, `0.90^3 = 0.729` — **2.7%, 21.6%,
72.9%**. **[X, arithmetic re-derived]** The point of the exponent is that low-intensity events stay
almost invisible while high-intensity events dominate, so the layer does not turn into constant
background wobble.

**Relevant here [I]:** the existing sway layers are already sums of detuned sines
(`cg_view.c:1210-1213`, `:2452-2461`), which is a poor man's band-limited noise and is *correct
practice* — they just use the same two frequencies every time. Giving each *instance* a different
phase seed makes them non-repeating for free.

## 2.3 Variation driven by CONTEXT rather than by randomness — the highest-value technique

This is what the user is actually asking for. *"A last-round reload under fire should differ from a
calm top-up"* is a statement about context, not about noise. Context-driven variation reads as
**intention**; random variation reads at best as texture and at worst as malfunction.

Every one of the following signals is **already available client-side, already networked, and needs
no protocol change**:

| context | signal | where | reload should |
|---|---|---|---|
| **empty vs partial reload** | `ps.stats[STAT_CLIPAMMO]` sampled at reload start; 0 = dry | `fgame/bg_public.h:542` | dry: bigger, more urgent, plus a distinct chamber/bolt beat. Partial: smaller, tidier |
| **the chamber beat exists at all** | `VM_ANIM_RELOAD_END` (8) is dispatched | `cg_viewmodelanim.c:526-528` | only guns that cycle get the down-snap |
| **stance** | `ps.pm_flags & PMF_DUCKED`; `ps.viewheight` | `bg_public.h:256`; used at `cg_view.c:1986` | crouched: braced, ~60% amplitude. Prone: less again |
| **movement** | `ps.velocity` magnitude, already read at `cg_view.c:832-840` | `cg_view.c:832` | moving: more lateral, less vertical (arms stabilise against the stride) |
| **sprinting** | client mirror already computed | `cg_view.c:1336-1372` | reload-while-jogging is a different animation of the body |
| **stamina / winded** | `s_spStam` mirror; breath-hold state `s_breathSteady` | `cg_view.c:1336`, `cg_view.c:517-519` | low stamina: larger, slower, less precise |
| **health** | `ps.stats[STAT_HEALTH]` vs the self-calibrating peak already tracked | `cg_view.c:2424-2437` | hurt: the existing injury ramp already computes a 0..1 "hurt" scalar — reuse it, do not recompute |
| **being shot at** | `CG_AddSuppression()` already exists and is already driven | `cg_view.c:546-561` | suppressed: faster, snatchier, overshoot on the seat |
| **in ADS at reload start** | `CG_AimingDownSights()` | `cg_view.c:1540-1556` | keep the gun near the eye-line: a "tactical" reload |
| **weapon class** | `ps.stats[STAT_EQUIPPED_WEAPON]` bitmask | `bg_public.h:371-378` | see §3 |
| **real reload length** | `cgi.Anim_Time()` on the live anim | `cg_public.h:387` | see §2.4 |

**[P] for every row.** `STAT_CLIPAMMO` is already sampled every frame at `cg_view.c:1105` for the
recoil detector, so the shot/reload-start bookkeeping already exists in this file.

The combinatorial payoff is the point: with just *empty/partial* x *stance 3* x *suppressed y/n* x
*hurt y/n* you have 24 distinguishable reload performances before a single random number is drawn.
Layer per-instance randomness (§2.1) on top of *that* and the player will never see the same reload
twice — while every individual reload still means something.

## 2.4 Retime to the real animation instead of to a constant

The strongest anti-repetition move available here is not a new layer, it is deleting the `900.0f`.

The client can read the true, per-weapon, per-anim duration with no new networking and no new API:

- `cgi.anim->g_iCurrentVMDuration` — ms elapsed in the current viewmodel anim. Reset to 0 on anim
  change at `cg_viewmodelanim.c:590`, advanced by `cg.frametime` at `cg_viewmodelanim.c:620`. The
  struct is `clientAnim_t` (`qcommon/q_shared.h:2280-2295`), reachable as `cgi.anim`
  (`cgame/cg_public.h:442`). **[P]**
- `cgi.Anim_Time(dtiki_t*, animnum)` — total length of an anim, `cg_public.h:387`; the index is
  `cgi.anim->g_VMFrameInfo[cgi.anim->g_iCurrentVMAnimSlot].index`, and `cgi.Anim_NumForName` is at
  `cg_public.h:384`. **[P]**

That yields a normalised phase `0..1` through the *actual* animation the player is watching. Every
sub-beat then lands on the gun instead of near it, and a Garand (2.000 s) and a DP28 (3.201 s)
diverge automatically without a per-gun table.

**Caveat [I]:** `CG_ViewModelAnim` runs in the viewmodel draw path, which does not run in third
person — so `g_iCurrentVMDuration` freezes in 3P. Since the layer must be gated off in 3P anyway
(§0.4), this is a consistency check, not a problem. It is also one frame stale relative to
`CG_CalcViewValues`, which at 60 fps is 16 ms and below perception.

## 2.5 Multiple authored variants selected by context

The cheapest possible variety: two or three authored reload clips, chosen by context. The
empty-vs-tactical distinction is the industry-standard case — an empty reload requires working the
bolt or bolt-catch to chamber a round, a tactical reload does not, and games that ignore this get
called out for *"tapping the bolt catch after every reload even if you just dropped a half-full
mag."* **[X]** ([tactical reload](https://en.wikipedia.org/wiki/Tactical_reload);
[Fallout 4 Tactical Reload framework](https://www.nexusmods.com/fallout4/mods/49444))

**This engine already has the state machine for it [P]:** `RELOAD` / `RELOAD_SINGLE` / `RELOAD_END`
are separate networked states (`bg_public.h:166-168`), the anim suffixes are dispatched by name at
`cg_viewmodelanim.c:520-528`, and the data convention for empty-state alternates already exists —
`Weapon::SetWeaponIdleAnim` prefers `idle_empty` over `idle` when the clip is dry
(`fgame/weapon.cpp:3468-3486`), and `fire_empty` is used the same way at `fgame/weapon.cpp:2912`.

**But [I]:** authoring 69 new reload clips is not on this project's budget, and the procedural layer
gets ~80% of the perceived variety at ~2% of the cost. **Recommend: do not author variants.** Note
the hook exists (a `<prefix>_reload_empty` lookup would slot straight into `cg_viewmodelanim.c:520`)
and leave it for a future asset pass.

## 2.6 Asymmetric per-hand / off-axis motion

Real reload motion is not planar. The support hand goes to the magazine well and comes back; the
weapon rolls toward the player's dominant eye so the well is visible; the whole thing is
right-biased for a right-handed shooter.

**In this codebase [P]:** the view weapon is a single `refEntity_t` — hands and gun are one model,
and `cg_modelanim.c:2015-2026` can only hide surfaces (`viewhand`, `viewsleeves`), not articulate
them. So per-hand motion is **not available**.
**What is available [I]:** off-axis *whole-weapon* motion. The current layer moves pitch and roll in
fixed proportion (`roll = 0.3 * pitch`, `cg_view.c:150`), which is a straight line in angle space and
reads as mechanical. Decoupling pitch, roll, and yaw — with different time constants and different
per-instance phases — is the same trick at a fraction of the cost and is the largest single
readability win available in the existing function.

## 2.7 What reads as ALIVE vs what reads as DRUNK

| reads **alive** | reads **drunk / broken** |
|---|---|
| parameters drawn once per action, held constant within it | parameters redrawn per frame |
| band-limited (smoothed / summed-sine) noise | white noise on the camera |
| variation whose *cause* the player can name | variation with no discernible cause |
| amplitude varying, *timing* mostly stable | timing varying more than ~15% |
| motion that starts and ends at a known rest pose | motion that leaves residual offset |
| the **weapon** moving relative to the camera | the **camera** moving with no reason |
| decoupled axes with different time constants | one scalar driving all axes proportionally |
| bounded, with a hard clamp | unbounded accumulators |

The asymmetry in row 4 is the important one. Players tolerate — and enjoy — large amplitude
variation. They do **not** tolerate timing variation, because timing variation reads as input lag.
Animations that are not tightly synchronised with input *"feel delayed, sluggish, or disconnected"*
**[X]** ([QDStaff, unresponsive game animations](https://qdstaff.com/breaking-the-lag-fixing-unresponsive-game-animations/)).
**Vary how big, not when.**

---

# §3 — Weight

## 3.1 What actually makes a Garand feel heavier than a Thompson

Ranked by perceived weight delivered per unit of implementation effort in *this* codebase.

| # | channel | why it carries weight | status here |
|---|---|---|---|
| 1 | **positional lag on turn** | mass = resistance to being accelerated. The eye reads the gap between where the camera points and where the gun points as inertia, directly. | **built**, `cg_view.c:1254-1312`, per-class weights `cg_view.c:1274-1278` |
| 2 | **settle time after motion stops** | a heavy object overshoots and takes longer to stop ringing. This is the *second-order* half of channel 1 and is the difference between "laggy" and "heavy". | **missing** — the spring is first-order (`s += (T-s)*k`), so it cannot overshoot |
| 3 | **reload duration + sub-beat spacing** | a Garand en-bloc clip goes in as one committed shove; a Thompson stick mag is a two-hand fiddle. The *rhythm* is the tell. | **available** (§2.4), **unused** |
| 4 | **muzzle rise magnitude** | already per-weapon in the data | **built**, `fgame/weapon.cpp:2284-2293` (see §4.2) |
| 5 | **recovery time after kick** | a light gun snaps back; a heavy one is still coming down when you fire again | **built but global**: `s_recoil` decays at a fixed rate 9.0 for every weapon, `cg_view.c:1250` |
| 6 | **audio timing** | the metallic events (mag out, mag in, bolt) are the beat the camera should be dancing to | authored per weapon in TIK `entry sound` blocks, e.g. `m1_snd_reload` at `models/weapons/m1_garand.tik:185` |
| 7 | **ADS raise time** | heavy guns come up slower | **built**, per-gun ADS tune tables (`cg_local.h:517-545`) |

**The cheap wins are 2 and 3.** Channel 2 is a one-line change to the spring form. Channel 3 is
already fully specified by data the client can read (§2.4).

## 3.2 The per-weapon-class parameter set

Fill one row per class. Values below are *starting points*, anchored to the multipliers already in
the tree so nothing lurches on the first build.

| parameter | pistol | SMG | rifle | MG | heavy | units | anchor |
|---|---:|---:|---:|---:|---:|---|---|
| `lagWeight` | 0.55 | 0.80 | 1.10 | 1.50 | 1.35 | x | **shipping values**, `cg_view.c:1274-1278` **[P]** |
| `kickWeight` | 0.60 | 0.85 | 1.35 | 1.50 | 1.30 | x | **shipping values**, `cg_view.c:1116-1121` **[P]** |
| `settleDamping` | 1.00 | 0.90 | 0.75 | 0.60 | 0.65 | ratio zeta | proposed; <1 = overshoot |
| `settleFreq` | 9.0 | 8.0 | 6.5 | 5.0 | 5.5 | rad/s | proposed; `tau ~ 1/(zeta*w)` |
| `reloadLiftPeak` | 0.55 | 0.80 | 1.10 | 1.45 | 1.30 | x global | mirror `lagWeight` — one weight concept, not two |
| `reloadRollBias` | 0.45 | 0.35 | 0.25 | 0.18 | 0.20 | fraction of pitch | small guns roll more, long guns pitch more |
| `reloadSagRate` | 1.00 | 0.85 | 0.70 | 0.50 | 0.55 | x | how fast the gun returns to rest |
| `recoilDecay` | 11.0 | 10.0 | 9.0 | 7.0 | 7.5 | 1/s | generalises the fixed 9.0 at `cg_view.c:1250` **[P]** |

Class bits are `WEAPON_CLASS_PISTOL/RIFLE/SMG/MG/GRENADE/HEAVY/CANNON` = bits 0-6,
`fgame/bg_public.h:371-378`, read from `ps.stats[STAT_EQUIPPED_WEAPON]` exactly as
`cg_view.c:1274-1278` already does. **[P]**

**Do not add a per-gun table.** Class + `cgi.Anim_Time` covers the spread. The project already has
one per-gun table (the ADS tune tables) and it required a dedicated in-game tuning workbench
(`cg_adsTune`, `cg_local.h:529`) plus a per-gun tuning session to fill. A second one is not worth it
until class-level tuning demonstrably fails.

## 3.3 The second-order spring (channel 2)

Current form everywhere in this file (`cg_view.c:147`, `:1301-1302`, `:1379-1380`):

```
s += (target - s) * rate * dt;          // first-order: monotone, never overshoots
```

A heavy object overshoots. The minimal upgrade keeps one extra float:

```
v += (-2*zeta*w*v - w*w*(s - target)) * dt;   // damped harmonic oscillator
s += v * dt;
```

`zeta = 1.0` is exactly critical (behaves like today), `zeta < 1` overshoots and rings, `zeta > 1` is
sluggish. Setting `zeta = 1.0` in every class reproduces today's behaviour, which is what makes this
safe to ship. **[I]** Stability requires `w*dt < ~0.5`; with `w = 9.0` that is `dt < 55 ms`
(18 fps) — so it needs the same `dt` clamp §0.5(a) is asking for anyway.

## 3.4 Reproducing the duration table

```python
import struct
def skc_duration(path):
    d = open(path,'rb').read(64)
    assert d[:4] == b'SKAN'
    frameTime, = struct.unpack_from('<f', d, 16)   # skelAnimDataFileHeader_t.frameTime
    numFrames, = struct.unpack_from('<i', d, 44)   # ...numFrames
    return numFrames * frameTime
```

Offsets derived by walking `skelAnimDataFileHeader_t`,
`openmohaa-hzm/code/skeletor/skeletor_animation_file_format.h:36-48`:
`ident 0, version 4, flags 8, nBytesUsed 12, frameTime 16, totalDelta 20..32, totalAngleDelta 32,
numChannels 36, ofsChannelNames 40, numFrames 44`. **[P]**

---

# §4 — Period correctness: how far is too far for Medal of Honor

## 4.1 The constraint, stated honestly

MOHAA's 2002 weapon handling is part of what the audience is here for. A modern procedural stack —
full spring-driven multi-axis rig, per-footstep camera impulses, sprint-dependent locomotion sway,
velocity-driven directional lean — would be *better feel* and *worse Medal of Honor*. The failure
mode is specific and recognisable: the game starts reading as an Insurgency/Escape-from-Tarkov-alike
wearing WW2 textures.

## 4.2 The 2002 game already randomised its recoil, and this is decisive

This is the argument that settles the question. Retail MOHAA's own weapon data draws view kick from a
**min/max band, per shot**:

```
fgame/weapon.cpp:2284-2286
    if (viewkickmin[mode][0] != 0.0f || viewkickmax[mode][0] != 0.0f) {
        vAngles[0] += random() * (viewkickmax[mode][0] - viewkickmin[mode][0]) + viewkickmin[mode][0];
    }
```

Signature `viewkick pitchmin pitchmax yawmin yawmax`, `fgame/weapon.cpp:763-771`; setter at
`:4669-4699`. **[P]** The shipped values (negative pitch = muzzle up), read out of
`hzm-mohaa-coop-mod/models/weapons/*.tik`: **[P]**

| weapon | pitch min/max | yaw min/max | randomised? |
|---|---|---|---|
| M1 Garand | -2.50 / -2.50 | -0.10 / -0.10 | no |
| Thompson | -1.58 / -1.58 | -0.16 / -0.16 | no |
| Sten | -0.90 / -0.90 | 1.20 / 1.20 | no |
| Shotgun | -20.0 / -20.0 | 0.05 / 0.05 | no |
| MP40 | -1.65 / -1.65 | -0.12 / 0.12 | **yaw** |
| Colt .45 | -1.20 / -1.20 | -0.20 / 0.20 | **yaw** |
| P38 | -1.00 / -1.00 | -0.16 / 0.16 | **yaw** |
| MP44 | -1.80 / -1.80 | -0.20 / 0.05 | **yaw** |
| BAR | -1.96 / -1.96 | -1.20 / 1.20 | **yaw** |
| Kar98 | -3.50 / -4.00 | -1.00 / -1.05 | **both** |
| Springfield | -4.50 / -5.00 | -1.00 / 1.00 | **both** |
| Enfield | -1.50 / -2.00 | -0.50 / -0.50 | **pitch** |

Eight of twelve sampled weapons randomise pitch, yaw, or both. **[P]**

**Therefore [I]:** per-instance randomised parameters (§2.1) are not a modern graft onto MOHAA. They
are MOHAA's own idiom, extended from "the shot" to "the reload." That is the licence, and it is also
the limit — the technique is in-period; a spring rig with ten coupled layers is not.

## 4.3 Two more findings from the same block, worth acting on separately

**(a) A likely stock index bug kills horizontal kick on most weapons. [I — high confidence, one-line
verification]** `fgame/weapon.cpp:2288` gates the *yaw* kick on firemode-**1**'s *pitch*:

```
if (viewkickmin[1][0] != 0.0f || viewkickmax[1][0] != 0.0f) {          // <-- [1][0], not [mode][1]
    vAngles[1] += random() * (viewkickmax[mode][1] - viewkickmin[mode][1]) + viewkickmin[mode][1];
}
```

All firemode slots are zeroed at init (`fgame/weapon.cpp:1116-1119`), and a weapon that declares
`viewkick` only in its primary firemode leaves `[1][0] == 0` — so the gate is false and the
horizontal kick never fires. If so, every yaw value in the table above is dead data.
*Verification:* log `viewkickmin[1][0]` per weapon on spawn, or temporarily change the gate to
`[mode][1]` and fire a BAR (`+/-1.20°` yaw should become obvious). **Out of scope for this feature —
flag it, do not fold it into the reload work.**

**(b) The TIK data declares a richer recoil model than the engine reads. [P]** The shipped lines
carry nine tokens with a commented legend
(`hzm-mohaa-coop-mod/models/weapons/m1_garand.tik:226-234`):
`entry viewkick -2.5 -2.5 -0.1 -0.1 0.15 "T" 8.0 8.2 3.6` — scatter pattern, absolute pitch/yaw
clamps, and *"the pitch at which you lose all control of the weapon and its behavior is purely
random."* `Weapon::SetViewKick` reads arguments 1-4 and nothing else (`fgame/weapon.cpp:4669-4699`;
event format string `"ffFF"` at `:766`). Those last five tokens are inert in this build. Whether the
2002 binary read them is unknown and unprovable from here — but the authored intent is on record,
and it is the same intent this feature is chasing.

## 4.4 The calibration rule

The user has asked for both dramatic gore *and* rejected things with *"that doesn't look natural."*
That combination is not inconsistent — it says **magnitude is fine, incoherence is not.** A big
motion with a legible cause is welcome; a small motion with no cause is not.

Concretely:

- **Do:** make the reload camera bigger and more varied than it is now. Ship at the current 1.6°
  default and let the tuning session push it.
- **Do:** make every variation traceable to a cause the player can name — dry mag, crouched,
  suppressed, hurt, winded.
- **Do not:** add layers that are always on and always moving. MOHAA's stillness between events is a
  real part of its texture.
- **Do not:** add motion to actions that had none in 2002 — walking, standing, switching weapons.
  Reload was already an animated, camera-adjacent event; it is the legitimate place to spend.
- **Test:** if a change cannot be justified in one sentence beginning *"because the character is..."*,
  it is texture, not feel, and it should be cut.

---

# §5 — The numbers table

Magnitudes, durations, frequencies, and what "too much" looks like for each. All camera-space values
in degrees; all view-weapon values in world units along the view basis
(`mat[0]` forward, `mat[1]` left, `mat[2]` up, per `cg_view.c:1096`).

## 5.1 Reload layer (the new work)

| # | sub-layer | target | plausible range | too much looks like |
|---|---|---:|---|---|
| R1 | camera pitch peak, `RELOAD` | **1.6°** (today's default) | 1.0 - 2.6° | >3° — the horizon leaves the screen; a reload starts reading as flinching |
| R2 | camera roll peak | **0.5°** | 0.3 - 0.9° | >1.2° — reads as a stumble, not a hand motion |
| R3 | camera yaw peak (**new**, decoupled) | **0.35°** | 0.2 - 0.6° | >0.8° — the aim looks like it is being taken off you |
| R4 | per-instance amplitude jitter | **x[0.85, 1.15]** | x[0.9, 1.1] - x[0.75, 1.25] | >x[0.7, 1.3] — some reloads look broken |
| R5 | per-instance timing jitter | **+/-6%** of anim length | 0 - 10% | >15% — reads as input lag (§2.7) |
| R6 | sub-beat count (mag-out, mag-in, chamber) | **2-3**, placed at anim phase | 2 - 4 | >4 — the camera is dancing, not reacting |
| R7 | rise time constant | **tau 130 ms** (rate 7.7) | 90 - 200 ms | <70 ms — snap, reads as a hit |
| R8 | fall time constant | **tau 220 ms** (rate 4.5, today) | 180 - 350 ms | >450 ms — the view feels like it is floating home |
| R9 | chamber down-snap | **-0.28 x peak**, tau 90 ms | -0.2 to -0.4 x, 70-120 ms | more than -0.5 x — overshoot reads as a bug |
| R10 | view-weapon lag softening during reload | `stiffness x0.7`, `max x1.4` | x0.5 - x1.0, x1.0 - x1.8 | stiffness <x0.4 — the gun detaches from the hands |
| R11 | idle sway during reload | **x1.6 amplitude, x0.7 frequency** | x1.2-x2.2, x0.6-x1.0 | >x2.5 — the gun wanders like a cutscene prop |
| R12 | ADS scale | **x0.30** | 0.15 - 0.45 | >0.5 — see §6.2 |
| R13 | 3rd-person scale | **x0.0 (off)** | 0 only | any nonzero — see §0.4 |

## 5.2 Context multipliers (applied to R1-R3, held constant per instance)

| context | multiplier | notes |
|---|---:|---|
| dry / empty reload | **x1.25** | the strongest single differentiator; free from `STAT_CLIPAMMO` |
| partial top-up | **x0.85** | |
| crouched | **x0.70** | braced |
| prone (if reachable) | **x0.55** | |
| moving > 100 u/s | **x1.15**, redistributed toward roll/yaw | arms stabilise vertical against the stride |
| sprinting at reload start | **x1.30** | |
| suppressed (`CG_AddSuppression` active) | **x1.20**, rise tau **x0.75** | faster and snatchier, not just bigger |
| hurt (reuse the `injury` 0..1 ramp at `cg_view.c:2454-2458`) | **x(1 + 0.35 * injury)** | caps at x1.35 |
| stamina exhausted | **x1.25**, rise tau **x1.3** | bigger *and* slower — the fatigue signature |
| breath-hold active | **x0.6** | consistent with the rest of the breath system |

Products are **clamped to x1.8 total** so no combination of contexts can stack past ~2.9° of pitch at
the default peak. `1.6 * 1.8 = 2.88°`. **[I, arithmetic]** Unbounded stacking is how this class of
feature turns into motion sickness.

## 5.3 Reference values from the systems already in this tree (calibration anchors, all [P])

| existing effect | magnitude | frequency | file:line |
|---|---:|---:|---|
| ADS breathing sway (view weapon) | 0.40 u L/R, 0.28 u U/D | 0.175 Hz, 0.271 Hz | `cg_view.c:1208-1214` |
| scope sway (camera) | 0.25° yaw, 0.175° pitch | 0.175 Hz, 0.271 Hz | `cg_view.c:1218-1229` |
| injury sway (camera) | 2.2° roll, 1.3° pitch at death's door | 0.151 / 0.271 / 0.111 Hz | `cg_view.c:2460-2461` |
| shell shock (camera) | 5.5° roll, 2.8° pitch, 1.6° yaw at sev 1 | 0.844 / 0.621 / 0.462 Hz | `cg_view.c:185-187` |
| shell-shock duration | `coop_dizzyTime` 4.2 s x severity, squared decay | — | `cg_view.c:161, 173, 183` |
| weapon lag | 0.7 u/deg, clamp 3.5 u, tau 143 ms | — | `cg_view.c:1263-1265` |
| weapon lag in ADS | x0.35 | — | `cg_view.c:1266` |
| recoil decay | rate 9.0 (tau 111 ms) | — | `cg_view.c:1250` |
| sprint gun-lower | 3.0 u dip, 1.4 u back, 1.2 u side | 1.27 Hz run bob | `cg_view.c:1395-1397` |
| head-bob scale | x1.35, x0.25 under sights | — | `cg_view.c:977, 989` |

**Read the scale off this table.** The proposed reload peak (1.6°) sits between the scope sway (0.25°)
and the injury sway (2.2°), and well under shell shock (5.5°). That is the right neighbourhood for a
deliberate, voluntary action. A reload should never be louder than being blown up.

## 5.4 The frequency floor

Anything the camera does continuously must sit **below ~1.5 Hz**. Every existing sway in this tree
does (max 0.844 Hz, shell shock roll). Above ~2 Hz camera motion stops reading as a body and starts
reading as vibration, which is both a nausea trigger and a readability cost. Discrete events (kick,
the chamber snap) are exempt — they are impulses, not oscillations.

## 5.5 Motion sickness bounds

**[X]** The published guidance is consistent and unfussy: head-bob and camera sway are named
*"extremely troublesome"* offenders, they are frequently shipped with no toggle, and the primary
ask of developers is *"add as many graphics settings as you can to control these"*
([Busseneau, *Alleviating motion sickness in first-person video games*](https://nicolas.busseneau.fr/en/blog/2020/09/alleviating-motion-sickness-in-first-person-video-games);
[Access-Ability, *Gaming with Motion Sickness*](https://access-ability.uk/2022/04/25/gaming-with-motion-sickness/)).
From a motion-sickness standpoint no bob is always safest, and bob/sway intensity should be a slider.

Translated to hard requirements for this feature:

1. **One cvar zeroes the whole layer**, and it must be `CVAR_ARCHIVE` so it survives a restart.
   `coop_reloadSway 0` already does this (`cg_view.c:115-118`) — preserve that contract exactly.
2. **Nothing accumulates.** Every state variable returns to a known rest value between reloads and
   is force-cleared on death, respawn, weapon switch, and map change. Today `s_reloadLift` clears on
   the disable path (`cg_view.c:116-118`) but the *statics* `s_iLastVMA` / `s_iVMAStart` do not
   (§0.5b).
3. **Every product is clamped** (§5.2).
4. **Nothing is always on.** The reload layer is zero except during a reload — which is what keeps
   it inside the sickness budget in the first place, and is a reason not to expand it into a
   permanent idle-motion system.
5. **`dt` is clamped** before it enters any integrator (§0.5a).

---

# §6 — Composition: where this sits relative to everything else

## 6.1 The layer map

Order of application in `CG_CalcViewValues`, as it stands today: **[P]**

```
CG_OffsetFirstPersonView()   <- view-weapon (pREnt->origin) layers: ADS sway, recoil, LAG,
   [cg_modelanim.c:2039]        free-aim, sprint lower, weapon collision      ... 1P ONLY
free-aim camera smoothing    [cg_view.c:2316-2404]
lean roll                    [cg_view.c:2407-2416]     ADS-damped
injury sway                  [cg_view.c:2419-2461]     ungated
engine view kick             [cg_view.c:2466-2500]     ungated
ADS / freecam / DBNO stage   [cg_view.c:2550-2552]
CG_OffsetThirdPersonView()   [cg_view.c:2604]          3P camera placement
camera-view override         [cg_view.c:2611-2640]     cutscene / turret
CG_ApplyReloadSway()         [cg_view.c:2643]  <-- runs after EVERYTHING, gated on nothing
CG_ApplyShellShock()         [cg_view.c:2644]
AnglesToAxis(...)            [cg_view.c:2645]
```

**Recommended placement for the rebuilt layer [I]:** split it in two, along the §0.6 dividing line.

- **Camera half** (pitch/roll/yaw degrees): stays at `cg_view.c:2643`, because bug-1942's lesson is
  that the function tail is the only point every view path flows through. Add the 1P/ADS gates
  *inside* the function rather than moving the call.
- **Weapon half** (positional heft + lag softening, units): goes inside
  `CG_OffsetFirstPersonView` alongside the existing `pREnt->origin` layers, after the lag block at
  `cg_view.c:1312`. This half is what makes it read as *the gun being handled* rather than *the
  camera moving*, and it is intrinsically 1P-only because the function is.

The camera half without the weapon half is what exists today, and it is why the effect reads as
"the view moves" rather than "I am reloading."

## 6.2 ADS — the sacred rule, made explicit

The point of aim must not leave the crosshair. Three facts, all **[P]**, define the problem exactly —
and it is *not* the same problem in first and third person.

**Fact 1 — bullets are safe.** The layer writes `cg.refdefViewAngles` (render only). The server
computes bullets from `ps.viewangles`, which this never touches. Bug-168's fix note asserts this and
the code confirms it. Nothing in this specification can move a round.

**Fact 2 — in FIRST person the crosshair is screen centre, so the camera *is* the crosshair.**
`cg_drawtools.cpp:1477-1478` places it at `(vidWidth - width) * 0.5`, `(vidHeight - height) * 0.5`.
Screen centre is by definition the `cg.refdef.viewaxis` direction, which is built from
`cg.refdefViewAngles` at `cg_view.c:2645`. So rotating the render camera **makes the crosshair lie by
exactly the applied angle** even though the bullet does not move. Free-aim shifts the crosshair off
centre (`cg_drawtools.cpp:1537-1544`) but only by the deadzone offset from `CG_GetFreeAim` — it does
**not** compensate for any other camera layer, so the lie survives it.

**Fact 3 — in THIRD person the crosshair is already true-aim, which inverts the symptom.**
`cg_crosshair3p` (default `1`, `cg_drawtools.cpp:1485-1486`) traces the real bullet ray from
`cg.predicted_player_state.viewangles` and re-projects the impact point through `cg.refdef.vieworg` /
`cg.refdef.viewaxis` (`cg_drawtools.cpp:1513-1529`). The reticle therefore stays glued to the impact
point no matter what the camera does — so in 3P the reload sway does not make the crosshair lie, it
makes **the reticle slide across the screen while the world swings under it.** That is arguably worse
to look at than a small lie, and it is a second, independent reason for the 3P gate in §0.4.

At the current 1.6° the first-person lie is 1.6° during every reload. It is mostly harmless because
you cannot fire mid-reload — **except** for `RELOAD_SINGLE`, where the player can interrupt after any
shell and fire immediately, and except for the `tau = 222 ms` settle tail after the reload ends.

There is precedent in this file for the strictest response: `cg_view.c:1769-1770` hides the crosshair
outright when the camera direction is not the aim direction, because *"the crosshair (incl. the 3P
true-aim projection) would lie."* That is available as a fallback if the ADS damping below proves
insufficient, but it should not be needed at x0.30.

**Required behaviour:**

| state | camera half | weapon half |
|---|---|---|
| hip fire, 1P | full (x1.0) | full |
| **ADS held (`CG_AimingDownSights()`, `cg_view.c:1540`)** | **x0.30**, and pitch only — roll and yaw forced to 0 so the sight post stays level and centred | full (the *gun* may move freely; the camera may not) |
| **scoped (`ps.stats[STAT_INZOOM]`)** | **x0.0** | x0.0 — matches `cg_weaponLag`'s `!bScoped` rule at `cg_view.c:1298` |
| breath-hold steady (`s_breathSteady`) | x0.6 | x0.6 |
| **any 3P mode (`cg.renderingThirdPerson`)** | **x0.0** | n/a (function does not run) |
| staged 3P ADS shoulder | x0.0 (still 3P) | n/a |
| staged 3P ADS -> irons (`CG_AdsForceFirstPerson()`, `cg_view.c:1833`) | treat as 1P ADS | full |
| `PMF_CAMERA_VIEW` (cutscene/turret) | **x0.0** | n/a |
| DBNO (`coop_dbnoView`) | x0.0 | x0.0 — the downed presentation owns the camera |

**The single decider must be `CG_AdsForceFirstPerson()` for the 1P/3P question**, not
`cg_3rd_person->integer`. That function is documented in `cg_local.h:646` as *"render FIRST person
this frame (camera + own-model draw MUST both use this)"*, and the staged-ADS work established it as
the one authority. Reading `cg_3rd_person` directly is how bug-329/332 happened.

## 6.3 Networking: nothing needed, and here is the price if that changes

**Nothing in this specification requires a new networked field.** Every input is already in the
snapshot: `iViewModelAnim` (via `iNetViewModelAnim`, 4 bits, `msg.cpp:3367`),
`iViewModelAnimChanged` (2 bits, `msg.cpp:3358`), `stats[]`, `pm_flags`, `velocity`, plus purely
client-local state (`cgi.anim->*`, usercmd buttons). **[P]**

**If a future revision wants a networked field, price it loudly:**

- A `playerState_t` field change means `msg.cpp` field tables, `cl_parse.cpp`, and the server all
  change together — **exe + cgame + game must ship as a set**, and a mismatched set is a silent
  desync, not a crash. `.wolf/buglog.json` has the precedents (the `GENTITYNUM_BITS` 11 work and the
  `MAX_SNAPSHOT_ENTITIES` 1024->2048 miss that stayed hidden for four bugs).
- **`iNetViewModelAnim` is 4 bits and `vmAnim_e` currently has 15 entries (0-14)
  (`bg_public.h:160-175`).** Adding a 16th viewmodel anim state overflows the field silently.
  **[P]** Any proposal that wants e.g. a `VM_ANIM_RELOAD_EMPTY` must widen that field, which is a
  protocol change.
- The correct cheap channel for a *server-known, client-unknown* fact in this project is a stuffed
  per-client cvar — the pattern `coop_dizzy` (`cg_view.c:160`), `coop_dbnoView`, and
  `coop_setSuppression` already use. It costs one reliable command, no protocol change.

---

# §7 — Shipping it: acceptance tests, cvars, rollback

The user tests one build per session and reports what they **see**. Every item below is
live-observable without instrumentation.

## 7.1 Cvars — every one defaults to today's behaviour

| cvar | default | effect at default | flags |
|---|---|---|---|
| `coop_reloadSway` | `1.6` | **unchanged** — peak degrees, 0 disables everything | `CVAR_ARCHIVE` |
| `coop_reloadVary` | `0` | **0 = today's fixed curve.** 1 enables per-instance + context variation | `CVAR_ARCHIVE` |
| `coop_reloadRetime` | `0` | **0 = today's fixed 900 ms.** 1 retimes to `cgi.Anim_Time` | `CVAR_ARCHIVE` |
| `coop_reloadHeft` | `0` | **0 = camera only.** 1 enables the view-weapon positional half | `CVAR_ARCHIVE` |
| `coop_reloadADS` | `0.30` | camera scale while aiming (today: effectively 1.0 — this is the one intentional default change) | `CVAR_ARCHIVE` |
| `coop_reloadDebug` | `0` | one `Com_Printf` line per reload: anim, duration, context flags, drawn multipliers | not archived |

**With `coop_reloadVary 0`, `coop_reloadRetime 0`, `coop_reloadHeft 0` the build must be
pixel-identical to today except for the three bug fixes** (3P gate, `dt` clamp, `fPhase` floor) and
the ADS damping. That property is what makes it safe to ship in one session.

## 7.2 Test cfgs

Follow the `rag_*.cfg` pattern in `hzm-mohaa-coop-mod/coop_mod/cfg/` — one file per A/B state, each
ending in an `echo` that names the next key. **[P]** Proposed: `reload_off.cfg` (everything 0),
`reload_base.cfg` (today), `reload_full.cfg` (all on), `reload_big.cfg` (`coop_reloadSway 5` — makes
timing errors visible at a glance). Bind them in `hzm-mohaa-coop-mod/autoexec.cfg` alongside the
existing `KP_*` tuning binds (`autoexec.cfg:333-342`).

## 7.3 Acceptance tests — what the user should SEE

| # | do this | pass |
|---|---|---|
| A1 | `coop_reloadSway 0`, reload | camera dead still. Proves the off switch. |
| A2 | `coop_reloadSway 5`, `coop_reloadRetime 1`, reload a **Garand** then a **BAR** | the lift *finishes* at visibly different moments — the BAR keeps climbing well after the Garand has stopped. Today they stop together. |
| A3 | `coop_reloadVary 1`, reload the same gun **six times standing still** | six visibly different amounts of lift; no two identical. Timing feels the same each time. |
| A4 | fire the clip **dry**, reload; then reload at **half a clip** | the dry reload is bigger and has an extra downward beat at the end. The half reload is smaller and smoother. |
| A5 | reload **standing**, then **crouched** | crouched is visibly smaller/tighter. |
| A6 | reload while a **machine gun is firing at you** | bigger and snatchier than the calm version. |
| A7 | hold ADS and reload | **the front sight stays on the crosshair.** No roll, no yaw, minimal pitch. This is the sacred test. |
| A8 | scope a Springfield, reload | camera dead still through the scope. |
| A9 | `cg_3rd_person 1`, reload | **the world does not swing.** Today it does. |
| A10 | reload a **shotgun** (single-load) | each shell is its own small pump, not one flat hold. |
| A11 | `coop_reloadHeft 1`, reload | the **gun** moves in the hands, not just the view — visible as the weapon shifting against the screen edges. |
| A12 | start a reload, `maptest_transition`, reload on arrival | no downward slam on the first reload after the load. |
| A13 | reload ten times in a row and just watch | **no drift.** The rest pose is identical after the tenth as after the first. |
| A14 | reload while **downed** (DBNO) | camera unaffected; the downed presentation owns the view. |

A2, A7, A9 and A10 are the four that decide whether the feature worked.

## 7.4 Rollback

`coop_reloadVary 0; coop_reloadRetime 0; coop_reloadHeft 0; coop_reloadADS 1` — one console line,
back to today's behaviour without a rebuild.
Full removal: `coop_reloadSway 0`.
Binary rollback: restore the previous `cgame.dll`. This is **cgame-only** — no `game.dll`, no exe, no
protocol — so it ships alone and reverts alone. That is the main reason to keep every input
client-side (§6.3).

---

# §8 — Sources

**External [X]**
- Squirrel Eiserloh, *Math for Game Programmers: Juicing Your Cameras With Math*, GDC 2016 — trauma
  model, `trauma^2`/`trauma^3`, and smoothed fractal noise over random.
  [GDC Vault](https://gdcvault.com/play/1023146/Math-for-Game-Programmers-Juicing) ·
  [transcript](https://archive.org/stream/GDC2016Eiserloh/GDC2016-Eiserloh_djvu.txt)
- [CryEngine 3 — Procedural Weapon Animations](https://docs.cryengine.com/display/SDKDOC2/Procedural+Weapon+Animations) — additive vs override layering.
- [Dev_Unallocated — Procedural Weapon Animations (condensed)](https://www.devunallocated.com/projects/project-killhouse/procedural-weapon-animations-condensed) — the ten-layer breakdown; note it gives **no** numeric values.
- [Why Procedural Animations Are Essential for FPS Game Dev](https://unrealfpskit.com/blog/why-procedural-animations-fps/) — recoil/sway/recovery driven from data.
- Anders Nilsson, *Crafting Gun Feel: Investigating How Professional Game Developers Create the Feel
  of Gunplay in Shooter Games* — practitioner interviews; audio randomisation as a variation channel.
  [DiVA record](http://www.diva-portal.org/smash/record.jsf?pid=diva2:1971715) *(host was unreachable
  at time of writing; cited from the search abstract only — treat as secondary)*
- [Tactical reload](https://en.wikipedia.org/wiki/Tactical_reload) ·
  [Fallout 4 Tactical Reload framework](https://www.nexusmods.com/fallout4/mods/49444) — empty vs
  partial reload as an authored-variant convention.
- [Busseneau — Alleviating motion sickness in first-person video games](https://nicolas.busseneau.fr/en/blog/2020/09/alleviating-motion-sickness-in-first-person-video-games) ·
  [Access-Ability — Gaming with Motion Sickness](https://access-ability.uk/2022/04/25/gaming-with-motion-sickness/) — bob/sway as named offenders; sliders and off switches.
- [QDStaff — Breaking the Lag: Fixing Unresponsive Game Animations](https://qdstaff.com/breaking-the-lag-fixing-unresponsive-game-animations/) — desynced animation reads as input lag.
- [Playtank — First-Person 3Cs: Camera](https://playtank.io/2023/05/12/first-person-3cs-camera/) — *(403 at time of writing; listed for a later pass, not cited above)*

**This codebase [P]** — `cgame/cg_view.c`, `cgame/cg_modelanim.c`, `cgame/cg_viewmodelanim.c`,
`cgame/cg_public.h`, `cgame/cg_local.h`, `fgame/bg_public.h`, `fgame/weapon.cpp`, `fgame/player.cpp`,
`qcommon/q_shared.h`, `qcommon/msg.cpp`, `client/cl_parse.cpp`,
`skeletor/skeletor_animation_file_format.h`, `hzm-mohaa-coop-mod/models/weapons/*.tik`,
`hzm-mohaa-coop-mod/models/**/*.skc`, `.wolf/buglog.json` (bug-110, 165, 168, 327, 328, 1238, 1881,
1942).
