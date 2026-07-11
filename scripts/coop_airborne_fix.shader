// HZM coop - AIRBORNE SKIN FIX.
// Four US airborne player skins (allied_Airborne_101st_1, _101st_2, _101st_sgt, _82nd_2) declare
//   surface us_helmet shader air_helm
// but no pak ever defines a shader named "air_helm" -> the helmet rendered as a solid BLACK shell on
// those skins. The intended texture DOES exist (textures/models/human/usmaps/airborne/air_helm.jpg,
// shipped in HRRTM_Pak3) - it just had no shader. Define it here so the helmet renders correctly.
air_helm
{
	qer_editorimage textures/models/human/usmaps/airborne/air_helm.jpg

	{
		map textures/models/human/usmaps/airborne/air_helm.jpg
		rgbGen lightingSpherical
	}
}

// NOTE: the chest MEDIC POUCH (dday_medipack-1) black-render fix is NOT here anymore. Overriding it by
// shader NAME lost the race (HRRTM's allied_bob_pack.shader loads later and, via ScanAndLoadShaderFiles'
// reverse concatenation, wins the duplicate name). The fix now lives in a whole-file override:
// scripts/allied_bob_pack.shader (coop pk3 mounts after HRRTM -> FS de-dupes to our copy). See bug-499.
