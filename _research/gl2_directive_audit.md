# gl2 Shader-Directive Gap Audit — Merged Report

**Date:** 2026-07-26
**Scope:** Every shader directive used by retail MOHAA content (main/mainta/maintt pk3 scan) audited across three slices: (1) rgbGen/alphaGen/alphaFunc/blendFunc/depthFunc/depthWrite family; (2) map/clampmap/animmap, tcGen, tcMod, nextbundle; (3) shader-level directives (cull, surfaceparm, deformVertexes, skyParms, sort, portal/portalsky, sprites, conditionals ifCvar/ifCvarnot, orphan stage keywords).
**Reference renderer:** `openmohaa-hzm/code/renderergl1` (correct MOHAA behavior). Target: `code/renderergl2`.
**Danger class:** directives gl2 accepts SILENTLY but handles differently from gl1 (parsed-but-ignored or wrong semantics) — the same class as the just-fixed ifCvar opaque-black-bushes bug.

---

## Priority fix queue (all categories merged, worst first)

| # | Item | Why it's this high |
|---|------|--------------------|
| 1 | `rgbGen lightingSpherical` (5048) + `lightingGrid` (344) + `rgbGen static` dlights (780) | Every animated TIKI model in the game renders fullbright. Single largest visual gap. One shared root fix. |
| 2 | `portalsky` (3 uses, every map affected) | The 3D portal-sky scene behind every skybox never renders — sky openings draw as default/white geometry. |
| 3 | `nextbundle` residuals (3392; ~360 stages truly broken) | Dual-texture effects lose their 2nd layer; tcMods after nextbundle misapplied to base layer; 2 lightmap-first windows draw as raw lightmap. |
| 4 | `deformVertexes flap` (328) | All waving flags/banners/canvas frozen rigid, zero warning. |
| 5 | stage-level `nopicmip` (50) — **shader-killer** | Whole shader dies to default. Kills the animated ocean/shoreline (deepbluesea*) on the D-Day and North Africa beaches. |
| 6 | `surfaceparm nodraw` (143) | Nodraw faces render — tree-shadow silhouette quads visible on the ground outdoors. |
| 7 | alphaGen distance/angle family: `distFade` 557, `oneMinusTikiDistFade` 57, `oneMinusDistFade` 34, `dot` 35, `oneMinusDot` 13, `tCoord` 30, `sCoord` 8, `heightFade` 6 + `rgbGen dot` 8 | All CPU per-vertex alpha/color generators missing — opaque windows, hard-pop tree LODs, frozen gradients. One family fix. |
| 8 | `surfaceparm fence` (491) | Fences stay two-sided → z-fighting alpha edges gl1 deliberately prevents. |
| 9 | `tcmod rotate` extra args (134 of 264) + `tcmod parallax` (52) + `tcmod wavetrant` (36) + `tcmod scroll fromEntity` (5) | Clock hands wrong, jeep wheels static, weather overlays glued, waterline frozen. |
| 10 | `noMerge` (212) + `animmapphase` (17) + `animmaponce` (2) | Flipbook effects play mid-sequence, in lockstep, and loop when they should hold. |
| 11 | `tcgen environmentmodel` collapse-path residual (119) | One-line fix: env-map sweep lost again on the lightall path only. |
| 12 | `nofog` stage-level (37) | Fog-exempt beams/searchlights get fogged; needs design (gl2 fog is a post pass). |

---

## 1. SILENT GAPS (parsed-but-ignored / semantics-differ / absent-silent)

Sorted by severity, then usage count. These produce wrong pixels with **no console warning** (exceptions footnoted).

### HIGH

| Directive | Uses | Class | Symptom | Fix approach |
|---|---|---|---|---|
| `rgbGen lightingSpherical` | 5048 | parsed-but-ignored | Every animated TIKI model (characters, weapons, vehicles, hands, props) renders fullbright/unlit; no ambient/directional shading, no dlight response. Parse: gl2 tr_shader.c:1322-1325; no CGEN case in ComputeShaderColors (tr_shade.c:463-567); tr_sphere_shade.cpp ported (RB_Sphere_SetupEntity :1131) but ZERO callers in gl2 tr_backend.c; RB_SkelMesh (tr_model.cpp:922-1356) never fills tess.color. | Wire RB_Sphere_SetupEntity / RB_Grid_SetupEntity into gl2 tr_backend.c (mirror gl1 tr_backend.c:843-882), make RB_SkelMesh fill tess.color, add CGEN_LIGHTING_SPHERICAL to the CPU color path (port gl1 tr_shade.c:914-1010). |
| `nextbundle` | 3392 | semantics-differ | ~3030 tex+`$lightmap` stages are rescued by the split+collapse path (CreateMultistageFromBundle tr_shader.c:4781-4813). Broken: (a) ~356-370 dual-texture non-lightmap stages (tracers, snow, dust cones, waterfalls, window glass combos) silently lose the 2nd texture — generic_fp.glsl samples only u_DiffuseMap; (b) ~260 stages with tcMods AFTER nextbundle misapply them to bundle[0] (ParseTexMod hardwires bundle[0], tr_shader.c:417-429); (c) blended tex+lightmap stages skip collapse and the split lightmap pass drops alpha-test bits → dark rectangles around bullet-hole decals / window borders; (d) 2 lightmap-FIRST stages (mohcommon window32_lightmapalpha / bordered_window_glass) render only the lightmap — gl1's bundle swap (gl1 tr_shader.c:3175-3182) not ported. | Pass cntBundle through gl2 ParseTexMod (fixes b); extend CreateMultistageFromBundle to non-lightmap bundle[1] + add the lightmap-first bundle swap (fixes a,d); keep atest bits on the split pass (fixes c). Long-term: 2-texture generic GLSL variant. |
| `rgbGen lightingGrid` | 344 | parsed-but-ignored | Grid-lit model stages render fullbright white — same unlit-model class. Parse gl2 tr_shader.c:1318-1321; no apply case; RB_Grid_SetupEntity declared (tr_sphere_shade.cpp:1145) never called. | Same backend wiring as lightingSpherical + CGEN_LIGHTING_GRID case (port gl1 RB_CalcLightGridColor, gl1 tr_shade.c:911-912). |
| `deformVertexes flap` | 328 | parsed-but-ignored | All waving cloth frozen rigid: nazi banners, kriegsmarine flags (flags.shader), tents/canvas. Parsed (gl2 tr_shader.c:2155-2210) but no DEFORM_FLAP_S/T case in RB_DeformTessGeometry (tr_shade_calc.c:556-601), no default warning. | Port gl1 flap cases (gl1 tr_shade_calc.c:936-941) into gl2 RB_DeformTessGeometry; ShaderRequiresCPUDeforms already routes flap to CPU path. |
| `surfaceparm nodraw` | 143 | semantics-differ | Nodraw BSP faces render: treeshadows.shader draws dark silhouette quads on the ground; zero-stage utility shaders (textures/common/modelshader) fail parse → default checkerboard. `nodraw` IS in gl2 infoParms (tr_shader.c:2365) but neither apply path exists. | In gl2 ParseFace skip SURF_NODRAW faces as SF_SKIP (port gl1 tr_bsp.c:626-630); add SURF_NODRAW exemption to the zero-stage bail (gl2 tr_shader.c:2749, mirror gl1:2563). |
| `portalsky` * | 3 | absent-warns (parse) + absent-silent (apply) | textures/common/skyportal rejected → default shader; and even a flagged surface would never render — R_Sky_AddSurf (tr_sky_portal.cpp:67) has zero callers in gl2. The 3D skybox room used by virtually every map never draws. | Add portalsky branch (sort=SS_PORTALSKY + isPortalSky field on shader_t) and route isPortalSky surfaces to R_Sky_AddSurf from the world-surface path (mirror gl1 tr_world.c:462-466). |

\* Listed here despite the parse warning because the apply-side machinery gap is fully silent and severity is map-wide.

### MEDIUM

| Directive | Uses | Class | Symptom | Fix approach |
|---|---|---|---|---|
| `rgbGen static` (dlight part) | 780 | semantics-differ | Baked lighting correct (CGEN_STATIC case exists, RB_StaticMesh fills colors) but static props don't react to dynamic lights — muzzle flashes/explosions no longer illuminate nearby fences/rubble/furniture. RB_Static_BuildDLights exists (tr_staticmodels.cpp:469) with NO callers; gl1 overbrightShift clamp (gl1 tr_shade.c:970-986) unported. | Call RB_Static_BuildDLights from gl2 backend (mirror gl1 tr_backend.c:835-837); port the overbrightShift/clamp block. |
| `alphaGen distFade` | 557 | parsed-but-ignored | Distance-faded detail stages (window reflections, grass overlays) fully opaque at every distance; static models pop at cull radius instead of fading. Only the whole-surface cull survives (tr_staticmodels.cpp:399-406). | Add AGEN_DIST_FADE per-vertex alpha ramp on the CPU color path (port gl1 tr_shade.c:1167-1221). |
| `surfaceparm fence` | 491 | absent-silent | gl1 downgrades `cull twosided` → front-sided for CONTENTS_FENCE shaders (gl1 tr_shader.c:2571-2573); gl2 lacks the infoParm entirely → coincident fence faces double-draw and z-fight alpha edges. | Add `fence`/CONTENTS_FENCE to gl2 infoParms + port the cull-downgrade end rule in ParseShader. |
| `tcmod rotate` (extra args) | 264 (134 affected) | semantics-differ | gl2 parses only speed (tr_shader.c:617-627); rotateStart/rotateCoef/fromEntity silently discarded. Clock hands (clock.shader) start at wrong angle; jeep wheels (`tcmod rotate fromEntity 0 2`) don't rotate at all (atof("fromEntity")=0). | Parse start/coef/fromEntity and port gl1 apply (gl1 tr_shade_calc.c:1599-1631, entity shader_data[0] for fromEntity). |
| `noMerge` | 212 | parsed-but-ignored | Explicit `// FIXME: unimplemented` (gl2 tr_shader.c:2695-2699). Effect/sprite shaders merge across surfaces and animate on global shader time: animMap explosions/flames start mid-sequence and play in lockstep. | Store the flag; force batch break between surfaces sharing the shader (gl1 tr_backend.c:745-751) and rebase shaderTime per batch (gl1 tr_shade.c:1593-1596). |
| `tcgen environmentmodel` (residual) | 119 | semantics-differ | HZM re-port fix verified formula-exact on the generic path, BUT CollapseStagesToGLSL's tcgen flag (tr_shader.c:3238-3244) omits TCGEN_ENVIRONMENT_MAPPED2 → collapsed lightall stages with zero tcMods never set USE_TCGEN → static env texture again on scope lenses/glasses/leather with opaque stage0. | One-liner: add TCGEN_ENVIRONMENT_MAPPED2 to the condition at gl2 tr_shader.c:3239. |
| `alphaGen oneMinusTikiDistFade` | 57 | parsed-but-ignored | SH/BT tree far-LOD billboards hard-pop to full opacity instead of cross-fading; double-render over the 3D tree in the transition band. | Port gl1 per-model constant-alpha ramp (gl1 tr_shade.c:1277-1349) — same family as distFade. |
| `nofog` (stage-level) | 37 | parsed-but-ignored | `// FIXME: unimplemented` (gl2 tr_shader.c:1836-1840). Searchlight beams, tracers, portal-sky ground get fogged on foggy maps instead of staying bright. gl2 global fog is a fullscreen post pass (RB_GlobalFog, tr_postprocess.c:106-131) — cannot honor per-stage exemptions as-is. | Needs design: stencil-mask fog-exempt surfaces during RB_GlobalFog, or redraw exempt stages after the fog pass. |
| `alphaGen dot` | 35 | parsed-but-ignored | Angle-dependent glass/reflection overlays at constant full alpha — windows uniformly milky instead of sheening by view angle. | Add AGEN_DOT case (port RB_CalcAlphaFromDot, gl1 tr_shade.c:1125-1127). |
| `alphaGen oneMinusDistFade` | 34 | parsed-but-ignored | Far-LOD stand-ins meant to be invisible up close render opaque at all distances — doubled foliage close-up. | Same distFade family port (gl1 tr_shade.c:1222-1276). |
| `alphaGen tCoord` | 30 | parsed-but-ignored | Texcoord-ramped translucency (waterfall gradients) becomes hard-edged opaque sheets. | Port RB_CalcAlphaFromTexCoords (gl1 tr_shade.c:1155-1166). |
| `alphaGen oneMinusDot` | 13 | parsed-but-ignored | Inverse angle-fade overlays stuck at alpha 1. | Port RB_CalcAlphaFromOneMinusDot (gl1 tr_shade.c:1128-1130). |
| `alphaGen sCoord` | 8 | parsed-but-ignored | S-axis alpha gradients lose their fade. | Same RB_CalcAlphaFromTexCoords port, S axis. |
| `rgbGen dot` | 8 | parsed-but-ignored | Opel truck window stages lose angle-based darkening — glass renders bright white. | Add CGEN_DOT case (port RB_CalcRGBFromDot, gl1 tr_shade.c:1042-1044). |

### LOW

| Directive | Uses | Class | Symptom | Fix approach |
|---|---|---|---|---|
| `nomipmaps` (shader-level) | 2784 | semantics-differ | gl2 sets noPicMip too (ioq3 behavior, tr_shader.c:2580-2584) — at r_picmip>0 gl2 keeps full res where gl1 downsamples. Sharper, not broken; invisible at default picmip 0. | Optional: stop setting noPicMip alongside noMipMaps for strict parity. |
| `force32bit` | 1652 | parsed-but-ignored | Field stored (tr_local.h:624), zero readers. Only manifests at r_texturebits 16: menu/HUD art would band/dither. | Honor shader.force32bit at stage/sky image loads (force 32-bit upload as gl1 does). |
| `tcmod scroll` (fromEntity) | 498 (5 affected) | semantics-differ | jeep.shader tire treads: gl2 reads 0 → fully static. (gl1's own apply misses the magic too — shimmer — both wrong vs retail, differently.) | Support the fromEntity magic reading entity shader_data; fix gl1's apply too if touching. |
| `alphaFunc GT0` | 73 | semantics-differ | gl1 tests GL_GREATER 0.05 (tr_backend.c:414-417); gl2 GLSL discards only alpha==0.0 → faint 1-2px halo fringes on alpha-tested edges. | Change generic_fp.glsl U_ATEST GT_0 threshold from 0.0 to 0.05. |
| `nodepthtest` (depthmask interaction) | 24 (2 affected) | semantics-differ | gl1 force-clears depth writes when depth test disabled (gl1 tr_shader.c:1773-1775); gl2 lacks the clamp — unblended nodepthtest stage (gfx/2d/backtile) writes garbage depth. | After gl2 stateBits assembly (tr_shader.c:1988-1991), clear GLS_DEPTHMASK_TRUE when GLS_DEPTHTEST_DISABLE is set. |
| `animmapphase` | 17 | parsed-but-ignored | Phase stored (tr_shader.c:1786-1806) but R_BindAnimatedImageToTMU computes index from shaderTime*speed only (tr_shade.c:88). Torch/flame flipbooks play in lockstep instead of offset. | Add imageAnimationPhase into the index math ((time+phase)*speed, as gl1 tr_shade.c:229). |
| `rgbGen vertex/fromclient` on TIKI | 1980 (rare affected) | semantics-differ | World/BSP correct; RB_SkelMesh never writes tess.color so an animated-model vertex-color stage reads stale colors from the previous batch (gl1 has a fallback, gl1 tr_shade.c:828-833). | Covered by the lightingSpherical root fix (fill tess.color in RB_SkelMesh). |
| `alphaGen heightFade` | 6 | parsed-but-ignored | Vertical fade gradients (fog/haze skirts) uniform. | Port RB_CalcAlphaFromHeightFade (gl1 tr_shade.c:1357-1358). |
| `nocolorwrite` | 6 | parsed-but-ignored | Dead store (colorBits set, omitted from stateBits at tr_shader.c:1988-1991; also uninitialized at :655). **Parity today** — gl1's GL_State never implements GLS_COLOR_NOMASK either. All 6 uses are r_blendtrees=1 foliage prime stages (dropped by ifCvar at default). | Future-proof: OR colorBits into stateBits + add glColorMask handling for GLS_COLOR_NOMASK in both GL_States. |
| `deformVertexes projectionshadow` | 3 | semantics-differ (inverted) | gl2 ACTIVELY applies RB_ProjectionShadowDeform where gl1 warns and ignores — a surface using it flattens to the ground plane in gl2 only. common.shader utility defs, rarely bound. | For parity: drop the DEFORM_PROJECTION_SHADOW case or gate it with a warning. |
| `animmaponce` | 2 | parsed-but-ignored | BUNDLE_ANIMATE_ONCE set (tr_shader.c:1782-1784) but bind always wraps (tr_shade.c:96-99) — one-shot flipbooks loop forever. | Test bundle->flags in R_BindAnimatedImageToTMU and clamp at last frame (gl1 tr_shade.c:235-239). |
| `alphaFunc GE_FOLIAGE1-4` | 6 | present-ok (approx) | HZM re-port maps FOLIAGE atest to the 0.5 GLSL test vs gl1's r_alpha_foliage1 0.75 — marginally fatter leaf silhouettes, only with r_blendtrees 1. | Optional: pass foliage threshold as uniform. |

### Severity NONE (silent-class, documented, no action needed)

| Directive | Uses | Class | Note |
|---|---|---|---|
| `surfaceparm` material 15-pack (paper/wood/metal/rock/dirt/grill/grass/mud/puddle/glass/gravel/sand/foliage/snow/carpet) | 6037 | absent-silent | SURF_* bits are write-only even in gl1 (footsteps read BSP flags game-side). Restore table rows for parity/safety only. |
| `surfaceparm weaponclip/vehicleclip` | 55 | absent-silent | Contents bits never read by either renderer. |
| `surfaceparm castshadow` | 14 | absent-silent | Write-only in gl1 too (compiler concept). |
| `clampmapy` (and clampmapx) | 5 | semantics-differ | gl2 clamps BOTH axes (open FIXME, tr_shader.c:761-772). All 5 uses in dev/test shaders (mohtest/test.shader). |
| `detail` (stage keyword) | 3 | semantics-differ (inverted) | gl1 has NO stage-level detail — kills the shader; gl2 accepts it. Only unused mohtest/brick.shader. gl2 renders MORE, not less. |
| `blendFunc gl_dst_alpha gl_zero` | 2 | semantics-differ | r_ignoreDstAlpha defaults 1 in gl2 (substitutes ONE/ZERO); only user is the unused mohtest/brick.shader. |
| `clampTime` | 0 | latent code defect | gl2's force32bit branch is a bare `if` breaking the else-if chain (tr_shader.c:2733): a future clampTime user's value token would kill the whole shader. Fix while in file: make force32bit `else if` / add `continue` to clampTime (tr_shader.c:2563-2568). |

---

## 2. NOISY-BUT-KNOWN (absent-warns — console warns, but two of these are shader-killers)

Sorted by severity.

| Directive | Uses | Severity | Symptom | Fix approach |
|---|---|---|---|---|
| `nopicmip` (stage-level) | 50 | **HIGH** | **Shader-killer**: unknown-parameter branch (tr_shader.c:1925-1929) fails the WHOLE shader → default. Kills deepbluesea / deepbluesea_runup / deepbluesea_shoreline / northafrika_shoreline (misc_outside.shader) — the animated ocean on D-Day and North Africa beaches renders as a flat opaque texture. | Add stage-level nopicmip branch setting per-stage noPicMip (port gl1 tr_shader.c:875-878). |
| `tcmod parallax` | 52 | medium | View-position-driven overlays (snow/cloud haze, central_europe_winter, norway, environmentalfx) stop sliding with the camera — weather glued to surfaces. | Add TMOD_PARALLAX parse + vieworg-offset apply (port gl1 tr_shader.c:788-806, tr_shade_calc.c:1472-1483). |
| `tcmod wavetrant` | 36 | medium | misc_outside shoreline/water-edge bobbing frozen — waterline foam static. | Add TMOD_WAVETRANT (T-translate by waveform; port gl1 tr_shade_calc.c:171-180; sister wavetrans has 0 retail uses). |
| `nomipmaps` (stage-level) | 1 | medium | **Shader-killer** — same else-branch. Kills US_V_Chains (maintt Tanks.shader): Sherman Crab mine-flail chains render as default texture. | Add stage-level nomipmaps branch (port gl1 tr_shader.c:869-873). Do together with stage nopicmip; stage-level `force32bit` falls in the same killer branch. |
| `tcmod offset` | 4 | none | All 4 retail uses are whole-tile shifts on GL_REPEAT — visually a no-op even in gl1. | Optional TMOD_OFFSET port for completeness. |
| `tcmod bulge` | 4 | none | gl1's own apply is dead code (computes offset, never writes it) — gl2's ignore is pixel-identical. | None needed. |
| `depthFunc always` | 1 | none | gl1 warns identically and keeps LEQUAL — behavior parity (3dk.shader test asset). | None needed. |

---

## 3. CONFIRMED PARITY (same / present-ok) — coverage proof

### Stage color/alpha generators
`rgbGen identity` (7554), `identityLighting` (9), `vertex`/`fromclient` (1980 — world path exact; TIKI caveat covered in §1), `exactVertex` (8), `const`/`constant` (142), `global` (521 — HZM re-port Fix 2 verified), `entity`/`fromentity` (20), `wave sin` (258); `alphaGen vertex` (1388), `oneMinusVertex`/`oneMinusFromClient` (323), `const`/`constant` (222 — parse correctly targets AGEN_CONST; unused AGEN_CONSTANT enum still in tr_local.h:302), `global` (3 — HZM fix, coop_xpbar.shader depends on it), `entity`/`fromentity` (43), `fromclient` (8), `wave sin/triangle/sawtooth` (21), `identity` (3), `lightingSpecular` (11 — GLSL port with hardcoded default origin matches all 11 no-arg retail uses; custom specOrigin would be ignored, but gl1 ignores its alphaMax arg too).

### Alpha test / blend / depth
`alphaFunc GE128` (1929 — identical 0.5 GEQUAL), `LT128` (3); `blendFunc` all explicit GL_* pairs (5310) and `add/filter/blend/alphaadd` (2959 — MOHAA alphaadd present); `depthFunc equal` (3404), `lequal` (8); `depthWrite`/`depthmask`/`nodepthwrite` (5249 — implicit blend clear matches; nodepthtest clamp gap in §1).

### Maps / texcoords
`map` (15126 incl. specials), `map $lightmap` (6696 — TCGEN_BAD fixup present), `map $whiteimage` (151), `clampmap` (3437), `animmap` (122 — same 64-frame cap and index math); `tcgen environment` (283 — GLSL algebraically identical, collapse flag includes it), `tcgen base/texture` (8); `tcmod scale` (418), `turb` (64 — same spatial frequency/phase in GLSL), `transform` (30), `stretch` (3).

### Conditionals (the just-fixed bug class)
`ifCvar r_blendtrees` (6) / `ifCvarNot r_blendtrees` (12) — parse+evaluate byte-identical, HZM apply block matches gl1, dropped-slot reuse + inactive-stage compaction prevent stranding. Residual: with r_blendtrees **1**, gl1's break-on-first-inactive quirk renders ZERO stages while gl2 renders the authored blend stages — gl2 diverges only in non-default config and toward authored intent.

### Shader-level
`cull` all forms (6193 — token-for-token incl. MOHAA 'backsided' aliases; 'cull front' warns in both), `skyParms` (103 — retail skies unaffected by gl1's innerbox quirk), `sort` named/numeric (124), `portal` (9 — full mirror machinery), `spriteGen`/`spriteScale` (758 — RB_DrawSprite wired), `polygonOffset` (1143), `nopicmip` shader-level (2851), `tessSize` (20 — ignored in both), `deformVertexes wave/autosprite/autosprite2/bulge/move` (349 — CPU cases + GPU accel with CPU fallback), `surfaceparm sky/nomarks/noimpact` (726 — dlight-skip and mark-rejection consumed), shared surfaceparm pack water/playerclip/monsterclip/nonsolid/origin/trans/detail/structural/areaportal/ladder/nodamage/hint/alphashadow/nolightmap (4806), `qer_*` (29257 — prefix-skipped), `q3map_*` (83), `light` (1).

### Identical-failure parity (both renderers reject → default shader; retail data bugs, no gl2 regression)
Stage-level `surfaceparm nolightmap` (18, 1_1_groundPortal), `alpahfunc` typo (4, effects.shader seagull), unknown-keyword pack fullbright/bare-nodraw/subdivisions/surfacecolor/surfacelight (28), surfaceparm unknown-in-both pack stone/plaster/solid/translucent/shootonly/obscuring/patch (752 — silently dropped by both).

### Cross-slice conflict resolved
Slice 3 marked `animMapPhase`/`animMapOnce` present-ok on **parse-side** evidence only; slice 2 traced the **bind path** (R_BindAnimatedImageToTMU) and found phase/once flags never consumed. Bind-path evidence wins: both are parsed-but-ignored (listed in §1 LOW). This is exactly the audit's danger class — "parsed" is not "applied".

---

## 4. VERDICT

**After fixing the silent gaps (§1 high+medium+low) plus the four real absent-warns items (§2: stage nopicmip/nomipmaps, tcmod parallax, wavetrant), the gl2 shader-directive surface reaches functional parity with gl1 for all retail-used directives.** The census covered every directive family in the retail corpus; nothing else surfaced.

Three structural fixes carry most of the weight (design work, not transcription):
1. **Model vertex-color pipeline** — RB_SkelMesh filling tess.color + sphere/grid backend wiring: closes lightingSpherical, lightingGrid, static-dlights, and the TIKI vertex-color caveat at once.
2. **Bundle-aware stage handling** — ParseTexMod bundle index + generalized CreateMultistageFromBundle (or a 2-texture generic GLSL): closes all four nextbundle sub-gaps.
3. **Per-vertex CPU color/alpha generators** — one family port (distFade x3, dot x3, s/tCoord, heightFade, rgbGen dot) into the gl2 CPU color path.

Remaining divergences after the fix pass, all enumerated and acceptable:
- **Non-default cvar configs only:** r_texturebits 16 (force32bit), r_picmip>0 (nomipmaps sharper), r_blendtrees 1 (FOLIAGE 0.5-vs-0.75 threshold, nocolorwrite double-draw — gl1 equally wrong, ifCvar zero-stage quirk — gl2 closer to intent), r_ignoreDstAlpha vs future dst-alpha content.
- **Dev/test-only content:** clampmapx/y, detail stage, dst-alpha blend, depthFunc always.
- **Latent defects to fix opportunistically while in tr_shader.c:** clampTime else-if chain break, unused AGEN_CONSTANT enum, lightingSpecular custom specOrigin ignored, Q3-only infoParm rows aliasing MOHAA bit values (flesh/pointlight/metalsteps/lightfilter/dust — inert, no retail user).
- **`nofog` stage-level** is the one item with no clean transcription path (gl2 fog = post pass); parity requires a stencil/redraw design decision.

**Coverage caveats:** this audit proves directive parse/apply parity, not whole-pipeline numeric equivalence — overbright handling, fog math, dlight falloff curves, and CollapseStagesToGLSL pass-selection heuristics were verified only where a directive forced it. Zero-usage directives were skipped by design (`videomap` — gl2 implements it anyway; `tcmod wavetrans/macro`, `tcgen sunreflection/vector/lightmap`, bare `if/endif` — no retail uses, no gl1 support for if/endif either). Final sign-off should be a visual A/B (gl1 vs gl2) on: a character model in a dark interior (spherical), the m3l1a beach ocean (nopicmip killer), a flag map (flap), a foggy map with searchlights (nofog), and a fence-heavy map (fence cull).
