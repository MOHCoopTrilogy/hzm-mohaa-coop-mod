# Ragdoll Round 8 — Realism Reference

*Lens: what actually makes game deaths read as real, expressed as parameters we can implement.
Written 2026-08-20, against the SETTLE branch as committed (`coop_ragdollMode 1`).*

Every number in §1 is **measured from this project's own data**, not asserted. Every code claim
carries `file:line`. Every proposed API was checked against `openmohaa-hzm/code/cgame/cg_public.h`.

---

## 0. The unit scale — read this first, it changes every physical number below

`hzm-mohaa-coop-mod/models/human/german_afrika_private.tik:4`:

> `scale 0.52  // Set default scale to 16/30.5 since world is in 16 units per foot and model is in cm's`

**MOHAA is 16 units per foot.** 1 u = 1.905 cm = 0.75 in. Not 1 u ≈ 1 in — the memory index's
`coordinate_units_reference` line is wrong for anything physical, and every ragdoll constant tuned
on the "1 inch" assumption is off by 33 %.

| quantity | metric | MOHAA units |
|---|---|---|
| soldier height (178 cm) | 1.78 m | **92.6 u** |
| shoulder width (45 cm) | 0.45 m | 23.4 u |
| torso thickness lying (24 cm) | 0.24 m | 12.5 u |
| head diameter (22 cm) | 0.22 m | 11.4 u |
| real gravity | 9.81 m/s² | **515 u/s²** |
| 1 m/s | — | 52.5 u/s |

And the payoff line: **`sv_gravity` defaults to `512`** (`openmohaa-hzm/code/fgame/gamecvars.cpp:348`)
= 32.0 ft/s² = **1.00 g**. MOHAA's world gravity is physically exact.

`RAG_GRAVITY` is `800.0f` (`cg_ragdoll.c:59`) = **1.56 g**. Our corpses fall 56 % faster than
everything else in the game and 56 % faster than reality. This is the single largest realism defect
in the file and it is a one-constant fix.

---

## 1. Measured baseline

### 1.1 The authored death animations (parsed from the retail `.skc` headers)

30 `death*` anims are declared in `models/human/new_generic_human.tik:1769-2091`. Their `.skc`
headers (`skelAnimDataFileHeader_t`, `code/skeletor/skeletor_animation_file_format.h:37`) were read
out of `main/Pak0.pk3` — `numFrames × frameTime`:

| statistic | value |
|---|---|
| N | 30 |
| min | 0.47 s (`death_back3`) |
| p25 | 1.09 s |
| **median** | **1.40 s** |
| p75 | 1.94 s |
| max | **2.87 s** (`death_frontchoke`); next `death_choke` 2.40 s |
| under 1.0 s | 6 |
| 1.0–1.5 s | 11 |
| 1.5–2.0 s | 8 |
| ≥ 2.0 s | 5 |
| frame rates present | 10, 15, 25, 30 fps |

**Motion extraction is large.** `TIKI_Anim_Delta` scales the raw `totalDelta` by `load_scale`
(`code/tiki/tiki_anim.cpp:324`), which for humans is 0.52. Horizontal travel per death anim:

| statistic | units | metric |
|---|---|---|
| median | **83 u** | 1.58 m |
| max | 210 u (`death_run01`) | 4.00 m |
| ≥ 16 u | 29 of 30 | — |

So a MOHAA corpse **travels a metre and a half, on average, after the `EF_DEAD` edge**. That is why
bug-1964 (capture-time placement) was so violent, and it is the reason for §4.3 below.

**MEASURED DEFECT — the 3000 ms pending cap under-covers the asset set.**
`RagPendingThink` gives up at `age > 3000` (`cg_ragdoll.c:1281`). The clock starts at the `EF_DEAD`
edge, and the engine crossblends into the death anim over `m_fCrossblendTime = 0.5f`
(`code/fgame/actor.cpp:7634`). Worst case is therefore **0.5 + 2.87 = 3.37 s**, and `death_choke` is
0.5 + 2.40 = 2.90 s — 100 ms of margin. Two of the thirty anims are captured **mid-fall**, which is
exactly the "dropped puppet" failure the settle branch exists to remove. Raise the cap to **4000 ms**.

### 1.2 What our sim currently produces

From the stored session log `_research/ragdoll_p3_session_2200.log`, `RAGDOLL sleep` lines, N = 22
(pre-bug-1963 build, but the sleep gate is unchanged since):

| metric | measured | what a real body does |
|---|---|---|
| time to sleep | median **3833 ms**, mean 4119 ms | ~0.3–0.6 s after first ground contact |
| never speed-slept (rode the 6000 ms life cap) | **8 / 22 (36 %)** | 0 % |
| z-span of the point cloud at rest | median **5.5 u** (10.5 cm) | 12–16 u (23–30 cm) lying |
| z-span ≤ 2 u ("pancake") | **8 / 22 (36 %)** | 0 % |
| largest lateral span | median ~44 u, max 57 u | ≥ 64 u for our 15-point (no-foot) skeleton; ~85 u with feet |

Read that table as one sentence: **our corpses are 40 % too short, half as thick as a body, and take
six to twelve times too long to stop moving.** Those three numbers are the user's "puddle", "pile"
and "unnatural positions" verdicts in numeric form, and each has a parameter attached.

Seed velocities observed in the live log (`RAGDOLL seeded ent=… vel=…`): `(50 60 0)`, `(20 −10 0)`,
`(0 0 15)`, `(15 0 0)`, `(−90 −540 20)`. Four of five are 11–25 u/s — i.e. essentially **zero**. The
one 548 u/s outlier is the death anim's own root motion, not a physical impulse. Mode 3 therefore
photographs a standing soldier and drops him with no initial velocity — the textbook "dropped puppet".

### 1.3 Damping and terminal velocity (arithmetic on the current constants)

`RAG_DAMPING 0.98f` (`cg_ragdoll.c:60`) applied per 8 ms substep = 125 applications per second:

- retained velocity after 1 s = 0.98¹²⁵ = **0.080** → **92 % of velocity is destroyed per second**
- Verlet fixed point: `v* = g·h² / (1 − 0.98)` with `g·h² = 800 × 0.008² = 0.0512 u`
  → `v* = 2.56 u/substep` = **320 u/s = 6.1 m/s terminal velocity**

Real free fall reaches 6.1 m/s in 0.62 s. So any fall longer than ~0.6 s — a balcony, a stairwell, a
crater lip — is visibly floaty. And 92 %/s of "air drag" on a 75 kg body is not physics, it is syrup.

The fix is a **pair**, not one constant: energy loss must come from the *contact* model (Jakobsen's
own choice: friction applied by moving `ptPrev`, which is already what `RagResolveHit` does), not
from global damping. Set `RAG_DAMPING 0.995` (0.995¹²⁵ = 0.535/s, terminal 820 u/s = 15.6 m/s,
unreachable inside any death fall) and take the settle out of contact friction and the sleep gate.

---

## 2. Death anim → physics handoff in shipping engines

### 2.1 Nobody in the industry hard-switches at the death frame

| approach | who | what they do |
|---|---|---|
| **Blend weight ramp** | ubiquitous mid-2000s onward (Source `ragdoll blend`, UE `PhysicsBlendWeight` / `SetAllBodiesBelowPhysicsBlendWeight`, Unity) | animation → physics blend weight goes 0 → 1 over **0.1–0.3 s**; the skeleton is a per-bone lerp of the animated pose and the simulated pose during the window |
| **Powered / tracking ragdoll** | Havok `hkpPoweredChainData`, PhysX articulation drives, Havok "animation-driven ragdoll" | joints keep a **PD drive** toward the animated pose; torque = f(target rotation, current rotation, angular velocity) with per-joint spring/damp gains scaled by limb mass; stiffness is decayed rather than dropped |
| **Track-through-impact, then release** | Zordan & Hodgins SCA 2002; Zordan, Majkowska, Chiu & Fast, *Dynamic Response for Motion Capture Animation*, SIGGRAPH 2005; Shapiro, Pighin & Faloutsos PG 2003 | PD controllers track mocap on a physical model *through* the impact, then release to passive, optionally blending back to kinematic. The published finding that matters to us: **passive simulation started from an animated pose does not look right on its own** — the response has to be led by the motion data |
| **Staged behaviour** | NaturalMotion Euphoria (RAGE / GTA IV) | not one handoff but a sequence of behaviours (brace, catch-fall, protect, collapse) each with its own actuation, decaying to fully passive only at the end |
| **Seed-and-switch** | Source `CBaseAnimating::BecomeRagdoll…` | Source *does* hard-switch, but it seeds the ragdoll from the current animated pose **plus the current bone velocities**, so the corpse continues the motion it already had. Source also relies on very heavy contact damping to hide the transition |

**Our SETTLE branch is the fourth quadrant of this space and it is a legitimate one**: instead of
blending physics *into* an animation, we let the animation finish and hand physics a body that is
already at rest, then let physics only *re-drape* it onto real geometry. Zordan's objection ("passive
sim from an animated pose looks wrong") does not bite, because we do not start a fall — we start a
settle. The shape-match term (`RagShapeMatch`, `cg_ragdoll.c:642`) is the cheap scalar equivalent of
Havok's powered joints: it is a position-space PD with `alpha` as the gain and no derivative term.

### 2.2 The numbers to steal

- **Blend-in window 0.1–0.3 s.** Our `rampMs` 300 ms shape-match ramp (`cg_ragdoll.c:721`) and 250 ms
  gravity ramp (`cg_ragdoll.c:1072`) sit at the top of that band. Correct — keep.
- **Stiffness decays, it does not drop.** Ours goes 1.0 → `coop_ragdollStiff` and *stays* there,
  which is right for a settle (the authored pose is the rest state) and wrong for a blast.
- **Gain by limb, not global.** Havok scales per joint by mass/momentum. We have one global alpha.
  §5.7 proposes the cheap version: a per-point alpha multiplier, head/hands lowest.

---

## 3. What specifically reads as FAKE — ranked by how much it costs us today

Each row: the tell, whether **we have it right now**, and whether it is fixable inside a
client-side cosmetic pose override with a 15-point Verlet and no engine change.

| # | fake tell | present today? | fixable client-side? | cost |
|---|---|---|---|---|
| 1 | **The dropped puppet** — no muscle onset, body goes limp at the instant of death and free-falls | **Yes in mode 3.** Measured: 4 of 5 seeds under 25 u/s, so the body simply drops. Mode 1 removes it by construction | Yes — mode 1 *is* the fix | done |
| 2 | **Bodies that never stop** — residual jitter/creep for seconds | **Yes.** Median 3833 ms to sleep, 36 % never sleep at all | Yes — 3 constants (§5.3) | trivial |
| 3 | **The pancake / the pile** — corpse flattens to a 5 u slab and folds to 70 % of its length | **Yes.** z-span median 5.5 u, lateral median 44 u | Partly. Feet + joint limits (the joints-design track) are the real fix; per-point radii already help | medium |
| 4 | **The knee that isn't there** — sim ends at `Bip01 L/R Calf`, which *is* the knee, so the whole shin below it is dead weight slaved to the knee point | **Yes.** `s_ragBones[]` `cg_ragdoll.c:68-84` stops at Calf; `s_ragAnchorTable` slaves `Bip01 L Foot`/`Toe` to point 12/14 (`cg_ragdoll.c:201-205`) | Yes — add points 15/16 at `Bip01 L/R Foot` | small |
| 5 | **Mesh shear at every joint** — bone *i* driven by `pt[parent]→pt[i]` when the skinned segment runs `pt[i]→pt[child]` (`RagPush`, `cg_ragdoll.c:927-933`) | **Likely yes** (joint-limits agent finding, treat as true) | Yes | small |
| 6 | **Interpenetration with the ground** — a limb half inside the floor | Mitigated: per-substep collision + pre-lift (bug-1962) and per-bone radii `cg_ragdoll.c:181-187`. The *mesh* can still clip because only 15 points are traced | Partly — points are clean, the skin between them is not. Radii are the only lever | free (tuning) |
| 7 | **Feet not conforming to slope** | Yes — feet are not simulated at all (#4) | Yes, once feet exist: one down-trace per foot at settle, rotate the foot swing onto `plane.normal` | small |
| 8 | **Head at an impossible neck angle** | Partly guarded — brace `{2,4}` at 0.80 of capture (`cg_ragdoll.c:97,116`) is a *length* limit, not an angle | Yes — explicit neck cone (§5.6 table) | medium |
| 9 | **The spaghetti look** — unlimited joints, limbs bending backwards | Partly guarded by the 16 braces, but they are distance inequalities and cannot stop a hinge going the wrong *way* | Yes — the joints-design track's `LimitAngle` primitive | medium |
| 10 | **Identical repeated poses** — every corpse in the same silhouette | **Mode 3: severe** (passive collapse converges on one heap). **Mode 1: solved for free** — 30 authored anims, selected by hit direction/damage tier, so the silhouette variety is the animators' | Yes; add ±4° yaw jitter on the goal to stop two same-anim corpses superimposing | trivial |
| 11 | **Sliding at rest** | Fixed by the resting-contact full-stop (`cg_ragdoll.c:743`) | — | done |
| 12 | **T-pose drift** — the sim relaxing toward the bind pose | Not present: capture is the *live* pose and the shape-match target is that pose | — | n/a |
| 13 | **Corpses merging into each other in a pile** | **Yes** — no inter-body collision anywhere in the file | Yes — point-vs-point repulsion between sims (§5.8) | medium |
| 14 | **Corpse resting on its own weapon** | Rare: `DropInventoryItems()` fires at the death dispatch (`code/fgame/actor.cpp:5527`), so the gun is a separate tossed entity by then. Only actors flagged `DontDropWeapons` keep it | Mitigate by raising the hand radius from 2.5 u | trivial |

---

## 4. Settle realism — friction, restitution, and how fast a body actually stops

### 4.1 The strong prior: real bodies stop **fast**, and they do not bounce

Flesh is the most inelastic material in the game. Valve ships the numbers, and they are the best
public reference values available for exactly this problem
(`scripts/surfaceproperties.txt`, format documented in-file as *"elasticity: collision elasticity
(0 – 1.0, 0.01 is soft, 1.0 is hard)"* and *"friction: physical friction (0 – 1.0, 0.01 is slick,
1.0 is totally rough)"*):

| material | density kg/m³ | elasticity | friction |
|---|---:|---:|---:|
| **flesh** (and `bloodyflesh`, `alienflesh`) | **900** | **0.10** | **0.80** |
| concrete | 2400 | 0.20 | 0.80 |
| dirt | 1600 | 0.01 | 0.80 |
| wood | 700 | 0.10 | 0.80 |
| default | 2000 | 0.25 | 0.80 |

Combined flesh-on-concrete restitution ≈ 0.10 × 0.20 = **0.02**. Flesh on dirt ≈ 0.001.
Independent corroboration for the friction side: **cotton clothing on polished concrete μ_s ≈ 0.5**;
human skin μ ranges 0.12–0.74 depending on counterface.

Now run the arithmetic in MOHAA units at `sv_gravity` 512:

- **Impact speed.** A standing soldier's CoM sits ~0.95 m up and ends ~0.12 m up. Free fall of 0.83 m
  at 1 g → **4.0 m/s = 212 u/s** at first contact.
- **Bounce.** At e = 0.02 the rebound is 4.2 u/s; apex = v²/2g = 4.2²/(2 × 512) = **0.017 u**.
  Sub-millimetre. **A body does not bounce, at all, ever.** Our restitution of 0.1
  (`cg_ragdoll.c:748`) is 5× too springy and is a contributor to the multi-second settle.
- **Slide.** μ ≈ 0.55 → deceleration 0.55 × 512 = 282 u/s². A limb entering the ground laterally at
  100 u/s stops in **0.36 s over 18 u (34 cm)**.
- **Therefore: from first ground contact to visually at rest should be 300–600 ms, with total slide
  ≤ 25 u.** Measured today: 3833 ms median. That is the gap.

### 4.2 Sleep thresholds the industry actually uses

| engine | threshold | dwell |
|---|---|---|
| Bullet (defaults) | linear **0.8 m/s** (= **42 u/s**), angular 1.0 rad/s | `setDeactivationTime` **2.0 s** |
| Bullet, a shipped ragdoll config | `setSleepingThresholds(5.4, 5.6)`, `setDamping(0.05, 0.85)` | 3.0 s |
| Source | `ragdoll_sleepaftertime` **5.0 s**; `g_ragdoll_maxcount` **8**; `g_ragdoll_lvfadespeed` 100 | — |
| **ours** | **10 u/s = 0.19 m/s** (`cg_ragdoll.c:1115`) | **1000 ms** (`:1120`), life cap 6000 ms |

Our gate is **4× stricter than Bullet's default on speed**, which is why 36 % of bodies never reach
it — the code's own comment (`cg_ragdoll.c:1112-1114`) records a ~6 u/s constraint-jitter floor, so
we are asking bodies to get within 4 u/s of a noise floor of 6. Raise it to **40 u/s** (Bullet's
0.8 m/s) and shorten the dwell to **600 ms**: total 0.6 s after motion ceases, which lands squarely
in the §4.1 envelope. Note that `RAG_MAX_SIMS 8` (`cg_ragdoll.c:54`) already equals Source's
`g_ragdoll_maxcount` 8 — that one was right by accident.

The resting-contact full-stop gate is `|v| < 0.35 u/substep` = **43.75 u/s = 0.83 m/s**
(`cg_ragdoll.c:743`) — which is *already* Bullet's linear sleep threshold to two significant
figures. Keep it exactly as is; it is the best-calibrated constant in the file.

### 4.3 On the settle branch the body starts at rest, so the life cap is wrong

Mode 1 hands off a landed, static corpse. It should sleep in well under a second. A 6000 ms life cap
means a settle-branch body that fails to speed-sleep keeps re-integrating for six seconds against
geometry it has already conformed to — which is precisely how a good drape degrades into a slump.
**Life cap 2500 ms on the settle branch**, 6000 ms only on the free/blast branch.

---

## 5. Secondary detail — realism per unit of effort

The finding that dominates this section: **most of it already ships, driven by the death animations
themselves.** Overriding the pose does not stop the server running the anim's frame commands.

| detail | status in this project | evidence |
|---|---|---|
| **body-impact thuds** | **Already ships.** The anims carry `bodyfall` client frame commands with per-hit volumes — e.g. `death_fall_to_knees` at frames 6 (knees) and 24 (face); `death_fall_back` at 13 (butt, 0.7), 14 (back), `last` (feet, 0.1) | `models/human/new_generic_human.tik:1769-1790` |
| **helmet separates and lands on its own** | **Already ships.** `pophelmet` is a *server* frame command (frame 25 of `death_fall_to_knees`). It hides the helmet surfaces and spawns a `HelmetObject` — `MOVETYPE_TOSS`, `SOLID_NOT`, 2 u box, thrown from the `Bip01 Head` tag with randomised pitch/yaw spin, lifetime `g_helmetlife` **30 s** | `code/fgame/sentient.cpp:507, 4674-4735`; `code/fgame/object.cpp:406-431` |
| **weapon separates and comes to rest** | **Already ships.** `DropInventoryItems()` at the death dispatch, lifetime `g_droppeditemlife` **30 s** | `code/fgame/actor.cpp:5527`; `code/fgame/gamecvars.cpp:455` |
| **blood pools** | **Ships, but at the wrong place and the wrong time** — see below | `code/fgame/sentient.cpp:1796, 2074-2130` |
| **head lolls last** | not present | — |
| **small settle of the chest after rest** | not present | — |
| **limb-under-torso avoidance** | not present | — |

### 5.1 ⚑ The blood pool is stamped where the body DIES, not where it LANDS

`DropBloodPool()` is called from inside the death handler (`code/fgame/sentient.cpp:1796`), before
the death animation plays. It traces straight down 256 u from `centroid` and stamps there
(`:2108`), then a self-chained `EV_Sentient_CoopGorePoolGrow` grows it over ~6–7 s (`:2119-2130`).

But §1.1 measured the death animations as moving the corpse a **median of 83 u (1.58 m)** and up to
**210 u (4.0 m)**. So on a typical kill the pool spreads a metre and a half from the body, in the
open, with nothing on it — and it *grows* there for the next seven seconds, drawing the eye to the
mistake. This is arguably the highest-visibility realism defect in the whole death sequence and it
has nothing to do with the ragdoll.

Two fixes, and they differ in where the code lives:

- **Server (game.dll):** move the `DropBloodPool()` call out of the death handler and post it as an
  event ~`anim duration + 0.3 s` later, re-tracing from the then-current `centroid`. ~10 lines. This
  is the correct fix and it benefits vanilla play with the ragdoll switched off.
- **Client (cgame.dll only):** stamp our own pool at ragdoll sleep, from the mean of the torso points
  (`pt[0]`, `pt[1]`, `pt[2]`), oriented to the stored contact normal, via
  `CG_ImpactMarkSimple(markShader, origin, dir, orientation, fRadius, r,g,b,a, alphaFade=qfalse,
  temporary=qfalse, dolighting, fadein)` (`code/cgame/cg_local.h:762-776`) — verified present. This
  duplicates the server's pool rather than moving it, so it needs the server one suppressed.

**Recommend the server fix.** The client route is only worth it if game.dll is frozen this round.

### 5.2 Align the settle to the contact plane, not to world up

`RagShapeMatch` (`cg_ragdoll.c:642-659`) re-fits the goal pose using `RagBodyRotation`, which is built
from the *body's own* spine and hip directions. Nothing in the settle knows what the body is lying
**on**. A corpse draped over a 20° slope, a step, or a sandbag should have its whole goal pose rolled
onto that plane before the shape-match pulls toward it; today the pull fights the slope and the
result is a body that is half-conformed and half-standing-pose. Store the dominant contact normal
(largest-area accumulator over `RagResolveHit`'s `tr->plane.normal`, `cg_ragdoll.c:728-760`) and
pre-rotate `goal[]` by `RagMat3FromTo(worldUp, contactNormal)` once at first contact. ~15 lines,
uses only helpers already in the file.

### 5.3 Head lolls last, hands lag — per-point damping

Cheap, and it is the single most "alive-corpse" detail available. Real limp bodies settle
proximal-first: torso stops, then thighs, then the head rolls and the hands flop for another
200–400 ms. Give each point a damping multiplier applied in `RagStep` (`cg_ragdoll.c:670`):

| point | multiplier on `(1 − RAG_DAMPING)` | effect |
|---|---|---|
| 0–2 pelvis/spine | 1.4 | torso stops first |
| 11–14 thighs/calves | 1.0 | |
| 3–4 neck/head | 0.55 | head keeps rolling |
| 5–10 arms/hands | 0.55 | hands flop last |

Same treatment on the shape-match alpha (head/hands × 0.7) so the extremities are also the loosest.
~6 lines. This is the scalar stand-in for Havok's per-joint gain scaling (§2.1).

### 5.4 Body-to-body separation

Nothing in the file collides one sim against another, so two corpses in the same doorway occupy the
same space — the classic "merged pile". A minimum-separation pass between the 8 sims: AABB reject
first (bounds are already computed in `RagPush`, `cg_ragdoll.c:941-948`), then for surviving pairs
push apart any two points closer than `r_i + r_j`. Worst case 8 sims × 15 points = 7200 pairs, but
the AABB reject kills essentially all of them; realistically < 300 pair tests/frame and zero traces.
No new API. ~30 lines.

### 5.5 Bodies pushed by explosions after death

The server can move a corpse's origin after death. `RagPush` converts world sim points against
`cent->lerpOrigin` every frame (bug-1964's fix, `cg_ragdoll.c:899`), which means a server-driven push
currently makes the *mesh* move while the skeleton offsets compensate exactly — net visual result:
**the body does not move at all**. Fix: track `d = curOrigin − prevOrigin` per frame; when
`|d| > 1 u`, translate every `pt[]` and `ptPrev[]` by `d`, clear `sleepMs`, and set `state = 1`.
This reuses the mover-wake machinery already at `cg_ragdoll.c:1050-1062`. ~8 lines, cgame only.

### 5.6 "Shooting a corpse nudges it"

I found **no** cgame-side bullet-impact-on-entity hook (`cg_specialfx.c`, `cg_servercmds.c` searched).
Doing this properly needs either a server-side impulse on dead actors (game.dll) or a new event to
cgame. **State honestly: not achievable in cgame alone as the code stands.** It is also the lowest
value item on this list — deferred.

---

## 6. Anatomical range of motion — the anti-spaghetti reference

The joints track (`_research/ragdoll_joints_design.md` §11) owns the limit *mechanism*. These are the
**target angles** it should be validated against. Standard clinical passive ROM; a corpse is flaccid
(rigor mortis does not begin for 2–6 h), so passive ROM is the right figure — muscle tone does not
restrict a fresh body, only bone and ligament do. Widen by ~10 % over active ROM.

| joint | flexion | extension | abduction / lateral | axial rotation |
|---|---:|---:|---:|---:|
| neck (C-spine) | 50° | 60° | 45° | 80° |
| thoracolumbar spine | 80° | 25° | 35° | 45° |
| shoulder | 180° | 60° | 180° | 90° int / 90° ext |
| **elbow** | **145°** | **0°** (hinge, no hyperextension) | — | forearm 80° pron / 80° sup |
| hip | 120° | 30° | 45° | 45° |
| **knee** | **135°** | **0°** (hinge, no hyperextension) | — | ~10° at 90° flexion |
| ankle | 20° dorsi | 50° plantar | 20° inv / 5° ever | — |

The two rows in bold are the ones that make a ragdoll read as a body rather than a noodle: **elbows
and knees must not hyperextend, at all.** Everything else can be loose. Today the closest thing we
have is the pair of length-inequality braces `{0,12}` / `{0,14}` at 0.75 of capture
(`cg_ragdoll.c:103-104, 118`), which cap how *tight* the knee folds but cannot stop it folding the
wrong way — a knee bending backwards is constraint-legal in the current solver.

---

## 7. THE PARAMETER TABLE

Confidence: **H** = measured here or read from shipped engine data · **M** = industry practice,
secondary source · **L** = derived/estimated, verify live.

### 7.1 Change these

| # | parameter | site | current | **recommended** | source | conf |
|---|---|---|---|---|---|---|
| 1 | `RAG_GRAVITY` | `cg_ragdoll.c:59` | `800.0f` | **`cg.snap->ps.gravity`**, fallback `512.0f` | `sv_gravity` default 512 (`gamecvars.cpp:348`) = 1.00 g at 16 u/ft; `playerState_t.gravity` verified at `q_shared.h:1885`, `cg.snap->ps.*` is a live cgame pattern (`cg_view.c:40`) | **H** |
| 2 | `RAG_DAMPING` | `cg_ragdoll.c:60` | `0.98f` | **`0.995f`** | 0.98¹²⁵ destroys 92 % of velocity/s and caps terminal at 6.1 m/s; energy loss belongs in the contact model (Jakobsen) | **H** |
| 3 | sleep speed gate | `cg_ragdoll.c:1115` | `10.0f` u/s | **`40.0f`** u/s | Bullet default linear sleep 0.8 m/s = 42 u/s; our jitter floor is ~6 u/s | **H** |
| 4 | sleep dwell | `cg_ragdoll.c:1120` | `1000` ms | **`600`** ms | §4.1 envelope: rest reached 0.3–0.6 s after contact | **M** |
| 5 | life cap (settle branch) | `cg_ragdoll.c:1120` | `6000` ms | **`2500`** ms settle / 6000 free | settle hands off an already-resting body | **M** |
| 6 | restitution | `cg_ragdoll.c:748` | `0.1f` | **`0.03f`** | flesh 0.10 × concrete 0.20 = 0.02 (Valve `surfaceproperties.txt`) | **H** |
| 7 | floor tangential retention | `cg_ragdoll.c:749` | `0.45f` | **`0.35f`** | flesh 0.8 × concrete 0.8; cotton-on-concrete μ_s 0.5 → retention 0.5 is the ceiling, go under it | **M** |
| 8 | wall tangential retention | `cg_ragdoll.c:749` | `0.75f` | `0.75f` — keep | a body scraping a wall should slide | **L** |
| 9 | pending-arm cap | `cg_ragdoll.c:1281` | `3000` ms | **`4000`** ms | measured worst case 0.5 s crossblend + 2.87 s `death_frontchoke` = 3.37 s | **H** |
| 10 | `coop_ragdollStiff` | `cg_ragdoll.c:235` | `0.35` | **`0.60`** this round, → 0.30 once joint limits land | the authored pose is our only source of anatomical plausibility until angular limits exist; bias toward vanilla | **L** |
| 11 | sim points | `cg_ragdoll.c:56, 68-84` | 15 | **17** — add `Bip01 L Foot` / `Bip01 R Foot` | the shin is currently unsimulated; span 64 u → 85 u | **H** |
| 12 | hand collision radius | `cg_ragdoll.c:185` | `2.5f` | **`3.5f`** | keeps a retained weapon off the floor plane | **L** |

### 7.2 Keep these — they are already correct

| parameter | site | value | why it is right |
|---|---|---|---|
| resting-contact stop gate | `cg_ragdoll.c:743` | `0.35` u/substep = 43.75 u/s | = Bullet's 0.8 m/s linear sleep threshold, to 2 s.f. |
| shape-match ramp | `cg_ragdoll.c:721` | 300 ms | industry ragdoll blend-in is 0.1–0.3 s |
| gravity ramp | `cg_ragdoll.c:1072` | 250 ms | same band |
| `RAG_MAX_SIMS` | `cg_ragdoll.c:54` | 8 | = Source `g_ragdoll_maxcount` 8 |
| substep / max steps | `cg_ragdoll.c:57-58` | 8 ms × 4 | 125 Hz; Macklin 2019 says favour substeps over iterations — see 7.3 |
| per-bone radii | `cg_ragdoll.c:181-187` | pelvis 7.0 … hand 2.5 | anatomically sane at 16 u/ft: 7 u = 13.3 cm pelvis half-width; head 5 u = 19 cm diameter |
| seed jitter | `cg_ragdoll.c:1368-1370` | 0.08 / 0.08 / 0.06 | ≈ 10 u/s, below the noise floor — correct after bug-1963 |
| velocity clamp | `cg_ragdoll.c:672-673` | 24 u/substep = 3000 u/s | 57 m/s ≈ human terminal velocity. Coincidentally exact |

### 7.3 Worth an experiment, not a recommendation

| parameter | site | current | note |
|---|---|---|---|
| `RAG_ITERS` | `cg_ragdoll.c:61` | 6 | Macklin et al., *Small Steps in Physics Simulation* (SCA 2019): for a fixed budget, accuracy is maximised at **max substeps, one iteration each**; Müller 2020 uses `numPosIters = 1`. 4 substeps × 6 iters could become 12 substeps × 2 for the same work. Do **not** change this in the same build as anything else — it interacts with every constraint in the file |
| point count | — | 15 → 17 | Jakobsen's shipped Hitman humans were "stick figures", relaxation 1–10 ("3 to 4 … enough"). We are within his envelope |

---

## 8. Realism per unit of effort — ranked

| rank | change | effort | expected effect on the user's verdict | where |
|---|---|---|---|---|
| **1** | **Gravity 800 → `ps.gravity` (512)** | 1 line | Removes a 56 % over-speed on every fall. "Bodies don't fall like that" is *literally* true today | cgame |
| **2** | **Sleep fast** — gate 10 → 40 u/s, dwell 1000 → 600 ms, settle life cap 6000 → 2500 ms | 3 constants | Kills the multi-second creep and the 36 % of bodies that never settle. Directly addresses "still kinda fall into a puddle" — the puddle is what a body *becomes* over 4 s of re-integration | cgame |
| **3** | **Blood pool at rest, not at death** | ~10 lines | Highest-visibility single artefact in the whole death sequence: the pool is a median 1.6 m from the body and *grows* there for 7 s. Fixes vanilla too | **game.dll** (or cgame, §5.1) |
| **4** | **Add the feet (points 15/16)** | ~20 lines | Fixes the unsimulated shin, raises the sprawl span 64 → 85 u, and is a prerequisite for foot-on-slope. Attacks "mangled piles" at the geometry level | cgame |
| **5** | **Pending cap 3000 → 4000 ms** | 1 constant | 2 of 30 anims are currently captured mid-fall — i.e. the exact failure mode round 8 was built to remove, still firing on `death_frontchoke` and `death_choke` | cgame |
| **6** | **Restitution 0.1 → 0.03, floor friction 0.45 → 0.35** | 2 constants | Corpses stop dead on contact like flesh instead of easing like a beanbag | cgame |
| **7** | **Fix the off-by-one bone driving** (drive bone *i* from `pt[i] → pt[child]`) | ~25 lines | If the joint-limits agent is right, this is a shear at *every* joint whenever the sim moves — "limbs stretching and warping", verbatim | cgame |
| **8** | **Per-point damping — head and hands loll last** | ~6 lines | Disproportionate "that's a body" payoff for six lines. The cheap Havok per-joint gain | cgame |
| **9** | **Align the goal pose to the contact plane at first contact** | ~15 lines | Turns a half-conformed slump on a slope/step into a drape | cgame |
| **10** | **Body-to-body separation** | ~30 lines | Stops corpses merging in doorways — the literal "pile" | cgame |
| **11** | **Damping 0.98 → 0.995** | 1 constant | Only meaningful for falls > 0.6 s; ship it *with* #2 and #6 or bodies will settle slower, not faster | cgame |
| **12** | **±4° yaw jitter on the goal pose** | 3 lines | Two same-anim corpses on the same floor stop being the same corpse | cgame |
| **13** | **Angular joint limits (elbows/knees never hyperextend)** | the joints track | The anti-spaghetti fix. Large, and it belongs in its own build | cgame |
| **14** | **Corpse nudged by post-death gunfire** | — | **Not achievable in cgame alone**; no bullet-impact-on-entity hook exists client-side. Defer | game.dll + event |

---

## 9. What needs an engine/exe change (as opposed to `cgame.dll` alone)

Everything in ranks 1, 2, 4–13 is **cgame.dll only** — every function they need already exists in
`clientGameImport_t` and was verified for this document:

| API | `cg_public.h` line | used for |
|---|---|---|
| `CM_BoxTrace`, `CM_TransformedBoxTrace`, `CM_PointContents` | 177, 187, 173 | collision (already used) |
| `Anim_Time`, `Anim_NameForNum`, `Anim_NumFrames`, `Anim_CrossblendTime` | 387, 383, 386, 392 | pending-arm gate (already used) |
| `Anim_Delta` *(returns `totalDelta × load_scale`)* | 389 | predicting how far a death anim will travel — usable for a smarter pending cap |
| `Anim_Flags`, `Anim_FlagsSkel` | 390, 391 | detecting delta-driven anims |
| `TIKI_IsOnGround(refEntity_t*, tagNum, threshold)` | 410 | per-tag ground test (foot conformance) |
| `S_StartSound`, `S_RegisterSound` | 234, 260 | a settle thud, if the anim's `bodyfall` is not enough |
| `R_MarkFragments` / `CG_ImpactMarkSimple` (`cg_local.h:762`) | 203 / — | client-side blood pool at rest |
| `R_SetRagdollPose`, `R_ClearRagdoll` | 453, 454 | the bridge (already used) |
| `cg.snap->ps.gravity` (`q_shared.h:1885`) | — | world gravity, verified reachable |

**Requires `game.dll` (server):**
- rank 3, moving `DropBloodPool()` from the death instant to anim-end (`code/fgame/sentient.cpp:1796`)
- rank 14, any post-death impulse on corpses

**Requires no exe (`openmohaa.exe`) change at all.** Nothing in this document touches a protocol
constant, a network field, or `MAX_*` — so none of it triggers the exe+cgame+game triple-ship rule.

---

## 10. Acceptance criteria for the next playtest, in numbers

Extend the existing sleep print (`cg_ragdoll.c:1148`) — it already carries `life`, `span`, `branch`
and `drift`. Judge the build on these, not on impressions:

| metric | today (measured) | pass |
|---|---|---|
| `life` median | 3833 ms | **< 1200 ms** on the settle branch |
| fraction at the life cap | 36 % | **0 %** |
| `span` largest lateral axis, median | 44 u | **≥ 65 u** (≥ 80 u once feet land) |
| `span` z, median | 5.5 u | **10–16 u** |
| `span` z ≤ 2 u ("pancake") | 36 % | **0 %** |
| `drift` on flat ground | — | **< 3 u** (settle should be near-vanilla) |
| `drift` on a step / slope / sandbag | — | **5–20 u**, concentrated in the points over the geometry |
| variance of `span` across kills with the **same** anim on the **same** floor | high | **low** — this is the real regression detector |

Add the contact plane normal to the print once §5.2 lands; a corpse whose stored normal is not the
floor it is visibly lying on is a bug in the accumulator, not in the settle.

---

## Sources

**In-repo measurements (this document):**
- `hzm-mohaa-coop-mod/models/human/german_afrika_private.tik:4` — 16 units per foot, `scale 0.52`
- `hzm-mohaa-coop-mod/models/human/new_generic_human.tik:1769-2091` — 30 death anims, `bodyfall` /
  `pophelmet` frame commands
- retail `.skc` headers from `main/Pak0.pk3`, parsed per
  `openmohaa-hzm/code/skeletor/skeletor_animation_file_format.h:37` — durations and `totalDelta`
- `openmohaa-hzm/code/tiki/tiki_anim.cpp:324` — `totalDelta × load_scale`
- `openmohaa-hzm/code/fgame/gamecvars.cpp:348, 455` — `sv_gravity` 512, `g_droppeditemlife` 30
- `openmohaa-hzm/code/fgame/actor.cpp:5527, 7634` — `DropInventoryItems()`, `m_fCrossblendTime 0.5f`
- `openmohaa-hzm/code/fgame/sentient.cpp:1796, 2074-2130, 4674-4735` — `DropBloodPool()`, `EventPopHelmet`
- `openmohaa-hzm/code/fgame/object.cpp:406-431` — `HelmetObject`, `g_helmetlife` 30
- `openmohaa-hzm/code/qcommon/q_shared.h:1885` — `playerState_t.gravity`
- `openmohaa-hzm/code/cgame/cg_public.h`, `cg_local.h` — every API in §9
- `_research/ragdoll_p3_session_2200.log` — the 22-corpse sleep dataset
- `.wolf/buglog.json` bug-1962, bug-1963, bug-1964

**Literature:**
- Jakobsen, *Advanced Character Physics*, GDC 2001 — Verlet + Gauss-Seidel projection; friction by
  moving the previous position; inequality constraints; relaxation 1–10, "3 to 4 … enough";
  Hitman's humans as stick figures with no axial rotation
- Zordan & Hodgins, *Motion capture-driven simulations that hit and react*, SCA 2002
- Zordan, Majkowska, Chiu & Fast, *Dynamic Response for Motion Capture Animation*, SIGGRAPH 2005 —
  PD tracking through impact, then release/blend back
- Shapiro, Pighin & Faloutsos, *Hybrid control for interactive character animation*, PG 2003
- Müller, Heidelberger, Hennix & Ratcliff, *Position Based Dynamics*, VRIPhys 2006 / JVCIR 2007
- Macklin et al., *Small Steps in Physics Simulation*, SCA 2019 — max substeps, one iteration
- Müller et al., *Detailed Rigid Body Simulation with XPBD*, CGF 39(8) 2020 — `LimitAngle`

**Web, retrieved 2026-08-20:**
- [Valve `surfaceproperties.txt` (Garry's Mod mirror of the shipped file)](https://github.com/Facepunch/garrysmod/blob/master/garrysmod/scripts/surfaceproperties.txt) — flesh density 900, elasticity 0.10, friction 0.80; concrete 0.20/0.80; dirt 0.01/0.80; range documentation
- [Valve Developer Community — `prop_ragdoll`](https://developer.valvesoftware.com/wiki/Prop_ragdoll) and [`cl_ragdoll_collide`](https://developer.valvesoftware.com/wiki/Cl_ragdoll_collide) — `ragdoll_sleepaftertime` 5.0 s, `g_ragdoll_maxcount` 8, `g_ragdoll_lvfadespeed` 100, `cl_ragdoll_fade_time` 15 s
- [Bullet `btRigidBody` reference](https://pybullet.org/Bullet/BulletFull/classbtRigidBody.html) and [Bullet 2.80 manual](https://www.cs.kent.edu/~ruttan/GameEngines/lectures/Bullet_User_Manual) — default sleeping thresholds linear 0.8 / angular 1.0, `setDeactivationTime` 2.0 s
- [MoCap Online — *Ragdoll Physics in Games: How to Blend Animation*](https://mocaponline.com/blogs/mocap-news/ragdoll-physics-animation-guide) — blend weight 0 → 1 over 0.1–0.3 s
- [Epic — *Physics Driven Animation in Unreal Engine*](https://dev.epicgames.com/documentation/unreal-engine/physics-driven-animation-in-unreal-engine) — blend weight model
- [80.lv — *GDC: Physics Animation in Uncharted*](https://80.lv/articles/gdc-physics-animation-in-uncharted) / [GDC Vault — Michal Mach, *Physics Animation in Uncharted 4*](https://www.gdcvault.com/play/1024087/Physics-Animation-in-Uncharted-4) — driving physics objects *from* animation for artistic control
- [PulseGeek — *Ragdoll Setup and Stability Tips*](https://pulsegeek.com/articles/ragdoll-setup-and-stability-tips-for-reliable-collisions/) — interpenetration/jitter causes; collision shapes slightly smaller than the mesh; over-tight joint limits read as unrealistic, relax the spine and hips first
- [Body Physics 2.0 — *Slipping*](https://openoregon.pressbooks.pub/bodyphysics2ed/chapter/friction/) and [*Biomechanics of Human Movement* §6.6](https://pressbooks.bccampus.ca/humanbiomechanics/chapter/5-1-friction-2/) — cotton on polished concrete μ_s ≈ 0.5; human skin μ 0.12–0.74
- [GTA Wiki — Euphoria](https://gta.fandom.com/wiki/Euphoria) — Dynamic Motion Synthesis, staged behavioural responses rather than one handoff
