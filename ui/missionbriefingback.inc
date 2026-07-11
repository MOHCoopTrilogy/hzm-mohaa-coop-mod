
resource
Label
{
name "Default"
rect 384 0 256 512
fgcolor 0.50 0.50 0.50 1.00
bgcolor 0.50 0.50 0.50 0.00
borderstyle "NONE"
shader "briefingroomdark_b"
}
resource
Label
{
name "Default"
rect 0 0 512 512
fgcolor 0.50 0.50 0.50 1.00
bgcolor 0.50 0.50 0.50 0.00
borderstyle "NONE"
shader "briefingroomdark_a"
}
resource
Label
{
name "Default"
rect 384 0 256 256
fgcolor 1.00 1.00 1.00 1.00
bgcolor 0.50 0.50 0.50 0.00
borderstyle "NONE"
shader "textures/mohmenu/voodoo/briefingroomdark_c"
enabledcvar "ui_voodoo"
}
resource
Label
{
name "Default"
rect 384 256 256 256
fgcolor 1.00 1.00 1.00 1.00
bgcolor 0.50 0.50 0.50 0.00
borderstyle "NONE"
shader "textures/mohmenu/voodoo/briefingroomdark_f"
enabledcvar "ui_voodoo"
}
resource
Label
{
name "Default"
rect 0 0 256 256
fgcolor 1.00 1.00 1.00 1.00
bgcolor 0.50 0.50 0.50 0.00
borderstyle "NONE"
shader "textures/mohmenu/voodoo/briefingroomdark_a"
enabledcvar "ui_voodoo"
}
resource
Label
{
name "Default"
rect 256 0 256 256
fgcolor 1.00 1.00 1.00 1.00
bgcolor 0.50 0.50 0.50 0.00
borderstyle "NONE"
shader "textures/mohmenu/voodoo/briefingroomdark_b"
enabledcvar "ui_voodoo"
}
resource
Label
{
name "Default"
rect 0 256 256 256
fgcolor 1.00 1.00 1.00 1.00
bgcolor 0.50 0.50 0.50 0.00
borderstyle "NONE"
shader "textures/mohmenu/voodoo/briefingroomdark_d"
enabledcvar "ui_voodoo"
}
resource
Label
{
name "Default"
rect 256 256 256 256
fgcolor 1.00 1.00 1.00 1.00
bgcolor 0.50 0.50 0.50 0.00
borderstyle "NONE"
shader "textures/mohmenu/voodoo/briefingroomdark_e"
enabledcvar "ui_voodoo"
}

resource
Label
{
name "Default"
rect 184 432 272 40
fgcolor 1.00 1.00 1.00 1.00
bgcolor 0.75 0.75 0.75 0.00
borderstyle "NONE"
shader "clickfire"
}

// ===========================================================================================
// HZM coop READY-UP OVERLAY - appears on EVERY briefing slide (shared frame), drawn in the UI layer.
// All elements gated by enabledcvar "coop_gate_active" (0/unset in SP -> hidden). coop_mod/readygate.scr
// pushes live values via `set coop_gate_*` per client. Prompt/tally sit above the slide image (y<74);
// roster sits BELOW it (y>418) so the opaque slide never covers it. See bug (briefing ready overlay).
// ===========================================================================================
resource
Label
{
name "coopgate_prompt"
title "Press  F  ( [Use] )  to Ready Up"
rect 120 12 400 18
fgcolor 1.00 1.00 0.55 1.00
bgcolor 0 0 0 0
borderstyle "NONE"
font "verdana-12"
enabledcvar "coop_gate_active"
}
resource
Label
{
name "coopgate_tally"
rect 120 31 400 16
fgcolor 0.85 0.85 0.85 1.00
bgcolor 0 0 0 0
borderstyle "NONE"
font "verdana-12"
linkcvar "coop_gate_tally"
enabledcvar "coop_gate_active"
}
resource
Label
{
name "coopgate_r1"
rect 8 420 12 12
fgcolor 1 1 1 1
bgcolor 0 0 0 0
borderstyle "NONE"
linkcvar "coop_gate_p1r"
linkcvartoshader
enabledcvar "coop_gate_p1on"
}
resource
Label
{
name "coopgate_n1"
rect 23 421 140 14
fgcolor 1 1 1 1
bgcolor 0 0 0 0
borderstyle "NONE"
font "verdana-12"
textalign left
linkcvar "coop_gate_p1"
enabledcvar "coop_gate_p1on"
}
resource
Label
{
name "coopgate_c1"
rect 166 420 11 11
fgcolor 1 1 1 1
bgcolor 0 0 0 0
borderstyle "NONE"
shader "textures/hud/coop_ready_check"
enabledcvar "coop_gate_p1c"
}
resource
Label
{
name "coopgate_r2"
rect 8 434 12 12
fgcolor 1 1 1 1
bgcolor 0 0 0 0
borderstyle "NONE"
linkcvar "coop_gate_p2r"
linkcvartoshader
enabledcvar "coop_gate_p2on"
}
resource
Label
{
name "coopgate_n2"
rect 23 435 140 14
fgcolor 1 1 1 1
bgcolor 0 0 0 0
borderstyle "NONE"
font "verdana-12"
textalign left
linkcvar "coop_gate_p2"
enabledcvar "coop_gate_p2on"
}
resource
Label
{
name "coopgate_c2"
rect 166 434 11 11
fgcolor 1 1 1 1
bgcolor 0 0 0 0
borderstyle "NONE"
shader "textures/hud/coop_ready_check"
enabledcvar "coop_gate_p2c"
}
resource
Label
{
name "coopgate_r3"
rect 8 448 12 12
fgcolor 1 1 1 1
bgcolor 0 0 0 0
borderstyle "NONE"
linkcvar "coop_gate_p3r"
linkcvartoshader
enabledcvar "coop_gate_p3on"
}
resource
Label
{
name "coopgate_n3"
rect 23 449 140 14
fgcolor 1 1 1 1
bgcolor 0 0 0 0
borderstyle "NONE"
font "verdana-12"
textalign left
linkcvar "coop_gate_p3"
enabledcvar "coop_gate_p3on"
}
resource
Label
{
name "coopgate_c3"
rect 166 448 11 11
fgcolor 1 1 1 1
bgcolor 0 0 0 0
borderstyle "NONE"
shader "textures/hud/coop_ready_check"
enabledcvar "coop_gate_p3c"
}
resource
Label
{
name "coopgate_r4"
rect 8 462 12 12
fgcolor 1 1 1 1
bgcolor 0 0 0 0
borderstyle "NONE"
linkcvar "coop_gate_p4r"
linkcvartoshader
enabledcvar "coop_gate_p4on"
}
resource
Label
{
name "coopgate_n4"
rect 23 463 140 14
fgcolor 1 1 1 1
bgcolor 0 0 0 0
borderstyle "NONE"
font "verdana-12"
textalign left
linkcvar "coop_gate_p4"
enabledcvar "coop_gate_p4on"
}
resource
Label
{
name "coopgate_c4"
rect 166 462 11 11
fgcolor 1 1 1 1
bgcolor 0 0 0 0
borderstyle "NONE"
shader "textures/hud/coop_ready_check"
enabledcvar "coop_gate_p4c"
}
