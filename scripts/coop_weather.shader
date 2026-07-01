// HZM coop - dynamic-weather precipitation shaders. Our own (shipped) rain-streak + snow-flake so dynamic
// weather renders on any map without depending on a base-game precip texture being present (the blood bug
// was a missing base texture). Pointed at by the coop weather script via level.rain_shader, drawn as the
// rain "beams" by CG_RainGlobal / CG_Rain. rgbGen vertex so the rain system's per-drop color still applies.
textures/coop_rain
{
	{
		map textures/coop_rain.tga
		blendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA
		rgbGen vertex
	}
}

textures/coop_snow
{
	{
		map textures/coop_snow.tga
		blendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA
		rgbGen vertex
	}
}
