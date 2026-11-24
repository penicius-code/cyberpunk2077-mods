# Sound Gains

Sets the volume of custom sounds from other sound mods through AudioXL, from one tuning table. Single-player only.
Version 1.0.1 | For game version 2.5 | Status: 1.0.0 confirmed in game (2026-10-27, game 2.31); 1.0.1 not run in game

## What and why

Several sound mods (REDmods) set their own volume in their `info.json`. With AudioXL installed, every custom sound sits in the one sound registry that AudioXL drives, and the volume stored there never reaches the samples: AudioXL applies volumes itself through its `SetGain` call. The REDmod sounds then played at full volume.

This Cyber Engine Tweaks mod waits until AudioXL's script bridge answers and calls `SetGain` for every row of `gains.lua`. Rows that do not exist yet are retried once a second for up to 90 seconds. Every row is set again each time a save is loaded. Nothing else is changed. No sound files are included.

`gains.lua` is a personal tuning table. Its rows name sounds from other authors' mods (dodge and double-jump sounds, Kerenzikov and Sandevistan sounds, UI sounds of a sound overhaul, quest stingers, melee finishers, a guitar song). Rows for sounds you do not have are retried for 90 seconds and then reported as not set. Edit the table for the sound mods you use.

## Requirements

| Requirement | Version | Link |
|---|---|---|
| Cyberpunk 2077 | 2.5 | |
| Cyber Engine Tweaks | a build for 2.5 | [Nexus Mods, mod 107](https://www.nexusmods.com/cyberpunk2077/mods/107) |
| AudioXL | the version you use | |

The table only has an effect for the sound mods named in `gains.lua`. Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `bin\x64\plugins\cyber_engine_tweaks\mods\CyberslopSoundGains\init.lua` exists.
3. Start the game and load a save. `CyberslopSoundGains.log` next to `init.lua` gets one line per row, for example `lcm_dash = 0.050 (-26.0 dB) set`.

## Uninstall / roll back

1. Close the game.
2. Delete `bin\x64\plugins\cyber_engine_tweaks\mods\CyberslopSoundGains`.
3. Saves are not affected. The sound mods keep their own `info.json` volumes.

## Configuration

Edit `gains.lua`: one row per sound event name, linear gain, 1.0 = as recorded (0.5 = -6 dB, 0.1 = -20 dB). For silence use 0.001 rather than 0. Any custom sound name can be added. After a change, restart the game or reload the CET mods and run `GetMod("CyberslopSoundGains").apply()` in the CET console. `GetMod("CyberslopSoundGains").status()` lists every row as set, pending or not set.

## Known issues

- The log file has no size limit and grows with every launch.

## Changelog

| Version | Date | Game version | Change |
|---|---|---|---|
| 1.0.1 | 2026-11-23 | 2.5 | A row for a sound mod that was no longer installed is commented out (it was retried for 90 s on every launch and filled the log). |
| 1.0.0 | 2026-10-27 | 2.31 | First version. |

Back to the [mod list](../../README.md).
