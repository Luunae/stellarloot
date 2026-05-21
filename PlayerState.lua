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

-- Verbose-gated diagnostic line. Config and Log both load *after* this file
-- (see StellarLoot.toc), so neither can be captured at file scope — resolve
-- them lazily here. Every caller runs at/after PLAYER_LOGIN, by which point
-- both modules exist.
local function debugLog(msg)
    local cfg = StellarLoot.Config and StellarLoot.Config:Get()
    if cfg and cfg.log and cfg.log.verbose and StellarLoot.Log then
        StellarLoot.Log:Info(msg)
    end
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
    equippedILvl = {},        -- [invSlot] = ilvl number (heirloom synthetic applied)
    equippedHeirloom = {},    -- [invSlot] = true if the equipped item is a heirloom
    pendingSlots = {},        -- [invSlot] = itemID for slots whose ilvl read 0 (item not cached yet)

    -- Off-spec (populated by RefreshOffSpec; nil when disabled or unavailable)
    offspecSpecID = nil,
    offspecSpecName = nil,
    offspecRole = nil,
    offspecPrimaryStat = nil,
}
StellarLoot.PlayerState = PlayerState

-- Effective ilvl resolution lives in Data.EffectiveILvl so the equipped-side
-- snapshot and the incoming-roll side (Decision) share heirloom handling.

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
    if link then
        local ilvl, isHeirloom = Data.EffectiveILvl(link)
        self.equippedILvl[slot] = ilvl
        self.equippedHeirloom[slot] = isHeirloom or nil
        -- A non-empty slot resolving to ilvl 0 means the item isn't in the
        -- client cache yet — common at PLAYER_LOGIN, especially for upgraded
        -- items whose ilvl needs the server's upgrade data. Remember the
        -- itemID so GET_ITEM_INFO_RECEIVED can re-read the slot. Otherwise it
        -- stays a stale 0 and every same-slot roll looks like a huge upgrade.
        --
        -- TODO: this gates "pending" on ilvl == 0 only. If an upgraded item's
        -- detailed ilvl hasn't resolved yet, Data.EffectiveILvl can return its
        -- non-zero *base* ilvl instead — which slips past this check, so the
        -- slot is never re-read and the equipped snapshot stays understated.
        -- Needs in-client verification with upgraded gear before fixing.
        if ilvl == 0 then
            local pendingID = tonumber(link:match("item:(%d+)"))
            self.pendingSlots[slot] = pendingID
            debugLog(("slot %d: item %s info not loaded — ilvl unresolved, queued for re-read")
                :format(slot, tostring(pendingID)))
        else
            self.pendingSlots[slot] = nil
        end
    else
        self.equippedILvl[slot] = 0
        self.equippedHeirloom[slot] = nil
        self.pendingSlots[slot] = nil
    end
end

function PlayerState:RefreshAllSlots()
    -- Slots 1..18 cover the visible equipment slots (excl. shirt 4 / tabard 19,
    -- which never roll). Bag slots (20+) are not gear.
    for slot = 1, 18 do
        self:RefreshSlot(slot)
    end
end

-- Re-read any equipped slot whose ilvl previously resolved to 0 because the
-- item wasn't cached. Called from the GET_ITEM_INFO_RECEIVED handler once the
-- named item finishes loading. Returns true if a slot was updated.
function PlayerState:ResolvePendingSlot(itemID)
    if not itemID then return false end
    local updated = false
    -- RefreshSlot only mutates pendingSlots[slot] for the slot it's given, so
    -- clearing the current key mid-iteration is safe in Lua 5.1.
    for slot, pendingID in pairs(self.pendingSlots) do
        if pendingID == itemID then
            self:RefreshSlot(slot)
            updated = true
            if not self.pendingSlots[slot] then
                debugLog(("slot %d: re-read after item load — ilvl %d")
                    :format(slot, self.equippedILvl[slot] or 0))
            end
        end
    end
    return updated
end

-- Worst-of-comparison ilvl across all slots an equipLoc could fill. Returns
-- (ilvl, isHeirloom) where isHeirloom reflects the slot that produced the worst
-- ilvl (i.e. the one we'd be replacing) — used by Decision to pad needILvlMargin.
function PlayerState:WorstEquippedILvl(equipLoc)
    local slots = Data.EquipLocToSlots[equipLoc]
    if not slots then return 0, false end
    local worst, worstHeirloom
    for _, slot in ipairs(slots) do
        local ilvl = self.equippedILvl[slot] or 0
        if not worst or ilvl < worst then
            worst = ilvl
            worstHeirloom = self.equippedHeirloom[slot] or false
        end
    end
    return worst or 0, worstHeirloom or false
end

-- Resolve the item link the named equipment set assigns to a given inv slot.
-- Returns nil if the set doesn't define that slot, the set name is invalid, or
-- the item lives somewhere we can't read from (bank/void storage when away).
function PlayerState:GetEquipmentSetItemLink(setName, invSlot)
    if not setName or not invSlot then return nil end
    if not C_EquipmentSet or not _G.EquipmentManager_UnpackLocation then
        return nil
    end
    local setID = C_EquipmentSet.GetEquipmentSetID(setName)
    if not setID then return nil end
    local locations = C_EquipmentSet.GetItemLocations(setID)
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

-- Worst ilvl across the slots an equipLoc maps to, using items from an
-- equipment set rather than what's currently equipped. Returns (ilvl,
-- isHeirloom) — ilvl is nil if the set has no items in any of those slots
-- (caller treats that as "no comparison possible").
function PlayerState:WorstSetILvl(equipLoc, setName)
    local slots = Data.EquipLocToSlots[equipLoc]
    if not slots or not setName then return nil, false end
    local worst, worstHeirloom
    for _, slot in ipairs(slots) do
        local link = self:GetEquipmentSetItemLink(setName, slot)
        if link then
            local ilvl, isHeirloom = Data.EffectiveILvl(link)
            if not worst or ilvl < worst then
                worst = ilvl
                worstHeirloom = isHeirloom or false
            end
        end
    end
    return worst, worstHeirloom or false
end

-- Enumerate equipment set names. Returns a sorted list.
function PlayerState:GetEquipmentSetNames()
    local names = {}
    if C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs then
        for _, id in ipairs(C_EquipmentSet.GetEquipmentSetIDs()) do
            local n = C_EquipmentSet.GetEquipmentSetInfo(id)
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
