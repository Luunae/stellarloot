-- tests/cases/decision_cases.lua — curated table-driven cases for
-- Decision.Evaluate. Receives H (tests/helpers.lua) as the chunk vararg.
--
-- Case fields:
--   item      — itemID; link + name resolved from the fixture registry
--   synthetic — { [itemID] = record } added to the stub overlay for this case
--   ctx/cfg/roll — overrides for H.ctx / H.cfg / H.roll
--   expect    — { action = "NEED"|"GREED"|"PASS"|"DEFER"|"MANUAL"|"nil",
--                 rule = decisive rule tag from the trace }
--
-- Defaults: Retribution Paladin, every slot ilvl 480, Config.DEFAULTS
-- (requireILvlUpgrade=false — cases exercising the ilvl path set it true).
--
-- Anchor fixtures (see tests/fixtures/corpus.lua):
--   104462 Drape of the Despairing Pit    STR cloak, subclass Cloth, 566
--   87048  Breastplate of the Kings' Guard STR plate chest, 502
--   94731  Robes of Static Bursts          INT cloth robe, 522
--   104454 Norushen's Shortblade           AGI dagger, 566
--   94469  Tyrannical Gladiator's Wristguards of Accuracy  AGI+HIT mail, 496
--   94989  Lei Shen's Grounded Carapace    INT+SPIRIT plate chest, 522
--   96523  Delicate Vial of the Sanguinaire   effect trinket (dodge only), 535
--   99678  Chest of the Cursed Conqueror   tier token, 528
--   105858 Essence of the Cursed Conqueror wildcard tier token, 553

local H = ...

local SYNTH_TRINKET = {
    name = "Timeless Curio", quality = 4, ilvl = 496,
    itemType = "Armor", itemSubType = "Miscellaneous",
    equipLoc = "INVTYPE_TRINKET", classID = 4, subclassID = 0,
    stats = { ITEM_MOD_STAMINA_SHORT = 100 },
}

-- 99678 with a name no tier-token slot pattern recognizes.
local SYNTH_ODD_TOKEN = {
    name = "Mystery of the Cursed Conqueror", quality = 4, ilvl = 528,
    itemType = "Miscellaneous", itemSubType = "Junk",
    equipLoc = "INVTYPE_NON_EQUIP_IGNORE", classID = 15, subclassID = 0,
    stats = {},
}

return {
    -- ── Regression pins ─────────────────────────────────────────────────

    { name = "cloak: mainstat cloak is Need for plate wearer, ilvl mode (0.7.1)",
      item = 104462, cfg = { requireILvlUpgrade = true },
      expect = { action = "NEED", rule = "UPGRADE" } },

    { name = "cloak: mainstat cloak is Need for plate wearer, stat-only mode (0.7.1)",
      item = 104462,
      expect = { action = "NEED", rule = "STAT_MATCH_ANY_ILVL" } },

    { name = "master toggle beats per-item override (0.6.1)",
      item = 87048, cfg = { enabled = false, overrides = { [87048] = "NEED" } },
      expect = { action = "nil", rule = "DISABLED" } },

    { name = "per-item override honored when enabled",
      item = 87048, cfg = { overrides = { [87048] = "PASS" } },
      expect = { action = "PASS", rule = "USER_OVERRIDE" } },

    { name = "effect trinket: main-spec mapping match → ilvl upgrade (0.7.0)",
      item = 96523, ctx = { spec = 66 }, cfg = { requireILvlUpgrade = true },
      expect = { action = "NEED", rule = "UPGRADE" } },

    { name = "effect trinket: off-spec mapping match, no equipment set",
      item = 96523, ctx = { offspecSpecID = 66 }, cfg = { requireILvlUpgrade = true },
      expect = { action = "GREED", rule = "OFFSPEC_NO_SET" } },

    { name = "effect trinket: off-spec mapping match with set slot",
      item = 96523,
      ctx = { offspecSpecID = 66, sets = { Prot = { INVTYPE_TRINKET = 480 } } },
      cfg = { requireILvlUpgrade = true, offspec = { equipmentSet = "Prot" } },
      expect = { action = "NEED", rule = "UPGRADE" } },

    { name = "effect trinket: spec mismatch",
      item = 96523, ctx = { spec = 65 },
      expect = { action = "GREED", rule = "TRINKET_SPEC_MISMATCH" } },

    { name = "stat-less unmapped trinket → MANUAL (0.7.0)",
      item = 900001, synthetic = { [900001] = SYNTH_TRINKET },
      expect = { action = "MANUAL", rule = "TRINKET_UNKNOWN" } },

    { name = "extraStats: exact ITEM_MOD_* key matches (0.7.0)",
      item = 94989, cfg = { classOverrides = { extraStats = { "ITEM_MOD_SPIRIT_SHORT" } } },
      expect = { action = "NEED", rule = "STAT_MATCH_ANY_ILVL" } },

    { name = "extraStats: fragment matches via _SHORT form",
      item = 94989, cfg = { classOverrides = { extraStats = { "SPIRIT" } } },
      expect = { action = "NEED", rule = "STAT_MATCH_ANY_ILVL" } },

    { name = "extraStats: fragment matches via unsuffixed rating form",
      item = 94469, ctx = { spec = 262 },
      cfg = { classOverrides = { extraStats = { "HIT_RATING" } } },
      expect = { action = "NEED", rule = "STAT_MATCH_ANY_ILVL" } },

    { name = "extraStats control: no extras configured → wrong primary stat",
      item = 94469, ctx = { spec = 262 },
      expect = { action = "GREED", rule = "WRONG_PRIMARY_STAT" } },

    -- ── Step-chain coverage ─────────────────────────────────────────────

    { name = "armor not proficient: mage sees plate",
      item = 87048, ctx = { spec = 63 },
      expect = { action = "GREED", rule = "ARMOR_NOT_PROFICIENT" } },

    { name = "armor not proficient degrades to Pass when Greed unavailable",
      item = 87048, ctx = { spec = 63 }, roll = { canGreed = false },
      expect = { action = "PASS", rule = "ARMOR_NOT_PROFICIENT" } },

    { name = "weapon not proficient: paladin sees dagger",
      item = 104454,
      expect = { action = "GREED", rule = "WEAPON_NOT_PROFICIENT" } },

    { name = "wrong armor type: paladin sees cloth robe",
      item = 94731,
      expect = { action = "GREED", rule = "WRONG_ARMOR_TYPE" } },

    { name = "wrong armor type respects wrongArmorTypeAction=PASS",
      item = 94731, cfg = { wrongArmorTypeAction = "PASS" },
      expect = { action = "PASS", rule = "WRONG_ARMOR_TYPE" } },

    { name = "tier token: class match, redeemed slot is an upgrade",
      item = 99678, cfg = { requireILvlUpgrade = true },
      ctx = { equipped = { INVTYPE_CHEST = 480 } },
      expect = { action = "NEED", rule = "UPGRADE" } },

    { name = "tier token: class match but not an upgrade",
      item = 99678, cfg = { requireILvlUpgrade = true },
      ctx = { equipped = { INVTYPE_CHEST = 540 } },
      expect = { action = "GREED", rule = "DEFAULT" } },

    { name = "tier token: class mismatch (mage on Conqueror)",
      item = 99678, ctx = { spec = 63 },
      expect = { action = "GREED", rule = "TIER_TOKEN_MISMATCH" } },

    { name = "wildcard token compares against worst tier slot",
      item = 105858, cfg = { requireILvlUpgrade = true },
      ctx = { equipped = { INVTYPE_HEAD = 560, INVTYPE_SHOULDER = 560,
                           INVTYPE_CHEST = 480, INVTYPE_HAND = 560,
                           INVTYPE_LEGS = 560 } },
      expect = { action = "NEED", rule = "UPGRADE" } },

    { name = "tier token with unrecognized name defaults to Need",
      item = 99678, synthetic = { [99678] = SYNTH_ODD_TOKEN },
      expect = { action = "NEED", rule = "TIER_TOKEN_NEED_FALLBACK" } },

    { name = "ilvl: upgrade over equipped",
      item = 87048, cfg = { requireILvlUpgrade = true },
      ctx = { equipped = { INVTYPE_CHEST = 490 } },
      expect = { action = "NEED", rule = "UPGRADE" } },

    { name = "ilvl: equal is not an upgrade",
      item = 87048, cfg = { requireILvlUpgrade = true },
      ctx = { equipped = { INVTYPE_CHEST = 502 } },
      expect = { action = "GREED", rule = "DEFAULT" } },

    { name = "ilvl margin blocks a small upgrade",
      item = 87048, cfg = { requireILvlUpgrade = true, needILvlMargin = 15 },
      ctx = { equipped = { INVTYPE_CHEST = 490 } },
      expect = { action = "GREED", rule = "DEFAULT" } },

    { name = "ilvl margin passes a sufficient upgrade",
      item = 87048, cfg = { requireILvlUpgrade = true, needILvlMargin = 10 },
      ctx = { equipped = { INVTYPE_CHEST = 490 } },
      expect = { action = "NEED", rule = "UPGRADE" } },

    { name = "heirloom margin extra blocks replacement",
      item = 87048,
      cfg = { requireILvlUpgrade = true, heirloomNeedMarginExtra = 30 },
      ctx = { equipped = { INVTYPE_CHEST = { 480, heirloom = true } } },
      expect = { action = "GREED", rule = "DEFAULT" } },

    { name = "heirloom in slot without extra margin still upgrades",
      item = 87048, cfg = { requireILvlUpgrade = true },
      ctx = { equipped = { INVTYPE_CHEST = { 480, heirloom = true } } },
      expect = { action = "NEED", rule = "UPGRADE" } },

    { name = "off-spec stat match compares against equipment set",
      item = 94989, cfg = { requireILvlUpgrade = true, offspec = { equipmentSet = "Holy" } },
      ctx = { offspecPrimaryStat = 4, sets = { Holy = { INVTYPE_CHEST = 480 } } },
      expect = { action = "NEED", rule = "UPGRADE" } },

    { name = "off-spec set has no item in the slot",
      item = 94989, cfg = { requireILvlUpgrade = true, offspec = { equipmentSet = "Holy" } },
      ctx = { offspecPrimaryStat = 4, sets = { Holy = {} } },
      expect = { action = "GREED", rule = "OFFSPEC_SET_SLOT_EMPTY" } },

    { name = "no roll options available",
      item = 87048, roll = { canNeed = false, canGreed = false },
      expect = { action = "PASS", rule = "NO_ROLL_OPTIONS" } },

    { name = "uncached item defers",
      item = 999999,
      expect = { action = "DEFER", rule = "ITEM_INFO_PENDING" } },

    { name = "nonUpgradeAction=PASS applies to the default outcome",
      item = 87048,
      cfg = { requireILvlUpgrade = true, nonUpgradeAction = "PASS" },
      ctx = { equipped = { INVTYPE_CHEST = 502 } },
      expect = { action = "PASS", rule = "DEFAULT" } },
}
