// HZM coop [gore phase A] ARTERY jet art. Same shapes as coop_blood_long / coop_blood_drop (coop_blood.shader) but baked
// at BLOOD_RGB (150,12,10) - fresh arterial blood - instead of the #150200 stain hue, which renders as black
// flecks in daylight. rgbGen identity so the baked hue is what draws; alphaGen vertex so the emitter fades drive alpha.
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
// [2026-10-11] where an artery streak lands. The shared coop_bloodsplat decal is the flat #150200 stain hue, which is a
// black blot on white plaster; this is the same splat shape baked at SPLAT_RGB (98,6,6). Not named *bloodpool*, so
// cgame fades it like every other splat.
coop_artery_splat
{
	polygonOffset
	{
		map textures/coop_fx/coop_artery_splat.tga
		blendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA
		rgbGen identity
	}
}
