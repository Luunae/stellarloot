# Stellar Loot

Automatic Need / Greed / Pass rolls for World of Warcraft Mists of Pandaria Classic (5.5.x).

Set rules once, then stop thinking about loot.

## What it does

Watches for group-loot rolls and decides for you based on your **class**, **current spec**, **off-spec** (optional), and **equipped gear**.

Default behavior:

- **Need** items that match your spec's primary stat.
- **Need** items that match your **off-spec**'s primary stat (opt-in).
- **Greed** anything else your class can use, including the wrong armor type or wrong primary stat.
- **Pass** when no Greed roll is offered.

Item-level filtering is **off by default** — ilvl is an unreliable signal of item value across expansions and on irregularly-budgeted items (PvP gear, BoAs, heirlooms). Turn it on in the options panel for stricter endgame behavior; when enabled, Need additionally requires the incoming item to exceed your equipped piece's ilvl by the configured margin, and heirlooms are scored against a single synthetic ilvl (`Data.HEIRLOOM_ILVL = 400`) rather than their API-reported value of 1.

## Install

Via the CurseForge addon downloader, or manually: drop the contents of this repo into `Interface/AddOns/StellarLoot/` (file paths must end up at e.g. `Interface/AddOns/StellarLoot/StellarLoot.toc`).

## First-run quick-start

1. `/stellarloot status` — verify the addon detected your class, spec, and primary stat.
2. `/stellarloot test` — enable test mode (it prints decisions but does not actually roll).
3. Run a dungeon or LFR. Watch the chat output as items drop.
4. When you're satisfied, `/stellarloot test` again to disable dry-run.
5. `/stellarloot toggle` is the panic button to disable everything.

## Slash commands

| Command | What it does |
|---|---|
| `/stellarloot` | Open the config panel (also under Esc → Interface → AddOns → Stellar Loot) |
| `/stellarloot status` | Print spec, primary stat, off-spec, key thresholds |
| `/stellarloot toggle` | Enable/disable the addon |
| `/stellarloot test` | Toggle dry-run mode (prints decisions, does not roll) |
| `/stellarloot verbose` | Toggle full factor-by-factor logging |
| `/stellarloot perchar` | Toggle per-character settings on this character (default is account-wide) |
| `/stellarloot log [N]` | Print the last N decisions to chat (default 20) |
| `/stellarloot log open` | Open the Decision Log sub-panel |
| `/stellarloot log clear` | Wipe saved history |
| `/stellarloot override <itemID> <need\|greed\|pass\|clear>` | Force a specific action for an item |
| `/stellarloot eval <itemLink>` | Print what the addon *would* decide for the linked item right now |
| `/stellarloot heirloom <itemLink>` | Show heirloom recognition + ilvl resolution (debug aid for cataloging) |

`/sl` is registered as a short alias.

## Off-Spec Support

If you regularly play a second spec (e.g. Holy paladin / Prot off-spec), Stellar Loot can Need items that match its primary stat too.

1. **(Only if ilvl filtering is on)** Save your off-spec gear as an Equipment Manager set in-game (Character → Equipment Manager). This is the comparison baseline for off-spec ilvl checks — if there's no set, off-spec items fall through to Greed. With ilvl filtering off (the default), the set is not required.
2. Open the config panel and pick the off-spec source: **Auto-detect** reads your inactive talent group's primary stat; **Manual** lets you pick (use this if you haven't trained your second spec yet).
3. Pick that equipment set in the off-spec dropdown.

Off-spec rolls compare against the items in the chosen set, **not** your currently-equipped gear.

## Logging

Every automatic roll prints a one-line summary in chat by default:

```
StellarLoot GREED [Robe of Glowing Stone] — wrong armor type: Cloth (class prefers Plate)
```

With **verbose** logging enabled, every check that ran is shown:

```
StellarLoot GREED [Robe of Glowing Stone]
  · addon enabled
  · item: Robe of Glowing Stone (q4, ilvl 522, Armor/Cloth, equipLoc INVTYPE_CHEST)
  · quality Epic ≥ threshold Uncommon
  · roll options: Need=true Greed=true
  · class PALADIN can equip Cloth armor
  → wrong armor type: Cloth (class prefers Plate)
```

Test mode prefixes every line with `WOULD ` so dry-runs are visually distinct.

The `/stellarloot eval <link>` command always prints the verbose trace and is the primary tool for debugging "why did it do that?" questions — drag any item from your bags into chat and run it.

## Configuration

Open the panel via `/stellarloot` or under **Esc → Interface → AddOns → Stellar Loot**.

Settings are **account-wide by default**. The first checkbox on the panel ("Use per-character settings on this character") seeds a per-character copy from your account-wide settings the first time you enable it; toggling it back off restores the account-wide settings (and preserves the per-character copy for next time).

The main panel has:

- **Roll Behavior** — master toggle and test mode.
- **Upgrades** — opt-in ilvl-margin requirement for Need rolls (off by default).
- **Off-Spec Support** — source (off / auto-detect / manual), manual primary-stat picker, and the equipment-set selector (only used when ilvl filtering is on).
- **Fallback Action** — what to do when item info doesn't load before the roll timer expires (Greed / Pass / Need / Manual).
- **Per-item overrides** — force specific actions on specific items (also editable via the `override` slash command).

The **Log** sub-panel (nested under Stellar Loot in the Settings tree) shows the recent decision history with clickable item links. A **Verbose** checkbox in the sub-panel expands each entry to show every factor the decision considered.

## Distribution

Releases are auto-packaged to CurseForge by CF's native packager on annotated tag push (`vX.Y.Z`). Lightweight tags are silently ignored.

## Contributing

If something looks wrong, feel free to let me know via comment, issue, or PR, even for things like typos.
I'll notice interactions faster on Github than CurseForge, though.
