-- tests/helpers.lua — builders for the inputs Decision.Evaluate takes, plus
-- trace assertions. Loaded after the addon modules (needs StellarLoot.Config
-- and StellarLoot.Data).

local H = {}

local Config = StellarLoot.Config
local Data = StellarLoot.Data

local function deepCopy(src, dst)
    dst = dst or {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = deepCopy(v, {})
        else
            dst[k] = v
        end
    end
    return dst
end

-- Override-wins merge (unlike Config's deepMerge, which only fills nil keys).
local function applyOverrides(base, overrides)
    for k, v in pairs(overrides) do
        if type(v) == "table" and type(base[k]) == "table" then
            applyOverrides(base[k], v)
        else
            base[k] = v
        end
    end
    return base
end

-- All 34 MoP class-specs. Static game data; drives the sweep and ctx defaults.
-- primaryStat: 1=Str, 2=Agi, 4=Int (Data.STAT_*).
H.SPECS = {
    { specID = 71,  classToken = "WARRIOR",     classID = 1,  name = "Arms",          primaryStat = 1, role = "DAMAGER", isHealer = false },
    { specID = 72,  classToken = "WARRIOR",     classID = 1,  name = "Fury",          primaryStat = 1, role = "DAMAGER", isHealer = false },
    { specID = 73,  classToken = "WARRIOR",     classID = 1,  name = "Protection",    primaryStat = 1, role = "TANK",    isHealer = false },
    { specID = 65,  classToken = "PALADIN",     classID = 2,  name = "Holy",          primaryStat = 4, role = "HEALER",  isHealer = true  },
    { specID = 66,  classToken = "PALADIN",     classID = 2,  name = "Protection",    primaryStat = 1, role = "TANK",    isHealer = false },
    { specID = 70,  classToken = "PALADIN",     classID = 2,  name = "Retribution",   primaryStat = 1, role = "DAMAGER", isHealer = false },
    { specID = 253, classToken = "HUNTER",      classID = 3,  name = "Beast Mastery", primaryStat = 2, role = "DAMAGER", isHealer = false },
    { specID = 254, classToken = "HUNTER",      classID = 3,  name = "Marksmanship",  primaryStat = 2, role = "DAMAGER", isHealer = false },
    { specID = 255, classToken = "HUNTER",      classID = 3,  name = "Survival",      primaryStat = 2, role = "DAMAGER", isHealer = false },
    { specID = 259, classToken = "ROGUE",       classID = 4,  name = "Assassination", primaryStat = 2, role = "DAMAGER", isHealer = false },
    { specID = 260, classToken = "ROGUE",       classID = 4,  name = "Combat",        primaryStat = 2, role = "DAMAGER", isHealer = false },
    { specID = 261, classToken = "ROGUE",       classID = 4,  name = "Subtlety",      primaryStat = 2, role = "DAMAGER", isHealer = false },
    { specID = 256, classToken = "PRIEST",      classID = 5,  name = "Discipline",    primaryStat = 4, role = "HEALER",  isHealer = true  },
    { specID = 257, classToken = "PRIEST",      classID = 5,  name = "Holy",          primaryStat = 4, role = "HEALER",  isHealer = true  },
    { specID = 258, classToken = "PRIEST",      classID = 5,  name = "Shadow",        primaryStat = 4, role = "DAMAGER", isHealer = false },
    { specID = 250, classToken = "DEATHKNIGHT", classID = 6,  name = "Blood",         primaryStat = 1, role = "TANK",    isHealer = false },
    { specID = 251, classToken = "DEATHKNIGHT", classID = 6,  name = "Frost",         primaryStat = 1, role = "DAMAGER", isHealer = false },
    { specID = 252, classToken = "DEATHKNIGHT", classID = 6,  name = "Unholy",        primaryStat = 1, role = "DAMAGER", isHealer = false },
    { specID = 262, classToken = "SHAMAN",      classID = 7,  name = "Elemental",     primaryStat = 4, role = "DAMAGER", isHealer = false },
    { specID = 263, classToken = "SHAMAN",      classID = 7,  name = "Enhancement",   primaryStat = 2, role = "DAMAGER", isHealer = false },
    { specID = 264, classToken = "SHAMAN",      classID = 7,  name = "Restoration",   primaryStat = 4, role = "HEALER",  isHealer = true  },
    { specID = 62,  classToken = "MAGE",        classID = 8,  name = "Arcane",        primaryStat = 4, role = "DAMAGER", isHealer = false },
    { specID = 63,  classToken = "MAGE",        classID = 8,  name = "Fire",          primaryStat = 4, role = "DAMAGER", isHealer = false },
    { specID = 64,  classToken = "MAGE",        classID = 8,  name = "Frost",         primaryStat = 4, role = "DAMAGER", isHealer = false },
    { specID = 265, classToken = "WARLOCK",     classID = 9,  name = "Affliction",    primaryStat = 4, role = "DAMAGER", isHealer = false },
    { specID = 266, classToken = "WARLOCK",     classID = 9,  name = "Demonology",    primaryStat = 4, role = "DAMAGER", isHealer = false },
    { specID = 267, classToken = "WARLOCK",     classID = 9,  name = "Destruction",   primaryStat = 4, role = "DAMAGER", isHealer = false },
    { specID = 268, classToken = "MONK",        classID = 10, name = "Brewmaster",    primaryStat = 2, role = "TANK",    isHealer = false },
    { specID = 269, classToken = "MONK",        classID = 10, name = "Windwalker",    primaryStat = 2, role = "DAMAGER", isHealer = false },
    { specID = 270, classToken = "MONK",        classID = 10, name = "Mistweaver",    primaryStat = 4, role = "HEALER",  isHealer = true  },
    { specID = 102, classToken = "DRUID",       classID = 11, name = "Balance",       primaryStat = 4, role = "DAMAGER", isHealer = false },
    { specID = 103, classToken = "DRUID",       classID = 11, name = "Feral",         primaryStat = 2, role = "DAMAGER", isHealer = false },
    { specID = 104, classToken = "DRUID",       classID = 11, name = "Guardian",      primaryStat = 2, role = "TANK",    isHealer = false },
    { specID = 105, classToken = "DRUID",       classID = 11, name = "Restoration",   primaryStat = 4, role = "HEALER",  isHealer = true  },
}

H.SPECS_BY_ID = {}
for _, spec in ipairs(H.SPECS) do
    H.SPECS_BY_ID[spec.specID] = spec
end

-- Decision resolves the itemID from the link and takes everything else from
-- GetItemInfo, so the display name here is cosmetic.
function H.link(id, name)
    return ("|cffa335ee|Hitem:%d::::::::90:::::|h[%s]|h|r"):format(id, name or "Test Item")
end

function H.cfg(overrides)
    local cfg = deepCopy(Config.DEFAULTS)
    if overrides then applyOverrides(cfg, overrides) end
    return cfg
end

-- Resolve an entry from the per-case equipped/sets tables: a plain number,
-- or { ilvl, heirloom = true }.
local function entryILvl(e)
    if e == nil then return nil end
    if type(e) == "table" then return e[1] or 0, e.heirloom or false end
    return e, false
end

-- ctx builder. Default: Retribution Paladin with every known equip slot at
-- ilvl 480. Overrides:
--   spec        — a specID (looked up in H.SPECS) replacing the paladin
--   equipped    — { [equipLoc] = ilvl | {ilvl, heirloom=true} }
--   equippedAll — single ilvl for every slot (sweep convenience)
--   sets        — { [setName] = { [equipLoc] = ilvl | {...} } }
--   anything else is copied onto ctx verbatim
function H.ctx(overrides)
    overrides = overrides or {}

    local ctx = {
        classToken = "PALADIN",
        classID = 2,
        specID = 70,
        primaryStat = 1,
        role = "DAMAGER",
        isHealer = false,
        offspecSpecID = nil,
        offspecPrimaryStat = nil,
    }

    if overrides.spec then
        local spec = assert(H.SPECS_BY_ID[overrides.spec],
            "unknown specID " .. tostring(overrides.spec))
        ctx.classToken = spec.classToken
        ctx.classID = spec.classID
        ctx.specID = spec.specID
        ctx.primaryStat = spec.primaryStat
        ctx.role = spec.role
        ctx.isHealer = spec.isHealer
    end

    local equipped = overrides.equipped or {}
    local equippedAll = overrides.equippedAll
    if not equippedAll and not overrides.equipped then equippedAll = 480 end
    local sets = overrides.sets or {}

    for k, v in pairs(overrides) do
        if k ~= "spec" and k ~= "equipped" and k ~= "equippedAll" and k ~= "sets" then
            ctx[k] = v
        end
    end

    ctx.worstEquippedILvl = function(equipLoc, incomingName)
        local ilvl, heirloom = entryILvl(equipped[equipLoc])
        if ilvl == nil then
            if equippedAll then return equippedAll, false end
            return 0, false
        end
        return ilvl, heirloom
    end

    ctx.worstSetILvl = function(equipLoc, setName, incomingName)
        local set = sets[setName]
        if not set then return nil end
        return entryILvl(set[equipLoc])
    end

    return ctx
end

function H.roll(overrides)
    local roll = {
        name = "Test Item",
        quality = 4,
        bindOnPickUp = false,
        canNeed = true,
        canGreed = true,
    }
    if overrides then
        for k, v in pairs(overrides) do roll[k] = v end
    end
    return roll
end

function H.decisiveRule(trace)
    local f = trace and trace.decisive and trace.factors[trace.decisive]
    return f and f.data and f.data.rule
end

return H
