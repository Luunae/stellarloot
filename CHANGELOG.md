# Changelog

## 0.4.0 — Tier token data

**Tier tokens populated** — `Data.TierTokens` now covers Pandaria raid tier sets T14 (Mogu'shan Vaults / Heart of Fear / Terrace of Endless Spring), T15 (Throne of Thunder), and T16 (Siege of Orgrimmar), including the Heroic Garrosh "Essence of the Cursed" wildcard tokens. 111 item IDs, organized by `Data.TierTokenGroups` (Vanquisher / Protector / Conqueror).

**Tier token ilvl in trace** — the in-game tooltip on a tier token doesn't reveal the ilvl of the gear it redeems for. The decision trace now includes that ilvl alongside every `TIER_TOKEN_MATCH`, `TIER_TOKEN_MISMATCH`, and `TIER_TOKEN_NEED` factor, so `/sl eval <itemLink>` makes the LFR/Normal/Heroic difference visible.

**Options panel sync fix** — the modern Settings canvas API doesn't auto-call `panel.refresh()` on show, so widgets sat in their default visual state on every login and clicking Okay parsed an empty overrides edit box, wiping the saved overrides table. The panel now refreshes on `OnShow`. Saved data itself was always intact; only the UI was out of sync.

**Version in panel title** — the options panel title now shows the addon version from the `.toc`, with a `(dev)` marker for unsubstituted `@project-version@` or non-semver values, so it's obvious when running a local build vs a tagged release.

## 0.3.1 — Drop humanize delay

Removed the 0.8–2.2s pre-roll delay (and its config block). It served no real purpose — the loot client doesn't care how fast a roll arrives, and the delay only added latency between item drops and the addon's response. Rolls are now submitted as soon as the decision is made.

Also: added a brief Contributing note to the README.

## 0.3 — Auto-confirm

**Auto-confirm BoP popup (new)** — when the addon submits a roll on a bind-on-pickup item and the client prompts "looting this will bind it to you, do you want to loot it?", the addon now accepts the prompt automatically. Only rolls the addon itself submitted are confirmed; bind dialogs from picking up unrolled loot remain the player's responsibility. Test mode is unaffected (no real roll → nothing to confirm).

**Off-spec equipment set dropdown fix** — the "Off-spec equipment set" dropdown was empty even when equipment sets existed. The legacy `GetNumEquipmentSets` global was removed in Legion (7.0.3) and MoP Classic 5.5.x runs on the modern client, so the addon now uses the `C_EquipmentSet` namespace for both enumeration and per-slot lookups.

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

---

<sub>0.1 was published under the working name "AutoRoll" before the rename to Stellar Loot in 0.2.</sub>
