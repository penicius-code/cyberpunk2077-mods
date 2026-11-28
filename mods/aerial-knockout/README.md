# Aerial Knockout

The aerial takedown (drop onto an enemy and smash their head into the ground) knocks the target out instead of killing it; Mantis Blades aerial takedowns still kill. Single-player only.
Version 1.1.0 | Built for game version 2.5 | Status: compiles on 2.5; no written in-game test record

## What and why

The base game (2.5) sends the aerial takedown with a non-lethal effect tag, but other mods can point that effect at a kill. On the author's setup two did: Zeusico Quickhacks (Solo) points it at its own knockout marker, and A.I.O (all in one) points it at a forced kill.

What this mod does:
1. A script system resets that effect on every save load (after all CET mods have run). It points it at Zeusico's Solo marker when that record exists, otherwise at the vanilla knockout.
2. An aerial takedown with Mantis Blades in hand gets the vanilla lethal tag, so blade takedowns kill as before.
3. (1.1.0) No stand-up before the drop: the game's knockout timer starts at the clip start for every variant, while the slam lands earlier or later depending on the side; the knockout is now timed to the slam.

No other mod's files are edited.

```text
package/
  r6/scripts/zz_CyberslopAerialKnockout/CyberslopAerialKnockout.reds
```

## Requirements

- Cyberpunk 2077 2.5
- [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511), a build for 2.5
- [Codeware](https://www.nexusmods.com/cyberpunk2077/mods/7780)

Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `r6\scripts\zz_CyberslopAerialKnockout\` exist.

## Uninstall / roll back

1. Close the game.
2. Delete `r6\scripts\zz_CyberslopAerialKnockout\`.

## Changelog

| Version | Change |
|---|---|
| 1.1.0 (2026-11-26) | The knockout is timed to the moment the slam lands, so the target no longer stands up before the drop. |
| 1.0.0 (2026-11-25) | First version. |

Back to the [mod list](../../README.md).
