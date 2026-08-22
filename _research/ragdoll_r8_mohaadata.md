# Ragdoll round 8 — audit of the bet the SETTLE branch makes on MOHAA's own death data

Scope: does the game's authored death animation actually give the settle branch a good pose to
capture? Everything below is measured from the shipped data (`Pak0.pk3` etc.) and read out of the
engine source. File:line for every claim. No physics opinions — this is the data lens only.

Measurement tooling used (throwaway, in the session scratchpad, not shipped): a 40-line SKC parser
against `openmohaa-hzm/code/skeletor/skeletor_animation_file_format.h` (96-byte header, 48-byte
per-frame record, `static_assert` at `skeletor_loadanimation.cpp:233-234`).

---

## 0. Verdict up front

The settle branch's core premise **holds**: the engine freezes the death animation's final frame at
full weight, forever, and nothing later touches it. The override is neither redundant nor fought.

But the branch as committed will not reach a large share of deaths, and for roughly a third of the
ones it does reach the "landed authored pose" is not landed. Five concrete defects are listed in §6,
ranked. Two are showstoppers (S1, S2) in the sense that the next playtest cannot answer the question
it is meant to answer while they stand.

---

## 1. THE POSE-AFTER-ANIM ANSWER (the single most important fact)

**The corpse holds the death animation's LAST FRAME, at full channel weight, indefinitely. There is
no `dead_pose` hold, no loop, no blend to anything, and no second animation. The pose is stable from
the frame `FinishedAnimation_Killed` fires until the entity is removed.**

Full chain, verified end to end:

| step | file:line | what happens |
|---|---|---|
| 1 | `fgame/actor.cpp:5459` | `Actor::HandleKilled` sets `edict->s.eFlags \|= EF_DEAD`. **This is the edge cgame arms on.** No death anim has been requested yet. |
| 2 | `fgame/actor.cpp:5491-5497` | `ExecuteScript(global/killed.scr)`; `SetThink(THINKSTATE_KILLED, THINK_KILLED)` was set at `:5438`. |
| 3 | `fgame/actor_killed.cpp:49-66` | `Think_Killed` (state `ACTOR_STATE_KILLED_BEGIN`) → `Anim_Killed()` → `actor_animapi.cpp:104-107` `DesiredAnimation(ANIM_MODE_NORMAL, m_DeathHandler)`. `m_DeathHandler` defaults to `STRING_ANIM_KILLED_SCR` = **`anim/killed.scr`** (`simpleactor.cpp:113`, string table `scriptmaster.cpp:308`). |
| 4 | `anim/killed.scr:55` | `self.blendtime = 0.3`; `:62` `setsay death_generic`; then one `setmotionanim death_*`. |
| 5 | `fgame/actor.cpp:7154-7183` | `EventSetMotionAnim` → `gi.Anim_NumForName` (= `TIKI_Anim_NumForName`, `sv_game.c:1820`) → `ChangeMotionAnim()` → `StartMotionAnimSlot(0, anim, **2.0**)`. Weight base 2.0 (`simpleactor.cpp:757-769`) so the death anim outweighs every other channel from ~0.15 s. |
| 6 | `fgame/animate.cpp:713-742` | `PostAnimate`, non-repeating slot: once `frameInfo.time >= animtimes - frametime/10`, **clamp `frameInfo[i].time = animtimes[i]`** and set `ANIM_FINISHED` *only if* `startTime != animtimes[i]`. On every frame after that, `startTime == animtimes` so the flag is never re-raised. Time is re-clamped forever. |
| 7 | `fgame/animate.cpp:628-637` → `fgame/actor.cpp:8016-8054` | `PreAnimate` → `Actor::AnimFinished(slot, stop=true)`: sets `ANIM_NOACTION`, `m_iMotionSlot = -1`, `Unregister(STRING_FLAGGEDANIMDONE)`. **It does not call `StopAnimating` and does not touch `m_weightType[slot]`.** |
| 8 | `anim/killed.scr:523-524` | `waittill flaggedanimdone` resumes → `self.position = "dead"` → `end`. The anim thread dies. |
| 9 | `fgame/actor.cpp:13143-13152` | `Actor::StoppedWaitFor` → `func->FinishedAnimation` = `Actor::FinishedAnimation_Killed` (`actor_killed.cpp:36, 68-72`) → `BecomeCorpse()` + `TransitionState(ACTOR_STATE_KILLED_END)`. All in the same server frame as the clamp in step 6. |
| 10 | `fgame/actor_killed.cpp:53-56` | Every subsequent `Think_Killed`: `m_State != ACTOR_STATE_KILLED_BEGIN` → **returns immediately**. No `Anim_Killed`, no `PostThink` → no `UpdateAnim` (`actor.cpp:7759-7845`) → no `UpdateAnimSlot`, no `ChangeMotionAnim`, no `StopAnimating`. |
| 11 | `fgame/g_phys.cpp:1453-1461` | `G_RunEntity` still calls `PreAnimate`/`Think`/`PostAnimate` (FL_THINK is never cleared in coop — `Actor::DeathSinkStart` at `actor.cpp:5609-5613` is the only clearer and `BecomeCorpse` posts it **only for `GT_SINGLE_PLAYER`**, `actor.cpp:12544-12545`). So `PostAnimate` keeps re-clamping the time and nothing else changes. |

Consequence for the channel weight: the motion slot keeps `m_weightType == ANIM_WEIGHT_MOTION`, and
because `UpdateAnimSlot` stops being called, the weight is frozen at its last computed value
(saturated `m_weightBase` = 2.0, `simpleactor.cpp:823-838`). It never decays to
`ANIM_WEIGHT_LASTFRAME` → `StopAnimating`, which is the only path that would zero the pose.

**`dead_pose*` is a red herring.** `dead_pose1/2/3` do exist —
`models/human/animation/scripted/dead_poses.tik`, `$include`d four times at
`models/human/new_generic_human.tik:128, 316, 877, 1237` — but they are 4-frame delta-driven set
dressing (SKC flags `0x20` = `TAF_DELTADRIVEN`, `tiki/tiki_shared.h:39`) and the only two callers in
the whole mod are level scripts placing pre-dead bodies: `maps/e2l1/gliderride.scr:366-367` and
`maps/m5l1a.scr:1420-1422`. **The engine never plays them after a death.**

### Corollaries that matter for the build

- **The settle capture is pixel-exact.** The rendered pose uses client-interpolated frameInfo
  (`cg_modelanim.c:341-411`), the capture uses the raw state (`cg_ragdoll.c:1292` passes `cs`).
  At anim end both server snapshots carry `time == Anim_Time`, so the interpolation is a no-op and
  the two agree exactly. (In **mode 3** the capture uses `ns` — `cg_ragdoll.c:1438` → `RagArm(cent,
  ns)` — a pose up to one snapshot interval *ahead* of the screen. That is a mode-3-only pop.)
- **Wire quantization is inside the settle gate's tolerance.** `frameInfo.time` is packed as
  `(int)(time * 100.f)` over 15 bits (`qcommon/msg.cpp:2308-2320`) — a **10 ms truncation grid**.
  The gate's 60 ms window (`cg_ragdoll.c:1252`) is 6× that. Safe.
- **`frameInfo.weight` is wire-clamped to 1.0** (`msg.cpp:2331-2343`, 8 bits, `maxValue * weight`
  clamped at `maxValue`). So the death anim arrives at weight 1.0, not 2.0, and
  `RagPendingThink`'s `bestW >` scan (`cg_ragdoll.c:1244-1249`) is really "first slot at max weight".
  Motion slots are 0-2 / 3-5 (`simpleactor.cpp:GetMotionSlot`), action 6-11, say 12-13, so the
  motion slot always wins a tie against say/action. During the first ~0.3 s the *outgoing* living
  anim can tie at 1.0 on a lower index — which is exactly why the `age > 300` guard at
  `cg_ragdoll.c:1267` is needed and is correct.

---

## 2. Death-anim inventory and how much variety a player actually sees

### What exists

- `models/human/new_generic_human.tik` carries **30 `death_*` alias lines**. Byte-identical alias set
  in retail `main/Pak0.pk3`, `mainta/pak1.pk3`, `maintt/pak1.pk3` — the mod has added and removed
  nothing.
- Random groups collapse: TIKI strips trailing digits from any alias flagged `random`
  (`tiki/tiki_files.cpp:1046-1057`). So `death_back1/2/3` → alias **`death_back`**, `death_run01/02/03`
  → **`death_run`**, `death_grenade01/02` → **`death_grenade`**, `death_generic1/2/3` →
  **`death_generic`** (the facial say anim). `TIKI_Anim_NumForName` (`tiki/tiki_anim.cpp:95-180`)
  then picks inside the identical-alias run by weight. **Good news for the cgame**: the name
  `Anim_NameForNum` returns is the *stripped* base, so the `"death"` prefix test still matches.
- Across `models/human/animation/**.tik` there are **51 death-ish aliases**, of which only **13
  begin with `death`**. The other 38 are the `<wg>_pain_{knees,crawl,floor}todeath` family (24
  aliases → 9 distinct SKC clips), the `<wg>_wall_death_{left,right}` family (12 aliases → 2 distinct
  clips) and the set pieces (`chair_death_*`, `welding_death`, `opel_driver_death`,
  `cabinet_hiding_death`, `open_gate_death`).

### What `anim/killed.scr` can actually reach

**26 distinct `.skc` files, 25 of them live** (see §5 for the dead one). Two aliases share a file:
`death_head_flyforward` and `death_run` slot 3 are both `deaths/death_run03.skc`;
`death_grenade` slot 2 and `death_mortar_flip` are both `deaths/death_mortar_flip.skc`.

### Repetition per bucket — the honest numbers

`local.yaw = self GetLocalYawFromVector self.fact.direction`; `randomint 100` → 0..99.

| situation | file:line | candidate clips | modal clip |
|---|---|---:|---|
| standing, upper/middle torso, hit from the FRONT | `killed.scr:307-344` | **7** | `death_knockedup` ≈29 % |
| standing, upper/middle torso, any other angle | `killed.scr:328-343` | **3** | `death_chest` ≈41 % |
| standing, head/helmet | `killed.scr:361-400` | **7** (9 clips w/ the `death_back` group) | `death_shoot` / `death_fall_to_knees` ≈20 % each |
| standing, pelvis/lower torso | `killed.scr:268-304` | **5** | `death_chest` ≈36 % |
| standing, either arm | `killed.scr:404-458` | **4** | `death_chest` ≈36 % |
| standing, either leg | `killed.scr:462-514` | **4-5** | `death_collapse` ≈36 % |
| neck | `killed.scr:347-357` | **2** (50/50) | — |
| running (fwd vel > 130) | `killed.scr:232-259` | **3** (`death_run` group) or knockedup/chest | — |
| **crouch / knees / crouchwalk, not shot from the front arc** | `killed.scr:174-198` | **1** | `mp44_pain_kneestodeath.skc` **100 %** |
| **prone / floor** | `killed.scr:202-230` | **1** | `death_prone1.skc` **100 %** |
| explosive, dmg > 75 | `killed.scr:93-113` | **3** | — |
| explosive, dmg 50-75 | `killed.scr:114-137` | 1 per direction (4 aliases) | — |
| explosive, dmg ≤ 50 | `killed.scr:138-154` | **3** | — |

So: front-on torso and head kills look varied; everything else collapses fast, and **every crouching
enemy in the game plays the same single animation, as does every prone one.** `rifle_pain_kneestodeath`
and `thompson_pain_kneestodeath` are different aliases pointing at the *same* file
(`weapon_mp44/major_pain/mp44_pain_kneestodeath.skc`) — the weapon-type switch at `killed.scr:174-198`
buys literally nothing.

---

## 3. Measured: is the last authored frame a *landed* pose?

Per-frame `bounds`/`delta` decoded from the SKC. `AnimT` uses the engine's own formula —
`TIKI_Anim_Time`, `tiki/tiki_anim.cpp:272-284`: every death SKC has header `flags == 0`, so
**`AnimT = frameTime * (numFrames - 1)`**. Speeds are the bbox-centre displacement over the last
frame interval, converted to game units with the human TIK's `scale 0.52`
(`models/human/german_afrika_private.tik:4`).

| alias (clip) | frames | AnimT s | last-frame speed u/s | prev-frame u/s |
|---|---:|---:|---:|---:|
| `death_back` [1/3 back_death01] | 58 | 1.90 | **0** | 0 |
| `death_back` [2/3 back_death02] | 58 | 1.90 | **0** | 0 |
| `death_back` [3/3 death_back3] | 14 | 0.43 | 51 | 52 |
| `death_backgrenade` | 20 | 1.27 | 1 | 3 |
| `death_chest` | 32 | 2.07 | 9 | 53 |
| `death_choke` | 36 | 2.33 | 0 | 4 |
| `death_collapse` | 21 | 1.33 | 0 | 1 |
| `death_crotch` (stomach_death) | 59 | 1.93 | **0** | 0 |
| `death_fall_back` | 25 | 1.60 | 38 | 35 |
| `death_fall_to_knees` | 26 | 1.67 | 14 | 69 |
| `death_frontchoke` (gassing02) | 86 | **2.83** | **0** | 0 |
| `death_frontcrouch` | 10 | 0.60 | 0 | 32 |
| `death_grenade` [1/2 grenade_death] | 59 | 1.93 | **0** | 0 |
| `death_grenade` [2/2 mortar_flip] | 11 | 1.00 | 46 | 35 |
| `death_grenade_high` (dead code) | 25 | 1.60 | 11 | 39 |
| `death_head_flyforward` = `death_run`[3/3] | 13 | 0.80 | **103** | 103 |
| `death_headpistol` | 21 | 1.33 | 21 | 79 |
| `death_knockedup` | 19 | 1.20 | 0 | 2 |
| `death_left` / `death_right` | 20 | 1.27 | 6 | 2 |
| `death_prone` | 14 | 0.52 | 4 | 4 |
| `death_run` [1/3] | 16 | 1.00 | 44 | 63 |
| `death_run` [2/3] | 11 | 0.67 | 39 | 147 |
| `death_shoot` | 21 | 1.33 | 0 | 17 |
| `death_twist` | 20 | 1.27 | 35 | 44 |
| `death_mortar_high` | 23 | **2.20** | **118** | 30 |
| `death_mortar_medium` | 20 | 1.90 | 15 | 115 |
| `death_mortar_twist` | 18 | 1.70 | 3 | 25 |
| `*_pain_kneestodeath` | 11 | 0.67 | 43 | 37 |
| `*_pain_floortodeath` | 7 | 0.40 | 31 | 55 |
| `*_pain_crawltodeath` | 3 | 0.20 | 66 | 177 |
| `*_wall_death_left/right` | 42 | **2.73** | 1 | 1 |

**Reading**: 15 of 31 clips end essentially at rest (≤ 10 u/s) — the animators did land those.
**11 clips are still moving at 30-120 u/s when the engine clamps the last frame.** For those the
"authored landed pose" the settle branch captures is a body caught in mid-fall, and handing it to a
sim with `gravScale = 0` and zero seed velocity (`cg_ragdoll.c:1298-1304`) plants it there. That will
read as a *second* mannequin freeze, not as a landing.

Two clips also end with the whole skeleton **below the entity origin**: `death_mortar_high` last
frame model-space z-range `-57.0 … -24.5` (= **-29.6 … -12.7 game units**), `death_mortar_medium`
`-73.4 … -35.9` (= **-38.2 … -18.7 gu**). Both are reachable via
`exec global/setdeathanim.scr "death_mortar_high"` (5 call sites) / `"death_mortar_medium"` (3).

---

## 4. What else moves, changes or clears a corpse after we arm

### Clear signals the cgame honours (`cg_ragdoll.c:1343-1347`)

`EF_DEAD` falling edge · `EF_TELEPORT_BIT` toggle · `modelindex` change · `eType` change.

| candidate event | verdict | evidence |
|---|---|---|
| `pophelmet` (frame command on 8 death anims + `killed.scr:69/111/135/256/531`) | **safe** — surface bit only, not modelindex | `sentient.cpp:4674-4695` `edict->s.surfaces[iSurf] \|= MDL_SURFACE_NODRAW` |
| decapitation (`coop_decap` default **1**, chance 30, budget 3) | **safe** — hides corpse head surfaces, `gi.setmodel` is on the *gib* entity, not the corpse | `sentient.cpp:3102-3130`, `:3204`, `:3247` (gib), `:3411` |
| decap neck stump / wound props / blood drips | **safe** — they `attach()` to a corpse tag and the client resolves tags through the ragdoll bridge | `sentient.cpp:3495`, `:2330`, `:2818`; `cl_cgame.cpp:813` `cgi->TIKI_Orientation = re.TIKI_Orientation`; Hook B at `renderergl2/tr_model.cpp:2353` |
| gore skin tiers | **safe** — `edict->s.surfaces[]` bits | `sentient.cpp:2945+` |
| `DeathEmbalm` (shrinks `maxs.z` 4 u every 0.5 s to 8) | **safe** — bbox only, no origin, no state | `actor.cpp:5587-5601`, posted at `actor_killed.cpp:45` |
| `BecomeCorpse` → `droptofloor(64)` → `setOrigin` | **safe and helpful** — fires at anim end, i.e. *before* the settle capture; no teleport bit (`entity.cpp:2637-2655`) | `actor.cpp:12468-12530` |
| `BecomeCorpse` bbox flatten + `CONTENTS_WEAPONCLIP` | **safe** — not in `MASK_PLAYERSOLID`/`MASK_MONSTERSOLID`, so nothing can push the body | `actor.cpp:12492` |
| `MOVETYPE_TOSS` survivors (droptofloor failed — died on a ledge) | **live risk**, see S4b | `actor.cpp:12523` |
| SP corpse sink (`EV_DeathSinkStart`, 10 s) | **not in coop** — gated on `GT_SINGLE_PLAYER` | `actor.cpp:12544-12545` |
| `coop_mod/corpse.scr` despawn | alpha fade then `remove`; **default `coop_corpseLife 0` = never** (`autoexec.cfg:357`). `remove` orphans the sim slot until it sleeps | `coop_mod/corpse.scr:23-31`, `coop_mod/aihandler.scr:177` |
| `aihandler.scr:137 removeattachedmodel "tag_weapon_left"` on every death | **safe** — child entity, not the corpse model | — |
| DBNO / revive | **cannot reach** — `cg_ragdoll.c:1400-1402` refuses `ns->number < cgs.maxclients` | — |
| `Sentient::setModel` / script `self model` | **would clear** (modelindex) — no engine path does this to a corpse; only a map script could | `sentient.cpp:3991-3997` |

`EF_TELEPORT_BIT` is toggled in exactly two places in the whole of fgame — `entity.cpp:5194`
(EV_Entity_Teleport) and `g_client.cpp:304-305` (player respawn). Neither touches a corpse.

**Body queue**: `AddToBodyQue` re-uses `this`; it does not create a new entity, so the entnum key
holds. `MAX_BODYQUEUE` is 128 in this fork (`actor.h:306`), oldest gets `EV_Remove`.

---

## 5. Unused / mis-wired death anims, and cheap variety wins with no physics involved

### Bugs in the shipped data (all vanilla, all one-line fixes)

**(a) Half the "shot from behind" arc is unreachable.** `killed.scr` tests
`(local.yaw > 135) && (local.yaw < 225)` at **eight** sites (`:168, 279, 324, 372, 409, 467, 495, 563`).
`GetLocalYawFromVector` ends with `AngleSubtract` (`entity.cpp:6432-6441`), which is documented and
implemented as **"Always returns a value from -180 to 180"** (`qcommon/q_math.c:1272-1287`). Values in
180..225 therefore never occur, and every rear-shot branch fires on only 135..180 — half its intended
cone; the other half falls through to the generic `else`. Changing the test to
`(local.yaw > 135 || local.yaw < -135)` immediately doubles the reach of `death_run` (torso),
`death_head_flyforward` (head), `death_knockedup` (legs), `death_twist` (arms) and `death_frontcrouch`
(crouch). **This is the single cheapest realism win in the file** and it is independent of the ragdoll.

**(b) `death_grenade_high` is dead code.** `killed.scr:96-107` sets it on a 30 % roll and then
*unconditionally* sets `death_backgrenade` or `death_grenade` in the same frame. The second
`setmotionanim` wins: `EventSetMotionAnim` → `ChangeMotionAnim()` short-circuits its channel swap on a
repeat call in the same `level.frame_skel_index` (`simpleactor.cpp:564`) and then
`StartMotionAnimSlot` overwrites slot 0 (`actor.cpp:7172-7180`). The script's own comment at
`killed.scr:59-61` warns about exactly this. Restructuring into `if/else` recovers a third
explosive-death clip for free.

**(c) Two `setdeathanim` names do not resolve.** `global/setdeathanim.scr` is called 103 times
(12 of them `NIL`). Two of the names are not aliases of `new_generic_human.tik`:
- `death_gassing` (1 site) — the alias is **commented out** at `new_generic_human.tik:1839-1847`
  ("Identical to death_frontchoke"). Retarget the call to `death_frontchoke`, or uncomment.
- `death_mortar` (2 sites) — only exists on the Higgins scripted set (`death_mortar01/02/03`,
  `availability maps:m3l1a`), so it resolves everywhere else to -1 → `UnknownAnim` (`actor.cpp:7166`)
  → `StartMotionAnimSlot(0, -1, 2.0)`.

**(d) The crouch bucket ignores the weapon group.** `killed.scr:174-198` hardcodes
`rifle_pain_kneestodeath` / `thompson_pain_kneestodeath`, and both alias to the *same* SKC.
`anim/pain.scr:392` already does it correctly: `self setmotionanim (self.weapongroup +
"_pain_kneestodeath")`. Copying that one line into `killed.scr` turns 1 clip into 3
(`grenade_`, `mp44_`, `pistol_` are the three distinct source files behind the 8 aliases).

### Present in the data, never wired

`deaths/death_fire.skc` (48 frames, 4.70 s — no alias anywhere), `death_choke2` (byte-identical to
`death_choke`), `death_upgrenade` (commented out, `new_generic_human.tik:1992-2001`),
`deaths/pose_a/b/c` (aliased as `dead_pose1/2/3`, used only as level set dressing).

---

## 6. Findings against the SETTLE build, ranked

### S1 — SHOWSTOPPER: the `"death"` prefix gate drops a whole family of real deaths

`cg_ragdoll.c:1267`
```c
if (age > 300 && (!nm || Q_stricmpn(nm, "death", 5))) { /* drop the pending record */ }
```
36 of the 51 death-ish aliases in the human anim set do not begin with `death`. The ones that are
reachable in normal play:

| alias pattern | reached from | what dies this way |
|---|---|---|
| `<wg>_pain_kneestodeath` | `anim/killed.scr:179, 183, 187, 192, 196`; `anim/pain.scr:392` | **every** crouching / kneeling / crouch-walking AI not hit from the front arc |
| `<wg>_pain_floortodeath` | `anim/pain.scr:408` | AI killed while on the floor after a major-pain fall |
| `<wg>_pain_crawltodeath` | `anim/pain.scr:400`; `coop_mod/wounded.scr:593` | the mod's own mortal-wound theater |
| `<wg>_wall_death_left/right` | `anim/cornerleft.scr:287`, `anim/cornerright.scr:290` | AI killed while cornering at a wall |

Crouching is the single most common AI posture in MOHAA combat. As committed, those bodies never
ragdoll at all — and they are exactly the bodies whose one shared animation the player will see over
and over, i.e. the population that most needs the variety.

**Fix**: invert the test. Accept anything, and *deny* the set-piece list, which is short and
enumerable: `death_balcony*`, `chair_death_*`, `welding_death`, `opel_driver_death`,
`cabinet_hiding_death`, `open_gate_death`, `jeep_crash_*`, and any name set through
`global/setdeathanim.scr` that is not a `death_*`/`*todeath`/`*_wall_death_*` (the scripted ones are
listed in §5c and are all uppercase-prefixed level codes like `21A201_RagDollDeath`,
`13G106_ColonelDeath`, `22A222_DeathTruck`).

### S2 — SHOWSTOPPER: the 3000 ms pending cap is too short for the longest anims

`cg_ragdoll.c:1281` `if (!((animDone && s->pendStatic >= 2) || age > 3000)) return;`

`age` is measured from the `EF_DEAD` edge (`cg_ragdoll.c:1429`), which is **one server frame before**
`setmotionanim` runs, and the capture then needs ≥ 2 more static client frames. Measured `AnimT`:

- `death_frontchoke` **2.83 s** (reachable from neck hits, front torso and low-damage explosives)
- `<wg>_wall_death_left/right` **2.73 s**
- `death_choke` 2.33 s · `death_mortar_high` 2.20 s · `death_chest` 2.07 s · `death_crotch` 1.93 s

`death_frontchoke` and the wall deaths blow the cap; the rest have < 1 s of margin. On the cap path
the code captures **mid-animation** — which is the mannequin case the branch exists to eliminate,
now silently and only on the longest, most visible deaths.

**Fix**: derive the cap. The dominant anim index is already in hand at `cg_ragdoll.c:1250-1251`, so
`cap = animT * 1000 + 500` is free. Verified available in the import struct:
`float (*Anim_Time)(dtiki_t*, int)` — `cgame/cg_public.h:387`.

### S3 — the captured pose is not always a resting pose (see §3)

11 of 31 reachable clips are still moving at 30-120 u/s on their last frame. The settle arms with
`ptPrev == pt` (zero velocity, `RagCapture` line `cg_ragdoll.c:486`) and `gravScale = 0`
(`cg_ragdoll.c:1301`), so the body stops dead in mid-fall and then eases down.

**Fix that uses the game's own data**: seed the Verlet from the animation's own end velocity. At
capture, pose the model a second time with `frameInfo[dom].time -= Anim_Frametime(...)`, read the same
15 tags, and set `ptPrev[i] = pt_prevframe[i]` scaled to the substep. Both calls are verified present:
`float (*Anim_Frametime)(dtiki_t*, int)` — `cg_public.h:388`; `void (*ForceUpdatePose)(refEntity_t*)`
— `cg_public.h:408`; `orientation_t (*TIKI_Orientation)(refEntity_t*, int)` — `cg_public.h:409`.
Cost: one extra `ForceUpdatePose` + N `TIKI_Orientation` at arm time only. **cgame.dll only, no engine
change.** This is also the single change most likely to answer "bodies don't fall like that", because
it makes the physics *continue* the animator's motion instead of contradicting it.

### S4a — the two mortar anims start the sim deep in solid

`death_mortar_high` / `death_mortar_medium` end with the entire skeleton 13-38 game units *below* the
entity origin (§3). `BecomeCorpse` anchors a `(-32,-32,0)…(32,32,16)` box at that origin
(`actor.cpp:12492`), so those corpses are already partly inside the floor in vanilla. Every one
of the 15 sim points will then be `startsolid`; the pre-lift loop (`cg_ragdoll.c:493-509`) traces from
only **+24 u** above the point, which is not enough for a 38-unit burial — points that fail the lift
freeze, pin the body and produce exactly the pile described in the round-3 finding at
`cg_ragdoll.c:88-89`. Either add `death_mortar_*` to the deny list alongside `death_balcony*`, or
raise the pre-lift start to 64 u and bail the whole arm if any point still fails.

### S4b — a `MOVETYPE_TOSS` corpse can be armed while still falling

If `CheckGround` and `droptofloor(64)` both fail, `BecomeCorpse` hands the body to `MOVETYPE_TOSS`
(`actor.cpp:12523`) and it keeps falling under server physics. `RagPendingThink` correctly refuses to
arm while the origin moves — but the `age > 3000` escape at `cg_ragdoll.c:1281` arms anyway.
`RagPush` then converts against the **current** `lerpOrigin` (`cg_ragdoll.c:899`, the bug-1964 fix),
so the mesh rides the falling origin while the world-space sim points stay put: the mesh slides out of
its own skeleton. **Fix**: on the cap path, require `pendStatic >= 2` too, and simply drop the record
otherwise (the corpse keeps its authored pose, which is the correct fallback).

### S5 — pool starvation, new in this branch

A pending record holds one of `RAG_MAX_SIMS` (8) slots from the `EF_DEAD` edge through the whole
animation — up to 2.83 s — *and then* through the 6 s sim life. That is roughly double the slot
residency of mode 3. `RagAllocSlot` (`cg_ragdoll.c:1160-1189`) evicts only `state == 2` (asleep) and
never a pending (`-1`) or awake record, so a burst of 8+ near-simultaneous deaths — a grenade in a
squad, an officer wave — silently refuses every subsequent arm. Cheapest fix: allow eviction of the
**oldest pending** record when the pool is full (a pending record has captured nothing and costs
nothing to discard); better, keep pending records in a separate small array so they never consume a
sim slot at all.

---

## 7. Weapon drop and helmet pop — no desync, and the settle branch is strictly better than mode 3

**Weapon.** `Actor::DispatchEventKilled` calls `DropInventoryItems()` at the killed event
(`actor.cpp:5516-5528`), i.e. before the death animation even starts. `Item::Drop`
(`item.cpp:491-503`) places the item at **`owner->origin + (0,0,40)`** with
`velocity = owner->velocity*0.5 + (crandom(50), crandom(50), 100)` and a random spin — it is *never*
placed at the hand tag. So the dropped weapon was already decoupled from the hands in vanilla, and a
ragdolled corpse cannot desync from it. `g_droppeditemlife` then removes it (`weapon.cpp:2732-2733`,
`item.cpp:516`); the project runs it at 60 s (entity-pool note, bug-914..927).

**Helmet.** `EV_Sentient_PopHelmet` (`sentient.cpp:4674-4740`) hides the helmet surfaces on the corpse
(surface bits, so the ragdoll override survives) and spawns a `HelmetObject` at the world position of
the **server's** `Bip01 Head` tag (`G_TIKI_Orientation`, `sentient.cpp:4713-4732`). The server knows
nothing about the client ragdoll, so a helmet popped *while a ragdoll is running* would appear at the
authored-anim head, not the simulated one.

In **SETTLE** this cannot happen: every `pophelmet` is either a frame command inside the death anim
(frames 7-25 of 8 anims — `new_generic_human.tik:1778, 1803, 1916, 2027, 2041, 2064, 2078, 2101`) or a
`killed.scr` call at the death edge (`:69, 111, 135, 256`), all strictly **before** the settle
capture. In **mode 3** the pop lands mid-ragdoll and the helmet spawns at the wrong head. One more
reason the settle ordering is the right architecture.

---

## 8. Two items from the joint-limits agent, seen from the data side

- **Knee not simulated.** Confirmed buildable: `Bip01 L Foot` / `Bip01 R Foot` are real animated
  channels on the human skeleton (decoded from `deaths/death_prone1.skc` — 73 channels including
  `Bip01 L Foot pos/rot/rotFK`, `Bip01 R Foot pos/rot/rotFK`, `Bip01 L/R Toe0 rot`). Note that adding
  them as sim points 15/16 requires moving the four `Bip01 L/R Foot`/`Toe` rows of the anchor table
  (`cg_ragdoll.c:200-205`, currently anchored to the calf points 12/14) and extending
  `s_ragPtRadius` (`cg_ragdoll.c:181-187`). The payoff is largest in exactly the crouch/prone/crawl
  family that S1 currently drops — those clips end with the legs flat and the shins fully visible.
- **Off-by-one bone driving.** Nothing in the death data contradicts it; the shear would be invisible
  in the `coop_ragdollTest 2` freeze drill (S = identity) and visible only once the sim moves, which
  matches the reported symptom set.

---

## 9. One-line summary of the bet

The engine does exactly what the settle design assumed — it freezes the death animation's last frame
at full weight, permanently, with nothing downstream to fight. The bet fails on the *content*, not the
mechanism: a third of the reachable clips are not at rest when they freeze, two of them freeze the body
underground, the two longest overrun the pending cap, and the largest single population of deaths
(crouching AI) never reaches the branch at all because its animation is not named `death_*`.
