# v1.7.0 - Pick Your Fight

Multiplayer grows up. This release turns HZM MP from "pick a side and spawn" into a full
progression game with modes, bots, and gear you earn and keep.

## MP Progression + Service Record (new)
- Every kill is attributed server-side by weapon and class and credited to your record.
- Your progress is signed and carried in your userinfo, so it follows you from server to server
  and persists across sessions - no account, no login.
- Earn a rank from your total kills, and unlock each weapon class's armory by racking up kills
  with that class (default: 15 kills in a class unlocks it).
- A connected MP Service Record panel (from the Multiplayer Options screen) shows your rank,
  total kills, and kills by class.
- Tamper-resistant: an HMAC signature and a server-side high-water ledger stop edited or rolled-back
  records. Coop is completely unaffected - progression only runs on MP maps.

## Multiplayer modes and hosting
- Six MP modes: Gun Game, King of the Hill, Search & Destroy, Last Man Standing, Freeze Tag, Push.
- Fill any server with bots that scale to your player count.
- Hardcore modifier: no crosshair, half health, slower - composes with any mode.
- MP armories (Allied and Axis) with side-appropriate weapons; a Multiplayer Options menu to pick
  your mode, preset, and loadout.
- Gun Game: a melee/bash kill now demotes the victim one tier instead of resetting them.

## Fixes
- GL2: styled-lightmap surfaces (e2l1 bridge rails, e2l2 panels) no longer pulse red.
- MP voice and subtitles now match your worn armory skin's nationality.
- A connected controller no longer black-screens the game at launch.
- Bloom dialled back - less blown-out (still tunable in Post FX).

Coop players: nothing here changes your game. Every MP system is gated off on coop maps and the
build enforces that isolation automatically.
