// MOH Trilogy Coop - caustics on Omaha's submerged seabed [user 2026-09-06, bug-2507]
//
// WHAT THIS SURFACE IS. textures/mohtest/omaha_set4_covered is the SEABED under the open sea on m3l1a:
// 8 planar world faces (BSP surfaces 183, 619, 620, 624, 626, 628, 630, 632 - 40 verts; no terrain patch
// uses it): the flat floor at z -576 from y -2816 to -1792 across the full x -7872..8000, then six slopes
// rising to -504 at y -1024. Every vertex was checked against the drawn water directly above it (the
// $ocean patches at -520 seaward of y -2160; the waterline band -520 -> -499.8 -> -479 across
// y -2160 / -1472 / -768) and against the 13 CONTENTS_WATER brushes (tops -520 / -499.7 / -479, floor
// -704): the shallowest vertex is 17.4 u under the sheet (the -504 edge at y -1024, sheet -486.6 there)
// and every one is inside the water volume. NOTHING of this shader is above the water, so it may carry a
// caustic. (An earlier pass measured textures/test/omaha_pjspick3 instead, found it dry, and wrote
// nothing; the seabed was never that shader.)
//
// THE BASE BLOCK IS THE WINNING RETAIL COPY, VERBATIM. Three retail files define the name, all named
// scripts/mohtest.shader: main/Pak0.pk3:3165 (surfaceparm sand), mainta/pak1.pk3:3178 and
// maintt/pak1.pk3:3191 (both surfaceparm dirt). Pak order main < mainta < maintt and the LAST copy wins,
// so the maintt/pak1.pk3 block is the one restated below, dirt included. No other pak, loose file or
// coop .shader defines it (every pk3 under G:/mohaa-gl2/main*, the walked junctions, the homepath and
// hzm-mohaa-coop-mod/scripts grepped 2026-09-06), so this file is the only coop definition of the name
// and the coop pk3, mounting last, wins it. Define it nowhere else in the mod (T6).
//
// THE CAUSTIC is the recipe retail left commented out under textures/mohtest/fltwall1grim2rock in the
// same file (:37-48): blendfunc add, textures/misc_outside/caustic, tcMod scroll 0 .05, tcMod turb
// 0 .2 0 .1, tcMod scale 4 4, plus a second bundle at scale -3.55 with its own scroll and turb.
// Written here as ONE SINGLE-BUNDLE stage, on purpose:
//   * gl1 hands every bundle of a stage the SAME texMods array (renderergl1/tr_shader.c:3447), so the
//     second bundle's three tcMods overwrite the first's and both layers move identically - the
//     interference the two-bundle recipe wants never happens on gl1 (a fair guess at why retail
//     commented it out). gl2 fixed that for itself only (renderergl2/tr_shader.c:34-40).
//   * gl2 (the shipping renderer): this shader has no deformVertexes, so CollapseStagesToGLSL runs
//     (renderergl2/tr_shader.c:3216). A dual-bundle additive stage would survive there - the nextbundle
//     pass marks it ST_GLSL (:5238) and the GENERIC program draws both bundles with their own tcMods
//     (tr_shade.c:2076) - but the gl1 defect above stands, so single-bundle it is.
//   What gl2 does to THIS stage, read from the code: the nextbundle pass splits the retail base into an
//   opaque texture stage plus a DST_COLOR*ZERO lightmap filter stage placed in the first free slot,
//   i.e. AFTER the caustic (:5209-5225); CollapseStagesToGLSL folds base + lightmap into one lightall
//   draw, and because the caustic is a non-filter ST_COLORMAP stage that still sees that lightmap stage
//   ahead of it (:3352-3364, the test is on the DIFFUSE stage's blend bits), it too becomes a lightall
//   stage WITH the lightmap attached (CollapseStagesToLightall :3090-3094) and
//   LIGHTDEF_USE_TCGEN_AND_TCMOD (:3204); its additive stateBits are untouched. So on gl2 the caustic
//   draws additive as caustic * const * lightmap, the three tcMods applied in authored order by
//   lightall_vp.glsl ModTexCoords (:132-154: one 2x3 matrix plus a turb term per slot, built by
//   tr_shade.c ComputeTexMods :196), which composes scroll -> turb -> scale exactly as gl1's per-vertex
//   ComputeTexCoords does (renderergl1/tr_shade.c:1370). Base lightmapping is untouched - the base
//   collapses exactly as the retail block did before this file existed. Fog adjust cannot skip the
//   collapse: stage 0 is opaque (:4145). The one renderer difference: gl1 draws the caustic
//   un-lightmapped (its own additive stage over the multitextured base), gl2 lightmapped - it dims in
//   baked shadow on gl2; with r_mapOverBrightBits 2 the gl2 lightmap is stored x4 and mostly saturates,
//   so in lit sand the two renderers agree.
//
// BRIGHTNESS. textures/misc_outside/caustic.jpg (Pak2 256x256; the HD pak's 1024 copy measures the same)
// is mostly black: mean luminance 0.098, 95th percentile 0.34, thin lines to 1.0. Retail's recipe
// multiplied two copies, which squares that into sparse bright crossings; ONE copy added at identity
// would put +0.10 mean and +1.0 peaks on the sand and read as a white net. rgbGen const 0.35 gives
// +0.034 mean / +0.35 peak - visible moving ripple lines, never a burn-out - and the gl2 lightmap attach
// can only lower it. Raise toward 0.5 if the playtest wants more; do not go to identity.

textures/mohtest/omaha_set4_covered
{
	qer_keyword sand
	qer_keyword terrain
	surfaceparm dirt
	{
		map textures/mohtest/omaha_set4_covered.tga
	nextbundle
		map $lightmap
	}
	// [user 2026-09-06, bug-2507] the caustic: one single-bundle additive stage, see the header for why
	// not the two-bundle retail form and for what each renderer does with it.
	{
		// [user 2026-09-06, bug-2509] 'giant greenish/white squares under the water': the first cut used retail
		// caustic.jpg at full brightness with rgbGen const 0.35, and on gl2 it drew as bright bands. The
		// brightness now lives in a private 18% copy (docs/tools/gen_caustic.py) with rgbGen identity, so no
		// renderer path can ignore it; scale 8 8 = one caustic cell per 32 u on this 256 u/repeat seabed.
		map textures/coop_fx/caustic_dim.tga
		blendfunc add
		rgbGen identity
		tcMod scroll 0 .05
		tcMod turb 0 .2 0 .1
		tcMod scale 8 8
	}
}
