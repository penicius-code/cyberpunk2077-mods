# Tough Cars

Cars only blow up from explosives, not from bullets, punches or crashes, and flipped cars no longer burn out. Single-player only.
Version 1.0.0 | Built on game version 2.31 | Status: in use, no written test record

## What and why

In the base game every hit on a car (bullets, melee, Gorilla Arms punches, crashes) lowers its health. Once health reaches the decay threshold the car is disabled, burns and explodes, so a strong punch or a few bullets could get it there. This mod changes how much damage cars take:

- Hits that are not explosions do 10 % of their damage, and they never take a car's health below the decay threshold plus 1 %. Smoke and dents still show; the car never starts to burn.
- Explosions (grenades, launchers, rockets, a car blowing up next to it) are left as in the base game.
- A car left on its roof no longer gets the burn-out damage, and a flip no longer sets it about to explode.
- Cars with a hostile or aggressive NPC inside (chases, police pursuit, vehicle combat) are protected too, so pursuers can only be stopped with explosives. This can be switched off (see Configuration).

How it works: `@wrapMethod` on `DamageSystem.ProcessVehicleTarget`, `VehicleComponent.ApplyVehicleDOT` and `VehicleComponent.CheckAboutToExplodeStateOnFlip`. The health floor uses the same mechanism the game uses for quest cars that must not be destroyed. The three wrapped functions have the same signatures in the 2.5 scripts.

```text
package/
  r6/scripts/ToughCars/ToughCars.reds
```

## Requirements

- Cyberpunk 2077 (built on 2.31)
- [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511)

Requirements are not bundled.

## Install

1. Install redscript.
2. Copy the contents of `package/` into the game folder, so that `r6\scripts\ToughCars\ToughCars.reds` exists.

## Uninstall / roll back

1. Close the game.
2. Delete `r6\scripts\ToughCars\`.
3. Saves are not affected: the mod stores nothing.

## Configuration

Edit the functions in the `ToughCarsConfig` class at the top of `ToughCars.reds`:

| Function | Default | Meaning |
|---|---|---|
| `NonExplosiveDamage` | 0.1 | Share of non-explosive damage a car takes |
| `ExplosionDamage` | 1.0 | Share of explosion damage (1.0 = base game) |
| `FloorMargin` | 1.0 | Health % kept above the decay threshold by non-explosive hits |
| `ProtectPlayerVehicles` | true | V's own car and the car V sits in |
| `ProtectHostileVehicles` | true | Cars with a hostile NPC inside; false = base-game damage while they are inside |

## Changelog

| Version | Change |
|---|---|
| 1.0.0 (2026-10-29) | First version |

Back to the [mod list](../../README.md).
