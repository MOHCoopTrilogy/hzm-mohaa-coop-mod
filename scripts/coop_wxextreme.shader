// HZM coop [2026-10-12] BLIZZARD / DOWNPOUR VEIL - the per-player sheet skins of models/emitters/coop_dustveil_snow*.tik
// and coop_dustveil_rain*.tik (coop_mod/wxextreme.scr; the sheet machinery is coop_mod/duststorm.scr's).
// The same recipe as coop_dustveil_night (scripts/coop_duststorm.shader): the moonveil frames carry the pattern in
// ALPHA with white RGB, so rgbGen constant IS the veil colour; alphaGen entity lets the script fade it; sort nearest +
// cull none because the camera sits inside the cube. No new textures.
//   snow       a pale grey-blue            snownight   moonlit snow, under the headlight 'dark' gate
//   rain       grey spray                  rainnight   dark grey spray
// These names are defined here and nowhere else (TRAPS T6 - one coop file per shader name).

coop_dustveil_snow
{
	nomipmaps
	cull none
	sort nearest
	surfaceparm nolightmap
	surfaceparm noimpact
	surfaceparm nomarks
	{
		animmap 15 textures/coop_dust/moonveil0001.tga textures/coop_dust/moonveil0002.tga textures/coop_dust/moonveil0003.tga textures/coop_dust/moonveil0004.tga textures/coop_dust/moonveil0005.tga textures/coop_dust/moonveil0006.tga textures/coop_dust/moonveil0007.tga textures/coop_dust/moonveil0008.tga textures/coop_dust/moonveil0009.tga textures/coop_dust/moonveil0010.tga textures/coop_dust/moonveil0011.tga textures/coop_dust/moonveil0012.tga textures/coop_dust/moonveil0013.tga textures/coop_dust/moonveil0014.tga textures/coop_dust/moonveil0015.tga textures/coop_dust/moonveil0016.tga textures/coop_dust/moonveil0017.tga textures/coop_dust/moonveil0018.tga textures/coop_dust/moonveil0019.tga textures/coop_dust/moonveil0020.tga textures/coop_dust/moonveil0021.tga textures/coop_dust/moonveil0022.tga textures/coop_dust/moonveil0023.tga textures/coop_dust/moonveil0024.tga textures/coop_dust/moonveil0025.tga textures/coop_dust/moonveil0026.tga textures/coop_dust/moonveil0027.tga textures/coop_dust/moonveil0028.tga textures/coop_dust/moonveil0029.tga textures/coop_dust/moonveil0030.tga
		blendFunc blend
		rgbGen constant .66 .69 .76
		alphaGen entity
	}
}

coop_dustveil_snownight
{
	nomipmaps
	cull none
	sort nearest
	surfaceparm nolightmap
	surfaceparm noimpact
	surfaceparm nomarks
	{
		animmap 15 textures/coop_dust/moonveil0001.tga textures/coop_dust/moonveil0002.tga textures/coop_dust/moonveil0003.tga textures/coop_dust/moonveil0004.tga textures/coop_dust/moonveil0005.tga textures/coop_dust/moonveil0006.tga textures/coop_dust/moonveil0007.tga textures/coop_dust/moonveil0008.tga textures/coop_dust/moonveil0009.tga textures/coop_dust/moonveil0010.tga textures/coop_dust/moonveil0011.tga textures/coop_dust/moonveil0012.tga textures/coop_dust/moonveil0013.tga textures/coop_dust/moonveil0014.tga textures/coop_dust/moonveil0015.tga textures/coop_dust/moonveil0016.tga textures/coop_dust/moonveil0017.tga textures/coop_dust/moonveil0018.tga textures/coop_dust/moonveil0019.tga textures/coop_dust/moonveil0020.tga textures/coop_dust/moonveil0021.tga textures/coop_dust/moonveil0022.tga textures/coop_dust/moonveil0023.tga textures/coop_dust/moonveil0024.tga textures/coop_dust/moonveil0025.tga textures/coop_dust/moonveil0026.tga textures/coop_dust/moonveil0027.tga textures/coop_dust/moonveil0028.tga textures/coop_dust/moonveil0029.tga textures/coop_dust/moonveil0030.tga
		blendFunc blend
		rgbGen constant .27 .29 .34
		alphaGen entity
	}
}

coop_dustveil_rain
{
	nomipmaps
	cull none
	sort nearest
	surfaceparm nolightmap
	surfaceparm noimpact
	surfaceparm nomarks
	{
		animmap 15 textures/coop_dust/moonveil0001.tga textures/coop_dust/moonveil0002.tga textures/coop_dust/moonveil0003.tga textures/coop_dust/moonveil0004.tga textures/coop_dust/moonveil0005.tga textures/coop_dust/moonveil0006.tga textures/coop_dust/moonveil0007.tga textures/coop_dust/moonveil0008.tga textures/coop_dust/moonveil0009.tga textures/coop_dust/moonveil0010.tga textures/coop_dust/moonveil0011.tga textures/coop_dust/moonveil0012.tga textures/coop_dust/moonveil0013.tga textures/coop_dust/moonveil0014.tga textures/coop_dust/moonveil0015.tga textures/coop_dust/moonveil0016.tga textures/coop_dust/moonveil0017.tga textures/coop_dust/moonveil0018.tga textures/coop_dust/moonveil0019.tga textures/coop_dust/moonveil0020.tga textures/coop_dust/moonveil0021.tga textures/coop_dust/moonveil0022.tga textures/coop_dust/moonveil0023.tga textures/coop_dust/moonveil0024.tga textures/coop_dust/moonveil0025.tga textures/coop_dust/moonveil0026.tga textures/coop_dust/moonveil0027.tga textures/coop_dust/moonveil0028.tga textures/coop_dust/moonveil0029.tga textures/coop_dust/moonveil0030.tga
		blendFunc blend
		rgbGen constant .46 .49 .54
		alphaGen entity
	}
}

coop_dustveil_rainnight
{
	nomipmaps
	cull none
	sort nearest
	surfaceparm nolightmap
	surfaceparm noimpact
	surfaceparm nomarks
	{
		animmap 15 textures/coop_dust/moonveil0001.tga textures/coop_dust/moonveil0002.tga textures/coop_dust/moonveil0003.tga textures/coop_dust/moonveil0004.tga textures/coop_dust/moonveil0005.tga textures/coop_dust/moonveil0006.tga textures/coop_dust/moonveil0007.tga textures/coop_dust/moonveil0008.tga textures/coop_dust/moonveil0009.tga textures/coop_dust/moonveil0010.tga textures/coop_dust/moonveil0011.tga textures/coop_dust/moonveil0012.tga textures/coop_dust/moonveil0013.tga textures/coop_dust/moonveil0014.tga textures/coop_dust/moonveil0015.tga textures/coop_dust/moonveil0016.tga textures/coop_dust/moonveil0017.tga textures/coop_dust/moonveil0018.tga textures/coop_dust/moonveil0019.tga textures/coop_dust/moonveil0020.tga textures/coop_dust/moonveil0021.tga textures/coop_dust/moonveil0022.tga textures/coop_dust/moonveil0023.tga textures/coop_dust/moonveil0024.tga textures/coop_dust/moonveil0025.tga textures/coop_dust/moonveil0026.tga textures/coop_dust/moonveil0027.tga textures/coop_dust/moonveil0028.tga textures/coop_dust/moonveil0029.tga textures/coop_dust/moonveil0030.tga
		blendFunc blend
		rgbGen constant .16 .17 .20
		alphaGen entity
	}
}

// BLIZZARD STREAK - what the flakes are drawn with above strength 0.35 (wxextreme.scr sets rain_shader to
// textures/coop_snowgust with rain_numshaders 1, the engine appends the 0). The mod's soft flake dot
// (textures/coop_snow.tga), blended, depth-tested, taking the beam's colour. NOT autosprite: the quad lies along
// the flake's path, so a fast flake is a soft streak 13 x 3 units. "snow" in the name keeps the lens dry
// (cg_view.c CG_CoopPrecipType).

textures/coop_snowgust0
{
	surfaceparm nolightmap
	surfaceparm nonsolid
	surfaceparm trans
	surfaceparm nomarks
	cull none
	{
		map textures/coop_snow.tga
		blendFunc blend
		rgbGen vertex
		alphaGen vertex
	}
}
