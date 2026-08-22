# Ragdoll R12 — how shipping engines make a corpse react, and why ours does not

Scope: the user's complaint is that shooting a settled corpse produces no visible limb motion, and
that explosions translate the body without articulating it. This document establishes (a) what the
arithmetic of our current code actually predicts, (b) how Havok/PhysX/Bullet/idTech4-class engines
produce the behaviour, (c) the minimum change that closes the gap.

Written against `cg_ragdoll.c` as of commit `15a8f5c5` ("fix: bullet impulses must ROTATE a limb,
not translate it"), 2176 lines, read in full. Every claim about this codebase carries a `file:line`.
Every number is re-derived below rather than quoted from an earlier round.

Status legend used throughout: **PROVEN** = derived from code I read or a source I quote;
**INFERRED** = follows from proven facts plus a stated assumption; **UNVERIFIED** = plausible,
untested.

---

## 0. Verdict in one page

**The impulse magnitude is correct. The dissipation is not.**

We inject 150–360 u/s onto the struck limb (`cg_parsemsg.cpp:1808`, `cg_ragdoll.c:1456`). Real
physics for a rifle round on a human forearm is ~180 u/s at the limb, ~530 u/s at the limb's free
end (§6.1). Source ships an explosion clamp equivalent to ~300 MOHAA u/s (§6.2). **We are in the
right band and have been since the feature landed.**

What kills the motion is `RagResolveHit` (`cg_ragdoll.c:1038-1071`), which is not a contact model.
It is a per-substep velocity haircut:

| | ours | Bullet / Doom 3 / any shipping solver |
|---|---|---|
| tangential | `v_t *= 0.45` **every 8 ms** (`:1060`) | impulse bounded by `μ × (normal impulse)` |
| effective decel on a resting limb | **~6 750 u/s² (13 g)** | `μg` = **~230 u/s²** |
| distance a 162 u/s limb slides | **2.15 u** | **57 u** |
| rest cut-off | zero all velocity below 43.75 u/s (`:1053`) | Doom 3 `STOP_SPEED = 10.0`; Bullet linear sleep 0.8 m/s ≈ 31 u/s |

Ratio: **27×**. That is the whole complaint, expressed as a number.

Two further defects found while deriving this, both **PROVEN**:

1. **The limp factor goes negative** (`cg_ragdoll.c:937-938` vs. the call sites at
   `cg_parsemsg.cpp:1809, 1869`). `RAG_IMPACT_LIMP_MS` is hard-coded 600, but bullets pass up to
   810 and explosions pass 1200–1410. For `limpMs = 1200` the shape-match alpha becomes **−0.225**:
   the pose-match *repels* every point from its target and the error grows 1.225× per substep.
   Predicted outcome for a grenade near a corpse: the sim trips `RagSane`'s 200 u span gate
   (`:1219-1224`) or the 128 u pelvis leash (`:1229-1236`), sets `s_ragNeverArm`, and deletes
   itself — leaving only the server's corpse-entity toss with the authored pose. That is verbatim
   the user's report: *"lift the body up and throw it slightly as a whole, individual limbs not
   really reacting."* §3.4.

2. **`goal[]` is written once and never again** (`cg_ragdoll.c:1985`; only reader `:927`). Every
   non-pelvis point is dragged back to the *original captured death pose*, and `pt[0]` is exempt
   (the loop starts at `i = 1`, `:924`). Therefore the only lasting effect any impulse can have is
   whatever the pelvis absorbed — i.e. **whole-body translation**. The user's *"the body kinda just
   slowly slides as a whole"* is not a tuning artefact; it is the architecture's only reachable
   output. §3.5.

And one process fact: **`grep -c "RAGDOLL impulse"` returns 0 in every log on this machine** —
`_research/ragdoll_r9_session_live.log`, `ragdoll_r8_session_1230.log`, `ragdoll_p3_session_2200.log`,
and the live `G:/mohaa-gl2/home/maintt/qconsole.log` (which contains **zero** `RAGDOLL` lines of any
kind; the 16:24–16:27 session either ran `r_ragdollDebug 0` or produced no corpses). Every impulse
tuning decision today was made without a single instrumented observation that an impulse reached a
sim. §7.

**The one thing shipping engines do that we do not:** they never let a contact remove more momentum
than the contact physically supports. Friction is an *impulse* bounded by the normal impulse; ours
is a *velocity multiplier*. Structural runner-up: an impulse in a rigid-body engine changes angular
momentum about the struck body's own centre of mass (`r × J`), so a limb rotates even when its
centre cannot translate — which is exactly the case for a shot fired downward into a corpse lying
on the floor.

---

## 1. What our system actually is

Read end to end so the arithmetic below is against the real thing, not the docs.

- 15 mass points on Bip01 bones (`cg_ragdoll.c:73-92`), 14 parent distance links, 16 braces
  (`:123-153`), all with **implicit equal mass** — every constraint splits its correction 50/50
  (`:984-986`, `:1007-1009`).
- Verlet integration, `RAG_SUBSTEP_MS 8`, `RAG_MAX_STEPS 4`, `RAG_DAMPING 0.98`, `RAG_ITERS 6`
  (`:58-61`).
- Per-substep order (`:1633-1642`): `subStart = pt` → `RagStep` (integrate → 6× constraints → limp
  tick → body-rotation filter → `RagShapeMatch`) → `RagCollideWorld`.
- Shape-match `RagShapeMatch` (`:915-948`) pulls every point `i ≥ 1` toward
  `pt[0] + S·(goal[i] − goal[0])` with `alpha = coop_ragdollStiff` (default **0.25**, `:311`),
  ×0.15 where in contact, ×(limp factor) where recently struck; `ptPrev` carries
  `alpha × coop_ragdollCarry` (0.85, `:317`) of the same delta.
- Collision `RagCollideWorld` (`:1104-1146`), swept `CM_BoxTrace` per point per substep against
  `MASK_DEADSOLID`; `RagResolveHit` (`:1038-1071`) resolves.
- Sleep (`:1742-1747`): mean point speed < 10 u/s for 1000 ms, or `lifeMs > 6000`.
- Impulses `CG_RagdollImpulse` (`:1384-1556`), entered from `cg_parsemsg.cpp:1808, 1820, 2232, 2244`
  (flesh) and `:1867` (explosion). `CG_RagdollFrame` runs once per frame from `cg_view.c:2928`,
  after snapshot parse — so an impulse always lands before the step that consumes it. **PROVEN.**

API check against the cgame import struct, as required: `CM_BoxTrace` `cg_public.h:177`,
`CM_TransformedBoxTrace` `:187`, `CM_PointContents` `:173`, `Tag_NumForName` `:406`,
`ForceUpdatePose` `:408`, `TIKI_Orientation` `:409`, `R_SetRagdollPose` `:453`, `R_ClearRagdoll`
`:454`. All present; no invented calls in the recommendations below.

### 1.1 One unit trap worth writing down

`coop_ragdollVelCap` (`:318`, default 8) is applied to `vel` at `:962-968`, and `vel` at that point
is a **per-substep displacement**, not u/s. So the shipped cap is `8 u / 8 ms` = **1000 u/s**, and
the documented "24 = pre-fix" is 3000 u/s. Nothing in the impulse path is near it. Any future
reasoning about that cvar must convert; the name invites the error. **PROVEN** by reading `:955-973`.

---

## 2. The standard model: N rigid bodies, constraints, sequential impulses

### 2.1 What a rigid body is that a particle is not

A rigid body carries **orientation** and an **inertia tensor**. An impulse `J` applied at a world
point `p` therefore changes *two* things. Bullet, verbatim
([`btRigidBody.h`](https://github.com/bulletphysics/bullet3/blob/master/src/BulletDynamics/Dynamics/btRigidBody.h)):

```cpp
void applyCentralImpulse(const btVector3& impulse)
{
    m_linearVelocity += impulse * m_linearFactor * m_inverseMass;
}
void applyTorqueImpulse(const btVector3& torque)
{
    m_angularVelocity += m_invInertiaTensorWorld * torque * m_angularFactor;
}
void applyImpulse(const btVector3& impulse, const btVector3& rel_pos)
{
    if (m_inverseMass != btScalar(0.))
    {
        applyCentralImpulse(impulse);
        if (m_angularFactor)
        {
            applyTorqueImpulse(rel_pos.cross(impulse * m_linearFactor));
        }
    }
}
```

idTech4 — the closest living relative of the engine we are in — is the same three lines
([`Physics_RigidBody.cpp`](https://github.com/id-Software/DOOM-3/blob/master/neo/game/physics/Physics_RigidBody.cpp)):

```cpp
void idPhysics_RigidBody::ApplyImpulse( const int id, const idVec3 &point, const idVec3 &impulse ) {
    if ( noImpact ) {
        return;
    }
    current.i.linearMomentum  += impulse;
    current.i.angularMomentum += ( point - ( current.i.position + centerOfMass * current.i.orientation ) ).Cross( impulse );
    Activate();
}
```

Note the third line. `Activate()` is unconditional:

```cpp
void idPhysics_RigidBody::Activate( void ) {
    current.atRest = -1;
    self->BecomeActive( TH_PHYSICS );
}
```

For the articulated figure the routing is the same, one indirection deeper
([`AF.cpp`](https://github.com/id-Software/DOOM-3/blob/master/neo/game/AF.cpp),
[`AFEntity.cpp`](https://github.com/id-Software/DOOM-3/blob/master/neo/game/AFEntity.cpp)):

```cpp
void idAF::ApplyImpulse( idEntity *ent, int id, const idVec3 &point, const idVec3 &impulse ) {
    SetupPose( self, gameLocal.time );
    physicsObj.ApplyImpulse( BodyForClipModelId( id ), point, impulse );
}
void idAFEntity_Base::ApplyImpulse( idEntity *ent, int id, const idVec3 &point, const idVec3 &impulse ) {
    if ( af.IsLoaded() ) {
        af.ApplyImpulse( ent, id, point, impulse );
    }
    if ( !af.IsActive() ) {
        idEntity::ApplyImpulse( ent, id, point, impulse );
    }
}
```

`BodyForClipModelId( id )` — the impulse goes to **one** body, the one whose collision hull the trace
hit. Not a radius. Not a falloff. **The hit limb, and only the hit limb, is accelerated.**

PhysX makes the wake behaviour explicit in the signature itself
([PxRigidBody](https://nvidia-omniverse.github.io/PhysX/physx/5.3.1/_api_build/class_px_rigid_body.html)):

```cpp
virtual void addForce(const PxVec3& force, PxForceMode::Enum mode = PxForceMode::eFORCE,
                      bool autowake = true) = 0;
```

`autowake` defaults to **true**: "This call wakes the actor if it is sleeping and the autowake
parameter is true (default) or the force is non-zero."

### 2.2 Why that produces limb rotation, arithmetically

Take a uniform rod: mass `m`, length `L`, free in space. Impulse `J` perpendicular, applied at one
end, i.e. at distance `d = L/2` from the centre of mass.

```
  Δv_cm = J / m
  I_cm  = m·L² / 12
  Δω    = J·d / I_cm = J·(L/2) / (m·L²/12) = 6J / (m·L)
  velocity of the struck end = Δv_cm + Δω·d = J/m + (6J/(m·L))·(L/2) = J/m + 3J/m = 4J/m
  velocity of the far end    = J/m − 3J/m   = −2J/m
```

**The struck end moves at 4× the naive `J/m`, and the far end moves backwards at 2×.** That
counter-rotation of the far end is the visual signature of a ragdoll limb reacting — it is what
makes a shot forearm look *hit* rather than *pushed*.

Pinned at the proximal joint (the ragdoll case, shoulder or elbow holds), `I_end = mL²/3`:

```
  Δω  = J·L / (m·L²/3) = 3J / (m·L)
  tip = Δω·L = 3J / m          → still 3× the naive value
```

**Our particle equivalent:** the segment is two equal points of mass `m/2`. Putting the whole
impulse on the distal point gives it `J/(m/2) = 2J/m`, with the proximal end at 0 — which *is* a
rotation about the proximal joint, at **2J/m instead of 3J/m**. A 1.5× shortfall.

**That 1.5× is not our problem.** It is worth recording precisely so that nobody spends a round
chasing it: the particle model is a factor of 1.5 weaker at articulating, while the contact model
is a factor of 27 stronger at destroying the result.

### 2.3 Constraints and the solver

Ball-socket (3 DOF removed), hinge (5), cone-twist (4 + a swing/twist limit) are the three joints
every humanoid ragdoll uses. Solved by sequential impulses (Bullet, PhysX, Havok) or by
position-based projection (PBD/XPBD, and Jakobsen's Verlet scheme, which is the position-based
ancestor). The relevant property for us: a sequential-impulse solver operates on *velocities* with
correct mass ratios, so an impulse that arrives at one body is distributed to its neighbours in
proportion to their inertias. A position-projection solver operates on *positions* with whatever
weights it was given — ours are all equal (`:984-986`) — so the struck point is dragged back toward
the mean of the tree regardless of how heavy the "limb" is versus the "torso".

---

## 3. Particle / Verlet ragdolls — what ours can and cannot do

### 3.1 The source of the model

Thomas Jakobsen, *Advanced Character Physics*, GDC 2001
([PDF, CMU mirror](https://www.cs.cmu.edu/afs/cs/academic/class/15462-s13/www/lec_slides/Jakobsen.pdf)) —
the Hitman: Codename 47 ragdoll. Bones as particles, joints as distance constraints, Verlet
integration, relaxation. Its stated strengths are exactly the ones we have relied on for eleven
rounds: constraints can be made infinitely rigid without divergence, and the whole thing is cheap.

Its prescription for impacts is worth quoting because **we deliberately do the opposite**:

> "With the Verlet integrator it is easy to control the motion of objects by bombs, bullet hits etc.
> by simply moving the particle positions proportionally to the force inflicted on them and the
> velocities will be adjusted automatically."

Jakobsen moves `pt`. We move `ptPrev` (`cg_ragdoll.c:1381-1383, 1456`), on the reasoning that moving
`pt` teleports.

Both are defensible; the difference matters on the grounded case and is worth stating carefully.
Moving `pt` by δ produces an immediate *position* change **and** a velocity of δ/dt. Moving `ptPrev`
by δ produces the velocity and **zero first-substep displacement**. In our pipeline the velocity
must then survive: integration, 6 constraint iterations, the shape-match, and the collision resolve
— and §4 shows the collision resolve annihilates it in three substeps. A position change survives
one solver pass by construction. **INFERRED** (the pipeline is proven; the relative benefit is not
measured).

### 3.2 Is articulated impact response achievable in a particle model?

Yes, and we can prove it against our own code. Remove the ground and nothing else.

A struck point receives `Δv` (see §4.1: ~162 u/s = 1.30 u per 8 ms substep). Retention per substep
is `RAG_DAMPING = 0.98` (`:60`). Upper bound on total travel, damping only:

```
  Σ 1.30 × 0.98ⁿ , n = 0…∞  =  1.30 / (1 − 0.98)  =  1.30 × 50  =  65 units
```

The shape-match takes some of that back. On a struck point at the moment of impact
(`limpMs = 600`, no contact) its alpha is `0.25 × 0.05 = 0.0125` per substep (`:934-939`), rising
back toward 0.25 as the window expires. Combined retention over the first 75 substeps (600 ms)
is roughly `(0.98 × 0.9875)^n` at the start, so the excursion lands in the **tens of units**.

**PROVEN: the solver can articulate. A limb given this impulse in free air swings tens of units.
It is the contact resolve, not the particle model, that produces "no motion at all".**

### 3.3 What implementations do to fake articulation in a particle model

Four techniques, in increasing cost. We already do the first; the others are open.

1. **Impulse on one endpoint only, proximal end planted.** Ours: `w[0] = 0.80 + 0.20·bestT` on the
   distal point, `w[1] = 0.15·(1 − bestT)` on the proximal, with the proximal skipped entirely when
   `w < 0.05` (`:1445-1465`). Correct in principle; §2.2 shows it recovers 2/3 of the rigid answer.
2. **Torque-equivalent point pair.** Apply `+J·a` distally and `−J·b` proximally so the *sum* is
   the linear impulse you want and the *moment* about the segment midpoint is the couple you want.
   This synthesises an angular impulse out of two linear ones. This is the cheap stand-in for the
   inertia tensor, and it is the one thing that makes a *downward* shot rotate a limb that cannot
   translate downward (§5.3). We do not do this — our proximal weight is same-signed, so the pair is
   a push, never a couple.
3. **Relax the constraints on the struck limb, not just the pose-match.** We relax only
   `RagShapeMatch` (`:934-939`). `RAG_ITERS = 6` stiff Gauss–Seidel distance passes still run at
   full strength on the struck link every substep (`:974-1011`), plus 16 braces at
   `coop_ragdollTruss` strength (`:988-1010`). Six near-rigid iterations on an equal-mass tree is
   precisely the mechanism that redistributes the struck point's motion into the whole body — which
   is the "slides as a whole" the user reports.
4. **Freeze the proximal point as a hard pivot for a short window.** Cheapest way to guarantee
   rotation rather than translation, at the cost of a visible anchor if the window is long.

### 3.4 DEFECT — the limp factor goes negative

`cg_ragdoll.c:64-68`:

```c
#define RAG_CONTACT_RELAX 0.15f
#define RAG_IMPACT_RELAX  0.05f
#define RAG_IMPACT_LIMP_MS 600
```

`cg_ragdoll.c:934-939`, inside `RagShapeMatch`:

```c
if (s->limpMs[i] > 0) {
    float k = 1.0f - (float)s->limpMs[i] / (float)RAG_IMPACT_LIMP_MS;
    a *= RAG_IMPACT_RELAX + (1.0f - RAG_IMPACT_RELAX) * k;
}
VectorMA(s->pt[i], a, d, s->pt[i]);
```

There is no clamp on `a`, and no clamp on `limpMs` at either assignment site (`:1464`, `:1474`,
`:1535`). The call sites pass:

| caller | `limpMs` | `k = 1 − limpMs/600` | `a` factor `0.05 + 0.95k` | alpha = 0.25 × factor |
|---|---:|---:|---:|---:|
| bullet, `iLarge = 0` (`cg_parsemsg.cpp:1809`) | 600 | 0.000 | +0.050 | **+0.0125** ok |
| bullet, `iLarge = 1` | 670 | −0.117 | −0.061 | **−0.0152** |
| bullet, `iLarge = 2` | 740 | −0.233 | −0.172 | **−0.0430** |
| bullet, `iLarge = 3` | 810 | −0.350 | −0.283 | **−0.0706** |
| explosion, offset 0 (`:1869`) | 1200 | −1.000 | −0.900 | **−0.2250** |
| explosion, offset 3 | 1410 | −1.350 | −1.233 | **−0.3081** |

`iLarge` is `MSG_ReadBits(2)`, so 0…3 (`cg_parsemsg.cpp:1778`). The explosion offset is
`iType − CGM_EXPLOSION_EFFECT_1` over the four cases at `:1855-1858`, so 0…3.

With `a < 0`, `VectorMA(pt, a, d, pt)` where `d = want − pt` moves the point **away** from its pose
target. The error compounds:

```
  explosion offset 0:  growth 1.225 per substep
  substeps until limpMs decays back to 600:  (1200 − 600)/8 = 75
  1.225^75 = e^(75 × ln 1.225) = e^(75 × 0.2029) = e^15.2 ≈ 4.0 × 10⁶
```

Bounded in practice by the 6 distance-constraint iterations — but those constrain link **length**,
not link **direction**, so the limbs fan outward freely — and then by `RagSane`: the 200 u span gate
(`:1219-1224`) or the 128 u pelvis leash (`:1229-1236`). Either sets `s_ragNeverArm[entnum] = 1` and
calls `CG_RagdollClearEnt` (`:1721-1722`), which is permanent for that entnum for the map.

The radial path limps **every** point within `dist < 0.613 × radius` (`k > 0.15` at `:1534` with the
quadratic falloff at `:1500-1501`), i.e. every point of any corpse within 110 u of a 180 u blast. So
the whole body gets alpha −0.225 simultaneously.

**Predicted symptom:** grenade near a settled corpse ⇒ `^~^~^ RAGDOLL blowup ent=N reason=span` (or
`reason=leash`) ⇒ ragdoll deleted ⇒ what the player sees is the server's corpse-entity toss with the
authored animation pose and no articulation whatsoever. **This is verbatim the user's explosion
report.** **PROVEN** as code behaviour; **INFERRED** as the cause of that specific report (no log
line exists to confirm, see §7).

Secondary consequence: `ptPrev` carries `a × 0.85` (`:946`), so a negative `a` leaves
`(a − 0.85a) = 0.15a` of outward *velocity* per substep — energy injection, the exact failure the
carry term was written to prevent (comment `:941-945`).

### 3.5 STRUCTURAL — `goal[]` is immutable and the pelvis is exempt

`goal[]` is written at one place only, `cg_ragdoll.c:1984-1986`:

```c
for (i = 0; i < RAG_PTS; i++) {
    VectorCopy(s->pt[i], s->goal[i]); // the authored pose is the target silhouette
}
```

and read at `:927` and `:1767` (the debug `drift=` metric). Nothing updates it, ever.

`RagShapeMatch` (`:924`) starts at `i = 1`, so `pt[0]` — the pelvis — is never pulled, and the target
for every other point is expressed **relative to `pt[0]`**. Two consequences, both **PROVEN** by
construction:

- Any deformation a bullet produces is temporary. Once `limpMs` expires, the limb is reeled back to
  the death pose at 0.25/substep — a 96 % return in `ln(0.04)/ln(0.75)` ≈ **11 substeps = 88 ms**.
  A shot corpse *cannot* keep a new shape.
- The only degree of freedom that survives is whatever the constraint tree pushed into the pelvis,
  and the whole pose rigidly follows the pelvis. **The system's only durable response to being shot
  is to translate the entire body.** That is the user's *"kinda just slowly slides as a whole"*,
  and no amount of impulse tuning can change it while `goal[]` is fixed and `pt[0]` is exempt.

---

## 4. The arithmetic — what happens when you shoot our corpse

Constants used, all read from source:

| symbol | value | site |
|---|---|---|
| substep `dt` | 8 ms = 0.008 s | `cg_ragdoll.c:58` |
| damping | 0.98/substep | `:60` |
| gravity | `ps.gravity`, 512 u/s² typical | `:333-343` |
| gravity per substep² | `512 × 0.008² = 0.032768 u` | derived |
| force (bullet) | `150 + 70·iLarge` → 150/220/290/360 u/s | `cg_parsemsg.cpp:1808` |
| radius (bullet) | `15 + 1.5·iLarge` → 15/16.5/18/19.5 u | same |
| restitution | 0.1 | `cg_ragdoll.c:1059` |
| tangential retention | 0.45 floor / 0.75 wall | `:1060` |
| dead-stop gate | `n_z > 0.7` and `|v| < 0.35 u/substep` | `:1053` |

`0.35 u/substep ÷ 0.008 s = 43.75 u/s.`

### 4.1 The injected speed

`cg_ragdoll.c:1456`:

```c
VectorMA(s->ptPrev[q], -(force * k2 * w[e] * subDt), dir, s->ptPrev[q]);
```

`pt` is untouched, so `v = (pt − ptPrev)/dt` gains exactly `force · k2 · w` u/s along `dir`.

Take a typical forearm hit with `iLarge = 1` (force 220, radius 16.5). The impact point `vStart` is
on the *skin*; the bone segment is inside, so `bestD` ≈ 3 u for a ~4 u-radius forearm.

```
  k2 = 1 − bestD/radius = 1 − 3/16.5 = 0.818
  w[0] = 0.80 + 0.20·bestT,  bestT ≈ 0.5  →  0.90
  Δv = 220 × 0.818 × 0.90 = 162 u/s = 1.30 u per substep
```

The result clamp at `:1457` is `vmax = force × 1.6 = 352 u/s`; 162 is well under. The `velcap` at
`:962-968` is 1000 u/s (§1.1); also clear. **The impulse arrives intact.** **PROVEN.**

### 4.2 Case A — shot downward into a corpse on its back (the common case)

`dir` is the **inward** impact normal: `cg_parsemsg.cpp:1777` reads the surface normal, `:1802`
negates it, `:1808` passes it. For a player standing over a supine corpse, the corpse's surface
normal points up; negated, `dir` points **down, into the floor**. The maintainer's premise: confirmed.

Take `dir·(0,0,−1) = 0.93`.

Substep 1. The point is resting on the floor (its box bottom is touching), so the sweep from
`subStart` to `pt` hits at `fraction ≈ 0` with `plane.normal = (0,0,1)`.

```
  v      = 1.30 u along dir                       →  v_z = −1.21,  |v_xy| = 0.47
  |v| = 1.30 > 0.35                               →  dead-stop branch NOT taken
  v_n' = −0.1 × (−1.21) = +0.121                  (restitution, :1059)
  v_t' =  0.45 × 0.47   =  0.211                  (floor friction, :1060)
  |v'| = √(0.121² + 0.211²) = 0.243 u/substep = 30.4 u/s
```

**One contact removed 81 % of the speed.** And 0.243 < 0.35, so **the next floor contact takes the
dead-stop branch and zeroes it entirely** (`:1053-1057`).

The point now has +0.121 u/substep upward against 0.032768 u/substep² of gravity:

```
  rise time = 0.121 / 0.032768 = 3.7 substeps ≈ 30 ms
  peak height = v²/(2a) = 0.121² / (2 × 0.032768) = 0.0146 / 0.0655 = 0.223 u
```

**Total visible excursion: ~0.22 units, over ~60 ms, then dead.** A soldier is ~72 u tall. At a
typical viewing distance the model is ~300 px on a 1080p screen, so 0.22 u ≈ **0.9 pixels**.

> *"no — they don't really seem to move at all."* — matched, quantitatively.

### 4.3 Case B — grazing / horizontal shot

`dir` nearly horizontal, so almost all 1.30 u is tangential. Gravity keeps the point pressed to the
floor, so the sweep hits every substep and `RagResolveHit` fires every substep:

```
  substep 1: 1.30                    → ×0.45 → 0.585
  substep 2: 0.585                   → ×0.45 → 0.263
  substep 3: 0.263 < 0.35            → DEAD STOP (all velocity zeroed)

  total slide = 1.30 + 0.585 + 0.263 = 2.15 u   over 24 ms
```

Then the shape-match reels it home over ~88 ms (§3.5).

**2 u out and back in ~110 ms.** That is a twitch.

> *"legs kinda work but it still seems like both twitch."* — matched.

### 4.4 The same hit under a Coulomb contact

Treat 0.45 as a friction coefficient and apply it the way every shipping solver does — as a bound on
the tangential *impulse*, `|J_t| ≤ μ|J_n|`. For a point resting under gravity, the normal impulse
per substep is only what is needed to stop the gravity increment: `J_n ≈ m·g·dt`. Therefore:

```
  tangential deceleration = μ·g = 0.45 × 512 = 230 u/s²
  from 162 u/s:  stop time = 162/230 = 0.70 s
                 distance  = v²/(2a) = 162²/(2×230) = 26 244/460 = 57 units
```

| | ours | Coulomb, same μ |
|---|---:|---:|
| slide distance | **2.15 u** | **57 u** |
| stop time | 24 ms | 700 ms |
| effective deceleration | 162/0.024 = **6 750 u/s² (13 g)** | **230 u/s² (0.45 g)** |

**Factor 27 in distance, 29 in time.** Same coefficient, same impulse — different *model*.

For calibration, 57 u is most of a body length, which is more than we want; but it is the right
order of magnitude to then tune *down* with joint limits (the r11 work) rather than an order of
magnitude we cannot reach at all.

### 4.5 The rest-gate is set 4× too high

| system | rest / sleep threshold | source |
|---|---|---|
| **ours** | 43.75 u/s, zeroes velocity instantly on first contact below it | `cg_ragdoll.c:1053` |
| Doom 3 rigid body | `STOP_SPEED = 10.0f` — a *test*, over a whole body, not a per-contact kill | `Physics_RigidBody.cpp` |
| Doom 3 AF | `SUSPEND_LINEAR_VELOCITY 10.0`, `SUSPEND_ANGULAR_VELOCITY 15.0`, `NO_MOVE_TIME 1.0 s`, `NO_MOVE_TRANSLATION_TOLERANCE 10.0` | `Physics_AF.cpp` |
| Bullet | linear sleep 0.8 m/s ≈ **31 u/s**, angular 1.0 rad/s, held for a deactivation *time* | `btRigidBody.h` |

Ours is **4.4× Doom 3's** and 1.4× Bullet's, and unlike either it fires on a *single* contact rather
than after a sustained period. A point still moving at 43 u/s — which is a visible 43 in/s — is
declared at rest and frozen.

### 4.6 A latent direction bug, low severity

`cg_parsemsg.cpp:1800-1809`: the `VectorNegate(vEnd, vEnd)` sits **inside**
`if (flesh_impact_count < MAX_IMPACTS)`. `MAX_IMPACTS = 64` (`:48`). Past 64 flesh impacts in one
snapshot the negate is skipped and the impulse direction is **outward instead of inward** — the
corpse is pulled toward the shooter. Essentially unreachable (64 flesh hits in one snapshot), but it
is free to fix by hoisting the negate above the `if`. **PROVEN** by reading; **UNVERIFIED** that it
has ever fired.

---

## 5. The grounded-corpse case, specifically

This is the behaviour the user is asking for and the one we cannot currently produce. Four
mechanisms make it work in shipping engines.

### 5.1 Coulomb friction — the load-bearing one

Bullet's sequential-impulse solver
([`btSequentialImpulseConstraintSolver.cpp`](https://github.com/bulletphysics/bullet3/blob/master/src/BulletDynamics/ConstraintSolver/btSequentialImpulseConstraintSolver.cpp)):

```cpp
solveManifold.m_lowerLimit = -(solveManifold.m_friction * totalImpulse);
solveManifold.m_upperLimit =   solveManifold.m_friction * totalImpulse;
```

`totalImpulse` is the **accumulated normal contact impulse**. The friction impulse is *clamped* by
it. The physical statement: a surface can only resist tangentially in proportion to how hard it is
being pressed. A corpse lying on the floor presses with `m·g` only, so friction can only remove
`μ·m·g·dt` of momentum per step — a *small, bounded* amount — no matter how fast the limb is moving.

Our `v_t *= 0.45` is unbounded viscous drag: it removes 55 % of *whatever speed exists*, so the
faster the hit, the harder the floor grabs. That is backwards, and it is why the harder we push the
less we see.

Defaults for calibration: Bullet `m_friction = 0.5`, `m_restitution = 0.0`; Doom 3
`SetFriction(0.6f, 0.6f, 0.0f)` and `SetBouncyness(0.6f)` — note Doom 3 ships **contactFriction 0.0**
for rigid bodies. Ours: restitution 0.1 (reasonable), "friction" 0.45 (wrong model).

### 5.2 Impulse unconditionally wakes the body

- Doom 3: `Activate()` is the last line of `ApplyImpulse`, no threshold (§2.1).
- PhysX: `autowake = true` by default in the signature (§2.1).
- Bullet: sleeping bodies stay in the broadphase specifically so that "active objects [can]
  activate/wake up sleeping objects" — waking propagates through the whole contact *island*, so a
  shot that wakes a hand wakes the torso and legs too.

We do wake on impulse (`cg_ragdoll.c:1542-1548`) — that part is right. What we do **not** do is
suspend the rest machinery afterwards. Two consequences, both **PROVEN** against `:1731-1747`:

- The struck point can be dead-stopped by `RagResolveHit` on the very next substep despite having
  been woken 8 ms earlier. Nothing in `RagResolveHit` consults `limpMs`.
- The body-level sleep gate averages `|pt − ptPrev|` over **all 15 points** (`:1731-1735`), so one
  limb moving at 150 u/s reads as `150/15 = 10 u/s` — sitting exactly on the 10 u/s threshold. And
  because the speed is sampled *after* the collision resolve, the struck point is already down to
  ~30 u/s by then (§4.2), giving a mean of ~2 u/s: **`sleepMs` starts accruing on the same frame the
  body was shot.** The 1000 ms hold means this does not truncate the (60 ms) motion today, but the
  metric is structurally blind to a single fast limb and must not be used as evidence that a
  reaction has finished.

### 5.3 Impulses directed into the ground

Rigid-body engines handle this almost for free, and the reason is §2.2. The impulse contributes
`r × J` to angular momentum about the limb's own centre of mass. The floor can veto the *linear*
component (`J_n` is cancelled by the contact's normal impulse), but the *angular* component is
about an axis in the ground plane and is not cancelled: the limb **rolls / rotates** even though its
centre cannot descend. A hand shot from above flips over; a forearm shot from above pivots at the
elbow and the wrist comes up.

We have no angular state, so the entire downward impulse is a linear push into a plane, and the
plane absorbs 90 % of it in one contact (§4.2). **This is the specific reason downward shots read as
nothing at all in our build and read fine in Havok/PhysX games.**

Practices that address it, in shipping code and mods:

- **Torque pair** (the cheap fix available to us): `+J·a` distal, `−J·b` proximal, so the *sum* is
  the linear push and the *difference* is a couple about the segment's midpoint. The couple has a
  component parallel to the floor and therefore survives the contact.
- **Reflect rather than absorb** the into-surface component when the point is already in resting
  contact: the floor cannot accept downward momentum from a body already lying on it, so a real
  contact returns it as normal impulse. Our restitution 0.1 throws 90 % of it away as heat.
- **Minimum upward bias.** The explosion path already does a version of this
  (`cg_ragdoll.c:1506`: `n[2] += radius * 0.35f`). The bullet path does not.
- **Penetration recovery.** Shipping solvers push out of penetration with a *bounded bias velocity*
  (Baumgarte stabilisation, or Bullet's split impulse). Our two `startsolid` branches
  (`:1125-1141`) either freeze the point or release it entirely; both are non-physical and both have
  their own bug history in this file's comments.

### 5.4 The death handoff — how "the life comes out of their body"

The user's verbatim goal is a *handoff* description, and Source implements exactly it
([`ragdoll_shared.cpp`](https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/shared/ragdoll_shared.cpp)):

```cpp
void RagdollApplyAnimationAsVelocity( ragdoll_t &ragdoll, const matrix3x4_t *pPrevBones,
    const matrix3x4_t *pCurrentBones, float dt )
{
    for ( int i = 0; i < ragdoll.listCount; i++ )
    {
        Vector velocity;
        AngularImpulse angVel;
        int boneIndex = ragdoll.boneIndex[i];
        CalcBoneDerivatives( velocity, angVel, pPrevBones[boneIndex], pCurrentBones[boneIndex], dt );

        AngularImpulse localAngVelocity;
        ragdoll.list[i].pObject->WorldToLocalVector( &localAngVelocity, angVel );
        ragdoll.list[i].pObject->AddVelocity( &velocity, &localAngVelocity );
    }
}
```

Source differentiates the **animation's own bone matrices** across one frame and hands each ragdoll
body both a linear and an **angular** velocity. The animator's fall becomes the physics' initial
condition — literally "the life comes out of the body, they fall in one direction or another, and
physics does the rest."

Our SETTLE branch (`cg_ragdoll.c:1978-1986`) captures a **static** landed pose with zero velocity
(`ptPrev = pt` at `:611`, `:639`) and then drapes. That is a defensible, deliberate choice — round 8
took it because arming at the `EF_DEAD` edge photographed a standing soldier — and it is **not**
part of the current complaint, which is about post-death reaction. Recorded here so a future round
knows the shipping alternative exists and what it costs (it needs two consecutive bone-matrix sets,
which `ForceUpdatePose` + `TIKI_Orientation` can produce).

---

## 6. What "good" looks like, numerically

### 6.1 First principles

A rifle round: 10 g at 800 m/s ⇒ momentum `p = 8 N·s`.
Dempster's segment mass fractions for an 80 kg human: forearm 1.6 %, hand 0.6 % ⇒ forearm+hand
≈ 1.76 kg.

```
  Δv = 8 / 1.76 = 4.5 m/s = 179 in/s ≈ 179 MOHAA u/s      (naive, limb centre)
  pinned at the elbow, tip speed = 3 × Δv ≈ 537 u/s        (§2.2)
```

Thigh (10 % ⇒ 8 kg): `Δv = 1.0 m/s = 39 u/s`. Whole body (80 kg): `Δv = 0.1 m/s = 4 u/s` — which is
why real bodies are *not* thrown by bullets, and why a corpse should move mostly at the struck limb.

**Our injection band (150–360 u/s on the struck point) sits correctly between the 179 u/s limb value
and the 537 u/s tip value.** Do not raise it. Raising it was the wrong lever in rounds 9–11.

### 6.2 What Source ships

[`takedamageinfo.cpp`](https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/shared/takedamageinfo.cpp):

```cpp
float ImpulseScale( float flTargetMass, float flDesiredSpeed )
{
    return (flTargetMass * flDesiredSpeed);
}

void CalculateExplosiveDamageForce( CTakeDamageInfo *info,
    const Vector &vecDir, const Vector &vecForceOrigin, float flScale )
{
    info->SetDamagePosition( vecForceOrigin );
    float flClampForce = ImpulseScale( 75, 400 );
    float flForceScale = info->GetBaseDamage() * ImpulseScale( 75, 4 );
    if( flForceScale > flClampForce )
        flForceScale = flClampForce;
    flForceScale *= random->RandomFloat( 0.85, 1.15 );
    ...
    vecForce *= phys_pushscale.GetFloat();
```

Read the units: `ImpulseScale(75, 4)` is "the impulse that gives a 75 kg body 4 units/s".

- **1 point of damage = 4 u/s on a 75 kg body.**
- **Explosions clamp at 400 u/s on a 75 kg body** — i.e. a whole-body Δv ceiling.
- Source units are ~0.75 inch, so 400 Source u/s ≈ **300 MOHAA u/s** whole-body.
- `phys_pushscale` default 1, `FCVAR_REPLICATED` — a shipped, user-visible tuning knob, precedent for
  our `coop_ragdoll*` family.
- `RandomFloat( 0.85, 1.15 )` — Source randomises explosion force ±15 %. Our per-point variation
  (`cg_ragdoll.c:1513`: `0.55 + 0.9·hash`, i.e. 0.55–1.45, ±45 %) is 3× wider, which is defensible
  for a *per-point* rather than per-body variation but is worth knowing.

Our explosion force of 400–460 u/s applied per point is therefore at Source's *whole-body clamp*,
per point. It is not too weak. It never gets to act (§3.4).

### 6.3 Target behaviour, as acceptance numbers

Derived from the above plus what reads on screen at MOHAA's scale (72 u tall soldier, 11 u forearm,
17 u thigh):

| quantity | target | today (derived, §4) |
|---|---|---|
| struck-limb travel, grazing hit | **6–20 u** (a 30–90° swing) | 2.15 u |
| struck-limb travel, downward hit | **3–10 u** (roll/pivot) | 0.22 u |
| whole-body translation per hit | **1–4 u** (visible, not a shove) | dominant term |
| reaction duration before re-settle | **250–700 ms** | 24–60 ms |
| deceleration to rest | **200–350 u/s²** | 6 750 u/s² |
| new resting pose retained after the hit | **yes** | no — snaps back in 88 ms |
| body slides when shot | **yes, a little** (Source does; `phys_pushscale 1`) | yes, and it is the *only* thing that happens |

On the last row: shipping games **do** let a shot corpse move as a whole, a little. Half-Life 2
ragdolls visibly shift when shot. The user is not asking us to eliminate that — they are asking for
it to stop being the *only* response.

---

## 7. Process finding — we are flying blind

```
$ grep -c "RAGDOLL impulse" _research/ragdoll_r9_session_live.log   → 0
$ grep -c "RAGDOLL impulse" _research/ragdoll_r8_session_1230.log   → 0
$ grep -c "RAGDOLL impulse" _research/ragdoll_p3_session_2200.log   → 0
$ grep -c "RAGDOLL"         G:/mohaa-gl2/home/maintt/qconsole.log   → 0
```

The two archived sessions predate the impulse commits (`27f90ff1` onward). The live log covers
16:24–16:27 today and contains **no `RAGDOLL` lines at all**, so that session ran with
`r_ragdollDebug 0` or produced no corpses.

**Nothing on this machine demonstrates that a single `CG_RagdollImpulse` call has ever reached a
running sim.** Every impulse tuning decision in commits `27f90ff1`, `cad7efcb`, `663bd1bd`,
`a0122287`, `15a8f5c5` was made from eyeball reports against unmeasured code. Before any further
tuning, the next session must produce at least one `^~^~^ RAGDOLL impulse` line. This is the cheapest
high-value action in this document.

The existing print (`cg_ragdoll.c:1551-1554`) is also too thin to diagnose with — it reports
`force/radius/limp` (which we already know, they are constants) and nothing about what was hit.
See §8, Tier 0c.

---

## 8. The minimum change, ranked

Every tier is behind a cvar so rollback is one console line and the user's one-build-per-session
budget is respected. Tiers 0 and 1 together are the recommendation; they are one build.

### Tier 0 — bug fixes, no design change

**0a. Clamp the limp factor.** `cg_ragdoll.c:937-938`. Either clamp the result to `[0, 1]`, or use
the actual window length instead of the constant. The second is better because it preserves the
intent (a longer limp for explosions):

```c
if (s->limpMs[i] > 0) {
    float win = (float)s->limpMax[i];            /* store the window at impulse time */
    float k   = 1.0f - (float)s->limpMs[i] / (win > 1.0f ? win : 1.0f);
    if (k < 0.0f) { k = 0.0f; }
    a *= RAG_IMPACT_RELAX + (1.0f - RAG_IMPACT_RELAX) * k;
}
```

Buys: removes the guaranteed explosion blow-up. Cost: one `short limpMax[RAG_PTS]` in `ragSim_t`,
set alongside every `limpMs` write (`:1464`, `:1474`, `:1535`). Risk: none — the current behaviour is
unambiguously a sign error.

**0b. Hoist the `VectorNegate`** above the `if (flesh_impact_count < MAX_IMPACTS)` at
`cg_parsemsg.cpp:1800-1802` (and the three sibling sites `:1812`, `:2224`, `:2236`). One line each.

**0c. Make the impulse print diagnostic.** Extend `:1551-1554` with the struck segment, the
point-to-segment distance, the post-clamp `Δv`, and the contact state of the struck point; add a
`travel=` accumulator on the struck point (world distance from impulse to re-sleep) and print it in
the `RAGDOLL sleep` line. Without `travel=` this whole question stays an eyeball argument.

### Tier 1 — make the contact resolve physical (this is the fix)

All four behind one master `coop_ragdollImpact` (default 1, `0` = today's behaviour verbatim), so
the A/B is a keypress.

**1a. Coulomb-bound the tangential impulse.** Replace `:1060`'s `v_t *= 0.45` with a bound on the
*change*: the tangential speed removed this contact may not exceed `μ × |Δv_n|`, where `Δv_n` is the
normal impulse actually applied this contact. On a resting point `|Δv_n| ≈ g·dt = 0.0328 u/substep`,
so at μ = 0.9 the floor removes at most 0.03 u/substep of tangential speed — 57 u of slide instead of
2 u (§4.4). *This single change is the largest single win in this document.*

**1b. Lower the dead-stop gate** from 0.35 u/substep to ~0.08 (10 u/s, Doom 3's `STOP_SPEED`), and
require it on **3 consecutive substeps** rather than firing on the first. Both numbers behind
`coop_ragdollRest` so they can be walked back live if bodies start skidding.

**1c. Suspend the dead-stop while `limpMs[i] > 0`.** A struck point is by definition not at rest.
This is our equivalent of the unconditional `Activate()` every shipping engine performs (§5.2). Two
lines at `:1053`.

**1d. Do not absorb the into-floor component.** When the struck point is in resting contact and
`dir · plane.normal < 0`, reflect the normal component instead of scaling it by 0.1 — or, simpler,
add a `+z` bias to the bullet impulse mirroring what the explosion path already does at `:1506`.
Behind `coop_ragdollKick` (default ~0.3, `0` = off).

Expected combined effect (**INFERRED**, from §4.4 + §3.2): grazing hits swing 20–60 u before the
joint limits and damping arrest them — probably *too much*, which is the correct problem to have,
because it is tuned down with one cvar rather than up with a redesign.

### Tier 2 — let the corpse keep its new shape

**2a. Re-baseline `goal[]` when a struck body re-sleeps.** One `memcpy(s->goal, s->pt, ...)` at the
sleep transition (`:1747-1748`) when `lifeMs` includes an impulse. Buys: the corpse keeps the pose
the bullet gave it, instead of snapping back (§3.5). Small, high visual value, zero stability risk —
`goal` is only ever read as a target.

**2b. Limp the whole limb chain including the parent.** Today the proximal point is skipped entirely
when `w[1] = 0.15(1 − bestT) < 0.05`, i.e. whenever `bestT > 0.667` (`:1453-1464`). Set
`limpMs[bestP]` unconditionally, outside the weight test.

### Tier 3 — synthesise the missing angular impulse

**3a. Torque-equivalent point pair** (§3.3.2, §5.3). Change the proximal weight's **sign** so the
struck segment receives a couple rather than a push: `+J·a` distal, `−J·b` proximal with
`a − b = 1` (linear impulse preserved) and `a + b` setting the couple. This is the cheapest possible
stand-in for an inertia tensor and it is the mechanism that makes downward shots read.

**3b. Soften the distance constraints on the struck link during the limp window.** `RAG_ITERS 6`
stiff passes (`:974-987`) plus 16 braces (`:988-1010`) is what redistributes the hit into the whole
tree. Halving the iterations on links whose either endpoint has `limpMs > 0` is a few lines.

### Tier 4 — replace the solver (do NOT)

15 rigid bodies with orientations, inertia tensors, ball-socket/cone-twist joints, and a
sequential-impulse solver. This is idTech4's `idPhysics_AF` — a ~5 000-line file. It would give us
correct articulation for free and throw away every stability property that eleven rounds bought.
Recorded for completeness and as a boundary, not as a proposal.

---

## 9. Acceptance tests and rollback

One build. `r_ragdollDebug 1` for all three.

**T1 — the headline. Grazing shot on a settled corpse.**
Kill a soldier, wait for `^~^~^ RAGDOLL sleep`, then shoot its forearm from the side.
PASS: a `^~^~^ RAGDOLL impulse` line appears **and** the follow-up `RAGDOLL sleep` reports
`travel=` ≥ **6.0** on the struck point (Tier 0c instrument), and the limb is visibly displaced from
where it was.
FAIL today (predicted, §4.3): `travel≈2.2`.

**T2 — downward shot.** Same corpse, shoot straight down into the chest or an arm.
PASS: `travel=` ≥ **3.0**.
FAIL today (predicted, §4.2): `travel≈0.2`.

**T3 — explosion.** Grenade beside a settled corpse.
PASS: **no** `^~^~^ RAGDOLL blowup` line, limbs fan and re-settle in a changed pose.
FAIL today (predicted, §3.4): `blowup ent=N reason=span` or `reason=leash`.

**T4 — no regression.** Ten kills, no shooting.
PASS: ≥ 9 reach `RAGDOLL sleep`, zero `blowup`, `spinmax` ≤ 5 deg/s, `stretch` ≤ 1.10, and no corpse
visibly creeps after settling.

**Rollback, in order of blast radius, all console-only, no rebuild:**

```
coop_ragdollImpact 0     // revert the whole Tier-1 contact change; Tier 0 fixes stay
coop_ragdollKick 0       // just the upward bias
coop_ragdollRest 0.35    // just the rest gate, back to today's value
coop_ragdoll 0           // ragdolls off entirely (CVAR_ARCHIVE, survives relaunch)
```

Tier 0a is a sign-error fix and is deliberately **not** behind a cvar — there is no version of the
current behaviour worth preserving.

---

## 10. Sources

- [Bullet — `btRigidBody.h`](https://github.com/bulletphysics/bullet3/blob/master/src/BulletDynamics/Dynamics/btRigidBody.h) — `applyImpulse` / `applyTorqueImpulse`; `m_linearSleepingThreshold 0.8`, `m_angularSleepingThreshold 1.0`, `m_friction 0.5`, `m_restitution 0.0`.
- [Bullet — `btSequentialImpulseConstraintSolver.cpp`](https://github.com/bulletphysics/bullet3/blob/master/src/BulletDynamics/ConstraintSolver/btSequentialImpulseConstraintSolver.cpp) — friction limits bounded by the accumulated normal impulse.
- [Bullet — `btRigidBody` class reference](https://pybullet.org/Bullet/BulletFull/classbtRigidBody.html) — sleeping bodies remain in the broadphase so active objects can wake them.
- [id Software — `Physics_RigidBody.cpp` (Doom 3 GPL)](https://github.com/id-Software/DOOM-3/blob/master/neo/game/physics/Physics_RigidBody.cpp) — `ApplyImpulse`, `Activate`, `STOP_SPEED 10.0f`, `SetFriction(0.6, 0.6, 0.0)`, `SetBouncyness(0.6)`.
- [id Software — `Physics_AF.h` / `Physics_AF.cpp`](https://github.com/id-Software/DOOM-3/blob/master/neo/game/physics/Physics_AF.cpp) — `NO_MOVE_TIME 1.0`, `NO_MOVE_TRANSLATION_TOLERANCE 10.0`, `NO_MOVE_ROTATION_TOLERANCE 10.0`, `SUSPEND_LINEAR_VELOCITY 10.0`, `SUSPEND_ANGULAR_VELOCITY 15.0`, `suspendVelocity` / `noMoveTime` semantics.
- [id Software — `AF.cpp`](https://github.com/id-Software/DOOM-3/blob/master/neo/game/AF.cpp) and [`AFEntity.cpp`](https://github.com/id-Software/DOOM-3/blob/master/neo/game/AFEntity.cpp) — `idAF::ApplyImpulse`, `idAFEntity_Base::ApplyImpulse`, `BodyForClipModelId`.
- [idTech4 ModWiki — Af (decl)](https://modwiki.dhewm3.org/Af_(decl)) — articulated-figure declaration: collision bodies and joint constraints replacing a static death animation.
- [NVIDIA — `PxRigidBody` (PhysX 5.3)](https://nvidia-omniverse.github.io/PhysX/physx/5.3.1/_api_build/class_px_rigid_body.html) — `addForce(..., autowake = true)`; impulses wake sleeping actors by default.
- [Valve — `takedamageinfo.cpp` (Source SDK 2013)](https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/shared/takedamageinfo.cpp) — `ImpulseScale`, `CalculateBulletDamageForce`, `CalculateExplosiveDamageForce`, `phys_pushscale`.
- [Valve — `ragdoll_shared.cpp` (Source SDK 2013)](https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/shared/ragdoll_shared.cpp) — `RagdollActivate`, `RagdollApplyAnimationAsVelocity`, `g_ragdoll_maxcount`.
- [Valve Developer Community — `prop_ragdoll`](https://developer.valvesoftware.com/wiki/Prop_ragdoll) — VPhysics ragdolls as constrained collections of physics objects.
- [Thomas Jakobsen, *Advanced Character Physics*, GDC 2001 (PDF)](https://www.cs.cmu.edu/afs/cs/academic/class/15462-s13/www/lec_slides/Jakobsen.pdf) — the Verlet particle ragdoll we implement; "move the particle positions proportionally to the force… velocities will be adjusted automatically".
- [GDC Vault — *Physics Driven Ragdolls and Animation at EA: From Sports to Star Wars*](https://www.gdcvault.com/play/1025210/Physics-Driven-Ragdolls-and-Animation) — driven ragdolls that follow animation and react to interactions; the modern form of our shape-match, done with joint motors rather than positional pulls.
- [ezEngine — Jolt Ragdoll Component](https://ezengine.net/pages/docs/physics/jolt/ragdolls/jolt-ragdoll-component.html) — powered mode: joints act as muscles moving the ragdoll toward a desired pose, typically to play a death animation before going limp.
