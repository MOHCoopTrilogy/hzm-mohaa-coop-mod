# Engine Modernization Survey — 2026-08-19

Scope: value-per-effort ranking of engine work for the HZM coop fork (`openmohaa-hzm`, branch
`hzm-coop-working` @ `64bd613d`). Grounding: fork branch point is upstream `a72bc153`
(2025-08-03); upstream was fetched today — tip is `docs: clarify contribution guidelines`
(2026-04-24) and the GitHub API confirms **zero commits since**, so the delta is exactly
**311 upstream commits** vs **42 local commits**. All file:line cites checked against the working
tree today. Effort scale: S = hours–1 day, M = days, L = week+ for a 2-person hobby team.

---

## TOP-10 SHORTLIST (ranked by value ÷ effort)

| # | Item | Effort | Risk | One-line payoff |
|---|------|--------|------|-----------------|
| 1 | Upstream stability cherry-pick batch (~15 commits, hashes below) | S–M | Low | Free crash fixes + coop fixes the fork has been debugging by hand |
| 2 | Enable leaning (engine already has it end-to-end) | S | Low | SH 2.0 tactical lean for a WW2 coop game — binds + menu only |
| 3 | Defaults pass: anisotropy 2→8/16, com_maxfps 85→250, pmove_fixed decision | S | Low | Visible texture + input-feel win from three cvar defaults |
| 4 | Damage-direction HUD indicator | S–M | Low | Answers "who's shooting me" — the #1 missing PvE feel feature |
| 5 | Micro-feel bundle: hit-stop on kill, spread-driven crosshair, tracer glow-up | S each | Low | Cgame-only polish stacking on shipped hitmarker/headshot hooks |
| 6 | gl2 styled-lightmap fix: cherry-pick upstream `dfd9bd23`+`7edc1028`, A/B on bug-1331 bridge | M | Low (isolated build) | Kills the "pulses red" class; keeps the gl2 testbed viable |
| 7 | Per-pixel dynamic lights on gl1 (Q3e `r_dlightMode` concept port) | M–L | Med | Muzzle flashes/explosions actually light walls — biggest remaining world-visual win |
| 8 | One-time upstream sync sprint (merge/rebase to the 2026-04-24 tip) | L | Med–High | Absorbs all 311 commits incl. bot system + netcode; gets ahead of the corepp/CMake conflict wall |
| 9 | First-person body awareness (own legs in 1P) | M | Med | Immersion; reuses the shipped 3P/ADS world-model infrastructure |
| 10 | LUT color grading + per-map mood presets in the gl1 post stack | S | Low | Per-theater looks (Normandy/N.Africa/Winter) on the existing tonemap pass |

**Not recommended:** Vulkan/modern-backend rewrite (Q3e-vk / CNQ3-class, XL, no coop value),
ET:Legacy renderer2/XreaL port (deprecated even there), switching the mod's default renderer to
gl2 this year (see §3 verdict).

---

## 1. Upstream OpenMOHAA (openmoh/openmohaa) — what the fork lacks

Branch point `a72bc153` = 2025-08-03. Upstream landed 311 commits through 2026-04-24, then went
quiet (verified via fetch + API today). Diffstat concentration: **fgame 21.6%**, renderergl2 6.9%,
client 5.0%, corepp 5.0%, cgame 4.1%, renderergl1 4.1%, qcommon 3.2%, server 1.8%.

### 1a. Cherry-pick batch (Rank #1) — hashes verified in local refs

Crash / memory safety (the fork hunts exactly this class by hand — cf. m1l2a crash hunt):
- `3f83b4b3` buffer overflow in `CM_EdgePlaneNum` (#895) — collision-map heap overflow
- `e7bd3c22` access violation in `Actor::Think_MachineGunner_TurretGun` (#896) — MG-gunner AI, the mod uses these heavily
- `dd1e7469` script array freed during evaluation (#904) — script-VM crash
- `26816593` skeletor NaN/negative time (#871) — animation-time corruption
- plus: `Fix access violation in angles_pointat` (2025-08-16), voteUpload save crash (2025-12-15)

Coop-relevant gameplay:
- `5a430cfd` **Allow Actor to think with no player in multiplayer** — directly serves the fork's standing "dedicated/listen parity" rule (AI freezing with no players)
- `25b336eb` objective text printed to **all** player screens (#901) — multiplayer objective UX
- `7b357cdf` chat text event received only the last word (#882)
- `b839d55a` spectate-immediately-after-death misbehavior
- `b1a18b66` **commands executed twice when the server is also the client** — listen server, the mod's primary mode
- `48febb12` binoculars for players on AA maps
- squad-formation fixes (2026-01-26, disguise/radius/dead-sentient), ScriptDoor completion (#893), damage-clamping fix (2026-04-07), door reopen-from-blocked-side cvar, stand-on-player's-head cvar (2026-04-12)

Netcode:
- `7584af97` properly check needed deltas when writing player state
- `5604a1f7` suppress animation time delta only when ≈ frame step (#860) — smoother remote animation
- decimal packing on explicitly-rounded values (2025-12-01); switchable network-message profiling (nice debug tool)

Renderer / client:
- `e7c66cfb` MAX_RENDER_COMMANDS ×2 + drop warning — relevant: this fork pushes far more render commands than stock (post-FX + HUD systems)
- `a40b9104` shadows drawn only in-frustum below a distance — perf for the shipped decal shadows
- `96931127` crosshair centering at hi-res UI scaling (#908) — ultrawide relevance
- `69d2236d` reconnect command fixed after disconnect (#883)
- gl2 batch: map-change handling, terrain-normal format, `R_Init` from `GetRefAPI` (2025-10-20); greyscale as backend post + DDS fallback (2025-11-01); `97ae04ef` gl1 AGEN_WAVEFORM enum fix; `dfd9bd23` gl2 tr_shader surface*/alphagen rework (210 lines); `7edc1028` DCL file paired with large-lightmap BSP; `1fd5c731` `_sml` suffix handling (the fork's cmpatch system loads `_sml.bsp` — audit interaction); `8eb3f66b` farplane-cull-only-for-portal-sky option (SH 2.0 behavior)

Bots (potential coop AI filler / test drivers): named bots, behavior variables, spawn delay,
no-bot-alloc in SP, exclusion from votes. Note upstream **renamed** `sv_botxname`→`g_botx_name`
and `bot_manualmove`→`g_bot_manualmove` — breaking if picked partially.

How: `git cherry-pick` onto a branch of the isolated build first; most are small and land clean
because the fork's 42 commits sit in different functions. Expect manual conflict work only in
`player.cpp` / `actor.cpp` / `weapturret.cpp` (fork's hottest files, also upstream-touched).

### 1b. Full sync sprint (Rank #8)

Everything above plus ~280 commits of build, packaging (upstream now has an NSIS Windows
installer — relevant to the parked Inno installer plan), XDG paths, PVR images, LTO, gamespy auth
fixes, parser fixes (`end` reserved keyword, comma-separated args). **Hazards that make this L:**
upstream moved all C++ core classes to `code/corepp/` (2025-08-24), reimplemented CMake from
upstream ioq3 (#781), reorganized `misc/`, renamed binaries ("Remove architecture from binary
filenames", `USE_ARCHLESS_FILENAMES`) — the deploy contract of `build.ps1` (cgame.dll / game.dll /
renderer_opengl1.dll names and .cmake output paths) must be re-audited after merge. Strategy:
do it once, soon — upstream is quiet since April (stable target), and every fork commit added
before syncing raises the price. Keep the `*_bak` binary rollback convention; full trilogy
maptest afterward.

---

## 2. gl1-path graphical upgrades

**Inventory first — the fork's gl1 is already far past stock.** `renderergl1/tr_postprocess_gl1.c`
implements an FBO+GLSL post pipeline **on the gl1 path** (proc pointers loaded in `sdl_glimp.c`;
copy backbuffer → shader passes → draw back, engine glState-safe): bloom, SSAO (half-res,
soft-bias, blurred), DoF, ACES tonemap + color-grade **presets** (exposure/contrast/sat/temp
"war-film looks", `r_ppGrade`), FXAA, sharpen, low-health, suppression, heat haze, raindrops,
god rays. Anisotropy exists (`r_ext_texture_filter_anisotropic`, `tr_init.c:1694`). Permanent
marks (`tr_marks_permanent.c`), gore UV-stamping (`tr_gore.c`), grass (`tr_grass_gl1.c`) are
custom already. So the classic idTech3 upgrade list is mostly **done**; what genuinely remains:

| Upgrade | What / why | Effort | Risk | Reference |
|---|---|---|---|---|
| **Per-pixel dynamic lights** (Rank #7) | MOHAA gl1 dlights are vertex-added blobs (`tr_light.c`); per-pixel projection makes muzzle flashes, explosions and the e2l1 alarm lights actually shape interiors. Night/dusk WW2 maps gain the most. | M–L (~600–1000 new LOC; tag lit surfaces, extra lit pass reusing the already-loaded GLSL infra) | Med — touches world drawing; gate behind cvar, A/B with the existing harness | Quake3e `r_dlightMode 1/2` ("high-quality per-pixel dynamic lighting", GL impl via ARB programs in `code/renderer/tr_arb.c`; also in its Vulkan backend). Port the concept, not the code. |
| **Anisotropy default** (in Rank #3) | `r_ext_max_anisotropy` defaults to **2** (`tr_init.c:1376`). Ground/trench textures at grazing angles are where WW2 maps live. 8–16 is free on any GPU since ~2010. | S (one default + cfg) | None | ioquake3/Q3e both default higher; hardware-clamped already (`tr_image.c:688`) |
| **LUT color grading** (Rank #10) | Replace/augment the parametric grade presets with 3D-LUT (Hald CLUT .tga per theater); artists can grade in Photoshop. Per-map mood: Normandy overcast, N.Africa heat, Ardennes cold. | S (~100 LOC in the tonemap pass + LUT loader) | Low | Standard technique; slots into `TONEMAP_FS` (`tr_postprocess_gl1.c:280`) |
| **Atmospheric weather sheets** | Layered rain/snow with wind gusts beyond MOHAA's native emitter rain (which the mod's dynamic-weather v2.1 already drives). | M (~1.1k LOC port) | Low (cgame-only) | ET:Legacy / ET SDK `src/cgame/cg_atmospheric.c` — self-contained, renderer-agnostic polys |
| Bloom polish (lens-dirt mask, streaks) | Cheap character on top of working bloom | S | Low | Extend `BRIGHT_FS`/`ADD_FS` chain |
| Decal system | Already strong (permanent marks + gore stamps + terrain marks) | — | — | No action |

cnq3 (mightycow/cnq3) is the cautionary reference, not a porting source: it modernized by
**rewriting backends** (GL3/D3D11-class work) — exactly the scale a 2-person team should not buy.

---

## 3. gl2 path — the two defects, and the parity verdict

**Current truth (differs from the stale "paused" framing):** a July-2026 campaign shipped ~20 gl2
fixes on the isolated `G:\mohaa-gl2` build (global fog post-pass, rgbGen black-artifacts, foliage
depth-prepass, HUD compass/segments, red decals via the `R_GetLightingForDecal` stub,
MAX_POLYS 600→131072, autosprite trees, grid-lighting parent-entity fix) and a 54-map A/B sweep
reached near-parity. `docs/OPEN.md §gl2` is the live ledger. The two briefed defects map to:

### Styled-lightmap surfaces pulse red — bug-1331
User bisect 2026-08-04: **gl1 clean, gl2 blinks** — a gl2 renderer defect in styled-lightmap
handling (bridge rails on e2l1, panels on e2l2 — all lightmaps baked against a lightstyle index).
The mod worked around it script-side (style 1 → static white ramp). Renderer fix path:
1. Cherry-pick upstream `dfd9bd23` (gl2 `tr_shader.c` surface*/alphagen rework, 210 lines,
   2026-02-18) + `7edc1028` (DCL paired with large-lightmap BSP) + `1fd5c731` (`_sml`) — all landed
   **after** the fork branched, all plausibly touch this path. Test on the bug-1331 bridge. Cost:
   an afternoon on the isolated build with the existing A/B harness.
2. If not fixed: instrument the styled-surface color chain gl1-vs-gl2. Suspect area is gl2's
   internal-lightmap tcMod-transform path (`renderergl2/tr_shader.c:3876` — "may be used by q3map2
   lightstyles") interacting with the lightstyle color table the cgame maintains
   (`cg_lightstyles.cpp`, `svc_lightstyle`). Effort M with the harness; the probe tooling
   (SKELPIX/A-B diff) from July still exists.

### Distant objects pop through fog — bug-1296 (residual)
The dominant cause is **already fixed** (sky-exemption epsilon 1e-5→1e-7; nonlinear window depth
was exempting a ~5500-unit slab of real geometry from fog). What remains is **structural**: gl2
fogs in screen space from the depth buffer, so **non-depth-writing surfaces (~13.5% of shader
defs — propeller discs, glass, FX) can never be fogged**. OPEN.md records three evaluated-and-
rejected fixes (make them write depth → breaks transparency sorting; stencil is-sky mask → wrong
distance + no gl2 FBO has stencil; port gl1's per-stage forward fog → double-fogs every blended
stage and mixes color spaces). The honest options: (a) accept the residual class (current
decision), (b) per-pixel "already-fogged" mark = the expensive stencil attachment (L), or
(c) a narrow whitelist forward-fogging only the worst offender shaders (S–M, partial). ioq3's
opengl2 (the gl2 base) has the same class of problem; upstream OpenMOHAA has no open gl2 issues
because their gl2 simply gets little use — no rescue is coming from upstream here.

### Verdict: parity is not worth chasing as a default-switch goal now
gl1+post-FX **is** the shipped product: 19 rollback baks for renderer_opengl1.dll vs **zero** for
renderer_opengl2.dll (OPEN.md), `coop_defaults.cfg` ships `r_ppSSAO 1` which black-screens gl2
(bug-1211) until re-guarded, bloom thresholds live in different numeric domains (bug-1149), and 7
gl1 post effects have no gl2 port. gl2's real carrots (HDR targets, sun-cascade character
shadows, per-pixel light) don't outweigh re-stabilizing ~10 open items across 54 maps. **Keep gl2
as the isolated testbed, absorb upstream gl2 cherry-picks cheaply (Rank #6), and revisit the
switch only after styled-lightmap + bloom-domain + menu Z_TagMalloc spam are closed.**

---

## 4. Combat-feel tech

| Feature | Status in fork | What to build | Effort | Risk | Reference |
|---|---|---|---|---|---|
| **Damage-direction indicator** (Rank #4) | Missing (no cgame code found) | HUD arc segments around crosshair pointing at attacker; server knows attacker origin, client has view yaw; `ps.damage_angles` already exists (`q_shared.h:1932`) for view-kick — add attacker-yaw via servercmd or piggyback the pain event. Fade 1.5s, stack up to 4. | S–M | Low | Standard modern-shooter HUD; RTCW/ET only kick the view. Build natively. |
| **Hit-stop / impact frames** (Rank #5) | Missing | On confirmed kill (hook exists — headshot sound already hooks `ArmorDamage`): 40–70 ms viewmodel anim hold + 0.3° FOV punch; optionally stronger for melee/bash. Client-side only — do NOT touch server time. | S | Low | Fighting-game technique; no canonical idTech3 impl. Cgame-only. |
| **Dynamic crosshair** (Rank #5) | Partially — "true-aim crosshair" shipped | Spread-driven expansion from the weapon's live accuracy (server-side `fAccuracy`/spread; predict client-side from weapon state + movement, matching server formula). | S | Low | OSP/CPMA-style crosshair scaling; MOHAA spread model is server-authoritative so mirror the formula. |
| **Tracer glow-up** (Rank #5) | Engine has a tracer pool (`cg_parsemsg.cpp`, `MAX_BULLET_TRACERS 32`) | Lit additive streak quads, thickness/alpha by distance, brighter for MG42/vehicle fire; consider raising the 32-slot pool for MG-heavy fights (same class as the MAX_SOUNDS/entity-pool raises already done). | S | Low | Compare Q3e railtrail/beam styling; mostly art + one draw func. |
| **Footstep/impact materials** | Native — MOHAA surface types drive footsteps/impacts; upstream `#872` (`26816593`-adjacent, effectNum −1 surface deduction) is in the cherry-pick batch | Nothing structural. Optional: louder enemy-footstep mix via the shipped audio-occlusion system. | — | — | Native system |
| **Penetration / wallbang** | Native `bulletthrough{wood,metal,any}` + the fork's own `coop_smgPenetrate` chance layer (`weaputils.cpp:2372-2380`, cap 5 layers) | Polish only: per-material exit puff + damage falloff per layer. | S | Low | Already home-grown |
| **First-person body awareness** (Rank #9) | Missing; strong adjacent infra (3P freecam, shoulder ADS, `CG_AdsForceFirstPerson` single-decider, surface-hide know-how from helmet/gear work) | Draw own world model in 1P with head+arms surfaces hidden, clip near-plane carefully; disable during ADS first iteration. | M | Med (view clipping, anim mismatch, shadow interplay) | No good idTech3 reference — modern-shooter technique; prototype behind `cg_showBody`. |
| **Leaning** (Rank #2) | **Engine-complete**: `+leanleft/+leanright` client commands (`cl_input.cpp:1348-1351`), MP lean rules incl. lean-while-moving flag (`player.cpp:4223-4243`; SP-blocked by design), lean state networked (SH 2.0 feature OpenMOHAA implements) | Binds in default cfg + two lines in the settings menu + one coop playtest (3P lean anim on other clients, DBNO interaction). | S | Low | Already in-engine — highest feel-per-effort item in this table. |

---

## 5. Modern conveniences

| Item | Status | Action | Effort |
|---|---|---|---|
| **Raw mouse input** | **Done** — SDL relative mouse mode (`sdl_input.c:361`, `in_mouse`); no DirectInput legacy path in play | None. Optionally surface "raw input" label in the options menu. | — |
| **High-FPS physics decoupling** (Rank #3) | Better than expected: `pmove_fixed`/`pmove_msec` exist in `pmove_t` (`bg_public.h:327`) **and are honored** (`bg_pmove.cpp:1530-1532` msec clamp), so the Q3 125-fps class of integration drift is already cappable. `com_maxfps` defaults to **85** (`common.c:1910`); `com_maxfpsUnfocused/Minimized` exist. | Bump default `com_maxfps` (250), decide a `pmove_msec` default (8) and playtest sprint/stamina timing (cgame/fgame-timed features) at 60 vs 250 fps with the maptest harness. | S (defaults) + S (verification) |
| **Ultrawide / FOV** | Menus verified centered/pillarboxed at 2560×1080; @3x font experiment failed and was rolled back (keep stock fonts) | Cherry-pick `96931127` (crosshair centering at hi-res UI scaling). Audit that `cg_fov` scales as horizontal+ on 21:9 (weapon viewmodel FOV is separately tuned by the ADS suite — retest after any FOV change). | S–M |
| **Audio HRTF / occlusion** | **Shipped** — HRTF, occlusion lowpass, reverb, distance gun tails (snd_openal_new.cpp work) | Optional later: per-zone EFX reverb presets (interior/trench/street) — M, low priority given what's live. | — |
| Gamepad | Upstream mapped SDL gamepad buttons to keys (2025-08-05) — comes free with the sync sprint | None now | — |

---

## Reference index
- Upstream: github.com/openmoh/openmohaa (fetched today; all hashes above resolvable in local refs)
- Quake3e: github.com/ec-/Quake3e — per-pixel dlights (`r_dlightMode`), bloom, `r_hdr`, raw input, aniso (README verified today)
- ET:Legacy: github.com/etlegacy/etlegacy — `src/cgame/cg_atmospheric.c` weather; Legacy-mod hitsounds
- ioquake3 opengl2: the direct ancestor of `code/renderergl2` (tr_fbo/tr_dsa/glsl layout)
- cnq3: github.com/mightycow/cnq3 — scale reference for backend rewrites (anti-recommendation)
- Local ground truth: `renderergl1/tr_postprocess_gl1.c` (post stack), `docs/OPEN.md §gl2` (defect ledger + rejected fixes), `.wolf/buglog.json` bug-1294/1296/1331, memory `gl2_migration_status`
