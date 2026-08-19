# Client-Side Ragdoll — Implementation Plan **v2** (post round-1 vetting)

**Status: PLAN — no code. v1 was adversarially vetted by 3 independent agents
(architecture / stability / engine-facts, findings in `ragdoll_vet1_*.md`); all 15 blocking
findings are folded in below and marked [F:source]. Round 2 vetting must confirm every
numbered round-1 finding is addressed before implementation begins (user directive).**

## 0. Settled by round 1 (do not relitigate)

- **Renderer-side override is the ONLY safe layer.** The skeletor objects are shared with the
  server game DLL on a listen host (tiki_cache.cpp:305; fgame poses/reads via gi.TIKI_*Internal,
  g_main.cpp:904/915; LBD hit traces cm_trace_lbd.cpp:486). A skeletor-layer override would
  corrupt SERVER hit detection. Recorded here + to be copied to docs/DECISIONS.md at ship so a
  later session doesn't "simplify" it back. [arch F7]
- Hook A site (exact): inside `R_AddSkelSurfaces`, immediately after the bone-cache copy loop
  (tr_model.cpp:844), keyed by `ent->e.entityNumber`, running on EVERY fill (the pool is
  per-view, recycled per scene — never "apply once"). [arch F1]
- Hook B (mandatory v1, not deferred): patch `RE_TIKI_Orientation` (tr_model.cpp:1797) — the
  single funnel for all client tag consumers (attachments incl. helmets/wound props/eyeball).
  Also `RE_TIKI_IsOnGround` if corpse foot-shadows remain enabled. [arch F5, facts 10]
- All v1 file:line citations verified byte-exact; all 17 Bip01 bone names verified in the LBD
  table AND parsed skds across AA/SH/BT/imported bodies; ONE refEntity + one bone block spans
  body+head+hands skds; LOD cannot break indexing (vertex collapse only; r_uselod 0 default).
  These leave the P0 unknowns list. [facts 1-7]
- The gore UV mesh tracer reads post-skinning tess.xyz, so stamps FOLLOW the override for
  free; but server bullet-stop PLACEMENT lands at the invisible anim pose. v1 decision:
  **(b) honest remap** — Hook A keeps a copy of the anim-pose matrices for flagged entities;
  the gore funnel remaps the segment end by the nearest bone's anim→sim delta. [arch F8]

## 1. Goal & non-goals (unchanged from v1)

Cosmetic client-side ragdoll for dead AI actors; server corpse/hitboxes untouched; players
never ragdoll; no networking; gl1 first (gl2 = clean no-op, NOT a crash — see §5); ships dark
behind `coop_ragdoll 0` until playtest verdict. Delimb enabler later.

## 2. Data model & spaces [arch F3, facts 8-9; stability F5]

- **Table shape (gore's shape, not dense):** `byte slotPlusOne[MAX_GENTITIES]` index +
  `MAX_RAGDOLLS(8)` payload slots. Slot: entnum, the entity's `dtiki_t*` (row ignored when it
  mismatches `ent->e.tiki` — belt for slot reuse), channel count, per-CHANNEL 3x4 matrices
  (array sized to an asserted engine cap ~112), the anim-pose matrix copy (for gore remap),
  sim AABB, state. MAX_GENTITIES=2048 in this fork — dense was 2.45 MiB for a 10 KB need.
- **Space:** table stores **skeletor-space (model-local, unscaled) 3x4s** — exactly what
  `skeletor_c::GetFrame` emits. cgame sims in world space and converts each push:
  `local_pos = (transpose(ent.axis) * (world_pos - ent.origin)) / (ent.scale * tiki->load_scale) - tiki->load_origin`;
  `local_axis = world_axis * transpose(ent.axis)`. Hook A writes raw; Hook B applies the
  tiki_tag.cpp:108-111 formula. The corpse refEntity keeps its server origin/axis (no pinning
  — rejected: pinning breaks PVS/culling assumptions elsewhere).
- **One index space everywhere:** tiki bone-list channel indices — the space Tag_NumForName
  returns, GetFrame writes, GetBoneFrame reads. Capture, Hook A, Hook B all use it.
- **Full-skeleton coverage:** the cache is absolute per-channel (no inheritance) — a partial
  override tears the mesh (fingers/face freeze mid-air). cgame emits EVERY channel: at capture,
  record each channel's matrix relative to its governing simmed anchor
  (`rel_b = inv(M_anchor_capture) * M_b_capture`); per frame emit `M_b = M_anchor_sim * rel_b`.
  Anchor assignment: hardcoded Bip01 hierarchy for the 15 sim bones + known descendants;
  unknown gear bones -> nearest-capture-position anchor. (cgi exposes no bone-parent API —
  accepted; no new export in v1.) [facts 9, arch F4]

## 3. Simulation [stability F1, F3; facts 11]

- 15 points / 14 links / 6 braces / 6 relaxation iterations (unchanged from v1).
- **Timestep (exact spec):** `if (cg.frametime <= 0) return;`
  `accumMs += min(cg.frametime, 200); while (accumMs >= 8 && steps < 3) { step(8ms); }`
  `accumMs = min(accumMs, 8*3)` — discard excess after stepping: a hitch costs one
  fast-forwarded frame, never a backlog, never slow-mo on low-fps clients.
- **Collision (exact spec):** per moving point, **world-only** `CG_Trace(cliptoentities=qfalse)`
  (2u box) — NEVER the entity-clip loop (24k traces/frame on a horde, no preculling,
  cg_predict.c:130-184). Movers/doors/elevators: **one `CG_GetBrushEntitiesInBounds`
  (cg_predict.c:87) per body per frame** over the inflated body AABB, then clip moving points
  against that candidate list (typically 0-4 bmodels) via transformed box traces. Never clip
  against bbox entities (actors/players/other corpses). Trace ceiling 240/frame; past it,
  points glide one frame.
- **Init velocity:** actors never network pos.trDelta [facts 11] — seed from snapshot origin
  differencing at the EF_DEAD rising edge: `(current.origin - previous.origin) / snapshot_dt`,
  and add the wound kick along that vector. P0 logging task confirms magnitude quality on
  grenade kills; fallback = a tiny server->client event carrying the impulse (only if
  differencing proves too coarse — decide at P2 exit).
- Sleep rules unchanged (point sleep, body sleep <4 u/s for 1s, coop_ragdollLife 6s force-sleep).

## 4. Lifecycle & identity [stability F7; arch F9; facts 3, 7]

- **Arm guard:** `eType == ET_MODELANIM` + `eFlags & EF_DEAD` RISING edge + `entityNumber >=
  cgs.maxclients` (never a live player slot). Body-queue player corpses (ET_MODELANIM+EF_DEAD):
  EXCLUDED v1 (revisit after playtest). Edge detection mirrors the gore template at
  `CG_TransitionEntity` (cg_snapshot.c:113-136).
- **All ragdoll state lives in cg_ragdoll.c's own array** — never centity clientFlags (zeroed
  on PVS re-entry, cg_snapshot.c:65).
- **Clear/re-arm signal set** (all of): EF_DEAD falling edge; EF_TELEPORT_BIT toggle;
  modelindex change; eType change; parent change (mirror cg_snapshot.c:326); entity absent
  from snapshot then re-present WITH origin discontinuity (>64u) — the corpse->corpse slot
  reuse hole. Renderer belt: row ignored when stored tiki != ent->e.tiki.
- **Eviction (mirrors R_GoreAcquireInstance):** new death takes (a) a free slot, else (b) an
  ASLEEP slot (prefer out-of-PVS). If none: the new death does NOT arm — corpse keeps the
  server death anim (today's look). **Never evict an awake sim** (upright-statue failure —
  the bug-856 shape). [stability F4]

## 5. Renderer, bridge, failure ladder [stability F6; arch F2]

- Hook A also **overrides culling** for flagged entities: cgame pushes the sim AABB with the
  matrices; the renderer treats flagged ents as CULL_IN within that AABB (anim-pose bounds at
  the entity origin would pop a drifted body or skin garbage). P1 acceptance item.
- Bridge: `R_SetRagdollPose(entnum, tiki, count, mat[], animMat[], aabb)`, `R_ClearRagdoll(entnum)`,
  `R_ClearAllRagdolls()` via the gore-precedent refexport/cgi pairing. **cgame NULL-checks
  every bridge pointer** (gl2 provides none in v1 -> feature silently off under gl2, no crash —
  the `if (cgi.R_GoreReset)` precedent, cg_snapshot.c:121).
- `R_ClearAllRagdolls` called at CG_Init and CG_ServerRestarted. vid_restart kills cgame and
  renderer TOGETHER (cl_main.cpp:1624): sims are lost, corpses snap back to the anim pose —
  accepted + documented (reachable via the mod's own display-mode selector).
- Failure ladder unchanged (NaN / |pos|>65536 / repeated startsolid -> Clear + never re-arm
  that corpse). Kill switch coop_ragdoll 0 -> ClearAll.
- Quirk ledger (accepted v1): corpses on moving platforms may lag one frame behind the mover;
  shadow decals follow feet via Hook B (verify at P4); UV wound placement uses the F8 remap.

## 6. Phases (each gated on its acceptance test)

- **P0** — log trDelta/origin-differencing quality on actor deaths (one session with
  r_ragdollDebug prints); confirm channel-count ceiling across the model roster (script over
  skds: max channels — sizes the slot array); confirm CG_GetBrushEntitiesInBounds signature.
- **P1** — bridge proof: test pose (+32u) on one corpse; culling override verified by walking
  away/back; gl2 launch shows normal corpses (NULL bridge), no crash.
- **P2** — capture + constraints + timestep, no collision (falls through floor); full-channel
  slaving verified (fingers/face move with limbs, nothing frozen mid-air); velocity seeding
  verdict (differencing vs server event).
- **P3** — collision: settles on ground; grenade fling; elevator/door bmodel clip test on m2l2a
  lift; horde grenade with r_ragdollDebug (budget + eviction: no upright statues, deaths past
  budget keep anim pose).
- **P4** — quality: orientation stability, attachment coherence (helmet/eyeball ride the
  ragdoll via Hook B), gore-stamp remap spot check, sleep verification, NaN bail drill
  (inject NaN via debug cvar).
- **P5** — user playtest; tune; only then default-on.

## 7. Round-2 vetting brief

Two fresh agents: (1) COMPLETENESS — verify every numbered finding in ragdoll_vet1_*.md is
addressed by this v2 text, no regression of v1's correct content; (2) INTEGRATION — hunt
interactions v2 misses against the mod's own systems: helmet pop (HelmetObject is its own
entity, not an attachment?), corpse despawn (coop_corpseLife), DBNO revive of a ragdolling
teammate (excluded: players never ragdoll — verify DBNO players are ET_PLAYER not
ET_MODELANIM), lobby mannequins, anim_scripted scene corpses, count-scaling replicas,
freecam/spectator views (per-view fill = multiple fills/frame — Hook A must be idempotent),
gore chunks/decap interplay (decapped corpse ragdolls with hidden head — stump attachment via
Hook B), and the P0-P5 protocol's adequacy.
