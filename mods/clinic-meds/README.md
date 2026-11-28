# Clinic Meds

Seven lore-friendly clinic cures for the Injuries and Dark Future mods: a concussion, bleeding, broken bones, all injuries at once, withdrawal, addiction and poison, each with an after-effect. Single-player only.
Version 1.0.1 | Built for game version 2.5 | Status: compiles on 2.5; not run in game yet

## What and why

| Item | Clears | Price | After-effect (real time) |
|---|---|---|---|
| NeuroMend Nanosurgeon Ampoule | Injuries concussion; ends Pain Blockers | 12,000 | 10 min: stamina regen starts 0.3 s later |
| HemoSeal (hemostatic) | Injuries bleeding; ends MedKit | 6,500 | 5 min: -10 stamina |
| OsteoWeld (bone fusion) | Injuries broken arm and limp; ends Painkiller without its flare-up | 9,500 | 15 min: -10 stamina, +0.3 s |
| ReGen-9 Full Trauma Cocktail | all Injuries and Dark Future's injury condition | 38,000 | 20 min: -15 stamina, +0.5 s |
| Quell Receptor Blocker | the current Dark Future withdrawal (the addiction stage stays) | 3,500 | 10 min: +0.2 s |
| Clean Slate Rapid Detox Kit | every Dark Future addiction | 28,000 | 30 min: -25 stamina, +0.5 s |
| ChelaTox Antidote Autoinjector | vanilla poison | 900 | 2 min: +0.2 s |

Each use shows an on-screen line ("...complete" or "...nothing found"; the item is used up either way). Sold at all 20 medic vendors and in the Virtual Atelier store "Biotechnica Clinical Supply"; since 1.0.1 ReGen-9 and Clean Slate are only sold by Pharm Courier. A medic that saved its stock before the mod was installed gets the items once, on its next visit.

Clinic Meds replaces the earlier single-item NeuroMend mod (same item record, so owned ampoules stay valid).

```text
package/
  r6/scripts/zz_CyberslopClinicMeds/CyberslopClinicMeds.reds
  r6/scripts/zz_CyberslopClinicMeds/CyberslopClinicMedsAtelier.reds
  r6/scripts/zz_CyberslopClinicMeds/CyberslopClinicMedsStock.reds
  r6/tweaks/zz_CyberslopClinicMeds/CyberslopClinicMeds.yaml
```

## Requirements

- Cyberpunk 2077 2.5
- [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511), [TweakXL](https://www.nexusmods.com/cyberpunk2077/mods/4197) and [Codeware](https://www.nexusmods.com/cyberpunk2077/mods/7780)
- Injuries (1.7.6 was used) and [Dark Future](https://www.nexusmods.com/cyberpunk2077/mods/16300)
- Optional: Virtual Atelier for the store (that script part compiles only when it is installed)

Requirements are not bundled.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `r6\scripts\zz_CyberslopClinicMeds\`, `r6\tweaks\zz_CyberslopClinicMeds\` exist.

## Uninstall / roll back

1. Close the game.
2. Delete `r6\scripts\zz_CyberslopClinicMeds\`, `r6\tweaks\zz_CyberslopClinicMeds\`.

## Changelog

| Version | Change |
|---|---|
| 1.0.1 (2026-11-26) | ReGen-9 and Clean Slate leave the medic and store stock; Pharm Courier sells all seven cures. |
| 1.0.0 (2026-11-25) | First version: seven cures, medic stock, Virtual Atelier store. |

Back to the [mod list](../../README.md).
