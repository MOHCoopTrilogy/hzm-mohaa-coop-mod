// [user 2026-08-08] ENIGMA MACHINE - the shader retail never wrote.
//
// models/animate/enigmaclosed.tik and enigmaopen.tik both map their surfaces to shaders named
// "enigma" and "enigmatext". Neither is defined ANYWHERE in the retail paks - I checked every
// .shader in every pak. The textures do ship (textures/models/submodels/enigma.tga at 786 KB and
// enigmatext.tga at 262 KB, both in Pak2), and the models ship, and the map even carries an entity
// for it - but with no shader the engine logs "Couldn't find image file for shader enigma" and the
// model draws nothing at all. Submitted, sized, lit, invisible.
//
// That is the real reason this is cut content: the reveal was commented out of m2l2b because the
// machine could never have appeared. scripts/submodels.shader defines the static_ variants used by
// the baked set-dressing Enigma elsewhere on the boat, and the dynamic pair was simply never done.
//
// rgbGen lightingSpherical, not static: this is a script_model that gets swapped in at runtime and
// has to take the room's lighting. rgbGen static is for geometry baked at compile time, which is
// what the static_ variants in submodels.shader are for.

enigma
{
	qer_editorimage textures/models/submodels/enigma.tga
	{
		map textures/models/submodels/enigma.tga
		rgbGen lightingSpherical
	}
}

// enigmatext.tga is 256x256 32-bit with a real 8-bit alpha channel (enigma.tga is 24-bit and needs
// none). cull none / alphaFunc GE128 / depthwrite are copied verbatim from retail's static_enigmatext
// in scripts/submodels.shader - without the alphaFunc the cut-out areas draw opaque and the lettering
// plate becomes a black slab over the keys, and without cull none the thin plane vanishes from one side.
// Only rgbGen differs from retail, for the runtime-lit reason above.
enigmatext
{
	cull none
	qer_editorimage textures/models/submodels/enigmatext.tga
	{
		map textures/models/submodels/enigmatext.tga
		alphaFunc GE128
		depthwrite
		rgbGen lightingSpherical
	}
}
