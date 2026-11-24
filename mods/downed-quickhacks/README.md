# Downed Quickhacks

The quickhack wheel opens on downed and unconscious NPCs and on corpses, with only the quickhacks that make sense there. Single-player only.
Version 1.0.1 | Built for game version 2.31 | Status: in use on 2.5, no written test record

## What and why

In the base game an NPC that is down, unconscious or dead can no longer be targeted by quickhacks. This mod opens the wheel on them with a fixed list:

- Defeated (down but alive): Ping, Contagion, Short Circuit, Synapse Burnout, Overheat, Detonate Grenade, System Reset and Blackwall Gateway. The damage quickhacks finish them off, System Reset knocks them out.
- Unconscious: the same without System Reset.
- Dead: Ping (reaches the squad through the body's cyberware), Contagion (the body is the source; it spreads to the living only) and Detonate Grenade (a booby-trapped corpse, once per body).

Every other quickhack shows as locked with the game's own "not active" text. Never on bosses, immortal or invulnerable NPCs or a fist-fight opponent. The game's own checks stay: hostile targets only, network exposure, range, RAM and cooldowns. Quickhacks on corpses give no Intelligence XP; on downed NPCs XP is as usual.

How a few of them work on a body:

- Ping: a downed NPC has left its combat squad, so the game's effect finds nobody. On completion the mod applies the quickhack's own Ping effect to one living member of the NPC's current or recent squad, which marks the rest the normal way.
- Detonate Grenade is normally an AI behaviour (the NPC pulls its own grenade), which a body on the ground cannot run. On a body the grenade beeps and goes off at its chest after a fuse, with the medium explosion attack (6 m; it also hurts you up close).
- No queueing on a body: the wheel shows "upload in progress" until the first upload is done.

The mod only wraps game functions. It filters the list after other mods have built it, so the wrap order with other netrunning mods does not matter.

## Requirements

| Requirement | Version | Link |
|---|---|---|
| Cyberpunk 2077 | built on 2.31 | |
| redscript | a build for your game version | [Nexus Mods, mod 1511](https://www.nexusmods.com/cyberpunk2077/mods/1511) |
| Codeware | a build for your game version | [Nexus Mods, mod 7780](https://www.nexusmods.com/cyberpunk2077/mods/7780) |
| Mod Settings (optional) | a build for your game version | [Nexus Mods, mod 4885](https://www.nexusmods.com/cyberpunk2077/mods/4885) |

Without Mod Settings the default values apply. Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `r6\scripts\zz_CyberslopDownedHacks\DownedHacks.reds` exists. The `zz_` prefix makes it load after other netrunning mods.
3. Start the game, knock an enemy down and scan it: the quickhack wheel opens with the list above.

## Uninstall / roll back

1. Close the game.
2. Delete `r6\scripts\zz_CyberslopDownedHacks`.
3. Saves are not affected.

## Configuration

The mod's own page in Mod Settings:

| Setting | Default | Range |
|---|---|---|
| Defeated NPCs | on | |
| Unconscious NPCs | on | |
| Corpses | on | |
| Blackwall Gateway on downed NPCs | on | |
| Grenade fuse on a body (s) | 1.0 | 0 to 3 |
| Log | on | |

The log writes every quickhack that finishes on a downed NPC or a corpse to the game log. Its description says to switch it off after the first test.

## Compatibility

| Item | Status | Notes |
|---|---|---|
| Better Netrunning | designed to work together | Its option to breach unconscious NPCs is left to it. The list is filtered after it switches quickhacks back on. |

## Changelog

| Version | Date | Game version | Change |
|---|---|---|---|
| 1.0.1 | 2026-11-02 | 2.31 | The extra trace lines run only when the log setting is on. No gameplay change. |
| 1.0.0 | 2026-10-29 | 2.31 | First version. |

Back to the [mod list](../../README.md).
