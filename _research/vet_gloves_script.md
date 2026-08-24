# Adversarial vet — ARMORY GLOVES (bug-2080), 2026-08-23

Scope: `coop_mod/gloves.scr` + every file the glove row touches, plus the three generators
(`docs/tools/gen_gloves.py`, `gen_glove_ui.py`, `armory_unlocks.py`) and the engine sites the script
contract depends on. Nothing was modified except this file.

**Verdict: NOT SHIPPABLE.** Two blockers make the third-person half of the feature a no-op or wrong
for most players, and a third defect means the pick is not persisted or committed by any of the four
mechanisms every other armory row uses.

Severity key: **blocker** = feature is wrong/dead for a normal player · **bug** = wrong behaviour in a
reachable path · **risk** = latent / depends on an unverified premise · **nit** = cosmetic or comment.

---

## 1. BLOCKER — the 3P glove never reaches the model a player actually wears (`_nohat.tik`)

`gen_gloves.py:139-155` authors glove shader lines into `models/player/<skin>.tik` and
`<skin>_fps.tik`. It does **not** touch `models/player/<skin>_nohat.tik` — and the hatless twin is
what every armory player is actually dressed in:

- `coop_mod/helmet.scr:1381` — `local.player model ( "models/player/" + local.skin + "_nohat.tik" )`
  (the armory uniform apply)
- `coop_mod/player.scr:1282` — the spawn re-force, same `_nohat` path
- `coop_mod/player.scr:1320` — the locked-skin heal, `"american_army_nohat.tik"` as the free default
- `ui/loadout/init.cfg:40` and every `ui/loadout/skin/sNN.cfg:2` — the armory preview model

Measured: 135 `_nohat.tik` files exist in `hzm-mohaa-coop-mod/models/player/`; **0** carry the
`gen_gloves.py` tag. `american_army_nohat.tik:29` has exactly one `surface hand shader handsnew`, so
`numskins == 1` on `hand`.

The renderer then discards the index outright — `renderergl2/tr_model.cpp:1321-1325` (and
`renderergl1/tr_model.cpp:964-968`):

```c
int iShaderNum = ent->e.skinNum + MDL_SURFACE_SKININDEX(*bsurf);
if (iShaderNum >= dsurf->numskins) { iShaderNum = 0; }
```

**Player-facing:** pick any glove, look at yourself in third person or at a teammate — bare hands.
It works only for a player who has *never* used the armory uniform row (the engine's `InitModel`
gives them the base `<skin>.tik`, which *was* authored). So the row breaks for exactly the audience
it was built for, and it breaks *the moment they change uniform*, which reads as intermittent.

Compounding: because `<skin>_nohat_fps.tik` does not exist either (0 files),
`cg_modelanim.c:2357-2373` falls back to `CG_GetPlayerLocalModelTiki(dm_playermodel->resetString)`
= the **default** `american_army_fps.tik`, which *is* authored — so first person shows the glove
while third person does not. That is precisely the mismatch `gloves.scr:16-18` and
`cg_modelanim.c:2398` call "worse than having no gloves at all", with the two views swapped.

---

## 2. BLOCKER — the index contract holds in three places and breaks in the fourth (the TIKI)

Asked check #2 was "verify all three agree". They do, exactly:

| index | `gloves.scr:33-56` | `gen_glove_ui.py:33-41` | `gen_gloves.py:43-58` | `ui/loadout/glove/gNN.cfg` |
|---|---|---|---|---|
| 0 | Bare Hands | Bare Hands | (model's own) | g00 "Bare Hands" |
| 1 | Leather Gloves | Leather Gloves | `l_gloves` | g01 |
| 2 | Wool Knit Gloves | Wool Knit Gloves | `knitgloves1` | g02 |
| 3 | US Winter Gloves | US Winter Gloves | `handssnow` | g03 |
| 4 | Wool Mittens | Wool Mittens | `mittens2` | g04 |
| 5 | Seaman's Gloves | Seaman's Gloves | `seaman_gloves` | g05 |
| 6 | Alpine Hands | Alpine Hands | `hands_snow1` | g06 |

**The authority none of them consulted is the TIKI's positional skin list.**
`gen_gloves.py:92-112` inserts after the **last** existing `surface <name> shader` line, and
`tiki_parse.cpp:878-948` dedupes `SETUP_SURFACE` by name, so *every* `surface hand shader` line in a
file accumulates into one ordered list — index = position.

Swept all 133 authored 3P tiks: 132 have exactly one base line (glove N lands at index N, correct).
**One does not** — `models/player/allied_russian_crazy_boris.tik` has two base lines,
`handsnew` at :9 and `handssnow` at :21, so the real mapping on that uniform is:

| script asks | TIKI delivers |
|---|---|
| 1 Leather | `handssnow` (US Winter) |
| 2 Wool Knit | `l_gloves` (Leather) |
| 3 US Winter | `knitgloves1` (Wool Knit) |
| 4 Mittens | `handssnow` |
| 5 Seaman's | `mittens2` |
| 6 Alpine | `seaman_gloves` |

`hands_snow1` lands at index 7, which `gloves.scr:134` (`local.idx >= level.coop_gloveCount`, count
7) can never request. Boris **is** an armory uniform (`helmet.scr:885`,
`level.coop_armorySkins[23]`), so this is reachable, silent, and off by one in the direction that
looks like a working feature.

Boris also sits at exactly 8 skins, the ceiling — `tiki_shared.h:110` `MAX_TIKI_SHADER 8` and
`tiki_parse.cpp:933` reject a 9th with `TIKI_Error`. Any uniform that later gains a second base hand
line, or a 7th glove, silently loses entries.

**The generator has no assertion for this.** `gen_gloves.py` never counts the pre-existing lines and
never verifies the index it labels in its own comment (`(1: Leather Gloves)`) is the index the engine
will compute. That is TRAPS T2's "assertion gates, not review" written out in full.

---

## 3. BLOCKER — the pick is not archived, not replayed on join, and not committed on close

Every other armory family's page cfg carries four `seta` recipes. Compare
`ui/loadout/helm/h05.cfg` / `ui/loadout/skin/s05.cfg` with `ui/loadout/glove/g0N.cfg:5-9`:

| line | helm/skin page | glove page |
|---|---|---|
| archived apply recipe | `seta coop_loAHelm "append name ,hn05"` | `set coop_loAGlove …` — **not archived** |
| archived open-replay | `seta coop_loOpenHelm "exec …/h05.cfg"` | **absent** |
| padlock | `set coop_loCosLk 1` + `vstr coop_loHmLkA05` | **absent** |
| requirement caption | `set coop_loCosReq/2/3 …` | **absent** |

Consequences, each independently reachable:

**3a (bug) — dropped clicks never converge.** TRAPS T8 §6: the name bus dispatches **one** token per
~0.75 s batch in *bus index order*, and gloves are index **52** — the lowest priority in the whole
table (`variables.scr:192`, dispatched last at `player.scr:705`). The documented cure is
"archived-`seta` + join replay **or** a close-commit". Gloves have neither:
`loadoutpick.scr:350` replays `coop_loASkin`, `:363` `coop_loAHelm`, `:399` `coop_loA1..4`;
`loadoutpick.scr:555` / `:607` / `:621` do the same at menu close. No site anywhere mentions
`coop_loAGlove`. *Player-facing:* click NEXT four times quickly, the label reaches "Wool Mittens",
the server applies "Leather Gloves", and nothing ever corrects it. This is bug-773 re-committed
verbatim.

**3b (bug) — the row lies about what you are wearing.** `ui/loadout/open.cfg:9` force-execs
`glove/g00.cfg` on **every** armory open, resetting the label to "Bare Hands" and the prev/next chain
to page 0. Its own comment — "The server re-pushes the archived pick right after" — is false: grep
across the whole mod finds no writer of `coop_loGlove`, `coop_loGloveN/P`, `coop_loGloveNm` or
`coop_loAGlove` other than the seven page cfgs themselves. *Player-facing:* wearing Alpine Hands,
open the armory, it says "Bare Hands"; press PREV expecting Seaman's and you get Alpine (page 6),
press NEXT and you commit Leather (page 1).

**3c (bug) — the pick dies at every map change.** `coop_gloveIdx` lives only in
`player.flags` (`gloves.scr:74, 84, 143`), which does not survive a map transition, and nothing else
persists it (no `seta`, no `fs_write_content`, no cvar). Skins persist through
`coop_armorySkin` + `seta coop_loSkin` + `seta dm_playermodel` + the `player.scr:1265-1287` spawn
re-force; helmets through the archived `coop_loAHelm` replay. *Player-facing:* pick gloves, finish
the mission, arrive on the next map bare-handed.

---

## 4. BUG — `armory_glove_exportLocks` is write-only; there is no padlock and no requirement caption

`gloves.scr:180-193` pushes `set coop_loGlLk<i> <0|1>` for i = 1..6 and claims in its own header "so
the armory can draw a padlock and a requirement caption". Grep across `ui/` finds **zero** readers of
`coop_loGlLk*` — no `enabledcvar`, no `vstr`, no cfg. The only mentions outside `gloves.scr:191` are
in `_research/gloves_research.md:589-593`, which describes a `coop_loGlLkA<NN>` per-page recipe that
was never built.

Compare the shape it says it mirrors: `helmet.scr:1505` pushes
`seta coop_loHmLkA<NN> set coop_loCosLk <lk>` and the page cfg fires it with `vstr coop_loHmLkA05`
into the shared `cosLk` widget (`coop_loadout.urc:205-212`).

Two knock-on effects:

- **(bug)** locked gloves are indistinguishable from unlocked ones. You click, the pick is silently
  refused by `gloves.scr:136-141`, and the only feedback is a one-line `iprint`.
- **(bug)** because the glove pages never write `coop_loCosLk` / `coop_loCosReq*` at all, browsing the
  glove row leaves the **shared** padlock and caption showing whatever the last *skin or helmet* page
  set. *Player-facing:* the padlock and "UNLOCK: reach rank 12 / Challenge: …" caption stay lit while
  you scroll gloves, describing a different item entirely.

Three calls exist (`loadoutpick.scr:383` join, `:546` open, `challenges.scr:1245`); all three are
currently dead work — 6 stufftexts per player per armory open with no consumer.

---

## 5. BUG — the glove lock re-export is wired to the *helmet* branch

`challenges.scr:1243-1246`:

```
if( waitthread coop_mod/main.scr::containsText local.reward "models/coop_helmets/" 0 ){
    thread coop_mod/helmet.scr::armory_helmet_exportLocks local.player
    thread coop_mod/gloves.scr::armory_glove_exportLocks local.player   //[bug-2080]
}
```

A glove unlock token is `glv_wool` / `glv_mittens` / `glv_uswinter` / `glv_seaman` / `glv_alpine` —
none contains `models/coop_helmets/`. So earning a glove never refreshes glove locks; earning an
unrelated *helmet* does. It needs its own `containsText local.reward "glv_"` test. (Moot only because
of finding #4; it becomes live the moment a padlock exists.)

---

## 6. BUG — a glove unlock is announced to the player as `glv wool`

`challenges.scr:2958-3043` (`chal_unlock_displayName`) has branches for
`models/weapons/` → roster name, `models/coop_helmets/` → `"Headgear: …"`, `models/player/` →
`"Uniform: …"`, `finish_*` → `"Weapon Finish: …"`, `mv_*`, `perk_`, `attach_`. There is **no** `glv_`
branch, so a glove falls through to `chal_pend_pretty` (`:3042`), which just strips the path and
turns `_` into spaces.

*Player-facing:* the lobby NEW UNLOCKS list (`chal_pend_append`, `:1214`) and the end-of-mission
debrief card (`coop_mapUnlockList`, `:1223-1232`) read **"glv wool"**, **"glv uswinter"**,
**"glv mittens"** instead of "Gloves: Wool Knit Gloves".

---

## 7. BUG — the glove row collides with the finish strip; the relayout's stated reason does not exist

`ui/coop_loadout.urc:182-190` puts `gloveNameLbl` at `rect 150 428 190 14` → occupies y428-442,
x150-340. The FINISH strip sits at y434-449, x150-361 (`finstrip_lbl` :2893, `finbtn0..3`
:2906/2921/2950/2979, `finlk1..3`). Computed overlaps: **gloveNameLbl × finstrip_lbl, finbtn0,
finbtn1, finbtn2, finbtn3, finlk1, finlk2, finlk3.** All eight are live whenever
`coop_loFinUIOn` is 1, i.e. as soon as a weapon slot is clicked — the normal first action in the
armory. The helmet label it replaced (y412-426) cleared the strip by 8px.

The `.urc` even records this exact regression being fixed once already, at :2888:
"a two-line skin/helm name ran INTO the finish buttons (user screenshot). 434 clears the name".

**The relayout was unnecessary.** `gen_glove_ui.py:8-16` and the comment it emits at
`coop_loadout.urc:148-151` rest on two premises, both false against the file:

- *"the character model viewer occupies rect (12 46 134 348)"* — the `charRender` widget is
  `rect 12 82 134 312` (`coop_loadout.urc:47`), i.e. y82-394.
- *"the unlock caption was moved to y444+ … must not move back up"* — the caption widgets are
  `cosLk` `rect 14 46 12 12` (:207), `cosReq1` `rect 30 46 114 11` (:220), `cosReq2` `rect 14 57`
  (:236), `cosReq3` `rect 14 68` (:252). They are at **y46-79**, above the viewer. A full rect sweep
  of all 260 widgets found **nothing at all** in x14-144 below y442.

So y444 was free, the glove row could have gone there with no repitch, and instead two working rows
were shrunk 15px→14px to make room for a constraint that is not in the file. TRAPS T11 (record over
code) biting inside a generator.

*Other rect notes:* no new widget intrudes on `charRender` (y82-394 vs y396+ — 2px clear, and the
glove row is 34px clear). The remaining overlaps the sweep found (`fit*` panel, `tile74/75`) are
pre-existing and gated by `coop_loFitUI` / tab paging. The 640×480 canvas is not exceeded
(bottom widget ends y479), so TRAPS T8's `CalcClippedFrame` trap is not tripped.

---

## 8. BUG — self-revive was missed; the mannequin is missed twice

The claim was "glove_apply next to every helmet_apply". One site was missed:

- **`coop_mod/medkit.scr:565`** — the SELF-revive path threads `helmet_apply` with no `glove_apply`.
  Its sibling, the AI-revive path at `dbno.scr:1062-1063`, got both. *Player-facing:* revive yourself
  with a medkit and your gloves are gone until the next respawn; get revived by someone else and they
  are not. (All other `helmet_apply` sites — `helmet.scr:804/1384/1404`, `player.scr:1282/1323/1334`,
  `dbno.scr:1062` — are correctly paired.)

- **`helmet.scr:1395-1398`** re-models the lobby mannequin on a uniform change and re-runs
  `helmet_applyMannequin` for exactly the "re-model wiped attachments" reason — but never calls
  `gloves.scr::glove_applyMannequin`. *Player-facing:* in the lobby, change uniform and the
  mannequin's gloves vanish.

- **`lobby.scr:495`** creates the mannequin and never applies gloves at all, so it starts bare-handed
  regardless of the pick. `glove_applyMannequin` has exactly **one** caller,
  `gloves.scr:149` inside `armory_glove_set`.

---

## 9. BUG — 13 armory uniforms already wear a roster glove as index 0

Swept the base `surface hand shader` of all 133 authored uniforms:

| base shader | uniforms | collides with |
|---|---|---|
| `wintergloves_us` | 8 | — (distinct name) |
| `l_gloves` | 4 | glove **1** Leather |
| `handssnow` | 3 | glove **3** US Winter |
| `mittens2` | 2 | glove **4** Mittens |
| `knitgloves1` | 2 | glove **2** Wool Knit |
| `seaman_gloves` | 1 | glove **5** Seaman's |
| `hands_snow1` | 1 | glove **6** Alpine |

*Player-facing:* on those 13 uniforms the matching glove is a visible no-op — "I picked Leather
Gloves and nothing happened". Fixable in the generator by skipping (or reordering) a roster entry
whose shader equals the model's own index 0.

---

## 10. BUG — the 1P texture for "US Winter Gloves" ships only in a third-party pack

`gen_gloves.py:39-41` asserts "Every shader below already ships in a retail or already-installed pak
— no new art, no licence exposure." Scanned every `.shader` in every pk3 under both roots for a
top-level block of each of the 12 roster names:

- `us_winterglove` (index 3, first person) — **only** in `zzzzzz-HRRTM_Pak1_Models.pk3`, with its
  texture in `zzzzzz-HRRTM_Pak3_Textures.pk3`. Neither is retail and neither is shipped by this mod.
  The only `.tik` in the world that references it is HRRTM's own `american_winter_sgt_fps.tik`.

*Player-facing:* a player without the HRRTM pack installed aims down the sights wearing US Winter
Gloves and gets the default/missing shader. This is TRAPS T6/bug-2020 exactly — the generator
audited the **dev install**, not the shipped set.

- **(risk)** `handviewcold` (index 6, first person) has **no shader block anywhere** — only the
  texture `pak1.pk3:textures/models/human/HandViewCold.tga`. Retail's own
  `_american_Army_cold_fps.tik` references the same bare name, so it presumably resolves; *INFERENCE
  — I did not confirm the resolution path in `R_FindShader`.* Worth one runtime check.

The other ten names resolve in retail paks or the coop pak, and both derived textures
(`coop_glove_mittens_view.tga`, `coop_glove_seaman_view.tga`) exist with matching shader blocks in
`scripts/coop_gloves.shader` (both bare and `textures/models/human/`-prefixed forms). Clean.

---

## 11. BUG — missing NULL re-checks after a waiting call (three sites)

`cosmetic_isUnlocked` (`helmet.scr:1749-1761`) calls `chal_ensure`, which waits on a file load. Every
neighbouring implementation re-checks the player afterwards — `helmet.scr:1449`, `:1461`, `:1500`,
`:1512`, and `helmet.scr:806` even carries the comment "helmet_apply waits a frame - the player can
disconnect during it". `gloves.scr` does not, at three sites:

- `gloves.scr:82-85` — after the wait, `local.player.flags["coop_gloveIdx"] = 0`
- `gloves.scr:93-95` — `local.player.flags["coop_gloveSent"]` and `stufftext`
- `gloves.scr:137-148` — same pattern in `armory_glove_set`
- `gloves.scr:186-192` — the export loop calls `cosmetic_isUnlocked` **inside** the loop and then
  `stufftext`s with no re-check, no generation stamp (`coop_loHmLkGen` equivalent), no diff-only
  guard (`coop_loHmLkL<i>` equivalent) and no 8-per-frame throttle. All four exist in the helmet twin
  it says it mirrors.

*Player-facing:* a player who disconnects during the armory open or during spawn produces
`Script Error … applied to NULL listener` spam. Not fatal — TRAPS says the *statement* is skipped,
not the thread — but it is the exact log noise the project has spent sessions cleaning up.

---

## 12. NIT / RISK — smaller items

- **(risk)** `challenges.scr:149-150` **inserts** two challenges at catalogue index 69-70, shifting
  the remaining 297 rows by +2. Pins are safe — they store CIDs now (`chal_pin_importUserinfo`,
  `challenges.scr:3410-3419`) and `ui/coop_sr_cids.cfg` was regenerated (367 entries = 367
  `chal_def`). But the **archived, index-keyed** Service Record row state
  (`seta coop_uiB<i>` / `coop_uiN<i>` / `coop_uiD<i>`, `challenges.scr:1027-1044`) is not
  generation-stamped, so every player's *disconnected* Service Record shows 298 rows' progress
  shifted by two until the server re-pushes each. TRAPS T7/bug-1926 wants a generation stamp here.
  Appending at the end instead of inserting would have avoided it entirely.
- **(nit)** `helmet.scr:1537-1541` — the comment says "The other **six** are gated: **three** by
  challenge, three by rank". Five are listed (`glv_wool`, `glv_uswinter`, `glv_mittens`,
  `glv_seaman`, `glv_alpine`); two by challenge, three by rank. Stale from the pre-cut 8-entry
  roster that still had Paratrooper Hands.
- **(nit)** `unlockreq_gen.scr:265` — `"…to unlock the Wool Mit"`. `armory_unlocks.py:213` hard-cuts
  at 80 chars (`return sanitise(out)[:80]`). Pre-existing behaviour (many rows are cut), but the new
  glove strings are what the *new* `chal_reqText` path reads out loud, so a player sees the truncated
  sentence in `glove_lockNotice`'s `iprint` (`gloves.scr:163`).
- **(nit)** `gloves.scr:155-160` — the header claims "ONE message per distinct locked item", but
  `coop_gloveLockMsg` is a single scalar, so it only suppresses *consecutive* repeats of the same
  index. Clicking locked 2 → 3 → 2 prints three times.
- **(nit)** `variables.scr:192-193` — entry `52` is written **before** entry `51`. Harmless (the
  `while(local.command[string(local.i)])` walk at `player.scr:449` is key-indexed, and both keys
  exist, so the loop still reaches 52 before stopping at 53), but it reads as a mistake and the same
  out-of-order insert appears again at `player.scr:705-706`.
- **(nit)** The three `glove_apply` inserts at `player.scr:1283`, `:1324`, `:1335` and `dbno.scr:1063`
  are indented at one tab regardless of their block depth — column-misaligned inside 4- and 5-deep
  nesting. Cosmetic only; `depthscan2.py` passes.
- **(risk)** `armory_skin_applyIdx` threads `glove_apply` **twice** (`helmet.scr:1385` and `:1405`)
  within one call, plus `armory_helmet_applyIdx` at `:805`. Two concurrent `glove_apply` threads per
  uniform change, each doing a `chal_ensure`. Idempotent (the writes are absolute, the
  `coop_gloveSent` compare-and-set has no wait inside it), so no corruption — just doubled work.
- **(risk, engine)** `tiki_parse.cpp:527` still parses the TIKI token `crossfade` into
  `TIKI_SURF_CROSSFADE (1 << 6)` (`tiki_shared.h:100`), while bit 6 is now the third skin-offset bit
  (`q_shared.h:2169`). The *script* token was retired with a warning (`entity.cpp:4378-4384`); the
  TIKI one was not. Any `.tik` that sets it now silently reads as glove index +4. Clean in this mod
  (zero `.tik`/`.shader` hits), but the mod imports third-party skin packs it does not author
  (TRAPS T6) — either retire it in the TIKI parser too or add a load-time warning.

---

## Categories that are CLEAN

**Parse safety (asked check #1) — clean.**
`depthscan2.py`, `linecheck.py` and `quotecheck.py` all pass on all nine touched `.scr`
(`gloves`, `variables`, `player`, `dbno`, `helmet`, `challenges`, `xp`, `loadoutpick`,
`unlockreq_gen`). Byte scan: no UTF-8 BOM anywhere; no non-ASCII except four pre-existing bytes in
`player.scr:556` (`°`) and `:565` (`§`), which are literal `case` labels in the name sanitiser and
predate this change. No bare negative inside parentheses in `gloves.scr`. Line endings preserved
per file (`variables.scr`/`dbno.scr`/`loadoutpick.scr`/`coop_loadout.urc` CRLF, the rest LF) — no
whole-file flip, so TRAPS T2/bug-2081 was not tripped. **All six `surface` arguments in
`gloves.scr:111-121` are quoted** (`"-skin1"`, `"-skin2"`, `"-skin4"`, `"+skin1"`, `"+skin2"`,
`"+skin4"`), which is the bug-533/1308 requirement; no unquoted `+`/`-` directive argument exists in
any touched file.

**Bit math (asked check #3) — clean, no off-by-one.**
`q_shared.h:2141/2142/2169/2173`: BIT0 = `1<<0`, BIT1 = `1<<1`, BIT2 = `1<<6`, and
`MDL_SURFACE_SKININDEX(b) = ((b)&3) | (((b)&64)>>4)`. `entity.cpp:4365-4377` maps script `skin1`→BIT0,
`skin2`→BIT1, `skin4`→BIT2. Verified every index against `gloves.scr:115-121`:

| idx | script writes | byte | macro | ✓ |
|---|---|---|---|---|
| 1 | skin1 | 0x01 | 1 | ✓ |
| 2 | skin2 | 0x02 | 2 | ✓ |
| 3 | skin1+skin2 | 0x03 | 3 | ✓ |
| 4 | skin4 | 0x40 | 0\|4 = 4 | ✓ |
| 5 | skin4+skin1 | 0x41 | 1\|4 = 5 | ✓ |
| 6 | skin4+skin2 | 0x42 | 2\|4 = 6 | ✓ |
| 7 | skin4+skin1+skin2 | 0x43 | 3\|4 = 7 | ✓ |

The pre-clear of all three bits is correct (`surface` sets/clears flags, it does not assign), and it
deliberately leaves `NODRAW` (bit 2) and the surfacetype bits (3-5) alone, which the helmet system
owns. The cgame mirror at `cg_modelanim.c:2422` computes `(g & 3) | ((g & 4) << 4)` — the exact
inverse — and writes it after the `memset` at `:2393`, before the hide-arms `|= NODRAW` at `:2447`,
so no ordering hazard. The gore writer exemption is real: `sentient.cpp:2500-2504` skips
`handSurf` for `isSubclassOf(Player)` only.

**Unlock gating (asked check #4) — clean.**
`helmet.scr:1542-1546` gates exactly `glv_wool`, `glv_uswinter`, `glv_mittens`, `glv_seaman`,
`glv_alpine`. `glv_bare` and `glv_leather` are **absent**, so both are free — as intended. Every
gated token has a source: `glv_wool` ← `challenges.scr:149`, `glv_mittens` ← `:150`,
`glv_uswinter`/`glv_seaman`/`glv_alpine` ← `xp.scr:91/93/95`. `armory_unlocks.py` confirms:
`gloves 7 | gated 182`, `UNOBTAINABLE (0)`, `DEAD REWARDS (0)`, and no `glv_` row in the UNGATED
list. (Only the comment's arithmetic is wrong — item 12.)

**xp.scr rank grants (asked check #5) — clean.**
`coop_xp_rankUnlockCnt[6] = 2` (`xp.scr:54`), `[12] = 2` (`:71`), `[18] = 0` (`:85`) are all assigned
**above** the glove block at `:89-96`, so the live-count idiom lands `glv_uswinter` at `[6][2]`,
`glv_seaman` at `[12][2]`, `glv_alpine` at `[18][0]` — no overwrite of any weapon reward. The idiom
is byte-identical to the community-skin block at `:105-111`, and the consumers
(`xp.scr:1955-1960`, `collectible.scr:418-424`) both iterate `0 .. Cnt-1`, so the incremented counts
are honoured. Both consumers funnel through `chal_add_unlock`, which is token-agnostic — a bare
`glv_*` id needs no path branch.

**The bus (asked check #6) — clean.**
`variables.scr:192` `local.command["52"]=" ,gn"` and `player.scr:705` `arrayIndex==52` agree.
Extraction (`main.scr::containsText`) is a plain substring search, and `,gn` collides with no other
marker: the only other `,g*` token is `,ga` (index 17), which differs in the second character, and no
marker is a prefix of another. The 1-digit payload is parsed exactly like the `,f1`-`,f4` finish
tokens (`playerExtract`, `player.scr:527-586`, terminates on the delimiter set; digits are not
delimiters), and it always carries a data character, so bug-772's "undispatchable bare token" cannot
occur. The walk at `player.scr:449` (`while(local.command[string(local.i)])`) reaches 52 because both
51 and 52 are defined. *(The bus-index priority consequence is a real problem, but it is a design gap
— see finding 3a — not a wiring error.)*

**Stufftext safety (asked check #7) — clean.**
Both payloads are single statements with no embedded quote and no `;`:
`gloves.scr:95/147` `"set coop_gloveIdx " + local.idx` and `:191`
`"set coop_loGlLk" + local.i + " " + local.lk`. Both names hit the `coop_` prefix allow at
`cg_servercmds_filter.cpp:173` (`CG_IsVariableAllowed`), which `CG_IsSetVariableAllowed:206` consults
first, so neither is filtered. `exec ui/loadout/glove/g00.cfg` passes the path scope at
`cg_servercmds_filter.cpp:346-348` (`ui/loadout/` is one of the three allowed prefixes) — although in
practice it runs client-side from `open.cfg`, where the filter does not apply. The client's
`vstr coop_loGloveP/N` also passes the `coop_`-prefix `vstr` exemption at `:349-362`. No value is
padded with whitespace, so the `Cmd_ArgsFrom` collapse (bug-1364) is not a factor.

**Re-entrancy (asked check #8) — clean of the bug-2045 class.**
`glove_apply` (`gloves.scr:62-97`) NULL-checks **before** the `waitframe` at `:70` and again at `:71`
immediately after — the ordering the check asked about. It spawns no loop, latches no flag that is
never cleared, and re-threads nothing. Called twice in one frame it is safe: `glove_writeBits` is an
absolute write (clear-then-set), and the `coop_gloveSent` compare-and-set at `:93-95` has no wait
between the read and the write. `armory_glove_exportLocks` is bounded at `level.coop_gloveCount`.
(The missing NULL re-checks in item 11 are an error-spam issue, not a leak.)

**The prev/next chain (asked check #10) — clean.**
Verified all seven files: g00→g01→g02→g03→g04→g05→g06→g00 forward, g00→g06 and gNN→gNN-1 backward.
Fully circular over all 7 entries, no dead end, no self-reference, every referenced file exists.
`gen_glove_ui.py:52-53` computes it with `(i±1) % n`, which cannot produce a dead end.

---

## Suggested fix order

1. Author the glove lines into the 135 `_nohat.tik` twins (finding 1) — nothing else matters until
   the worn model carries them. Whatever generated the `_nohat` set must run **after**
   `gen_gloves.py`, or `gen_gloves.py` must include `<skin>_nohat.tik` in its file list.
2. Make `gen_gloves.py` **assert** the computed index (finding 2): count pre-existing
   `surface <name> shader` lines per file, fail loudly if it is not exactly 1, and fail if the total
   would exceed `MAX_TIKI_SHADER`. Fix `allied_russian_crazy_boris.tik` explicitly.
3. Switch the page cfgs to `seta coop_loAGlove` / `seta coop_loOpenGlove`, add the glove replay to
   `loadout_resend` and `loadout_menuCtl` close, drop the unconditional `g00` seed from `open.cfg`,
   and persist `coop_gloveIdx` across maps (finding 3).
4. Either wire `coop_loGlLk*` into real padlock/caption widgets or delete the export (finding 4), and
   move the re-export out of the helmet branch (finding 5).
5. Move the glove row to y444 and restore the uniform/helmet rows to 15px (finding 7).
6. `medkit.scr:565`, `helmet.scr:1397`, `lobby.scr:495` (finding 8); `glv_` branch in
   `chal_unlock_displayName` (finding 6); NULL re-checks (finding 11).
