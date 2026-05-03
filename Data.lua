-- StellarLoot/Data.lua
-- Static reference tables: class proficiency, spec→primary stat, equipLoc→inventory slot.

local Data = {}
StellarLoot.Data = Data

-- Localized armor subtype strings come from GlobalStrings; we pin the localized
-- names at runtime via GetItemSubClassInfo to stay locale-safe.
-- Item class IDs (Enum.ItemClass.*) — kept as numeric literals because the Enum
-- table is not guaranteed in MoP Classic.
Data.ITEM_CLASS_WEAPON = 2
Data.ITEM_CLASS_ARMOR  = 4

-- Armor subclass IDs (Enum.ItemArmorSubclass.*)
Data.ARMOR_GENERIC = 0  -- cloaks live here
Data.ARMOR_CLOTH   = 1
Data.ARMOR_LEATHER = 2
Data.ARMOR_MAIL    = 3
Data.ARMOR_PLATE   = 4
Data.ARMOR_SHIELD  = 6

-- Weapon subclass IDs (Enum.ItemWeaponSubclass.*)
Data.WEAPON_AXE_1H     = 0
Data.WEAPON_AXE_2H     = 1
Data.WEAPON_BOW        = 2
Data.WEAPON_GUN        = 3
Data.WEAPON_MACE_1H    = 4
Data.WEAPON_MACE_2H    = 5
Data.WEAPON_POLEARM    = 6
Data.WEAPON_SWORD_1H   = 7
Data.WEAPON_SWORD_2H   = 8
Data.WEAPON_STAFF      = 10
Data.WEAPON_FIST       = 13
Data.WEAPON_DAGGER     = 15
Data.WEAPON_THROWN     = 16
Data.WEAPON_CROSSBOW   = 18
Data.WEAPON_WAND        = 19

-- Class → set of armor subclass IDs the class can equip at max level.
-- (Pre-40 hunters/shamans/plate classes wear lower types, but since MoP is at
-- the level cap and lower level rolls are rare, we use endgame proficiency.)
Data.ClassArmor = {
    WARRIOR     = { [Data.ARMOR_GENERIC]=true, [Data.ARMOR_CLOTH]=true, [Data.ARMOR_LEATHER]=true, [Data.ARMOR_MAIL]=true, [Data.ARMOR_PLATE]=true, [Data.ARMOR_SHIELD]=true },
    PALADIN     = { [Data.ARMOR_GENERIC]=true, [Data.ARMOR_CLOTH]=true, [Data.ARMOR_LEATHER]=true, [Data.ARMOR_MAIL]=true, [Data.ARMOR_PLATE]=true, [Data.ARMOR_SHIELD]=true },
    DEATHKNIGHT = { [Data.ARMOR_GENERIC]=true, [Data.ARMOR_CLOTH]=true, [Data.ARMOR_LEATHER]=true, [Data.ARMOR_MAIL]=true, [Data.ARMOR_PLATE]=true },
    HUNTER      = { [Data.ARMOR_GENERIC]=true, [Data.ARMOR_CLOTH]=true, [Data.ARMOR_LEATHER]=true, [Data.ARMOR_MAIL]=true },
    SHAMAN      = { [Data.ARMOR_GENERIC]=true, [Data.ARMOR_CLOTH]=true, [Data.ARMOR_LEATHER]=true, [Data.ARMOR_MAIL]=true, [Data.ARMOR_SHIELD]=true },
    ROGUE       = { [Data.ARMOR_GENERIC]=true, [Data.ARMOR_CLOTH]=true, [Data.ARMOR_LEATHER]=true },
    DRUID       = { [Data.ARMOR_GENERIC]=true, [Data.ARMOR_CLOTH]=true, [Data.ARMOR_LEATHER]=true },
    MONK        = { [Data.ARMOR_GENERIC]=true, [Data.ARMOR_CLOTH]=true, [Data.ARMOR_LEATHER]=true },
    MAGE        = { [Data.ARMOR_GENERIC]=true, [Data.ARMOR_CLOTH]=true },
    PRIEST      = { [Data.ARMOR_GENERIC]=true, [Data.ARMOR_CLOTH]=true },
    WARLOCK     = { [Data.ARMOR_GENERIC]=true, [Data.ARMOR_CLOTH]=true },
}

-- Class → preferred armor subclass at endgame (the spec bonus type).
Data.ClassPreferredArmor = {
    WARRIOR     = Data.ARMOR_PLATE,
    PALADIN     = Data.ARMOR_PLATE,
    DEATHKNIGHT = Data.ARMOR_PLATE,
    HUNTER      = Data.ARMOR_MAIL,
    SHAMAN      = Data.ARMOR_MAIL,
    ROGUE       = Data.ARMOR_LEATHER,
    DRUID       = Data.ARMOR_LEATHER,
    MONK        = Data.ARMOR_LEATHER,
    MAGE        = Data.ARMOR_CLOTH,
    PRIEST      = Data.ARMOR_CLOTH,
    WARLOCK     = Data.ARMOR_CLOTH,
}

-- Class → set of weapon subclass IDs equippable.
Data.ClassWeapons = {
    WARRIOR = {
        [Data.WEAPON_AXE_1H]=true, [Data.WEAPON_AXE_2H]=true, [Data.WEAPON_MACE_1H]=true,
        [Data.WEAPON_MACE_2H]=true, [Data.WEAPON_SWORD_1H]=true, [Data.WEAPON_SWORD_2H]=true,
        [Data.WEAPON_POLEARM]=true, [Data.WEAPON_STAFF]=true, [Data.WEAPON_FIST]=true,
        [Data.WEAPON_DAGGER]=true, [Data.WEAPON_BOW]=true, [Data.WEAPON_CROSSBOW]=true,
        [Data.WEAPON_GUN]=true, [Data.WEAPON_THROWN]=true,
    },
    PALADIN = {
        [Data.WEAPON_AXE_1H]=true, [Data.WEAPON_AXE_2H]=true, [Data.WEAPON_MACE_1H]=true,
        [Data.WEAPON_MACE_2H]=true, [Data.WEAPON_SWORD_1H]=true, [Data.WEAPON_SWORD_2H]=true,
        [Data.WEAPON_POLEARM]=true,
    },
    DEATHKNIGHT = {
        [Data.WEAPON_AXE_1H]=true, [Data.WEAPON_AXE_2H]=true, [Data.WEAPON_MACE_1H]=true,
        [Data.WEAPON_MACE_2H]=true, [Data.WEAPON_SWORD_1H]=true, [Data.WEAPON_SWORD_2H]=true,
        [Data.WEAPON_POLEARM]=true,
    },
    HUNTER = {
        [Data.WEAPON_AXE_1H]=true, [Data.WEAPON_AXE_2H]=true, [Data.WEAPON_SWORD_1H]=true,
        [Data.WEAPON_SWORD_2H]=true, [Data.WEAPON_POLEARM]=true, [Data.WEAPON_STAFF]=true,
        [Data.WEAPON_FIST]=true, [Data.WEAPON_DAGGER]=true,
        [Data.WEAPON_BOW]=true, [Data.WEAPON_CROSSBOW]=true, [Data.WEAPON_GUN]=true,
    },
    SHAMAN = {
        [Data.WEAPON_AXE_1H]=true, [Data.WEAPON_AXE_2H]=true, [Data.WEAPON_MACE_1H]=true,
        [Data.WEAPON_MACE_2H]=true, [Data.WEAPON_STAFF]=true, [Data.WEAPON_FIST]=true,
        [Data.WEAPON_DAGGER]=true,
    },
    ROGUE = {
        [Data.WEAPON_AXE_1H]=true, [Data.WEAPON_MACE_1H]=true, [Data.WEAPON_SWORD_1H]=true,
        [Data.WEAPON_FIST]=true, [Data.WEAPON_DAGGER]=true, [Data.WEAPON_THROWN]=true,
        [Data.WEAPON_BOW]=true, [Data.WEAPON_CROSSBOW]=true, [Data.WEAPON_GUN]=true,
    },
    DRUID = {
        [Data.WEAPON_MACE_1H]=true, [Data.WEAPON_MACE_2H]=true, [Data.WEAPON_POLEARM]=true,
        [Data.WEAPON_STAFF]=true, [Data.WEAPON_FIST]=true, [Data.WEAPON_DAGGER]=true,
    },
    MONK = {
        [Data.WEAPON_AXE_1H]=true, [Data.WEAPON_MACE_1H]=true, [Data.WEAPON_SWORD_1H]=true,
        [Data.WEAPON_STAFF]=true, [Data.WEAPON_POLEARM]=true, [Data.WEAPON_FIST]=true,
    },
    MAGE = {
        [Data.WEAPON_SWORD_1H]=true, [Data.WEAPON_STAFF]=true, [Data.WEAPON_DAGGER]=true,
        [Data.WEAPON_WAND]=true,
    },
    PRIEST = {
        [Data.WEAPON_MACE_1H]=true, [Data.WEAPON_STAFF]=true, [Data.WEAPON_DAGGER]=true,
        [Data.WEAPON_WAND]=true,
    },
    WARLOCK = {
        [Data.WEAPON_SWORD_1H]=true, [Data.WEAPON_STAFF]=true, [Data.WEAPON_DAGGER]=true,
        [Data.WEAPON_WAND]=true,
    },
}

-- GetSpecializationInfo primaryStat values
Data.STAT_STRENGTH  = 1
Data.STAT_AGILITY   = 2
Data.STAT_INTELLECT = 4

-- Map primary stat → GetItemStats key. Spirit is a healer accept-stat
-- handled separately (not a disqualifier).
Data.PrimaryStatKey = {
    [Data.STAT_STRENGTH]  = "ITEM_MOD_STRENGTH_SHORT",
    [Data.STAT_AGILITY]   = "ITEM_MOD_AGILITY_SHORT",
    [Data.STAT_INTELLECT] = "ITEM_MOD_INTELLECT_SHORT",
}

Data.PrimaryStatName = {
    [Data.STAT_STRENGTH]  = "Strength",
    [Data.STAT_AGILITY]   = "Agility",
    [Data.STAT_INTELLECT] = "Intellect",
}

-- Healer specs that benefit from Spirit (spec IDs from GetSpecializationInfo)
Data.HealerSpecIDs = {
    [65]  = true, -- Holy Paladin
    [105] = true, -- Restoration Druid
    [256] = true, -- Discipline Priest
    [257] = true, -- Holy Priest
    [264] = true, -- Restoration Shaman
    [270] = true, -- Mistweaver Monk
}

-- equipLoc string → inventory slot ID(s) for ilvl comparison.
-- Multi-slot entries are compared via MIN(equipped ilvl) so we only Need
-- if the incoming item beats the worst slot.
Data.EquipLocToSlots = {
    INVTYPE_HEAD            = { 1 },
    INVTYPE_NECK            = { 2 },
    INVTYPE_SHOULDER        = { 3 },
    INVTYPE_CLOAK           = { 15 },
    INVTYPE_CHEST           = { 5 },
    INVTYPE_ROBE            = { 5 },
    INVTYPE_WAIST           = { 6 },
    INVTYPE_LEGS            = { 7 },
    INVTYPE_FEET            = { 8 },
    INVTYPE_WRIST           = { 9 },
    INVTYPE_HAND            = { 10 },
    INVTYPE_FINGER          = { 11, 12 },
    INVTYPE_TRINKET         = { 13, 14 },
    INVTYPE_WEAPON          = { 16, 17 },
    INVTYPE_2HWEAPON        = { 16 },
    INVTYPE_WEAPONMAINHAND  = { 16 },
    INVTYPE_WEAPONOFFHAND   = { 17 },
    INVTYPE_HOLDABLE        = { 17 },
    INVTYPE_SHIELD          = { 17 },
    INVTYPE_RANGED          = { 16 }, -- MoP folded most ranged into MH
    INVTYPE_RANGEDRIGHT     = { 16 },
    INVTYPE_THROWN          = { 16 },
}

-- Tier tokens that grant gear when redeemed: itemID → set of class strings.
-- Stub list; populated as raids are encountered. Items not in this table
-- fall through normal stat-match logic.
Data.TierTokens = {
    -- Throne of Thunder T15 (examples; expand as needed)
    -- [95620] = { ROGUE=true, MONK=true, DEATHKNIGHT=true }, -- Helm of the Vanquisher
}

-- rollType constants for RollOnLoot
Data.ROLL_PASS  = 0
Data.ROLL_NEED  = 1
Data.ROLL_GREED = 2

Data.ActionToRollType = {
    PASS  = Data.ROLL_PASS,
    NEED  = Data.ROLL_NEED,
    GREED = Data.ROLL_GREED,
}

-- Quality colors for chat output
Data.QualityNames = {
    [0] = "Poor", [1] = "Common", [2] = "Uncommon",
    [3] = "Rare", [4] = "Epic", [5] = "Legendary",
}
