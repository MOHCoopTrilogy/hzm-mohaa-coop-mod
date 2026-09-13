> **USER DECISIONS (2026-09-13, after this design):**
> - D1 tone baseline: the HZM ACES grade (decided with the fog/grade research; fix the daylight reset, bug-2584).
> - D2 bloom: EXPOSURE-AWARE glow - r_ppBloomMode 1 (threshold in display domain for the active curve, half-float
>   bright pass, exposure measured before bloom); mode 0 kept byte-identical for A/B.
> - D3 render scale: default 1.0 for everyone, plus a restart-required Video menu option (0.5-2.0, FSR 1); the
>   user tries 1.5 on their own machine first. Launch/restart only (bug-1181), never a live menu apply.
> - D4 MSAA: build it - no-code retest, alpha-to-coverage, then 4x MSAA - and compare against 1.5x supersampling
>   before either ships as a default.
> - D8 soft particles: ON by default, r_softParticleDistance 24, player can turn off (restart applies).
> - Taken at the recommendation unless the user says otherwise: D5 moderate RCAS above 1.0 that replaces
>   r_ppSharpen only while RCAS runs; D6 GPU timer diagnostics developer-only; D7 gl2 ignores r_ext_multisample;
>   D9 FXAA off while render scale > 1.0.
> - Build order: bloom mode 1 -> MSAA retest -> render-scale split -> FSR 1 -> soft particles -> A2C -> MSAA.

# gl2 render upgrades - design pass (bloom, AA, render scale + FSR 1, soft particles)

Written 2026-09-13. READ-ONLY design: nothing in this note has been built, deployed or run. Every
anchor below was re-read from source on 2026-09-13; where a doc disagreed with the code, the code
is quoted. Performance numbers are ESTIMATES unless a measurement is named.

Approved scope (user, 2026-09-13): (1) fix bloom on gl2, (2) anti-aliasing: alpha-to-coverage
then MSAA returns, (3) render-scale supersampling, extended the same day with AMD FSR 1 as a
selectable filter, (4) soft particles.

Target: renderer_opengl2.dll, source `openmohaa-hzm/code/renderergl2`. Live client:
`G:\mohaa-gl2\openmohaa.exe`, 3440x1440, NVIDIA RTX 5070 Ti, driver 616.64, and a
**GL_VERSION 3.2.0** context (qconsole.log 2026-09-13 14:58). The extension string includes
GL_ARB_texture_multisample, GL_ARB_gpu_shader5, GL_ARB_shader_bit_encoding and GL_ARB_timer_query,
and NVIDIA's GL_NV_alpha_to_coverage_dither_control.

---

## 0. Verified baseline

### 0.1 Live cvars that matter

From `G:\mohaa-gl2\home\maintt\configs\omconfig.cfg`, mtime 2026-09-13 15:04:

```
r_hdr 1                 r_toneMap 1            r_autoExposure 1
r_tonemapMode 0         r_ppTonemap 0          r_ppGrade 0
r_ppBloom 1             r_ppBloomThreshold 0.349570   r_ppBloomIntensity 0.893983
r_ppSSAO 1   r_ppDoF 1  r_ppFXAA 1   r_ppSharpen 1 (0.35)  r_ppChromaticAberration 1
r_ppHeatHaze 1  r_ppSuppression 1  r_ppUnderwaterFx 1
r_depthPrepass 1        r_sunlightMode 1       r_drawSunRays 0     r_globalFogPreTone 0
r_ext_multisample 0     r_ext_framebuffer_multisample 0
r_mapOverBrightBits 2   r_mapOverBrightScale 0.71     r_postProcess 1
r_customwidth 3440  r_customheight 1440  r_mode -1  r_fullscreen 1  com_maxfps 180
```

**T7 fossil that changes the bloom analysis.** `coop_defaults.cfg:95` seeds `r_ppTonemap 1`, but
the archived `r_ppTonemap 0` in omconfig wins. So **the user runs rend2's Hable tone curve with
autoexposure, while a fresh install runs the HZM ACES grade.** The two paths put bloom in
different numeric domains (section 1). This is Decision D1.

### 0.2 FBO topology today

All images are created in `tr_image.c:3549-3633`, all FBOs in `tr_fbo.c:251-432`.

| object | size | format | anchor |
|---|---|---|---|
| tr.renderImage | vidW x vidH | RGBA16F when r_hdr 1 | tr_image.c:3556-3562 |
| tr.renderDepthImage | vid | DEPTH24 texture | tr_image.c:3578 |
| tr.screenScratchImage | vid | RGBA8 | tr_image.c:3564-3565 |
| tr.hdrDepthImage | vid | R32F; exists only if shadowBlur, ssao, r_ppSSAO or r_ppDoF | tr_image.c:3572-3573 |
| tr.sunRaysImage | vid | RGBA8 (r_drawSunRays) | tr_image.c:3575-3576 |
| tr.screenShadowImage | vid | RGBA8 (r_sunlightMode) | tr_image.c:3626 |
| tr.quarterImage[0..1] | vid/2 | **RGBA8** | tr_image.c:3599-3602 |
| tr.screenSsaoImage | vid/2 | RGBA8 | tr_image.c:3605-3608 |
| tr.textureScratchImage[0..1] | 256x256 | RGBA8 | tr_image.c:3595-3598 |
| tr.renderFbo | vid | MSAA: MS renderbuffers (hdrFormat + D24); else renderImage + renderDepthImage | tr_fbo.c:283-303 |
| tr.msaaResolveFbo | vid | renderImage + renderDepthImage (MSAA only) | tr_fbo.c:292-295 |
| tr.screenScratchFbo | vid | screenScratch + **renderDepthImage as depth** | tr_fbo.c:313-318 |
| tr.globalFogFbo | vid | colour-only alias of screenScratch (feedback-loop avoidance) | tr_fbo.c:320-329 |
| tr.hdrDepthFbo, quarterFbo, screenSsaoFbo, sunRaysFbo, screenShadowFbo | as images | | tr_fbo.c:332-418 |

- No FBO has a stencil attachment.
- `FBO_Blit` ORs `GLS_DEPTHTEST_DISABLE` (`tr_fbo.c:642`).
- `FBO_BlitFromTexture` pushes `UNIFORM_HZMPARAMS`, `UNIFORM_AUTOEXPOSUREMINMAX` and
  `UNIFORM_TONEMINAVGMAXLINEAR` on every blit (`tr_fbo.c:611-613`).
- A NULL destination falls back to vid dimensions (`tr_fbo.c:531-532`, `:661-673`).
- MSAA sample count is clamped to GL_MAX_SAMPLES; the MS branch needs framebufferBlit
  (`tr_fbo.c:271-281`).

### 0.3 Pass order, per world scene (`RB_PostProcess`, tr_backend.c:2126-2295)

1. Early-out if `!r_postProcess` (2137-2141).
2. MSAA resolve, colour and depth, `GL_NEAREST` (2152-2158).
3. SSAO generation `RB_HZMSsao` (2177), then the multiply composite gated on
   `backEnd.ssaoValid` (2185-2194).
4. Optional pre-tone global fog (2223-2227; `r_globalFogPreTone`, live 0).
5. `RB_HZMDof` then `RB_HZMBloom` (2234-2239), both on the HDR buffer.
6. `RB_ToneMap` into screenScratch, then FastBlit back (2241-2251).
7. Post-tone global fog (2265-2269; the live order).
8. `RB_HZMScreenFx` (2276): motion blur (off), FXAA, sharpen, heat haze, rain, low health,
   suppression (tr_postprocess.c:795 onward).
9. `RB_HZMExtraFx` (2281): underwater, blood, frost, chromatic aberration, grain, dizzy
   (tr_postprocess.c:1416 onward).
10. Sun rays (2285-2286, off), bokeh (2288-2289).

### 0.4 HUD safety on gl2

- The gl1 note "the 3D->2D hook lives in Set2DWindow" describes renderergl1.
- gl2's `Set2DWindow` (`tr_draw.c:614-648`) calls no post pass. On gl2, HUD safety comes from
  **command order** instead:
  - `RC_POSTPROCESS` is queued at the end of every world `RE_RenderScene`
    (`tr_scene.c:841-842`, `!RDF_NOWORLDMODEL`), before the frame's 2D commands.
  - Every post pass above therefore finishes before the HUD is drawn into `tr.renderFbo`.
- Known interleave hazard: a 3D scene drawn after 2D in the same frame
  (bug-gl2-viewmodel-over-menu, bug-1140, bug-1144).
- Every design below keeps all new work inside `RB_PostProcess` or earlier in the scene, and
  never touches 2D.

### 0.5 Other load-bearing facts

- **Sprites** (all emitter particles) are a SEPARATE sorted list per view.
  - Queued as `RC_DRAW_SURFS` then `RC_SPRITE_SURFS` (`tr_main.c:1710-1711`).
  - Drawn by `RB_SpriteSurfs` -> `RB_RenderSpriteSurfList` (`tr_backend.c:2678-2695`,
    `2597-2672`), AFTER the view's opaque and blended world surfaces and BEFORE post.
  - First-person RF_DEPTHHACK sprites swap depth range at `tr_backend.c:2617-2647`.
- **Alpha test is pure GLSL `discard`** (`generic_fp.glsl:66-80`; lightall_fp.glsl, same block
  before its `gl_FragColor.a = alpha` at :592).
  - Selected in `tr_shade.c:1707-1737` from the stage's `GLS_ATEST_*` bits
    (`tr_local.h:2996-3006`).
  - Cutouts skip the depth prepass (`RB_DepthFillSkip`, `tr_backend.c:494-495`,
    bug-gl2-foliage-white).
  - `GL_SAMPLE_ALPHA_TO_COVERAGE` appears nowhere in either renderer (grep 2026-09-13).
- **Shader collapse:** `CollapseStagesToGLSL` (`tr_shader.c:3216`) skips only shaders with
  deforms (3222-3225). So a blended, deform-free sprite shader can run in **LIGHTALL**, not
  GENERIC (consistent with bug-2486). Any per-fragment feature for particles must go into BOTH
  `generic_fp.glsl` and `lightall_fp.glsl`.
- **Texture units:** `NUM_TEXTURE_BUNDLES = 7`, TB 0..6 (`tr_local.h:497-509`). The DSA cache is
  `glDsaState.textures[NUM_TEXTURE_BUNDLES]` (`tr_dsa.c:27`), so a TMU 7 would index out of
  bounds unless that array (and the loops at `tr_dsa.c:44,52`) is widened.
- **GLSL embedding:**
  - `glsl/shaders.cmake:1-14` globs `*.glsl` and runs `tools/stringify.cpp`.
  - Stringify wraps EVERY LINE in double quotes with no escaping (`stringify.cpp:39-51`).
    - A double quote anywhere, including comments, breaks the build (bloom_bright_fp.glsl:28-29).
    - A trailing backslash (macro continuation) corrupts the literal.
  - Each program also needs: an extern in `tr_glsl.c` (e.g. :56-57), `GLSL_InitGPUShader` +
    `GLSL_InitUniforms` + sampler `SetUniformInt` + `GLSL_FinishGPUShader` (e.g. tr_glsl.c:1513-1543),
    a delete in the shutdown list (tr_glsl.c:1964-1965), and a `shaderProgram_t` in trGlobals_t
    (tr_local.h:2303-2304).
  - A NEW .glsl needs a CMake re-glob (renderergl2/CMakeLists.txt:5 "touch to re-glob").
  - New uniforms MUST be appended last, in both the enum and uniformsInfo
    (`tr_local.h:939-955`).
  - `r_externalGLSL` (tr_init.c:1475, CVAR_LATCH) loads shader text from disk, useful for tuning
    without a rebuild.
- **Latched cvars** apply only at a full relaunch. `vid_restart` from an open menu crashes gl2
  (bug-1181, bug-1145), so every allocation-gating cvar below is launch-only and gets a
  "(needs restart)" menu label, like AO.
- **P0 prerequisite** (OPEN.md "renderer_opengl2.dll has zero rollback points"): make a `.bak` of
  the live dll before the first build of any of this.

---

## 1. Feature 1 - bloom

### 1.1 Current state (verified)

- `RB_HZMBloom` (`tr_postprocess.c:689-729`):
  - Bright pass into the half-res **RGBA8** `quarterFbo[0]` (712-713), then 9-tap H and V
    Gaussian (716-720), then additive composite back onto the HDR scene, intensity rides
    u_Color (723-728).
  - Levers are registered lazily at :698-700 (CVAR_ARCHIVE).
- `bloom_bright_fp.glsl:38-42` clamps the sample to [0,1], then applies a soft knee
  `f = max(b - thr, 0) / b`. The clamp is the bug-1156/bug-1159 fix of 2026-07-28.
- **The OPEN.md claim "no-op at 0.664756" is stale.** It was measured for bug-1149 at 12:45,
  before the bug-1159 clamp landed at 16:15, against a different threshold. Do not reuse it.
- gl1 reference (`renderergl1/tr_postprocess_gl1.c`):
  - Copies the fixed-point backbuffer into sceneColor (:871), so values are clamped by the
    target.
  - BRIGHT_FS has no clamp of its own (:133-143).
  - Bloom composites additively onto the backbuffer (:1000-1033), and the grade copies the
    result afterwards (:1075).
  - gl1 therefore thresholds and composites in the **pre-grade, clamped [0,1]** domain.

### 1.2 The domain problem, measured analytically

gl2 has two tone paths, selected at `tr_postprocess.c:111`.

**(a) HZM grade path** (`r_tonemapMode 1 || r_ppTonemap || r_ppGrade`; what coop_defaults intends)

- `tonemap_hzm_fp.glsl:27` clamps the scene to [0,1] before exposure 0.889971, ACES and
  contrast 0.951289. The bright pass sees the same clamp, so **gl1 parity already holds**.
- Threshold 0.349570 corresponds to display 0.454; the clamp ceiling 1.0 to display 0.764, on
  both gl1 and gl2.
- The only real difference is the one gl1 shares: bloom added to pixels already at 1.0 is
  clipped by the grade.

**(b) rend2 Hable + autoexposure** (all three selectors 0; **the user's live config**)

The mapping, from `tonemap_fp.glsl:35-47` and `tonemap_vp.glsl:26`:
- log2 of the geometric-mean luminance, `calclevels4x_fp.glsl:48-50`, clamped to [-2, 2]
  (`tr_bsp.c:3527-3528`).
- toneMinAvgMax levels (-8, -2, 0) (`tr_bsp.c:3531-3533`).
- `r_cameraExposure` 1 minus autoExposure 1 gives gain 1 (tr_postprocess.c:85).
- Hence `display = Hable(s * 0.25/avgLum - 2^-8) * 2.4991`. The display white point is 4x the
  scene's average luminance, and a pixel at the average maps to display 0.302.

Computed with that exact shader math (scratchpad `bloomdomain.py`):

| scene avgLum | display of s = threshold 0.3496 | display of s = 1.0 (bright-pass clamp ceiling) | scene s that reaches display 1.0 |
|---:|---:|---:|---:|
| 0.25 (clamped floor: night, interiors) | 0.425 | 1.000 | 1.0 |
| 0.50 | 0.204 | 0.592 | 2.0 |
| 1.00 (typical daylight, estimate) | 0.091 | 0.302 | 4.0 |
| 2.00 | 0.039 | 0.139 | 8.0 |
| 4.00 (clamped ceiling) | 0.016 | 0.061 | 16.0 |

What that means on the live path:
- In a daylit frame the bright pass starts at roughly **display 0.09**. It is saturated by
  **display 0.30**, because of the bug-1159 clamp.
- Every real highlight (sky, sunlit walls, fire) sits between display 0.30 and 1.0 and gets
  **the same flat bright-pass value** (0.65).
- Bloom stops being a highlight effect. It becomes a low-frequency veil weighted by the area of
  mid-to-bright tones.
- A second effect damps it further. The composite lands BEFORE `RB_ToneMap` measures luminance
  (`tr_postprocess.c:31-80` reads `hdrFbo` after bloom), so the added energy raises the
  geometric mean and autoexposure pulls the whole frame down. The blend is 0.03 per update,
  every 5+ frames.
- Net result: a slow, slight contrast loss that reads as "bloom does nothing". Only in dark
  frames (avgLum at the 0.25 floor) is the window close to gl1's intent (0.43-1.0).

Side findings, on the same path:
- **DoF clamps HDR.** `RB_HZMDof` copies the HDR scene into RGBA8 `quarterFbo` (tr_postprocess.c:1375;
  image at tr_image.c:3601). Under Hable, out-of-focus bright regions are clamped to 1.0 and
  render darker than in-focus ones.
- **Half-res bloom is small at 3440 wide.** A 9-tap blur with sigma about 2 half-res pixels
  gives a halo radius of roughly 4-8 display pixels.

### 1.3 Design

**Mode 0 (default): today's behaviour, byte for byte.**

**Mode 1: exposure-aware threshold, pre-tone composite (recommended).**

1. **Separate the luminance measurement from the tone pass.**
   - Split `RB_ToneMap`'s levels block (tr_postprocess.c:31-80) into
     `RB_ToneMapMeasureLevels(FBO_t *hdrFbo, ivec4_t hdrBox)`.
   - `RB_PostProcess` calls it before `RB_HZMDof` (i.e. before tr_backend.c:2237).
   - `RB_ToneMap` gains a flag so it does not measure twice.
   - This removes the bloom -> exposure feedback, for both modes (harmless in mode 0).
2. **Add HDR bloom buffers.**
   - New `tr.bloomImage[0..1]`: **RGBA16F at DISPLAY/2**, i.e. glConfig.vidWidth/2, independent
     of render scale (section 3), so the halo radius and cost do not change with scale.
   - New `tr.bloomFbo[0..1]`, colour only.
   - Allocated unconditionally next to quarterImage (tr_image.c:3599-3602), because r_ppBloom is
     registered lazily and can be toggled live. VRAM: 2 x 1720x720 x 8 B = 20 MB.
   - Mode 0 keeps using quarterFbo, so it is unchanged.
3. **Bright pass** (extend `bloom_bright_fp.glsl`; no new file, so no re-glob).
   - Uniforms:
     - u_Color = (threshold, knee, mode, maxBright).
     - u_HzmParams = (tonePath 0/1, invTexRes.x, invTexRes.y, 0).
     - u_LevelsMap on TB_LEVELSMAP, bound to calcLevelsImage (the smoothed value, same as
       tonemap_fp.glsl:35).
     - u_AutoExposureMinMax and u_ToneMinAvgMaxLinear, which FBO_BlitFromTexture already pushes.
   - mode 0: exactly lines 38-42.
   - mode 1:
     - Take 4 bilinear taps at +-0.5 source texel. This is a 2x2-texel box that stops sub-pixel
       highlight flicker, since the source can be 2x-4x larger than the target.
     - Compute a display proxy `d`:
       - grade path: `d = maxc(clamp(c, 0, 1))`;
       - Hable path: `e = max(c*invAvgLum - min, 0)`, then `d = Hable(maxc(e)) * invWhite`,
         copying the helper from tonemap_fp.glsl:15-25.
     - `f = smoothstep(thr - knee, thr + knee, d)`.
     - Output `min(c, maxBright) * f`, **not clamped to 1**. maxBright is 8.0, a hardcoded
       constant with a comment, to stop fireflies from sun/flare pixels.
   - The CPU chooses tonePath with a new helper `RB_HZMToneUsesGrade()`, factored from the
     predicate at tr_postprocess.c:111, so the two can never drift apart.
   - Comments in the GLSL must contain no double quotes.
4. **Blur:** the same `bloom_blur_fp` on bloomFbo (no shader change).
   - Optional stage 2: a second, quarter-display octave added back (r_ppBloomRadius 1 = today's
     look, 2 = wider). This changes the look (Decision D2).
5. **Composite:** unchanged. Additive, pre-tone, into srcFbo at full scene size, bilinear
   upsample from D/2.
   - Grade path: the grade's clamp clips bloom over pixels already at 1.0, as gl1 does.
   - Hable path: the shoulder compresses it gracefully.
6. **Cvars** (register once, in R_Register, not lazily; Cvar_Get OR-combines flags, bug-1125):
   - `r_ppBloomMode` - CVAR_ARCHIVE, live, default **0**. Flip the coop_defaults seed only after
     the A/B, AND edit the live omconfig with the game closed (T7).
   - `r_ppBloomKnee` - CVAR_ARCHIVE, live, default 0.1.
   - `r_ppBloomRadius` - CVAR_ARCHIVE, live, default 1 (stage 2 only).
   - `r_ppBloomDebug` - CVAR_TEMP (not CHEAT: a listen server clamps cheats, see the
     r_globalFogDebug precedent at tr_init.c:1926). At 1 it prints
     `^~^~^ BLOOM avgLum=%f invAvgLum=%f tonePath=%d thrScene=%f` once per second, reading the
     1x1 calcLevels texel with qglReadPixels. That number is exactly the unknown in the table
     above, which is why it is worth one line.
   - `r_ppBloomThreshold` keeps a display-referred 0..1 meaning in mode 1 on BOTH tone paths,
     so the existing menu slider stays honest.

**Alternative A (rejected as the default, kept as a fallback): move bloom after tone.**
- Move the call from tr_backend.c:2238 to after :2251 and keep RGBA8.
- One line, but:
  - it composites in display space (clips at 1.0 with no shoulder);
  - it runs before post-tone fog (fine) but after the grade, so gl1 parity on the grade path
    is lost, and the shipped 0.3496 no longer means what it means on gl1;
  - on the Hable path it is still better than today.

### 1.4 Interactions

- **SSAO:** the multiply happens before bloom. Unchanged.
- **DoF:** runs before bloom on the same HDR image. Bloom is not defocused, as on gl1.
  - If the RGBA8 clamp side finding is fixed, DoF can reuse bloomImage[1] as its 16F half-res
    blur target, but only at D/2, so its blur radius becomes resolution-independent too.
  - That is optional and only visible on the Hable path.
- **Fog:** the live post-tone fog mixes over the bloomed result, so distant glow fogs correctly.
  With pre-tone fog, fog lands before bloom and distant highlights dim before thresholding.
  Both are acceptable.
- **Tone/grade, sun rays, underwater, suppression, low health:** all run after. Unaffected.
- **HUD:** everything is inside RB_PostProcess (section 0.4).
- **bug-1296:** unaffected. The bright pass reads colour, not depth.

### 1.5 Cost, risks, effort

- **Cost (estimate, 3440x1440):**
  - Bright pass with 4 taps at 1.24 MP, plus 2 blur passes at 1.24 MP, plus a full-res
    composite: about 0.3-0.6 ms on this GPU, roughly today's cost.
  - Stage 2 adds under 0.1 ms.
  - Moving the measurement changes nothing (same work, earlier).
- **Risks:**
  - Mode 1 on night maps: autoexposure boosts dark frames up to 4x, so fires, lamps and flashes
    bloom more. Check that m1l1's moonlit sky (suncolor "10 15 30") does not glow.
  - Fireflies from `r_drawSun` and flares. Mitigated by maxBright and the 4-tap bright pass.
  - Moving the luminance measurement BEFORE bloom slightly brightens bright maps (exposure no
    longer sees bloom energy). Measure mean luma.
  - Changing `r_ppBloomThreshold`'s effective meaning on the Hable path is a visible look change.
- **Effort (estimate):**
  - Mode 1 + 16F buffers + measure split + debug print: S-M, about 1 day including an A/B.
  - Stage 2 radius: +0.25 day.
  - Alternative A: under 1 hour plus A/B.

---

## 2. One shared FBO plan (render scale, FSR, MSAA and soft particles all use this)

### 2.1 Definitions

- **D** = display size, glConfig.vidWidth x vidHeight (3440x1440).
- **S** = scene size = round(D * r_renderScale), with r_renderScale in [0.5, 2.0].
  - Clamp S to glRefConfig.maxRenderbufferSize (checked by FBO_Create, tr_fbo.c:89-97).
  - Clamp S to at most 4x the pixels of D.
- S < D: FSR upscale. S > D: supersample. S == D: today's path.

### 2.2 The split

**Rule: 3D and post live at S; 2D, present, screenshots and levelshots live at D.**

| object | size | colour | depth | exists when |
|---|---|---|---|---|
| **tr.sceneFbo** (NEW pointer) | S | MSAA: MS colour (hdrFormat); else tr.renderImage | MSAA: MS D24; else tr.renderDepthImage | always |
| tr.msaaResolveFbo | S | renderImage | renderDepthImage | MSAA only |
| **tr.renderFbo** (becomes display) | D | when S==D and no MSAA: renderImage (alias); else NEW tr.displayImage RGBA8 | own D24 renderbuffer (for RDF_NOWORLDMODEL / RDF_HUD 3D) | always |
| **tr.displayScratchFbo** (NEW) | D | RGBA8 | none | S != D |
| screenScratch, globalFog, hdrDepth, sunRays, screenShadow | S | as today | as today | as today |
| quarter, screenSsao | S/2 | as today | | as today |
| **tr.bloomFbo[0..1]** (section 1) | D/2 | RGBA16F | none | always |
| textureScratch, levels, shadow maps, cubemaps | unchanged | | | |

**Byte-identical guarantee.** At r_renderScale 1 with MSAA 0, `tr.sceneFbo == tr.renderFbo` (the
same pointer, created exactly as tr_fbo.c:297-303 does today), no displayImage is created, and
no resample runs.

**Why renderFbo is the pointer that stays at D.** It has 42 references
(`grep tr\.renderFbo renderergl2`). The 2D and present sites keep their meaning untouched:
- tr_draw.c: 11 binds in Draw_StretchPic etc., plus R_Ensure2DClear (:54-86).
- RE_StretchRaw / cinematic: tr_backend.c:1246, 1352.
- RB_DrawBuffer clear: 1856-1870.
- RB_SwapBuffers present: 2059-2061.
- Anaglyph clear: tr_cmds.c:484-487.
- tr_font.cpp.

The screenshot, levelshot and video paths then need **no change**:
- `RB_ReadPixels(0, 0, vidW, vidH)` (tr_init.c:648-692, 896).
- `qglReadPixels(cmd->width, ...)` (tr_init.c:1135).

The sites that must move to `tr.sceneFbo`:

| site | change |
|---|---|
| tr_backend.c:353 (RB_BeginDrawingView) | targetFbo NULL -> world scene uses sceneFbo; RDF_NOWORLDMODEL stays renderFbo |
| tr_backend.c:1622 | prepass MSAA depth resolve source |
| tr_backend.c:1992, 1998-2001 (RB_ClearDepth) | clear the scene target |
| tr_backend.c:2149-2156 (RB_PostProcess) | srcFbo |
| tr_backend.c:2053-2058 (RB_SwapBuffers MSAA resolve) | **delete**: display is never multisampled any more, which also stops the HUD being MSAA-drawn and resolved |
| tr_cmds.c:478-481 | anaglyph clear |
| tr_flares.c:288-302 | already binds msaaResolveFbo; windowX/Y come from the scaled viewport, so they land in S space automatically |

### 2.3 Viewport scaling

- `RE_RenderScene` builds the viewport from the refdef in D pixels (`tr_scene.c:746-749`).
- For a world scene (`!(rdflags & RDF_NOWORLDMODEL)` and targetFbo NULL), scale x, y, w, h by
  S/D there.
  - Portal-sky and mirror sub-views inherit from parms.
  - Shadow and cubemap views have their own targetFbo and are left alone (tr_main.c:2314-2317,
    2651-2660, 3544).
- Projection is fov-based, so it is scale-independent.

### 2.4 Audit list: code that assumes scene == vid

- **tr_backend.c:1650-1661** (shadowmask box divides viewport by glConfig.vidWidth/Height) and
  **2188-2191** (SSAO composite box): divide by sceneFbo dims instead. Add
  `tr.sceneWidth` / `tr.sceneHeight`.
- **tr_backend.c:2312-2315:** debug quarter boxes, same fix.
- **tr_postprocess.c:395-396, 522-523:** RadialBlur / SunRays NULL-fbo fallbacks. Fine, since
  srcFbo is never NULL.
- **tr_postprocess.c:658:** RB_GaussianBlur dstBox uses vid dims. That path is dead
  (`if (1)` at tr_backend.c:2288), but fix it for hygiene.
- **tr_postprocess.c:962-963, 1718-1719:** aspect only, so ratio-safe.
- **Texel-kernel shaders** (`u_InvTexRes`): bloom_blur (bloom moves to D/2, see 1.3); DoF's use
  of quarterFbo (radius shrinks by 1/scale, so pass texScale = S/D); fxaa and sharpen
  (per-texel, correct at any size); underwater_fp ("1.0 = 9 texels at 1080p"; verify it is
  height-normalised); bokeh (dead); calclevels/down4x (256x256 scratch, unaffected);
  bloodspatter (verify). Each needs a one-line check at implementation.
- **Flare sizes** in tr_flares.c are pixel-based: verify once. r_drawSun is world-space.

### 2.5 HUD, screenshots, vid_restart, r_postProcess

- **HUD:** unchanged by construction. 2D never touches S; the resample writes renderFbo before
  any 2D command of the frame (section 0.4).
  - If 2D is drawn before the world scene in a frame, today the world overwrites it inside the
    viewport; after the split, the resample overwrites the same rect. Equivalent.
- **r_postProcess 0:** the resample must still run, so put it BEFORE the early-out at
  tr_backend.c:2137-2141 (if scaled, resample, then return).
- **Screenshots, levelshots, video:** stay at D (a feature request for native-S shots is out
  of scope).
- **Latched:** r_renderScale and r_ext_framebuffer_multisample resize or recreate targets, so
  both are CVAR_LATCH and launch-only (bug-1181).

---

## 3. Feature 3 - render scale, with FSR 1 as a selectable filter

### 3.1 Current state

- Absent: no r_renderScale or supersample token in renderergl2/renderercommon/sdl.
- `r_imageUpsample` is texture upsampling, unrelated.
- No FSR, NIS or FidelityFX code in the tree. The only grep hit, in tr_init.c:1662, is the word
  "MEASURED".

### 3.2 Chain placement

The resample and RCAS are ONE new stage at the END of the post chain:
- after `RB_HZMExtraFx` (tr_backend.c:2281), sun rays (2286) and bokeh (2289);
- before the frame's 2D.

The resulting chain:

```
scene @S -> SSAO -> [pre-tone fog] -> DoF -> bloom -> tone/grade -> [post-tone fog]
  -> motion blur -> FXAA -> sharpen* -> heat haze -> rain -> low health -> suppression
  -> underwater -> blood -> frost -> chromatic aberration -> grain -> sun rays
  -> RESAMPLE S->D (EASU / quality downsample / bilinear) -> RCAS @D -> [renderFbo @D] -> HUD 2D
```

`*` r_ppSharpen is **skipped whenever RCAS runs** (no double sharpening). With RCAS off, it runs
at S as today.

Why at the end, and not directly after FXAA (AMD's ideal: after tonemap and AA, before noise
and lens effects):
- Every tail pass round-trips through S-sized scratch.
- `RB_HZMExtraFx`'s underwater stage samples `tr.renderDepthImage` and writes through
  `tr.globalFogFbo` (tr_postprocess.c:1564-1569, 1659), both S-sized.
- Resampling right after FXAA would mean re-targeting about 10 passes onto D-size scratch
  FBOs.

Accepted costs of placing it at the end:
- **Film grain before EASU** gets treated as detail. It ships off (r_ppFilmGrain 0).
- **Chromatic aberration** is smooth and radial, so harmless.
- **Rain and heat haze** are refractions, so harmless.

A v2 can move grain (and only grain) after RCAS if it is ever enabled.

### 3.3 Filters

`r_upscaleFilter`: CVAR_ARCHIVE, live (no allocation), default 1.

| scale | r_upscaleFilter 0 | r_upscaleFilter 1 (default) |
|---|---|---|
| < 1 | FBO_FastBlit GL_LINEAR | **FSR 1 EASU** to D |
| = 1 | nothing | nothing |
| > 1 | FBO_FastBlit GL_LINEAR (exact box at 2.0, soft at 1.5) | **quality downsample**, new `glsl/downscale_fp.glsl`, see below |

**Quality downsample (scale > 1).**
- A separable tent / 2-lobe filter.
- Implemented as 4 bilinear taps at +-(0.5 * S/D - 0.25) source texels around the destination
  centre, covering the full footprint at any ratio from 1 to 2.
- Runs on display-referred values (post-tone), which is standard. Averaging gamma-encoded values
  slightly darkens high-contrast edges compared with a linear-light average; that is acceptable
  and it is what every SSAA implementation in this class does.

**RCAS** (any scale, including 1.0, where it is simply a better sharpen than r_ppSharpen).
- `r_fsrSharpness` (CVAR_ARCHIVE, live) in **stops**:
  - 0.0 = maximum sharpening; each +1.0 halves the strength;
  - negative = RCAS off.
- Default 0.2 when scale < 1, -1 (off) at scale 1.0.
- Recommend 0.5 for scale > 1 as a starting point; tune by A/B.
- Gating:
  - When `r_fsrSharpness >= 0`, RCAS runs at D after the resample, on renderFbo via
    displayScratchFbo, and `RB_HZMScreenFx` skips r_ppSharpen (tr_postprocess.c:897-902).
  - When RCAS is off, r_ppSharpen behaves as today.
  - At scale 1.0, RCAS replacing r_ppSharpen is opt-in only (the shipped r_ppSharpen look is
    user-tuned).

### 3.4 FSR 1 - licence, vendoring, GLSL port notes

**Licence (checked 2026-09-13).**
- `github.com/GPUOpen-Effects/FidelityFX-FSR/license.txt` is the **MIT License**,
  "Copyright (c) 2021 Advanced Micro Devices, Inc. All rights reserved."
- The shader headers are `ffx-fsr/ffx_a.h` and `ffx-fsr/ffx_fsr1.h`, each carrying the same AMD
  MIT header.
- `ffx_a.h` also contains a **second MIT notice crediting Michal Drobot** for its float
  approximation helpers. It applies only if a function from that section is ported; the trimmed
  port below should avoid them, and if it cannot, carry that notice too.

**Vendor as follows:**
- **Pristine reference copy (not compiled):**
  `openmohaa-hzm/code/thirdparty/FidelityFX-FSR-1.0/{license.txt, ffx_a.h, ffx_fsr1.h, README.hzm}`.
  README.hzm records the upstream commit hash, taken at vendoring time.
  `thirdparty/` already holds SDL2, opus and recastnavigation. shaders.cmake only globs
  `renderergl2/glsl/*.glsl`, so these headers are never stringified.
- **Trimmed GLSL ports (compiled):**
  `renderergl2/glsl/fsr_easu_fp.glsl` and `renderergl2/glsl/fsr_rcas_fp.glsl`, both using
  `tonemap_vp` as the vertex stage, as the bloom programs do.
  - Each file starts with the AMD copyright line and the MIT permission paragraph.
  - The licence text quotes "Software" and "AS IS", and **stringify cannot carry a double
    quote**. So the in-shader copy uses single quotes, and the verbatim notice lives in
    thirdparty license.txt.
- **Binary distribution attribution:**
  - add the AMD MIT notice verbatim to the release's third-party notices (the release docs
    under docs/public, or a THIRD_PARTY_NOTICES.txt in the release zip);
  - one line in HISTORY.md when it ships.
  - MIT requires the notice "in all copies or substantial portions", and the compiled dll embeds
    the shader source.

**Why not vendor the headers verbatim into glsl/:**
- stringify (stringify.cpp:39-51) wraps each line in quotes, and ffx_a.h uses backslash macro
  continuations extensively, which corrupt the literal.
- ffx_a.h is roughly 2,800-3,000 lines; a single concatenated string that size also risks MSVC's
  string-literal limits.
- There is no include mechanism (generic_fp.glsl:17-19 says so).

**Port notes:**
1. **Use the 32-bit F path, not H.**
   - Define `A_GPU` and `A_GLSL`, then use `FSR_EASU_F` / `FSR_RCAS_F` with `FsrEasuF(pix, ip,
     con0..3)` and `FsrRcasF(pixR, pixG, pixB, ip, con)`.
   - `A_HALF` / the H path uses `float16_t` with `GL_EXT_shader_16bit_storage` and
     `GL_EXT_shader_explicit_arithmetic_types`, which are Vulkan-GLSL only. Our context compiles
     `#version 150` (tr_glsl.c:294-301).
2. **EASU uses `textureGather`** (the FsrEasuRF/GF/BF callbacks), which needs GLSL 4.00 or
   `GL_ARB_gpu_shader5`.
   - The live context advertises GL_ARB_gpu_shader5. Put `#extension GL_ARB_gpu_shader5 : enable`
     in the `extradefines` string; tr_glsl.c:303 already places `extra` directly after `#version`,
     where #extension must go.
   - Fallback when the extension is absent: rewrite the three callbacks as 12 `texture2D`
     point-sample taps (the same 12-tap footprint), or drop to r_upscaleFilter 0 with a one-time
     console warning. Recommend the warning (this GPU has it).
3. **Constants.**
   - Port `FsrEasuCon` and `FsrRcasCon` to C in tr_postprocess.c: about 40 lines, pure arithmetic
     on input viewport size, input size and output size.
   - Upstream packs floats into `uint` vectors and reinterprets them with `AF4_AU4`
     (uintBitsToFloat, GLSL 3.30 or ARB_shader_bit_encoding). **Pass plain `vec4` floats
     instead** and delete the reinterpretation, which removes that dependency.
   - Four new vec4 uniforms, appended LAST (tr_local.h:939-955): `UNIFORM_FSRCON0..3`, named
     `u_FsrCon0..3`. RCAS uses `u_FsrCon0` only.
   - Set them with GLSL_SetUniformVec4 before FBO_Blit, following the RB_GlobalFog pattern
     (tr_postprocess.c:244-249).
4. **Input domain.**
   - EASU expects perceptual (roughly gamma 2.0) input. The post-tone buffer is display-referred
     [0,1], so it can be fed directly.
   - EASU also expects anti-aliased input: at scale < 1, keep r_ppFXAA on (it runs at S before
     the resample).
5. **RCAS.**
   - `FsrRcasLoadF(ip)` becomes `texelFetch(u_TextureMap, ip, 0)` (GLSL 1.30+).
   - `FSR_RCAS_LIMIT` is `(0.25 - (1.0/16.0))`. Keep `FSR_RCAS_DENOISE` defined: MOHAA's
     ESRGAN textures and dithered sky gradients are exactly the noise it suppresses.
   - The sharpness conversion is `con.x = 2^(-stops)`, done in FsrRcasCon.
6. **Skip LFGA and TEPD.** Film grain has its own pass, and the output is an RGBA8 target.
7. **No double quotes and no trailing backslashes in either .glsl.** Re-glob CMake after adding
   the files.

**Scale presets for the menu** (FSR 1 naming; r_renderScale is a multiplier of D):
- Ultra Quality 0.77
- Quality 0.667
- Balanced 0.588
- Performance 0.5
- Native 1.0
- SSAA 1.25 / 1.5 / 2.0

### 3.5 NVIDIA Image Scaling (NIS) - considered, not recommended

- `github.com/NVIDIAGameWorks/NVIDIAImageScaling`: **MIT License**, "Copyright(c) 2022 NVIDIA
  CORPORATION & AFFILIATES. All rights reserved."
- Files: `NIS_Scaler.h`, `NIS_Config.h`, `NIS_Main.hlsl`, `NIS_Main.glsl`.
- **Its shaders are compute shaders, and it needs coefficient textures** for the scaler and USM
  phases.
- Compute needs GL 4.3. The live context is **GL 3.2** (qconsole GL_VERSION 3.2.0).
- Using NIS would therefore mean porting the compute kernel to a fragment shader AND uploading
  the coefficient textures, or raising the context version: a renderer-wide risk this project
  should not take for an upscaler.
- Quality is comparable to FSR 1.
- **Recommendation: FSR 1.**

### 3.6 DLSS - out of scope

- RTX-only.
- Requires motion vectors, sub-pixel jitter and history buffers. This renderer has none; TAA was
  already rejected in visual_upgrade_plan.md section 5 for the same reason, and because it blurs
  the sharpened hand-painted art.
- The SDK has no OpenGL support.

### 3.7 Cvars

| cvar | flags | default | notes |
|---|---|---|---|
| r_renderScale | CVAR_ARCHIVE \| CVAR_LATCH | 1.0 | range 0.5-2.0; launch-only (bug-1181); menu label "(needs restart)" |
| r_upscaleFilter | CVAR_ARCHIVE | 1 | 0 bilinear blit, 1 FSR EASU (<1) / quality downsample (>1) |
| r_fsrSharpness | CVAR_ARCHIVE | -1 | stops; <0 off; while >=0, r_ppSharpen is skipped |
| r_renderScaleDebug | CVAR_TEMP | 0 | prints `^~^~^ RSCALE S=%dx%d D=%dx%d filter=%d rcas=%.2f` once per map |

### 3.8 Cost at 3440x1440 (estimates)

- **Scene pixels:**
  - 0.667: 2295x960 = 2.2 MP (0.44x)
  - 1.25: 6.2 MP (1.56x)
  - 1.5: 5160x2160 = 11.1 MP (2.25x)
  - 2.0: 6880x2880 = 19.8 MP (4x)
- **GPU time:** per-pixel work (lightall + shadow mask + about 10 full-screen post passes) scales
  roughly linearly.
  - 1.5 is estimated at 1.8-2.3x today's GPU frame time; 2.0 at 3-4x.
  - 0.667 saves roughly 45-50% of scene+post cost, minus EASU+RCAS (together about 0.5-1.0 ms
    at D).
  - Baseline GPU headroom is unknown: measure first (section 8).
- **VRAM:**
  - S-sized targets are about 24 B/px full-res (renderImage 16F 8, depth 4, screenScratch 4,
    hdrDepth 4, screenShadow 4) plus about 3 B/px half-res.
  - Today about 134 MB; at 1.5 about 300 MB; at 2.0 about 535 MB. Plus display targets of about
    60 MB when S != D. Comfortable on 16 GB.

### 3.9 Risks

- **HUD:** designed out (2D is D-only).
  - Test: the HUD rect must be pixel-identical between scale 1.0 and 1.5, and the bug-1144
    precondition (fullscreen menu over a live session) must show no ghost.
- **RDF_HUD / RDF_NOWORLDMODEL 3D** (armory preview, UI 3D widgets) must render into D with
  their own depth; that is what the renderFbo D24 renderbuffer is for.
- **Sky portal sub-views** inherit the scaled viewport: test a portal-sky map.
- **Cinematics** (RE_StretchRaw) bind renderFbo (D): unchanged.
- **Pixel-size assumptions not in the audit list** (flares, marks LOD): verify.
- **Texture shimmer** improves with SSAA; **mip LOD** automatically sharpens by log2(scale).
  No LOD-bias change is wanted.
- **Scale < 1** softens alpha-tested foliage before EASU; EASU cannot restore sub-pixel wires.
  FSR is a performance lever here, not a quality one; the user's GPU likely does not need it.
- **Latched plus vid_restart crash:** never apply from a menu.

**Effort (estimate):**
- FBO split + viewport scaling + audit + bilinear/quality downsample: M, 2-3 days including HUD,
  screenshot, cinematic and portal-sky verification.
- FSR 1 EASU+RCAS port: M, 1.5-2 days.
- The FBO split is also the prerequisite for section 4.

---

## 4. Feature 2 - anti-aliasing: alpha-to-coverage, then MSAA returns

### 4.1 Current state (verified)

- **The MSAA path exists and is off.**
  - `r_ext_framebuffer_multisample` (tr_init.c:1432, "0", ARCHIVE|LATCH) sizes the MS renderbuffers
    (tr_fbo.c:283-296).
  - `r_ext_multisample` (tr_init.c:1450-1451, "0", ARCHIVE|LATCH, range 0-4) is a separate cvar:
    it is read by `sdl/sdl_glimp.c:677` and sets SDL default-framebuffer samples (:814-815).
    sdl_glimp.c is compiled per renderer (sdl/CMakeLists.txt:12).
- **The MSAA resolves** are FastBlit GL_NEAREST at tr_backend.c:1622 (prepass depth) and
  :2156 (colour + depth); there is another at :2056 (swap).
- **Mitigation state:** bug-1298 mitigated by MSAA 0 (coop_defaults.cfg:140-142, bug-1997).
  bug-1300 (distance-fade alphaGen) was fixed AFTER bug-1298's bisect and is a confound: both
  produced "pale/white distant trees" on e2l1.

### 4.2 What actually produces white edges - four mechanisms, none yet separated

- **H1 - HDR resolve before tone.**
  - The colour resolve averages linear RGBA16F samples, then a compressive curve runs.
  - Example: a 50/50 silhouette pixel, bright background s=3.0, dark leaf s=0.08, avgLum 1.0
    (scratchpad bloomdomain.py):
    - **HZM grade path:** resolve-then-tone 0.764 vs tone-then-average 0.431, a
      **+85/255 bright rim**;
    - **Hable path:** +13/255.
  - Foliage against sky or sunlit ground is where the most such edges are. This matches "objects
    outlined in white" closely, especially if the 08-02 sandbox ran the grade path.
- **H4 - depth resolve with GL_NEAREST.**
  - The resolved depth at an edge pixel belongs to ONE sample, while the colour is blended.
  - Global fog then fogs the whole pixel at the background depth, or exempts it as sky
    (zw >= 0.9999999, bug-1296): a fog-coloured or unfogged rim.
  - SSAO, DoF and the shadow mask inherit the same mismatch.
- **H5 - default-framebuffer MSAA.**
  - With r_ext_multisample > 0 the backbuffer is multisampled, and the present blit
    `FBO_FastBlit(renderFbo -> 0)` (tr_backend.c:2057/2061) targets a multisampled draw
    framebuffer, which the GL spec makes GL_INVALID_OPERATION. Driver behaviour here is unknown.
  - The bug-1298 bisect toggled both cvars together (bug-1298 "restoring everything EXCEPT
    r_ext_framebuffer_multisample / r_ext_multisample").
- **H2 - alpha test under MSAA.**
  - `discard` is per fragment, so cutout edges get no AA: aliasing and shimmer.
  - This does not by itself make edges white. **Alpha-to-coverage fixes H2 only.**

### 4.3 Phase 0 - retest matrix (no code, do this first)

Launch-only (both cvars latched):
- Set `r_ext_multisample 0` always.
- Test `r_ext_framebuffer_multisample 4` and `8`.
- Per launch, toggle over rcon/console: `r_globalFog 0/1`, `r_ppSSAO` (latched, separate launch),
  `r_ppDoF` (latched), `r_ppTonemap 0/1` (live), `r_ppBloom 0/1` (live).
- Spots: e2l1 trees + tow plane, e2l2 foliage billboards.

Reading the result:
- Rim present at MSAA 4 with fog off and a tone-path flip changing its strength: **H1**.
- Rim only with fog on: **H4**.
- Clean at r_ext_multisample 0 (where the original bisect had both on): **H5** was the culprit.

### 4.4 Phase 1 - alpha-to-coverage (small)

- **State bit:** new `GLS_ALPHA_TO_COVERAGE 0x00000200`, a free bit between GLS_DEPTHMASK_TRUE
  0x100 and GLS_POLYMODE_LINE 0x1000 (tr_local.h:2987-2989). `GL_State` (tr_backend.c:106)
  enables and disables `GL_SAMPLE_ALPHA_TO_COVERAGE` on diff.
- **Selection** in `RB_IterateStagesGeneric` at the GL_State call (tr_shade.c:1700-1706). OR in
  the bit when ALL of these hold:
  - not `backEnd.projection2D` and not `backEnd.depthFill`;
  - the scene FBO is multisampled;
  - `r_alphaToCoverage`;
  - the stage has `GLS_ATEST_GE_80`, `GE_FOLIAGE1` or `GE_FOLIAGE2` (and the LT variants,
    inverted) and has no blend bits.
  - `GT_0` stays plain discard.
- **GLSL**, in both `generic_fp.glsl` and `lightall_fp.glsl`, as new `u_AlphaTest` modes 4 (GE)
  and 5 (LT):
  - `a = (alpha - 0.5) / max(fwidth(alpha), 1e-4) + 0.5`, clamped, then `if (a <= 0.0) discard`,
    and output `gl_FragColor.a = a`.
  - The fwidth sharpening keeps the coverage ramp about one pixel wide, so NVIDIA's A2C dither
    pattern is invisible.
  - The shadow-cascade depth pass keeps plain discard.
- **Cvar:** `r_alphaToCoverage`, CVAR_ARCHIVE, live, default 1. It does nothing without an MS
  scene FBO, so it is safe to default on.
- **Cost:** negligible (one fwidth per cutout fragment).
- **Effort:** S (0.5 day), testable only with Phase 2's MSAA on.

### 4.5 Phase 2 - MSAA returns

1. **Stop gl2 from requesting default-framebuffer samples.**
   - In gl2's tr_init.c, before GLimp_Init, force the SDL request to 0 samples when
     `glRefConfig.framebufferObject` is expected, keeping `r_ext_multisample` registered for
     gl1 and menu compatibility.
   - The menu pulldown (advanced_graphics.urc, bug-1123/1152) should set only
     `r_ext_framebuffer_multisample` under gl2 (Decision D7). This kills H5 permanently.
2. **Tone-weighted colour resolve (fixes H1).**
   - Attach the scene FBO's colour as a `GL_TEXTURE_2D_MULTISAMPLE` RGBA16F texture instead of a
     renderbuffer. FBO_CreateBuffer (tr_fbo.c:120-197) needs a texture variant.
   - New `glsl/msaa_resolve_fp.glsl` (`#version 150`, `sampler2DMS` + `texelFetch`, sample count
     as a uniform): `resolved = sum(c_i * w_i) / sum(w_i)` with `w_i = 1 / (1 + k * maxc(c_i))`
     and `k = invAvgLum` from calcLevels (grade path: k = 1).
   - Replaces the colour part of tr_backend.c:2156.
   - Fallback when !ARB_texture_multisample: today's FastBlit.
3. **Depth resolve to nearest-to-camera (fixes H4).**
   - Same MS texture approach for depth.
   - `glsl/msaa_depth_resolve_fp.glsl` writes `gl_FragDepth = min_i(texelFetch(depthMS, p, i).r)`
     into msaaResolveFbo's renderDepthImage.
   - Replaces the depth parts of tr_backend.c:1622 and :2156.
   - Edge pixels then carry foreground depth, so fog, SSAO and DoF treat silhouettes as the
     object (no background rim).
   - `r_msaaDepthResolve` (CVAR_ARCHIVE, live): 0 = driver NEAREST, 1 = min (default).
4. **Delete the swap-time resolve** (tr_backend.c:2053-2058): the display FBO is single-sampled
   (section 2).
5. **Sample count:** `r_ext_framebuffer_multisample` 2/4/8, still clamped to GL_MAX_SAMPLES
   (tr_fbo.c:271-281). Recommend 4 (Decision D4).

Interactions:
- A2C needs Phase 2.
- Soft particles under MSAA need one extra depth resolve before the sprite list (section 5).
- Bloom and DoF read the resolved colour.
- SSAO, fog and DoF read the min-resolved depth.
- MSAA combined with render scale > 1 is allowed but expensive; the menu should say so.

Cost at 3440x1440, 4x (estimates):
- VRAM: MS colour 16F about 158 MB, MS depth about 79 MB.
- GPU:
  - geometry edge shading is small (MSAA shades once per pixel);
  - the two custom resolves are 2 full-screen passes x 4 texelFetch, about 0.5-1.0 ms;
  - total about +10-25% GPU frame time at 4x, and about +20-40% at 8x.

Risks:
- The resolve shader needs `#version 150`; the header selection is at tr_glsl.c:294-301.
- `sampler2DMS` is not available through the stringified fallback on GLSL < 1.50, so gate it.
- `r_ext_framebuffer_multisample` is latched: launch-only.
- Min-depth resolve slightly biases DoF and fog toward the foreground at silhouettes (invisible
  in practice).
- The FBO_CreateBuffer texture variant touches the same allocation path that crashed on apply
  in bug-1124/1145 (menu vid_restart): still launch-only.

**Effort (estimate):**
- Phase 0: 0.5 day.
- Phase 2: M-L, 2-3 days (MS textures, two resolve shaders, SDL decoupling, menu label).
- If Phase 0 shows only H5, Phase 2 shrinks to the SDL decoupling plus A2C (about 1 day).

---

## 5. Feature 4 - soft particles

### 5.1 Current state

- Zero `softParticle` hits.
- **What counts as a particle:** emitter particles are RT_SPRITE refents; cgame submits them from
  cg_tempmodels.cpp, cg_testemitter.cpp and others (10 RT_SPRITE sites). The renderer stores them
  as SF_SPRITE (tr_scene.c:923) and queues them into the per-view sprite list (tr_main.c:3804-3853,
  sort by distance at :3799).
- **Where they draw:** in `RB_RenderSpriteSurfList` after all of the view's world surfaces.
- **The depth problem:** particles write no depth, and `tr.renderDepthImage` is the live depth
  attachment of the scene FBO. Sampling it while drawing is a feedback loop (the tr.globalFogFbo
  lesson, tr_fbo.c:320-326, bug-1132).
- **The existing snapshot recipe** is `FBO_BlitFromTexture(renderDepthImage -> hdrDepthFbo)`, used
  by SSAO and DoF (tr_postprocess.c:1217-1218, 1371-1372). Both re-snapshot at post time, so
  reusing `tr.hdrDepthImage` earlier in the frame cannot disturb them.

### 5.2 Design

1. **Snapshot** at the top of `RB_SpriteSurfs` (tr_backend.c:2678), after `backEnd.viewParms` is
   set. Run it when ALL of these hold:
   - `r_softParticles` is on;
   - `cmd->numDrawSurfs > 0`;
   - `!(rdflags & RDF_NOWORLDMODEL)`;
   - `tr.hdrDepthFbo` exists.

   The steps:
   - if MSAA: resolve depth, scene FBO to msaaResolveFbo (the section 4 resolver);
   - blit renderDepthImage into hdrDepthFbo;
   - restore the FBO and `SetViewportAndScissor()` (static in the same file, tr_backend.c:314);
   - set `backEnd.softDepthValid = qtrue`.

   `softDepthValid` is cleared at the top of every RB_DrawSurfs, mirroring `ssaoValid`
   (tr_backend.c:1583-1585, bug-1211). This runs per view, so the portal-sky view gets its own
   snapshot.
2. **Allocation:** add `r_softParticles` to the hdrDepthImage OR at tr_image.c:3572. Live config
   already allocates it because r_ppSSAO and r_ppDoF are 1.
3. **Uniforms:**
   - Reuse existing `UNIFORM_SCREENDEPTHMAP` ("u_ScreenDepthMap", tr_glsl.c:96) and
     `UNIFORM_INVTEXRES` (1/scene FBO size, so `uv = gl_FragCoord.xy * u_InvTexRes`; no viewport
     offset is needed because the snapshot covers the whole FBO).
   - Append ONE new vec4 LAST: `UNIFORM_SOFTPARTICLE` "u_SoftParticle" =
     (1/fadeDistance, projMat[10], projMat[14], mode).
     - Mode 0 = off.
     - Mode 1 = fade alpha (SRC_ALPHA blends).
     - Mode 2 = fade rgb (ONE,ONE additive).
     - Mode 3 = lerp rgb toward white (DST_COLOR,ZERO modulate).
4. **TMU:** bind the snapshot on a NEW unit 7 (`TB_SCREENDEPTH 7`).
   - The generic program leaves TB 5/6 free, but lightall uses all of 0-6 (shadow map 5,
     cubemap 6).
   - Add `#define NUM_TEXTURE_UNITS 8` for `glDsaState.textures[]` and its two loops
     (tr_dsa.c:27, 44, 52). Do NOT raise NUM_TEXTURE_BUNDLES: it sizes `shaderStage_t.bundle[]`
     and `tess texcoords[][SHADER_MAX_VERTEXES]` (tr_local.h:526, 3156).
   - Set the sampler int once per program at init: generic at tr_glsl.c:1135-1136, and the
     lightall permutations likewise.
5. **GLSL**, the same block in generic_fp.glsl (before ApplyGlobalFog at :82) and in
   lightall_fp.glsl (before its final output). It reuses the exact depth inversion from
   generic_fp.glsl:30-31:
   ```
   if (u_SoftParticle.w > 0.5) {
     float zs = texture2D(u_ScreenDepthMap, gl_FragCoord.xy * u_InvTexRes).r;
     float ds = u_SoftParticle.z / min(u_SoftParticle.y + (2.0 * zs - 1.0), -1e-6);
     float df = u_SoftParticle.z / min(u_SoftParticle.y + (2.0 * gl_FragCoord.z - 1.0), -1e-6);
     float k  = clamp((ds - df) * u_SoftParticle.x, 0.0, 1.0);
     // mode 1: alpha *= k;  mode 2: rgb *= k;  mode 3: rgb = mix(vec3(1.0), rgb, k);
   }
   ```
   The sky (zs = 1) gives ds = zFar, so there is no fade.
6. **CPU gate** (tr_shade.c, generic and lightall uniform setup). Set mode > 0 only when ALL of
   these hold, otherwise upload mode 0 every draw:
   - `backEnd.inSpriteList` is set (a new flag, raised around the loop in RB_RenderSpriteSurfList);
   - `backEnd.softDepthValid`;
   - `!depthRange` (excludes RF_DEPTHHACK muzzle flashes, tr_backend.c:2617);
   - `!backEnd.projection2D`;
   - the stage has blend bits and no `GLS_DEPTHMASK_TRUE`;
   - `!shader->noSoftParticles`.

   Uniform values persist per program, which is why the unconditional mode-0 upload matters.
7. **Escape hatch:** shader keyword `nosoftparticles`, parsed in tr_shader.c next to the
   bug-2186 `noGlobalFog` flag.
8. **v1 is sprites only.** World blended surfaces (water, glass, the bug-2514 shoreline work),
   SF_POLY marks and **the red bullet-hole decals are never touched**. Decals are SS_DECAL /
   SF_POLY in the main list, not sprites.

### 5.3 Cvars

| cvar | flags | default | notes |
|---|---|---|---|
| r_softParticles | CVAR_ARCHIVE \| CVAR_LATCH | 0 | latched because it widens the hdrDepthImage allocation gate (bug-1177 pattern) |
| r_softParticleDistance | CVAR_ARCHIVE | 24 | world units; live |
| r_softParticlesDebug | CVAR_TEMP | 0 | 1 = output k as greyscale on particles |

### 5.4 Interactions

- **bug-1296:** unchanged. Particles still write no depth and still escape the screen-space fog;
  soft particles neither fix nor worsen that.
- **Forward fog** (ApplyGlobalFog): runs after the fade.
- **SSAO/DoF:** they re-snapshot in post, so no conflict. DoF still blurs particles by the depth
  behind them (existing).
- **Characters:** in the non-MSAA path the snapshot is the live main-pass depth, so characters
  are included (unlike prepass depth, which excludes them per bug-1224). MSAA resolve includes
  them too.
- **HUD:** sprites are 3D-only, and projection2D is excluded.

### 5.5 Cost, risks, effort

- **Cost (estimate):** one R32F full-screen copy per view with sprites, about 0.1-0.3 ms at S.
  Add one MS depth resolve under MSAA. Per particle fragment, one fetch and a few ops: +10-20% of
  particle fill cost, which only matters in heavy smoke overdraw.
- **Risks:**
  - Ground-hugging smoke fades at its base if the distance is too large (tune 16-32).
  - Sparks and impact puffs against walls dim.
  - First-person smoke wisps (coop_smokeWhip) spawn in world space near the barrel, so check
    that they do not vanish against the viewmodel. The viewmodel is DEPTHHACK and drawn in the
    main pass; its depth is in the snapshot, so a wisp in front of the gun can fade wrongly. If
    it does, exclude by distance or by the wisp shader's `nosoftparticles`.
  - A lightall permutation missing the uniform resolves to -1 and silently does nothing (the
    bug-1148 class): verify with r_softParticlesDebug.
- **Effort (estimate):** M, 1.5-2.5 days, including the TMU-8 DSA change, both shaders and tuning.

---

## 6. Build order and dependencies

```
[0] .bak renderer_opengl2.dll                                   (P0, minutes)
[1] Bloom mode 1 (+ measure split, D/2 16F buffers)             independent of the FBO split
[2] AA Phase 0 retest (no code)                                 informs [6]; can run any time
[3] FBO split + r_renderScale + quality downsample              foundation for [4] [5] [6]
[4] FSR 1 EASU + RCAS (r_upscaleFilter / r_fsrSharpness)        needs [3]
[5] Soft particles                                              S-aware snapshot; needs [3] only for sizes
[6] AA Phase 1 A2C + Phase 2 MSAA resolves                      needs [3] (single-sampled display, S-sized MS targets)
```

Why render scale comes before MSAA, although the user listed AA second:
- Supersampling fixes edges, alpha-tested foliage and texture shimmer together.
- It is immune to H1 and H4, because the whole post chain runs on consistent per-pixel colour
  and depth before averaging.
- It deletes the swap-time MSAA path that [6] must otherwise work around.
- MSAA's value can be judged after SSAA is in hand. If SSAA 1.5 is adopted, MSAA may not be
  worth [6]'s cost (Decision D4).

Every item ships in renderer_opengl2.dll only. `build.ps1` deploys it to both `G:\mohaa-gl2\` and
the GOG root (CLAUDE.md, bug-1634/1796). The dedicated harness clients launch the **GOG root**
exe (launch_dedicated_2player.ps1:44-45), so both copies matter.

---

## 7. Cross-cutting risk table

| risk | where it bites | guard |
|---|---|---|
| blended surfaces write no depth (bug-1296) | soft particles, MSAA depth resolve, fog | v1 soft particles are sprites only; no change to depth writes; fog gap unchanged |
| alpha-tested foliage and fences | MSAA rims, SSAA cost, A2C | Phase 0 separates H1/H2/H4/H5; A2C only with MS; prepass exclusion untouched |
| red bullet-hole decals (leave alone) | soft particles, A2C | decals are SF_POLY/SS_DECAL, never sprites; A2C excludes blended stages; no rgbGen/mark code touched |
| r_ext_multisample vs FBO path (H5) | every MSAA test | gl2 requests 0 default-FB samples; retest with r_ext_multisample 0 |
| screenshots / levelshots / video | render scale | display FBO stays D; RB_ReadPixels and R_LevelShot unchanged; test dims = 3440x1440 |
| vid_restart / latched cvars (bug-1181/1145) | r_renderScale, MSAA, r_softParticles | CVAR_LATCH, launch-only, menu labels "(needs restart)", force via command line in harness |
| archive fossils (T7) | flipping any default | edit coop_defaults AND live omconfig with the game closed; record bug id beside any mitigation |
| drawn-over-HUD | all four | all work inside the RC_POSTPROCESS / scene commands; 2D untouched; HUD-rect diff test |
| uniform name/position (bug-1148, tr_local.h:939-955) | new uniforms | append last; verify each program resolves the location (debug views) |
| stringify quotes / backslashes | new .glsl, FSR port | no double quotes, no continuation macros; re-glob CMake |
| two world scenes per frame (bug-1226) | resample runs twice | resample per world RC_POSTPROCESS is idempotent; today MOHAA submits one |
| a second agent is compiling in .cmake | CMake re-glob for new .glsl | coordinate before re-configuring |

---

## 8. Test plan

### 8.1 Harness

Use `launch_dedicated_2player.ps1`: dedicated `omohaaded.exe` on 12203, gl2 clients forced with
`+set cl_renderer opengl2` (:155-159).

Additions to request, as harness changes in their own session:
1. A `-ClientCvars` parameter appended to Player1's command line, so latched cvars
   (r_renderScale, r_ext_framebuffer_multisample, r_softParticles, r_ppSSAO) are set at launch,
   never by vid_restart.
2. Player1 at `r_customwidth 3440 r_customheight 1440` (the defaults are 1280x720 and 960x540,
   which hide scale and FSR behaviour).
3. A per-spot client cfg (`+exec gl2shots.cfg`) using `setviewpos x y z yaw pitch` (needs
   `sv_cheats 1` via -ServerCvars), `cg_draw2d 0/1`, `wait 60`, then `screenshotJPEG` or `screenshot`.
   Record each spot's viewpos once in a manual session and commit the list beside the cfg.
   Coordinates are not in this note: they have to be captured in-game.

Standing rules:
- Isolated homepaths (bug-1134).
- Rotate qconsole.log per launch (T15).
- Confirm the gl2 banner and renderer dll timestamp in each log (TRAPS: gl2 is the renderer we
  ship).
- Wait about 20 s after coop join before capturing.
- Force `r_toneMap 1 cg_drawviewmodel 1` on the command line (bug-1148's archive poisoning).

### 8.2 Spots

| feature | map / spot | why |
|---|---|---|
| AA | e2l1 treeline + tow plane | bug-1296/1298/1300 site; alpha-tested foliage against sky |
| AA | e2l2 foliage billboards | bug-gl2-foliage-white; GE128 cutouts |
| AA | m4l3 wooden posts `jh_fence1` | bug-2549 thin geometry |
| AA | m1l1 wall trim spikes | bug-1164 shimmer |
| AA | m3l1a Omaha beach obstacles / wire (verify in game) | thin silhouettes, bright sky |
| bloom | m3l1a beach, bright sky | bug-1149's A/B map |
| bloom | e2l2 desert | bright scene, high avgLum |
| bloom | m1l1 night | must NOT glow the moonlit sky |
| bloom | explosion / mortar on m3l1a, fires on e2l1 | small very bright sources |
| soft particles | e2l1 fires: `models/emitters/firegood.tik`, `firefill.tik` (e2l1.scr:575-640) | sprites intersecting ground |
| soft particles | m6l2a fires: `firesmoke.tik`, `fireandsmoke.tik` (m6l2a.scr:3328-3330) | smoke against walls |
| soft particles | any smoke grenade + first-person firing | RF_DEPTHHACK exclusion, coop_smokeWhip wisps |
| render scale / FSR | all AA spots, plus a portal-sky map, a cinematic, the armory 3D preview, ESC menu over a live session | HUD / RDF_HUD / sky portal / bug-1144 paths |

### 8.3 What to measure

Screenshots are diffed with a small Python script under `hzm-mohaa-coop-mod/_research/`, not
eyeballed.
- **Every build:**
  - GLSL program count and zero "Could not load" / compile errors in qconsole.
  - Zero `R_CheckFBO` warnings.
  - `rcon meminfo` renderer zone stable across 3 map loads (bug-1146/1254).
- **Bloom:**
  - Mean luma and 99th-percentile luma, bloom on vs off.
  - **Selectivity** = mean(on-off) in a 16 px ring around pixels with off-luma > 200, divided
    by mean(on-off) over pixels with off-luma < 100. Expect about 1-2 for mode 0 on the Hable
    path (a veil) and much higher for mode 1.
  - The `^~^~^ BLOOM avgLum` line per spot, which fills in the section 1.2 table with real values.
  - Run both tone paths.
- **AA:**
  - **White-rim count:** pixels in a 2 px silhouette band (Sobel on the MSAA-0 capture) whose
    luma exceeds max(neighbour luma) + 24.
  - **Shimmer:** 8 captures stepping yaw by 0.25 deg via setviewpos; mean absolute frame-to-frame
    diff on the edge mask.
  - **Interior sharpness:** high-frequency energy inside flat textured regions, to catch FXAA or
    downsample softening.
  - Run Phase 0's matrix.
- **Render scale / FSR:**
  - Screenshot dims stay 3440x1440; the levelshot still writes 128x128.
  - HUD-rect diff between scales is about 0 (`cg_draw2d 1`).
  - The ESC menu over a live session shows no ghost (bug-1144 precondition).
  - The armory 3D preview is positioned and sized identically.
  - The same AA metrics at 0.667 (EASU) / 1.0 / 1.5 / 2.0, and with RCAS on/off. Verify
    r_ppSharpen is skipped while RCAS runs by diffing against RCAS-only.
- **Soft particles:**
  - On/off diff confined to particle masks.
  - A straight-edge detector (Hough / long horizontal gradient) along sprite-floor intersections;
    count drops with the feature on.
  - HUD-rect diff = 0.
  - A muzzle-flash crop while firing, diff about 0.
- **Performance:**
  - Player1 at 3440x1440, fixed viewpos, `com_maxfps 0 r_swapInterval 0 fps 1`
    (`fps` cvar, qcommon/common.c:1914).
  - Average frame time over 10 s for: baseline; bloom mode 1; scale 0.667 (FSR) / 1.25 / 1.5 / 2.0;
    MSAA 4 / 8; soft particles in the e2l1 fire scene.
  - Optional (Decision D6): a gated `r_hzmGpuTimers` using GL_ARB_timer_query (present) to print
    per-pass GPU ms, instead of inferring from fps.

---

## 9. Effort summary (estimates)

| item | effort |
|---|---|
| bloom mode 1 + measure split + D/2 16F + debug line | S-M, about 1 day (+0.25 radius stage) |
| AA Phase 0 retest | 0.5 day |
| FBO split + r_renderScale + quality downsample + audit + verification | M, 2-3 days |
| FSR 1 EASU + RCAS port, licence vendoring | M, 1.5-2 days |
| soft particles (sprites, both shaders, TMU 8, keyword) | M, 1.5-2.5 days |
| A2C | S, 0.5 day |
| MSAA Phase 2 (MS textures, two resolves, SDL decoupling, menu) | M-L, 2-3 days (about 1 day if Phase 0 shows only H5) |
| harness additions (-ClientCvars, spot cfgs, diff scripts) | S-M, about 1 day |

---

## 10. Decisions for the user

- **D1 - Canonical tone path.**
  - Today: live omconfig has r_ppTonemap 0 (Hable + autoexposure); coop_defaults seeds 1 (the
    HZM ACES grade).
  - If the grade path is canonical, current bloom is already gl1-parity and only needs value
    tuning; mode 1 then matters only for Hable users.
  - Either way this is a T7 fossil to resolve deliberately.
- **D2 - Should bloom's look change?**
  - Options: (a) keep parity (mode 0 + D1 = grade path); (b) exposure-aware highlights (mode 1,
    recommended); (c) also widen the radius (r_ppBloomRadius 2).
- **D3 - Render scale.**
  - Ship default 1.0 for everyone.
  - The user's own value: suggest trying 1.5 (or 1.25 if frame time matters).
  - Expose in the menu as a restart-required row?
- **D4 - MSAA.**
  - Sample count: 4 is recommended; 8 only if measured cheap.
  - Whether MSAA is still wanted once SSAA is adopted.
- **D5 - FSR.**
  - Keep r_upscaleFilter 1 as default.
  - Default RCAS sharpness at scale > 1: 0.5 stops, or off.
  - Should RCAS replace r_ppSharpen at scale 1.0 too?
- **D6 - Diagnostics.** Add the gated GL timer-query scaffolding, or measure by fps only.
- **D7 - r_ext_multisample.** gl2 ignores the default-framebuffer sample request, and the menu
  sets only r_ext_framebuffer_multisample.
- **D8 - Soft particles.** Default (0 until A/B) and fade distance (start 24 units).
- **D9 - FXAA under SSAA.** Keep it on, or auto-skip at scale >= 1.5.

---

## 11. Stale doc lines found during this pass (for the next docs session)

- **OPEN.md "Bloom is a no-op at the shipped threshold":**
  - the 0.664756 measurement predates the bug-1159 clamp;
  - the shipped threshold is now 0.349570;
  - the real problem is tone-path dependent (section 1.2).
- **FEATURES.md "Graphics & FX":** "The 3D->2D hook MUST live in Set2DWindow" is gl1-only. gl2
  relies on RC_POSTPROCESS command order (tr_draw.c:614-648 has no hook). It also still calls the
  gl2 migration "PLANNED" and lists seven post-FX as not ported (all are dispatched,
  tr_backend.c:2177-2289).
