# Ragdoll — the Realism Gap AFTER the Settle Lands (round 8)

**Date** 2026-08-20 · **Lens** assume `coop_ragdollMode 1` (SETTLE) works exactly as specified:
authored death anim plays, body lands, physics drapes it, it sleeps. **What still looks wrong,
ranked by visual impact per unit of effort and risk.**

**Scope note.** This is not a re-audit of the sim. bug-1962 / bug-1963 / bug-1964 are settled, the
render/space pipeline is proven by the `coop_ragdollTest 2` freeze drill, and the two defects the
joints agent found (off-by-one bone driving, unsimulated knee) are taken as true and folded into the
ranking rather than re-derived. Everything below was verified against the code as it stands at
`cg_ragdoll.c` 1449 lines, `renderergl{1,2}/tr_ragdoll.cpp` 196 lines.

---

## 0. Headline: three things will be wrong on the very first settle kill

| # | What the user sees | Where | Verdict |
|---|---|---|---|
| **A** | **A large share of kills get no ragdoll at all** — crouching/kneeling AI (which is most AI in cover) die with the vanilla frozen pose while standing AI drape. Inconsistency reads as "it's broken". | `cg_ragdoll.c:1267` vs `anim/killed.scr:179,183,187,192,196` | **1-line fix.** Measured below. |
| **B** | **A rigid mannequin, not a drape**, plus ~6 s of micro-jitter on every non-flat surface, and every sleep line logging `life≈6000`. | `cg_ragdoll.c:642-659` + `:711-723` + `:1102-1121` | **~15-line fix.** Arithmetic below. |
| **C** | **Mesh sheared at every joint**; hands and feet through the floor. | `cg_ragdoll.c:916-939` (off-by-one), `:65-84` (no foot point) | Already in flight from the joints agent. Keep it in flight — it is #3, not #1. |

A and B are *new to this branch* and neither has been playtested. They will dominate the next
report unless they go in the same build.

---

## 1. Defect A — the settle gate silently drops every crouching death

### The code

`RagPendingThink` refuses any dominant anim whose name does not start with `"death"`:

```c
// cg_ragdoll.c:1267
if (age > 300 && (!nm || Q_stricmpn(nm, "death", 5))) {
    ... memset(s, 0, sizeof(*s)); return;      // pending dropped, corpse keeps the anim pose
}
```

### The measurement

`anim/killed.scr` has **30 `setmotionanim` sites**. Counted by prefix (comments excluded):

| class | sites | starts with `death`? | settle arms? |
|---|---:|---|---|
| `death_*` (chest/back/run/twist/collapse/shoot/prone/knockedup/crotch/left/right/…) | 19 | yes | yes |
| `rifle_pain_kneestodeath` | **4** (`:179 :183 :192 :196`) | **no** | **no** |
| `thompson_pain_kneestodeath` | **1** (`:187`) | **no** | **no** |
| `chair_death_forwards` / `chair_death_backwards` | 2 (`:565 :569`) | no | no — **correct**, set piece |
| `self.deathanim` (script override) | 2 (`:76 :554`) | depends | see below |
| `death_frontcrouch` (the one crouch case that *is* covered) | 1 | yes | yes |

The five `*_pain_kneestodeath` sites are the **entire `knees:` / `crouch:` / `crouchwalk:` branch**
of the `switch (self.position)` at `killed.scr:161-198`, minus the one directional
`death_frontcrouch` case. MOHAA AI fight from cover and spend most of a firefight in `crouch`, so
this is not a corner: it is a large, position-correlated blind spot. A player will read it as
"ragdolls only work sometimes".

The scripted `self.deathanim` override inventory (56 sites across `maps/`) splits cleanly:

```
correctly excluded (set pieces, 16 sites):
  opel_driver_death 6 · 22A222_DeathTruck 3 · welding_death 3 · jeep_crash_{driver,passenger} 2
  · open_gate_death 1 · cabinet_hiding_death 1
correctly included (37 sites): death_headpistol 10 · death_shoot/run/right/left/crotch/collapse 6 ea
  · death_mortar_* 15 · death_fall_back 4 · …
```

So the `"death"` prefix rule is doing real work on the set pieces — it just has the wrong shape.

### The fix (1 line, cgame-only, risk ≈ 0)

Accept a name that **starts with `death` OR ends with `todeath`**, keep the explicit exclusions:

```c
static qboolean RagIsDeathAnim(const char *nm) {
    int L;
    if (!nm || !nm[0]) return qfalse;
    if (!Q_stricmpn(nm, "death_balcony", 13)) return qfalse;   // existing
    if (!Q_stricmpn(nm, "chair_death", 11))   return qfalse;   // set piece, currently excluded by luck
    if (!Q_stricmpn(nm, "death", 5))          return qtrue;
    L = strlen(nm);
    return (qboolean)(L >= 7 && !Q_stricmp(nm + L - 7, "todeath"));
}
```

`Q_stricmp` / `Q_stricmpn` / `strlen` are already used in this file (`:583`, `:1263`). No new API.

**Risk**: the only new anims admitted are the four `*_pain_kneestodeath` clips, which are ordinary
kneel-and-fall animations that end grounded — exactly the class the settle was designed for. Add
`chair_death` to the explicit deny list at the same time (today it is excluded only because it
happens not to start with `death`; that is luck, not intent).

---

## 2. Defect B — the shape-match is ~10x too stiff AND injects velocity

This is the single highest-value item because it decides whether the branch reads as **"a body
draping"** or **"a statue that was placed"** — and the current numbers say statue.

### B1 — `RagShapeMatch` moves `pt` but not `ptPrev`

```c
// cg_ragdoll.c:651-658
for (i = 1; i < RAG_PTS; i++) {
    ... VectorSubtract(want, s->pt[i], d);
    VectorMA(s->pt[i], alpha, d, s->pt[i]);      // ptPrev untouched
}
```

In Verlet, `pt - ptPrev` **is** the velocity. Moving `pt` alone is an impulse, not a projection.
Consequences, in order of visibility:

1. **The sleep metric can never fire on uneven ground.** `CG_RagdollFrame` measures
   (`:1107-1115`) `speed = mean|pt - ptPrev| / 0.008`. The shape-match contributes
   `alpha * d` to that difference every substep, where `d` is the residual distance between where
   the ground put the point and where the rigid goal wants it. With the shipped `alpha = 0.35`:

   ```
   speed_floor = 0.35 * d / 0.008  =  43.75 * d   (u/s)
   sleep gate  = 10 u/s   ->   requires  d < 0.23 u
   ```

   **Any** surface that prevents the authored pose from being satisfied to within a quarter of an
   inch — a slope, a stair tread, a crate, a kerb, a second corpse — produces `d >= 1 u` and the
   body **never speed-sleeps**. It runs to the `lifeMs > 6000` hard cap at `:1120`, jittering the
   whole time, then freezes abruptly. That is a testable prediction: *the next log will show
   `life=6000` on nearly every corpse that did not land on flat ground.*

2. **Spring ringing.** Next substep's integrate step (`:668-678`) propagates the injected impulse
   with 0.98 damping, then the shape-match applies the same correction again — the corpse
   overshoots its own goal and oscillates against the collision resolve.

3. It fights `RagResolveHit`'s resting-contact full-stop (`:743-747`), which sets
   `pt = ptPrev = pos`. The very next substep the shape-match pulls the point back into the
   geometry, the next world sweep pushes it out, and so on: a limit cycle at the contact.

**Fix (2 lines):** move `ptPrev` by the same delta so the shape-match is a pure position
projection.

```c
VectorMA(s->pt[i],     alpha, d, s->pt[i]);
VectorMA(s->ptPrev[i], alpha, d, s->ptPrev[i]);   // NEW: projection, not impulse
```

### B2 — `alpha` is per **substep**, and 0.35 per substep is a 16 ms half-life

`RagShapeMatch` is called once per `RagStep` (`:722`), and `RagStep` runs at `RAG_SUBSTEP_MS = 8`,
up to 4 per frame — i.e. **125 substeps per simulated second**.

```
alpha = 0.35 per 8 ms   ->   half-life = 8 * ln(0.5)/ln(0.65) = 12.9 ms
                        ->   99% converged in ~86 ms
```

A drape wants a half-life in the **150-400 ms** band. The shipped constant is ~15x too fast, so
the corpse snaps back onto the animator's silhouette faster than gravity or contact can deform it.
The debug `drift` print at `:1133-1147` will read ~0-2 u even on stairs, and the user will read
that as "it just plays the animation".

Worse, it is **frame-rate dependent** in the wrong direction: a 30 fps client gets 4 substeps/frame
(capped by `RAG_MAX_STEPS`), a 144 fps client gets 1 — different stiffness per machine, and in
coop, different corpse poses per player.

**Fix (4 lines):** express the constant as a time constant in seconds and convert per substep.

```c
// coop_ragdollStiff now = settle time constant in SECONDS (default 0.20)
float tau   = rag_stiff->value; if (tau < 0.01f) tau = 0.01f;
float alpha = 1.0f - expf(-(RAG_SUBSTEP_MS * 0.001f) / tau);   // 0.039 at tau=0.20
if (s->rampMs < 300) alpha = alpha + (1.0f - alpha) * (1.0f - s->rampMs / 300.0f);
```

`expf` is already reachable (`fabs` is used at `:358`, `:875`; `math.h` comes in via `cg_local.h`).
If `expf` is undesirable, `alpha = dt/(tau+dt)` is within 2% over this range and needs no header.

**Retune note:** the cvar's *meaning* changes. Change the default string at `:235` from `"0.35"`
to `"0.20"` and update the comment, or the first playtest will run a 0.35-**second** time constant
(too soft) and be blamed on the wrong thing.

### B3 — contact points should be exempt from the pull

The drape *is* the contact points staying where the ground put them while the rest of the body
keeps the animator's silhouette. Today the shape-match applies uniformly, so the ground gets
overruled at every joint.

**Fix (~8 lines):** latch a per-point `byte contact[RAG_PTS]` in `RagResolveHit` (`:728`), clear it
at the top of each substep, and in `RagShapeMatch` scale `alpha` by `0.15f` for latched points.
This is what turns "statue rotated to fit" into "shoulder on the step, arm hanging off it".

### Combined cost

| | |
|---|---|
| Files | `cg_ragdoll.c` only |
| Lines | ~15 changed / added |
| Ships as | `cgame.dll` alone |
| Regression risk | **LOW.** Every line is inside `RagShapeMatch` / the `s->branch` block of `RagStep`, both added by this unplaytested branch. Mode 3 (`s->branch == 0`) does not execute any of it, so the proven free-fall A/B is untouched. |

---

## 3. Ranked roadmap

Ordered by *visual impact ÷ (effort × risk)*. "cgame-only" means `cgame.dll` ships alone;
anything marked game/renderer must ship as a matched set per the standing exe+cgame+game rule.

| # | Gap | What the user sees | Fix | Lines / files | Ships | Risk |
|---:|---|---|---|---|---|---|
| **1** | Settle gate drops crouch deaths (§1) | Half the kills have no ragdoll | prefix OR `todeath` suffix | **1-8** / `cg_ragdoll.c` | cgame | **none** |
| **2** | Shape-match impulse + 15x stiffness (§2) | Statue, not drape; 6 s of jitter; never sleeps off flat ground | project `ptPrev`; `tau` in seconds; contact exemption | **~15** / `cg_ragdoll.c` | cgame | low |
| **3** | Off-by-one bone driving + no knee/foot points | Sheared mesh at every joint; hands/feet in the floor | joints-agent §1.1/§1.3 (child-driven swings, points 15/16 = `Bip01 L/R Foot`) | ~60 / `cg_ragdoll.c` | cgame | **med** — this is the push math that was wrong twice (bug-1963, bug-1964). Re-run the `coop_ragdollTest 2` freeze drill before and after. |
| **4** | Blood pool stamped before the body lands (§4) | Pool 30-80 u away from the corpse, growing in empty dirt | move the base stamp to `BecomeCorpse` + failsafe | ~12 / `fgame/sentient.cpp`, `fgame/actor.cpp` | **game.dll** | low |
| **5** | Shooting / exploding a corpse does nothing (§5) | Bodies are furniture | consume `CGM_BULLET_*` / `CGM_EXPLOSION_EFFECT_*` in cgame, impulse the sim | ~70 / `cg_ragdoll.c`, `cg_parsemsg.cpp` | cgame | low |
| **6** | Neck is one distance link (§6) | Heads at impossible backward/lateral angles | cone limit at the neck, in the constraint sweep | ~25 / `cg_ragdoll.c` | cgame | low |
| **7** | No collision vs non-brush props (§7) | Corpses half inside crates, sandbags, tank hulls | second sweep over `cg_solidEntities` non-BMODEL via `CM_TempBoxModel` | ~45 / `cg_ragdoll.c` | cgame | **med** — bbox-granular; oversized props can float bodies. Gate on a cvar + a size cap. |
| **8** | No corpse-vs-corpse (§8) | Bodies interpenetrate into one mass in doorways / MG kill zones | point-vs-point pushout against other sims' `pt[]` | ~30 / `cg_ragdoll.c` | cgame | low |
| **9** | Ledge bodies do not topple (§9) | Corpse hovers rigid with legs over a drop | support-polygon test → collapse stiffness locally | ~35 / `cg_ragdoll.c` | cgame | med |
| **10** | Slot eviction snaps a settled corpse (§10) | 9th kill makes an older body visibly pop back to its anim pose | split *retired pose* from *live sim*; raise renderer slots | ~40 / `cg_ragdoll.c`, both `tr_ragdoll.cpp` | cgame + renderer | low |
| **11** | Repetition: identical twins on flat ground (§11) | Two corpses that drew the same clip are pixel-identical | deterministic per-corpse goal perturbation seeded by `entnum` | ~20 / `cg_ragdoll.c` | cgame | low |
| **12** | Pending records eat sim slots (§12) | A grenade on a squad = later kills get nothing | pending records use a separate small array | ~15 / `cg_ragdoll.c` | cgame | low |
| **13** | Cull bounds ignore the sim AABB (§13) | A body draped down a stairwell can pop out at grazing angles | feed `slot->mins/maxs` into the skel cull | ~15 / both `tr_model.cpp` | renderer | low |

Items 1+2 are one build. 3 is one build (with the drill). 4+5 is one build. Everything else is
polish that only pays once 1-3 land.

---

## 4. Blood pools are stamped at the wrong place — and it is not a ragdoll bug

**Verified.** `Sentient::DropBloodPool()` is called from inside `Sentient::Damage` at the instant
health crosses zero:

```
fgame/sentient.cpp:1796      DropBloodPool();   // inside Damage(), health<=0 branch
fgame/sentient.cpp:2107-2108 end = centroid - Vector(0,0,256);
                             trace = G_Trace(centroid, ..., MASK_DEADSOLID, ..., "DropBloodPool");
fgame/sentient.cpp:2124-2136 m_vCoopPoolPos = trace.endpos + normal*0.25;  // LATCHED here
                             PostEvent(EV_Sentient_CoopGorePoolGrow, 0.6 + rand(0.3));
```

That is **before the death animation has played a single frame**. The grow chain then layers 7
rings at `m_vCoopPoolPos` over 6-7 s (`:2230-2232`), so the pool keeps growing at the spot where
the man was *standing when he was hit*.

Every death anim with root motion moves the body away from that point. `death_run01/02/03`,
`death_knockedup`, `death_grenade*`, `death_mortar_*`, `death_head_flyforward` (which is literally
`death_run03.skc`, `new_generic_human.tik:1868`) all travel. The hybrid design already established
that root motion runs until `Actor::FinishedAnimation_Killed` → `BecomeCorpse()`
(`fgame/actor.cpp:12468`), which then calls `droptofloor(64.0f)` — one **final** origin change.

**What the user sees:** a growing crimson pool in clean dirt, and a corpse a body-length away with
nothing under it. Ragdolls make it worse only because the settle draws the eye to the resting body.

**Fix (~12 lines, `game.dll`):** add `byte m_bCoopPoolDropped;` to `Sentient`; at `sentient.cpp:1796`
replace the direct call with `PostEvent(EV_Sentient_DropBloodPool, 3.0f)` (failsafe, no-ops if the
flag is set); call `DropBloodPool()` from the end of `Actor::BecomeCorpse()` where the body is
grounded and static. `DropBloodPool` sets the flag on its first successful stamp.

**Risk:** low, but note the two paths that never reach `BecomeCorpse` — gibbed actors and actors
removed mid-anim. The +3.0 s failsafe covers both. Do **not** move `CoopGoreTryDripAttach`
(`sentient.cpp:1798`) — the bleed-out drip is supposed to start at death.

---

## 5. Post-death impacts: the signal already reaches cgame, free

### What exists server-side today

- `Sentient::CoopGoreDeathKinetics` (`sentient.cpp:2622`) applies `velocity += vDir*fPush + z`
  (`:2649`) — **but** its call site is gated on the *killing blow only*:
  ```c
  // sentient.cpp:1743-1745
  if (fCoopPrevHealth > 0 && health <= 0 && !IsSubclassOfPlayer())
      CoopGoreDeathKinetics(position, direction, damage, meansofdeath, inflictor);
  ```
  Shooting an already-dead body never reaches it.
- Even if it did, `Actor::BecomeCorpse` sets `MOVETYPE_NONE` on any grounded corpse
  (`actor.cpp:12502-12512`), and `g_phys.cpp:1466` makes `MOVETYPE_NONE` a `break` — **`velocity`
  on a settled corpse is inert.**
- Corpses *are* shootable (`coop_corpseShootable 1`): `BecomeCorpse` flattens the box to
  `(-32,-32,0)..(32,32,16)` and sets `CONTENTS_WEAPONCLIP` + `SOLID_BBOX` (`actor.cpp:12490-12494`),
  which is in `MASK_SHOT` but **not** in `MASK_DEADSOLID`
  (`fgame/bg_public.h:643` = `SOLID|PLAYERCLIP|CORPSE|NOTTEAM2|FENCE`).

So today: bullets stop on a corpse, gore skins re-tier, and the body does not move a millimetre.

### The free client-side signal

Two message classes already arrive in `cg_parsemsg.cpp` carrying world geometry, with **no server
change needed**:

| message | payload | line |
|---|---|---|
| `CGM_BULLET_1 / _2 / _5` (and `_3/_4`, `_6..11`, `_NO_BARREL_*`, the `CGM6_*` mirrors) | `vStart` (muzzle) + `vEnd[]` = **the server's own trace endpoint** + `iLarge` | `cg_parsemsg.cpp:1691-1730` |
| `CGM_EXPLOSION_EFFECT_1..4` | explosion origin | `cg_parsemsg.cpp:1851-1858`, mirror `:2262-2269` |

The bullet `vEnd` is the server's post-trace impact point, so it *already* accounts for the corpse
slab. No client trace, no `bIgnoreEntities` ambiguity, no new protocol constant (which the traps
list flags as a whole-session cost).

### The fix (~70 lines, cgame-only)

Add to `cg_ragdoll.c`:

```c
void CG_RagdollImpulse(const vec3_t pos, const vec3_t dir, float force, float radius);
```

- Iterate the 8 sims. Skip `state == -1` (pending) and `s_ragNeverArm`.
- Cheap reject on the sim AABB (recompute from `pt[]`, or cache the `mins/maxs` already built in
  `RagPush` at `:941-948`) expanded by `radius`.
- For each of the 15 points within `radius`, `VectorMA(s->ptPrev[i], -k, dir, s->ptPrev[i])` with
  `k` falling off as `1 - dist/radius`. **Move `ptPrev`, not `pt`** — that is how you add velocity
  in Verlet, and it is the exact inverse of the §2 bug.
- Wake the body: `s->state = 1; s->sleepMs = 0; s->lifeMs = 0; s->accumMs = 0;` (same recipe as the
  mover-wake at `:1052-1059`).
- **Drop the shape-match for the rest of this body's life** (`s->branch = 0`). A shot corpse should
  go limp, not spring back to its authored silhouette. This is also the cheapest possible answer to
  the "physics variety without the puddle" question in §11: the free-physics window is opt-in, and
  the player opted in by shooting it.
- Clamp: bullets `force ≈ 40-90` u/s at `radius 24`, explosions `force ≈ 250-400` at `radius 180`.
  The existing per-substep velocity clamp at `:672-674` (24 u/substep = 3000 u/s) is the blowup
  backstop; `RagSane` (`:870`) is the ladder below that.

Call sites: one line each after `CG_MakeBulletTracer(...)` in the `CGM_BULLET_*` cases and after
`CG_MakeExplosionEffect(...)` in the `CGM_EXPLOSION_EFFECT_*` cases (and the two `CGM6_*` mirrors).

### Does it fight the server?

**No.** The server corpse is `MOVETYPE_NONE`; its origin will not move. `RagPush` already converts
against `cent->lerpOrigin` every frame (bug-1964's fix, `:899`), so a purely client-side displacement
of the point cloud renders correctly and the server never contradicts it. The only mismatch is that
the corpse's *shot slab* stays at the old origin — a body shoved 20 u by a grenade keeps its bullet
hitbox where it was. That is a cosmetic-vs-hitbox divergence on an already-dead entity; acceptable,
and it is the price of client-side ragdolls in general.

**MP consequence:** the shove is client-side, so two players see slightly different post-impact
poses. Same class as §14 — acceptable, and the impulse magnitude is derived from a *shared* message,
so both clients shove in the same direction with the same force.

---

## 6. The neck

`Bip01 Neck` (pt 3) and `Bip01 Head` (pt 4) are joined by exactly one distance link
(`s_ragBones`, `:71-73`) plus one **inequality** brace `{2,4}` at `0.80` of capture distance
(`:97`, `s_ragBraceMinFactor[6] = 0.80f`).

An inequality brace only ever pushes apart (`:703-704`). So the head is free to travel anywhere on
a sphere of radius `restLen[4]` about the neck, subject only to *not getting closer than 0.8x* its
capture distance from spine2. Nothing at all limits **extension or lateral tilt**. A settled corpse
can therefore rest with its head folded straight back onto its own shoulder blades, or 90 degrees
sideways. Human cervical range is roughly 50-60 degrees extension and 40-45 degrees lateral.

Under a *correct* stiff settle this rarely triggers, because the shape-match holds the authored
head pose. It becomes visible the moment §5 lands (a shot corpse goes limp) or the moment §2's
softening takes effect — i.e. exactly when the rest of the roadmap starts working. Do it in the
same build as §2 or the first thing the user reports after the drape works is "the heads are wrong".

**Fix (~25 lines):** in the constraint sweep, after the distance pass, clamp the `pt3 -> pt4`
direction into a cone about the current `pt2 -> pt3` direction, half-angle ~55 degrees; rotate the
excess out with the existing `RagMat3FromTo` (`:342`) and move `ptPrev` by the same delta. The same
primitive, with different half-angles, is the joints agent's §5.2 — build it once and reuse.

**Also true and lower priority:** every non-pelvis bone gets its orientation from
`RagMat3FromTo` (`:932`), which is a pure swing with **no twist**. Heads and forearms lose their
authored roll as soon as anything moves. The joints agent's §4 covers this; it is a #3-tier item,
not a #6-tier one.

---

## 7. Props: the world sweep cannot see them

`RagCollideWorld` traces `CM_BoxTrace(..., 0, MASK_DEADSOLID, ...)` — clip model 0, the world
(`:807`). `RagCollideMovers` covers brush entities via `CG_GetBrushEntitiesInBounds`
(`:837`), which explicitly **skips everything that is not a bmodel**:

```c
// cg_predict.c:98-100
if (cent->currentState.solid != SOLID_BMODEL) { continue; }
```

Everything solid that is a **model** rather than brushwork is therefore invisible to the ragdoll:
`script_model` crates and barrels, sandbag props, furniture, vehicle hulls, the tank the AI was
standing next to. Bodies will drape *through* them onto the floor beneath.

The engine already has the recipe, four lines away in the same file:

```c
// cg_predict.c:161-165  (CG_ClipMoveToEntities)
IntegerToBoundingBox(ent->solid, bmins, bmaxs);
cmodel = cgi.CM_TempBoxModel(bmins, bmaxs, CONTENTS_BBOX);
```

`cgi.CM_TempBoxModel` is in the import struct (`cg_public.h:199`), `cgi.CM_TransformedBoxTrace` at
`:187`. Corpses themselves are in `cg_solidEntities` too — `CG_BuildSolidList` admits anything with
`nextState.solid` (`cg_predict.c:79`), and `BecomeCorpse` leaves the slab solid.

**Fix (~45 lines):** a third sweep, structured exactly like `RagCollideMovers` (whole-frame,
budget-charged), over `cg_solidEntities` where `solid != SOLID_BMODEL`, mask
`MASK_DEADSOLID | CONTENTS_BBOX`, skipping `s->entnum` itself.

**Risks, and they are real:**
- Bbox granularity. A corpse rests on the *bounding box* of a prop, not its mesh — bodies will
  float above anything whose bbox is much larger than its silhouette (a lamppost, a tree, an
  archway `script_model`). **Mitigate**: skip entities whose bbox exceeds ~96 u in any axis.
- Live actors and players are also non-BMODEL solids. Colliding with them makes corpses shove
  around under a walking soldier. **Mitigate**: skip `number < cgs.maxclients`; consider skipping
  anything with a non-zero `frameInfo[0].weight` on a locomotion anim, or simply accept it — a
  corpse that a living soldier can nudge is arguably *more* realistic, but it is not proven and
  should not ride in the same build as §1/§2.
- Trace budget. `RAG_TRACE_BUDGET` is 240/frame (`:62`) and world traces are already exempt
  (`15 pts x 4 substeps x 8 sims = 480` worst case). Charge the prop sweep against the 240 and let
  it degrade, as the mover sweep does.

**Ship this behind `coop_ragdollProps` defaulting 1, so a single console toggle isolates it if the
next playtest shows floating bodies.**

---

## 8. Corpse-vs-corpse is nearly free — do it as points, not traces

There is no body-vs-body interaction today. In a doorway or an MG kill zone the user will see three
corpses occupying the same volume, which is one of the strongest "this is fake" signals a game can
emit.

**Do not do this with traces.** Every awake sim already has the other sims' 15 world points sitting
in memory (`s_ragSims[]`, `:174`), including slept ones (their `pt[]` is retained; sleep just skips
the step at `:1050-1062`). A pushout is pure arithmetic:

```
8 sims -> 28 unordered pairs x 15 x 15 = 6300 squared-distance tests per iteration
```

At 1 iteration per substep, 4 substeps/frame, that is 25k float ops/frame — under 0.05 ms. It costs
**zero** traces and does not touch the budget.

**Fix (~30 lines):** after the intra-body constraint loop in `RagStep`, for each other active sim
whose AABB overlaps, push apart any point pair closer than `s_ragPtRadius[i] + s_ragPtRadius[j]`
(`:181-187`), splitting the correction and moving both `pt` and `ptPrev`. Only the **awake** body
moves if the other is asleep (asymmetric: give the sleeper infinite mass) — otherwise a new corpse
landing on an old one visibly disturbs a body the player already saw come to rest.

Sensible refinement: wake a sleeping body if a new one lands on it hard (mirrors the existing
mover-wake at `:1052`). That produces the "shot man collapses onto his mate, who shifts" beat, which
is disproportionately convincing for 30 lines.

---

## 9. Ledges: the settle will hold a body in mid-air

The shape-match rigidly re-fits the whole authored pose to the pelvis and the body rotation
(`RagShapeMatch`, `:642-659`; `RagBodyRotation`, `:622-636`). If the anim ends with the legs over a
drop, gravity pulls the leg points down and the shape-match pulls them straight back. With the
current stiffness the shape-match wins outright: **the corpse stays flat, half of it over nothing.**

After §2 softens it, the legs will droop — but the body still will not *topple*, because there is
no notion of support.

**Fix (~35 lines):** each frame, count points with a floor contact latch (the same latch §2/B3
adds). Project the point-cloud centroid onto the horizontal plane and test whether it lies inside
the 2-D convex hull (or, cheaply, the AABB) of the contacting points. If it does not, drop the
shape-match `alpha` toward ~0.02 over ~200 ms and let the body go free — it will roll off the ledge
under gravity + collision, which is what a real body does.

**Risk: medium.** This deliberately re-opens the free-physics regime that produced the mangled
piles, so it must not ship before §3 (off-by-one) and §6 (neck) are in. Gate on
`coop_ragdollTopple` default 0 for the first playtest.

---

## 10. Slot pressure and the eviction pop

`RAG_MAX_SIMS = 8` (`:54`), renderer `RAGDOLL_MAX_SLOTS = 8` (`tr_ragdoll.cpp:20`). Coop enemy
count-scaling caps at 80 AI, and `coop_corpseLife` defaults to **0 = keep forever**
(`actor.cpp:12541-12545` comment). So after 8 kills every new death evicts a slept body
(`RagAllocSlot`, `:1176-1182`), and `CG_RagdollClearEnt` (`:250`) tears down the renderer override —
the older corpse **snaps back to its authored anim pose** in one frame, in full view.

Under settle the snap is small (drift is a few units by construction), so this is polish, not a
headline. But it happens every single kill after the eighth, in every firefight.

**The cheap structural fix**, and the one that also makes §7/§8 cheaper: **a retired pose does not
need a sim.** After sleep, the renderer slot holds a static 3x4 table and costs nothing per frame.
So:

1. Free the cgame `ragSim_t` some seconds after sleep **without** calling `R_ClearRagdoll` — a plain
   `memset(s, 0, sizeof(*s))` leaves the renderer override standing (verified: only
   `CG_RagdollClearEnt` at `:250` calls `cgi.R_ClearRagdoll`, and the clear-signal path at
   `:1343-1347` is keyed on entnum, not on the sim existing, so revive/model-change teardown keeps
   working).
2. Raise `RAGDOLL_MAX_SLOTS` on the renderer side. Cost per slot is
   `(mat + animPose) = 2 x 128 x 3 x 4 x 4 = 12,288 bytes`. **24 slots = 295 KB**, and
   `s_ragSlotPlusOne` is a `byte` array so 255 is the hard ceiling.
3. When the renderer pool *is* full, evict the **most distant** retired pose rather than the first
   found, and prefer one outside the view frustum. A pop you cannot see is not a pop.

Keep `RAG_MAX_SIMS` at 8 — the awake-sim count is what costs traces, and 8 awake bodies is already
480 world traces + up to 240 mover traces per frame.

**Cost:** ~40 lines across `cg_ragdoll.c` and **both** `tr_ragdoll.cpp` copies (gl1 and gl2 must
stay byte-identical; the user runs gl2, and gl1 drifting is how a renderer-switch bug is born).

---

## 11. Repetition — and the constraint on how to fix it

### The measurement

`models/human/new_generic_human.tik:1769-2091` declares **~28 distinct death clips**, with three
`random` alias groups (`death_run01/02/03`, `death_back1/2/3`, `death_grenade01/02`).
`anim/killed.scr` selects among them with **20 `randomint` calls** across a tree branched on
`self.position`, `self.weapontype`, hit location and incoming yaw. The scripted `deathanim`
override adds 37 more map-specific placements.

So the authored variety is genuinely decent. **Repetition is a MEDIUM problem, not the headline** —
and the settle branch does not make it worse. What it *does* is expose a subtler artefact:

**On flat ground the settle converges every corpse to the animator's exact end pose.** Two soldiers
who happened to draw `death_chest` are pixel-identical twins, in the same orientation relative to
their own facing. Vanilla has the same property, but a player who has been told there are ragdolls
scrutinises corpses and notices.

### The fix, and the trap in it

**Fix (~20 lines):** at settle-arm (`RagPendingThink`, `:1288-1305`), perturb `s->goal[]` before it
is handed to the shape-match: a small rotation of the whole goal about the pelvis (±6 degrees yaw,
±4 degrees roll) plus ±1.5 u of per-limb offset on the four extremity points. Cheap, and because the
shape-match target moves rather than the live points, it introduces **zero** instability — the sim
still converges to a rigid, non-self-intersecting pose.

**The trap — and this is the important part:** it must be seeded **deterministically from
`s->entnum` (optionally XOR the dominant anim index), never from `crandom()`**. Ragdolls are
client-side; `crandom()` would give every player in the coop session a differently-posed corpse for
no gain. Today the settle path is RNG-free (the only `crandom` is in the mode-3 seed at
`:1368-1370`, which the settle branch never reaches) and that property is worth protecting.

A cheap deterministic hash: `h = entnum * 2654435761u; h ^= h >> 15;` then take bits as ±1 factors.

### The other half of the question: a short free-physics window

The brief asks whether a short free window for high-impact deaths could re-introduce variety
without re-introducing the puddle. **The answer is yes, but not as a separate feature** — §5's
post-death impulse already builds exactly that machinery (wake + `branch = 0` + limp), and it is
opt-in by the player's own action. Extending it to *explosive kills at death time* is then a
two-line policy change inside `RagPendingThink`: if the dominant anim is `death_grenade*` /
`death_mortar*` / `death_knockedup`, arm with `branch = 0` and a real seed. Do that **only after**
§3 and §6 have landed, because free physics is precisely the regime that produced every "mangled
pile" screenshot.

---

## 12. Pending records consume the sim pool

`RagPendingThink` records are allocated out of the same 8-slot pool (`RagAllocSlot` at `:1424`) and
sit in `state == -1` for up to **3000 ms** (`:1281`). `RagAllocSlot`'s eviction path only ever
considers `state == 2` (`:1176-1180`), so a pending record can neither be evicted nor recycled early.

A grenade dropped on a four-man squad puts four slots into `state == -1` simultaneously, for up to
three seconds, during which the pool has half its capacity. A second grenade, or a sustained MG
burst, exhausts it and later kills fall out with `arm refused ent=%d (pool awake-full)` (`:1186`).

**Fix (~15 lines):** give pending records their own small array (`ragPend_t pend[16]` holding just
`entnum`, `armTime`, `pendOrigin`, `pendStatic`) and allocate a real `ragSim_t` only at the moment
of capture. A pending record is 20 bytes; a `ragSim_t` is ~7 KB. This also removes the
`memset(s, 0, ...)` / re-`RagCapture` dance at `:1288-1296`, which currently zeroes the slot and then
re-fills it from scratch just to reuse `entnum` and `armTime`.

**Related, minor:** `CG_RagdollFrame` returns early when `cg.frametime <= 0` (`:1017`), which also
skips `RagPendingThink`. Above ~250 fps that stalls the pending gate for a frame at a time. Harmless
but worth a comment so it is not re-diagnosed later.

**Also minor:** `pendStatic` (`:1277-1279`) compares `cent->lerpOrigin` frame to frame with a 0.5 u
threshold. At 125 fps that is a **62 u/s** static gate — a body still sliding at 50 u/s reads as
static. More robust and 3 lines: compare `cent->currentState.origin` against `cent->nextState.origin`
(un-interpolated snapshot values, so the threshold has a fixed meaning in server-tick units).

---

## 13. Cull bounds still come from the animation

`RE_SetRagdollPose` stores the sim AABB (`tr_ragdoll.cpp:87-88`, commented "for the drift-cull
work") and **nothing reads it**. Culling still runs `R_CullSkelModel(tiki, &ent->e, newFrame, ...)`
on the *animation's* frame bounds (`renderergl2/tr_model.cpp:1217`).

Under settle, drift is small by construction, so this is currently harmless. It becomes a real
artefact the moment §5 (impulse), §9 (topple) or the free-physics window in §11 lets a body travel:
a corpse draped down a stairwell, 60 u from its origin, can be culled at grazing view angles and
vanish. **~15 lines in both `tr_model.cpp` copies:** union the stored ragdoll AABB into the cull
test when a slot exists. Low priority, but log it now so it is not mistaken for a new bug later.

---

## 14. Two things that are NOT gaps — do not spend effort here

**Weapon and helmet separation.** Already correct, by accident of the vanilla design.
`Sentient::DropInventoryItems` (`sentient.cpp:3929`) calls `item->Drop()` on every inventory item at
death, from `Actor::DispatchEventKilled` (`actor.cpp:5525-5527`) — the rifle becomes an independent
world item and is no longer part of the corpse's skeleton. `pophelmet` (6 sites in `killed.scr`)
does the same for the helmet. There is no attached weapon to shear.

Attachments that *do* remain (the neck stump at `sentient.cpp:2681-2691`, wound props, the bleed-out
drip) are placed client-side through `cgi.TIKI_Orientation` on the parent
(`cg_ents.c:716`), which routes through **Hook B** (`R_RagdollGetOrientation`,
`renderergl2/tr_model.cpp:2353`). They ride the ragdoll correctly. The only cosmetic wart is that a
weapon dropped at the *pre-fall* position ends up a body-length from the corpse — the same root
cause as the blood pool (§4), and it is vanilla behaviour, so leave it.

**MP pose divergence.** Ragdolls are client-side, so each player simulates their own. Under
**settle** this is acceptable and should be stated as a design position rather than fixed:

- The capture inputs are `cs->frameInfo[]` (straight from the shared snapshot) and
  `cent->lerpOrigin/lerpAngles` at a moment when the server has already grounded and frozen the
  corpse (`BecomeCorpse` → `droptofloor` → `MOVETYPE_NONE`). Those are effectively identical across
  clients.
- The settle path contains **no RNG** — `crandom()` appears only in the mode-3 seed (`:1368-1370`).
- The attractor is the same authored pose over the same world geometry. Divergence comes only from
  differing `cg.frametime` substep accumulation, and the shape-match actively suppresses it.

Expect sub-inch differences on flat ground, a few units on complex geometry. One player seeing a
body draped over a crate while another sees it flat **cannot** happen under settle, because both
converge on the same authored silhouette against the same collision surfaces. It **can** happen the
moment free physics returns (§9, §11) — which is a further argument for keeping free physics
opt-in and impulse-triggered rather than default.

The one hard constraint that falls out: **any variety or perturbation added in §11 must be
deterministically seeded.** Write that into the code comment, not just here.

---

## 15. What to put in the next build, and what to grep for

The user tests one build per session, so the sequencing matters more than the list.

### Build 1 — §1 + §2 (about 25 lines, `cgame.dll` only, near-zero risk)

Fix the coverage hole and the stiffness/impulse arithmetic together. These are the two things that
determine whether the settle branch reads as working at all.

Add one number to the sleep print at `:1148` — the count of contacting points — and change the
`branch=` field to also carry `alpha`:

```
^~^~^ RAGDOLL sleep ent=%d life=%dms span=(%.0f %.0f %.0f) branch=%s drift=%.1f contacts=%d
```

**Acceptance, read straight out of `G:/mohaa-gl2/home/maintt/qconsole.log`:**

| signal | fail (today's build) | pass |
|---|---|---|
| `life=` on bodies that landed on stairs/slopes | **6000** on nearly all | 900-2500 |
| `drift=` on stairs/slopes | 0-2 | 4-15 |
| `drift=` on flat ground | 0-2 | 0-2 (unchanged — this is the vanilla-identical case) |
| `pending dropped ... (anim=rifle_pain_kneestodeath)` | present | **absent** |
| `pending dropped ... (anim=opel_driver_death \| welding_death \| chair_death_*)` | present | **still present** (set pieces must stay excluded) |
| `contacts=` | n/a | 3-7 for a sprawled body; 0-1 means the drape is not happening |

If `life` is still 6000 everywhere after B1+B2, the residual `d` is coming from somewhere other than
the shape-match and the next thing to instrument is per-point `|pt - ptPrev|` at sleep time.

### Build 2 — §3 (off-by-one + knee/foot points)

Alone, with the `coop_ragdollTest 2` freeze drill run **before and after**. That drill is the only
thing that separates "the skeleton is wrong" from "the render is wrong", and the push math has
already been wrong twice (bug-1963, bug-1964). Do not bundle anything else into this build.

### Build 3 — §4 + §5 (`game.dll` + `cgame.dll`)

Pools land where the body lands, and shooting a corpse moves it. These are the two changes most
likely to read to the user as "now it feels real", and they are independent of everything above.

### Then, in order, as polish

§6 neck cone · §8 corpse-vs-corpse · §7 props (behind `coop_ragdollProps`) · §10 retired-pose pool ·
§11 deterministic variety · §12 pending array · §9 topple (behind `coop_ragdollTopple 0`) · §13 cull.

---

## Appendix — verified anchors

| claim | anchor |
|---|---|
| Settle gate rejects non-`death` prefixes | `cg_ragdoll.c:1267` |
| Balcony exclusion | `cg_ragdoll.c:1263` |
| Crouch/knees branch uses `*_pain_kneestodeath` | `anim/killed.scr:179,183,187,192,196` |
| Chair set piece | `anim/killed.scr:565,569` |
| Shape-match moves `pt` only | `cg_ragdoll.c:651-658` |
| `alpha` applied once per 8 ms substep | `cg_ragdoll.c:711-723`, `:1078-1087` |
| Sleep metric = mean `|pt-ptPrev|`/substep | `cg_ragdoll.c:1107-1115` |
| Sleep gate 10 u/s, life cap 6000 ms | `cg_ragdoll.c:1115,1120` |
| `coop_ragdollStiff` default `"0.35"` | `cg_ragdoll.c:235` |
| Resting-contact full stop | `cg_ragdoll.c:743-747` |
| Bone swing built from parent→self segment | `cg_ragdoll.c:927-933` |
| Sim points end at Calf (no foot/knee) | `cg_ragdoll.c:81-84` |
| Neck brace is inequality, min 0.80 | `cg_ragdoll.c:97,113-121,703-704` |
| Pool = 8 sims; eviction only of `state==2` | `cg_ragdoll.c:54,1176-1182` |
| Pending record occupies a sim slot for ≤3000 ms | `cg_ragdoll.c:1424-1434,1281` |
| `pendStatic` uses interpolated origin, 0.5 u/frame | `cg_ragdoll.c:1277-1279` |
| Push uses current placement (bug-1964 fix) | `cg_ragdoll.c:899-900` |
| Renderer slots = 8; AABB stored, never read | `tr_ragdoll.cpp:20,30,87-88` |
| Cull uses anim frame bounds | `renderergl2/tr_model.cpp:1217` |
| Hook A / Hook B sites | `renderergl2/tr_model.cpp:1243-1246`, `:2353` |
| Attached entities resolve via `cgi.TIKI_Orientation` | `cg_ents.c:716` |
| `MASK_DEADSOLID` composition (no WEAPONCLIP/BBOX) | `fgame/bg_public.h:643` |
| Brush query skips non-BMODEL | `cg_predict.c:98-100` |
| Non-BMODEL solids via `CM_TempBoxModel` | `cg_predict.c:161-165` |
| `CM_TempBoxModel` / `CM_TransformedBoxTrace` in import struct | `cg_public.h:199`, `:187` |
| Corpses are in `cg_solidEntities` | `cg_predict.c:79-81` |
| Bullet msg carries `vStart` + server `vEnd` | `cg_parsemsg.cpp:1691-1730` |
| Explosion msg carries origin | `cg_parsemsg.cpp:1851-1858`, `:2262-2269` |
| Blood pool stamped at `health<=0` | `fgame/sentient.cpp:1796` |
| Pool traces from `centroid`, latches `m_vCoopPoolPos` | `fgame/sentient.cpp:2107-2136` |
| Death kinetics gated to the killing blow | `fgame/sentient.cpp:1743-1745` |
| Kinetics applies `velocity +=` | `fgame/sentient.cpp:2649` |
| `BecomeCorpse` → WEAPONCLIP slab + `MOVETYPE_NONE` | `fgame/actor.cpp:12468,12490-12494,12502-12512` |
| `MOVETYPE_NONE` runs no physics | `fgame/g_phys.cpp:1466` |
| Weapon dropped as a world item at death | `fgame/sentient.cpp:3929`, `fgame/actor.cpp:5525-5527` |
| ~28 death clips, 3 `random` groups | `models/human/new_generic_human.tik:1769-2091` |
| 20 `randomint` calls in the selector | `anim/killed.scr` |
| Scripted `deathanim` inventory (56 sites) | `maps/*/**.scr` via `global/setdeathanim.scr` |
