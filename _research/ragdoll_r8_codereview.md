# Ragdoll round-8 SETTLE branch — line-by-line pre-flight code review

Reviewed: `openmohaa-hzm/code/cgame/cg_ragdoll.c` @ 1448 lines (full read), plus
`renderergl2/tr_ragdoll.cpp` (196 lines, identical to gl1). Cross-checked against the engine:
`fgame/animate.cpp`, `fgame/simpleactor.cpp`, `fgame/actor.cpp`, `fgame/actor_killed.cpp`,
`tiki/tiki_anim.cpp`, `tiki/tiki_files.cpp`, `skeletor/skeletor.cpp`, `qcommon/msg.cpp`,
`cgame/cg_snapshot.c`, `cgame/cg_view.c`, `cgame/cg_modelanim.c`, `cgame/cg_predict.c`,
`cgame/cg_public.h`, and the retail data (`Pak0.pk3:anim/killed.scr`).

Status: the branch compiles and is committed. **It has never run.** Everything below is what I
expect to happen on first contact.

Headline: the shape-match math is correct (verified, see §3.1) and the render/space contract is
untouched. What will fail is the *handoff decision* — `RagPendingThink` can and will capture the
wrong pose, and its two escape hatches (the 300 ms name gate and the 3000 ms cap) are wired
backwards. Four of the five S1/S2 items are one-to-three-line fixes.

---

## Severity index

| # | Sev | Site | One line |
|---|---|---|---|
| S1 | **CRITICAL** | `cg_ragdoll.c:1250-1254`, `1281` | `animDone` is accepted with no death-name and no age guard → captures the LIVING pose, reproducing the round-8 defect |
| S2 | **CRITICAL** | `cg_ragdoll.c:1277-1279` | "static" is a per-render-frame *distance* test, not a speed test → frame-rate dependent; at 125 fps anything under 62 u/s reads static |
| S3 | **HIGH** | `cg_ragdoll.c:1267-1274` | the name gate **drops** the record instead of waiting → whole death classes silently get no ragdoll |
| S4 | **HIGH** | `cg_ragdoll.c:1281` | the 3000 ms cap arms unconditionally — no name check, no anim-done check, no static check |
| S5 | **HIGH** | `cg_ragdoll.c:1244-1249` | dominant scan covers all 16 slots incl. the dialog channel, which plays `death_generic` and matches the `"death"` prefix |
| S6 | **MED-HIGH** | `cg_ragdoll.c:493-509` | the capture pre-lift now runs on a *landed* pose and distorts it per-point before it becomes `goal[]`, `restLen[]`, `braceLen[]` |
| S7 | **MED** | `cg_ragdoll.c:1284-1287` | a `!cent->interpolate` frame at the trigger instant permanently drops the record |
| S8 | **MED** | `cg_ragdoll.c:1333` / `cg_snapshot.c:120` | no clear hook on PVS exit / entity free; corpse-over-corpse entnum reuse with the same model produces no clear signal |
| S9 | **MED** | `cg_ragdoll.c:1256-1259` | the pending trace prints every render frame per body — ~375 lines per corpse at 125 fps, with `logfile 2` flushing each one |
| S10 | **MED** | `cg_ragdoll.c:806, 850` | world traces charge the shared 240-trace budget the banner says they are exempt from → movers starve at >4 awake bodies |
| S11 | **MED** | `cg_ragdoll.c:429-438` | `RagCapture` never sets `model.actionWeight` → captured pose ≠ on-screen pose |
| S12 | **MED** | `cg_ragdoll.c:899-900` vs `cg_view.c:2928` | `CG_RagdollFrame` runs before `CG_CalcEntityLerpPositions`, so `RagPush` uses a one-frame-stale placement |
| S13 | **LOW-MED** | `cg_ragdoll.c:1160-1192` | pending records are (correctly) non-evictable but now hold a slot for up to 3 s — pool starves faster in a firefight |
| S14 | **LOW** | `cg_ragdoll.c:1-42`, `86-121`, `1422` | stale banner, brace comments, undefined mode values |
| S15 | **LOW** | `cg_ragdoll.c:800-802` | sub-0.01u substep moves skip collision → slow creep into the floor |

---

## S1 — CRITICAL: the anim-end test accepts *any* animation, including the living one

`cg_ragdoll.c:1250-1254`

```c
if (dom >= 0) {
    animT = cgi.Anim_Time(tiki, cs->frameInfo[dom].index);
    if (animT > 0 && cs->frameInfo[dom].time >= animT - 0.06f) {
        animDone = qtrue;
    }
    nm = cgi.Anim_NameForNum(tiki, cs->frameInfo[dom].index);
    ...
    if (age > 300 && (!nm || Q_stricmpn(nm, "death", 5))) { ...drop... }
}
...
if (!((animDone && s->pendStatic >= 2) || age > 3000)) { return; }        // :1281
```

`animDone` is computed **before** the name is even fetched, and the trigger at `:1281` never
consults `nm`. The death-name check only ever *drops* the record, and only after 300 ms.

Semantics verified:
- `Anim_Time` returns **seconds** (`tiki/tiki_anim.cpp:271`, `frameTime * numFrames` for
  deltadriven, `* (numFrames-1)` otherwise). ✅ the units in the test are right.
- `frameInfo[].time` is seconds, advanced by `level.frametime` and **clamped to `animtimes[i]`**
  for non-repeat anims (`fgame/animate.cpp:676`, `:738-742`). ✅ so `time >= animT - 0.06` is a
  valid end test for a once-type anim.
- Wire quantisation is `time*100` into 15 bits, unpacked `packed/100.f`
  (`qcommon/msg.cpp:2308-2328`, `MSG_UnpackAnimTime`). Truncation loses ≤ 0.01 s, well inside the
  0.06 tolerance. ✅

**What breaks.** At the EF_DEAD rising edge the engine has not yet started the death anim (this is
the round-8 finding, confirmed: `Actor::HandleKilled` sets `EF_DEAD` at `fgame/actor.cpp:5459`,
then queues `global/killed.scr` as a *script*, which only sets the motion anim on a later Think).
For the first 50-300 ms the dominant slot therefore still holds the **living** animation, and:

- `MSG_UnpackAnimWeight` **clamps to 1.0** (`msg.cpp`, `if (tmp > 1.0f) return 1.f`), and
  `StartCrossBlendAnimSlot` seeds the outgoing slot at its previous weight
  (`simpleactor.cpp:753-754`). So for the first server frame or two the outgoing living anim reads
  exactly `1.0` on the client — the same value as anything else — and wins the strict-`>` scan by
  having the lower slot index.
- If that living animation happens to be sitting within 0.06 s of its end (a once-type holding its
  last frame is *permanently* within tolerance; a looping idle is within tolerance for
  `0.06/animLength` of its cycle, i.e. ~3-6 % of a 1-2 s idle), `animDone` is **true immediately**.
- `pendStatic >= 2` needs two render frames — 16 ms at 125 fps — and a soldier who has just been
  shot has not moved yet.

Net: a measurable fraction of kills (order 5-15 %, plus 100 % of actors holding a finished
one-shot anim at death) will capture ~30 ms after the edge — i.e. **photograph the standing
soldier and drop him cold**, which is the exact behaviour the settle branch exists to eliminate.
The user will report it as "still happening".

**Fix (3 lines).** Gate the accept on the name and the age, not just the drop:

```c
qboolean isDeath = (nm && !Q_stricmpn(nm, "death", 5));
...
if (animT > 0 && cs->frameInfo[dom].time >= animT - 0.06f) animDone = qtrue;
...
if (!(age > 300 && isDeath && animDone && s->pendStatic >= 2)) { ... }
```
and see S3/S4 for what the fallbacks should become.

---

## S2 — CRITICAL: `pendStatic` is a distance-per-frame test, so it is frame-rate dependent

`cg_ragdoll.c:1277-1279`

```c
VectorSubtract(cent->lerpOrigin, s->pendOrigin, d);
VectorCopy(cent->lerpOrigin, s->pendOrigin);
s->pendStatic = (VectorLength(d) < 0.5f) ? s->pendStatic + 1 : 0;
```

`RagPendingThink` runs once per **render** frame (`CG_RagdollFrame`, `cg_ragdoll.c:1028-1031`),
not per snapshot. `cent->lerpOrigin` is interpolated smoothly between snapshots
(`cg_ents.c:532-534`), so `d` is the true per-render-frame motion. The threshold is absolute:

| render fps | frame ms | speed that still reads "static" |
|---|---|---|
| 60 | 16.7 | < 30 u/s |
| 125 | 8.0 | **< 62 u/s** |
| 250 | 4.0 | **< 125 u/s** |
| 333 | 3.0 | < 167 u/s |

The user plays a high-FPS listen build. At 250 fps the static test is effectively disabled.

**What breaks.** Two concrete paths, both common:

1. `Actor::BecomeCorpse` hands a corpse with no ground to `MOVETYPE_TOSS`
   (`fgame/actor.cpp` ~12500). A corpse still falling at 60 u/s reads static at 125 fps → capture
   happens **mid-air**, `goal[]` becomes a mid-fall pose, gravity ramps 0→1 over 250 ms
   (`cg_ragdoll.c:1072`) and the body drops from rest out of a pose the animator never intended to
   be a resting pose.
2. **Explosive kills.** `Actor::HandleKilled` applies a death impulse of up to
   `420 * 1.55 ≈ 650 u/s` (`fgame/actor.cpp:5470-5487`). The body flies, the anim finishes in
   flight, and as the arc decelerates through ~60 u/s the static test latches. The ragdoll then
   starts at rest at the capture point with `gravScale = 0`, while the server body keeps flying —
   so the corpse visibly **stops dead in mid-air and drops straight down**. That is textbook
   "bodies don't fall like that".

**Fix.** Make it a speed test with an explicit time base, and require a minimum wall-clock dwell:

```c
float spd = VectorLength(d) / (cg.frametime * 0.001f);        // u/s, frame-rate independent
s->pendStaticMs = (spd < 8.0f) ? s->pendStaticMs + cg.frametime : 0;
...  && s->pendStaticMs >= 100
```
`cg.frametime` is already guaranteed > 0 at this point (`cg_ragdoll.c:1017`).

---

## S3 — HIGH: the name gate drops the ragdoll instead of waiting for it

`cg_ragdoll.c:1267-1274` — at `age > 300`, if the dominant anim's name does not start with
`"death"`, the record is `memset` away and the corpse never ragdolls.

I pulled the retail death script to see what names actually occur.
`Pak0.pk3:anim/killed.scr` is the `deathhandler` (`Actor::Anim_Killed` →
`DesiredAnimation(ANIM_MODE_NORMAL, m_DeathHandler)`, `fgame/actor_animapi.cpp:104`;
`m_DeathHandler` defaults to `"deathhandler"`, `fgame/actor.cpp:1508/1517`). The complete set of
`setmotionanim` targets it can pick:

- **matches `death*`** (21 names): `death_grenade_high`, `death_backgrenade`, `death_grenade`,
  `death_back`, `death_right`, `death_left`, `death_run`, `death_crotch`, `death_chest`,
  `death_frontchoke`, `death_frontcrouch`, `death_prone`, `death_knockedup`,
  `death_head_flyforward`, `death_headpistol`, `death_twist`, `death_shoot`,
  `death_fall_to_knees`, `death_collapse`, `death_choke`, `death_fall_back`.
- **does NOT match** — silently loses the ragdoll:
  - `rifle_pain_kneestodeath`, `thompson_pain_kneestodeath` — **every actor killed while
    kneeling, crouching or crouch-walking** (the `knees:/crouch:/crouchwalk:` case). This is not a
    corner case; crouched AI are everywhere in this game.
  - `chair_death_backwards`, `chair_death_forwards` — the seated set piece. (Correctly excluded,
    but by accident rather than by the explicit gate.)
  - any `self.deathanim` special set via `global/setdeathanim.scr` whose name does not begin
    `death` — arbitrary, map-authored.

Alias resolution checked: `TIKI_Anim_NameForNum` returns `panimdef->alias`
(`tiki/tiki_anim.cpp:66-80`), and for `TAF_RANDOM` groups the loader strips trailing digits
(`tiki/tiki_files.cpp:1046-1057`), so `death_chest_1/2/3` collapse to alias `death_chest_` —
still a prefix match. ✅ the `"death"` prefix itself is sound for the names it covers.

**Fix.** Two separate concepts are conflated. Use an explicit *reject* list for set pieces
(`death_balcony`, `chair_death`, plus the balcony intro/loop/outtro already at `:1263`) and treat
"not obviously a death anim" as **keep waiting**, not as drop. Add `_kneestodeath` /
`pain_kneestodeath` to the accept set — those are genuine deaths that end on the ground.

---

## S4 — HIGH: the 3000 ms cap arms unconditionally

`cg_ragdoll.c:1281`: `|| age > 3000` bypasses `animDone`, `pendStatic` **and** the name check in
one term. Anything that reaches 3 s arms with whatever pose is on screen.

This is reachable in the normal case: if every `frameInfo[].weight` is zero, `dom` stays `-1`
(`:1231`, `:1244-1249`), the whole `if (dom >= 0)` block is skipped, and the record falls through
to the cap. `Animate::StopAnimating` sets `weight = 0` and `index = 0/1`
(`fgame/animate.cpp:504-523`), and `UpdateLastFrameSlot` calls it
(`fgame/simpleactor.cpp:889-892`). It is also the path taken by a body that has left the PVS (see
S8), whose `currentState` is frozen.

**Fix.** The cap should be a *give-up*, not a *fire*: at 3 s, if the pose has never validated,
drop the record and leave the corpse on its server anim. That is a strictly better outcome than
simulating an unknown pose, and it matches the file's own stated failure ladder ("NaN'd corpses
keep the anim pose", `:34-37`).

---

## S5 — HIGH: the dominant-channel scan includes the dialog channel, which plays `death_generic`

`cg_ragdoll.c:1244-1249` scans all `MAX_FRAMEINFOS` (16) slots. The engine's slot map:

| slots | channel | source |
|---|---|---|
| 0-2 or 3-5 | motion (`GetMotionSlot(n) = n + (m_AnimMotionHigh ? 3 : 0)`) | `simpleactor.cpp:545-551` |
| 6-8 or 9-11 | action / aim (`GetActionSlot(n) = n + (m_AnimActionHigh ? 9 : 6)`) | `simpleactor.cpp:595-601` |
| 12 or 13 | say / dialog (`GetSaySlot()`) | `simpleactor.cpp:639-642` |

`anim/killed.scr` line ~50 runs `self setsay death_generic` — a **facial** anim whose alias
starts with `"death"`, so it passes the prefix gate at `:1267` and `:1263`. Its weight ramps to
1.0 in **0.1 s** (`UpdateSayAnimSlot`, `simpleactor.cpp:881-887`) while the body's motion anim
crossblends over 0.3-0.5 s. During that window the say slot genuinely out-weighs the motion slot.

So `Anim_Time` can be measured on a ~0.5-1.5 s **facial** clip while the 2-3 s body death anim is
still mid-fall, and `animDone` fires early. Combined with S2 this is a second independent path to
a mid-fall capture.

The code has no notion that "the dominant animation" should mean "the dominant *body* animation".

**Fix (1 line).** `for (i = 0; i < 6; i++)` — motion channels only. Ties then resolve to the lower
slot index, which is also the correct behaviour when the old and new motion groups both read a
clamped `1.0` (see S1).

---

## S6 — MED-HIGH: the capture pre-lift distorts the authored landed pose before it becomes `goal[]`

`cg_ragdoll.c:493-509`. The pre-lift was added by bug-1962 for a capture taken at the **standing**
death edge, where only a calf or foot is ever slightly buried. The settle branch now captures a
**landed** pose, where a prone body has hands, forearms, head, hips and both calves resting at or
just inside the floor plane. Each buried point is independently traced up and re-seated at
`surface + 0.25` — with no coupling between neighbours.

Consequences, in order:
1. `goal[]` is copied from `s->pt[]` **after** the pre-lift (`:1302-1304`), so the shape-match
   target is the *distorted* pose, not the animator's.
2. `restLen[]` (`:525-546`) and `braceLen[]` (`:547-554`) are measured after it too, so the
   distortion is baked into the constraint web.
3. `hipDir0` and `rot0[]` likewise.

The distortion is small per point (≤ a few units) but it is systematic and it scales with how much
of the body is in ground contact — i.e. it is largest precisely for the well-landed poses this
branch is designed to preserve.

Second-order: if a point is buried **and** the 24u up-trace also starts solid (inside a thick
brush, under a ramp), nothing happens and the point stays buried; `RagCollideWorld`'s
`tr.startsolid` branch (`:808-812`) then freezes it for the sim's whole life, pinning the body —
the original bug-1962 pile mechanism, re-armed.

**Fix.** For the settle branch, do the de-penetration as a **rigid** whole-body lift: find the
largest single penetration depth across all 15 points along the dominant contact normal and
translate the entire cloud by it, rather than moving points independently. Measure `restLen`,
`braceLen`, `rot0` and `goal` from the *undistorted* capture.

---

## S7 — MED: an `interpolate == 0` frame at the trigger instant kills the record permanently

`cg_ragdoll.c:1284-1287`:

```c
if (!cent->interpolate || cs->eType != ET_MODELANIM) {
    memset(s, 0, sizeof(*s));   // re-validated at capture time, not at the edge
    return;
}
```

`cent->interpolate` is cleared at the end of every `CG_TransitionEntity`
(`cg_snapshot.c:151`) and only restored when `CG_SetNextSnap` runs
(`cg_snapshot.c`, `cent->interpolate = qtrue` in the per-entity loop). If the client is snapshot-
starved for one frame — packet loss, a hitch, a server stall — the condition is false and the
ragdoll is discarded outright rather than retried on the next frame.

**Fix.** `return;` without the memset — retry next frame. The record already has the 3 s cap as a
backstop.

---

## S8 — MED: lifecycle holes (leak on PVS exit, no clear on corpse-over-corpse reuse)

Walked every path that touches a slot.

**Clear paths that exist.** `CG_RagdollClearEnt` (`:250-259`) is called from exactly three places,
all inside this file: the clear-signal branch (`:1343-1347`), the NaN ladder (`:1099`), and
eviction (`:1178`). `CG_RagdollTransition` is called from **one** site, `CG_TransitionEntity`
(`cg_snapshot.c:140`), which `CG_TransitionSnapshot` runs **only for entities present in the new
snapshot**.

**Hole 1 — PVS exit / entity free.** An entity that leaves the snapshot never gets a transition,
so nothing clears its slot. `cent->currentState` freezes with `EF_DEAD` still set, so the
revive/recycle guard at `:1234` does **not** fire; `lerpOrigin` freezes so `pendStatic` climbs;
`frameInfo` freezes so `animDone` may be permanently true. The record arms on a body that is not
there, or arms via the 3 s cap (S4). Self-heals in ~9 s (3 s pending + 6 s life cap + eviction),
but burns a pool slot the whole time and pushes a ragdoll override for that entnum.

**Hole 2 — corpse-over-corpse entnum reuse.** The clear signal (`:1343-1344`) is
`EF_DEAD` falling edge ∨ `EF_TELEPORT_BIT` toggle ∨ modelindex change ∨ eType change. A **new
corpse** re-using a freed entnum with the **same model** trips none of them: both states carry
`EF_DEAD`, same modelindex, same eType. `Actor::BecomeCorpse` calls `AddToBodyQue()`
(`fgame/actor.cpp:12468`), which recycles corpse entities — so this is a routine event, not a
corner case. The stale sim keeps running against the new body. The renderer's tiki-match belt
(`tr_ragdoll.cpp:46-48`) does not help: same model, same tiki pointer.

`cent->currentValid` is the discriminator the engine itself uses
(`cg_snapshot.c`, `!cent->currentValid → interpolate = qfalse, teleported = qtrue`), and
`entityState_t::usageIndex` is the definitive one.

**Fix.** In `CG_RagdollTransition`, add `|| !cent->currentValid || cent->teleported ||
(cs->usageIndex != ns->usageIndex)` to the clear-signal set. Separately, walk `s_ragSims[]` once
per frame in `CG_RagdollFrame` and clear any slot whose entnum is not in `cg.snap->entities` (or
whose `cent->snapShotTime != cg.snap->serverTime`).

**Double-arm: none found.** `RagAllocSlot` refuses when `RagSimFor(entnum)` is non-NULL
(`:1165`), and a pending record sets `active = qtrue` (`:1426`), so a second pending-arm on the
same entnum is impossible. Eviction correctly refuses anything that is not `state == 2`
(`:1176-1181`), so pending records are never evicted out from under themselves. ✅

---

## S9 — MED: the pending debug trace floods the log at render-frame rate

`cg_ragdoll.c:1256-1259` prints once **per render frame per pending body** under
`r_ragdollDebug >= 2`. At 125 fps × 3 s that is ~375 lines for one corpse; with `logfile 2`
(per-line flush, per `CLAUDE.md`) and 8 slots that is ~1000 flushed lines/sec. It will visibly
cost frames and it will bury the `settle-armed` / `sleep` lines that are the actual evidence.

Worse, `r_ragdollDebug >= 2` is the same gate that turns on `RagDrawSkeleton` (`:1032-1034`), so
there is no way to get the skeleton dots without the flood.

**Fix.** Print on change only (last `dom`/`nm` differs) or throttle to one line per 250 ms, and/or
move it to `r_ragdollDebug >= 3`.

---

## S10 — MED: world traces charge the budget the banner declares them exempt from

`cg_ragdoll.c:792` says "World traces are budget-EXEMPT", but `RagCollideWorld` increments the
shared counter at `:806`, and `RagCollideMovers` bails on it at `:850`
(`if (s_ragTraceCount >= RAG_TRACE_BUDGET) return;`).

Worst case per frame: 8 sims × 4 substeps × 15 points = **480 world traces**, double the 240
ceiling. Any frame with more than ~4 awake bodies therefore gives movers **zero** traces — the
elevator/door case the mover pass exists for. The mover-wake hash (`RagMoverHash`, `:763-785`)
still fires, so bodies wake on a moving bmodel and then get no mover collision, which is worse
than not waking.

**Fix.** Either make world traces genuinely exempt (use a separate counter) or raise
`RAG_TRACE_BUDGET` above `RAG_MAX_SIMS * RAG_MAX_STEPS * RAG_PTS + RAG_MAX_SIMS * 4 * RAG_PTS`.

---

## S11 — MED: `RagCapture` never sets `actionWeight`

`cg_ragdoll.c:429-438` builds the `refEntity_t` with `memset` + `frameInfo` only. It never assigns
`model.actionWeight`, which stays 0.

`skeletor_c::SetPose` stores it as `m_frameList.actionWeight` (`skeletor/skeletor.cpp:495`) and it
scales the action-channel contribution. The on-screen model gets the entity's own interpolated
value (`cg_modelanim.c`, `model->actionWeight = (sNext->actionWeight - state->actionWeight)*t +
state->actionWeight`). So whenever a dead actor still carries any action-slot weight, the captured
pose differs from what the player is looking at — and the handoff will visibly pop.

**Fix (1 line).** `model.actionWeight = ns->actionWeight;` — the field exists on `entityState_t`.

Checked and **not** a problem: `bone_tag` / `bone_quat` are *pointers* in `refEntity_t`
(`renderercommon/tr_types.h:146-147`), so `memset` leaves them NULL and
`SetPose`'s `if (contIndices && contValues)` short-circuits — no bogus controller is installed on
bone 0. And `Actor::Begin_Killed` calls `ResetBoneControllers()` (`fgame/actor_killed.cpp:43`),
whose identity quaternion fails `SetPose`'s `(w-1)^2 >= EPSILON` test anyway
(`skeletor.cpp:387-390`). ✅

---

## S12 — MED: `RagPush` reads a one-frame-stale entity placement

`cg_view.c:2928` calls `CG_RagdollFrame()` immediately after `CG_ProcessSnapshots()` and **before**
`CG_AddPacketEntities` → `CG_CalcEntityLerpPositions` (`cg_ents.c:566`) updates `cent->lerpOrigin`.
`CG_ModelAnim` then composes the refEntity from the **fresh** `cent->lerpOrigin`
(`cg_modelanim.c:1443-1444`, `:1484`).

So `RagPush`'s `curOrigin`/`axisNow` (`cg_ragdoll.c:899-900`) are one render frame behind the
placement the renderer will actually use this frame. Residual mesh-vs-skeleton offset =
`velocity × frametime`: zero for a resting corpse, ~0.5 u for a corpse drifting at 60 u/s, larger
on a moving elevator. This is the same *class* of defect as bug-1964, just one frame's worth.

`RagPendingThink` reads the same stale value, but consistently frame-to-frame, so S2's delta is
still the true per-frame motion — the staleness does not compound there.

**Fix.** Either move `CG_RagdollFrame()` to after `CG_AddPacketEntities`, or call
`CG_CalcEntityLerpPositions(cent)` for the sim's own entity at the top of `RagPush`. The first is
cleaner but changes when `R_SetRagdollPose` lands relative to Hook A — needs a check that Hook A
reads the table during `R_AddSkelSurfaces` (it does) and not before.

---

## S13 — LOW-MED: pool pressure

`RAG_MAX_SIMS 8`. Before the settle branch a death took a slot and released it after
sleep + eviction. Now each death holds a **non-evictable** pending slot for up to 3 s
(`RagAllocSlot:1176-1181` only evicts `state == 2`) before its ~1-6 s sim life even begins.

In a grenade/MG burst that kills 8+ actors inside 3 s, later deaths hit
`"arm refused (pool awake-full)"` (`:1186`) and keep their server anim pose. That is a graceful
degradation, but it means the feature visibly toggles off exactly when the most corpses are on
screen. Consider `RAG_MAX_SIMS 12-16` (the renderer pool is also 8, `tr_ragdoll.cpp:19` — both
must move together) or evicting the *oldest pending* record when the pool is full of pending.

---

## S14 — LOW: dead / contradictory / stale text

- **Banner, `:1-42`.** Still describes the P2/P3 architecture and states the seed contract as the
  live design ("Seed (vet2/F8): arm on the EF_DEAD rising edge…"). Under the default
  `coop_ragdollMode 1` that entire paragraph is now the *legacy* path. `:39-41` documents only
  `coop_ragdollTest 1`; `coop_ragdollTest 2` (the freeze drill, `:1439-1447`) and
  `coop_ragdollMode` / `coop_ragdollStiff` are undocumented there.
- **`:1422`**, `if (rag_mode->integer != 3 && !rag_test->integer)`. Every value except 3 means
  settle. `coop_ragdollMode 0` and `2` silently behave as 1, though `RagCvars` (`:232-234`)
  documents only 1 and 3. Make it `== 1` explicitly, or document "anything but 3".
- **`:86-89`**, "beyond the 14 parent links" with `RAG_BRACES 16`; bug-1962's entry says "14
  total". The table and the min-factor array are correctly aligned at 16 entries each
  (verified index-by-index), only the prose drifted.
- **`:103-104`**, `{0,12}` / `{0,14}` are commented "knee fold limit", but pt 12/14 are
  `Bip01 L/R Calf`, i.e. the knee joint itself — these are pelvis→knee (thigh-span) braces, not
  knee limits. This is the same confusion as the "knee is not simulated" finding below.
- **`:1300`**, `s->armTime = armTime` carries the pending-arm time into the running record, where
  `armTime` is only read by the state-0 seed timeout (`:1041`) that a settle record can never
  reach. Harmless, but it means the `life=` figure and `armTime` disagree about what t=0 is.
- **State-0 seed machinery** (`seedOrigin`, `seedServerTime`, `:1039-1049`, `:1352-1378`) is
  unreachable in the default mode. Not dead — mode 3 needs it — but worth a comment saying so.

---

## S15 — LOW: sub-threshold moves skip collision

`cg_ragdoll.c:800-802` skips the trace when the substep displacement is `< 0.01 u`. With the
shape-match holding points nearly still, most points skip most substeps. A point being pulled
0.005 u/substep into the floor never gets a trace and creeps ~1.6 u over a 1.3 s life. Bounded by
sleep, cosmetically invisible, but it will show up as a small `drift` bias in the sleep print.

---

## §3 — Things I checked that are CORRECT (do not "fix" these)

### 3.1 The shape-match rotation convention is right
`RagBodyRotation` (`:622-636`) builds `S = T0ᵀ · T1` via `RagMat3TransMul`. For a row vector `v` in
world space: its coordinates in the capture triad are `c_k = v · T0[k]`, i.e. `c = v·T0ᵀ`; mapping
back through the current triad gives `v' = c·T1 = v·T0ᵀ·T1 = v·S`. `RagMat3RotateVec`
(`:326-332`) computes exactly `out[j] = Σᵢ v[i]·m[i][j]` = `v·M`. ✅ consistent.

Both `T0` and `T1` come from `RagTriad` (`:303-324`), which Gram-Schmidts and crosses, so both are
orthonormal → `S` is a pure rotation, **no scaling**. The shape-match therefore cannot stretch
limbs. ✅

Self-consistency at the handoff: `goal[] == pt[]` at settle-arm (`:1302-1304`), so `S = I`,
`want == pt[i]`, and the first push is the capture verbatim. ✅ No lurch.

### 3.2 The ordering is what the comment claims
`RagStep` runs integrate (`:666-679`) → constraints (`:680-710`) → `RagShapeMatch` (`:711-723`);
`CG_RagdollFrame` then calls `RagCollideWorld` (`:1084`) after `RagStep`. So it really is
integrate → constraints → shape-match → collide, i.e. **the ground gets the last word**, exactly
as `:638-641` says. ✅

### 3.3 The shape-match does not fight Verlet
`ptPrev` is captured *before* integration (`:675`) and the shape-match runs *after*, so a
correction back to a stationary goal produces implicit velocity ≈ 0 rather than the classic
position-projection ringing. ✅

### 3.4 The freeze drill still works
`:1422` — with `coop_ragdollTest 2`, `!rag_test->integer` is false, so control falls through to
`RagArm` at `:1438` and `freezePose` is set at `:1442`. `CG_RagdollFrame` short-circuits on
`freezePose` at `:1035-1038`, **before** the `state == 0` seed check. ✅ Note the drill now
photographs the *living* pose (it takes the legacy arm-at-edge path), which is still a valid
render regression test but is no longer representative of what mode 1 renders.

### 3.5 Mode 3 is unaffected
`s->branch` is set only at `:1299`. `RagStep` gates gravity scaling (`:664`) and the shape-match
(`:711`) on it; the drift metric gates on it (`:1133`). `RagArm` leaves it 0. ✅

### 3.6 API surface is real
Every import used exists with the signature the code assumes: `Anim_Time`/`Anim_NameForNum`
(`cg_public.h:383,387`), `Tag_NumForName`/`Tag_NameForNum`/`ForceUpdatePose`/`TIKI_Orientation`
(`:406-409`), `CM_InlineModel`/`CM_PointContents`/`CM_BoxTrace`/`CM_TransformedBoxTrace`
(`:171-198`), `R_Model_GetHandle` (`:375`), `R_SetRagdollPose`/`R_ClearRagdoll` (`:453-454`),
`CG_GetBrushEntitiesInBounds` (`cg_local.h:698`, impl `cg_predict.c:87`). `Q_isnan`
(`q_shared.h:1098`), `crandom()` (`q_shared.h:828`), `MASK_DEADSOLID`
(`fgame/bg_public.h:643` = SOLID|PLAYERCLIP|CORPSE|NOTTEAM2|FENCE). ✅ **No engine/exe change is
required for any fix in this document** — all of S1-S15 are cgame-side, except the optional
`RAG_MAX_SIMS`/`RAGDOLL_MAX_SLOTS` bump in S13, which needs cgame **and** both renderers
(i.e. `cgame.dll` + `renderer_opengl1.dll`/gl2 shipped together, no `game.dll`, no exe).

Also verified: `CG_GetBrushEntitiesInBounds` filters to `solid == SOLID_BMODEL`
(`cg_predict.c:98-100`), so the corpse's own `CONTENTS_WEAPONCLIP` bbox from
`Actor::BecomeCorpse` never enters the mover pass, and `MASK_DEADSOLID` excludes WEAPONCLIP
anyway. Corpses cannot collide with themselves or each other. ✅

---

## §4 — Corroboration of the joint-limits agent's two findings

I did not re-derive these, but the settle branch changes their weight:

**Off-by-one bone driving** (`RagPush:916-939`, bone `i`'s swing built from `pt[parent] → pt[i]`).
Under the settle branch this is *masked at the handoff* — `S = I` everywhere on frame 1 — and only
appears as the sim moves. Because the shape-match keeps the body close to `goal[]`, total motion
is small, so the shear is smaller than in mode 3 but permanently present in the final resting
pose. It is now the **dominant remaining source of visible mesh warp**, since the branch has
removed most of the gross point motion that used to hide it.

**Knee not simulated** (sim points end at `Bip01 L/R Calf`, which *is* the knee). Corroborated
independently by the brace comments at `:103-104` calling pelvis→calf a "knee fold limit" when it
is a thigh-span brace, and by `s_ragAnchorTable:202-205` slaving `Bip01 L/R Foot` and `Toe` to the
calf point — meaning the entire shin+foot rides rigidly on the knee. Adding points 15/16 at
`Bip01 L/R Foot` requires bumping `RAG_PTS`, extending `s_ragPtRadius`, `s_ragBones`, and
re-checking `RAG_BRACES` — all cgame-local.

**One structural observation about the branch itself.** `RagShapeMatch` (`:651`) loops
`i = 1 … RAG_PTS-1` and never moves `pt[0]`. The pelvis is the only free particle; everything else
is rigidly refitted to it each substep. After the 300 ms ramp at `coop_ragdollStiff 0.35` the body
is effectively a rigid mannequin whose only physics is the pelvis's single 7-unit collision box,
with limbs pushed out of geometry by the post-shape-match collide pass. That is probably the right
first cut for "keep the animator's silhouette", but it means:
- the brace truss built by bug-1962/1963 (16 braces, inequality fold limits) is now **largely
  inert** — the shape-match overrides it every substep;
- a body landing across a crate or a step cannot *drape*; it will sit rigid with individual limbs
  clipped to surfaces;
- sleep will occur fast (expect `life=` ≈ 1100-1500 ms: 300 ms ramp + `sleepMs > 1000`), which the
  acceptance criteria treat as a pass.

If the user's verdict after the first playtest is "too stiff / still doesn't drape", the knob is
`coop_ragdollStiff` **and** making the shape-match per-limb-chain (weight it down toward the
extremities) rather than one global alpha.

---

## §5 — What would fail on the FIRST kill, ranked

1. **S1** — a premature capture of the living pose. Fires on any kill where the outgoing anim is
   within 0.06 s of its end at the death instant, and on 100 % of kills where the actor was
   holding a finished one-shot anim. Directly reproduces the round-8 verdict.
2. **S2** — a mid-air / mid-flight capture, guaranteed on the user's high-FPS build for any
   explosive kill and for any corpse handed to `MOVETYPE_TOSS`.
3. **S5** — `death_generic` (the facial say anim) deciding the body's handoff time.
4. **S3** — every crouched/kneeling kill (`rifle_pain_kneestodeath`) silently gets no ragdoll,
   which will read as "it only works sometimes".
5. **S4** — the 3 s cap arming on an unvalidated pose, including for bodies that left the PVS.
6. **S9** — `r_ragdollDebug 2` flooding `qconsole.log`, which is the channel the evidence has to
   come through.

Everything above S6 is a handoff-decision bug in one function. I would fix S1+S2+S3+S4+S5 as a
single edit to `RagPendingThink` and S9 alongside it, then playtest — the rest are real but will
not change the verdict on the first build.
