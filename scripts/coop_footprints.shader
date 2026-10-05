// HZM coop [user 2026-10-04] FOOTPRINTS in snow, mud and soft dirt - drawn by cgame (cg_footprints.c), never by a map.
//
// Own shader names + private texture paths (the bug-922 isolation recipe). The textures are generated from scratch by
// docs/proposals/footprints_2026-10-04/tools/gen_footprints.py: a RIGHT boot seen from above, toe at the top; cgame
// mirrors s for the left foot. allied = rubber service-shoe sole with a Cat's Paw heel, axis = hobnailed jackboot
// with a heel iron. Soft dry dirt reuses the mud prints at a lower strength.
//
// ONE MULTIPLICATIVE stage: dst * (1 - src). The texture RGB is how much of the ground to take away (zero = untouched),
// the vertex colour is the print's strength and age fade (cgame scales it to 0). It can only darken the lightmapped
// ground beneath, so it reads the same in sun and at night - an alpha-blended print carried its own light-grid
// brightness and showed as a pale outlined sticker on m2l1's dusk snow. clampmap: the art has a zero border.
// polygonOffset against the ground (both renderers); cull none because the poly winding is not oriented.

coop_footprint_snow_allied
{
	cull none
	polygonOffset
	nopicmip
	qer_editorimage textures/coop_fx/footprint_snow_allied.tga
	{
		clampmap textures/coop_fx/footprint_snow_allied.tga
		blendFunc GL_ZERO GL_ONE_MINUS_SRC_COLOR
		rgbGen vertex
	}
}

coop_footprint_snow_axis
{
	cull none
	polygonOffset
	nopicmip
	qer_editorimage textures/coop_fx/footprint_snow_axis.tga
	{
		clampmap textures/coop_fx/footprint_snow_axis.tga
		blendFunc GL_ZERO GL_ONE_MINUS_SRC_COLOR
		rgbGen vertex
	}
}

coop_footprint_mud_allied
{
	cull none
	polygonOffset
	nopicmip
	qer_editorimage textures/coop_fx/footprint_mud_allied.tga
	{
		clampmap textures/coop_fx/footprint_mud_allied.tga
		blendFunc GL_ZERO GL_ONE_MINUS_SRC_COLOR
		rgbGen vertex
	}
}

coop_footprint_mud_axis
{
	cull none
	polygonOffset
	nopicmip
	qer_editorimage textures/coop_fx/footprint_mud_axis.tga
	{
		clampmap textures/coop_fx/footprint_mud_axis.tga
		blendFunc GL_ZERO GL_ONE_MINUS_SRC_COLOR
		rgbGen vertex
	}
}
