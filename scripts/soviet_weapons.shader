// HZM coop [user 2026-08-17] - WHOLE-FILE OVERRIDE of a shader file the engine was REJECTING.
//
// The log said it outright and we read past it for weeks:
//   WARNING: Ignoring shader file scripts/soviet_weapons.shader ... missing opening brace
//
// MOHAA discards the ENTIRE FILE on one syntax error, so every shader it defines dies with it.
// For soviet_weapons that meant ppsh43, tt33, nagantrifle, Mosin-Nagant, scope, wrap, weas and
// f1_grenade all failed to resolve - which is why those guns were invisible in first person
// while their silencers and clips still drew (ppk_SILENCER and P38 are RETAIL shaders living in
// a different, valid file).
//
// This is byte-identical to the pack's original except for the fix noted below. Whole-FILE
// override is the documented pattern here (TRAPS T6): the filesystem dedupes shader files by
// NAME and the last pak to contain that name wins, and the coop pak sorts after the source pak.
// Removed: line 27 'Wrapping_06.tga' (shader name with no opening brace)

scope
{
	qer_editorimage textures/models/weapons/mosin_Nagant/scope.tga
	cull none
	{
		map textures/models/weapons/mosin_Nagant/scope.tga
		rgbGen lightingSpherical

	}
}
nagantrifle
{
	qer_editorimage textures/models/weapons/mosin_Nagant/mosin_Nagant.tga
	{
		map textures/models/weapons/mosin_Nagant/mosin_Nagant.tga
		rgbGen lightingSpherical
	}
}
Mosin-Nagant
{
	qer_editorimage textures/models/weapons/mosin_nagant/mosin-nagant.jpg
	{
		map textures/models/weapons/mosin_nagant/mosin-nagant.jpg
		rgbGen lightingSpherical
	}
}
wrap
{
	qer_editorimage textures/models/weapons/mosin_Nagant/Wrapping_06.tga
	{
		map textures/models/weapons/mosin_Nagant/Wrapping_06.tga
		rgbGen lightingSpherical
	}
}
weas
{
	qer_editorimage textures/models/weapons/mosin_nagant/weas.jpg
	{
		map textures/models/weapons/mosin_nagant/weas.jpg
		rgbGen lightingSpherical
	}
}
ppsh43
{
	qer_editorimage textures/models/weapons/ppsh43/ppsh43.tga
	cull none
	{
		map textures/models/weapons/ppsh43/ppsh43.tga
		rgbGen lightingSpherical
		alphaFunc GE128
		depthWrite
	}
	{
		map textures/effects/s93_gloss3.tga
		blendFunc blend
		depthFunc lequal
		rgbGen lightingSpherical
		tcGen environmentmodel
	nextbundle
		map textures/models/weapons/ppsh43/ppsh43_gloss.tga
		tcGen base
	}
}
tt33
{
      qer_editorimage textures/models/weapons/tt33/tokarev.tga
	cull none
      {
            map textures/models/weapons/tt33/tokarev.tga
            rgbGen lightingSpherical
      }
}
f1_grenade
{
      qer_editorimage textures/models/weapons/grenades/f1_grenade.tga
      cull none
      {
            map textures/models/weapons/grenades/f1_grenade.tga
            rgbGen lightingSpherical
      }
}
