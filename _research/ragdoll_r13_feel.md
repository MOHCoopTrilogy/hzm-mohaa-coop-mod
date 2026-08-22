# Ragdoll R13 - FEEL: what a living hit reaction should look like

**Lens:** the target. References, numbers, and failure modes, so the build has something to hit
rather than a vibe.

**Ask, from the user, after ten rounds of corpse work:** *"if their bodies would react similarly to
shots too that would be great"* - living soldiers should visibly react when shot, the way the
corpses now do.

**Scope of this document.** It does not specify an implementation. It specifies (a) what shipping
games actually do and what they cost, (b) the numeric target - degrees, milliseconds, units of
screen travel - a developer can build to, (c) the ways this looks bad ranked by how likely each is
in *our* architecture specifically, with a code anchor for each, (d) an acceptance paragraph precise
enough to judge a single build against.

**Proven vs inferred.** Everything under "MEASURED" was extracted this session from the shipped game
data or read out of this repo's source, and the extraction method is in Appendix A so it can be
re-run. Everything under "DERIVED" is arithmetic from published anthropometric and ballistic
constants, shown in full. Everything under "TARGET" is a recommendation - a judgement, argued, not a
measurement.

---

## 0. The one-paragraph version

MOHAA already has an authored hit-reaction layer and this mod already drives it. It is a
**whole-body, ~1.2-second, once-per-1.2-seconds, 55%-of-the-time gesture that does not actually
know which limb you hit** - measured below: all twelve weapon groups map `*_stand_hit_larm` to a
torso or head clip, and one maps it to a *crouch* clip on a standing man. So roughly three out of
four rounds a player puts into a German produce no visible response, and the fourth produces a
response about the wrong limb. The gap a procedural layer fills is therefore **specificity and
immediacy, not amplitude**. The target is a short, small, *correctly-placed* deflection - 15-20
degrees at the struck bone, 6-9 units of limb-tip travel, up in 90 ms and gone in 340 ms - riding on
top of an animation that never stops, never held, never repeated faster than 120 ms, and never
applied to a weight-bearing leg or to a client entity. That is roughly **one third of the corpse
system's measured 60.5-degree swing** and roughly **five times the physically correct deflection**,
and both of those ratios are defended below.

---

## 1. How shipping games do procedural hit reactions

Five lineages, in the order they appeared. For each: what is physically simulated, what stays
animation, how long the blend lasts, how the return is hidden.

### 1.1 Authored overlay pain - the lineage MOHAA belongs to (1998-2005)

The pre-physics answer: author a library of hit animations indexed by **type x direction x region**
and play the closest match, either as an *overlay* on the current state or as a *replacement* for
it. Halo 2's model_animation_graph is the cleanest documented example and its taxonomy is worth
copying wholesale:

| Halo 2 damage type | kind | what it is |
|---|---|---|
| `soft_ping` | **overlay (jmo)** | impact from *light* damage - added on top of whatever he is doing |
| `hard_ping` | **state (jma)** | impact from *heavy* damage - usually a stagger or side-step, replaces what he is doing |
| `soft_kill` / `hard_kill` | state (jma) | death, light / heavy |

Four directions (front/left/right/back) x eleven regions (gut, chest, head, l-arm, l-hand, l-leg,
l-foot, r-arm, r-hand, r-leg, r-foot) x four types = "176 damage animations per character" if you
authored every permutation, which nobody does - so the engine walks an explicit **inheritance
table**: missing `[h_ping, back, r-shoulder]` falls back through directions first, then through
regions (`r-hand` -> `r-arm` -> `chest` -> `gut` -> `head`).
([Microsoft Learn, Halo 2 Animation - Damage Animations](https://learn.microsoft.com/en-us/halo-master-chief-collection/h2/art/animation/animationdamageanims))

**Two things to steal from this.**

1. **The light/heavy split is a kind split, not a magnitude split.** Light damage is an *overlay*
   that leaves the actor's state intact; heavy damage is a *state change*. Our design maps onto this
   exactly: the procedural limb deflection is the `soft_ping`, and the mod's existing
   `setmotionanim` flinch (`hzm-mohaa-coop-mod/coop_mod/aihandler.scr:1848`) is the `hard_ping`.
   They must never both own the same event.
2. **Falling back by region is a *documented, deliberate lie*.** Bungie shipped a table that says
   "when you have no left-arm animation, play the chest one." MOHAA shipped the same lie without the
   table - see §2.6. The lie is what a procedural layer is for.

MOHAA's own version of the taxonomy is `minor_pain/` (the `soft_ping` shelf) and `major_pain/` (the
`hard_ping` shelf), visible as literal directory names in `main/Pak0.pk3` under
`models/human/animation/weapon_*/`.

### 1.2 Powered / animation-driven ragdoll (Havok Behavior, ~2005 onward)

The first widely-shipped physics answer. A ragdoll skeleton is built alongside the animation
skeleton and is *driven toward* the animated pose by joint motors, rather than falling freely. The
tool exposes it as the "Rigid Body Ragdoll Controls Modifier", plus a runtime **ragdoll mapping**
between the simplified physical body and the full animation skeleton. The output pose is a blend
between "what the animation says" and "what the physics says", with the blend factor driven by
impact magnitude.

The characteristic behaviour, and the reason this lineage matters to us: *"you can take a hit, then
go a little bit to ragdoll and then recover, and never go to the ground."*
([Havok interview, Game Developer](https://www.gamedeveloper.com/business/havok-your-way-an-interview-with-havok-s-jeff-yates);
[AnimMotion, combining physical animation with keyframe animation](http://peyman-mass.blogspot.com/2015/05/combining-physical-animation-with.html))

- **Simulated:** the whole ragdoll, always, but with motors pulling it to the animation.
- **Animation:** everything, always - it is the motor target, not a competing pose.
- **Blend:** magnitude-driven, per-impact.
- **Return hidden by:** the motors themselves. There is no discrete "return" - the physics is always
  converging on the animation, so the blend can go to zero without a discontinuity.

That last property is the single most important idea in this document. **A system where the physics
target is the animation has no snap-back problem, because there is nothing to snap back to.** Our
corpse system does not have this property (its shape-match target is a frozen death pose); a living
system must.

### 1.3 Euphoria / Dynamic Motion Synthesis (Max Payne 3, GTA IV/V, RDR)

The most-praised end of the spectrum, and the one the user has probably seen. NaturalMotion's
Euphoria simulates a body with bones, muscles and a simplified motor-nervous system, and synthesizes
the response at runtime from behaviour sets rather than playing clips. Rockstar's stated goal on Max
Payne 3 was that *individual shots* react properly rather than the body playing one canned response,
and Rockstar explicitly **mixed canned animation with the simulation** rather than going fully
dynamic, to keep the game responsive.
([MCV/Develop, Max Payne 3 dev explains Euphoria tweaks](https://mcvuk.com/development-news/max-payne-3-dev-explains-euphoria-engine-tweaks/);
[Euphoria - Wikipedia](https://en.wikipedia.org/wiki/Euphoria_(software)))

- **Simulated:** effectively everything, with active balance and protective behaviours.
- **Animation:** blended in for weight and gameplay-critical moments.
- **Blend:** continuous, behaviour-driven.
- **Return hidden by:** active balance - the character *recovers* on his own rather than being faded
  back.

**Why we are not doing this and should not pretend to.** Euphoria's readability comes from active
balance and protective behaviour (stepping to catch himself, putting a hand out, clutching the
wound), not from limb deflection. Limb deflection alone, scaled up to Euphoria-looking amplitude,
does not read as Euphoria - it reads as a broken arm. This is the trap in "make it dramatic."

### 1.4 UE4/UE5 PhysicalAnimationComponent - the "blend physics on a bone below a threshold" pattern

The pattern most people will actually recognise, because it is a five-node Blueprint. Get the bone
that was hit, then:

- `Set All Bodies Below Simulate Physics` on that bone,
- `Set All Bodies Below Physics Blend Weight` - "at 1.0 the given bone and all those below it are
  completely driven by physics; at 0.0 the mesh has returned to its original keyframe animation" -
  and drive that value **every tick** so it animates smoothly,
- optionally apply a `PhysicalAnimationComponent` profile so the simulated bodies are *driven* toward
  the animation rather than falling.

([Physics Driven Animation in Unreal Engine](https://dev.epicgames.com/documentation/unreal-engine/physics-driven-animation-in-unreal-engine);
[Set All Bodies Below Physics Blend Weight](https://dev.epicgames.com/documentation/unreal-engine/BlueprintAPI/Physics/SetAllBodiesBelowPhysicsBlendWei-?lang=en-US))

The standard physical-animation profile values quoted in practice are **Orientation Strength 1000,
Angular Velocity Strength 100, Position Strength 1000, Velocity Strength 100**, and the standard
warning is not to raise the strength modifier too far or the character behaves like "an
uncontrollable octopus."
([Coppens, *Reactive Melee Combat in Unreal Engine 4*](https://assets.ctfassets.net/y4twieuxp19i/5WBm8ecHVC2EIQEGS26mMS/3435e9e01ffd7e57091597d67f7af7ca/ReactiveMeleeCombat.pdf))

The recommended shape of the reaction, from the same source, is worth quoting because it is exactly
our shape: *blend "from 100% animation to 100% physics back to 100% animation over a certain period",
driven by "a curve somewhat like a sinusoid", with the period varying by how hard the character was
hit.*

- **Simulated:** the sub-tree below the struck bone, and only while the blend weight is non-zero.
- **Animation:** the rest of the body, all the time; and the struck sub-tree again as soon as the
  weight returns to 0.
- **Blend:** commonly 0 -> 1 -> 0 over 0.2-0.5 s for a hit reaction.
- **Return hidden by:** interpolating the weight back rather than snapping it, and by the physical
  animation drive pulling the simulated bodies at the animation the whole time.

**The sub-tree rule is the important one.** "All bodies *below* the struck bone" means a forearm hit
moves forearm + hand and *nothing above the elbow*. That is a hard structural guarantee that the
torso cannot be dragged into a limb reaction, and it costs nothing to adopt.

### 1.5 Unity partial ragdoll blending

Same idea, hand-rolled: enable simulation on some bones and leave others keyframed, then in
`LateUpdate` lerp each blended bone between its ragdolled transform and its animated transform.
Community practice for the ramp is **0 -> 1 over about 0.2 s**, with `Vector3.Lerp` on positions and
`Quaternion.Slerp` on rotations. Active-ragdoll variants instead tween the *joint drive strength*
down and back: *"tween the angular drive strength from its normal value to 0 over 0.15-0.25 seconds
for a smooth transition"*, so the limb yields, then the drives pull it home.
([Unity - blending ragdoll physics with animation](https://discussions.unity.com/t/how-to-blend-ragdoll-physics-with-animation/734320);
[RagdollHelper.cs](https://github.com/nbzeman/Ragdoll/blob/master/Assets/Scripts/RagdollHelper.cs);
[Jettelly, self-balancing active ragdoll](https://jettelly.com/blog/self-balancing-active-ragdoll-in-unity-breakdown-of-an-upcoming-tool))

- **Blend:** 0.15-0.25 s in, comparable out.
- **Return hidden by:** the drives, again.

### 1.6 Inertialization (Gears of War 4, GDC 2018) - the correct way to *end* a reaction

The most directly applicable single technique in this whole document, and it is not a physics
technique at all.

David Bollo's Gears of War 4 talk replaces cross-fade blending with a **post-process**: instead of
evaluating two poses and mixing them, you capture the difference between the old pose and the new
one at the moment of transition and then **decay that difference to zero** using a curve that
matches position *and* velocity at the start and reaches zero with **zero jerk** at the end. The
curve is a **quintic (fifth-order) polynomial** (the talk cites Flash and Hogan 1985), the
transition duration is *the only tunable parameter*, and the talk explicitly adds two guards:
**limit overshoot by controlling the initial acceleration**, and **clamp the transition time**.
([Bollo, *Inertialization: High-Performance Animation Transitions in Gears of War*, GDC 2018 - slides PDF](https://media.gdcvault.com/gdc2018/presentations/bollo_david_inertialization_high_performance.pdf);
[GDC Vault](https://www.gdcvault.com/play/1025165/Inertialization-High-Performance-Animation-Transitions))

General practice for the duration parameter is short: **keep it under 0.4 s.**

**Why this matters more than anything else here.** A procedural hit reaction *is* an inertialization
problem wearing a physics costume. You do not need a solver to make a limb move and come back. You
need:

1. an offset (a rotation delta on one or two channels),
2. a magnitude for it,
3. a decay curve that reaches zero with zero velocity *and* zero acceleration,
4. a duration under 0.4 s.

Everything else - mass points, constraints, collision, gravity - buys you nothing on a living actor
who is being re-posed by an animation every frame, and costs you every failure mode in §3.

### 1.7 Summary of the lineage

| approach | physically simulated | stays animation | blend duration | how the return is hidden |
|---|---|---|---|---|
| Halo-2 style overlay pain | nothing | everything | authored clip length | it *is* animation; the state machine cross-fades |
| Havok powered ragdoll | whole ragdoll, motor-driven | the motor target | magnitude-driven, continuous | motors converge on the animation; no discrete return |
| Euphoria / DMS | whole body + motor control | blended for weight and gameplay beats | continuous | active balance: the character recovers himself |
| UE PhysicalAnimation | sub-tree below the struck bone | everything above it, plus the drive target | 0.2-0.5 s, 0 -> 1 -> 0 | interpolate the weight back; drives pull home |
| Unity partial ragdoll | selected bones | the rest | 0.15-0.25 s each way | per-bone Lerp/Slerp back to the animated transform |
| Inertialization | nothing | everything | **< 0.4 s** | quintic decay of the *offset*, zero jerk at the end |
| **recommended for us** | **nothing** | **everything** | **260-340 ms** | **quintic decay of a per-channel rotation offset** |

---

## 2. The numbers

### 2.1 Units, and what a "visible" motion actually costs

- **1 MOHAA unit ~ 1 inch = 0.0254 m** (project coordinate reference).
- **MEASURED skeleton scale**, from prior sessions in this repo: forearm ~ 11 u, upper arm ~ 12 u
  (`_research/ragdoll_r12_grounded.md:449`); the forearm+hand reach used for swing arithmetic is
  14 u (`_research/ragdoll_r12_spec.md:42`). Shoulder-to-hand is therefore ~ 23-26 u. An actor is
  ~ 72 u tall.
- **Screen size.** For a small feature of size *s* at distance *d*, pixels ~ `k * s / d`, with
  `k = (W/2) / tan(hfov/2)`. At 1920 wide and `cg_fov 80`: `k = 960 / 0.8391 = 1144`.

| range *d* (u) | actor height on screen | pixels per unit | units needed for a 6 px motion |
|---:|---:|---:|---:|
| 200 | 412 px | 5.72 | 1.05 |
| 400 | 206 px | 2.86 | 2.10 |
| 800 | 103 px | 1.43 | 4.20 |
| 1200 | 69 px | 0.95 | 6.30 |
| 1600 | 51 px | 0.72 | 8.40 |
| 2400 | 34 px | 0.48 | 12.6 |

Take **6 px of peak displacement** as the floor for "a motion the player reliably notices on a
target he is already tracking, inside a 200-400 ms window". (This is a working threshold, not a
citation - it is roughly the point at which a moving element subtends more than a couple of
foveal receptive fields at typical viewing distance. It is deliberately conservative; smaller
motions are *sometimes* noticed, but "sometimes" is not a build target.)

**Consequence: a 6-9 u limb-tip travel is readable everywhere out to ~1200-1500 u, and nothing is
readable past ~2000 u regardless of amplitude, because the whole man is 34 px tall.** The distance
cull is therefore a *feature*, not a compromise, and it is also the entire performance answer.

### 2.2 DERIVED: what a real bullet actually does to a real forearm

Worth doing once, because the answer decides §4.

**Ballistics** (nominal WW2 service loads):

| round | mass | muzzle velocity | momentum *p* | energy |
|---|---:|---:|---:|---:|
| 7.92x57 Mauser sS (Kar98, MP44, MG42) | 12.8 g | 760 m/s | 9.73 kg m/s | 3697 J |
| .30-06 M2 ball (Garand, BAR, 30cal) | 9.7 g | 838 m/s | 8.13 kg m/s | 3407 J |
| .303 Mk VII (Enfield, Vickers) | 11.3 g | 744 m/s | 8.41 kg m/s | 3128 J |
| 9x19 Parabellum (MP40, Sten) | 8.0 g | 390 m/s | 3.12 kg m/s | 608 J |
| .45 ACP (Thompson) | 15.0 g | 280 m/s | 4.20 kg m/s | 588 J |

Rifle-to-pistol momentum ratio: **2.3-3.1x**. (Note for §2.5: the engine's existing `iLarge` force
scaling is 220/150 = **1.47x**, i.e. *more conservative than physics*. That is the right direction
for readability and should not be "corrected".)

**Segment inertia** (Winter, *Biomechanics and Motor Control of Human Movement*, standard
anthropometric table - forearm 0.016 M, hand 0.006 M, radius of gyration about the proximal end
0.468 of segment length;
[Winter table reproduction](https://www1.udel.edu/biology/rosewc/kaap686/notes/anthropometry.html)):

For a 75 kg soldier, forearm + hand:
- mass `m = 0.022 * 75 = 1.65 kg`
- length elbow-to-fingertip `L = 0.44 m`
- radius of gyration about the elbow `k = 0.468 * 0.44 = 0.206 m`
- `I = m k^2 = 1.65 * 0.206^2 = 0.070 kg m^2`

**Momentum actually transferred.** A rifle FMJ passing through ~10 cm of limb exits with most of its
velocity; transferred momentum is on the order of **5-10%** of *p*, so 0.5-1.0 kg m/s. (A pistol
round that *stops* in the limb transfers 100% of a much smaller *p* - 3.1 kg m/s - which is why the
naive "rifles hit harder" intuition is not straightforwardly true at the limb level. Games do not
model this and should not.)

**Angular response.** Impulse `J = 0.6 kg m/s` applied `r = 0.15 m` from the elbow:
- angular impulse `= 0.09 kg m^2/s`, so `w0 = 0.09 / 0.070 = 1.29 rad/s = 74 deg/s`
- a co-contracted elbow is roughly `K ~ 10 N m/rad`, `C ~ 0.6 N m s/rad`, giving
  `wn = sqrt(K/I) = 12 rad/s (1.9 Hz)` and `zeta = C / (2 sqrt(K I)) = 0.36` - underdamped
- peak deflection `~ (w0/wn) * exp(-zeta*phi/sqrt(1-zeta^2)) = 0.107 * 0.55 = 0.059 rad = **3.4 deg**`
- time to peak `= (1/wd) * atan(sqrt(1-zeta^2)/zeta) = 1.20 / 11.2 = **107 ms**`
- 5% settling `= 3 / (zeta * wn) = **0.69 s**`

**DERIVED RESULT: a real rifle round through a real forearm bends the elbow about 3-6 degrees,
peaking at ~100 ms, settling in ~0.6 s.** At 14 u that is `14 * sin(4 deg) = 0.98 u` of hand travel -
**1.4 px at 400 u range. Physically correct is invisible.**

This is the load-bearing fact of the whole document. It means the number to hit is a *readability*
number, and any argument that begins "but realistically..." is settled: realism here produces
nothing on screen. The only remaining question is *how much* exaggeration, and §4 answers it.

Two of the derived timings survive into the target anyway, and should:

- **time to peak ~100 ms** - the real one. Keep it. A reaction that peaks much faster reads as a
  teleport; much slower reads as a shove.
- **damping ratio ~0.35, i.e. slightly underdamped** - a real limb overshoots once and comes back.
  A single small overshoot on the return is *correct* and is worth having, but Bollo's rule applies:
  bound it by controlling the initial acceleration, do not let it ring.

### 2.3 MEASURED: what our corpse system does today, as the upper bound

From `openmohaa-hzm/code/cgame/cg_ragdoll.c` and the live logs:

| quantity | value | anchor |
|---|---|---|
| struck-forearm swing, live, with the fixed direction | **60.5 deg** | user brief; instrument at `cg_ragdoll.c:1866-1886` |
| same, before the `weaputils.cpp` direction fix | 2.34 deg | `fgame/weaputils.cpp:2633` comment |
| same, on a body never shot at | 0.05 deg | ditto |
| corpse hand travel implied at 14 u | `14 * sin(60.5) = 12.2 u` | derived |
| corpse limp window | `RAG_IMPACT_LIMP_MS 600` ms, wire value `600 + 70*iLarge` | `cg_ragdoll.c:70`, `cg_parsemsg.cpp:1809` |
| pose pull retained at impact | `RAG_IMPACT_RELAX 0.05` (5%) | `cg_ragdoll.c:69` |
| observed corpse targets, rifle into a forearm | 12-20 u of travel over 250-450 ms | `_research/ragdoll_r12_grounded.md:455` |

So the corpse target is **12-20 u / 250-450 ms / ~60 deg**. A living man must be visibly *less* than
that, and §4 argues for about a third.

### 2.4 TARGET: the implementable table

Two instruments, both defined so they can be printed and compared to these numbers directly:

- **`swing`** - the angle between the struck bone's drive segment now and its direction at the
  instant of impact. *Identical definition to the corpse instrument* at `cg_ragdoll.c:1866-1886`, so
  the two systems are directly comparable.
- **`tip`** - peak world displacement, in units, of the distal end of the affected chain (for an arm
  hit, `Bip01 * Hand`), measured against where the animation alone would have put it.

| hit | swing (deg) | tip (u) | attack (ms) | release (ms) | total (ms) |
|---|---:|---:|---:|---:|---:|
| support arm (L: forearm / upper arm), rifle-calibre | **15-20** | **6-9** | 90 | 250 | **340** |
| support arm (L), pistol-calibre | **8-12** | **3.5-5.5** | 70 | 190 | **260** |
| gun arm (R), rifle-calibre, **while firing** | **6-8** | 2.5-3.5 | 90 | 220 | 310 |
| gun arm (R), rifle-calibre, not firing | 15-20 | 6-9 | 90 | 250 | 340 |
| shoulder / upper arm (either side) | 8-12 | 5-8 | 90 | 250 | 340 |
| torso / back (Spine2 only) | **3-5** | 2-4 | 100 | 260 | 360 |
| head / neck | **6-10** | 2-4 | 60 | 160 | **220** |
| leg / thigh / calf | **0 in v1** | 0 | - | - | - |
| pelvis | **0, always** | 0 | - | - | - |

Global rules that go with the table:

| rule | value | why |
|---|---|---|
| **decay curve** | quintic, zero velocity **and** zero acceleration at t1 | Bollo; anything else is the rubber arm (§3.3) |
| **hold at peak** | **0 ms** | a hold is what makes a living man look dead (§3.6) |
| **hard ceiling on total** | **400 ms** | under the 1.05 s median authored `minor_pain` clip (§2.6) and under the 1.2 s script throttle |
| **torso share of a limb hit** | <= 3 deg at Spine2, 0 at pelvis | the corpse system needed a quadratic falloff for exactly this reason (`cg_ragdoll.c:1690`, "when I shoot one leg they both move") |
| **sub-tree rule** | affect the struck bone and its descendants only | UE's `Set All Bodies Below`; makes "the torso got dragged in" structurally impossible |
| **re-trigger floor** | 120 ms | MG42 at 1200 rpm is one message every 50 ms (§3.5) |
| **saturation** | peak offset clamps at 1.4x the single-hit value | corpse precedent: `vmax = force * 1.6f`, `cg_ragdoll.c:1655` |
| **overshoot** | <= 1 undershoot cycle, amplitude <= 15% of peak | real elbow zeta ~ 0.35 (§2.2); Bollo bounds it via initial acceleration |
| **distance cull** | 1200 u (pistol-calibre) / 1500 u (rifle) | §2.1: past that a 9 u motion is under 6 px |
| **entity gate** | `entnum >= cgs.maxclients` only | `cg_view.c:789` places the local player's camera from the `eyes bone` tag (§3.9) |
| **stance gate** | skip prone; skip any actor whose current motion anim started < 120 ms ago | matches `aihandler.scr:1866` (`self.position == "prone"` -> end) |

### 2.5 Weapon scaling: the field is already on the wire

**MEASURED.** The flesh-hit message already carries a weapon-power field and nothing has to be added
to the protocol.

- Server: `fgame/weaputils.cpp:2646` writes `gi.MSG_WriteBits(bulletlarge, bulletbits)` on
  `CGM_BULLET_8`; `bulletbits = 2` on Breakthrough protocol, 1 on legacy (`weaputils.cpp:2357`).
- Client: `cgame/cg_parsemsg.cpp:1778` reads `iLarge = cgi.MSG_ReadBits(2)`.
- `bulletlarge` defaults to **0** (`fgame/weapon.cpp:1102`) and is declared per weapon TIKI.

Scanning every `.tik` in `main/` and `maintt/` for a `bulletlarge` line (Appendix A, method 3):

| `bulletlarge` | count | which weapons |
|---:|---:|---|
| **0** (never declared) | all the rest | MP40, Thompson, Sten, MP18, Luger, Colt, Webley - i.e. **every pistol-calibre weapon** |
| **1** | **241 tiks** | Kar98 (+sniper, +mortar), Garand, Springfield, Enfield, Mosin, Carcano, Moschetto, SVT, G43, FG42, Johnson M1941, MP44, BAR, DP28, Breda, MG42, Maxim, Vickers, 30cal, L42A1 - i.e. **every rifle-calibre weapon and every LMG/MMG** |
| **2** | 1 tik | `p_aagun_cannon.tik` |

So `iLarge` is, in the shipped data, **exactly a rifle-calibre-versus-pistol-calibre bit**. That is
the only weapon-power axis worth expressing, and it is free.

Mapping to the table in §2.4:

| `iLarge` | class | swing target (support arm) | total |
|---:|---|---:|---:|
| 0 | pistol-calibre | 8-12 deg | 260 ms |
| 1 | rifle-calibre / LMG | 15-20 deg | 340 ms |
| 2 | AA cannon | **do not express procedurally** - hand off to the authored `major_pain` / death path | - |

**Two producers of this message, and the second one is a trap.** `CGM_BULLET_8` is also sent by
`Actor::EventDamagePuff` (`fgame/actor.cpp:6040-6046`) with `iLarge` hard-wired to 0 and a
script-supplied direction. The only vanilla callers are `anim/killed.scr:51` and
`anim/dog_killed.scr:12` - i.e. **at the moment of death**. A living-reaction path that does not
distinguish them will fire a flinch on the exact frame a man dies, one snapshot before the client
sees `EF_DEAD`, and that flinch will ride into the death animation. Named again as §3.10.

### 2.6 MEASURED: what MOHAA's own authored layer actually does

This is the finding that decides §4, so it is stated in full.

**Method** (Appendix A, methods 1-2): read the SKC headers (`skcHeader_t`, `numFrames` at +44,
`frameTime` at +16 - `openmohaa-hzm/code/tools/md5_2_skX/skx_format.h:172`) of every
`minor_pain/` and `major_pain/` clip in `main/Pak*.pk3`, then parse every `human_*.tik` for the
`*_hit_*` alias lines and resolve each alias to the SKC it actually plays.

**Result 1 - durations.**

| shelf | n | min | median | mean | max |
|---|---:|---:|---:|---:|---:|
| `minor_pain/` clips (the flinch shelf) | 78 | 0.300 s | **1.050 s** | 1.137 s | 2.700 s |
| `major_pain/` clips | 90 | 0.300 s | 1.575 s | 1.774 s | 3.600 s |
| **`*_hit_*` aliases as actually wired in `human_*.tik`** | **158** | 0.300 s | **1.225 s** | 1.240 s | 2.700 s |

Only **3 of the 158** wired aliases are 0.4 s or shorter. The authored flinch is a **1.2-second
whole-body gesture**, not a hit reaction in the modern sense.

**Result 2 - the aliases lie about which limb was hit.** Every one of the twelve weapon groups maps
its left-arm flinch to a torso or head clip. There is no left-arm animation in MOHAA at all:

| alias the mod asks for | SKC actually played | duration | what the player sees |
|---|---|---:|---|
| `rifle_stand_hit_larm` | `rifle_stand_hit_torso.skc` | 1.080 s | a torso hunch |
| `thompson_stand_hit_larm` | `rifle_stand_hit_torso.skc` | 1.080 s | a torso hunch |
| `bar_stand_hit_larm` | `rifle_stand_hit_torso.skc` | 1.080 s | a torso hunch |
| `mp40_stand_hit_larm` | `mp40_stand_hit_head.skc` | **1.700 s** | a **head** snap |
| `pistol_stand_hit_larm` | `pistol_stand_hit_head.skc` | **2.000 s** | a **head** snap |
| `mp44_stand_hit_larm` | `mp44_crouch_hit_front.skc` | 1.400 s | a **crouch** clip on a standing man |
| `grenade_stand_hit_larm` | `grenade_stand_hit_head.skc` | 1.700 s | a head snap |
| `unarmed_stand_hit_larm` | `grenade_stand_hit_head.skc` | 1.700 s | a head snap |
| `rifle_crouch_hit_larm` | `rifle_crouch_hit_torso.skc` | 0.960 s | a torso hunch |

The right-arm side is better but still coarse: `rifle_stand_hit_rarm` ->
`rifle_stand_hit_Rshoulder.skc` (0.400 s, a *shoulder*, not an arm), while `mp40`/`mp44`/`pistol`/
`grenade` do have genuine `*_stand_hit_rarm.skc` clips (0.650-1.350 s).

**Result 3 - and MOHAA holds the rifle in the right hand.** `tag_weapon_right` is the grip tag
(`cgame/cg_modelanim.c:1628`), so `Bip01 R Hand` is the trigger hand and the left arm is the
support arm on the forestock.

**The convergence, and it is the design's whole thesis:**

> **The limb MOHAA cannot animate a reaction for (the left arm) is exactly the limb it is safest to
> move procedurally (the support arm, which is not aiming the gun).**

**Result 4 - how often the authored layer fires at all.** From
`hzm-mohaa-coop-mod/coop_mod/aihandler.scr:1848-1897`:

- `coop_aiHitReact` default **55** (`coop_defaults.cfg:364`) - a 45% miss on every hit by design,
- per-actor throttle `self.coop_hitReactT = level.time + 1.2` - at most one flinch per **1.2 s**,
- `self.position == "prone"` -> nothing,
- fires `self setmotionanim local.anim` with `self.blendtime = 0.15`, fire-and-forget,
- counted at `aihandler.scr:1892` via `behav_bump "hitreact"`, printed every 30 s as
  `^~^~^ AIBEHAV3 ... hitreact=NN ...` (`coop_mod/aibehav.scr:143`).

A rifleman putting 1-2 rounds/s into a German gets a visible authored response on roughly **one shot
in four**, and that response is about the wrong limb for half the body. **That is the hole the user
is describing.**

---

## 3. What makes it look wrong, ranked by likelihood *in our design*

Ranked by `P(it happens) x P(the player notices)`, with the mechanism, the code anchor, the visible
tell, and the guard.

### 3.1 Wrong-actor / wrong-bone attribution, because the message has no entity number - **VERY HIGH**

**Mechanism.** `CGM_BULLET_8` carries position + direction and *no entity number*
(`fgame/weaputils.cpp:2641-2665`). The corpse path resolves it geometrically: nearest bone segment
within `radius = 15.0f + 1.5f * iLarge` (`cg_parsemsg.cpp:1808`), i.e. 15-19.5 u. That works for
corpses because they are stationary and the client's rendered pose equals the server's pose. **A
living actor is neither.** MOHAA AI run at ~250-300 u/s, and the client renders one snapshot behind:
at `sv_fps 20` that is 50 ms = **12-15 u**, plus the client's own interpolation. So the impact point
can arrive **15-30 u behind the rendered body** - comparable to or larger than the entire search
radius.

**Tell.** Two flavours, both bad and both silent: (a) no reaction at all on exactly the shots the
player is watching land (which reads as "the feature does not work" - the same complaint the corpse
system already generated once: *"eventually it does nothing when you shoot the limbs"*,
`cg_ragdoll.c:1452`), or (b) a *leg* twitch for a shoulder hit, which reads as random.

**Guard.** Do not resolve the hit by absolute world distance to a bone. Resolve the **entity** first
- a generously expanded bounds test against each visible living actor's *lerped* position - and only
then find the nearest bone segment *within that entity*, with no radius rejection. If two candidate
entities overlap, prefer the one whose bounds the point is actually inside; if still tied, prefer
the one facing the impact direction.

**This is the one risk that is genuinely new.** Everything else in this list has a corpse-system
precedent.

### 3.2 The reaction outliving, or fighting, the authored flinch - **HIGH**

**Mechanism.** The mod fires `setmotionanim` with `blendtime 0.15` for a clip of median **1.225 s**
(measured, §2.6) at 55% of hits, throttled to 1.2 s (`aihandler.scr:1862-1895`). If the procedural
decay runs past ~400 ms it is still displacing a bone that the authored clip is now animating from a
completely different pose, and the two disagree about where the arm is for the remaining 800 ms.

**Tell.** The arm "sticks" partway through the flinch, or the flinch looks like it has a hitch in it.
Worse, because it is intermittent (55% x throttle), it looks like a bug rather than a style.

**Guard.** Hard 400 ms ceiling (§2.4). Additionally: when the authored flinch *does* fire, the
procedural layer for that actor should **abort its current offset with a fast decay** rather than
run to completion, on the Halo principle that a `hard_ping` replaces rather than layers.

### 3.3 The rubber arm - **HIGH**

**Mechanism.** A linear or exponential decay of the offset leaves non-zero velocity at t1. The limb
arrives back at the animated pose still moving and visibly *catches*. An ease-out that reaches zero
velocity but not zero *acceleration* is better but still shows a subtle crease.

**Tell.** The single most-recognised failure in the whole category, and the one players describe as
"floaty" or "rubbery" without being able to say why.

**Guard.** Bollo's quintic: match position and velocity at t0, reach zero with **zero jerk** at t1,
clamp the duration, and control the initial acceleration to bound overshoot. It is a five-line
function and the *only* thing this document asks the build to copy verbatim.

### 3.4 Broken aim - the gun swings and the bullets do not - **HIGH**

**Mechanism, and it is specific to our renderer bridge.** Hook B
(`R_RagdollGetOrientation`, `openmohaa-hzm/code/renderergl1/tr_ragdoll.cpp`) serves *tag lookups*
from the override table, and `CG_GetOrigin` (`cgame/cg_ents.c:716`) places any parented entity -
including the actor's attached weapon - by calling `TIKI_Orientation` on the parent. So **the moment
we push an override for a living actor, his rifle rides it**, along with its muzzle flash and any
tag-anchored FX. The server's shot geometry is untouched.

**Numbers.** An 8-degree deviation at the shoulder rotates the muzzle direction by up to 8 degrees.
At 400 u that is `400 * tan(8 deg) = 56 u` of apparent miss - most of a body width. At 5 degrees it
is 35 u.

**Tell.** A German whose rifle is visibly pointed past the player's shoulder while the player takes
damage. This is the failure that makes the feature feel *unfair* rather than merely ugly, which is
worse.

**Guard.** Three-part: (a) cap the **right** (trigger) arm at 6-8 degrees while the actor is firing;
(b) bias the reaction toward the **left** support arm and the shoulder - which §2.6 shows is exactly
where the authored data is missing anyway; (c) if a cheap "is firing" signal is not available, apply
the firing cap unconditionally to the right arm and accept the smaller reaction there.

### 3.5 Reactions firing on every bullet of a burst - **MEDIUM-HIGH**

**Mechanism.** An MG42 at 1200 rpm sends one flesh-hit message every **50 ms**. Even a Thompson at
700 rpm sends one every 86 ms. Without saturation, six to eight impulses land inside a single 400 ms
event.

**Tell.** The arm vibrates. It stops looking like impact and starts looking like a physics bug -
which is exactly how the corpse system failed once already: *"seven rifle hits walked a body 128u
from its own entity and tripped the leash"* (`cg_ragdoll.c:1685`).

**Guard.** The corpse precedent, adapted: clamp the *result* rather than the impulse. Peak offset
saturates at 1.4x the single-hit value regardless of how many arrive; plus a 120 ms re-trigger
floor per actor per limb so that a burst produces roughly three deflections, not eight. Note this
is deliberately *not* the script's 1.2 s throttle - the procedural layer's whole job is to answer the
shots the authored layer cannot.

### 3.6 He looks dead while he is still shooting at you - **MEDIUM**

**Mechanism.** Copying the corpse recipe literally means copying `RAG_IMPACT_RELAX 0.05` -
"a struck limb keeps only 5% of the pose pull at the moment of impact" (`cg_ragdoll.c:69`) - i.e.
the limb goes *limp*. A corpse's limb has no muscle; a living man's never does. A limp arm hangs,
lags behind the body, and swings on its own.

**Tell.** Uncanny in the specific way the user has objected to before. A man running with one arm
trailing reads as wounded-to-the-point-of-uselessness, which contradicts the fact that he is still
returning fire.

**Guard.** The reaction is a **displaced spring, never a released one**. The limb is pulling back
toward the animation from frame 1. Structurally: never reduce the pull-to-animation term; only add
an offset on top of it. This is the Havok "motors converge on the animation" property from §1.2, and
it is why §1.7 recommends "physically simulated: nothing".

### 3.7 Silhouette detachment - the limb leaves the mesh - **MEDIUM**

**Mechanism.** The mesh cannot close at a joint that is bent the wrong way or about the wrong point.
This project has already shipped this exact bug once: the swing was measured on `pt[parent] -> pt[i]`
instead of `pt[i] -> pt[child]`, and *"the mesh literally cannot close at a bent elbow"*
(`cg_ragdoll.c:104-119`, the `s_ragDriveChild` table).

**Tell.** A visible seam or a shoulder that separates from the torso, usually for two or three
frames at the peak - just long enough to register as "broken" without being long enough to diagnose.

**Guard.** Reuse `s_ragDriveChild` unchanged, and keep the angles inside the table in §2.4 - 15-20
degrees does not open a seam on a MOHAA humanoid; 60 does.

### 3.8 Foot skate on a weight-bearing leg - **LOW (only because we exclude legs)**

**Mechanism.** A planted foot that slides, or a knee that bends while it is carrying the body, is
the most-noticed of all animation errors because the ground is a fixed reference the eye can check
against.

**Guard.** Legs are **0 in v1** (§2.4). If they are ever added, the rule is: swing-phase leg only,
and never while `self.position` is prone or crouched. The upside is small - the authored
`*_stand_hit_leg` clips are among the *better* ones (a genuine `*_stand_hit_leg.skc` exists for
every group, 1.000-1.050 s) - so this is the cheapest thing to cut.

### 3.9 Player-entity contamination - **LOW probability, CATASTROPHIC if missed**

**Mechanism.** `cgame/cg_view.c:789` places the local player's camera from the `eyes bone` tag via
`TIKI_Orientation`. Hook B intercepts tag lookups. An override pushed for any client entity therefore
**moves the player's own camera**.

**Guard.** One line: `entnum >= cgs.maxclients` before anything else. Cheap, absolute, and worth
stating explicitly because the corpse path gets it for free (`cg_ragdoll.c:1476`) and a
living-actor path might not.

### 3.10 A flinch that starts on the frame he dies - **LOW-MEDIUM**

**Mechanism.** `Actor::EventDamagePuff` (`fgame/actor.cpp:6040`) sends the *same* `CGM_BULLET_8` from
`anim/killed.scr:51`, i.e. at death. The client may not have seen `EF_DEAD` for that entity yet.

**Tell.** A small arm twitch that starts a beat *after* the death animation begins - reads as a
glitch rather than a reaction, and it is exactly the frame the player is watching.

**Guard.** Suppress the living-reaction path for any entity whose `EF_DEAD` arrived within the last
snapshot, and for any entity with a pending or active ragdoll sim (`RagSimFor(entnum)` non-NULL, or a
pending record). The corpse path already owns that entity.

### 3.11 Cost - **LOW, if the architecture is right**

16+ living actors versus 16 corpse slots today. But the corpse cost is a 15-point Verlet body with 6
constraint iterations, 4 substeps and up to 240 collision traces per frame
(`RAG_TRACE_BUDGET`, `cg_ragdoll.c:65`). A per-limb **angular offset with a scalar decay** is
~40 bytes of state and one 3x3 composition per affected channel - two to three orders of magnitude
cheaper, with no traces, no gravity and no constraint solve. Combined with the distance cull (§2.1),
this should not be measurable.

The risk is not the cost of the right design; it is the temptation to reach for the corpse solver
because it exists.

---

## 4. Subtle or pronounced? The MOHAA-specific argument

The tension is real and the user is on both sides of it: he asked for gore and dramatic deaths, and
he has objected every single time something looked unnatural (piles, sinking, the wrong-limb
question, the "rubber" complaint). Resolving it needs the argument to be about *which axis* is being
turned up.

**The case for subtle.**

1. A living actor is the object the player is *already tracking*. His silhouette is the
   most-attended thing on screen. A change that would be invisible on a corpse lying in a corner is
   plainly visible on a man the player is aiming at. The 60.5-degree corpse number is large partly
   *because a corpse is peripheral*.
2. MOHAA is a 2002 game with a coherent, remembered animation vocabulary. A 40-degree arm swing
   layered on a 2002 run cycle will not read as "modern"; it will read as "the mod is broken".
3. Every failure mode in §3 gets worse monotonically with amplitude. §3.4 (broken aim) and §3.7
   (silhouette detachment) get *dramatically* worse - they are roughly threshold effects around 10
   and 25 degrees respectively.

**The case for pronounced.**

1. §2.2 settles the "realistic" position: real is 3-6 degrees and 1.4 pixels. There is no defensible
   "subtle = accurate" argument available. Subtle, taken literally, means *nothing on screen*.
2. §2.6 settles the "don't fight the authored layer" position: there is nothing coherent to be
   subtle *against*. The retail data does not have a left-arm animation for any weapon group and
   substitutes a head snap or a crouch clip. The authored layer is already telling the wrong story.
3. §2.1 sets a hard floor: below ~2 u of limb-tip travel at 400 u, and below ~4 u at 800 u, the
   reaction does not exist for the player. A "few degrees, barely conscious" design is
   indistinguishable from not shipping.

**Resolution: pronounced in *specificity*, restrained in *amplitude*.**

The thing to turn up is not how far the limb moves. It is:

- **which** limb moves - the one that was actually hit, which the retail data gets wrong for the
  entire left side;
- **when** it moves - on *this* bullet, at ~90 ms, not on one bullet in four;
- **that** it moves at all - on the 45% the `coop_aiHitReact` roll discards and on every shot inside
  the 1.2 s throttle.

Concretely: **target one third of the corpse angle** (15-20 degrees against 60.5) and **about five
times the physical angle** (15-20 against 3-6). Delivered inside 340 ms, on top of an animation that
never stops. That is a real, visible, unmistakable *flinch*, and it is nowhere near a *flail*.

A useful sanity phrasing for the playtest: **the player should be able to tell you which arm he hit,
without being able to tell you that a physics system did it.**

---

## 5. Acceptance

### 5.1 What the user should SEE - first shot into a running German's arm

> A German is running left-to-right across the player's front at conversational range, rifle carried
> across his body, and the player puts a single Kar98 round into his left forearm. Within about a
> tenth of a second - fast enough that it reads as caused by the shot, not as a decision the
> character made - **the left forearm and hand snap outward and back along the line the bullet was
> travelling**, carrying the support hand off the forestock by roughly the width of the man's own
> hand, while his shoulder gives a little and his torso barely registers it. His **right hand does
> not leave the grip and the rifle does not visibly change where it is pointing.** He does not
> break stride, his legs keep their cycle, his head keeps tracking the player, and he keeps
> shooting. The arm is already on its way back before the eye has finished registering that it
> moved, and by about a third of a second it is exactly where the animation would have had it, with
> at most one small settle - no float, no drift, no catch at the end, and nothing left hanging. If
> the player then empties the magazine into the same arm, it flinches perhaps three more times, each
> a little less than the first, and never begins to vibrate or to trail behind the body. And if the
> normal MOHAA flinch animation fires for that same hit, the arm reaction gets out of the way and
> lets it play - the player sees one reaction, not two arguing.

**And the negative half, which is equally part of the acceptance:** at 1200 units the player should
see the man react without being able to say which limb; past ~1500 units he should see nothing new
at all, and that is correct. Nothing about the player's own view, the player's own weapon, or any
corpse on the ground should change.

### 5.2 The numeric instrument

One greppable line per reaction, on the existing `^~^~^` machine-parseable convention, gated behind
`r_ragdollDebug` (already `CVAR_TEMP`, `cg_ragdoll.c:317`):

```
^~^~^ HITREACT ent=NNN bone=<name> side=L|R large=0|1 swing=NN.Ndeg tip=NN.Nu
      peak=NNms total=NNms retrig=N dist=NNNNu gunarm=0|1 authored=0|1
```

- `swing` and `tip` as defined in §2.4 - `swing` uses the **same** measurement as the corpse
  instrument at `cg_ragdoll.c:1866-1886`, so the two are directly comparable in one log.
- `retrig` counts impulses folded into the current event (§3.5 pass condition: a 1-second MG42 burst
  into one arm yields `retrig` around 6-8 with `swing` staying inside the §2.4 band, not scaling
  with it).
- `authored=1` when the mod's `setmotionanim` flinch fired for the same hit (§3.2 pass condition:
  `total` collapses well under 400 ms in that case).
- `dist` supports the cull check (§2.1).

Pass conditions, against §2.4, from one live session:

| check | pass |
|---|---|
| support-arm rifle hit | `swing` 15-20, `tip` 6-9, `total` <= 400 |
| support-arm SMG hit | `swing` 8-12, `tip` 3.5-5.5, `total` <= 300 |
| gun-arm hit while firing | `swing` <= 8 |
| any pelvis or leg line | **zero occurrences** |
| any `ent` < `cgs.maxclients` | **zero occurrences** |
| MG42 burst | `retrig` >= 5 with `swing` inside band |
| beyond the cull radius | **zero lines** |
| `AIBEHAV3 ... hitreact=NN` | still climbing at its previous rate - the procedural layer must not have suppressed the authored one |

### 5.3 One-command rollback

A single archived master cvar, following the `coop_ragdoll` precedent (`CVAR_ARCHIVE`, defaults 0
until the look is signed off - `cg_ragdoll.c:320`):

```
coop_hitReact 0
```

...taking the whole living path dark in one console line with no rebuild, leaving the corpse system,
the authored flinch layer and `coop_aiHitReact` completely untouched. Plus per-axis `CVAR_TEMP`
knobs mirroring the corpse ones so the live A/B costs a keypress, not a build:
`coop_hitReactSwing` (peak degrees, default per §2.4), `coop_hitReactMs` (total, default 340),
`coop_hitReactGunArm` (gun-arm cap, default 8), `coop_hitReactDist` (cull, default 1500).

---

## Appendix A - measurement methods (so every MEASURED number can be re-run)

All three run against the retail install at
`G:\GOG\Medal of Honor - Allied Assault War Chest\`.

**Method 1 - authored clip durations.** Enumerate every `.skc` under
`models/human/animation/weapon_*/minor_pain/` and `/major_pain/` in `main/Pak*.pk3` (skipping the
`newanim/` duplicate tree, and letting later paks override earlier ones). Read the first 48 bytes as
`skcHeader_t` (`openmohaa-hzm/code/tools/md5_2_skX/skx_format.h:172`): `ident` at +0 must be
`SKAN`, `frameTime` (float) at +16, `numFrames` (int) at +44. Duration = `numFrames * frameTime`.
n = 78 minor, 90 major.

**Method 2 - alias resolution.** Parse every `models/human/animation/human_*.tik` in `main/Pak*.pk3`
for lines matching `^\s*(\w+_(stand|crouch)_hit_\w+)\s+(\S+\.skc)`, resolve each SKC path relative to
`models/human/animation/`, and apply method 1. n = 158 aliases across 12 weapon groups.

**Method 3 - `bulletlarge` census.** Scan every `.tik` in `main/*.pk3` and `maintt/*.pk3` for
`^\s*bulletlarge\s+(\d+)`. 241 hits at value 1, one at value 2 (`p_aagun_cannon.tik`), everything
else undeclared and therefore 0 by `fgame/weapon.cpp:1102`.

## Appendix B - code anchors referenced

| what | anchor |
|---|---|
| corpse sim, impulse entry point | `openmohaa-hzm/code/cgame/cg_ragdoll.c:1443` |
| torque couple / asymmetric ends | `cg_ragdoll.c:1548-1575` |
| accumulation ceiling (`vmax`) | `cg_ragdoll.c:1655` |
| quadratic falloff rationale | `cg_ragdoll.c:1690` |
| swing instrument | `cg_ragdoll.c:1866-1886` |
| `s_ragDriveChild` (bone drives toward child) | `cg_ragdoll.c:104-119` |
| impact limp constants | `cg_ragdoll.c:69-71` |
| cvar registration | `cg_ragdoll.c:314-357` |
| frame entry point | `cg_view.c:2928` |
| transition / clear signal | `cg_snapshot.c:140` |
| flesh-hit parse, force/radius/limp | `cg_parsemsg.cpp:1778`, `:1808`, `:1820`, `:2232`, `:2244` |
| flesh-hit send + direction fix | `fgame/weaputils.cpp:2621-2665` |
| `bulletbits` width | `fgame/weaputils.cpp:2357`, `fgame/actor.cpp:6036` |
| `bulletlarge` default | `fgame/weapon.cpp:1102` |
| second `CGM_BULLET_8` producer (death) | `fgame/actor.cpp:6040`, `anim/killed.scr:51` |
| renderer bridge, override table | `openmohaa-hzm/code/renderergl1/tr_ragdoll.cpp` (gl2 identical) |
| `animPose` stash - fed, never read | `tr_ragdoll.cpp`, `R_RagdollApplyToCache` |
| Hook B serves tag orientations | `tr_ragdoll.cpp`, `R_RagdollGetOrientation` |
| attached entity placed from a tag | `cgame/cg_ents.c:716` |
| local player camera from `eyes bone` | `cgame/cg_view.c:789`, `:807` |
| `tag_weapon_right` / `_left` | `cgame/cg_modelanim.c:1628` |
| script hit-react layer | `hzm-mohaa-coop-mod/coop_mod/aihandler.scr:1749`, `:1848-1897` |
| `coop_aiHitReact` default 55 | `hzm-mohaa-coop-mod/coop_defaults.cfg:364` |
| behaviour odometer (`hitreact=NN`) | `hzm-mohaa-coop-mod/coop_mod/aibehav.scr:128-168` |
| space/convention defect history | buglog `bug-1962`, `bug-1963`, `bug-1964`, `bug-1971`; self-block lesson `bug-1944` |

## Appendix C - sources

- [Microsoft Learn - Halo 2 Animation: Damage Animations](https://learn.microsoft.com/en-us/halo-master-chief-collection/h2/art/animation/animationdamageanims) - `soft_ping`/`hard_ping` overlay-vs-state split, 176-permutation taxonomy, region/direction inheritance tables
- [David Bollo, *Inertialization: High-Performance Animation Transitions in 'Gears of War'*, GDC 2018 (slides PDF)](https://media.gdcvault.com/gdc2018/presentations/bollo_david_inertialization_high_performance.pdf) / [GDC Vault](https://www.gdcvault.com/play/1025165/Inertialization-High-Performance-Animation-Transitions) - quintic offset decay, zero jerk at t1, limit overshoot via initial acceleration, clamp transition time
- [Epic - Physics Driven Animation in Unreal Engine](https://dev.epicgames.com/documentation/unreal-engine/physics-driven-animation-in-unreal-engine) and [Set All Bodies Below Physics Blend Weight](https://dev.epicgames.com/documentation/unreal-engine/BlueprintAPI/Physics/SetAllBodiesBelowPhysicsBlendWei-?lang=en-US) - the "blend physics on the sub-tree below the struck bone" pattern, drive the weight every tick
- [Daan Coppens, *Reactive Melee Combat in Unreal Engine 4*](https://assets.ctfassets.net/y4twieuxp19i/5WBm8ecHVC2EIQEGS26mMS/3435e9e01ffd7e57091597d67f7af7ca/ReactiveMeleeCombat.pdf) - physical animation profile values (Orientation 1000 / Angular Velocity 100 / Position 1000 / Velocity 100), sinusoid weight curve, "uncontrollable octopus" warning
- [Peyman Massoudi, *AnimMotion: Combining Ragdoll and Keyframe Animation*](http://peyman-mass.blogspot.com/2015/05/combining-physical-animation-with.html) and [*How To Implement Active Ragdoll*](https://peyman-mass.blogspot.com/2018/01/how-to-implement-active-ragdoll.html) - Havok "Rigid Body Ragdoll Controls Modifier", force-magnitude-driven blend factor, fade the physics pose out over time
- [Game Developer - Havok interview (Jeff Yates)](https://www.gamedeveloper.com/business/havok-your-way-an-interview-with-havok-s-jeff-yates) - "take a hit, go a little bit to ragdoll, recover, never go to the ground"
- [MCV/Develop - Max Payne 3 dev explains Euphoria engine tweaks](https://mcvuk.com/development-news/max-payne-3-dev-explains-euphoria-engine-tweaks/) and [Euphoria (software) - Wikipedia](https://en.wikipedia.org/wiki/Euphoria_(software)) - per-shot reactions, canned + simulated mix
- [Unity Discussions - How to blend ragdoll physics with animation](https://discussions.unity.com/t/how-to-blend-ragdoll-physics-with-animation/734320), [RagdollHelper.cs](https://github.com/nbzeman/Ragdoll/blob/master/Assets/Scripts/RagdollHelper.cs), [Jettelly - self-balancing active ragdoll](https://jettelly.com/blog/self-balancing-active-ragdoll-in-unity-breakdown-of-an-upcoming-tool) - partial ragdoll, per-bone Lerp/Slerp, 0.15-0.25 s drive-strength tween
- [MoCap Online - Ragdoll physics in games: how to blend animation](https://mocaponline.com/blogs/mocap-news/ragdoll-physics-animation-guide) - general blending practice
- [Winter anthropometric table (reproduction)](https://www1.udel.edu/biology/rosewc/kaap686/notes/anthropometry.html) - segment mass fractions (forearm 0.016 M, hand 0.006 M) and proximal radius of gyration (0.468 L), from Winter, *Biomechanics and Motor Control of Human Movement*
