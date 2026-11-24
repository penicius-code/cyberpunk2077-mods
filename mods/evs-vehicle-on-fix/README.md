# EVS Vehicle On Fix

An add-on for Enhanced Vehicle System: a car whose engine V switched off stays off after V gets out, and the car radio is muffled correctly in third person. Single-player only.
Version 1.1.0 | Built on game version 2.31 | Status: compiles (with and without EVS), not yet play-tested

## What and why

Two problems with Enhanced Vehicle System (EVS), both worked out from the scripts:

- **Radio muffle (1.0.0):** the base game sets a car to the "On" state when V takes the driver seat. EVS replaces that step and leaves the car at "Default", so the game stops muffling the radio in third person. While V drives with the engine running, this mod keeps the state "On" (checked on mount and every 0.5 s). Engine off through EVS puts it back to "Default", as EVS has it.
- **Engine comes back on (1.1.0):** V switches the engine off and gets out; the car rolls a little, stops, and the engine is running again. On exit two pairs of "no driver" / "driver ready" AI events reach the empty car: one from EVS and, after any autodrive use, one from Auto Drive Enhanced's workaround for cars moving on their own. "Driver ready" wakes the vehicle AI, which starts the engine behind EVS's back. For 8 s after V leaves the driver seat the mod checks every 0.25 s: if EVS's flag says off and the engine runs, it switches the engine off, sets the car back to "Default" and, at walking speed or less, brakes until the car stands. It only acts on cars V drove, and a new mount stops the check.

The cause in the second case was found by reading the scripts, not seen in game; each catch writes one `[EVSOnFix]` line to the log, which would confirm it. All EVS-dependent code only compiles when EVS is installed.

```text
package/
  r6/scripts/zz_EVSVehicleOnFix/EVSVehicleOnFix.reds
```

## Requirements

- Cyberpunk 2077 (built on 2.31)
- [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511)
- [Enhanced Vehicle System](https://www.nexusmods.com/cyberpunk2077/mods/11765) (17.8 used). Without it the mod compiles but does nothing.

Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `r6\scripts\zz_EVSVehicleOnFix\EVSVehicleOnFix.reds` exists. The `zz_` prefix makes it load after EVS.

## Uninstall / roll back

1. Close the game.
2. Delete `r6\scripts\zz_EVSVehicleOnFix\`.
3. Saves are not affected: the mod stores nothing.

## Known issues

- A car V bails out of at speed keeps rolling; the brake only acts at walking speed or below.

## Changelog

| Version | Change |
|---|---|
| 1.1.0 (2026-11-04) | Engine V switched off stays off after the exit |
| 1.0.0 (2026-10-28) | Car state kept "On" while V drives, for the third-person radio muffle |

Back to the [mod list](../../README.md).
