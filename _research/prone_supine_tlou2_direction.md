# Prone supine aim — the TLOU2 direction

Design lead synthesis, 2026-08-27. Supersedes the "flip = 180 body reversal" premise in
`supine_no_jank_spec.md` A3/A4 and the bug-2129 comment block in `player.cpp`.

---

## 1. What the user is actually asking for

**The mechanic is a supine, over-the-feet firing position.** TLOU2's rule, as its own players
state it: *aim toward the direction your **head** points and you stay belly-down; aim toward the
direction your **feet** point and you end up belly-up.* Rainbow Six Siege ships the same pose with
the same player-facing tell — "if you see your feet in front of you, you're on your back." MGSV
binds it to the identical input we chose (camera behind + hold ADS). Three shipped games converge;
the user is remembering the real thing, and our trigger binding is already correct.

**The geometric ambiguity resolves cleanly.** "Flip onto your back and aim that way" could mean the
threat is past your head or past your feet. It is past your **feet**. If the threat were past your
head you were already facing it and no flip is needed — that reading is vacuous. And you cannot get
an eye behind a rifle pointed back over your own skull.

**Target behaviour, one paragraph.** The player is prone, head north, feet south. He swings the
camera 180° to look south; his body does not move at all. He holds ADS. Over ~0.55 s he rolls about
his own long axis onto his back — **head still north, feet still south, entity yaw unchanged by a
single degree**. Now supine, he curls his head and shoulders up off the ground, brings the rifle
across his chest with the buttstock in the shoulder pocket, and points the muzzle over his own
abdomen and out past his knees at the threat to the south. One knee draws up and the boot plants as
a brace. He can track ±60° about that rearward line using spine twist and head, without the entity
turning. Sweeping wider than that rolls him back onto his belly and hands the arc to the existing
retail prone-turn animation.

---

## 2. Why the current build fails it

There is a theorem underneath both failures, and it is worth stating once because it kills a whole
family of future attempts:

> In every prone source, the head direction **and** the gun direction are both model **+X**. A rigid
> rotation acts identically on both. So `R(gun) = −X` forces `R(head axis) = −X`.
> **No rigid transform of a forward-aiming prone clip can aim backward while keeping the head at the
> same end.** Not for any roll, yaw, untwist value, lift or rate.

- **v1 (`bodyyaw = view + 180`)** had the **correct yaw policy** — body plants, head does not travel
  — paired with a pose whose gun still pointed the old way. Because the flip fires at ~180° off, the
  target equalled the facing the body already held, so nothing rotated *and* the gun pointed
  backwards. User: *"my head and gun are just upside down."* Correct diagnosis of the pose; the yaw
  policy was wrongly blamed and reverted with it.
- **v2 (`bodyyaw = view`, shipped)** has a geometrically **valid end pose** — the X-roll plus 180° of
  entity yaw composes to a 180° somersault about model Y, gun on the crosshair — paired with the one
  motion the user rejects. The destination is fine; the *journey* is a 200 deg/s record-player spin
  about the vertical axis. It also silently relocates the head a full body length to where the feet
  were.
- **Measured and previously unnamed:** the shipped supine pose holds the **rifle upside down**. A
  pure X-roll maps gun-up +Z → −Z. That is a second, separate defect from the aim direction.

**Restoring `+180` on its own reproduces bug-2129 verbatim.** It is the obvious next move and it is a
trap. v1's yaw policy is only correct *once the pose exists*.

---

## 3. Recommended solution

### Primary — rotate the shoulders, not the body (measured, no new assets)

The 180° must be spent in **joint space at the shoulder**, which is anatomically what a supine
rearward shooter does (shoulder flexion sweeping the arms from past-the-head down to at-the-sides).
An FK rig built against `usarmy.skd` and the real retail skcs measures, on top of the existing
X-flipped base, a **180° model-Y rotation of the two clavicle subtrees**:

```
head    ( 53.1, -0.2, 20.1)   UNCHANGED from the flipped base
pelvis  ( -2.6, -3.7, 32.4)   UNCHANGED
gun pos ( 16.5, 15.1, 29.9)   over the abdomen
gun fwd (-1.00,  0.00, -0.01) points at the FEET      <- the aim fix
gun up  (-0.01, -0.05, +1.00) sights UP               <- the upside-down-rifle fix
```

That is the §1 pose, and it is reachable **today** because MOHAA's bone controllers are not what the
brief assumed:

- `SetControllerTag` is called from four ordinary lines (`player.cpp:2837-2840`) and `bone_tag[0..4]`
  is a networked `-8` field — **the tags are re-pointable at runtime**.
- A controller is applied as `m_cachedValue.RotateBy(m)` **after** the parent multiply
  (`skeletorbones.cpp:542-548, 592-598, 644-650`): it rotates that bone **and its whole subtree**, in
  **model space**, pivoting on the bone's own origin. `bone_angles[*][0]` (pitch) is exactly the
  model-Y rotation above.
- There is **no clamp on the player path**. `SetControllerAngles` is a bare copy + `EulerToQuat`
  (`entity.cpp:3600-3610`); the ±30°/15° deadbands are `Actor::` code the Player never runs.
  `MSG_PackAngle` at `bits=-13` gives 0.088° resolution over full ±360, so 180 transmits exactly.
- The clavicles are plain `SKELBONE_ROTATION` bones, children of Spine2.

So: **while supine, re-point `ARMS_TAG` → `Bip01 L Clavicle` and `PELVIS_TAG` → `Bip01 R Clavicle`
and write pitch 180 into both.** `TORSO_TAG` (Spine2) and `HEAD_TAG` stay put and keep carrying aim
pitch. Cost while supine: we lose the Spine1 and Pelvis offsets — acceptable, supine needs neither.
Reversible in one cvar. Applies to **every** supine animation at once — idle, aim, shoot, pain,
death — which is the reason to prefer it over baking first.

**Pair it with v1's yaw policy, restored:** while `m_bCoopSupine`, the body-yaw target is
`view + 180`, i.e. **the body does not move**. `coop_supineFlipRate` (200 deg/s) should be **deleted,
not retuned** — under this design there is no 180° sweep to perform; the sweep *is* the artifact the
user rejected. Ease at 25-40 deg/s for small corrections only, and **enforce a ±60° supine cone**:
past it, roll back to belly and let retail's `rifle_prone_turn_left` cover the flanks. The roll does
not replace the prone turn — it covers the one arc the turn is worst at, directly behind.

Once the pose reads right in-game, **bake it**: extend `skc_flip.py` with a per-bone subtree rotation
`A = M_par · R · M_parᵀ` post-multiplied onto the clavicle quats per frame, regenerate the 3-6
`coop_supine/*.skc`, and drop the runtime controller. Permanent, net-free, survives every anim.

### Fallback if it reads poorly — fix the weapon, concede the pose

If the straightened-arm supine reads as broken (it has no spine crunch, and see §6), fall back to
**reversing only the weapon**: apply 180° of yaw to the weapon's attach orientation, or move it to
the opposite hand tag, and let the flipped arms read as "reaching across the chest." First person
never draws the body at all, so 1P loses nothing. Lower fidelity, near-zero risk, and it makes the
**gun** correct — which is the only thing that *must* point at the crosshair for the mechanic to be
legible. Second fallback, if even that fails: the Ground Branch answer — clamp the prone aim to a
±55° cone and require an explicit input to pivot. Shipped, respected, and honest; but it is the v2
feel the user already rejected.

**Ruled out with measurements, do not revisit:** roll-X ∘ yaw-Z (≡ a somersault: swaps head and feet,
rifle still inverted); splitting the 180 across the spine (4×45°, 5×36°, 6×30° all stand the torso
vertical, z 74-88 vs a supine pelvis at 32, gun still 45-70° skyward); recombining two source anims
(no retail clip anywhere has a torso reversed over its hips — retail expressed prone turning as
hips-swing plus spine **counter**-rotation); a physics solver (Max Payne 3 needed Euphoria).

---

## 4. What it looks like frame by frame

Roll-in, **0.55 s (~16 f @ 30)**, onto the left shoulder — pick the side from the sign of the aim
offset as the code already does. Note the existing `coop_prone_rolll/rollr` run 0.9 s/1.0 s, roughly
double; **retime them**. A flip is fast and committed; at 0.9 s it reads as a slow rotate.

- **f0-f2 (0.00-0.07 s) — the tell.** *Before anything rotates.* Hands release the forward brace,
  weight shifts onto the right forearm, left elbow lifts ~4 u. The head turns toward the threat,
  **leading** the body. This anticipation beat is what sells "he decided to move" rather than "the
  model got rotated," and it is the cheapest item on this list.
- **f2-f6 (0.07-0.20 s) — the hip drive.** Left hip drives up and over; pelvis roll 0 → −95°. The
  **chest lags the hips by ~25°** — retail's own idiom (`rifle_prone_turn_left` counter-rotates the
  spine against the root, pitch 9.6 → −15.6). Right leg straightens into a pivot rail, left knee
  bends ~20° to clear. **Hard contract: the root's world position must not translate more than 3-4 u.
  The footprint not moving is the feature.**
- **f6 (0.20 s) — the crest.** On the side, belly west. The gun crosses the body: elbows tight, rifle
  pulled to the chest, muzzle sweeping N→W. Peak of a ~2 u body lift (match retail's measured 1.8).
- **f6-f10 (0.20-0.33 s) — the settle.** Pelvis completes to −180°. Shoulders continue past the hips
  and begin to curl as the back lands. The head never touches the ground: chin to chest, eyes already
  on the threat.
- **f10-f16 (0.33-0.55 s) — the mount.** Rifle across the chest, buttstock into the left shoulder
  pocket, muzzle over the right hip and past the knees. **Right knee draws up ~25° and the boot
  plants.** Spine crunch settles ~55° off the ground.
- **Settled loop.** Shallow breathing, head steady, gun at body-yaw+180. The ±60° of aim slack is
  absorbed by spine twist and head — **never** by rotating the entity.
- **Roll-out, 0.45 s.** Reverse, and make it *faster* than the roll-in; you get back on your gun
  urgently. Reverse the same shoulder you rolled in on (the pass2 logic already does this, keep it).
- **1P camera.** None of this is visible to the player himself. In first person the mechanic's entire
  legibility is the camera: roll it through the flip and hold ~10-15° of roll while supine. Ship this
  *with* the pose, not after — without it 1P players feel an unexplained handling change and nothing
  else.

---

## 5. Implementation plan

| # | Step | Anchor | Rebuild | Verify |
|---|---|---|---|---|
| 1 | Restore the **v1 yaw policy** while supine: `fTarget = AngleMod(vAngles[1] + 180)` when `m_bCoopSupine`. Delete the `coop_supineFlipRate` boost branch. | `player.cpp:14312-14336` `Player::CoopProneBodyYaw` | game.dll | Prone, spin the camera 180, hold ADS: the **entity yaw must not change**. Watch it in 3P; `viewpos` before/after must match. |
| 2 | **Clavicle controllers.** On supine enter, `SetControllerTag(ARMS_TAG, Tag_NumForName(tiki,"Bip01 L Clavicle"))` and `PELVIS_TAG` → `"Bip01 R Clavicle"`; restore Spine1/Pelvis on exit. In `ApplyCoopBoneOffsets`, when `m_bCoopSupine`, write `bone_angles[ARMS_TAG][0] = bone_angles[PELVIS_TAG][0] = coop_supineArmsAng` (default 180). Gate on `coop_supineArms` (default 0 until proven). | `player.cpp:2837-2840` (tag map), `player.cpp:14696` `ApplyCoopBoneOffsets`, supine enter/exit at `player.cpp:14284/14302` | game.dll | 3P screenshot supine with `coop_supineArms 0` then `1`. Acceptance: **muzzle anti-parallel to the head direction, sights up.** Sweep `coop_supineArmsAng` 0→180 in 30° steps to check the pitch sign convention in-game (at exactly 180 the Quake sign is irrelevant; at intermediate angles it is not). |
| 3 | **Enforce the ±60° supine cone.** Past `coop_supineExit` in either direction while supine, trigger roll-out rather than easing the body. | `player.cpp:14296-14309` | game.dll | Sweep slowly past 60°: must roll back to belly, never spin on the back. |
| 4 | **1P camera roll** through the flip, hold 10-15° supine. | cgame view setup | cgame.dll (+ exe if a new ps field is needed — prefer deriving from the existing supine flag) | 1P: the roll is felt, the horizon tilts, no view snap. |
| 5 | **Retime** `coop_prone_rolll/rollr` to ~0.55 s in, ~0.45 s out; adjust `m_fCoopSupineFlip` windows to match (currently 0.9/1.0). | `player.cpp:14307`, `anims_shared.txt:608-651` | none (mod only) | The roll should not finish before or after the yaw settles. |
| 6 | **Bake** the clavicle rotation into `coop_supine/*.skc` via a new per-bone subtree mode in `skc_flip.py` (`A = M_par · R · M_parᵀ`, post-multiplied per frame; the FK is already written). Then delete step 2's runtime path. | `docs/tools/skc_flip.py` | none | Byte-diff-free re-run; in-game pose identical to step 2 with `coop_supineArms 0`. |
| 7 | **Independent win, not on the critical path:** strip the `Bip01 rot` channel from copies of the action-class skcs. `GetSlerpValue` zeroes `channelActionWeight` for channels absent from the action frame (`skeletorbones.cpp:233-278`), so the root then comes 100% from the legs slot and unflipped retail actions ride the flipped base coherently. Replaces the A7 "hide the torso at weight 0" workaround for putaway/pullout/grenade/rechamber. | `skc_flip.py` (new mode), `supine_no_jank_spec.md` A7 | none | Fire a grenade supine: the torso should play, not vanish, and the body should not wrench 90°. |

Steps 1-3 are one game.dll build. `bone_tag`/`bone_angles` are already-networked entityState fields,
so **no protocol change and no exe ship** — game.dll alone reaches the running client.

---

## 6. What we cannot do without authored animation

Stated plainly, so the remaining gap can be accepted or rejected on purpose:

1. **The spine crunch.** The §4 curl — head and shoulders lifted 50-70° off the deck — is not
   reachable. `TORSO_TAG` can pitch tens of degrees (the shipped tuning is −5° constant + 35° action),
   which buys a partial lift, not a real sit-up. Without it the supine shooter lies **flat on his
   back with the rifle held over his chest** rather than propped on his shoulder blades. This is the
   single largest fidelity gap and it will be visible in 3P.
2. **The left hand will come off the rifle by ~5.7 world units.** Rotating each arm about its own
   clavicle rather than a common pivot separates them (the clavicles sit 2.42/1.89/−4.90 apart; a 180
   doubles the perpendicular components). Clavicles are ROTATION bones — translation comes from the
   skd base offset and cannot be authored from an skc. Either accept it, or hand-correct the left arm
   chain in the baked skc (step 6).
3. **The knee plant, the anticipation beat, and the chest lag.** All three are *animation*, not
   transform. The roll will read as a rigid barrel roll of a stiff body. Retail's own
   `rifle_prone_turn_left` proves the original animators never did it rigidly.
4. **Nobody has ever shipped this cheaply.** ND mocapped a bespoke supine set. Rockstar licensed
   Euphoria. Ground Branch withheld prone entirely for *years* rather than ship a bad one. That is the
   honest cost signal.

**Two corrections to standing assumptions, both measured.** (a) "No Blender/animation authoring
available" is not true — `md5_2_skX.exe` is built at
`openmohaa-hzm/code/tools/md5_2_skX/.build/Release/md5_2_skX.exe` and Blender 5.1 is installed. Gates
are an MD5 importer on Blender 5.x and the tool author's own "generated md5anims might be buggy"
(`NOTES.txt:11`). It is the correct long-term path for items 1-3 above; it is not the first move.
(b) The four bone controllers are **not** clamped spine-only additive levers — they are full-range,
networked, **re-pointable** model-space subtree rotations. That single fact is what makes the aim
direction solvable without new animation, and it is why step 2 is worth doing before anything else.

**Given the history — two rounds burned on the head-vs-feet ambiguity — ship both end poses behind
`coop_supineMode 0/1` for the eyeball test.** v1's `view+180` is the over-the-feet pose; v2's `view`
is the somersault. Both yaw policies already exist in the file. Let the user judge rather than have us
guess a third time.
