# Loadout v3 "world-class" rebuild — implementation plan (2026-07-17)

Verified ground truth (3 scouts + engine reads). Execute top to bottom. Defects reference the 07-17 screenshot batch (shot0090-0105).

## Ground truth (cited)
- Authority is ALREADY server flags: spawn/DBNO/revive/ammo consumers read `flags["coop_loWeapons"/"coop_loSlot*"]` only; NO server getcvar of chip cvars anywhere. Client→server channel = name bus 42-46 (w1-w4) / 46 (,w0 menuCtl). loadout_set writes flags at loadoutpick.scr:80-81.
- BUG A (deny desync): all 3 deny branches (unknown :35, wrong-slot :44, locked :57) iprint+end WITHOUT reverting the 4 archived chip cvars `coop_lo<n>/loN<n>/loS<n>/loA<n>` that w<id>_s<n>.cfg already seta'd. Revert template EXISTS at :74 (one-per-class bump single-line stufftext).
- BUG B (stale locks): `coop_loLk<id>` is SETA-persisted, never seeded by init.cfg, exported only on chal_grant/rank events → stale garbage across sessions (free guns dim-locked, NAMBU none). Export writes 0 for all when gate off; gate IS ON (server.scr:28 defaults coop_lockLoadout=1 — the "DORMANT" comment at loadoutpick.scr:53 is WRONG).
- BUG C (orphan locks): engine draws enabledcvar widgets purely by cvar ignoring page visibility (uiwidget.cpp:1982/1986: enabledcvar widgets SKIP IsVisible); a widget takes exactly ONE enabledcvar; padlock tiles (gen l435: rect 452,ty,14,14 per-tab row Y) gate only on coop_loLk<id> → every locked id draws on EVERY tab at its row Y.
- BUG D (renders): rendermodelfit frames re.ModelBounds (cl_uistd.cpp:1694), camera dist = maxdim*scale*0.5/0.268 (:1710), centers Y/Z (:1697-98). Degenerate/authored-wrong TIKI bounds (pistols, m2frag) → sliver/empty. modeloffset/modelscale/modelangles (cl_uistd.cpp props :156-213) apply ON TOP and are STATIC per widget → per-CLASS preview widgets are the fix (fit OFF + fixed camera for pistol/nade classes).
- Layout numbers (gen_loadout2.py): tiles LIST_X/W/H/Y0/DY=306,162,16,80,19; padlock at 452,ty+1,14,14 ordernumber 8; wreq coop_loReq rect 478 180 152 11 OVERLAPS bar0 DMG 516 184 + clips at panel edge 630; clipNum "N RDS" at 478 246; skin/helmet buttons y=398/416 overlap baked captions y=390/408; MAG strip = single linkcvartoshader label → textures/hud/clip/clip_<N> (32 blocks overflow track). bg2.tga captions baked to same constants — layout change = re-bake bg + re-emit urc TOGETHER.
- Tabs: RIFLE 11 (ids 01-11) enabledcvar '!coop_loNP0'; SNIPER 12-23; SMG 24-35; HEAVY 36-47; PISTOL 48-63 (16); NADES 64-69 (6); others coop_loP1..5. Tab buttons pure client page_sets (gen l406).
- Click chain: tile → t<id>.cfg (exec p<id>.cfg + vstr coop_loCcur) → p<id>.cfg stages preview (set) + coop_loC1..4 commit lines → w<id>_s<n>.cfg = THE commit (seta 4 chip cvars + bus append). Padlock NEVER consulted client-side (cfgs can't branch).
- Persistence: chip cvars seta-archived; join resend loadout_resend :142 re-fires vstr coop_loA1..4 (t+4/t+15) → re-validates on server each map. reset.cfg = USE MAP DEFAULT (clears 16 cvars + ,w0c → loadout_clear flags).
- loadout_rebuild :183-217: grenade→sidearm→p1→p2 (dupe collapse), writes flags coop_loWeapons. one-per-class bump :65-78. regiveWatch :105 debounced re-give (join window ≤120s).

## Build steps

### 1. loadoutpick.scr authority + lock freshness  [scripts only]
1a. loadout_set deny branches (all 3): after iprint, REVERT the clicked slot's 4 chip cvars to the server's last VALID pick (flags coop_loSlotId<slot> → roster_get → name/shader; or empty if none), using the :74 single-stufftext template; then `thread loadout_ui_exportUnlocks` to re-push fresh lock states. Fix the WRONG "DORMANT" comment at :53.
1b. Lock cvars: change exportUnlocks to `set` (NOT seta) so stale values die with the session; ALSO export on menu open (loadout_menuCtl open path / first resend volley).
1c. Tab-visibility compound: exportUnlocks gains tab awareness → maintains `coop_loLkV<id>` = (locked AND item's tab == active tab) ? 1 : 0. Tab buttons get an extra bus fire: reuse token 46 with data "t<0-5>" → loadout_menuCtl stores player.flags["coop_loTab"] + re-exports. Padlock tiles in v3 urc bind enabledcvar coop_loLkV<id>. Pace waitframe/8.
1d. KEEP: one-per-class bump, dupe collapse, resend volleys, regiveWatch, ammoTopup — untouched.

### 2. gen_loadout3.py  (copy gen_loadout2.py → v3; regenerates bg2 TGA + urc + cfgs + roster)
2a. LAYOUT CONTRACT: central rect registry; assert (build-fails) no intersecting rects among {tiles, locks, req row, stat rows, mag strip, buttons, captions} and every text label's est. width (chars * font advance) ≤ its rect w. Fonts: verdana-12 ≈ 6px/char virtual.
2b. Inspect right column re-grid (panel x478..630): title / caliber (font-size-aware, truncate+ellipsis if > width) / NEW dedicated REQ row (own y, amber, 11px, clipped) / DMG/RPM/ACC/MOB bars / MAG row: strip width fixed 152, block w = max(2, floor((152 - (n-1)) / n)) so 32 rds fits; RDS count text INSIDE mag row right edge (remove top-right clipNum near DONE).
2c. Padlocks: enabledcvar coop_loLkV<id> (from 1c). Also emit a small "LOCKED" hint on the tile row? NO — padlock only, keep clean.
2d. SKIN/HELMET block: reserve rows — caption y then buttons y+14 (SKIN cap 384, btns 396; HELMET cap 414, btns 426); re-bake captions in bg accordingly.
2e. PREVIEW: replace single inspect rendermodel widget with SIX per-class widgets (same rect), each enabledcvar coop_loPvC<class#> (rifle0 sniper1 smg2 heavy3 pistol4 nades5), p<id>.cfg sets its class cvar 1 + other five 0. Class params: rifle/sniper/smg/heavy = rendermodelfit 1 (works today); PISTOL = fit 0 + modelscale ~2.2 + modeloffset tuned + modelangles 0 90 0; NADES = fit 0 + modelscale ~3.0 + tuned offset. Card thumbs (slot chips) same treatment via class of the EQUIPPED id → simpler: leave card thumbs with fit (they look acceptable) — revisit after user screenshots. Per-gun override table PERGUN = {id: (fit,scale,offset,angles)} for outliers (colt silenced etc.) — emits a per-gun widget instead of class widget membership.
2f. Sanity: emit r<id>_s<n>.cfg NOT needed (server reverts via direct stufftext seta).
2g. Regen set: bg2.tga + coop_lo_lock.tga + urc + ~330 cfgs + loadoutroster.scr — deploy together.

### 3. Briefing ready-up overlay  [in progress]
Retail slide URCs extracted (scratchpad/briefing_urcs/briefing1a..g.urc from main/Pak0.pk3 ui/briefing1*.urc). Slides = fullscreen menus w/ bgfill 0 0 0 1; ihuddraw can NEVER show above menus; overlay must live INSIDE each slide menu, appended LAST (in-menu file order = draw order). Script showmenu/ForceShow does NOT re-raise; slides hide predecessors so only one visible.
3a. gen_briefing_overlay.py: for each of briefing1a,1b,1c,1c2,1d,1e,1f,1f2,1g: take retail content, insert the coopgate_* resource blocks (moved VERBATIM from ui/missionbriefingback.inc :100-273) immediately before `end.` → write hzm-mohaa-coop-mod/ui/briefing1X.urc (pk3 path overrides Pak0).
3b. Strip coopgate block from ui/missionbriefingback.inc (restore backdrop-only; briefing2-6 lose the dead overlay too).
3c. readygate.scr: remove 3 DEBUG prints (:24 :98 :262). ihuddraw copies stay (harmless fallback).

### 4. Lobby skin-cycle removal  [player.scr]
Bus 31/32 dispatch (player.scr:561-562): lobby branch → replace lobbySkinCycle calls with iprint "Change skins in the ARMORY (Loadout menu)" (keep armory branch). lobby.scr::lobbySkinCycle stays (dead code ok) — do NOT touch mannequin display.

### 5. Officer music fade — DONE this session (officer.scr coop_officer_music_fadeout; 15s interruptible; death-path starts at tracked coop_officer_musicvol).

### 6. Verify + ship
depthscan2.py on loadoutpick/player/readygate/officer; generator layout-linter must pass; adversarial review workflow (3 lenses: cfg/cvar-flow correctness, urc/engine semantics, regression vs kept behaviors); build.ps1; user screenshot loop for per-gun fit tuning (expect 1-2 passes on PERGUN table).

## Locked decisions
- Padlock = visual only + SERVER deny+revert is the enforcement (cfgs can't branch client-side).
- Lock cvars session-only (`set`), never seta.
- Preview = per-class widgets, per-gun override table for outliers.
- RDS readout removed from top-right; count lives in MAG row.
- Lobby loses skin cycling; armory owns it. Helmet cycling was never in lobby bus (35/36 armory-routed already).
