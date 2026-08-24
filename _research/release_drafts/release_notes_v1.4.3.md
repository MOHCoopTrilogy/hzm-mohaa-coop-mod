## HZM Coop v1.4.3 — the truck ride is quiet again

Mostly a fix pass, and the headline one had been hunting us for a while.

### The Normandy truck ride no longer ambushes you

If you played m1l1 recently you had Germans opening fire on you *during* the scripted ride into
the checkpoint — sometimes seconds after the map loaded. Fixed, and the cause is worth telling.

The engine command that marks a player "don't shoot this one" (`notarget`) is declared **twice**,
and for players it resolved to a **cheat toggle** that ignores its argument and flips the flag
rather than setting it. So every attempt to protect you switched it back off again. It looked
random because the outcome depended on how many times the code happened to run — three live runs
of one identical build produced three different results.

It's fixed at the root, which means it fixes the same thing on **every scripted ride in the
trilogy** — Normandy, the Bastogne intro, the e1l3 tank ride and eleven more map scripts — not
just the one map where we noticed it.

Verified over four live two-player rides: zero enemies acquiring a player for the whole ride,
while they could still plainly see you.

### Also fixed

- **Your squad stays seated in the truck.** The allies riding with you were standing up mid-ride
  and playing a dive animation. They stay put now.
- **One kit per spawn, not three.** You were being handed your loadout three times (two silently).
  The join sequence sends its picks in two volleys eleven seconds apart, and the merge window was
  only 1.5 seconds, so it could never combine them. Armory picks still apply the instant you spawn.
- **The bolt idle animation is gone** — as requested. It turned out it was still running even
  though it had been switched off, because the old setting was saved in your config and beat the
  new default.
- **Turret gunners get their weapon back** when they dismount instead of it staying invisible.
- **The low-ammo weapon tilt is removed.** It was under one unit of movement — nobody could see it.

### Still in progress

**Wall cover is not ready.** Leaning and blind-firing out of a doorway still pick the wrong side.
We now know exactly why — the check that asks "can I fit through that gap" starts its trace
already touching the wall, so it reports both sides blocked — and it's being fixed properly rather
than patched again. The in-game field report says the same; we'd rather tell you than let you find
it.

Use **Report a Bug** in the menu — it comes straight to us.
