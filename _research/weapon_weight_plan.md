# WEAPON WEIGHT — what else makes a gun feel heavy

> **BUILT 2026-08-27.** Items 1-11 and 13 are shipped: heft (rebuilt twice - see below), variant
> resolution, 3P torso lag, second-order asymmetric lag spring with the framerate fix, muzzle droop
> at the grip, sprint ready-up delay, stamina drain, AI hearing radius, breath hold, AI suppression
> radius. Item 12 (14 movement tiers from movementspeed) is DELIBERATELY SKIPPED: that field is
> reused in this mod as a scripted movement penalty (dbno_pistol), and coop_weaponMoveByClass already
> delivers the same thing from the weapon class, which is the derivation the heft work converged on
> anyway. Items 14-16 need audio assets. Item 17 (turn inertia) stays refused.
> Three heft derivations were needed - recoil climb (inverted), movementspeed (poisoned), weapon
> class (shipped) - and each inversion was caught by review rather than by play. See bug-2139..2142.

Design plan, 2026-08-27. Excludes everything already shipped (lag spring, per-gun authored recoil, heft-scaled ADS raise, feel
budget, landing dip, bob lock, muzzle retract, ADS suite, sprint/stamina, slide, vault, cover, prone, bracing, holstering,
handling foley, mechanical audio). Where an item extends a shipped system, its heading says so.

---

## 1. THE THESIS

**Mass is a low-pass filter on the player's intent.** A gun feels heavy not because it is drawn low or wobbles, but because
every channel the player drives — look, move, aim, fire, swap — answers *late*, and the size of that lateness is the weapon's
mass. Three things read hardest, in order: **time costs the player waits through** (raise, swap, sprint-out), **rate ceilings
they push against** (how fast the sights realign, how fast the body turns), and **the settle** — what the weapon does in the
half-second *after* motion stops. The settle is the most under-built and the most legible. Displace fast, realign slowly, and it
reads as mass; bounce, and it reads as flimsy — heavy is an over-damped spring at low frequency, not a big springy one. This
project's lag spring is first-order, so it can lag but can never overshoot-and-catch, the exact motion the eye reads as inertia.

**And mass is relative** — a contrast percept, not an absolute. If every gun gets heavier, none feels heavy; the game just feels
sluggish. The lightest weapon has to stay genuinely snappy for the Panzerschreck to land. Which is why the top item below is not
a feature: **the per-gun heft scalar shipped today is ordered backwards.** `CoopHeft()` derives weight from recoil climb, but
climb has mass in the *denominator* — so bazooka and panzerschreck score **0.00** (their kick lives in `recenter 56`, not the
pitch pair) while a G43 scores **1.00**. Verified against all 70 rows of `coop_mod/recoil_table.txt`. The heaviest weapons in
the game currently shoulder *faster* than a Kar98 and get *zero* recoil weighting. Every item here multiplies that scalar, so
fixing it outranks all of them. Better data is already in the box: **469 of 481** weapon TIKs declare `dmmovementspeed`, and it
orders correctly end to end (launchers 0.75 → Kar98 1.05).

---

## 2. RANKED — weight read per hour of work

| # | item | reads | effort | binaries | risk |
|---|---|---|---|---|---|
| 1 | Re-derive `CoopHeft()` from `movementspeed`, not recoil climb | ★★★★★ | XS | game | low |
| 2 | Variant-suffix strip in `CoopFindRecoil()` (440/481 TIKs currently inert) | ★★★★★ | XS | game | low |
| 3 | Per-weapon 3P torso lag — one multiply, visible to every observer | ★★★★★ | XS | game | low |
| 4 | Second-order lag spring: overshoot + settle (+ framerate fix) | ★★★★★ | S | cgame | med |
| 5 | Asymmetric realign — fast displace, slow settle, per heft | ★★★★★ | S | cgame | low |
| 6 | Viewmodel **rotation** as the mass channel (unbudgeted) | ★★★★ | S | cgame | low |
| 7 | Heft-scaled sprint-out delay before fire/ADS is permitted | ★★★★ | S | game | med |
| 8 | Viewmodel anim clock scaled by heft (pullout/putaway/idle only) | ★★★★ | XS | cgame | low |
| 9 | Heft-scaled stamina drain | ★★★★ | XS | game | low |
| 10 | Heft-scaled AI hearing radius | ★★★★ | XS | game | low |
| 11 | Heft-scaled breath-hold duration | ★★★ | XS | cgame | low |
| 12 | 14-tier movement speed from `movementspeed`, replacing the 5-bucket table | ★★★ | S | game | med |
| 13 | Heft-scaled suppression radius | ★★★ | XS | game | low |
| 14 | Weight-tiered handling foley + heft-scaled action-foley delay | ★★★ | S–M | cgame + data | low |
| 15 | 3P equipment rattle keyed to carried weight | ★★★ | M | cgame | med |
| 16 | Low-end sub layer on heavy weapon shots | ★★★ | M | data | low |
| 17 | Turn inertia via `CG_SensitivityScale()` | ★★★★/★☆ | S | cgame | **high** |

Items 1–3 are one-to-twenty-line changes that each repair or unlock a system already built. Nothing else comes close on
read-per-hour. Items 9–13 and 15 are detailed in §4.

---

## 3. THE ITEMS

### 1. Re-derive `CoopHeft()` from `movementspeed` — EXTENDS today's heft work
`fgame/weapon.cpp:2710 Weapon::CoopHeft()`. Replace the mean-pitch derivation with `1 - normalise(GetMovementSpeed())` over the
observed 0.75–1.05 range, falling back to `normalise(recenter)` — which *does* separate the launchers
(bazooka/panzerschreck/PIAT 56, shotgun 15.2, pistols ~1) — when a TIK declares no movementspeed. **Reads as mass** because it
is a developer statement of encumbrance rather than of violence, and it puts the heaviest objects at the heavy end instead of at
zero. Keep the recoil table as the authority for *violence*; the two axes should tune apart. **XS. game.dll only** — heft
already reaches the client on the change-only stufftext at `player.cpp:5643`. Risk: low, but every downstream value tuned
against the old scalar needs a re-feel pass.

### 2. Variant-suffix strip in `CoopFindRecoil()`
`weapon.cpp:2682` keys on the bare model filename; `coop_mod/loadoutskins.scr` spawns 428 variant TIKs across 7 finishes, so
only **41 of 481** weapon TIKs match. For the other 440 the authored recoil falls back to the legacy flat kick and heft returns
0.0 — **today's per-gun recoil feature is inert on every unlocked finish.** Exact match first, then retry with the finish tokens
stripped (`_gold _chrome _blued _bloody _camo_woodland _camo_winter _camo_desert`), then longest-key-prefix for the ~12 model
swaps (`bar_bar1918a1`, `g43_dhg43fleck`). Fifth instance of the variant-suffix family in `docs/TRAPS.md:799`. **XS. game.dll.**
Risk: low — safe against `kar98_lite`, `mp40silenced`; neither ends in a finish token.

### 3. Per-weapon torso lag in third person
`fgame/player.cpp:15267`, in `ApplyCoopBoneOffsets`. The chest already counter-rotates against yaw rate (`coop_torsoLagAmount
0.35`, clamped ±18°) and — unlike the first-person spring — is correctly rate-based (`/ dt`). Multiply the amount by `(0.6 +
0.8*heft)`. **Reads as mass** because a bazooka's chest visibly drags a beat behind the turn where a Luger's does not, on the
networked bone channel, seen by every teammate, with zero new wire. The direct answer to "how does the world respond". **XS, one
multiply. game.dll.** Risk: low; honour the supine mirror (`player.cpp:15030`) if the term is ever made pitch-bearing.

### 4. Second-order lag spring — EXTENDS the shipped `cg_weaponLag`
`cgame/cg_view.c:3116-3184`. **(a) Correctness first:** the target is built from a per-*frame* angular delta, so trail is linear
in frametime — a rifle settles at 2.31 u at 60 fps and 0.55 u at 250 fps, and the ±3.5 clamp only ever engages on slow machines,
so every number in the block is calibrated to one machine's framerate. Divide by `dt`, rescale the gain. **(b) Then upgrade:**
`x += (target-x)*k` is first-order — a pure exponential step response, so it can only lag, never overshoot. Add one velocity
static: `v += (K*(t-x) - C*v)*dt; x += v*dt`, ζ from heft (ζ≥1, low ω for heavy; ζ<1, high ω for light). **Reads as mass**
because the eye reads the settle, not the offset — a gun swung and *caught* is the most legible inertia cue available. **S.
cgame.dll.** Risk: medium — clamp `dt` like the other integrators (`:2185`), and keep `s_prevPitch` captured *before*
`CG_ApplyReloadFeel` (`:3501`) writes a sine into `refdefViewAngles`, or this becomes bug-1984 with velocity state.

### 5. Asymmetric realign — displace fast, settle slow
Same block; today one stiffness governs both directions. Split it: displacement rate stays fast, return rate scales down with
heft. Also ease the ADS damping through `CG_AdsPoseFactor()` instead of stepping it on the binary `bAds` (`:3151`), which
currently drops the gain 65 % in one frame. **Reads as mass:** "your sights are knocked out of alignment the way you moved, and
it takes time to come back" is the cleanest verbal statement of weight in the medium. **S. cgame.dll.** Risk: low.

### 6. Viewmodel rotation as the mass channel
`cg_view.c`, late in `CG_OffsetFirstPersonView` (after the `AxisCopy` read, per the note at `:2647`). **Rotation is outside the
9-unit feel budget and outside the camera**, and a grep of `pREnt->axis` writes returns only the idle inspect — the channel is
unclaimed. Spend it on mass: a muzzle-heavy pitch droop proportional to heft under hip carry, growing with fatigue; a small roll
as the body turns; a heft-scaled tilt on landing. **Reads as mass** because a sagging barrel is the most literal weight
statement there is — and being rotational it survives sprint saturation, where the translational sum already hits 13+ against a
9 cap and every new translational knob is inert (bug-2016, `TRAPS.md:857`). **S. cgame.dll.** Risk: low; give it its own ceiling
(roll already has ±6°) so it can never occlude the sight picture.

### 7. Heft-scaled sprint-out delay — EXTENDS the sprint gun-lower
`fgame/player.cpp`, in the sprint tick beside the no-fire-while-sprinting gate; the client already has a sprint-to-fire snap at
`cg_view.c:2842`. Today firing unlocks the frame you release Shift. Gate it for `120 + 260*heft` ms, blocking fire *and* the
start of ADS. **Reads as mass** because the cost lands at the moment of decision and is felt as agency, not decoration — the
player wanted to shoot and the gun was not ready. Highest-read item here that is not a bug fix. **S. game.dll** (keep it out of
`bg_pmove.cpp` so the predictor is untouched). **Risk: medium — this one can annoy.** Ship behind a cvar, keep the pistol/SMG
end near zero, playtest before trusting the tuning.

### 8. Viewmodel animation clock scaled by heft
`cgame/cg_viewmodelanim.c:846` — `g_VMFrameInfo[i].time += cg.frametime / 1000.0` is the *only* place the viewmodel clock
advances. Scale it by `1/(1 + 0.35*heft)` for `VM_ANIM_PULLOUT`, `VM_ANIM_PUTAWAY`, the idles and `VM_ANIM_RECHAMBER`. **Reads
as mass:** the whole handling motion of a heavy gun becomes physically slower, with no new art. **XS, one line plus a switch on
`g_iLastVMAnim`. cgame.dll.** **Risk: hard constraint — never scale `VM_ANIM_RELOAD` or `VM_ANIM_FIRE`.** The server owns those
completions (`EV_Weapon_DoneReloading`, `FireDelay`), so slowing the client clock desynchronises the visual from the
authoritative state. If the switch *duration* should change, do it in `coop_mod/player_Torso.st` (385 per-weapon conditions
already there), not in the clock, or first and third person disagree.

### 14. Weight-tiered handling foley — EXTENDS the shipped foley layer
`cg_view.c:990` picks the class prefix (`pistol/smg/mg/rifle`) from `STAT_EQUIPPED_WEAPON`; select it from `coop_gunHeft`
instead and add a `heavy` set — every existing edge (ADS, crouch, sprint, swap, dry-fire) then reroutes with no new hooks.
Separately `CG_NoteLocalFire()` (`:5860`) schedules the mechanical layer at a flat `+55 ms`; make the delay and the light/heavy
choice functions of heft. **Reads as mass** because a bigger reciprocating mass clunks later and lower — physically true and
audibly obvious. **S code, M content. cgame.dll + alias data.** No wire cost: `S_StartLocalSound` allocates no `CS_SOUNDS` slot,
so the MAX_SOUNDS ceiling (2048, hard compile-time guard at `q_shared.h:1742`) is not in play. Fix the stale comment at
`cg_view.c:5900` while there — `cl_cgame.cpp:581` passes `CHAN_AUTO`, not `CHAN_MENU`.

### 16. Low-end layer on heavy shots
Mix, not code: a sub-thump one-shot layered under heavy-class fire, client-local. **Reads as mass** because low-frequency
content on impacts is the most direct "this is heavy" signal in audio, and it is the cheapest of the three legs of impact feel
(hit-stop / sound coherence / camera response) that must agree or the whole thing degrades. **M, content-bound. Data only.**
Risk: low.

### 17. Turn inertia via `CG_SensitivityScale()`
`cg_view.c:5374` returns `cg.zoomSensitivity` and the exe already calls it every frame (`client/cl_input.cpp:629`) — so turn
rate is a **cgame.dll-only** lever, no exe rebuild, no protocol change. Build inertia, not a flat penalty: an envelope starting
the scale low and climbing to 1 over ~150 ms, depth by heft. **S. cgame.dll. Risk: HIGH — this is the technique players hate**;
input-multiplication is Tarkov's most-disliked mechanic. If built: never below 0.85, default shallow or off, compose with (never
replace) `fov_y/75` or scoped aim breaks, and low-pass the *measurement* not the output or the loop oscillates. **The safer read
of the whole survey: do not slow the camera, slow the alignment (items 4–6).** An experiment, not a plan item.

---

## 4. THE PLAYER AND THE WORLD

One constraint shapes this section: `CoopGunFoley` bails on `cg.renderingThirdPerson` (`cg_view.c:968`), so the whole
handling-foley layer is self-only — **teammates never hear each other's gear.** Everything here must go through the server, the
bone channel, or the remote-player footstep path.

**9. Heft-scaled stamina drain.** `player.cpp:15697` drains a flat `dt/sec`; multiply by `(1 + 0.6*heft)`, cap 1.6×. **Reads as
mass because it changes route planning** — a Panzerschreck buys three seconds of sprint, not five, which changes which gaps you
can cross. Not theatre, a movement-budget change. **XS. game.dll**, outside `bg_pmove.cpp` so the predictor is never involved.
Scale the *rate* only, never the discrete jump/vault/slide costs.

**10. Heft-scaled AI hearing radius.** `weapon.cpp:2575` broadcasts a calibre-blind `AI_EVENT_WEAPON_FIRE` — a Panzerschreck and
a Luger alert the same bubble. Scale by `(0.7 + 0.6*heft)` inside the clamp: firing the heavy gun should pull the map onto you.
**XS. game.dll.** **Leave the `level.m_bStealthNative` branch at 1500** — its banner documents that constant as the fix for one
shot alerting most of m6l2a.

**11. Heft-scaled breath-hold.** `cg_view.c:909`, `cg_breathHoldTime 7`. Hold a Springfield 7 s, an MG 3. `coop_gunHeft` is
already on the client, and this touches the aiming loop every engagement. **XS. cgame.dll.**

**12. 14-tier movement speed.** `player.cpp:4914` uses `coop_weaponMoveByClass` (5 buckets); `GetMovementSpeed()`
(`weapon.cpp:5432`) gives 14 tiers from real per-gun data, and observers read gait speed and footstep cadence directly. **The
justification comment at `player.cpp:4914` is stale** — it says "our bar.tik has none", but `models/weapons/bar.tik:70-72`
declares sp 0.9 / dm 0.85 / realism 0.85, and 469 of 481 TIKs declare it. Re-test before citing it again. **S. game.dll.** Risk:
medium — rebalances 469 weapons at once.

**13. Heft-scaled suppression radius.** `weaputils.cpp:2671`, `coop_aiSuppressRadius 150`, flat. A BAR near-miss should rattle a
wider bubble than a pistol: `rad * (0.6 + 0.8*heft)`. Real, because it decides whether suppressing fire *works* — the reason to
carry the heavy gun. **XS. game.dll.**

**15. 3P equipment rattle by carried weight.** `cg_specialfx.cpp:693` gates `snd_step_equipment` on an *animation* flag
unrelated to what you carry, and this path runs for remote players. **A teammate you can hear is carrying the heavy gun** beats
any visual item here. Cost: the client does not know a remote player's weight, so it needs client-side derivation from the
attached weapon model name or a second publish. **M. cgame.dll (+ possible game.dll publish).**

**Weight-scaled landing.** `CG_LandingSound` already takes volume and an equipment flag, but landing **broadcasts no AI event at
all** — only `Footstep` does (`sentient.cpp:5197`, radius 512). A heft-scaled landing the AI can hear is a stealth consequence,
not decoration. **S. game.dll.**

---

## 5. WHAT NOT TO DO

- **Small flat movement penalties.** KF2's 8 % at full load is below the perception floor — invisible, and it still
costs goodwill. Large enough to change behaviour, or not at all.
- **Mouse-sensitivity multiplication as a plain penalty.** See item 17: penalise the alignment, not the camera.
- **Any new *translational* viewmodel channel active while sprinting or on a hard landing.** The 9-unit budget is
saturated in both states (sprint sums 13+, an MG landing dip alone ~13), and past saturation a shared budget makes every control
inside it inert — turning the knob up raises the scale-down factor and cancels the gain (bug-2016). Put it in rotation instead.
- **New bone controllers on the third-person player.** All five networked slots are claimed (`q_shared.h:2135`,
`player.cpp:2850`); raising the count is a protocol change costing every entity forever, and `bone_quat` writes on world
entities deflect server hitboxes. Modulating the existing TORSO_TAG (item 3) is the whole opportunity.
- **Per-shot positional weight audio for remote shooters.** A second sound per shot per shooter is a real voice-count
and bandwidth cost in a firefight; reasoned out already at `cg_view.c:5875`.
- **A third calibre tier of impact decals.** The wire has room (`bulletbits = 2`), but the client consumes it as
LITE/HARD *pairs* (`cg_parsemsg.cpp:245`) — a third tier means ~15 new authored FX rows, for a four-inch decal seen from 40 m.
The cheap 80 % is moving the existing `damage >= 41` threshold onto heft. Also `bulletbits = 1` on legacy protocol, so writing 2
or 3 unguarded breaks old clients.
- **Muzzle-blast dust and foliage disturbance — theatre.** Off-axis, occluded by the weapon model, gone in 200 ms, and
it costs new FX content. The one version that is not theatre is firing prone or braced over dirt, where the blast obscures *your
own* sight picture — because that costs the player something.
- **New per-weapon carry/raise animations.** Real, but `.skc` authoring is the slowest path here and the Blender
carry-pose edit is already paused mid-task. The bone channel fakes a droop; it cannot fake a grip change.

**The risk that outranks every item: multiplicative stacking.** Six systems already degrade the player — stress→spread, limp,
stamina, recoil, weapon lag, feel budget. If heft multiplies into each independently, a Panzerschreck user gets degraded aim ×
slow ADS × heavy recoil × fast drain × wide spread, and the gun is not heavy, it is unfun. The codebase guards this pattern
explicitly already (the `coop_braceStress` server/client twins, `player.cpp:14206`). Same discipline: **one heft scalar,
consumed at a short documented list of named sites, with the total degradation budget written down** — and the lightest gun kept
genuinely snappy, because weight only reads as contrast.
