# Ragdoll plan vet #1 — PERFORMANCE / STABILITY / PATHOLOGICAL CASES

Adversarial review of `_research/ragdoll_plan.md` (v1, 2026-08-19). Every claim below was
checked against `openmohaa-hzm/code/` source, `docs/TRAPS.md`, and `.wolf/buglog.json`.
**BLOCKING** = the plan cannot be implemented as written without hitting the finding.

Verified constants used throughout: `MAX_GENTITIES = 2048` (`qcommon/q_shared.h:1667-1668`,
`GENTITYNUM_BITS 11`); `cg.frametime` is an **int, milliseconds** (`cgame/cg_local.h:220`),
assigned at `cgame/cg_view.c:2880` from `CL_CGameRendering`'s `cl.serverTime - cl.oldServerTime`
(`client/cl_cgame.cpp:1019`).

---

## F1 — BLOCKING: the collision spec is self-contradictory; "240 traces/frame" is only sane world-only

**CLAIM (plan §3, §5):** "Collision: per moving point, CG_Trace prev->new (2u box)"; "hard trace
ceiling 240/frame"; and (§5) "Elevators/moving brushes: corpse sim traces against them at their
current pose each frame — good enough."

**VERDICT:** Broken as written. The plan never chooses a value for CG_Trace's `cliptoentities`
parameter, and the two §5 statements require opposite values.

**EVIDENCE:**
- `cgame/cg_predict.c:216-250` — `CG_Trace(result, start, mins, maxs, end, skipNumber, mask,
  cylinder, cliptoentities, description)`. World part = one `cgi.CM_BoxTrace`. If
  `cliptoentities`, it calls `CG_ClipMoveToEntities`.
- `cgame/cg_predict.c:130-184` — `CG_ClipMoveToEntities` is a **linear loop over ALL
  `cg_numSolidEntities` with no bounds pre-cull**, one `cgi.CM_TransformedBoxTrace` per solid
  entity per call.
- `cgame/cg_predict.c:51-85` — the solid list is every snapshot entity with `nextState.solid`
  (live actors, players, brush models). On a count-scaled horde (cap 80 AI, per
  enemy-count-scaling) plus crates/doors/vehicles, `cg_numSolidEntities` is ~60-120.
- Arithmetic: 240 traces x ~100 solids = **~24,000 transformed box traces per frame** — a
  frame-rate cliff, not a budget.
- The engine's own client-side physics precedent traces **world-only**: tempmodel collision
  passes `qfalse` for cliptoentities (`cgame/cg_tempmodels.cpp:639-650`).
- But world-only means corpses fall through **every inline brush model** — elevator floors,
  func_ doors, crates, sandbag walls — because those are entities (`SOLID_BMODEL`), not world.
  §5's elevator sentence is then false.
- The middle path already exists: `CG_GetBrushEntitiesInBounds` (`cgame/cg_predict.c:87-122`)
  is a bounds-prefiltered, SOLID_BMODEL-only candidate query.

**REQUIRED CHANGE:** Specify: per point, world-only `CG_Trace(..., cliptoentities=qfalse)`;
plus **one** `CG_GetBrushEntitiesInBounds` per body per frame over the body AABB (inflated by
travel), then clip moving points only against that candidate list (typically 0-4 bmodels) via
`CM_TransformedBoxTrace`. Never clip against bbox entities (actors/players). Name the content
mask explicitly (MASK_SOLID-class). Rewrite the §5 elevator paragraph to match.

## F2 — Confirmed: 240 world-only traces/frame is affordable; the existing baseline is small

**CLAIM (plan §5):** 240/frame ceiling is acceptable.

**VERDICT:** CONFIRMED **for world-only traces** (given F1's fix).

**EVIDENCE:** Existing per-frame CG_Trace spend is lower than assumed: retail precise foot
shadows (2 entity-clipping traces per character, `cg_modelanim.c:509`, note it passes `qtrue`)
are gated behind `cg_shadows 2`, and cgame registers `cg_shadows` **default "0"**
(`cg_main.c:181`) — off. The shipped Phase-A shadow decal (coop_shadowDir default 1,
`cg_modelanim.c:717,742`) does **one world-only CM_BoxTrace per visible character per frame**
(~30-80/frame on hordes). Tempmodels (casings/debris) add ~10-50 world-only traces during
firefights (`cg_tempmodels.cpp:639`). So ragdoll's 240 world-only traces ≈ 2-4x today's whole
trace budget — fine. With entity clipping it is ~100x per trace — see F1.

## F3 — BLOCKING: cg.frametime pathologies — the exact clamp, and steady-state slow motion below 60fps

**CLAIM (plan §3, §8-Q4):** fixed 120 Hz substeps accumulated from cg.frametime; "cap substeps
at 2/frame"; "clamp accumulated dt" (unspecified).

**VERDICT:** Under-specified in a way that produces two distinct failures.

**EVIDENCE:**
- `cg.frametime` = server-time delta (`cl_cgame.cpp:1019`), so: **timescale** scales it
  (ragdolls slow-mo with the world — correct, free); **pause** freezes it at 0; a load hitch or
  `CL_AdjustTimeDelta` `<RESET>` (`cl_cgame.cpp:1082-1085`, deltaDelta > 500ms) can spike it by
  seconds; and it **can be 0 or negative** — this fork's cgame already guards
  `(cg.frametime > 0) ? ... :` in **14 places** (`cg_view.c:183,1157,1246,...`,
  `cg_drawtools.cpp:1850,...`). `CG_ProcessSnapshots` force-advances cg.time after vid_restart
  (`cg_snapshot.c:518-521`).
- **Hitch pathology:** with "cap 2 substeps" alone, one 2000ms hitch leaves ~1983ms in the
  accumulator; each later frame consumes 16.7ms (2 x 8.33ms) while adding ~16.7ms at 60fps —
  the accumulator **never drains**: permanently maxed substep cost and corpses in slow motion
  for the rest of the map.
- **Steady-state pathology (not just hitches):** 2 substeps x 8.33ms = 16.7ms of simulated time
  per rendered frame. Any client below 60fps gets permanent corpse slow motion (half speed at
  30fps). 80-AI horde frames on period hardware WILL dip below 60. com_maxfps/cl_maxfps changes
  move this threshold directly.

**REQUIRED CHANGE:** Write the clamp into §3 exactly: `if (cg.frametime <= 0) return;`
`accumMs += min(cg.frametime, 200); step while (accumMs >= SUBSTEP_MS && steps < MAX_STEPS);`
then `accumMs = min(accumMs, SUBSTEP_MS * MAX_STEPS)` — i.e. **discard excess time after
stepping** so a hitch costs one fast-forward-free frame, never a permanent backlog. And pick a
substep budget that covers the real min spec: either 60 Hz substeps with cap 2 (correct speed
down to 30fps) or 120 Hz with cap 4 (down to 30fps at double cost). State the supported
minimum fps in the plan.

## F4 — BLOCKING: the horde grenade + "oldest freezes" eviction = upright frozen statues (the bug-856 shape again)

**CLAIM (plan §5):** "coop_ragdollMax 8 (oldest ragdoll freezes at last pose, stays overridden
— freezing is fine, corpses are static)".

**VERDICT:** Broken. "Corpses are static" is false at eviction time under the mod's own load
profile.

**EVIDENCE:**
- The mod count-scales to ~80 AI; a grenade kills 10+ in one frame. Under §5 as written,
  **every death arms** (capture + slot steal from the oldest). A 12-kill grenade arms 12,
  evicting sims that are **mid-air or mid-crumple** — frozen at (or near) the capture pose,
  which on the death frame is essentially the last alive anim frame: an upright statue,
  permanently overridden, hanging in the air if launched.
- Capture cost itself is bounded and acceptable: per death = 1 `cgi.ForceUpdatePose`
  (`RE_ForceUpdatePose`, `renderergl1/tr_model.cpp:1777-1790` → `TIKI_SetPoseInternal`, lazy
  bone eval via dirty flags, `skeletor/skeletorbones.cpp:474-477`) + 15 `cgi.TIKI_Orientation`
  reads (`tr_model.cpp:1797-1801`; per-frame deduped by `tr.skel_index[entnum]` check at
  :1756-1760, and bone frames are cached after first eval) ≈ **one extra character pose eval**
  — the same work the renderer does per visible character per frame. 12 in one frame ≈
  rendering 12 extra characters for one frame: a spike, not a cliff.
- The project has shipped this exact failure before, twice:
  - **bug-856/861/866** (in buglog only via bug-866's text — bug-856 itself has NO entry in
    `.wolf/buglog.json`, 1310 entries checked): the original blast-decap build "regressed:
    under coop count-scaled hordes + grenade spam ... one grenade fired dozens" of per-death
    spawns with "no per-frame cap so a horde grenade decapped many AI in ONE frame" — reverted
    wholesale by bug-892.
  - **bug-780** in the gore system, same renderer: "the LRU steal began eating LIVE instances
    (see the steal-priority fix in R_GoreAcquireInstance)" (`renderergl1/tr_gore.c:47-51`).
    The fix pattern the plan needs already exists in the file it is modeled on.
- Deaths 9..N: the plan does **not** leave them at anim pose — §5 arms them and evicts older
  sims. Nothing in the plan bounds arms-per-frame either.

**REQUIRED CHANGE:** Steal priority, mirroring R_GoreAcquireInstance: a new death may take
(a) a free slot, else (b) a slot whose sim is **asleep** (prefer out-of-PVS sleepers). If
neither exists, the new death **does not arm** — corpse keeps the server death anim (exactly
today's look; this is the plan's own failure-ladder philosophy). Never evict an awake sim.
Additionally cap arms per frame (e.g. 4) and queue the remainder ~1-2 frames (visually
indistinguishable) so the death-frame capture spike is bounded by design, not by luck. Add an
`arms refused` counter to r_ragdollDebug so the policy is observable (T14: absence does not
log).

## F5 — Memory: dense table is 2.45 MiB and 24 bone slots is wrong-sized in BOTH directions

**CLAIM (plan §4):** table `{qboolean active; int count; int boneIndex[24]; float mat[24][3][4]}`
indexed by entityNumber `[MAX_GENTITIES]`.

**VERDICT:** Works but oversized by ~200x as a table and **undersized per entry**; the fork's
own gore system demonstrates the correct shape in the same renderer.

**EVIDENCE:**
- Arithmetic: per entry 4+4+96+1152 = **1,256 B**; x2048 = **2,572,288 B ≈ 2.45 MiB** static
  BSS per renderer that compiles it (the actual need is 8 sims x 1,256 B ≈ 10 KB).
- Precedent in-repo: `renderergl1/tr_gore.c:175,180,194` — 48 **slotted** heavy instances +
  `s_goreEntityHas[GORE_MAX_ENTNUM]` **1-byte dense fast-out** + every entnum index
  bounds-checked (`:352,395,442`), with `GORE_MAX_ENTNUM = MAX_GENTITIES` following the
  protocol constant by name (bug-930 comment at `:55`). The dense-heavy-table shape is also
  the exact T4 bug family (skel_index[1024]: bug-932b gl1, gl2 twin, `processed[MAX_ENTITIES]`
  bug-935).
- **24 bones is not enough for coverage:** the bone cache holds an independent **absolute
  model-space transform per channel** — the fill loop copies every channel separately
  (`renderergl1/tr_model.cpp:829-844`) and skinning reads per-vertex bone refs against those
  entries (`SkelWeightGetXyz`, `tr_model.cpp:1017`). Any channel NOT overridden renders at the
  raw anim pose — so finger/face/gear channels beyond the 24 render **detached** from their
  ragdolled parent bones (hands fly off, faces stay behind). Human skds carry well over 24
  channels (`num_tags = ri.TIKI_GetNumChannels(tiki)`, `tr_model.cpp:763`).

**REQUIRED CHANGE:** MAX_RAGDOLLS-slotted payload + `byte slotPlusOne[MAX_GENTITIES]` index
(gore's shape). Size the per-slot matrix array to the model's full channel count (bounded by
an engine-real per-model cap, asserted at capture), and fill **every** channel — non-simmed
children take their simmed parent's delta transform. Keep every entnum index bounds-checked
against MAX_GENTITIES symbolically (T4).

## F6 — BLOCKING: gl2 NULL bridge = crash; vid_restart premise corrected; restart clear-sites missing

**CLAIM (plan §4):** "gl2: no hook in v1 — table exists renderer-side, gl2 simply never reads
it." (And the vetting brief assumed "renderer tables are wiped on restart while cgame keeps
simming.")

**VERDICT:** Two errors and one gap.

**EVIDENCE:**
- **gl2 crash:** `refexport_t` is shared by both renderers (`renderercommon/tr_public.h`). If
  `R_SetRagdollBones`/`R_ClearRagdoll` are implemented only in gl1 and gl2 never fills those
  struct slots, the pointers are NULL under `cl_renderer opengl2` and the first AI death
  **crashes the client**. The gore bridge already shows the required pattern: cgame NULL-checks
  `if (cgi.R_GoreReset)` / `if (cgi.R_GoreKillSplash)` before every call
  (`cgame/cg_snapshot.c:121,132`). The plan must mandate NULL-checked cgame calls AND gl2
  stub exports (both — a stub protects future callers, the NULL check protects against a
  renderer that predates the export).
- **vid_restart premise is false:** `CL_Vid_Restart_f` shuts down BOTH sides —
  `CL_ShutdownRef()` at `client/cl_main.cpp:1619` and `CL_ShutdownCGame()` at `:1624` ("we
  also have to reload the UI, CGame and TIKI system", `:1584`). There is no wiped-renderer /
  live-cgame desync window; sim state and table die together.
- **The real vid_restart gap:** after restart, corpses arrive in the initial snapshot with
  EF_DEAD already set (`CG_SetInitialSnapshot` → `CG_ResetEntity`, `cg_snapshot.c:165-202`) —
  no death edge fires, so **every previously-ragdolled corpse snaps back to the server anim
  pose**. This is user-reachable mid-session: the mod's shipped Borderless/Exclusive display
  selector applies through exactly this path (and bug-1145 shows settings-apply exercising
  CL_ShutdownRef/CL_InitRef). tr_gore accepts the same loss (instances reset "on renderer
  shutdown", `tr_gore.c:28-31`). The plan must either document the snap-back as accepted, or
  arm-on-first-sight-of-EF_DEAD with zero initial velocity (settled capture — benign, and
  makes late-joiners consistent too).
- **Missing clear sites:** the plan clears on entity free and kill-switch only. It must also
  clear-all in `CG_ServerRestarted` (differentServer transition, `cg_snapshot.c:217-219`) and
  on cgame init/shutdown.

**REQUIRED CHANGE:** NULL-check every new cgi bridge pointer in cgame; provide gl2 stubs; add
ClearAll at CG_ServerRestarted + CG_Init; state the post-vid_restart snap-back behavior
explicitly in §5.

## F7 — BLOCKING: PVS exit/re-entry is survivable, but two hard requirements and one reuse hole

**CLAIM (plan §7-risk-4, §8-Q3):** table entries must be keyed to "a spawn counter/serial, not
entnum alone"; asks what serial cgame has.

**VERDICT:** Answer: **cgame has no spawn serial at all** — the plan must be rewritten around
observable edges, and one reuse case has no observable edge.

**EVIDENCE:**
- **Leave PVS:** cent persists (static `cg_entities[]`); `currentValid = qfalse` and
  `currentState` freezes at last-seen (`cg_snapshot.c:224-228`). Keeping the sim running is
  safe; nothing renders it.
- **Re-enter PVS:** `CG_TransitionEntity` compares frozen `currentState` vs `nextState` —
  dead→dead toggles nothing; the gore hook comment documents this exact invariant: "PVS
  re-entry alone changes neither flag, so wounds correctly survive it"
  (`cg_snapshot.c:115-126`). Ragdoll override survives re-entry — CORRECT — **but only if
  per-cent arm state does not live in `cent->clientFlags`**: re-entry always runs
  `CG_ResetEntity` (`interpolate=qfalse` → `:142-144`), which zeroes `clientFlags`
  (`cg_snapshot.c:65`). The plan never says where per-cent state lives; forbid clientFlags.
- **Reuse detection available to cgame** is exactly the heuristic set the engine itself uses:
  `!currentValid`, EF_TELEPORT_BIT toggle, `parent` change, `modelindex` change
  (`cg_snapshot.c:326-333`); plus the EF_DEAD falling edge (gore's reuse catch, `:121-126`).
  Reuse to a live actor fires the falling edge — covered.
- **The hole:** slot freed and reused **corpse→corpse with the same modelindex while out of
  PVS** (count-scaled twin killed off-screen into a recycled slot; MP body-queue churn). No
  flag toggles, no falling edge, teleported can't set (`:331` requires currentValid). The
  frozen/settled override then renders the OLD corpse's bones on the NEW corpse — a ghost
  tangle at the wrong position.

**REQUIRED CHANGE:** (1) per-cent ragdoll state lives in cg_ragdoll.c's own array, never
clientFlags; (2) clear on the full edge set: EF_DEAD falling edge, EF_TELEPORT_BIT toggle,
modelindex change, parent change (mirror `cg_snapshot.c:326`); (3) close the hole: on the
`!currentValid → valid` re-entry of an armed entnum, compare the snapshot origin against the
ragdoll's captured root — discontinuity beyond ~64u ⇒ ClearRagdoll (falls back to anim pose,
today's look). `cent->snapShotTime` (`cg_snapshot.c:246`) is available for staleness checks.

## F8 — Hook A alone provably misses attachments; the twin-hook obligation is real (and the exe alternative is a deploy trap)

**CLAIM (plan §2/§4):** skelBoneCache fill site is "the single override choke point"; Hook B
is a phase-0 "find whether" task.

**VERDICT:** Phase-0 question already answerable: the cache is NOT a choke point for tags.
Hook B is mandatory, and its site is known.

**EVIDENCE:** The tag path never reads `TIKI_Skel_Bones`: `RE_TIKI_Orientation`
(`renderergl1/tr_model.cpp:1797-1801`) calls `R_UpdatePoseInternal` then
`ri.TIKI_OrientationInternal` → `skeletor->GetBoneFrame(tagnum)` (`tiki/tiki_tag.cpp:94-114`)
— straight from the skeletor. Every cgame attachment/eyes/foot consumer goes through
`cgi.TIKI_Orientation` (= this function): `cg_ents.c:716`, `cg_modelanim.c:145,269,450,914`,
`cg_specialfx.cpp:718`, etc. So overriding the cache moves the body while every attachment
(helmet, wound props) stays at anim pose — the plan's own feared outcome, now confirmed.
The single-choke-point alternative (override inside the skeletor) is **exe-side code**
(`ri.TIKI_*` are exe callbacks registered at `client/cl_main.cpp:3315-3318`) — and the exe is
the project's known deploy gap (TRAPS T10: build.ps1 does not deploy openmohaa.exe). The
plan's renderer-side twin-hook architecture is therefore RIGHT; it just must stop calling
Hook B a question. Note `RE_TIKI_IsOnGround` (`tr_model.cpp:1808-1812`) reads bone frames the
same way (decide: override or ignore for corpses). Capture-side caveats to write into P1:
(a) `cgi.ForceUpdatePose` stamps `tr.skel_index[entnum] = tr.frame_skel_index`
(`tr_model.cpp:1779-1781`), which suppresses the renderer's own re-pose for that entity that
frame — build the capture refEntity from the same cent fields CG_ModelAnim submits, or capture
after the scene; (b) `TIKI_GetSkeletor` keeps only **2** cached skeletors per entnum with
delete-on-evict (`tiki/tiki_cache.cpp:319-344`, `TIKI_MAX_ENTITY_CACHE_PER_ENT 2`,
`tiki_shared.h:92-93`; TIKI_MAX_ENTITIES=2048 matches the pool, no modulo aliasing) — always
capture with the cent's own tiki handle or you evict the live skeletor mid-frame.

## F9 — Fill-site mechanics the override must respect (space, culling, per-view, overflow)

**EVIDENCE (all `renderergl1/tr_model.cpp`, R_AddSkelSurfaces):**
- The cache entries are **model-space** transforms copied verbatim from the skeletor
  (`:829-844`) — the plan's "per-bone 3x4 **world** matrices" table is in the wrong space for
  Hook A; cgame must push model-space (world x inverse entity matrix) or the renderer must
  convert. (Sim in world space is right for traces; conversion belongs at push time.)
- The copy loop is **skipped when the model culls out** while `TIKI_Skel_Bones_Index` still
  advances (`:824-850`) — the override write must tolerate never-read slots.
- Fill runs **once per entity per VIEW** (portals/mirrors re-run it; bug-1214 note) — the
  override hook must be idempotent per view, not per frame.
- Bone-pool overflow skips the whole model with only a PRINT_DEVELOPER line (`:765-768`) —
  an overridden corpse can simply not render on a saturated scene; harmless, but do not
  assert on "pushed but never consumed".
- Plan §8-Q2 (gore tracer): consistent **automatically** if Hook A overwrites before
  RB_SkelMesh skins — gore ray-tests freshly skinned triangles in model space
  (`tr_gore.c:13-18`), so stamps land on the ragdolled pose. Server hit registration still
  uses server-side LBD at anim pose (`qcommon/cm_trace_lbd.cpp:486` runs off the game's own
  skeletor) — already declared out of scope by the plan (hitboxes unchanged), consistent.
- Cosmetic desync worth one plan line: the Phase-A shadow decal traces from entity origin
  (`cg_modelanim.c:740-742`), so a launched ragdoll leaves its shadow at the server corpse
  origin.

## F10 — Cvar/T7 footnote

`coop_ragdoll` will be cgame-registered but scripts run fgame-side; on a listen server both
share one cvar table. If any script ever `getcvar`s it before cgame registers, TRAPS T7 /
bug-1669 applies (script getcvar creates it EMPTY and the engine default is dead forever).
Harmless while default is "0"; the moment P5 flips the default to "1", pre-register it in
`G_InitGame` alongside the other coop_* cvars or keep scripts away from it. Also: never give
`r_ragdollDebug` CVAR_ARCHIVE (T7, bug-1427/bug-1148), and note CVAR_CHEAT debug cvars are
useless on a listen server (sv_cheats 0 clamps them — use CVAR_TEMP, bug-1148 precedent at
tiki_tag.cpp:168).

---

## Summary

| # | Severity | One-liner |
|---|---|---|
| F1 | **BLOCKING** | cliptoentities unspecified: qtrue = ~24k transformed traces/frame on hordes, qfalse = corpses fall through elevators/doors/crates; must spec world-only + CG_GetBrushEntitiesInBounds bmodel clip |
| F2 | ok | 240 world-only traces/frame confirmed affordable (existing baseline ~30-130/frame) |
| F3 | **BLOCKING** | exact accumulator clamp missing (one hitch = permanent slow-mo backlog); 120Hz/cap-2 = permanent corpse slow motion below 60fps steady-state |
| F4 | **BLOCKING** | "oldest freezes" evicts awake sims → upright mid-air statues on horde grenades; per-frame arm count unbounded; = the bug-856/861 shape and gore's bug-780 LRU bug; need steal-priority + arm cap + refusal counter |
| F5 | should-fix | dense table = 2.45 MiB for a 10 KB need (gore's slotted+byte-index shape is in-repo); 24 bone slots under-covers human channel lists → detached fingers/gear |
| F6 | **BLOCKING** | gl2 refexport slots NULL → crash on first death under gl2 (gore NULL-check precedent exists); vid_restart premise corrected (cgame dies too, cl_main.cpp:1624); snap-back after restart + CG_ServerRestarted clear site unaddressed |
| F7 | **BLOCKING** | no spawn serial exists in cgame — heuristic edge set must be spec'd; corpse→corpse same-model slot reuse out of PVS has NO observable edge (needs origin-discontinuity clear); clientFlags is cleared on PVS re-entry and must not hold arm state |
| F8 | design-confirm | Hook B is mandatory (tag path reads skeletor, never the cache — tr_model.cpp:1797); renderer-side twin hooks beat the exe-side skeletor override (T10 deploy gap); two capture caveats (skel_index stamp, 2-deep skeletor cache) |
| F9 | spec-fix | cache is MODEL-space (plan says world); fill is per-view and cull-skipped; gore tracer consistent for free; shadow decal desync |
| F10 | footnote | T7 getcvar trap if default ever flips to 1; debug cvar flags |

Blocking findings: **5** (F1, F3, F4, F6, F7).
