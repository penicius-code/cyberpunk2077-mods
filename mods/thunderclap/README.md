# Thunderclap

A new legendary electric quickhack that knocks human enemies out instead of killing them. Single-player only.
Version 1.3.0 | For game version 2.5 | Status: 1.1.0 confirmed in game on 2.31 (2026-11-08); 1.2.0 to 1.3.0 not run in game; 1.3.0 compiles on 2.5

## What and why

Adds the quickhack program "Thunderclap" (Short Circuit icon, 16 RAM, 2.0 s upload). The program is put into the backpack once per save. On a human target:

- The target is knocked out and thrown back on every cast. Impacts from the throw cannot kill it for 10 seconds.
- The discharge arcs to up to three hostile NPCs within 12 m of the target. Each loses 25 % health and is electrocuted, and is knocked out if left at 25 % health or less.
- Health never drops below 5 % through this quickhack.
- Bosses, MaxTac and quest-protected NPCs are stunned and not hurt. NPCs that cannot be knocked out (exo soldiers) lose 50 % health and are stunned.
- Drones, mechs and androids get the game's legendary EMP grenade effect.

The cast plays the game's Blackwall hand gesture (the weapon is holstered and drawn again after 2 seconds), slows time to 10 % for 0.5 seconds, and shows the game's EMP explosion visual.

It was written from scratch because an earlier setup built on another author's Thunderclap quickhack still killed targets: the thrown body hit the ground hard enough for the game to mark it for death. This version deals no game damage to humans at all and applies the game's own knockout effect directly.

## Requirements

| Requirement | Version | Link |
|---|---|---|
| Cyberpunk 2077 | 2.5 | |
| redscript | a build for 2.5 | [Nexus Mods, mod 1511](https://www.nexusmods.com/cyberpunk2077/mods/1511) |
| TweakXL | a build for 2.5 | [Nexus Mods, mod 4197](https://www.nexusmods.com/cyberpunk2077/mods/4197) |
| Codeware | a build for 2.5 | [Nexus Mods, mod 7780](https://www.nexusmods.com/cyberpunk2077/mods/7780) |
| Cyber Engine Tweaks (optional) | a build for 2.5 | [Nexus Mods, mod 107](https://www.nexusmods.com/cyberpunk2077/mods/107) |

Cyber Engine Tweaks is needed only for the window that switches the slow motion off. Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `r6\scripts\CyberslopThunderclap\CyberslopThunderclap.reds` exists.
3. Start the game and load a save. The program "Thunderclap" is in the backpack; install it in the cyberdeck. The CET log `gamelog.log` gets the line `[CyberslopThunderclap] program added to the backpack`.

## Uninstall / roll back

1. Close the game.
2. Delete:
   - `r6\scripts\CyberslopThunderclap`
   - `r6\tweaks\CyberslopThunderclap`
   - `bin\x64\plugins\cyber_engine_tweaks\mods\CyberslopThunderclap`
3. Saves keep working. The program item disappears from saves made with the mod; the quest fact `cyberslop_thunderclap_granted` stays in the save unused.

## Configuration

With the Cyber Engine Tweaks overlay open, the window "Cyberslop Thunderclap" has one checkbox, "Slow motion on cast" (on by default). The choice is saved in `config.json` in the mod's CET folder. All other values (RAM cost, arc range, health floor) are fixed in the scripts.

## Known issues

- Every cast writes one line per affected NPC to the CET log `gamelog.log`. There is no switch to turn this off.
- The tweak file still defines a settings record from 1.2.0 that nothing uses. It is harmless.

## Changelog

| Version | Date | Game version | Change |
|---|---|---|---|
| 1.3.0 | 2026-11-23 | 2.5 | Stronger: 16 RAM, knockout and throw on every cast, three arcs at 12 m that can knock out. |
| 1.2.2 | 2026-11-23 | 2.5 | Street MaxTac squads count as MaxTac (stunned). NPCs immune to knockout are shocked and stunned. |
| 1.2.1 | 2026-11-23 | 2.5 | The slow-motion switch goes through a script service; the 1.2.0 method failed on 2.5. |
| 1.2.0 | 2026-11-08 | 2.31 | CET window to switch the slow motion off. |
| 1.1.0 | 2026-11-07 | 2.31 | Cast look: hand gesture, short slow motion, EMP visual. Visuals only. |
| 1.0.1 | 2026-11-07 | 2.31 | No program grant in the main menu's pre-game state. |
| 1.0.0 | 2026-11-06 | 2.31 | First version. |

## Credits

The cast timing and the choice of the game's own gesture and EMP visual follow the look of Zeusico's Thunderclap quickhack. No code or records from that mod are used.

Back to the [mod list](../../README.md).
