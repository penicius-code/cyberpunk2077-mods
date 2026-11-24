# Corpse Ragdoll

Dead human enemies that keep twitching or crawling on the floor go limp and stay limp. Single-player only.
Version 1.0.1 | For game version 2.5 | Status: 1.0.0 run in game on 2.5 with two failures seen; 1.0.1 not run in game

## What and why

Some dead NPCs keep moving on the ground after death. This mod forces the game's ragdoll (without a pose driving the joints, so the body is fully limp) on dead bodies that are still animating:

- A body that died in the "defeated" state is forced limp from 1 second after death; any other dead body that is still animating from 2 seconds.
- Each body is watched for 30 seconds. If something turns its ragdoll off again, it is forced limp again and the watch restarts.
- A ragdolling body that keeps moving for 2 seconds straight gets its ragdoll reset (at most 2 resets and 8 forces per body).

Never touched: living NPCs, bodies in a scripted pose or finisher, grappled or carried bodies, bodies in vehicles, bodies that cannot ragdoll (bosses, MaxTac), robots, drones and mechs.

Version 1.0.1 fixes what the 1.0.0 test showed: two kills kept moving because 1.0.0 stopped watching a body at the first limp reading, and in 2.5 that reading turns back to "not ragdolling" when the ragdoll is switched off.

## Requirements

| Requirement | Version | Link |
|---|---|---|
| Cyberpunk 2077 | 2.5 | |
| redscript | a build for 2.5 | [Nexus Mods, mod 1511](https://www.nexusmods.com/cyberpunk2077/mods/1511) |

Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `r6\scripts\zz_CyberslopCorpseRagdoll\CyberslopCorpseRagdoll.reds` exists.
3. Start the game. Each forced ragdoll writes a `[CorpseRagdoll]` line to the CET log `gamelog.log`.

## Uninstall / roll back

1. Close the game.
2. Delete `r6\scripts\zz_CyberslopCorpseRagdoll`.
3. Saves do not depend on it.

## Configuration

There is no settings page. The timings are constants at the top of the script. Logging is on: `Log()` returns `true`. Change it to `false` to stop the `[CorpseRagdoll]` lines.

## Changelog

| Version | Date | Game version | Change |
|---|---|---|---|
| 1.0.1 | 2026-11-21 | 2.5 | Force from 2 s (was 10 s; defeated bodies from 1 s), 30 s watch, re-force when the ragdoll is switched off, reset bodies that keep moving. |
| 1.0.0 | 2026-11-20 | 2.5 | First version. |

Back to the [mod list](../../README.md).
