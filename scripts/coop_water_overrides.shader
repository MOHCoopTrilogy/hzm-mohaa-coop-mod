// HZM coop - per-shader water overrides. Loaded from the mod's own pk3, so a same-named shader
// here takes priority over the stock definition in main/Pak0.pk3's scripts/misc_outside.shader.
//
// [user 08-07] northafrika_shoreline (m1l3c's ocean) reverted to its PRE-07-29-fix look. The
// engine-level fix (bug-1242/1249, openmohaa-hzm renderergl2) made alphaGen tCoord and
// tcMod wavetrant actually WORK on gl2 - they were parsed-but-ignored before, which is why the
// blended shore-wash/fade layers below rendered fully opaque/static pre-fix. That engine fix
// stays in place (deepbluesea_shoreline / afrika_shoreline / m3l1a still need it - reverting it
// globally would reintroduce hard waterlines + static wash there). This override just removes
// the alphaGen/wavetrant lines from THIS one shader, so the renderer has nothing to act on here
// specifically, reproducing the old opaque/static look without touching the shared fix.
// Original block: scripts/misc_outside.shader (Pak0.pk3) - diff is exactly the alphaGen/wavetrant
// lines removed below, everything else (maps, blendFuncs, tcMod scale/scroll, rgbGen) unchanged.
textures/misc_outside/northafrika_shoreline
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
	{
		nopicmip
		map textures/misc_outside/oceandday1.tga
		blendFunc blend
		tcMod scale 16 -5
		tcMod scroll 0.01 -0.034
	nextbundle
		map textures/misc_outside/oceandday1.tga
		tcMod scale -16 -5
		tcMod scroll 0.01 -0.034
	}
	{
		nopicmip
		map textures/misc_outside/oceandday1.tga
		blendFunc GL_SRC_ALPHA GL_ONE
		tcMod scale 0.2 -0.105
		tcMod scroll 0 -0.005
	nextbundle
		map textures/misc_outside/oceandday1.tga
		tcMod scale 0.2 -0.105
		tcMod scroll 0 -0.009
	}
	{
		nopicmip
		map textures/misc_outside/wash2.tga
		blendFunc alphaadd
		rgbGen wave sin .15 .525 .35 -.04
		tcMod scale 3 -1.1
		tcMod scroll 0.01 .0
	nextbundle
		map textures/misc_outside/oceandday1.tga
		tcMod scale 3 -1.1
		tcMod scroll -0.025 -0.025
	}
	{
		nopicmip
		map textures/misc_outside/wash2.tga
		blendFunc alphaadd
		rgbGen wave sin .15 .525 .325 -.04
		tcMod scale -3 -1.1
		tcMod scroll 0.01 .0
	nextbundle
		map textures/misc_outside/oceandday1.tga
		tcMod scale -3 -1.1
		tcMod scroll -0.025 -0.025
	}
	{
		nopicmip
		map textures/misc_outside/wash2.tga
		blendFunc alphaadd
		rgbGen wave sin .15 .525 .85 -.04
		tcMod scale 3 -1.1
		tcMod scroll 0.01 .0
	nextbundle
		map textures/misc_outside/oceandday1.tga
		tcMod scale 3 -1.1
		tcMod scroll -0.025 -0.025
	}
	{
		nopicmip
		map textures/misc_outside/wash2.tga
		blendFunc alphaadd
		rgbGen wave sin .15 .525 .825 -.04
		tcMod scale -3 -1.1
		tcMod scroll 0.01 .0
	nextbundle
		map textures/misc_outside/oceandday1.tga
		tcMod scale -3 -1.1
		tcMod scroll -0.025 -0.025
	}
}
