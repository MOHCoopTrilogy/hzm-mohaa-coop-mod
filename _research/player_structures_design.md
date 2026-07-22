# Player-Built Custom Structures — Design + Implementation Plan

**Date:** 2026-07-21 · **Status:** **WIRED LIVE** (user approved all §8 defaults; §7 diffs applied to buildmode.scr / bunker.scr / cfg pair same day, adapted to bunker v2 — see §7 preamble). Awaiting build.ps1 + in-game test (§9).
**Goal:** let the builder compose their OWN multi-piece structures from the cat-33 box primitives, save them as named templates, and re-place them anywhere — extending (not replacing) the existing buildmode.scr → bunker.scr → cat-41 architecture.

**Deliverables in this pass**
- `coop_mod/blueprint.scr` — NEW, fully written, depth-scan clean (depthscan2.py: real_depth=0, all labels at 0), pure ASCII, no `(-` patterns. Nothing threads into it yet, so it is inert even if packed.
- This doc — the wiring diffs for `buildmode.scr` / `bunker.scr` / `buildmode.cfg` (small, listed verbatim in §7; NOT applied — the operator applies after review since the user is play-testing live).
- One found bug in today's `bunker.scr` (§6) with a 4-line fix.

---

## 0) Architecture summary

```
buildmode.scr  (ghost / control bus / capture)          [3 small diff blocks]
   |                     |
   | snap per-frame      | place/undo hooks
   v                     v
blueprint.scr  (NEW - all logic lives here)
   - SNAP:      bp_snapPos / bp_snapYaw / bp_gridB / bp_round
   - CAPTURE:   bp_record / bp_mark / bp_save  -> coop_mod/save/bp_<name>.dat
   - PLAYBACK:  bp_place (generalizes bunker.scr grid playback to offset lists)
   - REGISTRY:  bs_register / bs_remove / bs_removeAimed  (structures as UNITS)
   - CATALOG:   bp_catalogRefresh (runtime-appends "bp:<name>" to cat 41)
   |
bunker.scr  (unchanged builders + 1 register line each + solidify scale fix)
```

Everything is script-only. No engine change is needed anywhere in this design.

**Priority order (user acceptance bar = "I can build my own structures"):**
1. **Blueprint capture + playback** (§2) — the centerpiece; ships value on its own even with snap off.
2. Snap/grid (§1) — makes the captures worth keeping.
3. Registry/unit-undo (§4), dynamic catalog (§3), budget gates (§5) — supporting.

---

## 0.5) How the game itself builds structures (and which precedent this design copies)

Four mechanisms exist in the engine/retail data; only one is available at runtime:

| # | Mechanism | How it works | Usable live? |
|---|---|---|---|
| 1 | **Baked brush buildings** | Radiant-compiled worldspawn brushes + inline `"*N"` submodels in the BSP | No — no runtime brush/CSG creation exists (buildmode_geometry_research.md, definitive) |
| 2 | **`func_crate`** (CrateObject, crateobject.cpp) | `SOLID_BSP` + inline `"*N"` brush model, `MOVETYPE_PUSH` — retail's "placed solid box" | No — depends on map-compiled brushes; `*N` indices are meaningless outside their own BSP |
| 3 | **`addon_*` / TIK-self-describing prefabs** (SH/BT) | Unknown classnames fall back to the model TIK's server init block — `g_spawn.cpp:242` reads the TIK's `classname` + `setsize` commands to pick the class AND collision. Retail's data-driven way to "place" a complex prefab as ONE entity | Yes, but wrong shape: one mesh + one setsize box per entity; a *template-as-TIK* would need authoring a mesh outside the game per template — not player-buildable live. Its lesson (collision = explicit setsize boxes, never scaled by `scale`) is already absorbed as the bug-829 recipe |
| 4 | **Composed script_model structures** (our bunker.scr) | Self-measured cube, block-grid math, batched spawn, solidify with true bounds × scale | **Yes — the only live path.** This design generalizes exactly this machinery |

So the blueprint system is deliberately "mechanism 4, generalized": bunker.scr's hardcoded `(fx, ry, row)` grid arrays become arbitrary `(tik, fx, ry, dz, ryaw, pitch, scale, solid)` lists loaded from a file the builder recorded in-game. The spawn/solidify/batching recipes are copied verbatim, per the fix methodology (find the working recipe, copy it exactly).

---

## 1) SNAP / GRID MODE

**What snaps:** ghost X/Y to the measured block grid, yaw to 45° steps. Z stays trace-driven by default (the aim trace already lands the ghost exactly on top of a placed box, which is what makes stacking flush); opt-in Z snapping to half-grid steps via `coop_build_snapz 1`.

**Grid size** = measured box edge (bunker.scr::measure reference-cube recipe, cached once per map in `level.coop_bp_baseEdge`) × the **current build scale** — so two scale-2.0 concrete blocks land flush edge-to-edge, and dropping to scale 1.0 gives a half-grid for detail pieces. Manual override: `coop_build_gridsize <units>` (0/unset = auto). First snap of a map costs one `waitframe` (the measure cube); after that it's cached.

**Where it hooks (2 spots in buildmode.scr):**
1. `coop_build_ghostFollow` — after the dist push/pull, **before** the zofs add: `if snap → local.hitpos = waitthread blueprint.scr::bp_snapPos local.hitpos`. Because `coop_build_place` consumes `level.coop_build_lastpos` written by ghostFollow, snapping the ghost snaps the placement for free — no second hook needed.
2. `coop_build_doCmd` — `yawplus`/`yawminus` step 45 instead of 15 while snap is on; toggling snap ON re-rounds the current yaw immediately (`bp_snapYaw`).

**Rounding without `%`:** morfuscript has no modulo. `bp_round` divides, `int()`-truncates (toward zero), and corrects with ±0.5 threshold tests — symmetric for negative coordinates (the common case: map coords are negative half the time).

**Control bus:** one new action `snap`, bound to the SEMICOLON key (the only *named* punctuation key — `bind SEMICOLON "set coop_build_cmd snap"`; cerebrum 07-08: printable chars self-bind, but `;` is a command separator inside cfg lines so the name is required). No existing bind moves. The toggle is also reachable with no bind at all: `set coop_build_cmd snap` in the console.

**Cvars:** `coop_build_snapz` (0/1, default off), `coop_build_gridsize` (0 = auto). Snap state itself is session state (`level.coop_build_snap`), reset per map like the rest of the build state.

**HUD:** append ` snap <0/1>` to the existing slot-57 readout line (diff in §7).

---

## 2) BLUEPRINT CAPTURE (named templates)

### Workflow (builder's view)
```
;                                  <- snap on (recommended while building)
' (apostrophe)                     <- bpmark: "start recording here"
...place boxes/props normally...
set coop_build_bpname mybase       <- console (~), names need typing anyway
set coop_build_cmd bpsave          <- saves "mybase", instantly appears in STRUCTURES
```
Then cycle to cat STRUCTURES → `bp:mybase` → aim → KP_ENTER places the whole thing at the ghost, rotated to the current build yaw. KP_DEL (undo) removes it as a unit.

### Data captured
`buildmode.scr` today only keeps the paste-text `dumpline[n]` and the entity — not structured data. The place diff adds one `bp_record` call per placement storing tik/pos/yaw/pitch/scale/solid/kind in `level.coop_bp_*[n]` arrays (kind = `model` / `actor` / `struct`). `bpsave` walks marker+1..count and templates **kind=="model" pieces only** (v1; actors and nested structures are an open decision, §8). Undo calls `bp_unrecord` so removed pieces never enter a template.

### Template format — `coop_mod/save/bp_<name>.dat`
One ASCII line, two-level separators (`,` field / `|` record — neither occurs in tik paths or numbers), parsed with the **proven challenges.scr char-walk recipe** (`chal_deserialize`), which survives every morfuscript string limit because it never needs regex/split of mixed types:

```
bpv1,<name>,<count>|<tik>,<fx>,<ry>,<dz>,<ryaw>,<pitch>,<scale>,<solid>|...
```

- **Anchor-relative:** the FIRST captured piece is the anchor. `fx`/`ry` = units along the anchor's facing/right axes (dot products against `angles_toforward` of anchor yaw), `dz` = height above anchor origin, `ryaw` = piece yaw − anchor yaw wrapped 0..360. Playback at any yaw is then just the bunker.scr basis math (`origin + vector_scale(fwd,fx) + vector_scale(rgt,ry)`).
- Floats round-trip as plain concat-printed strings → `float()` cast on read (the `strings.scr::array_to_float` cast is stock).
- Negative numbers in the **file** are data, not script source — the `(-1)` parse-killer does not apply.
- 128-piece cap at both save and parse.

### Why homepath works here (bug-960 check)
Loose files do NOT override pk3 twins on this engine — but **no pk3 ships anything under `coop_mod/save/`**, so `bp_*.dat`/`bp_index.dat` loose files always load (exactly like the proven `build_<map>.dat` channel; `fs_read_content` → `gi.FS_ReadFile` walks the full search path). For **shipping** curated templates later, put them in the pk3 under a different prefix — `coop_mod/bp/<name>.dat` — and `bp_readfile` already probes `save/bp_` first, then `bp/`. User saves and shipped templates can never shadow each other.

### Playback — `bp_place <origin> <yaw> <name>`
Generalizes bunker.scr's grid playback to arbitrary offset lists, keeping every proven safety recipe:
- parse with frame-yields every 1500 chars (op-budget safe for 8KB files),
- spawn batched **8/frame** (bunker.scr batching),
- solidify with the **coop_placements.scr recipe**: shared `waitframe` → `getmins`/`getmaxs` **property syntax** (bug-910) → multiply by piece scale (bug-829: engine `setScale` never touches `r.mins/r.maxs`, the getter returns BASE bounds) → `setsize`, batched 8/frame,
- registers all pieces as ONE structure (§4),
- entity-budget gate before spawning anything (§5).

The `.dat` capture line for a placed template (goes into `build_<map>.dat` like today's structures):
```
thread coop_mod/blueprint.scr::bp_place ( <x> <y> <z> ) <yaw> "<name>"
```
Baking that into a map script requires the template file to be present — ship it as `coop_mod/bp/<name>.dat` in the pk3 (see above), or paste the per-piece blocks as before.

---

## 3) DYNAMIC CATALOG

**Recommendation: runtime append — no generated include file, no fixed slot pool.** The catalog *file* is static script, but the catalog *data* is plain `level.coop_build_item[c][i]` arrays. `bp_catalogRefresh` reads `coop_mod/save/bp_index.dat` (a `|`-separated name list maintained by `bp_save` with exact-name dedup) and rewrites the tail of cat `level.coop_build_structCat`: items 1–4 stay the builtin bunker labels, templates append as `"bp:<name>"` (cap 16 so KP4/KP6 cycling stays sane). Called once from the monitor after `catalog_init` (templates from previous sessions/maps appear every map) and again after every `bp_save` (same-session availability, zero restarts).

Why not the alternatives:
- *Fixed `custom_1..custom_8` slots*: pure downside — empty slots clutter the list, name collisions, still needs the index file.
- *Regenerating a catalog include that gets packed*: needs a build.ps1 run per save, and a generated .scr is a parse-kill risk surface. Rejected.

Ghost preview for `bp:` items reuses the existing structures behavior (anchor cube at the aim point) — zero changes needed; the item string just isn't a tik path, same as the bunker labels.

---

## 4) EDITING — structures as UNITS (registry)

`level.coop_bs_*` registry in blueprint.scr:

| var | meaning |
|---|---|
| `coop_bs_count` | structures ever registered this map (sid allocator) |
| `coop_bs_ent[sid][1..n]` | piece entities |
| `coop_bs_n[sid]`, `coop_bs_name[sid]`, `coop_bs_alive[sid]` | bookkeeping |
| `coop_bs_pieces` | live piece total (budget gate, §5) |

- `bs_register bm bn base label` — one call registers a whole piece array; `base` handles bunker's 0-indexed vs bp_place's 1-indexed arrays. Each bunker builder gets **one added line** after its `solidify` call (§7). Because registration must complete before the sid is read, the structures branch in `coop_build_place` switches the four bunker calls from `thread` to `waitthread` — the ghost freezes ~8–15 frames during a build, acceptable for a dev tool (open decision §8 if not).
- **Undo as a unit:** the place diff records structure placements as kind `"struct"` with `level.coop_bp_sid[n] = level.coop_bs_count`; the undo diff routes kind-struct entries to `bs_remove sid` (batched delete, 8/frame) instead of the single-entity delete. Capture-file line removal already works (dumpline mechanism untouched).
- **Remove by aiming:** `bs_removeAimed` — view trace (the engine `traced` result carries an `"entity"` key, scriptthread.cpp:7297), linear registry scan for the hit entity, `bs_remove` the owner. Bus action `bpremove` (console or optional bind).
- **Move as a unit** = remove + re-place (the template is already in the catalog). True drag-moving 50 live entities is not worth the complexity for a dev tool.

Note: registry entries are per-map level vars (clear on map change) — correct, since the entities die with the map. Persistence is the capture file, as today.

---

## 5) LIMITS — entity + op budget math

**Entity pool (post entity-pool-2048 saga):** true `MAX_GENTITIES` 2048; slots 2046/2047 reserved (WORLD/NONE), low slots reserved for clients → ~2040 usable. AllocEdict now hard-clamps (clean ERR_DROP on true exhaustion, no more world-stomp).

**Baseline occupancy:** BSP dumps run 393–4519 raw entity blocks (e3l4 4519, m3l3 3570, e1l1 3053), but many never stay resident (pathnodes aren't edicts, func_group folds, temps free). Ground truth from the crash saga: the heaviest coop maps were brushing the OLD ~1022 ceiling under full pressure (80 scaled AI + weapons-on-back drops + fx) — call peak baseline **~1000–1100**. Headroom on the worst maps ≈ **900 slots**; typical maps far more.

**Budget policy (implemented in bp_place / bs_register):**
- `coop_build_maxpieces` cvar, default **400** — total live composed-structure pieces per map; `bp_place` refuses (console + `^~^~^ BUILD_BP_BUDGET` line) rather than partially spawning. 400 leaves ~500 slots of margin on the worst map even at full AI pressure.
- Template size cap **128** pieces (save + parse). Builtin costs for scale: pillbox 57, tower 49, nest 12, wall 12 — so 400 ≈ 7 pillboxes or 33 wall segments.
- `coop_bs_pieces` decrements on removal, so build/remove cycling doesn't leak budget.

**Op budget:** spawn 8/frame and solidify 8/frame (proven bunker batching); parser yields every 1500 chars (a max 128-piece file is ~9KB → ~6 frames); removal batched 8/frame. Nothing here runs in or before `main.scr::main`, so the no-wait init rule is untouched.

**Net/vis caveat (not enforced):** every piece is a networked entity when in PVS. One 57-piece pillbox in view is nothing; several hundred pieces in a single sightline starts to matter for snapshot size. If mega-bases become a thing, revisit with a per-area guidance note rather than more caps.

---

## 6) FOUND BUG — bunker.scr solidify ships half-size hulls

`bunker.scr::solidify` does `local.emn = local.e.getmins` → `setsize` **without multiplying by scale**, but every wall block is placed at scale `local.bs = 2.0`. The engine getter returns the entity's BASE `mins/maxs` (`Entity::GetMins`, entity.cpp:3496 — `setScale` never touches `r.mins/r.maxs`; this is exactly bug-829, and coop_placements.scr + buildmode.scr both already multiply). Result: all four bunker variants render 2× but **clip at 1×** — players/AI/bullets pass through the outer half of every block, and the cover system's traces miss.

**Fix (4 lines in `solidify`, uses the proven `scale` property getter):**
```
			local.emn = local.e.getmins
			local.emx = local.e.getmaxs
			local.es = local.e.scale
			if( local.es == NIL || local.es <= 0 ){ local.es = 1.0 }
			local.emn = local.emn * local.es
			local.emx = local.emx * local.es
			local.e solid
			if( local.emx[2] - local.emn[2] > 0 ){ local.e setsize local.emn local.emx }
```
Using the per-entity scale (not a passed array) also fixes the mixed-scale pieces (scale-1.0 sandbags/crates and the tower's half-blocks at `local.hb = 1.0`) in one shot. blueprint.scr's own solidify already does this via its `bscl[]` array.

---

## 7) WIRING DIFFS — **APPLIED 2026-07-21** (kept for reference)

Applied against **bunker.scr v2** (base block bs = 4.0 × mult, per-variant material tiks, builders take a third `mult` arg = the current build scale, solidify scale fix already in). Deltas from the diffs as originally written below:
- `bp_place` gained a matching 4th arg `mult` (default 1.0): scales offsets AND piece scales, so KP+/- sizes whole templates exactly like the bunker builders; the structure dispatch passes `level.coop_build_scale`, and both capture-line variants include it.
- Added a **success flag** (`level.coop_bp_lastPlaceOk`): a refused `bp_place` (missing file / bad header / budget) aborts the branch before `bp_record`/capture — otherwise the recorded sid would point at an OLDER structure and undo would delete the wrong one.
- Struct `bp_record` records `level.coop_build_scale` (the mult) instead of the placeholder 1.0.
- Help surfaces updated: BUILD_HELP println + HUD slot-59 line mention `;` snap and `'` bpmark; buildmode.cfg header documents the blueprint workflow; buildmode_stop.cfg unbinds SEMICOLON and `'`.

Original diffs (pre-v2 signatures) follow:

### 7.1 `coop_mod/buildmode.scr`

**(a) monitor — after the `buildmode_sounds.scr::sound_catalog_init` line:**
```
	waitthread coop_mod/blueprint.scr::bp_catalogRefresh		//HZM coop BLUEPRINT: append saved templates to STRUCTURES
```

**(b) session state defaults — after the `level.coop_build_animIdx` line:**
```
	if( level.coop_build_snap == NIL ){ level.coop_build_snap = 0 }		//HZM coop BLUEPRINT: grid snap (x/y block grid + 45 deg yaw)
```

**(c) doCmd — replace the two yaw branches (45° steps while snapped):**
```
	else if( local.cmd == "yawplus" ){
		local.step = 15
		if( level.coop_build_snap == 1 ){ local.step = 45 }
		level.coop_build_yaw = level.coop_build_yaw + local.step
		if( level.coop_build_yaw >= 360 ){ level.coop_build_yaw = level.coop_build_yaw - 360 }
	}
	else if( local.cmd == "yawminus" ){
		local.step = 15
		if( level.coop_build_snap == 1 ){ local.step = 45 }
		level.coop_build_yaw = level.coop_build_yaw - local.step
		if( level.coop_build_yaw < 0 ){ level.coop_build_yaw = level.coop_build_yaw + 360 }
	}
```

**(d) doCmd — new branches (insert before the `place` branch):**
```
	else if( local.cmd == "snap" ){
		if( level.coop_build_snap == 1 ){ level.coop_build_snap = 0 }
		else{
			level.coop_build_snap = 1
			level.coop_build_yaw = waitthread coop_mod/blueprint.scr::bp_snapYaw level.coop_build_yaw
		}
		local.player iprint ( "SNAP: " + level.coop_build_snap ) 1
	}
	else if( local.cmd == "bpmark" ){
		waitthread coop_mod/blueprint.scr::bp_mark local.player
	}
	else if( local.cmd == "bpsave" ){
		waitthread coop_mod/blueprint.scr::bp_save local.player
	}
	else if( local.cmd == "bpremove" ){
		waitthread coop_mod/blueprint.scr::bs_removeAimed local.player
	}
```

**(e) ghostFollow — after the dist push/pull block, BEFORE the zofs line:**
```
	//HZM coop BLUEPRINT: optional grid snap (x/y to the block grid; z opt-in via coop_build_snapz)
	if( level.coop_build_snap == 1 ){
		local.hitpos = waitthread coop_mod/blueprint.scr::bp_snapPos local.hitpos
	}
```

**(f) place — STRUCTURES branch: `bp:` dispatch + registry + unit-undo record.** Replace the four `thread coop_mod/bunker.scr::...` lines and the `local.block` build with:
```
		local.pfx = waitthread coop_mod/strings.scr::left 3 level.coop_build_tik
		if( local.pfx == "bp:" ){
			local.bpname = waitthread coop_mod/strings.scr::remove level.coop_build_tik "bp:"
			waitthread coop_mod/blueprint.scr::bp_place level.coop_build_lastpos level.coop_build_yaw local.bpname
		}
		else if( level.coop_build_tik == "bunker_pillbox" ){ waitthread coop_mod/bunker.scr::bunker_pillbox level.coop_build_lastpos level.coop_build_yaw }
		else if( level.coop_build_tik == "bunker_nest" ){ waitthread coop_mod/bunker.scr::bunker_nest level.coop_build_lastpos level.coop_build_yaw }
		else if( level.coop_build_tik == "bunker_wall" ){ waitthread coop_mod/bunker.scr::bunker_wall level.coop_build_lastpos level.coop_build_yaw }
		else if( level.coop_build_tik == "bunker_tower" ){ waitthread coop_mod/bunker.scr::bunker_tower level.coop_build_lastpos level.coop_build_yaw }
		else{ local.player iprint "unknown structure" 1 ; end }
		//HZM coop BLUEPRINT: record as a unit (builder just registered -> sid = coop_bs_count)
		waitthread coop_mod/blueprint.scr::bp_record local.n level.coop_build_tik level.coop_build_lastpos level.coop_build_yaw 0 1.0 1 "struct"
		level.coop_bp_sid[local.n] = level.coop_bs_count
		local.block = "// coop_build STRUCTURE #" + local.n + " " + level.coop_build_tik + "\n"
		if( local.pfx == "bp:" ){
			local.block = local.block + "thread coop_mod/blueprint.scr::bp_place ( " + local.sx + " " + local.sy + " " + local.sz + " ) " + level.coop_build_yaw + " \"" + local.bpname + "\"\n\n"
		}else{
			local.block = local.block + "thread coop_mod/bunker.scr::" + level.coop_build_tik + " ( " + local.sx + " " + local.sy + " " + local.sz + " ) " + level.coop_build_yaw + "\n\n"
		}
```
(`thread` → `waitthread` is deliberate: the sid must exist when `bp_record` runs. Ghost freezes ~8–15 frames per structure build.)

**(g) place — single-model branch, right after `level.coop_build_count = local.n`:**
```
	//HZM coop BLUEPRINT: structured record (template capture + unit undo)
	local.kind = "model"
	if( local.isActor == 1 ){ local.kind = "actor" }
	waitthread coop_mod/blueprint.scr::bp_record local.n level.coop_build_tik level.coop_build_lastpos level.coop_build_yaw level.coop_build_pitch level.coop_build_scale level.coop_build_solid local.kind
```

**(h) undo — replace the entity-delete block at the top of `coop_build_undo` body (after the count check):**
```
	local.n = level.coop_build_count
	//HZM coop BLUEPRINT: structure placements undo as a UNIT
	if( level.coop_bp_kind[local.n] == "struct" ){
		waitthread coop_mod/blueprint.scr::bs_remove level.coop_bp_sid[local.n] local.player
	}else{
		local.m = level.coop_build_ent[local.n]
		if( local.m != NIL && local.m != NULL ){
			if( local.m.coop_buildPropTag != NIL && local.m.coop_buildPropTag != "" ){
				local.m removeattachedmodel local.m.coop_buildPropTag
			}
			local.m delete
		}
	}
	waitthread coop_mod/blueprint.scr::bp_unrecord local.n
```
(rest of undo — dumpline NIL, count−1, save — unchanged.)

**(i) HUD — slot-57 readout line, append snap state:**
```
				ihuddraw_string local.player 57 ( "yaw " + level.coop_build_yaw + " pitch " + level.coop_build_pitch + " zofs " + level.coop_build_zofs + " dist " + level.coop_build_dist + " scale " + level.coop_build_scale + " solid " + level.coop_build_solid + " snap " + level.coop_build_snap )
```

### 7.2 `coop_mod/bunker.scr`

**(a) solidify scale fix — §6 above (replace the getmins/getmaxs/solid/setsize body).**

**(b) one register line at the END of each builder, after its `waitthread solidify` line:**
```
	waitthread coop_mod/blueprint.scr::bs_register local.bm local.bn 0 "bunker_pillbox"
```
(label string matches each builder: `bunker_nest` / `bunker_wall` / `bunker_tower`.)

### 7.3 `coop_mod/cfg/buildmode.cfg`

```
bind SEMICOLON "set coop_build_cmd snap"
bind ' "set coop_build_cmd bpmark"
```
Console-only (names need typing anyway): `set coop_build_bpname <name>` + `set coop_build_cmd bpsave`; `set coop_build_cmd bpremove` (or bind a spare key, e.g. `bind - "set coop_build_cmd bpremove"`). Add the two lines to the header comment and mirror the unbinds in `buildmode_stop.cfg` (`unbind SEMICOLON`, `unbind '`).

---

## 8) OPEN DECISIONS (user)

1. **Actors/structures inside templates?** v1 templates capture kind `model` only (boxes + props). Including placed actors (anim + prop fields → 3 more record fields) or nesting structures is straightforward format-wise — worth it, or keep templates geometry-only?
2. **Z-snap default:** off (trace-stacking already lands flush). Turn `coop_build_snapz` on by default instead?
3. **Grid source:** auto = block edge × current scale. Prefer a fixed grid (e.g. always 32u) as the default?
4. **Caps:** 400 total pieces / 128 per template / 16 catalog templates — adjust?
5. **Ghost freeze during structure builds** (~8–15 frames from `waitthread`): acceptable, or should registration move to a builder-side callback so `thread` stays?
6. **Shipping templates:** confirm `coop_mod/bp/` as the pk3 prefix for curated templates so baked `bp_place` lines work for all players.
7. **Auto-snap for STRUCTURES category:** should selecting cat 41 force snap ON (like cover cats force SOLID)?

## 8.5) PARSE-SAFETY VALIDATION PROTOCOL (mandatory before any deploy)

Today's incident: a REAL newline inside a string literal parse-killed buildmode.scr entirely (whole file compiled to nothing, build mode dead). The on-disk file is fixed (`"\n"` escapes); the §7.1(f) diff is written against the fixed version and keeps every `\n` as a two-character escape **inside** the quotes. Rules for all three touched files:

1. String literals stay on ONE physical line; newlines only ever as the `\n` escape (parser TextEscapeValue supports `\n \t \"`).
2. `depthscan2.py <file>` → `real_depth=0`, `first_negative=None`, all labels at depth 0.
3. Odd-quote-count line scan (comment-aware) → zero odd lines. One-liner used this pass:
   walk each line, skip from an unquoted `//`, count `"` — any line with an odd count is a breakage candidate.
4. Pure-ASCII + no-BOM + no `(-` byte-scan.

`blueprint.scr` as committed passes all four (verified this pass). Note its template FILE format needs no `\n` at all — one single line, `,`/`|` separators — precisely to keep the writer/parser out of escape territory.

## 9) TEST PLAN (rcon + qconsole.log; `developer 1` for script prints)

1. Wire diffs → run the §8.5 protocol on buildmode.scr, bunker.scr, blueprint.scr → build/deploy when the user is ready (NOT now).
2. Smoke: build mode on → `;` toggles SNAP on HUD; place two scale-2 concrete boxes side by side → edges flush; yaw steps 45.
3. Bunker hull fix: place a wall, shoot/walk the outer half of an end block → now blocked (`BUILD_STRUCT_REG` line shows registration).
4. Blueprint: `'` mark → 4-6 boxes → `set coop_build_bpname test1` → bpsave → `BUILD_BPSAVE test1 pieces N`; STRUCTURES now shows `bp:test1`; place it twice at different yaws → geometry matches original relative layout; KP_DEL removes the whole second copy (`BUILD_STRUCT_REMOVE`).
5. Persistence: map restart → `bp:test1` still listed (index file read; `BUILD_BPCAT 1 templates`).
6. Budget: set `coop_build_maxpieces 20`, place a pillbox → refused with `BUILD_BP_BUDGET` (template path) / verify bunker path budget behavior (registers over budget — acceptable? builders don't pre-gate in v1).
7. Bad-file: hand-corrupt `bp_test1.dat` header → `BUILD_BP_BADFILE`, no spawns.
