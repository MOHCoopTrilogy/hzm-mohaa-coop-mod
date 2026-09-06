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

// [user 2026-09-04] AND THEN IT WAS TOO MUCH. "when bullets hit walls they create an excessive
// amount of smoke... was it from the ask to make the bullets hitting the bunkers visible yesterday?"
// Yes - this file is that change, and defining the name did exactly what it was supposed to. The
// problem is WHAT the name was pointing at.
//
// STONE IS THE DEFAULT IMPACT SURFACE. CG_ParseCGMessage's untyped case is SFX_BHIT_STONE_LITE
// (cg_parsemsg.cpp:1812), so a round into any surface with no surfaceparm - which is most walls in
// the game - runs the stone effect. And zzzzzz_hd_fx.pk3's rewrite of bh_stone_lite/hard is far
// heavier than retail's: measured out of both tiks, the puff element goes alpha 0.2 -> 0.75, count
// 3 -> 5 and scale .4-.7 -> .7-1. That is roughly 3.7x the opacity at twice the size, on every
// wall hit in the game. While the shader was undefined nobody saw it (white squares instead); the
// moment it resolved, it became smoke.
//
// WE CANNOT FIX THE TIKS - zzzzzz_hd_fx.pk3 sorts AFTER zzzzzz_co-op_hzm_mod_*, so it wins that
// name and a coop-pak override could never load. Never edit a third-party pak in place either; the
// next re-import reverts it. But the SHADER NAME IS OURS, uncontested, so what it draws is ours.
//
// SO IT DRAWS RETAIL'S OWN STONE DUST. This stanza is now a verbatim copy of `vsssource` from
// main/Pak0.pk3 scripts/sprites.shader - the sprite retail's OWN bh_stone_lite uses for this exact
// element - instead of the HD pack's solid snow puff. Two counter-rotating bundles of a soft dust
// wisp rather than one opaque white ball, so the pack's heavy alpha and count land on art that is
// meant to be faint. The white squares stay fixed (the name still resolves), the effect still reads
// as a round striking stone, and it stops fogging the map.
// To go back to the HD pack's look: restore the single `map textures/effects/bh_snow_puff1.tga`
// stage below. To remove the effect entirely, delete this stanza - but that brings the white
// squares back, so do not.
bh_snow_puff1
{
	nopicmip
	surfaceparm nolightmap
	spritegen parallel
	noMerge
	cull twosided
	{
		clampmap textures/sprites/vsssource.tga
		blendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA
		tcMod rotate 20
		rgbGen vertex
		alphaGen vertex
	nextbundle
		map textures/sprites/vsssource2.tga
		tcMod rotate -20
	}
}
