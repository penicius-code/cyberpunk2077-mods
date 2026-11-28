# Auto Overclock

Executing a quickhack that is greyed out only for lack of RAM switches Overclock on, uploads the quickhack in the same press (the missing RAM is paid with health, the vanilla Overclock rule) and switches Overclock off 3 seconds later. Single-player only.
Version 1.0.2 | Built for game version 2.5 | Status: 1.0.1 run in game: Overclock switched on but the quickhack was not sent in the same press; fixed in 1.0.2, which is not run in game yet

## What and why

Rules:
- Only a pure RAM lock triggers it. Cooldowns, uploads in progress, ICE and other locks are left alone.
- Not triggered when Overclock is already on or cannot start (no Overclock perk or cyberdeck, an overheat lock), or when its charge would not last the 3 second window.
- Not triggered when the health payment would leave V below 25 % of max health; the quickhack then stays locked as in vanilla. Every further quickhack inside the window must keep the same floor.
- Every further quickhack sent while auto Overclock is on restarts the 3 second window (capped to the charge left).
- Overclock you switch on yourself is never switched off. Toggling Overclock by hand during the window hands it back to you.

How it works: a wrap of the quickhack list's vanilla execute call switches Overclock on through the game's own toggle, clears the lock on the selected entry and sends the quickhack; the send retries on real-time ticks for up to 1 second, because the Overclock state is not visible in the frame it starts. A wrap of `ScriptedPuppet.TranslateChoicesIntoQuickSlotCommands` keeps the action of a RAM-locked entry, which vanilla leaves empty. The off timer runs in real time, so the slowed scanner time does not stretch it.

```text
package/
  r6/scripts/CyberslopAutoOverclock/AutoOverclock.reds
```

## Requirements

- Cyberpunk 2077 2.5
- [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511), a build for 2.5
- Optional: [Mod Settings](https://www.nexusmods.com/cyberpunk2077/mods/4885) for the debug log switch
- Works with Overclock Overheat (its partial-charge setting keeps unused charge) and with mods that call the vanilla execute path (Overclock hold, quickhack hotkeys)

Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `r6\scripts\CyberslopAutoOverclock\` exist.

## Uninstall / roll back

1. Close the game.
2. Delete `r6\scripts\CyberslopAutoOverclock\`.

## Configuration

Mod Settings > Cyberslop Auto Overclock > Debug > "Debug log" (off by default): every decision goes to CET's `gamelog.log` as `[AutoOverclock]` lines. The 3 second window and the 25 % health floor are constants in the script (`CsAutoOc.Grace()`, `CsAutoOc.HealthFloor()`).

## Changelog

| Version | Change |
|---|---|
| 1.0.2 (2026-11-28) | One press only switched Overclock on and never sent the quickhack (seen in game with 1.0.1). The send now retries on real-time ticks for up to 1 s; a second press on the same quickhack and target cancels it, so nothing uploads twice. |
| 1.0.1 (2026-11-28) | The 25 % health floor guards every quickhack while auto Overclock is on (1.0.0 checked only the first); the off timer is capped to the charge left; debug log setting. |
| 1.0.0 (2026-11-28) | First version. |

Back to the [mod list](../../README.md).
