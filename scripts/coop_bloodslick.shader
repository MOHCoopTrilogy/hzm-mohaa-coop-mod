// HZM coop [user 2026-08-31] BLOOD SLICK for Omaha - pools under the beach dead.
//
// Own name + private texture path, per the shader-isolation recipe (bug-922): a contested shader name
// loses silently and the failure looks like a texture bug, so never reuse a retail name.
//
// The texture is a COPY of textures/sprites/coop_bloodpool.tga to a new path, deliberately. Editing
// textures/coop_gore/coop_bloodsplash.tga in place was the tempting shortcut and is wrong: that file
// is live engine gore art, loaded directly by tr_gore.c in BOTH renderers, and it is already at the
// engine's hard 256x256 cap.
//
// ONE stage only. The surface this lands on at the waterline is already 6 stages x 2 texture bundles
// of scrolling water plus a deformVertexes flap; a second blended stage here is cheap, a third is not.
// polygonOffset earns its keep on the sand, where the ground underneath is opaque.
coop_bloodslick
{
	cull none
	polygonOffset
	qer_editorimage textures/coop_fx/bloodslick.tga
	{
		map textures/coop_fx/bloodslick.tga
		blendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA
		rgbGen identity
	}
}
