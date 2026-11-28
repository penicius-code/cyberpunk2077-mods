# Cashflow

Records every change of V's money with its source, shows a morning statement and writes a CSV file you can analyse. Single-player only.
Version 1.1.1 | For game version 2.5 (1.0.3 was built on 2.31) | Status: not run in game yet; no in-game result for earlier versions either; 1.1.0 and 1.1.1 compile on 2.5

## What and why

The game never tells you where your eddies went. This mod watches V's money and books every change under a source:

- A vanilla inventory listener on V reports every change of eddies (amount and new balance), whoever moved them: game code, redscript or CET mods.
- Hooks around the vanilla code that moves money tag the change: trade screens (sales and shopping), the ripperdoc chair, job and gig rewards, NCPD bounties, looted cash, vending machines, car purchases, Delamain cabs, and Night City Finance taxes and fees if that mod is installed. Untagged changes are booked as "other". Money swaps in cinematics and braindances are booked as "scene" and left out of the statements.
- Each game morning (default 07:00) a HUD line shows money in and out by source for the last game day, the net and the balance.
- Every change is also written to `r6\storages\CyberslopCashflow\cashflow.txt` (CSV text: game day, clock, real seconds since launch, amount, balance, source, detail), plus a heartbeat line every 5 minutes.

The mod is read-only: it never changes an amount. Other mods can tag their own money changes by calling `CashflowBook.TagNow(gi, CashflowCat.X(), "detail", seconds)` right before they move money; Bounty Ledger, Chrome Upkeep and Bank in this collection do that when Cashflow is installed.

```text
package/
  r6/scripts/zz_CyberslopCashflow/CyberslopCashflow.reds   listener, tags, statement, file writer
tools/
  cashflow_report.py   prints money per source, per real hour and per game day from cashflow.txt (runs outside the game)
```

## Requirements

- Cyberpunk 2077 (built on 2.31; not tested on 2.5)
- [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511)
- [Codeware](https://www.nexusmods.com/cyberpunk2077/mods/7780)
- [Mod Settings](https://www.nexusmods.com/cyberpunk2077/mods/4885) (the script calls it directly and does not compile without it)
- [RedFileSystem](https://www.nexusmods.com/cyberpunk2077/mods/13378) (writes `cashflow.txt`; the script does not compile without it)
- Python 3, only for the optional report script

Optional: Night City Finance (its taxes and fees get their own source).

Requirements are not bundled. Install them first.

## Install

1. Install the requirements above.
2. Copy the contents of `package/` into the game folder, so that `r6\scripts\zz_CyberslopCashflow\CyberslopCashflow.reds` exists.
3. Start the game and load a save. Mod Settings shows "Cyberslop Cashflow". After the first money change, `r6\storages\CyberslopCashflow\cashflow.txt` exists.
4. Optional report: run `python cashflow_report.py <path to cashflow.txt>`. Without a path it reads `r6\storages\CyberslopCashflow\cashflow.txt` below the current folder, so it also works when started from the game folder. `--days N` limits the per-day table to the last N game days.

## Uninstall / roll back

1. Close the game.
2. Delete:
   - `r6\scripts\zz_CyberslopCashflow\`
   - `r6\storages\CyberslopCashflow\` (the money log)
3. The statement totals are stored in the save. Without the mod the game does not read them.
4. To restore an unmodified game, verify the game files in your launcher.

## Configuration

Mod Settings > Cyberslop Cashflow:

| Category | Setting | Default | Range |
|---|---|---|---|
| General | Enabled | on | |
| Statement | Morning statement | on | |
| Statement | Statement hour | 7 | 0 to 23 |
| Statement | Transaction lines (a HUD line per large change) | off | |
| Statement | Transaction line minimum (eddies) | 500 | 0 to 10000 |
| Records | Write cashflow.txt | on | |
| Records | Log to CET gamelog | off | |

## Known issues

- `cashflow.txt` grows for as long as the mod runs; it is not trimmed. Delete it to start over.

## Changelog

| Version | Date | Game version | Change |
|---|---|---|---|
| 1.1.1 | 2026-11-26 | 2.5 | A money change handled after the player detached (a load or quit in the same frame) is booked instead of dropped; the pre-game attach drops an old listener first; the menu state is set before the menu counts as open. Only visible as correct rows around loads. |
| 1.1.0 | 2026-11-26 | 2.5 | Thread safety: money changes and source tags are queued as requests and only the book's own handlers touch its lists (the item events run on parallel job threads in 2.x, and a push from there can corrupt a list; a game crash was traced to such a push). Out-of-range tag categories book as "other"; no double booking after a second attach; null guards for the settings. Statements, `cashflow.txt` and the report are unchanged. |
| 1.0.3 | 2026-11-07 | 2.31 | No fake row per launch from the main menu's pre-game session |
| 1.0.2 | 2026-11-06 | 2.31 | Review fixes: kill loot booked as jobs, bounty tags only for paid events |
| 1.0.1 | 2026-11-06 | 2.31 | Buffered file writes, tag fixes |
| 1.0.0 | 2026-11-06 | 2.31 | Listener, source tags, morning statement, CSV file, report script |

Back to the [mod list](../../README.md).
