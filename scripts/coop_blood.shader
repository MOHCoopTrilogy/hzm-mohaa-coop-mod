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
// renders it WITHOUT the ~10s fade (cg_ents.c checks for "bloodpool"). rgbGen vertex so the decal's setColor
// (dark crimson) tints it darker than a fresh hit splat = a settled pool. polygonOffset stops z-fighting.
coop_bloodpool
{
	polygonOffset
	{
		map textures/sprites/bloodsplat.tga
		blendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA
		rgbGen vertex
	}
}
