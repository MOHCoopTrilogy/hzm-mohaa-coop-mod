// HZM coop [2026-09-26] SEARCHLIGHTS S2 (docs/proposals/searchlights_2026-09-26/plan_searchlights.md).
// The Normandy (t1l1) sky beams - models/animate/searchlight.tik and searchlight_small.tik - drawn with this in
// place of retail long_searchlight (blendfunc blend + rgbGen lightingSpherical: a translucent tube with hard sides,
// on gl2 lit from an origin under the terrain). Applied ONLY by cgame (cg_view.c CG_HL_SkyBeamShader, through
// refEntity customShader) on gl2 while r_hzmRgbGenDot resolves on, never on Omaha; otherwise retail draws as before.
// rgbGen dot 0 1: rgb = (N.V)^2, so the cone's silhouette fades to nothing and its face carries the light - the soft
// shaft. Additive, scaled by the retail texture's alpha ramp along the length. nofog is kept from retail, so the
// beams stay visible out to t1l1's 5000 u farplane. The name is defined ONLY here (TRAPS T6).
coop_searchlight_skybeam
{
	qer_editorimage textures/models/animate/searchlight/searchlight.tga
	{
		map textures/models/animate/searchlight/searchlight.tga
		blendFunc GL_SRC_ALPHA GL_ONE
		rgbGen dot 0 1
		nofog
	}
}
