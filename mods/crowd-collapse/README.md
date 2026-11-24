# Crowd Collapse

The System Collapse quickhack knocks crowd NPCs (pedestrians, vendors, tenants) unconscious. Single-player only.
Version 1.0.0 | For game version 2.5 | Status: compiles on 2.5 (0 errors); not run in game

## What and why

The base game never lets System Collapse target crowd NPCs. A mod that makes civilians quickhackable, such as Hackable Civilians, adds it to them, but the quickhack then uploads and lands with no knockout: in 2.5 System Collapse knocks a target out only through the NPC's AI behaviour, and crowd NPCs run a reduced AI that has no behaviour for it. In testing, three casts left a crowd NPC standing with reduced health.

This mod waits 0.1 seconds after System Collapse lands on a living crowd NPC, then applies the game's own knockout effect (the one the game gives a crowd NPC knocked out non-lethally) and a ragdoll so the body drops. Regular NPCs keep the normal path.

Skipped: children, quest-protected NPCs, NPCs immune to knockout, anyone already down or dead.

## Requirements

| Requirement | Version | Link |
|---|---|---|
| Cyberpunk 2077 | 2.5 | |
| redscript | a build for 2.5 | [Nexus Mods, mod 1511](https://www.nexusmods.com/cyberpunk2077/mods/1511) |

The mod compiles on its own, but it only has an effect when another mod lets System Collapse target crowd NPCs (it was written for Hackable Civilians together with Quickhack_Fixes). Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `r6\scripts\CyberslopCrowdCollapse\CyberslopCrowdCollapse.reds` exists.
3. Start the game and use System Collapse on a pedestrian. The CET log `gamelog.log` gets a `[CrowdCollapse] ... knocked out` line.

## Uninstall / roll back

1. Close the game.
2. Delete `r6\scripts\CyberslopCrowdCollapse`.
3. Saves are not affected.

## Configuration

There is no settings page. Every knockout or skip writes one `[CrowdCollapse]` line to the CET log (buffered, written in 4 KB blocks and at quit).

## Changelog

| Version | Date | Game version | Change |
|---|---|---|---|
| 1.0.0 | 2026-11-22 | 2.5 | First version. |

Back to the [mod list](../../README.md).
