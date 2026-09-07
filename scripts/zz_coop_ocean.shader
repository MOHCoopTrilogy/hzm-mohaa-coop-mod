// [coop 2026-09-05] THE OPEN OCEAN STOPPED SWALLOWING THE LANDING CRAFT.
//
// USER: "it looks like there are several higgins boats that are underwater following us in."
//
// This is a WHOLE-BODY RESTATEMENT of textures/misc_outside/deepbluesea (main/Pak0.pk3,
// scripts/misc_outside.shader). Two edits differ from retail, both marked below: the flap max
// (bug-2478) and the first stage's blendFunc blend + depthwrite (bug-2507, the lid from below).
// Two retail stages plus two coop stages (bug-2508: foam streaks, sky sheen) = 4 of the 8-stage cap -
// unlike zz_coop_shoreline.shader, which is at 8.
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
// NOTHING ELSE IS TOUCHED in the retail body: apart from the two marked edits, stages 1-2 are byte-for-byte
// retail. Stages 3-4 are coop additions (bug-2508), each documented where it sits.
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
		//[user 2026-09-06, bug-2514] THE SEAM. This additive sheen had no counterpart on the shore
		//sheet, so it was 0.240 of max channel of pure step across the straight line at y -2160.
		//`blendFunc add` parses to ONE|ONE and ignores alpha (tr_shader.c:1007), so the blendFunc
		//change is a PREREQUISITE of the alphaGen, not decoration. alphaGen tCoord 0 4 0 1 = 4T
		//clamped, which on this patch's eight drawn vertex rows (t = k/7, y -2160 .. -8000) reads
		//0.000 / 0.571 / 1.000 and is bit-identical to what shipped from y -3828.6 seaward.
		blendFunc GL_SRC_ALPHA GL_ONE
		alphaGen tCoord 0 4 0 1
		tcMod scale .2 .5
		tcMod scroll 0 .005
	nextbundle
		map textures/misc_outside/oceandday1.tga
		tcMod scale .2 .5
		tcMod scroll 0 .01
	}
	// [user 2026-09-06, bug-2508] ITEM 5a - FOAM STREAKS ON THE OPEN SEA (ocean_2026-09-06 README s.2).
	// Coop-only stage 3 of 8. Retail froth2 = main/Pak2 256^2 RGBA. The install's winning copy is
	// maintt/zzzzzzz_dds_hdmem.pk3's 1024^2 DXT5 (gl2, r_ext_compressed_textures 1 loads .dds first,
	// tr_image.c:2481), else zzzzz-AA_HD_Project_Pak3's 1024^2 tga; the mod source tree ships none and
	// a TEXTURE name is not contested (T6 is about shader names), so no private copy. Per-pixel, so
	// the 8x8 drawn patch does not matter (README s.1).
	//   rgbGen wave sin 0.3 0.2 0 0.10 = 0.1..0.5, locked to the flap's .10 Hz above so the streaks
	//   brighten on the lift. tcMod scale 4 1 = 4 tiles across S, 1 across T (T = 0 at the y -2160
	//   seam, 1 at y -8000). scroll 0 0.004 = texcoord t rising = pattern drifting toward T 0 =
	//   SHOREWARD, ~23 u/s (same sign as retail stage 2's 'rolling in'). turb = a lazy per-vertex
	//   wobble (gl2 tr_shade.c:218, a smooth term on 64 verts), ~80 u at 20 s.
	//   Additive budget = 0.5 x texel(max channel x alpha): winning HD copy p99 0.31 -> 0.155, mean
	//   0.085 -> 0.04; retail-only p99 0.72 -> 0.36; absolute peak (a white speck) 0.5.
	//   Global fog fades additive stages toward black with distance (tr_shade.c:1450-1458), so the
	//   streaks die at range on their own. Kill switch: delete this stage (shader-only item).
	{
		nopicmip
		map textures/misc_outside/froth2.tga
		blendFunc GL_SRC_ALPHA GL_ONE
		rgbGen wave sin 0.3 0.2 0 0.10
		tcMod scale 4 1
		tcMod scroll 0 0.004
		tcMod turb 0 0.02 0 0.05
		//[user 2026-09-06, bug-2518] ALONG-SHORE CELL MASK. Everything on this beach is driven by
		//tCoord, which cannot vary along the shore, so every band was a straight stripe running all
		//15872 u ("a lot of perfect symmetry ... it all looks like a straight line"). A second bundle
		//is the only channel that can carry along-shore variation without spending a stage: both
		//renderers multiply bundle 1's ALPHA into the stage (gl2 generic_fp.glsl, gl1 GL_MODULATE),
		//and the mask is RGB 255 so colour is untouched. No tcMod: bundle 1 defaults to TCGEN_TEXTURE,
		//the raw texcoords, which is the mapping docs/tools/gen_surfcell.py authors in. 17 cells at
		//~23.7 m plus five embayments at 16-28 m, sheared 0.015 across the surf zone so the outer and
		//inner gaps do not stack. The embayments are megacusp / runnel drainage, NOT rips: rips at
		//Omaha are unattested and a dissipative terrace is the least likely bed to carry them.
		//Kill switch: python docs/tools/gen_surfcell.py --flat (alpha 255, a no-op multiply, no
		//shader edit and no vid_restart).
	nextbundle
		map textures/coop_fx/surfcell_m.tga
	}
	// [user 2026-09-06, bug-2508] ITEM 5b - SKY SHEEN (README s.0 item 4 / s.4: Omaha's sun is
	// vertical, so a sun glint sits at the nadir; what an overcast sea catches at grazing angles is
	// the sky). Coop-only stage 4 of 8. textures/coop_fx/sky_sheen.tga is a 256^2 sphere map baked
	// from the map's own sky faces (env/dday2 = textures/sky/d-day2, maintt/pak1 sky.shader) by
	// docs/tools/gen_skysheen.py, which also bakes a Fresnel-shaped ALPHA (0.30 at the nadir, 1.0 at
	// the horizon) because alphaGen dot/oneMinusDot are dead on gl2. tcGen environment runs in the
	// vertex program on gl2 (generic_vp.glsl:149-155) and on gl1's CPU path with the same algebra:
	// per-vertex, a smooth grazing gradient on the 8x8 patch, the right look from a Higgins.
	//   Additive budget = 0.25 x alpha x sky max-channel: 0.033 looking straight down, 0.162 at the
	//   horizon, absolute max 0.166.
	//   SUM with 5a: typical 0.04 + 0.06 = 0.10; bright streak (HD) 0.155 + 0.162 = 0.32; worst
	//   case (retail white speck at the horizon) 0.50 + 0.166 = 0.67 < 0.7. NOTE the shipped knee is
	//   r_ppBloomThreshold 0.35 (coop_defaults.cfg:54), not the engine default 0.6, and
	//   bloom_bright_fp.glsl:38-40 tests the FINAL pixel's max channel on a base that is already
	//   ~0.69 (stage 1 oceandday1 0.35 + stage 2 add 0.35) - toggle r_ppBloom to A/B.
	//   Kill switch: delete this stage (shader-only item).
	{
		nopicmip
		map textures/coop_fx/sky_sheen.tga
		blendFunc GL_SRC_ALPHA GL_ONE
		tcGen environment
		rgbGen identity
		//[user 2026-09-06, bug-2514] was `alphaGen const 0.25` - a flat quarter everywhere, including
		//the seam row where the shore sheet has no sheen at all. clamp(T,0,0.25) fades it in over the
		//first 1/4 of the patch; 255*0.25 = 63 exactly, so the far field is unchanged to the byte.
		alphaGen tCoord 0 1 0 0.25
	}
	// [user 2026-09-06, bug-2514] ITEM 5c - THE SAME CREST AS THE SHORE, SO IT CROSSES THE SEAM.
	// The travelling crest existed on exactly one side of a straight line, which was the largest
	// single component of the step at y -2160. Every number here is DERIVED from the shore stage,
	// not chosen: `24.887` = 5840 * 6/1408 is the scale at which this patch's texture coordinate is
	// the same function of world y as the shoreline sheet's, so both crests have the same 234.67 u
	// spacing and the same 37.55 u/s shoreward run; `5` matches the shore's S scale so both tile at
	// 3174 u along shore; the transform matches the shore's shear and gives dy/ds = +117.33 u with
	// the SAME sign (the sea's t rises seaward, and the sign flip between -6 and +24.887 already
	// accounts for it). alphaGen tCoord 1 -1 0 1 = 1-2T, which on this patch's real vertex rows is
	// 1.000 / 0.714 / 0.429 / 0.143 / 0.000 at y -2160 / -2994 / -3829 / -4663 / -5497 and seaward,
	// so the crest lives in the near strip and never reaches the fleet.
	// MUST BE LAST: gl1 leaves an inactive slot for a failed ifCvarnot and FinishShader breaks at the
	// first inactive stage, so a cvar-gated stage anywhere else silently drops everything below it.
	// ocean2a_shore.jpg exists once, main/Pak2.pk3, 256^2, with no .dds and no .tga anywhere in
	// main/mainta/maintt, so no HD pack can shadow it. Ocean goes 4 -> 5 stages of 8.
	// Kill switch: coop_noSeaCrest 1 + vid_restart (parse time, not live).
	// IF IT RUNS OUT TO SEA INSTEAD OF IN, negate the 0.16 in tcMod scroll - that sign is the one
	// thing here derived rather than observed.
	{
		ifCvarnot coop_noSeaCrest 1
		nopicmip
		map textures/misc_outside/ocean2a_shore.jpg
		blendFunc GL_SRC_ALPHA GL_ONE
		alphaGen tCoord 1 -1 0 1
		rgbGen wave sin 0.55 0.45 0 0.08
		tcMod scale 5 24.887
		tcMod transform 1 0.10 0 1 0 0
		tcMod scroll 0.01 0.16
		tcMod wavetrant sin 0 0.30 0 0.08
	}
}
