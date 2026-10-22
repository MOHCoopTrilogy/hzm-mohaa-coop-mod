// ============================================================================================
// MOH Trilogy Coop - PROTOTYPE main-menu chrome.  SHARED FRAME, include this at the TOP of a
// prototype .urc, immediately after the container properties and BEFORE any content widget:
//
//     menu "coop_proto_x" 640 480 NONE 0
//     bgcolor 0 0 0 1
//     borderstyle NONE
//     bgfill 0 0 0 1
//     fullscreen 1
//     virtualres 1
//     include "ui/proto/coop_proto_chrome.inc"
//     ... your widgets ...
//     end.
//
// This file is INERT until something includes it.  Nothing under ui/proto/ is auto-loaded:
// the engine's startup sweep is FS_ListFiles("ui/", "urc", qfalse, ...) - non-recursive
// (client/cl_ui.cpp:5634, wantSubs=qfalse -> qcommon/files.cpp:2426 drops any entry whose
// depth != 1).  A prototype must be registered by hand:
//
//     loadmenu proto/coop_proto_x      (cl_ui.cpp:5535 -> UI_LoadMenu, opens ui/<arg>.urc)
//     pushmenu coop_proto_x            (NEVER showmenu - it skips the focus call that
//                                       turns the mouse on)
//
// Because a prototype is PUSHED, the BACK button below ("popmenu 0") returns to whatever was
// underneath - normally the real main menu.  No shipped menu is touched.
//
// WHY IT IS BUILT THIS WAY (all verified against openmohaa-hzm):
//   * Widgets do not nest.  Every resource is a direct child of the menu container
//     (uilib/uilayout.cpp:150).  This file is a flat list, like everything else.
//   * Draw order is DECLARATION order; hit-testing walks children LAST to FIRST
//     (uilib/uiwidget.cpp:1744).  Chrome declared first therefore draws behind prototype
//     content and can never steal a click from it.
//   * The default border style is border_indent, NOT none (uilib/uiwidget.cpp:747), so every
//     widget here carries an explicit borderstyle.  Note "RAISED", used all over the retail
//     menus, is not a recognised value (uiwidget.cpp:1349-1360) and silently leaves the
//     indent border in place.
//   * bgcolor only paints when its alpha != 0 (uiwidget.cpp:2055).
//   * `shader` art is always drawn STRETCHED to the widget rect (uiwidget.cpp:2104), so the
//     rects below match each texture's native aspect.
//   * Each field is on its OWN LINE.  A single-line resource block is silently dropped.
//
// TEXT AND ART ARE PARAMETERS, not edits.  Set these three cvars from whatever launches the
// prototype (a cfg, a bind, the console) - never from a `showcommand`, which builds a widget
// EVENT and not a console command (uiwidget.cpp:2412-2422, ExecuteShowCommands at :2189):
//
//     seta coop_protoTitle "OPERATIONS"                 title line, facfont-20
//     seta coop_protoSub   "select a mission"           strapline, verdana-12
//     seta coop_protoArt   "textures/mohmenu/coop_lo_bg.tga"   full-canvas backdrop, or "0"
//
// An unset cvar prints nothing and registers no material (uilib/uilabel.cpp:245-284), so the
// frame is correct with none of them set.  A prototype that wants a fixed title can simply
// declare its own Label over the plate AFTER the include instead.
//
// LAYOUT CONTRACT for the three prototypes - stay inside these bounds:
//     y   0 ..  70   title block (plate + title + strapline)   OWNED BY THE CHROME
//     y  72 .. 432   CONTENT.  x 8 .. 632.  All yours.
//     y 434 .. 480   footer (rule, credit line, BACK)          OWNED BY THE CHROME
// Canvas is 640x480 and nothing may cross it: a widget outside the declared canvas is
// clipped away by the container and draws nothing.
//
// The BACK button takes `ordernumber 1`; start prototype focus order at 2.
//
// ASSETS USED HERE ARE CONFIRMED TO EXIST - do not substitute an unverified name:
//   font facfont-20   fonts/facfont-20.RitualFont      (Pak0/Pak6, +@3x in the mod)
//   font verdana-12   fonts/verdana-12.ritualfont      (Pak0/Pak6, +@3x in the mod)
//   textures/mohmenu/weapon_sign   Pak1.pk3, TGA 256x32 24bpp   (8:1)
//   textures/mohmenu/back          Pak6EnUk.pk3, TGA 128x32 24bpp (4:1)
//   textures/mohmenu/back_h        Pak6EnUk.pk3, TGA 128x32 24bpp (4:1)
//   sound/menu/back.wav            Pak0.pk3
// A font name the engine cannot load is Com_Error(ERR_DROP) - the client drops at menu load
// (uilib/uifont.cpp:297-301).  Only facfont-20, verdana-12 and courier-16 are in use anywhere
// in this mod; treat that as the palette.
// ============================================================================================


// --- full-bleed ground -----------------------------------------------------------------
// `stretch both` is a WIDGET PROPERTY, not a resource type (uiwidget.cpp:345, :1409-1422).
// It zeroes pos and takes the full physical vidWidth/vidHeight, so it fills an ultrawide and
// paints the pillarbox bars that appear under `ui_menuCenter 1` (uiwidget.cpp:2577-2588).
// The rect is written for readability only - stretch overwrites it.
resource
Widget
{
	name "coop_proto_bleed"
	rect 0 0 640 480
	stretch both
	fgcolor 1.00 1.00 1.00 1.00
	bgcolor 0.055 0.055 0.050 1.00
	borderstyle "NONE"
}

// --- optional backdrop art, chosen by cvar ----------------------------------------------
// Same idiom as the retail main menu's ui_map_bg plate (ui/main.urc:133-144).  An empty or
// unresolvable name registers no material and simply draws nothing.
resource
Label
{
	name "coop_proto_art"
	rect 0 0 640 480
	fgcolor 1.00 1.00 1.00 1.00
	bgcolor 0.00 0.00 0.00 0.00
	borderstyle "NONE"
	linkcvar "coop_protoArt"
	linkcvartoshader
}

// --- scrim: seats the board inside the bleed and guarantees text contrast over any art ---
resource
Widget
{
	name "coop_proto_scrim"
	rect 0 0 640 480
	fgcolor 1.00 1.00 1.00 1.00
	bgcolor 0.02 0.02 0.02 0.42
	borderstyle "NONE"
}

// --- title block -------------------------------------------------------------------------
// weapon_sign is 256x32 (8:1); 480x60 is 8:1, so the plate is drawn undistorted.
resource
Label
{
	name "coop_proto_plate"
	rect 80 6 480 60
	fgcolor 1.00 1.00 1.00 1.00
	bgcolor 0.00 0.00 0.00 0.00
	borderstyle "NONE"
	shader "textures/mohmenu/weapon_sign"
}
resource
Label
{
	name "coop_proto_title"
	rect 90 16 460 24
	fgcolor 0.94 0.88 0.70 1.00
	bgcolor 0.00 0.00 0.00 0.00
	borderstyle "NONE"
	font "facfont-20"
	textalign centerx
	outlinedtext 1
	linkcvar "coop_protoTitle"
	dontlocalize
}
resource
Label
{
	name "coop_proto_sub"
	rect 90 42 460 15
	fgcolor 0.78 0.70 0.52 1.00
	bgcolor 0.00 0.00 0.00 0.00
	borderstyle "NONE"
	font "verdana-12"
	textalign centerx
	linkcvar "coop_protoSub"
	dontlocalize
}

// --- rules that bracket the content band -------------------------------------------------
resource
Widget
{
	name "coop_proto_rule_top"
	rect 40 70 560 2
	fgcolor 1.00 1.00 1.00 1.00
	bgcolor 0.72 0.62 0.38 0.75
	borderstyle "NONE"
}
resource
Widget
{
	name "coop_proto_rule_bot"
	rect 40 434 560 2
	fgcolor 1.00 1.00 1.00 1.00
	bgcolor 0.72 0.62 0.38 0.55
	borderstyle "NONE"
}

// --- footer ------------------------------------------------------------------------------
resource
Widget
{
	name "coop_proto_footer"
	rect 0 440 640 40
	fgcolor 1.00 1.00 1.00 1.00
	bgcolor 0.02 0.02 0.02 0.62
	borderstyle "NONE"
}
resource
Label
{
	name "coop_proto_credit"
	title "MOH Trilogy Coop - based on the HaZardModding (HZM) Coop Mod"
	rect 112 444 416 13
	fgcolor 1.00 1.00 1.00 0.34
	bgcolor 0.00 0.00 0.00 0.00
	borderstyle "NONE"
	font "verdana-12"
	textalign centerx
}
resource
Label
{
	name "coop_proto_note"
	title "PROTOTYPE LAYOUT STUDY - not the shipping menu"
	rect 112 459 416 13
	fgcolor 0.86 0.74 0.40 0.55
	bgcolor 0.00 0.00 0.00 0.00
	borderstyle "NONE"
	font "verdana-12"
	textalign centerx
}
// Same rect, art, sound and command as the retail BACK on ui/options_main.urc:109-121.
resource
Button
{
	name "coop_proto_back"
	rect 8 448 96 24
	fgcolor 1.00 1.00 1.00 1.00
	bgcolor 0.00 0.00 0.00 0.00
	borderstyle "NONE"
	shader "textures/mohmenu/back"
	hovershader "textures/mohmenu/back_h"
	clicksound "sound/menu/back.wav"
	stuffcommand "popmenu 0"
	ordernumber 1
}
