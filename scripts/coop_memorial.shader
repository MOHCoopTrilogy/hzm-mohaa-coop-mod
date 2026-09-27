// HZM coop [user 2026-09-27] LAUNCH MEMORIAL - "In Memory of Vince Zampella", shown on black before the main menu
// by the exe's startup-intro stage (client/cl_ui.cpp, cl_memorial*). Art: docs/tools/gen_memorial.py (2048x1024,
// 24-bit, bottom-up TGA - bug-3019; the text is baked in because the game fonts are ASCII-only).
// Opaque on black like the retail intro cards (mohmenu.shader mohaa_title / legal): the engine fades it by colour,
// hence rgbGen global. Mipmaps ON (no nomipmaps): the card is drawn at 0.75x at 1080p and 1:1 at 1440p.
// ui/ path, not textures/: it ships in the small code pk3, not the asset pk3.
hzmMemorial
{
	nopicmip
	cull none
	force32bit
	surfaceparm nolightmap
	{
		clampMap ui/hzm_memorial/memorial.tga
		rgbGen global
	}
}
