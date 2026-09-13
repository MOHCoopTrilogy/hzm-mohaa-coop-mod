> Generated 2026-09-13 by the mp-armories-understand workflow (34 agents: 10 readers, 10 adversarial verifiers, a critic, 6 gap readers + verifiers, synthesis). Research only. Decisions 4 and 5 in its brief (Allied enforcing coop unlocks, Axis fully unlocked) were superseded the same day by MP-only progression - see the header of mp_loadout_plan_v1.md. The synthesis was emitted in two parts; this file joins both.

# MP Allied and MP Axis Armories: Verified Understanding Map

This map was synthesised on 2026-09-13 from nine subsystem research passes and six gap passes. Nothing in the repo was modified.

**Conventions**
- **Where paths point.**
  - Paths starting coop_mod/, ui/, models/, global/, maps/, scripts/, textures/, autoexec.cfg or _research/ are under hzm-mohaa-coop-mod/.
  - Paths starting code/ are under openmohaa-hzm/.
  - docs/, build.ps1, publish_release.ps1, installer/ and manifests/ are at the repo root C:\mohaa-coop-dev.
  - Pak citations use the form `<dir>/<pak>.pk3:<inner path>[:line]`, under the GOG install. Wherever the live G:\mohaa-gl2 paks were compared, they were byte-identical.
- **Tags.**
  - **[NV]** marks a load-bearing fact that one research pass cited but no verifier re-checked.
  - **[UNTESTED]** marks behaviour never observed in a running game.
  - "Corrected:" means a verifier changed the original claim. Only the corrected form appears here.

---

## 1. Executive summary

### 1.1 Corrections that change the starting picture

1. **Weapon table size.** docs/tools/loadout_weapons.tsv has 89 lines: 14 comment lines, a header at :15, and 74 data rows at :16-89.
   - The ids are 01-72, 74 and 75. Id 73 is a permanent hole (docs/OPEN.md:178-180).
   - The rows match the 74 tiles in ui/coop_loadout.urc and `level.coop_loRosterN = 74` (coop_mod/loadoutroster.scr:609).
   - The brief's "88 data rows" is wrong.
2. **Nation split.** No data file has a nation column. Classified by weapon:
   - Allied: 42 including the shotgun (US 22, UK 10, USSR 10).
   - Axis: 32 (German 20, Italian 8, Japanese 4), or 33 with the shotgun.
   - The old plan's 42/32 was correct with the shotgun counted as Allied only. Only the "shotgun on both sides" decision changed the numbers (_research/mp_loadout_plan_v1.md:104).
3. **The stock weapon picker is only partly suppressed.**
   - ui/coop_weaponselect_suppress.urc defines five empty menus. The layout parser stops at the first `end.`, at line 47 (code/uilib/uilayout.cpp:109-113).
   - So only the American "SelectPrimaryWeapon" becomes an empty shell. It wins through pak order plus keep-first dedup (code/uilib/uiwinman.cpp:640-658). The live log shows exactly one duplicate drop (G:\mohaa-gl2\home\maintt\qconsole.log:4740).
   - British, Russian, German and Italian players get the full stock picker. Its buttons send `primarydmweapon <class>;popmenu 0`, which deploys them (maintt/pak1.pk3:ui/dm_primaryselect_german.urc:55-152).
4. **ui/mploadout/ cannot work.**
   - The cgame filter lets a server `exec` only paths starting ui/loadout/, ui/coop_ or coop_mod/ (code/cgame/cg_servercmds_filter.cpp:337-349).
   - One disallowed statement drops the whole stufftext (code/cgame/cg_servercmds.c:465-482).
   - The plan body still uses ui/mploadout/ (_research/mp_loadout_plan_v1.md:123, 141, 148, 166, 169, 187, 189, 191), although its own header at :20 says ui/coop_*.
5. **The unlock decisions may already be superseded.**
   - _research/mp_loadout_plan_v1.md:23-39, marked "later on 2026-09-13", records that decision 4 (coop unlocks ENFORCED for Allies) and decision 5 (everything unlocked for Axis) are both OUT.
   - It replaces them with: MP-only progression for all gear, starting over, per-class kills counted across both teams, client-carried progress with a tamper check, and bot kills counting.
   - This is an uncommitted 18-line working-copy edit, timestamped 12:41, after mp.scr (11:42). It appears in no other file and in no transcript index [NV provenance].
   - The docs/DECISIONS.md:542-551 working copy still says Axis weapons keep their challenge unlocks.
   - The user must say which record stands before anyone designs a lock layer.
6. **HRRTM ships.**
   - manifests/manifest-1.5.3.json:175-229 distributes all six zzzzzz-HRRTM paks with no optional flag. installer/hzm_coop.iss:85-89 and publish_release.ps1:131-134 package them.
   - docs/tools/gen_glove_views.py:46-50 and docs/TRAPS.md:321 say the opposite.
7. **The gates are weaker than they claim.**
   - Isolation clause 6 compares the working tree to the index, not to HEAD, under core.autocrlf=true (docs/tools/check_mp_isolation.py:209-216).
   - Clause 10's call regex reads only mp.scr (:286).
   - The whole gate runs after the pk3s and DLLs are deployed, and is silently skipped if the tool file is missing (build.ps1:355-373) [NV].
8. **The coop generators are not safe to run.**
   - `gen_loadout.py check` already exits 1: 11 coop p-pages have drifted from MV_HOSTS. A build would rewrite those pages and loadoutroster.scr.
   - `gen_skins.py build` renumbers all 350 finish tiks.
   - `gen_glove_ui.py --write` downgrades the glove pages and moves rows in the coop urc.
9. **The armory preview can show gloves.** This refutes an earlier claim. code/client/cl_invrender.cpp:318-331 writes coop_loGlove onto the preview model's `hand` surface. The cvar name is hard-coded.
10. **The coop skin ring is not Allied-only.** s126 "Colonel Hildebrandt" is a German officer body (models/player/hildebrandt_nohat.tik uses german_officer.skd). s129 "Claus" is a French-resistance body.
11. **The deployed mp.scr has never been played.** The only MP log run (mohdm7, 10:59) used the bug-2564 build. Its Script Error cites mp.scr line 297 (qconsole.log:27751-27753), but the current file is only about 285 lines.

### 1.2 What already exists and can be reused

- **Screen recipe.** The tile, padlock, tab, slot-card, finish-strip, inspect-panel and charRender widgets of ui/coop_loadout.urc, with their geometry. Use them as a template to copy. Never edit the coop file itself (clause 6).
- **Client plumbing.**
  - The cgame filter already passes `exec ui/coop_*` and set/seta/vstr on coop_* cvars (cg_servercmds_filter.cpp:173-175, 346-348, 350-363).
  - Name-bus transport via `append name` already works.
  - Pure string helpers exist: main.scr::containsText, player.scr::playerExtract and player.scr::playerCleanName. mp.scr already calls two of them (mp.scr:131, 276).
- **MP entry.** The global/ambient.scr:34-36 hook, the team-flip and spawn-edge polls in mp.scr, health 100 per player (mp.scr:229), and the dmflags unlatch (mp.scr:84-88).
- **Weapons.**
  - All 74 roster tiks, 350 finish tiks over 50 bases, and 77 model-variant tiks.
  - The "Base (Finish)" display-name convention, which makes cgame use the base gun's hands and ADS (code/cgame/cg_modelanim.c:1330-1349).
  - The emitters in docs/tools/gen_skins.py, usable as a library.
- **Headgear.** 45 exact-fit pieces in models/coop_helmets/ (20 of Axis origin, 2 glasses), plus the zero-offset `attachmodel ... "Bip01 Head"` recipe (coop_mod/helmet.scr:398, 469).
- **Allied bodies.** 135 `<skin>_nohat.tik` bodies carrying glove shader lists (docs/tools/gen_gloves.py), and 7 glove looks.
- **Axis bodies.** The hatless line-deletion recipe in _research/nohat/nohat_build.py applies to every Axis body once it is parameterised [NV].
- **Engine.**
  - The two-attach preview widget and the glove-bit write path.
  - The `isBot` builtin (code/fgame/scriptthread.cpp:2066-2074, 7364-7381) and the `md5string` builtin (:2002-2010).
  - The `coopprof` client event (code/fgame/player.cpp:7529-7567).

### 1.3 What must be built new

- **Screens and plumbing.**
  - One or two MP armory .urc files with unique menu names, placed at the top level of ui/.
  - MP cfg trees under ui/coop_<mp>/.
  - MP cvar families: coop_ prefix, never coop_lo*.
  - An MP token vocabulary and an MP-owned dispatcher.
- **Data.**
  - MP roster tables carrying side, engine class and single-primary slot legality. Never add rows to loadout_weapons.tsv or loadoutroster.scr.
  - An MP finish and variant table. loadoutskins.scr is forbidden by clause 10.
- **Flow.**
  - The MP give path: takeall, then `item`, explicit ammo, `use`, and health.
  - The weapon-select replacement: all five picker names made effective, or an fgame redirect.
  - Push, hold and fallback logic; fixes for maps that never run mp.scr; a bot branch.
- **Allied locks.** A lock source matching whichever policy the user picks.
- **Axis content.**
  - Hatless german_*/it_* body tiks with _fps twins and glove lists, plus Standard Issue headgear tiks.
  - An Axis glove roster.
  - The missing Axis finishes, made by an MP-only generator.
- **Engine.**
  - An Axis glove cvar read in cgame.
  - Per-widget glove and helmet preview cvars in client/uilib.
  - Optionally, a re-entry redirect in fgame.
- **Art and gates.** Background art with three slot seats and MP wording; new isolation clauses; the isolation gate moved before packing.

### 1.4 The three biggest risks

1. **Coop contamination through surfaces no current gate watches.**
   - The picker menu names load for coop too (code/client/cl_ui.cpp:5633-5645), and coop itself triggers those pushes (coop_mod/main.scr:426-435, 460-466).
   - F7 and ESC -> Multiplayer Options already open the COOP armory in MP and write archived coop_lo* picks (autoexec.cfg:1378; ui/multiplayeroptions.urc:174; ui/loadout/w01_s1.cfg:3-8).
   - Generator runs change coop output: a gen_loadout build rewrites 11 p-pages; `<stem>_<finish>.tik` naming adds 18 p-page diffs and 126 new finp cfgs; a gen_skins build renumbers 350 ranks.
   - Every mod grenade base txt execs coop itemhandler.scr.
   - dm_playermodel is a single archived cvar shared with coop.
   - Clauses 6, 7 and 10 see almost none of this.
2. **Stranding players in spectate.** Holding players with no class until they press DONE, while the picker shells are empty, parks them wherever the armory never arrives:
   - ESC sends no token (code/client/cl_keys.cpp:1207-1236).
   - Clients with a stock cgame drop the exec.
   - Pushes are silently lost inside the menu lock (code/uilib/uimenu.cpp:519-533, 599-601).
   - Two stock maps never reach mp.scr and already strand mod clients today [NV, UNTESTED].
   - In round modes a late deploy becomes a temporary spectator.
   - Remote idlers are kicked after 900 s even while spectating (code/fgame/player.cpp:5422-5428) [NV].
3. **The Allied unlock requirement cannot be built as stated, and the policy itself is unsettled.**
   - The unlock data exists only on servers that hosted the player's coop, keyed by an unauthenticated guid that often differs per server.
   - Every existing reader writes coop state.
   - Client-held copies are forgeable and exceed the only transport's size cap.
   - Finishes need a second record.
   - The TRENCH GUN's only unlock is an AI-only Axis challenge.
   - A later record says the user dropped this requirement anyway.

Other serious risks:
- Hard-coded preview cvar names (coop_loGlove, coop_loHelmOnChar, and others) would be shared by any second preview.
- No hatless or glove-capable Axis tik exists yet, and the live disguise body is the HRRTM copy.
- New german_/IT_/SC_ tiks automatically join the bot model pool.

---

## 2. Requirements trace

### Decision 1: a new loadout menu replaces the weapon selector after team pick. Allied mirrors coop; Axis is new and MP-only.

- **What it means technically.**
  - After `join_team`, Player::Join_DM_Team calls UserSelectWeapon when dm_primary is empty (code/fgame/player.cpp:11406-11407).
  - On protocol 15 or higher (Breakthrough is 17), that stuffs `[wait 250;]pushmenu SelectPrimaryWeapon[_british|_russian|_german|_italian]`, chosen by the model's nationality (:18440-18497).
  - "Replace" therefore means: no stock picker is ever usable in MP, and the armory for the player's side opens instead, chosen by dmteam. FFA players are also on allies or axis (code/fgame/dm_manager.cpp:1802-1821) [NV].
- **Feasibility.** Yes, by either of two mechanisms:
  - (a) Make all five picker names effective empty shells, and push the armory from mp.scr on the team-flip edge.
  - (b) Redirect UserSelectWeapon in game.dll behind a per-map, MP-only flag. That single choke point also covers team switches, the fire-click re-prompt, ESC -> Select Weapon and the P key.
- **Conflicts.**
  - All shells load for every session (cl_ui.cpp:5633-5645). Coop players with British or Russian models hit those names during coop's own empty-class windows (coop_mod/main.scr:426-435, 460-466), and coop calls `pickweapon` itself (main.scr:434).
  - mp.scr's header says it touches no urc and leaves the stock picker alone (mp.scr:27-29).
  - Two stock maps and 25 mod-owned MP maps never run mp.scr (section 5.11).
- **Cost.** Medium. Higher if the fgame redirect is chosen, because that is a server binary.

### Decision 2: no impact on coop

- **What it means technically.** Every new artefact needs names coop never reads, and every shared surface must be provably unchanged. The shared surfaces are:
  - menu names and the SelectPrimaryWeapon* shells
  - the F7 and mpoptions routes
  - name-bus prefixes
  - dm_playermodel, coop_gloveIdx, and coop_lo* cvars
  - ui/loadout/**, loadoutroster.scr, loadout_weapons.tsv, loadoutskins*.scr and coop_skins.shader
  - `<stem>_<finish>.tik` names in models/weapons
  - the disguise tiks, the bot model pool, and the grenade base txt files
- **Feasibility.** Yes, but not with today's gates:
  - Clause 6 misses staged, committed and line-ending-only edits.
  - Nothing guards ui/loadout/** or the armory scripts.
  - Clause 7 misses non-digit MP names and still exempts loadoutpick.scr.
  - Clause 10 reads only mp.scr.
  - The gate runs after deploy (section 6).
- **Conflicts.**
  - Plan step 1, deleting the extra `end.` lines (_research/mp_loadout_plan_v1.md:179), edits a URC that coop also loads.
  - gen_loadout.py is already failing, so "coop output unchanged" has to be proven against a frozen baseline (604 identical pages plus the 11 drifted ones), not against a passing check.
- **Cost.** Medium: a checker rewrite and baselines, plus ongoing discipline.

### Decision 3: three separate armories with separate saved picks; Allies get no non-Allied weapons

- **What it means technically.** Separate menu names, cfg trees, archived pick cvars, token families and rosters. Shotgun id 44 needs its own tile and saved-pick target on each side.
- **Feasibility.** Yes.
- **Conflicts.**
  - The coop Allied skin ring includes non-Allied bodies (s126, s129). It also has 24 skins whose names fail the engine's american/allied prefix test (coop_mod/helmet.scr:940-945, 976-979, 1004-1017 against code/fgame/player.cpp:2855-2857) [NV].
  - "Allies only" was stated for weapons; whether it also applies to skins is an open question.
  - Coop armory handlers never check team (no dmteam reference in loadoutpick.scr or gloves.scr) [NV], so MP handlers must re-check dmteam at commit and again at spawn.
- **Cost.** Part of the build.

### Decision 4: coop unlocks enforced for MP Allied weapons and skins on every server

**Verdict.** Enforcement that players cannot forge is possible only on a server that already holds the player's coop record, and only when the player id matches. "Every server" can be met only by a gate players can forge. Unforgeable enforcement across servers would need engine crypto plus a trusted signer, or a central service. Neither exists.

- **Where the truth lives.**
  - The server session cvar `coop_unlocks_<id>`, otherwise the file coop_mod/save/unlocks_<id>.dat under that server's homepath, otherwise nothing (coop_mod/challenges.scr:824-833).
  - The only writer is chal_add_unlock (:1215-1241).
  - On a foreign server the record is empty, so only the 4 free starters pass (coop_mod/loadoutpick.scr:780-783), plus ungated cosmetics.
- **Identity.**
  - The id is `coop_guid` = cl_guid, falling back to "n_"+netname, which anyone can spoof (coop_mod/xp.scr:346-359).
  - cl_guid is the MD5 of the local qkey file. When cl_guidServerUniq is non-zero, the server's ip:port is hashed in as a prefix (code/client/cl_main.cpp:1037-1049, 1455-1462).
  - That setting defaults to 1 in the engine (:4264) and in the installer's config (installer/omconfig_default.cfg:363). The mod autoexec sets 0 (autoexec.cfg:1349), but the user's own main/configs/omconfig.cfg:191 still has 1.
  - The server never validates the guid; its only fgame read is code/fgame/g_client.cpp:817.
  - qkey is stored per homepath: a reinstall loses progress, and copying someone's qkey impersonates them.
- **The existing readers write state.**
  - chal_ensure calls xp_identify before its MP guard (challenges.scr:799-801, guard at :867).
  - That can thread xp_rank_unlock, which runs chal_add_unlock: it writes the unlock cvar and file, the pending-unlocks queue, and lock stufftexts (xp.scr:1955-1971; challenges.scr:1239-1248, 1272-1286, 2974-2975). This is the bug-2571 leak class, and clause 10 forbids these labels anyway.
  - A clause-10-clean reader must duplicate five things: the guid wait, a read-only getcvar plus fs_read_content, the pipe-delimited membership probe (loadoutpick.scr:785-790), the free-starter list, and the cosmetic gated allow-list (helmet.scr:1537-1768).
- **Client-side copies are not trustworthy.**
  - The archived coop_loLkA<id>, coop_loCmt<id>, coop_loLkF<fid> and coop_loSkLkA/HmLkA/GlLkA cvars are plain `seta` lines the player can edit (G:\mohaa-gl2\home\maintt\configs\omconfig.cfg:2897, 3076-3077).
  - Any server can overwrite them, because coop_* is filter-legal (cg_servercmds_filter.cpp:173-175).
  - They are exported as fully unlocked whenever the last server ran coop_lockLoadout != 1 (loadoutpick.scr:692-708).
  - Players who never opened the coop armory have none.
  - The client holds no raw unlock list and no XP.
- **Mirror transport.**
  - coopprof is live (code/fgame/player.cpp:318-336, 7529-7567). Players can type it by design, and it silently drops anything beyond 8192 bytes (:7561).
  - The worst-case unlock string is 374 tokens, 13,214 bytes. The live host's unlocks and chal files together are 10,156 bytes.
  - The existing probe cannot round-trip. Its server stufftext `coopprof 0 ...` is dropped by the filter (cg_servercmds_filter.cpp:106-156, 173), and the log has no result line.
- **Finishes and variants.**
  - A finish needs its `finish_<key>` token and weapon mastery (coop_chalD_wpn_<wid>), which comes from a second file, chal_<id>.dat. Variants need their own per-variant challenge (loadoutpick.scr:1116-1198).
  - Several finish challenges count coop campaign stats that cannot advance in PvP (challenges.scr:210-216).
- **TRENCH GUN.**
  - Its only challenge source is fac_ss_1 "Shadow Hunter": 12 Gestapo/SS kills, credited by the victim's model name (challenges.scr:512, 3146-3165; coop_mod/unlockreq_gen.scr:57). A random blueprint coin-flip is the only other route (coop_mod/collectible.scr:386-439).
  - It cannot be earned in PvP, while stock MP hands Americans the shotgun for free (code/fgame/player.cpp:10905-10909).
- **Options.** Full list in section 8a.
  - O1: a read-only reader of the server's own record, with a free floor elsewhere.
  - O2: a client mirror over coopprof, imported only when the server holds no record. This matches the user-approved hybrid rule in coop_mod/profile.scr:1-30, and it is forgeable.
  - O3: a signed mirror. A shared md5string secret shipped in the mod can be extracted.
  - O4: a central service. fgame has no HTTP.
  - O5: a client-only gate reading coop_loLkA, which is forgeable and polluted.
- **Possibly superseded.** _research/mp_loadout_plan_v1.md:23-39 says this decision was replaced by MP-only progression. If that stands, no coop reader is needed, but the same forgeable-or-not choice returns for carried MP progress.
- **Cost.** O1 is small to medium (script plus generated token tables). O2 is medium and first needs a working client-to-server hop. O3 and O4 are large engine and backend projects.

### Decision 5: MP Axis armory with German, Italian and Japanese weapons plus the shotgun, all unlocked for now; combos for skins, headgear, glasses and gloves; all weapons, variants and weapon skins

- **Weapons.**
  - The roster already contains 33 Axis-side ids (section 4.2).
  - Stock Axis kit items not in the roster: Gewehrgranate (kar98_mortar.tik) and Minensuchgerat (Gr_W_MineDetector.tik), both of which already have 7 finishes, and the Italian smoke grenade it_w_bombabreda.tik, which has none.
  - No usable Japanese grenade exists. A Type 97 is half-imported: base txt, skd and shader exist, but it has no tik, its projectile tiks exist nowhere, and its rank 510 collides with US_W_MineDetector.
  - kar98_g98.tik, the G43's model variant fid 8 (coop_mod/loadoutskins.scr:475), is a Kar98K clone with different firing stats.
- **Weapon skins.**
  - 15 of the 33 have the 7 finishes. The other 18 are 15 guns whose base tik exists only in maintt/zzzzz_xw_weapons.pk3, plus 3 grenades.
  - The coop tools cannot make them without changing coop: gen_skins build renumbers 350 ranks and rewrites coop_skins.shader, and `<stem>_<finish>.tik` names make gen_loadout emit 18 p-page diffs and 126 new finp cfgs.
  - They need an MP-only generator with non-colliding names, its own shader file, its own table and its own rank band.
- **Character skins.**
  - There are 25 stock Axis bodies (21 German, 4 Italian), and 63 more exist only in HRRTM Pak1.
  - No Japanese character model exists anywhere, and no hatless Axis body exists.
  - Hatless bodies are feasible for all 88 by deleting tik lines, with no mesh surgery [NV].
- **Headgear and glasses.** 20 Axis-origin exact-fit pieces already exist, 6 of which depend on HRRTM-only shaders. Eyeglasses and Aviator Glasses sit in the single head slot, as in coop.
- **Gloves.** Stock German glove art exists for both views (Leather and Wool Knit). Showing it requires shader lists in the new Axis body tiks and their _fps twins.
- **Conflicts.**
  - Plan decisions 8-12 say Axis is not "everything unlocked".
  - DECISIONS.md:542-551 says Axis weapons keep challenge unlocks, and rejects authoring an Axis cosmetic set.
  - Decision 7 forbids touching the disguise bodies.
- **Cost.** A large content effort: bodies, _fps twins, Standard Issue tiks, skins, glove injection and page cfgs. Medium tooling.

### Decision 6: Axis first-person gloves get their own client cvar

- **cgame site.**
  - code/cgame/cg_modelanim.c:3041-3061 reads coop_gloveIdx (Cvar_Get with flags 0) and writes `(g&3)|((g&4)<<4)` to triggerhand, lefthand and garandhand. It has no team or gametype condition.
  - Add a sibling cvar, chosen when `cg.snap->ps.stats[STAT_TEAM] == TEAM_AXIS`. STAT_TEAM is already read at :2999, in the fallback branch.
  - Coop force-joins an Axis player to allies after a 1 s wait (coop_mod/main.scr:424-429), so an Axis-gated read can fire briefly in coop. That is harmless as long as coop never sets the Axis cvar.
- **Preview.** code/client/cl_invrender.cpp:318-331 reads coop_loGlove by fixed name. An Axis preview needs either a per-widget cvar keyword (an exe change) or writes to coop's preview cvar.
- **Content.**
  - Third person needs glove shaders on the worn body's `hand` surface; first person needs them in `<stem>_fps.tik` (docs/tools/gen_gloves.py:92-124).
  - At most 7 gloves fit, because MAX_TIKI_SHADER is 8 (code/tiki/tiki_shared.h:113; code/tiki/tiki_parse.cpp:933-941).
  - Without a matching _fps twin, first person falls back to german_wehrmacht_soldier_fps.tik, whose hands have a single shader, so no glove shows.
- **Name.**
  - A coop_ prefix passes the filter with no edit.
  - Avoid coop_lo* (clause 10) and the coop_mpa<digit> / coop_mpx<digit> forms (clause 7).
  - If any script getcvar's it, pre-register it in G_InitGame (docs/TRAPS.md:374-388).
- **Cost.** Small C++. The cgame.dll must reach every client (plus the exe for the preview change), staged per docs/21-user-preferences.md:15-20.

### Decision 7: never modify the disguise tiks; Axis preview, glove and hatless models are new files

- **Disguise set** (section 4.10).
  - german_waffenss_officer.tik and its _fps.tik: the default uniform (coop_mod/itemhandler.scr:888-902).
  - sc_ax_ital_inf.tik and its _fps.tik: the e1l4 uniform (maps/e1l4.scr:41).
  - The live waffenss_officer is the HRRTM Pak1 copy, a different model from retail.
- **Naming rules for new files.**
  - An Axis model name must start with german, axis, it or sc (case-insensitive) and must not end in _fps. Otherwise the engine silently uses german_wehrmacht_soldier (code/fgame/player.cpp:2830-2847).
  - Names starting it or sc get Italian nationality on TT; the rest are German (:10468-10491).
  - First person uses exactly `<stem>_fps.tik` (code/cgame/cg_modelanim.c:2984-3016).
  - The bot model pool takes every top-level models/player tik starting german_, IT_ or SC_ that is not _fps (code/fgame/g_bot.cpp:55-81). Names like axis_* or italian_* pass InitModel but stay out of the pool.
  - The stock MP model picker lists any file starting german, axis, it or sc (code/client/cl_uiplayermodelpicker.cpp:247-266).
- **Things never to do.**
  - Never ship a mod file at any stock Axis player tik path; it would shadow the disguise body.
  - Never add Axis bodies to level.coop_skinStdHelmet or coop_skinBase. Coop's body normalize step would swap disguised coop players onto a hatless twin (helmet.scr:262-275, 1020-1031) [NV].
- **Dressing Axis players.** A server cannot stufftext dm_playergermanmodel: it is engine-registered and not whitelisted (cg_servercmds_filter.cpp:90-95, 202-227) [NV]. MP must dress Axis players with a script `model` command.

### Decision 8: one primary; health 100

- **One primary** removes slot card 2 (urc:368-439), the w*_s2, s2sel, clrP2, fin*_s2 and mvp*_s2 files, and the one-per-class registry (unreg_*, coop_loWho_*, coop_loUnregP*) (docs/tools/gen_loadout.py:119-149).
- **Health** is set per player on each spawn edge, never through coop_health (mp.scr:220-229; clause 4).
- **Class.**
  - DONE must send a legal `primarydmweapon` class derived from the gun's engine class, not its tab.
  - G43 and SVT-40 are sniper, StG44 is mg, and DeLisle, kar98_mortar and the shotgun are shotgun (player.cpp:10782, 10797, 10848, 10890, 10901).
  - Degrade the class against dmflags first: a banned class is refused without writing anything (:12079-12084).
- **Cost.** Small.

### Decision 9: MP never calls coop armory code (clause 10)

- **What clause 10 actually checks today** (check_mp_isolation.py:281-305):
  - literal `coop_mod/<file>.scr::<label>` calls in mp.scr to loadoutpick, challenges, xp, helmet, gloves or loadoutskins;
  - a stufftext naming coop_lo on the same line;
  - coop_mpFreeKit anywhere in coop_mod.
- **What passes it.** Any new MP script file; loadoutskins_base.scr, loadout.scr, loadoutroster.scr; itemhandler.scr::giveInventory; main.scr::changeGameType.
- **Read-only allowlist candidates** [NV]:
  - main.scr::containsText; player.scr::playerExtract; player.scr::playerCleanName;
  - loadoutroster.scr::roster_get; challenges.scr::chal_widFromModel;
  - itemhandler.scr notStartGrenade, makeWeaponStringValid, coop_isPrimaryClass, isPrimaryWeapon;
  - data-only initialisers roster_ids, loadoutskins.scr::skin_init, loadoutskins_base.scr::main.
- **Never allowlist.** chal_ensure and every label that calls it (loadout_finUnlocked, loadout_finMastered, loadout_finResolve, loadout_mvUnlocked, helmet.scr::cosmetic_isUnlocked); changeGameType; the giveInventory chain.
- **Hidden coupling.** All 9 mod grenade base files (for example models/weapons/steilhandgranate_base.txt) append `exec coop_mod/itemhandler.scr "initialiseItem" ...` after the retail content (verifier diff against maintt/pak1.pk3). MP grenade gives therefore run coop itemhandler code, and no clause scans tik includes.

---

## 3. The coop armory as it is

### 3.1 Screen: ui/coop_loadout.urc

- **Header.** One menu, `menu "coop_loadout" 640 480 NONE 1`, borderstyle NONE, bgcolor 0 0 0 0, centred, virtualres 1, fullscreen 0 (:8-15).
- **File.** 3,995 lines, 79,401 bytes, pure ASCII, no BOM, a single `end.` at :3995. It is CRLF only in the working copy; the git blob is LF with core.autocrlf=true.
- **Widgets.** 263 in total: 134 Labels and 129 Buttons.
- **Data-driven.** No US content lives in the file: 340 coop_lo cvar tokens (161 distinct) supply models, names, padlocks and texts, and widgets run 246 ui/loadout/ paths.

| Lines | Block | Rect / bindings |
|---|---|---|
| 17-27 | bg | 0 0 640 480, order 50, textures/mohmenu/coop_lo_bg2.tga |
| 29-41 | closeBtn DONE | 560 8 72 16; `popmenu 0 ; append name ,w0x ; exec ui/loadout/fitunbind.cfg` |
| 43-66 | charRender | 12 82 134 312; linkcvar coop_loChar; modelxformcvar coop_loXfmC (7 floats: offset 3, scale, angles 3); modelattachcvar coop_loHelm on "Bip01 Head"; modelattachcvar2 coop_loPrev on tag_weapon_right; modelspincvar coop_loCharSpin; modelanimcvar coop_loCharAnim; modelanim coop_loadout_idle; modeloffset 78 0 -18; angles 0 200 0 |
| 68-169 | SKIN/HELMET rows | captions 14 396 / 14 409; arrows 72 and 94, 18x12 (`vstr coop_loCharP\|N ; vstr coop_loASkin`, `vstr coop_loHelmP\|N ; vstr coop_loAHelm`); name labels 150 x, 190x12 (coop_loCharNm, coop_loHelmNm) |
| 170-223 | GLOVES row | 14 422; arrows 72 and 94 (`vstr coop_loGloveP\|N ; vstr coop_loAGlove`); label coop_loGloveNm |
| 226-293 | cosmetic lock caption | cosLk 14 46 12x12 (enabledcvar coop_loCosLk); cosReq1-3 at 30 46, 14 57, 14 68 (coop_loCosReq/2/3). The comment at 226-233 is stale |
| 295-585 | 4 slot cards | cardhl<n> 153 41+76k 148x76 (coop_loSel<n>); card<n> and cardbody<n> exec s<n>sel.cfg; cardthumb 160 60+76k 92x50 (coop_loS<n>, coop_loXfmT<n>); chip label coop_loN<n> |
| 587-599 | USE MAP DEFAULT | 156 364 142x14, exec reset.cfg |
| 601-683 | 6 tabs | RIFLE/SNIPER/SMG at y42, HEAVY/PISTOL/NADES at y59; x 306/361/416; 52x15; each sets all 6 page flags, `append name ,w0t<N>`, exec lktab<N>.cfg |
| 685-2914 | 74 tiles | tileNN Button 306 (80+19k) 162 16, k=0..17; tilelkNN Label 452 (81+19k) 14 14, coop_lo_lock.tga, order 8 |
| 2916-3174 | finish strip | label 150 435 (coop_loFinUIOn); finbtn0 STD 196 434 30x15; finbtn1-7 GOLD/CHROME/BLUED/BLOODY/WOODLD/WINTER/DESERT at x228+45k, 43x15 (`vstr coop_loFcmt<f>`, hover reqf<f>.cfg, padlocks coop_loLkFV<f>); finbtn8 VARIANT 545 434 50x15 (enabledcvar coop_loMvOn, `vstr coop_loFcmt8`, hover reqmv.cfg) |
| 3180-3325 | inspect models | prevC0-5 and prevG39 at 478 44 152x100 (coop_loPrev, coop_loXfmW, enabledcvar coop_loPvC0-5 / coop_loPvG39; modelscale 1.00 x4, 1.60, 2.00, 0.80) |
| 3327-3381 | texts | wname 478 152 facfont-20 (coop_loNm); wdesc 478 176 (coop_loCd); wreq/wreq2 at 190/202 (coop_loReq/Req2) |
| 3383-3473 | stats | bar0-3 516 218+16k 114x8 (coop_loB0-3, linkcvartoshader); clip 516 286 (coop_loClip); rounds 478 286 (coop_loClipN); recoil 481 317 70x58 (coop_loRecoil) |
| 3475-3493 | helm3dRender | 559 317 68x58 (coop_loHelmView, coop_loHelm, coop_loXfmH) |
| 3495-3993 | fit-tune dev overlay | 33 widgets gated by coop_loFitUI; drop this in MP |

**Tile and tab mechanics**
- **Ids per tile.** Every tile carries its roster id five times: tileNN, tilelkNN, `exec ui/loadout/tNN.cfg`, `exec ui/loadout/reqNN.cfg`, and padlock enabledcvar coop_loLkVNN.
  - That is 366 id-bearing tokens. Tiles 01, 24, 48 and 64 have no hover.
  - The mouse-away command runs reqclear.cfg; the click sound is apply.wav.
  - The tile id equals the TSV id and the loadoutroster.scr case id.
- **Pages.** The page comes from the tile's enabledcvar; the row comes from its rect.
  - Tab 0 is gated `!coop_loNP0`, because an unset cvar reads 0 (bug-589). Tabs 1-5 use coop_loP1-5.
  - Rows used per tab: 12, 12, 13, 13, 18, 6.
- **Capacity.**
  - Row 19 (y422) would collide with the finish strip (y434, x196-595).
  - No MP tab needs more than 9 rows (y80-y232).
- **Coop nation split per tab** (shotgun on both sides): Allied 8/7/8/7/9/3; Axis 4/5/5/7/9/3.

**Engine rules the screen depends on**
- **Parser.**
  - It stops at the first `end.`; only a postinclude declared before `end.` still runs (code/uilib/uilayout.cpp:109-113, 204-213).
  - Among same-named menu containers the first is kept (case-insensitive); later ones are dropped with only a console print (code/uilib/uiwinman.cpp:629-659).
  - Every ui/*.urc loads at UI init (code/client/cl_ui.cpp:5633-5645).
- **enabledcvar.**
  - One per widget; a second line silently overwrites the first; the only operator is a leading `!` (code/uilib/uiwidget.cpp:1695-1715, 2545-2548).
  - A missing cvar reads 0.
  - A gated widget gets no clicks while its gate is off (:1736-1742). This relies on the engine fix from bug-587 and bug-593.
- **Preview.**
  - Exactly two attach slots (code/client/cl_uistd.cpp:226-261; cl_invrender.cpp:283-342).
  - Each slot composites a whole TIKI, so a combined hat-plus-glasses tik in the head slot would render both.
  - A rendermodel widget draws over 2D widgets regardless of ordernumber (urc:226-233, 2881-2884).
- **Engine-fixed cvar names** (global, not per widget):
  - coop_loGlove, values 1-7, applied to the `hand` surface (cl_invrender.cpp:318-331);
  - coop_loHelmOnChar and coop_loWpnOnChar (:286, :288);
  - coop_loXfmCH and coop_loXfmWH (:338, :341);
  - coop_loFitCur and its dump list (cl_ui.cpp:5403, 5429-5432);
  - coop_loSpinSens, archived (cl_uistd.cpp:594).
  - When a helmet is attached, the preview hides only us_helmet, us_helmet_inside and bob_helmet_camo (cl_invrender.cpp:293-304).
- **Fonts.** Only verdana-12 (151 uses) and facfont-20 (1 use) are usable. verdana-10 fails to load (docs/tools/gen_glove_ui.py:18-19). An unregistered font crashes UI init (docs/FEATURES.md:632-633, bug-519) [NV].
- **Background.** coop_lo_bg2.tga is 2048x2048 RGB. It has painted in: the header "ARMORY // SELECT LOADOUT", the OPERATOR/LOADOUT/WEAPONS captions, four slot seats, DMG/RPM/ACC/MOB, RDS, RECOIL PATTERN, and the coop caption ending "MISSION-CRITICAL WEAPONS ARE STILL ISSUED AUTOMATICALLY". docs/tools/gen_armory_bg.py cannot reproduce this image and would overwrite it (OUT at :30).
- **Entry points.**
  - The only push in the mod is ui/loadout/open.cfg:3.
  - open.cfg runs `exec ui/loadout/init.cfg; pushmenu coop_loadout; append name ,w0o; exec ui/loadout/glove/g00.cfg` (:2-4, :9).
  - It is called from: ui/multiplayer.urc:210 (the ARMORY button on the Join Game menu), ui/multiplayeroptions.urc:174 ("Allies Player Model"), autoexec.cfg:1378 (F7), and coop_mod/lobbyui.scr:237 (stufftext).
- **Closing.**
  - DONE also execs fitunbind.cfg, which unbinds 15 user keys every time (fitunbind.cfg:2-16).
  - ESC calls PopMenu(qtrue), which restores every linkcvar to its value at open and sends nothing (cl_ui.cpp:3127-3128; uimenu.cpp:344-357, 593-619).

### 3.2 Client click chains (no server involved)

- **Slot card: s<n>sel.cfg** (s1sel.cfg, 33 lines).
  1. set coop_loSel<n> 1 and the other Sel flags to 0; set coop_loCcur `vstr coop_loC<n>`.
  2. Set the page flags and exec the matching lktab: slots 1-2 use tab 0, slot 3 tab 4, slot 4 tab 5.
  3. Retarget coop_loFgo0-8 to `exec ui/loadout/fin<f>_s<n>.cfg`; set coop_loFinUIOn 1; exec lkfin.cfg.
  4. Point coop_loOpenInspect and coop_loMvPN at slot n; vstr coop_loInspectS<n>, then coop_loFinPrevS<n>.
- **Tile: tNN.cfg.** Runs `exec ui/loadout/pNN.cfg`, then `vstr coop_loCmtNN`.
  - coop_loCmt<id> is either `vstr coop_loCcur` (commit) or `vstr coop_loDeny` (plays back.wav).
  - It is set by init.cfg for the four free starters (:66-69) and by the server's lock export (coop_mod/loadoutpick.scr:723-725).
- **Preview page: pNN.cfg.** Plain `set` only (p01.cfg, 37 lines):
  - coop_loMvOn, coop_loMvReqCur, coop_loMvPN_s1-4, coop_loFinP1-7;
  - coop_loPrev, coop_loXfmW, coop_loPrevId, coop_loCharAnim, coop_loPvC0-5, coop_loPvG39;
  - coop_loNm, coop_loCd, coop_loB0-3, coop_loClip, coop_loClipN, coop_loRecoil;
  - coop_loC1-4: either `exec ui/loadout/wNN_s<slot>.cfg` or `vstr coop_loDeny` for a slot the gun cannot use.
- **Commit: wNN_s<n>.cfg** (w01_s1.cfg, 14 lines).
  1. Slots 1-2 only: `vstr coop_loUnregP<n>; vstr coop_loWho_<class>`.
  2. seta coop_lo<n> (id), coop_loN<n> (name), coop_loS<n> (tik), and coop_loA<n> = `append name ,w<n><id>`.
  3. set coop_loXfmT<n>; `vstr coop_loA<n>` (this sends the token).
  4. seta coop_loInspectS<n>, coop_loS<n>F 0, coop_loFA<n> '' and coop_loOpenInspect (slot 1 only), plus the registry cvars.
- **Finish.**
  - A finish button runs `vstr coop_loFcmt<f>`. lkfin.cfg sets that to `vstr coop_loFgo<f>` or to deny.
  - That reaches fin<f>_s<n>.cfg: seta coop_loS<n>F <f>; seta coop_loFA<n> `append name ,f<n><f>`; `append name ,f<n><f>`; vstr coop_loFinP<f> (shows the finpNN_f preview).
  - fin8 is the VARIANT cycle: `vstr coop_loMvPN` steps through the mvpNN_k_sN chain. Each link sets coop_loPrev and coop_loNm, seta's coop_loS<n>F <fid> and coop_loFA<n> `append name ,f<n><fid>`, and sets coop_loMvPN_s<n> to the next link. The chain only arms the replay recipe; the live `,f<n>8` token comes from fin8_s<n>.cfg:6 (mvp01_1_s1.cfg:1-6).
- **Tab.** The button sets the six flags, sends `,w0t<N>` and execs lktab<N>.cfg. lktab sets every coop_loLkV01..75 to 0, then for each member id sets coop_loLkV<id> 1 and runs `vstr coop_loLkA<id>` (fail-locked; lktab0.cfg:1-99). Ids 70-75 were hand-appended without the `LkV 1` line, and lktab3 vstr's the nonexistent coop_loLkA73.
- **Cosmetic rows.**
  - Skin page skin/sNN.cfg (s01.cfg, 18 lines): set coop_loChar `models/player/<skin>_nohat.tik`, coop_loXfmC `57 1 4 0.80 0 200 0`, coop_loCharN/P; seta coop_loASkin `append name ,snNN` and coop_loOpenSkin; set coop_loCosLk 1 then `vstr coop_loSkLkA<NN>`; set coop_loCosReq/2/3 and coop_loCharNm; set coop_loStdH then `vstr coop_loHelmStdRef`.
  - Helm page helm/hNN.cfg: set coop_loHelm, coop_loXfmH `-2 8 -1 1.00 -90 120 150`, coop_loHelmN/P; seta coop_loAHelm `append name ,hnNN` and coop_loOpenHelm; lock lines (`vstr coop_loHmLkA<NN>` on 31 of 47 pages); coop_loHelmNm. h01 "Standard Issue" instead runs `vstr coop_loStdH`.
  - Glove page glove/gNN.cfg: set coop_loGlove <n>, coop_loGloveNm, coop_loGloveP/N; seta coop_loAGlove `append name ,gn<n>` and coop_loOpenGlove; lock lines (`vstr coop_loGlLkA<NN>` on g02-g06 only).
- **USE MAP DEFAULT: reset.cfg.** Clears seta coop_lo<s>, coop_loN<s>, coop_loA<s>, coop_loS<s>, coop_loS<s>F, coop_loFA<s> and coop_loInspectS<s>, then `append name ,w0c` (:19).
- **init.cfg (121 lines).**
  - Seeds page flags, xforms, coop_loChar `models/player/american_army_nohat.tik` (:40) and coop_loHelm `coop_std_ushelmet.tik` (:41-42).
  - Seeds the skin/helm ring pointers, execs lktab0 and lkfin, and execs p01.cfg (:114).
  - Then runs `vstr coop_loOpenInspect / coop_loOpenSkin / coop_loOpenHelm` (:117-121), which replays the player's archived coop picks. Reusing init.cfg for MP would therefore show the coop kit.

### 3.3 cfg tree and generators

The tree is ui/loadout/: 1,303 files, 493,042 bytes. That is 1,113 at top level plus skin/ 135, helm/ 48 and glove/ 7.

| Family | Count | EOL | Emitter today | Role |
|---|---|---|---|---|
| pN | 74 | LF | gen_loadout.py preview() :50-114 | inspect page |
| tN | 74 | LF | gen_loadout.py tile() :153-158 | tile click |
| wN_sN | 124 | LF | gen_loadout.py slotfile() :117-150 | commit + token |
| reqN | 70 | LF | gen_loadout.py req() :161-166 | hover unlock text |
| finpN_N | 273 (39 guns x 7) | LF | gen_loadout.py :205-217, only if the finish tik exists | finish preview |
| mvpN_N_sN | 400 (23 hosts) | CRLF | docs/tools/wire_mv2.py :173-189 | variant chain |
| reqmvN | 23 | CRLF | wire_mv2.py :153-158 | variant hover text |
| finN_sN | 36 | CRLF | none | apply finish |
| reqfN | 7 | CRLF | none | finish hover text |
| lktabN | 6 | LF | none (lost), hand-patched | padlocks per tab |
| sNsel | 4 | LF | none (wire_mv2 appends one line) | slot select |
| clrkN 4, clrPN 2, clrN 2, unreg_* 4, seed_sN 2 | 14 | LF, seed CRLF | none | clears, registry, seeds |
| reset, open, init, reqclear, reqmv, lkfin, fitbinds, fitunbind | 8 | mixed | none | fixed |
| skin/sNN | 135 | LF | none; gen_cos_reqs.py rewrites CosReq2/3 | skin ring |
| helm/hNN + hclear | 48 | LF | none; gen_cos_reqs.py rewrites CosReq2/3 | helmet ring |
| glove/gNN | 7 | LF | gen_glove_ui.py, but stale against disk | glove ring |

Only 615 of the 1,303 files have a generator that still reproduces them (gen_loadout.py), and 423 more (mvp, reqmv) come from wire_mv2.py, which has no check mode. Nothing that survives can reproduce the other 265: the 75 fixed cfgs and the 190 cosmetic pages. The skin ring is not a clean ring: page headers come in /76, /121 and /135 batches, and s01's PREV goes to s121, so paging backwards skips s122-s135.

Generators and their hazards:
- **docs/tools/gen_loadout.py**
  - Modes: check (the default), build, extract.
  - Output dir and roster path are hardcoded (:30, :38). A build also splices roster_ids into coop_mod/loadoutroster.scr (:193-198).
  - `check` exits 1 today: 604 files identical, 11 DIFFERENT (p03, p07, p08, p09, p14, p23, p45, p46, p50, p53, p55). Disk has coop_loMvOn 0 / reqclear; the generator emits MvOn 1 / reqmvNN.
  - Cause: MV_HOSTS grew in root commits c5c0142 and 1fd6005 (2026-08-19), but the pages were last committed 2026-08-18. So the coop VARIANT button is dark on those 11 tiles in live coop.
  - build.ps1 never runs gen_loadout.py.
  - `extract` rewrites the TSV with only its 19 columns (:284-300), so an added nation column would be deleted.
  - The finish-tik existence probe (:75-81) ties coop pages to files named models/weapons/<stem>_<finish>.tik.
- **docs/tools/wire_mv2.py**
  - No dry-run, no check, relative paths.
  - Every run rewrites the loadoutskins.scr MODEL VARIANTS block, MV_HOSTS inside gen_loadout.py, 23 reqmv files, 400 mvp files and global/giveall.scr.
- **docs/tools/gen_glove_ui.py --write**
  - Writes a stale template into glove/g00-g06: it drops seta coop_loOpenGlove, the lock vstr lines and the CosReq caption lines.
  - Also moves the skin and helmet rows in coop_loadout.urc, which breaks clause 6. Never run it.
- **docs/tools/gen_cos_reqs.py.** Rewrites coop_loCosReq2/3 in place on every skin and helm page. No dry-run; writes LF.
- **docs/tools/gen_skins.py**
  - Modes: list, build.
  - Sees only tiks in the mod's models/weapons that have an inline classname Weapon and a name with no " (" in it (:118-128).
  - Build is not reproducible: all 350 existing variants would get a new rank (allocation starts at 1000 and skips ranks already used). It also rewrites coop_skins.shader from its first coop_skin_ block onward (:267-270).
- **docs/tools/gen_gloves.py**
  - Injects glove shader lines into `<skin>.tik`, `<skin>_nohat.tik` and `<skin>_fps.tik` for the Allied armory skins read from helmet.scr coop_armorySkins (:81-84, :150-206).
  - Extracts pak-only tiks into the mod tree if they are missing.
  - Census: 368 tagged tiks, none German.
- **docs/tools/gen_skinbase.py.** Rewrites coop_mod/loadoutskins_base.scr on every build (build.ps1:66). Its exit code is not checked.
- **Lost generators.**
  - scratchpad/gen_loadout3.py produced the urc plus most of the 265 files with no emitter.
  - build_finish_strip.py produced the fid 1-7 half of loadoutskins.scr (coop_mod/loadoutskins.scr:1).
- **docs/tools/unlock_audit.py.**
  - A hard build gate (build.ps1:52). It parses the TSV by column position: give = c[2] or c[1], requirements = c[17:19].
  - It exits 1 for any roster row with no coop unlock path, so MP-only rows cannot go in that TSV.

### 3.4 Server pipeline

- **Detection** [NV]
  - player.scr::manage runs for every connected player, spectators included.
  - Trigger: netname differs from flags coop_netname, or contains ",", with a 15-frame holdoff (coop_mod/player.scr:175-189).
- **Dispatch**
  - Key table: 53 keys "0".."52", contiguous (coop_mod/variables.scr:139-194).
  - Matching: case-sensitive substring via main.scr::containsText (:1334-1373). Data runs up to the first punctuation character (player.scr:527-586).
  - Only the LOWEST table index that has data is dispatched (player.scr:619-625) [NV]. The name is then cut at the first " ," and the server stuffs `set name <clean>` (:590-607), which destroys any other tokens.
  - A key present with no data leaves a stale coop_extracted<i> that can dispatch again (:457-469) [NV].
- **Weapon pick: loadout_set -> loadout_setBody** (coop_mod/loadoutpick.scr:39-170) [NV]
  - loadout_set refuses when gametype is 0 and serializes on flags coop_loSetBusy.
  - loadout_setBody, in order:
    1. no-op if the slot already holds that id;
    2. roster_get; deny unknown ids;
    3. slot legality: p for 1-2, s for 3, g for 4;
    4. unlock gate, only when getcvar coop_lockLoadout == "1" (seeded to 1 when empty at coop_mod/server.scr:28): chal_ensure + loadout_isUnlocked, with deny text from chal_reqText;
    5. one-per-class bump of the other primary;
    6. write coop_loSlot<n>, coop_loSlotId<n>, coop_loRevert<n>, coop_loFin<n>; stufftext `seta coop_loS<n>F 0`;
    7. loadout_rebuild writes coop_loWeapons: picked grenade (or the map's two start grenades), sidearm, p1, p2 (:444-492);
    8. set coop_loDirty and coop_loRegivePending, then thread loadout_regiveWatch.
  - Every deny pushes the last valid chips back to the client (bug-591, bug-1933).
- **Regive** [NV]
  - loadout_regiveWatch (:221-284): waits out the join resend (up to 45 s) plus 1.5 s of quiet, and queues the regive if the player is dead or DBNO.
  - It then runs managePlayerInventory (coop_mod/itemhandler.scr:698-709): takeall, then giveWeaponLoadout -> spawnInventory, which spawns pickup entities.
  - giveInventory (:2341-2370) wraps the give in main.scr::changeGameType 0 ... 2, using triggereffect and `ammo`. changeGameType writes g_gametype, and every restore passes a literal 2 (coop_mod/main.scr:1802-1843; itemhandler.scr:2087, 2131, 2370, 3230).
  - Finally `use`, a spawnWeaponAssert re-select loop, and a backfill `item` inside another gametype 0/2 window.
- **Finishes and variants** [NV]
  - loadout_finish (:943-1110) handles fid 0 = standard, 1-7 = finishes, 8 = cycle, 9-19 = direct variant.
  - loadout_finResolve (:1156-1168) is the only authority at spawn and falls back to the base tik.
  - Ambiguity: a stored fid 8 replays as a cycle, so a replay advances 8 to 9 (:959, 1052-1094).
- **Persistence**
  - The pick path writes no files. The durable state is the client's archived coop_lo* recipes.
  - loadout_resend fires two volleys, at t+4 and t+15 s, each waiting for a token-free name (:293-402).
  - The listen host alone is seeded from getcvar coop_lo1..4, host-gated because server getcvar reads the host's own archive (:420-436; bug-715).
  - Lock export loadout_ui_exportUnlocks is diff-only against per-player Last flags (:686-768).
- **Cosmetics**
  - Skin (bus 31 ,sn): helmet.scr::armory_skin_set (:1356) checks alive, index 1..135 and cosmetic_isUnlocked. armory_skin_applyIdx (:1379-1413) then runs `model <skin>_nohat.tik`, helmet_apply and glove_apply, and stuffs `seta dm_playermodel <skin>`, `seta coop_loSkin <skin>` and `set coop_loChar ...`. No dmteam check anywhere.
  - Helmet (bus 35 ,hn): armory_helmet_set sets flags coop_helmetIdx and refuses 30/31/32 (helmet.scr:835).
  - Glove (bus 52 ,gn): gloves.scr::armory_glove_set. The third-person bits are written as quoted "+skin1/+skin2/+skin4" on the `hand` surface (gloves.scr:100-122). `set coop_gloveIdx <n>` is stuffed only when the value changes (:93-96, 145-148).
  - Spawn re-force and locked-skin heal are skipped for dmteam axis/spectator (player.scr:1268-1332).
- **Team handling** [NV]
  - Coop keeps Axis players off US kit only by forcing them onto allies: forceValidTeam -> forceTeam, a 1 s wait, then join_team allies (main.scr:411-437, 517-525).
  - The armory handlers themselves have no team check.
- **Label purity** [NV]
  - PURE: roster_get, loadout_isPicked, loadout_isUnlocked (only meaningful after the data is loaded), containsText, playerExtract, playerCleanName, chal_widFromModel, and the itemhandler string/class helpers.
  - DATA-ONLY initialisers: roster_ids, skin_init, loadoutskins_base::main.
  - Everything else in loadoutpick.scr writes state. chal_ensure writes (challenges.scr:785-844), so any caller of it is not pure.

### 3.5 Name bus vocabulary

Every client token reaches the server netname as " ,<key><data>" (code/qcommon/cvar.c:1150-1161 appends with a space) [NV]. The coop keys are:

- 0 ,0 version; 1 ,1 fov; 2 ,2 teleport; 3 ,3 dev command; 4 ,stuck; 5 ,5 dev auth; 6 ,6 admin
- 7 ,7t thirdperson; 8 ,8m medkit; 9 ,9c cover; 10 ,pg godmode (dev/host gated); 11-13 ,bn ,rd ,rv stubs; 14 ,td DBNO enter; 15 ,nc noclip; 16 ,ab ammobox; 17 ,ga give all; 18-22 ,wr ,ws ,wp ,wm ,wo dev weapon cycles
- 23-25 ,e1-,e3 emotes; 26 ,c1 take cover; 27-30 ,t1-,t4 anim tests
- 31 ,sn skin set; 32 ,sp skin prev; 33 ,rk ready; 34 ,ch challenges; 35 ,hn helmet set; 36-41 ,hp ,hm ,hu ,hd ,hs ,hq helmet tuner
- 42-45 ,w1-,w4 slot pick (2-digit id); 46 ,w0 o/x/c/t0-t5; 47 ,cp pin; 48-51 ,f1-,f4 finish (fid 0-19); 52 ,gn glove

Notes:
- Skin pages s100-s135 send 3-digit ids (e.g. s126.cfg `,sn126`), but the handler comment says 2-digit (player.scr:677). Whether 3 digits parse is unverified.
- First characters after " ," that no key uses: **4 d i j k l m o q u v x y z**.

Rules for an MP family:
- Lowercase alphanumeric payloads only.
- Keep w, f, s, h and g out of the first two characters, so a coop server can never dispatch them.
- Never add MP keys to getNameAppendCommands.
- One token per round trip.
- Names are capped at 32 bytes (code/qcommon/q_shared.h:318; code/fgame/g_client.cpp:768-779), and coop warns once fewer than 8 characters are free (player.scr:485-489).

### 3.6 Locks the client sees

| Archived cvar (seta'd by the server) | Value | Consumer |
|---|---|---|
| coop_loLkA<id> | `set coop_loLkV<id> 0\|1` | lktab<N>.cfg (loadoutpick.scr:716) |
| coop_loCmt<id> | `vstr coop_loCcur` or `vstr coop_loDeny` | t<id>.cfg (:723-725) |
| coop_loLkF<fid>, coop_loFcmtA<fid> | finish padlocks and commit gates, per finish index 1-7 | lkfin.cfg (:763-767) |
| coop_loSkLkA<pg> / coop_loHmLkA<pg> / coop_loGlLkA<pg> | `set coop_loCosLk 0\|1` | skin, helm, glove pages (helmet.scr:1461, 1512; gloves.scr:198) |

The cosmetic gate is an allow-list: any token absent from level.coop_cosmeticGatedTok is free (helmet.scr:1537-1542, 1756-1768). 132 models/player tokens are gated; all 45 real headgear pieces are gated; gloves are gated except glv_bare and glv_leather.

---

## 4. Inventories

Legend: F7 = all seven finish tiks `<base>_{gold,chrome,blued,bloody,camo_woodland,camo_winter,camo_desert}.tik` (fid 1-7). MV = model variants (fid 8+). xw = the base tik exists only in maintt/zzzzz_xw_weapons.pk3. "dm class" is the engine class used for the dmflags ban check and for primarydmweapon.

### 4.1 MP Allied weapons (42, shotgun included)

| Tab | Id | Name | Nation | give (models/weapons/) | dm class | F7 | MV |
|---|---|---|---|---|---|---|---|
| RIFLE | 01 | M1 GARAND (free) | US | m1_garand.tik | rifle | yes | 3: pagarand, guangarand, lv_ttgarand |
| RIFLE | 02 | M1 CARBINE | US | carbine.tik (xw) | rifle | no | - |
| RIFLE | 05 | LEE-ENFIELD NO.4 | UK | enfield.tik | rifle | yes | 3: p14, hobbsenfurb, lv_ttenfield |
| RIFLE | 06 | SPRINGFIELD M1903 | US | springfield_unscoped.tik (xw) | rifle | no | - |
| RIFLE | 08 | SVT-40 | USSR | svt_rifle.tik | sniper | yes | 1: hobbssvtwood |
| RIFLE | 09 | MOSIN-NAGANT | USSR | mosin_nagant_rifle.tik | rifle | yes | 2: hobbsmosinur, lv_ttmosin |
| RIFLE | 11 | M1 GARAND SILENCED | US | garand_silenced.tik (xw) | rifle | no | - |
| RIFLE | 70 | JOHNSON M1941 | US | johnson_m1941.tik | rifle | yes | - |
| SNIPER | 12 | SPRINGFIELD SNIPER | US | springfield.tik | sniper | yes | 11: smlescope, m1903, dhspdesert, dhspdigital, dhsptiger, dhspwinter, guansplight, guansp2, hobbsspwood, hobbsspurban, lv_ttspring |
| SNIPER | 14 | ENFIELD L42A1 | UK | uk_w_l42a1.tik | sniper | yes | 1: dhl42camo |
| SNIPER | 15 | M1 GARAND SCOPED | US | garand_scoped.tik (xw) | sniper | no | - |
| SNIPER | 17 | LEE-ENFIELD SNIPER | UK | enfieldsniper.tik (xw) | sniper | no | - |
| SNIPER | 20 | MOSIN SNIPER | USSR | nagant_sniper.tik (xw) | sniper | no | - |
| SNIPER | 21 | MOSIN SNIPER SILENCED | USSR | nagant_snipersilenced.tik (xw) | sniper | no | - |
| SNIPER | 23 | DE LISLE CARBINE | UK | delisle.tik | shotgun | yes | 2: lv_ttdelisle, lv_wdelisle ("WEHRMACHT DELISLE") |
| SMG | 24 | THOMPSON M1 (free) | US | thompsonsmg.tik | smg | yes | 8: tommy28, tommy1928d, tommy27a1, m1a1dk, hobbstomworn, guantommy, lv_tttommy, lv_famastommy |
| SMG | 25 | THOMPSON DRUM | US | thompson50.tik (xw) | smg | no | - |
| SMG | 28 | STEN MK II | UK | sten.tik | smg | yes | - |
| SMG | 29 | PPSH-41 | USSR | ppsh_smg.tik | smg | yes | - |
| SMG | 30 | PPS-43 SILENCED | USSR | ppsh43silenced.tik (xw) | smg | no | - |
| SMG | 31 | M3 GREASE GUN | US | greasegun.tik (xw) | smg | no | - |
| SMG | 32 | M3 GREASE SILENCED | US | greasegun_silenced.tik (xw) | smg | no | - |
| SMG | 71 | THOMPSON (GOLD) | US | thompsonsmg_gold.tik (the same tik as the Thompson's gold finish) | smg | - | - |
| HEAVY | 36 | BAR M1918 | US | bar.tik | mg | yes | 5: pabar, bar1918, bar1918a, bar1918a1, bar1918a2 |
| HEAVY | 40 | VICKERS-BERTHIER | UK | uk_w_vickers.tik | mg | yes | - |
| HEAVY | 42 | M1919 .30 CAL | US | 30calportable.tik (xw; 120 rds) | mg | no | - |
| HEAVY | 44 | TRENCH GUN | both | shotgun.tik | shotgun | yes | 6 (section 4.3) |
| HEAVY | 45 | M1A1 BAZOOKA | US | bazooka.tik | heavy | yes | 1: guanbazooka |
| HEAVY | 47 | PIAT | UK | uk_w_piat.tik | heavy | yes | - |
| HEAVY | 72 | DP-28 | USSR | dp28.tik | mg | yes | - |
| PISTOL | 48 | COLT M1911 (free) | US | colt45.tik | - | yes | 7: coltpa, colt1911w, covert, drbond, bloodyeic, guancolt, lv_ttcolt |
| PISTOL | 49 | COLT M1911 SILENCED | US | colt_silenced.tik (xw) | - | no | - |
| PISTOL | 52 | HI-STANDARD HDM | US | silencedpistol.tik | - | yes | - |
| PISTOL | 53 | WEBLEY MK VI | UK | webley_revolver.tik | - | yes | 1: lv_ttwebley |
| PISTOL | 54 | NAGANT M1895 | USSR | nagant_revolver.tik | - | yes | - |
| PISTOL | 60 | TOKAREV TT-33 | USSR | tt33.tik | - | yes | - |
| PISTOL | 61 | TT-33 SILENCED | USSR | tt33silenced.tik | - | yes | - |
| PISTOL | 63 | WELROD MK II | UK | welrod.tik | - | yes | - |
| PISTOL | 75 | S&W M10 .38 | US (nation is a judgement call) | m10_revolver.tik | - | yes | - |
| NADES | 64 | M2 FRAG (free) | US | roster give m2frag_grenade_sp_start.tik (ammo pool "agrenade"); the stock DM tik is m2frag_grenade.tik ("grenade") | - | no | - |
| NADES | 66 | MILLS BOMB | UK | roster give mills_grenade_sp_start.tik ("agrenade"); stock DM mills_grenade.tik | - | no | - |
| NADES | 68 | M18 SMOKE | US | roster give m18_smoke_grenade_start.tik; stock DM M18_smoke_grenade.tik | - | no | - |

Counts per tab: RIFLE 8, SNIPER 7, SMG 8, HEAVY 7, PISTOL 9, NADES 3. 25 of the 42 have F7.

### 4.2 MP Axis weapons (33, shotgun included), by nation

| Nation | Tab | Id | Name | give (models/weapons/) | dm class | F7 | MV |
|---|---|---|---|---|---|---|---|
| GER | RIFLE | 03 | KAR98K | kar98.tik | rifle | yes | 3: hobbskarworn, hobbskarwood, lv_ttkar98 |
| GER | RIFLE | 04 | GEWEHR 43 | g43.tik | sniper | yes | 5: **kar98_g98 (stat-changing, see note)**, G43_dhg43fleck, hobbsg43wood, hobbsg43urb, lv_ttg43 |
| GER | SNIPER | 13 | KAR98K SNIPER | kar98sniper.tik | sniper | yes | 3: g98scope, lv_ttkar98sn, lv_98ks |
| GER | SNIPER | 16 | G43 SNIPER | g43sniper.tik (xw, mod override) | sniper | yes | - |
| GER | SNIPER | 22 | KAR98K SNIPER SILENCED | kar98snipersilenced.tik (xw) | sniper | no | - |
| GER | SMG | 26 | MP40 | mp40.tik | smg | yes | 5: mp40r2, mp18, guanmp40, guanmp40s, lv_mp75 |
| GER | SMG | 27 | MP40 SILENCED | mp40silenced.tik (xw) | smg | no | - |
| GER | HEAVY | 37 | STG 44 | mp44.tik | mg | yes | 4: mp44strap, dhstg44ss, guanmp44, lv_ttmp44 |
| GER | HEAVY | 38 | STG 44 SCOPED | mp44scoped.tik (xw) | mg | no | - |
| GER | HEAVY | 39 | FG 42 | fg42.tik | mg | yes | - |
| GER | HEAVY | 43 | MG42 | mg42portable.tik (xw; dmbulletdamage 60, 150 rds) | mg | no | - |
| GER | HEAVY | 46 | PANZERSCHRECK | panzerschreck.tik | heavy | yes | 1: lv_ofenrohr |
| GER | PISTOL | 50 | WALTHER P38 | p38.tik | - | yes | 2: guanp38, lv_ttp38 |
| GER | PISTOL | 51 | P38 SILENCED | p38silenced.tik (xw) | - | no | - |
| GER | PISTOL | 57 | LUGER P08 | lugerp08.tik (xw) | - | no | - |
| GER | PISTOL | 58 | LUGER P08 SILENCED | lugerp08silenced.tik (xw) | - | no | - |
| GER | PISTOL | 59 | WALTHER PPK | ppk.tik (xw) | - | no | - |
| GER | PISTOL | 74 | MAUSER C96 | mauser_c96.tik | - | yes | 1: c96trench |
| GER | NADES | 65 | STIELHANDGRANATE | roster give steilhandgranate_start.tik; stock DM steilhandgranate.tik | - | no | - |
| GER | NADES | 69 | NEBELHANDGRANATE (smoke) | roster give nebelhandgranate_start.tik; stock DM nebelhandgranate.tik | - | no | - |
| ITA | RIFLE | 07 | CARCANO M91/38 | it_w_carcano.tik | rifle | yes | 1: lv_ttcarcano |
| ITA | SNIPER | 18 | CARCANO SNIPER | carcanosniper.tik (xw) | sniper | no | - |
| ITA | SMG | 33 | MOSCHETTO M38 | it_w_moschetto.tik | smg | yes | - |
| ITA | SMG | 34 | BERETTA M38A | moschetto.tik (xw, "Beretta M38") | smg | no | - |
| ITA | HEAVY | 41 | BREDA M30 | it_w_breda.tik | mg | yes | - |
| ITA | PISTOL | 55 | BERETTA M1934 | it_w_beretta.tik | - | yes | 1: lv_ttberetta |
| ITA | PISTOL | 56 | BERETTA SILENCED | berettasilenced.tik (xw) | - | no | - |
| ITA | NADES | 67 | BREDA MOD.35 | roster give it_w_bomba_sp_start.tik; stock DM it_w_bomba.tik | - | no | - |
| JPN | RIFLE | 10 | ARISAKA TYPE 99 | arisaka.tik (xw) | rifle | no | - |
| JPN | SNIPER | 19 | ARISAKA SNIPER | arisakasniper.tik (xw) | sniper | no | - |
| JPN | SMG | 35 | TYPE 100 SMG | type100smg.tik (xw) | smg | no | - |
| JPN | PISTOL | 62 | NAMBU TYPE 14 | nambu.tik (xw) | - | no | - |
| both | HEAVY | 44 | TRENCH GUN | shotgun.tik | shotgun | yes | 6 |

Counts per tab: RIFLE 4, SNIPER 5, SMG 5, HEAVY 7, PISTOL 9, NADES 3. 15 of the 33 have F7. The 18 without are ids 10, 18, 19, 22, 27, 34, 35, 38, 43, 51, 56, 57, 58, 59, 62, 65, 67 and 69.

Notes:
- **kar98_g98 is a different gun behind a "cosmetic" button.** It is a Kar98K clone: dm bulletdamage 110 vs 50, firedelay 1.1 vs 0.18, clipsize 5 vs 10, plus 4 grenades, 2 smoke grenades and binoculars (models/weapons/G43.tik:37-97 vs models/weapons/kar98_g98.tik:46-115). Its name, "Mauser KAR 98K (Gewehr 98)", also gives it Kar98K hands and ADS. Every other Axis finish and model variant has zero gameplay-line differences from its base.
- **Why 15 guns cannot be skinned today.** Their bases live only in the untracked third-party xw pak (DECISIONS.md:247-252). gen_skins cannot see them, although its emitters could handle them: every surface texture resolves.

### 4.3 Stock items outside the roster, and the shotgun

| Item | Tik | Status |
|---|---|---|
| GEWEHRGRANATE (GER) | kar98_mortar.tik: weapontype heavy, rank 285, dm damage 80, 3 rifle grenades (models/weapons/kar98_mortar.tik:27-84) | F7 exist (loadoutskins.scr:240-246). The stock German "shotgun" class on TA+ unless DF_DISALLOW_KAR98_MORTAR (code/fgame/player.cpp:10894-10903) |
| MINENSUCHGERAT (GER) | Gr_W_MineDetector.tik: grenade subtype, rank 520, 4 mines | F7 exist (loadoutskins.scr:44-50). Stock German landmine class, TT landmine maps only, paired with kar98_lite or 16 pistol rounds (player.cpp:10911-10949) |
| BOMBA A MANO BREDA smoke (ITA) | it_w_bombabreda.tik, only in maintt/pak1.pk3; a single $include of the mod-overridden It_W_BombaBreda_base.txt, rank 590 | No finishes, no _start wrapper; gen_skins cannot parse $include tiks. Stock Italian TA+ smoke (player.cpp:11012-11024) |
| TYPE 97 (JPN) | only type97nade_base.txt, type97nade.skd and japanese_weapons.shader in the xw pak | No tik; its projectile tiks exist nowhere; rank 510 collides with US_W_MineDetector.tik:26 |
| Russian F1 / RDG-1 smoke / US minedetector (Allied) | russian_f1_grenade.tik, rdg-1_smoke_grenade.tik, US_W_MineDetector.tik | Not in the roster; stock Russian and landmine kit items |
| Lite rifles | kar98_lite, It_W_Carcano_lite, m1_garand_lite, enfield_lite, Mosin_Nagant_Rifle_lite | Engine sweeper-kit companions only; have finishes |
| Coop-only weapon tiks | coop_binoculars, dbno_pistol, coop_smoke_grenade (each with F7) | Must never reach MP |

**Shotgun.**
- The only shotgun family in any pak is shotgun.tik: weapontype heavy, subtype 2, ammotype shotgun. The live copy is the mod's.
- F7: shotgun_gold, _chrome, _blued, _bloody, _camo_woodland, _camo_winter, _camo_desert.
- MV fids 8-13: authwinch, dhshotblack, dhshotchrome, hobbsshotty, guanshotty, lv_ttshotgun (coop_mod/loadoutskins.scr:310-316, 531-543).
- There is no Axis shotgun. Stock MP gives shotgun.tik to Americans, Russians and Italians (the default case), to British below TT, and to Germans below TA (player.cpp:10883-10910).

### 4.4 Grenades per nation (roster give vs stock DM tik)

| Nation | Frag | Smoke |
|---|---|---|
| US | roster m2frag_grenade_sp_start.tik ("agrenade" pool); DM m2frag_grenade.tik ("grenade") | roster m18_smoke_grenade_start.tik; DM M18_smoke_grenade.tik |
| UK | roster mills_grenade_sp_start.tik ("agrenade", mainta/pak1.pk3:14); DM mills_grenade.tik | DM M18 smoke |
| USSR | not in roster; DM Russian_F1_grenade.tik | not in roster; DM RDG-1_Smoke_grenade.tik |
| GER | roster steilhandgranate_start.tik; DM steilhandgranate.tik | roster nebelhandgranate_start.tik; DM nebelhandgranate.tik |
| ITA | roster it_w_bomba_sp_start.tik; DM It_W_Bomba.tik | DM It_W_BombaBreda.tik (not in roster) |
| JPN | none exists | none exists |

- **All nine grenade base files set `dm startammo 0`,** and every roster start wrapper also sets 0 (e.g. models/weapons/steilhandgranate_base.txt:51).
- **Stock DM grenade counts come from the primary's `dm additionalstartammo` line** (code/fgame/weapon.cpp:513). 22 roster primaries have no such line; m1_garand and johnson_m1941 declare 0.
- **The roster's own ammo table is wrong for two grenades.** It says "grenade" for M2 and Mills, but their tiks use "agrenade" (coop_mod/loadoutroster.scr:512-531).

### 4.5 Allied skins, headgear and gloves

**Skins (135, coop_mod/helmet.scr:868-1017; ui/loadout/skin/)**

| Group | Range | Notes |
|---|---|---|
| Base set | 1-76 | 70 allied/american names plus the geared soldiers rifleman, riflemannohelm, submachine_gunner(+nohelm), support_gunner(+nohelm) at 71-76 |
| BA skin pack | 77-88 | 12 (bug-1356). The pack's 11 Axis models were not shipped (helmet.scr:951-952) |
| Community | 89-121 | 33, including 34th_Infantery_Division x4, allied_russian_Pvt (s115) |
| Named campaign NPCs | 122-135 | 14: ramsey, mcmartin, johnson_e2l1, cappy_sh, hildebrandt (German officer body), captain_ike, wilson_sh, claus (French resistance), burton, gobbs, hammon, glenn, campbell, whittaker |

- **Worn form.** Every page wears `<skin>_nohat.tik`; no `*_nohat_fps.tik` exists.
- **Gating.** 10 pages are free (s06, s14, s34, s55, s71-s76); 125 are gated. s14 and s55 carry a [GATED] header but bake `set coop_loCosLk 0`.
- **Prefix failures.** 24 names fail the engine's american/allied prefix, so only coop's script `model` shows them [NV].
- **First person.** 33 of the 135 have no _fps tik (bug-2081).

**Headgear slot (47 entries, helmet.scr:36-179)**
- **Standard.** 1 Standard Issue (the skin's own piece, from 72 coop_std_*.tik); 2 No Helmet. Both free.
- **Allied/neutral.**
  - 3 Plain, 4 Netted, 5 29th, 6 29th Netted, 7 Sergeant, 8 Captain, 9 Medic, 10 Engineer
  - 11 Brit Commando Hat, 12 Brit Field Cap, 13 Brit Officer Hat, 14 Brit Tanker Hat, 15 Brit Helmet, 16 US Tanker Helmet
  - 30 Brit Beret (hidden), 32 Soviet Seaman Hat (hidden), 33 Netted + Cigarettes, 34 Lieutenant, 36 Tanker Beret + Goggles, 37 US Gas Mask
  - 39 AVIATOR GLASSES, 43 Wool Cap (its woolcapdc shader exists only in HRRTM), 44 Para Helmet + Mask, 45 Brit Mk2, 46 Brit Officer Cap
- **Axis-origin.** Entries 17-29, 31, 35, 38 and 40-42, and 47 (section 4.8).
- **Refused.** Indices 30, 31 and 32 are refused server-side (73-bone skeleton; helmet.scr:829-835; bug-2085).

**Gloves (7; coop_mod/gloves.scr:28-58; pages glove/g00-g06; bus 52)**

| Index | Name | Token | 3P shader | 1P shader | Unlock |
|---|---|---|---|---|---|
| 0 | Bare Hands | glv_bare | model's own | model's own | free |
| 1 | Leather Gloves | glv_leather | l_gloves | lthr_gloveview | free |
| 2 | Wool Knit Gloves | glv_wool | knitgloves1 | grmn_winter_glove | challenge (challenges.scr:156) |
| 3 | US Winter Gloves | glv_uswinter | handssnow | coop_glove_uswinter_view (mod) | rank 6 (xp.scr:91) |
| 4 | Wool Mittens | glv_mittens | mittens2 | coop_glove_mittens_view (mod) | challenge (:157) |
| 5 | Seaman's Gloves | glv_seaman | seaman_gloves | coop_glove_seaman_view (mod) | rank 12 (xp.scr:93) |
| 6 | Alpine Hands | glv_alpine | hands_snow1 | handviewcold | rank 18 (xp.scr:95) |

### 4.6 Axis player models by nation

**Rules** (code/fgame/player.cpp:2830-2847, 10468-10491; code/cgame/cg_modelanim.c:2984-3016):
- The name must start german/axis/it/sc and must not end _fps.
- it*/sc* gives Italian nationality on TT; everything else is German.
- First person uses `<stem>_fps.tik`, else the team default german_wehrmacht_soldier_fps.tik.

**Retail (25). No Axis `_nohat` body exists anywhere. No Japanese character model exists in any pak.**

The last column shows what a retail-forked hatless body would need for Standard Issue headgear, from _research/nohat reproduction [NV].

| Body | Source pak(s) | Baked headgear | 3P hand shader | _fps twin | Standard Issue if forked from retail |
|---|---|---|---|---|---|
| german_afrika_officer | main/Pak0 (HRRTM overrides) | officer_hat.skd | handsnew | yes | reuse coop_helmet_ger_offhat_sh.tik |
| german_afrika_private | Pak0 (HRRTM) | germanhelmet outside/inside | handsnew | yes | new std on ger_helmet.skd |
| german_elite_officer | Pak0 (HRRTM) | officer_hat | L_gloves | yes | reuse coop_std_officer2_hat.tik |
| german_elite_sentry | Pak0 (HRRTM) | germanhelmet | handsnew | yes | new std on ger_helmet.skd |
| german_kradshutzen | Pak0 (HRRTM) | germanhelmet | handsnew | yes | new std on ger_helmet.skd (same as winter_2) |
| german_panzer_grenadier | Pak0 (HRRTM) | coveredhelmet | handsnew | yes | new std on ger_covered.skd |
| german_panzer_obershutze | Pak0 (HRRTM) | germangear/creasecap | handsnew | yes | new std on std_creasecap.skd |
| german_panzer_shutze | Pak0 (HRRTM) | germangear/creasecap | handsnew | yes | new std on std_creasecap.skd |
| german_panzer_tankcommander | Pak0 (HRRTM) | tankofficerhat "hat" | l_gloves | yes | reuse coop_helmet_ger_tankhat.tik |
| german_scientist | Pak0 (HRRTM) | none (HRRTM copy adds eyeglass.skd) | handsnew | yes | none |
| **german_waffenss_officer (DISGUISE)** | Pak0; HRRTM Pak1 copy wins | officer_hat (HRRTM copy: officerhat_new.skd) | handsnew (HRRTM: l_gloves) | yes | reuse coop_std_officer2_hat.tik |
| german_waffenss_shutze | Pak0 (HRRTM) | germanhelmet | handsnew | yes | reuse coop_helmet_ger_helmet.tik |
| german_wehrmacht_officer | Pak0 (HRRTM) | officer_hat | handsnew | yes | new std on ger_offhat_sh.skd |
| german_wehrmacht_soldier (engine default) | Pak0 (HRRTM uses stahlhelm.skd) | germanhelmet | handsnew | yes | reuse coop_helmet_ger_helmet.tik |
| german_winter_1 | Pak0 (HRRTM) | coveredhelmet | knitgloves1 (1P grmn_winter_glove) | yes | reuse coop_helmet_ger_covered.tik |
| german_winter_2 | Pak0 (HRRTM) | germanhelmet | `hand` on wintersoldier2.skd (not hand.skd) | yes | new std on ger_helmet.skd |
| german_worker | Pak0 (HRRTM) | none | `hand` on german_worker.skd (not hand.skd) | yes | none |
| german_ardennes_artillery_commander | mainta/pak1, maintt/pak1 | coveredhelmet | knitgloves1 | yes | reuse coop_helmet_ger_covered.tik |
| german_dday_colonel | mainta/pak1, maintt/pak1 | officercap | handsnew | yes | new std on ger_officercap.skd |
| german_panzer_corporal | mainta/pak3, maintt/pak1 | German_Beret_M5 (bound to bone "beret") | handsnew | yes | reuse coop_helmet_ger_beret.tik (but index 31 is refused as hidden) |
| german_stukageschwader | mainta/pak3, maintt/pak1 | creasecap | handsnew | **no** | new std on std_creasecap.skd |
| it_ax_ital_vol (ITA) | maintt/pak1 | ax_it_volhat | handsnew | yes | reuse coop_helmet_ital_volhat.tik |
| **sc_ax_ital_inf (ITA, DISGUISE e1l4)** | maintt/pak1 | ax_ital_infhat; tik declares scale 0.52 | handsnew | yes | reuse coop_helmet_ital_infhat.tik |
| sc_ax_ital_inf2 (ITA) | maintt/pak1 | us_helmet | handsnew | yes | reuse coop_std_sc_al_us_inf_helm_2.tik |
| sc_ax_ital_para (ITA) | maintt/pak1 | SC_AX_ITAL_PARA_HELMET | handsnew | yes | new std on ital_para.skd |

- **Glove readiness.** 23 of 25 bodies use hand.skd; 24 of 25 have _fps twins, all on USarmyplyr.skd with triggerhand/lefthand/garandhand.
- **Helmet stacking.** 9 bodies carry a helmet on the outside/inside surfaces, which the preview's hide list does not cover.
- **Retail fork totals:** 2 hatless, 12 reuse an existing piece, 10 new Standard Issue tiks, 0 new container skds [NV].

**HRRTM-only (63, in maintt/zzzzzz-HRRTM_Pak1_Models.pk3)** [NV]
- german_afrika_gunner, afrika_nco, afrika_nco_shirt, afrika_officer2, afrika_private2, afrika_private_sandstorm, afrika_sentry, afrika_shirt, afrika_shirt2
- german_elite_gestapo, elite_panzer_commander, elite_sd_colonel, elite_sentry_staff, elite_ss_officer
- german_feldgendarmerie, feldgendarmerie2, feldgendarmerie_nco, kriegsmarine, kriegsmarine_sentry
- german_panzer_nco, panzer_obershutze_2, panzer_shutze_rear, panzer_sturmshutze
- german_waffenss_nco, waffenss_nco2, waffenss_officer2, waffenss_officer_lt, waffenss_shutze2, waffenss_shutze_mg, waffenss_shutze_rear, waffenss_soldier, waffenss_soldier_mg, waffenss_soldier_rear, waffenss_sturmshutze
- german_wehrmacht_gastrooper, wehrmacht_gunner, wehrmacht_nco, wehrmacht_nco2, wehrmacht_nco_camo, wehrmacht_officer_camo, wehrmacht_officer_major, wehrmacht_rear, wehrmacht_rear_shirt, wehrmacht_sentry (no _fps), wehrmacht_sniper, wehrmacht_sniper2, wehrmacht_soldier2 (no _fps), wehrmacht_soldier_camo, wehrmacht_soldier_camo2, wehrmacht_soldier_vet, wehrmacht_sturmschutze
- german_winter_3, winter_4, winter_5_gunner, winter_6_jager, winter_7_nco, winter_8_officer, winter_sniper, winter_ss, winter_volksgrenadier
- german_worker_afrika, worker_kmarine, worker_panzer

All carry headgear as separate skelmodels.
- **HRRTM-only fork totals:** 0 hatless, 10 reuse, 21 new Standard Issue tiks, 6 blocked.
- **The one missing container** is HRRTM's stahlhelm.skd outer shell ("outside", 90 verts). It blocks 12 HRRTM bodies in total (6 in the overrides, 6 HRRTM-only).
- **Wider dependencies.** HRRTM copies depend on HRRTM-only skds and shaders, e.g. stahlhelm, officerhat_new, coveredhelm_new, eyeglass, heerhelmet, ss_smock_officer_cpt.
- **Textures on retail forks.** 151 of 155 shader references in the retail tiks map to texture paths that HRRTM, HD or DDS paks also override, so a retail fork still looks different on installs without those paks.

### 4.7 Axis headgear and glasses (existing exact-fit pieces in models/coop_helmets/)

| Idx | Piece | Tik | Shader source | Coop reward |
|---|---|---|---|---|
| 17 | German Helmet (SH) | coop_helmet_ger_helmet_sh.tik | static_ranger_helmet (a US-named shader) | cc_stowaway (challenges.scr:543) |
| 18 | German Helmet | coop_helmet_ger_helmet.tik | wehrmact_helmet, stock | cc_under_radar (:527) |
| 19 | German Covered Helmet | coop_helmet_ger_covered.tik | winterhelmet1, stock | cc_das_boot_stealth (:407) |
| 20 | German Crease Cap | coop_helmet_ger_creasecap.tik | obershutze_hat, stock | cc_mein_kampf (:548) |
| 21 | Afrika Korps Cap | coop_helmet_dak_hat.tik | DAKhat, stock | cc_desert_fox (:542) |
| 22 | German Officer Hat (SH) | coop_helmet_ger_offhat_sh.tik | dak_officer_hat, stock | wpn_thirtycal_e (:184) |
| 23 | German Officer Cap | coop_helmet_ger_officercap.tik | officer_hat, stock | t_officer_e (:252) |
| 24 | SS NCO Cap | coop_helmet_ssncocap.tik | ssncohat, stock | cc_hell_let_loose (:313) |
| 25 | German Tanker Hat | coop_helmet_ger_tankhat.tik | tc_hat, stock | cc_king_tiger (:413) |
| 26 | German Field Hat | coop_helmet_ger_hat.tik | dakhat, stock | cc_church_hunt / cc_quiet_town |
| 27 | Italian Infantry Hat | coop_helmet_ital_infhat.tik | SC_AL_US_Inf_Helm, stock | cc_enemy_mine (:544) |
| 28 | Italian Volunteer Hat | coop_helmet_ital_volhat.tik | AX_Ital_Vol_Hat, stock | cc_flugplatz (:545) |
| 29 | Italian Para Helmet | coop_helmet_ital_para.tik | SC_AL_US_Inf_Helm, stock | cc_rolling_thunder (:546) |
| 31 | German Beret | coop_helmet_ger_beret.tik | German_Beret, stock | HIDDEN (73 bones; helmet.scr:829-835) |
| 35 | Gas Mask | coop_helmet_gasmask.tik | gasmask_green, **HRRTM-only** | cc_schmerzen_done (:533) |
| 38 | EYEGLASSES | coop_helmet_eyeglasses.tik | priest_glass(_frames), mod shaders; source mesh HRRTM Pak2 eyeglass.skd | wpn_ppk (:135) |
| 40 | German Crusher Cap | coop_helmet_ger_crusher.tik | crusher_ss_steingrau, **HRRTM-only** | fac_gen_2 (:523) |
| 41 | SS Officer Hat | coop_helmet_ss_officerhat.tik | officerhat_ss_black, **HRRTM-only** | fac_ss_2 (:513) |
| 42 | SS Field Cap | coop_helmet_ss_mutze.tik | hat_ssfeldgrau, **HRRTM-only** | fac_off_2 (:521) |
| 47 | Splinter Camo Helmet | coop_helmet_ger_splinter.tik | camohelmet_splinter, **HRRTM-only** | fac_snp_2 (:525) |

- **Glasses.** Eyeglasses (38) and Aviator Glasses (39, Af_P_Glasses.skd, stock maintt/pak1) are the only glasses meshes.
- **Combos.** A hat plus glasses needs a combined tik in the head slot, or a third attach slot.
- **Stock headgear art with no exact-fit piece yet:**
  - main/Pak0 flyoff and prop gear shaders dak_helmet, motorpool_helmet, sentry_helmet, camohelm, officer2_hat, hundhat, pshutze_hat, worker_hat.
  - Italian SC_AX_ITAL_PARA_HELMET.
  - Retail containers already match every retail Axis head skd (section 4.6).
- **Attach recipe:** `attachmodel <tik> "Bip01 Head" 1.0 "coop_helmetProp" 0 -1 -1 -1 -1 ( 0 0 0 )`; remove with `removeattachedmodel "Bip01 Head"` (helmet.scr:302, 398, 469).

### 4.8 Axis glove options (candidate roster)

| Option | 3P shader | 1P shader | Source | Caveat |
|---|---|---|---|---|
| Bare Hands | body's own | body's own | - | - |
| Leather Gloves | l_gloves | lthr_gloveview | stock textures (germanmaps/tank_commander/l_gloves.tga; lthr_gloveview.tga) | No-op on german_elite_officer and german_panzer_tankcommander, whose base shader is already L_gloves |
| Wool Knit Gloves | knitgloves1 | grmn_winter_glove | stock | No-op on german_winter_1 and german_ardennes_artillery_commander |
| Wool Mittens | mittens2 | coop_glove_mittens_view | 3P stock (german_winter_2); 1P mod shader | - |
| Alpine / Seaman's / US Winter | hands_snow1 / seaman_gloves / handssnow | handviewcold / coop_glove_seaman_view / coop_glove_uswinter_view | coop art | US Winter is US-themed |

- **Cap.** At most 7 gloves per surface (a base shader plus 7; code/tiki/tiki_shared.h:113).
- **Where the shaders go.** Glove lists must be appended to the new body tiks and their _fps twins, following the gen_gloves.py inject/normalise recipe. Normalise each body to one base hand shader.
- **Bodies needing a different UV map.** german_winter_2 and german_worker put `hand` on the body mesh, so a hand.skd glove texture will not map correctly on them.

### 4.9 Stealth-disguise tiks that must NEVER be modified or shadowed

| Tik | Why it is used | Winning copy |
|---|---|---|
| models/player/german_waffenss_officer.tik | Default disguise uniform: itemhandler.scr:888 default, :900-902 model + dm_playermodel; global/items.scr:286, 289; maps m2l2a.scr:1073, m2l2b.scr:130, m6l1c.scr:1268, m6l2a.scr:1393, e1l3/FinalEscape.scr:765 | maintt/zzzzzz-HRRTM_Pak1_Models.pk3 (ssnco.skd + head1.skd + officerhat_new.skd); retail copy in main/Pak0.pk3 |
| models/player/german_waffenss_officer_fps.tik | Loaded automatically while disguised (cg_modelanim.c:2988-2991) | HRRTM Pak1 (retail in Pak0) |
| models/player/sc_ax_ital_inf.tik | e1l4 disguise (maps/e1l4.scr:39-41); hat surface ax_ital_infhat hidden at runtime (helmet.scr:348, 355) | maintt/pak1.pk3 only |
| models/player/sc_ax_ital_inf_fps.tik | Loaded automatically while disguised in e1l4 | maintt/pak1.pk3 only |

Also leave alone:
- the AI models models/human/allied_oss_man_disguised.tik and sc_al_us_claus_disguised.tik;
- the mod-tree AI overrides models/human/it_ax_ital_vol, sc_ax_ital_inf, sc_ax_ital_inf2, sc_ax_ital_para.

Rules: no mod file may sit at any of these paths, no generator (gen_gloves, nohat_build) may target them, and none may be listed in coop_armorySkins or coop_skinStdHelmet.

---

## 5. MP flow

### 5.1 Current chain, as deployed (bug-2571 mp.scr, never played)

1. **Connect.** G_ClientConnect. A different map clears dm_primary (code/fgame/g_client.cpp:951-958); session data restores teamnum (code/fgame/g_session.cpp:61-79) [NV].
2. **Begin.** G_ClientBegin creates the Player (g_client.cpp:1017-1037). InitDeathmatch puts it on the spectator team; Spectator() sets health to max_health (player.cpp:10571-10577, 11105-11133) [NV].
3. **Map script.** It execs global/ambient.scr. ambient.scr sets level.gametype (:22) and, when gametype != 0 and coop_mainScriptLoaded != 1, execs coop_mod/mp.scr::main (:34-36).
4. **mp.scr::main.** Refuses under coop and on gametype 0. Seeds g_statefile, clears dmflags 532676608, threads mp_manage (mp.scr:42-92).
5. **Team menu.** The server stuffs pushmenu_teamselect on a fire-click (throttled to 1/s; player.cpp:6238-6240). cgame picks SelectTeam, ObjSelectTeam or SelectFFAModel (code/cgame/cg_consolecmds.c:834-852). The buttons send `join_team allies;popmenu 0` (main/Pak0.pk3:ui/dm_teamselect.urc:130).
6. **Join.** Join_DM_Team -> CheckCanSwitchTeam -> SetTeam (player.cpp:11324-11427). A spectator with an empty class gets UserSelectWeapon(true), which stuffs `wait 250;pushmenu SelectPrimaryWeapon[_nat]` (:11406-11407, 18463-18495).
7. **mp.scr poll (every 0.5 s).** On the team flip, mp_deploy sends `primarydmweapon "rifle"` and stuffs `wait 300;popmenu 0;wait 300;popmenu 0`. One second later, gametype 2 only, a player still spectating gets `auto` (mp.scr:142-151, 185-214).
8. **Deploy.** EventPrimaryDMWeapon writes dm_primary, then EndSpectator + Respawn, or waits for the spawn wave (player.cpp:12086-12101) [NV].
9. **Respawn.** Init -> InitDeathmatch -> ChooseSpawnPoint -> EquipWeapons, which gives the stock class kit and posts a useitem at +0.3 s (player.cpp:10596-10597, 10737-11034, 10991-10992). Then Spawned() fires the player_spawned delegate (:18584-18605).
10. **Spawn edge** (health > 0 and not spectator). mp_onSpawn sets health 100 and coop_isActive=1; starts the ads, painbreath, tinnitus and muffle monitors and limpWarn; stuffs s_volume and s_sfxduck. **No armory kit.** (mp.scr:155-174, 224-256)
11. **Name clean.** Any name containing " ," is cut and `set name <clean>` is stuffed. Nothing is committed (mp.scr:131-133, 271-284).

### 5.2 Gametype differences [NV unless marked]

| g_gametype | Respawn | Rounds | Team spawn waves | Consequence for the armory |
|---|---|---|---|---|
| 1 FFA | yes | no | never | Players are on allies/axis (dm_manager.cpp:1802-1821), so choose the armory by dmteam; an alive team switch respawns at once (player.cpp:11403-11404) |
| 2 Team Match | yes | no | if sv_team_spawn_interval > 0; default 15 on TA+ (code/fgame/gamecvars.cpp:405-410) | The first deploy is immediate; after death, wait for the wave |
| 3 Team Rounds, 4 Objective | no | yes | - | Anyone still in the armory at round start sits the round out (dm_manager.cpp:1574-1586). Deploying after g_allowjointime (30) makes a temp spectator (player.cpp:10550-10565). Round end runs `restart`, which keeps dm_primary on the same map (sv_init.c:984-995; g_client.cpp:956) |
| 5 TOW | yes | yes | yes | StopTeamRespawn can block EndSpectator (dm_manager.cpp:1748-1766) |
| 6 Liberation | yes | yes | no (the check at :1778 is unreachable) | Jail interaction not analysed |

mp.scr's `auto` fallback runs only on gametype 2 (mp.scr:208-213).

### 5.3 The weapon-select menus and where the armory goes

**Menu names the engine pushes:**
- SelectPrimaryWeapon: American/default models, and every protocol < 15 push. The mod's empty shell is effective.
- SelectPrimaryWeapon_british (allied_british*/allied_sas*), _russian (allied_russian*), _german (german* and every other Axis name), _italian (it*/sc* on TT): all stock, all live.

**Push candidates:**
- **(a) mp.scr on the team flip, only while the player is still a spectator.**
  - Lead with a wait and `popmenu 0` to clear the engine's 250 ms shell push.
  - Then stuff a separate `exec ui/coop_<mp>/open_<side>.cfg`, which pushes the menu and sends an open-ping token.
  - Re-push if no ping arrives.
- **(b) fgame redirect inside UserSelectWeapon, gated per map by an MP-only flag.**
  - This covers every Breakthrough entry: team join, team switch (player.cpp:11399-11402), fire-click (:6215-6237), ESC Select Weapon and the P key.
  - The flag must be cleared on every level load, because coop calls `pickweapon` (main.scr:434).
- **(c) cgame CG_PushMenuWeaponSelect_f** only serves old-protocol and bind pushes. Not enough.
- **(d) An override of dm_main, or a second ESC board,** was reverted after 6 rounds of bugs (code/client/cl_ui.cpp:3138-3141; bug-720, bug-767). Excluded.

**Ordering hazards:**
- Server stufftext is appended to the client buffer; exec and vstr insert at the front; `wait` pauses the whole buffer (code/qcommon/cmd.c:62-70, 100-145) [NV].
- PushMenu and PopMenu silently no-op while the motion lock is held, and a push of the menu already on top is refused (uimenu.cpp:519-533, 550-551, 599-601).
- The empty shell still takes the cursor (bug-2558); pop it before pushing the armory.
- A .urc showcommand cannot run console commands, so a shell cannot redirect on its own (suppress.urc:23-39) [NV].

### 5.4 Holding a player in spectate until DONE

- **Holding works by itself.** A teamed spectator with an empty dm_primary never spawns: TickTeamSpawn returns early (player.cpp:18379-18381) and a fire-click only re-pushes the picker at 1/s (:6215-6237). A non-spectator with an empty class is sent back to spectator (:6248-6253).
- **What to send on DONE.** `primarydmweapon <class>`, where the class comes from the kit primary's engine class, degraded against dmflags first. A banned class is refused without being written (:12079-12084).
- **What script cannot do.** It cannot clear dm_primary: an empty argument returns early (:12016-12020), and only the console `spectator` command clears it (:11296-11306).
- **What must change.** Today mp.scr sets `rifle` on the team flip, which defeats the hold; that must go.
- **A server-side fallback is mandatory:**
  - ESC sends no token (cl_keys.cpp:1207-1236);
  - stock-cgame clients never see the armory;
  - g_inactivekick (900) drops remote spectators (player.cpp:5422-5428) [NV];
  - round modes punish late deploys.
  - Re-push while the player is a teamed spectator without DONE, and after a timeout deploy the last archived or default kit.

### 5.5 Applying the kit (MP recipe) [NV engine semantics, UNTESTED]

1. **When.** On the spawn edge, after EquipWeapons, keyed on the current dmteam; never on a stale flag.
2. **Clear.** `self takeall` (code/fgame/sentient.cpp:136-143).
3. **Give.** `self item <tik>` for primary, sidearm and grenade. Sentient::giveItem has no gametype check, grants starting ammo, and skips the pickup one-primary rule (sentient.cpp:1384-1449; weapon.cpp:3959-3962).
   - Give the plain DM grenade tiks, not the roster's *_sp_start ones.
   - `give` is flagged EV_CONSOLE|EV_CHEAT on Player (player.cpp:292-300), but the bots pass found the cheat check only in G_ProcessClientCommand (code/fgame/entity.cpp:5465-5508; gamecmds.cpp:367). Script `give` is therefore probably not cheat-gated; `item` avoids the question either way.
4. **Ammo.** `ammo <type> <n>` adds (sentient_combat.cpp:66-78); `setammo` sets an exact value (sentient.cpp:163-170). Grenade and smoke ammo must always be given explicitly.
5. **Select.** `use <primary>` plus `activatenewweapon "dual"`, re-asserted after the engine's own +0.3 s useitem. Copy the idea of itemhandler.scr:1905-1945 without calling it.
6. **Health.** `health 100` per player.
7. **Never:** changeGameType, giveInventory, giveWeaponLoadout, managePlayerInventory, spawnInventory, or triggereffect pickups (they need gametype 0).
8. **Unenforced by the engine on script gives:**
   - dmflags bans (only the class path checks them: player.cpp:12028-12041, 10686-10729, 10765-10965);
   - the landmine map gate QueryLandminesAllowed (:10604-10672);
   - `dm additionalstartammo` / `dm startitem` lines, whose effect on a script give is untested.
9. **Isolation note.** Every mod grenade base file execs coop_mod/itemhandler.scr initialiseItem.

### 5.6 Death, respawn, team switch, map change [NV]

| Event | Engine behaviour | Armory handling |
|---|---|---|
| Death | dm_primary kept; respawn on click or wave (player.cpp:6194-6213) | Re-apply the saved kit on every spawn edge; do not reopen the armory |
| Change while alive | primarydmweapon only prints "Will switch to new weapon next time you respawn" (:12106-12109) | Commit for the next life |
| Alive team switch in team modes | Clears dm_primary, pushes the picker, forces spectator (:11399-11402) | The flip edge offers the other side's armory |
| Spectator switch with a class already set | Immediate respawn with the kept class (:11385-11398) | Choose the kit by current dmteam, or the old side's kit crosses over |
| FFA alive switch | Immediate respawn (:11403-11404) | Same |
| Same-map `restart` (round end) | dm_primary kept | Do not re-prompt; whether Player flags survive is unknown |
| Different map | dm_primary cleared (g_client.cpp:956-958) | Fresh hold |

### 5.7 Re-entry and ESC

- **ESC with a menu up** pops it with a cvar restore and sends nothing. **With no menu up** in an MP session it pushes the stock "dm_main" (code/client/cl_ui.cpp:3100-3155). The exclusivity guard knows only "dm_main" (:2480-2506).
- **Stock dm_main, live under BT.** The copy in maintt/pak1.pk3:ui/dm_main.urc wins.
  - Select Weapon runs `popmenu 0;wait 50;pickweapon` (:64).
  - Select Team runs pushmenu_teamselect (:47).
  - Multiplayer Options runs pushmenu mpoptions (:81).
- **pickweapon** is a server console event that calls UserSelectWeapon(false) (player.cpp:915-922, 18499-18506). The P key is bound to pickweapon (maintt/pak2.pk3:default.cfg:97).
- **Routes into the COOP armory during MP:**
  - F7 (autoexec.cfg:1378; archived in the user's omconfig.cfg:57);
  - ESC -> Multiplayer Options -> "Allies Player Model" (ui/multiplayeroptions.urc:174).
- **Not usable as client gates.** coop_active and coop_mpmenu are set only at launch and on coop join (autoexec.cfg:8-9; coop_mod/cfg/detect.cfg:7-8), so they go stale.

### 5.8 Reading tokens in MP

- **Allowed helpers.** Pure string helpers only: containsText, playerExtract, playerCleanName. Clause 10 does not forbid player.scr, main.scr or variables.scr helpers (check_mp_isolation.py:283-305).
- **Forbidden.** Never call manageNamechange or playerNameCommand: they also serve teleport, forced DBNO entry, ammo crates, medkit and the whole coop armory (mp.scr:267-269; player.scr:636-706).
- **Protocol rules.**
  - Use new MP-only keys.
  - Keep one surviving token per batch: commit state client-side into archived MP cvars and send one DONE token, or replay slots one at a time behind a token-free-name poll (the coop_mod/loadoutpick.scr:393-397 pattern).
  - Debounce like coop (15 frames).
- **Transport.** userinfo is sent reliably at most once per client frame and is never flood-gated (code/client/cl_main.cpp:2732-2739; code/server/sv_client.c:1710-1749) [NV].
- **Alternative channel.** A game console command carries 255 bytes per argument (cmd.c:626-641), gated only on a dedicated server with sv_floodProtect 1 (default 0) [NV, UNTESTED].

### 5.9 Remote-client and push limits [NV]

- **Per server command.** Must be under 2048 bytes including the `stufftext "..."` wrapper; longer ones are silently dropped (code/server/sv_main.c:243-245; sv_game.c:1356-1363).
- **Reliable ring.** 1024 unacknowledged commands; command 1025 drops the client (code/qcommon/qcommon.h:215; sv_main.c:196-209).
- **Before CS_PRIMED.** Commands are discarded (sv_main.c:188-189). During level.spawning, stufftext is deferred one frame (player.cpp:12374-12379).
- **Client buffer.** 128 KB; overflow drops the text (cmd.c:27-28, 100-109).
- **Filter.**
  - Each token is checked in a 256-byte buffer.
  - Allowed commands: pushmenu, popmenu, wait, primarydmweapon, name, globalwidgetcommand, echo, play...
  - exec only under ui/loadout/, ui/coop_, coop_mod/.
  - vstr only on coop_* or user-created cvars.
  - set/seta/append on coop_* or whitelisted cvars (dm_playermodel yes, dm_playergermanmodel no).
  - An embedded quote truncates the argument.
  - (cg_servercmds_filter.cpp:32-96, 106-141, 165-227, 299-387)
- **Client cvars.** MAX_CVARS 8192, warning at 80% (bug-1582). A cvar value holds 256 bytes.
- **Clients without the HZM cgame.dll** drop every server exec and vstr (bug-597).

### 5.10 Bots

- **Status.** Off by default: sv_maxbots 0, latched (gamecvars.cpp:675-678). No project cfg enables them.
- **What a bot is.**
  - A real Player with SVF_BOT and targetname "player", so mp.scr's `$player` loop already ticks bots (g_bot.cpp:158-170; g_client.cpp:852; player.cpp:2508; mp.scr:112-116).
  - The authoritative test is `isBot <entity>`, compiled into the deployed game.dll and unused by the mod. netname is unreliable.
- **Class and model churn.**
  - A bot sets `primarydmweapon auto` before joining a team (playerbot.cpp:133-143).
  - On every death it re-rolls both class and model (playerbot.cpp:1247-1260).
  - So dm_primary never holds a scripted value; only a spawn-edge kit sticks.
  - Bots equip the best-ranked weapon that has ammo on every think (playerbot.cpp:183, 1105-1145).
- **Stufftext to a bot.**
  - It goes to BotController::SendCommand.
  - Strings whose first token is not an fgame event (set, s_volume) leak a TAG_GAME buffer, freed on the next different-map load.
  - Strings whose first token is an event handled by Player RUN on the bot: use, join_team, primarydmweapon, dmmessage. `give` runs without a cheat check, and `exec <path>` tries to run a server script (playerbot.cpp:279-330; listener.cpp:1528-1536, 149-157).
- **Model pool.** Every top-level models/player tik starting allied_/american_ (Allied) or german_/IT_/SC_ (Axis), excluding _fps (g_bot.cpp:43-81). It already includes coop's 111 *_nohat tiks; new german_* tiks would join.
- **Stock kit on Allied bots** can be British/Russian guns, a minedetector (no roster row), or locked items.

### 5.11 Maps where mp.scr never runs [NV, UNTESTED]

- **Engine.** It runs only maps/<map>.scr and maps/<map>_precache.scr, and only when they exist; no global script runs on every map (level.cpp:1488-1494, 1613-1620).
- **Stock maps.** 35 MP maps. 33 reach ambient.scr. The two that do not:
  - **maintt/pak3.pk3:maps/lib/mp_ship_lib.scr**: sets level.gametype at :4, prespawn at :58.
  - **maps/obj/mp_bizertefort_obj.scr**: gametype at :4, prespawn at :34.
  - Both are in the default Liberation, Objective, Round, Team and FFA map lists (installer/omconfig_default.cfg:700-705).
  - The planned mod copies of these two scripts (_research/mp_loadout_plan_v1.md:181) were never shipped, although ambient.scr:24-27 reads as if they were.
  - Today, mod clients on these maps get empty pickers with nothing setting their class, so they are stranded.
- **Tour maps.** 23 mod scripts in y_hzm_maptour maps call coop_mod/main.scr::main first and never exec ambient.scr (e.g. maps/dm/Ramelle.scr:11). They run the full coop framework under any MP gametype and force allies. siegecastle_obj and stalingrad_3_obj have no script at all.
- **DMprecache.scr is not a hook.** Overriding it misses all 7 TOW maps.

---

## 6. Isolation contract and gates

### 6.1 Current check_mp_isolation.py clauses (docs/tools/check_mp_isolation.py)

| # | What it checks | Gaps |
|---|---|---|
| 1 | 5 coop entry scripts (main, player, server, variables, itemhandler) must not match `coop_mod/mp\.scr`; maps containing both `coop_mod/main.scr::main` and `coop_mod/mp.scr` fail (:116-149) | Any other MP script name is invisible |
| 2 | mp.scr contains `level.coop_mainScriptLoaded == 1` anywhere (:152-160) | Not required to be the first statement |
| 3 | The text before the first `coop_mod/mp.scr` in ambient.scr has `!= 1` (:163-177) | No coverage check of stock maps |
| 4/5 | Hard-coded MP_FILES (mp.scr, cfg/mp_start.cfg, cfg/mp_reset.cfg) never set coop_health, coop_lockLoadout or 9 other saved cvars (:180-202) | New MP scripts and cfg/urc trees are not scanned; a cvar held in a local is missed |
| 6 | `git diff --exit-code --quiet -- ui/coop_loadout.urc`, cwd = mod repo (:204-218) | Compares against the index, not HEAD; staged, committed and line-ending-only edits pass; guards only this one file |
| 7 | `coop_mp(?:a\d\|x\d\|FreeKit\|LockLoadout)` in coop_mod/**/*.scr, except mp.scr and loadoutpick.scr (:221-241) | Misses coop_mpaA1, coop_mpaSlot1, coop_mpxGloveIdx...; the loadoutpick.scr exemption is stale; ui, maps, global and cfgs are never scanned; a new coop_mod/mp_*.scr would be treated as a coop file |
| 8 | coop_mpRun guard within 200 chars before chal_autosave_loop, chal_pin_load, xp_autosave_loop (:244-271) | chal_ensure calls xp_identify before its own guard |
| 9 | mp.scr never contains `coop_isHost"]\s*=` (:276) | Also matches `==` reads |
| 10 | mp.scr: no `coop_mod/(loadoutpick\|challenges\|xp\|helmet\|gloves\|loadoutskins).scr::label`, no same-line stufftext naming coop_lo; coop_mpFreeKit absent from all of coop_mod (:281-305) | mp.scr only; misses loadoutskins_base, loadout, loadoutroster, itemhandler, main::changeGameType, label-less exec, string-held paths, stufftext through a local, `exec ui/loadout/*` |

The tool exits 1 only on FAIL; PENDING never fails. build.ps1 runs it at :355-373, after pack (:143-203) and deploy (:207-313), and skips it silently when the tool file is missing [NV].

### 6.2 Other gates

- **Hard, before packing** [NV]: scrlint (:8), check_empty_rhs (:13), check_tik_surfaces (:18), check_anim_dwell (:36), check_anim_rootless (:41), unlock_audit (:52), ads_audit (:54), ui_wiring_audit (:58), gen_service_record build (:63), gen_coop_vo_override (:73), gen_metal_brushes (:80), fix_vo_pools --check (:87).
- **Advisory:** check_say_aliases (:46), check_challenges --warn, count_skel_channels --check, check_download_links.
- **Unchecked writer:** gen_skinbase (:66).
- **Not run at all:** prosecheck.py (the only catch for prose that lost its //, TRAPS T1), gen_loadout.py check.
- **No git hooks** in any of the three repos.
- **scrlint / check_empty_rhs** glob every **/*.scr, so new MP scripts are covered. No gate lints .cfg or .urc syntax.
- **check_tik_surfaces** scans only models/weapons, so new models/player tiks get no check.
- **ui_wiring_audit** [NV]:
  - Exec closure over ui/**/*.cfg and *.urc and non-recursive coop_mod/*.scr, case-exact.
  - vstr closure only for coop_(lo|sr|ui)*, using one pooled setter set, so an MP cfg's `seta coop_loX` would hide a dead coop vstr.
  - Sent tokens pass if they startswith ANY registered token (single-character ,0 ,1 ,2 ,3 ,5 ,6 are registered).
  - A token counts as handled only if player.scr dispatches it, which pushes MP tokens into coop's dispatcher.
  - It ignores #if guards (bug-2572).
- **unlock_audit** exits 1 for a TSV row with no coop unlock path.

### 6.3 What each new artefact trips today

| Artefact | Effect |
|---|---|
| MP .urc files | ui_wiring_audit exec closure applies; dead `vstr coop_mpa*` passes; new tokens fail the bus check unless registered in variables.scr and dispatched in player.scr; no gate catches a duplicate menu name ("coop_loadout", "SelectPrimaryWeapon*") |
| ui/coop_mpa/, ui/coop_mpx/ trees | Pass the filter; exec targets checked; nothing forbids `exec ui/loadout/*`, `seta coop_lo*`, `set coop_gloveIdx`, `pushmenu coop_loadout` |
| coop_mod/mp_*.scr scripts | Linted; clauses 2, 4/5, 9, 10 never read them; clause 7 would fail them on coop_mpa1-style names |
| Rows added to loadout_weapons.tsv / loadoutroster.scr | unlock_audit blocks the build; gen_loadout puts them into coop pages |
| Axis finish tiks named `<stem>_<finish>.tik` | 18 coop p-page diffs and 126 new coop finp files on the next gen_loadout build |
| New Axis body tiks | No surface check; would join the bot pool and the stock model picker if german_/IT_/SC_; a stock path would shadow a disguise body |
| cgame Axis glove cvar | Filter-legal with a coop_ prefix; ui_wiring_audit registers literal Cvar_Get names; no clause stops coop scripts stuffing it or MP stuffing coop_gloveIdx |
| Edits to coop_weaponselect_suppress.urc | No clause |

### 6.4 Proposed clauses

- **P1: MP namespace never appears in coop files.** Replaces clause 7.
  - Define COOP_SET = coop_mod/**/*.scr minus the MP scripts, maps/, global/, ui/loadout/**, coop urcs, coop cfgs and autoexec.cfg.
  - Fail on `\bcoop_mp(?!Run\b|menu\b)\w+` and on `ui/coop_mp[ax]/`.
  - Allow exactly coop_mpRun (challenges.scr:701, 867; xp.scr:309) and coop_mpmenu (autoexec.cfg:9; detect.cfg:8).
- **P2: MP files never write coop state.**
  - Define MP_SET = MP scripts, MP cfg trees, MP urcs, cfg/mp_*.cfg.
  - Fail on set/seta/sets/setu/append/setcvar of coop_(lo|sr|ui|pf|chal|xp|helm|skin|unlock)*, coop_gloveIdx, coop_health, coop_lockLoadout, dm_playermodel. Match inside string literals too.
  - Fail on flag assignments `flags["coop_(lo|chal|xp|helm|glove|sr)..."] =`.
  - Fail on fs_write_content under coop_mod/save.
- **P3: no cross-exec or cross-push.** MP_SET must never exec ui/loadout/, ui/coop_loadout, ui/coop_sr or push coop_loadout. COOP_SET must never exec ui/coop_mp[ax]/ or push coop_mp*.
- **P4: default-deny coop calls from MP scripts.** Any `coop_mod/<file>.scr[::label]` must be in READONLY_ALLOW. That list starts with the seven helpers mp.scr uses today, plus whatever read-only roster/string helpers are explicitly approved. Also forbid reading coop_unlocks_/coop_chal_/coop_xp_ cvars and save paths if MP-only progression stands.
- **P5: no coop path reaches an MP script.** COOP_SET must never match `coop_mod/mp(_\w+)?\.scr`. ambient.scr is allowed exactly one gated occurrence. Add a coverage sub-check: every stock MP map's winning script chain reaches mp.scr.
- **P6: raw-byte freeze of the coop surface.** Replaces clause 6.
  - sha256 of the working-copy bytes of: ui/coop_loadout.urc, ui/coop_weaponselect_suppress.urc, ui/loadout/**; coop_mod/{loadoutpick, loadoutroster, loadout, loadoutskins, loadoutskins_base, helmet, gloves, challenges, xp, unlockreq_gen, mvchal_gen, lobby, lobbyui}.scr; scripts/coop_skins.shader; the 350 finish tiks; models/player/*_nohat.tik.
  - Compare against a manifest rewritten only by `--bless`, plus a git diff against a pinned pre-MP commit.
- **P7: menu names unique.** Parse `menu "..."` in every mod urc and every retail pak urc. Fail on duplicates among mod urcs, and on any MP urc declaring coop_loadout, SelectPrimaryWeapon* or a name outside `coop_mp*`.
- **P8: bus tokens disjoint.** Keep an MP registry beside coop's. Fail if either token set prefix-matches the other (coop's extractor is a substring test).
- **P9: rosters and gloves disjoint.** MP tables live in new files. Fail if loadout_weapons.tsv or loadoutroster.scr gains MP-only rows. Fail if the Axis glove cvar appears in COOP_SET or coop_gloveIdx appears in MP_SET.
- **P10: content.** The mod ships no file at a stock Axis player tik path. No generator lists a disguise tik. MP finish tiks never match `<TSV stem>_<finish>.tik`. MP tik ranks are unique across mod, xw and stock paks.
- **P11: UI routes.** No mod ui/dm_main.urc. autoexec.cfg:1378 and ui/multiplayeroptions.urc:174 change only by explicit decision. The suppress URC's coop behaviour stays byte-frozen, or its change is explicitly blessed.
- **Gate placement.** Move check_mp_isolation.py before packing (build.ps1 before :143); make a missing tool a failure; add prosecheck.py --all as a hard gate.
- **ui_wiring_audit changes.**
  - vstr namespace includes coop_mpa*/coop_mpx*.
  - Setter sets are kept per tree.
  - Scan coop_mod/cfg, autoexec.cfg and recursive coop_mod.
  - A second registry/dispatcher pair for MP, attributed by source tree.
  - Exact family matching instead of startswith-any.
  - Flag server-reachable execs outside the filter prefixes.

---

## 7. Constraints and traps from the records

| Topic | Trap | Bug ids / citation |
|---|---|---|
| ESC | PopMenu(qtrue) restores linkcvars and sends no close token; trusting DONE left dead cursors | bug-588; cl_ui.cpp:3127; uimenu.cpp:344-357 |
| Menu stack | pop+push in one frame never works; pushes lost inside the motion lock; the empty shell grabs the cursor; double delayed popmenu is still unverified in play | bug-461, bug-2558, bug-2563, bug-2564 |
| Duplicate menus | Same-name override of a stock menu fails; the engine keeps the first container | bug-720, bug-767, bug-777; uiwinman.cpp:629-659 |
| enabledcvar | Stacked gated buttons ate clicks / only the open page was clickable (needs the engine fix); unset gate reads 0, so negate the default page | bug-587, bug-593, bug-589 |
| Open path | Any route skipping init leaves tiles hidden; init must not plain-set archived cvars | bug-589, bug-1932 |
| URC layout | Widget below canvas height draws nothing; ordernumber ties are unreliable; rendermodel draws over text; only verdana-12 / facfont-20; unregistered font crashes | bug-1365, bug-1527, bug-1530, bug-519 |
| URC workflow | Unobservable from the dev box: add alongside, never replace a working widget; revert on the 2nd failure via `git show HEAD:` | bug-1546; docs/TRAPS.md:185-188; docs/21-user-preferences.md:100-107 |
| Filter | Server exec/vstr/unlisted set silently dropped; remote clients need the HZM cgame | bug-597, bug-1991 |
| Stufftext wire | Embedded quote truncates; valueless `set x` prints instead of setting; whitespace collapses; one statement per stufftext | bug-736, bug-758, bug-773, bug-1364 |
| Ordering | exec/vstr insert at the front, stufftext appends; a server echo reverted a preview | bug-1918; docs/archive/traps-t8-stufftext.md:28-33 |
| Name bus | One token per batch, lowest index wins, stacked tokens destroyed; bare token undispatchable; tokens persist in the saved name | bug-773, bug-1936, bug-772, bug-2571 |
| Reliable ring / cvars | 514-command join burst overflowed; export queued ~1005; archived armory + Service Record families hit MAX_CVARS | bug-681, bug-1670, bug-787, bug-598, bug-1582 |
| Deny path | Every server deny must push the last valid chips back | bug-591, bug-1933 |
| Locks | Fail-locked padlocks; cold-menu snapshot export; locked-preview leak via dm_playermodel; wear-time checks fail open until the record loads | bug-682, bug-666, bug-707, bug-801, bug-803, bug-1578, bug-1595 |
| Host-global cvars | Server getcvar reads the listen host's archive; remotes cloned the host skin | bug-715 |
| Give timing | Carry-over dropped while loading; volleys caused triple give and viewmodel flicker; thread/waitthread ordering killed the give; `.size == 0` guard dead; apply while dead lost | bug-592, bug-595, bug-2067, bug-1204, bug-1931, bug-1930 |
| Finish/variant | 120 s regive gate; finish leak across re-picks; variant ring cross-wired; fin cfgs never fired preview | bug-1919, bug-1923, bug-1926, bug-1934, bug-1938, bug-1927 |
| Generators | Lost urc generator; 0-byte roster truncation; missing roster half; empty RHS parse kill; case-sensitive keys killed 14 guns' finishes; template stomp reverted 75 lines; gitignored TGA overwritten with no backup | bug-1896, bug-1902, bug-1906, bug-1908, bug-1916, bug-1947, bug-1917 |
| Line endings | Never sed -i / text-mode Python / git apply on CRLF files; binary mode, assert counts | bug-2081, bug-2453, bug-2482; docs/TRAPS.md:109-129 |
| Parse killers | One bad token kills the whole file silently; scanners pass files that cannot compile; a dedicated boot is the only real compile test | bug-533, bug-1205, bug-1822; docs/TRAPS.md:29-83 |
| Positional state | Persist ids, never positions; roster shift remapped stale skin archives | bug-1926, bug-armory-roster76 |
| Cosmetics | Headgear removed at source via _nohat tiks, not runtime nodraw; 73-bone headgear bridged out; 33 skins without _fps | bug-1545, bug-2085, bug-2081 |
| MP-specific | coop_health cvar follow-through; coop_lockLoadout is a one-way latch; the dmflags ban latch survives into MP; the coop armory wrote coop saves from MP | bug-2558, bug-2563, bug-2564, bug-2571 |
| Tiles | Never renumber tile ids; id 73 stays a hole; a finish picker is a per-slot cvar, never a tile per variant; every weapon tik rank unique | docs/OPEN.md:178-180; docs/DECISIONS.md:253-255, 278-289 (bug-494) |
| Workflow | Plan, then agent-vet it with independent lenses before code; test yourself on the 2-player harness, sweep the whole log, hash-verify deploys; content ships, binaries are staged; debug prints behind cMTE flags | docs/21-user-preferences.md:15-20, 45-70, 144-152 |
| Engine cvar registration | Script getcvar creates an empty cvar that defeats a later engine default; pre-register in G_InitGame | docs/TRAPS.md:374-388 |

---

## 8. Open questions

### 8a. Need the user's decision

1. Do plan decisions 8-12 (MP-only progression, start over, per-class kills, carried progress, bot kills; _research/mp_loadout_plan_v1.md:23-39) replace decisions 4 and 5? Every lock-layer design depends on this.
2. If decision 4 stands, which policy: O1 server record plus free floor, O2 forgeable client mirror, or O3/O4 signer or central service? It decides whether anti-cheat is possible at all.
3. On a server with no record for the player: free floor, trust-on-first-use import, or deny? Most public players will hit this case.
4. If carried progress stands (decision 11), is a deterrent-grade tamper check (secret in the shipped mod) acceptable, or is a central signer wanted? Only a signer is unforgeable.
5. Does MP Allied enforce weapon finishes and model variants, which need chal_<id>.dat mastery? Doubling the data exceeds the coopprof cap.
6. TRENCH GUN in MP: free starter, its own ladder, or coop-gated (AI-only Shadow Hunter)? Strict coop gating makes it unobtainable in PvP.
7. Which gun per class is the free starter on each side (plan open assumption, :38-39)? It defines the floor and the bot kit.
8. Include the stock-kit items outside the roster: Gewehrgranate, Minensuchgerat with its sweeper rifle, Breda smoke, Russian F1/RDG-1, US minedetector? Replacing the picker otherwise deletes them.
9. Japanese grenade: accept none, or commission a completed Type 97? No usable asset exists.
10. Gewehr 98: keep as a G43 variant, promote to its own tile, or exclude? It is a different gun behind a cosmetic button.
11. MP Allied skin ring: include coop's non-Allied bodies (s126 Hildebrandt, s129 Claus) and the 24 prefix-failing skins? "No non-Allied" was stated for weapons only.
12. Axis body roster: 25 retail only, or all 88 including HRRTM? Fork retail or HRRTM geometry for the 17 overridden names? This decides container work and the HRRTM dependency.
13. HRRTM policy: stays mandatory, and is lifting more HRRTM geometry permitted? Six headgear pieces and 63 bodies depend on it.
14. Should new Axis bodies be pickable by bots and by the stock MP model picker? The naming prefix decides it.
15. Glasses together with hats: combined tiks, or glasses-only in the head slot? A single attach slot allows only one.
16. F7, ESC -> Multiplayer Options -> "Allies Player Model", and the Join Game ARMORY button: what should each do in MP? Today they edit coop picks.
17. ESC-closed or idle armory: auto-deploy after N seconds (with what N, given g_allowjointime 30) or stay in spectate? This is the stranding trade-off.
18. Is a game.dll change acceptable for the re-entry redirect, and must MP hosts run the HZM game.dll? It decides mechanism (b) and whether script-less maps can be covered.
19. The 11 coop tiles with a dark VARIANT button: intended, or approve a separate coop rebuild? This sets the no-coop-impact baseline.
20. Script-less maps (siegecastle_obj, stalingrad_3_obj) and third-party MP maps: in scope? They need per-map stubs or an engine hook.
21. Bots: fixed team kit, random free guns, or random roster guns; random cosmetics or not? It affects the bot branch and MP progression farming.
22. What changes the plan's weapon-select replacement may make to coop_weaponselect_suppress.urc, which coop also loads? It is a shared file.

### 8b. Need a playtest

1. First run of the deployed bug-2571 mp.scr on the dedicated harness: stray cursor, spawn edge, statefile. It has never been played.
2. ESC -> Select Weapon with American, allied_british and German models; grep "dropping duplicate". Confirms which pickers are live.
3. mp_bizertefort_obj (g_gametype 4) and mp_ship_lib (g_gametype 5) with a mod client: confirms the existing strand.
4. A remote client: does a server-pushed `exec ui/coop_*/open.cfg` open the menu, and does its DONE token reach mp.scr? Never tested remotely.
5. `event_subscribe "player_spawned"` with an unquoted label: would give a same-frame spawn hook.
6. Same-map round `restart`: are Player flags recreated, and does the armory re-open every round?
7. Spawn-edge takeall plus `item` in MP after EquipWeapons, and the +0.3 s useitem race: core of the kit recipe.
8. Plain DM grenades vs *_start tiks via `item`; does `dm additionalstartammo` apply to script gives? Grenade counts.
9. `isBot` at runtime, and whether a bot's spawn-edge kit sticks.
10. Name truncation with a long player name plus MP token: 32-byte cap.
11. An armory pushed over or under the empty weapon-select shell: cursor ownership.
12. The six HRRTM-shader headgear pieces on a clean install: do they render untextured?
13. A hatless Axis body without a `_nohat_fps` twin: first-person arms, and glove index on Axis _fps.
14. Helmet attach on Italian skeletons (It_AX_Ital_Vol, SC_AX_ITAL_PARA) and the 73-bone beret: fit.
15. A client-issued `coopprof 0 X` round trip: prerequisite for any mirror.
16. Whether a thread started from a mod maps/<map>_precache.scr survives: hook candidate.
17. The 23 tour maps under g_gametype 1/3/4/5 on a dedicated server: coop behaviour outside TM is unknown.
18. The Axis-gated cgame glove read inside coop's 1 s force-join window: confirm it is harmless.

### 8c. Need more research

1. Does FS_ListFiles("ui/", "urc") recurse into subdirectories? It decides where new urcs can live.
2. Are inner commands of a server-exec'd cfg filtered? It decides whether a client cfg can seta dm_playergermanmodel.
3. Is there any script getter for client dm_primary? Otherwise armory state lives in script flags.
4. What does coop_mod/itemhandler.scr initialiseItem do in MP when run from the grenade base txt files? Hidden coop code on the MP path.
5. Where can an fgame MP gate be reset on every level load? Needed for the UserSelectWeapon redirect.
6. Liberation jail and TOW StopTeamRespawn interaction with a held player.
7. Actual sv_team_spawn_interval, dmflags, g_inactivekick and g_teamswitchdelay on the user's servers and the harness. Timing of holds and fallbacks.
8. Does the ,sn handler parse 3-digit ids (s100-s135)? A latent coop defect and a pattern MP might copy.
9. The rank band for MP finish tiks that is unique across mod, xw and stock paks.
10. Is cl_guid visible to other clients (configstrings/status)? It would make impersonation trivial.
11. Which wins in exec order, autoexec's `seta cl_guidServerUniq 0` or the installer's omconfig value 1? It decides per-server id splits.
12. Coop latent defect: does loadout_ammoTopup ever refill the "agrenade" pool for M2/Mills?
13. Is "Plain" headgear free or gated (helmet.scr:1487/1504 vs :1746), and are s14/s55 meant to be free? Coop data consistency for Allied enforcement.
14. getAmmoType returns "unknown" for johnson_m1941, dp28, mauser_c96, m10_revolver, thompsonsmg_gold: matters if any class dedup logic is reused.
15. Current MAX_CVARS headroom on a typical client, before adding two armories' archived families.
16. The fid 8 cycle vs direct replay ambiguity (loadoutpick.scr:959, 1052-1094), if the MP finish protocol copies coop's.
17. Where the BA pack's 11 unshipped Axis models are: a possible Axis skin source.
18. Which stock skds ger_officercap and ger_tankhat were transplanted from, and whether ger_helmet_sh's static_ranger_helmet shader is intentional: cheap Axis reskins.

---

## 9. Candidate architectures

Shared by all three architectures:
- MP roster tables with side and engine-class columns, in new files.
- An MP finish/variant table.
- The MP give recipe (section 5.5).
- An MP token family with its own dispatcher.
- A server fallback deploy.
- Map-coverage fixes (mod copies of the two stock scripts).
- The Axis content pipeline: parameterised nohat tools, new german_/italian_ bodies with _fps twins, gen_gloves recipe, MP-only finish generator.
- The cgame Axis glove cvar.
- The new isolation clauses.
- A bot branch keyed on isBot.

They differ in how the screen and client data are structured.

### A. Two mirrored screens (generated per-side copies of the coop shape)

- **Structure.**
  - ui/coop_mpa_armory.urc (menu coop_mpa_armory) and ui/coop_mpx_armory.urc (menu coop_mpx_armory).
  - Trees ui/coop_mpa/ and ui/coop_mpx/; cvars coop_mpa* and coop_mpx*.
  - Tiles keep roster ids as tile ids, re-pitched into y80-y232.
  - Three slot cards; the coop finish strip and VARIANT button; no fit overlay; DONE without fitunbind.
  - One new generator, templated from on-disk samples, writes both urcs and both trees in binary CRLF with count, overlap and zero-coop-token assertions.
- **Rough size** (derived from coop counts).
  - Allied urc about 2,400 lines; Axis about 2,100.
  - Allied cfgs about 544 per-weapon (p 42, t 42, w 42, req 38, finp 175, mvp 192, reqmv 13), about 60 fixed, about 190 cosmetic pages: about 800 files.
  - Axis cfgs about 344 per-weapon (no req), about 60 fixed, and new cosmetics (25-88 skin pages, about 22 helm, about 5 glove): about 450-500 files.
  - Engine: preview cvars made per-widget (glove, helmet gates, composite offsets), or an extended helmet hide list.
- **Pros.**
  - Every widget pattern is already proven in coop.
  - Id-baked tiles follow the coop finish and no-renumber rules.
  - Per-side menu names make the side choice a plain `pushmenu`.
  - Separate saved picks come naturally.
- **Cons.**
  - Largest file count and two screens to observe blind.
  - Repeats coop's volley and desync machinery.
  - The templates' original generators are lost, so correctness rests on copying samples.
  - The largest archived-cvar growth; the shotgun needs a tile on each side.
  - New 3-seat background art for each screen, or a shared one.
- **How it honours the decisions.**
  - 1: push by menu name from mp.scr or the fgame redirect.
  - 2: no coop names anywhere, P1-P11.
  - 3: physically separate files.
  - 4: MP padlock families fed by whichever lock source the user picks.
  - 5: the Axis tree has no lock pages.
  - 6: cgame cvar plus per-widget preview cvar.
  - 7: new bodies only.
  - 8: three cards, health in mp_onSpawn.
  - 9: own dispatcher, allowlist-only calls.

### B. One slot-generic screen with per-side data

- **Structure.**
  - One urc (menu coop_mparmory) with 54 generic tile slots (9 rows x 6 tabs), not roster ids.
  - Each slot has a name label (linkcvar coop_mpTn<NN>), a button running `vstr coop_mpTc<NN>`, a padlock (enabledcvar coop_mpLk<NN>) and its own gate cvar coop_mpOn<NN>. enabledcvar cannot AND, so a tab click sets all 54 gates.
  - Side data lives in ui/coop_mpa/tab<N>.cfg and ui/coop_mpx/tab<N>.cfg, which set the slot cvars.
  - Per-weapon preview, commit, finish and variant pages stay per side. Tile click cfgs are replaced by inline vstr commands.
  - Opening means exec'ing the side's open cfg, then `pushmenu coop_mparmory`.
- **Rough size.**
  - urc about 1,500-1,800 lines.
  - 12 tab data cfgs.
  - Per-weapon pages about the same as A minus the t pages (about 500 Allied, about 310 Axis).
  - Cosmetics as in A.
  - Same engine preview work.
- **Pros.**
  - Half the blind URC work, and no per-side re-pitching.
  - Adding weapons (Gewehrgranate, Breda smoke, a future Type 97) is a data change only.
  - A team switch just runs the other side's data cfg.
  - Fewer widgets than coop; view-state cvars shared by both sides; only pick recipes kept per side.
- **Cons.**
  - An unproven pattern here: tile content and gating come from cvars, and a tab switch sets 54+ cvars. Heavy-clicking safety must be re-proved.
  - Breaks coop's id-in-tile convention, whose reason was click-race desync.
  - A single menu means a stale side seed could show the wrong armory unless every open path runs a side-specific cfg first.
  - Padlocks must be recomputed per slot on every tab change (fail-locked first).
  - Harder for the checker to prove one urc never references coop names in data.
- **How it honours the decisions.** Same as A. Side separation lives in the data trees and per-side saved-pick cvars rather than in two screens. P7 and P3 must also scan the tab data cfgs.

### C. Engine-native armory (C++ UI plus a game command)

- **Structure.**
  - A new uilib/client widget, or UI commands, reads a generated per-side roster file (e.g. ui/coop_mpa/roster.txt listing tiles, tiks, finishes, variants, cosmetics) and renders tabs, tiles, locks and preview internally. The preview glove and helmet cvars become parameters.
  - Picks are stored in a few archived client cvars (e.g. one compact kit string per side).
  - DONE, and optionally close, sends one new EV_CONSOLE Player event (e.g. `mparmory <side> <kit>`, 255 bytes per argument) instead of name-bus tokens.
  - mp.scr or fgame validates against a generated server roster, then gives with `item`.
  - The re-entry redirect in UserSelectWeapon comes in the same binary work.
- **Rough size.**
  - Engine about 1,500-3,000 lines of C++ (widget, client commands, fgame event, redirect).
  - One thin urc shell, or none.
  - Two to four generated data files.
  - MP script dispatcher about 300-500 lines.
  - New background art.
- **Pros.**
  - No thousand-file cfg trees, no MAX_CVARS or reliable-ring pressure.
  - No 32-byte name or one-token limits.
  - ESC and close can commit in C++.
  - Per-widget preview parameters remove the fixed coop_lo* names.
  - Data is generated, so it cannot drift.
  - One code path for both sides.
- **Cons.**
  - Needs an updated openmohaa.exe and cgame.dll on every client and game.dll on hosts, which the user stages rather than ships.
  - Stock-exe or stock-cgame clients get nothing and rely entirely on the fallback deploy.
  - Highest engine risk; UI still unobservable from the dev box; least reuse of proven coop patterns.
  - The new client command needs validation and flood design.
  - The isolation contract must extend into C++: the command name, no coop_lo reads, redirect gating.
- **How it honours the decisions.**
  - 1: engine redirect plus native menu.
  - 2: coop UI and cfgs untouched; P-clauses extended to the C++ call sites.
  - 3: separate roster files and kit cvars.
  - 4: lock data supplied by the server or reader per the user's policy.
  - 5: Axis roster file with no locks.
  - 6: glove cvar plus widget parameter.
  - 7: new body files.
  - 8: the kit string holds one primary.
  - 9: the fgame or MP script dispatcher never calls coop labels.
