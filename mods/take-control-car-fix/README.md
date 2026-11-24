# Take Control Car Fix

Repairs a car after the game's Take Control vehicle quickhack: trunk and hood open again, the engine keeps running after the release, and a vanilla autodrive that switches itself off gets one repair and retry. Single-player only.
Version 1.1.3 | Built for game version 2.5 | Status: compiles on 2.5, not yet play-tested; no written pass record for earlier versions

## What and why

Take Control (a vanilla vehicle quickhack, offered on most cars by mods such as Quickhack All Vehicles) leaves cars in a broken state. This redscript mod fixes what could be traced in the game scripts and logs what could not.

- **Trunk and hood** (a base-game bug, found in the 2.5 scripts): Take Control disables all six door slots of the car (four seats, trunk, hood). The release resets only the four seats, so trunk and hood stay disabled and the trunk can no longer be opened. The mod saves the trunk and hood state when control starts and puts it back when it ends.
- **Car switched off:** while Take Control runs, a car that is off is switched on every 0.5 s. Since 1.1.3, after the release the car is switched on again during 4 s (the game switches it off on release), unless V gets in or the car is destroyed.
- **Getting into a car V took control of:** stale remote-control flags and the trunk and hood state are cleared 0.5 s after V sits in the driver seat.
- **Vanilla autodrive** (K) that switches itself off within 6 s in such a car: one log line with the car's state, a full repair (also lingering forced brakes, unused seat reservations, engine on, car on) and one automatic retry 1 s later. The underlying cause is in native code and is not proven. Since 1.1.2 an autodrive start the game refuses is logged with the reason; nothing is changed then.

Engine and power go through Enhanced Vehicle System's functions when it is installed, so EVS's flags agree. The parts that use EVS or Auto Drive Enhanced only compile when those mods are installed. The [Vehicle Actions](../vehicle-actions/README.md) window calls this mod's repair from its repair button and shows its log lines.

```text
package/
  r6/scripts/zz_CyberslopHackedCarFix/HackedCarFix.reds
```

## Requirements

- Cyberpunk 2077 2.5
- [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511), a build for 2.5
- Optional: [Enhanced Vehicle System](https://www.nexusmods.com/cyberpunk2077/mods/11765) (17.8 used): engine and power go through it
- Optional: [Auto Drive Enhanced](https://www.nexusmods.com/cyberpunk2077/mods/23157): its own autodrive is told apart from the vanilla one

Requirements are not bundled.

## Install

1. Install redscript.
2. Copy the contents of `package/` into the game folder, so that `r6\scripts\zz_CyberslopHackedCarFix\HackedCarFix.reds` exists. The `zz_` prefix makes it load after EVS.
3. Start the game. Log lines are prefixed `[CSHackedCar]`.

## Uninstall / roll back

1. Close the game.
2. Delete `r6\scripts\zz_CyberslopHackedCarFix\`.
3. Saves: the mod keeps five fields in a car's saved state (taken-over flag, remote-control flag, trunk and hood state). A save loaded without the mod ignores them.

## Known issues

- The autodrive cause is not proven; the repair and retry are a best effort.

## Changelog

| Version | Change |
|---|---|
| 1.1.3 (2026-11-24) | Engine stays on after Take Control ends (4 s watch after the release) |
| 1.1.2 (2026-11-23) | A refused autodrive start is logged with the reason |
| 1.1.1 (2026-11-23) | Getter `CSHCF_TakenOver()` for the Vehicle Actions window |
| 1.1.0 (2026-11-20) | Car kept switched on while Take Control runs; repairs no longer cancel AI vehicle commands |
| 1.0.0 (2026-11-20) | Trunk and hood restored after Take Control; repair on entry; autodrive watch and one retry |

Back to the [mod list](../../README.md).
