-- AutoRoll/LogUI.lua
-- Sub-panel ("Log") nested under the main AutoRoll category in the Settings
-- tree. Renders the persistent decision history embedded in the panel — no
-- chat-frame dump required. Live-refreshes via Log:Subscribe so new decisions
-- appear immediately while the panel is open.

local Config = AutoRoll.Config
local Log    = AutoRoll.Log

local LogUI = {}
AutoRoll.LogUI = LogUI

local ACTION_COLORS = {
    NEED   = "|cff00ff00",
    GREED  = "|cffffff00",
    DE     = "|cffff8800",
    PASS   = "|cff999999",
    DEFER  = "|cff8888ff",
    MANUAL = "|cffcccccc",
}

local panel = CreateFrame("Frame", "AutoRollLogPanel", UIParent)
panel.name = "Log"
panel.parent = "AutoRoll"   -- legacy fallback; modern path uses RegisterCanvasLayoutSubcategory
panel:Hide()
LogUI.panel = panel

-- ---- Header ---------------------------------------------------------------

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("AutoRoll — Decision Log")

local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
subtitle:SetWidth(540)
subtitle:SetJustifyH("LEFT")
subtitle:SetText("Most recent decisions appear at the top. Click any item link for a tooltip; shift-click to chat-link it.")

local cbEnabled = CreateFrame("CheckButton", "AutoRollLog_cbEnabled", panel, "InterfaceOptionsCheckButtonTemplate")
cbEnabled:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -12)
_G[cbEnabled:GetName() .. "Text"]:SetText("Logging enabled (record decisions and print to chat)")
cbEnabled.tooltipText = "Logging master toggle"
cbEnabled.tooltipRequirement = "When off, no decisions are recorded here and nothing is printed to chat."
cbEnabled:SetScript("OnClick", function(self)
    Config:Get().log.enabled = self:GetChecked() and true or false
end)

local cbVerbose = CreateFrame("CheckButton", "AutoRollLog_cbVerbose", panel, "InterfaceOptionsCheckButtonTemplate")
cbVerbose:SetPoint("TOPLEFT", cbEnabled, "BOTTOMLEFT", 0, -2)
_G[cbVerbose:GetName() .. "Text"]:SetText("Verbose: show every factor checked")
cbVerbose.tooltipText = "Verbose display"
cbVerbose.tooltipRequirement = "When on, each entry expands to show every check that ran (decisive marked with →). Off: just the action, item, and decisive reason."
cbVerbose:SetScript("OnClick", function(self)
    Config:Get().log.verbose = self:GetChecked() and true or false
    LogUI:Refresh()
end)

local btnClear = CreateFrame("Button", "AutoRollLog_btnClear", panel, "UIPanelButtonTemplate")
btnClear:SetSize(120, 22)
btnClear:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -16)
btnClear:SetText("Clear history")
btnClear:SetScript("OnClick", function() StaticPopup_Show("AUTOROLL_CONFIRM_CLEAR_LOG") end)

StaticPopupDialogs["AUTOROLL_CONFIRM_CLEAR_LOG"] = {
    text = "Clear AutoRoll decision history?",
    button1 = YES, button2 = NO,
    OnAccept = function()
        Config:ClearLog()
        Log:Info("history cleared.")
        LogUI:Refresh()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

-- ---- Scrolling history ----------------------------------------------------

local scroll = CreateFrame("ScrollFrame", "AutoRollLog_Scroll", panel, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", cbVerbose, "BOTTOMLEFT", 0, -12)
scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 16)

local content = CreateFrame("Frame", "AutoRollLog_Content", scroll)
content:SetSize(540, 1)
scroll:SetScrollChild(content)

-- Hyperlink wiring: enable on the content frame so item links inside any of
-- the row FontStrings respond to click/hover with chat-style behavior.
content:EnableMouse(true)
content:SetHyperlinksEnabled(true)
content:SetScript("OnHyperlinkClick", function(_, link, text, button)
    SetItemRef(link, text, button)
end)
content:SetScript("OnHyperlinkEnter", function(self, link)
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:SetHyperlink(link)
    GameTooltip:Show()
end)
content:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)

-- Pool of FontStrings, one per visible entry.
local rows = {}
local function getRow(i)
    local fs = rows[i]
    if fs then return fs end
    fs = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    fs:SetWidth(520)
    rows[i] = fs
    return fs
end

local function formatEntry(e, verbose)
    local actionColor = ACTION_COLORS[e.action] or "|cffffffff"
    local stamp       = e.time and date("%H:%M:%S", e.time) or "??:??:??"
    local prefix      = e.testMode and "WOULD " or ""
    local item        = e.itemLink or ("itemID " .. tostring(e.itemID))
    local lines = {}
    table.insert(lines,
        ("|cff999999[%s]|r %s%s%s|r  %s  |cff999999— %s|r"):format(
            stamp, prefix, actionColor, tostring(e.action or "?"),
            item, e.reason or "(no reason)"))
    if verbose and e.factors then
        for _, f in ipairs(e.factors) do
            local marker = f.decisive and "|cffffffff→|r" or "|cff666666·|r"
            local color  = f.decisive and "|cffdddddd" or "|cff888888"
            table.insert(lines, ("        %s %s%s|r"):format(marker, color, f.text))
        end
    end
    return table.concat(lines, "\n")
end

function LogUI:Refresh()
    -- Sync header checkboxes to current config.
    local cfg = Config:Get()
    cbEnabled:SetChecked(cfg.log and cfg.log.enabled and true or false)
    cbVerbose:SetChecked(cfg.log and cfg.log.verbose and true or false)

    local entries = Log:GetEntries()
    local total = #entries

    if total == 0 then
        local fs = getRow(1)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -8)
        fs:SetText("|cff999999(no entries yet — let a roll fire, or try /autoroll eval <itemlink>)|r")
        fs:Show()
        for i = 2, #rows do rows[i]:Hide() end
        content:SetHeight(40)
        return
    end

    local verbose = cfg.log and cfg.log.verbose
    local y, rowIdx = 8, 0
    -- Newest first.
    for i = total, 1, -1 do
        rowIdx = rowIdx + 1
        local fs = getRow(rowIdx)
        fs:SetText(formatEntry(entries[i], verbose))
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -y)
        fs:Show()
        y = y + fs:GetStringHeight() + 6
    end
    for i = rowIdx + 1, #rows do rows[i]:Hide() end
    content:SetHeight(math.max(40, y))
end

-- Live refresh when a new entry lands.
Log:Subscribe(function()
    if panel:IsShown() then LogUI:Refresh() end
end)

-- Refresh whenever the panel becomes visible.
panel:SetScript("OnShow", function() LogUI:Refresh() end)
panel.refresh = function() LogUI:Refresh() end
panel.okay    = function() end
panel.cancel  = function() end
panel.default = function() end

-- ---- Registration ---------------------------------------------------------

if Settings and Settings.RegisterCanvasLayoutSubcategory
        and AutoRoll.ConfigUI and AutoRoll.ConfigUI.panel
        and AutoRoll.ConfigUI.panel.settingsCategory then
    local sub = Settings.RegisterCanvasLayoutSubcategory(
        AutoRoll.ConfigUI.panel.settingsCategory, panel, panel.name)
    if sub then
        sub.ID = "AutoRollLog"
        panel.settingsCategory = sub
    end
elseif _G.InterfaceOptions_AddCategory then
    _G.InterfaceOptions_AddCategory(panel)
end

function LogUI:Open()
    if Settings and Settings.OpenToCategory and panel.settingsCategory then
        Settings.OpenToCategory(panel.settingsCategory:GetID() or panel.settingsCategory.ID)
    elseif _G.InterfaceOptionsFrame_OpenToCategory then
        _G.InterfaceOptionsFrame_OpenToCategory(panel)
        _G.InterfaceOptionsFrame_OpenToCategory(panel)
    else
        Log:Warn("no options panel system detected on this client")
    end
end
