# Ragdoll Plan v3 — Round-3 FINAL CONFIRMATION

**Audited:** `_research/ragdoll_plan.md` (v3) against (1) the 13-item "Consolidated fix list
for v3" in `ragdoll_vet2_completeness.md` and (2) every REQUIRED CHANGE in
`ragdoll_vet2_integration.md` (F1-F11), plus a fresh end-to-end contradiction sweep and two
code spot-checks against `openmohaa-hzm/code/` (this session, 2026-08-19). Tags were not
trusted: every [Cn]/[int Fn] claim was checked against the demand text, and the two most
load-bearing NEW claims were checked against the engine source.

## VERDICT: **PASS** — all 13 completeness items and all 11 integration items CLOSED, zero
new contradictions, both code spot-checks PASS. Implementation is green-lit.

> History: the first pass of this confirmation (earlier this session) returned FAIL on one
> item — integration F6 carried two textual residues ("on BOTH sides" eType qualifier; the
> HeadGib/Helmet never-EF_DEAD sentence). Both were added to §4 and re-verified against the
> amended text (and the eType-not-in-interpolate rationale re-checked against
> cg_snapshot.c:326-327). F6's updated verdict is below; everything else was already closed
> on the first pass and was not re-litigated.

---

## Matrix 1 — Completeness fix list (13 items)

### 1. Capture procedure paragraph — **CLOSED**
v3 §2: *"**Capture procedure [C1]:** build the capture refEntity from the same cent fields
CG_ModelAnim submits (tiki, CURRENT interpolated frameInfo, scale, entityNumber, origin/axis);
one `cgi.ForceUpdatePose` — **warning: this stamps tr.skel_index[entnum], so wrong frameInfo
poisons that frame's real render**; then per-channel `cgi.TIKI_Orientation`. Always the cent's
own tiki handle (TIKI_GetSkeletor caches only 2 skeletors per entnum, delete-on-evict). P2
acceptance: captured pose verified non-bind."* Every enumerated element present: refEntity
recipe, skel_index warning, per-channel orientation, own-tiki-handle + 2-cache note, P2
non-bind acceptance. (Code note: the skel_index stamp and the matching early-out are real —
tr_model.cpp:1757/1760/1780.)

### 2. Timestep (cap 4 + min-fps statement + slow-mo claim re-scoped) — **CLOSED**
v3 §3: *"`accumMs += min(cg.frametime, 200); while (accumMs >= 8 && steps < 4) step(8ms);
accumMs = min(accumMs, 32)` — discard excess after stepping."* 8ms x cap 4 = 32ms ⇒ floor
1000/32 = 31.25 fps. v3 §1: *"supported minimum framerate ~31 fps — below that, corpse motion
slows; above it, never [C2]"* — the min-fps statement delivered and the false v2 claim
re-scoped exactly as the fix list's second option allowed. Arithmetic self-consistent.

### 3. Arm-rate bounding — **CLOSED**
v3 §4: *"**Arm-rate bound [C3]: max 4 arms/frame; the remainder queue for 1-2 frames (capture
cost stays bounded on horde grenades); r_ragdollDebug counts `arms refused` and `arms
queued`.**"* Cap, queue window, and BOTH counters — verbatim to the demand.

### 4. Trace mask — **CLOSED**
v3 §3: *"world-only `CG_Trace(..., cliptoentities = qfalse)` with a **MASK_SOLID-class content
mask**, 2u box"*.

### 5. gl2 stubs — **CLOSED**
v3 §5: *"**gl2 ships stub exports that no-op** (belt) AND cgame NULL-checks anyway (braces)
[C5]"*. The reviewer's both-belts demand, not the deviation-note fallback.

### 6. Shadow quirk rewrite — **CLOSED** (note)
v3 §5: *"Corpse shadow DECAL plants at model->origin and does not follow the body (cg_shadows
default 0; the shipped Phase-A decal never reads tags) [C6 — corrected wording]"*. The
inversion is gone; the quirk now states the code-verified truth, so the P4 tester will not
hunt a phantom Hook B bug. Note (non-blocking): New-Defect 2's optional tail ("only
cg_shadows 2 precise foot shadows follow via Hook B") is not restated in the quirk line; §0's
RE_TIKI_IsOnGround / RF_SHADOW-window bullet covers the foot-shadow path.

### 7. Body-queue guard (clientNum reject) — **CLOSED**
v3 §4: *"**reject any ET_MODELANIM corpse carrying a valid s.clientNum** (player body-queue
corpses are born ET_MODELANIM+EF_DEAD and must never arm) [C7]"*. This is the discriminator
both round-1 reviewers named; v2's New-Defect 3 is resolved.

### 8. CL_TraceDeep ledger line — **CLOSED**
v3 §5: *"`CL_TraceDeep` is a latent client-side LBD consumer that reads the skeletor, not the
table; cross-comment both sites referencing the ragdoll table as insurance [C8]"*. Ledger
entry + the cross-comment insurance, as demanded.

### 9. Cvar flags paragraph — **CLOSED**
v3 §5: *"**Cvar discipline [C9]:** `r_ragdollDebug` is never CVAR_ARCHIVE (CVAR_TEMP, not
CVAR_CHEAT); before the P5 default flip, `coop_ragdoll` gets pre-registered in G_InitGame (the
T7 / bug-1669 getcvar trap)"* and §6 P5: *"pre-register cvar; tune; only then default-on"*.
All three STAB-F10 hazards covered, and the P5 sequencing walks around the trap.

### 10. First-seen-dead statement — **CLOSED**
v3 §4: *"Corpses FIRST SEEN with EF_DEAD already set (off-screen deaths, late join,
post-restart) never arm — they keep the anim pose; accepted [C10]"*.

### 11. T4 bounds-check line — **CLOSED**
v3 §2: *"Every entnum index into any ragdoll array is bounds-checked against MAX_GENTITIES,
gore-precedent style [C11]"*. The symbolic constant is named; the demand's substance.

### 12. "~112" correction + pool-overflow tolerance — **CLOSED** (note)
v3 §2: *"channel count (per-model, bounded by the engine-real per-SKD `TIKI_MAX_BONES 100`
[C12] — asserted at capture)"* — the phantom ~112 is gone and the cited constant is real and
correctly labeled (verified: `#define TIKI_MAX_BONES 100`, tiki_shared.h:76). Tolerance line:
*"Rows tolerate being pushed but never consumed (cull-out, bone-pool overflow skipping the
model) — no consumption asserts [C12]"* — exactly the STAB-F9 rule. Note (non-blocking): a
per-SKD cap does not mathematically bound the per-model UNION channel list (the thing
`TIKI_GetNumChannels` returns and the slot arrays must hold) — the completeness auditor's own
parenthetical said as much and still prescribed exactly this citation, and the capture assert
+ P0 ceiling script make any excess fail loud at dev time. Recommend (at implementation, not
a plan re-spin): the §6 P0 "channel-count ceiling script over the skd roster" should measure
`TIKI_GetNumChannels` per TIK (the union), not per-skd bone counts.

### 13. Minor trio — **CLOSED**
(a) caller-gating clause: v3 §0 *"the skeletor layer offers no caller gating — there is no way
to distinguish a render read from a server read at that level [C13]. Copy this rationale to
docs/DECISIONS.md at ship"*. (b) v3 §2: *"always against the **current frame's** entity
placement, never the death-frame transform [C13]"*. (c) v3 §2: *"`MAX_RAGDOLLS(8)` slots
(constant, not cvar — intentional change from v1 [C13])"*. All three present.

**Matrix 1 result: 13/13 CLOSED.**

---

## Matrix 2 — Integration REQUIRED CHANGEs (F1-F11)

### F1 (helmet = surface, Hook A; retarget P4) — **CLOSED**
v3 §0: *"the WORN helmet is a model SURFACE and rides the head via **Hook A**; the neck stump,
dangling eyeball, wound props, drip emitter, decap chunks-on-head and holstered
weapons-on-back ride via **Hook B**"*; §6 (v): *"worn helmet surface rides the head (Hook A),
stump/eyeball/props ride Hook B"*. Attribution and P4 wording both fixed.

### F2 (post-death decap/helmet-pop server-pose quirk) — **CLOSED**
v3 §5: *"Post-death decap/helmet-pop chunks spawn at the SERVER pose; offset bounded by
ragdoll drift [int F2]"*; measured by §6 (vii).

### F3 (blood-pool quirk + unified 48u drift bound) — **CLOSED**
v3 §5: *"The growing blood pool is a world decal at the server-pose floor point; strands with
drift [int F3]"* plus *"**Unifying drift bound: r_ragdollDebug logs settle distance from
server origin per corpse; if the MEDIAN settle exceeds ~48u (a body half-length), retune
seed/damping before P5 — pools, aim-at-corpse and gib spawn coherence all degrade with
drift** [int F3]"*. Ledger entry + acceptance metric, verbatim to the demand.

### F4 (post-death damage expected, must not clear + test) — **CLOSED**
v3 §4: *"**Post-death damage events are EXPECTED on armed corpses and must not clear** —
corpses are shootable and re-fire the whole gore block (decap included) after death [int F4]"*;
§6 (ii) is the demanded gore drill (*"nothing clears, chunks within drift bound"*).

### F5 (DBNO confirmation) — no change was required; v3 consistent (players never ragdoll, §1).

### F6 (arm guard vs body-queue/ghosts) — **CLOSED** (on re-confirm after the §4 amendment)
All components of the REQUIRED CHANGE are now present in §4:
- eType, both sides: *"`eType == ET_MODELANIM` **on BOTH currentState and nextState** (an
  eType change does NOT clear `interpolate` — verified cg_snapshot.c:326-327 — so the
  interpolate clause alone cannot cover a same-slot eType swap) [int F6]"* — the demanded
  qualifier, with a rationale that matches this session's code verification exactly (eType is
  absent from the interpolate condition; see spot-check b).
- EF_DEAD rising between currentState and nextState — present.
- *"`cent->interpolate == qtrue` at that transition (the engine's own continuity test — false
  on snapshot absence, EF_TELEPORT_BIT flip, parent change, modelindex change,
  cg_snapshot.c:326-335) [int F6]"* — code-accurate (spot-check b).
- `entityNumber >= cgs.maxclients` + the [C7] clientNum reject — present.
- Out-of-PVS documentation sentence — present [C10].
- The "state that too" sentence: *"HeadGibObject/HelmetObject props never carry EF_DEAD
  (verified: zero EF_DEAD writes in fgame/object.cpp), so gib/helmet entities were never at
  risk of arming [int F6]."* — present, and re-verified true this session (zero `EF_DEAD`
  occurrences in fgame/object.cpp).

The first pass of this confirmation flagged the two now-delivered items as F6's only
residues; the amendment introduces no side effects — the clear/re-arm signal list, eviction
ladder, and arm-rate bound in §4 are untouched, and the new parenthetical rationales are
consistent with the verified engine code.

### F7 (Hook A idempotency contract a-d + mirror test) — **CLOSED** (notes)
(a) verbatim: v3 §0 *"outside the cull-gated copy `if` (between tr_model.cpp:845 and :847) —
for flagged ents it writes ALL channels unconditionally, so a skipped vanilla copy can never
leak stale pool garbage"* — and code-verified real (spot-check a). (b) verbatim: *"Hook A is a
**pure reader** of the table: no edge latches, no counters, no capture-on-first-call — with N
fills per frame (mirrors, portals, wrap-frames) all state transitions live in cgame's push"*.
(c) delivered as the implementable contract rather than the rationale: *"Hook A also copies
`newFrame->bones` into the slot's anim-pose block each fill"* — the per-fill copy is
prescribed (the latch bug is thereby impossible); the why (R_UpdatePoseInternal early-out,
tr_model.cpp:1757 — verified real) is not restated. Acceptable. (d) delivered as outcome +
gating test rather than the two named sites: §5 *"flagged ents render CULL_IN within [the sim
AABB]"* + §6 P1-a (*"aim the camera so the server pose is off-frustum — body must render
(culling override) with no garbage"*). Code-verified this is functionally sufficient:
`iRadiusCull` has NO consumer after the line-824 gate (only 747/777/779/792/824), sphere
CULL_OUT short-circuits the gate TRUE (the copy still runs), so the only in-function garbage
path is CULL_CLIP + OBB CULL_OUT — which Hook A's unconditional write cures regardless of the
cull override; any body-vanish risk lives outside R_AddSkelSurfaces and is exactly what P1-a
arbitrates. Mirror test present: §6 (i).

### F8 (velocity seed post-edge + P0 re-word + RF_SHADOW note) — **CLOSED**
v3 §3: *"arm on the EF_DEAD edge, **hold the sim one snapshot, then difference the first 1-2
post-edge snapshot origins forward** — the death impulse lands the same server frame and moves
the origin only on FOLLOWING snapshots; differencing at the edge seeds ~zero on stationary
kills"*. §6 P0: *"seed-vs-server-kick comparison specifically on **stationary-target grenade
kills**"* [P0-b]. RF_SHADOW: §0 *"RF_SHADOW stays on until BecomeCorpse — the foot-shadow
window is exactly the guard window"* (wording note: "guard window" is an undefined term —
read "the death-edge→BecomeCorpse window, i.e. the first seconds of the sim"; fact stated).

### F9 (table persists while frametime==0; lifetime owned by §4) — **CLOSED**
v3 §3: *"the TABLE persists and Hook A keeps applying the last push while paused/hitching
(table lifetime belongs to §4 lifecycle, never the stepper) [int F9]"*. Verbatim.

### F10 (drop animMat[]; Hook A is the one producer) — **CLOSED**
v3 §0: *"Hook A also copies `newFrame->bones` into the slot's anim-pose block each fill — that
is the ONE producer of the anim-pose matrices the gore remap consumes; the bridge does NOT
carry an animMat[] parameter (cgame has no GetFrame export …) [int F10]"*; §5 bridge signature
is `R_SetRagdollPose(entnum, tiki, count, mat[], aabb)` — animMat[] gone. The v2
self-contradiction is resolved on the only implementable side. (Typo: "uncimplementable".)

### F11 (acceptance items) — **CLOSED**
P0-a retired as confirmed (§3: *"cg_predict.c:87 — signature confirmed [P0-a done]"*); P0-b in
§6 P0; P1-a drift-cull drill in §6 P1; §6 P3/P4 carries (i) mirror/portal, (ii) post-death
gore, (iii) player-Body-never-ragdolls, (iv) coop_corpseLife 5 fade, (v) helmet Hook-A/Hook-B
split (the F1 re-word), (vi) timescale/pause, (vii) drift median < 48u, (viii) balcony death.
All eight plus both P-early items present. (Minor: F11-iii's "consumes no slot
(r_ragdollDebug slot dump)" detail is compressed to "player Body never ragdolls" — the slot
dump is the natural way to verify it and r_ragdollDebug exists in §4; not blocking.)

**Matrix 2 result: 11/11 CLOSED (F5 needed nothing; F6 closed on re-confirm after the §4
amendment).**

---

## Contradiction sweep (v3 end-to-end) — **zero new contradictions**

Checked pairings, all consistent:
- §1 min-fps ~31 vs §3 arithmetic (8ms x 4 = 32ms ⇒ 31.25 fps floor; steady-state 30fps runs
  ≈96% speed, i.e. "below ~31, slows" is honest).
- §4 first-seen-dead-never-arm [C10] vs the [int F6] interpolate clause (absence ⇒
  interpolate false ⇒ no arm) — the two rules produce the same outcome.
- §0 Hook A "writes ALL channels unconditionally" vs §2 "rows pushed but never consumed" — not
  a conflict: the tolerance covers frames where the fill path never executes (bone-pool
  overflow early-return at tr_model.cpp:765-768; genuine off-screen cull of the sim AABB
  itself), while the unconditional write covers every executed fill. They dovetail.
- §5 bridge params (entnum, tiki, count, mat[], aabb) vs §2 slot contents — every slot field
  arrives via the bridge except the anim-pose block (Hook-A-owned, §0) and lifecycle state
  (cgame-side, §4). Coherent split; gl2 stubs make the renderer table absent ⇒ feature dark,
  consistent with §1 "gl1 first".
- §4 arm-rate queue (1-2 frames) vs §2 capture ("CURRENT interpolated frameInfo") vs §3 seed
  ("hold one snapshot, difference forward") — queued arms capture late with current fields and
  seed from post-edge origins; no ordering impossibility.
- §4 eviction ladder vs arm queue vs "arms refused" counter — consistent.
- vid_restart snap-back (§5) vs [C10] — same accepted class.

Non-blocking NOTES for the implementer (no plan re-spin required):
- **N1 (from item 12):** "per-model … bounded by the engine-real per-SKD TIKI_MAX_BONES 100"
  is loose — the per-SKD cap does not bound the union channel list. Backstopped by the capture
  assert + P0 script; make the P0 script measure `TIKI_GetNumChannels` per TIK.
- **N2:** §0 "the foot-shadow window is exactly the guard window" — "guard window" undefined;
  intended meaning is the death-edge→BecomeCorpse window.
- **N3:** typo "uncimplementable" (§0).

---

## Code spot-checks (both PASS)

### (a) Hook A between tr_model.cpp:845 and :847 — **REAL AND COHERENT**
`openmohaa-hzm/code/renderergl1/tr_model.cpp`, verified this session:
- :824-825 — the cull-gated copy `if`: `if (lod_tool->integer || iRadiusCull != CULL_CLIP ||
  R_CullSkelModel(tiki, &ent->e, newFrame, tiki_scale, tiki_localorigin) != CULL_OUT) {`
- :829-844 — the bone copy loop (`newFrame->bones[i]` → `outbones`)
- :845 — `}` closing the gated if; :846 — blank; :847 — `ri.Hunk_FreeTempMemory(newFrame);`

"Between :845 and :847" is therefore a real single insertion point (line 846), outside the
gate — and it is the *uniquely* correct spot: `newFrame` is still alive there (freed at :847),
which the [int F10] anim-pose copy requires; the pool block base is recoverable
(`TIKI_Skel_Bones_Index` is not advanced until :850, `outbones`' base set at :761);
`num_tags`, `tiki`, and `ent->e.entityNumber` are all in scope. The hazard the hook cures is
also confirmed: `ent->e.bonestart` is assigned and the pool index advanced at :849-850
UNCONDITIONALLY, and the mesh/surface loop (:910+) never consults `iRadiusCull` — so a skipped
copy really does draw surfaces over stale pool garbage, and an unconditional write at :846
really does cure it. Additional precision: sphere CULL_OUT at :777 short-circuits the :824
gate TRUE (copy runs); the skip path is exactly `CULL_CLIP` + OBB `CULL_OUT` — the case the
plan names.

### (b) cent->interpolate semantics at cg_snapshot.c:326-335 — **MATCHES §4**
`openmohaa-hzm/code/cgame/cg_snapshot.c` (in `CG_SetNextSnap`), :326-336:
`if (!cent->currentValid || ((cent->currentState.eFlags ^ es->eFlags) & EF_TELEPORT_BIT) ||
(cent->currentState.parent != es->parent) || (cent->currentState.modelindex != es->modelindex))
{ cent->interpolate = qfalse; … } else { cent->interpolate = qtrue; }` — i.e. false on
snapshot absence (`!currentValid`, per the :324-325 comment "the entity wasn't in the previous
frame"), EF_TELEPORT_BIT flip, parent change, modelindex change; true otherwise. Exactly the
four conditions §4 claims, at exactly the cited lines. **Extra finding feeding F6:** eType is
NOT part of this condition — an eType change alone does not clear `interpolate`, which is why
F6's "on BOTH sides" qualifier is belt the interpolate clause cannot substitute for.

(Also verified in passing: `RE_TIKI_Orientation` at tr_model.cpp:1797 — §0's Hook B cite is
exact; `R_UpdatePoseInternal` early-out at :1757 and skel_index stamps at :1760/:1780 — §2's
capture warning and F7(c)'s stability rationale are real; `TIKI_MAX_BONES 100` at
tiki_shared.h:76.)

---

## Final disposition

The first pass demanded two clauses in §4 (the "on BOTH sides" eType qualifier; the
HeadGib/Helmet never-EF_DEAD sentence). Both were added and re-verified against the amended
§4 text this session. With that, the tallies are: **completeness 13/13 CLOSED, integration
11/11 CLOSED, zero new contradictions, both code spot-checks PASS.**

**Verdict: PASS. Implementation of ragdoll_plan.md v3 is green-lit.**

Non-blocking notes carried forward for the implementer (no plan re-spin required): N1 — make
the P0 channel-count ceiling script measure `TIKI_GetNumChannels` per TIK (the union), not
per-skd bone counts, since the per-SKD `TIKI_MAX_BONES 100` does not mathematically bound the
union (the capture assert backstops either way); N2 — read §0's "guard window" as the
death-edge→BecomeCorpse window; N3 — typo "uncimplementable" in §0.
