# Lobby Idle Animation Catalog

Research pass (2026-07-08) over the whole War Chest trilogy game data for `.skc`
animations usable as **passive downtime / idle poses** on the player (bip01) skeleton,
for the pre-mission camp **lobby** where up to 4 soldiers wait to deploy.

Scanned: `main/` (AA, Pak0-7), `mainta/` (Spearhead), `maintt/` (Breakthrough, incl.
all HD/mod paks) + `%APPDATA%\openmohaa`. 7,855 unique `.skc` total; 3,788 under
`models/human/animation/` (the player-compatible skeleton). This report keeps only the
passive/idle-appropriate ones.

---

## How these plug in (integration facts — verified this session)

- **Alias file:** `hzm-mohaa-coop-mod/models/player/base/anims_shared.txt`.
- **A rotation pool already exists** and is what this catalog expands:
  ```
  coop_lobbyidle_stand1   idle/standidle01.skc
  coop_lobbyidle_chatter  idle/chatter01.skc
  coop_lobbyidle_smoke    idle/smoking03.skc
  ```
  driven by `coop_mod/lobby.scr::lobbyIdleRotate` via the engine `coop_lobbyrepose` command.
- **Paths in the alias are RELATIVE to `models/human/animation/`** (the file's `$path` line).
  Use `idle/standidle01.skc`, NOT the full `models/human/animation/...` — prefixing the
  full path doubles it and throws `Can't find player animation` (**bug-381**).
- **No `weight` flag** on these aliases. The vanilla `weight` flag pools numbered anims
  under a digit-stripped base name for random pick, which makes the individual numbered
  names non-addressable (**bug-260**). The lobby rotation needs deterministic per-name
  aliases, so every candidate below is aliased weight-free (exactly like the emote/cover set).
- **Skeleton compatibility is PROVEN, not assumed.** `misc/00A104_stretches.skc` (a
  *Spearhead* `mainta/pak1.pk3` anim) already ships as `coop_emote_stretch`, and the AA
  `idle/` + `scripted/t2l3/` donors already drive lobby/DBNO poses. AA human anims, SH/BT
  `misc/00*` anims, and `scripted/*` actor anims all play on the player model.
- **Lobby holsters the weapon** (per `coop_lobby_master_plan.md`: holster + `forcetorsostate STAND` +
  `EMOTE_ATEASE`). So **empty-hand / at-ease poses fit best.** Rifle-in-hands idles
  (`rifle_idle_*`, `weapon_rifle/*`) pose the hands as if gripping a rifle that is holstered —
  a visual mismatch — so they're ranked lower / marked secondary.
- **MAX_TIKI budget:** the player `.tik` already carries a large alias table. Every alias
  added here costs one anim slot, so this catalog is **ranked** — add the shortlist first,
  stop when the camp feels alive. Do not bulk-add the full catalog.
- **Loop vs one-shot:** files named `(loop)` are authored loops. `(weight_shift)`/`(twitch)`
  are short "breaker" variants meant to punctuate a loop. One-shots (salute, stretches,
  cardidle, canteen) play once and settle — fine for a timed rotation that re-triggers, but
  they should not be the *resting* pose. Marked per row.

---

## 1. RANKED SHORTLIST (top ~18 — add these first)

Ranked for: reads clearly as "soldier waiting in camp", needs no prop, empty-hand friendly,
loops or settles cleanly, skeleton-proven. Path = value to drop into `anims_shared.txt`.

| # | Relative path (alias value) | Theater | Category | Loop? | Why it fits |
|---|---|---|---|---|---|
| 1 | `idle/generic_idle_a01(loop).skc` | AA | At-ease stand | **Loop** | The cleanest neutral standing idle — subtle breathing/weight, empty hands. Ideal default resting pose. |
| 2 | `idle/generic_idle_a02(weight_shift).skc` | AA | At-ease stand | One-shot breaker | Weight shift from foot to foot — perfect punctuation between loops of #1. |
| 3 | `scripted/lean/relax01(loop).skc` | AA | Relaxed / at ease | **Loop** | Loose, relaxed standing posture — reads as off-duty. No prop needed. |
| 4 | `idle/standidle02.skc` | AA | At-ease stand | Loop-ish | Relaxed stander; adds variety next to the already-used `standidle01`. |
| 5 | `idle/standidle03.skc` | AA | At-ease stand | Loop-ish | Another distinct relaxed stance for the pool. |
| 6 | `idle/chatter02.skc` | AA | Talking / gesturing | One-shot | Conversing hand gestures — pairs soldiers who look like they're talking (extends `chatter01`). |
| 7 | `idle/chatter03.skc` | AA | Talking / gesturing | One-shot | More talk gesticulation variety. |
| 8 | `idle/smoking01.skc` | AA | Smoking | One-shot (light-up) | Start of the smoke sequence (light up → inhale → `smoking03` loop). Great camp flavor. |
| 9 | `misc/00g103_axis_lookaround.skc` | SH/BT | Looking around | One-shot | Head/torso scan of surroundings — "waiting, glancing about." Skeleton-proven family. |
| 10 | `misc/00g105_axis_lean.skc` | SH/BT | Leaning | One-shot/hold | Casual lean posture, no prop required (self-contained lean). |
| 11 | `misc/00g102_axis_primping.skc` | SH/BT | Adjusting gear | One-shot | Straightening/adjusting uniform — fidgety downtime. |
| 12 | `misc/00g108_axis_milling_1.skc` | SH/BT | Milling about | One-shot | Restless shifting/milling — good crowd-of-soldiers texture. |
| 13 | `misc/00a102_cleanshoes.skc` | SH/BT | Grooming | One-shot | Cleaning boots — classic bored-in-camp bit. Allied-authored. |
| 14 | `scripted/pickup_obj/pass_canteen_drink.skc` | AA | Drinking | One-shot | Takes a drink from canteen. Reads instantly as downtime; solo-usable. |
| 15 | `idle/unarmed_idle_moretough01(loop).skc` | AA | Arms idle (empty hand) | **Loop** | Confident empty-handed stand (arms low/crossed feel). Matches holstered lobby. |
| 16 | `misc/00g104_axis_shoeshine.skc` | SH/BT | Grooming | One-shot | Shoe-shine downtime motion — more grooming variety. |
| 17 | `misc/neutralidle01.skc` | AA | Neutral stand | Loop-ish | Plain neutral idle; safe filler, empty hands. |
| 18 | `misc/00g109_axis_milling_2.skc` | SH/BT | Milling about | One-shot | Second milling variant so paired soldiers don't sync-match. |

**Already in the pool (don't re-add):** `idle/standidle01.skc`, `idle/chatter01.skc`,
`idle/smoking03.skc`, and (as an emote) `idle/atease.skc`, `misc/00A104_stretches.skc`.

**Honorable mentions / flavor (add if you want personality, one costs a slot each):**
`misc/00egg1_allied_sitar.skc` (soldier plays a sitar — hilarious camp easter egg),
`idle/smoking02.skc` + `idle/smoking05.skc` (fuller smoke cycle around the `smoking03` loop),
`scripted/lean/relax02(twitch).skc` (breaker for #3).

---

## 2. FULL CATEGORIZED CATALOG

All paths relative to `models/human/animation/`. `[AA]` = main, `[SH]` = mainta,
`[BT]` = maintt, `[SH/BT]` = present in both SH and BT paks.

### 2a. At-ease / relaxed standing — no prop (BEST fit, empty hand)
| Path | Th | Loop? | Note |
|---|---|---|---|
| `idle/generic_idle_a01(loop).skc` | AA | Loop | Cleanest neutral stand. |
| `idle/generic_idle_a02(weight_shift).skc` | AA | Breaker | Foot-to-foot shift. |
| `idle/generic_idle_b.skc` | AA | Loop-ish | Alt generic idle. |
| `idle/standidle01.skc` *(in pool)* | AA | Loop-ish | — |
| `idle/standidle02.skc` … `standidle05.skc` | AA | Loop-ish | 4 more relaxed stands. |
| `idle/unarmed_idle_lesstough.skc` (+`_intro`/`_outtro`) | AA | Loop | Relaxed empty-hand idle w/ enter/exit. |
| `idle/unarmed_idle_moretough01(loop).skc` (+`02(twitch)`,`_intro`,`_outtro`) | AA | Loop | Confident empty-hand idle. |
| `scripted/lean/relax01(loop).skc` (+`relax02(twitch)`) | AA | Loop | Loose off-duty posture. |
| `misc/neutralidle01.skc`, `misc/neutralidle02.skc` | AA | Loop-ish | Plain neutral fillers. |
| `misc/smileidle.skc`, `misc/smileidle01.skc` | AA | One-shot | Content/relaxed expression idle. |
| `misc/00a100_idle.skc`, `misc/00g100_axis_idle.skc` | SH/BT | Loop-ish | SH/BT ambient idle. |

### 2b. Smoking (sequence: light-up → inhale → loop → stub)
| Path | Th | Note |
|---|---|---|
| `idle/smoking01.skc` | AA | Light up. |
| `idle/smoking02.skc` | AA | First inhale. |
| `idle/smoking03.skc` *(in pool)* | AA | Steady puff loop. |
| `idle/smoking04.skc` | AA | Puff variant. |
| `idle/smoking05.skc` | AA | Butt-out / stub. |
| `scripted/smoking/lightup.skc`, `inhale.skc`, `firstinhale.skc`, `buttout.skc`, `throwaway.skc` (+`*morph`) | AA | Finer-grain smoke set (the `idle/smoking0x` ones are the packaged loopable version — prefer those). |

### 2c. Leaning (mostly self-contained; wall variants want a wall)
| Path | Th | Note |
|---|---|---|
| `misc/00g105_axis_lean.skc` | SH/BT | Casual lean, self-contained. |
| `scripted/lean/lean_standwall_legs.skc` | AA | Lean back on a wall — **wants a wall behind** the spawn. |
| `scripted/lean/getup_standwalltostand.skc` | AA | Exit transition off the wall lean. |

### 2d. Talking / conversing / gesturing
| Path | Th | Note |
|---|---|---|
| `idle/chatter01.skc` *(in pool)* … `chatter04.skc` | AA | Conversation hand gestures — best for 2 soldiers facing each other. |
| `dialogue/generic/a/actor_idle_11h.skc` (also `_20h`,`_27h`,`_28h`,`_31h`,`_35h`) | AA | Idle-while-listening talk gestures (upper-body). One-shots tied to old VO but pose-usable. |
| `misc/point.skc` | AA | Points off into the distance — good "briefing gesture." |

### 2e. Looking around / scanning / curious (empty-hand or holstered)
| Path | Th | Note |
|---|---|---|
| `misc/00g103_axis_lookaround.skc` | SH/BT | Scans surroundings. Top pick. |
| `misc/curiousidle.skc` | AA | Curious head/torso idle. |
| `misc/alertidle.skc` | AA | Watchful stand (mild). |
| `weapon_unarmed/unarmed_stand_curious.skc` | AA | Empty-hand look-around. |
| `weapon_rifle/curious/rifle_stand_curious.skc` (+`_twitch`) | AA | Look-around *holding rifle* — secondary (weapon mismatch when holstered). |

### 2f. SH/BT camp downtime set — `misc/00*` (skeleton-proven; `stretches` already shipped)
| Path | Th | Note |
|---|---|---|
| `misc/00a100_idle.skc` | SH/BT | Allied idle. |
| `misc/00a101_salute.skc` | SH/BT | Salute (allied). |
| `misc/00a102_cleanshoes.skc` | SH/BT | Cleans boots. |
| `misc/00a103_pullups.skc` | SH/BT | Pull-ups (**wants a bar** — see props). |
| `misc/00a104_stretches.skc` *(shipped as coop_emote_stretch)* | SH/BT | Stretch. |
| `misc/00a105_pushups.skc` | SH/BT | Push-ups (on ground — reads fine solo). |
| `misc/00a106_jumpingjacks.skc` | SH/BT | Jumping jacks (PT). |
| `misc/00g101_axis_attention.skc` | SH/BT | Snaps to attention. |
| `misc/00g102_axis_primping.skc` | SH/BT | Adjusts uniform/gear. |
| `misc/00g103_axis_lookaround.skc` | SH/BT | Look around. |
| `misc/00g104_axis_shoeshine.skc` | SH/BT | Shoe shine. |
| `misc/00g105_axis_lean.skc` | SH/BT | Lean. |
| `misc/00g106_axis_pushup.skc` | SH/BT | Push-up. |
| `misc/00g108_axis_milling_1.skc`, `misc/00g109_axis_milling_2.skc` | SH/BT | Milling about. |
| `misc/00egg1_allied_sitar.skc`, `misc/00egg2_axis_sitar.skc` | SH/BT | Easter-egg: plays a sitar. Flavor. |

*(Note: the `00g*` names say "axis" but they're just the animation source; they play on any
human/player skeleton and read as generic soldier downtime.)*

### 2g. Drinking / eating
| Path | Th | Note |
|---|---|---|
| `scripted/pickup_obj/pass_canteen_drink.skc` | AA | Drinks from canteen. |
| `scripted/pickup_obj/pass_canteen_idle.skc` | AA | Holds canteen at rest (settles). |
| `scripted/pickup_obj/pass_canteen.skc`, `pass_canteen_end.skc` | AA | Pass-to-buddy start/end (2-soldier bit). |

### 2h. Salute / gesture one-shots (from `misc/`)
| Path | Th | Note |
|---|---|---|
| `misc/salute.skc` *(shipped as coop_emote_salute)* | AA | Salute. |
| `idle/salute.skc`, `idle/salute_idle.skc`, `idle/salute_idle2.skc` | AA/SH | Salute + hold variants. |
| `misc/nervousb.skc` | AA | Fidget (tonally "on edge" — use sparingly). |
| `misc/determinedidle.skc`, `misc/determinedidle01/02.skc` | AA | Resolute stand. |

### 2i. Weapon-held idles (SECONDARY — only if the lobby shows the rifle in-hand)
| Path | Th | Loop? | Note |
|---|---|---|---|
| `idle/rifle_idle_normal01(loop).skc` (+`02(weight_shift)`) | AA | Loop | Rifle held low, relaxed. |
| `idle/rifle_idle_oshoulder01(loop).skc` (+`02`,`_intro`,`_outtro`) | AA | Loop | **Rifle slung over shoulder** — iconic "waiting" pose if weapon visible. |
| `idle/thompson_idle_stand1..3.skc` | AA | Loop-ish | Thompson at-ease. |
| `weapon_rifle/idles/idle_rifle.skc` | AA | Loop | Plain rifle idle. |
| `weapon_pistol/idles/pistol_stand_bored.skc` | AA | Loop | Bored pistol stand. |
| `weapon_rifle/crouch/rifle_crouch_bored.skc` | AA | Loop | Bored crouch (if any soldier crouches). |

### 2j. Trench / cover downtime (situational)
| Path | Th | Note |
|---|---|---|
| `idle/trench_idle_up.skc`, `idle/trench_idle_down.skc` | AA | Idle leaning on a trench/parapet lip. |
| `weapon_rifle/cornering/rifle_wall_bored.skc` | AA | Bored against wall, rifle (already the cover-donor family). |

---

## 3. NEEDS-PROP (great flavor, but require a placed prop / specific spawn)

These are authored around a prop mesh or exact spawn geometry. Usable in the lobby only if
you place the matching prop (chair/table/crate/bunk/wall) at the soldier's mark. Excellent
for "hero" set-dressing on 1-2 soldiers, not the whole rotation.

| Path | Th | Prop needed | Depicts |
|---|---|---|---|
| `scripted/table/actor_sitchair.skc` | AA | Chair | Sits in a chair. |
| `scripted/table/actor_m1l1_cardidle01.skc`, `..._cardidle02.skc` | AA | Table + chair + cards | **Playing cards at a table** — perfect camp scene. |
| `scripted/table/actor_sit_write.skc` | AA | Table + chair | Sits writing (letters home). |
| `scripted/table/actor_chairstand_slow.skc` / `_fast.skc` | AA | Chair | Stand-up-from-chair transitions. |
| `scripted/table/actor_radio_listenidle.skc`, `_talkidle.skc`, `_op.skc`, `_tune.skc` | AA | Radio set | Radio operator idling/tuning. |
| `scripted/lean/lean_chair_legs.skc` | AA | Chair | Leans back tipping a chair. |
| `scripted/lean/lean_sitwall_legs.skc` | AA | Wall | Sits on ground against a wall. |
| `scripted/sleep/sleep_lowerbunk.skc`, `sleep_middlebunk.skc` (+`jumpup_*`) | AA | Bunk bed | Sleeping in a bunk (+ wake). |
| `scripted/lean/sleep01(loop).skc`, `relaxtosleep.skc`, `sleeptorelax.skc` | AA | (chair/wall implied) | Dozing-off loop + transitions. |
| `scripted/crate_carry/crate_stand_idle.skc` | AA | Crate model | Stands holding a crate. |
| `misc/00a103_pullups.skc` | SH/BT | Bar/beam | Pull-ups. |
| `scripted/welding/welding_idle.skc` (+`welding_start/end`) | AA | Welder + workpiece | Welding (workshop flavor). |
| `scripted/train/*_idle.skc` | SH | Train car | Idle riding/standing on a train car. |

---

## 4. EXCLUDED (scanned but rejected — wrong mood or not passive)

- **Combat / weapon action:** everything under `weapon_*/{cornering,major_pain,minor_pain,prone}`,
  `fire_*`, `*_shoot*`, `*_aim*`, `*_reload*`, `viewmodel/*` (first-person only), `bar_shoot*`, etc.
- **Death / pain:** `deaths/*`, `pain/*`, `*_pain_*`, `hitidle*`, `higginsflinch*`, `fallen*`.
- **Distress mood (not "relaxed"):** `panicidle*`, `fearidle*`, `terroridle`, `angeridle*`,
  `disgustidle*`, `worryidle01`, `deadidle*`. (`nervousb`/`nervous_idle0x`/`alertidle` are
  borderline — listed above but flagged as tense, not at-ease.)
- **Locomotion:** `walks_runs/*`, `multiplayer/mp_*_run/walk/jog`, `cornering/*`, `wallclimb/*`,
  `alert_walk`. (MP `mp_*_stand_idle` / `mp_*_crouch_bored` loop cleanly and ARE player-safe, but
  they're weapon-ready combat idles — same demotion as §2i; pull from here only if a weapon shows.)
- **Vehicle / turret / mounted:** `jeep/*`, `opel/*`, `bmwbike/*`, `flak88/*`, `exit_tank/*`,
  `vehicle_artillery/*`, `weapon_mg42/*`, `tripod/*`, `*_driver.skc`, `train/engine_move`.
- **Ladder / climb / dive / vent:** `misc/ladder*`, `misc/kick_door_*`, `standtocrouch_dive`,
  `diveongrenade*`, `grenade_cower*`, `enter_vent`, `push/*`, `moving_hedge/*`.
- **Prisoner / interrogation (hands-up / being hit):** `scripted/prisoners/*`,
  `scripted/interrogation/*` (`german_hit_*`, `oss_hit_*`).
- **Map-specific scripted cutscene actors:** `scripted/{e1l1..e3l4,t1l1..t3l3,m1l1..m6l3,level_*,
  balcony,scientist,higgins,piperplane,jeepcrash,set_explosive,sledgehammer,...}` — bound to exact
  map geometry / props / timing; won't loop as free-standing lobby poses. (Individual gems inside
  them exist, e.g. `higginslook0x` glances, but they carry the Higgins-specific posture.)

---

## 5. Caveats / recommendations

1. **Add the shortlist (§1) first, test in `co_lobby1`, then decide if more variety is worth the
   MAX_TIKI slots.** ~15-20 new aliases on top of the existing 3 gives a lively camp without
   bloating the player `.tik`.
2. **Prefer §2a/§2b/§2c/§2d/§2e/§2f/§2g (empty-hand)** because the lobby holsters the weapon.
   Reserve §2i (rifle-held) for a mode where the rifle is visible.
3. **Loops vs one-shots:** make the resting/base pose a `(loop)` file (e.g.
   `generic_idle_a01(loop)`, `relax01(loop)`, `unarmed_idle_moretough01(loop)`), and let
   `lobbyIdleRotate` fire the one-shots (stretch, look-around, smoke, drink, cleanshoes) as
   periodic "actions" that return to the loop — same enter→action→return shape the smoking
   sequence already implies.
4. **SH/BT `misc/00*` are confirmed player-safe** (via the shipped `coop_emote_stretch`), so the
   whole downtime set in §2f is low-risk. AA `idle/`, `scripted/lean/`, `scripted/pickup_obj/`,
   `misc/` are AA-human and equally proven by the existing lobby/emote/cover aliases.
5. **Names with `(loop)`/`(weight_shift)`/parentheses are literal filenames** — keep the
   parentheses in the alias value exactly as written; they resolve fine (the existing cover set
   uses the same convention). Do **not** add a `weight` flag (bug-260).
