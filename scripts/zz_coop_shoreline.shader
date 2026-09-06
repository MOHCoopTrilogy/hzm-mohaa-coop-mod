// MOH Trilogy Coop - shoreline wave motion
//
// WHY THIS FILE IS NAMED zz_: ScanAndLoadShaderFiles concatenates the shader files in REVERSE
// listing order (tr_shader.c: `for (i = numShaderFiles - 1; i >= 0; i--)`), and FindShaderInShaderText
// returns the FIRST match in that text. FS_ListFiles returns a sorted list, so the file that sorts
// LAST ends up FIRST in the text and wins the name. The highest existing name in this install is
// y_hzm_maptour3.shader, so zz_ beats it. Rename this below that and the retail definition silently
// wins again with no error anywhere - the documented contested-shader trap (bug-922).
//
// WHY THE WHOLE BODY IS RESTATED: an override replaces the definition outright, it does not merge.
// Dropping a single surfaceparm here would change how the surface collides, fogs or sorts. This is a
// verbatim copy of textures/misc_outside/deepbluesea_shoreline from main/Pak0.pk3 scripts/misc_outside.shader
// with exactly ONE line added - the deformVertexes below.
//
// WHAT IT FIXES: m3l1a's waterline is 12 faces of this shader and it has no deform at all, while the
// only animated water (deepbluesea, deepbluesea_runup) is ONE face each. So the surf moves on a sliver
// and the waterline you actually look at is static - which reads as "there are no waves".
// The flap parameters are deliberately gentler than deepbluesea's own (amplitude 4 vs 10): this is the
// wash at the sand's edge, not open ocean.

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

	// [coop 2026-08-28] THE ONE ADDED LINE - vertical wash at the sand's edge.
	deformVertexes flap t 10 sin 0 4 0 .08 0 4

	{
		nopicmip
		map textures/misc_outside/oceandday1.tga
		blendFunc blend
		alphaGen tCoord 1.8 -0.01
		tcMod scale 16 5
		tcMod scroll 0.01 -0.034
	nextbundle
		map textures/misc_outside/oceandday1.tga
		tcMod scale -16 5
		tcMod scroll 0.01 -0.034
	}
	{
		nopicmip
		map textures/misc_outside/oceandday1.tga
		blendFunc GL_SRC_ALPHA GL_ONE
		alphaGen tCoord 1.01 -0.5
		tcMod scale 0.2 0.105
		tcMod scroll 0 -0.005
	nextbundle
		map textures/misc_outside/oceandday1.tga
		tcMod scale 0.2 0.105
		tcMod scroll 0 -0.009
	}
	{
		nopicmip
		map textures/misc_outside/wash2.tga
		blendFunc add
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
		blendFunc add
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
		blendFunc add
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
		blendFunc add
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
	// Kept to ONE extra blended stage on a surface that is already 6 stages x 2 bundles. alphaGen const
	// rather than the tCoord ramps above, so the wash reads evenly along the whole waterline instead of
	// banding; the texture's own alpha does the shaping. Slow, near-perpendicular scroll so it drifts
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
		// [user 2026-08-31] RAMPED ALONG T, and that is what fixes the seam.
		//
		// The user: "the blood is overwhelming in the water once you get off the boat, you can tell the
		// clear difference between where the water textures separate between the higgins drive in and
		// the actual landing in the water area, it does not blend well at all."
		//
		// Both halves of that are this stage's fault. This shader covers ONLY the wading band; the
		// run-in is textures/misc_outside/deepbluesea, a different shader with no blood in it. So a
		// flat `alphaGen const` painted the wading band evenly and stopped dead at the join - drawing
		// the boundary rather than hiding it. Measured from the BSP, that join is at Y = -2160, and on
		// these 12 faces T runs 0.005 at the seaward edge to 0.994 at the water's edge. So T is exactly
		// the axis to ramp on: near zero at the seam, strongest where the user asked for it.
		//
		// FOUR PARAMETERS, not two. alphaGen sCoord/tCoord takes min, max, constMin, const - and the
		// last two are the clamps. Every retail use of this keyword supplies only two, which leaves
		// alphaConst at its -1 sentinel and drives the stage to alpha 0 in gl1 and to an
		// undefined-order clamp in gl2 (bug-2226). Supplying all four keeps it well defined in both.
		alphaGen tCoord 0.02 0.60 0 0.60
		// Was 0.42/0.16 - less than one repeat across a 16,000-unit beach, i.e. one smooth blob, i.e. a
		// red filter over the sea. 16 x 2 puts a repeat every ~1000 units across and ~700 deep, so the
		// texture's clear water (58% of it now) actually reads as gaps between slicks.
		tcMod scale 16 2
		tcMod scroll 0.002 -0.008
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
	// NEVER change `sin` to `noise` here: TableForFunc has no GF_NOISE case and calls ri.Error(ERR_DROP).
	{
		ifCvarnot coop_noCrest 1
		nopicmip
		map textures/misc_outside/ocean2a_shore.jpg
		blendFunc add
		rgbGen wave sin 0.55 0.45 0 0.08
		tcMod scale 8 -6
		tcMod scroll 0.01 0.16
		tcMod wavetrant sin 0 0.30 0 0.08
	}
}
