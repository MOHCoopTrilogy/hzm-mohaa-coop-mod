# Ragdoll Plan — Vetting Round 1: Architecture & Correctness of the Override Design

**Reviewer lens: adversarial. Every claim checked against engine source 2026-08-19.**
Engine root: `openmohaa-hzm/code/`. All line numbers verified this session.

---

## Finding 1 — Bone-cache fill site pinned: single producer, but it is a per-VIEW append pool, not a per-entity slot

**CLAIM (plan §2):** "Whoever fills that cache is the single override choke point. (Phase-0 task: pin the exact fill site.)"

**VERDICT: CONFIRMED — with structural qualifications the plan must absorb.**

**EVIDENCE:**
- Producer: `R_AddSkelSurfaces` — `renderergl1/tr_model.cpp:720`. Bone copy loop at `:829-844` copies `newFrame->bones[i]` (from `R_GetFrame` `:822` → `ri.GetFrameInternal` → `skeletor_c::GetFrame`, `skeletor/skeletor.cpp:1022`) into the global pool; `ent->e.bonestart` recorded at `:849-850`.
- The pool is `TIKI_Skel_Bones[MAX_SKELBONES]`, a process-global append arena — `tiki/tiki_mesh.cpp:29`, reset ONCE PER SCENE by `TIKI_Reset_Caches()` at `renderergl1/tr_scene.c:510` (RE_BeginScene).
- Fill cadence is documented in-tree: "filled by R_AddSkelSurfaces once per entity PER VIEW and reset once per SCENE" — `tiki/tiki_mesh.h:29-40`. Caller: `renderergl1/tr_main.c:1466` (per view: main + portals/mirrors).
- Sole consumer: `RB_SkelMesh` resolves `&TIKI_Skel_Bones[backEnd.currentEntity->e.bonestart]` — `renderergl1/tr_model.cpp:1236`.
- Not cached across frames. The underlying POSE is computed once per com frame per entityNumber (`R_UpdatePoseInternal` guard `tr.skel_index[entnum] == tr.frame_skel_index`, `tr_model.cpp:1754-1761`; frame number = `com_frameNumber` via `qcommon/common.c:2273` → `cl_main.cpp:2645`), but the CACHE copy happens at every view's add.

**REQUIRED PLAN CHANGE:** Name the hook exactly: inside `R_AddSkelSurfaces`, immediately after the copy loop (`tr_model.cpp:844`) — or substitute into `newFrame` before it. The override must run on EVERY fill (each view), keyed by `ent->e.entityNumber` at fill time. Any design that "applies the table to the pool" outside this function is invalid: `bonestart` offsets are only meaningful during the add, and the pool is recycled per scene.

---

## Finding 2 — The bone copy is CULL-GATED, and culling uses the anim pose at the entity origin: ragdoll drift ⇒ pop-out and garbage skinning

**CLAIM (plan, implied by §4 and absent from §5):** overriding after the fill is always possible; culling is unaffected.

**VERDICT: WRONG (unhandled failure mode).**

**EVIDENCE:**
- The copy loop is inside `if (lod_tool->integer || iRadiusCull != CULL_CLIP || R_CullSkelModel(...) != CULL_OUT)` — `renderergl1/tr_model.cpp:824-845`. When the sphere clips the frustum and the tighter test says CULL_OUT, the copy is SKIPPED — but `bonestart` still advances (`:849-850`) and the surfaces are still added (`:912ff`), i.e. the entity skins from an UNWRITTEN pool region.
- Cull sphere: center = entity origin (`tiki_worldorigin`, `:770-777`), radius = `R_GetRadius` → skeletor `m_frameRadius` (`:774`, `:1819-1823`) which `SetPose` derives from the ANIM's stored bounds (`skeletor/skeletor.cpp:396-401, 463-467`). `R_CullSkelModel` uses the same anim-frame bounds.
- A ragdolled body can slide/fling away from the server entity origin (down slopes, grenade impulse) while the cull volume stays parked at the death spot around the death-anim bounds. Two concrete failures: (a) body pops out of existence when the death spot leaves the frustum though the ragdoll is on-screen; (b) the CULL_CLIP→CULL_OUT edge skips the copy while still drawing ⇒ verts skinned from garbage matrices splatter across the screen. With override matrices systematically far from the anim pose, (b) stops being a theoretical vanilla corner and becomes reachable every time a corpse settles near a frustum edge.

**REQUIRED PLAN CHANGE:** For table-flagged entnums: force the copy path (treat as CULL_IN) and use a sim-derived bound — either cgame pushes an AABB/drift distance with the matrices, or the renderer inflates radius by a `coop_ragdollMaxDrift` constant. Alternatively (cheaper, uglier): hard-clamp sim center drift to within the anim radius of the entity origin. One of these must be a P1/P2 acceptance item, not a P3 surprise.

---

## Finding 3 — "Per-bone 3x4 WORLD matrices" is the wrong space: as written, the design double-transforms every vertex

**CLAIM (plan §2/§3):** cgame does "capture pose (bones -> world)", sims in world, "rebuild bone matrices", renderer table holds "per-bone 3x4 world matrices" substituted into the cache.

**VERDICT: WRONG (correctness bug baked into the architecture text).**

**EVIDENCE:**
- Cache matrices are MODEL-SPACE and UNSCALED. `SkelWeightGetXyz` computes `out = weight.offset · bone.matrix + bone.offset` (`renderergl1/tr_model.cpp:1017-1033`), then the vertex is scaled by `scale = tiki->load_scale * ent->e.scale` (`:1099`, applied at `:1292/:1349`). The entity's rotation/origin are applied afterwards by the GL modelview — stated verbatim in `renderergl1/tr_gore.c:647-650`: "Positions in tess.xyz are MODEL-space (entity rotation/origin are applied by the GL modelview)".
- The tag path uses a DIFFERENT unit convention: `TIKI_OrientationInternal` returns `origin = (bone.t + load_origin) * (scale * load_scale)`, axis = raw bone rotation — `tiki/tiki_tag.cpp:105-111`. Consumers then transform by the parent refEntity's origin/axis (`CG_AttachEntity`, `cgame/cg_modelanim.c:918-922`).
- Insert world matrices into the cache and every corpse vertex gets the entity transform applied twice; feed world matrices to the tag path and attachments fly off by the parent transform.

**REQUIRED PLAN CHANGE:** The table must store skeletor-space (model-local, unscaled) 3x4s — the same thing `skeletor_c::GetFrame` emits. cgame converts its world-space sim back to model space each push, using exactly the origin/axis/scale it submits on the corpse refEntity that frame, dividing translations by `load_scale * e.scale`. Hook A then writes matrix+offset raw; Hook B applies the `tiki_tag.cpp:108-111` formula. (Design alternative worth recording: pin the corpse refEntity to a fixed origin/identity axis at death so world≈model up to load_scale — pick one in the plan.)

---

## Finding 4 — `boneIndex[24]` / 15-point partial override TEARS THE MESH: cache entries are absolute per-bone transforms and humans carry ~72 channels

**CLAIM (plan §4):** table = `{active, count, boneIndex[24], mat[24][3][4]}`; Hook A overwrites "the cached entries whose bone indices appear in the table"; §3 sims 15 points with leaf bones inheriting parent swing.

**VERDICT: WRONG.**

**EVIDENCE:**
- Cache entries are ABSOLUTE model-space transforms, one per tiki bone channel — not parent-relative. Every vertex weight indexes its bone directly: `bones[weight->boneIndex]` (`renderergl1/tr_model.cpp:1331-1337`; mesh>0 remap via `skelmodel->pBones[].channel` → `ri.TIKI_GetLocalChannel` `:1376-1385`).
- Characters have ~72 channels, in-tree number: "131072/72 bone-channels = ~1820 character-views" — `tiki/tiki_mesh.cpp` SKELPOOL comment (`:32-45`). 24 slots cannot even hold the full skeleton; 15+leaves overrides a third of it.
- Consequence: verts weighted to any NON-overridden bone (fingers, face/jaw/eye bones, spine0, clavicles, gear bones) keep rendering at the DEATH-ANIM pose location while their neighbors render ragdolled — hands/head shred into spikes the moment the pelvis moves. This is the exact class of corruption POSECHK exists to diagnose (`tiki/tiki_tag.cpp:152-184`).

**REQUIRED PLAN CHANGE:** Override EVERY channel of the tiki (count = `TIKI_GetNumChannels`, typically ~72; size the slot for ~80-100). Non-simmed bones are slaved: at capture record `rel_b = inv(M_anchor_capture) * M_b_capture` for each bone against its governing simmed anchor; each frame emit `M_b = M_anchor_sim * rel_b`. Note honestly: cgame has NO bone-parent API (`cgi` exposes only `Tag_NumForName`/`Tag_NameForNum`, `cgame/cg_public.h:406-407`), so anchor assignment needs the hardcoded Bip01 hierarchy (the 15 names + known children), a nearest-capture-position heuristic for unknown gear bones, or a new export that surfaces `skelBone_Base::m_parent`. Also state the index space once: table indices are tiki bone-list channel indices — the same space `cgi.Tag_NumForName` returns (`tiki/tiki_tag.cpp:36-39`), the same order `GetFrame` writes (`skeletor/skeletor.cpp:1022-1031`) and `GetBoneFrame(tagnum)` reads — one index space across Hook A, Hook B and capture. Memory: key the table as 8 active slots × full skeleton, not `MAX_GENTITIES × 24` (MAX_GENTITIES is 2048 in this fork, `qcommon/q_shared.h:1667-1668`).

---

## Finding 5 — Attachment path pinned: everything funnels through RE_TIKI_Orientation, which reads the SKELETOR, not the cache — Hook B is feasible and its exact target is now known

**CLAIM (plan §4 Hook B / P0):** "the tag-orientation function ... must consult the same table, or attachments will float at anim-pose positions"; P0 task "find whether attachment placement flows through RE_ForceUpdatePose+TIKI_Orientation only, or a separate path."

**VERDICT: CONFIRMED (the fear is real, the fix point exists and is singular for cgame).**

**EVIDENCE:**
- Server sends `parent` + `tag_num` (`entityState_t`, `qcommon/q_shared.h:2173-2174`). The CLIENT re-resolves attachment placement every frame: `CG_AddPacketEntities` adds parents before children (`cgame/cg_ents.c:668-685`); `CG_AttachEntity` (`cgame/cg_modelanim.c:904-944`) calls `cgi.TIKI_Orientation(parent, tagnum)` `:914` and transforms by the parent refEntity's origin/axis `:918-922`.
- `cgi.TIKI_Orientation = re.TIKI_Orientation` (`client/cl_cgame.cpp:813`) = `RE_TIKI_Orientation` (`renderergl1/tr_init.c:2101`, body `tr_model.cpp:1797-1801`) = `R_UpdatePoseInternal` + `ri.TIKI_OrientationInternal` → `skeletor->GetBoneFrame` (`tiki/tiki_tag.cpp:94-114`). It NEVER touches `TIKI_Skel_Bones`. So Hook A alone leaves helmets/wound-props/eyeballs floating at the anim pose — plan's concern confirmed.
- Hook B target: `RE_TIKI_Orientation` (`renderergl1/tr_model.cpp:1797`), gated on `table[model->entityNumber].active`. This one function covers ALL cgame tag consumers: attachments (`cg_modelanim.c:914`), eyes/head/feet (`:145/:269/:450/:599/:612`), tag emitters incl. wound-prop drips (`cg_commands.cpp:3474/3520/4909/5113`), swipes (`cg_swipe.cpp:153/175`), specialfx (`cg_specialfx.cpp:718`), `CG_GetOrigin` (`cg_ents.c:716`).
- Bypassing consumers checked: server fgame uses its own import (`fgame/g_main.cpp:915` via `gi.TIKI_OrientationInternal`) — untouched, correct; `client/cl_invrender.cpp:76` (UI inventory models) — irrelevant entnums.
- Bonus: precise foot shadows follow automatically (`cg_shadows 2` path, `cg_modelanim.c:766-788` uses tag orientations). The DEFAULT Phase-A directional shadow decal does NOT — it plants at `model->origin` (`cg_modelanim.c:711-763`), so the shadow decal stays at the death spot while the body slides. Cosmetic; either accept or offset it cgame-side from the sim centroid.

**REQUIRED PLAN CHANGE:** Write Hook B down as: patch `RE_TIKI_Orientation` in renderergl1 to return override-derived `orientation_t` (space per Finding 3). Remove the "or is there another consumer" hedge — the consumer set is closed and listed above. Add the shadow-decal note to §5 quirks.

---

## Finding 6 — Latent non-render consumer: CL_TraceDeep does client LBD hit-location tracing through re.TIKI_Orientation

**CLAIM (plan Q2):** "Does anything else consume bone poses ... that would desync from the override?"

**VERDICT: RISK (latent, currently dead code).**

**EVIDENCE:** `CL_TraceDeep` (`qcommon/cm_trace_lbd.cpp:533-591`, under `#ifdef CLIENT`) traces the 19 hit-location spheres using `re.TIKI_Orientation(model, iBoneNum)` at `:578`. Grep finds ZERO callers today. The server twin `SV_TraceDeep` (`:444-502`) uses `ge->TIKI_Orientation` (`:486`) — anim pose, unaffected. If client hit prediction is ever wired to `CL_TraceDeep` (hitmarker work makes this plausible), Hook B silently makes client corpse traces follow the ragdoll while the server hits the anim pose.

**REQUIRED PLAN CHANGE:** Record it. Cheap insurance: implement the Hook B override in a helper both can call, and have `RE_TIKI_Orientation` pass a "render" flag — or simply leave a comment at both sites cross-referencing the ragdoll table.

---

## Finding 7 — Plan Q1 answered: DO NOT override at the skeletor layer — the skeletor is shared with the SERVER on a listen host

**CLAIM (plan §8 Q1):** "Is the skelBoneCache override point sound, or should the override live at the skeletor layer (posintegrator) so TIKI_Orientation follows automatically?"

**VERDICT: skelBoneCache + RE_TIKI_Orientation (renderer-side Hook A+B) is CORRECT; skeletor-layer is WRONG for this fork.**

**EVIDENCE:**
- Skeletors are cached per `(entnum, tiki)` PROCESS-WIDE: `TIKI_GetSkeletor` (`tiki/tiki_cache.cpp:305-335`, `skel_entity_cache` keyed `entnum % TIKI_MAX_ENTITIES`).
- On a listen server — this project's primary mode — fgame poses and reads the SAME skeletor objects for the same entnum: `gi.TIKI_SetPoseInternal` (`fgame/g_main.cpp:904`), `gi.TIKI_OrientationInternal` (`:915`), `TIKI_TransformInternal` (`:923`); server LBD hit-location traces consume it via `SV_TraceDeep` → `ge->TIKI_Orientation` (`cm_trace_lbd.cpp:486`).
- An override inside `skeletor_c::GetBoneFrame`/`GetFrame` (`skeletor/skeletor.cpp:1022-1041`) or `skelBone_Base::GetTransform` (`skeletor/skeletorbones.cpp:474-481`) therefore feeds ragdolled bones to SERVER hit detection and server tag logic on the host — violating the plan's own non-goals ("hitboxes unchanged", "purely client-side") and making listen and dedicated servers behave differently. The layer has no caller identity to gate on, and `SetPose` re-dirties every bone on every call (`skeletor.cpp:375-378`) from both sides each frame, so cached-value poisoning would be stomped/re-evaluated nondeterministically.
- The true exe-level funnels, for the record: `TIKI_GetFrameInternal` (`tiki/tiki_tag.cpp:293` — feeds BOTH renderers' cache fill; see its own comment "the single funnel every skeletal model's final pose passes through, in BOTH renderers" `:163-166`) and `TIKI_OrientationInternal` (`:94`). Overriding those would need per-caller gating anyway — which is exactly what renderer-side hooks give for free, with smaller blast radius.
- gl2 note: if parity is ever wanted, the same two hooks exist there (`renderergl2/tr_model.cpp` fill ~`:1195`, `RE_TIKI_Orientation` `:2337`); gl2 fills per cascade-shadow view too (`tiki/tiki_mesh.h:29-40`), so the per-view discipline from Finding 1 already covers it.

**REQUIRED PLAN CHANGE:** Commit to renderer-side Hook A+B and record the rejection rationale (listen-host server contamination; no caller gating at the skeletor layer) in the plan/DECISIONS so a later session doesn't "simplify" it back.

---

## Finding 8 — Gore UV stamps (plan Q2): the ray test WILL follow the override — but stamping on ragdolled corpses breaks anyway, a regression in a shipped feature

**CLAIM (plan §8 Q2):** "tr_gore raycasts against the MESH — stamps on ragdolled corpses must use the overridden pose or miss."

**VERDICT: CONFIRMED mechanism / RISK — the plan's stated requirement is met automatically, yet the feature still regresses.**

**EVIDENCE:**
- `R_GoreSkelSurfaceCheck` runs at the tail of `RB_SkelMesh` against the just-skinned `tess.xyz` (`renderergl1/tr_gore.c:643-656`) — i.e., post-override verts. Segments are world→model transformed with `ent->e.origin/axis` (`:730-740`). So stamps use the OVERRIDDEN pose. Good.
- BUT the segment END is the SERVER's bullet stop, computed against server LBD spheres at the ANIM pose (`SV_TraceDeep`). The in-tree bug-905 comment records the current invariant: "corpses match poses, so they hit exactly" (`tr_gore.c:60-66`). Ragdoll destroys it: the stop point lands where the invisible anim-pose body is; the visible triangles are elsewhere. The exact test requires the hit within `GORE_NEAR_END_DIST` 20u of the stop (`:56`), the skin-snap fallback reaches 26u (`:66`) and is skin-only. Result: shooting a ragdolled corpse mostly produces NO new wounds (and occasionally a wrong-place snap stamp).

**REQUIRED PLAN CHANGE:** Own the regression explicitly. Options, pick one in the plan: (a) accept + document "ragdolled corpses stop accumulating UV wounds"; (b) keep a copy of the anim-pose matrices at Hook A time and remap the segment end by the nearest bone's anim→sim delta before testing; (c) for table-flagged entnums raise the near-end/snap tolerances. (b) is the only one that keeps wound placement honest.

---

## Finding 9 — Entity-slot reuse (plan Q3): there is NO spawn serial anywhere in the protocol — the plan's "key to a spawn counter/serial" cannot be implemented as written

**CLAIM (plan §7 risk 4):** "per-map entity churn reusing entitynums mid-sim (must key table entries to a spawn counter/serial, not entnum alone)."

**VERDICT: WRONG premise (no such serial exists); the underlying risk is REAL.**

**EVIDENCE:**
- `centity_t` (`cgame/cg_local.h:89-135`): currentState/nextState, `teleported`, `interpolate`, `currentValid`, `snapShotTime` — no generation counter. `entityState_t` (`qcommon/q_shared.h:2151+`): none either.
- Existing precedent handles exactly this problem for gore: `CG_TransitionEntity` (`cgame/cg_snapshot.c:113-136`) resets on the EF_DEAD falling edge OR an `EF_TELEPORT_BIT` toggle, and `CG_ResetEntity` runs on `!interpolate` (`:142-144`). Its own comment enumerates what each signal catches (`:115-120`).
- Hole for ragdoll: dead→dead slot reuse. Corpse A is removed (coop_corpseLife), actor B dies elsewhere and inherits the slot with EF_DEAD already set in the new state — no falling edge, possibly no teleport toggle. The table would ram A's matrices onto B's mesh.

**REQUIRED PLAN CHANGE:** Replace "spawn counter/serial" with the actual signal set, ALL of which clear/re-arm the ragdoll: EF_DEAD falling edge; EF_TELEPORT_BIT toggle; `modelindex` change; `eType` change; entity absent from snapshot (`currentValid` false / not in `cg.snap`) and later re-present. Belt-and-braces renderer-side: store the `dtiki_t*` (or model handle) in the table row and have Hook A/B ignore rows whose stored tiki != `ent->e.tiki`.

---

## Finding 10 — Capture-path facts: CONFIRMED, with two clarifications the plan must state (orientation space; ForceUpdatePose frame source)

**CLAIM (plan §2 grounded facts):** cgi.Tag_NumForName / ForceUpdatePose / TIKI_Orientation at cg_public.h:406-409; gore bridge precedent tr_public.h:185-186 + cg_public.h:448-449; RE_ForceUpdatePose tr_model.cpp:1774; SkelWeightGetXyz sites 987/1017/1040.

**VERDICT: CONFIRMED (all citations accurate).**

**EVIDENCE:** `cg_public.h:406-410` exact; gore exports now THREE functions `renderercommon/tr_public.h:185-187` and `cg_public.h:448-450` (incl. `R_GoreKillSplash`); `RE_ForceUpdatePose` body at `tr_model.cpp:1777` (header comment 1774); skinning helpers at `:990/:1017/:1040`. Plan P0 question "does TIKI_Orientation return bone-space or model-space" is hereby answered: MODEL-space, origin = `(bone.t + load_origin) * (scale * load_scale)` (`tiki/tiki_tag.cpp:105-111`); world = parent refEntity origin/axis transform (`cg_modelanim.c:918-922`).

Two traps to write into the capture step:
1. `cgi.ForceUpdatePose` re-poses from whatever `frameInfo[]` the passed refEntity carries and stamps the once-per-frame guard (`tr_model.cpp:1777-1790`, guard `:1754-1761`). The capture refEntity MUST carry the corpse's current interpolated `cent->currentState.frameInfo` (as `CG_ModelAnim` does; refEntity keyed `model.entityNumber = s1->number`, `cg_modelanim.c:1440`) — a zeroed refEntity captures a bind/stale pose, and the stamped guard then makes the real render that frame reuse it.
2. Death-edge detection point (plan P0): already exists — ride `CG_TransitionEntity` (`cg_snapshot.c:113-136`) exactly like the gore kill-splash rising edge. Actor filter available client-side: `eType == ET_MODELANIM/ET_MODELANIM_SKEL` (`cg_ents.c:578-579`) + tiki `bIsCharacter` (gore's gate, note at `tr_gore.c:683`) + reject `s.clientNum` in `[0, MAX_CLIENTS)` — `q_shared.h:2193` says clientNum is set "for players and corpses", which is what excludes player body-queue corpses (their entityNumber is NOT < MAX_CLIENTS, so the plan §8 item 7 filter must mean `s.clientNum`, not entityNumber — make that explicit).

**REQUIRED PLAN CHANGE:** Add the two traps above to §3/§6; mark the P0 sub-questions (orientation space, edge point) resolved.

---

## Finding 11 — Corpse "entity velocity" for sim init is not a thing cgame can just read

**CLAIM (plan §3 Init):** "point velocities = corpse entity velocity (the shipped corpse impulse)".

**VERDICT: RISK (unverified data source).**

**EVIDENCE:** `entityState_t` carries only `trajectory_t pos {trTime, trDelta}` (`q_shared.h:2116-2119, :2156`); MOHAA actors are interpolated via `netorigin`, and whether the fgame corpse-impulse populates a nonzero `pos.trDelta` on the dying actor's state is unverified. Worse, the impulse moves the server entity over frames AFTER death — sampling at the EF_DEAD rising edge may read zero motion.

**REQUIRED PLAN CHANGE:** P0 task: log `s.pos.trDelta` on actor deaths. Fallback design: derive launch velocity from lerpOrigin deltas across the first 1-2 post-death snapshots (start the sim a snap late), or reconstruct from the damage direction cgame already observes for suppression/hit FX.

---

## Finding 12 — "Elevators/moving brushes: corpse sim traces against them at their current pose" is FALSE for the trace the plan names

**CLAIM (plan §5):** "corpse sim traces against them at their current pose each frame — good enough."

**VERDICT: WRONG as stated.**

**EVIDENCE:** `CG_Trace` (`cgame/cg_predict.c:216-250`) calls `cgi.CM_BoxTrace(..., 0, mask, cylinder)` — collision model 0 = STATIC WORLD ONLY. Doors/elevators/movers are inline submodels, i.e. holes in model 0, clipped only when `cliptoentities = qtrue` routes through `CG_ClipMoveToEntities` (`:240-243`) against snapshot solids. With plain world traces, corpses ragdolling in a doorway fall through the closed door; on an elevator, through the platform into the shaft.

**REQUIRED PLAN CHANGE:** Either pass `cliptoentities = qtrue` for ragdoll point traces (budget: multiplies per-point cost by the solid-entity walk — fold into the §5 trace ceiling) or change the quirk statement to the truthful "corpses fall through movers/doors; accepted v1". Also: entity-clipped traces must skip the corpse's own entityNumber and other ragdolled corpses.

---

## Finding 13 — LOD question (plan P0): resolved, no interaction

**CLAIM (plan P0):** "LOD interaction ... verify lower LODs share bone indices anyway."

**VERDICT: CONFIRMED (no plan change).**

**EVIDENCE:** The LOD path in `RB_SkelMesh` only reduces `render_count` and remaps vertex collapse indices (`renderergl1/tr_model.cpp:1128-1231`); per-weight bone lookup is unchanged (`:1331-1337`, mesh>0 channel remap `:1376-1385`). Bone indexing is LOD-invariant. (`r_uselod 0` project default makes it moot anyway.)

---

## Summary counts

- CONFIRMED (plan claim or hoped-for fact verified): Findings 1, 5, 8-mechanism, 10, 13.
- WRONG (plan text must change before implementation): Findings 2, 3, 4, 7 (resolves the open Q1 against one of the two options), 9, 12.
- RISK (must be tracked, may bite later): Findings 6, 8-regression, 11.

**Blocking findings: 6** — F2 (cull gate/pop-out), F3 (matrix space), F4 (partial-skeleton tearing), F8 (gore stamp regression needs an owned decision), F9 (slot-reuse signals; the proposed serial doesn't exist), F12 (mover fall-through claim false). None of them invalidates the overall shape — cgame Verlet + renderer override table + paired bridge remains the right architecture (and Finding 7 now positively rules out the skeletor-layer alternative for this fork's listen-server reality).
