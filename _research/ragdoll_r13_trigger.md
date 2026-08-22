# Ragdoll R13 — the trigger and the data (living hit reactions)

**Lens:** what tells the client a *living* soldier was hit, and *where*.
**Date:** 2026-08-20 · **Mode:** read-only audit of source. Every claim below carries a
`file:line`. Where a number is measured-from-code it says so; where it is a projection it says
**inferred**.

---

## 0. Verdict up front

| Question | Answer |
|---|---|
| Does a living flesh hit already send a message? | **Yes** — the *same* `CGM_BULLET_8` the corpse path uses. `weaputils.cpp:2606` gates on `trace.location >= 0 && ent->IsSubclassOfSentient()`, which is true for a living `Actor` (ET_MODELANIM, SOLID_BBOX, `actor.cpp:2915/2926`). Nothing new is needed to *know that a hit happened*. |
| Can the client tell **which entity**? | **No.** The message carries position, direction, size class — no entity reference (`cg_parsemsg.cpp:1774-1778`). |
| Is position matching enough for a *moving* actor? | **No, not for limb selection.** Render lags the message's server frame by up to one snapshot (50 ms at `sv_fps 20`, `sv_init.c:1108`); at `sv_runspeed 287` (`gamecvars.cpp:381`) that is **14.4 u** of displacement against a **15 u** bone-match radius and **18-24 u** limb spacing. |
| Is `trace.location` sent to the client? | **No, nowhere.** It exists server-side on every flesh hit and is thrown away at the wire. |
| **Definite answer** | **Add BOTH: 11-bit entity number + 5-bit hit location, appended to `CGM_BULLET_8`. 16 bits, +21.6 % on a 74-bit message. Ships `game.dll` + `cgame.dll` together — no exe, no protocol constant.** |
| Pain-system coexistence rule | **The procedural layer rides ON TOP and never suppresses.** It drives *only* the struck limb's channels, blended against `animPose`; the authored anim keeps whole-body authority. See §5. |

---

## 1. The message path, end to end

### 1.1 Server — where a living flesh hit is produced

`BulletAttack()` — `fgame/weaputils.cpp:2273`. Per fire event it loops **once per pellet**
(`:2406`, `for (i = 0; i < count; i++)` where `count` = the TIKI's `bulletcount`).

Per pellet:

1. `trace = G_Trace(..., "BulletAttack", true)` — `:2436-2438`. The trailing `true` is the **deep**
   flag: `SV_TraceDeep` (`qcommon/cm_trace_lbd.cpp:444`) runs the 19-sphere bone test.
2. `vTmpEnd = trace.endpos` — `:2440`. World-space, bone-accurate.
3. `ent->Damage(..., trace.location)` — `:2571`, inside `if (ent->takedamage)`.
4. **The message send is OUTSIDE the `takedamage` block** (`:2606`) — so a corpse and a living
   actor both fire it, and a living actor fires it even when the damage is later swallowed
   (friendly fire, `m_bEnablePain == false`).

Send block, verbatim structure:

```
:2606   } else if (trace.location >= 0 && ent->IsSubclassOfSentient()) {
:2616       gi.Printf("^~^~^ FLESHHIT dist=%.0f loc=%d pos=(%.0f %.0f %.0f)\n", ...)   // coop_bloodDebug 1
:2620       gi.SetBroadcastVisible(vTmpEnd, vBarrel);
:2621       gi.MSG_StartCGM(BG_MapCGMToProtocol(g_protocol, CGM_BULLET_8));
:2622-24    gi.MSG_WriteCoord(vTmpEnd[0..2]);
:2638       Vector vHitDir = Vector(vBarrel) - Vector(vTmpEnd);      // the 2026-08-20 fix
:2641       gi.MSG_WriteDir(vHitDir);
:2646       gi.MSG_WriteBits(bulletlarge, bulletbits);
:2647       gi.MSG_EndCGM();
```

**The direction fix benefits living hits identically.** The defect it repaired is upstream of the
alive/dead split: `CM_TraceDeepSimple` (`cm_trace_lbd.cpp:215-264`) inflates the entity box by
**+40 u on every axis** (`:234-239`), traces it in the entity's **yaw-local** frame
(`AngleVectorsLeft`, `:242`) and never rotates the resulting plane back; the bone-sphere test
(`LineSegmentToSphereIntersect`, `:111`) writes **only `pTrace->fraction`** (`:170`). So
`trace.plane.normal` was a constant for every deep hit — living or dead. `:2638` now sends the
true wound→muzzle normal.

**`trace.location` is genuinely correct on living actors** — `SV_TraceDeep` reads the bone
orientation live from the game module (`ge->TIKI_Orientation(touch, iBoneNum)`, `:486`) and
returns the **first** of 19 spheres the segment intersects, in table order (`:475-497`). The
`endpos` it hands back is world-space and bone-accurate: `CM_TraceDeepSuccess` (`:345-357`)
reconstructs it from the *world* `vStart`/`vEnd` and the fraction, and the local-frame transform
is a pure rotation+translation so the parameterisation is preserved.

### 1.2 What is on the wire today

Written by `PF_MSG_*` in `server/sv_game.c`:

| Field | Writer | Wire bits | Staging bytes | Precision |
|---|---|---:|---:|---|
| block continuation | `PF_MSG_StartCGM:396` | 1 | 1 | — |
| message type | `PF_MSG_StartCGM:399` | 6 | 1 | 0-63; **42-63 unused** |
| impact pos ×3 | `PF_MSG_WriteCoord:347` | 3 × 19 = 57 | 3 × 4 = 12 | `(int)(f*16)` → **1/16 u** |
| direction | `PF_MSG_WriteDir:368` | 8 | 1 | `DirToByte` → 162-entry `bytedirs` (`q_shared.h:441`) ⇒ **≈9° worst-case, ~5-6° typical** |
| `bulletlarge` | `MSG_WriteBits(.,2)` | 2 | 1 | 0-3; `bulletbits` = 2 at proto ≥ 15, 1 below (`weaputils.cpp:2357/2360`) |
| **total** | | **74 bits (9.25 B)** | **16 B** | |

The first message in a block costs 81 bits (an 8-bit `svc_cgameMessage` byte replaces the
continuation bit, `PF_MSG_StartCGM:393`), plus a trailing 0 bit per block
(`SV_WriteCGMToClient:530`).

Two accountings matter and they are **not** the same:
* **wire bits** — cheap; a 20-pellet shotgun burst that all connects is 20 × 74 = 1480 bits = 185 B.
* **staging bytes** — the real cap. `MSG_WriteCGMBits` (`sv_game.c:180`) stores **1 byte per
  ≤8-bit field, 2 per ≤16, 4 per ≤32**, so the same burst costs **320 staging bytes**. The
  broadcast setters refuse a client once `cursize >= 3968` (`:435`, `:499`) → an effective budget
  of **3968 staging bytes per client per server frame ≈ 248 flesh messages**, shared with tracers,
  wall impacts and HUD draws.

### 1.3 Delivery — who gets it

`gi.SetBroadcastVisible(vTmpEnd, vBarrel)` → `MSG_SetBroadcastVisible` (`sv_game.c:444`). For each
connected client it takes the client's PVS and accepts if **either** the impact **or** the muzzle
cluster is visible **and** areas are connected (`:491-495`). **Confirmed: the message reaches the
PVS of both the impact and the shooter.** Other players' hits are therefore visible to you, and
your hits on a distant target are visible to you. (That second half is an HZM change — the vanilla
call passed `NULL` for the second position.)

### 1.4 Client — where it is parsed, and *when*

`svc_cgameMessage` → `CL_ParseCGMessage` (`client/cl_parse.cpp:1018`) → `cge->CG_ParseCGMessage`
→ `CG_ParseCGMessage_ver_15` (`cgame/cg_parsemsg.cpp:1674`; `_ver_6` at `:2128` for protocol < 15,
selected in `CG_InitCGMessageAPI:2478`). Coop runs `com_target_game 2` → protocol 17
(`q_shared.h:269-276`), i.e. the **ver_15** path; ver_6 stays live for legacy clients and any wire
change must be mirrored there (`CGM6_BULLET_7`/`CGM6_BULLET_8` are the legacy flesh pair,
`cg_parsemsg.cpp:2204-2205`).

Parse, `:1774-1778`:

```
vStart[0..2] = cgi.MSG_ReadCoord();
cgi.MSG_ReadDir(vEnd);
iLarge = cgi.MSG_ReadBits(2);
...
case CGM_BULLET_8:                       // :1799
    VectorNegate(vEnd, vEnd);            // :1802 - client flips to travel direction
    flesh_impact_pos/norm/large[...]     // :1803-1806, consumed later by CG_AddBulletImpacts
    CG_RagdollImpulse(vStart, vEnd, 150+70*iLarge, 15+1.5*iLarge, 600+70*iLarge);   // :1808
```

**Ordering, and it is decisive.** In the outgoing packet the server writes
`SV_WriteSnapshotToClient` at `sv_snapshot.c:1266` **before** `SV_WriteCGMToClient` at `:1275`. So
when `CG_ParseCGMessage` runs, `cl.snap` for the message's own server frame has already been
parsed — but **`cg.snap` has not moved**: the cgame's `cg.snap`/`cg.nextSnap` are only advanced in
`CG_ProcessSnapshots` (`cg_snapshot.c:449`), which runs inside `CG_DrawActiveFrame`
(`cg_view.c:2921`).

Consequences, all proven:

* At parse time `cg.snap` is the snapshot currently being **rendered**, bounded by
  `cg.snap->serverTime <= cg.time < cg.nextSnap->serverTime` (`cg_snapshot.c:510`) — i.e. one to
  two snapshots behind the message.
* `cent->lerpOrigin` at parse time is **last frame's** value: it is written by
  `CG_CalcEntityLerpPositions` (`cg_ents.c:476`) from `CG_AddCEntity` (`:566`), reached only from
  `CG_AddPacketEntities` at `cg_view.c:3078`.
* `CG_RagdollFrame()` (`cg_view.c:2928`) runs *after* `CG_ProcessSnapshots` but *before*
  `cg.frameInterpolation` is computed (`:2938-2942`) and long before `CG_AddPacketEntities`.
* `CG_AddBulletImpacts()` (`cg_view.c:3108`) is the existing precedent for **deferring** a parsed
  event to the render frame. **A living-actor reaction must use that pattern**: the parse handler
  records into a small queue, the match runs in the frame. Doing entity/limb matching at parse
  time reads stale positions by construction.

---

## 2. Can the client identify the entity itself?

### 2.1 What the corpse path does, and why it does not generalise

`CG_RagdollImpulse` (`cg_ragdoll.c:1443`) never needs an entity number: it walks all 16 sim slots
and, for each, finds the closest of the **14 bone segments** (`:1515-1536`), rejecting the body if
`bestD >= radius` (`:1538`). Position alone is sufficient because a settled corpse is **static** —
`RagCapture` snapshots `cent->lerpOrigin` once (`:602`) and the body does not move again.

A living actor is being animated and translated every frame. Two error terms appear:

### 2.2 The temporal skew, re-derived

`sv_fps` default **20** (`server/sv_init.c:1108`) → 50 ms per server frame; `sv.frameTime = 1/sv_fps`
(`sv_init.c:556`). In steady state the client renders at `cg.time`, which sits inside
`[cg.snap->serverTime, cg.nextSnap->serverTime)` — i.e. **the rendered pose is up to one full
snapshot interval behind the pose the server used to compute the impact position**, before any
`cl_timeNudge` or packet jitter.

Displacement over 50 ms:

| Speed | Source | Error |
|---|---|---:|
| 250 u/s | `sv_runspeed` in SP mode (`gamecvars.cpp:399`, `level.cpp:1968`) | **12.5 u** |
| 287 u/s | `sv_runspeed` default (`gamecvars.cpp:381`) | **14.4 u** |
| ~0 | crouched / in cover / MG42 gunner | ~0 u |

Compare against the things that must be resolved:

* corpse-path bone-segment match radius: `15.0 + 1.5*iLarge` u (`cg_parsemsg.cpp:1808`) → **15-19.5 u**;
* the 19 hit spheres themselves: radius **4.0-9.0 u** (`cm_trace_lbd.cpp:53-55`);
* limb separation on the sim skeleton: hips ≈ 18 u apart, shoulders ≈ 24 u (recorded in
  `cg_ragdoll.c:1643-1646`).

**So a 12-14 u error is the same order as the discriminant.** A running soldier's left and right
arms can swap; a leg hit can land on the pelvis. Standing/crouched enemies are fine — but this mod
now actively pushes AI to move (`coop_aiDynamic`, juke/hide timers), so "they stand still" is no
longer a safe assumption.

There *is* a way to remove most of it without a wire change (recorded so the option is on the
table, not because it is recommended): defer to the frame, then transform the impact point into the
actor's **model-local** frame using `cent->nextState.origin/angles` — the *exact* server state at
the message's server time, no interpolation — and match against the rendered pose in that same
local frame. That cancels the translation term entirely and leaves only the limb-swing term
(**inferred** ≈ 5 u for an arm over 50 ms, from a ~0.6 s swing cycle). The cost is that the client
must pose-evaluate every candidate, and `RagCapture`'s own warning applies — `cgi.ForceUpdatePose`
"stamps `tr.skel_index[entnum]`" (`cg_ragdoll.c:605`), so posing a **living** entity with a
different `frameInfo` than the render pass will use is exactly the class of interference the
constraints forbid. **Do not build this to save 16 bits.**

### 2.3 What the client *can* cheaply do, with no wire change

* **Enumerate candidates** from `cg.snap->entities` filtering `eType == ET_MODELANIM`,
  `modelindex > 0`, `number >= cgs.maxclients` — the corpse re-arm scan already does exactly this
  (`cg_ragdoll.c:1460-1470`).
* **Read the true server bbox** — `IntegerToBoundingBox(es->solid, bmin, bmax)`
  (`cg_ragdoll.c:2102`, already used). Living standing = `(-15,-15,0)..(15,15,94)`
  (`bg_public.h:32-37`); a parked corpse = `(-32,-32,0)..(32,32,16)`
  (`actor.cpp:12492`). So living/dead is distinguishable two ways (bbox shape and
  `eFlags & EF_DEAD`, `bg_public.h:414`).
* **Reject the local player and other players** by `number < cgs.maxclients`.

That gets the client to a small candidate set cheaply and reliably. It does **not** get it to the
right *limb*.

### 2.4 Verdict on the entity number

**Send it.** Reasons, in order of weight:

1. **It removes an ambiguity class that has no client-side answer.** Two soldiers overlapping (one
   walking behind another) put the impact inside both bboxes; the bullet stopped at the first, and
   nothing in the message says which.
2. **It answers "was he alive?" exactly.** Today `CG_RagdollImpulse` only touches `EF_DEAD` bodies,
   so a living hit is silently discarded. Once a living path exists, a round into a corpse lying at
   a standing soldier's feet must not kick the soldier — the two bodies' bboxes overlap in XY by
   construction (`±32` corpse slab vs `±15` standing box).
3. **It costs `GENTITYNUM_BITS` = 11** (`q_shared.h:1667`) and nothing else. It is not a protocol
   *constant*; it is a payload field.
4. It lets the false-trigger path be tagged. `Actor::EventDamagePuff` (`actor.cpp:6026-6046`)
   sends the **same** `CGM_BULLET_8` from a *script-supplied* position and direction. In this mod
   that path is currently inert — `anim/killed.scr:45` wraps it in `if(0)` and
   `anim/dog_killed.scr:7` gates it to `level.gametype == 0` — but it is reachable from any map
   script, and it has no `trace` behind it at all. Writing `ENTITYNUM_NONE` there makes it
   ignorable in one comparison.

---

## 3. `trace.location` — the hit-location table

### 3.1 What it is

`hitloc_t`, `qcommon/q_shared.h:1426-1449`: `HITLOC_MISS = -2`, `HITLOC_GENERAL = -1`, then
**19 codes 0-18**, `NUMBODYLOCATIONS = 19`. Each code is a named `Bip01` tag plus a primary and
secondary sphere (radius + offset), `cm_trace_lbd.cpp:31-100`:

```
0 HEAD "Bip01 Head" r5.0    7  R_ARM_UPPER "Bip01 R UpperArm" r7.0   14 L_LEG_LOWER "Bip01 L Calf" r7.5
1 HELMET "Bip01 Head" r5.5  8  L_ARM_UPPER "Bip01 L UpperArm" r7.0   15 R_HAND "Bip01 R Hand" r6.0
2 NECK "Bip01 Neck" r4.0    9  R_LEG_UPPER "Bip01 R Thigh" r8.0      16 L_HAND "Bip01 L Hand" r6.0
3 TORSO_UPPER "Spine2" r9.0 10 L_LEG_UPPER "Bip01 L Thigh" r8.0      17 R_FOOT "Bip01 R Foot" r6.0
4 TORSO_MID "Spine1" r8.0   11 R_ARM_LOWER "Bip01 R Forearm" r5.5    18 L_FOOT "Bip01 L Foot" r6.0
5 TORSO_LOWER "Spine" r9.0  12 L_ARM_LOWER "Bip01 L Forearm" r5.5
6 PELVIS "Bip01 Pelvis" r9.0 13 R_LEG_LOWER "Bip01 R Calf" r7.5
```

`SV_TraceDeep:475-497` returns the **first** sphere in that table order that the segment intersects
— not the nearest — so head/helmet/neck/torso win ties against limbs. That is a property to
document, not a defect: it is what `anim/pain.scr` and `anim/killed.scr` have always consumed.

### 3.2 Is it networked anywhere? **No.**

Grepped every `MSG_Write*` in `fgame/`. The location reaches:

* `Entity::Damage(..., trace.location)` → `EV_Damage` → the pain/killed chain, **server-side only**;
* `Sentient::ArmorDamage` (`sentient.cpp:1535`, `:2731`, `:2786` via
  `gi.CM_GetHitLocationInfo` for wound-prop placement) — **server-side only**;
* the `coop_bloodDebug` console line at `weaputils.cpp:2616` — **console only**.

`CM_GetHitLocationInfo` is exported to the **game** module (`fgame/g_public.h:417-418`) and is
**absent from the cgame import struct** (`cgame/cg_public.h` — verified; the client has
`CM_BoxTrace:177`, `ForceUpdatePose:408`, `TIKI_Orientation:409`, `Tag_NumForName`/`Tag_NameForNum`
at `:405-406`, and the HZM ragdoll bridge at `:453-455`, but no hit-location accessor). So the
client cannot even look up the table today without re-declaring it.

The only per-hit message that *does* reach a client with any hit semantics is `CGM_NOTIFY_HIT`
(`player.cpp:3719`), and it is **payload-free** — `MSG_StartCGM` then `MSG_EndCGM`, aimed at one
client via `MSG_SetClient`, purely to play `dm_hit_notify` (`cg_parsemsg.cpp:2030-2046`). It also
only fires for **player-on-player** damage in non-SP (`player.cpp:3714`). Useless here.

### 3.3 The 19 → 15 mapping is exact and lossless

Every hit-location code lands on a sim point of the existing 15-bone set (`cg_ragdoll.c:76-92`):

| loc | tag | sim pt | loc | tag | sim pt |
|---:|---|---:|---:|---|---:|
| 0,1 | Head | **4** | 9 | R Thigh | **13** |
| 2 | Neck | **3** | 10 | L Thigh | **11** |
| 3 | Spine2 | **2** | 11 | R Forearm | **9** |
| 4 | Spine1 | **1** | 12 | L Forearm | **6** |
| 5 | Spine | **1** (no sim pt; between Pelvis and Spine1) | 13 | R Calf | **14** |
| 6 | Pelvis | **0** | 14 | L Calf | **12** |
| 7 | R UpperArm | **8** | 15 | R Hand | **10** |
| 8 | L UpperArm | **5** | 16 | L Hand | **7** |
| | | | 17 | R Foot | **14** (calf is the leaf today) |
| | | | 18 | L Foot | **12** |

Two codes (5, 17/18) fold onto a neighbour because the sim has no `Spine`/`Foot` point. Nothing is
ambiguous, nothing needs a distance test, and the mapping is a 19-entry `static const int` table.

### 3.4 Verdict on the hit location

**Send it. This is the single highest-value field in the whole proposal.** The user's ask is
"react to *where the round landed*". The engine already computes exactly that, authoritatively,
from the server's live skeleton, on every flesh hit — and then discards it. Five bits carry codes
0-18. The client cannot recompute it to the same accuracy for a moving actor (§2.2), and cannot
recompute it *at all* without either re-declaring the sphere table or pose-evaluating candidates.

---

## 4. The wire change — exact cost and blast radius

### 4.1 Recommended shape

Append two fields to `CGM_BULLET_8` (and its `CGM6` twin), **after** the existing three, so the
existing readers' field order is unchanged and the diff is additive at both ends:

```
gi.MSG_WriteBits(entnum, GENTITYNUM_BITS);   // 11 bits; ENTITYNUM_NONE from EventDamagePuff
gi.MSG_WriteBits(trace.location, 5);         // 0..18, guaranteed >= 0 by the :2606 gate
```

`trace.entityNum` is already populated by `CM_TraceDeepSuccess` (`cm_trace_lbd.cpp:355`) and
`ent->entnum` is in hand at the send site.

### 4.2 Cost, re-derived

| | today | with entnum + loc | delta |
|---|---:|---:|---:|
| wire bits / message | 74 | **90** | +16 (+21.6 %) |
| staging bytes / message | 16 | **19** | +3 (+18.8 %) |
| 20-pellet shotgun burst, wire | 185 B | **225 B** | +40 B |
| 20-pellet shotgun burst, staging | 320 B | **380 B** | +60 B |
| flesh messages per client per frame before the 3968 B refusal | ~248 | **~208** | −16 % headroom |

Worst realistic frame (**inferred**): 4 coop players, all on shotguns, all connecting all pellets
in the same 50 ms server frame = 80 messages = 1520 staging bytes — 38 % of the budget, shared with
tracers (a `CGM_BULLET_1` costs ~40 staging bytes) and HUD traffic. Comfortable, but the margin is
smaller than the wire numbers suggest, so quote the **staging** figure in any future review.

### 4.3 Which binaries

**`game.dll` + `cgame.dll`, together. Not the exe, not the renderer.** The exe is payload-blind:
`PF_MSG_*` (`sv_game.c:180-448`) stages `(value, bitwidth)` pairs and `SV_WriteCGMToClient`
(`sv_game.c:514`) replays them verbatim; `CL_ParseCGMessage` (`cl_parse.cpp:1018`) hands straight
to the cgame. Contrast the constants table in `docs/ENGINE.md#protocol-coupling`: this is *not* a
`GENTITYNUM_BITS`-class change, it is the "anything cgame-visible → remote clients need the updated
cgame.dll" row.

`BG_MapCGMToProtocol` needs no edit: `CGM_BULLET_8` = 8, and the mapper returns ids ≤ 10 unchanged
for both protocol families (`bg_misc.cpp:392-418`).

### 4.4 The failure mode, stated plainly

The CGM block is a **length-free bitstream**. One extra field read by a client that does not expect
it — or written by a server a client does not match — desynchronises **every subsequent message in
the block**, and the outer switch ends at
`cgi.Error(ERR_DROP, "CG_ParseCGMessage: Unknown CGM message type")`
(`cg_parsemsg.cpp:2120` ver_15, `:2470` ver_6). That is a **hard disconnect on the first flesh hit**
for any player running a mismatched `cgame.dll`. It is loud, immediate and unmistakable — which is
the good version of this risk — but it must be called out in the release note, and both parse paths
must be edited in the same commit.

### 4.5 The alternative that was considered and rejected

A **new** CGM id. The type field is 6 bits and ids **42-63 are free** (the ver_15 enum ends at
`CGM_FENCEPOST = 41`, `bg_public.h:792`, which is a real message — `Entities.cpp:2342`), and
`BG_MapCGMToProtocol` passes `> 40` through untranslated for both families (`bg_misc.cpp:401`).
Tempting, and it keeps `CGM_BULLET_8` byte-identical.

**It does not help.** A broadcast new id lands on an old parser as an unknown type → the same
`ERR_DROP`. Making it safe requires per-client gating: `gi.MSG_SetClient` (`g_public.h:297`) plus
`gi.GetUserinfo` (`:304`) for a capability flag — and there is a precedent for the flag
(`cg_main.c:191` registers `coop_wussCount` as `CVAR_USERINFO`). But `PF_MSG_SetClient`
(`sv_game.c:408`) **memsets the recipient mask and sets exactly one client**, so it cannot be
intersected with `SetBroadcastVisible`; the game module would have to re-implement the PVS test per
client. That is more code, more per-message cost (a second message), and a second wire format to
keep in step — to protect a configuration (mixed builds) that this project does not support anyway.
**Extend `CGM_BULLET_8`.**

---

## 5. Coexistence with the existing pain / hit-reaction system

### 5.1 What exists today — the full chain, in order

```
Actor::HandlePain                  fgame/actor.cpp:5356
  ├─ early-out if !m_bEnablePain                                   :5364
  ├─ early-out if attacker IsTeamMate                              :5368
  ├─ early-out (script only) if m_bNoLongPain                      :5372
  ├─ ExecuteScript(STRING_GLOBAL_PAIN_SCR)                         :5374-5380
  └─ SetThinkState(THINKSTATE_PAIN, THINKLEVEL_PAIN)               :5381   <- whole-body authority

global/pain.scr::start
  ├─ same-frame re-entrancy guard: coop_painFrame == level.time -> end     :19-23
  └─ coop branch -> aihandler.scr::actorPainHandler                        :26-37

coop_mod/aihandler.scr::actorPainHandler                          :914
  ├─ writes self.fact.* incl. .location                           :927-940
  ├─ restores the coop_aiBuffer health                            :977-991
  ├─ friendlyFireCheck  -> end for player->allied and team hits    :1018-1027
  └─ thread handlePain                                             :999  (label :1031)
        ├─ coop_actorActualHealth -= damage                        :1039
        ├─ if still alive: wounded/tactical retreat threads        :1043-1046
        ├─ if still alive: self thread coop_hitReact               :1050
        └─ else: the 150000 overkill                               :1060

coop_mod/aihandler.scr::coop_hitReact                             :1848
  ├─ coop_aiHitReact % roll (default 55, coop_defaults.cfg:364)    :1850-1852
  ├─ not if prone                                                   :1859
  ├─ per-actor throttle: 1.2 s                                      :1861-1862
  ├─ self.fact.location -> sfx bucket head/back/larm/rarm/leg       :1863-1872
  ├─ whitelist check level.coop_hitOK[wg_stance_sfx]                :1878-1881
  ├─ 30 % dropgun variant for arm hits (rifle/thompson)             :1884-1889
  ├─ self.blendtime 0.15; self setmotionanim <wg>_<stance>_hit_<sfx>:1890-1891
  └─ behav_bump "hitreact"   -> the AIBEHAV3 counter                :1892
```

Also live: `anim/pain.scr` (the vanilla knees/crawl/floor state machine, `:36-512`) is **not**
reached through `global/pain.scr` in this mod — the non-coop branch writes `self.fact` and `end`s
(`global/pain.scr:39-63`). It is still reachable through `self.painhandler` set by idle/corner anim
scripts (`anim/cornerleft.scr:63`, `anim/mg42_idle.scr:6`, `anim/pain.scr:373`).

Two exclusion sets matter:

* `level.coop_painHandlerExclusions = m3l1a, m2l2a, m2l2b, m6l1c, e1l1, e1l3, e1l4, e2l1`
  (`coop_mod/variables.scr:114`) — on these **eight maps there is no coop flinch at all**.
* `friendlyFireCheck` — a player shooting an **allied** AI produces **no** pain, **no** flinch —
  but `weaputils.cpp:2606` still sends the flesh message (it is outside `takedamage`). So the
  message fires in cases the authored layer deliberately ignores.

### 5.2 What the authored layer does well, and what it cannot do

**Does well — do not duplicate:**
* Whole-body, weapon-and-stance-correct stagger, hand-animated, blended at 0.15 s.
* Directional in the coarse sense (head / back / left arm / right arm / leg).
* Gameplay consequence: `THINKSTATE_PAIN` interrupts the attack, raises alertness, sets
  `m_pLastAttacker` and can pull the actor out of idle (`actor.cpp:5381-5400`). **A procedural
  layer must not touch any of that.**
* Narrative beats the physics cannot invent: the gun-drop, the stand→knees collapse.

**Cannot do — this is the whole gap:**
* It knows **five** buckets; the engine computed **nineteen**. A round through the right forearm
  and a round through the right hand play the identical `..._stand_hit_rarm`.
* It cannot express *where along* a limb, or from *which side* — the direction is discarded
  entirely; only `self.fact.location` is read (`aihandler.scr:1863`).
* It fires at most **once per 1.2 s per actor**, and only **55 %** of the time. Four of every five
  rounds in a burst produce **no visible reaction whatsoever** today.
* It never fires on the **killing blow** (`handlePain:1050` is inside the "survived" branch), and
  never for allied AI, and never on the eight excluded maps, and never when prone.
* `setmotionanim` replaces the **motion layer**; it cannot perturb one bone while the rest of the
  body keeps its authored pose.

### 5.3 THE RULE — how the procedural layer coexists

> **The procedural layer is an additive, per-channel, single-limb overlay. It rides on top of
> whatever the animation system is doing, always. It never suppresses, delays, replaces or
> conditions the authored pain animation, and the authored animation never gates it.**

Concretely, five clauses:

1. **Additive, never exclusive.** It fires on **every** qualifying flesh message, including the
   ~45 % that lose the `coop_aiHitReact` roll, the ones inside the 1.2 s throttle, the killing
   blow, allied-AI hits, prone actors, and the eight excluded maps. Those are precisely the cases
   where the actor visibly eats a bullet and does nothing today.
2. **Client-only, and it must stay client-only.** The authored layer is a **server** decision with
   AI-state consequences (`THINKSTATE_PAIN`). The procedural layer is a **render** effect with
   none. They cannot conflict because they do not share a mechanism. Any design that makes the
   procedural layer influence anim selection, think state, or the skeletor has crossed the line
   the ragdoll plan forbids.
3. **One limb, bounded.** Only the struck bone's chain gets a procedural offset, blended against
   `slot->animPose` (`renderergl1/tr_ragdoll.cpp` — stashed every frame, read by nothing today).
   Torso and pelvis stay at animation weight so the actor cannot slide, T-pose or lose his footing.
   Head hits should be the most conservative of all: a wrong head offset is the most visible
   artifact a player can be shown.
4. **Ceiling below the authored motion.** The offset must be visibly smaller than an authored
   flinch, so that when both play the flinch reads as the reaction and the overlay reads as
   detail. Starting proposal (**inferred**, to be swept live like `coop_ragdollCouple` was):
   peak deflection **8-15°** on a limb, **≤5°** on the neck/head, decaying to zero in **150-250 ms**
   — against the flinch's 0.15 s blend and multi-second anim.
5. **Never on the local player's own body, never on any player.** Filter `entnum < cgs.maxclients`.
   The standing rule from bug-785/792 (nothing is painted on or attached to a player) plus the
   first-person view make this non-negotiable.

**Rejected alternative — "only fire when no pain anim is playing".** It inverts the value: the
authored anim already covers the 55 % case *well*, and this would confine the procedural layer to
exactly the frames where the actor has the least going on, while requiring the client to know a
server-side decision it has no message for. It also produces a visible on/off flicker in a burst as
the 1.2 s throttle opens and closes.

### 5.4 A note on the counter

`behav_bump "hitreact"` (`aibehav.scr:128`) feeds the `^~^~^ AIBEHAV3 ... hitreact=N` line printed
every 30 s while `coop_aiBehav != 0` (`aibehav.scr:137-164`). That counter measures the **authored**
layer only. If a procedural layer ships, give it its **own** key (e.g. `proc`) in the same line
rather than folding it in — otherwise the one instrument that proves the authored flinches are
firing stops meaning anything.

---

## 6. Rate limiting

### 6.1 The real message rates, from the shipped TIKIs

| weapon | `firedelay` (dm/mp) | rounds/s | msgs per 50 ms server frame |
|---|---:|---:|---:|
| Thompson (`thompsonsmg.tik:57-58`) | 0.075 sp / 0.09 dm | 11.1-13.3 | 0.6-0.7 |
| MP40 (`mp40.tik:54`) | 0.08 | 12.5 | 0.6 |
| FG42 (`FG42.tik:80`) | 0.09 | 11.1 | 0.6 |
| BAR (`bar.tik:60`) | 0.115 | 8.7 | 0.4 |
| **Shotgun** (`shotgun.tik:49`, `bulletcount 20`) | per trigger pull | — | **up to 20 in ONE frame** |

So the automatic weapons are gentle — under one message per actor per server frame per shooter —
and the shotgun is the whole problem, plus 4-player convergent fire on a single target.

### 6.2 Policy

**Per-actor, per-limb, with accumulation. Three numbers:**

1. **Per-limb refractory: 120 ms.** A limb already deflecting takes further hits as an *addition to
   its existing offset*, capped, not as a fresh reaction. Rationale: 120 ms is just under the
   fastest sustained inter-round interval (75 ms Thompson SP) so a burst still reads as multiple
   distinct kicks on *different* limbs, while a shotgun's 20 pellets into one arm produce **one**
   compounded reaction rather than twenty restarts.
2. **Per-actor budget: 4 concurrent limbs, 6 reaction starts per 250 ms.** Beyond that, drop the
   message (do not queue) — dropping is invisible, queueing is a visible delayed twitch.
3. **Hard magnitude ceiling per limb**, applied to the *accumulated* offset, not the per-hit
   impulse. This is the exact lesson already paid for on the corpse path: `cg_ragdoll.c:1669-1681`
   clamps the **result** velocity, not the impulse, after "seven rifle hits walked a body 128 u
   from its own entity and tripped the leash".

**Precedent to mirror, not re-invent:** the server already enforces *one pain event per actor per
server frame* — `global/pain.scr:19-23`, `self.flags["coop_painFrame"] == level.time -> end`. That
guard exists because the same 20-pellet blast was double-threading the pain handler. The client
layer needs the same shape, one level finer (per limb rather than per actor), because the whole
point is that different limbs react independently.

### 6.3 A global ceiling is also required

`RAG_MAX_SIMS` is **16** (`cg_ragdoll.c:56`) and that is 16 *corpses*. A firefight can have 16+
**living** actors in view simultaneously, each potentially with an active limb offset — so the
living layer needs its own pool and its own per-frame work ceiling, sized independently. The corpse
path's own precedent for this is `RAG_TRACE_BUDGET 240` (`:64`) with a documented graceful
degradation ("past it, points glide this frame"). Adopt the same shape: a per-frame cap with a
defined, invisible degradation, never an unbounded loop.

---

## 7. Who sees it, and does divergence matter

**Confirmed** (§1.3): `MSG_SetBroadcastVisible(vTmpEnd, vBarrel)` accepts a client if the impact
**or** the muzzle is in its PVS and the areas connect (`sv_game.c:491-495`). So:

* Player B **does** see Player A's hits on an enemy, provided B can see the enemy or the shooter.
* A player **does** see their own hits at long range (this is the HZM widening of the vanilla
  `(pos, NULL)` call, noted inline at `weaputils.cpp:2620`).
* A player whose view is blocked from both the shooter and the impact sees nothing — correct, and
  identical to the existing blood behaviour.

**Will reactions be identical between coop players? No — and that is fine.** The layer is
client-side and unsynchronised: each client runs its own decay from its own `cg.time`, its own
frame rate, its own render-lag, and its own tuning cvars. Two players will see the same limb kick
in the same direction at the same instant, but not the same intermediate angles.

This is acceptable because:
* it is **cosmetic and non-authoritative** — the server's `trace.location`, damage, AI state and
  hit detection are untouched, which is the invariant the whole ragdoll plan was built to protect;
* the **decision inputs are identical** (position, direction, size, and — with the change —
  entity and limb), so the *choice of limb* and the *direction of the kick* are deterministic
  across clients even though the animation is not;
* the existing blood/impact FX are already unsynchronised in exactly this way
  (`CG_AddBulletImpacts`, `cg_view.c:3108`, with a randomised `coop_bloodSpurtUp` roll per client
  at `cg_parsemsg.cpp:1339-1349`) and nobody has ever noticed.

The one case that *would* matter is a divergence in **which limb** — two players seeing a hit on
different arms. The entity+location fields make that impossible by construction. Without them, it
is a live risk on any moving actor, because each client's render-lag differs.

---

## 8. Acceptance test, instrument, rollback

The user tests **one build per session**, so all three must exist before the build ships.

### 8.1 Instrument that needs no rebuild — available today

`coop_bloodDebug 1` (`autoexec.cfg:423`, seeded 0) already prints, per player flesh hit on a
**living** actor:

```
^~^~^ FLESHHIT dist=%.0f loc=%d pos=(%.0f %.0f %.0f)      weaputils.cpp:2616
```

**Run this before writing any code.** Shoot a stationary enemy in the left arm, the right leg and
the head; confirm `loc=` reads 8, 13, 0. Then repeat on a *running* enemy. This costs one console
command and proves — or disproves — the premise of the entire feature (that the engine's hit
location is accurate on living, animated actors) with zero build risk.

### 8.2 Numeric instrument for the new layer

Follow the shape that produced the corpse path's "60.5° live against 0.05° untouched" number
(`cg_ragdoll.c:1866-1886`, `swingBone`/`swingDir0`/`swingMax`): capture the struck bone's direction
at the moment of impact, track the peak angle between it and its current direction, and print one
greppable line per reaction:

```
^~^~^ HITREACT ent=%d loc=%d bone=%d peak=%.1fdeg rise=%dms decay=%dms match=%s
```

with `match=wire` (entity+location came off the wire) or `match=pos` (fallback). **The `peak` and
`match` fields are the whole acceptance criterion**, and the pair of them separates "the trigger is
wrong" from "the motion is wrong" — the exact confusion that cost rounds 1-8 of the corpse work.

Add a paired baseline count to the AIBEHAV3 line — `hitreact=` (authored) and a new `proc=`
(procedural) — so the ratio proves clause 1 of §5.3: `proc` must be **substantially larger** than
`hitreact`, because the procedural layer fires on messages the authored layer discards. If
`proc ≈ hitreact`, the layer has accidentally been gated on the pain path.

### 8.3 Live-observable acceptance test

1. `coop_bloodDebug 1`, `developer 1`.
2. Stand a **stationary** enemy (an MG42 gunner is ideal — he cannot move) and put one rifle round
   into his left forearm. **Expect:** `FLESHHIT loc=12`, one `HITREACT ... loc=12 bone=6 match=wire`
   with `peak` in the target band, and the arm visibly kicks while he keeps firing the MG.
3. Repeat on a **running** enemy at ~15 m crossing left-to-right. **Expect:** `loc=` matches the
   limb you aimed at, and `match=wire`. This is the case that fails today and the reason for the
   wire change.
4. Empty a shotgun into one enemy's torso at close range. **Expect:** one compounded reaction, not
   twenty; `proc` advances by ≤ 3; no slide, no T-pose, no loss of his firing animation.
5. Shoot an **allied** AI in the arm. **Expect:** a procedural reaction with **no** authored flinch
   (`friendlyFireCheck` suppresses pain) — this is the clearest single demonstration that the layer
   is additive rather than gated.
6. Shoot a **corpse** lying at a standing soldier's feet. **Expect:** the corpse reacts, the
   standing soldier does not. This is the overlapping-bbox case that only the entity number can
   resolve.
7. Load `e1l1` (a `coop_painHandlerExclusions` map, `variables.scr:114`) and repeat step 2.
   **Expect:** procedural reaction, zero `hitreact` counter movement.

### 8.4 Rollback — one command

Register the master gate the way `coop_ragdollImpact` was (`cg_ragdoll.c:343`,
`cgi.Cvar_Get("coop_ragdollImpact", "1", CVAR_TEMP)`), and give the living layer its own:

```
coop_hitReactProc 0
```

`CVAR_ARCHIVE` (not `CVAR_TEMP`) so a player's "off" survives a relaunch, defaulting **0** until the
look is signed off — the same call already reasoned through for `coop_ragdoll` at
`cg_ragdoll.c:318-320`. Zero must mean *the code path is not entered at all*, checked before any
queue write, so the rollback also removes the per-frame cost.

**⚠ Do not read this cvar from a script with `getcvar`** without pre-registering it in
`G_InitGame`: per the standing trap (bug-1669), a script `getcvar` on an unregistered name creates
it **empty** and permanently defeats the engine default. Registering it in the cgame as above and
seeding it in `coop_defaults.cfg` is the safe pattern (`coop_aiHitReact` follows it,
`coop_defaults.cfg:364`).

---

## 9. Defects and hazards found in passing

1. **`CG_RagdollImpulse` dereferences `cg.snap` with no NULL guard** —
   `cg_ragdoll.c:1460`, `for (e = 0; e < cg.snap->numEntities; e++)`. The only guard is
   `:1449` (`R_SetRagdollPose` / force / radius / `rag_impact`), none of which covers a NULL
   snapshot. `cg.snap` is set only in `CG_ProcessSnapshots` (`cg_snapshot.c:175`) during
   `CG_DrawActiveFrame`, whereas `CG_ParseCGMessage` runs from `CL_ParseServerMessage`. A CGM
   arriving in the same packet as the first snapshot, before any frame is drawn, is a null deref.
   Rare, but it is a crash, and the living path would add a second caller on the same page.
   **Recommend logging and guarding.**
2. **`CGM_DATATYPES_SIZE` is a lie.** `sv_game.c:136` defines it 8192 and `:186` bounds-checks
   `dtindex` against it, but the buffer is allocated `CGM_DATA_SIZE` = 4096 at `:148`. Not
   currently reachable — `cursize` advances by ≥1 per field while `dtindex` advances by exactly 1,
   so `cursize >= dtindex` always and the `:182` guard (4092) fires first — but the constant is
   dead and misleading, and anyone adding small fields to CGM messages will read `:186` and
   conclude there is twice the headroom there actually is. **Worth a one-line fix or a comment.**
3. **`SV_TraceDeep` returns the first sphere in table order, not the nearest** —
   `cm_trace_lbd.cpp:475-497`. Head/helmet/neck/torso systematically win against limbs where the
   spheres overlap. Long-standing vanilla behaviour that the pain scripts already depend on; noted
   so nobody "fixes" it and silently changes every pain animation in the game.
4. **`Actor::EventDamagePuff` is an unauthenticated `CGM_BULLET_8` source** — `actor.cpp:6026-6046`,
   with a script-supplied position and direction and `SetBroadcastVisible(pos, NULL)` (impact PVS
   only). Currently inert in this mod (`anim/killed.scr:45` is `if(0)`; `anim/dog_killed.scr:7`
   is gated to `level.gametype == 0`) but reachable from any map script. With an entnum field it
   should write `ENTITYNUM_NONE`; without one it is indistinguishable from a real hit.
5. **`bulletbits` asymmetry** — 2 bits at protocol ≥ 15, 1 below (`weaputils.cpp:2357/2360`), and
   `Actor::EventDamagePuff` carries its own copy of the same fix (`actor.cpp:6036`). Any new
   field added to `CGM_BULLET_8` must be written **after** `bulletlarge` in both, or the two send
   sites diverge in field order.
6. **`docs/generated/` is stale-checked, not stale-proof** — nothing in this report was taken from
   it; every fact is a fresh read of source. Noted only because the `_research/` file this
   supersedes-in-part (`ragdoll_r9_impact.md`) predates the `weaputils.cpp:2638` direction fix.

---

## 10. One-paragraph summary for the decision

A living soldier's hit already reaches every client that can see him or the shooter, over the same
`CGM_BULLET_8` the corpse ragdoll consumes, with a bone-accurate position (1/16 u) and — since the
2026-08-20 fix — a real inward normal (~6°). What it does **not** carry is the two things the
feature actually needs: **which soldier** and **which limb**. The engine computes the second one
authoritatively on every single flesh hit (`trace.location`, 19 codes, mapping 1:1 onto the
existing 15 sim bones) and then discards it at the wire. Recovering both costs **16 bits** on a
74-bit message and ships `game.dll` + `cgame.dll` together — no exe, no protocol constant, no
renderer. Attempting it without them means matching a 12-14 u stale position against a 15 u radius
and 18-24 u limb spacing, which will pick the wrong arm on any moving target on some fraction of
hits, differently on each client. Pay the 16 bits.
