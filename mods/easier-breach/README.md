# Easier Breach

The Breach Protocol puzzle stays, but Intelligence decides how much easier it gets, and devices get easier than NPCs. Single-player only.
Version 1.0.0 | Built for game version 2.31 | Status: not run in game

## What and why

Written as a replacement for an auto-solve mod: the puzzle is kept, and Intelligence scales the help (Intelligence 3 = nothing extra, 20 = full).

Device breaches (access points, devices, remote breach on a device, shards):

- Timer x2 at Intelligence 3 up to x4 at 20 (base game 30 s: 60 to 120 s). Can be switched off entirely in Mod Settings.
- Buffer +1 (Intelligence 3 to 7), +2 (8 to 15), +3 (16 to 20).
- Daemon chains 1 shorter and at most 4 cells, at most 3 from Intelligence 12. Never under 2.
- Daemons are linked in list order: the last cell of one is the first cell of the next, so one path can finish several. Chance per link 70 % at Intelligence 3 up to 100 % at 20.

NPC breaches (physical, unconscious and grapple breach, remote breach on an NPC, and the netrunner and squad networks of Much Better Netrunning):

- Timer x1 at Intelligence 3 up to x2.5 at 20.
- Buffer +1 at Intelligence 3 up to +5 at 20.
- Daemon chains as in the base game below Intelligence 12; from 12 one shorter and at most 4 cells.
- No overlap: every daemon is its own sequence.

The buffer never goes above 12. Breaches whose records fix their own buffer (Courier Jobs, quest boards, hard shards) keep their buffer and timer. Unchanged: the shorter timer on later attempts, board size, symbols, the automatic first daemon perk and fixed daemon lists.

## Requirements

| Requirement | Version | Link |
|---|---|---|
| Cyberpunk 2077 | built on 2.31 | |
| redscript | a build for your game version | [Nexus Mods, mod 1511](https://www.nexusmods.com/cyberpunk2077/mods/1511) |
| Mod Settings (optional) | a build for your game version | [Nexus Mods, mod 4885](https://www.nexusmods.com/cyberpunk2077/mods/4885) |

Without Mod Settings the default values apply. Requirements are not bundled.

## Install

1. Install the requirements above. Disable any auto-solve mod for Breach Protocol, such as [Nexus Mods, mod 6956](https://www.nexusmods.com/cyberpunk2077/mods/6956).
2. Copy the contents of `package/` into the game folder, so that `r6\scripts\CyberslopEasierBreach\CyberslopEasierBreach.reds` exists.
3. Start the game and open a breach. With the breach log on, the CET log `gamelog.log` gets one `[EasierBreach]` line per breach.

## Uninstall / roll back

1. Close the game.
2. Delete `r6\scripts\CyberslopEasierBreach`. Or switch "Enabled" off in Mod Settings.
3. Saves are not affected.

## Configuration

Mod Settings > Easier Breach:

| Setting | Default |
|---|---|
| Enabled | on |
| No timer on device breaches | off |
| Breach log | on |

The breach log writes device or NPC, Intelligence, buffer, timer, daemon lengths and links of each breach to the CET game log.

## Compatibility

| Item | Status | Notes |
|---|---|---|
| Auto-solve mods for Breach Protocol | conflict | This mod replaces that approach; use one or the other. |
| Much Better Netrunning, Courier Jobs | designed to work together | They wrap other functions of the breach code; none of those is touched here. |

## Changelog

| Version | Date | Game version | Change |
|---|---|---|---|
| 1.0.0 | 2026-10-29 | 2.31 | First version. |

Back to the [mod list](../../README.md).
