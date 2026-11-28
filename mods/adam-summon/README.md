# Adam Summon

A CET window with one toggle that starts the Lore-Accurate Adam Smasher encounter wherever you are, at any wanted level. Single-player only.
Version 1.0.0 | Built for game version 2.5 | Status: not run in game yet; offline mock test 20 of 20

## What and why

Without this mod, Lore-Accurate Adam Smasher only spawns Adam in the City Center district at a high wanted level. This window drives that mod's own command queue, which its author meant for a CET bridge:
- Toggle on with no wanted stars: Adam is spawned 25 to 175 m away, off-screen, with path-finding; the corp squads come as usual.
- Toggle on with stars and "Clear my stars first" ticked (default): the pursuit is ended first, then Adam comes. Unticked: it waits until you lose the stars.
- While he is out, the police are held off through that mod's own police lock, released before every save and taken again after.
- He withdraws at 20 % health as usual. When he is gone, or you untick the toggle, the encounter ends and the police are back.
- The save's repair timer and the normal 5-star encounter are untouched. Blocked in safe areas, scenes and dialogue, and while Adam or his squads are still around.
- The window sends a heartbeat every frame; without it (for example after a CET reload) the other mod ends a summon after 10 s.

No other mod's files are edited.

```text
package/
  bin/x64/plugins/cyber_engine_tweaks/mods/CyberslopAdamSummon/init.lua
```

## Requirements

- Cyberpunk 2077 2.5
- [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107)
- Lore-Accurate Adam Smasher 1.0.1 ([Nexus Mods, mod 36865](https://www.nexusmods.com/cyberpunk2077/mods/36865)) and its requirements

Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `bin\x64\plugins\cyber_engine_tweaks\mods\CyberslopAdamSummon\` exist.

## Uninstall / roll back

1. Close the game.
2. Delete `bin\x64\plugins\cyber_engine_tweaks\mods\CyberslopAdamSummon\`.

## Configuration

Hotkey (unbound): "Toggle Adam Smasher summon".

## Changelog

| Version | Change |
|---|---|
| 1.0.0 (2026-11-26) | First version. |

Back to the [mod list](../../README.md).
