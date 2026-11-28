# Parts Courier

A CET window to order crafting components in bulk, with bulk prices and a Street Cred discount, delivered by drone to a dealer locker or your apartment. Single-player only.
Version 1.0.1 | Built for game version 2.5 | Status: compiles on 2.5; not run in game yet; offline mock test 25 of 25

## What and why

CET window "Scrapline Parts Exchange - drone freight": the nine crafting components (weapon and gear Common to Legendary, quickhack Uncommon to Legendary) at list prices of 25 / 50 / 120 / 300 / 750.
- Bulk per line: 25+ -5 %, 50+ -10 %, 100+ -15 %, 250+ -20 % (up to 999). Street Cred: -1 % per 2 cred, -25 % at 50.
- One drone carries 200 units: dealer locker 150 per drone (2:00-2:30 game hours), apartment drop 400 (2:30-3:00).
- Collect locker orders next to any tech, junk, gun or armor dealer, apartment orders near your stash.
- Hover tooltips, orders, Recall and delivery work as in [Pharm Courier](../pharm-courier/README.md); the order state is stored in the save.

Parts Courier is generated from Pharm Courier's code by a script (same order, delivery and pickup system, its own catalogue and names), so it does not need Pharm Courier installed.

```text
package/
  bin/x64/plugins/cyber_engine_tweaks/mods/CyberslopPartsCourier/init.lua
  r6/scripts/zz_CyberslopPartsCourier/CyberslopPartsCourier.reds
```

## Requirements

- Cyberpunk 2077 2.5
- [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107) and [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511)
- Optional: [Cashflow](../cashflow/README.md) books the payment

Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `bin\x64\plugins\cyber_engine_tweaks\mods\CyberslopPartsCourier\`, `r6\scripts\zz_CyberslopPartsCourier\` exist.

## Uninstall / roll back

1. Close the game.
2. Delete `bin\x64\plugins\cyber_engine_tweaks\mods\CyberslopPartsCourier\`, `r6\scripts\zz_CyberslopPartsCourier\`.

## Configuration

Hotkeys (unbound): show / hide the window, collect here.

## Changelog

| Version | Change |
|---|---|
| 1.0.1 (2026-11-26) | Regenerated from Pharm Courier 1.0.4 (names the script cannot translate are looked up in the window). |
| 1.0.0 (2026-11-26) | First version. |

Back to the [mod list](../../README.md).
