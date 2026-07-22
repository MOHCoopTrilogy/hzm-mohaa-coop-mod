# Build Mode — Textured Geometry / Crate Placement Research

**Date:** 2026-07-17 · **Scope:** research only, no files changed.
**Question answered:** "There are tons of crates on maps that I don't have access to — can I place geometry with textures modelled after what's baked into the maps?"

**TL;DR**
- The build catalog is **already exhaustive for crate *models*** — every crate/box/supply `.tik` in the paks is in category 10 (`CRATES + SUPPLY`). There is **no missing crate model** to add.
- The "tons of crates on maps" the user can't reach are **`func_crate` brush entities** (1,653 of them across all maps) — BSP brushwork, **not models**. They physically cannot be spawned as a model at runtime.
- The realistic path is exactly what the user intuited: **place a scalable textured box primitive**. The engine already ships a unit-cube mesh and a unit-quad mesh. The winning design is a set of **cube/plank/panel `.tik` variants, each hard-wired to a map-authentic crate/wood/metal/concrete shader**, added as one new build category. This is ~95% a data/asset addition — the existing `buildmode.scr` ghost/place/scale/save pipeline already handles it unchanged.
- **Hard engine limit:** there is **no runtime arbitrary shader/texture assignment**. The script `surface` command only toggles `skin1`/`skin2`/`nodraw`/`crossfade` bit flags (`entity.cpp:4243-4250`). So the texture picker is "cycle pre-authored variant tiks," not "type a shader name at runtime."
- **Second limit:** model `scale` is a **single uniform float** (`entity.cpp:619`) — no per-axis stretch. A cube can only be scaled uniformly, so ship a few base aspect ratios (cube, slab, plank, post, flat tile/panel).

---

## 1) Crate/box/supply props in the paks vs. the catalog

Method: enumerated all **4,152 unique `.tik` paths** across `main` + `mainta` + `maintt` pk3s (script `scratchpad/enum_tiks.py`) and diffed against the 1,804 tiks already referenced by `buildmode_catalog.scr` / `buildmode_actors.scr` / `buildmode_sounds.scr` (`scratchpad/diff_props.py`, `sweep.py`).

**Result: the catalog is essentially complete for props.**

| Prop directory | total `.tik` | already in catalog | missing |
|---|---|---|---|
| `models/static/` | 508 | 504 | 4 |
| `models/miscobj/` | 93 | 91 | 2 |
| `models/items/` | 58 | 57 | 1 |
| `models/furniture/` | 21 | 21 | 0 |
| `models/ammo/` | 38 | 32 | 6 |
| `models/equipment/` | 45 | 43 | 2 |

Every crate/box/cargo/supply/ammobox model already lives in **category 10 `CRATES + SUPPLY`** (`buildmode_catalog.scr:477-529`): `30cal_crate`, `45cal_crate`, `50cal_crate`, `exp_crate1/2/3(a)`, `fragcrate1`, `heat_crate`, `indycrate`, `nazi_crate`, `cratelid1/2`, `snow_crate`, `snowycrate`, `supplydropcrate`, `mg42ammoboxwbelt`, `miscobj/ammocrate`, `miscobj/crate_carry`, the six `models/items/item_*_ammobox`, etc. A full keyword sweep (`sweep.py`) found **44 crate/cargo/supply/ammobox tiks, all already catalogued**.

**Concrete additions worth making** (none are crates — the catalog already has those; these are the only prop-worthy tiks not yet listed):

| `.tik` path | pak | suggested category |
|---|---|---|
| `models/static/rubble_bigpile.tik` | main/Pak0 | 22 `DEBRIS + RUBBLE` |
| `models/ammo/mg_box.tik` | main/Pak0 | 10 `CRATES + SUPPLY` or 25 `AMMO + CLIPS` |
| `models/items/papers_open2.tik` | main/Pak0 | 26 `DOCUMENTS + PAPERS` |
| `models/equipment/germanhelmet.tik` | main/Pak0 | 23 `HELMETS + HEADGEAR + GEAR` |
| `models/equipment/german_prop_helmet.tik` | main/Pak0 | 23 `HELMETS + HEADGEAR + GEAR` |
| `models/ammo/g43clip.tik`, `nambu_clip`, `thompson_clip50`, `type100_clip`, `welrod_clip` | maintt/zzzzz_xw_weapons | 25 `AMMO + CLIPS` |

**The important "missing" tiks are the geometry primitives** (see §3), which are deliberately not props today:

| primitive `.tik` | pak | what it is |
|---|---|---|
| `models/miscobj/cube_transparency.tik` | maintt/pak1 | **unit cube** (`cube_CampFire.skd`, single surface `cube_CampFire`, QUAKED bounds ±8) |
| `models/fx/unitsquare.tik` | main/Pak0 | **unit quad / flat square** (`unitsquare.skd`, `surface all shader blank`) |
| `models/emitters/emitters_cube.tik` | maintt/pak1 | another cube-mesh host |
| `models/miscobj/cube_campfire.tik` | maintt/pak1 | same cube mesh (already catalogued at cat 19/32) |

---

## 2) How map crates are actually built — placeable vs baked

Evidence from the exported BSP entity lumps in `C:\mohaa-coop-dev\map_entities\*.txt` (classname histogram + `func_crate` block inspection).

**The overwhelming majority of "crates on maps" are `func_crate` — a BSP *brush* entity, not a model.**

- **1,653** `func_crate` entities across all campaign maps (m3l1b alone has 163; m1l2b 157; m1l3c 121; …). Sample block from `e1l1_entities.txt`:
  ```
  {
  "model" "*14"          ← inline BSP brush model index, valid ONLY in this .bsp
  "origin" "5194 1812 420"
  "classname" "func_crate"
  "debristype" "3"
  }
  ```
- Engine class confirms it: `openmohaa-hzm/code/fgame/crateobject.cpp` → `CrateObject::CrateSetup` (line ~219) calls `setMoveType(MOVETYPE_PUSH)` and **`setSolidType(SOLID_BSP)`** (line ~232). `crateobject.h:32` `class CrateObject : public Entity`. It has `spawnitems` (drops items on death) and `debristype` (debris FX) — these are the **destructible supply crates** you shoot apart.
- Because the collision hull *is* the compiled brush (`model "*NN"`), a `func_crate` **cannot be reproduced by spawning a `.tik` model** — there is no brush to attach, and `*NN` indices are meaningless outside their own map.

**Static crate *models* also exist and are placeable** — maps reference `.tik` models via `script_object` (3,735 instances) and `script_model` (1,202), and the dumps contain **8,129 `.tik` model references** total (e.g. `"model" "items/item_smg_ammobox.tik"`). The crate `.tik`s use `classname object` (plain static, e.g. `30cal_crate.tik`, `nazi_crate.tik`) or `classname interactobject` (the two `miscobj` carry/ammo crates). **All of these are already in the catalog**, so anything a map places as a crate *model*, the user can already place.

**Texture-only crates (no model at all)** — the baked look the user is chasing. These crate textures exist with **no corresponding `.tik`**, i.e. they are only ever painted onto `func_crate`/world brushes:
- `textures/das_boot/foodcrate1 / foodcrate2a / foodcrate2b / foodcrate3 / foodcrate_end`
- `textures/german/crate_reinforced1_side / _sideflt / _top / _topflt`
- `boxes_eud`, `boxes_eu_wntr`, `boxes_eud_wntr` (shaders in `scripts/tanks.shader`, `vehicles_panzeriv_destroyed.shader`)

**Bottom line for the user:** ~1,650 map crates are brush geometry you can't grab as models. The static crate models you *can* grab are all already in the catalog. To recreate the baked crates you must **place a textured box primitive with the matching crate shader** — §3/§4.

---

## 3) The real ask — placing textured geometry primitives

### Option A — scalable box/plank primitive with a map texture ✅ RECOMMENDED

Everything needed already exists:

- **Mesh:** reuse the stock **unit cube** `models/miscobj/CampFire/cube_CampFire.skd` (+ `.skc` idle) — the mesh behind `cube_transparency.tik`. A single named surface (`cube_CampFire`) makes shader override trivial. For flat surfaces reuse `models/fx/unitsquare.skd` (the "1-unit square centered around the origin").
- **Spawn/scale/place pipeline:** `buildmode.scr` already does `spawn script_model model <tik>` for the ghost (`buildmode.scr:324`) and the real placement (`:399`), applies `scale` (`:402`, `:327`), rotation, z/dist nudge, `solid`/`notsolid`, and writes a paste-ready block to `build_<map>.dat` (`:431-462`). **No engine or core-script change is required** to add box primitives — they are just catalog entries.

**Why not "swap the shader on one cube live":** the runtime `surface` script command **cannot assign a shader**. `Event EV_SurfaceModelEvent` (`entity.cpp:739`) → `Entity::SurfaceModelEvent` (`:4290`) → `SurfaceCommand` only recognizes `skin1` / `skin2` / `nodraw` / `crossfade` bit flags (`entity.cpp:4243-4250`); anything else logs `"Unknown token"`. There is **no `setmaterial`/`setshader`/`reskin`** event anywhere in `fgame`. So the texture choice must be **baked into the asset**, and the user picks a texture by **picking a pre-authored variant tik**.

**Author one tiny tik per (shape × texture).** Example — a wood-crate cube, reusing the stock mesh, wired to the map-authentic `nazi_crate` shader:

```
// hzm-mohaa-coop-mod/models/coop_build/box_crate_nazi.tik
TIKI
setup
{
    scale 0.52
    path models/miscobj/CampFire
    skelmodel cube_CampFire.skd
    surface cube_CampFire shader nazi_crate      // map-authentic crate shader (lightingSpherical)
}
init { server { classname animate } }            // 'animate' = plain static prop; scalable + solid-able
animations { idle cube_CampFire.skc }
```

- Use the **`lightingSpherical`** shader variants (`nazi_crate`, `30cal_crate`, `heat_crate`, `ammocrate1`, …) **not** the `static_*` variants — the `static_*` ones use `rgbGen static` (baked vertex lighting) and render flat/wrong on a runtime model; the plain names use `rgbGen lightingSpherical` (dynamic model lighting). Confirmed in `scripts/crates.shader` / `scripts/paulscrate.shader`.
- Prefer **single-face tileable** textures for clean cube mapping (`crate_reinforced1_side`, `foodcrate1`, wood-plank textures). Multi-face crate atlases (`30cal_crate.tga`) will map approximately on a generic cube's UVs — fine for "close enough," re-UV only if a pixel-perfect match matters.
- **Ship a small shape family** to work around uniform-scale-only (`entity.cpp:619`, `EV_SetScale "f"`): `box_cube` (1:1:1), `box_slab` (wide/low), `box_plank` (long/thin), `box_post` (tall/thin), `panel`/`tile` (flat, from `unitsquare`). Uniform-scaling each covers most crate/wall/floor shapes. Collision: a placed `solid` script_model gets its bbox from the (scaled) mesh bounds; for a precise hull add `setsize` in the tik or via script.

**Saved `.dat` block** is already exactly right (from `buildmode.scr:452-462`) — picking a variant tik just changes the model string:
```
// coop_build #7 models/coop_build/box_crate_nazi.tik
local.m = spawn script_model
local.m model "models/coop_build/box_crate_nazi.tik"
local.m.origin = ( 5194 1812 420 )
local.m.angles = ( 0 90 0 )
local.m scale 2.4
local.m solid
```

### Option B — runtime BSP brush spawning ❌ NOT POSSIBLE

idTech3/MOHAA compiles brushes into the `.bsp` at map-build time; the engine has no runtime CSG/brush creation. `func_crate` proves the constraint — it needs an inline brush model (`model "*NN"`, `SOLID_BSP`). Definitively unavailable; do not pursue.

### Option C — decals / quads / patches

`models/fx/unitsquare.tik` is a ready-made **flat quad** (`surface all shader blank`, `setsize "-1 -0.5 -0.5" "0 0.5 0.5"`). Wrap it the same way as the cube (variant tiks pointing `surface all shader <wall/floor texture>`) to place **flat textured panels / floor tiles / wall patches** — useful for recreating baked wall and floor surfaces, not just crates. No terrain/patch-mesh runtime primitive exists otherwise.

---

## 4) Texture / shader picker

### Recommended: "cycle variant tiks" (zero new engine surface)

Because there's no runtime shader assignment, the picker is just **more catalog items**. Add a new category (e.g. `33: GEOMETRY (SCALABLE)`) whose items are the box/panel variant tiks, one per texture. Cycling model (KP4/KP6) *is* the texture picker; scale (KP+/–), rotate, z/dist, solid, place, undo, and `.dat` capture all already work. Group by shape or by material as you prefer.

**Map-authentic shaders/textures to seed the picker** (all verified present; `scratchpad/tex_sweep.py`, `extract2.py`):

- **Crate shaders** — `scripts/crates.shader` (main/Pak0): `30cal_crate`, `45cal_crate`, `50cal_crate`, `heat_crate`, `nazi_crate`, `static_exp_crate1/2/3` (+ `static_*` baked variants). `scripts/paulscrate.shader`: `ammocrate1`, `ammocrate1rope`.
- **Crate textures (direct paths, if you skip named shaders)** — `textures/models/crates/`: `30cal_crate`, `45cal_crate`, `50cal_crate`, `explosive1/2/3`, `fragcrate1`, `grenade2`, `heat_crate`, `indycrate`, `mg42ammobox`, `mg_ammo`, `nazi_crate`, `pistol`, `rifle`, `shotgun`, `smg_ammo`, `wood_gibs`. Baked-only crate looks: `textures/das_boot/foodcrate1/2a/2b/3`, `textures/german/crate_reinforced1_side/_top`, `textures/models/paulscrate/ammocrate_uswrk`.
- **Wood** (154 files) — e.g. `textures/central_europe/flrwood2`, `textures/general_structure/plank_flat`, `textures/it_barricade/plank_flatnohit`.
- **Metal** (82), **concrete** (54, e.g. `textures/af_extwall/af-e-concrete2*`), **brick** (66), **stone** (204), **sandbag** (`textures/models/sandbags/sb_1..4` + winter `*w`), **barrels** (`textures/barrel/*`).

A raw texture path (e.g. `surface cube_CampFire shader textures/german/crate_reinforced1_side`) also works — the renderer's shader lookup falls back to a default image-based shader — but named crate shaders carry the correct `lightingSpherical` lighting, so prefer them where they exist.

### Optional advanced: live in-place texture cycling via skin bits

If you want to swap a *placed* box's texture without deleting/replacing it, use the one thing the runtime `surface` command *can* do: **`skin1`/`skin2` offset bits** (2 bits → up to 4 skins). This requires authoring a **multi-skin** cube `.skd`/tik (4 shader variants baked as skin offsets), then binding a key to run `<ent> surface cube_CampFire skin1 +` / `skin2 +` on the ghost and placed model, and writing the chosen skin bits into the `.dat` block (as extra `surface … skin1 +` lines). More asset work (multi-skin mesh) for 4 textures per tik; the plain "variant tik per texture" approach (above) is simpler and unlimited, so recommend that first and treat skin-cycling as a later polish.

---

## 5) Engine limitations that constrain the design

| Limitation | Evidence | Consequence |
|---|---|---|
| No runtime arbitrary shader/material assignment | `entity.cpp:739` `EV_SurfaceModelEvent`; `:4243-4250` only `skin1`/`skin2`/`nodraw`/`crossfade`; no `setmaterial` in `fgame` | Texture choice must be **baked into variant tiks**; picker = cycle tiks (or skin bits, max 4/tik) |
| Uniform scale only (single float) | `entity.cpp:619` `EV_SetScale "f"`; `edict->s.scale` is scalar (`:2175`, `:4608`) | Can't stretch one cube per-axis → ship several base aspect ratios (cube/slab/plank/post/tile) |
| No runtime brush creation | `func_crate` uses `SOLID_BSP` + inline `model "*NN"` (`crateobject.cpp` `CrateSetup`) | The 1,653 baked map crates can't be reproduced as models with matching brush hull; approximate with scaled solid box primitives (+ `setsize` for collision) |
| Cube UV vs crate atlas | crate `.tga`s are UV-mapped to their own crate meshes | Generic-cube mapping is approximate; use tileable single-face textures, or re-UV a purpose-built cube if pixel-perfect needed |
| Placed box lighting | `static_*` crate shaders use `rgbGen static` | Use the `lightingSpherical` shader names for runtime script_models |

**Net recommendation:** add a new build category of box/plank/panel primitive tiks (reusing `cube_CampFire.skd` + `unitsquare.skd`), one variant per map-authentic crate/wood/metal/concrete/sandbag shader, seeded from the lists in §4. It needs no engine change and no change to the core `buildmode.scr` place/scale/save loop — only new `.tik` assets in the mod (`hzm-mohaa-coop-mod/models/coop_build/…`) plus catalog rows in `buildmode_catalog.scr`. That gives the user exactly what they asked for: place arbitrary-size boxes textured to match the crates baked into the maps.

### Key file references
- `C:\mohaa-coop-dev\hzm-mohaa-coop-mod\coop_mod\buildmode.scr` — ghost spawn `:324`, place `:399`, scale `:402`, `.dat` block `:431-462`, save `:506-516`
- `C:\mohaa-coop-dev\hzm-mohaa-coop-mod\coop_mod\buildmode_catalog.scr` — cat 10 `CRATES + SUPPLY` `:477`, 32 categories total
- `C:\mohaa-coop-dev\openmohaa-hzm\code\fgame\entity.cpp` — `surface` cmd `:739`,`:4243-4290`; `scale` `:619`
- `C:\mohaa-coop-dev\openmohaa-hzm\code\fgame\crateobject.cpp` / `.h` — `func_crate` = `SOLID_BSP` brush entity
- `C:\mohaa-coop-dev\map_entities\*.txt` — BSP entity dumps (1,653 `func_crate`, 8,129 `.tik` model refs)
- Stock primitives: `models/miscobj/cube_transparency.tik` + `CampFire/cube_CampFire.skd` (maintt/pak1); `models/fx/unitsquare.tik` (main/Pak0)
- Crate shaders/textures: `scripts/crates.shader`, `scripts/paulscrate.shader`, `textures/models/crates/*` (main/Pak0)
```
