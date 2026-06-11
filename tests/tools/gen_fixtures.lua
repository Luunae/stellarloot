-- tests/tools/gen_fixtures.lua — emit tests/fixtures/corpus.lua from an
-- EJGearAudit SavedVariables dump (the ej-gear-audit sibling repo).
-- Every db.items record becomes a stub-ready fixture: the GetItemInfo tuple
-- fields, the verbatim GetItemStats table, and the EJ loot-filter sets
-- (filterSpecs/filterClasses) that the corpus sweep uses as its oracle.
-- Output is sorted by itemID so regeneration diffs cleanly.
--
-- Usage: lua tests/tools/gen_fixtures.lua <path-to-dump> > tests/fixtures/corpus.lua

local svPath = assert(arg[1], "usage: lua gen_fixtures.lua <EJGearAudit dump> > corpus.lua")
dofile(svPath)
local db = assert(EJGearAuditDB, "no EJGearAuditDB in file")

local ITEM_TYPE = { [2] = "Weapon", [4] = "Armor", [15] = "Miscellaneous" }

-- Weapon subclass names (Enum.ItemWeaponSubclass), trace-text only.
local WEAPON_SUBTYPE = {
    [0] = "One-Handed Axes", [1] = "Two-Handed Axes", [2] = "Bows",
    [3] = "Guns", [4] = "One-Handed Maces", [5] = "Two-Handed Maces",
    [6] = "Polearms", [7] = "One-Handed Swords", [8] = "Two-Handed Swords",
    [10] = "Staves", [13] = "Fist Weapons", [14] = "Miscellaneous",
    [15] = "Daggers", [16] = "Thrown", [18] = "Crossbows", [19] = "Wands",
    [20] = "Fishing Poles",
}

local function subType(rec)
    if rec.armorText and rec.armorText ~= "" then return rec.armorText end
    if rec.classID == 2 then return WEAPON_SUBTYPE[rec.subclassID] or ("subclass " .. tostring(rec.subclassID)) end
    return "Miscellaneous"
end

local function sortedKeys(t)
    local keys = {}
    for k in pairs(t or {}) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        if type(a) == type(b) then return a < b end
        return type(a) == "number"
    end)
    return keys
end

-- Stats values can be floats (DPS); the decision engine only tests > 0, so
-- plain tostring precision is fine — and deterministic.
local function statsSrc(stats)
    local parts = {}
    for _, k in ipairs(sortedKeys(stats)) do
        parts[#parts + 1] = ("[%q]=%s"):format(k, tostring(stats[k]))
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function idSetSrc(set)
    local parts = {}
    for _, k in ipairs(sortedKeys(set)) do
        parts[#parts + 1] = ("[%d]=true"):format(k)
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local ids = sortedKeys(db.items)

print("-- GENERATED FILE — do not edit by hand.")
print("-- Regenerate: lua tests/tools/gen_fixtures.lua <ej-gear-audit dump> > tests/fixtures/corpus.lua")
print(("-- Source: EJGearAudit dump %s, client build %s (%s), %d items."):format(
    tostring(db.meta and db.meta.date), tostring(db.meta and db.meta.build),
    tostring(db.meta and db.meta.version), #ids))
print("-- itemID → GetItemInfo/GetItemStats fixture + EJ loot-filter sets")
print("-- (filterSpecs/filterClasses — the sweep oracle; the stub ignores them).")
print("return {")
for _, id in ipairs(ids) do
    local rec = db.items[id]
    print(("[%d]={name=%q,quality=%d,ilvl=%d,equipLoc=%q,classID=%d,subclassID=%d,itemType=%q,itemSubType=%q,stats=%s,filterSpecs=%s,filterClasses=%s},"):format(
        id, rec.itemName or rec.name or "?", rec.quality or 0, rec.ilvl or 0,
        rec.equipLoc or "", rec.classID or 0, rec.subclassID or 0,
        ITEM_TYPE[rec.classID] or ("class " .. tostring(rec.classID)), subType(rec),
        statsSrc(rec.stats), idSetSrc(rec.filterSpecs), idSetSrc(rec.filterClasses)))
end
print("}")
