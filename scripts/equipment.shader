// HZM coop OVERRIDE of equipment.shader (original in zzzzzz-HRRTM_Pak2_Models_misc.pk3).
// Whole-file copy: the coop pk3 mounts AFTER HRRTM, so FS_AddFileToList dedupes by name and ONLY this
// copy loads (same proven pattern as our allied_bob_pack.shader override, bug-525 - a shader-NAME
// override in another file loses the reverse-concat race). ONLY the five defs below are changed:
// bob45holster / 101_knife / 101_grenade / 2gren_left / 2gren_right -> rgbGen identity. Their skds
// (bob45holster.skd, 101_knife.skd, 101_granade.skd, ranger_2grenades.skd - ALL from the HRRTM import
// pack) have the same bad vertex normals as dmedipack.skd: under rgbGen lightingSpherical the
// spherical-harmonic lighting integrates to ~0 = solid BLACK gear patches on the 82nd/101st airborne
// skins and the AI paradrop soldier (bug-921; completes the bug-499/525/530 family).

2gren_right
{
	qer_editorimage textures/RI/2grenades.tga
	{
		map textures/RI/2grenades.tga
		rgbGen identity	// HZM coop bug-921: bad import-skd normals -> black under lightingSpherical
	}
}

2gren_left
{
	qer_editorimage textures/RI/2grenades.tga
	{
		map textures/RI/2grenades.tga
		rgbGen identity	// HZM coop bug-921: bad import-skd normals -> black under lightingSpherical
	}
}

r_knife
{
	qer_editorimage textures/RI/r_equip.tga
	{
		map textures/RI/r_equip.tga
		rgbGen lightingSpherical
	}
}

bob45holster
{
	qer_editorimage textures/models/101holster.tga
	{
		map textures/models/101holster.tga
		rgbGen identity	// HZM coop bug-921: bad import-skd normals -> black under lightingSpherical
	}
}
pouch_thingy
{
	qer_editorimage textures/pouch_thingy.jpg
	{
		map textures/pouch_thingy.jpg
		rgbGen lightingSpherical
	}
}

101_knife
{
	qer_editorimage textures/models/101knife.tga
	{
		map textures/models/101knife.tga
		rgbGen identity	// HZM coop bug-921: bad import-skd normals -> black under lightingSpherical
	}
}

101_grenade
{
	qer_editorimage textures/models/101grenade.tga
	{
		map textures/models/101grenade.tga
		rgbGen identity	// HZM coop bug-921: bad import-skd normals -> black under lightingSpherical
	}
}

binoculars
{
	qer_editorimage textures/binoculars.tga
	{
		map textures/binoculars.tga
		rgbGen lightingSpherical
	}
}
ushelm
{
	qer_editorimage textures/ushelm.jpg
	{
		map textures/ushelm.jpg
		rgbGen lightingSpherical
	}
}