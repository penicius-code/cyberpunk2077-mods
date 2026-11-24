# PLS Obliterate

Every blast from V's Projectile Launch System cyberarm obliterates the NPCs it hits. Single-player only.
Version 1.1.1 | Built on game version 2.31 | Status: tested in game on 2.31 (2026-10-29); not tested on 2.5; the Lethal Only file has no separate test record

Published on Nexus Mods as "Spontaneous Obliteration for the Projectile Launch System": <https://www.nexusmods.com/cyberpunk2077/mods/29386>

## What and why

The Body perk Spontaneous Obliteration blows enemies apart when a shotgun or LMG finishes them. The Projectile Launch System never got that: the game hands every explosion to its explosion gore and never asks the perk. With this mod, a blast from a PLS round fired by V runs the full obliteration on every NPC it hits, at 100 % chance and without the perk. Bodies in the blast, dead or downed, come apart too. Bosses and MaxTac are excluded, as in the base game. Grenades, other explosions, shotguns and LMGs are unchanged.

How it works: one `@wrapMethod` on `HitReactionComponent.ProcessWoundsAndDismemberment`. When the hit is an explosion whose source is a PLS round fired by the player, the mod runs the obliteration instead of the explosion gore; everything else goes to the original code. No `@replaceMethod`, no TweakDB edits.

Since 1.1.1 the obliteration runs through the mod's own copy of the game's routine `HitReactionComponent.ProcessBodyPerkDismembement` (about 55 lines of the game's 2.31 script, marked with a comment in the file). Other mods replace that routine, for example Obliterate Dismemberment Fix, which keeps only the hit body part; with them a PLS blast in 1.1.0 cut off a single leg. With its own copy the PLS result stays the full obliteration.

```text
package/
  r6/scripts/PLSObliterate/PLSObliterate.reds                     main file (Mod Settings toggle)
variants/lethal-only/
  r6/scripts/PLSObliterate/PLSObliterate.reds                     lethal hits only, built in
```

## Requirements

- Cyberpunk 2077 2.31
- [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511) (built with 0.5.31)
- Optional: [Mod Settings](https://www.nexusmods.com/cyberpunk2077/mods/4885), only for the "Lethal hits only" toggle

Requirements are not bundled.

## Install

1. Install redscript.
2. Copy the contents of `package/` into the game folder, so that `r6\scripts\PLSObliterate\PLSObliterate.reds` exists.
3. Or, for lethal hits only without Mod Settings: copy the contents of `variants/lethal-only/` instead. Both files use the same path; install one, not both.

## Uninstall / roll back

1. Close the game.
2. Delete `r6\scripts\PLSObliterate\`.
3. Saves are not affected: the mod stores nothing.

## Configuration

Mod Settings > "PLS Obliterate" > "Lethal hits only" (off by default). Off: every PLS blast obliterates the NPCs it hits. On: only PLS hits that kill obliterate. Without Mod Settings the default applies.

## Compatibility

| Mod | Status | Notes |
|---|---|---|
| Revolver x Obliteration and other mods that replace `IsValidBodyPerkDismemberAttack` | works | Nothing is replaced since 1.1.0 |
| Obliterate Dismemberment Fix | works | Since 1.1.1: shotgun obliterations follow that mod, PLS blasts still take the whole body |

## Known issues

- At long range the engine uses simplified NPC models without dismemberment meshes, so a body may not visibly come apart even though the kill counts.
- Only V's own PLS rounds count.

## Changelog

| Version | Change |
|---|---|
| 1.1.1 (2026-10-28) | Own copy of the game's obliteration routine, so mods that rewrite that routine no longer reduce PLS blasts to one leg |
| 1.1.0 (2026-10-24) | Hooks earlier, so the obliteration really runs; no method replaced; Mod Settings toggle and Lethal Only file; bodies in the blast come apart too |
| 1.0.0 | First release (never fired: explosions went to the explosion gore before its check) |

Back to the [mod list](../../README.md).
