# Cyberpunk 2077 mods

Script mods for Cyberpunk 2077: combat, vehicles, netrunning, economy, interface windows and small fixes, plus the measuring tools behind some of them. Single-player only.
Built on game versions 2.31 and 2.5. The Status column gives the recorded test result of each mod; nothing is rounded up. Every mod has its own README with requirements, install, rollback and known issues.

**Featured, each in its own repository:** [AV Flight](https://github.com/penicius-code/cp2077-av-flight) | [Salvage](https://github.com/penicius-code/cp2077-salvage-crew) | [Gorilla Yeet](https://github.com/penicius-code/cp2077-gorilla-yeet) | [Custom Vehicles](https://github.com/penicius-code/cp2077-custom-vehicles) | [Eye Non-Lethal](https://github.com/penicius-code/cp2077-eye-non-lethal) | [Kiroshi NetLink](https://github.com/penicius-code/cp2077-netlink) | [Chrome Stride](https://github.com/penicius-code/cp2077-chrome-stride) | [Chrome Upkeep and Chrome Clinic](https://github.com/penicius-code/cp2077-chrome-upkeep) | [Bounty Ledger and NCPD Uplink](https://github.com/penicius-code/cp2077-bounty-ledger) | [Endurance](https://github.com/penicius-code/cp2077-endurance) | [Quick Wardrobe](https://github.com/penicius-code/cp2077-quick-wardrobe) | [Quest Picker](https://github.com/penicius-code/cp2077-quest-picker) | [Shard Log](https://github.com/penicius-code/cp2077-shard-log) | [Phone Search](https://github.com/penicius-code/cp2077-phone-search) | [Media Remote](https://github.com/penicius-code/cp2077-media-remote) | [Backpack](https://github.com/penicius-code/cp2077-backpack)

> This is an unofficial fan work and is not approved/endorsed by CD PROJEKT RED. No game files are included.

## Mods

<details>
<summary><strong>Published on Nexus Mods</strong> (7)</summary>

| Mod | What it does | Requires | Status | Details |
|---|---|---|---|---|
| Gorilla Yeet ([Nexus](https://www.nexusmods.com/cyberpunk2077/mods/29014)) | Gorilla Arms punches launch the target as a ragdoll along your aim; lootable bodies, optional non-lethal mode | CET, redscript | 0.5.2 released and in use; 0.5.9 and 0.5.10 not yet play-tested | [README](mods/gorilla-yeet/README.md); own repo [cp2077-gorilla-yeet](https://github.com/penicius-code/cp2077-gorilla-yeet) |
| Head Popper ([Nexus](https://www.nexusmods.com/cyberpunk2077/mods/28767)) | A hotkey pops the head of the NPC under the crosshair; protected NPCs skipped | CET, redscript, TweakXL | 1.3 tested in game on 2.31; 2.5 not tested | [README](mods/head-popper/README.md) |
| Corpse Throw ([Nexus](https://www.nexusmods.com/cyberpunk2077/mods/28748)) | A hotkey puts the body under the crosshair on V's shoulder for a Savage Sling throw | CET | 1.1 tested in game on 2.31; 2.5 not tested | [README](mods/corpse-throw/README.md) |
| SandevistanToggle ([Nexus](https://www.nexusmods.com/cyberpunk2077/mods/28747)) | A hotkey switches Sandevistan-style slow motion on and off anywhere | CET | 1.1 tested in game on 2.31; 1.2 not yet play-tested | [README](mods/sandevistan-toggle/README.md) |
| ForceStun ([Nexus](https://www.nexusmods.com/cyberpunk2077/mods/28745)) | A hotkey stuns the NPC under the crosshair so V can grab it | CET; Buttslinger Quickmelee optional | 1.1 tested in game on 2.31; 2.5 not tested | [README](mods/force-stun/README.md) |
| Drop Current Weapon ([Nexus](https://www.nexusmods.com/cyberpunk2077/mods/27211)) | A hotkey drops the held weapon into the world; optional add-on drops the old weapon when a pickup replaces it | CET | 1.1.0 tested in game on 2.31; AutoDrop 1.1.1 not yet play-tested | [README](mods/drop-current-weapon/README.md) |
| PLS Obliterate ([Nexus](https://www.nexusmods.com/cyberpunk2077/mods/29386)) | Projectile Launch System blasts obliterate the NPCs they hit; lethal-only option | redscript; Mod Settings optional | 1.1.1 tested in game on 2.31; 2.5 not tested | [README](mods/pls-obliterate/README.md) |

</details>

<details>
<summary><strong>Vehicles</strong> (8)</summary>

| Mod | What it does | Requires | Status | Details |
|---|---|---|---|---|
| Vehicle Actions | CET window for the car you sit in or aim at: locks, engine, lights, doors, windows, trunk, every Enhanced Vehicle System action | CET, redscript; Enhanced Vehicle System optional | 1.0.0 confirmed working on 2.31; 1.1.0 to 1.6.1 not yet play-tested | [README](mods/vehicle-actions/README.md) |
| Custom Vehicles + Vehicle Bench | Vehicle performance tuned from in-game measurements, applied to add-on cars and bikes | CET; Cyber Vehicle Overhaul (for Custom Vehicles) | 1.0.0 to 1.2.2 benched in game; 1.2.3 to 1.2.5 not yet play-tested | [README](mods/custom-vehicles/README.md); own repo [cp2077-custom-vehicles](https://github.com/penicius-code/cp2077-custom-vehicles) |
| Take Control Car Fix | Repairs a car after the Take Control quickhack: trunk and hood open again, engine stays on, autodrive retried | redscript; EVS and Auto Drive Enhanced optional | Compiles on 2.5, not yet play-tested | [README](mods/take-control-car-fix/README.md) |
| Tough Cars | Cars only blow up from explosives, not from bullets, punches or crashes | redscript | In use, no written test record | [README](mods/tough-cars/README.md) |
| Vehicle Camera Hold FPP | Holding the vehicle camera button jumps straight back to first person | redscript, Input Loader | Compiles on 2.5, not yet play-tested | [README](mods/vehicle-camera-hold-fpp/README.md) |
| Calm Exit | Getting out of a car outside combat no longer draws a weapon | redscript | Compiles on 2.5, not yet play-tested | [README](mods/calm-exit/README.md) |
| EVS Vehicle On Fix | With Enhanced Vehicle System: an engine switched off stays off after exit; third-person radio muffle works | redscript, Enhanced Vehicle System | Compiles, not yet play-tested | [README](mods/evs-vehicle-on-fix/README.md) |
| Vehicle Savable | Saves made while driving certain add-on cars and bikes load correctly | TweakXL; the vehicle mods it lists | Not yet play-tested | [README](mods/vehicle-savable/README.md) |

</details>

<details>
<summary><strong>Combat</strong> (7)</summary>

| Mod | What it does | Requires | Status | Details |
|---|---|---|---|---|
| Eye Non-Lethal | A key switches Kiroshi optics to a non-lethal mode: hits on humans knock out instead of kill | redscript, TweakXL, Codeware | up to 1.3.0 confirmed in game on 2.31; 1.4.0 to 1.6.0 not play-tested | [README](mods/eye-non-lethal/README.md) (own repo: [cp2077-eye-non-lethal](https://github.com/penicius-code/cp2077-eye-non-lethal)) |
| Thunderclap | A new legendary electric quickhack that knocks humans out, arcs to up to three enemies and never kills | redscript, TweakXL, Codeware; CET optional | 1.1.0 confirmed on 2.31; 1.3.0 compiles on 2.5, not run in game | [README](mods/thunderclap/README.md) |
| Chrome Stride | Sprint speed comes from leg cyberware, with a build-up, a stamina cost and a double-tap burst | redscript, TweakXL; Mod Settings optional | 1.2.0 and 1.4.0 confirmed in game on 2.31; 1.4.3 in use in my game on 2.5 and working; no written test record | [README](mods/chrome-stride/README.md); own repo [cp2077-chrome-stride](https://github.com/penicius-code/cp2077-chrome-stride) |
| Knockdown Release | After a car knockdown you can move as soon as you are back on your feet | redscript, RedFileSystem | not run in game | [README](mods/knockdown-release/README.md) |
| Stay Dead | Open-world NPCs you killed or knocked out stay away for game days | redscript, Mod Settings | compiles on 2.31; not run in game | [README](mods/stay-dead/README.md) |
| Corpse Ragdoll | Dead enemies stop twitching or crawling on the floor | redscript | 1.0.0 run on 2.5 with two failures; 1.0.1 not run in game | [README](mods/corpse-ragdoll/README.md) |
| Crowd Collapse | System Collapse knocks crowd NPCs unconscious | redscript; a mod that lets System Collapse target civilians | compiles on 2.5; not run in game | [README](mods/crowd-collapse/README.md) |

</details>

<details>
<summary><strong>Netrunning</strong> (3)</summary>

| Mod | What it does | Requires | Status | Details |
|---|---|---|---|---|
| Easier Breach | Breach Protocol gets easier with Intelligence (longer timer, bigger buffer, shorter chains), devices more than NPCs | redscript; Mod Settings optional | not run in game | [README](mods/easier-breach/README.md) |
| Downed Quickhacks | Selected quickhacks work on downed NPCs and a few on corpses | redscript, Codeware; Mod Settings optional | in use on 2.5, no written test record | [README](mods/downed-quickhacks/README.md) |
| Instant Login | Computers skip NewBrowser's typed login and open the desktop at once | redscript, NewBrowser | confirmed in game on 2.31 | [README](mods/instant-login/README.md) |

</details>

<details>
<summary><strong>Realism and economy</strong> (7)</summary>

| Mod | What it does | Requires | Status | Details |
|---|---|---|---|---|
| Chrome Upkeep (with Chrome Clinic) | Cyberware wears with use, loses performance and needs paid repair at a ripperdoc; a window at the ripperdoc shows condition and prices | CET, redscript, TweakXL, Codeware, Mod Settings, Input Loader | Chrome Upkeep 1.7.2 and Chrome Clinic 1.1.3 in use in my game and working; no written test record | [README](mods/chrome-upkeep/README.md); own repo [cp2077-chrome-upkeep](https://github.com/penicius-code/cp2077-chrome-upkeep) |
| Bounty Ledger (with NCPD Uplink) | NCPD bounties priced by wanted stars, alive pays more, payout later in one batch; a window shows the claim file | CET, redscript, Codeware, Mod Settings | 1.0.0 tested in game on 2.31 (prices, alive claim, death downgrade, scan rule and batching seen; the payout itself was not reached in that test); Bounty Ledger 1.1.7 and NCPD Uplink 1.0.0 in use in my game and working; no written test record | [README](mods/bounty-ledger/README.md); own repo [cp2077-bounty-ledger](https://github.com/penicius-code/cp2077-bounty-ledger) |
| Cashflow | Records every change of V's money with its source; morning statement and a CSV file | redscript, Codeware, Mod Settings, RedFileSystem | built on 2.31, not run in game yet | [README](mods/cashflow/README.md) |
| Bank | Account with interest, loans and a credit score in one window | CET | not run in game yet | [README](mods/bank/README.md) |
| Salvage | Salvage androids and a drone collect loot from downed enemies after a fight | CET, redscript | runs in game per its log; no written test pass yet | [README](mods/salvage-crew/README.md); own repo [cp2077-salvage-crew](https://github.com/penicius-code/cp2077-salvage-crew) |
| Trunk Ammo | Opening your car's trunk tops up ammo, paid in crafting components at the bench price | redscript, TweakXL, RedFileSystem | not run in game yet | [README](mods/trunk-ammo/README.md) |
| Endurance | Adds an Oxygen reserve on top of stamina that runs down with sustained effort | redscript, TweakXL, Dark Future | in use in my game and working; no written test record | [README](mods/endurance/README.md); own repo [cp2077-endurance](https://github.com/penicius-code/cp2077-endurance) |

</details>

<details>
<summary><strong>Interface windows</strong> (9)</summary>

| Mod | What it does | Requires | Status | Details |
|---|---|---|---|---|
| Quick Wardrobe | Put Equipment-EX wardrobe items on and off from a window, with filters, outfits and a pinned mode | CET, redscript, Codeware, Equipment-EX | 1.2.2 in use in my game and working; earlier versions were tried in game; no version has a written test record | [README](mods/quick-wardrobe/README.md); own repo [cp2077-quick-wardrobe](https://github.com/penicius-code/cp2077-quick-wardrobe) |
| Quest Picker | Choose the tracked quest from a journal-style window without the pause menu | CET | in use in my game and working; no written test record; the offline mock test passes (129 of 129 checks) | [README](mods/quest-picker/README.md); own repo [cp2077-quest-picker](https://github.com/penicius-code/cp2077-quest-picker) |
| Shard Log | Every shard in one window, newest first, with search and a reading pane | CET, redscript | runs in my game, lightly used so far; no written test record; redscript compiles and the offline mock test passes (136 of 136 checks) | [README](mods/shard-log/README.md); own repo [cp2077-shard-log](https://github.com/penicius-code/cp2077-shard-log) |
| Phone Search | Search every phone contact and thread, then open the thread or call | CET, redscript | 1.0.1 in use in my game and working; 1.0.0 was used in game (a problem seen there led to 1.0.1), with no written test result | [README](mods/phone-search/README.md); own repo [cp2077-phone-search](https://github.com/penicius-code/cp2077-phone-search) |
| Media Remote | Power, station, volume and mute for radios and TVs within reach | CET, redscript | in use in my game and working; no written test record; checked with an offline mock test (37 of 37 checks pass) | [README](mods/media-remote/README.md); own repo [cp2077-media-remote](https://github.com/penicius-code/cp2077-media-remote) |
| Backpack | Use consumables from an overlay list without the pausing backpack screen | CET | 1.0.0 failed its in-game test (items were used by themselves); 1.0.1 fixes that cause and is in use in my game and working; no written test record | [README](mods/backpack/README.md); own repo [cp2077-backpack](https://github.com/penicius-code/cp2077-backpack) |
| HUD Control (with Scanner Pins) | Hide HUD elements and set their opacity on top of Limited HUD; map pins get world markers out to scanner range | CET, redscript, TweakXL, Limited HUD | not run in game yet | [README](mods/hud-control/README.md) |
| Gamma Slider | Change gamma from a window or hotkeys, optional day and night values | CET | 1.0.0 loaded in game on 2.31, no written result; 1.1.0 no test record | [README](mods/gamma-slider/README.md) |
| Kiroshi NetLink | A computer screen inside the Kiroshi optics that opens on a key and follows you on foot and in cars | CET, redscript, Codeware, DigitalVixen Core; source only, not installable from the repo | 1.1.0 and 1.3.0 used in game on 2.31; 1.7.0 failed its in-game test on 2.5; 1.7.1 in use in my game and working; no written test record | [README](mods/netlink/README.md); own repo [cp2077-netlink](https://github.com/penicius-code/cp2077-netlink) |

</details>

<details>
<summary><strong>Quality of life</strong> (1)</summary>

| Mod | What it does | Requires | Status | Details |
|---|---|---|---|---|
| Hold Esc Menu | The pause menu opens only after Esc is held for half a second | redscript | not run in game | [README](mods/hold-esc-menu/README.md) |

</details>

<details>
<summary><strong>Audio</strong> (1)</summary>

| Mod | What it does | Requires | Status | Details |
|---|---|---|---|---|
| Sound Gains | Sets the volume of other sound mods' custom sounds through AudioXL from one tuning table | CET, AudioXL | 1.0.0 confirmed on 2.31; 1.0.1 not run in game | [README](mods/sound-gains/README.md) |

</details>

## Research

Read-only mods written to find out how a game system behaves before changing it. Each folder has the code and a short write-up: the question, how it was measured, what was found.

| Probe | Question it answered | Result | Details |
|---|---|---|---|
| Monitor 2.1.2 | Where does the time go on every trip into a menu and back, and what state is the game in when it stutters or crashes? | Used for weeks; dated the start of the steady stutter, and its own crash led to a world-read gate in 2.1.2 | [README](research/monitor/README.md) |
| PerfLog 1.0.1 | When and where does normal play hitch, and do hitches line up with Lua garbage collection? | Always-on CSV log with a report script; first run worked, no further findings recorded | [README](research/perflog/README.md) |
| Combat Log 1.4.0 | What does each hit do: health taken, NPC hit rates, hits to drop an NPC, and who zeroed a hit that did nothing? | Source of the damage and armour tuning; 1.4.0 is the 2.5 port, compiled but not run in game | [README](research/combat-log/README.md) |
| Gore Probe 1.1.0 | Why does dismemberment fail at range: a script rule or the engine? | The engine drops cuts at range: 22 of 22 landed under 25 m, 0 of 12 beyond 75 m; no script fix possible | [README](research/gore-probe/README.md) |
| Vehicle Bench 1.2.1 | What are the real 0-100 km/h times and top speeds of each vehicle? | Measurements used to fit the Custom Vehicles tuning (code lives in that repo) | [README](research/vehicle-bench/README.md) |

More investigations, including two that did not find their answer, are in [docs/investigations.md](docs/investigations.md).

## Changes to other authors' mods

Many mods by other authors needed changes to run on game version 2.5, to fix errors or to cost less performance. Those changes are described in words in [COMPATIBILITY.md](COMPATIBILITY.md). None of the changed files are published here, because they are other authors' work.

## Install a mod (general steps)

1. Install the requirements listed in that mod's README (see [Common requirements](#common-requirements)).
2. Copy the content of the mod's `package/` folder into the game folder, so that the folders line up with the game's own folders (`bin`, `r6`, `archive`).
3. Start the game. Mods with a window appear in the Cyber Engine Tweaks overlay; mods with settings appear in the game's Mod Settings menu if that mod is installed.

## Common requirements

| Requirement | Used for | Where to get it |
|---|---|---|
| Cyber Engine Tweaks | Lua mods (`bin\x64\plugins\cyber_engine_tweaks\mods`) | [Nexus Mods, mod 107](https://www.nexusmods.com/cyberpunk2077/mods/107) |
| redscript | script mods (`r6\scripts`) | [Nexus Mods, mod 1511](https://www.nexusmods.com/cyberpunk2077/mods/1511) |
| RED4ext | needed by TweakXL, Codeware and Mod Settings | [Nexus Mods, mod 2380](https://www.nexusmods.com/cyberpunk2077/mods/2380) |
| TweakXL | tweak files (`r6\tweaks`) | [Nexus Mods, mod 4197](https://www.nexusmods.com/cyberpunk2077/mods/4197) |
| Codeware | extra script functions some mods call | [Nexus Mods, mod 7780](https://www.nexusmods.com/cyberpunk2077/mods/7780) |
| Mod Settings | in-game settings pages | [Nexus Mods, mod 4885](https://www.nexusmods.com/cyberpunk2077/mods/4885) |

These are not bundled in this repository. Each mod's README says which of them it needs.

## Uninstall / roll back

Each mod README lists exactly which files or folders it adds. Close the game and delete those to remove the mod. To return to an unmodified game, remove all mods and let the store client verify the game files.

## Repo layout

```text
mods/<mod>/README.md       per-mod documentation
mods/<mod>/package/        folder tree that mirrors the game folder
mods/<mod>/variants/       alternative files for the same game path, where a mod has them
research/<probe>/          measuring mods with their write-ups
docs/investigations.md     shorter investigations, in words
COMPATIBILITY.md           changes made to other authors' mods, in words
```

## Licence and credits

My code is MIT-licensed, see [LICENSE](LICENSE). Game files, names and trademarks belong to their owners; none are included here.
Built with AI assistance (Claude); designed, tested and maintained by me.
