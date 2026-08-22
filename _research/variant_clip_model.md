# Variant guns show the wrong reload clip in hand — diagnosis

**Reported** 2026-08-20 (live playtest): *"sometimes for these custom guns the clip in their hand is
not from the new gun model but rather the old gun model"*.

**Verdict: PROVEN, one root cause, 247 shipped weapon tiks affected.** The magazine you see in the
hand during a reload is a **separate entity attached by the THIRD-PERSON torso animation**, and the
torso animation is chosen by an **exact full-string weapon-name compare** in the statemap. Every
variant is named `"<Base Gun> (<Finish>)"`, so it fails every name test and falls through to the
class *default* row — `rifle_reload` / `smg_reload` / `mg_reload` / `pistol_reload` — which attach
the **M1 Garand en-bloc clip / Thompson stick mag / BAR mag / Colt 45 mag** respectively.

The first-person side already has the fix (`CoopStripSkinSuffix`). The server-side statemap never
got it. That asymmetry is the whole bug.

This also closes the open question in `docs/OPEN.md:80-86` ("`models/ammo/thompson_clip.tik` is
cached by the weapon tik but nothing in the content or the engine spawns it by name … its source is
still unidentified"). It is spawned by `models/player/base/anims_smg.txt:14`, which lives in the
**retail** `maintt/pak3.pk3` — a file the mod does not ship, which is why every previous search of
the mod tree and the engine came up empty.

---

## 1. How the clip gets on screen (traced end to end)

There are **two** independent clip mechanisms. Only the second one is the reported bug.

### Mechanism A — a surface inside the weapon model (NOT the bug)

The clip inside the gun is a surface of the weapon's own `.skd`, hidden by default and revealed for
the reload frames:

- `hzm-mohaa-coop-mod/models/weapons/m1_garand.tik:13` — `surface material8 shader m1clip`
- `…/m1_garand.tik:137` — `surface material8 +nodraw` (hidden in `init{server{}}`)
- `…/m1_garand.tik:175-181` — `reload garand_reload.skc { server { 28 surface material8 -nodraw ;
  48 surface material8 +nodraw } }`

304 of 481 weapon tiks use this frame-gated pattern. Revealed surface names across the set:
`clip` (98), `material8` (94), `material3` (84), `Clip` (78), `material7` (56), `p38clip` (32),
`g43_Clip` (24), `mp44clip` (24), `fg42clip`, `sten_Clip`, `svt_riflecull`, `shell`, `bazookashell`…

This is (a) in the task's taxonomy: **a surface inside the weapon model itself**, per-tik.

### Mechanism B — a separate entity attached to a hand tag (THIS IS THE BUG)

The hand-held magazine is a real `Animate` entity spawned by the `attachmodel` frame command in the
**third-person torso** animation file — not by the weapon tik, and not by `fps_anims_*`:

```
main/Pak0.pk3, mainta/pak1|pak3.pk3, maintt/pak1|pak3.pk3 ::
models/player/base/anims_rifle.txt:8   rifle_reload  viewmodel/rifle/tps_garand_reload.skc
models/player/base/anims_rifle.txt:14      4  attachmodel models/ammo/garand_clip_reload.tik tag_weapon_right
models/player/base/anims_rifle.txt:16     42  removeattachedmodel tag_weapon_right 0 models/ammo/garand_clip_reload.tik
```

Full alias → attached-clip table, extracted from every `models/player/base/anims_*.txt` in the
retail paks (winning copy under `com_target_game 2` is `maintt/pak3.pk3`):

| torso anim alias | attaches | tag | file:line |
|---|---|---|---|
| `rifle_reload` **(rifle class default)** | `models/ammo/garand_clip_reload.tik` | tag_weapon_right | `anims_rifle.txt:14` |
| `kar98_reload` | `models/ammo/kar98_clip_reload.tik` | tag_weapon_right | `anims_rifle.txt:60` |
| `springfield_reload_loop` | `models/ammo/springfield_clip_reload.tik` | tag_weapon_right | `anims_rifle.txt:37` |
| `svt_reload` | `models/ammo/svt_clip_reload.tik` | tag_weapon_left | `anims_rifle.txt:76` |
| `mosin_reload` | `models/ammo/enfield_clip1.tik` | tag_weapon_right | `anims_rifle.txt:95` |
| `enfield_reload` | `enfield_clip2.tik` + `enfield_clip1.tik` | "Bip01 R Hand" + tag_weapon_right | `anims_rifle.txt:114,115` |
| `g43_reload` | `models/ammo/g43_clip.tik` | tag_weapon_left | `anims_rifle.txt:133` |
| `smg_reload` **(smg class default)** | `models/ammo/thompson_clip.tik` | tag_weapon_left | `anims_smg.txt:14` |
| `ppsh_reload` | `models/ammo/ppsh_clip_reload.tik` | tag_weapon_left | `anims_smg.txt:25` |
| `mg_reload` **(mg class default)** | `models/ammo/bar_clip.tik` | tag_weapon_left | `anims_mg.txt:14` |
| `fg42_reload` | `models/ammo/bar_clip.tik` | tag_weapon_left | `anims_mg.txt:32` |
| `pistol_reload` **(pistol class default)** | `models/ammo/colt_clip.tik` | tag_weapon_left | `anims_pistol.txt:13` |
| `p38_reload` | `models/ammo/p38_clip.tik` | tag_weapon_left | `anims_pistol.txt:24` |
| `histandard_reload` | `models/ammo/silencedpistol_clip.tik` | tag_weapon_left | `anims_pistol.txt:35` |
| `nagantrev_reload_loop` | `models/ammo/nagant_pistol_shell.tik` | tag_weapon_left | `anims_pistol.txt:87` |
| `bazooka_reload` | `models/ammo/bazooka_shell.tik` | — | `anims_bazooka.txt:14` |
| `panzerschreck_reload` | `models/ammo/panzer_shell.tik` | — | `anims_bazooka.txt:30` |

`mp40_reload`, `sten_reload`, `mp44_reload`, `moschetto_reload`, `vickers_reload`, `carcano_reload`,
`delisle_reload`, `enfieldl42a1_reload`, `beretta_reload` attach **nothing** — those guns keep the
magazine on the gun (mechanism A).

**So the answer to "which of (a)/(b)/(c)/(d)" is (d):** the hand clip is supplied *per weapon CLASS*,
globally, by an animation-alias table — not per weapon tik.

### Why it is visible in FIRST person

`attachmodel` builds a real entity parented to the player:

- `openmohaa-hzm/code/fgame/entity.cpp:4435` `Entity::AttachModelEvent`
- `…entity.cpp:4508-4511` — `obj->setModel(modelname); tagnum = gi.Tag_NumForName(edict->tiki, bone);
  obj->attach(this->entnum, tagnum, true, offset)`

so `entityState_t.parent == clientNum` and `tag_num` = `tag_weapon_right`/`_left`. cgame then
re-parents it onto the **first-person hands model** rather than the body:

- `openmohaa-hzm/code/cgame/cg_modelanim.c:1636` — `if (s1->parent != cg.snap->ps.clientNum || bThirdPerson) { …world model… } else {`
- `…cg_modelanim.c:1637` — `tiki = cg.pPlayerFPSModel;`
- `…cg_modelanim.c:1648-1650` — `else if (!Q_stricmp(szTagName, "tag_weapon_right") || !Q_stricmp(szTagName, "tag_weapon_left")) { iTagNum = cgi.Tag_NumForName(tiki, szTagName); CG_AttachEntity(&model, parent, tiki, iTagNum & TAG_MASK, …); }`

That is the *same* branch the view weapon itself uses (the coop ADS sight-rotation block is bolted
onto it immediately below), so the clip is drawn in 1P at the FPS hands' `tag_weapon_*`.

APIs verified against `openmohaa-hzm/code/cgame/cg_public.h`: `R_GetRenderEntity` :318,
`R_Model_GetHandle` :375, `Tag_NumForName` :406, `Tag_NameForNum` :407, `DPrintf` :104,
`Cvar_Get` :122.

---

## 2. Why a variant resolves to the base asset

The torso alias is picked by the mod's own statemap — `coop_mod/server.scr:23` sets
`g_statefile "coop_mod/player"`, so `hzm-mohaa-coop-mod/coop_mod/player_Torso.st` is authoritative.

```
coop_mod/player_Torso.st:2286  state RELOAD_WEAPON
:2290    RELOAD_SPRINGFIELD : IS_WEAPON_ACTIVE "mainhand" "Springfield '03 Sniper"
:2291    RELOAD_SPRINGFIELD : IS_WEAPON_ACTIVE "mainhand" "KAR98 - Sniper"
:2292    RELOAD_SHOTGUN     : IS_WEAPON_ACTIVE "mainhand" "Shotgun"
:2293    RELOAD_NAGANTREV   : IS_WEAPON_ACTIVE "mainhand" "Nagant Revolver"
:2294    RELOAD_WEBLEY      : IS_WEAPON_ACTIVE "mainhand" "Webley Revolver"
:2296    RELOAD_PISTOL      : IS_WEAPONCLASS_ACTIVE "mainhand" "pistol"
:2298    RELOAD_RIFLE       : IS_WEAPONCLASS_ACTIVE "mainhand" "rifle"
…
coop_mod/player_Torso.st:2315  state RELOAD_RIFLE
:2327    kar98_reload   : IS_WEAPON_ACTIVE "mainhand" "Mauser KAR 98K"      <- exact
:2329    enfield_reload : IS_WEAPON_ACTIVE "mainhand" "Lee-Enfield"
:2332    g43_reload     : IS_WEAPON_ACTIVE "mainhand" "G 43"
:2336    rifle_reload   : default                                          <- everything else
```

and the conditional is an **exact, whole-string, case-insensitive compare**:

```c
// openmohaa-hzm/code/fgame/player_conditionals.cpp:219-234
qboolean Player::CondWeaponActive(Conditional& condition)
{
    …
    Weapon *weapon = GetActiveWeapon(hand);
    return (weapon && !Q_stricmp(weaponName, weapon->item_name));
}
```

`weapon->item_name` is the tik's `name` key (`fgame/item.cpp:744-756 Item::setName`), and every
variant tik carries the decorated name:

- `models/weapons/kar98_lv_ttkar98.tik:24` — `name "Mauser KAR 98K (Team Tactics)"`
- `models/weapons/m1_garand_lv_ttgarand.tik:27` — `name "M1 Garand (Team Tactics)"`
- `models/weapons/thompsonsmg_tommy27a1.tik:31` — `name "Thompson (27A1 Commando)"`

`"Mauser KAR 98K (Team Tactics)" != "Mauser KAR 98K"` → `kar98_reload` is skipped → `rifle_reload`
default → **Garand en-bloc clip in the hand of a Kar98**.

**The asymmetry that proves it is an unfinished port, not a design choice:** two other consumers of
the same weapon name already strip the suffix, in this codebase, added 2026-08-17/18:

- `openmohaa-hzm/code/cgame/cg_modelanim.c:1270` — `qboolean CoopStripSkinSuffix(const char *in, char *out, int outSize)` (decl `cg_local.h:540`)
- `…cg_viewmodelanim.c:165` — `if (CoopStripSkinSuffix(szWeaponName, szSkinBase, sizeof(szSkinBase))) { szWeaponName = szSkinBase; }` — so the **first-person hands** anim prefix is correct for variants
- `…cg_modelanim.c:1344` — same call in `CG_FindAdsTune`, so **ADS tuning** is correct for variants

Only the server-side statemap path was left on a raw compare. `CoopStripSkinSuffix` exists **only in
cgame** — there is no fgame copy.

### Why it is "sometimes"

A variant looks *correct* exactly when its base gun already resolves to the class default:
**M1 Garand** (rifle default), **Thompson** (smg default), **BAR** (mg default), **Colt 45** (pistol
default). All Garand/Thompson/BAR/Colt finishes and imports are unaffected. Every other family is
wrong. That is the user's "sometimes".

### Ruled out (tested, not assumed)

| candidate | verdict |
|---|---|
| variant tik `$include`s the base and hard-names the base clip | **No.** No `$include` in any weapon tik; the `cache models/ammo/*_clip_reload.tik` line is a precache only — nothing spawns by that name. |
| clip path absolute in a shared *viewmodel* animation file | **No.** `models/player/base/fps_anims_*.txt` (the files the mod DOES ship) contain zero `attachmodel` — verified across mod tree and all retail paks. |
| variant overrides skin only, so a shared clip surface keeps the base texture | **Real but secondary** — see §3b. It cannot produce "a different model", only a differently-textured one. |
| runtime model swap that never re-runs tag/slot setup (the `OpenSlotsByModel` precedent, `_research/tank_turret_slot_fix.md`) | **No.** The clip is re-created from scratch by a frame command on every reload; there is no persistent tag binding to go stale. |

---

## 3. Which guns are affected

### 3a. Wrong clip MODEL in hand — the reported bug

Measured by simulating `player_Torso.st`'s `RELOAD_WEAPON` → `RELOAD_*` resolution over all 477
weapon tiks that declare `classname Weapon` + a `name`.

**247 tiks total: 51 credited model/skin variants + 196 auto finish treatments.**
Unaffected families: M1 Garand, Thompson, BAR, Colt 45 (their base *is* the class default).

#### The 51 credited / imported variants

| variant tik | in-game name | class | gets in hand | should get |
|---|---|---|---|---|
| `shotgun_authwinch.tik` | Shotgun (Authentic Wood) | heavy | **bazooka/panzer rocket shell** | shotgun_reload_loop |
| `shotgun_dhshotblack.tik` | Shotgun (Black Tactical) | heavy | **bazooka/panzer rocket shell** | shotgun_reload_loop |
| `shotgun_dhshotchrome.tik` | Shotgun (Chrome Tactical) | heavy | **bazooka/panzer rocket shell** | shotgun_reload_loop |
| `shotgun_guanshotty.tik` | Shotgun (Guanshire) | heavy | **bazooka/panzer rocket shell** | shotgun_reload_loop |
| `shotgun_hobbsshotty.tik` | Shotgun (Recoil) | heavy | **bazooka/panzer rocket shell** | shotgun_reload_loop |
| `shotgun_lv_ttshotgun.tik` | Shotgun (Team Tactics) | heavy | **bazooka/panzer rocket shell** | shotgun_reload_loop |
| `mp44_dhstg44ss.tik` | StG 44 (SS Edition) | mg | **bar_clip.tik (BAR mag)** | mp44_reload |
| `mp44_guanmp44.tik` | StG 44 (Guanshire) | mg | **bar_clip.tik (BAR mag)** | mp44_reload |
| `mp44_lv_ttmp44.tik` | StG 44 (Team Tactics) | mg | **bar_clip.tik (BAR mag)** | mp44_reload |
| `mp44_mp44strap.tik` | StG 44 (Strapped) | mg | **bar_clip.tik (BAR mag)** | mp44_reload |
| `it_w_beretta_lv_ttberetta.tik` | Beretta (Team Tactics) | pistol | **colt_clip.tik (Colt 45 mag)** | beretta_reload |
| `p38_guanp38.tik` | Walther P38 (Guanshire) | pistol | **colt_clip.tik (Colt 45 mag)** | p38_reload |
| `p38_lv_ttp38.tik` | Walther P38 (Team Tactics) | pistol | **colt_clip.tik (Colt 45 mag)** | p38_reload |
| `webley_revolver_lv_ttwebley.tik` | Webley Revolver (Team Tactics) | pistol | **colt_clip.tik (Colt 45 mag)** | WEBLEY_reload_start |
| `G43_dhg43fleck.tik` | G 43 (Flecktarn) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | g43_reload |
| `G43_hobbsg43urb.tik` | G 43 (Urban Camo) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | g43_reload |
| `G43_hobbsg43wood.tik` | G 43 (Woodland Camo) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | g43_reload |
| `G43_lv_ttg43.tik` | G 43 (Team Tactics) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | g43_reload |
| `KAR98sniper_g98scope.tik` | KAR98 - Sniper (G98 Scoped) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | springfield_reload_loop |
| `KAR98sniper_lv_98ks.tik` | KAR98 - Sniper (98 KS) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | springfield_reload_loop |
| `KAR98sniper_lv_ttkar98sn.tik` | KAR98 - Sniper (Team Tactics) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | springfield_reload_loop |
| `delisle_lv_ttdelisle.tik` | DeLisle (Team Tactics) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | delisle_reload |
| `delisle_lv_wdelisle.tik` | DeLisle (Wehrmacht) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | delisle_reload |
| `enfield_hobbsenfurb.tik` | Lee-Enfield (Urban Camo) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | enfield_reload |
| `enfield_lv_ttenfield.tik` | Lee-Enfield (Team Tactics) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | enfield_reload |
| `enfield_p14.tik` | Lee-Enfield (P14 Enfield) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | enfield_reload |
| `it_w_carcano_lv_ttcarcano.tik` | Carcano (Team Tactics) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | carcano_reload |
| `kar98_g98.tik` | Mauser KAR 98K (Gewehr 98) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | kar98_reload |
| `kar98_hobbskarwood.tik` | Mauser KAR 98K (Woodland Camo) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | kar98_reload |
| `kar98_hobbskarworn.tik` | Mauser KAR 98K (Worn) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | kar98_reload |
| `kar98_lv_ttkar98.tik` | Mauser KAR 98K (Team Tactics) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | kar98_reload |
| `mosin_nagant_rifle_hobbsmosinur.tik` | Mosin Nagant Rifle (Urban Camo) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | mosin_reload |
| `mosin_nagant_rifle_lv_ttmosin.tik` | Mosin Nagant Rifle (Team Tactics) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | mosin_reload |
| `springfield_dhspdesert.tik` | Springfield '03 Sniper (Desert Camo) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | springfield_reload_loop |
| `springfield_dhspdigital.tik` | Springfield '03 Sniper (Digital Camo) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | springfield_reload_loop |
| `springfield_dhsptiger.tik` | Springfield '03 Sniper (Tiger Camo) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | springfield_reload_loop |
| `springfield_dhspwinter.tik` | Springfield '03 Sniper (Winter Camo) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | springfield_reload_loop |
| `springfield_guansp2.tik` | Springfield '03 Sniper (Guanshire II) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | springfield_reload_loop |
| `springfield_guansplight.tik` | Springfield '03 Sniper (Lightwood) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | springfield_reload_loop |
| `springfield_hobbsspurban.tik` | Springfield '03 Sniper (Urban Camo) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | springfield_reload_loop |
| `springfield_hobbsspwood.tik` | Springfield '03 Sniper (Woodland Camo) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | springfield_reload_loop |
| `springfield_lv_ttspring.tik` | Springfield '03 Sniper (Team Tactics) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | springfield_reload_loop |
| `springfield_m1903.tik` | Springfield '03 Sniper (M1903 Springfield) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | springfield_reload_loop |
| `springfield_smlescope.tik` | Springfield '03 Sniper (SMLE Scoped) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | springfield_reload_loop |
| `svt_rifle_hobbssvtwood.tik` | SVT 40 (Woodland Camo) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | svt_reload |
| `uk_w_l42a1_dhl42camo.tik` | Enfield L42A1 (Camo) | rifle | **garand_clip_reload.tik (M1 en-bloc)** | enfieldl42a1_reload |
| `mp40_guanmp40.tik` | MP40 (Guanshire) | smg | **thompson_clip.tik (Thompson stick)** | mp40_reload |
| `mp40_guanmp40s.tik` | MP40 (Silver) | smg | **thompson_clip.tik (Thompson stick)** | mp40_reload |
| `mp40_lv_mp75.tik` | MP40 (MP 75 Ausf D) | smg | **thompson_clip.tik (Thompson stick)** | mp40_reload |
| `mp40_mp18.tik` | MP40 (MP18) | smg | **thompson_clip.tik (Thompson stick)** | mp40_reload |
| `mp40_mp40r2.tik` | MP40 (Reactivated) | smg | **thompson_clip.tik (Thompson stick)** | mp40_reload |

#### The 196 finish treatments (bloody / blued / chrome / gold / camo_desert|winter|woodland)

| base gun | class | finishes affected | gets in hand | should get |
|---|---|---:|---|---|
| Beretta | pistol | 7 | **colt_clip.tik** | beretta_reload |
| Carcano | rifle | 14 | **garand_clip_reload.tik** | carcano_reload |
| DeLisle | rifle | 7 | **garand_clip_reload.tik** | delisle_reload |
| Enfield L42A1 | rifle | 7 | **garand_clip_reload.tik** | enfieldl42a1_reload |
| FG 42 | mg | 7 | **bar_clip.tik** | fg42_reload |
| G 43 | rifle | 7 | **garand_clip_reload.tik** | g43_reload |
| Gewehrgranate | heavy | 7 | **rocket shell** | kar98_reload |
| Hi-Standard Silenced | pistol | 7 | **colt_clip.tik** | histandard_reload |
| KAR98 - Sniper | rifle | 7 | **garand_clip_reload.tik** | springfield_reload_loop |
| Lee-Enfield | rifle | 14 | **garand_clip_reload.tik** | enfield_reload |
| MP40 | smg | 7 | **thompson_clip.tik** | mp40_reload |
| Mauser KAR 98K | rifle | 14 | **garand_clip_reload.tik** | kar98_reload |
| Moschetto | smg | 7 | **thompson_clip.tik** | moschetto_reload |
| Mosin Nagant Rifle | rifle | 14 | **garand_clip_reload.tik** | mosin_reload |
| Nagant Revolver | pistol | 7 | **colt_clip.tik** | nagantrev_reload_loop |
| PPSH SMG | smg | 7 | **thompson_clip.tik** | ppsh_reload |
| SVT 40 | rifle | 7 | **garand_clip_reload.tik** | svt_reload |
| Shotgun | heavy | 7 | **rocket shell** | shotgun_reload_loop |
| Springfield '03 Sniper | rifle | 7 | **garand_clip_reload.tik** | springfield_reload_loop |
| StG 44 | mg | 7 | **bar_clip.tik** | mp44_reload |
| Sten Mark II | smg | 7 | **thompson_clip.tik** | sten_reload |
| Vickers-Berthier | mg | 7 | **bar_clip.tik** | vickers_reload |
| Walther P38 | pistol | 7 | **colt_clip.tik** | p38_reload |
| Webley Revolver | pistol | 7 | **colt_clip.tik** | WEBLEY_reload_start |

**Bigger than the clip.** Because the *whole torso reload animation* is misrouted, these variants
also play the wrong reload gesture and (for the springfield/kar98-sniper/shotgun/nagant/webley
families) the wrong reload *style* entirely: the single-shell fill loop becomes a one-shot en-bloc
push. The 1P hands still play the right animation (`CG_GetVMAnimPrefixIndex` strips the suffix), so
hands and body disagree — which is exactly what makes the wrong clip so noticeable.

### 3b. Wrong clip TEXTURE on the gun's own clip surface — secondary, cosmetic

Separate, smaller, mechanism-A defect. 53 variant tiks re-skin the gun body but leave the
reload-revealed surface on the base shader (141 other variants do re-skin it correctly):

| shader kept | tiks | notable |
|---|---:|---|
| `m1clip` | 50 surface-pairs | `m1_garand_lv_ttgarand.tik:13`, `m1_garand_pagarand.tik:13`, all `kar98_hobbskar*` / `kar98_lv_ttkar98.tik:10-11`, all `kar98_mortar_*`, all `johnson_m1941_*:36-37`, all M1 Garand finishes |
| `bazookashell` | 16 | all `bazooka_*`, all `panzerschreck_*` |
| `ThompsonSMG` | 1 | `thompsonsmg_tommy27a1.tik:13` (`surface Clip shader ThompsonSMG`) |
| `colt` | 2 | `colt45_guancolt.tik:10`, `colt45_lv_ttcolt.tik:10` |
| `shellmetal` | 1 | `webley_revolver_lv_ttwebley.tik:9` |

Note the base guns often share `m1clip` too (`kar98.tik:10-11` uses it), so several of these are
inherited retail behaviour, not variant regressions.

### 3c. Inert nodraw gating on model-swapped variants — cosmetic, low priority

16 variants ship their own `path`/`skelmodel` but keep the base tik's surface names in the
frame-gated nodraw commands. Verified by reading surface names out of the `.skd`s:

- `models/weapons/coop_pagarand/garand.skd` **has** `material8` → gating works (`m1_garand_pagarand.tik`)
- `models/weapons/coop_tommy27a1/ThompsonSMG.skd` **has** `Clip` → gating works
- `models/weapons/coop_g98/KAR98.skd` has a single surface `material`, **not** `material7`/`material8`
  → `kar98_g98.tik:142-143` `surface material7|8 +nodraw` are silent no-ops

83 tik/surface pairs name a surface in a nodraw command with no matching `surface … shader` line in
that tik; worth a sweep, but none of it produces a *wrong model in hand*.

---

## 4. The fix

### Recommended — Fix B: strip the finish suffix in `Player::CondWeaponActive` (engine, game.dll)

Mirror what cgame already does. One function, ~12 lines, `openmohaa-hzm/code/fgame/player_conditionals.cpp`.

```c
// --- add near the top of player_conditionals.cpp -------------------------------
//
// HZM coop [user 2026-08-20] "the clip in their hand is not from the new gun model".
// A skin/model variant is named "<Base Gun> (<Finish>)". IS_WEAPON_ACTIVE was an exact
// whole-string compare, so EVERY variant failed every name row in player_Torso.st and fell
// through to the class default reload alias - rifle_reload/smg_reload/mg_reload/pistol_reload -
// which are the M1 Garand / Thompson / BAR / Colt reloads and attach THEIR magazine to the hand
// (models/player/base/anims_rifle.txt:14 etc., retail maintt/pak3.pk3). cgame already strips the
// suffix in CG_GetVMAnimPrefixIndex (cg_viewmodelanim.c:165) and CG_FindAdsTune
// (cg_modelanim.c:1344) via CoopStripSkinSuffix; the server statemap never got the same
// treatment. A skin must never change how a weapon animates - that is what makes it a skin.
//
static qboolean CoopStripSkinSuffix(const char *in, char *out, int outSize)
{
    const char *paren;
    int         len;

    if (!in || !*in || !out || outSize <= 0) {
        return qfalse;
    }
    paren = strstr(in, " (");
    if (!paren) {
        return qfalse;
    }
    len = (int)(paren - in);
    if (len <= 0 || len >= outSize) {
        return qfalse;
    }
    memcpy(out, in, len);
    out[len] = 0;
    return qtrue;
}

// --- replace the body of Player::CondWeaponActive (line 219) -------------------
qboolean Player::CondWeaponActive(Conditional& condition)
{
    const char  *weaponName;
    weaponhand_t hand;
    char         base[64];

    weaponName = condition.getParm(2);
    hand       = WeaponHandNameToNum(condition.getParm(1));

    if (hand == WEAPON_ERROR) {
        return false;
    }

    Weapon *weapon = GetActiveWeapon(hand);

    if (!weapon) {
        return false;
    }
    // Exact still wins, so a variant CAN be given its own statemap row later - place any such
    // row ABOVE the base row, because the stripped compare below will otherwise match first.
    if (!Q_stricmp(weaponName, weapon->item_name)) {
        return true;
    }
    if (CoopStripSkinSuffix(weapon->item_name.c_str(), base, sizeof(base))) {
        return (!Q_stricmp(weaponName, base));
    }
    return false;
}
```

**Cost / risk**

- 1 file, ~30 lines. **game.dll only** — needs the CMake build, deploys to `G:\mohaa-gl2\` **and**
  the GOG root (bug-1634). `cgame.dll` / `openmohaa.exe` unchanged, no protocol constant touched.
- Fixes all 247 tiks at once, and every future variant automatically.
- Fixes the reload *gesture and style* too, not just the clip.
- Also corrects the 361 `IS_WEAPON_ACTIVE` rows in `player_Torso.st` and the 168 in
  `player_legs.st` for variants — all of them currently mis-fire the same way.
- **Safety proven, not assumed:** all 385 shipped weapon names containing `" ("` have a prefix that
  is one of the 44 real base weapon names. There is no gun whose name would be wrongly collapsed.
- **Verifiable without a playtest**: run the resolution simulator in §5 note, or read
  `docs/tools/` — the mapping is a pure function of the tik `name` + `weapontype` + the statemap.

### Fallback — Fix A: enumerate every variant in the statemap (data-only, no build)

`coop_mod/player_Torso.st` ships in the pk3, so this needs **no engine build** — just `.\build.ps1`.
Add an `IS_WEAPON_ACTIVE` row per variant name:

- `RELOAD_WEAPON` (`:2286`) needs rows for the 4 special-style families → 6 shotgun + 3 kar98sniper +
  18 springfield + 7 nagant + 8 webley ≈ **42 rows**
- `RELOAD_RIFLE` (`:2315`), `RELOAD_SMG` (`:2351`), `RELOAD_MG` (`:2383`), `RELOAD_PISTOL` (`:2411`)
  need one row per affected variant → **~247 rows**

Generatable (the project already generates `coop_mod/loadoutskins_base.scr` with
`docs/tools/gen_skinbase.py`; the same table drives this). But it must be regenerated every time a
variant is added, and `.st` files are parse-fragile. **Use only if a game.dll ship is unacceptable.**

### Rejected

- **Per-variant clip assets** (`models/ammo/<variant>_clip.tik`): nothing can select them —
  the attach is hard-named in a retail animation file, keyed to the alias, not the weapon.
- **Ship our own `anims_rifle.txt`/`anims_smg.txt`**: the alias *content* is not the problem; the
  alias *selection* is. One alias cannot serve all rifles.
- **Resolve the clip from the equipped weapon at attach time in cgame**: the clip entity is created
  server-side with a fixed model; cgame only re-parents it. Wrong layer.
- **`Item::EventViewModelPrefix`** (`fgame/item.cpp:898`): `#ifdef OPM_FEATURES` and gated on
  `sv_specialgame` — not a usable route here.

### Optional follow-up (data-only, ships with any pk3 build)

For §3b, give each variant's clip surface its own shader. 53 tiks, one line each, e.g.
`m1_garand_lv_ttgarand.tik:13` `surface material8 shader m1clip` →
`surface material8 shader coop_v3_lv_ttgarand_m1clip` (plus the shader + texture).
`m1_garand_guangarand.tik:13` already does this correctly — copy that pattern.

---

## 5. Verification probe

Insert in `openmohaa-hzm/code/fgame/entity.cpp`, **immediately after line 4508**
(`obj->setModel(modelname);`) inside `Entity::AttachModelEvent`. `entity.cpp` already includes
`player.h` (:52), already uses `IsSubclassOfPlayer()` (:2741) and `Player *` casts (:6549);
`Sentient::GetActiveWeapon` is public (`sentient.h:297`).

```c
    obj->setModel(modelname);

    // HZM coop [user 2026-08-20] clip-in-hand probe. coop_clipDebug 1 prints, for every model the
    // torso reload animation attaches to a player's hand, the weapon actually held and the model
    // that got attached. CORRECT = the clip belongs to the held gun. WRONG = a variant name with a
    // "(Finish)" suffix paired with the class-default clip (garand/thompson/bar/colt).
    if (IsSubclassOfPlayer()) {
        static cvar_t *pClipDbg = NULL;
        if (!pClipDbg) { pClipDbg = gi.Cvar_Get("coop_clipDebug", "0", 0); }
        if (pClipDbg->integer) {
            Weapon *w = ((Player *)this)->GetActiveWeapon(WEAPON_MAIN);
            gi.Printf(
                "^~^~^ CLIPDBG wpn='%s' class=0x%x tag='%s' attach='%s'\n",
                w ? w->item_name.c_str() : "<none>",
                w ? w->GetWeaponClass() : 0,
                bone.c_str(),
                modelname.c_str()
            );
        }
    }
```

Enable with `coop_clipDebug 1`; read `%APPDATA%\openmohaa\maintt\qconsole.log` (or drive it over
rcon per `dev_test_workflow`). Reload each gun once.

**Correct output** (base Kar98, and every variant after Fix B):

```
^~^~^ CLIPDBG wpn='Mauser KAR 98K (Team Tactics)' class=0x8 tag='tag_weapon_right' attach='models/ammo/kar98_clip_reload.tik'
^~^~^ CLIPDBG wpn='MP40 (Guanshire)'              class=0x10 tag='tag_weapon_left'  attach='(no line at all - MP40 attaches nothing)'
^~^~^ CLIPDBG wpn='Walther P38 (Guanshire)'       class=0x4  tag='tag_weapon_left'  attach='models/ammo/p38_clip.tik'
```

**Incorrect output** (today, pre-fix — the signature to look for is a `(Finish)` name next to a
class-default clip):

```
^~^~^ CLIPDBG wpn='Mauser KAR 98K (Team Tactics)' class=0x8  tag='tag_weapon_right' attach='models/ammo/garand_clip_reload.tik'
^~^~^ CLIPDBG wpn='MP40 (Guanshire)'              class=0x10 tag='tag_weapon_left'  attach='models/ammo/thompson_clip.tik'
^~^~^ CLIPDBG wpn='StG 44 (Team Tactics)'         class=0x20 tag='tag_weapon_left'  attach='models/ammo/bar_clip.tik'
^~^~^ CLIPDBG wpn='Walther P38 (Guanshire)'       class=0x4  tag='tag_weapon_left'  attach='models/ammo/colt_clip.tik'
```

A **static** pre-check needing no game at all: for any tik, read its `name` and `weapontype`, walk
`coop_mod/player_Torso.st` `RELOAD_WEAPON` → `RELOAD_*` top-down with an exact-string compare, then
look the resulting alias up in the §1 table. If the alias is `rifle_reload`/`smg_reload`/
`mg_reload`/`pistol_reload` and the gun is not a Garand/Thompson/BAR/Colt, the clip will be wrong.

---

## References

| what | where |
|---|---|
| exact-name conditional (root cause) | `openmohaa-hzm/code/fgame/player_conditionals.cpp:219-234` |
| torso reload dispatch + alias tables | `hzm-mohaa-coop-mod/coop_mod/player_Torso.st:2286, 2315, 2351, 2383, 2411` |
| statemap is ours | `hzm-mohaa-coop-mod/coop_mod/server.scr:23` (`g_statefile "coop_mod/player"`) |
| the attach itself | retail `models/player/base/anims_rifle.txt:14` / `anims_smg.txt:14` / `anims_mg.txt:14` / `anims_pistol.txt:13` (maintt/pak3.pk3) |
| attach → entity | `openmohaa-hzm/code/fgame/entity.cpp:4435, 4508-4511` |
| entity → first-person hands | `openmohaa-hzm/code/cgame/cg_modelanim.c:1636-1650` |
| the strip helper cgame already has | `openmohaa-hzm/code/cgame/cg_modelanim.c:1270`, decl `cg_local.h:540` |
| 1P prefix already strips | `openmohaa-hzm/code/cgame/cg_viewmodelanim.c:148, 165` |
| ADS tune already strips | `openmohaa-hzm/code/cgame/cg_modelanim.c:1344` |
| `name` → `item_name` | `openmohaa-hzm/code/fgame/item.cpp:744-756` |
| weapontype → class bits | `openmohaa-hzm/code/fgame/weapon.cpp:1270`, `g_utils.cpp:1942` |
| prior open question, now answered | `docs/OPEN.md:80-86` |
