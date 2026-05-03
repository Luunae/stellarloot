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
    Log:Info(("filters: qualityFilter=%s minQuality=%s requireUpgrade=%s needMargin=%d"):format(
        tostring(cfg.qualityFilterEnabled),
        Data.QualityNames[cfg.minQuality] or cfg.minQuality,
        tostring(cfg.requireILvlUpgrade), cfg.needILvlMargin))
    Log:Info(("behavior: greedUnusable=%s fallback=%s"):format(
        tostring(cfg.greedUnusable), tostring(cfg.fallbackAction)))
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
    elseif cmd == "log" then
        cmdLog(rest)
    else
        Log:Warn("unknown subcommand: " .. cmd)
        printHelp()
    end
end
