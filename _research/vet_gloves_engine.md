# Adversarial vet: bug-2080 armory GLOVES engine change

Reviewed 2026-08-23 against the working tree of `C:\mohaa-coop-dev\openmohaa-hzm` (uncommitted,
HEAD = `95dc8eae`). Read-only review; nothing was modified.

Scope note: the working tree also carries **unrelated** bug-2055 cover-lean work in
`code/fgame/player.cpp` and `code/fgame/weapon.cpp`. Those were not reviewed. They do mean that
"the gloves change" cannot be built or shipped in isolation from the tree as it stands.

---

## 1. BLOCKER — `MAX_TIKI_LOAD_SHADERS` was not raised with `MAX_TIKI_SHADER`; every glove-authored TIKI overruns `dloadsurface_t` on load

**Where**
- `code/tiki/tiki_parse.cpp:934` — the changed guard, now `numskins > MAX_TIKI_SHADER - 1` (i.e. `> 7`)
- `code/tiki/tiki_parse.cpp:942-948` — the write it guards
- `code/qcommon/tiki.h:57` — `#define MAX_TIKI_LOAD_SHADERS 4` — **unchanged**
- `code/qcommon/tiki.h:126-132` — `dloadsurface_t`, whose array is sized by `MAX_TIKI_LOAD_SHADERS`, *not* `MAX_TIKI_SHADER`
- `code/tiki/tiki_files.cpp:332` — `dloadsurface_t loadsurfaces[MAX_TIKI_LOAD_SURFACES];` on the **stack**
- `code/qcommon/tiki_main.cpp:113-127` — `TIKI_SetupIndividualSurface`, the consumer

**What breaks.** `MAX_TIKI_SHADER` (`tiki/tiki_shared.h:109`) governs the *runtime* struct
`dtikisurface_t`. The *load-time* struct is a different one with a different constant:

```c
typedef struct {                                  /* qcommon/tiki.h:126 */
    char  name[MAX_NAME_LENGTH];                  /* 32  @ 0   */
    char  shader[MAX_TIKI_LOAD_SHADERS][MAX_RES_NAME];  /* 4x64 @ 32..287 */
    int   numskins;                               /*     @ 288 */
    int   flags;                                  /*     @ 292 */
    float damage_multiplier;                      /*     @ 296 */
} dloadsurface_t;                                 /* sizeof = 300 */
```

The old guard `numskins > 3` was exactly right for a 4-row array. The new guard permits
`numskins` = 4,5,6,7, and `tiki_parse.cpp:942` then does a 64-byte `strncpy` into `shader[4]`,
which starts at byte **288** — i.e. **on top of `numskins`, `flags` and `damage_multiplier`**, and
then 52 bytes into the next array element.

**This is not hypothetical — the shipped content already triggers it.**
`hzm-mohaa-coop-mod/models/player/*.tik` authors **7** shaders on one surface:

- `34th_Infantery_Division_private.tik:20-26` — `surface hand shader handsnew` + 6 glove lines
- 133 third-person TIKs carry 6 glove lines (1 overflowing surface each)
- 102 `*_fps.tik` carry 18 glove lines — `triggerhand`, `lefthand`, `garandhand`, 7 shaders each
  (`34th_Infantery_Division_private_fps.tik:12-34`) → **3 overflowing surfaces per file**

**Concrete scenario**, third-person TIK, 5th shader line is `mittens2`:

1. lines 1-4 fill `shader[0..3]`, `numskins` = 4
2. line 5 passes the new guard (4 ≤ 7) and writes 64 bytes at offset 288
3. `numskins` now reads the first four bytes of `"mittens2"` = **1953786221**, then `++` → **1953786222**
   (`flags` → 0, `damage_multiplier` → 0.0 — so the hand's surface flags and damage multiplier are
   silently destroyed as well)
4. lines 6-7 hit the guard and are dropped
5. `TIKI_SetupIndividualSurface` (`qcommon/tiki_main.cpp:118`) runs
   `for (j = 0; j < loadsurf->numskins; j++)`. j = 0..7 copies `shader[0..7]` — indices 4-7 are
   **out-of-bounds reads** of the load struct. j = 8 .. ~1.95e9 each hit
   `if (surf->numskins >= MAX_TIKI_SHADER) TIKI_Error(...)` — and `TIKI_Error`
   (`qcommon/tiki_main.cpp:94-107`) does **not** abort, it `Com_Printf`s. That is ~1.95 **billion**
   console+logfile writes, with `logfile 2` flushing per line. Effective hang plus an unbounded
   `qconsole.log`.

For the `_fps` TIKs the 5th shader is `coop_glove_mittens_view` → `numskins` becomes 1886351204,
same outcome, three times per file.

Additionally, if the overflowing surface is ever the **last** slot (`currentSurface == 47`), the
write runs 244 bytes past the end of the 14,400-byte stack array in `TIKI_LoadTikiModel` — a /GS
canary trip (0xC0000409), the exact failure mode the guard at `tiki_parse.cpp:893-905` was added to
prevent. Not reachable with today's content (`hand` sits at slot 5), but it is one content edit away.

**Fix direction.** `code/qcommon/tiki.h:57` must go to 8 as well; it is used in only two places
(`tiki.h:57`, `tiki.h:128`). Note the side effect: `dloadsurface_t` grows 300 → 556 bytes, so
`loadsurfaces[48]` in `TIKI_LoadTikiModel` grows from 14.1 KB to 26.1 KB of stack.

---

## 2. BUG — the `hand` exemption added to `CoopGoreUpdateSkinTier` is unreachable dead code

**Where** `code/fgame/sentient.cpp:2386-2390` vs `code/fgame/sentient.cpp:2496-2501`

```c
void Sentient::CoopGoreUpdateSkinTier(void)
{
    ...
    if (IsSubclassOfPlayer()) {      /* sentient.cpp:2388  -- bug-792, "no body gore on players" */
        return;
    }
    ...
    int handSurf = -1;               /* sentient.cpp:2498  -- 110 lines BELOW that return */
    if (isSubclassOf(Player)) {
        handSurf = gi.Surface_NameToNum(edict->tiki, "hand");
    }
```

`IsSubclassOfPlayer()` is `return (entflags & ECF_PLAYER);` (`code/fgame/simpleentity.cpp:289-292`)
— functionally the same test as `isSubclassOf(Player)` for any constructed `Player`. The function
has returned for every player since bug-792, so `handSurf` is **always -1** and the new branch never
executes.

**What this means.** The mechanism the change's comment describes at length ("the two systems fight
and the glove loses… a player's gloves would step through the roster as they took hits") **could not
have happened**. The comment states an inference as a measurement and will mislead the next reader
into believing this exemption is load-bearing. Answering the brief's sub-questions anyway:
`player.h` **is** included (`sentient.cpp:38`) so it compiles; `Surface_NameToNum` is **not** a
per-damage-event cost because it sits after the `tier == m_iCoopGoreSkinTier` early-out
(`sentient.cpp:2457-2460`), so it runs only on a tier flip; and `-1` can never collide with a real
index because the loop counter starts at 0.

Recommend deleting the block and replacing the comment with one line recording *why* no exemption is
needed (bug-792 already returns).

---

## 3. BUG — `EventCoopGoreReset` clears the glove's low bits, silently changing which glove a player wears

**Where** `code/fgame/sentient.cpp:2962-2970`

```c
for (i = 0; i < numsurfaces; i++) {
    edict->s.surfaces[i] &= ~(MDL_SURFACE_SKINOFFSET_BIT0 | MDL_SURFACE_SKINOFFSET_BIT1);
}
```

Unlike `CoopGoreUpdateSkinTier`, this function has **no player early-out** (`sentient.cpp:2932`
onward) and no `hand` exemption. It clears bits 0-1 but leaves bit 6, so it does not clear the glove
— it **mutates** it:

| worn glove | bits | after clear | renders as |
|---|---|---|---|
| 5 Seaman's | `BIT2\|BIT0` | `BIT2` | 4 — Wool Mittens |
| 6 Alpine | `BIT2\|BIT1` | `BIT2` | 4 — Wool Mittens |
| 1/2/3 | bits 0-1 | 0 | Bare Hands |

**Scenario.** `coop_gorePermanent 0` (the loop is skipped at `sentient.cpp:2953-2959` under the
default 1). A player wearing Seaman's Gloves takes a script heal — the officer canteen / health post
or `aihandler`'s `coop_actorActualHealth` path — which fires the no-arg `gore_reset`. Their gloves
become Wool Mittens for the rest of the life. `coop_mod/gloves.scr::glove_apply` only re-runs on
spawn, revive and skin change, so a canteen heal is not corrected.

Either add the same `hand` exemption here (this one would actually execute), or clear all three bits
and let `glove_writeBits` re-assert.

---

## 4. BUG (documentation) — the `surface` event declaration was not updated, against its own in-file instruction

**Where** `code/fgame/entity.cpp:758-770` (declaration) vs `code/fgame/entity.cpp:4353-4357` (the rule)

`Entity::SurfaceCommand` carries an explicit standing instruction directly above the token chain:

> `// WARNING: please change the Event decleration, // to match this function, if flags are added or // deleted the event must be updated.`

`skin4` was added at `entity.cpp:4377` and `crossfade` was removed at `entity.cpp:4378-4383`, but
`EV_SurfaceModelEvent`'s help text at `entity.cpp:764-768` still lists only skin1 / skin2 / nodraw.
Nothing breaks at runtime (the format string `"sSSSSSS"` accepts any strings, and
`SurfaceModelEvent` at `entity.cpp:4424-4436` just forwards them), so this is documentation only —
but `listCommands` / the event dump is how the next person discovers `skin4` exists.

---

## 5. RISK — `TIKI_SURF_CROSSFADE` still occupies bit 6 in the TIKI enum, which several sites deliberately alias onto the MDL enum

**Where** `code/tiki/tiki_shared.h:101` (`TIKI_SURF_CROSSFADE (1 << 6)`, unchanged),
`code/tiki/tiki_parse.cpp:527-529` (token still mapped), `code/qcommon/q_shared.h:2169`
(`MDL_SURFACE_SKINOFFSET_BIT2 (1 << 6)`)

**Answering question A directly: the TIKI-side path is NOT reachable, and this is confirmed rather
than inferred.** `TIKI_ParseSurfaceFlag`'s result lands in `dloadsurface_t.flags`
(`tiki_parse.cpp:918`), is copied to `dtikisurface_t.flags` (`qcommon/tiki_main.cpp:130`), and that
`int` field has exactly three readers in the whole tree:

- `code/renderergl1/tr_model.cpp:144` — `TIKI_SURF_NOMIPMAPS` only
- `code/renderergl1/tr_staticmodels.cpp:108` — `TIKI_SURF_NOMIPMAPS` only
- `code/renderergl2/tr_staticmodels.cpp:107` — `TIKI_SURF_NOMIPMAPS` only

It is never OR'd into `entityState.surfaces[]` or `refEntity_t.surfaces[]`. So a TIKI saying
`surface x crossfade` cannot become a glove index. (It also never drove the deleted renderer branch:
that branch tested `*bsurf & 0x40`, the entity byte, not `dsurf->flags`.) `hzm-mohaa-coop-mod` has
no `crossfade` in any working-tree file.

**The residual risk is the enum divergence itself.** The two enums were bit-for-bit aligned by
design — `TIKI_SURF_SKIN1/2` = `MDL_SURFACE_SKINOFFSET_BIT0/1`, `TIKI_SURF_NODRAW` =
`MDL_SURFACE_NODRAW` (both `1<<2`), `TIKI_SURF_NODAMAGE` = `MDL_SURFACE_SKIN_NO_DAMAGE` (both
`1<<7`) — and code *relies* on the aliasing: `code/client/cl_invrender.cpp:299` writes
`ent.surfaces[s] |= TIKI_SURF_NODRAW;` into an MDL byte. Bit 6 is now the one place the two enums
disagree, with no comment on the TIKI side saying so. Recommend a `// bit 6: MDL-side meaning
diverged, see q_shared.h` marker at `tiki_shared.h:101`, or retire `TIKI_SURF_CROSSFADE` and its
parser token the way the `entity.cpp` token was retired.

---

## 6. RISK — `MDL_SURFACE_SKININDEX` evaluates its argument twice

**Where** `code/qcommon/q_shared.h:2173`

```c
#define MDL_SURFACE_SKININDEX(b)  ( ( (b) & 3 ) | ( ( (b) & MDL_SURFACE_SKINOFFSET_BIT2 ) >> 4 ) )
```

**Answering question B: the arithmetic is correct.** `(b) & 3` → 0-3; bit 6 is 64, `64 >> 4` = 4;
the two ranges are disjoint so the OR composes 0-7 with no overlap and no loss. `(b)` is
parenthesised, `MDL_SURFACE_SKINOFFSET_BIT2` expands to a parenthesised `( 1 << 6 )`, and the whole
body is parenthesised — so `*bsurf` (a `byte` lvalue promoted to `int`) is safe, and so is any
side-effect-free expression.

The defect is that `b` appears twice. All three current call sites pass the side-effect-free
`*bsurf` — `renderergl1/tr_model.cpp:964`, `renderergl2/tr_model.cpp:1321`,
`renderergl2/tr_model.cpp:1336` — so nothing is broken today. But `bsurf` is a walking pointer
incremented in the loop header (`renderergl1/tr_model.cpp:952`,
`renderergl2/tr_model.cpp:1310`), which is precisely the context where someone later writes
`MDL_SURFACE_SKININDEX(*bsurf++)` and gets a double increment with no diagnostic. A `static inline`
would cost nothing.

---

## 7. NIT — `Entity::SurfaceCommand` writes `edict->s.surfaces[]` with no `MAX_MODEL_SURFACES` bound (pre-existing, newly exercised)

**Where** `code/fgame/entity.cpp:4394-4413`

The loop bound is `numsurfaces = gi.TIKI_NumSurfaces(edict->tiki)` and the writes at
`entity.cpp:4409/4412` are unguarded, but `entityState_t.surfaces` is `byte surfaces[32]`
(`q_shared.h:2231`, `MAX_MODEL_SURFACES` = 32 at `q_shared.h:2139`) while the TIKI loader allows up
to `MAX_TIKI_LOAD_SURFACES` = 48 distinct surfaces (`qcommon/tiki.h:68`). Every other writer in this
subsystem clamps — `sentient.cpp:2471`, `:2590`, `:2746`, `:3419`, `gamecmds.cpp:93`, and the new
cgame code at `cg_modelanim.c:2427` — this one does not.

This is **pre-existing**, not introduced by bug-2080. It is listed because `coop_mod/gloves.scr`
now calls `surface hand "-skin1"` / `"+skin4"` on every player spawn and revive
(`gloves.scr:113-121`), which exercises the path far more often than before. INFERENCE: `hand` sits
at a low index in the shipped player TIKs (third mesh, after `usarmy.skd` and `head2.skd`), so it is
almost certainly < 32 today — I did not enumerate the `.skd` surface counts to confirm.

---

## 8. NIT — the 1P glove is client-cvar-driven with no server re-assertion, so it does not honour unlocks

**Where** `code/cgame/cg_modelanim.c:2412-2431`, `coop_mod/gloves.scr:74-96`

`glove_apply` re-validates the unlock server-side and fails safe to 0 (`gloves.scr:81-87`), then
pushes `set coop_gloveIdx <n>` **change-only**, guarded by `flags["coop_gloveSent"]`
(`gloves.scr:93-96`). Nothing re-asserts the value afterwards. A client that types
`set coop_gloveIdx 6` in console wears Alpine Hands in their own first-person view regardless of
unlock state, and the server will not correct it because its `coop_gloveSent` flag already matches
whatever it last sent. Purely a self-view cosmetic — third person still comes from the server-owned
surface bits — so this is a consistency nit, not an exploit.

Also in this block: `g > 0 && g <= 7` silently ignores out-of-range values with no developer print.
Minor, but `coop_gloveIdx 8` failing invisibly is exactly the shape of a debugging session.

**Everything else in question F checks out.** `MAX_MODEL_SURFACES` is in scope in this file (used at
`cg_modelanim.c:2192`, `:2446`); `model` is a `refEntity_t` whose `surfaces` is
`byte surfaces[MAX_MODEL_SURFACES]` (`renderercommon/tr_types.h:143`); `model.tiki` is a real member
(`tr_types.h:158`); `cgi.Surface_NameToNum` is `TIKI_Surface_NameToNum`
(`client/cl_cgame.cpp:808`), which returns `-1` on miss and an index `< num_surfaces` otherwise
(`tiki/tiki_surface.cpp:34-48`) — so the `sn >= 0 && sn < MAX_MODEL_SURFACES` guard at
`cg_modelanim.c:2427` is correct and is in fact **stricter than the legacy code beside it** at
`:2476-2495`, which only checks `>= 0`. The cached-`static cvar_t *` pattern is the established one
in this file (`cg_modelanim.c:58`, `:370`, `:749`, `:1459`, `:1757`, and ~15 more across cgame), and
`cgi.Cvar_Get` returns a `cvar_t *` (`cgame/cg_public.h:122`), so reading `->integer` per frame is a
pointer dereference, not a lookup.

---

## Category answers

### C — MAX_TIKI_SHADER 4 → 8: complete audit

Every site that indexes `hShader[]` / `shader[][]` or assumes 4:

| site | verdict |
|---|---|
| `code/qcommon/tiki.h:57,128` — `MAX_TIKI_LOAD_SHADERS 4` | **BROKEN — finding #1** |
| `code/tiki/tiki_parse.cpp:934` | changed; now inconsistent with the array it guards |
| `code/qcommon/tiki_main.cpp:119,125-126` | bound by `MAX_TIKI_SHADER`, scales correctly |
| `code/renderergl1/tr_model.cpp:138-151` | `assert(numskins <= MAX_TIKI_SHADER)` + `for (j...numskins)`, fine |
| `code/renderergl2/tr_model.cpp:420-426` | same, fine |
| `code/renderergl1/tr_staticmodels.cpp:106-112`, `gl2:106-110` | loop to `numskins`, fine |
| `code/tiki/tiki_cache.cpp:456-457` | loop to `numskins`, fine |
| `code/tiki/tiki_files.cpp:497-500` | writes `shader[0]` only, fine |
| `code/fgame/sentient.cpp:3070-3071` | reads `dsurf->numskins` — see the note below |
| `code/tools/ommap/misc_model.c:119` | unrelated (`md3Surface_t`) |

**Struct size change.** `dtikisurface_t` (`tiki_shared.h:321-328`) grows from 348 to 620 bytes
(`shader` 256→512, `hShader` 16→32). Allocation is `sizeof`-driven —
`tiki_files.cpp:365` `defsize += num_surfaces * sizeof(dtikisurface_t)` — and `TIKI_Alloc` is a
plain `malloc` wrapper (`qcommon/tiki_imports.cpp:45-48`, `Z_TagMalloc` →
`memory.c:183 block = malloc(size)`), **not** a fixed pool. So there is no allocation ceiling to
blow. Memory cost is roughly +272 bytes per surface per loaded TIKI (order of 1-2 MB across a full
map's model set).

**Nothing persists or networks `dtikisurface_t`.** It is a runtime-only struct; no file format, no
savegame field, no netfield references it. Confirmed by grep — the only serialisation-shaped code
near it (`tools/ommap/misc_model.c:119`) operates on `md3Surface_t`.

**ABI.** `dtikisurface_t` is dereferenced across the DLL boundary by both renderers
(`tr_model.cpp` via `ent->e.tiki->surfaces`) **and by game.dll** (`fgame/sentient.cpp:3069`
`dsurf = &edict->tiki->surfaces[i];`), while the allocation and layout live in the exe. A partial
rebuild that ships one side stale is silent garbage, not a link error. `build.ps1:190-205` does
deploy all six binaries (`openmohaa.exe`, `omohaaded.exe`, `cgame.dll`, `game.dll`,
`renderer_opengl1.dll`, `renderer_opengl2.dll`), so the deploy step is safe — the hazard is a
`cmake --build` that skips a target.

**One semantic collision worth noting.** `Sentient::CoopGoreTryGibSkins` gates on
`dsurf->numskins < 4` (`sentient.cpp:3070-3072`) to mean "does this surface have an authored gib
skin". On player models the `hand` surface now has 7 skins that are **gloves, not gore tiers**, so
that gate's meaning is now false for player hands. It is harmless *today* only because the function
early-returns for players at `sentient.cpp:3042` (`if (IsSubclassOfPlayer()) return;` — bug-792). If
that early-out is ever relaxed, or if a non-Player entity is ever given a player TIK, gibbing would
write index 3 onto `hand` and paint US Winter Gloves on a corpse. Same shape applies to any allied
AI given a `models/player/*.tik`: `CoopGoreUpdateSkinTier`'s clamp
(`sentient.cpp:2534 surfTier = TIKI_SurfaceNumSkins(...) - 1`) would resolve to 6, clamp to the
damage tier 1-2, and render Leather / Wool Knit Gloves as "blood". INFERENCE — I did not find such a
spawn, but the coupling is now real and was not there before.

### D — the deleted crossfade branch

**Nothing else depended on it.** The only writers of bit 6 into the surface byte were
`Entity::SurfaceCommand`'s `crossfade` token (now retired) and nothing else; the only reader was the
deleted `(*bsurf & 0x40)` branch in the two `R_AddSkelSurfaces`. Grep for `0x40` across
`renderergl1`, `renderergl2`, `client`, `cgame` returns only `tr_terrain.c` patch flags and
`cl_ui.cpp` inventory bitmasks — unrelated fields.

**The surviving path clamps correctly for all inputs**, including the combination the brief asks
about. `renderergl1/tr_model.cpp:964-969` and `renderergl2/tr_model.cpp:1321-1326`:

```c
int iShaderNum = ent->e.skinNum + MDL_SURFACE_SKININDEX(*bsurf);   /* max +7 now, was +3 */
if (iShaderNum >= dsurf->numskins) { iShaderNum = 0; }
shader = tr.shaders[dsurf->hShader[iShaderNum]];
```

The upper bound is checked against the *actual* `numskins`, so a 3-bit index on a 1-skin surface
falls to 0 exactly as a 2-bit index did. `numskins` is never 0 — `tiki_files.cpp:489-500` assigns
`numskins = 1` to any surface the setup block did not name. The old branch's extra
`iShaderNum + 1 >= numskins` guard went away with the branch that needed it. The gl2 diagnostic
block is also clamped before use (`tr_model.cpp:1338-1340` sets `lsn = 0` before
`dsurf->hShader[lsn]` at `:1347`).

Residual: `iShaderNum` is `int` and `ent->e.skinNum` is unclamped, so a negative `skinNum` would
index `hShader[]` negatively — the `>=` test does not catch it. Pre-existing, unchanged by this work,
and `skinNum` is 0 on every player and actor.

### G — wire, demo and savegame compatibility

**Networked.** `entityState_t.surfaces[32]` (`q_shared.h:2231`) is transmitted as 32 separate 8-bit
netfields, present in all three field tables (`qcommon/msg.cpp:1388-1486`, `:1635-1636`,
`:1793-1794`). All 8 bits of every byte cross the wire, so there is no capacity problem — only a
**meaning** problem: bit 6 means crossfade on an old peer and skin-index-bit-2 on a new one.

**Binaries that must ship together:** `openmohaa.exe` (TIKI loader owns the struct layout and the
surface byte semantics), `omohaaded.exe`, `game.dll` (writes the bits; dereferences
`dtikisurface_t`), `cgame.dll` (writes the 1P bits; passes `dtiki_t *`), and **both**
`renderer_opengl1.dll` and `renderer_opengl2.dll` (read the bits; dereference `dtikisurface_t`).
The `dtikisurface_t` size change (finding C) makes this stricter than a semantic mismatch — a stale
renderer or a stale game.dll reads the surface array at the wrong stride.

**Savegames / persistent archive: yes, these bytes are stored raw.**
`code/fgame/g_utils.cpp:1352` — `arc.ArchiveRaw(&edict->s.surfaces, sizeof(edict->s.surfaces));`
inside the entity-state archive, with no version gate around it. Direction of risk:

- old save → new binary: safe. Nothing ever set bit 6 (finding #5 confirms the writers), so every
  archived byte has bit 6 clear and reads back as glove index 0 — which is each uniform's own hand
  shader, i.e. correct.
- new save → old binary: a saved glove index 4-7 reads back as a crossfade request and double-draws
  the hand surface with two adjacent shaders.

Practically bounded: `CLAUDE.md` forbids the persistant-archive transition path on a live coop
server, and this is a one-way version step. Worth one line in the release note rather than a code
change.

**Demos** record the same `entityState` bytes through the same delta tables, so the same two
directions apply. No demo predating today can carry bit 6.

---

## Independent question: can a player's **non-hand** surface now render the wrong shader?

**No.** Walking the exact case asked for — `pants` with 3 gore skins, player wearing glove index 5:

1. Glove 5 is composed as `MDL_SURFACE_SKINOFFSET_BIT2 | MDL_SURFACE_SKINOFFSET_BIT0` and written by
   `coop_mod/gloves.scr:119` as `local.ent surface hand "+skin4"` then `"+skin1"`.
2. `Entity::SurfaceCommand` (`entity.cpp:4319-4333`) takes the named-surface path: `surf_name` has
   no trailing `*` and is not `"all"`, so `mult` and `do_all` stay false and `surface_num` is the
   single index from `Surface_NameToNum`. The write loop at `entity.cpp:4404-4419` therefore runs
   exactly once and `break`s (`if (!do_all && !mult) break;`). **Only the `hand` byte is touched.**
3. `pants` keeps whatever `CoopGoreUpdateSkinTier` last wrote. That writer masks to bits 0-1 only —
   `sentient.cpp:2540-2542`, `(surfaces[i] & ~(BIT0|BIT1)) | surfTier` — and `surfTier` is clamped
   to `min(numskins-1, tier)` with `tier ∈ {0,1,2}` (`sentient.cpp:2440-2446`, `:2534-2539`), so it
   can never set bit 6 and can never exceed 2.
4. At render, `MDL_SURFACE_SKININDEX(pants_byte)` = `(0..2) | (0 >> 4)` = 0..2, plus
   `skinNum` = 0 → index 0..2, clamped against `numskins` = 3. Identical to pre-change behaviour.

The only way a non-hand player surface could pick up bit 6 is a wildcard or `all` surface command
carrying `skin4`, which nothing issues. So the answer is no — **for third person**.

Two caveats that are not the pants case but are the same class of question:

- **First person**: `cg_modelanim.c:2419-2430` writes the composed byte with `=` (not `|=`) to
  `triggerhand` / `lefthand` / `garandhand` only, immediately after the `memset` at `:2394`. The
  later NODRAW manipulation in the same block uses `|=` / `&= ~` (`:2447`, `:2478-2495`,
  `:2609-2619`), so it preserves the glove bits. `viewsleeves` and every other 1P surface stay 0.
  Clean.
- **The one real cross-talk is finding #3** — `EventCoopGoreReset` clearing bits 0-1 across *all*
  surfaces including `hand`, which changes the glove rather than the trousers. That is the inverse
  of the question asked, and it is a live defect.

---

## Nothing found in these categories

- No remaining reader or writer of bit 6 / `0x40` on a surface byte anywhere in the tree
  (question A) — the two deleted renderer branches were the last.
- No file format, savegame field or netfield stores `dtikisurface_t`, and no allocation assumes its
  old size (question C).
- No other consumer of the 2-bit skin index was left un-updated: `renderergl1/tr_model.cpp:964`,
  `renderergl2/tr_model.cpp:1321` and `:1336` are the complete set, and all three were changed.
- The `MDL_SURFACE_SKININDEX` arithmetic itself is correct (question B) — the only issue is macro
  hygiene (#6).
