# Cover Structures Catalog — trilogy-wide buildable-cover scan (AA / SH / BT)

Working reference for converting stock campaign-map brush structures into player-buildable blueprint templates (128-piece cap, authentic textures).

- Raw cluster data: `scratchpad/coverscan/clusters_<map>.json` (dims, center, zbase, brush counts, top-texture face counts). Scan session 2026-07-21.
- Piece budget rule of thumb: **pieces ~= 3x brush count** (observed planning ratio). 128-piece cap => <=42 brushes at full fidelity; bigger structures need major-brush-only / reduced detail.
- `Br/Maj` = total brushes / major (structural) brushes. `zb` = zbase (bottom of cluster).
- **Origin caveat**: clusters with center ~(0,0,z) are brush-entity submodels — coords are model-local, resolve the entity's in-map origin before extracting. Flagged `[origin]` below.
- Status: **OK** = verify-pass confirmed, standalone/extractable. **SEG** = confirmed real but merged slice of connected geometry (extract with surgery or skip). **cand** = unverified candidate (heuristic scan only). **DONE** = already shipped.

## DONE (shipped templates — do not re-extract)
| Template | Source | Notes |
|---|---|---|
| `casemate` | m3l1b shore-battery casemate | shipped buildable |
| `depot` | e1l2 depot outbuilding | shipped buildable |

---

## TOP 15 shortlist (best extraction candidates trilogy-wide)

| # | Map | Name | Type | Dims (u) | Center (zb) | Top textures | Feasibility | Why |
|---|---|---|---|---|---|---|---|---|
| 1 | m2l3 | small winter-concrete pillbox | pillbox | 160x288x168 | (-5552,-2240,-236) zb -320 | concretewall_winter_bunker:8 | 8 br → ~24 pc, full fidelity | Uniform single-texture enterable pillbox; cheapest cv5 structure in the trilogy |
| 2 | e1l2 | square iron/concrete gun-emplacement pit | emplacement | 416x416x100 | (-2936,-5632,914) zb 864 | ironwall1:7, jh_conc512brown:5 | 12 br (6 maj) → ~18-36 pc | Chest-high walled square = perfect buildable cover ring |
| 3 | m6l1b | medium Siegfried-line bunker | bunker | 435x719x288 | (-2632,-4750,1840) zb 1696 | winterbunkerwall:9, resrchnorway_wall1low:9, dday_bunker_wall1bsml:6 | 24 br (22 maj) → ~66 pc | Discrete enterable Siegfried bunker, classic textures, well within cap |
| 4 | m4l2 | concrete wall segment (1008u run) | low-wall | 208x1008x192 | (-3224,3832,-144) zb -240 | fltwall1grmy:2, jh_conc512c:1, dday_bunker_wall1bsml:1 | 4 br → ~12 pc | Archetypal buildable cover wall; trivially cheap, over-chest height |
| 5 | m6l1b | chest-high concrete bunker wall | low-wall | 192x352x72 | (-5664,3136,1948) zb 1912 | dday_bunker_wall1bsml:8 | 8 br → ~24 pc | Perfect chest-height firing wall; identical prefab also on m6l1a (x2) |
| 6 | e1l1 | small concrete bunker with metal doors | bunker | 432x192x166 | [origin] (0,0,9) zb -74 | bunkerdoor3:48, bunk_ceiling:18, concretewall2:15 | 103 br / 18 maj → majors-only ~54 pc | Enterable concrete bunker with doors; extract major brushes only |
| 7 | e1l2 | rectangular iron/concrete sandwall emplacement | emplacement | 352x144x116 | (-1656,-3392,778) zb 720 | ironwall1:7, jh_conc512brown:4 | 11 br (5 maj) → ~15-33 pc | Waist-to-chest rectangular position; pairs with #2 as an emplacement set |
| 8 | e1l4 | crate stack (mixed-height supply pile) | low-wall | 227x338x140 | (-4628,2460,114) zb 44 | gnrlcratesml_side:5, foodcrate_end:4, crate_reinforced1_topflt:3 | 12 br → ~36 pc | Pure-crate chest-to-head cover chunk, instantly recognizable |
| 9 | e2l2 | plank-and-timber revetment emplacement | emplacement | 280x352x172 | (2752,-2004,2602) zb 2516 | plank_flat:20, woodbeamed_trenchwall1:9 | 29 br (13 maj) → majors ~39 pc | Stamped prefab (mirror twin of c26); iconic wood-revetted firing position |
| 10 | m2l2a | reinforced supply-crate cube | low-wall | 132x112x132 | [origin] (-2,12,0) zb -66 | crate_reinforced1_top:50, foodcrate3:14 | 68 br (65 maj) — SIMPLIFY to a few boxes | Literal reinforced-crate cube; rebuild as 4-8 box brushes with same textures |
| 11 | t2l4 | concrete bunker (bunker_wall2) | bunker | 640x416x368 | (696,1080,536) zb 352 | bunker_wall2:38, stonebricks1drk:12 | 56 br (49 maj) → reduced detail | Best SH bunker; discrete, enterable, dominated by one wall texture |
| 12 | m3l1a | Omaha beach-wall MG42 casemate | bunker | 720x1184x408 | (2456,5384,-372) zb -576 | jh_conc2:40, bunk_beam:31, bunk_ceiling:8 | 104 br (27 maj) → majors-only ~81 pc | The iconic D-Day fortification; reduced-detail template, rear abuts seawall |
| 13 | m1l2b | wooden guard/watch tower | building | 192x240x520 | (2160,-968,36) zb -224 | flrwood1_rep:27, plank_flat:22 | 51 br (24 maj) → ~72 pc | Classic plank watchtower = elevated firing platform; twins at c5/c6, also m1l3a/b |
| 14 | m4l1 | wood-beamed trench section with rubble | trench | 752x640x262 | (5640,4704,461) zb 330 | woodbeamed_trenchwall2:7, rubble2c:3 | 10 br → ~30 pc | Compact iconic German trench segment; only buildable trench candidate |
| 15 | t2l3 | stacked snowy log barricade | low-wall | 396x87x83 | (-194,-1186,-25) zb -66 | snowylog:9 | 9 br → ~27 pc | Unique winter log-wall cover; single texture, trivially replicable |

---

## Allied Assault (m-series, Pak5.pk3)

### m1l1 — Arzew, Algeria (Lighting the Torch)
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 5 | building | Arzew street building / courtyard wall run | 704x205x258 | [origin] (0,0,45) zb -84 | 42/19 | algierwall1:14, afrik_wall1b:7 | cand |
| 4 | low-wall | stucco compound wall segment | 160x744x364 | (-3960,12,542) zb 360 | 14/12 | afrik_wall1a:7, algierwall1_0:3 | cand |
| 1 | ruin | partial building shell near town square | 1300x668x324 | (-5418,78,538) zb 376 | 13/7 | algierwall1_0:4, afrik_wall1brick:2 | cand |

### m1l2a — Rescue the Sabotage Team (Arzew town)
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 13 | emplacement | crate stack courtyard (supply crates by barn door) | 1272x577x440 | [origin] (-124,-127,-36) zb -256 | 98/32 | gr_crate_slat:52, algierwall1_0:9 | cand |
| 15 | ruin | ruined building shell (ruinswall section) | 2392x1560x792 | (-1300,-3212,-372) zb -768 | 80/58 | tudor_set1w_exwall1flat:51, ruinswall:14 | cand |
| 4 | house | small Algiers house with doorway | 544x904x896 | (4816,-3828,-64) zb -512 | 12/12 | algierwall1_0:5, algierwall1b_mozaic_bl:3 | cand |
| 5 | house | tiny mosaic-walled hut with grated window | 392x304x416 | (4964,-2952,80) zb -128 | 8/7 | algierwall1b_mozaic_bl:4, windowgrate2a:1 | cand |
| 9 | low-wall | low shed / market stall | 352x384x240 | (6064,-896,-8) zb -128 | 7/7 | whitewoodbmtrm:3, algierwall1drk_1flat:2 | cand |
| 12 | low-wall | freestanding garden wall segment | 208x40x584 | (128,4076,36) zb -256 | 6/6 | tudor_set1w_exwall1flat:5 | cand |

### m1l2b — Arzew port / harbor warehouses (night)
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 9 | emplacement | stacked supply-crate depot (German crates on dock) | 544x457x300 | [origin] (114,-188,50) zb -100 | 142/29 | bnkrpipe1_iron:46, gnrlcratesml_top:37, gnrlcratesml_side:21 | OK (minor dock-pipe bleed at edges) |
| 7 | building | wooden guard/watch tower | 192x240x520 | (2160,-968,36) zb -224 | 51/24 | flrwood1_rep:27, plank_flat:22 | OK — **TOP 15 #13** |
| 10 | building | wooden dockside platform/tower structure | 416x680x552 | (528,-1700,20) zb -256 | 60/33 | plank_flat:33, flrwood1_rep:23 | cand |
| 5 | building | wooden guard tower (short variant) | 240x192x336 | (3496,-3032,72) zb -96 | 47/20 | flrwood1_rep:23, plank_flat:22 | cand (twin of c7, shorter) |

### m1l3a — SAS survivor jeep escape (Arzew)
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 6 | emplacement | Afrika Korps crate stack w/ I-beam scaffold + planks | 144x132x128 | [origin] (0,0,0) zb -64 | 44/15 | gnrlcratesml_afrika1:14, ibeam_flat2:13, wood_plank:10 | OK |
| 3 | building | wooden plank tower/scaffold | 224x272x576 | (4176,4968,304) zb 16 | 32/26 | wood_plank:30, gnrlcratesml_top:2 | cand (same prefab as m1l3b c1) |
| 2 | low-wall | ruined Algiers courtyard wall section | 320x512x156 | (880,-1992,170) zb 92 | 14/12 | algierwall_set5drt_moz:6, tudor_set1w_exwall1flat:4 | cand |

### m1l3b — jeep escape pt 2
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 1 | building | wooden guard tower (plank, crates on platform) | 224x272x576 | (-1648,-856,296) zb 8 | 32/26 | wood_plank:30, gnrlcratesml_top:2 | OK (stamped prefab, twin c3) |
| 2 | house | small tudor village house | 656x456x456 | (-2720,-7004,524) zb 296 | 16/16 | whitewoodbmtrm:8, tudor_set1w_exwall1flat:4 | cand |
| 4 | bridge | concrete road bridge / culvert span | 552x528x232 | (-2796,7096,76) zb -40 | 5/5 | jh_conc512b:5 | cand |

### m1l3c — lighthouse/bunker complex
No extractable candidates (all clusters are merged fort-complex slices).

### m2l1 — Trondheim naval base
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 14 | house | small Norwegian guard hut (research-base walls) | 416x384x440 | (832,-176,668) zb 448 | 21/20 | rembridge_ibeama:8, resrchnorway_wall1low:6 | cand |
| 20 | house | small naval-base outbuilding / guard house | 480x464x376 | (-1760,-3624,636) zb 448 | 20/20 | resrchnorway_wall1:17, ironwall1:2 | cand |
| 16 | house | prefab shed/guard shack (repeated base prop; twins c18/c21) | 512x784x312 | (-512,384,652) zb 496 | 12/12 | concretewall_winter_bunker:5, ibeam_vert:4 | cand |

### m2l2a — Lorient U-boat pens (dry docks)
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 40 | low-wall | reinforced supply crate stack (dockside cargo) | 132x112x132 | [origin] (-2,12,0) zb -66 | 68/65 | crate_reinforced1_top:50, foodcrate3:14 | OK — **TOP 15 #10** (simplify) |
| 32 | low-wall | pen entrance blast wall (bunker_walltrans) | 1024x336x1248 | (-384,-1448,-144) zb -768 | 9/9 | jh_conc512c:3, jh_conc512b:3 | cand |

### m2l2b — U-boat pen interior
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 43 | low-wall | small supply crate cluster (foodcrate3) | 302x84x183 | [origin] (-39,2,24) zb -68 | 16/16 | foodcrate3:6, jh_conc512a:4, crate_reinforced1_top:4 | OK (chest-to-head, not low) |
| 2 | emplacement | reinforced crate stack on dock | 1088x1904x1088 | (-960,-6072,-272) zb -816 | 20/20 | crate_reinforced1_top:15, jh_conc512c:2 | cand |

### m2l2c — Trondheim U-boat pens (interior docks)
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 53 | emplacement | reinforced German crate stack | 1088x660x432 | (-960,-6694,-600) zb -816 | 16/16 | crate_reinforced1_top:15, jh_conc512c:1 | OK |
| 6 | building | U-boat pen divider wall (berth partition) | 328x1280x1024 | (2080,-3200,-256) zb -768 | 50/41 | jh_conc512c:16, ironwall1:9 | cand |
| 27 | low-wall | south-berth pen divider wall (thin partition) | 328x2016x1056 | (-352,-6128,-272) zb -800 | 15/10 | ironwall1:5, jh_conc512c:3 | cand |

### m2l3 — Trondheim naval facility / dry dock
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 6 | pillbox | small winter-concrete bunker | 160x288x168 | (-5552,-2240,-236) zb -320 | 8/8 | concretewall_winter_bunker:8 | OK — **TOP 15 #1** |

### m3l1a — Omaha Beach landing
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 0 | bunker | beach-wall MG42 bunker casemate (shingle line) | 720x1184x408 | (2456,5384,-372) zb -576 | 104/27 | jh_conc2:40, bunk_beam:31, bunk_ceiling:8 | OK — **TOP 15 #12** (rear abuts seawall) |
| 1 | low-wall | concrete anti-tank wall segment | 256x464x320 | (1376,4280,-392) zb -552 | 6/6 | jh_conc2:6 | cand (same prefab as m3l1b c1 pillbox) |

### m3l1b — Omaha clifftop fortress
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 1 | pillbox | lower concrete pillbox/casemate shell | 256x464x320 | (1376,-3208,-392) zb -552 | 9/9 | jh_conc2:9 | **DONE** — shipped as `casemate` template (verify identity before any re-extract) |
| 9 | emplacement | crate-stacked supply room near bunker entrance | 574x840x476 | (-225,-348,178) zb -60 | 124/13 | gr_crate_slat:72, gnrlcratesml_side:23 | SEG (merged with bunker interior shell) |
| 5 | bunker | secondary bunker room / casemate section w/ beams | 1013x864x414 | (669,-354,271) zb 64 | 50/10 | ironwall1:25, bunk_beam:13 | cand |
| 4 | trench | concrete trench/walkway section w/ wood planking | 662x1468x208 | (-895,-686,352) zb 248 | 24/9 | ironwall1:14, jh_conc512c:5 | cand |
| 7 | low-wall | iron/concrete parapet wall section (upper level) | 414x742x136 | (2561,-515,388) zb 320 | 17/5 | ironwall1:12, jh_conc512c:4 | cand |

### m3l2 — push inland from Omaha
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 2 | ruin | shelled tudor building with rubble base | 416x768x440 | (-6928,-6448,28) zb -192 | 13/5 | tudor_set1_exwall1flat:6, rubblebase:5 | OK |
| 5 | bunker | D-Day bunker wall segment w/ I-beam framing | 1024x288x768 | (3936,-3504,128) zb -256 | 8/4 | bunk_beam:4, dday_bunker_wall1bsml:3 | SEG (thin slab, slice of bunker complex) |
| 3 | house | small two-story stone farmhouse w/ wood floors | 330x325x528 | (-4640,-7266,-56) zb -320 | 35/18 | flrwood1_rep:18, stonewall1:16 | cand |
| 4 | house | small wood-framed cottage/barn | 400x528x520 | (-5384,-5816,108) zb -152 | 15/7 | flrwood1_rep:9, beam_wood1:5 | cand |

### m3l3 — Sniper's Last Stand (ruined St. Lo)
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 20 | ruin | small rubbled brick shop corner w/ wood floor + crates | 184x128x168 | [origin] (22,0,0) zb -84 | 100/20 | jh_brick3:40, rubblebase:32, flrwood1_rep:24 | OK |
| 13 | ruin | two-storey blasted house with intact wood floors | 672x464x520 | (2984,8,-68) zb -328 | 33/32 | flrwood1_rep:19, jh_concwallwin2b:4 | OK |
| 16 | ruin | blasted concrete building with windowed facade | 1236x936x608 | (4630,-380,-136) zb -440 | 76/51 | flrwood1_rep:33, jh_concwallwin2b:20 | cand |
| 10 | ruin | single-storey blasted concrete house | 472x640x444 | (5572,1848,50) zb -172 | 20/18 | flrwood1_rep:14, jh_concwallwin2b:6 | cand |
| 8 | ruin | low collapsed house with rubble floor | 696x512x376 | (2844,3152,-76) zb -264 | 19/17 | flrwood1_rep:8, jh_concwallwin2b:6, rubblebase:5 | cand |
| 9 | ruin | ruined courtyard with crates and low walls | 896x800x368 | (4032,1984,-104) zb -288 | 19/10 | jh_concwallwin2b:7, misc_crate1d:4 | cand |
| 0 | emplacement | German supply crate stack (outskirts checkpoint) | 288x269x114 | (-6848,2985,35) zb -22 | 15/6 | flrwood1_rep:5, crate_reinforced1_side:5, misc_crate1d:5 | cand |

### m4l0 — Nebelwerfer Hunt (forest/farm village)
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 1 | house | small plank/stone farm outbuilding (shed/cottage) | 768x516x344 | (-984,6990,212) zb 40 | 13/11 | plank_flat:8, platestonelittn:5 | OK |
| 4 | low-wall | dark stone perimeter wall network | 1773x2652x174 | (-4486,-5502,79) zb -8 | 29/29 | stonebricks1drk:28 | cand |
| 12 | low-wall | plank fence / low wooden barrier run | 574x1360x166 | (-3411,-2856,61) zb -22 | 23/9 | plank_flat:23 | cand |
| 6 | house | two-story plank farmhouse | 1037x910x626 | (-280,4678,353) zb 40 | 18/11 | plank_flat:15, platestonelittn:3 | cand |
| 10 | low-wall | sunken stone wall / streambed retaining wall | 672x1000x308 | (-2124,3344,-6) zb -160 | 11/10 | stonebricks1drk:11 | cand |
| 9 | ruin | stone building shell with plank remnants | 1432x984x626 | (-5252,-3092,385) zb 72 | 9/9 | stonebricks1drk:7, plank_flat:2 | cand |
| 8 | house | small plank shed | 496x928x296 | (-5484,-2052,220) zb 72 | 6/6 | plank_flat:5, drkgry1beam:1 | cand |
| 5 | low-wall | mixed plank/stone barrier segment | 249x869x288 | (-4232,-1366,216) zb 72 | 5/5 | plank_flat:2, stonebricks1drk:2 | cand |
| 11 | low-wall | stone parapet / ledge wall | 948x100x247 | (3354,472,399) zb 275 | 4/2 | stonebricks1drk:4 | cand |

### m4l1 — Nebelwerfer Hunt
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 3 | ruin | ruined stone outbuilding w/ fence-row (Brest roof remnant) | 896x712x520 | (368,-2980,244) zb -16 | 11/9 | concrete7:4, brstroof1a:3, platestonelittn:2 | OK |
| 4 | trench | wood-beamed trench section with rubble | 752x640x262 | (5640,4704,461) zb 330 | 10/10 | woodbeamed_trenchwall2:7, rubble2c:3 | OK — **TOP 15 #14** |

### m4l2 — Behind Enemy Lines
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 9 | low-wall | concrete wall segment (1008u run, 192 tall) | 208x1008x192 | (-3224,3832,-144) zb -240 | 4/4 | fltwall1grmy:2, jh_conc512c:1 | OK — **TOP 15 #4** |
| 10 | low-wall | reinforced-crate and iron barricade stack | 690x207x248 | [origin] (49,6,-48) zb -172 | 126/90 | ironwall1:76, crate_reinforced1_top:17 | cand |
| 7 | bunker | low concrete bunker (bunker_conc walls/ceiling) | 1246x926x360 | (-2047,1009,180) zb 0 | 99/45 | ironwall1:24, bunker_conc2:22 | cand |
| 8 | low-wall | dark stone-brick wall run | 520x1104x384 | (-7884,3560,192) zb 0 | 8/8 | stonebricks1drk:7 | cand |
| 1 | low-wall | wood-plank and ibeam barrier/walkway edge | 576x282x333 | (5784,2312,270) zb 103 | 4/4 | wood_plank:2, ibeam_vert_normal:2 | cand |

### m4l3 — The Bridge (night rail bridge)
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 5 | house | two-story timber house near bridge approach | 720x1248x910 | (-2928,160,425) zb -30 | 114/71 | flrwood1_rep:71, afrikwall7_set1base:16 | cand |
| 6 | building | low wooden shed/barn (barn-door texture) | 992x408x272 | (-3520,-3868,-183) zb -319 | 22/21 | flrwood1_rep:21, jh_barndoor1:1 | cand |
| 8 | emplacement | i-beam girder stack / maintenance platform | 132x144x112 | (-5116,2414,52) zb -4 | 16/4 | ibeam_flat2:15 | cand |
| 1 | low-wall | waist-high concrete block | 100x120x84 | (-5058,-4836,-182) zb -224 | 6/2 | concrete7:4 | cand (twins c3/c4) |
| 3 | low-wall | waist-high concrete block | 120x100x84 | (2752,330,110) zb 68 | 6/2 | concrete7:4 | cand |
| 4 | low-wall | waist-high concrete block | 100x120x84 | (-5618,-6912,62) zb 20 | 6/2 | concrete7:4 | cand |

### m5l1a — Sniper Town (St. Matthieu)
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 5 | ruin | shelled two-story house with exposed wood floors | 1456x656x712 | (3664,-3776,228) zb -128 | 60/54 | flrwood1_rep:19, plank_flat:16, remgn_wallexter1:8 | OK (reduced detail) |
| 18 | ruin | ruined corner stone house with cellar | 589x494x554 | [origin] (0,0,-93) zb -370 | 41/22 | stonewall1grim:15, beam_wood1:8, plank_flat:7 | OK (origin-prefab caveat) |
| 4 | ruin | roofless roughwall house shell | 980x1764x496 | (3354,-2098,272) zb 24 | 36/28 | jh_roughwall2a:17, beam_wood1:11 | cand |
| 7 | ruin | low bombed-out building footprint w/ rubble | 1382x884x408 | (2867,-4902,172) zb -32 | 33/30 | jh_roughwall2a:26, rubblebase:3 | cand |
| 10 | ruin | small shelled house with wood floor remnants | 916x1100x586 | (790,-2938,227) zb -66 | 24/18 | flrwood1:9, beam_wood1:7 | cand |
| 15 | house | small intact-roof village house fragment | 588x412x648 | (2850,-2426,292) zb -32 | 14/13 | beam_wood1:4, woodbeamed_trenchwall1:4 | cand |
| 12 | ruin | small stone outbuilding shell (east edge) | 464x512x576 | (5496,-4544,160) zb -128 | 12/12 | platestone1flt:5, plank_flat:4 | cand |
| 6 | house | tiny tile-roofed shed/outbuilding | 496x392x536 | (4252,-4992,252) zb -16 | 7/7 | jh_tileroof1:4, jh_roughwall2a:2 | cand |

### m5l1b — The Hunt Begins (bombed town)
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 19 | ruin | collapsed rough-wall stub (rubble corner) | 528x514x296 | (2424,-1599,548) zb 400 | 12/9 | jh_roughwall2a:9, beam_wood1:3 | OK |
| 6 | ruin | two-storey bombed town house | 904x1148x792 | (-900,-2046,684) zb 288 | 48/40 | plank_flat:18, flrwood1_rep:14 | cand |
| 9 | low-wall | long stone boundary/garden wall | 1752x816x512 | (-4044,-1384,544) zb 288 | 38/29 | stonewall1grim:22, beam_wood1:10 | cand |
| 18 | ruin | ruined rough-wall house with wood floor | 993x832x850 | (2608,-2208,849) zb 424 | 32/32 | flrwood1_rep:18, jh_roughwall2a:10 | cand |
| 5 | building | narrow plank-built structure (shed/lean-to row) | 688x1528x800 | (-2072,-716,968) zb 568 | 20/17 | plank_flat:16, platestone1flt:4 | cand |
| 15 | building | small plank-and-stone outbuilding | 630x1196x849 | (4333,-1094,919) zb 495 | 15/11 | plank_flat:9, stonewall1grim:6 | cand |
| 20 | ruin | partially collapsed shed w/ bridge-plank debris | 933x656x723 | (4062,760,806) zb 445 | 12/12 | plank_flat:4, jh_roughwall2a:3, bridgeplank:2 | cand |
| 11 | low-wall | plank fence/wall run | 920x340x664 | (-1204,1030,844) zb 512 | 11/7 | plank_flat:11 | cand |
| 8 | building | small wood/stone hut | 537x491x799 | (-4632,-4311,652) zb 253 | 9/8 | flrwood1_rep:6, platestone1flt:3 | cand |

### m5l2a — Sniper Town (m5l2a)
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 7 | ruin | gutted plank/beam building interior | 1264x640x640 | (1288,1352,512) zb 192 | 21/17 | beam_wood1:9, plank_flat:7 | cand |
| 8 | house | small timber-framed house | 694x796x636 | (5001,434,602) zb 284 | 16/9 | beam_wood1:9, drkgry1beam:4 | cand |
| 1 | ruin | small ruined room / floor section w/ plaster walls | 368x504x437 | (1112,228,494) zb 275 | 9/8 | flrwood1_rep:6, plaster_wall2:2 | cand |
| 4 | low-wall | free-standing plaster wall segment (608u, 32 thick) | 608x32x296 | (3496,-816,788) zb 640 | 6/6 | plaster_wall2a:6 | cand |

### m5l2b — Day of the Tiger (King Tiger ride)
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 1 | building | single-texture town house shell | 680x744x332 | (1140,6476,-110) zb -276 | 26/26 | fltwall1grim2_1:26 | cand |
| 5 | ruin | collapsed stone/timber building corner | 1044x722x568 | (-4614,-791,220) zb -64 | 12/9 | platestone1flt:6, beam_wood1:4 | cand |
| 0 | ruin | freestanding stone wall section (upper street) | 408x1288x728 | (-7972,-1604,620) zb 256 | 9/9 | stonewall1grim:6, plank_flat:3 | cand |
| 3 | ruin | plank-and-stone ruined facade | 336x1104x772 | (-7776,-416,446) zb 60 | 9/8 | plank_flat:6, stonewall1grim:2 | cand |
| 8 | ruin | tall stone ruin wall | 312x1052x888 | (-5548,-3430,444) zb 0 | 9/9 | stonewall1grim:5, plank_flat:2 | cand |
| 2 | low-wall | plank rubble barricade / low wall run | 392x1024x192 | (2724,-1496,40) zb -56 | 8/8 | plank_flat:6, sootwallflt:1 | cand |
| 11 | low-wall | thin exterior wall remnant (remagen texture) | 20x376x512 | (-6650,-2044,544) zb 288 | 7/5 | remgn_wallexter1:4, beam_wood1:2 | cand |
| 6 | ruin | rough-wall building corner ruin | 501x804x569 | (-1318,-946,204) zb -81 | 5/5 | jh_roughwall2a:4, beam_wood1:1 | cand |

### m5l3 — The Bridge (ruined river town)
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 16 | ruin | collapsed stone house shell (large ruined building) | 1324x776x712 | (574,2920,760) zb 404 | 50/48 | stonewall1grim:24, stonewall2grim:16 | OK (large — reduced detail) |
| 3 | building | planked-roof stone outbuilding / warehouse | 764x1916x810 | (2226,4682,655) zb 250 | 60/52 | plank_flat:22, platestone1flt:15 | cand |
| 10 | building | stone corner building with plank floor | 1680x848x1144 | (3168,6720,740) zb 168 | 40/37 | platestone1flt:16, plank_flat:8 | cand |
| 5 | ruin | small ruined stone house (platestone shell) | 984x756x960 | (3084,5282,896) zb 416 | 35/29 | platestone1flt:21, flrwood1_rep:7 | cand |
| 11 | building | windowed exterior-wall townhouse (Remagen facade) | 806x2040x1169 | (2831,3368,855) zb 271 | 31/29 | remgn_wallexter1win:8, remgn_wallexter1:6 | cand |
| 12 | ruin | soot-scorched ruined house below street level | 1246x1314x992 | (3991,5711,408) zb -88 | 25/25 | remgn_wallexter1:6, sootwallflt:6 | cand |
| 9 | low-wall | stone rubble wall / bridge abutment segment | 1040x512x399 | (-2568,-824,591) zb 392 | 20/20 | platestone1flt:20 | cand |
| 6 | ruin | freestanding tall stone wall fragment | 584x264x720 | (364,-2476,944) zb 584 | 12/11 | platestone1flt:12 | cand |
| 8 | low-wall | chest-high stone garden wall | 606x312x176 | (-1621,-676,480) zb 392 | 10/10 | platestone1flt:5, remgn_wallexter1:5 | cand (cv5 — good cover-pack pick) |

### m6l1a — forest road ambush
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 0 | emplacement | concrete bunker-wall emplacement | 352x192x72 | (-2272,128,5596) zb 5560 | 8/6 | dday_bunker_wall1bsml:8 | OK (twin at c1 (-864,5392,5596)) |

### m6l1b — Siegfried Forest winter bunkers
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 2 | bunker | medium Siegfried-line bunker | 435x719x288 | (-2632,-4750,1840) zb 1696 | 24/22 | winterbunkerwall:9, resrchnorway_wall1low:9 | OK — **TOP 15 #3** |
| 1 | low-wall | chest-high concrete bunker wall segment | 192x352x72 | (-5664,3136,1948) zb 1912 | 8/6 | dday_bunker_wall1bsml:8 | OK — **TOP 15 #5** |
| 0 | bunker | large winter bunker complex (ibeam-roofed casemate) | 874x1038x400 | (-2175,2391,2288) zb 2088 | 115/43 | ibeam_flat2:47, winterbunkerwall:21 | cand |

### m6l1c — Fort Schmerzen surface
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 1 | bunker | fort surface bunker block (concrete + iron plate) | 1156x1096x236 | (4766,1632,122) zb 4 | 32/14 | ironwall1:8, bunker_conc2:8 | OK |
| 6 | bunker | concrete casemate room shell (jh_conc512) | 456x928x384 | (4944,3734,-528) zb -720 | 17/17 | jh_conc512b:12, jh_conc512c:2 | cand |
| 5 | low-wall | iron wall segment with metal door (72u partition) | 854x72x380 | (4765,2466,-442) zb -632 | 9/3 | ironwall1:4, metaldoor_gen1plain:2 | cand |
| 2 | low-wall | fort perimeter concrete wall run (bunker_conc2) | 352x1896x236 | (4364,2032,122) zb 4 | 6/6 | jh_conc512b:2, bunker_conc2:2 | cand |
| 3 | low-wall | long interior concrete wall (60u thick) | 1104x60x384 | (4472,5802,-528) zb -720 | 4/4 | jh_conc512b:3, jh_conc512c:1 | cand |

### m6l2a — winter village
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 1 | house | two-story tudor winter house (lit windows, wood floor) | 888x828x595 | (-2196,-890,290) zb -8 | 60/54 | tudor_set1w_exwall1flatw:39, ibeam_vertwnter:6 | cand |
| 5 | bunker | concrete guard bunker/blockhouse (door + iron bars) | 676x694x1052 | [near-origin] (-2,-81,390) zb -136 | 58/43 | flatgrey_conc:16, tudor_set1w_exwall1flatw:15 | cand |

### m6l2b — winter rail approach
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 10 | ruin | small ruined plaster/stone house (two-story shell) | 384x384x488 | (3544,4616,116) zb -128 | 11/11 | plasterwal1a:5, stonewall1snow:3 | OK |
| 12 | house | snow-covered stone townhouse with roof | 1287x1608x1252 | (6429,-3932,478) zb -148 | 46/44 | stonewall1snow:9, plasterwal4b1:7 | cand |
| 15 | house | lit two-storey house (windows + white wood) | 1264x712x976 | (680,-7324,584) zb 96 | 34/22 | jh_window2pj_lit:14, whitewoodbmtrm:14 | cand |
| 5 | building | small industrial outbuilding (iron/plaster) | 1231x1177x548 | (6152,7052,146) zb -128 | 27/21 | ibeam_flat2:9, plasterwal1a:3 | cand |
| 2 | low-wall | plaster wall segment along tracks | 304x1152x296 | (6816,2632,20) zb -128 | 12/10 | plasterwal4b1:9, ibeam_vert:2 | cand |
| 1 | low-wall | elevated concrete parapet/walkway edge | 423x794x196 | (4628,4709,262) zb 164 | 8/5 | csnowconc:3, plasterwal1a:3 | cand |
| 9 | ruin | partial plaster building shell with wood floor | 832x568x392 | (3760,6796,164) zb -32 | 6/6 | plasterwal1a:3, flrwood2:2 | cand |

### m6l3a — Fort Schmerzen interior
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 7 | pillbox | small bunker_wall guard-post cube | 192x192x224 | (1504,-6624,-864) zb -976 | 6/6 | bunker_wall:6 | OK |
| 1 | bunker | iron-walled fort interior room | 560x834x424 | (-680,-1185,-596) zb -808 | 74/30 | ironwall1:28, ibeam_vert:16 | SEG (merged fort interior slice) |
| 3 | building | industrial iron corridor/gallery section | 448x1024x368 | (-1344,-2816,-568) zb -752 | 51/26 | ibeam_vert:21, ironwall1:15 | cand |
| 2 | emplacement | I-beam framed concrete alcove | 536x368x384 | (-1900,-3592,-576) zb -768 | 31/19 | ibeam_vert:20, ibeam_flat2:4 | cand |

### m6l3b / m6l3d / m6l3e — fort interior sections
m6l3b, m6l3d: no candidates. m6l3e:
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 6 | low-wall | low concrete kerb wall | 112x480x64 | (-6120,-1696,-552) zb -584 | 7/7 | csnowconc:7 | cand |
| 5 | emplacement | concrete block pillar (waist-plus hard cover) | 280x376x304 | (-5068,-1052,-424) zb -576 | 4/4 | jh_conc512c:3, jh_conc512b:1 | cand |

---

## Spearhead (t-series, pak1.pk3 / mainta)

### t1l1 — Normandy night paradrop
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 23 | house | small thatched cottage/shed with broken windows | 419x336x110 | [origin] (10,0,-7) zb -62 | 38/31 | plank_flat:19, thatchroof_wmoss:15, window725_frame:2 | OK |
| 1 | house | Norman farmhouse (thatch/moss roof) | 1132x1106x648 | (-3674,5041,-6692) zb -7016 | 189/126 | jh_woodwall_1:50, flrwood1_rep:46, thatchroof_wmoss:25 | cand |
| 12 | low-wall | straight wooden plank fence line (8u thick) | 8x2712x244 | (-3968,-2948,-6708) zb -6830 | 22/14 | plank_flat:22 | cand |
| 6 | low-wall | tall stone wall section | 144x312x400 | (-6568,-2532,-5990) zb -6190 | 9/5 | stonewl1:9 | cand |
| 5 | low-wall | chest-high plank livestock pen | 328x426x104 | (-1136,-4413,-6404) zb -6456 | 6/6 | plank_flat:6 | cand (cv4 — good cover-pack pick) |

### t1l2 — Normandy night village
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 23 | low-wall | long tall plank fence (16u thick, 192 tall, 1752 long) | 16x1752x192 | (-2096,3708,-24) zb -120 | 15/11 | plank_flat:15 | OK (192u = vision-block fence, not vaultable; cut into segments) |
| 25 | building | barn-door shed / small outbuilding w/ double doors | 130x264x183 | [origin] (1,0,-7) zb -98 | 64/16 | jh_barndoor1:43, jh_woodwall_1:7 | cand |
| 1 | house | small wood-shingled farmhouse | 1267x1167x396 | (-3926,-2552,174) zb -24 | 44/36 | plank_flat:12, jh_woodwall_1:11, jh_woodshingles1:9 | cand |
| 6 | building | small barn / farm outbuilding on concrete pad | 1172x1160x552 | (-3486,3420,260) zb -16 | 40/38 | plank_flat:22, jh_woodwall_1:11 | cand |
| 16 | low-wall | wooden plank fence line | 99x1492x208 | (-1014,470,-11) zb -115 | 14/11 | plank_flat:14 | cand |

### t1l3 — village & bridge demolition
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 2 | house | two-story concrete village house | 788x1240x616 | (-1062,1372,300) zb -8 | 153/111 | whitewoodbmtrm:37, concdeco1trim:30, flatgrey_conc:26 | OK (reduced detail) |
| 13 | ruin | pitted-brick ruined house shell | 856x824x328 | (4960,1056,164) zb 0 | 21/6 | pitted_brick:14, hollbrick_flat1:3 | OK |
| 0 | emplacement | iron pipe/crate supply position (bunker-pipe shed) | 644x750x264 | (4814,279,132) zb 0 | 34/8 | bnkrpipe1_iron:21, jh_corrdoor1a:4 | cand |
| 25 | ruin | small ruined brick/wood shed at origin | 408x344x128 | [origin] (0,0,0) zb -64 | 34/18 | jh_woodwall2:9, pitted_brick:7 | cand |
| 11 | house | small shingled outbuilding | 448x543x340 | (6251,2834,158) zb -12 | 25/17 | whitewoodbmtrm:8, ibeam_flat2:7 | cand |
| 10 | house | brick cottage with shingle roof | 840x878x668 | (388,1143,394) zb 60 | 22/13 | whitewoodbmtrm:8, afrik_wall1b:4 | cand |
| 12 | house | small concrete/shingle house | 584x704x350 | (212,3836,225) zb 50 | 20/14 | whitewoodbmtrm:9, flatgrey_conc:6 | cand |
| 24 | low-wall | Normandy hedgerow line | 2112x512x248 | (736,208,116) zb -8 | 11/11 | ta_hedgerow:11 | cand |
| 8 | low-wall | low concrete wall/foundation | 356x622x116 | (1878,4201,58) zb 0 | 10/6 | jh_conc512a:10 | cand |
| 18 | low-wall | plank fence along hedgerow | 224x912x252 | (-1552,536,118) zb -8 | 10/8 | plank_flat:8, ta_hedgerow:2 | cand |

### t2l1 — Ardennes village
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 3 | house | small wooden barn/shed with crates | 384x210x176 | [origin] (0,0,6) zb -82 | 31/21 | wood_joist_trim_masked:23, jh_barndoor1:4 | OK |

### t2l2 — Bastogne halftrack ride
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 2 | emplacement | reinforced crate stack | 66x132x112 | (5865,2940,1970) zb 1914 | 4/4 | crate_reinforced1_topflt:4 | OK (cheapest crate piece in the trilogy) |
| 0 | house | snow-covered Ardennes village house | 772x1036x352 | (5426,4074,2064) zb 1888 | 20/16 | winterroof_set1aw:11, crate_reinforced1_topflt:4 | cand |

### t2l3 — Ardennes forest (wave defense)
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 1 | low-wall | stacked snowy log barricade | 396x87x83 | (-194,-1186,-25) zb -66 | 9/9 | snowylog:9 | OK — **TOP 15 #15** |

### t2l4 — Ardennes winter town
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 4 | bunker | concrete bunker (bunker_wall2 structure) | 640x416x368 | (696,1080,536) zb 352 | 56/49 | bunker_wall2:38, stonebricks1drk:12 | OK — **TOP 15 #11** |
| 8 | ruin | broken-windowed bunker-wall building interior | 496x708x604 | (136,0,134) zb -168 | 65/20 | window725_broken:20, bunker_wall2:13, flrwood2wntr:9 | OK (reduced detail) |
| 9 | house | snow-roofed stone/timber house | 1264x728x440 | (-1136,5532,620) zb 400 | 82/52 | ironwall1:30, beam_wood1:26 | cand |
| 7 | house | winter-roofed farmhouse/barn | 1544x1724x592 | (-716,3618,552) zb 256 | 73/52 | beam_wood1:23, winterroof_set1w:12 | cand |
| 5 | house | small wood/iron shed or outbuilding | 648x496x392 | (572,1888,516) zb 320 | 42/24 | beam_wood1:17, ironwall1:15 | cand |
| 6 | low-wall | long iron/concrete wall run | 1186x637x328 | (-959,1430,420) zb 256 | 32/24 | ironwall1:24, flatgrey_conc:3 | cand |

### t3l1 — Berlin city streets
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 36 | ruin | collapsed plaster house with rubble | 834x1150x800 | (-1127,-5966,432) zb 32 | 26/26 | plaster_wall3d:7, beam_wood1:5, brln_rubble:4 | OK |
| 52 | house | timber-framed row house | 1240x758x720 | (766,-7609,376) zb 16 | 29/22 | beam_wood1:20, algierwall_set5:7 | cand |
| 51 | house | small timber-framed cottage | 881x1208x720 | (-1834,-7354,376) zb 16 | 25/21 | beam_wood1:18, tudor_set1_exwall1a:6 | cand |
| 14 | ruin | shot-up concrete wall section | 759x963x976 | (1884,2622,344) zb -144 | 22/12 | concretewall2:12, berlinwall2b_shot:8 | cand (same cluster confirmed SEG on t3l2) |
| 35 | house | small plaster house | 680x682x719 | (-2710,-6495,376) zb 16 | 19/18 | plaster_wall3d:12, beam_wood1:5 | cand |
| 13 | ruin | rubble mound with broken wall stubs | 520x1048x560 | (-5732,-3784,344) zb 64 | 18/18 | brln_rubble:7, berlinwall2a_shot:6 | cand |

### t3l2 — Berlin final mission
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 58 | ruin | small collapsed corner ruin (tall wall remnants) | 775x725x595 | (5318,-6959,223) zb -75 | 38/37 | fltwall1grmy:26, fltwall1grim2_1:11 | OK (reduced detail) |
| 15 | ruin | shot-up concrete wall ruin (berlinwall2 corner) | 759x963x976 | (1884,2622,344) zb -144 | 22/12 | concretewall2:12, berlinwall2b_shot:8 | SEG (L/U street-block slice; harvest wall panels only) |
| 38 | ruin | gutted plaster-and-beam house ruin | 834x1150x800 | (-1127,-5966,432) zb 32 | 24/24 | plaster_wall3d:7, brln_rubble:6 | cand (same prefab as t3l1 c36 OK) |
| 50 | building | timber-frame (tudor) house, mostly wood beams | 814x1131x720 | (-1800,-7392,376) zb 16 | 24/20 | beam_wood1:18, tudor_set1_exwall1a:6 | cand |
| 36 | low-wall | collapsed beam/wall segment (low profile) | 952x424x576 | (-570,-7562,304) zb 16 | 22/20 | beam_wood1:16, brln_rubble:3 | cand |
| 42 | low-wall | cracked hotel wall remnant w/ plank bridging | 1299x534x404 | (-2195,281,202) zb 0 | 21/21 | hotelwall1crk:14, jh_conc512damg:4 | cand |
| 51 | house | small mixed-wall house (beams + algiers/tudor) | 656x662x720 | (474,-7657,376) zb 16 | 19/13 | beam_wood1:9, algierwall_set5:7 | cand |
| 14 | ruin | rubble mound with shot Berlin wall fragments | 520x1048x560 | (-5732,-3784,344) zb 64 | 18/18 | brln_rubble:7, berlinwall2a_shot:6 | cand |
| 37 | house | small plaster house shell with wood beams | 680x682x719 | (-2710,-6495,376) zb 16 | 18/18 | plaster_wall3d:12, beam_wood1:5 | cand |

---

## Breakthrough (e-series, pak1.pk3 / maintt)

### e1l1 — Kasserine Pass
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 7 | bunker | small concrete bunker with metal doors | 432x192x166 | [origin] (0,0,9) zb -74 | 103/18 | bunkerdoor3:48, bunk_ceiling:18, concretewall2:15 | OK — **TOP 15 #6** |
| 4 | low-wall | low reinforced-crate row | 416x122x66 | (-4949,-2176,278) zb 245 | 11/0 | crate_reinforced1_top:11 | OK (66u = perfect crouch cover) |
| 6 | emplacement | crate stack (German supply crates) | 240x192x520 | (-5312,88,532) zb 272 | 26/20 | gnrlcratesml_top:26 | cand |
| 5 | emplacement | crate stack (German supply crates) | 376x192x528 | (-2860,-4144,552) zb 288 | 25/21 | gnrlcratesml_top:24 | cand |
| 3 | low-wall | i-beam and crate barricade | 214x236x112 | (-5252,-2932,300) zb 244 | 19/4 | ibeam_flat2:13, crate_reinforced1_top:5 | cand |

### e1l2 — Bizerte (artillery plateau)
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 4 | emplacement | square iron/concrete gun-emplacement pit | 416x416x100 | (-2936,-5632,914) zb 864 | 12/6 | ironwall1:7, jh_conc512brown:5 | OK — **TOP 15 #2** |
| 3 | emplacement | rectangular iron/concrete sandwall emplacement | 352x144x116 | (-1656,-3392,778) zb 720 | 11/5 | ironwall1:7, jh_conc512brown:4 | OK — **TOP 15 #7** |
| 0 | bunker | concrete/iron bunker room w/ tudor exterior | 482x304x487 | (817,3528,256) zb 13 | 44/21 | bunk_ceiling:14, tudor_set1w_exwall1flat:11, ironwall1:10 | cand |
| 9 | low-wall | L/U-shaped shell-holed concrete wall (Cassino-style) | 256x256x112 | (-5608,-3696,552) zb 496 | 7/7 | it_e_3-2wallconcrete01:5, ...shole_01-512:2 | cand (cv5 — cover-pack pick) |
| 2 | low-wall | concrete perimeter wall corner | 468x357x80 | (5841,929,156) zb 116 | 4/4 | it_e_3-2wallconcrete01:4 | cand |

### e1l3 — Bizerte night infiltration
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 19 | building | small stone courtyard structure w/ wood beams | 256x320x178 | [origin] (0,0,7) zb -82 | 113/38 | beam_wood1:25, af-e-stonewall03highpass:25, cobblestone:19 | OK |
| 4 | building | iron-walled harbor shed (tall — 2-story harbor tower) | 429x624x630 | (1791,-3592,315) zb 0 | 17/9 | ironwall1:9, plank_flat:5 | OK |
| 8 | house | raised two-room house (south quarter) | 1356x548x528 | (866,-6734,392) zb 128 | 35/31 | af-e-door02wallbase:8, af-e-door03wallbase03:7 | cand |
| 12 | low-wall | compound wall segment (southwest, afrik_wall) | 1164x564x448 | (-1654,-5134,352) zb 128 | 14/13 | afrik_wall1a:10, af-e-door03wallbase02:3 | cand |
| 5 | building | small iron dock shack | 320x272x548 | (1792,-4264,274) zb 0 | 11/7 | ironwall1:5, plank_flat:3 | cand |

### e1l4 — Bizerte harbor
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 26 | low-wall | crate stack (stacked supply crates, mixed heights) | 227x338x140 | (-4628,2460,114) zb 44 | 12/12 | gnrlcratesml_side:5, foodcrate_end:4, crate_reinforced1_topflt:3 | OK — **TOP 15 #8** |
| 28 | low-wall | small crate stack | 218x265x96 | (2151,-1225,136) zb 88 | 10/10 | foodcrate_end:4, gnrlcratesml_side:3, crate_reinforced1_topflt:3 | OK |
| 1 | building | small Bizerte house with trench-wall cover | 1129x632x360 | (-5644,2260,220) zb 40 | 30/29 | af_e_facade_04:15, woodbeamed_trenchwall2:6 | cand |
| 19 | ruin | castle/old-wall street section | 2024x656x496 | (812,-3264,280) zb 32 | 27/26 | woodbeamed_trenchwall2:9, af-e-wallcastle01a:8 | cand |
| 22 | house | small whitewashed Algiers house | 712x496x424 | (676,272,284) zb 72 | 16/16 | whitewoodbmtrm:8, algierwall1drk_1flat:4 | cand |
| 13 | house | tiny whitewashed house/kiosk | 400x336x424 | (-5952,3840,284) zb 72 | 13/13 | whitewoodbmtrm:8, algierwall1drk_1flat:4 | cand |
| 12 | low-wall | harbor perimeter wall section | 432x1248x368 | (-6608,5616,344) zb 160 | 10/10 | algierwall1b:6, wh_conc2b:2 | cand |

### e2l1 — Sicily opener
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 3 | house | two-story wooden shack/outbuilding (plank walls) | 321x370x316 | [origin] (0,-1,0) zb -158 | 30/22 | plank_flat:18, jh_oldwood1:10 | cand |
| 2 | low-wall | wooden plank wall/fence w/ bridge-plank decking | 53x320x252 | (5492,-4186,80) zb -46 | 8/4 | plank_flat:5, bridgeplank:2 | cand |

### e2l2 — Palermo harbor/shipyard
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 29 | emplacement | plank-and-timber revetment (mirror twin of c26) | 280x352x172 | (2752,-2004,2602) zb 2516 | 29/13 | plank_flat:20, woodbeamed_trenchwall1:9 | OK — **TOP 15 #9** |
| 26 | emplacement | plank-and-timber trench revetment segment | 352x280x172 | (-1425,1038,2570) zb 2484 | 29/13 | plank_flat:20, woodbeamed_trenchwall1:9 | SEG (connected trenchworks — extract c29 instead) |
| 18 | building | wooden scaffold tower (planks and beams) | 520x324x560 | (3344,6482,2866) zb 2586 | 46/35 | wood_plank:38, beam_wood1:5 | cand |
| 22 | low-wall | dockside crate row / loading-line barricade | 2038x374x353 | (1031,2215,2672) zb 2496 | 33/32 | beam_wood1:12, crate_reinforced1_topflt:5 | cand |
| 10 | house | Italian house facade w/ shuttered/barred windows | 464x944x600 | (-4280,-728,2828) zb 2528 | 28/8 | af-e-door04windowshutter:12, windowbarred:6 | cand |
| 19 | low-wall | crate stack line along beam walkway | 352x1208x432 | (2742,5784,2720) zb 2504 | 24/14 | beam_wood1:10, misc_crate1b:4 | cand |
| 8 | low-wall | small crate stack (German general crates) | 344x328x240 | (2396,-6076,2696) zb 2576 | 18/8 | gnrlcratesml_top:10, wood_plank:6 | cand |
| 3 | low-wall | low wooden plank wall | 528x120x96 | (-5933,-3955,2622) zb 2574 | 17/4 | flrwood1:17 | cand |
| 9 | low-wall | crate stack with plank topping | 344x488x256 | (-5840,5904,2952) zb 2824 | 14/7 | gnrlcratesml_top:7, wood_plank:6 | cand |

### e2l3 — Monte Battaglia
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 4 | ruin | burned Cassino-style ruined wall corner (boarded openings) | 944x768x506 | (-1096,-1128,-133) zb -386 | 25/24 | it_e_walltall01:15, plank_flatnohit:7 | SEG (town-street slice) |
| 9 | ruin | low stone ruin shell on elevated ground | 832x1242x322 | (3504,3997,257) zb 96 | 38/34 | platestonelittn:26, plank_flatnohit:4 | cand |
| 2 | low-wall | long plank barricade wall (~1304u run) | 1304x480x336 | (-1852,80,-256) zb -424 | 23/23 | plank_flatnohit:21 | cand |
| 10 | ruin | beige Cassino-wall ruined room footer section | 648x576x372 | (580,-1112,-34) zb -220 | 23/23 | it_e_3-2wallbeigefooter_02-512:11, platestonelitgrm:6 | cand |
| 7 | ruin | small stone outbuilding shell | 520x776x322 | (-5820,4548,-271) zb -432 | 15/15 | platestonelittn:9, ht_interiorwall_wthrdtrim:5 | cand |
| 0 | low-wall | freestanding tall stone wall segment w/ plank patching | 928x144x363 | (-1088,-1552,-146) zb -328 | 7/6 | it_e_walltall01:4, plank_flatnohit:3 | cand |

### e3l1 — Monte Cassino ruins
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 10 | low-wall | long beige stone perimeter wall | 1864x540x264 | (-1344,5446,164) zb 32 | 22/22 | it_e_3-2wallbeigebase_01-512:20 | cand |
| 4 | low-wall | concrete wall section with crates | 1028x349x495 | (2786,1774,264) zb 17 | 18/16 | it_e_3-2wallconcrete01:5, flatgrey_conc:4 | cand |
| 6 | bunker | concrete blockhouse (all-concrete structure) | 1022x551x752 | (2169,845,400) zb 24 | 13/12 | concrete7:12, flatgrey_conc:1 | cand |
| 3 | ruin | ruined plaster house shell | 772x1248x768 | (1218,-784,352) zb -32 | 11/11 | plaster_wall2a:5, it_e_3-2walltanbase_02-512:3 | cand |
| 8 | ruin | ruined house corner (beige walls and rubble) | 784x608x584 | (-216,2736,348) zb 56 | 9/9 | it_e_3-2wallcorebeige01:3, rubble:2 | cand |
| 18 | emplacement | elevated wooden plank platform (sniper/observation) | 480x480x480 | (-1008,6864,752) zb 512 | 9/8 | plank_flat:9 | cand |
| 5 | ruin | small ruined outbuilding | 592x752x432 | (3800,1640,232) zb 16 | 8/8 | it_e_3-2wallcorebeige02:5 | cand |
| 7 | low-wall | stone courtyard wall enclosure | 619x642x376 | (3018,2671,228) zb 40 | 6/6 | stonewall1grim:4, concretewall2:1 | cand |

### e3l2 — Monte Cassino town
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 25 | house | two-story Italian stone house | 720x1144x672 | (472,3996,-120) zb -456 | 29/19 | it_e_3-2walltanbase_02-512:7, wood_joist_trim_masked:6 | OK |
| 5 | house | small concrete/plaster Cassino house w/ french door | 876x873x902 | (-690,4720,21) zb -430 | 28/16 | it_e_3-2wallcorebeige01:7, conc_rough4a:7 | OK (tall narrow shell) |
| 0 | house | tudor row house (long facade) | 2711x800x1128 | (-1994,-2097,180) zb -384 | 62/33 | tudor_set1_exwall1fltseem:25 | cand |
| 12 | ruin | barricaded ruined house (planks over beige walls) | 967x763x896 | (5192,-5978,-48) zb -496 | 23/18 | it_e_3-2wallbeigebase:6, plank_flatnohit:5 | cand |
| 19 | ruin | plank-floored partial structure / collapsed corner | 360x848x624 | (-2788,3400,-64) zb -376 | 22/18 | plank_flat:10, it_e_3-2wallcorebeige01:4 | cand |
| 27 | ruin | tan-plaster wall shell (roofless ruin) | 748x753x592 | (-2783,2272,-72) zb -368 | 20/20 | it_e_3-2walltanbase_02b:17, algierwall1_0:3 | cand |
| 20 | low-wall | low concrete/tudor courtyard wall run | 367x1047x456 | (-3440,-1250,-132) zb -360 | 18/18 | tudor_set1w_exwall1flat:6, flrwood1_rep:5 | cand |
| 8 | building | tall narrow Cassino tower house | 743x864x1248 | (410,912,176) zb -448 | 17/14 | it_e_3-2wallcorebeige01:9, beam_wood1:3 | cand |
| 10 | emplacement | concrete strongpoint with crates | 670x1067x725 | (-3601,-196,-6) zb -368 | 17/12 | concrete7:8, beam_wood1:4 | cand |

### e3l3 — Monte Battaglia castle defense
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 2 | low-wall | wooden plank parapet/walkway wall section | 132x784x164 | (-6242,-4184,506) zb 424 | 31/23 | flrwood1_rep:23, plank_flat:8 | cand |
| 3 | ruin | Italian street barricade (planks over dark stone rubble) | 316x543x690 | (-3854,6357,391) zb 46 | 13/9 | plank_flatnohit:9, stonebricks1drknohit:3 | cand |
| 21 | low-wall | plank fence/scaffold rail section | 332x57x252 | (-6658,-7097,550) zb 424 | 10/5 | plank_flat:5, flrwood1_rep:3 | cand |
| 14 | low-wall | small waist-high Italian barricade chunk | 107x155x116 | (4599,4305,-6) zb -64 | 7/4 | plank_flatnohit:5, stonebricks1drknohit:2 | cand |

### e3l4 — Monte Battaglia (castle defense)
| Cl | Type | Name | Dims | Center (zb) | Br/Maj | Top tex | Status |
|---|---|---|---|---|---|---|---|
| 2 | ruin | ruined stone house (cobblestone/ruinswall) | 772x796x484 | (-4606,3578,1022) zb 780 | 81/63 | flrwood1_rep:32, it_p_castlecobblestone:26, ruinswall:16 | OK (reduced detail) |
| 1 | low-wall | long stone boundary wall segment | 352x2080x208 | (-5440,-3000,632) zb 528 | 37/37 | exterior_wall_2:37 | cand |
| 9 | emplacement | crate-stack supply point | 669x700x128 | (3794,-1502,832) zb 768 | 33/11 | flrwood1_rep:21, uscrate_02_:12 | cand |
| 3 | bunker | wood-beamed trench dugout shelter | 416x436x272 | (640,-5386,472) zb 336 | 21/12 | flrwood1_rep:16, woodbeamed_trenchwall2:5 | cand |
| 4 | house | small plaster/wood shack | 456x336x288 | (-12,-6000,576) zb 432 | 12/11 | woodbeamed_trenchwall2:6, flrwood1_rep:3 | cand |

---

## Cover pack — best SMALL pure-cover pieces (~10-40 pieces each)

Quick-place combat cover: low walls, crate stacks, single emplacements. All fit the budget at full fidelity.

| Piece | Map/Cl | Dims | Br (~pc) | Height class | Status |
|---|---|---|---|---|---|
| concrete wall run 1008u | m4l2 c9 | 208x1008x192 | 4 (~12) | over-chest | OK |
| reinforced crate stack | t2l2 c2 | 66x132x112 | 4 (~12) | chest/head | OK |
| bunker_wall guard-post cube | m6l3a c7 | 192x192x224 | 6 (~18) | full-height block | OK |
| chest-high bunker wall | m6l1b c1 | 192x352x72 | 8 (~24) | chest | OK |
| bunker-wall emplacement | m6l1a c0 | 352x192x72 | 8 (~24) | chest (head-high w/ corners) | OK |
| winter-concrete pillbox | m2l3 c6 | 160x288x168 | 8 (~24) | enterable | OK |
| snowy log barricade | t2l3 c1 | 396x87x83 | 9 (~27) | chest/head | OK |
| small crate stack | e1l4 c28 | 218x265x96 | 10 (~30) | knee-waist | OK |
| wood-beamed trench section | m4l1 c4 | 752x640x262 | 10 (~30) | trench | OK |
| reinforced-crate row | e1l1 c4 | 416x122x66 | 11 (~33) | crouch (66u) | OK |
| rectangular sandwall emplacement | e1l2 c3 | 352x144x116 | 11 (~33) | waist-chest | OK |
| square gun-pit | e1l2 c4 | 416x416x100 | 12 (~36) | chest ring | OK |
| crate stack (mixed heights) | e1l4 c26 | 227x338x140 | 12 (~36) | chest-head | OK |
| rough-wall rubble corner | m5l1b c19 | 528x514x296 | 12 (~36) | chest-head broken | OK |
| chest-high stone garden wall | m5l3 c8 | 606x312x176 | 10 (~30) | chest | cand (cv5) |
| shell-holed concrete wall L | e1l2 c9 | 256x256x112 | 7 (~21) | chest | cand (cv5) |
| waist-high concrete block | m4l3 c1/3/4 | ~100x120x84 | 6 (~18) | waist | cand (x3 twins) |
| plank livestock pen | t1l1 c5 | 328x426x104 | 6 (~18) | chest | cand |
| waist-high Italian barricade | e3l3 c14 | 107x155x116 | 7 (~21) | waist | cand |
| freestanding plaster wall | m5l2a c4 | 608x32x296 | 6 (~18) | full-height thin | cand |

Suggested first wave for the pack (all verified, textures span all three theaters/seasons): m4l2 c9 wall + m6l1b c1 wall + e1l2 c3/c4 emplacements + e1l4 c26/c28 crates + t2l2 c2 crate + t2l3 c1 logs + m4l1 c4 trench + m2l3 c6 pillbox. Ten templates, every one <=40 pieces, covering concrete/wood/crate/log/winter looks.
