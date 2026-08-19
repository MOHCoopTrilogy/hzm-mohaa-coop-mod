# Ragdoll v2 — Round-2 INTEGRATION vetting (adversarial)

**Scope:** interactions between `_research/ragdoll_plan.md` (v2) and the mod's real systems, verified
against the actual implementations in `openmohaa-hzm/code/`, `hzm-mohaa-coop-mod/`, `docs/TRAPS.md`,
`docs/FEATURES.md`. Every plan file:line cite I touched re-verified byte-accurate
(tr_model.cpp:844/1797, tiki_tag.cpp:108-111, cg_snapshot.c:65/113-136/121/326, cg_predict.c:87/130-184).

**Verdict summary: 5 BLOCKING (F6, F7, F8, F10, F11), 5 non-blocking ledger/wording items (F1-F4, F9),
2 confirmations (F5, and the clear-signal audit inside F8).**

> Side note for fresh sessions: `docs/FEATURES.md:398-403` still says decap is `REVERTED` with "zero
> `CoopGoreTryDecapitate` / `HeadGibObject` symbols". The code has both today (re-added 2026-08-17/19,
> bug-866 safe pattern): `sentient.cpp:3102`, `object.cpp:406+/540+`. Code wins; FEATURES.md is stale.

---

## F1 — Worn helmets are SURFACES, not attachments; Hook B is the wrong test target for them

- **CLAIM (plan §0/F5, §6 P4):** Hook B patches "the single funnel for all client tag consumers
  (attachments incl. helmets…)"; P4 acceptance: "helmet/eyeball ride the ragdoll via Hook B".
- **VERDICT: WRONG taxonomy, right outcome — NON-BLOCKING (wording + retarget the P4 item).**
- **EVIDENCE:** `sethelmet` registers *surface names* on the wearer's own model
  (fgame/sentient.cpp:4635-4658); the pop hides those surfaces via
  `edict->s.surfaces[i] |= MDL_SURFACE_NODRAW` (sentient.cpp:4689-4706). A worn AI helmet is skinned
  geometry of the corpse model — it rides the ragdoll head through **Hook A automatically**, no tag
  involved. Models without `sethelmet` carry headgear as plain surfaces too (the decap fallback list,
  sentient.cpp:3392-3415). The only tag-attached helmets in the project are the **player** cosmetic
  switcher props (`attachmodel` to Bip01 Head — FEATURES.md:917-921, helmet.scr) and players never
  ragdoll. The real Hook B customers on a corpse are: neck stump, dangling eyeball, wound props, drip
  emitter, decap gore chunks on the flying head, and holstered weapons-on-back.
- **REQUIRED CHANGE:** Fix the Hook B rationale wording; P4 item becomes "worn helmet (surface) rides
  the head via Hook A; stump/eyeball/wound props/drip/holstered weapons ride via Hook B."

## F2 — Popped helmet & flying head gib spawn at the SERVER pose; post-death decap makes that visible

- **CLAIM (plan §7 brief):** "HelmetObject is its own entity, not an attachment?" and "decapped corpse
  ragdolls with hidden head — stump attachment via Hook B".
- **VERDICT: CONFIRMED both, but INCOMPLETE — NON-BLOCKING with mandatory quirk-ledger + P4 item (see F11).**
- **EVIDENCE:** Popped helmet = `new HelmetObject()` — its own physics entity, `g_helmetlife` 30 s
  despawn (fgame/object.cpp:406-431, 613-625); spawned at the **server** head-tag position
  `G_TIKI_Orientation(edict, "Bip01 Head")` (sentient.cpp:4712-4737). Flying head =
  `HeadGibObject` spawned at the server head tag too (sentient.cpp:3191, 3262, 3369), SOLID_BBOX +
  MOVETYPE_GIB (object.cpp:554-574). Neck stump/eyeball = `Animate` **attach()** at Bip01 Neck/Head →
  networked parent/tag_num → positioned client-side through `cgi.TIKI_Orientation` (cg_ents.c:716,
  cg_modelanim.c:914) → Hook B covers them. At the killing blow the capture pose ≈ server pose, so
  spawn points read right. On a **post-death** decap (F4) of a drifted ragdoll, the helmet/head gib
  pop from the invisible server pose — a visible detach proportional to drift. Neither event flips any
  v2 clear signal (surfaces only — verified, F8).
- **REQUIRED CHANGE:** Quirk-ledger entry: "post-death decap/helmet-pop spawn at the server pose;
  offset bounded by ragdoll drift (measured in F11-vii)". No code change in v1.

## F3 — Growing blood pool is a WORLD DECAL at the server-pose floor point; ragdoll drift strands it

- **CLAIM (plan §5 quirk ledger):** lists mover lag, foot shadows, UV remap — no blood-pool entry.
- **VERDICT: MISSING interaction — NON-BLOCKING but ledger + measurement REQUIRED.**
- **EVIDENCE:** `DropBloodPool` traces down from the server-pose `centroid` and plants `Decal` world
  marks (sentient.cpp:2107-2163); the grow chain keeps layering rings at the **stored** floor point
  for ~6-7 s (`EventCoopGorePoolGrow`, sentient.cpp:2170-2233). Decals are world marks, not children
  (comment at 2165-2169), so Hook B cannot move them and the client cannot re-place them. A ragdoll
  that slides leaves its pool (and its shootable WEAPONCLIP slab, actor.cpp:12463-12475, and the F8
  gore-stamp server placement) behind at the server spot.
- **REQUIRED CHANGE:** Ledger entry + acceptance metric: r_ragdollDebug logs settle distance from
  server origin per corpse; if the median settle exceeds ~48 u (≈ a body half-length) the velocity
  seed/damping must be retuned before P5, because pools/aim-at-corpse/gore placement all degrade with
  drift. This turns three separate "accepted quirks" into one measured bound.

## F4 — Corpses are SHOOTABLE and the whole death-gore block RE-FIRES on every corpse hit

- **CLAIM (plan):** treats decap/gore as death-moment events; no mention that corpses take damage.
- **VERDICT: MISSING interaction — NON-BLOCKING for code (no clear signal false-fires — verified),
  BLOCKING only via the missing tests (folded into F11).**
- **EVIDENCE:** bug-1321 standing rule: corpses stay damageable — `Sentient::ArmorDamage` has no dead
  early-out and BecomeCorpse gives the corpse a WEAPONCLIP bbox so bullets stop on it
  (actor.cpp:12450-12475). Every hit on a corpse re-enters the `health < 0.1` block
  (sentient.cpp:1775-1798): gib-skin flips (surface bits only, 2464-2467 — no modelindex change),
  **CoopGoreTryDecapitate** (3102 — dead-gated `health > 0 return`, i.e. it *expects* corpses;
  explosive/shotgun, chance+budget), **DropBloodPool again** (a second pool at the server pose),
  drip re-attach, and bullet wound props post-death via line 1694. Momentum is also added to the
  server corpse (1667). None of these change eType/modelindex/parent or toggle EF_TELEPORT — **no v2
  clear signal false-triggers; the ragdoll correctly survives post-death gore** (head-surface NODRAW
  follows the ragdoll; stump/eyeball attach via Hook B).
- **REQUIRED CHANGE:** Plan §4 should state explicitly that post-death damage events are expected on
  armed corpses and must not clear; add the F11-ii acceptance test.

## F5 — DBNO players can never be touched by the arm guard — CONFIRMED

- **CLAIM (plan §1/§4):** players never ragdoll; DBNO players are ET_PLAYER.
- **VERDICT: CONFIRMED, two independent guards.**
- **EVIDENCE:** DBNO is pure script state on the player entity (`healthonly 9999`, flags —
  coop_mod/dbno.scr:25-51); no fgame path ever sets a player to ET_MODELANIM — `s.eType = ET_PLAYER`
  is the only assignment (player.cpp:2276); EF_DEAD on the player entity is set only on real death
  (player.cpp:3466) and cleared on respawn (2711), and even then eType stays ET_PLAYER and
  entityNumber < cgs.maxclients. The guard `eType==ET_MODELANIM && entnum>=maxclients` excludes every
  player state including DBNO, dead-awaiting-respawn, and spectate.

## F6 — BLOCKING: the plan's own edge template ARMS body-queue player corpses; "EXCLUDED v1" has no mechanism

- **CLAIM (plan §4):** "Body-queue player corpses (ET_MODELANIM+EF_DEAD): EXCLUDED v1", edge detection
  "mirrors the gore template at CG_TransitionEntity (cg_snapshot.c:113-136)".
- **VERDICT: CONTRADICTION — the cited template fires on body-queue corpses BY DESIGN.**
- **EVIDENCE:** Player death spawns `new Body` (player.cpp:11393) which is **born**
  ET_MODELANIM + EF_DEAD (body.cpp:36-47) at entnum ≥ maxclients — indistinguishable from an actor
  corpse by the plan's three arm predicates. `CG_TransitionEntity` runs for every entity in the new
  snapshot including newly-appearing ones, comparing against the **stale** `currentState` of the slot
  (cg_snapshot.c:237-243); the gore KillSplash edge deliberately fires on that stale rising edge —
  its own comment says "players and the body queue already carried it" (cg_snapshot.c:127-136). A
  naive mirror arms every player Body (and any slot-reuse ghost whose stale state lacked EF_DEAD).
- **REQUIRED CHANGE (plan §4 text):** Arm only when ALL of:
  (1) EF_DEAD rising between currentState and nextState;
  (2) `cent->interpolate == qtrue` at that transition — the engine's own continuity test, which is
  false when the entity was absent from the previous snapshot, on an EF_TELEPORT_BIT flip, a parent
  change, or a **modelindex change** (cg_snapshot.c:326-335);
  (3) eType == ET_MODELANIM on BOTH sides; entnum ≥ maxclients.
  This excludes Bodies (first snapshot already dead ⇒ no witnessed rising edge with continuity),
  excludes slot-reuse ghosts, and — document this — means actors killed out of PVS never ragdoll
  (correct: their server anim has already settled them). HeadGibObject/HelmetObject never carry
  EF_DEAD (object.cpp) so they were never at risk — state that too.

## F7 — BLOCKING: multi-view fills are real (mirrors/portals), and Hook A's site is ambiguous about the cull-skip path

- **CLAIM (plan §0/F1):** Hook A "inside R_AddSkelSurfaces, immediately after the bone-cache copy loop
  (tr_model.cpp:844) … running on EVERY fill (the pool is per-view, recycled per scene)".
- **VERDICT: mechanism CONFIRMED, statement UNDER-SPECIFIED in two ways that produce garbage skinning.**
- **EVIDENCE:**
  - Per-view fills are real, with a server-side trigger: `TIKI_Reset_Caches` runs once per scene
    (tiki/tiki_mesh.h:29-43, tiki_mesh.cpp:34) while each `R_AddSkelSurfaces` call claims a **new**
    `bonestart` block (tr_model.cpp:761-768, 849-850). gl1 re-walks the entity list per view
    (tr_main.c:1391+): the portal-sky view re-adds only RF_SKYENTITY entities (1416-1425) and
    mirror/portal views re-add only RF_WRAP_FRAMES / RF_SHADOW_PLANE entities (1427-1435) — and those
    flags are **computed by the server per snapshot** for entities visible through an SVF_PORTAL
    portal (sv_snapshot.c:528-564, 820-823, 836-838). So a corpse visible in a mirror or a
    security-camera portal genuinely gets TWO+ fills per frame in DIFFERENT pool blocks.
  - The vanilla bone-copy loop is **cull-gated**: when `iRadiusCull == CULL_CLIP` and
    `R_CullSkelModel(...) == CULL_OUT`, the copy loop (829-845) is skipped but `bonestart` still
    advances and the surfaces are still added — the block contains stale pool garbage. Both culls use
    the SERVER anim pose radius (`R_GetRadius`, 774; `newFrame`-based OBB, 825): a ragdoll that
    drifted on-screen while its server pose is off-frustum takes exactly this path.
- **REQUIRED CHANGE (plan §0/§5 text):** state the idempotency contract precisely:
  (a) Hook A sits **outside** the cull-gated `if` (between tr_model.cpp:845 and 847) and writes ALL
  channels unconditionally for flagged ents, so a skipped vanilla copy can never leak garbage;
  (b) Hook A is a PURE READER of the ragdoll table — no rising-edge latches, no per-frame counters,
  no capture-on-first-call: with N fills/frame all state transitions live in cgame's push;
  (c) the F8 anim-pose copy is per-frame stable because `R_UpdatePoseInternal` early-outs once
  `tr.skel_index[entnum] == tr.frame_skel_index` (tr_model.cpp:1755-1761) — GetFrame returns the same
  pose for every fill of a frame, so copying it on every fill is safe and identical;
  (d) the culling override must neutralize BOTH cull sites (sphere at 777, OBB at 825), not just the
  drawsurf side. Add the F11-i mirror test — it is currently the only way to exercise any of this.

## F8 — Death-frame entity audit: NO clear signal false-triggers (confirmed) — but the velocity seed samples the WRONG side of the edge

- **CLAIM (plan §3/§4):** clear set = EF_DEAD fall, EF_TELEPORT toggle, modelindex/eType/parent change,
  absent+re-present >64 u; init velocity "from snapshot origin differencing at the EF_DEAD rising edge".
- **VERDICT: clear-set audit CONFIRMED CLEAN; velocity spec DEFECTIVE — BLOCKING (P0 as written
  measures the wrong thing).**
- **EVIDENCE:**
  - Sequence at death: `Actor::HandleKilled` sets deadflag/health/EF_DEAD at death-anim START
    (actor.cpp:5427-5435); the death anim plays for seconds; `BecomeCorpse` runs at anim END
    (actor_killed.cpp:70, actor_balcony.cpp:409) doing AddToBodyQue (a REGISTER — the actor entity is
    not copied; the 129th corpse EV_Removes the oldest, MAX_BODYQUEUE=128, actor.cpp:11552-11562),
    bbox flatten + CONTENTS_WEAPONCLIP (12463-12475), CheckGround/droptofloor ≤64 u origin snap
    (12477-12511), RF_SHADOW clear (12514). **No eType change, no modelindex change, no EF_TELEPORT
    toggle, no parent change anywhere in the path** — nothing in v2's clear set fires at death, at
    anim end, or on post-death gore (F4). The mid-ragdoll droptofloor snap is absorbed by the
    per-push world→local conversion (uses live origin), as is the balcony bespoke fall.
  - BUT: the killing-blow impulses — `HandleKilled`'s explosive shove (actor.cpp:5437-5460) and
    `CoopGoreDeathKinetics`'s `velocity +=` (sentient.cpp:2635-2650) — are applied to the server
    entity in the SAME server frame that sets EF_DEAD. They move the origin starting the NEXT server
    frame. Differencing `(current - previous)` **at** the rising edge therefore captures only
    pre-death movement — ~zero for a standing guard — and misses the grenade kick entirely. The
    server corpse gets up to 340+130 u/s; the ragdoll would sim from rest and immediately diverge
    from every server-side expectation (pool position, gib spawn points, the F3 drift bound).
- **REQUIRED CHANGE (plan §3):** seed velocity from the FIRST 1-2 snapshot deltas AFTER the edge
  (arm on the edge, hold the sim 1 snapshot, difference forward), and re-word P0: log
  seed-vs-server-velocity specifically on **stationary-target grenade kills** — the current "confirm
  magnitude quality on grenade kills" would happily pass moving targets and miss this. Also note
  RF_SHADOW stays ON until BecomeCorpse (anim end), so the Hook-B foot-shadow window is exactly the
  first seconds of the sim — the plan's "if corpse foot-shadows remain enabled" should say that.

## F9 — Timescale / pause: spec CONFIRMED correct (with one clarification)

- **CLAIM (plan §3):** `if (cg.frametime <= 0) return;` accum in ms, clamp 200, ≤3 steps of 8 ms.
- **VERDICT: CONFIRMED.** `cg.frametime = cl.serverTime - cl.oldServerTime` in **milliseconds**
  (cl_cgame.cpp:1019 → cg_view.c:2877-2880). Timescale scales serverTime advancement, so the sim
  slows/accelerates in lockstep with the world (correct). Pause freezes serverTime → frametime 0 →
  guarded. Map-restart rewind is clamped at cl_cgame.cpp:1014-1017; residual negatives hit the ≤0
  guard. Demo fast-forward hits the 200 ms clamp.
- **REQUIRED CHANGE (clarification only):** state that the pose TABLE persists and Hook A keeps
  applying the last pushed matrices while frametime == 0 (paused/hitching) — table lifetime is owned
  by the lifecycle signals (§4), never by the stepper.

## F10 — BLOCKING: internal contradiction — who produces the anim-pose matrices for the F8 gore remap?

- **CLAIM:** plan §0 [arch F8]: "Hook A keeps a copy of the anim-pose matrices for flagged entities".
  Plan §5 bridge: `R_SetRagdollPose(entnum, tiki, count, mat[], animMat[], aabb)` — cgame passes
  `animMat[]` in. §2 slot layout stores "the anim-pose matrix copy (for gore remap)".
- **VERDICT: SELF-CONTRADICTORY, and only one side is implementable.** cgame has no GetFrame-class
  export (cgi exposes TIKI_Orientation per-tag only — cg_public.h:409) and the anim pose keeps
  evolving while the death anim plays; the renderer already holds the exact frame in `newFrame` at the
  hook site (tr_model.cpp:819-822), refreshed per frame and stable across fills (F7c).
- **REQUIRED CHANGE:** drop `animMat[]` from the bridge signature; Hook A copies `newFrame->bones`
  into the slot's anim-pose block before overriding. One producer, one consumer (the gore funnel).

## F11 — BLOCKING: P0-P5 protocol cannot catch F1-F8 as written — add these acceptance items

The existing P0-P5 list tests the sim in isolation; every integration found above slips through it.
Additions (each gates its phase):

- **P0-a (replaces "confirm CG_GetBrushEntitiesInBounds signature" — confirmed here):**
  `int CG_GetBrushEntitiesInBounds(int iMaxEnts, centity_t **pEntList, const vec3_t vMins, const vec3_t vMaxs)`
  (cg_predict.c:87); it filters `cg_solidEntities` to SOLID_BMODEL, so shootable-corpse WEAPONCLIP
  bboxes (bug-1321) are naturally excluded from the mover candidate list.
- **P0-b (F8):** seed-vs-server-kick comparison on stationary-target grenade kills; PASS = seeded
  speed within 2x of the server corpse's first-snapshot displacement.
- **P1-a (F7):** drift-cull drill — debug-push a test pose ≥ radius away from the entity origin, aim
  the camera so the SERVER pose is off-frustum but the sim AABB is on-screen; PASS = body renders
  correctly (no vanish, no garbage verts).
- **P3/P4 additions:**
  - **i (F7):** mirror/SVF_PORTAL test — kill an actor visible in a mirror or security-camera portal;
    PASS = both images show the identical ragdoll, no "too many skeleton models" spam, no flicker.
  - **ii (F4/F2):** post-death gore — shotgun + grenade a settled ragdoll until decap fires
    (coop_decapChance 100); PASS = ragdoll survives (no clear), ragdoll's head disappears, stump +
    eyeball ride via Hook B, head gib/helmet spawn offset observed and ≤ the F3 drift bound, wound
    props appear on the ragdoll at plausible spots.
  - **iii (F6):** body-queue exclusion — die as a player among actor corpses; PASS = the player Body
    plays its anim (no ragdoll), consumes no slot (r_ragdollDebug slot dump).
  - **iv (F3 quirk of corpse.scr):** `coop_corpseLife 5` — corpse fades (alpha applies to the
    ragdolled body — corpse.scr:24-31) and removal frees cleanly; slot reusable; no stale render.
  - **v (F1):** helmeted-actor kill — worn helmet surface rides the ragdolling head; killing-blow
    helmet pop reads continuous.
  - **vi (F9):** timescale 0.5 / 2 and pause drill — sim speed tracks the world; no accum burst on
    unpause.
  - **vii (F3/F2):** drift measurement — r_ragdollDebug logs settle distance per corpse across a
    horde test; PASS = median < ~48 u, else retune seed/damping before P5 (gates pool/aim/gib
    coherence in one number).
  - **viii (F8):** balcony-death actor (actor_balcony.cpp path) — server body keeps falling after the
    arm; PASS = no snap when BecomeCorpse's droptofloor fires seconds later.
- **P4 wording (F1):** replace "helmet/eyeball ride the ragdoll via Hook B" per F1.

---

## What v2 already gets RIGHT (verified, do not relitigate in round 3)

- Renderer-only layer: server/listen skeletor sharing is real (`TIKI_OrientationInternal` reads the
  shared skeletor — tiki_tag.cpp:94-114; G_TIKI_Orientation goes through gi, never through Hook B).
- Hook B funnel is genuinely single: every cgame tag consumer routes through `cgi.TIKI_Orientation`
  = RE_TIKI_Orientation (cg_ents.c:716; cg_modelanim.c:145/269/450/599/612/914; cg_commands.cpp,
  cg_specialfx.cpp, cg_swipe.cpp, cg_view.c) — tr_model.cpp:1797-1801.
- Clear-signal set does NOT false-trigger at death (F8 audit) — gore is surface-bit-only
  (sentient.cpp:2464-2467), decap is surface + separate entities, BecomeCorpse changes neither eType
  nor modelindex.
- Mannequins (`spawn script_model` — lobby.scr:490, 994+), surrender/prone posers (officer.scr:4876+,
  anim_scripted on LIVING actors), buildmode actors, and e2l1's health≤0 unkillables can never carry
  EF_DEAD — the only setters are body.cpp:40, actor.cpp:5435 (HandleKilled), player.cpp:3466.
- The eviction/never-evict-awake rule and the world-only + GetBrushEntitiesInBounds collision recipe
  match the engine's real shapes (cg_predict.c:87-122 vs the 130-184 entity-clip loop).
- corpse.scr despawn (fade + remove) is ragdoll-coherent as-is.
