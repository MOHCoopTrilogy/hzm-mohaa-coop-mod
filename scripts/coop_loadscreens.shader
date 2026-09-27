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

// HZM coop [user 2026-09-26] LOADING-SCREEN MEDAL - ui/loadingbar.txt widget hzm_loadmedal, on every loading
// screen. Art: docs/tools/gen_loadscreen_medal.py (256x256 RGBA uncompressed TGA; never DXT - TRAPS T2).
// Stage 1 is the static compass ring. Stage 2 is the star: 24 frames pre-lit under a FIXED top-left light,
// 3 deg apart over 72 deg (5-fold symmetry: frame 24 == frame 0). animMap 10 = 10 frames/s = 30 deg/s.
// NEVER 24 (72 deg/s) or 48 (144 deg/s): a redraw gap near 1 s would then land on the same frame and the
// star looks frozen. At 30 deg/s even a 1 s load stall moves it 30 deg, which still reads as forward.
// animMap phase is wall-clock time in 2D (bug-1147), so the star is at the right angle on every redraw.
// No nomipmaps on purpose: it is drawn at 72-216 px from a 256 px texture, and mips keep the ticks clean.
// ui/ path, not textures/: the art ships in the small code pk3 (precedent ui/coop_tiles), not the asset pk3.
hzmLoadMedal
{
	nopicmip
	cull none
	force32bit
	surfaceparm nolightmap
	{
		clampMap ui/hzm_loadscreen/medal_ring.tga
		blendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA
	}
	{
		animMap 10 ui/hzm_loadscreen/medal_star_00.tga ui/hzm_loadscreen/medal_star_01.tga ui/hzm_loadscreen/medal_star_02.tga ui/hzm_loadscreen/medal_star_03.tga ui/hzm_loadscreen/medal_star_04.tga ui/hzm_loadscreen/medal_star_05.tga ui/hzm_loadscreen/medal_star_06.tga ui/hzm_loadscreen/medal_star_07.tga ui/hzm_loadscreen/medal_star_08.tga ui/hzm_loadscreen/medal_star_09.tga ui/hzm_loadscreen/medal_star_10.tga ui/hzm_loadscreen/medal_star_11.tga ui/hzm_loadscreen/medal_star_12.tga ui/hzm_loadscreen/medal_star_13.tga ui/hzm_loadscreen/medal_star_14.tga ui/hzm_loadscreen/medal_star_15.tga ui/hzm_loadscreen/medal_star_16.tga ui/hzm_loadscreen/medal_star_17.tga ui/hzm_loadscreen/medal_star_18.tga ui/hzm_loadscreen/medal_star_19.tga ui/hzm_loadscreen/medal_star_20.tga ui/hzm_loadscreen/medal_star_21.tga ui/hzm_loadscreen/medal_star_22.tga ui/hzm_loadscreen/medal_star_23.tga
		blendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA
	}
}
