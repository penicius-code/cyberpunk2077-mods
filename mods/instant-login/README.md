# Instant Login

An add-on for NewBrowser: every in-game computer goes straight to its desktop instead of playing NewBrowser's typed login. Single-player only.
Version 1.0.0 | Built for game version 2.31 | Status: confirmed in game on 2.31 (2026-11-04)

## What and why

NewBrowser redesigns the in-game computer screens and plays a login sequence of about 3.5 seconds on each computer (a user name typed character by character, password stars, "Connecting..." pulses). This add-on skips that sequence. NewBrowser's screens stay as they are, and none of its files are changed.

How: NewBrowser plays the sequence once per computer while its own field `m_hasShownLoginSequence` is false. This script wraps `ComputerInkGameController.SetupWidgets`, which runs before the screen is switched on, and sets that field to true. A computer that is still asleep shows NewBrowser's idle screen; waking it goes straight to the desktop.

## Requirements

| Requirement | Version | Link |
|---|---|---|
| Cyberpunk 2077 | built on 2.31 | |
| redscript | a build for your game version | [Nexus Mods, mod 1511](https://www.nexusmods.com/cyberpunk2077/mods/1511) |
| NewBrowser (by L3LY), with its login screen file | the version you use | [Nexus Mods, mod 32851](https://www.nexusmods.com/cyberpunk2077/mods/32851) |

NewBrowser is required: the field belongs to NewBrowser, and without it this script does not compile. Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `r6\scripts\zz_CyberslopInstantLogin\CyberslopInstantLogin.reds` exists.
3. Start the game and use a computer: the desktop appears without the typed login.

## Uninstall / roll back

1. Close the game.
2. Delete `r6\scripts\zz_CyberslopInstantLogin`. Remove it together with NewBrowser if you uninstall NewBrowser.
3. Saves are not affected.

## Changelog

| Version | Date | Game version | Change |
|---|---|---|---|
| 1.0.0 | 2026-11-04 | 2.31 | First version. |

Back to the [mod list](../../README.md).
