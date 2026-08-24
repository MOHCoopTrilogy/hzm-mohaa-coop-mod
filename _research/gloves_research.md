# Gloves in the Armory - research findings

Research only. Nothing in the project was modified to produce this. Date 2026-08-23.

Measurement method: all 88 pk3s under `G:\GOG\Medal of Honor - Allied Assault War Chest\{main,mainta,maintt}`
and `G:\mohaa-gl2\...` enumerated with Python `zipfile` (43,434 unique member names; the two roots are
byte-identical mirrors, so counts below are de-duplicated and cite the `main`/`mainta`/`maintt` pak).
Engine claims are cited to file:line in `C:\mohaa-coop-dev\openmohaa-hzm`. Where a statement is an
inference rather than something I read or counted, it is labelled **INFERENCE**.

---

## 1. Verdict

### Third person: FEASIBLE, and cheap. The trilogy already ships gloved 3P hands.

3P hands are one skelmodel with exactly **one surface, named `hand`**
(`models/human/hands/hand.skd`, `main/Pak0.pk3` - SKMD v5, numsurfaces=1, 746 tris / 604 verts,
50 bones incl. per-finger `Bip01 L Finger*`). Every character TIK wires it the same way:

```
	$path models/human/hands
	skelmodel hand.skd
	surface hand shader handsnew
```
(`models/player/american_army.tik`, `main/Pak0.pk3`)

Across the whole trilogy, **1,878 TIKs** reference that hands path, and I counted the
`surface hand shader <X>` pairs they use. `handsnew` is the default (1,482 uses), but **nine other
hand shaders are already in production**, most of them gloves:

| shader on `surface hand` | uses | what it is |
|---|---:|---|
| `handsnew` | 1482 | bare hands (AA default) |
| `knitgloves1` | 128 | German winter knitted gloves |
| `L_gloves` / `l_gloves` | 93 + 25 | German tank-commander leather gloves |
| `mittens2` | 83 | German winter mittens |
| `wintergloves_us` | 55 | US winter gloves |
| `pt_hands` | 25 | paratrooper hands |
| `handssnow` | 7 | -> `textures/models/human/handsglove.tga` (US snow glove) |
| `hands_snow1` / `hands_snow2` | 5 + 3 | Spearhead winter hands |
| `seaman_gloves` | 2 | Soviet seaman gloves (BT) |

So a 3P glove is a **one-token change to a single surface**. No new art is needed to ship a first
pass of 5-7 gloves. The only question is *how* to select one at runtime; see section 3.

### First person: FEASIBLE, and far cheaper than feared. It is NOT per-weapon.

I scanned all **551** `models/weapons/*.tik` in the trilogy. **Zero** of them declare a hand surface
or reference a hand shader. 1P hands are not baked into weapon viewmodels.

They live in a **per-player-skin companion TIK**, `models/player/<skin>_fps.tik`, selected by the
client at `code/cgame/cg_modelanim.c:2357-2367` by string-substituting `_fps.tik` onto the world
model name (helper: `CG_GetPlayerLocalModelTiki`, `cg_modelanim.c:98-101`; server twin
`player.cpp:15765-15767` sets `m_fpsTiki` the same way). There are **191** such files, and

* **all 191 use the same base mesh** - `path models/player/US_Army` + `skelmodel USarmyplyr.skd`;
* each declares exactly **three hand surfaces**: `triggerhand`, `lefthand`, `garandhand`
  (`lefthand` vs `garandhand` is swapped per weapon by cgame at `cg_modelanim.c:2434-2456`);
* plus one `viewsleeves` surface (52 distinct sleeve shaders across the set).

**Four gloved 1P looks already ship**, on 41 of the 191 files:

| 1P hand shader | _fps.tik files | what it is |
|---|---:|---|
| `handview` | 150 | bare hands (default) |
| `grmn_winter_glove` | 13 | German winter glove |
| `lthr_gloveview` | 12 | black leather officer glove |
| `us_winterglove` | 9 | US winter glove |
| `handviewcold`, `handviewend`, `handviewAfricanAm`, `1st_manon_handview`, `1st_sniper_handview`, `332handview`, `snipers_handview` | 1 each | skin-specific bare hands |

Cost: **1P needs zero weapon edits and, as it turns out, zero cgame edits** - see the next block and
section 4. It needs N shader lines added to the `_fps.tik` files, which is a generator job.

### The cost, stated plainly

**One networked field drives BOTH views.** `entityState_t.skinNum` is a 16-bit netfield
(`code/qcommon/msg.cpp:1409`), it is **unused on players and actors today**, and cgame copies it into
the render entity at `cg_modelanim.c:1950` - *before* the first-person branch, and the fps swap at
:2394 only zeroes `model.surfaces`, **not** `model.skinNum` (verified: inside `CG_ModelAnim`, which
starts at :1689, the only three touches are the full `memset(&model,...)` at :1785, the assignment at
:1950, and the surfaces-only memset at :2394). Both renderers then compute
`iShaderNum = ent->e.skinNum + (*bsurf & 3)`. So setting `skinNum` on the player entity selects the
hand shader in third person **and** in first person, through code that already exists.

| | cost |
|---|---|
| 3P gloves | `game.dll` only: a scriptable `skinNum` setter (no such event exists today - `actor.cpp` has only `EV_Actor_SetHeadSkin`) + a 2-line gore exemption. **No cgame, no renderer, no per-skin files.** |
| 1P gloves | the *same one field*. Author N shaders on `triggerhand` / `lefthand` / `garandhand` in the `_fps.tik` files. **No weapon edits (0 of 551), no cgame change.** |
| beyond 4 looks | `MAX_TIKI_SHADER` 4 -> N: ~6 lines across `tiki_shared.h`, `tiki_parse.cpp` and both `tr_model.cpp` |
| armory preview | one new URC command (`modelskincvar`), ~20 lines in `cl_uistd.cpp` - or skip it and use a 2-D swatch. See 6c |

**Recommendation.** Ship 4 looks first (bare + 3 gloves) with no `MAX_TIKI_SHADER` change at all -
that is a `game.dll`-only feature plus content. Raise the ceiling later if the roster wants to grow.
There is **no genuinely DLL-free path**: the two skin-offset bits are reachable from script today via
`surface hand "+skin1"`, but `CoopGoreUpdateSkinTier` *writes* those bits on every damage event
(`sentient.cpp:2513-2523`), so a script-only glove does not survive a firefight - and 1P is
unreachable from script entirely.

**Watch the quoting.** `surface hand "+skin1"` must be quoted in script. An unquoted `+`/`-` argument
is valid TIKI but a script parse-killer (`unexpected TOKEN_PLUS`) that takes the whole file down with
balanced braces - `docs/TRAPS.md:69`, bugs 533 and 1308.

---

## 2. Asset inventory

### 2a. The one hand model

| path | pak | notes |
|---|---|---|
| `models/human/hands/hand.skd` | `main/Pak0.pk3` | SKMD v5, **1 surface named `hand`**, 746 tris, 604 verts, 50 bones (full Bip01 arm+finger chain). The only 3P hand mesh in the trilogy. |
| `models/human/hands/hand.lod` | `main/Pak0.pk3` | LOD sidecar |
| `models/player/US_Army/USarmyplyr.skd` | `main/Pak0.pk3` | the 1P arms+hands mesh, shared by **all 191** `_fps.tik` |

There is no second hand mesh anywhere in AA / SH / BT. Anything that looks like a different hand is
a different *texture* on one of these two meshes.

### 2b. 3P hand / glove textures and shaders

Shader definitions are plain single-stage `map <tga>` + `rgbGen lightingSpherical`.

| shader | defined in | texture | pak of texture | theatre |
|---|---|---|---|---|
| `handsnew` | `scripts/faces.shader` | `textures/models/human/handsnew.tga` | `main/Pak2.pk3` | AA - default bare |
| `static_handsnew` | `scripts/faces.shader` | same, `rgbGen vertex` | `main/Pak2.pk3` | AA - static props |
| `handsnew_btc` | `scripts/mohta_download_characters.shader` | `textures/models/human/handsnew_btc.tga` | `mainta/pak3.pk3`, `maintt/pak1.pk3` | BT bare |
| `pt_hands` | `scripts/heads_hands.shader` | `textures/models/human/pt_hands.tga` | `mainta/pak1.pk3` | SH paratrooper |
| `hands_snow1` | `scripts/heads_hands.shader` | `textures/models/human/hands_snow1.jpg` | `mainta/pak1.pk3` | SH winter |
| `hands_snow2` | `scripts/heads_hands.shader` | `textures/models/human/hands_snow2.jpg` | `mainta/pak1.pk3` | SH winter |
| **`handssnow`** | `scripts/us_soldier_snow.shader` | **`textures/models/human/handsglove.tga`** | `mainta/pak1.pk3`, `maintt/pak1.pk3` | **SH/BT - US gloved** |
| **`knitgloves1`** | `scripts/german_winter.shader` | `textures/models/human/germanmaps/wintertroops/knitgloves1.tga` | `main/Pak2.pk3` | **AA - German knit glove** |
| **`mittens2`** | `scripts/german_winter.shader` | `textures/.../wintertroops/mittens2.tga` | `main/Pak2.pk3` | **AA - German mitten** |
| (`mittens3.tga` exists, no shader block found) | - | `textures/.../wintertroops/mittens3.tga` | `main/Pak2.pk3` | unused variant |
| **`l_gloves`** | `scripts/tank_commander.shader` | `textures/models/human/germanmaps/tank_commander/l_gloves.tga` | `main/Pak2.pk3` | **AA - panzer leather** |
| **`wintergloves_us`** / `us_winterglove` | `scripts/new_uswinter.shader` | `textures/models/human/usmaps/winter/wintergloves_us.jpg`, `textures/models/human/us_winterglove.jpg` | `maintt/zzzzzz-HRRTM_Pak1_Models.pk3` (shader), textures in `zzzzzz-HRRTM_Pak3_Textures.pk3` | **HRRTM addon - US winter** |
| **`seaman_gloves`** | `scripts/mohta_characters.shader` | `textures/models/human/sovietmaps/seaman_gloves.tga` | `mainta/pak3.pk3`, `maintt/pak1.pk3` | **BT - Soviet seaman** |
| `manon_hands` | `scripts/manon.shader` | `textures/models/human/frenchmaps/manon/manon_hands.tga` | `main/Pak2.pk3` | AA - Manon |
| `com_hands` / `com_hand` / `com_handr` | `scripts/krzysz_commando.shader` | `textures/com_hand*.tga` | `maintt/zzzzzz-HRRTM_Pak2_Models_misc.pk3` | HRRTM commando |
| `grmn_winter_glove` (1P; 3P texture also present) | see 2c | `textures/models/human/grmn_winter_glove.tga` | `main/Pak2.pk3` | **AA - German winter** |

Already in the **coop mod's own** paks (`maintt/zzzzzz_co-op_hzm_mod_code.pk3` shaders,
`..._assets_tex.pk3` textures) - these came in with imported skin packs:

`332hands`, `ae_hands` (airborne elite), `am_hands` (medic), `demo_hands`, `snipers_handsnew`,
`snipers_static_handsnew`, `recon_handsnew`, `pol_hands`/`pol_hand`/`pol_handr` (British paras),
`handsnew1` (britpack), `1st_sniper_hand`, `handsbloody`, plus
`textures/models/human/usmaps/sniper_gloves.tga` and `textures/l_gloves.tga`.

### 2c. 1P (viewmodel) hand / glove textures and shaders

| shader | defined in | texture | pak | look |
|---|---|---|---|---|
| `handview` | `scripts/faces.shader` | `textures/models/human/handview.tga` | `main/Pak2.pk3` | bare, default |
| `handview_right` | `scripts/faces.shader` | `textures/models/human/handview_right.tga` | `main/Pak2.pk3`, `mainta/pak1.pk3` | bare, right |
| **`lthr_gloveview`** | `scripts/playerviewmodel.shader` | **`textures/models/human/lthr_gloveview.tga`** | `main/Pak2.pk3` | **black leather officer glove** |
| **`grmn_winter_glove`** | (used by 13 `_fps.tik`; block not in the shaders I dumped - **INFERENCE**: it resolves by the "shader name == texture name" fallback, `tiki_files.cpp:489-500`) | `textures/models/human/grmn_winter_glove.tga` | `main/Pak2.pk3` | **German winter glove** |
| **`us_winterglove`** | `scripts/new_uswinter.shader` | `textures/models/human/us_winterglove.jpg`, `_cln.jpg` | `maintt/zzzzzz-HRRTM_Pak1_Models.pk3` | **US winter glove** |
| `handviewcold` | `scripts/playerviewmodel.shader` | `textures/models/human/handviewcold.tga` | `mainta/pak1.pk3` | cold/reddened bare |
| `handviewend` | `scripts/playerviewmodel.shader` | `textures/models/human/handviewend.tga` | `mainta/pak1.pk3` | bare (campaign end) |
| `handviewAfricanAm` | `scripts/playerviewmodel.shader` | `textures/models/human/handviewafricanam.jpg` | `mainta/pak1.pk3` | bare, darker skin |
| `handview_base` | (texture only) | `textures/models/human/handview_base.jpg` | `mainta/pak1.pk3` | bare base |
| `snipers_handview`, `1st_manon_handview`, `1st_sniper_handview`, `332handview`, `recon_handview` | coop mod shaders | `textures/*.tga` | `maintt/zzzzzz_co-op_hzm_mod_code.pk3` + `_assets_tex.pk3` | imported skin packs |

### 2d. Glove textures that exist but are NOT wired to a hand surface today

These are painted onto *body/gear* surfaces of specific character models, not onto `hand`. They are
still usable as source art for new glove shaders (they are already in the game's own paks, so no
licence question at all).

| texture | pak |
|---|---|
| `textures/models/human/germanmaps/wintertroops/mittens3.tga` | `main/Pak2.pk3` |
| `textures/models/human/us_winterglove_cln.jpg` | `maintt/zzzzzz-HRRTM_Pak3_Textures.pk3` |
| `textures/models/human/usmaps/sniper_gloves.tga` | coop `_assets_tex.pk3` |
| `textures/l_gloves.tga` | coop `_assets_tex.pk3` |
| `textures/models/mittens2.tga` | `maintt/zzzzzz-HRRTM_Pak2_Models_misc.pk3` |
| `textures/coop_*/ft_gloves.tga`, `.../ww1_sniper_gloves.tga` (10 weapon dirs) | coop `_assets_tex.pk3` - these belong to the WW1 weapon pack's own *weapon* skd surfaces, not to hands |

### 2e. Gloved characters already in the game (for reference art / naming)

* German panzer tank commander - `l_gloves` (`models/player/german_panzer_tankcommander*.tik`)
* German elite / SS / Gestapo officers - `lthr_gloveview` in 1P
* German winter troops (`german_winter_1..8`) - `knitgloves1`, `mittens2`, `grmn_winter_glove`
* US winter riflemen (`american_ranger_winter*`, `american_winter_*`) - `us_winterglove` / `wintergloves_us`
* Soviet seaman (BT) - `seaman_gloves`
* Norwegian resistance, British snow paras (HRRTM/coop packs) - `grmn_winter_glove`

**No dedicated pilot or Japanese gloved hand exists.** There is no Japanese character content in
this trilogy at all (checked: no `jap*`/`nippon*` human textures in the index).

---

## 3. The skin-offset question, answered

**Concrete answer: the hard maximum is 4 shader variants per surface, set by `MAX_TIKI_SHADER`, not
by the bit count. On the player models specifically, 3 of those 4 slots are free today - so the
honest number is "4 total looks including bare hands, i.e. 3 gloves" - but taking them collides with
the coop gore ladder and needs a one-line exemption. A `skinNum` change lifts the ceiling entirely.**

### Why 4

`Entity::SurfaceCommand` (`code/fgame/entity.cpp:4321-4407`) maps the script tokens to bits:

```c
    if (!Q_stricmp(token, "skin1")) {
        mask = MDL_SURFACE_SKINOFFSET_BIT0;
    } else if (!Q_stricmp(token, "skin2")) {
        mask = MDL_SURFACE_SKINOFFSET_BIT1;
```
(`entity.cpp:4363-4368`; bit values at `code/qcommon/q_shared.h:2141-2148`)

Two bits give indices 0..3. The renderer consumes them (both backends, identically):

```c
    int iShaderNum = ent->e.skinNum + (*bsurf & 3);
    if (iShaderNum >= dsurf->numskins) {
        iShaderNum = 0;
    }
    shader = tr.shaders[dsurf->hShader[iShaderNum]];
```
(`code/renderergl1/tr_model.cpp:962-967` and `code/renderergl2/tr_model.cpp:1320-1325`)

`dsurf->hShader[]` is `MAX_TIKI_SHADER` wide, and `MAX_TIKI_SHADER` is **4**
(`code/tiki/tiki_shared.h:107`, array at `:321-322`). The TIKI parser enforces it:

```c
    if (loadsurfaces[currentSurface].numskins > 3) {
        TIKI_Error("TIKI_ParseSetup: Too many skins defined for surface %s in %s.\n", ...);
```
(`code/tiki/tiki_parse.cpp:933-940`)

So authoring is: repeat the directive up to four times on one surface -

```
	surface hand shader handsnew
	surface hand shader handsnew_skin2
	surface hand shader handsnew_skin2
	surface hand shader handsnew_blood3
```

The 2 selector bits and the 4 array slots match exactly. **4 is the ceiling, and it is set by
`MAX_TIKI_SHADER`, not by the bit count.**

### How many are free on `hand` today - measured

I counted the `surface hand shader <X>` lines per TIK across the whole effective content set (mod
tree first, then paks in reverse mount order, so each name is counted once at the copy the engine
would actually load):

| shader lines on `surface hand` | all TIKs | `models/player/*.tik` only |
|---|---:|---:|
| 1 | 1928 | **351** |
| 2 | 46 | **5** |
| 4 | 28 | 0 |

The 28 four-slot TIKs are all **AI** models under `models/human/` in the mod tree - the coop gore
ladder, e.g. `models/human/german_wehrmact_soldier.tik`:

```
	surface hand shader handsnew
	surface hand shader handsnew		// gore tier 1 (light) - padded with the clean texture
	surface hand shader handsnew_skin2	// gore tier 2 (heavy)
	surface hand shader handsnew_blood3	// gore tier 3 (gib)
```

(the winter AI use the same ladder on `knitgloves1`, the UK para on `pt_hands`).

**Players are different.** 351 of 356 `models/player/*.tik` give `hand` exactly one shader; the 5
exceptions have two, and one of those is already a glove -
`models/player/allied_russian_crazy_boris_nohat.tik` carries `['handsnew', 'handssnow']`. The mod's
own generated `_nohat` twins - which are what players actually wear at runtime, 135 of them from
`_research/nohat/nohat_build.py` - add the gore ladder to body surfaces (`us_top_blood1/2` etc.) but
deliberately leave `hand` at a single shader.

So on the player: **slot 0 is taken by the bare hand, slots 1-3 are free. Four total looks, three of
them gloves.**

### The collision that taking those slots would create

`Sentient::CoopGoreUpdateSkinTier` (`code/fgame/sentient.cpp:2460-2528`) writes the gore tier
across **every** surface of a damaged sentient, clamped to what each surface can display:

```c
    // tier IS the skin index: 0 clean, 1 = SKINOFFSET_BIT0 (light), 2 = SKINOFFSET_BIT1 (heavy).
    ...
    surfTier = gi.TIKI_SurfaceNumSkins(edict->tiki, i) - 1;
    if (surfTier > tier) { surfTier = tier; }
    ...
    edict->s.surfaces[i] =
        (edict->s.surfaces[i] & ~(MDL_SURFACE_SKINOFFSET_BIT0 | MDL_SURFACE_SKINOFFSET_BIT1)) | surfTier;
```
(`sentient.cpp:2474`, `:2513-2523` - note it *writes*, never OR-accumulates, so it destroys any
glove index a script had set)

Two consequences, both real:

1. **It writes, it does not accumulate.** Any glove index a script put in those bits with
   `+skin1`/`+skin2` is *destroyed* the first time the player takes damage. A script-only glove
   through the skin bits is therefore not viable even for 3 gloves.
2. **The clamp reads `numskins`.** Today `hand` has `numskins == 1` on players, so `surfTier`
   clamps to 0 and hands are simply never bloodied. The moment you author 4 glove shaders on `hand`,
   `numskins` becomes 4, the clamp stops clamping, and **a wounded player's hands would step
   through your glove list as if it were a gore ladder.**

The fix for both is the same shape the head already uses: `CoopGoreUpdateSkinTier` skips the head
surface via the `m_bCoopHeadGore` latch (`sentient.cpp:2479-2485`). Add `hand` to the same skip and
the gore loop stops touching it - **one line**, and hand gore is not currently authored for players
anyway, so nothing is lost.

The gore art itself does exist if you ever want hand gore back: `scripts/coop_gore.shader` defines
`handsnew_skin2`, `pt_hands_skin2`, `knitgloves1_skin2`; `scripts/coop_gore3.shader` defines
`handsnew_blood3`, `pt_hands_blood3`, `knitgloves1_blood3` (both in
`maintt/zzzzzz_co-op_hzm_mod_code.pk3`).

### The lever that IS free: `skinNum`

The renderer line above adds `ent->e.skinNum` to the bit index. `skinNum` is:

* a **16-bit networked entityState field** (`code/qcommon/msg.cpp:1409`, `:1559`, `:1717`);
* **completely unused on players and actors today** - the only writers in `fgame` are
  `beam.cpp` (repurposed as beam flag bits) and `portal.cpp:61-136` (rotate/roll). Grepping
  `code/fgame/` for `skinNum` outside those two files returns only archive/packet plumbing
  (`entity.cpp:4812`, `g_utils.cpp:1343`).

Because it is *added*, `skinNum` and the gore bits form a natural 2-D table:
`index = gloveIndex * 4 + goreTier`. With `MAX_TIKI_SHADER` raised from 4 to (say) 64, that is
**16 gloves x 4 gore tiers on one surface, with no change to the gore system at all**.

Raising `MAX_TIKI_SHADER` touches: `tiki_shared.h:107`, the `numskins > 3` test at
`tiki_parse.cpp:933`, the two `assert(psurface->numskins <= MAX_TIKI_SHADER)` at
`renderergl1/tr_model.cpp:138` / `renderergl2/tr_model.cpp:420`, and the two existing HZM
out-of-bounds guards at `renderergl1/tr_model.cpp:973-984` / `renderergl2/tr_model.cpp:1354-1362`.
Memory cost is `MAX_QPATH(64) + 4` bytes per extra slot per surface per tiki - **INFERENCE**: for
~36 human models x ~8 surfaces that is well under a megabyte, but it should be measured before
committing, because `dtikisurface_s` is allocated per loaded TIKI and the project has hit
allocation ceilings before.

**Surface budget is not a constraint here - measured, not assumed.** `MAX_MODEL_SURFACES` is 32
(`code/qcommon/q_shared.h:2139`). Counting distinct surface names in the 135 generated
`models/player/*_nohat.tik`: the distribution runs 4 to 13, peaking at 9-10, **max 13**. That leaves
19 free. Note that *extra shaders on an existing surface do not consume surfaces at all* - they fill
`hShader[]` slots. Only introducing a separate glove **mesh** would cost a surface (+1, to 14).

---

## 4. First person: mechanism and cost

### How 1P hands are drawn

1. Client decides it is in first person, then swaps the render model to the fps tiki
   (`code/cgame/cg_modelanim.c:2357-2392`):
   `COM_StripExtension(model.tiki->a->name, ...)` then `Q_strcat(fpsname, "_fps.tik")`,
   `cgi.R_RegisterModel(fpsname)`. If that fails it falls back to the *reset default*
   `dm_playermodel` / `dm_playergermanmodel` fps tiki (`:2370-2380`).
2. **`memset(model.surfaces, 0, sizeof(model.surfaces));`** - `cg_modelanim.c:2394`.
3. cgame then sets NODRAW bits itself: whole-model hide when unarmed/zoomed/dead (`:2404-2410`),
   `lefthand` vs `garandhand` per weapon (`:2434-2456`), ADS off-hand hide (`:2460+`).

**Consequence 1: no server-side `surface` script command can ever affect the 1P hands.** The
`surfaces` array is zeroed every frame on the client. Hard fact, not an inference - line 2394.

**Consequence 2, and this is the good news: `model.skinNum` DOES survive.** The memset at :2394
clears only `model.surfaces`. `model.skinNum` was set from the networked entity state at :1950 and is
never touched again inside `CG_ModelAnim`. Since the surface bits are now all zero,
`iShaderNum = skinNum + 0 = skinNum` - so the player's networked `skinNum` alone picks the 1P hand
shader out of the `_fps.tik`'s shader list, with **no cgame change whatsoever**.

### Cost

* **551** `models/weapons/*.tik` - **0** need touching. Weapon viewmodels contain no hands.
* **191** `models/player/*_fps.tik` exist, all on the same `USarmyplyr.skd`, differing only in
  `viewsleeves` + the three hand surfaces.
* The mod also ships **171** `_nohat` player TIKs that have **no** `_fps.tik` partner - those
  players currently fall through to the default fps model at `cg_modelanim.c:2370-2380`, i.e. they
  already lose their per-skin sleeves in first person. (**INFERENCE** on the visual consequence -
  the fallback path is measured, the on-screen result is not; see the test in section 7.)

### Three ways to do 1P, ranked

**(A) Networked `skinNum` - recommended, and it needs NO cgame code.** The server sets
`edict->s.skinNum = <gloveIndex>` on the player; it networks; cgame copies it at :1950; the fps swap
does not clear it; the renderer resolves `hShader[skinNum]`. All that is needed on the content side
is N shader lines on each `_fps.tik`'s three hand surfaces:

```
	surface triggerhand shader handview
	surface triggerhand shader lthr_gloveview
	surface triggerhand shader grmn_winter_glove
	surface triggerhand shader us_winterglove
```

Capped at 4 by `MAX_TIKI_SHADER` unless that is raised. **There is no gore contention in 1P** -
`model.surfaces` is zeroed, so `bsurf & 3` is always 0 and `skinNum` alone selects. 1P therefore does
not need the 2-D table that 3P does; a flat index works.

Scope of the content edit: 191 `_fps.tik` files, all mechanically identical (same skd, same three
surface names) - so it is a generator job of the same kind as `_research/nohat/nohat_build.py`, not
191 hand edits. Or restrict it to the ~69 armory skins and let the rest keep bare hands.

**(B) cgame hook that renames the fps tiki - ~8 lines, no `MAX_TIKI_SHADER` change.** Append a glove
suffix when building `fpsname`, e.g. `models/player/<skin>_fps_g3.tik`, falling back to
`<skin>_fps.tik` when the variant is absent. Lifts the 4-look cap without touching `MAX_TIKI_SHADER`,
but the cost is *files*: 191 (or 69) skins x N gloves. Worth keeping in mind only if the glove roster
is meant to grow past what a raised `MAX_TIKI_SHADER` comfortably holds.

**(C) Pure content, no DLL - not possible.** Because the fps name is derived from the world model
name, changing gloves without code means changing the world model, i.e. the skin. Reject.


---

## 5. Internet finds

Nothing was downloaded. Licence status is reported as found; where a page carried no licence
statement at all, that is said rather than guessed.

**Read section 2 first.** The single strongest finding of the whole sweep is that *you do not need
any of this yet*: the retail paks already contain nine 3P and four 1P glove shaders (section 2b/2c),
and OpenMOHAA requires the retail data, so every user already owns them. The external sources below
matter for the *second* wave of gloves, not the first.

### 5a. MOHAA hand/glove skins - direct hits

All **ARCHIVE-ERA** (2003-2010 uploads, no author activity since). **None of these pages carries any
licence statement** - they are bare file listings. Under the project's asset policy these ship with
credit and remove-on-request. Format in every case is a `.pk3` of `.tga`/`.jpg` replacing the stock
hand textures, so **conversion needed: none** - they are drop-in repaints of the exact surfaces this
report is about. One of them even ships pre-split per game (main / mainta / maintt), which is the
same layout this mod uses.

| mod | contents | date / size | URL |
|---|---|---|---|
| **DirtyHarry's Hand Skinpack** | five bare-hand repaints: black fingerless, white, British camo, MARPAT camo, skeleton | 2007-07-31, 3.47 MB | https://en.ds-servers.com/gf/medal-of-honor/skins/other/dirtyharry-s-hand-skinpack.html |
| **DHs Fingerless Glove Pack** | seven fingerless knitted glove colours; author's note says it works on all three installs | 4 MB, 728 dls | https://www.lonebullet.com/skins/download-dhs-fingerless-glove-pack-medal-of-honor-allied-assault-skin-free-8762.htm |
| **Winter Gloves** | retextures the default hands as the winter-level gloves | 2004-01-15, 200 KB, 1396 dls | https://en.ds-servers.com/gf/medal-of-honor/skins/other/winter-gloves-3.html |
| **Dr Deleto's Fingerless Mesh Gloves** | the original fingerless mod | 2003-03-20, 91 KB, 2843 dls | https://en.ds-servers.com/gf/medal-of-honor/skins/other/dr-deleto-s-fingerless-mesh-gloves.html |
| **Fingerless Gloves (DeceptioN recolour)** | recolour of the above; the 2000s-era uploader's own note says he *tried* to contact Dr Deleto and could not | 90 KB, 1419 dls | https://www.lonebullet.com/mods/download-fingerless-gloves-medal-of-honor-allied-assault-mod-free-24622.htm |
| **Allied Assault gloves Final** | fingerless gloves shipped as per-game pk3s (`zzz_AARangerarmgloves.pk3`, `zzz_AAdefaultarmgloves.pk3`, `zzz_SHgloves.pk3`, `zzz_BTgloves.pk3`) | 2010-09-07 | https://www.nexusmods.com/medalofhonor/mods/1404 |
| **Wartorn Hands** | grimier replacement hands | 2003-02-22, 249 KB | https://en.ds-servers.com/gf/medal-of-honor/skins/other/wartorn-hands.html |
| **Spearhead Hand Skins** | more realistic hand replacement | 2003-02-23, 277 KB | https://en.ds-servers.com/gf/medal-of-honor/skins/other/spearhead-hand-skins.html |
| **Wolf Hands** | 1P novelty hands | 2006-04-16, 431 KB | https://en.ds-servers.com/gf/medal-of-honor/skins/other/wolf-hands-2.html |
| **Armdudes Bloody Hands**, **Raiden's Sleeve Reskins** | gore hands; MP sleeve reskins (6.85 MB) | 2007-01-04 | https://en.ds-servers.com/gf/medal-of-honor/skins/other/2 and /3 |

The GameFront "Medal of Honor -> Skins -> Other" category was swept completely - all 10 pages,
93 entries. Spearhead's equivalent category has no hand or glove content.

### 5b. ACTIVE authors - must be asked first, per the asset policy

| mod | why it is relevant | status | URL |
|---|---|---|---|
| **FAH Infantry HD Remaster** (Ferran Adzarà Hernández) | states it remastered *all* SP campaign hand and view-sleeve textures. Released **2026-01-08** - current | **ACTIVE-AUTHOR, ask first** | https://www.moddb.com/mods/fah-infantry-hd-remaster |
| **Hi-Res Realism Texture Mod** (`czwarty_`) | includes winter jacket + glove textures; the author himself asks permission before reusing others' work | **ACTIVE-AUTHOR, ask first** | https://www.moddb.com/mods/hi-res-realism-texture-mod |
| **MoHAA Texture remaster** (Nexus) | permissions page **explicitly restricts** asset reuse without asking | **ACTIVE-AUTHOR, ask first** | Nexus Mods |

### 5c. CC0 / explicitly-licensed material for authoring originals

| source | what | licence | conversion |
|---|---|---|---|
| **BEST** **Auckland War Memorial Museum glove photos, Wikimedia Commons** | ~34 studio shots of individual glove pairs flat on white. Includes a genuine **WW2 RAF brown leather flying glove at 5184x3456** (`Gloves, flying (AM 1981.155-1)`), fleece-lined brown leather (`AM 2001.25.802.9`), white RAF dress gloves, canvas gauntlets | **CC BY 4.0**, verified per file | photo -> repaint onto the hand UV. One credit line |
| **Poly Haven** | `brown_leather` (vintage/wrinkled/matte), `fabric_leather_01`/`02` (**visible stitching** - what sells a glove at MOHAA viewing distance), `knitted_fleece`, `wool_boucle`, `poly_wool_herringbone` | **CC0** ("effectively Public Domain") | material -> repaint |
| **ambientCG** | `Leather007` (brown, rough, used), `Leather032` (black, scratched) - wear layers | **CC0**; licence explicitly permits shipping raw files inside a game | material -> repaint |
| **OpenGameArt** "cc0 texture resources 4 - textile" (rubberduck) | 54 **photo-sourced** cloth/leather textures | **CC0** | material -> repaint |
| **Drillimpact "PSX First Person Arms"** | ships a hand-painted **black glove texture at 512x512** - a free study in painting a glove at exactly this resolution budget, even ignoring its mesh | **CC0** | reference / direct repaint source |
| **Quaternius "Glove"** | the only true CC0 glove *mesh* found | **CC0** | full retarget - see 5d |

**Do not use:** textures.com (redistribution banned - and a `.pk3` *is* a zip, so shipping one
violates it by construction), Imperial War Museum (non-commercial terms; reference only, ship
nothing), Free3D and CGTrader (both explicitly ban standalone redistribution).

### 5d. 3D glove models - recommend skipping

Nothing found matches the 746-triangle budget or the Bip01 skeleton. Retargeting a mesh onto
`hand.skd` costs far more than a repaint buys, and the repaint gets both the 3P and 1P surfaces from
the same afternoon's work. **Recommendation: repaint, do not retarget.**

Sketchfab specifically: its default "Sketchfab Standard" licence is **view-only, not
redistributable**, and its CC0 option is restricted to cultural-heritage institutions - so hobbyist
CC0 gloves there essentially do not exist. The two glove scans found are **CC BY-NC**, which the
project cannot use.

### 5e. What could not be verified - stated, not guessed

* **GameFront returns 403 to automated fetches**, including its own game index. The content is real
  (search engines index live download counts) but no page could be read directly. Everything in 5a
  came via the **ds-servers.com `/gf/` mirror**, which is fetchable and carries the same
  descriptions, file sizes, dates and download counts. Treat sizes/dates as mirror-reported.
* **mohaaaa.co.uk and its forums are entirely behind an anti-bot proof-of-work challenge.** Every
  HTML page returns Access Denied. Its ~671-skin database was **unreachable**. Notably, static file
  paths under `/sites/default/files/` *do* fetch - so a human with the site open in a browser could
  enumerate it, and that is probably the single highest-yield follow-up if more gloves are wanted.
* **mohcentral.net does not resolve (DNS NXDOMAIN).** The commonly cited "AAAA merged with MRU ->
  MOH Central" successor archive is **dead**; any reference to it elsewhere is stale.
* **ModDB and Nexus Mods return 403** to automated fetches. The 5b entries rest on search-result
  snippets, not on pages actually read.
* **Library of Congress, NARA, IWM and PicRyl all returned 403.** Their contents are unverified.
  LOC's FSA/OWI collection and NARA's Signal Corps holdings are genuinely public domain and worth a
  manual browse for WW2 glove reference.
* `mohaareunited.com` is live but distributes full copies of the retail game. Flagged as a source
  **not** to draw from.


---

## 6. Implementation plan, mirroring the helmet system

### 6a. What the helmet system actually is (the pattern to copy)

`coop_mod/helmet.scr` (1746 lines, 23 labels). The load-bearing shape:

| function | line | role |
|---|---:|---|
| `helmet_initList` | 30 | builds `level.coop_helmetName[i]` / `level.coop_helmetTik[i]` / `level.coop_helmetCount`, guarded by `if( level.coop_helmetCount != NIL ){ end }`. Index 1 = "Standard Issue", 2 = "No Helmet", 3+ = real pieces |
| `helmet_apply` | 186 | the single choke point. `waitframe` first (InitModel rebuilds the tiki on every spawn and clears surfaces + attachments), range-check the stored index, **wear-time unlock re-validation that FAILS OPEN**, body-normalise onto the `_nohat` twin, then nodraw + attachmodel |
| `helmet_lockNotice` | 482 | says the locked-item message **once per distinct item** (automated resends re-enter the gate constantly) |
| `helmet_applyMannequin` | 498 | same recipe aimed at the lobby `script_model` + sets the armory preview tile cvar |
| `helmet_cycle` | 771 | relative prev/next, skipping locked items |
| `armory_helmet_applyIdx` | 799 | shared apply tail: set `flags["coop_helmetIdx"]` + `flags["coop_helmetTouched"]`, then `helmet_apply` + `helmet_applyMannequin` |
| `armory_helmet_set` | 818 | **bus 35 entry.** `int(local.data)` then range check then `cosmetic_isUnlocked` gate; if dead, record the choice and let the next spawn dress them; else `armory_helmet_applyIdx` |
| `armory_helmet_exportLocks` | 1480 | pushes each GATED page's lock state to the client as `seta coop_loHmLkA<NN> set coop_loCosLk <0 or 1>`; diff-only via `flags["coop_loHmLkL"+i]`, superseded-generation guard `coop_loHmLkGen`, **8 stufftexts per frame**, then `vstr coop_loOpenHelm` to refresh the shown page |
| `cosmetic_gatedBuild` | 1527 | **the allow-list.** `level.coop_cosmeticGatedTok[<token>] = 1` |
| `cosmetic_isUnlocked` | 1736 | not listed means FREE, else `chal_ensure` then substring-match the pipe-separated `flags["coop_chal_unlocks"]` |

Client side: one generated cfg per item, `ui/loadout/helm/hNN.cfg` (48 files today), each setting
`coop_loHelm` (the preview attach model), `coop_loHelmN`/`coop_loHelmP` (neighbour links),
`coop_loAHelm` (`append name ,hn<NN>` - the wire token), `coop_loOpenHelm`, `coop_loHelmNm`, and the
shared lock caption cvars `coop_loCosLk` / `coop_loCosReq` / `coop_loCosReq2` / `coop_loCosReq3`.
Gated pages bake `set coop_loCosLk 1` then `vstr coop_loHmLkA<NN>` so the server push overrides it.
`ui/coop_loadout.urc` has `helmPrev` / `helmNext` buttons
(`stuffcommand "vstr coop_loHelmP ; vstr coop_loAHelm"`, `.urc:120-147`) and a `coop_loHelmNm` label;
the preview mannequin at `.urc:52-65` uses `rendermodel 1` + `modelattachcvar "coop_loHelm"`.

### 6b. The concrete list for GLOVES

**New file: `coop_mod/gloves.scr`.** One-to-one with the table above:

```
glove_initList                        // level.coop_gloveName[i] / coop_gloveTok[i] / coop_gloveCount
glove_apply           local.player    // choke point, called every spawn
glove_lockNotice      local.player local.idx
glove_applyMannequin  local.player
glove_cycle           local.player local.dir
armory_glove_applyIdx local.player local.idx
armory_glove_set      local.player local.data      // bus 52 entry
armory_glove_exportLocks local.player
```

**Note what `glove_apply` actually does, because it is simpler than `helmet_apply`.** It does *not*
name a shader. The shader list lives in the TIK; the script only publishes an **index**:

```
	local.player skinnum ( local.idx - 1 )      // 0-based: 0 = bare hands
```

(pending the new setter from the table below). That is the whole apply step. There is no
`attachmodel`, no `_nohat`-style body swap, no follower thread, and no fit-tuning cvars - all of
which exist in `helmet.scr` only because a helmet is a separate prop that has to be positioned on a
bone. A glove is a shader on a surface the model already has. **Expect `gloves.scr` to be a small
fraction of `helmet.scr`'s 1746 lines** - the list, the gate, the export and the bus entry, and
little else.

`glove_apply` still needs the leading `waitframe` (InitModel rebuilds the tiki on respawn) and the
same fail-open wear-time re-validation, because those guard the *unlock* logic, not the attach logic.

`cosmetic_isUnlocked` and `cosmetic_gatedBuild` are **reused unchanged** from `helmet.scr` - they are
already written as shared cosmetic helpers ("Shared unlock gate for cosmetics (skins + helmets)",
`helmet.scr:1520-1526`). Gloves become the third caller.

Index 1 must be the free default ("Bare Hands"), exactly as helmets do, so an untouched or
locked-out player always has a deterministic fallback.

**Files to edit - 9 sites:**

| file | site | change |
|---|---|---|
| `coop_mod/variables.scr` | `getNameAppendCommands` | add `local.command["52"]=" ,gn"` (data = 2-digit page id). `,gn` / `,gp` / `,gl` are all unused - I checked the whole table. **Note the table currently declares `["48"]`..`["51"]` five times over** - identical values, last write wins, harmless today, but it must be cleaned before anyone appends 52 beneath it |
| `coop_mod/player.scr` | ~line 691, after `arrayIndex==51` | `else if(local.arrayIndex==52){ thread coop_mod/gloves.scr::armory_glove_set local.player local.dataExtract }` |
| `coop_mod/player.scr` | `manageAliveSpawning`, next to the existing `helmet_apply` hook | `thread coop_mod/gloves.scr::glove_apply local.player` |
| `coop_mod/dbno.scr` | 1062 | next to `helmet.scr::helmet_apply`, add `gloves.scr::glove_apply` - revive rebuilds the model too |
| `coop_mod/challenges.scr` | 1213 | next to `armory_helmet_exportLocks`, add `armory_glove_exportLocks` |
| `coop_mod/challenges.scr` | `chal_unlock_displayName`, ~2950 | new branch: token starts `glv_` gives `"Gloves: " + level.coop_gloveName[i]`, mirroring the `models/coop_helmets/` branch |
| `coop_mod/helmet.scr` | `cosmetic_gatedBuild`, 1527+ | **add every gated glove token.** See 6d - this is the step that is easy to forget and that silently makes gloves free |
| `coop_mod/helmet.scr` | `armory_skin_applyIdx`, 1371 | a skin change re-`model`s the player, which wipes surfaces - re-apply gloves there, exactly as it already re-threads `helmet_apply` at :1381 / :1400 |
| `coop_mod/loadoutpick.scr` | open / close-commit / join-resend (`:291`, `:483`) | resend the archived `,gn` token alongside the existing `,hn` resend |

**New UI files:**

* `ui/loadout/glove/g01.cfg` .. `gNN.cfg` - generated, same shape as `helm/hNN.cfg`. Cvars:
  `coop_loGlove` (the glove **index**, not a model path - see 6c), `coop_loGloveN`, `coop_loGloveP`,
  `coop_loAGlove` (`append name ,gn<NN>`), `coop_loOpenGlove`, `coop_loGloveNm`, plus the shared
  `coop_loCosLk` / `coop_loCosReq*`. Gated pages bake `1` then `vstr coop_loGlLkA<NN>`.
* `ui/coop_loadout.urc` - two buttons (`glovePrev` / `gloveNext`,
  `stuffcommand "vstr coop_loGloveP ; vstr coop_loAGlove"`) and a `coop_loGloveNm` label.
  **Layout warning:** the helmet buttons occupy y426-441 and the unlock caption was deliberately
  moved to y444+ to escape the model viewer rect (the reasoning is written out at `.urc:145-158` -
  a rendermodel widget composites *after* 2-D widgets regardless of `ordernumber`, so the caption
  could not be layered over it). There is therefore **no free vertical space directly under the
  helmet row**; a glove row needs a relayout decision, not just another pair of buttons.
* A generator script, next to the existing precedents (`_research/nohat/nohat_build.py`,
  `scratchpad/gen_cosmetic_unlocks.py`). Per the project rule that anything derivable must be
  generated, the page cfgs **and** the `cosmetic_gatedBuild` glove lines should come from one
  generator, not be hand-written.

**Engine edits (small, and both are needed only once):**

| file | change | size | needed for |
|---|---|---|---|
| `code/fgame/entity.cpp` (or `player.cpp`) | a scriptable setter for `edict->s.skinNum` - **none exists today**; the only skin-ish script events are `EV_Actor_SetHeadSkin` / `GetHeadSkin` (`actor.cpp:1605-1614`) | ~15 lines (one `Event` + handler + `CLASS_DECLARATION` entry) | **both views** |
| `code/fgame/sentient.cpp` | in `CoopGoreUpdateSkinTier`, skip the `hand` surface the way `headSurf` is skipped at :2479-2485 | 2 lines | 3P only |
| `code/tiki/tiki_shared.h` + `tiki_parse.cpp` + both `tr_model.cpp` | raise `MAX_TIKI_SHADER` - **only if** more than 4 total looks are wanted | ~6 lines, 4 files | >4 gloves |
| `code/client/cl_uistd.cpp` / `.h` | new `modelskincvar` URC command for the armory preview - see 6c | ~20 lines | preview only |

**`cgame.dll` and the renderers need no change for the feature itself.** That is worth stating
plainly because it halves the deploy surface: this is a `game.dll`-only ship
(plus `openmohaa.exe` if `modelskincvar` is added, since `cl_uistd.cpp` is client code).

### 6c. The preview problem - the one genuinely new piece of work

A helmet preview is easy because a helmet is an *attached model*: the URC widget already has
`modelattachcvar` (`code/client/cl_uistd.cpp:227-235`). **A glove is not an attachment - it is a
shader on a surface of the body model, and there is no URC command for that.** `cl_uistd.cpp` never
touches `skinNum` or `surfaces[]` on the preview refEntity - I grepped it, zero hits.

Three options:

1. **Add `modelskincvar` to the URC widget - recommended.** Reads an int from a cvar into the
   preview refEntity's `skinNum`. Exactly the same shape as the four HZM widget extensions already
   in `cl_uistd.cpp` (`modelxformcvar`, `modelattachcvar`, `modelattachcvar2`, `modelanimcvar`), it
   is the natural twin of the cgame change, and it makes the preview show the real thing.
2. **2-D swatch.** A flat `shader "textures/coop_gloves/preview_<n>.tga"` label beside the name.
   No engine work. At the mannequin's scale the hands are tiny, so a swatch may well read *better*
   than the model would.
3. **Per-glove preview body TIK** via `coop_loChar`. Rejected: skins x gloves files.

**INFERENCE, not measured:** that the hands are too small to read on the armory mannequin. The
mannequin widget rect is `12 46 134 348` and it frames a standing player, so the hands land at a few
pixels. Worth one look in-game before choosing between (1) and (2). The **lobby** mannequin
(`glove_applyMannequin`) is a full-size in-world `script_model` and does not have this problem.

### 6d. Unlock plumbing - exactly how a glove gets gated

Two independent grant channels, both funnelling into one stored record
(`flags["coop_chal_unlocks"]`, pipe-separated, persisted per player id).

**Challenge-based.** `chal_def` takes the reward as its 7th argument (`challenges.scr:698`:
`chal_def local.id local.cat local.title local.desc local.stat local.target local.reward`).
Existing cosmetic example, `challenges.scr:128`:

```
	waitthread chal_def "wpn_ppk" "pistols" "Gestapo Pocket" "Get 30 kills with the Walther PPK" "wpn_ppk" 30 "models/coop_helmets/coop_helmet_eyeglasses.tik"
```

A glove reward is one more line of the same shape with a glove token in the reward slot.

**Rank-based.** `xp.scr:39+` builds `level.coop_xp_rankUnlockCnt[rank]` and
`level.coop_xp_rankUnlock[rank][j]`:

```
	level.coop_xp_rankUnlockCnt[1] = 2
	level.coop_xp_rankUnlock[1][0] = "models/weapons/carbine.tik"
	level.coop_xp_rankUnlock[1][1] = "models/weapons/p38.tik"
```

Adding a glove = bump the `Cnt` and add an entry. Both channels funnel through `chal_add_unlock`,
which also appends the display name to the lobby "new unlocks" queue (`chal_pend_append`,
`challenges.scr:2918`) - which is why `chal_unlock_displayName` needs the glove branch.

**THE STEP THAT SILENTLY BREAKS GATING.** `cosmetic_isUnlocked` is an **allow-list**
(`helmet.scr:1739`):

```
	if( level.coop_cosmeticGatedTok[local.token] != 1 ){ end 1 }		//not gated -> free
```

A glove that is **not** in `cosmetic_gatedBuild` is **free to everyone**, no matter how many
challenges or rank tiers point at it. `helmet.scr:1533-1536` records that exact mistake already
being made once, for 13 helmet pieces added on 08-07. So: **every gated glove token must appear in
`cosmetic_gatedBuild` as well as in its challenge/rank entry**, and one generator should emit both.

### 6e. Token naming

Helmets use a model path as the token because they *are* models. Gloves are not models, so a path
would be a lie. Suggest a flat token: `glv_leather`, `glv_wool`, `glv_mitten`, `glv_tanker`,
`glv_seaman`. It stays a plain string through `cosmetic_gatedBuild`, `flags["coop_chal_unlocks"]`
and `chal_def`'s reward slot, all of which are string-typed. It also keeps
`chal_unlock_displayName`'s dispatch unambiguous - that function already dispatches on `perk_` /
`attach_` prefixes for the same reason.

### 6f. Suggested first roster - all from assets already on disk, zero licence exposure

| # | name | 3P shader on `surface hand` | 1P shader on triggerhand/lefthand/garandhand | gate |
|---:|---|---|---|---|
| 1 | Bare Hands | `handsnew` | `handview` | free |
| 2 | Leather Gloves | `l_gloves` | `lthr_gloveview` | challenge |
| 3 | Winter Wool | `knitgloves1` | `grmn_winter_glove` | challenge |
| 4 | US Winter | `handssnow` (maps to `handsglove.tga`) | `us_winterglove` | rank |
| 5 | Mittens | `mittens2` | *(no 1P art - needs a repaint)* | challenge |
| 6 | Seaman's Gloves | `seaman_gloves` | *(no 1P art)* | rank |

Rows 5-6 show the real asymmetry: **the 3P set is richer than the 1P set** - 9 usable 3P hand
shaders against 4 usable 1P ones. For any glove without a 1P twin the options are (a) paint a
`*_gloveview` texture, (b) reuse the nearest existing 1P glove, or (c) ship it 3P-only and say so in
the item description.

**INFERENCE, not verified:** (a) is not a straight copy - the 3P `hand.skd` and the 1P
`USarmyplyr.skd` are different meshes and almost certainly have different UV layouts, so a 3P glove
texture will not land correctly on the viewmodel hands. Confirming this needs both meshes opened in
a viewer; I did not do it.

> **Cap note for 6f:** the roster above is six entries, but `MAX_TIKI_SHADER` is 4. Either ship rows
> 1-4 first (bare + leather + wool + US winter, all of which have both a 3P and a 1P shader - a tidy
> coincidence) or raise `MAX_TIKI_SHADER` before adding rows 5-6.

---

## 7. Open questions

Ordered by how much they could change the plan.

### 7.1 Does `skinNum` on a player entity actually reach the renderer intact? MUST TEST.

Everything in section 1 and 4 rests on this chain: `edict->s.skinNum` -> netfield
(`msg.cpp:1409`) -> `cg_modelanim.c:1950` -> `iShaderNum = skinNum + (bsurf & 3)`
(`tr_model.cpp:962` / `:1320`). I read every link, but I did not run it, and the field has never
carried a value on a player before.

**Exact test:** author one player TIK with two shaders on `hand`
(`surface hand shader handsnew` / `surface hand shader l_gloves`), give the player entity
`skinNum = 1`, and look at the hands in third person. The gl2 renderer already has a diagnostic that
prints the resolved shader per surface - `^~^~^ SKELSHADER model=... surf=N bsurf=0x.. skin=A/B
hShader=.. shader=..` (`renderergl2/tr_model.cpp:1331-1348`, gated behind `R_SkelDiagOn()`). Turn
that on and the answer is one line of `qconsole.log`, no guessing. Repeat in first person for the
`_fps.tik` half.

### 7.2 Do the 3P and 1P hand meshes share a UV layout?

`models/human/hands/hand.skd` (746 tris) and `models/player/US_Army/USarmyplyr.skd` are different
meshes. If their UVs differ - which I expect - then every new glove needs **two** textures painted,
not one, and the 3P-only rows in 6f cannot be promoted to 1P by copying a file. I did not open either
mesh. **Test:** convert both with the project's `md5_2_skX` converter and compare UV islands, or just
try `surface triggerhand shader knitgloves1` on one `_fps.tik` and look.

### 7.3 Is the armory mannequin's hand big enough to preview a glove on?

Drives the choice between `modelskincvar` (6c option 1) and a 2-D swatch (option 2). The widget rect
is roughly `12 46 134 348` framing a standing figure. **Test:** open the armory and look at the
mannequin's hands. One glance settles it, and it decides whether ~20 lines of `cl_uistd.cpp` are
worth writing.

### 7.4 Does exempting `hand` from the gore loop lose anything visible?

Player `hand` surfaces have `numskins == 1` today, so the gore loop already clamps them to tier 0 -
i.e. **player hands are never bloodied right now**, and the exemption should be a no-op for players.
But the same function runs on **AI**, and 28 `models/human/*.tik` in the mod tree *do* carry the
4-slot hand gore ladder. Exempting the surface by name would switch AI hand gore off too.
**Recommended shape:** exempt `hand` only when the sentient is a player, or better, only when a glove
index is set - not a blanket name skip. Worth deciding deliberately rather than discovering later.

### 7.5 What is the memory cost of raising `MAX_TIKI_SHADER`?

`dtikisurface_s` holds `char shader[MAX_TIKI_SHADER][MAX_QPATH]` + `int hShader[MAX_TIKI_SHADER]`
(`tiki_shared.h:321-322`), i.e. **68 bytes per slot per surface per loaded TIKI**. Going 4 -> 16 adds
816 bytes per surface. **INFERENCE:** across the loaded human/player set that is well under a
megabyte and irrelevant - but this project has hit allocation ceilings repeatedly
(`MAX_SOUNDS`, `MAX_TIKI_ALIASES`, the entity pool), so it should be measured, not assumed, before
the raise ships. Only do it if the roster genuinely needs more than 4.

### 7.6 The `_nohat` skins have no `_fps.tik` - is that already a visible defect?

171 player TIKs (including all 135 generated `_nohat` twins, which are what players actually wear)
have no `_fps.tik` partner, so `cg_modelanim.c:2370-2380` falls back to the *reset default*
`dm_playermodel`'s fps model. **INFERENCE:** that means a player in a British-para skin currently
sees US Army sleeves in first person. I measured the fallback path; I did not confirm the visual.
This matters for gloves because the glove would then be authored onto whichever fps tiki actually
gets loaded - so it is worth knowing which one that is before generating 191 files, 135 of which may
never be reached. **Test:** pick a distinctive non-default armory skin, go first person, look at the
sleeves.

### 7.7 Dedicated/listen parity

Project standing rule: listen-only is a defect. `skinNum` is a networked entity-state field, so it
should behave identically on a dedicated server - but the whole feature is driven from a server-side
setter, and the armory export path uses `stufftext`, which has bitten this project before.
**Test:** the usual dedicated boot + a second client, pick a glove, confirm both players see it on
each other.

### 7.8 Bots

`code/fgame/g_bot.cpp:72` explicitly filters out `_fps.tik` when enumerating bot models. Bots will
therefore take whatever `skinNum` default they get (0 = bare hands). Probably fine; noting it so it
is not a surprise.

### 7.9 Housekeeping found in passing (not a glove problem)

`coop_mod/variables.scr::getNameAppendCommands` declares `local.command["48"]` through `["51"]`
**five times over** - one original plus four verbatim duplicate blocks at the tail. The values are
identical so last-write-wins makes it harmless today, but the next person appending index 52 (which
is exactly what a gloves feature does) will append under a triplicated tail. Worth cleaning first.

---

## Files referenced

Report: `C:\mohaa-coop-dev\hzm-mohaa-coop-mod\_research\gloves_research.md` (this file).

Mod: `coop_mod/helmet.scr`, `coop_mod/player.scr`, `coop_mod/variables.scr`,
`coop_mod/challenges.scr`, `coop_mod/xp.scr`, `coop_mod/dbno.scr`, `coop_mod/loadoutpick.scr`,
`ui/coop_loadout.urc`, `ui/loadout/helm/*.cfg`, `models/player/*_nohat.tik`,
`_research/nohat/nohat_build.py`.

Engine: `code/fgame/entity.cpp`, `code/fgame/sentient.cpp`, `code/fgame/player.cpp`,
`code/fgame/actor.cpp`, `code/cgame/cg_modelanim.c`, `code/qcommon/q_shared.h`,
`code/qcommon/msg.cpp`, `code/tiki/tiki_shared.h`, `code/tiki/tiki_parse.cpp`,
`code/tiki/tiki_files.cpp`, `code/renderergl1/tr_model.cpp`, `code/renderergl2/tr_model.cpp`,
`code/client/cl_uistd.cpp`.
