# RAGDOLL R11 — THE TOPOLOGY CHANGE: FEET AS SIM POINTS 15 AND 16

**Lens:** add `Bip01 L Foot` / `Bip01 R Foot` as sim points 15/16, giving the shin a simulated
direction and the knee a real constraint. `RAG_PTS 15 -> 17`.

Written 2026-08-20 against `openmohaa-hzm/code/cgame/cg_ragdoll.c` **as it stands at 16:18:38
today** (2157 lines, 93 253 bytes — it grew by 15 lines mid-session with the arrival of
`coop_ragdollTruss`, so every line number below was re-read after that edit, not carried over).

Prior art: `ragdoll_joints_design.md` §1.3/§3.1, `ragdoll_r9_spec.md` §3.5, `ragdoll_r9_impact.md`,
`ragdoll_pile_findings.md`, `ragdoll_r8_spec.md` §3.4, `.wolf/buglog.json` bug-1962 … bug-1975.

Every claim inherited from the earlier adversarial vet was **re-measured with a parser written
from the engine's own struct definitions**, not trusted. All three survive. Two of them are
stronger than the vet stated; the third is exactly right.

---

## 0. VERDICT ON THE THREE INHERITED CLAIMS

| # | Claim | Verdict | What I actually measured |
|---|---|---|---|
| 1 | `Bip01 L/R Foot` exist across the humanoid roster (vet said "39/39 models, 2/2 each") | **CONFIRMED — and understated** | **1385 / 1385** ragdoll-eligible human TIKs, and **76 / 76** SKDs carrying a full 15-bone sim skeleton, resolve both feet. Zero misses. Also 4/4 on `Bip01 L/R Toe0`. |
| 2 | The calf bone's origin **is** the knee (IK-chain evidence: IKSHOULDER at the hip, IKELBOW at the thigh length, IKWRIST at the ankle) | **CONFIRMED — verbatim, and the model self-labels it** | The leg chain is literally typed `IKSHOULDER → IKELBOW → IKWRIST` in the SKD bone records, and the rig carries a helper bone **named `helper Lknee`** parented to `Bip01 L Thigh` at *exactly the Calf's own offset* (46.35 cm). The animator placed a bone called "knee" on top of the Calf origin. |
| 3 | Roughly a third of the corpse mesh (calf + foot + toe + ankle helpers) rides rigidly on the knee | **CONFIRMED — 29.4 % to 41.5 %, mean 35.0 %** by vertex weight across 10 SKDs spanning US / German / British / Italian / officer / winter / Afrika / airborne / mod-imported | Of which **19.0–30.1 % (mean 24.4 %) is strictly below the knee** and has no simulated direction whatsoever. |

---

## 1. METHOD — why I did not use the existing tool

`docs/tools/ragdoll_channel_census.py` strides bone records with a fixed `o += 84`. That is wrong,
and the engine says so:

```c
boneBuffer = (boneFileData_t *)((byte *)boneBuffer + boneBuffer->ofsEnd);
```
— `openmohaa-hzm/code/qcommon/tiki_main.cpp:277`

`boneFileData_t` (`openmohaa-hzm/code/skeletor/skeletor_model_file_format.h:50-58`) is an **84-byte
header followed by variable-length payload**: per-type base data, then inline channel-name and
bone-name strings. `CreateRotationBoneFileData` sets `ofsBaseData = sizeof(boneFileData_t)` (=84),
then `ofsChannelNames = ofsBaseData + 24`, then `ofsEnd = ofsChannelNames + strlen(rotName) + 1`
(`skeletor/skeletor_model_files.cpp:40-56`). Measured live: `ofsEnd` runs **116 to 156** across one
soldier's 42 bones. A fixed 84 desynchronises at bone 0 and reads garbage from there on.

I wrote `scratchpad/skd_probe.py` from the source structs:

| what | source |
|---|---|
| `skelHeader_t` (`numBones`@76, `ofsBones`@80, `scale`@148 for v6) | `tiki/tiki_shared.h:214-230` |
| `boneFileData_t` + `ofsEnd` stride | `skeletor/skeletor_model_file_format.h:50-58`, `qcommon/tiki_main.cpp:277` |
| per-bone-type base data offsets | `tiki/tiki_skel.cpp:86-138` (`LoadBoneFromBuffer2`) |
| `skelSurface_t` (100 B) | `tiki/tiki_shared.h:239-250` |
| vertex layout: header, **then morphs, then weights** | `tiki/tiki_shared.h:356-361`; order proven by `renderergl1/tr_model.cpp:1268-1270` |
| `skelWeight_t.boneIndex` indexes the SKD's own `pBones[]` | `renderergl1/tr_model.cpp:1284-1287` |

**Parser validated against the shipped runtime**: `models/human/german_wehrmact_soldier.tik`
computes a union of **72 channels** — exactly the `channels=72` printed by the live
`settle-armed` line and recorded in the file header as "the static census". Independent agreement
on a number produced by a completely different code path.

---

## 2. CLAIM 1 — THE FEET EXIST. THE STRONGEST FORM OF THE TEST.

Scope: every `.skd` in the mounted `main` + `mainta` + `maintt` pk3 set plus the loose mod tree —
**1575 SKD files**, of which 235 carry `Bip01 Pelvis`.

**Per-SKD.** 76 SKDs carry all 15 current sim bones. Of those:

```
with BOTH Bip01 L Foot and Bip01 R Foot : 76 / 76
with BOTH Bip01 L Toe0 and Bip01 R Toe0 : 76 / 76
Bip01 Footsteps                          : 75 / 76
```

The 76 span every category asked for and several more — AA `usarmy` / `airborne` /
`allied_ranger_soldier` / `heerprivate` / `wehrmacht_nohead` / `waffen_ss_shutze` / `ssnco` /
`german_officer` / `gestapo` / `kreigsmarine` / `panzergrenadier` + the four panzer-crew rigs /
`daksoldier` (Afrika) / `wintersoldier1` + `wintersoldier2` / `scientist` / `german_worker` /
`kradshutzen` / `resistance` / `manon` / `allied_pilot` / `brit_tank_corp`; SH+BT `sc_al_us_inf`,
`sc_al_brit_inf`, `sc_al_us_pilot`, `sc_ax_ital_inf`, `sc_ax_ital_para`, `it_ax_ital_vol`, plus
the `sc_*` gear skeletons; mod-imported `6abs/battledress`, `6abs/brit_para`, `britpack/*`.
**Also `models/animal/dog/german_shepherd.skd`** — the dog carries all 15 *and* both feet, so
`hund` corpses arm today and will keep arming.

**Per-TIK (the unit that actually matters).** `cgi.Tag_NumForName` → `TIKI_Tag_NameToNum`
(`client/cl_cgame.cpp:809`) → `dtiki_s::GetBoneNumFromName` (`skeletor/skeletor.cpp:1258-1269`),
which returns the **local channel index in `tiki->m_boneList`** — the per-TIK union over all its
`skelmodel` lines. Across 1638 human TIKs:

```
ragdoll-eligible (resolve all 15 current sim bones) : 1385
  ... of those, missing Bip01 L or R Foot           :    0
  ... of those, missing Bip01 L or R Toe0           :    0
not eligible today (already refused at :599-604)    :  253
```

**The coverage-shrink test — the only way this change could cost arms.** Across the entire data
set, **152** (SKD, side) pairs carry a `Calf`. In **0** of them is the matching `Foot` absent.
`Foot ⊇ Calf` with no exception, so `RagCapture`'s bail-clean at `:599-604` cannot fire on a
corpse that arms today.

**Channel-index headroom.** `RAG_MAX_CH` is 128 and `RagCapture` refuses any sim bone whose
channel index is `>= s->count` (`:600`). Worst case across the 1385 eligible TIKs:

```
max union channel count : 87   (models/human/1st-ranger_sergeant.tik)
max Foot channel index  : 72
TIKs exceeding 128      :  0
```

41 channels of headroom in the worst case. **No `RAG_MAX_CH` change needed.**

**Third-party corroboration inside the engine.** `qcommon/cm_trace_lbd.cpp:31-51` — the 19-entry
locational-damage hitloc table — ends with `"Bip01 R Foot"`, `"Bip01 L Foot"`, and
`fLocRadius[]:52-54` gives each a **6.0** hit sphere. The engine already assumes every human model
resolves those two names.

---

## 3. CLAIM 2 — THE CALF ORIGIN IS THE KNEE

Full leg chain, `models/human/allied_army_soldier/usarmy.skd`, verbatim from my parser
(offsets in model cm; the world column is × the tik's `scale 0.52`, whose own comment reads
*"world is in 16 units per foot and model is in cm's"*):

| # | bone | parent | **bone type** | offset (cm) | \|off\| cm | **world u** |
|---|---|---|---|---|---|---|
| 26 | `Bip01 L Thigh` | `Bip01 Pelvis` | **IKSHOULDER** | (0, 0, 9.18) | 9.18 | 4.8 |
| 27 | `Bip01 L Calf` | `Bip01 L Thigh` | **IKELBOW** | (46.35, 0, 0) | 46.35 | **24.1** |
| 28 | `Bip01 L Foot` | `Bip01 L Calf` | **IKWRIST** | (46.04, 0, 0) | 46.04 | **23.9** |
| 29 | `Bip01 L Toe0` | `Bip01 L Foot` | ROTATION | (10.98, 12.84, −0.17) | 16.90 | 8.8 |
| 30 | `helper Lankle` | `Bip01 L Foot` | HOSEROT | (−0.77, 0.01, 0) | 0.77 | 0.4 |
| 31 | `helper Lknee` | `Bip01 L Thigh` | AVROT | (46.35, 0, 0) | 46.35 | **24.1** |

Three independent proofs, all in one table:

1. **The IK typing.** 3ds Max Biped names a leg IK chain with the arm's type names. The
   `SKELBONE_IKSHOULDER → SKELBONE_IKELBOW → SKELBONE_IKWRIST` triple
   (`skeletor_model_file_format.h:32-34`) sits on Thigh → Calf → Foot. The "elbow" of the leg is
   the knee, and it is the **Calf** bone. `tiki/tiki_skel.cpp:103-113` reads `boneData->length`
   for IKELBOW/IKWRIST as `|baseData[0..2]|` — the IK segment length — and it comes out at 46.35
   for the Calf and 46.04 for the Foot, i.e. **the thigh length and the shin length**.
2. **The model's own label.** `helper Lknee` is parented to `Bip01 L Thigh` at offset 46.35 —
   bit-identical to `Bip01 L Calf`'s offset. The rig author put a bone *named knee* at exactly the
   Calf's origin. Symmetrically, `helper Lankle` hangs off `Bip01 L Foot` at 0.77 cm — an ankle
   helper co-located with the Foot origin, so **Foot origin = ankle**.
3. **The arithmetic closes on the live data.** Pelvis→Head along the spine sums to 60.46 cm =
   31.4 u; Pelvis→Knee is 47.25 cm = 24.6 u. Head-to-knee = **56.0 u**, against the r8 spec's
   independently *measured* "~57.5 u full cloud extension". Within 3 %. The geometry is right.

**The skeleton is one rig.** Across 16 sampled models the leg is identical to the centimetre —
thigh 24.1 u, shin 23.9 u, foot 8.7 u world — with the single exception of `manon.skd` (the female
model: 22.8 / 23.9 / 8.1). There is no per-model tuning to do.

### What this means numerically

* The unsimulated shin is **23.9 world units**, nearly **twice the forearm** (25.97 cm = 13.5 u)
  and essentially **equal to the thigh** (24.1 u). It is the longest unsimulated segment on the
  body by a wide margin, and the second-longest segment of any kind.
* `pt[12]` **is** the knee, so `|pt[0] − pt[12]|` — `s_ragBraces` rows 11-12, `{0,12}` / `{0,14}` —
  is `|pelvis→hip| = 4.8` and `|hip→knee| = 24.1` hinged at the hip. Its full range is 19.3 … 28.9 u.
  **It is a hip-angle measure and has never constrained a knee.** The vet's finding: confirmed.
* A real knee measure is `|pt[11] − pt[15]|` = thigh 24.1 + shin 23.9 hinged at the knee, range
  **0.2 … 48.0 u** — a 240× wider dynamic range. That is the difference between a constraint and a
  decoration.

---

## 4. CLAIM 3 — HOW MUCH MESH RIDES ON THE KNEE

Vertex-weight census. Every vertex's weights sum to 1, so `Σweight = numVerts` and the columns are
true mesh fractions. `boneIndex` → `pBones[]` per `renderergl1/tr_model.cpp:1284-1287`.

| model | verts | below-knee | calf | **BELOW+CALF** | thigh |
|---|---:|---:|---:|---:|---:|
| `usarmy` (US Army) | 1107 | 25.1 % | 9.5 % | **34.6 %** | 11.0 % |
| `heerprivate` (Wehrmacht) | 950 | 27.6 % | 10.9 % | **38.5 %** | 15.9 % |
| `sc_al_us_inf` (BT US) | 1349 | 19.7 % | 13.4 % | **33.1 %** | 14.8 % |
| `sc_al_brit_inf` (BT British) | 1349 | 22.7 % | 11.1 % | **33.8 %** | 12.3 % |
| `sc_ax_ital_inf` (Italian) | 1201 | 20.7 % | 16.7 % | **37.3 %** | 15.0 % |
| `german_officer` | 1012 | 27.4 % | 7.3 % | **34.7 %** | 21.5 % |
| `wintersoldier2` (winter) | 1356 | 19.0 % | 10.5 % | **29.4 %** | 11.9 % |
| `daksoldier` (Afrika) | 1029 | 30.1 % | 7.1 % | **37.2 %** | 16.7 % |
| `airborne` | 1222 | 25.4 % | 4.6 % | **30.0 %** | 16.5 % |
| `battledress` (mod import) | 1189 | 25.9 % | 15.6 % | **41.5 %** | 13.1 % |
| | | **19.0–30.1** | **4.6–16.7** | **29.4–41.5** | |

*below-knee* = `Bip01 L/R Foot` + `helper L/Rankle` + `Bip01 L/R Toe0`; *calf* = `Bip01 L/R Calf` +
`helper L/Rknee`.

**"Roughly a third" is exactly right: mean 35.0 %.** All of it anchors to sim point 12 or 14 today
and therefore rides one rigid transform.

Split finer, because it decides where to stop:

| region | mean weight | after this change |
|---|---:|---|
| `Bip01 L/R Foot` + ankle helpers | 16.2 % | position **and** orientation now follow a simulated ankle |
| `Bip01 L/R Toe0` | 6.0 % | position follows the ankle; orientation still inherits |
| `Bip01 L/R Calf` + knee helpers | 10.7 % | **now driven by the shin** instead of the thigh — the actual fix |
| `Bip01 Footsteps` | **0.0 %** on all ten | nothing is skinned to it; its anchor can move freely |

**This is the argument for stopping at the ankle.** Adding `Toe0` as points 17/18 would correct
the orientation of a further ~6 % of the mesh, at the price of two more collision points at the
very lowest, most-likely-to-be-buried place on the body. Not worth it. **Feet only.**

### Why the below-knee mesh is currently frozen — the exact mechanism

`s_ragDriveChild[12] = -1` and `[14] = -1` (`cg_ragdoll.c:113,115`), so in `RagPush` the calf takes
the leaf branch:

```c
int dch = rag_drive->integer ? s_ragDriveChild[i] : -1;     // :1286
...
VectorSubtract(s->pt[i], s->pt[p], dNow);   // leaf: the INCOMING segment  :1291
ref = s->restDir[i];
```

`pt[11] → pt[12]` is the **thigh**. So the calf bone renders with the thigh's swing; the Foot, Toe0
and ankle helpers anchor to `pt[12]` (`s_ragAnchorTable`, `:269-272`) and are placed by
`pt[12] + rotNow[12]·relPos[ch]` (`:1310-1313`) with `rotNow[12] = rot0[12]·S_thigh`. Position and
orientation both. **The whole lower leg is welded to the thigh, and it is 35 % of the corpse.**

The shipped code already anticipates the fix, at `cg_ragdoll.c:113`:

```c
    -1, // 12 L Calf     - leaf TODAY; becomes L Foot in round 9 (the unsimulated knee)
```

### Free consequence: the shin becomes hittable for the first time

`CG_RagdollImpulse`'s bullet path walks the **parent links** (`:1408-1430`) and calls with
`radius = 15.0f + 1.5f * iLarge` (`cg_parsemsg.cpp:1808,1820,2232,2244`), i.e. **15–18 u**.

Today the lowest leg segment is `pt[11] → pt[12]` (hip→knee). For a shot through the shin the
closest point on that segment clamps to `t = 1` (the knee), so:

| shot lands | `bestD` today | today's result |
|---|---:|---|
| mid-shin (11.9 u past the knee) | 11.9 u | registers at `k2 = 1 − 11.9/15 = 0.20`, **and `bestT = 1` puts 100 % of that 20 % on the knee** |
| lower shin (≥ 15 u past the knee) | ≥ 15 u | `bestD >= radius` → **`continue`. The round misses the corpse entirely.** |
| the foot | ≥ 24 u | **misses entirely** |

So **the lower ~9 u of each shin and the whole foot are currently un-shootable**, and a mid-shin
hit kicks the knee instead of the shin. After the change the segment `pt[12] → pt[15]` exists: a
mid-shin hit scores `bestD ≈ 0`, `k2 ≈ 1.0`, and the force splits 50/50 between knee and ankle —
which is precisely the rotation-about-a-joint that the bone-segment targeting fix was written to
produce for arms. **This is the cheapest acceptance test in the build: shoot a corpse in the
shin.**

---

## 5. THE COMPLETE SITE LIST — CHECKLIST

`RAG_PTS` is referenced **51 times** in the current file. Every `for` loop and every
`ragSim_t` member auto-scales. **Three `static const` tables do not, and C silently zero-fills the
missing initialisers.** That is the entire risk surface of this change.

### 5.1 The three silent-corruption traps — do these first

- [ ] **`s_ragPtRadius[RAG_PTS]` — `:248-254`.** 15 initialisers. Missing entries become `0.0f`.
      Consumed in three places: the capture pre-lift box (`:633-634`), the clearance clamp
      (`:719,721,724,726,727`), and thence `s->ptRadius[i]` used by `RagCollideWorld` (`:1120-1121`)
      and `RagCollideMovers` (`:1182-1183`). A 0-size box is **a point trace** in the collision
      model — the exact mechanism the E7 comment at `:627-631` documents as bug-1962's pin.
      *(The runtime `ptRadius` would be rescued by the `clear < 1.0f → 1.0f` floor at `:729-731`,
      but the pre-lift, which reads the static table directly, would not.)*
- [ ] **`s_ragDriveChild[RAG_PTS]` — `:100-116`.** 15 entries. Missing entries become **`0`**, and
      `0 >= 0` passes the `dch >= 0` test at `:1286`. Each foot would be "driven" by
      `pt[0] − pt[15]`, the **ankle→pelvis** direction. Silent, catastrophic, and invisible to the
      freeze drill.
- [ ] **`s_ragBraceMinFactor[RAG_BRACES]` — `:145-153`.** If `RAG_BRACES` grows and only
      `s_ragBraces` gains rows, the new entries become `0.0f`, which `:707` and `:1004` both read as
      **"structural equality brace"** — welding the ankle to the hip at capture distance and
      freezing the knee solid. It would look exactly like "the knee still doesn't bend".

**Add a compile-time guard.** Valid C89, fails the build rather than the playtest:

```c
/* A missing initialiser in any of these is silent: C zero-fills, and a 0 radius becomes a POINT
   trace, a 0 drive-child becomes "drive toward the pelvis", a 0 min-factor becomes an EQUALITY
   weld. Break the build instead. */
typedef char rag_tbl_bones_check [(sizeof(s_ragBones)         / sizeof(s_ragBones[0])         == RAG_PTS)    ? 1 : -1];
typedef char rag_tbl_drive_check [(sizeof(s_ragDriveChild)    / sizeof(s_ragDriveChild[0])    == RAG_PTS)    ? 1 : -1];
typedef char rag_tbl_radius_check[(sizeof(s_ragPtRadius)      / sizeof(s_ragPtRadius[0])      == RAG_PTS)    ? 1 : -1];
typedef char rag_tbl_brace_check [(sizeof(s_ragBraceMinFactor)/ sizeof(s_ragBraceMinFactor[0])== RAG_BRACES) ? 1 : -1];
```

`s_ragBones[RAG_PTS]` (`:73-92`) is the fourth, but it fails **loudly**: a `NULL` name reaches
`cgi.Tag_NumForName` and nothing ever arms. Guard it anyway.

### 5.2 Tables that must gain rows

- [ ] `#define RAG_PTS 15` → **17** (`:57`)
- [ ] `s_ragBones` (`:76-92`) — append two rows **at the end**, indices 15/16. See §6.1.
- [ ] `s_ragDriveChild` (`:100-116`) — index 12 `-1 → 15`, index 14 `-1 → 16`, append `-1, -1`.
- [ ] `s_ragPtRadius` (`:248-254`) — append two entries. See §6.3.
- [ ] `#define RAG_BRACES 16` → **18** (`:122`); `s_ragBraces` (`:123-140`) append `{11,15}`,
      `{13,16}`; `s_ragBraceMinFactor` (`:145-153`) append `0.75f, 0.75f`. See §6.2.
- [ ] `s_ragAnchorTable` (`:269-272`) — `"Bip01 L Foot"` 12→**15**, `"Bip01 L Toe"` 12→**15**,
      `"Bip01 R Foot"` 14→**16**, `"Bip01 R Toe"` 14→**16**.

### 5.3 Constants that must move because a counted budget changed

- [ ] `RAG_MOVER_PER_BODY 60` → **68** (`:63`). See §7.4 — this one is a **silent order-dependent
      defect** if missed, and the points it silently drops are the feet.
- [ ] `RAG_TRACE_BUDGET 240` → **272** (`:62`), to preserve the "4 bodies × 4 movers × every point"
      invariant that 240/60 encoded.
- [ ] `if (nTorso > 0 || s->buried >= 4)` → **`>= 5`** (`:658`). See §7.1 — coverage risk, and
      coverage is bug-1969's ground.

### 5.4 Sites that auto-scale but whose **meaning** changes — no edit, but they must be understood

| site | line | what changes |
|---|---|---|
| capture pre-lift | `:618-642` | two more points probed; `preLifted` (a `byte`) now tops out at 17 |
| buried census | `:648-664` | two more points counted → §5.3 threshold |
| bind/degenerate check | `:669-678` | unchanged: `pt[4]` vs `pt[0]` |
| restLen / restDir / rot0 | `:681-702` | two more, including the two new 23.9 u links |
| brace capture | `:703-710` | two more `braceLen` entries |
| clearance clamp | `:716-733` | two more radii clamped to authored floor clearance |
| capture AABB `capSpan` | `:746-752` | **grows ~+42 %** — §8 |
| `driveDir0` capture | `:755-768` | now captures the two shin directions (the whole point) |
| channel anchoring | `:772-824` | Foot/Toe re-target; `helper L/Rankle` improves via *nearest* |
| `RagShapeMatch` | `:924` | feet are now pose-attracted — required |
| `RagStep` integrate | `:955-973` | 17 points |
| `RagStep` parent links | `:975-987` | 16 links; parent-before-child order preserved by appending |
| `RagStep` braces | `:988-1010` | 18 braces, all scaled by `rag_truss` |
| limp tick | `:1012-1019` | 17 windows |
| `RagMoverHash` bounds | `:1082-1084` | query box grows — §7.5 |
| `RagCollideWorld` | `:1104-1146` | 17 sweeps/substep; `s_ragWorldTraces` is budget-exempt |
| `RagCollideMovers` | `:1148-1197` | §5.3 / §7.4 |
| `RagSane` span/leash | `:1199-1238` | span baseline grows; the pelvis leash reads `pt[0]` only — unaffected |
| `RagPush` stack arrays | `:1243-1244` | `rotNow`+`conj` 1080 B → 1224 B |
| `RagDrawSkeleton` | `:1358` | **17 dots — this is the live verification for the anchor re-target** |
| impulse: bullet segments | `:1408-1430` | 16 segments; the shin becomes hittable — §4 |
| impulse: explosion | `:1467-1519` | 17 points; `((j*37) % 17)` at `:1494` now yields a full permutation of 0…16 for j = 0…16, which is *better* spread than today's 15-of-17 — leave it, but add a comment, because "17" now coincidentally equals `RAG_PTS` and a future reader will assume that was intentional |
| frame/substep snapshots | `:1559,1615` | auto |
| stretch instrument | `:1667-1678` | 16 links, incl. the two longest — §8 |
| contact peak `ctcMax` | `:1681-1689` | two more contactable points → the `nContact >= 3` rot-lock latch (`:890`) fires **earlier and on more bodies** — §7.6 |
| sleep speed | `:1712-1716` | `/ RAG_PTS` = /17 — §8 |
| drift instrument | `:1747-1754` | `/(RAG_PTS − 1)` = /16 — §8 |
| pending → goal copy | `:1965-1967` | feet get goals — required |
| free-branch seed | `:2040-2045` | 17 seeded points (mode 3 only) |

### 5.5 Comments that will lie if not updated

`:20` "sims 15 mass points" · `:72` "the 15 sim bones" · `:113`/`:115` the two "leaf TODAY" notes ·
`:216` "over the 14 parent links" · `:1119` "hard-bounded at 15 x 4 x pool" · `:1357` "draw the 15
sim points" · the `RagShapeMatch` header's "all 14 non-pelvis points".

### 5.6 Nothing outside `cg_ragdoll.c` changes

- **No new cgame import.** Every API is already in the struct: `Tag_NumForName`
  (`cg_public.h:406`), `Tag_NameForNum` (`:407`), `ForceUpdatePose` (`:408`), `TIKI_Orientation`
  (`:409`), `CM_PointContents` (`:173`), `CM_BoxTrace` (`:177`), `CM_TransformedBoxTrace` (`:187`),
  `CM_InlineModel` (`:171`), `R_SetRagdollPose` (`:453`), `R_ClearRagdoll` (`:454`).
- **No renderer change.** `renderergl1/tr_ragdoll.cpp` ≡ `renderergl2/tr_ragdoll.cpp`. The bridge
  is per-**channel** (`RAGDOLL_MAX_CHANNELS 128`, `tr_ragdoll.cpp:20`), not per-sim-point; the
  channel count is unchanged.
- **`cgame.dll` alone.** No `game.dll`, no `openmohaa.exe`, no protocol constant.

### 5.7 Memory

Twelve `[RAG_PTS]` members in `ragSim_t` (`:176-203`) at **112 B/point**
(`simChan` 4 + five `vec3_t` 60 + `restLen`/`ptRadius` 8 + `rot0` 36 + `driveOk`/`contact` 2 +
`limpMs` 2), so **+224 B**, plus `braceLen` **+8 B** = **+232 B/slot**, ×8 slots = **+1.9 KB** on a
~77 KB pool. `RagPush`'s stack grows 144 B. Nothing.

---

## 6. THE NEW TABLE VALUES

### 6.1 `s_ragBones` — append, never renumber

```c
static const struct {
    const char *name;
    int         parent;
} s_ragBones[RAG_PTS] = {
    /* ... 0..14 EXACTLY AS TODAY, not one index moved ... */
    {"Bip01 L Foot",    12}, // 15  NEW - the ANKLE. Bip01 L Calf's origin is the KNEE (the leg IK
    {"Bip01 R Foot",    14}, // 16  chain is IKSHOULDER hip -> IKELBOW knee -> IKWRIST ankle, and
                             //     the rig carries a bone literally named "helper Lknee" at the
                             //     Calf's own offset), so this is the first point that gives the
                             //     23.9u shin a direction of its own.
};
```

**Append-don't-renumber is load-bearing, not stylistic.** Every hard-coded index in the file keeps
its meaning only because 15/16 are new: the torso test `i <= 4` (`:656`), the bind check `pt[4]` vs
`pt[0]` (`:671`), the hip line `pt[13] − pt[11]` (`:743`, `:846` in `RagRawFit`), the spine line
`pt[1] − pt[0]` (`:845`), the pelvis anchor `pt[0]`/`goal[0]` (`:927,929,1750,1754`), the leash
`pt[0]` (`:1231`), every `s_ragAnchorTable` sim value, every `s_ragBraces` row. Ordering also
matters for the solver: `RagStep`'s parent-link pass (`:975-987`) is a root→leaf Gauss-Seidel sweep
in index order, and appending children of 12/14 at 15/16 keeps every parent before its child.

### 6.2 `s_ragBraces` / `s_ragBraceMinFactor` — grow to 18, touch nothing existing

```c
#define RAG_BRACES 18
    /* ... rows 0..15 UNCHANGED ... */
    {11, 15}, // 16 L hip - L ankle  (the FIRST real knee fold limit: |pt0-pt12| rows 11-12
    {13, 16}, // 17 R hip - R ankle   measure the HIP angle, range 19.3..28.9u, and never
              //                      constrained a knee. This one ranges 0.2..48.0u.
static const float s_ragBraceMinFactor[RAG_BRACES] = {
    0,0,0,0,0,0,  0.80f,  0.70f,0.70f,  0.75f,0.75f,  0.75f,0.75f,  0.75f,  0.60f,0.60f,
    0.75f, 0.75f,                       // knees: the exact analogue of the elbows {5,7}/{8,10}
};
```

**Why 0.75, derived not copied.** The knee is the anatomical twin of the elbow — a hinge between
two near-equal segments — and `{5,7}`/`{8,10}` already run 0.75. Working the law of cosines at a
near-straight capture:

| joint | segments (u) | straight `d` | `×0.75` | interior angle admitted | flexion allowed |
|---|---|---:|---:|---:|---:|
| elbow `{5,7}` | 13.3 + 13.5 | 26.8 | 20.1 | 97.2° | **82.8°** |
| knee `{11,15}` | 24.1 + 23.9 | 48.0 | 35.5 | 95.4° | **84.6°** |

Within 2° of each other — the same joint stop, derived independently. State plainly what it is:
**0.75 is a pile-prevention limit, not an anatomical one.** A real knee flexes ~140–150°, which
would need a factor of ~0.35. The r12 angular limits replace this with a genuine `[+2°, +150°]`
hinge (`ragdoll_joints_design.md` J18/J19). Note also the fold braces measure against the *capture*
distance, so a corpse that dies kneeling gets a correspondingly loose knee — same semantics every
other fold brace already has.

**Why grow rather than retarget rows 11-12.** The vet's proposal was to move `{0,12}`/`{0,14}` to
`{11,15}`/`{13,16}`. Its diagnosis is right (§3: they are hip measures, and rows 14-15 `{2,12}`/
`{2,14}` at 0.60 are the strong hip limits that make them near-redundant), but the retarget is the
wrong shape for *this* build:

1. **Keeping them is free, because they cannot fight the knee.** `|pt[0] − pt[12]|` is invariant
   under knee flexion — bending the knee moves `pt[15]`, not `pt[12]`. The two constraints are
   geometrically orthogonal. There is no limit cycle to buy.
2. **This build must not remove a truss member.** Its acceptance test is "does the shin bend and
   does coverage hold". Deleting a brace in the same build re-runs the r10 §3.5 mistake that F6/F4
   were deferred to avoid.
3. `coop_ragdollTruss` (new today, `:298,320-326`) already makes the whole truss A/B-able live, so
   the retarget is a one-line follow-up experiment, not a thing to bundle.

**Atomicity handover (r9 §3.5 rule).** The fold-limit set is now **rows 6–17**, not 6–15. When the
angular limits land they must delete rows 6–**17** together with the whole `s_ragBraceMinFactor`
table. Deleting 6–15 and orphaning 16–17 would leave two unlabelled equality-adjacent braces
behind.

**Interaction to expect:** `coop_ragdollTruss 0` does `break` out of the brace loop entirely
(`:992-995`), so the new knee limits go with it. After this build, truss-off means a leg with a
*simulated* shin and *no* knee limit — a more informative experiment than today (where the knee
does not exist at all), and a more mangled-looking one. That is the correct reading, not a bug.

### 6.3 `s_ragPtRadius` — 3.0 f, from the file's own rule

```c
static const float s_ragPtRadius[RAG_PTS] = {
    7.0f, 7.0f, 7.5f, 4.0f, 5.0f,   // pelvis, spine1, spine2, neck, head
    4.0f, 3.0f, 2.5f,               // L upperarm, forearm, hand
    4.0f, 3.0f, 2.5f,               // R arm
    5.0f, 4.0f,                     // L thigh, calf
    5.0f, 4.0f,                     // R thigh, calf
    3.0f, 3.0f,                     // L/R FOOT (= the ankle joint)
};
```

The file's stated rule is "Torso/head hold higher, extremities lower = natural drape" (`:245-247`),
and the arm already spells the gradient out: upperarm 4.0 → forearm 3.0 → hand 2.5. The leg is
thigh 5.0 → calf 4.0 → **foot 3.0**. Three further checks all agree:

* The ankle sits ~**5.7 u above the sole** (the `Toe0` offset's down-bone component, 10.98 cm ×
  0.52, with the foot's local +X continuing the shin). 3.0 keeps the box comfortably *inside* that
  height, so the R4 clearance clamp (`:716-733`) has room to do its job instead of the point
  starting already inflated — which is the bug-1970 hover mechanism.
* The pre-lift sweeps a ±r box down from `pt + 40 z` (`:625,633-634`). The feet are the points most
  likely to need that lift, and a smaller box is less likely to `startsolid` in tight geometry.
* The engine's own LBD hit sphere for a foot is 6.0 (`cm_trace_lbd.cpp:52-54`) — but every
  `s_ragPtRadius` entry runs 0.4–0.9× its LBD counterpart (hand 2.5 vs 6.0, calf 4.0 vs 7.5). 3.0
  is 0.50×, right inside the band.

Independent agreement with `ragdoll_joints_design.md` §3.1, which also lands on 3.0.

*If boots visibly sink after landing*, 4.0 is the one-token tune. *If `prelift=` shows feet not
being lifted and `buried=` rises*, 2.5 is the other direction.

### 6.4 One new cvar — and only one

```c
rag_buried = cgi.Cvar_Get("coop_ragdollBuriedMax", "5", CVAR_TEMP);  // was hard 4 at :658
```

This is the single highest-risk regression of the change (§7.1) and it is the one thing that
*cannot* be diagnosed from the log alone without a live A/B. Two lines, and it puts coverage —
bug-1969's ground — behind a console key instead of a rebuild.

**No `coop_ragdollFeet` toggle.** `RAG_PTS` is a compile-time array bound in twelve struct members
and five stack arrays; making it runtime means rewriting ~20 loop bounds, which is exactly the
class of edit that produced bug-1962 and bug-1967. See §10 for the rollback that does exist.

---

## 7. NEW FAILURE MODES

### 7.1 HIGH — the `buried >= 4` refusal becomes reachable, and the two new points are *biased* toward burial

`:648-664` refuses to arm if the torso is buried **or** if four points anywhere are still in solid
after the pre-lift. The torso half is untouched (feet are indices 15/16, and `i <= 4` still means
pelvis…head — the append-don't-renumber payoff). The **total** half is not.

The feet are the lowest points on a landed corpse, so the two added points are not a random sample:
they are the two most likely to be buried. A body that today buries two calves and a hand (3 →
arms) will tomorrow bury two calves, two feet and a hand (5 → **refuses**). The failure is silent
except for the existing `capture BURIED` print at `:659-662`, and it hands back coverage — the
exact axis bug-1969 moved from 22 % to 98 %.

**Fix:** threshold 4 → **5**. 4/15 = 26.7 %; 5/17 = 29.4 % is the nearest integer preserving the
proportion, and given the burial bias that is if anything conservative. Behind
`coop_ragdollBuriedMax` (§6.4) so it is one console line either way.

**Watch:** `buried=` and `prelift=` on the `settle-armed` line, and the arm-rate itself (Gate 1).

### 7.2 MEDIUM — a foot the pre-lift cannot free is cosmetic on settle, a pin on free

If the pre-lift `startsolid`s (its box at `pt + 40 z` is in solid — plausible for an ankle in a
crawlspace or under a stair), the point stays buried; the clearance probe at `:722` then also
`startsolid`s, so `clear` keeps its `s_ragPtRadius[i]` initialiser and the point is `startsolid` on
every sweep for the rest of its life.

**On the settle branch this is benign**: R1 releases such a point (`:1135-1138`: `contact = 0`,
`ptPrev = pt`), so the shape-match creeps it out along the pull rather than anchoring the leg
inside the wall. The visible artefact is a boot through the floor for a few hundred ms. **On the
free branch (mode 3) it freezes and pins** (`:1132-1134`) — but mode 3 is the A/B branch, not the
shipping one. Acceptable, and it should be *stated* rather than discovered.

### 7.3 LOW — the R4 clearance probe cannot see the floor under a foot-flat ankle

`:718-724` probes down `s_ragPtRadius[i] + 2` = 5.0 u for a 3.0 foot. With the ankle 5.7 u above
the sole, a perfectly foot-flat authored pose returns `fraction == 1.0` and the ankle keeps the
full 3.0 radius — box bottom 2.7 u above the floor, so the ankle *may* descend up to 2.7 u before
collision stops it. In practice the knee is already in resting contact (velocity zeroed dead at
`:1053-1056`) and the shape-match holds the ankle at its authored goal, so the sink is bounded by
the same residual `drift` as everywhere else. The reverse case — a body on its side with the ankle
3 u up — probes correctly and clamps to 3.0. No action; note it so it is not re-discovered.

### 7.4 HIGH (silent, order-dependent) — the mover budget truncates, and it truncates the feet first

`RagCollideMovers` allows `RAG_MOVER_PER_BODY = 60` traces per body (`:63,1154`) and loops
`for m in movers (≤4) { for i in RAG_PTS }` (`:1176-1197`), returning the instant the allowance is
hit (`:1179-1181`).

```
today : 4 movers × 15 points = 60  == the allowance exactly. Every point, every mover.
after : 4 movers × 17 points = 68  >  60. Three movers complete; the fourth gets 9 of 17 points.
```

Because the inner loop runs in **index order** and the feet are the **highest indices**, the points
silently dropped are, in order: **both feet, both calves, both thighs**. The feet are exactly the
points most likely to be standing on the elevator.

**Fix:** `RAG_MOVER_PER_BODY 60 → 68`, and `RAG_TRACE_BUDGET 240 → 272` so the global ceiling still
covers four bodies fully (240/60 = 4 = 272/68). World traces are unaffected — bug-1967 split them
into `s_ragWorldTraces` (`:1122`), which is incremented and never checked; their bound rises from
15×4×8 = 480 to 17×4×8 = 544/frame, against a peak `worldtr=` of 75 observed live.

### 7.5 LOW — a bigger `RagMoverHash` box can produce a spurious wake

`RagMoverHash` (`:1082-1084`) bounds all `RAG_PTS` points and queries
`CG_GetBrushEntitiesInBounds(4, ...)`, which walks `cg_solidEntities` in list order and takes the
**first four** overlapping bmodels (`cgame/cg_predict.c:96-117`). The hash is a sum, so it is
order-independent *for a fixed set* — but a box that is now ~24 u larger down the leg axis makes
"more than four bmodels overlap" more likely, and then a reshuffle of `cg_solidEntities` between
snapshots changes the set-of-four and the hash, waking a sleeping corpse for no reason (`:1584-1592`:
`lifeMs` reset, `rotLocked` cleared).

Zero mover-wakes have fired across three archived sessions and 145 corpses, so this is theoretical.
**No change this build.** If `mover-wake` lines ever appear without a mover moving, the fix is to
sum *all* overlapping bmodels rather than the first four — and the r9 roadmap's alternative
(delete `RagMoverHash` and the `state==2` rehash outright, keep `RagCollideMovers`) makes the whole
question disappear.

### 7.6 MEDIUM — the rotation latch fires earlier, changing a filter this build is not testing

`RagBodyRotationAdvance` latches `rotLocked` at `nContact >= 3` (`:885-893`). Two more contactable
points, both at the bottom of a landed corpse, means the latch fires **sooner and on more bodies**.
That is a change to the orientation filter caused by a topology change, and `rotlockAt=` /
`ctcmax=` will both move for reasons unrelated to R5. Expect `ctcmax` up by ~2 and `rotlockAt` down.
Not a defect — but any r10-vs-r11 comparison of those two fields is invalid.

### 7.7 Does the shin make the legs springier at `RAG_ITERS 6`? **No.**

Three separate reasons, all checkable:

1. **Chain depth is what governs Gauss-Seidel convergence, and the binding chain does not change.**
   `RagStep`'s link pass (`:975-987`) sweeps root→leaf in index order, so one iteration propagates
   a root displacement to every leaf in a single pass; the residual is the leaf→root back-propagation,
   costing roughly one iteration per level. Depths: arm `Pelvis→Spine1→Spine2→UpperArm→Forearm→Hand`
   = **5** (unchanged, and it already converges at 6). Leg `Pelvis→Thigh→Calf` = 2 → `…→Foot` = **3**.
   **3 < 5.** No new deficit.
2. **The new links are not outliers.** Calf→Foot is 23.9 u against the existing longest link,
   Thigh→Calf at 24.1 u. Same scale, same conditioning.
3. **The foot is damped by two things that already exist.** The `{11,15}` brace (§6.2) bounds its
   swing exactly as `{5,7}` bounds the hand's, and `RagShapeMatch` (`:915-948`) pulls it toward its
   authored goal at alpha 0.25 — a first-order low-pass with a ~32 ms time constant against an 8 ms
   substep.

Constraint count rises 30 → 34 (+13 %); iteration cost rises the same. Total sim cost is a rounding
error against the 0.2–0.4 ms/frame the system already spends.

**The falsifier, and it needs one line of instrument.** If the Calf→Foot link reads high while
Thigh→Calf reads ~1.0, convergence *is* the problem and `RAG_ITERS` goes to 8. Today `stretchMax`
(`:1667-1678`) records only the peak and not **which** link produced it. Add a `byte stretchAt` next
to it and print `stretchat=` — one byte, two lines, and it turns "stretch is high" into "the shin
link is the one stretching".

---

## 8. THE METRIC-CONTINUITY BREAK — read this before comparing any number to r10

Seven instruments change denominator or membership. **Every r10 acceptance threshold keyed on them
is invalid**, and a session that compares r10 numbers to r11 numbers will read a topology change as
a regression.

| instrument | site | change | expected direction |
|---|---|---|---|
| `span=` / `capspan=` | `:1735-1741`, `:746-752` | natural max-axis extension **56.0 u → 79.7 u** (pelvis→head 31.4 + pelvis→ankle 48.3) | **+42 %.** The r8/r9 "57.5 u full extension" reference and the "31.7 % of bodies stretched past 57.5 u" finding are **dead**. New reference: **79.7 u.** |
| `RagSane` span gate | `:1218-1223` | 200 u unchanged, but headroom falls from 3.6× natural to **2.5×** | scaling r9's worst observed (88 u on a 56 u cloud = 1.57×) gives ~125 u. Still clear. **Leave 200 this round** — same reasoning r10 used: do not tighten a gate while re-baselining the quantity it gates. **r12 must not set it from r10 data.** |
| `drift=` | `:1747-1754` | `/(RAG_PTS−1)` = /16, and the two new terms are the points **furthest** from the pelvis anchor (48.3 u vs the knee's 24.6 u). Mean \|goal[j]−goal[0]\| over j=1…14 is 25.3 u; over j=1…16 it is 28.2 u | **~+11 %** for the same orientation error |
| sleep `speed` | `:1712-1716` | `/ RAG_PTS` = /17, and the feet are the points most likely to be velocity-zeroed by the resting-contact snap (`:1053-1056`) | **0 to −12 % lower** → bodies cross the 10 u/s gate sooner. Same direction r10 wanted. **Do not touch the 10 u/s gate** (r9: "never"). Watch the RISK-2 signature: sleep at 1000–1600 ms with `drift > 2` |
| `stretch=` | `:1667-1678` | max over 16 links instead of 14, and the two new ones are joint-longest | **will read higher.** The r10 "≤ 1.15 good / > 1.3 = live violation" bands need re-establishing, which is what §7.7's `stretchat=` makes possible |
| `contacts=` / `ctcmax=` | `:1681-1689`, `:1758-1765` | two more contactable points, both at the bottom | **`ctcmax` up ~2** |
| `rotlockAt=` | `:885-893` | latch threshold `nContact >= 3` is now easier to reach | **fires earlier, on more bodies** |

Only `rot=`, `spin=`, `spinmax=`, `yawf=` and `rawbad=` are unaffected: `RagRawFit` (`:840-853`)
reads `pt[0]`, `pt[1]`, `pt[11]`, `pt[13]` only. **The spin instrument survives the topology
change intact**, which is worth saying out loud — r10's one deliverable stays comparable.

---

## 9. ACCEPTANCE — LIVE-OBSERVABLE, IN ORDER

**Gate 0 — the freeze drill, and an honest warning about it.** `coop_ragdollTest 2`: the corpse must
render as a pixel-perfect normal soldier. But **the drill is structurally blind to the anchor
re-target**: at capture `relPos[ch] = rot0[best]ᵀ·(worldPos − pt[best])` (`:818-819`) and the push
recomposes `pt[best] + rot0[best]·relPos[ch]` with `S = I`, which returns `worldPos` exactly for
*any* choice of `best`. This is the same blindness that hid bug-1966 for eight rounds. The drill
still gates the *render path*; it cannot gate the re-target.

Also note `hzm-mohaa-coop-mod/coop_mod/cfg/rag_drill.cfg` still sets `coop_ragdollMode 3`, so F7
exercises the **free** branch only. `:1963` now supports `coop_ragdollTest 2` on the settle branch
(r9's E9). Update the cfg to `coop_ragdollMode 1`, or run `coop_ragdollMode 1; coop_ragdollTest 2`
from the console, so the drill covers the branch that ships.

**Gate 1 — the re-target, verified directly.** `r_ragdollDebug 2` now draws **17** dots
(`:1358`). Look at a settled corpse: two new dots must sit **at the ankles**, and the boots must sit
on those dots. This is the test the freeze drill cannot be.

**Gate 2 — coverage. Hard stop, this is bug-1969's ground.** `settle-armed` ≥ 95 % of pendings;
**zero** `capture BURIED` lines that were not there in r10. If `buried=` has risen and arms have
fallen, try `coop_ragdollBuriedMax 6` live before concluding anything else. Coverage failing makes
every other number in the log meaningless.

**Gate 3 — THE QUESTION: does the shin bend?** Kill men on stairs, on rubble, over a sandbag lip,
half off a ledge. **Watch the lower legs.** Today the shin is a rigid extension of the thigh and the
boots point wherever the thigh points. If the change works, a shin lying across a step will follow
the step while the thigh keeps its own angle, and the knee will read as a joint rather than as the
end of the body.

**Gate 4 — the free win, and the cheapest test in the build.** Shoot a settled corpse **in the
shin**, low, near the ankle. Today that round is discarded outright (§4: `bestD ≥ radius`). After
the change the lower leg should swing about the knee. Then shoot the same corpse in the calf, high:
today the whole leg slides from the hip; after, the shin should rotate.

**Gate 5 — the instruments.** Log `span=`, `stretch=` (+ `stretchat=` if added), `drift=`, `life=`,
`ctcmax=`, `buried=`, `prelift=` over ≥ 35 bodies and record them as the **new baseline**, not as a
comparison to r10 (§8).

**Do not** press F1 / F10 / F11 during the measurement pass, and do not change
`coop_ragdollTruss` mid-run without saying where in the log it happened.

---

## 10. ROLLBACK

**Console, mid-session, no rebuild:**

| what | command |
|---|---|
| revert the shin *driver* (the calves go back to riding the thigh; the foot points stay as sim/collision points) | `coop_ragdollDrive 0` — **F10**, `rag_ab.cfg`, already exists |
| the whole truss including the two new knee limits | `coop_ragdollTruss 0` |
| the buried threshold, if coverage drops | `coop_ragdollBuriedMax 4` (or 6) |
| back to defaults | **F8** (`rag_run.cfg`) |
| the whole feature | `exec coop_mod/cfg/rag_off.cfg` |

**Be honest about the limit:** `RAG_PTS` is a compile-time array bound, so **the topology itself has
no console rollback**. `coop_ragdollDrive 0` is the meaningful live A/B — it answers "is the
child-driven shin direction responsible for what I'm seeing?" — but it also reverts the arms and
spine, so say so when reading the result.

**Source:** `git -C openmohaa-hzm checkout HEAD -- code/cgame/cg_ragdoll.c`, rebuild,
`.\build.ps1`. Copy `G:\mohaa-gl2\cgame.dll` aside **before** building. Per bug-1634 the DLL must
reach **both** `G:\mohaa-gl2\` (the live install) and the GOG root; `build.ps1` does both, and the
GOG root alone never reaches the running game.

---

## 11. WHAT THIS BUILD DELIBERATELY DOES NOT DO

- **It does not fix the foot's own orientation.** The feet are leaves, so `RagPush` drives them with
  the incoming segment (`:1291`) — the **shin** direction — while the foot's mesh actually runs
  ankle→toe. Same approximation the hands and head already accept, and a strict improvement over
  today (where the foot rides the *thigh*). Fixing it means points 17/18 at `Toe0`, worth ~6 % of
  mesh weight (§4), at the price of two more collision points at the lowest place on the body.
  **Recommend against.**
- **It does not land angular limits, and it must not.** The r9 §3.5 atomicity rule holds: the fold
  braces (now rows **6–17**) stay until the limits replace them, and vice versa.
- **It does not touch F6 or F4** (the deferred clearance-arithmetic corrections), the rotation
  filter, the shape-match, the space contract, the sleep gate, or the renderer.
- **It does not retarget braces 11-12.** §6.2.

## 12. HANDOVER — why this is the prerequisite for the joints build

Four of the twenty-one angular limits in `ragdoll_joints_design.md` §11 are **unimplementable
without these two points**: J18/J19 (knee flexion, hinge `g=11, c=15` / `g=13, c=16`) and J20/J21
(knee out-of-plane), whose moving sets are literally `{15}` and `{16}`. The design's own §3.1
opens by growing the roster to 17 for exactly this reason. Landing the topology alone, first, is
also what makes the limits build judgeable: if feet and limits ship together and the legs still
look wrong, there is no way to tell which one is wrong — the same mistake §8's landing order was
written to prevent for A1 vs A2.
