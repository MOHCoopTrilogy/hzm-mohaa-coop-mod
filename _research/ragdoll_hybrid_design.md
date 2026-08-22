# Animation-Driven / Hybrid Corpses — Competing Design (2026-08-19)

Companion to `ragdoll_plan.md` (the full-physics plan) and `ragdoll_pile_findings.md` (the
render-math audit). That audit fixed the render path — a frozen-sim drill now renders a
pixel-perfect soldier — and the remaining complaint is purely about the SIMULATION's
plausibility. User verdict after 7 rounds: *"bodies continuously fall into unnatural
positions"*, *"doesn't look natural at all, bodies don't fall like that."*

This document argues the opposite thesis to "make the Verlet better": **MOHAA already ships a
30-animation, direction-aware, damage-aware, hit-location-aware, root-motion death system that
looks natural by construction, and our ragdoll throws all of it away at frame 0.** Keep it, and
use physics only where animation cannot go.

---

## 0. Executive summary

**Recommendation: build B + A' + C** — *delay the arm until the authored death animation has
finished and the body has landed, then run the sim as a short shape-matched settle; and take
the full-physics branch only for explosive deaths, gated on the impulse magnitude we already
measure.*

One-sentence justification: **the game's own animators already solved "how does a body fall",
30 different ways with baked root motion and directional selection; the only thing they could
not author is the ground under the body, so physics should own exactly that and nothing else.**

Cost: ~150 lines, **one file** (`cg_ragdoll.c`), **cgame.dll only** — no engine change, no
renderer change, no protocol change, no ship-together constraint. Every import it needs
(`Anim_Time`, `Anim_NameForNum`, `Anim_Delta`, `Anim_Flags`) is already in `cg_public.h:383-393`.

The honest headline, stated up front because it is the strongest argument against the
recommendation: **on flat open ground the first kill will look exactly like vanilla — no
visible difference at all.** That is by design and it is the guarantee: never worse than
vanilla. The visible payoff is confined to bodies on stairs / slopes / sandbags / crates /
ledges / movers, and to grenade kills. See §9 for what changes on the first kill.

---

## 1. The asset inventory — what the game ALREADY does at death

### 1.1 The animation set

Declared inline in `hzm-mohaa-coop-mod/models/human/new_generic_human.tik` lines **1764-2105**
(`$path models/human/animation` at :23 resolves `deaths/x.skc`). The mod overrides that file but
its death block is **byte-identical to vanilla** — the mod adds weapon-anim `$include`s and an
`aihandler.scr` init block, and does not touch the death set.

**30 distinct `death_*` aliases + `diveongrenade_death`.** Durations and root-motion status
(derived from `_research/npc_anims.csv`, the extracted alias catalog):

| alias | dur | RM | | alias | dur | RM |
|---|---:|:--:|---|---|---:|:--:|
| `death_back1` | 1.93 | RM | | `death_grenade_high` | 1.67 | RM |
| `death_back2` | 1.93 | RM | | `death_head_flyforward` | 0.87 | RM |
| `death_back3` | 0.47 | RM | | `death_headpistol` | 1.40 | RM |
| `death_backgrenade` | 1.33 | RM | | `death_knockedup` | 1.27 | RM |
| `death_chest` | 2.13 | RM | | `death_left` | 1.33 | RM |
| `death_choke` | 2.40 | RM | | `death_mortar_flip` | 1.10 | RM |
| `death_collapse` | 1.40 | RM | | `death_mortar_high` | 2.30 | RM |
| `death_crotch` | 1.97 | RM | | `death_mortar_medium` | 2.00 | RM |
| `death_fall_back` | 1.67 | RM | | `death_mortar_twist` | 1.80 | RM |
| `death_fall_to_knees` | 1.73 | RM | | `death_prone` | 0.56 | — |
| `death_frontchoke` | 2.87 | RM | | `death_right` | 1.33 | RM |
| `death_frontcrouch` | 0.67 | RM | | `death_run01/02/03` | 1.07/0.73/0.87 | RM |
| `death_grenade01` | 1.97 | RM | | `death_shoot` | 1.40 | RM |
| `death_grenade02` | 1.10 | RM | | `death_twist` | 1.33 | RM |
| | | | | `diveongrenade_death` | 0.40 | — |

**29 of 31 carry root motion.** Median duration **1.33 s**, range 0.47-2.87 s (the scripted
outliers `death_mortar03` 3.4 s and `open_gate_death` 7.0 s are set-pieces).

Beyond that core set: **16 cover/wall deaths** (`<weapon>_wall_death_left/right`), a scripted
family (`chair_death_forwards/backwards`, `cabinet_hiding_death`, `welding_death`,
`opel_driver_death`, `death_balcony_intro/loop/outtro`, `death_balconyFLAT_intro`,
`death_balconyRAIL_intro`), **13 map-scripted one-off deaths** (`12G508_Death`, `AX_K5_death`,
…), the `_pain_*todeath` chain deaths (`_kneestodeath`, `_floortodeath`, `_crawltodeath`), and
**3 looping corpse holds** `dead_pose1/2/3` (0.8 s, `loop`, from
`deaths/pose_a(leftside).skc` / `pose_b(front).skc` / `pose_c(back).skc` — directional even at
rest). 76 rows carry `category==death` in the catalog.

Flags: **the only flag any death anim carries is `random`** (verified: zero death rows carry
`deltadriven`, `crossblend`, `notimecheck`, `autosteps_*`, `dontrepeate` or `weight`). Crossblend
is set at runtime instead — `anim/killed.scr:56-57` `self.blendtime = 0.3`. Frame commands on
deaths are `client { N bodyfall [scale] }` and `server { N pophelmet }` (7 deaths pop the helmet
at an authored frame).

Missing, worth knowing: **no burning death** (`death_fire` exists only in the orphaned
`models/human/deaths.tik` with an unresolvable SKC), and **no generic fall-from-height death** —
the balcony family is engine-driven (`actor_balcony.cpp`) and map falls are trigger mechanics
(`maps/e1l3/RoofJaunt.scr:1229`).

### 1.2 The selection logic — directional, damage-tiered, hit-location-aware

**The engine never hardcodes a death animation name for actors.** Selection is script-side. The
chain, verified end to end:

```
Sentient::Damage -> EV_Killed (10 args: 1=attacker 2=damage 3=inflictor 4=position
                    5=direction 6=normal 7=knockback 8=dflags 9=meansofdeath 10=location)
                                                          fgame/sentient.cpp:1817-1829
                                                          arg order: fgame/entity.cpp:190-199
  -> Actor::EventKilled            actor.cpp:5538
  -> Actor::DispatchEventKilled    actor.cpp:5516
  -> Actor::DefaultKilled          actor.cpp:5435   ClearStates + SetThink(THINK_KILLED)
  -> Actor::HandleKilled           actor.cpp:5449   deadflag, health=0, EF_DEAD,
                                                    corpse impulse, ExecuteScript(killed.scr)
  -> global/killed.scr                              stashes all 10 args on self.fact
  -> Actor::Think_Killed           actor_killed.cpp:47  -> Anim_Killed()
  -> SimpleActor::Anim_Killed      actor_animapi.cpp:104  DesiredAnimation(ANIM_MODE_NORMAL,
                                                          m_DeathHandler)
  -> m_DeathHandler = "anim/killed.scr"  simpleactor.cpp:113  (per-actor override:
                                          `deathhandler`, simpleactor.cpp:1249; per-think:
                                          `setkilledtype`, actor.cpp:8572)
  -> anim/killed.scr  ->  self setmotionanim <name>   -> Actor::EventSetMotionAnim
                                                        actor.cpp:7154-7183
```

There is **no** `"death"` or `"deathfall"` string anywhere in `code/` for actors. (The only
engine-side directional death selection is for *destructible props*:
`fgame/damagemodel.cpp:171-182` builds `"death_" + str(num)` from an 8-way yaw bucket — proof
the engine authors knew the pattern and deliberately left actors to script.)

`anim/killed.scr` chooses:

- **per-actor override first** (`killed.scr:73-78`): `if (self.deathanim != NIL) { self
  setmotionanim self.deathanim; self waittill flaggedanimdone; end }`. The mod uses this —
  `global/mg42_active.scr:205`, `maps/m3l1b.scr:160,916`, `maps/t1l2.scr:144` all set
  `death_fall_back` via `global/setdeathanim.scr`.
- **explosive** (`self.fact.location == -1`, `killed.scr:86+`): damage `> 75` →
  `death_grenade_high` / `death_backgrenade` / `death_grenade`, plus a 30% `pophelmet`; damage
  `> 50` → the directional quadrant set; else the soft set.
- **directional quadrant** (`killed.scr:83,113-131`): `local.yaw = self GetLocalYawFromVector
  self.fact.direction`, then `-45..45 → death_back`, `45..135 → death_right`,
  `-135..-45 → death_left`, else `death_run`.
- **hit location** (`killed.scr:3-23` documents all 19 codes; `:357+`): head/helmet →
  `death_back` / `death_head_flyforward` / weighted `death_headpistol` `death_twist`
  `death_shoot` `death_fall_to_knees` `death_collapse`, and `self pophelmet` at `:66-70`.

So the answer to "what does the game already do at death" is: **it already does everything a
ragdoll is usually built to do, except conform to the ground.**

> Latent defect spotted in passing (not ours to fix here): `killed.scr` calls `death_back`,
> `death_run` and `death_grenade`, none of which is an exact alias in the live table — only
> numbered siblings (`death_back1/2/3`, `death_run01/02/03`, `death_grenade01/02`) exist, and
> `setmotionanim` → `Anim_NumForName` is an exact match. Worth a separate look.

### 1.3 What our ragdoll does with all of it today: discards it

`CG_RagdollTransition` arms on the **EF_DEAD rising edge** (`cg_ragdoll.c:1203`). Per the chain
above, `EF_DEAD` is set inside `HandleKilled` **before** `killed.scr` runs, and the animation is
not even *requested* until the next `Think_Killed` → `Anim_Killed` (`actor_killed.cpp:47`,
`actor_animapi.cpp:104`). So when the first EF_DEAD snapshot reaches the client, the entity's
`frameInfo` is still the living pose or frame 0 of the death anim. The capture is the pose at
the instant of death — standing, running, or crouched — and from that frame on the entire
authored ~1.3 s fall is replaced by Verlet.

**That is the defect this document is about.** Everything in §1.1 and §1.2 — 30 authored falls,
the yaw quadrant, the damage tiers, the head-shot pool, the `bodyfall` sound frames, the
`pophelmet` frames, the baked root motion — is discarded at frame 0 and re-derived, badly, from
15 particles and 30 distance constraints.

---

## 2. The root-motion question, answered (task item 6)

**Yes. MOHAA death animations carry root motion, the server applies it through full collided
movement, and the corpse origin travels metres during the death.** Three independent lines of
evidence:

1. **Data.** 29 of 31 core death aliases are tagged `root-motion` in the extracted catalog.
   The tik comments say so in plain English: `new_generic_human.tik:1975` *"Fall/fly left and
   slightly back, 1-2 meters"*; `:1945` *"Flies back a meter or two, lands, legs go in the
   air"*; `:1848` *"Fly about 18 feet in the air."*

2. **Engine, server side.** The delta is **baked into the `.skc`** — `TIKI_Anim_HasDelta`
   (`tiki/tiki_anim.cpp:355`) just returns `animData->bHasDelta`, and
   `skelAnimDataGameHeader_s::GetDeltaOverTime` (`skeletor/skeletor.cpp:93-138`) sums the
   per-frame `m_frame[n].delta` between two times, scaled by `load_scale`. Nothing is derived at
   runtime. `Animate::PostAnimate` (`fgame/animate.cpp:686-697`) gates on
   `gi.Anim_HasDelta(tiki, index)` — **not** on the `deltadriven` flag, which is a separate
   speed-driving concept — weight-scales and accumulates it, then `:752`
   `MatrixTransformVector(vFrameDelta, orientation, frame_delta)`. `Actor::DoMove`
   (`fgame/actor.cpp:3930+`) consumes it: in `ANIM_MODE_NORMAL` (which is what
   `Anim_Killed` requests) it becomes `mm.desired_dir` / `desired_speed` into `MmoveSingle` —
   a **full collided, gravity-aware move**, not a teleport, so the body slides along walls and
   steps. Two nuances that matter: only the **XY** component is used (`VectorCopy2D`,
   `actor.cpp:3935`) — vertical motion comes from `MmoveSingle`'s gravity — and `SetMoveInfo`
   copies `velocity` into `mm->velocity`, so **the explosive corpse impulse and the animation
   delta are combined inside the same move**. (`ent->total_delta` is dead code, `#if 0` at
   `g_phys.cpp:307-317` — ignore it.)

3. **Live, already burned us.** `bug-1964`: the push was converting world→model against the
   *capture* placement, and *"MOHAA death anims keep moving the corpse origin after the EF_DEAD
   edge … the mesh rendered offset from its own simulated skeleton by the full post-death
   drift: bodies slid forward, clipped into rocks, and sank through floors while the sim points
   rested correctly on top."* That drift **is** the root motion, measured in anger.

**Consequence for this design: hybrid B and C get much stronger.** The authored fall is not
just a pose sequence, it is a collided translation of the body through the world — the animator
threw the body back two metres and the server slid it along the floor to get there. Letting it
finish costs us nothing and buys us a landing site that is already legal.

It also means the shape-match / spring target must be built against the **current** entity
placement each frame (`cent->lerpOrigin` / `lerpAngles`), exactly as `RagPush` now does at
`cg_ragdoll.c:824-825`. Do that and root motion comes along for free; use the capture placement
and you re-create bug-1964.

### 2.1 …and the server already stops, grounds and freezes the corpse at anim end

The other half of the same finding, and it is what makes Design B's handoff clean.

When the death animation completes, `Actor::AnimFinished` unregisters `flaggedanimdone`,
`killed.scr` ends, and `Actor::FinishedAnimation_Killed` (`fgame/actor_killed.cpp:63-66`) calls
`BecomeCorpse()` and transitions to `ACTOR_STATE_KILLED_END`. Two things follow:

1. **Root motion stops dead.** From `KILLED_END` on, `Think_Killed`
   (`actor_killed.cpp:53-56`) early-returns *before* `PostThink()`, so `UpdateAnim()` and
   `DoMove()` are never called again. No further `frame_delta` is applied, ever.
2. **`Actor::BecomeCorpse` (`fgame/actor.cpp:12468-12547`) grounds and freezes it:**
   ```cpp
   CheckGround();
   if (groundentity)            setMoveType(MOVETYPE_NONE);
   else if (droptofloor(64.0f)) { CheckGround(); setMoveType(MOVETYPE_NONE); }
   else                         setMoveType(MOVETYPE_TOSS);
   ```
   plus `svFlags &= ~SVF_MONSTER`, contents/solid change, `renderfx &= ~RF_SHADOW`.

The animation also **holds its last frame**: `PostAnimate` clamps a non-repeating anim's time at
its length (`animate.cpp:737-743`, `frameInfo[i].time = animtimes[i]`) and cgame is a pure slave
to `entityState.frameInfo[]` (`cg_modelanim.c:341-408`), so the client renders a frozen final
pose. `Actor::DeathEmbalm` (`actor.cpp:5587-5600`) then shrinks the server bbox `maxs.z` by 4
every 0.5 s down to 8 — server-side only, invisible to our world traces.

**So the moment Design B waits for is precisely the moment the server itself declares the death
finished, grounds the body, and stops touching it.** The handoff is not a guess about when the
animation "looks done"; it is the same event the engine uses. It also explains why the
secondary origin-static test in §5.1 matters: `droptofloor(64.0f)` produces one final origin
change at exactly that instant.

---

## 3. Design A — physics-guided animation (powered / blended ragdoll)

The death animation plays normally; the ragdoll runs as a **correction layer**. Pose-matching
springs pull each sim point toward its animated position, strong at death and decaying, so the
body follows the authored motion but bends around slopes, obstacles and stairs and can be
overpowered by a grenade.

### 3.1 Where the animated matrices come from — and the trap

Two candidate sources. **One of them is a trap and must be documented before anyone tries it.**

**A-2 — pose a scratch refEntity and read `cgi.TIKI_Orientation` (looks free — IS A TRAP).**
`RagCapture` already does exactly this once (`cg_ragdoll.c:441-453`), so repeating it per frame
looks like a zero-engine-change win. It is not:

> **Hook B makes the readback circular.** `RE_TIKI_Orientation`
> (`renderergl1/tr_model.cpp:1813`) calls `R_RagdollGetOrientation(model->entityNumber,
> model->tiki, …)` **first** and returns the ragdoll's own pushed pose whenever a slot is armed
> for that entnum. From the first `RE_SetRagdollPose` on, every `cgi.TIKI_Orientation` for a
> ragdolled corpse returns the simulation's output, not the animation. A spring toward that
> target is a spring toward the body's own current position: a fixed point. The corpse would
> freeze at capture and look *stable and completely wrong* — the worst possible failure mode,
> because it looks deliberate.

The dodge: set `model.entityNumber = ENTITYNUM_NONE`. `R_RagdollSlotFor(MAX_GENTITIES-1, …)`
misses (that entnum is reserved and never armed), and `TIKI_GetSkeletor`
(`tiki/tiki_cache.cpp:311-315`) has an explicit `ENTITYNUM_NONE` branch returning a per-TIKI
scratch skeletor. It works — but `R_UpdatePoseInternal` (`tr_model.cpp:1770-1777`) skips its
`skel_index` early-out for `ENTITYNUM_NONE`, so **every tag lookup re-poses the entire
skeleton**: 15 full `SetPose` calls per body per frame instead of one. Functional, 15x the cost.

**A-1 — read back the `animPose` stash (recommended if A is built).** The stash already exists
and is already filled: `R_RagdollApplyToCache` (`renderergl{1,2}/tr_ragdoll.cpp:120-138`) copies
the vanilla `newFrame` into `slot->animPose[]` on every Hook A fill, sets `animPoseValid`, and
nothing ever reads it. Hook A runs **outside** the cull gate (`tr_model.cpp:849-861`), so the
stash is fresh whenever the corpse is in PVS, culled or not. Wiring:

| file | change |
|---|---|
| `renderergl1/tr_ragdoll.cpp`, `renderergl2/tr_ragdoll.cpp` | `qboolean R_GetRagdollAnimPose(int entnum, dtiki_t *tiki, int count, float *out34)` — `R_RagdollSlotFor` + `animPoseValid` guard + memcpy |
| `renderercommon/tr_public.h` | refexport entry beside `SetRagdollPose` (`:189`) |
| `client/cl_cgame.cpp` | bridge assign beside the existing ragdoll wiring (`~:812`) |
| `cgame/cg_public.h` | import beside `R_SetRagdollPose` (`:453-454`) |

~35 lines across 5 files in both renderers. Two hazards:

- **One frame of lag.** `CG_RagdollFrame` runs at `cg_view.c:2928`, *before* entities are added,
  so Hook A's fill for frame N lands after the read. Negligible at 16 ms, but say so.
- **Space conversion, and it has burned us once.** `animPose` holds `newFrame->bones[i]` =
  **raw skeletor space**. `mat0` / the push table are **TIKI-orientation space**,
  `(raw + load_origin) * load_scale` (`tiki/tiki_tag.cpp:108-110`, `cg_ragdoll.c:446-447`
  dividing out `e.scale`). The conversion into the table's space is therefore
  `tiki = (animPose_offset + load_origin) * load_scale` — the exact inverse of Hook A's
  `cache.offset = mat/load_scale - load_origin` (`tr_ragdoll.cpp:153-155`). Getting it backwards
  reproduces **bug-1963**'s double-scale defect: human tikis carry `load_scale` 0.52, so every
  bone renders at 52% offset — a uniform compaction into a pile, from the first frame.

### 3.2 The spring math in a Verlet integrator

Per sim point, per substep, the animated world target is

```
animCap[i]   = (animPoseRaw[simChan[i]].offset + tiki->load_origin) * tiki->load_scale
animWorld[i] = cent->lerpOrigin + axisNow * (animCap[i] * s->scale)     // CURRENT placement
```

Two formulations:

**(a) PBD projection — recommended.** After the constraint iterations in `RagStep`, before the
collision pass:

```c
VectorSubtract(animWorld[i], s->pt[i], d);
VectorMA(s->pt[i], w, d, s->pt[i]);        // w in [0,1] per substep
```

This is the Position Based Dynamics attachment constraint (Müller et al. 2007) and is
unconditionally stable for any `w <= 1`. It leaves `ptPrev` alone, so the pull also *injects*
velocity — desirable: the body inherits the animation's motion. Collision runs after and has the
last word, which is exactly the property we want (the floor beats the animation).

**(b) Force / PD form — the literal "powered ragdoll".** In the integrate step:

```c
a = ks * (animWorld[i] - pt[i]) - kd * vel[i];
pt[i] += a * dt * dt;
```

Faithful to Havok `hkpPoweredChainData` / PhysX articulation drives and to Zordan's PD
trackers, but conditionally stable: at `dt = 8 ms` you need roughly `ks * dt^2 < 2`, i.e.
`ks < 31250`, with `kd ≈ 2*sqrt(ks)` for critical damping. More knobs, more ways to explode.
Use (a).

### 3.3 Blend-out schedule

```
w(t) = wFloor + (w0 - wFloor) * clamp(1 - (t - tHold) / tFade, 0, 1)
w0 = 0.90, tHold = 150 ms, tFade = 900 ms
```

`tHold` gives full animation authority through the handoff so there is no pop. Two variants:

- **`wFloor = 0`** — the textbook decaying blend. The body ends under pure Verlet.
- **`wFloor ≈ 0.25`** — a *persistent* correction layer. The animation stays the rest pose the
  physics relaxes toward, forever.

**This distinction is the whole argument against A, see §7.**

Impulse override: drop `w` to 0 permanently when the seed speed exceeds the explosion gate
(§6) — a grenade must be able to win.

### 3.4 Literature

Zordan, Majkowska, Chiu & Fast, *"Dynamic Response for Motion Capture Animation"*, SIGGRAPH
2005 — PD controllers track mocap on a physical model through an impact, then blend back to
kinematic; the canonical citation for exactly this. Zordan & Hodgins, *"Motion capture-driven
simulations that hit and react"*, SCA 2002 (the precursor). Shapiro, Pighin & Faloutsos,
*"Hybrid control for interactive character animation"*, PG 2003. Industry: Havok's powered
ragdolls / `hkpPoweredChainData`, NaturalMotion Euphoria's behaviour-driven actuation,
PhysX articulation drives, and the ubiquitous "partial ragdoll" / "blend from animation to
ragdoll" of the mid-2000s (GTA IV, Uncharted, the Source engine's `ragdoll blend`). Müller,
Heidelberger, Hennix & Ratcliff, *"Position Based Dynamics"*, VRIPHYS 2006 / JVCIR 2007 — the
projection form in §3.2(a).

---

## 4. Design A' — shape-matched settle (the cheap A that does the same job)

**The synthesis, and the one actually recommended.** Instead of tracking the *live* animation
frame by frame, take the pose the animation has *already produced* as the goal shape, and let
the physics relax toward it — rigidly re-fitted to wherever the body currently is.

This is **shape matching** (Müller, Heidelberger, Teschner & Gross, *"Meshless Deformations Based
on Shape Matching"*, SIGGRAPH 2005). Per substep, after the constraint iterations:

1. Rest cloud `pt0[15]` = the capture world positions (one `VectorCopy` loop added to
   `RagCapture`).
2. Recover the body's rigid rotation `R` from capture to now.
3. Goal `g[i] = anchor + (pt0[i] - pt0[anchor]) * R`.
4. `pt[i] += alpha * (g[i] - pt[i])`.
5. Collision runs after, and wins.

**Recovering `R` costs nothing, because the code already computes it.** `RagPush` builds the
pelvis rotation from a two-axis triad — spine direction plus hip line — at
`cg_ragdoll.c:854-858`:

```c
VectorSubtract(s->pt[1], s->pt[0], spineNow);
VectorSubtract(s->pt[13], s->pt[11], hipNow);
if (RagTriad(s->restDir[1], s->hipDir0, T0) && RagTriad(spineNow, hipNow, T1)) {
    RagMat3TransMul(T0, T1, S);      // world S: capture basis -> current basis
}
```

That `S` **is** the rigid rotation, in the file's own row-vector convention, using helpers that
have already been math-vetted. Anchor on the pelvis (`pt[0]`) rather than the centroid and the
whole addition is ~15 lines:

```c
// A' shape-match: pull the cloud back toward the authored pose, rigidly re-fitted.
// S is the pelvis triad rotation already built in RagPush; hoist it into RagStep.
for (i = 0; i < RAG_PTS; i++) {
    vec3_t q, g, d;
    VectorSubtract(s->pt0[i], s->pt0[0], q);
    RagMat3RotateVec(S, q, g);            // row-vector: out = q * S
    VectorAdd(s->pt[0], g, g);
    VectorSubtract(g, s->pt[i], d);
    VectorMA(s->pt[i], alpha, d, s->pt[i]);
}
```

A least-squares fit (Kabsch / polar decomposition of `A[r][c] = sum_i q_i[r] * p_i[c]`, Higham
iteration `M <- 0.5 (M + (M^-1)^T)`, 4 iterations, `det(M) < 1e-6` guard) is strictly better
conditioned and can replace the triad later if the triad proves noisy. It is not needed for the
first build, and the triad has the nice property of being **the same rotation the renderer
already uses for the pelvis**, so the goal pose and the rendered orientation cannot fight.

**Why A' beats A on every axis that matters here:**

| | A (track live anim) | A' (shape-match the captured pose) |
|---|---|---|
| engine change | 5 files x 2 renderers, ship-together | **none** |
| Hook B circularity | must be dodged | **cannot occur** (no tag readback) |
| frame lag | 1 frame | **none** |
| `load_scale` space conversion | required, burned us in bug-1963 | **none** — `pt0` is already world |
| new math | spring + readback | **reuses `RagTriad` / `RagMat3RotateVec`** |
| what the settled pose is | pure Verlet if `wFloor = 0` | **the authored pose, always** |

**Where A genuinely beats A':** A reproduces the authored *motion* — the stagger, the
knee-buckle, the arms coming up — while colliding. A' only reproduces the authored *shape*,
rigidly transported. See §7 for why that gap does not justify the cost **yet**.

---

## 5. Design B — anim-then-settle

Play the authored death animation to completion untouched (guaranteed natural, guaranteed
never-worse-than-vanilla), then hand the **final** pose to the physics for a short settle:
drape onto slope/stairs/props, fall off a ledge, re-settle when a mover pushes it.

### 5.1 The handoff — how the client knows the animation is done

Everything needed is already networked and already imported. `frameInfo[].time` is a delta field
(`qcommon/msg.cpp:1344-1345`, 15 bits, `netFieldType_t::animTime`) and `frameInfo[].index` is 13
bits (`:1355`). Server side, `Animate::PostAnimate` **clamps** a non-repeating anim's time at its
length (`fgame/animate.cpp:737-743`: `edict->s.frameInfo[i].time = animtimes[i]`), so the client
can test completion exactly rather than guessing. `cgi.Anim_Time(tiki, animnum)` is already in
the import table at `cg_public.h:387`.

```c
static qboolean RagAnimSettled(entityState_t *ns, ragPend_t *pd, dtiki_t *tiki)
{
    int    i, best = -1;
    float  bw = 0.05f, len;
    vec3_t d;

    if (!tiki) return qtrue;                       // capture will bail cleanly
    for (i = 0; i < MAX_FRAMEINFOS; i++) {         // the dominant channel, not slot 0
        if (ns->frameInfo[i].weight > bw) { bw = ns->frameInfo[i].weight; best = i; }
    }
    if (best < 0) return qtrue;                    // nothing playing
    len = cgi.Anim_Time(tiki, ns->frameInfo[best].index);
    if (len > 0.01f && ns->frameInfo[best].time < len - 0.06f) return qfalse;  // still playing
    VectorSubtract(ns->origin, pd->lastOrigin, d); // root motion still travelling?
    if (VectorLengthSquared(d) > 0.25f) return qfalse;
    return qtrue;
}
```

Note the client is inferring an event the server has an exact name for. `BecomeCorpse` (§2.1) is
the true handoff moment, but **nothing about it is networked** — `SVF_MONSTER`, contents,
solidity and movetype are all server-side, and cgame receives exactly one death bit (`EF_DEAD`,
`bg_public.h:414`, set at `actor.cpp:5459`). So the client must infer it. Belt and braces,
because a missed handoff is a corpse that never ragdolls (a silent no-op, the safe failure) and
a premature one is a corpse that snaps mid-fall (visible, bad):

- primary: dominant-channel `time >= Anim_Time - 60 ms`;
- secondary: `ns->origin` static (< 0.5 u) across two consecutive snapshots — 100 ms at 20 Hz;
- hard cap: **2600 ms** since the EF_DEAD edge (covers every core death; the 2.87 s
  `death_frontchoke` and the 3.4 s / 7.0 s scripted outliers simply arm slightly early or are
  excluded, and a choke/scripted death is a set-piece where a ragdoll is wrong anyway).

Then arm exactly as today, but **with zero seed velocity** — go straight to `state = 1`, skip
the pending-seed differencing at `cg_ragdoll.c:1160-1187`. The body has already landed; there is
no impulse left to seed.

### 5.2 What the user gains over vanilla

Everything in the authored fall is preserved bit-for-bit: pose, direction, root-motion travel,
`bodyfall` sound frames, `pophelmet` frames, hit-location selection. What is added, for the
0.5-1 s after the anim ends and for as long as the corpse exists:

- **drape onto real geometry.** Vanilla plays a flat-ground animation on a staircase and leaves
  the body half-inside the steps or standing off them. The settle pushes the 15 points out of
  solid and lets the constraint web follow.
- **ledge fall.** A body killed on a parapet whose animation throws it two metres back
  (`death_back*`, `death_grenade_high`) currently lands wherever the server's `MmoveSingle`
  put it, held rigid. The settle lets it actually go over.
- **movers.** Already built and already working: `RagMoverHash` wakes a slept body when a bmodel
  under it moves (`cg_ragdoll.c:984-994`), so an elevator or door carries the corpse.
- **prop drape.** Sandbags, crates, rubble.

Risk profile: **the lowest of any option.** The physics starts from a resting pose on legal
ground with zero velocity, so it can never do the thing the user is complaining about — it
never gets to fall 50 units and self-fold. The only new failure mode is a visible twitch at the
handoff (§8).

---

## 6. Design C — impulse-only

Vanilla animation always; physics engages only for the deaths where animation looks worst.

**The trigger is already computed, and it is exact.** `Actor::HandleKilled`
(`fgame/actor.cpp:5464-5487`) applies a server-side corpse impulse for
`MOD_EXPLOSION | MOD_EXPLODEWALL | MOD_GRENADE | MOD_ROCKET | MOD_THROWNOBJECT`:

```c
fPush = 120.0f + fDmg * 1.5f;   if (fPush > 420.0f) fPush = 420.0f;
fPush *= g_corpseImpulse->value;
vDir.z = 0; vDir.normalize();
velocity += vDir * fPush;
velocity.z += fPush * 0.55f;
```

so an explosive death gives the corpse **120-420 u/s horizontal plus 66-231 u/s vertical**,
while a bullet death gives essentially nothing. The ragdoll **already measures exactly this**:
`CG_RagdollTransition` differences the first post-edge snapshot origins into `vel` at
`cg_ragdoll.c:1165-1170`. `VectorLength(vel)` **is** the death-impulse magnitude. Gate on it:

```c
#define RAG_IMPULSE_GATE 220.0f   // u/s; between a bullet death (~0) and the 120..420 blast band
```

Zero new code, zero netcode, zero heuristics. **Use this and not the alternatives**, which are
all worse:

- *`cgi.Anim_NameForNum(tiki, frameInfo[best].index)`* — genuinely available
  (`cg_public.h:383`) and would give the exact chosen anim (`death_grenade*`, `death_mortar*`,
  `death_backgrenade`). String-compare per death, works, but redundant given the impulse gate,
  and it hard-codes alias names that `killed.scr` can override per actor.
- *`CGM_EXPLOSION_EFFECT_1..4`* messages (`cg_parsemsg.cpp:1450-1459, 1851-1854`) carry a world
  position; a small ring buffer would let cgame ask "was there a blast within R units in the
  last T ms". Real, but a proximity heuristic where an exact signal exists.
- *entity events* — dead end. `CG_EntityEvent` is a stub (`cgame/cg_event.c:36`,
  `void CG_EntityEvent(centity_t *cent, vec3_t position) {}`); MOHAA does not use the Q3 event
  path.
- *means-of-death* is **not** networked to the client at all. Per-entity, cgame learns exactly
  **one** death bit — `EF_DEAD` (`fgame/bg_public.h:414`), set for actors only because this fork
  added it (`actor.cpp:5459`; vanilla set it on players and `Body` only). No MOD, no hit
  location, no damage magnitude reaches the client. Do not plan on it.

> The engine survey reached the same conclusion independently and put it best: the origin
> difference the ragdoll already computes *is* the corpse impulse from `Actor::HandleKilled` —
> the two systems are already coupled, we just have not read the number yet.

C alone is a legitimate minimal ship: bodies never look worse than vanilla, and grenade kills
get the one thing physics is unambiguously better at.

---

## 7. Adversarial pass — including on the recommendation

### Against A (track the live animation)

The killer is the blend-out schedule. With `wFloor = 0`, the **final** pose — the one the corpse
holds for the rest of the map, the one in every screenshot, the one the user is complaining
about — is 100% Verlet. A hides the first second and changes nothing about the complaint.

With `wFloor > 0` it does fix the complaint — but after the death animation ends, the "live
animation" **is a static held pose**. Tracking it is then identical to tracking a captured
static pose, which is A'. So **A converges to A' for the only part that matters, at 5 extra
files, 2 renderers, a ship-together constraint, a frame of lag, and a `load_scale` conversion
that has already cost us one debugging session.** Build A only after A' proves the concept and
someone specifically wants the authored *motion* to collide during the fall.

### Against B/C

- **The visible payoff is conditional.** On flat ground in the open — most kills in most maps —
  B is indistinguishable from vanilla. A user who asked for ragdolls may reasonably say "I don't
  see anything." Counter: the complaint is that the current system makes flat-ground deaths
  *worse* than vanilla; B's guarantee is *never worse*, and better wherever geometry is
  involved. But it must be sold honestly (§9).
- **Handoff twitch.** Arming on a body already resting on the floor means pre-lift
  (`cg_ragdoll.c:473-489`) pushes buried points up and gravity settles them back — a small
  visible nudge at the exact moment the player is looking. Mitigations: ease `alpha` from 1.0
  down to its target over 300 ms so the first frames are rigid; ramp gravity in over ~250 ms.
- **C's gate can misfire.** A body that dies at the top of a staircase and tumbles down it via
  root motion will show a large snapshot origin delta and could trip the 220 u/s gate. Cheap
  guard: only sample the impulse from the **first two** post-edge snapshots (~100 ms), which is
  when the blast velocity is present and before root motion has built up much travel.

### Against A' (the recommendation's own core)

- **Stiff corpses.** At `alpha ≈ 0.35` the body is semi-rigid: it topples off a ledge as a unit
  rather than flopping. This is the Half-Life 1 corpse look and it is a genuine regression in
  *dynamism* versus a good ragdoll. Honest framing: **stiff-but-plausible beats limp-but-
  impossible**, and vanilla is 100% stiff today and the user accepts it. `alpha` is a cvar; tune
  it down until it flops, then back off.
- **It cannot invent a pose.** If the authored pose is bad for the situation — a body draped
  over a barrel — A' will hold the flat-ground pose and merely push it out of solid. A real
  ragdoll would conform. This is the price.

### Against the parallel track (full physics with angular joint limits)

Stated fairly, then adversarially.

**Fairly:** angular limits are a real improvement the current sim cannot express. The fold-limit
braces (`s_ragBraces` + `s_ragBraceMinFactor`, `cg_ragdoll.c:89-119`) are **distance**
constraints, and a distance constraint is direction-agnostic: it caps *how far* a knee folds but
not *which way*. Nothing today stops a knee bending sideways or an elbow inverting, and those
are precisely the "impossible" reads. Cone-and-twist limits on point triples would fix that
class outright, and they would improve the settle **whatever the arm policy is** — including
inside B/A'. This work is complementary, not competing, and should be built.

**Adversarially:**

1. **The sim has no angular state to limit.** Bone orientation is not simulated; it is
   *reconstructed at push time* from a single point direction —
   `RagMat3FromTo(s->restDir[i], dNow, S)` (`cg_ragdoll.c:868`), a pure swing with **no twist
   component at all**. There is no twist DOF, so a cone-and-twist limit can only be implemented
   as an angle constraint on point *triples* (parent-joint-child). That is strictly better than
   a distance brace, but it is not the textbook articulated-body joint limit, and reaching the
   textbook version means per-bone quaternion state and a real articulated solver — a rewrite of
   the file, not an addition to it.
2. **Joint-legal is not pose-plausible.** A corpse folded backwards over its own legs, or with
   the torso resting on the shoulder blades and both arms underneath, can be entirely within
   every per-joint limit. Local limits do not constrain global configuration. The user's
   complaint — *"bodies continuously fall into unnatural positions"* — is largely a
   **global-configuration** complaint, and angular limits do not address it.
3. **It has already had 7 rounds.** Each round found a real defect and fixed it, and the pile
   became a different pile. That is what tuning a 15-particle model into looking like human
   anatomy looks like: 15 points cannot encode a ribcage, a shoulder girdle, or the fact that a
   spine will not bend 90 degrees backwards. Shape matching encodes all three implicitly,
   because a real animator drew them.

**If the parallel track is genuinely better, it is on this argument:** a properly limited
articulated ragdoll is the only option that yields *novel, situation-specific* poses that still
read as human — draped over a barrel, folded into a trench corner, hanging off a step. A' can
never do that; it can only transport an authored pose. If the goal is a modern-feeling physics
showcase, they are right and this document is wrong. If the goal is that WW2 soldiers in a 2002
game stop looking broken, the animators already won.

---

## 8. Scorecard

Scores 1-5, 5 best. "Naturalness (common case)" = a bullet death on flat or near-flat ground —
the overwhelming majority of kills.

| | naturalness (common) | dynamism (does a grenade throw it?) | risk vs the now-correct render path | effort |
|---|:--:|:--:|:--:|:--:|
| **A** powered / live-anim tracking | 4 with `wFloor>0`, **2** with `wFloor=0` | 4 | **2** — new import in 2 renderers, ship-together, 1-frame lag, `load_scale` conversion (bug-1963 class), Hook B trap next door | **2** — ~150 lines cgame + ~35 across 5 files x 2 renderers |
| **A'** shape-matched settle | **5** (it *is* the authored pose) | 3 (semi-rigid unless `alpha` drops) | **5** — cgame-only, reuses vetted helpers, no new spaces | **4** — ~70 lines, one file |
| **B** anim-then-settle | **5** (bit-exact vanilla until landed) | 2 alone | **5** — cgame-only; worst case is a no-op corpse | **4** — ~60 lines, one file |
| **C** impulse-only | 5 (vanilla by definition) | **5** for blasts, 1 otherwise | **5** — reuses the seed already computed | **5** — ~15 lines |
| **B+A'+C** (recommended) | **5** | **4** | **5** | **3** — ~150 lines, one file, cgame.dll only |
| **full physics + joint limits** | 3 — better than today, still 15 points pretending to be a skeleton | **5** | 3 — same file, but every round so far has produced a new failure mode | 2 — angle-triple constraints are cheap; a real articulated solver is a rewrite |

---

## 9. Recommendation, and what changes on the first kill

**Build B + A' + C.** Arm policy:

```
EF_DEAD rising edge
  -> create a PENDING record (entnum, armTime, seedOrigin); do NOT capture yet
  -> difference the first 1-2 post-edge snapshots to measure impulseSpeed   [existing code]

  if impulseSpeed > coop_ragdollImpulse (220 u/s)          [Design C: the blast branch]
      arm IMMEDIATELY, seed with that velocity, alpha = 0  -> full physics, body flies
  else                                                     [Design B: the settle branch]
      wait for RagAnimSettled() or the 2600 ms cap
      arm with ZERO seed, alpha = coop_ragdollStiff        -> shape-matched drape
```

### What the user SEES differently on the first kill

- **Bullet kill, flat open ground: nothing. Identical to vanilla.** The authored death animation
  plays start to finish, root motion and all; the settle then moves the body by a unit or two at
  most. This is the guarantee, not a shortcoming — today's build makes this exact case worse
  than vanilla, and that is the complaint being answered.
- **Bullet kill on a staircase, slope, sandbag line, crate stack or rubble pile:** the same
  authored fall, and then, in the half-second after it lands, the body visibly **settles onto
  the geometry** — torso high on the step, legs down the treads, an arm hanging over the edge —
  instead of lying in the flat-ground pose half-inside the steps.
- **Bullet kill near a ledge:** the animation throws the body back as authored, and if it ends
  up past the edge it now **goes over** instead of resting in mid-air.
- **Grenade kill:** unchanged authored selection (`killed.scr` still picks `death_grenade_high` /
  `death_backgrenade` / the mortar family and still pops the helmet), but the body is thrown by
  the existing `g_corpseImpulse` velocity and **tumbles limp through the air**, landing sprawled
  wherever it lands. This is the branch where the ragdoll is unambiguously better than the
  animation, and it is the one the player will notice first.
- **Corpse on a lift or door:** already working, unchanged — the body rides it.

---

## 10. Next-build spec

**Files touched: `openmohaa-hzm/code/cgame/cg_ragdoll.c` only. Ships as `cgame.dll` alone.**

### 10.1 State

```c
typedef struct {                     // pending records: deaths waiting for their anim to finish
    qboolean active;
    int      entnum;
    int      armTime;                // cg.time at the EF_DEAD edge
    int      seedServerTime;
    vec3_t   seedOrigin;             // for the impulse measurement
    vec3_t   lastOrigin;             // previous snapshot origin (the static test)
    float    impulseSpeed;           // u/s, measured once; 0 until the second snapshot
    int      snapsSeen;
} ragPend_t;
static ragPend_t s_ragPend[RAG_MAX_SIMS * 2];
```

Added to `ragSim_t`: `vec3_t pt0[RAG_PTS]` (the rest cloud) and `float alpha` (per-body
shape-match strength, so the blast branch can carry 0).

### 10.2 Functions

| function | change |
|---|---|
| `CG_RagdollTransition` | on the EF_DEAD rising edge, create a **pending** record instead of calling `RagArm`. Keep the existing clear-signal set (`:1152-1156`) verbatim. |
| `RagPendUpdate(cent, ns)` *(new)* | per snapshot transition: on the 1st/2nd post-edge snapshot measure `impulseSpeed` from the origin difference (moved out of `:1160-1187`); then branch — blast → `RagArm` + seed + `alpha = 0`; else → `RagAnimSettled()` → `RagArm` + `alpha = coop_ragdollStiff`, or the 2600 ms cap. |
| `RagAnimSettled(ns, pd, tiki)` *(new)* | §5.1 verbatim. Uses `cgi.Anim_Time` (`cg_public.h:387`), already imported. |
| `RagCapture` | add one `VectorCopy(s->pt[i], s->pt0[i])` loop **after** the pre-lift block (`:489`), so the rest cloud is penetration-free. |
| `RagStep` | hoist the pelvis triad `S` out of `RagPush` (`:854-858`) into a helper `RagBodyRotation(s, S)`, call it once per substep, then run the §4 shape-match loop **after** the constraint iterations and **before** `RagCollideWorld`. |
| `RagPush` | call the same `RagBodyRotation` helper for the pelvis branch — one producer, so the goal pose and the rendered orientation cannot diverge. Otherwise unchanged. |

### 10.3 Blend schedule

```c
// alpha ramps 1.0 -> alphaTarget over 300 ms so the handoff has no twitch, then holds.
// It never decays to 0 on the settle branch: the authored pose IS the rest state.
float t = (float)s->lifeMs;
float a = (t < 300.0f) ? (1.0f - (1.0f - s->alpha) * (t / 300.0f)) : s->alpha;
// gravity ramp over the same window, same reason
float gScale = (t < 250.0f) ? (t / 250.0f) : 1.0f;
```

Blast branch: `s->alpha = 0` at arm; no ramp; today's behaviour exactly, which is the branch
today's build is already good at.

### 10.4 Cvars

| cvar | default | meaning |
|---|---|---|
| `coop_ragdoll` | `0` | existing master gate, stays dark until this passes live |
| `coop_ragdollMode` | `2` | `0` off · `1` settle only (B+A') · `2` settle + blast physics (B+A'+C) · `3` always full physics (today's behaviour, for A/B comparison in one session) |
| `coop_ragdollStiff` | `0.35` | shape-match `alpha` on the settle branch; `0` = today's floppy Verlet, `1` = rigid statue |
| `coop_ragdollImpulse` | `220` | u/s gate for the blast branch (blast band is 120-420 u/s + 55% vertical) |
| `r_ragdollDebug` | `0` | existing; `1` prints, `2` draws the 15 sim dots |

Add to the existing `RagCvars()` block (`cg_ragdoll.c:210-217`), all `CVAR_TEMP` until the
default flip. **Pre-register `coop_ragdollStiff` / `coop_ragdollImpulse` / `coop_ragdollMode` in
`G_InitGame` before any script reads them** — the `getcvar` trap (bug-1669: a script `getcvar`
creates the cvar EMPTY and permanently defeats the engine default).

### 10.5 Debug and acceptance

Extend the existing sleep print (`cg_ragdoll.c:1060-1061`) with the branch and the drift:

```
^~^~^ RAGDOLL sleep ent=%d branch=%s life=%dms span=(%.0f %.0f %.0f) drift=%.1f alpha=%.2f
```

where `drift` = mean `|pt[i] - g[i]|` at sleep — how far physics had to move the body away from
the authored pose. That single number is the whole acceptance test:

- **flat ground, bullet death: `drift` < ~2 u.** If it is larger, the settle is doing something
  the animation did not ask for and `alpha` is too low.
- **staircase / sandbag death: `drift` 5-20 u**, concentrated in the points over the geometry.
  That is the feature working.
- **blast death: branch=blast, no drift reported** (`alpha = 0`).
- **`span`** keeps its existing meaning from the audit: a sprawled body is 55-75 u on one lateral
  axis; a pile is < 35 u everywhere. On the settle branch `span` should now simply match the
  authored death pose's span, kill after kill, with low variance — **variance across kills is
  the real regression detector**, because today's failure is that it varies wildly.
- **`coop_ragdollMode 3` vs `2` on the same map** gives a direct A/B in one session.

### 10.6 Explicitly NOT in this build

- The A-1 `R_GetRagdollAnimPose` readback import (§3.1). Revisit only if someone wants the
  authored *motion* to collide during the fall, and only after A' has proven out.
- Angular / cone-twist joint limits. **Land the parallel track's work on top of this** — it
  improves the settle regardless of arm policy, and the two do not conflict.
- Full Kabsch/polar shape matching (§4). The pelvis triad first.
- Player corpses. The arm guard at `cg_ragdoll.c:1209` (`ns->number < cgs.maxclients → return`)
  stays. Worth knowing for later: player deaths use a completely different selection mechanism —
  a **statemap** (`coop_mod/player_Torso.st`, vanilla `global/mike_torso.st:1705-1980`) whose
  conditionals are C++ (`fgame/player_conditionals.cpp:2073-2153`), driven by `pain_dir` /
  `pain_type` / `pain_location` loaded by a deliberate re-fire of `EV_Pain` inside
  `Player::Killed` (`player.cpp:3446-3459`, direction bucketing at `:3676-3692`). It has its own
  explosion branch (`EXPLOSION_KILLED` → `death_explosion_large/back/left/right/small`, gated on
  `PAIN_THRESHOLD 150`). Same philosophy, different machinery; `Player::Dead` then
  `PausePartAnim(torso)` so the corpse holds its final frame.

- **Scripted set-piece deaths must never arm.** The balcony family pre-bakes a 200-position
  trajectory (`Actor::CalcFallPath`, `fgame/actor_balcony.cpp:200-300`) replayed through
  `ANIM_MODE_FALLING_PATH` — hand-authored physics that a ragdoll would only vandalise. Same for
  `chair_death_*`, `welding_death`, `opel_driver_death`, `cabinet_hiding_death`,
  `open_gate_death` and the map one-offs. Cheapest gate: name-check via
  `cgi.Anim_NameForNum(tiki, dominantIndex)` for a `death_balcony` / non-`death_` prefix, or
  simply let the 2600 ms cap and the `RagAnimSettled` origin test handle them (a body still on
  a falling path is never origin-static, so it will not arm early).

---

## 11. Open questions

1. **Does `killed.scr`'s `waittill flaggedanimdone` path change the client-visible frameInfo
   tail?** The `self.deathanim` override branch (`:73-78`) ends the script the moment the anim
   completes, while the main path continues. Both should clamp `frameInfo[].time`, but a live
   `r_ragdollDebug` print of `(index, time, Anim_Time)` at the settle test would confirm it in
   one kill.
2. **Do any corpses transition into `dead_pose1/2/3`** (0.8 s, `loop`) after the death anim?
   `BecomeCorpse` stops all further thinking (§2.1), so the standard path should *not*, and the
   client should see one frozen `frameInfo`. But `dead_poses.tik` is `$include`d four times from
   `new_generic_human.tik` (`:128, 316, 877, 1237`), so something uses it — probably map-scripted
   sleeping/dead props. A `loop` anim never clamps its time, so the primary settle test would
   never fire on one; the origin-static secondary and the 2600 ms cap cover it, but measure.
3. **`death_prone` and `diveongrenade_death` carry no root motion.** Both are short (0.56 / 0.40
   s) and the settle test's origin-static clause will pass instantly; check they do not arm
   mid-animation.
4. **`death_frontchoke` is 2.87 s, past the 2600 ms cap.** Either raise the cap to 3000 ms or
   accept an early arm on the one anim; measure which reads better.
5. **Does `alpha` want to be per-death-type?** A `death_fall_to_knees` corpse (kneeling, high
   centre of mass) is a much less stable authored pose than a `death_back*` sprawl, and may want
   a lower `alpha` so gravity can finish the job. `cgi.Anim_NameForNum` makes that a one-line
   lookup if the live look calls for it.

---

## 12. Evidence index

| claim | source |
|---|---|
| 30 core `death_*` aliases, durations, root-motion tags | `hzm-mohaa-coop-mod/models/human/new_generic_human.tik:1764-2105`; `_research/npc_anims.csv`; `_research/npc_animation_catalog.md` |
| mod death block byte-identical to vanilla | diff vs `C:\mohaa-coop-dev\new_generic_human_extracted.tik:1702-2044` |
| directional / damage / hit-location selection | `hzm-mohaa-coop-mod/anim/killed.scr:56-158, 357-400`; `fgame/entity.cpp:6432-6441` (`GetLocalYawFromVector`) |
| kill dispatch and arg order | `fgame/sentient.cpp:1817-1829`; `fgame/entity.cpp:190-199` |
| death chain / `m_DeathHandler` | `fgame/actor.cpp:5435-5578`; `fgame/actor_killed.cpp` (73 lines); `fgame/actor_animapi.cpp:104`; `fgame/simpleactor.cpp:113, 1249` |
| explosive corpse impulse (120-420 u/s + 55% vertical) | `fgame/actor.cpp:5461-5488` |
| root motion baked in the `.skc`, applied through `MmoveSingle` | `skeletor/skeletor.cpp:93-138`; `tiki/tiki_anim.cpp:355`; `fgame/animate.cpp:640-774`; `fgame/actor.cpp:3921-3994` |
| corpse grounded and frozen at anim end | `fgame/actor.cpp:12468-12547` (`BecomeCorpse`); `fgame/actor_killed.cpp:53-66` |
| anim time clamps at length (the "done" signal) | `fgame/animate.cpp:737-743`; `qcommon/msg.cpp:1344-1355` (networked) |
| cgame gets exactly one death bit | `fgame/bg_public.h:414`; `fgame/actor.cpp:5459`; `cgame/cg_snapshot.c:113-140` |
| `CG_EntityEvent` is a stub | `cgame/cg_event.c:36` |
| Hook B circularity (the A-2 trap) | `renderergl1/tr_model.cpp:1813`; `renderergl{1,2}/tr_ragdoll.cpp:176-196` |
| `animPose` stash exists, is filled, and is never read | `renderergl{1,2}/tr_ragdoll.cpp:28-29, 120-138`; `tr_model.cpp:849-861`; grep: zero readers |
| `ENTITYNUM_NONE` scratch skeletor branch | `tiki/tiki_cache.cpp:311-315`; `qcommon/q_shared.h:1673` |
| TIKI-orientation vs raw skeletor space | `tiki/tiki_tag.cpp:108-110`; `tr_ragdoll.cpp:146-157`; `cg_ragdoll.c:446-447` |
| `CG_RagdollFrame` runs before entities are added | `cgame/cg_view.c:2928` |
| the pelvis triad rotation `S` already exists | `cgame/cg_ragdoll.c:283-304` (`RagTriad`), `:854-858` |
| post-death origin drift, measured in anger | `.wolf/buglog.json` bug-1964; also 1962, 1963 |
| `Anim_Time` / `Anim_NameForNum` / `Anim_Delta` already imported | `cgame/cg_public.h:383-393` |
