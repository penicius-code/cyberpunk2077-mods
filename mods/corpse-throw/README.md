# Corpse Throw

A hotkey puts the body under the crosshair on V's shoulder, ready for the game's Savage Sling throw. Single-player only.
Version 1.1 | Built on game version 2.31 | Status: tested in game on 2.31 (2026-10-24); not tested on 2.5

Published on Nexus Mods as "Corpse Throw Savage Sling Dead NPCs": <https://www.nexusmods.com/cyberpunk2077/mods/28748>

## What and why

Aim at a dead, knocked-out or downed NPC within 5 m and press the hotkey. The body is mounted on V's left shoulder as a thrown NPC, so the game's own throw can follow. If no body is directly under the crosshair, the body closest to it within 15 degrees is used.

Left alone: downed bosses, NPCs the game protects (companions and quest characters), and passengers still sitting in a car. No pickup while V already carries a body, sits in a vehicle or is in a scene. The CET console says why nothing was picked up.

The Cyber Engine Tweaks folder is named `GrappleTools`, as on Nexus.

```text
package/
  bin/x64/plugins/cyber_engine_tweaks/mods/GrappleTools/init.lua
```

## Requirements

- Cyberpunk 2077 2.31
- [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107) (built with 1.37.1)

No body-carry mod is needed. Requirements are not bundled.

## Install

1. Install Cyber Engine Tweaks.
2. Copy the contents of `package/` into the game folder, so that `bin\x64\plugins\cyber_engine_tweaks\mods\GrappleTools\init.lua` exists.
3. Start the game and bind the hotkey in the CET overlay: Bindings > GrappleTools > "Corpse Throw (Savage Sling Dead NPC)".

## Uninstall / roll back

1. Close the game.
2. Delete `bin\x64\plugins\cyber_engine_tweaks\mods\GrappleTools\`.
3. Saves are not affected: the mod writes no files and stores nothing in saves.

## Configuration

The `settings` table at the top of `init.lua`: `corpseRange` (5.0 m), `maxAngle` (15.0 degrees), `includeUnconscious` (true: also knocked-out and downed NPCs).

## Known issues

- Throwing a body that is still alive kills it, as in the base game.
- A beaten fist-fight opponent is not picked up (the game uses a different status for them).

## Changelog

| Version | Change |
|---|---|
| 1.1 (2026-10-24) | Crosshair targeting; knocked-out and downed NPCs; bosses, companions, quest characters and car passengers skipped; no pickup while carrying, in a vehicle or in a scene; console explains empty results |
| 1.0 | Dead NPCs only, first body found within 5 m |

Back to the [mod list](../../README.md).
