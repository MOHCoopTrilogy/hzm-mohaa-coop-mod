# Internal Dev Changelog — v1.2.0 (DRAFT)

> INTERNAL RECORD. Not player-facing. Includes bug-IDs, files, and rebuild requirements.
> Window: everything since the v1.1.48 tag (commit 78ce86a, 2026-07-16 21:07) through 2026-07-18.
> Source: .wolf/buglog.json (92 substantive entries in-window; ~130 auto-detected refactor entries
> omitted), .wolf/memory.md, hzm-mohaa-coop-mod/_research/*.md. Version proposal: **v1.2.0**.
>
> **LIVING DRAFT** — gore tuning, exposed-skin wounds, build-mode cover roster, "1936" prop mining,
> and story-VO cleanup are still in flight. Confirm rebuild + playtest before tagging.
>
> Phrasing note for anything that leaks public: gun audio = "fresh recorded gun audio"; death/gurgle
> SFX = "wet death-rattle / bleed-out SFX". Never name the source library or expose secrets/URLs.

---

## ⚠️ Build / deploy requirements before this release ships
Several items are code-flagged but were NOT built this cycle (per drafting task rules). To ship:
- **game.dll (fgame):** gore (sentient.cpp), AI grenade CheckTeams (bug-617), weapons-on-back holster
  (bug-619/623), tank turret owner fix (bug-647 root), blood_model flesh-gate (bug-795), player gore
  gates (bug-797), pool tint/size (bug-828), decal radius side-channel (bug-776), actor EF_DEAD (bug-780).
- **renderer_opengl1.dll:** all gore stamping (tr_gore.c — bug-734/747/754/780/785/796/817/828),
  SSAO camera-motion fix (bug-708).
- **openmohaa.exe:** video/borderless (bug-753 sdl_glimp), pulldown hit-test (bug-756 uilib),
  gore refexport growth (bug-780), ESC-menu engine fixes kept after revert (bug-767/777/831),
  coop_defaults exec-order (bug-710 common.c).
- **cgame.dll:** gore decal radius read (bug-776 cg_ents), gore kill-splash bridge (bug-780).
- **pk3 repack (build.ps1):** all script/UI/texture/TIK changes.
- Deploy note: renderer_opengl2.dll (Jul 3) predates the Gore* refexport members — do NOT select gl2
  without rebuilding it (bug-780 hazard).

---

## Features (new systems)

### 4-tier gore & blood system (NEW, engine + assets) — in polish
- **bug-731** gore tier-1 TIKI skin generator: append blood skins after every `case weapon` block;
  per-path 4-skin (MAX_TIKI_SHADER) overflow audit. `gen_gore_skins.py`, models/*.tik.
- **bug-734** renderer readback entry point: added `GLE(GetTexImage)` to QGL_DESKTOP_1_1_PROCS
  (renderercommon/qgl.h) so tr_gore.c UV-wound readback links on gl1/gl2.
- **bug-747** first visibility pass — five stacked causes fixed (near-black color palette, tier
  thresholds, UV stamp size, wound-prop placement inside mesh, pool regression). sentient.cpp,
  tr_gore.c, gen_gore_skins.py/gen_woundstamp.py, coop_blooddrip*.tik, autoexec.cfg (CVAR_ARCHIVE
  override of stale defaults). Added `r_goreDebug`.
- **bug-754** round 2 — GORE_MAX_TEXBYTES 1024²→2048² (HD tunic diffuses were refused); per-instance
  wound history + family-key rebase (skin flips no longer orphan stamps); dedicated solid pool blob
  texture + rgbGen identity; heavy tier retuned. tr_gore.c, sentient.cpp, player.cpp, coop_blood.shader.
- **bug-776** blood-pool wire clamp — entityState.scale packs scale×100 into 10 bits (max 10.23u), so
  pool radius 31–58 clamped to a splat. Fix: side-channel exact radius in s.surfaces[1] (decals.cpp)
  + read in cg_ents.c CG_Decal. **engine (game.dll + cgame.dll).**
- **bug-780** round 3 — instance-table exhaustion (GORE_MAX_INSTANCES 16→48) + LRU steal rework
  (never steal the entity being stamped); two-layer stamps (splash halo + hole); kill-splash on the
  EF_DEAD rising edge via new GoreKillSplash refexport bridge. tr_gore.c (+tr_local/tr_init/tr_public/
  cl_cgame/cg_public/cg_snapshot/actor.cpp). **refexport grew — exe+cgame+renderer+game together.**
- **bug-785** players must NEVER show holes/wounds: gate entityNumber < MAX_CLIENTS in
  R_GoreSkelSurfaceCheck + RE_GoreKillSplash; early-out IsSubclassOfPlayer in CoopGoreTryWoundProp.
- **bug-795** blood_model flesh-gate — MOHAA human/dog TIKs never issue blood_model, so ALL AI gore
  no-opped ("BLOCKED no blood_model" ×58 in log). Fix: Actor::Actor() defaults blood_model
  "fx_bspurt.tik". **game.dll.** (This was the real "pools not visible for AI" root.)
- **bug-796** round 4 "super messy" (later dialed back).
- **bug-797** player gore gates finalized — no body gore + no pooling on players (IsSubclassOfPlayer
  early-out in CoopGoreUpdateSkinTier / CoopGoreTryDripAttach / DropBloodPool); pools = dead ACTORS
  only, both sides incl. officer/wave/reinforcement.
- **bug-817** tuning pass: dial back uniform blood; pool darker (no bright arterial core) + smaller +
  9-step continuous grow; NEW AI-only exposed-skin marks; kill-splash reverted to pre-round-4.
- **bug-828** playtest round 2 — POOL brightness root cause = decal VERTEX-COLOUR tint (mark-poly path)
  drives rendered rgb, not the texture; N concentric rings over-blend-converge to the tint. Fix: pool
  setColor 0.50,0.03,0.03 → #150200 (0.082,0.008,0) so any ring count converges dark maroon; pool
  smaller (coop_bloodPool 44→32, POOL_END 1.15→0.72, steps 9→7); GORE_HOT 110,12,5→42,5,1 for
  consistent dark holes; **skin pivot** — removed generic face/hand tier overlay, rely on hit-location
  UV stamps (R_GoreSkelSurfaceCheck via RB_SkelMesh) for realistic wounds at true impact. sentient.cpp/.h,
  tr_gore.c, gen_gore_skins.py (cloth-only), gen_woundstamp.py.
- STATUS: mid-polish, needs game.dll + renderer_opengl1.dll rebuild + fresh playtest.

### The Armory — loadout + wardrobe (major expansion, v3.2)
- **bug-626** operator idle anim (was random pull-ups/pushups pool) → single idle; tabs 6-across
  overflow → 2×3 inside panel; skin+helmet buttons added. ui/coop_loadout.urc, anims_shared.txt.
- **bug-642** locked guns showed equipped / padlocks on wrong rows / stale locks — deny-revert helper,
  compound session cvar coop_loLkV<id> (locked AND on-active-tab), generator v3. loadoutpick.scr.
- **bug-645** bg-bake layout overlap caught by v3 layout-registry contract. gen_loadout3.py.
- **bug-646** pre-deploy review: join resend would WIPE archived challenge-earned picks (lazy unlock
  record NIL at join) — chal_ensure before the unlock gate; keepArchive on locked deny.
- **bug-666** cold main-menu armory: padlocks/helmet/skin dead offline — v3.2 client-side archived
  cvar chains (coop_loLkA<id>, helm/skin cfg chains), preview modelscale per class, FG42 override.
- **bug-707** one-per-class + unlock gate mirrored CLIENT-side for the disconnected main-menu armory
  (coop_loCmt<id> commit gate, coop_loWho_<class> registry). Parse-safe single-quote cfgs.
- **bug-716** self-review: client one-per-class registry stale when server cleared a primary (resend).
- **bug-656** idempotent re-pick early-out (equip sound looped on every resend/deny replay).
- **bug-657** serialized loadout_set per player (race let two same-class primaries commit).
- **bug-658** M1 Carbine preview blank — shipped missing garand.skc (idle anim) into carbine dir.
- **bug-659** padlock flicker — diff-only export + latest-wins generation stamp.
- **bug-660/661/662** preview fixes (pistols/nades upside-down/tiny → fit=1 scale=1 angles 0 90 180;
  requirement text 2-line word-wrap; info block regrid + narrower recoil box).
- **bug-682** lktab fail-LOCKED (was fail-open: no snapshot → everything showed unlocked).
- **bug-683** skin buttons unresponsive — charRender drag-rotate rect overlapped SKIN buttons; shrank.
- **bug-740** armory skin buttons sent BARE name-bus tokens (no data char → never dispatched) —
  absolute-page apply token recipe (coop_loASkin), armory_skin_set. urc + s01-28.cfg + helmet/player/loadoutpick.scr.
- **bug-755** locked-skin black hole (preview seta'd pick before gate; refused skin stayed archived,
  re-fired forever) — coop_loOpenSkin replay + revert-on-refusal snap-back; generator-drift fix (hand
  edits ported back into gen_loadout3.py).
- **bug-759** design: skip locked skins in the cycle (two-layer redirect chain) — later reversed.
- **bug-772** helmet row: same bare-token + locked-in-cycle defects as skins; ported the skin recipe
  (coop_loAHelm, armory_helmet_set, exportChain).
- **bug-773** helmet close-commit missing + empty-value push no-op (`set coop_loHelm` argc==2 →
  Cvar_Print) — hclear.cfg for "No Helmet"; lobby countdown default 10→5.
- **bug-787** DESIGN REVERSAL (pre-release, supersedes 759/772): show ALL skins+helmets with a lock
  icon + unlock-requirement text; preview may park on locked; server still refuses apply. Repurposed
  exportChain → exportLocks (coop_loCosLk / coop_loSkLkA / coop_loHmLkA); requirement text derived at
  generation time from challenge defs + rank unlocks. urc + init.cfg + s/h cfgs + helmet/loadoutpick/challenges.scr.
- **bug-786** removed dev-only FIT button from the armory header (kept console-reachable).
- **bug-802** INSTANT loadout at spawn — host-seed (loadout_hostSeed reads coop_lo1..4 via getcvar
  during forced-spectator first pass) + giveWeaponLoadout removes blind 0.1s deactivate wait
  (same-frame use/activate + spawnWeaponAssert corrector). No more default-gun-then-swap blip.
- **bug-803** locked-skin leak into next mission — preview pages no longer seta dm_playermodel/coop_loSkin;
  manageAliveSpawning strips a locked worn skin + self-heals archived cvars.
- **bug-627** spectate→rejoin lost picks (retain-inventory path never read picks) — force default/picks
  path when coop_loWeapons populated.
- **bug-618** DBNO revive lost armory pistol — inserted picks tier into the revive re-give chain.
- **bug-758** stufftext nested-quote truncation (coop_loLkA/coop_loCmt never created client-side) —
  unquoted values + client-side clr cfgs. rcon-verified on live m1l1.
- STATUS: largely landed; instant-spawn + lock UI need a confirming playtest.

### Ready-Up / briefing gate (NEW)
- **bug-641** briefing slides are fullscreen URC menus over ihuddraw → ship mod overrides of the 9
  retail slide URCs with the coopgate_* overlay appended as last widgets. gen_briefing_overlay.py.
- **bug-712** cvar-bridge push moved into the guaranteed-running arm/ready loop (was behind a fragile
  ihuddraw pass that stalled the whole briefing). readygate.scr.
- **bug-684** briefing map calls `drawhud 0` (kills custom ihuddraw slots) — coop_readyGateStart now
  forces `drawhud 1`.
- **bug-736** coop_gateSet wrapped values in escaped quotes → wire truncation ("Cvar does not exist")
  — send UNQUOTED + bounded force-resend every ~2.1s. readygate.scr.
- STATUS: landed for listen host; ultrawide-verified via log; playtest to confirm.

### Bleed-out audio (NEW)
- **bug-836** ubersound/coop_gurgle.scr (12 aliases, vol 0.55 / 150–1200u) + 12 curated wet
  death-rattle / bleed-out SFX + coop_mod/gurgle.scr::play (35% roll, 1–3s delay, proximity-gated,
  1–2 clips over the bleed-out window, NULL-guarded). Hooked in aihandler.scr (after bug-822 guard)
  + player.scr::manageDead. Cvars coop_gurgle/_chance/_range. pk3-only.

### Build-mode cover (NEW category)
- **bug-829** placed solid objects walk-through at large scale — MOHAA `scale` is visual-only for
  collision; coop_build_place now setsize base×scale on the live model + writes it into the saved
  build_<map>.dat block. buildmode.scr.
- Cat 34 **COVER OBJECTS**: 14 authentic static props (8 tall ≥90u wrecks/boulders, med boxes/carts/
  trough/rock), default SOLID on entry. buildmode_catalog.scr, buildmode.scr. (memory 07-18 23:35)

---

## Gameplay / AI
- **bug-617** AI grenades never exploded — Projectile::SetOwner only set m_iTeam for players; CheckTeams
  Sentient branch now mirrors the player TEAM_NONE exemption. weaputils.cpp. **game.dll.**
- **bug-621** actors block doorways for remote clients — IdleThink yielded only to entity 0 (host);
  now yields to nearest living player. actor_idle.cpp. **game.dll.**
- **bug-686** wounded Germans were bullet sponges — nolongpain skipped the only path decrementing
  coop_actorActualHealth; un-buffer to real hp first. wounded.scr.
- **bug-687** wounded/heal-retreat path oscillation — issue walkto/runto once, re-issue only on stall.
  wounded.scr, officer.scr.
- **bug-638** wounded-limp `remove` on a LIVE actor bypassed the death path (objective stall + NULL in
  coop_actorArray) — kill through the real damage path; re-engage on timeout. wounded.scr.
- **bug-619** weapons-on-back emptied when a long gun was raised — new UpdateCoopHolsteredWeapons pass.
  sentient_combat.cpp. **game.dll.**
- **bug-623** intermittent "holding guns backwards" — AttachGun saved poisoned holster angles into
  lastAngles; save only when !lastValid. weapon.cpp. **game.dll.**
- **bug-647** tank turret invisible to the manning player (e1l1 panzer) — SVF_NOTSINGLECLIENT set on
  remote-controlled cannons with no viewmodel, targeting client 0. Script mitigation (force 3P for the
  ride) shipped; engine root fix flagged in vehicleturret.cpp (`|| !m_pViewModel` + set singleClient).

## Challenges / progression / XP
- **bug-628** Service Record toast text too large — font sizes reduced. challenges.scr.
- **bug-718** self-review: duplicate/stale catLabel lines after the category reorg removed. challenges.scr.
- **bug-688** debrief rank-bar fill width 184→194 (under-reached groove). xp.scr.
- **bug-689** rank-up ping quiet — removed xp_ping_duck (dipped master s_volume). xp.scr.
- **bug-804** debrief XP bar "super glitchy" — stale-alpha race between popup fade and summary card;
  fade exits on summaryActive + singleton guards + per-segment alpha re-assert. xp.scr.
- **bug-805 / bug-819** mid-game + rank bar filler too big for the brass frame — clamp fill width +
  seat glint/fill in the measured groove. xp.scr, challenges.scr.
- **bug-788** XP debrief ran on briefing/lobby maps (paid mission awards for watching slides) — skip
  xp_summary when mapname contains 'briefing' or coop_lobbyMap. missioncomplete.scr.
- **bug-789** officer boss machinery ran on briefing maps — coop_officer_policy → 'none' on briefings.
- **bug-818** REGRESSION (from bug-804): real mission-end debrief cut short by a double
  mission-complete fire — idempotency guard level.coop_missionCompleteRan at top of main(). missioncomplete.scr.
- **bug-808** lobby unlock-list race — chal_add_unlock waitthreads chal_ensure before dedup; hud slot
  map corrected (lobby roster 100–114, SR panel 150–174+196–249, new NEW-UNLOCKS list 117–126).

## Audio
- **bug-775** MP taunts never audible — all 72 aliases pointed at retail taunt WAVs deleted from the
  shipped War Chest paks (ghost subtitles). Rebuilt coop_taunt.scr on audio VERIFIED present
  (GRden_r/v + AMdfr_r/v). flchatter.scr bounds updated + coop_flchatDebug trace. ubersound/coop_taunt.scr.
- **bug-717** bombing-run crater fires silent on e-series / most t-series — loopsound fire_med aliascache
  didn't cover those maps; switched to coop_snd_fire_small (all theaters). officer.scr.
- **bug-822** random death voices at level start — aihandler fired deathvox BEFORE the waitframe+null
  guard; a scripted `remove`/`delete` of a live actor synchronously resumes `waittill death`
  (Actor::Remove). Moved the deathvox call AFTER the guard (removals self-null; real kills persist a
  corpse). aihandler.scr. **(engine-verified, script-only fix.)**
- **bug-839** Major Grillo (m2l1) still spoke generic American combat barks — these are engine say-anim
  VO (CHAN_DIALOG 8), not our flchatter. New silenceNativeDialog helper (per-frame stopsound 7/8 while
  alive, never touches CHAN_VOICE 4 so story dialogue survives), gated on coop_noChatter. flchatter.scr, m2l1.scr.

## Menus / UI
- **bug-709 / bug-685** in-game ESC menu overlap (coop + MP button stacks) — engine enable/disable by
  name; then gate MP buttons on `!coop_active` (single-cvar mutual exclusion). cl_ui.cpp, dm_main.urc.
- **bug-745 / bug-767 / bug-777** ESC-menu zombie/mesh saga — hudList 1-based forward-removal left
  dangling Menu* (use-after-free), plus an unidentified per-frame re-show pump. Fixes: hudList
  FreeObjectList, CreateMenus duplicate-container dedup, draw-level guard in UIWidget::Display.
- **bug-831** RESOLUTION: coop custom ESC menu (coop_dm_main) fully REVERTED after 6 overlap reports;
  kept the genuine engine bug fixes (hudList, dedup, draw-guard now guarding stock dm_main only).
  Loadout access stays on main-menu ARMORY + lobby LOADOUT buttons. **exe rebuilt.**
- **bug-753** Video Options resolution — vanilla pulldown only offered 4:3 r_mode table (max 1600×1200);
  replaced with 11 modern entries incl 3440×1440 / 3840×2160 writing r_mode -1 + r_customwidth/height;
  sdl_glimp Borderless honors picked size. `video options.urc`, coop_defaults.cfg, sdl_glimp.c. **exe.**
- **bug-756** Display Mode pulldown barely clickable — PulldownMenu hit column sized by the menushader's
  native width, and 'menu_button_trans' doesn't exist (→16px default). Shipped a real transparent
  256×32 TGA + widened rect; engine widens single-title pulldowns to full client width. uilib/uipulldownmenu.cpp.
- **bug-710** coop menu options didn't persist — autoexec seta'd defaults AFTER the saved config every
  launch. New coop_defaults.cfg (51 menu-controlled defaults) exec'd BEFORE the saved config via a
  common.c hook. autoexec.cfg, coop_defaults.cfg, common.c. **exe.**
- **bug-757** removed Helmet Next/Prev + Emote bindable actions from Options>Controls (moved to Armory).
  ui/BIND.SCR.

## Engine / renderer
- **bug-708** gl1 SSAO swims/flickers on camera motion — hard step at absolute bias on a half-res mask +
  bilateral blur normalized by the volatile per-frame zFar. Fix: smoothstep onset/far-fade + fixed 4096"
  reference. tr_postprocess_gl1.c. **renderer_opengl1.dll.**
- (Gore renderer entries listed under Features above: bug-734/747/754/780/785/796/817/828.)

## Fixes (map/content)
- **bug-620** e1l2 mine detector stripped by armory regive / DBNO / respawn — new level.coop_missionItems
  tier (addMissionItemToEveryone). itemhandler.scr, dbno.scr, e1l2/Intro.scr.
- **bug-625** carried papers/binoculars lost on every DBNO revive path + armory regive — itemGetAll
  one-shot on down→up transitions; medkit self-revive chain + picks/mission-items. keyitems.scr, medkit.scr, loadoutpick.scr.
- **bug-624** e1l2 invisible wall after the intro jeep — remove leftover clip1..9 script_objects on
  control handoff. e1l2.scr, e1l2/Intro.scr.
- **bug-648** scoped G43 fired too slow — mod override g43sniper.tik firedelay 0.4→0.15 / dm 0.5→0.18
  (m1_garand cadence). pak-ordering win.
- **bug-809** M1 Carbine buttstock rendered white — carbine.shader mapped skin9 to a dead del/carbine
  path from the S93 donor import; repointed to textures/hobbscarbine/. Rebuilt zzzzz_xw_weapons.pk3.
- **bug-812** AUDIT (no change): swept all 9 xw shader files / 89 stanzas for bug-809-class dead paths;
  the only referenced-and-dead path (carbine1) was already fixed; 9 remaining dead paths unreferenced.

---

## In-flight / research (NOT shipped this cycle — for awareness)
- **"1936" + War Chest Restored prop mining** (_research/named_mods_objects.md, named_mods_object_assessment.md):
  download/diff only, nothing wired. ~30 new Spanish-Civil-War meshes (walls, trucks, T-26/BA-6 armor,
  monuments, Maxim HMG, foliage) as build-mode cover candidates; WCR yields only 4 cardchair furniture.
  IP/attribution caveat flagged — confirm reuse policy before importing.
- Gore final tuning + exposed-skin wound density (bug-828 direction), pending playtest.
- Story-VO cleanup beyond Grillo (bug-839) ongoing.
- Loadout v3 further work (loadout_v3_plan.md), player gore research (player_gore_research.md).

---

## Suggested version: v1.2.0
Prior releases v1.1.44–v1.1.48 were incremental patches. This cycle adds multiple new player-facing
systems (gore/blood, Armory loadout+wardrobe, ready-up briefing gate, bleed-out audio, build-mode
cover) plus engine-level renderer work — a feature milestone. Bump the minor to **v1.2.0**. (Use
v1.1.49 only if the team prefers a single rolling patch line.) Update manifests + latest.json and
rebuild all four binaries; deploy per build.ps1 (game.dll manual to GOG root).
