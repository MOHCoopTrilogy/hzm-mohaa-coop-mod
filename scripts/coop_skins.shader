// [user 2026-08-17] Weapon skin variants. Generated procedurally by docs/tools (see
// _skins/): the base texture is split into a low-frequency shading term and a high-frequency
// detail term, and only the HUE is replaced - which is why the receiver, screws and grain
// survive instead of being flooded over. One block per variant, all prefixed coop_skin_ so a
// third-party pak cannot win the name and leave the gun untextured.

coop_skin_thompson_gold
{
	qer_editorimage textures/coop_skins/thompson_gold.jpg
	{
		map textures/coop_skins/thompson_gold.jpg
		rgbGen lightingSpherical
	}
}
