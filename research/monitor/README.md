# Monitor

A read-only logger that times every trip from the game world into a menu and back, and records the game state around it, for Cyberpunk 2077. Single-player only.
Version 2.1.2 | Built on game version 2.31 | Status: versions up to 2.1.1 were in use for weeks; there is no test record for 2.1.2

## The question

Where does the time go when the game switches from the world to a menu and back, and what state is the game in when a stutter or a crash happens?

## How it was measured

A Cyber Engine Tweaks script (829 lines of Lua) that changes nothing in the game. It notes every change of menu scenario and sub-menu (inventory, map, the quickhack wheel, photo mode), keeps the last 40 frame times, and after a menu closes it records the frames until the frame time settles, the hitch on closing and the time lost against the normal gameplay frame time. Every 10 seconds it writes frame statistics, the size of the Lua heap and a state line: position, district, police heat, the number of NPCs within 60 m, rain, time dilation, game clock and vehicle or combat state. Single frames over 100 ms are logged as spikes, and while NPCs are being hit or affected it adds one combat line per second. Lines that matter after a crash are written at once, the rest at least every 5 seconds, to `CyberslopMonitor.log` next to the script (rotated past 5 MB).

## What was found and what it led to

The log was used for weeks and fed the stutter study described in [investigations](../../docs/investigations.md): it dated when the steady stutter began, which narrowed the search. It also caught a crash in itself. Version 2.1.1 crashed the game when a save was loaded from the pause menu; the crash stack ended in a police-system call made by the 10-second state line while the world was being torn down. Version 2.1.2 therefore reads the world only after a world has started and while no load or exit has been requested, and it no longer reads the police unit count.

## Requirements, install, uninstall

- Requires: Cyberpunk 2077 (built on 2.31, not checked on 2.5) and [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107). Requirements are not bundled.
- Install: copy the contents of `package/` into the game folder so that `bin\x64\plugins\cyber_engine_tweaks\mods\CyberslopMonitor\init.lua` exists.
- Uninstall: close the game and delete `bin\x64\plugins\cyber_engine_tweaks\mods\CyberslopMonitor\` (this also removes the log). Saves are not affected: the script only reads.

Back to the [main page](../../README.md).
