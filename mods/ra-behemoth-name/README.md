# RA Behemoth Name

Renames the truck of RA Militech Behemoth Mobile Living Conversion from "Behemoth" to "RA Behemoth", so it can be told apart from the other Behemoths in Vanguard Auto and the vehicle call menu. Single-player only.
Version 1.0.0 | Built for game version 2.5 | Status: compiles on 2.5; no written in-game test record

## What and why

Two small files:
- a redscript file that registers the text "RA Behemoth" with Codeware's localization system;
- a TweakXL file that points the truck record's display name (`Vehicle.ra_behemoth_border_patrol`) at that text.

No other mod's files are edited.

```text
package/
  r6/scripts/CyberslopRABehemothName/CyberslopRABehemothName.reds
  r6/tweaks/zz_CyberslopRABehemothName/zz_CyberslopRABehemothName.yaml
```

## Requirements

- Cyberpunk 2077 2.5
- [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511), [TweakXL](https://www.nexusmods.com/cyberpunk2077/mods/4197) and [Codeware](https://www.nexusmods.com/cyberpunk2077/mods/7780)
- RA Militech Behemoth Mobile Living Conversion ([Nexus Mods, mod 27754](https://www.nexusmods.com/cyberpunk2077/mods/27754))

Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `r6\scripts\CyberslopRABehemothName\`, `r6\tweaks\zz_CyberslopRABehemothName\` exist.

## Uninstall / roll back

1. Close the game.
2. Delete `r6\scripts\CyberslopRABehemothName\`, `r6\tweaks\zz_CyberslopRABehemothName\`.

## Changelog

| Version | Change |
|---|---|
| 1.0.0 (2026-11-26) | First version. |

Back to the [mod list](../../README.md).
