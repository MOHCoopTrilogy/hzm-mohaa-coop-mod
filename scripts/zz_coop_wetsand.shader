// MOH Trilogy Coop - wet-sand swash on Omaha's tidal strip [user 2026-09-05, water research item #1]
//
// WHAT THIS SURFACE IS. textures/mohtest/omaha_set4_shoreline is the strip of sand between the drawn
// waterline and dry sand: 6 planar quads, y -1024..-768, sloping 24 units over those 256 (z -504 at
// the sea edge, -480 at the land edge), on m3l1a, m3l1b and obj_team3 (every shipped BSP scanned). m3l1b
// carries the same T mapping, sheet and flap, so everything below holds there; obj_team3 (stock MP, not a
// coop map) has the same mapping with its sheet resting one unit lower at the land edge, so its wet
// edge lags the water by up to 0.17 T instead of 0.13 - acceptable, and stated.
// Retail draws it with ONE stage - the wet-to-dry sand texture clamped in T over a lightmap - so it
// has SEVEN free stages where the waterline shader (zz_coop_shoreline.shader) is at its cap of 8.
//
// THE T AXIS IS THE SHORE DISTANCE, measured from the BSP's own texcoords: T = 1.0 at y -1024 (the
// sea edge) and 0.0 at y -768 (the land edge). S is 256 world units per unit on EVERY quad and
// restarts at 0.25 on each (spans 8, 8, 20, 4, 4, 18 - all integers, which is why retail tiles
// seamlessly across the joins; keep S scales integer for the same reason). `clampmapy` clamps T
// only, which is exactly right for a gradient that must not repeat across the strip and a texture
// that tiles along it.
//
// THE WATER ALREADY WASHES OVER THIS STRIP - the sand never did anything about it. The waterline's
// flap (`deformVertexes flap t 10 sin 0 4 0 .08 0 4` in zz_coop_shoreline.shader) heaves the sheet
// by 4*sin*4*T: 13.0 units at this strip's sea edge and 15.9 at its land edge, on a 12.5 s cycle. At
// rest the sheet sits 17.5 units above the sand at the sea edge but only 1 unit above it at the land
// edge, so the water line is RECTIFIED: for the whole flood half of the cycle (sin >= 0) the sheet
// covers the entire strip, and only on the ebb does the landward part drain, down to the seaward 23%
// still covered at the trough. What was missing is the sand darkening under it and drying behind it,
// and foam where the sheet turns.
//
// PHASE LOCK, FOR FREE. Every shader-time generator (`deformVertexes` waves, `rgbGen wave`,
// `tcMod wavetrant`) runs off the one renderer clock, so a wave here with the same 0.08 Hz as the
// flap is locked to it forever. Water is highest at cycle phase 0.25 (sin peak, t = 3.125 s).
//
// THE WET LINE IS A CLAMPED GRADIENT MOVED BY THE SAME WAVE. tcMod wavetrant TRANSLATES T
// (renderergl1 tr_shade_calc.c RB_CalcTransWaveTexCoordsT does st[1] += wave; gl2's
// RB_CalcTransWaveTexMatrixT puts the same value in the translation column), so the texel drawn at
// world T is gradient[T + wave]. The gradient (textures/coop_fx/wetsand_swash.tga, 16x256, written
// raw so the row order is known - the engine's LoadTGA puts the file's FIRST row at t = 1, and the
// verifier re-read the bytes) is grey 0.66 for v >= 0.45, white for v <= 0.25, a ramp between. With
// `sin 0.45 0.75 0 0.08` the wave is v = T + 0.45 + 0.75 sin: at rest and on the whole flood
// v >= 0.45 at EVERY T, so the clamp saturates the strip grey - which is what the geometry does (the
// land edge is under 1 unit of water at rest); at the trough v = T - 0.30, full grey only for
// T >= 0.75 (the water then covers T >= 0.77) with the ramp's visible mid-edge at T 0.65, i.e. a
// tenth of the strip of drying sand behind the receding water. Tabulated against the real water
// line at every eighth of the cycle the visible edge stays within 0.13 T (32 units) of it; the
// first draft's 0.5/0.7 overshot by 0.22 T on the ebb. The draft before that was
// a symmetric +/-0.35 sinusoid with a phase lag; the adversarial pass showed it drew a third of the
// strip dry under a visible sheet for most of the cycle, because the real water line saturates and
// a sine does not. The multiply darkens the sand by up to a third under the band, not at all outside.
// gl2 does not apply overbright to a DST_COLOR blend (ComputeShaderColors isBlend), so `rgbGen
// identity` is a clean white there too.
//
// WHY THE FOAM'S REACH IS BAKED INTO ITS ALPHA AND NOT `alphaGen tCoord`. On gl2 - the shipping
// renderer - a shader with NO deform goes through CollapseStagesToGLSL, and every colour stage is
// folded into the LIGHTALL program, which has no alphaGen sCoord/tCoord at all (the generic program
// has them; only deformed shaders reach it, which is why the waterline's ramps work). A stage with
// `alphaGen tCoord` here draws at alpha 1 across the whole strip on gl2, dry seam included - the
// adversarial pass caught it before it shipped. Texture alpha IS honoured by lightall
// (alpha = diffuse.a * var_Color.a), so textures/coop_fx/wetsand_foam.tga carries retail's wash2
// foam with the T ramp written into its alpha. MEASURED, NOT ASSUMED: wash2 is not a full-frame foam
// sheet, it is one horizontal band at t 0.20..0.44 of the image (mean luminance peaks 64 at 0.35,
// zero everywhere else) - the first bake put the alpha window over the black rows and the stage drew
// nothing, and only a per-row dump of RGB*alpha caught it. The band is resampled to t 0.60..0.90 of
// the texture; alpha is 0 for T <= 0.50, full from 0.60 to 0.88, and back to 0 by 0.95 so the clamped
// sea-edge row is black AND transparent and cannot smear when the wave shifts it. Both files are
// checked by the same per-row RGB*alpha dump before they ship. The ramp rides the wavetrant (it is
// texture now), which is right: foam moves up with the wash.
// The seaward guarantee is therefore geometric, not a wave clamp: every row above t 0.90 is black and
// every row above t 0.95 also has alpha 0 (black times any alpha adds nothing under GL_SRC_ALPHA
// GL_ONE), so nothing draws on the always-exposed sea-edge rows whatever the glow does.
// TWO RENDERER DIFFERENCES, STATED: gl2 also multiplies this foam by the lightmap and lights it
// (lightall attaches the split lightmap pass to any non-filter blend), so it dims in bunker shadow
// where gl1 draws it flat additive; and `rgbGen wave` is scaled by identityLight on both, so the
// wave numbers below are relative knobs, not framebuffer values.
//
// STAGE BUDGET: 4 of 8 used. NO deform on this shader, on purpose - any deform would drop it out of
// gl2's whole lighting path (tr_shader.c CollapseStagesToLightall), and it is lightmapped. Do not
// add `alphaGen sCoord/tCoord` to any stage of a deform-free shader on gl2; bake it into the texture.
//
// PRECEDENCE. This override wins because the coop code pak outranks main/mainta/maintt in the search
// path, not because of the file name: both renderers resolve a duplicated shader name to the
// highest-priority pak, and WITHIN one pak to the alphabetically FIRST shader file (gl2
// FindShaderInShaderText keeps the last hit of a text concatenated in reverse listing order; gl1 keeps
// the head of its chain - same answer). The `zz_` rationale copied around the sibling overrides is
// therefore inverted for a same-pak duplicate. Rule that follows: define a shader name in exactly ONE
// coop file, and never a second time in another. The body below restates the WINNING retail block
// (maintt pak1's, `surfaceparm dirt`, which gl2 ignores and gl1 maps to a flag nothing reads for a
// world surface - footsteps use the BSP-baked SURF_SAND) verbatim and only adds stages.
//
// KNOBS, all in this file: the wet line's shape is stage 2's wavetrant (base 0.45 = where the edge
// sits at rest, amplitude 0.75 = how far it drains); its darkness is the grey in the gradient texture;
// the foam's brightness is stage 4's rgbGen wave amplitude; its reach is the alpha ramp baked into
// wetsand_foam.tga. The blood's coverage, colour and reach window are all in docs/tools/gen_swashblood.py
// (TARGET_COVERAGE, RED_*, REACH_*) - stage 3 only places the texture and moves it with the wet line.
// Nothing here runs a script or costs an entity.

textures/mohtest/omaha_set4_shoreline
{
	qer_keyword sand
	qer_keyword terrain
	surfaceparm dirt
	{
		clampmapy textures/mohtest/omaha_set4_shoreline.tga
	nextbundle
		map $lightmap
	}

	// [coop 2026-09-05] STAGE 2 - THE WET LINE. A multiply by the clamped gradient, translated in T
	// by the flap's own 0.08 Hz, in phase with it: saturated (all wet) through the flood, draining
	// to the seaward third at the trough, a tenth of the strip behind the receding water.
	{
		nopicmip
		clampmapy textures/coop_fx/wetsand_swash.tga
		blendFunc filter
		rgbGen identity
		tcMod wavetrant sin -0.10 0.40 0 0.08		//[bug-2514] land edge: swing 0.659-1.000 -> 0.910-1.000
	}

	// [user 2026-09-06, bug-2508] STAGE 3 - BLOOD IN THE SWASH. The waterline sheet no longer draws its blood
	// over the strip (ocean pass item 1: the sheet's blood tiles T twice, so its edge could never be ragged);
	// the slicks live here instead, clamped in T with the REACH BAKED INTO THE TEXTURE'S ALPHA - no
	// alphaGen tCoord, this shader is deform-free and gl2's lightall drops it (bug-2486). The bake
	// (docs/tools/gen_swashblood.py): gen_bloodwash's seamless integer-frequency slicks, alpha 0 landward of
	// the wet line's rest position (t 0.30..0.45 ramp), full to t 0.80, 0 by t 0.88, every row t >= 0.96
	// black AND transparent so both clamp rows draw nothing; its ragged edge is o(s) from gen_wetsand.py at
	// 1.0x, so it is the wet line's own rag. Translated by stage 2's EXACT wave: at rest the slicks sit on
	// the landward T 0..0.45 behind the wet line, at the trough they ride out to T 0.65..1.0 with the
	// draining water, and through the flood they slide landward under the sheet - blood carried by the
	// swash. `tcMod scale 1 1` = one 256 u tile, seamless at every quad join (integer S spans). Drawn
	// BEFORE the foam so the foam floats over the slicks; lightall multiplies it by the lightmap like
	// the sand. Kill switch: delete this block.
	{
		nopicmip
		clampmapy textures/coop_fx/swashblood.tga
		blendFunc blend
		rgbGen identity
		tcMod scale 1 1
		tcMod wavetrant sin -0.10 0.40 0 0.08		//[bug-2514] land edge: swing 0.659-1.000 -> 0.910-1.000
	}

	// [coop 2026-09-05] STAGE 4 - FOAM WHERE THE SHEET TURNS. Retail's wash2 with the reach baked into
	// its alpha (see the header for why not alphaGen), additive and alpha-scaled, pulsed by a 0.08 Hz
	// wave that peaks WITH the water (phase 0) so the foam is brightest as the sheet comes in and
	// gone at the trough; it rides landward with the wet line (small wavetrant, same phase) and drifts
	// slowly along the beach (0.02 S/s = 5 units/s). `tcMod scale 1 1` is one 256x256-unit tile, square
	// against the strip and seamless at every quad join because the S spans are integers (a non-integer
	// scale puts a tile-phase seam at four of the five joins). Clamped in T (the alpha ramp must not
	// repeat); its sea-edge row is black and transparent by construction so the clamp cannot smear.
	{
		nopicmip
		clampmapy textures/coop_fx/wetsand_foam.tga
		blendFunc GL_SRC_ALPHA GL_ONE
		rgbGen wave sin 0.12 0.20 0 0.08
		tcMod scale 1 1
		//[user 2026-09-07, bug-2519] LONGSHORE DRIFT. 0.02 -> 0.0672 S/s = 17.2 u/s, and the sign is
		//EAST: the flood tide at Omaha on 6 June ran east at up to 2.7 kt offshore and about 0.44 m/s
		//inside the surf, and it is the named cause of the landing craft coming ashore off their
		//sectors. So the foam slides steadily to the right as you face the sea, about a body-length
		//and a half per wave, while the wet line and the stains printed on the sand stay put - which
		//is why only THIS stage takes an S scroll and stages 2 and 3 keep zero.
		//RISK: one 256 u tile passes every 14.9 s, so this is the one place a conveyor read is
		//possible. Check it while MOVING along the beach, not standing still. Fallback 0.034.
		tcMod scroll 0.0672 0
		tcMod wavetrant sin 0.213 0.40 0 0.08		//[bug-2514] foam rides the wet line, 30 u seaward, unclamped
	}
}
