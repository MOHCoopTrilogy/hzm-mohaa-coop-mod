// HZM coop - explicit named shaders for single-texture loading screens. Referencing a texture path
// directly from a .urc Label (the mod's older convention) still gets nomipmaps/nopicmip automatically
// (the UI's Rend_RegisterMaterial is bound to RE_RegisterShaderNoMip), but skips force32bit, so its
// internal GPU format falls back to r_texturebits/r_colorbits instead of always being full 32-bit color.
// Matches the pattern every vanilla mohmenu.shader entry already uses.
coop_load_m1l1
{
	nomipmaps
	nopicmip
	cull none
	force32bit
	surfaceparm nolightmap
	{
		clampMap textures/mohmenu/loadscreens/m1l1.tga
	}
}
