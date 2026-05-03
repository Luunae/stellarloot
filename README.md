# AutoRoll

Automatic Need / Greed / Pass / Disenchant rolls for World of Warcraft Mists of Pandaria Classic (5.5.x).

## What it does

Watches for group-loot rolls and decides for you based on your **class**, **current spec**, and **equipped gear**.

Default behavior:

- **Need** items that match your spec's primary stat *and* are an item-level upgrade over what you have equipped in that slot.
- **Greed** anything else your class can use — the wrong armor type, the wrong primary stat, items below upgrade threshold, etc.
- **Pass** on items below the configured quality threshold or that your class literally cannot equip (when "Greed unusable" is off).
- **Disenchant** instead of Greed when you're an enchanter with sufficient skill (configurable).

A short "humanize" delay (0.8–2.2s by default) is applied before rolling so it doesn't look botted.

## Install

Via the CurseForge addon downloader, or manually: drop the contents of this repo into `Interface/AddOns/AutoRoll/` (file paths must end up at e.g. `Interface/AddOns/AutoRoll/AutoRoll.toc`).

## First-run quick-start

1. `/autoroll status` — verify the addon detected your class, spec, and primary stat.
2. `/autoroll test` — enable test mode (it prints decisions but does not actually roll).
3. Run a dungeon or LFR. Watch the chat output as items drop.
4. When you're satisfied, `/autoroll test` again to disable dry-run.
5. `/autoroll toggle` is the panic button to disable everything.

## Slash commands

| Command | What it does |
|---|---|
| `/autoroll` | Open the config panel (also under Esc → Interface → AddOns → AutoRoll) |
| `/autoroll status` | Print spec, primary stat, enchanting skill, key thresholds |
| `/autoroll toggle` | Enable/disable the addon |
| `/autoroll test` | Toggle dry-run mode (prints decisions, does not roll) |
| `/autoroll verbose` | Toggle full factor-by-factor logging |
| `/autoroll perchar` | Toggle per-character settings on this character (default is account-wide) |
| `/autoroll log [N]` | Print the last N decisions to chat (default 20) |
| `/autoroll log open` | Open the Decision Log sub-panel |
| `/autoroll log clear` | Wipe saved history |
| `/autoroll override <itemID> <need\|greed\|pass\|de\|clear>` | Force a specific action for an item |
| `/autoroll eval <itemLink>` | Print what the addon *would* decide for the linked item right now |

`/ar` is registered as a short alias.

## Logging

Every automatic roll prints a one-line summary in chat by default:

```
AutoRoll GREED [Robe of Glowing Stone] — wrong armor type: Cloth (class prefers Plate)
```

With **verbose** logging enabled, every check that ran is shown:

```
AutoRoll GREED [Robe of Glowing Stone]
  · addon enabled
  · item: Robe of Glowing Stone (q4, ilvl 522, Armor/Cloth, equipLoc INVTYPE_CHEST)
  · quality Epic ≥ threshold Uncommon
  · roll options: Need=true Greed=true DE=false
  · class PALADIN can equip Cloth armor
  → wrong armor type: Cloth (class prefers Plate)
```

Test mode prefixes every line with `WOULD ` so dry-runs are visually distinct.

The `/autoroll eval <link>` command always prints the verbose trace and is the primary tool for debugging "why did it do that?" questions — drag any item from your bags into chat and run it.

## Configuration

Open the panel via `/autoroll` or under **Esc → Interface → AddOns → AutoRoll**.

Settings are **account-wide by default**. The first checkbox on the panel ("Use per-character settings on this character") seeds a per-character copy from your account-wide settings the first time you enable it; toggling it back off restores the account-wide settings (and preserves the per-character copy for next time).

The main panel has:

- **Roll Behavior** — master toggle, test mode, DE preference, what to do with unusable items.
- **Quality & Upgrades** — minimum quality threshold (with disable toggle), ilvl margin required for Need rolls (with disable toggle).
- **Fallback action** — what to do when item info doesn't load before the roll timer expires (Greed / Pass / Need / Manual).
- **Per-item overrides** — force specific actions on specific items (also editable via the `override` slash command).

The **Log** sub-panel (nested under AutoRoll in the Settings tree) shows the recent decision history with clickable item links. A **Verbose** checkbox in the sub-panel expands each entry to show every factor the decision considered.

## Distribution

This repository auto-publishes to CurseForge via the [BigWigs Packager](https://github.com/BigWigsMods/packager) GitHub Action on tag push (`vX.Y.Z`). Set the `CF_API_KEY` repo secret first.
