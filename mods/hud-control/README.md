# HUD Control (with Scanner Pins)

A Cyber Engine Tweaks window to hide HUD elements and set their opacity on top of Limited HUD, plus map pins that get world markers out to the scanner range. Single-player only.
Version: HUD Control 1.1.2 (window 1.1.1), Scanner Pins 1.1.1 | Built for game version 2.5 and Limited HUD 2.23.2 | Status: not run in game yet (no version of either part has an in-game test record)

## What and why

**HUD Control** adds a window "HUD Control" to the CET overlay for the HUD elements that Limited HUD manages: minimap, quest tracker, health bar, stamina bar, weapon roster and ammo, hotkeys (dpad and phone), input hints and the crouch indicator.

- Hide: a ticked element follows Limited HUD's rules; an unticked element stays hidden whatever Limited HUD decides. The mod wraps the game's own show and hide requests for these elements, so a show request is undone while the element is hidden, and on unhide the element goes back to what the game last asked for.
- Opacity: one preset slider for all elements (10 to 100 %), then one slider per element (0 to 100 %). Untouched elements keep Limited HUD's own opacity. The value is written into Limited HUD's own config object, so its fades land on the chosen value instead of fighting it.
- Scanner Pins settings (on or off, scanner range, near range) are mirrored in the same window.
- Choices are saved in `settings.json` next to the window's `init.lua` and applied again after every load. Only values changed in this window are saved.

**Scanner Pins** gives world map pins (vendors, ripperdocs, fixers, fast travel, metro, drop points, other points of interest, world encounters) their 3D world marker out to the chosen range (default 200 m; vanilla spawns them at 50 to 100 m). Past the "always visible" distance (default 50 m) these markers show only while the scanner is up. Tracked pins are never hidden. The minimap and the world map are not touched. It only ever hides markers; whether a pin shows at all is still decided by the game and by Limited HUD.

```text
package/
  bin/x64/plugins/cyber_engine_tweaks/mods/CyberslopHudControl/init.lua   the HUD Control window
  r6/scripts/CyberslopHudControl/CyberslopHudControl.reds                 hide and opacity on the HUD controllers
  r6/scripts/zz_CyberslopScannerPins/CyberslopScannerPins.reds             longer pin markers, scanner gate
  r6/tweaks/CyberslopScannerPins/CyberslopScannerPins.yaml                 marker range profiles 100 to 300 m
```

## Requirements

- Cyberpunk 2077 2.5
- [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107) (for the window)
- [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511)
- [TweakXL](https://www.nexusmods.com/cyberpunk2077/mods/4197) (for the Scanner Pins profiles)
- [Limited HUD](https://www.nexusmods.com/cyberpunk2077/mods/2592) for HUD Control: its redscript part compiles to nothing without Limited HUD, so the window then has no effect. Scanner Pins works without Limited HUD; with Limited HUD installed it needs version 2.23 or later.

Optional: [Mod Settings](https://www.nexusmods.com/cyberpunk2077/mods/4885) for the Scanner Pins settings menu (without it the defaults apply, and the HUD Control window can still change them).

Requirements are not bundled. Install them first.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `r6\scripts\CyberslopHudControl\CyberslopHudControl.reds` exists.
3. Start the game, load a save and open the CET overlay: the "HUD Control" window lists the HUD elements. Raise the scanner to see map pin markers farther away.

To use only Scanner Pins, copy only `r6\scripts\zz_CyberslopScannerPins\` and `r6\tweaks\CyberslopScannerPins\`.

## Uninstall / roll back

1. Close the game.
2. Delete:
   - `bin\x64\plugins\cyber_engine_tweaks\mods\CyberslopHudControl\` (also removes its `settings.json`)
   - `r6\scripts\CyberslopHudControl\`
   - `r6\scripts\zz_CyberslopScannerPins\`
   - `r6\tweaks\CyberslopScannerPins\`
3. Saves are not affected: neither part stores anything in the save.
4. To restore an unmodified game, verify the game files in your launcher.

## Configuration

HUD Control window: a tick box and an opacity slider per element, "All HUD elements" preset slider, "Use Limited HUD's own opacity for all", "Reset all to Mod Settings defaults".

Scanner Pins, in Mod Settings > Cyberslop Scanner Pins or in the HUD Control window:

| Setting | Default | Range |
|---|---|---|
| Enabled | on | |
| Scanner range (m) | 200 | 100 to 300, steps of 50 |
| Always visible within (m) | 50 | 0 to 100, steps of 10 |

A changed range applies to markers created after the change (move away and back, or reload).

## Changelog

| Version | Date | Game version | Change |
|---|---|---|---|
| HUD Control 1.1.2 | 2026-11-23 | 2.5 | The dpad's phone, car and radio icons show at the chosen opacity |
| Scanner Pins 1.1.1 | 2026-11-19 | 2.5 | Works with Limited HUD 2.23 (changed visibility function; markers no longer pop in and out) |
| HUD Control 1.1.1 | 2026-11-04 | 2.31 | Quest Compass controls removed from the window |
| HUD Control 1.1.0 | 2026-11-03 | 2.31 | Opacity sliders |
| Scanner Pins 1.1.0 | 2026-11-03 | 2.31 | Settings readable and writable from the HUD Control window |
| HUD Control 1.0.0 | 2026-11-03 | 2.31 | Hide HUD elements, Quest Compass and Scanner Pins controls |
| Scanner Pins 1.0.0 | 2026-11-02 | 2.31 | World markers for map pins out to the scanner range |

Back to the [mod list](../../README.md).
