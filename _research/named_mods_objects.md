# Named-Mods Placeable-Object Mining — "1936" + "War Chest Restored"

Research/download/diff only. Nothing was launched, executed, or wired into the mod.
Sources mined read-only via python-zipfile / 7-Zip listing. Date: 2026-07-18.

## Downloads (staging: `G:\mohaa_mod_staging\`)

| Mod | File | Bytes | Size | Source |
|---|---|---|---|---|
| 1936 v0.77 (SCW total conversion, BT-only) | `1936\1936v077.rar` | 165,098,308 | 157.45 MB | moddb.com/mods/1936 → file 103880 → mirror `1936v077.rar` |
| War Chest Restored v1.1.0 (cut-content restoration) | `warchest_restored\WarChestRestored_v1.1.0.zip` | 154,244,900 | 147.1 MB | moddb.com/mods/war-chest-restored → file 308671 → mirror `WarChestRestored_v1.1.0.zip` |

Both downloaded fully (HTTP 200) from the same-IP mirror after clicking through ModDB's landing pages
in the browser (direct nav to file pages returns HTTP 500 / empty body — had to click the anchor from the
listing page to get a valid session, then read the `/downloads/start/<id>` mirror link). No captcha hit.

**Archive nesting**
- 1936v077.rar is a *container*: main data lives in `1936v077.part1/2.rar` → `zPak1936f.pk3` (1638 entries, 184 tiks)
  plus `zPak1936g.zip` → `zPak1936g.pk3` (4 tiks: milkshape foliage/stove). `servera.zip`/maps/EN = no placeables.
- WCR zip is a bundle of restoration pk3s (main/mainta/maintt). Model content is only in the three
  `Restoration_{AA,SH,BT}_Pak1-Main.pk3`. The bulk of the 147 MB is FOV/resolution cfg variants + video, not art.

## Method

Built an index of every `models/**` path in the vanilla trilogy (`G:\GOG\...\{main,mainta,maintt}\*.pk3`,
including all HD/xw/geared/HRRTM/coop paks the user already runs) **plus** the coop mod's own
`hzm-mohaa-coop-mod\models\` tree = **14,920 model paths / 6,505 distinct `.skd/.skc` basenames**.
For each placeable-category tik (static / furniture / world / miscobj / props / vehicles / statweapons /
milkshape / items) I checked (a) is the tik path already in the index, and (b) does the tik's `skelmodel`/anim
reference a mesh basename already in the index. NEW = path absent **and** it packs a mesh basename absent from
vanilla+coop. This correctly rejects re-tik'd vanilla meshes (e.g. 1936's "BT-5" tanks point at the vanilla
`t34_base_driveable.skd` → excluded).

---

## WAR CHEST RESTORED — new placeable objects: **4 (all minor furniture)**

WCR is a *cut-content restoration*: it re-enables EA's own unused assets that already ship inside the retail
trilogy paks, so almost every one of its 30 placeable tiks lands on a **path that already exists in the user's
install** (bunkerchair, kingtank, opeltruck, willys_it, welding_torch, camera, naxosplans, the BT statweapons,
etc.) → **not new**. Its value is script-side (mission logic, poems, silencer, HZM options), **not new art**.

The only genuinely-new meshes are 4 destructible chairs from the cut "card-game" bunker scene:

| Path | Type | Mesh size | Solid? | Cover/Deco |
|---|---|---|---|---|
| `models/furniture/cardchair_simplechair.tik` | wooden chair (has death anims) | anim_simplechair.skd 14 KB | yes (small) | deco / furniture |
| `models/furniture/cardchair_simplestool.tik` | stool | anim_simplestool.skd 10 KB | yes (small) | deco / furniture |
| `models/furniture/cardchair_bunkerchairstool.tik` | bunker chair-stool | anim_bunkerchairstool.skd 6 KB | yes (small) | deco / furniture |
| `models/furniture/cardchair_luxuryfootrest.tik` | upholstered footrest | anim_luxuryfootrest.skd 11 KB | yes (small) | deco / furniture |

Meshes live at `models/furniture/chairs/anim_*.skd` with their own shaders (simplechair/luxuryfootrest/…);
each has forward/back collapse death animations. Nice-to-have furniture, low priority.

**Bottom line: WCR yields essentially zero new prop/static/vehicle meshes — just 4 small chairs.**

---

## 1936 — new placeable objects: **~30 distinct new meshes**

The rich source. A Spanish-Civil-War total conversion with a full custom static/vehicle/statweapon set.
Excluded (re-tik'd vanilla, already in install): rubble_bigpile/smallpile, mg42_gun, ab_base, the Carro P40,
Panzer IV (`panzer_iv_d`, `panzeriv_w_*`), sc_v_tractor, `bt5_*` (=vanilla T-34), `corona_tilt` (=unitsquare),
`sc_p_radiotower`, dm_50_healthbox, papers.

### Foliage / greenery (non-solid deco)
| Path | Type | Mesh | Solid | Fit |
|---|---|---|---|---|
| `models/milkshape/GrassTall/GrassTall.tik` | tall grass tuft | 7 KB | no | deco |
| `models/milkshape/VG_Corn1/CornLowPoly.tik` | corn stalk | 16 KB | no | deco |
| `models/static/arbol_alto.tik` | tall tree | tree_tall.skd 64 KB | trunk | cover/deco |
| `models/static/arbol_delgado.tik` | skinny tree | tree_skinny.skd 24 KB | trunk | cover/deco |
| `models/static/arbol_mediano.tik` | medium tree | tree_med.skd 26 KB | trunk | cover/deco |
| `models/static/seto.tik` | hedge row | seto.skd 6 KB | partial | **low cover** |

### Furniture / props
| Path | Type | Mesh | Solid | Fit |
|---|---|---|---|---|
| `models/milkshape/vgstove/vgstove.tik` | cast-iron stove | 83 KB | yes | deco/furniture |
| `models/static/caballo.tik` | horse (static) | 100 KB | yes | deco (animal) |
| `models/static/barnapalm.tik` | small barrier/barrel | 8 KB | likely | small (unverified) |

### Walls / architecture (cover + set dressing)
| Path | Type | Mesh | Solid | Fit |
|---|---|---|---|---|
| `models/static/muro.tik` | masonry wall segment | 32 KB | yes | **strong cover** ★ |
| `models/static/ventana.tik` | window frame (v1) | 3 KB | frame | deco |
| `models/static/ventana2.tik` | window frame (v2) | 3.5 KB | frame | deco |
| `models/static/ventana3.tik` | window frame (v3) | 4 KB | frame | deco |
| `models/static/ventana4.tik` | window frame (v4) | 3 KB | frame | deco |

### Monuments / flags (distinctive set-pieces)
| Path | Type | Mesh | Solid | Fit |
|---|---|---|---|---|
| `models/static/colon.tik` | Columbus column/statue | colon.skd 69 KB | yes | monument, cover/deco ★ |
| `models/static/torico.tik` | Teruel "El Torico" monument | 33 KB | yes | monument deco |
| `models/static/falange.tik` | Falange banner | 15 KB | thin | deco flag |
| `models/static/nacional.tik` | Nationalist flag | bandera.skd 6.6 KB | thin | deco flag |
| `models/static/neutral.tik` | neutral flag (same mesh, skin) | bandera.skd | thin | deco flag |
| `models/static/republicana.tik` | Republican flag (same mesh, skin) | bandera.skd | thin | deco flag |

(`nacional`/`neutral`/`republicana` are 3 skins of one `bandera.skd`.)

### Period vehicles as static cover (best heavy-cover source)
| Path | Type | Mesh | Solid | Fit |
|---|---|---|---|---|
| `models/static/zis5.tik` | ZIS-5 cargo truck | zis5.skd 172 KB | yes | **big cover** ★ |
| `models/static/zis5a.tik` | ZIS-5 truck (variant) | zis5a.skd 266 KB | yes | **big cover** ★ |
| `models/static/lancia.tik` | Lancia truck | lancia.skd 229 KB | yes | **big cover** ★ |
| `models/static/ba6-cuerpo.tik` | BA-6 armored car body | 220 KB | yes | **big cover** ★ |
| `models/static/ba6-torre.tik` | BA-6 turret (pairs w/ body) | 34 KB | yes | cover |
| `models/static/unl35.tik` | UNL-35 armored car | 111 KB | yes | cover |
| `models/vehicles/t26r_tank.tik` | T-26 tank hull | t26.skd 280 KB | yes | **big cover** ★ |
| `models/vehicles/t26r_cannon.tik` | T-26 turret/cannon | 49 KB | yes | cover (pairs) |
| `models/vehicles/t26r_d.tik` | T-26 destroyed wreck | t26d.skd 256 KB | yes | **wreck cover** ★ |

### Stationary weapons (functional or deco)
| Path | Type | Mesh | Solid | Fit |
|---|---|---|---|---|
| `models/statweapons/maxim_gun.tik` | Maxim M1910 HMG | maxim.skd 158 KB | yes | statweapon/deco ★ |
| `models/statweapons/maxim_soporte.tik` | Maxim wheeled mount | soporte.skd 92 KB | yes | deco (pairs) |
| `models/statweapons/modello37_d.tik` | Fiat-Revelli Modello 37 (dmg) | modello_d.skd 151 KB | yes | deco |

---

## Top-picks shortlist (highest build-mode value)

1. **`muro` (wall)** — clean solid cover primitive; era-neutral, drops straight into a "cover / walls" category.
2. **`seto` (hedge)** — natural low cover; complements existing sandbags.
3. **ZIS-5 trucks (`zis5`, `zis5a`) + `lancia`** — large period trucks = instant heavy cover + set dressing.
4. **Armor as cover/wrecks: `t26r_tank` + `t26r_d` (wreck), `ba6-cuerpo`/`ba6-torre`, `unl35`** — big solid blockers; the destroyed T-26 is a ready-made battlefield wreck.
5. **`colon` + `torico` (monuments)** — distinctive statue/column set-pieces, no vanilla equivalent.
6. **`vgstove` (stove)** — the one solid interior furniture piece worth pulling.
7. **`GrassTall` + `CornLowPoly`** — foliage variety for a "greenery" deco row.
8. **`maxim_gun` (+`maxim_soporte`)** — a fresh HMG emplacement look distinct from the vanilla MG42.
9. **(WCR) 4 `cardchair_*` furniture** — minor, but the only new art WCR offers; destructible chairs/stool/footrest.

Solidity note: none of these tiks declare solid/nonsolid in-file — MOHAA sets collision at spawn, which the
existing `buildmode.scr` solid-toggle already handles. "Solid?" above is a shape/type judgment, not a file flag.

---

## ⚠️ IP / attribution caveat (user decides — do NOT ship blindly)

- **1936** is a fan total-conversion. Its new meshes are a mix of team-custom and *possibly third-party* WW2
  assets. Red flags: the trees carry generic `tree_tall/tree_skinny/tree_med.skd` names, and ZIS-5 / T-26 /
  Maxim are common cross-mod WW2 props — any of these could be borrowed from other mods (Red Orchestra-era
  packs, etc.). No per-asset license ships in the archive (only `LEEME.txt` / `manual-es.pdf`, Spanish).
- **War Chest Restored** restores *EA's own cut content* (same IP as the retail trilogy the user already owns);
  the 4 cardchairs are WCR-restored EA cut assets. Lower risk, but still EA IP.
- Recommendation: before importing any of these into a redistributable pk3, confirm the 1936 team's reuse
  policy / original source for the specific meshes chosen (walls, trucks, monuments are the safest custom-looking
  picks; trees/HMG the most likely to be borrowed).

## Staging layout (for follow-up import)
- `G:\mohaa_mod_staging\1936\extract\1936v077\zPak1936f.pk3` — 1936 main data (static/vehicles/statweapons meshes)
- `G:\mohaa_mod_staging\1936\extract\zPak1936g.pk3` — 1936 milkshape foliage + stove
- `G:\mohaa_mod_staging\warchest_restored\1.1.0\MOHAA\main\Restoration_AA_Pak1-Main.pk3` — the 4 cardchairs
- Diff script: `scratchpad\mine_named.py`; raw JSON: `scratchpad\mine_results.json`
