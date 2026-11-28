# Toast Hold

Notifications stay on screen longer: quest, district, shard, loot, money, text and other mods' on-screen messages get extra seconds (default 6). Single-player only.
Version 1.0.1 | Built for game version 2.5 | Status: compiles on 2.5; no written in-game test record

## What and why

Why a plain duration change does nothing: the game's notifications are whole animations that fade themselves out after about 5 seconds; the queue time only decides how long the slot is kept. So the mod holds each animation at a point where nothing is mid-fade, then lets it finish:

| Notification | How |
|---|---|
| Quest new / updated / failed, district banner, NCPD job done, new activity, shard | played to its hold marker, held, then the rest of the animation |
| Quest completed, quickhack reward | the same, with the hold capped to fit the game's fixed slot |
| Item received | held at the start of the outro; queue time + hold |
| Money | the outro starts after the hold |
| Incoming texts | shown 6.7 s + hold |
| Other mods' on-screen and warning messages | their timeout + hold |
| Police-style messages | the vanilla animation paused for the hold |

XP, level-up, zone alerts and crafting notifications are unchanged. All changes are in one redscript file; no other mod's files are edited. (On the author's PC an extra local edit also lengthens CyberBane's phone texts; that edit belongs to another author's mod and is not part of this package.)

```text
package/
  r6/scripts/zz_CyberslopToastHold/CyberslopToastHold.reds
```

## Requirements

- Cyberpunk 2077 2.5
- [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511), a build for 2.5
- Optional: [Mod Settings](https://www.nexusmods.com/cyberpunk2077/mods/4885) to change the extra time (default 6 s without it)

Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `r6\scripts\zz_CyberslopToastHold\` exist.

## Uninstall / roll back

1. Close the game.
2. Delete `r6\scripts\zz_CyberslopToastHold\`.

## Configuration

Mod Settings > Cyberslop Toast Hold > "Extra seconds on screen": 0 to 12, default 6; 0 = the game's own timing. A change applies to the next notifications.

## Changelog

| Version | Change |
|---|---|
| 1.0.1 (2026-11-27) | Quest notifications are held where nothing is mid-fade; police-style messages pause the vanilla animation instead of restarting it; a setting change applies to the next notifications; a notification never holds longer than its slot; money notifications hold reliably. |
| 1.0.0 (2026-11-26) | First version. |

Back to the [mod list](../../README.md).
