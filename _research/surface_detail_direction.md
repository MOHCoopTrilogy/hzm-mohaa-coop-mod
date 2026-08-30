# Surface detail direction — what MOHAA does, and what we should do

Design-lead call, 2026-08-27. Question: *"based on research of how this game handles this kind of thing, what should we be doing with
this?"*

**Short answer: fix the lighting first, and shrink the generated-normals trial instead of growing it.** MOHAA has no relief mechanism to
copy — the standing "find how the devs did it" rule returns *they didn't*. What carried the look was lighting plus hand-painted shading.
Relief is the wrong lever to pull hardest on, and two lighting defects sit unfixed in front of it.

---

## 1. WHAT MOHAA ACTUALLY DOES

Corpus: 445 retail `.shader` files from 17 pk3s → **7,041 effective** defs after pk3 override, **3,319 of them world** (`textures/…`);
35,681 pak entries; 160 shipped BSPs.

**There is no runtime surface-relief mechanism in this game, at all.**

| looked for | retail ships |
|---|---|
| normal / bump maps | **1 line, commented out** — `scripts/interior.shader:11`, `//map $bumpmap …townhallbmp.tga`. `textures/bumpmaps/` = 0 entries. Across 35,681 pak entries: `_n.` 0, `_bump.` 0, `_nrm.` 0, `_local.` 0 |
| `detail` keyword | **3 stages**, all in `textures/mohtest/brick.shader` — a test file. Zero production use |
| `tcMod macro` (MOHAA's *own* world-space detail projection, implemented in gl1 `tr_shade_calc.c:1535`) | **0 uses in 7,041 shaders.** They built the tool and never touched it |
| second diffuse layer | 170/3319 world shaders (5.1%) sample ≥2 textures — all env-map, water, snow sparkle, pulsing lights. **Not one is a relief overlay**. `nextbundle` (1,797 uses) is 97% diffuse × `$lightmap` folded into one pass: fillrate, not layering |

**85.3% of world shaders (2,832/3,319) are one canonical form: one diffuse + one `$lightmap`.** That is the entire world-surface vocabulary.

**The mechanism they used was painting the light in, and shipping variants** — proven, not inferred. `church_interior_wall1` → `…drk` is the
same texture × 0.772, high-pass residual correlation **+0.997**; `brick1trim` → `…shadowed` is the same brick with a ramp painted across it
(+0.951), `…wht` (+0.974). Naming taxonomy over 3,109 world stems: `lt/lite/light` 31, `dk/dark` 17, `shadow/shdw` 8, `top/bot` 43, plus
`flt` = *flat*. **46.3% of sampled world textures have macro shading std > 15; 30.4% have a >10-level half-to-half luminance ramp.**
`church_pillar_top.jpg` is a carved stone cornice — acanthus, egg-and-dart, deep undercuts — entirely photographed highlight and shadow, at
**128×128**. The other half was the lightmap, and it is coarse: `LIGHTMAP_WIDTH/HEIGHT 128`, with **m1l1 at 6 pages for a whole level**
(98,304 luxels) — room-scale light and big cast shadows, nothing finer. Models got shape from a third thing again: `rgbGen
lightingSpherical`, **2,026 shaders** (vs 1 world shader), backed by `LUMP_SPHERELIGHTS`. **Models get form from lighting; world surfaces
get it from painting.** Neither is a normal map.

---

## 2. THE CRUX — is there a light direction to shade a normal against?

**Yes — two of them, so this is not moot. But both are thin, and that caps the payoff.**

Verified in source:

1. **Per-vertex, baked at load.** `R_CalcVertexLightDirs` (`tr_bsp.c:2904`) → `R_LightDirForPoint` (`tr_light.c:1233`, MOHAA's own — Q3's
   version at `:130` is inside `#if 0`). Sums *visibility-traced* sphere lights plus the sun into `srfVert_t.lightdir` →
   `attr_LightDirection` → `L` in `lightall_vp.glsl:241`. Data is real: **140/160 BSPs have a sun in worldspawn; median 90 sphere lights per
   map.**
2. **Per-pixel sun, already on.** Defaults verified: `r_sunlightMode 1`, `r_sunShadows 1`, `r_normalMapping 1`. Every lit stage gets
   `SHADOWMAP_MODULATE`, where `shadowValue *= clamp(dot(N, var_PrimaryLightDir))` with **N = the perturbed normal**. True per-pixel, never
   falls back.

And ~**98.7% of visible world brush triangles** reach a lit `lightall` permutation that can sample a normal map (134k/175k lightmapped, 16k
vertex-lit; the 21,513-tri "unlit" bucket is `common/*` nodraw). **The collapse path is not the bottleneck.** The four things that cap it:

- **No deluxemaps. On any map. Ever.** `worldDeluxeMapping` needs every surface's `lightmapNum` even; **142/160 BSPs have at least one odd,
  the other 18 have ≤1 page.** Zero false positives. No per-texel light direction exists anywhere in this game.
- **The per-vertex fallback is the fooling-ourselves case.** `R_LightDirForPoint` ends `if (DotProduct(summedDir, normal) > 0.2f) lightDir =
  summedDir; else lightDir = normal;` — when `L == N` the response is **symmetric**: a bump tilted left and one tilted right darken
  identically. Cos-of-tilt crevice darkening, never a lit side and a shadowed side. And it discards light at grazing angles, exactly where a
  normal map reads best.
- **Per-vertex on a wall brush ≈ one constant direction** — four verts, no shadowing, no spatial variation across a big face.
- **Specular is off.** `r_baseSpecular 0`, `r_specularMapping 0`. Specular is where relief pops; the term exists under `SHADOWMAP_MODULATE`
  but is multiplied by zero.

**Verdict: sunlit exteriors are the one place a normal map genuinely reads. Interiors get crevice darkening only. The ceiling is set by the
lighting data, not by the normal map's quality — which is why a bigger or better normal map does not remove it.**

---

## 3. THE RECOMMENDATION

**Fix the lighting first. Keep generated normals as a narrow, family-scoped trial. Do not build the offline pack yet. Drop detail textures
entirely.**

1. **Two live lighting defects are in front of this, and one ships today.** `RB_DrawTerrainTris` (`tr_surface.c:1352`) writes `tess.normal`
   and `tess.tangent` but **never writes `tess.lightdir`** — the only writes in the file are `:389` and `:1086`, both BSP paths. Terrain
   shaders are ordinary lightmapped `textures/*` shaders, so they *do* get `LIGHTDEF_USE_LIGHTMAP` and *do* demand `ATTR_LIGHTDIRECTION` —
   terrain is uploading a stale direction left by an unrelated brush face (`RB_BeginSurface` doesn't clear it). Live **now, with zero
   generated normals**, because `USE_FAST_LIGHT` is off whenever `r_normalMapping || r_specularMapping`. Terrain is the ground on every
   outdoor map (e1l1 527 patches, t2l1 601). ~6 lines, mirroring the constant-normal pattern at `:1371`. **Do this before anything else.**
2. **AO is what makes flat painted art read as shaped, and it cannot be fooled by paint.** SSAO uses real depth; a Sobel over luminance
   cannot tell a painted shadow from a hole. `r_ppSSAO` is built, gl2-wired, menu-wired in `ui/coop_postfx.urc`, and both failure modes are
   diagnosed and fixed (bug-1178: the *default* was the defect, not the code; bug-1211: generation was nested inside the `r_depthPrepass`
   gate while the composite wasn't, so a NULL-uploaded black texture multiplied over the frame — fixed with `backEndState_t::ssaoValid`).
   Zero assets, zero disk, zero load time.
3. **"Copy the devs" returns a real answer, and it's not a normal map — it's *per-surface, artist-chosen* shading.** Retail ships the
   handle: **2,967/3,319 world shaders (89.4%) carry a material `surfaceparm`** (rock 1250, metal 404, wood 396, dirt 256, snow 144, glass
   80…), plus 8,919 `qer_keyword` tags including **`flat` ×177 — an explicit opt-out from the original artists.** A global relief pass
   contradicts the one convention this game actually has.
4. **The offline pack's ceiling is the same ceiling.** 4,638 world stems at 256px BC5 ≈ 0.38 GB (512px = 1.51 GB) on top of ~8 GB of HD paks
   already in `maintt`. Wrong order of operations — and the option does not expire: the engine consumes such a pack with **zero code
   changes** (`<diffuse>_nh` → `_n` auto-probe at `tr_shader.c:3100-3121`, verified; BC5 DDS loader already in at `tr_image_dds.c:349-424`).
   **Detail textures: drop outright** — 3 stages in the whole game, all in a test file; thousands of shader edits for a flatter result,
   against zero precedent.

**Correction to the survey material, because it changes what to watch for.** A 3×3 Sobel is a differentiator, so it *attenuates* low
frequencies: a 56-level ramp across a 512px tile yields ~0.05° of tilt — smooth painted ramps do **not** become giant fake bevels. What *is*
read at full strength is **sharp painted lighting edges**: the bright-top-left/dark-bottom-right edge on every `brick1trim` quoin, the baked
bevel shadows in `frenchdoor_wood1` panels, painted AO seams, stencilled lettering. Those become geometry edges and double-shade. The
upscale hurts by **removing signal**, not by adding fake bevel (`brick1trim` micro-band contrast fell ~17.0 → ~8.8 std while macro, which
Sobel ignores, rose); per bug-1225 DDS diffuses take height from a decoded non-DDS sibling downsampled to 512, often better input than the
live art. **Net: the runtime Sobel is weaker and more inconsistent than feared, not more destructive.**

---

## 4. WHAT TO DO WITH THE TRIAL NOW RUNNING

Keep it, shrink it, treat it as an *instrument* for "do we even want relief on this art?" — not a shipping feature.

**Fix the filter first — there is a real gap.** `R_HZM_PathListMatch` (`tr_image.c:2666`) is a plain `Q_stristr` substring test,
`r_hzmGenNormalInclude` defaults to `"textures/"`, and the builtin deny-list (`tr_image.c:2713-2717`) contains `models/fx/` but **not
`textures/models/`** — where ~3,213 TIKI skin stems live, the largest directory in the game. The comment at `:2723` claims the include list
"is what keeps models/ out". **It does not.** Those can never show relief (no tangent in `RB_SkelMesh`, no light type from
`lightingSpherical`), and the `r_charLighting` net that zeroes `u_NormalScale` never fires because `r_charLighting` defaults 0. Unguarded
*and* ~40% of the VRAM/load budget spent on nothing.

```
r_hzmGenNormalExclude "textures/models/ foliage grass tree bush leaf ivy vine hedge terrain"
r_hzmGenNormalStrength 0.35        // down from 0.6 - the readable band is grain-only
r_hzmGenNormalMaxSize  512         // keep
r_hzmGenNormalBlur     1           // keep
r_hzmGenNormalDebug    1           // read real per-map MB before ANY default change (bug-1178)
```

**Foliage** has no builtin token and we ship `zzzzz_hd_foliage.pk3` (194 MB): a Sobel across an alpha-cut leaf reads the transparent
background as a cliff and bevels every silhouette. **Terrain** stays out until `tess.lightdir` is filled — it has an approximate constant
tangent but a *stale* light direction, so its output is unpredictable rather than merely weak.

**Families in:** rock, stone, concrete, brick, gravel, dirt, road, plaster, wood — relief that is genuine geometry. **Out:** glass, window,
paper, snow (the 18 `tcMod parallax` sparkle shaders), water, anything tagged `qer_keyword flat`. The filter is **path-based today and
cannot express a `surfaceparm` family**, so this is approximated by path; driving the gate off `surfaceparm`/`qer_keyword` is the follow-up
that makes it MOHAA's convention rather than ours.

**One deliberate exception to test:** `r_hzmSpecular 0.12` on a **sunlit exterior only** — `r_baseSpecular` is 0, so the specular tail under
`SHADOWMAP_MODULATE` is currently multiplied out, and that is the single place perturbed normals pop against a real per-pixel sun. Expect
aliasing: we encode BC5 and reconstruct N.z, so **Toksvig is unavailable** (it needs the normal's length, which 2-channel formats discard).

**Four tests, in order, on one sunlit exterior AND one interior** (different lighting paths — they will disagree):

1. **Paint test.** `brick1trimshadowed` vs `brick1trimwht` — same brick, opposite painted key. Relief reads the *same* on both = reading
   grain (good); reads *opposite* = reading the painting (fail).
2. **Parallax test.** Walk past a wall. Real relief changes with view angle, painted relief doesn't. Nothing changes as you move = the
   feature is contributing nothing, quietly.
3. **Double-shade test.** A baked-bevel surface (`frenchdoor_wood1` panels, `brick1trim` quoins): a *second*, offset geometric highlight
   beside the painted one = double-shading.
4. **Shimmer test.** Oblique distant surfaces, moving, `r_hzmSpecular` on. Strobing = the no-Toksvig aliasing; back the specular out.

---

## 5. THE ALTERNATIVE PATH IF THE TRIAL DISAPPOINTS

**Do not escalate to the 4,638-surface pack. Escalate to a hero set** — the 150–400 most-seen wall and floor tiles on the most-played maps,
generated offline (DeepBump CLI, `deepbump256.onnx`, 26.7 MB, DirectML on Windows) bolted onto the existing `docs/tools/upscale_vehicles.py`
structure, which already has the CLI driver, the luma-correlation validator, the black-output guard and the DDS writer. Hand-correct what's
wrong, ship as `_n.dds`. At 256px BC5 that is **~5–30 MB, not 380**, and needs **zero engine changes**: the probe at `tr_shader.c:3100`
finds it, and authored `_n` art is deliberately *not* marked `hzmGenNormal` (`tr_shader.c:3134`), so it keeps `r_baseNormalX/Y` and takes no
`r_hzmSpecular` — the two systems already coexist by design. Prove relief is worth having on 300 surfaces before committing to 4,638. Rules
for that pack, all learned the hard way here:

- **BC5/RGTC only, never DXT1** (DXT1 correlates error across XY and facets smooth curvature), and **OpenGL green-up** — backwards lights
  every surface from the wrong side, easy to miss at low strength.
- **Never emit `_s`** — bug-1155: MOHAA ships 39 ordinary diffuses ending in `_s`, which is why `r_specularMapping` is 0 here. Also confirm
  no retail diffuse is already named `<x>_n`: the suffix guard at `tr_image.c:2751` protects *generation*, not a naming collision in a
  shipped pk3.
- **Emit `_nh` where height is trustworthy** — it flips parallax on for free (`tr_shader.c:3129`, gated by `r_parallaxMapping`, currently
  0). **Bake roughness offline** if specular ever ships.

**If even the hero set disappoints, that is a real answer, not a failure.** It means MOHAA was right — the relief lives in the paint — and
the money goes to lighting: terrain `lightdir`, SSAO, `r_cubeMapping` (currently 0), and an upscale recipe that preserves grain instead of
sharpening the painted macro shapes. Note that RTCW Full 4K Remaster — a WW2 idTech3 shooter, 4K-upscaled, running rend2, our exact
situation — ships **diffuse only, no normal maps**, and its install guide does not turn `r_genNormalMaps` on. Upstream's own cvar help calls
the technique **"naively generate"**; DarkPlaces files it as reproducing Tenebrae, a 2002 look. **Nobody on this engine family ships
synthesised normals by default. Everyone who wanted relief authored a pack — or fixed the lighting.**
