# Bane Log

A CET window for CyberBane: every text and map pin it gives you in one history, and its pins trackable with one click. Single-player only.
Version 1.0.1 | Built for game version 2.5 | Status: compiles on 2.5; no written in-game test record; offline mock test 16 of 16

## What and why

- **History tab**: every text CyberBane's gangs, rivals, fixers and crews send you (your replies optional), and every place it marks on the map, newest first with game day and time. Filter, search. A map entry whose pin is still on the map shows its distance and a TRACK button. Kept in `history.json` in the mod's folder (last 500 entries), across sessions.
- **On the map tab**: CyberBane's pins right now, nearest first: places (track / untrack) and a collapsible people section (hunters, bagmen, people at a sit-down). "Track nearest place". Tracking sets the GPS route as on the world map; untrack only drops CyberBane pins, never your quest.
- The window title shows "(N new)" until you look at the history. It is drawn only while the CET overlay is open.

How it works: texts are read from CyberBane's phone store every 3 seconds; a thread is read again only when it changes. Pins are read from the map. The redscript part only provides a session number, so a CET reload adds nothing twice. No other mod's files are edited.

```text
package/
  bin/x64/plugins/cyber_engine_tweaks/mods/CyberslopBaneLog/init.lua
  r6/scripts/CyberslopBaneLog/CyberslopBaneLog.reds
```

## Requirements

- Cyberpunk 2077 2.5
- [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107) and [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511)
- CyberBane (2.7.10 was used)

Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `bin\x64\plugins\cyber_engine_tweaks\mods\CyberslopBaneLog\`, `r6\scripts\CyberslopBaneLog\` exist.

## Uninstall / roll back

1. Close the game.
2. Delete `bin\x64\plugins\cyber_engine_tweaks\mods\CyberslopBaneLog\`, `r6\scripts\CyberslopBaneLog\`.

## Configuration

Hotkey (unbound): "Show / hide the Bane Log window". Options in the window: log your replies, log people markers in the history.

## Changelog

| Version | Change |
|---|---|
| 1.0.1 (2026-11-27) | A repeated text is logged again when it is sent again; pins put back by a load are not logged twice, but a gathering at the same spot days later is; hunters are one entry each, not one per position; history.json is written safely; each TRACK button has its own id. |
| 1.0.0 (2026-11-27) | First version. |

Back to the [mod list](../../README.md).
