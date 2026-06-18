-- StellarLoot/PlayerState.lua
-- Cached snapshot of player class, spec, primary stat, and equipped item
-- levels per slot. Refreshed on relevant events.

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
    equippedILvl = {},        -- [invSlot] = ilvl number (heirloom synthetic applied)
    equippedHeirloom = {},    -- [invSlot] = true if the equipped item is a heirloom
    pendingSlots = {},        -- [invSlot] = itemID for slots whose ilvl read 0 (item not cached yet)
    mainHandTwoHand = nil,    -- true when the equipped main-hand weapon is a 2H

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

function PlayerState:RefreshSlot(slot)
    if not slot or slot < 1 then return end
    local link = GetInventoryItemLink("player", slot)
    if link then
        local ilvl, isHeirloom = Data.EquippedILvl(slot)
        self.equippedILvl[slot] = ilvl
        self.equippedHeirloom[slot] = isHeirloom or nil
        -- A non-empty slot resolving to ilvl 0 means the item isn't in the
        -- client cache yet — common at PLAYER_LOGIN. Remember the itemID so
        -- GET_ITEM_INFO_RECEIVED can re-read the slot. Otherwise it stays a
        -- stale 0 and every same-slot roll looks like a huge upgrade.
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

    -- Track main-hand handedness: a 2H in the main hand leaves the off-hand
    -- slot empty, which Decision must not mistake for a free off-hand upgrade.
    -- GetItemInfoInstant resolves equipLoc without the server item cache, so
    -- this is correct even at login before the item's full info arrives.
    if slot == 16 then
        local equipLoc = link and select(4, GetItemInfoInstant(link)) or nil
        self.mainHandTwoHand = (equipLoc == "INVTYPE_2HWEAPON") or nil
    end
end

function PlayerState:RefreshAllSlots()
    -- Slots 1..18 cover the visible equipment slots (excl. shirt 4 / tabard 19,
    -- which never roll). Bag slots (20+) are not gear.
    for slot = 1, 18 do
        self:RefreshSlot(slot)
    end
    -- Verbose-only readout of resolved ilvls — visible confirmation that
    -- upgrade-aware equipped reads landed correctly at load.
    local parts = {}
    for slot = 1, 18 do
        local ilvl = self.equippedILvl[slot] or 0
        if ilvl > 0 then
            table.insert(parts, ("%d=%d"):format(slot, ilvl))
        end
    end
    if #parts > 0 then
        debugLog("equipped ilvl: " .. table.concat(parts, " "))
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
--
-- If incomingName is provided and any slot in the family holds an item of that
-- same name, return THAT slot specifically. This handles Unique-Equipped rings
-- and trinkets (the common case is two same-family rings at different ilvls;
-- the game forces you to replace the matching one, not the worst). Matching by
-- name rather than itemID catches Celestial/Normal/Heroic siblings, which share
-- names but use different itemIDs.
function PlayerState:WorstEquippedILvl(equipLoc, incomingName)
    local slots = Data.EquipLocToSlots[equipLoc]
    if not slots then return 0, false end

    if incomingName then
        for _, slot in ipairs(slots) do
            local link = GetInventoryItemLink("player", slot)
            if link then
                local equippedName = GetItemInfo(link)
                if equippedName == incomingName then
                    return self.equippedILvl[slot] or 0, self.equippedHeirloom[slot] or false
                end
            end
        end
    end

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

-- Locate the item the named equipment set assigns to a given inv slot, as an
-- ItemLocation suitable for C_Item.GetCurrentItemLevel. Returns nil if the set
-- doesn't define that slot, the set name is invalid, or the item can't be
-- found in equipped slots or bags (bank/void storage are out of reach while
-- away from them).
--
-- We deliberately don't trust C_EquipmentSet.GetItemLocations here: on MoP
-- 5.5.4 it can hand back a player-encoded location for a set whose item lives
-- in bags, which then resolves to "whatever's currently equipped in that
-- slot" — a different item entirely, since the set isn't active. Going via
-- GetItemIDs and locating each itemID ourselves is robust to that quirk and
-- works the same in all expansions.
function PlayerState:GetEquipmentSetItemLocation(setName, invSlot)
    if not setName or not invSlot then return nil end
    if not (C_EquipmentSet and ItemLocation and C_Item) then return nil end
    local setID = C_EquipmentSet.GetEquipmentSetID(setName)
    if not setID then return nil end
    local ids = C_EquipmentSet.GetItemIDs and C_EquipmentSet.GetItemIDs(setID)
    if not ids then return nil end
    local wantedID = ids[invSlot]
    if not wantedID or wantedID == 0 then return nil end

    if GetInventoryItemID and GetInventoryItemID("player", invSlot) == wantedID then
        local loc = ItemLocation:CreateFromEquipmentSlot(invSlot)
        if C_Item.DoesItemExist(loc) then return loc end
    end

    local getNumSlots = (C_Container and C_Container.GetContainerNumSlots) or _G.GetContainerNumSlots
    local getItemID = (C_Container and C_Container.GetContainerItemID) or _G.GetContainerItemID
    if not getNumSlots or not getItemID then return nil end
    local lastBag = NUM_BAG_SLOTS or 4
    for bag = 0, lastBag do
        local n = getNumSlots(bag) or 0
        for s = 1, n do
            if getItemID(bag, s) == wantedID then
                local loc = ItemLocation:CreateFromBagAndSlot(bag, s)
                if C_Item.DoesItemExist(loc) then return loc end
            end
        end
    end
    return nil
end

-- Worst ilvl across the slots an equipLoc maps to, using items from an
-- equipment set rather than what's currently equipped. Returns (ilvl,
-- isHeirloom) — ilvl is nil if the set has no items in any of those slots
-- (caller treats that as "no comparison possible"). Reads through
-- C_Item.GetCurrentItemLevel so MoP upgrades are reflected even when the set
-- item is sitting in a bag (link-based reads would understate it).
--
-- Same unique-equipped sibling rule as WorstEquippedILvl: if incomingName is
-- supplied and the set contains a same-name item, prefer that slot.
function PlayerState:WorstSetILvl(equipLoc, setName, incomingName)
    local slots = Data.EquipLocToSlots[equipLoc]
    if not slots or not setName then return nil, false end
    if not (C_Item and ItemLocation) then return nil, false end

    local function readSlot(invSlot)
        local loc = self:GetEquipmentSetItemLocation(setName, invSlot)
        if not loc then return nil end
        local ilvl = C_Item.GetCurrentItemLevel(loc) or 0
        local link = C_Item.GetItemLink and C_Item.GetItemLink(loc)
        local isHeirloom = link and Data.IsHeirloom(link) or false
        if isHeirloom and Data.HEIRLOOM_ILVL > ilvl then
            ilvl = Data.HEIRLOOM_ILVL
        end
        return ilvl, isHeirloom, link
    end

    if incomingName then
        for _, slot in ipairs(slots) do
            local ilvl, isHeirloom, link = readSlot(slot)
            if link and GetItemInfo(link) == incomingName then
                return ilvl, isHeirloom
            end
        end
    end

    local worst, worstHeirloom
    for _, slot in ipairs(slots) do
        local ilvl, isHeirloom = readSlot(slot)
        if ilvl then
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
        mainHandTwoHand = self.mainHandTwoHand,
        equippedILvl = self.equippedILvl,
        offspecSpecID = self.offspecSpecID,
        offspecSpecName = self.offspecSpecName,
        offspecRole = self.offspecRole,
        offspecPrimaryStat = self.offspecPrimaryStat,
        worstEquippedILvl = function(equipLoc, incomingName) return PlayerState:WorstEquippedILvl(equipLoc, incomingName) end,
        worstSetILvl = function(equipLoc, setName, incomingName) return PlayerState:WorstSetILvl(equipLoc, setName, incomingName) end,
    }
end
