# Coverage report v2
**1268 findings** across 54 maps


**Module fingerprints:** cgame Aug  5 2026 21:41:09 ENTBITS=11 MAX_SOUNDS=1600 | game Aug  5 2026 21:41:02 ENTBITS=11 MAX_SOUNDS=1600

## e1l1
walker: ok | triggers 239/242 | snd 246 | SNDMISS 0 | labels 264
engine force-activated: 2356 triggers; committed fires recorded: 70340 (uncommitted = locked / already-spent / filtered)
**NEW error signatures (30):**
  - `NoEvent:enter` x217
  - `NoEvent:flickeralpha` x56
  - `ScriptError:command 'thread' applied to NULL listener` x42
  - `ScriptError:command 'waitTill' applied to NULL listener` x37
  - `ScriptError:There are 2 entities with targetname 't#'. You are using a command that requires exactly o` x30
  - `ScriptError:binary '>' applied to incompatible types 'float' and 'none'` x18
  - `ScriptError:command 'remove' applied to NULL listener` x18
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x14
  - `ScriptError:binary '-' applied to incompatible types 'none' and 'float'` x12
  - `ScriptError:command 'show' applied to NULL listener` x12
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x7
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x7
  - `NoImage:sun` x7
  - `NoImage:gfx/2d/sunflare` x7
  - `ScriptError:Failed execution of command 'set_respawn' for class 'ProjectileGenerator_Projectile' Targe` x7

| never fired | targetname | setthread | at |
|---|---|---|---|
| trigger_once | - | - | [5724, 2804, 608] |
| trigger_once | - | - | [6383, 2127, 608] |
| trigger_once | - | - | [2852, 878, 232] |

## e1l2
walker: ok | triggers 164/167 | snd 76 | SNDMISS 0 | labels 100
engine force-activated: 630 triggers; committed fires recorded: 9445 (uncommitted = locked / already-spent / filtered)
**NEW error signatures (21):**
  - `NoEvent:damageable` x66
  - `NoEvent:enter` x62
  - `ScriptError:ModifyDrive used when not driving!` x18
  - `NoEvent:flickeralpha` x16
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x4
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x2
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x2
  - `NoImage:sun` x2
  - `NoImage:gfx/2d/sunflare` x2
  - `NoImage:textures/menu/exit` x2
  - `NoImage:poopy` x2
  - `NoImage:bh_snow_puff1.spr` x2
  - `NoImage:sm_explosion.spr` x2
  - `NoImage:supashermantred_2` x2
  - `NoImage:#handview` x2

| never fired | targetname | setthread | at |
|---|---|---|---|
| trigger_multiple | - | - | [-4104, 2048, 532] |
| trigger_multiple | - | - | [-3756, -2968, 184] |
| trigger_multiple | - | - | [650, -4441, 351] |

## e1l3
walker: ok | triggers 134/173 | snd 209 | SNDMISS 0 | labels 209
engine force-activated: 866 triggers; committed fires recorded: 4188 (uncommitted = locked / already-spent / filtered)
**NEW error signatures (36):**
  - `ScriptError:Field 'origin' applied to NULL listener` x124
  - `ScriptError:Cannot cast 'none' to vector` x118
  - `NoEvent:enter` x62
  - `ScriptError:command 'thread' applied to NULL listener` x50
  - `ScriptError:command 'waitTill' applied to NULL listener` x30
  - `CouldntLoad:models/nil` x21
  - `NoEvent:flickeralpha` x16
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x4
  - `ScriptError:command 'remove' applied to NULL listener` x4
  - `ScriptError:command 'delete' applied to NULL listener` x4
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x2
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x2
  - `NoImage:sun` x2
  - `NoImage:gfx/2d/sunflare` x2
  - `NoImage:textures/menu/exit` x2

| never fired | targetname | setthread | at |
|---|---|---|---|
| trigger_multiple | - | - | [-621, 2944, 200] |
| trigger_multiple | - | - | [-1216, 2976, 144] |
| trigger_multiple | - | - | [-1120, -4688, 80] |
| trigger_use | - | - | [608, -6476, 208] |
| trigger_use | - | - | [1232, -6604, 216] |
| trigger_use | - | - | [2084, -5888, 192] |
| trigger_use | - | - | [336, -5324, 200] |
| trigger_use | - | - | [-1216, -5412, 160] |
| trigger_use | - | - | [2100, -1088, 192] |
| trigger_use | - | - | [2144, -2484, 216] |
| trigger_use | - | - | [3916, -2176, 236] |
| trigger_use | - | - | [3452, -1696, 200] |
| trigger_use | - | - | [3008, -892, 200] |
| trigger_use | - | - | [3417, -615, 200] |
| trigger_use | - | - | [3084, -80, 212] |
| trigger_use | - | - | [3340, 208, 216] |
| trigger_use | - | - | [2784, 372, 216] |
| trigger_use | - | - | [2712, 1028, 208] |
| trigger_use | - | - | [2876, 1952, 204] |
| trigger_use | - | - | [1040, 1652, 216] |
| trigger_use | - | - | [196, 2360, 208] |
| trigger_use | - | - | [-1156, 2848, 368] |
| trigger_use | - | - | [-832, 3572, 368] |
| trigger_use | - | - | [-1348, 3504, 560] |
| trigger_use | - | - | [-1216, 3016, 576] |
| trigger_use | - | - | [-1376, 2828, 576] |
| trigger_use | - | - | [-1056, 2828, 576] |
| trigger_use | - | - | [-416, 2804, 384] |
| trigger_use | - | - | [-160, 2804, 384] |
| trigger_use | - | - | [-528, 2804, 192] |
| trigger_use | - | - | [-352, 2804, 192] |
| trigger_use | - | - | [-176, 2804, 192] |
| trigger_use | - | - | [1028, -720, 192] |
| trigger_use | - | - | [-68, -720, 192] |
| trigger_use | - | - | [-76, -720, 576] |
| trigger_use | - | - | [-1376, -1292, 352] |
| trigger_use | - | - | [964, -2416, 128] |
| trigger_use | - | - | [3120, 972, 208] |
| trigger_multiple | - | ShadowThread | [3564, -1696, 208] |

## e1l4
walker: ok | triggers 191/204 | snd 63 | SNDMISS 1 | labels 95
engine force-activated: 386 triggers; committed fires recorded: 6443 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** alarm_switch
**NEW error signatures (48):**
  - `NoEvent:enter` x248
  - `ScriptError:Cannot cast 'array' to listener` x228
  - `ScriptError:Cannot cast 'none' to vector` x126
  - `ScriptError:binary '*' applied to incompatible types 'none' and 'none'` x126
  - `ScriptError:binary '*' applied to incompatible types 'none' and 'float'` x126
  - `ScriptError:binary '-' applied to incompatible types 'none' and 'vector'` x84
  - `ScriptError:binary '+' applied to incompatible types 'none' and 'none'` x84
  - `NoEvent:flickeralpha` x64
  - `ScriptError:binary '+' applied to incompatible types 'none' and 'vector'` x42
  - `ScriptError:binary '>' applied to incompatible types 'none' and 'int'` x42
  - `ScriptError:command 'thread' applied to NULL listener` x34
  - `ScriptError:Field 'has_disguise' applied to NULL listener` x18
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x16
  - `CouldntLoad:vehicles/tigercannon.tik` x16
  - `NoEvent:fun` x15

| never fired | targetname | setthread | at |
|---|---|---|---|
| trigger_multiple | - | - | [-3440, 3120, -248] |
| trigger_multipleall | - | - | [-3600, 5388, 288] |
| trigger_multiple | explodeshiptrigger | - | [-3456, 3992, -208] |
| trigger_multipleall | - | - | [-3164, 4600, 368] |
| trigger_multipleall | - | - | [-3164, 4488, 368] |
| trigger_multipleall | - | - | [-3600, 5232, 176] |
| trigger_multipleall | - | - | [-3624, 4472, 176] |
| trigger_multipleall | - | - | [-3624, 4312, 176] |
| trigger_multipleall | - | - | [-3600, 5376, -104] |
| trigger_multipleall | - | - | [-3600, 5232, -208] |
| trigger_multipleall | - | - | [-4388, 4344, 112] |
| trigger_multipleall | - | - | [-4328, 3908, 208] |
| trigger_multiple | - | - | [-3440, 3200, 16] |

## e2l1
walker: ok | triggers 42/49 | snd 100 | SNDMISS 5 | labels 188
engine force-activated: 431 triggers; committed fires recorded: 706 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** DFRUS_E2L1_GP1301, DFRUS_E2L1_MK2602, explode_searchlight, stonecrash01, stonecrash03
**NEW error signatures (22):**
  - `NoEvent:enter` x62
  - `ScriptError:command 'thread' applied to NULL listener` x18
  - `NoEvent:flickeralpha` x16
  - `ScriptError:command 'ai_on' applied to NULL listener` x12
  - `ScriptError:command 'ai_off' applied to NULL listener` x6
  - `ScriptError:player doesn't exist` x5
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x4
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x2
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x2
  - `NoImage:sun` x2
  - `NoImage:gfx/2d/sunflare` x2
  - `NoImage:textures/menu/exit` x2
  - `NoImage:poopy` x2
  - `NoImage:bh_snow_puff1.spr` x2
  - `NoImage:glider_explosion.spr` x2

| never fired | targetname | setthread | at |
|---|---|---|---|
| trigger_once | - | dialog_over_here | [-2844, -752, 662] |
| trigger_multiple | - | maps/e2l1/aaguns.scr::AAGunShot | [3640, 3948, 280] |
| trigger_multiple | - | - | [-3684, 1208, 544] |
| trigger_once | - | maps/e2l1/gliders.scr::startfifthflyby | [-3432, -3820, 220] |
| trigger_multiple | - | maps/e2l1/aaguns.scr::AAGunShot | [4790, -60, 390] |
| trigger_multiple | - | maps/e2l1/aaguns.scr::AAGunShot | [-4320, -3012, 280] |
| trigger_once | - | maps/e2l1/objectives.scr::StartFinalBattleObjective | [-2580, -1536, 628] |

## e2l2
walker: ok | triggers 121/125 | snd 58 | SNDMISS 0 | labels 80
engine force-activated: 392 triggers; committed fires recorded: 7613 (uncommitted = locked / already-spent / filtered)
**NEW error signatures (15):**
  - `NoEvent:enter` x31
  - `NoEvent:flickeralpha` x8
  - `ScriptError:command 'thread' applied to NULL listener` x3
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x2
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x1
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x1
  - `NoImage:sun` x1
  - `NoImage:gfx/2d/sunflare` x1
  - `NoEvent:animname` x1
  - `ScriptError:player doesn't exist` x1
  - `NoImage:textures/menu/exit` x1
  - `NoImage:poopy` x1
  - `NoImage:bh_snow_puff1.spr` x1
  - `NoImage:#handview` x1
  - `NoImage:viewsleeves_camo` x1

| never fired | targetname | setthread | at |
|---|---|---|---|
| trigger_once | - | - | [931, 3189, 2636] |
| trigger_use | - | - | [1442, 3512, 3080] |
| trigger_once | - | - | [1348, 3588, 3076] |
| trigger_once | - | - | [5184, 4872, 2608] |

## e2l3
walker: ok | triggers 103/105 | snd 82 | SNDMISS 0 | labels 106
engine force-activated: 632 triggers; committed fires recorded: 3976 (uncommitted = locked / already-spent / filtered)
**NEW error signatures (21):**
  - `NoEvent:enter` x31
  - `ScriptError:Cannot cast 'none' to listener` x27
  - `ScriptError:command 'thread' applied to NIL` x14
  - `ScriptError:cannot cast NIL to an array` x13
  - `NoEvent:flickeralpha` x8
  - `ScriptError:command 'projectilevulnerable' applied to NIL` x7
  - `ScriptError:binary '>' applied to incompatible types 'none' and 'int'` x5
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x2
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x1
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x1
  - `NoImage:sun` x1
  - `NoImage:gfx/2d/sunflare` x1
  - `ScriptError:player doesn't exist` x1
  - `NoImage:textures/menu/exit` x1
  - `NoImage:poopy` x1

| never fired | targetname | setthread | at |
|---|---|---|---|
| trigger_multiple | wineHouseEntrance | - | [-144, 104, -288] |
| trigger_multiple | stopHouseParade | - | [-3504, 4292, -238] |

## e3l1
walker: ok | triggers 104/113 | snd 87 | SNDMISS 0 | labels 75
engine force-activated: 244 triggers; committed fires recorded: 584 (uncommitted = locked / already-spent / filtered)
**NEW error signatures (35):**
  - `NoEvent:enter` x62
  - `NoEvent:flickeralpha` x16
  - `ScriptError:ModifyDrive used when not driving!` x12
  - `ScriptError:player doesn't exist` x5
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x4
  - `CouldntLoad:vehicles/tigercannon.tik` x4
  - `CouldntLoad:font` x4
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x2
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x2
  - `NoImage:sun` x2
  - `NoImage:gfx/2d/sunflare` x2
  - `NoImage:textures/menu/exit` x2
  - `NoImage:poopy` x2
  - `NoImage:bh_snow_puff1.spr` x2
  - `NoImage:bomb_snowblast_01.spr` x2

| never fired | targetname | setthread | at |
|---|---|---|---|
| trigger_multiple | - | - | [-416, 3516, 424] |
| trigger_multiple | - | - | [-128, -892, 220] |
| trigger_once | - | - | [110, 4830, 86] |
| trigger_multiple | - | - | [172, 196, 96] |
| trigger_multiple | - | maps/e3l1/Courtyard.scr::BritsFollowPlayer | [-144, 5354, 224] |
| trigger_once | jeeptrigger | maps/e3l1/BritHQ.scr::StartMedicRide | [4086, -3558, 136] |
| trigger_once | - | - | [-638, 5104, 232] |
| trigger_multiple | - | - | [172, -204, 100] |
| trigger_multiple | - | - | [-56, -1020, 276] |

## e3l2
walker: ok | triggers 154/156 | snd 73 | SNDMISS 3 | labels 125
engine force-activated: 457 triggers; committed fires recorded: 12178 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** barn_door_locked, den_head_attack_h, den_head_sighted_h
**NEW error signatures (32):**
  - `NoEvent:enter` x31
  - `ScriptError:Cannot cast 'none' to listener` x15
  - `ScriptError:command 'remove' applied to NULL listener` x15
  - `NoEvent:flickeralpha` x8
  - `ScriptError:Couldn't convert string to vector - malformed string 'tag_bomb'` x5
  - `ScriptError:Cannot cast 'none' to vector` x5
  - `ScriptError:command 'anim' applied to NIL` x5
  - `ScriptError:command 'waitTill' applied to NULL listener` x4
  - `ScriptError:player doesn't exist` x3
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x2
  - `CouldntLoad:models/static/it_p_anziomap.tik` x2
  - `CouldntLoad:vehicles/panzer_cannon_europe_slow.tik` x2
  - `CouldntLoad:vehicles/panzer_smgun_europe.tik` x2
  - `CouldntLoad:vehicles/panzer_cannon_europe.tik` x2
  - `ScriptError:command 'thread' applied to NULL listener` x2

| never fired | targetname | setthread | at |
|---|---|---|---|
| trigger_multiple | - | maps/e3l2/cannon_section_1.scr::TowerExploderCheck2 | [3344, 560, 184] |
| trigger_multiple | - | maps/e3l2/cannon_section_1.scr::TowerExploderCheck1 | [2984, -336, 64] |

## e3l3
walker: ok | triggers 68/87 | snd 82 | SNDMISS 3 | labels 76
engine force-activated: 558 triggers; committed fires recorded: 9182 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** opeltruck_snd_doorclose, opeltruck_snd_on, opeltruck_snd_start
**NEW error signatures (42):**
  - `CouldntLoad:models/fx/fx-dummy.tik` x48
  - `NoEvent:enter` x31
  - `NoEvent:flickeralpha` x8
  - `NoEvent:sound_open_stop` x4
  - `ScriptError:command 'thread' applied to NIL` x4
  - `ScriptError:Cannot cast 'none' to entity` x4
  - `ScriptError:IsTouching used with a NULL entity.` x4
  - `ScriptError:command 'exec' applied to NULL listener` x3
  - `CouldntLoad:models/nil` x3
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x2
  - `CouldntLoad:models/fx/fx_truck_explosion_02.tik` x2
  - `CouldntLoad:models/vehicles/ab_turret_main_viewmodel.tik` x2
  - `CouldntLoad:models/vehicles/ab_turret_mini_viewmodel.tik` x2
  - `ScriptError:command 'anim' applied to NULL listener` x2
  - `ScriptError:command 'waitTill' applied to NULL listener` x2

| never fired | targetname | setthread | at |
|---|---|---|---|
| trigger_hurt | - | - | [-6560, -336, 848] |
| trigger_vehicle | - | - | [5976, 336, -224] |
| trigger_hurt | - | - | [-6628, -2148, 736] |
| trigger_use | dasdetonator | - | [-6066, -6707, 457] |
| trigger_multiple | - | - | [-3984, 6328, 284] |
| trigger_multiple | - | - | [-1192, 6320, 192] |
| trigger_multiple | - | - | [40, 6288, 148] |
| trigger_multiple | - | - | [4424, 4312, 0] |
| trigger_multiple | - | - | [4120, 5008, 72] |
| trigger_multiple | - | - | [-3140, 7024, 472] |
| trigger_multiple | - | - | [5976, 240, -288] |
| trigger_multiple | - | - | [6000, -448, -392] |
| trigger_multiple | - | - | [56, 5368, 336] |
| trigger_multiple | - | maps/e3l3.scr::BlowGuyFromTower | [1556, 5760, 560] |
| trigger_multiple | - | maps/e3l3.scr::BlowGuyFromTower | [4500, 6016, 688] |
| trigger_multiple | - | - | [5044, 5728, 464] |
| trigger_multiple | - | - | [5284, 4912, 444] |
| trigger_multiple | - | maps/e3l3/scene1.scr::frontdoorguys | [-4696, -5128, 200] |
| trigger_vehicle | - | - | [6000, -376, -312] |

## e3l4
walker: ok | triggers 210/220 | snd 95 | SNDMISS 0 | labels 77
engine force-activated: 400 triggers; committed fires recorded: 15511 (uncommitted = locked / already-spent / filtered)
**NEW error signatures (23):**
  - `NoEvent:enter` x31
  - `ScriptError:Failed execution of command 'set_respawn' for class 'ProjectileGenerator_Heavy' Targetname` x9
  - `ScriptError:Failed execution of command 'set_respawn_time' for class 'ProjectileGenerator_Heavy' Targe` x9
  - `NoEvent:flickeralpha` x8
  - `NoEvent:spawntreads` x8
  - `ScriptError:invalid waittill trigger for 'AISpawnPoint'` x5
  - `ScriptError:Cannot cast 'listener' to int` x3
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x2
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x1
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x1
  - `NoImage:sun` x1
  - `NoImage:gfx/2d/sunflare` x1
  - `NoImage:textures/menu/exit` x1
  - `NoImage:poopy` x1
  - `NoImage:bh_snow_puff1.spr` x1

| never fired | targetname | setthread | at |
|---|---|---|---|
| trigger_multiple | - | - | [1356, -6588, 588] |
| trigger_multiple | - | - | [6168, 4148, 936] |
| trigger_multiple | - | - | [5896, 4396, 840] |
| trigger_multiple | - | - | [3088, -1344, 832] |
| trigger_multiple | - | - | [3888, -960, 896] |
| trigger_multiple | - | - | [2328, 2352, 1872] |
| trigger_multiple | - | - | [2558, 2674, 1872] |
| trigger_multiple | - | - | [2208, 2688, 2016] |
| trigger_multiple | - | - | [-488, -6960, 1120] |
| trigger_multiple | - | - | [6176, 4684, 1076] |

## m1l1
walker: ok | triggers 41/41 | snd 73 | SNDMISS 2 | labels 56
engine force-activated: 1787 triggers; committed fires recorded: 36468 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** actor_M1L1_102, snd_pickup
**NEW error signatures (2):**
  - `ScriptError:binary '>' applied to incompatible types 'none' and 'int'` x12
  - `CouldntLoad:sound:` x6
**count regressions:** `CouldntLoad:models/gear/ba_bob45holster.skd` 2->40, `ScriptError:player doesn't exist` 1->50, `NoEvent:flickeralpha` 8->160, `NoEvent:enter` 31->620

## m1l2a
walker: ok | triggers 87/87 | snd 102 | SNDMISS 3 | labels 69
engine force-activated: 3732 triggers; committed fires recorded: 7243 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** den_head_sighted_a, den_head_sighted_c, den_head_sighted_h
**NEW error signatures (3):**
  - `ScriptError:anim 'stop' not found, so can't tell if it is looping` x10
  - `ScriptError:unknown animation 'stop' in 'models/human/german_afrika_private.tik'` x10
  - `ScriptError:Can't find 'mom/mom.scr'` x8
**count regressions:** `CouldntLoad:models/gear/ba_bob45holster.skd` 2->32, `ScriptError:player doesn't exist` 3->50, `NoEvent:flickeralpha` 8->120, `NoEvent:enter` 31->465

## m1l2b
walker: ok | triggers 64/64 | snd 95 | SNDMISS 1 | labels 46
engine force-activated: 1186 triggers; committed fires recorded: 22078 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** tank_vehicle_crash
**NEW error signatures (8):**
  - `ScriptError:player doesn't exist` x16
  - `ScriptError:Player entity is NULL for ihuddraw_alpha!` x16
  - `ScriptError:Player entity is NULL for ihuddraw_string!` x8
  - `ScriptError:Field 'flags' applied to NULL listener` x6
  - `ScriptError:self is NULL` x2
  - `ScriptError:command 'modheight' applied to NULL listener` x1
  - `ScriptError:binary '+' applied to incompatible types 'none' and 'int'` x1
  - `ScriptError:binary '<' applied to incompatible types 'none' and 'int'` x1
**count regressions:** `NoEvent:dmusenoammo` 2->28, `CouldntLoad:models/gear/ba_bob45holster.skd` 2->28, `NoEvent:flickeralpha` 8->112, `NoEvent:enter` 31->434, `CouldntLoad:vehicles/tigercannon_dsrt.tik` 2->28

## m1l3a
walker: ok | triggers 22/22 | snd 102 | SNDMISS 0 | labels 34
engine force-activated: 467 triggers; committed fires recorded: 1886 (uncommitted = locked / already-spent / filtered)
**NEW error signatures (2):**
  - `ScriptError:invalid waittill spawn for 'Level'` x7
  - `CouldntLoad:sound:` x6
**count regressions:** `NoEvent:flickeralpha` 8->72, `NoEvent:enter` 31->279

## m1l3b
walker: ok | triggers 18/18 | snd 88 | SNDMISS 3 | labels 33
engine force-activated: 491 triggers; committed fires recorded: 394 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** jeep_snd_doorclose, jeep_snd_on, jeep_snd_start
**NEW error signatures (2):**
  - `ScriptError:ModifyDrive used when not driving!` x7
  - `CouldntLoad:sound:` x1
**count regressions:** `NoEvent:flickeralpha` 8->64, `NoEvent:enter` 31->248

## m1l3c
walker: ok | triggers 37/40 | snd 110 | SNDMISS 3 | labels 39
engine force-activated: 820 triggers; committed fires recorded: 58909 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** opeltruck_snd_doorclose, opeltruck_snd_start, sanford_and_son
**NEW error signatures (2):**
  - `ScriptError:command 'waitTill' applied to NULL listener` x35
  - `ScriptError:command 'stoploopsound' applied to NIL` x1
**count regressions:** `NoEvent:flickeralpha` 8->64, `NoEvent:enter` 31->248

| never fired | targetname | setthread | at |
|---|---|---|---|
| trigger_once | enddialog | grillo_dialog | [-320, -1664, 380] |
| trigger_once | the_end | - | [-272, -1600, 408] |
| trigger_once | ossmobiletrig | - | [-300, -2400, 412] |

## m2l1
walker: ok | triggers 46/46 | snd 89 | SNDMISS 1 | labels 21
engine force-activated: 608 triggers; committed fires recorded: 47872 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** playsound
**NEW error signatures (1):**
  - `CouldntLoad:font` x4
**count regressions:** `CouldntLoad:models/weapons/stieilhandgranate.tik` 4->32, `ScriptError:player doesn't exist` 3->43, `NoEvent:flickeralpha` 8->64, `NoEvent:enter` 31->248

## m2l2a
walker: ok | triggers 41/60 | snd 28 | SNDMISS 0 | labels 71
engine force-activated: 179 triggers; committed fires recorded: 14560 (uncommitted = locked / already-spent / filtered)
**NEW error signatures (3):**
  - `ScriptError:Cannot cast 'array' to listener` x28
  - `ScriptError:invalid waittill spawn for 'Level'` x15
  - `CouldntLoad:font` x4
**count regressions:** `CouldntLoad:models/gear/ba_bob45holster.skd` 2->36, `ScriptError:player doesn't exist` 10->116, `NoEvent:flickeralpha` 8->136, `NoEvent:enter` 31->527

| never fired | targetname | setthread | at |
|---|---|---|---|
| trigger_multipleall | - | - | [-4052, -3892, 16] |
| trigger_multipleall | - | - | [-4052, -3844, 16] |
| trigger_multipleall | - | - | [-4146, -3490, -178] |
| trigger_multipleall | - | - | [-4090, -3566, -178] |
| trigger_multipleall | - | - | [-4054, -2658, -422] |
| trigger_multipleall | - | - | [-3936, -2980, -142] |
| trigger_multipleall | - | - | [-3918, -2620, -422] |
| trigger_multipleall | - | - | [-4394, -1568, -422] |
| trigger_multipleall | - | - | [-4386, -1468, -422] |
| trigger_multipleall | - | - | [-4072, -4404, -448] |
| trigger_multipleall | - | - | [-4072, -4500, -448] |
| trigger_multipleall | - | - | [-3960, -3404, -234] |
| trigger_multipleall | - | - | [-3960, -3340, -234] |
| trigger_multipleall | - | - | [-3698, -2036, -422] |
| trigger_multipleall | - | - | [-3698, -2064, -422] |
| trigger_multipleall | - | - | [-3696, -4408, -446] |
| trigger_multipleall | - | - | [-3696, -4500, -448] |
| trigger_multipleall | - | - | [-3628, -6312, -444] |
| trigger_multipleall | - | - | [-3548, -6312, -444] |

## m2l2b
walker: ok | triggers 62/62 | snd 24 | SNDMISS 0 | labels 21
engine force-activated: 251 triggers; committed fires recorded: 10090 (uncommitted = locked / already-spent / filtered)
**NEW error signatures (2):**
  - `ScriptError:player doesn't exist` x2
  - `ScriptError:invalid waittill spawn for 'Level'` x1
**count regressions:** `NoEvent:enter` 31->93

## m2l2c
walker: ok | triggers 23/23 | snd 35 | SNDMISS 0 | labels 11
engine force-activated: 200 triggers; committed fires recorded: 238 (uncommitted = locked / already-spent / filtered)
**NEW error signatures (4):**
  - `CouldntLoad:sound:` x2
  - `ScriptError:unknown animation 'unarmed_run_back' in 'models/animal/german_shepherd.tik'` x1
  - `ScriptError:unknown animation 'unarmed_run_left' in 'models/animal/german_shepherd.tik'` x1
  - `ScriptError:unknown animation 'unarmed_stand_nervous_a' in 'models/animal/german_shepherd.tik'` x1
**count regressions:** `NoEvent:enter` 31->93

## m2l3
walker: ok | triggers 107/108 | snd 51 | SNDMISS 0 | labels 55
engine force-activated: 327 triggers; committed fires recorded: 2844 (uncommitted = locked / already-spent / filtered)
**NEW error signatures (7):**
  - `ScriptError:command 'exec' applied to NULL listener` x10
  - `ScriptError:command 'waitTill' applied to NULL listener` x8
  - `ScriptError:command 'thread' applied to NULL listener` x6
  - `ScriptError:Field 'origin' applied to NULL listener` x4
  - `ScriptError:command 'notsolid' applied to NULL listener` x2
  - `ScriptError:command 'solid' applied to NULL listener` x2
  - `ScriptError:command 'turnto' applied to NULL listener` x2
**count regressions:** `NoEvent:enter` 31->93

| never fired | targetname | setthread | at |
|---|---|---|---|
| trigger_multiple | sequence3interupttrig | - | [-464, 5842, -30] |

## m3l1a
walker: ok | triggers 172/183 | snd 88 | SNDMISS 1 | labels 140
engine force-activated: 830 triggers; committed fires recorded: 5607 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** snd_pickup
**NEW error signatures (20):**
  - `ScriptError:Cannot cast 'array' to listener` x44
  - `ScriptError:command 'remove' applied to NULL listener` x27
  - `ScriptError:Field 'origin' applied to NULL listener` x20
  - `ScriptError:command 'unbind' applied to NULL listener` x7
  - `ScriptError:self is NULL` x2
  - `CouldntLoad:font` x2
  - `ScriptError:coop_mod/replace.scr::withinDistanceOf - parameter1 was NULL` x2
  - `ScriptError:command 'playsound' applied to NULL listener` x2
  - `ScriptError:command 'lookat' applied to NULL listener` x2
  - `CouldntLoad:sound:` x2
  - `ScriptError:Field 'stop_forward_motion' applied to NULL listener` x1
  - `ScriptError:Field 'stop' applied to NULL listener` x1
  - `ScriptError:command 'anim' applied to NULL listener` x1
  - `ScriptError:command 'model' applied to NULL listener` x1
  - `ScriptError:command 'time' applied to NULL listener` x1
**count regressions:** `NoEvent:enter` 31->93

| never fired | targetname | setthread | at |
|---|---|---|---|
| trigger_multipleall | ai_groundtype | - | [1968, -1384, -260] |
| trigger_multiple | player_sequence_2_center | player_sequence_2_center | [312, -1888, -288] |
| trigger_multipleall | ai_groundtype | - | [-1856, -2144, -360] |
| trigger_multipleall | ai_groundtype | - | [-352, -2432, -360] |
| trigger_multipleall | ai_groundtype | - | [1216, -2080, -360] |
| trigger_multipleall | ai_groundtype | - | [2332, -1792, -360] |
| trigger_multipleall | ai_groundtype | - | [-1648, -1340, -260] |
| trigger_multipleall | ai_groundtype | - | [480, -2652, -432] |
| trigger_once | playeritem_bangalore_give | playeritem_bangalore_give | [-1348, 2324, -272] |
| trigger_multiple | player_sequence_2_right | player_sequence_2_right | [1232, -1952, -288] |
| trigger_multiple | dragging_guys_blow_triggerleft | dragging_guys_blow | [-564, -312, -388] |

## m3l1b
walker: ok | triggers 19/32 | snd 37 | SNDMISS 1 | labels 42
engine force-activated: 141 triggers; committed fires recorded: 1007 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** snd_pickup
**count regressions:** `NoEvent:enter` 31->93

| never fired | targetname | setthread | at |
|---|---|---|---|
| trigger_multipleall | allied_beach_target | - | [32, -4384, -152] |
| trigger_multipleall | allied_beach_target | - | [928, -6720, -152] |
| trigger_multipleall | allied_beach_target | - | [1920, -5536, -152] |
| trigger_use | 88mm_trigger1 | - | [2540, -324, 506] |
| trigger_multipleall | minefield | - | [-1824, -224, 540] |
| trigger_multipleall | minefield | - | [1824, 1184, 540] |
| trigger_multipleall | minefield | - | [4272, 480, 540] |
| trigger_multipleall | minefield | - | [4528, -288, 540] |
| trigger_multipleall | minefield | - | [4032, -1360, 444] |
| trigger_multipleall | minefield | - | [2704, -1680, 388] |
| trigger_use | 88mm_trigger2 | - | [-1088, -112, 500] |
| trigger_multipleall | minefield | - | [2992, 736, 540] |
| trigger_use | door_floor_hatch1_lock | door_metal_lock | [1880, -1696, 100] |

## m3l2
walker: ok | triggers 60/60 | snd 51 | SNDMISS 2 | labels 77
engine force-activated: 146 triggers; committed fires recorded: 458 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** flak88_hit, snd_pickup
**NEW error signatures (1):**
  - `ScriptError:ScriptMaster::CreateScriptThread: label 'playerPlaceAtSpawn' does not exist in 'maps/m3l2.` x4

## m3l3
walker: ok | triggers 90/90 | snd 75 | SNDMISS 6 | labels 204
engine force-activated: 350 triggers; committed fires recorded: 2133 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** dfr_panic_35c_13, drop_bomb, snd_move_start, snd_move_stop, snd_pickup, tank_vehicle_crash
**NEW error signatures (8):**
  - `ScriptError:player doesn't exist` x108
  - `ScriptError:command 'remove' applied to NULL listener` x37
  - `ScriptError:command 'waitTill' applied to NULL listener` x37
  - `CouldntLoad:models/items/explosive` x37
  - `ScriptError:Failed execution of command 'set_respawn' for class 'ScriptModel' Targetname 'scene0_panze` x37
  - `ScriptError:Failed execution of command 'set_respawn_time' for class 'ScriptModel' Targetname 'scene0_` x37
  - `ScriptError:Failed execution of command 'set_respawn' for class 'ScriptModel' Targetname 'scene4_panze` x37
  - `ScriptError:Failed execution of command 'set_respawn_time' for class 'ScriptModel' Targetname 'scene4_` x37
**count regressions:** `NoEvent:flickeralpha` 8->40, `NoEvent:enter` 31->155

## m4l0
walker: ok | triggers 23/23 | snd 35 | SNDMISS 0 | labels 19
engine force-activated: 90 triggers; committed fires recorded: 426 (uncommitted = locked / already-spent / filtered)
**NEW error signatures (2):**
  - `ScriptError:player doesn't exist` x4
  - `NoImage:poopy` x2
**count regressions:** `NoEvent:enter` 11->33

## m4l1
walker: ok | triggers 44/44 | snd 42 | SNDMISS 1 | labels 19
engine force-activated: 83 triggers; committed fires recorded: 5862 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** coop_stuka_dive
**count regressions:** `NoEvent:enter` 31->93

## m4l2
walker: ok | triggers 76/79 | snd 50 | SNDMISS 0 | labels 44
engine force-activated: 454 triggers; committed fires recorded: 6439 (uncommitted = locked / already-spent / filtered)
**NEW error signatures (24):**
  - `NoEvent:enter` x62
  - `NoEvent:flickeralpha` x16
  - `ScriptError:player doesn't exist` x7
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x4
  - `CouldntLoad:vehicles/tigercannon.tik` x4
  - `ScriptError:Field 'FirstPathFinished' applied to NULL listener` x4
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x2
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x2
  - `NoImage:sun` x2
  - `NoImage:gfx/2d/sunflare` x2
  - `NoImage:textures/menu/exit` x2
  - `NoImage:poopy` x2
  - `NoImage:bh_snow_puff1.spr` x2
  - `NoImage:mg` x2
  - `NoImage:opelhubstill` x2

| never fired | targetname | setthread | at |
|---|---|---|---|
| trigger_multiple | trainkill_trigger | - | [-1981, 2561, 81] |
| trigger_once | gatecrash_trigger | gatecrash | [-5840, 4764, 456] |
| trigger_once | fakegetawaytruck_drive_trigger | obj7_complete | [-6016, 1380, 404] |

## m4l3
walker: ok | triggers 73/77 | snd 39 | SNDMISS 1 | labels 46
engine force-activated: 223 triggers; committed fires recorded: 17860 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** snd_pickup
**NEW error signatures (20):**
  - `NoEvent:enter` x31
  - `ScriptError:player doesn't exist` x8
  - `NoEvent:flickeralpha` x8
  - `ScriptError:command 'waitTill' applied to NULL listener` x5
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x2
  - `CouldntLoad:vehicles/kingcannon.tik` x2
  - `CouldntLoad:vehicles/kingsmgun.tik` x2
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x1
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x1
  - `NoImage:sun` x1
  - `NoImage:gfx/2d/sunflare` x1
  - `NoImage:textures/menu/exit` x1
  - `NoImage:poopy` x1
  - `NoImage:bh_snow_puff1.spr` x1
  - `NoImage:opelhubstill` x1

| never fired | targetname | setthread | at |
|---|---|---|---|
| trigger_use | tank1_bomb_trigger | tank1_bomb_plant | [-2840, 2708, 36] |
| trigger_once | objective5_trigger1 | objective5_add | [-3580, 2208, 60] |
| trigger_once | objective5_trigger3 | objective5_add | [-3612, 1248, 60] |
| trigger_use | tank2_bomb_trigger | tank2_bomb_plant | [-176, 2498, 36] |

## m5l1a
walker: ok | triggers 64/64 | snd 46 | SNDMISS 0 | labels 28
engine force-activated: 380 triggers; committed fires recorded: 1807 (uncommitted = locked / already-spent / filtered)
**NEW error signatures (15):**
  - `NoEvent:enter` x62
  - `NoEvent:flickeralpha` x16
  - `ScriptError:player doesn't exist` x7
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x4
  - `CouldntLoad:models/equipment/USGear/helmets/haversack.skd` x4
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x2
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x2
  - `NoImage:sun` x2
  - `NoImage:gfx/2d/sunflare` x2
  - `NoEvent:vis_dirived` x2
  - `NoImage:textures/menu/exit` x2
  - `NoImage:poopy` x2
  - `NoImage:bh_snow_puff1.spr` x2
  - `NoImage:#handview` x2
  - `NoImage:viewsleeves_camo` x2

## m5l1b
walker: ok | triggers 56/56 | snd 72 | SNDMISS 0 | labels 34
engine force-activated: 325 triggers; committed fires recorded: 506 (uncommitted = locked / already-spent / filtered)
**NEW error signatures (18):**
  - `NoEvent:enter` x62
  - `NoEvent:flickeralpha` x16
  - `ScriptError:player doesn't exist` x11
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x4
  - `CouldntLoad:vehicles/kingcannon.tik` x4
  - `CouldntLoad:vehicles/kingsmgun.tik` x4
  - `CouldntLoad:vehicles/panzer_cannon_europe.tik` x4
  - `CouldntLoad:vehicles/panzer_smgun_europe.tik` x4
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x2
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x2
  - `NoImage:sun` x2
  - `NoImage:gfx/2d/sunflare` x2
  - `CouldntLoad:models/equipment/USGear/helmets/haversack.skd` x2
  - `NoImage:textures/menu/exit` x2
  - `NoImage:poopy` x2

## m5l2a
walker: ok | triggers 52/52 | snd 40 | SNDMISS 3 | labels 31
engine force-activated: 979 triggers; committed fires recorded: 912 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** flak_snd_move_start, snd_pickup, tank_snd_move_start
**NEW error signatures (22):**
  - `NoEvent:enter` x62
  - `ScriptError:Failed execution of command 'weaponcommand' for class 'World' Targetname 'world'` x20
  - `NoEvent:flickeralpha` x16
  - `CouldntLoad:models/fx/fx-dummy.tik` x8
  - `ScriptError:Failed execution of command 'iprint' for class 'World' Targetname 'world'` x6
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x4
  - `CouldntLoad:vehicles/panzer_cannon_europe.tik` x4
  - `CouldntLoad:vehicles/panzer_smgun_europe.tik` x4
  - `CouldntLoad:vehicles/kingcannon.tik` x4
  - `CouldntLoad:vehicles/kingsmgun.tik` x4
  - `CouldntLoad:vehicles/tigercannon.tik` x4
  - `ScriptError:Failed execution of command 'face' for class 'World' Targetname 'world'` x4
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x2
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x2
  - `NoImage:sun` x2

## m5l2b
walker: ok | triggers 69/69 | snd 54 | SNDMISS 4 | labels 24
engine force-activated: 1601 triggers; committed fires recorded: 1992 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** coop_stuka_dive, flak_snd_move_start, snd_pickup, tank_snd_move_start
**NEW error signatures (23):**
  - `NoEvent:enter` x62
  - `NoEvent:flickeralpha` x16
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x4
  - `CouldntLoad:vehicles/panzer_cannon_europe.tik` x4
  - `CouldntLoad:vehicles/panzer_smgun_europe.tik` x4
  - `CouldntLoad:vehicles/kingcannon.tik` x4
  - `CouldntLoad:vehicles/kingsmgun.tik` x4
  - `CouldntLoad:vehicles/tigercannon.tik` x4
  - `CouldntLoad:models/emitters/explosion_bombdirt_shockwave.tik` x4
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x2
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x2
  - `NoImage:sun` x2
  - `NoImage:gfx/2d/sunflare` x2
  - `NoImage:textures/menu/exit` x2
  - `NoImage:poopy` x2

## m5l3
walker: ok | triggers 109/109 | snd 105 | SNDMISS 1 | labels 45
engine force-activated: 4812 triggers; committed fires recorded: 5744 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** dfr_m5l3_add01
**NEW error signatures (18):**
  - `NoEvent:enter` x403
  - `NoEvent:flickeralpha` x104
  - `ScriptError:player doesn't exist` x72
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x30
  - `CouldntLoad:vehicles/kingcannon.tik` x26
  - `CouldntLoad:vehicles/kingsmgun.tik` x26
  - `CouldntLoad:vehicles/tigercannon.tik` x26
  - `NoEvent:sunflare` x20
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x15
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x15
  - `NoImage:sun` x15
  - `NoImage:gfx/2d/sunflare` x15
  - `NoImage:textures/menu/exit` x13
  - `NoImage:poopy` x13
  - `NoImage:bh_snow_puff1.spr` x13

## m6l1a
walker: ok | triggers 5/5 | snd 32 | SNDMISS 1 | labels 10
engine force-activated: 28 triggers; committed fires recorded: 225 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** snd_pickup
**NEW error signatures (13):**
  - `NoEvent:enter` x31
  - `NoEvent:flickeralpha` x8
  - `ScriptError:player doesn't exist` x3
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x2
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x1
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x1
  - `NoImage:sun` x1
  - `NoImage:gfx/2d/sunflare` x1
  - `NoImage:textures/menu/exit` x1
  - `NoImage:poopy` x1
  - `NoImage:bh_snow_puff1.spr` x1
  - `NoImage:#handview` x1
  - `NoImage:viewsleeves_camo` x1

## m6l1b
walker: ok | triggers 10/10 | snd 21 | SNDMISS 2 | labels 9
engine force-activated: 24 triggers; committed fires recorded: 41 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** airplane, snd_pickup
**NEW error signatures (13):**
  - `NoEvent:enter` x31
  - `NoEvent:flickeralpha` x8
  - `ScriptError:player doesn't exist` x3
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x2
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x1
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x1
  - `NoImage:sun` x1
  - `NoImage:gfx/2d/sunflare` x1
  - `NoImage:textures/menu/exit` x1
  - `NoImage:poopy` x1
  - `NoImage:bh_snow_puff1.spr` x1
  - `NoImage:#handview` x1
  - `NoImage:viewsleeves_camo` x1

## m6l1c
walker: ok | triggers 59/99 | snd 30 | SNDMISS 1 | labels 40
engine force-activated: 330 triggers; committed fires recorded: 2780 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** snd_pickup
**NEW error signatures (14):**
  - `NoEvent:enter` x31
  - `ScriptError:player doesn't exist` x9
  - `NoEvent:flickeralpha` x8
  - `CouldntLoad:font` x4
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x2
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x1
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x1
  - `NoImage:sun` x1
  - `NoImage:gfx/2d/sunflare` x1
  - `NoImage:textures/menu/exit` x1
  - `NoImage:poopy` x1
  - `NoImage:bh_snow_puff1.spr` x1
  - `NoImage:#handview` x1
  - `NoImage:viewsleeves_camo` x1

| never fired | targetname | setthread | at |
|---|---|---|---|
| trigger_multipleall | - | - | [4904, 4428, -656] |
| trigger_multipleall | - | - | [4904, 4520, -656] |
| trigger_multipleall | - | - | [4904, 4920, -656] |
| trigger_multipleall | - | - | [4904, 4988, -656] |
| trigger_multipleall | - | - | [4452, 5464, -656] |
| trigger_multipleall | - | - | [4452, 5512, -656] |
| trigger_multipleall | - | - | [2940, 5240, -552] |
| trigger_multipleall | - | - | [2876, 5240, -552] |
| trigger_multipleall | - | - | [2166, 4800, -552] |
| trigger_multipleall | - | - | [2158, 4704, -552] |
| trigger_multipleall | - | - | [1924, 3488, -552] |
| trigger_multipleall | - | - | [2028, 3488, -552] |
| trigger_multipleall | - | - | [1652, 2716, -464] |
| trigger_multipleall | - | - | [2312, 2696, -456] |
| trigger_multipleall | - | - | [1572, 2692, -460] |
| trigger_multipleall | - | - | [1356, 1852, -456] |
| trigger_multipleall | - | - | [1356, 1780, -456] |
| trigger_multipleall | - | - | [1132, 1624, -456] |
| trigger_multipleall | - | - | [1060, 1624, -456] |
| trigger_multipleall | - | - | [300, 1252, -376] |
| trigger_multipleall | - | - | [300, 1250, -112] |
| trigger_multipleall | - | - | [204, 1456, 24] |
| trigger_multipleall | - | - | [128, 1316, 24] |
| trigger_multipleall | - | - | [128, 1208, 25] |
| trigger_multipleall | - | - | [128, 1132, 24] |
| trigger_multipleall | - | - | [384, 892, 24] |
| trigger_multipleall | - | - | [784, 332, 104] |
| trigger_multipleall | - | - | [1160, 396, 104] |
| trigger_multipleall | - | - | [1972, 2500, 104] |
| trigger_multipleall | - | - | [1972, 2620, 104] |
| trigger_multipleall | - | - | [3824, 2628, 104] |
| trigger_multipleall | - | - | [3820, 2548, 104] |
| trigger_multipleall | - | - | [3712, 1124, 104] |
| trigger_multipleall | - | - | [4820, 1216, 112] |
| trigger_multipleall | - | - | [4772, 1216, 112] |
| trigger_multipleall | - | - | [1928, 3694, -552] |
| trigger_multipleall | - | - | [2120, 3820, -552] |
| trigger_multipleall | - | - | [1076, 332, 104] |
| trigger_multipleall | - | - | [876, 332, 104] |
| trigger_multipleall | - | - | [3868, 1000, 112] |

## m6l2a
walker: ok | triggers 74/75 | snd 69 | SNDMISS 1 | labels 32
engine force-activated: 361 triggers; committed fires recorded: 1485 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** snd_pickup
**NEW error signatures (16):**
  - `NoEvent:enter` x31
  - `NoEvent:flickeralpha` x8
  - `ScriptError:player doesn't exist` x7
  - `ScriptError:command 'cansee' applied to NULL listener` x4
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x2
  - `CouldntLoad:sound:` x2
  - `CouldntLoad:font` x2
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x1
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x1
  - `NoImage:sun` x1
  - `NoImage:gfx/2d/sunflare` x1
  - `NoImage:textures/menu/exit` x1
  - `NoImage:poopy` x1
  - `NoImage:bh_snow_puff1.spr` x1
  - `NoImage:#handview` x1

| never fired | targetname | setthread | at |
|---|---|---|---|
| trigger_changelevel | levelchange | - | [2208, -3040, 324] |

## m6l2b
walker: ok | triggers 32/32 | snd 75 | SNDMISS 0 | labels 16
engine force-activated: 146 triggers; committed fires recorded: 1914 (uncommitted = locked / already-spent / filtered)
**NEW error signatures (13):**
  - `NoEvent:enter` x31
  - `NoEvent:flickeralpha` x8
  - `ScriptError:player doesn't exist` x3
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x2
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x1
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x1
  - `NoImage:sun` x1
  - `NoImage:gfx/2d/sunflare` x1
  - `NoImage:textures/menu/exit` x1
  - `NoImage:poopy` x1
  - `NoImage:bh_snow_puff1.spr` x1
  - `NoImage:#handview` x1
  - `NoImage:viewsleeves_camo` x1

## m6l3a
walker: ok | triggers 57/57 | snd 53 | SNDMISS 2 | labels 68
engine force-activated: 250 triggers; committed fires recorded: 3106 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** door_vault_open, snd_pickup
**NEW error signatures (17):**
  - `NoEvent:enter` x31
  - `NoEvent:flickeralpha` x8
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x2
  - `ScriptError:invalid waittill prespawn for 'Level'` x2
  - `ScriptError:player doesn't exist` x2
  - `ScriptError:binary '+' applied to incompatible types 'const string' and 'none'` x2
  - `ScriptError:binary '+' applied to incompatible types 'none' and 'const string'` x2
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x1
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x1
  - `NoImage:sun` x1
  - `NoImage:gfx/2d/sunflare` x1
  - `NoImage:textures/menu/exit` x1
  - `NoImage:poopy` x1
  - `NoImage:bh_snow_puff1.spr` x1
  - `NoImage:#handview` x1

## m6l3b
walker: ok | triggers 26/26 | snd 33 | SNDMISS 0 | labels 8
engine force-activated: 81 triggers; committed fires recorded: 438 (uncommitted = locked / already-spent / filtered)
**NEW error signatures (14):**
  - `NoEvent:enter` x31
  - `NoEvent:flickeralpha` x8
  - `ScriptError:player doesn't exist` x3
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x2
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x1
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x1
  - `NoImage:sun` x1
  - `NoImage:gfx/2d/sunflare` x1
  - `ScriptError:invalid waittill spawn for 'Level'` x1
  - `NoImage:textures/menu/exit` x1
  - `NoImage:poopy` x1
  - `NoImage:bh_snow_puff1.spr` x1
  - `NoImage:#handview` x1
  - `NoImage:viewsleeves_camo` x1

## m6l3c
walker: ok | triggers 90/92 | snd 46 | SNDMISS 0 | labels 51
engine force-activated: 243 triggers; committed fires recorded: 699 (uncommitted = locked / already-spent / filtered)
**NEW error signatures (20):**
  - `NoEvent:enter` x31
  - `NoEvent:flickeralpha` x8
  - `ScriptError:player doesn't exist` x4
  - `ScriptError:command 'exec' applied to NULL listener` x3
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x2
  - `CouldntLoad:font` x2
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x1
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x1
  - `NoImage:sun` x1
  - `NoImage:gfx/2d/sunflare` x1
  - `ScriptError:command 'waitTill' applied to NULL listener` x1
  - `NoImage:textures/menu/exit` x1
  - `NoImage:poopy` x1
  - `NoImage:bh_snow_puff1.spr` x1
  - `NoImage:#handview` x1

| never fired | targetname | setthread | at |
|---|---|---|---|
| trigger_multiple | blast_seq1_firedeath1 | firedeath | [-1504, 1326, -956] |
| trigger_multiple | blast_seq12_hurt1 | hurt_20 | [-2040, -2412, -504] |

## m6l3d
walker: ok | triggers 27/27 | snd 61 | SNDMISS 0 | labels 27
engine force-activated: 87 triggers; committed fires recorded: 277 (uncommitted = locked / already-spent / filtered)
**NEW error signatures (13):**
  - `NoEvent:enter` x31
  - `NoEvent:flickeralpha` x8
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x2
  - `ScriptError:player doesn't exist` x2
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x1
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x1
  - `NoImage:sun` x1
  - `NoImage:gfx/2d/sunflare` x1
  - `NoImage:textures/menu/exit` x1
  - `NoImage:poopy` x1
  - `NoImage:bh_snow_puff1.spr` x1
  - `NoImage:#handview` x1
  - `NoImage:viewsleeves_camo` x1

## m6l3e
walker: ok | triggers 11/15 | snd 43 | SNDMISS 1 | labels 32
engine force-activated: 69 triggers; committed fires recorded: 38 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** door_railcar_open
**NEW error signatures (14):**
  - `NoEvent:enter` x31
  - `NoEvent:flickeralpha` x8
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x2
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x1
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x1
  - `NoImage:sun` x1
  - `NoImage:gfx/2d/sunflare` x1
  - `ScriptError:player doesn't exist` x1
  - `NoImage:textures/menu/exit` x1
  - `NoImage:poopy` x1
  - `NoImage:bh_snow_puff1.spr` x1
  - `NoImage:#handview` x1
  - `NoImage:viewsleeves_camo` x1
  - `ScriptError:command 'anim' applied to NULL listener` x1

| never fired | targetname | setthread | at |
|---|---|---|---|
| trigger_multiple | blast_seq4_hurt3 | hurt_20 | [-4832, -1538, -512] |
| trigger_multiple | blast_seq4_hurt4 | hurt_20 | [-4744, -1692, -512] |
| trigger_multiple | blast_seq4_hurt5 | hurt_20 | [-4920, -1692, -512] |
| trigger_multiple | blast_seq4_firedeath1 | firedeath | [-4712, -1520, -504] |

## t1l1
walker: ok | triggers 45/45 | snd 50 | SNDMISS 4 | labels 20
engine force-activated: 126 triggers; committed fires recorded: 312 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** barn_door_locked, door_wood_locked1, plane, whistle_blow
**NEW error signatures (18):**
  - `CouldntLoad:models/fx/fx_miniaa_model.tik` x88
  - `NoEvent:enter` x31
  - `NoEvent:flickeralpha` x8
  - `ScriptError:player doesn't exist` x3
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x2
  - `CouldntLoad:vehicles/tigercannon.tik` x2
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x1
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x1
  - `NoImage:sun` x1
  - `NoImage:gfx/2d/sunflare` x1
  - `CouldntLoad:sound:` x1
  - `NoImage:textures/(0` x1
  - `NoImage:textures/menu/exit` x1
  - `NoImage:poopy` x1
  - `NoImage:bh_snow_puff1.spr` x1

## t1l2
walker: ok | triggers 59/66 | snd 82 | SNDMISS 6 | labels 50
engine force-activated: 208 triggers; committed fires recorded: 33244 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** barn_door_locked, coop_stuka_dive, door_wood_locked1, gate_wood_open_move, picket_fence_open, picket_fence_open_stop
**NEW error signatures (18):**
  - `NoEvent:enter` x186
  - `NoEvent:flickeralpha` x48
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x12
  - `ScriptError:Failed execution of command 'explosionoffset' for class 'ThrobbingBox_ExplodePlayerFlak88'` x12
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x11
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x11
  - `NoImage:sun` x11
  - `NoImage:gfx/2d/sunflare` x11
  - `ScriptError:player doesn't exist` x9
  - `ScriptError:Failed execution of command 'set_respawn' for class 'ProjectileGenerator_Projectile' Targe` x6
  - `ScriptError:Failed execution of command 'set_respawn_time' for class 'ProjectileGenerator_Projectile' ` x6
  - `NoImage:textures/menu/exit` x6
  - `NoImage:poopy` x6
  - `NoImage:bh_snow_puff1.spr` x6
  - `NoImage:#handview` x6

| never fired | targetname | setthread | at |
|---|---|---|---|
| trigger_once | - | spawnset02 | [1056, -1080, 184] |
| trigger_once | - | spawnset05 | [-1024, -1440, 184] |
| trigger_once | - | spawnset08 | [-3872, -1056, 184] |
| trigger_once | - | spawnset09 | [-3888, -1504, 184] |
| trigger_once | - | spawnset16 | [-3392, 4624, 64] |
| trigger_once | - | spawnset17 | [-3760, 3488, 368] |
| trigger_once | - | spawnset25 | [1004, 4268, 64] |

## t1l3
walker: ok | triggers 123/123 | snd 47 | SNDMISS 3 | labels 53
engine force-activated: 571 triggers; committed fires recorded: 3539 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** barn_door_locked, door_wood_locked1, picket_fence_locked
**NEW error signatures (17):**
  - `NoEvent:enter` x62
  - `NoEvent:flickeralpha` x16
  - `ScriptError:player doesn't exist` x9
  - `ScriptError:Cannot cast 'array' to listener` x6
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x4
  - `CouldntLoad:vehicles/tigercannon.tik` x4
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x2
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x2
  - `NoImage:sun` x2
  - `NoImage:gfx/2d/sunflare` x2
  - `NoImage:textures/menu/exit` x2
  - `NoImage:poopy` x2
  - `NoImage:bh_snow_puff1.spr` x2
  - `NoImage:#handview` x2
  - `NoImage:viewsleeves_camo` x2

## t2l1
walker: INVALID (walker heartbeat missing - do not trust this map's coverage) | triggers 49/49 | snd 47 | SNDMISS 4 | labels 58
engine force-activated: 175 triggers; committed fires recorded: 11628 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** barn_door_open_move, barn_door_open_stop, plane, toilet_flush
**NEW error signatures (25):**
  - `ScriptError:Cannot cast 'array' to listener` x189
  - `NoEvent:enter` x155
  - `ScriptError:Cannot cast 'int' to listener` x149
  - `ScriptError:Cannot cast 'none' to vector` x149
  - `NoEvent:flickeralpha` x40
  - `ScriptError:Failed execution of command 'set_respawn' for class 'ProjectileGenerator_Projectile' Targe` x30
  - `ScriptError:Failed execution of command 'set_respawn_time' for class 'ProjectileGenerator_Projectile' ` x30
  - `ScriptError:Failed execution of command 'set_respawn' for class 'ProjectileGenerator_Heavy' Targetname` x20
  - `ScriptError:Failed execution of command 'set_respawn_time' for class 'ProjectileGenerator_Heavy' Targe` x20
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x10
  - `NoEvent:mg42` x10
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x5
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x5
  - `NoImage:sun` x5
  - `NoImage:gfx/2d/sunflare` x5

## t2l2
walker: ok | triggers 83/84 | snd 141 | SNDMISS 3 | labels 74
engine force-activated: 389 triggers; committed fires recorded: 900 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** damage_tank, drop_bomb, plane
**NEW error signatures (43):**
  - `NoEvent:enter` x62
  - `NoEvent:flickeralpha` x16
  - `ScriptError:command 'thread' applied to NULL listener` x14
  - `ScriptError:command 'delete' applied to NULL listener` x12
  - `ScriptError:Field 'start_health' applied to NULL listener` x9
  - `NoEvent:delay` x8
  - `ScriptError:command 'drive' applied to NULL listener` x7
  - `ScriptError:command 'waitTill' applied to NULL listener` x7
  - `ScriptError:command 'stop' applied to NULL listener` x7
  - `ScriptError:command 'delete' applied to NIL` x5
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x4
  - `ScriptError:invalid waittill drive for 'TriggerOnce'` x4
  - `ScriptError:Field 'health' applied to NULL listener` x4
  - `ScriptError:Field 'accuracy' applied to NULL listener` x4
  - `ScriptError:Field 'get_out' applied to NULL listener` x4

| never fired | targetname | setthread | at |
|---|---|---|---|
| trigger_nodamage | - | - | [6704, -6344, 152] |

## t2l3
walker: INVALID (walker heartbeat missing - do not trust this map's coverage) | triggers 84/84 | snd 20 | SNDMISS 0 | labels 19
engine force-activated: 111 triggers; committed fires recorded: 184 (uncommitted = locked / already-spent / filtered)
**NEW error signatures (30):**
  - `ScriptError:command 'anim' applied to NIL` x4347
  - `ScriptError:command 'waitTill' applied to NIL` x4347
  - `NoEvent:enter` x281
  - `NoEvent:rotatedbbox` x261
  - `ScriptError:invalid waittill spawn for 'Level'` x180
  - `ScriptError:Failed execution of command 'set_respawn' for class 'ProjectileGenerator_Projectile' Targe` x72
  - `ScriptError:Failed execution of command 'set_respawn_time' for class 'ProjectileGenerator_Projectile' ` x72
  - `NoEvent:flickeralpha` x72
  - `ScriptError:player doesn't exist` x20
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x18
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x11
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x11
  - `NoImage:sun` x11
  - `NoImage:gfx/2d/sunflare` x11
  - `NoEvent:mg42` x9

## t2l4
walker: ok | triggers 135/144 | snd 116 | SNDMISS 4 | labels 63
engine force-activated: 485 triggers; committed fires recorded: 17480 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** arty_leadin05, coop_stuka_dive, door_wood_locked, door_wood_locked1
**NEW error signatures (40):**
  - `NoEvent:enter` x62
  - `ScriptError:Failed execution of command 'set_respawn' for class 'ProjectileGenerator_Projectile' Targe` x22
  - `ScriptError:Failed execution of command 'set_respawn_time' for class 'ProjectileGenerator_Projectile' ` x22
  - `NoEvent:flickeralpha` x16
  - `NoEvent:rotatedbbox` x12
  - `ScriptError:command 'thread' applied to NULL listener` x12
  - `ScriptError:command 'delete' applied to NULL listener` x7
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x4
  - `ScriptError:command 'physics_off' applied to NULL listener` x4
  - `CouldntLoad:vehicles/tigercannon.tik` x4
  - `ScriptError:command 'takedamage' applied to NULL listener` x4
  - `ScriptError:Field 'health' applied to NULL listener` x4
  - `ScriptError:command 'setAimTarget' applied to NIL` x4
  - `ScriptError:command 'waitTill' applied to NIL` x4
  - `ScriptError:command 'anim' applied to NIL` x4

| never fired | targetname | setthread | at |
|---|---|---|---|
| trigger_multiple | - | death_church_to_hotel | [1107, 3204, 619] |
| trigger_multiple | - | death_church_to_hotel | [1149, 1622, 619] |
| trigger_multiple | - | death_church_to_hotel | [-286, 1280, 619] |
| trigger_once | - | spawn_4_2 | [-5088, 4432, 708] |
| trigger_once | - | spawn_5_2 | [-5070, 4504, 700] |
| trigger_once | - | spawn_7 | [-5105, 5284, 558] |
| trigger_multiple | - | death_church_to_hotel_toggle | [-563, 2362, 619] |
| trigger_multiple | - | death_hotel_to_end | [-3452, 2700, 619] |
| trigger_multiple | - | death_church_to_hotel | [-5363, 2886, 619] |

## t3l1
walker: ok | triggers 80/80 | snd 91 | SNDMISS 10 | labels 64
engine force-activated: 501 triggers; committed fires recorded: 24966 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** door_wood_locked1, opeltruck_snd_dooropen, opeltruck_snd_off, opeltruck_snd_revdown, opeltruck_snd_stop, pickup_papers, plane1, tank_snd_doorclose, tank_snd_dooropen, tank_vehicle_crash
**NEW error signatures (28):**
  - `ScriptError:Cannot cast 'none' to vector` x5748
  - `ScriptError:Cannot cast 'array' to listener` x3360
  - `ScriptError:binary '-' applied to incompatible types 'vector' and 'none'` x1680
  - `ScriptError:binary '>' applied to incompatible types 'none' and 'int'` x1680
  - `ScriptError:binary '>=' applied to incompatible types 'none' and 'float'` x687
  - `ScriptError:binary '<=' applied to incompatible types 'none' and 'float'` x507
  - `NoEvent:enter` x62
  - `NoEvent:flickeralpha` x16
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x4
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x2
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x2
  - `NoImage:sun` x2
  - `NoImage:gfx/2d/sunflare` x2
  - `ScriptError:Failed execution of command 'set_respawn' for class 'ProjectileGenerator_Projectile' Targe` x2
  - `ScriptError:Failed execution of command 'set_respawn_time' for class 'ProjectileGenerator_Projectile' ` x2

## t3l2
walker: ok | triggers 72/104 | snd 48 | SNDMISS 3 | labels 52
engine force-activated: 412 triggers; committed fires recorded: 873 (uncommitted = locked / already-spent / filtered)
**dead aliases (runtime):** damage_tank, tank_hurt2, tank_vehicle_crash
**NEW error signatures (19):**
  - `NoEvent:enter` x423
  - `NoEvent:flickeralpha` x108
  - `CouldntLoad:models/fx/fx-dummy.tik` x56
  - `CouldntLoad:models/gear/ba_bob45holster.skd` x28
  - `CouldntLoad:vehicles/tigercannon.tik` x28
  - `ShaderFileIgnored:scripts/new_opelgray.shader.` x14
  - `ShaderFileIgnored:scripts/soviet_weapons.shader.` x14
  - `NoImage:sun` x14
  - `NoImage:gfx/2d/sunflare` x14
  - `NoImage:textures/menu/exit` x14
  - `NoImage:poopy` x14
  - `NoImage:bh_snow_puff1.spr` x14
  - `NoImage:#handview` x14
  - `NoImage:viewsleeves_camo` x14
  - `ScriptError:command 'thread' applied to NULL listener` x6

| never fired | targetname | setthread | at |
|---|---|---|---|
| trigger_vehicle | - | - | [1200, 2352, 336] |
| trigger_vehicle | - | pole_fall | [-4216, -4372, 40] |
| trigger_vehicle | - | pole_fall | [-4216, -3956, 40] |
| trigger_vehicle | - | pole_fall | [2032, -4004, 40] |
| trigger_vehicle | - | pole_fall | [1888, -4820, 40] |
| trigger_vehicle | - | pole_fall | [2184, -4828, 40] |
| trigger_vehicle | - | pole_fall | [2560, -4812, 40] |
| trigger_vehicle | - | pole_fall | [5426, 415, -24] |
| trigger_vehicle | - | pole_fall | [5400, 980, -64] |
| trigger_vehicle | - | pole_fall | [5246, 1574, -88] |
| trigger_vehicle | - | pole_fall | [4856, 2068, -120] |
| trigger_vehicle | - | pole_fall | [2848, 2276, -152] |
| trigger_vehicle | - | pole_fall | [2808, 2732, -128] |
| trigger_vehicle | - | pole_fall | [2788, 3380, -128] |
| trigger_vehicle | - | pole_fall | [3844, 3060, -136] |
| trigger_vehicle | - | tree_fall | [2832, 3340, -108] |
| trigger_vehicle | - | tree_fall | [5036, 2160, -128] |
| trigger_vehicle | - | tree_fall | [4064, 1140, -112] |
| trigger_vehicle | - | tree_fall | [3552, 1396, -128] |
| trigger_vehicle | - | tree_fall | [2496, -5660, 64] |
| trigger_vehicle | - | tree_fall | [2264, -5468, 64] |
| trigger_vehicle | - | tree_fall | [2144, -5292, 64] |
| trigger_vehicle | - | tree_fall | [1624, -4908, 64] |
| trigger_vehicle | - | tree_fall | [1320, -4940, 72] |
| trigger_vehicle | - | tree_fall | [1120, -4908, 80] |
| trigger_vehicle | - | bench_smash | [2076, -4816, 40] |
| trigger_vehicle | - | bench_smash | [2376, -4812, 40] |
| trigger_vehicle | - | bench_smash | [5386, -5634, 40] |
| trigger_vehicle | - | bench_smash | [4212, 1062, -110] |
| trigger_once | - | s10 | [-5077, -2345, 220] |
| trigger_vehicle | - | gags/T3L2_KingTiger.scr::PushBridgeTank | [5185, 2820, -48] |
| trigger_once | - | health_pickup_4 | [6047, 5864, -104] |

