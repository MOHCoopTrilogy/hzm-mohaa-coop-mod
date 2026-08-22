# Dynamic weapon feel — IMPLEMENTATION SPEC

**Ask (user, 2026-08-20):** *"I think we should also try to make weapon movement feel dynamic, no
reload should feel the same with the camera movements."*

**Written 2026-08-20.** Every claim below was re-verified against source in this session; the four
lens reports (`weapon_feel_r1_{reference,engine,variation,risk}.md`) and their adversarial verifiers
disagreed on several load-bearing points and those conflicts are settled in §2 with citations, not
by majority. Measured numbers were re-derived here, not copied.

---

## 1 — VERDICT: build a REDUCED version. One session. `cgame.dll` only.

**Build Stage 1 and then stop.** Stage 1 is ~110 LOC in one file, ships alone, rolls back with one
console line, and is simultaneously a **defect fix** and the feature the user asked for. Stages 2
and 3 are specified but should not be built unless the user asks after seeing Stage 1.

### Why "build" and not "don't"

The risk lens argues the feature is not worth a playtest slot against bug-1976 (every AI hit
reaction has played the wrong limb since it shipped), bug-1971 (Germans with guns on their back that
never fire) and the still-churning ragdoll queue (bug-1964, bug-1970, bug-1981 — a regression
shipped in the same session that fixed it). **That priority call is correct and this spec does not
contest it.** But its own analysis contains the reason to build anyway, and it under-priced it:

> **The reason no reload feels different from the last one is not missing randomness. It is a
> hardcoded 900 ms constant applied to animations that run 0.63 s to 4.80 s.**

`cg_view.c:133` — `float fPhase = (cg.time - s_iVMAStart) * (1.0f / 900.0f);`

Measured, this session, by parsing the SKC headers of the viewmodel reload clips actually bound by
`hzm-mohaa-coop-mod/models/player/base/fps_anims_*.txt` (v13 files; duration =
`frameTime * (numFrames - 1)`, per `tiki/tiki_anim.cpp:283-284`):

| gun | `<prefix>_reload` clip | frames | **duration** | fraction of anim the 900 ms ramp covers |
|---|---|---:|---:|---:|
| Shotgun (start) | `shotgun/reload_start.skc` | 23 | **0.733 s** | never completes — state ends first |
| Shotgun (fill) | `shotgun/reload_fill.skc` | 20 | **0.633 s** | n/a (state 7, flat today) |
| Springfield (start) | `rifle/springfield_reload_start.skc` | 49 | **1.600 s** | 56 % |
| **M1 Garand** | `rifle/vm_riflereload.skc` | 61 | **2.000 s** | **45 %** |
| Johnson (mod) | `coop_johnson/johnson_reload.skc` | 91 | **2.002 s** | 45 % |
| FG42 (mod) | `fg42/fg42_stand_reload.skc` | 71 | **2.310 s** | 39 % |
| M10 (mod) | `coop_m10/m10_reload.skc` | 73 | **2.376 s** | 38 % |
| Colt 45 / P38 | `pistol/reload_colt.skc` | 73 | **2.400 s** | 38 % |
| MP40 | `mp40/reload_mp40_stand.skc` | 76 | **2.500 s** | 36 % |
| MP44 | `mp44/mp44_reload.skc` | 83 | **2.733 s** | 33 % |
| Thompson | `smg/reload_tommy_stand.skc` | 84 | **2.767 s** | 33 % |
| BAR | `mg/reload_bar.skc` | 91 | **3.000 s** | 30 % |
| DP28 (mod) | `coop_dp28/dp28_reload.skc` | 97 | **3.168 s** | 28 % |
| **Kar98** | `rifle/kar98_reload.skc` | 102 | **3.367 s** | **27 %** |
| Panzerschreck | `bazooka/panzer_reload.skc` | 137 | **4.533 s** | 20 % |
| Bazooka | `bazooka/reload_bazooka.skc` | 145 | **4.800 s** | 19 % |

*(SH/BT weapons — `enfield`, `g43`, `mosin`, `ppsh`, `svt`, `nagantrev`, the `A_W_*_fps` set — ship
as **SKAN v14**, a different header layout. A v13 parser emits garbage on them, so their numbers are
deliberately absent here. Stage 1 reads the length **at runtime** via `cgi.Anim_Time`, so they are
covered without ever being measured offline. Do not re-run a v13 parser on them.)*

So today, on **every** gun, the camera finishes its entire two-step excursion inside the first fifth
to half of the reload and then **parks at full lift** for the remainder — 2.5 s of parked camera on a
Kar98, 3.9 s on a bazooka. That is not "a canned curve"; it is a canned curve plus a long plateau,
and the plateau is what makes every reload read the same. Replacing the constant with the real
animation length makes a Garand (2.000 s) objectively unlike a Kar98 (3.367 s) unlike a Thompson
(2.767 s) — a **1.68×** spread across the common set, **7.6×** including shotgun and bazooka —
**with no randomness, no per-gun table, and no new networked field.**

### Why "reduced"

The literal ask ("no reload should feel the same") reads as *add randomness*. The risk lens is right
that randomness is the low-value half: ±15 % of a ~1.6° motion is ±0.24°, ≈5 px at 1080p, against a
reload animation doing an order of magnitude more. **Determinism keyed to the real animation buys
the user's stated outcome; dice do not.** Stage 2 keeps the dice on the shelf, cvar-gated to
today's behaviour, for a session where nothing better is queued.

### What Stage 1 also fixes, for free, in the same edit

Three shipped defects, all confirmed this session:

1. **The smoother can diverge.** `cg_view.c:145-147` is the only first-order smoother in the file
   with no `k` clamp — its six neighbours all have one (`:939`, `:1292`, `:1382`, `:1438`, `:2366`,
   `:2394`). `s += (T-s)·rate·dt` has error `e' = e(1-k)`: it overshoots at `k>1` and **diverges** at
   `k>2`. At `RELOAD_END`'s rate 11.0 that is `dt > 181.8 ms`. `Com_ModifyMsec`
   (`qcommon/common.c:2194-2216`) clamps frame time to **200 ms on a listen host** but to **5000 ms
   for a client of a remote server** (`:2206`) — and a remote coop client is not an exotic case here,
   it is half the standing dedicated/listen parity rule. Re-derived at 1000 ms: `k = 11`,
   `lift = 1.6 − 2.048×11 = −20.9°`. A twenty-degree camera dive.
2. **It runs in third person and in cutscenes.** The call at `cg_view.c:2643` sits after the 3P
   offset (`:2604`) and after the `PMF_CAMERA_VIEW` angle replacement (`:2617`), and tests neither.
   In 3P it tips the world without moving the chase camera.
3. **It feeds the weapon-lag spring.** `cg_view.c:1282` differentiates `cg.refdefViewAngles`, so the
   sway written at `:2643` re-enters the viewmodel as a synthetic mouse movement on the next frame.

Stage 1's relocation (§4.1) kills 2 and 3 structurally rather than with hand-written gates that a
future session must remember to keep in lockstep — which is exactly the failure mode of bug-296 /
bug-329 / bug-332 ("TWO third-person deciders must stay in lockstep").

### Explicit non-goals

Not built, not now, not later without a fresh ask: any networked field, anything in `game.dll` or
the exe, any change to where bullets go, any always-on camera oscillator, and any movement of the
view-weapon model during a reload (bug-168 proved the reload animation swallows it).

---

## 2 — CONFLICTS BETWEEN LENSES, SETTLED

Each settled by reading the source this session. One sentence each.

**C1 — Where does the layer live? (reference: leave at `:2643`; engine: move into
`CG_OffsetFirstPersonView`; variation: leave at `:2643`; risk: leave at `:2643` + hand-written
gates.)**
→ **Engine lens wins.** `cg_scopeSway` already writes `cg.refdefViewAngles` from inside
`CG_OffsetFirstPersonView` (`cg_view.c:1220-1229`) and it reaches the camera because
`cg_modelanim.c:2042` rebuilds `cg.refdef.viewaxis` from `cg.refdefViewAngles` right after the call
returns — the source comment at `cg_view.c:1218-1219` says so in as many words.

**C2 — Does the gun follow the camera pitch, so the iron sights lie? (risk: yes via the ARMS bone;
reference: no, the viewmodel axis is `lerpAngles`; variation: yes, they rotate together and that is
"safe"; engine: rotation about the eye is safest.)**
→ **Risk lens has the mechanism right and everyone missed that it is a function of WHERE you
write.** `PmoveAdjustAngleSettings_Client` (`cg_modelanim.c:1456`) puts **yaw only** into
`cent->lerpAngles` and the full camera **pitch + lean roll** into `bone_angles[ARMS_TAG]`
(`fgame/bg_pmove.cpp:1743-1752`), and it runs at line 1456 — **before**
`CG_ViewModelAnimation` (`:1954`), `ForceUpdatePose` (`:1956`) and `CG_OffsetFirstPersonView`
(`:2039`). So a write at `cg_view.c:2643` (inside `CG_CalcViewValues`, `:2962`, which runs before
the entity pass at `:3078`) **is** picked up by the arms bone — the gun tracks the sway, the sights
follow the lie. A write at the end of `CG_OffsetFirstPersonView` is **not** — the gun keeps pointing
where the bullet goes and only the screen-centre crosshair is displaced.

**C3 — Is the ADS sight picture safe? (reference: scale to 0.15; variation: the layer only runs
while the weapon cannot fire, so it is safe; risk: move the budget into roll, which is aim-neutral.)**
→ **All three are right about different halves.** Under the relocated hook (C2) the sights are
honest by construction, so ADS becomes a *readability* budget rather than a correctness one; the
variation lens's rule is the correct framing for the tail (`the action channel only perturbs the
camera in a window where the weapon cannot fire`); and the reference lens's 0.15 is the right
number because the tree's own accepted ceiling for camera-space angular motion during aimed fire is
`cg_scopeSway` 0.25° (pitch component 0.175°, `cg_view.c:1221-1227`).

**C4 — Which ADS predicate? (reference/engine: `CG_AimingDownSights()`; risk:
`CG_AimingDownSights() || STAT_INZOOM`.)**
→ **Risk lens wins, and it is mandatory:** `CG_AimingDownSights()` returns `qfalse` when
`STAT_INZOOM` is set (`cg_view.c:1547-1549`), so keying on it alone leaves the **sniper** — the
worst case — completely undamped; every neighbour already tests both (`:988`, `:1047`).

**C5 — Does `TAF_DELTADRIVEN` wrap the phase? (variation: yes, `johnson_reload.skc` ships with
flags 0x20 and will replay the curve mid-reload; others: silent.)**
→ **Real hazard, wrong path, and Stage 1 is immune to both.** `johnson_reload.skc` genuinely
carries `flags = 0x20` in its SKC header (measured), which makes `Anim_Time` return
`frameTime × numFrames` rather than `× (numFrames-1)` (`tiki/tiki_anim.cpp:283-284`) — a 22 ms
difference, harmless. But the `.time` **wrap** at `cg_viewmodelanim.c:650-651` keys on
`cgi.Anim_Flags`, which returns the **TIKI animdef** flags (`tiki/tiki_anim.cpp:442-454`), set only
by a literal `deltadriven` keyword on the anim line (`tiki/tiki_parse.cpp:247-248`) — and **zero
lines in any `fps_anims_*.txt` contain that keyword** (grepped: no hits across all six files).
Stage 1 drives phase from `g_iCurrentVMDuration` (`cg_viewmodelanim.c:590` reset, `:620` `+=`),
which is monotone within an animation instance and never wrapped, so the question cannot arise.

**C6 — Which phase clock, and is it stale? (reference: `g_VMFrameInfo[].time`, warns about a
one-frame pop; engine: `g_VMFrameInfo[].time`; risk: `g_iCurrentVMDuration`.)**
→ **Risk lens's clock, and relocating removes the staleness.** `g_iCurrentVMDuration` is reset on
the anim-change edge at `cg_viewmodelanim.c:590` and accumulated at `:620`, inside
`CG_ViewModelAnimation` (`cg_modelanim.c:1954`) — which runs **before** `CG_OffsetFirstPersonView`
(`:2039`) and **after** `CG_CalcViewValues` (`cg_view.c:2962`). At the relocated hook the value is
**this frame's**; at `:2643` it would be last frame's, and on the very first RELOAD frame it would
still hold the *previous* animation's accumulated ms — a one-frame snap to full lift.

**C7 — Per-shell restart: does it already work? (reference: needs edge tracking; engine/variation:
free.)**
→ **Free.** `player_Torso.st:2472, 2576, 2739, 2841` all issue `viewmodelanim reload_single 1`; the
trailing `1` is `force_restart`, which bumps `iViewModelAnimChanged` (`fgame/player.cpp:13150-13152`)
even though `iViewModelAnim` stays 7; the cgame consumes that edge at `cg_viewmodelanim.c:500-504`
and zeroes both `g_iCurrentVMAnimSlot`'s `.time` (`:588`) and `g_iCurrentVMDuration` (`:590`).

**C8 — Hand tremor / always-on idle sway on the camera (variation lens L4).**
→ **Rejected outright.** The codebase already made this decision and wrote down why: sway the
**gun** while the gun is visible (`cg_adsSway`, `cg_view.c:1208-1213`, on `pREnt->origin`) and sway
the **view** only when the gun is hidden behind a scope (`cg_scopeSway`, `:1216-1229`, source
comment: *"the gun is hidden behind the scope, so wobble the VIEW"*). A new camera oscillator that
runs while the weapon **can** fire is a standing ADS violation and reverses a deliberate, documented
choice. If this is ever wanted, it is a multiplier on the existing `cg_adsSway` amplitude plus a
hip-fire extension — see §8.

**C9 — Is `cg_adsLeanRoll` evidence that "every neighbour damps in ADS"? (reference/risk: no.)**
→ **Correct, it is not.** `cg_view.c:2413` ships the cvar at `"1.0"`; the `0.25f` in that
expression is an unreachable null-pointer fallback. The real ADS-damping precedent set is head bob
0.25 (`:988-990`), limp 0.25 (`:1047-1048`) and weapon lag 0.35 (`:1266`, applied `:1280`).

**C10 — Does the "statics survive a map change" hazard exist? (reference/variation: clamp `fPhase`
low; risk: refuted.)**
→ **Risk lens wins.** `CL_InitCGame` calls `CL_ShutdownCGame` → `Sys_UnloadCGame` →
`Sys_UnloadLibrary`, so the cgame DLL is unloaded and reloaded on every map load and all
function-local statics re-initialise. Stage 1 still clears its statics on the anim edge because it
costs nothing, but this is hygiene, not a live defect — do not sell it as one.

**C11 — Which A/B weapon pair for the headline test? (reference: Garand vs Kar98; risk: Garand vs
BAR.)**
→ **Garand (2.000 s) vs Kar98 (3.367 s) = 1.68×**, measured above. Garand vs BAR is 1.50× and
weaker. Thompson vs Panzerschreck (1.64×) is an acceptable second pair.

---

## 3 — WHAT SHIPS: architecture in one paragraph

One cgame-local function, `CG_ApplyReloadSway`, keeps its name and its cvar, gains a real phase
clock and a per-class weight, and **moves its point of application** from the tail of
`CG_CalcViewValues` (`cg_view.c:2643`) to the tail of `CG_OffsetFirstPersonView`
(`cg_view.c:1518`), which the engine calls from `cg_modelanim.c:2039` and follows immediately with
`AnglesToAxis(cg.refdefViewAngles, cg.refdef.viewaxis)` at `:2042`. That single move puts the layer
behind four existing gates it no longer has to re-implement — local player (`cg_modelanim.c:1877`),
first person (`:1904`), not a cutscene camera (`:2036`), alive and not `cg_animationviewmodel`
(`:2037`) — puts it after the weapon-lag differentiator (`cg_view.c:1289`) so it cannot feed it, and
puts it after `PmoveAdjustAngleSettings_Client` (`cg_modelanim.c:1456`) so the gun keeps pointing
where the bullet goes. Envelope advance stays at `:2643` (which runs unconditionally, every frame,
every view path) so the state is always current; only the **application** moves. Nothing crosses the
wire; `cgame.dll` ships and reverts alone.

---

## 4 — BUILD SEQUENCE

### STAGE 1 — "Does a Kar98 reload feel unlike a Garand reload?"

**Ship this alone. One session. `cgame.dll` only.**

#### IN

| # | Change | Anchor |
|---|---|---|
| 1.1 | Clamp `k`, matching the six neighbours | `cg_view.c:145-147` |
| 1.2 | `VM_ANIM_RELOAD/_SINGLE/_END` symbols instead of `6/7/8` | `cg_view.c:132,138,140`; enum `fgame/bg_public.h:160-175` |
| 1.3 | Real animation length replaces the 900 ms constant | `cg_view.c:133` |
| 1.4 | Reshape all three state curves as fractions of the real anim | `cg_view.c:132-143` |
| 1.5 | Per-weapon-class amplitude weight (reuse the shipped lag set) | new; set copied from `cg_view.c:1274-1278` |
| 1.6 | Relocate the **apply**; keep the **advance** at `:2643` | new call at `cg_view.c:1518`; existing call `:2643` |
| 1.7 | ADS/scope scale + hard ADS ceiling; zero roll in ADS | new |
| 1.8 | `^~^~^ WFEEL` instrument, one line per anim edge | new |
| 1.9 | Three test cfgs + binds; defaults seeded in `coop_defaults.cfg` | `coop_mod/cfg/`, `autoexec.cfg`, `coop_defaults.cfg` |

#### OUT — named so a later session does not re-litigate them

- All randomness and per-reload seeding (Stage 2).
- Context modifiers: dry-vs-top-up, crouched, moving, hurt, suppressed (Stage 2).
- Camera **translation** (`cg.refdef.vieworg` dip) — the channel bug-168 shipped. Angle first.
- Any write to `pREnt->origin` during a reload — bug-168, verbatim: *"During a reload the gun plays a
  large reload animation that swallowed a few-units origin nudge, so nothing was visible."*
- Any always-on / idle camera motion (C8).
- A total-view-motion clamp across injury + shell-shock + lean + viewkick. Real idea, wrong stage:
  it would also clamp vanilla `damage_angles`/`viewkick`, which is a behaviour change that needs its
  own decision and its own cvar.
- Recoil recovery, weapon raise/lower, sprint, landing, melee (§8).
- Anything in `game.dll`, the exe, or the wire.

#### Code shape

**(a) Replace the body of `CG_ApplyReloadSway` (`cg_view.c:106-151`).**

```c
// HZM coop [user 2026-08-20] DYNAMIC RELOAD FEEL. v1 timed the whole camera excursion off a
// hardcoded 900 ms (cg_view.c:133) while the viewmodel reload clips run 0.63 s (shotgun fill) to
// 4.80 s (bazooka) - measured from the .skc headers bound by models/player/base/fps_anims_*.txt.
// So on EVERY gun the camera hit full lift in the first 19-56% of the reload and then PARKED
// there, which is exactly why "no reload feels different from the last one". Now the phase is
// normalised against the animation's REAL length, read once per animation instance from
// cgi.Anim_Time - Garand 2.000 s vs Kar98 3.367 s vs Thompson 2.767 s diverge with no per-gun
// table and no dice.
//
// APPLIED FROM CG_OffsetFirstPersonView, NOT from the CG_CalcViewValues tail. That placement is
// load-bearing three ways:
//   * cg_modelanim.c:1456 PmoveAdjustAngleSettings_Client puts the camera PITCH into the ARMS
//     bone controller (bg_pmove.cpp:1743-1752) and runs BEFORE :2039, so a write here does NOT
//     reach the gun - the iron sights keep pointing where the bullet goes and only the screen
//     crosshair is displaced. A write at the :2643 tail is picked up by the arms bone and the
//     SIGHTS follow the lie.
//   * cg_modelanim.c:1904 / :2036 / :2037 already gate the block to first person, alive, and not
//     a cutscene camera - no hand-written 3P gate to keep in lockstep with the two deciders
//     (bug-296/329/332).
//   * it lands after the weapon-lag differentiator (cg_view.c:1282-1289), so the lift is never
//     re-injected into the gun as a synthetic mouse movement.
// cg_modelanim.c:2042 rebuilds cg.refdef.viewaxis from cg.refdefViewAngles right after we return,
// which is how the change reaches the camera - same route cg_scopeSway already uses (:1220-1229).
static float s_reloadLift = 0.0f;   // eased state, degrees; ADVANCED once per frame at :2643
static float s_reloadRoll = 0.0f;   // roll companion, separately eased

static void CG_ReloadFeelAdvance(void)
{
    static cvar_t *pRS = NULL, *pWt = NULL, *pRetime = NULL, *pMax = NULL, *pDbg = NULL;
    static int     s_iLastSlot = -1;
    static float   s_fAnimLen  = 0.9f;   // seconds; cached per animation instance
    static float   s_fWeight   = 1.0f;   // per-class amplitude, latched on the edge
    float          fTarget, fRate, fDt, k, fPhase, fPeak;
    int            iAnim, iSlot, iClass;
    qboolean       bAlive;

    if (!pRS) {
        pRS     = cgi.Cvar_Get("coop_reloadSway",   "1.6", CVAR_ARCHIVE);
        pWt     = cgi.Cvar_Get("coop_reloadWeight", "1",   CVAR_ARCHIVE);
        pRetime = cgi.Cvar_Get("coop_reloadRetime", "1",   CVAR_ARCHIVE);
        pMax    = cgi.Cvar_Get("coop_reloadSwayMax","3.0", CVAR_ARCHIVE);
        pDbg    = cgi.Cvar_Get("coop_reloadDebug",  "0",   0);  // NEVER archive a diagnostic (TRAPS T7)
    }
    if (pRS->value <= 0.0f || !cg.snap) {
        s_reloadLift = s_reloadRoll = 0.0f;
        s_iLastSlot  = -1;
        return;
    }

    // bug-1306: a spectator keeps STAT_HEALTH at max (Player::Spectator sets deadflag DEAD_NO),
    // so h > 0 alone is not "alive". Same predicate the suppression/hit tints use (:2079-2080).
    bAlive = (qboolean)(cg.snap->ps.stats[STAT_HEALTH] > 0
                        && !(cg.snap->ps.pm_flags & (PMF_SPECTATING | PMF_INTERMISSION)));

    iAnim  = cg.snap->ps.iViewModelAnim;
    iSlot  = cgi.anim ? cgi.anim->g_iCurrentVMAnimSlot : -1;
    iClass = cg.snap->ps.stats[STAT_EQUIPPED_WEAPON];

    // ANIMATION-START EDGE. g_iCurrentVMAnimSlot advances at cg_viewmodelanim.c:580 on EVERY
    // (re)start - a new state, a weapon change, AND a force_restart per shell (player_Torso.st
    // "viewmodelanim reload_single 1" -> player.cpp:13150-13152 bumps iViewModelAnimChanged ->
    // cg_viewmodelanim.c:500). So per-shell restart is free; we only need the edge for the CACHE.
    if (iSlot != s_iLastSlot) {
        s_iLastSlot = iSlot;
        s_fAnimLen  = 0.9f;
        s_fWeight   = 1.0f;

        if (pRetime->integer && iSlot >= 0 && cg.pPlayerFPSModel) {
            int   idx  = cgi.anim->g_VMFrameInfo[iSlot].index;
            int   idle = cgi.Anim_NumForName(cg.pPlayerFPSModel, "idle");
            float len  = (idx >= 0) ? cgi.Anim_Time(cg.pPlayerFPSModel, idx) : 0.0f;
            // cg_viewmodelanim.c:583-586 SILENTLY substitutes "idle" when <prefix>_reload does not
            // resolve (DPrintf only, developer-gated here). Normalising against an idle length
            // would make the ramp crawl or never finish, with no visible diagnostic - so bail to
            // the 900 ms fallback instead, and band-limit anything absurd.
            if (idx >= 0 && idx != idle && len > 0.2f && len < 6.0f) {
                s_fAnimLen = len;
            }
        }
        if (pWt->integer) {
            // Same per-class weights the shipped weapon-lag spring uses (cg_view.c:1274-1278):
            // a proven, already-networked signal, so a Thompson and a BAR diverge with no table.
            if      (iClass & WEAPON_CLASS_PISTOL) { s_fWeight = 0.55f; }
            else if (iClass & WEAPON_CLASS_SMG)    { s_fWeight = 0.80f; }
            else if (iClass & WEAPON_CLASS_RIFLE)  { s_fWeight = 1.10f; }
            else if (iClass & WEAPON_CLASS_MG)     { s_fWeight = 1.50f; }
            else if (iClass & WEAPON_CLASS_HEAVY)  { s_fWeight = 1.35f; }
        }
        if (pDbg->integer && iAnim >= VM_ANIM_RELOAD && iAnim <= VM_ANIM_RELOAD_END) {
            cgi.Printf("^~^~^ WFEEL state=%d slot=%d idx=%d len=%.3f class=0x%x wt=%.2f peak=%.2f hook=%d\n",
                       iAnim, iSlot, (iSlot >= 0 && cgi.anim) ? cgi.anim->g_VMFrameInfo[iSlot].index : -1,
                       s_fAnimLen, iClass, s_fWeight, pRS->value * s_fWeight,
                       cgi.Cvar_Get("coop_reloadHook", "1", CVAR_ARCHIVE)->integer);
        }
    }

    // PHASE. g_iCurrentVMDuration is reset on the same edge (cg_viewmodelanim.c:590) and only ever
    // accumulated (:620) - monotone within an instance, and immune to the TAF_DELTADRIVEN wrap that
    // g_VMFrameInfo[].time is subject to at :650-651.
    fPhase = (cgi.anim && s_fAnimLen > 0.0f)
             ? (float)cgi.anim->g_iCurrentVMDuration * 0.001f / s_fAnimLen : 1.0f;
    if (fPhase < 0.0f) { fPhase = 0.0f; } else if (fPhase > 1.0f) { fPhase = 1.0f; }

    fPeak = pRS->value * s_fWeight;

    // In 3P / cutscene / dead the layer does not APPLY (cg_modelanim.c gates the call), and
    // g_iCurrentVMDuration does not advance either (CG_ViewModelAnimation is inside the
    // !bThirdPerson branch, :1904/:1954) - so target zero and let the envelope decay out rather
    // than tracking a frozen phase that would snap on the way back to first person.
    if (!bAlive || cg.renderingThirdPerson || (cg.snap->ps.pm_flags & PMF_CAMERA_VIEW)) {
        fTarget = 0.0f;
        fRate   = 4.5f;
    } else if (iAnim == VM_ANIM_RELOAD) {
        // Two perceived beats across the WHOLE animation, then the hands come back down before the
        // state ends - this is the fix for the parked plateau. p<0.28 mag out, p<0.62 mag seated,
        // then relax to a quarter lift by p=1.
        if      (fPhase < 0.28f) { fTarget = fPeak * (0.62f * (fPhase / 0.28f)); }
        else if (fPhase < 0.62f) { fTarget = fPeak * (0.62f + 0.38f * ((fPhase - 0.28f) / 0.34f)); }
        else                     { fTarget = fPeak * (1.00f - 0.75f * ((fPhase - 0.62f) / 0.38f)); }
        fRate = (fTarget > s_reloadLift) ? 7.0f : 4.5f;
    } else if (iAnim == VM_ANIM_RELOAD_SINGLE) {
        // Per-shell PUMP, not a flat hold: rises and falls inside each shell's own clip, and the
        // clip restarts per shell for free (C7). Shotgun fill = 0.633 s, Springfield fill = 0.900 s.
        fTarget = fPeak * 0.70f * (float)sin(3.14159265f * fPhase);
        fRate   = (fTarget > s_reloadLift) ? 9.0f : 6.0f;
    } else if (iAnim == VM_ANIM_RELOAD_END) {
        // The cock. v1 parked at a flat -0.28 target for the whole state - and shotgun/springfield
        // reload_end are both 1.033 s, so it was a three-quarter-second downward STARE. Impulse and
        // return instead.
        float d = 1.0f - fPhase;
        fTarget = fPeak * -0.28f * d * d;
        fRate   = 11.0f;
    } else {
        fTarget = 0.0f;
        fRate   = 4.5f;
    }

    fDt = cg.frametime * 0.001f;
    k   = fRate * fDt;
    if (k > 1.0f) { k = 1.0f; }   // MANDATORY. Unclamped, k>2 DIVERGES: Com_ModifyMsec clamps to
                                  // 200 ms on a listen host but 5000 ms for a client of a remote
                                  // server (common.c:2206) -> k=55 at rate 11. Same idiom as :1292.
    s_reloadLift += (fTarget - s_reloadLift) * k;
    s_reloadRoll += (fTarget * 0.30f - s_reloadRoll) * k * 0.8f;  // roll lags the pitch slightly

    if (s_reloadLift >  pMax->value) { s_reloadLift =  pMax->value; }
    if (s_reloadLift < -pMax->value) { s_reloadLift = -pMax->value; }
    if (fabs(s_reloadLift) < 0.004f && fabs(fTarget) < 0.004f) { s_reloadLift = s_reloadRoll = 0.0f; }
}

static void CG_ApplyReloadFeel(vec3_t vAngles)
{
    float fLift = s_reloadLift, fRoll = s_reloadRoll;

    if (fLift == 0.0f && fRoll == 0.0f) {
        return;
    }
    // ADS / native scope. CG_AimingDownSights() returns FALSE when STAT_INZOOM (cg_view.c:1547-1549),
    // so the sniper - the worst case - needs the second term or it is left completely undamped.
    // Scale AFTER the ease, never inside the target, or releasing ADS mid-reload steps.
    if (CG_AimingDownSights() || cg.snap->ps.stats[STAT_INZOOM]) {
        static cvar_t *pAds = NULL;
        float          fCap;
        if (!pAds) { pAds = cgi.Cvar_Get("coop_reloadSwayAds", "0.15", CVAR_ARCHIVE); }
        fLift *= pAds->value;
        fRoll  = 0.0f;                 // zero roll under sights - it tilts the sight picture
        fCap   = 0.30f;                // hard ceiling in degrees, above cg_scopeSway's 0.175 pitch
        if (fLift >  fCap) { fLift =  fCap; }
        if (fLift < -fCap) { fLift = -fCap; }
    }
    vAngles[0] -= fLift;
    vAngles[2] += fRoll;
}
```

**(b) The two call sites.**

At `cg_view.c:2643` — replace the existing single call with the advance plus a legacy-hook apply:

```c
    CG_ReloadFeelAdvance();                                   // state, every frame, every view path
    if (cgi.Cvar_Get("coop_reloadHook", "1", CVAR_ARCHIVE)->integer == 0) {
        CG_ApplyReloadFeel(cg.refdefViewAngles);              // legacy v1 placement (rollback path)
    }
    CG_ApplyShellShock(cg.refdefViewAngles);
    AnglesToAxis(cg.refdefViewAngles, cg.refdef.viewaxis);
```

At `cg_view.c:1518` — immediately before `VectorCopy(origin, cg.playerHeadPos);`, i.e. the same
"very end of `CG_OffsetFirstPersonView`" slot bug-1238 established for the DBNO eye drop:

```c
    // HZM coop [user 2026-08-20] reload feel - APPLY here, not at the CG_CalcViewValues tail.
    // cg_modelanim.c:2042 rebuilds cg.refdef.viewaxis from cg.refdefViewAngles right after this
    // returns (same route cg_scopeSway uses at :1220-1229), so the camera gets it; the arms-bone
    // pose was already baked at :1456/:1956, so the GUN does not - which is what keeps the iron
    // sights honest. Reachable only in live first person, alive, non-cutscene (:1904/:2036/:2037).
    if (!bUseWorldPosition && cgi.Cvar_Get("coop_reloadHook", "1", CVAR_ARCHIVE)->integer) {
        CG_ApplyReloadFeel(cg.refdefViewAngles);
    }

    VectorCopy(origin, cg.playerHeadPos);
```

> `bUseWorldPosition` must be tested: `CG_OffsetFirstPersonView` is also called with `qtrue` from
> `cg_modelanim.c:1910`, on the third-person body path. That call is inside `if (!bThirdPerson)`
> today, but the predicate is the file's own and the two 3P deciders have desynced before
> (bug-332) — test the argument, not the caller.

**(c) Forward declarations.** `CG_ApplyReloadFeel` is used at `:1518`, above its definition at
`:106`? No — `:106` is above `:1518`, so no forward declaration is needed for the apply. The
**advance** is only called at `:2643`, also below. Both fine as-is. `CG_AimingDownSights` is defined
at `:1540`, **below** `:1518`, so it needs the prototype that already exists in `cg_local.h:645`
(verify at build time; if absent, add it there, not a local `extern`).

**(d) Cfgs.** New, in `hzm-mohaa-coop-mod/coop_mod/cfg/`, house style copied from `rag_ab.cfg`:

`wfeel_on.cfg` (F2), `wfeel_off.cfg` (F3), `wfeel_legacy.cfg` (F4):

```
// HZM coop - RELOAD FEEL: ON + instrumented  [bound to F2]
// Real per-animation timing, per-class weight, first-person hook. Reload a Garand then a Kar98
// back to back: the Kar98's lift should take visibly longer to reach the top AND come back down
// before the animation ends. Console prints one ^~^~^ WFEEL line per reload with the measured
// animation length - Garand 2.000, Kar98 3.367, Thompson 2.767.
coop_reloadSway 1.6
coop_reloadRetime 1
coop_reloadWeight 1
coop_reloadHook 1
coop_reloadDebug 1
echo "RELOAD FEEL: ON (retimed + weighted, FP hook). F3 = off, F4 = legacy 900ms/tail hook."
```

```
// HZM coop - RELOAD FEEL: OFF  [bound to F3]
// Kills the whole layer, including the v1 behaviour. This is the single rollback command.
coop_reloadSway 0
coop_reloadDebug 0
echo "RELOAD FEEL: OFF. F2 = on, F4 = legacy."
```

```
// HZM coop - RELOAD FEEL: LEGACY v1  [bound to F4]
// Exactly what shipped 2026-08-19: hardcoded 900 ms ramp, no class weight, applied at the
// CG_CalcViewValues tail (so it runs in third person and the gun tracks it). A/B against F2.
coop_reloadRetime 0
coop_reloadWeight 0
coop_reloadHook 0
coop_reloadSway 1.6
echo "RELOAD FEEL: LEGACY v1 (900ms, tail hook). F2 = new."
```

Binds in `autoexec.cfg` next to the ragdoll block at `:1249-1253` — **F2/F3/F4 are free**; F1, F7
(double-bound at `:1162` and `:1249`), F8, F9, F10 (double-bound at `:73` and `:1251`) and F11 are
all taken.

**(e) Defaults.** `coop_reloadSway`, `coop_reloadSwayAds`, `coop_reloadSwayMax`, `coop_reloadWeight`,
`coop_reloadRetime`, `coop_reloadHook` go in **`coop_defaults.cfg`**, never `autoexec.cfg` —
bug-710 / TRAPS T7: `autoexec.cfg` execs *after* the saved config and re-forces the default every
launch, which is a live bug on `coop_injurySway` today (`autoexec.cfg:513`). `coop_reloadDebug` gets
flags `0` and is seeded nowhere: TRAPS T7, *"never give a diagnostic `CVAR_ARCHIVE`"*.

---

### STAGE 2 — "Can you tell two Thompson reloads apart?"

**Only if Stage 1 lands and the user asks for more.** Default `coop_reloadVary 0` = Stage 1 exactly.

**IN**
- One seed drawn **once, on the animation-start edge**, held for the whole instance. Use
  `Q_random(&s_seed)` (`qcommon/q_shared.h:823`) — a **private** stream. Do **not** use `random()`
  (`:826`), which shares the global `rand()` with per-shot viewkick (`cg_view.c:2693-2695`) and the
  ragdoll solver; drawing from it perturbs both.
- Per-instance amplitude ×[0.85, 1.15]; beat positions (0.28 / 0.62) warped ±12 %; a small
  signed roll bias; a small signed yaw (currently absent — the layer is pitch+roll only).
- Context modifiers, also latched on the edge, product clamped to 1.8× against the **1.6° base**
  (not against whatever the tuning session lands on, or the clamp drifts):
  **dry vs top-up** (`cg.snap->ps.stats[STAT_CLIPAMMO]` still holds the pre-reload count on the
  edge — `FillAmmoClip` is an anim event, `fgame/weapon.cpp:3724`, and the manual fill at `:3727` is
  the failure path only), **crouched** (`PMF_DUCKED`, `bg_public.h:256`), **moving**
  (`cg.snap->ps.speed`, guard the divide).
- `coop_reloadSeed <n>` to freeze the stream for A/B — with it set, five reloads must be identical;
  at 0, visibly different. That is the literal acceptance test for the user's words.

**OUT**
- Stamina and suppression as inputs. `s_spStam` is a **block-scope** static inside a nested brace
  in `CG_OffsetFirstPersonView` (`cg_view.c:1336`) — hoisting it is not the "2 lines" the variation
  lens claimed; `s_coopSuppress` (`:538`) is decayed inside `CG_CalcFov` (`:2652`), one hook *after*
  the advance, so it is one frame stale.
- The discrete "fumble" variant. Cute, bounded, low value per line; hold until the continuous
  variation is tuned.
- Second-order spring / overshoot. Needs Stage 1's clamp under it first, and `ζ=1.0` just
  reproduces Stage 1.

---

### STAGE 3 — "Should the other actions share this layer?"

**IN** — generalise to `CG_ActionFeel`, serving three more `iViewModelAnim` states that are already
state-machined, already unserved, and all occur in windows where the weapon cannot fire:
`VM_ANIM_RECHAMBER` (5) — the bolt cycle on a Kar98/Springfield, currently silent;
`VM_ANIM_PULLOUT` (9) / `VM_ANIM_PUTAWAY` (10) — weapon raise/lower, a real heft cue. All three get
phase from the same clock and weight from the same class table; zero new signals.

**OUT permanently** — see §8.

---

## 5 — PARAMETER TABLE

Every tunable in Stage 1. **The one to sweep live is `coop_reloadSway`.**

| cvar | default | range | flags | seeded in | what it controls |
|---|---:|---|---|---|---|
| **`coop_reloadSway`** ← **sweep this** | `1.6` | 0 – 4 deg | `CVAR_ARCHIVE` | `coop_defaults.cfg` | Peak pitch in degrees before class weight. `0` disables the entire feature. Existing cvar, existing default — the build is a no-op on this axis. |
| `coop_reloadSwayAds` | `0.15` | 0 – 1 | `CVAR_ARCHIVE` | `coop_defaults.cfg` | Multiplier while ADS or scoped. 0.15 × 1.6 = **0.24°** peak = 7.6 px at 1080p ADS — just above `cg_scopeSway`'s already-accepted 0.175° pitch. `0` = fully suppressed in ADS. |
| `coop_reloadSwayMax` | `3.0` | 0.5 – 6 deg | `CVAR_ARCHIVE` | `coop_defaults.cfg` | Hard ceiling on the eased state, after class weight. At the MG weight 1.50 the uncapped peak is 2.40°, so this only bites if the sweep pushes `coop_reloadSway` past 2.0. |
| `coop_reloadWeight` | `1` | 0 / 1 | `CVAR_ARCHIVE` | `coop_defaults.cfg` | Per-class amplitude: pistol 0.55, SMG 0.80, rifle 1.10, MG 1.50, heavy 1.35. `0` = every gun at 1.00 (v1 behaviour). |
| `coop_reloadRetime` | `1` | 0 / 1 | `CVAR_ARCHIVE` | `coop_defaults.cfg` | `1` = phase normalised against `cgi.Anim_Time`. `0` = the v1 900 ms constant. **This is the feature.** |
| `coop_reloadHook` | `1` | 0 / 1 | `CVAR_ARCHIVE` | `coop_defaults.cfg` | `1` = apply at the end of `CG_OffsetFirstPersonView` (1P-only, sights honest, no lag-spring feed). `0` = the v1 `CG_CalcViewValues` tail. Relocation-only rollback. |
| `coop_reloadDebug` | `0` | 0 / 1 | **`0` — never archive** | nowhere (TRAPS T7) | One `^~^~^ WFEEL` line per animation-start edge. Diagnostic only. |
| *(Stage 2)* `coop_reloadVary` | `0` | 0 – 1 | `CVAR_ARCHIVE` | `coop_defaults.cfg` | Per-reload variation gain. `0` = Stage 1 exactly. |
| *(Stage 2)* `coop_reloadSeed` | `0` | int | `0` | nowhere | Non-zero freezes the variation stream for A/B. |

**Untouched but adjacent, listed so the sweep does not collide with them:** `cg_scopeSway` 0.25,
`cg_adsSway` 0.4, `cg_adsRecoil` 0.5, `cg_weaponLag` 0.7 / `cg_weaponLagADS` 0.35 /
`cg_weaponLagMax` 3.5, `coop_injurySway` 1.0, `cg_adsLeanRoll` 1.0, `cg_adsZoom` 0.70, `cg_fov` 80.

**Derived reference numbers** (re-derived this session, 1920×1080, 16:9):
hip `cg_fov` 80 → `fov_y` 50.53° → **19.97 px/deg**; ADS 80 × 0.70 = 56° → `fov_y` 33.30° →
**31.51 px/deg**. So 1.6° = **32 px** hip-fire, and the ADS-scaled 0.24° = **7.6 px**.

---

## 6 — ACCEPTANCE EVIDENCE

The user is the sole tester and does not take debug homework
(`docs/21-user-preferences.md:54`): drive the console over rcon (`scratchpad/rcon.py` →
`127.0.0.1:12203`) and read `%APPDATA%\openmohaa\maintt\qconsole.log`. Set `coop_reloadDebug 1` over
rcon yourself; the user only plays and says what they saw. Sweep the **whole** log after the boot,
not just the `WFEEL` lines (`21-user-preferences.md:57`).

### Stage 1 — A. THE HEADLINE (this is the one the build exists to answer)

- **Do:** rcon `exec coop_mod/cfg/wfeel_on.cfg`. User equips an M1 Garand, fires one shot, reloads.
  Then a Kar98, one shot, reload. Standing still, hip-fire, first person.
- **SEE:** the Kar98's lift takes visibly longer to reach the top, and — the part that is new —
  **comes back down before the animation finishes** instead of sitting at full lift. The Garand's
  whole arc is over in two-thirds the time.
- **LOG proves it numerically:**
  `^~^~^ WFEEL state=6 slot=3 idx=<n> len=2.000 class=0x2 wt=1.10 peak=1.76 hook=1`
  `^~^~^ WFEEL state=6 slot=4 idx=<n> len=3.367 class=0x2 wt=1.10 peak=1.76 hook=1`
  Two different `len` values, matching the table in §1. Same `wt` (both rifles) — the divergence is
  pure timing, which is the claim.
- **FAILURE SIGNATURE THAT STOPS THE PROJECT:** both lines print `len=0.900`. That is the fallback,
  meaning `cg.pPlayerFPSModel` was NULL, the index was −1, or `cg_viewmodelanim.c:583-586`
  substituted `idle`. Fix that before anything else; nothing downstream is meaningful.
- **SOFT FAILURE, ALSO STOPS THE PROJECT:** the `len` values are correct and the user says the two
  reloads still feel the same. Then 1.68× is below the noticing threshold, the whole premise is
  wrong, and Stage 2 should not be built — say so and move to the ragdoll queue.

### Stage 1 — B. PER-SHELL RHYTHM

- **Do:** shotgun, fire 3, reload. Repeat with a Springfield.
- **SEE:** three distinct pumps — up on the shell going in, back down between shells — instead of
  one flat hold for the whole magazine, then a single snap-down on the cock that **returns to
  level** rather than parking below it.
- **LOG:** three `state=7` lines with `len=0.633` (shotgun fill) / `len=0.900` (springfield fill),
  each with a **different `slot=`**; then one `state=8 len=1.033`.
- **FAILURE:** one `state=7` line only → the `force_restart` edge is not reaching
  `g_iCurrentVMAnimSlot`; re-check `cg_viewmodelanim.c:500` and `:580`.

### Stage 1 — C. ADS REGRESSION GATE *(mandatory)*

- **Do:** hold ADS on a Garand and fire until it auto-reloads while ADS is still held. Then repeat
  scoped, with a Springfield '03 Sniper (this is the `STAT_INZOOM` path, which
  `CG_AimingDownSights()` alone does **not** catch — C4).
- **SEE:** the front post stays inside the rear notch for the whole reload; the scope reticle does
  not drift off the target. Immediately after the reload ends, one shot at a wall ~300 units away
  must put its decal on the crosshair.
- **LOG:** the peak applied under sights is `0.24°`; at 300 units that is
  `tan(0.24°) × 300 = 1.26 units` of crosshair displacement, comfortably inside a crosshair glyph,
  and the tail is under 0.1° within 0.5 s of `RELOAD_END`.
- **FAILURE:** sights visibly separate, or the decal lands off the crosshair → rcon
  `coop_reloadSwayAds 0` (feature stays on everywhere except sights) and re-test. If it persists at
  0, the relocation is wrong, not the scale — go to `coop_reloadHook 0`.

### Stage 1 — D. THIRD-PERSON REGRESSION GATE *(mandatory)*

- **Do:** rcon `cg_3rd_person 1`, reload. Then reload **while in cover** (`PMF_COOP_COVER` forces 3P
  at `cg_view.c:2576`) — that is the case a hand-written `CG_AdsForceFirstPerson()` gate would get
  wrong, and the only reason the structural gate is worth the relocation.
- **SEE:** the world does **not** tip. The chase camera stays level through the entire reload, in
  both cases. Today (`coop_reloadHook 0`) it tips in both — that contrast is the proof.
- **LOG:** no visual to log; prove it by A/B — `exec coop_mod/cfg/wfeel_legacy.cfg` (F4), reload in
  3P, world tips; F2, reload in 3P, it does not.
- **FAILURE:** it still tips at `hook=1` → the apply is reaching a 3P path; the `bUseWorldPosition`
  test at `:1518` is the first suspect.

### Stage 1 — E. CUTSCENE GATE

- **Do:** load `m1l1` and let the intro cutscene play; reload nothing.
- **SEE:** no camera motion attributable to this layer. Structural: `cg_modelanim.c:2036` gates the
  whole block on `!(pm_flags & PMF_CAMERA_VIEW)`, and the advance targets zero in that state.
- This is the bug-1942 hazard in reverse — that bug was the effect landing *only* in the cutscene
  branch. Confirm by seeing, not by reading the diff.

### Stage 1 — F. HITCH STABILITY

- **Do:** rcon `fixedtime 200` (note: the cvar is **`fixedtime`**, not `com_fixedtime`, and it is
  `CVAR_CHEAT` — `qcommon/common.c:1916`), reload, then `fixedtime 0`.
- **SEE:** the lift eases. It must never flip sign, dive, or snap.
- **The real guarantee is in the code, not the test:** `k ≤ 1` makes the error strictly contract at
  any `dt`. Re-derived: unclamped at rate 11.0, `k > 1` at `dt > 90.9 ms` and `k > 2` at
  `dt > 181.8 ms`; a remote client's 5000 ms ceiling gives `k = 55`.

### Stage 2 — the one test that matters

`coop_reloadSeed 7`, reload five times → identical. `coop_reloadSeed 0`, reload five times →
visibly different. If the user cannot tell the two runs apart, Stage 2 is dead and should be
reverted, not tuned.

---

## 7 — ROLLBACK

| scope | command |
|---|---|
| **The whole feature, everything** | `coop_reloadSway 0` — or press **F3**. The guard at the top of `CG_ReloadFeelAdvance` zeroes both statics and returns; `CG_ApplyReloadFeel` early-outs on `0 && 0`. Nothing else in the frame reads either static. |
| Stage 1 retiming only (back to 900 ms) | `coop_reloadRetime 0` |
| Stage 1 relocation only (back to the v1 tail hook) | `coop_reloadHook 0` |
| Class weight only | `coop_reloadWeight 0` |
| ADS contribution only | `coop_reloadSwayAds 0` |
| Everything at once, back to exactly what shipped 2026-08-19 | `exec coop_mod/cfg/wfeel_legacy.cfg` — or press **F4** |
| Stage 2 variation | `coop_reloadVary 0` |
| Binary | restore `cgame_pre_wfeel_bak.dll` — take the backup **before** the build, per the project's `<binary>_pre_<feature>_bak.<ext>` convention (`docs/OPEN.md`, 25 existing cgame rollback points). `cgame.dll` ships alone; there is no protocol change, so no exe/game pairing. |

---

## 8 — WHAT THIS LAYER SHARES WITH THE REST OF THE MOD

The question is whether one motion layer should also serve recoil recovery, weapon raise/lower,
sprint, landing and melee. The answer is **three yes, three no**, and the line is not aesthetic — it
is whether the mod already owns that channel and whether the weapon can fire during the window.

### Should share it — Stage 3

| action | signal | why it fits |
|---|---|---|
| **Bolt rechamber** | `VM_ANIM_RECHAMBER` (5) | Same state machine, same clock, same class weight. Currently silent, and it is the beat the Kar98/Springfield are missing between shots. Weapon cannot fire during it. |
| **Weapon raise** | `VM_ANIM_PULLOUT` (9) | The single most under-served heft cue in the mod: a BAR and a Colt currently come up identically. Weapon cannot fire during it. |
| **Weapon lower** | `VM_ANIM_PUTAWAY` (10) | Symmetric with raise, free once raise exists. |

All three read from the identical `g_iCurrentVMDuration` / `cgi.Anim_Time` pair, need no new
signals, and inherit the ADS scale and the 3P gate unchanged. That is the whole argument for
generalising rather than copying: **the layer's value is the clock, not the curve.**

### Should NOT share it — the mod already owns these channels, in gun space

| action | who already owns it | why a second layer is a defect, not a feature |
|---|---|---|
| **Recoil recovery** | `cg_adsRecoil`, `cg_view.c:1234-1252` | Already a per-class kick (0.6/0.85/1.35/1.5/1.3 at `:1117-1121`) with its own decay, applied to `pREnt->origin` along `mat[2]`/`mat[0]`. Adding a camera-space recoil term stacks a second, incommensurate oscillator on a channel that is tuned, shipped and accepted — and, unlike a reload, **the weapon can fire during recovery**, so it would be a standing aim lie. |
| **Sprint** | the sprint gun-lower, `cg_view.c:1325+` | Already eased in/out with its own run-bob, already gated on the same inputs the server's `TickSprint` uses, already 1P-only. |
| **Landing** | nothing — and it stays that way for now | The obvious edge is not readable from either hook: `cg.bFPSOnGround` is compared and then immediately overwritten on the next line (`cg_modelanim.c:1891-1892`), one stage *after* the advance. It would need its own latch off `cg.predicted_player_state.walking`. Cheap, but it is a different feature with a different acceptance test — do not smuggle it in. |
| **Melee / bash** | nothing | There is no `VM_ANIM_*` state for it; it would need a new signal, and the bash window is one where the player is very much still in a fight. Out of scope. |
| **Idle hand tremor** | `cg_adsSway`, `cg_view.c:1208-1213` | Covered in C8. If ever wanted, it is a **multiplier on `cg_adsSway`'s existing amplitude** plus an extension of that block to hip-fire (it is `bAds`-only today, which is the actual gap), keeping the `s_breathSteady` kill and staying on `pREnt->origin`. Never a new camera oscillator. |

### The rule this establishes, for the next session

> **Camera-space motion is legal only inside a window where the weapon cannot fire, and only from
> inside `CG_OffsetFirstPersonView`. Everything else moves the gun.**

That is not invented here — it is the line `cg_scopeSway` (camera, scope only, gun hidden) and
`cg_adsSway` (gun, everywhere else) already draw, and the line bug-168 discovered the hard way from
the other direction. Write it into `docs/TRAPS.md` when Stage 1 ships.

---

## 9 — RISK REGISTER

Top five by probability × impact.

| # | Risk | P | Impact | Mitigation | Detect |
|---|---|---|---|---|---|
| **R1** | **The relocated hook fires nowhere and the effect goes dead** — the exact bug-1942 / bug-165 / bug-168 failure mode, three times in this file's history, twice on *this feature*. | **Med** | High — a wasted session, and the user has already sat through two dead builds of this same feature | `coop_reloadHook 0` restores the v1 placement in the same binary. The advance runs unconditionally at `:2643` regardless of hook, so the state is never dead — only the apply can be. | Acceptance A: `^~^~^ WFEEL` lines print but nothing moves ⇒ apply-side, not signal-side. That split is why the instrument logs on the **edge** rather than on the apply. |
| **R2** | **Motion sickness** — the layer becomes always-on-feeling because reloads are frequent, and a player who hates it has no way out. | **Med** | High — this is a WW2 shooter played for hours, and the complaint arrives late | Bounded by construction: `coop_reloadSwayMax 3.0` hard-clamps the eased state; the envelope **cannot accumulate** because `cg.refdefViewAngles` is freshly assigned from `ps->viewangles` every frame (`cg_view.c:2314`); the target is 0 in every non-reload state; and the tail hard-zeroes below 0.004°. Tunable to zero by a player: `coop_reloadSway 0`, `CVAR_ARCHIVE`, seeded in `coop_defaults.cfg` so a menu change persists (bug-710). **Stage 1 also strictly REDUCES total motion**: the parked plateau — the longest-duration component today — is removed. | Ask the user directly after 30 minutes of play, not after one reload. If it reads as too much, halve `coop_reloadSway` before touching anything structural. |
| **R3** | **ADS sight picture degrades on a gun nobody tested** — 45 hand-dialled per-gun ADS alignments exist (`cg_modelanim.c:1187-1241`) and this layer is applied uniformly. | Med | Med | The relocation makes the sights **honest** (C2), so the failure mode is readability, not accuracy; 0.24° = 7.6 px is below `cg_scopeSway`'s already-shipped-and-accepted budget; `coop_reloadSwayAds 0` removes it entirely without disabling hip-fire. | Acceptance C, run on **both** an iron-sight gun and a scoped gun — the `STAT_INZOOM` path is a different code branch. |
| **R4** | **The 1.68× spread is below the noticing threshold** and the user says "still feels the same". | **Med** | Med — the premise, not the code, is wrong | Nothing to mitigate; this is the honest failure. It is cheap to discover (one session) and the answer is decisive. | Acceptance A's soft-failure branch. If it fires: report it plainly, revert with F3, do not build Stage 2, move to bug-1976. |
| **R5** | **Silent `idle` fallback poisons the phase** — `cg_viewmodelanim.c:583-586` substitutes `idle` when `<prefix>_reload` does not resolve and warns only through `DPrintf`, which is developer-gated here. A gun with a missing reload anim would normalise against an idle length and crawl or never complete, with no visible diagnostic. | Low | Med | The edge code compares the resolved index against `cgi.Anim_NumForName(tiki, "idle")` and band-limits to 0.2–6.0 s, falling back to 900 ms; that fallback is *visible* in the log as `len=0.900`. | Acceptance A's hard-failure signature is literally this. Also sweep the log for `Couldn't find view model animation` with `developer 1` on the first boot. |

**Deliberately accepted, not mitigated:** exiting third person mid-reload resumes the phase from
where it froze (`g_iCurrentVMDuration` does not advance in 3P because `CG_ViewModelAnimation` sits
inside `if (!bThirdPerson)`, `cg_modelanim.c:1904/:1954`) — the advance targets zero while 3P so the
envelope is already decayed, and it self-corrects at the next animation edge. Sub-second, and the
alternative costs more than it buys.

---

## 10 — WHAT WAS VERIFIED THIS SESSION, AND WHAT WAS NOT

**Proven by reading source or parsing the shipped assets:** every line citation in this document;
the full frame order (`CG_CalcViewValues` `cg_view.c:2962` → `CG_AddPacketEntities` `:3078` →
`CG_ModelAnim` → `PmoveAdjustAngleSettings_Client` `cg_modelanim.c:1456` → `CG_ViewModelAnimation`
`:1954` → `ForceUpdatePose` `:1956` → `CG_OffsetFirstPersonView` `:2039` → `AnglesToAxis` `:2042`);
the arms-bone pitch path (`fgame/bg_pmove.cpp:1743-1752`); the anim clock reset/accumulate
(`cg_viewmodelanim.c:588/590/620`); the `TAF_DELTADRIVEN` split between SKC-header flags
(`tiki/tiki_anim.cpp:283-284`) and TIKI-animdef flags (`:442-454`, `tiki/tiki_parse.cpp:247-248`),
and that no `fps_anims_*.txt` line declares `deltadriven`; all 16 v13 reload durations; the
`Com_ModifyMsec` clamp table (`qcommon/common.c:2194-2216`); every `cgi` signature used
(`cg_public.h:103, 122, 342, 345, 384, 387, 390, 442`); `CVAR_TEMP 0x0100` and `CVAR_CHEAT 0x0200`
(`q_shared.h:1308-1309`); `fixedtime` is the cvar name, not `com_fixedtime` (`common.c:1916`);
F2/F3/F4 are free and F7/F10 are double-bound (`autoexec.cfg:73, 1162, 1249-1253`); the pixel-per-
degree figures, the smoother divergence thresholds and the ADS displacement, all re-derived rather
than copied.

Also confirmed: `CG_AimingDownSights` is prototyped at `cg_local.h:645`, so it is in scope at the
new `cg_view.c:1518` call site (its definition at `:1540` is below it), and `MAX_FRAMEINFOS` is 16
(`q_shared.h:2141`) — the slot counter would have to restart 16 times between two frames to alias,
which the shortest per-shell clip (0.633 s) makes impossible.

**Not verified, and flagged as such:** SH/BT (SKAN v14) reload durations — the runtime path covers
them, but no offline number for them appears in this document and none should be added by a v13
parser. And the *felt* result of the relocation: the gun no longer tracking the camera pitch is a
genuinely different look from what shipped on 2026-08-19, and only the user can say whether it reads
as heft or as a floating gun. That is what `coop_reloadHook` exists for.
