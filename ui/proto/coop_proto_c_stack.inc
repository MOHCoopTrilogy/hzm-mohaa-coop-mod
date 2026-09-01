// ============================================================================================
// MOH Trilogy Coop - PROTOTYPE "MINIMAL" THEME LAYER.  Shared by every coop_proto_c_* page.
// THIS IS A PROTOTYPE.  It ships no shader, touches no shipped menu, and is inert until a
// prototype .urc includes it.  Nothing under ui/proto/ is auto-loaded.
//
// HOW TO OPEN (console, ~).  Load both pages, then push the first:
//     loadmenu proto/coop_proto_c_main
//     loadmenu proto/coop_proto_c_play
//     pushmenu coop_proto_c_main
// pushmenu, never showmenu - UI_ShowMenu_f skips the focus call that turns the mouse on
// (client/cl_ui.cpp:5523 pushmenu vs :5528 showmenu).  BACK is popmenu 0, so the real main
// menu is still underneath, untouched.
//
// WHAT THIS FILE IS FOR
// ---------------------
// The include chain is chrome -> theme -> page:
//     include "ui/proto/coop_proto_chrome.inc"     the frame every prototype shares
//     include "ui/proto/coop_proto_c_stack.inc"    THIS FILE - the Minimal look
//     ...four Button blocks...                     the page
// Includes are processed INLINE and NEST: UILayout::ProcessCommands pushes the current script,
// recurses through Load(), and pops (uilib/uilayout.cpp:117-121), so a file may include any
// number of times and an .inc may itself include.  (That is only true of `include`.
// `postinclude` is stored in ONE str at uilayout.cpp:106 and overwritten at :123, so a file
// with two postincludes silently keeps the last.  Do not use postinclude here.)
//
// Because draw order is DECLARATION order and hit-testing walks children LAST to FIRST
// (uilib/uiwidget.cpp:2124-2127 and :1744), everything below is declared after the chrome and
// before the page: it paints over the chrome, and the page's buttons still win every click.
//
// WHY IT PAINTS OVER THE CHROME'S TITLE BLOCK
// -------------------------------------------
// "Minimal" means no ornament, and the chrome's title block is ornament: a brass weapon_sign
// plate at rect 80 6 480 60, plus the top rule at y 70.  coop_proto_chrome.inc:51-52 sanctions
// exactly this override ("declare its own Label over the plate AFTER the include - later
// declaration draws on top").  coop_proto_c_quiet below is that Label, sized 0 0 640 72 to
// cover the plate, the cvar title, the strapline and the top rule in one pass.
//
// Its colour is the composite the rest of the screen already shows, not the raw ground colour,
// or the top of the screen would read as a lighter band.  The chrome paints an opaque bleed of
// (0.055, 0.055, 0.050) and then a scrim of (0.02, 0.02, 0.02) at alpha 0.42 over it, so the
// visible colour is 0.42*scrim + 0.58*bleed = (0.0403, 0.0403, 0.0374).  Hence 0.040/0.040/0.037.
// bgcolor is a straight R G B A (uiwidget.cpp:1339-1342); it is `bgfill` that swaps green and
// blue (uiwidget.cpp:2685-2688), and nothing here uses bgfill.
//
// The chrome's FOOTER is kept as-is: rule, credit line, prototype notice and BACK.  That is the
// half of the chrome a Minimal page should inherit rather than override.
//
// LAYOUT THIS THEME FIXES (a page fills the slots, it does not re-derive them)
//     y   0 ..  72   quieted.  dead air.
//     y 100 .. 113   wordmark strip                        OWNED HERE
//     y 130 .. 154   page title, facfont-20                 PAGE SUPPLIES
//     y 166 .. 167   hairline tick, 40px, centred           OWNED HERE
//     y 200 .. 336   four rows, x 160 w 320 h 28, pitch 36  PAGE SUPPLIES
//     y 384 .. 397   hover/echo hint line                   PAGE SUPPLIES
//     y 397 .. 432   dead air.
// All of it sits inside the chrome's content contract (y 72..432 for content, x 8..632) except
// the deliberate 0..72 override above.  A widget outside the declared 640x480 canvas is clipped
// by the container and draws nothing.
//
// ASSETS: none.  No shader, no texture, no sound.  Two flat fills and one text line, so there
// is nothing here that can fail to resolve.  Fonts are verdana-12 only - one of the three faces
// (facfont-20, verdana-12, courier-16) proven in this mod's own menus.  A font name the engine
// cannot load is Com_Error(ERR_DROP) at uilib/uifont.cpp:295-299: the client drops at menu load.
// ============================================================================================


// --- quiet the chrome's title block ------------------------------------------------------
// Covers rows 0..71, which is the plate (y 6..66), the cvar title, the strapline and the top
// rule (y 70..72).  A plain Widget: it is not activatable, and nothing under it needs a click.
resource
Widget
{
	name "coop_proto_c_quiet"
	rect 0 0 640 72
	fgcolor 1.00 1.00 1.00 1.00
	bgcolor 0.040 0.040 0.037 1.00
	borderstyle "NONE"
}

// --- wordmark strip ------------------------------------------------------------------------
// The one constant across pages.  45 chars of verdana-12 is about 252px (avg 5.6 px/char) in a
// 640px rect, so it cannot collide with the edges - which matters, because there is no text
// wrapping anywhere in this UI (uilib/uifont.cpp:388-428): only a literal \n breaks a line.
// `textalign` takes ONE value: UIWidget::TextAlignment loops over the args but re-reads arg 1
// every pass (uiwidget.cpp:1511-1514), so `textalign centerx centery` would silently apply
// centerx twice.  Vertical centring is free - the default is FONT_JUSTVERT_CENTER
// (uiwidget.cpp:771-772).
resource
Label
{
	name "coop_proto_c_mark"
	title "ALLIED ASSAULT  -  SPEARHEAD  -  BREAKTHROUGH"
	rect 0 100 640 13
	fgcolor 0.72 0.66 0.52 0.40
	bgcolor 0.00 0.00 0.00 0.00
	borderstyle "NONE"
	font "verdana-12"
	textalign centerx
	dontlocalize
}

// --- the only mark on the page -------------------------------------------------------------
// A 40px hairline under the title.  Gives the centred stack an axis without adding a box, a
// border or a piece of art.  Explicit borderstyle because the DEFAULT is border_indent, not
// none (uiwidget.cpp:747) - and "RAISED", used 40 times across this mod's shipped menus, is
// not a recognised value (uiwidget.cpp:1349-1360) and silently leaves the indent border drawn.
resource
Widget
{
	name "coop_proto_c_axis"
	rect 300 166 40 1
	fgcolor 1.00 1.00 1.00 1.00
	bgcolor 0.72 0.62 0.38 0.55
	borderstyle "NONE"
}
