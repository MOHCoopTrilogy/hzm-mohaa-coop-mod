// HZM coop - blood ground-mark shader. polygonOffset gives the decal a depth bias so it stops Z-FIGHTING /
// flickering against the floor it sits on (coplanar surfaces flicker as the camera moves; the offset makes
// the mark always win the depth test). Unique name so it never collides with the base "bloodsplat" shader.
// Red is baked into the texture (rgbGen identity) so it renders red regardless of the decal's color path.
// The blood code (sentient.cpp TryDropBloodTrail / AddBloodSpurt) points its decals straight at this.
coop_bloodsplat
{
	polygonOffset
	{
		map textures/sprites/bloodsplat.tga
		blendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA
		rgbGen identity
	}
}

// HZM coop - PERSISTENT blood POOL under a dead body (sentient.cpp DropBloodPool). Distinct name so CG_Decal
// renders it WITHOUT the ~10s fade (cg_ents.c checks for "bloodpool"). polygonOffset stops z-fighting.
// bug-754: was  map bloodsplat.tga + rgbGen vertex  - the sparse SPLAT texture (flat #150200 = RGB 21,2,0)
// modulated by the decal's (0.50,0.03,0.03) tint rendered ~RGB(10,0,0) speckle = a pool that was never
// visible on any real floor. Now a dedicated SOLID pool blob (gen_blood_sprites.py gen_pool: dried rim ->
// fresh -> wet body -> arterial core, color baked in) rendered rgbGen identity so it reads everywhere.
coop_bloodpool
{
	polygonOffset
	{
		map textures/sprites/coop_bloodpool.tga
		blendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA
		rgbGen identity
	}
}

// HZM coop - GORE TIER 2 (blood drip): the falling STREAK a wounded human / fresh corpse drips
// (models/fx/coop_blooddrip*.tik emitters). Texture is the retail oil-streak ALPHA recolored to the
// mod's exact blood hue #150200 / RGB(21,2,0) - rgbGen identity so it always renders that baked hue
// (the retail barrel streak used lightingGrid; blood must never re-tint). alphaGen vertex lets the
// emitter's alpha/fade drive the fade-out.
coop_blood_long
{
	cull none
	{
		map textures/sprites/coop_blood_long.tga
		blendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA
		rgbGen identity
		alphaGen vertex
	}
}

// HZM coop - GORE TIER 2 (blood drip): tiny falling DROPLET sprite (referenced from the drip tiks as
// "coop_blood_drop.spr" - the renderer strips the extension when it looks the shader up, same trick
// as the retail barrel_oil_drop.spr). Same #150200 baked-hue rules as the streak above.
coop_blood_drop
{
	spriteGen parallel_oriented
	{
		map textures/sprites/coop_blood_drop.tga
		blendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA
		rgbGen identity
		alphaGen vertex
	}
}

// HZM coop - GORE TIER 3 (hit-location wound props): the wound patch itself (models/fx/coop_wound1.tik,
// attached engine-side at the LBD hit bone - sentient.cpp CoopGoreTryWoundProp). Hole + blood art with
// every blood pixel baked at the mod's exact hue #150200 / RGB(21,2,0), hole/dried rim at (7,1,0) -
// rgbGen identity so it always renders those baked values. cull none because the xbeam crossed quads
// must read from both sides.
coop_wound1
{
	cull none
	{
		map textures/sprites/coop_wound1.tga
		blendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA
		rgbGen identity
	}
}

// HZM coop - DISMEMBERMENT PHASE 0 (decapitation): the NECK-STUMP CAP (models/fx/coop_stump_neck.tik,
// attached engine-side at "Bip01 Neck" - sentient.cpp CoopGoreTryDecapitate). Solid wet-blood mass with
// every pixel baked at the mod's exact hue #150200 - reuses the SOLID coop_bloodpool blob sprite (no hole,
// unlike the wound1 bullet-hole art) so the crossed quads read as a filled neck cap. cull none so the
// crossed quads show from both sides; rgbGen identity so it always renders the baked #150200. No
// polygonOffset (this is a floating attached prop, not a coplanar floor decal).
coop_stump
{
	cull none
	{
		map textures/sprites/coop_bloodpool.tga
		blendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA
		rgbGen identity
	}
}
