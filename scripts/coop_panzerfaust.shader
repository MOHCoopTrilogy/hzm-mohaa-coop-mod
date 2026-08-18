// [user 2026-08-17] East's Panzerfaust. His pk3 ships NO shader - it works by overwriting the
// textures the RETAIL panzerschreck shaders already point at, which would have repainted our
// Panzerschreck, and its Thompson textures would have repainted the Thompson (his sight surface
// reuses the Thompson's 'thompsite' shader). This file gives the gun shaders of its own over
// private textures; the sight is left on the existing thompsite, so no Thompson file is taken.
// Model and animations by East (ds-servers, easts_panzerfaust).

coop_panzerfaust_body
{
	qer_editorimage textures/coop_panzerfaust/pschreck.tga
	{
		map textures/coop_panzerfaust/pschreck.tga
		rgbGen lightingSpherical
	}
}

coop_panzerfaust_rim
{
	qer_editorimage textures/coop_panzerfaust/panzerrim.tga
	{
		map textures/coop_panzerfaust/panzerrim.tga
		rgbGen lightingSpherical
	}
}

coop_panzerfaust_shell
{
	qer_editorimage textures/coop_panzerfaust/pzrshell.tga
	{
		map textures/coop_panzerfaust/pzrshell.tga
		rgbGen lightingSpherical
	}
}
