# Local changes to other authors' mods

This page lists the changes I made, for my own game, to Cyberpunk 2077 mods written by other people, described in words. None of the changed files are published here, because they are the other authors' work. The changes can be offered to the authors on request.

Authors are named as my notes record them; "not recorded" means my notes do not name the author. Single-player only. Most changes keep the mod's behaviour and only fix, port or speed it up; where a change alters what the mod does, the row says so.

## Game-version ports to patch 2.5

| Mod | Author | What was changed and why |
|---|---|---|
| Eviction Notice | Dark Fortune Teller | Map-edit file re-mapped to the 2.5 world data, because 2.5 changed node types and the old entries no longer matched. |
| Lucy Apartment Remastered | not recorded | World-edit list updated to 2.5: removed objects retyped to the new node types and two entry numbers moved. |
| Cyber Noir Flat | not recorded | World-edit file re-mapped to the 2.5 world data. |
| Judy's Lake House | not recorded | World-edit file re-mapped to the 2.5 world data. |
| Cloud first-floor booths | not recorded | World-edit file re-mapped to the 2.5 world data. |
| Virtual Atelier Delivery | not recorded | World-edit file re-mapped to the 2.5 world data. |
| Cyberarm Cycle | Kingpin RBD | Script rebuilt on the 2.5 rework of arm slots, since no 2.5 build of the mod was available. |
| HoldToOverclockWhileScanning | not recorded | Script hooks ported to 2.5, since no 2.5 build was available. |
| CyberneticEyesToAim | not recorded | Script hooks ported to 2.5, since no 2.5 build was available. |
| MovementAndCameraTweaks | not recorded | Script hooks ported to 2.5, since no 2.5 build was available. |
| Gunsensical | not recorded | Game-data records adjusted for 2.5. |
| No More Out-Leveling Vendor Items | not recorded | Game-data records adjusted for 2.5. |
| Cronos | not recorded | Game-data records adjusted for 2.5. |
| Trauma Team Smart Link | Cyberbuilds | Its copy of a 2.31 game icon sheet broke cyberware, quickhack and clothing icons on 2.5; replaced by a separate icon sheet. |
| Blackwall Berserk | Cyberbuilds | Same icon-sheet repair as above. |
| Less Samurai | not recorded | Icon sheet numbers updated for 2.5. |
| Armor Up | Phoenicia | Icon sheet numbers updated for 2.5; a "Realism" preset added to its settings. |
| Dark Future | Dark Fortune Teller | My local value changes and add-on hooks (see below) carried onto the author's 2.5 release by hand. |
| Wannabe Edgerunner | djkovrik | My local additions (see below) carried onto the author's 2.5 release. |

## Crash, error and bug fixes

| Mod | Author | What was changed and why |
|---|---|---|
| NC Living Costs | Elizbetha | A diagnostic logging routine no longer writes to a shared list, after a crash at the same place in the game repeated on two days. |
| Further Felonies | Sly Trickolas | Two lines of one data file re-indented, because the file as shipped failed to load. |
| V Voice Framework | dnbnhlp | 17 voice-line pools set to the English lines, because random comments played in Spanish. |
| Polyglot V | Nttnnexus | Five line swaps in its English audio and subtitle scripts, for the same Spanish-lines problem. |
| Enhanced Vehicle System | YG | Interior power re-synced when the flag says "on" but the dashboard is off, and engine start raises power first, because cabin lights stayed off with the engine running; per-input work also trimmed. |
| Overclocked Lynx Paws | Frosthaven | Wall-climb fixes (reverse hang, grabbing again after letting go, stamina regeneration, Shift for wall run and Space for climb), entry angle 15 to 35 degrees, and an input filter against stutter. |
| AEMHnG (auto-equip motorcycle helmets and goggles) | not recorded | A helmet toggle key with on-screen text added, and missing-value guards added. |
| Kabtools | not recorded | Faster police hologram call, a fix for late spawns, a call button in its window, and lighter input handling. |

## Performance

These changes reduce repeated work in the mod's script (checks moved from every frame to a few times a second, early exits, cached values). Behaviour is meant to stay the same. Most of them came from the stutter study in [investigations](docs/investigations.md).

| Mod | Author | What was changed and why |
|---|---|---|
| Hair Profiles CCXL | island_dancer and psiberx | Hair-colour patching limited to the player's own hair meshes; 46,980 of 47,250 patch lines in one launch had hit shared NPC hair. |
| Revengers | TSU (README) / prius310l (mod list) | Its periodic update spread over about 17 frames every 15 seconds instead of one frame every 5 seconds, which caused a regular hitch from hundreds of game-fact reads. |
| NCA HQ | VfromNightCity | A 4,932-line weapon list is no longer written to the log at every launch. |
| NCA Missions | VfromNightCity | Mission data cached instead of being re-read from disk every frame. |
| EXRC Runtime Controller | EntryierX | Lua memory clean-up scheduled for menus and loading screens, where a pause is not visible; it did not remove the steady hitch. |
| Immersive NCPD Hotline | anygoodname | Slow checks limited to five times a second. |
| 0-Engine | DigitalVixen | Twelve lookups done once instead of every frame. |
| GigCore | luridphoenix | Pause check only during a gig; vehicle damage check ten times a second. |
| Night City Pizza Delivery | luridphoenix | One message check once a second instead of every frame. |
| Street Games Playable Basketball | JudoChopMods | Idle check ten times a second; its input hook now only observes. |
| Go on a Date (Judy) | Dedra | Interaction screen update skipped when nothing is shown. |
| Go on a Date (Panam) | Dedra | Same change as above. |
| RA Militech Behemoth | Dedra | Same change as above. |
| Appearance Menu Mod | MaximiliumM | Mouse-movement input skipped, a growing vehicle list cleaned, one check once a second, and its 43,881 pose entries (about 15 MB of Lua memory) loaded only when its window is first opened. |
| Playable Arcade Machines | keanuWheeze | Early exit in its input hook. |
| Unarmed Carry | ripperdoc | Early exit in its input hook. |
| Charm Quickhack | yakuzadeso | Early exit in its input hook. |
| Zoomable Scopes | keanuWheeze | Input hook returns on mouse-movement events; carried onto version 1.5. |
| Time Dilation Overhaul | The Cyberpunk THING Team and Friends | Input check narrowed, and one vehicle check slowed from 40 to 4 times a second when its assist is off; merged into the author's later release. |
| Shift | CyanideX | One name lookup per event, an input filter, and failed lookups retried every 5 seconds instead of every frame. |
| Circlemap Widgets | Scream81 | Two per-frame checks return early when there is nothing to do. |
| GameUI library | psiberx | In 44 copies bundled with other mods, event data is read once per callback. |
| Misty's Resonance Services | RetchERezzed | Interface update skipped when nothing is shown; checks ten times a second; redone on the author's rewrite. |
| Weather Switcher | CyanideX | Interface update skipped when nothing is shown; checks ten times a second. |
| ScannerPlus | spaceymonk | Interface update skipped when nothing is shown; checks ten times a second. |
| Immersive Suppressor Toggle | RyselZ | Interface update skipped when nothing is shown; checks ten times a second. |
| Gambling System Roulette | Boe6 | Map-pin update returns unless its own pin is shown. |
| Gambling System Blackjack | Boe6 | Same change as above. |
| Gambling System Pachinko | Boe6 | Same change as above. |
| Kiroshi Night Vision Mod | keanuWheeze | The "off" effect is sent once when switching off and then once a second, not every frame. |
| Kiroshi Optics Thermal Vision | 0nlyQ | Active effect updated 20 times a second; when idle, cleared once and checked once a second. |
| Native Interactions Framework | keanuWheeze | World update sleeps for 0.25 seconds when nothing is near; manager update ten times a second. |
| I Want Them Alive | gygaxinor | Five quest-fact checks four times a second and about 62 per-frame reads removed; also two console helper commands added. |
| The Lamp Lighter | TheManualEnhancer | Checks two to four times a second. |
| Dynamic Ward | fly80high | Checks two to four times a second. |
| Viktor Vektor's Garage Add-on | Dedra | Distance check every 0.5 seconds. |
| Nova Optics | theCyanideX | Checks two to four times a second. |
| Immersive Third Person | CybrDrake | Early exits when idle. |
| Air's Inertia Returns | tidusmd | Early exits when idle. |
| E3 Smart Windows | keanuWheeze | One lookup per call instead of several. |
| VHaptics | not recorded | About 20 per-frame helper objects and lookups removed. |
| Nitrous | MisterChedda | Loop slowed to once a second when idle. |
| SynthDose | Phoenicia | Loop slowed when idle; lookups cached. |
| Trigger Mode Control | Seijax | Loop slowed when idle; cheap input test first. |
| Camo Realism | Seijax | Loop slowed when idle. |
| Loot Icons Extension Light | Demon9ne | Loop slowed when idle; lookups cached. |
| Marker Fade | not recorded | Loop slowed when idle. |
| DigitalVixen Core | DigitalVixen | Movement loop slowed when idle. |
| Immersive Odometer and Fuel System | elminister | Update every 0.5 seconds while on foot. |
| Simple Flashlight | keanuWheeze | Light settings applied every tenth frame; carried onto version 2.6. |
| Inside The Metro | tidusmd | Metro hooks exit early outside the metro; redone by hand on the author's rewrite. |

## Behaviour changes and additions

| Mod | Author | What was changed and why |
|---|---|---|
| Clairvoyance | not recorded | Optional rules: enemies are marked only while scanning, within a range set by the installed eye cyberware, in line of sight and only if hostile, and marks fade after the scan; marks are restored after a load. |
| Injuries | DigitalVixen | Protection per body region taken from the chrome installed in that area instead of slot counts, with seven new config values. |
| Keep Tracked Quest | Aeoniums | Optional rule that keeps the quest tracker empty after untracking, payment objectives untracked, and a key function; before, the next quest that tracked itself was picked up after "untrack all". |
| Overlay Map | not recorded | Markers of an icon framework get their own icon, colour and title, about 15 other pin mods get their own look, and active quest pins are shown; before, all pins looked the same and quest markers were missing. |
| Sit Anywhere | keanuWheeze | An overlay window with Sit and Stand buttons and a mouse-button key, plus filters that cut per-input and per-frame work. |
| Use Your Fridge | juiiicy00 | Fridges found by position and limited to seven listed ones, vendors excluded, and its own food filter; the original would have turned a weapon-wall stash into a food-only fridge. |
| Push And Pull Mod | GreenHouse | Every push or pull marks the target so a separate script of mine treats a wall impact as a knockout, not a death; "down" includes unconscious; a guard for objects without physics. Pushing an enemy into a wall used to kill it at once. |
| Punish Cruelty | NightlyNow | Sliders for self-defence penalties and a nerve loss per humanity level. |
| Immersive Road Crossing | OGunblade | One death roll per collision, based on impact speed. |
| Much Better AI | 0nlyQ | Limits for hits from vehicles; hit model and accuracy settings changed (accuracy 1.6 to 1.2). |
| Wannabe Edgerunner | djkovrik | Nine ways to recover or keep humanity, using items from Dark Future, plus neuroblocker stock. |
| Dark Future | Dark Fortune Teller | Hooks for the humanity additions above (humanity loss, sleeping in a vehicle). |
| Cazanu Blood Pools | Cazanu | A cut limb of a living NPC also leaves a blood pool (setting: downed only, any living, off); before, only corpses did. |
| Trauma Team International - Premium Coverage | juiiicy00 | Insurance rules for mercenary work (street cred, grace period, claims history, danger zones), and the Badlands sub-districts counted as Badlands instead of "Blacklisted". |
| ScannerPlus | spaceymonk | Shows an armour line from one of my own mods in the scanner readout. |
| Ped Damage Overhaul 2077 | HJ and fitfondue | Limb removal depends on the number of hits, the calibre and armour plates; before, rifles took off limbs of downed NPCs on every hit. |
| Immersive Gigs | hobo of Ferelden | A speed-dial window added. |

## Compatibility between mods

| Mod | Author | What was changed and why |
|---|---|---|
| Cyberarm Cycle | Kingpin RBD | Its four reads of key 4 switched off while my arm-key mod is present, because both reacted to the same key. |
| Enhanced Vehicle System (input file) | YG | Numpad keys freed (their actions are in a window of mine), and one hold entry removed that closed the radio menu. |
| DigitalVixen Core | DigitalVixen | Command-menu key unset because of a key clash, and one repair action removed from its input file so another mod's repair works. |
| NCA AV System ADDON | VfromNightCity | Two lines appended so a control panel of mine can open its menu. |
| Night City Allies - Mercenary BONUS | not recorded | Two lines appended so a control panel of mine can open its menu. |
| AudioXL | not recorded | Settings only: internet connections allowed for ten listed radio stream hosts. |

## Value tuning and settings

| Mod | Author | What was changed and why |
|---|---|---|
| NCRE High-value Economy | not recorded | Property prices, rents, payouts, mortgages and upkeep rescaled, with a 6 percent selling cost, to match the economy scale of my game. |
| Progression For RipperDeck | not recorded | License prices raised (60k, 220k, 450k) and the service fee changed to 60, 50 and 40 percent, to match my cyberware price classes. |
| Ripperdoc Service Charge | jack | Default changed to fixed upgrade fees without an item-price fee; on 2.5 set through its config file. |
| A.G.I.S. PublicNet | Neideltern | Component bundle prices aligned with my component price table; medical store prices adjusted. |
| Virtual Atelier stores (33 files) | several authors | Clothing, weapon, recipe and grenade prices rescaled to the same economy scale. |
| Lifepath Bonuses | not recorded | Upload time grows evenly with distance instead of exponentially. |
| Better Netrunning | not recorded | Settings only: maximum range 60 to 40 m, and its boss ICE switched off because a mod of mine replaces it. |
| Dark Future | Dark Fortune Teller | Nerve recovery values (calm target, regeneration, recovery while sleeping, insomnia threshold), one energy check and a store stock tuned for slower, more realistic recovery. |
| Wannabe Edgerunner | djkovrik | Endotrisine price and stock, and neuroblocker stock. |
| Ped Damage Overhaul 2077 | HJ and fitfondue | Three groups of enemy records count as bosses at 30 percent health, limb thresholds 5 to 7, shotgun modifiers 1.0 to 0.6, and its non-lethal option off because its dying state made knocked-out NPCs invulnerable. |
| HARDCORE22 | cortlong50 | Damage blocks tuned. |
| Relentless | Cazanu | Its diagnostic log switched off; limb factor, mark limit and bleed-out time set in the 2.5 build. |
| NCA AV System ADDON | VfromNightCity | Arrival sound volume lowered from 0.5 to 0.2. |

## Earlier edits no longer in use

| Mod | Author | What was changed and why |
|---|---|---|
| Curbside - Improved Vehicle Summoning | not recorded | A "drive with traffic" option and a collision guard for summoned cars, which hit other cars; the mod was later removed. |
| Drone Companions 2.0 | not recorded | Repacked for game version 2.31 with a fix for a function two mods replaced; never installed. |
| ITP TFPC Compatibility Fix | djoole | Ported back to game version 2.31; later switched off and replaced by the 2.5 original. |
| Lore-Accurate Adam Smasher | Quinnnn21 | One name changed so it compiled on game version 2.31; on 2.5 the original is used. |
| Drive an Aerial Vehicle | tidusmd | Climb settings and a garage throttle (sound edits were reverted); the mod was later replaced by one of my own. |
| ANODOS Financial | Cyb3rPho3nix | Saving limited to every 300 seconds and key moments; later replaced by one of my own mods. |
| Marmur Bank Overhaul | Cyb3rPho3nix | Input early exits; the mod's signed file check refused the changed files, so it ran unchanged and was later removed. |
| Drone Companion | opaaaaaaaaaaaa | Input filter and cleaned lists; the author's later release has the same fixes, and the mod was later removed. |
| Untrack Quest Ultimate | anygoodname | Cache limit 3,000 to 600; later replaced by Keep Tracked Quest. |
| Enterable Interiors | Halliphax2 | Early exit in its input hook; no longer needed on 2.5, where the mod moved to redscript. |
