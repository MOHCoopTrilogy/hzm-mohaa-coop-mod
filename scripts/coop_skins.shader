// [user 2026-08-17] Weapon skin variants. Generated procedurally by docs/tools (see
// _skins/): the base texture is split into a low-frequency shading term and a high-frequency
// detail term, and only the HUE is replaced - which is why the receiver, screws and grain
// survive instead of being flooded over. One block per variant, all prefixed coop_skin_ so a
// third-party pak cannot win the name and leave the gun untextured.

coop_skin_thompsonsmg_gold
{
	qer_editorimage textures/models/weapons/thompsonsmg/thompsonsmg.tga
	{
		map textures/models/weapons/thompsonsmg/thompsonsmg.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const ( 1.00 0.78 0.30 )
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const ( 0.40 0.31 0.12 )
	}
}

coop_skin_thompsonsmg_chrome
{
	qer_editorimage textures/models/weapons/thompsonsmg/thompsonsmg.tga
	{
		map textures/models/weapons/thompsonsmg/thompsonsmg.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const ( 0.88 0.92 0.98 )
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const ( 0.55 0.58 0.64 )
	}
}

coop_skin_thompsonsmg_blued
{
	qer_editorimage textures/models/weapons/thompsonsmg/thompsonsmg.tga
	{
		map textures/models/weapons/thompsonsmg/thompsonsmg.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const ( 0.44 0.48 0.64 )
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const ( 0.10 0.12 0.20 )
	}
}

coop_skin_thompsonsmg_bloody
{
	qer_editorimage textures/coop_skins/thompsonsmg/thompsonsmg_bloody.jpg
	{
		map textures/coop_skins/thompsonsmg/thompsonsmg_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_thompsonsmg_camo_woodland
{
	qer_editorimage textures/coop_skins/thompsonsmg/thompsonsmg_camo_woodland.jpg
	{
		map textures/coop_skins/thompsonsmg/thompsonsmg_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_thompsonsmg_camo_winter
{
	qer_editorimage textures/coop_skins/thompsonsmg/thompsonsmg_camo_winter.jpg
	{
		map textures/coop_skins/thompsonsmg/thompsonsmg_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_thompsonsmg_camo_desert
{
	qer_editorimage textures/coop_skins/thompsonsmg/thompsonsmg_camo_desert.jpg
	{
		map textures/coop_skins/thompsonsmg/thompsonsmg_camo_desert.jpg
		rgbGen lightingSpherical
	}
}
