# Vehicle Actions

A Cyber Engine Tweaks window with buttons for the car you sit in or aim at: locks, engine, power, lights, doors, windows, trunk, hood, and every Enhanced Vehicle System key action. Single-player only.
Version 1.6.1 | Built for game version 2.5 (1.0.0 on 2.31) | Status: 1.0.0 confirmed working in game (2026-11-05, 2.31); 1.1.0 to 1.6.1 not yet play-tested

## What and why

The window "Vehicle Actions" shows with the CET overlay. Its target is the car V sits in, else the car V aims at, else the last target within 30 m; "Pin this vehicle" keeps a target. It started as a separate window for the vehicle part of Appearance Menu Mod's Target Actions (it uses the same game calls; AMM is not needed) and grew to cover every key action of Enhanced Vehicle System (EVS), so those actions no longer need keyboard keys.

Sections:
- **Locks:** lock all doors or open the locks, with the current state.
- **Engine and power:** on and off through EVS's own functions, so EVS's engine flag stays right; without EVS the vanilla calls. "Headlights off while parked". Checkboxes "Start engine when I get in (all cars)" and "Engine and power off when I get out (all cars)", both off by default.
- **Lights:** all lights, headlights, high beams, interior lights, roof light and utility lights; EVS custom light colours per type.
- **Crystal dome** (cars that have one): on or off, "Clear glass now", and "Keep glass clear (engine start, in car)".
- **Doors and windows** per seat, trunk, hood, spoiler, crystal coat, and police lights, siren and signal on police cars.
- **Take Control repair:** a status row and a repair button (trunk, autodrive) for a car the game's Take Control quickhack left broken. With [Take Control Car Fix](../take-control-car-fix/README.md) installed it calls that mod's repair; otherwise it does the same steps itself.
- **EVS check:** a diagnostic button that writes what CET can read of EVS on the target car to `evscheck.log`.

On patch 2.5, CET 1.38.1 reads every script field as nil. Since 1.6.0 all field reads and writes go through a small redscript bridge (`CSVABridge.reds`); its EVS part only compiles when EVS is installed.

```text
package/
  bin/x64/plugins/cyber_engine_tweaks/mods/CyberslopVehicleActions/init.lua   the window
  r6/scripts/zz_CyberslopVehicleActions/CSVABridge.reds                       field bridge for CET on 2.5
```

## Requirements

| Requirement | Version | Link |
|---|---|---|
| Cyberpunk 2077 | 2.5 | |
| Cyber Engine Tweaks | 1.38.1 used | [Nexus Mods, mod 107](https://www.nexusmods.com/cyberpunk2077/mods/107) |
| redscript | a build for 2.5 | [Nexus Mods, mod 1511](https://www.nexusmods.com/cyberpunk2077/mods/1511) |
| Enhanced Vehicle System (optional) | 17.8 | [Nexus Mods, mod 11765](https://www.nexusmods.com/cyberpunk2077/mods/11765) |
| Take Control Car Fix (optional) | 1.1.1 or later | [this collection](../take-control-car-fix/README.md) |

Without EVS the window uses vanilla calls where it can; rows that only EVS provides are not shown. Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `bin\x64\plugins\cyber_engine_tweaks\mods\CyberslopVehicleActions\init.lua` and `r6\scripts\zz_CyberslopVehicleActions\CSVABridge.reds` exist.
3. Start the game and open the CET overlay: the window "Vehicle Actions" shows.

### Optional: free EVS's keyboard keys

Because the window covers every EVS action, EVS's keyboard keys can be removed. This is a change in EVS's own input file (`r6\input\Enhanced Vehicle System.xml`), which is not included here. On the author's setup these keyboard mappings were removed from that file: Numpad 2 (doors), Numpad 4 (dome, roof and interior lights), the Numpad 2+2 chord (hood, trunk, spoiler) and the Numpad 1+1 chord (custom colours). Numpad 1 (engine, power) and Numpad 3 (windows) and all controller combinations were kept. Make a backup of the file first; reinstalling or updating EVS restores its keys. The window works the same with or without this change.

## Uninstall / roll back

1. Close the game.
2. Delete `bin\x64\plugins\cyber_engine_tweaks\mods\CyberslopVehicleActions\` and `r6\scripts\zz_CyberslopVehicleActions\`.
3. Saves are not affected by this mod. (Take Control Car Fix, if installed, keeps a few fields in the car's saved state; see its README.)

## Configuration

Window checkboxes "Start engine when I get in", "Engine and power off when I get out" and "Keep glass clear" are saved to `settings.json` in the mod folder. CET hotkeys, all unbound by default (Bindings > CyberslopVehicleActions): "Show / hide window", the Take Control repair, "Toggle auto engine start", "Toggle auto engine off".

## Known issues

- The mod writes files in its own folder: `settings.json`; `evscheck.log` (the EVS check button, and a short timeline after every engine button press); `hackedcar.log` (lines from Take Control Car Fix, when installed). The two log files are not trimmed.
- Starting a car's engine from outside: on the author's setup the car sometimes switched off again a few seconds later; the cause is not found. The engine timeline in `evscheck.log` exists to track this.

## Changelog

| Version | Change |
|---|---|
| 1.6.1 (2026-11-23) | The Take Control status row reads Take Control Car Fix's getter; "Toggle auto engine start" no longer starts the car V already sits in |
| 1.6.0 (2026-11-21) | Redscript bridge for all field reads and writes (CET 1.38.1 on 2.5 reads fields as nil); lights section always shown, as checkboxes; engine buttons log an 8 s timeline |
| 1.5.1 | "EVS check" diagnostic button |
| 1.5.0 | "Engine and power off when I get out" |
| 1.4.0 (2026-11-20) | "Start engine when I get in"; EVS power |
| 1.3.1 | Shows Take Control Car Fix's log lines and writes them to `hackedcar.log` |
| 1.3.0 (2026-11-20) | Take Control status row and repair button |
| 1.2.0 | Relaxed driving pose; reverted |
| 1.1.0 (2026-11-05) | Every EVS key action in the window: lights, custom colours, crystal dome, spoiler, crystal coat, police lights |
| 1.0.0 (2026-11-04) | First version: locks, engine and power through EVS, doors, windows, trunk, hood, pin |

Back to the [mod list](../../README.md).
