# Gamma Slider

Change the game's gamma from a Cyber Engine Tweaks window or with hotkeys, without the pause menu. Single-player only.
Version 1.1.0 | Built on game version 2.31 | Status: 1.0.0 was loaded in game on 2.31, with no written test result; 1.1.0 has no in-game test record

## What and why

Dark interiors and bright streets can need different brightness, and the brightness screen is several menus deep. The value that screen edits is the engine setting `/video/display/Gamma` (0.5 to 2.0, vanilla default 1.0). The engine applies a change to it at once, so this mod writes it directly and asks the game to save its user settings 1.5 s after the last change.

- Window "Gamma" in the CET overlay: slider, minus and plus buttons, "Reset to" the reset value, "Game default", and "Use current as reset".
- Hotkeys "Gamma up (one step)", "Gamma down (one step)" and "Gamma reset (to the reset value)". They are hotkey bindings, so key combinations such as Ctrl + Numpad + work. Each hotkey change shows the new value on screen for a moment.
- Day and night (1.1.0, off by default): two stored gamma values, switched automatically by the in-game hour. While it is on, every change is stored as the value of the current period, so you tune night at night and day by day.

```text
package/
  bin/x64/plugins/cyber_engine_tweaks/mods/GammaSlider/init.lua
```

## Requirements

- Cyberpunk 2077 (built on 2.31; not tested on 2.5)
- [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107)

Requirements are not bundled. Install them first.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `bin\x64\plugins\cyber_engine_tweaks\mods\GammaSlider\init.lua` exists.
3. Start the game and open the CET overlay: the "Gamma" window shows the current value. Bind the hotkeys in CET > Bindings > GammaSlider.

## Uninstall / roll back

1. Close the game.
2. Delete `bin\x64\plugins\cyber_engine_tweaks\mods\GammaSlider\` (also removes `config.json` and `GammaSlider.log`).
3. Gamma stays at the last value set, because it is the game's own setting. Change it back in Settings > Video > Brightness.
4. Saves are not affected.

## Configuration

In the window, saved in `config.json` next to `init.lua`:

| Option | Default | Range |
|---|---|---|
| Hotkey step | 0.05 | |
| Show the value on screen after a hotkey | on | |
| Day / night gamma (switches by game time) | off | |
| Day gamma | 1.0 | 0.5 to 2.0 |
| Night gamma | 1.2 | 0.5 to 2.0 |
| Night starts (hour) | 20 | 0 to 23 |
| Day starts (hour) | 6 | 0 to 23 |

The reset value (default 1.0) is set with "Use current as reset" and stored as `resetValue`.

## Changelog

| Version | Date | Game version | Change |
|---|---|---|---|
| 1.1.0 | 2026-10-28 | 2.31 | Optional day and night gamma by game hour |
| 1.0.0 | 2026-10-28 | 2.31 | Window, hotkeys, saved user settings |

Back to the [mod list](../../README.md).
