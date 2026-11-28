# Collapse Sound

System Collapse plays the Short Circuit zap instead of its own sound; optionally the target also gets Short Circuit's electrocution sparks. Single-player only.
Version 1.2.2 | Built for game version 2.5 | Status: compiles on 2.5; not run in game yet

## What and why

How it works:
- Sound: a wrap of `GameObject.StartStatusEffectSFX`. When the System Collapse sound event comes and the switch is on, it plays the Short Circuit zap instead (humans and androids each get their own variant). Effects without sounds pass straight through. The zap is a one-shot, so a real Short Circuit on the same NPC is not cut off.
- Short sparks: the same `status_electrocuted` visual that Short Circuit starts, started on a new System Collapse and stopped after a short burst.
- Whole-collapse sparks: every second the visual is started again while the collapse is still on the target.
- No TweakDB edits, no archive. Recasts on an already collapsed NPC don't spark again; the collapse's own visual stays.

```text
package/
  r6/scripts/CyberslopCollapseSound/CollapseSound.reds
```

## Requirements

- Cyberpunk 2077 2.5
- [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511), a build for 2.5
- Optional: [Mod Settings](https://www.nexusmods.com/cyberpunk2077/mods/4885) for the switches. Without it the sound swap is on and the sparks are off.

Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `r6\scripts\CyberslopCollapseSound\` exist.

## Uninstall / roll back

1. Close the game.
2. Delete `r6\scripts\CyberslopCollapseSound\`.

## Configuration

Mod Settings > Cyberslop Collapse Sound. All switches apply from the next cast.

| Setting | Default |
|---|---|
| Short Circuit sound for System Collapse | on |
| Short Circuit electric effect for System Collapse | off |
| Sparks for the whole collapse (needs the electric effect) | off |
| Debug log (CET `gamelog.log`) | off |

## Changelog

| Version | Change |
|---|---|
| 1.2.2 | "Debug log" setting, off by default. |
| 1.2.1 | A second sound wrap that only affected device traps removed; effects without sounds skip the wrap early. |
| 1.2.0 | Option: sparks for the whole collapse (about 9 s). |
| 1.1.0 | Option: Short Circuit's electrocution sparks when System Collapse lands. |
| 1.0.0 (2026-11-25) | First version: the sound swap. |

Back to the [mod list](../../README.md).
