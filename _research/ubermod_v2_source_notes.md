# OwN-3m-All's Ubermod V2: what the source actually says

Read 2026-09-13 from `Ubermod Public Release V2.zip` (10,559,457 bytes, storage.moh-db.com), downloaded with the user's
approval and read only. Text files were extracted to the session scratchpad; nothing was run (the pack's
MohaaConfigGenerator.exe was not touched) and nothing from it is in the mod. Mechanics below are paraphrased, not copied.
Companion research: kings_push_hunt.md, community_modes_deepdive.md, mp_gamemodes_understanding.md.

## How the pack selects modes

- Requires the Reborn 1.12 server patch (bundled ReadMe).
- `g_extgametype_<mapname> <type>` per map, dispatched by Mefy's library (`global/libmef/gametypes.scr`: base types
  ffa / tdm / rbm / obj, plus dem, ctf, ft and their freeze-tag variants).
- `cust_gameMode` for OwN-3m-All's custom modes: 1 "BB Different" (Build-A-Base), 2 "Uber BB with Planes" (Base Builder),
  5 "V2 Owns MOD", 6 Base Assault, 7 Rabbit, 10 Push.
- `g_bas 1` enables Base Assault; `lastManStanding 1` and `teamBalance 1` enable those helpers.
- Each mode has a sample server cfg under `server_mod/*/main/configs/` (push.cfg, bb.cfg, bb2.cfg, bassault.cfg, dem.cfg,
  ctf.cfg, rabbit.cfg, freeze*.cfg, soccer.cfg, countdown.cfg ...).

## Build-A-Base vs Base Builder

Same idea - a timed build phase to put up fortifications, then the fight - with different building tools.

| | Build-A-Base (`bb/`, "Build=A=Base") | Base Builder (`alienx/basebuild.scr`, AlienX) |
|---|---|---|
| Selected by | `cust_gameMode 1` (sample bb2.cfg: gametype 2, build_time 10) | `cust_gameMode 2` "Uber BB with Planes" (sample bb.cfg: gametype 3) |
| How you build | USE spawns an object you carry; LEAN switches object type; primary fire places it; hold secondary to throw it; holster and use the movement keys to rotate it; WALK + forward/back moves it further or closer; double-click primary on a placed object to pick it up again, double-click secondary to delete it | Spinning pickup objects are placed at fixed points on the map; walk into one to "become" it, then press K to kill yourself and it is dropped as a solid object where you stood; falling damage is off while building |
| Maps | Any map | Needs a per-map object layout (`alienx/maps/`) |
| Limits and rules (defaults) | build time 5 minutes, 300 objects, objects can explode, only admins delete by default, delete-own / delete-own-team options | a wait time before the level really starts; object limit set by the caller; the Ubermod variant adds planes (`alienx/createPlanes.scr`) |

## Base Assault (`global/BAS/`, `base_assault/`)

- Enabled by `g_bas 1` on gametype 3, 4 or 5, and only on maps in its whitelist (`global/BAS/map.scr`), which includes
  single-player maps such as m1l3a, m1l3b, m4l0, m4l1, m4l3, m5l2a and m5l2b; per-map setup in `base_assault/maps/`.
- Each team has up to three bases, represented by tank models (Allied: Sherman, swapped to its damaged model when
  destroyed). Objective text: destroy the enemy bases and detonate them.
- Bomb timings: planting 15 s, defusing 10 s, fuse 60 s. Respawning on; 30-minute round limit; clock side "draw".
- HUD uses the allies/axis, explosives and wirecutters icons. No author credit in the files (identifiers are Hungarian).

## Push ("Push to Gain Ground", `push_maps/`)

- By OwN-3m-All; the standalone release credits code adapted from ViPER's Gain Ground mod.
- Seven converted single-player maps: m1l2b, m2l1, m3l3, m4l1, M4L2, M5L1A, m5l1b. Team Match (`g_gametype 2`).
- Each map script spawns ordered groups of team spawn points (targetnames alh, al2 .. al9 for Allies; axh, ax2 .. ax9 for
  Axis); the active group advances as a team reaches the next checkpoint. Objective text: Axis move to the smoke, Allies
  move to the sparks. An older teleport-based version is kept under `misc/old/push_old_angle_teleport/`.

## Last Man Standing (`global/lastManStanding.scr`)

- By OwN-3m-All. With `lastManStanding 1` in any team gametype it counts living players every second and shows a HUD
  callout naming a team's last surviving player (optional live player counts). It also contains a team balancer.
- It is an announcement layer, not an elimination rule: elimination itself comes from the round-based gametypes.

## Demolition and Capture the Flag (Mefy)

- Mark Follett's Server-Side Gametype Libraries, 2003-2005: `global/libmef/dem.scr` (Demolition 1.3.2), `ctf.scr`
  (CTF 1.4.2), plus `ft.scr`, `tow.scr`, `bases.scr`, `bomb.scr`, `respawn.scr`, `spectate.scr`, `hud.scr`,
  `gametypes.scr` (1.0.2).
- Base gametype 4 on objective maps, 3 otherwise; freeze-tag variants ftdem and ftctf.

## Not in this pack

- King of the Hill, Gun Game, Search & Destroy. (S&D exists in searingwolfe's UBER MODS; the stock gametype-4 bomb game is
  close to it.)

## Licences and credits

- **Mefy's libraries: MIT licence** - reuse is allowed if the copyright and permission notice is kept.
- **Last Man Standing:** "Modify anything you want, please leave credits at the beginning of this file."
- **`bb/cvars.scr`:** the author invites editing that file; the rest of Build-A-Base carries no licence text.
- **AlienX Base Builder, Base Assault, the Push map scripts:** no licence text - rebuild from the rules, or ask the authors.
- ReadMe credits: OwN-3m-All created the Push Mod, Rabbit, OwN's Special Teleporter Mod, Last Man Standing, the Team
  Balancer, all config files and some scripts; the admin menu is a variant of Merlin's; thanks to Elgan (elgbot), Sor,
  RazorRapid (Reborn), Merlin and Creaper.
- Other contents worth knowing: Rabbit (`rabbit/`), Beach Soccer (`global/libmef/gametypes/beachsoccer.scr`), Countdown,
  Elgan's bots (`elgbot/`), third person, jetpack, guided missile, and single-player-to-multiplayer map conversions.
