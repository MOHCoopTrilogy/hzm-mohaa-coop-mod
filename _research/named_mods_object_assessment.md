# Named-Mods Object Assessment — 5 community mods for build-mode objects

Date: 2026-07-18
Question: Do these 5 MOHAA community mods provide NEW spawnable OBJECTS/MODELS
(props / statics / world / vehicles / furniture — placeable as `script_model`) we
could mine for the build-mode catalog, or are they pure texture / script / campaign
mods with nothing new to place?

Scope note: a sibling agent is mining mohaareunited (MOHAARU) map packs — already
present at `G:\mohaa_custom_maps\*MOHAARU_Map_Pack.pk3`. Another agent inventories the
trilogy + local mods. This report covers ONLY the 5 named mods below.

---

## VERDICT TABLE (ranked by new-placeable-object value, highest first)

| # | Mod | What it is | MOHAA version | NEW PLACEABLE MODELS? | Download source + size | Recommendation |
|---|-----|-----------|---------------|----------------------|------------------------|----------------|
| 1 | **1936** | Spanish Civil War total conversion (play republican or rebel) | BT-only (needs AA+SH+BT, patch 2.4) | **MAYBE — LOW/MOD.** Genuinely new *weapon* models (Spanish Mauser 1893, Mauser Oviedo 1916, Arisaka, Mauser C96, Astra 903) + reskinned faction characters. Static props/architecture UNVERIFIED (need to unzip). Weapons aren't build statics. 2005-era low-poly, off-theme (SCW, not WW2). | ModDB `1936 ver 0.77` Full Version (BT only). Older v0.5 was GameSpy (dead). Single archive, size not shown on page (~tens of MB). | **MINE-IF-CURIOUS** — download & grep `models/statweapons`, `models/static`, `models/furniture` for `.tik` absent from vanilla. Expect modest yield; theme + poly quality limit reuse in a WW2 coop catalog. |
| 2 | **War Chest Restored** | Cut/unused SP content re-implemented "as accurate as possible" from dev media; also fixes/QoL + extended BT finale | AA + SH + BT | **MAYBE — LOW/MOD.** Author lists "models" among restored content. Some may be *new/rebuilt* props recreating cut content; most "restored" assets are vanilla-but-unused models (already in pak0-6, already placeable by us). Primarily map/global SCRIPTS + campaign, not a prop library. | ModDB (creator **Metlar**), `War Chest Restored v1.1` Full Version + patch v1.1.1. Mod total **373.1 MB** (4 files). | **MINE-IF-CURIOUS** — unzip v1.1, diff its `models/` tree vs vanilla for any *new* prop/vehicle `.tik`. Low-moderate yield; it's a campaign restoration, not an object pack. |
| 3 | **Hi-Res Realism Remaster (HRRTM)** | HD retexture/remaster: character remodels, HD weapon & vehicle retextures, restored animations/scripts | AA (+SH/BT skins) | **NO new placeable statics.** `.tik` files are HD REMODELS/retextures of EXISTING entities (AI_heer_late German soldiers, HD weapons, HD tiger/opel/sdkfz/bmwbike — all already-existing models). Pak7 "RestoredContent" is 4,797 `.skc` animations + scripts, only 71 `.tik` / 4 `.skd`. No new static/furniture/prop meshes. | **ALREADY LOCAL** — `_hd_staging/hdweapons/zzzzzz-HRRTM_Pak1..7*.pk3` + partly deployed to `G:\...\maintt\`. | **ALREADY-HAVE / SKIP for build objects** — it's a retexture set (same lineage as the AA_HD_Project already deployed). Nothing new to *place*. |
| 4 | **Pak9RtCW CoD** | Tiny weapon-tweak / script patch by grossmarschall: "edited game weapons, fixed weapon sounds in ubersound.scr, all missions available" | AA | **NO.** 49.97 KB Patch — physically too small to hold any model (one `.skd` alone often exceeds that). Pure script/config. | ModDB `grossmarschall/downloads` → "Pak9RtCW CoD", **49.97 KB**, May 17 2022. | **SKIP — script-only.** Name is misleading; no RtCW/CoD models here. |
| 5 | **Blurred Remembrance** | Standalone conversion that BUNDLES other authors' mods (HD textures + HD weapon retextures + 7 campaigns + ironsights + a different coop mod) | AA + SH + BT (standalone) | **NO original models.** "Models" credited are all third-party HD weapon RETEXTURES (val50 Garand/shell/viewsleeves, MOHAA HD by EOI, Perfect Assault, Newlight). No new placeable statics. | ModDB `medal-of-honor-blurred-remembrance`, 5-part download + installer (v1.61). Large (full-game conversion). | **SKIP — retexture compilation.** No original objects; redistributing = ~10 authors' work (attribution minefield). We already have equivalent HD sets locally. |

---

## Per-mod detail

### 1. 1936 — Spanish Civil War Total Conversion  (best new-asset candidate)
- ModDB `moddb.com/mods/1936`, creator **yochoylamuete**, released 2005, latest **v0.77** (May 2016). Homepage 1936.jolt.co.uk (dead).
- **Breakthrough ONLY**; requires MOHAA + SH + BT. Ships as `.pk2` (`zPak1936a.pk2`) — must sort last alphabetically. Spanish UI.
- Confirmed NEW weapon models (period-correct SCW arms). As a full TC it almost certainly reskins/adds faction characters and *may* include new Spanish-architecture map props — but that is UNVERIFIED without unzipping.
- Fit caveat: Spanish Civil War aesthetic and 2005 poly budget don't match a WW2 coop build catalog. Weapon models ≠ build-mode statics.

### 2. War Chest Restored  (cut-content campaign restoration)
- ModDB `moddb.com/mods/war-chest-restored`, creator **Metlar**, released Apr 5 2026, **v1.1** (Apr 30 2026) + patch **v1.1.1** (May 20 2026). Mod total **373.1 MB**.
- Restores cut/unused content across AA/SH/BT: map scripts, global scripts, models, textures, dialogues, SFX; plus fixes and an extended BT escape finale.
- Value for build objects is genuinely uncertain: cut-content "models" are often vanilla-but-unreferenced assets (we can already place those) rather than new mesh files. Worth a diff-vs-vanilla pass only if hungry for a few restored props.

### 3. Hi-Res Realism Remaster (HRRTM) — ALREADY LOCAL, retexture only
- Present locally: `_hd_staging/hdweapons/zzzzzz-HRRTM_Pak1_Models.pk3` … `Pak7_RestoredContent.pk3` (+ Blood addon, Pak4c WeaponTGA). Pak1/2/4/4c/Blood also deployed to `G:\GOG\...\maintt\`.
- Contents: Pak1 = HD `models/human/AI_heer_late/*` German-soldier remodels + a few HD `models/vehicles/tiger*/sdkfz*` `.tik`; Pak2 = HD gear/character skds + HD opel/bmwbike/sdkfz; Pak3 = textures; Pak4 = HD weapon models; Pak5/6 = globals/scripts; Pak7 = 4,797 `.skc` restored animations + `.lip`/`.scr` (only 71 `.tik`, 4 `.skd`).
- Every `.tik` is a higher-fidelity version of an entity the game/HD project already has. **No new object categories to place.**

### 4. Pak9RtCW CoD — 50 KB script patch (the file the user named)
- ModDB `grossmarschall/downloads` → "Pak9RtCW CoD", category **Patch**, **49.97 KB**, May 17 2022, tagged Medal of Honor: Allied Assault.
- Does: edits weapon stats, fixes `ubersound.scr` weapon sounds, unlocks all missions. **Contains no models.**
- grossmarschall's actual "Model" addons are FOR other games, not ported INTO MOHAA: "Awakened" (RtCW realism model pack, by Captain Bob, 5.82 MB, *for RtCW*) and "iw 25" (CoD2 weapon model, 236 KB, *for CoD2*). His MOHAA content is all patches / de-nazified texture skin-packs / audio.

### 5. Blurred Remembrance — compilation, no original models
- ModDB `medal-of-honor-blurred-remembrance`, by **_UNWRITTEN / ZYQUIST / DERRULB**, released 2016, current **v1.61**. Five-part download + installer + GFX guide.
- Explicitly a standalone conversion that combines OTHER mods. Credited "Textures & Models": Newlight (imtheheadhunter), MOHAA High Definition (EOI team), Perfect Assault v2/v3 (Jakob93), Realistic Blood (AresKiller), val50 HD Garand/shells/viewsleeves. Campaigns/ironsights/coop all third-party. Its bundled coop mod is Marvin_hun & S.D.A. — a DIFFERENT coop mod, not HZM.
- Nothing original to mine; anything useful (HD textures / HD weapon retextures) we already hold locally.

---

## Bottom line & recommendation

**None of the 5 is a rich source of new placeable build-mode statics/props.** Ranked
by likelihood of yielding *any* genuinely new placeable object:

1. **1936** and **2. War Chest Restored** are the only two with a plausible chance of
   new/rebuilt prop or statweapon meshes. If the user wants to spend the effort, download
   both to a staging folder (e.g. `G:\mohaa_custom_maps\_named_mods\` or a `_staging`
   dir), unzip, and diff their `models/` trees vs vanilla — specifically
   `models/static`, `models/furniture`, `models/miscobj`, `models/statweapons`,
   `models/vehicles` — keeping only `.tik`/`.skd` absent from pak0-6. Expect **modest**
   yield; 1936 is off-theme (Spanish Civil War, 2005-era) and War Chest Restored is
   primarily a campaign/script restoration.
2. **HRRTM (#3)** — already local; retexture set, nothing new to place. Skip for objects.
3. **Pak9RtCW CoD (#5)** — 50 KB script patch, no models. Skip.
4. **Blurred Remembrance (#2)** — third-party compilation, no original models,
   redistribution/attribution risk. Skip.

If the underlying goal is "RtCW/CoD props/buildings/vehicles ported into MOHAA," **none
of these deliver it.** The file the user named ("Pak9RtCW CoD") is a script patch, and
the only real RtCW→MOHAA porting effort seen (a separate mohaaaa.co.uk "RtCW mod for
MOHAA") ports WEAPONS (FG42, Luger) + German character skins/voices — again not world
props. A dedicated RtCW/CoD *prop/building* port into MOHAA was not found.

## Attribution / IP caveats (user decides)
- **RtCW / CoD assets** = id Software / Activision / Infinity Ward IP. Any port of their
  models into a public mod is a copyright concern — flag before shipping. (Moot for the
  named 50 KB patch, which has no models.)
- **1936** — TC by yochoylamuete; may contain third-party assets. Reuse needs permission
  + attribution.
- **War Chest Restored** — by Metlar; recreates EA/2015 cut content (EA IP). Reuse needs
  Metlar's permission.
- **Blurred Remembrance** — aggregates ~10 authors; redistributing any part is an
  attribution minefield.
- **HRRTM** — local already; retexture, but still third-party — attribution applies if
  any asset is shipped in the coop pk3.
