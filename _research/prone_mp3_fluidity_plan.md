# Prone Fluidity - Max Payne 3 Model (research, 2026-08-26)

**Ask:** "research how to make that prone system similar to max payne 3 with the movements
for fluidity."

## What MP3 actually does (the kinesthetic contract)

1. **The body follows the aim continuously, never snapping.** On the ground you have a full
   360-degree firing arc; as aim sweeps past the shoulder line the body rolls stomach -> side
   -> back and keeps firing. The roll IS the transition - there is no cut.
2. **Getting down is a motion, not a state change** (shootdodge dive; landing leaves you prone).
3. **Getting up is deliberate** - an explicit animation with real duration.
4. MP3 has **no crawl** - rotation in place only. Our crawl already exceeds it; keep it.

The fluidity is therefore three mechanics: rate-limited body rotation with turning animation,
hemisphere roll to supine, and motion-chained entry/exit.

## What this engine/asset base supports (verified this session)

| Need | Asset / mechanism | Status |
|---|---|---|
| Turn-in-place anims | `rifle_prone_turn_left/right.skc` | ships, unused |
| Supine base pose | `23A825_InjuredCycle` (DBNO idle - proven on player), `pose_c(back)` | **wired** (`coop_supineTest`) |
| Roll transition | `rifle_prone_roll_left/right.skc`, `bang_rollover.skc` | ships, unused |
| Dive | `alert/standtocrouch_dive.skc` (+ pistol variant); t2l4 dive/divepause/getup/diveroll set | ships, unused |
| Get-up | `riflep_floortoknees` - ALREADY aliased (`coop_dbno_floortoknees`), proven | proven |
| Body-yaw override site | `Player::PlayerAngles` after `PmoveAdjustAngleSettings` - the slot-owner site established by bug-2101 | proven |
| Slide chain | `TickSlide` (sprint+crouch slide ships) -> `TickCoopProne` accumulator | proven |
| Supine fire | `coop_prone_shoot` torso (has `first fire` notetrack) over supine legs | mismatched pose, functional |

Missing outright: authored supine AIM/SHOOT poses, an authored front<->back flip. Everything
else composes from shipped assets.

## Current defect the plan must fix first

Body yaw in prone SNAPS: `PmoveAdjustAngleSettings` sets body yaw = view yaw every frame, so a
prone body pivots instantly on its belly (reads as sliding, the opposite of MP3). This is the
same function that owns the bone controllers, so the override goes at the same proven hook.

## Phases (each independently shippable, probe-gated)

**P1 - Rate-limited body yaw + turn anims.** Server-side in `PlayerAngles`: while prone, ease
body yaw toward view yaw at ~120 deg/s instead of snapping (per-player `m_fCoopProneBodyYaw`;
1P never draws the body, so server-only is safe - same argument as the bone offsets). Legs
statemap: `PRONE_TURN_L/R` states play the turn anims while |delta| > 25 deg, idle under 5.
*This is the single biggest fluidity win and carries the least risk.*

**P2 - Rear hemisphere rolls you onto your back.** When the ease target exceeds +/-100 deg,
latch supine: play `rifle_prone_roll_left/right` as the flip (a lateral roll composited with
the yaw flip - whether it READS as rolling over is an eyeball question, honestly uncertain),
then the supine base (already wired). On back: body yaw = view yaw - 180, fire via
`coop_prone_shoot` torso. Exit: roll back when aim returns front, or crouch-press ->
`coop_dbno_floortoknees` get-up. GATE: the `coop_supineTest` pose must pass the user's eyeball
first; then the roll transition gets its own eyeball before the trigger ships.

**P3 - Slide into prone (the shootdodge substitute).** Sprint+crouch already slides. If crouch
is STILL held when the slide ends, seed the prone accumulator so the slide flows straight into
prone - sprint -> slide -> prone in one hold, no new assets. The true dive
(`standtocrouch_dive`) is a later upgrade on the same chain: sprint + prone-tap -> dive anim ->
land prone. Dive anim is notetrack-free (checked class: alert set); movement during the dive
would ride the slide's velocity code.

**P4 - Polish.** Supine pain (death_back last-frame family), diveroll on double-tap direction,
MP3-style deliberate get-up everywhere (replace the instant stand with floortoknees chained to
stand when leaving prone upward).

## Order and gates

P1 -> P3 immediately (all assets exist, no eyeball dependency). P2 strictly behind two eyeball
gates (supine pose, then roll-as-flip). P4 last. Every phase keeps the established probes:
body-yaw delta printed under `coop_proneDebug`, and nothing is reported working until the log
or the user says so.

## Known risks, stated now

- The roll-as-flip composite (P2) may read as a sideways scoot, not a rollover. If it fails the
  eyeball, the honest fallback is a hard cut to supine behind a 0.2s camera-held blend - or an
  authored flip via the validated md5<->skd Blender pipeline (art task).
- Supine firing reuses a stomach-pose torso anim; arms will not match the back pose. Acceptable
  for prototype; authored supine aim is the eventual fix.
- Body-yaw ease must NOT run in DBNO (shares the 20u hull) - gate on m_bCoopProne, the bug-2112
  lesson.
