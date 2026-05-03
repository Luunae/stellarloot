# Changelog

## 0.2 — Stellar Loot

**Off-Spec Support (new)** — opt-in path for hybrids (e.g. Holy paladin / Prot off-spec). Picks up the off-spec primary stat via auto-detect (inactive talent group) or a manual override, and compares ilvl against an in-game Equipment Manager set you nominate. Without a set, off-spec items fall through to Greed with a clear trace reason.

**Disenchant dropped** — DE was outside the four-action mental model (Need / Greed / Manual / Pass). All DE code paths, the `preferDEoverGreed` config flag, the UI checkbox, the override action, and the slash references are gone.

**Slash commands** are `/stellarloot` (or `/sl`).

## 0.1 — Initial release

First public release. Automatic Need / Greed / Pass / Disenchant rolls for World of Warcraft Mists of Pandaria Classic (5.5.x).

**Decision pipeline** considers, in order: per-item overrides → master toggle → quality threshold → roll-option availability → class equip-ability → preferred armor type → tier-token class match → primary stat match → ilvl upgrade vs equipped → default Greed (with optional Disenchant preference).

**Configuration UI**
- Account-wide settings by default with optional per-character overrides.
- Quality and ilvl-upgrade filters with individual disable toggles.
- Fallback action selector (Greed / Pass / Need / Manual) for when item info doesn't load before the roll timer.
- Per-item overrides editor.
- **Log** sub-panel with embedded scrolling history, clickable item links, and a verbose toggle that expands each entry's full factor trace.

**Other behavior**
- Humanize delay (0.8–2.2s default) before rolling, capped to never miss the roll window.
- Defers decisions until item info loads; safety-falls-back to the configured action near roll expiry.
- Persistent decision log (200-entry circular buffer, account-wide).

**Known limitations** (planned for 1.0)
- Tier token data table is a stub — no specific token IDs are populated yet.

---

<sub>0.1 was published under the working name "AutoRoll" before the rename to Stellar Loot in 0.2.</sub>
