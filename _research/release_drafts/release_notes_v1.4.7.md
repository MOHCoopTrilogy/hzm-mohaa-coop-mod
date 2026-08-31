**A repair release. One of these is a bug we shipped in v1.4.6, and two are security fixes.**

**Officer reinforcement waves are sized correctly again.** v1.4.6 introduced a fault that made every officer wave compute its size from the wrong value, so wave sizes came out empty. Maps built around held positions — m3l2 especially — were affected most. Fixed at the root, and it was caught by the automated regression suite rather than by a player, which is the point of having one.

**Two security fixes, both worth knowing about.**

The first: cheat commands could be triggered by any player, on any server, just by changing their name. God mode, noclip and give-all-weapons were reachable through the in-game command bus with no authentication of any kind. They now require a developer login. If you play on a public server, this one mattered.

The second: the remote-console password shipped inside the mod itself, identical on every install. Anyone with the mod could take remote console on anyone else's listen server. It no longer ships at all — servers have no rcon password unless the host sets one deliberately.

**New ground textures.** A CC0 terrain replacement pack covering the campaign. It was built two updates ago and, through a packaging mistake, never actually reached anybody — it existed only on the developer's machine. It ships now.

**Naming.** The coop button in Multiplayer and a leftover menu footer still read "HaZardModding". They now read MOH Trilogy Coop, which is what this project is called.

**The installer got a pass too.** You can choose where it installs — previously that page was hidden if you already had the mod, so most people never saw the option. It now also refuses folders that would damage something: your Medal of Honor install, an existing OpenMOHAA installation, or anywhere inside your game folder. And it checks you have all three games (Allied Assault, Spearhead, Breakthrough) instead of accepting a partial install and failing later.

Updating is automatic on your next launch. If you are several versions behind, you will get everything in one pass — the updater compares file fingerprints rather than stepping through releases.
