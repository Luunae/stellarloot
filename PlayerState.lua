-- StellarLoot/PlayerState.lua
-- Cached snapshot of player class, spec, primary stat, enchanting skill, and
-- equipped item levels per slot. Refreshed on relevant events.

local Data = StellarLoot.Data

-- Compat: spec info was moved to C_SpecializationInfo in newer clients.
local function getSpecIndex(group)
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        return C_SpecializationInfo.GetSpecialization(false, false, group)
    end
    if _G.GetSpecialization then return _G.GetSpecialization(false, false, group) end
    return nil
end

local function getSpecInfo(idx, group)
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
        return C_SpecializationInfo.GetSpecializationInfo(idx, false, false, group)
    end
    if _G.GetSpecializationInfo then return _G.GetSpecializationInfo(idx, false, false, group) end
    return nil
end

local function getActiveSpecGroup()
    if C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup then
        return C_SpecializationInfo.GetActiveSpecGroup()
    end
    if _G.GetActiveSpecGroup then return _G.GetActiveSpecGroup() end
    return nil
end

local PlayerState = {
    classID = nil,         -- numeric class ID
    classToken = nil,      -- "MAGE", "WARRIOR", etc.
    specIndex = nil,
    specID = nil,
    specName = nil,
    primaryStat = nil,     -- 1=Str, 2=Agi, 4=Int
    role = nil,            -- "TANK", "HEALER", "DAMAGER"
    isHealer = false,
    enchantingSkill = 0,
    equippedILvl = {},     -- [invSlot] = ilvl number

    -- Off-spec (populated by RefreshOffSpec; nil when disabled or unavailable)
    offspecSpecID = nil,
    offspecSpecName = nil,
    offspecRole = nil,
    offspecPrimaryStat = nil,
}
StellarLoot.PlayerState = PlayerState

local function getDetailedItemLevel(link)
    if not link then return 0 end
    local fn = _G.GetDetailedItemLevelInfo
    if fn then
        local ilvl = fn(link)
        if ilvl and ilvl > 0 then return ilvl end
    end
    local _, _, _, baseILvl = GetItemInfo(link)
    return baseILvl or 0
end

function PlayerState:RefreshClass()
    local className, classToken, classID = UnitClass("player")
    self.className = className
    self.classToken = classToken
    self.classID = classID
end

function PlayerState:RefreshSpec()
    local idx = getSpecIndex()
    self.specIndex = idx
    if not idx then
        self.specID, self.specName, self.role, self.primaryStat = nil, nil, nil, nil
        self.isHealer = false
        return
    end
    local specID, name, _, _, role, primaryStat = getSpecInfo(idx)
    self.specID = specID
    self.specName = name
    self.role = role
    self.primaryStat = primaryStat
    self.isHealer = (role == "HEALER") or (specID and Data.HealerSpecIDs[specID]) or false
end

function PlayerState:RefreshOffSpec()
    local cfg = StellarLoot.Config and StellarLoot.Config:Get()
    local offspec = (cfg and cfg.offspec) or {}
    local source = offspec.source or "off"

    self.offspecSpecID, self.offspecSpecName = nil, nil
    self.offspecRole, self.offspecPrimaryStat = nil, nil

    if source == "off" then return end

    if source == "manual" then
        self.offspecPrimaryStat = offspec.primaryStat
        return
    end

    -- source == "auto": read the inactive talent group
    local active = getActiveSpecGroup()
    if not active then
        -- API not available; fall back to the manual stat if user supplied one
        self.offspecPrimaryStat = offspec.primaryStat
        return
    end
    local other = (active == 1) and 2 or 1
    local idx = getSpecIndex(other)
    if not idx or idx == 0 then
        -- Off-spec not trained yet; use manual fallback if available
        self.offspecPrimaryStat = offspec.primaryStat
        return
    end
    local specID, name, _, _, role, primaryStat = getSpecInfo(idx, other)
    self.offspecSpecID = specID
    self.offspecSpecName = name
    self.offspecRole = role
    self.offspecPrimaryStat = primaryStat or offspec.primaryStat
end

function PlayerState:RefreshProfessions()
    -- Identify Enchanting by skillLine ID 333 (locale-independent), not by name.
    self.enchantingSkill = 0
    if not GetProfessions then return end
    local prof1, prof2 = GetProfessions()
    for _, slot in ipairs({ prof1, prof2 }) do
        if slot then
            local _name, _icon, rank, _maxRank, _numSpells, _spellOffset, skillLine = GetProfessionInfo(slot)
            if skillLine == 333 then
                self.enchantingSkill = rank or 0
            end
        end
    end
end

function PlayerState:RefreshSlot(slot)
    if not slot or slot < 1 then return end
    local link = GetInventoryItemLink("player", slot)
    self.equippedILvl[slot] = link and getDetailedItemLevel(link) or 0
end

function PlayerState:RefreshAllSlots()
    -- Slots 1..18 cover the visible equipment slots (excl. shirt 4 / tabard 19,
    -- which never roll). Bag slots (20+) are not gear.
    for slot = 1, 18 do
        self:RefreshSlot(slot)
    end
end

-- Best-of-comparison ilvl across all slots an equipLoc could fill.
function PlayerState:WorstEquippedILvl(equipLoc)
    local slots = Data.EquipLocToSlots[equipLoc]
    if not slots then return 0 end
    local worst
    for _, slot in ipairs(slots) do
        local ilvl = self.equippedILvl[slot] or 0
        if not worst or ilvl < worst then worst = ilvl end
    end
    return worst or 0
end

-- Resolve the item link the named equipment set assigns to a given inv slot.
-- Returns nil if the set doesn't define that slot, the set name is invalid, or
-- the item lives somewhere we can't read from (bank/void storage when away).
function PlayerState:GetEquipmentSetItemLink(setName, invSlot)
    if not setName or not invSlot then return nil end
    if not _G.GetEquipmentSetLocations or not _G.EquipmentManager_UnpackLocation then
        return nil
    end
    local locations = GetEquipmentSetLocations(setName)
    if not locations then return nil end
    local loc = locations[invSlot]
    if not loc or loc == 0 or loc == -1 then return nil end
    local player, _bank, bags, _void, slot, bag = EquipmentManager_UnpackLocation(loc)
    if player then
        return GetInventoryItemLink("player", invSlot)
    elseif bags and _G.GetContainerItemLink then
        return GetContainerItemLink(bag, slot)
    end
    return nil
end

-- Worst ilvl across the slots an equipLoc maps to, but using items from an
-- equipment set rather than what's currently equipped. Returns nil if the set
-- has no items in any of those slots (caller should treat that as "no
-- comparison possible").
function PlayerState:WorstSetILvl(equipLoc, setName)
    local slots = Data.EquipLocToSlots[equipLoc]
    if not slots or not setName then return nil end
    local worst
    for _, slot in ipairs(slots) do
        local link = self:GetEquipmentSetItemLink(setName, slot)
        if link then
            local ilvl = getDetailedItemLevel(link)
            if not worst or ilvl < worst then worst = ilvl end
        end
    end
    return worst
end

-- Enumerate equipment set names; legacy MoP API. Returns a sorted list.
function PlayerState:GetEquipmentSetNames()
    local names = {}
    if _G.GetNumEquipmentSets and _G.GetEquipmentSetInfo then
        for i = 1, GetNumEquipmentSets() do
            local n = GetEquipmentSetInfo(i)
            if n then table.insert(names, n) end
        end
    end
    table.sort(names)
    return names
end

function PlayerState:Snapshot()
    -- Returns a shallow copy of mutable scalars + a reference to equippedILvl.
    -- Decision.Evaluate treats this as read-only.
    return {
        classID = self.classID,
        classToken = self.classToken,
        specID = self.specID,
        specIndex = self.specIndex,
        primaryStat = self.primaryStat,
        role = self.role,
        isHealer = self.isHealer,
        enchantingSkill = self.enchantingSkill,
        equippedILvl = self.equippedILvl,
        offspecSpecID = self.offspecSpecID,
        offspecSpecName = self.offspecSpecName,
        offspecRole = self.offspecRole,
        offspecPrimaryStat = self.offspecPrimaryStat,
        worstEquippedILvl = function(equipLoc) return PlayerState:WorstEquippedILvl(equipLoc) end,
        worstSetILvl = function(equipLoc, setName) return PlayerState:WorstSetILvl(equipLoc, setName) end,
    }
end
