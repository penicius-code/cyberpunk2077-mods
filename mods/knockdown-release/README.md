# Knockdown Release

After a car hit knocks you down, you can move again as soon as you are back on your feet instead of waiting out the full effect. Single-player only.
Version 1.1.1 | Built for game version 2.31 | Status: not run in game; no version has a written test record

## What and why

A car hit (and some blast knockdowns) puts the player into a knockdown state that only ends when its status effect runs out: 4.1 seconds in the base game, 2 seconds for an explosion knockdown. The first-person get-up animation can finish earlier, and you then stand frozen until the timer ends.

This mod watches the first-person camera during that state. It records the camera height at the hit, and once the camera has dropped at least 0.30 m and is back within 0.15 m of that height for 0.10 seconds, it removes the knockdown effect. If the camera never drops (no fall animation played), the effect is removed after 1 second. Third person (camera far from the body at the hit) is left alone.

The release is based on the measured camera height, not on a guessed time. Another approach, speeding up the knockdown decisions, never applied, because this state runs the game's general status-effect decisions and not the knockdown ones.

## Requirements

| Requirement | Version | Link |
|---|---|---|
| Cyberpunk 2077 | built on 2.31 | |
| redscript | a build for your game version | [Nexus Mods, mod 1511](https://www.nexusmods.com/cyberpunk2077/mods/1511) |
| RedFileSystem | a build for your game version | [GitHub, rayshader/cp2077-red-filesystem](https://github.com/rayshader/cp2077-red-filesystem) |

RedFileSystem is needed for the log file; the script does not compile without it. Not checked: whether Codeware is also needed (the script uses a script service class, which the 2.5 game scripts list as a native class). Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `r6\scripts\CyberslopKnockdownRelease\CyberslopKnockdownRelease.reds` exists.
3. Start the game. After the first car knockdown, `r6\storages\CyberslopKnockdown\knockdowns.txt` is written.

## Uninstall / roll back

1. Close the game.
2. Delete `r6\scripts\CyberslopKnockdownRelease`. The log folder `r6\storages\CyberslopKnockdown` can be deleted too.
3. Saves are not affected.

## Configuration

There is no settings page. The values (release on/off, dip depth, tolerance, timings, log limits) are small functions at the top of the script. Setting `CKRReleaseOn()` to `false` keeps the log and never shortens a knockdown.

The log is buffered: nothing is written in a game launch without a car knockdown. Lines are written 30 seconds after the first one, at 10 lines, or when the game quits. Only the first 40 knockdowns of a launch get a full line.

## Changelog

| Version | Date | Game version | Change |
|---|---|---|---|
| 1.1.1 | 2026-11-06 | 2.31 | Log storage renamed to `CyberslopKnockdown`: RedFileSystem refuses names over 24 letters, so 1.1.0 never wrote its log. |
| 1.1.0 | 2026-11-03 | 2.31 | Buffered logging for normal play. |
| 1.0.0 | 2026-11-03 | 2.31 | First version. |

Back to the [mod list](../../README.md).
