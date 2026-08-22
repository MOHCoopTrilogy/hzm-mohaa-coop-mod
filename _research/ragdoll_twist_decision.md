# DECISION — bone twist inheritance in the client ragdoll

**Date:** 2026-08-20 · **Against:** `openmohaa-hzm/code/cgame/cg_ragdoll.c` @ `09828f97`
("revert: remove the torso twist limit"), 2909 lines, mtime 21:08, `git status` clean.
**Inputs:** two adversarially-verified research lenses (`ragdoll_twist_integration.md`,
`ragdoll_twist_value.md`), both re-checked here against the code; prior art
`ragdoll_joints_design.md`, `ragdoll_r11_spec.md`; `.wolf/buglog.json`; and the two live
instrument datasets on disk.

---

## 1. THE VERDICT

**DO NOT BUILD — not the frame chain, not a partial, not now.** The chain is not theatre and it is
not a faithful inheritance of zero; it is a well-posed, correct, and *invisible* feature. Its
payload has two terms and both are now measured. The first is the root's own twist, which comes
solely from `bodyRot` — and `bodyRot` is deliberately **latched** at `cg_ragdoll.c:1267-1270` the
moment three points touch the world: in 52 instrumented settle-branch corpses, **50 latched (96%),
median 252 ms into a median 1353 ms life, and the total root rotation never exceeded 24°, median
5°**. The second is the holonomy of composing the intervening minimal swings, which is quadratic in
the per-joint swing angles: measured numerically at **4.2° median / 11° p90 on the ordinary corpse**
(root 5°, per-joint swings ≤16° — the measured settle distribution), i.e. under half a pixel of
sleeve rotation at 300 u. It only becomes large — 19° median at 64° swings, 67° at 144° — on corpses
the player keeps shooting *after* death, which is exactly the population where `stretch` reads 2.07,
`maxspd` 758, and ~4% of limit corrections are saturating the 12°/substep clamp, i.e. where the pose
the twist would be applied to is least trustworthy. Meanwhile the change's headline visual
justification does not exist: **hands, feet and heads already inherit their parent's rotation
bit-identically today** (proof in §3.3), so no forearm can render with a palm rolled away from its
own wrist, before or after. And the whole subsystem is dark — `coop_ragdoll` defaults `0` (`:359`)
and is set to `1` only by two test cfgs. Spending the user's one build on a render-path rotation
change that is invisible on ~96% of corpses, in a feature no player can currently see, one session
after a rotation regression shipped and was reverted, is the wrong trade. **Prior art already said
this and said it correctly** (`ragdoll_r11_spec.md:465-468`, `:1054-1059`: deferred because it "buys
little now that `s_ragDriveChild` shipped" and "puts risk on the render path that
`coop_ragdollTest 2` is structurally blind to"); this round's contribution is the *number* that
deferral was waiting for, and a corrected revisit trigger.

---

## 2. WHAT THE CHAIN ACTUALLY DELIVERS — the algebra, then the measurement

### 2.1 The algebra is sound. That was never the problem.

Re-derived independently from `ragdoll_joints_design.md:273-286`. Doc form
`W_i = Lrel_i * W_p * S_i` with `Lrel_i = W0_i * W0_p^T`. Set `D_i := W0_i^T * W_i`. Then

```
W_i = W0_i*W0_p^T * W0_p*D_p * S_i     =>     D_i = D_p * S_i          (exact)
```

and the push reduces to today's shipped expression with `S_a -> D_a`:

```
relW_ch*W_a*Enow^T = W0_ch*W0_a^T * W0_a*D_a * Enow^T = mat0[ch]*E*D_a*Enow^T
```

which is `cg_ragdoll.c:1909-1910` composed with `conj` from `:1881-1882`, verbatim. Both math-vet
caveats dissolve in the delta form: `relPos` is stored as `rel * rot0[a]^T` (`:1195`) and consumed as
`relPos * rot0[a] * X` (`:1891`), so `rot0^T * rot0` cancels identically and **no basis change is
needed**; and the delta form never passes a `float[3][4]` where `float[3][3]` is expected (the doc's
own `:317` does — `RagMat3MulTrans` takes `float out[3][3]` at `:504`). `s_ragBones` (`:77-98`) is
topologically sorted, every parent strictly less than its child, so one ascending pass suffices.
`RagPush` (`:1819-1919`) writes nothing into `ragSim_t` — it is a pure reader — so a push-side change
**cannot** form the bug-1981 energy cycle. Implementation cost: ~14 lines, `cgame.dll` only, no ABI
change (`R_SetRagdollPose` unchanged at `cg_public.h:453`), `renderergl1/tr_ragdoll.cpp` and
`renderergl2/tr_ragdoll.cpp` verified byte-identical and untouched.

**None of that is in dispute. The feature is cheap, safe to roll back, and correct. It is simply not
worth a build, because of what it would deliver.**

### 2.2 Term one — the root — is latched, and the project has been reading the wrong number

`RagPush:1861-1862` gives the pelvis `RagBodyRotation(s, S)`, which is a `memcpy` of `s->bodyRot`
(`:1235-1238`). `RagBodyRotationAdvance:1259-1270` sets `rotLocked = 1` permanently once
`nContact >= 3` with `rag_rotlock` (default `1`, `:368`), after which the filter never advances.
`contact[i]` is written in exactly one place, `RagResolveHit:1635` — world/mover collision — so a
corpse lying on the ground latches almost immediately.

> **The finding that matters most in this document:** the `rot=` field in the sleep print
> (`:2519-2527`) is computed from **`RagRawFit`**, the live anatomical fit — *not* from `bodyRot`.
> `RagPush` and `RagShapeMatch:1300` both render `bodyRot`. So **`rot=` measures a rotation the
> renderer does not use.** Nine rounds added instruments to stop tuning a rotation nobody measured;
> the instrument that landed measures the wrong one. Every ranking built on `rot=` — including one
> of the two lenses feeding this decision — over-states the twist source by the full amount the
> latch discards.

Measured, `_research/ragdoll_r12_session_swing.log`, n = 52 settle-branch corpses:

| | latched (n=50) | never latched (n=2) |
|---|---|---|
| `rotlockAt` | med **252 ms**, p90 5610 ms | — |
| `rot=` at sleep (raw fit; upper bound on `bodyRot`, which froze earlier) | med **5°**, p90 18°, **max 24°** | 1° and 84° |
| `spinmax x t_latch` (bound on `bodyRot` at the latch) | med **0.7°**; ≤6.8° for the 30/50 that latched under 500 ms | — |
| `drift=` | med **0.9 u**, p90 1.9 u, max 4.4 u | |

**Every corpse with `rot >= 25°` in the sample is the one corpse that never latched.** The root's
contribution to the chain is, for practically every corpse, a frozen ~5° rotation — and the twist it
can project onto any bone axis is bounded by that: `phi = 2*atan(tan(theta/2)*cos psi) <= theta`.

*Caveat, stated honestly:* this log predates four of today's five shipped changes. Its last line is
18:47; feet-as-points landed 20:20, joint limits 20:25, self-collision 20:41, and it reads
`couple=0.60` against today's `1.1` (`:381`). The latch mechanism and `contact[]` write site are
unchanged by all four, and no limit mask touches points 1, 11 or 13 (`RagRawFit`'s inputs,
`:1222-1223`), so the latch *rate* should be stable — but the numbers above are a **strong
indication, not a proof, for the current build.** §5.1 says how to re-measure for free.

### 2.3 Term two — holonomy — is the real payload, and it is not a fidelity gain

With the root latched, `D_0` is constant, but `D_i = D_0*S_1*...*S_i` still varies, because composing
minimal swings about different axes accumulates rotation about the final bone's own axis. Both the
chain's `D_i` and today's `S_i` map `ref_i` onto the same current direction `d_i`, so
**`D_i * S_i^T` fixes `d_i` exactly — the difference between the two reconstructions is a pure twist
about the bone's own long axis.** That makes it exactly measurable. Monte-Carlo, 4000 trials per row,
row-vector conventions matching `RagMat3RotateVec:540-546`:

| scenario | delivered twist at a depth-4 bone (forearm): med / p90 / max |
|---|---|
| A — ordinary corpse: root 5°, per-joint swings ≤16° (`swing=` p90 measured) | **4.2° / 11.0° / 20.2°** |
| B — worst latched root 24°, swings ≤16° | 4.7° / 12.0° / 26.9° |
| C — shot corpse, root latched, swings ≤64° (`swing=` median today) | 19.2° / 49.9° / 100.6° |
| D — shot corpse, root latched, swings ≤144° (`swing=` p90 today) | 67.0° / 152.1° / 179.9° |

Depth sweep (root latched, swings ≤64°): depth 1 = **exactly 0**, depth 2 = 13.3°, depth 3 = 17.4°,
depth 4 = 18.1°, depth 5 = 19.9°. Depth 1 being identically zero is the correctness check — with
`D_0 = I` the chain reduces to today's push for bones 1, 11 and 13.

Two consequences neither lens drew:

1. **The chain changes only 8 bones, not 16.** Depth-1 bones (spine1, both thighs) get the root's
   twist only, ~5°. Leaves (hands, feet, head) are exact copies of their parents both before and
   after (§3.3). What actually moves is spine2, neck, both upper arms, both forearms, both calves.
2. **This is not a fidelity improvement, it is a change of assumption.** Neither reconstruction reads
   the physical constraint that determines a humerus's true roll (the elbow plane through `pt[5]`,
   `pt[6]`, `pt[7]`). Today's assumes "every joint applies exactly the twist needed to hold the
   bone's roll fixed in world space" — physically absurd. The chain assumes "no joint applies its own
   twist" — physically reasonable for a corpse. **The chain is the better assumption.** That is a
   genuine argument in its favour, and it is why the answer is "yes in principle, no now" rather than
   a flat no. But it is worth ~4° on the corpse a player actually walks past.

---

## 3. THREE CLAIMS FROM THE RESEARCH THAT DO NOT SURVIVE

### 3.1 "Nothing generates twist under this construction" — partially superseded

`ragdoll_r11_spec.md:642-643` is right about *serial* bones (a forearm has no second attached point,
so its roll is unobservable) and right about its own subject, twist *limits* on those bones. It is
**wrong as a blanket statement**, and the shipped code says so at `cg_ragdoll.c:806-808`: the
shoulder line can wind around the spine axis indefinitely while every bone keeps its length. That
winding is observable (four points: `pt[2]`, `pt[3]`, `pt[5]`, `pt[8]`), and `RagLimitFrames:1367`
**already computes the current chest triad every limit iteration and discards it**. Record the
narrower true statement: *twist is generated only where a bone carries two or more non-collinear
simulated points — the pelvis and the chest. Nowhere else.* See §5.3.

### 3.2 `rot=` as the twist source or the revisit trigger — refuted

See §2.2. `rot=` is the raw fit; the render uses the latched `bodyRot`. And even a correct `bodyRot`
metric would be the wrong trigger, because §2.3 shows holonomy, not the root, is the dominant term.
The correct trigger is the **per-joint swing distribution** (§5.1).

### 3.3 "Feet and hands freeze their roll at the death pose" — refuted, in code

Trace `RagPush:1863-1878` for a leaf and its parent:

* Bone 12 (L Calf): `s_ragDriveChild[12] = 15` (`:119`), so `dNow = pt[15] - pt[12]` (`:1867`) and
  `ref = driveDir0[12]`, captured at `:1138-1142` as `normalize(pt[15] - pt[12])`.
* Bone 15 (L Foot): leaf (`:122`), so `dNow = pt[15] - pt[12]` (`:1870`) and `ref = restDir[15]`,
  captured at `:987-990` as `normalize(pt[15] - pt[12])` — **the same expression on the same floats.**

`S_15` and `S_12` are therefore **bit-identical today**. Identically for hand/forearm
(`restDir[7] === driveDir0[6]`) and head/neck (`restDir[4] === driveDir0[3]`). And the property
survives the chain: `ref'_15 = restDir[15]*D_12 = driveDir0[12]*D_12 = dNow` by construction, so
`S'_15 = I` and `D_15 = D_12` — the identical relationship. **A foot rolled relative to its own shin
is not a defect that exists.** Any acceptance drill that asks the user to look at wrists or ankles is
asking them to look for a change that cannot appear, and would burn the session on a false negative.

---

## 4. WHAT WOULD HAVE TO CHANGE TO REVISIT

Three conditions, all necessary:

1. **The ordinary corpse must actually articulate.** Concretely: `swingmax=` (§5.1) p90 >= **40°** on
   the *unshot* population. From the table in §2.3 that is where the chain's median payload crosses
   ~12-15° — the first magnitude a player could notice on a sleeve. Today the unshot population is at
   `swing=` p90 16° and `drift=` median 0.9 u: the settle branch is reproducing the animator's pose
   to within a unit, by design (`:212-215`).
2. **That condition is reached by exactly one roadmap item: physics owning the fall.**
   `ragdoll_r11_spec.md:1054-1059` names this pairing explicitly and it is correct. A corpse that
   falls under physics rotates, never latches early, and swings its limbs through large angles; a
   corpse handed an already-landed authored pose does not. Corpse-vs-corpse collision is the second
   item that would move the number, and it is downstream of the same change.
3. **A motion-covering drill must exist first.** `coop_ragdollTest 2` is structurally blind by
   construction: `freezePose` forces `RagMat3Identity(S)` at `:1858-1859`, so every construction of
   `S` — right or wrong — collapses to the same identity, and a parked corpse additionally has
   `E == Enow`, so both orderings of the conjugation also collapse. That blindness is why bug-1966
   shipped. The rigid-rotation drill sketched in `ragdoll_twist_value.md` §5.3 is the right
   instrument, with **one correction that must not be lost**: its ground truth is written
   `mat0[ch]*R`, which drops the entity-axis conjugation and is precisely the frame-mixing error of
   bug-1963. The truth is `mat0[ch]*(E*R*Enow^T)` (`:1881-1882`). As a max-per-bone-*angle* metric it
   survives either way (conjugation preserves angle); as a matrix compare it fails on every corpse at
   nonzero yaw.

If all three land and the chain is then built, the acceptance evidence is: side by side on **one shot
corpse**, `coop_ragdollChain 0` vs `1`, watching **shoulders, elbows, knees** — never wrists or
ankles (§3.3) — with a `rollmax=` field in the log, and every existing sleep metric
(`drift/span/maxspd/stretch/lim*`) required to be statistically unchanged, since `RagPush` is a pure
reader and a push-side change **cannot** move them. A moved sim metric is by itself proof of a wiring
defect.

---

## 5. WHERE THE NEXT BUILD SHOULD GO

### 5.0 Ship-with-anything, no drill needed: guard `cg_ragdoll.c:982`

```c
s->rot0[i][r][c] = s->mat0[s->simChan[i]][r][c];   // simChan[i] can be -1
```

`simChan[i] = -1` is set at `:879` (`coop_ragdollFeet 0`) and `:889` (footless model — **241 of 1626
human tiks, 14.8% of the roster**). `mat0[-1]` reads the 48 bytes immediately preceding `mat0`, which
are `entOrigin` (`:188`, 3 floats) + `entAxis` (`:189`, 9 floats) — exactly 12 floats, no padding — so
`rot0[15][0]` becomes the entity's world origin. It is unreachable *today* only because the anchor
table routes `Bip01 L/R Foot|Toe` to 12/14 (`:312-315`), self-anchor cannot match `-1` (`:1160`), and
the nearest fallback's strict `<` on an ascending loop (`:1187`) gives 12 the tie against a bit-copied
`pt[15]` (`:890`). Three unrelated details. If any one breaks, `rot0` is no longer orthonormal,
`rot0^T * rot0` stops cancelling in the position path (`:1891`), and the offset scales by ~1e6 — while
`RagSane:1778` only checks `pt[]`, not the pushed matrices. Fix:

```c
if (s->simChan[i] < 0) {
    memcpy(s->rot0[i], s->rot0[(i == 15) ? 12 : 14], sizeof(s->rot0[i]));
} else { /* original loop */ }
```

Safe by construction: the loop runs `i` ascending so `rot0[12]`/`rot0[14]` are already filled, and on
the shipping path (`coop_ragdollFeet 1`, model has feet) `simChan[i] >= 0` for all `i`, so the
else-branch is the original code character for character. **This is a pure undefined-behaviour removal
with no behavioural surface — it needs no drill and no cvar.** Note also, against
`ragdoll_r8_mohaadata.md:386-388`: **do not move the four foot/toe anchor rows.** Under
`coop_ragdollFeet 0` those rows are the only thing keeping a foot channel off the garbage frame, and
the change they propose is provably a no-op anyway (§3.3 — `S_12 === S_15`).

### 5.1 Two pure-reader instruments, ~16 lines, inside the existing `if (rag_debug->integer)` block at `:2478`

Both read `pt[]`, `goal0[]`, `bodyRot` and the capture directions only, and are therefore incapable of
perturbing the sim — the same purity guarantee `RagRawFit`'s round-10 rewrite established.

* **`bodyrot=`** — the angle of `s->bodyRot` from identity, computed exactly as `rot=` is at
  `:2520-2527` but from `RagBodyRotation(s, M)` instead of `RagRawFit`. This is the rotation the
  renderer actually shows. Print it *next to* `rot=`; the gap between the two is the amount the latch
  is discarding, and no one has ever seen it.
* **`swingmax=`** — `max` over `i` in 1..16 of the angle between the capture direction
  (`driveDir0[i]` when `driveOk[i]`, else `restDir[i]`) and the current one, i.e. the same quantity
  `RagPush:1877` turns into `S`, across every bone rather than only the struck one. `swing=` is set
  only at impact (`CG_RagdollImpulse:2136`) and is therefore 0 for every unshot corpse — it cannot
  measure the population the twist trigger is about. **This is the trigger metric of §4.1.**

One `rag_run.cfg` session then re-measures §2.2 against the *current* build for free and arms the
revisit decision permanently. Ride these along with whatever ships next; they are not a build.

### 5.2 The recommended next build: blood pool timing

Ranked above physics-owns-the-fall for this session specifically, because the user has just watched a
rotation regression ship and revert, and this touches no rotation code at all.

`Sentient::DropBloodPool()` is called from `Sentient::Killed` at `fgame/sentient.cpp:1801` and traces
down from the **living** centroid (`:2113`). `coop_bloodPool` defaults `32` and `coop_gorePool`
defaults `1`, both `CVAR_ARCHIVE` (`:2086`, `:2126`, `:2191`) — unlike the ragdoll, **this is live for
every player on every AI kill today**. The pool grows over 7 rings to `POOL_END 0.72` x 32 = **23 u
radius** (`:2185`, `:2208`) — deliberately smaller than the body — while the corpse keeps travelling
for the whole death animation (median `after=` 1353 ms, p90 2731 ms, from the same log), because MOHAA
death anims carry motion extraction and `droptofloor` past the `EF_DEAD` edge — the root cause of
bug-1964, in its own words. A 23 u pool detaches from the body at ~25 u of travel.

**The magnitude is genuinely unmeasured** — `RagPendingThink:2662-2664` computes a per-frame origin
delta but never accumulates or prints it, and no other site does. So: **one `gi.Printf` of the
`Killed` centroid against the origin at park, first.** If the travel is small, close the item and do
not build. If it is a body length, the fix shape is *not* "stamp at the park point" (that delays all
blood by 1.3 s, its own artifact) but **keep a small impact splat at the kill point and move the
growing pool to the park signal** — the same `entityState.solid` transition `RagServerParked:2620-2632`
already keys off. Server-side, hard-edged decal, one screenshot verifies it.

### 5.3 Named but not recommended yet: the chest triad

The one twist that provably exists and is provably discarded (§3.1). Giving bone 2 the full frame
`RagBodyTriad(pt[3], pt[2], pt[8], pt[5], faceSign[1], T)` — already built every limit iteration at
`:1367` — would make the chest mesh follow the shoulders instead of only the spine direction. Blast
radius is small: spine2 plus the two clavicles, ~3.0 channels per model. It is push-side, so bug-1981
cannot recur (that was a *sim-side* limit whose moving set contained `pt[5]`/`pt[8]`, endpoints of the
equality braces at `:141-142`; `RagRotateSet:790-800` moves `pt` and `ptPrev`, the brace correction
moves `pt` alone, and the pair pumped energy). And prior art did **not** reject it —
`ragdoll_joints_design.md:258-264` specifies it; what `ragdoll_r11_spec.md:637-644` cut was the torso
twist *limit*, a different mechanism, for the brace-endpoint reason bug-1981 then proved live.

**But how much the chest actually winds is unmeasured, and the sim already fights it three ways:** the
equality braces `{5,8}`, `{5,13}`, `{8,11}` at full capture length (`:163`), the shape-match pulling
every point to the latched-`bodyRot`-rotated goal at alpha 0.25 (`:1300-1306`), and the deliberate
exclusion of the trunk from the sticky-damage rewrite at `:1311-1315` — whose comment says in as many
words that letting damage rewrite the trunk "is what allows a chest to accumulate twist and
deformation over repeated hits until the body reads as melted." Recommending a build on inference here
would repeat this session's mistake exactly. **Measure it first, for free:** a `wind=` metric is
computable from existing state with zero new fields — the capture shoulder and hip lines are
`goal0[8]-goal0[5]` and `goal0[13]-goal0[11]` (`:2718`), the current ones are the same expressions on
`pt[]`, and the winding is the difference of their signed angles about the spine axis. Add it with
§5.1's two, and let the number decide.

### 5.4 Ranked, with the standing roadmap folded in

| # | item | effort | risk | build |
|---|---|---|---|---|
| 1 | `:982` guard (§5.0) + the `bodyrot=` / `swingmax=` / `wind=` instruments (§5.1, §5.3) | ~25 lines | none — no behavioural surface | rider on anything |
| 2 | **Blood pool timing** (§5.2) — one printf, then ~20 lines | small | low, server-side | **next** |
| 3 | Physics owning the fall — the precondition for #4, #5 and for twist; needs the `goal[]` cross-fade of `ragdoll_r11_spec.md:1039-1044` | large | high | its own build, after #2 |
| 4 | Corpse-vs-corpse collision — downstream of #3, and the second thing that raises `swingmax=` | med | med | with/after #3 |
| 5 | Rigid-rotation drill (§4.3) — the missing motion-side regression test for the whole subsystem; would have caught bug-1966 | ~60 lines | low (read-only) | with #3 |
| 6 | Chest triad (§5.3) — only if `wind=` says the winding is real | ~10 lines | low | data-gated |
| 7 | Player corpses — four gates, not three: `:2820`, `:2830`, `RagServerParked:2621` vs `player.cpp:3471`, and `RagPendingThink`'s own eType drop at `:2648` | large | med | later |
| — | Weapon/helmet separation | — | — | **not applicable on AI corpses**: `Actor::DispatchEventKilled` calls `DropInventoryItems()` (`fgame/actor.cpp:5527`), so `tag_weapon_*` carries nothing; and the standard German model (and every armed corpse in the log printed `channels=72`) has no `helmet` bone at all — the helmet is skin. Hook B (`tr_ragdoll.cpp:174-196`) is correct and currently has nothing riding it |
| — | **Bone twist inheritance** | — | — | **not until §4's three conditions hold** |

---

## 6. RISK REGISTER

| # | risk | why it is real | mitigation |
|---|---|---|---|
| **1** | **A future session re-proposes the chain from the design doc and ships it**, because `ragdoll_joints_design.md` reads as an approved plan and the algebra vets clean — exactly the failure mode of the torso twist limit, whose analysis existed and was not re-read. | The doc has no "deferred" banner; `ragdoll_r11_spec.md`'s deferral sits ~600 lines from the section that proposes the mechanism; and a math-vet *confirming* the chain is easy to mistake for a recommendation to build it. | This file is the answer, and one merged entry in `docs/TRAPS.md` must carry both halves: the chain is deferred (with §4's numeric trigger), **and** the two-root variant / chest twist *limit* is permanently rejected (`ragdoll_r11_spec.md:637-644` + bug-1981). Anchor both to `cg_ragdoll.c:1267-1270` — the latch is the fact that makes the deferral true. |
| **2** | **`:982` becomes reachable and the render silently flies apart**, when someone tidies the anchor table, changes the pre-lift radii (4.0 vs 3.0, `:294`/`:296`), or acts on `ragdoll_r8_mohaadata.md:386-388`. | Three unrelated implementation details currently hold it benign; none is documented as load-bearing; `RagSane:1778` checks `pt[]` only and would not catch it. | §5.0 — three lines, no behavioural surface, ship with anything. |
| **3** | **The deferral is judged against the wrong number again.** `rot=` is on every sleep line, reads large on shot corpses, and is *not* what the renderer uses; `swing=` is 0 for every unshot corpse. Both invite a wrong "the body twists plenty now" conclusion. | Already happened once inside this round's own research. | §5.1's `bodyrot=` and `swingmax=`, printed next to the existing fields so the discrepancy is visible rather than inferred. Until they exist, treat §2.2's numbers as strongly indicated for the *pre-20:20* build and not proven for HEAD. |

---

## 7. FOR THE PROJECT RECORD — what this round establishes about the rotation model

The ragdoll's rendered orientation is built from exactly **two** kinds of rotation, and knowing which
is which answers most future questions without reading the file. The **root** (`bodyRot`) is a full
anatomical frame fit from the spine and hip lines — it carries real twist, it is slewed at 0.12 and
then **latched permanently** at three world contacts (`:1259-1270`), it is what `RagPush:1862` and
`RagShapeMatch:1300` render, and it is **not** what the sleep print's `rot=` measures. Every other
bone gets `RagMat3FromTo` (`:556`), the minimal swing, which by construction adds exactly zero
rotation about the bone's own axis, so **no serial bone's roll is ever computed — only inherited from
the root, or, under a hierarchy chain, accumulated as holonomy.** Twist is observable in this model
only where a bone owns two or more non-collinear simulated points, which is true of the pelvis and the
chest and of nothing else; the chest's frame is already built every limit iteration at `:1367` and
thrown away. Leaf bones — hands, feet, head — are **bit-identical copies of their parents** already,
because a leaf's `restDir` and its parent's `driveDir0` are the same capture expression on the same
two points, and that identity survives any hierarchy change; so no defect involving a wrist or ankle
rolled against its own forearm or shin can exist, and no drill should look for one. Finally, the
positional and rotational halves of `RagPush` are deliberately different reductions of the same
matrix — position cancels `rot0` exactly (`:1195` against `:1891`) while rotation carries the entity
conjugation `E*S*Enow^T` (`:1881-1882`, bug-1963, bug-1964) — and `coop_ragdollTest 2` can validate
neither, because `S = I` and `E == Enow` on a parked corpse collapse every candidate expression to the
same answer. **Any future change to the rotation path needs a moving-corpse drill, and the
rigid-rotation drill of §4.3 — with `mat0[ch]*(E*R*Enow^T)` as its ground truth, never `mat0[ch]*R` —
is the one to build.**
