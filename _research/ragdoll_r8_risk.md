# Ragdoll round-8 — risk / performance / shippability audit

Scope: the SETTLE branch as committed (`coop_ragdollMode 1` default), never yet playtested.
Lens: what breaks when this defaults ON for players. Everything below is cited to
`file:line` in the tree as of 2026-08-20. Where I say "verified", I read the code path end
to end; where I say "estimated", the number is arithmetic over verified constants.

Live-log baseline: the current `G:/mohaa-gl2/home/maintt/qconsole.log` holds 5 `RAGDOLL sleep`
lines and **none carry `branch=`/`drift=`** — confirming the settle branch has not run once.
The 22-corpse dataset in `_research/ragdoll_p3_session_2200.log` is all `channels=72`, which
is the channel count every number below uses.

---

## 0. Verdict

**Three blockers before `coop_ragdoll` can default to 1.** All three are cheap. Nothing in
the settle design is architecturally unshippable — the client-side-only choice holds up under
every multiplayer and listen-host probe I ran, and the settle branch's failure mode
(a body that keeps its authored pose) is *invisible*, which is the single best shippability
property this feature has.

| # | Blocker | Cost | Section |
|---|---|---|---|
| B1 | World traces eat the mover trace budget → bodies 4+ get **zero** mover collision and fall through elevators/doors | ~2 lines | §1.3 |
| B2 | `coop_ragdoll` is CVAR_TEMP and not pre-registered in `G_InitGame` — bug-1669 trap arms the moment any script reads it, and a player's OFF does not survive a restart | ~3 lines | §4 |
| B3 | The 3000 ms pending cap **arms on a mid-fall pose** — reproduces the user's exact complaint on a subset of deaths | ~6 lines | §2.1 |

Non-blocking, ship-worthy: `cgame.pdb` is built but never deployed (§5); `CG_ServerRestarted`
never clears the tables (§2.3); sleeping bodies pay a per-frame mover query forever (§1.4).

---

## 1. Performance

### 1.1 The headline number

**Worst case: 600 collision traces per rendered frame** — 480 world + ~120 mover — with 8
bodies awake at ≤31 fps. Steady-state that is **15,000 world box traces per second**, and it
is framerate-invariant above 31 fps.

Derivation, all constants verified in `cg_ragdoll.c`:

- `RAG_PTS 15` (:56), `RAG_MAX_STEPS 4` (:58), `RAG_SUBSTEP_MS 8` (:57), `RAG_MAX_SIMS 8`
  (:54), `RAG_TRACE_BUDGET 240` (:62).
- `RagCollideWorld` (:793-818) issues one `cgi.CM_BoxTrace` per point per substep, skipping
  only points whose substep displacement² < 0.0001 (:801) — i.e. essentially never under
  gravity.
- World traces/frame = 15 × substeps × bodies. At the 4-substep ceiling with a full pool:
  **15 × 4 × 8 = 480**.
- Substeps/second is fixed at 1000/8 = 125 by the accumulator (:1078). So world traces/second
  = 15 × 125 × 8 = **15,000**, whether the client runs at 40 fps or 144 fps.

At a conservative 2 µs per short (≤15 u sweep, ±7 u box) world `CM_BoxTrace`, 600 traces is
**~1.2 ms/frame** — ~7 % of a 16.7 ms frame, ~3.6 % of a 33 ms frame. Survivable, but it lands
entirely on the client main thread inside `CG_DrawActiveFrame` (`cg_view.c:2928`), and on a
listen host it stacks on top of the whole server frame. For scale: `PM_Move` costs on the
order of 10-30 traces per player per frame, so a full ragdoll pool is roughly 5× the trace
load of all four coop players' movement combined. It decays to zero as bodies sleep.

Adding the two missing foot points (`RAG_PTS` 15 → 17, the knee fix) takes this to 544
traces/frame / 17,000 per second: **+13 %**. Affordable — do not let perf block that fix.

### 1.2 Below 31 fps the sim runs in slow motion

`ms = min(cg.frametime, 200)` (:1064-1067), 4 substeps max, then the backlog is discarded
(:1088-1090). At 20 fps the sim consumes 32 ms of a 50 ms frame — corpses settle at **64 %
speed**. Meanwhile `rampMs` (:1071) advances in real ms, so the gravity ramp and the
shape-match relax run ahead of the physics they are supposed to be pacing. Cosmetic, but it
means a low-fps client sees a *different* settle than the tester did.

### 1.3 BLOCKER B1 — the trace budget is self-defeating

`RagCollideWorld` **increments** `s_ragTraceCount` (:806) but never **tests** it. Only
`RagCollideMovers` tests it (:850). The frame loop runs per body: world substeps first, then
movers (:1078-1093). So world traces spend the mover budget:

| body | world (4-substep) | cum | mover allowance |
|---|---|---|---|
| 0 | 60 | 60 | up to 60 → cum 120 |
| 1 | 60 | 180 | up to 60 → cum 240 |
| 2 | 60 | 300 | **0 — budget already hit** |
| 3-7 | 60 each | 600 | **0** |

At 60 fps / 2 substeps the same thing happens one body later. Consequence: with 3+ awake
bodies, **every body past the third has no brush-entity collision at all** and will drop
straight through a moving lift or a door — the exact `m2l2a` lift case named in the plan's
P3/P4 acceptance list (`ragdoll_plan.md` §6). The banner at :792 claims world traces are
"budget-EXEMPT"; the code makes them budget-*consuming* instead. Fix: separate counter, or
simply stop incrementing in `RagCollideWorld`.

### 1.4 Sleeping is not free

A `state == 2` sim calls `RagMoverHash` **every frame, forever** (:1052). That is
`CG_GetBrushEntitiesInBounds` (`cg_predict.c:87`), which walks `cg_numSolidEntities` and per
candidate does `cgi.CM_InlineModel` + `cgi.R_GetInlineModelBounds` — a **cross-DLL renderer
call** — plus `CalculateRotatedBounds` for any rotated mover. With a pool of 8 slept bodies on
a map carrying ~40 solid bmodels that is **~320 cross-DLL calls per frame in perpetuity**, for
bodies that are finished. Awake bodies pay the same query a second time in `RagCollideMovers`
(:837). Cheap fix: throttle the wake check to every 8th frame, or skip it when the body's
bounds held no movers at sleep time.

### 1.5 Matrix math and capture cost

Matrix math is **not** a concern. Per body per frame `RagPush` (:882-974) does 15 sim-point
rotations (~165 flops each: one `RagMat3FromTo` + three 3×3 products) plus 72 channels of
~80 flops (`RagMat3RotateVec` + three `DotProduct` + a 3×3 compose) ≈ 8,300 flops. Eight
bodies ≈ **66,000 flops/frame, ~20-30 µs, under 0.2 % of a frame**. The renderer half
(`R_RagdollApplyToCache`, `tr_ragdoll.cpp:113-172`) writes ~1,900 floats per ragdolled entity
per view fill — also negligible, even with a mirror doubling the fills.

The capture is the spike. `RagCapture` (:423-615) per body does one `cgi.ForceUpdatePose`
(→ `skeletor_c::SetPose`, `skeletor.cpp:352`, which dirties every bone at :376-379), then
72 × `cgi.TIKI_Orientation` (:464 — each resolves to one `GetBoneFrame`, together ≈ one full
skeleton evaluation), 144 × `Tag_NameForNum` (:445, :580), up to 72 × 15 distance tests in the
nearest-anchor fallback (:591-604), and up to 15 `CM_PointContents` + 15 `CM_BoxTrace` for the
pre-lift (:493-509). **Estimated 100-250 µs per capture.**

Under settle, captures are naturally staggered by differing death-anim lengths — *except* for
a grenade or satchel that kills a group with the same anim, where all 8 hand off within a
frame or two: **a one-off ~2 ms spike**. The plan's arm-rate bound ("max 4 arms/frame; the
remainder queue for 1-2 frames", `ragdoll_plan.md` §4 C3) is **not implemented anywhere**.
Under settle it belongs on `RagPendingThink`'s handoff, not on the death edge.

### 1.6 The worst realistic scenario in this mod: 20 die at once

`aihandler.scr:317,351` both describe the loop walking "~80 germans", so the premise is real.

- 20 `EF_DEAD` rising edges in one snapshot → `CG_RagdollTransition` (:1422-1436) creates a
  **pending record per death** until the pool is full.
- `RagAllocSlot` (:1160-1192) evicts **only** `state == 2` (:1177). Pending records are
  `state -1` and running sims are 0/1, so **nothing is evictable during a mass death**.
- Deaths 9-20 hit `arm refused (pool awake-full)` (:1186) and keep the server anim pose.

**What the 9th death looks like: exactly like today's game.** That is the settle branch's
best property. Under `coop_ragdollMode 3` the same refusal is glaring (some bodies crumple,
some snap to a pose); under settle the refused body keeps the same authored pose the armed
one was captured *from*, so the difference is a few units of drape. Do not fix the pool size —
this failure mode is a feature.

**Sustained throughput ceiling:** a slot is held for pending (≤3000 ms, :1281) plus life
(≤6000 ms, :1120) = up to **9 s**. Eight slots ⇒ **≈0.9 ragdolls per second sustained.** An
officer wave killing 3-5/s will ragdoll roughly 20-25 % of its deaths. Acceptable *only*
because of the paragraph above; if the settle drift ever grows large, this becomes a visible
lottery.

---

## 2. Correctness under adversarial conditions

### 2.1 BLOCKER B3 — PVS churn poisons the pending record

An entity that leaves the snapshot is never passed to `CG_TransitionEntity`
(`cg_snapshot.c:236-243` iterates only `cg.snap->entities`), so **no clear signal ever fires
for it**. For a pending record that means:

- `cs->frameInfo[dom].time` (:1252) stops advancing, so `animDone` can never become true.
- `cent->lerpOrigin` freezes, so `pendStatic` climbs — irrelevant, the `animDone` half is dead.
- The **3000 ms cap fires anyway** (:1281) and captures whatever mid-fall pose was frozen, then
  arms it as `branch = 1` with `goal[] = that mid-fall pose` (:1302-1304).

That is a standing soldier dropped cold — the precise round-8 finding the settle branch exists
to eliminate — reappearing on every body that leaves view mid-death. It will be read as "the
physics is bad", not "the capture was mistimed". The same cap also fires whenever the server
stops re-sending an unchanged corpse before the anim's final frame lands.

The sim then runs invisibly for up to 6 s at full trace cost (§1.1), and on PVS re-entry the
clear set (:1343-1347) does **not** fire — `EF_DEAD`, `modelindex` and `eType` are all
unchanged — so the stale sim keeps driving the mesh.

Fix (all fields verified to exist on `centity_t`): bail out of `RagPendingThink` when
`!cent->currentValid` or `cent->snapShotTime != cg.snap->serverTime` (set at
`cg_snapshot.c:245`), and make the 3000 ms cap a **drop**, not an arm. Losing a ragdoll costs
nothing; arming a bad one costs the verdict.

### 2.2 Entity slot reuse — one real gap

The normal case is covered: `CG_RagdollTransition`'s un-gated clear set (:1343-1347) fires
on the `EF_DEAD` falling edge, the `EF_TELEPORT_BIT` toggle, a `modelindex` change or an
`eType` change, and also resets `s_ragNeverArm` (:1346). A corpse slot reused by a *live*
entity therefore clears correctly.

**Gap:** a corpse slot reused by another entity that is *also* first-seen `EF_DEAD` with the
**same** modelindex and eType produces **no clear signal**, and the renderer's tiki-match belt
(`tr_ragdoll.cpp:46`) cannot catch it because the tiki matches. The old sim then drives the new
corpse. Needs `MAX_BODYQUEUE 128` (`actor.h:306`) corpses plus wraparound — rare, not
impossible in an 80-enemy map. The plan listed the missing guard verbatim
("snapshot absence → re-present with origin discontinuity > 64 u", `ragdoll_plan.md` §4); it
is unimplemented.

### 2.3 Map change / restart / vid_restart

Verified end to end:

- **Map change** (`stuffsrv "map <name>"` → `SV_Map_f` → new gamestate): `CL_ParseGamestate`
  (`cl_parse.cpp:546`) → `CL_FlushMemory` → `CL_ShutdownCGame` → `Sys_UnloadCGame`. cgame.dll
  is a real DLL (build.ps1 ships it), so **every cgame static — `s_ragSims`, `s_ragNeverArm`,
  `s_ragTraceCount` — is zeroed by the unload.** Then `CG_Init` calls `R_ClearAllRagdolls`
  before `cgi = *imported` (`cg_main.c:784-787`). **Clean.**
- **vid_restart**: `CL_Vid_Restart_f` (`cl_main.cpp:1588`) does `CL_ShutdownRef` (renderer DLL
  unloaded, `s_ragSlots` gone) then `CL_ShutdownCGame`, then re-inits both and reaches
  `CG_Init` → `R_ClearAllRagdolls`. Bodies snap back to the anim pose, exactly as the plan
  accepted. **Clean.**
- **`differentServer` server restart (no new gamestate)**: `CG_TransitionSnapshot(qtrue)`
  (`cg_snapshot.c:221`) calls `CG_ServerRestarted` (`cg_main.c:751-773`), which resets marks,
  temp models, VSS and objectives — and **does not touch the ragdoll tables**. The plan
  required "ClearAll at CG_Init + CG_ServerRestarted" (`ragdoll_plan.md` §5); the second half
  is missing. Not reached by this mod's own map transition, but reached by `restart`. Two
  lines: `CG_RagdollClearAll()` + `cgi.R_ClearAllRagdolls()`.

### 2.4 Listen host — CLEARED, with evidence

The plan forbade skeletor-layer changes because the skeletor is shared with the server game DLL
on a listen host. **The current code respects that, and I can show the server never reaches the
override table:**

- Server hit-location tracing goes `cm_trace_lbd.cpp:486` → `ge->TIKI_Orientation` →
  `G_TIKI_Orientation` (`g_main.cpp:909-916`) → `gi.TIKI_OrientationInternal` →
  `PF_TIKI_OrientationInternal` (`sv_game.c:1075-1077`) → `TIKI_OrientationInternal`
  **directly**.
- Hook B lives in `RE_TIKI_Orientation` (`renderergl2/tr_model.cpp:2353`), which is on the
  *renderer* path only. The server never calls it. **The override is genuinely render-only.**

One residual, and it is **not** reachable: `RagCapture`'s `cgi.ForceUpdatePose` (:461) *does*
write the shared skeletor. But `common.c:2263/2273` stamp `SV_SetFrameNumber` and
`CL_SetFrameNumber` with the same `com_frameNumber` at the top of `Com_Frame`, and `SV_Frame`
runs **before** `CL_Frame` — so by the time cgame writes, the server's frame is over, and the
next `Com_Frame` invalidates both caches (`level.skel_index`, `g_main.cpp:894`;
`tr.skel_index`, `tr_model.cpp:2307`). It is also pre-existing behaviour: `cg_modelanim.c:1956`
already re-poses the shared skeletor every frame for every character. The ragdoll adds one such
write per armed corpse.

**But it exposes a fidelity defect worth fixing anyway.** `RagCapture` memsets its local
`refEntity_t` (:429) and never sets `model.bone_tag` / `model.bone_quat`, which are *pointers*
(`tr_types.h:146`), so `skeletor_c::SetPose` skips the bone-controller block entirely
(`skeletor.cpp:380-392`). The normal render path sets them from the entity state
(`cg_modelanim.c:1480-1481`). So the comment at :459-460 — "this poses exactly what is on
screen" — is **false**: the capture is missing the head-look / torso-aim controllers. One line
(`model.bone_tag = ns->bone_tag; model.bone_quat = ns->bone_quat;` — both exist on
`entityState_t`, `q_shared.h:2187-2189`), and it makes the settle capture strictly more faithful.

### 2.5 Dedicated server — CLEARED

`common.c:2264` skips `CL_SetFrameNumber` entirely under `com_dedicated`. cgame is not loaded.
`cg_ragdoll.c` touches nothing outside the cgame module and reads no server state. **No
dedicated-server dependency, no dedicated/listen parity defect.**

### 2.6 Demo playback and stereo — CLEARED

- Demos: `CG_RagdollFrame` ignores `demoPlayback`, so ragdolls run from the *viewer's* cvars —
  the same demo replays with different corpses. Cosmetic, accepted. During a seek,
  `cg.frametime` (which is `cl.serverTime - cl.oldServerTime`, `cl_cgame.cpp:1022`) can jump;
  it is clamped to 200 ms (:1065) and the backlog discarded (:1088). Safe.
- Stereo: `CL_CGameRendering` sets `cl.oldServerTime = cl.serverTime` **after** the call
  (`cl_cgame.cpp:1024`), so a second (right-eye) `CG_DrawActiveFrame` receives frametime 0 and
  `CG_RagdollFrame` returns at :1017. **No double-stepping.**

### 2.7 One latent overflow, low risk

`RagCapture`'s census stops at `RAG_MAX_CH` 128 (:444). A tiki with >128 channels would have
channels 128+ left at the anim pose while 0-127 ragdoll — a mesh tear. Arming is gated to
`ET_MODELANIM` entities that resolve all 15 `Bip01` names (:478-480), so in practice only
72-channel humanoids reach it. Worth one guard line, not a blocker.

---

## 3. Multiplayer coherence — no real problem

Client-side ragdolls mean every player sees a different corpse. Enumerated against *this* mod:

| System | Verdict |
|---|---|
| **Corpse hit detection** | Unaffected. Coop actor corpses get a flat 64×64×16 `CONTENTS_WEAPONCLIP` `SOLID_BBOX` slab (`actor.cpp:12492-12495`, `coop_corpseShootable 1`). The ragdoll never moves the entity origin, so the slab stays under the visual. Divergence = the logged `drift` (:1148), small by construction under settle. |
| **`CL_TraceDeep` / LBD** | Reads the skeletor, not the override table (plan C8) — and per §2.4 the server path is separate anyway. Moot. |
| **Gore (UV wounds)** | Per-entity texture → rides the mesh → follows the ragdoll. Correct. |
| **Blood pools** | World decal at the server floor point → stays put. Correct (a pool under the body's authored landing spot). |
| **Blood drip FX** | Attached to tags → Hook B (`tr_model.cpp:2353`) serves ragdoll orientations → drips ride the body. Correct. |
| **Decap / helmet-pop chunks** | Spawn at the **server** pose in game.dll → offset from the visual head by the drift. Under settle that is a few units; under mode 3 it is tens. Another settle argument. |
| **DBNO revive prompts** | **Untouched.** The arm guard refuses `ns->number < cgs.maxclients` (:1400). |
| **Corpse despawn (`coop_corpseLife`)** | Default 0 = keep forever (`autoexec.cfg:357`). Fade is entity alpha → applies to the ragdolled mesh normally. On removal the entity leaves the snapshot with no transition, orphaning the sim (sleeping, evictable) — no visual artifact. |
| **Players standing on bodies** | Unchanged. Corpse collision is the server slab; the ragdoll is never in the collision path. |

**Coherence gap worth naming, not a defect:** *player corpses never ragdoll at all.* Live and
dead player slots are refused at :1400, and the separate `Body` entity spawned by
`Player::DeadBody` (`player.cpp:11384-11390`) is created **already** `EF_DEAD`
(`body.cpp:40`) — while the arm guard requires a rising edge (:1394) and "first-seen-dead never
arms". So "realistic deaths" currently excludes every player and every teammate. If the user's
mental model of the feature includes their own death, that needs saying before the flip.

---

## 4. Rollback and cvar safety

All five cvars are `CVAR_TEMP` (`cg_ragdoll.c:229-235`); `CVAR_TEMP` is `0x0100`,
"can be set even when cheats are disabled, but is not archived" (`q_shared.h:1308`). Each does
what its name says, verified at the read site:

| cvar | default | actual effect | site |
|---|---|---|---|
| `coop_ragdoll` | 0 | gates **arming only** | :1380 |
| `coop_ragdollMode` | 1 | `3` = legacy arm-at-edge; anything else = settle | :1422 |
| `coop_ragdollStiff` | 0.35 | shape-match target alpha, clamped 0-1 each substep | :712-721 |
| `coop_ragdollTest` | 0 | `1` = bone totem, `2` = freeze-pose drill | :1404, :1439 |
| `r_ragdollDebug` | 0 | `1` prints, `≥2` adds skeleton dots + pending trace | :1032, :1256 |

**Inertness at `coop_ragdoll 0` is genuine.** `CG_RagdollFrame` walks 8 inactive slots and
returns (:1021-1026); `CG_RagdollTransition` runs `RagCvars`, the clear set, and returns at
:1380. The only residual work is a `CG_RagdollClearEnt` (an 8-slot scan plus one cross-DLL
`R_ClearRagdoll`) on each `EF_DEAD`-falling / teleport / modelindex / eType transition —
negligible, and it is the belt that keeps the renderer table clean.

**Document this asymmetry:** setting `coop_ragdoll 0` mid-session does **not** stop or snap
back running sims — it only stops new arms. `CG_RagdollFrame` never reads the master gate.

**BLOCKER B2, two halves:**

1. **bug-1669 pre-registration.** Grepping the whole mod tree, none of the five names appears
   in any `.cfg` or `.scr` (hits only in `_research/*.md`), so the trap is **not live today**.
   But cvars are process-global and shared between game.dll and cgame.dll, and `RagCvars()`
   does not run until the first `CG_RagdollFrame` / `CG_RagdollTransition` — i.e. after the
   first snapshot, long after map-load scripts. The moment anything script-side reads
   `coop_ragdoll` (a coop settings-menu entry is the obvious next step), `getcvar` creates it
   **empty** and the cgame default is permanently defeated. Pre-register it in `G_InitGame`
   next to the existing block at `g_main.cpp:287-292`. The plan already required this
   (`ragdoll_plan.md` §5 C9); it is not done.
2. **`CVAR_TEMP` is wrong for a shipped player option.** Not archived ⇒ a player who turns
   ragdolls OFF gets them back ON next launch. When the default flips, `coop_ragdoll` must
   become `CVAR_ARCHIVE` and get a seed in `coop_defaults.cfg` (deployed loose by
   `build.ps1:166-171`). Keep `r_ragdollDebug`, `coop_ragdollTest` and `coop_ragdollMode` at
   `CVAR_TEMP` — archiving a dev switch is the bug-1427 trap the `g_main.cpp` block already
   calls out by name.

**Rollback is clean.** One cvar to 0 disables all new arms; existing sims expire within 6 s.
Nothing persists across a map change (§2.3).

---

## 5. Deployment

`build.ps1:184-206` ships **7 binaries to 2 roots** (`$gogRoot` and `G:\mohaa-gl2`, the live
install): `openmohaa.exe`, `cgame.dll`, `game.dll`, `game.pdb`, `renderer_opengl1.dll`,
`renderer_opengl2.dll`, `omohaaded.exe`.

**No engine/exe/protocol change is smuggled in.** Every settle-branch edit is inside
`code/cgame/cg_ragdoll.c`. No `entityState_t` field, no configstring, no `GENTITYNUM_BITS` /
`MAX_SOUNDS` / `MAX_SNAPSHOT_ENTITIES` constant, no game.dll edit. **`cgame.dll` alone is the
shippable unit for the settle work** — no exe lockstep, no protocol bump, no dedicated-server
rebuild.

The renderer half (`tr_ragdoll.cpp` + the `tr_model.cpp` hooks) is already deployed and
unchanged by this branch. A mismatched pair degrades safely: if a stale `renderer_opengl2.dll`
lacks `RE_SetRagdollPose`, `cgi.R_SetRagdollPose` is NULL and cg_ragdoll returns at :1014 and
:1383. **Both NULL-check belts verified.** No crash, just no ragdolls.

**The `cgame.pdb` gap is real.** `openmohaa-hzm\.cmake\code\client\cgame\Release\cgame.pdb`
exists (3,166,208 bytes, built 2026-08-20 00:12 alongside `cgame.dll`) but `build.ps1`'s
`$binaries` list carries **only `game.pdb`**. A crash inside `cg_ragdoll.c` will resolve to
`cgame.dll+0xNNNN` and nothing more — and per the project's crash-dump notes `cdb` is not
installed, so the PDB is the only line-level evidence available. One-line fix. (Same gap for
the renderers: `.cmake\code\renderercommon\renderergl2\Release\` contains **no `.pdb` at all**,
so a Hook A/B fault is unresolvable too — worth a separate look at the gl2 CMake config.)

---

## 6. Fix list, ranked

**Before default-ON:**

1. **B1** — stop `RagCollideWorld` (:806) spending `s_ragTraceCount`; give the mover pass its
   own counter. Without this, bodies 4+ fall through every lift and door.
2. **B2** — pre-register `coop_ragdoll` in `G_InitGame` (`g_main.cpp:287`) and promote it to
   `CVAR_ARCHIVE` + a `coop_defaults.cfg` seed.
3. **B3** — `RagPendingThink`: bail on `!cent->currentValid` /
   `cent->snapShotTime != cg.snap->serverTime`; make the 3000 ms cap a **drop**, not an arm.

**Same session, cheap, high value:**

4. Deploy `cgame.pdb` from `build.ps1`.
5. `CG_ServerRestarted` (`cg_main.c:751`) → clear both tables (plan §5).
6. Pass `ns->bone_tag` / `ns->bone_quat` into `RagCapture`'s `refEntity_t` (:429) — corrects a
   false comment and improves capture fidelity for free.
7. Throttle the slept-body `RagMoverHash` (:1052) to every 8th frame.

**Before a wide release:**

8. Implement the plan's C3 arm-rate bound on the **settle handoff** (max 4 captures/frame),
   to cap the ~2 ms grenade spike.
9. Add the origin-discontinuity clear signal (>64 u) the plan specified, for the
   dead-slot-reused-by-dead-entity case (§2.2).
10. Decide and document whether player / teammate corpses are meant to ragdoll (§3). Today they
    never do, by two independent guards.

**Perf note for the quality fixes already queued:** the off-by-one bone driving fix is pure
math and costs nothing. The knee fix (`RAG_PTS` 15 → 17) costs +13 % traces
(480 → 544/frame, 15,000 → 17,000/s) and needs `s_ragPtRadius` extended by two entries.
Neither is a perf blocker — do not trade quality for those numbers.
