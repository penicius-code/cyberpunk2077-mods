# Vehicle Savable

Saves made while driving certain add-on cars and bikes load correctly, instead of putting V on the car roof. Single-player only.
Version 1.0.0 | Built on game version 2.31 | Status: not yet play-tested

## What and why

Every base-game player vehicle record has `savable = true`. Some ownable add-on vehicles from other mods copy a base-game traffic record instead, which has no such flag, so the car is never written into the save. A save made while driving one of them loads with V standing on the car roof. This TweakXL file sets `savable: true` on the 55 affected records:

- Standalone - Rayfield Caliburn Legacy ([Nexus Mods, mod 24222](https://www.nexusmods.com/cyberpunk2077/mods/24222))
- Apollo Scout Tactical
- Honda NSX Liberty Walk
- the SDH0 Color Pack car
- 51 Arch V4 bikes

Only player-ownable vehicles are listed. Add-on cars that already copy a player record inherit the flag and are left alone. Vehicles that mods spawn without V owning them are left out on purpose, because saving them could leave copies in the world. No file of another mod is changed.

```text
package/
  r6/tweaks/zz_CyberslopVehicleSavable/vehicle_savable.yaml
```

## Requirements

- Cyberpunk 2077 (built on 2.31)
- [TweakXL](https://www.nexusmods.com/cyberpunk2077/mods/4197)
- At least one of the vehicle mods above. For vehicle mods you do not have, the matching lines have no record to act on; TweakXL may report them in its log.

Requirements are not bundled.

## Install

1. Install TweakXL.
2. Copy the contents of `package/` into the game folder, so that `r6\tweaks\zz_CyberslopVehicleSavable\vehicle_savable.yaml` exists.

## Uninstall / roll back

1. Close the game.
2. Delete `r6\tweaks\zz_CyberslopVehicleSavable\`.
3. The mod adds no data of its own to saves; it only lets the game write these vehicles the way it writes its own cars. What happens to such a save after removing the mod was not tested.

## Known issues

- Saves made before installing the mod while driving one of these vehicles still load wrong: the car is not in them.

## Changelog

| Version | Change |
|---|---|
| 1.0.0 (2026-11-08) | First version |

Back to the [mod list](../../README.md).
