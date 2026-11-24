# Hold Esc Menu

The pause menu opens only after Esc is held for half a second, so a quick tap to close something does not open it by accident. Single-player only.
Version 1.0.0 | For game version 2.5 | Status: not run in game

## What and why

The base game opens the pause menu when Esc is released. With this mod it opens only if Esc was held for at least 0.5 seconds before the release; a shorter tap does nothing. The menu still opens on the release, because opening it while Esc is still down would let the release reach the menu's own Back action and close it again. Esc still closes menus, the phone and popups as before.

Keyboard and mouse only. The pad's menu button is left to the game and to other mods that handle it.

The script wraps one game function, `gameuiInGameMenuGameController.OnAction`.

## Requirements

| Requirement | Version | Link |
|---|---|---|
| Cyberpunk 2077 | 2.5 | |
| redscript | a build for 2.5 | [Nexus Mods, mod 1511](https://www.nexusmods.com/cyberpunk2077/mods/1511) |

Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `r6\scripts\zz_CyberslopHoldEscMenu\CyberslopHoldEscMenu.reds` exists. The `zz_` prefix makes it load after other mods that wrap the same function.
3. Start the game, load a save and tap Esc: nothing opens. Hold Esc and release: the pause menu opens.

## Uninstall / roll back

1. Close the game.
2. Delete `r6\scripts\zz_CyberslopHoldEscMenu`.
3. Saves are not affected.

## Changelog

| Version | Date | Game version | Change |
|---|---|---|---|
| 1.0.0 | 2026-11-22 | 2.5 | First version. |

Back to the [mod list](../../README.md).
