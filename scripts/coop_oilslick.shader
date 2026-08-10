// [user 2026-08-09] OIL SLICK for the m2l2b sortie finale - grows on the water as she burns.
// Own name + private texture path per the shader-isolation recipe. Alpha-blended so the soft
// irregular edge reads as a slick, not a decal stamp; slight polygonOffset keeps it off the
// water plane without z-fighting.
coop_oilslick
{
	cull none
	polygonOffset
	qer_editorimage textures/coop_fx/oilslick.tga
	{
		map textures/coop_fx/oilslick.tga
		blendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA
		rgbGen identity
	}
}
