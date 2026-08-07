Verification confirms the two load-bearing contested claims:

- **gl2 `tr_shader.c:1910-1918`** is the stock two-way ioquake3 block â the `if (cntBundle || stage->bundle[0].isLightmap) â CGEN_IDENTITY` leading branch is **absent**. gl1 `tr_shader.c:1751-1761` has the three-way form. The task brief's "already banked, verify present" note is **wrong** â all four investigators who flagged it are correct.
- gl2 `tr_init.c` GetRefAPI has **no** `re.Gore*` / `re.SwipePoint` / weapon assignments (grep returns zero) â confirms the gore trio is left NULL.

Here is the merged plan.

---

# gl2 Re-Port Fix Plan (HZM OpenMOHAA)

## Section 0 â Boot safety: THERE IS NO CRASH / BOOT-BLOCKER

All 7 investigators independently converge: gl2 boots without an interface crash. `GetRefAPI` does `Com_Memset(&re,0,sizeof(re))` (gl2 `tr_init.c:1971`), so every un-assigned export is NULL, not garbage; `cl_cgame.cpp` copies the NULLs through; and every gore call site is NULL-guarded (`cg_parsemsg.cpp:629`, `cg_snapshot.c:121`, `cg_snapshot.c:132`). **No code change is required to make gl2 launch.** The whole plan below is feature/correctness restoration, not crash-fixing.

One latent, non-blocking caveat (NOT a gl2 regression â identical in gl1, so do not "fix" it as part of migration): `re.SwipePoint` is NULL in **both** renderers and its cgame callers `cg_swipe.cpp:221/225` are **unguarded**. The path is evidently never reached in the shipping build. Leave alone unless a swipe/melee-trail weapon is later activated; if so, add `if (cgi.R_SwipePoint)` in cg_swipe.cpp (cheapest) or assign `re.SwipePoint=RE_SwipePoint` in both `tr_init.c` files.

**Verify step 0 (no edit):** launch with `cl_renderer opengl1` â `cl_renderer opengl2`, confirm gl2 reaches the main menu and loads a map without crashing. This is the baseline the loop builds on.

---

## Section 1 â Banked fixes: CONFIRMED PRESENT, do NOT redo

| Banked item | gl2 site | Status |
|---|---|---|
| `r_baseSpecular` default "0" (terrain white-sheen) | `renderergl2/tr_init.c:1421` â `tr_shader.c:3695-3697` â `lightall_fp.glsl:392` | present-ok |
| `r_mergeLightmaps` default "0" (terrain black-streak) | `renderergl2/tr_init.c:1428` | present-ok |
| Per-vertex area-weighted terrain normals in `RB_DrawTerrainTris` | `renderergl2/tr_surface.c:1352-1477` | present-ok, well-formed |

**Also verified already-present (exclude from re-port surface):** RT_SPRITE overhead icons (`renderergl2/tr_main.c:1676`, `tr_surface.c:1181`, `re.AddRefSpriteToScene` at `tr_init.c:2040`); smoke whips (`tr_swipe.cpp`, `re.SwipeBegin/End` at `tr_init.c:2064-2065`); sun-flare / SURF_SKY trace (`tr_sun_flare.cpp:631`); CPU skeletal skinning (`RB_SkelMesh`, `tr_model.cpp:922`); 2D StretchPic color path (`tr_backend.c:896-903`, `VectorScale4 Ã 257`) is byte-order-preserving and equivalent to gl1 â **the HUD "greenâred" is NOT a channel swap**, do not hunt for a byte-swap.

**The 4th "banked" item is a LIE â reclassified as Fix 1 below.** The `cntBundle||isLightmap â CGEN_IDENTITY` rgbGen branch is genuinely absent (I read both files).

**Out of scope for the renderer entirely** (ride normal skeletal/cgame paths gl2 already has): weapons-on-back / holster offset, model-fit / rendermodelfit, blood trails (game.dll-only). Do not touch the renderer for these.

---

## Section 2 â Shared-root-cause map (one fix resolves several symptoms)

- **ROOT A â missing rgbGen default branch** (`gl2 tr_shader.c:1910`): causes **blood-decal-BLACK** + **bullethole-RED** + contributes to HUD miscolor. â **Fix 1** (one branch).
- **ROOT B â gl2 `ComputeShaderColors` omits MOHAA CGEN/AGEN cases** (`gl2 tr_shade.c` rgbGen switch 463-559 / alphaGen 564-605): causes **HUD greenâred** (missing `CGEN_GLOBAL_COLOR`/`AGEN_GLOBAL_ALPHA`, tint dropped to white/opaque) **and** fullbright-white world surfaces (missing `CGEN_LIGHTING_GRID`/`_SPHERICAL`/`MULTIPLY_BY_WAVEFORM`). Same function, same class of omission. â **Fix 2** (+ **Fix 7** for the world-surface cases).
- **ROOT C â gl2 builds no HZM post-FX module**: causes **DBNO/low-health**, **suppression**, **heat-haze**, **rain-on-lens** all missing at once. â **Fix 5/6/8** (one strategy decision).
- **ROOT D â gore module absent**: the NULL `re.Gore*` exports (Section 0), the missing `tr_gore.c`, and the missing engine blood-decal tier are one and the same. â **Fix 4** (one port).

---

## Section 3 â ORDERED FIX SEQUENCE

Each step is independently buildable + has a one-line boot test. Ordered cheap-and-foundational â high-value â big-ports â skippable.

### Fix 1 â Restore rgbGen default branch (ROOT A: blood-black + bullethole-red)
- **Severity:** HIGH Â· **Confidence:** high (I verified the diff)
- **File:** `renderergl2/tr_shader.c:1910-1918`
- **Change:** prepend the leading branch so it matches gl1 `tr_shader.c:1751-1761`:
  ```c
  if ( stage->rgbGen == CGEN_BAD ) {
      if ( cntBundle || stage->bundle[0].isLightmap ) {
          stage->rgbGen = CGEN_IDENTITY;
      } else if ( blendSrcBits == 0 || blendSrcBits == GLS_SRCBLEND_ONE ||
                  blendSrcBits == GLS_SRCBLEND_SRC_ALPHA ) {
          stage->rgbGen = CGEN_IDENTITY_LIGHTING;
      } else {
          stage->rgbGen = CGEN_IDENTITY;
      }
  }
  ```
- **Test:** shoot a wall + kill an enemy under gl2 â bullet holes are neutral/authored color (not red), blood decals visible (not black).

### Fix 2 â Add `CGEN_GLOBAL_COLOR` / `AGEN_GLOBAL_ALPHA` to ComputeShaderColors (ROOT B: HUD greenâred)
- **Severity:** HIGH Â· **Confidence:** high
- **File:** `renderergl2/tr_shade.c` â rgbGen switch (~463-559) and alphaGen switch (~564-605)
- **Change:** add `case CGEN_GLOBAL_COLOR:` â `baseColor[0..2] = backEnd.color2D[0..2]/255.0` (leave vertColor 0); add `case AGEN_GLOBAL_ALPHA:` â `baseColor[3] = backEnd.color2D[3]/255.0`. Mirrors gl1 `tr_shade.c:1015-1016, 1134-1136`. Enum is already parsed (`tr_shader.c:1286/1493`) â no enum work.
- **Follow-on (same fix):** change gl2 default 2D-GUI shader `tr_shader.c:4148-4149` from `CGEN_VERTEX`/`AGEN_VERTEX` back to `CGEN_GLOBAL_COLOR`/`AGEN_GLOBAL_ALPHA` to match gl1 `tr_shader.c:3498-3499` (do this only AFTER the switch cases exist, else the default breaks).
- **Test:** any HUD/menu element authored `rgbGen global` (e.g. health bar) renders its intended tint, not solid white/opaque.

### Fix 3 â ADS / iron-sight weapon projection port (5 sub-steps, one feature)
- **Severity:** HIGH (critical for aim) Â· **Confidence:** high
- This is a clean 1:1 gl1âgl2 port with ONE adaptation: gl2 feeds projection to GLSL via `GL_SetProjectionMatrix()` (updates `glState.modelviewProjection`), **NOT** `qglLoadMatrixf(GL_PROJECTION)`. Matrix index layout is identical, so gl1's math transfers verbatim.
  - **3a â cvars:** register `r_weaponfovx "0"` (flag 0), `r_weaponznear "1"` CVAR_ARCHIVE, `r_weaponshifty "-0.05"` CVAR_ARCHIVE, `r_weaponshiftx "0"` CVAR_ARCHIVE in `renderergl2/tr_init.c` R_Register + extern decls in `renderergl2/tr_local.h`. **Names must match exactly** â cgame sets them by name (`cg_view.c:1603/1625/1626`). Prerequisite for 3b-3d.
  - **3b â viewParms fields:** add `float weaponProjectionMatrix[16];` + `qboolean weaponFovActive;` after `projectionMatrix[16]` in `renderergl2/tr_local.h:1014`.
  - **3c â build the matrix:** in `renderergl2/tr_main.c:1785` (immediately after `R_SetupProjectionZ`, where the world matrix is complete), port gl1 `tr_main.c:602-642`: copy world `projectionMatrix`, override `[0]/[5]` from `r_weaponfovx`, rebuild `[10]/[14]` from `r_weaponznear` (clamped â¤ zNear), apply `[8]=r_weaponshiftx`, `[9]=r_weaponshifty`, set `weaponFovActive`. **Guard with `stereoFrame==STEREO_CENTER`** to avoid gl2's existing stereo projection swap.
  - **3d â backend surface swap:** in `renderergl2/tr_backend.c:580-619` (RB_RenderDrawSurfList depthRange block), add a mono path: in `if(depthRange)` â `if(stereoFrame==STEREO_CENTER && weaponFovActive && !isCrosshair) GL_SetProjectionMatrix(weaponProjectionMatrix);`; in `else` â restore `GL_SetProjectionMatrix(projectionMatrix)`. Use `GL_SetProjectionMatrix` (`tr_backend.c:277`), NOT qglLoadMatrixf. Exclude `isCrosshair` (`tr_backend.c:560-561`).
  - **3e â depth-hacked sprites (muzzle flash):** mirror 3d in `renderergl2/tr_backend.c:1931-1957` (RB_RenderSpriteSurfList), plus a restore at function exit near the `qglDepthRange` restore (`tr_backend.c:1955`).
- **Test:** ADS with any iron-sight weapon under gl2 â gun no longer magnifies off-screen, sights align; muzzle flash stays registered to the gun.

### Fix 4 â Port the gore / skin-wound / decapitation-splash system (ROOT D)
- **Severity:** CRITICAL feature (must-have) Â· **Confidence:** high Â· **Big port (~1750 lines)**
- **Files:** copy `renderergl1/tr_gore.c` â `renderergl2/`, add to `renderergl2/CMakeLists.txt`.
  - Declare `RE_GoreImpact/RE_GoreReset/RE_GoreKillSplash` in `renderergl2/tr_local.h`; assign `re.GoreImpact/GoreReset/GoreKillSplash` in `renderergl2/tr_init.c` GetRefAPI (after `re.FreeRawImage`, ~line 2086).
  - Two hook calls: `R_GoreSkelSurfaceCheck(baseVertex,baseIndex)` after gl2's `RB_SkelMesh` CPU-skin (`renderergl2/tr_model.cpp:922`); `R_GoreOverrideImage(image)` in gl2's texture-bind path (cf gl1 `tr_shade.c:223,242`).
  - **Adaptation:** gl2 uses `uint16 tess.color[] Ã 257` + VBO/GLSL shade path vs gl1's byte `tess.vertexColors` + fixed-function bind; the wound-painting operates on CPU-skinned diffuse copies (gl2 already CPU-skins, so viable â needs gl2's image-update path). Register `coop_goreSkinSnap/â¦SnapDist/â¦WoundScale`, `r_goreUV`, `r_goreDebug` cvars.
- **Interim:** leaving NULL is crash-safe (Section 0) if this is deferred.
- **Test:** decap/headshot an enemy under gl2 â UV wound decals + kill splash appear; respawn clears wounds.

### Fix 5 â DBNO / low-health full-screen effect (ROOT C, gameplay cue)
- **Severity:** CRITICAL (gameplay-state readout) Â· **Confidence:** high
- **Recommended strategy â renderer-agnostic relocation (removes the gl1-vs-gl2 divergence permanently):** move the tint to cgame. In `CG_Draw2D`, draw a full-screen red-tinted stretch-pic via `cgi.R_DrawStretchPic`/`RE_SetColor`, gated on `r_ppHealthFrac` (cgame already publishes it, `cg_view.c:1630-1662`, forces 0.02 while DBNO at :1659). Survives even when FBO/post-process is off. Approximate the shader vignette/desaturate with a radial-gradient full-screen pic.
- **Alternative â port into gl2:** add `lowhealth_fp/vp.glsl` to `renderergl2/glsl/` (register in `glsl/shaders.cmake`), `shaderProgram_t lowHealthShader` in `tr_local.h`, compile in `GLSL_InitGPUShaders`, declare `r_ppLowHealth/r_ppHealthFrac/r_ppLowHealthStart/r_ppLowHealthAmount/r_ppLowHealthBeat` in `renderergl2/tr_init.c`, and run an `FBO_Blit` through `lowHealthShader` at the RB_PostProcess insertion point `renderergl2/tr_backend.c:1601`, using the ramp math from `renderergl1/tr_postprocess_gl1.c:755-785`. Note: gl2 `RB_PostProcess` only runs when `framebufferObject` available + `r_postProcess` set (`tr_backend.c:1531`) â a no-FBO config would still miss it, which is why relocation is preferred.
- **Test:** get downed (DBNO) under gl2 â screen desaturates + red vignette pulses.

### Fix 6 â Suppression full-screen effect (ROOT C)
- **Severity:** HIGH Â· **Confidence:** high
- Same mechanism/strategy as Fix 5. cgame publishes `r_ppSuppress` (`cg_view.c:1664-1696`). Either the cgame-2D overlay (for consistency, recommended if Fix 5 chose relocation) or port `SUPPRESSION_FS` (`renderergl1/tr_postprocess_gl1.c:381-405`) into `renderergl2/tr_postprocess.c` after the low-health pass (cheapest gl2 route: reuse existing `RB_GaussianBlur` + a saturation lerp).
- **Test:** take suppressing near-miss fire under gl2 â peripheral desaturate/tunnel-vignette appears and decays.

### Fix 7 â Add MOHAA world-surface CGEN cases to ComputeShaderColors (same function as Fix 2)
- **Severity:** HIGH (static world only; dynamic skeletal entities unaffected) Â· **Confidence:** high
- **File:** `renderergl2/tr_shade.c:463-559` (rgbGen switch)
- **Change:** add `CGEN_LIGHTING_GRID`, `CGEN_LIGHTING_SPHERICAL`, `CGEN_MULTIPLY_BY_WAVEFORM` cases (gl1 handles at `tr_shade.c:908-925`). Mirror `CGEN_STATIC` (`baseColor=0, vertColor=1`) AND populate `tess.color` before draw: GRID â call the already-present-but-dead `RB_CalcLightGridColor` (`tr_shade_calc.c:834`) with `iGridLighting`; SPHERICAL â sphere path (`tr_sphere_shade.cpp`); WAVEFORM â `RB_CalcWaveColorSingle Ã colorConst`. Also add `needsLGrid/needsLSpherical` shader fields (cf gl1 `tr_local.h:599-600`) and set them in `FinishShader` (cf gl1 `tr_shader.c:3152-3156`).
- **Related low-sev:** after this exists, change gl2 `tr_shader.c:3532` `VertexLightingCollapse` default from `CGEN_LIGHTING_DIFFUSE` â `CGEN_LIGHTING_GRID` to match gl1 `tr_shader.c:3050-3054` (only under `r_vertexLight`; do NOT do before the GRID case exists or it worsens the fullbright bug).
- **Test:** load a map with `rgbGen lightingGrid`/`lightingSpherical` content shaders under gl2 â those surfaces are lit, not fullbright white.

### Fix 8 â Cosmetic parity (SKIPPABLE â port only if full visual parity required)
- **Severity:** LOW/MEDIUM Â· **Confidence:** high
- Heat-haze + rain-on-lens UV-warp (`renderergl1/tr_postprocess_gl1.c:410-436, 443-494`) â cosmetic warp, ROOT C; port `heathaze_fp.glsl`+`raindrops_fp.glsl` and run BEFORE the tint passes (warp first, tints overlay after, matching gl1 ordering) only if wanted.
- Grass/foliage (`renderergl1/tr_grass_gl1.c`, cvars `r_alpha_foliage1/2`, `r_blendbushes/trees`, `r_entlight_tikiScale`, `r_static_shaderdata*`) â gl1-only vegetation, port to VBO draw or accept reduced foliage.
- Most other gl1 `r_pp*` post-FX (Bloom/Tonemap/DoF/SunRays/FXAA/SSAO/Sharpen/grade) â gl2 does equivalents natively via its rend2 HDR chain (`RB_ToneMap/RB_BokehBlur/RB_SunRays/RB_GaussianBlur`); **skip**, do not re-port.

---

## Section 4 â Cross-cutting investigation flag (not a blind change)

`r_overBrightBits` default diverges: gl1=0 (`tr_init.c:1406`), gl2=1 (`renderergl2/tr_init.c:1366`). This shifts default-rgbGen decal/HUD brightness (dimension 4). Aligning gl2 to "0" would converge `CGEN_IDENTITY_LIGHTING` brightness with gl1, but it affects ALL rendering â **verify visually after Fixes 1-2, do not change blindly.** Likewise the `CGEN_VERTEX` vs `CGEN_EXACT_VERTEX` overbright asymmetry (gl2 `tr_shade.c:465-494`) is likely already correct for blended decals (overbright evaluates to 1.0 on the blend path) â only revisit if overbright is later raised.

---

## Suggested loop execution order
`Fix 1 â Fix 2 â Fix 3 â Fix 7 â Fix 5 â Fix 6 â Fix 4 â (Fix 8 optional)`.

Rationale: 1/2/7 are cheap shader-side edits sharing roots A/B and unblock visual QA fastest; 3 (ADS) is self-contained and high-value; 5/6 (post-FX cues) share a strategy decision â settle relocation-vs-port once; 4 (gore) is the largest port, last among must-haves; 8 is optional. Re-run the gl2 boot + map-load smoke test after every fix.

Files verified this session: `renderergl2/tr_shader.c:1910-1918`, `renderergl1/tr_shader.c:1751-1761`, `renderergl2/tr_init.c` (GetRefAPI, no Gore/weapon/SwipePoint assignments).