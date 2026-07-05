# MOH Coop Trilogy — mod source (HZM Extended)

This repository is the **mod source tree** for [MOH Coop Trilogy](https://github.com/MOHCoopTrilogy/releases): game scripts (`.scr`), configs, UI, sounds, and textures for cooperative play through all three *Medal of Honor: Allied Assault War Chest* campaigns (Allied Assault, Spearhead, Breakthrough) on OpenMOHAA.

It is a fork of the original **[HaZardModding Coop Mod](https://github.com/HaZardModding/hzm-mohaa-coop-mod)** by chrissstrahl / HaZardModding — all coop-framework credit belongs there. Development happens on the `coop-wip` branch; large binary assets (HD packs, built pk3s) are intentionally not tracked here and ship via Releases instead.

**Just want to play?** Don't clone this — get the installer from the [MOH Coop Trilogy releases page](https://github.com/MOHCoopTrilogy/releases). It bundles this mod, the engine, and all HD content, and auto-updates at launch.

## Related repos

- [MOHCoopTrilogy/releases](https://github.com/MOHCoopTrilogy/releases) — downloads, auto-update manifest, feature overview, build & installer pipeline
- [MOHCoopTrilogy/openmohaa](https://github.com/MOHCoopTrilogy/openmohaa) — the custom engine fork this mod runs on (GPLv2; upstream [openmoh/openmohaa](https://github.com/openmoh/openmohaa))

## Building

There is nothing to compile — `.scr` scripts are loaded at runtime by the engine. The mod ships as pk3 archives: `build.ps1` in the [releases repo](https://github.com/MOHCoopTrilogy/releases) packs this tree into `zzzzzz_co-op_hzm_mod_code.pk3` (scripts/UI/config) plus sound and texture asset pk3s, and deploys them to a local install for testing. For a quick manual test you can also zip the tree yourself as a `.pk3` into the game's `maintt/` folder, per the original HZM instructions.

## Legal

An independent, non-commercial fan project — not affiliated with, endorsed by, or sponsored by Electronic Arts, 2015 Inc., or any other rights holder of the Medal of Honor series. Medal of Honor and all related trademarks and assets remain the property of their respective owners. A legitimate copy of *Medal of Honor: Allied Assault War Chest* ([GOG](https://www.gog.com/game/medal_of_honor_allied_assault_war_chest)) is required. See [hzm_legal.txt](hzm_legal.txt) for the original mod's full legal notice and [hzm_credits.txt](hzm_credits.txt) for original credits.
