# MP decisions, 2026-09-13

Answered by the user on the Multiplayer Decision Sheet artifact
(https://claude.ai/code/artifact/616468ce-aced-42a5-97da-2e40aac28beb, db collection `answers`). All 80 questions were
answered, with no notes. Rows marked **(not rec)** are where the user chose differently from the recommendation.

Sources for each question: `mp_armories_understanding.md` 8a, `mp_progression_understanding.md` 9(a),
`mp_gamemodes_understanding.md` 8(a), `compass_bar_design.md` 8(a), `koth_source_notes.md`.

Decided earlier the same day, in chat:
- Compass bar: replaces the ring, on by default, fades with the HUD (markers too), kill feed shifts under it, hidden
  when scoped or spectating, current objective only, metres.
- Build-A-Base is the base-building mode; Base Assault is in.
- The Field Settings redesign is approved with all 14 additions, plus the Host Rules sheet on Start Game.

Decided later the same day, in chat (user: "Yes to 2 and 3"):
- Security layer 2 goes ahead as recommended: the exe filters every server-origin line (not only vstr/exec
  expansions); a refuse-list for the settings the mod vstr's, instead of persisting taint; a real cgame API
  handshake (stamp cgi->apiversion, append new imports at the end, fall back to Cmd_Stuff on an old exe);
  menu-widget laundering through globalwidgetcommand stays a residual for now.
- Field Settings: the Compass row becomes "Modern Compass" (coop_compassBar): on = the top bar, off = the
  classic round compass.

Scheduling (user, 2026-09-13, evening): MP starts NOW, in parallel with the visual upgrades; the first MP slice is
the ARMORIES (Allied + Axis screens replacing the stock picker, with the Multiplayer Options side picker). Engine
pieces from both queues take turns in the shared openmohaa-hzm/.cmake build folder.

## Scope and isolation
| id | decision |
|---|---|
| S1 | MP may change game.dll, cgame.dll and openmohaa.exe, all MP-gated |
| S2 | **(not rec)** Script-less stock maps AND third-party MP maps are in scope now. This needs an engine hook, not per-map stubs |
| S3 | Leave `coop_weaponselect_suppress.urc` alone; MP gets its own file |
| S4 | mp.scr coop couplings: allowlist now, replace with MP-owned copies over time |
| S5 | Shared assets (sound aliases, shaders) are acceptable |
| S6 | Do not harden coop maps against operator bots for now |
| S7 | Approved coop changes: zero the bot cvars in start_server.cfg, restore g_realismmode 0, force frag/time/round limits to 0 at coop load |
| S8 | A homepath-root progress file written by new exe code is acceptable |

## Security and tamper
| id | decision |
|---|---|
| T1 | Deterrent-grade key in game.dll now; revisit later |
| T2 | Listen-server progress is tagged, accepted by default, and dedicated operators may refuse it |
| T3 | After a crash or leave, the unsaved tail is lost |
| T4 | A failed import verification discards that session's kills |
| T5 | Accept for now that a hostile server can erase progress; the engine-wide fix comes with security layer 2 |
| T6 | Progress backup export: yes, later |
| T7 | Two people on one Windows account: out of scope |

## Progression rules
| id | decision |
|---|---|
| P1 | One free starter per class per side: the stock class kit gun |
| P2 | Split HEAVY into MG, Shotgun and Rocket |
| P3 | **(not rec)** Scoped rifles (scoped Garand, scoped StG44, zoom rifles) count toward the base gun's class, not Sniper |
| P4 | Both a weapon-family counter and a per-variant counter |
| P5 | Kills with picked-up enemy weapons count |
| P6 | Melee kills do not count toward the held gun's class |
| P7 | Latch: unlocks stay unlocked after a retune; past kills stay in their ladder |
| P8 | Headshot = head, helmet and neck (engine group 0-2) |
| P9 | No accuracy or shots-fired challenges in v1 |
| P10 | No perk-like rewards in v1 |
| P11 | Shotguns on both sides, unlocked through Shotgun class kills |
| P12 | Add the stock kit items outside the roster (Gewehrgranate, mine detectors, Breda smoke, F1/RDG-1) where assets exist |
| P13 | Offline MP Service Record and pins: later |
| P14 | A kit that verifies late applies at next spawn |

## Armory content
| id | decision |
|---|---|
| A1 | Gewehr 98 gets its own tile |
| A2 | Drop coop's non-Allied bodies and the 24 prefix-failing skins from the MP Allied ring |
| A3 | Axis bodies: the 25 retail bodies for v1 |
| A4 | HRRTM stays mandatory; lifting more HRRTM geometry is fine |
| A5 | New Axis bodies are armory-only (not bots, not the stock model picker) |
| A6 | Glasses go only in the head slot for v1 |
| A7 | Japanese gaps (no grenade, no character skins) accepted for now |
| A8 | **(not rec)** Voice nationality must match the worn skin. This is engine work, in scope |

## Flow and bots
| id | decision |
|---|---|
| F1 | F7 and the Join Game ARMORY button open the MP armory for the current side |
| F2 | From the disconnected main menu, padlocks come from the carried record |
| F3 | A closed or idle armory auto-deploys the last kit after 25 s |
| F4 | Bots get random free-tier guns |
| F5 | Bots are dressed from the free tier |
| F6 | Per-map cap on bot-kill credit |

## Game modes
| id | decision |
|---|---|
| M1 | Supersede the "MP stays classic" record with per-feature host toggles; OFF means classic |
| M2 | No extra modes beyond the picks |
| M3 | Rifles, Snipers and Rifles+Snipers presets |
| M4 | Pistols and grenades stay available in weapon presets |
| M5 | Weapon presets are a modifier row on every mode |
| M6 | Build order: Gun Game, Rifles, KOTH, S&D, LMS, Demolition, CTF, Freeze Tag, Push, Build-A-Base, Base Assault |
| M7 | Gun Game final tier: pistol-whip / bash only |
| M8 | Gun Game: a melee kill demotes the victim a tier |
| M9 | Gun Game: FFA only for v1 |
| M10 | Gun Game kills give weighted (reduced) progression credit |
| M11 | Gun Game: bot kills advance tiers and bots can win |
| M12 | Freeze Tag on Team Match with a script round score (UBER recipe) |
| M13 | Freeze Tag: thawed players stay where they were frozen |
| M14 | Freeze Tag: bots thaw by proximity, plus an auto-thaw timeout |
| M15 | KOTH: moving hill, team presence, contested pauses, a point per second, first to limit; Imperative as a host option |
| M16 | S&D: stock objective bomb game, rounds with no respawn, objective maps |
| M17 | LMS: team elimination rounds with the last-man callout |
| M18 | CTF and Demolition built on Mefy's MIT libraries, credited |
| M19 | Push: the 7 converted SP maps first |
| M20 | Build-A-Base: 5 min build phase, 300 objects, delete only your own |
| M21 | Base Assault: original rules (3 bases per team, plant 15 s, defuse 10 s, fuse 60 s, respawns on, SP map list) |
| M22 | Scoreboard: stock columns plus announcements for v1 |
| M23 | Callvote: mode and toggle votes, hidden on coop servers |
| M24 | Coop defects found in the modes research: fix later, separately |

## Host settings and menu
| id | decision |
|---|---|
| H1 | Healing/Medkits covers the coop medkit system and stock health pickups |
| H2 | ADS off: right mouse works as stock; scoped rifles keep zoom |
| H3 | A Classic master switch plus individual realism toggles |
| H4 | DBNO and Medkits are shown greyed out until the MP port lands |
| H5 | Toggles latch per map |
| H6 | Cvar family `g_mp*` |
| H7 | Host settings remember the last used values |
| H8 | Select Game Type: shrink the buttons into a 3x6 grid |
| H9 | Ship mod copies of the six stock options screens, with a Host Rules button and no dead controls |

## Compass bar
| id | decision |
|---|---|
| C1 | Show a teammate's name when that teammate is near the centre |
| C2 | First v2 addition: downed-teammate markers |
| C3 | 150-degree arc, numbers every 15 degrees |
| C4 | Give positions to the 4 no-location objectives (t1l2 obj 2, t2l2 escort truck, t3l2 bridge, training towers) |
