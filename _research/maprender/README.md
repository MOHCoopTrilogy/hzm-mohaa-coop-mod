# Map renderers

Offline tools. They **read** the BSP and pk3s and write a PNG next to themselves; they never
write to game data, so nothing here can affect the mod or the map.

    python maprender_modern.py <map> [width] [height] [fit]

`fit` is `map` (default, whole level in frame - required so every holdout stays markable) or
`auto` (frame tight on the authored holdouts). Emits `<map>_modern.png` and `<map>_recon.png`.

| file | output |
|---|---|
| `maprender_modern.py` | procedural materials, stamped flora, sun/sky rig, 1940s recon treatment |
| `maprender_textured.py` | faithful render using the map's own textures |
| `maprender_tactical.py` | parchment overlay map with authored arena data |

## BSP facts these encode (each cost a debugging round)

- `cTerraPatch_t` stride is **388**, not 385 - float `texCoord` members force 4-byte alignment.
- Terrain `iShader` is at offset **40**; 42 is `iLightMap`. Reading 42 paints whole rows of
  patches with one wrong texture (horizontal colour banding).
- `texCoord[i][j]` is the patch's **four corners**, not two opposite ones. `s` varies with `i`,
  `t` with `j`. Reading it as two corners makes `s` constant and smears the ground texture.
- Surface record: `shaderNum@0 fogNum@4 surfaceType@8 firstVert@12 numVerts@16 lightmapNum@28`.
- `TAnatural/nosprite*` and `common/tallen*` are **tree-impostor occluders** floating ~1300 units
  above the terrain. From directly overhead they win the z-buffer as flat plates and throw hard
  rectangular shadows - they must be skipped like nodraw.
- Lightmaps are usable only when well exposed. e3l4 is a night map (mean lit value 0.0756, ~19
  levels at 8 bits); normalising that amplifies quantisation noise into vertical streaks. The
  renderer measures exposure and skips them below `LM_MIN_MEAN`.

## BSP idents (2026-08-06)
Allied Assault maps use ident `2015`; **Spearhead and Breakthrough use `EALA`** (version 21). The
lump layout is the same for entity/model purposes (header base 12, lump 13 = models @40 bytes,
lump 14 = entities), so any tool that reads AA BSPs works on SH/BT once it stops rejecting the
ident. A `!= "2015"` check silently skips 20 of the trilogy's 54 maps (bug-1468).
