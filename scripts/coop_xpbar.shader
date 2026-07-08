// HZM coop - XP/rank progress bar layer shaders (prototype, wired by coop_mod/xp.scr::xp_hud_popup).
// Only the ANIMATED/ADDITIVE layers need explicit shaders; xpbar_base / xpbar_fill / xpbar_plate are
// plain TGAs and use the engine's implicit 2D shader (alpha blend + global color/alpha) - do NOT add
// entries for them here or they lose the huddraw color path.
//
// Facts this file relies on (verified in openmohaa-hzm renderergl1):
//  - cgame huddraw resolves ihuddraw_shader via R_RegisterShaderNoMip -> R_FindShader, which checks
//    scripts/*.shader text FIRST, so these named entries fully apply to huddraw quads.
//  - explicit stage images load with GL_REPEAT (tr_shader.c ParseStage), so tcMod scroll loops.
//  - "rgbGen global" / "alphaGen global" bind the stage to ihuddraw_color / ihuddraw_alpha
//    (CGEN_GLOBAL_COLOR / AGEN_GLOBAL_ALPHA - same thing the implicit 2D shader uses).

// Moving shine sweep, drawn additively in the SAME rect as the fill each frame so the fill width
// masks it. Scroll -0.4 = one full sweep every 2.5s, right to left texture space = leftward light
// travel; flip the sign if the sweep should run toward the fill head instead.
textures/hud/xpbar/xpbar_shine
{
	nomipmaps
	{
		map textures/hud/xpbar/xpbar_shine.tga
		blendFunc GL_SRC_ALPHA GL_ONE
		rgbGen global
		alphaGen global
		tcMod scroll -0.4 0
	}
}

// Fill head glint: additive warm spark at the leading edge of the fill. rgbGen wave gives it a
// slow breathing pulse (0.7..1.0 brightness @ ~1.4Hz); alphaGen global keeps the script fade-out
// working. NOTE: ihuddraw_color does NOT tint this layer (wave replaces global color) - by design.
textures/hud/xpbar/xpbar_head
{
	nomipmaps
	{
		map textures/hud/xpbar/xpbar_head.tga
		blendFunc GL_SRC_ALPHA GL_ONE
		rgbGen wave sin 0.85 0.15 0 1.4
		alphaGen global
	}
}

// Rank-up halo behind the emblem plate. Pure additive; the script drives the pulse by animating
// ihuddraw_alpha (0.9 -> 0 over ~0.8s on promotion), so no wave here.
textures/hud/xpbar/xpbar_glow
{
	nomipmaps
	{
		map textures/hud/xpbar/xpbar_glow.tga
		blendFunc GL_SRC_ALPHA GL_ONE
		rgbGen global
		alphaGen global
	}
}
