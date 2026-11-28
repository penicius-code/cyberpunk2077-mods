# Quickhack Loadout Switcher

Swap the quickhack loadouts saved by the Quickhack Loadouts mod without opening the inventory: a small CET window plus hotkeys. Single-player only.
Version 1.0.2 | Built for game version 2.5 | Status: 1.0.1 run in game: swaps worked, the window showed wrong quickhack counts; fixed in 1.0.2, which is not run in game yet

## What and why

- CET window (while the CET overlay is open): one button per loadout (1 to 6) with its name and quickhack count; hovering shows the quickhacks it holds. The active loadout is red, empty slots are greyed out.
- CET hotkeys (unbound): next loadout, previous loadout, loadout 1 to 6. A hotkey shows a 2 second line on screen with the deck name or why nothing happened.
- Next and previous start from the last loaded loadout, skip empty slots and wrap around.
- The swap is Quickhack Loadouts' own load call, the same as pressing LOAD in its menu. Saving and naming stay in that mod's deck menu.
- One swap at a time; no swap while a quickhack uploads, the scanner quickhack panel is open or the game is paused.

The redscript part only reads the loadouts and calls the load; it wraps nothing and stores nothing in the save. Game calls run in `onUpdate`, never in `onDraw`; the window re-reads every 0.75 s only while the overlay is open.

```text
package/
  bin/x64/plugins/cyber_engine_tweaks/mods/CyberslopHackLoadouts/init.lua
  r6/scripts/CyberslopHackLoadouts/CyberslopHackLoadouts.reds
```

## Requirements

- Cyberpunk 2077 2.5
- [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107)
- [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511), a build for 2.5
- Quickhack Loadouts (Nexus Mods), which saves the loadouts
- Optional: [Mod Settings](https://www.nexusmods.com/cyberpunk2077/mods/4885) for the debug log switch

Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `bin\x64\plugins\cyber_engine_tweaks\mods\CyberslopHackLoadouts\`, `r6\scripts\CyberslopHackLoadouts\` exist.

## Uninstall / roll back

1. Close the game.
2. Delete `bin\x64\plugins\cyber_engine_tweaks\mods\CyberslopHackLoadouts\`, `r6\scripts\CyberslopHackLoadouts\`.

## Configuration

Hotkeys: CET > Bindings, under this mod's name. This mod's Mod Settings page > Debug > "Debug log" (off by default) writes its lines to CET's `gamelog.log`.

## Changelog

| Version | Change |
|---|---|
| 1.0.2 (2026-11-28) | The window showed 32766 quickhacks per loadout (an array read straight from a function's return value; every such array now goes into a local first). Empty slots are really greyed out. The debug log no longer reports finished swaps as unfinished. |
| 1.0.1 (2026-11-28) | One swap at a time; the loaded loadout is not reloaded; Next and Previous start from the last loaded loadout; no swap while uploading, in the scanner panel or paused; clearer window messages. |
| 1.0.0 (2026-11-28) | First version. |

Back to the [mod list](../../README.md).
