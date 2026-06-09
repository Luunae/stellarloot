-- StellarLoot/Slash.lua
-- /stellarloot dispatcher.

local Config      = StellarLoot.Config
local Decision    = StellarLoot.Decision
local PlayerState = StellarLoot.PlayerState
local Events      = StellarLoot.Events
local ConfigUI    = StellarLoot.ConfigUI
local Log         = StellarLoot.Log
local Data        = StellarLoot.Data

local function printHelp()
    Log:Info("commands:")
    Log:Info("  /stellarloot                  open config panel")
    Log:Info("  /stellarloot status           show current spec, primary stat, key thresholds")
    Log:Info("  /stellarloot toggle           enable/disable")
    Log:Info("  /stellarloot test             toggle preview mode (don't actually roll)")
    Log:Info("  /stellarloot verbose          toggle verbose logging")
    Log:Info("  /stellarloot log [N]          show last N saved decisions (default 20)")
    Log:Info("  /stellarloot log open         open the Decision Log sub-panel")
    Log:Info("  /stellarloot log clear        wipe saved history")
    Log:Info("  /stellarloot perchar          toggle per-character settings on this character")
    Log:Info("  /stellarloot override <id> <need|greed|pass|clear>")
    Log:Info("  /stellarloot eval <itemLink>  print what would be rolled for the linked item")
    Log:Info("  /stellarloot heirloom <link>  show heirloom recognition + effective ilvl")
    Log:Info("  /stellarloot equipped <slot>  show C_Item-sourced ilvl + cached snapshot for slot")
    Log:Info("  /stellarloot readsetilvl <name>  show per-slot itemID + C_Item ilvl for an equipment set")
end

local function cmdStatus()
    local cfg = Config:Get()
    local stat = Data.PrimaryStatName[PlayerState.primaryStat] or "?"
    local scope = Config:UsingCharOverrides() and "per-character" or "account-wide"
    Log:Info(("scope: %s"):format(scope))
    Log:Info(("status: enabled=%s test=%s class=%s spec=%s primary=%s"):format(
        tostring(cfg.enabled), tostring(cfg.testMode),
        tostring(PlayerState.classToken), tostring(PlayerState.specName),
        stat))
    Log:Info(("filters: requireUpgrade=%s needMargin=%d fallback=%s"):format(
        tostring(cfg.requireILvlUpgrade), cfg.needILvlMargin,
        tostring(cfg.fallbackAction)))
    local off = cfg.offspec or {}
    local offStat = Data.PrimaryStatName[PlayerState.offspecPrimaryStat] or "?"
    local offSet = off.equipmentSet and ('"' .. off.equipmentSet .. '"') or "(none)"
    Log:Info(("offspec: source=%s primary=%s set=%s"):format(
        tostring(off.source or "off"), offStat, offSet))
    Log:Info(("logging: enabled=%s verbose=%s"):format(
        tostring(cfg.log.enabled), tostring(cfg.log.verbose)))
end

local function cmdToggle()
    local cfg = Config:Get()
    cfg.enabled = not cfg.enabled
    Log:Info("enabled = " .. tostring(cfg.enabled))
end

local function cmdTest()
    local cfg = Config:Get()
    cfg.testMode = not cfg.testMode
    Log:Info("testMode = " .. tostring(cfg.testMode))
end

local function cmdVerbose()
    local cfg = Config:Get()
    cfg.log.verbose = not cfg.log.verbose
    Log:Info("log.verbose = " .. tostring(cfg.log.verbose))
end

local function cmdOverride(args)
    local id, action = args:match("^(%d+)%s+(%a+)$")
    if not id then
        Log:Warn("usage: /stellarloot override <itemID> <need|greed|pass|clear>")
        return
    end
    local cfg = Config:Get()
    id = tonumber(id)
    action = action:upper()
    if action == "CLEAR" then
        cfg.overrides[id] = nil
        Log:Info("cleared override for itemID " .. id)
    elseif action == "NEED" or action == "GREED" or action == "PASS" then
        cfg.overrides[id] = action
        Log:Info(("set override: %d → %s"):format(id, action))
    else
        Log:Warn("unknown action: " .. action)
    end
end

local function cmdHeirloom(args)
    local link = args:match("(|%x+|Hitem:.-|h.-|h|r)") or args:match("(item:%d[%d:]*)")
    if not link then
        Log:Warn("usage: /stellarloot heirloom <item link>  (shift-click an item into chat)")
        return
    end
    local name, _, quality = GetItemInfo(link)
    if not name then
        Log:Warn("item info not cached yet — try again in a moment")
        return
    end
    local itemID = tonumber(link:match("item:(%d+)"))
    local isHeirloom = (quality == Data.QUALITY_HEIRLOOM)
    local apiILvl = _G.GetDetailedItemLevelInfo and _G.GetDetailedItemLevelInfo(link) or 0
    local effective = Data.EffectiveILvl(link)
    Log:Info(("heirloom: %s [%s]"):format(name, tostring(itemID)))
    Log:Info(("  isHeirloom: %s   API ilvl: %d   effective ilvl: %d"):format(
        tostring(isHeirloom), apiILvl or 0, effective))
    if isHeirloom then
        Log:Info(("  → substituted Data.HEIRLOOM_ILVL = %d"):format(Data.HEIRLOOM_ILVL))
    end
end

local function cmdEquipped(args)
    local slot = tonumber(args:match("^%s*(%d+)"))
    if not slot or slot < 1 or slot > 18 then
        Log:Warn("usage: /stellarloot equipped <slot>  (1-18; head=1 chest=5 legs=7 mh=16 oh=17)")
        return
    end
    local link = GetInventoryItemLink("player", slot)
    if not link then
        Log:Info(("slot %d: empty"):format(slot))
        return
    end
    local _, _, _, baseILvl = GetItemInfo(link)
    local equippedILvl, isHeirloom = Data.EquippedILvl(slot)
    local cached = PlayerState.equippedILvl[slot] or 0
    Log:Info(("slot %d: %s"):format(slot, link))
    Log:Info(("  C_Item ilvl: %d   link base ilvl: %d   heirloom: %s")
        :format(equippedILvl, baseILvl or 0, tostring(isHeirloom)))
    Log:Info(("  PlayerState cached: %d   pending: %s")
        :format(cached, tostring(PlayerState.pendingSlots[slot])))
end

local function cmdEval(args)
    -- Extract the first valid item link from the rest of the args.
    local link = args:match("(|%x+|Hitem:.-|h.-|h|r)") or args:match("(item:%d[%d:]*)")
    if not link then
        Log:Warn("usage: /stellarloot eval <item link>  (shift-click an item into chat)")
        return
    end
    local action, trace = Events.EvaluateLink(link, nil)
    -- Force verbose for eval so the user always sees the full chain.
    Log:Verbose(trace, { testMode = false })
    Log:Info("→ would roll: " .. tostring(action))
end

-- Diagnostic: walk every slot the named equipment set defines and print what
-- the addon resolves for each one (assigned itemID, where it was located,
-- C_Item ilvl, link). Useful to verify equipment-set comparisons match what
-- the user expects without waiting for an actual loot roll.
local function cmdReadSetILvl(args)
    local name = args:match("^%s*\"(.+)\"%s*$")
                or args:match("^%s*'(.+)'%s*$")
                or args:match("^%s*(.-)%s*$")
    if not name or name == "" then
        Log:Warn("usage: /stellarloot readsetilvl <set name>")
        return
    end
    if not (C_EquipmentSet and ItemLocation and C_Item) then
        Log:Warn("equipment-set APIs unavailable on this client")
        return
    end
    local setID = C_EquipmentSet.GetEquipmentSetID(name)
    if not setID then
        Log:Warn(("no equipment set named %q"):format(name))
        return
    end
    local ids = C_EquipmentSet.GetItemIDs and C_EquipmentSet.GetItemIDs(setID)
    if not ids then
        Log:Warn(("set %q exists but C_EquipmentSet.GetItemIDs returned nothing"):format(name))
        return
    end
    Log:Info(("set %q (id %d):"):format(name, setID))
    local any = false
    for invSlot = 1, 19 do
        local itemID = ids[invSlot]
        if itemID and itemID ~= 0 then
            any = true
            local loc = PlayerState:GetEquipmentSetItemLocation(name, invSlot)
            if loc then
                local ilvl = C_Item.GetCurrentItemLevel(loc) or 0
                local link = C_Item.GetItemLink and C_Item.GetItemLink(loc) or "?"
                Log:Info(("  slot %2d  id %d  ilvl %d  %s"):format(invSlot, itemID, ilvl, link))
            else
                Log:Info(("  slot %2d  id %d  (not in equipped or bags — bank/void?)"):format(invSlot, itemID))
            end
        end
    end
    if not any then
        Log:Info("  (set has no items assigned)")
    end
end

local function cmdLog(rest)
    local arg = rest:match("^%s*(%S*)")
    if arg == "clear" then
        Config:ClearLog()
        Log:Info("history cleared.")
        return
    end
    if arg == "open" then
        if StellarLoot.LogUI and StellarLoot.LogUI.Open then
            StellarLoot.LogUI:Open()
        end
        return
    end
    local n = tonumber(arg) or 20
    Log:PrintRecent(n)
end

local function cmdPerChar()
    local newState = not Config:UsingCharOverrides()
    Config:EnableCharOverrides(newState)
    Log:Info(("per-character settings: %s"):format(newState and "ENABLED" or "DISABLED"))
end

local handlers = {
    [""]        = function() ConfigUI:Open() end,
    ["config"]  = function() ConfigUI:Open() end,
    ["status"]  = cmdStatus,
    ["toggle"]  = cmdToggle,
    ["test"]    = cmdTest,
    ["verbose"] = cmdVerbose,
    ["perchar"] = cmdPerChar,
    ["help"]    = printHelp,
    ["?"]       = printHelp,
}

SLASH_STELLARLOOT1 = "/stellarloot"
SLASH_STELLARLOOT2 = "/sl"
SlashCmdList["STELLARLOOT"] = function(msg)
    msg = msg or ""
    local cmd, rest = msg:match("^(%S*)%s*(.*)$")
    cmd = (cmd or ""):lower()
    if handlers[cmd] then
        handlers[cmd]()
    elseif cmd == "override" then
        cmdOverride(rest)
    elseif cmd == "eval" then
        cmdEval(rest)
    elseif cmd == "heirloom" then
        cmdHeirloom(rest)
    elseif cmd == "equipped" then
        cmdEquipped(rest)
    elseif cmd == "readsetilvl" then
        cmdReadSetILvl(rest)
    elseif cmd == "log" then
        cmdLog(rest)
    else
        Log:Warn("unknown subcommand: " .. cmd)
        printHelp()
    end
end
