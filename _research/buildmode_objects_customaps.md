# Custom-Map Placeable-Object Mining — "MOHAA Reunited" Map Packs

Research / inventory only. Nothing was launched, executed, or wired into the mod. Game files untouched.
Sources mined read-only via python-zipfile listing. Date: 2026-07-18.

## Source (already on disk — NOT re-downloaded)

`G:\mohaa_custom_maps\` — 7 pk3 packs, ~2.3 GB total. These are the community "MOHAA Reunited"
(MOHAARU) map-pack bundles; each is a giant grab-bag of third-party MP/DM/OBJ maps plus their loose art.

| Pack (dependency tag) | File | Size | .bsp maps inside |
|---|---|---|---|
| `[x]`     | `x-MOHAARU_Map_Pack.pk3`     | 371 MB | 119 |
| `[xyz]`   | `xyz-MOHAARU_Map_Pack.pk3`   | 348 MB | 98 |
| `[z]`     | `z-MOHAARU_Map_Pack.pk3`     | 410 MB | 117 |
| `[zz]`    | `zz-MOHAARU_Map_Pack.pk3`    | 156 MB | 52 |
| `[zzz]`   | `zzz-MOHAARU_Map_Pack.pk3`   | 327 MB | 126 |
| `[zzzz]`  | `zzzz-MOHAARU_Map_Pack.pk3`  | 424 MB | 109 |
| `[zzzzz]` | `zzzzz-MOHAARU_Map_Pack.pk3` | 260 MB | 45 |

666 total .bsp entries scanned (heavy cross-pack duplication of the same maps). `[zz]` contributed **zero** new placeable objects.

## Method (same as the 1936 batch)

Built a master index of every `models/**` path in the vanilla trilogy (`G:\GOG\...\{main,mainta,maintt}\*.pk3`,
including all HD/xw/geared/HRRTM/coop paks) **plus** the coop mod's own `hzm-mohaa-coop-mod\models\` tree —
which already contains the integrated 1936 objects (muro, seto, ba6, colon, lancia, t26, arbol_*, etc.), so
they auto-exclude. Index = **15,013 model paths / 6,560 distinct `.skd/.skc/.skb` basenames**.

For each placeable-category tik (static / furniture / world / miscobj / props / vehicles / statweapons /
milkshape / items / scenery / debris) in the 7 packs I checked (a) is the tik path already in the index, and
(b) do its `skelmodel`/anim refs introduce a mesh basename absent from the index. **NEW = path absent AND it
ships at least one new mesh basename.** This rejects re-tik'd vanilla meshes and the already-integrated 1936 set.

Scripts: `scratchpad\mine_customaps.py` (index + scan), `scratchpad\inspect_customaps.py` (dedupe-by-mesh + tik dump).
Raw JSON: `scratchpad\customaps_results.json`, `scratchpad\customaps_bymesh.json`.

## Result totals

- Distinct placeable tik paths across the 7 packs: **178**
- Already-in-index (dup path): 29
- New path but reuses an existing/vanilla mesh (retexture/re-tik): 69 → **not new**
- **NEW (new path + new mesh): 80 tik paths → 47 distinct new meshes** (many `_wind` / small/large / regular scale
  variants point at one shared `.skd`; the HitP grass/bush set alone is 30 tiks over 4 meshes).

Solidity note: as in the 1936 batch, none of these tiks declare a clean solid/notsolid flag — MOHAA sets
collision at spawn (the existing `buildmode.scr` solid-toggle handles it). "Solid?" below is a shape/type
judgment. Each tik carries a baked `scale` (milkshape imports are authored in cm → `scale 0.52`; larger props
override, e.g. pak40 2.5, SdKfz 6-7, kübelwagen 4.5, big palms 2.0) — build-mode integration should keep the
tik's own scale.

---

## ⚠️ First, the anachronistic / joke assets — EXCLUDE for WW2 immersion

These are the biggest files but are period-breaking gag props from novelty maps. **Do not place in a WW2 coop mod.**

| Mesh | Path | What it is | Pack | Size |
|---|---|---|---|---|
| `ufo.skb` | `models/milkshape/ufo/ufo.tik` | flying saucer | `[zzzz]` | 999 KB |
| `pool.skb` | `models/milkshape/pool/pool.tik` | swimming pool | `[zzzz]` | 537 KB |
| `bong.skb` | `models/milkshape/bong/bong.tik` | bong | `[zzzz]` | 292 KB |
| `cubus_coke_truck.skd` | `models/milkshape/cubus_coke_truck.tik` | Coca-Cola delivery truck (modern) | `[xyz]` | 463 KB |
| `cubus_jurassic_jeep_top.skd` | `models/milkshape/cubus_jurassic_jeep_top.tik` | Jurassic-Park jeep (movie) | `[xyz]` | 309 KB |
| `cubus_ford_truck.skd` | `models/milkshape/cubus_ford_truck.tik` | modern Ford pickup | `[xyz]` | 218 KB |
| `cubus_pkmchevy.skd` | `models/milkshape/cubus_pkmchevy.tik` | modern Chevy pickup | `[xyz]` | 95 KB |
| `s76-camo.skb` | `models/milkshape/s76-camo/rudolph-s5.tik` | Sikorsky **S-76 helicopter** (`loopsound helico_snd`, "rudolph" xmas gag) | `[z]` | 126 KB |
| `car.skb` | `models/milkshape/car/car.tik` | generic modern car (single flat skin) | `[zzzz]` | 96 KB |
| `popcan.skb` | `models/milkshape/popcan/popcan.tik` | soda can (modern) | `[z]` | 27 KB |
| `quake3_flag.skd` | `models/static/quake3_flag.tik` | Quake-3 CTF flag | `[zzzz]` | 7 KB |

---

## WW2-appropriate new candidates (36 meshes)

### Category A — Vehicles / armor / AT gun (heavy cover) ★

| Mesh | Path | Type | Pack | Scale | Size | Solid | Cover/Deco |
|---|---|---|---|---|---|---|---|
| `pak40.skd` | `models/milkshape/pak40/pak40.tik` | German 7.5 cm **Pak 40 AT gun** | `[zzzzz]` | 2.5 | 191 KB | yes | **statweapon / heavy cover ★** |
| `sdkfz-234-2-puma.skd` | `models/milkshape/sdkfz-234-2-puma/sdkfz-234-2-puma.tik` | **SdKfz 234/2 Puma** armored car (turret+50mm) | `[zzzzz]` | 6.0 | 116 KB | yes | **big cover ★** |
| `sdkfz-234-3-puma.skd` | `models/milkshape/sdkfz-234-3-puma/sdkfz-234-3-puma.tik` | **SdKfz 234/3** support armored car | `[zzzzz]` | 7.0 | 116 KB | yes | **big cover ★** |
| `sdkfz-234-1.skd` | `models/milkshape/sdkfz-234-1/sdkfz-234-1.tik` | **SdKfz 234/1** armored car | `[zzzzz]` | 6.0 | 88 KB | yes | **big cover ★** |
| `kubelwagen.skd` | `models/milkshape/kubelwagen/kubelwagen.tik` | VW **Kübelwagen** field car | `[zzz]` `[zzzzz]` | 4.5 | 46 KB | yes | **cover ★** |
| `triporteur.skd` | `models/milkshape/triporteur/triporteur.tik` | civilian delivery **tricycle** (cargo trike) | `[xyz]` `[zzzzz]` | 0.52 | 78 KB | yes (small) | deco / low cover |

### Category B — Foliage / nature ("HitP" pack — mostly `[zzz]`)

Deduped by mesh; the many `_wind` / `_large` / `_regular` / `_small` tiks are scale/anim variants of one `.skd`.

| Mesh | Rep. path | Type | Pack | Size | Solid | Cover/Deco |
|---|---|---|---|---|---|---|
| `hitppalm2_bent1.skd` | `models/static/hitpmodels/hitppalm2_bent1.tik` | large bent palm | `[zzz]` | 184 KB | trunk | cover/deco |
| `hitppalm2_straight.skd` | `models/static/hitpmodels/hitppalm2_straight.tik` | large straight palm | `[zzz]` | 181 KB | trunk | cover/deco |
| `hitppalm1_bent2.skd` | `models/static/hitpmodels/hitppalm1_bent2.tik` | small bent palm | `[zzz]` | 29 KB | trunk | deco |
| `hitppalm1_bent1.skd` | `models/static/hitpmodels/hitppalm1_bent1.tik` | small bent palm | `[zzz]` | 29 KB | trunk | deco |
| `hitppalm1_straight.skd` | `models/static/hitpmodels/hitppalm1_straight.tik` | small straight palm | `[zzz]` | 24 KB | trunk | deco |
| `hitpgrass1.skd` | `models/static/hitpmodels/hitpgrass1_large.tik` | large grass clump | `[zzz]` | 54 KB | no | deco |
| `hitpbush1.skd` | `models/static/hitpmodels/hitpbush1_large.tik` | leafy bush | `[zzz]` | 29 KB | partial | low cover/deco |
| `hitpgrass_bush1_regular.skd` | `models/static/hitpmodels/hitpgrass_bush1_large.tik` | grass/bush tuft (6 scale tiks) | `[zzz]` | 10 KB | no | deco |
| `hitpgrass_bush2_regular.skd` | `models/static/hitpmodels/hitpfern1_large.tik` | fern / bush (10 tiks: fern1/2 + bush2) | `[zzz]` | 10 KB | no | deco |
| `hitpgrass_bush3_regular.skd` | `models/static/hitpmodels/hitpgrass_bush3_large.tik` | grass/bush tuft (6 scale tiks) | `[zzz]` | 10 KB | no | deco |
| `hitpgrass_bush4_regular.skd` | `models/static/hitpmodels/hitpbush2_large_regular.tik` | grass/bush tuft (8 tiks: bush2/bush4) | `[zzz]` | 10 KB | no | deco |
| `tree_common_fall_orange.skd` | `models/static/tree_common_fall_orange.tik` | autumn tree (orange) | `[zzzzz]` | 13 KB | trunk | cover/deco |
| `tree_common_fall_red.skd` | `models/static/tree_common_fall_red.tik` | autumn tree (red) | `[zzzzz]` | 13 KB | trunk | cover/deco |
| `tree_crunchtree.skd` | `models/static/tree_crunchtree.tik` | bare/crunch tree | `[zzz]` | 13 KB | trunk | cover/deco |
| `bush_fall_red.skc` | `models/static/bush_fall_red.tik` | autumn bush retint (shares an in-index skd; anim only, 192 B) | `[zzzzz]` | ~0 | no | deco (marginal) |
| `bush_fall_yellow.skc` | `models/static/bush_fall_yellow.tik` | autumn bush retint (as above) | `[zzzzz]` | ~0 | no | deco (marginal) |

### Category C — Architecture / set-piece

| Mesh | Path | Type | Pack | Size | Solid | Cover/Deco |
|---|---|---|---|---|---|---|
| `hitpkirche.skd` | `models/static/hitpmodels/hitpkirche_large.tik` | small **church** building | `[zzz]` | 34 KB | yes | set-piece / cover ★ |

### Category D — Furniture / civilian props (village + market/butcher dressing, mostly `[x]` & `[z]`)

| Mesh | Path | Type | Pack | Size | Solid | Cover/Deco |
|---|---|---|---|---|---|---|
| `shovel_dude.skd` | `models/static/shoveling_dude.tik` | animated worker "shoveling coal" (ambient character-prop) | `[zzz]` | 116 KB | yes | deco (living scenery) |
| `chair.skb` | `models/milkshape/chair/chair.tik` | wooden chair | `[z]` | 29 KB | yes (small) | furniture/deco |
| `bakersign.skb` | `models/milkshape/bakersign/bakersign.tik` | hanging baker shop sign | `[x]` | 13 KB | thin | deco (shopfront) |
| `butchersign.skb` | `models/milkshape/butchersign/butchersign.tik` | hanging butcher shop sign | `[x]` | 13 KB | thin | deco (shopfront) |
| `floristsign.skb` | `models/milkshape/floristsign/floristsign.tik` | hanging florist shop sign | `[x]` | 13 KB | thin | deco (shopfront) |
| `sausages.skb` | `models/milkshape/sausages/sausages.tik` | string of sausages | `[x]` | 17 KB | no | deco (butcher/market) |
| `bread.skb` | `models/milkshape/bread/bread.tik` | bread loaf | `[x]` | 13 KB | no | deco (market) |
| `loaf.skb` | `models/milkshape/loaf/loaf.tik` | bread loaf (variant) | `[x]` | 12 KB | no | deco (market) |
| `steak.skb` | `models/milkshape/steak/steak.tik` | cut of meat | `[x]` | 2 KB | no | deco (butcher) |
| `meatknife.skb` | `models/milkshape/meatknife/meatknife.tik` | butcher knife | `[x]` | 3 KB | no | deco (butcher) |
| `bottle.skb` | `models/milkshape/bottle/bottle.tik` | glass bottle | `[z]` | 14 KB | small | deco (tavern) |
| `bottle_broken.skb` | `models/milkshape/bottle_broken/bottle_broken.tik` | broken bottle | `[z]` | 26 KB | small | deco (tavern) |
| `bouteille.skb` | `models/milkshape/bouteille/bouteille.tik` | wine bottle | `[xyz]` `[zzzz]` | 8 KB | small | deco (tavern) |

---

## Top-picks shortlist (~30 best for placing)

WW2-authentic and mechanically useful, in rough priority order:

1. **`pak40` — 7.5 cm Pak 40 AT gun** — the standout. A real German anti-tank gun; drops straight into a
   "statweapon / heavy cover" role, no vanilla equivalent (vanilla only has the flak-88 and mg42 nests). ★
2. **SdKfz 234 armored-car trio — `sdkfz-234-1`, `-2-puma`, `-3-puma`** — three big solid German 8-wheelers =
   instant heavy cover + set dressing; the Puma (234/2) is the most iconic. ★
3. **`kubelwagen`** — VW field car; the everyday German light-vehicle prop the mod currently lacks. ★
4. **`hitpkirche` (church)** — a whole small building as a set-piece / cover block; nothing like it in build-mode. ★
5. **Big palms `hitppalm2_bent1` + `hitppalm2_straight`** — large trunked palms for North-Africa / Pacific map
   dressing (fills the theatre the vanilla European foliage doesn't cover). ★
6. **`triporteur` (cargo trike)** — charming period civilian vehicle; good village/market centerpiece.
7. **Small palms `hitppalm1_bent1/bent2/straight`** — palm variety for layering.
8. **Bush/grass/fern set `hitpgrass_bush1/2/3/4` + `hitpbush1` + `hitpgrass1`** — 6 low-poly greenery meshes
   (34 scale variants) for a "foliage / groundcover" build-mode row; complements existing sandbags/hedge.
9. **Autumn trees `tree_common_fall_orange` / `tree_common_fall_red` + `tree_crunchtree`** — seasonal tree
   variety (Ardennes/Hürtgen look).
10. **`shovel_dude`** — an animated coal-shoveling worker; unique "living scenery" ambient prop.
11. **Shop signs `bakersign` / `butchersign` / `floristsign`** — European-village shopfront dressing; a distinct
    prop class the mod has none of.
12. **Market/butcher clutter `sausages` / `bread` / `loaf` / `steak` / `meatknife`** — fills market-stall scenes.
13. **`chair`** — a plain solid chair (more generic than the WCR cardchairs).
14. **Tavern bottles `bottle` / `bottle_broken` / `bouteille`** — small interior dressing.

(Skip the marginal `bush_fall_red/yellow` — they're 192-byte retints of an already-present bush skd.)

---

## pk3 dependency (to actually use one)

To place any object we must ship the mesh + shaders + textures it needs. Two options per pick:
- **Extract-and-repack** the object's own `models/...` + `textures/...` + shader entries out of the source pack
  into the coop mod (how the 1936 batch was integrated — the winners now live under `hzm-mohaa-coop-mod\models`).
- Or hard-depend on the whole MOHAARU pack (not viable — 150-420 MB each).

Extraction is the right path. Providing pack per pick:
- **Pak 40 + all three SdKfz 234 + fall trees** → `[zzzzz]` (`zzzzz-MOHAARU_Map_Pack.pk3`)
- **All HitP foliage (palms/bushes/grass/ferns), the church, kübelwagen, shovel_dude, crunchtree** → `[zzz]`
- **Triporteur** → `[xyz]` (also in `[zzzzz]`)
- **Shop signs + all market/butcher food** → `[x]`
- **chair, bottles** → `[z]` (bouteille also `[xyz]`/`[zzzz]`)

Each milkshape object stores its skins under a matching `models/milkshape/<name>/…` shader block referencing
`textures/…` in the same pack; the static/HitP objects reference shared shaders (e.g. `kirchemodel`,
`hitp*`) that must be pulled too. Verify per-object shader/texture closure at extraction time.

---

## ⚠️ IP / attribution caveat (user decides — do NOT ship blindly)

- The MOHAARU packs are **community aggregations of third-party maps**; the loose art is authored by many
  different unknown mappers with **no per-asset license** shipped. The milkshape props explicitly carry other
  mods' fingerprints — e.g. `triporteur` and `pak40` share texture names, several tiks are stamped
  "Exported by kmckis @ 8/4/2002", and the SdKfz/Kübelwagen/Pak40 are common cross-mod WW2 assets that likely
  originated elsewhere. Attribution is effectively unknown.
- Higher-risk (most likely borrowed): the SdKfz 234 armored cars, Pak 40, Kübelwagen (classic reused WW2 model
  packs). Lower-risk-looking but still unverified: the HitP foliage set and the market/shop props.
- Recommendation: before importing any of these into a redistributable pk3, try to trace each chosen mesh to its
  original author/mod and confirm a reuse-permissive license — same caution flagged for the 1936 batch.
  This document is inventory only; the user integrates winners separately.

## Staging / follow-up
- Sources: `G:\mohaa_custom_maps\{x,xyz,z,zz,zzz,zzzz,zzzzz}-MOHAARU_Map_Pack.pk3` (read-only).
- Scan scripts + raw JSON in `scratchpad\mine_customaps.py` / `inspect_customaps.py` / `customaps_results.json` / `customaps_bymesh.json`.
