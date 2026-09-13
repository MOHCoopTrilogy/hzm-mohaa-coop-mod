> Web hunt, 2026-09-13 (kings-push-hunt workflow, 19 agents). Pages and archived captures only - nothing was downloaded.

# Kings Push: search report

## 1. Bottom line

**We found the game mode but not King's original files.** Nothing we found uses the exact words "Kings Push". The link comes from the author credit, not the name.

- **Confidence the mode is identified: high.** In a 2014 forum post, the modder ViPER says the MOHAA "Push mod" was, he believes, made by **"LMAO King"**. It ran on **"King's LMAO server"**, his favourite Allied Assault server, which went offline around 2005. "Kings Push" most likely means King's push mod.
- **Confidence the original can be downloaded: low.** ViPER says he rebuilt the mode because he could not reach King. The files that survive are recreations:
  - ViPER's **Gain Ground** (2005).
  - OwN-3m-All's **Push / Gain Ground / King of the Map Mod** (2013). Its server file is `zZzZzZz_kingofmap_push.pk3`, which carries "king" and "push" in the name.
- Source: x-null.net thread 2128, "OwN3mAll's push mod", May 18 2014. It was read through Wayback: https://web.archive.org/web/20190724212134/https://www.x-null.net/forums/threads/2128-OwN3mAll-s-push-mod

## 2. What Kings Push was

| Fact | Source | Confidence |
|---|---|---|
| **Origin.** The push mod ran on "King's LMAO server" and ViPER believes "LMAO King" made it. The server went offline around 2005. OwN-3m-All replies that he remembers the server and that players liked it "back in 2004". | x-null thread 2128 (Wayback, above) | High that ViPER said this. The author credit is his belief, not proven. |
| **Original rules.** When your team pushes forward, your spawns move up and the enemy's move back. It was played on linear single-player maps converted for multiplayer. | Same thread | High |
| **Same server, other features.** King also ran a "Steal the Beer" mode, which ViPER later recreated. Another poster asks whether it was the server with a honking car on a bridge in map 4 that gave out beer. That detail might jog your memory. | Same thread; https://web.archive.org/web/20080513205113/http://viper.thewarlegends.com:80/mods.html | High |
| **ViPER's recreation.** "Push mod m1l2b" / Gain Ground: teams push the battle line to move their spawns forward. It works on m1l2b only. ViPER says he posted it on TMT (ModTheater) in late 2005, and it was on his site by May 2008. | viper.thewarlegends.com/mods.html (live, and 2008 capture); https://www.moh-db.com/mods/17077-gain-ground-mod | High |
| **OwN-3m-All's version.** Called "Fight / Push Your Way to Victory", or "Push / Gain Ground / King of the Map". It is Team Deathmatch only. A team's spawn moves forward when one player reaches the next checkpoint, and checkpoints are not marked. Allies head for the sparks (their score zone) and Axis for the smoke (theirs). It uses single-player maps converted to multiplayer. | https://own3mall.com/modules.php?name=Downloads&d_op=viewdownloaddetails&lid=11 (live, read with curl) and a 2019 Wayback capture | High |
| **Server setup.** Put `zZzZzZz_kingofmap_push.pk3` and `push.cfg` in MOHAAMain, then run `rcon exec push.cfg`. Debug cvars: `pushDebugSpawns`, `pushDebugTriggers`. | Same page | High |
| **Credits and dates.** Built on "code adapted from Viper's Gain Ground mod", with help from x-null.net. Released standalone 11/19/2013, and "Included in Ubermod Since V1". | https://www.moh-db.com/mods/17075-push-gain-ground-mod-20; https://web.archive.org/web/20150901195356/http://www.mohaaaa.co.uk:80/AAAAMOHAA/content/push-gain-ground-mod-20 | High |
| **Ubermod.** OwN-3m-All's all-in-one server pack lists "The Push Mod". It needs the Reborn 1.12 server patch. | https://www.moh-db.com/mods/11686-own-3m-all-s-ubermod-v2; own3mall lid=10 | High |
| **Game version.** Allied Assault only. Every source says MOHAA / MOHAAMain, and none mentions Spearhead or Breakthrough for the push mod. | All of the above | Medium. This is absence of evidence. |

**Where sources disagree:**
- **File size.** own3mall lists the standalone mod at **58.59 Kb**. The moh-db and mohaaaa copy, `own3mall_push_mod.zip`, is **257,309 bytes (251.28 KB)**. These may be different packages, and neither was opened.
- **Ubermod dates.**
  - own3mall's Ubermod entry is dated 2013-02-08.
  - The moh-db V2 entry is dated 2013-04-27, yet the push mod says it was "in Ubermod since V1".
  - One pass read V2's feature list as including "The Push Mod". Another pass says the moh-db API text for V2 does not name push.
  - Live version history: v4.0 on 6/22/2014, v5.0 on 8/15/2020.
- **Era mismatch.** If you remember playing in 2003–2005, you played **King's original**, not the 2013 files. The 2013 files are the closest surviving relatives.

## 3. Where the files might still exist

**Nothing was downloaded.** These are listed download locations only, and it's your call whether to fetch any of them.

| What | File (as listed) | Size (as listed) | Where / status |
|---|---|---|---|
| OwN-3m-All push mod, standalone | not named; contains `zZzZzZz_kingofmap_push.pk3` + `push.cfg` | 58.59 Kb | own3mall.com lid=11 details page, **live** (HTTP 200 on 2026-09-13). The download is a form that may ask you to type a passcode, so it needs a person in a browser. |
| Same mod, mirror | `own3mall_push_mod.zip` | 251.28 KB (257,309 bytes) | https://www.moh-db.com/mods/17075-push-gain-ground-mod-20 → https://api.moh-db.com/api/v1/downloads/mods/14698 (storage: https://storage.moh-db.com/modfiles/own3mall_push_mod.zip). Listed live. **Best single candidate.** |
| Same zip, older mirror | `own3mall_push_mod.zip` | not listed | mohaaaa.co.uk (pubdlcnt nid=14698). The live site is behind a bot wall, and Wayback has only the HTML page, not the file. |
| ViPER's Gain Ground ("Push mod m1l2b") | `zzzzz-Gain_Ground_mod.pk3` | 5 KB (5,374 bytes) | http://www.thewarlegends.com/6001136/incoming/twldownloads/viper/mods/zzzzz-Gain_Ground_mod.pk3, linked from the live viper.thewarlegends.com/mods.html. Also on moh-db: https://api.moh-db.com/api/v1/downloads/mods/14701 |
| Ubermod (bundles push) | not named (own3mall v5.0) | 11.00 Mb | own3mall.com lid=10, live, passcode form. Needs Reborn 1.12. |
| Ubermod V2 | `Ubermod_Public_Release_V2.zip` | 10.07 MB (10,559,457 bytes) | https://api.moh-db.com/api/v1/downloads/mods/8555 |
| Steal the Beer (King's other mode, recreated by ViPER) | `zzzzz-stealthebeer.pk3` | 7 KB (7,242 bytes) | thewarlegends.com (same folder as Gain Ground); mohaaaa nid=14694 |

**Useful archived pages** (all opened with curl through Wayback):
- own3mall listing (2016): https://web.archive.org/web/20160324103403/http://own3mall.com/modules.php?name=Downloads&cid=3&orderby=dateD
- own3mall lid=11 details page (2019): https://web.archive.org/web/20190701223810/http://own3mall.com/modules.php?name=Downloads&d_op=viewdownloaddetails&lid=11&ttitle=Fight_/_Push_Your_Way_to_Victory_Mod
- mohaaaa "Gain Ground Mod" (2015): https://web.archive.org/web/20150901195711/http://www.mohaaaa.co.uk:80/AAAAMOHAA/content/gain-ground-mod
- x-null Ubermod thread 1634: https://web.archive.org/web/20190717185102/https://www.x-null.net/forums/threads/1634-OwN-3m-All-s-Ubermod-All-In-One-MOHAA-Mod-Server-Mod-Admin-Menu-Configs-amp-Editor

**Wayback CDX has no copy** of any of the actual push, Gain Ground or beer files.

**Probably not it, listed only to rule out:**
- ViPER's Strategic Hold V50: a King-of-the-Hill "hold" mode covering AA, SH and BT. `zzzzz-ViPERS_Team_Hold_Mods_v5.zip`, 165.49 KB.
- ViPER's King of the Hill maps: `zz-vipers_KOH.pk3` and `zz-vipers_KOH_SH.pk3`, about 339 KB each.
- `gametypekoth1.0.zip` (Klownterfit, 2003), 12.46 KB.
- The maps `push_cityhall.pk3` and `SHPush.pk3`.

## 4. Where we looked and found nothing

- **The exact name.** "Kings Push", "King's Push", KingsPush, Kingpush, King-Push, Kingz Push and kings_push, combined with MOHAA, Spearhead, Breakthrough, pk3, clan or server, got no Medal of Honor hits at all. Results were Pusha T, Honor of Kings, and real Medal of Honor recipients named King. We also tried Polish, Russian, German and French searches.
- **archive.org.** Metadata search for "kings push" returned 0 results. Full-text search for kingspush returned 0. Full-text hits for "kings push" and "king's push" were all unrelated. The FilePlanet archive collection has no MOHAA item with king or push in the name.
- **Mod databases.** Every moh-db.com search, plus its full 1,676-entry catalogue and all 57 gametype mods: no "Kings Push" and no "kingofmap". GameBanana returned 0. ModDB, GameFront, Nexus and mefy.moh-central.net returned 403.
- **Servers.** GameTracker returned 403. game-state.com and gs4u.net list no current server named king, kings or push. mohaaservers.tk no longer resolves.
- **GitHub.** OpenMOHAA issues; the own3mall account (85 repos); inequation/MoHAAMods; the mohaa-moddb org (30 repos); searingwolfe UBER-MODS. No push mod in any of them.
- **Communities.** MOHAA Reunited, MOH-France, the GOG servers thread, Reddit, Steam, Xfire, YouTube and ClanBase found nothing. Wayback has no captures of kingofmap.* or kingspush.* domains, and no x-null or mohaaaa URL containing "lmao".
- **Blocked or partial.**
  - Live x-null.net and mohaaaa.co.uk sit behind an Anubis bot wall, so we read them only through Wayback.
  - A scan of ModTheater thread URLs found nothing, but those URLs are mostly numbers, so it proves little.
  - **The web-search budget ran out before anyone searched "LMAO King", "King's LMAO server" or "LMAO clan".** That is the biggest gap.
  - ViPER's late-2005 TMT post was not found.

## 5. Next steps and how hard it would be to rebuild

**Where to look or ask next**
1. **Search "LMAO King", "King's LMAO server" and "LMAO clan" MOHAA.** None of these ever ran.
2. **x-null.net thread 2128**, opened in a normal browser. It has a reply form, so you could post a question there. ViPER, OwN-3m-All and Midnight1138 all remembered King's server. The thread also links a YouTube video, LjRCvyqaWhA, whose title we never saw.
3. **Contact OwN-3m-All** through GitHub (`own3mall`), forums.own3mall.com or dev.x-null.net/own3mall. Contact **ViPER** through thewarlegends.com (he posted on ModTheater as twl_viper).
4. **ModTheater captures on Wayback.** Look through twl_viper's posts from late 2005 for the original push thread.
5. **Community channels.** The OpenMOHAA and x-null/Reborn communities, and the MOH-DB and MOHAA Reunited maintainers. The HaVoK clan still runs a KoTH server and may know the old mods. Ask for "King's LMAO server", "LMAO King" or "the push mod from 2004".

**Rebuilding it in this mod: moderate effort, scripts only, no engine change.**
- **Why it fits.**
  - The mode was played on linear single-player maps converted to multiplayer, and running SP maps in MP is exactly what this project already does.
  - It is TDM-based, and the mod already runs `g_gametype 2`, has the spawn-location machinery (`spawnlocations.scr`, `coop_respawnOrigin`) and has a separate multiplayer script layer.
- **What it needs.**
  - An ordered checkpoint list for each map (origin and radius), and a checkpoint index for each team.
  - Polling or trigger checks that move a team's spawn forward and the enemy's back when a player reaches the next checkpoint.
  - End score zones marked with sparks for Allies and smoke for Axis.
  - A scoring or round rule, and the AI coop layer switched off while push is active.
- **The real cost.**
  - Placing checkpoints and two spawn sets per checkpoint on every map is the bulk of the work.
  - The original scoring and win rules have to be guessed, because King's version is lost.
- **Fastest route.** If you approve downloading `own3mall_push_mod.zip` (251 KB), we can read its scripts and port that working recipe, crediting OwN-3m-All and ViPER. It was written for Reborn 1.12, so any Reborn-only script commands would need checking against OpenMOHAA.
