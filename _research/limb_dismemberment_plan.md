# Limb Dismemberment / Gibbing from Explosions — Feasibility + Build Plan

> ## PHASE 0 — REVERTED 2026-07-18 (was BUILT same day; decapitation on explosion death, AI only)
> **REVERTED (bug-861, refs bug-856):** this MVP was built and deployed, but the AI went "all glitchy" in
> playtest — an AI regression — so it was pulled. The pre-decap `game.dll` (`game_pre_decap_bak.dll`) was
> restored to the game, and the ENGINE SOURCE was cleaned so a future rebuild won't reintroduce decap:
> removed `Sentient::CoopGoreTryDecapitate` (def + call in the `ArmorDamage` death branch + `sentient.h`
> decl) and the `HeadGibObject` class (`object.cpp`/`.h`), and the `coop_decap*` cvars from `autoexec.cfg`.
> `fgame`/`game.dll` rebuilt clean afterward (zero decap refs). The asset tiks
> (`coop_severedhead.tik`, `coop_stump_neck.tik`) and the `coop_stump` shader block are KEPT (inert without
> the code, harmless in the pk3) for a future fixed re-attempt — this doc is retained for the same reason.
>
> **⚠️ Debugging lead for the re-attempt (NOT yet investigated):** the decap hook fired from the
> `Sentient::ArmorDamage` death branch (`health < 0.1`, right after `CoopGoreTryDripAttach(qtrue)`) and/or the
> `HeadGibObject` spawn — a likely suspect for the "AI all glitchy" symptom is something in that death-path or
> the `object.cpp` change affecting AI state (e.g. head-surface nodraw netfield, helmet-pop re-entry, or the
> thrown physics prop). Start there next time.
>
> ---
>
> ### Original BUILT record (2026-07-18, now reverted — kept for the re-attempt):
> The MVP from this plan was implemented and the `fgame` target (`game.dll`) compiled clean. **game.dll + pk3
> only — NO exe/cgame/renderer.**
>
> **Engine (game.dll):**
> - `fgame/sentient.cpp` — new `Sentient::CoopGoreTryDecapitate(mod, location, damage, direction, position)`
>   called in the `ArmorDamage` death branch (`health < 0.1`, right after `CoopGoreTryDripAttach(qtrue)` ~line
>   1680). Gate: bleedable AI (players skipped, bug-785/797), `com_blood` on, `coop_decap` on, explosion-family
>   MOD (`MOD_EXPLOSION/EXPLODEWALL/GRENADE/ROCKET`), `coop_decapChance` roll. Action: nodraw the `head` surface
>   (replicated `edict->s.surfaces` netfield, the helmet-pop path); pop the helmet if worn
>   (`ProcessEvent(EV_Sentient_PopHelmet)`); throw a `HeadGibObject` off the `Bip01 Head` tag with outward+up
>   velocity + tumble; cap the neck at `Bip01 Neck` with `coop_stump_neck.tik` (reuses a free wound-prop slot for
>   cleanup); attach a 3 s `coop_blooddrip.tik` spurt at the neck. Guards: no double-decap (skips if head already
>   nodraw), graceful skip on missing surface/tag/full-child-table.
> - `fgame/sentient.h` — method decl.
> - `fgame/object.cpp` / `.h` — new `HeadGibObject` class, a near-exact `HelmetObject` clone (SOLID_NOT
>   MOVETYPE_TOSS, `MASK_VIEWSOLID`, fades on `coop_decapLife`, plays `snd_bh_flesh` on landing).
>
> **Assets (pk3, all text; deps verified in Pak0.pk3):**
> - `models/fx/coop_severedhead.tik` — wraps stock `head1.skd` + `hans` face skin + `atease.skc` idle, scale 0.52.
> - `models/fx/coop_stump_neck.tik` — `xbeam.skd` crossed quads + new `coop_stump` shader, scale 3.0.
> - `scripts/coop_blood.shader` — new `coop_stump` block (solid #150200, reuses the `coop_bloodpool` sprite, cull none).
> - Neck spurt reuses the shipped `coop_blooddrip.tik` (no new asset). No `snd_decap` alias added (uses `snd_bh_flesh`).
>
> **Cvars (autoexec.cfg):** `coop_decap 1` (master), `coop_decapChance 100` (0-100 % of blast deaths that decap;
> dial down for grenade-spam horde maps), `coop_decapLife 30` (thrown-head fade seconds). `coop_goreDebug 1`
> prints `^~^~^ DECAP ent=... mod=... loc=... at (...)`.
>
> **Coop replication:** head nodraw = `entityState.surfaces` netfield (full state to late joiners); thrown head +
> helmet = server-spawned entities; stump cap + neck spurt = `entityState.parent/tag_num` attachments — all the
> exact channels the shipped helmet-pop + wound props already use.
>
> **What the user sees:** an AI killed by a grenade/rocket/blast loses its head — the head (and helmet, if worn)
> flies off tumbling and lands, the neck is capped with a bloody stump, and blood spurts from the neck; the
> headless corpse still ragdolls/bleeds/pools normally. Players are never decapitated.
>
> **Better-art notes:** the flying head is an intact face (no bloody cross-section) — a purpose-built head mesh
> with a red neck-cut surface would improve it; the stump cap is crossed quads — a shallow bloody disc/cone
> authored to the neck (bug-535 bone-local orientation) would sit flusher. **Follow-up = Phase 1 (whole-body gib
> burst on close blasts), per the phased plan below.**

Research-only report, 2026-07-18. No code changed, no build, no game launch. Engine citations from
`C:\mohaa-coop-dev\openmohaa-hzm\code\...`, mod citations from `C:\mohaa-coop-dev\hzm-mohaa-coop-mod\...`,
asset facts verified by direct pak (`G:\GOG\...\{main,mainta,maintt}\*.pk3`) inspection.

Builds on the shipped gore stack (`_research/player_gore_research.md`, buglog bug-728..849). This is the
*next* layer: pieces of bodies coming off / bodies torn apart by blasts.

---

## TL;DR verdict

| Effect | Verdict | Why |
|---|---|---|
| **Clean single-limb removal** (one arm/leg gone, rest of body intact) | **NOT feasible on stock meshes** | The human body mesh is **3 fused surfaces** (tunic = torso+both arms, pants = hips+both legs, collar). No per-limb surface exists to hide. Requires re-authoring every enemy `.skd` — expensive Phase 3. |
| **Decapitation** (head off + flying head + neck stump) | **FEASIBLE NOW, cheap** | `head` is a **separate surface** (universal name) on every human. The helmet-pop engine path (`Sentient::EventPopHelmet`) is a turnkey "hide-surface + throw-physics-model" template already working and replicating in coop. |
| **Whole-body gib burst** (blast tears body into chunks/limbs that fly) | **FEASIBLE with authored assets** | The `Gib`/`SpawnBloodyGibs` engine pipeline exists but is **dormant + references missing models**. Wire it up + author chunk/limb props. This is the most faithful reading of "limbs come off from explosions." |

**Overall: realistically doable, MEDIUM difficulty — but NOT as "a limb cleanly detaches."** The achievable,
high-impact version is **decapitation (MVP) + whole-body gib-burst on close blasts**. True per-limb severing
needs mesh surgery on ~50 models and is a separate, expensive project. All of the recommended work is
**game.dll + pk3 data only** (no exe/cgame/renderer pairing — unlike the tier-4 UV wound system), which is the
low-risk deployment profile. The only real cost is **art**: no gib/limb/severed-part model exists anywhere in
the paks and must be authored.

---

## 1. ENGINE CAPABILITY — can we hide a limb via the skin-bit / nodraw path? Which surfaces = which limbs?

### 1a. The nodraw path works and replicates (already proven in coop)

Hiding a surface is the exact mechanism the helmet-pop uses every session:
`Sentient::EventPopHelmet` (`fgame\sentient.cpp:3491`) sets `edict->s.surfaces[iSurf] |= MDL_SURFACE_NODRAW`
(line 3508) to make the helmet vanish, then spawns a physics model at the head tag (below, §4). All 32
`edict->s.surfaces[]` bytes are entityState netfields (`qcommon\msg.cpp:1380+`), so nodraw replicates to every
client and late joiner. `WearingHelmet()` reads the bit back (3477-3489). **So "hide a body part's surface" is
solved and coop-tested.** The renderer honors nodraw at `renderergl1\tr_model.cpp:903` (`if (*bsurf & 4)
continue;`).

### 1b. The blocker: the body mesh has NO per-limb surfaces (verified from the binary .skd)

I parsed the actual body skeleton `models/human/german_wehrmact_soldier/heerprivate.skd` (SKMD v5, from
`main\Pak0.pk3`). **Header reports `numSurfaces = 3`, `numBones = 42`.** The three surfaces are:

| Surface | Covers |
|---|---|
| `Wehrmact_pants` (620 tris) | entire lower body — **hips + BOTH legs** |
| `Wehrmact_tunic` | entire upper body — **torso + BOTH arms** (sleeves are tunic geometry) |
| `Wehrmact_tunic_c` | collar detail |

The 42 bones ARE a full Bip01 rig (`Bip01 L UpperArm`, `L Forearm`, `L Hand`, `R UpperArm`, `R Forearm`,
`R Hand`, `Head`, `Neck`, `Pelvis`, `Spine/1/2`, `L/R Thigh/Calf/Foot` …) — the same bones the hit-location
table maps (`cm_trace_lbd.cpp`). **But mesh geometry is not split along those bones into surfaces.** Nodraw of
`Wehrmact_tunic` removes torso AND both arms together; nodraw of `Wehrmact_pants` removes hips AND both legs.
You cannot hide one arm or one leg.

Confirmed the same shape on the allied side. `allied_airborne_soldier.tik` surfaces:
`shirt` (torso+arms), `pants` (legs), `sleeve` (`airborne_top_cull` — cuff trim only, not a full arm), plus
separate `head` and `hand` skds. Same fused-limb reality.

**What IS a separate surface / skelmodel on every human, therefore hideable cleanly:**

- **`head`** — a separate skelmodel (`head1.skd`..`head8.skd`) included via `models/human/heads/*_heads.tik`;
  surface is **universally named `head`** across ALL german and US head TIKs (verified both
  `german_young_heads.tik` and `us_young_heads.tik`). → **Decapitation is the one clean "part removal" the
  stock assets allow.**
- **`hand`** — separate `models/human/hands/hand.skd`, surface `hand` (both hands, one surface). Not useful as
  a dismemberment unit.
- Gear/helmet surfaces (`us_helmet`, `outside`/`inside`, loadout, clips) — separate, already used by helmet pop.

**Conclusion for #1:** the skin-bit/nodraw path can remove the **head** (clean) or an entire **tunic/pants
half** (looks like the top or bottom of the body vanishing — not a usable "limb"). Per-limb (single arm, single
leg) removal is **impossible without re-meshing the `.skd`**.

---

## 2. SEVERED-LIMB / GIB MODELS — what exists in the paks?

**Nothing usable exists.** I scanned every `.tik/.skd/.spr/.def/.shader` across all 8 `main`, 5 `mainta`, and
27 `maintt` pk3s:

- **No** `gib*`, `*limb*`, `*bodypart*`, `*sever*`, `*dismember*`, `*decap*`, `*amputat*` model of any kind.
- The engine's own gib pipeline references models that **DO NOT SHIP**: `fx_rgib1.tik`..`fx_rgib5.tik`
  (used by `Body::Damage` and `Sentient::SpawnBloodyGibs`), `fx_bspurt.tik` (the default blood spurt),
  and `gib1.def` (the `Gib` default) — **all verified MISSING**. They are FAKK/Alice-era leftovers the
  MOHAA data never included. (This is also why bug-795 had to *default* `blood_model` in code — the TIKs never
  set it and the referenced spurt didn't exist.)
- Only flesh/blood FX present: `models/fx/bloodspurt.tik`, `blood_long.tik`, and the mod's own
  `coop_blooddrip*.tik`. Debris chunks exist only for crates/concrete (`crate-jib-chunk.tik`, `chunkcrete.tik`)
  — wrong material for body gore.

**So all gib/limb visuals must be AUTHORED.** Cheapest sources:

- **Severed head** = wrap an existing head skd (`head1.skd`, tiny, already shipped) in a new
  `models/fx/coop_gib_head.tik` and give it a bloody-neck-stump cross-section (re-texture the neck cap area
  with `#150200`). Lowest-effort part because the mesh already exists.
- **Arm / leg / torso-chunk gibs** = must be modeled. The repo already has a mesh pipeline: the **md5_2_skX
  converter** (`code\tools\md5_2_skX`, "MD5⇆skd/skc/tik, validated") + a Blender kit (`_blender_kit/`). Author
  4-6 crude low-poly meaty chunks → MD5 → skd → tik. This is the main art cost.
- **Fallback for a quick first pass**: a generic red "meat chunk" sprite/blob reused N times (like the barrel
  droplet sprites) — reads as "blown apart" at gameplay distance without per-limb modeling.

---

## 3. STUMP / CAP — filling the hole a hidden part leaves

Hiding `head` exposes the open top of the neck (interior back-faces / a gap). Cap it exactly like the shipped
wound-prop tag-attach (`CoopGoreTryWoundProp`, and the helmet attach recipe `coop_mod\helmet.scr:177`
`attachmodel <tik> "Bip01 Head" ... (0 0 0)`):

- Author one tiny **neck-stump cap** tik (a shallow bloody disc/cone, `#150200` core per the color authority)
  and `attachmodel` it at the **`Bip01 Neck`** tag (or `Bip01 Head` with a downward offset) at the moment of
  decap. Randomize roll for variety. It rides the corpse animation 1:1 (attachments inherit bone axes —
  author in bone-local orientation, the helmet work already burned this lesson, bug-535).
- Add a one-shot **blood spurt** at the neck (reuse `bloodspurt.tik` / the coop drip streak) so the cut reads
  as wet, and optionally a short `coop_blooddrip.tik` bleed from the neck tag (the tier-2 drip path already
  exists — `CoopGoreTryDripAttach`).
- Same recipe generalizes to any future re-meshed limb: stump cap at `Bip01 R UpperArm` etc.

Attachments replicate via `entityState.parent/tag_num` (all clients + late joiners), same channel the helmet
prop and existing wound props already use.

---

## 4. TRIGGER — where and how to fire it (fgame death path)

### 4a. The one hook point

Everything keys off the death branch of `Sentient::ArmorDamage` (`sentient.cpp` `if (health < 0.1)` block,
**~line 1663-1710**) — the same place the shipped gore already calls `DropBloodPool()` (1675) and
`CoopGoreTryDripAttach(qtrue)` (1677). At that point we have `meansofdeath`, `location` (the hit bone, via
`CheckHitLocation`, already computed at 1450), `damage`, `direction`, `position`, `inflictor`, `attacker`.

**Means-of-death constants** (`bg_public.h`): `MOD_EXPLOSION` (466), `MOD_EXPLODEWALL` (467), `MOD_GRENADE`
(471), `MOD_ROCKET` (473), `MOD_IMPACT` (474), `MOD_BASH` (483). Gate the gib/decap on
`MOD_EXPLOSION || MOD_GRENADE || MOD_ROCKET || MOD_EXPLODEWALL` (+ optional `MOD_IMPACT` for high-fall).

### 4b. The faked-health trap is already handled here

Rank-and-file AI run the aihandler pain system with **`self.health = 5000`** and real HP in
`coop_actorActualHealth` (`aihandler.scr:502`). When real HP hits 0, aihandler issues a synthetic
**`self damage ... 150000 ... self.fact.meansofdeath ... self.fact.location`** overkill (`aihandler.scr:623`).
That routes through `ArmorDamage`, drives health hugely negative, and **carries the REAL meansofdeath +
location** into our death branch. So the trigger sees the true blast MOD even for pain-handled troops — no
special-casing needed, and health is always far below the `-75` gates. (Note: do NOT gate on health *fraction*
— bug-747/tier lesson.)

### 4c. Which effect / which part

- **Decapitation**: fire when the killing blow was an explosion/grenade **near the head**, or on a headshot
  overkill. Use `location == HITLOC_HEAD`/`HELMET`, OR (for blasts) a probability that scales with proximity
  (the blast origin vs. the head tag) and `damage`. Reuse the retail `ShouldGib` random-by-damage shape
  (`sentient.cpp:2566`, `G_Random(100) < damage * k`) as the roll.
- **Whole-body gib burst**: fire when an explosion/grenade kill lands **very close** (blast center within ~a
  body-length) or damage is huge. Hide the whole body (`hideModel()` + `SOLID_NOT`, like `Player::GibEvent`
  `player.cpp:10227`) and spawn N `Gib` entities flying outward.
- For "which limb" on a burst, exact choice is unimportant — spray a mix (head + 2 arms + 2 legs + torso
  chunk) with velocities biased away from the blast origin.

### 4d. Reuse vs. revive the dormant retail path

- `Sentient::DoGib` (`sentient.cpp:1358`) and `Sentient::ShouldGib` (2566) exist but **`DoGib` is never called
  anywhere** and `ShouldGib`/`SpawnBloodyGibs` are only referenced from **commented-out** blocks (1519-1552,
  1612-1621). `CreateGibs()` (`gibs.cpp:277`) is an **empty stub** `{}`. `Body::Damage` (`body.cpp:49`) is the
  only *live* path and it spawns the missing `fx_rgib5.tik`.
- So we either (a) fill in `CreateGibs()` to spawn our authored `Gib` props, or (b) write a fresh
  `CoopGibExplode()` beside the existing `CoopGore*` methods. **(b) is cleaner** — keeps it inside the coop
  namespace, avoids resurrecting SP-only assumptions, and lets us cap/scale for coop hordes.

---

## 5. PRECEDENT

- **Retail/OpenMOHAA DOES have a gib framework, but it is inert here.** `class Gib : public Mover`
  (`gibs.h`/`gibs.cpp`) is complete: sets a model, `MOVETYPE_GIB` physics, blood trail bound to it, `Splat`
  drops a `Decal` on landing, `Damage` sprays blood, fade-out after 10-15s. **Two coop gotchas:**
  `Gib::Splat` early-returns unless `g_gametype == GT_SINGLE_PLAYER` (`gibs.cpp:141`) — our coop runs
  `g_gametype 2`, so landing blood would be suppressed; must relax that gate. And `Gib()` + `Body::Damage` +
  `SpawnBloodyGibs` all call `Sound("snd_decap")`, which is **not defined in the mod ubersound** — add an alias
  (missing alias = soft error, but add it).
- **The helmet-pop system is the working template for decapitation** — `Sentient::EventPopHelmet`
  (`sentient.cpp:3491`) + `HelmetObject` (`object.cpp:406`, a physics `Entity`, `MOVETYPE_TOSS`, `g_helmetlife`
  fade, landing clatter). It already does exactly: nodraw a surface → compute the `Bip01 Head` tag world
  orientation (3529-3551) → spawn a model there with randomized linear + angular velocity (3553-3574). Clone it
  as `HeadGibObject` throwing a severed-head model. Coop-tested, replicates.
- **No MOHAA community dismemberment mod is needed as a reference** — the two mechanisms above (surface nodraw
  + thrown physics object; and the Gib/Mover class) are the standard idTech/FAKK approach and are already in
  this tree. (Memory refs `reference_mohaa_moddb`, `kriegs_findings` describe drivable/firing props and
  MP-map-as-AI-arena recipes; neither ships body gibs.) The only thing the community packs would give is *art*,
  and none is present.

---

## 6. MULTIPLAYER / COOP replication

| Piece | Channel | Late joiner | Listen host |
|---|---|---|---|
| Head nodraw (`s.surfaces[head] |= NODRAW`) | entityState.surfaces netfield (`msg.cpp:1380+`) | ✔ full state | ✔ same path as helmet |
| Thrown severed-head / gib entities | server-spawned entities (like `HelmetObject`) | ✔ if still alive (they fade in 10-30s) | ✔ |
| Neck stump cap (attachmodel) | `entityState.parent/tag_num` | ✔ | ✔ |
| Gib landing splats (`Gib::SprayBlood` Decal) | server Decal broadcast (same as existing pools) | ✖ pre-join decals (accepted, matches current pools) | ✔ |

**All server-authored, all game.dll + pk3 — no protocol bump, no exe/cgame/renderer pairing.** This is the
low-risk profile (contrast the tier-4 UV wound work which needed matched renderer+cgame+exe).

**Players: keep dismemberment OFF by default.** The shipped policy is explicit — no holes/blood/pooling on
players (bug-785, bug-797: `IsSubclassOfPlayer` early-outs in every gore path). Mirror that: AI-only. Player
has a `GibEvent` (`player.cpp:10227`) and `Player::Gib()` but they call the stubbed `CreateGibs` and are
gated OUT of gametype-2 use anyway. Add a separate `coop_goreDismemberPlayers 0` cvar if it's ever wanted, but
ship AI-only.

---

## Recommended approach

Two independent, additive effects — **NOT** a promise of "clean single limb off" (the mesh forbids it):

- **A. Decapitation** — nodraw `head` + throw a severed-head model at `Bip01 Head` + neck stump cap + spurt.
  (Clone `EventPopHelmet`.)
- **B. Whole-body gib burst** — hide the body + spawn a spray of authored chunk/limb `Gib` props with blood
  trails + landing splats. (Revive the `Gib` class for coop.)

Both fired from one new hook in the `ArmorDamage` death branch, gated by explosion-family MODs + proximity/
damage, AI-only, cvar-master `coop_goreDismember 0/1/2` (off / decap-only / decap+burst), obeying `com_blood`.

### Engine files to touch (game.dll only)

| File | Change |
|---|---|
| `fgame\sentient.cpp` / `.h` | New `CoopGibExplode(mod, location, damage, direction, position)` called in the `health < 0.1` death branch (~1663). Clone the head-throw math from `EventPopHelmet` into a `CoopDecapitate()` helper. New cvars. |
| `fgame\object.cpp` / `.h` | `HeadGibObject` (copy of `HelmetObject`) for the flying head — or reuse `HelmetObject` with a head model. |
| `fgame\gibs.cpp` | Relax `Gib::Splat` `GT_SINGLE_PLAYER` gate (line 141) for coop; optionally implement `CreateGibs()` (277) to spawn our props, or bypass it. |
| `fgame\aihandler.scr` heal + `dbno.scr` revive | Nothing needed for death-time gore, but keep the existing `gore_reset` clears consistent (heals never un-decapitate a live AI — decap only on death, so N/A). |

### Asset needs (all NEW — nothing exists)

| Asset | Source / effort |
|---|---|
| `coop_gib_head.tik` (severed head) | wrap shipped `head1.skd` + bloody neck cross-section texture. **Low.** |
| `coop_stump_neck.tik` (stump cap) | tiny bloody disc/cone, `#150200`. **Low.** |
| `coop_gib_arm/leg/torso.tik` (burst chunks) | model 3-5 crude meaty chunks via `md5_2_skX` + Blender kit, OR reuse a red meat-blob sprite for a first pass. **Medium (the real cost).** |
| `snd_decap` + gib-hit aliases | add to mod ubersound (wet crunch). **Low.** |
| Blood: reuse `bloodspurt.tik`, `coop_blooddrip*.tik`, `coop_bloodsplat` decal shader | already shipped. **None.** |

### Effort / risk

| Piece | Effort | Risk |
|---|---|---|
| A. Decapitation (engine clone of helmet pop) | ~0.5 day code | **Low** — mechanism proven in coop |
| A. Severed-head + neck-stump assets | ~0.5-1 day art | Low-Med (stump fit tuning, bug-535 orientation) |
| B. Gib-burst wiring (hide body + spawn Gibs + relax gate + cap for hordes) | ~0.5-1 day code | Med — physics/entity-count under count-scaled hordes (up to 80 AI); needs per-frame spawn cap + fast fade |
| B. Chunk/limb gib assets | ~1-2 days art | **Med-High** — no donor art; quality of hand-authored chunks is the main visual risk |
| C. True per-limb severing (Phase 3) | ~1-2 weeks | **High** — re-mesh ~50 `.skd` into per-limb surfaces + cut-seam stumps + UVs |

### Phased build plan

1. **Phase 0 — MVP: Decapitation on explosion/headshot-overkill (AI only).** Engine clone of `EventPopHelmet`
   → nodraw `head`, throw `coop_gib_head.tik`, attach `coop_stump_neck.tik` at `Bip01 Neck`, one neck spurt.
   Trigger: explosion-family MOD death with head proximity, or headshot overkill. `coop_goreDismember 1`.
   Smallest, proven, one clean part comes off, biggest bang-for-buck.
2. **Phase 1 — Whole-body gib burst on close blasts.** Author chunk props, hide body, spawn 4-6 `Gib`s outward
   with blood trails + landing splats, relax the SP gate, per-frame spawn cap, coordinate with corpse-despawn
   (`coop_corpseLife`). `coop_goreDismember 2`. This is the "blown to pieces / limbs fly" explosion look.
3. **Phase 2 — polish**: proximity-scaled probability, direction-biased velocities, blast-size → chunk-count,
   headshot decap from bullets too (optional), tune with the existing gore cvars/palette.
4. **Phase 3 — (defer / maybe never) true per-limb severing.** Re-mesh bodies into per-limb surfaces via
   `md5_2_skX`, author matching stump geometry. Only if 0-2 leave appetite; high effort/risk.

---

## Hardest unknowns (flagged)

1. **Chunk/limb art from zero.** No donor gib model exists; hand-authored chunks are the main quality risk and
   time sink. A sprite/blob first pass de-risks the schedule.
2. **Neck-stump fit + nodraw cleanliness.** Does hiding `head` leave visible interior back-faces before the cap
   lands, and does the cap sit flush across all head skds? Low risk (helmet proves nodraw), but tuning + the
   bone-local orientation gotcha (bug-535).
3. **`Gib`/`MOVETYPE_GIB` under coop.** The class is untested in this fork under `g_gametype 2`; the `Splat`
   SP gate must be relaxed and physics behavior verified. `snd_decap` alias missing.
4. **Entity/network spike under count-scaled hordes.** A grenade into a duplicated horde could try to gib many
   AI at once (up to 80). Needs a hard per-frame gib-entity budget + short fade + LOD (skip full burst for
   distant/off-screen deaths).
5. **Corpse-pipeline coordination.** Gibbing replaces the ragdoll corpse — must play nicely with
   `DropBloodPool`/drip/gurgle (`gurgle.scr` bleed-loop expects a corpse), corpse-despawn, and the officer/DBNO
   systems (DBNO is players-only, so AI gib is safe there).
6. **Per-limb *selection* on a blast is arbitrary** — acceptable to randomize, but if the user expects "the arm
   that was hit comes off," only decap (head) and whole-body burst are honest; targeted single-limb needs
   Phase 3.
