# Build-Mode Object Solidity Audit — m1l1 + m1l2a (and catalog-wide)

> Read-only research, generated 2026-07-18. No game/mod files modified.
> Source of placements: `coop_mod/coop_placements.scr` (18 objects m1l1, 40 objects m1l2a).
> Provenance: `map_entities/*_entities.txt` (every trilogy map). Native bounds read directly
> from the shipping `.tik` files in `G:\GOG\...\{main,mainta,maintt}\*.pk3` and `UBER-MODS-v8.00-MOHAA\models`.

---

## ROOT CAUSE — confirmed from code + tik data

Three failure modes were suspected; **all three are real and now proven**:

**(1) Same-frame `spawn → model → solid` race.** The baked replay does, per object,
`local.m = spawn script_model model X` then immediately `local.m solid` — all in one frame.
`setmodel` only *posts* the model; the skeleton bounds (`getmins`/`getmaxs`) are still **zero this
same frame**. `solid` therefore links a zero/point `SOLID_BBOX`, and nothing re-links it after the
model finishes loading a frame later. The live build tool dodges this by reading bounds off a
*pre-loaded ghost* (`buildmode.scr:418` comment: *"getmins/getmaxs can still be zero this same
frame"*) — but the **baked replay has no ghost**, so the race is unmitigated.

**(2) The baked-in `setsize` guard only fires for scaled objects.** `buildmode.scr:421`:
```
if( local.isActor == 0 && level.coop_build_solid == 1 && level.coop_build_scale != 1.0 ){ ...emit setsize... }
```
So only `scale != 1.0` placements get an explicit `setsize` baked. **Verified in the data:** of 58
placements, only **6** carry `setsize` (all in m1l1: shovel .9, nazi_crate .8, 3× ceramic_pot .8,
wicker_basket 1.5). **All 40 m1l2a solids are bare `solid` with ZERO baked `setsize`** — i.e. the
entire m1l2a set is exposed to the race in (1).

**(3) Decorative model variants ship no collision box at all.** The stock `models/static/vehicle_*`
family loads a *static* `.skb`/`.skd` mesh with **no `setsize` in the tik**, whereas the trilogy's
own placements use the `vehicles/*.tik` entity models, **every one of which carries an explicit
`setsize`**. Same story for `statweapons/aagun_lowcount.tik` (no box) vs the trilogy's
`P_aagun_base.tik` (`setsize "-55 -55 0" "55 55 128"`). A decorative variant made `solid` gets only
its skeleton AABB (often tight or zero) → partial / non-solid.

---

## 1. MASTER TABLE

Native-bounds column: `tik:<box>` = explicit `setsize` shipped in the tik (reliable); `auto(skb)` /
`auto(skd)` = no tik box, relies on skeleton AABB (boxy = OK, thin/flat = partial); `none` = no
usable box. Footprint hint uses game units (16u ≈ 1 ft).

| # | object (.tik) | placed on (count) | trilogy classname / mechanism (map ev.) | native bounds | treatment | swap-to | footprint hint |
|---|---|---|---|---|---|---|---|
| 1 | static/sandbag_large_semicircle | m1l1 ×1 (scale .9) | *no entity use* (static dressing mesh) | auto(skd) | keep_solid_framedefer | — | low wall ~64w×40d×40h, boxy → AABB fine |
| 2 | static/sandbag_small_semicircle | m1l1 ×1, m1l2a ×2 | *no entity use* | auto(skd) | keep_solid_framedefer | — | low cover ~48×28×32 |
| 3 | statweapons/aagun_lowcount | m1l1 ×2 | decorative low-poly AA (real turret = `turretweapon_player_aagun` → `P_aagun_base.tik`) | **none** | **author_footprint_bbox** | (keep model) | use P_aagun box `(-55 -55 0)(55 55 128)` |
| 4 | static/stackedshelves | m1l1 ×2 | *no entity use* | auto(skd) | keep_solid_framedefer | — | tall shelf, boxy |
| 5 | furniture/bunkerchair | m1l1 ×1 | `nonstatic_furniture_bunkerchairstool` uses *bunkerchairstool.tik* (t1l3) | auto(skd) | keep_solid_framedefer | — | seat-height, boxy |
| 6 | static/cot | m1l1 ×1 | *no entity use* | auto(skd) | keep_solid_framedefer | — | low bed, boxy |
| 7 | static/static_clock3 | m1l1 ×1 | *no entity use* | auto(skd) | **mark_notsolid** | — | WALL clock — no cover value |
| 8 | static/static_radiostation3 | m1l1 ×1 | *no entity use* | auto(skd) | keep_solid_framedefer | — | desk box, boxy |
| 9 | static/flowerpainting | m1l1 ×1 | *no entity use* | auto(skd) | **mark_notsolid** | — | WALL painting — flat, no cover |
| 10 | static/shovel | m1l1 ×1 (scale .9) | `addon_*`/dressing | tik: baked `(-8.8 -7.4 0)(0 7.2 67.7)` **(already done)** | author_footprint_bbox ✔ | — | thin, hand-authored — correct |
| 11 | static/nazi_crate | m1l1 ×1 (scale .8) | *no entity use* | tik: baked `(-9.7 -23.1 0)(9.7 23.1 15.1)` **(already done)** | author_footprint_bbox ✔ | — | small crate — correct |
| 12 | static/toolbox_closed | m1l1 ×1 (scale .8) | *no entity use* | auto(skd) | mark_notsolid ✔ **(already notsolid)** | — | tabletop item — correct |
| 13 | static/south_africa_ceramic_pot_6 | m1l1 ×3 (scale .8) | *no entity use* | tik: baked `(-13.9 -29.9 -.1)(13.7 23 39)` **(already done)** | author_footprint_bbox ✔ | — | knee-high pot — correct |
| 14 | static/wicker_basket_2 | m1l1 ×1 (scale 1.5), m1l2a ×4 | *no entity use* | m1l1 baked box; m1l2a **bare solid** | keep_solid_framedefer | — | m1l2a instances need the framedefer fix |
| 15 | animate/it_p_castle | m1l2a ×1 | `addon_e3l4Gag_castle` (e3l4 gag) | auto(skd), tik `scale 0.052` (10th-scale, 3 submeshes) | **needs_manual_review** | — | miniature-castle gag used as cover?? verify intent |
| 16 | static/body_german01 | m1l2a ×1 | *no entity use* (corpse dressing) | auto(skd) | **needs_manual_review** | — | prone corpse — flat, near-floor, low cover value |
| 17 | vehicles/bmwbike_d | m1l2a ×1 | `vehicle_german_bmwbike` → `vehicles/bmwbike.tik` (m1l3b, t1l3) | **tik:`(-45 -30 0)(45 15 50)`** | keep_solid (reliable) | — | motorcycle, torso-high box |
| 18 | player/allied_sas | m1l2a ×1 | *scene actor* (`coop_sceneActorAnimate` thread) | actor capsule | **needs_manual_review** | — | animated NPC, not cover — solidity handled by actor |
| 19 | **static/vehicle_opeltruck** | m1l2a ×1 | decorative static (trilogy uses `vehicle_german_opeltruck` → `vehicles/opeltruck.tik` — incl. **m1l2a itself**, m1l2b, m1l3a/b/c) | **none** (opelstatic.skd, no box) | **swap_model_variant** | **vehicles/opeltruck.tik** | full truck; target box `(-160 -56 0)(160 56 60)` |
| 20 | furniture/roundedchair_d | m1l2a ×2 | *no entity use* | auto(skd) | keep_solid_framedefer | — | chair, seat-height |
| 21 | static/simpledesk_ns | m1l2a ×1 | trilogy places as `script_model` (m6l2a). `_ns` == identical dup of simpledesk.tik | auto(skd) | keep_solid_framedefer | — | desk, boxy |
| 22 | miscobj/g_magazine_ib4 | m1l2a ×1 | `interactobject_magazine_german_ib4` (m3l2, m4l3) | tik:`(-4 -4 0)(4 4 8)` | **mark_notsolid** | — | tabletop magazine — no cover value |
| 23 | gear/german_ssofficercap | m1l2a ×1 | dressing / flyoff prop | tik:`(-8 -8 -8)(8 8 8)` | **mark_notsolid** | — | hat on desk — no cover value |
| 24 | miscobj/bottle_medicine | m1l2a ×1 | `interactobject_decor_bottle-generic` (m4l3, m5l3, t2l1) | tik:`(-4 -4 0)(4 4 8)` | **mark_notsolid** | — | tabletop bottle — no cover value |
| 25 | static/widepainting | m1l2a ×1 | *no entity use* | auto(skd) | **mark_notsolid** | — | WALL painting — flat, no cover |
| 26 | static/smallfilecabinet | m1l2a ×1 | *no entity use* | auto(skd) | keep_solid_framedefer | — | cabinet, boxy |
| 27 | static/door_frame | m1l2a ×1 | *no entity use* | auto(skd) | keep_solid_framedefer | — | frame slab; AABB fills opening — OK as wall seg |
| 28 | static/wagon | m1l2a ×1 | *no entity use* | auto(skd) | keep_solid_framedefer | — | cart, boxy body |
| 29 | statweapons/nebelwerfer | m1l2a ×1 | `turretweapon_german_nebelwerfer` → `statweapons/nebelwerfer.tik` (m3l3, t2l1) | auto(skd) — tik box commented out | keep_solid_framedefer | — | rocket rack; AABB ok, barrels may overhang |
| 30 | static/it_p_radarstation | m1l2a ×1 | *no entity use* (BT dressing) | auto(skd) | keep_solid_framedefer | — | tall station, boxy |
| 31 | vehicles/bmwbike | m1l2a ×1 | `vehicle_german_bmwbike` → `vehicles/bmwbike.tik` (m1l3b, t1l3) | **tik:`(-45 -30 0)(45 15 50)`** | keep_solid (reliable) | — | motorcycle |
| 32 | vehicles/sdkfz_afrika | m1l2a ×2 | `vehicle_german_sdkfz` → `vehicles/sdkfz.tik` (m3l3, m5l2a); afrika = reskin sibling | **tik:`(-130 -64 0)(174 72 50)`** | keep_solid (reliable) | — | halftrack, long low box |
| 33 | animate/body_2nd-ranger-engineer2 | m1l2a ×1 | *no entity use* (posed soldier) | **tik:`(-16 -16 0)(16 16 8)`** — FLAT floor box | **author_footprint_bbox** | (keep model) | standing figure but box is 8u tall → author `(-16 -16 0)(16 16 72)` |
| 34 | static/trench_shovel | m1l2a ×1 | `addon_trench-shovel` → `static/trench_shovel.tik` (t2l3) | auto(skd), tik `scale 1.0` | **author_footprint_bbox** | (keep model) | thin leaning shovel — author `(-6 -6 0)(6 6 66)` or notsolid |
| 35 | miscobj/clipboard | m1l2a ×1 | `interactobject_items_clipboard` (m4l2) | auto(skd) | **mark_notsolid** | — | tabletop clipboard — no cover value |
| 36 | static/indycrate | m1l2a ×5 | *no entity use* | auto(skd) | keep_solid_framedefer | — | crate — ideal boxy cover |
| 37 | vehicles/mercedes | m1l2a ×2 | `vehicle_german_mercedes` → `vehicles/mercedes.tik` (e1l3, t3l1) | **tik:`(-100 -40 0)(110 40 90)`** | keep_solid (reliable) | — | staff car |
| 38 | **animate/vehicle_german_opeltruckgreen_canopy** | m1l2a ×1 | trilogy uses `vehicle_german_opeltruckgreen_canopy` → `vehicles/opeltruckgreen_canopy.tik` (e1l1/e1l3/e2l3/m4l2/t3l1) | tik box **SHRUNK** `(-50 -40 0)(50 40 60)` (100×80 vs real 320×112) | **swap_model_variant** | **vehicles/opeltruckgreen_canopy.tik** | real box `(-160 -56 0)(160 56 60)` — full truck footprint |
| 39 | vehicles/european_car_tan | m1l2a ×1 | *no entity use of this reskin* (base `car.tik` family) | **tik:`(-115 -40 0)(110 40 100)`** | keep_solid (reliable) | — | civilian car |
| 40 | weapons/kar98sniper | m1l2a ×1 | `script_model` prop (m1l2a itself, m4l2); playerweapon elsewhere | **none** (weapon viewmodel — no world box) | **author_footprint_bbox** | (keep model) | thin leaning rifle — author `(-6 -22 0)(6 22 40)` or notsolid |
| 41 | static/produce_cart | m1l2a ×1 | *no entity use* | auto(skd) | keep_solid_framedefer | — | market cart, boxy body |

---

## 2. BUCKETS (with counts)

Totals: **41 distinct objects** across **58 placements** (m1l1 = 18, m1l2a = 40).

### keep_solid_framedefer_autobbox — **21 distinct**
Real solid props whose skeleton/`.skb` AABB is adequate (boxy) — no swap, no hand box. They only
need the **shared-waitframe + capture-setsize** mechanism fix so the scale-1.0 race stops zeroing them.
- *Statics (16):* sandbag_large_semicircle, sandbag_small_semicircle, stackedshelves, cot,
  bunkerchair, roundedchair_d, simpledesk_ns, smallfilecabinet, door_frame, wagon, it_p_radarstation,
  indycrate, produce_cart, static_radiostation3, nebelwerfer, wicker_basket_2.
- *Vehicles — tik already carries `setsize`, already reliable (5):* bmwbike, bmwbike_d, mercedes,
  sdkfz_afrika, european_car_tan. (Still route them through the same loop; harmless and uniform.)

### swap_model_variant — **2 distinct**
Decorative variant → the trilogy's properly-collided entity model (evidence in swap list §4).
- static/vehicle_opeltruck → **vehicles/opeltruck.tik**
- animate/vehicle_german_opeltruckgreen_canopy → **vehicles/opeltruckgreen_canopy.tik**

### author_footprint_bbox — **7 distinct** (4 to fix + 3 already done)
AABB is absent / thin / flat; hardcode an explicit `setsize` (values in §3).
- **To fix (4):** aagun_lowcount, body_2nd-ranger-engineer2, trench_shovel, kar98sniper.
- Already correct (reference, 3): shovel, nazi_crate, south_africa_ceramic_pot_6.

### mark_notsolid_decorative — **8 distinct** (7 to change + 1 already done)
Tiny tabletop / flat wall items — solidity is pointless and only creates invisible clip nubs.
- **Recommend notsolid (7):** static_clock3, flowerpainting, widepainting, g_magazine_ib4,
  german_ssofficercap, bottle_medicine, clipboard.
- Already notsolid (reference, 1): toolbox_closed.

### needs_manual_review — **3 distinct**
- animate/it_p_castle — a 10th-scale miniature-castle *gag* prop used as cover; confirm intent
  (likely should be a scaled-up landmark or removed, not a cover box).
- static/body_german01 — prone corpse; flat near-floor collision, negligible cover. Keep low-solid
  or notsolid per taste.
- player/allied_sas — animated scene actor (runs `coop_sceneActorAnimate`); not a cover prop, its
  solidity belongs to the actor system, not the bbox fix.

---

## 3. MECHANISM FIX SPEC — make baked solidity reliable

The current baked pattern (per object, one frame):
```
local.m = spawn script_model model X
local.m.origin = ...   local.m.angles = ...
local.m solid                         // <-- links a ZERO bbox (model not loaded yet)
```

### Fix: split the block into three phases with **one shared waitframe**

**Phase A — spawn + model + transform ALL objects (no solid yet).** Keep every handle in an array:
```
local.i = 0
local.m[local.i] = spawn script_model ; local.m[local.i] model "models/..." 
local.m[local.i].origin = ( ... ) ; local.m[local.i].angles = ( ... )
if(<scaled>) local.m[local.i] scale <s>
local.solidWanted[local.i] = 1        // or 0 for notsolid decor
local.box[local.i] = <baked box or NIL>
local.i++
// ...repeat for all placements...
```

**Phase B — ONE shared waitframe** (this is the whole trick; do it once, not per object):
```
waitframe                              // now every model's getmins/getmaxs are valid
```

**Phase C — solidify with an EXPLICIT, now-valid box.** For each object:
```
if( local.solidWanted[local.i] == 0 ){ local.m[local.i] notsolid }
else {
    if( local.box[local.i] != NIL ){                 // author_footprint / swap targets
        local.m[local.i] solid
        local.m[local.i] setsize local.box[local.i][0] local.box[local.i][1]
    } else {                                          // keep_solid autobbox
        local.mn = local.m[local.i] getmins * <scale>   // scale defaults 1.0
        local.mx = local.m[local.i] getmaxs * <scale>
        local.m[local.i] solid
        local.m[local.i] setsize local.mn local.mx      // lock the valid bounds explicitly
    }
}
```
`* <scale>` is mandatory: engine `setScale` never touches `r.mins/r.maxs` (bug-829), so `getmins`
returns **base** bounds; a scaled object must multiply. For scale 1.0 it is a no-op.

> Equivalent alternative if you prefer not to restructure the loop: **bake a `setsize` for EVERY
> object at capture time**, not just scaled ones — i.e. drop the `&& level.coop_build_scale != 1.0`
> clause at `buildmode.scr:421` so the ghost's `getmins*scale/getmaxs*scale` box is written for
> scale-1.0 placements too. Then the existing per-object `solid`+`setsize` replay is already safe and
> no waitframe is needed. (Cleanest long-term: do both — bake boxes AND keep the shared waitframe.)

### Explicit `setsize` values to hardcode (author_footprint_bbox + swap targets)

| object | `setsize` (mins) (maxs) | source of value |
|---|---|---|
| statweapons/aagun_lowcount | `( -55 -55 0 ) ( 55 55 128 )` | `P_aagun_base.tik` (same real AA gun, trilogy turret box) |
| animate/body_2nd-ranger-engineer2 | `( -16 -16 0 ) ( 16 16 72 )` | tik ships flat 8u box; raise to standing-figure height |
| static/trench_shovel | `( -6 -6 0 ) ( 6 6 66 )` | thin leaning shovel — post-shaped hull (or set `notsolid`) |
| weapons/kar98sniper | `( -6 -22 0 ) ( 6 22 40 )` | leaning rifle — thin oriented hull (or set `notsolid`) |
| **vehicles/opeltruck.tik** (swap) | `( -160 -56 0 ) ( 160 56 60 )` | native tik `setsize` (torso-high truck box) |
| **vehicles/opeltruckgreen_canopy.tik** (swap) | `( -160 -56 0 ) ( 160 56 60 )` | native tik `setsize` |

Note: the truck boxes are ~60u (torso) tall by design — good for cover; players may clip the cab
roof above 60u. Raise the max-Z if roof-blocking is wanted, but the trilogy itself keeps them low.

---

## 4. MODEL-VARIANT SWAPS (from → to) with evidence

**Swap 1 — Opel truck (static → vehicle).**
`models/static/vehicle_opeltruck.tik` → `models/vehicles/opeltruck.tik`
- *Why our variant fails:* loads `opelstatic.skd`, **no `setsize` in the tik** → skeleton-only AABB → race/partial.
- *Why the target is genuinely solid:* trilogy classname `vehicle_german_opeltruck` uses
  `vehicles/opeltruck.tik` and it ships `setsize "-160 -56 0" "160 56 60"`. This exact entity is placed
  on **m1l2a itself (×2)**, plus m1l2b, m1l3a, m1l3b (×3), m1l3c — i.e. the shipping map we are dressing
  already relies on this model as a solid truck.

**Swap 2 — Opel truck green canopy (animate → vehicle).**
`models/animate/vehicle_german_opeltruckgreen_canopy.tik` → `models/vehicles/opeltruckgreen_canopy.tik`
- *Why our variant fails:* the `animate/` variant ships a **shrunken** box `setsize "-50 -40 0" "50 40 60"`
  (100×80u) — smaller than the visual truck → you walk through the front/rear overhang (classic "partial").
- *Why the target is genuinely solid:* trilogy classname `vehicle_german_opeltruckgreen_canopy` uses
  `vehicles/opeltruckgreen_canopy.tik`, which ships the full `setsize "-160 -56 0" "160 56 60"` (320×112u).
  Placed on e1l1, e1l3 (×4), e2l3, m4l2, t3l1.

**Catalog-wide follow-up (same class of bug, not in m1l1/m1l2a but present in `buildmode_catalog.scr`):**
The catalog ships the **entire `models/static/vehicle_*` decorative family (26 entries)** — all load
static `.skb`/`.skd` meshes with **no tik `setsize`** (spot-checked: vehicle_mercedes→mercedes.skb,
vehicle_sdkfz→sdkfz.skb, vehicle_shermantank→shermantank.skb, vehicle_european_car_tan→car.skb,
vehicle_jeep→jeep.skd — none carry a box). Any of these placed `solid` will race/partial exactly like
the opeltruck. Where a real `vehicles/<x>.tik` sibling with a `setsize` exists (it does for
mercedes, sdkfz, opeltruck[green][_canopy][gray], european_car, bmwbike, etc.), prefer it for
solid placements — or apply the Phase-A/B/C framedefer capture uniformly so even the boxless decor
variants get a valid hull. (`vehicles/opeltruck_nonvehicle.tik` is NOT a good target — it also lacks
a `setsize`.)

**aagun note (author, not swap):** `statweapons/aagun_lowcount.tik` has no box; rather than swap to
the visually-different `P_aagun_base.tik` (turret base only), **keep the model and author** its box
`(-55 -55 0)(55 55 128)` — that is the proven trilogy AA-gun collision hull from `P_aagun_base.tik`.
