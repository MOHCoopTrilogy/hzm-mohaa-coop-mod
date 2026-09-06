// [coop 2026-09-05] THE OPEN OCEAN STOPPED SWALLOWING THE LANDING CRAFT.
//
// USER: "it looks like there are several higgins boats that are underwater following us in."
//
// This is a WHOLE-BODY RESTATEMENT of textures/misc_outside/deepbluesea (main/Pak0.pk3,
// scripts/misc_outside.shader). Two edits differ from retail, both marked below: the flap max
// (bug-2478) and the first stage's blendFunc blend + depthwrite (bug-2507, the lid from below).
// Two stages, well under the 8-stage cap - unlike zz_coop_shoreline.shader, which is at 8.
//
// WHAT WAS WRONG, as arithmetic rather than as taste:
//
//   deformVertexes flap t 10 sin 0 10 0 .10 0 10
//
// parses (renderergl1/tr_shader.c:1903-1959) to coord=t, div=10 (computed into deformationSpread and
// then never used by either renderer), then ParseWaveForm -> func=sin base=0 amplitude=10 phase=0
// frequency=0.10, then bulgeWidth(min)=0 bulgeHeight(max)=10.
//
// RB_CalcFlapVertexes then computes, per vertex:
//   scale       = base + sin(...)*amplitude      = +/-10        (TIME ONLY - global, no per-vertex phase)
//   vertexScale = (max-min)*rawT + min           = 10 * rawT
//   offset      = scale * vertexScale * normal
// gl2 clamps vertexScale to 8 (renderergl2/tr_shade_calc.c, "HZM gl2 clamp"); gl1 does not clamp at
// all (renderergl1/tr_shade_calc.c:306-389).
//
// So the drawn sea plane on m3l1a heaves +/-80 units on gl2 and up to +/-100 on gl1, on a 10.0 s
// cycle, with EVERY vertex moving in the same instant. Measured from maps/m3l1a.bsp: surface 1643 is
// this shader, a 15x15 patch, all 225 control points at z -520.0, rawT = 0.0 at y -2160 (the shore
// seam) ramping to 1.0 at y -8000, so:
//     y -3200 -> +/-17.8   y -4000 -> +/-31.5   y -5600 -> +/-58.9
//     y -6400 -> +/-72.6   y <= -6832 -> +/-80 (gl2 clamp) / up to +/-100 (gl1)
//
// A Higgins hull is 141.8 units tall (higginslite_soldiers.tik, skc frame bounds z -2.4688..270.2508
// through scale 0.52). The retail boats ride at z -563.72 (BSP -543.72 plus the movedown 20 that
// maps/m3l1a.scr:736 applies to every one of them) and the coop-placed boats at z -544. At the crest
// of the cycle the sea reaches z -440 out where the fleet forms up, which puts 89% of a retail hull
// and 68% of a coop-placed one under the drawn surface. That is the "underwater boats": the boats
// are not too low, the sea is 80 units too high for half of every ten seconds.
//
// THE FIX IS THE LAST TOKEN: max 10 -> 1.
//   travel becomes +/- amplitude*max*rawT = +/-10 at the far edge, ~0 at the shore seam.
//   +/-10 is the same order as the boats' own bob (higgins_wave_motions steps the hull down 6/down 3/
//   up 3/up 6/up 3 per cycle, m3l1a.scr:742-830), so a boat now rides the swell instead of drowning
//   in it, and it is continuous with the shoreline band at the y -2160 seam where both go to zero.
//   It also makes gl1 and gl2 agree: at max 1 the gl2 clamp of 8 is never reached, so both renderers
//   compute the same +/-10 and the sea stops looking like a different ocean per renderer.
//
// WHY NOT ZERO. The user asked for "waves and physical white waves that crest" on 2026-09-04 and the
// travelling crest in zz_coop_shoreline.shader is built around a living surface. Killing the deform
// outright would flatten the open sea to a sheet of glass. This keeps the motion and removes the
// tidal wave.
//
// IF IT STILL READS TOO CALM OR TOO WILD, this token is the only knob: travel = 10 * <max> * rawT
// units at the seaward end. 2 gives +/-20, 0.47 makes this sheet move EXACTLY in step with
// deepbluesea_runup (surface 1644, coplanar with this one at z -520 over the whole overlap, and
// carrying `flap t 10 sin 0 3 0 .10 0 3`, i.e. 9*rawT_runup where rawT_runup ramps 1.909x slower) -
// which is the only value at which the two coplanar sheets cannot interpenetrate.
//
// NOTHING ELSE IS TOUCHED. Apart from the two marked edits, both stages below are byte-for-byte retail.
textures/misc_outside/deepbluesea
{
	qer_editorimage textures/misc_outside/ocean2.tga
	qer_keyword natural
	qer_keyword liquid
	qer_keyword ocean
	qer_trans .4
	surfaceparm trans
	surfaceparm water
	surfaceparm nolightmap
	cull none

	// retail: deformvertexes flap t 10 sin 0 10 0 .10 0 10   <- final 10 is the offender
	deformvertexes flap t 10 sin 0 10 0 .10 0 1

	{
		nopicmip
		// [user 2026-09-06, bug-2507] the lid from below. Retail deepbluesea has no blendFunc, so seen
		// from under the sheet it is an opaque wall; retail deepbluesea_runup (same file) carries
		// blendFunc blend + depthwrite on this stage, copied here. depthwrite is LOAD-BEARING: the
		// gl2 water pass (underwater_fp.glsl:156-164) paints every pixel with no depth as far-plane
		// silt, so a blended lid that wrote no depth would vanish into murk. The explicit keyword
		// survives blendFunc (gl2 tr_shader.c:1037 clears the mask only when not explicit); the
		// deform keeps this shader on the generic path, where the nextbundle pair still draws in one
		// pass (tr_shade.c:2064). m3l1a-only: the name is referenced by m3l1a.bsp alone (bug-2478).
		// MEASURED 2026-09-06: oceandday1 ships ONLY as .jpg (retail Pak2 256^2, coop tex pak 1024^2; no
		// .tga/.dds anywhere), and the JPEG loader fills alpha 255 (renderercommon/tr_image_jpg.c:235),
		// so blendFunc blend alone draws OPAQUE - retail runup is equally opaque. The alpha has to
		// come from an alphaGen (zz_coop_shoreline.shader does the same on this jpg with tCoord).
		// alphaGen entity reads $ocean_wavy's s.alpha (Entity default 1.0, entity.cpp:1754; cgame
		// cg_modelanim.c:2650; gl2 generic tr_shade.c:722), so the sheet stays exactly as it was
		// until the beat sets `$ocean_wavy alpha 0.6` and restores `alpha 1` at the break - no
		// from-above cost: seaward of Y -2000 the BSP has no seabed, only the sky wall, so a
		// permanently translucent sea would show sky through it from the beach.
		depthwrite
		map textures/misc_outside/oceandday1.tga
		blendFunc blend
		alphaGen entity
		rgbGen identityLighting
		tcMod scale 16 22
		tcMod scroll 0.01 .03
	nextbundle
		map textures/misc_outside/oceandday1.tga
		tcMod scale -16 22
		tcMod scroll 0.01 0.04
	}
	{
		nopicmip
		map textures/misc_outside/oceandday1.tga
		blendFunc add
		tcMod scale .2 .5
		tcMod scroll 0 .005
	nextbundle
		map textures/misc_outside/oceandday1.tga
		tcMod scale .2 .5
		tcMod scroll 0 .01
	}
}
