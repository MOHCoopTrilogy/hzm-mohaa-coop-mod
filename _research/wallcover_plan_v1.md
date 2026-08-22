# Wall Cover v3 - research + design plan

**Status:** DESIGN ONLY. No code written. 2026-08-21.
**Scope:** re-enable standing WALL cover; make the pop-out / blindfire side automatic on a
doorway; add A/D slide along cover.

**User ask (verbatim):**
> "make the wall cover work now, it used to crash when we built before. It needs to work and be
> smart enough to know which side you are wanting to blindfire and pop out of cover from. Think
> of a doorway, you could be in cover on either side and you would need blindfire and third
> person ads to work automatically depending on where the opening is, that was always an issue.
> There are definitely animations there, the second and hard part will be being able to actually
> move along the cover itself with A and D keys. We have an auto cover feature already built, but
> we also have a keybind."

---

## 0. Verdict in one paragraph

Wall cover is not missing. It is **fully built and switched off by a single `if (false)`** at
`openmohaa-hzm/code/fgame/player.cpp:13805`. Every statemap state, every engine conditional and
every animation alias it needs still exists and still compiles. It was disabled (bug-463) because
its pop-out was a **server-side `setOrigin()` that pushed the player's collision hull toward the
corner** and could shove them into geometry. The correct fix is not to make that origin write
safer - it is to **stop writing origin at all** and drive the pop-out with the engine's own
`ps->fLeanAngle`, which is already replicated, already client-predicted, already applied to the
camera, the view roll, the eye position and the viewmodel, and which **cannot move the collision
hull**, so the entire crash class becomes structurally impossible. The doorway-side problem is a
scoring function over lateral traces plus view intent. The A/D slide is a `wishdir` clamp in
shared `bg_pmove.cpp` plus one `client->ps.speed` scale. **Nothing in this plan needs a protocol
change, a new pmove flag or a new configstring - and, per section 6, none is available.**

---

## 1. Evidence base and method

`.wolf/buglog.json` filtered precisely (word-boundary `cover` **not** preceded by `re`/`dis` and
**not** followed by `age`, union with `blindfire` / `blind fire` / `lean` / `peek` / `corner` /
`PMF_COOP_COVER` / `takecover` / `coop_cover` / `wallcover`):

> **151 real cover entries** out of 1,380 total. 74 of those carry crash / revert / removed
> language. (A naive `cover` grep returns ~393 - the noise is "coverage", "recovered",
> "discovered".)

They cluster into four episodes:

| when | bugs | what |
|---|---|---|
| 2026-07-07 | **299, 303, 305, 306, 307, 308, 310, 311, 313, 320, 321, 323, 325, 326, 327, 329** | the entire wall-cover build-out and its twelve failures, in one day |
| 2026-07-10 | **463** | wall cover killed |
| 2026-08-09 | 1622, 1634, 1635 | auto-cover added; shipped against a binary that did not contain it |
| 2026-08-21 | 1992, 2000 | shoulder swap in every 3P view; the ADS camera jolt |
| undated | 536 | sandbag height vs the low-cover head trace |

**`docs/TRAPS.md` and `docs/DECISIONS.md` contain zero cover entries.** The only hits are ordinary
prose (`TRAPS.md:269`, `DECISIONS.md:98`, `DECISIONS.md:508`). That is itself a finding: the whole
crash history of this feature lives in exactly one artifact, and a session that read only the
authored docs would rebuild the crash. Section 11 supplies the TRAPS entry that should exist.

Prior design work that is still substantially correct and should be read next to this:
`docs/proposals/cover_attach_plan.md` (2026-08-10), inputs in
`docs/proposals/cover_attach/01_existing_cover.md` and `02_engine.md`. **Its line anchors are
stale by roughly +280 lines - do not trust them.** This plan **adopts** its section 3 detection
rules and section 6 network analysis unchanged, and **supersedes its section 4 movement model**,
which proposed the same per-frame `setOrigin` pin that caused the original crash.

---

## 2. Current state map - the shipped system, end to end

### 2.1 Two files called "cover"; only one is this feature

| file | what it is |
|---|---|
| `hzm-mohaa-coop-mod/coop_mod/takecover.scr` | **THIS FEATURE.** 47 lines. Bind bus 26. |
| `hzm-mohaa-coop-mod/coop_mod/cover.scr` | the deployable **sandbag**. Unrelated. 13.5 KB. |

Both `docs/FEATURES.md:238` and `docs/FEATURES.md:682` carry the warning. Keep it.

### 2.2 Two entry points - and only one of them can ever reach WALL

**Keybind path.** `coop_mod/variables.scr:167` allocates name-append bus index 26 with marker
`" ,c1"`. `coop_mod/player.scr:596` dispatches:

```
else if(local.arrayIndex==26){ thread coop_mod/takecover.scr::coop_cover_toggle local.player }
```

`takecover.scr:17-47` is a pure request/feedback shim - guards (dead / spectator / DBNO / turret /
vehicle), toggles the Player event `coop_setcover 0|1`, reads back the `coop_incover` getter. It
holds no geometry logic at all. `takecover.scr:44` is the tombstone:
`// wall (standing back-to-wall) cover was removed for being crash-prone; only LOW/crouch remains`.

**Auto path.** `player.cpp:13729-13766` (bug-1622, for the ask *"crouch behind cover and after a
second it will automatically put you behind cover like modern games do"*). It requires
`(client->ps.pm_flags & PMF_DUCKED)` at `player.cpp:13747` plus zero move input, then sets the
*same* `m_bCoopCoverRequested` flag the bind sets and lets the existing validation judge it.
Dwell `coop_coverAutoDelay` 0.9 s; silent retry every 0.4 s; 0.9 s backoff on any hard cancel so a
deliberate exit cannot re-grab.

> **Consequence that decides a design question.** Auto-cover is **crouch-gated**, and WALL cover is
> a **standing** pose (`player_Legs.st:1917-1922` sets `modheight "stand"`). So even with wall
> cover re-enabled, **auto-cover can never engage it** - wall cover stays keybind-only unless the
> auto path gets a standing branch. See 7.4; the recommendation is to add one, gated separately.

`coop_coverAuto` is seeded at `coop_defaults.cfg:27` and exposed at `ui/coop_settings.urc:310`.
Note bug-1635: that toggle **shipped in v1.2.4 against a `game.dll` that did not contain the
feature**, so it was a no-op in the release. Verify with `grep -qa coop_coverAuto` on the packaged
binary before publishing anything from this work.

### 2.3 The engine tick - `Player::TickCoopCover`, `player.cpp:13724-14034`

Called every frame from `ClientThink` at `player.cpp:5347` - **before** `ClientMove`
(`player.cpp:5456`), so anything it sets is visible to the same frame's speed chain and pmove. It
is also called synchronously inside `EventCoopSetCover` (`player.cpp:12826-12835`) so the bind
gets an authoritative same-frame answer.

| lines | block | state today |
|---|---|---|
| 13729-13766 | not-requested branch + AUTO COVER dwell | live |
| 13768-13782 | hard cancels (`forwardmove` / `rightmove` / `upmove>0` / dead / turret / vehicle / ladder / frozen / immobile) | live |
| 13785-13792 | cvars: `coop_coverWallDist` 40, `coop_coverLowDist` 48, `coop_coverLowHeight` 72, `coop_coverGrace` 0.5 | live |
| **13805** | **`if (false)`** | **THE SWITCH** |
| 13807-13853 | WALL detect: sustain-vs-anchor / entry face-turn / back-to-wall fallback | **dead** |
| 13855-13880 | OPEN-SIDE probe, writes `m_iCoopCoverSide` | **dead** |
| 13883-13914 | LOW detect: chest 36u must HIT, head 72u must be CLEAR | live |
| 13916-13926 | geometry grace before dropping the request | live |
| 13929-13953 | commit `m_bCoopCoverWall`/`Low`; PEEK on `BUTTON_COOPADS`; facing re-snap on release | live (wall half inert) |
| 13955-13986 | **PEEK STEP-OUT `setOrigin()`** | compiled, unreachable |
| 13988-14016 | blind-fire arming, per weapon class, semi-auto edge latch | live |
| 14018-14030 | script vars `coop_incover`, `coop_bf_t` (XP) | live |
| 14033 | `SendCoopCoverView()` | live |

**It never touches velocity.** A scan of 13724-14034 for `velocity` returns nothing. The single
movement write in the whole function is `setOrigin` at `player.cpp:13983`.

**The dead code that looks alive.** The peek step-out at 13955-13986 is still compiled. It is
gated on `(m_bCoopCoverWall || m_fCoopPeekFrac > 0.0f)` with target
`(m_bCoopCoverPeek && m_bCoopCoverWall) ? 1 : 0` - both permanently false, so `m_fCoopPeekFrac`
never leaves zero and `setOrigin` never runs. **Flipping `if (false)` alone re-arms it in the same
instant.** That is the single most dangerous line in this plan; see 4.1.

### 2.4 Per-player state - `player.h:394-444`, accessors `player.h:1037-1066`

All cover state is per-`Player`. Nothing global, nothing in `level.`:
`m_bCoopCoverRequested` (402), `m_bCoopCoverWall` (403), `m_bCoopCoverLow` (404),
`m_bCoopBlindfire` (405), `m_iCoopCoverSent` (406), `m_iCoopBfButtons` (407),
`m_bCoopBfShotDone` (408), `m_vCoopCoverNormal` (412), `m_iCoopCoverSide` (413),
`m_bCoopCoverPeek` (414), `m_vCoopCoverBaseOrg` (440), `m_fCoopPeekFrac` (441),
`m_fCoopCoverBadTime` (442), `m_fCoopCoverAutoDwell` (443), `m_fCoopCoverAutoRetry` (444).

Four simultaneous coverers are independent **by construction**. Preserve this property; every new
member in this plan is per-`Player` too.

### 2.5 Replication - one pmove bit and one change-only stufftext

- `PMF_COOP_COVER` = `1 << 13`, `bg_public.h:274`. Set/cleared at **exactly one site**,
  `player.cpp:8629-8635`, inside `Player::UpdateStats` (called from `Player::EndFrame`,
  `player.cpp:8806`), from `(m_bCoopCoverWall || m_bCoopCoverLow)`.
- It is **not** in the `ClientMove` pm_flags clear-mask (`player.cpp:4566-4568`), so last frame's
  bit is still live in `client->ps.pm_flags` when the server runs `Pmove` at `player.cpp:4850`,
  and live in `cg.predicted_player_state` when the client runs `Pmove` at `cg_predict.c:741`.
  **Symmetric, with a one-frame lag on both sides.** This is what makes a pmove gate legal.
- `SendCoopCoverView()`, `player.cpp:13546-13557`: mirrors one int to the owning client as
  `stufftext "set coop_coverView %d"`, **change-only** via `m_iCoopCoverSent`. Its comment records
  the bug it fixed - it used to sit only at the tail, both early returns skipped it, and releasing
  cover never sent 0, so the client kept the camera lift in normal third person. **It is now
  called on every exit path. Any new exit path must call it too.**

### 2.6 Client side - everything `PMF_COOP_COVER` drives

| site | effect |
|---|---|
| `cg_view.c:4820` | `if ((ps->pm_flags & PMF_COOP_COVER) && !CG_AdsForceFirstPerson()) cg.renderingThirdPerson = qtrue;` |
| `cg_modelanim.c:1690` | the **identical** predicate forces `bThirdPerson = qtrue` for the own-model draw |
| `cg_view.c:3865-3867` | `CG_FreecamEligible` returns **false** while covered - no orbit capture; the mouse aims live |
| `cg_view.c:3732-3734` | `CG_AdsStagedOn` returns true while covered, so staged shoulder ADS + the wheel work from cover |
| `cg_view.c:525-555` | `CG_CoopCoverViewLift` - raises the 3P eye by `coop_coverViewRaise` (16), eased out as the irons come up |
| `cg_drawtools.cpp:2130` | HUD-fade exemption while covered |
| `cg_drawtools.cpp:1537-1549` | crosshair compensation for the blind-fire muzzle raise |

Camera history worth not repeating (bug-303 -> 321 -> 325 -> 326 -> **327**): cover once *forced*
the free-look orbit, then composited orbit+viewangles into the usercmd, then applied the orbit
again at render time, double-applying pitch until the camera wedged past vertical with three
clamps fighting the mouse. The resolution at `cg_view.c:3857-3866` was to **remove one path
entirely** rather than add a third clamp. The stated lesson - *"when a signal starts being
consumed in two places, remove one path entirely rather than adding a third clamp"* - is the
governing principle for the camera work in section 5.4.

### 2.7 The lockstep rule (turret-camera-regression rule 2) - exactly what it constrains

Stated at `cg_modelanim.c:1686-1690` and `cg_view.c:4817-4819`:

> *"CG_AdsForceFirstPerson is documented as the single decider the camera AND the own-model draw
> must both use, so the mirror of this line in cg_modelanim.c changes with it
> (turret-camera-regression rule 2)."*
> *"if the camera goes first person and the body draw does not, the camera sits inside the drawn
> head."*

**The rule:** the camera's view-mode decision and the own-model draw decision are two copies of
the same boolean expression living in two files, and an edit to one is invalid unless the other is
edited identically in the same change. The two live expressions are byte-identical today:

```
cg_view.c:4820       if ((ps->pm_flags & PMF_COOP_COVER)       && !CG_AdsForceFirstPerson()) { cg.renderingThirdPerson = qtrue; }
cg_modelanim.c:1690  if ((cg.snap->ps.pm_flags & PMF_COOP_COVER) && !CG_AdsForceFirstPerson()) { bThirdPerson = qtrue; }
```

Layered on top is an **ordering law**: native scope is FINAL. `cg_view.c:4797` and `:4826`
re-assert first person after every 3P force. That ordering was bug-329 once, and then bug-1992's
sibling a second time when the coop ADS handoff (a later, second route to first person) did not
get the same treatment.

`cg_modelanim.c:1678-1684` records the equally binding counter-lesson: bug-1234 **reverted** a
lockstep "fix" that force-hid the body during DBNO, because it removed a working feature to
prevent a problem nobody had. **The rule is "keep the two expressions identical", not "force the
body to follow the camera".**

**What this constrains here:** the cover-side and lean work must not introduce a *third* decider.
Everything new hangs off `PMF_COOP_COVER` and `CG_AdsForceFirstPerson()`; if either line changes,
both change in the same commit. Checkable - see PROBE **P7**.

### 2.8 Blind-fire ballistics today

- `Weapon::GetMuzzlePosition`, `weapon.cpp:1686-1706` - fire origin is `player->m_vViewPos`, then
  `position[2] += coop_blindfireRaise` (32), **gated on the LOW pose, not on the blindfire flag**.
  That gating was itself a fix: trailing anim fire-frames lost the raise and shot the cover.
- `Weapon::Shoot`, `weapon.cpp:2038-2045` - spread multiplied by `coop_blindfireSpread` (3.0).
- `Weapon::Shoot`, `weapon.cpp:2071-2101` - **wall steering.** Rotates the entire aim basis by
  `coop_blindfireYaw` (50 deg) toward `GetCoopCoverSide()`, and slides the fire origin
  `coop_blindfireOut` (20u) laterally plus 8u off the wall.

> ### LIVE LATENT DEFECT (found during this research, not previously logged)
>
> The steer at `weapon.cpp:2077` is gated only on
> `pBf->IsCoopBlindfiring() && pBf->IsCoopCoverWall()`. **`m_iCoopCoverSide` has no "unknown"
> value.** It is initialised to `1` at `player.cpp:2406`, and the probe at `player.cpp:13859-13880`
> only ever *overwrites* it - if neither side trace finds an opening it leaves the previous value
> standing. So on a long unbroken wall the side is stale, or defaults to LEFT, and blind fire
> swings 50 degrees and slides the muzzle 20 units **into the wall the player is leaning on**.
>
> That is exactly the symptom bug-305 was filed for (*"sprayed bullets straight into the wall the
> character leans on - screenshot: decals at own shoulder"*). It was never fully closed; it was
> **masked** three days later when wall cover was disabled. **Fixing this is mandatory before
> `if (false)` comes out.** See 5.3 and RISK R2.

### 2.9 Where WALL vs LOW was cut - exact inventory

| thing | file:line | state |
|---|---|---|
| WALL geometry detection | `player.cpp:13805` `if (false)` | **disabled** |
| OPEN-SIDE probe | `player.cpp:13859-13880` (inside the guard) | **disabled** |
| PEEK step-out `setOrigin` | `player.cpp:13955-13986` | compiled, unreachable |
| `m_bCoopCoverWall` commit | `player.cpp:13932` | live, always false |
| `COOP_COVER` conditional | `player_conditionals.cpp:2220` -> `m_bCoopCoverWall` | live, always false |
| `COOP_COVER_OPENRIGHT` conditional | `player_conditionals.cpp:2224` -> `m_iCoopCoverSide < 0` | live, never true |
| legs `COVER_WALL` | `player_Legs.st:1915` | **intact, unreachable** |
| legs `COVER_WALL_FIRE` | `player_Legs.st:1939` | **intact, unreachable** |
| alias `coop_cover_wall` | `anims_shared.txt:591` | intact; still used by `COVER_LOW_PEEK` |
| alias `coop_blindfire_wall` | `anims_shared.txt:593-602` | intact, unreachable |
| alias `coop_blindfire_wall_r` | `anims_shared.txt:646-655` | intact, **orphaned - zero statemap references** |
| `Weapon::Shoot` wall steer | `weapon.cpp:2071-2101` | live, never fires |
| `takecover.scr` messaging | `takecover.scr:44-46` | reflects LOW-only |

**Nothing was deleted.** Re-enabling is one line, plus the safety work this plan exists to specify.

---

## 3. Crash post-mortem

### 3.1 The record

**bug-463, 2026-07-10, `openmohaa-hzm/code/fgame/player.cpp`** - the kill:

> *error:* "Wall (standing back-to-wall) cover was buggy and could crash"
> *root cause:* "Player::TickCoopCover's WALL pose did an entry view-snap and a peek step-out that
> `setOrigin()`'d the body toward a corner, which could shove the player into geometry."
> *fix:* "Guarded the entire wall-detection block with `if(false)` so `wallValid` stays false and
> `m_bCoopCoverWall` can never engage."

That is a **quarantine, not a diagnosis.** It names two suspects and disables the whole subsystem
rather than either of them. Three days earlier there were, in fact, **three separate crashes**, and
two of them had already been root-caused and fixed:

| bug | crash | real root cause | status |
|---|---|---|---|
| **308** | **HARD process crash** the instant wall cover engaged; log froze mid-line at `TAKECOVER: engaged WALL`, no ERR_DROP | `cgi.get_camera_offset(NULL, NULL)` - the client impl at `cl_main.cpp:217-221` writes **both** out-params unconditionally (`*resetview=`, `*lookactive=`) -> null write -> segfault on the first frame `PMF_COOP_COVER` rises | **FIXED** (pass real locals). Cause was in `cg_view.c`, nothing to do with wall geometry |
| **307** | ERR_DROP `Can't find player animation coop_blindfire_wall_r` -> "Possible infinite state loop" | a missing anim in an **in-graph** statemap row is fatal - the infinite-loop stopper drops the server (far harsher than `forcelegsstate` misses, which only warn). Compounded by a deploy race: the test at 23:03:43 ran against a pk3 that landed at 23:04:13 | **FIXED** (alias relocated, fire frames added, deploys timestamped) |
| **313** | ERR_DROP "Possible infinite loop in state AIM/STAND/COVER_TORSO" while peeking | peek routed **into the vanilla `AIM` hub state**, whose own exit web bounced `AIM -> STAND -> COVER_TORSO -> AIM` inside one evaluation pass | **FIXED** (dedicated `COVER_PEEK_TORSO` terminal state) |
| **299** | ERR_DROP `Unknown condition 'COOP_COVER'` at map load | concurrent-agent deploy race: the statemap shipped in the pk3 before its `player_conditionals.cpp` registration was in the exe | **FIXED** (rebuild engine+mod together) |

### 3.2 What actually remained unfixed on 2026-07-10

Not a crash - a **class of unsound mechanism**, plus a pile of feel bugs:

1. **`setOrigin()` on a live player from server code**, `player.cpp:13983`. Two independent
   problems, only one of which bug-463 names:
   - *geometry:* it traces `G_Trace(origin, mins, maxs, vWant, ..., MASK_PLAYERSOLID)` and refuses
     on `startsolid` (`player.cpp:13978-13982`) - which is actually the correct discipline. The
     hole is that `startsolid` describes the **start** of the trace, and the step ran every frame
     from a *moving* `origin` toward a target computed from a *stale* `m_vCoopCoverBaseOrg`. On a
     moving platform, a door closing on the player, or two players sharing a jamb, the anchor and
     the body drift apart and the sweep is asked to do something incoherent.
   - *prediction:* the client is simultaneously running `Pmove` (`cg_predict.c:741`) and does not
     know about the write. Server-authored origin against a live predictor **is** bug-311's
     *"VERY janky - you dont actually pop out from the door opening"*.
2. **Entry view-snap.** `player.cpp:13834-13836` does `SetViewAngles()` on entry to face the
   player out from the wall. A server-side view write against a client that owns the mouse is the
   same category of fight; bugs 325, 326 and 327 are all downstream of it.
3. **Right-corner blind fire was visually broken and unfixable with the shipped assets** (bug-310)
   - see 7.2.
4. **`m_iCoopCoverSide` had no unknown state** - the 2.8 defect, never diagnosed.

### 3.3 The three lessons that constrain this design

> **L1 - Never write a live player's origin from server-only code.**
> It fights the predictor and it can put the hull in a solid. Every "safe `setOrigin`" variant is
> still unpredicted. **This plan uses zero origin writes.**

> **L2 - A statemap-referenced animation that does not resolve kills the server.**
> Not a warning - `ERR_DROP` via the infinite-loop stopper (bug-307). Every alias must be verified
> present in the shipped pk3 **before** it is wired into a state, and the engine and mod must be
> deployed together (bug-299).

> **L3 - Never transition into a vanilla hub state you do not control the exits of.**
> `AIM` bounced back through `STAND` into `COVER_TORSO` in one evaluation pass (bug-313). Give
> every new feature its own terminal state.

Add the meta-lesson from bug-2000, which is the most recent and most expensive in this file: seven
fixes missed the real cause because they all targeted the same half of the system and two of their
premises were false. **Instrument before fixing** (`docs/21-user-preferences.md`, standing
instruction 2026-08-10: *"let's make it the standard practice to always build probes first to
test"*). Section 10 is not optional.

---

## 4. Chosen architecture

### 4.1 The core substitution: lean, do not teleport

**The engine already ships a replicated, client-predicted, collision-free body offset: `fLeanAngle`.**

| property | anchor |
|---|---|
| lives in `playerState_t` | `q_shared.h` `playerState_t::fLeanAngle` |
| **replicated** | `msg.cpp:3375` and `:3437` - `{ PSF(fLeanAngle), 0, netFieldType_t::regular }` (0 bits = float field) |
| interpolated between snapshots | `cg_predict.c:444` - `out->fLeanAngle = LerpAngle(prev, next, f)` |
| **driven entirely in shared pmove** | `bg_pmove.cpp:1357-1420` - so it is client-predicted, not server-pushed |
| parameters set identically on both sides | `player.cpp:4285-4300` and `cg_predict.c:638-653` (`leanMax` 45, `leanAdd` 6, `leanRecoverSpeed` 8.5, `leanSpeed` 2 under protocol >= MOHTA) |
| moves the **eye**, not the hull | `cg_view.c:1594-1608` - `RotatePointAroundVector` about a pivot 28.7u below the eye |
| moves the **view roll** | `cg_view.c:4652` - `cg.refdefViewAngles[2] += ps->fLeanAngle * 0.1 * fLeanRollScale` |
| moves the **viewmodel** | `cg_viewmodelanim.c:926-942` |
| **already ADS-aware** | `cg_adsLeanShift` (`cg_view.c:1600`) and `cg_adsLeanRoll` (`cg_view.c:4649`), both from bug-lean-ads-wrong-branch |
| **enabled in our gametype** | `player.cpp:4285` sets `leanMax = 45` for all non-SP protocols >= MOHTA. Only *lean while moving* is dmflag-gated (`DF_ALLOW_LEAN_MOVEMENT`, `player.cpp:4276-4280`) |

**And the muzzle follows it for free, through a channel that already exists.** The client reports
its own eye position to the server every packet:

```
cg_view.c:3626      VectorCopy(origin, cg.playerHeadPos);        // tail of CG_OffsetFirstPersonView, AFTER the lean pivot
cg_view.c:4909-4914 CG_EyeOffset() = cg.playerHeadPos - predicted origin
cl_input.cpp:999    CL_EyeInfo() -> usereyes_t.ofs[3]  (signed byte, clamped -127..128, cl_input.cpp:1009-1012)
cl_input.cpp:1237   MSG_WriteDeltaEyeInfo -> usercmd stream
player.cpp:5414-16  m_vViewPos = current_eyeinfo->ofs + origin
weapon.cpp:1686     VectorCopy(player->m_vViewPos, position);    // THE FIRE ORIGIN
```

So a leaned eye already becomes a leaned muzzle in first person. Verified rather than assumed:
`CG_OffsetFirstPersonView` sets `origin = cg.refdef.vieworg` at **`cg_view.c:1461`**, so it writes
the **real camera**, not just the `pREnt` weapon model it is handed - and its tail copies that same
leaned origin into `cg.playerHeadPos` at `:3626`.

> **Call-site oddity a future implementer will trip on.** `CG_OffsetFirstPersonView` is **not**
> called from `CG_CalcViewValues`. It is called from `cg_modelanim.c:2279` (`bUseWorldPosition`
> true) and `:2521` (false), i.e. during model animation, after `CG_CalcViewValues` has already
> run. `CG_OffsetThirdPersonView` **is** called from `CG_CalcViewValues`, at `cg_view.c:4848`.
> This asymmetry is what made bug-168 and bug-lean-ads-wrong-branch both land their first fix in a
> branch that never executes. **Confirm which branch executes before editing either function.**

**The one gap: `CG_OffsetThirdPersonView` never writes `cg.playerHeadPos`**, so in third person it
keeps the value set at `cg_view.c:4762` (own head, pre-chase - correct, the muzzle must not sit at
the chase camera) and therefore carries **no lean**. Since cover forces third person, the plan adds
one thing: a lean lateral contribution to `cg.playerHeadPos` in the 3P path. That is a
**client-side write into an existing reported field**, not a server origin write.

> **Why this eliminates the crash class rather than mitigating it.** `fLeanAngle` cannot place the
> collision hull inside a solid, because it never touches the hull. `PM_CheckDuck`, `PM_GroundTrace`
> and `PM_StepSlideMove` are untouched. There is nothing left for `startsolid` to be wrong about.

**Cost of the substitution:** the 3P *body* does not lean - MOHAA has no player lean animation and
no `LEAN` statemap condition (verified: zero `lean` hits in `player_Legs.st` / `player_Torso.st`,
zero `"LEAN` registrations in `player_conditionals.cpp`). The visible lean-out therefore comes from
the **cover animations**, which is what they are for (section 7). The lean supplies camera, eye and
ballistics; the anim supplies the silhouette. They are tuned to agree, not to be the same thing.

### 4.2 Script vs engine split

| layer | owns | files |
|---|---|---|
| **script** (`.scr`) | request/release, guards, player-facing text, `^~^~^` probe lines | `coop_mod/takecover.scr` **only**; messages and the log line, no logic |
| **statemap** (`.st`) | pose selection from engine conditionals; nothing else | `coop_mod/player_Legs.st`, `player_Torso.st` |
| **`game.dll`** (`fgame/`) | pose validation, the side solver, blind-fire arming, ballistics, the speed scale | `player.cpp`, `player.h`, `player_conditionals.cpp`, `weapon.cpp` |
| **shared pmove** (`fgame/bg_*.cpp`, compiled into BOTH) | the lean drive and the slide direction clamp - **the only place a movement rule can live without mispredicting** | `bg_pmove.cpp`, `bg_public.h` |
| **`cgame.dll`** | camera framing, shoulder side, the 3P eye lean contribution | `cg_view.c`, `cg_modelanim.c`, `cg_ui.cpp` |

`bg_pmove.cpp` is globbed into the cgame target at `cgame/CMakeLists.txt:21-23`, and `Pmove()` is
called from `cg_predict.c:741` (client) and `player.cpp:4850` (server). **It currently contains
zero coop edits** - the only HZM change in the file is constant tuning at `bg_pmove.cpp:53-61`
(`pm_accelerate` 5.5, `pm_friction` 4.5, `pm_strafespeed` 0.85, `pm_backspeed` 0.80), and the
comment at `bg_pmove.cpp:44-48` states the governing rule:

> values here must be **constants, not cvars**, "or every step mispredicts."

**Binding consequence: no cvar may be read inside `bg_pmove.cpp`.** All tuning that needs to be
live must be applied through `client->ps.speed` in `ClientMove` (replicated 16-bit, `msg.cpp:3362`)
or through a field on `pmove_t` filled identically by both callers. `pmove_t` (`bg_public.h:~330-353`)
is a **local** struct - not networked - so adding a field to it costs nothing on the wire.

### 4.3 Ship classes

| change | binaries that must ship together |
|---|---|
| side solver, wall re-enable, speed scale, ballistics guard | `game.dll` |
| lean drive + slide clamp (`bg_pmove.cpp`) | **`game.dll` AND `cgame.dll`** - shared source, must be built from the same tree |
| 3P eye lean, shoulder side, camera | `cgame.dll` |
| statemap / anims / takecover.scr | pk3 via `build.ps1` |

Per `docs/21-user-preferences.md`, engine-binary changes are the only class that warrants staging
around the user's testing. `build.ps1` deploys `cgame.dll`/`game.dll` to `G:\mohaa-gl2\` (the live
install) **and** the GOG root; deploying to the GOG root alone never reaches the running game
(bug-1634 - the reason auto-cover appeared not to exist for a whole session).

---

## 5. The doorway-side algorithm

### 5.1 Why the shipped probe cannot answer the user's question

`player.cpp:13859-13880`, in full:

```c
if (wallValid) {
    Vector vLeft = Vector(0.0f - m_vCoopCoverNormal[1], m_vCoopCoverNormal[0], 0);   // player's LEFT
    trace = G_Trace(vStart + vLeft*44, 0,0, vStart + vLeft*44 - m_vCoopCoverNormal*(fWallD+24), ...);
    if (trace.fraction >= 1.0f && !trace.startsolid) { m_iCoopCoverSide = 1; }       // opening LEFT
    else {
        trace = G_Trace(vStart - vLeft*44, 0,0, vStart - vLeft*44 - m_vCoopCoverNormal*(fWallD+24), ...);
        if (trace.fraction >= 1.0f && !trace.startsolid) { m_iCoopCoverSide = -1; }  // opening RIGHT
    }
}
```

Geometry check: `m_vCoopCoverNormal` is the wall's OUT normal, which is also the direction the
player faces once entry snaps them back-to-wall (`player.cpp:13835`). `vLeft = (-N.y, N.x, 0)` is
`N` rotated +90 about Z, which is the player's left. Correct. Each probe steps 44u sideways and
traces **backward into the wall**; a miss means the wall is not there, i.e. an edge. The mechanism
is sound. Five defects make it unable to answer *"which side do you want to pop out of"*:

1. **Left always wins.** Right is only tested if left failed. On a doorway with the player centred
   in the jamb, or on any pillar with open air on both sides, the answer is always LEFT.
2. **No unknown state.** If both probes fail, `m_iCoopCoverSide` keeps its previous value - or its
   constructor default `1` (`player.cpp:2406`). This is the 2.8 latent defect: mid-wall blind fire
   swings 50 degrees into the wall.
3. **One fixed distance.** 44u. A jamb edge at 20u and one at 70u are both invisible; the actual
   distance to the edge is never measured, so the pop-out cannot be sized to the geometry.
4. **One height.** 48u (chest). A waist-high window scores identically to a doorway you can
   actually step through.
5. **View intent is not an input at all.** The user's sentence is explicit: *"smart enough to know
   which side you are **wanting** to blindfire and pop out of cover from."* Intent must be in the
   scoring function.

**Does the LOW-cover system already solve pop-up direction, and does it generalise?** No, and no.
LOW cover computes **no side at all** - the side probe is inside the `if (false)` block, so it
never runs for low cover either. LOW blind fire is purely vertical: `Weapon::GetMuzzlePosition`
raises the fire origin by `coop_blindfireRaise` (32) at `weapon.cpp:1703-1705`, and the anim
`coop_blindfire_low` holds the gun overhead. That is a correct design for shooting *over* a crate
and it carries **zero lateral information**. There is nothing to generalise; the side solver is new
work.

### 5.2 The solver

Runs every frame while a wall pose is valid. Budget: 6 traces (3 per side), point traces except
one bbox sweep per side. Compare with the ~4 traces the pose validation already spends.

```
CONSTANTS (engine-registered, CVAR_ARCHIVE, read in game.dll only - NOT in bg_pmove):
  coop_coverSideScanMin      16      first lateral sample
  coop_coverSideScanMax      72      last lateral sample
  coop_coverSideScanStep     14      -> samples at 16,30,44,58,72
  coop_coverSideHeadZ        62      second probe height (must also be open to count as pop-out-able)
  coop_coverSideIntentDead   0.25    |dot| below this = no intent expressed
  coop_coverSideCommitMs     180     dwell before a side change is committed
  coop_coverSideMaxDelta     10      deg of yaw change that resets the intent dwell (anti-jitter)

INPUT
  O   = origin
  N   = m_vCoopCoverNormal        (flat, unit, points OUT of the wall = player's facing at entry)
  L   = (-N.y, N.x, 0)            (player's LEFT)
  F   = flat forward of the CURRENT view yaw  (free-look: may differ from N)
  hull= (mins, maxs)

-- STEP 1: EDGE SCAN ------------------------------------------------------------
for side s in { LEFT: +L , RIGHT: -L }:
    edge[s]   = INF
    for d = ScanMin to ScanMax step ScanStep:
        base = O + s*d
        // chest: is the wall still behind us at this lateral offset?
        tChest = trace(base + Z*48, base + Z*48 - N*(coop_coverWallDist + 24))
        if tChest.startsolid: break                  // we are inside something laterally - not an edge, a jam
        if tChest.fraction >= 1.0:                   // wall absent here
            // head: reject waist-high windows and recesses you cannot pop through
            tHead = trace(base + Z*SideHeadZ, base + Z*SideHeadZ - N*(coop_coverWallDist + 24))
            if tHead.fraction >= 1.0:
                edge[s] = d
                break
    // NOTE: no wall found in the FIRST sample means we were never against a wall on that side;
    // treat as edge = ScanMin (flush with the corner), not as INF.

-- STEP 2: REACHABILITY (the pop-out must be physically possible) ----------------
for side s:
    open[s] = false
    if edge[s] < INF:
        // can the SILHOUETTE clear the jamb? full player hull, laterally, no z change.
        want   = O + s*(edge[s] + coop_peekOut)        // coop_peekOut default 8
        tSweep = trace(O, mins, maxs, want)            // MASK_PLAYERSOLID, includes teammates
        open[s] = (!tSweep.startsolid && tSweep.fraction >= 0.85)

-- STEP 3: SCORE ----------------------------------------------------------------
intent = dot(F, L)          // +1 = looking hard left, -1 = hard right, 0 = straight out

if      open[LEFT] && !open[RIGHT]:  want = LEFT
else if open[RIGHT] && !open[LEFT]:  want = RIGHT
else if !open[LEFT] && !open[RIGHT]: want = NONE                 // <-- the value that never existed
else:                                                            // BOTH open: the doorway case
    if      intent >  +IntentDead:   want = LEFT
    else if intent <  -IntentDead:   want = RIGHT
    else if edge[LEFT] + 8 < edge[RIGHT]: want = LEFT            // no intent: nearer edge wins
    else if edge[RIGHT] + 8 < edge[LEFT]: want = RIGHT
    else:                            want = committed            // dead heat: do not change

-- STEP 4: COMMIT (hysteresis - the solver output is NOT the committed side) -----
if want == committed:
    sideDwell = 0
else if blindfiring || peekFrac > 0.01:
    // LATCH. Never flip the side mid-burst or mid-peek: the side drives an ANIMATION
    // (COOP_COVER_OPENRIGHT) and the CAMERA shoulder. Flipping either mid-action strobes.
    sideDwell = 0
else:
    sideDwell += frametime
    if viewYawDelta > SideMaxDelta: sideDwell = 0     // still swinging the mouse; wait for a decision
    if sideDwell >= CommitMs:
        committed = want
        sideDwell = 0
        SendCoopCoverSide()                            // change-only stufftext, see 5.4

m_iCoopCoverSide = committed        // 1 = LEFT, -1 = RIGHT, 0 = NONE
m_fCoopCoverEdge = edge[committed]  // NEW: distance to the edge, drives lean depth and muzzle slide
```

**Left vs right jamb of a doorway, walked through.** Wall along Y, doorway gap from y=0 to y=64,
player backed against the wall at y = -30 (i.e. on the **left jamb as seen from inside the room**,
with the opening to their... it depends which way they face, which is exactly why intent matters):

- Player faces out along `N`. Their LEFT `L` points toward +Y or -Y depending on `N`'s sign, and
  the solver never needs to know which - it just scans both.
- The doorway side scans clear at d = 30 (chest and head both open); the solid side never clears.
  `open` is true on one side only -> **STEP 3 first branch, deterministic, intent not consulted.**
  This is the normal case and it is unambiguous.
- Player moves to the **other jamb**: the mirror happens, and the answer flips automatically. The
  user's *"you could be in cover on either side"* is satisfied by geometry alone.
- Player stands **in** the opening, or on a narrow pillar between two doors: **both** open ->
  intent decides. Look left, you pop left. This is the only case where the old code was
  systematically wrong (it always said LEFT), and it is exactly the case the user described.
- Player is **mid-wall**, no edge within 72u: `want = NONE`. Blind fire fires straight out with no
  steer (5.3); no peek step-out; `COOP_COVER_OPENRIGHT` false; shoulder keeps the player's own
  choice. **This is the state that does not exist today and whose absence is the 2.8 defect.**

### 5.3 What the committed side drives - and the mandatory guard

| consumer | file:line | change |
|---|---|---|
| statemap condition `COOP_COVER_OPENRIGHT` | `player_conditionals.cpp:2224`, body `:1101-1104` | today `return (m_iCoopCoverSide < 0)`. Unchanged semantics; `0` correctly reads as "not right" |
| **NEW** condition `COOP_COVER_OPENLEFT` | new row next to `:2224` | `return (m_iCoopCoverSide > 0)`. Needed so a `default:` row can mean NONE rather than LEFT |
| blind-fire steer | `weapon.cpp:2071-2101` | **MANDATORY GUARD: `if (pBf->GetCoopCoverSide() == 0) skip the whole block.`** Then use `coop_blindfireOut` scaled by the measured edge distance instead of a flat 20u: `min(coop_blindfireOut, m_fCoopCoverEdge + 6)` |
| lean drive | `bg_pmove.cpp` (new, 6.2) | sign of the synthesized `BUTTON_LEAN_*` |
| 3P shoulder | `cg_view.c` (new, 5.4) | proposes a shoulder side |
| peek clearance | via the lean, no origin write | depth scaled by `m_fCoopCoverEdge` |

**Deleting the `coop_blindfireYaw` steer entirely is tempting and wrong.** Blind fire is by
definition unaimed - the player's view faces *out of* the wall, so unsteered rounds go
perpendicular to the wall into open room, not down the corridor the player is trying to suppress.
The 50-degree swing toward the opening is the correct intent. Keep it; guard it on `side != 0`;
and let the *muzzle* clearance come from the lean rather than from the raw 20u lateral teleport of
the fire origin.

### 5.4 3P shoulder - cover proposes, the player disposes

The shoulder machinery, all in `cg_view.c`:

```
:88    static float s_shoulderSideSign = 1.0f;              // +1 right, -1 left, EASED
:602   fCamSide   = cg_camerasideoffset->value * s_shoulderSideSign;      // plain chase, SIGNED since bug-1992
:641   fCamSide  += (cg_adsShoulderSide * s_shoulderSideSign - fCamSide) * s_adsShoulderEnv;
:741-745 fArc = 1.0f - fabs(s_shoulderSideSign); fCamDist += fArc * cg_adsShoulderArc;   // bows the sweep BEHIND the player
:753   VectorMA(new_vieworg, fCamSide, right, new_vieworg);
:3790-3803 s_shoulderSideSign eased toward +/-1 from the ARCHIVED cvar cg_adsShoulderRight
cg_ui.cpp:248-262 MOUSE3 claims the key whenever CG_AdsShoulderWheelActive() || cg.renderingThirdPerson
```

**They must not fight** - that is an explicit requirement of the task, and bug-1992 is the record
of what "fighting" looks like. Two rules:

1. **Cover must never write `cg_adsShoulderRight`.** It is `CVAR_ARCHIVE` and it is the player's
   standing preference. Per `docs/21-user-preferences.md` (*"A setting is a promise"*), silently
   rewriting an archived preference from gameplay code is a defect in its own right.
2. Introduce an **override**, not an assignment, at the single point where the sign target is
   computed (`cg_view.c:3790-3803`):

```c
/* existing */ fSignTgt = pRight->integer ? 1.0f : -1.0f;

/* NEW - cover proposes */
if (pCoverAutoShoulder->integer && !s_coverShoulderManual && coop_coverSide != 0) {
    fSignTgt = -(float)coop_coverSide;   /* side +1 = opening LEFT  -> LEFT shoulder  (-1) */
}                                        /* side -1 = opening RIGHT -> RIGHT shoulder (+1) */
```

- `coop_coverSide` reaches the client as a **change-only stufftext**, exactly like `coop_coverView`
  (`player.cpp:13555`): `stufftext "set coop_coverSide %d"`, **unquoted, one statement per
  stufftext** (`TRAPS.md` T8.1 - an embedded quote truncates the wire argument; `;`-joined
  statements are the other half of the same bug family, bugs 736/758).
- `s_coverShoulderManual` is a **client-side session latch**: MOUSE3 pressed while
  `PMF_COOP_COVER` sets it, and it clears when the cover flag drops. So an explicit swap always
  wins for the rest of that cover session, and the next time you take cover the auto-pick resumes.
  MOUSE3 continues to write `cg_adsShoulderRight` as it does today - the player's preference is
  still recorded, it is just temporarily overridden while covered.
- **Do not re-target the sign while `s_adsShoulderEnv` or `s_adsFpEnv` is mid-flight.** The arc
  term at `:742` bows the camera out behind the player during a sweep; starting a shoulder sweep
  on top of an ADS fly-in composes two eases into one motion and will read as the "warp" bug-1992
  was filed for. Gate the re-target on both envelopes being at rest, or on a fresh cover entry.
- **T8 warning:** a server-stuffed `set` of a cvar is silently dropped by
  `cg_servercmds_filter.cpp:304-316` unless whitelisted, and this ate three unrelated features
  once (bug-597, bug-1991). `coop_coverView` already works, so the `coop_*` namespace is
  permitted - **but verify `coop_coverSide` specifically with PROBE P3 before building anything on
  top of it.**

### 5.5 3P lean roll - one thing to suppress

`cg_view.c:4652` applies `cg.refdefViewAngles[2] += ps->fLeanAngle * 0.1 * fLeanRollScale`
**unconditionally**, in both view modes. In first person a lean roll is right. In a third-person
chase it rolls the whole world around a body that is not visibly leaning, which will read as a
camera bug. Scale it by `(1 - coverness)` while `PMF_COOP_COVER && cg.renderingThirdPerson`, or
route it through a `cg_coverLeanRoll` (default ~0.25). This is a **one-line change with a cvar**,
so it is a live-tunable feel decision rather than a guess.

---

## 6. A/D slide along cover

### 6.1 What must be true

| requirement | consequence |
|---|---|
| identical on listen host and dedicated remote client | the movement rule must be in **shared** `bg_pmove.cpp`. `Player::ClientMove` and `TickCoopCover` are server-only and will mispredict |
| no rubber-band | no `PMF_NO_PREDICTION` (it disables prediction outright, `cg_predict.c:561`), no `setOrigin` |
| no protocol change | no new pmove flag (6.4), no new stat (6.4), no new `playerState_t` field |
| no cvars inside `bg_pmove.cpp` | `bg_pmove.cpp:44-48` - a client with a different value mispredicts every step. Tuning goes through `client->ps.speed`, which **is** replicated (`msg.cpp:3362`) |

### 6.2 The design

**Step 0 - stop `rightmove` meaning "cancel".** `player.cpp:13770` currently reads:

```c
|| (flags & FL_IMMOBILE) || last_ucmd.forwardmove || last_ucmd.rightmove || last_ucmd.upmove > 0) {
```

Split it: while a wall pose is held and `coop_coverSlide` is on, **`rightmove` no longer cancels**.
`forwardmove` and `upmove > 0` keep cancelling - they stay the player's two instant escapes, which
is the same reflex-count argument `cover_attach_plan.md` §7 risk 3 makes. Keep the auto-cover entry
gate at `player.cpp:13745-13748` unchanged (you still have to hold still to *acquire* cover).

**Step 1 - direction clamp, in shared pmove.** Insert in `PM_WalkMove` between
`bg_pmove.cpp:603` (`wishspeed = VectorNormalize(wishdir)`) and `bg_pmove.cpp:627`
(`PM_Accelerate`). Friction, ground clip and `PM_StepSlideMove` stay stock, so it feels native:

```c
/* bg_pmove.cpp, inside PM_WalkMove, after wishdir is normalized */
if ((pm->ps->pm_flags & PMF_COOP_COVER) && pm->cmd.rightmove) {
    vec3_t vN, vT;
    /* Re-derive the wall normal with pm->trace: gi.trace on the server (player.cpp:4007+),
       CG_PlayerTrace on the client (cg_predict.c:580) - SAME collision model, SAME result.
       Zero replication, perfect prediction parity. Mirror of player.cpp:13842-13851. */
    if (PM_CoopCoverWallNormal(vN)) {                 /* backward trace along -flat_forward */
        CrossProduct(pml.flat_up, vN, vT);            /* wall tangent */
        VectorNormalize(vT);
        /* sign only: full slide speed regardless of where the player is LOOKING */
        {
            float dir = DotProduct(vT, pml.flat_left) * -(float)pm->cmd.rightmove;
            float s   = (dir >= 0.0f) ? 1.0f : -1.0f;
            VectorScale(vT, s, wishdir);
            /* wishspeed unchanged: ps.speed already carries the cover scale (step 2) */
        }
    } else {
        wishspeed = 0.0f;                             /* no wall found: do not slide anywhere */
    }
}
if (pm->ps->pm_flags & PMF_COOP_COVER) {
    /* never walk off the wall with W/S; forward/back stays a CANCEL handled server-side */
    /* (fmove was already folded into wishdir above, so this is applied by zeroing fmove at
        the top of PmoveSingle instead - see step 4) */
}
```

`pml.flat_forward` / `pml.flat_left` / `pml.flat_up` are declared at `bg_local.h:45` and computed
from **view yaw only** at `bg_pmove.cpp:1426-1429`. Viewangles are replicated and
pmove-authoritative, so both sides agree.

> **Why re-trace instead of using `pml.flat_left` directly as the tangent?** Because cover has
> **no orbit capture** (`cg_view.c:3865`) - the mouse aims live, so the view yaw drifts freely away
> from the wall normal. `flat_left` is therefore *not* the wall tangent except at the instant of
> entry. Using it directly would make A/D walk the player diagonally off the wall the moment they
> look sideways. The re-trace costs one `pm->trace` per pmove step and is exact. `pm->trace` is a
> function pointer on `pmove_t` (`bg_public.h:332-342`), already set by both callers.

**Step 2 - speed, through the one mechanism everything else uses.** In `Player::ClientMove`,
immediately after the crouch clamp at `player.cpp:4707-4709`:

```c
if (m_iMovePosFlags & MPF_POSITION_CROUCHING) {
    client->ps.speed = (float)client->ps.speed * sv_crouchspeedmult->value;   /* existing */
}
/* NEW */
if ((m_bCoopCoverWall || m_bCoopCoverLow) && coop_coverSlideMult) {
    client->ps.speed = (float)client->ps.speed * coop_coverSlideMult->value;  /* ~0.55 */
}
```

`ps.speed` is an int consumed by `PM_CmdScale` at `bg_pmove.cpp:294` and **replicated 16-bit**
(`msg.cpp:3362`), so the predictor sees the same number. This is the mechanism sprint
(`player.cpp:4668-4673`), Alt-walk (`:4679-4684`), ADS (`:4694-4705`), crouch (`:4707-4709`),
weapon weight (`:4711-4728`) and limp (`:4749-4778`) all use, so the slide composes with all of
them for free. **Do not use `speed_multiplier[]`** (`player.h:459`, applied `player.cpp:4737-4739`)
- slot 0 is script-owned by `coop_mod/ads.scr:19-38` and you would race it. `TickCoopCover` runs at
`ClientThink:5347`, before `ClientMove` at `:5456`, so the flags are fresh.

**Step 3 - stop at a corner or a gap, without dropping cover.** Each pmove step, before applying
the lateral wish, probe the *destination*:

```
probeAt = origin + wishdir * (wishspeed * frametime)
chest   = trace(probeAt + Z*48, probeAt + Z*48 - vN * coop_coverWallDist)
if chest.fraction >= 1.0:            // wall runs out this step
    wishspeed = 0                    // SOFT STOP: hold at the edge, stay in cover
```

The player parks flush at the jamb and the side solver (5.2) reports that edge at its minimum
distance, so the pop-out is maximally effective exactly where you stopped. **Do not drop cover at
the edge** - the 0.5 s `coop_coverGrace` at `player.cpp:13918-13926` would do that, and the user
asked for "slide stops at a corner", not "slide ejects you".

**Step 4 - forward/back.** `PmoveSingle` already has precedent for zeroing the cmd:
`bg_pmove.cpp:1323-1329` (BUTTON_TALK) and `:1431-1436` (dead). Add the cover case at the same
place, before the lean block at `:1357` so the lean's `!pm->cmd.forwardmove` gate
(`bg_pmove.cpp:1359`) is satisfied:

```c
if (pm->ps->pm_flags & PMF_COOP_COVER) {
    pm->cmd.forwardmove = 0;          /* server-side TickCoopCover still sees the raw ucmd and cancels */
    pm->alwaysAllowLean = qtrue;      /* so the synthesized lean survives an A/D slide */
}
```

Note the deliberate asymmetry: pmove zeroes `forwardmove` so it produces no motion, while
`TickCoopCover` reads `last_ucmd.forwardmove` (the untouched copy) and still treats it as the exit.
Press S and you leave cover; you never walk backwards out of the pose one unit at a time.

**Step 5 - the lean drive.** Same insertion point, before `bg_pmove.cpp:1357`:

```c
if ((pm->ps->pm_flags & PMF_COOP_COVER) && pm->coopCoverLeanSide != 0) {
    pm->cmd.buttons &= ~(BUTTON_LEAN_LEFT | BUTTON_LEAN_RIGHT);
    pm->cmd.buttons |= (pm->coopCoverLeanSide > 0) ? BUTTON_LEAN_LEFT : BUTTON_LEAN_RIGHT;
}
```

`pm->coopCoverLeanSide` is a **new field on `pmove_t`** (local struct, zero wire cost), filled by
the server from `m_iCoopCoverSide` when peeking or blind-firing, and by the client from the
mirrored `coop_coverSide` cvar in `cg_predict.c` alongside the existing setup at `:633-654`. A few
frames of disagreement at cover entry produce a small lateral view error that `cg_errorDecay`
(`cg_view.c:4746-4756`) already smooths.

Lean parameters need to be smaller than the stock 45-degree combat lean; set `pm->leanMax` to
`coop_coverLeanMax` (~22) while covered, on **both** sides (`player.cpp:4285-4300` and
`cg_predict.c:638-653` are the two places these are assigned, and they must stay identical - this
is the same class of paired edit as the lockstep rule).

### 6.3 Animation for the slide

**No lateral cover-slide animation exists anywhere in the retail data.** (Verified: 40 pk3s
scanned; the only `takecover_slide_*.skc` clips in `main/Pak0.pk3` are *forward dives*, used as
`*_diveongrenade`.) The recommendation is therefore to build the slide out of what the split
statemap already does well:

- **legs slot:** the existing `STRAFE_LEFT` / `STRAFE_RIGHT` conditionals - already registered at
  `player_conditionals.cpp:2148-2149`, bodies at `:900-908` (`last_ucmd.rightmove < 0` / `> 0`),
  already consumed in `player_Legs.st:134-135` and `:234-239`. Add two rows inside `COVER_WALL`
  (`player_Legs.st:1915`) and `COVER_LOW` (`:1967`) selecting the ordinary crouch/stand strafe
  clips. **Zero new engine code.**
- **torso slot:** hold the cover pose (`coop_cover_wall` / `coop_cover_low`) throughout. The torso
  slot masks the upper bones while the legs run underneath - this is the mod's own established
  trick, recorded in bug-320's fix (*"Torso slot masks upper bones; legs keep running underneath"*).

Net visual: the character keeps their back/shoulder on the wall and shuffles sideways. Good enough
for Phase 2; a bespoke shuffle clip is a Phase 4 nicety, not a blocker.

### 6.4 Why no new flag or stat - the hard numbers

| channel | status |
|---|---|
| `pm_flags` bits 0-15 | **100% allocated** (`bg_public.h:256-276`): 0 DUCKED, 1 VIEW_PRONE/DAMAGE_ANGLES, 2 SPECTATING, 3 RESPAWNED, 4 NO_PREDICTION, 5 FROZEN, 6 INTERMISSION, 7 SPECTATE_FOLLOW/CAMERA_VIEW, 8 NO_MOVE, 9 VIEW_DUCK_RUN, 10 VIEW_JUMP_START, 11 LEVELEXIT, 12 TURRET, **13 COOP_COVER**, 14 NO_WEAPONBAR, 15 NO_HUD |
| bit 16+ | **does not survive the wire.** `{ PSF(net_pm_flags), 16, ... }` at `msg.cpp:3373` and `:3435` - a hard 16-bit netfield. Widening it is a protocol-constant change in two tables and breaks any binary not rebuilt in lockstep |
| `stats[]` | **full.** `STAT_MGHEAT` at `bg_public.h:567` is commented *"uses the last free MAX_STATS slot"*; `STAT_LAST_STAT` = 32 = `MAX_STATS` (`q_shared.h:1865`) |
| `ps->falldir`, `walking`, `groundPlane`, `groundTrace` | **absent from the netfield table** (`msg.cpp:3346-3400`) - not replicated |
| `pmove_t` fields | **free.** Local struct, never serialised. This is the channel the plan uses |
| change-only stufftext | free, proven (`coop_coverView`, `coop_limpView`). Subject to T8 |

> **Protocol footnote worth knowing.** `CPT_DenormalizePlayerStateFlags_ver_6`
> (`bg_compat.cpp:78-98`) maps game bits 1-12 to wire bits 3-14 and copies bits 15-31 straight -
> **game bits 13 and 14 are silently dropped under protocol 6 (plain AA).** `PMF_COOP_COVER` is
> bit 13, so cover only replicates on protocol >= 15. The project runs `com_target_game 2`
> (Breakthrough), which is protocol 15/17, so this is fine today - but it means the flag is **not**
> a universal channel, and it is one more reason not to try to add a second one.

---

## 7. Animation inventory and mapping

Full sweep of all 40 retail pk3s plus the mod tree. `$path models/human/animation` is set at
`anims_shared.txt:5`, so every `.skc` below is relative to that.

### 7.1 The mapping table

| desired player state | alias | .skc | defined at | handedness | fire frames | status |
|---|---|---|---|---|---|---|
| **wall idle, LEFT jamb** | `coop_cover_wall` | `weapon_rifle/cornering/rifle_wall_alert_left.skc` | `anims_shared.txt:591`; `COVER_WALL` row `player_Legs.st:1926` | LEFT, gun stays right - correct | no | **EXISTS**, unreachable behind `if(false)`. Also live via `COVER_LOW_PEEK` (`player_Legs.st:2017`) |
| **wall idle, RIGHT jamb** | *(none)* | `weapon_rifle/cornering/rifle_wall_alert_right.skc` **or** `weapon_mp40/cornering/mp40_wall_alert_right.skc` | AI only: `human_rifle.tik:518` / `human_mp40.tik:382` | RIGHT, **bare row - no hand swap - USABLE** | n/a | **MISSING ALIAS ONLY.** The .skc ships in `main/Pak0.pk3`. **Cheapest win in the table.** |
| **blindfire LEFT** | `coop_blindfire_wall` | `weapon_mp40/cornering/mp40_wall_blindfire_left.skc` | `anims_shared.txt:593-602`; `player_Legs.st:1952` | LEFT, right-handed | **yes** `1,3,5,7 fire` | **EXISTS**, dead with `COVER_WALL` |
| **blindfire RIGHT** | `coop_blindfire_wall_r` | `weapon_mp44/cornering/mp44_wall_blindfire_right.skc` | `anims_shared.txt:646-655` | **poses the LEFT hand as the shooting hand** | yes `1,3,5,7` | **ORPHANED + VISUALLY BROKEN.** Zero statemap references. **No usable right-jamb blindfire animation exists in the game.** See 7.2 |
| **peek-aim LEFT** | `coop_aim_rifle/_smg/_mg/_pistol` | `weapon_rifle/rifle_aim.skc`, `weapon_mp40/mp40_aim_action.skc`, `weapon_mp44/mp44_aim.skc`, `weapon_pistol/pistol_aim.skc` | `anims_shared.txt:622-625`; `COVER_PEEK_TORSO` rows `player_Torso.st:265-271` | **neutral** - plain standing aim holds, no lean baked in | no (fires via `CHECK_PRIMARY_ATTACK_*`, `player_Torso.st:287-288`) | **PARTIAL.** Works, but is a torso aim over a wall legs pose, not an authored lean-out. Better donor: `rifle_wall_peek_left.skc` / `mp40_wall_peek_left.skc` - **exist, player-safe, no alias** |
| **peek-aim RIGHT** | same (side-agnostic) | same | same | neutral | no | **MISSING as a distinct pose.** `rifle_wall_peek_right.skc` / `mp40_wall_peek_right.skc` **exist in `main/Pak0.pk3` and are player-safe** (no offhand attach). No alias |
| **low idle** | `coop_cover_low` | `weapon_mp40/cornering/mp40_crate_alert.skc` | `anims_shared.txt:592`; `player_Legs.st:1978` | none (centred crouch) | no | **EXISTS and LIVE** - the only cover pose reachable today |
| **low blindfire** | `coop_blindfire_low` | `weapon_mp40/cornering/mp40_crate_blindfire.skc` | `anims_shared.txt:603-615`; `player_Legs.st:2042`, and doubling as the right-corner substitute at `:1951` | none | **yes** `1,3,5,7,9,11,13` | **EXISTS and LIVE** |
| **low peek (rise)** | `coop_cover_wall` (reused) | `rifle_wall_alert_left.skc` | `player_Legs.st:2017` | LEFT-jamb clip used as a generic standing hold | no | **LIVE but wrong donor.** Better: `mp40_crate_aim.skc` / `rifle_crate_aim.skc` - exist, no alias |
| **slide LEFT / RIGHT** | *(none)* | *(none exists)* | - | - | - | **MISSING - nothing in any pk3.** Use the legs/torso split of 6.3 |

### 7.2 The handedness wall (bug-310), now proven exhaustively

Every `_right`-suffixed cornering **shoot/blindfire** alias in the retail data carries
`entry weaponcommand mainhand attachtohand offhand`. **No `_left` alias does.** Confirmed across
`human_rifle.tik` (:447, :454, :461, :527, :547), `human_mp40.tik` (:312, :324, :331, :415, :423,
:434), `human_mp44.tik` (:341, :353, :360, :440, :453, :496, :504, :515), `human_pistol.tik`
(:308, :316, :323, :374, :410, :421, :443), `human_BAR.tik` (:303, :315, :323, :389, :401, :439,
:451), `human_thompson.tik` (:337, :349, :356, :426, :438).

A player weapon is bolted permanently to `tag_weapon_right` and there is **no player-side
equivalent of `weaponcommand attachtohand`**. So any `_right` cornering *shoot* clip on a player
gives you the gun stapled to a right hand that hangs at the wall while an empty left hand mimes the
shot - the "rifle at the ceiling" artefact quoted verbatim in `player_Legs.st:1950`.

**The safe exceptions** (bare rows, no hand swap - these are the right-jamb poses a player CAN
wear): `rifle_wall_alert_right` (`human_rifle.tik:518`), `mp40_wall_alert_right`
(`human_mp40.tik:382`), `rifle_wall_peek_left/right` (`:515`/`:516`), `mp40_wall_peek_left/right`
(`human_mp40.tik:379`/`:380`).

> **Design consequence, and it is load-bearing.** Right-jamb **idle** and right-jamb **peek** are
> achievable with existing assets. Right-jamb **blind fire** is not, and cannot be without new
> animation work. `player_Legs.st:1951` already carries the workaround the project chose:
> `coop_blindfire_low : COOP_COVER_OPENRIGHT` - substitute the **overhead crate spray**, which is
> right-handed and side-neutral. It is a compromise (an overhead spray while standing at a wall)
> but it is honest, it shoots, and it is right-handed. **Keep it, and gate it on the new
> `COOP_COVER_OPENLEFT` / `OPENRIGHT` pair so the `default:` row can mean NONE.**

### 7.3 Statemap - nothing was deleted

All five cover legs states and both torso states survive verbatim:

| state | line | note |
|---|---|---|
| `COVER_WALL` | `player_Legs.st:1915` | entered from `STAND` at `:60` on `COOP_COVER`; entry `modheight "stand"`, `movementstealth 1.0` |
| `COVER_WALL_FIRE` | `player_Legs.st:1939` | rows at `:1951` (`coop_blindfire_low : COOP_COVER_OPENRIGHT`) and `:1952` (`coop_blindfire_wall : default`) |
| `COVER_LOW` | `player_Legs.st:1967` | from `STAND` `:61` and `CROUCH_IDLE` `:570`; `modheight "duck"` |
| `COVER_LOW_PEEK` | `player_Legs.st:2001` | entry `modheight "stand"`, exit `modheight "duck"` - the rise-to-shoot |
| `COVER_LOW_FIRE` | `player_Legs.st:2032` | |
| `COVER_TORSO` | `player_Torso.st:206` | entered from `STAND` at `:88`/`:89`, **above** the attack edges at `:91-93` - deliberate |
| `COVER_PEEK_TORSO` | `player_Torso.st:247` | the bug-313 dedicated terminal state |

`COOP_COVER_OPENRIGHT` is referenced in exactly one place, `player_Legs.st:1951`, and its only
producer is inside the `if (false)` block. It is functionally dead at both ends.

### 7.4 Gaps worth closing while the file is open

- **No `crossblend` on any of the five cover aliases** (`anims_shared.txt:591-615`, `:646`) while
  every neighbouring `coop_act_*` has `crossblend 0.3`. Cover entry/exit will pop.
- **No enter/exit transitions aliased.** Retail ships `rifle_crate_standtocrouch.skc`,
  `rifle_crate_crouchtostand.skc`, `mp40_crate_crouchtostand.skc` and the
  `mp40_wall_blindfire_*_intro/_outtro` set, all in `main/Pak0.pk3`, none aliased on the player
  side. Cover currently snaps.
- **No cover pain anim.** `rifle_wall_peek_pain_left/right.skc`, `mp40_wall_shoot_pain_left/right.skc`,
  `mp40_crate_pain.skc` all exist, none aliased.
- **Shotgun maps to `coop_aim_rifle`** (`player_Torso.st:267`). Grenade / bazooka / PIAT /
  mine-detector / sniper classes have **no peek-aim row at all** and fall through to
  `none : default` (`player_Torso.st:272`).
- **Auto-cover cannot reach the standing pose** (2.2). Recommendation: add a standing branch gated
  on its own cvar `coop_coverAutoWall` (default **0**) so it can be enabled after the crouch case
  is signed off. Shipping both auto behaviours at once makes any feel complaint ambiguous.

**Every alias added must be verified present in the shipped pk3 before it is wired into a statemap
row (lesson L2). One missing anim in an in-graph row is `ERR_DROP`.**

---

## 8. Multiplayer constraints

| constraint | how this design satisfies it |
|---|---|
| **4 simultaneous players** | every new member is per-`Player`, next to the block at `player.h:394-444`. No `level.` state, no statics on the server side. Client statics (`s_coverShoulderManual`) are per-client by construction |
| **Dedicated + listen parity** (STANDING RULE: listen-only behaviour is a defect) | the lean and the slide clamp live in `bg_pmove.cpp`, compiled into **both** `cgame.dll` (`cgame/CMakeLists.txt:21-23`, `Pmove` at `cg_predict.c:741`) and `game.dll` (`Pmove` at `player.cpp:4850`). The tangent is re-derived through `pm->trace`, which is `gi.trace` on one side and `CG_PlayerTrace` on the other - same collision model. **No server-only movement authoring anywhere** |
| **No protocol change** | verified impossible-to-need: `pm_flags` bits 0-15 full and the netfield is a hard 16 (`msg.cpp:3373`, `:3435`); `stats[]` full (`bg_public.h:567`); `fLeanAngle` and `ps.speed` are **already** replicated (`msg.cpp:3375`, `:3362`); everything else rides `pmove_t` (local) or the existing change-only stufftext |
| **Stufftext discipline** | `coop_coverSide` sent **unquoted, one statement per stufftext, change-only** - `TRAPS.md` T8.1 (bugs 736, 758) and T8.3 (whitespace collapse). Verify it is not eaten by `cg_servercmds_filter.cpp:304-316` (T8.2, bugs 597/1991) with PROBE **P3** |
| **Two players on one jamb** | the reachability sweep in 5.2 STEP 2 uses `MASK_PLAYERSOLID`, which includes bodies, so a teammate in the pop-out lane scores that side closed and the solver picks the other one. The slide's soft stop (6.2 step 3) stops at a teammate rather than shoving them |
| **Remote clients need the new `cgame.dll`** | T3 / T8 - a server-stuffed `set` of a `CVAR_ARCHIVE` cvar is dropped by `CG_IsSetVariableAllowed` unless whitelisted, and the 3P eye lean is client code. This is a **paired ship**: `game.dll` + `cgame.dll` from the same tree, always |
| **Late join / respawn / DBNO** | `PMF_COOP_COVER` arrives in the first snapshot; cover state dies with the player via the existing `deadflag` cancel at `player.cpp:13769`; DBNO cancels via `takecover.scr:22` and the engine list. Nothing new |
| **Getter shadowing** | if `EventGetCoopCover` (`player.cpp:12839-12854`) is extended, do **not** also push an entity var named `coop_incover` - the EV_GETTER shadows entity vars for property reads. Any new var takes a new name |

---

## 9. Risk table

| # | risk | severity | mitigation | verified by |
|---|---|---|---|---|
| **R1** | Flipping `if (false)` at `player.cpp:13805` **also re-arms the dead `setOrigin` peek step-out** at `:13955-13986` in the same instant. This is the exact code bug-463 named. | **CRITICAL** | **Delete lines 13955-13986 in the same edit that removes `if (false)`.** Not comment out - delete. Then `grep -n setOrigin fgame/player.cpp` must show zero hits inside `TickCoopCover`. Non-negotiable, and it is the first line of Phase 1 | P1, and a source grep in the build gate |
| **R2** | `m_iCoopCoverSide` has no unknown state, so blind fire steers 50 deg and slides the muzzle 20u **into the wall** on any mid-wall pose (section 2.8 - the never-closed half of bug-305) | **HIGH** | add `side == 0`; guard `weapon.cpp:2077` on it; scale `coop_blindfireOut` by the measured edge distance | P2 |
| **R3** | A statemap row referencing an alias that does not resolve is **`ERR_DROP`, not a warning** (bug-307) - and a pk3/exe deploy race reproduces it even with correct source (bug-299) | **HIGH** | verify every new alias is in the shipped pk3 **before** wiring it; ship engine+mod together; announce deploy completion with a timestamp | P6, boot-log sweep |
| **R4** | The server view-snap at `player.cpp:13834-13836` fights the client mouse - the root of bugs 325/326/327 | **HIGH** | **do not restore the entry view-snap.** Anchor `m_vCoopCoverNormal` from the trace; let the player keep the mouse; the *body* turns via the animation, not via `SetViewAngles`. Keep the peek-release re-snap at `:13941-13951` only, which is a discrete event, not a per-frame fight | P4 |
| **R5** | Prediction mismatch between server `m_iCoopCoverSide` and the client's mirrored `coop_coverSide` at cover entry, so the lean starts a few frames apart | MED | the side is stable for the life of a pose; the error is a small lateral view offset absorbed by `cg_errorDecay` (`cg_view.c:4746`). If visible, fall back to re-deriving the side in pmove via `pm->trace` (same technique as the tangent) | P5 |
| **R6** | Cover-side auto-shoulder fights the player's MOUSE3 swap / archived `cg_adsShoulderRight` (the bug-1992 family) | MED | cover **proposes** via an override at the sign-target site only; MOUSE3 during a cover session latches manual and wins; never write the archived cvar; never re-target mid-envelope | P3 |
| **R7** | 3P lean roll (`cg_view.c:4652`, unconditional) rolls the world around a body that is not visibly leaning | MED | scale by a `cg_coverLeanRoll` while `PMF_COOP_COVER && renderingThirdPerson` | live tune |
| **R8** | **Right-jamb blind fire has no usable animation** and never will without new art (7.2) | MED | ship the honest substitute already chosen at `player_Legs.st:1951` (overhead crate spray, right-handed, side-neutral). **Tell the user this is a known compromise** rather than presenting right-jamb fire as solved | user sign-off |
| **R9** | Lockstep rule 2 violated - camera and own-model draw diverge, camera ends up inside the head | MED | the two expressions at `cg_view.c:4820` and `cg_modelanim.c:1690` must stay byte-identical; no third decider | P7 |
| **R10** | `bg_pmove.cpp` reads a cvar and every step mispredicts (`bg_pmove.cpp:44-48`) | MED | constants only in `bg_pmove.cpp`; all live tuning through `client->ps.speed` (replicated) or `pmove_t` fields filled identically | P5 |
| **R11** | Auto-cover grabs a wall the player did not want, since a standing pose has a much larger catchment than a crouch | MED | ship `coop_coverAutoWall` **default 0**. Auto stays crouch-only until the keybind wall case is signed off. Do not bundle two feel changes | phase gate |
| **R12** | Feel: "magnetised" reads as "grabbed" (`cover_attach_plan.md` §7 risk 5) | LOW-MED | three independent instant exits kept: re-press the bind, `forwardmove` (W or S), `upmove > 0` (jump). Escape latency is one input | playtest |
| **R13** | Moving platforms / elevators stale the anchored normal | LOW | existing 0.5 s `coop_coverGrace` (`player.cpp:13918-13926`) already drops the pose. Same limitation ships today; accept | - |

---

## 10. Probes - one playtest answers everything

Standing instruction (`docs/21-user-preferences.md`, 2026-08-10): *"let's make it the standard
practice to always build probes first to test"*. Machine-parseable lines are `^~^~^`-prefixed and
watched by `maptest_monitor.ps1`; the engine already has 361 `^~^~^` sites (e.g.
`actor.cpp:3483`, `:5251`, `:12549`), so `gi.Printf("^~^~^ ...")` is established.

Gate all of this on **`coop_coverProbe 1`** (default 0), change-only plus a 2 Hz cap so it cannot
flood.

| probe | line | answers | risk |
|---|---|---|---|
| **P1** | `^~^~^ COVERPROBE originwrites=<n>` emitted once per pose, counting any `setOrigin`/`SetViewAngles` call made from inside `TickCoopCover` this frame | **must be 0 forever.** This is the crash-class regression alarm. Pair it with a source-grep gate in the build | R1, R4 |
| **P2** | `^~^~^ COVERSIDE want=L/R/NONE cm=L/R/NONE edgeL=<u> edgeR=<u> openL=0/1 openR=0/1 intent=<f> dwell=<ms>` on every solver output change | does the doorway case actually resolve, and does it hold steady or strobe? Does `NONE` ever occur mid-wall (it must)? | R2, R5 |
| **P3** | client-side `^~^~^ COVERCVAR side=<n> view=<n> shoulderSign=<f> manual=0/1` on change, via `cgi.Printf` -> **and** a server-side `^~^~^ COVERSEND side=<n>` at the stufftext site. **A `COVERSEND` with no matching `COVERCVAR` proves the T8 filter ate it** | is the new stufftext arriving at all? does the shoulder follow? does MOUSE3 win? | R6, T8 |
| **P4** | `^~^~^ COVERVIEW yaw=<f> srvyaw=<f> delta=<f>` each covered frame where `|delta| > 5` | is anything server-side still fighting the mouse? Should be silent | R4 |
| **P5** | `^~^~^ COVERPRED side_s=<n> side_c=<n> lean_s=<f> lean_c=<f> perr=<f>` - server value in the game log, client value in the same log on a listen host | do server and client agree on the side and the lean? how big is the prediction error? | R5, R10 |
| **P6** | boot-time `^~^~^ COVERANIM alias=<name> ok=0/1` for every cover alias, resolved through the same lookup the statemap uses, printed at map load **before** any cover can engage | catches the `ERR_DROP` class *before* a player can trigger it. **Highest value per line in this list** | R3 |
| **P7** | `^~^~^ COVERLOCK cam3p=<0/1> body3p=<0/1>` on any frame where the two disagree while `PMF_COOP_COVER` | mechanical enforcement of lockstep rule 2. Should be silent | R9 |
| **P8** | `^~^~^ COVERSLIDE dir=<n> spd=<f> wall=0/1 stopped=0/1` on change | does the slide clamp to the tangent, and does it stop at the edge instead of ejecting? | 6.2 |

**Single-playtest script** (listen server, `m1l1` for beach sandbags + a doorway; a build-mode
crate for a controlled low-cover case):

1. Boot. Sweep the **whole** log, not just cover lines (standing instruction). **P6** must show
   `ok=1` for every alias. If not, stop - do not let a player press the bind.
2. Walk to a plain mid-wall stretch, press the bind. Expect `engaged WALL`, **P2** `cm=NONE`,
   **P1** `originwrites=0`. Hold LMB: rounds go **straight out**, not into the wall (**R2 closed**).
3. Step to the left jamb of a doorway. **P2** must flip to a single unambiguous side with
   `openL != openR`. **P3** must show the shoulder following. Hold LMB: the burst goes through the
   opening.
4. Step to the right jamb. Everything mirrors. Right-jamb blindfire will use the overhead spray -
   **that is the known R8 compromise, confirm the user accepts the look.**
5. Stand centred in the opening. **P2** must show `openL=1 openR=1` and the side must follow the
   mouse with a visible dwell, not strobe.
6. MOUSE3 mid-cover. **P3** `manual=1`; the shoulder holds the manual choice for the rest of that
   cover session and auto-picks again on the next engage.
7. Hold A, then D. **P8** shows tangent-clamped motion; **P1** still 0; the slide stops flush at
   the jamb (`stopped=1`) without dropping cover.
8. RMB peek at each jamb: the camera and the muzzle clear the frame. **P4** and **P7** silent.
9. Scope a sniper from cover: first person, no scope-over-the-back-of-the-head (`cg_view.c:4826`
   ordering intact).
10. `coop_coverSlide 0`, `coop_coverAutoWall 0`, `coop_coverAuto 0` -> behaviour is today's,
    exactly. **The rollback switches must be real.**

---

## 11. Phase plan

### Phase 1 - the smallest thing that is actually playable (`game.dll` only)

**Goal: stand at a doorway, blindfire the correct way round, and never crash.**

1. **Delete** `player.cpp:13955-13986` (the peek step-out `setOrigin` block). Delete, not comment.
2. Remove `if (false)` at `player.cpp:13805`.
3. **Do not restore** the entry view-snap at `player.cpp:13834-13836` - anchor the normal, leave
   the view alone (R4).
4. Replace the side probe at `player.cpp:13859-13880` with the 5.2 solver, including the `0` /
   NONE value and `m_fCoopCoverEdge`.
5. Guard `weapon.cpp:2077` on `side != 0`; scale `coop_blindfireOut` by the measured edge.
6. Add `COOP_COVER_OPENLEFT` next to `player_conditionals.cpp:2224`; re-gate
   `player_Legs.st:1951-1952` so `default:` means NONE.
7. Probes **P1, P2, P6** behind `coop_coverProbe`.
8. `takecover.scr:44-46` messaging updated (delete the "removed for being crash-prone" tombstone -
   *"if we removed settings for a bug reason that setting needs to be removed"*, and its inverse).

Peek in Phase 1 is **torso-only**, exactly as it is today for low cover - no lean, no step-out, no
body displacement. It is not the final feel, but it is safe, and it is the first build in which the
user's central ask ("know which side you want to pop out of") is observably true.

**Ship class:** `game.dll` + pk3. No `cgame.dll`, no shared-pmove change. Smallest possible blast
radius. **Gate to Phase 2:** P1 reads 0 for a whole session and the doorway case resolves correctly
at both jambs.

### Phase 2 - the lean (`game.dll` + `cgame.dll` + shared pmove, ship as a set)

9. `pmove_t.coopCoverLeanSide` + `coopCoverLeanMax`; the lean synthesis at `bg_pmove.cpp:~1350`;
   `pm->alwaysAllowLean` while covered; `leanMax` override paired in `player.cpp:4285-4300` **and**
   `cg_predict.c:638-653`.
10. 3P eye lean contribution to `cg.playerHeadPos` so the muzzle clears the corner (4.1).
11. `coop_coverSide` change-only stufftext + the shoulder override + the MOUSE3 session latch (5.4).
12. `cg_coverLeanRoll` damp on `cg_view.c:4652` (5.5).
13. Probes **P3, P4, P5, P7**.

### Phase 3 - the slide (shared pmove + `game.dll`)

14. Split the cancel at `player.cpp:13770` so `rightmove` no longer cancels while
    `coop_coverSlide` is on.
15. `wishdir` tangent clamp in `PM_WalkMove` (`bg_pmove.cpp:603-627`) with the `pm->trace`
    re-derivation; `forwardmove` zeroed in `PmoveSingle`.
16. `coop_coverSlideMult` on `client->ps.speed` after `player.cpp:4709`.
17. Soft stop at the edge.
18. `STRAFE_LEFT`/`STRAFE_RIGHT` legs rows inside `COVER_WALL` / `COVER_LOW` (zero engine cost).
19. Probe **P8**. Ships **default 0** until the feel is signed off.

### Phase 4 - polish, only after 1-3 are signed off

20. Right-jamb idle + peek aliases (`rifle_wall_alert_right`, `*_wall_peek_left/right`) - free
    wins, assets already ship (7.1).
21. `crossblend 0.3` on the five cover aliases; enter/exit transition aliases; cover pain anims.
22. `coop_coverAutoWall` standing branch for auto-cover, default 0 (R11, 7.4).
23. Better low-peek donor (`*_crate_aim`), peek-aim rows for the missing weapon classes.

### Bookkeeping that must not be skipped

- **`docs/TRAPS.md` needs a cover entry.** It has none, which is why this crash was one grep away
  from being rebuilt. Proposed, merged into the existing procedural-motion family at
  `TRAPS.md:759`:
  > *Never write a live player's `origin` or `viewangles` from server-only code to produce a view
  > or pose effect.* The client is running `Pmove` at the same time (`cg_predict.c:741`) and does
  > not know. Wall cover's peek step-out (`player.cpp:13955-13986`) was a bbox-traced,
  > `startsolid`-refusing `setOrigin` - textbook-careful and still unshippable, because careful and
  > *predicted* are different properties. It read as *"VERY janky"* (bug-311), it could put the
  > hull in a solid (bug-463), and it took the whole feature down for six weeks. The engine already
  > ships the predicted primitive: `ps->fLeanAngle`, driven in shared `bg_pmove.cpp:1357-1420`,
  > replicated at `msg.cpp:3375`, and incapable of moving the collision hull. **Two sibling
  > entries:** `SetViewAngles` from the server against a client that owns the mouse produced bugs
  > 325, 326 and 327 in one day. Movement rules belong in `bg_pmove.cpp` or nowhere -
  > `bg_pmove.cpp:44-48`.
- **`docs/DECISIONS.md`**: record the lean-not-teleport choice and the rejected alternative
  (`cover_attach_plan.md` §4's per-frame `setOrigin` pin with `PMF_NO_PREDICTION`), rejected
  because `PMF_NO_PREDICTION` disables prediction outright (`cg_predict.c:561`) and would make the
  slide feel correct on the listen host and laggy for the other three players - a listen-only
  defect by the standing rule.
- **`.wolf/buglog.json`**: log the section 2.8 latent defect now, as the un-closed half of bug-305,
  regardless of when it is fixed.
- **`docs/OPEN.md:510`** already carries the queued cover-peek step-out design. **Replace it** -
  do not leave the superseded `setOrigin` design standing next to this one.
