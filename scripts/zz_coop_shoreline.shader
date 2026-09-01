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
}
