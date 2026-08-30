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
}
