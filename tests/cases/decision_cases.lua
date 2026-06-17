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

-- Spirit + Stamina, no primary stat: a healer's effect trinket. On a
-- non-healer it's foreign, not opaque — greeds via the unusable path.
local SYNTH_SPIRIT_TRINKET = {
    name = "Empty Fruit Barrel (synthetic)", quality = 4, ilvl = 463,
    itemType = "Armor", itemSubType = "Miscellaneous",
    equipLoc = "INVTYPE_TRINKET", classID = 4, subclassID = 0,
    stats = { ITEM_MOD_SPIRIT_SHORT = 847, ITEM_MOD_STAMINA_SHORT = 100 },
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

    { name = "effect-only trinket → GREED by default (grabby; 0.8.0)",
      item = 900001, synthetic = { [900001] = SYNTH_TRINKET },
      expect = { action = "GREED", rule = "TRINKET_UNKNOWN" } },

    { name = "effect-only trinket → MANUAL when configured (careful mode)",
      item = 900001, synthetic = { [900001] = SYNTH_TRINKET },
      cfg = { unjudgeableTrinketAction = "MANUAL" },
      expect = { action = "MANUAL", rule = "TRINKET_UNKNOWN" } },

    { name = "Spirit trinket on a non-healer is foreign → greed, never MANUAL",
      item = 900002, synthetic = { [900002] = SYNTH_SPIRIT_TRINKET },
      ctx = { spec = 66 },  -- Prot Paladin: Str primary, not a healer
      cfg = { unjudgeableTrinketAction = "MANUAL" },  -- careful mode still must not nag
      expect = { action = "GREED", rule = "WRONG_PRIMARY_STAT" } },

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

    { name = "weapon not proficient: warrior sees gun (MoP removed ranged; QC pass 2026-06-11)",
      item = 86331, ctx = { spec = 73 },
      expect = { action = "GREED", rule = "WEAPON_NOT_PROFICIENT" } },

    { name = "weapon not proficient: rogue sees gun (MoP removed ranged)",
      item = 86331, ctx = { spec = 260 },
      expect = { action = "GREED", rule = "WEAPON_NOT_PROFICIENT" } },

    { name = "mount is not gear → MANUAL (QC pass 2026-06-11)",
      item = 87771,
      expect = { action = "MANUAL", rule = "NOT_GEAR" } },

    { name = "battle pet is not gear → MANUAL",
      item = 104158,
      expect = { action = "MANUAL", rule = "NOT_GEAR" } },

    { name = "nonGearAction=GREED sweeps a mount to Greed",
      item = 87771,
      cfg = { nonGearAction = "GREED" },
      expect = { action = "GREED", rule = "NOT_GEAR" } },

    { name = "nonGearAction=PASS sweeps a mount to Pass",
      item = 87771,
      cfg = { nonGearAction = "PASS" },
      expect = { action = "PASS", rule = "NOT_GEAR" } },

    { name = "nonGearAction=NEED needs a mount when the game offers Need",
      item = 87771,
      cfg = { nonGearAction = "NEED" },
      expect = { action = "NEED", rule = "NOT_GEAR" } },

    { name = "nonGearAction=NEED degrades to Greed when Need isn't offered",
      item = 87771,
      cfg = { nonGearAction = "NEED" },
      roll = { canNeed = false },
      expect = { action = "GREED", rule = "NOT_GEAR" } },

    { name = "wrong armor type: paladin sees cloth robe",
      item = 94731,
      expect = { action = "GREED", rule = "WRONG_ARMOR_TYPE" } },

    { name = "wrong armor type respects wrongArmorTypeAction=PASS",
      item = 94731, cfg = { wrongArmorTypeAction = "PASS" },
      expect = { action = "PASS", rule = "WRONG_ARMOR_TYPE" } },

    { name = "wrongArmorTypeAction=MANUAL leaves an off-type item for the player",
      item = 94731, cfg = { wrongArmorTypeAction = "MANUAL" },
      expect = { action = "MANUAL", rule = "WRONG_ARMOR_TYPE" } },

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

    { name = "nonUpgradeAction=NEED lets a player Need a usable non-upgrade",
      item = 87048,
      cfg = { requireILvlUpgrade = true, nonUpgradeAction = "NEED" },
      ctx = { equipped = { INVTYPE_CHEST = 502 } },
      expect = { action = "NEED", rule = "DEFAULT" } },

    { name = "nonUpgradeAction=MANUAL leaves a non-upgrade for the player",
      item = 87048,
      cfg = { requireILvlUpgrade = true, nonUpgradeAction = "MANUAL" },
      ctx = { equipped = { INVTYPE_CHEST = 502 } },
      expect = { action = "MANUAL", rule = "DEFAULT" } },
}
