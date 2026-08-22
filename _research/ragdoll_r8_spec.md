# RAGDOLL ROUND 8 — FINAL IMPLEMENTATION SPEC

Written 2026-08-20 from five adversarially-verified research lenses (`ragdoll_r8_reference.md`,
`_mohaadata.md`, `_codereview.md`, `_gap.md`, `_risk.md`) plus an independent re-verification of every
load-bearing citation in this document. Supersedes the surviving-recommendation lists in all five.

**Everything cited below was opened and read during the writing of this spec.** Where a lens's line
number was wrong, the corrected number is used and the correction is noted.

---

## 0. EXECUTIVE SUMMARY

Eight rounds of this ragdoll have failed on the same question — *when* do we take the pose? — and every
round answered it with a client-side heuristic (arm at the `EF_DEAD` edge; then wait for a
`"death"`-prefixed anim to reach its end and the origin to hold still). All five lenses independently
found that heuristic still broken in the untested SETTLE branch: it can fire on the *living* anim
inside the first 300 ms (three lenses, three separate mechanisms, converging on ~10-30 % of standing
kills), it drops every crouch/knees death because those anims are named `*_pain_kneestodeath`, its
3000 ms escape hatch arms a mid-fall pose, and its pending records eat the 8-slot sim pool. **This
spec deletes the heuristic outright and replaces it with an exact, engine-authored, already-networked
signal that none of the eight rounds used**: `Actor::BecomeCorpse` (`fgame/actor.cpp:12468`) is
reachable only from `Actor::FinishedAnimation_Killed` (`fgame/actor_killed.cpp:69-70`), it swaps the
actor's bounding box from the living `MINS/MAXS {-15,-15,0}..{15,15,94}` (`fgame/bg_pmove.cpp:52-53`,
applied at `fgame/actor.cpp:3265`) to the corpse slab `{-32,-32,0}..{32,32,16}`
(`fgame/actor.cpp:12492-12494`), and `setSolidType` ends in `link()` (`fgame/entity.cpp:2230`) so
`SV_LinkEntity` re-packs `entityState_t.solid` (`server/sv_world.c:243`) — a 32-bit netfield present in
all three delta tables (`qcommon/msg.cpp:1376`, `:1530`, `:1684`) and already decodable in cgame with
`IntegerToBoundingBox` (`qcommon/q_shared.h:869`, in use at `cgame/cg_ents.c:203`,
`cgame/cg_predict.c:164`). Seeing that box arrive is **proof** that the authored death animation ran to
completion *and* that `CheckGround()`/`droptofloor(64)` already parked the body — exactly the two facts
`RagPendingThink` was guessing at. It needs no anim-name list, no `animDone` test, no per-map
deny-list, and it cannot fire early. Around that one change the build adds the four cheap fixes every
lens agreed on (gravity from the world instead of 1.56 g, split trace budgets so movers are not starved
from the third body onward, pending records out of the sim pool, a refuse-to-arm guard on
still-buried captures) and one live A/B for the one genuinely uncertain thing: the off-by-one bone
driver, shipped behind `coop_ragdollDrive` so the playtester can flip it in-game rather than us
betting a whole round on it. **Deliberately excluded**: the feet/knee sim points, the
`CG_RagdollFrame` reorder, corpse-vs-corpse pushout, post-death impulse, blood-pool relocation and all
`killed.scr` variety edits — each would add a second independent variable to a build that must answer
one question. The playtester's verdict is decided by four numbers in one log line
(`after=`, `drift=`, `span=`, and the `drive=0`/`drive=1` A/B), not by prose.

---

## 1. THE ONE QUESTION THIS BUILD ANSWERS

> **When the corpse is handed to physics at the exact instant the server parks it — in its landed,
> authored pose, with the bone driver corrected — does the drape read as a body settling onto the
> ground, or does it still read as a mannequin being placed / a puddle?**

Everything in the build either produces that handoff, or measures it. Anything that would change what
the corpse *looks like* for a second, independent reason is out.

---

## 2. RECONCILED CONFLICTS

Where two lenses disagreed, the decision and the one-sentence reason.

| # | Conflict | Decision | Why |
|---|---|---|---|
| C1 | **How to detect the handoff.** reference #3 / mohaadata R1-R3 / gap #1 / risk #1 all propose *repairing* the anim-name + `animDone` gate (widen to `*todeath`, add a non-repeat test, derive the cap from `animT`). codereview R1/N2 proposes replacing it with the `solid` edge. | **codereview wins — replace, don't repair.** | The `solid` change is the server's own record that `FinishedAnimation_Killed` ran; four heuristics that each approximate that fact are strictly worse than the fact, and repairing them still leaves the looping-anim early-fire that mohaadata §7, codereview S1 and risk §1 each derived by a different route. |
| C2 | **`RagShapeMatch` and `ptPrev`.** codereview §3.3/N1 (its self-declared highest-value item): moving `pt` without `ptPrev` injects 219-875 u/s, bodies will never sleep, fix by projecting `ptPrev` too. gap B1: REFUTED, and the fix causes the failure it claims to cure (terminal 320 u/s, steady-state sag −4.75 u at α=0.35, −63 u at τ=0.20). | **gap wins — do NOT project `ptPrev`. This is dropped permanently.** | The 14 distance links (`cg_ragdoll.c:685-692`) and 16 braces (`:694-709`) use the identical `pt`-only construction and demonstrably let bodies sleep after bug-1962; if that were an unrecoverable velocity injection the truss would never have worked either. |
| C3 | **Settle stiffness direction.** reference #4: 0.35 → **0.55** (stiffer, hold the animator's pose). gap #3: convert to a time constant and start at τ=0.06 s ≈ α **0.125** (softer, today's α is a statue). | **gap's direction wins, reference's units win: keep `coop_ragdollStiff` as a per-substep alpha, default 0.25.** | Now that the captured pose is a *landed* pose rather than a mid-fall one, the shape-match's job changes from "stop the collapse" to "keep the silhouette while the ground reshapes it", which wants softer — but re-basing the cvar into seconds mid-experiment would silently invalidate the one live sweep the playtester gets. |
| C4 | **Off-by-one bone driver: this build or next?** reference #1 ranks it **#1** and notes the freeze drill is blind to it. codereview §4 concurs and adds that the shear scales with `drift`. gap C16: demoted — under a stiff settle the swings are small, and the fix is under-specified for 7 of 15 bones. | **In this build, behind `coop_ragdollDrive` (default 1), with the child rule written out in full (§3.4).** | gap is right that it is risky and right that it was under-specified — so specify it and make it a console-flippable A/B, which converts a medium-high-risk bet into a free measurement; reference is right that we have *never once tested this code path*, and the user has already sat through eight rounds of not knowing. |
| C5 | **`RAG_PTS` 15 → 17 (feet).** reference #6: ship it, alone, bone availability proven across 374 skeletons. mohaadata R9 / gap #7: only after the gating fixes land. | **OUT — round 9.** | It changes constraint topology (the exact thing that produced bug-1962/1963's piles), pushes world traces from 60 to 68 per body, and cascades into six `RAG_PTS`-derived constants; with the solid handoff and the drive A/B already in flight it would make the verdict unattributable. |
| C6 | **Move `CG_RagdollFrame` after `CG_AddPacketEntities`.** codereview S12/R10: verified safe, *strengthens* bug-1964. risk #9: MEDIUM, the one item that can reverse bug-1964. | **OUT — round 9, with the analysis banked.** | Both are right about the mechanism (`cg_view.c:2928` vs `:3078`, a one-frame `lerpOrigin` lag) but its effect on the settle branch is provably **exactly zero**, because every settle body is `MOVETYPE_NONE`-parked before capture and its origin no longer changes. |
| C7 | **Pre-lift.** mohaadata R4: raise the lift start to 64 u and deny-list the mortar deaths. codereview S6/R11: do **not** convert to a whole-body lift, add only the refuse-to-arm guard. | **Both halves of codereview, plus the lift start raised 24 → 40 u; no anim deny-list.** | The 13-38 u mortar burial mohaadata measured was against the *un-seated* origin, and the solid handoff now captures strictly after `droptofloor(64)`+`CheckGround()`, so the burial population collapses; guessing at an anim deny-list for a case the handoff already fixes adds risk for nothing. |
| C8 | **Trace budget severity.** reference #4 / gap #4 / risk #3: real, fix it. codereview S10: LOW-MED, burst-only. | **In. Split the counters and give movers a per-body allowance (risk #3's version, not gap's).** | Everyone agrees the defect is real and the fix is ~8 lines; risk is right that merely un-charging world traces still leaves 8 × 4 × 15 = 480 mover traces against a 240 budget, so the allowance is what actually restores the documented behaviour. |
| C9 | **`coop_ragdoll` → `CVAR_ARCHIVE`, and the `G_InitGame` pre-registration.** risk B2 splits it: archive half required, `G_InitGame` half prophylactic. | **Archive half in (cgame-only). `G_InitGame` half deferred.** | I re-ran the grep: `coop_ragdoll` and `r_ragdollDebug` appear in **zero** `.cfg` and `.scr` files in the tree, so the bug-1669 `getcvar` trap is not live and pulling `game.dll` into the ship unit would cost us the "cgame.dll alone" property for no present benefit. |
| C10 | **Seeding `ptPrev` from a model-space tag difference (reference §3 / S3).** mohaadata §4 refutes it as a bug-1964 reversal. | **Dropped permanently.** | mohaadata measured the counter-motion directly (`death_run03`: bbox centre −13 u/frame against a constant +19.6 u/frame root delta) and the engine stops applying delta the instant the anim clamps, so the corpse is genuinely at rest and the current `ptPrev == pt` seed is correct. |

---

## 3. THE BUILD — FILE BY FILE

**Ship unit: `cgame.dll` alone.** No engine, exe, renderer, protocol constant, netfield, `MAX_*` or
`game.dll` change. Every API used below was verified present in `cgame/cg_public.h` this session
(`CM_PointContents` `:173`, `CM_BoxTrace` `:177`, `Anim_NameForNum` `:383`, `Anim_Time` `:387`,
`Tag_NumForName` `:406`, `Tag_NameForNum` `:407`, `ForceUpdatePose` `:408`, `TIKI_Orientation` `:409`,
`R_SetRagdollPose` `:453`, `R_ClearRagdoll` `:454`) or is a `q_shared` global
(`IntegerToBoundingBox`, `q_shared.h:869`).

All edits are in **`openmohaa-hzm/code/cgame/cg_ragdoll.c`** unless stated.

---

### 3.1 — The solid handoff (replaces the whole pending heuristic)

**Delete** the `animDone` / `Anim_Time` / `Q_stricmpn(nm,"death",5)` / `death_balcony` machinery at
`cg_ragdoll.c:1244-1275` and the compound gate at `:1281`. **Add**, above `RagPendingThink`:

```c
// ---------- the server's own handoff signal --------------------------------------------------
//
// Actor::FinishedAnimation_Killed (fgame/actor_killed.cpp:69-70) is the ONLY route to
// Actor::BecomeCorpse (fgame/actor.cpp:12468) - the balcony set piece (actor_balcony.cpp:409) is
// the single other caller and it is script-driven along a baked path. BecomeCorpse swaps the box
// from the living MINS/MAXS {-15,-15,0}..{15,15,94} (fgame/bg_pmove.cpp:52-53, applied at
// actor.cpp:3265) to the corpse slab {-32,-32,0}..{32,32,16} (actor.cpp:12492-12494) and
// setSolidType() ends in link() (entity.cpp:2230), so SV_LinkEntity re-packs entityState.solid
// (server/sv_world.c:243) and the 32-bit netfield (qcommon/msg.cpp:1376) delivers it to us.
//
// Reaching that line PROVES two things we spent eight rounds guessing at: the authored death
// animation ran to completion, AND CheckGround()/droptofloor(64) has already parked the body.
//
// Actor::DeathEmbalm (actor.cpp:5587) also re-links every 0.5s throughout the death anim, but it
// only ever lowers maxs.z (94 -> 8 in steps of 4) and never touches x or y. maxs[0] is therefore
// a clean, monotone, one-shot discriminator: 15 while alive or dying, 32 once parked.
// BBOX_MAX_X is 512 (q_math.c:1591) so 32 is packed exactly, not clamped.
static qboolean RagServerParked(const entityState_t *es)
{
    vec3_t bmin, bmax;

    if (!es->solid) {
        return qfalse; // SOLID_NOT: the coop_corpseShootable 0 path (actor.cpp:12496-12497)
                       // parks the body too, but silently - those ride the give-up cap
    }
    IntegerToBoundingBox(es->solid, bmin, bmax);
    return (bmax[0] >= 24.0f && bmax[2] <= 32.0f) ? qtrue : qfalse;
}
```

`bmax[0] >= 24` alone is sufficient and unambiguous; `bmax[2] <= 32` is belt against a hypothetical
wide-boxed `ET_MODELANIM` actor and costs nothing.

**Ship note for the playtester:** this signal requires `coop_corpseShootable 1` (the default,
`fgame/actor.cpp:12489`). At `0` the corpse goes `SOLID_NOT` → `s.solid = 0` and no body will ever
ragdoll. Verify with `coop_corpseShootable` in the console before testing; if it reads 0, the whole
build is inert and the log will show only give-ups.

---

### 3.2 — Pending records leave the sim pool

With the solid handoff the pending phase can legitimately run 5 s (`death_fire.skc` is 4.700 s,
measured by the risk lens across 76 death anims) and `RagAllocSlot` (`:1176-1181`) can only evict
`state == 2`, so a pending record is unevictable. Eight deaths inside that window starve the pool.

**Add** near the sim-pool declarations (`:174-176`):

```c
// pending records must NOT hold a sim slot (gap-lens #2, promoted to a prerequisite by the
// longer pending phase the solid handoff allows). 16 x 32 bytes; a sim slot is ~9.4 KB.
#define RAG_MAX_PEND   16
#define RAG_PEND_CAP_MS 8000 // give-up only: never fires a capture (see RagPendingThink)

typedef struct {
    qboolean active;
    int      entnum;
    int      armTime;
    int      lastPrint;
    int      pendStatic;
    vec3_t   pendOrigin;
} ragPend_t;

static ragPend_t s_ragPend[RAG_MAX_PEND];
```

**Delete** `branch`-adjacent pending fields `pendOrigin` / `pendStatic` from `ragSim_t` (`:167-168`)
— they move to `ragPend_t`. Keep `branch`, `goal[]`, `gravScale`, `rampMs`.

**Replace** the `rag_mode->integer != 3` block at `:1422-1436` with a `ragPend_t` allocation:

```c
    if (rag_mode->integer == 1 && !rag_test->integer) {
        // SETTLE: record a pending arm and let the animators own the fall. The capture happens
        // when the SERVER parks the body, not when we guess the anim is over.
        int        k;
        ragPend_t *p = NULL;
        for (k = 0; k < RAG_MAX_PEND; k++) {
            if (!s_ragPend[k].active) { p = &s_ragPend[k]; break; }
        }
        if (!p) {
            for (k = 0; k < RAG_MAX_PEND; k++) { // oldest-first eviction; a dropped pending
                if (!p || s_ragPend[k].armTime < p->armTime) { p = &s_ragPend[k]; }
            }
        }
        if (p) {
            memset(p, 0, sizeof(*p));
            p->active  = qtrue;
            p->entnum  = ns->number;
            p->armTime = cg.time;
            VectorCopy(cent->lerpOrigin, p->pendOrigin);
            if (rag_debug->integer) {
                cgi.Printf("^~^~^ RAGDOLL pending-arm ent=%d (waiting on server park)\n", ns->number);
            }
        }
        return;
    }
    if (rag_mode->integer != 3) {
        return; // mode 0 = OFF (was: fell through to settle - codereview S14 trap)
    }
```

`CG_RagdollClearEnt` (`:250-259`) must also clear any pending record for that entnum, so the
`EF_DEAD` falling edge / teleport / modelindex clear signals at `:1343-1347` reach pendings too.

---

### 3.3 — `RagPendingThink` rewritten

**Replace** `cg_ragdoll.c:1223-1310` entirely:

```c
// SETTLE branch: hold while the authored death animation plays, then capture the LANDED pose at
// the exact frame the server parks the corpse. Arming at the EF_DEAD edge photographed a STANDING
// soldier - the engine does not request the death anim until a Think after the edge and then
// crossblends it in (anim/killed.scr sets self.blendtime 0.3) - which is the whole "bodies don't
// fall like that" verdict from rounds 1-7.
static void RagPendingThink(ragPend_t *p)
{
    centity_t     *cent = &cg_entities[p->entnum];
    entityState_t *cs   = &cent->currentState;
    vec3_t         d;
    int            age = cg.time - p->armTime;

    // lifecycle, evaluated first: revived, recycled, dropped from the snapshot, or PVS-exited.
    // cent->currentValid (cg_local.h:94) is cleared for every old-snapshot entity at
    // cg_snapshot.c:229-232 and re-set only by CG_TransitionEntity, so it is exactly the
    // "still in the world" discriminator (codereview S8 hole 1).
    if (!cent->currentValid || !cent->interpolate || cs->modelindex <= 0
        || cs->eType != ET_MODELANIM || !(cs->eFlags & EF_DEAD)) {
        memset(p, 0, sizeof(*p));
        return;
    }

    VectorSubtract(cent->lerpOrigin, p->pendOrigin, d);
    VectorCopy(cent->lerpOrigin, p->pendOrigin);
    p->pendStatic = (VectorLength(d) < 0.5f) ? p->pendStatic + 1 : 0;

    if (rag_debug->integer >= 2 && cg.time - p->lastPrint >= 250) {
        vec3_t bmn, bmx;
        p->lastPrint = cg.time;
        IntegerToBoundingBox(cs->solid, bmn, bmx);
        cgi.Printf("^~^~^ RAGDOLL pending ent=%d box=(%.0f %.0f) static=%d age=%d\n",
                   p->entnum, bmx[0], bmx[2], p->pendStatic, age);
    }

    if (!RagServerParked(cs)) {
        // GIVE UP, never fire. A corpse the server never parks - bPlayDeathAnim == false takes
        // SetThink(THINKSTATE_KILLED, THINK_DEAD) at actor.cpp:5498 and never reaches
        // FinishedAnimation_Killed - keeps its authored pose, which IS vanilla and therefore
        // invisible. Arming a guessed pose is the failure mode this whole branch exists to end.
        if (age > RAG_PEND_CAP_MS) {
            if (rag_debug->integer) {
                cgi.Printf("^~^~^ RAGDOLL pending gave-up ent=%d age=%dms (server never parked)\n",
                           p->entnum, age);
            }
            memset(p, 0, sizeof(*p));
        }
        return;
    }
    if (p->pendStatic < 2) {
        return; // the park itself moves the origin (droptofloor 64u): let it land first
    }

    {
        int         entnum  = p->entnum;
        int         armTime = p->armTime;
        int         i;
        const char *nm      = NULL;
        ragSim_t   *s;

        memset(p, 0, sizeof(*p));       // the pending record is spent either way
        s = RagAllocSlot(entnum);
        if (!s) {
            return;                     // pool full of awake sims: keep the authored pose
        }
        if (!RagCapture(cent, cs, s)) {
            memset(s, 0, sizeof(*s));
            return;
        }
        s->active    = qtrue;
        s->entnum    = entnum;
        s->state     = 1;               // no seed: the authored fall already happened
        s->branch    = 1;
        s->armTime   = armTime;
        s->gravScale = 0.0f;
        for (i = 0; i < RAG_PTS; i++) {
            VectorCopy(s->pt[i], s->goal[i]); // the authored pose is the target silhouette
        }
        RagPush(s);
        if (rag_debug->integer) {
            int dom = -1, k;
            float bw = 0;
            for (k = 0; k < MAX_FRAMEINFOS; k++) {
                if (cs->frameInfo[k].weight > bw) { bw = cs->frameInfo[k].weight; dom = k; }
            }
            if (dom >= 0) { nm = cgi.Anim_NameForNum(s->tiki, cs->frameInfo[dom].index); }
            cgi.Printf("^~^~^ RAGDOLL settle-armed ent=%d channels=%d after=%dms via=solid "
                       "anim=%s buried=%d\n",
                       entnum, s->count, cg.time - armTime, nm ? nm : "?", (int)s->buried);
        }
    }
}
```

The anim name is now **diagnostic only** — it decides nothing. That is the point: it tells us which
anims are reaching the sim without gating on the answer.

**`CG_RagdollFrame`** gets a pending loop ahead of the sim loop, and the `state == -1` branch at
`:1028-1031` is deleted:

```c
    for (i = 0; i < RAG_MAX_PEND; i++) {
        if (s_ragPend[i].active) { RagPendingThink(&s_ragPend[i]); }
    }
```

---

### 3.4 — Child-driven bone rotation (`coop_ragdollDrive`, the A/B)

`RagPush` (`:927-932`) builds bone `i`'s swing from `pt[parent] -> pt[i]`. A bone's skinned mesh runs
from its own origin toward its **child**, and `renderergl2/tr_ragdoll.cpp:152-171` writes an absolute
model-space `offset`+`matrix` per channel, so bone `i`'s matrix orients the flesh running `i -> child`
while we hand it the orientation of the segment arriving *at* `i`. Every bone's mesh lags one link up
the chain. **The `coop_ragdollTest 2` freeze drill cannot see this**, because with `S = I` the
off-by-one vanishes identically — which is exactly how "the render pipeline is proven correct" and
"limbs stretching and warping" have both been true for eight rounds.

**The child rule, written out in full** (the thing gap C16 correctly said was missing). Pelvis keeps
its anatomical triad — it is the single-producer invariant at `:619-621` and must not be touched.
Multi-child bones take the child their own mesh actually runs toward. Leaves keep the parent segment,
which for them is very nearly correct anyway.

```c
// A bone's mesh runs from its own origin toward its CHILD, so bone i's swing must be measured on
// pt[i] -> pt[child]. Pelvis (-1) uses the anatomical triad in RagBodyRotation and is never
// segment-driven. Spine2 has three sim children (Neck, L/R UpperArm) - the spine's own flesh runs
// to the Neck. Head/Hands/Calves are leaves with no sim child and fall back to the parent segment.
static const int s_ragDriveChild[RAG_PTS] = {
    -1, //  0 Pelvis     - anatomical triad, never segment-driven
     2, //  1 Spine1     -> Spine2
     3, //  2 Spine2     -> Neck        (of 3 sim children: the spine's own run)
     4, //  3 Neck       -> Head
    -1, //  4 Head       - leaf
     6, //  5 L UpperArm -> L Forearm
     7, //  6 L Forearm  -> L Hand
    -1, //  7 L Hand     - leaf
     9, //  8 R UpperArm -> R Forearm
    10, //  9 R Forearm  -> R Hand
    -1, // 10 R Hand     - leaf
    12, // 11 L Thigh    -> L Calf
    -1, // 12 L Calf     - leaf TODAY; becomes L Foot in round 9 (this is the unsimulated knee)
    14, // 13 R Thigh    -> R Calf
    -1, // 14 R Calf     - leaf
};
```

`ragSim_t` gains `vec3_t driveDir0[RAG_PTS];` and `byte driveOk[RAG_PTS];`. In `RagCapture`, after
the rest-length loop (`:525-546`):

```c
    for (i = 0; i < RAG_PTS; i++) {
        int    dch = s_ragDriveChild[i];
        vec3_t dv;
        s->driveOk[i] = 0;
        if (dch < 0) { continue; }
        VectorSubtract(s->pt[dch], s->pt[i], dv);
        if (VectorNormalize(dv) < 0.01f) { continue; }
        VectorCopy(dv, s->driveDir0[i]);
        s->driveOk[i] = 1;
    }
```

In `RagPush`, replace the `else` at `:926-933`:

```c
        } else {
            const float *ref;
            int          dch = rag_drive->integer ? s_ragDriveChild[i] : -1;
            if (dch >= 0 && s->driveOk[i]) {
                VectorSubtract(s->pt[dch], s->pt[i], dNow); // OUTGOING segment: the mesh's own run
                ref = s->driveDir0[i];
            } else {
                VectorSubtract(s->pt[i], s->pt[p], dNow);   // leaf / drive off: incoming segment
                ref = s->restDir[i];
            }
            if (VectorLength(dNow) < 0.01f) {
                RagMat3Identity(S);
            } else {
                VectorNormalize(dNow);
                RagMat3FromTo(ref, dNow, S);
            }
        }
```

This deliberately changes **both** paths that consume `S`: the rotation path (`conj[i]`, `:936-937`)
and the position path (`rotNow[i]`, `:935`, consumed at `:946`). That is correct and required — a
channel slaved to bone `a` must follow bone `a`'s real orientation, and both paths must agree or the
mesh separates from its own bone origin.

**Invariant check:** the `Ecap * S * Enow^T` conjugation (`:936-937`), the current-frame placement
(`:899-900`), the `load_scale` offset contract in `tr_ragdoll.cpp`, and the per-substep collision
ordering (`:1078-1087`) are all untouched — only the *content* of `S` changes, in the one place it is
produced.

---

### 3.5 — Contact-relaxed shape-match + softer default

`RagShapeMatch` pulls all 14 non-pelvis points toward the rigid goal with one shared alpha, so a
limb resting on a step is pulled off it just as hard as one hanging in the air. Exempting contact
points is the single change that most directly produces "shoulder on the step, arm hanging off it".

`ragSim_t` gains `byte contact[RAG_PTS];`. At the top of `RagCollideWorld` (`:798`):

```c
    for (i = 0; i < RAG_PTS; i++) {
        if (s->contact[i]) { s->contact[i]--; } // 2-substep memory: the shape-match runs BEFORE
    }                                          // collide, so it reads the previous substep
```

In `RagResolveHit`'s resting-contact branch (`:743-747`), before the `return`: `s->contact[i] = 2;`

In `RagShapeMatch` (`:651-658`):

```c
    for (i = 1; i < RAG_PTS; i++) {
        vec3_t rel, want, d;
        float  a = alpha;
        VectorSubtract(s->goal[i], s->goal[0], rel);
        RagMat3RotateVec(S, rel, want);
        VectorAdd(s->pt[0], want, want);
        VectorSubtract(want, s->pt[i], d);
        if (s->contact[i]) {
            a *= RAG_CONTACT_RELAX; // where the body TOUCHES, the ground gets the last word:
        }                           // the limb stays where it landed instead of being reeled in
        VectorMA(s->pt[i], a, d, s->pt[i]);
    }
```

`#define RAG_CONTACT_RELAX 0.15f` beside the other constants. Default `coop_ragdollStiff` 0.35 → **0.25**
at `:235`.

**Do NOT** touch `ptPrev` here (C2). Leave the pelvis un-shape-matched (gap B2c) — that is what lets
the body fall onto the ground at all; changing it is a round-9 candidate.

---

### 3.6 — World gravity instead of 1.56 g

`RAG_GRAVITY 800` (`:59`) is 1.5625 × the game's `sv_gravity 512` (`fgame/gamecvars.cpp:348`), so
every drape snaps down harder than the world the player is standing in, and it raises the
constraint-jitter floor the sleep gate has to clear.

```c
// the world's own gravity, not a hand-picked 800 (= 1.56 g). playerState_t.gravity is q_shared.h:1885
// and is networked 16-bit in both field tables (msg.cpp:3370, :3432). It carries the LOCAL player's
// sv_gravity * per-player multiplier (fgame/player.cpp), which is the gravity the viewer is standing
// in - the right one for a cosmetic effect they are looking at.
static float RagGravity(void)
{
    float g = (cg.snap && cg.snap->ps.gravity > 0) ? (float)cg.snap->ps.gravity : 512.0f;
    if (g < 1.0f)    { g = 1.0f; }
    if (g > 4000.0f) { g = 4000.0f; }
    return g;
}
```

`RagStep:664` becomes `float g = RagGravity() * dt * dt * (s->branch ? s->gravScale : 1.0f);`.
`RAG_GRAVITY` is deleted so no stale reference survives.

---

### 3.7 — Split trace budgets

`RagCollideWorld:806` increments `s_ragTraceCount` but never checks it; only `RagCollideMovers:850`
checks. The banner at `:792` claiming world traces are "budget-EXEMPT" is therefore false, and 15 × 4
substeps = 60 world traces per body exhausts the 240 budget by the third or fourth awake body —
after which mover collision is silently off for every remaining corpse, breaking the
elevator-carries-corpses behaviour this file's header (lines 14-16) advertises.

```c
static int s_ragTraceCount;   // MOVER traces only - the RAG_TRACE_BUDGET is theirs
static int s_ragWorldTraces;  // world traces: bounded by construction at RAG_PTS*RAG_MAX_STEPS*
                              // RAG_MAX_SIMS = 480, and reported in the sleep line
#define RAG_MOVER_PER_BODY 60 // 8 bodies x 60 = 480 > 240, so a per-body allowance is what
                              // actually stops the first bodies eating the whole budget
```

`RagCollideWorld:806` → `s_ragWorldTraces++;`. `RagCollideMovers` takes a snapshot at entry
(`int allow = s_ragTraceCount + RAG_MOVER_PER_BODY;`) and the guard at `:850` becomes
`if (s_ragTraceCount >= RAG_TRACE_BUDGET || s_ragTraceCount >= allow) { return; }`. Both counters
reset at `:1020`. Update the stale banner at `:792`.

---

### 3.8 — Pre-lift start 24 → 40 u, and refuse-to-arm on a still-buried torso

The pre-lift (`:493-509`) traces from `pt[i] + 24u` down. If both ends are in solid the trace is
`startsolid`, the point stays buried, `RagCollideWorld:808-812` freezes it, and it pins the body —
bug-1962's pile mechanism. codereview R11 is right that converting this to a rigid whole-body lift
re-arms exactly that failure on stepped geometry; the correct fix is to *refuse the arm*.

- `above[2] += 24` at `:500` → `above[2] += 40`.
- Count survivors and store: `ragSim_t` gains `byte buried;`, incremented for each point still
  returning `CM_PointContents(... ) & MASK_DEADSOLID` after the lift pass.
- After the lift loop, before the bind-pose check at `:513-522`:

```c
    // a buried point starts every trace in-solid, freezes, and PINS the body (bug-1962's pile).
    // If the pre-lift could not free the TORSO, or four points anywhere, refuse to arm: keeping
    // the authored pose is vanilla and therefore invisible, and strictly better than a pinned pile.
    {
        int nTorso = 0;
        for (i = 0; i <= 4; i++) {
            if (cgi.CM_PointContents(s->pt[i], 0) & MASK_DEADSOLID) { nTorso++; }
        }
        if (nTorso > 0 || s->buried >= 4) {
            if (rag_debug->integer) {
                cgi.Printf("^~^~^ RAGDOLL capture BURIED ent=%d torso=%d total=%d - not arming\n",
                           ns->number, nTorso, (int)s->buried);
            }
            return qfalse;
        }
    }
```

A single hand inside a crate must not kill the whole ragdoll; a buried pelvis or head must.

---

### 3.9 — Cvars

At `:226-237`:

| cvar | change | flags |
|---|---|---|
| `coop_ragdoll` | `CVAR_TEMP` → **`CVAR_ARCHIVE`** | a player's OFF must survive a relaunch (`q_shared.h:1308`: `CVAR_TEMP` is explicitly *not archived*). Cgame-only; the `G_InitGame` pre-registration is deferred (C9). |
| `coop_ragdollMode` | doc + behaviour: **0 = OFF**, 1 = settle, 3 = legacy free-fall | `CVAR_TEMP` |
| `coop_ragdollStiff` | default `"0.35"` → **`"0.25"`** | `CVAR_TEMP` |
| `coop_ragdollDrive` | **NEW**, default `"1"` | `CVAR_TEMP` — the live A/B for §3.4 |
| `coop_ragdollTest`, `r_ragdollDebug` | unchanged | `CVAR_TEMP` |

`static cvar_t *rag_drive = NULL;` alongside the others, `rag_drive = cgi.Cvar_Get("coop_ragdollDrive", "1", CVAR_TEMP);`.

---

### 3.10 — Instrumentation (this is the evidence channel — get it right)

1. **Hoist the skeleton draw.** At `:1032` `RagDrawSkeleton` sits *below* the `state == -1` continue,
   so `r_ragdollDebug 2` produced a print flood with no dots during the phase that most needed them.
   With pendings in their own array the sim loop no longer has a `-1` state, so the draw now runs for
   every sim; add a matching dot draw (pelvis only, green) for pending records so the tester can see
   which corpses are waiting.
2. **Throttle the pending print** to 250 ms (§3.3) — it was ~375 lines per corpse at 125 fps.
3. **`settle-armed`** carries `after=`, `via=solid`, `anim=`, `buried=` (§3.3).
4. **`sleep`** (`:1148-1150`) gains four fields:

```c
    cgi.Printf("^~^~^ RAGDOLL sleep ent=%d life=%dms span=(%.0f %.0f %.0f) branch=%s drift=%.1f "
               "maxspd=%.0f contacts=%d alpha=%.2f drive=%d worldtr=%d\n",
               s->entnum, s->lifeMs, bmx[0]-bmn[0], bmx[1]-bmn[1], bmx[2]-bmn[2],
               s->branch ? "settle" : "free", drift, s->maxSpeed, nContacts,
               rag_stiff->value, rag_drive->integer, s_ragWorldTraces);
```

`ragSim_t` gains `float maxSpeed;` updated from the existing per-frame `speed` at `:1111`
(`if (speed > s->maxSpeed) s->maxSpeed = speed;`). `nContacts` is a local count of non-zero
`s->contact[]`.

**Retire `life=` as an acceptance metric.** On the settle branch the body starts at rest, so `sleepMs`
accrues from frame 1 and `life` degenerates to approximately the 1000 ms dwell regardless of what the
physics did. Keep printing it; do not judge on it. `drift`, `span`, `maxspd` and `after` are the
discriminating numbers.

---

## 4. DELIBERATELY OUT — AND WHICH ROUND

| Item | Why out of THIS build | Lands |
|---|---|---|
| **Feet as sim points 15/16 (the unsimulated knee)** | Changes constraint topology — the exact thing that produced bug-1962/1963's piles — and cascades into `s_ragPtRadius`, `s_ragBraces`, `s_ragAnchorTable:202-205`, the sleep divisor `:1111`, the drift divisor `:1146` and the trace count (60 → 68/body). A third independent variable makes the verdict unattributable. Bone availability is already proven (reference #6: 374 skeletons, zero exceptions), so round 9 starts from a solved problem. | **R9**, trigger in §9 |
| **Off-by-one bone drive as an unconditional change** | It is IN, but behind `coop_ragdollDrive`. Shipping it unswitchable would be a bet on the same push math that was wrong in bug-1963 *and* bug-1964. | in, as A/B |
| **`CG_RagdollFrame` reorder (`cg_view.c:2928` → after `:3078`)** | Provably zero effect on the settle branch: every settle body is `MOVETYPE_NONE`-parked before capture, so `lerpOrigin` does not change between frames. It is the one item that can reverse bug-1964. | **R9** |
| **Corpse-vs-corpse pushout** | Real (`MASK_DEADSOLID`, `bg_public.h:643`, excludes `CONTENTS_WEAPONCLIP`, so ragdolls interpenetrate freely) and a genuine contributor to "mangled piles" — but it fights the shape-match and needs a decision about slept bodies, which the frame loop skips entirely (`:1050-1062`). | **R9/R10** |
| **Post-death bullet/explosion impulse from `cg_parsemsg.cpp`** | The single most "alive"-feeling item on the whole list, and mechanically free — but it is a *second* answer to "why did that body move", and this build must attribute its result to the handoff alone. | **R10** |
| **Blood pool at `BecomeCorpse` instead of `health<=0`** | `game.dll` ship, breaks the cgame-only property, re-opens a thrice-tuned feature (bugs 792/817/828), and is orthogonal to the sim. Independently worth doing (median 82.9 u = 1.58 m of measured displacement). | **own build** |
| **`killed.scr` variety edits** (yaw arc `>135 && <225` unreachable above 180 at 7 sites; `weapongroup`-driven `kneestodeath`; `death_grenade_high` recovery) | Mod-side `.scr`. They change *which anims play*, which changes what the tester sees, which confounds the one question. The solid handoff no longer cares which anim played, so there is no longer any urgency. | **R10** |
| **Neck cone tightening (77° → 55°)** | A ~77° isotropic cone already exists via the `{2,4}` brace (`:98`) at factor `0.80` (`:115`) — this is a tightening, not a new limit. Only worth it once bodies actually go limp. | **R11** |
| **Props via `CM_TempBoxModel`, ledge topple, renderer slot bump, cull bounds from the sim AABB** | All blocked on earlier items or on the trace budget; none affect the question. | **R11+** |
| **`ptPrev` projection in `RagShapeMatch`** | **DROPPED PERMANENTLY** (C2). gap's simulation: never sleeps, sags 4.8-63 u below the authored pose. | never |
| **`ptPrev` seeded from a model-space tag difference** | **DROPPED PERMANENTLY** (C10). Would re-open bug-1964's "bodies slid forward". | never |
| **`G_InitGame` pre-registration of `coop_ragdoll`** | Grep-verified: zero `.cfg`/`.scr` references, so the bug-1669 trap is not live, and it would pull `game.dll` into the ship unit. | when a settings-menu entry lands |

---

## 5. PARAMETER TABLE

| Parameter | Where | Old | **New** | Reasoning |
|---|---|---|---|---|
| `coop_ragdoll` | `:230` | `0`, `CVAR_TEMP` | `0`, **`CVAR_ARCHIVE`** | Opt-in stays opt-in; but a player's ON/OFF must survive a relaunch — `CVAR_TEMP` is explicitly non-archived (`q_shared.h:1308`). Also spares the tester retyping it across a multi-session sweep. |
| `coop_ragdollMode` | `:234` | `1` (and `0` silently behaved as settle) | `1`; **`0` now means OFF** | codereview S14: `:1422` tested `!= 3`, so a tester typing `0` expecting "off" got settle. Real trap, 2 lines. |
| `coop_ragdollStiff` | `:235` | `0.35` | **`0.25`** | The captured pose is now a *landed* pose, so the shape-match's job shifts from "prevent the collapse" to "keep the silhouette while the ground reshapes it" — which wants softer. `\|λ\| = √(0.75 × 0.98) = 0.857`, half-life ≈ 4.5 substeps ≈ 36 ms: visible drape, no puddle. **Sweep 0.10 / 0.25 / 0.50 in one session** — it is the only live-tunable item and therefore the highest information per playtest. |
| `coop_ragdollDrive` | new | — | **`1`** | The off-by-one bone-driver A/B (§3.4). `1` = child-driven (mesh-correct), `0` = today's parent-driven. Default 1 because the analysis says it is right; switchable because the freeze drill cannot verify it. |
| `RAG_CONTACT_RELAX` | new | — | **`0.15f`** | Where a point rests on geometry the shape-match pull drops to 15 %, so the ground wins. This is the specific mechanism that produces "shoulder on the step, arm hanging off it" rather than a rigid body hovering over a stair edge. Not a cvar: it is a physical property of contact, not a taste knob. |
| gravity | `:59` `RAG_GRAVITY 800` | `800` (1.5625 g) | **`cg.snap->ps.gravity`, fallback `512`, clamp 1-4000** | `sv_gravity` defaults 512 (`fgame/gamecvars.cpp:348`); 800 makes the drape snap down 56 % harder than the world the player is standing in, and it raises the constraint-jitter floor the sleep gate must clear (g·h² falls 0.0512 → 0.0328 u, jitter floor ~6 → ~3.8 u/s). |
| gravity ramp | `:1072` | 0 → 1 over **250 ms** | **unchanged** | It exists to stop a lurch at handoff. With the handoff now landing on an already-parked body the lurch risk is lower, not higher; no reason to move it and every reason not to add a variable. |
| shape-match ramp | `:721` | rigid → target over **300 ms** | **unchanged** | Same argument. |
| sleep speed gate | `:1115` | `10.0f` u/s | **unchanged at 10** | reference #5 wants 18, derived from a post-gravity-fix jitter floor of ~3.8 u/s. But reference's own verifier notes that on the settle branch `sleepMs` accrues from frame 1, so raising the gate makes the body sleep at *exactly* the dwell and turns the life cap into dead code. Lowering the gravity already lowers the floor; changing the gate on top of it in the same build makes the sleep timing unattributable. **Revisit in R9 with this build's `maxspd=` data.** |
| sleep dwell | `:1120` | `1000` ms | **unchanged** | Same reason. `life` is retired as a metric, so the dwell no longer distorts anything we read. |
| life cap | `:1120` | `6000` ms | **unchanged** | Only reachable if the body genuinely never settles, which is itself the signal. |
| pre-lift start | `:500` | `+24` u | **`+40` u** | A 24 u up-trace whose *other* end is also in solid returns `startsolid` and leaves the point buried. 40 u clears the residual burial that survives `droptofloor(64)` while staying well inside the corpse's own scale. |
| buried refuse-to-arm | new | — | **torso (pt 0-4) any, or ≥ 4 points total** | A pinned body is worse than no ragdoll; a hand in a crate is not. Failure mode = authored pose = vanilla = invisible. |
| pending cap | `:1281` | `3000` ms, **fires a capture** | **`8000` ms, DROPS** | The cap was arming a guessed mid-fall pose — the exact defect the branch exists to end. As a give-up it can be generous: `death_fire.skc` is 4.700 s and `m2l1_gate_open_death.skc` 6.900 s (risk lens, 76 anims measured). Free now that pendings do not hold sim slots. |
| `RAG_MAX_PEND` | new | — | **`16`** | 16 × 32 B = 512 B, vs ~9.4 KB for a `ragSim_t`. Two of the mod's own scripted waves can kill 8+ at once (`aihandler.scr:317`). |
| `RAG_MOVER_PER_BODY` | new | — | **`60`** | 15 pts × 4 movers. Without a per-body allowance the first 4 bodies eat all 240 and later bodies get zero mover collision — merely un-charging world traces does not fix that (8 × 60 = 480 > 240). |
| `RAG_TRACE_BUDGET` | `:62` | `240` | **unchanged, now movers only** | With world traces on their own counter the 240 is finally what its comment always claimed. |
| `RAG_DAMPING` | `:60` | `0.98f` | **unchanged** | reference #11 proposed 0.995; three lenses note it directly attacks bug-1962's fix (constraint-jitter decay ~4× longer) and is irrelevant to a branch that starts at rest. |
| restitution `0.1f` / friction `0.45f`/`0.75f` | `:748-749` | — | **unchanged** | reference's own verifier measured the rebound apex at **0.28 u** — one sub-pixel microbounce before the resting-contact full-stop at `:743` owns it. Changing either is a visual no-op with a nonzero regression surface. |

---

## 6. ACCEPTANCE EVIDENCE

### 6.1 Console setup — exactly what the user types

**Step 0 — the regression drill, once, before anything else.** It proves the render round-trip
survived the `RagPush` edit:

```
developer 1
r_ragdollDebug 1
coop_ragdoll 1
coop_ragdollMode 3
coop_ragdollTest 2
```

Kill one soldier. **Required:** the corpse renders as a pixel-perfect normal standing soldier, frozen.
Any warp, stretch, twist or compaction here means the §3.4 edit broke the identity case and **the
build must not be judged further** — report and stop.

**Step 1 — the actual test:**

```
coop_ragdollTest 0
coop_ragdollMode 1
coop_ragdollStiff 0.25
coop_ragdollDrive 1
```

**Step 2 — the two sweeps, in the same session.** After ~10 kills at the settings above:

```
coop_ragdollDrive 0        // A/B the bone driver, ~10 more kills, then back to 1
coop_ragdollStiff 0.10     // ~10 kills
coop_ragdollStiff 0.50     // ~10 kills
```

Log: `G:\mohaa-gl2\home\maintt\qconsole.log`. `logfile 2` is already in `autoexec.cfg`.

**Sanity check before starting:** type `coop_corpseShootable` — it must read `1`. At `0` the corpse
takes the `SOLID_NOT` path (`fgame/actor.cpp:12496-12497`) and **no body will ever ragdoll**; the log
will show only `pending gave-up`.

### 6.2 Where to test

| Map | Geometry that matters | What it tests |
|---|---|---|
| **m1l1 beach** | flat wet sand, hedgehogs, sandbag lines, the sea wall | The baseline: many simultaneous deaths on flat ground. `drift` here should be small (0.5-3) and bodies should look nearly vanilla. Also the only place that stresses the 8-slot pool and the trace budget. |
| **m1l1 village** | doorways, low walls, rubble, interior thresholds | Piles in doorways — the "mangled piles" verdict's home ground. |
| **m3l3 church** | **stairs**, pews, crates, the altar step | **The decisive venue.** A body dying on a staircase is where a landed authored pose and real geometry disagree most, so it is where `drift` is largest and where the contact-relaxed shape-match either works or does not. Kill at least 5 men on the stairs. |

### 6.3 The log lines — success

One healthy kill produces exactly this sequence:

```
^~^~^ RAGDOLL pending-arm ent=147 (waiting on server park)
^~^~^ RAGDOLL settle-armed ent=147 channels=72 after=1420ms via=solid anim=death_left buried=0
^~^~^ RAGDOLL contact ent=147 pt=11 n=(0.00 0.00 1.00)
^~^~^ RAGDOLL sleep ent=147 life=1180ms span=(56 21 13) branch=settle drift=2.8 maxspd=58 contacts=6 alpha=0.25 drive=1 worldtr=180
```

**Pass thresholds — read these, not prose:**

| Field | Pass | Meaning of a miss |
|---|---|---|
| `via=` | **`solid` on ≥ 90 % of armed bodies** | `via=` can only ever read `solid` by construction; what you count instead is `pending gave-up` lines. > 20 % give-ups means a large share of kills never reach `BecomeCorpse` — a `game.dll`/`bPlayDeathAnim` question, not a physics one. |
| `after=` | **900-2200 ms** on the great majority; a long tail to ~5000 ms is correct (`death_fire` is 4.7 s) | `after < 400 ms` on a standing kill would mean the solid test fired early — impossible by construction, so it would indicate a decode bug. Report immediately. |
| `buried=` | **0 or 1** typically; `capture BURIED ... not arming` should be rare (< 10 %) | High burial means `droptofloor(64)` is not seating bodies on that geometry. |
| `span=` | **one lateral axis 45-58 u**, z 8-20 u for a sprawled body | `< 35 u on every axis` = point pile. 57.5 u is the 15-point cloud's full extension (bug-1963), so **do not expect > 60** — a pass mark above that is unpassable. |
| `drift=` | **0.5-3 on flat ground; 5-20 on stairs/sandbags/crates** | `≈ 0 everywhere including stairs` = the shape-match is winning everywhere = statue. `> 30` = the pose is collapsing. |
| `maxspd=` | **30-120 u/s** | `> 300` on the settle branch means something is falling that should not be — the pose was not landed. |
| `contacts=` | **≥ 3** for a body lying on a floor | `0` means the collision pass never ran: check `worldtr=`. |
| `worldtr=` | **≤ 480** | It is bounded by construction; if it ever exceeds that the split in §3.7 is wrong. |
| `life=` | **DO NOT JUDGE ON THIS** | On the settle branch `sleepMs` accrues from frame 1, so it degenerates to the dwell. |

### 6.4 The visual verdicts

**Success reads as:** the soldier plays his full authored death animation exactly as in vanilla — no
twitch, no snap, no pose change at the handoff — and then, at the moment he would normally freeze, he
*keeps going for a beat*: an arm slides off the sandbag it landed across, a leg folds down the next
stair, the torso rolls a few degrees to sit flat on the ground it is actually on. Silhouette stays
recognisably the animator's; contact with geometry is correct; nothing stretches.

**Failure signatures, and what each redirects to:**

| Signature | Reading | Redirect |
|---|---|---|
| **F1** — bodies visibly *pop* or *jump* at the handoff | The park moved the origin and the `pendStatic >= 2` belt was insufficient | Tuning: raise the static dwell to 4 frames. Not architectural. |
| **F2** — `drift ≈ 0` on stairs too; user says "placed", "frozen", "hovering over the step" | Shape-match too stiff / contact relax too weak | Tuning: `coop_ragdollStiff 0.10`, then `RAG_CONTACT_RELAX` 0.15 → 0.05. Not architectural. |
| **F3** — user says "limbs stretching and warping" AND `coop_ragdollDrive 0` looks **the same** | The mesh defect is **not** the bone driver | **Round 9 pivots to the per-channel slaving** (`anchor[]` / `relPos[]`, `:560-612`) or the renderer offset contract — a different subsystem, not more physics tuning. |
| **F4** — warping, but `drive 0` looks **worse** and `drive 1` looks better-yet-imperfect | The driver fix is correct and **incomplete** | Round 9 = feet/knee points (§4), which is the known residual: pt 12/14 are leaves today, so the entire shin+foot rides the thigh→knee direction. |
| **F5** — user says "they still fall into a puddle" AND `span < 35` | The truss is losing; the landed pose is collapsing under gravity | Raise stiffness *and* check `maxspd`; if `maxspd > 300` the capture is not a landed pose after all and the solid decode is suspect. |
| **F6** — bodies sink through floors or slide again | bug-1962/1964 regression | Bisect: `coop_ragdollDrive 0`, then `coop_ragdollMode 3`. If mode 3 is also broken the regression is in `RagPush`/collision, not the handoff. |
| **F7** — `pending gave-up` on > 20 % of kills | A large share of deaths never reach `BecomeCorpse` | `game.dll` question: audit `DispatchEventKilled` callers passing `bPlayDeathAnim == false`. Not a cgame fix. |

### 6.5 **THE REDIRECT SIGNATURE** — the one combination that says "stop this approach"

> The freeze drill (`coop_ragdollTest 2`) is clean **AND** the skeleton dots (`r_ragdollDebug 2`) form
> a clean, correctly-proportioned body shape **AND** `span`/`drift`/`maxspd` are all in range **AND**
> `coop_ragdollDrive 0` and `1` look identical **AND** the user still reports mangled or warped meshes.

That means: the physics is right, the space round-trip is right, the bone driver is not the cause —
so the fault is in how the *other 57 channels* are slaved to the 15 sim bones (`:560-612` capture,
`:942-967` push). Round 9 would be a slaving rewrite, not another physics round. **Do not spend a
tenth round tuning constants if this combination appears.**

---

## 7. ROLLBACK — one command per piece

| Piece | Escape | Effect |
|---|---|---|
| Everything | `coop_ragdoll 0` | Feature off. Corpses hold the server anim pose = vanilla. Persists now that it is `CVAR_ARCHIVE`. |
| The settle branch (back to round-7 arm-at-`EF_DEAD`) | `coop_ragdollMode 3` | Legacy free-fall path, unchanged by this build except gravity and trace budgets. |
| The bone driver (§3.4) | `coop_ragdollDrive 0` | Reverts to parent-segment driving. Every other change stays live. |
| Shape-match tuning | `coop_ragdollStiff 0.35` | Round-7 value. |
| Debug noise | `r_ragdollDebug 0` | Silences all `^~^~^ RAGDOLL` lines. |
| Diagnose skeleton vs mesh | `r_ragdollDebug 2` | Dots for every sim (and pelvis dots for pendings). |
| The whole binary | Restore `cgame_r7_bak.dll` over the deployed `cgame.dll` and relaunch | Keep a copy of the current `cgame.dll` as `cgame_r7_bak.dll` **before** building. `build.ps1` ships `cgame.dll` to `G:\mohaa-gl2\` and the GOG root. |
| Source | `git revert <sha>` | Land the build as **one commit** so this works. |

---

## 8. RISK REGISTER — top 5, ordered by probability × impact

| # | Risk | P × I | Mitigation |
|---|---|---|---|
| **1** | **The child-drive edit (§3.4) warps the mesh.** It touches `RagPush`, the exact function that was wrong in bug-1963 (frame mixing) and bug-1964 (stale placement) — two consecutive rounds. | High × High | (a) `coop_ragdollDrive 0` reverts it live, so the build still answers its primary question; (b) the `coop_ragdollTest 2` freeze drill is **mandatory step 0** and catches any break of the identity case; (c) the A/B is itself the measurement — an implementer cannot "hope" it worked. |
| **2** | **`coop_corpseShootable 0` on the tester's machine makes the whole build inert.** The solid signal depends on the corpse taking the `SOLID_BBOX` path at `actor.cpp:12492-12494`. | Med × High | The default is `1` (`actor.cpp:12489`) and it is `CVAR_ARCHIVE`, so a past experiment could have persisted `0`. §6.1 makes checking it the first line of the test procedure, and the `pending gave-up` line names the failure explicitly rather than failing silently. |
| **3** | **Give-ups turn out to be common** — a meaningful share of kills never reach `BecomeCorpse` (`bPlayDeathAnim == false` → `THINK_DEAD`, `actor.cpp:5498`), so fewer bodies ragdoll than in round 7. | Med × Med | The failure mode is *vanilla* (authored pose), never a wrong pose — strictly better than round 7's guess. The `pending gave-up` count is printed, so one playtest measures the real rate instead of us estimating it; if > 20 % it becomes an explicit `game.dll` work item (F7). |
| **4** | **The softer stiffness (0.35 → 0.25) plus contact relax reads as "still a puddle"** and the user's verdict is unchanged for a tuning reason, wasting the round. | Med × Med | Both are live-tunable and the sweep is built into the procedure (§6.1 step 2): three stiffness values in one session, plus `drift=` and `span=` in the log to distinguish "too soft" from "architecturally wrong". This is the reason `coop_ragdollStiff` stays a per-substep alpha rather than being re-based into seconds mid-experiment (C3). |
| **5** | **Pending-array bookkeeping leaks** — a pending record whose entity is removed from the snapshot (body queue `EV_Remove` at `MAX_BODYQUEUE 128`) is never cleared and later captures against a stale `currentState`. | Low × Med | `RagPendingThink` tests `cent->currentValid` (`cg_local.h:94`, cleared for every old-snapshot entity at `cg_snapshot.c:229-232`) **first**, before anything else, and the 8000 ms give-up is a hard backstop. `CG_RagdollClearEnt` also sweeps pendings so the `EF_DEAD` falling edge reaches them. |

---

## 9. ROADMAP AFTER THIS BUILD

Ordered. Each item states the trigger that promotes it — **do not do any of these speculatively.**

| # | Work | Trigger |
|---|---|---|
| **R9-a** | **Feet as sim points 15/16** (`RAG_PTS` 17, `s_ragBones` += `Bip01 L/R Foot`, radii 3.5/3.5, re-point `s_ragAnchorTable:202-205` from 12/14 to 15/16, knee-fold braces `{11,15}`/`{13,16}` at ~0.75, `s_ragDriveChild[12] = 15`, `[14] = 16`). Ship **alone**; expect the mover pass to be starved more often (60 → 68 world traces/body). | User reports the shins/feet look detached, or the leg reads as one stiff bone from hip to foot — **or** F4 in §6.4. |
| **R9-b** | **Per-channel slaving rewrite** (`anchor[]`/`relPos[]`, `:560-612`). | **The redirect signature in §6.5.** This replaces R9-a as the round-9 content if it appears. |
| **R9-c** | **`CG_RagdollFrame` after `CG_AddPacketEntities`** (`cg_view.c:2928` → after `:3078`), with the freeze drill either side. | User reports corpses on an elevator or moving door lagging behind it. Zero value otherwise — the settle branch's bodies are `MOVETYPE_NONE`-parked. |
| **R9-d** | **Sleep gate 10 → 18 u/s** with the post-gravity jitter floor re-measured from this build's `maxspd=` data. | Only if this build's logs show bodies riding the 6000 ms life cap. |
| **R10-a** | **Post-death impulse** from `cg_parsemsg.cpp` bullet/explosion messages (`:1691-1730`, `:1851-1858`, `:2269`). Declare `CG_RagdollImpulse` inside `cg_local.h`'s `extern "C"` block (`:37-40`) or the C↔C++ link fails; **exclude `CGM_BULLET_5`** (`:1728` = `CG_MakeBubbleTrail`, underwater); the impulse **must** move `ptPrev` — correct here precisely because it is a real velocity change, the opposite of the shape-match case; set `s->branch = 0` on impact. | User says shooting a corpse should move it, **or** says deaths still feel "disconnected from the bullet". Only after §6 passes. |
| **R10-b** | **Corpse-vs-corpse point pushout** (own point AABB, radius push-apart, asymmetric with the sleeper as infinite mass; zero traces — corpses are `CONTENTS_WEAPONCLIP`, excluded from `MASK_DEADSOLID` at `bg_public.h:643`, so they interpenetrate freely today). | User reports bodies intersecting each other in doorways or on the beach. |
| **R10-c** | **`killed.scr` variety**: the `yaw > 135 && yaw < 225` bug at 7 sites (`AngleSubtract` caps at ±180, `q_math.c:1277`) plus the `(90,270)` site; `self setmotionanim (self.weapongroup + "_pain_kneestodeath")` for 1 clip → 3; `death_grenade_high` recovery. Mod-side `.scr`. | User says deaths look repetitive. **Never bundle with a physics build** — it changes what plays, which confounds every other verdict. |
| **R10-d** | **Blood pool at `BecomeCorpse`, not at `health<=0`** (`fgame/sentient.cpp:1796`, re-trace from the then-current centroid). `game.dll` ship, own build. Median 82.9 u = 1.58 m of measured displacement between the two moments. | Independent of everything above; do it whenever a `game.dll` build is going out anyway. Re-opens bugs 792/817/828 — read them first. |
| **R11** | Neck cone 77° → 55° (`s_ragBraceMinFactor[6]`, `:115`); props via `CM_TempBoxModel` (blocked on §3.7 landing); ledge topple behind `coop_ragdollTopple 0`; renderer slot bump (`tr_ragdoll.cpp:19`, **both** byte-identical copies, renderer-DLL ship); cull bounds from the already-written-but-never-read sim AABB (`tr_ragdoll.cpp:30`, `:87-88`). | Each only once bodies demonstrably go limp and travel — none of them changes anything while the corpse is essentially where the animator put it. |
| **R12** | Pelvis reaction in `RagShapeMatch` (today `pt[0]` is the anchor and takes no reaction, `:651`), which is why the settle is a rigid re-placement rather than a drape by construction (gap B2c). | Only if F2 persists after the full stiffness sweep — i.e. the body reads as placed even at `coop_ragdollStiff 0.10`. |

---

## 10. BUGLOG ENTRIES TO FILE WITH THIS BUILD

Per `.wolf/OPENWOLF.md`, append to `.wolf/buglog.json` when the build lands (schema fields only, no
prose sections):

- **The settle branch's handoff gate could capture the LIVING pose** — found independently by three
  lenses via three mechanisms (weight tie during the 0.3 s crossblend; looping anims always producing
  one server frame inside the 60 ms `animDone` window per cycle; no name gate below `age > 300`).
  `related_bugs: [bug-1962, bug-1963, bug-1964]`.
- **The `"death"` prefix gate dropped every crouch/knees death** (`*_pain_kneestodeath`, present in
  this mod's own `anim/killed.scr` and in `anim/pain.scr:392/400/408`).
- **World traces charged the mover trace budget** without ever checking it (`cg_ragdoll.c:806` vs
  `:850`), silently disabling mover collision from the third or fourth awake body.
- **`coop_ragdollMode 0` silently behaved as settle** (`:1422` tested `!= 3`).
- **Pending records held sim-pool slots and were unevictable** (`RagAllocSlot:1176-1181` evicts only
  `state == 2`).
- **`RagPush` drove each bone from its incoming segment instead of its outgoing one**, shearing the
  mesh at every joint — invisible to the `coop_ragdollTest 2` freeze drill because `S = I` there.
