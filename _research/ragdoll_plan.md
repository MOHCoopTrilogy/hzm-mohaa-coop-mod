# Client-Side Ragdoll — Implementation Plan **v3** (post round-2 vetting)

**Status: PLAN — no code. Vetting history: v1 -> 3 agents (15 blocking) -> v2 -> 2 agents
(completeness: 12 partial + 2 dropped + 5 new defects; integration: 5 blocking + 8 acceptance
items). v3 folds in ALL of it (changelog inline as [Cn]/[Fn] tags = the vet2 fix-list ids).
Round 3 = one confirmation agent re-running both matrices against this text; implementation
starts only on its pass (user directive).**

## 0. Settled — do not relitigate

- **Renderer-side override only.** Skeletor objects are shared with the server game DLL on a
  listen host (tiki_cache.cpp:305; g_main.cpp:904/915; cm_trace_lbd.cpp:486): a skeletor-layer
  override corrupts SERVER hit detection, and the skeletor layer offers no caller gating —
  there is no way to distinguish a render read from a server read at that level [C13]. Copy
  this rationale to docs/DECISIONS.md at ship.
- Hook A: in `R_AddSkelSurfaces`, **outside the cull-gated copy `if` (between tr_model.cpp:845
  and :847)** — for flagged ents it writes ALL channels unconditionally, so a skipped vanilla
  copy can never leak stale pool garbage (the drift-on-screen/server-pose-off-frustum case
  takes exactly that path). Hook A is a **pure reader** of the table: no edge latches, no
  counters, no capture-on-first-call — with N fills per frame (mirrors, portals, wrap-frames)
  all state transitions live in cgame's push. [int F7]
- Hook A also copies `newFrame->bones` into the slot's anim-pose block each fill — that is the
  ONE producer of the anim-pose matrices the gore remap consumes; the bridge does NOT carry an
  animMat[] parameter (cgame has no GetFrame export — v2's signature was uncimplementable).
  [int F10]
- Hook B: patch `RE_TIKI_Orientation` (tr_model.cpp:1797) — closed consumer set. Correct
  attribution [int F1]: the WORN helmet is a model SURFACE and rides the head via **Hook A**;
  the neck stump, dangling eyeball, wound props, drip emitter, decap chunks-on-head and
  holstered weapons-on-back ride via **Hook B**. `RE_TIKI_IsOnGround` also consults the table
  (RF_SHADOW stays on until BecomeCorpse — the foot-shadow window is exactly the guard window).
- Facts carried from round 1: all citations verified; 17 Bip01 names byte-exact across
  AA/SH/BT/imported skds; one refEntity spans body+head+hands; LOD harmless; gore UV stamps
  READ the overridden mesh (tess.xyz) — placement uses the [int F10] remap.

## 1. Goal & non-goals (unchanged)

Cosmetic client-side ragdoll for dead AI actors. Server corpse/hitboxes untouched; players and
player body-queue corpses never ragdoll; no networking; gl1 first; ships dark behind
`coop_ragdoll 0`; **supported minimum framerate ~31 fps — below that, corpse motion slows;
above it, never** [C2]. Delimb enabler later.

## 2. Data model, spaces, capture

- **Table:** `byte slotPlusOne[MAX_GENTITIES]` + `MAX_RAGDOLLS(8)` slots (constant, not cvar —
  intentional change from v1 [C13]). Slot: entnum, `dtiki_t*` (rows ignored on mismatch),
  channel count (per-model, bounded by the engine-real per-SKD `TIKI_MAX_BONES 100` [C12] —
  asserted at capture), per-channel 3x4s, the Hook-A-owned anim-pose block, sim AABB, state.
  Every entnum index into any ragdoll array is bounds-checked against MAX_GENTITIES,
  gore-precedent style [C11]. Rows tolerate being pushed but never consumed (cull-out, bone-
  pool overflow skipping the model) — no consumption asserts [C12].
- **Space:** skeletor-space (model-local, unscaled) 3x4s. Per push:
  `local_pos = (transpose(ent.axis) * (world_pos - ent.origin)) / (ent.scale * tiki->load_scale) - tiki->load_origin`,
  `local_axis = world_axis * transpose(ent.axis)` — always against the **current frame's**
  entity placement, never the death-frame transform [C13]. One index space everywhere: tiki
  channel indices (Tag_NumForName's space).
- **Capture procedure [C1]:** build the capture refEntity from the same cent fields
  CG_ModelAnim submits (tiki, CURRENT interpolated frameInfo, scale, entityNumber,
  origin/axis); one `cgi.ForceUpdatePose` — **warning: this stamps tr.skel_index[entnum], so
  wrong frameInfo poisons that frame's real render**; then per-channel `cgi.TIKI_Orientation`.
  Always the cent's own tiki handle (TIKI_GetSkeletor caches only 2 skeletors per entnum,
  delete-on-evict). P2 acceptance: captured pose verified non-bind.
- **Full-skeleton slaving:** every channel emitted; non-simmed channels ride their governing
  simmed anchor via capture-time relatives (`rel_b = inv(M_anchor_cap) * M_b_cap`); anchors
  from the hardcoded Bip01 hierarchy, nearest-capture-position for unknown gear bones.

## 3. Simulation

- 15 points / 14 links / 6 braces / 6 iterations (unchanged).
- **Timestep [C2]:** `if (cg.frametime <= 0) return;` — the TABLE persists and Hook A keeps
  applying the last push while paused/hitching (table lifetime belongs to §4 lifecycle, never
  the stepper) [int F9]. `accumMs += min(cg.frametime, 200); while (accumMs >= 8 && steps < 4)
  step(8ms); accumMs = min(accumMs, 32)` — discard excess after stepping. Timescale follows
  cg.frametime naturally; demo fast-forward hits the 200ms clamp.
- **Collision [C4]:** world-only `CG_Trace(..., cliptoentities = qfalse)` with a
  **MASK_SOLID-class content mask**, 2u box; movers via ONE `CG_GetBrushEntitiesInBounds`
  (cg_predict.c:87 — signature confirmed [P0-a done]) per body per frame over the inflated
  AABB, clipping moving points against that bmodel list only. Never bbox entities. Trace
  ceiling 240/frame.
- **Velocity seed [int F8]:** arm on the EF_DEAD edge, **hold the sim one snapshot, then
  difference the first 1-2 post-edge snapshot origins forward** — the death impulse lands the
  same server frame and moves the origin only on FOLLOWING snapshots; differencing at the edge
  seeds ~zero on stationary kills. Wound kick added along the seed vector.
- Sleep rules unchanged; `coop_ragdollLife 6` force-sleep.

## 4. Lifecycle & identity

- **Arm guard (ALL of):** `eType == ET_MODELANIM` **on BOTH currentState and nextState**
  (an eType change does NOT clear `interpolate` — verified cg_snapshot.c:326-327 — so the
  interpolate clause alone cannot cover a same-slot eType swap) [int F6]; EF_DEAD rising
  between currentState and nextState; **`cent->interpolate == qtrue` at that transition**
  (the engine's own continuity test — false on snapshot absence, EF_TELEPORT_BIT flip,
  parent change, modelindex change, cg_snapshot.c:326-335) [int F6];
  `entityNumber >= cgs.maxclients`; **reject any ET_MODELANIM corpse carrying a valid
  s.clientNum** (player body-queue corpses are born ET_MODELANIM+EF_DEAD and must never arm)
  [C7]. HeadGibObject/HelmetObject props never carry EF_DEAD (verified: zero EF_DEAD writes
  in fgame/object.cpp), so gib/helmet entities were never at risk of arming [int F6].
- Corpses FIRST SEEN with EF_DEAD already set (off-screen deaths, late join, post-restart)
  never arm — they keep the anim pose; accepted [C10].
- **Post-death damage events are EXPECTED on armed corpses and must not clear** — corpses are
  shootable and re-fire the whole gore block (decap included) after death [int F4].
- All ragdoll state in cg_ragdoll.c's own array (clientFlags is zeroed on PVS re-entry).
  Clear/re-arm signals: EF_DEAD falling edge; EF_TELEPORT_BIT toggle; modelindex change;
  eType change; parent change; snapshot absence -> re-present with origin discontinuity >64u.
  Renderer belt: tiki mismatch rows ignored.
- Eviction: free slot, else ASLEEP slot (prefer out-of-PVS), else the death does not arm.
  Never evict an awake sim. **Arm-rate bound [C3]: max 4 arms/frame; the remainder queue for
  1-2 frames (capture cost stays bounded on horde grenades); r_ragdollDebug counts
  `arms refused` and `arms queued`.**

## 5. Renderer, bridge, controls, quirk ledger

- Culling override: cgame pushes the sim AABB; flagged ents render CULL_IN within it.
- Bridge: `R_SetRagdollPose(entnum, tiki, count, mat[], aabb)`, `R_ClearRagdoll(entnum)`,
  `R_ClearAllRagdolls()`. cgame NULL-checks every pointer; **gl2 ships stub exports that
  no-op** (belt) AND cgame NULL-checks anyway (braces) [C5]. ClearAll at CG_Init +
  CG_ServerRestarted. vid_restart kills cgame+renderer together -> snap-back to anim pose,
  accepted (reachable via the mod's own display-mode selector).
- **Cvar discipline [C9]:** `r_ragdollDebug` is never CVAR_ARCHIVE (CVAR_TEMP, not CVAR_CHEAT);
  before the P5 default flip, `coop_ragdoll` gets pre-registered in G_InitGame (the T7 /
  bug-1669 getcvar trap).
- Failure ladder unchanged (NaN / |pos|>65536 / repeated startsolid -> Clear + never re-arm).
- **Quirk ledger (accepted v1, each with its bound):**
  - Post-death decap/helmet-pop chunks spawn at the SERVER pose; offset bounded by ragdoll
    drift [int F2].
  - The growing blood pool is a world decal at the server-pose floor point; strands with drift
    [int F3].
  - Corpse shadow DECAL plants at model->origin and does not follow the body (cg_shadows
    default 0; the shipped Phase-A decal never reads tags) [C6 — corrected wording].
  - `CL_TraceDeep` is a latent client-side LBD consumer that reads the skeletor, not the
    table; cross-comment both sites referencing the ragdoll table as insurance [C8].
  - Corpses on movers lag a frame; fade-out (coop_corpseLife alpha) applies to the ragdolled
    mesh normally.
  - **Unifying drift bound: r_ragdollDebug logs settle distance from server origin per corpse;
    if the MEDIAN settle exceeds ~48u (a body half-length), retune seed/damping before P5 —
    pools, aim-at-corpse and gib spawn coherence all degrade with drift** [int F3].

## 6. Phases & acceptance (round-2 additions folded)

- **P0** — seed-vs-server-kick comparison specifically on **stationary-target grenade kills**
  (PASS = seeded direction/magnitude match) [P0-b]; channel-count ceiling script over the skd
  roster.
- **P1** — bridge test pose; **drift-cull drill**: debug-push a pose >= anim radius away, aim
  the camera so the server pose is off-frustum — body must render (culling override) with no
  garbage [P1-a]; gl2 launch clean via stubs.
- **P2** — capture (non-bind verified), constraints, timestep; full-channel slaving (fingers/
  face move with limbs); velocity-seed verdict.
- **P3/P4** — collision + settle; grenade fling; m2l2a lift bmodel test; horde grenade budget/
  eviction (no statues, refusals counted); plus [int F11]:
  (i) mirror/portal kill — body coherent in both views; (ii) post-death gore drill — shotgun +
  grenade a settled ragdoll until decap fires, nothing clears, chunks within drift bound;
  (iii) die as a player among actor corpses — player Body never ragdolls; (iv) coop_corpseLife
  5 fade drill; (v) helmeted-actor kill — worn helmet surface rides the head (Hook A), stump/
  eyeball/props ride Hook B; (vi) timescale 0.5/2 + pause drill — no accum burst on resume;
  (vii) drift measurement across a session (median < 48u); (viii) balcony-death actor — server
  body keeps falling post-edge, sim tracks the seed sanely.
- **P5** — user playtest; pre-register cvar; tune; only then default-on.

## 7. Round-3 brief

One confirmation agent: re-run BOTH round-2 matrices (completeness 13-item fix list; integration
F1-F11) against this v3 text — verdict per item, plus a fresh sweep for new internal
contradictions. Implementation begins only on an all-clear.
