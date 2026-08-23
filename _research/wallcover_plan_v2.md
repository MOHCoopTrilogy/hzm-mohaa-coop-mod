# Wall Cover v2 — what is actually broken, and the plan

**Date:** 2026-08-22 · **Supersedes the "known dead end" in `wallcover_plan_v1.md` §7.2**
**Status:** research complete, nothing implemented, awaiting go.

---

## 0. Verdict in one paragraph

Wall cover was re-enabled on 2026-08-22 (`d3f1af09`) with both DECISIONS.md preconditions
satisfied. The user then reported four symptoms. **Three of them are one bug** — the open-side
solver's fit test returns NONE on 78% of frames, and three separate consumers are gated on
`side != 0`, so they all silently switch off together. **The fourth is not a bug at all** —
auto-cover is crouch-only by construction and was never wired to standing wall cover.
Separately, **the camera work in v1 §5.4 was never implemented**, so fixing the solver is
*necessary but not sufficient* for the camera symptom. And the v1 claim that right-jamb blindfire
is impossible for players is **wrong** — the mechanism is inherited, generic, and the player
skeleton has the tag.

---

## 1. What is broken, with evidence

### 1.1 The fit test — one cause, three symptoms  ⭐ the main event

`coop_coverProbe 1`, 6271 COVERSIDE samples from a live session:

| samples | reading | meaning |
|---:|---|---|
| **4864 (78%)** | `want=0 have=0 edgeL=44 edgeR=58 openL=0 openR=0` | both edges **found and measured**, both judged **closed** |
| 791 (13%) | `want=-1 have=-1 openR=1` | correctly picks the one open side |
| 43 (0.7%) | `want=1 have=0` | hysteresis never latched the side it wanted |

STEP 1 (outward edge scan, 16→72u) works — it finds the edge *and measures its distance*.
STEP 2 asks "can the body fit through that gap" by sweeping the **full player hull sideways
starting at the player's own origin**. In cover the player is pressed against the wall, so that
trace begins in contact, returns `startsolid`, and forces `open = 0` on both sides.

The 13% that succeed prove the *logic* is sound. Only the trace start point is wrong.

**Why it presents as three unrelated faults** — everything downstream is gated on the side:

| consumer | site | behaviour at side 0 | user's words |
|---|---|---|---|
| lean | `player.cpp:4309` | `&& m_iCoopCoverSide != 0` → never leans | *"right mouse doesn't pop you out on the correct side"* |
| blindfire steering | `weapon.cpp:2085` | steering skipped → round leaves along the **raw view basis from the in-pose muzzle** | *"shoots into the wrong side and at the wall"* |
| client lean prediction | `cg_predict.c:657` | `pSide->integer != 0` → no predicted lean → view never shifts | *"camera keeps going behind me"* |

The blindfire case is **bug-305's original symptom reappearing from a new cause**, which is why
it feels like old ground. The bug-2028 guard is doing exactly its job (refusing to collapse to
LEFT); the input it is guarding is simply always NONE.

### 1.2 The camera was never built

`wallcover_plan_v1.md` §5.4 designs a "cover proposes, the player disposes" shoulder override.
**It does not exist.** `grep -n "coverShoulder\|s_coverShoulderManual" cg_view.c` → nothing.
§5.5 (suppress the 3P lean roll while covered) is also absent — `cg_view.c:4670` still applies
`ps->fLeanAngle * 0.1 * fLeanRollScale` unconditionally in both view modes.

**Consequence, and this is the correction that matters:** fixing §1.1 restores the *lean* and the
*first-person* view shift, but in third person the camera still sits behind the player. The
camera symptom needs **both** fixes. Anyone who fixes only the solver will re-report it.

### 1.3 Auto-cover on walls — a missing feature, not a defect

`player.cpp:13828` gates the auto dwell timer on `(client->ps.pm_flags & PMF_DUCKED)`. Wall cover
is the **standing** back-to-wall pose, so the timer never starts near a wall. Crouch/LOW cover
auto-engages correctly — which is exactly what the user observes.

This is why auto-cover has been reported "never working" three times (bug-1634, bug-1635, and
now): standing at a wall can never trigger it. The comment records the original ask — *"crouch
behind cover and after a second it will automatically put you behind cover"* — so it was built to
spec and the spec did not include walls.

### 1.4 Right-jamb blindfire is NOT a dead end — v1 §7.2 is wrong

v1 states: *"A player weapon is bolted permanently to `tag_weapon_right` and there is no
player-side equivalent of `weaponcommand attachtohand`."* Every link in that chain fails on
inspection:

| link | finding |
|---|---|
| `weaponcommand` owner | `EV_Sentient_Weapon` → `Sentient::WeaponCommand` (`sentient.cpp:743`) |
| can a Player reach it? | **yes** — `class Player : public Sentient` (`player.h:127`), inherits the response map |
| is it player-guarded? | **no** — `Sentient::WeaponCommand` (`sentient_combat.cpp:1393`) is generic: resolve hand → `GetActiveWeapon` → build event → `weap->ProcessEvent(e)` |
| is `AttachToHand` guarded? | **no** — `Weapon::AttachToHand` only checks `owner && attached`, then `Tag_NumForName(owner->edict->tiki, tag)` |
| does the player model have the tag? | **yes** — `attachToTag_offhand = "tag_weapon_left"` (`weapon.cpp:1139`); **57 of 125** player/human `.skd` skeletons carry it, incl. `usarmy.skd`, `allied_ranger_soldier.skd` |
| does the engine expect it on a player? | **yes** — `player_combat.cpp:175` resolves `tag_weapon_left` on `edict->tiki` and has an explicit `pChild->edict->s.tag_num == iTagLeft` branch |
| do player statemap anims run entry commands? | **yes** — `player.cpp:6459` / `:6601` call `ProcessEntryCommands(this)` with the Player as target |

**One genuine unknown remains:** whether the *animation's* own `entry weaponcommand …` notetrack
fires for a player (that is the TIKI anim path, not the statemap `entrycommands` path, and I did
not trace it). **It does not matter** — we can invoke the attach explicitly on state entry and
restore it on exit, which is *safer* than relying on a notetrack because we control the pairing.
An unpaired attach would leave the gun in the left hand permanently, which is precisely the latch
class this project keeps losing to.

---

## 2. The machinery we must not fight

The 3P/ADS shoulder system is known-good and is the reference implementation.

```
cg_view.c:88     s_shoulderSideSign        ±1, EASED
cg_view.c:602    fCamSide = cg_camerasideoffset->value * s_shoulderSideSign
cg_view.c:641    fCamSide += (cg_adsShoulderSide * sign - fCamSide) * s_adsShoulderEnv
cg_view.c:741-45 fArc = 1 - |sign|;  fCamDist += fArc * cg_adsShoulderArc     (bows the sweep)
cg_view.c:753    VectorMA(new_vieworg, fCamSide, right, new_vieworg)
cg_view.c:3790+  sign eased toward ±1 from the ARCHIVED cvar cg_adsShoulderRight
```

**Three rules, each with a bug behind it:**

1. **Never write `cg_adsShoulderRight`.** It is `CVAR_ARCHIVE` and it is the player's standing
   preference. Override the *sign target*, do not assign the cvar. (`21-user-preferences.md`:
   *"A setting is a promise"*.)
2. **Never re-target the sign mid-envelope.** The arc term bows the camera behind the player
   during a sweep; starting a shoulder swap on top of an ADS fly-in composes two eases into one
   motion and reads as the warp bug-1992 was filed for. Gate on both envelopes at rest, or on a
   fresh cover entry.
3. **One decider for 1P/3P lockstep.** `CG_AdsForceFirstPerson()` is that decider today and both
   sides must use it (the turret-camera regression rule). Cover must not introduce a second.

**And the wire is lossy.** `coop_coverSide` reaches the client as a change-only stufftext.
Per TRAPS T8, a server-stuffed `set` is silently dropped unless whitelisted
(`cg_servercmds_filter.cpp`), and unquoted / one-statement-per-stufftext is mandatory
(bugs 736/758). `coop_coverView` already works, so the namespace is permitted — **but verify
`coop_coverSide` specifically before building the camera on top of it.** It is currently only
read by the predictor, so it has never been proven to arrive for any other consumer.

---

## 3. The plan

Four phases. **Each ships and is verified alone.** Bundling is what produced five partial fixes
in one day earlier in this session; the discipline is the point.

### Phase 1 — the fit test  (game.dll only)

*Fixes: blindfire direction, RMB lean, 1P view shift. Does not fix the 3P camera.*

1. Offset the hull sweep **away from the wall along the stored cover normal** before sweeping
   sideways, so the trace cannot begin in contact. STEP 1 already measures the edge distance, so
   the offset has a real number to work from rather than a guessed constant.
2. If that alone is insufficient, in order: relax the 0.85 fraction requirement, then sweep a
   reduced hull. **One at a time, re-probing between each** — the probe distribution is the
   oracle and it is cheap.
3. Fix the 43-sample `want=1 have=0` case: the commit hysteresis never latches the side it wants.
   Read `coop_coverSideCommitMs` (180) and confirm the dwell actually accumulates.

**Verification:** `coop_coverProbe 1`, one live session, same 6271-sample shape. Required:
both-closed share falls from 78% toward the noise floor, and `openL`/`openR` disagree (exactly
one side open) in a doorway. **Do not accept "it felt better".** Then confirm downstream:
`coop_coverSide` non-zero, blindfire decals leaving along the opening rather than the wall.

**Risk:** low. Confined to the solver; the mandatory `side != 0` guards stay exactly as they are,
so a wrong answer still degrades to NONE rather than to a wrong side.

### Phase 2 — verify the wire, then the camera  (cgame)

*Fixes: the 3P camera symptom.*

1. **First, prove `coop_coverSide` arrives.** Add it to the servercmds whitelist if needed and
   confirm with a one-line client print. If it does not arrive, everything below is dead code —
   this is the T3 "prove the feature executes" check and it costs one session.
2. Implement v1 §5.4 as an **override at the sign target only** (`cg_view.c:3790-3803`):
   `if (auto && !manualLatch && coverSide != 0) fSignTgt = -(float)coverSide;`
   Opening LEFT → left shoulder; opening RIGHT → right shoulder.
3. `s_coverShoulderManual`: a client session latch — MOUSE3 while covered wins for the rest of
   that cover session, clears when the cover flag drops. MOUSE3 keeps writing the archived
   preference as it does today; we only override while covered.
4. Implement v1 §5.5: scale the 3P lean roll by `(1 - coverness)` behind `cg_coverLeanRoll`
   (default ~0.25). One line, one cvar, live-tunable.
5. Gate the re-target on both shoulder envelopes being at rest (rule 2 above).

**Verification:** take cover at a doorway in 3P; the camera moves to the side of the opening and
does not warp. Swap with MOUSE3 and confirm it sticks for that session and that
`cg_adsShoulderRight` is unchanged afterwards.

**Risk:** medium — this is camera code, and bug-1992 is the record of getting it wrong. Mitigated
by making it an override behind a cvar so it can be dropped live.

### Phase 3 — auto-cover on walls  (game.dll, one line + a decision)

**This is a design decision, not a repair, and it is the user's call:**

- **(a)** Drop `PMF_DUCKED` from the gate at `player.cpp:13828` and let the existing validation
  pick wall-or-low. It already "silently clears the request again" when neither validates, so the
  failure mode is a no-op. Add a standing-still requirement so it does not grab walls you brush
  past.
- **(b)** Leave auto-cover as the crouch feature that was asked for, and say so in the settings
  text so it stops being re-reported as broken.

**Recommendation: (a)**, gated behind the existing `coop_coverAuto`, because the user has now
reported it three times — the expectation is clearly that it covers walls.

### Phase 4 — right-jamb blindfire  (game.dll + statemap)

*Only after Phases 1–2 prove the side is reliable — this is worthless while side is NONE.*

1. On entering `COVER_WALL_FIRE` with side = RIGHT, call the attach explicitly
   (`weaponcommand mainhand attachtohand offhand`) rather than relying on the anim notetrack.
2. **Pair it unconditionally on exit** — restore `mainhand` on every exit path, including death,
   disconnect, cover-drop and map change. An unpaired attach leaves the gun in the wrong hand
   permanently. Re-assert rather than reason about ordering (TRAPS T3).
3. Keep `coop_blindfire_low : COOP_COVER_OPENRIGHT` (the overhead crate spray) as the **fallback**
   for any weapon whose right clip is missing or whose model lacks `tag_weapon_left` — 68 of 125
   skeletons do not have it.
4. Right-jamb **idle** and **peek** need none of this: v1 §7.2 already identifies the bare
   no-hand-swap aliases (`rifle_wall_alert_right`, `mp40_wall_alert_right`,
   `rifle_wall_peek_left/right`, `mp40_wall_peek_left/right`).

**Verification:** right-jamb blindfire with a rifle and with a pistol; confirm the gun is in the
left hand during the burst and back in the right hand after, and after dying mid-burst.

**Risk:** medium-high, and it is the one to defer. The failure mode (gun stuck in the wrong hand)
is visible and persistent. It is also the only phase whose premise I have not fully traced — see
§1.4's remaining unknown.

---

## 4. Where I was wrong this session

Recorded because the corrections are the useful part:

1. **I repeated "players cannot honour `attachtohand`" as settled fact** from DECISIONS.md
   without checking it. Six lookups disproved it. A "known dead end" that nobody has re-tested is
   a hypothesis wearing a hat.
2. **I told the user the fit test would fix three symptoms.** It fixes the lean and the blindfire
   outright, but the 3P camera *also* needs §5.4, which was never built. I checked that only
   after saying it.
3. **I asserted the finger system could not cause the vanishing gun before verifying it**, and
   the user caught it. Verifying turned up a real latent bug (bug-2070) I would otherwise have
   missed.
4. **I said the gun flicker was "reduced" on arithmetic, not measurement.** The data does not
   support a rate change.

The pattern in all four: stating a conclusion at the confidence of a measurement when it was
actually an inference. The probe exists precisely to close that gap and it is cheap.

---

## 5. Not in this plan

- **Reload interruption / reload-while-sprinting.** The user asked whether there were prior
  ideas. There is no recorded design: `composure_and_ads_plan.md:191` covers *breath-hold*
  interrupt, and `weapon_feel_r1_engine.md` D1 mentions "a reload interrupted and restarted"
  only as a phase-timer edge case. **The engine has no reload-cancel mechanism at all** — no
  `CancelReload`, no sprint/reload interaction. That is a fresh design and belongs in its own
  pass, not bolted onto cover.
- A/D slide along cover (v1 §6) — unchanged, still deferred.
