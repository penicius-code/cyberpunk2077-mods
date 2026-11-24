# Head Popper

A hotkey pops the head of the NPC under the crosshair. Single-player only.
Version 1.3 | Built on game version 2.31 | Status: tested in game on 2.31 (2026-10-24); not tested on 2.5

Published on Nexus Mods as "Head Popper CET": <https://www.nexusmods.com/cyberpunk2077/mods/28767>

## What and why

Press the hotkey and the NPC under the crosshair loses its head, whether it is alive, knocked out, defeated or already dead. If no NPC is directly under the crosshair, the one closest to it within 6 degrees and 15 m is used. NPCs the game protects (immortal or invulnerable, for example quest characters) are skipped with the message "Protected NPC. Head stays on."

How it works: the Cyber Engine Tweaks script picks the target through the game's targeting system and calls a small redscript helper. The helper kills the NPC if needed and applies a status effect defined in the TweakXL file. That status effect carries the game's own head dismemberment effector. All five TweakDB records are new; no base-game record is changed. The idea comes from the Head Popper mod by Mocarniejszy (SoundWAV); the code here is separate.

```text
package/
  bin/x64/plugins/cyber_engine_tweaks/mods/HeadPopAnyone/init.lua   hotkey and targeting
  r6/scripts/HeadPopAnyone/HeadPopAnyone.reds                       helper that applies the effect
  r6/tweaks/HeadPopAnyone/HeadPopAnyone.yaml                        the status effect records
```

## Requirements

| Requirement | Tested with | Link |
|---|---|---|
| Cyberpunk 2077 | 2.31 | |
| Cyber Engine Tweaks | 1.37.1 | [Nexus Mods, mod 107](https://www.nexusmods.com/cyberpunk2077/mods/107) |
| redscript | 0.5.31 | [Nexus Mods, mod 1511](https://www.nexusmods.com/cyberpunk2077/mods/1511) |
| TweakXL | 1.11.3 | [Nexus Mods, mod 4197](https://www.nexusmods.com/cyberpunk2077/mods/4197) |

Requirements are not bundled. Install them first.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `bin\x64\plugins\cyber_engine_tweaks\mods\HeadPopAnyone\init.lua` exists.
3. Start the game and bind the hotkey in the CET overlay: Bindings > HeadPopAnyone > "Pop Head". It is unbound after install.

## Uninstall / roll back

1. Close the game.
2. Delete:
   - `bin\x64\plugins\cyber_engine_tweaks\mods\HeadPopAnyone\`
   - `r6\scripts\HeadPopAnyone\`
   - `r6\tweaks\HeadPopAnyone\`
3. Saves are not affected: the mod writes no files and stores nothing in saves.

## Configuration

Constants at the top of `init.lua`:

| Name | Default | Meaning |
|---|---|---|
| `MAX_RANGE` | 15.0 | Maximum range in metres |
| `MAX_ANGLE` | 6.0 | Degrees from the crosshair when no NPC is directly under it |
| `SKIP_PROTECTED` | true | Leave immortal or invulnerable NPCs alone |
| `DEBUG` | false | Print targeting details to the CET console |

## Known issues

- CET hotkeys fire when the key is released, not when it is pressed.

## Changelog

| Version | Change |
|---|---|
| 1.3 (2026-10-24) | Only the NPC under or closest to the crosshair; protected NPCs skipped with a message; no console output unless `DEBUG` is on |
| 1.2 | Hotkey is a CET binding ("Pop Head") instead of a fixed key |
| 1.1 | Crosshair target first; range lowered from 100 m to 15 m |
| 1 | First release |

Back to the [mod list](../../README.md).
