# Ragdoll R13 — Living hit reactions: RISK AND STAGING

**Lens:** risk and staging. Not a design doc — a list of what can go wrong, what is provably
safe, and the smallest ordered sequence of builds that answers one question each.

**Date:** 2026-08-20. **Status:** analysis only, nothing built.

**Scope:** the user's ask after ten rounds of corpse work — *"if their bodies would react
similarly to shots too that would be great"* — i.e. a **procedural hit reaction on a LIVING
soldier**: a partial, blended, physically-driven overlay on one limb, on an actor who is
being animated every frame and must keep running, firing and taking cover.

---

## 0. Verdict up front

| Question | Answer |
|---|---|
| Can a per-channel render blend affect server hit detection on a listen host? | **No. Proven from the code — the two paths do not share a single mutable object.** §1 |
| ...are there designs that CAN? | **Yes, three of them, and one is the obvious first idea.** §1.4 — reject on sight |
| Should living reactions share the corpse implementation? | **No. Separate sim pool, separate renderer pool, separate code path, separate cvars.** §2 |
| Is the cost affordable at 16 visible actors? | **Only if living reactions do NO world collision and simulate ONE limb chain.** Reusing the corpse solver is ~20x too expensive. §3 |
| What is the single most likely silent regression? | **A corpse capturing its own living overlay as the "authored" death pose** — a permanent frozen kink on every soldier killed while flinching. §2.1 |
| What is the hardest unsolved problem? | **Targeting.** The flesh-hit message carries no entity number and no hit location. On a moving actor, geometric matching will land on the wrong limb. §4.6 |
| Should this be built? | **Not as scoped, not yet.** §6 makes the case against as hard as it can be made. The honest recommendation is §7. |

---

## 1. THE HARD CONSTRAINT — can a render blend alias server hit detection?

The rule from the ragdoll plan is that nothing may change what the *server* thinks a bone's
position is, because `tiki_cache` shares skeletors with the game module on a listen host.
This section traces both graphs to their terminals and states whether they can ever meet.

### 1.1 What the server actually reads

The server's bone-accurate hit detection is one chain, with no branches:

```
server/sv_world.c:585            SV_TraceDeep(&trace, clip->start, clip->end, ...)
                                   ^ gated on clip->traceDeep && touch->tiki->a->bIsCharacter (:581)
qcommon/cm_trace_lbd.cpp:486       orPosition = ge->TIKI_Orientation(touch, iBoneNum)
fgame/g_main.cpp:909               G_TIKI_Orientation(gentity_t*, int)
fgame/g_main.cpp:912                 G_UpdatePoseInternal(edict)      <-- SERVER RE-POSES FIRST
fgame/g_main.cpp:904                   gi.TIKI_SetPoseInternal(edict->tiki, edict->s.number,
                                                               edict->s.frameInfo,
                                                               edict->s.bone_tag,
                                                               edict->s.bone_quat,
                                                               edict->s.actionWeight)
fgame/g_main.cpp:914                 gi.TIKI_OrientationInternal(edict->tiki, edict->s.number,
                                                                num, edict->s.scale)
server/sv_game.c:1075                PF_TIKI_OrientationInternal -> TIKI_OrientationInternal
tiki/tiki_tag.cpp:94                 TIKI_OrientationInternal(...)
tiki/tiki_tag.cpp:100                  skeletor->GetBoneFrame(tagnum)     <-- THE TERMINAL
```

The terminal object is the **shared skeletor**, `skel_entity_cache[(entnum % TIKI_MAX_ENTITIES)
* TIKI_MAX_ENTITY_CACHE_PER_ENT + i]` (`tiki/tiki_cache.cpp:305-330`). It lives in the exe and
is handed to both the server (`sv_game.c:1308 PF_GetSkeletor`) and the renderer
(`client/cl_main.cpp:3356 ri.TIKI_GetSkeletor`). It is genuinely shared. This is the object the
plan is protecting.

**The load-bearing detail** is `fgame/g_main.cpp:895-906`: `G_TIKI_Orientation` never reads the
skeletor cold. It calls `G_UpdatePoseInternal` first, which — unless
`level.skel_index[entnum] == level.frame_skel_index` — **re-writes the skeletor from the
server's own `edict->s.frameInfo`** before the read. The latch namespace is server-owned:
`level.skel_index[]` / `level.frame_skel_index` (`fgame/level.h:225`, set at
`fgame/g_main.cpp:998` from the game frame number). The renderer's equivalent latch is a
*different* pair, `tr.skel_index[]` / `tr.frame_skel_index` (`renderergl1/tr_local.h:1445`,
`renderergl1/tr_model.cpp:1762`). Neither stamps the other's.

So: **the server re-poses from its own state, once per game frame, immediately before every
deep trace.** Whatever the client left in the skeletor is overwritten first.

### 1.2 What our bridge actually writes

The ragdoll override enters the pipeline at exactly two points, **both inside the renderer
DLL**:

* **Hook A** — `renderergl1/tr_model.cpp:857-859` (gl2: `tr_model.cpp:1243-1245`), inside
  `R_AddSkelSurfaces`, calls `R_RagdollApplyToCache(slot, coopCacheStart, num_tags, newFrame)`.
  That function (`renderergl1/tr_ragdoll.cpp:113-170`) writes **only** `skelBoneCache_t *cache`,
  which is `&TIKI_Skel_Bones[TIKI_Skel_Bones_Index]` (`tr_model.cpp:761`).
* **Hook B** — `renderergl1/tr_model.cpp:1817-1820`, inside `RE_TIKI_Orientation`, returns
  `R_RagdollGetOrientation(...)` from the slot table before falling through to
  `ri.TIKI_OrientationInternal`.

`RE_SetRagdollPose` (`tr_ragdoll.cpp:52-87`) writes only `s_ragSlots[]` and
`s_ragSlotPlusOne[]`, both file-static in the renderer DLL.

### 1.3 Do the two graphs share anything mutable? — **No.**

Three independent reasons, each sufficient on its own:

1. **`TIKI_Skel_Bones` has no server reader.** A full-tree grep returns exactly six live sites:
   `renderergl1/tr_model.cpp:761,765,865,866,1252`, `tr_ragdoll.cpp` via the `cache` parameter,
   plus the gl2 mirrors (`tr_model.cpp:1113,1117,1122,1251,1252,1724`). Producer is
   `R_AddSkelSurfaces` (frontend), consumer is `RB_SkelMesh` (backend, `tr_model.cpp:1252`),
   reset once per scene by `TIKI_Reset_Caches()` (`tiki/tiki_mesh.cpp:47`). Nothing in
   `fgame/`, `server/` or `qcommon/` touches it. It is a **render scratch pool that happens to
   be declared in the shared `tiki/` directory**, nothing more.

2. **Hook B is on the wrong side of the fence.** The server calls
   `gi.TIKI_OrientationInternal` (`fgame/g_main.cpp:914`), which routes to
   `PF_TIKI_OrientationInternal` (`server/sv_game.c:1075`) and straight into
   `tiki/tiki_tag.cpp:94`. It **never calls `RE_TIKI_Orientation`** — that is a renderer export
   (`renderergl1/tr_init.c`, `re.TIKI_Orientation`), reachable only through `re.*` from the
   client. The ragdoll intercept sits in `RE_TIKI_Orientation`, one level *above*
   `TIKI_OrientationInternal`, so the server's path passes underneath it.

3. **`CL_TraceDeep` — the client's own deep trace, which DOES read through the renderer
   (`cm_trace_lbd.cpp:578 re.TIKI_Orientation`) — has zero callers.** A whole-tree grep for
   `CL_TraceDeep` outside its own definition returns nothing. It is dead code in this build.
   The only live deep trace is `SV_TraceDeep`, called once, from `server/sv_world.c:585`.

**Conclusion, stated definitively: a per-channel render blend implemented through
`RE_SetRagdollPose` / `R_RagdollApplyToCache` / `R_RagdollGetOrientation` cannot affect server
hit detection on a listen host. There is no shared mutable object between the two graphs. The
feature does NOT need redesigning on this axis.**

### 1.4 Three designs that WOULD alias — reject on sight

The safety above is a property of *where we write*, not of the feature. Three plausible
implementations break it, and one of them is the first thing anyone would try:

| Design | Why it aliases | Evidence |
|---|---|---|
| **Server-side bone controllers** — set `edict->s.bone_tag[n]` / `bone_angles[n]` to deflect the struck limb. The obvious idea: one line, networks for free, works for every client. | `bone_tag`/`bone_quat` are arguments to `TIKI_SetPoseInternal` (`g_main.cpp:904-906`), which is the **writer of the shared skeletor**. The server's own `SV_TraceDeep` would then trace against the deflected bone. You would be moving the hitbox with the flinch. | `q_shared.h:2188-2189`; already in use for aim: `actor.cpp:3765,3817,3838` set `TORSO_TAG`/`HEAD_TAG`/`ARMS_TAG`. Only `NUM_BONE_CONTROLLERS 5` exist (`q_shared.h:2121`) and 3 are taken. |
| **Client `ForceUpdatePose` with doctored `frameInfo`, per frame.** | `RE_ForceUpdatePose` (`tr_model.cpp:1793-1805`) calls `ri.TIKI_SetPoseInternal` on the shared skeletor and **bypasses the `tr.skel_index` latch** — it stamps and always writes. Called from cgame (`CG_RagdollFrame`, `cg_view.c:2928`) it lands outside the renderer's frame ordering. It does not corrupt the server's *own* frame (the server re-poses, §1.1), but it removes the property that makes the current code obviously safe. | `cg_ragdoll.c:607 cgi.ForceUpdatePose(&model)` — the corpse path does this **once, at capture**. Per-frame is a different animal. |
| **Anything that writes `skeletor->GetBoneFrame()` directly.** | That is the terminal the server reads. | `tiki/tiki_tag.cpp:100` |

**Standing rule to carry into the spec: the living overlay writes `s_ragSlots[]` and nothing
else. If a proposal touches `TIKI_SetPoseInternal`, `bone_tag`, `bone_quat`, or the skeletor,
it is rejected regardless of how good it looks.**

### 1.5 The one narrow ordering caveat (pre-existing, vanilla, not made worse)

`level.skel_index[]` latches the server's re-pose to once per game frame. If the client wrote
the shared skeletor *between* the server's first and second deep trace within a single game
frame, the second trace would read the client's pose. On a listen host `SV_Frame` and
`CL_Frame` run sequentially inside `Com_Frame`, so the window does not open — but it is an
ordering assumption, not an invariant, and it is **vanilla**: `R_UpdatePoseInternal`
(`tr_model.cpp:1770-1786`) already re-poses every visible skeletal entity every rendered frame.

The corpse feature adds exactly one extra write to this (the capture-time `ForceUpdatePose`,
`cg_ragdoll.c:607`) and it writes the entity's own server `frameInfo`, so it is idempotent with
what the server would write. **A living design must preserve that property: at most one pose
write per reaction, using the entity's own unmodified `frameInfo`, never per frame.**

---

## 2. REGRESSION SURFACE on the corpse feature

The corpse feature works today (~98% coverage, `swing=60.5deg` measured, freeze drill clean).
Every shared object below is a way to break it.

### 2.1 ⚠ THE MARQUEE RISK: a corpse capturing its own living overlay

**This is the one to design against first, because it is silent and permanent.**

`RagCapture` reads the authored pose through `cgi.TIKI_Orientation(&model, ch)`
(`cg_ragdoll.c:609`). That symbol is wired at `client/cl_cgame.cpp:813` to
`re.TIKI_Orientation` = **`RE_TIKI_Orientation`, which is Hook B**. Hook B returns the ragdoll
override whenever a slot exists for that entity (`tr_model.cpp:1817-1820`).

Today this is safe by accident: `RagAllocSlot` refuses if `RagSimFor(entnum)`
(`cg_ragdoll.c:2029`), and eviction calls `CG_RagdollClearEnt` → `cgi.R_ClearRagdoll`
(`cg_ragdoll.c:397-399`), so no corpse is ever captured while its own renderer slot is live.

Add living reactions and that stops being true. Sequence:

1. Soldier is hit at t=0. The living overlay arms and pushes a deflected forearm.
2. Soldier dies at t=180 ms, still inside the reaction window.
3. `CG_RagdollTransition` records a pending (`cg_ragdoll.c:2333-2360`).
4. Death anim plays; server parks the corpse; `RagPendingThink` calls `RagCapture`.
5. `RagCapture` calls `cgi.TIKI_Orientation` → **Hook B → our own deflected overlay.**
6. The corpse settles from a pose the animator never authored, with a bent arm frozen into
   `mat0[]` for the rest of the body's life.

**What the player sees:** every enemy killed while flinching lies with one arm kinked at a
wrong angle. It never self-corrects — `mat0` is the shape-match target. It looks exactly like a
new corpse bug, and every previous corpse bug (1962/1963/1964/1966/1970) was diagnosed by
comparing against the authored pose, which would now be poisoned.

**Mitigations, in order of preference:** (a) clear the living overlay and call the living pool's
`R_Clear*` on the `EF_DEAD` rising edge, *before* the pending is recorded — the edge is already
detected at `cg_ragdoll.c:2246-2251`; (b) keep living overlays in a **separate renderer slot
pool that Hook B does not consult**; (c) add an unhooked orientation accessor for capture.
Do (a) + (b), with (a) as the belt.

### 2.2 The shared objects, enumerated

| Object | Where | Size | What a shared implementation breaks |
|---|---|---|---|
| `s_ragSlots[RAGDOLL_MAX_SLOTS]` | `tr_ragdoll.cpp:34`, 16 slots | 16 | **Hard cap.** `RE_SetRagdollPose` returns silently when the pool is full (`tr_ragdoll.cpp:77-79`) — no eviction, no log. Living reactions consuming slots would make corpses **silently stop overriding**: a settling body snaps back to its authored death pose mid-settle, with no console line. |
| `s_ragSlotPlusOne[MAX_GENTITIES]` | `tr_ragdoll.cpp:36` | 2048 **bytes** | It is a `byte`. Any slot-pool raise above 255 overflows it. Living reactions want a *bigger* pool; this is the ceiling. (`MAX_GENTITIES` = 2048, `GENTITYNUM_BITS 11`, `q_shared.h:1667-1668`.) |
| `s_ragSims[RAG_MAX_SIMS]` | `cg_ragdoll.c:250`, 16 | ~9.4 KB each | `RagAllocSlot` evicts only sleeping sims (`cg_ragdoll.c:2040-2047`). Living reactions never sleep — they run 300-600 ms and vanish — so they would either starve the corpse pool during their window or need eviction rules that let a *live* reaction be killed by a corpse. Both are worse than two pools. |
| `s_ragNeverArm[MAX_GENTITIES]` | `cg_ragdoll.c:251` | 2048 bytes | A corpse-lifecycle poison latch (NaN'd bodies keep the anim pose). Cleared on the clear-signal at `cg_ragdoll.c:2251`. If a living reaction sets it, a later corpse on the same entity silently refuses to ragdoll. |
| `R_RagdollApplyToCache` | `tr_ragdoll.cpp:113` | — | **Overwrites `cache[i]` for every `i < min(num_tags, slot->count)` unconditionally.** There is no per-channel weight and no notion of a partial write. A living blend needs one; adding it changes the function every corpse also runs through. |
| `CG_RagdollImpulse` | `cg_ragdoll.c:1443` | — | Already does an untargeted geometric search over **all** active sims (`:1499`). Adding living sims to the same loop means a bullet near a corpse can flinch a living man standing next to it, and vice versa. |
| `rag_debug` / `r_ragdollDebug` | `cg_ragdoll.c:317` | — | The corpse sleep lines (`^~^~^ RAGDOLL sleep` / `sleep-rot`) are the only instrument that made rounds 8-12 tractable. Living reactions firing at ~10 Hz on 16 actors would bury them. |

### 2.3 Recommendation: **separate pool, separate code path, both sides**

* New cgame file `cg_hitreact.c`, new struct, new pool (`HR_MAX 8`), new cvars under
  `coop_hitReact*`, new debug cvar `coop_hitReactDebug`.
* New renderer slot pool `s_hrSlots[8]` and a **new bridge export** appended after
  `ClearAllRagdolls` in both `renderercommon/tr_public.h:189-191` and `cgame/cg_public.h:453-455`
  (append-only, so the ABI stays compatible — the existing three were added the same way; see
  the "appended; NULL when the renderer lacks it" comment at `cg_public.h:452`).
* **Hook B must NOT consult the living pool.** Attachments on a living actor (his rifle) ride
  the authored pose. That is correct — a flinching soldier's rifle should stay in his hands, and
  letting the weapon swing with a procedural forearm is a much worse artifact than the forearm
  not carrying it.

Shared code is limited to the pure math helpers (`RagMat3*`, `cg_ragdoll.c:403-540`), which
should be moved to a header or left duplicated. Duplicating 140 lines of matrix helpers is
cheaper than one silent corpse regression.

**Cost of separation:** one more renderer pool (8 × ~6.4 KB ≈ 51 KB of BSS), one more bridge
export, ~400 lines of new cgame. **Benefit:** the corpse feature's behaviour is bit-identical
with the living feature off, which makes the rollback below *real* rather than nominal.

---

## 3. PERFORMANCE

### 3.1 What one corpse costs today, per frame at 60 fps

`cg.frametime` ≈ 16.7 ms, `RAG_SUBSTEP_MS 8` (`cg_ragdoll.c:59`), `RAG_MAX_STEPS 4` (`:60`)
→ **2 substeps** typical.

| Item | Per substep | Per frame | Site |
|---|---|---|---|
| Verlet integrate | 15 pts × ~20 flops + 15 `VectorLength` | 30 sqrt | `cg_ragdoll.c:990-1005` |
| Constraints | `RAG_ITERS 6` × (14 parent links + `RAG_BRACES 16`) = **180 solves**, each one `VectorLength` | **360 sqrt** | `:1009-1044` (`RAG_ITERS` at `:62`) |
| Shape-match | 15 pts | 30 | `:1084` → `RagShapeMatch:940` |
| **World collision** | up to **15 `CM_BoxTrace`** | **up to 30 full BSP traces** | `:1163-1205` |
| Mover collision | — | 1 bounds query + up to `RAG_MOVER_PER_BODY 60` traces | `:1207`, `:64` |
| `RagPush` | — | 15 swing builds + **72 channels** × (9-mul rotate + 27-mul 3×3×3 + 3 dots) ≈ **3.2k multiplies** + a **3,456-byte memcpy** | `:1299-1398`; memcpy at `tr_ragdoll.cpp:83` |
| Hook A, **per view** | — | 72 × 12 override writes + 72 × 12 animPose stashes = **1,728 float writes** | `tr_ragdoll.cpp:113-170` |

**Measured, not estimated:** the sleep lines in `_research/ragdoll_r12_session_swing.log` carry
`worldtr=15` and `worldtr=30` — the per-frame world-trace count across all live bodies at that
instant. So the *current* live load is 15-30 box traces per frame total.

View multiplier: gl1 renders ~1 view; **gl2 adds 4 sun-cascade views**, documented at
`tiki/tiki_mesh.h:10-16` as a ~5x bone-pool multiplier. Hook A therefore costs ~8,640 float
writes per body per frame under gl2.

### 3.2 What 16 living actors would cost if they reused the corpse solver

16 × (30 box traces + 360 sqrt + 3.2k mul + 3.4 KB memcpy) =

* **480 additional `CM_BoxTrace` per frame** — for scale, `RAG_TRACE_BUDGET` is 240 for movers
  *alone* (`cg_ragdoll.c:63`), and that ceiling exists because mover collision silently died
  from the 4th corpse onward (bug-1967).
* **5,760 sqrt/frame**, ~51k multiplies, ~55 KB/frame of memcpy into the renderer.
* Hook A: 16 × 1,728 = 27,648 float writes/frame (gl1), **~138k under gl2**.

**Verdict: reusing the corpse solver for living actors is not affordable.** The box traces alone
roughly triple the feature's worst-case trace load, and they buy nothing — see below.

### 3.3 What it should cost instead

A living hit reaction does not need world collision. The actor's own animation already keeps him
out of walls; a forearm flinching 15° does not need to be swept against the BSP. **Drop
`RagCollideWorld` and `RagCollideMovers` entirely: 0 traces.** This also removes the subsystem
where bugs 1962, 1967 and 1970 all lived.

It also does not need 15 points. The struck limb chain is 3 points and 2 links (upperarm →
forearm → hand), or for a torso hit, 3 spine points.

| Item | Recommended shape | Per body per frame |
|---|---|---|
| Points | 3 (one limb chain) | 6 sqrt |
| Constraints | 2 links × 6 iters × 2 substeps | 24 sqrt |
| World traces | **none** | **0** |
| Channels written | **3-6**, not 72 — needs a channel list in the bridge (§3.4) | ~270 mul, ~288-byte memcpy |

16 concurrent: **0 traces, ~480 sqrt, ~4.3k mul, ~4.6 KB/frame.** Roughly **1/20th** of §3.2 and
comfortably below the corpse feature's existing load.

### 3.4 The channel-write problem, and why the blend must NOT be a matrix lerp

Three findings that constrain the bridge design:

1. **`R_RagdollApplyToCache` writes every channel, deliberately.** The comment at
   `tr_model.cpp:849-855` explains why: the vanilla copy at `tr_model.cpp:826-847` is
   **cull-gated** (`iRadiusCull != CULL_CLIP || R_CullSkelModel(...) != CULL_OUT`), so when the
   cull skips it, `cache[i]` holds stale pool garbage. Writing every channel unconditionally is
   what closes that hole. **A partial write must therefore still write untouched channels — from
   `newFrame`, which `R_RagdollApplyToCache` already has in hand as its 4th parameter.** With
   weight 0 that reproduces the vanilla copy exactly and keeps the hole closed.

2. **Do not lerp rotation matrices.** A component-wise lerp between two rotation matrices is not
   a rotation: for 0 < w < 1 it is non-orthonormal, and the skinner (`SkelWeightGetXyz`,
   `tr_model.cpp:1033`) will shear and scale the mesh. The corpse code never hits this because it
   always pushes a full rotation. **The safe place to blend is in cgame, on the swing direction,
   before composition:** `RagPush` builds `S = RagMat3FromTo(ref, dNow)` (`cg_ragdoll.c:1348`).
   Slerping `dNow` toward `ref` by the weight and *then* building `S` keeps `S` orthonormal by
   construction at every weight, and costs nothing extra. This also means **the rotation path
   needs no renderer change at all.**

3. **The base pose has to come from somewhere.** cgame needs the actor's current authored pose
   each frame to blend against. `cgi.TIKI_Orientation` is Hook B (§2.1) and would return our own
   output. The clean source is `slot->animPose`, which the renderer already stashes every frame
   and **nothing has ever read** (`tr_ragdoll.cpp:31,120-134`). Reading it back needs a 4th bridge
   export. Note it is **one frame stale**: `CG_RagdollFrame` runs at `cg_view.c:2928`, *before*
   entities are added, so at push time `animPose` holds the previous frame's pose. That is
   ~16.7 ms of uniform lag applied to base and target alike — invisible as a lag, but it means the
   overlay is composed against a pose that is not quite the one being rendered. **This is a
   Stage-L0 measurement, not an assumption** (§5).

### 3.5 Recommended caps and culling policy

| Control | Value | Derivation |
|---|---|---|
| `coop_hitReactMax` | **6** concurrent | 16 is the corpse pool's number and exists because corpses accumulate. Reactions last 300-600 ms; at the mod's own 1.2 s per-actor throttle (`aihandler.scr:1862`) six concurrent covers a heavy firefight. |
| Distance cull | **1024 u** | A 15° deflection on a ~12 u forearm moves the hand ~3 u. At 90° hFOV / 1920 px, centre-screen scale is (W/2)/tan(45°) = 960 px/rad, so 3 u subtends 2880/d pixels: **1 px at 2880 u, 3 px at 960 u**. Beyond ~1000 u the whole effect is sub-3-pixel. |
| PVS | **free** | `gi.SetBroadcastVisible(vTmpEnd, vBarrel)` (`weaputils.cpp:2620`) already gates the flesh-hit message to the impact's and the shooter's PVS. No extra work needed. |
| Frustum | skip actors not in `cg.snap->entities` this frame | same test the re-arm loop already uses (`cg_ragdoll.c:1461`) |
| Hard off-switch | `coop_hitReactProc 0` | §5 |

---

## 4. ABORT AND HANDOFF CASES

For each: how the client detects it, the policy, and **what the player sees if it goes wrong.**

### 4.1 Actor dies mid-reaction — the handoff

**Detect:** `EF_DEAD` rising edge, already computed at `cg_ragdoll.c:2301`
(`(cs->eFlags & EF_DEAD) || !(ns->eFlags & EF_DEAD)` guard) and the falling-edge clear signal at
`:2246-2251`.

**Policy:** on the rising edge, **before** the pending record is created (`:2333-2360`), force
the living overlay's weight to 0, push once at weight 0, and clear the living renderer slot. The
corpse path then proceeds exactly as today: pending → `RagServerParked` (`:2095-2104`) →
`RagCapture` reads the clean authored death pose.

**If it goes wrong:** §2.1 — a permanent frozen kink on every soldier killed while flinching.
This is the highest-severity failure in the whole feature and the reason the handoff must be
built in the first functional stage, not deferred.

**Second-order:** do *not* try to hand the reaction's momentum into the corpse sim. The corpse
path deliberately does not capture at the death edge — bug-1965 established that arming at the
edge photographs a standing soldier and produces "bodies don't fall like that". The authored
death animation owns the fall. A living reaction's velocity has no place in it.

### 4.2 Actor is a player

**Detect:** `ns->number < cgs.maxclients` — the corpse path already refuses these
(`cg_ragdoll.c:2303`).

**Policy:** keep refusing, unconditionally, and do not revisit. First person shows a viewmodel,
not the skeleton. Third person is another player's aim target, and a client-side deflection on a
player model is the one case where a viewer's render and the server's hitbox visibly disagree
even though §1 proves they *are* the same — because a human will read the deflected arm as the
target. Refusing costs nothing: players already have hit feedback (tinnitus, HUD, blood).

### 4.3 Actor is on a turret or in a vehicle

**Detect:** `es->parent != ENTITYNUM_NONE` (`q_shared.h:2173`, with `tag_num` at `:2174`).

**Policy:** refuse. This is not a taste call — `RagPush` converts world→model against
`cent->lerpOrigin` / `cent->lerpAngles` (`cg_ragdoll.c:1312-1313`), and for a **parented** entity
that is not the placement the renderer composes with (the parent's tag orientation is). Pushing
an override for a parented actor puts the whole mesh in the wrong place.

**If it goes wrong:** the MG42 gunner's body detaches from the gun and renders at the world-origin
offset — a whole-model teleport, the most visible artifact this feature can produce.

### 4.4 Actor is mid-scripted-anim (balcony deaths, set-pieces, `anim_scripted`)

**Detect:** **not detectable client-side.** There is no eFlag for it, and the client sees only
`frameInfo[]` weights, which cannot distinguish a scripted anim from a combat anim.

The corpse path finesses this by waiting for the *server* to park the corpse (`RagServerParked`,
`cg_ragdoll.c:2095-2104`) — a server-authored signal delivered via the 32-bit `entityState.solid`
netfield. There is no equivalent for a living actor.

**Policy: the server must decide eligibility, and say so on the wire.** The server already knows
everything needed — `self.position`, whether a custom `painhandler` is installed, whether the
actor is in a scripted anim — and the mod's own reaction layer already evaluates most of it
(`aihandler.scr:1848-1893`). A one-bit "procedural reaction is OK for this hit" flag, computed
where `coop_hitReact` is computed, is far more reliable than any client-side guess. **This makes
the wire change (§4.6) load-bearing, not optional.**

**If it goes wrong:** a soldier in a scripted fall gets a procedural arm deflection layered onto a
hand-animated set-piece. It reads as a glitch in a moment the level designer choreographed —
exactly the class of artifact the corpse path's gating exists to avoid.

### 4.5 Model or weapon changes mid-reaction

**Model:** `cs->modelindex != ns->modelindex` is already a clear signal
(`cg_ragdoll.c:2246-2251`), and the renderer has a second belt: `R_RagdollSlotFor` ignores a row
whose stored `tiki` does not match the refEntity's (`tr_ragdoll.cpp:44-46`). Reuse both.

**Weapon:** does not change `modelindex` — the weapon is a separate attached entity riding
Hook B. With the living pool excluded from Hook B (§2.3), a weapon swap during a reaction is a
non-event: the rifle stays on the authored hand orientation throughout.

### 4.6 The targeting problem — **the hardest unsolved case**

The flesh-hit message carries **position, direction, and 2 bits of "large"** and nothing else:

```
fgame/weaputils.cpp:2621-2646     MSG_StartCGM(CGM_BULLET_8)
                                  MSG_WriteCoord(vTmpEnd[0..2])      <- wound position
                                  MSG_WriteDir(vHitDir)              <- wound -> muzzle normal
                                  MSG_WriteBits(bulletlarge, bulletbits)
cgame/cg_parsemsg.cpp:1808        CG_RagdollImpulse(vStart, vEnd, 150+70*iLarge,
                                                    15.0+1.5*iLarge, 600+70*iLarge)
```

**No entity number. No hit location.** `CG_RagdollImpulse` finds its target purely by geometry:
nearest bone *segment* across all active sims, within a radius of **15.0-16.5 u**
(`cg_ragdoll.c:1508-1540`).

For a static corpse this is exact. For a living actor it degrades, and the numbers are bad:

* `sv_fps 40` in this deployment (`hzm-mohaa-coop-mod/autoexec.cfg:684`; engine default 20 at
  `server/sv_init.c:1108`) → **25 ms** snapshot interval. The client holds `cg.time` between
  `cg.snap->serverTime` and `cg.nextSnap->serverTime` (`cg_snapshot.c:510,522-528`), so the
  rendered actor is **25-50 ms behind** the server pose the wound position was computed against.
* A running MOHAA soldier covers ~250 u/s → **6-12 u of body translation error** against a 15 u
  match radius. That is 40-80% of the budget spent before the limb pose is considered.
* The limb error is larger. A hand in a run cycle moves on the order of 100-200 u/s at the
  extremity → another **5-10 u** in the same window.
* Worst case ≈ **20 u of error against a 15 u radius.**

**And the failure is not a miss — it is a wrong answer.** The search always picks *some* segment
(`bestJ`) and only bails on `bestD >= radius` (`cg_ragdoll.c:1541`). With ~15 u of error the
common outcome is the **wrong limb**: you shoot a running man in the chest and his thigh
twitches. That is worse than no reaction at all, and it is the exact artifact the user would
report as "it looks wrong".

**The server already has the right answer.** At the message site, `trace.location >= 0` is the
gate (`weaputils.cpp:2605`) and `ent` is the sentient that was hit. `trace.location` indexes
`szLocArray[]` (`cm_trace_lbd.cpp:31-51`, `MAX_HITLOCATIONS 19`), a direct bone-name table —
`"Bip01 R Forearm"`, `"Bip01 L Thigh"`, etc. That is *exactly* the datum the client needs, and
the mod's own script layer already consumes it (`aihandler.scr:1864-1872` maps
`self.fact.location` to head/back/rarm/larm/leg).

**Recommendation:** send a **new coop-private CGM message** — entity number (11 bits,
`GENTITYNUM_BITS`, `q_shared.h:1667`), hit location (5 bits), eligibility flag (1 bit), plus the
existing position/direction — rather than widening `CGM_BULLET_8`. Reasons:

* `CGM_BULLET_8` stays byte-identical, so blood, tracers, and the corpse impulse are untouched
  and the corpse feature cannot regress from a wire change.
* The eligibility bit (§4.4) has nowhere else to live.
* One new message is a smaller blast radius than a changed one.

**Cost:** exe + `cgame.dll` + `game.dll` must ship together (the same lockstep class as
bug-1186's `MAX_SNAPSHOT_ENTITIES` change). Non-matching clients simply never see the message.

---

## 5. STAGING

Five stages. Each answers **one** question, carries **one** numeric instrument, and has a
**one-command rollback**. Living-actor features default **OFF**, unlike the corpse work.

**Master switch, present from Stage L0 and never removed:**

```
coop_hitReactProc 0     // 0 = OFF (default). The whole feature.
```

At 0 the living code path must not execute a single instruction beyond the cvar read, so the
corpse feature is bit-identical to today. Rollback is `coop_hitReactProc 0` — one command, no
restart, no rebuild.

---

### Stage L0 — the null build (**this is the safety proof, empirically**)

**Question:** does declaring a *living* entity to the bridge, with an identity overlay, change
anything on screen or in hit detection?

**Build:** on `coop_hitReactProc 1`, pick living actors within 1024 u and push a weight-0 overlay
every frame — i.e. reconstruct the authored pose and push it verbatim. This is the living
analogue of `coop_ragdollTest 2`'s freeze drill (`cg_ragdoll.c:233`, `:2377`), which is what
proved the corpse render round-trip pixel-perfect. **No deflection, no sim, no impact handling.**

**Instruments (two, both required):**

```
^~^~^ HITREACT null ent=%d chan=%d maxdev=%.3fu maxrot=%.3fdeg stale=%dms
```

`maxdev` / `maxrot` = the largest per-channel translation / rotation difference between what we
pushed and the renderer's own `animPose` for that frame. **Both must read 0.000.** A non-zero
`maxrot` means the animPose read-back is not the pose being rendered (the one-frame staleness of
§3.4 turning out to matter), and the whole approach needs rework before anything else is built.

```
^~^~^ HITREACT hitdrill loc=%d dist=%.0f     (existing: coop_bloodDebug 1, weaputils.cpp:2614)
```

**Acceptance drill:** stand in front of a running actor. Fire 20 rounds with
`coop_hitReactProc 0`, record the `loc=` distribution. Repeat with `coop_hitReactProc 1`. The
distributions must be **statistically indistinguishable**, and `maxdev` must be 0.000 throughout.
This is the live demonstration that §1's proof holds in the built binary.

**Rollback:** `coop_hitReactProc 0`.

**Stop condition:** if `maxdev != 0` or the `loc=` distributions differ, **stop the feature
here.** Everything downstream assumes this stage is clean.

---

### Stage L1 — one bone, one hit, deliberately over-driven

**Question:** can a single channel be visibly deflected on a *living* actor and return cleanly to
the animation, with the death handoff intact?

**Build:** on a flesh hit, deflect exactly **one** channel — the struck limb's — by a fixed angle
about (impact normal × bone direction), decaying to zero over a fixed window. **No solver, no
points, no collision.** A scalar angle and a fixed axis. Deliberately over-driven so the answer is
not "I can't tell":

```
coop_hitReactDeg   25      // peak deflection, degrees. Tune DOWN later, never up.
coop_hitReactMs    300     // decay window
```

Plus the §4.1 handoff: on the `EF_DEAD` rising edge, force weight 0, push once, clear the slot,
**then** let the pending be recorded.

**Instrument** (direct analogue of the corpse `swing=60.5deg`):

```
^~^~^ HITREACT ent=%d loc=%d bone=%s peak=%.1fdeg t=%dms residual=%.3fdeg handoff=%d
```

* `peak` — how far the bone actually rotated away from its authored direction. The corpse work's
  `swing=` proved this is the only unit that measures what the user is looking at; the same
  applies here.
* **`residual`** — the deviation from the authored pose at release. **This is the number that
  matters most and has no corpse analogue.** A corpse artifact persists and is inspected at
  leisure; a living artifact must vanish. `residual` must be **< 0.05 deg** on every reaction. A
  non-zero residual is an actor permanently walking around with a bent arm.
* `handoff` — 1 if the reaction was released by a death edge. **Acceptance: every corpse killed
  mid-flinch settles from an authored pose.** Run 20 kills at `coop_hitReactDeg 25` and confirm no
  `RAGDOLL sleep` line shows an anomalous `stretch=` or `span=` versus the `coop_hitReactProc 0`
  baseline.

**Also print, free, from the same site — the §4.6 measurement:**

```
^~^~^ HITREACT target ent=%d wireloc=%d geomloc=%d geomerr=%.1fu moving=%d
```

Compare the server's `trace.location` against what the client's geometric search *would* have
chosen. **Over 100 rounds at moving actors, if agreement is below ~85%, the geometric path is
disqualified and the wire change is mandatory.** This costs one extra print and settles §4.6 with
data instead of argument.

**Rollback:** `coop_hitReactProc 0`. Secondary: `coop_hitReactDeg 0`.

---

### Stage L2 — the wire (only if L1's agreement rate says so)

**Question:** does a server-authored target (entity + location + eligibility) land the reaction on
the right limb on a moving actor?

**Build:** the new coop-private CGM message of §4.6. Ship exe + `cgame.dll` + `game.dll` together.
The eligibility bit is computed where `coop_hitReact` is computed (`aihandler.scr:1848-1893`) so
the two layers agree by construction.

**Instrument:** the same `HITREACT target` line, now with `wireloc` authoritative. **Acceptance:
`geomerr` distribution documented, and reactions land on the wire-named bone 100% of the time.**

**Rollback:** `coop_hitReactProc 0` (client ignores the message). The server keeps sending it;
that is harmless and costs ~20 bits per flesh hit.

---

### Stage L3 — chain and damping (the first stage that is about *feel*)

**Question:** does a 3-point limb chain with a damped return read as a hit reaction rather than a
twitch?

**Build:** replace L1's single-channel scalar with a 3-point chain (2 links, 6 iterations, 2
substeps, **no world collision** per §3.3), driven by the same impulse-on-`ptPrev` trick the
corpse path uses (`cg_ragdoll.c:1440-1442` — moving `pt` instead of `ptPrev` is the documented
body-flinging bug; do not repeat it). Reuse the corpse's asymmetric torque couple
(`cg_ragdoll.c:1546-1560`): push the distal end, pull the proximal end. That finding — 10.1° with
two pushes vs 21.1° with the couple — transfers directly and is the highest-value piece of prior
art here.

**Instruments:** `peak` and `residual` as L1, plus

```
^~^~^ HITREACT chain ent=%d peak=%.1fdeg overshoot=%.2f settleMs=%d fightscore=%.2f
```

`fightscore` = fraction of the reaction window during which the authored anim's own bone velocity
exceeded the overlay's. **High `fightscore` means the procedural layer is arguing with the
animation** — the "reads as jitter" failure of §6.2, measured rather than eyeballed.

**Rollback:** `coop_hitReactChain 0` falls back to L1's single channel. Master switch unchanged.

**Only here does `coop_hitReactDeg` come down from 25 to something shippable.** Tune down, never
up: an under-driven reaction is invisible, an over-driven one is a bug report.

---

### Stage L4 — density and budget

**Question:** does a 16-actor firefight hold frame time?

**Build:** enforce `coop_hitReactMax 6`, the 1024 u cull, and the not-in-snapshot skip (§3.5).

**Instrument:**

```
^~^~^ HITREACT budget active=%d peak=%d refused=%d chanwr=%d ms=%.2f
```

`refused` is the count that hit the cap — **it must be printed**, because the corpse feature's two
worst silent failures (bug-1967's mover budget, bug-1969's 30% coverage) were both "a thing
quietly stopped happening with no log line". `ms` is the measured cost of `CG_HitReactFrame`.

**Acceptance:** `ms` < 0.5 ms at `active=6`; no corpse `RAGDOLL sleep` line missing versus a
`coop_hitReactProc 0` run of the same map.

**Rollback:** `coop_hitReactMax 0`.

---

## 6. THE HONEST CASE AGAINST BUILDING THIS

Argued as hard as it can be argued. Four independent lines; any two are enough to shelve it.

### 6.1 The authored reaction already exists, and the gap is smaller than it looks

MOHAA shipped per-weapon, per-stance, per-location flinches, and this mod already plays them:
`aihandler.scr:1886-1891` does `self setmotionanim "<weapongroup>_<stance>_hit_<sfx>"` with
`<sfx>` ∈ {head, back, rarm, larm, leg} mapped from `self.fact.location` (`:1864-1872`). It uses
`setmotionanim`, the **torso layer**, so the legs keep running — which is exactly the "partial,
blended overlay that doesn't stop him fighting" the procedural version is supposed to deliver. It
was authored by animators who knew the rig.

The gaps are: `coop_aiHitReact` fires at **55%** (`:1850-1852`), it is throttled to **one per
1.2 s per man** (`:1861-1862`), and it is skipped when prone (`:1859`). So a procedural layer's
real addressable market is *the 45% of hits that are already deliberately suppressed, plus the
ones inside a throttle window that exists because firing a flinch on every hit looked bad.*

**Those thresholds were tuned, not accidental.** The strongest form of this argument: the
feature's entire value proposition is to fill in reactions that a previous tuning pass
deliberately removed. If more reactions were better, the cheapest possible experiment is
`coop_aiHitReact 100` and lowering the 1.2 s throttle — **zero code, zero risk, one cvar, this
session.** That experiment should be run before a single line of C is written, and if it makes the
game look worse, the procedural feature is answering a question whose answer is already known.

### 6.2 A procedural layer on a moving target will read as jitter

The corpse ragdoll works because a corpse is **static** — the server has parked it
(`RagServerParked`, `cg_ragdoll.c:2095`), the authored anim is finished, and physics owns the pose
outright. There is nothing to fight. bug-1965 is the proof of the converse: capturing while the
death animation was still playing produced "bodies fall like dropped mannequins", and the entire
SETTLE branch exists to *wait for the animation to be over*.

A living soldier is the opposite case by construction. His arms are being driven by a run cycle,
an aim controller (`actor.cpp:3765,3817,3838` set TORSO/HEAD/ARMS bone controllers **every
frame**), and possibly a `setmotionanim` flinch the mod just started on the same limb. A
procedural deflection on top is a fourth author on one bone. When four things drive one joint the
result is not "richer" — it is high-frequency noise, and at 15° on a limb moving at 200 u/s the
deflection is smaller than the animation's own frame-to-frame delta. **`fightscore` in Stage L3
exists precisely to measure this, and there is a real chance it comes back saying the effect is
inside the animation's noise floor.**

### 6.3 The visible-failure asymmetry, and much less room for error

A corpse artifact is inspected at leisure by a player who has already won that exchange. A living
artifact is on the model the player is *currently aiming at*, mid-exchange. The tolerance is not a
little tighter — it is an order of magnitude tighter.

And the targeting error is not hypothetical: §4.6 derives **~20 u of worst-case error against a
15 u match radius**, and the failure mode is *wrong limb*, not *no reaction*. Chest shot, thigh
twitch. Every one of those is a bug report, and it will look exactly like a hit-detection problem —
which will send the next session hunting in `cm_trace_lbd.cpp`, the most dangerous file in the
tree to be wrong about.

Fixing it properly costs a wire-format change and an exe+cgame+game lockstep ship. **That is a
large bill for a 15° arm wiggle.**

### 6.4 The corpse feature is not finished, and its remaining work is designed, cheap, and safe

Two items are already designed and unbuilt:

* **Feet and knees.** `s_ragDriveChild[12]` and `[14]` are `-1` with the comment "leaf TODAY;
  becomes L Foot in round 9 (the unsimulated knee)" (`cg_ragdoll.c:113-116`). Right now a corpse's
  lower legs are dead weight — the calf is a chain terminus and the foot is anchored to it
  (`s_ragAnchorTable`, `cg_ragdoll.c:277-284`). Bodies drape from the knee up.
* **Joint limits.** The current fold limits are **inequality distance braces**
  (`s_ragBraceMinFactor`, `cg_ragdoll.c:146-155`), an approximation the comments openly describe as
  a stand-in for angular limits — and `coop_ragdollTruss 0` exists specifically as "the experiment
  that tells us whether angular limits are worth building" (`cg_ragdoll.c:1027-1029`). It has been
  left as an open question through five rounds.

Both are **inside a proven subsystem, on static bodies, with an existing instrument (`swing=`,
`stretch=`, `span=`, `contacts=`), an existing acceptance drill (the freeze test), and no
hit-detection surface at all.** Neither needs a wire change, a renderer ABI change, or a lockstep
ship. The user tests **one build per session**. Spending those sessions on knees and joint limits
converts an already-working feature from "good" to "finished"; spending them on living reactions
starts a new feature at Stage L0, on the highest-visibility model in the game, against an authored
layer that already covers the salient cases.

---

## 7. Recommendation

**Do not build this as scoped. Do three things instead, in order:**

1. **This session, zero code:** set `coop_aiHitReact 100` and drop the 1.2 s throttle
   (`aihandler.scr:1862`) to ~0.4 s. Play one map. If the authored flinches at full rate look
   right, the ask is **answered** and the procedural layer is unnecessary. If they look *worse*,
   §6.1's argument is confirmed and the procedural layer would look worse still. Either result is
   decisive and costs nothing.

2. **If (1) says the authored layer is genuinely insufficient:** build **Stage L0 only**, in one
   session, as a pure safety demonstration. `maxdev=0.000` plus matching `loc=` distributions
   converts §1's static proof into a live one, and it is the only stage whose result cannot be
   guessed. **Do not build L1 in the same session** — the corpse work's own history says a session
   that ships two changes cannot attribute the result.

3. **In the meantime, finish the corpses:** feet/knees (`s_ragDriveChild[12]`, `[14]`) and the
   `coop_ragdollTruss 0` angular-limit experiment. Both are designed, both are cheap, both are in a
   subsystem that already has instruments and cannot touch hit detection.

**The safety answer stands regardless of the recommendation:** a per-channel render blend through
the existing bridge **cannot** affect server hit detection on a listen host. If this feature is
built, it is a product decision about visual value and session budget — not a correctness risk.
But it must be built with a **separate pool**, the **§4.1 death handoff in the first functional
stage**, and `coop_hitReactProc` defaulting **OFF**.

---

## Appendix — file:line index

| Subject | Location |
|---|---|
| Server deep trace entry | `openmohaa-hzm/code/server/sv_world.c:585` |
| Deep trace, server bone read | `openmohaa-hzm/code/qcommon/cm_trace_lbd.cpp:444-500` (bone read `:486`) |
| Hit location → bone name table | `openmohaa-hzm/code/qcommon/cm_trace_lbd.cpp:29-51`, `MAX_HITLOCATIONS 19` at `:29` |
| `CL_TraceDeep` (dead code, zero callers) | `openmohaa-hzm/code/qcommon/cm_trace_lbd.cpp:533-591` |
| Server re-pose before every bone read | `openmohaa-hzm/code/fgame/g_main.cpp:895-916` |
| Shared skeletor cache | `openmohaa-hzm/code/tiki/tiki_cache.cpp:305-340` |
| Skeletor bone read terminal | `openmohaa-hzm/code/tiki/tiki_tag.cpp:94-114` |
| Skeletor write (the only one) | `openmohaa-hzm/code/tiki/tiki_tag.cpp:120-126` `TIKI_SetPoseInternal` |
| Bone controllers (server, networked) | `openmohaa-hzm/code/qcommon/q_shared.h:2121,2188-2189`; setters `fgame/actor.cpp:3765,3817,3838` |
| Renderer bone pool | `openmohaa-hzm/code/tiki/tiki_mesh.cpp:29`; cap/reset `tiki/tiki_mesh.h:16-42`, `tiki_mesh.cpp:47-70` |
| Hook A (gl1 / gl2) | `renderergl1/tr_model.cpp:849-861` / `renderergl2/tr_model.cpp:1237-1247` |
| Hook B (gl1 / gl2) | `renderergl1/tr_model.cpp:1811-1823` / `renderergl2/tr_model.cpp:2347-2357` |
| Renderer slot pool, `animPose` stash | `renderergl1/tr_ragdoll.cpp:22-36`, `:113-170` (stash `:120-134`) |
| Bridge exports (append-only ABI) | `renderercommon/tr_public.h:187-191`; `cgame/cg_public.h:452-455`; wired `client/cl_cgame.cpp:837-839`, `renderergl1/tr_init.c:2113-2115`, `renderergl2/tr_init.c:2669-2671` |
| `cgi.TIKI_Orientation` is Hook B | `client/cl_cgame.cpp:813` |
| Corpse sim pool / points / constants | `cgame/cg_ragdoll.c:56-72`, `:249-253` |
| Corpse capture (reads through Hook B) | `cgame/cg_ragdoll.c:563-609` (`ForceUpdatePose` `:607`, orientation read `:609`) |
| Corpse push to bridge | `cgame/cg_ragdoll.c:1299-1398` |
| Corpse frame loop | `cgame/cg_ragdoll.c:1708+`; called `cgame/cg_view.c:2928` |
| Corpse arm/transition gates | `cgame/cg_ragdoll.c:2237-2383`; transition called `cgame/cg_snapshot.c:140` |
| Server-park handoff signal | `cgame/cg_ragdoll.c:2095-2104` |
| Post-death impact + torque couple | `cgame/cg_ragdoll.c:1443-1560` |
| Flesh-hit message writer (server) | `fgame/weaputils.cpp:2605-2648` |
| Flesh-hit message parse (client) | `cgame/cg_parsemsg.cpp:1768-1822` |
| Client interpolation window | `cgame/cg_snapshot.c:496-528` |
| `sv_fps 40` in this deployment | `hzm-mohaa-coop-mod/autoexec.cfg:684`; engine default 20 at `server/sv_init.c:1108` |
| Mod's authored hit reaction | `hzm-mohaa-coop-mod/coop_mod/aihandler.scr:1848-1893`; trigger `:1050`; counter `coop_mod/aibehav.scr:143` |
| `swing=` instrument precedent | `cgame/cg_ragdoll.c:1862-1882`; measured values `_research/ragdoll_r12_session_swing.log` |
