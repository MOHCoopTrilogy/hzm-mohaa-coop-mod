# King of the Hill: what the two community packs actually do

Read 2026-09-13. Both files were downloaded from storage.moh-db.com with the user's approval, then read only. Nothing was
run and nothing from either pack is in the mod. Mechanics below are paraphrased, not copied.
Companion notes: ubermod_v2_source_notes.md, community_modes_deepdive.md, mp_gamemodes_understanding.md.

| | Klownterfit KOTH (`gametypekoth1.0.zip`, 12,761 B) | ViPER Strategic Hold v5 (`zzzzz-ViPERS_Team_Hold_Mods_v5.zip`, 169,464 B) |
|---|---|---|
| Contents | `User-Gametype-Koth.pk3`: `global/switch.scr` dispatches on the map name to `koth/koth_trigdm1..7.scr` | `global/Strategic.scr` (2,441 lines) plus a template block pasted into over 40 map scripts |
| Maps | The 7 stock AA DM maps only | Over 100 hand-placed positions across AA, SH and BT: DM, objective, TOW and liberation maps, plus some SP maps |
| The hill | 14 hand-placed spots per map; one is picked at random on map load and **stays put** all map. The box is 200 x 200 x 100 units and a corona marks it (yellow = empty, blue = Allies, red = Axis) | One fixed box per map, sized per position, with a compass objective marker (`addobjective`/`setcurrentobjective`) and an optional glow marker |
| Who counts | Only the **first player** who touched the trigger. Leaving resets the count. An enemy walking in does not contest | **Team presence:** any player of a team inside the box feeds that team's timer, and the other team's timer resets. Two teams inside flip it back and forth, so neither scores |
| Scoring | 15 s held = 1 capture point; the capturer is force-respawned. **5 points wins** (hard-coded, although the readme says fraglimit) | `hold 1` Hold Match: a point every 15 s held, the leader at timelimit wins. `hold 2` Point Match: a point every 5 s, first to 50. `hold 3` Imperative: the first team to hold for one unbroken 60-90 s wins outright |
| Match end | Flips `g_gametype` to 4 for a frame and calls `teamwin` | Sets `timelimit 1`. The code comments say `teamwin` did not work in TDM |
| Extras | HUD score for each team | Health and weapon pickups at the position, team balancer, flashing team icons, a check-position USE trigger, cinematic endings, message loop toggle |
| Engine | Stock script commands only (`huddraw_*`, `teamwin`), no Reborn | Stock script commands only, no Reborn |
| Licence | None. The scoreboard names Creaper; the readme names Klownterfit; the string helpers are credited to Mefy | None. The credits list is in the instructions file |

## Flaws not to copy

- Klownterfit: only one player is tracked, there is no contest, the win score is fixed at 5, the hill never moves, and it
  forces a `sayteam` onto the capturer's client with `stufftext`.
- ViPER: a contested hill never freezes cleanly, positions are map-specific data (no fallback for other maps), and the
  end-of-match hack is a timelimit write.

## Recommendation for our mod

Neither pack has a licence, so we rebuild from the rules and credit both as inspiration. Proposed rules:

- Team presence scoring (ViPER): one point per second while only your team is inside. A contested hill pauses scoring.
- The hill **moves** every N minutes or after a capture (the modern rotating-hill rule; Klownterfit's random spot list is
  the seed of it), from a per-map list of 3-6 authored spots.
- First to the score limit wins, or the leader at timelimit. The Imperative variant (one unbroken hold wins) becomes a
  host option, not a separate mode.
- The hill shows as a marker on the compass bar and in the world. No `stufftext`.
- Map data: author spots for the stock DM maps first. Maps without data fall back to spots chosen from player spawn
  points.
