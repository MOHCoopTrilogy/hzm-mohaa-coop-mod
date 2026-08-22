# Weapon Feel R1 — Risk, Staging, and Whether To Build It

Lens: regression surface, motion sickness, multiplayer, staging, and the case against.
Written 2026-08-20 against the tree at `C:\mohaa-coop-dev`. Read-only pass; no source changed.

Every claim below is `file:line` cited. Numbers are re-derived in place, not asserted.
**PROVEN** = read out of the source this session. **INFERRED** = reasoning on top of proven facts.
**UNVERIFIED** = needs a runtime check before anyone leans on it.

---

## 0. Verdict, up front

**Build it — but not as a new layer.** The single highest-value change is deleting a hardcoded
constant that already exists: `cg_view.c:130` derives the reload camera phase from a **fixed 900 ms**
regardless of weapon. That one number is the whole reason a Garand reload and a Thompson reload feel
identical today. The client already has the true per-weapon reload length (§4.1) and the per-shell
retrigger signal (§4.2), both **networked already, both free**. Fixing that is a smaller diff than
any "add procedural motion" proposal and answers more of the user's ask.

**Before any of that**, `CG_ApplyReloadSway` (`cg_view.c:106-151`) has **three defects that are live
in the shipped build right now** (§2). One of them can throw the camera ~10 degrees on a frame hitch.
Stage 0 is fixing those, and it is a prerequisite, not a nicety — you cannot judge "does this reload
feel different" while an unclamped smoother is occasionally flinging the view.

**Recommended default: ON, SUBTLE, and materially quieter than today** — see §6 for the argument and
the exact numbers.

---

## 1. What is already in the view pipeline

This matters more than any proposal, because the answer to "where does a new layer compose" is
"into an already crowded function". Two writable targets exist, and they behave completely
differently.

### 1a. Writers of `cg.refdefViewAngles` — the CAMERA (rotates the world, moves the crosshair off the bullet)

| Layer | Site | Magnitude | Guarded in ADS? |
|---|---|---|---|
| free-aim camera low-pass | `cg_view.c:2320-2404` | replaces yaw/pitch wholesale | yes — inactive on `BUTTON_COOPADS`/`STAT_INZOOM`/turret (`:2337-2342`) |
| lean roll | `cg_view.c:2408-2416` | `fLeanAngle * 0.1` | yes — `cg_adsLeanRoll` (`:2412`) |
| injury sway | `cg_view.c:2440-2462` | up to **2.2° roll, 1.3° pitch** | **NO** |
| damage_angles + viewkick | `cg_view.c:2467-2469` | engine/vanilla | n/a (vanilla) |
| limp roll | `cg_view.c:1044-1051` | `cg_limpRoll` 1.2 × bob scale | yes — `cg_limpRollAds` 0.25 (`:1046-1048`) |
| scope sway | `cg_view.c:1222-1229` | `cg_scopeSway` 0.25° | intentional; zeroed by breath-hold |
| **reload sway** | **`cg_view.c:106-151`, called `:2643`** | **1.6° pitch + 0.48° roll** | **NO** |
| shell-shock dizziness | `cg_view.c:153-197`, called `:2644` | 5.5° roll / 2.8° pitch / 1.6° yaw at sev 1 | **NO** |

### 1b. Writers of `pREnt->origin` — the VIEW WEAPON (moves the gun on screen, aim untouched)

`cg_view.c:1094-1450`, all inside `CG_OffsetFirstPersonView`'s `!bUseWorldPosition` branch:
ADS sway (`:1210-1216`), recoil (`:1231-1252`), weapon weight/lag (`:1254-1312`), free-aim gun
shift (`:1314-1323`), sprint gun-lower (`:1325-1400`), weapon collision retract (`:1402-1450`).

**This distinction is the load-bearing fact of the whole report.** The 1b layers are geometrically
incapable of moving the point of impact — they translate a model in view space. The 1a layers rotate
the rendered world away from the bullet ray. The project learned this the hard way twice: **bug-165
and bug-168** are the *same* reload-camera feature, tried first against `pREnt->origin` where "a
few-units origin nudge" was "swallowed" by the reload animation, then moved to the camera. Anyone
proposing "more weapon motion" should be pushed toward 1b first; it is the free lane.

### 1c. Ordering — and why it is not obvious

`CG_ApplyReloadSway` / `CG_ApplyShellShock` are called at `cg_view.c:2643-2644`, at the **tail of
`CG_CalcViewValues`**, deliberately: **bug-1942** records that the shell-shock hook was first spliced
by a regex anchored on the *first* `AnglesToAxis(cg.refdefViewAngles` in the file, which sits inside
the `PMF_CAMERA_VIEW` cutscene branch that never runs in normal play — "the dizziness sway was stone
dead". The current placement is the correct one for *reaching every path*. But "every path" is
literal, and that is now a defect in the opposite direction (§2b).

Frame order (PROVEN, from the bug-1250 analysis comment at `cg_view.c:1463-1476` and the call graph):

```
CG_CalcViewValues
  ├─ free-aim / lean / injury / viewkick  →  cg.refdefViewAngles
  ├─ CG_OffsetThirdPersonView()           →  cg.refdef.vieworg   (3P camera POSITION fixed here)
  ├─ PMF_CAMERA_VIEW copy                 →  overwrites angles+org from the cutscene camera
  ├─ CG_ApplyReloadSway / ShellShock      →  cg.refdefViewAngles   ← applies to ALL THREE above
  ├─ AnglesToAxis → cg.refdef.viewaxis
  └─ CG_CalcFov  (underwater test reads the eye HERE)
CG_AddPacketEntities
  └─ cg_modelanim.c:2039 → CG_OffsetFirstPersonView(&model, qfalse)
       ├─ builds the viewmodel basis from cg.refdefViewAngles (cg_view.c:1080)  ← INHERITS the sway
       └─ cg_modelanim.c:2042 re-runs AnglesToAxis
```

Two consequences worth writing down:

1. **The gun cannot detach from the camera during a reload.** The viewmodel basis is rebuilt from the
   already-swayed angles (`cg_view.c:1080-1086`), so the gun rides the lift and holds its screen
   position. That is *why* the current effect reads as "the camera moves with the gun" and not as
   "the gun slides". Any new camera-rotation layer inherits this for free. **PROVEN.**
2. **Sound does not sway.** `SoundAngles` is captured at `cg_view.c:2532`, 111 lines *before* the sway
   is applied. Harmless at 1.6°; would become an audible decoupling if anyone scaled it up. **PROVEN.**

---

## 2. Three defects live in the shipped reload sway

These are not hypotheses. They are readable in `cg_view.c:106-151` today.

### 2a. The smoother is unclamped — the only one in the file that is

```c
fDt   = cg.frametime * 0.001f;                                    // cg_view.c:143
fRate = (iAnim == 8) ? 11.0f : ((fTarget > s_reloadLift) ? 7.0f : 4.5f);
s_reloadLift += (fTarget - s_reloadLift) * fRate * fDt;           // cg_view.c:145
```

`k = fRate * fDt`. An exponential smoother is stable only for `k <= 1`; at `k > 2` it diverges.
`cg.frametime` is the raw wall-clock frame delta handed in by the client (`cg_view.c:2905`,
`cg.frametime = frameTime`) and is **not** bounded.

Every other smoother in this same file clamps it. Weapon lag: `k = fStiff*dt; if (k > 1.0f) k = 1.0f`
(`cg_view.c:1279-1280`). Free-aim: same clamp twice (`:2331`, `:2388`). Limp: `dt` clamped to 0.25
(`:929`). Sprint: `dt >= 0.5` snaps instead of easing (`:1381`). Weapon collision: identical
(`:1438`). The ragdoll goes further — `if (cg.frametime <= 0) return;` (`cg_ragdoll.c:2293`) and its
header spec is `accumMs += min(frametime,200)` (`cg_ragdoll.c:31`). **The project already knows
`cg.frametime` spikes.** `CG_ApplyReloadSway` is the one place that forgot.

Worked example, `RELOAD_END` (`fRate` 11), `coop_reloadSway` at its default 1.6:

| hitch | k | lift before | lift after | camera pitch applied |
|---|---|---|---|---|
| 16 ms (normal) | 0.176 | 1.60 | 1.24 | −1.24° |
| 200 ms | 2.20 | 1.60 | **−2.91** | **+2.91°** and roll −0.87° |
| 500 ms | 5.50 | 1.60 | **−9.66** | **+9.66°** and roll −2.90° |

Derivation for the 200 ms row: target = `1.6 × −0.28` = −0.448; error = −0.448 − 1.60 = −2.048;
`s += −2.048 × 2.20` = 1.60 − 4.506 = −2.906.

A 200-500 ms hitch during a reload is an ordinary event in this game (streaming, a first-time
shader compile, a `snd_restart`). **Severity: this is almost certainly the mechanism behind any
"the camera jerked and I don't know why" report the user has had since 2026-08-19.**
Also unguarded: negative `cg.frametime` drives the lift *away* from target.

**Fix (one line):** `if (fDt > 0.05f) { fDt = 0.05f; } else if (fDt < 0.0f) { fDt = 0.0f; }`
before line 145. **INFERRED severity, PROVEN mechanism.**

### 2b. No state guards at all

```c
if (pRS->value <= 0.0f || !cg.snap) { s_reloadLift = 0.0f; return; }   // cg_view.c:117-120
```

That is the entire guard. Compare the neighbours: head bob damps ×0.25 under ADS or `STAT_INZOOM`
(`cg_view.c:983-985`); limp roll damps by `cg_limpRollAds` (`:1046-1048`); lean roll by
`cg_adsLeanRoll` (`:2411-2416`); weapon lag by `cg_weaponLagADS` and skipped while scoped
(`:1272`, `:1296`); the suppression and hit-tint clears were widened to `PMF_SPECTATING |
PMF_INTERMISSION` after **bug-1306** proved `h <= 0` misses spectators (`Player::Spectator()` leaves
health at max). The reload sway checks none of it. Concretely, today it is applied:

- **while ADS** — see §3.2 for the quantified aim consequence;
- **while scoped** (`STAT_INZOOM`) — the sniper's world pitches while the scope overlay stays fixed;
- **in third person** — after `CG_OffsetThirdPersonView()` has already committed the camera
  *position* (`cg_view.c:2604`), so the chase camera rotates in place while the player model does
  not move with it. At `fov_y` 73 on a 1080p screen, 1.6° ≈ **1.6/73 × 1080 = 24 px** of world slide
  under a static model. Small, but it is a first-person-only effect leaking into a mode where it is
  meaningless — exactly the class the user flagged in bug-296/bug-329;
- **during cutscene cameras** — the `PMF_CAMERA_VIEW` branch (`:2612-2638`) copies `camera_angles`
  in, then the sway is added on top at `:2643`. Reload as a scripted camera takes over and the
  cinematic pitches;
- **while dead or spectating** — the `bug-1306` hole, reopened.

### 2c. `fPhase` has no lower clamp

```c
float fPhase = (cg.time - s_iVMAStart) * (1.0f / 900.0f);
if (fPhase > 1.0f) { fPhase = 1.0f; }                    // cg_view.c:130-133 — upper only
fTarget = pRS->value * (0.62f + 0.38f * fPhase);
```

`s_iVMAStart` is a function-local `static` (`cg_view.c:124`), so it survives map changes — DLL
statics are not reset by `CG_Init`. If `cg.time` moves backwards (map_restart, demo seek) while
`iAnim` happens to be unchanged, `fPhase` goes large-negative and `fTarget` is unbounded below.
Narrow (it needs the anim to be identical either side of the discontinuity) but free to close:
clamp `fPhase` to `[0,1]` and reset the statics when `cg.time < s_iVMAStart`. **PROVEN mechanism,
INFERRED (low) likelihood.**

---

## 3. The regression surface, consumer by consumer

### 3.1 The crosshair — and the counterintuitive part

The first-person crosshair is placed at screen centre and then offset by **exactly one term**: the
free-aim deadzone, via `CG_GetFreeAim` (`cg_drawtools.cpp:1534-1545`, reading `s_faYaw`/`s_faPitch`
from `cg_view.c:699-707`). Nothing else. So **any degree written into `cg.refdefViewAngles` after
the free-aim block is an uncompensated divergence between where the crosshair is drawn and where the
round goes** — bullets leave along `ps->viewangles` (server authoritative), the world renders along
`cg.refdefViewAngles`.

The third-person crosshair is *not* exposed: `cg_drawtools.cpp:1486-1530` traces the real bullet ray
from the eye and re-projects the impact point through the offset camera, so it self-corrects for any
camera perturbation. **First person is the fragile case, third person is the safe one** — the
opposite of what you would guess, and the opposite of where the ADS anxiety usually points.

Miss at 1° of residual sway: `tan(1°) = 0.01746` → **5.2 units at 300**, **17.5 units at 1000**.
A soldier is ~72 units tall; a torso ~20 wide. So a degree is a quarter-torso at short range and a
near-miss at long range.

**Live test:** `ui_crosshair 1`, stand at a wall corner ~300 units away, fire single shots while the
reload tail is decaying (fire the instant the mag seats). Bullet decal offset from the crosshair =
the defect, directly measurable with a screenshot.

### 3.2 ADS sight alignment — the sacred one, quantified

While ADS the crosshair is **hidden** (`cg_drawtools.cpp:1387-1398`, returns early on
`BUTTON_COOPADS` + alive + not zoomed + not 3P), so the reference is the iron sights themselves. The
sights are part of the viewmodel, whose basis is rebuilt from the *already-swayed* angles
(`cg_view.c:1080`). So the sights **stay visually aligned and lie by exactly the sway amount**. There
is no visible tell. That is worse than a visible misalignment, not better.

The saving grace is that you cannot fire during a reload. The exposure is the **tail**:

- Magazine weapons (`RELOAD` → `IDLE`, no `RELOAD_END`): decay from 1.6° at rate 4.5/s.
  `s(t) = 1.6·e^(−4.5t)`. At t = 0.2 s (a realistic "mag seated, fire") → **0.65°**; at 0.4 s →
  0.26°; below 0.1° at t = ln(16)/4.5 = **0.62 s**.
- Weapons with a cock (`RELOAD_END`, target −0.448 at rate 11, then → 0 at rate 7):
  |residual| < 0.1° by t = ln(4.48)/7 = **0.21 s**. Much better, by accident.

So the honest statement is: **the first shot after a magazine reload lands up to ~0.65° off the iron
sights, decaying over ~0.6 s.** That is 3.4 units at 300, 11 at 1000 — real, small, and worth closing
with an explicit ADS scale rather than leaving to luck.

**Prescription for any layer in this family, and for the existing one:**
scale by `cg_reloadSwayADS` (proposed default **0.25**, matching the established `cg_weaponLagADS`
0.35 / `cg_limpRollAds` 0.25 / head-bob 0.25 convention), and **force the residual to a hard zero**
below a threshold — `if (fabs(s_reloadLift) < 0.02f) s_reloadLift = 0.0f;`. Exponential decay never
reaches zero, and the project's own scope-sway design (`cg_view.c:1222`) already encodes the
principle: *sway is allowed, but it must be exactly zero in the state where the player shoots
precisely* ("holding breath stops it — a steady shot is then dead-on").

Note the precedent cuts both ways: **injury sway violates that principle today** — up to 2.2° roll
and 1.3° pitch, never returning to zero while wounded, with no ADS damping
(`cg_view.c:2440-2462`) — and it has shipped since 2026-08-02 without a complaint. That is real
evidence that the user's tolerance for aim-decoupled sway is higher than this analysis implies.
Do not use it as licence; do use it to avoid over-engineering.

### 3.3 The sniper scope — the parallax fix this could re-open

The 3P sniper parallax defect was fixed by force-first-person on `STAT_INZOOM`, and it needed
**two** assertions because ordering broke it once: `cg_view.c:2559` sets it, then the cover
force-3P at `:2576` undid it, so `:2582` re-asserts it — **bug-329**, "scope overlay renders while
the camera is still behind the player". The comment at `:2578-2582` is explicit: *"NATIVE ZOOM IS
FINAL: re-assert first person AFTER every 3P force above."*

The reload sway runs at `:2643`, **after all of that**, and does not test `STAT_INZOOM`. It does not
re-open bug-329 (it cannot change `renderingThirdPerson`), but it does pitch the scoped world under a
fixed reticle. Two failure modes to test:

- **Scoped reload.** Springfield/Enfield: hold zoom, reload. Does the scope picture lurch?
- **Bolt-action `RELOAD_END`.** Bolt guns are exactly the ones that use `RELOAD_END` (the cock), so
  they get the −0.28 undershoot at rate 11 — the fastest slew in the whole layer — while the player
  may still be scoped.

**Live test:** m3l1b or any map with a Springfield. Scope in, fire, let it rechamber. Watch whether
the scope picture moves independently of the mouse. Rollback: `coop_reloadSway 0`.

### 3.4 Shell-shock / tinnitus — the neighbour, and the insertion-point trap

`CG_ApplyShellShock` (`cg_view.c:153-197`) sits **immediately after** the reload sway, on the same
angle vector, and is far louder: 5.5° roll, 2.8° pitch, 1.6° yaw at severity 1, decaying over
`coop_dizzyTime` 4.2 s. **They compose additively with no arbitration.** A grenade beside you while
you reload gives you both at once — up to ~7° of pitch. Nothing clamps the sum.

Two documented traps live here and both are about *insertion points*, which is precisely what a new
layer does:

- **bug-1942**: the shell-shock call was spliced by a regex that matched the wrong occurrence of
  `AnglesToAxis(cg.refdefViewAngles`, landing in a dead cutscene branch. Lesson recorded verbatim:
  *"verify WHICH occurrence matched and what branch encloses it — read the surrounding function, not
  just the matched line."*
- **bug-1941**: the dizziness stufftext was inserted **between** a `coop_blastPing` read and its NIL
  guard, throwing 2283 script errors in one session. Lesson: *"insert INSIDE its guard, not between
  read and guard."*

`docs/TRAPS.md:189-194` generalises it: *"In a render/view path, grep the whole function for every
assignment to that field and prefer the LAST write site... The dangerous variant is a misplaced write
that still lands somewhere real (bug-1238 moved the 3P pivot) — then it is not a no-op but a silent
corruption of a neighbouring feature, possibly one being tuned right then."*

**Recommendation:** do not add a fourth independent `vAngles[...] +=` site. Introduce a single
`CG_ApplyViewFeel(vec3_t)` that sums the cosmetic contributions and **clamps the total** (proposed
±6° pitch, ±8° roll) before writing once. That also gives shell-shock a ceiling it does not currently
have. This is a refactor risk in itself — stage it separately (§7 Stage 3), never bundled with a
feel change, or you cannot attribute what the user sees.

### 3.5 Third person and free-cam

`cg_freecam` orbit angles live in the **client exe** (`cl_main.cpp` camera_offset, read back through
`cgi.get_camera_offset()`, `cg_view.c:1703-1707`) and are applied inside
`CG_OffsetThirdPersonView`. The reload sway lands after that, so it rotates the orbit camera about
its own position. Same 24 px artifact as §2b.

The freecam family is the project's worst view-regression cluster and is worth reading before
touching this area: **bug-308** (hard segfault the frame cover engaged — `cgi.get_camera_offset(NULL,
NULL)` writes both out-params unconditionally), **bug-321/325/326/327** (pitch wedging past the pole
from *double-applied* orbit — the camera applied the orbit on top of a usercmd that already carried
it). The lesson that matters here: **a view offset applied in two places is a stuck camera, not a
double-strength effect.**

The good news is architectural and absolute: **cgame has no way to write aim.** `cg_public.h`
contains no `viewangles` setter of any kind, and no cgame file references `cl.viewangles`. Anything
written into `cg.refdefViewAngles` or `pREnt->origin` is render-only by construction. The freecam
needed an exe change *precisely because* it wanted to affect aim. **PROVEN.**

### 3.6 HUD fade — a non-issue, confirmed

`cg_drawtools.cpp:2057-2074` wakes the HUD on any delta of
`STAT_AMMO * 1024 + STAT_CLIPAMMO`. A reload always changes that, so the HUD is already up for the
whole reload. No interaction, no work needed. **PROVEN.**

---

## 4. Signals: what the client can actually see, and when

The prompt's concern — *"a layer driven by a value that arrives a frame late will read as a
glitch"* — has a clean answer here, and it is the strongest argument for keeping the current driver.

| Signal | Source | Latency vs the gun animation |
|---|---|---|
| `iViewModelAnim` | `cg.snap->ps` (`cg_view.c:118`) | **zero** — same snapshot the animation reads |
| `iViewModelAnimChanged` | `cg.snap->ps` (`cg_viewmodelanim.c:500`) | **zero** — same snapshot |
| `STAT_CLIPAMMO` | `cg.snap->ps` (`cg_view.c:1105`) | **zero** — same snapshot |
| `g_iCurrentVMDuration` | `cgi.anim` (`cg_viewmodelanim.c:620`) | one frame (~16 ms), client-local |
| velocity / origin | `cg.predicted_player_state` | **leads** the snapshot by up to one snapshot interval |
| stamina | client-side *mirror* (`cg_view.c:1336`) | immediate but **can drift** — not networked |
| suppression | client-local accumulator (`cg_view.c:546`) | immediate |

**The key result:** the camera driver and the viewmodel animation read the *same field of the same
snapshot* (`cg_view.c:118` vs `cg_viewmodelanim.c:500-503`). They are latency-locked and **cannot
desync by construction** — on a listen host, on a remote client, at any ping.

The corresponding hazard: `cg.predicted_player_state` is *ahead* of `cg.snap`. `sv_fps` defaults to
20 (`sv_main.c:1089-1090`), so that is up to 50 ms plus latency. **A weapon-feel layer driven from
predicted velocity would lead the gun animation by up to 50 ms — the camera moving before the gun
does.** That is exactly the "glitch" failure the prompt anticipates. Anything reacting to the
weapon must read `cg.snap`.

### 4.1 The per-weapon reload length is already available — this is the finding that matters

`cg_view.c:130` hardcodes **900 ms** for every gun in the game. That single constant is why every
reload feels the same. Three routes to the real number, none of which touch the protocol:

1. `cgi.anim->g_iCurrentVMDuration` (`q_shared.h:2286`) — elapsed ms inside the current viewmodel
   anim, zeroed at `cg_viewmodelanim.c:590` and accumulated at `:620` by the same code that starts
   the animation. **A strictly better phase clock than `cg.time - s_iVMAStart`**, because it is
   reset by the anim system rather than by a duplicated edge-detector.
2. `cgi.Anim_Time(tiki, animnum)` (`cg_public.h:387`) with
   `cgi.anim->g_VMFrameInfo[cgi.anim->g_iCurrentVMAnimSlot].index` (`q_shared.h:2281,2285`) — the
   true total duration of the reload animation actually playing.
3. The tiki handle from `cg_view.c`: `cgi.TIKI_FindTiki(CG_ConfigString(CS_WEAPONS +
   cg.snap->ps.activeItems[1]))` (`cg_public.h:432`; the configstring pattern is used at
   `cg_viewmodelanim.c:156,474`), cached on an `activeItems[1]` change exactly as
   `cg_viewmodelanim.c:473-481` caches its prefix index. **UNVERIFIED** — this specific call has not
   been run from `cg_view.c` and is the one thing Stage 1 must prove before anything is built on it.

With the real duration, a Garand (long, two-handed, en-bloc) and a Thompson (short stick-mag swap)
diverge **automatically, from data the artists already authored**, with no per-gun table to maintain
and nothing new on the wire. Compare: `bug-1888` found the Type 100 shipping five unused first-person
animations including a **76-frame reload** that nothing was playing. The animation data has more
per-weapon character in it than any procedural layer would invent.

### 4.2 Per-shell variation needs the 2-bit counter, not the anim id

For shell-by-shell reloads the state stays `VM_ANIM_RELOAD_SINGLE` (7) across every shell, so the
current edge-detector (`cg_view.c:123-127`, keyed only on `iAnim != s_iLastVMA`) **cannot see shell
boundaries at all** — which is why `:135-136` just holds a flat `0.7 ×` lift for the whole thing.

`iViewModelAnimChanged` is incremented at `player.cpp:13151`
(`(playerState->iViewModelAnimChanged + 1) & 3`) on **every anim start including a `force_restart` of
the same anim**, and is networked at 2 bits (`msg.cpp:3358`). It is the per-shell retrigger signal,
it is already on the wire, and `cg_viewmodelanim.c:500` already consumes it. **A shotgun where each
shell gives its own small lift, and the last one lands differently, is available today for the cost
of reading one more field.**

### 4.3 The hard protocol ceiling — price this loudly

`iNetViewModelAnim` is networked at **4 bits** (`msg.cpp:3367`, `:3429`). `enum vmAnim_e`
(`bg_public.h:160-176`) defines **15 values, 0..14**: DISABLED, IDLE, CHARGE, FIRE, FIRE_SECONDARY,
RECHAMBER, RELOAD, RELOAD_SINGLE, RELOAD_END, PULLOUT, PUTAWAY, LADDERSTEP, IDLE_0, IDLE_1, IDLE_2.
Four bits hold 0..15. **One spare code.** Under protocol 6 the value is shifted by ±1
(`bg_compat.cpp:100-107`), consuming that headroom.

So: **any design wanting new server-driven weapon states — a distinct "mag out" vs "mag in", a
"fumbled reload", a "check chamber" — is a protocol widening.** That means `exe + cgame + game` ship
together, the class of change that produced the entity-pool and `MAX_SNAPSHOT_ENTITIES` saga
(bug-1186's "MISSED 4th member... silent discard"). Price it at a multi-session risk, not a feature.
**Every recommendation in this report deliberately stays inside the existing 4 bits.**

---

## 5. Multiplayer: confirmed, nothing needs to agree

**Confirmed client-local and cosmetic.** The layer writes only `cg.refdefViewAngles` → `cg.refdef.viewaxis`
and `pREnt->origin`. It never writes `cl.viewangles` or the usercmd; cgame has no import that can
(`cg_public.h` has no viewangles setter; no cgame file references `cl.viewangles`).

Three specific "does this need to agree" checks:

1. **Between clients:** no. Each client renders only its own first-person view. Player A's reload
   camera is invisible to Player B — B sees A's *world model* animation, driven by a separate path.
2. **Client vs server:** no. Bullets use `ps->viewangles`; the server never reads `refdefViewAngles`.
   This is stated in `bug-168`'s fix note and holds by construction (§3.5).
3. **Randomness:** `random()`/`crandom()` (`q_shared.h:826-828`) are available in cgame and already
   used (`cg_view.c:2694-2696`, `cg_ragdoll.c:2240`). They are **unsynchronised**, which is correct
   here — nobody else needs to see the same variation. Per-reload variety therefore costs nothing.
   The one caution: seeding from `rand()` makes the effect non-reproducible, so **any A/B instrument
   must be able to force the seed** or the user cannot compare two builds.

**Listen-host vs dedicated:** the standing rule is *listen-only is a defect, whole trilogy*
(`dedicated_listen_parity`). This layer is symmetric — it depends only on `cg.snap`, which both hosts
and remote clients have. The one asymmetry to watch is the **stamina mirror** (`cg_view.c:1336`),
which reconstructs a server-side pool from cvars and will drift on a remote client. **Do not drive
any new weapon-feel term from stamina.** Drive it from `cg.snap` fields.

---

## 6. Motion sickness, accessibility, and the default

### The honest state of the evidence

I will not invent a percentage. I have no measured figure for how many players disable procedural
camera motion, and asserting one would be exactly the failure `bug-1290` records — *"Agreement
between reviewers is NOT corroboration when they share an upstream source."*

What is defensible: camera-motion options (view bob, camera shake, weapon sway, motion blur, FOV) are
among the first settings players change, and shipping them as toggles is now standard practice in
mainstream shooters precisely because a minority experiences real discomfort. That is **INFERRED**
general knowledge and should be labelled as such.

What is **PROVEN**, and local, and better evidence than any industry figure:

- This user has asked for a screen effect to be **removed** as recently as `bug-1547`:
  *"lets remove the frozen effect on screen for when it snows it looks really bad."*
- Corpse despawn ships **default 0 = OFF, per the user's explicit choice**
  (`corpse_despawn` memory: "DEFAULT 0=OFF per user").
- The user's own stated preference is that **every visual-effect enhancement must be exposed in the
  in-game settings UI with a toggle** (`docs/21-user-preferences.md:89`).

The relevant distinction is **event-driven vs continuous**:

| | discomfort risk | example here |
|---|---|---|
| **event-driven** — fires on a discrete action, decays to zero | low; the player caused it and it ends | reload sway, recoil, weapon collision |
| **continuous** — always running while a state holds | **high**; nothing to attribute it to, no end | injury sway, scope sway, head bob |

**Everything recommended in this report is event-driven.** That is not incidental — it is the reason
"ON by default" is defensible at all. A proposal for *continuous* idle weapon drift or a persistent
"breathing camera" should default **OFF**, and I would push back on building it.

### Recommendation: ON, SUBTLE, quieter than today

**ON**, because it is event-driven, self-terminating, and answers an explicit user request from
2026-08-19. **SUBTLE**, because 1.6° peak is not subtle for a WW2 shooter played for hours.

Reduce the default. The rationale is a comparison against the file's own established magnitudes:
weapon lag maxes at 3.5 *units* of model translation (`cg_weaponLagMax`, `cg_view.c:1266`) — a 1b
layer that cannot affect aim at all — while the reload sway spends **1.6° of camera rotation**, the
lane that does. Scope sway, the layer designed to be *felt*, is 0.25°. Lean roll is
`fLeanAngle × 0.1`. **1.6° is the loudest event-driven camera term in the file by a wide margin.**

Proposed defaults:

| cvar | today | proposed | why |
|---|---|---|---|
| `coop_reloadSway` | 1.6 | **1.0** | still clearly visible; ~40% less residual aim error |
| `coop_reloadSwayADS` | — | **0.25** | matches `cg_limpRollAds` / head-bob 0.25 |
| `coop_reloadSwayVary` | — | **0.35** | ±35% per-reload variation — the actual feature |
| (hard zero threshold) | — | **0.02°** | kills the exponential tail so the sights stop lying |

**Menu exposure.** `hzm-mohaa-coop-mod/ui/coop_settings.urc` is an 11-row checkbox list
(`:6` menu decl, rows at `:77`-`:336`) plus a POST-FX sub-page (`:343-354`). Add one row,
**"Reload Camera"**, in the pattern of `cbSway` (`:156-167`).

> **Trap, and it is live today.** These are `CheckBox` widgets with `linkcvar`, which write **0 or
> 1**. The existing "Weapon Sway" row is `linkcvar "cg_weaponLag"` (`coop_settings.urc:164`) whose
> compiled default is **0.7** (`cg_view.c:1262`). Ticking that box sets it to **1.0** — a silent
> **+43%** intensity change the player never asked for, and it is `CVAR_ARCHIVE`, so it persists.
> This is the `docs/21-user-preferences.md:110` trap verbatim: *"A `CVAR_ARCHIVE` cvar with a stale
> saved value silently re-breaks features."*
> **Never `linkcvar` a magnitude cvar to a checkbox.** Bind the checkbox to a separate binary
> `coop_reloadCam` (0/1) and keep `coop_reloadSway` as the magnitude, read only when the toggle is on.
> Worth logging the `cg_weaponLag` case as its own bug regardless of this feature.

---

## 7. Staging

Ground rules from `docs/21-user-preferences.md`: the user is the **sole tester** (`:49-56`),
**"do the commands yourself and watch console yourself"**, **instrument before fixing** (`:169-175`),
and **"two failed attempts on the same symptom is the budget — then REVERT"** (`:137`). Each stage
below answers exactly one question, ships one number, and has a one-line rollback.

### Stage 0 — Stabilise (prerequisite, no feel change)

**Question:** is the existing effect free of the hitch flip?
**Change:** clamp `fDt` to `[0, 0.05]`; clamp `fPhase` to `[0,1]` and reset the statics on a backwards
`cg.time`; add the ADS/scope/3P/camera/alive guards; hard-zero below 0.02°.
**Instrument:** `coop_feelDebug 1` prints, once per reload,
`RELOADCAM w=<weapon> dur=<ms> peak=<deg> resid@100ms=<deg> maxdt=<ms>`.
**Acceptance:** `maxdt` never exceeds 50; `peak` never exceeds `coop_reloadSway`; the user reports
**no** unexplained camera jerks in a full map.
**Rollback:** `coop_reloadSway 0`.
**This is the only stage with a correctness claim.** Everything after it is taste.

### Stage 1 — Real duration (the answer to the user's ask)

**Question:** does a Garand reload feel different from a Thompson reload?
**Change:** replace the hardcoded 900 ms (`cg_view.c:130`) with the true anim duration (§4.1). Prove
the tiki lookup first — it is the one **UNVERIFIED** step.
**Instrument:** the Stage 0 print already carries `dur=`. Run the armory and log every gun.
**Acceptance:** `dur` differs across weapons and matches the TIKI. Then, subjectively: reload a
Garand and a Thompson back to back and say which is heavier.
**Rollback:** `coop_reloadSwayFixed 900` restores the constant.
**This stage alone may close the request.** Ship it, get a verdict, then decide about Stage 2.

### Stage 2 — Variation (the literal "no reload the same twice")

**Question:** can the user tell two consecutive reloads of the *same* gun apart?
**Change:** on each `iViewModelAnimChanged` edge, roll `crandom()` into a ±`coop_reloadSwayVary`
scale on peak, a small phase jitter, and a small roll-sign bias. Bounded, decays to the same zero.
Per-shell for `RELOAD_SINGLE` via the 2-bit counter (§4.2).
**Instrument:** print the rolled scale per reload; `coop_reloadSwaySeed <n>` forces a fixed seed so
an A/B is reproducible.
**Acceptance:** with `coop_reloadSwayVary 0` vs `0.35`, the user picks which build is which
**blind**, from consecutive reloads of one gun.
**Rollback:** `coop_reloadSwayVary 0`.
**Honest expectation:** at ±35% of a 1.0° effect the delta is ±0.35°. **I would not bet on the user
passing that blind test.** Stage 1 is where the perceptible difference lives, because a Garand vs a
Thompson differ by hundreds of milliseconds, not by fractions of a degree. Say so before building it.

### Stage 3 — Arbitration refactor (only if Stages 0-2 land)

**Question:** can reload + shell-shock + injury be summed and clamped without changing how any of
them looks alone?
**Change:** one `CG_ApplyViewFeel(vec3_t)` summing all cosmetic contributions with a total clamp
(±6° pitch, ±8° roll), replacing three independent `+=` sites.
**Acceptance:** with only one effect active at a time, the user reports **no change** vs the previous
build. A refactor whose success criterion is "identical" — anything else is a regression.
**Rollback:** revert one commit.
**This is a cleanup, not a feature. Never bundle it with a feel change** — you lose attribution
(`docs/21-user-preferences.md:83`, *"never trade one visible artifact for another silently"*).

### The stage that would be a trap to build first

**Any new always-on procedural motion layer** — idle weapon drift, a breathing camera, "weight" that
follows movement. Four reasons, in order of force:

1. It would be built on top of an **unclamped smoother that can already flip the camera** (§2a). The
   first hitch would be blamed on the new feature, and a whole session would go into the wrong file —
   the `bug-1290` shape, where one bad premise poisons every conclusion downstream.
2. It is **continuous**, so it lands in the high-discomfort column of §6 and would need to default
   OFF — which means the user does not see it unless they go looking, which means it does not answer
   the request.
3. The natural driver is **predicted velocity**, which leads the animation by up to 50 ms (§4) and
   reads as a glitch.
4. It solves a problem the user did not state. The ask was *"no reload should feel the same"* —
   a per-reload variation problem, not an ambient-motion problem.

The second trap, smaller: **do not start with a per-weapon tuning table.** The project has one
already (`cg_adsTune`, `ads_pergun_tune_table`) and it has open unfinished entries (SVT, G43, Breda,
Springfield). A second table across 69+ armory guns plus 18 xw imports would rot the same way. The
animation data is the table (§4.1).

---

## 8. The case against — argued as hard as I can

**1. The original request was already answered.** The user said *"when you reload i'd like the camera
to move with it... gun gets lifted up to pull out mag, cam goes up, mag goes in, cam back down"*
(`cg_view.c:98-101`). That shipped on 2026-08-19 and is in `docs/HISTORY.md` in the mega-wave line.
The new ask arrived *before any reported playtest verdict on it*. There is a real possibility that
the correct response is **"play the build you have and tell me what's wrong with it"**, not a second
feature. `docs/21-user-preferences.md:145`: *"Say plainly when something is not built"* — the
converse applies. Something IS built; find out if it works first.

**2. MOHAA's weapon feel is load-bearing identity.** The 2002 gunplay is deliberate, planted,
animation-first — the fixed camera *is* the thing that makes a Garand ping land. The engine's own
`vm_offset_speed` machinery (`cg_viewmodelanim.c:734-748`) and the baked per-gun ADS alignment exist
because the original designers chose to place the weapon precisely. There are now **six** distinct
layers perturbing the view weapon and **eight** perturbing the camera (§1). Every one was individually
justified. Nobody has evaluated the sum, and the sum is what the player experiences. Adding a ninth
is the wrong direction; the honest move might be an audit that **removes** one.

**3. Procedural view motion is the most-disabled feature category in modern shooters.** If a
meaningful fraction of players will turn it off, effort spent on it is effort spent on a setting.
(Labelled INFERRED, per §6.)

**4. The opportunity cost is concrete and it is not close.** The ragdoll work is unfinished with a
**known, named, open defect**: `bug-1964` — *"mesh clumped/slid forward/fell through floors WHILE the
sim skeleton settled correctly"*. That is a solver that works and a render path that does not, with
measured evidence already in hand (`ragdoll_r12_session_swing.log`, `ragdoll_p3_session_2200.log`, a
bone-swing-in-degrees instrument, and **thirty-plus** `ragdoll_r*` design documents in `_research/`).
Every enemy death in the game runs through it. Compare the AI: `bug-1976` found that **every AI hit
reaction has played the wrong limb since the feature shipped** — a right arm flinched the back, a
right leg flinched the left arm — across 94 whitelist entries, because `hitloc_t`
(`q_shared.h:1426-1449`) starts HEAD, HELMET, NECK, TORSO_UPPER and the map was written assuming
0-3 were heads. And `bug-1957`/`bug-1971` still have Germans running around **with no weapons**.
**Enemies with no guns is a worse problem than reloads that feel similar, by a wide margin.**

**5. Precision.** Every degree added to the camera is a degree of divergence between the crosshair and
the bullet in first person (§3.1), because the first-person crosshair compensates for exactly one
term and this is not it.

### Do I believe it?

**Points 1, 2, 4 and 5 — yes, with force. Point 3 — as stated, no.**

Point 3 conflates two things §6 separates. *Continuous* camera motion is the disabled category.
*Event-driven* motion tied to a discrete player action is not — nobody turns off recoil. So point 3
argues correctly against a feature nobody should build and not at all against the one on the table.

Point 4 is the strongest and I would act on it: if this were a priority call rather than a design
question, **the ragdoll render-path defect and the weaponless-AI bug both outrank this.**

But points 1 and 4 do not survive contact with the actual proposal, because **the proposal collapses
to a bug fix.** Stage 0 is repairing an unclamped smoother that can flip the camera ten degrees —
that is not feature work under any reading, and it should happen whether or not anyone ever builds
Stage 1. Stage 1 is deleting a hardcoded 900 ms in favour of a number the animation system already
computes — a smaller diff than most of the fixes in this week's buglog, no protocol change, no new
layer, no new tuning table, and it makes a Garand and a Thompson genuinely diverge because the
*artists* made them diverge.

Point 2 is the one I would hold the line on, and it sets the shape of the recommendation: **the way
to honour MOHAA's weapon feel is to let the weapon animations drive the camera instead of inventing
motion beside them.** That is Stage 1 exactly, and it is why Stage 1 is the whole recommendation and
Stages 2-3 are optional.

So: **Stage 0 unconditionally. Stage 1 as the answer. Stop and get a verdict. Treat Stage 2 as a
coin-flip and say so before spending a playtest on it. Stage 3 only as hygiene.** And say out loud
that the ragdoll and the AI outrank all of it.

---

## 9. Test cfgs to ship with it

Following the `rag_drill.cfg` / `rag_ab.cfg` pattern (`hzm-mohaa-coop-mod/coop_mod/cfg/`) — armed
from a cfg, **not** a `+set` on the command line, because `autoexec.cfg` execs last and would
override it (`docs/21-user-preferences.md:113`, T7/bug-710).

- **`feel_probe.cfg`** — `developer 1` (required: script `println` and compile errors are gated
  behind it) + `coop_feelDebug 1`. Echo: *"Reload each gun once. Watch for RELOADCAM lines."*
- **`feel_off.cfg`** — `coop_reloadSway 0`. The one-command rollback, bind it to a key.
- **`feel_ab.cfg`** — toggles `coop_reloadSwayVary` between 0 and 0.35 with a fixed
  `coop_reloadSwaySeed`, for the Stage 2 blind test.

Per `docs/21-user-preferences.md:36`, tell the user first if any of this pops a window, and per
`:63-66`, **build and deploy before asking them to test** — source edits are invisible in-game until
`build.ps1` (scripts/cfg) or a rebuild plus manual copy (cgame/fgame/exe). This feature is
**cgame-only**; it does not need the exe or `game.dll`, so it ships as a single `cgame.dll` to
`G:\mohaa-gl2\` *and* the GOG root (bug-1634 — the GOG root alone never reaches the running game).
