# Build-Mode Object Inventory — Retail Trilogy + Installed Paks (catalog-gap scan)

> Generated 2026-07-18 (read-only scan; no game files modified). Research only — winners
> to be integrated into `coop_mod/buildmode_catalog.scr` separately.
> Sibling agent covers `G:\mohaa_custom_maps`; **this doc = retail AA/SH/BT + installed HD/mod paks only.**

## TL;DR / headline finding

**The build catalog (36 categories, 1,781 placed `.tik` paths) is already near-exhaustive for
placeable RETAIL scene/cover props.** Across every placeable prefix the gap is tiny:

| prefix | in paks | in catalog | **gap** | gap character |
|---|---:|---:|---:|---|
| `models/static/` | 530 | 526 | **4** | 3 are engine groundportals; 1 real (`rubble_bigpile`) |
| `models/furniture/` | 21 | 21 | **0** | complete |
| `models/vehicles/` | 227 | 224 | **3** | all viewmodels / sound-entity (non-placeable) |
| `models/statweapons/` | 59 | 53 | **6** | all `_viewmodel` / `camera_restrict` (non-placeable) |
| `models/miscobj/` | 93 | 91 | **2** | `cameranull`, `cube_transparency` (technical) |
| `models/lights/` | 26 | 26 | **0** | complete |
| `models/gear/` | 67 | 67 | **0** | complete |
| `models/natural/` | 6 | 6 | **0** | complete (rocks/foliage) |
| `models/animate/` | 160 | 158 | **2** | `furniture/safe` (real) + `safe_pulse` |
| `models/items/` | 58 | 57 | **1** | `papers_open2` (real deco) |
| `models/equipment/` | 45 | 43 | **2** | 2 loose German helmet props (real deco) |
| `models/ammo/` | 38 | 32 | **6** | 5 xw-mod clips + `mg_box` (small deco) |
| `models/posed/` | 32 | **0** | **32** | **entire dir missing — best gap (see Tier 1)** |
| `models/emitters/` | 172 | 146 | 26 | mortar-impact FX, mostly damage-dealing (excluded) |
| `models/fx/` | 292 | 213 | 79 | bullet-hole/footstep/explosion decals (excluded) |
| `models/weapons/` | 120 | 85 | 35 | xw standalone guns — viewmodels (optional deco) |
| `models/coop_helmets/` | 32 | 0 | 32 | mod's own helmet-switcher assets (marginal) |
| `models/human/` | 1805 | 0 | 1805 | characters — **excluded by scope** |
| `models/player/` | 313 | 0 | 313 | player skins — **excluded by scope** |
| `models/projectiles/` `models/tests/` | 76 | 0 | 76 | projectiles / test junk — **excluded** |

**Installed HD/retexture paks add ZERO new models** — verified per-pak: `AA_HD_Project_Pak1-4`,
`hd_foliage`, `hd_world`, `hd_charskins`, `hd_skybox`, `hd_gunsounds`, `dds_hdmem`, `dds_override`,
`HRRTM_Pak3_Textures`, `HRRTM_Pak4c_WeaponTGA` = **0 novel `.tik`** each. They only re-skin existing
paths (dedupe-by-path already folds them out). `hd_foliage` (194 MB) adds no new foliage models.

The only mod paks that add NEW model paths add **characters or weapon viewmodels**, not scene props:
- `HRRTM_Pak1_Models` — 1,729 novel `.tik` = 1,495 `human/` + 198 `player/` + 34 `gear/` (all covered) + 2 vehicle recolors.
- `HRRTM_Pak2_Models_misc` — 27 novel = 21 DAK `human/test_dak*` skins + 6 vehicle recolors already in catalog.
- `zzzzz_geared_soldiers` — 12 novel = `player/` rifleman/smg/support gunner variants (player models).
- `zzzzz_xw_weapons` — 37 novel = standalone guns + ammo clips (viewmodels; see optional Tier 3).
- `co-op_hzm_mod_assets_tex` — 128 novel = the mod's own coop assets (helmets, markers, blood fx).

**Bottom line:** there is no large trove of missed retail props. The defensible additions total
~42 core (dominated by the 32 `posed/` figures) + ~40 optional (xw guns / coop helmets / cinematic FX).

---

## Methodology

1. Extracted every `"models/*.tik"` string from `buildmode_catalog.scr` → **covered set (1,781)**.
2. Opened all 38 `.pk3` in `main`, `mainta`, `maintt` (retail + installed HD/mod) as zips; collected
   every `models/**/*.tik` entry → **4,209 distinct**. Added 234 loose `.tik` under the mod's `models/`.
3. `gap = found − covered = 2,428`; bucketed by top-level `models/<subdir>/`; dedupe is by lowercased path
   (so HD retexture overrides of an existing path never count as new).
4. Theater tag by earliest origin: `main`→**AA**, else `mainta`→**SH**, else `maintt` retail pak1-4→**BT**,
   else mod-pak/loose→**BT/MOD**. Scripts: `scratchpad/bm_scan.py`, `bm_report.py`, `bm_cov.py`, `bm_paks.py`, `bm_hrrtm.py`.

Size = footprint/height heuristic (LOW <~40u, MED ~40–100u, TALL >~100u). Solid = static prop → bbox-solid.

---

## TIER 1 — clear wins (add these)

### `models/posed/` — posed static soldiers, dogs & gun crews (32, AA) — NEW CATEGORY
Static, pre-posed figures (standing/kneeling, no AI) built for set-dressing — **distinct from catalog
cat 17 "BODIES + GEAR"**, which only has *lying* `body_*` corpses. Ideal for populating trenches, bunkers,
checkpoints, and manned-gun tableaus. All bbox-solid, MED (human height ~72u).

| path | theater | size | solid | role |
|---|---|---|---|---|
| models/posed/30cal_posed.tik | AA | MED | Y | **cover/deco** — posed .30cal + gunner tableau |
| models/posed/mg42_posed.tik | AA | MED | Y | **cover/deco** — posed MG42 crew tableau |
| models/posed/german_wehrmact_soldier.tik (+ -v1/-v2/-v3) | AA | MED | Y | deco — standing Wehrmacht (4 variants) |
| models/posed/german_wehrmact_grenadier.tik | AA | MED | Y | deco |
| models/posed/german_waffenss_shutze.tik / _nco.tik / _officer.tik | AA | MED | Y | deco — Waffen-SS trio |
| models/posed/german_panzer_shutze / _obershutze / _grenadier / _tankcommander | AA | MED | Y | deco — Panzer crew set (4) |
| models/posed/german_wehrmacht_officer.tik | AA | MED | Y | deco |
| models/posed/german_afrika_private / _grenedeir / _nco / _officer | AA | MED | Y | deco — DAK set (4) |
| models/posed/german_elite_gestapo.tik / german_elite_sentry.tik | AA | MED | Y | deco — elite pair |
| models/posed/german_misc_frogman / _kradshutzen / _scientist | AA | MED | Y | deco — specialists (3) |
| models/posed/german_worker.tik | AA | MED | Y | deco — laborer |
| models/posed/allied_pilot.tik / allied_ranger_soldier.tik | AA | MED | Y | deco — US pilot + Ranger |
| models/posed/allied_resistance_manon / french_resistance-jeff / -paul | AA | MED | Y | deco — resistance trio |
| models/posed/german_shepherd.tik / german_hund_hundpatrol.tik | AA | LOW | Y | deco — dogs (2) |

### Loose single-item wins
| path | theater | size | solid | role | note |
|---|---|---|---|---|---|
| models/static/rubble_bigpile.tik | AA | TALL | Y | **COVER** | large rubble mound; catalog has only `rubble_smallpile` — top cover gap |
| models/animate/furniture/safe.tik | SH | MED | Y | deco/furniture | strongbox/safe; office & bank scenes (skip `safe_pulse` = interactive glow twin) |

---

## TIER 2 — useful scatter deco (add if easy)

| path | theater | size | solid | role | note |
|---|---|---|---|---|---|
| models/equipment/germanhelmet.tik | AA | LOW | Y | deco | loose German helmet (battlefield scatter) |
| models/equipment/german_prop_helmet.tik | AA | LOW | Y | deco | helmet prop variant |
| models/items/papers_open2.tik | AA | LOW | Y | deco | open documents/paperwork (desk dressing) |
| models/ammo/mg_box.tik | AA | LOW | Y | deco | MG ammo box (variant of catalog's belt box) |
| models/ammo/g43clip.tik | BT(xw) | LOW | Y | deco | dropped clip |
| models/ammo/thompson_clip50.tik | BT(xw) | LOW | Y | deco | dropped 50-rd Thompson drum |
| models/ammo/nambu_clip.tik / type100_clip.tik / welrod_clip.tik | BT(xw) | LOW | Y | deco | Japanese clips (exotic scatter) |

---

## TIER 3 — OPTIONAL (weapon viewmodels as rack/table deco — scope said exclude from core)

`zzzzz_xw_weapons.pk3` adds ~30 standalone guns absent from the AA/SH/BT arsenal. As **static rack/table
props** they add real armory-scene variety; as weapon viewmodels they're outside the core placeable scope,
so listed separately. All LOW footprint, bbox-solid, deco.

New-to-trilogy guns (visually distinct): `arisaka`, `arisakasniper`, `carbine` (M1 carbine),
`carcanosniper`, `greasegun` (M3), `lugerp08` (Luger), `moschetto`, `nambu`, `type100smg`, `welrod`,
`tt33`, `ppk`, `30calportable`, `mg42portable`, `thompson50`, `springfield_unscoped`, `garand_scoped`,
`mp44scoped`, `nagant_sniper` — all `models/weapons/*.tik` [BT/xw].
Silenced variants also present (colt_silenced, garand_silenced, mp40silenced, p38silenced, etc.) — lower value.

`models/coop_helmets/` (32, mod's own) — the helmet-switcher assets (e.g. `coop_helmet_net_cig`,
`coop_helmet_ltnt`). As build props they're floating helmets — marginal deco; already consumed by the
helmet-switcher feature. Only worth exposing if you want a "headgear scatter" sub-palette.

`models/fx/cinematic_scenes/c_34/` (4, BT) — `c_34_m_airfleet` (bomber-fleet flyover),
`c_34_m_storm` (storm), `c_34_01`, `c_34_02_02`. Cinematic ambient rigs — cool skybox atmosphere but
map-specific/complex; treat as advanced/experimental, not a simple placeable.

---

## EXPLICITLY EXCLUDED (with reason — do NOT add)

- **`models/fx/bh_*` (34)** bullet-hole decals, **`fx/fs_*` (8)** footstep puffs, **`fx/grenexp_*` (16)**
  grenade-explosion bursts, **`fx/hs_*` / `mortarburst_tree`** hit FX, **`fx/dummy` `unitsquare`
  `waterhelper` `thompsonsmg_sideflash`** — impact/technical FX, spawn-and-die, not placeable scenery.
  (Catalog already samples ambient FX in cats 19 "EFFECTS + EMITTERS" and 32 "FX + EMITTERS 2".)
- **`models/emitters/mortar_*` (25)** — mortar-impact emitters; most are **damage-dealing** (`mortar_snowdeadly`,
  `_nodamage` toggles, triggerable variants) and duplicate one effect. Hazard to place; not scenery.
- **`models/static/*groundportal*` (3), `miscobj/cameranull` `cube_transparency`,
  `statweapons/*_viewmodel` + `camera_restrict`, `vehicles/*_viewmodel` `vehiclesoundentity`** —
  engine-technical / invisible / player-attach entities, not build objects.
- **`models/human/` (1805), `models/player/` (313, incl. `geared_soldiers` + DAK `test_dak*`),
  `models/projectiles/` (54), `models/tests/` (22)** — living characters / player skins / projectiles /
  test junk — outside placeable-prop scope.
- **`models/fx/coop_*`, `models/coop/allied_marker` `axis_marker`, `HRRTM p38 - copy.tik`** — the coop
  mod's own runtime/marker assets and a stray dup; not general scenery.

---

## Per-theater gap totals (useful placeables only)

| theater | Tier 1 | Tier 2 | Tier 3 (optional) |
|---|---|---|---|
| **AA (main)** | 32 posed + rubble_bigpile = 33 | germanhelmet, german_prop_helmet, papers_open2, mg_box = 4 | — |
| **SH (mainta)** | safe = 1 | — | — |
| **BT (maintt retail)** | — | — | cinematic c_34 (4) |
| **BT/MOD (xw / coop paks)** | — | 5 xw ammo clips | ~30 xw guns + 32 coop_helmets |

**Core recommended additions: ~42** (32 posed + safe + rubble_bigpile + 4 AA deco + 5 xw clips).
**With optional Tier 3: ~100+**, but those are viewmodels/marginal.

## Shortlist (copy-ready, best ~42)
```
models/posed/30cal_posed.tik
models/posed/mg42_posed.tik
models/posed/german_wehrmact_soldier.tik
models/posed/german_wehrmact_soldier-v1.tik
models/posed/german_wehrmact_soldier-v2.tik
models/posed/german_wehrmact_soldier-v3.tik
models/posed/german_wehrmact_grenadier.tik
models/posed/german_wehrmacht_officer.tik
models/posed/german_waffenss_shutze.tik
models/posed/german_waffenss_nco.tik
models/posed/german_waffenss_officer.tik
models/posed/german_panzer_shutze.tik
models/posed/german_panzer_obershutze.tik
models/posed/german_panzer_grenadier.tik
models/posed/german_panzer_tankcommander.tik
models/posed/german_afrika_private.tik
models/posed/german_afrika_grenedeir.tik
models/posed/german_afrika_nco.tik
models/posed/german_afrika_officer.tik
models/posed/german_elite_gestapo.tik
models/posed/german_elite_sentry.tik
models/posed/german_misc_frogman.tik
models/posed/german_misc_kradshutzen.tik
models/posed/german_misc_scientist.tik
models/posed/german_worker.tik
models/posed/allied_pilot.tik
models/posed/allied_ranger_soldier.tik
models/posed/allied_resistance_manon.tik
models/posed/french_resistance-jeff.tik
models/posed/french_resistance-paul.tik
models/posed/german_shepherd.tik
models/posed/german_hund_hundpatrol.tik
models/static/rubble_bigpile.tik
models/animate/furniture/safe.tik
models/equipment/germanhelmet.tik
models/equipment/german_prop_helmet.tik
models/items/papers_open2.tik
models/ammo/mg_box.tik
models/ammo/g43clip.tik
models/ammo/thompson_clip50.tik
models/ammo/nambu_clip.tik
models/ammo/type100_clip.tik
```
