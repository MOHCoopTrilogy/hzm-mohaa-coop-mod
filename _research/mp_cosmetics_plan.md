# MP Armory Cosmetics — plan (skin / helmet / gloves, side-specific, carried over)

Status: PLAN for approval (2026-09-15). No code written yet.
Goal (user): the Allied, Axis and coop loadout screens should look and function basically the same —
pick your kit + skin/helmet/gloves, hit DONE, spawn — the difference being weapons and skins are
side-specific and MP choices carry between servers like coop's do.

## The hard constraint (why MP can't be a literal copy of the coop loadout)
The coop loadout (`ui/coop_loadout.urc`) drives every cosmetic row with **`vstr`**, which the MP
isolation contract **bans in the MP UI** (clause 18 — vstr is how a hostile client could smuggle a
command past the server filter). So MP cannot share the coop file. It must use the **MP mechanism the
weapon armory already uses**: each option is a generated static `.cfg` that `seta`s the pick and
`append name`s a `,q` name-bus marker; the server reads the marker, validates it, and applies it. The
result feels the same to the player; it is just built the MP-safe way.

## Where the data comes from (research findings)
- **Skins** live in `coop_mod/helmet.scr` (`armory_skin_build` → `level.coop_armorySkins[1..135]`), NOT
  `loadoutskins*` (those are weapon finishes). Bodies are worn as the hatless twin
  `models/player/<skin>_nohat.tik`. **All 135 are Allied** (US / British / Russian); there is **no
  nationality field** and **no Axis body ships** (`helmet.scr:952`).
- **Helmets**: `level.coop_helmetName/Tik[1..47]` — headgear spanning US/Brit/German/Italian/Soviet;
  applied by `helmet_apply` (hatless-twin swap + surface nodraw + attach to Bip01 Head). No side field.
- **Gloves**: `level.coop_gloveName/Tok[0..6]` (7) — applied by a hand-surface skin-bit swap + the 1P
  cvar `coop_gloveIdx`. No side field.

## ⚠️ Decision needed: Axis skins
"Reuse coop's skins by side" fully stocks the **Allied** side (filter the 135 by prefix:
`american_*`/`allied_*`=US, `allied_british_*`=GB, `allied_russian_*`=RU). But coop ships **no Axis
character bodies**, so there is nothing to "reuse" for Axis. Options:
- **A (ship now, Allied-rich / Axis-stock):** Axis skin row offers the stock German DM models the
  engine already carries (`dm_playergermanmodel` set: german_wehrmacht_soldier, waffenss, afrika, etc.
  — a handful). Allied gets the full coop roster. No new art; ships this pass. *Recommended.*
- **B (parity later):** build the `hzmax_` Axis body set first (armory slice step 9b, not yet built),
  then both sides are rich. Bigger, needs art decisions.
- **C:** Axis gets helmet + glove choices only (no body pick) this pass; bodies later.
Helmets and gloves are shared rosters (headgear/hands), so both sides can offer the full lists.

## Work items (all mirror the existing weapon-armory machinery)
1. **Generated side-split cosmetic rosters + option cfgs** (extend `docs/tools/gen_mp_armory.py`):
   - `coop_mod/mp<side>_skins.scr`, `mp<side>_helm.scr`, `mp<side>_glove.scr` — `roster_get`-style
     tables (id → tik/name/nat), Allied filtered from `coop_armorySkins`, Axis per the decision above;
     helmet/glove tables built from the coop lists.
   - per-option cfgs under `ui/coop_mp<side>_armory/` (skin `k<NN>.cfg`, helmet `h<NN>.cfg`, glove
     `g<N>.cfg`): `set` the preview + `seta` the pick + `append name ,q<side><f><data>` (f = k/h/g).
   - a new source TSV or a filter over the coop data; deterministic, ASCII, emitter-checked like today.
2. **Name-bus grammar** (`mp_armory.scr::mp_bus_families` + `readMarkers` + `applyMarker`): add the
   `k` (skin) / `h` (helmet) / `g` (glove) field families; `applyMarker` validates the id against the
   side roster and stores `coop_mp_SKIN` / `coop_mp_HELM` / `coop_mp_GLOVE` flags. (The `readMarkers`
   scanner already handles multi-char data; k/h/g are new single-letter fields alongside 1/2/3/d.)
3. **Apply at spawn** (`mp_armory.scr::giveKit`, which today does weapons only): after the weapon give,
   set the body model (`player model models/player/<skin>_nohat.tik`, side-correct), then run the same
   helmet + glove surface work coop uses (call into a small MP-owned helper that mirrors `helmet_apply`
   / `glove_apply` WITHOUT calling coop code — isolation clause 10). Health/kit unchanged.
4. **Carry between servers** (E1 pattern, `cg_main.c` mp_kit_userinfo block): register
   `coop_mp<side>_skin/_helm/_glove` as USERINFO|ARCHIVE; the option cfgs `seta` them; the server reads
   them with `info_valueforkey` on connect and re-applies. ~30 bytes each, inside the ~630-byte budget.
5. **UI rows** on `ui/coop_mp<side>_armory.urc` (generated): add SKIN / HELMET / GLOVES rows mirroring
   the coop loadout's layout but with prev/next buttons that `exec` the static option cfgs (no vstr),
   plus the model preview (rendermodel + modelattachcvar for the helmet, like coop). Fonts limited to
   the two safe ones (bug-519).
6. **Coop parity pass**: align the three screens' visual layout so Allied/Axis/coop read the same
   (same row order, captions, preview placement) — cosmetic only, no coop behaviour change.

## Decisions (locked 2026-09-15 by user)
1. **Axis skins: B** — build a real `hzmax_` Axis body set so both sides have a rich roster. Axis bodies
   are armory-only tik forks of existing shipped Axis models (German/Italian/Waffen-SS/Afrika from the
   stock + HRRTM sets) under `hzmax_<stem>` names, with the hatless-twin + std-helmet fork the helmet
   system needs (armory slice Plan 5 / step 9b recipe). No brand-new art; content is forked tik data.
2. **Unlocks: EARNED via challenges** (both sides). A new MP challenge catalogue (I design it) grants
   cosmetic unlocks; extends the slice-4 progression counters. Weapons keep their per-class unlocks;
   cosmetics get their own named challenges (e.g. "Allied Rifleman I: 25 rifle kills → unlock <skin>").
3. **Helmet/glove side split: NO** — both sides offer the FULL helmet + glove lists.

## Build order (dependency-first; each checkpoints + you playtest)
1. **Cosmetic apply at spawn** — extend `mp_armory.scr::giveKit` to set body model + helmet + glove
   from `coop_mp_SKIN/HELM/GLOVE` flags (MP-owned helper mirroring `helmet_apply`/`glove_apply`, no coop
   call). Verify by forcing a cosmetic on a bot and confirming the model/surface applies (diagnostic).
2. **Axis body set** — generate the `hzmax_` Axis tik forks + their `_nohat`/std-helmet twins.
3. **Generated cosmetic rosters + option cfgs + UI rows** — `gen_mp_armory.py`: side-split skin roster
   (Allied from coop_armorySkins by prefix; Axis from the hzmax_ set), shared helmet/glove lists, the
   `k/h/g` option cfgs, and the SKIN/HELMET/GLOVES rows on both armory URCs (no vstr).
4. **Name-bus grammar + validation** — `mp_bus_families`/`readMarkers`/`applyMarker` gain `k/h/g`
   fields; `applyMarker` validates the id against the side roster AND the cosmetic-unlock state.
5. **Userinfo carry** — `coop_mp<side>_skin/_helm/_glove` USERINFO|ARCHIVE (cg_main.c), read back on
   connect (one cgame.dll rebuild).
6. **MP challenge catalogue + cosmetic unlock gating** — `coop_mod/mp_challenges.scr` (MP-owned, forked
   pattern from coop's `chal_def`, NOT calling coop): named per-side challenges over the progression
   counters that set `coop_mpUnlockCos_<id>` flags; the armory gates each cosmetic tile on its unlock,
   and the Service Record panel (slice 6) gains a challenges/cosmetics view.

## Verification reality
None of this is bot-verifiable (bots don't open the armory). Each piece will be built to parse-clean +
isolation-clean + emitter-checked, but the actual UX (rows render, picks apply, cosmetics show, choices
carry across a reconnect) needs a human client. Expect a build → you playtest → I fix loop, like the
Service Record panel.

## Rough size
Medium-large: item 1 (generator) and item 5 (UI) are the bulk; 2–4 are contained script/engine edits
mirroring existing patterns. One cgame.dll rebuild (item 4). No new exe. Isolation clauses unchanged
(all tokens are coop_mp*, all cfgs under ui/coop_mp*, all vstr-free).
