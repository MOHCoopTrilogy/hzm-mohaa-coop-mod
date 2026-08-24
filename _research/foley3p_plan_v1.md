# 3P weapon foley - plan v1 (for adversarial review)

## Goal

Other soldiers - teammates AND German AI - currently make NO mechanical weapon sound at all. They
reload, cycle bolts, raise and holster in silence. 84 room-mic takes ship in
`sound/coop_gunfoley3p/` with NO alias file and nothing referencing them: inert payload today.

## Evidence base (measured this session, not assumed)

### The mechanism already exists in retail

| Fact | Evidence |
|---|---|
| TIKI anim rows carry frame commands in server/client blocks | `anims_rifle.txt:394-414` |
| Syntax is `<frame or first or enter or entry> sound <alias>` | `enter sound snd_rifle_pullout` |
| A client-block sound is POSITIONAL at the entity origin | `cg_commands.cpp` handler: `PlaySound(sound_name, current_entity->origin, channel, volume, min_distance)` |
| Dispatch path | `cg_modelanim.c:2557/2567` to `CG_ProcessEntityCommands` (`cg_commands.cpp:5324`) |
| Retail ALREADY does per-weapon AI foley | `human_rifle.tik` carries `10 sound kar98_bolt_npc` - the `_npc` suffix shows retail already separates heard-from-outside variants |

Per CLAUDE.md "Fix methodology", this is the confirmed-working recipe to copy.

### There are TWO parallel animation systems, not one

| Who | Files | Granularity |
|---|---|---|
| Players | `models/player/base/anims_<class>.txt` | per CLASS (rifle/smg/pistol/mg/shotgun/bazooka) |
| AI | `models/human/animation/human_<weapon>.tik` | per WEAPON (rifle, thompson, mp40, mp44, pistol, bar, mg42, shotgun, bazooka, vickers, piat, moschetto, bombabreda, grenade, unarmed) |

AI tiks include `models/human/new_generic_human.tik`, which pulls the `human_*` set. They do NOT
read `models/player/base/`. **COVERING ENEMIES THEREFORE REQUIRES EDITING BOTH SETS.** This is the
single biggest scope fact and it was absent from the original estimate.

### Load order (measured)

- Priority is `maintt+mod > mainta > main`, stated in `qcommon/files.cpp:3507`.
- So BT `anims_*.txt` ALREADY shadows AA today.
- BT is a strict superset of SH. It is NOT of AA: AA has `<class>_pain`, `<class>_pain_ducked`,
  `<class>_run_into_wall` in rifle/smg/pistol. BT consolidated pain into `anims_shared.txt`
  (`rifle_pain_kneestodeath`). Pre-existing state, not caused by this feature.
- **PRECEDENT ALREADY PROVEN HERE:** we override `anims_shared.txt` today as a strict superset,
  168 rows vs retail 56, dropping nothing.

### The 1P system, for contrast

`CoopGunFoleyThink()` (`cg_view.c:999`) is CODE-driven, plays `cgi.S_StartLocalSound` (2D), and
reads class from `cg.snap->ps.stats[STAT_EQUIPPED_WEAPON]` - which exists ONLY for self.
`entityState_t` carries no weapon-class field for other entities (the weapon is a separate attached
entity), so a pure-cgame 3P version needs a fragile modelindex to name to class resolution.

## Design

### Option A (recommended): TIKI frame commands, both systems

Add `client { <frame> sound coop_3p_... }` rows to SUPERSET overrides of the per-weapon anim files.

- per-class / per-weapon selection is FREE (the file IS the class)
- positional is FREE
- no protocol change, no new engine code on the core path
- matches the retail `kar98_bolt_npc` recipe

### Option B (rejected): cgame code-driven, mirroring CoopGunFoleyThink

Rejected: weapon class for a non-self entity is not in `entityState_t`, so it needs modelindex
resolution, and it reimplements per-entity anim-transition detection that TIKI already gives free.

### Scope control - overlap analysis

1P covers STATE-driven events: sprint, crouch, ADS, weapon switch, dry fire, idle inspect, wall
bump, landing, low-ammo magcheck.
3P would cover ANIMATION-driven events: reload, bolt cycle, raise, putaway.
These barely intersect. The single genuine overlap is weapon switch (1P `grab`) vs raise/putaway.

## Risks and handling

| # | Risk | Sev | Handling |
|---|---|---|---|
| R1 | SELF-DOUBLE. Hidden entities still run frame commands - `cg_modelanim.c:2545` says so ("the hidden 1P viewmodel still processes its frame commands for the FIRE SOUND, bug-315 kept them"). Retail already double-fires `snd_rifle_pullout` (in BOTH `fps_anims_rifle.txt` and `anims_rifle.txt`); unnoticed only because it is the SAME alias, so two plays in one frame read as one louder sound. With a DIFFERENT room-mic sample the doubling becomes audible. | HIGH | Primary: scope 3P to animation-driven actions the 1P layer does not cover, so there is nothing to double. Secondary if needed: a narrow engine gate following the existing `cg_bCoopMuteVisualCmds` precedent in `CG_ProcessEntityCommands` - skip sound commands whose alias starts with a reserved prefix when `entnum == cg.snap->ps.clientNum` and not in third person. Keyed on OUR prefix so retail behaviour is untouched. |
| R2 | OVERRIDING RETAIL ANIM FILES. Our pk3 wins; a non-superset override silently deletes animations. | HIGH | Every override generated as a STRICT SUPERSET of the highest-priority retail version, with a build-time assertion that `retail_rows - our_rows` is empty. Same discipline as the packer count/balance asserts. `anims_shared.txt` proves the pattern. |
| R3 | THREE-GAME DIVERGENCE. Three effective versions exist (AA/SH/BT). | MED | Base every override on the EFFECTIVE highest-priority file (maintt), which is what already loads. Generator re-derives from the pk3s so it cannot drift. |
| R4 | VOICE-COUNT / BANDWIDTH. `cg_view.c` already notes broadcasting a second sound per shot for every shooter is "a real bandwidth and voice-count cost". 3P multiplies active voices by player+AI count. | MED | Positional sounds attenuate and cull by distance, unlike the 1P 2D layer. Add a distance gate and per-entity cooldown. MEASURE with the VOICES probe before widening. |
| R5 | MAX_SOUNDS at its 2048 HARD ceiling; the pain pool was trimmed 135 lines today for exactly this. The 84 3P wavs are NEW files, unlike the pain tiers which reused existing ones - so this IS a real index cost. | MED | Count it BEFORE authoring via the SNDIDX probe. If tight: share takes across weapons within a class, or cut takes per action from 4 to 2. |
| R6 | ALIAS PREFIX COLLISION. `Sound()` matches by prefix. | LOW | Same rule as the pain tiers: no name may be a prefix of another, no bare parent alias. Assert in the generator. |
| R7 | WIRING 189 ROWS BLIND. `human_rifle.tik` alone has 189 anim rows; most never play in combat. | MED | Do not author blind. Use ANIMFIRE to measure which rows actually fire, then wire only those. |

## Probes

| Probe | Question it settles | Output |
|---|---|---|
| ANIMFIRE | Which anim rows actually fire in play, per entity type? Stops us authoring 189 rows when 12 matter. | `^~^~^ ANIMFIRE ent=%d isAI=%d tiki=%s anim=%s n=%d` aggregated on a timer |
| FOLEY3P | Does self-double actually occur? One `self=1` line proves the gate is needed; none proves it is not. | `^~^~^ FOLEY3P ent=%d self=%d alias=%s dist=%.0f` |
| VOICES | Peak simultaneous sound channels with N players + AI. Answers R4 with a number. | `^~^~^ VOICES peak=%d cur=%d` sampled per second |
| SNDIDX | How many indices the 84 new wavs consume against the 2048 ceiling. Answers R5 BEFORE authoring. | one-shot boot print of used/free |

All four are read-only and fit in one session. ANIMFIRE and SNDIDX must run FIRST, because their
results change what gets authored.

## Phasing

- P0 (measure): SNDIDX + ANIMFIRE only. No content. Decides take budget and row list.
- P1: rifle reload, players only. Wire, then run FOLEY3P + VOICES.
- P2: extend to the measured row list for players.
- P3: AI set (`human_*.tik`) - where most of the value is; there are far more Germans than teammates.
- P4: widen takes / actions only if VOICES and SNDIDX show headroom.

## Explicitly NOT in scope

- Changing any retail alias or retail behaviour.
- Any protocol or configstring change.
- Rewiring the 1P layer.
