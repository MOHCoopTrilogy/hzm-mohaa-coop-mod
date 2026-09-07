// HZM coop [user 2026-09-06, bug-2508] HIGGINS BOW WAKE - the surface shader of models/fx/coop_wake.tik.
//
// This is retail `wake` (main/Pak0.pk3 scripts/wake.shader, drawn on models/fx/wake/wake.skd) copied under
// a coop-only name WITHOUT its third stage, `map $lightmap` x `blendFunc GL_DST_COLOR GL_ZERO`: a lightmap
// multiply has no meaning on an entity mesh. The wave deform and both scrolling oceandday layers are
// retail's, untouched. Name defined here and nowhere else - checked 2026-09-06 against every scripts/*.shader
// in main/mainta/maintt paks and hzm-mohaa-coop-mod/scripts (TRAPS T6: one name, one coop file).
//
// Path: any shader with a deform goes down gl2's generic program (tr_shader.c:3216-3225), where
// deformvertexes wave is GPU and tcMod scroll / nextbundle are supported; gl1 draws it as retail did.
// Textures resolve extension-agnostically: oceandday / oceandday1 are the coop tex pak's .jpg upscales.
// Kill switch for this file is the file itself; the script beat is level.coop_wakeOn.
coop_wake
{
	qer_editorimage textures/misc_outside/wake.tga
	surfaceparm nonsolid
	surfaceparm trans
	surfaceparm water
	cull none
	nopicmip
	deformvertexes wave 30 sin 0 10 0 .2
	{
		map textures/misc_outside/oceandday.tga
		rgbGen identity
		tcMod scroll .2 .7
	}
	{
		map textures/misc_outside/oceandday1.tga
		blendfunc add
		tcMod scroll 0 .9
	nextbundle
		map textures/misc_outside/oceandday1.tga
		tcMod scroll 0 .5
	}
}
