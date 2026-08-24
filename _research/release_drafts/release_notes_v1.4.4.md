## HZM Coop v1.4.4 — gloves, and a lot of things that were quietly not working

A big pass. Some of it is new, but most of the value this time is in things that *looked* fine and
were not — including several where the fix we shipped earlier turned out to do nothing at all.

### New: gloves in the Armory

A **GLOVES** row next to Skin and Helmet — seven looks, visible in **both** third person and down
the sights. Bare Hands and Leather Gloves are free; the rest unlock by challenge or rank, and the
armory now tells you exactly which.

Every glove comes from art already on your disk. Nothing was downloaded, and three of the
first-person textures were derived locally from retail ones, because the third-person and
first-person hands are different meshes with different UV layouts — a 3P glove texture simply
cannot be shown down the sights.

### The armory tells you how to earn things now

Locked items used to say *"earn it via challenges/ranks"*, which is barely more useful than a
padlock. Every gated item now names its actual requirement:

> **Armory: KAR98K is LOCKED — Reach rank 3**
> **Helmet locked: Italian Infantry Hat — Challenge: Autoblinda Down**

That list is generated from the challenge and rank tables rather than written by hand, so it cannot
drift out of step with them. While building it we audited all 256 gated items: **nothing is
unobtainable and no reward points at something that does not exist.**

Three Elite challenges were also paying out a uniform every player already owned — *The Tell-Tale
Ping*, *The Better Rifle* and *Six for Sure* now grant real ones.

### Enemies hold their ground again

If you have played Omaha or the Normandy houses recently you will have seen a garrison walk out of
a building to meet you in the open. That was ours: every German was having his **leash** — how far
from his post he may roam — overwritten with a flat value up to eight times the engine default, by
a dice roll, on top of whatever the map designer had set. Now it adds a modest bonus instead of
replacing it, so defenders defend the thing they were placed to defend.

### The invisible damage

Some of you have been shot by nothing. A prone rifleman's fire was genuinely unseeable — the round
is deliberately scaled to nothing so it reads as hitscan, and its tracer was disabled. Those shots
now make a noise from the right direction, so you can find the man shooting you.

### Also fixed

- **A crash on the Omaha bunker map.** A one-word mistake in our own engine change could corrupt a
  model's data on load and hang the game. Found and fixed the same evening.
- **Converting an enemy no longer breaks "eliminate all enemies" objectives.** A converted soldier
  stayed on the enemy ledger forever — unkillable because he is on your side, uncounted because
  nothing removed him. That made those objectives impossible to finish.
- Script errors on m3l1b when the flak gun was destroyed.
- Sprint speed is down again, and this time it will actually reach you — the old value was being
  shipped by a config file that overrode everything else.
- Gore wounds are on, for the same reason.

### Known issues, said plainly

- **Glove choice does not survive a map change** yet. It holds for the mission you pick it in.
- **Three helmets are hidden** — Brit Beret, German Beret and Soviet Seaman Hat. Their models are
  built on a full character skeleton rather than a prop rig, so they attach in the wrong place. They
  will come back once rebuilt properly.
- **Wall cover is still not right.** The camera work was reverted this build after it disturbed
  crouch cover, which was fine as it was. Crouch cover is unaffected; standing wall cover remains a
  work in progress.

Use **Report a Bug** in the menu — it comes straight to us.
