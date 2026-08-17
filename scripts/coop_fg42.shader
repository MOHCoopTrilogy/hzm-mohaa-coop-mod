// HZM coop [user 2026-08-17] - FG42 shader.
// From the FG42 Add-On by RoempaZ / DaRKaNGeL (moh-db.com/mods/17867). Model and skin
// are 2015/EA Games; the RIG and ANIMATIONS are DaRKaNGeL's, and they are the reason
// this weapon can exist at all - retail's fg42.skd has a single bone and no tags.
// Kept in its own file rather than appended to a shared one: a syntax error in a shader
// file makes the engine discard the WHOLE file, which is exactly what killed every
// Soviet weapon via soviet_weapons.shader. Small files fail small.
fg42
{
	qer_editorimage textures/fg42/fg42.jpg
	{
		map textures/fg42/fg42.jpg
		rgbGen lightingSpherical
	}
}
