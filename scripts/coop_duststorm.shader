// HZM coop [2026-09-26, bug-2963] DUST STORM VEIL - the sand sheet skin of models/emitters/coop_dustveil_*.tik
// (coop_mod/duststorm.scr). One stage animating the retail sheet frames (textures/sprites/sandB0001-0030,
// maintt pak1 - no new textures) exactly as retail scripts/sandstorm.shader sandstorm_fadeIn does, with:
//   - alphaGen entity: the script fades the sheet with `alpha` (works on gl1 and gl2 - on gl2 it is a uniform,
//     so the lightall merge that drops alphaGen sCoord/tCoord (bug-2486) does not touch it);
//   - sort nearest + cull none: the camera sits INSIDE the cube;
//   - no spritegen: this is a model surface, not a sprite.
// Day uses retail's .75 sheet colour; night is pulled down so the sheet reads as dark dust at night.
// These names are defined here and nowhere else (TRAPS T6 - one coop file per shader name).

coop_dustveil_day
{
	nomipmaps
	cull none
	sort nearest
	surfaceparm nolightmap
	surfaceparm noimpact
	surfaceparm nomarks
	{
		animmap 15 textures/sprites/sandB0001.tga textures/sprites/sandB0002.tga textures/sprites/sandB0003.tga textures/sprites/sandB0004.tga textures/sprites/sandB0005.tga textures/sprites/sandB0006.tga textures/sprites/sandB0007.tga textures/sprites/sandB0008.tga textures/sprites/sandB0009.tga textures/sprites/sandB0010.tga textures/sprites/sandB0011.tga textures/sprites/sandB0012.tga textures/sprites/sandB0013.tga textures/sprites/sandB0014.tga textures/sprites/sandB0015.tga textures/sprites/sandB0016.tga textures/sprites/sandB0017.tga textures/sprites/sandB0018.tga textures/sprites/sandB0019.tga textures/sprites/sandB0020.tga textures/sprites/sandB0021.tga textures/sprites/sandB0022.tga textures/sprites/sandB0023.tga textures/sprites/sandB0024.tga textures/sprites/sandB0025.tga textures/sprites/sandB0026.tga textures/sprites/sandB0027.tga textures/sprites/sandB0028.tga textures/sprites/sandB0029.tga textures/sprites/sandB0030.tga
		blendFunc blend
		rgbGen constant .75 .75 .75
		alphaGen entity
	}
}

coop_dustveil_night
{
	nomipmaps
	cull none
	sort nearest
	surfaceparm nolightmap
	surfaceparm noimpact
	surfaceparm nomarks
	{
		animmap 15 textures/sprites/sandB0001.tga textures/sprites/sandB0002.tga textures/sprites/sandB0003.tga textures/sprites/sandB0004.tga textures/sprites/sandB0005.tga textures/sprites/sandB0006.tga textures/sprites/sandB0007.tga textures/sprites/sandB0008.tga textures/sprites/sandB0009.tga textures/sprites/sandB0010.tga textures/sprites/sandB0011.tga textures/sprites/sandB0012.tga textures/sprites/sandB0013.tga textures/sprites/sandB0014.tga textures/sprites/sandB0015.tga textures/sprites/sandB0016.tga textures/sprites/sandB0017.tga textures/sprites/sandB0018.tga textures/sprites/sandB0019.tga textures/sprites/sandB0020.tga textures/sprites/sandB0021.tga textures/sprites/sandB0022.tga textures/sprites/sandB0023.tga textures/sprites/sandB0024.tga textures/sprites/sandB0025.tga textures/sprites/sandB0026.tga textures/sprites/sandB0027.tga textures/sprites/sandB0028.tga textures/sprites/sandB0029.tga textures/sprites/sandB0030.tga
		blendFunc blend
		rgbGen constant .3 .3 .3
		alphaGen entity
	}
}
