# Player Gore Research — bloody uniforms, wounds, dripping + pooling blood

Research-only report, 2026-07-17. No code was changed. All engine citations are from
`C:\mohaa-coop-dev\openmohaa-hzm\code\...`, mod citations from `C:\mohaa-coop-dev\hzm-mohaa-coop-mod\...`.

---

## Verdict summary

| # | Approach | Verdict |
|---|---|---|
| 1 | Skin-bit flip to bloodied surface shaders | **FEASIBLE — recommended core.** Engine has a complete, replicated, 4-state per-surface skin system that nothing currently uses for damage. |
| 2 | Decals / bullet marks projected onto skeletal models | **IMPOSSIBLE** without major new renderer work. Mark system is world-BSP + brush-model only. |
| 3 | Attached wound props at the hit bone | **FEASIBLE with bone-level (not point-level) precision.** 19 hit locations, each hard-mapped to a named Bip01 bone. Optional polish tier. |
| 4 | Existing blood FX (trails/pools/splats) | Already shipped, ground-only. Gore-on-model + drips are complementary layers, no overlap. |
| 5 | Whole-body gore-TIK swap (`player model x_gore.tik`) | **WORKS but rejected** — approach 1 achieves the same pixels with none of the swap costs (attachment wipe, InitModel, doubled TIK count). |
| 6 | Dripping + pooling blood via the oil-barrel recipe | **FEASIBLE — cheapest high-impact tier.** The barrel FX chain is almost entirely reusable data; only the trigger plumbing is engine code we already own. |

---

## 1. Skin/shader swap via TIKI skin bits — the core mechanism

### 1a. How TIKI skin offsets work

- Each TIKI surface can carry up to **4 shaders** ("skins"): `MAX_TIKI_SHADER 4` — `tiki\tiki_shared.h:97`, storage `char shader[MAX_TIKI_SHADER][MAX_QPATH]` + `int hShader[MAX_TIKI_SHADER]` at `tiki_shared.h:305-307`.
- The parser **appends** every extra `shader` token on a surface as the next skin: `tiki\tiki_parse.cpp:927-948` (`SETUP_SHADER`: errors past 4 at line 933, else `numskins++` at 947). Crucially, `SETUP_SURFACE` looks the surface up **by name** first (`tiki_parse.cpp:884-888`), so a *repeated* line targets the same surface:
  ```
  surface shirt shader airborne_top          // skin 0 (clean)
  surface shirt shader airborne_top_blood1   // skin 1 (light gore)
  surface shirt shader airborne_top_blood2   // skin 2 / 3 (heavy)
  ```
  (Multiple `shader` keywords on one line also parse — the token loop at `tiki_parse.cpp:1077-1099`.)
- All declared skins are shader-registered at model load, so no runtime hitching: `renderergl1\tr_model.cpp:126-155` (`R_RegisterShaders` loops `numskins`, `R_FindShader` each).
- Renderer selection per surface, per frame — `renderergl1\tr_model.cpp:901-931`:
  ```c
  if (*bsurf & 4) continue;                        // MDL_SURFACE_NODRAW        (line 903)
  int iShaderNum = ent->e.skinNum + (*bsurf & 3);  // skin1|skin2 bits -> index (line 912)
  if (iShaderNum >= dsurf->numskins) iShaderNum = 0; // SAFE CLAMP              (914-916)
  shader = tr.shaders[dsurf->hShader[iShaderNum]];
  // (*bsurf & 0x40) = CROSSFADE: draws skin N and N+1 together                 (923-927)
  ```
  The clamp at 914-916 means flipping skin bits on a surface that only has one shader is a harmless no-op — this makes a blanket `surface all +skin1` safe on partially re-authored models.
- Bit definitions: `qcommon\q_shared.h:2028-2035` (`MDL_SURFACE_SKINOFFSET_BIT0/BIT1`, `NODRAW`, `CROSSFADE_SKINS`, and a **vestigial** `MDL_SURFACE_SKIN_NO_DAMAGE` bit 7 with **no writer anywhere in the codebase** — there is no built-in auto-damage-skin system; we must drive the bits ourselves).
- 32 surfaces max per model (`q_shared.h:2026`); player TIKs use ~7 (see 1b), so headroom is fine.

**Four visual states are available per surface**: bits 0..3 → clean / light / heavy / critical, if we author up to 4 shaders. Two states (clean + bloodied) needs only one extra shader line.

### 1b. Player models can be re-authored

Stock player TIK (extracted from `G:\GOG\...\main\Pak0.pk3`, `models/player/allied_Airborne.tik`):

```
surface shirt   shader airborne_top
surface pants   shader airborne_pants
surface sleeve  shader airborne_top_cull
surface head    shader tom            (models/human/heads)
surface hand    shader handsnew       (models/human/hands)
surface gear    shader airborne_gear  (models/equipment/USGear/...)
surface us_helmet shader blank_web
```

One shader per surface today. Re-authoring = ship an override TIK in our pk3 (same path wins over the pak) with one added `surface <name> shader <name>_blood` line per gore-able surface (shirt/pants/sleeve — skip head/hands/gear at first). If the shader token contains a `.` it is treated as a texture path relative to the current `path` (`tiki_parse.cpp:1091-1094`), so we can point straight at composited `.tga`s without writing shader scripts — or declare proper shaders in `scripts/coop_gore.shader` for control.

### 1c. The script/engine command that flips the bits

`Entity::SurfaceCommand` — `fgame\entity.cpp:4199-4288`, exposed as the script event `surface` (`entity.cpp:739-751`):
- tokens: `+skin1` → `MDL_SURFACE_SKINOFFSET_BIT0` (line 4243-4244), `+skin2` → BIT1 (4245-4246), `nodraw` (4247-4248), `crossfade` (4249-4250)
- surface selector: exact name, `name*` prefix wildcard (4208-4210), or **`all`** (4211, 4218-4221) which loops every surface (4264) — combined with the renderer clamp this means `self surface all +skin1` bloodies every surface that HAS a blood skin and no-ops the rest. No per-model surface-name table needed.
- writes `edict->s.surfaces[surface_num] |= mask` (4275) — i.e. straight into entityState.

The mod already uses this live on players every spawn (helmet system: `coop_mod\helmet.scr:157-168`, `surface us_helmet +/-nodraw`), so the command path on Player entities is battle-proven.

### 1d. Replication — YES, for players and actors, including late joiners

- `entityState_t.surfaces[MAX_MODEL_SURFACES]` is a networked field: **every one of the 32 surface bytes is in the entityState netfield table**, 8 bits each — `qcommon\msg.cpp:1380-1475` (`{ NETF(surfaces[0]), 8, ... }` ... `surfaces[31]`).
- cgame copies them verbatim into the refEntity for animated models: `cgame\cg_modelanim.c:1600-1601` (`memcpy(model.surfaces, s1->surfaces, MAX_MODEL_SURFACES)`), and generically for other ents at `cg_ents.c:212-213`.
- Because it is entityState (delta-compressed, full-state to new connections), **late joiners see the current gore state automatically**. Listen host renders through the same cgame path. Zero new netcode.

### 1e. Reset semantics (a feature, not a bug)

A model change / respawn runs InitModel which "rebuilds the model + clears all surface flags/attachments" (documented in `coop_mod\player.scr:1033-1035`; that's why `helmet_apply` re-runs each spawn). So respawn = automatically clean uniform. Mid-life heals (officer medkit, DBNO revive) must explicitly clear the bits (`surface all -skin1 -skin2`).

---

## 2. Decals / marks on skeletal models — definitively NOT supported

- `R_MarkFragments` collects candidate surfaces exclusively from the world BSP: `renderergl1\tr_marks.c:648` — `R_BoxSurfaces_r(tr.world->nodes, ...)`; then tessellates against those (651-665). The only other entry point is `R_MarkFragmentsForInlineModel` (`tr_marks.c:853`) for **brush** submodels.
- cgame wrappers confirm: `CG_GetMarkFragments` (`cgame\cg_marks.c:96-175`) calls only `cgi.R_MarkFragments` (121) and `cgi.R_MarkFragmentsForInlineModel` (175). Nothing accepts a TIKI/skeletal surface.
- A skeletal mark system would have to project into bone space at impact time and re-skin the clipped fragment every frame with the animating mesh (or re-project per frame). That is a new renderer feature on the order of the shadow-mapping backlog, not a port of anything present. **Verdict: rule out bullet-hole decals on bodies.** The visual is better served by approach 3's small wound props and approach 1's textures with painted bullet rents.

---

## 3. Attached wound props at the hit bone

### 3a. The hit-location system (16+ regions, per-bone spheres)

- Enum (19 body regions + miss/general): `qcommon\q_shared.h:1426-1449` — `HITLOC_HEAD(0), HELMET, NECK, TORSO_UPPER, TORSO_MID, TORSO_LOWER, PELVIS, R/L_ARM_UPPER, R/L_LEG_UPPER, R/L_ARM_LOWER, R/L_LEG_LOWER, R/L_HAND, R/L_FOOT` (`NUMBODYLOCATIONS` = 19).
- `trace_t` carries it: `int location` — `q_shared.h:1463`.
- Character models get a **deep trace**: `server\sv_world.c:582-591` — if `clip->traceDeep && touch->tiki->a->bIsCharacter`, `SV_TraceDeep` runs the location-based-damage trace instead of the box clip. (`ischaracter` TIKI keyword sets `bIsCharacter` — `tiki\tiki_parse.cpp:1100-1101`.)
- The LBD trace tests **one sphere per hit location, attached to a named bone tag** — `qcommon\cm_trace_lbd.cpp:31-77`:
  - `szLocArray`: `"Bip01 Head", "Bip01 Head"(helmet), "Bip01 Neck", "Bip01 Spine2"(torso_upper), "Bip01 Spine1"(torso_mid), "Bip01 Spine"(torso_lower), "Bip01 Pelvis", "Bip01 R/L UpperArm", "Bip01 R/L Thigh", "Bip01 R/L Forearm", "Bip01 R/L Calf", "Bip01 R/L Hand", "Bip01 R/L Foot"`
  - with per-location radius (`fLocRadius`, 4–9 units) and bone-local center offsets (`vLocOffset`), plus a secondary sphere set for long bones (`fLocRadius_Secondary`/`vLocOffset_Secondary`, 79-103). `CM_GetHitLocationInfo` returns tag+radius+offset (179-190).

**So the HITLOC → bone mapping is exact and already tabled**: a hit reported as `HITLOC_R_ARM_LOWER` was literally a sphere intersection around "Bip01 R Forearm". Attaching a wound prop to that bone puts it on the correct limb segment. Precision is *bone-segment level*, not bullet-entry-point level (the sphere test returns which sphere, not where on it — `LineSegmentToSphereIntersect` only refines trace fraction, `cm_trace_lbd.cpp:110-172`).

### 3b. Reading the location at damage time

- The damage event signature carries it as **arg 10**: `EV_Damage("damage", ..., "eievvviiii", "attacker damage inflictor position direction normal knockback damageflags meansofdeath location", ...)` — `fgame\entity.cpp:218-227`. (Caution: the human-readable docstring's location list at 223-225 is the legacy ordering — 0=Pelvis, 5=Head. The **enum in q_shared.h is what the engine actually passes**; `Sentient::CheckHitLocation` treats 1 as HELMET, matching the enum — `sentient.cpp:1365-1376`, and downgrades helmet→head when `!WearingHelmet()`.)
- `Sentient::ArmorDamage` reads it: `location = CheckHitLocation(ev->GetInteger(10))` — `sentient.cpp:1422`, early-outs on `HITLOC_MISS` (1424). Player pain stores it (`player.cpp:3503`, `pain_location = iLocation` at 3527). Actors use the same `Sentient::ArmorDamage` (`sentient.cpp:656`; `Player::ArmorDamage` wraps it — `player.cpp:10220,10249`).
- **Script cannot read waittill-event args** (`waittill damage` yields no parameters), so the per-hit location is only usable from game.dll — which we own and already extend heavily in exactly this function (coop boss shield etc., `sentient.cpp:1432-1458`).

### 3c. Attachment mechanics (proven recipe)

- The helmet system attaches exact-fit props to bones with zero offset and they track animation 1:1: `coop_mod\helmet.scr:177` — `attachmodel <tik> "Bip01 Head" 1.0 "coop_helmetProp" 0 -1 -1 -1 -1 (0 0 0)`; removal by tag: `removeattachedmodel "Bip01 Head"` (helmet.scr:151). Attached entities replicate via `entityState.parent/tag_num` (`q_shared.h:2074-2075`), so all clients + late joiners see them.
- Wound prop = a tiny TIK (a few dark-red alpha patches on a 2-4 unit quad or a shallow cone, hue-matched per section 6c) attached at `szLocArray[location]` with the `vLocOffset` for that location. Randomize roll for variety. Cap ~3 per body (track count in game.dll or a `self.flags` counter), skip HAND/FOOT locations.
- Gotchas: model swap/respawn wipes them (fine — reset is desired); attachments inherit bone axes, so the patch model must be authored in bone-local orientation (the helmet work already burned this lesson — bug-535); don't attach to HELMET (prop would float on bare heads after `CheckHitLocation` downgrade... attach to the returned/checked location, not the raw one).

---

## 4. What already exists (ground blood) and how the new layer complements it

All in game.dll (`fgame\sentient.cpp` unless noted), all **ground** effects:

- **Hit feet-splats**: `AddBloodSpurt` traces down and drops a `Decal` with shader `coop_bloodsplat`, tinted red (sentient.cpp:1772-1807; size scaled up for distance readability, `GetBloodSplatSize` 2097-2117, `coop_bloodSplatScale`).
- **Persistent death pool**: `DropBloodPool` (1814-1846) — one non-fading `coop_bloodpool` decal (radius = `coop_bloodPool`, default 44) under the corpse, dark crimson `setColor(0.34, 0.02, 0.02)` (1840). Called from the death path at 1635.
- **Wounded-and-moving trail**: `TryDropBloodTrail` (1853+) — gates: `com_blood`, `coop_bloodTrail` (default 1), health ≤ `coop_bloodTrailHealthFrac`(0.5) × max, interval `coop_bloodTrailInterval`(0.45s), distance `coop_bloodTrailDist`(56u), chance 0.8. Driven per-frame from `Actor::Think` (`actor.cpp:7689`); players via `coop_playerBloodTrail` (`player.cpp:13363-13373`).
- Shaders: `scripts\coop_blood.shader` — `coop_bloodsplat` (polygonOffset, `rgbGen identity`, "red baked into the texture") and `coop_bloodpool` (`rgbGen vertex`, rendered non-fading by cgame's name check).

None of this touches the character model itself. Approach 1 (stained uniform) + approach 6 (drips falling FROM the body) are the missing vertical layer between "he got hit" (spurt) and "he bled on the floor" (splat/pool). No conflicts; the drip's landing splats should *reuse* `coop_bloodsplat` so ground marks stay uniform.

**One trap for the drip trigger**: officer/reinforcement AI under the aihandler pain system run with **faked engine health 5000** while their real HP lives in `self.flags["coop_actorActualHealth"]` (`coop_mod\aihandler.scr:147, 479-487`, decremented at 596-599, officer heal adds 60 at 285-286). Any game.dll gate of the form `health <= max_health * frac` (like TryDropBloodTrail's at sentient.cpp:1879) misfires for them. Gore tiers and drips should therefore key on **accumulated hit count / cumulative damage events**, not health fraction (see design below).

---

## 5. Whole-body gore-skin TIK swap — works, but strictly worse than skin bits

- Live model swap is proven: `helmet.scr:453` (`local.player model ("models/player/" + skin + ".tik")` in `armory_skin_cycle`) and the per-spawn re-force in `player.scr:1021-1031`.
- Costs vs approach 1 for identical pixels: doubles the TIK roster (76 armory skins → 152), full InitModel per transition (visible pop), **wipes attachments** every threshold crossing (helmet + wound props must re-apply — helmet re-hat exists but each swap re-runs it; `player.scr:1033-1035`), interacts with the already-racy skin-persistence writers (bug-715 territory, `player.scr:1022-1027`), and adds heal/damage swap-thrash edge cases. Asset authoring cost is IDENTICAL (same composited blood textures either way).
- Verdict: **rejected**. Keep model-swap only as the fallback if live testing turns up a surprise with skin bits on player entities (none is expected — the helmet system already flips `nodraw` surface bits on players every session).

---

## 6. Dripping + pooling blood — re-skinning the oil-barrel recipe

### 6a. Donor dissection (what the barrels actually do)

**Server (`fgame\barrels.cpp`, engine-coded, barrel-specific):**
- On bullet damage below the fluid line, register a leak hole (max 4 — `barrels.h:30`) at the hit pos/normal and broadcast the one-shot **squirt+splat** effect `CGM_MAKE_EFFECT_4` (oil) / `_8` (water) — `barrels.cpp:422-452`. Bash can't leak (422), grenades/rockets destroy instead (390-402).
- `BarrelThink` (~every 0.075s, 184-259+339): per active leak, compare hole height to the falling fluid top (`m_fFluidAmount / m_fHeightFluid`, 192) and broadcast the **stream** effect — big/medium/small (`CGM_MAKE_EFFECT_1/2/3` oil, `5/6/7` water) — draining 1.0/0.75/0.5 fluid per tick (218-251). Leak above fluid = one last small puff, leak retired (199-214). `liquid_leak` loopsound volume tracks the biggest leak (314-326).

**Wire + cgame (generic, reusable):**
- `CGM_MAKE_EFFECT_1..8` carry just coord+dir; cgame maps them to `SFX_OIL_LEAK_BIG + n` → `sfxManager.MakeEffect_Normal` — `cgame\cg_parsemsg.cpp:1750-1764`; tik lookup table `cgame\cg_specialfx.cpp:354-377`. The mod already extends this exact table (`SFX_COOP_GUNSMOKE`/`BARRELSMOKE`, `cg_specialfx.cpp:405-410`).

**The FX TIKs (pure client-side emitter data — extracted from Pak0, copies in scratchpad `barrelfx\`):**
- `models/fx/barrel_oil_leak_small/medium/big.tik`: dummy skelmodel + two `sfx originspawn` emitters — 1 aligned streak (`model models/fx/barrel_oil_long.tik`, life 0.4, `accel 0 0 -800`, velocity ~28 along the hole normal) + 2 droplet sprites (`barrel_oil_drop.spr`). Bigger leaks = higher counts/velocities.
- `models/fx/barrel_oil_leak_splat.tik`: one streak with `collision`, `dietouch`, **`bouncedecal decalshader barrel_oil_splat decalradius 24`** — i.e. the piece that leaves the ground decal where the squirt lands. `bouncedecal`/`decalradius`/`decalshader` are **generic emitter commands** available to any TIK (`cgame\cg_commands.cpp:990-1018`, handlers 1826-1871, wired at 1324-1339).
- `models/fx/barrel_oil_long.tik`: the streak itself — `splinter.skd` at scale 0.52 with shader `barrel_oil_long`.

**Key finding — there is no engine "pool grows" code.** The growing-puddle impression is an accumulation: the initial squirt's 24-unit `bouncedecal`, one per bullet hole, plus the destroyed-barrel FX. For blood we build the growth deliberately (below) with the server `Decal` class the mod already uses — that part is trivially ours.

**Reusable vs barrel-specific:** everything visual (emitter tiks, streak model, bounce-decal mechanism, sprite shaders) is reusable data. Barrel-specific and NOT needed for blood: the fluid-level bookkeeping, leak slots, and the CGM broadcasts — because unlike a barrel (no entity at the hole), our emitter can simply be **attached to the body entity** server-side and every client will run its emitters locally. Zero new protocol.

### 6b. Blood re-skin design

**New assets (mod pk3, `models/fx/` + `scripts/`):**
1. `coop_blood_long.tik` — clone of `barrel_oil_long.tik` pointing at a new `coop_blood_long` streak shader (hue per 6c). Reuse `splinter.skd` (already licensed/shipped by the game).
2. `coop_blood_drip.tik` — a **looping** emitter (persistent `sfx` emitter with `spawnrate`, not one-shot originspawn): every ~0.6-1.2s spawn 1 `coop_blood_long` streak + 1-2 drop sprites, `accel 0 0 -800`, and on the streak: `collision dietouch bouncedecal decalshader coop_bloodsplat decalradius 6` — so **each drip leaves the mod's exact existing blood mark where it lands**, client-side, for free. A `_slow` variant (half rate) for the injured-but-walking state.
3. `coop_blood_drop` sprite shader (derived from the bloodsplat texture hue).

**Trigger — injured (alive) enemies:** attach ONE `coop_blood_drip_slow.tik` via the attach path (bone `"Bip01 Spine"`, or better: the bone of the worst hit taken, from section 3) when the wound tier reaches "heavy". Hook in game.dll beside the existing wound bookkeeping in `Sentient::ArmorDamage` — NOT on health fraction (aihandler fake-5000 trap, section 4) but on the same accumulated-hits tier counter that drives the skin bits. Remove on heal (clear alongside the skin-bit clear) and on death-tier switch. Players: same mechanism behind `coop_playerBloodDrip` (default off, like `coop_playerBloodTrail`'s conservative default).

**Trigger — corpses:** on death (`sentient.cpp:1635` block, where `DropBloodPool` already runs):
- attach `coop_blood_drip.tik` (full rate) for ~8-15s then remove — dripping off the body, each drop splatting via bouncedecal;
- **growing pool**: keep the current `DropBloodPool` decal as the base layer, then a server-side PostEvent chain drops 3-5 more `coop_bloodpool` decals under the centroid with ramping radius (e.g. 12 → 24 → 36 → `coop_bloodPool`) and slight jitter over ~20s. Because `coop_bloodpool` renders non-fading, the overlap reads as one spreading pool. This is **layering, not replacing** — with `coop_pool_grow 0` behavior is exactly today's single decal. (Corpse-despawn note: pools are decals, they persist independently of the body; the drip emitter dies with the corpse entity — correct.)

Elevation edge case: dripping only reads when the body is above the floor mark (standing wounded AI, bodies on ledges/stairs). The bouncedecal handles any landing surface via its own collision — no extra work.

### 6c. Color match — HARD requirement, exact spec

The mod's blood color authority is its override texture **`C:\mohaa-coop-dev\hzm-mohaa-coop-mod\textures\sprites\bloodsplat.tga`** (128×128; measured: every non-transparent pixel is **RGB (21, 2, 0) = `#150200`**, shape carried entirely in alpha). Both existing ground shaders map this file (`scripts\coop_blood.shader:10,23`).

Rules for every new blood asset:
- Any decal a drip leaves MUST use the existing shaders verbatim: `decalshader coop_bloodsplat` (identity = renders the texture's #150200) — do not invent a new ground-mark shader.
- The streak (`coop_blood_long`) and drop-sprite textures must be **generated from the same hue**: base color `#150200`, alpha-shaped streak/tear-drop (PIL: fill RGB(21,2,0), paint alpha). Shader stage: `blendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA`, `rgbGen identity` — same recipe as `coop_bloodsplat`.
- If any decal path uses `rgbGen vertex`, the tint values already canonized in code are `setColor(0.50, 0.03, 0.03)` for fresh splats and `(0.34, 0.02, 0.02)` for settled pools (`sentient.cpp:1800, 1840`) — reuse those numbers, nothing else.
- The bloodied-uniform overlay textures (section 7 pipeline) sample the same `#150200` for fresh stains, darkened toward `(7,1,0)` for dried edges.
- **Never** reference `barrel_oil_splat`, `barrel_oil_drop.spr`, or retail `blood.spr`-family shaders in the blood variants — wrong hue, would clash.

---

## 7. Recommended design — three tiers

**Tier 1 (core): progressive gore skins via skin bits.**
**Tier 2 (cheapest high-impact): drip + growing pool (barrel recipe re-skin).**
**Tier 3 (optional polish): hit-location wound props.**

### Damage-state driver (shared by all tiers)

One hook, end of `Sentient::ArmorDamage` (`fgame\sentient.cpp`, after the damage actually applies), mirrored clear on heal paths:

- Track `m_iGoreHits` / `m_fGoreDamage` per Sentient (accumulated real damage events — robust against aihandler's faked 5000 HP, section 4). Thresholds (cvar-tuned, e.g. `coop_goreTier1Dmg`/`Tier2Dmg`, or hit counts for AI):
  - Tier reach 1 → `s.surfaces[all] |= SKINOFFSET_BIT0` (light stains)
  - Tier reach 2 → `|= BIT1` as well (index 3 = heaviest, if 4 skins authored; with 2-skin authoring just BIT0)
  - death → leave bits (corpse keeps its gore), start Tier-2 corpse drip/pool
- Clears: respawn is automatic (InitModel resets surfaces + attachments); DBNO revive and officer heal (aihandler.scr:285-286) get an explicit clear (`s.surfaces[i] &= ~(BIT0|BIT1)` + remove drip attachment + reset counters). A tiny script-callable event (`gore_reset`) keeps script-side heals honest.
- Master cvars: `coop_gore` (0/1/2 = off/skins only/skins+drips), obey `com_blood`.
- A script-only fallback exists for players (`player.scr` manage loop + `surface all +skin1` on health thresholds — players have REAL health), but the game.dll hook covers players and every AI class uniformly with hit-location access; recommended.

### Asset pipeline (automated, PIL)

1. Enumerate roster TIKs: armory skin list (`helmet.scr` armory list / `buildmode_actors.scr:34-56` names the `models/player/*.tik` set) + the German AI TIKs actually spawned (AI Model Catalog memory note).
2. Script (scratchpad → `_tools`): unzip each TIK from the paks, parse `setup` for `path`/`surface`/`shader` per gore-able surface (shirt/pants/sleeve/coat equivalents; skip heads/hands/gear initially), resolve each shader to its texture (search paks for `<shader>.tga/.jpg` under the surface's `path`; fall back to scripts/*.shader lookup).
3. Composite: for each diffuse, alpha-blend 2 blood overlay layers (light/heavy) — splatter masks tinted `#150200`→dried `(7,1,0)`, multiply-darkened at wound clusters (chest/abdomen biased). Output `<tex>_blood1.tga`, `_blood2.tga` next to a mirrored path in our pk3.
4. Emit override TIKs: original text + appended `shader` lines per surface (order: clean, blood1, blood2[, blood2]) — keep every other byte identical; ASCII-only, watch the parse-killer checklist.
5. QA pass with the armory 3D preview (rendermodelfit bus) cycling `surface all +skin1/+skin2`.

### Files touched per tier

- Tier 1: `openmohaa-hzm\code\fgame\sentient.cpp/.h` (tier counter + bit writes + clears), `hzm-mohaa-coop-mod\models\player\*.tik` overrides + composited textures (+ optional `scripts\coop_gore.shader`), small clears in `aihandler.scr` heal + DBNO revive script.
- Tier 2: new `models\fx\coop_blood_long.tik`, `coop_blood_drip[_slow].tik`, `scripts\coop_blood.shader` additions (streak/drop stages); game.dll: attach/detach calls in the tier driver + death block, pool-growth PostEvent chain beside `DropBloodPool` (sentient.cpp:1814). No cgame change, no protocol change.
- Tier 3: 2-3 tiny wound-patch TIKs; game.dll attach at `szLocArray[location]` with cap; nothing else.

### Network / replication summary

| Piece | Channel | Late joiner | Listen host |
|---|---|---|---|
| Skin bits | entityState.surfaces netfields (msg.cpp:1380+) | ✔ full state | ✔ same path |
| Wound props / drip emitters | attached entities (parent/tag_num) | ✔ entity exists | ✔ |
| Drip landing splats | client-side bouncedecal (each client computes its own) | ✖ only future drips (matches existing behavior) | ✔ |
| Pool decals | server Decal broadcast (same as today's pools) | ✖ pre-join decals (accepted — identical to current pools) | ✔ |

No new CGM, no protocol bump, no exe/cgame pairing hazard — the whole design is game.dll + pk3 data. (If a CGM route were ever wanted, the mod ships matched exe+cgame anyway, but it isn't needed.)

### Effort estimate

| Tier | Work | Estimate |
|---|---|---|
| 1 — gore skins | game.dll driver + clears | ~0.5 day |
| | pipeline script + composite QA (start: 26 armory allied + ~10 German AI, extend to full 76 later) | 1.5–2 days |
| 2 — drip + pool | tiks/shaders/sprites (donor clones + hue swap) | ~0.5 day |
| | game.dll attach/detach + pool growth + live tuning | 0.5–1 day |
| 3 — wound props | patch models + attach/cap/orientation tuning | 1–2 days (do last; cut if it reads badly) |

Recommended order: **Tier 2 first** (smallest, most visible, donor assets exist), then Tier 1 (the big one), Tier 3 only if the first two leave appetite.
