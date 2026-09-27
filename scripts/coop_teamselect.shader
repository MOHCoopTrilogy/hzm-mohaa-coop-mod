// [user 2026-09-21] Team-select screen materials. Referencing a TGA by raw path from the .urc gets
// nomipmaps/nopicmip automatically but SKIPS force32bit, so the GPU format falls back to r_texturebits/
// r_colorbits (often 16-bit) - which BANDS smooth gradients badly (the "pixelated as hell" the user saw on
// the backdrop/panels). These named shaders force full 32-bit color like every crisp vanilla mohmenu entry
// (same recipe as coop_loadscreens.shader). The .urc references them by NAME, not by .tga path.

coop_ts_bg
{
	nomipmaps
	nopicmip
	cull none
	force32bit
	surfaceparm nolightmap
	{
		clampMap textures/mohmenu/coop_ts_bg.tga
	}
}

coop_ts_panel_allies
{
	nomipmaps
	nopicmip
	cull none
	force32bit
	surfaceparm nolightmap
	{
		clampMap textures/mohmenu/coop_ts_panel_allies.tga
		blendfunc blend
	}
}

coop_ts_panel_axis
{
	nomipmaps
	nopicmip
	cull none
	force32bit
	surfaceparm nolightmap
	{
		clampMap textures/mohmenu/coop_ts_panel_axis.tga
		blendfunc blend
	}
}

coop_ts_allies_emblem
{
	nomipmaps
	nopicmip
	cull none
	force32bit
	surfaceparm nolightmap
	{
		clampMap textures/mohmenu/coop_ts_allies.tga
		blendfunc blend
	}
}

coop_ts_axis_emblem
{
	nomipmaps
	nopicmip
	cull none
	force32bit
	surfaceparm nolightmap
	{
		clampMap textures/mohmenu/coop_ts_axis.tga
		blendfunc blend
	}
}

coop_ts_spec_emblem
{
	nomipmaps
	nopicmip
	cull none
	force32bit
	surfaceparm nolightmap
	{
		clampMap textures/mohmenu/coop_ts_spec.tga
		blendfunc blend
	}
}

coop_brace_mount
{
	nomipmaps
	nopicmip
	cull none
	force32bit
	surfaceparm nolightmap
	{
		clampMap textures/mohmenu/coop_brace_mount.tga
		blendfunc blend
	}
}
