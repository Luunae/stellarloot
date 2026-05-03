-- AutoRoll/Slash.lua
-- /autoroll dispatcher.

local Config      = AutoRoll.Config
local Decision    = AutoRoll.Decision
local PlayerState = AutoRoll.PlayerState
local Events      = AutoRoll.Events
local ConfigUI    = AutoRoll.ConfigUI
local Log         = AutoRoll.Log
local Data        = AutoRoll.Data

local function printHelp()
    Log:Info("commands:")
    Log:Info("  /autoroll                  open config panel")
    Log:Info("  /autoroll status           show current spec, primary stat, key thresholds")
    Log:Info("  /autoroll toggle           enable/disable")
    Log:Info("  /autoroll test             toggle preview mode (don't actually roll)")
    Log:Info("  /autoroll verbose          toggle verbose logging")
    Log:Info("  /autoroll log [N]          show last N saved decisions (default 20)")
    Log:Info("  /autoroll log open         open the Decision Log sub-panel")
    Log:Info("  /autoroll log clear        wipe saved history")
    Log:Info("  /autoroll perchar          toggle per-character settings on this character")
    Log:Info("  /autoroll override <id> <need|greed|pass|de|clear>")
    Log:Info("  /autoroll eval <itemLink>  print what would be rolled for the linked item")
end

local function cmdStatus()
    local cfg = Config:Get()
    local stat = Data.PrimaryStatName[PlayerState.primaryStat] or "?"
    local scope = Config:UsingCharOverrides() and "per-character" or "account-wide"
    Log:Info(("scope: %s"):format(scope))
    Log:Info(("status: enabled=%s test=%s class=%s spec=%s primary=%s enchanting=%d"):format(
        tostring(cfg.enabled), tostring(cfg.testMode),
        tostring(PlayerState.classToken), tostring(PlayerState.specName),
        stat, PlayerState.enchantingSkill or 0))
    Log:Info(("filters: qualityFilter=%s minQuality=%s requireUpgrade=%s needMargin=%d"):format(
        tostring(cfg.qualityFilterEnabled),
        Data.QualityNames[cfg.minQuality] or cfg.minQuality,
        tostring(cfg.requireILvlUpgrade), cfg.needILvlMargin))
    Log:Info(("behavior: greedUnusable=%s preferDE=%s fallback=%s"):format(
        tostring(cfg.greedUnusable),
        tostring(cfg.preferDEoverGreed), tostring(cfg.fallbackAction)))
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
        Log:Warn("usage: /autoroll override <itemID> <need|greed|pass|de|clear>")
        return
    end
    local cfg = Config:Get()
    id = tonumber(id)
    action = action:upper()
    if action == "CLEAR" then
        cfg.overrides[id] = nil
        Log:Info("cleared override for itemID " .. id)
    elseif action == "NEED" or action == "GREED" or action == "PASS" or action == "DE" then
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
        Log:Warn("usage: /autoroll eval <item link>  (shift-click an item into chat)")
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
        if AutoRoll.LogUI and AutoRoll.LogUI.Open then
            AutoRoll.LogUI:Open()
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

SLASH_AUTOROLL1 = "/autoroll"
SLASH_AUTOROLL2 = "/ar"
SlashCmdList["AUTOROLL"] = function(msg)
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
