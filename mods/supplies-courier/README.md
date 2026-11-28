# Supplies Courier

A CET window to order merc food, drinks and cigarettes in bulk, delivered by drone in about half an hour to a vendor locker or your apartment. Single-player only.
Version 1.0.1 | Built for game version 2.5 | Status: compiles on 2.5; not run in game yet; offline mock test 25 of 25

## What and why

CET window "NightDrop - 30-minute supply drones": five merc foods (street burrito, ramen, Hawt Dawg, nomad dried meat, MRE), five drinks (RealWater, Nicola, Matapang black coffee, Chromanticore, Broseph lager) and the three Dark Future cigarette packs, at street prices (8 to 45).
- Bulk per line: 6+ -5 %, 12+ -10 %, 24+ -15 %. Street Cred: -1 % per 2 cred, -25 % at 50.
- One drone carries 30 items: vendor locker 25 per drone (25-30 game minutes), apartment drop 60 (28-32).
- Collect locker orders next to any food, drink or market vendor, apartment orders near your stash.
- Hover tooltips, orders, Recall and delivery work as in [Pharm Courier](../pharm-courier/README.md); the order state is stored in the save.

Generated from Pharm Courier's code by a script, so it does not need Pharm Courier installed.

```text
package/
  bin/x64/plugins/cyber_engine_tweaks/mods/CyberslopSuppliesCourier/init.lua
  r6/scripts/zz_CyberslopSuppliesCourier/CyberslopSuppliesCourier.reds
```

## Requirements

- Cyberpunk 2077 2.5
- [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107) and [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511)
- Optional: [Dark Future](https://www.nexusmods.com/cyberpunk2077/mods/16300) for the cigarette packs; [Cashflow](../cashflow/README.md) books the payment

Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `bin\x64\plugins\cyber_engine_tweaks\mods\CyberslopSuppliesCourier\`, `r6\scripts\zz_CyberslopSuppliesCourier\` exist.

## Uninstall / roll back

1. Close the game.
2. Delete `bin\x64\plugins\cyber_engine_tweaks\mods\CyberslopSuppliesCourier\`, `r6\scripts\zz_CyberslopSuppliesCourier\`.

## Configuration

Hotkeys (unbound): show / hide the window, collect here.

## Changelog

| Version | Change |
|---|---|
| 1.0.1 (2026-11-26) | Regenerated from Pharm Courier 1.0.4 (names the script cannot translate are looked up in the window). |
| 1.0.0 (2026-11-26) | First version. |

Back to the [mod list](../../README.md).
