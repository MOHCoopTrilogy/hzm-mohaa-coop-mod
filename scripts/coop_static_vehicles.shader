// [user 2026-08-11] STATIC VEHICLE SHADERS.
// A parked vehicle used as scenery still has moving treads and spinning wheels, because MOHAA
// animates them in the SHADER with tcMod, not on the entity. tcMod runs unconditionally in the
// renderer - no script command can stop it per-entity, which is why stopanimating did nothing.
// These are copies of the retail pzw42_* shaders with the tcMod line removed:
//   tread1 scroll -7.4 0 | tread2/treadedge scroll 0 1.7 | teeth scroll 0 2
//   tire1/tire2 rotate -120 | tire3 rotate -160 | tire4 rotate -100 | tire5 rotate -360
// FRESH NAMES on purpose (shader isolation): overriding the retail names would freeze the treads
// on every DRIVING panzerwerfer in the game too. Only the coop static TIK points here.

coop_pzw42_tire1_static
{
	nomerge
	qer_editorimage textures/models/vehicles/panzerwerfer42/pzw42_front_tire_s.tga
	{
		map textures/models/vehicles/panzerwerfer42/pzw42_front_tire_s.tga
		rgbGen lightingSpherical
	}
}

coop_pzw42_tread1_static
{
	nomerge
	qer_editorimage textures/models/vehicles/panzerwerfer42/pzw42_ftiretread_s.tga
	{
		map textures/models/vehicles/panzerwerfer42/pzw42_ftiretread_s.tga
		rgbGen lightingSpherical
	}
}

coop_pzw42_tread2_static
{
	nomerge
	qer_editorimage textures/models/vehicles/panzerwerfer42/pzw42_tread_s.tga
	{
		map textures/models/vehicles/panzerwerfer42/pzw42_tread_s.tga
		rgbGen lightingSpherical
	}
}

coop_pzw42_treadedge_static
{
	nomerge
	qer_editorimage textures/models/vehicles/panzerwerfer42/pzw42_tread_edge_s.tga
	{
		map textures/models/vehicles/panzerwerfer42/pzw42_tread_edge_s.tga
		rgbGen lightingSpherical
	}
}

coop_pzw42_teeth_static
{
	nomerge
	qer_editorimage textures/models/vehicles/panzerwerfer42/pzw42_teeth.tga
	{
		map textures/models/vehicles/panzerwerfer42/pzw42_teeth.tga
		rgbGen lightingSpherical
	}
}

coop_pzw42_tire2_static
{
	nomerge
	qer_editorimage textures/models/vehicles/panzerwerfer42/pzw42_back_tire2_s.tga
	{
		map textures/models/vehicles/panzerwerfer42/pzw42_back_tire2_s.tga
		rgbGen lightingSpherical
	}
}

coop_pzw42_tire3_static
{
	nomerge
	qer_editorimage textures/models/vehicles/panzerwerfer42/pzw42_back_tire1_s.tga
	{
		map textures/models/vehicles/panzerwerfer42/pzw42_back_tire1_s.tga
		rgbGen lightingSpherical
	}
}

coop_pzw42_tire4_static
{
	nomerge
	qer_editorimage textures/models/vehicles/panzerwerfer42/pzw42_back_tire3_s.tga
	{
		map textures/models/vehicles/panzerwerfer42/pzw42_back_tire3_s.tga
		rgbGen lightingSpherical
	}
}

coop_pzw42_tire5_static
{
	nomerge
	qer_editorimage textures/models/vehicles/panzerwerfer42/pzw42_back_tire4.tga
	{
		map textures/models/vehicles/panzerwerfer42/pzw42_back_tire4.tga
		rgbGen lightingSpherical
	}
}
