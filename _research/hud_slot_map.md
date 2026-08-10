# HUD Slot Allocation Map — ihuddraw elements 0-255

The engine exposes **`MAX_HUDDRAW_ELEMENTS = 256`** shared HUD slots
(`openmohaa-hzm/code/qcommon/q_shared.h:1706`), addressed from script via
`ihuddraw_* <player> <slot> ...` and shared with the cgame through the `cgi`
import struct. This is the **authoritative allocation** for the coop mod.

> **Before using a slot, check this table.** Two features that can be on screen at
> the same time MUST NOT share a slot number. That was **bug-553**: the end-of-mission
> debrief card and the top-of-screen XP gain popup both drew on 62-69 and fought over
> them for ~3 seconds at mission end ("massive bar at the top of the screen"). Fixed by
> gating the transient popups off while the card owns the HUD (`coop_xp_summaryActive`),
> but the real prevention is: **give every co-displayable feature its own block.**

## Current allocation

| Slots     | Owner                                   | File(s)                          | Notes |
|-----------|-----------------------------------------|----------------------------------|-------|
| 0-1       | weather / shared chrome                 | weather.scr, player.scr          | |
| 10, 20    | shared coop HUD (objectives seed)       | player.scr, dbno.scr             | |

| 27-39     | DBNO / downed / medkit / low-HP warning | dbno.scr, medkit.scr, player.scr | one "downed/heal" cluster; never concurrent with each other |
| 40-44     | take-cover HUD                          | cover.scr                        | |
| 45-47     | ammo box                                | ammobox.scr                      | |
| 50-53     | officer + paradrop banners              | officer.scr, paradrop.scr        | not concurrent (officer wave vs para call) |
| 54-61     | build mode                              | buildmode.scr                    | dev/build tool only |
| 62-72     | **XP system**                           | xp.scr                           | gain popup 62-69, promo ceremony 70-72. ~~micro popup 73-75~~ MOVED to 142-144 (bug-1668: faded invisible when calm). NOTE 62-69 still fade below 100 - the gain popup has the same latent problem whenever it fires while the player is still; **debrief card reuses 62-71 SEQUENTIALLY** (gated by `coop_xp_summaryActive` — see bug-553) |
| 76-78     | challenge completion toast              | challenges.scr                   | |
| 84-87     | challenge progress popup                | challenges.scr                   | |
| 88-94     | **fog mode**                            | fogmode.scr                      | was ABSENT from this table, which implied 88-99 free |
| 95-96     | arena deploy curtain (black + "CLICK TO DEPLOY") | maps/e3l4_arena.scr     | arena maps only; torn down on deploy, 25s failsafe |
| 100-114   | lobby roster (100-111, 3 per row x 4 rows) + help (112-113) + countdown (114) | lobby.scr | fade-exempt persistent-UI range (>=100); wiped 100-114 on lobby end |
| 115-116   | briefing / lobby ready gate             | readygate.scr                    | |
| 117-126   | **lobby NEW UNLOCKS list** (header 117, 8 lines 118-125, "+N more" 126) | lobby.scr (lobbyUnlockList), fed by challenges.scr | lobby-time only; fade-exempt; wiped on lobby end |
| 135-140   | **team revive channel** (reviver text 135 + bar 136-137, downed text 138 + bar 139-140) | dbno.scr | MUST be >= 100: the engine fade multiplies alpha for every slot BELOW 100 when the player is calm (cg_drawtools.cpp:648-656), and a medic holding USE while standing still is exactly "calm" - at 21-26 the reviver saw nothing. Co-displays with the DBNO cluster 27-39 and medkit.scr's self-revive bar 33-35 |
| 127-134   | **debrief "UNLOCKED THIS MISSION" list** (header 127, 6 lines 128-133, "+N more" 134) | xp.scr (xp_card_unlocks), fed by challenges.scr (per-map accumulator) | MISSION-END only, co-displays WITH the debrief card 62-73; fade-exempt (>=100); wiped when the card ends. Distinct from the lobby list 117-126 (never concurrent) |
| 141       | **blueprint pickup acknowledgement** ("Blueprint x / y Found", 3s) | collectible.scr (coop_bp_collect / coop_bp_hudClear) | MUST be >= 100 - the engine fade multiplies alpha for every slot below 100 when the player is calm (cg_drawtools.cpp:648-656), and picking a blueprint up in a quiet room is exactly "calm". 141-149 is the only free fade-exempt block: 135-140 is the revive channel, 150+ is challenges |
| 142-144   | **XP micro popup** ("+10 Revive", 3 stacked rows) | xp.scr (xp_micro_popup) | MOVED here from 73-75 by bug-1668. MUST be >= 100: the engine fades every slot below 100 by s_hudFadeAlpha when the player is calm (cg_drawtools.cpp:651-653), and reviving = standing still holding USE for ~5s = calm, so the text drew at alpha ~0. The XP was always awarded (96->106 verified); only the popup was invisible. Kill XP popped fine because shooting keeps the HUD awake. THIRD sighting of this trap in one day (revive HUD 21-26, blueprint ack, this) |
| 150-174   | challenge service-record panel (chrome 150-155, row names 156-173, footer 174) | challenges.scr, lobbyui.scr (174) | menu/lobby-time only — shares 156-173 with the mission-time objectives panel, never concurrent |
| 156-165, 175-215 | **script-drawn objectives panel** (word-wrap, styled like the old URC menu) | objectives.scr | coop_objPanel 1; grey plates 156(title bar)+158-165(row plates), separator 157, title text 175, checkboxes 176-183, wrapped text 184-215; MISSION-time only (menu-time SR panel reuses these numbers) |
| 196-249   | challenge SR panel progress bars (tracks 196-213, fills 214-231, counts 232-249) | challenges.scr | menu/lobby-time only — overlaps objectives 196-215 by the same never-concurrent gating |
| 251-253   | lobby UI cursor / misc                  | lobbyui.scr                      | |

## Free ranges

`2-9 · 11-19 · 21-26 · 30 · 48-49 · 60 · 79-83 · 88-99 · 141-149 · 250 · 254-255`

(156-249 are double-booked mission-time vs menu/lobby-time — see rows above; do not add a third tenant.)

## Reserved for the next features (claim top-down from here)

- **88-99** — next feature's exclusive block
- **141-149** — mid overlays (fade-exempt >=100) (135-140 taken 2026-08-10 by the team-revive channel)
- **250, 254-255** — spares

## Rules

1. **Check this table first.** Pick from a free range, not an occupied one.
2. A feature that can co-display with an existing one gets its **own** block.
3. Only reuse a range if the two features are provably never on screen together — and
   then gate it explicitly (pattern: `coop_xp_summaryActive` in xp.scr).
4. **Update this table when you claim slots.**
