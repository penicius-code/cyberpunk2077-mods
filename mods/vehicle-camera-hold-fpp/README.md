# Vehicle Camera Hold FPP

Holding the vehicle camera button jumps straight back to first person; a tap cycles the views as before. Single-player only.
Version 1.1.0 | Built for game version 2.5 (1.0.0 was for 2.31) | Status: compiles on 2.5, not yet play-tested; 1.0.0 has no written test record

## What and why

In a vehicle the camera button (Q on keyboard, D-pad right on a controller) cycles through the third-person views, so getting back to first person can take several presses. With this mod, holding the button for 0.5 s jumps straight to first person from any third-person view. A tap works as before. It works while driving, as a passenger and in driver combat. During autodrive the base-game hold (cinematic camera) is kept, and nothing happens while an item wheel is open.

How it works: an Input Loader file adds a hold action `VehCamHoldFPP` on the camera button to five vehicle input contexts. The redscript file wraps the game's vehicle camera input handling, switches to first person on the hold and swallows the button release that follows, so the view does not cycle on.

```text
package/
  r6/input/VehicleCameraHoldFPP.xml                           the hold action
  r6/scripts/VehicleCameraHoldFPP/VehicleCameraHoldFPP.reds   the camera switch
```

## Requirements

- Cyberpunk 2077 2.5
- [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511) (compiled with 0.5.32)
- [Input Loader](https://www.nexusmods.com/cyberpunk2077/mods/4575)

Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `r6\input\VehicleCameraHoldFPP.xml` and `r6\scripts\VehicleCameraHoldFPP\VehicleCameraHoldFPP.reds` exist.

## Uninstall / roll back

1. Close the game.
2. Delete `r6\input\VehicleCameraHoldFPP.xml` and `r6\scripts\VehicleCameraHoldFPP\`.
3. Saves are not affected: the mod stores nothing.

## Changelog

| Version | Change |
|---|---|
| 1.1.0 (2026-11-17) | Port to game version 2.5 (the camera input function takes the state context now); no hold while an item wheel is open |
| 1.0.0 (2026-10-28) | First version, for 2.31 |

Back to the [mod list](../../README.md).
