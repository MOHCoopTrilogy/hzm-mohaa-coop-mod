# Ragdoll Plan — Vet Round 1: Fact Check (adversarial, code-verified 2026-08-19)

Scope: every factual claim in `_research/ragdoll_plan.md` ("Grounded facts" + the seven
assigned questions). All paths relative to `C:\mohaa-coop-dev\openmohaa-hzm\code\` unless
noted. VERDICT legend: VERIFIED / PARTLY / FALSIFIED. Findings marked **BLOCKING** require a
plan change before implementation.

---

## 1. File:line citations

### 1a. renderergl1/tr_model.cpp:987/1017/1040 (SkelWeightGetXyz / SkelVertGetNormal)
- CLAIM: skinning reads a per-surface bone cache via these functions at these lines.
- VERDICT: VERIFIED (minor imprecision).
- EVIDENCE: 987 = `SkelVertGetNormal` comment header (signature at 990, takes
  `skelBoneCache_t *bone`); 1017 = `SkelWeightGetXyz(skelWeight_t*, skelBoneCache_t*, vec3_t)`;
  1040 = `SkelWeightMorphGetXyz` (the plan attributes this line to the other two names — it is
  the third sibling, morph variant). All three consume `skelBoneCache_t.matrix/offset`.
- Precision fix: the cache is per-ENTITY, not per-surface. `RB_SkelMesh` (tr_model.cpp:1064)
  reads `bones = &TIKI_Skel_Bones[backEnd.currentEntity->e.bonestart]` (line 1236) — one
  contiguous block per refEntity, indexed per-weight via
  `boneNum = ri.TIKI_GetLocalChannel(tiki, skelmodel->pBones[weight->boneIndex].channel)`
  (lines 1278-1280). The **fill site the plan's Phase-0 asks for is pinned**:
  `R_AddSkelSurfaces`, tr_model.cpp:829-850 — copies `newFrame->bones[i]` (from
  `R_GetFrame` → skeletor `GetFrame`) into `TIKI_Skel_Bones[TIKI_Skel_Bones_Index]`, then
  stamps `ent->e.bonestart`. Single fill site for refEntity skeletal models in gl1
  (tr_staticmodels.cpp:44 has a separate cache for BSP static models — never actors).
- REQUIRED CHANGE: none (wording only).

### 1b. cg_public.h:406-409 (Tag_NumForName / ForceUpdatePose / TIKI_Orientation)
- VERDICT: VERIFIED exactly. 406 `int (*Tag_NumForName)(dtiki_t*, const char*)`,
  407 `Tag_NameForNum`, 408 `void (*ForceUpdatePose)(refEntity_t*)`,
  409 `orientation_t (*TIKI_Orientation)(refEntity_t*, int tagNum)`.
  Wired in client/cl_cgame.cpp:809-813 (`cgi->ForceUpdatePose = re.ForceUpdatePose;
  cgi->TIKI_Orientation = re.TIKI_Orientation;`) — the cgi→client→refexport bridge is real.

### 1c. renderercommon/tr_public.h:185-186 (GoreImpact/GoreReset refexport precedent)
- VERDICT: VERIFIED exactly. 185 `void (*GoreImpact)(const vec3_t, const vec3_t)`,
  186 `void (*GoreReset)(int entityNumber)` (187 adds `GoreKillSplash`). Bridged at
  cl_cgame.cpp:834-836 to `cgi->R_GoreImpact/R_GoreReset/R_GoreKillSplash`.

### 1d. cg_public.h:448-449 (cgame side of the gore bridge)
- VERDICT: VERIFIED exactly. 448 `R_GoreImpact`, 449 `R_GoreReset` (450 `R_GoreKillSplash`),
  appended at end of `clientGameImport_t`, NULL when renderer lacks support — the exact
  pattern ragdoll should copy (NULL-guard on gl2).

### 1e. tr_model.cpp:1774 (RE_ForceUpdatePose)
- VERDICT: VERIFIED. 1774 = comment header; function at 1777. Note semantics: it stamps
  `tr.skel_index[entityNumber] = tr.frame_skel_index` then `TIKI_SetPoseInternal` —
  unconditional. Its sibling `R_UpdatePoseInternal` (1754) SKIPS if the entity's pose was
  already set this render frame; `RE_TIKI_Orientation` (1797) calls the skipping variant.
  Consequence for capture: cgame calls `cgi.ForceUpdatePose(&ent)` once, then every
  `cgi.TIKI_Orientation` that frame reuses that pose — correct and cheap.

### 1f. build.ps1 "exe+cgame+renderer already ship together"
- VERDICT: VERIFIED. C:\mohaa-coop-dev\build.ps1:190-194 deploys `openmohaa.exe`,
  `cgame.dll`, `game.dll`, `renderer_opengl1.dll` together to both bin roots.

---

## 2. cgi.TIKI_Orientation — what space? (P0 question, answered)

- CLAIM (plan §2/§6): unknown whether it returns bone-space or model-space.
- VERDICT: ANSWERED — **model-local space** (the entity's un-rotated, un-translated model
  frame), NOT world.
- EVIDENCE: `RE_TIKI_Orientation` (renderergl1/tr_model.cpp:1797-1801) →
  `TIKI_OrientationInternal` (tiki/tiki_tag.cpp:94-114) → `skeletor->GetBoneFrame(tagnum)`
  (skeletor/skeletor.cpp:1038-1041, the skeletor's model-space bone SkelMat4).
  `orient.origin = (boneframe.val[3] + tiki->load_origin) * (refent.scale * tiki->load_scale)`;
  `orient.axis` = raw copy of the 3x3 rotation rows. Every cgame caller then composes with
  the entity: `CG_AttachEntity` (cgame/cg_modelanim.c:904-944) does
  `world_origin = parent->origin + Σ or.origin[i]*parent->axis[i]` (lines 918-922) and
  `world_axis = or.axis * parent->axis` (`MatrixMultiply(or.axis, parent->axis, ...)`,
  line 925/935-936). Head-icon and foot-shadow callers do the same VectorMA-through-axis
  composition (cg_modelanim.c:145-152, 450-454).
- WHAT CGAME MUST DO for world-space bone matrices at capture: build the corpse refEntity
  (tiki, frameInfo, scale, entityNumber), `cgi.ForceUpdatePose`, then per tag
  `o = cgi.TIKI_Orientation(&ent, tag)`; world pos = `ent.origin + Σ o.origin[i]*ent.axis[i]`;
  world axis = `MatrixMultiply(o.axis, ent.axis)`. Tag numbers from `cgi.Tag_NumForName` are
  the SAME index space as skeletor bone frames and the renderer bone cache
  (`GetBoneNumFromName` returns `m_boneList.LocalChannel(...)`, skeletor.cpp:1258-1269 — the
  identical tiki-local channel index RB_SkelMesh uses). One index namespace end to end.

---

## 3. EF_DEAD

- CLAIM: exists, set server-side on dead actors, visible in cgame, gore reset already
  branches on the EF_DEAD/EF_TELEPORT edge.
- VERDICT: VERIFIED on all four points.
- EVIDENCE:
  - Definition: fgame/bg_public.h:414 `#define EF_DEAD 0x00000200` (header shared with cgame).
  - Actors: fgame/actor.cpp:5435 `edict->s.eFlags |= EF_DEAD;` in `Actor::HandleKilled`
    (HZM bug-780 addition — comment at 5430-5434 says it was added precisely for cgame edge
    detection). Also body queue fgame/body.cpp:40 and players fgame/player.cpp:3466
    (cleared on respawn at player.cpp:2711).
  - cgame visibility: `cent->currentState.eFlags & EF_DEAD` used at cgame/cg_snapshot.c:122
    and cg_modelanim.c:1518/1852/1859.
  - The template the plan should copy: **`CG_TransitionEntity`, cgame/cg_snapshot.c:113-136**.
    Falling edge + EF_TELEPORT_BIT toggle → `cgi.R_GoreReset(...)` (121-126); RISING edge →
    `cgi.R_GoreKillSplash(...)` (132-136). Ragdoll arming belongs on the same rising edge;
    ragdoll clearing on the same falling-edge/teleport clause. Caveat: this fires on snapshot
    transitions — an actor that dies OUTSIDE the client's PVS and is later seen will present
    EF_DEAD already set with no edge (CG_ResetEntity path, cg_snapshot.c:75-104 has no gore
    hook either — those corpses keep anim pose today, and would keep anim pose under ragdoll:
    acceptable, but state it in the plan).
  - The corpse impulse the plan references exists: actor.cpp:5437-5449 (`g_corpseImpulse`,
    explosive MODs shove the dying actor server-side).

---

## 4. Bone names (LBD table + real skds)

- CLAIM: 19-hitloc LBD map hard-codes Bip01 names; the 15 plan bones exist as tags.
- VERDICT: VERIFIED, zero spelling drift.
- EVIDENCE:
  - LBD table qcommon/cm_trace_lbd.cpp:31-51 (19 entries, MAX_HITLOCATIONS 19 at :29):
    `Bip01 Head/Neck/Spine2/Spine1/Spine/Pelvis/R|L UpperArm/R|L Thigh/R|L Forearm/R|L Calf/
    R|L Hand/R|L Foot` — exactly the plan's spellings ("UpperArm" one word, single spaces).
    Resolved at runtime via `tiki->GetBoneNumFromName(pszTagName)` (cm_trace_lbd.cpp:479,571)
    — the SAME lookup `cgi.Tag_NumForName` uses (tiki/tiki_tag.cpp:36-39), so tags == bones ==
    channels; if LBD hit detection works on a model (it does, game-wide), Tag_NumForName
    finds these names on that model.
  - Parsed actual skd binaries (parser: scratchpad skd_bones.py, format from
    skeletor/skeletor_model_file_format.h — `skelBaseHeader_t` + variable-length
    `boneFileData_t` walked by ofsEnd). All 17 plan bones (15 + R Forearm/R Hand implied)
    present with exact case in every body checked:
    - AA: `models/human/allied_army_soldier/usarmy.skd` (42 bones),
      `models/human/german_wehrmact_soldier/heerprivate.skd` (42) — main/Pak0.pk3
    - BT: `models/human/SC_AL_US_INF/SC_AL_US_INF.skd` (maintt/pak3.pk3)
    - SH-era: `models/human/allied_british_tank_corporal/brit_tank_corp.skd` (72 bones,
      mainta/pak3.pk3)
    - Mod-imported: `hzm-mohaa-coop-mod/models/6abs/brit_para.skd`,
      `models/britpack/battledress.skd` (42 each)
  - The LBD table also uses **"Bip01 Spine"** (base spine) which the plan's 15-point list
    omits — present in every skd; fine to omit from the sim, but see finding 9: it cannot be
    omitted from the OVERRIDE.
  - Wound-prop precedent confirmed: fgame/sentient.cpp:3453
    `const char *bones[3] = {"Bip01 Head", "Bip01 Neck", "Bip01 Head"};` plus
    Tag_NumForName("Bip01 Head"/"Bip01 Neck") at sentient.cpp:2603/2681/3166/3481 and
    actor.cpp:3269 (head controller tag).
- REQUIRED CHANGE: none for names. (Known engine quirk, already documented in tiki_tag.cpp
  POSECHK comment ~:176-183: `2nd-ranger_private.tik` carries a stray "grenade" bone from a
  gear skd with a case-colliding ORIGIN — harmless, nothing skinned to it.)

---

## 5. Multi-skelmodel humans: one skeletor / one refEntity? (decides table shape)

- CLAIM (implicit): one override table entry per entityNumber covers the whole body.
- VERDICT: VERIFIED — one refEntity, one bone block, one index namespace.
- EVIDENCE:
  - Data: `models/human/1st-ranger_private.tik` setup = `skelmodel usarmy.skd` (body) +
    `$include models/human/heads/us_young_heads.tik` (head skd) + `skelmodel hand.skd`
    (hands) + per-loadout gear skds — ALL inside one TIKI `setup`, i.e. one `dtiki_t` with
    `numMeshes` > 1.
  - Renderer: `R_AddSkelSurfaces` fills ONE bone block sized
    `num_tags = ri.TIKI_GetNumChannels(tiki)` (the union channel list across all meshes,
    tr_model.cpp:763-768, 829-850), then iterates `tiki->numMeshes` adding surfaces
    (:912-979). `RB_SkelMesh` maps each mesh's skd-local bone index → global channel →
    tiki-local channel into that SAME block (:1236, 1278-1280).
  - Skeletor: one `skeletor_c` per (tiki, entityNumber) pair — `TIKI_GetSkeletor`
    tiki/tiki_cache.cpp:305-340, cache sized TIKI_MAX_ENTITIES=2048 x 2 (tiki_shared.h:92-94
    — already raised to match the 2048 entity pool, no modulo aliasing).
  - So: one table entry per entityNumber covers body+head+hands+gear. Separate refEntities
    exist only for ATTACHED entities (helmets-as-entities, wound props, weapons) — which is
    exactly the Hook-B problem (finding 10).

---

## 6. LOD

- CLAIM: r_uselod 0 is project default; verify lower LODs share bone indices / a LOD swap
  mid-ragdoll can't break the mapping.
- VERDICT: VERIFIED — LOD cannot break bone indexing, by construction.
- EVIDENCE: MOHAA LOD is a progressive-mesh VERTEX collapse inside the same surface, not a
  mesh swap: `RB_SkelMesh` tr_model.cpp:1128-1180 computes `render_count` from
  `GetLodCutoff` and collapses triangle indices via `sf->pCollapse` (:1205-1227). The
  per-vertex weight records and their bone channels are untouched; the bone cache always
  holds ALL `TIKI_GetNumChannels(tiki)` channels regardless of LOD. Bones are never LOD'd.
  With `r_uselod 0`, `GetLodCutoff` (:472-504) returns `LOD->curve[0].val` unconditionally
  (`... || !r_uselod->integer`, :491) = full detail, so there is no collapse at all under the
  project default. (`nolod_*.skd` variants in the pk3s are separate models referenced by
  different tiks, not runtime swaps.)
- REQUIRED CHANGE: none. Drop this from the P0 unknowns list.

---

## 7. "entityNumber < MAX_CLIENTS" as the is-a-player test

- CLAIM (plan §8.7): never arm when `clientNum < MAX_CLIENTS`.
- VERDICT: PARTLY — safe as a conservative EXCLUSION, wrong as a player CLASSIFIER.
- EVIDENCE:
  - `MAX_CLIENTS` = 64 (qcommon/q_shared.h:1654). Players always occupy entity slots
    0..game.maxclients-1; no player can sit at entnum >= 64. So skipping everything < 64
    never ragdolls a player. BUT `game.maxclients = sv_maxclients + sv_maxbots`
    (fgame/g_main.cpp:355) is typically far below 64, and `Level::AllocEdict` starts its
    free-slot scan AT `g_entities[game.maxclients]` (fgame/level.cpp:1744-1746) — on a
    listen coop server with e.g. maxclients 8, entity slots 8..63 are handed to the first
    ~56 world spawns, **including actors**. A `< MAX_CLIENTS` skip silently disables ragdoll
    for every AI unlucky enough to load into a low slot (map-load actors on every map).
  - Correct client-side tests, from this fork's own code: players are `eType == ET_PLAYER`
    (set fgame/bg_misc.cpp:315/360; cgame branches on it at cg_modelanim.c:1518/1852);
    actors are `ET_MODELANIM` (fgame/actor.cpp:2915). True client-slot count is available as
    `cgs.maxclients` (cgame/cg_servercmds.c:140, parsed from serverinfo).
  - Caveat discovered: dead-PLAYER corpses (body queue, fgame/body.cpp:38-40) are
    `ET_MODELANIM` + `EF_DEAD` + entnum >= game.maxclients + `clientNum` set to the dead
    player (entityState_t.clientNum, q_shared.h:2193 "for players and corpses") — they PASS
    an "actors only" eType guard. Decide explicitly: ragdolling the body-queue copy does not
    touch the live player/DBNO entity and is probably desirable; if not wanted, additionally
    reject `s.clientNum` valid on ET_MODELANIM corpses.
- REQUIRED CHANGE: guard = `eType == ET_MODELANIM && (eFlags & EF_DEAD) rising edge &&
  entityNumber >= cgs.maxclients` (belt: also `!= ET_PLAYER`), NOT `< MAX_CLIENTS`.

---

## FALSIFIED / MISSING facts that change the design

## 8. **BLOCKING — the override table cannot hold WORLD matrices**

- CLAIM (plan §2 diagram): "override table: per-bone 3x4 world matrices"; cgame "capture
  pose (bones -> world)" and pushes world matrices.
- VERDICT: FALSIFIED as specified.
- EVIDENCE: the skinning consumes MODEL-LOCAL, UNSCALED bone transforms. `RB_SkelMesh`
  outputs `outXyz = out * (tiki->load_scale * ent.scale)` (tr_model.cpp:1099, 1292) where
  `out` came from bone matrix+offset — i.e. tess.xyz is model-space; the entity's
  rotation/origin are applied by the modelview matrix at draw. Confirmed independently by
  tr_gore.c:647-649: "Positions in tess.xyz are MODEL-space (entity rotation/origin are
  [not applied])". Also the cache offsets are PRE-scale and PRE-load_origin (the fill copies
  raw skeletor units, :829-844; contrast TIKI_OrientationInternal which ADDS load_origin and
  MULTIPLIES scale*load_scale before returning to cgame, tiki_tag.cpp:108-110).
- REQUIRED CHANGE: sim in world space if you like, but the table entries must be converted
  to entity-local, unscaled units each push:
  `local_pos = (transpose(ent.axis) * (world_pos - ent.origin)) / (ent.scale*tiki->load_scale) - tiki->load_origin`,
  `local_axis = world_axis * transpose(ent.axis)`. The corpse's `ent.origin/axis` continue to
  come from the server entityState every frame (dead actors still lerp/settle server-side),
  so this transform must use the CURRENT frame's refEntity placement, not the death-frame
  snapshot — otherwise the body double-moves when the server corpse slides.

## 9. **BLOCKING — `boneIndex[24]` is too small; non-overridden bones freeze in absolute space**

- CLAIM (plan §4): table holds up to 24 bone overrides; §3 sims 15 points; "leaf bones
  (hands/feet/head) inherit the parent swing".
- VERDICT: FALSIFIED — the cache stores ABSOLUTE model-space transforms per bone, so any
  skinned bone NOT overridden renders at its death-anim absolute pose while overridden
  neighbours move away. There is no parent-relative inheritance in the cache.
- EVIDENCE: cache fill is one flat absolute matrix per channel (tr_model.cpp:829-844);
  skinning reads only the weight's own bone (:1277-1289). Real channel counts: usarmy.skd
  body = 42 bones incl. 12 procedural helpers (`helper Lshoulder/Relbow/Lknee/Rhip...`,
  types SKELBONE_HOSEROT/AVROT — skinned smoothing bones), 2 clavicles, 2 toes, eyes bone;
  hand.skd adds **30 finger bones** (`Bip01 L Finger0..R Finger42`); heads/gear add more.
  A geared human tiki's union channel list is ~75-100. Overriding 15-24 of them leaves
  fingers floating at the old hand position, helper-skinned shoulder/hip/knee vertices
  anchored mid-air, toes detached from feet.
- REQUIRED CHANGE: cgame must emit a matrix for EVERY channel of the tiki (capture every
  bone's model-local matrix at death; for non-simmed descendants, compose
  `M_bone = M_capture_bone_relative_to_simmed_ancestor * M_simmed_ancestor_current` — the
  "rigid chunk follows its driving bone" rule, applied to all ~80 channels). Size the table
  entry to the engine cap (128 matches the renderer's own static-model bone array,
  tr_staticmodels.cpp:44) or allocate by `TIKI_GetNumChannels`. Note the legs being IK bone
  types (thigh/calf/foot = SKELBONE_IKSHOULDER/IKELBOW/IKWRIST in the skds) is harmless
  here because the override replaces skeletor OUTPUT, and capture reads final transforms.

## 10. **BLOCKING (now confirmed, was a P0 unknown) — the tag/attachment path does NOT read the bone cache**

- CLAIM (plan §2): "SAME table consulted by the tag-orientation path (attachments)" —
  written as a design property; §4 Hook B asks whether attachments flow through
  ForceUpdatePose+TIKI_Orientation or a separate path.
- VERDICT: ANSWERED — attachments flow through `cgi.TIKI_Orientation` → `RE_TIKI_Orientation`
  → **skeletor `GetBoneFrame`**, never touching `TIKI_Skel_Bones`. Overriding only the fill
  site leaves every attached entity (helmets, wound props, weapons in hands, smoke/fire
  emitters via cg_commands, foot shadows) at the death-anim pose while the mesh ragdolls.
- EVIDENCE: RE_TIKI_Orientation tr_model.cpp:1797-1801 reads
  `ri.TIKI_OrientationInternal(model->tiki, model->entityNumber, ...)` (skeletor); attach
  consumer `CG_AttachEntity` cg_modelanim.c:914. Other skeletor-direct consumers that will
  desync the same way: `TIKI_IsOnGround` (foot shadows), `R_GetTagPositionAndOrientation`
  (r_showSkeleton debug), eye-target head IK (skeletor.cpp:1144+).
- REQUIRED CHANGE: Hook B is mandatory in v1, not deferrable: make `RE_TIKI_Orientation`
  (and `RE_TIKI_IsOnGround` if foot shadows stay enabled on corpses) consult the ragdoll
  table for flagged entityNumbers before falling through to the skeletor. Alternatively
  suppress/skip attachments on ragdolled corpses in v1 — but that visibly pops helmets.
- GOOD NEWS (answers plan §8 Q2 for gore): the gore UV tracer needs NO extra work — it
  consumes `tess.xyz` AFTER RB_SkelMesh skinning (`R_GoreSkelSurfaceCheck` called at the
  tail of RB_SkelMesh with the just-filled tess ranges, tr_gore.c:645-656, 768-814), so
  stamps automatically land on the OVERRIDDEN pose.

## 11. **BLOCKING — "point velocities = corpse entity velocity" has no client-side source for actors**

- CLAIM (plan §3 Init): seed the sim from the corpse entity velocity (the shipped corpse
  impulse), and approximate hit direction "from that same velocity vector".
- VERDICT: FALSIFIED for actors.
- EVIDENCE: `pos.trDelta` IS a networked entityState field (qcommon/msg.cpp:1395-1398), but
  only PLAYERS populate it (`PlayerStateToEntityState` fgame/bg_misc.cpp:325/370,
  player.cpp:5414/8105). Actors never write `s.pos.trDelta` (only a clear site,
  g_utils.cpp:1462); the g_corpseImpulse shove (actor.cpp:5437+) changes the actor's
  server-side `velocity`, which reaches the client only as per-snapshot ORIGIN deltas.
- REQUIRED CHANGE: seed velocity = (currentState.origin - previousState.origin) /
  snapshot dt at the EF_DEAD rising edge (cgame already has both states in
  CG_TransitionEntity), optionally averaged over 2 snaps; or ship the impulse explicitly
  (server event/entityState field) if snapshot differencing proves too coarse for grenade
  flings. cg.frametime being milliseconds is confirmed (cg_local.h:220
  `int frametime; // cg.time - cg.oldTime`) — the plan's ms note is right.

---

## Additional confirmations (no change needed)

- `MAX_GENTITIES` = 2048 (`GENTITYNUM_BITS` 11, q_shared.h:1667-1668) — table sizing claim OK.
- Gore bridge precedent NULL-guards per renderer (cg_public.h:445-451 comment, cg_snapshot.c
  `if (cgi.R_GoreReset)`) — copy this for gl2-less ragdoll exports.
- Entnum reuse risk (plan §7.4) is real but detectable: cgame sees slot reuse as an EF_DEAD
  falling edge or EF_TELEPORT_BIT toggle (the exact clause at cg_snapshot.c:122-123) — the
  same trigger that must call R_ClearRagdoll; the skeletor cache is keyed (tiki, entnum)
  with 2 slots per entnum (tiki_cache.cpp:319-336), so a reused slot with a different tiki
  gets a fresh skeletor and capture stays coherent.
- `R_AddSkelSurfaces` runs once per refEntity per VIEW (portals/mirrors get their own
  bonestart block) — an override at the fill site covers all views for free.

## Blocking findings: 4 (items 8, 9, 10, 11)
