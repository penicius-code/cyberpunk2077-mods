# Combat Log

A read-only hit logger with a report script, used to tune damage and armour, for Cyberpunk 2077. Single-player only.
Version 1.4.0 | Built for game version 2.5 with Much Better AI 3.0 | Status: earlier versions in use from late October 2026 on 2.31; 1.4.0 compiles on 2.5 (0 errors) but has not been run in game

## The question

What does each hit actually do in a fight: how much of the target's health it takes, how often NPCs hit the player and from what range, how many hits it takes to drop an NPC, and, when a hit does nothing, which part of the damage pipeline set it to zero?

## How it was measured

A redscript file (656 lines) that wraps eight game functions covering damage received, the end of the damage pipeline, defeat, NPC death, player death, the player attaching to the world, and the hit roll that decides whether an NPC's shot hits. It changes nothing in combat. Each game launch gets its own tab-separated file, `r6\storages\CyberslopCombatLog\combat-N.txt`: one row per load with difficulty and AI settings, one row per hit dealt or taken with the share of maximum health, weapon class, body zone and flags, shot rolls summed by range and attacker rank, fights between NPCs summed every 5 seconds, and down or death rows with the number of hits and seconds it took. As shipped, the per-hit detail row is switched on and every row is written to disk at once, a setting left from a crash hunt, so the file is larger than with buffering. The report script `tools/combat-log-report.py` groups the rows into fights (30 seconds without a hit or shot ends one) and prints tables: health lost per hit against a target band of 8 to 12 percent per rifle round, NPC hit rates by range, by what the player was doing, by attacker rank and by weapon class, hits until an NPC goes down, and the armour share per faction when an armour mod writes those fields.

## What was found and what it led to

The log was in use from late October 2026 and was the source of many tuning findings for damage and armour settings. Its per-hit row names every flag on a hit together with its source, so a punch that dealt no damage shows which mod or rule zeroed it; the code notes that the knockout problem this row was built for is solved. Version 1.4.0 is the port to game version 2.5 and Much Better AI 3.0, which no longer has the module the earlier versions read.

## Requirements, install, uninstall

- Requires: Cyberpunk 2077 2.5, [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511), [RedFileSystem](https://github.com/rayshader/cp2077-red-filesystem), [Ped Damage Overhaul 2077](https://www.nexusmods.com/cyberpunk2077/mods/5066) and [Much Better AI](https://www.nexusmods.com/cyberpunk2077/mods/31402) 3.0. The script imports the last three without a guard, so it does not compile without them. The report needs Python 3. Requirements are not bundled.
- Install: copy the contents of `package/` into the game folder so that `r6\scripts\zz_CyberslopCombatLog\CyberslopCombatLog.reds` exists.
- Report: set the environment variable `CP2077_GAME_DIR` to the game folder (or pass `--dir` with the log folder), then `python -I -X utf8 tools\combat-log-report.py` (`--last N` or `--all` for more launches). The report is also saved to a `logs` folder next to `tools`, or to the file given with `--out`.
- Uninstall: close the game and delete `r6\scripts\zz_CyberslopCombatLog\`, and `r6\storages\CyberslopCombatLog\` if the logs are not needed. Saves are not affected.

Back to the [main page](../../README.md).
