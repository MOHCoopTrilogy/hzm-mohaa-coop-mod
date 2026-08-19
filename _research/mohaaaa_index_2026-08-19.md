# mohaaaa.co.uk Full Mod Index - Weapon Skins/Variants Crawl (2026-08-19)

Companion to `skins_hunt_2026-08-19.md` (which flagged this index as "best next dig") and
`_dp28/ds_items.tsv` (343-item DS-Servers/FileFront weapon-skins index used for the diff below).

## Coverage method / completeness

- **Method: live crawl of the real site** (not search reconstruction). The site sits behind an
  Anubis anti-bot proof-of-work; plain fetches get 403 "Access Denied". A real browser session
  solved the challenge, then the Drupal exposed-filter listing was enumerated by category and the
  item pages were fetched same-origin from within the session.
- **Enumeration is exhaustive, not sampled**: `mohaamodsfullindex` filtered by Type of Mod =
  *Weapon Skins* -> 5 pages / **219 items** (terminal page confirmed by pager). Cross-checked for
  weapon items filed under other types: *Scopes* (6), *Texture* (22, 4 weapon-adjacent kept),
  *Weapon* client-side (25, packs/model-replacements kept), all-types weapon-subcategory sweep (33),
  *MISC* client-side (3, none relevant), and an empty-Type probe (**0 items** - no uncategorised mods
  exist, so category filtering cannot have missed anything).
- **All 249 catalogued weapon-visual item pages were fetched** for hosted file name, download count,
  original-FileFront link and readme/permission text.
- **Believed coverage: ~100% of the site's weapon skin/model listings.** Residual risk is limited to a
  weapon skin somebody filed under Sound/Map/Player Skins with a non-weapon subcategory; the subcat
  sweep found no evidence of that.
- **File sizes are NOT displayed anywhere on the site** (item pages show a download *count* instead),
  so sizes are omitted. Download-count standouts (proxy for quality/popularity): Ironsights v2 = 2,044,
  Genocide Weapons MOD = 1,302, 2020 Commando = 1,313, 1928 Tommy Gun = 1,164, Extra WW2 update 2 = 868,
  Renegade AW50 = 828, City Nights Weapons Pack = 827.
- Download page URL pattern: `https://mohaaaa.co.uk/AAAAMOHAA/content/<slug>` - the hosted file link
  sits on that page. **No files were downloaded.**
- Dedup basis: token-diff of all 249 items against the 343-item DS tsv + manual verification of every
  match (compound DS slugs like `brutalkar98-zip-2` defeat naive tokenising, so each pair was eyeballed).
  Items marked FileFront-origin carry the FF id from the item page for cross-checking other DS categories.

**Tallies: 249 catalogued | 184 unique finds | 25 already in named known-sets | 40 confirmed already in the DS 343 tsv (or authorship already resolved locally) | 5 ambiguous (flagged inline).**

## Unique finds (not in known sets, not matched in the DS 343 tsv)

### Multi-gun packs & conversions (highest value)

- **RoempaZ Modern Weapon Pack** - RoempaZ - multi - https://mohaaaa.co.uk/AAAAMOHAA/content/roempaz-modern-weapon-pack
- **City Nights Weapons Pack** - City Nights Team - multi - https://mohaaaa.co.uk/AAAAMOHAA/content/city-nights-weapons-pack (DS-ambig: DS has only city-nights-final-ak47 - full pack is here)
- **Soares93's Mosin Nagant Sniper Pack** - Soares93 - Springfield/KAR98K - https://mohaaaa.co.uk/AAAAMOHAA/content/soares93s-mosin-nagant-sniper-pack
- **Soares93's M1 Carbine Pack** - Soares93 - M1 Garand - https://mohaaaa.co.uk/AAAAMOHAA/content/soares93s-m1-carbine-pack
- **Weapons MOD (Genocide)** - Genocide - multi - https://mohaaaa.co.uk/AAAAMOHAA/content/weapons-mod (ext: modtheater.com)
- **AA Weapons Converted (to MOHPA)** - MarcusG - multi - https://mohaaaa.co.uk/AAAAMOHAA/content/aa-weapons-converted
- **Genos Weapon Mod** - GENOS - multi - https://mohaaaa.co.uk/AAAAMOHAA/content/genos-weapon-mod
- **Medal of Horror - Weapons & HUD Pack** - FOREIGN LEGION - multi - https://mohaaaa.co.uk/AAAAMOHAA/content/medal-horror-weapons-hud-pack
- **SH & BT Weapons to AA Conversion** - SoRrIdStRoKeR - multi - https://mohaaaa.co.uk/AAAAMOHAA/content/sh-bt-weapons-aa-conversion

### Soares93 items NOT in your known Luger/MG42/ExtraWW2 set (author active, easy permission)

- **Jackson Springfield Reskin** - Soares93 - Springfield - https://mohaaaa.co.uk/AAAAMOHAA/content/jackson-springfield-reskin
- **Soares93 Kar98 and MP40 reskins** - Soares93 - KAR98K+MP40 - https://mohaaaa.co.uk/AAAAMOHAA/content/soares93-kar98-and-mp40-reskins
- **Soares93's Gewehr 43** - Soares93 - KAR98K - https://mohaaaa.co.uk/AAAAMOHAA/content/soares93s-gewehr-43
- **Deadfall Adventures P38 models** - Soares93 - Walther P38 - https://mohaaaa.co.uk/AAAAMOHAA/content/deadfall-adventures-p38-models
- **Soares93's animated COD luger** - Soares93 - Walther P38 - https://mohaaaa.co.uk/AAAAMOHAA/content/soares93s-animated-cod-luger
- **Call of Duty: World at War Scopes** - Soares93 - scopes - https://mohaaaa.co.uk/AAAAMOHAA/content/call-duty-world-war-scopes (note: free-to-use with credit)

### Renegade modern-weapon set (16 items, never on FileFront)

- **AK47 (Renegade)** - Renegade - StG 44 - https://mohaaaa.co.uk/AAAAMOHAA/content/ak47-1
- **Galil 223** - Renegade - MP40 - https://mohaaaa.co.uk/AAAAMOHAA/content/galil-223
- **M60** - Renegade - BAR - https://mohaaaa.co.uk/AAAAMOHAA/content/m60
- **AW50 High Caliber** - Renegade - KAR98K Sniper - https://mohaaaa.co.uk/AAAAMOHAA/content/aw50-high-caliber
- **M4A1 (Renegade)** - Renegade - Thompson - https://mohaaaa.co.uk/AAAAMOHAA/content/m4a1-1
- **M79 Grenade Launcher** - Renegade - Bazooka - https://mohaaaa.co.uk/AAAAMOHAA/content/m79-grenade-launcher
- **M4 Super 90** - Renegade - Shotgun - https://mohaaaa.co.uk/AAAAMOHAA/content/m4-super-90
- **M24 Tactical Camo** - Renegade - Springfield - https://mohaaaa.co.uk/AAAAMOHAA/content/m24-tactical-camo
- **Beretta 9mm (Renegade)** - Renegade - Colt.45 - https://mohaaaa.co.uk/AAAAMOHAA/content/beretta-9mm-1
- **M67 Fragmentation Grenade** - Renegade - Mk 2 Grenade - https://mohaaaa.co.uk/AAAAMOHAA/content/m67-fragmentation-grenade
- **Pipe Bomb** - Renegade - M24 Stiel - https://mohaaaa.co.uk/AAAAMOHAA/content/pipe-bomb
- **Minigun** - Renegade - MG42 - https://mohaaaa.co.uk/AAAAMOHAA/content/minigun
- **Night Vision Binoculars** - Renegade - Binoculars - https://mohaaaa.co.uk/AAAAMOHAA/content/night-vision-binoculars
- **HK-G3A3** - Renegade - KAR98K - https://mohaaaa.co.uk/AAAAMOHAA/content/hk-g3a3
- **Ingram 9mm** - Renegade - Walther P38 - https://mohaaaa.co.uk/AAAAMOHAA/content/ingram-9mm
- **M16A2 (Renegade)** - Renegade - M1 Garand - https://mohaaaa.co.uk/AAAAMOHAA/content/m16a2-1

### x-Rasta 'ARG' tactical set

- **ARG Panzerschreck** - x-Rasta - Panzerschreck - https://mohaaaa.co.uk/AAAAMOHAA/content/arg-panzerschreck
- **BAR Camo (ARG)** - x-Rasta - BAR - https://mohaaaa.co.uk/AAAAMOHAA/content/bar-camo
- **Glock (ARG)** - x-Rasta - Colt.45 - https://mohaaaa.co.uk/AAAAMOHAA/content/glock-1
- **KAR98 Sniper Tactical** - x-Rasta - KAR98K Sniper - https://mohaaaa.co.uk/AAAAMOHAA/content/kar98-sniper-tactical
- **Luger (ARG)** - x-Rasta - Walther P38 - https://mohaaaa.co.uk/AAAAMOHAA/content/luger
- **MP40 Tactical SWAT** - x-Rasta - MP40 - https://mohaaaa.co.uk/AAAAMOHAA/content/mp40-tactical-swat
- **Shotgun Chrome** - x-Rasta - Shotgun - https://mohaaaa.co.uk/AAAAMOHAA/content/shotgun-chrome
- **Springfield Tactical** - x-Rasta - Springfield - https://mohaaaa.co.uk/AAAAMOHAA/content/springfield-tactical
- **Quilmes Molotov Cocktail** - x-Rasta - Mk 2 Grenade - https://mohaaaa.co.uk/AAAAMOHAA/content/quilmes-molotov-cocktail
- **M1 Garand Sintetico** - x-Rasta - M1 Garand - https://mohaaaa.co.uk/AAAAMOHAA/content/m1-garand-sintetico

### LZ set

- **Spec Ops FAMAS** - LZ - Thompson - https://mohaaaa.co.uk/AAAAMOHAA/content/spec-ops-famas
- **Mac-10 (LZ)** - LZ - Walther P38 - https://mohaaaa.co.uk/AAAAMOHAA/content/mac-10
- **Industrial Luger** - LZ - Walther P38 - https://mohaaaa.co.uk/AAAAMOHAA/content/industrial-luger
- **Platinum Shotgun** - LZ - Shotgun - https://mohaaaa.co.uk/AAAAMOHAA/content/platinum-shotgun
- **Silver Scoped M16** - LZ - BAR - https://mohaaaa.co.uk/AAAAMOHAA/content/silver-scoped-m16
- **Black Silver M24** - LZ - Springfield - https://mohaaaa.co.uk/AAAAMOHAA/content/black-silver-m24
- **HK PSG-1** - LZ - Springfield - https://mohaaaa.co.uk/AAAAMOHAA/content/hk-psg-1
- **Black Glock** - LZ - Colt.45 - https://mohaaaa.co.uk/AAAAMOHAA/content/black-glock
- **Tactical Black Galil** - LZ - MP40 - https://mohaaaa.co.uk/AAAAMOHAA/content/tactical-black-galil

### Fubah set

- **Grim Reaper SMG** - Fubah - Thompson - https://mohaaaa.co.uk/AAAAMOHAA/content/grim-reaper-smg
- **Hurt Grenade** - Fubah - M24 Stiel - https://mohaaaa.co.uk/AAAAMOHAA/content/hurt-grenade
- **Black Widow 2 KAR98** - Fubah - KAR98K Sniper - https://mohaaaa.co.uk/AAAAMOHAA/content/black-widow-2-kar98 (DS-ambig: DS black-widow-weapon-skin may be v1 of this (v2 here))
- **Battered Ram** - Fubah - Bazooka - https://mohaaaa.co.uk/AAAAMOHAA/content/battered-ram
- **Bone Collector 2** - Fubah - Panzerschreck - https://mohaaaa.co.uk/AAAAMOHAA/content/bone-collector-2
- **Bone Collector** - Fubah - Panzerschreck - https://mohaaaa.co.uk/AAAAMOHAA/content/bone-collector
- **Thrill Kill** - Fubah - Springfield - https://mohaaaa.co.uk/AAAAMOHAA/content/thrill-kill
- **Black Mesa Desert Eagle** - Fubah - Colt.45 - https://mohaaaa.co.uk/AAAAMOHAA/content/black-mesa-desert-eagle
- **Black MP40** - Fubah - MP40 - https://mohaaaa.co.uk/AAAAMOHAA/content/black-mp40
- **Black Russian SMG (PPSh)** - Fubah - PPSh - https://mohaaaa.co.uk/AAAAMOHAA/content/black-russian-smg
- **Black Sunshine AA Gun** - Fubah - FLAK/AA gun - https://mohaaaa.co.uk/AAAAMOHAA/content/black-sunshine-aa-gun

### Flakrider items not in DS index

- **Deadman Sniper** - Flakrider - Springfield - https://mohaaaa.co.uk/AAAAMOHAA/content/deadman-sniper
- **OU812 Death Garand** - Flakrider - M1 Garand - https://mohaaaa.co.uk/AAAAMOHAA/content/ou812-death-garand
- **Skull Garand** - Flakrider & Plague - M1 Garand - https://mohaaaa.co.uk/AAAAMOHAA/content/skull-garand
- **Third Reich MP40** - Flakrider - MP40 - https://mohaaaa.co.uk/AAAAMOHAA/content/third-reich-mp40
- **Snake Camo M1** - Flakrider - M1 Garand - https://mohaaaa.co.uk/AAAAMOHAA/content/snake-camo-m1
- **Unreal Thompson** - Flakrider - Thompson - https://mohaaaa.co.uk/AAAAMOHAA/content/unreal-thompson
- **Veggie Nade** - Flakrider - M24 Stiel - https://mohaaaa.co.uk/AAAAMOHAA/content/veggie-nade
- **Demon Garand** - Flakrider - M1 Garand - https://mohaaaa.co.uk/AAAAMOHAA/content/demon-garand
- **SG-551** - Flakrider - MP40 - https://mohaaaa.co.uk/AAAAMOHAA/content/sg-551

### RoempaZ/DaRKaNGeL items not in DS index

- **AK-47 Synthetic** - RoempaZ - Thompson - https://mohaaaa.co.uk/AAAAMOHAA/content/ak-47-synthetic
- **AK-47 Wood** - RoempaZ - Thompson - https://mohaaaa.co.uk/AAAAMOHAA/content/ak-47-wood
- **IMI Galil SAR Assault Rifle** - RoempaZ - BAR - https://mohaaaa.co.uk/AAAAMOHAA/content/imi-galil-sar-assault-rifle (note: NO-MODIFY without permission)
- **M4A1 Assault Rifle v2** - RoempaZ - BAR - https://mohaaaa.co.uk/AAAAMOHAA/content/m4a1-assault-rifle
- **MAC-11** - RoempaZ - Thompson - https://mohaaaa.co.uk/AAAAMOHAA/content/mac-11
- **G36C Assault Rifle** - RoempaZ - BAR - https://mohaaaa.co.uk/AAAAMOHAA/content/g36c-assault-rifle
- **IMI Desert Eagle** - RoempaZ - Walther P38 - https://mohaaaa.co.uk/AAAAMOHAA/content/imi-desert-eagle
- **M16 (RoempaZ)** - RoempaZ - Thompson - https://mohaaaa.co.uk/AAAAMOHAA/content/m16-1
- **M24 (RoempaZ)** - RoempaZ - Springfield - https://mohaaaa.co.uk/AAAAMOHAA/content/m24
- **Silenced MAC-11** - RoempaZ - Thompson - https://mohaaaa.co.uk/AAAAMOHAA/content/silenced-mac-11
- **Steyr Mannlicher Scout Rifle** - RoempaZ - KAR98K Sniper - https://mohaaaa.co.uk/AAAAMOHAA/content/steyr-mannlicher-scout-rifle
- **Uzi** - RoempaZ - MP40 - https://mohaaaa.co.uk/AAAAMOHAA/content/uzi

### East rare-gun singles not in DS index

- **United Defense Model 42** - East - Thompson - https://mohaaaa.co.uk/AAAAMOHAA/content/united-defense-model-42 (note: East readme)
- **Walther PPK (silenced)** - East - Colt.45 - https://mohaaaa.co.uk/AAAAMOHAA/content/walther-ppk
- **Mannlicher Carcano (scoped)** - East - Springfield - https://mohaaaa.co.uk/AAAAMOHAA/content/mannlicher-carcano (note: East credits)

### chris redfield003 novelty items

- **Throwing Stars** - chris redfield003 - M24 Stiel - https://mohaaaa.co.uk/AAAAMOHAA/content/throwing-stars
- **Super Soaker 50 (Water Rifle)** - chris redfield003 - MP40 - https://mohaaaa.co.uk/AAAAMOHAA/content/super-soaker-50-water-rifle
- **Bomb V1** - chris redfield003 - M24 Stiel - https://mohaaaa.co.uk/AAAAMOHAA/content/bomb-v1

### koensieben622 (WW2FreakSniper) OMTR set

- **Black Old BAR** - koensieben622 (WW2FreakSniper) - BAR - https://mohaaaa.co.uk/AAAAMOHAA/content/black-old-bar
- **Black Old Colt 45** - koensieben622 (WW2FreakSniper) - Colt.45 - https://mohaaaa.co.uk/AAAAMOHAA/content/black-old-colt-45
- **Bloody Grenade** - koensieben622 (WW2FreakSniper) - M24 Stiel - https://mohaaaa.co.uk/AAAAMOHAA/content/bloody-grenade
- **Devils Grenade** - koensieben622 (WW2FreakSniper) - Mk 2 Grenade - https://mohaaaa.co.uk/AAAAMOHAA/content/devils-grenade
- **Skeleton Stielhandgranate** - koensieben622 (WW2FreakSniper) - M24 Stiel - https://mohaaaa.co.uk/AAAAMOHAA/content/skeleton-stielhandgranate

### TheRipppa novelty/throwable items

- **Butcher Knife** - TheRipppa - Colt.45 - https://mohaaaa.co.uk/AAAAMOHAA/content/butcher-knife
- **Beer Bottle Nades** - TheRipppa - Mk 2 Grenade - https://mohaaaa.co.uk/AAAAMOHAA/content/beer-bottle-nades
- **Lightsaber** - TheRipppa - Colt.45 - https://mohaaaa.co.uk/AAAAMOHAA/content/lightsaber
- **Nintendo Gun** - TheRipppa - Colt.45 - https://mohaaaa.co.uk/AAAAMOHAA/content/nintendo-gun
- **Nintendo Mushroom Nade** - TheRipppa - Mk 2 Grenade - https://mohaaaa.co.uk/AAAAMOHAA/content/nintendo-mushroom-nade
- **Throwable Candy Canes (SH & BT)** - TheRipppa - Mk 2 Grenade - https://mohaaaa.co.uk/AAAAMOHAA/content/throwable-candy-canes-sh-bt
- **Throwable Carrots (SH & BT)** - TheRipppa - Mk 2 Grenade - https://mohaaaa.co.uk/AAAAMOHAA/content/throwable-carrots-sh-bt
- **Throwable Axes (SH & BT)** - TheRipppa - Mk 2 Grenade - https://mohaaaa.co.uk/AAAAMOHAA/content/throwable-axes-sh-bt
- **Throwable Lightsaber (SH & BT)** - TheRipppa - Mk 2 Grenade - https://mohaaaa.co.uk/AAAAMOHAA/content/throwable-lightsaber-sh-bt

### Dark'nStein items not in DS index

- **AK47 (Dark'nStein)** - Dark'nStein - MP40 - https://mohaaaa.co.uk/AAAAMOHAA/content/ak47
- **FN FAL** - Dark'nStein - StG 44 - https://mohaaaa.co.uk/AAAAMOHAA/content/fn-fal
- **MP5A2** - Dark'nStein - Thompson - https://mohaaaa.co.uk/AAAAMOHAA/content/mp5a2
- **G36 S-Machine Gun** - Dark'nStein - Thompson - https://mohaaaa.co.uk/AAAAMOHAA/content/g36-s-machine-gun
- **Glock 18** - Dark'nStein - Walther P38 - https://mohaaaa.co.uk/AAAAMOHAA/content/glock-18
- **M4A1 (Dark'nStein)** - Dark'nStein - Thompson - https://mohaaaa.co.uk/AAAAMOHAA/content/m4a1

### Scope / ironsight packs

- **Ironsights (v2)** - Klaus & Dr.Doom - all guns - https://mohaaaa.co.uk/AAAAMOHAA/content/ironsights-v2 (ext: gamefront; note: full credit to Klaus and Dr.Doom (uploader note))
- **SkullBox Scope** - GunnyWatts - Springfield - https://mohaaaa.co.uk/AAAAMOHAA/content/skullbox-scope
- **Futuristic Scopes** - (unknown) - Springfield - https://mohaaaa.co.uk/AAAAMOHAA/content/futuristic-scopes

### Smoke-grenade appearance mods

- **Black Smoke Nade** - Capt. kick your ass & Fubah - Smoke - https://mohaaaa.co.uk/AAAAMOHAA/content/black-smoke-nade
- **Bud Light Smoke Nade** - Shultz - Smoke - https://mohaaaa.co.uk/AAAAMOHAA/content/bud-light-smoke-nade
- **Heineken Smoke Nade** - Shultz - Smoke - https://mohaaaa.co.uk/AAAAMOHAA/content/heineken-smoke-nade
- **Ghost's Axis Smoke Nades** - Ghost - Smoke - https://mohaaaa.co.uk/AAAAMOHAA/content/ghosts-axis-smoke-nades
- **Ghost's Allies Smoke Nades** - Ghost - Smoke - https://mohaaaa.co.uk/AAAAMOHAA/content/ghosts-allies-smoke-nades

### Everything else (singles)

- **3Ds Galil SAR** - {ElitE}3D - StG 44 - https://mohaaaa.co.uk/AAAAMOHAA/content/3ds-galil-sar (FileFront-origin FF:26046)
- **SA80 (v2)** - {ElitE}3D - BAR - https://mohaaaa.co.uk/AAAAMOHAA/content/sa80-v2 (FileFront-origin FF:25918)
- **19th's Allied Sniper** - 19thGates - Springfield - https://mohaaaa.co.uk/AAAAMOHAA/content/19ths-allied-sniper (FileFront-origin FF:97432; note: credit-required readme)
- **Green Goblin Pumpkin Bomb** - ReCoil||Factor - Mk 2 Grenade - https://mohaaaa.co.uk/AAAAMOHAA/content/green-goblin-pumpkin-bomb
- **Pumpkin Grenade** - Bdbodger - Mk 2 Grenade - https://mohaaaa.co.uk/AAAAMOHAA/content/pumpkin-grenade
- **Deadhead Springfield** - =ECAA=[GOA]Richards - Springfield - https://mohaaaa.co.uk/AAAAMOHAA/content/deadhead-springfield
- **Death Garand** - ReCoil||Factor - M1 Garand - https://mohaaaa.co.uk/AAAAMOHAA/content/death-garand
- **Resident Evil Beretta** - GIANCARLO SCHIANO - Colt.45 - https://mohaaaa.co.uk/AAAAMOHAA/content/resident-evil-beretta
- **Resident Evil Pump Shotgun** - GIANCARLO SCHIANO - Shotgun - https://mohaaaa.co.uk/AAAAMOHAA/content/resident-evil-pump-shotgun
- **Resident Evil M4S90 Shotgun** - GIANCARLO SCHIANO - Shotgun - https://mohaaaa.co.uk/AAAAMOHAA/content/resident-evil-m4s90-shotgun
- **Black Winchester M97 Shotgun** - Sonic.XR54 - Shotgun - https://mohaaaa.co.uk/AAAAMOHAA/content/black-winchester-m97-shotgun
- **Dutch Nades** - Sgt.shultz - Mk 2 Grenade - https://mohaaaa.co.uk/AAAAMOHAA/content/dutch-nades
- **Dutch Thompson** - =ECAA=[GOA]Richards - Thompson - https://mohaaaa.co.uk/AAAAMOHAA/content/dutch-thompson
- **Dutch Sniper** - -=MMD=-Dave_The_Brave - Springfield - https://mohaaaa.co.uk/AAAAMOHAA/content/dutch-sniper
- **Bloody Hell Thompson** - =SCF=Godfather - Thompson - https://mohaaaa.co.uk/AAAAMOHAA/content/bloody-hell-thompson
- **Wooden Panzerschreck** - {DRT}-Scharf.-Bruno-Gesche - Panzerschreck - https://mohaaaa.co.uk/AAAAMOHAA/content/wooden-panzerschreck
- **Black Thompson** - [-nFa-]Pvt.Duce - Thompson - https://mohaaaa.co.uk/AAAAMOHAA/content/black-thompson
- **Band of Brothers Thompson** - pablo - Thompson - https://mohaaaa.co.uk/AAAAMOHAA/content/band-brothers-thompson
- **M24 Black Camo** - Vdog77 - Springfield - https://mohaaaa.co.uk/AAAAMOHAA/content/m24-black-camo (note: model credit RoempaZ)
- **M24 Camo** - Vdog77 - Springfield - https://mohaaaa.co.uk/AAAAMOHAA/content/m24-camo (note: model credit RoempaZ)
- **M24 Desert Camo** - Vdog77 - Springfield - https://mohaaaa.co.uk/AAAAMOHAA/content/m24-desert-camo (note: model credit RoempaZ)
- **M24 Wood Camo** - Vdog77 - Springfield - https://mohaaaa.co.uk/AAAAMOHAA/content/m24-wood-camo (note: model credit RoempaZ)
- **Remington 870** - Retro_Cow - Shotgun - https://mohaaaa.co.uk/AAAAMOHAA/content/remington-870
- **Black Death Bazooka** - DM - Bazooka - https://mohaaaa.co.uk/AAAAMOHAA/content/black-death-bazooka
- **PSG-1 Sniper Rifle** - PyroManiac - Springfield - https://mohaaaa.co.uk/AAAAMOHAA/content/psg-1-sniper-rifle
- **Mac-10 Uzi** - Loc - Thompson - https://mohaaaa.co.uk/AAAAMOHAA/content/mac-10-uzi
- **Maschetto** - Major Koenig - (machete) - https://mohaaaa.co.uk/AAAAMOHAA/content/maschetto
- **The Devil's Hand Shotgun** - (unknown) - Shotgun - https://mohaaaa.co.uk/AAAAMOHAA/content/devils-hand-shotgun
- **MP5A2 Delta** - FIREANDFORGET - Thompson - https://mohaaaa.co.uk/AAAAMOHAA/content/mp5a2-delta (note: NO-REDISTRIBUTE readme)
- **P-08 Mauser Luger** - Pato & Dan - Walther P38 - https://mohaaaa.co.uk/AAAAMOHAA/content/p-08-mauser-luger (note: Lt.Pato = explicit reuse-OK author)
- **Binocular Optics** - Brutal (.:47RoNin:.) - Binoculars - https://mohaaaa.co.uk/AAAAMOHAA/content/binocular-optics
- **Binocular Optics (1)** - Son Of Liberty - Binoculars - https://mohaaaa.co.uk/AAAAMOHAA/content/binocular-optics-1
- **Jungle Machete** - LOCC - Colt.45 - https://mohaaaa.co.uk/AAAAMOHAA/content/jungle-machete
- **Type 38 Arisaka Rifle** - 1936 Team - KAR98K - https://mohaaaa.co.uk/AAAAMOHAA/content/type-38-arisaka-rifle
- **Night Vision Binoculars (1)** - (unknown) - Binoculars - https://mohaaaa.co.uk/AAAAMOHAA/content/night-vision-binoculars-1
- **The Holy Hand Grenade V2** - Spruce_Goose - Mk 2 Grenade - https://mohaaaa.co.uk/AAAAMOHAA/content/holy-hand-grenade-v2 (note: credit Dr.(...); DS-ambig: DS has the-holy-hand-grenade-v1-0 - THIS IS V2 (newer))
- **SMAW** - Kurell - Bazooka - https://mohaaaa.co.uk/AAAAMOHAA/content/smaw
- **SOCOM USP .45** - Kurell - Colt.45 - https://mohaaaa.co.uk/AAAAMOHAA/content/socom-usp-45
- **M249 SAW** - Dr.Deleto =MCT= - BAR - https://mohaaaa.co.uk/AAAAMOHAA/content/m249-saw
- **USP .45** - Dmitri - Colt.45 - https://mohaaaa.co.uk/AAAAMOHAA/content/usp-45
- **PSG-1 Sniper (City Nights)** - City Nights Team - Springfield - https://mohaaaa.co.uk/AAAAMOHAA/content/psg-1-sniper (DS-ambig: DS allied-psg1-2 may be the same City Nights PSG-1)
- **Type 100** - Acme - MP40 - https://mohaaaa.co.uk/AAAAMOHAA/content/type-100
- **Type 96** - Acme - StG 44 - https://mohaaaa.co.uk/AAAAMOHAA/content/type-96
- **Bomb Nades** - Master-Of-Fungus-Foo-D - Mk 2 Grenade - https://mohaaaa.co.uk/AAAAMOHAA/content/bomb-nades
- **MP40 Replacement** - City Nights Team - MP40 - https://mohaaaa.co.uk/AAAAMOHAA/content/mp40-replacement (note: 'I take no credit' uploader)
- **Camo Bazooka** - Borowski - Bazooka - https://mohaaaa.co.uk/AAAAMOHAA/content/camo-bazooka
- **2020 Commando** - {ElitE}3D & Dreadhead - Thompson - https://mohaaaa.co.uk/AAAAMOHAA/content/2020-commando (FileFront-origin FF:28883)
- **Black Bazooka** - Willis - Bazooka - https://mohaaaa.co.uk/AAAAMOHAA/content/black-bazooka
- **Skittastical BAR** - (unknown) - BAR - https://mohaaaa.co.uk/AAAAMOHAA/content/skittastical-bar
- **Beretta M9** - {ElitE}3D - Colt.45 - https://mohaaaa.co.uk/AAAAMOHAA/content/beretta-m9
- **Black Luger** - Sniper1501 - Walther P38 - https://mohaaaa.co.uk/AAAAMOHAA/content/black-luger
- **Black-Op Colt 45** - Covert - Colt.45 - https://mohaaaa.co.uk/AAAAMOHAA/content/black-op-colt-45
- **M24 Winter Camo** - Vdog77 - Springfield - https://mohaaaa.co.uk/AAAAMOHAA/content/m24-winter-camo (note: model credit RoempaZ)
- **M16 Assault Rifle ({ElitE}3D)** - {ElitE}3D - Thompson - https://mohaaaa.co.uk/AAAAMOHAA/content/m16-assault-rifle (FileFront-origin FF:30457)
- **Christmas Spirit ShotGun** - ReCoil||Factor - Shotgun - https://mohaaaa.co.uk/AAAAMOHAA/content/christmas-spirit-shotgun
- **Christmas Toy Pistols** - SolidScope - Walther P38 - https://mohaaaa.co.uk/AAAAMOHAA/content/christmas-toy-pistols
- **Enhanced Winter Springfield** - Yossarian - Springfield - https://mohaaaa.co.uk/AAAAMOHAA/content/enhanced-winter-springfield
- **Snowy MP40** - Goa.Patton - MP40 - https://mohaaaa.co.uk/AAAAMOHAA/content/snowy-mp40
- **Snowy Springfield** - Goa.Patton - Springfield - https://mohaaaa.co.uk/AAAAMOHAA/content/snowy-springfield
- **Crossbow** - Major_A - MP40 - https://mohaaaa.co.uk/AAAAMOHAA/content/crossbow
- **Wolf Hands** - Captain_Wolfen - 1P hands - https://mohaaaa.co.uk/AAAAMOHAA/content/wolf-hands (note: NO-REDISTRIBUTE without permission)
- **Black Chainmaille Gloves** - ReCoil||Factor - 1P hands (SH) - https://mohaaaa.co.uk/AAAAMOHAA/content/black-chainmaille-gloves
- **Snake Skin Gloves** - ReCoil||Factor - 1P hands (SH) - https://mohaaaa.co.uk/AAAAMOHAA/content/snake-skin-gloves
- **Throwing Knifes V2 (SH & BT)** - Ruckus & Lamron - Mk 2 Grenade - https://mohaaaa.co.uk/AAAAMOHAA/content/throwing-knifes-sh-bt
- **Molotov Cocktail (AA)** - Jethro - Mk 2 Grenade - https://mohaaaa.co.uk/AAAAMOHAA/content/molotov-cocktail
- **Plasma Grenade** - Seraphim1 - Mk 2 Grenade - https://mohaaaa.co.uk/AAAAMOHAA/content/plasma-grenade
- **Molotov Mod (AA beta)** - BatteryAziz - M24 Stiel - https://mohaaaa.co.uk/AAAAMOHAA/content/molotov-mod
- **Reaper Nade PRO BLAST Insanity** - FUBAR - explosion fx - https://mohaaaa.co.uk/AAAAMOHAA/content/reaper-nade-pro-blast-insanity

## Already-known items seen

**25 items belong to your named known sets** (Hobbs 9 incl. 2 skull-explosion fx, DirtyHarry 5,
Leon 4 incl. 2 zombie scopes, EIC/Schutze 1, Baro 1, Soares93-known 5 incl. all three Extra-WW2
releases: beta + update 1 + update 2 are ALL hosted here).

**40 further items are confirmed duplicates of the DS-Servers 343 tsv** (or authorship already
resolved in skins_hunt): 1928-tommy-gun, 27a1-commando-thompson, ak-47-1, ak47m, baseball-bat, black-colt-45, black-death-shotty, black-ops-garand, black-ops-springfield, bloody-tommy-gun, boom-grenade, brutal-kar98, cmc-assault-rifle, colt45-hellfire, desert-eagle, dsm-kar98, extreme-colt45, fg-42, g43, glock-17, glock-17-v2, glock-2, johnson-m1941-automatic-rifle, kickass-kar98, lpw05, m16, m16a1, m16a2, mauser-c1896, metal-z00ka, mosin-nagant-scoped, mp5k-fixed, p90, quake-3-phrasia-engine, quake-3-shuriken, scoped-ak-47, scoped-mosin-nagant, silenced-colt-45, smach-assault-rifle, suomi-m31-smg.

Bonus identifications for open questions in skins_hunt_2026-08-19.md:

- **'tommy28 (M1928)' authorship pending -> RESOLVED**: the site's *1928 Tommy Gun* page credits
  creator **sT@t!c**, readme credits **Dr.Deleto's model** ("all i did was reskin it and gave it the
  mp40 animations"), FileFront id 28424. Matches your Static/Dr.Deleto note exactly.
- **DarkAngel FG42 add-on (Tier B want)** is hosted here directly: content/fg-42
  (`zzzuser-fg42-mohaa.pk3`, readme: model 2015/EA Games, animations DaRKaNGeL).
- **Holy Hand Grenade**: DS tsv has v1.0; this site hosts **V2** (content/holy-hand-grenade-v2).
- **City Nights**: DS tsv has only the pack's AK47; the **full City Nights Weapons Pack** is here.

## Permission notes

The site has **no license field** (every page shows "Mod Status - Unknown"); permissions live only in
embedded readme text, which was captured for all 249 items. Explicit statements found:

| Item | Author | Statement |
|---|---|---|
| MP5A2 Delta | FIREANDFORGET | **Do not redistribute, repackage, copy or extract** individual parts without permission |
| IMI Galil SAR | RoempaZ/DaRKaNGeL | "Please don't edit or modify without my permission" |
| Wolf Hands | Captain_Wolfen | "Don't redistribute this file without my permission" (contact email on page) |
| 19th's Allied Sniper | 19thGates | May be used by anybody, but **credit required** - threatens takedown if uncredited |
| BOOM! Grenade | Ph4de | "Credit me if you use it and dont try to claim it as your own, do not redistribute without credit" |
| CoD WaW Scopes | Soares93 | "**Feel free to use it as long as you give credit**" |
| Extra WW2 weapons (all 3) | Soares93 | "Gathers files from all over the internet, the only credit I take is for some reskins/fixes" - upstream provenance unstated |
| MG42 ironsights view | Soares93 | Model **ripped from MoH:Airborne** by BUTTHE4D (p3dm) - commercial-asset rip, risky for public release |
| FG 42 | DaRKaNGeL | Model credited to "2015/EA Games" (original MOHAA devs) + DarkAngel anims |
| Johnson M1941 / UD M42 / Carcano | East | Credit blocks list East + "CoD2 (edited)" textures / MOHAA-exp sounds - CoD2 asset provenance; East already flagged CONTACT-FIRST in your ledger |
| 1928 Tommy Gun | sT@t!c | Dr.Deleto model credit; dedication line |
| Vdog77 M24 camo series (5) | Vdog77 | "CREDITS: MODEL: Roempaz, SKINS: Vdog77" - two-party credit needed |
| Metal of Z00ka | koensieben622 | Credits Flakrider "for awesome tips" |
| Suomi M31 | Sgt KIA | Sound borrowed **with permission** from FDF Mod (Operation Flashpoint) |
| MP40 Replacement | City Nights uploader | "I take no credit in the making" - actual author unstated |
| Cuchillo de Rambo | Hobbs | Credits "City Nights FINAL" (=FS= HOBBS all roles) |

Everything else carries install-instructions-only readmes -> FileFront-era convention applies
(reuse with readme credit, as already assumed in your permission ledger). The **P-08 Mauser Luger**
is by **Pato & Dan** - Lt. Pato is your one explicit reuse-YES author, so that item is likely safe.
Renegade/x-Rasta/LZ/Fubah items shipped bare pk3s with no readme text at all.
