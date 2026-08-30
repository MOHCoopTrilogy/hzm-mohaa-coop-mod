# Gun Bracing (Weapon Mounting) — Design Document

Status: DESIGN — not built. Synthesized 2026-08-27 from three research streams (genre survey,
engine code map, detection design). All engine line numbers verified against the current tree
(C:\mohaa-coop-dev\openmohaa-hzm\code\) by researchers B/C this session.

Goal: when a player's gun is physically supported by geometry — leaning at a corner, crouched
behind a crate/sill/sandbag (including objects the cover system never claims), or peek-aiming
from cover — the gun should FEEL braced: tighter spread, less recoil, damped weapon sway/lag,
plus a rest "thunk" cue. Genre reference: CoD MW2019 mounting, RS2:Vietnam weapon resting.

---

## 1. Behavior spec

**Trigger: fully AUTOMATIC with hysteresis, no new bind.** This is the RS2:Vietnam model — the
consensus best-feel for a milsim-adjacent game, needs zero new binds, and players who never read
patch notes still get it. CoD ships a button-commit because its buff is enormous (~90% recoil);
ours is moderate, so automatic is safe. A global off-switch cvar (`coop_brace 0/1`, default 1)
covers players who hate it. NOT a debuff: we brace (buff) only — never block the gun (the
Ready-or-Not muzzle-collision lesson: buff versions are loved, block versions are resented).

**Braced := C OR A OR B'** — one authoritative server function `Player::TickCoopBrace()`:

- **C — cover peek** (zero new traces): `m_bCoopCoverPeek` true (wall OR low cover + RMB aim,
  player.cpp:15924-15925). The anchored wall-sustain trace already revalidates geometry per
  frame (player.cpp:15389-15400). This is the purest mount case — and today peek fire gets
  vanilla spread while blindfire is penalized 3x, so cover-peek is currently unrewarded.
- **A — muzzle-support trace** (standing or crouched, catches sills/sandbags/crates/fences the
  cover system never claims): support trace must HIT just below the gun line AND eye trace must
  be CLEAR at the gun line. Same inverse-pair recipe as vault's knee-blocked/chest-clear
  (player.cpp:16769-16776). Full parameters in §4.
- **B' — lean at a corner**: `|ps->fLeanAngle| >= 22°` (half of leanMax 45, player.cpp:4332)
  PLUS one confirming shoulder trace. Lean alone is NOT enough — vanilla lean performs no
  geometry test (bg_pmove.cpp:1399-1477 never traces) and DF_ALLOW_LEAN_MOVEMENT can permit
  moving leans (player.cpp:4323-4327); raw lean would grant free accuracy in an open field.

**Stance composition (division of labour — no double-dipping):**

| State | Braced? | Why |
|---|---|---|
| Standing lean at corner | Yes (B') | The lean case the user asked for |
| Crouched behind unclaimed object | Yes (A) | Support hits at z+36, eye clears at z+52 |
| Standing at window sill / sandbag | Yes (A) | Support hits at z+70, eye clears at z+82 |
| Cover peek (wall or low) | Yes (C) | Flags already exist where spread is computed |
| Cover blindfire | **Never** | Deliberately 3x spread (weapon.cpp:2082-2089); brace must not fight it |
| Prone | **Excluded** | Already owns 0.35 spread lane (weapon.cpp:1943-1952); stacking would trivialize it |
| Moving / airborne / vehicle / turret / ladder | Never | Gates in §4; Vanguard's strafe-while-mounted mistake is the #1 thing to avoid |

Braced STACKS with crouch (RS2 rule: rest stacks with stance): braced crouch = 0.80 x 0.50 =
0.40 of base spread — decisive, but still short of prone's 0.35, preserving the stance ladder.

**Envelope, not a bool:** publish `m_fCoopBrace` 0..1, rise ~6/s (the ~0.2 s settle IS the
feel — same design note as the move-spread settle, weapon.cpp:1958-1962), fall ~3/s. All
effects scale by the envelope, so entry/exit feels like the gun settling onto the surface.

## 2. Effect set (cvar defaults + hook points)

All new cvars pre-registered in G_InitGame with real defaults — never script-getcvar-created
(standing rule, bug-1669). `env` = m_fCoopBrace (server) / mirrored client copy (cgame).

| Effect | Cvar / default | Formula | Hook |
|---|---|---|---|
| Bullet spread | `coop_braceSpread 0.5` | `vSpread *= 1 - env*(1-0.5)` | fgame weapon.cpp — **BOTH copies**: FT_BULLET :1918 and FT_FAKEBULLET :2262, inserted right after the stance block :1943-1952 (in-code warning :1940-1942: patching one "works in SP and not MP") |
| Server recoil (real aim climb) | `coop_braceKick 0.4` | `kick *= 1 - env*0.4` | fgame Weapon::ApplyFireKickback weapon.cpp:2523-2562, exactly like the breath multiplier g_breathRecoilMult at :2546-2557 |
| Client view-weapon recoil shove | `coop_braceShove 0.5` | scale the per-shot shove | cgame cg_view.c:1889-2082; mirror the breath-steady halving at :2050 |
| Stress calm | fixed 0.70 damper | `raw *= 1 - env*0.3` | **BOTH twins in lockstep**: fgame TickCoopStress player.cpp:14100-14104 (beside prone x0.70/crouch x0.85) AND cgame CG_FeelStressAdvance cg_view.c:5531-5534 (comment player.cpp:14043-14045 forbids drift) |
| Weapon-lag spring damping | `coop_braceLag 0.4` | `fGain *= lerp(1, 0.4, env)` | cgame cg_view.c:2959-3017; mirror the ADS scale `if (bAds) fGain *= cg_weaponLagADS` at :2985. **Do NOT zero it** — Squad's "less like turrets" pass: a braced gun is a damped spring, not a frozen turret |
| ADS idle sway | `coop_braceSway 0.35` | `sway *= lerp(1, 0.35, env)` | cgame cg_view.c:1999-2005 (cg_adsSway figure-8); same scale on scope sway :2007-2020 |
| Translational accel lag | reuse coop_braceLag | same scale | cgame cg_view.c:2221-2259 |

Genre calibration: shipped numbers are recoil -50..-90% (CoD ~90, Sandstorm 70), sway
-75..-100%. We land deliberately mid-pack (spread -50%, recoil -40%, sway -65%) because our
brace is automatic and movement-gated rather than button-committed — the anti-camping price is
the stillness gate, not a giant number. Plain ADS gives no server spread bonus today
(researcher B, #1 note), so brace is the first hip/ADS-agnostic accuracy buff besides stance.
No ADS-time buff (no surveyed game does one). NOT applied per-gun: the ADS tune table is
positional-only and a cover column was already rejected (cg_view.c:540-543) — brace feel is
cvar-global, optionally x per-class weight (fClassKick precedent cg_view.c:1908-1912).

## 3. Feedback

1. **Rest thunk (primary cue).** Client-local, edge-triggered on the post-dwell 0→nonzero
   envelope rise ONLY (never on exit or sub-dwell touches — strafing a wall cannot machine-gun
   it). Pattern: the breath in/out pair at cg_view.c:1958-1963 — static prev-state bool +
   `cgi.S_StartLocalSound("sound/coop_brace/brace_on.wav", qfalse)`; direct wav path, no alias
   needed (S_StartLocalSound hardcodes CHAN_MENU, note at cg_view.c:5627). Softer
   `brace_off.wav` on the falling edge, CoD-style. Asset ships in the mod pk3. One generic
   wood/cloth thunk first; per-surface variants later. (A server-positional variant audible to
   nearby players via `Sound("coop_brace_on")` — player.cpp:3544-3549 alias-prefix pattern,
   mind the prefix-collision warning :3779-3794 — is an open question, §6.)
2. **Viewmodel settle.** Free by construction: the eased envelope ramping the lag-spring gain
   (cg_view.c:2996-3009) and ADS sway over ~0.2 s reads as the gun settling onto the surface.
   No authored pose needed for v1; a statemap braced pose later would follow the
   CondCoopCover pattern (player.h:673-674, player_conditionals.cpp:1129).
3. **HUD pip (optional, recommended — RS2's single icon is its whole discoverability story).**
   Small icon near the crosshair while braced. cgame-side 2D draw keyed off the mirrored
   client envelope (no script/ihuddraw needed — the state already reaches cgame, §4
   transport); if ever script-drawn instead, it must claim a free slot in the authoritative
   HUD slot map (_research/hud_slot_map.md).
4. The sway itself dying is the strongest kinesthetic signal (every surveyed game) — effects
   2-7 in §2 carry most of the communication even with sound/pip disabled.

## 4. Detection — exact parameters

`Player::TickCoopBrace()`, called in ClientThink immediately AFTER TickCoopCover
(player.cpp:5644) because it consumes this frame's peek/blindfire flags (tick-order trap
documented at :5579-5584, bugs 319/554).

**Gates (integer compares before any trace; copy of the cover cancel list :15345-15357 minus
its WASD strictness):** alive, !spectator, !prone, !vehicle, !turret, !ladder, !frozen,
groundentity != NULL (vault precedent :16763 — kills the falling-past-a-window false
positive), NOT m_bCoopBlindfire, stillness with hysteresis: enter `velocity.lengthXY() < 20`
u/s, break `> 35` u/s (mirror of the crawl no-fire 30/15 hysteresis, player.cpp:5614-5618).

**Scheme A traces** (point traces, vec_zero hulls, passEntity=this, direction = flat
yaw_forward — same source as cover, player.cpp:15369; flat, not 3D aim, so aiming down over a
sill still qualifies):
- STANDING: support from origin+(0,0,70) (12u under the 82 viewheight, bg_public.h:42),
  length `coop_braceDist` (default 36u); accept `!startsolid && fraction<1 &&
  |plane.normal.z|<0.7 && dot(normal,fwd)<-0.5` (filter copied verbatim from cover wall-enter
  :15408-15409). Eye-clear from origin+(0,0,82), length braceDist+8, require fraction>=1.0
  (pattern = LOW head-clear :15745-15749).
- CROUCHED: support at origin+(0,0,36) (identical to LOW-cover chest height :15731),
  eye-clear at origin+(0,0,52) (48 crouch viewheight bg_public.h:45, +4 margin). A 40-46u
  crate → braced with a sightline; a 60u crate → eye blocked → not braced, that's LOW-cover
  blindfire territory: clean division with the existing system.
- Mask MASK_SOLID, then REJECT if trace.ent resolves to a Sentient/Player (MASK_SOLID includes
  CONTENTS_BODY, bg_public.h:643-644; rejection patterns player.cpp:8732, :12992-12996).
  CONTENTS_FENCE hits stay — bracing on a railing is desirable. Shut func_doors qualify; when
  the door moves the trace misses and the exit grace drops brace cleanly — no exploit.
- Be GENEROUS (RS2's pure-geometry generosity is its most-praised trait; Sandstorm/HLL's
  strict/hand-tagged eligibility is their most-complained): no angle window beyond the two
  dot filters. Optional later gate: |view pitch| < 45° against sloped-rubble edge cases.

**Scheme B' confirm trace** (runs only while |fLeanAngle| ≥ 22°; fLeanAngle is networked
playerstate, msg.cpp:3375, client-predicted cg_predict.c:444): from origin+(0,0,viewheight)
toward the lean side (flat right-vector, sign convention per solver comment :15486-15493),
length 32u; require solid hit, |normal.z|<0.7, non-Sentient. Release below 15° — the lean
ramp itself (leanSpeed 2 / leanAdd 6, player.cpp:4332-4335) is natural hysteresis.

**Hysteresis:** enter dwell `coop_braceDelay 0.25s` (auto-cover dwell precedent :15325-15329;
side-commit 180 ms precedent :15509 — but first-acquisition latency must stay low, bug-2055
lesson); exit grace `coop_braceGrace 0.35s` (coop_coverGrace 0.5 precedent :15364); distance
band: enter at braceDist 36, sustain trace length braceDist*1.2 = 44 (small ENTER threshold,
generous EXIT threshold — the anti-sticky rule from the CoD complaints).

**Transport (no protocol change, no exe):** all 16 pm_flags bits are allocated (comment
:15655-15660) — publish change-only stufftext `"set coop_braceView %d"` (envelope as 0-100
int), exact SendCoopCoverView pattern player.cpp:15125-15133. The stufftext filter auto-allows
any `set coop_*` (cg_servercmds_filter.cpp:169-173) — zero filter edits. Do NOT overload
coop_coverView (it deliberately sends 0 while peeking, :15127). cgame eases its own local copy
for frame-smooth feel. Cost: worst case 3 point traces/frame/player, gated to
still+grounded frames; TickCoopCover already runs ~22 traces/frame — negligible.

## 5. Implementation plan

| # | Step | File / function | ~LOC | Build |
|---|---|---|---|---|
| 1 | Register cvars (coop_brace, braceDist, braceDelay, braceGrace, braceSpread, braceKick) | fgame G_InitGame cvar block | 10 | game.dll |
| 2 | State + envelope: m_fCoopBrace, m_vCoopBraceNormal, timers; `Player::TickCoopBrace()` (gates, schemes C/A/B', hysteresis, ease, stufftext publish); call after :5644 | fgame player.h (~460 flags area) + player.cpp | 130 | game.dll |
| 3 | Spread hook in BOTH fire-path copies, after stance block | fgame weapon.cpp :1943-1952 area + FT_FAKEBULLET twin ~:2337 | 12 | game.dll |
| 4 | Recoil hook beside breath multiplier | fgame Weapon::ApplyFireKickback weapon.cpp:2546-2557 | 5 | game.dll |
| 5 | Stress damper — server side | fgame player.cpp:14100-14104 | 3 | game.dll |
| 6 | Client mirror: register coop_braceView + coop_braceLag/Sway/Shove, eased local envelope | cgame cg_main.c cvar table + cg_view.c | 25 | cgame.dll |
| 7 | Feel scaling: lag spring :2985/:2996-3009, accel lag :2221-2259, ADS sway :1999-2005, scope sway :2007-2020, recoil shove :2050 area | cgame cg_view.c | 25 | cgame.dll |
| 8 | Stress damper — client twin, IDENTICAL weights to step 5 | cgame CG_FeelStressAdvance cg_view.c:5531-5534 | 3 | cgame.dll |
| 9 | Thunk: edge-trigger pair off local envelope | cgame cg_view.c (breath pattern :1958-1963) | 12 | cgame.dll |
| 10 | Sound assets brace_on/off.wav under sound/coop_brace/ | mod pk3 | — | pk3 only |
| 11 | Optional HUD pip near crosshair, alpha = envelope | cgame 2D draw pass | 30 | cgame.dll |
| 12 | Seed cfg defaults + docs (FEATURES.md, CVARS via docgen) | mod cfg + docs | 10 | pk3 only |

**Ship together:** game.dll + cgame.dll + pk3 in ONE release — the stress twins (5/8) must
move in lockstep, and step 6's cvar consumer needs step 2's publisher. No engine-exe change
(no netfields, no protocol constants). Deploy DLLs to both G:\mohaa-gl2\ and the GOG root per
build.ps1 (bug-1634). Dedicated/listen parity applies: everything server-side is fgame, so
dedicated works by construction; verify both. Test order: step 2 alone with a debug print
(coop_braceDebug), then 3-5, then client feel.

## 6. Open questions for the user

1. **Automatic vs bind?** Recommended: automatic (RS2 model) with `coop_brace 0/1` opt-out.
   A bind-to-commit variant (CoD) is possible later via the bindable-action recipe if
   auto-grabs annoy in playtests.
2. **HUD pip yes/no?** Recommended yes (tiny, near crosshair, envelope-faded) — it is the
   entire discoverability story in RS2. Sound alone is the fallback if HUD feels busy.
3. **All guns, or stronger for MG/heavy?** Recommended: uniform v1; per-class scaling
   (fClassKick weights) is a 5-line follow-up if MGs should reward bracing more.
4. **Thunk local-only or positional?** Local-only (v1). Positional (nearby enemies hear the
   mount, a mild anti-camp tell) is one server Sound() call if wanted.
5. **Numbers** (0.5 spread / 0.4 kick / 0.4 lag / 0.35 sway / 0.7 stress) are starting points
   for a playtest pass — tune live via the cvars, no rebuild needed.
