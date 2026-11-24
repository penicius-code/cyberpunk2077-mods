# Drop Current Weapon

A hotkey drops the weapon in V's hands into the world, and an optional add-on drops the old weapon when a picked-up weapon replaces it. Single-player only.
World Drop 1.1.0, AutoDrop 1.1.1 | World Drop built on 2.31, AutoDrop 1.1.1 written against the 2.5 scripts | Status: World Drop 1.1.0 and AutoDrop 1.1.0 tested in game on 2.31 (2026-10-24); AutoDrop 1.1.1 not yet play-tested (offline mock passed); the No Notifications file not run in game

Published on Nexus Mods as "Drop Current Weapon - CET - Immersive Hotkey Drop Auto Swap" (version 1.1.0 there): <https://www.nexusmods.com/cyberpunk2077/mods/27211>

## What and why

Two small Cyber Engine Tweaks mods.

- **World Drop** (`DropCurrentWeapon_WorldDrop`): press the hotkey and the weapon in V's hands lands on the ground, where it can be picked up again. The weapon is unequipped first (the game never drops an item that is still in the hands) and then dropped through the game's own Drop item action, the one the inventory uses. A small on-screen message confirms it.
- **AutoDrop** (`AutoDropWeaponOnPickupEquip`, optional): when V picks up a weapon from the ground and equips it, the weapon V held before is dropped. A reload or a normal weapon switch never drops anything. Since 1.1.1 a weapon is only dropped if it really lost its weapon slot: with a free slot the game puts the new weapon there and keeps the old one, so nothing drops. A holstered weapon is kept too.

Both never drop fists or cyberware arms (Gorilla Arms, Mantis Blades, Monowire, Projectile Launch System), quest items, or iconic weapons.

```text
package/
  bin/x64/plugins/cyber_engine_tweaks/mods/DropCurrentWeapon_WorldDrop/init.lua    World Drop
  bin/x64/plugins/cyber_engine_tweaks/mods/AutoDropWeaponOnPickupEquip/init.lua    AutoDrop (optional)
variants/no-notifications/
  bin/x64/plugins/cyber_engine_tweaks/mods/DropCurrentWeapon_WorldDrop/init.lua    World Drop without the on-screen message
```

## Requirements

- Cyberpunk 2077 (World Drop built on 2.31; AutoDrop 1.1.1 follows the 2.5 weapon slot rules)
- [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107) (built with 1.37.1)

Requirements are not bundled.

## Install

1. Install Cyber Engine Tweaks.
2. Copy the contents of `package/` into the game folder, so that `bin\x64\plugins\cyber_engine_tweaks\mods\DropCurrentWeapon_WorldDrop\init.lua` exists. Leave out the `AutoDropWeaponOnPickupEquip` folder if you do not want the add-on.
3. Optional: to hide the on-screen message, copy `variants/no-notifications/` over it, so that its `init.lua` replaces the World Drop one.
4. Start the game and bind the hotkey in the CET overlay: Bindings > DropCurrentWeapon_WorldDrop > "Drop currently equipped weapon to the ground (world)". AutoDrop has no key.

## Uninstall / roll back

1. Close the game.
2. Delete `bin\x64\plugins\cyber_engine_tweaks\mods\DropCurrentWeapon_WorldDrop\` and, if installed, `bin\x64\plugins\cyber_engine_tweaks\mods\AutoDropWeaponOnPickupEquip\`.
3. Saves are not affected: the mods write no files and store nothing in saves.

## Configuration

`cfg` tables at the top of each `init.lua`:

| Mod | Setting | Default | Meaning |
|---|---|---|---|
| World Drop | `protectQuestItems`, `protectIconics` | true | Never drop quest items or iconic weapons |
| World Drop | `notify` | true (false in the No Notifications file) | On-screen message |
| World Drop | `debug` | false | Extra lines in the CET console |
| AutoDrop | `protectQuestItems`, `protectIconics` | true | As above |
| AutoDrop | `pickupWindow` | 1.0 s | Time between a weapon entering the inventory and it being in the hands |
| AutoDrop | `dropHolstered` | false | Also drop a holstered weapon that the pickup pushed out of its slot |
| AutoDrop | `debugPrint` | false | Debug lines; can also be toggled with the unbound CET input "ADWOP: Toggle debug logging" |

## Known issues

- With all three weapon slots full and the old weapon holstered, the replaced weapon goes to the backpack, as in the base game (AutoDrop keeps holstered weapons by default).

## Changelog

| Version | Change |
|---|---|
| AutoDrop 1.1.1 (2026-11-23) | Drops only when the old weapon lost its weapon slot; holstered weapons kept; idle check limited to 4 times a second |
| 1.1.0 (2026-10-24) | Both files rebuilt: the drop now works (1.0.1 called a game function that does not exist); unequip first, then the inventory's drop action; fists and cyberarms never dropped; iconic and quest items protected; AutoDrop rewritten around inventory events; No Notifications file added |
| 1.0.1 | First release (the drop did not work) |

Back to the [mod list](../../README.md).
