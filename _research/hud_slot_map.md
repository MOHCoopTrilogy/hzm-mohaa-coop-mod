# HUD Slot Allocation Map — ihuddraw elements 0-255

The engine exposes **`MAX_HUDDRAW_ELEMENTS = 256`** shared HUD slots
(`openmohaa-hzm/code/qcommon/q_shared.h:1788`), addressed from script via
`ihuddraw_* <player> <slot> ...` and shared with the cgame through the `cgi`
import struct.

> ## Do not hand-maintain this file. Sweep it.
>
> ```powershell
> python docs\tools\hudslots.py 100 255      # or no args for the whole 0-255 range
> ```
>
> **This table is rebuilt from that sweep.** It was hand-maintained until 2026-08-10 and had
> drifted far enough to be dangerous (bug-1680): it still listed `cover.scr` at 40-44 and
> `ammobox.scr` at 45-47 long after both moved into the fade-exempt band, it advertised
> **141-149 as a free reserve when only 149 was left**, and it showed no conflict at all for
> `objectives.scr`, which quietly owns 135-142. A feature trusting the table would have claimed
> an occupied slot — which is exactly what nearly happened to the Phase C contain prompt.
>
> **The literal-slot grep is not enough, and that is precisely how the collision hid.** Several
> features COMPUTE their slot (`local.slot = 136 + local.line`), so a grep for digits finds 135
> and 142 and misses 136-141 entirely. `hudslots.py` reports computed sites separately and
> loudly for this reason. **Absence from the literal table is not evidence a slot is free** —
> check the computed-base list below before claiming anything.

## Two rules that cost real features

1. **A slot below 100 fades out exactly when the player needs to read it.** The engine
   multiplies alpha by `s_hudFadeAlpha` for every slot **below 100** when the player is calm
   (`cg_drawtools.cpp:651-653`). Standing still holding a key *is* calm. This trap has now cost
   **six** features: the team-revive HUD (21-26), the blueprint acknowledgement, the XP micro
   popup (bug-1668), the cover prompt, the ammo prompt, and it would have cost the Phase C
   contain prompt. **Anything a stationary player must read goes at 100 or above.**
2. **Two features that can be on screen together must not share a slot.** That was bug-553 (the
   debrief card and the XP gain popup both drew on 62-69 and fought for ~3 seconds). Reuse is
   allowed *only* when the two are provably never concurrent, and must then be gated explicitly
   — the pattern is `coop_xp_summaryActive` in `xp.scr`.

## Current allocation (measured 2026-08-10)

| Slots | Owner | File(s) | Notes |
|---|---|---|---|
| 0-1 | weather / shared chrome | weather.scr, player.scr | |
| 10, 20 | shared coop HUD (objectives seed) | player.scr, dbno.scr | |
| 27-39 | DBNO / downed / medkit / low-HP warning | dbno.scr, medkit.scr, player.scr | one "downed/heal" cluster, never concurrent with each other. **Below 100 — fades.** |
| 45-47 | *(vacated)* | — | ammobox moved to 148 |
| 40-44 | *(vacated)* | — | cover prompt moved to 145-147 |
| 50-53 | officer + paradrop banners | officer.scr, paradrop.scr | not concurrent (officer wave vs para call) |
| 54-59, 61 | build mode readout | buildmode.scr | **computed** (`local.i = 54`, buildmode.scr:885). dev/build tool only |
| 62-72 | **XP system** | xp.scr | gain popup 62-69, promo ceremony 70-72. Still below 100, so the gain popup has the same latent fade problem whenever it fires while the player is still; **the debrief card reuses 62-71 SEQUENTIALLY**, gated by `coop_xp_summaryActive` (bug-553) |
| 76-78 | challenge completion toast | challenges.scr | |
| 84-87 | challenge progress popup | challenges.scr | |
| 88-94 | fog mode | fogmode.scr | |
| 95-96 | arena deploy curtain | maps/e3l4_arena.scr | arena maps only; torn down on deploy, 25s failsafe |
| 100-111 | lobby roster (3 per row × 4 rows) | lobby.scr | **computed** (`local.rankSlot = 100 + ((p-1)*3)`, lobby.scr:766) |
| 112-114 | lobby help (112-113) + countdown (114) | lobby.scr | wiped 100-114 on lobby end |
| 115-116 | briefing / lobby ready gate | readygate.scr | |
| 117-126 | lobby NEW UNLOCKS list | lobby.scr | header 117, 8 lines **computed** `118 + j` (:915), "+N more" 126. Lobby-time only |
| **118-120** | **m2l2a Naxos sabotage** — prompt/status line (118) + bar track (119) + fill (120) | maps/m2l2a.scr | ⚠️ **deliberate never-concurrent reuse of 118-125 above.** Mission-time vs lobby-time are strictly disjoint, and lobby.scr:901 wipes 117-126 itself on lobby end. Taken because the ≥100 band is otherwise full and a sub-100 bar fades out exactly while you hold USE watching it. 118 carries two mutually exclusive states of one feature ("Hold [USE] to sabotage the Naxos" / "Sabotaging the Naxos") so they cannot stack |
| 127-134 | debrief "UNLOCKED THIS MISSION" list | xp.scr | header 127, 6 lines 128-133, "+N more" 134. MISSION-END only, co-displays with the debrief card |
| **135-142** | ⚠️ **objectives.scr NEW OBJECTIVE toast** | objectives.scr | header 135, wrapped lines **computed** `136 + local.line` (:102), plus 142 (:117). **COLLIDES with the two rows below — see the conflict note.** |
| 135-140 | **DBNO team-revive channel** | dbno.scr | reviver text 135 + bar 136-137, downed text 138 + bar 139-140. Moved here from 21-26 because the medic reads as "calm" |
| **121** | **m6l2a transmit prompt** - "Press [USE] to Transmit False Signal" | maps/m6l2a.scr (`coop_m6l2aTransmitPrompt`) | free block between the Naxos 118-120 and 126; >=100 so the engine fade cannot hide it |
| 141 | blueprint pickup acknowledgement | collectible.scr | |
| 142-144 | **XP micro popup** ("+10 Revive", 3 stacked rows) | xp.scr | moved from 73-75 by bug-1668 |
| 145-147 | **take-cover prompt** | cover.scr | moved from 40-44 (fade) |
| 148 | **ammo box prompt** | ammobox.scr | moved from 45-47 (fade) |
| 149 | **Phase C outcome banner** — "Situation Contained. / Situation Escalated. Leave the Area Immediately." | bust.scr | one banner, two texts; exactly one of them ever fires, so they share |
| 150-155 | challenge service-record chrome | challenges.scr | menu/lobby-time only |
| 156-173 | challenge SR row names | challenges.scr | **computed** `156 + local.r` (:2465, :2568). Shares 156-173 with the mission-time objectives panel, never concurrent |
| 174 | challenge SR footer | challenges.scr, lobbyui.scr | |
| 156-165, 175-215 | **script-drawn objectives panel** | objectives.scr | `coop_objPanel 1`; plates 156-165, title 175, checkboxes 176-183, wrapped text 184-215; clear loop from `local.s = 156` (:496). MISSION-time only |
| 196-213 | challenge SR bar tracks | challenges.scr | **computed** `196 + local.r` |
| 214-231 | challenge SR bar fills | challenges.scr | **computed** `214 + local.r` |
| 232-249 | challenge SR counts | challenges.scr | **computed** `232 + local.r` (:2476) |
| **216** | **DBNO "\<name\> is down" banner** (top centre) | dbno.scr | ⚠️ **deliberate never-concurrent reuse** of the SR fills above: mission-time vs menu/lobby-time are disjoint. Taken because the ≥100 band is full and a sub-100 slot fades exactly when a stationary teammate is reading it. Moved off `iprint`, which is fixed at top-left and overlapped the compass |
| **250** | **Phase C contain prompt** — "Press [USE] to Contain The Situation", and the first-contact advisory "Avoid the Officer. Contain him only when alone." | itemhandler.scr (`enableClickablePapers` + `coop_papersAnytime`) | claimed 2026-08-10. Deliberately NOT on 149: player 2 can have this prompt up at the moment player 1 escalates, and the squad-wide banner would overwrite it. The two strings share the line by design — two messages in the DBNO position would stack |
| 251-253 | lobby UI cursor / misc | lobbyui.scr | |
| **254** | **Phase C "Body Being Investigated. Leave the Area Immediately"** | bust.scr (`coop_bustBodyWatch`) | claimed 2026-08-10; drawn at -74 so it does not sit on the DBNO line |
| **255** | **m2l2a Naxos room message** — "Wait for the scientists to be distracted to destroy the Naxos." | maps/m2l2a.scr | claimed 2026-08-10. DBNO line, 6s, **permanent one-shot latch per player** — it previously cleared on leaving the radius, so crossing the boundary re-fired it |

`player.scr::manageSpectator` also writes 135-149 and 250 — that is the **teardown backstop**
added by bug-1679, not a tenant. See below.

## Genuinely free

**Nothing.** The fade-exempt band (≥100) is now **full** — 250, 254 and 255 were the last three
spares and all were claimed on 2026-08-10 by Phase C and the Naxos rework.

Below 100, **measured 2026-08-10** by `hudslots.py` (the previous hand-written list advertised
88-99, but 88-94 is `fogmode.scr` and 95-97 is the arena curtain + holdout — check, don't trust):

`0-19 · 21-26 · 42-44 · 47-49 · 60 · 74-75 · 79-83 · 98-99` — 42 slots, but they **fade**, so they
are usable only for something a *moving* player reads. A stationary player will not see them.
`40-49` is the cleanest contiguous block: cover and ammobox vacated it, and the only remaining
writes are `player.scr`'s teardown clearing what used to live there.

**The next feature that needs a fade-exempt slot has to free some first.** Two candidates, in
order of safety:

1. Move `objectives.scr`'s toast out of **135-142** into the menu/lobby-only 216-249 range. That
   returns eight slots *and* fixes the live collision below.
2. **216-249** is menu/lobby-time only (challenge SR bars/counts), so a mission-time feature can
   double-book it under the same never-concurrent gating already used for 156-173 and 118-120.
   Gate it explicitly and record it here.

## ⚠️ Open conflict — objectives.scr 135-142 (bug-1680)

`objectives.scr`'s "NEW OBJECTIVE" toast occupies **135-142** and overlaps two live tenants:

- **135-140** — the DBNO team-revive channel (`dbno.scr`)
- **142-144** — the XP micro popup (`xp.scr`)

All three are mission-time and co-display trivially: completing an objective while a teammate
is being revived is ordinary play. **Not yet fixed** — a `.urc`-adjacent widget cannot be
diffed or run from a dev session, so rewriting one that currently works is a blind bet (TRAPS
T3, UI corollary). Suggested repair, when someone can watch it render: move the toast into
**216-249**, which is menu/lobby-time only.

## HUD teardown — the other half of owning a slot

`ihuddraw` state **persists on the client until something overwrites that slot.** Every
transient prompt in this mod is torn down by the loop that drew it, so any exit that loop does
not model leaves text on screen forever. bug-1679 was exactly this: the revive availability
prompt was drawn on *candidates* while all four teardowns cleared only the *reviver* and the
*downed player*, so the text stuck the moment the patient resolved — and going spectator was
just the route the user happened to notice.

**When you claim a slot, write the teardown for every exit, including the ones you do not
own** (the player dying, going spectator, the entity you were tracking disappearing). The
backstop for the one transition that ends all of them lives in
`player.scr::manageSpectator`, inside the `coop_everActive` block — **add your slot there too.**

## Rules

1. **Sweep before you claim.** `python docs\tools\hudslots.py` — do not trust this table alone,
   and never trust a literal grep.
2. Anything a stationary player must read goes at **100 or above**.
3. A feature that can co-display with an existing one gets its **own** block.
4. Reuse a range only if the two are provably never concurrent, and gate it explicitly.
5. Write the teardown for every exit path, and register the slot in the spectator backstop.
6. **Update this table when you claim slots** — then re-run the sweep to confirm it agrees.
