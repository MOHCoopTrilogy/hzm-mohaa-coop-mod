// HZM coop OVERRIDE of allied_bob_pack.shader (original in zzzzzz-HRRTM_Pak2_Models_misc.pk3).
// The coop pk3 mounts AFTER HRRTM, so this whole file wins the FS lookup (FS_AddFileToList dedupes by
// name -> only this copy loads), avoiding the fragile shader-NAME override that lost the race before
// (bug: reverse-concat in ScanAndLoadShaderFiles made the later-loaded HRRTM def win). ONLY dday_medipack-1
// is changed vs the original; every other surface keeps its original lightingSpherical.


lt_helmet
{
	qer_editorimage textures/models/lt_helmet.tga
	
	{
		map textures/models/lt_helmet.tga
		rgbGen lightingSpherical
	}
}

lt_helmet_camo
{
	qer_editorimage textures/models/lt_camo_helmet.tga
	
	{
		map textures/models/lt_camo_helmet.tga
		rgbGen lightingSpherical
	}
}

sgt_helmet
{
	qer_editorimage textures/models/sgt_helmet.tga
	
	{
		map textures/models/sgt_helmet.tga
		rgbGen lightingSpherical
	}
}

sgt_helmet_camo
{
	qer_editorimage textures/models/sgt_camo_helmet.tga
	
	{
		map textures/models/sgt_camo_helmet.tga
		rgbGen lightingSpherical
	}
}


pvt_helmet
{
	qer_editorimage textures/models/pvt_helmet.tga
	
	{
		map textures/models/pvt_helmet.tga
		rgbGen lightingSpherical
	}
}

pvt_helmet_camo
{
	qer_editorimage textures/models/pvt_camo_helmet.tga
	
	{
		map textures/models/pvt_camo_helmet.tga
		rgbGen lightingSpherical
	}
}

helmet_inside_bob
{
	qer_editorimage textures/models/blank_inside.tga
	
	{
		map textures/models/blank_inside.tga
		rgbGen identity	// HZM coop: was lightingSpherical -> black on this separate overlay model's bad normals (bug-525)
	}
}

priest_glass
{
	qer_editorimage textures/models/glasses.tga
	cull none
	//{
	//	map textures/models/glasses.tga
	//	tcGen environment
	//}
	{
		map textures/models/glasses.tga
		blendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA
	}
	{
		map $lightmap
		rgbGen Identity
		blendFunc GL_DST_COLOR GL_ZERO
	}
}	

//priest_glass
//{
//	qer_editorimage textures/models/glasses.tga
//	cull none
//	{
//		map textures/models/glasses.tga
//		rgbGen lightingSpherical
//	}
//}

priest_glass_frames
{
	qer_editorimage textures/models/glasses.tga
	cull none
	{
		map textures/models/glasses.tga
		rgbGen lightingSpherical
	}
}

doc_scissors
{
	qer_editorimage textures/models/scissors.tga
	{
		map textures/models/scissors.tga
		rgbGen lightingSpherical
	}
}

dday_medipack-1
{
	qer_editorimage textures/models/dmedipack.tga
	{
		map textures/models/dmedipack.tga
		rgbGen identity	// HZM coop: was lightingSpherical -> the dmedipack.skd's bad normals
					// integrate to ~0 under spherical-harmonic lighting = solid BLACK pouch on every 82nd/101st
					// airborne skin (all except 82nd sgt, who has no medipack). identity uses the baked tan
					// texture directly so it is always visible. bug-499.
	}
}

dday_camo_hel
{
	qer_editorimage textures/models/camo_base-1.tga
	cull none
	{
		map textures/models/camo_base-1.tga
		rgbGen identity	// HZM coop: was lightingSpherical -> black on this separate overlay model's bad normals (bug-525)
	}
}