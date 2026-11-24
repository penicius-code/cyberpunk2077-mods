# Stay Dead

Open-world NPCs you killed stay away for game days, knocked-out ones for a shorter time, and knocked-out bodies are picked up after a while. Single-player only.
Version 1.0.0 | Built for game version 2.31 | Status: compiles on 2.31 (0 errors); not run in game

## What and why

The base game has no respawn timer for open-world NPCs: the community system can bring the same NPC back whenever it decides to. This mod remembers every community NPC the player put down, with the game time:

- Killed: the NPC is "dead". If it spawns again within 14 game days, it is removed as it spawns (no body, no loot, no XP).
- Knocked out or bleeding out: the NPC is "in hospital" for 3 game days, with the same rule.
- A knocked-out body vanishes 20 game minutes after the knockout, once you are more than 30 m away.

Not tracked: quest NPCs, companions, crowd NPCs, police, and anything that is not a community spawn (reinforcement squads and some other mods' spawns have no stable identity).

## Requirements

| Requirement | Version | Link |
|---|---|---|
| Cyberpunk 2077 | built on 2.31 | |
| redscript | a build for your game version | [Nexus Mods, mod 1511](https://www.nexusmods.com/cyberpunk2077/mods/1511) |
| Mod Settings | a build for your game version | [Nexus Mods, mod 4885](https://www.nexusmods.com/cyberpunk2077/mods/4885) |

Mod Settings is required: the script registers its settings without a guard and does not compile without it. Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `r6\scripts\CyberslopStayDead\CyberslopStayDead.reds` exists.
3. Start the game. Mod Settings shows the page "Cyberslop Stay Dead". With the log on, the CET log `gamelog.log` gets `[StayDead]` lines.

## Uninstall / roll back

1. Close the game.
2. Delete `r6\scripts\CyberslopStayDead`.
3. Saves keep working. The records live only in saves made with the mod and are ignored without it.

## Configuration

Mod Settings > Cyberslop Stay Dead:

| Setting | Default | Range |
|---|---|---|
| Enabled | on | Off: base-game respawn, bodies stay where they fell. Records keep being written. |
| Killed: away for (game days) | 14 | 0.5 to 30 |
| Knocked out: away for (game days) | 3 | 0.5 to 30 |
| Knocked out: body picked up after (game minutes) | 20 | 5 to 120 |
| Log | on | |

## Known issues

- Not checked in game: whether a respawn reuses the same entity ID. The game scripts suggest that community IDs are fixed; if they are not, the mod would never recognise a returning NPC.
- The log setting is on by default.

## Changelog

| Version | Date | Game version | Change |
|---|---|---|---|
| 1.0.0 | 2026-11-01 | 2.31 | First version. |

Back to the [mod list](../../README.md).
