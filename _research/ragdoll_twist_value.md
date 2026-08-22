# Ragdoll — is bone-twist inheritance worth building?

**Lens:** value, not mechanism. Is the frozen bone twist worth a build, and worth it *now*?
**Date:** 2026-08-20 · **Mode:** read-only against HEAD. Every claim carries a `file:line` or a
measured number. Where a research document and the code disagreed, the code won and the document
is named. Where I re-derived a number it says so; where I inferred, it says **inferred**.

---

## 0. VERDICT UP FRONT

| | |
|---|---|
| **Build the general frame chain now?** | **No.** |
| **Build the cheap partial now?** | **No** — and the partial named in the brief (forearm + shin) is the *wrong two bones*; see §3.2. |
| **Defer?** | **Yes,** to the trigger the prior art already wrote down and that I can now put a number on. |
| **The number that decides it** | Across **52 corpses** in today's live settle session, the body's total rotation since capture was **median 5°, p75 11°, p90 18°, max 84°** (`ragdoll_r12_session_swing.log`, `rot=` field). The frozen-twist error is **bounded above by that angle, exactly** (§1.3). Half of all corpses can be off by at most 5°. |
| **Where the next build should go** | Two things ahead of it, in order: **the blood pool that stamps 1.35 s and one body-length before the corpse comes to rest**, then **physics owning the fall**. §4. |
| **Strongest counter to my own verdict** | 1 corpse in 52 rotated **84°**, and on that body a bone lying along the rotation axis renders up to 84° rolled — a ~10 u shear at the waist, ~38 px at 300 u. If the user's eye lands on that corpse, "the torso is twisted" is exactly what they will say, and they have said it once already (`bug-1981`). §5.3. |

---

## 1. WHAT IS ACTUALLY FROZEN — re-derived from HEAD

### 1.1 The push, as it stands today

`RagPush` (`openmohaa-hzm/code/cgame/cg_ragdoll.c:1819`) builds one rotation per sim point:

- pelvis (`parent < 0`) → `RagBodyRotation` (`:1861`), the **full** smoothed anatomical triad
  (spine direction + hip line), i.e. a real 3-DOF frame including roll (`RagRawFit`, `:1217-1231`);
- every other bone → `RagMat3FromTo(ref, dNow, S)` (`:1877`), Rodrigues' **minimal** rotation
  (`:556-609`), which by construction adds **zero** rotation about the bone's own axis.

Each channel is then pushed as `mat0[ch] * conj[anchor]` (`:1904-1910`), with
`conj = Ecap·S·Enow^T` (`:1883-1885`). The renderer stores those matrices **absolutely**, per
channel, into the bone cache — `R_RagdollApplyToCache` (`renderergl1/tr_ragdoll.cpp:161-175`)
writes `cache[i].matrix` element by element with no parent composition anywhere. **There is no
hierarchy at render time.** Whatever cgame writes is the bone's final world orientation. So a
bone's roll is whatever `RagPush` gives it, and `RagPush` gives it the capture roll, forever.

Confirmed. That is the defect as stated in the brief and in
`_research/ragdoll_joints_design.md:78-87`.

### 1.2 But the sim has no twist to inherit *from*

This is the fact that sizes the whole question, and it is not in the brief.

The simulation is 17 point masses (`RAG_PTS`, `:59`) with distance constraints. **A point has no
orientation.** Nothing in `RagStep` (`:1483`), `RagLimitSweep` (`:1410`), `RagSelfCollide`
(`:668`) or `CG_RagdollImpulse` (`:1963`) produces an angle about a bone's long axis, because
there is no such state to produce.

So "inherit twist" cannot mean *simulate* pronation. `ragdoll_joints_design.md:86-87` says this
plainly and it is correct: *"A limp forearm has no twist source of its own; its roll is entirely
the humerus's roll."* Twist inheritance is a **redistribution**: it takes roll that already exists
at the root of the chain and carries it downward. Its total budget is therefore capped by the
root's rotation — and the root's rotation is measured (§2.1).

There is exactly one exception, and it matters for §3: the **chest** has a roll that is genuinely
observable, because the shoulder sockets `pt[5]`/`pt[8]` are simulated points. That is why
`ragdoll_joints_design.md:262-265` gives bone 2 its **own** anatomical triad rather than
inheriting one. The chest is not a twist-inheritance case at all; it is a second root.

### 1.3 The exact size of the error, in closed form

Let the body undergo rigid rotation `R` = (axis `â`, angle `θ`) after capture. For bone *i* with
captured direction `d̂`, `R` factors uniquely as `swing ∘ twist` about `d̂`, and
`RagMat3FromTo(d̂, R·d̂)` **is** that swing. The rendered orientation is therefore wrong by exactly
the twist:

```
tan(φ/2) = tan(θ/2) · (â · d̂)      →    φ = 2·atan( tan(θ/2) · cos ψ )
small θ:  φ ≈ θ · cos ψ                  ψ = angle between the rotation axis and the bone
```

Sanity: θ = 84°, cos ψ = 1 → φ = 2·atan(tan 42°) = 84° (a bone lying **along** the axis loses the
whole rotation). θ = 18°, cos ψ = 0.5 → φ = 9.06°. cos ψ = 0 → φ = 0 (a bone **across** the axis
is rendered perfectly by today's flat push).

Two consequences worth stating because they cut against the intuition in the brief:

1. **The error is bounded by, and usually well under, the body's own rotation.** It cannot exceed
   it. There is no accumulation term that grows down the chain faster than the swings feeding it.
2. **A limb whose parent swings is *not* automatically rolled.** The swing axis of a minimal
   rotation is perpendicular to the bone it rotates. So when a humerus swings, the roll it would
   hand a *straight* forearm is `cos ψ = 0` — **zero**. The forearm only inherits roll when the
   elbow is bent far enough to put the forearm near the humerus's swing axis. The brief's example
   ("a forearm that cannot roll palm-up as the arm falls") is the corner of a corner.

---

## 2. WHAT THE PLAYER WOULD ACTUALLY SEE

### 2.1 The measurement

`_research/ragdoll_r12_session_swing.log` (2026-08-20 18:37, the current settle branch, 52
`sleep-rot` lines, all `branch=settle`):

| instrument | meaning | min | med | p75 | p90 | max |
|---|---|---:|---:|---:|---:|---:|
| `rot=` | total body rotation since capture (`:2518-2528`) | 0° | **5°** | 11° | 18° | **84°** |
| `drift=` | mean per-point deviation from the rigidly-refitted authored pose | 0.0 u | **0.9 u** | 1.5 u | 1.9 u | 4.4 u |
| `swing=` | how far a **shot** bone rotated after the bullet (`:2388-2400`) | 0° | 0° | 10° | 16° | **74°** |
| `after=` | EF_DEAD → server park, i.e. the authored death anim's length | — | **1353 ms** | — | 2749 ms | 2850 ms |
| `capspan` z | vertical span of the captured pose | — | **8 u** | — | — | 31 u |

`rot > 20°`: **3 of 52**. `rot > 30°`: **1 of 52**. `capspan` z median **8 u** means the corpse is
already **flat on the ground** when physics takes over — which is exactly what the settle branch
is for (`bug-1965`), and exactly why the rotations are small.

### 2.2 Translating that into pixels

The visible cue is *not* the bone rolling — a sleeved forearm is near-cylindrical and its texture
rotating about its own axis is invisible at this fidelity. The visible cue is the **seam**: where
a rolled parent meets an unrolled child, the skin weights shear by chord `2·r·sin(φ/2)`, with `r`
from the anatomical radius table (`:290-301`: pelvis 7.0, spine2 7.5, thigh 5.0, upperarm 4.0,
forearm 3.0, calf 4.0, hand 2.5, foot 3.0).

At `fov` 80 (`client/cl_main.cpp:4194`, `cgame/cg_main.c:243`) on a 1920-wide viewport the scale
is `1144/d` px per unit. Taking the **worst** seam in the body — pelvis↔spine2, r ≈ 7.5:

| body rotation | seam shear | @100 u | @300 u | @600 u |
|---|---:|---:|---:|---:|
| **5°** (median corpse) | 0.65 u | 7 px | **2.5 px** | 1.2 px |
| **18°** (p90 corpse) | 2.35 u | 27 px | **9 px** | 4.5 px |
| **84°** (1 of 52) | 10.0 u | 114 px | **38 px** | 19 px |

**Read this honestly in both directions.** The median corpse is 2-3 px of smooth shear at normal
looting distance — genuinely invisible, and no amount of "the user notices things" changes that,
because a smooth gradient across a limb has no reference edge to be judged against. A HUD bar
overflowing by a few pixels is detectable precisely because it has a hard edge next to a straight
line; this does not. But the tail is *not* invisible: the 84° body is a visibly broken waist, and
the user has already reported this class of artifact once, in the exact words *"corpses twist at
the torso"* (`bug-1981`).

### 2.3 The specific situations, named and rated

- **Forearm cannot roll palm-up as the arm falls.** *Rare and near-invisible.* Needs a bent elbow
  **and** a large humerus swing about an axis near the forearm (§1.3). Forearm r = 3.0, so even
  30° of roll is a 1.55 u shear = 5.9 px at 300 u. Fingers ride the hand (16.8 channels per model,
  §5.2), so they move *with* it rather than tearing away from it. **Frequency: effectively only on
  shot corpses.**
- **Shin cannot follow a rolling thigh.** *Already largely fixed, by other work.* Feet as points
  15/16 (`:96-98`; `s_ragDriveChild[12] = 15`, `:130`) gave the shin its own direction today. The
  residual is thigh roll about the shin axis, which needs a bent knee, and the derived knee fold
  brace (`:158-161`, factor 0.34) plus the hip/knee limits keep a settled leg mostly extended.
- **Hand holds its death-pose orientation while the arm swings.** *Real, and the most defensible
  of the three,* because the hand is a leaf (`s_ragDriveChild[7] = -1`, `:113`) driven by the
  incoming forearm segment, so it gets no roll at all. But r = 2.5 u: at 300 u a 30° error is
  4.9 px, and a settled hand is usually against the ground or the body.
- **The one that is actually visible: the waist.** The pelvis gets the full body rotation
  (`:1861`); spine1/spine2 get pure swings. Any body rotation about the spine's own axis is
  therefore rendered *entirely* at the pelvis and *not at all* in the chest. This is the largest-
  radius seam in the model (7.0 → 7.5) and the only place where the p90 corpse crosses into
  visibility.

### 2.4 The precedent nobody should skip

`ragdoll_joints_design.md:113` — its own literature table — records Jakobsen's Hitman ragdoll, the
canonical shipped ragdoll of this exact era using this exact technique, as *"stick figures …
rotation around limb length axis not simulated"*, relying on the animation skeleton for joint
plausibility. The 2000-era game that invented this method shipped with the identical hole, on
comparable models, and it was never the thing anyone noticed.

---

## 3. THE ALTERNATIVES, COSTED

### 3.1 What already shipped, and how much of the benefit it took

`s_ragDriveChild` (`:106-133`, `bug-1966`) and feet as points 15/16 are the two changes that
mattered, and **both were about bone DIRECTION, not roll**. Direction errors were up to *the full
joint bend*: a bent elbow could not close, a thigh was driven by a hip stub pointing ~90° away.
Those are order-of-90° errors on the primary axis. Twist is an order-of-5° error on the secondary
one. `ragdoll_r11_spec.md:465-466` reached this conclusion in advance — the frame chain *"buys
only twist inheritance now that `s_ragDriveChild` shipped"*. That judgement is now confirmed by
measurement rather than re-asserted.

**Answer to the brief's question: yes, the child-driven driver plus the feet already delivered
most of the visible improvement, and they delivered the part that was an order of magnitude
larger.**

### 3.2 The cheap partial the brief proposes — forearm + shin — is the wrong pair

A targeted rule for the forearm and the shin would have to *invent* the roll it inherits, because
the humerus and the thigh have no roll of their own either (§1.2). You would be propagating a
value that does not exist, and inventing one is the road to limbs that spin
(`ragdoll_joints_design.md:376-385` on why Option B needs twist limits at all). **Cost is not the
problem here; correctness is. Do not build this one.**

### 3.3 The cheap partial that *is* right, if any is ever built: the spine chain

Bones 1-4 inherit the **existing** `s->bodyRot`, which is already computed, already filtered
(`rag_slew` 0.12, `:1275`) and already latched on contact (`:1264-1271`):

```c
} else if (i <= 4 && rag_twistSpine->integer) {
    float  C[3][3], Sr[3][3];
    vec3_t f;
    RagBodyRotation(s, C);                       /* the roll that already exists      */
    RagMat3RotateVec(C, s->driveDir0[i], f);     /* where this bone SHOULD now point  */
    /* ... FromTo(f, dNow, Sr); RagMat3Mul(C, Sr, S);   residual swing on top         */
}
```

Under a rigid body rotation `R` this is **exactly** correct: `bodyRot = R`, `f = R·d0 = dNow`,
`FromTo = I`, `S = R`. Re-derived here, not copied. It fixes the one seam that reaches visibility
(§2.3), and it needs **no** change to `relPos`, **no** change to the `Ecap·S·Enow^T` contract, and
**no** new state — the two caveats the math-vet raised against the design doc's chain
(`relPos` basis, 3×4-vs-float[3][3]) do not attach to it, because it does not touch either.

**Cost:** ~12 lines plus one `CVAR_TEMP`. **But its blast radius is not four bones** — §5.2 — and
that is why the answer is still "not this session".

### 3.4 The general frame chain (`RagBuildFrames`)

`ragdoll_joints_design.md:246-289`. ~55 lines, plus `L_i` / `uLocal` / `W0` captured per bone, plus
a **mandatory** `RagMat3Ortho` on every product (`:290-296` — the renderer does no normalisation,
determinant check or quaternion round-trip; verified at `tr_ragdoll.cpp:161-175`). The doc's
version *also* moves `relPos` from the `rot0` basis to a `W0` basis and deletes the conjugation
sandwich (`:240-243`) — i.e. it rewrites the position path as well. That is precisely the split
the brief warns about, and it is the version the math-vet's caveats attach to.

---

## 4. THE COMPETING ROADMAP, RANKED

Ranked by *visible improvement per unit of risk*, with the risk read off the code.

**0 — Decide the default.** `coop_ragdoll` defaults to **`"0"`** (`cg_ragdoll.c:365-367`, and
deliberately `CVAR_ARCHIVE` rather than `CVAR_TEMP`). It is set to 1 in exactly one place in the
whole tree: `coop_mod/cfg/rag_run.cfg`, the F8 test cfg. It is **not** in `coop_defaults.cfg` and
**not** in `autoexec.cfg`. **No player has seen any of this.** Coverage is now ~90% (42
pending-arms → 38 armed, 1 dropped, 2 refused as buried, 0 gave up, 0 evicted — same log).
Everything below is polish on a feature that is still dark, and twist is polish on the polish.

**1 — Blood pools that spawn before the body settles.** `DropBloodPool()` is called from the kill
handler (`fgame/sentient.cpp:1801`), tracing straight down from the *living* centroid (`:2113`).
The corpse then plays an authored death animation for a **median 1353 ms** (measured, §2.1) with
motion extraction moving the origin the whole time (that is `bug-1964`'s root cause, in those
words), and the pool then **grows for 6-7 s** at that fixed floor point (`:2189-2213`). So on 100%
of kills a hard-edged, high-contrast, growing decal sits where the man was *standing* while the
body lies somewhere else. That is a ground-plane artifact with a crisp edge against a flat
surface — by far the most detectable thing on this list — it is fixable server-side with no
ragdoll math anywhere near it, and it is verifiable from a single screenshot. **Highest value per
unit of risk on the board.**

**2 — Physics owning the fall.** The user's stated original goal, and the prior art's own
precondition for twist. `capspan` z median **8 u** proves physics currently owns nothing but the
drape. This is the one item with a large ceiling. It is also the largest job:
`ragdoll_r11_spec.md:1035-1044` is right that it needs a cross-fade of `goal[]` from the live
animated pose over ~150 ms rather than the at-rest handoff the code has (`rampMs`, `:2332-2334`),
and that the moment of handoff is a *timing* decision to be tuned on a cvar before anything is
made permanent. **This is what twist is waiting for.** Building twist first is building the polish
before the thing it polishes exists.

**3 — Player corpses.** Blocked by **three** independent structural gates, not one:
`cs->eType != ET_MODELANIM` (`cg_ragdoll.c:2822`) while a player is `ET_PLAYER`
(`fgame/player.cpp:2277`); `ns->number < cgs.maxclients` (`:2831`); and the settle trigger
`RagServerParked` requires a non-zero `es->solid` (`:2620-2628`) while `Player::Killed` sets
`setSolidType(SOLID_NOT)` (`player.cpp:3472`). So this is a real feature, not a gate deletion —
but it is the corpse a player stares at longest, and it is *their own*.

**4 — Corpse-versus-corpse collision.** Absent by construction: `RagCollideWorld` traces
`model 0` only (`:1683-1726`) and `RagCollideMovers` queries brush entities only (`:1727-1777`).
Meshes interpenetrate. Partly mitigated by the server's parked 64×64×16 slab (`bug-1965`), which
keeps the *boxes* apart even when the meshes overlap. Real, but soft-edged and far less legible
than #1.

**5 — Twist inheritance.** Median 5° of error, p90 18°, on a feature that is off by default.

**6 — Weapon / helmet separation.** Note this is an *addition*, not a fix: helmets and weapons
already **ride the ragdoll correctly today**, via Hook B (`tr_ragdoll.cpp:174-196`) plus the
`"helmet"` / `"tag_weapon"` / `"tag_weapon_left"` rows of the anchor table (`cg_ragdoll.c:318-322`).
Nothing here is currently broken.

---

## 5. THE RISK-ADJUSTED CASE

### 5.1 One genuinely reassuring structural fact

`RagPush` is a **pure sink**: it reads `s->pt`, `mat0`, `rot0`, `relPos`, `anchor` and
`cent->lerpOrigin/lerpAngles`, writes only a `static` scratch matrix, and calls
`cgi.R_SetRagdollPose` (`:1819-1917`). `RagBodyRotation` is documented and verified as a pure
reader (`:1235-1237`). **Nothing in the push writes back into the sim.**

A rotation-side change therefore **cannot** reproduce `bug-1981`. That failure was a *cycle*:
`RagRotateSet` moved `pt` and `ptPrev` together (`:782-802`), the brace correction moved `pt`
alone, and the two pumped rotational energy. A render-only change has no return edge and no
integrator to feed. This is a structural argument, not a hope, and it is the strongest thing in
favour of eventually building this.

### 5.2 And the risk that is real, and larger than the brief assumes

**A change to `S` moves channel ORIGINS, not just orientations.** In the position path
`off = relPos[ch] · rotNow[a]` with `rotNow = rot0·S` (`:1889`), and `relPos` was stored as
`rot0^T · rel_world` at capture (`:1194`) — so the `rot0` sandwich cancels exactly and the path
reduces to `off = rel_world · S_a` (the code's own comment, `:1821`). Changing how `S` is built
therefore **relocates every channel anchored to that sim point.**

I measured that blast radius. Reusing `docs/tools/ragdoll_channel_census.py`'s pk3 index but
iterating bone records the way the engine does (§7.2), over **1626 human tiks** (median 72
channels, max 87), mean channels per anchor:

| anchor | 0 pelvis | 1 spine1 | 2 spine2 | 3 neck | 4 head | 7 L hand | 10 R hand | all others |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| mean channels / model | 2.00 | 1.00 | 3.00 | 1.00 | 2.02 | **16.76** | **16.76** | ~13 |

So the "cheap" spine partial of §3.3 relocates **7 channels per corpse** — and those 7 include the
clavicles (anchor 2) and, via anchor 4, the **helmet, `tag_head`, `tag_eyes`, `eye*` and `JAW`**
(`cg_ragdoll.c:320-325`). A helmet that shifts 2 u off the skull is not a subtle shear; it is the
kind of thing the user catches at a glance. The full chain of §3.4 additionally re-aims the ~33.5
finger channels through the two hands — **46% of every corpse's channel set**.

That is the honest cost of "cheap": even the smallest correct version of this puts the helmet and
the face on a path with four shipped defects behind it.

### 5.3 The regression test is blind, and would stay blind

`coop_ragdollTest 2` sets `s->freezePose = 1` and `RagPush` then forces `RagMat3Identity(S)`
(`:1857-1859`). With `S = I` **every** construction of `S` is identical, so the freeze drill cannot
distinguish a correct twist chain from a wrong one — the same structural blindness that let
`bug-1966` ship (its own note says exactly this, `:100-105`). Credit where due: the drill *is*
reachable on the shipping settle branch now (`:2717`), which it was not before. It still cannot
see this.

**What would catch it.** A *rigid-rotation drill* has the ground truth the freeze drill lacks:
rotate the whole point cloud `pt[]`/`ptPrev[]`/`goal[]` rigidly by a known `R` about `pt[0]` each
frame with the solver otherwise frozen. Under a rigid rotation the correct pushed matrix for
**every** channel is exactly `mat0[ch]·R` — checkable in code, reported as a max per-bone deviation
in degrees. The flat push fails it by construction, by `φ = 2·atan(tan(θ/2)·cos ψ)`. That
instrument is worth more than the feature: it is the missing motion-side regression test for the
*whole* subsystem, it would have caught `bug-1966`, and it turns "is twist worth it" into a number
measured on the real 1626-model roster instead of an argument.

Because the failure is closed-form, **most of what that drill would report is already in §1.3 and
§2.1** — which is why the honest recommendation this session is neither the feature nor the drill.

---

## 6. VERDICT

**Defer.** Not "no forever". The prior art's own condition is right —
`ragdoll_r11_spec.md:1055-1059`: *"A falling body twists; twist inheritance is what stops forearms,
hands, shins and feet rendering rolled"* — and today's measurement supplies its missing half: a
body that is **already lying down** at capture does not twist, and 52 of 52 corpses were.

**Revisit when any one of these becomes true:**

1. **Physics owns the fall** and `rot=` p90 climbs past ~45°. At that point the *median* corpse
   crosses the visibility threshold of §2.2 instead of one corpse in fifty, and the cost/benefit
   inverts. This is the primary trigger, and it is **measurable from the existing instrument with
   no new code** — just watch `rot=` in the first handoff session.
2. Post-death impacts get strong enough that `swing=` p90 clears ~40° (today 16°), i.e. shooting a
   corpse routinely throws limbs rather than nudging them.
3. A rigid-rotation drill measures a max per-bone reconstruction error above ~25° on the shipping
   branch.

**When it is revisited: build the spine chain (§3.3) first, on its own cvar; never the
forearm/shin rule (§3.2); and build the rigid-rotation drill in the same build, because the freeze
drill will not see either of them.**

---

## 7. FINDINGS FOUND ON THE WAY (not the assignment; all read-only)

### 7.1 The anchor table's Foot/Toe rows were supposed to move when the feet shipped

`s_ragAnchorTable` (`cg_ragdoll.c:312-315`) still reads:

```c
{"Bip01 L Foot",     12},   {"Bip01 L Toe",      12},
{"Bip01 R Foot",     14},   {"Bip01 R Toe",      14},
```

12 and 14 are the **calves** — i.e. the knees. `_research/ragdoll_r8_mohaadata.md:387` says, in
advance and in these words, that adding the feet as sim points 15/16 *"requires moving the four
`Bip01 L/R Foot`/`Toe` rows of the anchor table"*. The feet shipped today; the rows did not move.
**1385 of 1626 human tiks (85%) carry a `Bip01 L/R Toe*` bone.** The foot bone itself is unharmed
(sim channels self-anchor first, `:1158-1163`), so the residual error is only the ankle's rotation
relative to the shin — small on a settled body. But it is a documented prerequisite that was
skipped, which is the same shape of miss as `bug-1981`. **Fix cost: four characters.**

### 7.2 `docs/tools/ragdoll_channel_census.py` iterates bone records with the wrong stride

`skd_bones()` advances a fixed **84 bytes** per bone. The engine advances by the record's own
`ofsEnd`:

```c
boneBuffer = (boneFileData_t *)((byte *)boneBuffer + LongNoSwapPtr(&boneBuffer->ofsEnd));
```

— `tiki/tiki_skel.cpp:440`. Records are variable-length (`skdBone_t` carries `ofsEnd` at +80,
`tools/md5_2_skX/skx_format.h:113-121`). With the fixed stride the names come back shifted
(`"pine2"`, `"rearm"`, `"1 Spine"`, plus non-ASCII garbage) and the reported max union is **72**;
with the engine's own iteration it is **87**. `RAG_MAX_CH` and `RAGDOLL_MAX_CHANNELS` are both 128,
so nothing is currently unsafe — but this tool exists *specifically* to size that array, its wrong
answer happens to equal the live median `channels=72` (which is how it looks right), and it is
currently uncommitted-modified in the tree.

### 7.3 `rot0[i]` is read at `mat0[-1]` on ~15% of the roster

`cg_ragdoll.c:982`: `s->rot0[i][r][c] = s->mat0[s->simChan[i]][r][c];` with no guard, while the
footless path a few lines above deliberately sets `simChan[i] = -1` (`:889`). **241 of 1626 human
tiks (14.8%) have no `Bip01 L Foot` bone**, and `coop_ragdollFeet 0` forces the same path on every
model (`:877-878`). The read lands inside the struct (`entAxis` precedes `mat0`) so it is garbage, not
a fault, and I traced that nothing anchors to 15/16 in that case — step 1 cannot match `ch = -1`,
step 2 sends Foot/Toe to 12/14, and step 3's nearest ties resolve to 12/14 first because `pt[15]`
is bit-copied from `pt[12]` (`:890-891`). **Benign today, but load-bearing on the anchor table
staying exactly as it is** — which §7.1 wants to change. Guard it in the same edit.

---

## APPENDIX — VERIFICATION LOG

| claim | how verified |
|---|---|
| `S` is a pure swing | `RagMat3FromTo` read in full, `cg_ragdoll.c:556-609`; Rodrigues about `a×b`, identity when parallel |
| bone cache is absolute, no render-side hierarchy | `renderergl1/tr_ragdoll.cpp:161-175` read in full; gl2 stated byte-identical by the design doc and **not** re-checked (**inferred**) |
| position path reduces to `rel_world · S_a` | `relPos` stored as `rot0^T·rel` at `:1194`; consumed as `relPos·(rot0·S)` at `:1889` |
| `RagPush` writes nothing to the sim | full read of `:1819-1917`; `RagBodyRotation` pure, `:1235-1237` |
| freeze drill blind to `S` construction | `:1857-1859` (`freezePose` → `RagMat3Identity(S)`) |
| freeze drill reachable on the settle branch | `:2717` |
| `rot=` / `drift=` / `swing=` / `after=` / `capspan` | parsed from `_research/ragdoll_r12_session_swing.log`: 52 `sleep-rot`, 52 `sleep`, 38 `settle-armed`, all `branch=settle` |
| `φ = 2·atan(tan(θ/2)·cos ψ)` | re-derived from the swing-twist quaternion factorisation; checked at θ = 84° / cos ψ = 1 → 84°, and θ = 18° / cos ψ = 0.5 → 9.06° |
| px per unit = 1144/d | `fov` default 80 (`client/cl_main.cpp:4194`, `cgame/cg_main.c:243`), 1920-wide viewport assumed |
| per-anchor channel census | `docs/tools/ragdoll_channel_census.py` index reused, bone iteration corrected per `tiki/tiki_skel.cpp:440`; 1626 human tiks |
| `coop_ragdoll` default 0, set only in the test cfg | `cg_ragdoll.c:365-367`; grep of `hzm-mohaa-coop-mod/**/*.cfg` and `autoexec.cfg` |
| blood pool stamped at kill time | `fgame/sentient.cpp:1801`, downward trace `:2113`, grow chain `:2189-2213` |
| corpse-vs-corpse absent | `RagCollideWorld` `:1683-1726` (model 0), `RagCollideMovers` `:1727-1777` (brush entities) |
| player corpses triple-gated | `cg_ragdoll.c:2822`, `:2831`, `:2620-2628`; `fgame/player.cpp:2277`, `:3472` |
| helmets / weapons already ride the ragdoll | `tr_ragdoll.cpp:174-196`; anchor rows `cg_ragdoll.c:318-322` |
| Hitman shipped without limb-axis rotation | `_research/ragdoll_joints_design.md:113` (its own literature table) |
| prior art's deferral and its trigger | `_research/ragdoll_r11_spec.md:465-466` and `:1055-1059`, both read in full |
| `bug-1981` was a sim-side energy cycle, not a render defect | `.wolf/buglog.json` bug-1981 `root_cause`; `RagRotateSet` `:782-802`; the reasoning block kept in-file above `RagLimitFrames` |
