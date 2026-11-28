# ForceStun

A hotkey stuns the NPC under the crosshair, so V can grab it for a Savage Sling throw; since 1.2 it also shocks the target's cyberware. Single-player only.
Version 1.2.4 | For game version 2.5 (1.1 was built on 2.31) | Status: 1.1 tested in game on 2.31 (2026-10-24); 1.2.3 tried in game on 2.5, two faults found and fixed in 1.2.4; 1.2.4 not run in game yet

Published on Nexus Mods as "ForceStun Hotkey Stun for Savage Sling" (version 1.1 there): <https://www.nexusmods.com/cyberpunk2077/mods/28745>

## What and why

Aim at an NPC within 15 m and press the hotkey. If no NPC is directly under the crosshair, the one closest to it within 8 degrees is used. Dead, defeated and knocked-out NPCs are skipped with a message.

With Buttslinger Quickmelee installed, the mod applies that mod's stun (`ActualStun` plus its opening effect), which gives the grab prompt; this works with Gorilla Arms equipped, no weapon swap needed. Without it, the mod applies the vanilla stun and prints a one-time note to the CET console; there is then no grab prompt.

Since 1.2, one press also shorts out the target's cyberware:

1. **Shock damage** (default 10 HP): silent (no aggro, no crime), ignores armour. If it would kill, the target is knocked out instead (vanilla Unconscious, no instigator). Bosses and targets immune to that stop at 1 HP. Nobody dies from the shock.
2. **Stun** as in 1.1, with an adjustable duration. A knocked-out target is not stunned.
3. **Electrified look**: Short Circuit arcs, the Cyberware Malfunction glitch with its sound, or both, with its own duration.
4. **Experimental, off by default**: while electrified, the target's chrome goes offline (no Sandevistan, Kerenzikov, optical camo or arm chrome), optionally with EMP convulsions after the stun or at once (at once replaces the stun, so the grab is lost).
5. **RAM cost**: a flat 4 RAM per press (0 = free). Not enough RAM, or a target that cannot be stunned right now: nothing happens and no RAM is used.

```text
package/
  bin/x64/plugins/cyber_engine_tweaks/mods/ForceStun/init.lua
  r6/scripts/ForceStun/ForceStunShock.reds
  r6/tweaks/ForceStun/ForceStunShock.yaml
```

## Requirements

- Cyberpunk 2077 2.5
- [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107)
- [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511) and [TweakXL](https://www.nexusmods.com/cyberpunk2077/mods/4197)
- Optional: [Mod Settings](https://www.nexusmods.com/cyberpunk2077/mods/4885) (without it the defaults apply)
- Optional: [Buttslinger Quickmelee](https://www.nexusmods.com/cyberpunk2077/mods/10556), for the grab prompt

Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `bin\x64\plugins\cyber_engine_tweaks\mods\ForceStun\init.lua`, `r6\scripts\ForceStun\` and `r6\tweaks\ForceStun\` exist.
3. Start the game and bind the hotkey in the CET overlay: Bindings > ForceStun > "Force Stun Target (for Savage Sling)".

## Uninstall / roll back

1. Close the game.
2. Delete `bin\x64\plugins\cyber_engine_tweaks\mods\ForceStun\`, `r6\scripts\ForceStun\` and `r6\tweaks\ForceStun\`.
3. Saves are not affected: nothing is stored.

## Configuration

The `settings` table at the top of `init.lua`: `maxRange` (15.0 m), `maxAngle` (8.0 degrees).

Mod Settings > ForceStun:

| Setting | Default | Range |
|---|---|---|
| Stun duration (s) | 4.6 (vanilla) | 0.5 to 30 |
| RAM cost | 4 (flat) | 0 to 20 (0 = free) |
| Shock damage (HP) | 10 | 0 to 500 (0 = off) |
| Electrified effect duration (s) | 5.0 | 0 to 30 (0 = off) |
| Electrified look | Both | Short Circuit arcs / Malfunction glitch / Both |
| Electrified gameplay (experimental) | Off | Off / Chrome offline / + convulsions after the stun / + convulsions at once |

## Changelog

| Version | Change |
|---|---|
| 1.2.4 (2026-11-28) | The key also fires while walking or zoomed (CET input instead of a hotkey). A would-be kill applies vanilla Unconscious instead of System Collapse, which did not drop civilians and left them at about 0 HP. |
| 1.2.2, 1.2.3 (2026-11-28) | Review fixes: convulsions wait for the real end of a refreshed stun; a refresh during Buttslinger's opening keeps the new duration; a debug log setting (off by default). |
| 1.2.1 (2026-11-28) | Flat RAM cost per press; a target that cannot be stunned right now costs nothing and is not shocked. |
| 1.2 (2026-11-28) | Shock add-on: shock damage that never kills, adjustable stun, electrified look, experimental chrome-offline and convulsion modes, Mod Settings page. |
| 1.1 (2026-10-24) | Crosshair targeting; vanilla stun when Buttslinger Quickmelee is missing; dead and knocked-out NPCs skipped with a message; the unused stun duration setting removed |
| 1.0 | First release |

Back to the [mod list](../../README.md).
