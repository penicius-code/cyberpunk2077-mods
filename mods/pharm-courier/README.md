# Pharm Courier

A CET window to order the whole merc pharmacy in bulk, with bulk prices and a Street Cred discount, delivered by drone to a clinic locker or your apartment. Single-player only.
Version 1.0.4 | Built for game version 2.5 | Status: installed in my game; no written in-game test record; offline mock test 25 of 25

## What and why

CET window "Afterhours Pharm - drone courier" (with the CET overlay open, or kept up by a hotkey):
- Every Merc Stims item by group, Clinic Meds' seven cures, Wannabe Edgerunner's neuroblockers, the Dark Future and Injuries medicines, with how many you carry and the list price. Hover a row for its benefits and costs.
- Bulk rate per line: 1-9 list price, 10+ -6 %, 20+ -10 %, 30+ -14 %, 50+ -18 % (up to 99). Street Cred: -1 % per 2 cred, -25 % at 50. Grey-market lines need Street Cred 20.
- Delivery: clinic locker (250 per drone, lands in 2:00-2:30 game hours) or apartment drop (600 per drone, 2:30-3:00). One drone carries 40 units.
- Drones in the air with their countdown in game time, and Recall (goods refunded, drone fee kept).
- Collect: clinic orders near any medic or ripperdoc, apartment orders near your stash.

Orders, payment and delivery are stored in the save. Top-tier items are sold only here.

The redscript part holds the catalogue, orders and timers; the Lua part is the window.

```text
package/
  bin/x64/plugins/cyber_engine_tweaks/mods/CyberslopPharmCourier/init.lua
  r6/scripts/zz_CyberslopPharmCourier/CyberslopPharmCourier.reds
```

## Requirements

- Cyberpunk 2077 2.5
- [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107) and [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511)
- [Merc Stims](../merc-stims/README.md) (the items)
- Optional: [Clinic Meds](../clinic-meds/README.md), Dark Future, Injuries and Wannabe Edgerunner for their items; [Cashflow](../cashflow/README.md) books the payment as Medical

Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `bin\x64\plugins\cyber_engine_tweaks\mods\CyberslopPharmCourier\`, `r6\scripts\zz_CyberslopPharmCourier\` exist.

## Uninstall / roll back

1. Close the game.
2. Delete `bin\x64\plugins\cyber_engine_tweaks\mods\CyberslopPharmCourier\`, `r6\scripts\zz_CyberslopPharmCourier\`.

## Configuration

Hotkeys (unbound): show / hide the window, collect here.

## Changelog

| Version | Change |
|---|---|
| 1.0.4 (2026-11-26) | Item names the script could not translate (non-Merc Stims items) are looked up in the window, also in order lists. |
| 1.0.3 (2026-11-26) | The whole pharmacy: Clinic Meds, rebalanced neuroblockers, Dark Future and Injuries medicines; top-tier items sold only here. |
| 1.0.2 (2026-11-26) | Merc Stims humanity items orderable. |
| 1.0.1 (2026-11-26) | Hover tooltips with each item's benefits and costs; wider name column; Street Cred discount -1 % per 2 cred, up to -25 %. |
| 1.0.0 (2026-11-26) | First version. |

Back to the [mod list](../../README.md).
