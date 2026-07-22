All Phase 1 hooks verified against live code. Notable confirmations and refinements found while checking:

- The kill chokepoint at `aihandler.scr:884` fires **after a `waitframe`** and only when `self.fact.attacker.classname == "Player"` — a clean one-liner insertion point.
- `level.coop_xp_teamkills` (`xp.scr:484`) is gated on `coop_xp_enabled == 1` (`xp.scr:479`) — so the director must keep its **own** counter at the tap, not depend on the XP one.
- `calculateAccuracy` has an **early-out at `aihandler.scr:416-420`**: if anything writes `actor.accuracy` directly it permanently disables further calc for that actor. So an accuracy lever must be injected *inside* the formula (line 434) + re-propagated via `updateEnemyTeamDifficulty` (`aihandler.scr:372`, which exists alongside the self-scoped `updateEnemyDifficulty:363`) — never by poking `actor.accuracy`.
- `coop_officerWaveCooldown` is read fresh every wave call (`officer.scr:1267`) — a zero-new-code pacing lever, and re-usable as the forced relax valve.

Below is the deliverable.

---

# Reactive Difficulty ("AI Director") — Design Plan

**Project:** HZM MOHAA Coop Mod · **New file:** `hzm-mohaa-coop-mod/coop_mod/director.scr` · **Status:** design, not built
**Verified against live code** (all file:line below are real unless marked NEW-CODE).

---

## 1. Goal & philosophy

Keep the squad in the **flow channel** — pushed but winning — by reading how the fight is actually going and quietly nudging pressure up when they're steamrolling, down when they're drowning. Two hard rules borrowed from the DDA precedent (report D):

1. **Invisible.** No HUD, no "difficulty increased" text, no bullet-sponges, no enemy the player is *already watching* suddenly shooting straighter. Every adjustment must read as a plausible WW2 event — "the officer called in more men," "resupply happened to be nearby." The only acceptable tell is atmospheric (an officer bark, more troops arriving off-screen). This is the anti-rubber-band imperative: the moment a player feels the system, trust is gone.
2. **Additive, never a rewrite.** The mod *already* scales enemies by player count — accuracy in `calculateAccuracy` (`aihandler.scr:409`), clone count in `coop_tryDuplicateActor` (`aihandler.scr:160`), officer waves in `coop_reinf_pc` (`officer.scr:1384`), all capped by `level.coop_maxPlayerScalar` (def 4, `variables.scr:95`) and the 80-enemy hard cap `level.coop_aiScaleHardCap` (`variables.scr:98`). The director is a **thin dynamic layer on top of that static baseline.** It must never touch `coop_maxPlayerScalar` (feeds 3 systems) and must respect the 80-cap (enforced at `aihandler.scr:182` and `officer.scr:1414`). **No double-dialing:** pick one lever per effect — don't raise clone-chance *and* officer wave-size for the same "more enemies."

Set-point is biased **slightly toward challenge** (~0.45 on a 0..1 ease scale, see §2), because players report the most fun just below their ceiling — and a strong squad must still be allowed to *stomp sometimes* (don't punish mastery, the Oblivion failure mode).

---

## 2. The performance score — the "Ease Index" (EI)

One smoothed hidden scalar **`level.coop_dda_ei` ∈ [0,1]**: **0 = struggling / near-wipe**, **1 = facerolling**. Steer toward set-point `0.45 + bias`. All signals below are read live on the director's slow tick (§4), normalized to a signed deviation, weighted, summed into a per-tick *pressure*, then EWMA-integrated into EI.

### Signal table

| # | Signal | User's "tell" | Read from (file:line) | Window | Aggregation | Weight | Phase |
|---|---|---|---|---|---|---|---|
| S1 | **Downs/deaths in window** | too-hard: frequent DBNO | NEW-CODE stamp in `dbno_enter` (`dbno.scr:158`) + death path (`player.scr:1203`) | rolling 60 s | team sum, per-active-player normalized | **heavy** (hard side) | 1 |
| S2 | **Time since last down/death** | too-easy: rare deaths | derived from S1 stamp `level.coop_dda_lastDownTime` | since last event | team (single clock) | **heavy** (easy side) | 1 |
| S3 | **Avg team HP fraction** | too-easy: nobody in danger / too-hard: everyone red | `player.health / level.coop_health` (`dbno.scr:80`, `main.scr:381`) | instantaneous → EWMA | **mean** of active non-downed players | medium | 1 |
| S4 | **Kill rate (kills/min)** | too-easy: killing too fast | NEW-CODE own counter at kill tap `aihandler.scr:884` (NOT `coop_xp_teamkills`, XP-gated at `xp.scr:479`) | sample-and-diff each tick over 60 s | team total | light (noisy) | 1 |
| S5 | **Near-wipe** (all active players down/dead at once) | too-hard: wipe | S1 detection + active-count idiom (`xp.scr:437-441`) | instantaneous | team boolean | **SNAP** | 1 |
| S6 | **Objective pace** (time per objective vs par) | too-easy: fast objectives | `chal_primary_done` (`challenges.scr:931`) — **needs NEW per-objective timestamp** + par table | per objective | team | heavy (easy side) | 2 |
| S7 | **Level-push / forward progress** | too-easy: pushing too fast | **NEW** — no live progress tracker exists (`officer.scr:248` measures distance once). Reuse `maptest_waypoints.scr` checkpoints | continuous | team max-advanced | medium | 3 |
| S8 | **Stalled objective** (time since last objective > par timeout) | too-hard: stalled | derived from S6 timestamp | since last obj | team clock | heavy (hard side) | 2 |

### Why these aggregations

- **Hard side (S1, S3, S5): take the MAX-stress player.** Whoever is most in trouble sets the floor (L4D model, report D). One person bleeding out in a corner should ease pressure even if three teammates are fine.
- **Easy side (S2, S3, S4): take the MEAN / team total.** A dominating team means *everyone* is fine; don't let one hero mask a struggling squad, but don't let one straggler hide a steamroll either. Normalize per-active-player using the canonical count loop at `xp.scr:437-441` (`flags["coop_isActive"] == 1`) so thresholds hold from solo to a full lobby.
- **`$player` is 1-indexed, `$player.size` = connected count.** Skip downed players when reading HP — while DBNO, `.health` is force-set to 100/9999 (`dbno.scr:105,127,129`), so gate on `coop_dbno_active == 0 && coop_isActive == 1`.

### Normalization → pressure → EI (per tick)

```
// each signal → signed deviation in [-1,+1], + = "too easy"
dDown  = -clamp( downsInWindow / downPar, 0, 1 )           // hard side, always <= 0
dQuiet =  clamp( (level.time - lastDownTime - quietPar) / quietPar, -1, 1 )
dHP    =  clamp( (avgHPfrac - hpPar) / hpPar, -1, 1 )       // hpPar ~0.6
dKill  =  clamp( (killsPerMin - killPar) / killPar, -1, 1 )

pressure = wQuiet*dQuiet + wHP*dHP + wKill*dKill + wDown*dDown   // wDown large
pressureSmoothed = ewma( pressureSmoothed, pressure, alpha=0.15 )

if ( abs(pressureSmoothed) < deadband )   pressure contributes 0   // §4 band
ei += rateLimit( pressureSmoothed )        // asymmetric, §4
ei = clamp( ei, floor, ceiling )
if ( nearWipe )  ei = floor                 // S5 snap, §4
```

All `*Par`, `w*`, `alpha`, `deadband` are **cvars** (see §6) so the whole curve is tunable without recompiling scripts.

**Phase 1 uses only S1–S5** — all readable today with two one-line stamps. S6–S8 (true objective/spatial pace) require new tracking the mod does not have (report C gaps: `chal_primary_done` records *no* timestamp, no par table, no forward-progress meter) and are deferred.

---

## 3. The adjustment levers

EI → concrete cvar values by **clamped lerp**, each with its own min/max and a per-tick max step (so even a fast EI move can't jerk a lever). Ordered **most-invisible → most-noticeable**; Phase 1 uses only the top group.

| Lever | Cvar / hook (file:line) | Direction | Suggested clamp | Mid-mission safe? | Notes |
|---|---|---|---|---|---|
| **Resupply generosity** (gentlest ease-off) | `coop_healthDropFreq` (`variables.scr:110`), `coop_healthRespawnTime`/`coop_ammoRespawnTime` (`variables.scr:111`) | EI low → drop health more often / respawn faster | freq 5–15, respawn 20–45 s | ✅ read when item taken (`itemhandler.scr:390`) / per axis death (`itemhandler.scr:532`) | RE4 drop-table model (report D). Players *never* read "more ammo appeared" as easing. Use this **before** touching enemy stats. **Phase 2.** |
| **Reinforcement CADENCE** | `coop_officerWaveCooldown` (`officer.scr:1267`, read fresh every call) | EI high → shorter cooldown (relentless); EI low → longer (relax) | **20–75 s** | ✅ pure `setcvar` | THE pacing lever. Verified read-fresh at `officer.scr:1267-1270`. Also the **relax-valley valve** (§4). **Phase 1.** |
| **Reinforcement SIZE** | `coop_officerSquadPer` / `coop_officerBattalionPer` (`officer.scr:1660`, used at 562/1756/1872/2182/2826/3071) | EI high → bigger waves | SquadPer 1–3, BattalionPer 2–5 | ✅ pure `setcvar`, applied per wave in `coop_reinf_count` | Diegetic: "officer called more men." Bounded by 80-cap. **Phase 1.** |
| **Ambient spawn density** | `coop_aiScaleChance` (`aihandler.scr:164`) / gate `coop_aiScale` (`aihandler.scr:139`) | EI high → higher clone chance | 30–75 | ✅ `setcvar`, **future spawns only** | Only bites at 2+ players (or `coop_aiScaleTest`, `aihandler.scr:144`). Invisible (off-screen replicas). **Phase 1.** |
| **AI accuracy** | NEW-CODE factor inside `calculateAccuracy` at `aihandler.scr:434`, reading `coop_ddaAccBonus`; re-propagate via `updateEnemyTeamDifficulty` (`aihandler.scr:372`) | EI high → +accuracy | **±10 %** only | ⚠️ new spawns preferred | **Must not** write `actor.accuracy` directly — the early-out at `aihandler.scr:416-420` will permanently disable calc for that actor. Living-actor changes are semi-visible; keep the swing tiny. **Phase 2.** |
| **Enemy HP** | NEW-CODE `coop_ddaHealthMult` inside `initialisePainVars` scaling `coop_actorActualHealth` before the 700 clamp (`aihandler.scr:479`) | EI high → tougher | **±15 %**, new spawns only | ⚠️ | Bullet-sponge = the #1 trust-killer (report D). Smallest clamp, **Phase 3**, only after smoothing is proven. |

### Levers that must NOT be dialed

- **Player max HP `coop_health`** (`main.scr:381`). Raising it mid-life does nothing until respawn/medkit, and player-side fudging is the most "cheaty"-feeling change. Leave it fixed.
- **DBNO on/off, LMS lives** (`dbno.scr:43,268`) — too coarse and player-facing.
- **Living enemies the players are watching** — never retro-buff HP/accuracy on an actor already in a firefight. Enemy-stat levers touch **new spawns only** (rubber-band rule, report D).
- **`coop_maxPlayerScalar`** — feeds accuracy + cloner + all officer sizing at once; moving it is a triple double-dial.

---

## 4. The feedback loop

- **Cadence:** slow tick every **`coop_ddaCadence` s (default 10)**, in the 5–15 s band. A new self-perpetuating thread `director_main` in `director.scr`. **Started from `main.scr::main` with `thread` (fire-and-forget)** — `wait`/`waitframe` are forbidden in `main.scr::main` (single-frame init, per CLAUDE.md), so the loop's `wait`s live *inside* the spawned thread, not in `main`. Gate on `level.coop_mainScriptLoaded` and `coop_ddaEnabled`.
- **Smoothing:** EWMA of each signal and of the combined pressure, `alpha ≈ 0.15` (`coop_ddaSmooth`). Kills yo-yo from noisy per-second swings.
- **Deadband:** `coop_ddaBand` (default 0.1). If |smoothed pressure| < band, EI does not move. Small fluctuations do nothing.
- **Hysteresis:** require a larger move to *reverse* EI direction than to continue it (e.g. reversal needs 1.5× band). Prevents twitchy flip-flopping.
- **Asymmetric rate-limit (death-spiral guard):** EI may **fall fast** (ease off) — up to `coop_ddaEaseRate` (0.15/tick) — but **rise slow** (ramp up) — up to `coop_ddaRampRate` (0.05/tick), a 3:1 asymmetry (report D). React quickly and generously to trouble; ramp back cautiously.
- **Snap-down on wipe/multi-down (S5):** if all active players are down/dead in one tick, or ≥2 downs land inside the window, **snap EI to floor** and open a **forced relax valley for 30–45 s** (`coop_ddaValley`, L4D model). Cheapest implementation reuses the existing throttle: temporarily `setcvar coop_officerWaveCooldown <valley>` and `coop_aiScaleChance 0`, so the officer's own gate at `officer.scr:1272` suppresses waves for free — no new suppression code.
- **Floor & ceiling:** EI clamped to `[coop_ddaFloor 0.15, coop_ddaCeiling 0.85]`. A struggling team is never crushed into an unwinnable state; a dominating team always faces a *real* fight (never trivial). Per-lever min/max in §3 double-bound this.
- **Map transitions (per-map reset for v1):** level vars reset every map (`variables.scr`, `main.scr` — confirmed across reports A/B/C). Re-seed `ei = 0.5 + coop_ddaBias` and zero the counters at map load (in `director_main` init, keyed off `level.coop_mapname` like `challenges.scr:795`). Reset counters: `coop_dda_kills`, `coop_dda_downs`, `coop_dda_lastDownTime`. **Phase 3 option:** persist a campaign skill estimate in a cvar `coop_ddaSkill`, updated at `chal_mission_complete` (`challenges.scr:1172`, the one reliably-wired map-done hook) from the map's closing EI, and use it to seed EI0 next map. Per-map reset is safer for v1 (no compounding into an unfair/trivial baseline).

**Anchor note:** use `level.coop_gameStartedAt` (`main.scr:275`, first player active — verified) as the elapsed denominator, **not** `level.coop_mapStartTime` (`variables.scr:67`) which includes lobby/ready dwell.

---

## 5. Safety & feel

- **Invisibility:** no HUD element, no `iprintlnbold` about difficulty (reserve it for genuine events, per report D). The only player-facing signal is the *existing* diegetic one — the officer's radio bark in `coop_call_reinforcements` (`officer.scr:1273`) and more troops arriving from existing off-screen spawn points. Ramp = "the enemy reinforced," ease = "reinforcements thinned and there's ammo nearby."
- **Don't punish good play cheaply:** ceiling caps how hard a dominating squad can be pushed (they get to win). Reserve real ramp for pace/kill-rate *far* above par (deadband + slow ramp), not merely above it. Bias the channel slightly toward the player so success still feels rewarded.
- **Anti-gaming (RE4 suicide-before-boss exploit):** weight deaths/downs on the *ease-off* side but weight **pace/kill-rate more on the ramp side** — pace is hard to fake without actually playing well. Clamp how fast and how low EI can drop (floor). This risk is low for a small cooperative community but the asymmetric rate-limit already blunts it.
- **Opt-out & bias cvars:** `coop_ddaEnabled` (default **0** during rollout, flip to 1 once proven) fully disables the thread → levers hold at their count-scaled defaults, so the director is purely additive and removable. `coop_ddaBias ∈ [-1,+1]` (host-only) shifts set-point + floor/ceiling center for hosts who want a harder/easier baseline. Optionally surface both in the existing coop settings menu (`ui/coop_settings.urc`).
- **Coexistence:**
  - *Count-scaling (`aihandler.scr`)* stays the static baseline; the director only nudges the per-wave/per-spawn cvars, so the 80 hard cap (`aihandler.scr:182`, `officer.scr:1414`) still bounds everything.
  - *Officer waves (`officer.scr`)* are the director's primary diegetic actuator — sizing (`coop_officer*Per`) and cadence (`coop_officerWaveCooldown`) are exactly the two knobs it drives.
  - *Wounded-limp (`wounded.scr:37`)* already thins low-HP enemies (a natural ease-off). The director should not fight it; note that raising EI mildly counteracts limp-away attrition — acceptable, just don't stack an accuracy/HP ramp on top of a wave-size ramp at the same time.

---

## 6. Phased build plan

### Phase 1 — smallest shippable (script-only, 2 one-liners + 1 new file)

**Signals:** S1 downs/deaths, S2 time-since-down, S3 avg HP fraction, S4 kill-rate, S5 wipe-snap.
**Levers:** `coop_officerWaveCooldown` (cadence) + `coop_officerSquadPer`/`coop_officerBattalionPer` (size) + `coop_aiScaleChance` (density). **All pure `setcvar` into code that already reads them fresh** — zero engine edits, no accuracy/HP edits.

**New file:** `hzm-mohaa-coop-mod/coop_mod/director.scr`
- `director_main` — spawned via `thread coop_mod/director.scr::director_main` from `main.scr::main` after `level.coop_mainScriptLoaded`. Per-map init (reset EI + counters keyed off `level.coop_mapname`), then a `while(1){ ... wait coop_ddaCadence }` tick loop.
- `director_tick` — read S1–S5, compute pressure, EWMA, deadband, asymmetric rate-limit, wipe-snap, clamp EI, lerp EI→the 4 cvars with per-lever clamps + max-step, `setcvar`.

**Exact hooks to touch (2 one-liners):**
1. `aihandler.scr:884` — inside the `self.fact.attacker.classname == "Player"` block, add `if(level.coop_dda_kills==NIL){level.coop_dda_kills=0}; level.coop_dda_kills++`. (Own counter — independent of XP being enabled.)
2. `dbno.scr:158` — where `coop_dbno_active` is set, add `level.coop_dda_lastDownTime = level.time; if(level.coop_dda_downs==NIL){level.coop_dda_downs=0}; level.coop_dda_downs++`. (Optionally mirror at the true-death stamp `player.scr:1203`.)

**New cvars:** `coop_ddaEnabled` (0), `coop_ddaBias` (0), `coop_ddaFloor` (0.15), `coop_ddaCeiling` (0.85), `coop_ddaCadence` (10), `coop_ddaSmooth` (0.15), `coop_ddaBand` (0.1), `coop_ddaEaseRate` (0.15), `coop_ddaRampRate` (0.05), `coop_ddaValley` (40), plus par seeds `coop_ddaKillPar`, `coop_ddaHpPar` (0.6), `coop_ddaQuietPar`, `coop_ddaDownPar`, and lever clamps `coop_ddaCooldownMin/Max`.

**Testable:** with `coop_ddaEnabled 1` and a debug `iprintln` of EI + the four cvar outputs (dev-only, gated like `level.cMTE_*`), verify EI climbs when a solo `coop_aiScaleTest 1` host farms kills untouched, and snaps to floor on a forced DBNO. Confirm wave cadence/size cvars visibly change via `seta`-echo, and that the 80-cap still holds.

### Phase 2 — pacing & gentle ease-off

- **Wire objective completion (S6/S8):** in `chal_primary_done` (`challenges.scr:931`, the single funnel — but note the coverage caveat at `challenges.scr:949-950`: SH/BT `t*/e*` and Omaha maps don't all route through `global/objectives.scr::add_objectives:46`) add `level.coop_dda_objDoneT[index] = level.time` + a running completed-count. Derive time-per-objective and a stall timer.
- **Seed a per-map par table** from the two existing par-times (`challenges.scr:957` m3l1a<90 s, `challenges.scr:1207` m4l2<300 s) and expand.
- **Add the resupply-generosity ease-off lever** (`coop_healthDropFreq`, `coop_health/ammoRespawnTime`) — the gentlest, least-detectable easing, applied when EI is low.
- **Add the AI-accuracy lever** — NEW factor inside `calculateAccuracy` at `aihandler.scr:434` reading `coop_ddaAccBonus` (±10 %), re-propagated with `updateEnemyTeamDifficulty` (`aihandler.scr:372`). Handle the early-out (`aihandler.scr:416-420`) by injecting inside the formula, never writing `actor.accuracy`.

### Phase 3 — full two-clock + persistence

- **Fast intensity clock (L4D leaky integrator):** per-player recent-damage/under-fire meter (reuse `coop_dbno_cumulative`, `dbno.scr:92-104`) driving *burst sizing* and mandatory relax valleys, layered under the slow EI clock.
- **Spatial forward-progress signal (S7):** reuse `maptest_waypoints.scr` (32 checkpoints/map) + `level.coop_mapStartOrigin` (`officer.scr:248`) for a "% through map / pushing too fast" meter.
- **Enemy-HP lever** (`coop_ddaHealthMult` in `initialisePainVars`, `aihandler.scr:479`, ±15 %, new spawns).
- **Campaign-persistent skill estimate** `coop_ddaSkill`, updated at `chal_mission_complete` (`challenges.scr:1172`), seeding EI0 next map.

---

## 7. Open questions for the user

1. **Aggressiveness / spread.** How wide should the swings be? Proposed seeds: wave cadence 20–75 s, SquadPer 1–3, accuracy ±10 %, HP ±15 %. Wider = more felt, narrower = safer. Needs playtest, not a guess.
2. **Per-map reset vs campaign-persistent skill.** Recommend per-map reset for v1 (simpler, no compounding). Persist across the campaign later? (Phase 3 `coop_ddaSkill`.)
3. **Set-point bias.** Aim dead-center (challenge==skill) or biased slightly hard ("enjoyably challenged")? Default proposed 0.45.
4. **Anti-gaming weight on deaths.** Trust the small co-op community and prioritize responsiveness, or deliberately weight deaths weakly so a team can't farm easiness by dying before a fight?
5. **Diegetic tell level.** Fully silent, or allow the existing officer "calling reinforcements" bark (`officer.scr:1273`) to fire more when ramping as narrative cover?
6. **Default `coop_ddaEnabled` at ship.** Recommend **0** (off) for first release so it can be A/B'd, flipped on once smoothing is proven. Confirm.
7. **v1 lever set.** Recommend Phase 1 = cadence + reinforcement size + spawn density only (all pure `setcvar`, no bullet-sponge risk). Confirm before adding accuracy/HP.
8. **Objective-pace authoring (Phase 2).** Willing to author per-map par times (time-to-objective / expected duration)? This is the main content cost; only two par-times exist today.

**Files that will be created/edited:** new `C:\mohaa-coop-dev\hzm-mohaa-coop-mod\coop_mod\director.scr`; Phase-1 one-liners in `C:\mohaa-coop-dev\hzm-mohaa-coop-mod\coop_mod\aihandler.scr` (line 884) and `C:\mohaa-coop-dev\hzm-mohaa-coop-mod\coop_mod\dbno.scr` (line 158); thread launch added to `C:\mohaa-coop-dev\hzm-mohaa-coop-mod\coop_mod\main.scr::main`.