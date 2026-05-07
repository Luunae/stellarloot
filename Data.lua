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

-- Tier-token name prefix → equipLoc the token redeems for. Lets the decision
-- engine compare a token's ilvl against the gear it would replace.
Data.TierTokenSlotByName = {
    Helm      = "INVTYPE_HEAD",
    Shoulders = "INVTYPE_SHOULDER",
    Chest     = "INVTYPE_CHEST",
    Gauntlets = "INVTYPE_HAND",
    Leggings  = "INVTYPE_LEGS",
}

-- Slots a Garrosh "Essence" wildcard token can redeem for. Compared via
-- MIN(equipped ilvl) across the five so a wildcard only Needs when at least
-- one tier slot is genuinely below the token.
Data.TierWildcardSlots = {
    "INVTYPE_HEAD", "INVTYPE_SHOULDER", "INVTYPE_CHEST",
    "INVTYPE_HAND", "INVTYPE_LEGS",
}

-- Resolve a tier token's destination slot from its name. Returns:
--   "WILDCARD" for "Essence of the Cursed ..." (Garrosh-only),
--   an INVTYPE_* string for fixed-slot tokens,
--   nil if the name doesn't match any known pattern.
function Data.TierTokenEquipLoc(name)
    if not name then return nil end
    if name:find("^Essence ") then return "WILDCARD" end
    local first = name:match("^(%S+)")
    return first and Data.TierTokenSlotByName[first] or nil
end

-- Tier token class groups (Pandaria). Each MoP raid tier reuses these three
-- groupings; tokens are named "of the Vanquisher / Protector / Conqueror".
Data.TierTokenGroups = {
    VANQUISHER = { DEATHKNIGHT=true, DRUID=true, MAGE=true, ROGUE=true },
    PROTECTOR  = { HUNTER=true, SHAMAN=true, WARRIOR=true, MONK=true },
    CONQUEROR  = { PALADIN=true, PRIEST=true, WARLOCK=true },
}

-- Tier tokens that grant gear when redeemed: itemID → class set.
-- Populated for Pandaria raid tiers T14-T16. Unknown tokens hit the stat
-- check in Decision.lua step 9 (tokens have no primary stat) and silently
-- default to Greed/Pass — populate this table when new tier content lands.
local V, P, C = Data.TierTokenGroups.VANQUISHER,
                Data.TierTokenGroups.PROTECTOR,
                Data.TierTokenGroups.CONQUEROR
Data.TierTokens = {
    -- ===== T14: Mogu'shan Vaults / Heart of Fear / Terrace of Endless Spring =====
    -- Helms
    [89273] = V,  -- Helm of the Shadowy Vanquisher  [ilvl: 483]
    [89234] = V,  -- Helm of the Shadowy Vanquisher  [ilvl: 496]
    [89258] = V,  -- Helm of the Shadowy Vanquisher  [ilvl: 509]
    [89275] = P,  -- Helm of the Shadowy Protector  [ilvl: 483]
    [89236] = P,  -- Helm of the Shadowy Protector  [ilvl: 496]
    [89260] = P,  -- Helm of the Shadowy Protector  [ilvl: 509]
    [89274] = C,  -- Helm of the Shadowy Conqueror  [ilvl: 483]
    [89235] = C,  -- Helm of the Shadowy Conqueror  [ilvl: 496]
    [89259] = C,  -- Helm of the Shadowy Conqueror  [ilvl: 509]
    -- Shoulders
    [89276] = V,  -- Shoulders of the Shadowy Vanquisher  [ilvl: 483]
    [89248] = V,  -- Shoulders of the Shadowy Vanquisher  [ilvl: 496]
    [89261] = V,  -- Shoulders of the Shadowy Vanquisher  [ilvl: 509]
    [89278] = P,  -- Shoulders of the Shadowy Protector  [ilvl: 483]
    [89247] = P,  -- Shoulders of the Shadowy Protector  [ilvl: 496]
    [89263] = P,  -- Shoulders of the Shadowy Protector  [ilvl: 509]
    [89277] = C,  -- Shoulders of the Shadowy Conqueror  [ilvl: 483]
    [89246] = C,  -- Shoulders of the Shadowy Conqueror  [ilvl: 496]
    [89262] = C,  -- Shoulders of the Shadowy Conqueror  [ilvl: 509]
    -- Chest
    [89264] = V,  -- Chest of the Shadowy Vanquisher  [ilvl: 483]
    [89239] = V,  -- Chest of the Shadowy Vanquisher  [ilvl: 496]
    [89249] = V,  -- Chest of the Shadowy Vanquisher  [ilvl: 509]
    [89266] = P,  -- Chest of the Shadowy Protector  [ilvl: 483]
    [89238] = P,  -- Chest of the Shadowy Protector  [ilvl: 496]
    [89251] = P,  -- Chest of the Shadowy Protector  [ilvl: 509]
    [89265] = C,  -- Chest of the Shadowy Conqueror  [ilvl: 483]
    [89237] = C,  -- Chest of the Shadowy Conqueror  [ilvl: 496]
    [89250] = C,  -- Chest of the Shadowy Conqueror  [ilvl: 509]
    -- Gauntlets
    [89270] = V,  -- Gauntlets of the Shadowy Vanquisher  [ilvl: 483]
    [89242] = V,  -- Gauntlets of the Shadowy Vanquisher  [ilvl: 496]
    [89255] = V,  -- Gauntlets of the Shadowy Vanquisher  [ilvl: 509]
    [89272] = P,  -- Gauntlets of the Shadowy Protector  [ilvl: 483]
    [89241] = P,  -- Gauntlets of the Shadowy Protector  [ilvl: 496]
    [89257] = P,  -- Gauntlets of the Shadowy Protector  [ilvl: 509]
    [89271] = C,  -- Gauntlets of the Shadowy Conqueror  [ilvl: 483]
    [89240] = C,  -- Gauntlets of the Shadowy Conqueror  [ilvl: 496]
    [89256] = C,  -- Gauntlets of the Shadowy Conqueror  [ilvl: 509]
    -- Leggings
    [89267] = V,  -- Leggings of the Shadowy Vanquisher  [ilvl: 483]
    [89245] = V,  -- Leggings of the Shadowy Vanquisher  [ilvl: 496]
    [89252] = V,  -- Leggings of the Shadowy Vanquisher  [ilvl: 509]
    [89269] = P,  -- Leggings of the Shadowy Protector  [ilvl: 483]
    [89244] = P,  -- Leggings of the Shadowy Protector  [ilvl: 496]
    [89254] = P,  -- Leggings of the Shadowy Protector  [ilvl: 509]
    [89268] = C,  -- Leggings of the Shadowy Conqueror  [ilvl: 483]
    [89243] = C,  -- Leggings of the Shadowy Conqueror  [ilvl: 496]
    [89253] = C,  -- Leggings of the Shadowy Conqueror  [ilvl: 509]

    -- ===== T15: Throne of Thunder =====
    -- Helms
    [95879] = V,  -- Helm of the Crackling Vanquisher  [ilvl: 502]
    [95571] = V,  -- Helm of the Crackling Vanquisher  [ilvl: 522]
    [96623] = V,  -- Helm of the Crackling Vanquisher  [ilvl: 535]
    [95881] = P,  -- Helm of the Crackling Protector  [ilvl: 502]
    [95582] = P,  -- Helm of the Crackling Protector  [ilvl: 522]
    [96625] = P,  -- Helm of the Crackling Protector  [ilvl: 535]
    [95880] = C,  -- Helm of the Crackling Conqueror  [ilvl: 502]
    [95577] = C,  -- Helm of the Crackling Conqueror  [ilvl: 522]
    [96624] = C,  -- Helm of the Crackling Conqueror  [ilvl: 535]
    -- Shoulders
    [95955] = V,  -- Shoulders of the Crackling Vanquisher  [ilvl: 502]
    [95573] = V,  -- Shoulders of the Crackling Vanquisher  [ilvl: 522]
    [96699] = V,  -- Shoulders of the Crackling Vanquisher  [ilvl: 535]
    [95957] = P,  -- Shoulders of the Crackling Protector  [ilvl: 502]
    [95583] = P,  -- Shoulders of the Crackling Protector  [ilvl: 522]
    [96701] = P,  -- Shoulders of the Crackling Protector  [ilvl: 535]
    [95956] = C,  -- Shoulders of the Crackling Conqueror  [ilvl: 502]
    [95578] = C,  -- Shoulders of the Crackling Conqueror  [ilvl: 522]
    [96700] = C,  -- Shoulders of the Crackling Conqueror  [ilvl: 535]
    -- Chest
    [95822] = V,  -- Chest of the Crackling Vanquisher  [ilvl: 502]
    [95569] = V,  -- Chest of the Crackling Vanquisher  [ilvl: 522]
    [96566] = V,  -- Chest of the Crackling Vanquisher  [ilvl: 535]
    [95824] = P,  -- Chest of the Crackling Protector  [ilvl: 502]
    [95579] = P,  -- Chest of the Crackling Protector  [ilvl: 522]
    [96568] = P,  -- Chest of the Crackling Protector  [ilvl: 535]
    [95823] = C,  -- Chest of the Crackling Conqueror  [ilvl: 502]
    [95574] = C,  -- Chest of the Crackling Conqueror  [ilvl: 522]
    [96567] = C,  -- Chest of the Crackling Conqueror  [ilvl: 535]
    -- Gauntlets
    [95855] = V,  -- Gauntlets of the Crackling Vanquisher  [ilvl: 502]
    [95570] = V,  -- Gauntlets of the Crackling Vanquisher  [ilvl: 522]
    [96599] = V,  -- Gauntlets of the Crackling Vanquisher  [ilvl: 535]
    [95857] = P,  -- Gauntlets of the Crackling Protector  [ilvl: 502]
    [95580] = P,  -- Gauntlets of the Crackling Protector  [ilvl: 522]
    [96601] = P,  -- Gauntlets of the Crackling Protector  [ilvl: 535]
    [95856] = C,  -- Gauntlets of the Crackling Conqueror  [ilvl: 502]
    [95575] = C,  -- Gauntlets of the Crackling Conqueror  [ilvl: 522]
    [96600] = C,  -- Gauntlets of the Crackling Conqueror  [ilvl: 535]
    -- Leggings
    [95887] = V,  -- Leggings of the Crackling Vanquisher  [ilvl: 502]
    [95572] = V,  -- Leggings of the Crackling Vanquisher  [ilvl: 522]
    [96631] = V,  -- Leggings of the Crackling Vanquisher  [ilvl: 535]
    [95889] = P,  -- Leggings of the Crackling Protector  [ilvl: 502]
    [95581] = P,  -- Leggings of the Crackling Protector  [ilvl: 522]
    [96633] = P,  -- Leggings of the Crackling Protector  [ilvl: 535]
    [95888] = C,  -- Leggings of the Crackling Conqueror  [ilvl: 502]
    [95576] = C,  -- Leggings of the Crackling Conqueror  [ilvl: 522]
    [96632] = C,  -- Leggings of the Crackling Conqueror  [ilvl: 535]

    -- ===== T16: Siege of Orgrimmar =====
    -- Helms
    [99671] = V,  -- Helm of the Cursed Vanquisher  [ilvl: 528]
    [99683] = V,  -- Helm of the Cursed Vanquisher  [ilvl: 553]
    [99723] = V,  -- Helm of the Cursed Vanquisher  [ilvl: 566]
    [99673] = P,  -- Helm of the Cursed Protector  [ilvl: 528]
    [99694] = P,  -- Helm of the Cursed Protector  [ilvl: 553]
    [99725] = P,  -- Helm of the Cursed Protector  [ilvl: 566]
    [99672] = C,  -- Helm of the Cursed Conqueror  [ilvl: 528]
    [99689] = C,  -- Helm of the Cursed Conqueror  [ilvl: 553]
    [99724] = C,  -- Helm of the Cursed Conqueror  [ilvl: 566]
    -- Shoulders
    [99668] = V,  -- Shoulders of the Cursed Vanquisher  [ilvl: 528]
    [99685] = V,  -- Shoulders of the Cursed Vanquisher  [ilvl: 553]
    [99717] = V,  -- Shoulders of the Cursed Vanquisher  [ilvl: 566]
    [99670] = P,  -- Shoulders of the Cursed Protector  [ilvl: 528]
    [99695] = P,  -- Shoulders of the Cursed Protector  [ilvl: 553]
    [99719] = P,  -- Shoulders of the Cursed Protector  [ilvl: 566]
    [99669] = C,  -- Shoulders of the Cursed Conqueror  [ilvl: 528]
    [99690] = C,  -- Shoulders of the Cursed Conqueror  [ilvl: 553]
    [99718] = C,  -- Shoulders of the Cursed Conqueror  [ilvl: 566]
    -- Chest
    [99677] = V,  -- Chest of the Cursed Vanquisher  [ilvl: 528]
    [99696] = V,  -- Chest of the Cursed Vanquisher  [ilvl: 553]
    [99714] = V,  -- Chest of the Cursed Vanquisher  [ilvl: 566]
    [99679] = P,  -- Chest of the Cursed Protector  [ilvl: 528]
    [99691] = P,  -- Chest of the Cursed Protector  [ilvl: 553]
    [99716] = P,  -- Chest of the Cursed Protector  [ilvl: 566]
    [99678] = C,  -- Chest of the Cursed Conqueror  [ilvl: 528]
    [99686] = C,  -- Chest of the Cursed Conqueror  [ilvl: 553]
    [99715] = C,  -- Chest of the Cursed Conqueror  [ilvl: 566]
    -- Gauntlets
    [99680] = V,  -- Gauntlets of the Cursed Vanquisher  [ilvl: 528]
    [99682] = V,  -- Gauntlets of the Cursed Vanquisher  [ilvl: 553]
    [99720] = V,  -- Gauntlets of the Cursed Vanquisher  [ilvl: 566]
    [99667] = P,  -- Gauntlets of the Cursed Protector  [ilvl: 528]
    [99692] = P,  -- Gauntlets of the Cursed Protector  [ilvl: 553]
    [99722] = P,  -- Gauntlets of the Cursed Protector  [ilvl: 566]
    [99681] = C,  -- Gauntlets of the Cursed Conqueror  [ilvl: 528]
    [99687] = C,  -- Gauntlets of the Cursed Conqueror  [ilvl: 553]
    [99721] = C,  -- Gauntlets of the Cursed Conqueror  [ilvl: 566]
    -- Leggings
    [99674] = V,  -- Leggings of the Cursed Vanquisher  [ilvl: 528]
    [99684] = V,  -- Leggings of the Cursed Vanquisher  [ilvl: 553]
    [99726] = V,  -- Leggings of the Cursed Vanquisher  [ilvl: 566]
    [99676] = P,  -- Leggings of the Cursed Protector  [ilvl: 528]
    [99693] = P,  -- Leggings of the Cursed Protector  [ilvl: 553]
    [99713] = P,  -- Leggings of the Cursed Protector  [ilvl: 566]
    [99675] = C,  -- Leggings of the Cursed Conqueror  [ilvl: 528]
    [99688] = C,  -- Leggings of the Cursed Conqueror  [ilvl: 553]
    [99712] = C,  -- Leggings of the Cursed Conqueror  [ilvl: 566]
    -- Essence (Garrosh — wildcard, redeemable for any tier slot)
    [105859] = V,  -- Essence of the Cursed Vanquisher  [ilvl: 553]
    [105868] = V,  -- Essence of the Cursed Vanquisher  [ilvl: 566]
    [105857] = P,  -- Essence of the Cursed Protector  [ilvl: 553]
    [105866] = P,  -- Essence of the Cursed Protector  [ilvl: 566]
    [105858] = C,  -- Essence of the Cursed Conqueror  [ilvl: 553]
    [105867] = C,  -- Essence of the Cursed Conqueror  [ilvl: 566]
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
