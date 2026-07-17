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
| 62-75     | **XP system**                           | xp.scr                           | gain popup 62-69, promo ceremony 70-73, micro popup 73-75; **debrief card reuses 62-71 SEQUENTIALLY** (gated by `coop_xp_summaryActive` — see bug-553) |
| 76-78     | challenge completion toast              | challenges.scr                   | |
| 84-87     | challenge progress popup                | challenges.scr                   | |
| 112-114   | lobby roster / help / countdown         | lobby.scr                        | fade-exempt persistent-UI range (>=100) |
| 115-116   | briefing / lobby ready gate             | readygate.scr                    | |
| 150-155   | challenge service-record panel          | challenges.scr                   | menu-time only |
| 174       | challenge SR + lobby UI                  | challenges.scr, lobbyui.scr      | menu/lobby-time only — never concurrent |
| 156-165, 175-215 | **script-drawn objectives panel** (word-wrap, styled like the old URC menu) | objectives.scr | coop_objPanel 1; grey plates 156(title bar)+158-165(row plates), separator 157, title text 175, checkboxes 176-183, wrapped text 184-215 |
| 251-253   | lobby UI cursor / misc                  | lobbyui.scr                      | |

## Free ranges (~180 slots)

`2-9 · 11-19 · 21-26 · 30 · 48-49 · 60 · 79-83 · 88-111 · 117-149 · 166-173 · 216-250 · 254-255`

## Reserved for the next features (claim top-down from here)

- **88-99** — next feature's exclusive block
- **100-111** — reserved (persistent-UI range, >=100 is HUD-fade-exempt like the lobby)
- **117-149** — mid overlays
- **200-250** — large transient overlays

## Rules

1. **Check this table first.** Pick from a free range, not an occupied one.
2. A feature that can co-display with an existing one gets its **own** block.
3. Only reuse a range if the two features are provably never on screen together — and
   then gate it explicitly (pattern: `coop_xp_summaryActive` in xp.scr).
4. **Update this table when you claim slots.**
