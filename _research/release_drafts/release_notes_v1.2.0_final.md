# HaZardModding Coop Mod — v1.2.0

The biggest coop update yet: a full combat gore & blood system, the Armory loadout + wardrobe, briefing ready-up, shellshock, and a huge build-mode object library. Updates automatically on your next launch.

## Headline features

**A brand-new combat gore & blood system.** Bullets leave wounds where they actually hit — UV-accurate bullet holes stamp onto enemy uniforms *and* exposed skin at the true impact point. Soldiers get progressively bloodier as they take damage, a soft blood splash blooms around each hit, and killing blows throw extra spray. Fallen soldiers — rank-and-file, reinforcements, and officer bosses on both sides — pool dark blood beneath them, and living wounded leave scattered drips. Dialed for a grounded, dark look, not comic-book crimson. Your own character stays clean by design.

**The Armory — full loadout & wardrobe.** Pick your kit from a 69-weapon roster across six classes (rifle / sniper / SMG / heavy / pistol / grenade) with a live 3D preview, stat/caliber/recoil readouts, and one-weapon-per-class rules. Locked weapons show a padlock with the exact unlock requirement. Cycle player **skins** and **helmets** with the same lock/unlock display. The Armory opens from the main menu (even offline) and the in-mission lobby, and your picks now apply **instantly** the moment you spawn.

**Ready-Up on the briefing screen.** Mission briefings show a live squad roster with per-player ready checkmarks and a "Press F to Ready Up" prompt. Once everyone's ready, a 5-second countdown launches the mission — no waiting on the slowest reader.

**Shellshock & bleed-out audio.** Explosions near you now ring your ears — scaled by how close, and it triggers even for near-misses and blasts behind cover, not just direct hits. Fresh corpses get a quiet wet death-rattle and a blood-leak trickle for a few seconds during the bleed-out.

**A huge build-mode object library — 40 placement categories.** Authentic cover (wrecked tanks/trucks/armored cars, a 7.5cm AT gun, Kübelwagen, sandbags, walls, boulders, concrete), pre-posed static soldiers and gun crews to populate positions without spawning AI, plus period props, market clutter, signage, and foliage. Scaled objects are now genuinely solid, so the cover system can use anything you place.

## What's new by category

### Gameplay
- Enemy AI grenades now actually explode (they were silently fizzling).
- Allied AI (paratroopers, escorts) step aside for the nearest player in doorways.
- Wounded/retreating Germans are no longer bullet sponges and no longer pace stuck in place.
- Weapons-on-back holstering hardened; the intermittent "gun held backwards" glitch is fixed.

### Gore & blood
- UV bullet-hole wounds at the true hit location on uniforms and exposed skin.
- Multi-tier blood-soaked uniforms, per-hit blood splash, killing-blow spray.
- Growing dark blood pools under dead soldiers (all AI, both sides, including bosses); living wounded drip and trickle.
- Tuned dark and grounded; players never show body wounds or pool blood.

### Cover & Build-mode
- Object library expanded to **40 categories** — cover-grade vehicles/wrecks, an AT gun, posed static soldiers, period props, foliage, market clutter and signage.
- Fixed placed objects being walk-through at large scale — build pieces are genuinely solid at any size, and saved builds reload solid.

### Armory & Loadout
- 69-weapon picker, six classes, live 3D preview, stat/caliber/recoil readouts, one-per-class.
- Locked weapons and cosmetics show a padlock + unlock requirement text.
- Works offline at the main menu and in the lobby; picks apply instantly at spawn.
- Loadout survives spectate-and-rejoin, DBNO revives, and respawns; mission-critical items (mine detector, papers, binoculars) are never stripped by revives or re-gives.

### Challenges & Progression
- New **"Unlocked This Mission"** debrief list — see exactly what you earned that map.
- Service Record toasts and the rank-up debrief/mid-game bars re-fit to their frames (no more filler bulge); rank-up ping plays at full volume.
- Lobby "new unlocks" list hardened against reconnect duplicates.
- XP debrief no longer runs (or hands out awards) on briefing/lobby maps.

### Audio
- MP taunts now actually play — both sides were silent; rebuilt on audio that ships with the game.
- Wet bleed-out / death-rattle SFX and a blood-leak trickle near corpses.
- Bombing-run crater fires are now audible on all theaters.
- Story characters Major Grillo and Manon no longer blurt generic American combat lines.
- No more random enemy "death" grunts at the start of levels (from scripted actor cleanup).

### Menus & UI
- **Video Options:** a modern resolution picker including widescreen/ultrawide (up to 3840×2160 and 3440×1440), first-launch native-resolution auto-detect, and an easy-to-click Display Mode selector (Borderless / Fullscreen / Windowed).
- **Options persist** — coop menu settings save and survive a restart.
- ESC menu returned to the clean stock layout; Armory UI polish (tabs, previews, buttons, padlocks).

### Engine
- gl1 ambient-occlusion (SSAO) no longer swims/flickers on camera movement.
- Tank turret is visible to the player manning it (e1l1 panzer).
- Explosion shellshock, the gore renderer pipeline, and menu/HUD stability fixes.

### Fixes (selected)
- e1l2: removed a leftover invisible wall on the side path; mine detector and papers no longer lost on revive/respawn.
- M1 Carbine white-stock and scoped G43 fixes (G43 now fires like a proper semi-auto).

---

**How to get it:** launch the game — the in-game updater downloads v1.2.0 automatically. The **Report a Bug** tool in-game is the fastest way to send feedback.

## Why v1.2.0?
v1.1.44–v1.1.48 were incremental patches. This cycle adds multiple brand-new player-facing systems — the gore/blood suite, the Armory loadout + wardrobe, briefing ready-up, shellshock, bleed-out audio, and a 40-category build-mode object library — plus engine-level renderer work. That's a feature milestone, so a minor bump to v1.2.0.
