# Ragdoll r11 — DISMANTLING THE TRUSS

Lens: **loosening the body**. Written 2026-08-20 against `cg_ragdoll.c` at **2176 lines**
(settle branch + child-driven bone rotation + post-death impulses + the round-10 instruments,
plus the `coop_ragdollTruss` knob and the asymmetric distal impulse added part-way through this
analysis). Companion to `ragdoll_joints_design.md` (the 21-limit design) and `ragdoll_r9_spec.md`
(the atomicity rule). Where this document and those disagree, the disagreement is called out and
the measurement is shown.

> ⚠ **Two live edits landed in `cg_ragdoll.c` while this was being written**, and both are in
> the code this document analyses. They are folded in and every number below is re-measured
> against the current file, but a reader comparing against an earlier draft or an earlier
> binary should know which build they are holding:
> 1. **`coop_ragdollTruss`** (`:326`, applied `:991-994`) scales brace stiffness, `0` = truss
>    entirely off. This turns §5's whole T2 experiment into a console line. ⚠ Note it is
>    all-or-nothing: the `break` at `:992` skips the *whole* table, so `0` also disables `{5,8}`
>    and `{11,13}` — the two braces §1 says must never be deleted. It is a **diagnostic, not a
>    shipping configuration**, and it cannot isolate rows 6-15 from rows 0-1. (Both were measured
>    separately here and are indistinguishable, so for this A/B it does not matter.)
> 2. **The bullet impulse is now asymmetric** (`:1443-1448`): `w = [0.80 + 0.20t, 0.15(1−t)]`
>    on the distal/proximal ends instead of `[t, 1−t]`, plus a subtree limp (`:1466-1477`).
>    This raises the distal impulse ~1.8× and changes §4's conclusion materially.
>
> The comment added with edit 2 records a new live finding that independently confirms this
> document's headline: *limbs "dont really move at all" **even with the truss switched off
> entirely**.*

Everything numeric below was re-derived, not copied. The harness is
`scratchpad/rag_truss.py` + `rag_dof.py` + `rag_blast.py` + `rag_minspan.py`: a line-faithful
replica of `RagStep` / `RagCollideWorld` / `CG_RagdollImpulse`, plus a constraint-Jacobian rank
analysis of the 17-point body. Method and reference skeleton are in §7.

---

## 0. THE HEADLINE, AND IT IS NOT WHAT THE BRIEF ASSUMED

The brief's premise is that the equality braces `{5,8}`, `{5,13}`, `{8,11}` tie the upper-arm
points into a rigid torso and that is why "arms arent moving at all when shot". **That premise
is measurably false**, and it is now false twice over — once in this harness, once in the
user's own live `coop_ragdollTruss 0` test. Deleting all sixteen braces changes the wrist
excursion of a shot arm by **0.01 u**:

| brace set (settle branch, `coop_ragdollStiff 0.25`, `iLarge 0` = 90 u/s) | wrist travel | forearm swing | blast deform/translate |
|---|---:|---:|---:|
| all 16 (`coop_ragdollTruss 1`) | **1.42 u** | 5.9° | 0.20 |
| rows 6-15 deleted (fold braces gone) | 1.42 u | 5.9° | 0.20 |
| ... plus `{5,13}`,`{8,11}` gone | 1.42 u | 5.9° | 0.23 |
| ... plus `{5,8}` gone | 1.42 u | 5.9° | 0.22 |
| **no braces at all (`coop_ragdollTruss 0`)** | **1.42 u** | 5.9° | 0.24 |

Identical to two decimal places at 90, 150 and 255 u/s. Three other mechanisms are doing the
work the truss is being blamed for:

1. **Impulse magnitude, and it dominates everything.** The current asymmetric split
   (`:1443-1448`) gives a mid-forearm hit `w = 0.90` on the wrist instead of the old `0.5`, so
   the per-substep impulse at `iLarge 0` is now `90 · 0.90 · 0.90 · 0.008 = 0.593 u/substep`
   against a `0.35` resting-contact gate — **clear of it, where the old symmetric split at
   0.30-0.36 u/substep straddled it exactly** and was annihilated in the substep it was applied
   (harness: implied wrist speed `0.3498 → 0.0000`). That edit alone should take the arm from
   ~1.6° to ~5.9°. It has not been playtested yet, and 5.9° is still marginal. Force is the
   remaining lever: 150 u/s → **10.6°**, 255 u/s → 17.9°.
2. **The floor still re-arms every ~4 substeps.** A resting point is parked 0.25 u proud
   (`:1043`), falls `512·0.008² = 0.0328 u`/substep and re-contacts; the measured re-kill period
   is 4 substeps = **32 ms of travel, then zero** (`:1053`). Exempting limp points from that
   kill is now worth only +0.1 to +0.4° — a cheap correctness fix, no longer the headline.
3. **`RagShapeMatch` — not the braces — is the rigid slab.** On a grenade
   (`force 400 / radius 180`), deformation is governed entirely by `coop_ragdollStiff`:

   | `coop_ragdollStiff` | translate | deform | deform/translate |
   |---:|---:|---:|---:|
   | 0.25 (today) | 23.9 u | 4.9 u | **0.20** |
   | 0.15 | 23.2 u | 5.9 u | 0.26 |
   | 0.10 | 22.7 u | 6.9 u | 0.30 |
   | 0.05 | 22.3 u | 8.7 u | 0.39 |
   | 0.00 | 25.0 u | 19.4 u | **0.78** |

   That is a **4× swing in limb flail from one cvar**, against a <0.05 swing from deleting the
   entire truss. "Still kind of as a whole body" is `coop_ragdollStiff`, full stop.

**So the truss is not the payload — but dismantling it is still the right move**, for a
different and more important reason: the braces are the *only* thing standing between today's
build and a much lower `coop_ragdollStiff`, and they are a bad stand-in that no longer even
earns its cost on the settle branch. §1 audits them; §2 proves what has to replace them before
they go; §3 gives the order.

---

## 1. THE SIXTEEN BRACES, ONE BY ONE

Definitions: `s_ragBraces` `cg_ragdoll.c:123-140`, `s_ragBraceMinFactor` `:145-153`, capture
lengths `:703-710`, solve `:988-1009` (inside the 6-iteration loop at `:974`, so **24 full-
strength passes per frame** against the shape-match's 4 partial ones). A 2-point distance
constraint is projected exactly in one Gauss-Seidel pass, so every brace is effectively
stiffness 1.0.

Two properties apply to the whole table and are worth stating before the rows:

- **The fold braces are pose-relative, not anatomical.** `braceLen` is `minFactor ×` the
  distance *in the captured death pose* (`:707-709`). A corpse captured with a straight elbow
  can flex it ~83° before `{5,7}` fires; a corpse captured already bent can flex 25% further
  and no more. The same brace is a different joint limit on every body. An angular limit is
  absolute.
- **No brace has any relax path.** `RAG_CONTACT_RELAX` (`:64`) and `RAG_IMPACT_RELAX` (`:65`)
  multiply `alpha` inside `RagShapeMatch` (`:931-939`) and nothing else. Where the shape-match
  yields to the ground or to a bullet, the braces do not. They are the residual rigidity that
  survives every softening knob the file has.

| # | pair | kind | what it actually constrains | superseded by | delete? |
|---:|---|---|---|---|---|
| 0 | `{5,8}` shoulder↔shoulder | **equality** | Chest width. With links `2→5`, `2→8` it makes `{2,5,8}` a **rigid triangle**. It does *not* restrain the arm — it restrains the *socket*, which is anatomically correct (scapular travel is a couple of units). | nothing | **NEVER.** Promote it: this triangle is the chest frame `T2` every shoulder/neck limit is measured in. |
| 1 | `{11,13}` thigh↔thigh | **equality** | Hip width. With links `0→11`, `0→13` makes `{0,11,13}` a **rigid triangle** = the pelvis. | nothing | **NEVER.** Same reason — this is the pelvis frame `T0`. |
| 2 | `{5,13}` L shoulder↔R thigh | **equality** | One half of the torso twist+bend lock. A chest twist of `+θ` lengthens this diagonal and shortens `{8,11}`; both being equality blocks torso twist to first order. Verified independent: removing it costs exactly 1 DOF at a generic pose. | **J1** spine1 flex, **J2** spine1 lateral, **J3** torso twist | **YES — only with the limits.** |
| 3 | `{8,11}` R shoulder↔L thigh | **equality** | The other half. Same 1 DOF. | J1 / J2 / J3 | **YES — only with the limits.** |
| 4 | `{3,1}` neck↔spine1 | **equality** | The fold at `pt[2]` — i.e. the **spine2 joint**. Freezes it outright (equality, both directions). | **J26/J27** (chest-vs-spine1 swing) — **which are NOT in the 21-limit table.** See §2. | **YES — but only with J26/J27, which the current design does not have.** |
| 5 | `{0,2}` pelvis↔spine2 | **equality** | The fold at `pt[1]` — the **spine1 joint**. Freezes it. | **J1 + J2** | **YES — only with the limits.** |
| 6 | `{2,4}` spine2↔head, 0.80 | push-apart | Neck fold. Head cannot approach the chest closer than 80% of its captured distance. | **J4** neck flex, **J5** neck lateral | **YES.** |
| 7 | `{2,6}` spine2↔L forearm, 0.70 | push-apart | Elbow cannot approach the chest. Crude stand-in for both a shoulder limit *and* forearm-vs-torso self-collision. | **J6/J8** (L shoulder) + self-collision pair `(6,2)` | **YES.** |
| 8 | `{2,9}` spine2↔R forearm, 0.70 | push-apart | Mirror. | **J7/J9** + self-collision `(9,2)` | **YES.** |
| 9 | `{5,7}` L upperarm↔L hand, 0.75 | push-apart | The **elbow** fold, one-sided, pose-relative. | **J10** elbow hinge `[+2°,+150°]`, **J12** out-of-plane | **YES.** |
| 10 | `{8,10}` R upperarm↔R hand, 0.75 | push-apart | Mirror. | **J11 / J13** | **YES.** |
| 11 | `{0,12}` pelvis↔L calf, 0.75 | push-apart | Labelled "knee fold limit" at `:135`. **The label is wrong** — `pt[12]` *is* the knee, so this is a function of the **hip** angle and has never constrained a knee. (`ragdoll_joints_design.md` §1.3 already caught this; confirming.) | **J14/J16** (L hip). The real knee fold needs the feet: `{11,15}`. | **YES.** |
| 12 | `{0,14}` pelvis↔R calf, 0.75 | push-apart | Mirror, same mislabel. | **J15/J17** | **YES.** |
| 13 | `{1,11}` spine1↔L thigh, 0.75 | push-apart | Comment at `:137` calls it "geometrically inert". **Also wrong.** With `{11,13}` making the pelvis rigid, `\|pt1−pt11\|` varies with the direction of segment `0→1` — and that segment is exactly one of the two DOF that *no limit in the 21-table can see* (§2). This inert-looking brace is today's only one-sided bound on it. | **J1b/J1c** (lumbar swing), which the 21-table does not have | **YES — only with J1b/J1c.** |
| 14 | `{2,12}` spine2↔L calf, 0.60 | push-apart | The hip jackknife guard added in bug-1963. | **J14** hip flexion `≤ +110°` | **YES.** |
| 15 | `{2,14}` spine2↔R calf, 0.60 | push-apart | Mirror. | **J15** | **YES.** |

**Verdict: 16 → 2.** Keep `{5,8}` and `{11,13}` forever and re-describe them in the code as the
rigid pelvis/chest triangles rather than as "anti-pile truss". Delete the other fourteen and
the whole `s_ragBraceMinFactor` table.

The four torso equality braces (`{5,13}`, `{8,11}`, `{3,1}`, `{0,2}`) are a **must-delete, not
a may-delete**, once the limits land: §2.3 finds no feasible configuration at all for
`6 braces + 27 limits + self-collision`, and the rank ledger shows why — with all six braces the
body has 23 internal DOF while the 27 limit functions still span only rank 23, so at least four
limits become linearly dependent on the braces. Leaving them in is not "extra safety", it is a
guaranteed constraint fight.

### 1.1 A conditioning hazard worth a comment, not a fix

At a **bilaterally symmetric, planar** pose the 6-equality-brace system drops from rank 22 to
rank 19 — three singular values at 1e-16. All six are independent at any generic pose
(drop-one test: each removes exactly 1 DOF), so this is *ill-conditioning near symmetry*, not
redundancy. A soldier lying flat on his back with his arms at his sides is close to that pose,
and near-dependent equality constraints are a classic Gauss-Seidel jitter source. It is one
more reason the four torso braces should go rather than be tuned. `{5,8}` and `{11,13}` are
never involved — they stay full rank at every pose tested.

---

## 2. DOF ACCOUNTING — AND WHY THE 21-LIMIT TABLE IS SIX SHORT

Counting is not enough: a count cannot see redundancy, and redundancy is what made the earlier
hip jackknife survive four braces that all claimed to stop it. So this is done as a **rank
computation on the constraint Jacobian**, at a generic (asymmetric, link-projected) pose.

Method: build `J` = gradients of the equality constraints (16 parent links + kept braces);
`rank(J)` by SVD; the null space `N` is the space of infinitesimal motions the equalities
permit. Then build `G` = gradients of every limit's **angle function**, restricted to `N`.
Angles are invariant under global translation and rotation, so all 6 rigid modes lie in
`ker(G)` automatically. Therefore

> **blind DOF = dim(N) − 6 − rank(G|N)** — the number of internal deformation modes that
> *no limit can see*. Zero blind DOF ⇒ no free collapse mode.

### 2.1 The ledger (17 points: the 15 shipped + `Bip01 L/R Foot`)

| configuration | eq rows | rank | dim(N) | internal | rank(G\|N) | **BLIND** |
|---|---:|---:|---:|---:|---:|---:|
| 16 parent links only | 16 | 16 | 35 | **29** | 0 | 29 |
| + all 6 equality braces | 22 | 22 | 29 | 23 | 0 | 23 |
| + `{5,8}`,`{11,13}` only | 18 | 18 | 33 | **27** | 0 | 27 |
| + `{5,8}`,`{11,13}` + **the 21-limit table** | 18 | 18 | 33 | 27 | 21 | **6** |
| + `{5,8}`,`{11,13}` + **27 limits (proposed)** | 18 | 18 | 33 | 27 | **27** | **0** |

`51 coordinates − 16 links = 35`; minus 6 rigid = 29 internal deformation DOF. The two kept
braces make the pelvis and chest rigid triangles and remove 2 more: **27 internal DOF to
account for.** The 21-limit table accounts for 21. **Six are unwatched.**

### 2.2 Which six, and why the design missed them

The blind DOF are not exotic — they are a structural consequence of how the two anatomical
triads are built. `RagRawFit` (`:840-854`) and `ragdoll_joints_design.md` §3.2 both derive the
frame's **up** axis from a spine *segment*: `T0` up `= unit(pt[1] − pt[0])`, `T2` up
`= unit(pt[3] − pt[2])`. A frame that is defined by a segment cannot measure that segment.
Rotate `pt[1]` about `pt[0]` and `T0` rotates with it; every hip limit `J14-J17` is measured
against `T0` and rides along reading "in range" while the legs fold relative to the *actual*
pelvis. That is a jackknife mode by construction. The chest has the mirror-image version, and
the arms ride *that* one.

Fix: build the limit frames from the **rigid triangles**, which `{5,8}` and `{11,13}` already
guarantee:

```
T0 (pelvis body):  L = unit(pt[11] − pt[13])                        // hip line, rigid
                   w = unit((pt[11]−pt[0]) × (pt[13]−pt[0])) · sgn  // triangle normal
                   F = unit(w − (w·L)L) ;  U = F × L                // rows [F, L, U], L×U = F
T2 (chest  body):  L = unit(pt[5] − pt[8]) ; same construction about pt[2]
```

`sgn` is resolved once at capture against `entAxis[0]`, exactly as `faceSign` already is. Both
frames then depend only on points that are rigid to each other, so the two spine segments
become measurable — and the six missing angle functions fall out. Verified incrementally, each
one closing exactly one blind DOF:

| added function | measured against | rank(G) | range (start here) |
|---|---|---:|---|
| **J1b** lumbar flex/ext | `dir(0→1)` vs `+T0[2]` about `T0[1]` | 21 → 22 | `[−15°, +30°]` |
| **J1c** lumbar lateral | same, about `T0[0]` | 22 → 23 | `[−15°, +15°]` |
| **J26** chest-vs-spine1 flex | `dir(1→2)` vs `T2[2]` about `T2[1]` | 23 → 24 | `[−30°, +30°]` |
| **J27** chest-vs-spine1 lateral | same, about `T2[0]` | 24 → 25 | `[−20°, +20°]` |
| **J24** neck-base flex | `dir(2→3)` vs `+T2[2]` about `T2[1]` | 25 → 26 | `[−25°, +30°]` |
| **J25** neck-base lateral | same, about `T2[0]` | 26 → 27 | `[−20°, +20°]` |

**J26/J27 are the ones that matter most**: they are the spine2 joint, and `{3,1}` is the only
thing constraining it today. Ship the limits without J26/J27 and delete `{3,1}`, and the chest
gets a completely free 2-DOF hinge on top of the spine — the exact failure class the truss was
built to stop.

Degeneracy guard: the chest triangle is well conditioned (`|a×b|/|a||b| ≈ 0.99` at the
reference skeleton), the pelvis triangle is thinner (`≈ 0.52`, ~31°). Below ~0.15, fall back
to today's segment-based triad for that corpse and print it under `r_ragdollDebug 3`.

**Do not route this through `RagRawFit`.** That function feeds `bodyRot`, the spin instrument
and the shape-match, and the spin problem is closed (rotation after landing 0-28°, spin at rest
0-3°/s). Build `T0`/`T2` as *new* frames used only by the limit solver. `RagRawFit` and
`RagBodyRotationAdvance` (`:867-909`) are not touched by any of this.

### 2.3 The honest limit of the "no pile" claim

Zero blind DOF proves no *unbounded* internal mode survives. It does not by itself bound how
compact the body can get, so that was measured too — constrained minimisation of the radius of
gyration subject to the link equalities and the limits:

| configuration | min radius of gyration | max-axis span |
|---|---:|---:|
| the authored standing pose (reference) | 25.2 u | 80.7 u |
| 16 links only (bead chain) | **8.2 u** | 24.2 u |
| + today's 6 equality braces | 11.8 u | 29.5 u |
| + `{5,8}`,`{11,13}` + 27 limits | 12.6 u | 31.5 u |
| **+ `{5,8}`,`{11,13}` + 27 limits + the 16 self-collision pairs** | **13.5 u** | **43.2 u** |
| + all 6 equality braces + 27 limits + self-collision | *no feasible point found* | — |

Four things to take from this:

- **Today's truss does not geometrically prevent a pile.** 29.5 u max-axis span is inside the
  code's own pile criterion (`<35 u on every axis`, `:1752-1753`). The truss raises the floor
  from 24 u to 29 u — it makes the pile harder to reach, not impossible.
- **Limits alone do not either.** 31.5 u is still inside it. A fully-tucked human really does
  fit in ~32 u, and that configuration is anatomically *legal* — the reason it never happens to
  a corpse is that gravity cannot drive it there, not that geometry forbids it.
- **Limits + self-collision do.** 43.2 u clears the pile threshold by 8 u. **This promotes
  self-collision from optional garnish to the constraint that actually closes the argument**,
  and it is the cheapest thing in the whole plan: 16 point-pair distance tests
  (`ragdoll_joints_design.md` §7), ~770 comparisons per frame for a full pool.
- **Keeping all six equality braces on top of the limits over-constrains the system.** The
  optimiser finds no feasible configuration at all in that combination. With all six braces the
  body has 23 internal DOF and the 27 limit functions still span rank 23 — so at least four
  limits are linearly dependent on the brace set, which is precisely the "redundant constraints
  fight" jitter source `ragdoll_joints_design.md` §5.5 lists. *Caveat: an SLSQP failure is not a
  proof of infeasibility; but combined with the rank deficit it is strong evidence that the four
  superseded equality braces **must** be deleted in the limits build, not merely that they may.*

What the limits actually exclude is the class the player reads as "mangled": knees bending
backwards, elbows hyperextending, arms threaded through the ribcage. That class is exactly the
blind-DOF set, and with 27 functions it is empty.

A dynamic cross-check agrees that span cannot grade the truss: dropping a standing body 55 u
onto flat ground with the shape-match off gives max-axis spans of 46/46/61 u with all 16
braces and 33/42/47 u with none — overlapping distributions across seeds. The truss's
contribution to *span* is inside the noise. Its contribution to *legality* is what limits
replace.

---

## 3. THE STIFFNESS CASCADE

Measured, not reasoned. Blast metrics are `translate` = centroid displacement (slab motion),
`deform` = RMS point displacement after removing the centroid (flail).

| parameter | site | today | recommended | evidence |
|---|---|---:|---:|---|
| **bullet force, `iLarge 0`** | `r9_impact` §4.4 table, applied `:1456` | 90 u/s | **150 u/s** | The dominant lever for *bullets*: forearm swing 5.9° → **10.6°** → 17.9° at 90 / 150 / 255. Nothing else in this table moves the arm by more than 1°. |
| **`coop_ragdollStiff`** | `:311`, applied `:1022-1032` | 0.25 | **0.10** (once limits land) | The dominant lever for *blasts* and for the body's general looseness: deform/translate 0.20 → 0.30 at 0.10, 0.39 at 0.05, 0.78 at 0.00. **This is the one to sweep.** |
| `coop_ragdollTruss` | `:326`, applied `:991-994` | 1 | **1, then delete the table in T3** | Zero measured effect on anything, at any force (§0). Diagnostic only — and it disables `{5,8}`/`{11,13}` too, which must never ship off. |
| `RAG_CONTACT_RELAX` | `:64` | 0.15 | **0.15 — unchanged** | Governs drape depth, not looseness. Lowering it re-opens bug-1970 (hover) territory; raising it un-drapes the corpse. Not the arm's problem. |
| `RAG_IMPACT_RELAX` | `:65` | 0.05 | **0.05 — unchanged** | Already effectively zero in the early window (`a_eff = 0.25 × 0.0627 = 0.0157`/substep on the first substep). Setting it to 0.00 moves the wrist by <0.1 u. Not a lever. |
| `RAG_IMPACT_LIMP_MS` | `:66` | 600 | **600 — unchanged** | Governs the *return*, not the *departure*. 600 → 2000 ms moves peak wrist travel by 0.1 u. |
| `RAG_DAMPING` | `:60` | 0.98 | **0.98 — unchanged, and do not raise it** | 0.98 → 0.99 raises translate 23.9 → 32.2 u but deform only 4.9 → 5.3 u: the ratio gets *worse* (0.20 → 0.16). Raising damping makes "moves as a whole body" worse, not better. |
| `RAG_ITERS` | `:61` | 6 | **4, in the limits build** | Deform is flat from 3 to 8 iterations (4.9 / 4.9 / 4.9 / 4.8 u). Dropping to 4 frees a third of the constraint budget to pay for the limits, per Macklin 2019 (substeps beat iterations). Use Müller's `k' = 1 − (1−k)^(1/n)` for limit stiffness so the tuning stays iteration-independent. |
| resting-contact gate | `:1053` | `\|v\| < 0.35` | **0.35 globally, but exempt limp points** | See §4. Widening it globally re-opens bug-1963's recorded regression ("froze the landing slide, folding bodies vertically over their first contact"). |
| sleep speed gate | `:1742` | 10 u/s | **10 — never touch** | bug-1962. |

### Does the shape-match still earn its place once limits exist?

**Yes, and the min-compactness table is why.** Limits are inequalities: with `alpha = 0` and
all 27 limits on, the body is free to adopt *any* legal pose, and a legal pose can be half as
extended as the authored one (Rg 12.6 vs 25.2). Nothing but the shape-match holds the
animator's silhouette. The correct division of labour is:

> **The limits make it safe to turn the shape-match down. The shape-match is what stops a
> legal corpse from being a boring one.**

So `RagShapeMatch` stays, `RAG_CONTACT_RELAX` and `RAG_IMPACT_RELAX` stay, and the single
number that moves is `coop_ragdollStiff`.

### The one parameter to sweep live

**`coop_ragdollStiff`.** It is already `CVAR_TEMP` (`:311`), already the shape-match's only
input (`:1022`), already bound to hotkeys (`rag_soft.cfg` F11 = 0.10, `rag_firm.cfg` F1 = 0.50),
and already printed on every sleep line as `alpha=` (`:1752`). Sweep it **after** the limits
land, never in the same session — the r10 discipline. Suggested ladder: 0.25 (as shipped,
5 kills) → 0.15 → 0.10 → 0.05, ~10 kills each, with a grenade at each step.

**And explicitly not `coop_ragdollTruss`.** The new knob (`:326`) is the right *experiment* —
it settles §1 without a build — but it is the wrong *sweep*: every measurement in this document
says it moves nothing you can see. Use it once, as T2's A/B, then leave it at 1 until T3 deletes
the fourteen braces for good.

---

## 4. THE ARM PROBLEM — BEFORE AND AFTER, FROM THE CODE

### 4.1 The chain, step by step, on the current build

Reference skeleton (§7): upper arm `pt[5]→pt[6]` ≈ 17.5 u, forearm `pt[6]→pt[7]` ≈ 13.7 u.

1. **`CG_RagdollImpulse` finds the segment**, not the joint. Segments are indexed `parent→j`,
   so a mid-forearm hit resolves to `j=7 (L Hand)`, `p=6 (L Forearm)`, `t ≈ 0.5` — correct.
2. **Force is split asymmetrically** (`:1443-1448`) and scaled by `k2 = 1 − d/radius` (`:1435`).
   At `iLarge 0` = 90 u/s with a skin entry ~3 u off the bone axis, the wrist takes
   `90 × 0.90 × 0.90 × 0.008 =` **0.593 u/substep** and the elbow `0.049`.
   *Previously — symmetric `w = 0.5` — this was `0.324`, and step 5 destroyed it.*
3. **`limpMs` is set on both ends and on the whole subtree below the hit** (`:1466-1477`), so
   `RagShapeMatch` yields there: `a_eff = 0.25 × (0.05 + 0.95 × 0.0133) = 0.0157`/substep on the
   first substep. **The pose pull is not the obstacle**, and never was.
4. **The constraint network does not resist.** The forearm's own link `{6,7}` sees a
   second-order length change; `{5,6}` likewise (`0.59²/(2×17.5) = 0.010 u`); the push-apart
   braces `{5,7}` and `{2,6}` sit at 0.75× and 0.70× of capture and are nowhere near firing.
   The shoulder `pt[5]` is welded by three equality constraints — correct, since a socket should
   not translate, and irrelevant, since an arm swings *about* it.
5. **`RagCollideWorld` used to kill it outright** (`:1053`). The gate is
   `VectorLength(v) < 0.35f` — the *same units* as the impulse, no conversion. At 0.324 the old
   symmetric impulse was below it and any point touching the floor was snapped to `pos` with
   `ptPrev = pt` in the same substep. At 0.593 the current impulse clears it.
6. **The floor still re-arms.** A resting point parked 0.25 u proud (`:1043`) falls
   `0.0328 u`/substep and re-contacts; measured re-kill period **4 substeps = 32 ms**. That caps
   travel for any point sliding along the ground rather than lifting off it.
7. What survives is ballistic and damped: an upward `v` against `sv_gravity 512` rises `v²/2g`,
   and 78% of the impulse is damped away by the end of the limp window (`0.98^75 = 0.220`).

**Net on the current build: 1.42 u of wrist travel = 5.9° of forearm swing.** That is right at
the edge of visible — better than the ~1.6° the user was looking at, and probably still not
enough. **And the truss contributes nothing to any of the seven steps.**

### 4.2 What changes, in order of leverage

| change | wrist travel | forearm swing | note |
|---|---:|---:|---|
| the build the user tested (symmetric split) | 0.38 u | 1.6° | |
| **current build** (asymmetric distal split) | **1.42 u** | **5.9°** | untested live |
| current + limp exempt from the resting kill | 1.52 u | 6.4° | one clause, free |
| **current + force 150** | **2.51 u** | **10.6°** | the lever that matters |
| current + force 255 | 4.20 u | 17.9° | too much — bodies read as rubber |
| current + force 150 + `coop_ragdollStiff 0.05` + limp exempt | ~2.9 u | ~12° | the loosening cascade's contribution |
| **deleting all 16 braces, at any force** | **no change (±0.01 u)** | — | measured at 90 / 150 / 255 u/s |

**Recommendation: raise the `iLarge 0` bullet floor from 90 to 150 u/s** and re-scale the rest
of the `ragdoll_r9_impact.md` §4.4 table by the same factor. The original 90 was calibrated
against `Sentient::CoopGoreDeathKinetics`'s 90-340 u/s band — but the server applies that to a
*whole rigid corpse with mass and a bounding box*, while cgame applies it to a massless point
that a floor contact can zero. The two were never the same quantity, and the client side needs
the middle of the band, not its floor.

The limp exemption is one clause at `:1053`, and is worth taking even though it is now small:

```c
    if (tr->plane.normal[2] > 0.7f && VectorLength(v) < 0.35f && !s->limpMs[i]) {
```

It cannot re-open bug-1963: that regression was widening the gate *globally* to 1.2, freezing
the landing slide for every point of every body. `limpMs` is non-zero only on points struck
within the last 600 ms, on one corpse, for a bounded window.

**Why the calibration was off in the first place.** `ragdoll_r9_impact.md` §4.4 set the bullet
floor at 90 u/s to match `Sentient::CoopGoreDeathKinetics`'s own 90-340 u/s band. But the
server applies that to a *whole rigid corpse with mass and a bounding box*; cgame applies it to
a massless point that a floor contact then zeroes. The two were never the same quantity, and
the client side needs the top of the band, not the bottom.

### 4.3 After the truss changes — what actually resists an arm

| resisting constraint | today | after |
|---|---|---|
| link `{5,6}`, `{6,7}` | equality, second-order in a rotation | **unchanged** — these are bone lengths and must stay |
| brace `{5,7}` (elbow fold, 0.75× capture) | one-sided, pose-relative, ~83° of flex on a straight-armed capture | **gone** → `J10` hinge `[+2°, +150°]`, absolute, plus `J12` out-of-plane `\|ψ\| ≤ 12°` |
| brace `{2,6}` (elbow-vs-chest, 0.70×) | one-sided distance | **gone** → `J6/J8` shoulder swing + self-collision pair `(6,2)` at 9 u |
| `{5,8}`, `{5,13}`, `{8,11}` welding `pt[5]` | 3 equalities, socket pinned | `{5,8}` **stays** (socket stays pinned — correct); the two crosses go, so the *chest* can now bend and twist under an arm's reaction instead of being infinitely heavy |
| `RagShapeMatch` | `a_eff = 0.0157`/substep during limp, 0.25 after | same shape, but the terminal pull scales with `coop_ragdollStiff` — at 0.10 the limb returns home over ~1.5× longer |
| resting-contact kill (`:1053`) | annihilated the *old* symmetric impulse outright; the current asymmetric one clears the gate but is still re-killed every ~4 substeps while sliding | **exempted while limp** |

The honest summary: **loosening the shoulder is not what unblocks the arm, because the shoulder
was never the blocker.** What unblocks the arm is (i) giving it enough velocity — the
asymmetric split did half of that, the force floor is the other half — and (ii) not zeroing
that velocity on contact. Neither is a truss change.

What the truss work *does* buy the arm is second-order but real: with `{5,13}`/`{8,11}` gone the
chest is no longer infinitely heavy, so a struck arm rocks the torso instead of the torso
silently absorbing the reaction. And it buys the licence to lower `coop_ragdollStiff`, which is
what the grenade complaint actually needs. Ranked by what the user will see:
**force → stiffness → self-collision → limits → braces.** The braces come last, and they come
last because they were never in the way.

---

## 5. THE ATOMICITY RULE, RESTATED AND CORRECTED

`ragdoll_r9_spec.md` states it as: *the fold-limit braces `s_ragBraces` rows 6-15 must NOT be
deleted in any build that does not land the limits, and vice versa.* That rule is **too strict
in one direction and not strict enough in the other.** Both corrections are measured.

**Too strict — rows 6-15 are safe to delete today, on the settle branch.** Every one of the ten
is push-apart-only, and `RagShapeMatch` at `alpha ≥ 0.10` already enforces the entire captured
configuration, which implies every one of their minimum distances. Measured: deleting rows 6-15
changes blast deform by 0.0 u and wrist travel by 0.0 u. The caveat is precise:

> Rows 6-15 may be deleted without limits **only while `coop_ragdollMode 1` and
> `coop_ragdollStiff ≥ 0.10`.** On the free branch (`coop_ragdollMode 3`, no shape-match at
> all) they are the only fold constraint that exists, and the same deletion in that mode is a
> regression waiting to be found by whoever next presses F10.

Because deleting them changes nothing visible, shipping that deletion as its own experiment
teaches nothing. Better: land it in the same build as the limits, as cleanup — and confirm the
prediction first with `coop_ragdollTruss 0`, which costs no build at all.

**Not strict enough — four braces are load-bearing and two are permanent.**

| brace | may ship without limits? | why |
|---|---|---|
| rows 6-15 (10 fold braces) | **yes**, mode 1 + stiff ≥ 0.10 only | subsumed by the shape-match; zero measured effect |
| `{5,13}`, `{8,11}` | **NO** | each removes exactly 1 DOF at a generic pose; without J1/J2/J3 the torso gains free twist and bend |
| `{0,2}` | **NO** | removes 1 DOF — the spine1 fold. Needs J1 + J2 in the same build |
| `{3,1}` | **NO, and stricter than the design allows** | removes 1 DOF — the spine2 fold. Superseded by **J26/J27, which are not in the 21-limit table.** Landing the 21 limits and deleting `{3,1}` opens a free 2-DOF hinge at the chest |
| `{5,8}`, `{11,13}` | **never delete, in any build** | they are the rigid triangles the frames `T0`/`T2` are derived from. Delete them and every limit is measured in a frame that no longer exists |

And the converse, which the original rule does not state at all: **the limits must not land
while those four braces are still in.** `6 equality braces + 27 limits + self-collision` has no
feasible configuration (§2.3) and a rank deficit of 4. "Keep the truss as a safety net while we
try the limits" is the one combination that is guaranteed to misbehave.

**One-line rule for the next session:** *nothing above row 6 leaves without the limits; nothing
above row 6 STAYS once the limits land; rows 0 and 1 never leave; and the limits do not leave
without J1b, J1c, J24, J25, J26 and J27.*

---

## 6. LANDING ORDER, ACCEPTANCE, ROLLBACK

Each step is separately visible and separately revertable from the console. One build per
session, as always.

| build | change | live-observable acceptance test | rollback |
|---|---|---|---|
| **T1** | **Raise the `iLarge 0` bullet floor 90 → 150** (and re-scale the rest of the `r9_impact` §4.4 table by ×1.67) + the limp exemption at `:1053`. Nothing else. The asymmetric distal split is already in; this is the second half of the same fix. | Kill a soldier, let him settle, then put one rifle round through a forearm from the side. Target ≈ **10.6°**, ~2.5 u at the wrist — a swing you can see, then a settle over ~0.6 s. Repeat on an arm lying flat on the ground: that is the case the resting-contact kill governs. | revert two constants; the limp clause is one `&&` |
| **T2** | **No build.** `coop_ragdollTruss 0` from the console already runs this experiment. | 10 kills at `1`, 10 at `0`. The prediction is **no visible difference at all** and `span=` / `drift=` / `stretch=` distributions inside noise. If that holds, the truss deletion in T3 carries no risk; if the body visibly degrades at `0`, stop and re-open §1 before touching the braces. | `coop_ragdollTruss 1` |
| **T3** | **The limits build.** 17 points (feet), rigid-triangle `T0`/`T2`, **27** limits behind `coop_ragdollLimits 1`, delete `{5,13}`,`{8,11}`,`{3,1}`,`{0,2}`, `RAG_ITERS` 6 → 4. `coop_ragdollStiff` stays **0.25**. | Gate 0: `coop_ragdollTest 2` freeze drill must render a pixel-perfect soldier on **both** `coop_ragdollMode 1` and `3`. Then 40 kills on m3l3: zero `blowup` lines, `stretch=` ≤ 1.10, no knee or elbow bending backwards in any screenshot, `rot=`/`spin=` distributions unchanged from r10 (the spin fix must not regress). | **`coop_ragdollLimits 0`** — one console line, restores the un-limited body; the deleted braces stay deleted but T2 already proved that is safe at stiff 0.25 |
| **T4** | **Sweep `coop_ragdollStiff` only.** No code change. | F11 (0.10) after 10 kills at 0.25, then 0.05 from the console. Watch a grenade at each step: `deform/translate` should read as visible limb flail by 0.10. Log splits cleanly on the `alpha=` field already printed at `:1752`. | `coop_ragdollStiff 0.25` |
| **T5** | Self-collision pairs (`ragdoll_joints_design.md` §7) behind `coop_ragdollSelfCol 1`. **Not optional** — §2.3 shows it is what raises the minimum legal span from 31.5 u to 43.2 u, i.e. what actually puts the pile out of geometric reach. Ship it before, or with, any `coop_ragdollStiff` below 0.10. | Arms come to rest *on* the legs and torso rather than inside them; forearms stop crossing the ribcage on a grenade. | `coop_ragdollSelfCol 0` |

**T3 must not also change `coop_ragdollStiff`.** That is the r10 lesson in one sentence: a build
that changes both the constraint set and the parameter that dominates the metric cannot be read.

**No new cgame import is needed anywhere in this plan.** Everything is arithmetic on `s->pt[]`.
Verified against `cg_public.h`: `Cvar_Get:122`, `Printf:103`, `CM_PointContents:173`,
`CM_BoxTrace:177`, `CM_TransformedBoxTrace:187`, `Tag_NumForName:406`, `Tag_NameForNum:407`,
`ForceUpdatePose:408`, `TIKI_Orientation:409`, `R_SetRagdollPose:453`, `R_ClearRagdoll:454`.
**`cgame.dll` alone; no renderer change.** `renderergl1/tr_ragdoll.cpp` and the gl2 copy are
still byte-identical (`diff` clean) and `RE_SetRagdollPose` still `Com_Memcpy`s the raw 3×4 with
no re-orthonormalisation — which is why `RagMat3Ortho` on any reconstructed frame remains
mandatory, not optional.

---

## 7. METHOD, AND WHAT IS HYPOTHESIS

**Harness.** `scratchpad/rag_truss.py` replicates `RagStep` (`:957-1034`) and
`RagCollideWorld` (`:1104-1146`) constant-for-constant and ordering-for-ordering: Verlet with
`RAG_DAMPING 0.98` and the `coop_ragdollVelCap` clamp, 6 iterations of 14 parent links then 16
braces, the limp tick, the `alpha` ramp, the `rag_carry 0.85` `ptPrev` carry, and a flat-floor
version of the swept-box collide including the capture-time radius clamp (`:716-733`).
`rag_blast.py` adds the explosion path (`:1481-1533`) with its quadratic falloff and per-point
variation. `rag_dof.py` does the Jacobian rank work. `rag_minspan.py` does the constrained
minimisation, and rejects any solution with an equality residual > 0.02 u or an inequality
violation > 1e-3.

**Reference skeleton.** Derived, not copied: a 94 u figure (the living bbox is
`{-15,-15,0}..{15,15,94}`) with standard segment fractions — upper arm 17.5 u, forearm 13.7 u,
thigh 23.0 u, shin 23.1 u, shoulder line 22.9 u, hip line 18.0 u. Cross-checks: the code's own
comment at `:1495-1496` says "hips are ~18u apart and his shoulders ~24u"; the r9 session log's
sleep spans run 50-74 u on the long axis, consistent with a body of this size lying down.

> ⚠ **The brief's "~46 u of shin per leg" is a TIKI-space number, not world.** 23.1 / 0.52
> (the human tiki `load_scale` that bug-1963 turned up) = 44.4. In the space `pt[]` actually
> lives in — world units — the shin is ~23 u. Nobody should size a collision radius, a brace
> length or a limit off 46.

**Stated plainly as hypothesis, not measurement:**

- The 27-limit ranges in §2.2 for the six new functions are anatomical estimates. They have
  never been run. `r_ragdollDebug 3` printing every capture angle, plus the capture-time range
  widening of `ragdoll_joints_design.md` §5.6, is what turns them into data.
- The pelvis-triangle conditioning number (~0.52) is computed on the reference skeleton. Real
  MOHAA `Bip01 Pelvis`/`Thigh` offsets may be thinner. Measure it at capture before trusting
  the frame.
- The flat-floor collide in the harness reproduces the resting-contact kill and the ~4-substep
  re-arm exactly, but it has no walls, no movers and no self-collision. Numbers about *arms on
  the ground* are solid; numbers about a corpse draped over a crate are not modelled.
- The free-fall span comparison in §2.3 is a 3-seed sample per configuration. It is enough to
  show the truss's span effect is inside seed noise; it is not enough to rank configurations.

**Corrections this document makes to earlier records, so a grep does not return the superseded
version:**

1. `cg_ragdoll.c:135-136` calls `{0,12}`/`{0,14}` the "knee fold limit". They are hip
   constraints; `pt[12]` *is* the knee.
2. `cg_ragdoll.c:137` calls `{1,11}` "geometrically inert". It is not — it is the only thing
   bounding the lumbar segment direction, which is a blind DOF.
3. `ragdoll_r9_spec.md`'s atomicity rule is wrong about rows 6-15 (safe today on the settle
   branch) and silent about `{3,1}`, which needs limits the 21-table does not contain.
4. `ragdoll_joints_design.md` §5.5's "keep exactly the six equality rows" is two rows too
   generous: `{5,13}`, `{8,11}`, `{3,1}` and `{0,2}` are all superseded, and only `{5,8}` and
   `{11,13}` are permanent.
5. The 21-limit table is complete for *bone frames* but six short for *point-cloud DOF*, because
   both anatomical triads are defined by the very segment they would have to measure.
