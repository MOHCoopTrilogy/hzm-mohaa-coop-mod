# Visual Upgrade Plan — what is left after the upscaling

Written 2026-08-27. Synthesised from four independent surveys (already-done/rejected, how other
old-engine projects modernise, renderer capability, art direction). **Every claim below was
verified against source or the live config, not against the docs — several headline doc lines are
stale and are corrected in §5.**

Target renderer: **gl2 / rend2** (`G:\mohaa-gl2`, `cl_renderer opengl2`) — what the user plays and
tests. Unresolved split: `installer/omconfig_default.cfg` still ships `opengl1` to new players, so
gl2-only wins do not reach a fresh install until that decision is made.

---

## 1. THE THESIS

**The textures are no longer the problem. The lighting is.** Upscaling raised the resolution of a
2002 *photograph* of a surface; it did not give the surface a shape. Every world polygon in this
build is still shaded off its interpolated vertex normal against a baked lightmap, so a brick wall,
a mud bank and a sandbag all respond to light identically — flatly. `r_normalMapping` is already
`1` and has been for months, but the mod ships **zero** authored normal maps and zero specular
maps, so the path is switched on and sampling nothing. That flatness is the single loudest "this
is old" tell left, and it survives any amount of texture work because it is not a texture problem.

**The second tell is that the world has no air in it.** Modern-looking scenes read depth through
atmosphere — haze that thickens with distance, light that has a visible direction, colour that
belongs to a place. This build has all three systems written and shipped: a screen-space global
fog pass, a per-map fog authoring editor, an ACES grade with theatre presets, and a working sun
that knows each map's real direction (bug-1154 bridged it out of worldspawn, where MOHAA actually
stores it — 117 of 134 BSPs carry `sundirection`). And all three are effectively idle: fog is
authored on **2 of 65** maps, the grade preset is set to neutral, and the sun ray pass is off by a
default that predates the fix that made it work. The distilled answer to "what else?" is therefore
not *build more*. It is: **give surfaces relief, give the world air, and finish landing the things
already written.** Almost the entire top of this plan is switches and data files.

---

## 2. TOP TABLE — ranked by visible impact per hour

| # | Item | Effort | Where it hooks | Ships | Play vs screenshot |
|---|---|---|---|---|---|
| 1 | Generated normal maps + confined specular | S (tuning M) | `r_hzmGenNormals 1`, `r_hzmGenNormalStrength` | none (cvars) | **Play**, constantly |
| 2 | Sun rays back on | XS | `r_drawSunRays 1` in `PLAY-GL2.bat` | none | **Screenshot**, strong outdoors |
| 3 | Fog profiles for the other 63 maps | M (offline) | `coop_mod/fog/<map>.dat` | mod pk3 | **Both** |
| 4 | Foliage casts shadows | XS | `r_shadowCastFoliage 1` | none | Play, outdoors |
| 5 | Fix bloom threshold domain | S | `tr_backend.c` pass order / `RB_HZMBloom` | gl2 dll | Both — a shipped feature is inert |
| 6 | Fix styled-lightmap red pulse | M | rend2 lightstyle sampling | gl2 dll | **Negative value removed** |
| 7 | Shadow quality knobs | XS | `r_shadowMapSize/Filter/charShadowDist` | none | Play |
| 8 | Pick a `r_ppGrade` preset; then per-map grade | XS then S | `r_ppGrade`; `coop_` cvar bus | none; cgame | Play |
| 9 | Height fog (`animated_farplane_color`) | S | `worldspawn.cpp` cmd, script line/map | mod | Both |
| 10 | Alpha-to-coverage → MSAA returns | M | `tr_fbo.c:284-295` | gl2 dll | Play, constant |
| 11 | `r_coopSunPublish 1` | XS | cvar | none | Play, completeness |
| 12 | Render-scale supersampling | S–M | new `r_renderScale` on the FBO chain | gl2 dll | Play |
| 13 | Soft particles | M–L | depth blit + FX fragment path | gl2 dll | Play, FX-heavy moments |
| 14 | Cubemap reflections (revisit) | S to enable | `r_cubeMapping 1`, third in the chain | none | Marginal on matte art |

---

## 3. THE ITEMS

### 1. Generated normal maps — the answer to flat lighting
**What.** `r_hzmGenNormals` Sobel-generates a normal map per world texture at load. Mode 1 =
allow-list (`r_hzmGenNormalInclude "textures/"`, which deliberately excludes `models/` because
`RB_SkelMesh` writes no tangents). Height field is box-downsampled to `r_hzmGenNormalMaxSize 512`
*before* the Sobel — that cap is the noise filter, the VRAM budget and the load-time budget at
once, and it is what stops 2002 dither and ESRGAN speckle sparkling through the mip chain.
**Why it lifts the look.** Surfaces gain relief that responds to the real per-map sun
(`r_sunlightMode 1` + the bug-1154 bridge) and to the muzzle-flash and explosion dlights that
already ship. Those dlights currently just brighten; with normals they *reveal*.
**Hooks.** `renderergl2/tr_init.c:1586-1642`, `tr_shade.c:932-951`, `tr_image.c:2582-2632`.
**Chain, verified at `tr_shade.c:948`:** `r_hzmSpecular` is gated on `r_hzmGenNormals`, and the
cubemap term multiplies specular. Correct order is **normals → specular ~0.04 → cubemaps**;
enabling cubemaps alone renders literally nothing.
**Effort.** S to try, M to tune. **Assets.** None — the generator *is* the asset path, zero pak
bytes. **Ships.** Cvars only; applies on next map load, no `vid_restart` (which crashes gl2).
**Risk.** Real and documented by its own author: the Sobel produces strongest relief where the
texture is *darkest*, which on hand-painted art is exactly where the artist painted dirt and
contact shadow — relief where the art intends flat. Start `Strength 0.3-0.4`, raise `Blur`, A/B in
play (Strength is live-tunable to 0 with no reload). bug-1225 already fixed the DXT-sibling decode,
so you will not get relief on some textures of a wall and not others. **This needs a real playtest,
not a flag flip** — but it is the highest ceiling left in the build.

### 2. Sun rays — one cvar, and the reason they were off is gone
**What.** gl2's own `RB_SunRays` (`tr_postprocess.c:455`, dispatched `tr_backend.c:2252`), gated
solely on `r_drawSunRays`, default `0`.
**Why the old rejection no longer holds.** The user's 08-02 verdict was *"they rendered on maps
with no sun at all… obnoxious permanent glare"* — **flagged as previously rejected, and I recommend
revisiting anyway.** Two things changed: bug-1169 added a real sun-luminance gate (returns early
below 48; m1l1's moonlight `suncolor "10 15 30"` luminances to ~15), and bug-1154 gave it real
per-map sun direction. Also unresolved: bug-1796 records `build.ps1` shipping only the gl1 dll for
a period, so the fixed gl2 renderer may never have been live when the verdict was formed. Treat as
a cheap re-test, present it to the user as such, and accept a second "no" gracefully.
**Hooks.** `CVAR_LATCH` → set in `PLAY-GL2.bat`, never a menu apply (bug-1181).
**Effort.** XS. **Assets.** None (`scripts/coop_sunflare.shader` already gives them art).
**Risk.** Low; self-limits on view angle and occlusion queries. Watch one thing: it runs *after*
tonemap, so rays read hotter/ungraded — eyeball before deciding to move the call. Intensity is
hardcoded `1.0`; a tuning cvar is ~5 lines.

### 3. Fog profiles for the other 63 maps
**What.** `coop_mod/fogmode.scr` (473 lines, hardened, numpad editor, late re-asserts that beat the
map's own re-fogging) reads `coop_mod/fog/<map>.dat` — format `fogv1,dist,bias,r,g,b,cull,sky`.
Exactly **two** exist: `e2l2.dat`, `m1l3c.dat`. 65 maps are coop-integrated.
**Why.** Atmospheric perspective is the classic "film still" cue and it is missing on 63 maps.
**Pipeline.** Offline: read each map's sky shader faces, average the colour, emit a `.dat` whose
fog colour matches that sky. Fixes atmosphere and sky/scene mismatch in one pass.
**⚠️ Hard constraint, verified in five places.** `farplane_distance` clamps AI sight range to
`world->farplane_distance * 0.828f` (`fgame/actor.cpp:4318, 8988, 9000-9005, 10279`,
`fgame/actorenemy.cpp:51, 546`). **Author mood with BIAS and COLOUR; keep DIST at or above the
map's native value.** `officer.scr` also scales off `$world.farplane`.
**Effort.** M (generator + spot-checks). **Assets.** 63 tiny data files in the mod pk3. **Ships.**
Mod pk3 only, zero engine risk. **Risk.** Low, if the DIST rule is honoured.

### 4. `r_shadowCastFoliage 1`
Alpha-tested world cutouts — trees, fences, camo nets — currently cast **nothing** into the
cascades, so trees over open ground have no shadow at all. Implemented at `tr_backend.c:770`, off
only as "separate visual risk". XS, no assets, no restart. Best effort-to-effect ratio of the pure
switches. Risk: may interact with the bug-1164 thin-geometry shadow acne — check e2l1.

### 5. Bloom threshold domain (bug-1149)
`RB_HZMBloom` runs at `tr_backend.c:2204`, *before* `RB_ToneMap` at `:2215`, so it thresholds the
**pre-tone HDR** buffer while gl1's shipped threshold value was tuned against a **display-referred
LDR** backbuffer. Same chain position, different numeric domain — the shipped `0.349570` is close
to a no-op. Bloom is nominally on and largely not doing its job. Fix: remap the threshold into HDR
domain, or move the pass after tone mapping. **S, gl2 dll.** Any "visual quality pass" that skips
this is tuning a dead knob.

### 6. Styled-lightmap red pulse (bug-1331)
`OPEN.md` calls it the top gl2 visual defect and the user bisect confirms it (gl1 clean, gl2
blinks). e2l1 bridge rails, e2l2 panels: rend2 is not sampling the lightstyle ramp and generates
its own red oscillation. **A surface that visibly blinks red costs more perceived quality than
several items above buy.** M, gl2 dll. Cheap first attempt already identified and never tried:
upstream cherry-picks `dfd9bd23`, `7edc1028`, `1fd5c731`.

### 7. Shadow quality knobs — all implemented, left conservative
`r_shadowMapSize 1024 → 2048` (cheapest quality lever on the shipped character CSM),
`r_shadowFilter 1 → 2` (wider PCF), `r_shadowBlur 0` (unused pass), `r_charShadowDist 512` (raise —
shadows currently vanish close in). XS each. Never set `r_charShadowCascade 3` — that is the cached
whole-map cascade and gives frozen baked silhouettes. Leave `r_charLightShadow 0`: characters are
excluded from the depth prepass, so the shadowmask at their pixels describes the geometry *behind*
them and every sunlit actor self-darkens (bug-1224).

### 8. Colour grade — free preset now, per-map later
`r_ppGrade 0` = manual sliders, i.e. the Normandy/Ardennes/bleach presets you built are switched to
neutral. Trying one is free. Beyond that, per-map grading was written off in `fogmode.scr:20-21`
because `r_pp*` cvars are client `CVAR_ARCHIVE` and would stomp player settings — **but
`CG_IsVariableAllowed` (`cg_servercmds_filter.cpp:165-175`) passes any `coop_`-prefixed cvar
unconditionally.** So: script sets `coop_gradeSat/Temp/Contrast` per map → cgame folds them
**multiplicatively over** the player's own values before the tonemap blit. Multiplying rather than
overwriting answers the original objection exactly — nothing is stomped, nothing needs restoring.
~30 lines cgame + a script table. S.

### 9. Height fog — the most "modern" atmospheric read available
`animated_farplane_color <colorStart> <colorEnd> <ZStart> <ZEnd>` and `animated_farplane_bias` are
declared at `fgame/worldspawn.cpp:146, 210, 246` with real state at `:592-603`, and nothing uses
them. Valley mist and low-ground haze, one script line per map. S. Pairs with item 3.

### 10. Alpha-to-coverage, then MSAA returns
MSAA is off because gl2's multisample resolve haloes alpha-tested cutouts in white (bug-1298; 131
of 131 tree/foliage shaders use `alphaFunc GE128`). FXAA is covering, and FXAA is a blur filter on a
game whose look is thin geometry — rails, wires, branches, rifle silhouettes. `GL_SAMPLE_ALPHA_TO_COVERAGE`
appears **nowhere** in either renderer; fix site is the multisampled render FBO at
`tr_fbo.c:284-295`. Correct cvar under gl2 is `r_ext_framebuffer_multisample`, not
`r_ext_multisample`. **Do not just flip it** — that mistake has been made twice (bug-1997). But one
honest caveat: bug-1298 was bisected *before* bug-1300 landed the four alphaGen distance-fade modes,
and nobody has retested since. A single launch at `r_ext_framebuffer_multisample 8` settles whether
the M-effort fix is even needed. Do that first.

### 11. `r_coopSunPublish 1`
Publishes `r_coopSunAz/El/Valid` from the real sun so the Phase-A blob decal stops running at a
hardcoded 45/45 on every map. Only matters where real cascade shadows do not reach (past
`r_charShadowDist`), so it is completeness, not a headline. XS.

### 12. Render-scale supersampling
Absent from the tree (`r_imageUpsample` is *texture* upsampling, a different thing). Render the
scene FBO at 1.25-1.5× and let the existing final blit downsample. A 2002 game on a modern GPU has
the headroom, the FBO infrastructure exists, and Quake3e's `r_ext_supersample` is a reference shape.
Fixes the texture shimmer that no spatial AA can. Pairs with `r_ppSharpen`. S–M, gl2 dll.
Prefer this over adding SMAA: SMAA is the better *edge* filter, but supersampling fixes edges and
shimmer both, and you can only justify one new AA path.

### 13. Soft particles
Zero hits for `softParticle` in either renderer. Hard-edged sprite/geometry intersections are the
most recognisable old-engine tell in a mod that is wall-to-wall smoke, dust and explosions.
Feasible but not trivial: `tr.renderDepthImage` is bound as the render FBO's own depth attachment,
so sampling it during the transparent pass is a feedback loop. The in-tree pattern is the depth
blit into `tr.hdrDepthFbo` that `RB_HZMDof`/`RB_HZMSsao` already do (`tr_postprocess.c:1218, 1372`)
— but those are post passes, and this needs depth bound *during* the forward transparent batch.
Shape: blit depth after opaque → bind for transparents → depth-fade term in the sprite fragment
path, allow-listed so HUD sprites are untouched. M–L, gl2 dll, gate behind `r_softParticles 0`.
Genuinely modernising; do it after 1-6.

### 14. Cubemaps — revisit only as step three
**Previously parked deliberately**: *"the renderer support is finished and working (auto probe
placement from info_pathnode, bake-order fix, bug-1237), but on MOHAA's matte outdoor content the
payoff did not justify the load-time and per-frame cost."* That reasoning stands on its own terms,
**but it was formed with specular at zero**, which means the parked test rendered nothing at all
(`lightall_fp.glsl:489-517` — cubemap contribution multiplies `u_SpecularScale`, left at 0 unless
the gen-normal branch fires). Worth exactly one re-test *after* item 1 lands, at
`r_baseGloss ~0.45`, full restart never `vid_restart`. If it is still marginal on matte WW2 art,
that is a real answer and it stays parked.

---

## 4. ALREADY IN THE ENGINE, JUST SWITCHED OFF — the cheapest category

Copy-paste block. No code, no assets, no new binaries. Live cvars unless noted.

```
r_shadowCastFoliage   1      // foliage/fences/nets cast into the cascades  (§4)
r_coopSunPublish      1      // blob decals follow the real sun, not 45/45  (§11)
r_shadowMapSize       2048   // cheapest quality lever on the shipped CSM   (§7)
r_shadowFilter        2      // wider PCF
r_charShadowDist      1024   // real character shadows reach further
r_hzmGenNormals       1      // surface relief — START HERE                 (§1)
r_hzmGenNormalStrength 0.35  // live-tunable; 0 collapses cleanly, no reload
r_hzmSpecular         0.04   // dielectric F0; INERT without the line above
r_ppGrade             1      // a shipped preset instead of neutral         (§8)
// PLAY-GL2.bat only — CVAR_LATCH, never a menu apply (bug-1181):
r_drawSunRays         1                                                  // (§2)
```

Also worth one measurement each, not a blanket enable: `r_dlightMode 1` (per-pixel dlights; mode 2
is shadowed dlight cubemaps, `R_RenderDlightCubemaps` already dispatched at `tr_scene.c:620` —
note iortcw marks the analogous shadowed path *broken* upstream, so test under coop load, not in an
empty map); `r_globalFogPreTone 1` (pinned to 0 "until gl1's ACES grade is ported" — **that grade
IS now ported**, so the pin is stale); `r_mapOverBrightBits 1` (engine default is 2 — the world may
be rendering one overbright stop dark by drift, unverified); `r_imageUpsample`; `r_ppMotionBlur`
(built, never tuned — but see §5, ship it off).

**⚠️ TRAPS T7: changing a default is not enough.** `omconfig.cfg` execs *after* `coop_defaults.cfg`,
so an archived value wins forever. Edit the live config too, **with the game closed** — the engine
rewrites that file from memory on exit. This has bitten three times (bug-1629/1699, bug-1990).

---

## 5. WHAT NOT TO DO

**Rejected on evidence — do not re-litigate.** `r_specularMapping` (MOHAA ships 39 ordinary
*diffuse* textures named `*_s`; rend2's auto-probe binds them as specular data, bug-1155).
`r_baseSpecular` (4% white sheen on every lit surface, sweeps as you pan). `r_mergeLightmaps`
(atlas coords wrong on MOHAA terrain — black/streaky). `r_pbr` and `r_parallaxMapping` (no authored
material set; parallax needs height in the normal alpha, and on generated normals it amplifies the
noise). `r_charLightShadow` (self-darkening sunlit actors, bug-1224). Fogging non-depth-writing
surfaces under gl2 — three fixes evaluated and rejected, read the `OPEN.md:332-343` table before
re-proposing. Disabling `r_ext_compressed_textures` (~1400 stock-.dds-only textures vanish).

**Rejected by the user.** 3D grass — *"completely remove 3d grass its no good"*, and it is
gl1-only anyway, so `r_grass` in the config is a no-op on the renderer you run. Frost-on-lens
(removed 08-07). Gore intensity beyond round 3 (*"way too much"*). Film grain ships off. Keep
chromatic aberration scoped to injury only, never an always-on look — it is an accessibility issue
for astigmatism and migraine, and full-screen motion blur is the effect players disable first.

**Wrong scale for this team.** New renderer backend, Vulkan, TAA (needs motion vectors and history
buffers you do not have, and it blurs the hand-painted art you deliberately sharpened), lightmap
re-bake (Quake II Enhanced's biggest win, but it needs `.map` sources — you have 134 compiled BSPs
and no sources; the `cmpatch` pipeline edits collision, not lightmaps). ET:Legacy spent a decade
failing to make an XreaL-derived renderer the default; that is the trap.

**More upscaling.** RealRTCW's own note is the caution: *"no more ugly upscales with artifacts…
it all looks as vanilla but slightly sharper."* Remaining texture work is consistency auditing,
not more pixels. Never ESRGAN a bitmap font or UI chrome (bugs 157, 247, 1129, 1185). Sky sources
are 512²/face and soft (bug-1295) — if upscaled, they must be done as a **set** or cube-edge seams
drift, and ESRGAN mottles smooth cloud gradients; the user's condition was *"unless there is risk
of it looking worse"*, and here there genuinely is.

**Leave alone deliberately.** The red bullet-hole decals (`bug-gl2-decal-red-dds`) — mechanism
unexplained, guessing risks 2,370 working DDS or the whole mark system. Distant-object LOD pop
under fog — user explicitly deferred, do not open a broad investigation unasked.

**Stale doc lines that will mislead the next session — fix these:** `OPEN.md:388` and
`FEATURES.md:435` claim seven gl1 post-FX have no gl2 port (all seven exist, dispatched
`tr_backend.c:2143-2252`). `FEATURES.md:432` calls the gl2 migration planned (it is the live
renderer). `DECISIONS.md:139,179` call gl2 a sandbox and say real shadow mapping was deferred (both
shipped). `coop_defaults.cfg:67 r_ppSunShafts 1` and `:31 r_grass 0` are dead cvar names under gl2 —
anyone reading the config would reasonably believe god rays are already on. They are not.

**Two constraints on any of the above.** `renderer_opengl2.dll` has **zero** `.bak` rollbacks — the
most-churned renderer has no undo; make one before the first gl2 build. And protocol-adjacent work
ships as a set (exe + cgame + game + renderer); `build.ps1` stages only two of four, the rest are
manual copies.
