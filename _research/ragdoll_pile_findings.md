# Ragdoll "Mangled Pile" — Audit Findings (2026-08-19)

Auditing `openmohaa-hzm/code/cgame/cg_ragdoll.c` + `tr_ragdoll.cpp` against the live symptom:
corpses collapse into a compact, telescoped, limbs-folded-under pile that survived the 14-brace
truss upgrade. All math below was verified numerically with a faithful Python port of the code's
own matrix helpers (`scratchpad/rag_math_check.py`, session 2026-08-19).

## Executive summary

**The pile is not the simulation — it is the render push.** The 15 sim points land in a sane,
sprawled configuration (the equality-brace truss shape-locks them near the death-pose distances),
but `RagPush` composes each channel's rotation as `rot0 * swing * rot0^T * relRot` — two coupled
convention errors: the world-space Rodrigues swing is glued onto the **capture-space** `rot0`
without conjugating through the entity axis (wrong for every corpse with yaw != 0), and the swing
is applied on the **wrong side** of the channel's capture rotation (wrong even at yaw 0 for every
channel twisted relative to its anchor — feet vs calves, hands, fingers, head, clavicles).
Numerically: a 90-degree body swing at entity yaw 90 renders bones **120 degrees** off their true
orientation while every channel POSITION stays exactly correct — mesh segments translated to the
right places but rotated wrongly around them is precisely "body-shaped but telescoped/folded".
The round trip is exact at zero swing, which is why the P1 totem and the seamless arm frame never
caught it; the error grows as the body collapses. Secondary contributors, in order: nearest-point
anchoring mis-slaves limb channels in arms-at-sides/crossed death poses (telescopes the mesh
between diverging limbs); the resolve-hit "resting contact" threshold (1.2u/substep = 150 u/s)
full-stops all velocity including tangential on first floor touch, killing the slide-out that
makes bodies sprawl; and the uniform 2u collision box seats the pelvis at hand height so the
whole body settles into one flat plane. The fix set is small: ~20 lines to correct the push math
(cgame-only), a hierarchy/name-table anchor assignment, a 3-line contact-threshold change, and
per-point radii. Jakobsen's canonical Verlet ragdoll differs from ours mainly in exactly the
places that are broken or missing: orientation extracted from particle triads (not one direction
in a mismatched frame), fat particles with per-part radii, and inequality (push-apart-only)
constraints for joint limits and self-intersection.

**Live discriminator before any code change:** `r_ragdollDebug 1` already prints
`span=(x y z)` at sleep (cg_ragdoll.c:815-825). A sprawled point cloud (one lateral axis 55-75u,
z 8-20u) under a balled mesh confirms Defect 1 in one kill.

---

## (a) Confirmed defects, ranked

### DEFECT 1 — CRITICAL: rotation-push math (the mangle)

**Where:** `cg_ragdoll.c`
- swing build: 659-684 (`RagMat3FromTo(s->restDir[i], dNow, swing)` at 681, `RagMat3Mul(s->rot0[i], swing, rotNow[i])` at 682)
- channel compose: 699 (`RagMat3Mul(rotNow[a], s->relRot[ch], rot)`)
- the false premise, stated in comments: 440-442 ("Entity axis cancels in the round trip") and
  700-702 ("the entity axis cancels because both rot0 and the swing were built in the same
  frame") — **rot0 is capture/model space (TIKI_Orientation, line 332-336); restDir/dNow are
  world space (built from world `pt[]`, lines 396-401, 675). They are NOT the same frame.**

**The math** (row-vector convention, `v' = v*M`, verified against the code's own helpers):

Let `E` = entity axis (AnglesToAxis of lerpAngles, line 321), `R_ch` = channel ch's capture
(model-space) rotation, `R_a` = its anchor sim bone's, `S` = the world-space Rodrigues swing
taking the anchor's capture parent-direction onto its simmed one.

- A bone's world rotation is `W = R * E` (model axes rows, each mapped to world by E).
- The sim swings the anchor in WORLD space: `W_a_new = W_a0 * S = R_a E S`.
- Rigid slaving (`W_ch = Rel * W_a`, `Rel = W_ch0 * W_a0^T = R_ch E E^T R_a^T = R_ch R_a^T` —
  the entity axis cancels in the *relative* rotation, which is likely where the comment's claim
  came from) gives the true new world rotation `W_ch_new = R_ch R_a^T R_a E S = R_ch E S`.
- The bridge wants MODEL-space matrices (renderer re-composes with E at draw), so the correct
  push is:

  ```
  pushed_correct = W_ch_new * E^T = R_ch * (E * S * E^T)        // world swing conjugated into capture space
  ```

- The code pushes:

  ```
  pushed_code = (R_a * S) * (R_a^T * R_ch)                       // lines 682 + 699
  ```

Both reduce to `R_ch` when `S = I` — exact round trip (verified to 1e-6 degrees), which is why
the P1 totem, the arm-frame push, and every capture-freeze check passed. For `S != I` they
diverge with **two independent error components**:

1. **Frame mismatch** (`R_a`-conjugation instead of `E`-conjugation). Even for the 15 sim bones
   themselves (`R_ch = R_a`, code = `R_a S`, correct = `R_a E S E^T`): wrong unless `S` commutes
   with `E`. `E` is a yaw (z-rotation); collapse swings are about horizontal axes — maximal
   non-commutation. Worked example (verified numerically): entity yaw 90, upper-arm capture
   direction +x in model space (= +y world), sim drops the arm to straight down (-z world).
   True render: arm points down. Code render: **arm still points horizontally (+y world)** —
   the rendered bone axis is `x_model * S * E`, and S (a rotation about world x) fixes x_model.
   Orientation error: **120.0 degrees** (the classic commutator of two 90-degree rotations about
   perpendicular axes).
2. **Wrong-side composition** for slaved channels. At yaw 0 (`E = I`): code = `R_a S R_a^T R_ch`,
   correct = `R_ch S`; equal only when `S` commutes with `R_a^T R_ch` (the anchor-to-channel
   capture twist). Worked example (verified): yaw 0, `R_a = I`, hand twisted 90 about x relative
   to the forearm, forearm swings from +x to -z. True: hand bone points down with the forearm.
   Code: **hand bone points +y — perpendicular to its own forearm.** Error again 120 degrees.
   Feet are ~90 degrees twisted from calves, fingers from hands, "Bip01 Spine"/clavicles from
   their anchors — this component alone mangles every extremity **on every corpse, including
   yaw 0**.

**Positions are immune** — and that is the fingerprint. Line 692's offset path is
`off = relPos * rotNow[a] = (rel_w R_a^T)(R_a S) = rel_w * S`: the `R_a` sandwich cancels
algebraically for positions (verified: exact match in every test case), so world sim points and
channel origins are all correct while every orientation is wrong. Mesh segments in the right
places, spun wrongly around their bones, interpenetrating = "compact, telescoped, limbs folded
under". Error grows with swing angle — bodies look fine at arm and worst at settle — and with
entity yaw, so severity varies corpse-to-corpse. The debug comment at 819-822 anticipated
exactly this discriminator.

### DEFECT 2 — HIGH: anchor-by-nearest mis-slaving

**Where:** `cg_ragdoll.c:417-449` (nearest-point search 427-436).

Every non-sim channel binds to the geometrically nearest of the 15 sim points at capture.
Death animations routinely end with hands at the thighs, arms crossed over the chest, or feet
together:

- arms-at-sides: hand/finger channels sit nearer `L/R Thigh` (pts 11/13) or `Pelvis` (0) than
  their own hand points -> fingers ride the leg; when the sim spreads arm and leg apart, the
  hand-to-finger mesh telescopes across the gap.
- clutch-chest deaths: forearm/hand channels bind to `Spine2` (2) -> the arm mesh folds into the
  torso and stays there regardless of where the arm points go.
- feet together: `Bip01 L Foot`/`L Toe0` bind to `R Calf` (14) -> legs scissor, left foot rides
  the right shin, legs render crossed/folded.
- `Bip01 Spine` (the base spine — a real channel per the LBD table, `ragdoll_vet1_facts.md:135`)
  binds by luck to Pelvis or Spine1.

This corrupts channel POSITIONS (unlike Defect 1) in exactly the "limbs folded under" way, per
death pose. It also amplifies Defect 1: a mis-anchored channel inherits a wholly unrelated swing.

**Correct assignment:** by skeleton hierarchy, not distance — walk each channel's bone-parent
chain until it hits one of the 15 sim bones. The engine already has everything needed:

- `skeletor_c::GetBoneParent(int boneIndex)` — `openmohaa-hzm/code/skeletor/skeletor.cpp:1238-1251`
  (declared `skeletor.h:136`). Returns the parent's bone index **in the same channel/tag index
  space** or -1 for worldbone. Proof the index spaces match: the gl1 debug skeleton
  (`renderergl1/tr_model.cpp:627-637`) feeds the same `i` to both `R_GetTagPositionAndOrientation`
  and `ri.SKEL_GetBoneParent`.
- A plain-C wrapper already exists for the renderer import table:
  `CL_RefSKEL_GetBoneParent(void *skeletor, int boneIndex)` — `code/client/cl_main.cpp:3188-3192`
  (wired at 3365 as `ri.SKEL_GetBoneParent`, declared `renderercommon/tr_public.h:343`).
- cgame can already obtain the skeletor: `cgi.TIKI_GetSkeletor(dtiki_t*, int entNum)` —
  `cg_public.h:379`, filled at `cl_cgame.cpp:792`.

The only missing piece is exposing the wrapper to cgame (3 lines, exact spec in section b), or —
zero-engine-touch alternative — a static name/prefix table for the fixed Bip01 roster (plan
section 0: "17 Bip01 names byte-exact across AA/SH/BT/imported skds").

### DEFECT 3 — MEDIUM-HIGH: resting-contact full-stop kills the sprawl

**Where:** `cg_ragdoll.c:515-519` (`RagResolveHit`).

```c
if (tr->plane.normal[2] > 0.7f && VectorLength(v) < 1.2f) {  // v is per-SUBSTEP displacement
    VectorCopy(pos, s->pt[i]);
    VectorCopy(pos, s->ptPrev[i]);   // total stop: normal AND tangential zeroed
    return;
}
```

`v` is displacement per 8ms substep, so `1.2f` = **150 u/s**. A body falling from standing height
(~50u) impacts at ~283 u/s = 2.3u/substep — barely above the gate — and after one 0.1-restitution
bounce every subsequent floor contact is far below it. Effect: any point that grazes a floor
full-stops, tangential motion included; the friction branch below (0.45 floor scale, line 521) is
unreachable for ordinary contacts. Limbs cannot slide outward as the torso comes down; the body
folds vertically over its first contact points. This is a *pinning mechanism that survived* the
per-substep-collision + pre-lift fixes, and a direct "compact pile" contributor. (Its purpose —
letting bodies reach the 10 u/s sleep gate, line 806 — is preserved at a far lower threshold.)

### DEFECT 4 — MEDIUM: uniform 2u point box flattens the settle profile

**Where:** `cg_ragdoll.c:146-147` (`s_ragPtMins/Maxs = +/-2`), used in pre-lift (365), world
collide (577), mover collide (623).

Every point — pelvis, head, hands — rests 2.25u above the floor. The pelvis/torso mesh has a
~7-9u radius, the head ~5u: torsos render half-sunk and the entire skeleton settles into one
flat plane, reading as a deflated pancake pile even with correct rotations. Jakobsen-style fat
particles (per-point radii) make the floor hold the torso high and the extremities low — the
sprawled-body silhouette — for zero extra traces.

### DEFECT 5 — MEDIUM: pelvis swing ignores roll (unfinished 2-axis basis)

**Where:** `cg_ragdoll.c:661-671`. The pelvis branch builds its swing solely from the spine
direction; `side0`/`side1` are declared and voided (670) — the intended hip-line second axis was
never implemented. A body rolling onto its side barely changes its spine DIRECTION, so the
rendered torso stays un-rolled while the leg/arm points move to rolled positions — limbs render
through the torso mesh. Same class as Defect 1 (render orientation, positions fine) and cheap to
finish with the capture/current triad (spine dir + hip line + cross).

### DEFECT 6 — MEDIUM: push inverts with the death-frame entity placement (plan C13 violation)

**Where:** `cg_ragdoll.c:320-321` (placement stored once at capture), `RagWorldToCapture`
275-283 used at push time (695). The plan (`ragdoll_plan.md` section 2) mandates conversion
"always against the CURRENT frame's entity placement, never the death-frame transform [C13]".
The renderer composes the pushed model-space matrices with the entity's **current** lerp
placement, so inverting with the stored one renders the body offset by however far the server
moved the corpse after arm — and the seed logic (924-948) exists precisely because the origin
DOES move on post-edge snapshots. Small on flat kills, large on balcony/slide deaths (plan
P4-viii). The `E` used for Defect 1's conjugation must be this same current-frame axis.

### DEFECT 7 — LOW: seed jitter is ~50 u/s of per-point velocity noise

**Where:** `cg_ragdoll.c:938-940`. `crandom()*0.4` on `ptPrev` at an 8ms substep is up to
0.4/0.008 = **50 u/s** of random per-point velocity (gravity adds only 6.4 u/s per substep).
The constraint web spends the first frames fighting it — visible initial crumple energy.
0.05-0.1u (6-12 u/s) still de-synchronizes the fall without the snap.

### DEFECT 8 — LOW/EDGE: 180-degree Rodrigues fallback is wrong for rest directions along world y

**Where:** `cg_ragdoll.c:236-243`. The antiparallel fallback returns `diag(-1, 1, -1)` (180
about +y), which maps y -> y: verified numerically, `FromTo(+y, -y)` returns a matrix that sends
+y to **+y**, not -y. Any bone whose capture direction lies within 0.0001 of the world y axis
and swings to antiparallel gets an identity-like swing. Rare (exact antiparallel) but free to
fix: flip about any axis perpendicular to `a` instead of hardcoding y.

**Not defects, checked and cleared:** `RagMat3FromTo` itself is a correct row-convention
Rodrigues (`a*M == b` verified to 1e-9, transpose layout right); `RagMat3Mul/TransMul/RotateVec/
TransRotateVec` are mutually consistent; the position slaving path is exactly correct (by the
cancellation above); Hook A/B in `tr_ragdoll.cpp` faithfully copy 3x4s and serve the documented
orientation contract; the accumulator/substep scheme matches the plan; the 14+14 equality truss
does hold the point cloud (28 constraints on 45 DOF, shape-locked to death-pose distances) —
which is itself evidence the pile is the mesh, not the points.

---

## (b) Recommended fix set (concrete)

### FIX 1 — correct the rotation push (Defect 1 + 5 + 8) — cgame-only, ~25 lines

In `RagPush`, build the world swing per sim point as today, conjugate it once per point into
capture space with the entity axis, and compose it on the RIGHT of each channel's own capture
rotation. `relRot` becomes dead state (delete it and its capture-time fill at 443-448); the
`relPos` path is already correct and stays untouched.

```c
static void RagPush(ragSim_t *s)
{
    static float mat[RAG_MAX_CH][3][4];
    float        Sworld[3][3], tmp[3][3], Scap[RAG_PTS][3][3];
    const float (*E)[3] = (const float (*)[3])s->entAxis;   // row-vector rotation, orthonormal
    ...
    for (i = 0; i < RAG_PTS; i++) {
        int p = s_ragBones[i].parent;
        if (p < 0) {
            // pelvis: full triad (finishes the dead side0/side1 intent) - spine dir + hip line
            vec3_t f0, s0, u0, f1, s1, u1;
            float  B0[3][3], B1[3][3];
            VectorCopy(s->restDir[1], f0);                       // capture spine dir (world, unit)
            VectorSubtract(s->pt[13], s->pt[11], s1);            // current hip line R-L
            VectorSubtract(/* capture hip line, store at capture as s->hipDir0 */, s0);
            // Gram-Schmidt both triads: u = normalize(cross(f, side)); side = cross(u, f)
            RagBuildTriad(f0, s0, B0);  RagBuildTriad(f1norm, s1, B1);
            RagMat3TransMul(B0, B1, Sworld);                     // S = B0^T * B1 (rows are world vectors)
        } else {
            vec3_t dNow;
            VectorSubtract(s->pt[i], s->pt[p], dNow);
            if (VectorLength(dNow) < 0.01f) { RagMat3Identity(Sworld); }
            else { VectorNormalize(dNow); RagMat3FromTo(s->restDir[i], dNow, Sworld); }
        }
        RagMat3Mul(E, Sworld, tmp);                              // E * S
        RagMat3MulTrans(tmp, E, Scap[i]);                        // (E*S) * E^T  -> capture-space swing
        RagMat3Mul(s->rot0[i], Sworld, rotNow[i]);               // keep for the (already-correct) relPos path
    }

    for (ch = 0; ch < s->count && ch < RAG_MAX_CH; ch++) {
        int a = s->anchor[ch];
        ...position path unchanged (lines 692-698)...
        // rotation: pushed = R_ch0 * (E S E^T)   [replaces line 699]
        float chRot0[3][3];   /* rows = s->mat0[ch][r][0..2] */
        RagMat3Mul(chRot0, Scap[a], rot);
        ...
    }
}
```

New 6-line helper `RagMat3MulTrans(a, b, out) // out = a * b^T`, mirror of `RagMat3TransMul`.
For FIX of Defect 8, in `RagMat3FromTo`'s antiparallel branch build the flip about an axis
perpendicular to `a` (pick the smallest component axis, cross, normalize, Rodrigues with c=-1)
instead of `diag(-1,1,-1)`.

Correctness invariants to re-verify after the change (all held in the numeric harness):
`S=I` pushes exactly `mat0` (seamless arm); rendered world axis of a swung bone equals
`axis_capture * E * S`; entity yaw sweep 0/90/180 renders identical world results for the same
world sim state.

Note `E` here should be the **current-frame** axis per FIX 4; at parity with today it is
`s->entAxis` and already fixes the mangle.

### FIX 2 — hierarchy anchoring (Defect 2)

Preferred (general): expose the existing wrapper to cgame — engine+cgame ship together, same
protocol as the ent-2048 precedent.

1. `code/cgame/cg_public.h` (+1 line after 454, next to the fork's ragdoll imports at 453-454):
   ```c
   int (*SKEL_GetBoneParent)(void *skeletor, int boneIndex); // HZM coop - ragdoll hierarchy anchoring
   ```
2. `code/client/cl_cgame.cpp` (+2 lines near 839; prototype for the cl_main.cpp:3191 function):
   ```c
   extern int CL_RefSKEL_GetBoneParent(void *skeletor, int boneIndex);
   cgi->SKEL_GetBoneParent = CL_RefSKEL_GetBoneParent;
   ```
3. `cg_ragdoll.c` — replace the nearest-search body of the anchor loop (427-437):
   ```c
   void *skel = cgi.TIKI_GetSkeletor(model.tiki, ns->number); // same skeletor ForceUpdatePose used
   ...
   // hierarchy anchor: walk the bone-parent chain to the first sim bone
   int walk = ch, found = -1, depth;
   for (depth = 0; depth < 32 && walk >= 0; depth++) {
       for (i = 0; i < RAG_PTS; i++) {
           if (s->simChan[i] == walk) { found = i; break; }
       }
       if (found >= 0) break;
       walk = cgi.SKEL_GetBoneParent(skel, walk);
   }
   if (found < 0) { /* keep today's nearest-point search as the fallback for orphan gear bones */ }
   s->anchor[ch] = (byte)((found >= 0) ? found : nearest);
   ```
   Sim channels find themselves at depth 0 (self-anchor preserved); `Bip01` root walks to -1 and
   falls back (nearest = Pelvis in practice); fingers -> hands, feet/toes -> calves, clavicles ->
   neck/spine2, weapon/helmet tags -> their true limb.

Zero-engine-touch alternative (ships in the same cgame.dll as FIX 1): a static prefix table for
the fixed Bip01 roster — `"Bip01 L Finger" -> 7`, `"Bip01 R Finger" -> 10`, `"Bip01 L Foot"/"
Bip01 L Toe" -> 12`, `"Bip01 R Foot"/"Bip01 R Toe" -> 14`, `"Bip01 L/R Clavicle" -> 2`,
`"Bip01 Spine" (exact) -> 1`, `"Bip01" (exact) -> 0`, `helmet/eye/JAW prefix -> 4`,
`tag_weapon* -> 10`; unknown names keep the nearest fallback. Equally correct for the human
roster; the import version additionally future-proofs imported skeletons and can validate this
table with a one-time debug print.

### FIX 3 — contact full-stop threshold (Defect 3) — 4 lines

`cg_ragdoll.c:515`: gate the full stop at ~0.35u/substep (~44 u/s) and stop only the NORMAL
component otherwise, letting the existing friction branch own tangential decay:

```c
if (tr->plane.normal[2] > 0.7f && VectorLength(v) < 0.35f) {   // was 1.2f
    ... unchanged full stop ...
}
```

(With Defect 3's gate lowered the friction path at 521-522 becomes reachable and no other change
is needed; if settling then takes too long, raise the sleep window, not the stop threshold.)

### FIX 4 — per-point radii + current-frame placement (Defects 4, 6)

```c
static const float s_ragPtRadius[RAG_PTS] = {
    7.0f, 7.0f, 7.5f, 4.0f, 5.0f,      // pelvis, spine1, spine2, neck, head
    3.5f, 3.0f, 2.5f, 3.5f, 3.0f, 2.5f, // L/R arm chain
    5.0f, 4.0f, 5.0f, 4.0f              // thighs, calves
};
// per trace: VectorSet(mins,-r,-r,-r); VectorSet(maxs,r,r,r);  (pre-lift, world, movers)
```

And in `RagPush`/`RagWorldToCapture` callers, use the CURRENT centity placement
(`cg_entities[s->entnum].lerpOrigin/lerpAngles -> AnglesToAxis` each push) instead of
`s->entOrigin/entAxis`, for both the inverse mapping and FIX 1's `E`. (Capture-time placement
remains correct for building `pt[]`/`restDir` — only the per-push inverse must track the frame.)

### FIX 5 — fold-limit braces to inequality + softer seed (Defect 7 + sprawl freedom)

In the brace loop (484-496), for the 8 fold-limit braces (table rows 6-13) only push APART when
compressed below ~90% of capture length; keep rows 0-5 (torso box) equality:

```c
if (i >= 6) {
    float lim = s->braceLen[i] * 0.9f;
    if (len >= lim) continue;                 // fold limit: never pull, only stop over-folding
    corr = (len - lim) * 0.5f / len;
} else {
    corr = (len - s->braceLen[i]) * 0.5f / len;
}
```

Bodies can then unfold/straighten past the death pose (sprawl) while still unable to ball.
Seed jitter (938-940): `0.4/0.3 -> 0.08/0.06`.

### FIX 6 (optional polish) — minimum-separation pairs (self-collision)

Jakobsen inequality sticks between symmetric points, run inside the iteration loop after braces —
only push apart, never pull: `(12,14) min 6u` knees/calves, `(7,10) min 5u` hands, `(6,9) min 5u`
forearms, `(4,0) min 16u` head-pelvis, `(7,2)/(10,2) min 6u` hands-torso. Same solver form as the
braces with the `len < minLen` gate. With the truss in place this is robustness, not the cure.

**Suggested landing order:** FIX 1 alone should visibly transform the corpses (worth a solo live
look at yaw-varied kills); then FIX 3 + FIX 5 (sprawl); then FIX 2 (pose-dependent telescoping);
then FIX 4; FIX 6 last. All except FIX 2's preferred variant are cgame.dll-only.

---

## (c) What Jakobsen does differently that matters here

Reference: Thomas Jakobsen, "Advanced Character Physics" (GDC 2001; the Hitman: Codename 47
ragdoll). Same foundation as this system — position Verlet, stick constraints solved by
Gauss-Seidel relaxation, collision as projection — but four deltas map directly onto the pile:

1. **Orientation comes from particle triads, not a single swung direction.** Jakobsen renders
   limbs by building a full basis from the particles themselves (two points per rigid part plus
   a tracked perpendicular, or 3-4 point tetrahedra): the render matrix is *derived in world
   space from world-space points*, so a capture-frame/world-frame mismatch like Defect 1 cannot
   exist — there is no capture-space rotation to contaminate. Our swing-only reconstruction is
   fine (and cheaper) once the frames are conjugated correctly, but the pelvis/torso needs his
   triad treatment (FIX 1's pelvis branch) because a single spine direction cannot encode roll.
2. **Fat particles.** His particles/body parts carry volume against the environment (sphere or
   capsule per part). Per-part radii are what keep a settled body's torso above its hands and
   stop the one-plane pancake (our uniform 2u box, Defect 4).
3. **Inequality constraints — enforced only when violated.** He is explicit that joint limits
   and self-intersection are best expressed as min-distance sticks that only push apart, while
   rigid shapes use equality sticks on a *triangulated* structure. Our truss got the
   triangulated-equality half right (torso box) but expresses fold limits as equality too, which
   freezes joints at their death angles instead of merely capping the fold (FIX 5), and we have
   no self-intersection pairs at all (FIX 6).
4. **Friction by prev-position manipulation, not velocity zeroing.** His resting contact scales
   the tangential component via the projected previous position; motion dies from friction over
   frames, letting parts slide outward before settling. Our 150 u/s total full-stop (Defect 3)
   is the opposite — it beats his approach to sleep but at the cost of the sprawl.

Also from that era's particle ragdolls and still cheap today: per-bone ground offsets (identical
to fat particles in effect), heavy extra damping only once average speed is near the sleep gate
(instead of aggressive full-stops throughout), and low relaxation counts (he shipped Hitman with
~1 iteration; our 6 with 28 constraints is comfortably stiff — stiffness is not our problem).

---

## (d) Quick-wins table (impact on the pile look / effort)

| # | Change | Impact | Effort | Notes |
|---|--------|--------|--------|-------|
| 1 | FIX 1 rotation-push conjugation + side | Transforms the whole look | ~25 lines cgame | The mangle itself; verified 120-deg worst-case error |
| 2 | FIX 3 contact full-stop 1.2 -> 0.35 | High (restores slide-out sprawl) | 1 line | Pinning mechanism that survived the earlier fixes |
| 3 | FIX 5 fold braces -> inequality | High (bodies unfold naturally) | ~8 lines | Keeps anti-ball guarantee |
| 4 | FIX 2 hierarchy/name-table anchors | Medium-high, pose-dependent | ~25 lines (+3 engine) | Kills crossed-limb telescoping |
| 5 | FIX 4 per-point radii | Medium (silhouette: torso high, hands low) | ~15 lines | Zero extra traces |
| 6 | FIX 1 pelvis triad (roll) | Medium | ~15 lines | Part of FIX 1's loop |
| 7 | FIX 4b current-frame placement | Medium on falls, low on flat kills | ~10 lines | Plan C13 compliance |
| 8 | Seed jitter 0.4 -> 0.08 | Low (softer first frames) | 1 line | 50 u/s -> 10 u/s noise |
| 9 | FIX 6 min-separation pairs | Low with truss present | ~20 lines | Robustness vs interpenetration |
| 10 | FromTo 180-deg fallback axis | Edge-case only | ~6 lines | Wrong for rest dirs along world y |

Verification harness: `scratchpad/rag_math_check.py` (session scratchpad) ports the code's exact
matrix helpers and reproduces every number above; re-run it against any reformulation before
building.
