// [user 2026-08-17] Weapon skin variants. Generated procedurally by docs/tools (see
// _skins/): the base texture is split into a low-frequency shading term and a high-frequency
// detail term, and only the HUE is replaced - which is why the receiver, screws and grain
// survive instead of being flooded over. One block per variant, all prefixed coop_skin_ so a
// third-party pak cannot win the name and leave the gun untextured.

coop_skin_delisle_gold
{
	qer_editorimage textures/models/weapons/delisle/delisle.jpg
	{
		map textures/models/weapons/delisle/delisle.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_delisle_chrome
{
	qer_editorimage textures/models/weapons/delisle/delisle.jpg
	{
		map textures/models/weapons/delisle/delisle.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_delisle_blued
{
	qer_editorimage textures/models/weapons/delisle/delisle.jpg
	{
		map textures/models/weapons/delisle/delisle.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_delisle_bloody
{
	qer_editorimage textures/coop_skins/delisle/delisle_bloody.jpg
	{
		map textures/coop_skins/delisle/delisle_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_delisle_camo_woodland
{
	qer_editorimage textures/coop_skins/delisle/delisle_camo_woodland.jpg
	{
		map textures/coop_skins/delisle/delisle_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_delisle_camo_winter
{
	qer_editorimage textures/coop_skins/delisle/delisle_camo_winter.jpg
	{
		map textures/coop_skins/delisle/delisle_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_delisle_camo_desert
{
	qer_editorimage textures/coop_skins/delisle/delisle_camo_desert.jpg
	{
		map textures/coop_skins/delisle/delisle_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_fg42_gold
{
	qer_editorimage textures/fg42/fg42.jpg
	{
		map textures/fg42/fg42.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_fg42_chrome
{
	qer_editorimage textures/fg42/fg42.jpg
	{
		map textures/fg42/fg42.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_fg42_blued
{
	qer_editorimage textures/fg42/fg42.jpg
	{
		map textures/fg42/fg42.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_fg42_bloody
{
	qer_editorimage textures/coop_skins/fg42/fg42_bloody.jpg
	{
		map textures/coop_skins/fg42/fg42_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_fg42_camo_woodland
{
	qer_editorimage textures/coop_skins/fg42/fg42_camo_woodland.jpg
	{
		map textures/coop_skins/fg42/fg42_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_fg42_camo_winter
{
	qer_editorimage textures/coop_skins/fg42/fg42_camo_winter.jpg
	{
		map textures/coop_skins/fg42/fg42_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_fg42_camo_desert
{
	qer_editorimage textures/coop_skins/fg42/fg42_camo_desert.jpg
	{
		map textures/coop_skins/fg42/fg42_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_g43_gold
{
	qer_editorimage models/weapons/g43/g43.tga
	{
		map models/weapons/g43/g43.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_g43_chrome
{
	qer_editorimage models/weapons/g43/g43.tga
	{
		map models/weapons/g43/g43.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_g43_blued
{
	qer_editorimage models/weapons/g43/g43.tga
	{
		map models/weapons/g43/g43.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_g43_bloody
{
	qer_editorimage textures/coop_skins/g43/g43_bloody.jpg
	{
		map textures/coop_skins/g43/g43_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_g43_camo_woodland
{
	qer_editorimage textures/coop_skins/g43/g43_camo_woodland.jpg
	{
		map textures/coop_skins/g43/g43_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_g43_camo_winter
{
	qer_editorimage textures/coop_skins/g43/g43_camo_winter.jpg
	{
		map textures/coop_skins/g43/g43_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_g43_camo_desert
{
	qer_editorimage textures/coop_skins/g43/g43_camo_desert.jpg
	{
		map textures/coop_skins/g43/g43_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_gr_w_minedetector_gold
{
	qer_editorimage textures/models/weapons/minedetector/gr_w_minedetector.jpg
	{
		map textures/models/weapons/minedetector/gr_w_minedetector.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_gr_w_minedetector_chrome
{
	qer_editorimage textures/models/weapons/minedetector/gr_w_minedetector.jpg
	{
		map textures/models/weapons/minedetector/gr_w_minedetector.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_gr_w_minedetector_blued
{
	qer_editorimage textures/models/weapons/minedetector/gr_w_minedetector.jpg
	{
		map textures/models/weapons/minedetector/gr_w_minedetector.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_gr_w_minedetector_bloody
{
	qer_editorimage textures/coop_skins/gr_w_minedetector/gr_w_minedetector_bloody.jpg
	{
		map textures/coop_skins/gr_w_minedetector/gr_w_minedetector_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_gr_w_minedetector_camo_woodland
{
	qer_editorimage textures/coop_skins/gr_w_minedetector/gr_w_minedetector_camo_woodland.jpg
	{
		map textures/coop_skins/gr_w_minedetector/gr_w_minedetector_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_gr_w_minedetector_camo_winter
{
	qer_editorimage textures/coop_skins/gr_w_minedetector/gr_w_minedetector_camo_winter.jpg
	{
		map textures/coop_skins/gr_w_minedetector/gr_w_minedetector_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_gr_w_minedetector_camo_desert
{
	qer_editorimage textures/coop_skins/gr_w_minedetector/gr_w_minedetector_camo_desert.jpg
	{
		map textures/coop_skins/gr_w_minedetector/gr_w_minedetector_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_it_w_beretta_gold
{
	qer_editorimage textures/models/weapons/beretta/it_w_beretta.jpg
	{
		map textures/models/weapons/beretta/it_w_beretta.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_it_w_beretta_chrome
{
	qer_editorimage textures/models/weapons/beretta/it_w_beretta.jpg
	{
		map textures/models/weapons/beretta/it_w_beretta.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_it_w_beretta_blued
{
	qer_editorimage textures/models/weapons/beretta/it_w_beretta.jpg
	{
		map textures/models/weapons/beretta/it_w_beretta.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_it_w_beretta_bloody
{
	qer_editorimage textures/coop_skins/it_w_beretta/it_w_beretta_bloody.jpg
	{
		map textures/coop_skins/it_w_beretta/it_w_beretta_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_it_w_beretta_camo_woodland
{
	qer_editorimage textures/coop_skins/it_w_beretta/it_w_beretta_camo_woodland.jpg
	{
		map textures/coop_skins/it_w_beretta/it_w_beretta_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_it_w_beretta_camo_winter
{
	qer_editorimage textures/coop_skins/it_w_beretta/it_w_beretta_camo_winter.jpg
	{
		map textures/coop_skins/it_w_beretta/it_w_beretta_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_it_w_beretta_camo_desert
{
	qer_editorimage textures/coop_skins/it_w_beretta/it_w_beretta_camo_desert.jpg
	{
		map textures/coop_skins/it_w_beretta/it_w_beretta_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_it_w_breda_gold
{
	qer_editorimage textures/models/weapons/breda/it_w_breda.jpg
	{
		map textures/models/weapons/breda/it_w_breda.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_it_w_breda_chrome
{
	qer_editorimage textures/models/weapons/breda/it_w_breda.jpg
	{
		map textures/models/weapons/breda/it_w_breda.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_it_w_breda_blued
{
	qer_editorimage textures/models/weapons/breda/it_w_breda.jpg
	{
		map textures/models/weapons/breda/it_w_breda.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_it_w_breda_bloody
{
	qer_editorimage textures/coop_skins/it_w_breda/it_w_breda_bloody.jpg
	{
		map textures/coop_skins/it_w_breda/it_w_breda_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_it_w_breda_camo_woodland
{
	qer_editorimage textures/coop_skins/it_w_breda/it_w_breda_camo_woodland.jpg
	{
		map textures/coop_skins/it_w_breda/it_w_breda_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_it_w_breda_camo_winter
{
	qer_editorimage textures/coop_skins/it_w_breda/it_w_breda_camo_winter.jpg
	{
		map textures/coop_skins/it_w_breda/it_w_breda_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_it_w_breda_camo_desert
{
	qer_editorimage textures/coop_skins/it_w_breda/it_w_breda_camo_desert.jpg
	{
		map textures/coop_skins/it_w_breda/it_w_breda_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_it_w_carcano_gold
{
	qer_editorimage textures/models/weapons/carcano/it_w_carcano.jpg
	{
		map textures/models/weapons/carcano/it_w_carcano.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_it_w_carcano_chrome
{
	qer_editorimage textures/models/weapons/carcano/it_w_carcano.jpg
	{
		map textures/models/weapons/carcano/it_w_carcano.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_it_w_carcano_blued
{
	qer_editorimage textures/models/weapons/carcano/it_w_carcano.jpg
	{
		map textures/models/weapons/carcano/it_w_carcano.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_it_w_carcano_bloody
{
	qer_editorimage textures/coop_skins/it_w_carcano/it_w_carcano_bloody.jpg
	{
		map textures/coop_skins/it_w_carcano/it_w_carcano_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_it_w_carcano_camo_woodland
{
	qer_editorimage textures/coop_skins/it_w_carcano/it_w_carcano_camo_woodland.jpg
	{
		map textures/coop_skins/it_w_carcano/it_w_carcano_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_it_w_carcano_camo_winter
{
	qer_editorimage textures/coop_skins/it_w_carcano/it_w_carcano_camo_winter.jpg
	{
		map textures/coop_skins/it_w_carcano/it_w_carcano_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_it_w_carcano_camo_desert
{
	qer_editorimage textures/coop_skins/it_w_carcano/it_w_carcano_camo_desert.jpg
	{
		map textures/coop_skins/it_w_carcano/it_w_carcano_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_it_w_carcano_lite_gold
{
	qer_editorimage textures/models/weapons/carcano/it_w_carcano.jpg
	{
		map textures/models/weapons/carcano/it_w_carcano.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_it_w_carcano_lite_chrome
{
	qer_editorimage textures/models/weapons/carcano/it_w_carcano.jpg
	{
		map textures/models/weapons/carcano/it_w_carcano.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_it_w_carcano_lite_blued
{
	qer_editorimage textures/models/weapons/carcano/it_w_carcano.jpg
	{
		map textures/models/weapons/carcano/it_w_carcano.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_it_w_carcano_lite_bloody
{
	qer_editorimage textures/coop_skins/it_w_carcano_lite/it_w_carcano_bloody.jpg
	{
		map textures/coop_skins/it_w_carcano_lite/it_w_carcano_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_it_w_carcano_lite_camo_woodland
{
	qer_editorimage textures/coop_skins/it_w_carcano_lite/it_w_carcano_camo_woodland.jpg
	{
		map textures/coop_skins/it_w_carcano_lite/it_w_carcano_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_it_w_carcano_lite_camo_winter
{
	qer_editorimage textures/coop_skins/it_w_carcano_lite/it_w_carcano_camo_winter.jpg
	{
		map textures/coop_skins/it_w_carcano_lite/it_w_carcano_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_it_w_carcano_lite_camo_desert
{
	qer_editorimage textures/coop_skins/it_w_carcano_lite/it_w_carcano_camo_desert.jpg
	{
		map textures/coop_skins/it_w_carcano_lite/it_w_carcano_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_it_w_moschetto_gold
{
	qer_editorimage textures/models/weapons/moschetto/it_w_moschetto.jpg
	{
		map textures/models/weapons/moschetto/it_w_moschetto.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_it_w_moschetto_chrome
{
	qer_editorimage textures/models/weapons/moschetto/it_w_moschetto.jpg
	{
		map textures/models/weapons/moschetto/it_w_moschetto.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_it_w_moschetto_blued
{
	qer_editorimage textures/models/weapons/moschetto/it_w_moschetto.jpg
	{
		map textures/models/weapons/moschetto/it_w_moschetto.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_it_w_moschetto_bloody
{
	qer_editorimage textures/coop_skins/it_w_moschetto/it_w_moschetto_bloody.jpg
	{
		map textures/coop_skins/it_w_moschetto/it_w_moschetto_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_it_w_moschetto_camo_woodland
{
	qer_editorimage textures/coop_skins/it_w_moschetto/it_w_moschetto_camo_woodland.jpg
	{
		map textures/coop_skins/it_w_moschetto/it_w_moschetto_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_it_w_moschetto_camo_winter
{
	qer_editorimage textures/coop_skins/it_w_moschetto/it_w_moschetto_camo_winter.jpg
	{
		map textures/coop_skins/it_w_moschetto/it_w_moschetto_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_it_w_moschetto_camo_desert
{
	qer_editorimage textures/coop_skins/it_w_moschetto/it_w_moschetto_camo_desert.jpg
	{
		map textures/coop_skins/it_w_moschetto/it_w_moschetto_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98sniper_gold
{
	qer_editorimage textures/models/weapons/kar98/kar98scope.tga
	{
		map textures/models/weapons/kar98/kar98scope.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_kar98sniper_chrome
{
	qer_editorimage textures/models/weapons/kar98/kar98scope.tga
	{
		map textures/models/weapons/kar98/kar98scope.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_kar98sniper_blued
{
	qer_editorimage textures/models/weapons/kar98/kar98scope.tga
	{
		map textures/models/weapons/kar98/kar98scope.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_kar98sniper_bloody
{
	qer_editorimage textures/coop_skins/kar98sniper/kar98scope_bloody.jpg
	{
		map textures/coop_skins/kar98sniper/kar98scope_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98sniper_camo_woodland
{
	qer_editorimage textures/coop_skins/kar98sniper/kar98scope_camo_woodland.jpg
	{
		map textures/coop_skins/kar98sniper/kar98scope_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98sniper_camo_winter
{
	qer_editorimage textures/coop_skins/kar98sniper/kar98scope_camo_winter.jpg
	{
		map textures/coop_skins/kar98sniper/kar98scope_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98sniper_camo_desert
{
	qer_editorimage textures/coop_skins/kar98sniper/kar98scope_camo_desert.jpg
	{
		map textures/coop_skins/kar98sniper/kar98scope_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mosin_nagant_rifle_gold
{
	qer_editorimage models/weapons/mosin_nagant/mosin_nagant.jpg
	{
		map models/weapons/mosin_nagant/mosin_nagant.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_mosin_nagant_rifle_chrome
{
	qer_editorimage models/weapons/mosin_nagant/mosin_nagant.jpg
	{
		map models/weapons/mosin_nagant/mosin_nagant.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_mosin_nagant_rifle_blued
{
	qer_editorimage models/weapons/mosin_nagant/mosin_nagant.jpg
	{
		map models/weapons/mosin_nagant/mosin_nagant.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_mosin_nagant_rifle_bloody
{
	qer_editorimage textures/coop_skins/mosin_nagant_rifle/mosin_nagant_bloody.jpg
	{
		map textures/coop_skins/mosin_nagant_rifle/mosin_nagant_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mosin_nagant_rifle_camo_woodland
{
	qer_editorimage textures/coop_skins/mosin_nagant_rifle/mosin_nagant_camo_woodland.jpg
	{
		map textures/coop_skins/mosin_nagant_rifle/mosin_nagant_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mosin_nagant_rifle_camo_winter
{
	qer_editorimage textures/coop_skins/mosin_nagant_rifle/mosin_nagant_camo_winter.jpg
	{
		map textures/coop_skins/mosin_nagant_rifle/mosin_nagant_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mosin_nagant_rifle_camo_desert
{
	qer_editorimage textures/coop_skins/mosin_nagant_rifle/mosin_nagant_camo_desert.jpg
	{
		map textures/coop_skins/mosin_nagant_rifle/mosin_nagant_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mosin_nagant_rifle_lite_gold
{
	qer_editorimage models/weapons/mosin_nagant/mosin_nagant.jpg
	{
		map models/weapons/mosin_nagant/mosin_nagant.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_mosin_nagant_rifle_lite_chrome
{
	qer_editorimage models/weapons/mosin_nagant/mosin_nagant.jpg
	{
		map models/weapons/mosin_nagant/mosin_nagant.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_mosin_nagant_rifle_lite_blued
{
	qer_editorimage models/weapons/mosin_nagant/mosin_nagant.jpg
	{
		map models/weapons/mosin_nagant/mosin_nagant.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_mosin_nagant_rifle_lite_bloody
{
	qer_editorimage textures/coop_skins/mosin_nagant_rifle_lite/mosin_nagant_bloody.jpg
	{
		map textures/coop_skins/mosin_nagant_rifle_lite/mosin_nagant_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mosin_nagant_rifle_lite_camo_woodland
{
	qer_editorimage textures/coop_skins/mosin_nagant_rifle_lite/mosin_nagant_camo_woodland.jpg
	{
		map textures/coop_skins/mosin_nagant_rifle_lite/mosin_nagant_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mosin_nagant_rifle_lite_camo_winter
{
	qer_editorimage textures/coop_skins/mosin_nagant_rifle_lite/mosin_nagant_camo_winter.jpg
	{
		map textures/coop_skins/mosin_nagant_rifle_lite/mosin_nagant_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mosin_nagant_rifle_lite_camo_desert
{
	qer_editorimage textures/coop_skins/mosin_nagant_rifle_lite/mosin_nagant_camo_desert.jpg
	{
		map textures/coop_skins/mosin_nagant_rifle_lite/mosin_nagant_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_nagant_revolver_gold
{
	qer_editorimage textures/models/weapons/nagentrevolver.tga
	{
		map textures/models/weapons/nagentrevolver.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_nagant_revolver_chrome
{
	qer_editorimage textures/models/weapons/nagentrevolver.tga
	{
		map textures/models/weapons/nagentrevolver.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_nagant_revolver_blued
{
	qer_editorimage textures/models/weapons/nagentrevolver.tga
	{
		map textures/models/weapons/nagentrevolver.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_nagant_revolver_bloody
{
	qer_editorimage textures/coop_skins/nagant_revolver/nagentrevolver_bloody.jpg
	{
		map textures/coop_skins/nagant_revolver/nagentrevolver_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_nagant_revolver_camo_woodland
{
	qer_editorimage textures/coop_skins/nagant_revolver/nagentrevolver_camo_woodland.jpg
	{
		map textures/coop_skins/nagant_revolver/nagentrevolver_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_nagant_revolver_camo_winter
{
	qer_editorimage textures/coop_skins/nagant_revolver/nagentrevolver_camo_winter.jpg
	{
		map textures/coop_skins/nagant_revolver/nagentrevolver_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_nagant_revolver_camo_desert
{
	qer_editorimage textures/coop_skins/nagant_revolver/nagentrevolver_camo_desert.jpg
	{
		map textures/coop_skins/nagant_revolver/nagentrevolver_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_us_w_minedetector_gold
{
	qer_editorimage textures/models/weapons/minedetector/us_w_minedetector.jpg
	{
		map textures/models/weapons/minedetector/us_w_minedetector.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_us_w_minedetector_chrome
{
	qer_editorimage textures/models/weapons/minedetector/us_w_minedetector.jpg
	{
		map textures/models/weapons/minedetector/us_w_minedetector.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_us_w_minedetector_blued
{
	qer_editorimage textures/models/weapons/minedetector/us_w_minedetector.jpg
	{
		map textures/models/weapons/minedetector/us_w_minedetector.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_us_w_minedetector_bloody
{
	qer_editorimage textures/coop_skins/us_w_minedetector/us_w_minedetector_bloody.jpg
	{
		map textures/coop_skins/us_w_minedetector/us_w_minedetector_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_us_w_minedetector_camo_woodland
{
	qer_editorimage textures/coop_skins/us_w_minedetector/us_w_minedetector_camo_woodland.jpg
	{
		map textures/coop_skins/us_w_minedetector/us_w_minedetector_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_us_w_minedetector_camo_winter
{
	qer_editorimage textures/coop_skins/us_w_minedetector/us_w_minedetector_camo_winter.jpg
	{
		map textures/coop_skins/us_w_minedetector/us_w_minedetector_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_us_w_minedetector_camo_desert
{
	qer_editorimage textures/coop_skins/us_w_minedetector/us_w_minedetector_camo_desert.jpg
	{
		map textures/coop_skins/us_w_minedetector/us_w_minedetector_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_uk_w_l42a1_gold
{
	qer_editorimage textures/models/weapons/enfield_l42a1/uk_w_l42a1.jpg
	{
		map textures/models/weapons/enfield_l42a1/uk_w_l42a1.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_uk_w_l42a1_chrome
{
	qer_editorimage textures/models/weapons/enfield_l42a1/uk_w_l42a1.jpg
	{
		map textures/models/weapons/enfield_l42a1/uk_w_l42a1.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_uk_w_l42a1_blued
{
	qer_editorimage textures/models/weapons/enfield_l42a1/uk_w_l42a1.jpg
	{
		map textures/models/weapons/enfield_l42a1/uk_w_l42a1.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_uk_w_l42a1_bloody
{
	qer_editorimage textures/coop_skins/uk_w_l42a1/uk_w_l42a1_bloody.jpg
	{
		map textures/coop_skins/uk_w_l42a1/uk_w_l42a1_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_uk_w_l42a1_camo_woodland
{
	qer_editorimage textures/coop_skins/uk_w_l42a1/uk_w_l42a1_camo_woodland.jpg
	{
		map textures/coop_skins/uk_w_l42a1/uk_w_l42a1_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_uk_w_l42a1_camo_winter
{
	qer_editorimage textures/coop_skins/uk_w_l42a1/uk_w_l42a1_camo_winter.jpg
	{
		map textures/coop_skins/uk_w_l42a1/uk_w_l42a1_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_uk_w_l42a1_camo_desert
{
	qer_editorimage textures/coop_skins/uk_w_l42a1/uk_w_l42a1_camo_desert.jpg
	{
		map textures/coop_skins/uk_w_l42a1/uk_w_l42a1_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_uk_w_piat_gold_0
{
	qer_editorimage textures/models/weapons/piat/uk_w_piat.jpg
	{
		map textures/models/weapons/piat/uk_w_piat.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_uk_w_piat_gold_1
{
	qer_editorimage textures/models/weapons/piat/uk_w_piatrocket.jpg
	{
		map textures/models/weapons/piat/uk_w_piatrocket.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_uk_w_piat_chrome_0
{
	qer_editorimage textures/models/weapons/piat/uk_w_piat.jpg
	{
		map textures/models/weapons/piat/uk_w_piat.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_uk_w_piat_chrome_1
{
	qer_editorimage textures/models/weapons/piat/uk_w_piatrocket.jpg
	{
		map textures/models/weapons/piat/uk_w_piatrocket.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_uk_w_piat_blued_0
{
	qer_editorimage textures/models/weapons/piat/uk_w_piat.jpg
	{
		map textures/models/weapons/piat/uk_w_piat.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_uk_w_piat_blued_1
{
	qer_editorimage textures/models/weapons/piat/uk_w_piatrocket.jpg
	{
		map textures/models/weapons/piat/uk_w_piatrocket.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_uk_w_piat_bloody_0
{
	qer_editorimage textures/coop_skins/uk_w_piat/uk_w_piat_bloody.jpg
	{
		map textures/coop_skins/uk_w_piat/uk_w_piat_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_uk_w_piat_bloody_1
{
	qer_editorimage textures/coop_skins/uk_w_piat/uk_w_piatrocket_bloody.jpg
	{
		map textures/coop_skins/uk_w_piat/uk_w_piatrocket_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_uk_w_piat_camo_woodland_0
{
	qer_editorimage textures/coop_skins/uk_w_piat/uk_w_piat_camo_woodland.jpg
	{
		map textures/coop_skins/uk_w_piat/uk_w_piat_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_uk_w_piat_camo_woodland_1
{
	qer_editorimage textures/coop_skins/uk_w_piat/uk_w_piatrocket_camo_woodland.jpg
	{
		map textures/coop_skins/uk_w_piat/uk_w_piatrocket_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_uk_w_piat_camo_winter_0
{
	qer_editorimage textures/coop_skins/uk_w_piat/uk_w_piat_camo_winter.jpg
	{
		map textures/coop_skins/uk_w_piat/uk_w_piat_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_uk_w_piat_camo_winter_1
{
	qer_editorimage textures/coop_skins/uk_w_piat/uk_w_piatrocket_camo_winter.jpg
	{
		map textures/coop_skins/uk_w_piat/uk_w_piatrocket_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_uk_w_piat_camo_desert_0
{
	qer_editorimage textures/coop_skins/uk_w_piat/uk_w_piat_camo_desert.jpg
	{
		map textures/coop_skins/uk_w_piat/uk_w_piat_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_uk_w_piat_camo_desert_1
{
	qer_editorimage textures/coop_skins/uk_w_piat/uk_w_piatrocket_camo_desert.jpg
	{
		map textures/coop_skins/uk_w_piat/uk_w_piatrocket_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_uk_w_vickers_gold
{
	qer_editorimage textures/models/weapons/vickers/uk_w_vickers.jpg
	{
		map textures/models/weapons/vickers/uk_w_vickers.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_uk_w_vickers_chrome
{
	qer_editorimage textures/models/weapons/vickers/uk_w_vickers.jpg
	{
		map textures/models/weapons/vickers/uk_w_vickers.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_uk_w_vickers_blued
{
	qer_editorimage textures/models/weapons/vickers/uk_w_vickers.jpg
	{
		map textures/models/weapons/vickers/uk_w_vickers.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_uk_w_vickers_bloody
{
	qer_editorimage textures/coop_skins/uk_w_vickers/uk_w_vickers_bloody.jpg
	{
		map textures/coop_skins/uk_w_vickers/uk_w_vickers_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_uk_w_vickers_camo_woodland
{
	qer_editorimage textures/coop_skins/uk_w_vickers/uk_w_vickers_camo_woodland.jpg
	{
		map textures/coop_skins/uk_w_vickers/uk_w_vickers_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_uk_w_vickers_camo_winter
{
	qer_editorimage textures/coop_skins/uk_w_vickers/uk_w_vickers_camo_winter.jpg
	{
		map textures/coop_skins/uk_w_vickers/uk_w_vickers_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_uk_w_vickers_camo_desert
{
	qer_editorimage textures/coop_skins/uk_w_vickers/uk_w_vickers_camo_desert.jpg
	{
		map textures/coop_skins/uk_w_vickers/uk_w_vickers_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_webley_revolver_gold_1
{
	qer_editorimage textures/models/weapons/webley.jpg
	{
		map textures/models/weapons/webley.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_webley_revolver_gold_0
{
	qer_editorimage models/ammo/shell/shell.tga
	{
		map models/ammo/shell/shell.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_webley_revolver_chrome_1
{
	qer_editorimage textures/models/weapons/webley.jpg
	{
		map textures/models/weapons/webley.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_webley_revolver_chrome_0
{
	qer_editorimage models/ammo/shell/shell.tga
	{
		map models/ammo/shell/shell.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_webley_revolver_blued_1
{
	qer_editorimage textures/models/weapons/webley.jpg
	{
		map textures/models/weapons/webley.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_webley_revolver_blued_0
{
	qer_editorimage models/ammo/shell/shell.tga
	{
		map models/ammo/shell/shell.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_webley_revolver_bloody_1
{
	qer_editorimage textures/coop_skins/webley_revolver/webley_bloody.jpg
	{
		map textures/coop_skins/webley_revolver/webley_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_webley_revolver_bloody_0
{
	qer_editorimage textures/coop_skins/webley_revolver/shell_bloody.jpg
	{
		map textures/coop_skins/webley_revolver/shell_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_webley_revolver_camo_woodland_1
{
	qer_editorimage textures/coop_skins/webley_revolver/webley_camo_woodland.jpg
	{
		map textures/coop_skins/webley_revolver/webley_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_webley_revolver_camo_woodland_0
{
	qer_editorimage textures/coop_skins/webley_revolver/shell_camo_woodland.jpg
	{
		map textures/coop_skins/webley_revolver/shell_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_webley_revolver_camo_winter_1
{
	qer_editorimage textures/coop_skins/webley_revolver/webley_camo_winter.jpg
	{
		map textures/coop_skins/webley_revolver/webley_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_webley_revolver_camo_winter_0
{
	qer_editorimage textures/coop_skins/webley_revolver/shell_camo_winter.jpg
	{
		map textures/coop_skins/webley_revolver/shell_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_webley_revolver_camo_desert_1
{
	qer_editorimage textures/coop_skins/webley_revolver/webley_camo_desert.jpg
	{
		map textures/coop_skins/webley_revolver/webley_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_webley_revolver_camo_desert_0
{
	qer_editorimage textures/coop_skins/webley_revolver/shell_camo_desert.jpg
	{
		map textures/coop_skins/webley_revolver/shell_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_bar_gold_1
{
	qer_editorimage textures/models/weapons/bar/s93_bar.tga
	{
		map textures/models/weapons/bar/s93_bar.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_bar_gold_0
{
	qer_editorimage textures/models/weapons/bar/s93_bar-bipod.tga
	{
		map textures/models/weapons/bar/s93_bar-bipod.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_bar_chrome_1
{
	qer_editorimage textures/models/weapons/bar/s93_bar.tga
	{
		map textures/models/weapons/bar/s93_bar.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_bar_chrome_0
{
	qer_editorimage textures/models/weapons/bar/s93_bar-bipod.tga
	{
		map textures/models/weapons/bar/s93_bar-bipod.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_bar_blued_1
{
	qer_editorimage textures/models/weapons/bar/s93_bar.tga
	{
		map textures/models/weapons/bar/s93_bar.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_bar_blued_0
{
	qer_editorimage textures/models/weapons/bar/s93_bar-bipod.tga
	{
		map textures/models/weapons/bar/s93_bar-bipod.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_bar_bloody_1
{
	qer_editorimage textures/coop_skins/bar/s93_bar_bloody.jpg
	{
		map textures/coop_skins/bar/s93_bar_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_bar_bloody_0
{
	qer_editorimage textures/coop_skins/bar/s93_bar-bipod_bloody.jpg
	{
		map textures/coop_skins/bar/s93_bar-bipod_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_bar_camo_woodland_1
{
	qer_editorimage textures/coop_skins/bar/s93_bar_camo_woodland.jpg
	{
		map textures/coop_skins/bar/s93_bar_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_bar_camo_woodland_0
{
	qer_editorimage textures/coop_skins/bar/s93_bar-bipod_camo_woodland.jpg
	{
		map textures/coop_skins/bar/s93_bar-bipod_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_bar_camo_winter_1
{
	qer_editorimage textures/coop_skins/bar/s93_bar_camo_winter.jpg
	{
		map textures/coop_skins/bar/s93_bar_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_bar_camo_winter_0
{
	qer_editorimage textures/coop_skins/bar/s93_bar-bipod_camo_winter.jpg
	{
		map textures/coop_skins/bar/s93_bar-bipod_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_bar_camo_desert_1
{
	qer_editorimage textures/coop_skins/bar/s93_bar_camo_desert.jpg
	{
		map textures/coop_skins/bar/s93_bar_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_bar_camo_desert_0
{
	qer_editorimage textures/coop_skins/bar/s93_bar-bipod_camo_desert.jpg
	{
		map textures/coop_skins/bar/s93_bar-bipod_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_bazooka_gold_0
{
	qer_editorimage textures/models/weapons/bazooka/bazooka.tga
	{
		map textures/models/weapons/bazooka/bazooka.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_bazooka_gold_1
{
	qer_editorimage textures/models/weapons/bazooka/bazookarim.tga
	{
		map textures/models/weapons/bazooka/bazookarim.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_bazooka_chrome_0
{
	qer_editorimage textures/models/weapons/bazooka/bazooka.tga
	{
		map textures/models/weapons/bazooka/bazooka.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_bazooka_chrome_1
{
	qer_editorimage textures/models/weapons/bazooka/bazookarim.tga
	{
		map textures/models/weapons/bazooka/bazookarim.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_bazooka_blued_0
{
	qer_editorimage textures/models/weapons/bazooka/bazooka.tga
	{
		map textures/models/weapons/bazooka/bazooka.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_bazooka_blued_1
{
	qer_editorimage textures/models/weapons/bazooka/bazookarim.tga
	{
		map textures/models/weapons/bazooka/bazookarim.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_bazooka_bloody_0
{
	qer_editorimage textures/coop_skins/bazooka/bazooka_bloody.jpg
	{
		map textures/coop_skins/bazooka/bazooka_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_bazooka_bloody_1
{
	qer_editorimage textures/coop_skins/bazooka/bazookarim_bloody.jpg
	{
		map textures/coop_skins/bazooka/bazookarim_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_bazooka_camo_woodland_0
{
	qer_editorimage textures/coop_skins/bazooka/bazooka_camo_woodland.jpg
	{
		map textures/coop_skins/bazooka/bazooka_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_bazooka_camo_woodland_1
{
	qer_editorimage textures/coop_skins/bazooka/bazookarim_camo_woodland.jpg
	{
		map textures/coop_skins/bazooka/bazookarim_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_bazooka_camo_winter_0
{
	qer_editorimage textures/coop_skins/bazooka/bazooka_camo_winter.jpg
	{
		map textures/coop_skins/bazooka/bazooka_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_bazooka_camo_winter_1
{
	qer_editorimage textures/coop_skins/bazooka/bazookarim_camo_winter.jpg
	{
		map textures/coop_skins/bazooka/bazookarim_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_bazooka_camo_desert_0
{
	qer_editorimage textures/coop_skins/bazooka/bazooka_camo_desert.jpg
	{
		map textures/coop_skins/bazooka/bazooka_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_bazooka_camo_desert_1
{
	qer_editorimage textures/coop_skins/bazooka/bazookarim_camo_desert.jpg
	{
		map textures/coop_skins/bazooka/bazookarim_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_colt45_gold
{
	qer_editorimage textures/models/weapons/colt45/colt45.tga
	{
		map textures/models/weapons/colt45/colt45.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_colt45_chrome
{
	qer_editorimage textures/models/weapons/colt45/colt45.tga
	{
		map textures/models/weapons/colt45/colt45.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_colt45_blued
{
	qer_editorimage textures/models/weapons/colt45/colt45.tga
	{
		map textures/models/weapons/colt45/colt45.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_colt45_bloody
{
	qer_editorimage textures/coop_skins/colt45/colt45_bloody.jpg
	{
		map textures/coop_skins/colt45/colt45_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_colt45_camo_woodland
{
	qer_editorimage textures/coop_skins/colt45/colt45_camo_woodland.jpg
	{
		map textures/coop_skins/colt45/colt45_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_colt45_camo_winter
{
	qer_editorimage textures/coop_skins/colt45/colt45_camo_winter.jpg
	{
		map textures/coop_skins/colt45/colt45_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_colt45_camo_desert
{
	qer_editorimage textures/coop_skins/colt45/colt45_camo_desert.jpg
	{
		map textures/coop_skins/colt45/colt45_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_coop_binoculars_gold
{
	qer_editorimage textures/binoculars.tga
	{
		map textures/binoculars.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_coop_binoculars_chrome
{
	qer_editorimage textures/binoculars.tga
	{
		map textures/binoculars.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_coop_binoculars_blued
{
	qer_editorimage textures/binoculars.tga
	{
		map textures/binoculars.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_coop_binoculars_bloody
{
	qer_editorimage textures/coop_skins/coop_binoculars/binoculars_bloody.jpg
	{
		map textures/coop_skins/coop_binoculars/binoculars_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_coop_binoculars_camo_woodland
{
	qer_editorimage textures/coop_skins/coop_binoculars/binoculars_camo_woodland.jpg
	{
		map textures/coop_skins/coop_binoculars/binoculars_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_coop_binoculars_camo_winter
{
	qer_editorimage textures/coop_skins/coop_binoculars/binoculars_camo_winter.jpg
	{
		map textures/coop_skins/coop_binoculars/binoculars_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_coop_binoculars_camo_desert
{
	qer_editorimage textures/coop_skins/coop_binoculars/binoculars_camo_desert.jpg
	{
		map textures/coop_skins/coop_binoculars/binoculars_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_coop_smoke_grenade_gold
{
	qer_editorimage textures/models/weapons/m18_smoke_grenade.jpg
	{
		map textures/models/weapons/m18_smoke_grenade.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_coop_smoke_grenade_chrome
{
	qer_editorimage textures/models/weapons/m18_smoke_grenade.jpg
	{
		map textures/models/weapons/m18_smoke_grenade.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_coop_smoke_grenade_blued
{
	qer_editorimage textures/models/weapons/m18_smoke_grenade.jpg
	{
		map textures/models/weapons/m18_smoke_grenade.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_coop_smoke_grenade_bloody
{
	qer_editorimage textures/coop_skins/coop_smoke_grenade/m18_smoke_grenade_bloody.jpg
	{
		map textures/coop_skins/coop_smoke_grenade/m18_smoke_grenade_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_coop_smoke_grenade_camo_woodland
{
	qer_editorimage textures/coop_skins/coop_smoke_grenade/m18_smoke_grenade_camo_woodland.jpg
	{
		map textures/coop_skins/coop_smoke_grenade/m18_smoke_grenade_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_coop_smoke_grenade_camo_winter
{
	qer_editorimage textures/coop_skins/coop_smoke_grenade/m18_smoke_grenade_camo_winter.jpg
	{
		map textures/coop_skins/coop_smoke_grenade/m18_smoke_grenade_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_coop_smoke_grenade_camo_desert
{
	qer_editorimage textures/coop_skins/coop_smoke_grenade/m18_smoke_grenade_camo_desert.jpg
	{
		map textures/coop_skins/coop_smoke_grenade/m18_smoke_grenade_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_dbno_pistol_gold
{
	qer_editorimage textures/models/weapons/colt45/colt45.tga
	{
		map textures/models/weapons/colt45/colt45.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_dbno_pistol_chrome
{
	qer_editorimage textures/models/weapons/colt45/colt45.tga
	{
		map textures/models/weapons/colt45/colt45.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_dbno_pistol_blued
{
	qer_editorimage textures/models/weapons/colt45/colt45.tga
	{
		map textures/models/weapons/colt45/colt45.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_dbno_pistol_bloody
{
	qer_editorimage textures/coop_skins/dbno_pistol/colt45_bloody.jpg
	{
		map textures/coop_skins/dbno_pistol/colt45_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_dbno_pistol_camo_woodland
{
	qer_editorimage textures/coop_skins/dbno_pistol/colt45_camo_woodland.jpg
	{
		map textures/coop_skins/dbno_pistol/colt45_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_dbno_pistol_camo_winter
{
	qer_editorimage textures/coop_skins/dbno_pistol/colt45_camo_winter.jpg
	{
		map textures/coop_skins/dbno_pistol/colt45_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_dbno_pistol_camo_desert
{
	qer_editorimage textures/coop_skins/dbno_pistol/colt45_camo_desert.jpg
	{
		map textures/coop_skins/dbno_pistol/colt45_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_dp28_gold_1
{
	qer_editorimage textures/coop_dp28/dp28.jpg
	{
		map textures/coop_dp28/dp28.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_dp28_gold_0
{
	qer_editorimage textures/coop_dp28/bipod.jpg
	{
		map textures/coop_dp28/bipod.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_dp28_chrome_1
{
	qer_editorimage textures/coop_dp28/dp28.jpg
	{
		map textures/coop_dp28/dp28.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_dp28_chrome_0
{
	qer_editorimage textures/coop_dp28/bipod.jpg
	{
		map textures/coop_dp28/bipod.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_dp28_blued_1
{
	qer_editorimage textures/coop_dp28/dp28.jpg
	{
		map textures/coop_dp28/dp28.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_dp28_blued_0
{
	qer_editorimage textures/coop_dp28/bipod.jpg
	{
		map textures/coop_dp28/bipod.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_dp28_bloody_1
{
	qer_editorimage textures/coop_skins/dp28/dp28_bloody.jpg
	{
		map textures/coop_skins/dp28/dp28_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_dp28_bloody_0
{
	qer_editorimage textures/coop_skins/dp28/bipod_bloody.jpg
	{
		map textures/coop_skins/dp28/bipod_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_dp28_camo_woodland_1
{
	qer_editorimage textures/coop_skins/dp28/dp28_camo_woodland.jpg
	{
		map textures/coop_skins/dp28/dp28_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_dp28_camo_woodland_0
{
	qer_editorimage textures/coop_skins/dp28/bipod_camo_woodland.jpg
	{
		map textures/coop_skins/dp28/bipod_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_dp28_camo_winter_1
{
	qer_editorimage textures/coop_skins/dp28/dp28_camo_winter.jpg
	{
		map textures/coop_skins/dp28/dp28_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_dp28_camo_winter_0
{
	qer_editorimage textures/coop_skins/dp28/bipod_camo_winter.jpg
	{
		map textures/coop_skins/dp28/bipod_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_dp28_camo_desert_1
{
	qer_editorimage textures/coop_skins/dp28/dp28_camo_desert.jpg
	{
		map textures/coop_skins/dp28/dp28_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_dp28_camo_desert_0
{
	qer_editorimage textures/coop_skins/dp28/bipod_camo_desert.jpg
	{
		map textures/coop_skins/dp28/bipod_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_enfield_gold
{
	qer_editorimage models/weapons/enfield/enfield.tga
	{
		map models/weapons/enfield/enfield.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_enfield_chrome
{
	qer_editorimage models/weapons/enfield/enfield.tga
	{
		map models/weapons/enfield/enfield.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_enfield_blued
{
	qer_editorimage models/weapons/enfield/enfield.tga
	{
		map models/weapons/enfield/enfield.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_enfield_bloody
{
	qer_editorimage textures/coop_skins/enfield/enfield_bloody.jpg
	{
		map textures/coop_skins/enfield/enfield_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_enfield_camo_woodland
{
	qer_editorimage textures/coop_skins/enfield/enfield_camo_woodland.jpg
	{
		map textures/coop_skins/enfield/enfield_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_enfield_camo_winter
{
	qer_editorimage textures/coop_skins/enfield/enfield_camo_winter.jpg
	{
		map textures/coop_skins/enfield/enfield_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_enfield_camo_desert
{
	qer_editorimage textures/coop_skins/enfield/enfield_camo_desert.jpg
	{
		map textures/coop_skins/enfield/enfield_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_enfield_lite_gold
{
	qer_editorimage models/weapons/enfield/enfield.tga
	{
		map models/weapons/enfield/enfield.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_enfield_lite_chrome
{
	qer_editorimage models/weapons/enfield/enfield.tga
	{
		map models/weapons/enfield/enfield.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_enfield_lite_blued
{
	qer_editorimage models/weapons/enfield/enfield.tga
	{
		map models/weapons/enfield/enfield.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_enfield_lite_bloody
{
	qer_editorimage textures/coop_skins/enfield_lite/enfield_bloody.jpg
	{
		map textures/coop_skins/enfield_lite/enfield_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_enfield_lite_camo_woodland
{
	qer_editorimage textures/coop_skins/enfield_lite/enfield_camo_woodland.jpg
	{
		map textures/coop_skins/enfield_lite/enfield_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_enfield_lite_camo_winter
{
	qer_editorimage textures/coop_skins/enfield_lite/enfield_camo_winter.jpg
	{
		map textures/coop_skins/enfield_lite/enfield_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_enfield_lite_camo_desert
{
	qer_editorimage textures/coop_skins/enfield_lite/enfield_camo_desert.jpg
	{
		map textures/coop_skins/enfield_lite/enfield_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_g43sniper_gold
{
	qer_editorimage textures/models/weapons/g43/gewehr43.jpg
	{
		map textures/models/weapons/g43/gewehr43.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_g43sniper_chrome
{
	qer_editorimage textures/models/weapons/g43/gewehr43.jpg
	{
		map textures/models/weapons/g43/gewehr43.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_g43sniper_blued
{
	qer_editorimage textures/models/weapons/g43/gewehr43.jpg
	{
		map textures/models/weapons/g43/gewehr43.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_g43sniper_bloody
{
	qer_editorimage textures/coop_skins/g43sniper/gewehr43_bloody.jpg
	{
		map textures/coop_skins/g43sniper/gewehr43_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_g43sniper_camo_woodland
{
	qer_editorimage textures/coop_skins/g43sniper/gewehr43_camo_woodland.jpg
	{
		map textures/coop_skins/g43sniper/gewehr43_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_g43sniper_camo_winter
{
	qer_editorimage textures/coop_skins/g43sniper/gewehr43_camo_winter.jpg
	{
		map textures/coop_skins/g43sniper/gewehr43_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_g43sniper_camo_desert
{
	qer_editorimage textures/coop_skins/g43sniper/gewehr43_camo_desert.jpg
	{
		map textures/coop_skins/g43sniper/gewehr43_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_gold_0
{
	qer_editorimage textures/coop_johnson/johnson_01.jpg
	{
		map textures/coop_johnson/johnson_01.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_johnson_m1941_gold_1
{
	qer_editorimage textures/coop_johnson/johnson_02.jpg
	{
		map textures/coop_johnson/johnson_02.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_johnson_m1941_gold_2
{
	qer_editorimage textures/coop_johnson/johnson_03.jpg
	{
		map textures/coop_johnson/johnson_03.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_johnson_m1941_gold_3
{
	qer_editorimage textures/coop_johnson/johnson_04.jpg
	{
		map textures/coop_johnson/johnson_04.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_johnson_m1941_gold_4
{
	qer_editorimage textures/coop_johnson/johnson_05.jpg
	{
		map textures/coop_johnson/johnson_05.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_johnson_m1941_gold_5
{
	qer_editorimage textures/coop_johnson/johnson_06.jpg
	{
		map textures/coop_johnson/johnson_06.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_johnson_m1941_gold_6
{
	qer_editorimage textures/coop_johnson/johnson_07.jpg
	{
		map textures/coop_johnson/johnson_07.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_johnson_m1941_gold_7
{
	qer_editorimage textures/coop_johnson/johnson_08.jpg
	{
		map textures/coop_johnson/johnson_08.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_johnson_m1941_gold_8
{
	qer_editorimage textures/coop_johnson/johnson_09.jpg
	{
		map textures/coop_johnson/johnson_09.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_johnson_m1941_gold_9
{
	qer_editorimage textures/coop_johnson/johnson_10.jpg
	{
		map textures/coop_johnson/johnson_10.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_johnson_m1941_gold_10
{
	qer_editorimage textures/coop_johnson/johnson_11.jpg
	{
		map textures/coop_johnson/johnson_11.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_johnson_m1941_gold_11
{
	qer_editorimage textures/coop_johnson/johnson_12.jpg
	{
		map textures/coop_johnson/johnson_12.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_johnson_m1941_gold_12
{
	qer_editorimage textures/coop_johnson/johnson_13.jpg
	{
		map textures/coop_johnson/johnson_13.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_johnson_m1941_gold_13
{
	qer_editorimage textures/coop_johnson/johnson_14.jpg
	{
		map textures/coop_johnson/johnson_14.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_johnson_m1941_gold_14
{
	qer_editorimage textures/coop_johnson/johnson_15.jpg
	{
		map textures/coop_johnson/johnson_15.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_johnson_m1941_gold_15
{
	qer_editorimage textures/coop_johnson/johnson_16.jpg
	{
		map textures/coop_johnson/johnson_16.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_johnson_m1941_chrome_0
{
	qer_editorimage textures/coop_johnson/johnson_01.jpg
	{
		map textures/coop_johnson/johnson_01.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_johnson_m1941_chrome_1
{
	qer_editorimage textures/coop_johnson/johnson_02.jpg
	{
		map textures/coop_johnson/johnson_02.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_johnson_m1941_chrome_2
{
	qer_editorimage textures/coop_johnson/johnson_03.jpg
	{
		map textures/coop_johnson/johnson_03.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_johnson_m1941_chrome_3
{
	qer_editorimage textures/coop_johnson/johnson_04.jpg
	{
		map textures/coop_johnson/johnson_04.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_johnson_m1941_chrome_4
{
	qer_editorimage textures/coop_johnson/johnson_05.jpg
	{
		map textures/coop_johnson/johnson_05.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_johnson_m1941_chrome_5
{
	qer_editorimage textures/coop_johnson/johnson_06.jpg
	{
		map textures/coop_johnson/johnson_06.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_johnson_m1941_chrome_6
{
	qer_editorimage textures/coop_johnson/johnson_07.jpg
	{
		map textures/coop_johnson/johnson_07.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_johnson_m1941_chrome_7
{
	qer_editorimage textures/coop_johnson/johnson_08.jpg
	{
		map textures/coop_johnson/johnson_08.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_johnson_m1941_chrome_8
{
	qer_editorimage textures/coop_johnson/johnson_09.jpg
	{
		map textures/coop_johnson/johnson_09.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_johnson_m1941_chrome_9
{
	qer_editorimage textures/coop_johnson/johnson_10.jpg
	{
		map textures/coop_johnson/johnson_10.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_johnson_m1941_chrome_10
{
	qer_editorimage textures/coop_johnson/johnson_11.jpg
	{
		map textures/coop_johnson/johnson_11.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_johnson_m1941_chrome_11
{
	qer_editorimage textures/coop_johnson/johnson_12.jpg
	{
		map textures/coop_johnson/johnson_12.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_johnson_m1941_chrome_12
{
	qer_editorimage textures/coop_johnson/johnson_13.jpg
	{
		map textures/coop_johnson/johnson_13.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_johnson_m1941_chrome_13
{
	qer_editorimage textures/coop_johnson/johnson_14.jpg
	{
		map textures/coop_johnson/johnson_14.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_johnson_m1941_chrome_14
{
	qer_editorimage textures/coop_johnson/johnson_15.jpg
	{
		map textures/coop_johnson/johnson_15.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_johnson_m1941_chrome_15
{
	qer_editorimage textures/coop_johnson/johnson_16.jpg
	{
		map textures/coop_johnson/johnson_16.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_johnson_m1941_blued_0
{
	qer_editorimage textures/coop_johnson/johnson_01.jpg
	{
		map textures/coop_johnson/johnson_01.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_johnson_m1941_blued_1
{
	qer_editorimage textures/coop_johnson/johnson_02.jpg
	{
		map textures/coop_johnson/johnson_02.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_johnson_m1941_blued_2
{
	qer_editorimage textures/coop_johnson/johnson_03.jpg
	{
		map textures/coop_johnson/johnson_03.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_johnson_m1941_blued_3
{
	qer_editorimage textures/coop_johnson/johnson_04.jpg
	{
		map textures/coop_johnson/johnson_04.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_johnson_m1941_blued_4
{
	qer_editorimage textures/coop_johnson/johnson_05.jpg
	{
		map textures/coop_johnson/johnson_05.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_johnson_m1941_blued_5
{
	qer_editorimage textures/coop_johnson/johnson_06.jpg
	{
		map textures/coop_johnson/johnson_06.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_johnson_m1941_blued_6
{
	qer_editorimage textures/coop_johnson/johnson_07.jpg
	{
		map textures/coop_johnson/johnson_07.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_johnson_m1941_blued_7
{
	qer_editorimage textures/coop_johnson/johnson_08.jpg
	{
		map textures/coop_johnson/johnson_08.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_johnson_m1941_blued_8
{
	qer_editorimage textures/coop_johnson/johnson_09.jpg
	{
		map textures/coop_johnson/johnson_09.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_johnson_m1941_blued_9
{
	qer_editorimage textures/coop_johnson/johnson_10.jpg
	{
		map textures/coop_johnson/johnson_10.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_johnson_m1941_blued_10
{
	qer_editorimage textures/coop_johnson/johnson_11.jpg
	{
		map textures/coop_johnson/johnson_11.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_johnson_m1941_blued_11
{
	qer_editorimage textures/coop_johnson/johnson_12.jpg
	{
		map textures/coop_johnson/johnson_12.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_johnson_m1941_blued_12
{
	qer_editorimage textures/coop_johnson/johnson_13.jpg
	{
		map textures/coop_johnson/johnson_13.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_johnson_m1941_blued_13
{
	qer_editorimage textures/coop_johnson/johnson_14.jpg
	{
		map textures/coop_johnson/johnson_14.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_johnson_m1941_blued_14
{
	qer_editorimage textures/coop_johnson/johnson_15.jpg
	{
		map textures/coop_johnson/johnson_15.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_johnson_m1941_blued_15
{
	qer_editorimage textures/coop_johnson/johnson_16.jpg
	{
		map textures/coop_johnson/johnson_16.jpg
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_johnson_m1941_bloody_0
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_01_bloody.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_01_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_bloody_1
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_02_bloody.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_02_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_bloody_2
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_03_bloody.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_03_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_bloody_3
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_04_bloody.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_04_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_bloody_4
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_05_bloody.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_05_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_bloody_5
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_06_bloody.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_06_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_bloody_6
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_07_bloody.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_07_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_bloody_7
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_08_bloody.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_08_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_bloody_8
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_09_bloody.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_09_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_bloody_9
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_10_bloody.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_10_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_bloody_10
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_11_bloody.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_11_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_bloody_11
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_12_bloody.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_12_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_bloody_12
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_13_bloody.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_13_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_bloody_13
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_14_bloody.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_14_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_bloody_14
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_15_bloody.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_15_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_bloody_15
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_16_bloody.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_16_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_woodland_0
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_01_camo_woodland.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_01_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_woodland_1
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_02_camo_woodland.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_02_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_woodland_2
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_03_camo_woodland.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_03_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_woodland_3
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_04_camo_woodland.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_04_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_woodland_4
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_05_camo_woodland.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_05_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_woodland_5
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_06_camo_woodland.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_06_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_woodland_6
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_07_camo_woodland.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_07_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_woodland_7
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_08_camo_woodland.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_08_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_woodland_8
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_09_camo_woodland.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_09_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_woodland_9
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_10_camo_woodland.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_10_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_woodland_10
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_11_camo_woodland.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_11_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_woodland_11
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_12_camo_woodland.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_12_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_woodland_12
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_13_camo_woodland.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_13_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_woodland_13
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_14_camo_woodland.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_14_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_woodland_14
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_15_camo_woodland.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_15_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_woodland_15
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_16_camo_woodland.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_16_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_winter_0
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_01_camo_winter.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_01_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_winter_1
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_02_camo_winter.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_02_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_winter_2
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_03_camo_winter.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_03_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_winter_3
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_04_camo_winter.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_04_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_winter_4
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_05_camo_winter.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_05_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_winter_5
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_06_camo_winter.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_06_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_winter_6
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_07_camo_winter.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_07_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_winter_7
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_08_camo_winter.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_08_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_winter_8
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_09_camo_winter.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_09_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_winter_9
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_10_camo_winter.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_10_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_winter_10
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_11_camo_winter.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_11_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_winter_11
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_12_camo_winter.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_12_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_winter_12
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_13_camo_winter.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_13_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_winter_13
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_14_camo_winter.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_14_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_winter_14
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_15_camo_winter.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_15_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_winter_15
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_16_camo_winter.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_16_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_desert_0
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_01_camo_desert.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_01_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_desert_1
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_02_camo_desert.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_02_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_desert_2
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_03_camo_desert.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_03_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_desert_3
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_04_camo_desert.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_04_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_desert_4
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_05_camo_desert.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_05_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_desert_5
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_06_camo_desert.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_06_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_desert_6
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_07_camo_desert.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_07_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_desert_7
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_08_camo_desert.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_08_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_desert_8
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_09_camo_desert.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_09_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_desert_9
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_10_camo_desert.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_10_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_desert_10
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_11_camo_desert.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_11_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_desert_11
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_12_camo_desert.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_12_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_desert_12
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_13_camo_desert.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_13_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_desert_13
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_14_camo_desert.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_14_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_desert_14
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_15_camo_desert.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_15_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_johnson_m1941_camo_desert_15
{
	qer_editorimage textures/coop_skins/johnson_m1941/johnson_16_camo_desert.jpg
	{
		map textures/coop_skins/johnson_m1941/johnson_16_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_gold_0
{
	qer_editorimage textures/models/weapons/kar98/kar98.tga
	{
		map textures/models/weapons/kar98/kar98.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_kar98_gold_1
{
	qer_editorimage textures/models/weapons/m1garand/m1clip.tga
	{
		map textures/models/weapons/m1garand/m1clip.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_kar98_chrome_0
{
	qer_editorimage textures/models/weapons/kar98/kar98.tga
	{
		map textures/models/weapons/kar98/kar98.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_kar98_chrome_1
{
	qer_editorimage textures/models/weapons/m1garand/m1clip.tga
	{
		map textures/models/weapons/m1garand/m1clip.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_kar98_blued_0
{
	qer_editorimage textures/models/weapons/kar98/kar98.tga
	{
		map textures/models/weapons/kar98/kar98.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_kar98_blued_1
{
	qer_editorimage textures/models/weapons/m1garand/m1clip.tga
	{
		map textures/models/weapons/m1garand/m1clip.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_kar98_bloody_0
{
	qer_editorimage textures/coop_skins/kar98/kar98_bloody.jpg
	{
		map textures/coop_skins/kar98/kar98_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_bloody_1
{
	qer_editorimage textures/coop_skins/kar98/m1clip_bloody.jpg
	{
		map textures/coop_skins/kar98/m1clip_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_camo_woodland_0
{
	qer_editorimage textures/coop_skins/kar98/kar98_camo_woodland.jpg
	{
		map textures/coop_skins/kar98/kar98_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_camo_woodland_1
{
	qer_editorimage textures/coop_skins/kar98/m1clip_camo_woodland.jpg
	{
		map textures/coop_skins/kar98/m1clip_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_camo_winter_0
{
	qer_editorimage textures/coop_skins/kar98/kar98_camo_winter.jpg
	{
		map textures/coop_skins/kar98/kar98_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_camo_winter_1
{
	qer_editorimage textures/coop_skins/kar98/m1clip_camo_winter.jpg
	{
		map textures/coop_skins/kar98/m1clip_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_camo_desert_0
{
	qer_editorimage textures/coop_skins/kar98/kar98_camo_desert.jpg
	{
		map textures/coop_skins/kar98/kar98_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_camo_desert_1
{
	qer_editorimage textures/coop_skins/kar98/m1clip_camo_desert.jpg
	{
		map textures/coop_skins/kar98/m1clip_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_lite_gold_0
{
	qer_editorimage textures/models/weapons/kar98/kar98.tga
	{
		map textures/models/weapons/kar98/kar98.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_kar98_lite_gold_1
{
	qer_editorimage textures/models/weapons/m1garand/m1clip.tga
	{
		map textures/models/weapons/m1garand/m1clip.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_kar98_lite_chrome_0
{
	qer_editorimage textures/models/weapons/kar98/kar98.tga
	{
		map textures/models/weapons/kar98/kar98.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_kar98_lite_chrome_1
{
	qer_editorimage textures/models/weapons/m1garand/m1clip.tga
	{
		map textures/models/weapons/m1garand/m1clip.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_kar98_lite_blued_0
{
	qer_editorimage textures/models/weapons/kar98/kar98.tga
	{
		map textures/models/weapons/kar98/kar98.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_kar98_lite_blued_1
{
	qer_editorimage textures/models/weapons/m1garand/m1clip.tga
	{
		map textures/models/weapons/m1garand/m1clip.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_kar98_lite_bloody_0
{
	qer_editorimage textures/coop_skins/kar98_lite/kar98_bloody.jpg
	{
		map textures/coop_skins/kar98_lite/kar98_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_lite_bloody_1
{
	qer_editorimage textures/coop_skins/kar98_lite/m1clip_bloody.jpg
	{
		map textures/coop_skins/kar98_lite/m1clip_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_lite_camo_woodland_0
{
	qer_editorimage textures/coop_skins/kar98_lite/kar98_camo_woodland.jpg
	{
		map textures/coop_skins/kar98_lite/kar98_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_lite_camo_woodland_1
{
	qer_editorimage textures/coop_skins/kar98_lite/m1clip_camo_woodland.jpg
	{
		map textures/coop_skins/kar98_lite/m1clip_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_lite_camo_winter_0
{
	qer_editorimage textures/coop_skins/kar98_lite/kar98_camo_winter.jpg
	{
		map textures/coop_skins/kar98_lite/kar98_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_lite_camo_winter_1
{
	qer_editorimage textures/coop_skins/kar98_lite/m1clip_camo_winter.jpg
	{
		map textures/coop_skins/kar98_lite/m1clip_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_lite_camo_desert_0
{
	qer_editorimage textures/coop_skins/kar98_lite/kar98_camo_desert.jpg
	{
		map textures/coop_skins/kar98_lite/kar98_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_lite_camo_desert_1
{
	qer_editorimage textures/coop_skins/kar98_lite/m1clip_camo_desert.jpg
	{
		map textures/coop_skins/kar98_lite/m1clip_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_mortar_gold_1
{
	qer_editorimage models/weapons/kar98grenade/kar98gren_01.tga
	{
		map models/weapons/kar98grenade/kar98gren_01.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_kar98_mortar_gold_3
{
	qer_editorimage models/weapons/kar98grenade/riflegrenade_01.tga
	{
		map models/weapons/kar98grenade/riflegrenade_01.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_kar98_mortar_gold_2
{
	qer_editorimage models/weapons/kar98grenade/kar98sight.tga
	{
		map models/weapons/kar98grenade/kar98sight.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_kar98_mortar_gold_0
{
	qer_editorimage models/weapons/kar98grenade/grenlaunchcup.tga
	{
		map models/weapons/kar98grenade/grenlaunchcup.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_kar98_mortar_gold_4
{
	qer_editorimage models/weapons/kar98grenade/wrapping_06.tga
	{
		map models/weapons/kar98grenade/wrapping_06.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_kar98_mortar_chrome_1
{
	qer_editorimage models/weapons/kar98grenade/kar98gren_01.tga
	{
		map models/weapons/kar98grenade/kar98gren_01.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_kar98_mortar_chrome_3
{
	qer_editorimage models/weapons/kar98grenade/riflegrenade_01.tga
	{
		map models/weapons/kar98grenade/riflegrenade_01.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_kar98_mortar_chrome_2
{
	qer_editorimage models/weapons/kar98grenade/kar98sight.tga
	{
		map models/weapons/kar98grenade/kar98sight.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_kar98_mortar_chrome_0
{
	qer_editorimage models/weapons/kar98grenade/grenlaunchcup.tga
	{
		map models/weapons/kar98grenade/grenlaunchcup.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_kar98_mortar_chrome_4
{
	qer_editorimage models/weapons/kar98grenade/wrapping_06.tga
	{
		map models/weapons/kar98grenade/wrapping_06.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_kar98_mortar_blued_1
{
	qer_editorimage models/weapons/kar98grenade/kar98gren_01.tga
	{
		map models/weapons/kar98grenade/kar98gren_01.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_kar98_mortar_blued_3
{
	qer_editorimage models/weapons/kar98grenade/riflegrenade_01.tga
	{
		map models/weapons/kar98grenade/riflegrenade_01.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_kar98_mortar_blued_2
{
	qer_editorimage models/weapons/kar98grenade/kar98sight.tga
	{
		map models/weapons/kar98grenade/kar98sight.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_kar98_mortar_blued_0
{
	qer_editorimage models/weapons/kar98grenade/grenlaunchcup.tga
	{
		map models/weapons/kar98grenade/grenlaunchcup.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_kar98_mortar_blued_4
{
	qer_editorimage models/weapons/kar98grenade/wrapping_06.tga
	{
		map models/weapons/kar98grenade/wrapping_06.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_kar98_mortar_bloody_1
{
	qer_editorimage textures/coop_skins/kar98_mortar/kar98gren_01_bloody.jpg
	{
		map textures/coop_skins/kar98_mortar/kar98gren_01_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_mortar_bloody_3
{
	qer_editorimage textures/coop_skins/kar98_mortar/riflegrenade_01_bloody.jpg
	{
		map textures/coop_skins/kar98_mortar/riflegrenade_01_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_mortar_bloody_2
{
	qer_editorimage textures/coop_skins/kar98_mortar/kar98sight_bloody.jpg
	{
		map textures/coop_skins/kar98_mortar/kar98sight_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_mortar_bloody_0
{
	qer_editorimage textures/coop_skins/kar98_mortar/grenlaunchcup_bloody.jpg
	{
		map textures/coop_skins/kar98_mortar/grenlaunchcup_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_mortar_bloody_4
{
	qer_editorimage textures/coop_skins/kar98_mortar/wrapping_06_bloody.jpg
	{
		map textures/coop_skins/kar98_mortar/wrapping_06_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_mortar_camo_woodland_1
{
	qer_editorimage textures/coop_skins/kar98_mortar/kar98gren_01_camo_woodland.jpg
	{
		map textures/coop_skins/kar98_mortar/kar98gren_01_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_mortar_camo_woodland_3
{
	qer_editorimage textures/coop_skins/kar98_mortar/riflegrenade_01_camo_woodland.jpg
	{
		map textures/coop_skins/kar98_mortar/riflegrenade_01_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_mortar_camo_woodland_2
{
	qer_editorimage textures/coop_skins/kar98_mortar/kar98sight_camo_woodland.jpg
	{
		map textures/coop_skins/kar98_mortar/kar98sight_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_mortar_camo_woodland_0
{
	qer_editorimage textures/coop_skins/kar98_mortar/grenlaunchcup_camo_woodland.jpg
	{
		map textures/coop_skins/kar98_mortar/grenlaunchcup_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_mortar_camo_woodland_4
{
	qer_editorimage textures/coop_skins/kar98_mortar/wrapping_06_camo_woodland.jpg
	{
		map textures/coop_skins/kar98_mortar/wrapping_06_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_mortar_camo_winter_1
{
	qer_editorimage textures/coop_skins/kar98_mortar/kar98gren_01_camo_winter.jpg
	{
		map textures/coop_skins/kar98_mortar/kar98gren_01_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_mortar_camo_winter_3
{
	qer_editorimage textures/coop_skins/kar98_mortar/riflegrenade_01_camo_winter.jpg
	{
		map textures/coop_skins/kar98_mortar/riflegrenade_01_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_mortar_camo_winter_2
{
	qer_editorimage textures/coop_skins/kar98_mortar/kar98sight_camo_winter.jpg
	{
		map textures/coop_skins/kar98_mortar/kar98sight_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_mortar_camo_winter_0
{
	qer_editorimage textures/coop_skins/kar98_mortar/grenlaunchcup_camo_winter.jpg
	{
		map textures/coop_skins/kar98_mortar/grenlaunchcup_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_mortar_camo_winter_4
{
	qer_editorimage textures/coop_skins/kar98_mortar/wrapping_06_camo_winter.jpg
	{
		map textures/coop_skins/kar98_mortar/wrapping_06_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_mortar_camo_desert_1
{
	qer_editorimage textures/coop_skins/kar98_mortar/kar98gren_01_camo_desert.jpg
	{
		map textures/coop_skins/kar98_mortar/kar98gren_01_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_mortar_camo_desert_3
{
	qer_editorimage textures/coop_skins/kar98_mortar/riflegrenade_01_camo_desert.jpg
	{
		map textures/coop_skins/kar98_mortar/riflegrenade_01_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_mortar_camo_desert_2
{
	qer_editorimage textures/coop_skins/kar98_mortar/kar98sight_camo_desert.jpg
	{
		map textures/coop_skins/kar98_mortar/kar98sight_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_mortar_camo_desert_0
{
	qer_editorimage textures/coop_skins/kar98_mortar/grenlaunchcup_camo_desert.jpg
	{
		map textures/coop_skins/kar98_mortar/grenlaunchcup_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_kar98_mortar_camo_desert_4
{
	qer_editorimage textures/coop_skins/kar98_mortar/wrapping_06_camo_desert.jpg
	{
		map textures/coop_skins/kar98_mortar/wrapping_06_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_gold_8
{
	qer_editorimage textures/coop_m10/gun5.tga
	{
		map textures/coop_m10/gun5.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_m10_revolver_gold_2
{
	qer_editorimage textures/coop_m10/gun11.tga
	{
		map textures/coop_m10/gun11.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_m10_revolver_gold_7
{
	qer_editorimage textures/coop_m10/gun4.tga
	{
		map textures/coop_m10/gun4.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_m10_revolver_gold_11
{
	qer_editorimage textures/coop_m10/gun9.tga
	{
		map textures/coop_m10/gun9.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_m10_revolver_gold_1
{
	qer_editorimage textures/coop_m10/gun10.tga
	{
		map textures/coop_m10/gun10.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_m10_revolver_gold_5
{
	qer_editorimage textures/coop_m10/gun2.tga
	{
		map textures/coop_m10/gun2.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_m10_revolver_gold_6
{
	qer_editorimage textures/coop_m10/gun3.tga
	{
		map textures/coop_m10/gun3.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_m10_revolver_gold_3
{
	qer_editorimage textures/coop_m10/gun12.tga
	{
		map textures/coop_m10/gun12.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_m10_revolver_gold_4
{
	qer_editorimage textures/coop_m10/gun13.tga
	{
		map textures/coop_m10/gun13.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_m10_revolver_gold_0
{
	qer_editorimage textures/coop_m10/gun1.tga
	{
		map textures/coop_m10/gun1.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_m10_revolver_gold_10
{
	qer_editorimage textures/coop_m10/gun8.tga
	{
		map textures/coop_m10/gun8.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_m10_revolver_gold_9
{
	qer_editorimage textures/coop_m10/gun7.tga
	{
		map textures/coop_m10/gun7.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_m10_revolver_chrome_8
{
	qer_editorimage textures/coop_m10/gun5.tga
	{
		map textures/coop_m10/gun5.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_m10_revolver_chrome_2
{
	qer_editorimage textures/coop_m10/gun11.tga
	{
		map textures/coop_m10/gun11.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_m10_revolver_chrome_7
{
	qer_editorimage textures/coop_m10/gun4.tga
	{
		map textures/coop_m10/gun4.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_m10_revolver_chrome_11
{
	qer_editorimage textures/coop_m10/gun9.tga
	{
		map textures/coop_m10/gun9.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_m10_revolver_chrome_1
{
	qer_editorimage textures/coop_m10/gun10.tga
	{
		map textures/coop_m10/gun10.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_m10_revolver_chrome_5
{
	qer_editorimage textures/coop_m10/gun2.tga
	{
		map textures/coop_m10/gun2.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_m10_revolver_chrome_6
{
	qer_editorimage textures/coop_m10/gun3.tga
	{
		map textures/coop_m10/gun3.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_m10_revolver_chrome_3
{
	qer_editorimage textures/coop_m10/gun12.tga
	{
		map textures/coop_m10/gun12.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_m10_revolver_chrome_4
{
	qer_editorimage textures/coop_m10/gun13.tga
	{
		map textures/coop_m10/gun13.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_m10_revolver_chrome_0
{
	qer_editorimage textures/coop_m10/gun1.tga
	{
		map textures/coop_m10/gun1.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_m10_revolver_chrome_10
{
	qer_editorimage textures/coop_m10/gun8.tga
	{
		map textures/coop_m10/gun8.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_m10_revolver_chrome_9
{
	qer_editorimage textures/coop_m10/gun7.tga
	{
		map textures/coop_m10/gun7.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_m10_revolver_blued_8
{
	qer_editorimage textures/coop_m10/gun5.tga
	{
		map textures/coop_m10/gun5.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_m10_revolver_blued_2
{
	qer_editorimage textures/coop_m10/gun11.tga
	{
		map textures/coop_m10/gun11.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_m10_revolver_blued_7
{
	qer_editorimage textures/coop_m10/gun4.tga
	{
		map textures/coop_m10/gun4.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_m10_revolver_blued_11
{
	qer_editorimage textures/coop_m10/gun9.tga
	{
		map textures/coop_m10/gun9.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_m10_revolver_blued_1
{
	qer_editorimage textures/coop_m10/gun10.tga
	{
		map textures/coop_m10/gun10.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_m10_revolver_blued_5
{
	qer_editorimage textures/coop_m10/gun2.tga
	{
		map textures/coop_m10/gun2.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_m10_revolver_blued_6
{
	qer_editorimage textures/coop_m10/gun3.tga
	{
		map textures/coop_m10/gun3.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_m10_revolver_blued_3
{
	qer_editorimage textures/coop_m10/gun12.tga
	{
		map textures/coop_m10/gun12.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_m10_revolver_blued_4
{
	qer_editorimage textures/coop_m10/gun13.tga
	{
		map textures/coop_m10/gun13.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_m10_revolver_blued_0
{
	qer_editorimage textures/coop_m10/gun1.tga
	{
		map textures/coop_m10/gun1.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_m10_revolver_blued_10
{
	qer_editorimage textures/coop_m10/gun8.tga
	{
		map textures/coop_m10/gun8.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_m10_revolver_blued_9
{
	qer_editorimage textures/coop_m10/gun7.tga
	{
		map textures/coop_m10/gun7.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_m10_revolver_bloody_8
{
	qer_editorimage textures/coop_skins/m10_revolver/gun5_bloody.jpg
	{
		map textures/coop_skins/m10_revolver/gun5_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_bloody_2
{
	qer_editorimage textures/coop_skins/m10_revolver/gun11_bloody.jpg
	{
		map textures/coop_skins/m10_revolver/gun11_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_bloody_7
{
	qer_editorimage textures/coop_skins/m10_revolver/gun4_bloody.jpg
	{
		map textures/coop_skins/m10_revolver/gun4_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_bloody_11
{
	qer_editorimage textures/coop_skins/m10_revolver/gun9_bloody.jpg
	{
		map textures/coop_skins/m10_revolver/gun9_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_bloody_1
{
	qer_editorimage textures/coop_skins/m10_revolver/gun10_bloody.jpg
	{
		map textures/coop_skins/m10_revolver/gun10_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_bloody_5
{
	qer_editorimage textures/coop_skins/m10_revolver/gun2_bloody.jpg
	{
		map textures/coop_skins/m10_revolver/gun2_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_bloody_6
{
	qer_editorimage textures/coop_skins/m10_revolver/gun3_bloody.jpg
	{
		map textures/coop_skins/m10_revolver/gun3_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_bloody_3
{
	qer_editorimage textures/coop_skins/m10_revolver/gun12_bloody.jpg
	{
		map textures/coop_skins/m10_revolver/gun12_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_bloody_4
{
	qer_editorimage textures/coop_skins/m10_revolver/gun13_bloody.jpg
	{
		map textures/coop_skins/m10_revolver/gun13_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_bloody_0
{
	qer_editorimage textures/coop_skins/m10_revolver/gun1_bloody.jpg
	{
		map textures/coop_skins/m10_revolver/gun1_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_bloody_10
{
	qer_editorimage textures/coop_skins/m10_revolver/gun8_bloody.jpg
	{
		map textures/coop_skins/m10_revolver/gun8_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_bloody_9
{
	qer_editorimage textures/coop_skins/m10_revolver/gun7_bloody.jpg
	{
		map textures/coop_skins/m10_revolver/gun7_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_woodland_8
{
	qer_editorimage textures/coop_skins/m10_revolver/gun5_camo_woodland.jpg
	{
		map textures/coop_skins/m10_revolver/gun5_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_woodland_2
{
	qer_editorimage textures/coop_skins/m10_revolver/gun11_camo_woodland.jpg
	{
		map textures/coop_skins/m10_revolver/gun11_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_woodland_7
{
	qer_editorimage textures/coop_skins/m10_revolver/gun4_camo_woodland.jpg
	{
		map textures/coop_skins/m10_revolver/gun4_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_woodland_11
{
	qer_editorimage textures/coop_skins/m10_revolver/gun9_camo_woodland.jpg
	{
		map textures/coop_skins/m10_revolver/gun9_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_woodland_1
{
	qer_editorimage textures/coop_skins/m10_revolver/gun10_camo_woodland.jpg
	{
		map textures/coop_skins/m10_revolver/gun10_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_woodland_5
{
	qer_editorimage textures/coop_skins/m10_revolver/gun2_camo_woodland.jpg
	{
		map textures/coop_skins/m10_revolver/gun2_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_woodland_6
{
	qer_editorimage textures/coop_skins/m10_revolver/gun3_camo_woodland.jpg
	{
		map textures/coop_skins/m10_revolver/gun3_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_woodland_3
{
	qer_editorimage textures/coop_skins/m10_revolver/gun12_camo_woodland.jpg
	{
		map textures/coop_skins/m10_revolver/gun12_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_woodland_4
{
	qer_editorimage textures/coop_skins/m10_revolver/gun13_camo_woodland.jpg
	{
		map textures/coop_skins/m10_revolver/gun13_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_woodland_0
{
	qer_editorimage textures/coop_skins/m10_revolver/gun1_camo_woodland.jpg
	{
		map textures/coop_skins/m10_revolver/gun1_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_woodland_10
{
	qer_editorimage textures/coop_skins/m10_revolver/gun8_camo_woodland.jpg
	{
		map textures/coop_skins/m10_revolver/gun8_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_woodland_9
{
	qer_editorimage textures/coop_skins/m10_revolver/gun7_camo_woodland.jpg
	{
		map textures/coop_skins/m10_revolver/gun7_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_winter_8
{
	qer_editorimage textures/coop_skins/m10_revolver/gun5_camo_winter.jpg
	{
		map textures/coop_skins/m10_revolver/gun5_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_winter_2
{
	qer_editorimage textures/coop_skins/m10_revolver/gun11_camo_winter.jpg
	{
		map textures/coop_skins/m10_revolver/gun11_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_winter_7
{
	qer_editorimage textures/coop_skins/m10_revolver/gun4_camo_winter.jpg
	{
		map textures/coop_skins/m10_revolver/gun4_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_winter_11
{
	qer_editorimage textures/coop_skins/m10_revolver/gun9_camo_winter.jpg
	{
		map textures/coop_skins/m10_revolver/gun9_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_winter_1
{
	qer_editorimage textures/coop_skins/m10_revolver/gun10_camo_winter.jpg
	{
		map textures/coop_skins/m10_revolver/gun10_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_winter_5
{
	qer_editorimage textures/coop_skins/m10_revolver/gun2_camo_winter.jpg
	{
		map textures/coop_skins/m10_revolver/gun2_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_winter_6
{
	qer_editorimage textures/coop_skins/m10_revolver/gun3_camo_winter.jpg
	{
		map textures/coop_skins/m10_revolver/gun3_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_winter_3
{
	qer_editorimage textures/coop_skins/m10_revolver/gun12_camo_winter.jpg
	{
		map textures/coop_skins/m10_revolver/gun12_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_winter_4
{
	qer_editorimage textures/coop_skins/m10_revolver/gun13_camo_winter.jpg
	{
		map textures/coop_skins/m10_revolver/gun13_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_winter_0
{
	qer_editorimage textures/coop_skins/m10_revolver/gun1_camo_winter.jpg
	{
		map textures/coop_skins/m10_revolver/gun1_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_winter_10
{
	qer_editorimage textures/coop_skins/m10_revolver/gun8_camo_winter.jpg
	{
		map textures/coop_skins/m10_revolver/gun8_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_winter_9
{
	qer_editorimage textures/coop_skins/m10_revolver/gun7_camo_winter.jpg
	{
		map textures/coop_skins/m10_revolver/gun7_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_desert_8
{
	qer_editorimage textures/coop_skins/m10_revolver/gun5_camo_desert.jpg
	{
		map textures/coop_skins/m10_revolver/gun5_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_desert_2
{
	qer_editorimage textures/coop_skins/m10_revolver/gun11_camo_desert.jpg
	{
		map textures/coop_skins/m10_revolver/gun11_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_desert_7
{
	qer_editorimage textures/coop_skins/m10_revolver/gun4_camo_desert.jpg
	{
		map textures/coop_skins/m10_revolver/gun4_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_desert_11
{
	qer_editorimage textures/coop_skins/m10_revolver/gun9_camo_desert.jpg
	{
		map textures/coop_skins/m10_revolver/gun9_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_desert_1
{
	qer_editorimage textures/coop_skins/m10_revolver/gun10_camo_desert.jpg
	{
		map textures/coop_skins/m10_revolver/gun10_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_desert_5
{
	qer_editorimage textures/coop_skins/m10_revolver/gun2_camo_desert.jpg
	{
		map textures/coop_skins/m10_revolver/gun2_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_desert_6
{
	qer_editorimage textures/coop_skins/m10_revolver/gun3_camo_desert.jpg
	{
		map textures/coop_skins/m10_revolver/gun3_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_desert_3
{
	qer_editorimage textures/coop_skins/m10_revolver/gun12_camo_desert.jpg
	{
		map textures/coop_skins/m10_revolver/gun12_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_desert_4
{
	qer_editorimage textures/coop_skins/m10_revolver/gun13_camo_desert.jpg
	{
		map textures/coop_skins/m10_revolver/gun13_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_desert_0
{
	qer_editorimage textures/coop_skins/m10_revolver/gun1_camo_desert.jpg
	{
		map textures/coop_skins/m10_revolver/gun1_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_desert_10
{
	qer_editorimage textures/coop_skins/m10_revolver/gun8_camo_desert.jpg
	{
		map textures/coop_skins/m10_revolver/gun8_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m10_revolver_camo_desert_9
{
	qer_editorimage textures/coop_skins/m10_revolver/gun7_camo_desert.jpg
	{
		map textures/coop_skins/m10_revolver/gun7_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m1_garand_gold
{
	qer_editorimage textures/models/weapons/m1garand/garand.tga
	{
		map textures/models/weapons/m1garand/garand.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_m1_garand_chrome
{
	qer_editorimage textures/models/weapons/m1garand/garand.tga
	{
		map textures/models/weapons/m1garand/garand.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_m1_garand_blued
{
	qer_editorimage textures/models/weapons/m1garand/garand.tga
	{
		map textures/models/weapons/m1garand/garand.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_m1_garand_bloody
{
	qer_editorimage textures/coop_skins/m1_garand/garand_bloody.jpg
	{
		map textures/coop_skins/m1_garand/garand_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m1_garand_camo_woodland
{
	qer_editorimage textures/coop_skins/m1_garand/garand_camo_woodland.jpg
	{
		map textures/coop_skins/m1_garand/garand_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m1_garand_camo_winter
{
	qer_editorimage textures/coop_skins/m1_garand/garand_camo_winter.jpg
	{
		map textures/coop_skins/m1_garand/garand_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m1_garand_camo_desert
{
	qer_editorimage textures/coop_skins/m1_garand/garand_camo_desert.jpg
	{
		map textures/coop_skins/m1_garand/garand_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m1_garand_lite_gold
{
	qer_editorimage textures/models/weapons/m1garand/garand.tga
	{
		map textures/models/weapons/m1garand/garand.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_m1_garand_lite_chrome
{
	qer_editorimage textures/models/weapons/m1garand/garand.tga
	{
		map textures/models/weapons/m1garand/garand.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_m1_garand_lite_blued
{
	qer_editorimage textures/models/weapons/m1garand/garand.tga
	{
		map textures/models/weapons/m1garand/garand.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_m1_garand_lite_bloody
{
	qer_editorimage textures/coop_skins/m1_garand_lite/garand_bloody.jpg
	{
		map textures/coop_skins/m1_garand_lite/garand_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m1_garand_lite_camo_woodland
{
	qer_editorimage textures/coop_skins/m1_garand_lite/garand_camo_woodland.jpg
	{
		map textures/coop_skins/m1_garand_lite/garand_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m1_garand_lite_camo_winter
{
	qer_editorimage textures/coop_skins/m1_garand_lite/garand_camo_winter.jpg
	{
		map textures/coop_skins/m1_garand_lite/garand_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_m1_garand_lite_camo_desert
{
	qer_editorimage textures/coop_skins/m1_garand_lite/garand_camo_desert.jpg
	{
		map textures/coop_skins/m1_garand_lite/garand_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_gold_5
{
	qer_editorimage textures/coop_c96/grip.tga
	{
		map textures/coop_c96/grip.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_mauser_c96_gold_4
{
	qer_editorimage textures/coop_c96/body.tga
	{
		map textures/coop_c96/body.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_mauser_c96_gold_7
{
	qer_editorimage textures/coop_c96/hammer2.tga
	{
		map textures/coop_c96/hammer2.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_mauser_c96_gold_6
{
	qer_editorimage textures/coop_c96/hammer.tga
	{
		map textures/coop_c96/hammer.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_mauser_c96_gold_8
{
	qer_editorimage textures/coop_c96/hammerhit.tga
	{
		map textures/coop_c96/hammerhit.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_mauser_c96_gold_9
{
	qer_editorimage textures/coop_c96/switchblade.tga
	{
		map textures/coop_c96/switchblade.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_mauser_c96_gold_2
{
	qer_editorimage textures/coop_c96/aimrearsup.tga
	{
		map textures/coop_c96/aimrearsup.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_mauser_c96_gold_1
{
	qer_editorimage textures/coop_c96/aimrearblade.tga
	{
		map textures/coop_c96/aimrearblade.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_mauser_c96_gold_10
{
	qer_editorimage textures/coop_c96/trigger.tga
	{
		map textures/coop_c96/trigger.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_mauser_c96_gold_11
{
	qer_editorimage textures/coop_c96/triguard.tga
	{
		map textures/coop_c96/triguard.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_mauser_c96_gold_3
{
	qer_editorimage textures/coop_c96/barrel.tga
	{
		map textures/coop_c96/barrel.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_mauser_c96_gold_0
{
	qer_editorimage textures/coop_c96/aimfront.tga
	{
		map textures/coop_c96/aimfront.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_mauser_c96_chrome_5
{
	qer_editorimage textures/coop_c96/grip.tga
	{
		map textures/coop_c96/grip.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_mauser_c96_chrome_4
{
	qer_editorimage textures/coop_c96/body.tga
	{
		map textures/coop_c96/body.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_mauser_c96_chrome_7
{
	qer_editorimage textures/coop_c96/hammer2.tga
	{
		map textures/coop_c96/hammer2.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_mauser_c96_chrome_6
{
	qer_editorimage textures/coop_c96/hammer.tga
	{
		map textures/coop_c96/hammer.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_mauser_c96_chrome_8
{
	qer_editorimage textures/coop_c96/hammerhit.tga
	{
		map textures/coop_c96/hammerhit.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_mauser_c96_chrome_9
{
	qer_editorimage textures/coop_c96/switchblade.tga
	{
		map textures/coop_c96/switchblade.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_mauser_c96_chrome_2
{
	qer_editorimage textures/coop_c96/aimrearsup.tga
	{
		map textures/coop_c96/aimrearsup.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_mauser_c96_chrome_1
{
	qer_editorimage textures/coop_c96/aimrearblade.tga
	{
		map textures/coop_c96/aimrearblade.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_mauser_c96_chrome_10
{
	qer_editorimage textures/coop_c96/trigger.tga
	{
		map textures/coop_c96/trigger.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_mauser_c96_chrome_11
{
	qer_editorimage textures/coop_c96/triguard.tga
	{
		map textures/coop_c96/triguard.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_mauser_c96_chrome_3
{
	qer_editorimage textures/coop_c96/barrel.tga
	{
		map textures/coop_c96/barrel.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_mauser_c96_chrome_0
{
	qer_editorimage textures/coop_c96/aimfront.tga
	{
		map textures/coop_c96/aimfront.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_mauser_c96_blued_5
{
	qer_editorimage textures/coop_c96/grip.tga
	{
		map textures/coop_c96/grip.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_mauser_c96_blued_4
{
	qer_editorimage textures/coop_c96/body.tga
	{
		map textures/coop_c96/body.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_mauser_c96_blued_7
{
	qer_editorimage textures/coop_c96/hammer2.tga
	{
		map textures/coop_c96/hammer2.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_mauser_c96_blued_6
{
	qer_editorimage textures/coop_c96/hammer.tga
	{
		map textures/coop_c96/hammer.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_mauser_c96_blued_8
{
	qer_editorimage textures/coop_c96/hammerhit.tga
	{
		map textures/coop_c96/hammerhit.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_mauser_c96_blued_9
{
	qer_editorimage textures/coop_c96/switchblade.tga
	{
		map textures/coop_c96/switchblade.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_mauser_c96_blued_2
{
	qer_editorimage textures/coop_c96/aimrearsup.tga
	{
		map textures/coop_c96/aimrearsup.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_mauser_c96_blued_1
{
	qer_editorimage textures/coop_c96/aimrearblade.tga
	{
		map textures/coop_c96/aimrearblade.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_mauser_c96_blued_10
{
	qer_editorimage textures/coop_c96/trigger.tga
	{
		map textures/coop_c96/trigger.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_mauser_c96_blued_11
{
	qer_editorimage textures/coop_c96/triguard.tga
	{
		map textures/coop_c96/triguard.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_mauser_c96_blued_3
{
	qer_editorimage textures/coop_c96/barrel.tga
	{
		map textures/coop_c96/barrel.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_mauser_c96_blued_0
{
	qer_editorimage textures/coop_c96/aimfront.tga
	{
		map textures/coop_c96/aimfront.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_mauser_c96_bloody_5
{
	qer_editorimage textures/coop_skins/mauser_c96/grip_bloody.jpg
	{
		map textures/coop_skins/mauser_c96/grip_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_bloody_4
{
	qer_editorimage textures/coop_skins/mauser_c96/body_bloody.jpg
	{
		map textures/coop_skins/mauser_c96/body_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_bloody_7
{
	qer_editorimage textures/coop_skins/mauser_c96/hammer2_bloody.jpg
	{
		map textures/coop_skins/mauser_c96/hammer2_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_bloody_6
{
	qer_editorimage textures/coop_skins/mauser_c96/hammer_bloody.jpg
	{
		map textures/coop_skins/mauser_c96/hammer_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_bloody_8
{
	qer_editorimage textures/coop_skins/mauser_c96/hammerhit_bloody.jpg
	{
		map textures/coop_skins/mauser_c96/hammerhit_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_bloody_9
{
	qer_editorimage textures/coop_skins/mauser_c96/switchblade_bloody.jpg
	{
		map textures/coop_skins/mauser_c96/switchblade_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_bloody_2
{
	qer_editorimage textures/coop_skins/mauser_c96/aimrearsup_bloody.jpg
	{
		map textures/coop_skins/mauser_c96/aimrearsup_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_bloody_1
{
	qer_editorimage textures/coop_skins/mauser_c96/aimrearblade_bloody.jpg
	{
		map textures/coop_skins/mauser_c96/aimrearblade_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_bloody_10
{
	qer_editorimage textures/coop_skins/mauser_c96/trigger_bloody.jpg
	{
		map textures/coop_skins/mauser_c96/trigger_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_bloody_11
{
	qer_editorimage textures/coop_skins/mauser_c96/triguard_bloody.jpg
	{
		map textures/coop_skins/mauser_c96/triguard_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_bloody_3
{
	qer_editorimage textures/coop_skins/mauser_c96/barrel_bloody.jpg
	{
		map textures/coop_skins/mauser_c96/barrel_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_bloody_0
{
	qer_editorimage textures/coop_skins/mauser_c96/aimfront_bloody.jpg
	{
		map textures/coop_skins/mauser_c96/aimfront_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_woodland_5
{
	qer_editorimage textures/coop_skins/mauser_c96/grip_camo_woodland.jpg
	{
		map textures/coop_skins/mauser_c96/grip_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_woodland_4
{
	qer_editorimage textures/coop_skins/mauser_c96/body_camo_woodland.jpg
	{
		map textures/coop_skins/mauser_c96/body_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_woodland_7
{
	qer_editorimage textures/coop_skins/mauser_c96/hammer2_camo_woodland.jpg
	{
		map textures/coop_skins/mauser_c96/hammer2_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_woodland_6
{
	qer_editorimage textures/coop_skins/mauser_c96/hammer_camo_woodland.jpg
	{
		map textures/coop_skins/mauser_c96/hammer_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_woodland_8
{
	qer_editorimage textures/coop_skins/mauser_c96/hammerhit_camo_woodland.jpg
	{
		map textures/coop_skins/mauser_c96/hammerhit_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_woodland_9
{
	qer_editorimage textures/coop_skins/mauser_c96/switchblade_camo_woodland.jpg
	{
		map textures/coop_skins/mauser_c96/switchblade_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_woodland_2
{
	qer_editorimage textures/coop_skins/mauser_c96/aimrearsup_camo_woodland.jpg
	{
		map textures/coop_skins/mauser_c96/aimrearsup_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_woodland_1
{
	qer_editorimage textures/coop_skins/mauser_c96/aimrearblade_camo_woodland.jpg
	{
		map textures/coop_skins/mauser_c96/aimrearblade_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_woodland_10
{
	qer_editorimage textures/coop_skins/mauser_c96/trigger_camo_woodland.jpg
	{
		map textures/coop_skins/mauser_c96/trigger_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_woodland_11
{
	qer_editorimage textures/coop_skins/mauser_c96/triguard_camo_woodland.jpg
	{
		map textures/coop_skins/mauser_c96/triguard_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_woodland_3
{
	qer_editorimage textures/coop_skins/mauser_c96/barrel_camo_woodland.jpg
	{
		map textures/coop_skins/mauser_c96/barrel_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_woodland_0
{
	qer_editorimage textures/coop_skins/mauser_c96/aimfront_camo_woodland.jpg
	{
		map textures/coop_skins/mauser_c96/aimfront_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_winter_5
{
	qer_editorimage textures/coop_skins/mauser_c96/grip_camo_winter.jpg
	{
		map textures/coop_skins/mauser_c96/grip_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_winter_4
{
	qer_editorimage textures/coop_skins/mauser_c96/body_camo_winter.jpg
	{
		map textures/coop_skins/mauser_c96/body_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_winter_7
{
	qer_editorimage textures/coop_skins/mauser_c96/hammer2_camo_winter.jpg
	{
		map textures/coop_skins/mauser_c96/hammer2_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_winter_6
{
	qer_editorimage textures/coop_skins/mauser_c96/hammer_camo_winter.jpg
	{
		map textures/coop_skins/mauser_c96/hammer_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_winter_8
{
	qer_editorimage textures/coop_skins/mauser_c96/hammerhit_camo_winter.jpg
	{
		map textures/coop_skins/mauser_c96/hammerhit_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_winter_9
{
	qer_editorimage textures/coop_skins/mauser_c96/switchblade_camo_winter.jpg
	{
		map textures/coop_skins/mauser_c96/switchblade_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_winter_2
{
	qer_editorimage textures/coop_skins/mauser_c96/aimrearsup_camo_winter.jpg
	{
		map textures/coop_skins/mauser_c96/aimrearsup_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_winter_1
{
	qer_editorimage textures/coop_skins/mauser_c96/aimrearblade_camo_winter.jpg
	{
		map textures/coop_skins/mauser_c96/aimrearblade_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_winter_10
{
	qer_editorimage textures/coop_skins/mauser_c96/trigger_camo_winter.jpg
	{
		map textures/coop_skins/mauser_c96/trigger_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_winter_11
{
	qer_editorimage textures/coop_skins/mauser_c96/triguard_camo_winter.jpg
	{
		map textures/coop_skins/mauser_c96/triguard_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_winter_3
{
	qer_editorimage textures/coop_skins/mauser_c96/barrel_camo_winter.jpg
	{
		map textures/coop_skins/mauser_c96/barrel_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_winter_0
{
	qer_editorimage textures/coop_skins/mauser_c96/aimfront_camo_winter.jpg
	{
		map textures/coop_skins/mauser_c96/aimfront_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_desert_5
{
	qer_editorimage textures/coop_skins/mauser_c96/grip_camo_desert.jpg
	{
		map textures/coop_skins/mauser_c96/grip_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_desert_4
{
	qer_editorimage textures/coop_skins/mauser_c96/body_camo_desert.jpg
	{
		map textures/coop_skins/mauser_c96/body_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_desert_7
{
	qer_editorimage textures/coop_skins/mauser_c96/hammer2_camo_desert.jpg
	{
		map textures/coop_skins/mauser_c96/hammer2_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_desert_6
{
	qer_editorimage textures/coop_skins/mauser_c96/hammer_camo_desert.jpg
	{
		map textures/coop_skins/mauser_c96/hammer_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_desert_8
{
	qer_editorimage textures/coop_skins/mauser_c96/hammerhit_camo_desert.jpg
	{
		map textures/coop_skins/mauser_c96/hammerhit_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_desert_9
{
	qer_editorimage textures/coop_skins/mauser_c96/switchblade_camo_desert.jpg
	{
		map textures/coop_skins/mauser_c96/switchblade_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_desert_2
{
	qer_editorimage textures/coop_skins/mauser_c96/aimrearsup_camo_desert.jpg
	{
		map textures/coop_skins/mauser_c96/aimrearsup_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_desert_1
{
	qer_editorimage textures/coop_skins/mauser_c96/aimrearblade_camo_desert.jpg
	{
		map textures/coop_skins/mauser_c96/aimrearblade_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_desert_10
{
	qer_editorimage textures/coop_skins/mauser_c96/trigger_camo_desert.jpg
	{
		map textures/coop_skins/mauser_c96/trigger_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_desert_11
{
	qer_editorimage textures/coop_skins/mauser_c96/triguard_camo_desert.jpg
	{
		map textures/coop_skins/mauser_c96/triguard_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_desert_3
{
	qer_editorimage textures/coop_skins/mauser_c96/barrel_camo_desert.jpg
	{
		map textures/coop_skins/mauser_c96/barrel_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mauser_c96_camo_desert_0
{
	qer_editorimage textures/coop_skins/mauser_c96/aimfront_camo_desert.jpg
	{
		map textures/coop_skins/mauser_c96/aimfront_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mp40_gold
{
	qer_editorimage textures/models/weapons/mp40/mp40.tga
	{
		map textures/models/weapons/mp40/mp40.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_mp40_chrome
{
	qer_editorimage textures/models/weapons/mp40/mp40.tga
	{
		map textures/models/weapons/mp40/mp40.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_mp40_blued
{
	qer_editorimage textures/models/weapons/mp40/mp40.tga
	{
		map textures/models/weapons/mp40/mp40.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_mp40_bloody
{
	qer_editorimage textures/coop_skins/mp40/mp40_bloody.jpg
	{
		map textures/coop_skins/mp40/mp40_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mp40_camo_woodland
{
	qer_editorimage textures/coop_skins/mp40/mp40_camo_woodland.jpg
	{
		map textures/coop_skins/mp40/mp40_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mp40_camo_winter
{
	qer_editorimage textures/coop_skins/mp40/mp40_camo_winter.jpg
	{
		map textures/coop_skins/mp40/mp40_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mp40_camo_desert
{
	qer_editorimage textures/coop_skins/mp40/mp40_camo_desert.jpg
	{
		map textures/coop_skins/mp40/mp40_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mp44_gold_0
{
	qer_editorimage textures/models/weapons/mp44/mp44.tga
	{
		map textures/models/weapons/mp44/mp44.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_mp44_gold_1
{
	qer_editorimage textures/models/weapons/mp44/mp44clip.tga
	{
		map textures/models/weapons/mp44/mp44clip.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_mp44_chrome_0
{
	qer_editorimage textures/models/weapons/mp44/mp44.tga
	{
		map textures/models/weapons/mp44/mp44.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_mp44_chrome_1
{
	qer_editorimage textures/models/weapons/mp44/mp44clip.tga
	{
		map textures/models/weapons/mp44/mp44clip.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_mp44_blued_0
{
	qer_editorimage textures/models/weapons/mp44/mp44.tga
	{
		map textures/models/weapons/mp44/mp44.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_mp44_blued_1
{
	qer_editorimage textures/models/weapons/mp44/mp44clip.tga
	{
		map textures/models/weapons/mp44/mp44clip.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_mp44_bloody_0
{
	qer_editorimage textures/coop_skins/mp44/mp44_bloody.jpg
	{
		map textures/coop_skins/mp44/mp44_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mp44_bloody_1
{
	qer_editorimage textures/coop_skins/mp44/mp44clip_bloody.jpg
	{
		map textures/coop_skins/mp44/mp44clip_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mp44_camo_woodland_0
{
	qer_editorimage textures/coop_skins/mp44/mp44_camo_woodland.jpg
	{
		map textures/coop_skins/mp44/mp44_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mp44_camo_woodland_1
{
	qer_editorimage textures/coop_skins/mp44/mp44clip_camo_woodland.jpg
	{
		map textures/coop_skins/mp44/mp44clip_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mp44_camo_winter_0
{
	qer_editorimage textures/coop_skins/mp44/mp44_camo_winter.jpg
	{
		map textures/coop_skins/mp44/mp44_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mp44_camo_winter_1
{
	qer_editorimage textures/coop_skins/mp44/mp44clip_camo_winter.jpg
	{
		map textures/coop_skins/mp44/mp44clip_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mp44_camo_desert_0
{
	qer_editorimage textures/coop_skins/mp44/mp44_camo_desert.jpg
	{
		map textures/coop_skins/mp44/mp44_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_mp44_camo_desert_1
{
	qer_editorimage textures/coop_skins/mp44/mp44clip_camo_desert.jpg
	{
		map textures/coop_skins/mp44/mp44clip_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_p38_gold
{
	qer_editorimage textures/models/weapons/p38/p38.tga
	{
		map textures/models/weapons/p38/p38.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_p38_chrome
{
	qer_editorimage textures/models/weapons/p38/p38.tga
	{
		map textures/models/weapons/p38/p38.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_p38_blued
{
	qer_editorimage textures/models/weapons/p38/p38.tga
	{
		map textures/models/weapons/p38/p38.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_p38_bloody
{
	qer_editorimage textures/coop_skins/p38/p38_bloody.jpg
	{
		map textures/coop_skins/p38/p38_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_p38_camo_woodland
{
	qer_editorimage textures/coop_skins/p38/p38_camo_woodland.jpg
	{
		map textures/coop_skins/p38/p38_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_p38_camo_winter
{
	qer_editorimage textures/coop_skins/p38/p38_camo_winter.jpg
	{
		map textures/coop_skins/p38/p38_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_p38_camo_desert
{
	qer_editorimage textures/coop_skins/p38/p38_camo_desert.jpg
	{
		map textures/coop_skins/p38/p38_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_panzerfaust_gold_1
{
	qer_editorimage textures/coop_panzerfaust/pschreck.tga
	{
		map textures/coop_panzerfaust/pschreck.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_panzerfaust_gold_2
{
	qer_editorimage textures/coop_panzerfaust/pzrshell.tga
	{
		map textures/coop_panzerfaust/pzrshell.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_panzerfaust_gold_0
{
	qer_editorimage textures/coop_panzerfaust/panzerrim.tga
	{
		map textures/coop_panzerfaust/panzerrim.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_panzerfaust_chrome_1
{
	qer_editorimage textures/coop_panzerfaust/pschreck.tga
	{
		map textures/coop_panzerfaust/pschreck.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_panzerfaust_chrome_2
{
	qer_editorimage textures/coop_panzerfaust/pzrshell.tga
	{
		map textures/coop_panzerfaust/pzrshell.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_panzerfaust_chrome_0
{
	qer_editorimage textures/coop_panzerfaust/panzerrim.tga
	{
		map textures/coop_panzerfaust/panzerrim.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_panzerfaust_blued_1
{
	qer_editorimage textures/coop_panzerfaust/pschreck.tga
	{
		map textures/coop_panzerfaust/pschreck.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_panzerfaust_blued_2
{
	qer_editorimage textures/coop_panzerfaust/pzrshell.tga
	{
		map textures/coop_panzerfaust/pzrshell.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_panzerfaust_blued_0
{
	qer_editorimage textures/coop_panzerfaust/panzerrim.tga
	{
		map textures/coop_panzerfaust/panzerrim.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_panzerfaust_bloody_1
{
	qer_editorimage textures/coop_skins/panzerfaust/pschreck_bloody.jpg
	{
		map textures/coop_skins/panzerfaust/pschreck_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_panzerfaust_bloody_2
{
	qer_editorimage textures/coop_skins/panzerfaust/pzrshell_bloody.jpg
	{
		map textures/coop_skins/panzerfaust/pzrshell_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_panzerfaust_bloody_0
{
	qer_editorimage textures/coop_skins/panzerfaust/panzerrim_bloody.jpg
	{
		map textures/coop_skins/panzerfaust/panzerrim_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_panzerfaust_camo_woodland_1
{
	qer_editorimage textures/coop_skins/panzerfaust/pschreck_camo_woodland.jpg
	{
		map textures/coop_skins/panzerfaust/pschreck_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_panzerfaust_camo_woodland_2
{
	qer_editorimage textures/coop_skins/panzerfaust/pzrshell_camo_woodland.jpg
	{
		map textures/coop_skins/panzerfaust/pzrshell_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_panzerfaust_camo_woodland_0
{
	qer_editorimage textures/coop_skins/panzerfaust/panzerrim_camo_woodland.jpg
	{
		map textures/coop_skins/panzerfaust/panzerrim_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_panzerfaust_camo_winter_1
{
	qer_editorimage textures/coop_skins/panzerfaust/pschreck_camo_winter.jpg
	{
		map textures/coop_skins/panzerfaust/pschreck_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_panzerfaust_camo_winter_2
{
	qer_editorimage textures/coop_skins/panzerfaust/pzrshell_camo_winter.jpg
	{
		map textures/coop_skins/panzerfaust/pzrshell_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_panzerfaust_camo_winter_0
{
	qer_editorimage textures/coop_skins/panzerfaust/panzerrim_camo_winter.jpg
	{
		map textures/coop_skins/panzerfaust/panzerrim_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_panzerfaust_camo_desert_1
{
	qer_editorimage textures/coop_skins/panzerfaust/pschreck_camo_desert.jpg
	{
		map textures/coop_skins/panzerfaust/pschreck_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_panzerfaust_camo_desert_2
{
	qer_editorimage textures/coop_skins/panzerfaust/pzrshell_camo_desert.jpg
	{
		map textures/coop_skins/panzerfaust/pzrshell_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_panzerfaust_camo_desert_0
{
	qer_editorimage textures/coop_skins/panzerfaust/panzerrim_camo_desert.jpg
	{
		map textures/coop_skins/panzerfaust/panzerrim_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_panzerschreck_gold
{
	qer_editorimage textures/models/weapons/panzerschreck/pschreck.tga
	{
		map textures/models/weapons/panzerschreck/pschreck.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_panzerschreck_chrome
{
	qer_editorimage textures/models/weapons/panzerschreck/pschreck.tga
	{
		map textures/models/weapons/panzerschreck/pschreck.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_panzerschreck_blued
{
	qer_editorimage textures/models/weapons/panzerschreck/pschreck.tga
	{
		map textures/models/weapons/panzerschreck/pschreck.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_panzerschreck_bloody
{
	qer_editorimage textures/coop_skins/panzerschreck/pschreck_bloody.jpg
	{
		map textures/coop_skins/panzerschreck/pschreck_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_panzerschreck_camo_woodland
{
	qer_editorimage textures/coop_skins/panzerschreck/pschreck_camo_woodland.jpg
	{
		map textures/coop_skins/panzerschreck/pschreck_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_panzerschreck_camo_winter
{
	qer_editorimage textures/coop_skins/panzerschreck/pschreck_camo_winter.jpg
	{
		map textures/coop_skins/panzerschreck/pschreck_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_panzerschreck_camo_desert
{
	qer_editorimage textures/coop_skins/panzerschreck/pschreck_camo_desert.jpg
	{
		map textures/coop_skins/panzerschreck/pschreck_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_ppsh_smg_gold
{
	qer_editorimage textures/models/weapons/ppsh_smg.tga
	{
		map textures/models/weapons/ppsh_smg.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_ppsh_smg_chrome
{
	qer_editorimage textures/models/weapons/ppsh_smg.tga
	{
		map textures/models/weapons/ppsh_smg.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_ppsh_smg_blued
{
	qer_editorimage textures/models/weapons/ppsh_smg.tga
	{
		map textures/models/weapons/ppsh_smg.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_ppsh_smg_bloody
{
	qer_editorimage textures/coop_skins/ppsh_smg/ppsh_smg_bloody.jpg
	{
		map textures/coop_skins/ppsh_smg/ppsh_smg_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_ppsh_smg_camo_woodland
{
	qer_editorimage textures/coop_skins/ppsh_smg/ppsh_smg_camo_woodland.jpg
	{
		map textures/coop_skins/ppsh_smg/ppsh_smg_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_ppsh_smg_camo_winter
{
	qer_editorimage textures/coop_skins/ppsh_smg/ppsh_smg_camo_winter.jpg
	{
		map textures/coop_skins/ppsh_smg/ppsh_smg_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_ppsh_smg_camo_desert
{
	qer_editorimage textures/coop_skins/ppsh_smg/ppsh_smg_camo_desert.jpg
	{
		map textures/coop_skins/ppsh_smg/ppsh_smg_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_shotgun_gold
{
	qer_editorimage textures/models/weapons/winchester/winchester.tga
	{
		map textures/models/weapons/winchester/winchester.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_shotgun_chrome
{
	qer_editorimage textures/models/weapons/winchester/winchester.tga
	{
		map textures/models/weapons/winchester/winchester.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_shotgun_blued
{
	qer_editorimage textures/models/weapons/winchester/winchester.tga
	{
		map textures/models/weapons/winchester/winchester.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_shotgun_bloody
{
	qer_editorimage textures/coop_skins/shotgun/winchester_bloody.jpg
	{
		map textures/coop_skins/shotgun/winchester_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_shotgun_camo_woodland
{
	qer_editorimage textures/coop_skins/shotgun/winchester_camo_woodland.jpg
	{
		map textures/coop_skins/shotgun/winchester_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_shotgun_camo_winter
{
	qer_editorimage textures/coop_skins/shotgun/winchester_camo_winter.jpg
	{
		map textures/coop_skins/shotgun/winchester_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_shotgun_camo_desert
{
	qer_editorimage textures/coop_skins/shotgun/winchester_camo_desert.jpg
	{
		map textures/coop_skins/shotgun/winchester_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_silencedpistol_gold
{
	qer_editorimage textures/models/weapons/hi_standard/hi_standard.tga
	{
		map textures/models/weapons/hi_standard/hi_standard.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_silencedpistol_chrome
{
	qer_editorimage textures/models/weapons/hi_standard/hi_standard.tga
	{
		map textures/models/weapons/hi_standard/hi_standard.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_silencedpistol_blued
{
	qer_editorimage textures/models/weapons/hi_standard/hi_standard.tga
	{
		map textures/models/weapons/hi_standard/hi_standard.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_silencedpistol_bloody
{
	qer_editorimage textures/coop_skins/silencedpistol/hi_standard_bloody.jpg
	{
		map textures/coop_skins/silencedpistol/hi_standard_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_silencedpistol_camo_woodland
{
	qer_editorimage textures/coop_skins/silencedpistol/hi_standard_camo_woodland.jpg
	{
		map textures/coop_skins/silencedpistol/hi_standard_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_silencedpistol_camo_winter
{
	qer_editorimage textures/coop_skins/silencedpistol/hi_standard_camo_winter.jpg
	{
		map textures/coop_skins/silencedpistol/hi_standard_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_silencedpistol_camo_desert
{
	qer_editorimage textures/coop_skins/silencedpistol/hi_standard_camo_desert.jpg
	{
		map textures/coop_skins/silencedpistol/hi_standard_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_springfield_gold
{
	qer_editorimage textures/models/weapons/springfield/springfield.tga
	{
		map textures/models/weapons/springfield/springfield.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_springfield_chrome
{
	qer_editorimage textures/models/weapons/springfield/springfield.tga
	{
		map textures/models/weapons/springfield/springfield.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_springfield_blued
{
	qer_editorimage textures/models/weapons/springfield/springfield.tga
	{
		map textures/models/weapons/springfield/springfield.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_springfield_bloody
{
	qer_editorimage textures/coop_skins/springfield/springfield_bloody.jpg
	{
		map textures/coop_skins/springfield/springfield_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_springfield_camo_woodland
{
	qer_editorimage textures/coop_skins/springfield/springfield_camo_woodland.jpg
	{
		map textures/coop_skins/springfield/springfield_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_springfield_camo_winter
{
	qer_editorimage textures/coop_skins/springfield/springfield_camo_winter.jpg
	{
		map textures/coop_skins/springfield/springfield_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_springfield_camo_desert
{
	qer_editorimage textures/coop_skins/springfield/springfield_camo_desert.jpg
	{
		map textures/coop_skins/springfield/springfield_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_sten_gold
{
	qer_editorimage models/weapons/sten_smg/sten.tga
	{
		map models/weapons/sten_smg/sten.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_sten_chrome
{
	qer_editorimage models/weapons/sten_smg/sten.tga
	{
		map models/weapons/sten_smg/sten.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_sten_blued
{
	qer_editorimage models/weapons/sten_smg/sten.tga
	{
		map models/weapons/sten_smg/sten.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_sten_bloody
{
	qer_editorimage textures/coop_skins/sten/sten_bloody.jpg
	{
		map textures/coop_skins/sten/sten_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_sten_camo_woodland
{
	qer_editorimage textures/coop_skins/sten/sten_camo_woodland.jpg
	{
		map textures/coop_skins/sten/sten_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_sten_camo_winter
{
	qer_editorimage textures/coop_skins/sten/sten_camo_winter.jpg
	{
		map textures/coop_skins/sten/sten_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_sten_camo_desert
{
	qer_editorimage textures/coop_skins/sten/sten_camo_desert.jpg
	{
		map textures/coop_skins/sten/sten_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_svt_rifle_gold
{
	qer_editorimage models/weapons/svt_rifle/svt.tga
	{
		map models/weapons/svt_rifle/svt.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_svt_rifle_chrome
{
	qer_editorimage models/weapons/svt_rifle/svt.tga
	{
		map models/weapons/svt_rifle/svt.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_svt_rifle_blued
{
	qer_editorimage models/weapons/svt_rifle/svt.tga
	{
		map models/weapons/svt_rifle/svt.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_svt_rifle_bloody
{
	qer_editorimage textures/coop_skins/svt_rifle/svt_bloody.jpg
	{
		map textures/coop_skins/svt_rifle/svt_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_svt_rifle_camo_woodland
{
	qer_editorimage textures/coop_skins/svt_rifle/svt_camo_woodland.jpg
	{
		map textures/coop_skins/svt_rifle/svt_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_svt_rifle_camo_winter
{
	qer_editorimage textures/coop_skins/svt_rifle/svt_camo_winter.jpg
	{
		map textures/coop_skins/svt_rifle/svt_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_svt_rifle_camo_desert
{
	qer_editorimage textures/coop_skins/svt_rifle/svt_camo_desert.jpg
	{
		map textures/coop_skins/svt_rifle/svt_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

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
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
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
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
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
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
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

coop_skin_tt33_gold_1
{
	qer_editorimage textures/models/weapons/tt33/tokarev.tga
	{
		map textures/models/weapons/tt33/tokarev.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_tt33_gold_0
{
	qer_editorimage textures/models/weapons/p38/p38.tga
	{
		map textures/models/weapons/p38/p38.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_tt33_chrome_1
{
	qer_editorimage textures/models/weapons/tt33/tokarev.tga
	{
		map textures/models/weapons/tt33/tokarev.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_tt33_chrome_0
{
	qer_editorimage textures/models/weapons/p38/p38.tga
	{
		map textures/models/weapons/p38/p38.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_tt33_blued_1
{
	qer_editorimage textures/models/weapons/tt33/tokarev.tga
	{
		map textures/models/weapons/tt33/tokarev.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_tt33_blued_0
{
	qer_editorimage textures/models/weapons/p38/p38.tga
	{
		map textures/models/weapons/p38/p38.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_tt33_bloody_1
{
	qer_editorimage textures/coop_skins/tt33/tokarev_bloody.jpg
	{
		map textures/coop_skins/tt33/tokarev_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_tt33_bloody_0
{
	qer_editorimage textures/coop_skins/tt33/p38_bloody.jpg
	{
		map textures/coop_skins/tt33/p38_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_tt33_camo_woodland_1
{
	qer_editorimage textures/coop_skins/tt33/tokarev_camo_woodland.jpg
	{
		map textures/coop_skins/tt33/tokarev_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_tt33_camo_woodland_0
{
	qer_editorimage textures/coop_skins/tt33/p38_camo_woodland.jpg
	{
		map textures/coop_skins/tt33/p38_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_tt33_camo_winter_1
{
	qer_editorimage textures/coop_skins/tt33/tokarev_camo_winter.jpg
	{
		map textures/coop_skins/tt33/tokarev_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_tt33_camo_winter_0
{
	qer_editorimage textures/coop_skins/tt33/p38_camo_winter.jpg
	{
		map textures/coop_skins/tt33/p38_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_tt33_camo_desert_1
{
	qer_editorimage textures/coop_skins/tt33/tokarev_camo_desert.jpg
	{
		map textures/coop_skins/tt33/tokarev_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_tt33_camo_desert_0
{
	qer_editorimage textures/coop_skins/tt33/p38_camo_desert.jpg
	{
		map textures/coop_skins/tt33/p38_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_tt33silenced_gold
{
	qer_editorimage textures/models/weapons/ppk/ppk_silencer.tga
	{
		map textures/models/weapons/ppk/ppk_silencer.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_tt33silenced_chrome
{
	qer_editorimage textures/models/weapons/ppk/ppk_silencer.tga
	{
		map textures/models/weapons/ppk/ppk_silencer.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_tt33silenced_blued
{
	qer_editorimage textures/models/weapons/ppk/ppk_silencer.tga
	{
		map textures/models/weapons/ppk/ppk_silencer.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_tt33silenced_bloody
{
	qer_editorimage textures/coop_skins/tt33silenced/ppk_silencer_bloody.jpg
	{
		map textures/coop_skins/tt33silenced/ppk_silencer_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_tt33silenced_camo_woodland
{
	qer_editorimage textures/coop_skins/tt33silenced/ppk_silencer_camo_woodland.jpg
	{
		map textures/coop_skins/tt33silenced/ppk_silencer_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_tt33silenced_camo_winter
{
	qer_editorimage textures/coop_skins/tt33silenced/ppk_silencer_camo_winter.jpg
	{
		map textures/coop_skins/tt33silenced/ppk_silencer_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_tt33silenced_camo_desert
{
	qer_editorimage textures/coop_skins/tt33silenced/ppk_silencer_camo_desert.jpg
	{
		map textures/coop_skins/tt33silenced/ppk_silencer_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_welrod_gold_0
{
	qer_editorimage textures/models/weapons/welrod/barrel.tga
	{
		map textures/models/weapons/welrod/barrel.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_welrod_gold_3
{
	qer_editorimage textures/models/weapons/welrod/misc.tga
	{
		map textures/models/weapons/welrod/misc.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_welrod_gold_1
{
	qer_editorimage textures/models/weapons/welrod/bolt.tga
	{
		map textures/models/weapons/welrod/bolt.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_welrod_gold_4
{
	qer_editorimage textures/models/weapons/welrod/rec.tga
	{
		map textures/models/weapons/welrod/rec.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_welrod_gold_2
{
	qer_editorimage textures/models/weapons/welrod/clip.tga
	{
		map textures/models/weapons/welrod/clip.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 1.00 0.78 0.30
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.40 0.31 0.12
	}
}

coop_skin_welrod_chrome_0
{
	qer_editorimage textures/models/weapons/welrod/barrel.tga
	{
		map textures/models/weapons/welrod/barrel.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_welrod_chrome_3
{
	qer_editorimage textures/models/weapons/welrod/misc.tga
	{
		map textures/models/weapons/welrod/misc.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_welrod_chrome_1
{
	qer_editorimage textures/models/weapons/welrod/bolt.tga
	{
		map textures/models/weapons/welrod/bolt.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_welrod_chrome_4
{
	qer_editorimage textures/models/weapons/welrod/rec.tga
	{
		map textures/models/weapons/welrod/rec.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_welrod_chrome_2
{
	qer_editorimage textures/models/weapons/welrod/clip.tga
	{
		map textures/models/weapons/welrod/clip.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.88 0.92 0.98
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.55 0.58 0.64
	}
}

coop_skin_welrod_blued_0
{
	qer_editorimage textures/models/weapons/welrod/barrel.tga
	{
		map textures/models/weapons/welrod/barrel.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_welrod_blued_3
{
	qer_editorimage textures/models/weapons/welrod/misc.tga
	{
		map textures/models/weapons/welrod/misc.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_welrod_blued_1
{
	qer_editorimage textures/models/weapons/welrod/bolt.tga
	{
		map textures/models/weapons/welrod/bolt.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_welrod_blued_4
{
	qer_editorimage textures/models/weapons/welrod/rec.tga
	{
		map textures/models/weapons/welrod/rec.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_welrod_blued_2
{
	qer_editorimage textures/models/weapons/welrod/clip.tga
	{
		map textures/models/weapons/welrod/clip.tga
		rgbGen lightingSpherical
	}
	{
		map $whiteimage
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen const 0.44 0.48 0.64
	}
	{
		map textures/coop_skins/env_sheen.tga
		blendFunc add
		tcGen environment
		rgbGen const 0.10 0.12 0.20
	}
}

coop_skin_welrod_bloody_0
{
	qer_editorimage textures/coop_skins/welrod/barrel_bloody.jpg
	{
		map textures/coop_skins/welrod/barrel_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_welrod_bloody_3
{
	qer_editorimage textures/coop_skins/welrod/misc_bloody.jpg
	{
		map textures/coop_skins/welrod/misc_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_welrod_bloody_1
{
	qer_editorimage textures/coop_skins/welrod/bolt_bloody.jpg
	{
		map textures/coop_skins/welrod/bolt_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_welrod_bloody_4
{
	qer_editorimage textures/coop_skins/welrod/rec_bloody.jpg
	{
		map textures/coop_skins/welrod/rec_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_welrod_bloody_2
{
	qer_editorimage textures/coop_skins/welrod/clip_bloody.jpg
	{
		map textures/coop_skins/welrod/clip_bloody.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_welrod_camo_woodland_0
{
	qer_editorimage textures/coop_skins/welrod/barrel_camo_woodland.jpg
	{
		map textures/coop_skins/welrod/barrel_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_welrod_camo_woodland_3
{
	qer_editorimage textures/coop_skins/welrod/misc_camo_woodland.jpg
	{
		map textures/coop_skins/welrod/misc_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_welrod_camo_woodland_1
{
	qer_editorimage textures/coop_skins/welrod/bolt_camo_woodland.jpg
	{
		map textures/coop_skins/welrod/bolt_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_welrod_camo_woodland_4
{
	qer_editorimage textures/coop_skins/welrod/rec_camo_woodland.jpg
	{
		map textures/coop_skins/welrod/rec_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_welrod_camo_woodland_2
{
	qer_editorimage textures/coop_skins/welrod/clip_camo_woodland.jpg
	{
		map textures/coop_skins/welrod/clip_camo_woodland.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_welrod_camo_winter_0
{
	qer_editorimage textures/coop_skins/welrod/barrel_camo_winter.jpg
	{
		map textures/coop_skins/welrod/barrel_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_welrod_camo_winter_3
{
	qer_editorimage textures/coop_skins/welrod/misc_camo_winter.jpg
	{
		map textures/coop_skins/welrod/misc_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_welrod_camo_winter_1
{
	qer_editorimage textures/coop_skins/welrod/bolt_camo_winter.jpg
	{
		map textures/coop_skins/welrod/bolt_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_welrod_camo_winter_4
{
	qer_editorimage textures/coop_skins/welrod/rec_camo_winter.jpg
	{
		map textures/coop_skins/welrod/rec_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_welrod_camo_winter_2
{
	qer_editorimage textures/coop_skins/welrod/clip_camo_winter.jpg
	{
		map textures/coop_skins/welrod/clip_camo_winter.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_welrod_camo_desert_0
{
	qer_editorimage textures/coop_skins/welrod/barrel_camo_desert.jpg
	{
		map textures/coop_skins/welrod/barrel_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_welrod_camo_desert_3
{
	qer_editorimage textures/coop_skins/welrod/misc_camo_desert.jpg
	{
		map textures/coop_skins/welrod/misc_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_welrod_camo_desert_1
{
	qer_editorimage textures/coop_skins/welrod/bolt_camo_desert.jpg
	{
		map textures/coop_skins/welrod/bolt_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_welrod_camo_desert_4
{
	qer_editorimage textures/coop_skins/welrod/rec_camo_desert.jpg
	{
		map textures/coop_skins/welrod/rec_camo_desert.jpg
		rgbGen lightingSpherical
	}
}

coop_skin_welrod_camo_desert_2
{
	qer_editorimage textures/coop_skins/welrod/clip_camo_desert.jpg
	{
		map textures/coop_skins/welrod/clip_camo_desert.jpg
		rgbGen lightingSpherical
	}
}
