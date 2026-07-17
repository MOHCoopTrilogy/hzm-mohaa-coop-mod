# Live MP-Safe Helmet Switcher — Research + Buildable Design

Status: RESEARCH COMPLETE (2026-07-10). No game/engine files edited. Every load-bearing claim is
cited to `file:line` in the engine (`openmohaa-hzm/code`) or the mod (`hzm-mohaa-coop-mod`).
Confidence markers: **VERIFIED** = proven from source; **UNVERIFIED** = needs a 15-min in-game test.

---

## (a) VERDICT

**A live, MP-safe helmet ON/OFF switch is VIABLE via surface-nodraw, and it replicates to remote
clients. Ship that as v1. It needs ZERO new art and (optionally) ZERO engine changes.**

- The helmet on nearly every allied player model is a **separate composite surface named
  `us_helmet`** (loaded as `skelmodel us_helmet.skd` inside the player `.tik`). Hiding it live is
  one script line: `self surface us_helmet +nodraw`.
- **Replication is PROVEN from the netfield table**, not assumed: `entityState_t::surfaces[0..31]`
  are all delta-encoded into the snapshot (`qcommon/msg.cpp:1380-1478`), and the `surface` script
  event writes exactly `edict->s.surfaces[]` (`fgame/entity.cpp:4275-4278`). The change is
  server-authoritative and visible on every client's copy of that player.
- The head under the helmet is a **complete head** on all US models (the mod already ships authored
  `...nohelm` variants using the *same* head skelmodel — `rifleman.tik` head2.skd ==
  `riflemannohelm.tik` head2.skd), so helmet-off reveals a proper head, not a bald crown gap.

**The "swap to a DIFFERENT helmet" path (alt-helmet) is also replication-safe** (attached models
net their `parent`/`tag_num`/`attach_offset` — `msg.cpp:1356,1371,1373,1397-1399`), **but the
visual alignment of an `attachmodel`'d helmet is UNVERIFIED** and will need per-helmet offset/scale
tuning because the standalone helmet tiks are full-skeleton skelmodels, not head-tag props. Treat
alt-helmet as v2, gated on a live test.

Recommended v1 = a **2-state toggle (helmet ON / helmet OFF)**. It is the smallest thing that is
provably correct in MP and needs no assets. Extend to a 3-state (ON / ALT / OFF) once the
attachmodel alignment is confirmed in-game.

Whole-model `dm_playermodel` pre-baked variants are the fallback-of-last-resort ONLY if a live
in-game test somehow shows the surface change not painting on remotes (it will — the netfield
proves it). Do not start there; it doubles the model count and is heavier on the wire.

---

## (b) VERIFIED SCRIPT API (signatures from engine source)

### Hide/show a surface — `surface` (works on a Player)
Event declared `fgame/entity.cpp:739-751`, handler `Entity::SurfaceModelEvent`
(`entity.cpp:4290-4302`) → `Entity::SurfaceCommand` (`entity.cpp:4199-4288`). Registered on `Entity`
at `entity.cpp:1585`; `Player` inherits it (Player→Sentient→Animate→Entity), so `self surface ...`
on a player is valid.

```
self surface <surfaceName> <token> [token2 ...]
```
- Tokens (case-insensitive), first char sets direction: `+` sets the flag, `-` clears it
  (`entity.cpp:4224-4237`). Default when neither given is `+` (with a warning).
- Valid tokens: `nodraw`, `skin1`, `skin2`, `crossfade` (`entity.cpp:4243-4255`).
- `surfaceName` may be `all`, or end in `*` for a prefix match, else exact
  (`entity.cpp:4208-4221`). An unknown surface just warns "group not found" and returns — **not
  fatal** (`entity.cpp:4214-4217`), so issuing a nodraw for a surface a given model lacks is
  harmless console noise.

Concrete calls for the feature:
```
self surface us_helmet +nodraw      // hide helmet (live)
self surface us_helmet -nodraw      // show helmet (live)
```
`+nodraw` ORs `MDL_SURFACE_NODRAW (1<<2)` into `edict->s.surfaces[idx]` (`entity.cpp:4247-4248`,
`4275`); `-nodraw` clears it (`4278`). `MDL_SURFACE_NODRAW` def: `q_shared.h:2030`.

### Attach a prop model (alt-helmet path) — `attachmodel`
Event declared `entity.cpp:379-395`, handler `Entity::AttachModelEvent` (`entity.cpp:4335-4427`),
low-level `Entity::attach` (`entity.cpp:3742-3790`). Verbatim signature string
(`entity.cpp:383-384`): format `"ssFSBFFFFV"`, args:
```
self attachmodel <modelname> <tagname> [scale] [targetname] [detach_at_death]
                 [removetime] [fadeintime] [fadeoutdelay] [fadetime] [offset(vec)]
```
- The engine `Tag_NumForName(edict->tiki, tagname)` resolves the tag (`entity.cpp:4410`); the head
  tag on player models is **`"Bip01 Head"`** (used by the engine itself at `player.cpp:2655`
  `SetControllerTag(HEAD_TAG, ... "Bip01 Head")`).
- Detach with `self removeattachedmodel <tagname>` (`EV_RemoveAttachedModel`, `entity.cpp:396-404`;
  handler `entity.cpp:4429+`) or `<child> detach` (`EV_Detach`, `entity.cpp:413-421`).
- The attached entity is spawned as a new `Animate`, plays its `idle` anim
  (`entity.cpp:4344,4408,4413`).

### Helmet attach tag
Helmets on the composite models are `skelmodel us_helmet.skd` weighted to the shared bip01 skeleton
(see model dumps below); the standalone helmet tiks (`models/equipment/ushelmet*.tik`) are the SAME
`us_helmet.skd` with an `idle us_helmet.skc` (verified by dumping `ushelmet.tik` /
`ushelmet_medic.tik`). Because those are full-skeleton skelmodels rather than a small prop anchored
at a head tag, attaching one at `"Bip01 Head"` needs an offset/scale to sit correctly — see risks.

---

## (c) MP-REPLICATION PROOF (code path, both mechanisms)

The game DLL runs server-side; the `surface`/`attachmodel` events mutate the player edict's
`entityState_t s`, and the server delta-encodes networked `entityState_t` fields into every client's
snapshot. What replicates is defined by the netfield tables in `qcommon/msg.cpp`.

### surface nodraw — REPLICATES (VERIFIED)
- Write site: `edict->s.surfaces[surface_num] |= MDL_SURFACE_NODRAW` (`entity.cpp:4275`).
- `entityState_t.surfaces` is `byte surfaces[32]` (`q_shared.h:2092`, `MAX_MODEL_SURFACES 32`
  `q_shared.h:2026`).
- Netfield table includes **all 32**: `surfaces[0..5]` at `msg.cpp:1380-1386` and `surfaces[6..31]`
  at `msg.cpp:1453-1478` (8 bits each). The table repeats for the 3 protocol variants
  (AA/SH/BT): `1534-1628` and `1688-1786`. So a `surface us_helmet +nodraw` on the server is sent
  to and applied on every remote client's render of that player. **VERIFIED.**
- Cap note: only the first 32 surfaces of a composite exist/replicate; the allied player models have
  ~9 surfaces and `us_helmet` sits at a low index — no cap concern.

### attachmodel — REPLICATES (VERIFIED for the state; visual alignment UNVERIFIED)
- `Entity::attach` writes `edict->s.parent`, `edict->s.tag_num`, `edict->s.attach_use_angles`,
  `edict->s.attach_offset` on the *attached* entity's own edict (`entity.cpp:3778-3784`).
- Those exact fields are networked: `parent` (`msg.cpp:1356`), `tag_num` (`1371`),
  `attach_use_angles` (`1373`), `attach_offset[0..2]` (`1397-1399`), plus the child's `modelindex`
  (`1355`). The client re-attaches the child to the parent's tag from snapshot data. So the extra
  helmet model *appears and tracks* on remotes. **State replication VERIFIED.** Whether it lands at
  the right spot/scale on the head is the open question (risks §g).

### The one thing that is NOT client-local
Both mechanisms are server-driven entityState — there is no client-only rendering trick here, so
host and remote clients see the same thing. (Contrast: a pure `cg_`/cvar client effect would not.)

---

## (d) MODEL COVERAGE (allied models the coop lobby cycles)

Roster source: `coop_mod/lobby.scr:57-132` (`level.coop_lobbySkins[1..76]`). Structure verified by
extracting the tiks from the paks. Helmet surface token is **`us_helmet`** across the US line.

| Model (dm_playermodel) | Head skd | Helmet piece | Bare-head clean? | Notes |
|---|---|---|---|---|
| `american_army` (engine default, `player.cpp:2599`) | head1 | `surface us_helmet` (skel us_helmet.skd) | YES | canonical case |
| `rifleman` | head2 | `surface us_helmet` | YES | authored `riflemannohelm` proves complete head |
| `submachine_gunner` | head1 | `surface us_helmet` | YES | authored `submachine_gunnernohelm` exists |
| `support_gunner` | head2 | `surface us_helmet` | YES | authored `support_gunnernohelm` exists |
| `american_ranger` (+ `_winter`, `_29id`, etc.) | head1/head2 | `surface us_helmet` | YES | net-cover shader, still one `us_helmet` surface |
| `american_army_29id` | head2 **and** head7 (both loaded) | `surface us_helmet` | YES | quirk: two head skelmodels; helmet still `us_helmet` |
| `allied_airborne`, `allied_airborne_101st_*`, `allied_airborne_82nd_*` | head1 | **THREE** surfaces: `us_helmet` + `us_helmet_inside` + `bob_helmet_camo` | PARTIAL | must nodraw all three to fully bare-head; iconic look — consider excluding from OFF |
| `allied_sas` | head2 | **none** (bare/beret head only, no helmet skelmodel) | N/A | no `us_helmet` surface; OFF is a no-op (harmless warn), ALT would ADD a helmet |
| British / Russian / Italian / misc allied skins | varies | mostly their own headgear meshes, not always `us_helmet` | varies | UNVERIFIED per-model; treat OFF as "hide `us_helmet` if present" and no-op otherwise |

Key structural evidence (extracted tik `setup` blocks):
- `rifleman.tik`: `skelmodel us_helmet.skd` / `surface us_helmet shader 34th_sniper`; head =
  `skelmodel head2.skd` / `surface head shader 34th_camohead`.
- `riflemannohelm.tik`: identical minus the two `us_helmet` lines → same `head2.skd` underneath.
- `american_army.tik`: `skelmodel us_helmet.skd` / `surface us_helmet shader UShelmet`; head =
  `head1.skd`.
- `allied_airborne.tik`: three stacked helmet surfaces `bob_helmet_camo`, `us_helmet_inside`,
  `us_helmet`; head = `head1.skd`.
- `allied_sas.tik`: no helmet skelmodel at all; head = `head2.skd`.

**Rule for the OFF action:** always issue `self surface us_helmet +nodraw`; additionally, if the
model name contains `airborne`, also `+nodraw` on `us_helmet_inside` and `bob_helmet_camo`. Missing
surfaces just warn and no-op (`entity.cpp:4214-4217`).

---

## (e) HELMET-PIECE INVENTORY (for the ALT-helmet path)

Standalone, attach-able US helmet tiks (all under `main/Pak0.pk3`, `models/equipment/`), each a
`us_helmet.skd` skelmodel + `idle us_helmet.skc`, differing only by shader:

| Tik | Look |
|---|---|
| `ushelmet.tik` | plain private |
| `ushelmet_private_net.tik`, `ushelmet_private_net_cig.tik` | netted private (+ cigarette) |
| `ushelmet_29th.tik`, `ushelmet_29th_net.tik` | 29th ID (plain / netted) |
| `ushelmet_sergeant.tik` | sergeant |
| `ushelmet_captain.tik`, `ushelmet_blank_capt.tik` | captain |
| `ushelmet_ltnt.tik` | lieutenant |
| `ushelmet_medic.tik` | medic (red cross) |
| `ushelmet_engineer01.tik`, `ushelmet_engineer02.tik` | engineer |
| `ushelmet_blank.tik`, `ushelmet_blank_web.tik` | blank / webbed |
| `usgear/helmet_ranger_private.tik` | ranger (note: uses `us_helmetflyoff.skd`) |

Prop-style alternatives (rigid, likely better-behaved as attachments): `models/miscobj/helmet_hand.tik`
(a helmet held in a hand — german), and the `models/static/static_us-helmet_*.tik` set (static
props, no skeleton). German helmets for axis/disguise use: `models/gear/german_*helmet*.tik`,
`models/equipment/germangear/*`.

Because these are all the same skelmodel used *inside* the player composite, the cleanest ALT look
that needs NO alignment work is actually a **texture reskin via the skin-offset bits**:
`self surface us_helmet +skin1` (or `+skin2`) also replicates (same `surfaces[]` byte) and swaps the
helmet's shader skin *if the helmet shader defines skin stages*. Most stock helmet shaders do not,
so this is opportunistic, not guaranteed — flag as an experiment.

---

## (f) v1 IMPLEMENTATION PLAN (smallest shippable: helmet ON/OFF)

Design mirrors the existing lobby skin picker (`lobby.scr::lobbySkinCycle`, `lobby.scr:478-507`),
the emote/cover input bus, and the per-spawn monitor pattern. Server-authoritative; host + remote
safe. **No engine rebuild required for v1** (surface event + name-append bus + `coop_*` cvar
whitelist all already exist).

### State model
Per-player truth lives server-side in `self.flags["coop_helmetOff"]` (0 = helmet on [default],
1 = off). This is the same per-player flag idiom used everywhere (`coop_isActive`, `coop_fov`, …).

### Files to touch (all in `hzm-mohaa-coop-mod/`, ship via `build.ps1`)

1. **`coop_mod/player.scr` — re-apply on every spawn (THE critical hook).**
   `InitModel` wipes the model each spawn (`player.cpp:2607 gi.clearmodel(edict)` then `setModel`),
   so the nodraw must be re-issued. Add a call at the end of `manageAliveSpawning`
   (`player.scr:837-986`, alongside the other per-spawn `thread ...monitor` starts near
   `player.scr:980-985`):
   ```
   thread coop_mod/helmet.scr::helmet_apply local.player
   ```
   `helmet_apply` (new, see file 4) waits one frame for the tiki to settle, then applies the flag.

2. **`coop_mod/variables.scr` — register an input token.** In `getNameAppendCommands`
   (`variables.scr:125-162`, currently ends at index 34) add:
   ```
   local.command["35"]=" ,hm" //[helmet] toggle helmet on/off (data: x)
   ```

3. **`coop_mod/player.scr` — dispatch the token.** In the `playerNameCommand` dispatch chain
   (`player.scr:518-552`, currently ends at index 34) add:
   ```
   else if(local.arrayIndex==35){ local.player thread coop_mod/helmet.scr::helmet_toggle local.player }
   ```

4. **`coop_mod/helmet.scr` — NEW file.** Two entry points:
   ```
   // apply current flag to the live model (called every spawn + after a toggle)
   helmet_apply local.player:{
       if( local.player == NULL ){ end }
       waitframe                                   // let InitModel/setModel finish
       if( local.player == NULL ){ end }
       local.off = local.player.flags["coop_helmetOff"]
       local.mdl = local.player.model              // "models/player/<skin>.tik"
       if( local.off == 1 ){
           local.player surface us_helmet +nodraw
           if( waitthread coop_mod/main.scr::containsText local.mdl "airborne" 0 ){
               local.player surface us_helmet_inside +nodraw
               local.player surface bob_helmet_camo +nodraw
           }
       } else {
           local.player surface us_helmet -nodraw
           local.player surface us_helmet_inside -nodraw
           local.player surface bob_helmet_camo -nodraw
       }
   }end

   helmet_toggle local.player:{
       if( local.player == NULL || !isAlive local.player ){ end }
       if( local.player.flags["coop_helmetOff"] == 1 ){ local.player.flags["coop_helmetOff"] = 0 }
       else { local.player.flags["coop_helmetOff"] = 1 }
       waitthread helmet_apply local.player
       if( local.player.flags["coop_helmetOff"] == 1 ){ local.player iprint "Helmet off" }
       else { local.player iprint "Helmet on" }
   }end
   ```
   (`containsText` is the mod's substring helper, used the same way at `player.scr:114,277`.)

5. **`ui/BIND.SCR` — add a bindable action** (after the emote/cover binds, ~line 54):
   ```
   binditem "Coop: Helmet On/Off"    "append name ,hmx"
   ```

6. **`ui/coop_settings.urc` — add a menu button** that fires the same bus token, so it works without
   a bound key: a button whose command is `append name ,hmx` (mirror how the settings hub routes
   other coop actions). This is the recommended primary UI entry; the bind is the power-user path.

### Cvar bridge / persistence
- The toggle needs **no** cvar for the core effect — the surface change is server-side entityState.
  The name-append bus (`append name ,hmx`) is the MP-safe client→server channel (host + remote),
  identical to emotes/cover (`BIND.SCR:51-57`, dispatch `player.scr:541-544`). Nothing new in the
  servercmd filter is required.
- If you want the choice to survive across the lobby→mission transition and across sessions, add a
  **`coop_*`-named cvar** (auto-whitelisted by the filter at
  `cgame/cg_servercmds_filter.cpp:138`, so `self stufftext "seta coop_helmetOff 1"` reaches the
  client). But because a plain `seta` cvar is archive-not-userinfo, the *server* can't read it back
  next map. Two clean options:
  - **In-mission only (recommended v1):** hold it in `self.flags`, re-apply each spawn. Player
    re-toggles once per mission if desired. Zero persistence complexity.
  - **Carry from the lobby:** set it in the lobby right next to the skin picker and stash it in a
    `game.`-scoped table (the `game.*` scope survives `stuffsrv "map"` transitions the same way the
    lobby carries other state) keyed by a stable id, then seed `self.flags["coop_helmetOff"]` from
    it in `manageSetup`. Defer unless the lobby integration is wanted in v1.

### Optional lobby integration (nice, low-cost)
Add helmet ON/OFF to the lobby the same way skins cycle: a bus token that toggles
`self.flags["coop_helmetOff"]` and re-applies to BOTH the mannequin (`self.flags["coop_lobbyMannequin"]
surface us_helmet +nodraw`) and the hidden real player, mirroring `lobbySkinCycle`
(`lobby.scr:497-504`). Note: re-issue the nodraw after any skin cycle, because
`mann model <new>` reloads the tiki and clears surfaces.

---

## (g) RISKS / CAVEATS / WHAT WON'T WORK

1. **ALT-helmet alignment (the main unknown) — UNVERIFIED.** The standalone `ushelmet_*.tik` are
   full-skeleton `us_helmet.skd` skelmodels, not head-tag props. `attachmodel ... "Bip01 Head"`
   anchors the child's ROOT to the head tag, so the helmet mesh (authored at skeleton origin) will
   likely float above/behind the head and need an `offset` vector + `scale` tune, per model. It also
   won't inherit the wearer's head-bone animation (rigid follow of the tag only). Needs a 15-min
   in-game test before promising a 3-state toggle. The static-prop helmets
   (`models/static/static_us-helmet_*.tik`) may attach more predictably — test those too.
2. **Airborne models** stack three helmet surfaces (`us_helmet`, `us_helmet_inside`,
   `bob_helmet_camo`); OFF must hide all three (handled by the `airborne` name check in
   `helmet_apply`). The camo-net helmet is iconic — consider leaving paratroopers helmeted or making
   OFF just drop the outer net.
3. **SAS / non-US allied skins** have no `us_helmet` surface. OFF is a harmless no-op (engine warns
   "group not found", `entity.cpp:4214`). British/Russian/Italian headgear uses other surface names;
   a universal OFF won't touch them. If per-faction bare-head is wanted, extend the surface-name
   list per model family (UNVERIFIED which names — would need to dump those tiks).
4. **Spawn timing.** `helmet_apply` uses `waitframe` so the surface command lands after
   `InitModel`→`setModel` rebuilds the tiki. Applying too early (same frame as spawn) may hit a
   model that isn't fully loaded. If a `waitframe` proves too short in testing, gate on
   `local.player.model != ""`.
5. **First-person invisibility.** Like the emotes, the wearer sees the change on their own body only
   in 3rd person; the point of the feature is what teammates see, which is exactly the replicated
   path. Not a bug, but set expectations in the UI copy.
6. **Deploy note.** v1 is script + UI only → normal `build.ps1`. No `game.dll`/`cgame.dll`/exe
   change is needed (all three events and the filter whitelist already exist). Only the (unneeded
   for v1) engine-cvar-persistence route would touch a DLL.
7. **`us_helmet` surface index < 32.** Guaranteed for these ~9-surface models; only relevant if a
   future model exceeds 32 surfaces (then high-index surfaces wouldn't replicate — `msg.cpp` caps at
   `surfaces[31]`).

---

## KEY file:line INDEX
- `surface` event: decl `fgame/entity.cpp:739-751`; handler `4290-4302`; core `4199-4288`
  (nodraw mask `4247-4248`, write `4275-4278`); registered on Entity `1585`.
- `attachmodel`: decl `entity.cpp:379-395`; handler `4335-4427`; `attach()` state writes
  `3778-3784`; head tag `"Bip01 Head"` `player.cpp:2655`.
- Replication netfields (`qcommon/msg.cpp`): `surfaces[0..31]` `1380-1478` (repeats `1534-1628`,
  `1688-1786`); `parent` `1356`; `tag_num` `1371`; `attach_use_angles` `1373`; `attach_offset`
  `1397-1399`. `MAX_MODEL_SURFACES 32` `q_shared.h:2026`; `surfaces[32]` `q_shared.h:2092`;
  `MDL_SURFACE_NODRAW (1<<2)` `q_shared.h:2030`.
- Spawn wipe/re-apply: `Player::InitModel` `player.cpp:2596-2709` (`gi.clearmodel` `2607`);
  per-spawn hook `player.scr::manageAliveSpawning` `837-986` (monitor starts `980-985`);
  callbacks fired `891/894`.
- Input bus: registry `variables.scr:125-162`; dispatch `player.scr:518-552`; binds `ui/BIND.SCR`.
- Lobby skin picker to mirror: roster `lobby.scr:57-132`; cycle+persist `lobby.scr:478-507`
  (`self model` + `seta dm_playermodel` `503-504`); mannequin `439-471`.
- Servercmd filter (coop_* auto-allow) `cgame/cg_servercmds_filter.cpp:138`; dm_playermodel/coop
  whitelist `59-60`.
- Model tiks (paks): `zzzzz_geared_soldiers.pk3` (rifleman/…nohelm/submachine/support);
  `zzzzzz-HRRTM_Pak1_Models.pk3` (american_army HD, rangers, airborne, 29id); `Pak0.pk3` (SAS,
  base helmets under `models/equipment/ushelmet_*.tik`).
