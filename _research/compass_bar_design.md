> **USER DECISIONS (2026-09-13):**
> - Markers vanish with the bar when the HUD fades (marker floor 0). The bar follows the HUD fade, superseding the July
>   compass fade exemption for the bar.
> - The bar replaces the round hud_compass ring while it is on. On by default.
> - The DM box (kill feed/chat) shifts down under the bar.
> - Hidden when scoped and when spectating.
> - Current objective only (v1). Distance in metres.
> - Not asked yet, taken at the recommendation: coop-only in v1 via a coop session flag (MP byte-identical).
> - Still open (decisions page): teammate names near centre, v2 priority, arc/label density, locations for the 4
>   no-location stages. Fix before building: markers overlapped labels in the mockup; give markers their own row.

# Top compass bar: research map and recommended design (HZM MOHAA Coop)

Evidence conventions:
- Repo paths are relative to `C:\mohaa-coop-dev`. Engine code is under `openmohaa-hzm/code/` and mod content is under `hzm-mohaa-coop-mod/`.
- `[NV]` marks a load-bearing fact that one research pass got from reading code and nobody re-checked. The design would change if it were wrong.
- `[C]` marks a fact a critic pass confirmed.
- Where a critic refuted or partly corrected a claim, this document uses the correction.

---

## 1. Executive summary

**Feasibility: yes, and it needs no protocol change and no game.dll change.** Every v1 input is already on the client:
- heading
- current-objective bearing (plus a rough distance)
- the location of every listed objective
- teammates, in-snapshot and through the radar channel

Three binaries or content sets change:
- **cgame.dll**: draws the bar.
- **openmohaa.exe**: moves the kill-feed/chat box down and hides the round compass ring while the bar is on.
- **pk3**: menu controls, defaults and marker art.

build.ps1 already deploys openmohaa.exe next to cgame.dll (build.ps1:277-291, `[C]`). An integration-pass claim that it does not was refuted.

**Recommended design in five lines:**
1. A `CG_DrawCompassBar` in `cgame/cg_drawtools.cpp`, called in CG_Draw2D after the ADS vignette and before CG_HudDrawElements. It is centred, sized from vidHeight, occupies a 0-0.040H band (43 px at 1080p), and shows a fixed 150-degree arc: 5-degree ticks, a label every 15 degrees, 8 cardinal letters and a centre heading readout.
2. The bar follows the HUD fade the way the stamina arc does. Ticks and text use `s_hudFadeAlpha` squared. It has its own gates for cg_hud, letterbox, the cinematic hold, script cameras (not turrets), spectators, scopes (not turrets) and intermission/no-HUD.
3. Markers:
   - Current objective: from STAT_OBJECTIVECENTER turned into a world bearing, hidden on the no-location sentinel.
   - Distance: decoded from the LEFT/RIGHT spread, or taken exactly from CS_OBJECTIVES `loc` when the two agree.
   - Teammates: same-team only, from snapshot entities plus a raw copy of radar packets.
4. cgame publishes `coop_compassBarLive` (flags 0, its value is the band height in px). The exe reads it to hide hud_compass and to shift the DM box down by that height. At 0, the layout is byte-identical to today, so an old cgame or bar-off changes nothing.
5. Player prefs are CVAR_ARCHIVE cvars registered in cgame and seeded only in coop_defaults.cfg. The controls live in the redesigned COOP - FIELD SETTINGS menu. v1 is coop-only by default: it is gated on a coop-published session flag, so MP clients see nothing new (user decision 8a-3).

**Three biggest risks:**
1. **The top strip is already taken, and the taker draws over cgame.** The DM box (kill feed/chat) sits at y=0 across 15-90% of the width, and every exe UI box and URC HUD menu draws over cgame 2D `[NV]`. Clearing it takes an exe change. That change creates new neighbours that need moves: the DBNO "is down" banner, the m5l3 King Tiger label, and the e1l1/e1l2 items strip.
2. **Marker data is subtly wrong in several places.**
   - The objective stat is view-relative, has a no-location sentinel, and cannot be told apart from an objective very close dead ahead.
   - Configstring `loc` goes stale on the 8 coop maps (plus 2 MP OBJ maps) that call `set_objective_pos`.
   - The client radar drops teammates whose last-seen state was not solid, for example one who respawned far away.
   - Downed state is not sent to other clients at all.
   - A first-person vehicle gunner's view yaw may not match the stat's yaw.
3. **Gate and fade regressions.**
   - cgame 2D draws over the letterbox and no cgame element checks it.
   - Turret seats read STAT_INZOOM=80 and set PMF_CAMERA_VIEW, so copied gates would hide the bar in every vehicle.
   - Thin bright strokes linger after the rest of the HUD fades (bug-2559).
   - Fading the bar goes against the recorded choice that the compass never fades (docs/FEATURES.md:506).

---

## 2. Visual spec

### 2.1 Geometry (virtual units are not used; everything is in real pixels from vidWidth/vidHeight)

Script huddraw uses a 640x480 space and stretches x and y separately (5.375x by 3.0x at 3440x1440; cgame/cg_drawtools.cpp:42-55, 661-687 `[NV]`). It also has no free fade-exempt slots (_research/hud_slot_map.md:87-89). So the bar is drawn in cgame in real pixels, sized as fractions of H, the same approach as the brace pip and hit marker (cg_drawtools.cpp:2716-2835). `cgs.uiHiResScale` is not used because it stays 1 at or below 1920x1080 (client/cl_ui.cpp:4035-4046 `[NV]`).

Let H = vidHeight, W = vidWidth, s = coop_compassBarScale (clamped to 0.75..1.0; see 2.6).

| Element | Formula (s=1) | 1080p value |
|---|---|---|
| Band (reserved, published to exe) | `bandPx = round(0.040*H*s)` | 43 px |
| Top margin | `round(0.006*H*s)` | 6 px |
| Bar body | y = margin .. bandPx-5 | 6..38 |
| Label row | top of body, text height `0.0167*H*s` (18 px, the XAG 101 minimum for PC text at 1080p) | 8..26 |
| Cardinal letters N/E/S/W | `0.020*H*s` | 22 px |
| Tick row | grows up from the body bottom | 28..38 |
| Bar width | `bw = round(min(0.42*W, 0.75*H) * s)`, centred at `W*0.5` | 768 px |
| Pixels per degree | `ppd = bw / 150` | 5.12 |

How it scales (s=1):

| Resolution | Aspect | bw | band | ppd | 5-deg spacing | 15-deg label spacing |
|---|---|---|---|---|---|---|
| 1024x768 | 4:3 | 430 | 31 | 2.87 | 14 px | 43 px (switch to 30-deg labels, see 2.3) |
| 1600x1200 | 4:3 | 672 | 48 | 4.48 | 22 px | 67 px |
| 1280x720 | 16:9 | 538 | 29 | 3.59 | 18 px | 54 px |
| 1920x1080 | 16:9 | 768 | 43 | 5.12 | 26 px | 77 px |
| 2560x1440 | 16:9 | 1075 | 58 | 7.17 | 36 px | 108 px |
| 3440x1440 | 21:9 | 1080 (capped by 0.75H) | 58 | 7.20 | 36 px | 108 px |
| 3840x2160 | 16:9 | 1613 | 86 | 10.75 | 54 px | 161 px |

**Width cap.** 0.75H keeps ultrawide from getting a 3000 px strip. It also keeps the half-width under `W/2 - 256*scaleRes - margin`, which clears hud_timelimit/hud_score at top-right. Those menus show in coop too, because cgame adds them for every gametype other than 0 (cgame/cg_servercmds.c:199-212 `[NV]`). Worst case is 1024x768: half-width 215 px against a limit of 240.

**Title-safe.** The usual guidance is about 90% safe area (https://michaelnoland.com/safe-zones/). A 6 px margin sits on the edge of that, which is acceptable on PC. The margin is a constant, so it is easy to change.

### 2.2 Bearing math (resolved across passes)

- Engine yaw runs counter-clockwise. `GetBattleLanguageDirection` maps +45 degrees from north to "North West" (fgame/player.cpp:13051-13058 `[C]`).
- `camYaw = cg.refdefViewAngles[YAW]`. This is the final rendered camera and the same source as the stock ring via CG_EyeAngles (client/cl_uistd.cpp:1282-1284, cgame/cg_view.c:6549-6554 `[NV]`). It is correct in third person, free-cam, script cameras, spectator follow and every vehicle seat (section 4.4).
- `north = AngleNormalize360(stats[STAT_COMPASSNORTH] / 182.0f)`. The stat is sent as a short, so values above 180 arrive negative and must go through anglemod (fgame/player.cpp:9269, qcommon/msg.cpp:3629 `[C]`).
- Heading number: `heading = AngleNormalize360(north - camYaw)`, increasing clockwise.
- Tick for compass bearing h: `x = cx + AngleSubtract(h, heading) * ppd`.
- World yaw B (a marker): `x = cx - AngleSubtract(B, camYaw) * ppd`. This is the same as converting B to a bearing with `north - B`.
- Do **not** reuse the stock ring's spring/overshoot smoothing (cl_uistd.cpp:1286-1405). A numeric readout would lag and overshoot.
- View kick and scope sway are in refdefViewAngles, so ticks move with recoil. Accept this in v1 because it matches the rendered world. Revisit only if a playtest finds it jittery.
- Unsettled: whether in-game N lines up with the map screen and the hud_compass_in.tga art on a map with non-zero northyaw (8c).

### 2.3 Ticks, labels, cardinals

- **Arc: fixed 150 degrees**, independent of `cg.refdef.fov_x` so the bar does not rescale on ADS (cg_view.c:5507-5509). The Unity reference defaults to 150 (https://github.com/CommanderFoo/Unity-Horizontal-Compass). Insurgency's 180-degree concept is the alternative (https://www.gamedeveloper.com/design/sense-of-direction-insurgency-compass-design-process).
- **Minor tick every 5 deg:** `w = max(1, round(0.0019*H))`, `h = round(0.0065*H)`.
- **Major tick every 15 deg:** `h = round(0.010*H)`.
- **Cardinal/intercardinal tick every 45 deg:** `h = round(0.012*H)`.
- **Labels every 15 deg:** numbers 15, 30, 60, 75, ...; letters at 0/90/180/270 (N E S W) and 45/135/225/315 (NE SE SW NW).
  - Keep the intercardinals. Hell Let Loose removed them and shrank the font, and players revolted (https://steamcommunity.com/app/686810/discussions/0/1642043732656805328/).
  - BF6 uses 10-degree numbers (https://www.shacknews.com/article/145511/turn-on-compass-battlefield-6). 15 fits the band better.
- **Density rule:** if `15*ppd < 3.2*textHeight`, label every 30 degrees and keep the letters. This applies at 1024x768.
- **Centre readout:** a boxed 3-digit heading on a dark `*white` plate about 3.2 text-heights wide, drawn in the label row. Any tick label whose centre falls inside the plate is skipped. A 2 px vertical accent line in the tick row marks the exact centre. MW2019 highlights the exact facing degree (https://blog.activision.com/content/atvi/activision/atvi-touchui/web/en/blog/call-of-duty/2019-10/Getting-Started-in-Modern-Warfare-Controls-and-Settings-PC.html).

### 2.4 Fonts, art, draw primitives

- **Primitives cgame actually has:** R_SetColor, R_DrawStretchPic (explicit UVs, batched per shader), R_DrawString (flushes on every call), R_DrawBox (flushes on every call), R_LoadFont, UI_FontStringWidth. There is **no scissor, no rotation and no triangle draw** (cgame/cg_public.h:304-332 `[NV]`).
- Draw ticks as `R_DrawStretchPic` on `R_RegisterShaderNoMip("*white")` with x snapped to whole pixels. That gives one batched surface. R_DrawBox flushes on each call, so avoid it (renderergl1/tr_draw.c:381-398 `[NV]`).
- **Fonts:** numbers use `verdana-14` and cardinals use `facfont-20`. Both are already loaded by cgame (cg_main.c:659-661), and the renderer picks up the `@3x` sheets automatically (renderergl1/tr_font.cpp:149-181). Draw with a uniform scale vector `{k,k}`, `k = targetPx / fontHeight`, pass x/k and y/k, and centre with `UI_FontStringWidth*k`.
  - @3x sheets have no mipmaps (tr_shader.c:3625-3649). At 720p text is about 12 px, so prefer verdana there and check for shimmer (8b).
- **Text shadow:** a 1 px black offset pass. Keep the total at 30 or fewer R_DrawString calls per frame.
- **Background band:** a new art file `textures/hud/compassbar_bg.tga` (black, horizontal alpha ramp at both ends), one stretched quad, shader in `scripts/hud_airborne_coop.shader`. Fallback without art: 6 stepped `*white` quads.
- **Marker art (new, 64 px, clampmap, blend):**
  - `compassbar_obj` (filled star/diamond)
  - `compassbar_obj_hollow`
  - `compassbar_mate` (chevron)
  - `compassbar_mate_hollow` (direction-only)
  - `compassbar_edge` (edge caret)
  - `compassbar_down` (cross, v2)

  Existing art that could stand in: textures/hud/radar_allies.tga and radar_axis.tga (cgame/cg_radar.cpp:30-31); coop_ally_icon.spr and coop_officer_icon.spr (cg_modelanim.c:295-301).
- **Cost:** about 40-60 batched quads plus up to 30 text calls per frame. That is less than the hit marker's up to 100 R_DrawBox calls.

### 2.5 Colours and opacity (proposal; no repo palette fact was gathered, so tune against the Airborne HUD art)

| Item | RGB | Alpha |
|---|---|---|
| Background band | 0,0,0 | 0.35 x opacity x fA2 |
| Ticks, numbers, NE/SE/SW/NW | 0.93, 0.90, 0.80 (khaki off-white) | opacity x fA2 x edge(x) |
| N letter + centre accent | 0.90, 0.30, 0.18 | same |
| Heading plate | 0,0,0 | 0.55 x opacity x fA2 |
| Current objective | 1.00, 0.82, 0.25 (gold), filled star | marker alpha (4.3) |
| Other active objective | same gold, hollow, 75% size | 0.7 x marker alpha |
| Teammate | 0.50, 0.85, 0.50, chevron | marker alpha; x0.6 when from radar |
| Downed teammate (v2) | 0.95, 0.25, 0.20, cross | marker alpha, pulses |

`fA2 = s_hudFadeAlpha * s_hudFadeAlpha`. `opacity = coop_compassBarOpacity`.

Markers are told apart by shape (star, chevron, cross), not only by colour. XAG 102 asks for 4.5:1 contrast against the worst background and for not relying on colour alone (https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/102).

### 2.6 Edge handling, markers, distance text

- **Edge fade:** there is no scissor. Multiply alpha by a smoothstep over the outer 12% of each half-width. Skip a label whose centre is outside the window. Commercial bars do the same (https://www.lovattostudio.com/en/shop/gui/ucompass-bar/).
- **Clamping:**
  - Current objective and (v2) downed teammates clamp to `+/-(bw/2 - 0.012H)` and switch to the edge caret at 0.8 alpha.
  - Teammates and non-current objectives are hidden when outside the arc.
  - Icons crossing a bar end are cropped through s1/s2 UVs, as the stamina arc does (cg_drawtools.cpp:1767-1851).
- **Marker size and placement:** current objective `0.020H`; teammate `0.014H`. Vertically centred on the tick row (y = body bottom - 0.010H), drawn over the ticks.
- **Distance text:** only for the current objective. It is drawn in the label row beside the marker, at label text size, and numbers under its rectangle are skipped. Format `~140 m` when decoded from the stat, `140 m` when exact (5.1). Metres assume 1 unit = 1 inch, the convention bug-2177 states `[NV]`; the user decides units (8a).
- **Teammate name:** shown only when the marker is within +/-4 degrees of centre and no objective label is there.
- **Overlap priority** (drawn last means on top): background < ticks < labels < other objectives < teammates < downed teammates < current objective < centre plate. Within a tier, the marker closest to centre draws last; PUBG draws the newest on top (https://pubg.com/en/news/7810).
- **Size slider range 0.75-1.0.** Above 1.0 the band would pass 0.044H and hit the XP gain popup (virtual y21) and the ready-gate prompt (virtual y20). That cap is a layout constraint, not a style choice.

---

## 3. Never interfering

### 3.1 Z-order (settled by code reading)

- All cgame 2D is drawn inside `View3D::Draw -> Draw2D` (client/cl_uiview3d.cpp:491-503, 697-708 `[NV]`).
- View3D is created first in the always-on-bottom group. ArrangeWidgetList keeps order within a group (uilib/uiwidget.cpp:1198-1250). View3D::OnActivate brings every other always-on-bottom widget back in front (cl_uiview3d.cpp:92-111).
- **Result: gmbox, dmbox and every URC HUD menu (including hud_compass) draw over the bar** `[NV]`.
- The letterbox is painted before CG_Draw2D, so the bar would draw over the letterbox (cl_uiview3d.cpp:491-503 `[C]`).
- Full-screen script dims are huddraw, so drawing the bar before CG_HudDrawElements puts those dims over it (cg_drawtools.cpp:2837-2872).
- To confirm: one screenshot (8b).

### 3.2 Inventory and rule per occupant (1920x1080 unless noted; virtual = 640x480 units)

| Occupant | Position / timing | Rule | Evidence |
|---|---|---|---|
| **DM box (kill feed, death messages, DM chat)** | x 288-1728, y 0-120, up to 6 lines, 5 s per line (6 s death, 8 s bold). 3440x1440: x 384-2176, y 0-160. 720p: y 0-120 | **Move X:** exe offsets `getDefaultDMBoxRectangle` pos.y by `coop_compassBarLive` (band px). `ui_compass_scale` cannot do this: y is hard-coded 0, and the cvar only moves the DM box x and the gmbox y | cl_ui.cpp:1229-1237 `[NV]`; cl_uidmbox.cpp:155-168, 293; gap report 2 |
| **gmbox (iprintln/iprintlnbold)** + engine objectives list | x 20, y = max(0.25*H*scale, dmbox bottom): 202 at 1080p, 135 at 720p, 270 at 1440p | **Follows automatically** via max(). No change at 1080p and up. At 720p it moves 135 -> 149 | cl_ui.cpp:1211-1222, 1244-1247; cg_drawtools.cpp:780-817 |
| **hud_compass ring** (incl. radar, damage flash, objective arrow, frame) | top-left 160x160 px (213 at 1440p, 320 at 2160p). Not resized by ui_compass_scale (virtualres 0) | **Hidden while bar live** (section 6.3) | ui/hud_compass.urc:5-82; uiwidget.cpp:1424-1429, 2555-2563 |
| hud_timelimit / hud_score | right-top, x 1664-1920, y 0-41, all gametypes != 0 | **Fixed free band:** width cap keeps half-width under W/2 - 256*scaleRes - margin | cg_servercmds.c:199-212; maintt pak1.pk3 ui/hud_timelimit.urc `[NV]` |
| XP gain popup (slots 62-69) | centre, virtual y21-45 (53 with halo) = 47-101 px, about 2.5 s per award, fades | **Fixed free band:** band bottom 0.040H = 43 px < 47 px (720p: 29 < 32) | coop_mod/xp.scr:1287-1341 |
| Ready-gate prompt (slots 115/116) | centre, virtual y20/38 = 45 px, briefing map, drawhud 1 forced | **Fixed free band**, 2 px gap at 1080p, 1 px at 720p; screenshot | coop_mod/readygate.scr:173-189 |
| M3L3 church bar | centre, virtual y24-50, objective 6 | Fixed free band | maps/M3L3.scr:6595-6623 |
| **m5l3 King Tiger label** | centre-top virtual y10 (22 px), facfont-20, whole tank fight | **Move X:** set its y below the XP popup (about virtual y56; screenshot-verify). No generic yield, because a yield would hide the compass for the whole fight | maps/m5l3.scr:1001-1002, 1052-1053 |
| **Vanilla SP items strip** (e1l1, e1l2) | right-top virtual y8-72, x about 212-626, only when items exist | **Move X:** +20 virtual y in global/items.scr; check whether coop reaches it first (8b) | global/items.scr:508-523 |
| **DBNO "<name> is down" banner** (slot 216) | centre, virtual y58 = 130 px, 6 s. Once the DM box moves to 43-163 px it overlaps DM box text. It already overlaps today at 720p (87 px < 120) | **Move X:** about virtual y142, below the challenge toast (y100-138). Clearing the shifted DM box needs virtual y >= 99 at 720p, >= 73 at 1080p and up | coop_mod/dbno.scr:241, 247-253; gap report 2 |
| "[DOWN] name" labels (slots 30/31/36/37) | top-left x10, y30+14n | No conflict (left side, bar centred) | dbno.scr:1432-1504 |
| Objectives title plate (slots 156/157/175) | virtual y20-44 top-left, fade-exempt | **Not live by default:** coop_objPanel is forced 0 in autoexec. If re-enabled, y20 = 45 px still clears | objectives.scr:549, 578-590, 683-701; autoexec.cfg:1174-1178 `[NV]` |
| Service Record rows (156+r) | virtual y122 and down | No conflict | challenges.scr:2655-2713, 2793 |
| Lobby help / "LAUNCHING IN" | virtual y12/26/46, y70 | Lobby runs `drawhud 0`, so the bar is gated off | lobby.scr:417, 634-640, 759-769, 978 |
| Challenge toast; objective toast; challenge progress | y100-138 centre; left y150+; left y195-223 | No conflict | challenges.scr:2539-2584, 1996-2032; objectives.scr:133-167 |
| Scoreboard | side panel from virtual y32 (72 px) | No conflict; bar stays visible (fade is woken) | cg_scoreboard.cpp:44-50; cg_drawtools.cpp:2254 |
| Cinematic letterbox top bar | 0 .. H*STAT_LETTERBOX/MAX | **Yield: hide** (gate) | cl_uiview3d.cpp:659-676 |
| Scope / binocular full-screen overlay | full screen, STAT_INZOOM | **Yield: hide** when scoped (gate 4.2) | cg_drawtools.cpp:551-597 |
| ADS vignette, gl2 low-health/suppression washes | full screen | Bar is drawn after them (on top). This is intended | cg_drawtools.cpp:2098-2135, 2468-2533 |
| Full-screen script dims (SR panel slot 150, e3l4 curtain 95, m6l3d, weather) | from y0 | **Layer under:** bar drawn before CG_HudDrawElements | challenges.scr:2742-2753; e3l4_arena.scr:162-172 |
| Centerprint, subtitles, FPS, chat input, crosshair and cgame chrome | middle / lower / aim point | No conflict | cl_uiview3d.cpp:525-800; cl_ui.cpp:979-1022; cg_drawtools.cpp listing |
| Dev-only: ADS tune readout 30,40; net profile overlay | top-left | Ignore (dev) | cg_drawtools.cpp:2040; cl_uiview3d.cpp:475-489 |

**Future scripts.** No generic runtime yield. Instead, a `coop_dev`-gated warning print when any visible top-aligned huddraw element has a scaled Y inside the band (cgame can read the huddraw elements). New collisions get fixed at the source.

---

## 4. HUD fade integration

### 4.1 The mechanism being joined `[C]`

- **The value.** `s_hudFadeAlpha` and `s_hudTouchTime` are file-statics in cg_drawtools.cpp:32-33. `CG_UpdateHudFade` is the first call in CG_Draw2D (:2837-2839). The target is 1 while `cg.time - touch < coop_hudFadeTime` (5 s, minimum 1 s) and 0 otherwise. Fade-in takes 200 ms, fade-out 750 ms. The value is published to `ui_hudAlpha` only when it changes (:2229-2375).
- **Wakes:**
  - fire or ADS buttons
  - scoreboard held
  - coop_hudPoke change
  - health, weapon, ammo or owned-weapons delta
  - health at or below 25%, or dead
  - cover, or DBNO (coop_dbnoView)
  - stopwatch running
  - stamina change while not on a turret
  - coop_objOpen
  - CS_OBJECTIVES flags/text change (cg_main.c:516-524)
  - suppression (cg_view.c:1604)
- **Not wakes:** CS_CURRENT_OBJECTIVE change (cg_main.c:511-513), turning, movement, opening a non-fullscreen menu.
- **The exemption.** Today the compass is exempt by user choice (FEATURES.md:504-507; cl_ui.cpp:1834-1837, 2440; cg_drawtools.cpp:690, 2194; archive history-2026-06-26-to-07-10.md:53). No verbatim user quote survives, so whether it meant "the ring" or "any compass" is unknown (8a-1).
- **Scope of this change.** The request explicitly asks the bar to follow the fade. The ring keeps its exemption for as long as it exists.

### 4.2 Exact recipe

1. **Where.** Add `static void CG_DrawCompassBar(void)` in `cgame/cg_drawtools.cpp`, in the same translation unit as `s_hudFadeAlpha` and `CG_CoopCineHudActive`. No accessor is needed. Call it from CG_Draw2D after `CG_DrawAdsVignette`/lagometer and **before** `CG_HudDrawElements` (:2837-2872).
2. **One gate helper, evaluated once per frame:** `static qboolean CG_CompassBarVisible(void)`. Hide when any of these holds:
   - `!cg.snap`
   - pref `coop_compassBar` off, or (if coop-only is chosen) the coop session flag unset
   - `!cg_hud->integer` (cg_main.c:196; cl_ui.cpp:4869-4873)
   - `ps.pm_flags & (PMF_NO_HUD | PMF_INTERMISSION)`: lobby `drawhud 0`, intermission (cg_drawtools.cpp:1786-1796)
   - `ps.stats[STAT_LETTERBOX] > 0`. No cgame element checks this today, and the UI hides the HUD under letterbox (cl_ui.cpp:2043) `[C]`
   - `CG_CoopCineHudActive()`. Evaluate it unconditionally every frame, first in the helper, never short-circuited behind another test (cg_drawtools.cpp:1424-1461)
   - script camera: `(pm_flags & PMF_CAMERA_VIEW) && !(pm_flags & PMF_TURRET) && !(pm_flags & PMF_SPECTATING)`. Script cameras never set PMF_TURRET (cg_view.c:6412-6415, 6487-6489 `[NV]`)
   - spectator: `pm_flags & PMF_SPECTATING`. While following, snap->ps is the other player's state (cg_drawtools.cpp:2572-2575; player.cpp:8169-8216)
   - not alive: `!(ps.stats[STAT_HEALTH] > 0 || (pm_flags & PMF_TURRET))`. STAT_HEALTH carries the **vehicle's** health while riding (player.cpp:9031-9054 `[NV]`)
   - scoped: `STAT_INZOOM > 0 && STAT_INZOOM <= 30 && !(pm_flags & PMF_TURRET)`. Every VehicleTurretGun user, **tank drivers included**, sits at INZOOM=80 (vehicleturret.cpp:1003-1008; VehicleTank.cpp:79-87 `[NV]`). Scoped weapons use 15-30 (models/weapons/*.tik; player.cpp:9264-9267)

   Handled upstream, no code needed: fullscreen menus and loading (View3D is hidden, cl_ui.cpp:1993-2011 `[C]`) and `cls.no_menus`.
3. **Alpha.**
   - `fA2 = s_hudFadeAlpha * s_hudFadeAlpha`
   - `tickAlpha = coop_compassBarOpacity * fA2`
   - `markerAlpha = coop_compassBarOpacity * max(markerFloor, s_hudFadeAlpha*s_hudFadeAlpha)`
   - `markerFloor` is a constant, 0 by default, until the user decides 8a-1
   - If `tickAlpha <= 0.02 && markerAlpha <= 0.02`, return before any draw call, like the team logo and MAGS early-outs (:936, :2180). Nothing lingers and a faded bar costs nothing.
4. **Wakes: edges only.**
   - Add `CG_HudFadeTouch()` when CS_CURRENT_OBJECTIVE's value changes (cg_main.c:511-513), with a `CG_HudFadeDebug` reason.
   - Never wake on objective bearing or distance, teammate positions, "marker on screen", or the raw stats (player.cpp:9271-9313 changes every turn).
   - v2 downed-teammate events wake through script `coop_hudPoke`, as medkit.scr:167-168 does.
5. **Settings preview.** coop_settings.urc is `fullscreen 0` and opening it does not wake the HUD (coop_settings.urc:6, 11 `[C]`). The compass checkbox's stuffcommand should also set `coop_hudPoke` to a changing value so the player sees the change.

### 4.3 Per-state behaviour

| State | Bar | Why |
|---|---|---|
| Normal play, calm | fades out after 5 s | request |
| Firing / ADS (not scoped) / hurt / cover | full | existing wakes |
| Downed (DBNO) | visible, pinned awake | coop_dbnoView wake (cg_drawtools.cpp:2303-2309); health stays > 0 via `healthonly 100` (dbno.scr:142, 169, 197 `[NV]`) |
| Dead waiting to respawn | hidden | alive gate |
| Scoped rifle / binoculars | hidden (default; 8a-5) | gate; scope art sits under later draws |
| Turret, tank driver, vehicle gunner, glued rider | visible | PMF_TURRET exceptions; do not copy the damage indicator's PMF_CAMERA_VIEW / PMF_TURRET / PMF_NO_MOVE gate (cg_drawtools.cpp:2614-2616) |
| Script cutscene camera, coop_cineHud hold, letterbox | hidden | gates |
| Lobby / drawhud 0 / intermission | hidden | gate |
| Fullscreen menu / loading | hidden | upstream |
| Non-fullscreen settings folder | draws behind the folder, usually faded | poke on toggle |
| Scoreboard held | visible (woken), no overlap (panel at 72 px) | cg_drawtools.cpp:2254 |
| Spectator / follow | hidden (v1; 8a-5) | gate |
| Build mode | always full (it sets coop_hudFade 0) | buildmode.scr:110-111 |

### 4.4 Avoiding the stamina-arc stuck-visible bug (bug-2559)

The arc already read `s_hudFadeAlpha`. The complaint was perceptual: a thin bright stroke stays readable at alphas where dark panels have already vanished. It was fixed with alpha squared, and the sprint wake changed from "stat not full" to "stat changed" (cg_drawtools.cpp:1821-1836, 2331-2338 `[C]`). That fix was deployed today and has not been playtested.

Squared alpha has one precedent: MAGS, the team logo and huddraw use linear alpha (`[C]` partly). Treat it as the default and confirm it in a playtest. The bar copies all four lessons:
1. Use the same clock and never keep a private timer or ui_hudAlpha, which is published on change and can be one frame late.
2. Square the alpha for ticks and text.
3. Hard early-out at 0.02.
4. Wakes on edges only.

Also do not follow the stamina arc's missing gates: it has no cg_hud check and no letterbox check (cg_drawtools.cpp:1786-1796 `[C]`). Whether the arc already shows during letterboxed cutscenes is an open playtest (8b); if it does, it is a latent defect.

---

## 5. Markers

### 5.1 Objectives

**Data on the client, no new networking:**
- **STAT_OBJECTIVELEFT / RIGHT / CENTER** (stats 17/18/19): computed server-side every frame. `yaw = AngleSubtract(v_angle[1], (objective - centroid).toYaw()) + 180`, tenths of a degree, clamped 1..3599. `LEFT/RIGHT = centre +/- max(7, 60 - atan(300/dist))` (player.cpp:9271-9313 `[C]`).
  - It follows `set_objective_pos` and TOW/Liberation per-team locations (player.cpp:8985-8994 `[C]`).
  - **World bearing:** `objYaw = cg.snap->ps.viewangles[YAW] - (CENTER*0.1 - 180)`. This uses the same snapshot, so it neither swims against the predicted yaw nor depends on seat. It rests on UpdateStats running before SetupView copies v_angle into ps.viewangles in the same EndFrame (player.cpp:9432-9441, 8155 `[NV]`).
  - Place the marker against `camYaw` (2.2). This also cancels a possible first-person vehicle-gunner mismatch: camera yaw is m_vUserViewAng[1] but v_angle adds m_vBaseAngles[1] (vehicleturret.cpp:958 vs 1373 `[NV]`; 8b).
- **Sentinel:** an exact (1730, 1870, 1800) means no location.
  - A real location produces it only inside a cone under 0.1 degrees wide dead ahead within about 227 units (player.cpp:9271-9292 `[C]`).
  - Hide the marker on an exact match. This is strictly better than today's ring, which points its arrow forward on those stages (hud_compass.urc:56-68).
  - Correction: one pass said a *distant* objective ahead also gives the triple. That is wrong: the spread clamps to 7 when *near*.
  - Also hide when CS_CURRENT_OBJECTIVE is -1, which is `current_objectives 0` (scriptthread.cpp:4606-4626).
- **Distance, approximate:**
  - `d = (RIGHT - LEFT + 3600) % 3600`, `fOffset = d*0.05`
  - if `fOffset <= 7.05`, show no number ("here")
  - otherwise `len = 300 / tan(DEG2RAD(60 - fOffset))`
  - An offline replay of the server arithmetic gave 400->400, 1000->1003, 5000->4976, 10000->9819 (scratchpad/compass/objdist.py `[NV]`, not checked in game). Resolution gets coarser with distance, so show it with `~`.
- **CS_OBJECTIVES+i** (i < 20): info strings with `flags`, `text` and `loc`, reliable and sent to every client (scriptthread.cpp:4501-4507 `[C]`).
  - cgame parses only flags/text today (cg_main.c:516-527; cg_local.h:174-177). Adding `vec3_t loc; qboolean hasLoc` is a cgame-only change.
  - **`loc` is stale** wherever `set_objective_pos` / `clear_objective_pos` are used, because they write only level.m_vObjectiveLocation (scriptthread.cpp:4629-4646 `[C]`). That is **26 live calls in 8 coop maps**, including t1l3 (10), m1l2a, m2l1, m4l3, m5l1a/b, m5l3. Earlier counts of 38/11 included commented lines. The claim that the "mod never calls it" is false.
  - `current_objectives` also re-copies `loc` over an earlier `set_objective_pos` point, but the stat always shows whatever the server currently uses.
- **Exact distance rule:** use `|loc - player origin|` only when `hasLoc`, gametype < GT_TOW, the index equals CS_CURRENT_OBJECTIVE, and the bearing of `loc` is within 2 degrees of the stat bearing. Otherwise use the decoded `~` distance.

**Coverage in coop (static scan, comments stripped; scratchpad/compass/coopobj*.py, coopobjloc_rows.json):**
- Every current objective has a location on all 30 m-series maps, all 11 e-series maps (e1l3/e2l3/e3l2 through ObjMgr SetObjCompassTarg), t1l1, t2l1, t2l3, t2l4, t3l1, and t1l3 (objectives 1/2/5 through set_objective_pos).
- **No location, so the marker is hidden:**
  - t1l2 obj 2 (t1l2.scr:657-658)
  - t2l2 obj 1, the whole map (t2l2.scr:67-68)
  - t3l2 obj 3 (t3l2.scr:1016, 1064-1067)
  - training obj 1 (training.scr:175)
- Optional per-map fix using the e1l2 per-frame re-add recipe (e1l2.scr:255-268): not required for the bar (8a-10).
- Caveats:
  - Index joins for variable-held indices (e1l1, e1l2, e1l4, e2l1, e2l2, e3l1, e3l4, t2l3, m6l1a) were not done.
  - A NULL entity passed as location throws "Cannot cast NULL to vector" and kills that addobjective (script/scriptvariable.cpp:1237-1250); counting these needs a maptest run.
  - m6l1a.scr:104 calls `current_objectives` with no index.
- **Coop side objectives coop_so1/so2** are cvar-only and have no position (coop_mod/objectives.scr:1-25 `[C]`). **Not shown in v1.**

**Per MP mode (relevant only if MP is enabled, 8a-3):**

| Mode (gametype) | Current marker | Other objectives | Notes |
|---|---|---|---|
| FFA (1) | none (sentinel) | none | heading only |
| Team / Round (2/3) | only if map adds objectives | CS_OBJECTIVES loc | |
| Objective (4) | stat | loc from func_objective origin (Entities.cpp:2102-2105, 2199-2217) | mp_castello_obj, mp_palermo_obj use set_objective_pos (retail pk3 scan, scratchpad/compass/pkscan2.py), so current must come from the stat |
| TOW (5) | stat (per team) | **skip**: CS_CURRENT_OBJECTIVE is shared, last call wins (Tow_Entities.cpp:118-124, 325-337) | TOW scripts make no objective calls |
| Liberation (6) | stat (per team) | **skip**: scripts set current per team (1 allies / 2 axis), so the configstring is wrong for allies | pkscan2.py |

For gametype >= GT_TOW, draw the current marker only.

### 5.2 Other players

**Sources:**
- **In snapshot, exact:** `cg_entities[n]` origin and eFlags (EF_ALLIES 0x80, EF_AXIS 0x100, EF_DEAD 0x200, talking). Name and team come from CS_PLAYERS via `cg.clientinfo[n]`, which is available for every client (bg_public.h:425-428; cg_main.c:591-608).
- **Snapshot limits** (sv_snapshot.c:769-821, 579-615 `[NV]`):
  - area/PVS test, then a distance cull of about 12,128 units ahead
  - FOV weighting (`fov/80*len*(2*dot+1)`): at fov 80 a moving player behind you drops out beyond about 3,032 units and one beside you beyond about 6,064
  - stationary players get x0.25
  - `sv_netoptimize 0`
- **Out of snapshot:** `ps.radarInfo`, a 26-bit field (clientNum 6, X/Y 7 each, yaw 5, valid 1), **one teammate per snapshot**, chosen by oldest lastRadarTime.
  - In-snapshot teammates are refreshed every snapshot and never picked.
  - Teammates beyond `com_radar_range` are **not skipped**: they are sent at most about once a second and **clamped to the rim**, so direction is kept and distance is lost. This corrects a refuted survey claim; the clamp comes from HZM bug-2177 (sv_snapshot.c:876-958, 1000-1063, 1162-1180 `[NV]`).
  - No Z.
  - Coop sets `com_radar_range 6144` (server.scr:35-49), about 97.5 units per step. The engine default is 1024, about 16 units per step (common.c:1930, CVAR_ARCHIVE|SYSTEMINFO).
- **Filtering:** team games only (gametype >= GT_TEAM), same team, both solid with team flags, server-side on fresh state. Enemies and AI actors are never in this channel (sv_snapshot.c:966-1036 `[NV]`).

**Client-side hole, which needs a cgame fix.** `CG_ValidRadarClient` requires `currentState.solid` on the local player's and the teammate's **last-seen** cg_entities entries. `CG_ReadNonPVSClient` drops packets that fail, even when fresh (cg_radar.cpp:41-75, 119-152 `[NV]`). cg_entities is zeroed at init (cg_main.c:712) and only updated while in snapshot (cg_snapshot.c:142). So a teammate is silently missing when they:
- were never seen,
- died in view and respawned far away (a very common coop case; Killed sets SOLID_NOT, player.cpp:3596), or
- were last seen during a coop notsolid window: playerMakeSolidAsap on spawn/respawn/revive/teleport, glue, radiusFreeze (main.scr:864, 885, 1641-1643; replace.scr:2395, 2491; player.scr:770-787, 1137, 1456-1458).

**Fix without touching the stock radar:** in `CG_ReadNonPVSClient`, copy every decoded packet into a new `cg.compassMates[MAX_CLIENTS]` (origin XY, yaw, serverTime, clamped flag) **before** the validity check. The bar accepts an entry when:
- `cg.clientinfo[n].team == local team`
- `CG_IsTeamGame`
- the packet is under 5000 ms old
- the client is not the local player

The server already filtered team and solid on fresh state, so this leaks nothing. The stock UIRadar path stays upstream-unmodified. `CG_UpdateRadar`'s purge only runs from UIRadar::Draw, which is hidden with the ring, so the bar does its own age test (cl_uiradar.cpp:74, 121).

**Presentation:**

| Case | Style |
|---|---|
| In snapshot, alive | filled chevron, full marker alpha; no distance by default |
| In snapshot, EF_DEAD | not drawn |
| Radar, inside range | filled chevron, alpha x0.6, fades by packet age after 1.5 s |
| Radar, clamped to rim (delta at rim radius) | hollow chevron (direction only), never a distance |
| Talking (EF_PLAYER_TALKING / radar lastSpeakTime) | blink at cl_radar_blink_time (cl_main.cpp:4257-4259) |
| Outside the 150-degree arc | hidden |
| Downed (v2) | red cross, clamps to edge, priority above teammates |

The radar round-robin means that with N out-of-snapshot teammates each one refreshes every N snapshots (or no more than once a second when beyond range). Out-of-range markers step; fading by age hides most of that.

**Downed teammates: needs new data (v2).**
- DBNO does **not** remove a player from the radar. EventCoopSetDbno only sets a bool and dismounts (player.cpp:13493-13501). dbno.scr makes only the medkit and glow notsolid (dbno.scr:1437, 1447) `[NV]`.
- Downed state never reaches other clients: coop_dbnoView is self-only (dbno.scr:443, 470), and radarInfo has no spare bit.
- Cheapest carrier: coop-only `stufftext "set coop_dbnoMask <bits>"` sent to all players on each change from dbno.scr's existing coop_setdbno sites, plus a re-push every 2 s, because the stufftext channel is lossy (docs/TRAPS.md:424-439, T8). The coop_* prefix already passes the cgame filter (cg_servercmds_filter.cpp:165-175).
- Alternative: a game.dll-written configstring (reliable, but adds a game.dll change).
- Never SVF_BROADCAST player entities: it goes to all clients, enemies included (entity.cpp:4176-4179; sv_snapshot.c:736-741).

**Priority (top to bottom):** current objective > downed teammate > teammate near centre > teammate > other active objectives.

### 5.3 What needs new networking (summary)

| Want | Carrier | Binary |
|---|---|---|
| Heading, current objective bearing and approximate distance, listed objective locations, teammates | existing | cgame only |
| Downed teammates | coop-only stufftext bitmask + refresh (or configstring) | cgame + script (or + game.dll) |
| Side objectives coop_so1/so2 | coop-only position cvar from officer/radio scripts | cgame + script |
| Exact distance on set_objective_pos maps | position push, or accept `~` | cgame + script |
| Precise/Z far teammates, several per snapshot | new configstring or playerState field; playerState is a protocol change (exe+game+cgame on every client); MAX_STATS=32 is full, STAT_MGHEAT already dual-use (bg_public.h:547-593) | avoid |

---

## 6. Player options

### 6.1 Cvars

All registered in cgame with `Cvar_Get(..., CVAR_ARCHIVE)` and seeded with `seta` in `hzm-mohaa-coop-mod/coop_defaults.cfg` only. That file runs before the saved config, so menu changes survive. **Never in autoexec.cfg**, which runs last and clobbers menu choices (docs/TRAPS.md:354-366 T7, 392-397). Autoexec already forces coop_hudFade/coop_hudFadeTime (autoexec.cfg:211-216).

| Cvar | Values | Default (proposal) | Menu control |
|---|---|---|---|
| `coop_compassBar` | 0 classic ring, 1 top bar | 1 (8a-3) | checkbox "Modern Compass" |
| `coop_compassBarScale` | 0.75-1.0 | 1.0 | slider (precedent: Crosshair Size, autoexec.cfg:203-205) |
| `coop_compassBarOpacity` | 0.3-1.0 | 0.9 | slider |
| `coop_compassBarObj` | 0 off, 1 current, 2 all active | 1 | cycle/checkbox |
| `coop_compassBarMates` | 0/1 | 1 | checkbox |
| `coop_compassBarLive` | band px, 0 = off | internal, flags 0, never archived, never on a menu | none |
| coop session flag (only if coop-only) e.g. `coop_isCoopSession` | 0/1 | cgame registers flags 0, resets to 0 in CG_Init/CG_Shutdown; coop script sets it | none |

Rules:
- Every menu control must be read by code: "a setting is a promise", checked with docs/tools/audit_menu_cvars.py.
- Scripts must never `getcvar` these prefs. On a listen host the client and server share one cvar table, and getcvar creates the cvar empty (T7, bug-1669).
- Any server can stufftext a coop_* cvar (cg_servercmds_filter.cpp:166-175). Accept this; it is the existing coop trust model.
- If any MP file could write a pref, add it to FORBIDDEN in docs/tools/check_mp_isolation.py.
- Arc (150) and label interval are compile-time constants in v1, not settings.

### 6.2 Where they live

COOP - FIELD SETTINGS has no free row. It has 11 CheckBox rows on a 30 px grid from y=148; the last, cbHitMarker, is at y=448 and CLOSE at y=454 (ui/coop_settings.urc:84-96, 320-369 `[NV]`). The controls therefore depend on the concurrent coop_settings.urc redesign, for example a "HUD" tab beside the folder tab (a comment there reserves tabs). Checkboxes use `linkcvar`: live, archived, no Apply button. Each compass control's stuffcommand also pokes coop_hudPoke (4.2 step 5).

### 6.3 Stock compass behaviour and how the bar replaces it

- **Stock hud_compass:**
  - an exe-drawn URC menu: ring (stat 16), teammate Radar, damage flash (stat 29), objective arrow (stat 19), frame
  - top-left 160x160, fade-exempt
  - shown iff `ui_compass` (default 1, flags 0, not archived; cl_ui.cpp:5466, 2432-2438) once the HUD hide test passes
  - the hide test covers ui_hud, not connected, letterbox, fullscreen menu, loading, PMF_NO_HUD, PMF_INTERMISSION (cl_ui.cpp:2043-2069 `[C]`)
  - `ui_compass_scale` (0.75, ARCHIVE|LATCH) does **not** size the ring (virtualres 0; uiwidget.cpp:1424-1429, 2555-2563 `[NV]`); it only positions the DM box x and gmbox y
- **Mechanisms rejected:**
  - `ui_removehud hud_compass`: a no-op, because it only acts on hudList members (cl_ui.cpp:5151-5158). lobby.scr:979 is dead; the lobby hides the ring through `drawhud 0`.
  - `ui_addhud hud_compass`: force-shows it every frame (cl_ui.cpp:1269-1274, 2455).
  - `enabledcvar` on each resource: each widget then skips its own visibility check, so the ring would ignore letterbox, menus, loading and ui_compass (uiwidget.cpp:2027-2033 `[C]`).
- **Chosen: route A (exe).** At cl_ui.cpp:2433, show the ring iff `ui_compass->integer && !coop_compassBarLive`, and add the same test on the no_menus path at :1922.
  - It keeps every hide rule because it sits inside the hide test's else branch (cl_ui.cpp:2070-2456 `[C]`).
  - The exe already changes for the DM box shift, so this adds nothing to ship.
  - Old cgame + new exe: the cvar is never set, so the stock layout stays.
  - New cgame + old exe: both compasses show and the DM box overlaps the bar. build.ps1 and publish_release.ps1:76-77 ship both, so only a partial manual update hits this.
- **Fallbacks:**
  - route C: cgame writes `ui_compass 0` on change and restores in CG_Shutdown (cg_main.c:913-932). Shares a cvar with the console and fgame/lodthing.cpp:169.
  - route B': one `enabledcvar "!coop_compassBarLive"` in the menu **header**, which lands on the container only (uilayout.cpp:98, 150, 182-200). This keeps hide rules, but leaves an invisible 160x160 click target top-left when the HUD is hidden (uiwidget.cpp:1736-1752).
- **Features lost with the ring:**
  - objective arrow and radar: moved to the bar
  - damage flash: covered by cgame `coop_dmgIndicator`; a player who turns that off loses hit direction (8a-2)
- When `coop_compassBar 0` (classic), the bar is not live, the ring returns, and the layout is byte-identical.

---

## 7. Implementation plan

### 7.1 Files and functions per binary

**cgame.dll** (`openmohaa-hzm/code/cgame/`)
- `cg_drawtools.cpp`:
  - `CG_CompassBarVisible()`, `CG_DrawCompassBar()`, and helpers for ticks, labels, objective marker, teammate markers
  - cached `static cvar_t*` pointers
  - call site in CG_Draw2D between the ADS vignette/lagometer and CG_HudDrawElements
  - publish `coop_compassBarLive` (band px, or 0) **only on change**, using the ui_hudAlpha pattern (:2370-2375). The value comes from pref + mode gate + resolution, **not** from the per-frame gates, so the ring never flickers back during a scope or cutscene
- `cg_main.c`:
  - parse `loc` in the CS_OBJECTIVES handler (:516-527)
  - `CG_HudFadeTouch()` on CS_CURRENT_OBJECTIVE value change (:511-513)
  - register prefs; reset `coop_compassBarLive` (and the session flag) to 0 in CG_Init and CG_Shutdown
- `cg_local.h`: `cobjective_t` gains `vec3_t loc; qboolean hasLoc` (:174-177); `cg.compassMates[]`
- `cg_radar.cpp`: raw packet capture in `CG_ReadNonPVSClient` before the validity check (:119-139). The stock path is otherwise unchanged.

**openmohaa.exe** (`openmohaa-hzm/code/client/cl_ui.cpp`)
- `getDefaultDMBoxRectangle` (:1229-1237): `pos.y = coop_compassBarLive` px. The gmbox and UI_GetObjectivesTop follow through max() (:1211-1222, 1244-1247).
- Ring gate at :2433 and :1922.
- When `coop_compassBarLive` is modified, re-apply the dmbox/gmbox frames the way UI_ResolutionChange does (:4087-4095), so the toggle works without vid_restart.

**game.dll:** none in v1.

**pk3 content** (`hzm-mohaa-coop-mod/`)
- `coop_defaults.cfg`: `seta` prefs.
- `ui/coop_settings.urc`: controls (through the redesign pass).
- `textures/hud/compassbar_*.tga` + entries in `scripts/hud_airborne_coop.shader`.
- `maps/m5l3.scr:1001-1002, 1052-1053`: King Tiger label y.
- `coop_mod/dbno.scr:247-253, 1419-1421`: banner y about 142 (after screenshots).
- `global/items.scr:508-523`: +20 virtual y (if reachable in coop).
- If coop-only: `coop_mod/player.scr` (player setup) stufftexts the session flag, re-pushed every few seconds from the manage loop. No mp.scr involvement.
- `docs/tools/check_mp_isolation.py`: clause that no MP file writes the session flag or the compass prefs.

**v2:** dbno.scr downed bitmask push; side-objective position push from officer/radio scripts; `com_radar_range` reset on the MP path (see 7.4).

### 7.2 Ordered steps

1. **Settle user decisions 8a** (single bundled question, together with the settings redesign).
2. **Probe build** (cgame only, `coop_compassProbe` flags 0, prints every 0.5 s, `^~^~^` prefix):
   - camYaw, ps.viewangles yaw, camera_angles yaw, north
   - stats 17/18/19 and reconstructed bearing
   - decoded distance and loc distance
   - INZOOM, STAT_HEALTH, STAT_VEHICLE_HEALTH, pm_flags bits
   - STAT_LETTERBOX, radar packet ages

   Run on:
   - e1l2, m2l1, t1l3, t2l2 (sentinel, set_objective_pos)
   - m1l3b jeep gunner in first and third person, and a glued passenger
   - t2l2 halftrack gunner and bed rider
   - t3l2 tank driver, MG gunner, hull rider

   This settles north sign, gunner yaw, sentinel behaviour, distance accuracy and the gunner's m_pTurret (existing GUNNERPROBE prints, player.cpp:5838-5849). Use the 2-player dedicated harness for remote-client radar.
3. **Bar skeleton:** gates, band, ticks, labels, centre readout, fade. Screenshots at 1024x768, 1280x720, 1920x1080, 2560x1440, 3440x1440, 3840x2160.
4. **Exe:** ring gate + DM box shift + live re-frame. Screenshot `say` + kill + objective update at each resolution in coop.
5. **Current objective marker** + distance + CS_CURRENT_OBJECTIVE wake.
6. **Teammate markers** via compassMates (test: kill a teammate in view, respawn them more than 3000 units away).
7. **Other active objectives** from loc (if 8a-6 says all).
8. **Menu controls, defaults, art;** run audit_menu_cvars.py.
9. **Neighbour moves** (m5l3 label, DBNO banner, items strip) after step-4 screenshots.
10. **Docs at ship time:**
    - record the bar-follows-fade decision and ring-stays-exempt in docs/21-user-preferences.md and docs/DECISIONS.md
    - update FEATURES.md:504-507 and the four exemption comments (cl_ui.cpp:1836-1837, 2440; cg_drawtools.cpp:690, 2194)
    - add to TRAPS: cgame 2D ignores letterbox; turret INZOOM=80 / PMF_CAMERA_VIEW; the stale-solid radar gate
    - buglog entries
11. **v2:** downed teammates, side objectives, radar-range bleed fix.

### 7.3 Tests

- **Resolution matrix** (step 3/4).
- **Gate matrix:**
  - letterbox intro (m3l1a ramp drop)
  - coop ESC board and team select
  - co_lobby1 (`drawhud 0`)
  - console `ui_hud 0`
  - sniper scope and binoculars
  - spectator follow
  - DBNO bleed-out
  - death/respawn
  - scoreboard held
  - build mode
  - each vehicle seat from step 2
- **Fade:** `coop_hudFadeTime 5`; compare the bar against the health panel during fade-out in a bright sky (m1l1) and a dark interior (m4l3); confirm nothing stays readable after panels vanish.
- **Layout:** DM box text never over the bar; gmbox unchanged at 1080p; DBNO banner, XP popup, ready-gate, m5l3 label, e1l2 items clear.
- **Toggle:** bar on/off live without vid_restart; ring and DM box restore; `ui_compass 0` typed by the player still hides the ring with the bar off.
- **Isolation:** with the bar off, and on an MP map (FFA, TOW, Liberation), layout byte-identical and no bar; `python docs/tools/check_mp_isolation.py`; `python docs/tools/docgen.py check`.
- **Skew:** old exe + new cgame and new exe + old cgame both behave as in 6.3.

### 7.4 Effort (estimates, not measured)

| Work | Estimate |
|---|---|
| Probe build + runs | 0.5-1 day |
| Bar skeleton, gates, fade | 1.5-2 days |
| Exe DM box + ring gate | 0.5 day |
| Objective + teammate markers | 1-1.5 days |
| Menu, defaults, art | 1 day (plus art time) |
| Neighbour moves + resolution/gate testing | 1.5 days |
| v2 (downed, side objectives) | 1-2 days |

### 7.5 Isolation

- The bar is cgame and exe code that check_mp_isolation.py never inspects (docs/tools/check_mp_isolation.py:13-66 `[C]`). Isolation is therefore enforced by construction: every layout change keys on `coop_compassBarLive`, which is 0 unless the bar is live.
- If the bar is coop-only, it is live only when a coop script has set the session flag, so MP clients and MP maps see the stock HUD.
- Markers read same-team client entities and radar only, never actors, so enemies cannot appear.
- The coop/MP split has to be checked by hand, plus the new checker clause.

**Pre-existing defects surfaced (log to .wolf/buglog.json when work starts):**
- `com_radar_range 6144` from coop server.scr:49 persists into later MP maps on the same host and into its archived config. mp.scr never resets it (cvar.c:1247-1264). Fix: reset to 1024 on the MP path + checker clause.
- lobby.scr:979 `ui_removehud hud_compass` is a no-op; lobby.scr:980-981's comment contradicts cl_ui.cpp:2043-2044.
- Service Record rows (156+r) and medkit.scr slots 158-160 can show at the same time mid-mission (hud_slot_map.md:72 is stale).
- m6l1a.scr:104 `current_objectives` has no index.
- docs/SOURCE_OF_TRUTH.md:70, 137-138 and ENGINE.md:76-78 wrongly say build.ps1 does not deploy openmohaa.exe.
- The DBNO banner already overlaps the DM box at 720p.
- Possible: the stamina arc draws over letterboxed cutscenes (unverified).

---

## 8. Open questions

### (a) User decisions

1. **Fade scope and marker floor.** The bar fades (request) and the ring keeps its July exemption. When the bar is faded, should markers disappear too (floor 0, the literal request) or stay at a floor such as 0.35? "Markers should still appear" can mean either. Suggested default: floor 0. Quote FEATURES.md:506.
2. **Replace the ring.** Suggested: yes when the bar is on. The user called two displays of the same information "obnoxious" (FEATURES.md:512-516), though that was about objective text lists. Is losing the ring's damage flash acceptable given coop_dmgIndicator covers it?
3. **Coop-only or all modes, and default on.** Suggested: coop-only in v1 through a coop-published session flag (MP stays byte-identical), default on for coop players. If all modes: the DM box shift happens in MP whenever a player enables the bar.
4. **Kill feed rule.** Shift the DM box down under the bar (recommended), or move the kill feed to top-right under the score (bigger exe change).
5. **Scoped and spectator behaviour.** Suggested: hide when scoped, hide when spectating. Alternative: spectator gets heading only.
6. **Objective markers:** current only (suggested v1) or all active objectives?
7. **Distance:** metres (1 unit = 1 inch assumed), feet, or none. Teammate names near centre: yes or no.
8. **v2 priority:** downed-teammate markers; officer/radio side-objective markers.
9. **Arc and label density:** 150-degree arc, labels every 15 degrees (or 180 / 10). Settle with a mockup.
10. **Give locations to the 4 no-location stages** (t1l2 obj 2, t2l2 escort truck, t3l2 bridge, training towers)?

### (b) Playtests

- Z-order and rectangles: screenshot with a test strip at y=0 plus a `say` line and a kill, at 1080p and 3440x1440. Expected: DM box text over the strip.
- DM box shift at every resolution; gmbox position at 720p; DBNO banner and DM box collision; ready-gate 1-2 px gap.
- Is the m5l3 King Tiger label reachable in the coop flow? Does global/items.scr draw on coop e1l1/e1l2?
- Vehicle yaw: first-person jeep/halftrack gunner, reconstructed bearing stable while the vehicle turns (m1l3b, t2l2); tank driver and glued riders (t3l2).
- Gunner STAT_HEALTH: player or vehicle (GUNNERPROBE); does STAT_VEHICLE_HEALTH clear after dismount?
- Sentinel on t2l2; non-sentinel on e1l2/m2l1/t1l3; decoded distance against a known entity distance.
- Radar: teammate respawned more than 3000 units away never appears in the stock radar but appears through compassMates; downed teammate far away stays tracked.
- Letterbox and cutscene gates on m3l1a; does the stamina arc already show under letterbox?
- Squared-fade look against panels; @3x font shimmer at 720p.
- Settings toggle visibility behind the non-fullscreen folder with the poke.
- Loading screen: can CG_Draw2D run during CA_LOADING/PRIMED (cl_scrn.cpp:451-454) and flash the bar?
- Confirm the radar-range bleed: coop map, then an MP team map on the same listen host, then type `com_radar_range`. Expected: 6144.
- Stuffed session flag reliability over a dedicated server with a remote client (T8 loss).

### (c) More research

- North convention: does worldspawn northyaw place N where textures/hud/hud_compass_in.tga draws it? Cheapest: open the TGA and compare against the probe print on a map with non-zero northyaw.
- Confirm that ps.viewangles in the snapshot equals the v_angle STAT_OBJECTIVECENTER was computed from (player.cpp:9432-9441 order) in every seat. The probe settles it.
- Is dbno.scr reachable from any MP path (mp.scr:80-82 reuses player.scr::manageDead)? Grep before choosing an ungated downed carrier.
- Typical coop cg_fov, which scales the snapshot's behind-cull distance. Grep CVARS_ENGINE.md/CVARS_COOP.md and autoexec.
- In Liberation/TOW, is more than one objective relevant per team (Tow_Entities.cpp:318-321 controller cvars)?
- The scope of the July compass exemption (ring vs any compass): no quote exists in buglog or git (18 matching commits, none about it). Ask the user rather than dig through frozen archives.
- Commercial bar widths and positions for BF6/Warzone/PUBG/Hunt, and compass position in BF2042/BFV/HLL, are unmeasured. Measure on Game UI Database pages (https://www.gameuidatabase.com/index.php?scrn=165) only if the 0.42W/0.75H proposal is disputed.