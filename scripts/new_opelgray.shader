// HZM coop [user 2026-08-17] - WHOLE-FILE OVERRIDE of a shader file the engine was REJECTING.
//
// The log said it outright and we read past it for weeks:
//   WARNING: Ignoring shader file scripts/new_opelgray.shader ... missing opening brace
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
// Removed: line 1 '}' (stray closing brace at top level)

opelgrau
{
	qer_editorimage textures/models/vehicles/OpelTruck/opelgrau.tga
	{
		map textures/models/vehicles/OpelTruck/opelgrau.tga
		rgbGen lightingSpherical
	}
}
opel_cullgrau
{
	qer_editorimage textures/models/vehicles/OpelTruck/opelgrau.tga
	cull none
	{
		map textures/models/vehicles/OpelTruck/opelgrau.tga
		rgbGen lightingSpherical
	}
}

opelhubgrau
{
	qer_editorimage textures/models/vehicles/OpelTruck/opelhubgrau.tga
	{
		map textures/models/vehicles/OpelTruck/opelhubgrau.tga
		rgbGen lightingSpherical
	}
}