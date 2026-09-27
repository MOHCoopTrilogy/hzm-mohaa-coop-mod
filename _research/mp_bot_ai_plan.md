# MP Bot AI Overhaul - vetted plan (workflow wf_e3f1cf8b-d2f, 2026-09-17)

Phase 1 (perception cones + fire gate) + Phase 2 (objective scatter) SHIPPED 2026-09-17.
Phases 3-6 pending. Vetting defects for those still to apply (see verdicts below).

## DESIGN

I have the exact isolation mechanics and cvar patterns confirmed. Here is the plan.

---

# HZM MP-Bot Intelligence Overhaul — Phased, Coop-Safe Implementation Plan

## 0. The finding that shapes everything

**No new engine signal is needed for hearing or for reacting to being shot.** Both channels already reach the bot brain today and are simply under-used:

- `Weapon::Fire → G_BroadcastAIEvent(AI_EVENT_WEAPON_FIRE) → botManager.BroadcastEvent (g_utils.cpp:1851) → BotController::NoticeEvent (playerbot.cpp:397)`. The "a player fired near me" signal is already delivered per-bot with shooter entity, position, type, and radius falloff.
- Being shot already reaches the bot: `Sentient::ArmorDamage → delegate_damage.Execute → BotController::Pain (playerbot.cpp:1319, subscribed :1438)`, with `ev.GetEntity(1)` = attacker.

So **~90% of this work is C++ tuning inside the `BotController` / `BotMovement` / `BotRotation` surface plus one script-side bot director** — no shared-code edits, therefore coop-safe by construction. The remaining requirement ("how to add a NEW signal isolation-safely") is addressed as a template in §2, but the plan deliberately never invokes it, because the signals we need already exist bot-side.

**Cvar naming decision (load-bearing for isolation).** All new host cvars use the existing `bot_*` prefix (`bot_botcover`, `bot_manualmove` at `playerbot.cpp:40,1094`). `bot_*` is **not** a `coop_mp*` token, so it never trips `check_mp_isolation.py` clause 14 (no HZM-MP hook required for pure `bot_*` cvar reads), and it is **not** a `coop_` name, so it can never collide with `SAVED_COOP_CVARS` (clause 4) or the `coop_lo*`/`coop_compassBar*` bans (clauses 12/15). This is strictly safer than the `coop_mp*` naming the coop-safety brief suggested, and needs no registry edit. I flag the one case that *would* need a hook in §2.

---

## 1. Coop-safety contract — invariant across all phases

Every phase honors all of these; a phase that cannot is not shipped.

**FROZEN — do not edit for bot work (shared with coop `Actor` AI):**
1. `Sentient::CanSee` and `Actor::CanSee` (`actor.cpp:4270`), all of `actor*.cpp`, `sentient*.cpp`, `simpleactor.cpp`, `sentient_combat.cpp`. Tune bot sight only by passing different `fov`/`distance` **arguments** at the bot's call sites.
2. `G_AIEventRadius` + the AI_EVENT radius table (`g_utils.cpp:1769`) and the **Actor arm** of `G_BroadcastAIEvent` (`g_utils.cpp:1814–1849`). Never retune hearing here — it changes what coop enemies hear.
3. The shared AI-event **emitters**: `Sentient` footstep (`sentient.cpp:5975/5996`), `Weapon::Fire` (`weapon.cpp:2611+`). Do not make bots "louder" here.
4. The `.Execute()` sites and **argument order** of `delegate_damage/_killed/_gotKill` (`sentient.cpp:2144/2161/2183`). Bot code may `.Add()`/`.Remove()` its own callbacks (already does, `playerbot.cpp:1436–1441/:88`) but must not move these sites.
5. `SentientList` is read-only from bot code (bot reads a copy, `playerbot.cpp:827`).
6. **`Actor` coop actor.cpp is untouched, entirely.**

**MAY edit freely (MP-bot-only surface, never instantiated in coop):**
`playerbot.cpp`, `playerbot_movement.cpp`, `playerbot_rotation.cpp`, `playerbot_master.cpp` (the `BroadcastEvent` arm only), `playerbot_strategy.*`, `g_bot.cpp`; plus MP-only scripts under `coop_mod/mp*.scr`.

**Primary coop guard (structural, not cvar-based):** No `BotController` is ever instantiated on a coop server — `G_SpawnBots` fires only when `sv_numbots/sv_minPlayers > 0`, and those are set **only** from `coop_mod/mp_bots.scr` behind the `mp.scr:46` coop-refusal clause. Coop runs with them at 0, so `Think()`/`NoticeEvent`/`State_Attack` never execute. **Therefore the `bot_*` master cvars below are for live tuning/rollback and A-B testing, NOT the coop firewall** — the firewall is "no BotController exists." No phase may add a code path that runs bot logic off a bare `g_gametype` test (that would fire in coop's gametype 2).

**Regression proof, run after every phase:**
- `python docs/tools/check_mp_isolation.py` → exit 0; `check_mp_isolation_selftest.py` green (both gate `build.ps1`).
- **Engine-build hazard (already in buglog, 2 refs):** delete/relocate the three globbed `.bak` files (`player.cpp.bak_botinput`, `player.cpp.pre_0905lanes_bak`, `weapturret.cpp.pre_0905lanes_bak`) out of `code/fgame/` before the cmake reconfigure, or the `GLOB_RECURSE ./*.c*` in `CMakeLists.txt` pulls them in → duplicate-symbol link errors.
- Coop unchanged: `exec coop_mod/cfg/maptest_start.cfg` (Phase-2 patrol, 54 maps) with `sv_numbots 0`; confirm `^~^~^` parse lines and AI behavior identical to a pre-change baseline capture.
- Bots verified separately on an MP server (`sv_maxbots`/`sv_numbots > 0`). The two never coexist in one session.

---

## 2. New-signal isolation template (used by zero phases, provided per the task)

If a future need arises for a signal that requires naming a `coop_mp*` cvar or an `mp*.scr` path **in engine code** (e.g. reading a script-authored objective table by its `coop_mp*` cvar name), it must sit in a declared hook:

```cpp
// HZM-MP-BEGIN(botobj_read)
cvar_t *pObjTable = gi.Cvar_Get("coop_mpBotObjData", "", 0);   // coop_mp* token → must be hooked
// ... parse MP objective state ...
// HZM-MP-END(botobj_read)
```

and register it on the single `ENGINE_MP_HOOKS` line in `check_mp_isolation.py:130`:
```python
ENGINE_MP_HOOKS = { ..., "botobj_read": "bot reads the MP objective table cvar set by mp_botobj.scr" }
```
Rules the checker enforces (clause 14a–g): blocks don't nest, names are unique and registered, no `coop_lo*`/`ui/loadout/` inside, and **every** `coop_mp*` token or `mp*.scr`/`mp*.cfg` path in engine code lives inside such a block. **This plan avoids the situation entirely** by (a) using `bot_*` cvars for all tuning and (b) passing objective data to bots through the existing `AttractiveNode` mechanism (which the movement code already consumes with no `coop_mp*` string in C++), so no engine hook is ever required.

---

## 3. New host cvars (complete set, all `bot_*`, all `CVAR_ARCHIVE`)

| Cvar | Default | Phase | Effect |
|---|---|---|---|
| `bot_perception` | `1` | 1 | Master for graded sight cones + fire-gate unfreeze; `0` = stock 80/20 cones |
| `bot_fov_acquire` | `150` | 1 | Full-cone acquisition FOV (deg) at close range |
| `bot_fov_acquire_far` | `90` | 1 | Full-cone acquisition FOV (deg) at max range (inverse-distance lobe) |
| `bot_fov_fire` | `45` | 1 | Full-cone firing FOV (deg) |
| `bot_hearing` | `1` | 3 | Master for gunfire/impact reactions in `NoticeEvent` |
| `bot_hearing_react` | `1` | 3 | 0 = investigate-only (stock), 1 = pre-aim + shorten reaction on heard fire |
| `bot_flankreact` | `1` | 3 | Soften Pain early-return + snap-aim at shot source |
| `bot_objective_spread` | `128` | 2 | Radius (u) each bot scatters around a shared objective node |
| `bot_nav_reroute` | `1` | 4 | Reroute/relax-radius before terminal give-up; validate goals |
| `bot_nav_stucktimeout` | `500` | 4 | ms short-window progress watchdog; **0 = disabled, not clamped** (botnav footgun) |
| `bot_combat_realism` | `1` | 5 | Dynamic-accuracy delay + aim convergence + suppression |
| `bot_squadroles` | `1` | 6 | Enables script bot-director role/quota assignment |

Each is registered the way `bot_botcover` is (`static cvar_t *x = NULL; if(!x) x = gi.Cvar_Get("x", "def", CVAR_ARCHIVE);`) at first use inside the relevant bot function. `bot_squadroles` is read in the MP script, not engine.

---

## PHASE 1 — Perception cones + fire-gate unfreeze (symptom 1: "bots must look directly at me")

**Value: highest (fixes the most-felt bug). Risk: low.** Pure argument changes at two call sites plus one gate relax.

**File:** `openmohaa-hzm/code/fgame/playerbot.cpp`

**1a. Graded acquisition FOV — `CheckCondition_Attack` (:825, cone at :842).**
Replace the fixed `CanSee(sent, 80, maxDistance, false)` with an inverse-distance cone (The Last of Us / Splinter Cell "coffin" pattern: wide up close, narrow at range):
```cpp
// HZM: graded acquisition cone, MP-bot-only. bot_perception gates back to stock 80.
float fFovAcq = 80.0f;
if (bot_perception->integer) {
    float d = sqrt(fDistanceSquared);
    float t = Q_min(1.0f, d / maxDistance);
    fFovAcq = bot_fov_acquire->value + t * (bot_fov_acquire_far->value - bot_fov_acquire->value);
}
if (controlledEnt->CanSee(sent, fFovAcq, maxDistance, false)) { ... }
```
Defaults 150→90 give ±75° peripheral acquisition up close, ±45° at 2048u. `CanSee`'s cone is horizontal-only against body forward (`entity.cpp:2962/2972`), unchanged.

**1b. Firing FOV — `State_Attack` (:900).** Widen the punishing ±10° cone:
```cpp
float fFovFire = bot_perception->integer ? bot_fov_fire->value : 20.0f;   // 45 → ±22.5°
bCanSee = controlledEnt->CanSee(m_pEnemy, fFovFire, Q_min(world->m_fAIVisionDistance, world->farplane_distance*0.828), false);
```

**1c. Fix the "crouched, facing me, never fired" freeze — semi-auto spread gate (:962–981).** Today a settling/moving bot with `fSpreadFactor >= 0.25` just `ClearMove()`s and never fires. Change: when the bot cannot meet the spread threshold, **stop and settle, then fire** rather than perpetually holding. Add a settle timer:
```cpp
if (bot_perception->integer) {
    if (fSpreadFactor >= 0.25f) {
        bNoMove = true; ClearMove();                 // settle
        if (level.inttime - m_iSteadyStartTime > 350) // but fire after 350ms of settling
            /* allow trigger */ ;
        else m_iSteadyStartTime = m_iSteadyStartTime ? m_iSteadyStartTime : level.inttime;
    } else { m_iSteadyStartTime = 0; /* fire normally */ }
}
```
Also guard the viewmodel-anim gate (:962) so a bot that finished its ready anim isn't stuck holding fire indefinitely. `m_iSteadyStartTime` is a new `int` field on `BotController`, reset in `State_Reset` (:561).

**Gating:** all behind `bot_perception`; `0` restores exact stock 80/20 + hard spread gate.
**Coop-safety:** only `CanSee` *arguments* change; `Sentient::CanSee` untouched. `BotController` never runs in coop.
**Playtest:** MP server, `sv_numbots 4`. Toggle `bot_perception 0/1`; confirm bots engage from the side and a bot facing you always eventually fires. Verify a `world->m_fAIVisionDistance`-short map (e.g. foggy) isn't the real blocker before blaming FOV.

---

## PHASE 2 — Objective goal-spread + arrival (symptom 3: bots clump and block each other)

**Value: high (the biggest nav problem, and it *is* why "playing objectives" looks broken). Risk: low.** No `dtCrowd` needed.

**File:** `openmohaa-hzm/code/fgame/playerbot_movement.cpp`, `MoveToBestAttractivePoint` (:621–711, change at :705).

Root cause: every bot does `MoveTo(bestNode->origin)` — the identical coordinate, 16u arrival — so N bots pile into one 16u bubble. Fix: scatter each bot to a distinct navmesh-valid point in a ring, reusing the existing `FindPathNear`/`findRandomPointAroundCircle` primitive (`navigation_recast_path.cpp:140`):
```cpp
// HZM: scatter bots around the objective instead of stacking on one origin.
if (bot_objective_spread->value > 0.0f && bestNode->m_vSpread /*per-node flag*/) {
    if (m_vAttractOffsetNode != bestNode) {          // roll once per node, not per frame
        m_vAttractOffsetNode = bestNode;
        MoveNear(bestNode->origin, bot_objective_spread->value);   // FindPathNear → random reachable poly in radius
    }
} else {
    MoveTo(bestNode->origin);
}
```
Persist `m_vAttractOffsetNode` (a `SafePtr` on `BotMovement`) so the offset doesn't re-roll every frame (which would jitter). The existing 16u arrival then means "reached *my* spot," not "reached *the* point" — the two compose. Dwell (`m_fMaxStayTime` / node `stay_time`) already holds bots on the point afterward, so they hold the objective spread out instead of grinding.

**Optional script variant (no engine build):** in `hzm-mohaa-coop-mod/coop_mod/mp_botobj.scr` (:28–45), spawn several `hzm_attractnode` per objective slot at offset origins instead of one. Useful as a stopgap or per-map tuning; the engine fix is preferred because it's automatic and per-bot.

**Gating:** `bot_objective_spread 0` = stock single-point behavior.
**Coop-safety:** `mp_botobj.scr` nodes are gated on `level.coop_mpRun` (never set on a coop map); `MoveToBestAttractivePoint` only runs from a `BotMovement`, which coop never instantiates. `actor.cpp` never reads `attractiveNodes`.
**Playtest:** MP objective map, `sv_numbots 6`. Watch bots on a flag/bomb node — should fan out to a ring, not stack; toggle `bot_objective_spread 0` to see the regression.

---

## PHASE 3 — Realistic hearing + flank response (symptom 4 + "hear/engage realistically")

**Value: high. Risk: low-medium.** All inside two bot-only functions; no shared code.

**File:** `openmohaa-hzm/code/fgame/playerbot.cpp`

**3a. Act on gunfire — `NoticeEvent` (:397–470).** Today every event type just sets 20s curiosity. Add reaction by type (all data already delivered):
```cpp
// HZM: bot_hearing gates reactive hearing; 0 = stock curiosity-only.
if (bot_hearing->integer) {
  switch (iType) {
    case AI_EVENT_WEAPON_FIRE:
    case AI_EVENT_WEAPON_IMPACT:
      if (bot_hearing_react->integer) {
        // Bypass the probabilistic drop for gunfire — you always notice being shot at.
        if (owner && IsValidEnemy(owner) && controlledEnt->CanSee(owner, bot_fov_fire->value, maxDist, false)) {
          m_pEnemy = owner; m_vLastEnemyPos = owner->origin;   // shot at with LOS → engage now
        } else {
          m_vLastEnemyPos = vPos;                              // no LOS → face + peek, don't run onto the sound
          m_iAttackStopAimTime = level.inttime + 1500;         // orient toward the back-azimuth
          m_iLastUnseenTime = 0;                               // shorten next reaction (awareness)
        }
      }
      break;
    case AI_EVENT_EXPLOSION:
    case AI_EVENT_GRENADE:  /* if close → AvoidPath(vPos); else investigate */  break;
    case AI_EVENT_FOOTSTEP: /* low weight: orient only, keep probabilistic drop */ break;
  }
}
```
**Also fix the fixation bug (best-practice finding):** the current nearest/farthest early-out keeps the bot locked on a *farther* prior sound and ignores a *closer* new threat — invert so nearest/newest wins. And **bypass the `fRangeFactor < random()` drop** (:411) for `WEAPON_FIRE`/`EXPLOSION` only (keep it for footsteps).

**3b. Flank response — soften Pain + snap-aim (fixes the "shot from behind, no reaction" half-measure).**
- `Pain` (:1319–1355): the `if (m_pEnemy && IsValidEnemy(m_pEnemy)) return;` at :1347 swallows most flank shots because `m_pEnemy` is sticky. Replace with a switch-if-better rule, gated by `bot_flankreact`:
```cpp
if (m_pEnemy && IsValidEnemy(m_pEnemy)) {
    bool bCurUnseen = (m_iLastUnseenTime != 0);
    float dNew = (ev.GetEntity(1)->origin - controlledEnt->origin).lengthSquared();
    float dCur = (m_pEnemy->origin - controlledEnt->origin).lengthSquared();
    if (!bot_flankreact->integer || (!bCurUnseen && dCur <= dNew)) return;  // keep current only if seen & closer
}
```
- `State_Attack` aim path (:1081–1083): when `bCanSee==false`, aim at `m_vLastEnemyPos` if `m_iLastPainTime` is recent (extend `m_iAttackStopAimTime` on pain), instead of `AimAtAimNode()` (which faces the movement path). This makes the bot *turn to face* the shooter, bounded by the normal `TurnThink` rate so it's a fast swing, not an aimbot snap.

**Gating:** `bot_hearing 0` = stock curiosity; `bot_flankreact 0` = stock sticky-enemy Pain.
**Coop-safety:** `NoticeEvent`/`Pain` are `BotController` methods bound only to bot-controlled Players (`:1438`); the `G_AIEventRadius` table, `BroadcastAIEvent` emitters, and the Actor arm are untouched. Teammate/self filter in `NoticeEvent` (:443) and `IsValidEnemy` team gate (:743) preserved.
**Playtest:** MP, stand out of a bot's cone and fire — it should orient and engage; shoot a bot in the back while it fights someone else — it should turn on you if you're closer/its current target is unseen.

---

## PHASE 4 — Never-stuck: reroute before give-up + goal validation (symptom 2)

**Value: high. Risk: medium.** The stuck-detector exists (`MoveThink:128–202`); we make it re-route instead of quitting, and stop feeding it unreachable goals.

**File:** `openmohaa-hzm/code/fgame/playerbot_movement.cpp`

**4a. Reroute before terminal give-up (:133–136).** Today `m_iNumBlocks >= 5 → ClearMove()`, the state re-issues the same unreachable goal, and the cycle repeats. Insert an escalating alternate-path attempt on blocks 2–4, gated by `bot_nav_reroute`:
```cpp
if (bot_nav_reroute->integer && m_iNumBlocks >= 2 && m_iNumBlocks < 5) {
    // ask Detour for a different corridor: accept a nearby reachable poly
    MoveNear(m_vFinalGoal, 128.0f + 64.0f * m_iNumBlocks);   // FindPathNear grows the accept radius
}
```
Only after alternates also fail does it abandon (existing :133). Store `m_vFinalGoal` when a state issues `MoveTo`.

**4b. Validate goals before use.** In `MoveTo` (:588) and at the `State_Attack` `MoveTo(m_vLastEnemyPos)` sites (`playerbot.cpp:1130`), gate the raw world point through `TestPath`/`CanMoveTo` (already available, `playerbot_movement.cpp:975`); if it fails, fall back to the last reachable node rather than pathing toward a poly snapped through a wall by the huge `DETOUR_EXTENT` (`navigation_recast_path.cpp:44`). Add a short **unreachable-goal cooldown**: mark a goal that failed `TestPath` as bad for ~3s so the state picks a different target instead of re-issuing it.

**4c. Tighten the block detector (:142–143).** The 1s / 64u two-sample window lets slow wall-grind persist up to 3s. Add a short-window watchdog gated on `m_pPath->GetNodeCount() > 0` and not on a ladder: `<24u progress over bot_nav_stucktimeout ms` latches blocked. **Treat `bot_nav_stucktimeout 0` as disabled — do not clamp it up** (the botnav PR #79 footgun).

**4d. Off-mesh-link timeout.** `traversingOffMeshLink` (`navigation_recast_path.cpp:310`) has no timeout; if a jump/ladder link doesn't complete in ~2s, force `ResetPosition` + repath.

**4e. Ledge-safe escape.** The back-up axis-snap (:183–192) can walk a bot off a ledge or into the same corner. Before committing an escape direction, run a forward+down trace (reuse `CheckJumpOverEdge` probes) and reject directions that step into a pit.

**Gating:** `bot_nav_reroute 0` restores stock give-up; `bot_nav_stucktimeout` tunes/disables the watchdog.
**Coop-safety:** all in `BotMovement` (coop instantiates none); new logic stays in the bot layer, not in `navigation_recast_path.cpp` shared query code that actors could use.
**Playtest:** MP on a map with known pockets/doorways; drive `sv_numbots 8` and watch for permanent-stuck; toggle `bot_nav_reroute` to compare.

---

## PHASE 5 — Realistic combat (dynamic accuracy, aim convergence, suppression)

**Value: medium-high (the "fight more realistically" ask). Risk: medium.** Deterministic GameAIPro model, no RL.

**File:** `openmohaa-hzm/code/fgame/playerbot.cpp` (`State_Attack`), `playerbot_rotation.cpp`

**5a. Dynamic-accuracy delay (GameAIPro Ch.33).** Keep the bot always shooting when in cone/range, but modulate *hit likelihood* via a variable delay-between-effective-shots instead of gating fire. Compute `delay = base × ∏ ruleᵢ`, multipliers from data the bot already has: distance (≤5m ×0.5, ≥15m ×1.0), target crouched ×2, target in cover ×2, target facing away (angle >170°) ×2, target running toward the bot ×0.5. This drives the existing `m_vAimOffset` magnitude rather than adding a new fire suppressor.

**5b. Aim convergence.** Today `m_vAimOffset` re-rolls flat inside the enemy box every 100ms (`:1068`). Change to a converging error: `|offset|` starts large on acquisition and decays over time-on-target (`m_iLastAimTime`) toward a non-zero floor (residual jitter, never perfect). Feed the Phase-3 awareness so a bot that heard you first converges faster. This is what removes the "instant lock-on" tell.

**5c. Suppression + peek.** On `AI_EVENT_WEAPON_IMPACT` near the bot with no LOS (signal from Phase 3), duck to `FindCoverPosition` and stop advancing; peek-and-fire from cover rather than standing. Retreat toward the objective/squad node, not a random reachable spot. This layers on the existing `bot_botcover` system (:1086–1113) without touching it — same cvar keeps cover toggleable.

**5d. Keep** the existing human-ish burst throttle (`maxContinousFireTime`/`maxBurstTime`, :926–927) and distance-scaled reaction gate (:910); just shorten burst length at long range/while suppressing.

**Gating:** `bot_combat_realism 0` restores the current flat aim-offset + fire logic.
**Coop-safety:** entirely inside `State_Attack`/`rotation`; no shared code, no new signal.
**Playtest:** 1v1 an MP bot at short and long range — misses should read as suppression (rounds landing near you), first-shot should lag when you surprise it and be quicker when it heard you; toggle `bot_combat_realism`.

---

## PHASE 6 — Smart objective play: script-side squad director (attack/defend/flank roles)

**Value: high for "play objectives," but built last because it composes on Phases 2 & 4. Risk: low (script-only, no engine build).**

**Files:** new `hzm-mohaa-coop-mod/coop_mod/mp_botdirector.scr` (MP-only, gated like all `mp*.scr`), consumed via the existing `AttractiveNode` priority mechanism (`MoveToBestAttractivePoint(iMinPriority)`, floors Idle 0 / Curious 3 / Attack 5 at `playerbot.cpp:612/674/1121`).

Pattern (LoU skills/behaviours split — decide in script, execute in C++):
- The director reads `$player` team counts and, per team, assigns a **role quota**: e.g. cap attackers on the contested point, send the surplus to defend the owned point or flank. Implemented as per-role **attractive-node priority bands** — the director sets node priorities so a bot's state picks the role-appropriate node (attackers see the push node at high priority, defenders the hold node, flankers an offset approach node). Scoring per node: `priority / (1 + travelCost) × roleBias`.
- This reuses shipped code: bots already pull goals from `AttractiveNode`s; no engine change, no `coop_mp*` token in C++, so **no HZM-MP hook needed**. The nodes are spawned by `mp_botobj.scr` (already `level.coop_mpRun`-gated) and now tagged with role/priority by the director.

**Gating:** `bot_squadroles 0` (read in script) = flat objective-seeking (Phase 2 behavior only).
**Coop-safety:** pure MP script under the `mp.scr:46` refusal clause; `officer.scr`/`aihandler.scr` coop waves untouched; passes `check_mp_isolation.py` (no saved-cvar/loadout/compass names, MP-owned tokens only).
**Playtest:** MP objective map, `sv_numbots 8`, 4v4 — confirm one team pushes while some hold/flank, and the split rebalances as players die; toggle `bot_squadroles`.

---

## 4. Recommended ship order (each independently shippable)

1. **Phase 1** (perception cones + fire unfreeze) — highest felt impact, lowest risk.
2. **Phase 2** (objective spread) — near-pure win, kills clumping, unblocks "objective play."
3. **Phase 3** (hearing + flank) — delivers "hear realistically" + finishes the flank-reaction half-measure.
4. **Phase 4** (never-stuck) — biggest reduction in permanently-stuck bots.
5. **Phase 5** (combat realism) — polish; removes the aimbot/instant-lock tells.
6. **Phase 6** (squad director) — smart role-based objective play, built on 2 & 4.

Phases 1–5 are engine builds (one `game.dll`/`cgame.dll` rebuild each — remove the `.bak` files first, deploy to `G:\mohaa-gl2\` AND the GOG root per `build.ps1`). Phase 6 is a mod-only `build.ps1` pack. After each: `check_mp_isolation.py` green, coop 54-map patrol with `sv_numbots 0` unchanged, bots verified on a separate MP server.

**Key file anchors for the implementing session:**
- `openmohaa-hzm/code/fgame/playerbot.cpp` — `CheckCondition_Attack` :825/:842, `State_Attack` :879/:900/:962–981/:1081/:1121, `NoticeEvent` :397, `Pain` :1319/:1347, `State_Reset` :561, cvar pattern :1092.
- `openmohaa-hzm/code/fgame/playerbot_movement.cpp` — `MoveThink` block logic :128–202, arrival :219, `MoveToBestAttractivePoint` :621–711 (change :705), `MoveNear` :559, `TestPath`/`CanMoveTo` :975, `FixDeltaFromCollision` :817.
- `openmohaa-hzm/code/fgame/navigation_recast_path.cpp` (read-only ref) — `FindPathNear` scatter :115–167, `findCorners`/`currentNodePos` :358–388, `traversingOffMeshLink` :310, `HasReachedGoal` 16u :518, `DETOUR_EXTENT` :44.
- `docs/tools/check_mp_isolation.py` — `ENGINE_MP_HOOKS` :130, `SAVED_COOP_CVARS` :148 (verify no new cvar collides).
- `hzm-mohaa-coop-mod/coop_mod/mp_botobj.scr` :28–45 (nodes), new `mp_botdirector.scr` (Phase 6).

**Bottom line:** the three hard problems (deaf/blind bots, clumping on objectives, terminal stuck) are all fixable inside the `BotController`/`BotMovement`/`BotRotation` surface plus one MP script, using signals the engine already delivers to bots. No shared coop code (`actor.cpp`, `Sentient::CanSee`, `G_AIEventRadius`, the AI-event emitters, the `delegate_*` signatures) is touched, and coop instantiates no bot, so coop cannot regress — the `bot_*` cvars exist only for live tuning and A/B rollback.


## VET: correctness

I have verified every load-bearing claim against the actual source. The plan's core thesis holds, but there are several concrete defects — one of which breaks the headline feature. Findings below, ranked, with file:line.

---

## VERDICT: Thesis sound, but Phase 2 is broken as scoped, and two phases edit files outside the plan's own declared surface.

### What checks out (verified against code, not taken on faith)

- **Central thesis confirmed.** The AI-event and damage channels already reach the bot brain: `G_BroadcastAIEvent` runs the Actor arm (`g_utils.cpp:1814-1849`) then `botManager.BroadcastEvent` (`g_utils.cpp:1851`), which loops bot controllers and calls `controller->NoticeEvent(origin, iType, originator, dist2, r2)` (playerbot_master.cpp) — shooter, position, type and radius-falloff all delivered per-bot. `delegate_damage.Execute` (`sentient.cpp:2183`) → `BotController::Pain` (subscribed `playerbot.cpp:1438`). Both real.
- **Coop firewall confirmed.** `G_SpawnBots` (`g_bot.cpp:762`) derives its count purely from `sv_minPlayers`/`sv_numbots`, capped by `sv_maxbots` (`:777-791`); with all 0 it calls `createController` (`:168`) zero times. No `BotController` exists in coop, so `Think`/`NoticeEvent`/`Pain`/`State_Attack` never run. The gate is the *count*, not gametype — the plan's caution against a bare `g_gametype` test is well-placed. `mp_bots.scr` writes those `sv_*` cvars behind the `mp.scr:46` refusal guard (`if( level.coop_mainScriptLoaded == 1 )` — verified at that line). `mp_botobj.scr` gates every entry on `level.coop_mpRun != 1 → end`.
- **FOV math correct.** `Entity::CanSee(ent, fov, …)` uses `cos(DEG2RAD(fov/2.f))` (`entity.cpp:2957+`), so fov is the full cone. 150→±75°, 90→±45°, 45→±22.5°, 20→±10° all correct. It's 2D/horizontal (`DotProduct2D` against `orientation[0]`). Phase 1 only changes call-site *arguments*; the impl is untouched.
- **`bot_*` cvars don't trip the isolation checker.** `RX_MP_TOKEN` matches `coop_mp\w*`; `BUILD_BAN`/`SAVED_COOP_CVARS` list no `bot_*`. Confirmed against the regexes. `ENGINE_MP_HOOKS` is at `check_mp_isolation.py:130`, `SAVED_COOP_CVARS` at `:148` — both exactly as cited.
- **Nearly all line anchors are accurate.** Spot-checked and correct: `NoticeEvent:397`, `Pain:1319`/guard-return `:1347`, semi-auto gate `:962-981`, aim re-roll `:1068`, `MoveToBestAttractivePoint(5):1121`, `State_Reset:561`, cover system `:1086-1113`, `FindCoverPosition:758`; movement `MoveToBestAttractivePoint:621-711`/`MoveTo@:705`, block give-up `:133-136`, axis-snap `:183-192`, `MoveNear:559`, `CanMoveTo:975`; recast `FindPathNear:115-167`/`findRandomPointAroundCircle:140`, `traversingOffMeshLink:310`, `HasReachedGoal 16u:518`, `DETOUR_EXTENT:44`, `ResetPosition:537`. `MoveToBestAttractivePoint(int=0)` default confirmed (playerbot.h:58), so the Idle-0/Curious-3/Attack-5 floors are right. Actors use a *separate* `ActorPath` class (`actorpath.cpp`), not `RecastPather` — so the recast file is bot-only in fact.

---

### DEFECTS

**1. [HIGH — breaks the feature] Phase 2 scatter is defeated by the primary-attract fast path; editing only `:705` does nothing.**
`MoveToBestAttractivePoint` sets `m_pPrimaryAttract = bestNode` at `playerbot_movement.cpp:703`, immediately before the `:705` call the plan wants to change. On *every subsequent frame*, control enters the fast path at `:628` and calls `MoveTo(m_pPrimaryAttract->origin)` at **`:629`** — a fresh full path to the *exact* node origin. So the `MoveNear` scatter survives one frame and is then overwritten; all bots re-converge to within 16u of the same origin. The plan's `m_vAttractOffsetNode` only gates *re-rolling* the offset — it never stores a scattered destination, and it never touches `:629`. To actually scatter, the code must store a per-bot scattered Vector and route the `:629` `MoveTo` through it. As written, clumping is not fixed.

**2. [MED — will not compile as written] Phase 1a references an undefined variable.**
The snippet does `float d = sqrt(fDistanceSquared);` inside `CheckCondition_Attack` (`playerbot.cpp:825-859`), but that function never computes a per-sentient distance — `sentients_compare` sorts by distance but stores nothing, and there is no `fDistanceSquared` in scope. Implementer must first add `float fDistanceSquared = (sent->origin - controlledEnt->origin).lengthSquared();`. (Contrast: `State_Attack` *does* have `fDistanceSquared` at `:896`, which is likely where the plan copied it from without noticing the scope change.)

**3. [MED — internal contradiction + edits outside declared surface] Phase 4d edits a file the plan calls read-only and off-limits.**
4d adds an off-mesh-link timeout to `RecastPather::UpdatePos` in `navigation_recast_path.cpp`. But the plan's own anchor list tags that file "(read-only ref)", §1's MAY-EDIT list omits it, and §4's coop-safety text claims logic "stays in the bot layer, not in navigation_recast_path.cpp." The plan also mischaracterizes it as "shared query code that actors could use" — actors use `ActorPath`, so it's bot-only and the edit is in fact coop-safe, but the plan is self-contradictory about it. Note the underlying bug is real and worth fixing: `if (traversingOffMeshLink)` at `:310` has no timeout and is an `else if` chain ahead of the 2s repath branch at `:320`, so a stalled link hangs the agent indefinitely.

**4. [MED — field doesn't exist; edits shared archived class] Phase 2's `bestNode->m_vSpread`.**
No such member exists. `AttractiveNode` is defined in `navigate.h:407` (a savegame-`Archive`d `SimpleArchivedEntity`), which is not in the MAY-EDIT list. Adding an archived member touches persisted/shared state. The scatter is achievable cvar-only; the per-node flag is unnecessary and, as written, forces a `navigate.h` edit the plan doesn't acknowledge.

**5. [LOW-MED — misread variable] Phase 3b `bCurUnseen = (m_iLastUnseenTime != 0)`.**
`m_iLastUnseenTime` is a *reaction-time* timestamp, not an "enemy unseen now" flag: set on acquisition (`:848`), cleared once the reaction delay elapses (`:914`), re-set only after 2s of lost sight (`:1042-1044`). A bot in steady view of its target has it at 0 — so does a bot mid-fight. Using it to decide whether a flank attacker should displace the current enemy will misfire in the common case.

**6. [LOW — pseudo-code that doesn't work as printed]**
- Phase 3a uses `owner` and `maxDist`; the resolved shooter in `NoticeEvent` is `pSentOwner` (`playerbot.cpp:418-430`, and it can be `NULL`), and no `maxDist` exists in that scope.
- Phase 1c's settle timer fires immediately: with `m_iSteadyStartTime == 0`, `level.inttime - m_iSteadyStartTime > 350` is always true, so the "settle first, then fire" never settles. The set-vs-test order is inverted.

**7. [LOW — stale facts, hazard still real] Build-hazard file list is partly wrong.**
Of the three `.bak` files named, only `player.cpp.bak_botinput` exists (plus an unlisted, harmless `player.h.bak_botinput` — `.h` isn't matched by the glob). `player.cpp.pre_0905lanes_bak` and `weapturret.cpp.pre_0905lanes_bak` are not present. The hazard itself is real and currently live: `GLOB_RECURSE "./*.c*"` (`code/fgame/CMakeLists.txt:20-22`) matches `player.cpp.bak_botinput` → duplicate-symbol link error. The plan's nuance is right that it bites only at cmake *reconfigure*, not incremental build.

**8. [LOW — cosmetic, not edited] Reference imprecision.**
§1 item 4 pairs "delegate_damage/_killed/_gotKill" with "2144/2161/2183" but the actual order is `gotKill:2144`, `killed:2161`, `damage:2183` — reversed. The `fRangeFactor` probabilistic drop is at `playerbot.cpp:413` (the `if (fRangeFactor < random())`), not `:411` (the assignment). Neither is edited, so these don't affect the build.

**9. [LOW — oversold as new] Phase 4b partial redundancy.**
`MoveTo` already sets `m_bPathing=false` and returns when `FindPath` yields 0 nodes (`playerbot_movement.cpp:604-607`), so truly-unreachable goals are already handled; and `m_vFinalGoal` duplicates `m_vTargetPos`, which `MoveTo` already stores at `:590`. The DETOUR_EXTENT wall-snap concern is legitimate, but the "add validation" work is smaller than described.

---

**Bottom line for the implementing session:** Phases 1 (after fixing the undefined-variable), 3, 5, 6 are well-grounded and land on real, correctly-located, bot-only code. **Phase 2 must be re-scoped to change `playerbot_movement.cpp:629`, not `:705`, and to store a per-bot scattered destination — otherwise it is a no-op.** Phases 2 and 4d quietly require edits to `navigate.h` and `navigation_recast_path.cpp`, which are outside the plan's stated edit surface (both happen to be coop-safe, but the plan should own that rather than deny it). The coop-safety argument itself — no `BotController` in coop, no shared AI code touched — is verified correct.

## VET: coopsafety

I have verified every shared-surface claim in the plan against the actual engine tree. Here is the adversarial verdict.

---

# COOP-SAFETY ADVERSARIAL REVIEW — MP-Bot Intelligence Plan

**Verdict: No actual coop leak found in the plan's design. Isolation is real and I confirmed each shared-surface claim against the code. But three of the plan's own safety arguments are wrong or vacuous, and one phase (4d/4e) points the implementer straight at shared code while telling them not to touch it. These must be fixed before implementation, or the guarantee rests on luck.**

## What I verified as genuinely coop-safe (with evidence)

1. **Human coop players never receive a `BotController`.** `setControlledEntity` (playerbot.cpp:1429) is the sole place `delegate_damage/_killed/_gotKill/_spawned/_stufftext` are subscribed, and it is called only from `BotControllerManager::createController` (:1449), reached only via `G_AddBot`. So `Pain`, `NoticeEvent`, `State_Attack`, `CheckCondition_Attack`, `State_Reset` — all confirmed `BotController::` methods — can never fire for a coop human or a coop actor. Phases 1, 3, 5 are class-isolated. **Confirmed.**

2. **Coop actors do not share the recast path code Phase 2/4 edits.** `Actor : SimpleActor` uses `ActorPath m_Path` (simpleactor.h:97) directly. `IPather::CreatePather()` — which returns the `RecastPather` carrying `traversingOffMeshLink`/`UpdatePos`/`ResetPosition`/`FindPathNear` — is called at exactly **one** site: `playerbot_movement.cpp:33`. Coop actors never instantiate a `RecastPather`. `actor.cpp` has **zero** `AttractiveNode` references. `MoveThink`, `MoveTo`, `MoveNear`, `MoveToBestAttractivePoint`, `CanMoveTo`, `TestPath` are all `BotMovement::` methods. Phases 2/4 are class-isolated. **Confirmed.**

3. **The hearing path reaches only bots.** `BotManager::BroadcastEvent` (playerbot_master.cpp:59) loops over `getControllers()` only; the Actor arm of `G_BroadcastAIEvent` and the `G_AIEventRadius` table (g_utils.cpp:1769/1851) are separate and are on the plan's frozen list. Phase 3 does not touch the emitter. **Confirmed.**

4. **`bot_*` cvars cannot collide with any isolation clause** — not `coop_mp*`, `coop_`, `coop_lo*`, nor any `SAVED_COOP_CVARS` name. `bot_botcover`/`bot_manualmove` already exist. **Confirmed.**

5. **The firewall cvars are the only real gate and coop keeps them at 0.** `mp_bots.scr` is the sole mod writer of `sv_numbots`/`sv_minPlayers`/`sv_maxbots`, and it is an `mp*.scr` reachable only through `mp.scr`, whose first statement refuses to run under coop (mp.scr:46). Those cvars are registered with flag `0` (gamecvars.cpp:695-696), so they do not persist across a restart. This is the **already-shipped v1.7.7 firewall**; the plan does not change it. **Confirmed.**

## Findings to FLAG

**FLAG 1 — The regression proof for Phases 1–5 is vacuous. `check_mp_isolation.py` is structurally blind to every engine edit in this plan.** The plan cites "check_mp_isolation.py → exit 0" as the per-phase gate. But clause 14 skips any engine file that does not contain `coop_mp`/`hzm-mp`/`coop_mod` (checker line 751), and I confirmed `playerbot.cpp`, `playerbot_movement.cpp`, `playerbot_rotation.cpp` and `navigation_recast_path.cpp` contain **none** of those tokens. The mod-script clauses (1–13,15–18) never apply to engine C++ at all. So the checker stays green no matter what Phases 1–5 do to the bot brain. The plan's stated reason ("bot_* never trips clause 14") is true only incidentally — the whole file is never scanned. **Do not present a green checker as coop-safety evidence for Phases 1–5.** The only load-bearing proof for those phases is the structural class-isolation argument above plus the coop 54-map patrol at `sv_numbots 0` (which the plan does include — keep it, and treat it as the *primary* gate, not a secondary one). Phase 6 is the sole phase the checker actually covers.

**FLAG 2 — Phase 4d/4e contradict the plan's own frozen-boundary and point at shared code.** The plan's Phase 4 safety note says logic must stay in the bot layer and *not* in "navigation_recast_path.cpp shared query code that actors could use." Yet 4d ("force `ResetPosition` + repath" on off-mesh-link timeout) and its anchors point directly at `RecastPather::UpdatePos`/`traversingOffMeshLink` (:310) and `ResetPosition` (:537). I established these are bot-only *in practice today* (CreatePather is bot-only), so an edit there would not currently reach coop actors — but the plan simultaneously asserts the file is actor-reachable, and the legacy-vs-recast choice is a runtime `CreatePather()` decision, not a type-level guarantee that actors can never get a `RecastPather`. **Pin the implementation explicitly:** the off-mesh watchdog and ledge trace must live in `BotMovement::MoveThink` and call `ResetPosition`/`CanMoveTo` on the bot's own `m_pPath` — **never edit any `RecastPather` method body.** As written, the natural reading of 4d edits shared code, and no automated check would catch it.

**FLAG 3 — The firewall rationale is mis-stated; the correct invariant is narrower.** The plan says coop-safety is "by construction — no BotController is ever instantiated ... `G_SpawnBots` fires only when sv_numbots/sv_minPlayers > 0." That is false: `G_SpawnBots` runs **every frame in coop** (g_main.cpp:854), returning early only for `GT_SINGLE_PLAYER`; coop is gametype 2. It spawns zero bots solely because the cvars are 0. The real invariant is: **(a)** no coop-reachable code sets `sv_numbots`/`sv_minPlayers` > 0 (held only because `mp_bots.scr` sits behind the refusal guard and the cvars are non-archived), and **(b)** every edited function is bot-class-only. Both hold today. But the plan's "no BotController by construction" phrasing hides that (a) is a cvar-value discipline, not a structural impossibility — and the plan's own warning against gating bot logic on a bare `g_gametype` test is exactly the way (a) could be broken. State the invariant as (a)+(b), not "no bot exists."

**FLAG 4 — New bot-class members need constructor init (bot-only, not a coop leak).** `m_iSteadyStartTime` (BotController) and `m_vAttractOffsetNode` (BotMovement) must be initialized in the constructors, not only reset in `State_Reset` — this class has the same "memory is not zeroed" hazard TRAPS documents. `m_vAttractOffsetNode` must be a `SafePtr` (or stored as entnum) so a freed attractive node cannot dangle across the per-frame `!=` re-roll gate. Bot-only impact, but an uninitialized read would read as a bot regression, not a coop one.

**FLAG 5 — Phase 6 (`mp_botdirector.scr`) is the one phase the checker gates; run it.** It must carry no saved-coop-cvar name, no `coop_lo*`, no `flags["coop_isHost"]`, and call only allowlisted coop labels (clause 10). Reading `bot_squadroles` via `getcvar` and setting AttractiveNode priorities through existing MP mechanisms should pass, but it is the only phase where `check_mp_isolation.py` is load-bearing — gate it there explicitly, and confirm it is added to `MP_MANIFEST` (it matches `coop_mod/mp*.scr`, so it will be).

**Minor (correct as noted):** the `.bak` build hazard is real — I count **4** stale files in `code/fgame/` (`player.cpp.bak_botinput`, `player.cpp.pre_0905lanes_bak`, `player.h.bak_botinput`, `weapturret.cpp.pre_0905lanes_bak`); three match `GLOB_RECURSE ./*.c*`. Relocate them before any cmake reconfigure, as the plan says.

## Bottom line

The plan's design does not leak into coop: I traced every shared surface (`Sentient::CanSee` argument-only, the AI-event emitter/radius table, `RecastPather` vs `ActorPath`, the attractive-node system, the delegate subscriptions) and each is either bot-class-only or on the untouched frozen list. **The isolation is sound, but it rests entirely on the structural class-isolation argument plus the `sv_numbots 0` coop patrol — NOT on `check_mp_isolation.py`, which cannot see Phases 1–5 at all.** Fix FLAG 2 (pin 4d/4e to the bot layer, forbid editing `RecastPather` bodies) and re-word FLAGs 1 and 3 so no future session mistakes a green checker for engine-side coop-safety. With those corrections the plan is safe to implement.

## VET: completeness

Verification complete. I traced every load-bearing claim to source. Findings below.

---

# Adversarial review — HZM MP-Bot Overhaul plan

## Verdict
The plan's central premise is **sound and verified**: the hearing and got-shot signals already reach the bot brain, the work is genuinely confinable to the bot-only surface, and the `bot_*` naming really does evade the isolation checker. But **two of the six user symptoms are not actually fixed by the plan as written** (clumping, and part of "never stuck"), one goal ("play objectives") is only one-third wired, and the plan contains one internal coop-safety contradiction. Details, ranked.

## Confirmed against source (premises hold)
- **Hearing path is real and reaches bots.** `G_BroadcastAIEvent` calls `botManager.BroadcastEvent(...)` unconditionally (g_utils.cpp:1851), `BotManager::BroadcastEvent` iterates bot controllers and calls `NoticeEvent` (playerbot_master.cpp:107), and a firing player's weapon emits `AI_EVENT_WEAPON_FIRE` (weapon.cpp:2611+). No new engine signal needed — correct.
- **`NoticeEvent` (playerbot.cpp:397) genuinely wastes it.** Every event type — WEAPON_FIRE, IMPACT, EXPLOSION, voices, FOOTSTEP, GRENADE — falls through to the *same* case that only sets `m_iCuriousTime += 20000`. Bots never acquire an enemy from sound today. The plan's diagnosis, including the inverted nearest/farthest early-out (line 402: it returns when the *new* event is *closer*, keeping the farther one) and the `fRangeFactor < random()` drop, is accurate.
- **Pain flank-swallow is real.** playerbot.cpp:1347 `if (m_pEnemy && IsValidEnemy(m_pEnemy)) return;` — confirmed; a bot already fighting ignores being shot from behind.
- **Sight cones are as claimed.** Acquisition `CanSee(sent, 80, …)` (CheckCondition_Attack), firing `CanSee(m_pEnemy, 20, …)` (State_Attack). And once acquired the bot *does* turn to the enemy via `rotation.AimAt(vTarget + m_vAimOffset)`, so widening the cones composes with real aiming.
- **`bot_*` is isolation-safe.** BUILD_BAN, SAVED_COOP_CVARS, `RX_MP_TOKEN`(coop_mp), `RX_COOP_LO`(coop_lo), `RX_COMPASS`(coop_compassBar) — none match `bot_`. Verified in check_mp_isolation.py.
- **Coop firewall is structural, as claimed.** Bots spawn only from `sv_numbots`/`sv_minPlayers` (g_bot.cpp:762+), set only in mp_bots.scr behind `level.coop_mpRun==1`; coop instantiates no `BotController`. Verified.
- **Turn-rate clamp exists** (playerbot_rotation.cpp:98 `Q_clamp_float(speed, -maxChangeDelta, maxChangeDelta)`), so Phase 5's "fast swing, not aimbot snap" claim is real.

## Defects — these leave a user symptom unfixed

**1. [HIGH] Phase 2 patches the wrong line; clumping is NOT fixed as written.**
The plan changes `MoveTo(bestNode->origin)` at :705. But `MoveToBestAttractivePoint` has a `m_pPrimaryAttract` early-return at the *top* (playerbot_movement.cpp:629) that runs `MoveTo(m_pPrimaryAttract->origin)` **every frame** once a node is locked; :705 executes only on the first selection. The frame after the scatter, line 629 overwrites it with the exact objective origin, so bots re-converge on the same point. The scatter must be applied on the primary-attract path (or stored as origin+offset and re-used there), not at :705. Additionally, node selection is *nearest-node* (`distSquared < bestDistanceSquared`), so all nearby bots pick the **same** node — per-bot scatter yields a ring on one point, not distribution across objectives; real spread needs Phase 6. As written, "don't clump" does not ship.

**2. [HIGH] Phase 4d/4e edit shared path code — contradicts the plan's own frozen-list, and coop-safety rests on an unstated invariant.**
`traversingOffMeshLink` and the corner/ledge logic are in `navigation_recast_path.cpp` inside class `RecastPather`. The plan's frozen list and Phase-4 coop-safety line both assert "navigation_recast_path.cpp is not touched / stays in the bot layer," yet 4d explicitly says "force ResetPosition+repath at navigation_recast_path.cpp:310." I checked whether coop is exposed: coop Actors use a *separate* class (`ActorPath`, legacy `PathInfo`, actorpath.h) and hold **no** `IPather`, while bots hold `IPather* = RecastPather` (`IPather::CreatePather()`, navigation_path.cpp:35). So the edit is bot-only *in effect today* — but only because "no coop Actor ever constructs a RecastPather," an invariant the plan never states or defends, and one that `g_navigation_legacy`/navmesh-actor changes could break. Fix: put the off-mesh timeout and ledge trace in the `BotMovement` caller (`MoveThink`), never in `RecastPather`. The plan should either move 4d/4e bot-side or explicitly document and pin this invariant.

**3. [MEDIUM] "Play objectives" is wired for only 3 of ~15 MP modes.**
`botobj_set` (the objective→AttractiveNode bridge in mp_botobj.scr) is called from exactly three mode scripts: **assassination, domination, koth**. Demolition, CTF, push, baseassault, cyberattack, cybersnd, buildabase, countdown, gungame, freezetag, etc. spawn no objective nodes. Phases 2 and 6 only improve how bots *follow* nodes — they add nothing to a mode that places none. So for most objective modes bots will still just fight. The plan improves node-following but never audits or extends per-mode node coverage; "bots play objectives" is delivered for 3 modes and unaddressed for the rest. This is the largest silent gap against the user's "play objectives" goal.

**4. [MEDIUM] Phase 3a pseudocode won't compile — undefined identifiers in the load-bearing hearing fix.**
The block references `owner` and `maxDist`. In `NoticeEvent` the resolved shooter is `pSentOwner`, and there is no `maxDist` in scope (that local belongs to `CheckCondition_Attack`). An implementing session pasting this gets build errors on the one change that delivers "hear gunfire and react." Needs the real name (`pSentOwner`) and a locally computed `Q_min(world->m_fAIVisionDistance, world->farplane_distance*0.828)`.

**5. [LOW] The engine-build `.bak` hazard list is factually wrong.**
Plan says remove `player.cpp.bak_botinput`, `player.cpp.pre_0905lanes_bak`, `weapturret.cpp.pre_0905lanes_bak`. Actual files present: `player.cpp.bak_botinput` and `player.h.bak_botinput`; the two `pre_0905lanes_bak` files **do not exist**. The `GLOB_RECURSE "./*.c*"` (fgame/CMakeLists.txt:22) does match `player.cpp.bak_botinput` (it contains `.c`), so the duplicate-symbol hazard is real — but the plan chases two phantom files and omits the sibling. Re-derive the removal list from `find code -name '*.bak*'` at build time rather than trusting the plan's list.

**6. [LOW] "Engage without facing me dead-on" beyond ±75° depends on Phase 3, not Phase 1.**
Phase 1 widens sight to ±75° (close) / ±45° (far). A player at the bot's true flank/rear is still invisible to sight; acquisition there comes only from hearing (Phase 3a) or Pain (3b). The ship order (1→3) is fine, but Phase 1's own playtest criterion ("bots engage from the side") only holds to ±75°; the rear arc is unfixed until Phase 3. Don't sign Phase 1 off as delivering the full "from any angle" symptom.

## Symptom-by-symptom scorecard
- must-face-to-shoot → addressed (Phase 1 cones + 1c fire-unfreeze). Note 1c's freeze is **semi-auto-only** (full-auto already fires unconditionally at the `else` branch); fine, but don't expect 1c to change full-auto bots.
- no-reaction-when-shot → addressed (Phase 3b), mechanism verified.
- ignore-human / hear gunfire → addressed in design (Phase 3a) but won't compile as written (defect 4).
- clumping → **not delivered as written** (defect 1).
- run-into-walls / stuck → addressed (Phase 4) but violates the plan's own coop boundary (defect 2).
- play objectives → **only 3 modes wired** (defect 3).
- fight realistically → addressed (Phase 5); no aimbot-snap risk (turn clamp confirmed).

**Bottom line for the implementing session:** the architecture is correct and coop-safe in spirit, but before building, (a) move the Phase 2 scatter to the primary-attract path at movement.cpp:629, (b) relocate Phase 4d/4e off-mesh/ledge logic into `MoveThink` and out of `RecastPather`, (c) extend `botobj_set` wiring to the remaining objective modes or scope the "play objectives" claim to the 3 wired modes, and (d) fix the Phase 3a identifiers. Defects 1–3 each correspond to a user-stated symptom the current plan would leave visibly unfixed.
