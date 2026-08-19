# Ragdoll Plan v2 — Round-2 Vetting: COMPLETENESS AUDIT

**Audited:** `_research/ragdoll_plan.md` (v2) against every numbered finding in
`ragdoll_vet1_architecture.md` (F1-F13), `ragdoll_vet1_stability.md` (F1-F10),
`ragdoll_vet1_facts.md` (1-11). 34 findings total. Disputed points re-verified against
`openmohaa-hzm/code/` this session (2026-08-19). Verdict bar: the v2 text must contain the
**specific mechanism** the reviewer demanded, not a gesture at it.

**Note on the v1-regression check:** v1 is not on disk and has no git history
(`git log --follow -- _research/ragdoll_plan.md` is empty — the file was never committed
pre-rewrite). The "lost from v1" audit below therefore works from v1 content as quoted in the
three reviews' CLAIM lines, which is the only surviving record. Every "unchanged from v1"
phrase in v2 is unverifiable against the original; fortunately v2 restates the values it
claims are unchanged (15/14/6/6 sim, sleep rules, failure ladder), so nothing is dangling.

## Bottom line

| Verdict | Count | IDs |
|---|---|---|
| ADDRESSED | 20 | ARCH F1 F2 F3 F4 F7 F8 F9 F11 F12 F13; STAB F2 F7; FACTS 1 4 5 6 8 9 10 11 |
| PARTIALLY | 12 | ARCH F5 F10; STAB F1 F3 F4 F5 F6 F8 F9; FACTS 2 3 7 |
| DROPPED | 2 | ARCH F6; STAB F10 |

**v2's own status line ("all 15 blocking findings are folded in") is overstated.** Of the 15
round-1 blocking findings, 11 are fully folded in; **4 are only partial: STAB-F1 (content
mask unnamed), STAB-F3 (substep budget fails the demanded 30fps min spec + false no-slow-mo
claim), STAB-F4 (per-frame arm cap + refused counter missing), STAB-F6 (gl2 stubs explicitly
declined against the reviewer's both-belts demand).**

The single largest hole is a **cluster**: the capture-procedure traps that three reviewers
independently demanded (ARCH-F10 trap 1, STAB-F8 caveats a+b, FACTS-2 recipe) appear nowhere
in v2 — the plan never says how capture builds its refEntity, and the frameInfo/skel_index
trap is the #1 way capture silently produces a bind pose AND corrupts that frame's real
render.

---

## Matrix 1 — Architecture review (ragdoll_vet1_architecture.md)

### ARCH-F1 (confirmed+qualifications) — hook site exact, per-view, keyed by entnum — **ADDRESSED**
Required: name the hook exactly (inside `R_AddSkelSurfaces` immediately after the copy loop,
tr_model.cpp:844), run on EVERY fill, keyed by `ent->e.entityNumber`; no out-of-function table
application.
v2 §0: *"Hook A site (exact): inside `R_AddSkelSurfaces`, immediately after the bone-cache
copy loop (tr_model.cpp:844), keyed by `ent->e.entityNumber`, running on EVERY fill (the pool
is per-view, recycled per scene — never 'apply once')."* Verbatim match. §7 additionally
carries per-view idempotence into the round-2 brief.

### ARCH-F2 (WRONG/blocking) — cull gate: pop-out + garbage skinning — **ADDRESSED**
Required: force CULL_IN for flagged entnums + sim-derived bound (pushed AABB or inflated
radius), as a P1/P2 acceptance item.
v2 §5: *"Hook A also overrides culling for flagged entities: cgame pushes the sim AABB with
the matrices; the renderer treats flagged ents as CULL_IN within that AABB … P1 acceptance
item."* §2 slot carries the "sim AABB" field; §6 P1: *"culling override verified by walking
away/back."* Chose the reviewer's first (better) option.

### ARCH-F3 (WRONG/blocking) — matrix space — **ADDRESSED**
Required: store skeletor-space (model-local, unscaled) 3x4s; convert world→local each push
with the exact formula; Hook A writes raw, Hook B applies tiki_tag.cpp:108-111; record the
pin-the-refEntity alternative and pick one.
v2 §2: stores *"skeletor-space (model-local, unscaled) 3x4s — exactly what
`skeletor_c::GetFrame` emits"*; formula reproduced character-for-character
(`local_pos = (transpose(ent.axis) * (world_pos - ent.origin)) / (ent.scale * tiki->load_scale) - tiki->load_origin`);
*"Hook A writes raw; Hook B applies the tiki_tag.cpp:108-111 formula"*; alternative recorded
and rejected: *"(no pinning — rejected: pinning breaks PVS/culling assumptions elsewhere)."*

### ARCH-F4 (WRONG/blocking) — partial override tears the mesh — **ADDRESSED** (one number wrong, see New-Defect 4)
Required: override EVERY channel; slave non-simmed bones via
`rel_b = inv(M_anchor_capture) * M_b_capture`, emit `M_b = M_anchor_sim * rel_b`; hardcoded
Bip01 anchors + nearest-capture heuristic; state the one index space; 8 slots x full skeleton
not MAX_GENTITIES x 24.
v2 §2 has all of it, including the exact slaving equations, the anchor policy, the honest
"cgi exposes no bone-parent API — accepted; no new export in v1", the *"One index space
everywhere: tiki bone-list channel indices"* paragraph, and the slotted 8 x full-skeleton
shape. Only blemish: the slot is sized to *"an asserted engine cap ~112"* — no such engine
constant exists (see New-Defect 4); the P0 roster scan + capture assert keep it safe.

### ARCH-F5 (confirmed) — Hook B written down; hedge removed; shadow-decal quirk — **PARTIALLY**
Required: (1) write Hook B as a patch to `RE_TIKI_Orientation` (tr_model.cpp:1797), (2) remove
the "or is there another consumer" hedge, (3) add the shadow-decal note to §5 quirks — the
note being that the DEFAULT Phase-A directional decal does NOT follow (plants at
`model->origin`), only the off-by-default `cg_shadows 2` precise path follows.
v2 delivers (1) and (2) — §0: *"patch `RE_TIKI_Orientation` (tr_model.cpp:1797) — the single
funnel for all client tag consumers."* But (3) is recorded **inverted**: §5 quirk says
*"shadow decals follow feet via Hook B (verify at P4)"*. Code re-verified this session: the
Phase-A decal (`coop_shadowDir` default "1", cg_modelanim.c:711-763) traces straight down from
`model->origin` (`cgi.CM_BoxTrace`, :740-742) and never reads a tag — Hook B cannot move it;
only `cg_shadows 2` + RF_SHADOW_PRECISE (:766-788, feet via `cgi.TIKI_Orientation` at
:450/:599/:612) rides Hook B, and `cg_shadows` defaults "0". Under the mod's shipped defaults
the shadow decal stays parked at the server corpse origin. See New-Defect 2.

### ARCH-F6 (RISK) — CL_TraceDeep latent client LBD consumer — **DROPPED**
Required: *"Record it"* + cheap insurance (shared helper with a "render" flag, or
cross-referencing comments at both sites).
v2 mentions `cm_trace_lbd.cpp:486` only as the server-side rationale for F7 (§0). CL_TraceDeep
(cm_trace_lbd.cpp:533-591, `re.TIKI_Orientation` at :578, currently zero callers) appears
nowhere. Risk is live precisely because hitmarker work makes wiring client hit prediction
plausible — Hook B would then silently make client corpse traces follow the ragdoll while the
server hits the anim pose.

### ARCH-F7 (resolves Q1) — renderer-side committed, rationale recorded — **ADDRESSED** (minor note)
Required: commit to renderer-side Hook A+B; record the rejection rationale (listen-host server
contamination; no caller gating at the skeletor layer) in plan/DECISIONS.
v2 §0 bullet 1: full commit, the listen-host contamination evidence chain (tiki_cache.cpp:305,
g_main.cpp:904/915, cm_trace_lbd.cpp:486), *"Recorded here + to be copied to docs/DECISIONS.md
at ship so a later session doesn't 'simplify' it back."* Minor: the second rationale clause
("the layer has no caller identity to gate on") is not recorded — worth one added phrase when
the DECISIONS entry is written, since caller-gating is what also rules out the exe-level
TIKI_*Internal funnels.

### ARCH-F8 (risk needing owned decision) — gore stamp regression — **ADDRESSED**
Required: pick one of (a) accept / (b) honest remap via stored anim-pose matrices + nearest
bone anim→sim delta / (c) raised tolerances.
v2 §0: *"v1 decision: (b) honest remap — Hook A keeps a copy of the anim-pose matrices for
flagged entities; the gore funnel remaps the segment end by the nearest bone's anim→sim
delta."* §2 slot stores the anim-pose copy; §5 quirk cites the F8 remap; §6 P4 spot-checks it.
Exactly the mechanism demanded.

### ARCH-F9 (WRONG premise/blocking) — no spawn serial; signal set instead — **ADDRESSED**
Required: replace "spawn counter/serial" with: EF_DEAD falling edge; EF_TELEPORT_BIT toggle;
modelindex change; eType change; absent-then-re-present. Belt: store `dtiki_t*` in the row,
ignore on mismatch.
v2 §4: all five signals present (plus parent change from STAB-F7); belt present twice (§2 slot
*"row ignored when it mismatches `ent->e.tiki`"*, §4 *"Renderer belt"*). Note: v2 gates the
absent→re-present clear on a >64u origin discontinuity rather than clearing unconditionally —
this follows STAB-F7's more-correct refinement (ragdolls must SURVIVE plain PVS re-entry, per
the gore invariant at cg_snapshot.c:115-126) and still closes ARCH-F9's reuse hole via the
discontinuity test + tiki belt. Correct resolution of a real inter-reviewer tension — round 3
should not "fix" this back to unconditional clearing.

### ARCH-F10 (confirmed + two traps) — capture traps and filter explicitness — **PARTIALLY**
Required: add BOTH traps to §3/§6: (1) the capture refEntity MUST carry the corpse's current
interpolated `cent->currentState.frameInfo` — a zeroed refEntity captures a bind/stale pose
AND the stamped skel_index guard makes the real render reuse it that frame; (2) death-edge at
`CG_TransitionEntity` (gore template) with the actor filter made explicit (`eType ==
ET_MODELANIM` + tiki `bIsCharacter` + reject `s.clientNum` in [0, MAX_CLIENTS) — "the filter
must mean s.clientNum, not entityNumber"). Mark the P0 sub-questions resolved.
v2 has trap (2)'s edge point (§4: *"Edge detection mirrors the gore template at
`CG_TransitionEntity` (cg_snapshot.c:113-136)"*) and marks the P0 unknowns resolved (§0).
Missing: **trap (1) entirely** — "frameInfo" appears nowhere in v2; no sentence anywhere
describes how the capture refEntity is built. Missing: the `s.clientNum` explicitness (v2's
guard uses `entityNumber >= cgs.maxclients`, which FACTS-7 endorsed for live players, but the
clientNum discriminator both reviewers named for body-queue corpses is absent — see FACTS-7)
and the `bIsCharacter` gate.

### ARCH-F11 (RISK) — velocity source — **ADDRESSED**
Required: P0 task to log; fallback = post-death origin deltas or damage-direction
reconstruction / explicit ship.
v2 §3: differencing seed spec'd; *"P0 logging task confirms magnitude quality on grenade
kills; fallback = a tiny server->client event carrying the impulse (only if differencing
proves too coarse — decide at P2 exit)"*; §6 P0 first bullet is the logging task, P2 exit
carries the verdict. (FACTS-11's "optionally averaged over 2 snaps" refinement is subsumed by
the P0/P2 empirical gate.)

### ARCH-F12 (WRONG as stated) — mover clip claim — **ADDRESSED**
Required: either cliptoentities=qtrue (with budget + self-skip) or the truthful
fall-through-accepted quirk.
v2 does the third (better) thing both reviewers converged on: STAB-F1's bmodel candidate path
(§3), which clips movers honestly. Quirk rewritten truthfully (§5: *"corpses on moving
platforms may lag one frame behind the mover"*); §6 P3 tests the m2l2a lift. The self-skip
requirement is satisfied structurally: only SOLID_BMODEL candidates are clipped
(`CG_GetBrushEntitiesInBounds` filters `currentState.solid != SOLID_BMODEL`, cg_predict.c:98 —
re-verified), so the corpse's own entity and other corpses can never be in the clip list, and
§3 says *"Never clip against bbox entities (actors/players/other corpses)."*

### ARCH-F13 (confirmed) — LOD — **ADDRESSED**
No change required. v2 §0 records it (*"LOD cannot break indexing (vertex collapse only;
r_uselod 0 default)"*) and retires it from P0 (*"These leave the P0 unknowns list"*); the §6
P0 list indeed contains no LOD item.

---

## Matrix 2 — Stability review (ragdoll_vet1_stability.md)

### STAB-F1 (BLOCKING) — collision spec — **PARTIALLY**
Required: world-only `CG_Trace(cliptoentities=qfalse)`; ONE `CG_GetBrushEntitiesInBounds` per
body per frame over the inflated AABB; clip points only against that candidate list; never
bbox entities; **"Name the content mask explicitly (MASK_SOLID-class)"**; rewrite the §5
elevator paragraph.
v2 §3 delivers the architecture verbatim (world-only, *"NEVER the entity-clip loop (24k
traces/frame on a horde …)"*, one bounds query per body per frame, 0-4 bmodel candidates,
never bbox entities) and the contradictory v1 elevator sentence is gone (replaced by the §5
mover-lag quirk + P3 lift test). **Missing: the content mask.** The word "MASK" does not
appear in v2; the trace spec names box size, clip class, and ceiling but not the mask — the
one enumerated deliverable left out.

### STAB-F2 (confirmed) — 240 world-only traces affordable — **ADDRESSED**
No change required; v2 keeps the 240/frame ceiling under the world-only regime the
confirmation was conditioned on. Consistent.

### STAB-F3 (BLOCKING) — timestep clamp + steady-state slow motion — **PARTIALLY** (and a new false claim)
Required: (1) the exact clamp (`if (cg.frametime <= 0) return; accumMs += min(cg.frametime,
200); step while (accumMs >= SUBSTEP_MS && steps < MAX_STEPS); accumMs = min(accumMs,
SUBSTEP_MS*MAX_STEPS)`); (2) a substep budget covering the real min spec — the reviewer's two
allowed configs (60 Hz cap 2, or 120 Hz cap 4) both cover 30fps (33.3ms/frame); (3) **"State
the supported minimum fps in the plan."**
v2 §3 delivers (1) exactly. It fails (2) and (3): v2 chose **8ms x cap 3 = 24ms max simulated
per rendered frame**, which is correct-speed only down to 1000/24 ≈ **41.7 fps**. At 30fps —
which the reviewer explicitly said 80-AI horde frames WILL hit — corpses run at 72% speed,
permanently (the discard clamp fixes the hitch backlog, not the steady-state deficit; the two
pathologies were separately documented in the finding). No supported-minimum-fps statement
exists. Worse, v2 appends *"never slow-mo on low-fps clients"* — arithmetically false below
~42fps under its own numbers. See New-Defect 1. Fix is one token: cap 3 → cap 4 (32ms ≈
31fps floor), or 16.67ms x 2, plus the min-fps sentence.

### STAB-F4 (BLOCKING) — eviction statues + arm-rate bounding — **PARTIALLY**
Required: (1) steal priority mirroring R_GoreAcquireInstance (free, else asleep
prefer-out-of-PVS, else DO NOT ARM; never evict an awake sim); (2) **cap arms per frame (e.g.
4) and queue the remainder 1-2 frames**; (3) **an "arms refused" counter in r_ragdollDebug**.
v2 §4 delivers (1) completely, with the bug-856 shape named: *"new death takes (a) a free
slot, else (b) an ASLEEP slot (prefer out-of-PVS). If none: the new death does NOT arm …
Never evict an awake sim."* **Missing: (2) and (3) entirely.** Nothing in v2 bounds
arms-per-frame — a 12-kill grenade still performs 12 captures (12 ForceUpdatePose + ~12x112
orientation reads) in one frame; the reviewer sized that spike and demanded it bounded by
design. §6 P3's *"budget + eviction"* test observes slots, not arm rate, and no refused
counter is specified anywhere (the finding's T14 point: absence does not log).

### STAB-F5 (should-fix) — table shape + sizing + T4 — **PARTIALLY**
Required: slotted payload + `byte slotPlusOne[MAX_GENTITIES]` index; per-slot matrices sized
to full channel count bounded by an **engine-real** cap asserted at capture; fill every
channel; **keep every entnum index bounds-checked against MAX_GENTITIES symbolically (T4)**.
v2 §2 delivers the shape verbatim (gore's shape, 8 slots, byte index, full channels, capture
assert, the 2.45 MiB arithmetic). Two gaps: (a) the cap is stated as *"an asserted engine cap
~112"* — not an engine constant (see New-Defect 4; the engine-real numbers are
`TIKI_MAX_BONES 100` per skd, tiki_shared.h:76, loader-enforced at tiki_skel.cpp:632/926 — a
per-SKD cap, not a union-channel-list cap — and the 128 static-model bone array the facts
reviewer offered); (b) the **T4 symbolic bounds-check requirement is unstated** — no line in
v2 requires Hook A/B/bridge writes to bounds-check entnum against MAX_GENTITIES by name. In
this codebase that omission is a documented repeat-bug family (skel_index[1024]: bug-932b,
gl2 twin, bug-935), which is exactly why the reviewer spelled it out.

### STAB-F6 (BLOCKING) — gl2 NULL bridge, vid_restart, clear sites — **PARTIALLY**
Required: NULL-check every bridge pointer **AND provide gl2 stub exports (both)**; ClearAll at
CG_ServerRestarted + CG_Init; state post-vid_restart snap-back in §5.
v2 §5 delivers three of four: NULL-checks with the gore precedent cited; *"`R_ClearAllRagdolls`
called at CG_Init and CG_ServerRestarted"*; the vid_restart paragraph (cgame+renderer die
together, cl_main.cpp:1624, snap-back accepted + documented, display-selector reachability
noted). **Missing: gl2 stubs — explicitly declined** (*"gl2 provides none in v1"*). The
reviewer demanded both belts with a stated reason ("a stub protects future callers, the NULL
check protects against a renderer that predates the export"). If v2 keeps the
NULL-check-only stance it must at minimum record WHY it is safe (refexport_t handed to cgame
zero-initialized ⇒ unfilled slots are reliably NULL) as a deliberate deviation — right now the
deviation is silent, which is how round-1 findings get relitigated.

### STAB-F7 (BLOCKING) — PVS exit/re-entry, clientFlags, reuse hole — **ADDRESSED**
Required: (1) state in cg_ragdoll.c's own array, never clientFlags; (2) full clear edge set
incl. parent change; (3) origin-discontinuity (~64u) clear on re-entry of an armed entnum.
v2 §4 delivers all three verbatim: *"All ragdoll state lives in cg_ragdoll.c's own array —
never centity clientFlags (zeroed on PVS re-entry, cg_snapshot.c:65)"*; the signal list
includes *"parent change (mirror cg_snapshot.c:326)"*; and *"entity absent from snapshot then
re-present WITH origin discontinuity (>64u) — the corpse->corpse slot reuse hole."*

### STAB-F8 (design-confirm) — Hook B mandatory + two capture caveats — **PARTIALLY**
Required: stop calling Hook B a question (done — §0 mandates it); decide RE_TIKI_IsOnGround
(done — §0: *"Also `RE_TIKI_IsOnGround` if corpse foot-shadows remain enabled"*); **write the
two capture caveats into P1**: (a) ForceUpdatePose stamps `tr.skel_index[entnum]` and
suppresses the renderer's own re-pose that frame — build the capture refEntity from the same
cent fields CG_ModelAnim submits, or capture after the scene; (b) `TIKI_GetSkeletor` keeps
only 2 cached skeletors per entnum with delete-on-evict — always capture with the cent's own
tiki handle.
**Both caveats are missing from v2** — P1 covers bridge/culling/gl2 only, and no section
describes capture mechanics at all. Same cluster as ARCH-F10 trap 1 and FACTS-2.

### STAB-F9 (spec-fix) — fill-site mechanics — **PARTIALLY**
Required items and their fates: model-space table — ADDRESSED (§2); per-view fill idempotence
— ADDRESSED (§0 + §7); cull-skip tolerance — ADDRESSED-BY-STRONGER-FIX (the §5 CULL_IN
override removes the skip case for flagged ents); gore-tracer-automatic — ADDRESSED (§0 F8
bullet); shadow-decal desync plan line — **present but INVERTED** (see ARCH-F5 / New-Defect
2); bone-pool overflow tolerance (overflowed scene skips the whole model with only a
PRINT_DEVELOPER line — an overridden corpse can simply not render; **do not assert on "pushed
but never consumed"**) — **MISSING** (nothing in v2 mentions pool overflow or the no-assert
rule; the §2 slot design makes "pushed but never consumed" a reachable state every saturated
scene).

### STAB-F10 (footnote) — cvar/T7 traps — **DROPPED**
Required: pre-register `coop_ragdoll` in G_InitGame (or keep scripts away) the moment P5 flips
the default to 1 (T7 / bug-1669: script getcvar creates it EMPTY and kills the engine default
forever); never give `r_ragdollDebug` CVAR_ARCHIVE (bug-1427/1148); CVAR_TEMP not CVAR_CHEAT
for debug cvars on a listen server (sv_cheats 0 clamps CHEAT).
Nothing survives in v2: no flags guidance, and §6 P5 (*"only then default-on"*) walks straight
into the documented trap with no pre-registration step. This is a standing project hazard
(dedicated_listen_parity memory: the getcvar trap killed a shipped feature once already), not
a style nit.

---

## Matrix 3 — Facts review (ragdoll_vet1_facts.md)

### FACTS-1 (1a-1f, citations) — **ADDRESSED**
Required change: none (wording only). v2 §0: *"All v1 file:line citations verified
byte-exact."* Fill-site pinning consumed by ARCH-F1's hook spec.

### FACTS-2 (orientation space answered + capture recipe) — **PARTIALLY**
The answer itself (model-local space, one index namespace end to end) is fully absorbed: §2
stores skeletor-space, Hook B applies the tiki_tag.cpp:108-111 formula, and the *"One index
space everywhere"* paragraph matches the finding's namespace proof. **Missing: the "WHAT CGAME
MUST DO" capture recipe** — *"build the corpse refEntity (tiki, frameInfo, scale,
entityNumber), `cgi.ForceUpdatePose`, then per tag …"*. v2 never describes the capture call
sequence or the refEntity fields; `frameInfo` appears nowhere. Same cluster as ARCH-F10 trap
1 / STAB-F8(a): this is the recipe whose omission produces a silent bind-pose capture.

### FACTS-3 (EF_DEAD verified + outside-PVS caveat) — **PARTIALLY**
The verification and the CG_TransitionEntity template are absorbed (§4). **Missing: the
demanded plan statement** — *"an actor that dies OUTSIDE the client's PVS and is later seen
will present EF_DEAD already set with no edge … those corpses keep anim pose … acceptable,
but state it in the plan."* v2 states only the vid_restart instance of this class (§5); the
general case (off-screen deaths, late joiners) is unstated. One sentence in §4 fixes it.

### FACTS-4 (bone names) — **ADDRESSED**
No change required. §0: *"all 17 Bip01 bone names verified in the LBD table AND parsed skds
across AA/SH/BT/imported bodies."* The "Bip01 Spine cannot be omitted from the OVERRIDE" rider
is satisfied structurally by §2's every-channel emission.

### FACTS-5 (one refEntity / one bone block) — **ADDRESSED**
No change required. §0: *"ONE refEntity + one bone block spans body+head+hands skds."*

### FACTS-6 (LOD; drop from P0) — **ADDRESSED**
§0 records it and the §6 P0 list no longer contains a LOD item.

### FACTS-7 (player guard + body-queue decision) — **PARTIALLY**
Required: guard = `eType == ET_MODELANIM && EF_DEAD rising && entityNumber >= cgs.maxclients`
(NOT `< MAX_CLIENTS`); decide body-queue corpses explicitly; if excluding them, *"additionally
reject `s.clientNum` valid on ET_MODELANIM corpses."*
v2 §4 delivers the guard verbatim and makes the decision (*"Body-queue player corpses
(ET_MODELANIM+EF_DEAD): EXCLUDED v1 (revisit after playtest)"*). **Missing: the exclusion
mechanism.** Body-queue corpses are ET_MODELANIM + EF_DEAD + entnum >= cgs.maxclients — they
PASS every clause of v2's stated arm guard, so the guard as written arms exactly what the same
paragraph declares excluded whenever the slot transition produces a rising edge. The
discriminator both reviewers named (`s.clientNum` is set "for players and corpses",
q_shared.h:2193) must be added to the guard. See New-Defect 3.

### FACTS-8 (BLOCKING — world matrices falsified) — **ADDRESSED** (minor note)
Required: convert to entity-local unscaled units each push with the exact formula; use the
CURRENT frame's refEntity placement, not the death-frame snapshot.
v2 §2 reproduces the formula exactly and binds it to *"converts each push"* on a refEntity
that *"keeps its server origin/axis"* — i.e. current-frame placement by construction. Minor
note: the explicit anti-trap sentence ("dead actors still lerp/settle server-side, so never
cache the death-frame transform — the body double-moves") is not spelled; recommend adding it
as one clause since a fresh implementer could still hoist the conversion transform out of the
per-push path.

### FACTS-9 (BLOCKING — 24 bones falsified) — **ADDRESSED** (same ~112 note as ARCH-F4/STAB-F5)
Required: every channel; ancestor-relative composition; size to engine cap (128 precedent) or
TIKI_GetNumChannels.
v2 §2 delivers the coverage and the composition (its `rel_b`/`M_anchor_sim * rel_b` form is
the same math as the finding's `M_capture_rel_ancestor * M_ancestor_current`, modulo
row/column convention), plus the P0 roster-scan sizing task and capture assert. The named cap
"~112" is wrong as an engine fact (New-Defect 4) but the mechanism (assert + measure) is the
one demanded.

### FACTS-10 (BLOCKING — tag path bypasses cache) — **ADDRESSED**
Required: Hook B mandatory in v1 (RE_TIKI_Orientation, + RE_TIKI_IsOnGround if foot shadows
stay); gore tracer needs nothing.
v2 §0 mandates both, §6 P4 verifies attachment coherence, and the gore-automatic fact is
recorded (*"stamps FOLLOW the override for free"*).

### FACTS-11 (BLOCKING — no velocity source) — **ADDRESSED**
Required: snapshot-origin differencing at the rising edge; explicit-impulse ship as fallback.
v2 §3 reproduces the differencing formula, keeps the wound kick, adds the P0 quality log and a
named decision gate (P2 exit). The optional 2-snap averaging refinement is folded into that
empirical gate — acceptable.

---

## v1 content lost in v2 — audit result: nothing material

Checked every v1 CLAIM quoted by the three reviews against v2:
- Goal/non-goals, 15/14/6/6 sim, sleep rules, failure ladder, kill switch, 240 trace ceiling,
  r_ragdollDebug, wound kick, dark-ship behind `coop_ragdoll 0` — all retained (v2 restates
  each, so its "unchanged from v1" phrases are self-contained despite v1 being unrecoverable).
- v1's WRONG content (dense table, world matrices, 24-bone partial override, elevator
  sentence, oldest-freezes eviction, spawn-serial premise, skeletor-layer question) was
  removed deliberately per findings — correct removals, not losses.
- One tunable quietly became a constant: v1's `coop_ragdollMax 8` cvar is now `MAX_RAGDOLLS(8)`
  compile-time. Defensible (slot payloads are statically sized), but it silently removes the
  runtime knob the cvar table advertised; if intentional, say so in one line.
- v1's P0 unknowns that round 1 resolved (LOD, orientation space, edge point, Hook B path) are
  correctly retired rather than lost.

## NEW defects / internal contradictions introduced by v2

1. **§3 timestep: "never slow-mo on low-fps clients" is false under §3's own numbers.**
   8ms substeps x cap 3 = 24ms max simulated per rendered frame ⇒ steady-state slow motion
   below ~41.7fps (72% speed at 30fps) — the exact steady-state pathology STAB-F3 was raised
   to kill, on hardware the reviewer stated WILL dip below 60fps on hordes. The clamp v2
   adopted only cures the hitch-backlog half of the finding. Fix: cap 4 (32ms ⇒ ~31fps floor)
   or 16.67ms x 2, delete or scope the claim, and state the supported minimum fps (the
   reviewer's explicit deliverable).
2. **§5 quirk ledger inverts a code-verified fact:** *"shadow decals follow feet via Hook B"*.
   Re-verified this session: the shipped default Phase-A decal (`coop_shadowDir` "1",
   cg_modelanim.c:711-763) traces from `model->origin` and consumes no tags; only the
   `cg_shadows 2` precise path (default "0") reads foot tags through Hook B. As written the
   quirk will send the P4 tester hunting a Hook B bug when the decal stays at the death spot.
   Correct line: "the default directional shadow decal stays at the server corpse origin
   (plants at model->origin, cg_modelanim.c:740-742) — accept or offset cgame-side from the
   sim centroid; only cg_shadows 2 precise foot shadows follow via Hook B."
3. **§4 contradicts itself on body-queue corpses:** declared *"EXCLUDED v1"*, but the arm
   guard in the previous sentence (ET_MODELANIM + EF_DEAD rising + entnum >= cgs.maxclients)
   admits them — body-queue entities satisfy all three (facts review, body.cpp:38-40). The
   exclusion has no mechanism until the guard adds the reviewers' discriminator: reject
   ET_MODELANIM corpses with a valid `s.clientNum` (q_shared.h:2193).
4. **§2 asserts a nonexistent engine constant:** *"array sized to an asserted engine cap
   ~112"*. No ~112 cap exists in the tree. Engine-real anchors: `TIKI_MAX_BONES 100`
   (tiki_shared.h:76, enforced per-SKD at tiki_skel.cpp:632/926 — note it caps a single skd,
   not the tiki's UNION channel list across body+head+hands+gear) and the 128 static-model
   bone array precedent (facts review, tr_staticmodels.cpp:44). The P0 roster scan + capture
   assert make the slot self-correcting, but the text should cite a real constant or none.
5. **Process root cause worth fixing in §0:** the line *"These leave the P0 unknowns list.
   [facts 1-7]"* bundles FACTS-3 and FACTS-7 with the pure confirmations. Both carried
   required plan statements (outside-PVS caveat; clientNum mechanism), and bundling them as
   "confirmed, no action" is precisely how they fell out of v2.

## Consolidated fix list for v3 (smallest edits that close every gap)

1. **Capture procedure paragraph** (closes ARCH-F10 trap 1, STAB-F8 a+b, FACTS-2): in §2 or a
   new §2.5 — capture builds its refEntity from the same cent fields CG_ModelAnim submits
   (tiki, CURRENT interpolated frameInfo, scale, entityNumber, origin/axis); one
   `cgi.ForceUpdatePose` (WARNING: stamps `tr.skel_index[entnum]` — wrong frameInfo poisons
   that frame's real render too), then per-channel `cgi.TIKI_Orientation`; always use the
   cent's own tiki handle (TIKI_GetSkeletor keeps only 2 cached skeletors per entnum,
   delete-on-evict). Add "capture pose verified non-bind" to P2 acceptance.
2. **Timestep** (STAB-F3): cap 3 → 4 (or 16.67ms x 2); add "supported minimum fps: ~31 (30
   target)"; delete "never slow-mo on low-fps clients" or re-scope it to "above the stated
   minimum".
3. **Arm-rate bounding** (STAB-F4): cap arms/frame at 4, queue the remainder 1-2 frames; add
   `arms refused` + `arms queued` counters to r_ragdollDebug.
4. **Trace mask** (STAB-F1): name it — MASK_SOLID-class — in the §3 collision spec.
5. **gl2 stubs** (STAB-F6): add gl2 stub exports, or record the deliberate deviation with the
   zero-init rationale in one sentence.
6. **Shadow quirk** (ARCH-F5/STAB-F9): rewrite per New-Defect 2.
7. **Body-queue guard** (FACTS-7): add "reject ET_MODELANIM corpses with valid s.clientNum" to
   the §4 arm guard.
8. **CL_TraceDeep ledger line** (ARCH-F6): one §5 quirk-ledger entry + the cross-comment
   insurance plan.
9. **Cvar flags paragraph** (STAB-F10): r_ragdollDebug never CVAR_ARCHIVE, CVAR_TEMP not
   CVAR_CHEAT; P5 step: pre-register coop_ragdoll in G_InitGame before flipping the default
   (T7/bug-1669).
10. **First-seen-dead statement** (FACTS-3): one §4 sentence — corpses first seen with EF_DEAD
    already set (off-screen deaths, late join, post-restart) never arm and keep the anim pose;
    accepted.
11. **T4 bounds-check line** (STAB-F5): every entnum index into ragdoll tables is
    bounds-checked against MAX_GENTITIES symbolically, per the gore precedent.
12. **"~112" correction** (New-Defect 4) and **pool-overflow tolerance line** (STAB-F9):
    override state must tolerate rows that are pushed but never consumed (cull-out before the
    CULL_IN override lands, bone-pool overflow skipping the model) — no asserts on
    consumption.
13. **Minor**: add the caller-gating clause to the §0/DECISIONS rationale (ARCH-F7); add the
    "current frame, never death-frame transform" clause to §2 (FACTS-8); note the
    coop_ragdollMax cvar → MAX_RAGDOLLS constant change as intentional.
