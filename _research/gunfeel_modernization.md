# Gunplay / Weight / Movement — what is left to build

Date 2026-08-27. Design-lead ranking, **feel-per-effort**, not ambition. Every item below was
grepped in `openmohaa-hzm/code/` this session and confirmed **absent**; anything that turned out to
be already shipped is in §Corrections at the bottom rather than silently dropped.

Reading the effort column: **XS** ≤2 h, **S** ½ day, **M** 1–2 days, **L** a week+.
"Feel" is honest — three of the ten are rated *small* and say so.

---

## TOP 10

| # | Proposal | Feel | Effort | Binaries | One-line why |
|---|---|---|---|---|---|
| 1 | Hit confirmation on AI | **very high** | S | game.dll + pk3 | Every shot in a PvE campaign currently lands in silence |
| 2 | ADS tightens the cone | **high** | XS | game.dll | The flagship feature buys zoom and nothing mechanical |
| 3 | Per-weapon recoil from the authored `viewkick` data | **highest** | M | game.dll | 657 hand-tuned rows already in the TIKs, driving only the camera |
| 4 | Sprint-out ready-up delay | **high** | XS | game.dll | The visual already plays; the server does not honour it |
| 5 | Stamina regen delay + vault/jump cost | med-high | XS | game.dll | Turns four separate toys into one economy |
| 6 | Airborne-fire penalty | medium | XS | game.dll | A jump-shot is currently the most accurate shot in the game |
| 7 | Footstep↔bob phase lock via `ps.bobCycle` | medium | XS | cgame.dll | The code already names the fix; the clock is already on the wire |
| 8 | Per-gun handling columns on `s_adsGunTune` | **high** | M | cgame.dll | 69 guns share one ADS speed and one per-class recoil weight |
| 9 | Landing recovery window | medium | S | game.dll | Drop-downs are free; they should be a decision |
| 10 | Dynamic spread crosshair | **small alone** | S | cgame.dll | Worthless on its own, but it makes 2/4/6 legible |

### 1. Hit confirmation on AI — feel **very high**, effort **S**

**What.** A short client-local cue on landing a bullet in an actor, plus a distinct crit variant, plus
an optional crosshair pip. **Verified absent:** `CGM_NOTIFY_HIT` is sent from exactly one place —
`fgame/player.cpp:3794`, inside `Player::Damage`, gated on `attacker->client` — so actors never
notify. `dm_hit_notify` is still aliased to `sound/null.wav` (`ubersound/ubersound.scr:1046`).
Today only headshot *kills* have a cue. `docs/DECISIONS.md:124` already flags the null.wav alias.
**Hook.** `fgame/sentient.cpp:1757` — the `coop_headshot` edge inside `ArmorDamage`. `attacker`,
`location`, `meansofdeath` are all in hand; add a generic non-kill branch beside it. This is the
proven choke point (the aihandler 5000-health buffer means `BulletAttack` cannot see real kills).
**Ship.** Audio-only by default (`coop_hitCue 1`); pip behind `coop_hitMark 0` — an X reads arcade,
a leather/flesh thump reads period. Client-local sound costs **zero** `MAX_SOUNDS` indexes
(that pool is at its 11-bit wire ceiling); `S_StartLocalSound` registers into the client's own 4096.
**Risk.** Low. Only risk is taste — some players hate hitmarkers. Hence default audio-only.

### 2. ADS tightens the cone — feel **high**, effort **XS**

**What.** An extension of the shipped stance ladder, not a new system. **Verified absent:** the spread
chain (`fgame/weapon.cpp:1925-2110`) has terms for bloom, brace-bloom, prone/crouch, brace, movement
+settle, breath, stress, zoom and blindfire — and no ADS term. `GetSpreadFactor` (`:5283`) reads
velocity only. `BUTTON_COOPADS` is read server-side in ~16 places, never for spread. Hip-firing an
MG42 standing still is exactly as accurate as aiming it.
**Hook.** `Weapon::Shoot`, beside the existing hold-breath block. **Both copies** (`~:2048` and
`~:2371`) — the file warns twice that patching one works in SP and not MP.
**Ship.** `coop_adsSpread 0.6`. Keep it *weaker* than prone (0.35) so the stance ladder keeps its
order — the same discipline the brace work used. Gate on the *pose factor* rather than the raw
button once item 4 exists, so the bonus arrives as the sights arrive.
**Risk.** Low mechanically, but it is a **combat-balance change** — same class as bug-2106. Cvar-gated.

### 3. Per-weapon recoil from the authored `viewkick` data — feel **highest**, effort **M**

**What.** MOHAA's real recoil model is a **nine-parameter** system EA documented inside the TIKs
(`models/weapons/thompsonsmg.tik:195-221`): pitch min/max, yaw min/max, **recentre speed in
fraction/sec**, **scatter pattern** ("T" = pushes a direction, "V" = cone widening horizontally with
the burst), absolute pitch clamp, absolute yaw clamp, and the pitch at which you **lose all control**.
657 `entry viewkick` rows across 445 weapon TIKs, visibly hand-retuned ("(original)" lines).

**All 657 are in the TIKI *client* block**, so they only move `cg.refdefViewAngles`. Bullets leave
along the server's view angles. Consequences, both verified:
- The camera kicks with a per-gun pattern while the rounds go where the un-kicked view pointed —
  the exact inversion the user already ruled on for stress ("the gun shakes, the crosshair is steady").
- The server path is inert: `EV_Weapon_SetViewKick` is declared `"ffFF"` (`weapon.cpp:763`) so it
  would drop the recentre/pattern/clamps anyway, and no mod TIK declares a server-block viewkick.

So the **only** thing that moves your aim is `Weapon::ApplyFireKickback` (`weapon.cpp:2587`): a flat
`g_adsRecoilKick 0.5°`, pitch only, no yaw, identical for a Colt .45 and an MG42, **accumulating with
no recovery by design** ("it inches up").
**Hook.** Extract the 9 params offline into a generated header (or new columns on the already
substring-matched `s_coopCalibers[]`, `weaputils.cpp:2443`) and drive `ApplyFireKickback` from it:
per-weapon draw, T/V yaw behaviour, recentre toward the pre-burst aim, authored absolute clamps.
**Ship.** `coop_recoilModel 0/1` with the flat kick as fallback, plus `coop_recoilRecenter` — full
recentre plays modern-CoD, zero plays CS-classic. ~120 LOC + extractor. No wire change, no content.
**Defect found while reading** (harmless today, load-bearing the moment this ships) —
`fgame/weapon.cpp:2547` the yaw guard tests the wrong indices:
```c
if (viewkickmin[1][0] != 0.0f || viewkickmax[1][0] != 0.0f) {          // firemode 1, PITCH
    vAngles[1] += random() * (viewkickmax[mode][1] - viewkickmin[mode][1]) + viewkickmin[mode][1];
```
Guard is `[1][0]`, body is `[mode][1]`. Upstream EA/OpenMOHAA bug. Log it.
**Risk.** Medium — this is the balance change on the list. Needs an explicit user go.

### 4. Sprint-out ready-up delay — feel **high**, effort **XS**

**What.** Sprint-to-fire is one of the two or three most load-bearing numbers in modern weapon feel
(CoD ships it per-gun, ~150–350 ms, SMG fastest, LMG slowest). **Verified absent:** the fire strip at
`fgame/player.cpp:5636` is gated on `m_bCoopSprinting` and evaporates the frame you release Shift.
`coop_sprintToFire` (`cgame/cg_view.c:2806`) is explicitly a viewmodel envelope only — the animation
of a recovery the server does not enforce. The gate exists; the transition cost does not.
**Hook.** Persist the existing `current_ucmd->buttons &= ~…` strip for `coop_sprintOut * classWeight`
ms after `m_bCoopSprinting` falls. Reuse the `coop_weaponMoveByClass` weight split (0.98→0.74).
**Risk.** Low. Making the visual and the authority agree is the fix, not a new system.

### 5. Stamina regen delay + vault/jump cost — feel **med-high**, effort **XS**

**What.** **Verified:** `TickSprint` (`player.cpp:15533-15545`) regens the instant `wantSprint` is
false — no delay. The vault (`player.cpp:17310`) costs nothing; the slide already costs 0.55. Hunt's
3 s regen delay is the genre convention and it is what turns stamina from a leash into a rhythm.
**Hook.** One timestamp in `TickSprint`; one subtraction in the vault block.
**Why it ranks here.** It is the single change that makes sprint / slide / vault / breath-hold belong
to **one economy** instead of being four independent toys, and it stops vault-spam without an
arbitrary cooldown. Stamina already feeds the composure scalar at 0.18, so the tell exists.

### 6. Airborne-fire penalty — feel **medium** (fairness high), effort **XS**

**What.** `coop_moveSpread` uses `velocity.lengthXY()` (`weapon.cpp:2011`) — Z deliberately discarded,
for a good reason (a falling player and a glued vehicle rider should not sit at max spread). The
side effect: at the apex of a jump XY speed is low and Z is ignored, so **a jump-shot is the most
accurate shot in the game.** `grep groundEntityNum` in `weapon.cpp` returns nothing.
**Hook.** One branch on `groundEntityNum == ENTITYNUM_NONE` (not on Z velocity — that preserves the
rider/elevator exemptions the current code was written for). **Both fire-path copies.**

### 7. Footstep↔bob phase lock — feel **medium**, effort **XS**

**What.** `cg_view.c:3837` says it outright: the bob is *gait-shaped, not synchronised to the
footstep sound*, and true sync "would need a footstep event on the wire". **It does not.**
`ps.bobCycle` is an 8-bit replicated netfield (`qcommon/msg.cpp:3391`), pmove integrates it
(`bg_pmove.cpp:1167`) and the footstep edge is literally `((old+64) ^ (bobCycle+64)) & 128` at
`:1170`. The client runs the same pmove, so it already holds the exact phase.
**Hook.** Drive `s_stepPh` from `ps.bobCycle` instead of its own private integrator. Both sides then
share one clock and the dip lands on the foot. Honour TRAPS rule 1 — keep integrating, do not
`time * f`. No wire change, no prediction risk.
**Why it matters more than it sounds.** Drifted dip/sound/contact is the whole reason players say
"floaty" without being able to name it. This is the cheapest weight-per-line item on the list.

### 8. Per-gun handling columns on `s_adsGunTune` — feel **high**, effort **M**

**What.** `adsGunTune_t` (`cgame/cg_local.h:533`) is exactly ten floats: standing pitch/yaw/roll/
shiftX/shiftY plus crouch extras. It is a **pose** table. It carries no recoil, no sway, no ADS-in
time, no weight, and no prone row. Everything handling-related is per-**class**: `fClassKick`
(`cg_view.c:1936`), lag weight 0.55→1.5, and a single global ADS ease of **15/s in, 8.5/s out**
(`CG_AdsFactorAdvance`, `cg_view.c:6004`) for all 69 guns.
**Hook.** Add `adsInRate, adsOutRate, kick, kickRecover, swayScale` columns. The lookup
(`CG_FindAdsTune`), the skin-suffix normalisation (`CoopStripSkinSuffix`) and a live in-game
workbench (`cg_adsTune`, `cg_adsMode`, `adssave`) all already exist — this is the cheapest path to
making the armory feel like 69 objects rather than 69 skins, and it gives the loadout/unlock systems
a real stat axis to display. Field band for a rifle ADS-in is **240–280 ms**; measure before dialling.
**Effort is a tuning tail, not code.** The code is a day; hand-dialling 45 guns is the rest.
**User rule from FEATURES.md still applies: a crouch re-bake edits only the 5 crouch fields.**

### 9. Landing recovery window — feel **medium**, effort **S**

**What.** Landing *presentation* is excellent (3 severity tiers, camera absorb spring, weapon dip,
tiered sound). Landing *cost* is stock Q3 fall damage only. On the touchdown frame you can
immediately fire, ADS, sprint or vault. **Verified absent:** no recovery state anywhere.
**Hook.** `fgame/player.cpp:7510` already switches on `EV_FALL_SHORT/MEDIUM/FAR/FATAL`. Gate
`BUTTON_COOPADS` + sprint for `tier * ~120 ms` using the same input-strip pattern as items 4/6.
The client already knows its own severity for the dip, so prediction stays honest.
**Near-free variant worth doing first:** have `EV_FALL_MEDIUM`+ set `m_bCoopWounded` for ~2 s so the
**already-built and already-tuned limp** plays. That is a "twisted your ankle" mechanic for ~6 lines.

### 10. Dynamic spread crosshair — feel **small on its own**, effort **S**

**What.** **Verified absent** — `cg_drawtools.cpp:1480-1530` draws a static shader with
`cg_crosshairSize` and the 3P true-aim reprojection. Nothing reads spread.
**Honest rating.** As a feature by itself: small. As the **readout** for items 2, 4 and 6: it is what
turns three invisible server rules into things the player can learn. Ship it *with* them or not at all.
**Hook.** cgame-only — approximate the cone client-side from state it already holds (velocity,
`PMF_DUCKED`, prone, `CoopBraceEnv`, ADS factor, `CoopWFeelStress`). Do **not** put spread on the
wire for this. Default off (`coop_crosshairDynamic 0`) — it is a modern tell that some will dislike.

---

## Deliberately NOT recommended

- **Bullet drop / projectile rounds.** `MAX_GENTITIES 2048` and this project has a documented weekend
  of entity-pool crashes (bugs 914-927); projectiles are server-only and unpredicted, so a remote
  client sees click→impact latency equal to their RTT. Max weapon range in the trilogy is ~4000 u
  (~100 m) where real drop is inches. Note `tracerspeed` is **not** a travel-time channel — the
  client reads it as alpha (`cg_parsemsg.cpp:1713`).
- **Lag compensation / hit rewind.** Zero infrastructure (`grep unlag|antilag|TimeShift` = nothing).
  Days of work plus a new desync bug class, for a PvE mod. This is a diagnosis, not a feature.
- **Counter-strafe stop-assist.** Directly contradicts a shipped decision: `coop_moveSpreadSettle`
  exists precisely because "stopping instantly accurate … feels like a switch" (`weapon.cpp:1994`).
  Worth recording in DECISIONS.md as rejected-with-reason.
- **Aim punch when hit.** ~20 lines, and wrong for co-op: against AI hordes it compounds into
  unrecoverable death spirals. The receiving-end message already lands via suppression, stress→spread,
  tinnitus, hit flinch and the damage-direction indicator.
- **Weapon jams / malfunctions.** Tarkov's own audience hates random stoppages mid-gunfight. If any
  half is worth it, it is player-weapon *overheat* (the MG42 turret precedent exists) — and even that
  ranks below everything in the table.
- **Foot IK.** Real convention, weak ROI here — first person almost never sees its own feet, so the
  payoff is 3P only, and it needs a per-frame solver inside the skeleton pipeline.
- **Swimming, indoor/outdoor tail *samples*, low-ready carry.** Low content justification, or blocked
  by the same "layer a torso hold over a legs state" impossibility already closed in DECISIONS.md.
- **Anything needing a new `pm_flag`, `stat[]` slot, usercmd button bit, networked viewmodel-anim id,
  or a `MAX_SOUNDS` raise.** All five are provably full. New per-player state should **spend one of
  the 22 free CGM ids** (`bg_public.h:806`, 6-bit type, `CGM_FENCEPOST` = 41) — unreliable,
  snapshot-rate, per-client, game+cgame pair, no exe. That is the right channel above a few Hz;
  change-only stufftext is a reliable-buffer flood risk (bug-1183).

## Large projects — only if you want them

- **Tiered vault / mantle with a real lockout (M–L).** Today's vault is one test and one velocity
  assignment; anything above ~56 u does nothing at all, so an 80 u crate is indistinguishable from a
  wall. Three tiers (18–46 hop, 46–72 pull-over exiting crouched, 72–100 slow climb) with duration
  proportional to height and an input lockout for the duration. The user's own verdict on the current
  one — *"feels more like sliding"* — **is** the missing duration and lockout. Extend the existing
  `coop_vaultView` counter to carry the tier rather than adding a cvar. Biggest movement win here.
- **Real ricochet geometry (M).** The server half is genuinely cheap — the segment loop at
  `weaputils.cpp:3109` already continues with a changed start point, so a grazing-angle test plus a
  reflect is ~30 lines. **The visual half is the blocker:** the tracer wire carries one straight
  segment per pellet, so a bent round draws *through* the wall it bounced off, and the ZING and smoke
  whips derive from that same segment. Budget one CGM id, or do not start.
- **Doors as an interaction (L).** The largest categorical gap — no door code exists anywhere. The
  reduced-scope version is 80% of the read: hold Use to drive an existing `func_door`'s move fraction
  instead of triggering it, so you can crack a door and look. Full CQB (peek/kick/wedge) is a project.
- **Authored animation sets (L, user-gated).** Empty-vs-tactical reload, a true low-ready, a mantle
  set. The `md5_2_skX` pipeline round-trips and is validated; the blocker is the user's own paused
  Blender session, not the engine. **Trap:** notetracks *are* the mechanism — `rifle_prone_shoot` is
  `{ server { first fire } }`; the animation pulls the trigger. Copy the whole block, and remember
  `.st` errors `ERR_DROP` the server on a **listen** boot only (T23 / bug-2099 / bugs 2113-2115).

## Corrections — things I checked and found already present (do NOT build these)

1. **Stair-step eye smoothing exists.** A prior survey called the 18 u step-up an un-smoothed snap.
   `cg_view.c:1563-1586` eases `cg.fCurrentViewHeight` toward `predicted origin[2] + viewheight` at
   12.5/s with a ±32 u clamp and 2× rate airborne — a step-up *is* an origin-Z change, so it goes
   through the same filter as the crouch blend. Tune it if you like; do not rebuild it.
2. **Lean already ramps.** `bg_pmove.cpp:1409-1440` runs `leanSpeed` / `leanAdd` against `leanMax`.
   It does not snap. Analogue (variable-depth) lean is still open; lean *speed* is not.
3. **Wall cover is re-enabled and the peek `setOrigin` is deleted, not disabled** — DECISIONS.md is
   stale there. **Bracing is a `BUTTON_USE` toggle mount**, not automatic, despite the FEATURES.md
   header. **Lean binds shipped** (`autoexec.cfg:90-91`, `ui/BIND.SCR:60-61`).
4. **Penetration is deep already** — per-caliber table, range falloff, SMG wall-punch, and body
   over-penetration is broadly on (244 mod TIKs at `bulletlarge 1`). Do not propose it.
5. **Ricochet *audio*, bullet cracks, distant-fire layer, gun tails, EFX reverb and mechanical foley
   all ship.** The audio stack is the most complete part of the mod. Do not propose "layer the sounds".

## Four rules any viewmodel/camera work must honour

Each already cost a shipped regression (TRAPS "Procedural view/weapon motion", bugs 1983-1985, 2016):
integrate oscillator phase, never `time * f` · never write a periodic term into a state variable an
exponential ease owns · express ceilings in world units, never as a multiple of the thing capped ·
**a deliberately large pose must register in `s_vFeelExempt`** or the 9 u budget silently scales it
and makes its own tuning cvar inert. When the user says "adjusting X does nothing", suspect the clamp.
