# Merc Stims

A merc's pharmacy for Dark Future: 29 lore-friendly consumables (CP2020 / RED names where canon has them, corp products otherwise) built on real pharmacology, sold at medics, black-market medics and a Virtual Atelier store. Single-player only.
Version 1.2.1 | Built for game version 2.5 | Status: compiles on 2.5; not run in game yet; no written test record

## What and why

Groups: wake and sleep (Vigil, Hold Fast, Surge, Lull), combat (Kagami, Hardline, Crank, Synthcoke), nerve (Steady, Serene, Zero Point), detox (Rapidetox, Antitox), oxygen (Respirocyte, Bronchodilator), field rations (ProteoMax, Electra, Corpo Daily, Ketone, Cold Brew, HydraSalt, NutriGel), chrome care (NeuroSync, OsteoCal, BioCoolant, Rejectol), grey market (Ghostline, Emberline) and, since 1.2.0, humanity items (Anchor, Tether, Lumen, Circuit Breaker, Kill Switch). Every item has a benefit, a duration in game hours and a cost (sleep debt, a crash, a debuff or a price). Only Crank and Synthcoke are Dark Future narcotics; nothing else causes euphoria or addiction.

Since 1.2.1 the top-tier (Legendary) items are not sold in shops; Pharm Courier delivers them.

How it works:
- `CyberslopMercStims.reds`: a script system with 30 persistent game-clock timers and a 5 second tick that applies and removes the items' status effects. The consume hook only queues a request, so nothing shared is written from the game's item threads.
- `CyberslopMercStimsTexts.reds`: all item texts (Codeware). `CyberslopMercStimsStock.reds`: a one-time top-up for vendors you already visited (a vendor saves its stock on the first visit). `CyberslopMercStimsAtelier.reds`: the Virtual Atelier store "Afterhours Pharm", compiled only when Virtual Atelier is installed.
- `CyberslopMercStims.yaml`: items, status effects and vendor stock.

Two effects work through other mods by status effect tag only: Respirocyte and Bronchodilator raise oxygen capacity and refill in [Endurance](https://github.com/penicius-code/cp2077-endurance) 1.3.2; Ghostline (no vehicle-sleep ambush) needs a small local edit of Dark Future that is not published here, so without it Ghostline has no effect.

```text
package/
  r6/scripts/zz_CyberslopMercStims/CyberslopMercStims.reds
  r6/scripts/zz_CyberslopMercStims/CyberslopMercStimsAtelier.reds
  r6/scripts/zz_CyberslopMercStims/CyberslopMercStimsStock.reds
  r6/scripts/zz_CyberslopMercStims/CyberslopMercStimsTexts.reds
  r6/tweaks/zz_CyberslopMercStims/CyberslopMercStims.yaml
```

## Requirements

- Cyberpunk 2077 2.5
- [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511), [TweakXL](https://www.nexusmods.com/cyberpunk2077/mods/4197) and [Codeware](https://www.nexusmods.com/cyberpunk2077/mods/7780)
- [Dark Future](https://www.nexusmods.com/cyberpunk2077/mods/16300) (Energy, Nerve, nutrition, hydration, narcotics)
- Optional: Virtual Atelier for the "Afterhours Pharm" store; Wannabe Edgerunner for the humanity items' effect; [Endurance](https://github.com/penicius-code/cp2077-endurance) for the oxygen items

Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `r6\scripts\zz_CyberslopMercStims\`, `r6\tweaks\zz_CyberslopMercStims\` exist.

## Uninstall / roll back

1. Close the game.
2. Delete `r6\scripts\zz_CyberslopMercStims\`, `r6\tweaks\zz_CyberslopMercStims\`.

## Known issues

- Ghostline needs a local edit of Dark Future that is not published; without it the item does nothing.
- The yaml also overrides the price modifiers of Wannabe Edgerunner's neuroblockers (1.2.1: Common 1,500, Uncommon 2,800, Rare 5,000, Mil-spec 8,500).

## Changelog

| Version | Change |
|---|---|
| 1.2.1 (2026-11-26) | Top-tier items are out of the medic and black-market stock and the Atelier store (Pharm Courier sells them); a vendor's saved stock drops them on the next visit. Neuroblocker prices rebalanced. |
| 1.2.0 (2026-11-26) | Humanity items for Wannabe Edgerunner: Anchor, Tether, Lumen, Circuit Breaker, Kill Switch. |
| 1.1.1 (2026-11-26) | Crit and headshot bonuses replaced by mitigation, recoil, aim and reload bonuses; Dark Future's own Overdrive stacks give aim speed instead of crit. |
| 1.1.0 (2026-11-26) | Nerve, oxygen, detox, chrome-care and grey-market items; 29 items in all. |
| 1.0.0 (2026-11-26) | First version: eight meds. |

Back to the [mod list](../../README.md).
