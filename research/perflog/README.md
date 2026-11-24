# PerfLog

An always-on performance log for normal play, with a report script, for Cyberpunk 2077. Single-player only.
Version 1.0.1 | Built on game version 2.5 | Status: the first run worked; there is no test record for 1.0.1

## The question

When and where does the game hitch during normal play, what is the player doing at that moment (on foot, driving, fighting, in a menu), and do the hitches line up with Lua garbage-collection cycles (all Cyber Engine Tweaks mods share one Lua state) or with something else?

## How it was measured

A Cyber Engine Tweaks script (215 lines of Lua) with no hooks. Per frame it does a few additions and reads the Lua heap size; once a second, and only while unpaused in the world, it reads the player's context and position. Every 30 seconds it appends one line to a CSV file per game launch (`perf-<launch time>.csv` in its own folder, the 30 newest kept): time spent per context, frames, fps, frame-time percentiles (p50, p95, p99, worst), hitches and their total time, garbage-collection cycles and how many hitches coincided with one, heap floor, allocation rate and position. A hitch is a frame at least 2.5 times the typical frame time and at least 18 ms longer; the typical frame time is a moving average. Each hitch of 50 ms or more gets its own line with context and heap size. The report script `tools/perf_report.py` turns one launch into a Markdown report: hitches per minute by context, the share caused by garbage collection, heap growth per hour, the worst windows, hot spots per 100 m map cell, and, with a log-size snapshot taken before the launch, which mods wrote the most log lines and errors. Per-mod CPU time cannot be measured from inside Cyber Engine Tweaks, so the log answers when, where and whether garbage collection was involved, not which mod.

## What was found and what it led to

The first run worked. Version 1.0.1 changed how a hitch is detected: the typical frame time is now a moving average of recent frames, each clipped to twice the average. The log was written as the always-on companion to the stutter study in [investigations](../../docs/investigations.md); no findings from its reports are recorded beyond the first run.

## Requirements, install, uninstall

- Requires: Cyberpunk 2077 2.5 and [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107). The report needs Python 3. Requirements are not bundled.
- Install: copy the contents of `package/` into the game folder so that `bin\x64\plugins\cyber_engine_tweaks\mods\CyberslopPerfLog\init.lua` exists.
- Report: set the environment variable `CP2077_GAME_DIR` to the game folder (or run from the game folder), then `python -I -X utf8 tools\perf_report.py` for the newest launch, `--list` for all launches, `--snapshot` before a launch for the log-size section. Reports are written to `tools\reports\`.
- Uninstall: close the game and delete `bin\x64\plugins\cyber_engine_tweaks\mods\CyberslopPerfLog\` (this also removes the CSV logs). Saves are not affected: the script only reads.

Back to the [main page](../../README.md).
