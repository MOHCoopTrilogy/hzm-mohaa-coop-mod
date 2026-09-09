// ===========================================================================
// MOH Trilogy Coop - overrides of RETAIL shaders whose authored settings produce
// a visible artifact on the geometry the retail maps actually ship.
//
// Precedence: gl2 returns the LAST occurrence in s_shaderText, which is the
// lowest FS index, which is the highest-priority pak (bug-2228 fixed this; before
// that fix gl2 silently discarded every override that shadowed a retail name).
// Only main/Pak0, mainta/pak1, mainta/pak4 and maintt/pak1 define the names below,
// and the coop pak outranks all four, so these win.
// ===========================================================================

// ---------------------------------------------------------------------------
// [user 2026-09-09, bug-2549] "seeing some textures through these wooden posts"
// - the m4l3 barn stalls, photographed in play.
//
// It is not a texture and it is not a hole. The barn's stall partitions are
// TWELVE PAIRS of exactly coincident faces: identical world vertices, identical
// texture st, opposite normals, each pair triangulated across the OPPOSITE
// diagonal. Retail authored this shader `cull none`, so BOTH members of every
// pair are drawn - and the compiler gave them different lightmap rects, with
// measured patch brightness differing by 1.7x to 5x between the two. Depth
// testing is GL_LEQUAL, so wherever the two triangulations' plane-equation
// rounding makes one depth marginally larger, the other wins that pixel: blocky
// rectangles, alternating dark and bright, and the pattern shifts as the view
// matrix changes. Nothing is see-through; you are seeing the same panel lit two
// different ways at once.
//
// Restoring back-face culling is the whole fix. The compiler already emitted
// both sides with correct outward normals precisely so each side carries its own
// lightmap, so from any viewpoint exactly one member survives - the correctly
// lit one. The fence still reads from both sides and the double-draw is gone.
//
// SAFETY GATE, run before shipping this and re-runnable
// (scratchpad/fence_pairing_scan.py): an UNPAIRED face would go invisible from
// one side. All 160 installed maps scanned, brush-model origins applied (207 of
// m4l3's 208 brush models carry a nonzero origin, so a world-space scan sees
// almost nothing). Eight maps use this shader - m4l3, e2l3(+_sml), dm/bot_foy_east,
// dm/bot_foy_west, dm/operation_fubar, obj/bobobjaa01, test_bob_foy - 298 faces,
// 149 pairs, ZERO singles and zero groups larger than two.
//
// Everything else is byte-for-byte the retail definition. Deliberately NOT
// extended to the map's other `cull none` shaders yet: interior/railing (28 maps)
// and misc_outside/fence1 (31 maps) scan fully paired too and would be safe, but
// they are unreported and touch far more of the trilogy. jh_fence1 is the pilot.
// ---------------------------------------------------------------------------
textures/general_structure/jh_fence1
{
	qer_keyword masked
	qer_keyword wood
	surfaceparm wood
	surfaceparm fence
	qer_editorimage textures/general_structure/jh_fence1.tga
	{
		map textures/general_structure/jh_fence1.tga
		alphaFunc GE128
		depthWrite
	nextbundle
		map $lightmap
	}
}
