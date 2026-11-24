# Calm Exit

Getting out of a car outside combat no longer draws a weapon. Single-player only.
Version 1.0.0 | Built for game version 2.5 | Status: compiles on 2.5, not yet play-tested

## What and why

In the base game (2.5) two kinds of vehicle exit always draw V's last used weapon, in combat or not:
- the jump-out exit (double tap the exit key, needs the Reflexes perk), which with Gorilla Arms, Mantis Blades or Monowire as the last weapon even draws the arms mid-exit;
- the exit from a heavily damaged car.

With this mod both draw only when V is in combat or had a gun out in the car (driver combat). Otherwise V's hands stay empty. The jump-out itself (impulse, roll, knockdown protection) is unchanged, and the other exits stay as they are.

How it works: `@wrapMethod` on `CoolExitingEvents.OnUpdate` and `CoolExitingEvents.OnExit`, and one `@replaceMethod` on `CombatExitingEvents.OnExit` (its base-game body is two lines).

```text
package/
  r6/scripts/zz_CyberslopCalmExit/CyberslopCalmExit.reds
```

## Requirements

- Cyberpunk 2077 2.5
- [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511), a build for 2.5

Requirements are not bundled.

## Install

1. Install redscript.
2. Copy the contents of `package/` into the game folder, so that `r6\scripts\zz_CyberslopCalmExit\CyberslopCalmExit.reds` exists.

## Uninstall / roll back

1. Close the game.
2. Delete `r6\scripts\zz_CyberslopCalmExit\`.
3. Saves are not affected: the mod stores nothing.

## Compatibility

| Mod | Status | Notes |
|---|---|---|
| Mods that also replace `CombatExitingEvents.OnExit` | conflicts | Only one replacement can win; none was found on the author's setup |
| Always First Equip | works | After a calm jump-out the next manual draw skips that mod's first-equip animation once |

## Changelog

| Version | Change |
|---|---|
| 1.0.0 (2026-11-22) | First version |

Back to the [mod list](../../README.md).
