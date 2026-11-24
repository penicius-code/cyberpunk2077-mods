# SandevistanToggle

A hotkey switches a Sandevistan-style slow motion on and off anywhere, including dialogues. Single-player only.
Version 1.2 | Built on game version 2.31 | Status: 1.1 tested in game on 2.31 (2026-10-24); 1.2 not yet play-tested (offline mock passed)

Published on Nexus Mods as "SandevistanToggle Manual Time Dilation Hotkey" (version 1.1 there): <https://www.nexusmods.com/cyberpunk2077/mods/28747>

## What and why

Press the hotkey: the world slows to 0.3 of its speed while V moves at full speed. Press again: it eases out the way the cyberware does. It uses the game's own `sandevistan` time dilation, so the effect matches the real Sandevistan, but it does not need the cyberware and has no duration or cooldown.

If the real Sandevistan cyberware is running, the same key ends it. Since 1.2 it does this by removing the Sandevistan status effects, so the game runs its own exit (cooldown, cleanup). That also ends cyberware mods that set the time dilation again every tick, for example the "Apogee" Sandevistan of Time Dilation Overhaul. Other slow motion (Kerenzikov, focus mode, other mods) is left alone.

```text
package/
  bin/x64/plugins/cyber_engine_tweaks/mods/SandevistanToggle/init.lua
```

## Requirements

- Cyberpunk 2077 2.31
- [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107) (built with 1.37.1)

Requirements are not bundled.

## Install

1. Install Cyber Engine Tweaks.
2. Copy the contents of `package/` into the game folder, so that `bin\x64\plugins\cyber_engine_tweaks\mods\SandevistanToggle\init.lua` exists.
3. Start the game and bind the hotkey in the CET overlay: Bindings > SandevistanToggle > "Toggle Sandevistan On/Off".

## Uninstall / roll back

1. Close the game.
2. Delete `bin\x64\plugins\cyber_engine_tweaks\mods\SandevistanToggle\`.
3. Saves are not affected: nothing is stored.

## Configuration

`dilation` at the top of `init.lua` (0.3) is the world speed while the slow motion is on.

## Known issues

- Music does not slow down with it; this mod changes time only.

## Changelog

| Version | Change |
|---|---|
| 1.2 (2026-11-02) | Also removes the Sandevistan status effects, so a running Time Dilation Overhaul "Apogee" can be ended |
| 1.1 (2026-10-24) | Switches on even during Kerenzikov, focus mode or other slow motion; a press during the fade-out switches back on; vanilla ease-out |
| 1.0 | First release |

Back to the [mod list](../../README.md).
