> Generated 2026-09-13 by the mp-progression-understand workflow (28 agents: 7 readers, 7 adversarial verifiers, a critic, gap readers + verifiers, synthesis). Research only; it designs nothing. It follows the user's MP progression decisions recorded at the top of mp_loadout_plan_v1.md. The synthesis agent was cut off inside section 9 and then re-emitted sections 2.2(8)-10 in a shorter form; this file keeps the full first pass for sections 1-8 and takes the complete sections 9 and 10 from the second.

# MP-only Progression: Verified Understanding Map

Research synthesis, 2026-09-13. Nothing described here has been built, and no repository file was changed. The sources are seven subsystem reports and six gap reports. Where a second reader refuted or partly corrected a claim, the corrected version is the one stated here.

**How to read this document**

- **Paths.** Engine paths are relative to `openmohaa-hzm/code/`. Mod paths are relative to `hzm-mohaa-coop-mod/`. `docs/`, `.wolf/`, `installer/`, `build.ps1` and `publish_release.ps1` are relative to the repo root. Pak references look like `maintt/pak1.pk3 <inner path>` and live under the GOG install.
- **Verdict tags:**
  - [C]: confirmed by a second, independent reader.
  - [P]: partly confirmed. The text states the corrected version.
  - [R]: refuted. The text states the correction.
  - [NV]: one reader's code finding, not re-read by anyone else.
  - [M]: measured by a scratch script, a live file, a hash or a binary grep. Not observed in-game.
  - [S]: supporting fact, not load-bearing, as reported.
- **LB** marks a load-bearing fact: a design decision changes if it is wrong. **LB/NV** means load-bearing and unverified. Treat it as a hypothesis until its test in section 9(b) has run.
- **Runtime evidence.** No MP progression behaviour in this document has been seen in-game. The mod has never executed `event_subscribe` or `registerev`, never spawned an engine bot, and never completed a `coopprof` round trip.

---

## 1. Executive summary

### 1.1 What the decisions require

| Decision | Technical requirement it creates |
|---|---|
| A: MP unlocks all gear | An MP-owned unlock table and two MP armories. The table covers:<br>- 74 roster guns (docs/tools/loadout_weapons.tsv:16-89) [NV]<br>- weapon finishes and model variants. coop_skinGive has 427 entries: 350 finishes (fid 1-7) plus 77 model variants (fid 8-18) (coop_mod/loadoutskins.scr) [C]<br>- character skins, headgear and glasses, and gloves for each side |
| B: start over | MP never reads coop save files, coop session cvars, coop player flags or coop unlock strings (list in section 7.6). The first MP record is empty. |
| C: class and weapon ladders, challenge gear | On every valid kill, the server attributes the kill to a class token (ignoring team) and to an exact weapon source. Challenge counters drive character gear. |
| D: players carry their own progress, server-verified | Four things are needed: a portable identity, a client store that survives normal client life, a carrier in each direction, and a signing primitive. None exists in usable form today (sections 2 and 3). |
| E: bot kills count | A human killing a bot earns credit. A farming policy is needed (section 8). |
| F: never impact coop | MP needs its own files, verbs, cvar prefixes, events, save stores and HUD slots. Engine hooks must do nothing unless an MP script subscribes. Coop also runs g_gametype 2, so gametype cannot be the C++ gate. check_mp_isolation.py must be extended (section 7.6). |
| G: standing rules | One primary weapon. Health 100. Shotgun id 44 appears as a tile on both armories; today the roster split puts it on the Allied side only. Allies are US/UK/USSR. Axis is German, Italian and Japanese. |

### 1.2 What exists to build on

| Building block | State | Evidence |
|---|---|---|
| `player_killed` script delegate, 11 args, self = victim | Exists. Never used by the mod. | fgame/player.cpp:66, :3639-3653 [C] |
| `event_subscribe` (many subscribers per event) | Exists. Never executed in this mod. | fgame/scriptthread.cpp:1688-1696, :7160-7176 [P]; coop_mod/mp.scr:98-103 has only a comment [S] |
| `isBot <ent>` | Exists, and is present in the deployed DLL. | fgame/scriptthread.cpp:2066-2074, :7364-7381 [C]; G:/mohaa-gl2/game.dll contains "isBot" [M] |
| `attacker getactiveweap 0`, then `.model` (lowercase canonical tik path) | Exists. | fgame/sentient.cpp:631-639; fgame/entity.h:744-762; qcommon/files.cpp:4346-4383 [C] |
| `coopprof` EV_CONSOLE reassembly, up to 8192 bytes | In the deployed game.dll. Owned by the coop profile mirror. The round trip has never been proven. | fgame/player.cpp:328-336, :1997, :7542-7567 [C]; coop_mod/profile.scr:9-25 [NV]; "coop_profdata" found in G:/mohaa-gl2/game.dll [M] |
| Script can read a player's userinfo (getter form) | Exists. Not tested at runtime. | fgame/player.cpp:1842-1850, :2166, :19444-19452; fgame/scriptthread.cpp:1374-1382 [C]; precedent coop_mod/challenges.scr:3500-3510 |
| HZM cgame filter lets a server set or seta any coop_*, vstr coop_*, and exec under ui/loadout/, ui/coop_ or coop_mod/ | Exists. It is also a hole (section 3.3). | cgame/cg_servercmds_filter.cpp:173-175, :315-363 [C] |
| Portable identity MD5(qkey) | Exists only because autoexec forces cl_guidServerUniq 0. The client asserts it and nothing verifies it. | autoexec.cfg:1347-1349; client/cl_main.cpp:1037-1051, :1459-1462 [P]; hash match against live saves [M] |
| Server file I/O fs_read_content / fs_write_content | Exists. Writes to the server disk by truncating, then writing. | fgame/scriptthread.cpp:2075-2112, :7400-7405; qcommon/files.cpp:2068-2091 [NV] |
| md5string | Registered but broken on x64. Not usable as a MAC. | fgame/md5.h:65 [C]; scratch harness [M] |
| Correct MD5 code, and vendored RSA/SHA1 (GameSpy SDK) | Both are in the exe build, not game.dll. Both can be compiled into game.dll. | qcommon/md5.c:51-216 [P]; gamespy/common/gsCrypt.h:31-82 [R] |
| Roster TSV (id, give, tab) and generated skin tables | Exist. MP may not call the coop labels that use them. | docs/tools/loadout_weapons.tsv; coop_mod/loadoutskins.scr:1-5 [C] |
| Challenge row shape, generators and audits | Exist, with coop names hard-coded as literals. | coop_mod/challenges.scr:732-752 [NV]; docs/tools/gen_service_record.py [NV] |
| Isolation gate | Exists. Its clause 10 scans only mp.scr. | docs/tools/check_mp_isolation.py:282-294 [C] |

### 1.3 The three biggest risks

**1. No player-vs-player kill reaches the hook today (LB).**

- Sentient::ArmorDamage subtracts health only when the attacker is NULL, is the victim, is not a Sentient, or has a different m_Team (fgame/sentient.cpp:1798-1801) [P].
- HZM baseline commit eaac51be removed upstream's `g_gametype != GT_SINGLE_PLAYER` exemption (upstream d5da32b8 sentient.cpp:1513) [P].
- Every Player is TEAM_AMERICAN. The constructor sets it (sentient.cpp:958). `models/player/base/include.txt:18` (`american`, in main Pak0.pk3 and maintt pak1.pk3) sets the same value, and no player tik contains `german` [P].
- Result: PvP damage is silently dropped. This is not proven at runtime; the only MP session in the live log (mohdm7, 2026-09-13) has no kills [M].
- The engine fix must do nothing in coop. Coop runs g_gametype 2, so a gametype gate is not coop-safe.

**2. No trustworthy client-held store and no working signing primitive (LB).**

- md5string gives non-standard, non-deterministic output on x64 (fgame/md5.h:65 [C]; scratch harness [M]).
- Any server can overwrite any coop_* client cvar. It can also run arbitrary client commands in two ways: `seta coop_x <cmd>` then `vstr coop_x`, or a whitelisted cfg trampoline (cg_servercmds_filter.cpp:173, :350-363 [C]; ui/loadout/t01.cfg:2-3 [NV]).
- That hole cannot be closed inside cgame without breaking the coop armory (coop_mod/loadoutpick.scr:350-621) [NV].
- A compiled-in key reaches every player's disk (publish_release.ps1:78; manifests/manifest-1.5.3.json:19-22) [C].
- Listen hosts and bot farms produce progress that signs correctly.
- Realistic tamper resistance is therefore casual. It stops config edits, typed commands, and records copied between guids, and nothing more unless a trusted-issuer tier is added.

**3. State lifetime, and MP code already coupled to coop (LB).**

- **Round restart wipes.** Every round restart (gametypes 3-6) deletes every Player, clears level, parm and game vars, and wipes every delegate subscription (fgame/level.cpp:898-950; fgame/scriptmaster.cpp:784) [C].
- **Map changes discard writes.** A map change sends a gamestate, which silently discards server commands not yet executed (server/sv_client.c:821-830; client/cl_parse.cpp:546-554) [C].
- **No match-end signal.** FFA and TDM give script no match-end event; SE_INTERMISSION has no Trigger site [C].
- **Coop code already runs in MP:**
  - mp.scr sets g_statefile coop_mod/player, so every MP death runs coop events.scr and then player.scr::manageDead (mp.scr:77-82; player_Torso.st:3230) [NV].
  - mp.scr calls player.scr::playerCleanName and ::coop_limpWarn, main.scr::containsText, and the ads/painbreath/tinnitus monitors (mp.scr:238-244, :267-268, :276) [P].
  - MP spawns wear the coop skin carried in dm_playermodel (fgame/player.cpp:2815-2871; coop_mod/helmet.scr:1393) [NV].
  - Clause 10 of the isolation gate scans only mp.scr [C].

**Binaries implied.**

- **game.dll:** needed by every design (PvP filter, MP event, signing builtins).
- **cgame.dll:** needed by every design that keeps the record outside coop_* or writes it back without stufftext. The MP armory already requires the HZM cgame (_research/mp_loadout_plan_v1.md:92) [NV].
- **openmohaa.exe:** needed only for a homepath-root file store, for closing the trampoline class, or if userinfo keys are registered in the exe rather than cgame.
- **Stock OpenMOHAA clients** carry nothing in any design. The upstream filter at commit ea8ee677 (line 152) drops `seta coop_*`, vstr and exec [NV LB].

---

## 2. Carry-your-own-progress

### 2.1 Identity

**How cl_guid is formed.**

- cl_guid is the MD5 of the 2048-byte qkey file at the homepath root. It is salted with the server address only when cl_guidServerUniq is 1 (client/cl_main.cpp:1037-1051, :1459-1462; qcommon/md5.c:289-290) [P].
- The engine default is 1 (cl_main.cpp:4264), and so is the installer default config (installer/omconfig_default.cfg:363).
- autoexec.cfg:1347-1349 forces `seta cl_guidServerUniq 0`, and it runs after the saved config (qcommon/common.c:1848, then :1862) [NV LB]. This corrects the persistence report, which assumed a per-server guid.
- Empirical check [M]:
  - MD5(G:/mohaa-gl2/home/qkey) = 2496560D4E89BD4C91B8D00DC239BEB3, which is the host id in that install's coop_mod/save.
  - MD5(%APPDATA%/openmohaa/qkey) = 609F287B3808BAD639F214D3732FCB5D, the only id in that homepath's save directory.

**Trust.** The client asserts the guid.

- CVAR_USERINFO|CVAR_ROM (cl_main.cpp:4354) blocks only the console.
- The only reference outside client/ is the HZM push to self.coop_guid (fgame/g_client.cpp:817-818) [P].
- A copied qkey clones the identity.
- The player can set cl_guidServerUniq back to 1, and so can a hostile server through the vstr trampoline.

**Fragility.**

- A missing qkey, or one of the wrong size, is regenerated silently (cl_main.cpp:3640-3663) [NV LB]. That gives a new guid, and every record bound to the old guid fails.
- The guid is not broadcast to other clients (g_client.cpp:1054-1073) [S].

**No online authority.**

- USE_CURL is absent from the exe's PreprocessorDefinitions (.cmake/openmohaa.vcxproj; client/cl_curl.c:23).
- GameSpy auth lets the client in after a 5 s timeout and hands game.dll no verified id (gamespy/sv_gamespy.c:346, :474-492) [NV].

**Bots and fallbacks.**

- Bots have no cl_guid. coop_guid is NIL until the bot's first death, then "" (fgame/g_bot.cpp:468-470; g_client.cpp:801, :816-818; fgame/playerbot.cpp:1257-1260) [NV].
- Coop's fallback id "n_"+netname is spoofable, and it would give bots save files (coop_mod/xp.scr:350-358; challenges.scr:806-807) [S]. MP must not use it.

**Timing.**

- After a restart, coop_guid is published again when the new Player spawns (Player::InitClient -> G_ClientUserinfoChanged, fgame/player.cpp:2709-2724).
- It is not published at reconnect: the push sits inside `if (ent->entity)` at g_client.cpp:801-819 [P].

### 2.2 Channel matrix

Short verdicts only; the details and citations follow the table.

| # | Channel | Direction | Verdict |
|---|---|---|---|
| 1 | stufftext `seta coop_<name> <value>` | S->C | Usable; any server can overwrite it |
| 2 | stufftext `vstr coop_<name>` holding an unknown command | S triggers C->S | Probe route; it is also the arbitrary-command primitive |
| 3 | stufftext `coopprof ...` directly | S->C | Dead |
| 4 | EV_CONSOLE event sent by client code (coopprof today, an MP event later) | C->S | Record-body upload only |
| 5 | Userinfo key registered in engine or cgame (USERINFO+ARCHIVE) | C->S, automatic | Best small-value C->S channel |
| 6 | `setu` user-created userinfo key | C->S | Dead |
| 7 | Name bus | C->S | Reject |
| 8 | omconfig.cfg archive, written via seta | client disk | Lossy store (2.8) |
| 9 | New server command handled inside CG_ServerCommand | S->C | Needs cgame.dll; merge monotonically |
| 10 | cgame file via cgi.FS_WriteFile | client disk (gamedir) | Needs cgame.dll |
| 11 | New exe file at homepath root (FS_SV_* location, next to qkey) | client disk | Needs openmohaa.exe |
| 12 | Server file via fs_write_content | server disk | Ledger only |
| 13 | Server cvar (setcvar/getcvar) | server memory | Pending ledger |
| 14 | Chat plus player_textMessage filter | C->S | Reject |

**Channel details.**

1. **Archived coop_* cvar (S->C).**
   - Limits: the value persists only if len(name)+len(value)+10 <= 1024 (cvar.c:1250-1262) [C]. The formatted stufftext must stay under 2047 bytes (sv_main.c:243-245) [P].
   - Remote client on a dedicated server: works with the HZM cgame (filter :173) [C]. Stock client: dropped.
   - Script sees nothing; the channel is write-only.
   - Restart keeps the command queue. A gamestate discards unexecuted commands.

2. **vstr trampoline (server triggers a client-to-server send).**
   - Limits: 255 bytes per argument for remote clients (cmd.c:626-642) [P]. The whole line is capped near 2046 (cl_main.cpp:242-253) [P].
   - Remote/dedicated: works by code reading, never tested [NV LB]. Stock client: dropped.
   - Script sees whatever event the command names. The server side needs a live Player.

3. **Direct `coopprof` stufftext.** The filter drops it: no coop_ prefix, not whitelisted, not user-created (filter :236-271) [C]. The only probe returned NIL (profile.scr:57-58).

4. **EV_CONSOLE event sent by client code.**
   - Limits: 255 bytes per argument for remote clients; an 8192-byte buffer. A chunk that would overflow is dropped whole. idx<=0 resets the buffer, and there are no order or gap checks (player.cpp:7554-7566) [C].
   - Needs a Player entity, CS_ACTIVE or PRIMED, and clientOK. Silently dropped under flood protection (sv_client.c:1734-1748, :1789-1799) [C].
   - A player can type it, but a stock client cannot be told to send it.
   - Script sees `self.coop_profdata`. The buffer is a Player member, so it dies at every restart and map change [C].

5. **Registered userinfo key.**
   - Limit: the whole userinfo is 1350 bytes; an estimated 793-953 bytes are free [NV].
   - It is a server ucmd: no 255-byte cap, and exempt from flood protection, though it re-arms the flood timer (sv_client.c:1686-1687, :1717-1723) [C].
   - Script reads it with `info_valueforkey local.player.userinfo "key"` [C by code; runtime untested]. A stock client never has the key.
   - cl->userinfo survives both restart and map change, and is re-applied at every spawn (player.cpp:2709-2724) [P].
   - Needs registration in the exe or in cgame.

6. **`setu` user-created key.** Cvar_Unset runs on it at every gamestate and removes it from the saved config (cl_main.cpp:897-907, :1027; cvar.c:1436-1441) [P].

7. **Name bus.** 31 characters, about 23 of them data. One token per ~0.75 s at sv_fps 20 (player.scr:185-187; variables.scr:21) [P]. Every change is visible to all clients (g_client.cpp:768-799). A stock client works only if the user types the name.

8. **omconfig.cfg archive.** Lines are capped at 1024 bytes each. The whole file is rewritten, truncate-then-write, in any frame where an archived cvar changed (common.c:2087-2142, :2283-2286; files.cpp:1055) [NV LB]. There is one config per gamedir.

9. **Server command handled inside CG_ServerCommand.** Each command must be under 2048 bytes. Console, vstr and exec expansions cannot reach it: they go through CG_ConsoleCommand (cg_servercmds.c:386-530 vs cl_cgame.cpp:1003-1008) [NV]. Any server can still send it, and stock clients ignore it. Restart keeps the queue; a gamestate discards pending commands.

10. **cgame file.** Written truncate-then-write. A trampolined `writeconfig <path>.dat` can clobber it (common.c:2158-2169; q_shared.c:276-295; files.cpp:697-708) [NV]. One file per gamedir.

11. **exe file at homepath root.** Needs new atomic-write code; the engine has no MoveFileEx or ReplaceFile [NV]. Target game, cvar_restart and the installer do not touch it.

12. **Server file.** Truncate-then-write (files.cpp:2068-2091) [NV]. Visible to the server only, and not portable.

13. **Server cvar.** getcvar strips trailing '0's, and then a trailing '.', from any value that contains '.' (scriptthread.cpp:2630-2641) [P]. It survives restart and map change, but dies with the server process (precedent challenges.scr:815-828) [P].

14. **Chat filter.** Needs the unverified event_subscribe, and it pollutes chat (player.cpp:12831-12835) [S].

### 2.3 Hard limits

**Sizes.**
- MAX_STRING_CHARS is 2048, MAX_INFO_STRING 1350, MAX_CVAR_VALUE_STRING 256, MAX_CVARS 8192, MAX_RELIABLE_COMMANDS 1024, MAX_NAME_LENGTH 32 (q_shared.h:297-307, :318, :1357; cvar.c:44; qcommon.h:215). Later readers re-confirmed 1024, 1350 and 2048.

**Reliable command queues.**
- The server drops a client at 1,025 unacked commands with "Server command overflow" (sv_main.c:196-209) [P]. The client side fails with ERR_DROP "Client command overflow" (cl_main.cpp:247-249) [S].
- Unacked commands are re-sent in every snapshot, so a burst inflates snapshots (bug-1670) [NV].
- Commands to a client below CS_PRIMED are discarded, not queued (sv_main.c:187-189) [P].

**Flood protection.**
- The gate applies only on a dedicated server (!com_cl_running), with the client CS_ACTIVE and sv_floodProtect nonzero.
- A game command that arrives within 1000 ms of ANY previous client command, userinfo included, never reaches the game and is never retransmitted (sv_client.c:1789-1799, :1809) [C].
- The engine default is 0 (sv_init.c:1114). The mod's own net_sv.cfg:16 and coop_mod/cfg/dedicated_example.cfg:33 set it to 1 [C]. The cvar comment saying only dmmessage is gated (sv_init.c:1111-1113) is wrong [C].

**The listen host is not a valid test client.**
- The host's own commands go to G_ConsoleCommand before any forwarding, so they skip the 255-byte cap and flood protection (cmd.c:1052-1064; sv_game.c:1962-1967) [C].
- Every remote-client limit must be verified on a dedicated server.

**Encoding.**
- On the server read, '%' becomes '.' (msg.cpp:700-702, :784-786) [NV].

**Cvar table.**
- Running out is ERR_FATAL "Too many cvars" (cvar.c:512-517). A one-shot warning fires once the high-water index passes 6553 (cvar.c:529-536) [C].
- It has crashed the user before (bug-1582) [C].
- The live client config (G:/mohaa-gl2/home/maintt/configs/omconfig.cfg): 123,674 bytes, 4,659 lines, 4,565 seta, 3,951 `seta coop_` [M].

**Userinfo overflow is silent and depends on order.**
- The newest cvars are iterated first (cvar.c:551-557, :1557-1577).
- A pair that would reach 1350 is skipped (q_shared.c:1973-1977).
- Connect keys (protocol, qport, challenge) are appended after the cvars (cl_main.cpp:2176-2195). A nearly full userinfo loses protocol, and the server refuses the connection (sv_client.c:410-423).
- When the server adds ip and overflows, it drops the client (sv_client.c:442-454, :1621-1631) [NV LB].

### 2.4 Character set

**Characters each layer refuses or mangles.**

| Layer | Problem characters | Evidence |
|---|---|---|
| Any cvar value | backslash, double quote, ';' refuse the set | cvar.c:81-96, :616-625 [NV] |
| Userinfo pair | backslash, ';', double quote refuse the pair | q_shared.c:1952-1965 [C] |
| Stufftext | '"' ends the argument (player.cpp:12381; bug-758); ';' and newline split statements; '//' and '/*' start comments outside quotes; runs of whitespace collapse | cmd.c:194-252, :656-757; cvar.c:975 [NV] |
| Console event arguments | a space splits (only arg 2 is read); '%' becomes '.'; CR/LF become spaces; over 255 bytes truncates | cmd.c:634-640 [P] |

**Candidate alphabets.**

| Alphabet | Density | Caveat |
|---|---|---|
| [A-Za-z0-9-_] | 6 bits/char | Needs case-sensitive string compares and dictionary keys. Code reading says they are (scriptvariable.cpp:2027-2062; con_set.cpp:33-43) [NV LB]. |
| Lowercase [0-9a-z.~-] | base36 | Case-proof. If '.' is used, a copy held in a server cvar must never end in '0'. |

### 2.5 Capacity math

**Shape A: counters only, unlocks derived** (persistence report; 64-symbol alphabet; fixed width).

| Part | Characters |
|---|---|
| Header: version 1 + profile id 16 + seq 4 + length 3 + MAC 32 hex | 56 |
| 7 class counters x 4 | 28 |
| 80 weapon counters x 3 (x 4) | 240 (320) |
| 400 challenge completion bits | 67 |
| Core | 391 (571 with 4-char weapon counters plus 600 unlock bits) |
| Plus sparse in-progress counters for 50 challenges | ~821 |
| Plus dense 400 x 3 | ~1,771 |

**Shape B: tagged sections with latched unlock tokens** (record-unit scratch encoder, lowercase base36) [M].

- Sections:
  - v: format version
  - g: registry generation
  - k: key id
  - c: 8 class counters
  - w: 84 sources (74 roster + 10 reserved)
  - u: all 690 unlock tokens (74 guns + 427 finishes/variants + 47 headgear + 135 skins + 7 gloves)
  - x: 120 challenge counters
  - s: signature
- Worst case is 4,983 bytes, of which 3,298 are tokens. That is 20 chunks at 250 bytes.
- A typical mid-life player is about 1,063 bytes (5 chunks).
- Latched unlocks plus challenge-done flags as a hex bitmap over 810 positions come to about 203 characters. This is safe only behind an enforced append-only id registry (docs/TRAPS.md:418-420).

**What fits where.**
- **One userinfo key.** Shape A core (391-571) fits the ~793 worst-case free space with 210-390 to spare. The 821-character form does not fit the worst case, and Shape B never fits.
- **Console event chunks at 255 bytes.** 391 -> 2 chunks, 571 -> 3, 821 -> 4, 1,771 -> 7, 4,983 -> 20. The ceiling is 32 (8192 bytes). At 1.1 s pacing the upload takes about 2 to 22 s.
- **Server write-back as stufftext.** About 280 bytes on the wire each, 2 to 20 per save. Each persisted chunk is far below the 1014-minus-name archive cap.
- **Comparison with coop.** The largest live coop unlocks_<id>.dat is 5,781 bytes and chal_<id>.dat is 4,375 (G:/mohaa-gl2/home/maintt/coop_mod/save) [M]. Coop-style strings would overflow userinfo and approach the 8192 cap.

### 2.6 Transport the constraints favour, and how to split it

This split is what the verified constraints favour if new client binaries are acceptable. Section 10 compares alternatives, including a design that needs no new client binary, and does not pick one.

| Payload | Direction | Carrier | Why |
|---|---|---|---|
| Ack: sequence number plus digest ("I hold record N") | C->S | CVAR_USERINFO+ARCHIVE key registered in the engine or cgame (precedent: coop_pin1..5 at client/cl_main.cpp:4183-4187) | The only C->S channel that survives restart, map change and flood protection, and needs no Player entity [C/P] |
| Armory picks (the wanted kit) | C->S | Registered userinfo kit keys, re-applied at every spawn | It is state rather than events; it exists before the first spawn; it is exempt from flood protection [C/P] |
| Record body import | C->S | MP-only EV_CONSOLE event, never coopprof. Chunks of 250 bytes or less; chunk 0 carries magic, version, length, chunk count and MAC. Paced at 1.1 s or more when getcvar sv_floodProtect is nonzero. Sent by client code (cgi.SendClientCommand, cgame/cg_public.h:169), not by stufftext. Once per server session per guid. | 8192-byte cap. The buffer dies at each restart, so the verified import is cached in server cvars. |
| Record write-back | S->C | A dedicated server command (gi.SendServerCommand), handled inside CG_ServerCommand and never cgi.AddCommand. cgame merges by taking the larger value of each counter. | Console and trampoline expansions cannot reach it. Any server can still send it, so the monotonic merge is mandatory [NV]. |
| Durable client store | client disk | A dedicated file at the homepath root next to qkey, written atomically by exe code (2.8). In lower-binary designs, a cgame-owned store. | The only place immune to the installer, cvar_restart and target-game switches [NV] |
| Pending credit | server | Per-guid server cvars holding absolute totals since the last echoed sequence | Survives restart and map change [P] |
| Anti-rollback | server | Per-guid high-water ledger file with MP-only names, written with a .bak | Restores progress on servers already visited [NV] |

**Rules that apply whichever store is chosen.**

- **Commit order.** Send the payload writes first and the ack write last, in the same reliable stream. Commands execute in order (cg_servercmds.c:544-560), so an echoed sequence number proves the whole batch executed [C].
- **Absolute values.** Write absolute values, never deltas.
- **Commit means echoed.** "Committed" means echoed back by the client, never "sent" or engine-acked. The engine ack (reliableAcknowledge) means received, not executed. It advances even over commands a gamestate discarded, and script cannot see it (cl_input.cpp:1203; sv_client.c:2104-2116) [C].
- **Naming.** coopprof, coop_profdata and coop_pf* belong to the coop profile mirror (profile.scr:9-25) [NV]. These prefixes have zero hits and are free: coop_mpq, coop_mpr, coop_mpU, coop_mpprof, coop_mprec. coop_mpP is taken [S].
- **Pacing.** Pace write-back bursts like chal_ui_export: 24 commands per 0.25 s (challenges.scr:1005-1035) [NV]. Never export on join (bug-670; challenges.scr:881-893) [NV].
- **Zero-binary probe route.** `seta coop_mpq<i> <verb> <i> <chunk>` then `vstr coop_mpq<i>`. Use it only to probe the channel (architecture 1 in section 10).

### 2.7 Delivery and lifetime across transitions

| Transition | Gamestate sent? | Server command queue | Script state | Delegates |
|---|---|---|---|---|
| Round `restart` (FinishRoundTransition, dm_manager.cpp:1499; G_ExitLevel to the same map, g_main.cpp:2102-2104; vote restart) | No | Kept. cgame survives and queued commands still execute (sv_ccmds.c:318-336; sv_init.c:984-1014; cg_snapshot.c:215-226) [C/P] | All entities deleted; level, parm and game vars cleared (level.cpp:898-950) [C] | Reset (scriptmaster.cpp:784) [C] |
| `map` (including the same map), `gamemap`, `reloadmap`, vote map/nextmap, G_ExitLevel to a different map | Yes (sv_ccmds.c:269, :309, :1876) [C] | Unacked commands ride inside the gamestate and are then discarded by CL_ClearState. The new cgame starts from the gamestate sequence (sv_client.c:821-830; cl_parse.cpp:546-554; cl_cgame.cpp:963-973) [C] | Wiped | Reset |
| Intermission: FFA/TDM frag or time limit; timelimit reached at a round end | No | - | wait threads do not wake for g_maxintermission (15 s) (g_main.cpp:618-630; con_timer.cpp:47-54). Scripts launched by events still run (scriptthread.cpp:2518) [P] | No script signal: SE_INTERMISSION is never triggered [C] |
| Client disconnect or crash | - | Nothing can be sent afterwards (sv_main.c:185-187) [NV] | - | - |
| Server crash | - | - | Server cvars and the pending ledger are lost | - |

**What survives a restart:**
- server cvars;
- client_t: the reliable queue and cl->userinfo (server.h:147);
- client archived cvars;
- gclient pers, but in MP InitClient calls G_InitClientPersistant at every spawn. That keeps only userinfo, dm_primary, enterTime, teamnum and round_kills (player.cpp:2709-2730; g_session.cpp:46-98) [P].

**Loss window at a gamestate.** Commands that were queued but not yet carried in a snapshot the old cgame had transitioned to are lost. Causes: snapshot rate gating, lost packets, interpolation lag (sv_snapshot.c:1332) [C]. setas that already executed survive, because the Cbuf is not cleared (cl_main.cpp:1011-1029). Cvars created by `setu` do not survive [C].

**Warnings script gets.**
- Round-based gametypes: `level waittill allieswin/axiswin/draw` fires 2 s after the win and about 3 s before `restart` (dm_manager.cpp:1441-1465, :1593-1599) [P]. Delivery does not need it, because restart keeps the queue.
- FFA/TDM limits, and admin or vote map changes: no warning.

**Bounded loss.** With the pending ledger in server cvars, credit is lost only for a player who never spawns again on that server process. The loss is at most one debounce window plus the write in flight.

### 2.8 Crash, upgrade, config reset, shared PC

| Event | Record in archived cvars (omconfig) | Record in its own file at the homepath root | Server per-guid ledger |
|---|---|---|---|
| Installer re-run or repair | Lost [NV LB] | Not touched: the installer names neither qkey nor a record and has no [UninstallDelete] section [NV; Inno test pending] | Not touched |
| Crash during a config write | Whole omconfig truncated [NV] | Safe with tmp + _commit + MoveFileExA/ReplaceFileA + .bak; nothing like that exists today [NV] | Truncated too [NV] |
| `cvar_restart` | User-created cvars deleted, loss persisted [NV LB] | Not touched | Not touched |
| Joining a server with a different fs_game | Cvar_Restart, then execs q3config.cfg instead of omconfig [S] | Not touched | - |
| Launching under another target game | Different configs directory [NV/M] | Same file | - |
| Two instances, or one shared Windows account | Last full write wins; no lock [S] | Safe only with read-merge-max-then-write, optionally LockFileEx | - |
| Two Windows accounts | Separate by default [S] | Separate | - |
| Any server's stufftext | Can set any coop_* [C] | Not directly; homepath-root reach via writeconfig '..' is unverified | - |
| Losing qkey | New guid; guid binding fails | Same | Orphaned |

Evidence for the table:
- **Installer overwrite.** [Files] copies installer/omconfig_default.cfg over home\maintt\configs\omconfig.cfg with only `ignoreversion` (installer/hzm_coop.iss:106). A reinstall already drops 3,951 coop setas, against 132 in the default file [M]. The comment at publish_release.ps1:151-152 ("seeds it once") is wrong about the installer [S].
- **Crash mid-write.** Every engine write truncates first, with no temp file and no rename (sys_win32.c:374-384). The engine has no atomic-replace helper; FS_Rename is a plain CRT rename (files.cpp:959, :989) [NV]. fs_write_content truncates too. Three zero-byte pins_*.dat on the live box suggest torn server writes but prove nothing [M].
- **cvar_restart.** Deletes user-created cvars (cvar.c:1521-1526) and marks the archive modified (cvar.c:1441). Engine-registered cvars are reset unless ROM, INIT or NORESTART (cvar.c:1529-1532) [S].
- **fs_game restart.** cl_parse.cpp:476-484, :618; common.c:1474, :1489-1513 [S].
- **Target game.** One configs directory per fs_gamedir. Both home/main (414 lines) and home/maintt (4,659 lines) exist live [NV/M].
- **No instance lock.** The mutex function is an empty stub (sys_main_new.c:205-215). The launcher refuses a second copy, but running the exe directly bypasses that (updater/updater.ps1:57) [S].
- **Windows accounts.** The default install is per user ({localappdata}) with fs_homepath {app}\home (hzm_coop.iss:32, :43, :329) [S].
- **Long values.** An archive line over 1024 bytes is silently skipped (cvar.c:1250-1262) [C].

**Upgrade handling** (record-unit report):
- Tagged, order-free sections. Unknown sections are copied byte for byte, and the signature covers the raw body.
- The header carries the format major version and the key id. A server that does not know either treats the record as read-only for the session and never writes it back. The engine archive does the same with newer data (g_main.cpp:1301-1304) [S].
- Ids come from an append-only generated registry. Roster ids keep permanent holes, such as 73 (bug-1907; docs/DECISIONS.md:279-281) [NV].
- A new builtin name parse-kills the whole calling .scr on an older game.dll (script/scriptcompiler.cpp:1119-1127; bug-298) [C], so new names go in a shim file.
- Keep the key-id table across releases, and re-sign forward on write-back.

**Recovery.**
- Nothing restores a lost qkey. The only real recovery is the player copying qkey and the record file together.
- A server ledger restores progress only on servers already visited.

### 2.9 Before verification, and when the progression script is dead

**Timing.**
- mp_manage waits 1 s, then polls every 0.5 s. A team flip runs `primarydmweapon "rifle"`, which deploys the player (mp.scr:107, :117, :142-151, :172-174, :189; player.cpp:12011-12111) [P].
- The player stays a spectator until picking a team. An import started at join can therefore finish before the first spawn, but nothing guarantees it will [P].

**Policy until the import verifies** (pick-transport report):
- **Grant:** the per-class starter for any slot not provably unlocked. Keep the wanted pick on the client. Coop precedent: loadout_deny with keepArchive=1 (loadoutpick.scr:96-108) [C]. No toasts; plan:84 already flags join-toast spam.
- **Show:** fail-LOCKED padlocks from generated cfgs (precedent: ui/loadout/lktab0.cfg:1, :71-76; lkfin.cfg:1-17) [S], plus one "verifying" status cvar. Push nothing per item.
- **Count:** kills go into a server-side session delta keyed by guid. The import writes only the baseline, and totals are baseline plus delta.
- **Failed verification:** session-only progress; never write back.
- **No HZM binaries:** starter kit only.

**Today's fail mode is accidental.**
- An unknown command is a compile error that kills the whole file (scriptcompiler.cpp:1125-1127, :1452-1467) [P].
- Later calls throw "not properly loaded" (scriptmaster.cpp:918-920), and while g_scriptcheck is 0 the caller carries on with a none value (scriptvm.cpp:1915-1947) [P].
- Both messages print only with developer 1 (common.c:381-383, :403-405) [P].
- So `if(waitthread X)` fails closed, `if(!(waitthread X))` denies, and `== 0` fails open.
- bug-1027 is NOT runtime proof of any of this: it was superseded and verified clean. docs/open_defects.md:17 is stale [P].

**Make the fail mode explicit.**
1. Once per map run `local.ok = waitthread <mp progression>::prog_alive` and require the literal 1.
2. Otherwise set a level flag and print a `^~^~^` line. Grant starters, and count, push and write nothing.
3. Route every unlock test through one wrapper that returns 0 or 1.
4. Put new engine command names only in a one-label shim .scr. Progression files should read engine-pushed variables, which compile on any game.dll (scriptcompiler.cpp:498-513) [C].

**If mp.scr itself dies.** American Allies (and everyone under the AA protocol) cannot pick a class from the UI, because ui/coop_weaponselect_suppress.urc:42-47 empties SelectPrimaryWeapon. Typing `primarydmweapon rifle` still works (player.cpp:1043-1050) [P].

---

## 3. Tamper resistance

### 3.1 Primitives available

| Primitive | Reachable from | Usable for signing? | Evidence |
|---|---|---|---|
| md5string | script | No | See below |
| md5file | nobody: no Event, no response row; opens raw OS paths with fopen | No | scriptthread.cpp:6894-7003 [S] |
| randomint / randomfloat | script | Nonces only: rand() seeded from Com_Milliseconds | g_utils.h:230-233; g_main.cpp:399; sv_game.c:1939 [S] |
| gi.CalcCRC | game.dll | No: 16-bit, unkeyed. gi exposes no hash or MAC otherwise. | g_public.h:233-509, :456; sv_game.c:1886; crc.c:111 [P] |
| qcommon/md5.c (32-bit words), md4.c | exe only today | Yes, if compiled into game.dll | qcommon/md5.c:20-24, :51-216; md4.c:199 [P] |
| GameSpy gsCrypt | exe and omohaaded (gcd_common), not game.dll | Yes, if compiled into fgame | See below [R] |
| libtomcrypt | autoupdater build only, downloaded | Not in the tree | rsa_tools/build-libtom-unix.sh:29,34 [P] |
| fs_read_content / fs_write_content | script, server disk | Storage only | scriptthread.cpp:2075-2112, :7400-7405 [NV] |
| gettime / getdate | script | No epoch value, only HH:MM:SS strings | scriptthread.cpp:7245-7270 [S] |

**md5string is broken on x64.**
- md5_word_t is size_t, 64 bits here. T_MASK becomes 64-bit and ROTATE_LEFT is unmasked. The aligned path reads 128 bytes from a 64-byte block; the unaligned path leaves X[8..15] uninitialized (fgame/md5.h:65; md5.cpp:57-64, :164-169, :197; fgame.vcxproj x64, :646) [C].
- A scratch x64 build printed sizeof 8. For "abc" it gave ae4fc1471f36f88ff07ffac0197094d8 on one run and af42e4862558f832de332b06e353cdff on the next; the RFC value is 900150983cd24fb0d6963f7d28e17f72 [M].
- Not yet checked on the live DLL (LB, test 9b-2). No mod script calls md5string, so fixing it breaks nothing [S].

**GameSpy gsCrypt** provides RSA-1024 PKCS#1 v1.5 sign and verify, SHA1, RC4 and large integers (gamespy/common/gsCrypt.h:31-82; gcd_common.vcxproj:314-323; openmohaa.vcxproj:187). This refutes "no asymmetric crypto vendored" [R].

**Conclusion.** Nothing script can call today can sign. game.dll is native x64 and already compiles its own md5.cpp and some qcommon sources (fgame.vcxproj:711-723), so a correct HMAC needs no gi ABI change [P].

### 3.2 Engine cost of new builtins

- **Script builtin** (e.g. mp_sign, mp_verify). Four sites:
  1. Event object, EV_RETURN like md5string (scriptthread.cpp:2002-2010).
  2. Response-table row (:2293).
  3. Declaration (scriptthread.h:355).
  4. Implementation that returns via ev->AddString (:7039) [P].
- **A new .cpp file** (e.g. sha256.cpp) needs a cmake re-run, because fgame globs its sources recursively (fgame/CMakeLists.txt:19-25) [S].
- **Player console event** (MP upload). Five sites:
  1. Event with EV_CONSOLE (player.cpp:328-336).
  2. extern in player.h:48.
  3. Response row (player.cpp:1997).
  4. Method and member (player.h:891-892).
  5. Implementation (player.cpp:7542-7567).
  - Dispatch requires EV_CONSOLE (entity.cpp:5465-5480; gamecmds.cpp:336-370) [NV].
- **cgame write-back.** A new branch in CG_ServerCommand's strcmp chain (cg_servercmds.c:386-530). The cgame imports already cover Cvar_Get/Set, FS_ReadFile/WriteFile and SendClientCommand (cg_public.h:124-169). cgame has no FS_SV_* and no rename (cg_public.h:140-145) [NV].
- **Engine delegates** (intermission, teamwin, TOW takeover). One ScriptDelegate declaration plus one Trigger site each (pattern: player.cpp:62-67). Each must do nothing unless something subscribes [NV].
- **Deploy.** game.dll ships to players via publish_release.ps1:78 and the updater manifest [C]; build.ps1:287 deploys locally.
- **Version skew.** Command names are checked at compile time. A server on an older game.dll parse-kills the whole calling file (scriptcompiler.cpp:1119-1127; gamescript.cpp:758-759) [C]. Put every new name in a one-label shim .scr.

### 3.3 The hostile-server hole (pre-existing, not in buglog)

**How it works.**
- `seta coop_x <any command>` then `vstr coop_x`. The filter checks only the name and skips the value up to the next ';' (filter :173, :334-336, :350-363). vstr inserts the value unfiltered (cmd.c:334-344). Only the stufftext branch is ever filtered (cg_servercmds.c:467) [C/NV].
- One command per cvar; chained vstrs give more. The mod itself relies on this exact pattern (bug-758) [C].

**It has more than one route.**
- Without vstr: `seta coop_loCmt01 <cmd>` then `exec ui/loadout/t01.cfg` (t01.cfg:2-3). There are 74 such files, and 497 cfgs under allowed exec paths contain `vstr coop_` [NV].
- It reaches non-coop cvars: `seta coop_x seta <record> <v>` plus vstr. User-created cvars also accept `set` and bare `<name> <value>` straight from stufftext (filter :210-222, :264-268; cvar.c:635, :857-874). This refutes "a non-coop archived cvar is safe" [R].
- Code-registered non-coop_ cvars resist direct stufftext, because Cvar_Get clears USER_CREATED (cvar.c:447-449) [C]. A trampolined `set` still overwrites them, since force=qfalse is blocked only by ROM, INIT, CHEAT and LATCH (cvar.c:665-685) [NV].
- CVAR_ROM|ARCHIVE is not a fix: registration replaces the saved value with the engine value (cvar.c:447-461) [S].
- Files: a trampolined `writeconfig <name>.dat` writes any gamedir-relative path except dll/qvm/pk3 (common.c:2158-2169; q_shared.c:276-295; files.cpp:697-708) [NV].

**It cannot be closed in cgame.**
- Deleting the filter's vstr branch breaks the coop armory resend (loadoutpick.scr:350, :363, :376, :399, :555, :603, :605, :621) and leaves the t<id>.cfg route open. That violates F [NV].
- cgame cannot ask whether a token is a command (cg_public.h:129-136), so a complete close is an exe change [NV].

**Consequence.**
- A hostile server can erase, but, given a server MAC, not forge, any record the client holds.
- In a design where every server holds the key (T1), a modified HZM server can also inflate records.
- Not recorded anywhere: TRAPS T8 treats the filter only as a lossy channel (docs/TRAPS.md:425-436) [S].

### 3.4 Options

| Tier | Mechanism | Cost | Stops | Does not stop |
|---|---|---|---|---|
| T0 | Server-side plausibility checks only (3.7) | script | impossible counters, gross rate abuse | anything that stays plausible |
| T1a | MAC computed in script with md5string | - | REJECTED: md5string is broken | - |
| T1 | Symmetric HMAC in game.dll (see below) | game.dll | config and file edits; typed or forged uploads; records copied to another guid | key extraction from game.dll; minting by hostile or modified HZM servers; listen-host script edits; bot farms; copying qkey together with the record |
| T2 | Asymmetric trusted issuer (see below) | game.dll, plus key management and designating servers | everything T1 stops, plus extraction and minting by non-trusted servers and listen hosts | a compromised trusted server; qkey+record copies; farming on trusted servers |
| Ledger | Per-guid high-water file on each server plus a monotonic sequence number | script, MP save names | rollback and replay on servers already visited | anything on a first visit |

**T1 in detail.**
- Builtins `mp_sign` / `mp_verify`, using HMAC-SHA256 (vendor about 200 lines) or HMAC-MD5 after fixing md5.h:65.
- Keys in a table indexed by key id.
- Per-player key = HMAC(K_kid, "hzm-mp1|"+guid).
- Optionally mix in a server-only cvar for closed server networks.
- Compare tags in constant time.

**T2 in detail.** The private key lives only on HZM-designated dedicated servers. game.dll carries a verify-only public key: GameSpy RSA compiled into fgame, or a vendored Ed25519.

### 3.5 Threat model

| Actor and action | T0 | T1 | T2 | Ledger |
|---|---|---|---|---|
| Player edits omconfig or the record file | partial | stops | stops | - |
| Player types the upload event with a forged body | partial | stops | stops | - |
| Player copies a friend's record, but not their qkey | no | stops (guid-bound key) | stops | - |
| Player copies a friend's qkey together with the record | no | no | no | no |
| Player rolls back to an older record | no | no | no | stops on visited servers |
| Player extracts the key from game.dll and mints records offline | no | no | stops | - |
| Listen host edits plain-text MP scripts, or farms frozen bots (`bot_manualmove 1`) | caps only | no: records sign correctly | stops, if listen-issued records are refused | - |
| Hostile or modified HZM dedicated server inflates its visitors | no | no | stops, unless it is a trusted issuer | - |
| Any server erases a visitor's record through a trampoline | - | no | no | restores on visited servers; a client-side .bak and monotonic merge reduce the damage |
| Version skew or unknown key id | - | fail read-only, never write back | same | - |

Honest summary: T1 stops casual tampering only. Decision E makes bot farming legitimate unless it is capped.

### 3.6 Mechanism the tamper report recommends, and its limits

**Mechanism.**
- T1 HMAC builtins. Key bytes never enter script variables.
- **Record contents:** version, key id, guid, sequence, credited playtime, weapon counters (and class counters, see 7.2), challenge counters, tag.
  - The tamper report says never to store unlocks.
  - The record-unit report says to latch them (decision 9a-6).
  - Latched tokens enlarge the signed surface. A forged token is stopped only by the MAC, not by consistency with the counters.
- **Import:** verify, then run invariants and caps, then accept.
  - On any failure the player gets session-only progress, and the server never writes back.
  - Write back only after a verified import, or when the client presented no record at all.
  - Re-sign with the current key id.
- **Players with no guid:** session-only progress. No netname fallback.
- **Server high-water per guid:** sanitize the guid to hex before using it in any file or cvar name. Whether FS_FOpenFileWrite rejects '..' is unverified (9c).
- **Code placement:** every mp_sign / mp_verify call lives in one shim .scr.

**Limits.** It does not stop:
- key extraction;
- minting by listen hosts or modified servers;
- qkey cloning;
- erasure by a hostile server.

### 3.7 Plausibility checks that need no key

- **Counter invariant.** The sum of weapon counters is at most the sum of class counters: each kill adds one class kill and at most one source kill (record-unit report).
- **Monotonic per server.** A counter is never lower than this server last saw for that guid.
- **Rate caps.** Credited kills per rolling window, with a separate, lower cap for bot kills (isBot).
- **Playtime ratio.** Total credited kills are at most credited playtime times a cap.
- **Witnessed only.** A server adds only kills it saw through player_killed.
- **Engine exclusions mirrored.** No credit for telefrag, suicide or team kills (player.cpp:3743-3766).
- **Bounded challenges.** Challenge counters cannot exceed their inputs, e.g. headshots cannot exceed that weapon's kills.
- **Side eligibility.** A kill credited to a weapon the player's armory cannot hold is suspicious. Picked-up grenades and some enemy guns are legitimate, though (weapon.cpp:3964-3967), so flag such kills rather than reject them.
- **Farm switches (user decision).** Zero credit while `bot_manualmove != 0` or `sv_cheats` is on.

---

## 4. Kill attribution recipe

### 4.0 Prerequisite

PvP health damage must be restored first (risk 1).

- **Candidate gate.** In Sentient::ArmorDamage, treat the two sides as different teams when both are Players on different DM teams, or in FFA, or when g_teamdamage is on [NV].
- **Coop safety.** Whether coop ever puts a player on axis, or runs FFA, is open (main.scr:517-525 forceValidTeam; mp.scr:14-16).
- **Filters that already exist before that point:** Player::ArmorDamage drops same-DM-team damage unless g_teamdamage is set. It also drops all non-telefrag damage TO a victim whose m_bAllowFighting is false (player.cpp:11603-11617) [P].

### 4.1 Hook and lifecycle

**Subscribing.**
- Use `event_subscribe player_killed coop_mod/<mp_file>.scr::<label>` with file::label UNQUOTED. It parses as a const array (yyParser.cpp:2361-2363); the identifier lexer excludes ':' (lex_source.txt:187) [P].
- A quoted "file::label" fails FindLabel (gamescript.cpp:1143-1147, :1171-1179) [P].
- A label in the same file works, bare or quoted (upstream doc docs/markdown/04-coding/02-scripting/01-script-events.md:22-24) [P].
- The VM does not type-check arguments (scriptvm.cpp:596-619) [C].
- Never executed in this mod (LB, runtime unverified).

**Execution.**
- The handler runs synchronously inside Player::Killed with self = victim (player.cpp:3653; scriptdelegate.cpp:151-160; gamescript.cpp:893, :923-933) [C].
- A Script Error is caught and printed without aborting the death (scriptthread.cpp:2526-2548) [S].
- A heavy handler stalls the kill path for every death, bots included [S].

**Re-subscribe on every level load, including every round restart.**
- ResetAllDelegates runs unconditionally (scriptmaster.cpp:784), and `restart` goes through SV_SpawnServer and Cleanup (sv_init.c:725-729) [C].
- A duplicate subscribe is a no-op (scriptdelegate.cpp:118; gamescript.h:202-205) [C].

**Do not use:**
- **killhandler.** It replaces the death path and returns before scoring, the obituary and the delegate (player.cpp:3534-3544, return at :3543). Its setter treats a string as a FILE name (player.cpp:19362-19368; gamescript.cpp:1037-1040) [P].
- **`registerev kill`.** Deprecated, one registrant server-wide, self is NULL (scriptthread.cpp:7086-7117) [S].
- **The coop torso KILLED path.** It carries no arguments and is coop code (player_Torso.st:3224-3232; events.scr:46-51; main.scr:496-501; player.scr:1555-1644) [S].
- **self.fact.** Coop's AI kill path reads self.fact.attacker (aihandler.scr:1756-1760). Whether it is ever set for a Player was not re-verified. MP must not rely on it.

**Companion hooks.**
- player_damaged: self is the victim, 11 args. It fires AFTER player_killed on the killing hit, and is skipped for filtered team damage (player.cpp:11603-11645; sentient.cpp:2034-2047) [S].
- player_spawned (player.cpp:18592-18604) and player_disconnecting (player.cpp:11653) [S].

### 4.2 Arguments and enums

**Arguments** (player.cpp:3639-3651; entity.cpp:190-199) [C]:
1. attacker (entity)
2. damage (float)
3. inflictor (entity)
4. position (vector)
5. direction (vector)
6. normal (vector)
7. knockback (int)
8. dflags (int)
9. meansofdeath (int)
10. location (int)
11. victim (= self)

**State at trigger time.**
- The victim is already removed from vehicles and turrets (player.cpp:3561) [C].
- The victim's weapon drop is posted +0.1 s later, so the attacker's weapon and the victim's inventory are still in place (player.cpp:3590, :3659-3689) [S].
- The arguments are SafePtrs: copy everything you need before any wait.

**meansofdeath values** (bg_public.h:478-517; g_utils.cpp:36-67) [C]:

| Value | Name | Value | Name | Value | Name |
|---|---|---|---|---|---|
| 0 | none | 10 | explodewall | 20 | vehicle |
| 1 | suicide | 11 | electric | 21 | fire |
| 2 | crush | 12 | electricwater | 22 | flashbang |
| 3 | crush_every_frame | 13 | thrownobject | 23 | on_fire |
| 4 | telefrag | 14 | grenade | 24 | gib |
| 5 | lava | 15 | beam | 25 | impale |
| 6 | slime | 16 | rocket | 26 | bash |
| 7 | falling | 17 | impact | 27 | shotgun |
| 8 | last_self_inflicted | 18 | bullet | 28 | aagun |
| 9 | explosion | 19 | fast_bullet | 29 | landmine |

**Hit locations** (q_shared.h:1426-1449) [C]:
- -2 miss (never reaches the handler), -1 general, 0 head, 1 helmet, 2 neck, 3 torso_upper, 4 torso_mid, 5 torso_lower, 6 pelvis, 7-18 limbs.
- The numbering in the EV_Killed and EV_Damage doc strings is stale (entity.cpp:195-197, :223-225).
- A helmet hit on a victim without a helmet is folded to head before the kill event (sentient.cpp:1557-1568, :1619) [C].

### 4.3 Expressions

| Question | Expression | Evidence and notes |
|---|---|---|
| NULL attacker possible? | yes: guard `local.attacker != NULL` | A script `damage NULL` on a player bypasses the world substitution (entity.cpp:218-226; sentient.cpp:1610-1612; maps/e1l1/scene1.scr:323) [P] |
| World or environment | `local.attacker == $world` | entity.cpp:2710-2715; worldspawn.cpp:635 [P] |
| Attacker is a player (human or bot) | `local.attacker != NULL && local.attacker != $world && local.attacker.classname == "Player"` | listener.cpp:101-107; aihandler.scr:1085 [S] |
| Suicide or self-inflicted | `local.attacker == local.victim` | Covers: kill command, MOD 1, refused within 5 s of spawn (player.cpp:7455-7464); falling, MOD 7 (:7696); own grenade or rocket; trigger_hurt, which passes the victim as attacker (trigger.cpp:2088-2090); exit crush (trigger.cpp:1889) [S] |
| Telefrag | `local.mod == 4` (attacker is the arriving entity) | g_utils.cpp:966-976; engine scores nothing (player.cpp:3743-3750) [S] |
| Team kill | gametype >= 2 and `local.attacker.dmteam == local.victim.dmteam` | The engine compares DM_Team (player.cpp:3761); only reachable with g_teamdamage 1. dmteam is 'allies', 'axis', 'spectator' or 'freeforall' and errors otherwise (player.cpp:13574-13587). Gametype enum: bg_public.h:136-147 [P/S] |
| FFA | `local.attacker.dmteam == "freeforall"`: never a team kill | [S] |
| Bot | `isBot local.attacker`, `isBot local.victim` | scriptthread.cpp:7364-7381 [C] |
| Headshot | real location (MOD 18, 27, or 28 from turrets/vehicles) and location in 0-1 or 0-2 | The engine's own counter groups 0-2 (weaputils.cpp:2055-2058). No tik uses MOD 19. Melee, projectile direct hits and splash pass -1 (weaputils.cpp:170, :1269-1271, :3866; entity.h:417-428) [P]. 0-1 vs 0-2 is decision 9a-9. |
| Melee | `local.mod == 26`; attacker == inflictor; location -1 | weapon.cpp:2563-2592; weaputils.cpp:170; tiks say `secondary meansofdeath bash`, e.g. mod pak colt45.tik:74, m1_garand.tik:80 [C] |
| Grenade | `local.mod == 14` | Hand grenades and the Gewehrgranate secondary (kar98_mortar.tik:75-77; riflemortar.tik:25) [C] |
| Rocket direct hit | `local.mod == 16`; inflictor is the Projectile | bazookashell_dm.tik:21 (hitdamage 280), :25 [C] |
| Rocket splash | `local.mod == 9` with `local.inflictor.model` = models/fx/bazookaexplosion_dm.tik or models/fx/explosionpiatshell.tik | Splash MOD comes from the explosion tik (bazookaexplosion_dm.tik:22-23; explosionpiatshell.tik:19) [C]. **Do not drop all of MOD 9**: the class-mapping recipe did, and that would drop every rocket splash kill. |
| Barrel or world explosion | MOD 9 with a non-weapon inflictor (BarrelObject) | challenges.scr:1578; no credit |
| Landmine | `local.mod == 29` | TT maps; attribution not traced (weaputils.h:372; trigger.cpp:3204-3290) |
| Weapon (hitscan or melee) | `local.w = local.attacker getactiveweap 0`, then `local.wtik = local.w.model` if not NULL | sentient.cpp:631-639; sentient_combat.cpp:1469-1484 [P] |
| Turret or vehicle kill | Check `local.attacker.turret != NULL` and `.vehicle != NULL` FIRST | See below [P/C] |
| Quick-draw | pistol sits in WEAPON_MAIN, so credit is PISTOL | player.cpp:16573-16574; player.h:392-396 [S] |
| After the round is won, or in intermission | engine skips scoring (dm_manager.cpp:258-262), but the delegate still fires | No script getter for either state found [NV]. The allieswin latch is 2 s late; see 6.4 for an engine delegate. |
| killhandler set on anyone | diagnostic warning | A set killhandler silently removes the delegate for that player's deaths (player.cpp:3534-3544) |

**Turret and vehicle kills in detail.**
- Getters: player.cpp:1518-1535, :18569-18577.
- The main-hand slot is normally NULL, because TURRET_PUTAWAY and VEHICLE_PUTAWAY run `deactivateweapon righthand` (player_Torso.st:50-51, :3886-3906, :4023-4045; sentient_combat.cpp:776, :801-816) [P].
- A fixed MG42 sets owner to the using player (weapturret.cpp:1776-1783).
- A vehicle turret with no owner credits its remote owner (weapon.cpp:2209-2214) [C].

### 4.4 Dispatch by meansofdeath

**0. Snapshot before any wait:** attacker, victim, inflictor, mod, location, netnames, guids, dmteams, isBot for both, attacker turret and vehicle, active weapon model.

**1. Reject** (no credit) when any of these hold:
- attacker is not a Player;
- attacker == victim;
- mod is 4;
- team kill;
- round-won or intermission gate;
- attacker is a bot.

A human attacker without a verified record still counts, into the session delta (2.9).

**2. Emplacement gate.** If attacker.turret or attacker.vehicle is set, give no weapon or class credit. An optional emplacement stat is possible.

**3. Resolve the source.**

| MOD | Source |
|---|---|
| 18, 19, 27, 26 (and 28 when not on a turret) | Active weapon model |
| 16 | The active weapon if it is a launcher. Otherwise inflictor model: piat_rocket_dm -> PIAT (47); bazookashell_dm -> Bazooka (45) or Panzerschreck (46) by attacker side |
| 9 | Inflictor model: bazookaexplosion_dm -> 45/46 by side; explosionpiatshell -> 47. Anything else: no credit |
| 14 | Inflictor model: riflegrenadeexplosion -> kar98_mortar (a non-roster source); M2FGrenadeExplosion -> 64 (Allied) or 65 (Axis) by side, or by a throw latch; MillsGrenadeExplosion -> 66; f1GrenadeExplosion -> 67 Bomba (Axis) or Russian F1 (Allied, non-roster) |
| 29, 2, 3, 20, all others | No weapon credit |

Two facts make "attacker side" safe for splash kills:
- A thrower who changes team or disconnects mid-flight has the projectile removed with no damage (weaputils.cpp:1455-1490, :873-876; player.cpp:11376-11383). For credited splash kills the attacker's current side is therefore the fire-time side.
- A dead thrower is still credited (weaputils.cpp:883-892) [S].

**Side-based grenade disambiguation is wrong for picked-up grenades.** The engine waives the class check for grenades (weapon.cpp:3964-3967) [C].

**4. Look up** the lowercase path in a generated exact-match table (section 5). The result is a source id, family id, class token and side.

**5. Increment** the class counter (ignoring team) and the source counter. The class is decided now and frozen into the record.

### 4.5 In-game test list

Setup: dedicated server, one remote human client, engine bots (`+set sv_maxbots 2 +set sv_numbots 2`), a stock MP map, developer 1, and a throwaway stub label that prints all 11 arguments. Listen-server runs are for comparison only.

| Id | Test | Pass condition |
|---|---|---|
| K0 | Shoot a bot on the enemy team | Health drops and a "was shot by" obituary appears. Otherwise the sentient.cpp:1798-1801 filter is live, and the BLOCKER stands. |
| K0b | g_teamdamage 0: shoot a teammate | No damage, unchanged by any fix |
| K1 | event_subscribe with unquoted file::label from mp.scr::main | No Script Error; the stub prints on a death |
| K2 | Argument order | arg1 = killer, arg11 = victim = self, arg9 = MOD, arg10 = location |
| K3 | Re-subscribe after same-map `map`, after a map change, after a round restart | The next kill still prints |
| K4 | Rifle headshot, then a body kill | location 0/1 (or 2) with MOD 18; then 3-6 |
| K5 | Rifle-butt kill | MOD 26, location -1, `getactiveweap 0 .model` is the rifle tik |
| K6 | Throw a grenade, switch to the rifle, kill with the blast | MOD 14; inflictor classname and model readable; active weapon is the rifle |
| K6b | Bazooka splash kill, then a direct hit | MOD 9 with inflictor bazookaexplosion_dm; then MOD 16 with inflictor bazookashell_dm |
| K7 | `kill` after 5 s; a fall death | attacker == victim with MOD 1; then MOD 7 |
| K8 | isBot | Prints 1 when the bot kills you, 0 when you kill it |
| K9 | Load a coop map afterwards | The stub never prints on a coop death |
| K10 | MG42 nest kill | attacker.turret non-NULL; getactiveweap 0 NULL or not |
| K11 | Vehicle gun kill | attacker.vehicle and attacker as above |
| K12 | Grenade, thrower dies before detonation; again with the thrower disconnecting | Credit goes to the dead thrower; the disconnect removes the projectile |
| K13 | A kill after teamwin but before restart; FFA intermission | The delegate fires; check the engine score is unchanged |
| K14 | Quick-draw pistol kill | Credited to the pistol |
| K15 | Kill with a picked-up enemy grenade, and with an enemy gun | Model is the enemy tik |
| K16 | Landmine and AA gun on TT/TA maps | Args 1, 3, 9 |
| K17 | MP deaths with the coop statefile | No DBNO interception; no manageDead Script Error |
| K18 | One shotgun blast at a bot | Count player_damaged events |
| K19 | `level.t["ABC"] = 1; println level.t["abc"]` | Case-sensitivity result |

---

## 5. Class and weapon mapping

### 5.1 Why a generated exact-match table

**No existing class source matches the armory.**
- The engine class bits have no sniper and no shotgun bit (bg_public.h:385-396; g_utils.cpp:1951-1974) [C].
- Tik weapontype disagrees with the armory tabs [C]:
  - shotgun is heavy, subtype 2 (shotgun.tik:21-22);
  - kar98_mortar is heavy, subtype 1;
  - StG44, BAR, FG42 and DP-28 are mg;
  - mp44scoped is rifle (zzzzz_xw_weapons.pk3 models/weapons/mp44scoped.tik:23);
  - all snipers and the De Lisle are rifle.
- Armory tab 3 mixes MGs, StG44, FG42, the shotgun and the rockets (loadout_weapons.tsv:51-62) [NV].
- The challenge catalogue files StG44 under rifles and the shotgun under support_weapons (challenges.scr:92, :191) [NV].
- The SVT (id 08, zoom 20) and G43 (id 04, zoom 30) are zoom rifles in the RIFLE tab; cgame draws a scope for zoom <= 30 (svt_rifle.tik:104; cg_drawtools.cpp:551-567) [P].

**Script cannot read a weapon's class or name.**
- The only EV_GETTER in weapon.cpp and item.cpp is putaway (weapon.cpp:904-912) [C].
- getcurrentdmweapontype returns the latched DM class m_sDmPrimary, not the killing weapon (player.cpp:1088-1095, :12160-12163) [P].

**What script can read is the model path, and it is reliable.**
- `.model` is lowercase with forward slashes (sentient.cpp:1403-1428; entity.cpp:2066; g_utils.cpp:1524-1535; files.cpp:4346-4383). The getter returns the TIKI name (entity.h:744-761), which is canonicalized at registration (tiki_cache.cpp:108-109) [C].
- Across all 427 finish/variant pairs, weapontype and subtype never differ from the base tik (compared with `diff --strip-trailing-cr`) [P]. Model variants such as bar_bar1918 also change name, rank and animation skcs [P].

**Coop's resolver cannot be reused.**
- Clause 10 forbids MP calling chal_widFromModel (check_mp_isolation.py:286).
- It misattributes (challenges.scr:1353-1409; scratch emulation of main.scr:1334-1373) [P]:
  - **No id at all:** carbine; colt_silenced; fg42 and 7 skins; 11 of 12 BAR entries (bar_pabar resolves); dbno_pistol; every grenade; mine detectors; coop binoculars and smoke.
  - **Wrong id:** it_w_bombabreda -> breda; kar98_mortar and kar98_g98 (a G43 variant) -> kar98.
  - **Folded across tabs:** garand_scoped and garand_silenced -> garand; enfieldsniper -> enfield; springfield_unscoped -> springfield; mp44scoped -> stg44; both moschetto tiks -> moschetto; ppsh43silenced -> ppsh.
- itemhandler.scr::returnActiveWeapon rewrites the held weapon's targetname and falls back to a possibly stale flag (itemhandler.scr:2834-2857) [C]. Do not use it.

**Generator inputs and traps.**
- coop_skinGive keys are mixed case (e.g. US_W_MineDetector). The generator must lowercase them.
- 28 roster tiks exist only in maintt/zzzzz_xw_weapons.pk3, which is untracked and not managed by build.ps1 (docs/DECISIONS.md:248-250) [P]. g43sniper, tt33, tt33silenced and welrod ship in the mod pak. The generator must read the xw pak or treat those give paths as opaque keys.

**Sides.**
- The 74 ids split 42 Allied and 32 Axis. Per tab: RIFLE 8/4, SNIPER 7/5, SMG 8/5, HEAVY 7/6, PISTOL 9/9, NADES 3/3.
- Allied = US/UK/USSR; Axis = DE/IT/JP (scratch lo_sides.py) [P].
- Id 44 (shotgun) is counted Allied. plan:122 says no weapon appears on both sides, which contradicts G.
- The TSV has no nation column.

### 5.2 Allied MP-eligible weapons

"xw" marks tiks that exist only in zzzzz_xw_weapons.pk3. Family = the coop unlock source (challenges.scr line).

| Id | Tik | Roster tab | Proposed MP class | Engine weapontype | Family |
|---|---|---|---|---|---|
| 01 | m1_garand | 0 | RIFLE | rifle | - |
| 02 | carbine (xw) | 0 | RIFLE | rifle | - |
| 05 | enfield | 0 | RIFLE | rifle | - |
| 06 | springfield_unscoped (xw) | 0 | RIFLE | rifle | - |
| 08 | svt_rifle | 0 | RIFLE (zoom 20) | rifle | - |
| 09 | mosin_nagant_rifle | 0 | RIFLE | rifle | - |
| 11 | garand_silenced (xw) | 0 | RIFLE | rifle | 01 (:290) |
| 70 | johnson_m1941 | 0 | RIFLE | rifle | - |
| 12 | springfield | 1 | SNIPER | rifle | - |
| 14 | uk_w_l42a1 | 1 | SNIPER | rifle | 05 (:293) |
| 15 | garand_scoped (xw) | 1 | SNIPER | rifle | 01 (:289) |
| 17 | enfieldsniper (xw) | 1 | SNIPER | rifle | 14 (:107) |
| 20 | nagant_sniper (xw) | 1 | SNIPER | rifle | 09 (:294) |
| 21 | nagant_snipersilenced (xw) | 1 | SNIPER | rifle | 20 (:101) |
| 23 | delisle | 1 | SNIPER | rifle | - |
| 24 | thompsonsmg | 2 | SMG | smg | - |
| 25 | thompson50 (xw) | 2 | SMG | smg | 24 (:298) |
| 28 | sten | 2 | SMG | smg | - |
| 29 | ppsh_smg | 2 | SMG | smg | - |
| 30 | ppsh43silenced (xw) | 2 | SMG | smg | 29 (:300) |
| 31 | greasegun (xw) | 2 | SMG | smg | - |
| 32 | greasegun_silenced (xw) | 2 | SMG | smg | 31 (:301) |
| 71 | thompsonsmg_gold | 2 | skin of 24, not a gun (loadoutskins.scr:345) | smg | 24 |
| 36 | bar | 3 | MG | mg | - |
| 40 | uk_w_vickers | 3 | MG | mg | - |
| 42 | 30calportable (xw) | 3 | MG | mg | - |
| 72 | dp28 | 3 | MG | mg | - |
| 44 | shotgun (also Axis) | 3 | SHOTGUN or HEAVY | heavy sub 2, MOD 27 | - |
| 45 | bazooka | 3 | ROCKET/HEAVY | heavy | - |
| 47 | uk_w_piat | 3 | ROCKET/HEAVY | heavy | - |
| 48 | colt45 | 4 | PISTOL | pistol | - |
| 49 | colt_silenced (xw) | 4 | PISTOL | pistol | 48 (:302) |
| 52 | silencedpistol | 4 | PISTOL | pistol | - |
| 53 | webley_revolver | 4 | PISTOL | pistol | - |
| 54 | nagant_revolver | 4 | PISTOL | pistol | - |
| 60 | tt33 | 4 | PISTOL | pistol | - |
| 61 | tt33silenced | 4 | PISTOL | pistol | 60 (:305) |
| 63 | welrod | 4 | PISTOL | pistol | - |
| 75 | m10_revolver | 4 | PISTOL | pistol | - |
| 64 | m2frag_grenade_sp_start (also m2frag_grenade / _sp / _start) | 5 | NADES | grenade | - |
| 66 | mills_grenade_sp_start (also mills_grenade) | 5 | NADES | grenade | - |
| 68 | m18_smoke_grenade_start (also m18_smoke_grenade) | 5 | NADES (smoke, cannot kill) | grenade sub 1 | - |

### 5.3 Axis MP-eligible weapons (German, Italian, Japanese)

Japanese by name: 10, 19, 35, 62. Only 62 (Nambu) was spot-checked. 34 moschetto.tik is the Beretta M38A (Italian), a different gun from 33.

| Id | Tik | Roster tab | Proposed MP class | Engine weapontype | Family |
|---|---|---|---|---|---|
| 03 | kar98 | 0 | RIFLE | rifle | - |
| 04 | g43 | 0 | RIFLE (zoom 30) | rifle | - |
| 07 | it_w_carcano | 0 | RIFLE | rifle | - |
| 10 | arisaka (xw) | 0 | RIFLE | rifle | - |
| 13 | kar98sniper | 1 | SNIPER | rifle | 03 (:291) |
| 16 | g43sniper | 1 | SNIPER | rifle | 04 (:292) |
| 18 | carcanosniper (xw) | 1 | SNIPER | rifle | 07 (:295) |
| 19 | arisakasniper (xw) | 1 | SNIPER | rifle | 10 (:296) |
| 22 | kar98snipersilenced (xw) | 1 | SNIPER | rifle | 13 (:97) |
| 26 | mp40 | 2 | SMG | smg | - |
| 27 | mp40silenced (xw) | 2 | SMG | smg | 26 (:299) |
| 33 | it_w_moschetto | 2 | SMG | smg | - |
| 34 | moschetto (xw) | 2 | SMG | smg | - |
| 35 | type100smg (xw) | 2 | SMG | smg | - |
| 37 | mp44 | 3 | MG | mg | - |
| 38 | mp44scoped (xw) | 3 | MG or SNIPER (open) | rifle | 37 (:297) |
| 39 | fg42 | 3 | MG | mg | - |
| 41 | it_w_breda | 3 | MG | mg | - |
| 43 | mg42portable (xw) | 3 | MG | mg | - |
| 46 | panzerschreck | 3 | ROCKET/HEAVY | heavy | - |
| 50 | p38 | 4 | PISTOL | pistol | - |
| 51 | p38silenced (xw) | 4 | PISTOL | pistol | 50 (:303) |
| 55 | it_w_beretta | 4 | PISTOL | pistol | - |
| 56 | berettasilenced (xw) | 4 | PISTOL | pistol | 55 (:306) |
| 57 | lugerp08 (xw) | 4 | PISTOL | pistol | - |
| 58 | lugerp08silenced (xw) | 4 | PISTOL | pistol | 57 (:304) |
| 59 | ppk (xw) | 4 | PISTOL | pistol | - |
| 62 | nambu (xw) | 4 | PISTOL | pistol | - |
| 74 | mauser_c96 | 4 | PISTOL | pistol | - |
| 65 | steilhandgranate_start (also steilhandgranate) | 5 | NADES | grenade | - |
| 67 | it_w_bomba_sp_start (also it_w_bomba) | 5 | NADES | grenade | - |
| 69 | nebelhandgranate_start (also nebelhandgranate) | 5 | NADES (smoke) | grenade sub 1 | - |

### 5.4 Non-roster and coop-only sources

**Stock DM kit items not in the roster** (EquipWeapons, player.cpp:10737-11033) [P]:
- **kar98_mortar:** the German TA shotgun-class kit unless DF_DISALLOW_KAR98_MORTAR (player.cpp:10901). Bullets are MOD 18; the rifle grenade is MOD 14. Reserve a non-roster source id.
- ***_lite rifles** (m1_garand, kar98, enfield, it_w_carcano, mosin_nagant_rifle): landmine class, only when g_rifles_for_sweepers is set (player.cpp:10911-10964). Map to roster 01/03/05/07/09 RIFLE, or reserve ids.
- **us_w_minedetector / gr_w_minedetector:** grenade subtype 9. Mine kills are MOD 29.
- **russian_f1_grenade:** Russian kit only. NADES, no roster id.
- **rdg-1_smoke_grenade, it_w_bombabreda, M18_smoke_grenade, nebelhandgranate:** smoke grenades.
- Stock DM class names do not match the weapon: the Russian SVT is under "sniper", the British TT De Lisle is under "shotgun", the German TA G43 is under "sniper". Italians fall back to the American default for the shotgun and landmine classes [P].
- The plain stock grenade paths differ from the roster _start / _sp_start paths, so the table needs both keys.

**Coop-only, never in MP:** dbno_pistol, coop_smoke_grenade, coop_binoculars, each with 7 skins.

**Skins and variants:** every coop_skinGive[base][fid] maps to the base's roster id and class. kar98_g98 maps to G43 (04), not Kar98 (loadoutskins.scr:475) [C].

### 5.5 Edge cases

- **Prefix traps (why lookups must be exact-match):** kar98_mortar_gold is not a Kar98 skin; kar98_g98 is a G43 variant; springfield_unscoped is not a sniper skin; enfieldsniper and uk_w_l42a1 are separate guns; thompsonsmg_gold is both roster id 71 and skin fid 1 of 24.
- **Picked-up enemy guns.**
  - A player carrying a primary cannot pick up a primary of a different engine class. A same-class or duplicate gun gives ammo only (weapon.cpp:3959-3963, :4019-4077).
  - Only a player with no weapon of that class receives the dropped entity itself, which keeps its model and skin (weapon.cpp:3969-4013) [C].
  - Grenades waive the class check (weapon.cpp:3964-3967).
  - There is no team check anywhere. coop_pickupOneMag defaults to 1 with no gametype gate (weapon.cpp:3952-3957) [C].
- **Drops after a turret or vehicle mount.** The main slot is NULL, so nothing drops [C].
- **Barrels:** MOD 9 with a non-weapon inflictor; no credit.
- **Shotgun on both armories:** one path, models/weapons/shotgun.tik, one source id (44). Tile 44 needs a second target.

### 5.6 Character gear actually shipped, by side

Census of every models/player/*.tik across main, mainta and maintt: 551 unique names. No loose models/player directory exists under any homepath [NV].

**Allied skins: 135**, exactly coop's roster (helmet.scr:869-1004). The plan's figure of 142 disagrees.
- 111 carry the allied/american prefix: 90 American, 15 British, 6 Russian. All have _nohat twins, and 93 have _fps twins.
- 24 match neither prefix and can only be applied with `model`: 34th_Infantery_Division_* x4, rifleman/submachine_gunner/support_gunner and their nohelm variants x6, and 14 named characters.
- 25 of the 135 are stock.

**Axis skins: 25**, all stock [NV LB].
- 21 German.
- 4 Italian: IT_AX_Ital_Vol, Sc_AX_Ital_Inf, Sc_AX_Ital_Inf2, SC_AX_ITAL_PARA.
- 24 have _fps twins; german_Stukageschwader does not.
- No _nohat twins. The mod pak ships 0 Axis tiks.
- HRRTM adds 63 German-only bodies, but HRRTM is not shipped (docs/tools/gen_glove_views.py:46-49; TRAPS T6 at docs/TRAPS.md:306-322). The plan's "88 Axis models" counts HRRTM.

**Japanese character models: ZERO in any pk3.** The only Japanese-named files are japaneseflag.tga weapon-skin textures and scripts/japanese_weapons.shader [NV LB].

**Headgear: 47 entries** (helmet.scr:31-167) [NV]:
- 1 Standard Issue and 2 No Helmet.
- US props (12): 3-10, 16, 33, 34, 37.
- British props (10): 11-15, 30, 36, 44-46.
- German props (16): 17-26, 31, 35, 40-42, 47. Index 35 is the Gas Mask, extracted from HRRTM's german_Wehrmacht_GasTrooper.
- Italian props (3): 27-29.
- Soviet prop (1): 32.
- Glasses (2): 38 and 39.
- Nation not assigned (1): 43 Wool Cap.
- Also 72 per-skin coop_std_* pieces for the Allied hatless twins.

**Per-side headgear pool.**
- Allied: 23 nation props, plus 2 glasses, plus the Wool Cap if it is Allied.
- Axis: 19 nation props plus 2 glasses. With no hatless Axis bodies, props would sit over the baked helmet.

**Gloves: 7 entries**, 0-6: Bare Hands, Leather, Wool, US Winter, Mittens, Seaman, Alpine (gloves.scr:7-18).
- They are skin-bit swaps on the `hand` surface, defined only in the mod's Allied and neither-prefix tiks. 0 Axis tiks carry glove skins.
- Axis gloves therefore need new tiks, with a separate cvar (plan decision 4) [NV].

### 5.7 Gating character gear without the shared dm_playermodel key

**Today's leak.**
- InitModel dresses the player from pers.dm_playermodel or dm_playergermanmodel.
  - Allied names must start american or allied; Axis names german, axis, it or sc.
  - _fps names are rejected, and anything else falls back to american_army / german_wehrmacht_soldier (player.cpp:2815-2871).
  - The keys are copied from userinfo with no validation (g_client.cpp:781-797) [NV].
- It re-runs on every MP respawn (InitClient re-reads userinfo at player.cpp:2712-2724; Init -> InitModel at :2615; Respawn at :3135) and on every team switch (player.cpp:11482-11485) [NV LB].
- Coop writes the key from helmet.scr:1393, lobby.scr:549, player.scr:1327 and itemhandler.scr:862/:902.
- mp.scr does no model work, so MP players wear their coop skin [NV LB].
- The MP options screen's Allies model button opens the COOP armory (ui/multiplayeroptions.urc:164-174; ui/loadout/open.cfg:2-4) [S].

**Recipe.**
- Treat InitModel's result as untrusted.
- On every spawn and every team change, the server picks the body from an MP roster for that team and applies it with `model` (entity.cpp:6543-6546). `model` has no nation-prefix check, and Sentient::setModel re-attaches weapons (sentient.cpp:4757-4763).
- Re-apply headgear nodraws and glove bits afterwards, because setModel zeroes s.surfaces (entity.cpp:2034-2040).
- **Script-only, same frame:** player_spawned fires in the same Player::Init right after InitModel (player.cpp:2615, :2649, :18603). A handler that re-models before its first wait therefore acts within the spawn frame [NV LB, runtime unverified].
- **Fail-closed alternative:** an HZM per-player model override member that InitModel checks first, never set by coop.

**What `model` does not fix.**
- Voice nationality, the stock kit and the weapon menu still come from the userinfo keys (player.cpp:10468-10513, :12201-12225, :18457-18461; lib_dm.scr:636, :651) [NV LB].
- Controller tags come from the first tiki only (player.cpp:2873-2876). Not verified on Axis skeletons.

**Bots and local rendering.**
- Bots pick random models from every mounted allied_/american_/german_/IT_/SC_ tik, including coop-gated skins (g_bot.cpp:43-46, :104-146) [S].
- cg_forceModel is a local-only render override (cg_modelanim.c:1172-1257) [S].

---

## 6. Match events per gametype

### 6.1 Event table

Gametypes: 1 FFA, 2 TDM, 3 round TDM, 4 OBJ, 5 TOW, 6 LIB (bg_public.h:136-147). Engine work: "no" means script alone can do it. Evidence and caveats follow the table.

| Event | GT | Hook or derivation | Reliability | Engine work |
|---|---|---|---|---|
| Kill | 1-6 | player_killed with the 4.3 filters; re-subscribe each load | High | Optional: "team win decided" getter |
| Headshot | 1-6 | arg 10 in 0-2 on hitscan MODs | High for hitscan | no |
| Kill streak | 1-6 | per-attacker counter; reset when that player dies; flush milestones immediately | High | no |
| Multikill | 1-6 | level.time of last valid kill; N-second window | High | no |
| First blood | 1-6 | first valid kill after roundstart (GT 3-6) or map load (GT 1-2) | High | no |
| Revenge | 1-6 | store victim's lastKiller by client number plus identity | High within a map | no |
| Assist | 1-6 | player_damaged accumulates damage per victim/attacker since spawn; credit other enemy damagers at the kill | Medium-high | no |
| Round win/loss/draw | 3-6 | parallel `level waittill allieswin/axiswin/draw`; winners are $player by dmteam | High, ~3 s window | Optional dm_teamwin delegate |
| Match win / match end | 1-6 | no signal; derive from limits and a round-win tally in a server cvar | LOW | YES: dm_intermission delegate |
| OBJ bomb planted | 4 (+ Ardennes/Flughafen TOW) | poll level.bombs_planted rising edge; planter = planting-team player holding use >= 5 s | Team high, player medium | YES for exact planter |
| OBJ bomb defused | 4 | bombs_planted falls with no targets_destroyed rise in the prior 0.5 s; defuser held use >= 6 s | Team high, player medium | YES |
| OBJ target destroyed | 4 (and ship_lib in 6) | level.targets_destroyed rising edge | Team high | YES for player |
| TOW objective captured | 5 | poll tow_allied_obj1..5 / tow_axis_obj1..5 for flips; capturer on 4 maps = getkills +2 jump | Team high; player medium (4 maps) / none (3 maps) | YES: tow_takeover delegate |
| LIB rescue | 6 | poll level.axisLiberator / level.alliesLiberator, cross-check injail 1->0 | High | no |
| LIB capture | 6 | valid kill in GT 6; optionally victim injail 0->1 | Medium-high | no |
| Playtime | 1-6 | sample every N s for allies/axis, non-spectator; flush on player_disconnecting and periodically | High (+/- N s) | Optional enterTime getter |
| Survival time | 1-6 | level.time from player_spawned to player_killed; lives ended by restart close at allieswin | High | no |
| Accuracy / shots | 1-6 | NOT observable | None (shots); low (hits) | YES |
| Round start | 3-6 | `level waittill roundstart` or poll level.roundstarted; never in GT 1-2 | High | no |

**Per-event evidence and caveats.**
- **Kill:** player.cpp:3552-3565, :3639-3653; scriptmaster.cpp:784; dm_manager.cpp:258-262 [C/NV].
- **Headshot:** q_shared.h:1426-1431. Never use m_iNumHeadShots, which counts in single-player only (weaputils.cpp:2921) [NV].
- **Streak:** level.cpp:899-950 wipes counters at restart [C].
- **Multikill:** synchronous delegate (player.cpp:3653).
- **First blood:** dm_manager.cpp:1588-1589; g_main.cpp:2180-2183; dm_manager.cpp:1645-1648 [NV].
- **Revenge:** keyed by client number because Player objects are recreated each round (level.cpp:899-917).
- **Assist:** ignore the post-kill damage event of the killing hit. The engine has no assist tracking; `assists` has no writer (g_local.h:105) [S]. Evidence: player.cpp:11603-11645; sentient.cpp:2034-2047.
- **Round win/loss/draw:** dm_manager.cpp:1441-1465, :1499; stock obj_team1.scr:116 [P].
- **Match end:** G_BeginIntermission2 notifies nothing (g_main.cpp:1948-1978; dm_manager.cpp:1224-1268, :1475-1477). SE_INTERMISSION is never triggered (scriptthread.cpp:7066-7068) [C]. The derivation breaks on admin map changes and votes.
- **Bomb plant/defuse/destroy:**
  - Stock logic is maintt/pak1.pk3 global/obj_dm.scr: plant :58-116 with parm.other at :67 and bombs_planted++ at :104; defuse :122-172; explode :208-265 with targets_destroyed+1 at :253 and a delayed decrement at :263-264.
  - The level vars are engine-backed (level.cpp:2261-2279) [NV].
  - The planter exists only as a script local.
  - Inline copies exist: maintt/pak3.pk3 maps/obj/mp_bizertefort_obj.scr:222-390 and maps/lib/mp_ship_lib.scr:571-736 [NV].
- **TOW capture:**
  - TOWObjective::TakeOver sets the tow_* cvars without player attribution (Tow_Entities.cpp:263-292; dm_manager.cpp:962-985) [NV].
  - Capturer gets `parm.other AddKills 2` on Berlin, Ardennes, Flughafen and Druckkammern (e.g. MP_Berlin_TOW.scr:192-228).
  - Ardennes and Flughafen also give `local.planter AddKills 5` for plants.
  - Kasserine, MonteBattaglia and MonteCassino give nothing [NV].
- **LIB rescue:** stock lib_dm.scr:95-110, :215, :415-436, :461-482; mp_anzio_lib.scr:88-133; injail getter player.cpp:926-936 [NV].
- **LIB capture:** lib_dm.scr:428-431, :474-477.
- **Playtime:** enterTime exists but no getter was found (g_client.cpp:1027).
- **Accuracy:**
  - Every engine shot and hit counter is single-player-gated (weaputils.cpp:1879-1892, :2029-2036, :2921-2923, :3194-3199, :3519-3525).
  - Player::Stats is single-player only (player.cpp:12270-12273).
  - getammo returns reserve ammo only (sentient.cpp:154-162) [NV].
- **Round start:** dm_manager.cpp:1560-1591; level.cpp:1500-1503 [NV].

### 6.2 Delegates, legacy events and level notifies

**Script delegates.** fgame declares exactly six (player.cpp:62-67) [NV]:
- player_connected: fires again after every restart, because a new Player object connects.
- player_disconnecting.
- player_spawned: every spawn and respawn.
- player_damaged: 11 args, self = victim.
- player_killed: 11 args; skipped when a killhandler is set.
- player_textMessage.

**Legacy registerev.** connected, kill, damage, disconnected and spawn are triggered. keypress, intermission, servercommand and changeteam are names only and never fire [NV].

**Level notifies:**
- prespawn (level.cpp:1241-1242)
- spawn (level.cpp:1526-1536)
- playerspawn (player.cpp:2634)
- roundstart (GT 3-6 only)
- allieswin, axiswin, draw (dm_manager.cpp:1448, :1456, :1461)

**Level vars script can read** (level.cpp): roundstarted, roundbased, objectivebased, dmrespawning, dmroundlimit, clockside, planting_team, targets_to_destroy, targets_destroyed, bombs_planted, ignoreclock, force_team_objective. No getter exists for team score, team win decided, or intermission [S].

### 6.3 Lifecycle facts that shape event design

- **Round transition chain.**
  1. TeamWin calls EndRound.
  2. EndRound posts DoRoundTransition after 2 s.
  3. DoRoundTransition notifies allieswin/axiswin/draw and posts FinishRoundTransition after 3 s.
  4. FinishRoundTransition sends `restart`, or starts intermission if the timelimit has expired (dm_manager.cpp:1404-1499, :1593-1599) [P].
  - Rounds decided through TeamWin skip the projectile wait (:1406-1411) [P].
- **FFA and TDM** have no roundstart and no win notifies. `level waittill roundstart` there hangs forever (g_main.cpp:2180-2183; dm_manager.cpp:1645-1648; stock mp_anzio_lib.scr:47-53) [NV].
- **Counters across rounds.** In round gametypes getdeaths accumulates across a map's rounds while getkills resets each round (player.cpp:2710-2728; dm_manager.cpp:269-275) [S].
- **Liberation, capture-and-hold and TOW wins** all go through `teamwin` and end in the same notifies (scriptthread.cpp:4349-4369; lib_cinematics.scr:18, :50; obj_capture.scr:117-124) [S].
- **Coop dependency.** Coop map m3l1b threads global/obj_dm.scr::bomb_thinker (maps/m3l1b.scr:2128-2129). Overriding obj_dm.scr would change coop, which breaks F, and would still miss the inline copies [NV LB].

### 6.4 Engine work candidates

All live in game.dll and must do nothing unless an MP script subscribes.

- **dm_intermission** delegate in G_BeginIntermission2 (g_main.cpp:1948), carrying the winning team and top player. Makes match wins reliable.
- **dm_teamwin** delegate in DM_Manager::TeamWin (dm_manager.cpp:1528), fired immediately. Lets script exclude kills in the 2 s gap.
- **tow_takeover** delegate in TOWObjective::TakeOver (Tow_Entities.cpp:263), carrying the team and parm.other.
- **Bomb plant/defuse** delegate or per-player counters.
- **MP shot/hit counters** plus a getter, or a weapon_fired delegate.
- **Optional getters:** pers.enterTime, team win decided.
- **Projectile firing weapon:** Projectile::weap already exists (weaputils.h:60). Exposing it would disambiguate grenades and launchers.

---

## 7. The coop challenge system as a template

### 7.1 Data model and lifecycle

**Rows.**
- A challenge is one `chal_def` call with 7 fields (id, cat, title, desc, stat, target, reward). They are stored in parallel level arrays, with a cid->index map and a stat->rows reverse index (challenges.scr:732-752) [NV].
- **No tiers.** Base and Elite are separate rows on one stat (wpn_garand 50 / wpn_garand_e 150 at challenges.scr:76-77) [P].
- **Variant targets** follow B*(3+k^1.3). If the tail exceeds CAP 750, the whole set is rescaled linearly onto [first, 750], then rounded to 25 with a floor of 25 (docs/tools/variant_challenges.py:66-82) [P].
- **Elite cids key the skin tables** (challenges.scr:1168-1173; loadoutpick.scr:1194-1198) [P].

**Catalogue.**
- 445 challenges = 368 in challenges.scr + 77 in mvchal_gen.scr, over 255 distinct stats [S].
- Categories: campaign 96, discovery 53, rifles 52, pistols 45, snipers 35, support_weapons 34, smgs 32, combat 30, axis 23, fireteam 22, vehicles 16, finishes 7.
- Rewards: 128 none, 123 player skins, 118 weapon tiks, 52 helmets, 15 perk_*, 7 finish_*, 2 glv_*.
- The gate prints "challenges: 445 | stat writers found: 188 | actor placements: 2830" (docs/tools/check_challenges.py:299) [M].

**Write path** (challenges.scr:1087-1185) [NV]:
1. `chal_bump`
2. `chal_ensure`
3. `chal_apply` for each row on the stat: skip if done; clamp to target; write flags coop_chalP_<cid>; at target set coop_chalD_<cid>.
4. `chal_grant`: add the unlock, queue a toast, save, auto-unpin, run the mv_ pseudo-unlock, run medal_checkAll, run loadout_ui_exportUnlocks.

**Unlock store.**
- One '|'-joined string, append-only and deduplicated, kept in session cvar coop_unlocks_<id> and file unlocks_<id>.dat. It also feeds a pending queue, a debrief list and padlock refreshes (challenges.scr:1215-1290).
- The gun gate has 4 free starters hard-coded (loadoutpick.scr:777-791) [NV].

**Two unlock truths** [C]:
- Guns, cosmetics and finishes read the unlock string.
- Model variants and finish mastery read coop_chalD_ flags, which are re-derived from progress on load (challenges.scr:849-857; loadoutpick.scr:1116-1199; helmet.scr:1756-1768).

**XP.**
- Only the total is stored. Rank is re-derived from 22 thresholds (0..500000), and rank unlocks are re-granted idempotently on every connect (xp.scr:229-273, :364-405, :1955-1971) [NV].

**Persistence.**
- Server-local only: a session cvar is read first, then coop_mod/save/<family>_<id>.dat.
- Progress is serialized as cid:progress pairs with zeros omitted. Autosave every 30 s for challenges and 60 s for XP (challenges.scr:816-968; xp.scr:318-325) [NV].

**The only kill writer is for AI victims.**
- aihandler.scr:1756-1760 calls chal_ai_killed, which returns unless victim.team is "german" (challenges.scr:1483-1622) [NV].
- A Player's .team stays "american" even on Axis (sentient.cpp:958, :5357-5366) [C].

**Anti-farm.**
- None for challenges.
- XP scales awards by 0.5 above 90x and 0.25 above 180x the coop_isActive player count (xp.scr:582-600, :633). The comment at :297-298 still says 40/80 and is stale [C].

**Medals** are derived from done flags (medals.scr:1-50) [S].

### 7.2 What must NOT be copied into a carried record

- **Clamping.** Clamping progress at the target discards kills above it (challenges.scr:1115-1125), so a retune can never be recomputed [NV LB]. Store raw, unclamped counters.
- **Re-deriving done flags.** Re-deriving "done" as progress >= the CURRENT target re-locks earned gear on a retune (challenges.scr:849-857; loadoutpick.scr:1149, :1185-1188). The 750 rescale makes each target depend on the gun's variant count (variant_challenges.py:78-82) [NV LB]. Hold unlocks as a latched set plus a derivation that may only grant (pending the user's yes).
- **Positional keys.** They already broke once: bug-1925 pins repointed when catalogue rows shifted. The fix was cid keys plus a crc32 generation stamp that WIPES caches (gen_service_record.py:1089); a wipe is unacceptable for a carried record [NV]. Use an append-only id registry and fail a build gate on reuse.
- **Coop's wid.** It is a gun family that crosses rifle and sniper (springfield 06+12, garand 01/11+15, enfield 05+17), and it maps kar98_mortar/kar98_lite -> kar98 [NV].
- **Class vocabularies disagree** (5.1). Store BOTH class counters and per-source counters as independent increments at kill time, with the class frozen at kill time. Never compute class totals from weapon counters: stock non-roster kit and emplacement kills have a class but no roster id (player.cpp:10901-10945) [NV LB].

### 7.3 Generated vs hand-written

**Generated (re-runnable into new MP files):**
- ui/coop_sr.urc, the 29 page textures, ui/coop_sr_pinclear.cfg, coop_sr_pinreset.cfg, coop_sr_cids.cfg and coop_mod/gen_sr_stamp.scr, from gen_service_record.py. It blocks the build (build.ps1:63-64).
  - Output paths, cvar names, the catspec category table and REWARD_NAMES are literals (gen_service_record.py:27, :482-522, :1051-1105) [NV].
  - It needs parameterising or forking; whether a parameterised copy leaves coop outputs byte-identical is untested.
- coop_mod/mvchal_gen.scr, from variant_challenges.py --emit (run by hand).
- coop_mod/unlockreq_gen.scr, from armory_unlocks.py --emit (run by hand).
- Cosmetic hover text lines, from gen_cos_reqs.py (run by hand).
- ui/loadout/req, p, t and lktab cfgs, from gen_loadout.py (run by hand). The requirement text is still hand-typed in the TSV.
- ui/loadout/reqmv*.cfg, from wire_mv2.py (run by hand). **Stale:** it names the Elite challenge although variants are now gated per variant (wire_mv2.py:151-156 vs loadoutpick.scr:1181-1192).
- **Audits in build.ps1:** unlock_audit (blocking), check_challenges --warn (non-blocking), check_mp_isolation (blocking).

**Hand-written (must be re-authored for MP):**
- challenges.scr's 368 rows, category tables, class tables, wid chain, faction rules, hooks, and toast/popup/menu/pin code.
- The xp.scr rank table.
- The free-starter list, duplicated in three places.
- TSV requirement text.
- The 188 stat-writer call sites.
- The medal table.
- The engine pin commands with hard-coded coop cvar names (client/cl_main.cpp:3718-4202).

### 7.4 Coop categories mapped to PvP

| Coop category | PvP fit | Notes |
|---|---|---|
| rifles, snipers, smgs, pistols, support_weapons | Direct | Per-weapon ladders |
| combat | Mostly | Kill milestones, headshot, melee, grenade, rocket, longshot, wallbang. The engine sets coop_wallbang on any damageable entity hit by a Player-owned bullet (weaputils.cpp:2926-2931), but it is a coop-named var, so reusing it is an isolation question. Coop-only: reinf, downedkill, savior, coverkill/coverown, blindfire. |
| fireteam | Weak | Needs new writers: assists, plant/defuse, round wins |
| vehicles | Partial | Only maps with vehicles |
| axis | Partial | Faction of the victim |
| campaign, discovery, finishes | None | Replace with match, gametype, streak and map-set challenges |

### 7.5 UI surfaces, costs, and MP push sizing

| Coop surface | Cost | Copy for MP? |
|---|---|---|
| Completion toast (HUD slots 76-78) | 4 s_sfxduck stufftexts plus 7-8 local sounds per toast (challenges.scr:2450-2595) | Pattern yes. Use slots >= 100 away from 150-174, because slots below 100 fade when the player is calm (xp.scr:524-531) [S] |
| Pinned progress popup (slots 84-87) | 1 playsound (challenges.scr:1980-2060) | Optional |
| In-game Service Record (slots 150-174, name bus index 34) | About 5 ihuddraw per row x 18 rows, redrawn every 0.5 s (challenges.scr:2663-2800) | Connected-only panel needs no engine work |
| Offline Service Record | 3 archived cvars per row (about 1,780 total), a first export of up to 1,335 reliable commands (paced), and 29 baked 2048x2048 page textures = 486,540,540 bytes | No: MAX_CVARS pressure and asset size [NV] |
| Pins HUD | Up to 16 stufftexts per player every 3 s, not diff-gated (challenges.scr:3367-3432) | No |
| Gun padlocks | 2 archived cvars per gun, diff-only, a waitframe every 8 (loadoutpick.scr:686-775) | Adapt, see below |
| Cosmetic padlocks | 1 archived cvar per page (helmet.scr:1441-1480; gloves.scr:180-200, unpaced) | Adapt |
| Requirement hover text | 0 server commands: static cfg exec'd on hover (ui/coop_loadout.urc:726-727) | Yes |
| Lobby unlock list, mission debrief, XP HUD | coop lobby / missioncomplete only | No |

**MP push sizing, if coop's recipe is copied 1:1** [NV]:
- 148 commands for guns; 700 for 350 per-gun finish variants x2 (the 77 model variants are not included); 135 skins; 47 headgear; 6 gloves; about 106 Axis cosmetics.
- About 1,140 stufftexts, roughly 7 s at 8 per waitframe and sv_fps 20 (sv_init.c:1137).
- Paced, the reliable queue is not the binding limit. An unpaced join burst would hit 1,025 and drop the client.
- **The binding limit is MAX_CVARS.** Archiving about 1,200 new cvars would re-create them in coop sessions too, which breaks F.

**Compressed recipe** [NV]:
- Session `set`, never `seta`.
- Push once per map, after verification, and only for the armory of the joined team.
- One mask cvar per gun whose value execs one of 128 generated cfgs under ui/coop_mp*.
- Result: about 300-450 commands, about 600 session cvars, 0 archived.

**Constraints on MP UI names.**
- A widget's enabled state reads exactly one cvar (uilib/uiwidget.cpp:1695-1742), so each independent lock needs its own cvar [C].
- MP display cvars must start with coop_ to be server-settable, but use a prefix no coop regex matches. MP cfgs must live under ui/coop_* or coop_mod/ (filter :346-349).
- This does not conflict with keeping the RECORD outside coop_*: display state is disposable.

**Packed stufftexts.** About 50 ';'-joined setas in one command of about 1,900 bytes would cut the push to about 21 commands. Live code already sends multi-statement stufftexts (mp.scr:198; player.scr:827), which contradicts TRAPS T8 (docs/TRAPS.md:427-429). Test it.

### 7.6 Isolation

**Current gate gaps** [C unless noted]:
- Clause 10's call scan and its coop_lo stufftext scan read only coop_mod/mp.scr. Only the coop_mpFreeKit sub-check walks coop_mod (check_mp_isolation.py:282-305).
- Clause 7's regex covers only coop_mpa<digit>, coop_mpx<digit>, FreeKit and LockLoadout; its allowlist is mp.scr and loadoutpick.scr; it walks only .scr files under coop_mod (:220-241).
- Clauses 4 and 5 use the fixed MP_FILES list (:180).
- check_challenges.py's WRITER_RE scans every .scr (:96-108). An MP copy of the coop verbs and stat names would make a dead coop challenge look wired [NV LB].
- chal_bump, chal_team_bump, cc_award_clean, chal_add_unlock and xp_award have no MP guard. The only guards are at challenges.scr:701 and :867 and xp.scr:309. Meanwhile mp.scr sets coop_isActive=1 on every MP spawn [NV LB].

**Couplings that already exist** (user decides: allowlist or remove):
- g_statefile coop_mod/player, which runs events.scr playerdeath and player.scr::manageDead, including lmsForceSpectatorHandle and startMapCallback (player.scr:1620, :1642).
- player.scr::playerCleanName and ::coop_limpWarn; main.scr::containsText; the ads, painbreath and tinnitus monitors.
- The dm_playermodel leak.
- The MP options button that opens the coop armory.

**Clauses to add.** Consolidated from all reports. "MP_GLOB" = every MP-owned file (e.g. coop_mod/mp*.scr and ui/coop_mp*):

11. Enumerate MP files by glob, not assumption. Run clauses 2, 4/5, 7, 9 and 10 over all of MP_GLOB, including files outside coop_mod.
12. MP_GLOB may not reference coop_mod/(challenges|xp|medals|loadoutpick|loadoutskins|helmet|gloves|lobby|lobbyui|unlockreq_gen|mvchal_gen|gen_sr_stamp).scr, nor events.scr or eventsystem.scr.
13. Reverse direction: no coop file (coop_mod, maps, global) references MP file names, MP verbs, the MP event or MP prefixes.
14. Save-store separation. MP_GLOB may not name coop_mod/save/(chal|unlocks|pins|pend|medals|xp)_ or get/set coop_(chal|unlocks|pins|pend|medals|xp)_. Coop may not name the MP save or session prefixes.
15. Client-cvar separation. MP may not name coop_ui[BNDPM], coop_sr, coop_pin, coop_cp<n>, coop_lo, coop_pintoggle or coop_srsync. Widen clause 7 to the new MP prefixes.
16. Flag separation. MP may not index flags coop_chal*, coop_pin*, coop_xp_*, coop_medal*, coop_unlockPend or coop_mapUnlock*. Coop may not index MP flags.
17. Writer-name separation. MP may not define or call chal_bump, chal_team_bump, cc_award_clean, chal_quiet_feat, chal_def or chal_add_unlock. check_challenges.py must exclude MP_GLOB.
18. Runtime guard. chal_bump, chal_team_bump, cc_award_clean, chal_add_unlock and xp_award each start with a coop_mpRun early return. This touches coop files, so it needs the user's approval under F.
19. Generator output separation. MP generator runs leave the coop SR, requirement and variant outputs byte-identical to HEAD.
20. The engine pin path stays coop-only: MP may not stuff the pin commands or read userinfo coop_pin1..5.
21. The coop profile channel stays coop-only: MP may not reference coopprof, coop_profdata or coop_pf*.
22. No MP file sets killhandler.
23. Character gear. MP may not mention dm_playermodel, dm_playergermanmodel, coop_loSkin, coop_loChar, coop_armorySkin, coop_helmetIdx or coop_gloveIdx, may not exec ui/loadout/*, and may not push coop_loadout.
24. Bot cvars. No shipped mod file sets sv_maxbots, sv_sharedbots, sv_numbots, sv_minPlayers or bot_manualmove.
25. New engine command names may appear only in the designated shim .scr.

---

## 8. Bots

### 8.1 Facts

**Build and enablement.**
- Engine bots are compiled into game.dll (fgame.vcxproj:617, :675-679), and the deployed DLL contains "isBot" and "bot_manualmove" [M].
- Enabled by server cvars: sv_maxbots (default 0, LATCH; nothing spawns unless it is set before map load), sv_sharedbots, sv_numbots, sv_minPlayers (counts humans only), bot_manualmove (flags 0; 1 freezes all bots) (gamecvars.cpp:675-678; g_bot.cpp:643-661, :762-804; playerbot.cpp:102, :128-131) [S/NV].
- addbot and removebot are server console, rcon or cfg only in MP (gamecmds.cpp:209-210, :271-275, :328-330) [NV LB].

**Coop exposure.**
- No bots in single-player, but coop runs g_gametype 2, so the bot machinery is live on coop maps (g_bot.cpp:624, :768-771) [NV LB].
- The mod has never used engine bots. The harness "bots" are real clients driven by coop_botInput (launch_dedicated_2player.ps1:157-160; player.cpp:5563, :5676-5687) [S]. The CoopBotDrive gate is not SVF_BOT-aware.

**What a bot is.**
- A real Player: `new Player`, targetname "player", so it appears in `$player` and runs through mp.scr's poll (g_bot.cpp:156-169; player.cpp:2508; mp.scr:112-113) [C].
- It goes through the same Killed and delegate path as a human; kills on bots score (player.cpp:2009, :3563-3565) [C].

**Identity.**
- Userinfo exists only in game memory: name bot<N>, fov 80, ip localhost, no cl_guid.
- botId resets every level, so names repeat and a human can take one (g_bot.cpp:449-468, :709-714) [NV].
- The only reliable test is `isBot` (SVF_BOT, set at g_client.cpp:852) [C].
- These do NOT work: NA_BOT (never assigned), ip "localhost" (also the listen host, sv_client.c:443-444), netname, entnum (G_BotShift can renumber a bot, g_bot.cpp:264-321), coop_guid [NV].

**Across map changes.**
- G_RestartBots and G_RestoreBots re-add bots (g_main.cpp:1066, :522; g_bot.cpp:573-634) [NV].
- The engine's differentmap branch SV_DropClient's bot client slots in MP gametypes (sv_init.c:899-925) [P].
- The Player entity and gclient are rebuilt either way (g_client.cpp:857).

**Self-deployment.** Every frame, UpdateBotStates sends `primarydmweapon auto`, auto-joins a team and toggles fire to respawn (playerbot.cpp:133-166; player.cpp:11429-11445) [NV LB]. Class and model re-roll on every death (playerbot.cpp:1221-1261) [S].

**Server commands to a bot are dropped:** stufftext network send, pushmenu, centerprint (sv_game.c:1358-1362, :1521-1550; sv_main.c:163-187) [NV].

**But stufftext on a bot EXECUTES locally.**
- Player::EventStuffText calls delegate_stufftext. The BotController parses the first token and, if it is an EV_CONSOLE event, runs ProcessEvent server-side (player.cpp:12372-12384; playerbot.cpp:279-330, :1288-1303) [NV LB].
- 51 such events exist, including kill, join_team, primarydmweapon, spectator, use, give, health and coopprof.
- Non-event text (s_volume, s_sfxduck, set) returns without freeing the parse buffer, a leak (playerbot.cpp:288, :300-302). mp.scr:252-253 and tinnitus.scr:41 already do this on bots [NV].

**Class bans.** A dmflags "ban all classes" scheme is reverted server-wide when anyone joins a team with an empty dm_primary (player.cpp:18469-18476) [NV LB].

**Display.** huddraw to a bot is in bounds (sv_game.c:96-97, :408-415) [S]. The scoreboard shows "bot" instead of ping (dm_manager.cpp:1995) [S].

### 8.2 Rules for the flow

- **Classify with `isBot` at the moment of use.** Never cache across maps; never classify by netname, entnum, ip or guid.
- **No client pipeline for bots:** no stufftext, cvar pushes, exec, menus, toasts, profile import or export, or padlocks. Add an isBot early-out before the client-only parts of mp_deploy, mp_onSpawn, mp_cleanName and the stufftext monitors. Keep server work such as health 100.
- **No gate may wait on a client commit.** Bots never send one. Never use a dmflags ban-all scheme.
- **Kit:** the engine stock nationality kit, or a fixed server starter kit re-applied after every spawn, because bots re-roll per life. Never a progression-gated kit.
- **Dressing:** bots already wear coop-gated skins. Dress them from the MP free tier, or leave them (decision 9a-16).

### 8.3 Rules for progress

- **Bots get no record:** no id derivation, no file, no cvar, no ledger, no "n_"+netname fallback.
- **Credit** when the attacker is a human Player (`isBot` = 0), attacker != victim, MOD != 4, and dmteams differ in team gametypes. The victim may be a bot (E).
- **A bot attacker earns nothing** for anyone.
- **Farming defeats portable progress.** A self-hoster can run `sv_maxbots 8; addbot 8; bot_manualmove 1` and collect server-attested kills. A policy is required (9a-15): caps, weighting, zero credit while bot_manualmove or sv_cheats is on, or requiring a second human.
- **The mod must never ship bot cvars** (clause 24). Bots are the operator's choice, and they persist into coop maps.

---

## 9. Open questions

### 9(a) User decisions

- **Latched vs re-derived unlocks?** Recommended: latched set + grant-only derivation. Decides whether a later retune can silently re-lock gear.
- **On a class-map change, do past kills stay in their ladder?** Freezing class at kill time says yes.
- **Is the free starter gun per class a table policy or latched into the record?** Changes how a later starter change behaves; also decides whether a stock/unverified client spawns armed.
- **MP class vocabulary?** Engine's 7, the armory's tabs, or a new set with shotgun split out. Keying class counters by token makes the format indifferent.
- **Shotgun (44) on both armories** conflicts with the current one-target roster split; tile 44 needs a second target.
- **Does voice nationality have to match the worn MP skin?** If yes, `model` is not enough and the nationality callers need an engine override.
- **Drop Japanese from Axis cosmetics** (no models exist), or source/commission new models?
- **Does progress earned on listen servers count equally, or is it tagged and refusable by dedicated operators?**
- **Is a trusted-issuer tier wanted later**, given its key-management cost?
- **If import verification fails, are session kills written into the carried record (laundering risk) or discarded?**
- **Is a homepath-root file, written by new exe code, acceptable?** It is the only store meeting D on never-visited servers.
- **Is it acceptable that a hostile server can erase (not forge) progress**, or must the trampoline be closed engine-wide (ships openmohaa.exe to everyone)?
- **Two people on one Windows account** share one qkey/guid; separating them needs a per-person homepath. Wanted?
- **Offline (disconnected) MP Service Record?** If yes it needs client-held state (hurts MAX_CVARS) or a cgame decoder; if no, session `set` in-server suffices.
- **Should bots be dressed from the roster's free tier, or left on random picks?**

### 9(b) Playtests (cheapest test named)

- **PvP damage really zero today?** Listen TDM, addbot, shoot it; watch health and the obituary. ~3 min. (Gate on everything.)
- **Which engine gate restores PvP without touching coop?** Grep main.scr::forceValidTeam + a 2-player coop playtest to confirm coop never puts a player on axis or runs FFA.
- **Does event_subscribe deliver the 11 args with an unquoted label, self=victim, for bot and human?** Stub label, dedicated MP boot, one bot. Settles P1/P2.
- **Does the vstr bridge deliver coopprof end-to-end from a remote client on a dedicated server?** seta coop_mpq0 + vstr coop_mpq0; repeat at 300 chars for the 255 cut; repeat with sv_floodProtect 1 at 200 ms.
- **Does the zero-binary carrier work end-to-end?** Modify the profile.scr probe to seta+vstr and read coop_profdata.
- **Does a cgame-owned store survive, and does a trampolined writeconfig clobber it?** Prototype a CG_ServerCommand branch; confirm (a) direct stufftext dropped, (b) seta/vstr of the MP name dropped, (c) `seta coop_t writeconfig hzm_mp/prog.dat` + vstr clobbers the file.
- **Does md5string return identical output twice inside the real game.dll?** println md5string "abc" twice; correct is 900150983cd24fb0d6963f7d28e17f72.
- **Is `info_valueforkey local.player.userinfo "..."` live?** One println on any map.
- **Are script dictionary string keys case-sensitive at runtime?** level.t["ABC"]=1; println level.t["abc"].
- **Does getactiveweap 0 return NULL/turret/holstered on a turret or vehicle kill?** println on an MG42-nest kill.
- **Does player_spawned re-model land in the spawn frame with no InitModel skin visible?** Subscribe a label that runs `self model ...`, record a demo, step frames.
- **Do script `wait` timers freeze during FFA/TDM intermission?** fraglimit 1, println level.time every 0.5 s, look for the ~15 s gap.
- **Userinfo echo latency and survival across restart/map change.** stuff a userinfo key, poll info_valueforkey, then restart and map.
- **Does a seta queued at teamwin cross the round restart?** stuff seta in the teamwin frame, read the cvar in round 2.
- **Realistic kill-rate caps for human and bot play?** Count `^~^~^` kill lines per player per minute in a bot-filled Team Match log.
- **Do bots move and fight on stock MP maps with this fork's navmesh?** Dedicated boot with sv_maxbots, watch 60 s.
- **What share of real players have an empty cl_guid?** Grep the XP id logs for n_-prefixed ids.
- **Real userinfo occupancy on a remote client?** `dumpuser <n>` with a long name and 5 pins set.
- **Live client cvar-table headroom?** `cvarlist` count against 8192 (warning at 6554).

### 9(c) More research

- **Which engine gate in Sentient::ArmorDamage restores PvP without re-enabling coop friendly fire?** (Two Players on different DM teams as different teams, or FFA, or g_teamdamage.) The candidate must be gated so it is provably inert in coop.
- **GameSpy gcd auth: does it hand game.dll any verified per-player value?** Read AuthenticateCallback / challenge_t.
- **Does FS_FOpenFileWrite reject '..' like the read paths?** Matters if a server ledger is keyed by client-supplied guid.
- **Does CRT rename() fail when the target exists on this MSVC build?** Decides MoveFileExA vs remove-then-rename.
- **Landmine (29) and aagun (28) attribution on TT/TA maps** was not traced.
- **Does the coop DBNO/bleed-out machinery intercept a lethal MP hit before EV_Killed?** A kill in MP with the stub while watching for a DBNO state.
- **HMAC choice: SHA-256 (vendor ~200 lines) or MD5 (fix md5.h:65)?** Both sound as MACs; a maintenance call.
- **Does a packed multi-statement stufftext (~50 setas, under 2048 bytes) land intact** despite TRAPS T8's one-statement guidance? Would cut the padlock push from ~1,143 to ~21 commands.
- **Do the stock Axis/Italian bodies expose a separable baked-helmet surface** for a nodraw approach to Axis headgear?

---

## 10. Candidate progression architectures

Three genuinely different designs. Do not pick one. All three share: the player_killed feed (section 4), server-side attribution from a generated table (section 5), stored counters with grant-only derivation (7.2), the isolation clauses (7.6), and the engine PvP-filter prerequisite. They differ in the carry-your-own-progress layer.

### Architecture A: userinfo-carried signed blob (no server file, no exe change beyond registration)

- **Storage:** the record body lives in the client's archived config as a handful of registered coop_mp* cvars; a compact signed summary (seq + digest, or the whole small record) rides one or two registered CVAR_USERINFO|CVAR_ARCHIVE keys.
- **C->S:** userinfo, automatic at connect, present at spawn, flood-exempt. Body upload (if the record exceeds userinfo's ~800 free bytes) via a chunked MP EV_CONSOLE event.
- **S->C:** the server writes back the updated body via CG_ServerCommand (or archived coop_mp* setas), monotone merge.
- **Signing:** HMAC in a game.dll builtin, key bound to guid.
- **Size:** the userinfo summary must stay well under ~570 bytes (worst-case ~793 free). The full record (391-571 core) lives in the config.
- **Honours A-G:** A/C/E/G via the shared feed and table. B by empty first record. D partially: it travels and it is present at spawn with no round trip, but the config store is exposed to all nine loss paths and to any server's stufftext, and userinfo is capped at 1350 shared bytes.
- **Pros:** lowest new-code (registration + game.dll builtin); connect-time delivery; no new file format on disk.
- **Cons:** config store is fragile and server-overwritable; userinfo space is tight and overflow silently drops keys (including protocol at connect); a large record still needs the chunked event.

### Architecture B: homepath-root file with server MAC (recommended for D)

- **Storage:** the record is its own file at the homepath root next to qkey, written atomically by new openmohaa.exe code (write .tmp, _commit, MoveFileEx/ReplaceFile, keep .bak, read-merge-write).
- **C->S:** a chunked MP EV_CONSOLE event uploads the body; a userinfo key carries only the seq+digest ack.
- **S->C:** CG_ServerCommand write-back, monotone merge; the exe persists it to the root file.
- **Signing:** HMAC in game.dll, key bound to guid; a per-guid high-water ledger on the server under an MP-only save prefix rejects rollback on visited servers.
- **Size:** unconstrained on disk; the transport still chunks at 250 bytes (5 KB worst case = 20 chunks).
- **Honours A-G:** A/C/E/G shared. B empty. D best: survives reinstall, target switch, cvar_restart and crash; not overwritable by a hostile server's stufftext (the file is not a coop_ cvar); erasable only via the trampoline writeconfig, mitigated by .bak.
- **Pros:** the only store that meets D on never-visited servers and across installer/target/crash; clean isolation.
- **Cons:** requires openmohaa.exe changes (file I/O + atomic replace) plus cgame.dll and game.dll; stock/older-exe clients carry nothing.

### Architecture C: coopprof-style upload with server as high-water authority (thin client)

- **Storage:** the client holds the record only as archived coop_mp* cvars (a mirror). The authority is a per-guid server file plus a session cvar, exactly like coop's unlocks.
- **C->S:** the client uploads its mirror via the chunked MP event on connect; the server keeps the max of client and its own high-water.
- **S->C:** the server pushes the merged record back as archived setas (the chal_ui_export precedent) so the mirror refreshes.
- **Signing:** HMAC over the uploaded body; the server never lowers a counter.
- **Size:** same chunk math; the mirror obeys the 1014-byte per-cvar cap, so split across a few cvars.
- **Honours A-G:** A/C/E/G shared. B empty. D partially: progress travels only to servers that keep a ledger; a brand-new server that has never seen the guid trusts the signed upload, but the mirror is exposed to the same cvar loss paths and to overwrite.
- **Pros:** closest to a proven coop pattern; no new file format; the server-side ledger naturally rejects rollback and replay within a server's lifetime.
- **Cons:** "travels everywhere" depends on the visited server keeping state; the client mirror is fragile; MAX_CVARS pressure if the mirror is large; the coopprof round trip is itself unproven.

**Cross-cutting note for all three:** stock OpenMOHAA clients (no HZM cgame) carry nothing and must degrade to the free starter kit per class; the engine PvP filter, the generated attribution table, and the isolation clauses are prerequisites regardless of which carry-your-own-progress layer is chosen.
