# SCOPE — teaching the rend2 collapse to recognise `nextbundle`

**Date:** 2026-08-28 · **Verdict: NO-GO** · **Effort avoided: ~5-8 days**
Four independent investigations (A parsing, B collapse, C prize, D risk) plus my own re-count.
All five agree. The premise does not survive contact with the code.

---

## 1. THE PREMISE — CORRECTED

**Claimed:** rend2's collapse recognises only form (a) (separate diffuse + lightmap stages), so
~44% of world surfaces and essentially all terrain authored in form (b) (`nextbundle`) never
reach a lit lightall permutation.

**True:** the *shader-text counts are right*; the *inference is wrong*. `CollapseStagesToGLSL`
indeed never looks at `bundle[1]` — but it never has to, because a MOHAA-specific pre-pass
rewrites form (b) into form (a) first.

`openmohaa-hzm/code/renderergl2/tr_shader.c`:

| anchor | line |
|---|---:|
| `FinishShader()` → `CreateMultistageFromBundle()` | **4008** |
| `FinishShader()` → `CollapseStagesToGLSL()` | **4184** |
| `CreateMultistageFromBundle()` body | 5095-5177 |

The split runs **176 lines earlier in the same function**. For an opaque `texture × $lightmap`
nextbundle stage (`bundle[TB_LIGHTMAP].isLightmap && !blendBits && multitextureEnv != GL_ADD`,
line 5133) it clones the stage, moves the lightmap to the clone's `bundle[TB_COLORMAP]`, zeroes
both `bundle[TB_LIGHTMAP]`s, and sets
`GLS_SRCBLEND_DST_COLOR | GLS_DSTBLEND_ZERO | GLS_DEPTHFUNC_EQUAL`.
That is *literally* the Quake 3 convention — one of exactly two blend signatures the collapse
accepts for a lightmap stage (tr_shader.c:3341-3352). It then merges, reaches
`CollapseStagesToLightall` (3055), and sets `LIGHTDEF_USE_LIGHTMAP`.

Provenance: upstream `openmoh/openmohaa` commit `e04cbd57` (2024-12-21). Extended in this tree by
`bug-gl2-nextbundle2` (2026-07-27). Present in the shipped `G:\mohaa-gl2\renderer_opengl2.dll`
(built 2026-08-27 23:59); `tr_shader.c` is clean in git — only `tr_surface.c` is dirty.

### My own count (590 retail `.shader` files, stages containing `$lightmap`)

| form | count | reaches lightall |
|---|---:|---|
| (a) separate-stage | 3704 | yes |
| (a) separate, in a `deformVertexes` shader | 43 | no (deform, not nextbundle) |
| **(b) nextbundle, opaque → SPLIT** | **2828** | **yes** |
| (b) nextbundle, opaque, in a deform shader | 15 | no (deform) |
| (b) nextbundle, blended | 202 | no — deliberate |
| (b) nextbundle, blended + deform | 2 | no |
| (b) `nextbundle add` on a lightmap | **0** | n/a |

**2828 of 3047 nextbundle stages = 92.8% already collapse.** Investigators A (93.3%) and B
(93.3%) got the same number by different routes.

**Terrain is the inverse of the claim.** By shader name / `qer_keyword terrain`: 415 nextbundle
vs 257 separate — and **415 of 415 nextbundle terrain stages are split-eligible.** Terrain is
100% on the lit path. Investigator C's BSP-area attribution independently found 13,959 of 13,960
campaign terrain patches resolving LIT. The reported "terrain 1 vs 203, essentially all unlit" is
a text-form count presented as a lighting outcome; those are different things.

### The symptom has a different, verified cause

"Relief on walls, none on ground" is **config drift**, not renderer behaviour.
`R_HZM_PathListMatch` (tr_image.c:2666) is documented in-source as a
*"space / comma / semicolon separated **substring** list"*. The deployed config carries a bare
`terrain` token; the repo's does not:

```
G:\mohaa-gl2\home\maintt\autoexec.cfg:1362   ... hedge terrain sky water glass window paper
                                     :1369   seta r_hzmGenNormalStrength 0.35
hzm-mohaa-coop-mod\autoexec.cfg:1365         ... hedge sky water glass window paper
                               :1375         seta r_hzmGenNormalStrength 1.5
```

`terrain` substring-matches every `textures/*terrain*/` path, so no generated normal is ever
produced for them — nothing to bind, no relief, regardless of the collapse. Strength is also
4.3× weaker. Already logged as **bug-2145**.

> **New finding, not in any of the four reports:** `grass` is in **both** lists. Deploying the
> repo autoexec will *not* fix `wilderness/m3l3grass_*`, `it_t_*grass*`, `bocagegrass_1uf`,
> `nu_earth_set3grass*`. Expect a partial result and do not read it as the fix failing.

Two further confounders on ground specifically: DDS diffuses skip CPU normal generation entirely
(`picFormat == GL_RGBA8` gate, tr_image.c:3152 — bug-1225), and with no deluxemap `L ≈ N ≈ +Z` on
flat ground, so `d(N·L)/dθ → 0` and normal perturbation is second-order. Ground reads flatter than
walls even when every code path works.

---

## 2. WHAT THESE SURFACES ARE MISSING TODAY — smaller than it looked

The genuinely-excluded population is **219 stages (7.2% of nextbundle lightmap stages)**, of which
17 are excluded by `shader.numDeforms != 0` (tr_shader.c:3197) — which excludes form (a)
identically and is not a nextbundle problem. **The nextbundle-specific set is 202 blended stages.**

Investigator C attributed these by real BSP surface area over 39 campaign maps: **6.2M units², or
0.072% of non-sky world surface area — seven shaders** (railway-tie decals, a snow overlay,
icicles, one window, one tapestry). Every one is a blended overlay sitting on top of already-lit
geometry.

And they are **not unlit**. `generic_fp.glsl` samples `u_LightMap` on bundle 1 with
`u_Texture1Env == 1` (GL_MODULATE) — exactly the lighting gl1 gave them, in one pass. What they
actually lack:

| feature | lost? | live? |
|---|---|---|
| lightmap modulation | **no — identical** | — |
| per-pixel normal map | **yes** | `r_normalMapping 1` — the only real loss |
| sun cascade shadow mask | **yes** | `r_sunShadows 1` — real, on 0.072% of area |
| specular | yes | `r_specularMapping 0` — inert |
| deluxe / light direction | no difference | MOHAA ships no deluxemaps |
| cubemap reflection | no difference | `r_cubeMapping 0`, no cubemap entities |
| per-pixel dlights | no difference | `r_dlightMode 0` — branch never fires for anyone |
| SSAO / bloom / DoF / tonemap / fog | **unaffected** | screen-space or separate pass |

**Say it plainly: the prize is a normal map and a shadow mask on 0.072% of world area, on
transparent overlays nobody inspects for relief. It is not worth a week. It is not worth a day.**

---

## 3. THE CHANGE — what it would take, for the record

An in-place recognition (accept a lightmap already sitting in `bundle[1]` rather than splitting):

| file:function | what changes | LOC |
|---|---|---:|
| `tr_shader.c:CollapseStagesToLightall` (3055) | add `lightmapInBundle1` param; guard `diffuse->bundle[TB_LIGHTMAP] = lightmap->bundle[0]` (self-aliasing stomp if `lightmap == diffuse`); same for the deluxemap read | 15-25 |
| `tr_shader.c:CollapseStagesToGLSL` (3192) | accept a diffuse whose own `bundle[TB_LIGHTMAP].isLightmap` is set; skip the inner `j` search; do not deactivate it | 15-25 |
| `tr_shader.c:CreateMultistageFromBundle` (5095) | stop marking those stages `ST_GLSL` (5169); zero `multitextureEnv` | 10-20 |
| `tr_shader.c:FixFatLightmapTexCoords` (3844) | bundle[1] case — inert only because `r_mergeLightmaps` defaults 0 here; upstream defaults 1 | 10-20 |

**~40-80 LOC, one file, mechanically easy — half a day to write.** The code is not the cost. Note
`ComputeVertexAttribs` already loops all `NUM_TEXTURE_BUNDLES` and runs after the collapse, so
`ATTR_LIGHTCOORD` needs nothing.

---

## 4. WHAT IT COULD BREAK

| risk | count | severity |
|---|---:|---|
| **Regressing the 2828 currently-working split stages** | 2828 | catastrophic — this is the whole world |
| Blended overlays moved onto lightall gain lighting model, overbright, sun shadow | 202 | high — visible, on conspicuous props; this is exactly the "dark-decal-rectangle class" the line-5160 comment exists to prevent |
| `TB_*` slot collision: `cntBundle` shares a namespace with the role enum (`NUM_TEXTURE_BUNDLES 7`, tr_local.h:503). A 2nd `nextbundle` lands on `TB_NORMALMAP` and `CollapseStagesToLightall:3092` overwrites it | 0 in retail | latent — mod shaders could trip it |
| bundle[1] `tcMod` silently dropped (lightall calls `ComputeTexMods(TB_DIFFUSEMAP)` only) | **0** on lightmap stages (all 187 are on non-lightmap FX stages) | none today |
| `animMap` in a nextbundle bundle | **0** | none |
| sky / portalsky with nextbundle lightmap | **0** | none |
| Stage-slot exhaustion in the split | **0** | none |

The decisive asymmetry: the change risks 2828 working stages to rescue 202 that are excluded for a
*mathematically correct* reason — a split framebuffer-multiply darkens the whole quad outside a
blended stage's alpha shape.

**A cvar gate is also weaker than it sounds here.** The collapse runs at *shader parse time*, so a
flip needs a full `vid_restart` / map load. It is fine for A/B, useless as a live safety valve.

---

## 5. STAGING — the smallest step that proves it

**Step 0 (2 minutes, do this before anything else).** In-game: `r_speeds 7` prints
`c_genericDraws` / `c_lightallDraws` (tr_cmds.c:94). Stand on ground on `t2l1` or `m3l3`. If this
analysis holds, `light` dominates and `gen` is a handful of water/decal/2D draws. Cross-check with
`r_lightmap 1`. **This converts a static argument into an observed fact and closes the question.**

**Step 1 (minutes).** `.\build.ps1` to deploy the repo autoexec — drops `terrain` from
`r_hzmGenNormalExclude`, raises strength 0.35 → 1.5. One token, one surface class, instantly
reversible by putting `terrain` back. Expect **partial** improvement: `grass` is still excluded.

**Step 2 (minutes).** Decide on `grass` — it is a foliage token doing double duty as a terrain
token. Either drop it and rely on `foliage`/`leaf`/`bush`, or move to the include-list form.

**Step 3 (hours).** Config-drift guard. The repo autoexec and both deployed copies silently
disagreed, and the deployed one is what the engine reads. **That is the actual defect this
investigation surfaced, and it will recur.**

**Step 4 (small, on its own merits, NOT as a relief fix).** `CreateMultistageFromBundle:5153` uses
`newStage->stateBits = ...` (assignment), dropping `GLS_ATEST_BITS` from the split lightmap pass.
Harmless while the collapse re-merges; wrong when it is skipped. **695 opaque-split stages carry
`alphaFunc`; it manifests on the 5 that also carry `deformVertexes`** — `static_naziflag1`,
`central_europe/curtain_1`, `curtain_1dirty`, `hood/hood_chain`, `misc_outside/blowingleaves`.

**Rollback for every step:** restore the exclude token / revert one line. No engine rebuild is
required for steps 0-3.

**Deferred, only if step 0 contradicts this document:** the §3 collapse change, behind
`r_hzmCollapseNextbundle` (default 0, `CVAR_LATCH`), scoped by a path allow-list in the style of
`r_hzmGenNormalInclude` rather than a global flip.

---

## 6. GO / NO-GO

### NO-GO on teaching the collapse to recognise `nextbundle`.

1. **It already does**, via `CreateMultistageFromBundle`, shipped since Dec 2024 and extended here
   a month ago. The work would re-implement an existing path.
2. **The prize is 0.072% of world area** — 202 blended overlay stages, seven shaders across 39
   campaign maps.
3. **Those 202 are excluded on purpose**, for a correct reason, by a comment that exists
   specifically to prevent the regression this change would reintroduce.
4. **It risks 2828 working stages and 100% of terrain** to buy that.
5. **The motivating symptom is a stale deployed config**, verified in two files against
   substring-match semantics, already logged as bug-2145.

### GO on the alternative, ~1 day total

| item | effort |
|---|---|
| Step 0 `r_speeds 7` observation | 2 min |
| Step 1 deploy autoexec | 10 min |
| Step 2 `grass` token decision + verify | 1 h |
| Step 3 config-drift guard | 2-4 h |
| Step 4 preserve `GLS_ATEST_BITS` in the split | 1-2 h |

**Confidence: high.** The split was traced end-to-end by four investigators independently and
re-verified here; the 92.8% and the 415/415 terrain figures were re-counted from the retail corpus
by two separate scripts; the config drift was read out of the deployed files. The one thing none of
us did is see pixels — **Step 0 costs two minutes and should be run before anyone writes renderer
code.**
