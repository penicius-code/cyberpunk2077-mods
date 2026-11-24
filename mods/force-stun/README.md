# ForceStun

A hotkey stuns the NPC under the crosshair, so V can grab it for a Savage Sling throw. Single-player only.
Version 1.1 | Built on game version 2.31 | Status: tested in game on 2.31 (2026-10-24); not tested on 2.5

Published on Nexus Mods as "ForceStun Hotkey Stun for Savage Sling": <https://www.nexusmods.com/cyberpunk2077/mods/28745>

## What and why

Aim at an NPC within 15 m and press the hotkey. If no NPC is directly under the crosshair, the one closest to it within 8 degrees is used. Dead, defeated and knocked-out NPCs are skipped with a message.

With Buttslinger Quickmelee installed, the mod applies that mod's stun (`ActualStun` plus its opening effect), which gives the grab prompt; this works with Gorilla Arms equipped, no weapon swap needed. Without it, the mod applies the vanilla stun and prints a one-time note to the CET console; there is then no grab prompt.

```text
package/
  bin/x64/plugins/cyber_engine_tweaks/mods/ForceStun/init.lua
```

## Requirements

- Cyberpunk 2077 2.31
- [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107) (built with 1.37.1)
- Optional: [Buttslinger Quickmelee](https://www.nexusmods.com/cyberpunk2077/mods/10556), for the grab prompt

Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `bin\x64\plugins\cyber_engine_tweaks\mods\ForceStun\init.lua` exists.
3. Start the game and bind the hotkey in the CET overlay: Bindings > ForceStun > "Force Stun Target (for Savage Sling)".

## Uninstall / roll back

1. Close the game.
2. Delete `bin\x64\plugins\cyber_engine_tweaks\mods\ForceStun\`.
3. Saves are not affected: nothing is stored.

## Configuration

The `settings` table at the top of `init.lua`: `maxRange` (15.0 m), `maxAngle` (8.0 degrees).

## Changelog

| Version | Change |
|---|---|
| 1.1 (2026-10-24) | Crosshair targeting; vanilla stun when Buttslinger Quickmelee is missing; dead and knocked-out NPCs skipped with a message; the unused stun duration setting removed |
| 1.0 | First release |

Back to the [mod list](../../README.md).
