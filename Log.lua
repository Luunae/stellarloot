-- StellarLoot/Log.lua
-- Centralized chat output + a circular decision-history buffer.
-- Renders Decision traces in two modes:
--   terse   : one line per roll — action, item, decisive reason
--   verbose : multi-line, every factor checked
-- Test-mode prefix is "WOULD " to make dry-runs visually distinct.
-- When cfg.log.enabled is true, each rendered decision is appended to
-- StellarLootLog.entries (capped by cfg.log.maxEntries) AND printed to chat.
-- Subscribers (e.g. LogUI) can register via Log:Subscribe to get notified
-- on each new saved entry.

local Log = {}
StellarLoot.Log = Log

Log.listeners = {}

local PREFIX = "|cff66ccffStellarLoot|r"

local ACTION_COLORS = {
    NEED   = "|cff00ff00",
    GREED  = "|cffffff00",
    PASS   = "|cff999999",
    DEFER  = "|cff8888ff",
    MANUAL = "|cffcccccc",
}

local function colorAction(action)
    local c = ACTION_COLORS[action] or "|cffffffff"
    return c .. tostring(action) .. "|r"
end

local function chatPrint(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. " " .. msg)
end

-- Terse one-liner.
function Log:Terse(trace, opts)
    opts = opts or {}
    local verb = opts.testMode and "WOULD " or ""
    local actionStr = colorAction(trace.action or "?")
    local item = trace.itemLink or ("itemID " .. tostring(trace.itemID))
    local reason = trace.reason or "(no reason recorded)"
    chatPrint(("%s%s %s — %s"):format(verb, actionStr, item, reason))
end

-- Verbose multi-line.
function Log:Verbose(trace, opts)
    opts = opts or {}
    local verb = opts.testMode and "WOULD " or ""
    local actionStr = colorAction(trace.action or "?")
    local item = trace.itemLink or ("itemID " .. tostring(trace.itemID))
    chatPrint(("%s%s %s"):format(verb, actionStr, item))
    for _, f in ipairs(trace.factors or {}) do
        local marker = f.decisive and "|cffffffff→|r" or "|cff666666·|r"
        chatPrint(("  %s %s"):format(marker, f.text))
    end
end

-- Append a trace to the persistent log buffer (circular, capped).
function Log:Save(trace, cfg)
    if not (cfg.log and cfg.log.enabled) then return end
    local store = StellarLoot.Config:GetLog()
    if not store then return end
    local entry = {
        time     = time(),
        action   = trace.action,
        itemLink = trace.itemLink,
        itemID   = trace.itemID,
        reason   = trace.reason,
        factors  = {},
        testMode = cfg.testMode and true or false,
    }
    -- Strip structured `data` fields; keep only the human-readable text so
    -- the saved table stays small and human-readable.
    for _, f in ipairs(trace.factors or {}) do
        table.insert(entry.factors, { text = f.text, decisive = f.decisive })
    end
    table.insert(store.entries, entry)
    local cap = (cfg.log and cfg.log.maxEntries) or 200
    while #store.entries > cap do
        table.remove(store.entries, 1)
    end
    for _, fn in ipairs(self.listeners) do
        pcall(fn, entry)
    end
end

function Log:Subscribe(fn)
    table.insert(self.listeners, fn)
end

function Log:GetEntries()
    local store = StellarLoot.Config:GetLog()
    return store and store.entries or {}
end

-- Honor cfg.log.{enabled,verbose}; testMode forces logging on so dry-runs
-- always print regardless of user settings.
function Log:Render(trace, cfg)
    if not trace then return end
    local opts = { testMode = cfg.testMode }
    if cfg.testMode or (cfg.log and cfg.log.enabled) then
        if cfg.log and cfg.log.verbose then
            self:Verbose(trace, opts)
        else
            self:Terse(trace, opts)
        end
    end
    self:Save(trace, cfg)
end

-- View N most recent saved entries in chat.
function Log:PrintRecent(n)
    local store = StellarLoot.Config:GetLog()
    local entries = store and store.entries or {}
    n = n or 20
    local total = #entries
    if total == 0 then
        chatPrint("history: (empty)")
        return
    end
    chatPrint(("history: showing %d of %d entries"):format(math.min(n, total), total))
    local startIdx = math.max(1, total - n + 1)
    for i = startIdx, total do
        local e = entries[i]
        local verb = e.testMode and "WOULD " or ""
        local actionStr = colorAction(e.action or "?")
        local item = e.itemLink or ("itemID " .. tostring(e.itemID))
        local reason = e.reason or "(no reason)"
        chatPrint(("  [%s] %s%s %s — %s"):format(
            date("%H:%M:%S", e.time), verb, actionStr, item, reason))
    end
end

function Log:Info(msg)
    chatPrint(msg)
end

function Log:Warn(msg)
    chatPrint("|cffff8800Warning:|r " .. msg)
end
