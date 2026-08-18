# Skin variant selector — build plan

[user 2026-08-18] Design research requested: "how we will build the skin variant in the Loadout
menu including the existing locks icon and unlock conditions. we need to make the selector for
skins intuitive so we don't just end up with a long list of weapons to select."

Everything here plugs into plumbing that already exists and is playtest-proven. No new mechanism
is invented; the strip is a second, small instance of the per-gun lock/commit pattern.

## The shape

**Variants never get tiles.** The picker keeps exactly the 75 base-gun tiles it has today. A
**finish strip** — one row of small fixed buttons under the preview pane — carries everything
else:

```
[ STANDARD ][ GOLD ][ CHROME ][ BLUED ][ BLOODY ][ WOODLAND ][ WINTER ][ DESERT ]  [ M1928 ]...
   8 fixed finish buttons, always present                     model-variant buttons, appear
   lock icon overlay per finish (lktab pattern)               only for guns that have them
```

- 8 fixed widgets total for finishes, independent of gun count (the reason this can't become
  "a long list": the strip is per-FINISH, not per-variant; 45 guns x 7 finishes = 315 variants
  ride on 8 buttons).
- Model variants (PA Tommy M1928, PA BAR, PA Garand, Reactivated MP40) are a handful of extra
  fixed widgets that only enable while their host gun is selected — `enabledcvar` set by the
  host gun's `t<id>.cfg`, cleared by every other gun's via the existing `who/clr` pattern.

## Flow

1. Player clicks a gun tile — commits the BASE gun into the active slot, exactly as today.
2. Player clicks a finish — the strip button fires a name-append bus token (`,wf1gold` = slot 1,
   gold). No new transport: same bus the tiles already use.
3. Server validates BOTH conditions (finish challenge complete AND that gun's per-weapon mastery
   challenge complete), then rewrites the slot give to the variant tik and stuffs back
   `seta coop_loS1F gold` (client persistence) + `set coop_loPrev <variant tik>` + re-open
   inspect, so the preview swaps to the finished gun immediately.
4. Deny path mirrors `coop_loDeny`: beep + requirement line ("BLOODY: 250 melee kills — 137/250"
   or "Master this weapon first — 12/25 kills").

## Locks

- The 8 strip lock icons show the ACCOUNT-WIDE finish unlock only — 8 new cvars
  (`coop_loLkFgold`...) exported by `loadout_ui_exportUnlocks` with the same
  archived-`seta` + fail-locked-`lktab`-seed pattern as the per-gun locks (bug-758 rules apply:
  unquoted stufftext, no semicolons on the wire).
- The per-gun mastery gate is deliberately NOT an icon: it would need finish x gun cvars
  (8 x 45 = 360). It is enforced server-side on click with the deny line naming the remaining
  kills. Icon = "you don't have this finish"; deny text = "this gun isn't mastered yet".
- Spawn-time resolution re-checks both conditions server-side — the client cvars are
  convenience, never authority.

## Unlock conditions

7 finish challenges (account-wide, one each — agreed design, tune numbers at build):

| finish | challenge |
|---|---|
| Gold | 2,500 career kills |
| Chrome | complete any mission with no deaths |
| Blued | 500 career headshots |
| Bloody | 250 melee/bash kills |
| Woodland | 300 kills on AA-campaign maps |
| Winter | 300 kills on snow maps |
| Desert | 300 kills on North-Africa maps |

Model variants cost ZERO new challenges: each unlocks at its host gun's existing **Elite** tier
(M1928 at Thompson Elite 75 kills, PA BAR at BAR Elite, PA Garand at Garand Elite, R2 MP40 at
MP40 Elite). Mastery gate for applying a finish = the gun's base per-weapon challenge (25 kills),
which 68 guns already have.

## Spawn resolution

`gen_skins.py` gains a third output: `coop_mod/loadoutskins.scr::skin_resolve`, a generated
lookup `level.coop_skinGive[baseGive][finish] -> variant path` (Morpheus arrays key on strings).
The spawn path asks it once; empty result = fall back to base give. Generated, so it cannot
drift from the actual variant tiks — same argument as roster_ids.

## Imported model-variant packs (downloaded 2026-08-18, in `_variant_packs/`)

All four ship their own .shader = cheap imports under the East re-path recipe (private mesh
path, private textures, `coop_*` shader names, tik derived from OUR gun so tuning/holster carry):

| pack | variant | pk3 | notes |
|---|---|---|---|
| Vdog77 MP40 (Reactivated 2 mesh) | "MP40 (Reactivated)" | zzzuser-MP40.pk3 | ships own clip model |
| MOHPA port | "Thompson (M1928)" | zzzzzzzz-PA Tommy.pk3 | own clip + viewmodel reload anim + sounds |
| MOHPA port | "BAR (Pacific)" | zzzzzzzz-PA Bar.pk3 | own clip model + sounds |
| MOHPA port | "M1 Garand (Pacific)" | zzzzzzzz-PA M1 Garand.pk3 | sounds |

MOHPA pack author is NOT listed on the page or in the tiks — credit line pending; the research
agent is hunting the original porter's name. Vdog77 is credited on-page (mesh from Reactivated 2).

**Import hazards learned this trilogy, all apply:** surfaces must be read from each pack's OWN
skd, never inherited (bug-1912); animations referenced bare (bug-1905); rank from the variant
band, asserted unique; `CoopStripSkinSuffix`-compatible names ("Base (Variant)") so hands + ADS
tuning resolve to the base gun; run `check_tik_surfaces.py` + `resolve_basetex.py` after each.

**The clip-model discovery:** both the MP40 and Tommy packs replace `models/ammo/<gun>_clip.tik`
alongside the gun — community-confirmed that this file IS the in-hand reload magazine. Our
finish variants should ship reskinned clip tiks the same way once the reference point (who
spawns it) is found — still open in OPEN.md.

## Build order

1. Finish strip UI + 8 lock cvars + export lines + bus tokens + server validation (the core).
2. `skin_resolve` generated table + spawn-path hook + server-side re-check.
3. The 7 finish challenges (chal_def + resolver entries at top of chain, per bug-1897 rule).
4. Import the four model-variant packs (East recipe), wire as strip variants.
5. Reskinned clip tiks once the magazine reference point is identified.
