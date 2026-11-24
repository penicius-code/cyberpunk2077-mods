# Gore Probe

A logger for the hit-reaction and dismemberment pipeline, with a built-in A/B test and a report script, for Cyberpunk 2077. Single-player only.
Version 1.1.0 | Built on game version 2.31 | Status: used in game until the question below was answered, then removed; which of 1.0.0 or 1.1.0 produced the recorded result is not recorded

## The question

Why do dismemberment and gore wounds stop happening when enemies are shot from a distance: is a script rule blocking them, or does the engine drop the cut?

## How it was measured

A redscript file (691 lines) wraps the six game functions that decide a hit reaction, wounds and dismemberment, and logs each ranged hit on an NPC with distance, camera field of view (scope zoom), hit shape, every gate decision, every cut request, the call into the engine and the limb count 3 seconds later, which shows whether the engine really cut. Its folder name makes its wraps the outermost ones, so it sees the final decision of every other gore mod. An automatic A/B test answers the engine question during normal play: ranged kill shots from 30 m on that got no cut alternate between being left alone and getting a forced cut of the hit head or limb. A small Cyber Engine Tweaks script adds optional hotkeys (mark "gore seen" or "no gore" on the last hit, force a cut, switch the A/B test off) and an on-screen readout. The report script `tools/gore_probe_report.py` prints, per distance band, the path from shot to confirmed cut, the A/B results, the player's marks and an automatic verdict.

## What was found and what it led to

The engine drops cuts at range: 22 of 22 cuts landed under 25 m, 0 of 12 beyond 75 m. The limit is not in a script, so no script change can bring gore back at long range; the report's reading for this pattern is a native limit that would need an engine plugin. The probe was removed from the game once the question was answered.

## Requirements, install, uninstall

- Requires: Cyberpunk 2077 (built on 2.31; its six hook targets still exist in the 2.5 scripts, not run on 2.5), [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511) and [RedFileSystem](https://github.com/rayshader/cp2077-red-filesystem). [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107) only for the hotkeys and the readout. The report needs Python 3. Requirements are not bundled.
- Note: the A/B test is on by default and changes the game: about every second long-range kill shot to the head or a limb that would leave the body intact cuts that part off. Switch it off with the hotkey "toggle automatic A/B engine test"; it is on again at the next launch.
- Install: copy the contents of `package/` into the game folder so that `r6\scripts\zz_zz_CyberslopGoreProbe\CyberslopGoreProbe.reds` exists (and `bin\x64\plugins\cyber_engine_tweaks\mods\CyberslopGoreProbe\init.lua` for the hotkeys).
- Report: set the environment variable `CP2077_GAME_DIR` to the game folder, then `python -I -X utf8 tools\gore_probe_report.py` (newest log), or pass a log file or folder.
- Uninstall: close the game and delete `r6\scripts\zz_zz_CyberslopGoreProbe\` and `bin\x64\plugins\cyber_engine_tweaks\mods\CyberslopGoreProbe\`, and `r6\storages\CyberslopGoreProbe\` if the logs are not needed.

Back to the [main page](../../README.md).
