# Changelog

## 0.5.0 — Stat-only default, simpler everywhere

**Ilvl-upgrade requirement now defaults OFF.** Decisions default to "stat-matching item → Need" without an ilvl-delta check. Item level is an unreliable signal of item value: it skews wildly across expansions, on PvP gear, on BoAs, and on heirlooms (which report ilvl 1 in inventory). Stat-match is the more honest "do I want this?" signal. Existing users keep their saved setting; only fresh installs (and `Reset`) pick up the new default. Toggle **Need only on item-level upgrades** in the options panel for stricter endgame behavior.

**Stat-only mode skips the off-spec equipment set requirement.** Previously off-spec match required an in-game equipment set as the ilvl comparison source. With ilvl filtering off, the set is no longer needed; off-spec stat matches Need outright. The set is still used when ilvl filtering is on.

**Heirloom handling** — quality-7 heirlooms now substitute a single flat synthetic ilvl (`Data.HEIRLOOM_ILVL = 400`) anywhere their effective ilvl is computed. Previously they reported ilvl 1 to the API and triggered false Needs on every drop when ilvl filtering was on. Effective-ilvl resolution is centralized in `Data.EffectiveILvl` so the equipped side, the incoming side, and the equipment-set side all share the same logic.

**`/sl heirloom <link>` debug helper** — confirms whether an item is recognized as a heirloom and prints both the API-reported and the effective ilvl.

**Fixed: equipped item level could stick at 0 after login.** `RefreshAllSlots` runs once at `PLAYER_LOGIN`, when an equipped item often isn't in the client cache yet — `GetDetailedItemLevelInfo`/`GetItemInfo` then return 0, and the slot was only re-read on `PLAYER_EQUIPMENT_CHANGED` (which fires only when gear actually changes). A slot that read 0 stayed 0 for the whole session, so every same-slot roll compared against 0 and triggered a false Need. Slots that resolve to 0 are now tracked and re-read on `GET_ITEM_INFO_RECEIVED` once the item finishes loading.

**Verbose logging now covers equipped-slot refresh.** With `/sl verbose` on, the addon logs when a slot's item level can't be read at login — queued for a deferred re-read — and again when that re-read resolves it. Silent unless verbose is enabled; a way to confirm the fix above engaged.

**Removed: quality filter.** The `minQuality` / `qualityFilterEnabled` config and its UI row are gone — group loot does not surface sub-Uncommon items, so the filter was dead weight.

**Removed: `greedUnusable` toggle.** Items the class cannot equip now always Greed (Pass if Greed isn't offered). The previous opt-out toggle and its UI row are gone.

**Optional heirloom stickiness retained** — config `heirloomNeedMarginExtra` (default 0) still exists as a hidden knob; when set and ilvl filtering is on, it pads the upgrade margin required to displace a heirloom.

## 0.4.2 — Fix version display (for real this time)

**Version in panel title now actually resolves on CF builds** — the 0.4.0 panel-title check used a bare `"@project-version@"` literal in `ConfigUI.lua` to detect unsubstituted dev builds. The CF packager's keyword substitution runs across `.lua` too (not just `.toc`), so on a packaged release that literal got replaced with the real version (e.g. `"v0.4.1"`), turning the guard into `if v == "v0.4.1" then return "(dev)" end` — self-defeating. The placeholder is now assembled at runtime from two strings, so the packager's text replacement leaves it intact. 0.4.1's `C_AddOns.GetAddOnMetadata` fallback was correct as defensive code but did not address this bug.

## 0.4.1 — Fix version display

**Version in panel title now resolves** — the 0.4.0 lookup used the global `GetAddOnMetadata`, which has been moved to `C_AddOns.GetAddOnMetadata` on modern clients (including MoP Classic 5.5.0). The global was nil, so the title fell back to `(dev)` even on a properly-packaged release. Now prefers `C_AddOns.GetAddOnMetadata` and falls back to the global.

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
