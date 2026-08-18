// [user 2026-08-17] Lt. Pato's DP-28, imported as an ADDITION (his mod replaces the BAR).
// His shader names were 'dp28' and 'bipod' over textures/DarknStein/ - generic enough for
// another pak to win the name, which renders the gun untextured. Prefixed and re-pathed.
// Model: MOH Spearhead + Lt. Pato. Animations: Lt. Pato. Used with his permission.

coop_dp28_body
{
	qer_editorimage	textures/coop_dp28/dp28.jpg
	{
		map textures/coop_dp28/dp28.jpg
		rgbGen lightingSpherical
	}
}

coop_dp28_bipod
{
	qer_editorimage	textures/coop_dp28/bipod.jpg
	cull none
	{
		map textures/coop_dp28/bipod.jpg
		rgbGen lightingSpherical
	}
}
