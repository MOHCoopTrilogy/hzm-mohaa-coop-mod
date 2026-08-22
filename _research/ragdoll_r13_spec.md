# RAGDOLL ROUND 13 — IMPLEMENTATION SPEC: PROCEDURAL HIT REACTIONS ON LIVING SOLDIERS

Written 2026-08-20 against four lens reports (`ragdoll_r13_blend.md`, `_trigger.md`, `_feel.md`,
`_risk.md`) and their adversarial verifications. Every claim below was re-verified against source
in this session; where a lens and the code disagreed, the code won and the lens is named.

The ask: *"if their bodies would react similarly to shots too that would be great"* — a living
soldier should visibly react where he was hit, while continuing to run, fire and take cover.

---

## 0. THE SAFETY ANSWER

**A render-side per-channel blend CANNOT affect server hit detection. This is not a judgement
call; it is four independent structural facts, each of which alone is sufficient.**

### Proof 1 — the surface the blend writes is not on any server path

The bone cache the blend rewrites is `TIKI_Skel_Bones[]` (`tiki/tiki_mesh.cpp:29`). A full-tree
grep returns **19 references, and every one is in `renderergl1/`, `renderergl2/`, or
`tiki/tiki_mesh.{cpp,h}`**:

```
renderergl1/tr_model.cpp:761,765,865,866,1252
renderergl2/tr_model.cpp:1113,1117,1122,1251,1252,1724
tiki/tiki_mesh.cpp:27,29,51,52,53,70      tiki/tiki_mesh.h:42,47,64,66
```

**Zero references in `fgame/`, `server/`, or `qcommon/`.** It is renderer scratch, indexed by
`ent->e.bonestart`, consumed only by the skinner at `tr_model.cpp:1252`.

### Proof 2 — the server module cannot reach the renderer at all

```
$ grep -n "\bre\.[A-Za-z_]*" server/*.c
(no output)
```

Not "does not call `re.TIKI_Orientation`" — **does not reference the renderer export table at any
symbol whatsoever.** Hook B (`RE_TIKI_Orientation`, `renderergl1/tr_model.cpp:1813`) is
unreachable from the server by construction.

### Proof 3 — the server's own bone read is a different function chain, verified end to end

| step | file:line |
|---|---|
| deep trace chosen for any `bIsCharacter` tiki, alive or dead | `server/sv_world.c:581-585` |
| `SV_TraceDeep` | `qcommon/cm_trace_lbd.cpp:444` |
| `orPosition = ge->TIKI_Orientation(touch, iBoneNum)` — the **game** export | `cm_trace_lbd.cpp:486` |
| `globals.TIKI_Orientation = G_TIKI_Orientation` | `fgame/g_main.cpp:1759` |
| `G_UpdatePoseInternal(edict)` then `gi.TIKI_OrientationInternal(...)` | `fgame/g_main.cpp:913,915` |
| `TIKI_OrientationInternal` | `tiki/tiki_tag.cpp:94` |
| `skeletor->GetBoneFrame(tagnum)` | `tiki/tiki_tag.cpp:105` |

The one collision-code function that *does* call `re.TIKI_Orientation` is `CL_TraceDeep`
(`cm_trace_lbd.cpp:578`). A full-tree grep for `CL_TraceDeep` returns exactly two hits: its
banner at `:530` and its definition at `:533`. **Zero callers. Dead code.** It is the single line
that would make this feature unsafe if anyone ever wired it up — see Risk 5.

### Proof 4 — even the shared skeletor cannot be poisoned, and two lenses overstated this

`TIKI_GetSkeletor` is one process-global store that server and renderer both write via
`TIKI_SetPoseInternal`. Both sides latch:

- server: `level.skel_index[]` / `level.frame_skel_index` (`fgame/level.h:225-226`, checked at
  `g_main.cpp:896`, stamped `:901`, frame value set by `G_SetFrameNumber` `:996-998`)
- renderer: `tr.skel_index[]` / `tr.frame_skel_index` (`renderergl1/tr_model.cpp:1773-1776`,
  frame value set by `RE_SetFrameNumber` `:1760-1762`)

**Disjoint namespaces.** Both are stamped from the same `com_frameNumber`
(`qcommon/common.c:2263` server, `:2273` client), and `SV_Frame(msec)` at `common.c:2388`
completes entirely before `CL_Frame(msec)` at `:2433`. And **every** server-side bone read in
`fgame/` goes through `G_TIKI_Orientation` / `G_TIKI_Transform` / `G_TIKI_IsOnGround`
(`g_main.cpp:909,920,928`), each of which calls `G_UpdatePoseInternal` first — there is no direct
`gi.TIKI_OrientationInternal` call anywhere else in `fgame/` (verified by grep).

Therefore a client pose write can never land between two server bone reads inside one server game
frame, and on the next game frame `com_frameNumber` has advanced, `level.skel_index[n] !=
level.frame_skel_index`, and the server re-poses from `edict->s.frameInfo` before its first read.

> **Correction to two lenses.** `ragdoll_r13_trigger.md` calls client-side `ForceUpdatePose` on a
> living entity "direct corruption of hit detection", and `ragdoll_r13_feel.md` calls it "a
> genuine hit-detection aliasing path". Both are wrong: `RE_ForceUpdatePose`
> (`tr_model.cpp:1793-1799`) stamps `tr.skel_index`, which has no power over the server's
> `level.skel_index` latch. The corpse path's `RagCapture` (`cg_ragdoll.c:607`) is safe for a
> structural reason, not by luck.

### What the chosen design does with that headroom

Nothing. **The design below never calls `cgi.ForceUpdatePose` on a living actor, never reads a
bone pose from cgame, and never touches the skeletor.** It writes exactly one thing:
`TIKI_Skel_Bones[]`, through Hook A, after the vanilla copy has filled it. The safety argument
therefore rests on Proof 1 alone — the weakest link in the chain is a variable that no server
translation unit can name.

**VERDICT: SAFE. No redesign required on this axis. Standing rule for all future work:**
*a client-side cosmetic layer may write the renderer bone cache and the ragdoll slot tables, and
nothing else. Any proposal that writes `refEntity_t::bone_tag`/`bone_angles`/`bone_quat`, calls
`SetControllerAngles`, or moves a server entity is rejected without further analysis.*

> **RECORDED EXCEPTION - 2026-08-21, VIEWMODEL ONLY (`CoopFingerLife`, cg_modelanim.c).**
> The procedural finger system writes `refEntity_t::bone_tag`/`bone_quat`, which the rule above bans
> outright. Taking it as an explicit, evidenced exception rather than working around it quietly.
>
> The rule's rationale is hitbox deflection: a client-side pose write reaching a skeletor the server
> also traces against. On a listen server client and server share a process, so that is a real
> concern - but it does not reach this case, because the cache is keyed on **(entnum, tiki)**, not on
> entnum alone. `TIKI_GetSkeletor` (`tiki/tiki_cache.cpp:319-330`) walks the per-entity cache and
> returns an instance ONLY when `skel->m_Tiki == tiki`, otherwise it constructs a new one. The
> first-person rig (`cg.pPlayerFPSModel`, a `*_fps.tik`) is a different tiki from the world model the
> server traces, so the viewmodel owns a separate skeletor and `SV_TraceDeep` cannot see these writes.
> Verified by reading the cache, not taken on report.
>
> The exception is scoped narrowly and does NOT relax the rule: it covers writes to the FIRST-PERSON
> refEntity only, it never takes a controller slot the engine has already populated (it copies the
> incoming array and fills only entries whose `bone_tag` is < 0, preserving `ARMS_TAG` view pitch),
> and it touches no server entity and calls no `SetControllerAngles`. Any proposal to write bone
> controllers on a WORLD entity is still rejected on the original grounds.

---

## 1. THE VERDICT

**Build a reduced version, in four builds, with a hard stop after build 1.**

The honest reason for the stop, and it is the single most valuable finding in the whole package
(from `ragdoll_r13_trigger.md`, missed by the other three lenses, verified by me this session):

> **The mod already has a locational hit-reaction layer, and its hit-location table is wrong. The
> user has never seen this feature work.**

`coop_mod/aihandler.scr:1864-1872` buckets `self.fact.location` like this:

```
if( local.loc >= 0 && local.loc <= 3 ){ local.sfx = "head" }
if( local.loc >= 4 && local.loc <= 7 ){ local.sfx = "back" }
if( local.loc == 8 || local.loc == 12 || local.loc == 16 ){ local.sfx = "rarm" }
if( local.loc == 9 || local.loc == 13 || local.loc == 17 ){ local.sfx = "larm" }
if( local.loc >= 10 && local.loc <= 11 ){ local.sfx = "leg" }
if( local.loc >= 14 && local.loc <= 15 ){ local.sfx = "leg" }
```

Against the truth — `hitloc_t` (`qcommon/q_shared.h:1426-1449`), `szLocArray[]`
(`qcommon/cm_trace_lbd.cpp:31-50`), and the original devs' own table at `anim/pain.scr:5-23`:

| loc | truth | script plays |
|---:|---|---|
| 3 | upper torso (`Bip01 Spine2`) | **head** |
| 7 | **right** upper arm | **back** |
| 8, 12, 16 | **left** arm / forearm / hand | **rarm** |
| 9, 13, 17 | **right** thigh / calf / foot | **larm** |
| 11 | **right** forearm | **leg** |
| 15 | **right** hand | **leg** |

Shoot a man's right arm, he plays a back flinch. Shoot his left arm, he plays the right-arm
flinch. Shoot his right leg, he plays a **left-arm** flinch. `self.fact.location` arrives
untouched (`Actor::HandlePain` forwards every `EV_Damage` arg; `global/pain.scr` passes
`local.location` straight through), so this is a plain mis-map, not a different enum. It is not
in `buglog.json`.

The layer underneath it is not a token: **94 whitelist entries across 21 `weapongroup_stance`
combinations** (`aihandler.scr:1749-1845`, counted this session) — bar, grenade, mp40, mp44,
pistol, rifle, shotgun, sten, thompson, unarmed, vickers, both stances (mp44 has no crouch set).
It already includes a 30% `<wg>_pain_dropgun` variant on standing arm hits (`:1883-1887`) — i.e.
it already does the single most legible thing a procedural forearm deflection could ever produce:
knock the gun loose. It is gated to 55% (`coop_defaults.cfg:364`) with a hardcoded 1.2 s
per-man throttle (`:1861-1862`).

> `ragdoll_r13_feel.md` claims the whitelist covers only rifle and pistol standing (2 combos) and
> builds an argument on it. **Refuted** — I counted 94 entries / 21 combos. `ragdoll_r13_risk.md`
> is correct.

So: **fix the buckets, unthrottle, and look.** That is seven lines of script, one pk3, zero
binary risk, and it changes what the existing feature looks like fundamentally. It might be the
whole answer. If it is, the engine work below should not be built at all, and I will say so
plainly rather than build it because it is interesting.

If it is not the whole answer, the procedural layer is worth building — **reduced to arms and
head, wire-driven, defaults off** — because the authored layer is a fixed-cost torso animation
that cannot tell a forearm from a hand, cannot scale with calibre, and cannot fire more than once
per 1.2 s. A procedural deflection is additive, continuous, and free of animation authoring.

**What is NOT worth building, at any stage:**

- **Torso and pelvis reactions** (locations 3-6). Bending the spine drags the arms, the head, the
  weapon and the aim. This is the "he loses his animation" failure the brief forbids, and the
  authored flinch already owns those locations.
- **Any client-side geometric search for which entity/bone was hit.** `sv_fps` is 40 in this
  install (`autoexec.cfg:684`) and the client parses CGM at packet-receive time
  (`client/cl_parse.cpp` → `CL_ParseCGMessage`), so the entity is 15-30 u from where the
  message says it was, against a 15.0-16.5 u search radius (`radius = 15.0f + 1.5f*iLarge`,
  `cg_parsemsg.cpp:1808`, and no shipped tik declares `bulletlarge > 1`). The positional error
  equals the entire search radius. Additionally `Actor::EventDamagePuff` (`fgame/actor.cpp:6040`)
  emits `CGM_BULLET_8` from script with no trace and no sentient, so any geometric consumer fires
  spurious reactions. **The wire carries the answer or the feature does not ship.**
- **Any port of the corpse solver** — no Verlet points, no constraints, no collision, no
  shape-match, no gravity, no leash. `ragdoll_r13_feel.md`'s "physically simulated: nothing" is
  the single best judgement in the four reports. A living actor is animated every frame; the
  reaction is a decaying rotation on top, not a simulation.

---

## 2. CONFLICT RECONCILIATION — one sentence each

1. **blend** wants a renderer blend between `slot->animPose` and `slot->mat`; **risk** shows
   `animPose` is raw skeletor space while `mat` is `(raw+load_origin)*load_scale` — I reject both
   and work purely on the post-vanilla-copy `cache[]`, so `animPose` is never read and no space
   conversion exists anywhere in the feature.
2. **feel** says the authored whitelist covers 2 weapongroup_stance combos, **risk** says 94
   entries / 21 combos — risk is right, I counted them.
3. **trigger** alone found the hit-location bucket mis-map — confirmed against `hitloc_t`,
   `szLocArray[]` and `anim/pain.scr:5-23`, and it is promoted to Stage 1, the whole first build.
4. **trigger** and **risk** say appending fields to `CGM_BULLET_8` desyncs the `CGM_BULLET_6..11`
   shared read block (`cg_parsemsg.cpp:1768-1778`), **blend** never noticed — they are right, and
   I sidestep it entirely with a new message id, which also makes the wire runtime-revocable.
5. **risk** says never reuse `RagPush`/`mat0` on a living actor because a captured pose plus an
   unconditional 72-channel overwrite is a freeze-and-moonwalk — correct, and the design uses a
   separate pool that stores a rotation and never a pose.
6. **feel** says never write `cache[].offset`; the sub-tree bend must — feel's *reason* (never mix
   two spaces) is right and its *rule* is too broad, because here the read, the pivot and the
   write are all `cache`-space with no `load_scale` or `load_origin` in the expression.
7. **blend** says off-screen reaction costs nothing and its verifier refutes it because Hook A
   sits outside the cull gate — the verifier is right about the corpse hook, so the bend hook goes
   **inside** the cull gate, which makes the claim true again and closes the stale-garbage hole.
8. **blend**'s verifier finds `RE_SetRagdollPose` never clears `hasWeights`, giving half-ragdolled
   corpses — real for blend's design, structurally impossible in mine because Hook A applies the
   bend only in the `else` branch of "does this entity have a corpse override".
9. **feel**'s `bulletlarge` census (241/1) does not reproduce at any scope and the live-mount MG42
   resolves to `iLarge = 0` because an HD pack shadows the retail tik — so `iLarge` becomes a
   multiplier with a default, and nothing is gated on it.
10. **blend** argues an 18-30° band (corrected to 19-26), **feel** argues 15-20°, both anchored
    on a 60.5° corpse swing that has no in-repo instrument record (`ragdoll_r12_spec.md:39`
    records 10.05° measured and `:44` projects 21.1°) — I drop the corpse ratio entirely and
    set the angle by on-screen readability, with the angle as the one live sweep knob, starting
    deliberately over-driven.
11. **risk** says merge the wire stage into the visual stage because the wire stage's only
    instrument needs data the next stage delivers — right, and a build with no visible output
    wastes a session at one build per session.
12. **trigger** and **feel** both call client-side `ForceUpdatePose` on a living actor a
    hit-detection corruption path — both overstate it (see Proof 4), but the design avoids it
    anyway because reading a pose from cgame is also the expensive way to get data the renderer
    already has in hand.
13. **blend** places the new bridge members mid-struct (`tr_public.h` "after :190",
    `cg_public.h` "after :454") — that shifts two existing members across a DLL boundary; the
    appends go after `tr_public.h:191` and `cg_public.h:455`, at the very end.
14. The **brief** attributes a fourth render-space defect to bug-1971 — bug-1971 is
    `officer.scr` + `mg42_hack.scr` surrender/holster work; the render-space defects are
    **1962, 1963, 1964**, three not four.

---

## 3. ARCHITECTURE

### 3.1 The one-line description

**cgame tells the renderer "rotate these N channels of entity E by θ degrees about the pivot
bone's origin, in the plane containing the bone and the bullet". The renderer does it to the bone
cache it has just filled from the animation, after the vanilla copy and inside the cull gate.**

### 3.2 Why this shape and not the other two

| | this design | blend's `animPose` blend | risk's cgame-read-and-push |
|---|---|---|---|
| untouched channels | **bit-exact vanilla** (never written) | lerped at w=0 | rewritten from a round trip |
| translation space conversion | **none exists** | `animPose` vs `mat` mismatch (bug-1963 class) | round trip through TIKI space |
| staleness | **zero** — same frame's cache | one frame | one frame |
| cgame pose reads/frame/actor | **0** | 0 | 72 `TIKI_Orientation` + `ForceUpdatePose` |
| blast radius of a bug | **one limb** | one limb | **the whole body** |
| skipped-push failure mode | actor renders vanilla | frozen limb | **frozen, sliding actor** |
| corpse interaction | impossible (`else` branch) | half-ragdoll hazard | pool contention |

The decisive column is *blast radius*. A living soldier the player is fighting must never explode,
collapse, or T-pose; the only way to guarantee that is to never write the channels we are not
deliberately bending, and to leave the vanilla copy loop untouched.

### 3.3 The bone cache is absolute per channel — which is why this works and why it needs a sub-tree

`R_RagdollApplyToCache` writes `cache[i].offset` and `cache[i].matrix` per channel with no
hierarchy propagation (`tr_ragdoll.cpp:139-171`), and the skinner places a vertex at
`v_bonelocal * matrix + offset` (`tr_model.cpp:1252` region). MOHAA's `Bip01` bones sit at their
**proximal** joint (`cg_ragdoll.c:96-99`: *"A bone's skinned mesh runs from its OWN origin toward
its CHILD"*), so:

- rotating `cache[b].matrix` swings bone `b`'s mesh about its own joint — exactly the wanted motion
- but every descendant keeps its old absolute `offset`, so the mesh tears at the next joint

Therefore the bend must carry the sub-tree: for pivot `b` at `P = cache[b].offset`, and for `b`
and every descendant `d`:

```
cache[d].matrix = cache[d].matrix * R
cache[d].offset = P + (cache[d].offset - P) * R
```

Both operands of the position line are cache offsets. **No `load_scale`, no `load_origin`, no
`e.scale` appears in this feature at any point.** That is what structurally excludes the
bug-1963 defect class, and it is why `ragdoll_r13_feel.md`'s "never write `cache[].offset`" rule
is relaxed here with a comment naming the reason.

### 3.4 Matrix convention — copied from the shipped corpse code, not re-derived

`cg_ragdoll.c:401` and `:482-536`: the engine is **row-vector**, matrix rows are the bone's axes,
`v_model = v_local * M`. `RagMat3FromTo(a, b, out)` builds a row-vector rotation taking `a` to `b`
(with a correct antiparallel fallback, `:493-517` — the fixed-`+y` version was a math-vet defect).
`RagPush` composes `mat[ch][r][c] = mat0[ch][r][*] * conj[a][*][c]`, i.e. **post-multiply**
(`cg_ragdoll.c:1387-1392`). The bend uses the identical convention and the identical primitive.

**The rotation is constructed as a from→to map, never as an axis-angle.** Given the bone
direction `u` (unit) and the bullet travel direction `t` (unit):

```
perp = t - (t . u) u ;  if |perp| < 1e-3  -> no reaction (shot straight down the bone)
perp = perp / |perp|
to   = u * cos(theta) + perp * sin(theta)
R    = RagMat3FromTo(u, to)
```

This is sign-free by construction: there is no `+θ` vs `-θ` and no column/row transpose to
get wrong. That removes the exact convention hazard that produced bugs 1962/1963/1964.

### 3.5 Where the direction and the bone direction come from

- **Direction**: the wire delivers the impact normal (wound → muzzle, per the 2026-08-20 flesh-hit
  fix at `weaputils.cpp:2638-2646`); cgame negates it to travel direction exactly as
  `cg_parsemsg.cpp:1799` already does for corpses, then rotates it into the entity's model frame
  with `cent->lerpAngles` using the same unrot as `cg_ragdoll.c:555-559`. Direction is
  scale-invariant, so no `load_scale` enters.
- **Bone direction**: computed **in the renderer** from `cache[tip].offset - cache[pivot].offset`,
  on the frame being drawn. This is the reason the renderer, not cgame, owns the rotation build:
  it already holds the current-frame pose, so there is zero staleness and cgame never needs
  `ForceUpdatePose`.

### 3.6 The per-location channel table

Ground truth, dumped this session by walking `boneFileData_t` records with the per-record `ofsEnd`
at `+80` (not the fixed 84-byte stride): the union across **45 roster human SKDs with ≥30 bones
is 106 names**; the standard 42-bone German (`daksoldier.skd`, `gestapo.skd`) and the 61-bone
ranger differ only by fingers and props.

Stage 3 ships **9 of 19 locations**. Torso/pelvis are permanently out; legs are Stage 4.

| loc | `szLocArray` bone | pivot | tip | channel-name prefixes carried | scale |
|---:|---|---|---|---|---:|
| 0 HEAD | `Bip01 Head` | `Bip01 Head` | `eyes bone` | `Bip01 Head`, `eyes bone`, `helmet`, `hat`, `beret` | 0.55 |
| 1 HELMET | `Bip01 Head` | as loc 0 | | | 0.55 |
| 2 NECK | `Bip01 Neck` | `Bip01 Neck` | `Bip01 Head` | `Bip01 Neck`, `Bip01 Head`, `eyes bone`, `helmet`, `hat`, `beret` | 0.55 |
| 7 R_ARM_UPPER | `Bip01 R UpperArm` | same | `Bip01 R Forearm` | `Bip01 R UpperArm`, `Bip01 R Forearm`, `Bip01 R Hand`, `Bip01 R Finger`, `helper Relbow` | 0.40 |
| 8 L_ARM_UPPER | `Bip01 L UpperArm` | same | `Bip01 L Forearm` | `Bip01 L UpperArm`, `Bip01 L Forearm`, `Bip01 L Hand`, `Bip01 L Finger`, `helper Lelbow` | 1.00 |
| 11 R_ARM_LOWER | `Bip01 R Forearm` | same | `Bip01 R Hand` | `Bip01 R Forearm`, `Bip01 R Hand`, `Bip01 R Finger` | 0.40 |
| 12 L_ARM_LOWER | `Bip01 L Forearm` | same | `Bip01 L Hand` | `Bip01 L Forearm`, `Bip01 L Hand`, `Bip01 L Finger` | 1.00 |
| 15 R_HAND | `Bip01 R Hand` | same | `Bip01 R Finger1` | `Bip01 R Hand`, `Bip01 R Finger` | 0.40 |
| 16 L_HAND | `Bip01 L Hand` | same | `Bip01 L Finger1` | `Bip01 L Hand`, `Bip01 L Finger` | 1.00 |
| 3,4,5,6 | torso/pelvis | **NEVER** — authored flinch owns these | | | — |
| 9,10,13,14,17,18 | legs/feet | **Stage 4** | | | — |

Matching is a case-insensitive prefix test (`Q_stricmpn`) against `cgi.Tag_NameForNum`, run once
per reaction, not per frame. Expected `ch` counts, which is the Stage 2 instrument: **loc 11 on a
42-bone German = 2** (`Bip01 R Forearm`, `Bip01 R Hand`); **loc 11 on a 61-bone ranger = 17**
(+15 fingers). If `ch` prints 0, the table is wrong; if it prints 40, a prefix is too loose.

`tag_weapon_right` / `tag_weapon_left` are deliberately **absent**. Nothing skins to a tag — tags
are served by Hook B from the skeletor, not from `cache` — so including them would change nothing
visible while inflating `ch` and muddying the instrument. Weapon-follows-hand is a post-Stage-4
option (§9) and needs Hook B, which Stages 1-4 do not touch at all.

The right (gun) arm and the head carry a scale below 1.0 for a concrete reason: the AI's rendered
weapon is placed through Hook B by `CG_AttachEntity` → `cgi.TIKI_Orientation`
(`cg_modelanim.c:914`), which Stages 1-4 leave on the animation. At the 0.40 cap a 25° base
becomes 10° of hand travel against a static rifle — a few units at the grip, and
`400 * tan(10°) = 70.5 u` of apparent muzzle swing avoided.

### 3.7 Wire: a new coop-private CGM, not an append to `CGM_BULLET_8`

`CGM_BULLET_6..11` share one read block (`cg_parsemsg.cpp:1768-1778`: coord ×3, `MSG_ReadDir`,
`MSG_ReadBits(2)`) before an inner `switch`. Appending there consumes 16 bits that
`CGM_BULLET_6/7/10/11` — every round that **misses** — never wrote, desyncing the stream into
`cgi.Error(ERR_DROP, ...)` at `:2120`.

Instead: **`CGM_COOP_HITREACT = 42`.**

- The CGM type field is 6 bits (`server/sv_game.c:398` write, `cg_parsemsg.cpp:1688` read),
  ceiling 63. `CGM_FENCEPOST` is 41 (counted from `fgame/bg_public.h:750-792`), so **42-63 are
  free**.
- `BG_MapCGMToProtocol` (`fgame/bg_misc.cpp:392-419`) returns `messageNumber` unchanged for
  `protocol >= PROTOCOL_MOHTA_MIN` and again unchanged for `messageNumber > 40`. **Identity-mapped
  in both protocol families.** The case is nonetheless added to *both* parsers
  (`CG_ParseCGMessage_ver_15` at `:1674`, `CG_ParseCGMessage_ver_6` at `:2128`) with identical
  field order, so a ver_6 client cannot hit `default:` at `:2470`.
- Payload, 74 bits:

```
entnum      11 bits   (GENTITYNUM_BITS, q_shared.h:1667)
location     5 bits   (trace.location + 2, so LOCATION_FAIL -2 and -1 survive; MAX_HITLOCATIONS 19)
bulletlarge  2 bits   (bulletbits, weaputils.cpp:2357)
pos          3 x MSG_WriteCoord
dir          MSG_WriteDir   (wound -> muzzle, same convention as CGM_BULLET_8)
```

**Why a new id rather than an append is the load-bearing decision:** the message is emitted only
when a server cvar is on, only for a living non-player sentient, only on a real bone hit. That
makes the wire change **revocable at runtime** (`coop_hitReactWire 0`) instead of only by
rebuilding — which is what satisfies the one-command-rollback requirement. It also costs nothing
on the hot path: `CGM_BULLET_8` is untouched, so a 20-pellet shotgun blast does not grow by
20 × 16 bits, and `Actor::EventDamagePuff` (`actor.cpp:6040`) needs no edit and can never produce
a false reaction.

**Mismatched clients hard-drop, they do not degrade** (`cg_parsemsg.cpp:2120`, `:2470`) — the CGM
block is one bit stream with a 1-bit continuation flag, so an unknown id cannot be skipped. The
server cvar defaults **0** and `build.ps1:190-206` ships `openmohaa.exe`, `cgame.dll`,
`game.dll` and both renderer DLLs together to both `G:\mohaa-gl2\` and the GOG root, so lockstep
holds for this pipeline. Note it in the release notes anyway.

---

## 4. THE BUILD SEQUENCE

Four builds. Each answers exactly one question. **Every stage is a hard gate: if its question
answers "no", the next stage does not get built.**

---

### STAGE 1 — "Does a correct-limb authored flinch, unthrottled, already answer the ask?"

**This is the smallest thing that produces a visible reaction on a living soldier, and it is
script-only.**

**IN**
- Fix the location buckets in `coop_mod/aihandler.scr::coop_hitReact` (`:1864-1872`).
- Replace the hardcoded `1.2` throttle (`:1862`) with a cvar so it can be swept live.
- One diagnostic print, gated on the existing debug path.

**OUT** — everything else. No DLL, no wire, no renderer, no cvar registration in C.

**Code shape** (`coop_mod/aihandler.scr`, replacing `:1864-1872`):

```
	//[2026-08-20] THE BUCKETS WERE MIRRORED AND OFF BY ONE. Truth: hitloc_t (q_shared.h:1426)
	//and szLocArray (cm_trace_lbd.cpp:31), which the original devs also documented at
	//anim/pain.scr:5-23. The shipped table sent loc 7 (RIGHT upper arm) to "back", 8/12/16
	//(LEFT arm) to "rarm", and 9/13/17 (RIGHT LEG) to "larm" - so every arm hit played the
	//wrong limb and every right-leg hit played an ARM flinch. Nobody saw the feature work.
	local.sfx = "back"
	if( local.loc <= 2 ){ local.sfx = "head" }                                  //0 head 1 helmet 2 neck
	if( local.loc >= 3 && local.loc <= 6 ){ local.sfx = "back" }                //3-5 spine 6 pelvis
	if( local.loc == 7 || local.loc == 11 || local.loc == 15 ){ local.sfx = "rarm" }
	if( local.loc == 8 || local.loc == 12 || local.loc == 16 ){ local.sfx = "larm" }
	if( local.loc == 9  || local.loc == 10 ){ local.sfx = "leg" }               //thighs
	if( local.loc == 13 || local.loc == 14 ){ local.sfx = "leg" }               //calves
	if( local.loc >= 17 ){ local.sfx = "leg" }                                  //feet
```

and replacing `:1861-1862`:

```
	local.thr = getcvar "coop_aiHitReactWait"
	if( local.thr == "" ){ local.thr = "1.2" }
	if( self.coop_hitReactT != NIL && level.time < self.coop_hitReactT ){ end }
	self.coop_hitReactT = level.time + float(local.thr)
```

and, immediately before `self setmotionanim local.anim` (`:1888`):

```
	if( getcvar "coop_bloodDebug" == "1" ){
		println "^~^~^ HITREACTMAP loc=" local.loc " sfx=" local.sfx " wg=" local.wg " anim=" local.anim
	}
```

`getcvar` returning `""` and being defaulted **in script** is deliberate: the bug-1669 trap
(script `getcvar` creates a cvar EMPTY and permanently defeats an engine default) does not bite
when nothing pre-registers the cvar and the script supplies the default itself — which is exactly
what the existing `coop_aiHitReact` read at `:1850-1852` already does.

**The question this build answers:** with the right limb flinching on every hit, is the ask
satisfied? **If yes, the project stops here and `coop_hitReact` is never registered.**

---

### STAGE 2 — "Does the wire deliver the right entity and the right bone, and does one over-driven limb read as a reaction?"

Wire and visual **merged into one build**, per `ragdoll_r13_risk.md` §H: a stage whose only
instrument needs data the next stage delivers is unbuildable, and a build with no visible output
wastes a session.

**IN**
- `fgame/`: `CGM_COOP_HITREACT = 42` in the ver_15 and ver_6 enums; send block in
  `weaputils.cpp` beside the existing `CGM_BULLET_8` send at `:2621`; server cvar
  `coop_hitReactWire` pre-registered in `G_InitGame` (never via script `getcvar` — bug-1669).
- `cgame/`: new file `cg_hitreact.c` — parse case in both parsers, the 9-location table, the
  envelope, the reaction pool, `CG_HitReactFrame()` called from `cg_view.c:2928` right after
  `CG_RagdollFrame()`.
- `renderergl1/tr_ragdoll.cpp` and `renderergl2/tr_ragdoll.cpp` (**keep byte-identical** — `diff`
  returns nothing today and must keep doing so): bend pool, `RE_SetRagdollBend`,
  `RE_ClearRagdollBend`, `R_RagdollBendFor`, `R_RagdollApplyBend`, and a verbatim port of
  `RagMat3FromTo` as `R_BendMat3FromTo`.
- `renderergl1/tr_model.cpp` and `renderergl2/tr_model.cpp`: the cull-gate flag and the `else`
  branch in Hook A.
- Bridge: `tr_public.h` **after `:191`**, `renderergl{1,2}/tr_init.c` beside the existing ragdoll
  assignments, `client/cl_cgame.cpp` beside `:837-839`, `cgame/cg_public.h` **after `:455`**.
  Every one is a struct-**tail** append; nothing mid-struct.
- Arms and head only (§3.6). Angle deliberately over-driven so the build cannot fail on
  "I could not tell".

**OUT** — legs, torso, pelvis, Hook B / weapon-follows-hand, `iLarge` scaling beyond a single
multiplier, distance LOD beyond a hard cull, any per-gun tuning, any interaction with the corpse
solver.

**Renderer code shape** (`tr_ragdoll.cpp`, appended below the existing pool; both files identical):

```c
// HZM coop - LIVING HIT REACTION (ragdoll_r13_spec.md). A second, SEPARATE pool: a living
// actor is animated every frame, so this never stores a pose - only a rotation to apply to
// the pose the animation just produced. Nothing here reads slot->animPose, and nothing here
// touches load_scale or load_origin: pivot, source and destination are all bone-cache space,
// which is what makes the bug-1963 defect class structurally unreachable.
#define RAGBEND_MAX_SLOTS 8
#define RAGBEND_MAX_CH    24

typedef struct ragBendSlot_s {
    qboolean active;
    int      entnum;
    dtiki_t *tiki;
    int      pivot, tip;
    int      count;
    short    ch[RAGBEND_MAX_CH];
    vec3_t   dir;      // bullet TRAVEL direction, entity model frame, unit
    float    deg;      // current commanded swing
} ragBendSlot_t;

static ragBendSlot_t s_bendSlots[RAGBEND_MAX_SLOTS];
static byte          s_bendSlotPlusOne[MAX_GENTITIES];

ragBendSlot_t *R_RagdollBendFor(int entityNumber, dtiki_t *tiki);  // same shape as R_RagdollSlotFor

void RE_SetRagdollBend(int entityNumber, dtiki_t *tiki, int pivot, int tip,
                       int count, const short *channels, const vec3_t dirModel, float degrees)
{
    // ... bounds, slot reuse / alloc, silent return when full (cgame counts refusals) ...
    // REFUSE while a corpse override owns this entity: the two must never both apply.
    if (R_RagdollSlotFor(entityNumber, tiki)) { return; }
}

void RE_ClearRagdollBend(int entityNumber);                       // memset + index clear

void R_RagdollApplyBend(ragBendSlot_t *slot, skelBoneCache_t *cache, int num_tags)
{
    vec3_t P, u, t, perp, to;
    float  R[3][3], ct, st, d;
    int    k, r;

    if (!slot || !cache || slot->deg <= 0.02f) { return; }
    if (slot->pivot < 0 || slot->pivot >= num_tags) { return; }
    if (slot->tip   < 0 || slot->tip   >= num_tags) { return; }

    VectorCopy(cache[slot->pivot].offset, P);
    VectorSubtract(cache[slot->tip].offset, P, u);
    if (VectorNormalize(u) < 0.01f) { return; }        // degenerate limb this frame

    VectorCopy(slot->dir, t);
    d = DotProduct(t, u);
    perp[0] = t[0] - d*u[0]; perp[1] = t[1] - d*u[1]; perp[2] = t[2] - d*u[2];
    if (VectorNormalize(perp) < 0.001f) { return; }    // shot straight down the bone: no torque

    ct = cos(slot->deg * (float)M_PI / 180.0f);
    st = sin(slot->deg * (float)M_PI / 180.0f);
    to[0] = u[0]*ct + perp[0]*st;
    to[1] = u[1]*ct + perp[1]*st;
    to[2] = u[2]*ct + perp[2]*st;
    R_BendMat3FromTo(u, to, R);                        // row-vector, verbatim from cg_ragdoll.c:482

    for (k = 0; k < slot->count; k++) {
        int    c = slot->ch[k];
        float  m[3][3];
        vec3_t rel, out;
        if (c < 0 || c >= num_tags) { continue; }
        // ROTATION - row-vector, post-multiply, identical to RagPush (cg_ragdoll.c:1387-1392)
        for (r = 0; r < 3; r++) {
            m[r][0] = cache[c].matrix[r][0]*R[0][0] + cache[c].matrix[r][1]*R[1][0] + cache[c].matrix[r][2]*R[2][0];
            m[r][1] = cache[c].matrix[r][0]*R[0][1] + cache[c].matrix[r][1]*R[1][1] + cache[c].matrix[r][2]*R[2][1];
            m[r][2] = cache[c].matrix[r][0]*R[0][2] + cache[c].matrix[r][1]*R[1][2] + cache[c].matrix[r][2]*R[2][2];
        }
        for (r = 0; r < 3; r++) {
            cache[c].matrix[r][0] = m[r][0];
            cache[c].matrix[r][1] = m[r][1];
            cache[c].matrix[r][2] = m[r][2];
            cache[c].matrix[r][3] = 0;
        }
        // POSITION - orbit the SAME rotation about the pivot. Both operands are cache offsets,
        // so no load_scale and no load_origin appear here. That asymmetry is the whole reason
        // this is safe where a naive animPose lerp is not (bug-1963).
        VectorSubtract(cache[c].offset, P, rel);
        out[0] = rel[0]*R[0][0] + rel[1]*R[1][0] + rel[2]*R[2][0];
        out[1] = rel[0]*R[0][1] + rel[1]*R[1][1] + rel[2]*R[2][1];
        out[2] = rel[0]*R[0][2] + rel[1]*R[1][2] + rel[2]*R[2][2];
        VectorAdd(P, out, cache[c].offset);
    }
}
```

**Hook A change** (`tr_model.cpp`, both renderers, at the existing `:826-863` region):

```c
    qboolean coopVanillaCopied = qfalse;
    if (lod_tool->integer || iRadiusCull != CULL_CLIP
        || R_CullSkelModel(tiki, &ent->e, newFrame, tiki_scale, tiki_localorigin) != CULL_OUT) {
        for (i = 0; i < num_tags; i++) { /* ... unchanged vanilla copy ... */ }
        coopVanillaCopied = qtrue;
    }

    {
        struct ragdollSlot_s *coopSlot = R_RagdollSlotFor(ent->e.entityNumber, tiki);
        if (coopSlot) {
            R_RagdollApplyToCache(coopSlot, coopCacheStart, num_tags, newFrame);
        } else if (coopVanillaCopied) {
            // HZM coop - LIVING HIT REACTION. Deliberately INSIDE the cull gate, unlike the
            // corpse override above. A corpse's OBB is stale by design, so its override must
            // write unconditionally or stale pool garbage leaks under a drifted body. A LIVING
            // actor's OBB is his own animation's, so CULL_OUT is trustworthy - and
            // post-multiplying an un-filled cache region would rotate that same garbage. The
            // `else` is load-bearing too: a corpse override and a bend can never both apply,
            // which is what makes a half-ragdolled corpse structurally impossible.
            struct ragBendSlot_s *coopBend = R_RagdollBendFor(ent->e.entityNumber, tiki);
            if (coopBend) {
                R_RagdollApplyBend(coopBend, coopCacheStart, num_tags);
            }
        }
    }
```

**cgame code shape** (`cg_hitreact.c`, new file):

```c
#define HR_MAX_ACTIVE 8
#define HR_MAX_CH     24

typedef struct hrReact_s {
    qboolean active;
    int      entnum, loc, startMs, attackMs, releaseMs;
    float    peakDeg;
    vec3_t   dirModel;            // travel direction, entity model frame
    int      pivotCh, tipCh, chCount;
    short    ch[HR_MAX_CH];
} hrReact_t;
static hrReact_t s_hr[HR_MAX_ACTIVE];
static int       s_hrRefused;

// zero derivative at both joins - no pop on either end
static float HR_Envelope(int t, int ta, int tr)
{
    float u;
    if (t < 0 || ta <= 0 || tr <= 0) { return 0.0f; }
    if (t < ta) { u = (float)t / (float)ta; return u*u*(3.0f - 2.0f*u); }
    t -= ta;
    if (t < tr) { u = (float)t / (float)tr; return 1.0f - u*u*u*(u*(6.0f*u - 15.0f) + 10.0f); }
    return 0.0f;
}

void CG_HitReactSeed(int entnum, int loc, const vec3_t pos, const vec3_t normal, int iLarge);
void CG_HitReactFrame(void);      // called from cg_view.c:2928, right after CG_RagdollFrame()
void CG_HitReactClearEnt(int entnum);
```

`CG_HitReactSeed` gates, in this order, and bails silently on any failure:

1. `hr_master->integer` and `cgi.R_SetRagdollBend` non-NULL (bridge-absent belt, matching
   `cg_ragdoll.c:396/1449/1713`).
2. `cg.snap` non-NULL. *(This also closes a live defect in the corpse path: `CG_RagdollImpulse`
   dereferences `cg.snap->numEntities` at `cg_ragdoll.c:1460` with only a
   `!cgi.R_SetRagdollPose || force <= 0 || radius <= 1.0f || !rag_impact->integer` guard at
   `:1449`. `CL_ParseCGMessage` runs from `cl_parse.cpp` with no snapshot guard, so a flesh hit
   arriving before the first rendered frame is a null deref. **One line, fold it into this
   build.**)*
3. `entnum >= cgs.maxclients` — never a player slot (bug-785/792 standing rule).
4. Entity present in `cg.snap`, `eType == ET_MODELANIM`, `!(eFlags & EF_DEAD)`,
   `es->parent == ENTITYNUM_NONE` (a parented actor is composed through
   `R_GetTagPositionAndOrientation`, `tr_model.cpp:589-601`, not `lerpOrigin`).
5. No corpse sim or pending record for this entnum (`RagSimFor`) — the corpse owns the body.
6. `|cent->lerpOrigin - cg.refdef.vieworg| < coop_hitReactDist`.
7. Location table entry exists (torso/pelvis/legs return NULL in Stage 2).
8. Free reaction slot, else `s_hrRefused++` and return.
9. Resolve `pivotCh`/`tipCh` via `cgi.Tag_NumForName`; enumerate channels with
   `cgi.Tag_NameForNum` and collect prefix matches, capped at `HR_MAX_CH`. `chCount == 0` → bail.
10. `dirModel` = negate the wire normal, then unrot by `AnglesToAxis(cent->lerpAngles)` exactly as
    `cg_ragdoll.c:555-559`.
11. `peakDeg = hr_deg->value * tbl->scale * (1.0f + hr_large->value * iLarge)`, clamped to
    `hr_degMax`.

`CG_HitReactFrame` per active reaction: recompute `w = HR_Envelope(cg.time - startMs, ...)`; if
`w * peakDeg < 0.05f` → `cgi.R_ClearRagdollBend(entnum)`, mark inactive, print the `done` line;
else re-run gates 3-6 (entity may have died, been culled, or left the snapshot — **on failure,
clear, never skip**, per `ragdoll_r13_trigger.md` R3) and
`cgi.R_SetRagdollBend(entnum, tiki, pivotCh, tipCh, chCount, ch, dirModel, w * peakDeg)`.

`CG_HitReactClearEnt` is called from `CG_RagdollClearEnt` (`cg_ragdoll.c:388-399`) **and** as the
first statement of `CG_RagdollTransition`, **above every early return**. This matters: the death
edge sits at `cg_ragdoll.c:2294-2306` behind `eType`, rising-edge and `!cent->interpolate` guards,
and bug-1969 exists precisely because an `interpolate` guard silently suppressed most of the
corpse path. A living bend cleared behind those guards becomes a **permanent frozen kink on a
corpse**.

**A skipped push does not freeze a living actor in this design** — Hook A's bend branch simply
finds no slot and the vanilla copy stands. That is the whole point of §3.2's "blast radius"
column, and it is the property that `ragdoll_r13_trigger.md` R3 and `ragdoll_r13_risk.md` §C
correctly identified as fatal in the other two designs.

**The question this build answers:** does the wire hand the client the right entity and the right
bone, and does an over-driven single-limb deflection read as a hit reaction on a moving man?

---

### STAGE 3 — "What does it look like at a believable angle, and does it survive a firefight?"

**IN** — sweep `coop_hitReactDeg` down from the over-drive to taste; sweep the envelope; enable
head; confirm behaviour with 8+ actors under fire; confirm the corpse handoff over 20 kills.
**OUT** — legs, weapon-follows-hand, per-gun tuning. No new code unless Stage 2 exposed a defect.

---

### STAGE 4 — "Do legs work without floating the feet?"

**IN** — locations 9/10/13/14/17/18 added to the table, with the thigh scale low. Legs are the
riskiest family because the animation plants the feet and the bend does not know it; if a running
soldier's foot visibly floats or skates, **cut legs permanently** and ship arms+head.
**OUT** — everything else.

---

## 5. PARAMETER TABLE

Living-actor behaviour is **OFF by default at both ends** — the server does not send and the
client does not react.

| cvar | default | flags | where | meaning |
|---|---:|---|---|---|
| **`coop_hitReactWire`** | **`0`** | ARCHIVE, server | `G_InitGame` (pre-registered) | master: server emits `CGM_COOP_HITREACT`. `0` = the message never goes on the wire and no client version can react. |
| **`coop_hitReact`** | **`0`** | ARCHIVE, client | `cg_hitreact.c` | master: client seeds reactions. Mirrors the `coop_ragdoll` precedent (`cg_ragdoll.c:320`) — ARCHIVE not TEMP so a player's "off" survives a relaunch. |
| **`coop_hitReactDeg`** | `25` **(Stage 2)** / `16` (Stage 3 start) | TEMP | client | **THE knob to sweep live.** Peak swing in degrees, before the per-region scale. Deliberately over-driven in Stage 2 so the build cannot fail on "I could not tell". |
| `coop_hitReactDegMax` | `32` | TEMP | client | hard ceiling after scale and `iLarge` |
| `coop_hitReactMs` | `90` | TEMP | client | attack, ms. Below the 108 ms physical `t_peak`; a readability nudge, not a claim. |
| `coop_hitReactRelMs` | `250` | TEMP | client | release, ms. Total 340 ms; hard-clamped at 400. |
| `coop_hitReactGunArm` | `0.40` | TEMP | client | right-arm scale (locations 7/11/15). The rifle stays on the animation in Stages 1-4. |
| `coop_hitReactHead` | `0.55` | TEMP | client | head/neck scale (locations 0/1/2) |
| `coop_hitReactLarge` | `0.35` | TEMP | client | per-`iLarge` bonus. Not gated on — the `bulletlarge` census does not survive the live mount (an HD pack's `mg42_gun.tik` shadows the retail one and resolves to 0). |
| `coop_hitReactDist` | `1000` | TEMP | client | hard cull, world units. Derived below, not guessed. |
| `coop_hitReactMax` | `8` | TEMP | client | concurrent reactions. 16 actors, ~1 hit/s each, 0.34 s reactions → ~5.4 expected concurrent; 8 gives headroom and matches `RAGBEND_MAX_SLOTS`. |
| `coop_hitReactLegs` | `0` | TEMP | client | Stage 4 gate; legs absent from the table until then. |
| `coop_hitReactDebug` | `0` | TEMP | client | the `^~^~^ HITREACT` prints |
| **`coop_aiHitReact`** | `55` | existing | script | authored flinch rate, %. **Stage 1 sweeps this to 100.** |
| **`coop_aiHitReactWait`** | `1.2` | new, script-defaulted | script | authored flinch throttle, seconds. **Stage 1 sweeps this to 0.4.** |

**`coop_hitReactDist` derivation, re-done because three lenses disagreed.** `cg_fov` defaults 80
(`cg_main.c:243`) and is the **4:3** horizontal FOV; `cg_view.c:1912-1916` widens it for the real
aspect: at 1920×1080, `fov_ratio = 1.3333`, `fov_x = 2·atan(tan(40°)·1.3333) = 96.41°`, so
`k = 960 / tan(48.2°) = 858 px/rad`. A 25 u lever at 16° gives `25·sin(16°) = 6.89 u` of
tip travel; the 6-px legibility floor is crossed at `858 × 6.89 / 6 = 985 u`. **1000 u.** At
2560×1440 the same computation gives ~1310 u — resolution-dependent, so it is a cvar.
(`ragdoll_r13_feel.md`'s table used `k = 1144`, the un-widened 4:3 value, and its 1500/1200
recommendations are 25% too generous at 1080p.)

---

## 6. ACCEPTANCE EVIDENCE

### Stage 1

**Console keys**
```
developer 1 ; coop_bloodDebug 1
coop_aiHitReact 100 ; coop_aiHitReactWait 0.4
```

**Log fields.** Two lines must appear as a pair, from two different modules, for the same round:
```
^~^~^ FLESHHIT dist=%.0f loc=%d pos=(%.0f %.0f %.0f)        <- game.dll, weaputils.cpp:2616
^~^~^ HITREACTMAP loc=%d sfx=%s wg=%s anim=%s               <- script, aihandler.scr (new)
```

**Numeric pass condition.** Shoot a stationary German four times, once per limb, and read the
pair each time:

| where you aim | `loc` must be | `sfx` must be |
|---|---:|---|
| right forearm | 11 | `rarm` |
| left forearm | 12 | `larm` |
| right calf | 13 | `leg` |
| head | 0 or 1 | `head` |

Any row where `sfx` disagrees with the table = the fix did not land. **The pre-fix build prints
`loc=11 sfx=leg`, `loc=12 sfx=rarm`, `loc=13 sfx=larm` — if you still see those, the pk3 did not
deploy.**

**Visual verdict.** With `coop_aiHitReact 100` and `coop_aiHitReactWait 0.4`, shoot a standing
rifleman in the right arm from the front: he must play a **right**-arm flinch (occasionally
dropping the rifle, 30% per `aihandler.scr:1883-1887`), not a back flinch. Fire a burst into one
man: he must flinch repeatedly, not once.

**Failure signature that stops the project.** If correct-limb flinches at 100% / 0.4 s look
*worse* than today — spastic, animation-cancelling, or the actor stops shooting back — then a
procedural layer stacked on top will look worse still, and **Stage 2 is not built.** Back off to
`coop_aiHitReact 55 ; coop_aiHitReactWait 1.2` and ship Stage 1 alone as a correctness fix.

**Success signature that also stops the project (the good outcome).** If it reads as "they react
where I hit them", say so, set the shipping defaults, and **do not build Stages 2-4.**

### Stage 2

**Console keys**
```
developer 1 ; coop_bloodDebug 1 ; coop_hitReactDebug 1
coop_hitReactWire 1 ; coop_hitReact 1 ; coop_hitReactDeg 25
```

**Log fields**
```
^~^~^ HITREACT seed ent=%d loc=%d bone=%s ch=%d pivot=%d tip=%d deg=%.1f dist=%.0f gun=%d
^~^~^ HITREACT done ent=%d ms=%d peak=%.1f residual=%.3f active=%d refused=%d
^~^~^ HITREACT skip ent=%d loc=%d reason=%s
```

**Numeric pass conditions, all four required**

1. **Wire correctness.** For every round, the `loc` in `HITREACT seed` equals the `loc` in the
   `FLESHHIT` line the server printed for the same round — **on a running target as well as a
   standing one.** One mismatch on a moving man kills the wire design.
2. **Channel set.** `ch` must equal the model's true sub-tree size. On the standard 42-bone
   German (`daksoldier.skd` / `gestapo.skd`), a right-forearm hit prints **`ch=2`**
   (`Bip01 R Forearm`, `Bip01 R Hand`) and `bone=Bip01 R Forearm`. On a 61-bone allied ranger the
   same hit prints **`ch=17`**. `ch=0` = table wrong; `ch>24` = a prefix is too loose.
3. **Clean release.** `residual` on the `done` line must read **`0.000`** every time, and `active`
   must return to 0 within 400 ms of the last hit. A nonzero residual means the envelope never
   reaches zero and a limb is welded.
4. **No refusals at normal load.** `refused` must stay 0 with fewer than 8 men under fire. If it
   climbs in an 8-man firefight, raise `coop_hitReactMax`; if it climbs with 3 men, a reaction is
   not being released.

**Visual verdict.** Shoot a *running, firing* German in the **left** forearm from the front:

- his left forearm swings visibly **away from you**, then settles back within about a third of a
  second;
- **his run cycle never stops, stutters, or resets**;
- his right arm, his rifle, his torso, his head and his legs do not move a pixel differently from
  a `coop_hitReact 0` baseline;
- no part of him detaches, stretches, collapses toward the world origin, or flickers.

Then repeat at the edge of `coop_hitReactDist` and inside a doorway (partial occlusion, cull
boundary).

**Failure signatures that stop the project**

- **Any whole-body artifact — collapse, explode, T-pose, a bone at the world origin, even for one
  frame.** That is a short/garbled channel write meeting a cull-skipped frame, and it is the one
  thing the brief says must not happen. Stop, do not tune, diagnose.
- **The run cycle visibly changes.** The bend is supposed to be invisible on untouched channels;
  if the legs stutter, the `else`/cull-gate structure is wrong.
- **`loc` mismatches between the two modules on a moving target.** The wire is the feature's
  entire premise.
- **A corpse renders with one arm in the flinch pose after dying mid-reaction.** The clear is
  behind a guard in `CG_RagdollTransition`.

### Stage 3

`coop_hitReactDeg` swept 25 → 20 → 16 → 12 with the same drill; the number the user stops at
becomes the shipped default. `coop_hitReactHead 0.55` enabled and head shots checked for neck
stretch. Then an 8-man firefight: `refused` must stay low, frame time must not visibly move, and
no corpse over 20 kills may show an anomalous `stretch=` or `span=` on its `RAGDOLL sleep` line
versus a `coop_hitReact 0` baseline.

### Stage 4

Legs only. A running soldier shot in the right calf: the calf must swing and **the foot must stay
planted where the animation put it**. Any float or skate = cut legs permanently.

---

## 7. ROLLBACK — one command per stage

| stage | rollback | effect |
|---|---|---|
| 1 | `coop_aiHitReact 55 ; coop_aiHitReactWait 1.2` | authored flinch back to shipped rate and throttle. The bucket *correctness* fix stays — it is a fix, not a feature, and reverting it restores a defect. To revert it too: `git checkout coop_mod/aihandler.scr` + `.\build.ps1`. |
| 2 | `coop_hitReact 0` | client seeds nothing; the renderer bend pool is never populated; every actor renders bit-exact vanilla (the vanilla copy loop is untouched and Hook A's bend branch finds no slot). Server-side kill switch, if the drop risk ever matters: `coop_hitReactWire 0`. |
| 3 | `coop_hitReactDeg 0` | angle zero → `R_RagdollApplyBend` returns at its `deg <= 0.02f` guard; reactions still seed and release, so the plumbing stays testable while the visual is off. |
| 4 | `coop_hitReactLegs 0` | legs drop out of the table lookup; arms and head keep working. |

---

## 8. RISK REGISTER — top 5 by probability × impact

**R1 — The bend applies to a cache region the vanilla copy never filled.**
*Probability: was high, now designed out. Impact: catastrophic (whole-body garbage on the actor
the player is aiming at).*
The vanilla copy at `tr_model.cpp:826-846` is cull-gated; Hook A's corpse override is deliberately
outside that gate. Copying that placement for the bend would post-multiply stale pool garbage.
**Mitigation:** the `coopVanillaCopied` flag and the `else if` in §4 Stage 2, plus the acceptance
criterion "no whole-body artifact even for one frame". This is the risk the entire Hook A shape
exists to close.

**R2 — Wire/parser lockstep. A stale `cgame.dll` in one of the two deploy roots hard-drops the
client.**
*Probability: medium (bug-1634 and bug-1796 are both exactly this). Impact: high (disconnect, not
a no-op).* `cg_parsemsg.cpp:2120` and `:2470` are `cgi.Error(ERR_DROP, ...)`; the CGM block is one
bit stream with a 1-bit continuation flag, so an unknown id cannot be skipped.
**Mitigation:** `coop_hitReactWire` defaults 0 and is server-side, so an unpatched client is safe
until someone turns it on; the case is added to **both** parsers; `build.ps1:190-206` already ships
exe + both renderers + cgame + game to both roots together; and the release note says "clients
must update".

**R3 — The living bend leaks onto a corpse or welds a limb.**
*Probability: medium. Impact: high (a permanent frozen kink, which is worse than a missing
reaction and is exactly bug-1969's shape).*
`RE_SetRagdollBend`/`RE_ClearRagdollBend` rows have no expiry, so a lost cgame record leaves the
last rotation applied forever.
**Mitigation, three belts:** (a) the renderer refuses a bend while a corpse override exists for
that entity and Hook A's `else` makes them mutually exclusive; (b) `CG_HitReactClearEnt` is the
**first statement** of `CG_RagdollTransition`, above all four early returns at
`cg_ragdoll.c:2294-2306`; (c) `CG_HitReactFrame` clears — never skips — whenever the entity leaves
the snapshot, dies, gains a parent, or exceeds the cull distance.

**R4 — Stage 1 turns out to be enough and Stages 2-4 were never needed.**
*Probability: genuinely material. Impact: two or three wasted engine sessions.*
**Mitigation:** this is why Stage 1 ships **alone**, as its own build, and why §1 states plainly
that a satisfied user should stop. The engine work is not started until Stage 1 has been looked at
live.

**R5 — `CL_TraceDeep` is revived.**
*Probability: very low. Impact: catastrophic (the feature becomes a hit-detection bug).*
`qcommon/cm_trace_lbd.cpp:578` calls `re.TIKI_Orientation` — Hook B — inside client-side deep
trace code that today has **zero callers**. If anyone ever wires it up on a listen host, both the
corpse override and this feature start feeding client-side traces.
**Mitigation:** a comment at `cm_trace_lbd.cpp:533` marking the function dead and load-bearing if
revived, plus a line in `docs/TRAPS.md`. One comment, no code.

---

## 9. RELATIONSHIP TO THE UNFINISHED CORPSE WORK

`ragdoll_r11_spec.md` designed two things that are still unbuilt. Confirmed by grep this session:

- **Stage 2, feet and knees.** `RAG_PTS` is still **15** (`cg_ragdoll.c:58`) against the designed
  17, and `s_ragDriveChild[12]` / `[14]` are still `-1` (`:113-116`). The consequence documented
  in r11 §0 item 3 is live: `driveDir0[11]` and `restDir[12]` are set to the *same vector* at
  capture, so `RagMat3FromTo` is called with identical arguments for both and **the calf receives
  a bit-identical copy of the thigh's rotation, every frame.**
- **Stage 3, the 18 angular joint limits.** `grep -c "RagLimit\|RagRotateSet" cg_ragdoll.c`
  returns **0**. Nothing was built. `coop_ragdollTruss` (`:342`) is the experiment knob that was
  supposed to motivate them.

*(r11 §0 item 1, the negative shape-match alpha, **was** fixed: `limpMax[]` at `:204` and the
per-point `span` at `:966` replaced the fixed `RAG_IMPACT_LIMP_MS` divisor.)*

**Does this feature depend on them? No.** Zero dependency in either direction. The living bend
shares no solver, no point cloud, no constraint, no collision, no capture, and no pose.

**Does it share code with them? Only conventions and one file.**

| shared | detail |
|---|---|
| `hitloc_t` → bone name | `szLocArray[]` (`cm_trace_lbd.cpp:31-50`) is the source of truth for the bend table and for `s_ragBones[]` |
| the row-vector primitive | `RagMat3FromTo` (`cg_ragdoll.c:482-536`) is ported verbatim into `tr_ragdoll.cpp` as `R_BendMat3FromTo` |
| the `^~^~^` print prefix and the `coop_*` TEMP-cvar convention | |
| **the two `tr_ragdoll.cpp` files** | the bend pool lands beside `s_ragSlots[]` in both renderers, which are byte-identical today and must stay so |
| `build.ps1`'s five-binary ship | |

**Do they compete for the same time? Yes, and for the same file.** Both want engine-build sessions,
and both edit `renderergl1/tr_ragdoll.cpp` + `renderergl2/tr_ragdoll.cpp`.

**Recommended order**

1. **Stage 1 (script).** One build, zero binary risk, and a hard gate. It is a prerequisite for the
   procedural layer either way — until the buckets are right, a procedural bend on the left arm
   and an authored flinch on the right arm point at opposite limbs, which is worse than neither.
2. **If Stage 1 satisfies: stop the living-reaction project** and spend the next engine session on
   **r11 Stage 2 (feet/knees)**. It is the cheapest remaining win in the whole ragdoll area — the
   calf-copies-thigh defect is visible on *every* corpse, the subsystem is proven, and it has
   existing instruments (`swing=`, `stretch=`, `span=`, `contacts=`, `worldtr=`), static bodies,
   zero hit-detection surface, and no wire or ABI change.
3. **If Stage 1 does not satisfy: build Stages 2-4 next**, before any further corpse work. The
   user asked for living reactions; corpse feet are my backlog, not theirs, and making them wait
   two sessions for something they did not request is the wrong trade.
4. **r11 Stage 3 (the 18 joint limits) last, in either branch.** It is the largest and least
   certain of the four items, it is motivated by an experiment (`coop_ragdollTruss 0`) whose
   result already refuted its original premise, and nothing else waits on it.

**One coupling rule if both proceed:** whoever edits `tr_ragdoll.cpp` next re-runs
`diff renderergl1/tr_ragdoll.cpp renderergl2/tr_ragdoll.cpp` before committing. It returns nothing
today. bug-1796 is what happens when the two renderers drift.

---

## APPENDIX A — VERIFICATION LOG (this session, source-checked)

**Confirmed exactly**
`tiki_mesh.cpp:29`, 19 `TIKI_Skel_Bones` refs all renderer/tiki · `grep "\bre\." server/*.c` empty ·
`CL_TraceDeep` zero callers (`cm_trace_lbd.cpp:530,533`) · server chain `sv_world.c:581-585` →
`cm_trace_lbd.cpp:444,486` → `g_main.cpp:909,913,915` → `tiki_tag.cpp:94,105` · `G_UpdatePoseInternal`
latch `g_main.cpp:896,901`, frame value `:996-998` ← `sv_main.c:1008` ← `common.c:2263` ·
renderer latch `tr_model.cpp:1773-1776`, `RE_SetFrameNumber:1760-1762` ← `cl_main.cpp:2645-2650` ←
`common.c:2273` · `SV_Frame` `common.c:2388` before `CL_Frame` `:2433` · no direct
`gi.TIKI_OrientationInternal` in `fgame/` outside `g_main.cpp:915` · `animPose` written at
`tr_ragdoll.cpp:124-137` (both renderers), **zero readers tree-wide** · Hook A `tr_model.cpp:857-860`
outside the cull gate at `:826-828` · space conversion `tr_ragdoll.cpp:139-156` (`*ils - lo`) vs
`tiki_tag.cpp:107-110` (`(val+lo)*scale*load_scale`) vs `RagCapture` `cg_ragdoll.c:610-613`
(`/scale`) · row-vector convention and post-multiply `cg_ragdoll.c:401,406-416,482-536,1387-1392` ·
`RagMat3FromTo` antiparallel fallback `:493-517` · `RAG_PTS 15` `:58`, `s_ragDriveChild[12]/[14] = -1`
`:113-116`, `RagLimit` count **0** · `limpMax[]` `:204`, per-point `span` `:966` (r11 item 1 fixed) ·
`CG_RagdollImpulse` `cg.snap` deref `:1460` behind a guard at `:1449` that does not test it ·
`CG_RagdollTransition` early returns `:2294-2306` · segment search + torque couple `:1512-1595` ·
cvars `:317-353` · `hitloc_t` `q_shared.h:1426-1449` · `szLocArray[]`/`fLocRadius[]`
`cm_trace_lbd.cpp:31-53` · `anim/pain.scr:5-23` · `weaputils.cpp:2606,2616,2620-2647` ·
`cg_parsemsg.cpp:1688,1768-1778,1799,1808,2120,2128,2470` · `CGM_FENCEPOST = 41`
`bg_public.h:750-792` · `BG_MapCGMToProtocol` `bg_misc.cpp:392-419` · CGM type 6 bits
`sv_game.c:398` · bridge `tr_public.h:189-191`, `cg_public.h:453-455`, `tr_init.c:2101`,
`cl_cgame.cpp:813` · `build.ps1:190-206` ships exe + cgame + game + both renderers + ded to both
roots · `diff renderergl1/tr_ragdoll.cpp renderergl2/tr_ragdoll.cpp` empty ·
`aihandler.scr:1749-1845` = **94** whitelist entries / **21** weapongroup_stance combos,
`:1850-1852` 55%, `:1859` prone skip, `:1861-1862` 1.2 s, `:1864-1872` the mis-map,
`:1883-1887` dropgun, `:1888` `setmotionanim` · `coop_defaults.cfg:364` ·
`autoexec.cfg:684 seta sv_fps 40`.

**Refuted or corrected**
brief's bug-1971 → it is `officer.scr`/`mg42_hack.scr` surrender work; the space defects are
1962/1963/1964 · `ragdoll_r13_feel.md`'s "2 weapongroup_stance combos covered" → 21 ·
`ragdoll_r13_feel.md`'s `k = 1144 px/rad` → 858 at 1920×1080 (`cg_view.c:1912-1916` widens the
4:3 `cg_fov`) · `ragdoll_r13_trigger.md`/`_feel.md` "client `ForceUpdatePose` corrupts hit
detection" → the latch namespaces are disjoint and `SV_Frame` completes before `CL_Frame` ·
`ragdoll_r13_blend.md`'s bridge append points (mid-struct) → tails only · the 60.5° corpse
swing has no in-repo instrument record (`ragdoll_r12_spec.md:39` = 10.05 measured, `:44` = 21.1
projected), so no target here is derived from it.

**Tooling defect found, unfixed, filed here**
`docs/tools/ragdoll_channel_census.py:81` advances the SKD bone-record cursor by a fixed
`o += 84`; the correct walk is the per-record `ofsEnd` at `+80`, as `count_skel_channels.py:129-132`
already does. The fixed stride desynchronises and truncates. Its MAX-union number is unreliable
until fixed — do not size anything from it. The 106-name / 45-SKD union used in §3.6 was produced
with the corrected walk.
