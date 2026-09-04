// coop_hdfx_missing.shader - definitions an imported HD FX pack referenced but never made loadable.
//
// [user 2026-09-02] "I still see random white squares under water... not sure what the hell is
// causing that."
//
// WHAT WAS HAPPENING
//   zzzzzz_hd_fx.pk3 rewrites models/fx/bh_stone_hard.tik and bh_stone_lite.tik - the STONE
//   bullet-hole effects - to use a sprite named `bh_snow_puff1.spr`, and defines that shader in
//   textures/sprites/effects.shader.
//
//   The engine never reads that file. ScanAndLoadShaderFiles calls
//   ri.FS_ListFiles("scripts", ".shader") (renderergl2/tr_shader.c:4931) and scans ONLY scripts/.
//   A .shader anywhere else is inert. So `bh_snow_puff1` was undefined everywhere, the reference
//   fell through to a raw image load, that failed - the live log carries
//   "Couldn't find image file for shader bh_snow_puff1.spr" - and the renderer substituted the
//   DEFAULT texture, which is white. Every round striking stone drew a white square. Under the
//   water that is the seabed and the seawall, which is where the user saw them.
//
//   The other three sprites those tiks reference (bh_stone_piece, stonechip, vsssource) are all
//   defined in retail's own scripts/effects.shader and scripts/sprites.shader, which is why only
//   this one ever complained. The set was checked; this is its only member.
//
// WHY THE FIX IS A NEW FILE UNDER scripts/ AND NOT AN EDIT TO THE IMPORT
//   The texture the pack ships is fine - textures/effects/bh_snow_puff1.tga, 36,908 bytes, present
//   in zzzzzz_hd_fx.pk3. Only the DEFINITION was unreachable. Defining it here is uncontested: no
//   scanned scripts/*.shader in any mounted pak declares this name, so there is no reverse-concat
//   race to lose (docs/TRAPS.md T6) and nothing stock is being repainted. Never edit a third-party
//   pak in place - the next re-import silently reverts it.
//
//   The stanza is copied VERBATIM from retail's own bh_snow_puff in main/Pak0.pk3
//   scripts/effects.shader, with only the texture path changed. Same reasoning as every other
//   borrowed definition in this project: copy the working recipe, do not invent one.

bh_snow_puff1
{
	spritegen parallel_oriented
	cull none
	{
		map textures/effects/bh_snow_puff1.tga
		blendFunc blend
		alphaGen vertex
		rgbGen vertex
	}
}
