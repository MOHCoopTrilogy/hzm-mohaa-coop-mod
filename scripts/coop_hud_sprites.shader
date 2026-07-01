// HZM Coop Mod - HUD / overhead icons.
//
// NOTE: Do NOT define explicit shader blocks for these textures/hud/* icons.
// R_RegisterShaderNoMip("textures/hud/<name>") resolves a bare name to the
// matching .tga as an IMPLICIT 2D image shader. That implicit path is what the
// working medkit/cover/binoc/smoke HUD icons use. An explicit block here with
// "rgbGen vertex" (and "nofog" inside the stage) parsed to an invisible shader
// that overrode the implicit load, so the axis/allies overhead icons never drew.
//
// Icons that load implicitly (leave them WITHOUT entries here):
//   textures/hud/axis_headicon.tga    - enemy/boss overhead icon  (CG_ActorBossIcon)
//   textures/hud/allies_headicon.tga  - allied paratrooper icon   (CG_ActorAllyIcon)
//   textures/hud/coop_binoc_icon.tga  - binoculars HUD item
//   textures/hud/coop_smoke_icon.tga  - signal smoke HUD item
//   textures/hud/coop_medkit_icon.tga - medkit HUD item
//   textures/hud/coop_cover_icon.tga  - sandbag/cover HUD item

// --- 3D overhead faction markers (camera-facing billboards on a unitsquare quad,
//     attached above actor heads via attachmodel). These ARE explicit shaders on
//     purpose: spritegen parallel can't be expressed via an implicit .tga load. ---
coop_axis_marker
{
	spritegen parallel
	surfaceparm nolightmap
	nomipmaps
	nopicmip
	cull none
	{
		map textures/hud/coop_axis_swastika.tga
		blendFunc blend
		rgbGen identity
	}
}

coop_allied_marker
{
	spritegen parallel
	surfaceparm nolightmap
	nomipmaps
	nopicmip
	cull none
	{
		map textures/hud/allies_headicon.tga
		blendFunc blend
		rgbGen identity
	}
}

// --- Overhead faction-marker SPRITES for the cgame RT_SPRITE path ---------------
// CG_ActorOverheadIcon registers these via R_RegisterModel("<name>.spr"); the engine
// strips ".spr" and resolves the shader of the same full-path name, building a
// camera-facing sprite (same mechanism as the stock textures/hud/axis_headicon icon).
// 32x32 to match the stock player icon so the engine's distance-scale law sizes it
// identically. Axis = swastika; ally = white star.
textures/hud/coop_axis_icon
{
	spritegen parallel
	surfaceparm nolightmap
	nomipmaps
	nopicmip
	cull none
	{
		map textures/hud/coop_axis_icon.tga
		blendFunc blend
		rgbGen identity
	}
}

textures/hud/coop_ally_icon
{
	spritegen parallel
	surfaceparm nolightmap
	nomipmaps
	nopicmip
	cull none
	{
		map textures/hud/coop_ally_icon.tga
		blendFunc blend
		rgbGen identity
	}
}

// Officer-only marker: the full Reichsadler (eagle + wreath/swastika), 64x32 so it reads
// a touch larger than the rank-and-file swastika. Sourced from the stock nazi_eagle.tga
// (shipped here since it's otherwise mainta-only).
textures/hud/coop_officer_icon
{
	spritegen parallel
	surfaceparm nolightmap
	nomipmaps
	nopicmip
	cull none
	{
		map textures/hud/coop_officer_icon.tga
		blendFunc blend
		rgbGen identity
	}
}
