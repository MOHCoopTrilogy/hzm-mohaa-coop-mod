// MOH Trilogy Coop - Omaha's waterline sheet: the 12 planar faces between the open sea and the sand
//
// PRECEDENCE (TRAPS T6, bug-2485): this override wins because the coop pak outranks main/mainta/maintt,
// NOT because of the zz_ name - within one pak both renderers give a duplicated name to the alphabetically
// FIRST shader file, so define this name in exactly ONE coop file. An override REPLACES the retail block,
// it does not merge (drop a surfaceparm and the surface collides, fogs or sorts differently), so the body
// restates textures/misc_outside/deepbluesea_shoreline from main/Pak0.pk3 scripts/misc_outside.shader and
// marks every change.
//
// GEOMETRY (LANE-A, measured from the BSP, m3l1b identical): y -2160 (the seam with deepbluesea) to -768
// (the quad edge on the sand strip), 1392 u, z -520 rising to -479. Raw T = 0.005 at the SEAM and 0.994
// at the LAND edge, one continuous 0..1 across both quad rows = 1408 u per 1.0 T. S is one continuous
// 0..1 over the whole 15872 u beach, so `tcMod scale 62 1` is a seamless 256 u tile, the sand strip's
// own period (its S phase leads this sheet's by 0.25). The sand strip (zz_coop_wetsand.shader) is
// y -1024..-768 = T 0.816..0.994 of this sheet; at rest the sheet sits 17.5 u above it at the sea edge
// and 1 u at the land edge.
//
// THE FLAP [coop 2026-08-28]: retail had no deform on these 12 faces while the only animated water was
// one face each of deepbluesea / deepbluesea_runup, so the water you actually look at was static.
// `flap t` is a time-only hinge scaled by T: +/-0.08 u at the seam, +/-7.9 mid-band, +/-15.9 at the
// land edge, 12.5 s period; amplitude 4 against deepbluesea's 10 because this is the wash at the
// sand's edge, not open ocean. Because the shader has a deform, gl2 sends it down the GENERIC program,
// the only one that evaluates alphaGen sCoord/tCoord (bug-1249; the lightall gap is bug-2486).
//
// THE HAND-OFF FADE [user 2026-09-06, bug-2508] (ocean report s.3, "the smallest change that rags it").
// The sheet's edge was a straight line for two reasons: during the flood it ends at the quad edge
// y -768 (an alpha cut), and during the ebb it dips under the sand plane for T > ~0.87 and its visible
// edge is plane-meets-plane. Additive stages cannot be masked after the fact, so every live stage now
// fades ITSELF along raw T (alphaGen reads the texcoord BEFORE tcMods, so the wavetrant surges do not
// move the fade). The formula, from the code (renderergl1 tr_shade_calc.c RB_CalcAlphaFromTexCoords,
// gl2 generic_vp.glsl CalcColor, identical):
//     alphaGen tCoord <min> <max> <constMin> <const>  ->  alpha = clamp((max - min) * T + min, constMin, const)
// ALWAYS FOUR PARAMETERS: the two-parameter form leaves const at its -1 sentinel = alpha 0 on both
// renderers (LANE-A s.4, bug-2226), which is why two retail stages here drew nothing for four years.
// The fade is `alphaGen tCoord 8.2 -1.8 0 1` = -10 T + 8.2: alpha 1 for T <= 0.72 (y -1146), 0 at
// T 0.82 (y -1006), seaward of the strip's sea edge (0.816) and of the ebb crossing (~0.87). (The ocean
// report wrote `8.2 -10` for this knee; under the real formula that is alpha 0 from T 0.45, mid-band.
// The code wins.) The four wash stages and the crest moved from `blendFunc add` to `GL_SRC_ALPHA
// GL_ONE` (identical while alpha is 1) so their own alpha can end them; the blood keeps `blend` with
// the same fade scaled to its 0.6 ceiling. The sheet now has no alpha at the y -768 quad edge and is
// invisible before it dips under the sand, the crest's shoreward run dies at one line - the break -
// and the swash on the strip is the strip's job (zz_coop_wetsand.shader, ragged by bug-2493).
//
// STAGES, 8 of 8 (MAX_SHADER_STAGES is 8 in both renderers; gl2 rejects a 9th and drops the whole
// shader, gl1 has no bound check and writes past the array - NEVER ADD A NINTH):
//   1  base water tint   oceandday1 x2   blend                  tCoord 1.8 -0.01 0 1  (reclaimed, was alpha 0)
//   2  break-line foam   coop_fx/breakfoam.tga  GL_SRC_ALPHA GL_ONE  alpha baked         (reclaimed, was alpha 0)
//   3-6 wash2 x oceandday1 (retail)      GL_SRC_ALPHA GL_ONE   tCoord 8.2 -1.8 0 1
//   7  blood in the surf bloodwash.tga   blend                  tCoord 4.92 -1.08 0 0.6
//   8  travelling crest  ocean2a_shore   GL_SRC_ALPHA GL_ONE   tCoord 8.2 -1.8 0 1   (ifCvarnot coop_noCrest, LAST)
// gl1 has 2 texture bundles (gl2 7); stages 1 and 3-6 use both, so there is no bundle route either.
// Kill switches for shader-only items are this file (and `coop_noCrest 1` for stage 8).

textures/misc_outside/deepbluesea_shoreline
{
	qer_editorimage textures/misc_outside/deepbluesea_editor.tga
	qer_keyword natural
	qer_keyword liquid
	qer_keyword ocean

	qer_trans .4
	surfaceparm trans
	surfaceparm water
	surfaceparm nolightmap
	cull none

	// [coop 2026-08-28] the vertical wash at the sand's edge (header: THE FLAP). Also what keeps this
	// shader on gl2's generic program, where alphaGen tCoord exists. Do not remove.
	//[user 2026-09-06, bug-2514] 4/4 -> 2/2. This sheet's own edge is a plane-plane intersection line
	//that swept y -768..-965 in perfect unison along all 15872 u - dead straight, zero rag, by
	//construction. Halving amplitude AND max moves the crossing to y -812.3: sweep 197 u -> 44 u,
	//keeping a quarter of the heave. (1/1 kills 94% of the motion and leaves 0.0067 u at the trough.)
	//This is the SHORELINE flap. The ocean's flap max is 1 by bug-2478 and must stay there.
	deformVertexes flap t 10 sin 0 2 0 .08 0 2

	// [user 2026-09-06, bug-2508] STAGE 1 - BASE WATER TINT, reclaimed. Retail's two-parameter alphaGen
	// left const at -1 = alpha 0 on both renderers (LANE-A s.4), so this stage drew nothing and the
	// waterline never had a water colour of its own - only additive foam over the seabed. The fourth
	// parameter is the whole fix: alpha = -1.81 T + 1.8, 1 from the seam to T 0.44, 0 at the land edge
	// (0.994), the ocean fading in from the seam as the retail comment always claimed. It runs past the
	// hand-off knee on purpose (0.32 at T 0.82, 0.24 at the ebb crossing ~0.87): that is the assigned
	// retail ramp. KNOB: if a faint blended line shows at the trough, `1.8 -0.4 0 1` ends it at T 0.82.
	{
		nopicmip
		map textures/misc_outside/oceandday1.tga
		blendFunc blend
		alphaGen tCoord 1.8 -0.01 0 1
		tcMod scale 16 5
		tcMod scroll 0.01 -0.034
	nextbundle
		map textures/misc_outside/oceandday1.tga
		tcMod scale -16 5
		tcMod scroll 0.01 -0.034
	}
	// [user 2026-09-06, bug-2508] STAGE 2 - BREAK-LINE FOAM, reclaimed (retail: `alphaGen tCoord 1.01 -0.5`,
	// two parameters, alpha 0, drew nothing; its second oceandday1 bundle went with it).
	// textures/coop_fx/breakfoam.tga is wetsand_foam.tga's wash2 band read back out of the shipped rows
	// (docs/tools/gen_breakfoam.py, per-row RGB*alpha dump, 18-byte header) and resampled to T 0.55-0.72
	// of THIS sheet (y -1386..-1146) - right where the crests die at the hand-off knee. The reach is
	// BAKED into its alpha (the sand foam's ragged window, resampled with the band) and its columns are
	// rolled 0.25 S, so at `tcMod scale 62 1` (one seamless 256 u tile, header: GEOMETRY) its rag is the
	// strip's rag at every x. `clampmapy` clamps T only; the t=0 and t=1 rows are black AND transparent
	// so the clamp cannot smear. No alphaGen: the band lives under the 0.72 knee and the +/-0.06 T
	// (84 u) surge keeps it under 0.82. rgbGen wave and wavetrant both run at the flap's 0.08 Hz, phase
	// 0 = brightest and furthest shoreward on the lift, so it pulses with the crest, the flap and the
	// strip's foam for free (one renderer clock). Peak add ~0.11 framebuffer, under the bloom threshold.
	// TUNING: brightness = rgbGen amplitude (base + amp <= 1); band position = regenerate (DST_T0/T1);
	// surge = wavetrant amplitude, keep base + amp + 0.72 < 0.82.
	{
		nopicmip
		clampmapy textures/coop_fx/breakfoam.tga
		blendFunc GL_SRC_ALPHA GL_ONE
		rgbGen wave sin 0.3 0.25 0 0.08
		tcMod scale 62 1
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
		map textures/coop_fx/surfcell.tga
		tcMod wavetrant sin 0 -0.06 0 0.08		// [bug-2508, verifier] negative amplitude: furthest shoreward ON the lift, with the flap
	}

	// [user 2026-09-06, bug-2508] STAGES 3-6 - retail's four wash2 layers, two mirrored antiphase pairs,
	// the only thing that painted the waterline until today. `blendFunc add` -> `GL_SRC_ALPHA GL_ONE`
	// plus the hand-off fade (header); identical output wherever alpha is 1, i.e. everywhere seaward of
	// T 0.72. Both bundles' textures carry alpha 1 (wash2.dds is DXT1, oceandday1 is a jpg), so the
	// stage alpha is exactly the fade. Nothing else in these four blocks changed.
	{
		nopicmip
		map textures/misc_outside/wash2.tga
		blendFunc GL_SRC_ALPHA GL_ONE
		alphaGen tCoord 8.2 -1.8 0 1
		rgbGen wave sin .15 .525 .35 -.04
		tcMod scale 8 1.1
		tcMod scroll 0.01 .0
		tcMod wavetrant  sin 0.725 -.3 .5 -.04
	nextbundle
		map textures/misc_outside/oceandday1.tga
		tcMod scale 8 1.1
		tcMod scroll -0.025 -0.025
	}
	{
		nopicmip
		map textures/misc_outside/wash2.tga
		blendFunc GL_SRC_ALPHA GL_ONE
		alphaGen tCoord 8.2 -1.8 0 1
		rgbGen wave sin .15 .525 .325 -.04
		tcMod scale -8 1.1
		tcMod scroll 0.01 .0
		tcMod wavetrant  sin 0.725 -.3 .45 -.04
	nextbundle
		map textures/misc_outside/oceandday1.tga
		tcMod scale -8 1.1
		tcMod scroll -0.025 -0.025
	}
	{
		nopicmip
		map textures/misc_outside/wash2.tga
		blendFunc GL_SRC_ALPHA GL_ONE
		alphaGen tCoord 8.2 -1.8 0 1
		rgbGen wave sin .15 .525 .85 -.04
		tcMod scale 8 1.1
		tcMod scroll 0.01 .0
		tcMod wavetrant  sin 0.725 -.3 0 -.04
	nextbundle
		map textures/misc_outside/oceandday1.tga
		tcMod scale 8 1.1
		tcMod scroll -0.025 -0.025
	}
	{
		nopicmip
		map textures/misc_outside/wash2.tga
		blendFunc GL_SRC_ALPHA GL_ONE
		alphaGen tCoord 8.2 -1.8 0 1
		rgbGen wave sin .15 .525 .825 -.04
		tcMod scale -8 1.1
		tcMod scroll 0.01 .0
		tcMod wavetrant  sin 0.725 -.3 .95 -.04
	nextbundle
		map textures/misc_outside/oceandday1.tga
		tcMod scale -8 1.1
		tcMod scroll -0.025 -0.025
	}

	// [coop 2026-08-31] BLOOD IN THE SURF - the user asked for blood in the water "specifically near
	// the shore not out in the ocean".
	//
	// This is a STAGE, not spawned geometry, and that is the whole point. This shader is the near-shore
	// band by construction - it is the 12 waterline faces, and the open ocean is a different shader
	// (deepbluesea) - so putting the blood here bounds it to the shore for free, with zero entities and
	// zero script.
	//
	// The alternative, floating blood planes on the water, does not work here: the deformVertexes flap
	// above moves this surface vertically by roughly +/-8u at the far end of the band and +/-16u at the
	// near end on a ~12.5s cycle, and no separate entity can follow a per-vertex deform. A static plane
	// would sink under the wash and surface through it every cycle. A stage inherits the deform.
	//
	// One blended stage on a surface at its 8-stage cap; the texture's own alpha does the slick shaping
	// and the stage alpha below does the reach. Slow, near-perpendicular scroll so it drifts
	// with the surf without ever looking like it is flowing in one direction.
	{
		nopicmip
		map textures/coop_fx/bloodwash.tga
		blendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA
		// [user 2026-08-31] HEAVIER. First pass ran alpha 0.5 at scale 0.85/0.30 and the user still read
		// the water as clean - "i was hoping more of having BLOODY WATER on the shoreline not just bodies
		// with blood in the water". Alpha up to 0.82 and the texture stretched much wider (0.42/0.16, so
		// each repeat covers roughly twice the surface) turns it from a tint into standing blood in the
		// wash. Still ONE stage on a 6-stage surface.
		// [user 2026-08-31] bug-2230 ramped this along T (0.02 at the seam -> 0.60 at the sand) to hide the
		// join with deepbluesea, which has no blood: 'you can tell the clear difference between where the
		// water textures separate between the higgins drive in and the actual landing'.
		// [user 2026-09-06, bug-2508] THE RAMP IS NOW THE HAND-OFF FADE (header). The ramp put a 60%-alpha
		// red sheet on the quad edge at y -768 and was the loudest part of the straight line; `tcMod scale
		// 16 2` tiles T twice so no bake could pin its edge. Same knee as every other stage, scaled to this
		// stage's tuned 0.6 ceiling (bug-2249): alpha = -6 T + 4.92 clamped [0, 0.6] = 0.6 for T <= 0.72,
		// 0 at 0.82. One linear ramp cannot both rise from the seam and fall at the knee, so the seam-hiding
		// rise is gone: the blood is 0.6 x texture alpha from y -2160 in. The swash blood moves to the sand
		// strip (coop_fx/swashblood.tga on zz_coop_wetsand.shader). KNOB: the 4th number is the ceiling -
		// lower it (with the 1st = 8.2 x ceiling, 2nd = -1.8 x ceiling) if the seam reads again.
		//[user 2026-09-06, bug-2514] halved. The blood reddens the shore side of the y -2160 line by
		//+0.030 R / -0.011 G and reads as a maroon carpet the length of the beach from above. This
		//sheet has THREE vertex t rows (0.00497 / 0.49361 / 0.99361) and alphaGen is per-vertex, so a
		//monotonic ramp cannot be clean at both ends: keep the clean sand edge, halve everything else.
		//Vertex triple 0.6 / 0.6 / 0.0 -> 0.3 / 0.3 / 0.0.
		alphaGen tCoord 2.46 -0.54 0 0.3
		// Was 0.42/0.16 - less than one repeat across a 16,000-unit beach, i.e. one smooth blob, i.e. a
		// red filter over the sea. 16 x 2 puts a repeat every ~1000 units across and ~700 deep, so the
		// texture's clear water (58% of it now) actually reads as gaps between slicks.
		tcMod scale 16 2
		tcMod scroll 0.002 -0.008
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
		//The SOFT mask here, floor 0.55 not 0.20: blood is deposited ON SAND and should vary with the
		//surf, not switch off with it.
		//Kill switch: python docs/tools/gen_surfcell.py --flat (alpha 255, a no-op multiply, no
		//shader edit and no vid_restart).
	nextbundle
		map textures/coop_fx/surfcell_soft.tga
	}

	// [user 2026-09-04] THE TRAVELLING CREST. "waves and physical white waves that crest".
	//
	// THIS STAGE IS LAST ON PURPOSE - do not move it up. On gl1 a stage disabled by ifCvarnot leaves
	// an inactive slot (ParseStage still does s++, tr_shader.c:2251-2266) and FinishShader BREAKS at
	// the first inactive slot in three separate loops. Sitting anywhere but last, `coop_noCrest 1`
	// would silently take the blood-in-the-surf stage above with it. Terminal, the hole is harmless
	// in both renderers. It is also the correct draw order: additive foam belongs on top of the
	// alpha-blended blood, not under it.
	//
	// WHY THIS IS TEXTURE-SPACE AND NOT GEOMETRY. The deformVertexes flap above is a HINGE, not a
	// wave: RB_CalcFlapVertexes (renderergl2/tr_shade_calc.c:169-238) computes its scale from TIME
	// ALONE and multiplies by a per-vertex (max-min)*T + min, so every vertex on the band rises in
	// the same instant and only the amplitude varies along T. Measured from the BSP: +/-0.08u at the
	// seaward seam, +/-7.9u mid-band, +/-15.9u at the water's edge, on a 12.5s period. The waterline
	// is 12 quads / 48 verts / 24 tris in total, so there is no per-vertex wave to be had at any
	// parameter - and tessSize is a compiler keyword both renderers SkipRestOfLine at runtime.
	// Retail hit this too: `deformvertexes wave` is commented out above the flap in deepbluesea.
	//
	// WHY THIS TEXTURE. textures/misc_outside/ocean2a_shore is retail art that NO shader references,
	// checked across every .shader in main/mainta/maintt. It is the only shore-parallel BANDED image
	// in the paks: row-luminance std 45.1 against 5.5 along columns, 8.2x anisotropy, where every
	// textures/water/* candidate measures ~1.0 and is isotropic chop with no band in it. Its profile
	// down T is a speckled spray field, then a crest core peaking at luminance 136, then ~28% pure
	// black - and under an additive blend that black is the gap between one crest and the next.
	// NOT wash2 (which this shader already uses four times): wash2 peaks at only 64, and on additive
	// stages brightness is the whole budget. Its profile is also a symmetric spike where ocean2a is
	// an asymmetric breaking section. (An earlier draft justified this by saying wash2 has no gap -
	// that was wrong; wash2's gap is 56%, larger than ocean2a's. The choice stands on brightness and
	// profile shape, not on the gap.) No .dds of this name exists in any mounted pak, so no HD pack
	// shadows it and it never enters the LoadDDS path that crashed gl1 on this map (bug-2445).
	//
	// SIGNS, because this is the easy thing to ship backwards. tcMods compose in listing order and
	// scroll ADDS to the coordinate, so the IMAGE travels toward DECREASING coordinate - which is why
	// the retail base stages above read `tcMod scroll 0.01 -0.034`. This stage uses a NEGATIVE T
	// scale to mirror the tile (ragged spray edge leading, smooth wash behind), and mirroring flips
	// the sign with it: here POSITIVE 0.16 is shoreward. If it runs out to sea, negate that number.
	//
	// NUMBERS, from the BSP: T maps 0.005..0.994 across the 1392u band = 1409 world units per 1.0 T.
	// scale 8/-6 puts a crest every 235u (5.9m); scroll 0.16 walks them shoreward at a mean 37.6 u/s
	// and lands one every 6.25s - EXACTLY HALF the flap's 12.5s, so the two can never drift apart.
	// wavetrant adds surge at the flap's own frequency at phase 0, so peak forward displacement falls
	// on peak lift: a crest runs, stalls, and surges again rather than gliding. Amplitude 0.30 sits
	// just under the 0.318 at which it would visibly slide backwards (at 60fps and the engine's
	// 1024-entry function table it still dips ~0.24u once per cycle - sub-pixel at any range).
	// rgbGen wave and the flap's scale are BOTH time-only and global, which is the only reason a
	// phase lock means anything across a 15872u beach. Phase 0 = white peaks at the top of the wash.
	//
	// THE CAP. MAX_SHADER_STAGES is 8 in both renderers and this is the 8th. DO NOT ADD A NINTH: gl2
	// rejects the whole shader and the waterline of every map using this name falls back to the
	// default texture, and gl1 has no bound check at all and writes past the array. NUM_TEXTURE_
	// BUNDLES is 2 on gl1 (7 on gl2), so gl1 is the binding constraint and there is no bundle route
	// either - both bundles of every wash2 stage above are already spoken for.
	//
	// KILL SWITCH: `coop_noCrest 1` then vid_restart (or a map load) drops this stage. Phrased as a
	// NEGATIVE cvar so it is ON out of the box with no cfg seed. Evaluated at SHADER PARSE time, so
	// it is NOT a live toggle.
	// TUNING, in the order to reach for it:
	//   runs the wrong way  -> negate the 0.16 in tcMod scroll.
	//   crests too close    -> the -6 in tcMod scale. Spacing = 1409/|value| world units. Arrival
	//                          period stays 6.25s for ANY T scale (it is 1/scroll), and the phase
	//                          lock is unaffected - so this knob is safe to move freely.
	//   too bright/faint    -> rgbGen wave sin 0.55 0.45 ...; base+amp must stay <= 1.0.
	//   white off-beat      -> the 3rd number (phase). 0.95 lags 0.6s, 0.05 leads. Never negative.
	//   dies too early/late -> the shared hand-off fade (header): alphaGen tCoord 8.2 -1.8 0 1. It is
	//                          raw-T, so the scroll and the surge never move it [bug-2508].
	// NEVER change `sin` to `noise` here: TableForFunc has no GF_NOISE case and calls ri.Error(ERR_DROP).
	{
		ifCvarnot coop_noCrest 1
		nopicmip
		map textures/misc_outside/ocean2a_shore.jpg
		blendFunc GL_SRC_ALPHA GL_ONE
		alphaGen tCoord 8.2 -1.8 0 1
		rgbGen wave sin 0.55 0.45 0 0.08
		//[user 2026-09-06, bug-2514] 8 -> 5: the crest stopped tiling on 1984 u (autocorrelation at that
		//lag +0.956 -> -0.307). The transform below is a SHEAR, t' = 0.10*(5s) - 6t, which tilts the
		//crest line off shore-parallel by 117 u across the beach so it arrives ~7 s apart at the two
		//ends instead of the whole 15872 u flashing white at once. tcMods compose in LISTED ORDER, so
		//this must sit between the scale and the scroll. FOUR tcMods here is TR_MAX_TEXMODS: a fifth
		//is ri.Error(ERR_DROP) at parse time. This stage is closed.
		tcMod scale 5 -6
		tcMod transform 1 0.10 0 1 0 0
		tcMod scroll 0.01 0.16
		tcMod wavetrant sin 0 0.30 0 0.08
		//[user 2026-09-06, bug-2518] the cell mask on the crest too, and this one is MANDATORY, not
		//optional: stage 2's foam contributes ~0.11 of framebuffer while this stage is ocean2a_shore
		//under rgbGen wave 0.55 0.45, roughly 5x brighter and the thing that actually reads as a line
		//of surf. Gating the faint layer and leaving the bright one whole would inverse the intent.
		//Bundle 1 carries no tcMod, so it samples the raw texcoords the mask is authored in. The
		//nextbundle also marks this stage ST_GLSL (tr_shader.c:5238), which keeps its alphaGen tCoord
		//off the lightall collapse that would drop it (bug-2486) - a free side benefit.
	nextbundle
		map textures/coop_fx/surfcell.tga
	}
}
