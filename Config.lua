-- StellarLoot/Config.lua
-- Two-tier saved variables:
--   StellarLootDB     — account-wide settings (the source of truth)
--   StellarLootCharDB — per-character overrides (only used when activated)
--
-- Reads/writes go to whichever scope is currently active. Toggling
-- per-character overrides ON copies the global table as a starting point so
-- the player isn't editing a blank slate. Toggling OFF preserves the per-char
-- copy (so re-enabling restores it) but the global table becomes active again.

local Config = {}
StellarLoot.Config = Config

Config.DEFAULTS = {
    version = 1,
    enabled = true,
    testMode = false,                 -- print decisions, don't actually roll
    -- Upgrade filter. Default off: ilvl is an unreliable signal of item value
    -- across expansions and on irregularly-budgeted items (BoAs, PvP gear,
    -- heirlooms). Stat-match alone is the more honest signal. Turn on for
    -- stricter endgame behavior.
    requireILvlUpgrade = false,
    needILvlMargin = 0,               -- ilvls beyond equipped required for Need
    heirloomNeedMarginExtra = 0,      -- extra margin when the slot we'd replace holds a heirloom (XP-bonus stickiness)
    fallbackAction = "GREED",         -- GREED | PASS | NEED | MANUAL
    overrides = {},                   -- [itemID] = "NEED" | "GREED" | "PASS"
    classOverrides = {
        primaryStat = nil,
        extraStats  = {},
    },
    offspec = {
        source = "off",               -- "off" | "auto" | "manual"
        primaryStat = nil,            -- 1=Str, 2=Agi, 4=Int (manual or auto fallback)
        equipmentSet = nil,           -- equipment set name; nil disables off-spec ilvl checks
    },
    log = {
        enabled = true,               -- master: print to chat + persist + show in sub-panel
        verbose = false,              -- show full factor trace (chat + sub-panel)
        maxEntries = 200,             -- circular buffer cap
    },
}

local function deepMerge(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            deepMerge(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
    return target
end

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

function Config:Init()
    if type(StellarLootDB) ~= "table"     then StellarLootDB = {}     end
    if type(StellarLootCharDB) ~= "table" then StellarLootCharDB = {} end
    if type(StellarLootLog) ~= "table"    then StellarLootLog = { entries = {} } end
    if type(StellarLootLog.entries) ~= "table" then StellarLootLog.entries = {} end

    deepMerge(StellarLootDB, Config.DEFAULTS)

    -- Per-char metadata lives in __meta to avoid colliding with setting keys.
    StellarLootCharDB.__meta = StellarLootCharDB.__meta or { active = false, seeded = false }

    -- If per-char was previously seeded, fill in any new default keys that
    -- have been added since (without overwriting existing user choices).
    if StellarLootCharDB.__meta.seeded then
        deepMerge(StellarLootCharDB, Config.DEFAULTS)
    end

    -- Migration: drop the obsolete log.save flag (folded into log.enabled).
    if StellarLootDB.log     and StellarLootDB.log.save     ~= nil then StellarLootDB.log.save     = nil end
    if StellarLootCharDB.log and StellarLootCharDB.log.save ~= nil then StellarLootCharDB.log.save = nil end

    self.global = StellarLootDB
    self.char   = StellarLootCharDB
    self.log    = StellarLootLog
    return self:Get()
end

function Config:UsingCharOverrides()
    return self.char and self.char.__meta and self.char.__meta.active or false
end

function Config:EnableCharOverrides(on)
    if not self.char then return end
    self.char.__meta = self.char.__meta or {}
    if on then
        if not self.char.__meta.seeded then
            -- Seed from global so the user starts with a known-good baseline.
            for k, v in pairs(self.global) do
                if type(v) == "table" then
                    self.char[k] = deepCopy(v)
                else
                    self.char[k] = v
                end
            end
            self.char.__meta.seeded = true
        end
        self.char.__meta.active = true
    else
        self.char.__meta.active = false
    end
end

-- Returns the active table (per-char if overrides on, global otherwise).
-- All UI/event code mutates this table directly; the active scope is
-- transparent to callers.
function Config:Get()
    if self:UsingCharOverrides() then return self.char end
    return self.global
end

function Config:GetGlobal() return self.global end
function Config:GetChar()   return self.char   end
function Config:GetLog()    return self.log    end

function Config:ResetActive()
    -- Reset whichever scope is active to defaults.
    local active = self:Get()
    -- Wipe (preserving __meta on char)
    local meta = active.__meta
    for k in pairs(active) do active[k] = nil end
    if meta then active.__meta = meta end
    deepMerge(active, Config.DEFAULTS)
end

function Config:ClearLog()
    if self.log then self.log.entries = {} end
end
