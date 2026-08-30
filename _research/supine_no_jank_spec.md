# Prone/Supine No-Jank Specification (deep vet, 2026-08-26)

> **STATUS 2026-08-27: SUPINE IS OFF (`coop_supine 0`) - bug-2135.** The rigid flip mirrors about
> z=19, so boots resting at z~4 land at z~34: the legs hang thirty units off the deck and no
> parameter fixes it, because a mirror cannot re-plant a limb it does not know is touching the
> floor. Together with the research theorem (no rigid transform can aim backward while keeping the
> head put) the transform family is exhausted twice over. Belly prone and everything else stays on.
> Next real move is authored animation - Blender 5.1 and md5_2_skX.exe are both available.

Two research passes (agent-audited, every claim file:line-anchored in the originals; this is the
operative condensation). Pass 1 fixed the flip math itself (bug-2122). Pass 2 audited the whole
system. Stage A + P1 were implemented the same day.

## Settled verdicts (no work needed)

- **Fire/aim/grenade/crosshair geometry while supine is SOUND.** The entire ballistic system is
  view-based: fire ray = eye pos (origin+16) along viewangles (weapon.cpp:1683-1686); body yaw
  never enters. The 3P true-aim crosshair projects the same ray. Shots cannot come from behind
  the head or the ground.
- **Hit locations on a rolled body are correct-by-construction** - SV_TraceDeep resolves
  locations from live animated bone orientations (cm_trace_lbd.cpp:486), so the flipped pose is
  what gets hit.
- **Reloads while supine (incl. pistol) are sound** - the supine weight-zero outranks the pistol
  exemption; notetracks are time-driven and still run.
- **1P supine works; the 3P shoulder cam does NOT sit at the feet** (it hangs behind the aim =
  past the head - the correct framing for free).
- **pm_flags has NO free bit** (16-bit wire cap, all assigned). Client-side supine detection must
  come from the legs frameInfo anim name.

## Implemented 2026-08-26 (Stage A + P1)

- A1 `bMustLeave |= m_bCoopDbno` - DBNO-while-prone kept the prone viewheight and resurrected the
  bug-2112 under-map camera; supine added a backwards DBNO crawl. (bug-2123)
- A2 supine bone frame: the 180 roll reverses bone-local Y/Z, so pmove's spine pitch shares and
  the +35 action tier acted INVERTED on the flipped body; aim-lead was ±180-based and snapped the
  head ±27°. All three re-based/negated while supine (`coop_supineSpine` trim, default 0).
- A3 turn hysteresis measured against the eased TARGET (was pinned ±1 the whole time on the back).
- A4 flip window drives the yaw at `coop_supineFlipRate` 200°/s (=180/0.9) so the yaw finishes
  WITH the roll anim (was: anim ends at 0.9s, pose pivots flat for 0.6s more). Windows are
  per-direction 0.9/1.0s (rolll=9f, rollr=10f).
- A5 crouch-press exit from supine arms the flip-out and DEFERS the stand until it ends (was: an
  instant 180° body snap). Jump exits stay immediate.
- A6 movement input zeroed + lean-rolls suppressed while supine (`coop_supineMove 0`) - WASD slid
  a frozen statue at ~84 u/s and tripped the fire strip; lean-rolls impulsed with no anim.
- A7 weight-zero extended to every unflipped torso action while supine (PUTAWAY_/RAISE_/
  CHARGE|RELEASE_ATTACK_GRENADE/both RECHAMBERs + RELOAD_): every action anim carries the root
  rot channel, so ANY unflipped overlay rolls the body ~90° sideways at blend weight. Notetracks
  still run at zero weight.
- A8 `m_bCoopDiedSupine` latch (set before death wipes the flags) + `COOP_DIED_SUPINE` conditional
  + `KILLED_SUPINE` route/state playing flipped `coop_supine_death` - dying on your back stays on
  your back.
- A9 removed the stale timestamp-into-accumulator branch (instant-prone landmine on dt=0 frames).
- P1 flipped `supine_hit_{helmet,torso,legs}` + `supine_death` (all MOVEMENT-class sources) +
  7 pain aliases + engine pain-picker supine branch.

## Pass 3 (2026-08-27, bug-2126) - 9 confirmed findings, all fixed

Lean gated out of prone/supine at the pmove level (bg_pmove PMF_VIEW_PRONE guard - game.dll +
cgame.dll pair); the 16 torso states the 08-25 sweep missed (bazooka/mortar/landmine/minedetector/
bashes) got prone+supine rows with 10 new stock-notetrack-verbatim aliases; prone-reload tail latch;
hide gate widened over flip-out; upstream dead pain-location switch fixed (scoped to prone/supine -
supine_hit_helmet/_legs were unreachable); pelvis pitch mirrored supine; enter-latch yields to a
running evasive roll; jump cuts an armed deferred exit; grenade prone switch sounds restored.
ATTACK_ITEM_* verified clean (no action block). Melee bash while prone now lands from the ground
(frame-4 fire notetrack) with the shoot pose - crude but flat; flipped bash anims stay P3 backlog.

## Pass 4 (2026-08-27, bug-2127) - 8 confirmed findings, all fixed

Cover and prone are now mutually exclusive by construction (cover terms in bMustLeave + prone
terms in cover entry/cancel; ladder/water bMustLeave gaps closed with them); fire-strip and the
supine enter-latch gate on PMF_VIEW_PRONE as well as the flag; the supine/flip movement freeze
reaches the client predictor via replicated ps.speed=0 (rubber-band + false crawl-dip fixed,
protocol-free); pain picker XORs flag with flip window to route by SOURCE pose; the flip-window
hide now covers EVERY torso action (fires included - notetracks still discharge); evasive-roll
rows added to turn+crawl legs states (impulse had no anim route outside PRONE_IDLE); COOP_SELFHEAL
and RAISE_PAPERS got stance rows; the hidden-torso latch releases on stand-up.

## THE GEOMETRY CORRECTION (2026-08-27, bug-2129) - read this before touching the yaw

The supine body yaw target is the VIEW, not view+180. A 180 roll about the model's X axis (what
skc_flip does) spins the body about its own head-to-toe line: the head stays at the head end and
the gun still points along the body's facing - only the belly turns skyward. So the flipped anim's
gun direction IS the body yaw, and the body must track the view exactly as it does belly-down.
The old +180 cancelled against the ~180 flip trigger, so the body never turned at all.
Dependents that inherited the same false premise and were fixed with it: the aim-lead base, and
the aim-came-forward exit (now measured against m_fCoopSupineRefYaw, the belly facing latched at
flip time - the live body yaw can no longer serve as that reference).

## V3 - THE ARMS, NOT THE YAW (2026-08-27, bug-2134). Supersedes the geometry note above.

THEOREM: head axis and gun are both model +X in every prone source, and a rigid rotation moves both
identically - so NO transform of a prone clip can aim backward while keeping the head put. Both
earlier attempts were therefore unwinnable as posed. The 180 must be spent at the SHOULDERS.

While supine, ARMS_TAG -> 'Bip01 L Clavicle' and PELVIS_TAG -> 'Bip01 R Clavicle', both given a 180
pitch: head and pelvis untouched, muzzle over the feet, sights up (also fixes the upside-down rifle).
The controllers are full-range re-pointable networked subtree rotations - the clamps we believed in
are Actor code. coop_supineMode 1 = plant the body (TLOU2, default), 0 = the v2 somersault.
coop_supineCone 60 rolls you back to belly rather than spinning you on your back. The flip-rate boost
applies only in mode 0. Deferred, needs authored animation: the spine crunch (he lies flat rather
than propped on his shoulder blades) and the left hand coming off the rifle by ~5.7u.
NOTE: Blender 5.1 and md5_2_skX.exe ARE available - authoring is not closed off, just not first.

## Remaining work (ordered)

- **P2 flips**: putaway/pullout (pullout `--action`), grenade takeout/throw/putaway (MOVEMENT) +
  COOP_SUPINE torso rows; remove each from the A7 weight-zero list as it lands. Alias notetracks
  copy verbatim (identical frame counts).
- **P3 flips**: per-class supine shoots (mp40/mp44 bursts verbatim; pistol set), supine
  turn-in-place pair + routes, flipped rolls if supine rolls wanted.
- **v2 movement**: 4 flipped walks + supine move states with CROSSED input mapping (W = toward
  the head = body-backward → plays flipped walk_back; A/D swap).
- **Stage C (cgame)**: supine chase-cam floor-dive fix when aiming up (copy the s_dbnoCamEnv
  eased-override pattern, cg_view.c:620-633); detect supine from legs anim-name prefix.
- H11 residue: flip-abort double-roll (re-latch cooldown ~0.5s between flips) - not yet done.
- Minor: ladder/water prone edge cases (1-line bMustLeave terms), slope ground-align = future
  feature (pre-existing prone parity).

## Verification probes (per the project's measure-first rule)

1. Boot gate: 0 Script Errors after any .st/alias batch.
2. `coop_proneDebug 1`: latch at |off|>110 with ADS, exit <60 or ADS release, yaw settles within
   0.05s of ANIMDONE after A4.
3. `coop_boneDebug 1` while supine firing: action tier 0, head yaw stable (no ±27 flap).
4. Fire-rate: MP40 3s trigger prone vs supine, equal FIREDBG counts ⇒ shared supine shoot OK.
5. DBNO-from-prone: camera above floor, PRONE-EXIT prints with the dbno term.
6. Interrupt sweep per state (reload/rechamber/grenade/switch/pain/kill/DBNO/mount): no frame
   with the body off its back except the flips.
7. `coop_supineMove 0`: WASD velocity = 0; lean keys no impulse.
