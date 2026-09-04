commando_pants
{
	qer_editorimage textures/models/human/germanmaps/commando/commando_pants.tga
	{
		map textures/models/human/germanmaps/commando/commando_pants.tga
		rgbGen lightingSpherical
	}
}
commando_tunic
{
	qer_editorimage textures/models/human/germanmaps/commando/commando_tunic.tga
	{
		map textures/models/human/germanmaps/commando/commando_tunic.tga
		rgbGen lightingSpherical
	}
}
commando_helmet
{
	qer_editorimage textures/models/human/germanmaps/commando/commando_helmet.tga
	{
		map textures/models/human/germanmaps/commando/commando_helmet.tga
		rgbGen lightingSpherical
	}
}
commando_tunic_c
{
	qer_editorimage textures/models/human/germanmaps/commando/commando_tunic.tga
	cull none
	{
		map textures/models/human/germanmaps/commando/commando_tunic.tga
		rgbGen lightingSpherical
	}
}
static_commando_helmet
{
	cull none
	qer_editorimage textures/models/human/germanmaps/commando/commando_helmet.tga	
{
		map textures/common/reflection1.tga
		rgbGen vertex
		tcgen environmentmodel
	}
	{
		map textures/models/human/germanmaps/commando/commando_helmet.tga	
		rgbGen vertex
		blendfunc gl_one_minus_src_alpha gl_src_alpha 
	}
}

//{
//	qer_editorimage textures/models/human/germanmaps/commando/commando_helmet.tga
//	cull none
//	{
//		map textures/models/human/germanmaps/commando/commando_helmet.tga
//		rgbGen lightingSpherical
//	}
//}

wf_face
{
	qer_editorimage textures/models/human/germanmaps/ss1/heinz4.tga
	{
		map textures/models/human/germanmaps/ss1/heinz4.tga
		rgbGen lightingSpherical
	}
}

we_gear
{
	qer_editorimage textures/models/gear/german_gear/german_gear.tga
	{
		map textures/models/gear/german_gear/german_gear.tga
		rgbGen lightingSpherical
	}
}

we_riflebelt
{
	qer_editorimage textures/models/gear/german_gear/riflebelt.tga
	{
		map textures/models/gear/german_gear/riflebelt.tga
		rgbGen lightingSpherical
	}
}

d_works
{
	qer_editorimage textures/models/human/germanmaps/d_german.tga
	{
		map textures/models/human/germanmaps/d_german.tga
		rgbGen lightingSpherical
	}
}







static_wehrmact_tunic
{
	qer_editorimage textures/models/human/germanmaps/wehrmact/wehrmact_tunic.tga
	{
		map textures/models/human/germanmaps/wehrmact/wehrmact_tunic.tga
		rgbGen static
	}
}

static_wehrmact_pants
{
	qer_editorimage textures/models/human/germanmaps/wehrmact/wehrmact_pants.tga
	{
		map textures/models/human/germanmaps/wehrmact/wehrmact_pants.tga
		rgbGen static
	}
}

// [2026-09-01, bug-2243] static_wehrmact_helmet REMOVED from this file.
//
// This is a COMMANDO skin file. It also carried 18 blocks redefining retail Wehrmacht uniform
// shaders - collateral from an imported pack, not a deliberate override. 17 of those 18 are
// byte-identical to retail and are harmless no-ops, so they are left alone. This one was not:
// retail's static_wehrmact_helmet is TWO stages - an environment-mapped reflection under the
// helmet diffuse - and this copy was a single flat rgbGen static, so German steel helmets lost
// their sheen wherever this file won.
//
// It won on gl1 all along. It began winning on gl2 too when bug-2228 corrected gl2's inverted
// shader-name precedence, which is why the helmets visibly flattened in v1.4.8. Deleting the
// block hands the surface back to retail on BOTH renderers and restores the reflection.

static_wehrmact_face
{
	qer_editorimage textures/models/human/germanmaps/wehrmact/wehrmact_face.tga
	{
		map textures/models/human/germanmaps/wehrmact/wehrmact_face.tga
		rgbGen static
	}
}

static_wehrmact_gear
{
	qer_editorimage textures/models/gear/german_gear/german_gear.tga
	{
		map textures/models/gear/german_gear/german_gear.tga
		rgbGen static
	}
}

static_wehrmact_riflebelt
{
	qer_editorimage textures/models/gear/german_gear/riflebelt.tga
	{
		map textures/models/gear/german_gear/riflebelt.tga
		rgbGen static
	}
}

static_d_works
{
	qer_editorimage textures/models/human/germanmaps/d_german.tga
	{
		map textures/models/human/germanmaps/d_german.tga
		rgbGen static
	}
}

/////////////////////////////////////////////////////////////////////////////////////
//uniform color variants
/////////////////////////////////////////////////////////////////////////////////////

wehrmact_tunic_olive
{
	qer_editorimage textures/models/human/germanmaps/wehrmact/Wtunicolive.tga
	{
		map textures/models/human/germanmaps/wehrmact/Wtunicolive.tga
		rgbGen lightingSpherical
	}
}

wehrmact_tunic_fieldgrey
{
	qer_editorimage textures/models/human/germanmaps/wehrmact/Wtunicfgrey.tga
	{
		map textures/models/human/germanmaps/wehrmact/Wtunicfgrey.tga
		rgbGen lightingSpherical
	}
}
wehrmact_tunic_fieldgrey_c
{
	qer_editorimage textures/models/human/germanmaps/wehrmact/Wtunicfgrey.tga
	cull none
	{
		map textures/models/human/germanmaps/wehrmact/Wtunicfgrey.tga
		rgbGen lightingSpherical
	}
}
static_wehrmact_tunic_fieldgrey
{
	qer_editorimage textures/models/human/germanmaps/wehrmact/Wtunicfgrey.tga
	{
		map textures/models/human/germanmaps/wehrmact/Wtunicfgrey.tga
		rgbGen vertex
	}
}

wehrmact_tunic_green
{
	qer_editorimage textures/models/human/germanmaps/wehrmact/Wtunicgreen.tga
	{
		map textures/models/human/germanmaps/wehrmact/Wtunicgreen.tga
		rgbGen lightingSpherical
	}
}
wehrmact_tunic_green_c
{
	qer_editorimage textures/models/human/germanmaps/wehrmact/Wtunicgreen.tga
	cull none
	{
		map textures/models/human/germanmaps/wehrmact/Wtunicgreen.tga
		rgbGen lightingSpherical
	}
}
wehrmact_pants_olive
{
	qer_editorimage textures/models/human/germanmaps/wehrmact/WPantsolive.tga
	{
		map textures/models/human/germanmaps/wehrmact/WPantsolive.tga
		rgbGen lightingSpherical
	}
}

wehrmact_pants_green
{
	qer_editorimage textures/models/human/germanmaps/wehrmact/WPantsgreen.tga
	{
		map textures/models/human/germanmaps/wehrmact/WPantsgreen.tga
		rgbGen lightingSpherical
	}
}

wehrmact_pants_fgrey
{
	qer_editorimage textures/models/human/germanmaps/wehrmact/Wpantsfgrey.tga
	{
		map textures/models/human/germanmaps/wehrmact/Wpantsfgrey.tga
		rgbGen lightingSpherical
	}
}
static_wehrmact_pants_fgrey
{
	qer_editorimage textures/models/human/germanmaps/wehrmact/Wpantsfgrey.tga
	{
		map textures/models/human/germanmaps/wehrmact/Wpantsfgrey.tga
		rgbGen vertex
	}
}
