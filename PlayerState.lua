-- AutoRoll/PlayerState.lua
-- Cached snapshot of player class, spec, primary stat, enchanting skill, and
-- equipped item levels per slot. Refreshed on relevant events.

local Data = AutoRoll.Data

-- Compat: spec info was moved to C_SpecializationInfo in newer clients.
local function getSpecIndex()
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        return C_SpecializationInfo.GetSpecialization()
    end
    if _G.GetSpecialization then return _G.GetSpecialization() end
    return nil
end

local function getSpecInfo(idx)
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
        return C_SpecializationInfo.GetSpecializationInfo(idx)
    end
    if _G.GetSpecializationInfo then return _G.GetSpecializationInfo(idx) end
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
}
AutoRoll.PlayerState = PlayerState

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
        worstEquippedILvl = function(equipLoc) return PlayerState:WorstEquippedILvl(equipLoc) end,
    }
end
