// HZM coop [gore phase A] ARTERY jet art: drawn strings and droplets (docs/proposals/gore_2026-10-05/tools/gen_artery.py).
// [user 2026-10-12] the SAME colour as the mod's other blood (coop_blood.shader: sprays, drips, wound decal, pools -
// 21-25 2-3 0, the #150200 stain hue); it had been baked four times brighter for the sign-off close-up and clashed in play.
// rgbGen identity so the baked hue is what draws; alphaGen vertex so the emitter fades drive alpha.
coop_artery_streak
{
	cull none
	{
		map textures/coop_fx/coop_artery_streak.tga
		blendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA
		rgbGen identity
		alphaGen vertex
	}
}
coop_artery_drop
{
	spriteGen parallel_oriented
	{
		map textures/coop_fx/coop_artery_drop.tga
		blendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA
		rgbGen identity
		alphaGen vertex
	}
}
// [2026-10-11] where an artery streak lands: a crisp lobed blot with satellite drops (the shared coop_bloodsplat shape is
// a soft haze). [2026-10-12] in the shared splat's own colour, SPLAT_RGB (27,3,0). Not named *bloodpool*, and laid by
// the same bouncedecal mark as every drip, so cgame ages and fades it exactly like every other splat.
coop_artery_splat
{
	polygonOffset
	{
		map textures/coop_fx/coop_artery_splat.tga
		blendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA
		rgbGen identity
	}
}
