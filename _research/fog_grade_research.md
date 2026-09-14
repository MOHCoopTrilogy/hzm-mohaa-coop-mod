> **USER DECISIONS (2026-09-13, after this note):**
> 1. Fog strength: SUBTLE DEPTH - keep each map's native fog distance (no AI sight-range change); tune bias and
>    colour only. Consequence: maps with no fog today (m1l1, m1l2a/b, co_lobby2-4, m6l3a-e) get no fog, and m3l1a
>    (any profile turns off its scripted fog lift) is grade-only.
> 2. Tone baseline: the HZM ACES grade - fix the CG_CoopDaylight first-frame reset (bug-2584) so the grade is live.
> 3. Per-map colour grade ON by default, with a player toggle off; the player's own r_pp* sliders are never written.
> 4. HD sky pack duplicates (bug-2583): KEEP the HD skies and RE-AUTHOR fog colour to match them on the affected maps.
> - HD-sky fog (bug-2583), user 2026-09-13 after the m2l1 pilot: KEEP the HD skies but give the washed-out
>   HD-sky maps a MOODIER, non-sky-matched fog (visible cool/warm atmosphere) at native distance - the sky-matched
>   0.81 grey was invisible on bright snow. Applies to the 13 EYES HD-sky maps.
> 5. Taken at the recommendation unless the user says otherwise: a grade toggle plus a fog-strength slider with a
>    floor above zero; colour-only profiles on scripted-fog maps (m3l1a, M3L3, e2l2, e2l3, e3l3, m4l3, m6l2a, m2l2c).

# Per-map fog and per-map colour grade - research note

Written 2026-09-13. READ-ONLY pass: nothing was built, deployed, launched or edited apart from this file.
The user approved: a fog pilot first, with before/after screenshots for approval, then the rest of the maps. Per-map grade was also approved.
Every claim below cites code or data that was read in this pass. Where a record and the code disagree, the code wins.
Six places where the existing docs or the plan are wrong are listed in section 0.

Data source for the inventory: a Python pass over the retail and mod pk3s in
`G:\GOG\...\main`, `mainta` and `maintt`, in load order. G:\mohaa-gl2\main*, the live install, are junctions to
exactly those folders. The pass read each BSP's entity lump (worldspawn) and shader lump, resolved every
sky shader's `skyParms` farbox, and averaged the band just above the horizon on the four side faces of
whichever image the live load order picks. The script is in the session scratchpad (`bspscan2.py`); it is
not shipped.

---

## 0. Corrections to the plan and the docs (read first)

1. **Height fog (plan item 9) is dead in coop.** `World::UpdateAnimatedFarplane` returns immediately when
   `g_gametype != GT_SINGLE_PLAYER` (`fgame/worldspawn.cpp:860`). It also interpolates on
   `g_entities[0]`, i.e. one player. Fog is one configstring shared by every client (`worldspawn.cpp:662-693`),
   so per-player height fog cannot come from the server at all. The only viable shape is client-side (see 5.4).
2. **`r_globalFogPreTone` does not matter any more.** The live path is the FORWARD fog
   (`r_globalFogForward 1`: `renderergl2/tr_init.c:2154`, live `omconfig.cfg:740`). Both screen-space call
   sites are gated `!R_UseForwardGlobalFog()` (`tr_backend.c:2223, 2265`). Forward fog is mixed inside the surface
   shaders, so it is always pre-tone. The "pinned until ACES is ported" note in plan section 4 is moot.
3. **The HZM ACES grade is NOT the live tone path, and a player's manual grade is wiped on every cgame load.**
   `CG_CoopDaylightThink` runs on its first evaluation. At `coop_daylight 1` it writes `r_ppTonemap 0` and resets
   `r_ppExposure/Contrast/Saturation/Temp` to hardcoded engine defaults (`cgame/cg_view.c:7226-7236`).
   The live config shows exactly those constants (`omconfig.cfg:4556 r_ppTonemap "0"`, `:4571 0.889971`,
   `:4576 0.951289`, `:4561 1.031519`), not the `coop_defaults.cfg` seeds (`:95 r_ppTonemap 1`, `:80 0.7`,
   `:64 0.998567`, `:90 1.083095`). With `r_tonemapMode 0` (`omconfig:912`) and `r_ppGrade 0` (`:4569`), the
   `RB_ToneMap` grade gate (`tr_postprocess.c:111`) is closed. The live image therefore goes through rend2's Hable curve with
   auto-exposure (`tr_postprocess.c:140-145`, `r_autoExposure 1` at `omconfig:4523`).
   The comment at `tr_backend.c:1530-1540`, and bug-1304's premise, say `r_ppTonemap` ships 1. That is not
   true on the live install. `r_ppGrade` is the only grade control that survives, because the day branch does not write it.
   **Parent session: this deserves a buglog entry. Nothing was changed here.**
4. **bug-1296 (OPEN.md:339-358) describes the screen-space pass, not the live one.** The forward path fogs
   blended stages per surface, using gl1's per-stage table (`tr_shade.c:1413-1490`, bug-1304, user-confirmed
   2026-08-03). On the live renderer, what remains unfogged is only: blend combinations gl1 also calls unfoggable,
   `nofog` shaders, `GLS_MULTITEXTURE_ENV` stages, and the sun-ray mask. Do not re-propose the three rejected
   fixes. Re-verify the OPEN entry with one screenshot instead (see 6.1).
5. **`skybox_farplane` only sets the sky-portal view's far distance** (`tr_sky_portal.cpp:174`). Global fog is
   skipped for portal-sky views (`tr_backend.c:1454-1457`, `tr_shade.c` same guard). It matters only on the three
   maps with a `script_skyorigin` (t1l1, t3l1, t3l2). The editor's SKYFAR key does nothing visible anywhere else.
6. **`farplane_cull` is a boolean.** The script event is `GetBoolean` (`worldspawn.cpp` `SetFarPlane_Cull`, ~777;
   `qcommon/listener.cpp:2132`) and the renderer tests only nonzero (`tr_main.c:856`). The BSP values `2` and
   `3000` both mean 1, and the editor's cull cycle 0/1/2 has only two real states.

Minor: `coop_mod/cfg/fogmode.cfg` says saves go to `%APPDATA%\openmohaa\maintt\coop_mod\save\`. The live
homepath is `G:\mohaa-gl2\home\maintt\coop_mod\save\`, and a `fog_m1l3c.dat` sits there now (2026-08-07,
identical to the shipped file).

---

## 1. How fog works end to end today

### 1.1 Data format and editor
- Profile = one line, `fogv1,<dist>,<bias>,<r>,<g>,<b>,<cull>,<skyfar>` (`coop_mod/fogmode.scr:219-228`).
  Shipped: `coop_mod/fog/e2l2.dat` = `fogv1,1000,450,0.050,0.060,0.100,1,0`,
  `coop_mod/fog/m1l3c.dat` = `fogv1,4250,450,0.050,0.060,0.100,1,0`. Both are the night preset colour.
- Load order: homepath `coop_mod/save/fog_<map>.dat` first, then the shipped `coop_mod/fog/<map>.dat`
  (`fogmode.scr:231-237`). The key is `level.coop_mapname`, lowercase (`fogmode.scr:329-343`).
- Boot: `main.scr:180` threads `coop_fog_boot` unconditionally on every coop map. It runs captureNative, then
  loadProfile, and starts the editor only when `coop_fog 1` (`fogmode.scr:41-49`).
- Applying: all profile fields go through `coop_fog_apply` as `$world farplane / farplane_color / farplane_bias /
  farplane_cull / skybox_farplane` (`fogmode.scr:80-104`). `farplane` is skipped when dist is 0 or less (`:83`). The
  apply also rewrites `global/weather.scr`'s `level.farplane*` snapshot so lightning restores the profile (`:95-101`).
- Holding: `coop_fog_lateAsserts` re-applies at +2, +5 and +10 s, then polls every 2 s for the whole level. It
  re-applies whenever `$world.farplane != coop_fogDist`, but only if dist > 0 (`fogmode.scr:273-295`).
  `level.coop_fogProfileLoaded = 1` (`:258`) makes the m3l1a Omaha fog lift stand down
  (`maps/m3l1a/coopified.scr:19905`).
- Editor: a submode of build mode. Run `exec coop_mod/cfg/buildmode.cfg`, then press `\` twice
  (`buildmode.scr:258-271`). The key map is `coop_fog_mapKey` (`buildmode.scr:222-242`):
  - 8/2 = distance, in 250 u steps
  - 6/4 = bias, in 100 u steps
  - 7/1 = red, 9/3 = green, / and * = blue, in 0.05 steps
  - +/- = skyfar
  - ENTER = save, KP_5 = reset, KP_INS = night preset, KP_DEL = mist preset, ; = cull
  
  HUD slots 88-94 show the live AI sight value, `dist*0.828` (`fogmode.scr:365-374`).
- Known editor gaps:
  - captureNative seeds bias 0, cull 1 and sky 0 instead of the map's real values (`fogmode.scr:62-68`),
    although a bias getter exists (`worldspawn.cpp:217`). So KP_5 "reset to native" is not native on maps with
    bias or cull keys (e2l1, e2l2, e2l3, e3l1, e3l3, e3l4, t1l1, t1l2, t2l1-t2l4, t3l1).
  - Colour steps of 0.05 are too coarse for night fogs (0.03 .05 .09 class). Hand-edit the .dat instead.

### 1.2 How the worldspawn keys reach the renderer
Server: the BSP worldspawn keys are ordinary events (`farplane`, `farplane_color`, `farplane_bias`,
`farplane_cull`, `skybox_farplane`, `skybox_speed`: `worldspawn.cpp:117-285`). Every setter calls `UpdateFog`,
which does two things (`worldspawn.cpp:662-693`):
- `gi.SetFarPlane(dist)`
- packs 13 fields into `CS_FOGINFO`: cull, dist, bias, skyfar, skyspeed, colour, render_terrain, farclip override,
  colour override

Client: `cg_main.c:553-558` resets the overrides and parses the string (`CG_ParseFogInfo_ver_15`, `cg_main.c:1085-1102`).
`cg_view.c:6118-6124` copies it unchanged into the refdef every frame. From there the renderer does the following:

| key | what gl2 does with it | cite |
|---|---|---|
| `farplane` (dist) | Fog END. 0 = no fog and no far cull at all. With cull, it also adds a far frustum plane | `tr_backend.c:1485-1488, 1516`; `tr_main.c:846-867` |
| `farplane_bias` | Fog START, in world units. **0 is replaced by 18% of dist.** Negative = fog already present at the eye (e2l1 -200 gives 8% at 0 u; t2l1 -1500 gives 30%). start >= end means NO fog (early return) | `tr_backend.c:1515, 1525`; `tr_scene.c:834-835` |
| `farplane_color` | Fog target colour, raw (identityLight 1). Also the CLEAR colour when no sky or portal drew. So on `caulksky` maps (skyParms `env/idontexist`) the fog colour IS the sky. The skybox shell is itself fogged when `r_globalFogSky 1` (live), so the sky is pulled toward this colour | `tr_backend.c:1542-1547, 388-392`; `tr_sky.c:481-487` |
| `farplane_cull` | Boolean: adds the far frustum plane (`VPF_FARPLANEFRUSTUM`), which culls geometry beyond dist | `tr_main.c:856-862` |
| `skybox_farplane` | Far distance of the sky-portal sub-view only. No fog there | `tr_sky_portal.cpp:174` |
| `animated_farplane*` | Ignored outside SP (server-side, see 0.1) | `worldspawn.cpp:860` |
| `farclipoverride` (script) | Only matters when `tr.farclip` is set (`r_farclip` cheat, or `r_picmip >= 2` / 16-bit forcing 2800). It then takes the MIN with the map's plane | `tr_scene.c:792-833` |

Forward fog per draw (`tr_shade.c:1413-1490`):
- Disabled for 2D, depth fill, the sun-ray FBO, `nofog` shaders, the cube capture FBO, portal views, sky views
  when `r_globalFogSky 0`, and multitexture-env stages.
- Additive stages fog toward black, modulate stages toward white, alpha-blend and opaque stages toward the fog colour.
- Distance comes from `gl_FragCoord.z` and the latched projection (`lightall_fp.glsl:96-119`).
- The mix clamps the HDR operand, because an unclamped mix leaves bright pixels unfogged (bug-1299).

### 1.3 Per-client versus server-driven
- **Server (one value for everyone, replicated through the configstring):** dist, bias, colour, cull, skyfar,
  skyspeed, render_terrain, farclip override, colour override. Profiles are read on the SERVER (dedicated =
  the server homepath), so remote clients need nothing.
- **Client (per player, archived):**
  - `r_globalFog` (kill switch) and `r_globalFogScale` (multiplies the fog fraction; forward path at
    `tr_shade.c` `fogColor[3]`)
  - `r_globalFogStartScale/EndScale`, `r_globalFogSky`, `r_globalFogForward`, `r_globalFogRadial`/`Debug` (both force
    the legacy pass) (`tr_init.c:2131-2154`)
  - `r_farplane*` and `r_farclip` are `CVAR_CHEAT` (`tr_init.c:2121-2127`)
  - `r_picmip >= 2` caps the far clip at 2800 (`tr_scene.c:801-803`)
- **AI (server):** sight is clamped to `farplane_distance * 0.828` wherever farplane > 0
  (`actorenemy.cpp:50-55, 546`; `actor.cpp:4470, 9221-9238, 10512`). The officer envelope scales from
  `$world.farplane`, with 0 treated as 8000 (`officer.scr:3063-3072`). Bias and colour have no gameplay coupling.
  (`player.cpp:5513` is SP-only; the `playerbot.cpp` sites are MP bots.)

### 1.4 Maps with no profile
Nothing is written. The map keeps its BSP worldspawn fog plus whatever its own scripts do. Where the BSP has no
`farplane` and no script sets one, there is no fog, no far cull and no AI sight clamp at all. That applies to
12 maps at runtime: m1l1, m1l2a, m1l2b, co_lobby2/3/4, m6l3a-e, plus M1L3c (whose script
forces `farplane 0` at `maps/M1L3c.scr:51`; its shipped profile then overrides that).

---

## 2. How the grade works

### 2.1 Code
`RB_ToneMap` (`renderergl2/tr_postprocess.c:88-133`):
- The gate is `r_tonemapMode==1 || r_ppTonemap || r_ppGrade` (`:111`). When it is closed, the stock rend2 Hable path with
  `r_cameraExposure` and auto-exposure runs (`:82-86, 136-145`).
- When the gate is open, the inputs are `r_ppExposure/Contrast/Saturation/Temp`: archived, engine defaults 0.889971 / 0.951289 /
  1.031519 / 0 (`:98-101`).
- `r_ppGrade` 1-4 OVERRIDES all four (`:120-125`):
  - 1 Neutral: expo 1.0, cont 1.05, sat 1.0, temp 0
  - 2 Warm "Normandy": 1.05, 1.10, 1.05, +0.10
  - 3 Cold "Ardennes": 0.95, 1.10, 0.85, -0.10
  - 4 Bleach bypass: 1.0, 1.35, 0.55, -0.02
- Shader `glsl/tonemap_hzm_fp.glsl`: exposure -> ACES -> contrast about mid-grey -> saturation -> temp tint.
- All inputs are read live every frame. No restart is needed.
- Player UI: the `ui/coop_postfx.urc:285-299` slider `slGrade` links `r_ppGrade`, range 0-4, and `:429` links `r_ppTonemap`.

Live state: the gate is closed (see 0.3). `CG_CoopDaylightThink` (`cg_view.c:7194-7266`, called every frame at
`:7486`) writes those archived cvars:
- at `coop_daylight 1` it restores the defaults once per cgame load
- below 1 it opens the gate through `r_ppTonemap 1`, forces `r_ppGrade 0`, and lerps a night grade

The server replicates `coop_daylight` change-only (`fgame/player.cpp:15329-15346`).

### 2.2 Can a per-map grade be pushed from the server?
- **Transport:** yes. `CG_IsVariableAllowed` passes any `coop_`-prefixed name (`cg_servercmds_filter.cpp:165-175`).
  A server `set r_pp*` is dropped: `r_pp*` is not whitelisted (`:26-99`), and `CG_IsSetVariableAllowed`
  refuses registered archived cvars (`:202-226`).
- **Two send options:**
  - Script: `stufftext` per player, at spawn and on join (T8: unquoted, one statement per stufftext).
  - Engine: publish change-only from `player.cpp`, exactly like `coop_daylight`. This reaches late joiners and
    dedicated clients.
  
  Recommended: ONE packed cvar, e.g. `coop_mapGrade 1.00,1.05,0.90,-0.04`, so the four values arrive atomically.
- **It needs a cgame relay AND a small gl2 change.** The plan's "cgame folds them multiplicatively" cannot be done
  in cgame alone, because the renderer reads `r_pp*` directly. The only way cgame can influence it is by writing
  those archived cvars, which stomps player settings and is the bug-2165 failure class. The clean shape follows the
  existing cgame-published, non-archived renderer cvars (`r_ppHeat`, `r_ppRainWet`, `r_ppHealthFrac`: flags 0,
  `tr_postprocess.c:769, 810, 912`):
  1. gl2: add flags-0 `r_ppMapGrade` (active 0/1) plus `r_ppMapExpo/Cont/Sat/Temp`. In `RB_ToneMap`, after the
     preset switch: `expo*=mapExpo; cont*=mapCont; sat*=mapSat; temp+=mapTemp`, and open the gate when the
     map grade is active.
  2. cgame: parse `coop_mapGrade`, check the player's opt-out, and publish the `r_ppMap*` cvars. Reset to neutral at CG_Init,
     so a later MP server that never publishes gets no coop grade.
  3. Server: a per-map table (a script array, or `coop_mod/grade/<map>.dat` next to the fog profiles).
- **Not overriding the player:** multiply over whatever the player's own preset or sliders produce. Never
  write `r_pp*`. The opt-out preference must NOT be `coop_`-prefixed, or a server could flip it. A name like `r_ppMapGradeOn`
  (archived, default 1) is filtered for server sets by `CG_IsSetVariableAllowed`. Add a checkbox next to `slGrade`.
- **Hard prerequisite:** decide the baseline tone path first, and fix the daylight think's first-frame restore so it
  no longer closes the gate (0.3). Otherwise the multipliers apply to a path that is off. Opening the gate also switches
  the curve from Hable + auto-exposure to ACES + fixed exposure, which is a global look change before any per-map work.
  Fog colours must be tuned AFTER that switch, or every profile is retuned twice.

---

## 3. Inventory: the 65 coop-integrated maps

Map list from `docs/generated/SUBSYSTEMS.md:212-278`. Column meanings:
- **fog** is BSP worldspawn `farplane` / `farplane_bias` / `farplane_color` / `farplane_cull`. `-` means key absent,
  so dist 0 = no fog.
- **horizon** is the average RGB of the band just above the horizon on the LIVE sky image. "caulksky" means
  `env/idontexist`, where the fog or clear colour is the sky.
- **setting** is inferred from sky, sun colour and shader-name counts (snow/sand/interior), and is labelled as inferred.
- **scr** = the map script tree mentions `farplane` (file-level grep of `maps/`). `ramp` = scripted distance changes.
- **prof** = a shipped fog profile exists.

Summary counts:
- 47 of 65 have BSP fog; 18 do not.
- 12 have no fog at runtime (1.4).
- 2 have shipped profiles.
- 35 map script trees touch farplane.
- 13 use caulksky; 3 use a sky portal.

| map | src | fog dist / bias / colour / cull | sky shader (farbox) | horizon (live) | setting (inferred) | scr | prof |
|---|---|---|---|---|---|---|---|
| M1L3a | AA | 4600 / - / .03 .05 .09 / - | sky/mohnightfog | .042 .058 .101 | night, N.Africa | - | - |
| M1L3c | AA | - | sky/lighthouse | .108 .160 .217 | night coast, lighthouse | Y (sets 0) | Y |
| M3L3 | AA | - | sky/d-day2 (DDS) | .63 .63 .62 | Normandy overcast, hedgerow town | Y ramp | - |
| M5L2A | AA | 5500 / - / .333 .333 .359 / - | sky/m5l2 (HD dup!) | .80 .82 .83 (retail .35 .35 .38) | overcast rural | - | - |
| M6L1b | AA | 1600 / - / .2 .2 .3 / - | caulksky | = fog | snow night forest | - | - |
| co_lobby1 | lobby (training copy) | 13000 / - / .7 .7 .55 / - | sky/mohday2 (HD) | .83 .87 .90 | clear day | - | - |
| co_lobby2 | lobby (m1l1 copy) | - | sky/africanight | .105 .159 .236 | night town | - | - |
| co_lobby3 | lobby (m1l2a copy) | - | sky/africanight | .105 .159 .236 | night town | - | - |
| co_lobby4 | lobby (M1L3c copy) | - | sky/lighthouse | .108 .160 .217 | night coast | - | - |
| co_lobby5 | lobby (m2l1 copy) | 14500 / - / .6 .6 .7 / - | sky/norway_dawn (HD) | .81 .81 .82 | snow; script night 1500 | Y | - |
| co_lobby6 | lobby (m2l1 copy) | 14500 / - / .6 .6 .7 / - | sky/norway_dawn (HD) | .81 .81 .82 | snow dawn | - | - |
| co_lobby7 | lobby (m2l2c copy) | 15000 / - / .6 .6 .7 / - | caulksky | = fog | Norway naval base | - | - |
| co_lobby8 | lobby (e1l4 copy) | 5000 / - / .03 .05 .09 / - | ep2sky/e1l4sky | .052 .062 .081 | night | - | - |
| e1l1 | BT | 1500 / - / - / - (script .35 .24 .16, bias 50) | ep2sky/e1l1sky (16x16 flat) | .353 .239 .161 | desert dusk/sandstorm | Y | - |
| e1l2 | BT | 5000 / - / .35 .28 .20 / - | ep2sky/e1l2sky | .356 .286 .204 | desert day, dusty | - | - |
| e1l3 | BT | 4200 / 0 / .651 .594 .486 / - | ep2sky/e1l3sky (HD dup!) | .80 .82 .83 (retail .55 .52 .48) | desert town day | - | - |
| e1l4 | BT | 5000 / - / .03 .05 .09 / - | ep2sky/e1l4sky | .052 .062 .081 | night | - | - |
| e2l1 | BT | 2300 / -200 / .176 .176 .191 / 1 | ep2sky/e2l1sky | .176 .176 .192 | Sicily night, glider | Y | - |
| e2l2 | BT | 3000 / -256 / .25 .26 .28 / 2 | ep2sky/e2l2sky + caulksky | .247 .259 .282 | Sicily night | Y ramp (cinematic x7) | Y |
| e2l3 | BT | 3000 / -256 / .31 .33 .43 / 2 | ep2sky/e2l3sky | .324 .335 .441 | Sicily dusk town | Y ramp (FinalHouse) | - |
| e3l1 | BT | 2200 / 1000 / .25 .26 .28 / 0 | ep2sky/e3l1sky (HD dup!) | .80 .82 .83 (retail .248 .259 .282) | Italy overcast | Y (Courtyard) | - |
| e3l2 | BT | 2500 / - / .16 .16 .17 / - | ep2sky/e3l2sky | .153 .157 .173 | overcast, interior-heavy | - | - |
| e3l3 | BT | 2400 / 0 / .06 .06 .1 / 2 | ep2sky/e3l3sky (mod tex) | .059 .059 .106 | night river | Y ramp (fog.scr) | - |
| e3l4 | BT | 3000 / -100 / .102 .102 .102 / 2 | ep2sky/e3l4sky + caulksky | .102 .102 .102 | night mountain | Y (Outro) | - |
| e3l4_arena | loose e3l4 BSP copy | as e3l4 | as e3l4 | as e3l4 | night holdout | - | - |
| m1l1 | AA | - | sky/africanight | .105 .159 .236 | night N.Africa town | - | - |
| m1l2a | AA | - | sky/africanight | .105 .159 .236 | night town | - | - |
| m1l2b | AA | - | sky/africanight | .105 .159 .236 | night town | - | - |
| m1l3b | AA | 4600 / - / .03 .05 .09 / - | sky/mohnightfog | .042 .058 .101 | night | Y | - |
| m2l1 | AA | 14500 / - / .6 .6 .7 / - | sky/norway_dawn (HD) | .81 .81 .82 (retail .41 .41 .55) | Norway snow dawn | commented only | - |
| m2l2a | AA | 15000 / - / .6 .6 .7 / - | caulksky | = fog | naval base | - | - |
| m2l2b | AA | 15000 / - / .6 .6 .7 / - | caulksky | = fog | naval base (sub 6000 .72 .75 .80) | Y | - |
| m2l2c | AA | 15000 / - / .6 .6 .7 / - | caulksky | = fog | naval base | Y ramp | - |
| m2l3 | AA | - (script 10000 .6 .6 .7) | caulksky | = fog | Norway snow | Y ramp | - |
| m3l1a | AA | - (script 2000-8300, .62 .62 .61) | sky/d-day2 (DDS) | .63 .63 .62 | Omaha beach overcast | Y ramp + RAMPFOG | - |
| m3l1b | AA | - (script 6500 .675 .663 .651) | sky/d-day2 (DDS) | .63 .63 .62 | beach bunkers | Y ramp | - |
| m3l2 | AA | 6200 / - / .62 .62 .61 / - | sky/d-day2 (DDS) | .63 .63 .62 | Normandy countryside | - | - |
| m4l0 | AA | 13000 / - / .7 .7 .55 / - | sky/mohday1 (HD dup!) | .83 .87 .90 (retail .72 .72 .73) | clear day | Y | - |
| m4l1 | AA | 3100 / - / .2 .2 .235 / - | caulksky | = fog | night town, interior-heavy | - | - |
| m4l2 | AA | 3100 / - / .2 .2 .235 / - | caulksky | = fog | night (blue moon) | - | - |
| m4l3 | AA | 2700 / - / - (script 1500 .1 .1 .14) | caulksky | = fog | night, interior-heavy | Y ramp | - |
| m5l1a | AA | 3500 / - / .333 .333 .359 / - | sky/m5l2 (HD dup!) | .80 .82 .83 (retail .35 .35 .38) | overcast town | Y | - |
| m5l1b | AA | 3500 / - / .333 .333 .359 / - | sky/m5l2 (HD dup!) | .80 .82 .83 | overcast town | Y | - |
| m5l2b | AA | 4000 / - / .333 .333 .359 / - | sky/m5l2 (HD dup!) | .80 .82 .83 | overcast rural | - | - |
| m5l3 | AA | 15000 / - / .4 .5 .6 / - | sky/mohday2 (HD dup!) | .83 .87 .90 (retail .89 .81 .67) | clear day | Y | - |
| m6l1a | AA | 1500 / - / .2 .2 .3 / - | caulksky | = fog | snow night forest | - | - |
| m6l1c | AA | - (BSP cull key 3000; script .2 .2 .3) | caulksky | = fog | snow night forest | Y ramp | - |
| m6l2a | AA | - (script 1600 .1 .1 .2) | caulksky | = fog | snow night town | Y ramp | - |
| m6l2b | AA | 1600 / - / .1 .1 .12 / - | caulksky | = fog | snow night | Y | - |
| m6l3a | AA | - | sky/africanight + caulksky | .105 .159 .236 | snow night fortress exterior | Y | - |
| m6l3b | AA | - | sky/africanight | .105 .159 .236 | night exterior | - | - |
| m6l3c | AA | - | none | n/a | interior (no sky) | - | - |
| m6l3d | AA | - | none | n/a | interior (no sky) | Y | - |
| m6l3e | AA | - | caulksky | clear colour | snow night exterior | Y | - |
| t1l1 | SH | 5000 / - / .024 .024 .036 / 2 | sky/t1l1 + t1l1a, sky portal | .024 .031 .046 | Normandy night paradrop | Y | - |
| t1l2 | SH | 3000 / - / .06 .14 .23 / 2 | sky/t1l2 | .043 .059 .098 | night | Y | - |
| t1l3 | SH | 6000 / - / .13 .19 .27 / - | sky/t1l3 | .155 .205 .281 | blue dusk, interior-heavy | Y | - |
| t2l1 | SH | 3500 / -1500 / .6 .6 .64 / - | sky/allwhite + caulksky | 1.0 1.0 1.0 | Bastogne snow whiteout | Y | - |
| t2l2 | SH | 2750 / -150 / .324 .324 .351 / - | caulksky | = fog | snow, dim | Y | - |
| t2l3 | SH | 2500 / -1000 / .06 .06 .065 / 2 | sky/t2l3 + caulksky | .059 .060 .068 | snow night forest | - | - |
| t2l4 | SH | 3600 / -1000 / .10 .11 .15 / 2 | sky/t2l4 | .103 .111 .152 | snow night | Y | - |
| t3l1 | SH | 15000 / 500 / .03 .05 .07 / - ; skyfar 4500 | sky/t3l1 (+m5l2), sky portal | .058 .081 .090 | city night | Y | - |
| t3l2 | SH | 16000 / - / .31 .33 .35 / - ; skyfar 4000 | sky/t3l2 (+m5l2), sky portal | .603 .560 .539 | city day, dusty | Y | - |
| test_BoB_Foy | maptour pk3 | 6500 / - / .6 .6 .6 / - | sky/m5l2 (HD dup!) | .80 .82 .83 | snow overcast | - | - |
| training | AA | 13000 / - / .7 .7 .55 / - | sky/mohday2 (HD dup!) | .83 .87 .90 | clear day | - | - |

Two data findings that shape the method:
- **The original designers set `farplane_color` to the sky's horizon average.** Examples: e2l1 .176/.176/.191 vs
  horizon .176/.176/.192; e2l2 .25/.26/.28 vs .247/.259/.282; e3l4 .102 vs .102; e2l3 .31/.33/.43 vs .324/.335/.441;
  t2l3, t2l4, e3l2 and mohnightfog all agree within 0.01-0.02; and retail e3l1 sky .248/.259/.282 vs fog .25/.26/.28.
  Deriving fog colour from the sky is therefore reproducing the original authoring rule, not inventing one.
- **`maintt/zzzzzz_hd_skybox.pk3` ships byte-identical images under different sky names.** An md5 pass found:
  - one bright blue-white set used for `dday2`, `m5l2`, `ep2sky/e1l3sky` and `ep2sky/e3l1sky`
  - one set for both `mohday1` and `mohday2`
  - `nordawn` swapped from a dawn blue (.41/.41/.55) to near-white
  
  gl2 loads a `.dds` first (`tr_image.c:3092`), so only `dday2` is rescued, by the grey DDS in
  `zzzzzzzzzz_coop_hd_m3l1a.pk3`. On M5L2A, m5l1a/b, m5l2b, e1l3, e3l1, m4l0, m5l3, training, co_lobby1 and
  test_BoB_Foy, the live sky no longer matches the map's grey or warm fog colour. That mismatch is a sky
  problem, not a fog problem, and needs a decision (7.4) before those maps get profiles. This is from image averages;
  confirm with one in-game look.

---

## 4. Pilot proposal: 6 maps

Principle, from the AI coupling: **keep DIST at or above the effective native value, and author mood with bias and colour.**
Colours come from the horizon or native fog column. Grades are expressed as multipliers over the player's own grade
(expo x, contrast x, saturation x, temp +), relative to Neutral. They only become shippable once 2.2 is built; for pilot
screenshots, emulate them with client cvars (4.7).

| # | map | why this one | fog proposal (.dat) | grade proposal (x expo, x cont, x sat, + temp) |
|---|---|---|---|---|
| 1 | **m2l1** snow | Snow with a real sky, static fog (script line commented), long sightlines | `fogv1,14500,3500,0.62,0.63,0.70,1,0`: native dist and hue, fog starting at ~24% instead of the implicit 18%. Alternative if the HD sky is kept: shift toward the live horizon, .70 .71 .76 | 1.00, 1.03, 0.90, -0.05 (hue of .6 .6 .7) |
| 2 | **e1l2** desert | N.Africa; native fog = sky horizon; static | `fogv1,5000,1250,0.356,0.286,0.204,1,0`: native dist, exact horizon colour, clear first 25% | 1.02, 1.05, 0.95, +0.08 |
| 3 | **m3l1a** Omaha | Headline map; but scripted ramps (m3l1a.scr:195-202, 1268-1493, 3545-3569) and the RAMPFOG lift | **Colour-only:** `fogv1,0,0,0.63,0.63,0.62,1,0`. dist 0 leaves the map's ramps alone, and bias 0 gives an auto 18% that follows each ramp. Caveat: loading ANY profile (even dist 0) sets `coop_fogProfileLoaded` and so disables coop_rampFogLift (coopified.scr:19905); treat this pilot as grade-first and consider shipping no fog file at all | 1.00, 1.08, 0.80, -0.03 (overcast, desaturated; gentler than preset 4) |
| 4 | **m1l1** night | First mission; NO fog today, so this tests adding fog where the AI has no clamp | `fogv1,9000,2500,0.07,0.10,0.15,1,0`. Hue = africanight horizon (.105 .159 .236) x 0.65, so the fog does not glow brighter than the lit town. dist 9000 gives an AI clamp of 7452 u; confirm no engagement is longer (maptest phase 2 + `Actor_LDDebug` log) | 1.00, 1.05, 0.80, -0.12 |
| 5 | **m4l1** interior-heavy | 99 interior-named shaders; caulksky; static native fog 3100 .2 .2 .235; no script fog | `fogv1,3100,900,0.18,0.20,0.26,1,0`: native dist, a touch cooler toward the moonlight sun (38.8 62.4 88.8) | 1.00, 1.08, 0.80, -0.10 |
| 6 | **e2l3** town | Sicily dusk town; native fog = sky; distinct blue-dusk look | `fogv1,3000,0,0.324,0.335,0.441,1,0`. But FinalHouse re-fogs (`e2l3/FinalHouse.scr:664-668`, bias -256) and the keeper would fight it. Either colour-only (`fogv1,0,-256,...`; negative bias is safe because start < end) or skip the fog and pilot only the grade | 1.00, 1.05, 0.92, -0.06 |

Maps left out deliberately:
- The m5/e1l3/e3l1 group waits on the HD sky decision.
- e2l2 and M1L3c already have profiles; both use the night preset colour, which is darker and bluer than e2l2's own
  sky (.25 .26 .28), so they are worth a re-look later.
- t2l1 whiteout (negative 1500 bias is already heavy).

### 4.7 Exact steps with the existing tools (pilot)
1. Launch `G:\mohaa-gl2\PLAY-GL2.bat`. Start coop from the menu (HZM button, pick the map, Apply =
   `ui_startdmmap 2`). Log: `G:\mohaa-gl2\home\maintt\qconsole.log`. Look for `^~^~^ COOP_FOG_LOAD`.
2. **Before shots first**, before touching the editor. KP_5 reset is not native on maps with bias or cull keys (1.1).
   Pick 3 fixed views per map: spawn, one long sightline, one interior or edge. Record positions with build
   mode's spawn marker, which is written to disk (`buildmode.scr` `spawnmark`), rather than console `viewpos`.
   Use the engine screenshot command (`screenshot`/`screenshotJPEG`, ioq3 heritage; not re-verified in this fork).
3. `exec coop_mod/cfg/buildmode.cfg`, press `\` twice for FOG. Use 6/4 for bias and 7/1, 9/3, / * for colour. Leave 8/2
   (distance) alone except on m1l1. ENTER writes `G:\mohaa-gl2\home\maintt\coop_mod\save\fog_<map>.dat`.
4. For exact derived colours, hand-edit that .dat to the table value. The homepath copy wins over the pk3
   (`fogmode.scr:233-236`). Restart the mission from the menu to reload it.
5. Grade emulation for the screenshots (client console, live, no restart): `r_ppTonemap 1`, then
   `r_ppExposure`, `r_ppContrast`, `r_ppSaturation`, `r_ppTemp` = Neutral values x the table multipliers
   (e.g. m3l1a: 1.0, 1.134, 0.80, -0.03). These are archived and get reset by the daylight think on the next cgame load,
   so write down the player's own values first. Take the after shots from the same views.
6. Approval, then ship: copy each save file to `hzm-mohaa-coop-mod/coop_mod/fog/<map>.dat` (lowercase), then
   `.\build.ps1`. **Then delete the homepath `fog_<map>.dat`**, or it masks the shipped file forever. The m1l3c
   one already does.

---

## 5. Scalable method for the rest

### 5.1 What a generator can do (offline, deterministic; extend the scan into `docs/tools/`)
1. Read worldspawn (farplane, bias, colour, cull, skyfar) and every sky shader's live image (DDS-first
   precedence, pk3 load order), then average the horizon band. Emit the section 3 table as generated data.
2. List the map scripts that write `$world farplane*`, and which of them ramp.
3. Classify each map:
   - **A.** Native fog, horizon matches colour (|delta| < 0.03): no fog profile, grade only.
   - **B.** Native fog, HD sky mismatch: flag for a decision (7.4). Emit two candidate .dat files (sky-matched and
     native).
   - **C.** caulksky: colour from native fog, since the sky IS the fog. The draft only nudges bias (auto 18% ->
     20-25% of dist).
   - **D.** No runtime fog: draft `dist = max(9000, native-class default)`, colour = horizon x 0.65 at night or x 0.9
     by day, bias 25%. Mark as AI-sensitive.
   - **E.** Scripted fog: emit a colour-only draft (dist 0, bias 0) or nothing.
4. A draft grade from the fog colour's chroma and brightness: temp = clamp(0.5*(R-B)/(R+G+B), -0.12, +0.10);
   sat 0.80 at night (sun luminance < 40), 0.88 overcast (grey fog), 0.95-1.0 clear or desert; contrast 1.03-1.08.

### 5.2 What needs eyes
- Night darkness and whether the fog "glows" against lit geometry.
- Bias on interiors and on maps with LOD pop.
- Every class B and D map.
- Scripted-fog maps where the story changes the fog (m3l1a, M3L3, e2l2, e2l3, e3l3, m4l3, m6l2a, m2l2c).
- Grade saturation vs gore and readability (enemy uniforms against snow and sand).

### 5.3 Format and runtime gaps worth closing before the bulk pass (small script work, not done)
- A `fogv2` with a "keep native" sentinel (e.g. -1) for dist, bias, cull and sky. Today cull and sky are always
  overwritten (e3l1's native cull 0 becomes 1).
- captureNative should read the native bias (getter at `worldspawn.cpp:217`).
- An apply-once vs hold flag, so a profile can coexist with scripted ramps.

### 5.4 Height fog, if still wanted
Height fog can only be client-side. In `cg_view.c:6118-6124`, interpolate the colour and bias by `cg.refdef.vieworg[2]` before
filling the refdef. Leave DIST untouched so the AI is unaffected. Parameters could ride a `coop_` cvar. This is new cgame
work and is not part of the pilot.

---

## 6. Risks

1. **bug-1296 unfogged surfaces.** The live forward path already fogs blended stages per surface (0.4). The residual is
   gl1-parity exemptions. Check a propeller disc or window on e2l1 once. Do not reopen the rejected fixes
   (OPEN.md:350-356).
2. **Distant LOD pop (user deferred; OPEN.md:616-630).** Pop tracks model LOD distance (~900 u), not fog. The launch
   sets `r_uselod 0 r_lodscale 28` (`PLAY-GL2.bat:22`). Shortening DIST or pulling bias under ~1000 u puts the pop
   inside partial fog, where it is most visible. Keep bias >= 1000 u on the pilot maps and do not investigate further unasked.
3. **Fog vs AI sight.**
   - The clamp is AI sight = 0.828 x DIST (1.3). Fog is 100% at DIST, and at 0.828 x DIST it is
     (0.828D - B)/(D - B) opaque: 77% at B = 0.25D. So AI engage from inside heavy haze by design.
   - Adding fog to a no-fog map introduces a clamp that was never there (m1l1 class).
   - Raising DIST on a short-fog map (m6l1a 1500) lengthens enemy range.
   - The officer bombing envelope shrinks from 8000 to 0.7 x DIST (`officer.scr:3063-3072`).
   - Colour matters for spotting: fog near the uniforms' luminance hides silhouettes.
4. **Profile keeper vs scripted fog.**
   - A dist > 0 profile re-applies every 2 s (`fogmode.scr:286-294`), flattening scripted ramps and cinematics.
   - Any loaded profile disables m3l1a's RAMPFOG (`coopified.scr:19905`).
   - A fixed positive bias on a ramping map can reach or exceed the current distance, and the renderer then drops fog
     entirely (`tr_backend.c:1525`). Use bias 0 or negative on colour-only profiles.
5. **Performance.**
   - Forward fog is a per-fragment mix already paid on every fogged map. Adding it to the 12 unfogged maps is
     negligible, and `cull 1` removes geometry past DIST, which is a net win.
   - Raising DIST costs draw distance (m3l1a's own note: 1.16x radius).
   - The grade is one fullscreen blit either way: ACES replaces Hable, with an early return at `tr_postprocess.c:132`.
6. **MP isolation.**
   - Profiles load only from coop `main.scr:180`, keyed by coop map name. Stock dm/obj maps never run it, and
     nothing in the fog pipeline edits a stock BSP.
   - `docs/tools/check_mp_isolation.py` has no fog or grade clause (grep: no hits). A cgame grade relay must avoid
     `coop_mp*` tokens (clause 14) and must reset at CG_Init, because flags-0 cvars persist across server switches
     within a client session.
   - Existing, not introduced here: `CG_CoopDaylightThink` runs on MP maps too and rewrites `r_pp*` on its first
     frame (`cg_view.c:7226-7236`).
7. **Underwater.** The v3 pass uses `rb_viewProj`, not the fog latch (`tr_postprocess.c:1524-1525`), and runs after tone
   in `RB_HZMExtraFx` (`tr_backend.c:2276-2281`). It stacks on top of the forward fog, so a bright beach fog plus
   underwater silt double-hazes. The m3l1a plunge restore is also part of the RAMPFOG that a profile disables.
8. **Suppression and low health.** On gl2 these are cgame 2D overlays drawn after the scene
   (`cg_drawtools.cpp:3320-3336`), so they are unaffected by fog and grade. A dark night grade plus the black tunnel
   vignette compounds, so check readability at night.
9. **Sun rays** (currently off: `PLAY-GL2.bat:22`, `omconfig:4642`).
   - `RB_SunRays` runs after tone (`tr_backend.c:2285-2286`), so it is ungraded.
   - Fog is hard-off in the ray mask (`tr_shade.c` sunRaysFbo guard), so rays can shine through fog that
     hides the sun.
   - The sun disc follows `r_globalFogSky` (tr_shade.c D4 note).
   
   If rays return, heavy-fog maps need a gate.
10. **Daylight grade interaction.** `coop_daylight < 1` forces `r_ppGrade 0` and writes the sliders
    (`cg_view.c:7247-7262`). Per-map multipliers in the renderer compose on top of that correctly. The current
    daylight think does not.

---

## 7. Decisions for the user

1. **Fog strength philosophy.**
   - (a) Subtle depth: keep native DIST, bias 20-30%, colour matched to the sky. No gameplay change; most maps change little.
   - (b) Heavy atmosphere: shorter DIST and warmer or colder colours. Real gameplay change, because AI range and the
     officer envelope shrink.
   
   Recommended: (a) as the default, with (b) only on a few named maps after an AI check.
2. **Tone baseline** (prerequisite for any grade). Keep rend2 Hable + auto-exposure (today's real look), or switch
   everyone to the HZM ACES grade (`r_ppTonemap 1`, which needs the daylight-think restore fixed). Fog colours are tuned
   after this choice.
3. **Grade on for everyone by default?** Per-map multipliers on by default, with neutral multipliers on maps not yet
   tuned, or opt-in.
4. **HD skybox mismatch.** On the maps where `zzzzzz_hd_skybox.pk3` replaced a grey or warm sky with a shared bright one:
   restore the retail sky, re-author the fog to the new sky, or leave it.
5. **Player opt-out.** Grade: a non-`coop_` archived client toggle (server cannot flip it) plus a menu
   checkbox. Fog: a client "atmosphere strength" slider on `r_globalFogScale` with a floor above 0, because
   `r_globalFog 0` exposes the far cull plane. Accept that a player who thins fog sees slightly past AI range
   (PvE, so probably fine).
6. **Scripted-fog maps.** Colour-only profiles that respect the map's ramps, or profiles that own the fog and flatten
   the scripted story beats (m3l1a RAMPFOG, e2l2 cinematic, M3L3 near/far).
