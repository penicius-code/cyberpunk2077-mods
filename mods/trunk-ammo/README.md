# Trunk Ammo

Opening the trunk or hood of V's own car tops ammo up to the carry limit, paid in crafting components at the bench price. Single-player only.
Version 1.1.1 | Built for game version 2.5 | Status: not run in game yet (no version has an in-game test record)

## What and why

It replaces the free refill of Vehicle Ammo Refill with one that costs what crafting the ammo would cost.

- Open the trunk (or hood) of a car V owns: pistol, rifle, shotgun and sniper ammo are filled up to the carry limit, which is read live from the ammo item.
- Every round is pressed from crafting components with the same recipe, the same crafting cost reduction and the same material-refund perk roll as the crafting bench. The cost comes from the game's own crafting cost for the ammo item.
- A pressed batch that V cannot carry stays in the trunk as loose rounds and is free next time (kept in the save).
- The ammo recipes are tiered by calibre and also apply at the crafting bench: pistol 2 Common components for 40 rounds, rifle 2 Common for 20, shotgun shells 1 Uncommon for 12, sniper 1 Rare for 10. The pistol and rifle values repeat EconomyPunk's; this file loads after it, so these win.
- If another mod still adds free ammo after the refill, the mod shows a one-time warning.

```text
package/
  r6/scripts/zz_CyberslopTrunkAmmo/CyberslopTrunkAmmo.reds   refill, cost, loose rounds, log
  r6/tweaks/zz_CyberslopTrunkAmmo/ammo_recipes.yaml          ammo recipes by calibre
```

## Requirements

- Cyberpunk 2077 2.5
- [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511)
- [TweakXL](https://www.nexusmods.com/cyberpunk2077/mods/4197)
- [RedFileSystem](https://www.nexusmods.com/cyberpunk2077/mods/13378) (the log writer; the script does not compile without it)

Requirements are not bundled. Install them first.

## Install

1. Install the requirements above. Remove Vehicle Ammo Refill if you use it: both react to the trunk.
2. Copy the contents of `package/` into the game folder, so that `r6\scripts\zz_CyberslopTrunkAmmo\CyberslopTrunkAmmo.reds` exists.
3. Start the game, load a save and open the trunk of a car you own with ammo missing: the ammo is refilled and the components are taken.

## Uninstall / roll back

1. Close the game.
2. Delete:
   - `r6\scripts\zz_CyberslopTrunkAmmo\`
   - `r6\tweaks\zz_CyberslopTrunkAmmo\`
   - `r6\storages\CyberslopTrunkAmmo\` (log files)
3. Loose rounds left in the trunk are stored in the save and are lost without the mod. Ammo recipes at the bench go back to the game's (or another mod's) values.
4. To restore an unmodified game, verify the game files in your launcher.

## Known issues

- The mod always writes a playthrough log, one file per game launch: `r6\storages\CyberslopTrunkAmmo\trunk-N.txt`. It keeps the newest 30 files and deletes older ones at launch. There is no setting to switch it off; the switch is `TrunkLog.Logging()` in the script.
- The warning text for a leftover free-refill mod says to disable it "in Vortex"; any mod manager works.

## Changelog

| Version | Date | Game version | Change |
|---|---|---|---|
| 1.1.1 | 2026-11-23 | 2.5 | The playthrough log keeps only the newest 30 launch files |
| 1.1.0 | 2026-11-02 | 2.31 | Playthrough log, one file per launch |
| 1.0.0 | 2026-11-02 | 2.31 | Refill at the trunk, priced in components at the bench price |

Back to the [mod list](../../README.md).
