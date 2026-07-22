# HaZardModding Coop Mod — v1.2.0 (DRAFT — NOT PUBLISHED)

> **LIVING DRAFT.** The v1.2.0 feature set is still landing — the gore/blood system is
> mid-polish, exposed-skin wounds and the growing blood pools are being tuned per playtest,
> the build-mode cover pass and the period-prop object mining ("1936" set) are in flight, and
> story-character voice cleanup is ongoing. Treat every line below as provisional and re-verify
> against the final build before publishing. Several headliners (gore, armory instant-spawn,
> ready-up gate) require the rebuilt engine binaries and a fresh playtest pass to be confirmed.
>
> Suggested version: **v1.2.0** (minor bump, not a patch) — see note at the bottom for why.

---

## Headline features

**A brand-new combat gore & blood system.** Bullets now leave wounds where they actually hit —
UV-accurate bullet holes stamp onto enemy uniforms *and* exposed skin at the true impact point,
soldiers get progressively bloodier as they take damage (multi-tier blood-soaked uniforms), a
soft blood splash blooms around each hit, and killing blows throw extra spray. Fallen soldiers —
rank-and-file, reinforcements and officer bosses alike, on both sides — slowly pool blood beneath
their bodies, and living wounded leave scattered drips. It's dialed for a grounded, dark look
(not comic-book crimson). Your own character stays clean of body wounds and pooling by design.

**The Armory — a full loadout & wardrobe picker.** Pick your kit from a 69-weapon roster across
six classes (rifle / sniper / SMG / heavy / pistol / grenade), with a live 3D preview, stat bars,
caliber and recoil readouts, and one-weapon-per-class rules. Weapons you haven't earned show a
padlock with the exact unlock requirement. Cosmetics live here too: cycle player **skins** and
**helmets** with a matching lock icon and unlock text on the ones you haven't earned yet. The
Armory opens from the main menu (even offline) and from the in-mission lobby, and your picks now
apply **instantly** the moment you spawn — no more spawning with the map's default gun and
swapping a beat later.

**Ready-Up on the briefing screen.** Campaign mission briefings now show a live squad roster with
per-player ready checkmarks and a "Press F to Ready Up" prompt. Once everyone's ready, a short
5-second countdown launches the mission — no waiting on the slowest reader.

**Atmospheric bleed-out audio.** Occasional, quiet wet death-rattle / bleed-out SFX now play near
fresh corpses for a few seconds after death, matching the visible blood — subtle, positional, and
rate-limited so it never turns into a chorus.

---

## What's new by category

### Gameplay
- Enemy AI grenades now actually explode — allied and German thrown grenades were silently fizzling.
- Allied AI (paratroopers, escorts) step aside for the nearest player in doorways, not just the host.
- Wounded/retreating Germans are no longer bullet sponges and no longer pace back-and-forth stuck.
- Weapons-on-back holstering hardened: carried weapons stay visibly stowed, and the intermittent
  "holding my gun backwards" glitch is fixed.
- Officer boss reinforcement/heal behavior smoothed (no more path-thrash oscillation).

### Gore & blood
- Four-tier gore: UV bullet-hole wounds at the true hit location, blood-soak uniform tiers, per-hit
  blood splash, and killing-blow spray.
- Growing blood pools under dead soldiers (all AI, both sides, including bosses); living wounded drip.
- Wounds land on exposed skin (faces/hands) at the actual bullet impact, not random spots.
- Tuned dark and grounded; players never show body wounds or pool blood on themselves.

### Cover & Build-mode
- New **Cover Objects** build category: authentic static props (wrecked tanks/trucks/cars, boulders,
  concrete blocks, carts) that default to solid so the cover system can use them.
- Fixed placed objects being walk-through at large scale — build pieces are now genuinely solid at
  any size, and saved builds reload solid.

### Armory & Loadout
- 69-weapon picker, six classes, live 3D preview, stat/caliber/recoil readouts.
- One-weapon-per-class enforcement; locked weapons show a padlock + unlock requirement text.
- Skin and helmet wardrobe with lock icons and unlock text on un-earned cosmetics.
- Works offline at the main menu and in the lobby; picks apply instantly at spawn.
- Loadout now survives spectate-and-rejoin, DBNO revives, and respawns; mission-critical items
  (mine detector, papers, binoculars) are no longer stripped by revives or loadout re-gives.

### Challenges & Progression
- Service Record challenge toasts resized to fit cleanly on screen.
- End-of-mission rank-up debrief bar and mid-game rank bar re-fit to their frames (no more filler
  bulging out); rank-up ping plays at full volume.
- Challenge categories cleaned up; lobby "new unlocks" list hardened against reconnect duplicates.
- XP debrief no longer runs (and no longer hands out mission awards) on briefing/lobby maps.

### Audio
- MP taunts now actually play — both sides had been silent; rebuilt on audio that ships with the game.
- New wet bleed-out / death-rattle SFX near corpses.
- Bombing-run crater fires are now audible on all theaters (were silent on many maps).
- Story character Major Grillo no longer blurts generic American combat lines.

### Menus & UI
- **Video Options:** a modern resolution picker including widescreen/ultrawide (up to 3840×2160,
  3440×1440), plus an easy-to-click Display Mode selector (Borderless / Fullscreen / Windowed).
- **Options now persist** — settings changed in the coop menus save and survive a game restart.
- Armory UI polish: fixed tab overflow, model previews, skin/helmet buttons, and padlock rendering.
- Removed a dev-only "FIT" tuning button from the Armory header.

### Engine
- gl1 ambient-occlusion (SSAO) no longer swims/flickers when the camera moves.
- Tank turret is now visible to the player manning it (e1l1 panzer).
- Several stability fixes around menu handling and HUD lists.
- Renderer gore pipeline (bullet-hole stamping, blood pools, kill splashes) built into gl1.

### Fixes (selected)
- e1l2: removed a leftover invisible wall blocking the side path after the intro jeep.
- e1l2 mine detector and story papers no longer lost on revive/respawn.
- Random enemy "death" grunts at the start of many levels (from scripted actor cleanup) silenced.
- M1 Carbine and scoped G43 fixes (missing preview/texture; G43 now fires like a proper semi-auto).

---

## Notes for testers
- This build needs the updated engine binaries (they ship via the in-game updater). Gore, instant
  loadout, and the ready-up gate depend on them.
- The in-game **Report a Bug** tool is the fastest way to send feedback.
- Known in-flight areas this cycle: final gore tuning, exposed-skin wound density, build-mode cover
  object roster, and story-VO cleanup.

---

## Why v1.2.0 (not v1.1.49)?
The last several releases (v1.1.44–v1.1.48) were incremental patches. This cycle adds **multiple
brand-new player-facing systems** — the gore/blood system, the Armory loadout + wardrobe picker,
the briefing ready-up gate, bleed-out audio, and a build-mode cover category — plus engine-level
renderer work. That's a feature milestone, not a patch, so a minor bump to **v1.2.0** communicates
the jump. (Fall back to v1.1.49 only if the team prefers to keep the single rolling patch line.)
