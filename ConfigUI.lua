-- StellarLoot/ConfigUI.lua
-- Blizzard Interface Options panel using stock widget templates.
-- Wrapped in a ScrollFrame so the whole content is reachable on any
-- panel size.

local Config = StellarLoot.Config
local Data   = StellarLoot.Data

local ConfigUI = {}
StellarLoot.ConfigUI = ConfigUI

local panel = CreateFrame("Frame", "StellarLootOptionsPanel", InterfaceOptionsFramePanelContainer or UIParent)
panel.name = "StellarLoot"
panel:Hide()
ConfigUI.panel = panel

-- The scroll frame fills the panel; all content goes into scrollChild.
local scroll = CreateFrame("ScrollFrame", "StellarLootOptionsScroll", panel, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 8, -8)
scroll:SetPoint("BOTTOMRIGHT", -28, 8)

local scrollChild = CreateFrame("Frame", "StellarLootOptionsScrollChild", scroll)
scrollChild:SetSize(560, 1) -- height set after layout
scroll:SetScrollChild(scrollChild)

-- Track widgets so panel.refresh can re-sync values from the saved DB.
-- Each entry: { type, widget, get, set, [enable(on)] }.
local widgets = {}

-- ---- Widget helpers --------------------------------------------------------

local function makeTitle(parent, text, anchorTo, x, y)
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", anchorTo or parent, anchorTo and "BOTTOMLEFT" or "TOPLEFT", x or 0, y or -8)
    title:SetText(text)
    return title
end

local function makeSection(parent, text, anchorTo, y, x)
    local h = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    h:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", x or 0, y or -16)
    h:SetText("|cffffd200" .. text .. "|r")
    return h
end

local function makeDescription(parent, text, anchorTo, y, width)
    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, y or -4)
    desc:SetWidth(width or 540)
    desc:SetJustifyH("LEFT")
    desc:SetText(text)
    return desc
end

local function makeCheckbox(parent, key, label, tooltip, anchorTo, x, y, getter, setter)
    local cb = CreateFrame("CheckButton", "StellarLootOpt_" .. key, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", x or 0, y or -8)
    _G[cb:GetName() .. "Text"]:SetText(label)
    cb.tooltipText = label
    cb.tooltipRequirement = tooltip
    cb.key = key
    cb:SetScript("OnClick", function(self)
        local v = self:GetChecked() and true or false
        if setter then setter(v) else Config:Get()[key] = v end
        if cb.onChange then cb.onChange(v) end
    end)
    widgets[key] = { type = "checkbox", widget = cb,
        get = getter or function() return Config:Get()[key] end,
        set = setter or function(v) Config:Get()[key] = v end }
    return cb
end

-- Slider with an associated formatter for the value label.
local function makeSlider(parent, key, label, low, high, step, tooltip, anchorTo, x, y, formatter)
    local slider = CreateFrame("Slider", "StellarLootOpt_" .. key, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", x or 16, y or -28)
    slider:SetWidth(280)
    slider:SetMinMaxValues(low, high)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    _G[slider:GetName() .. "Low"]:SetText(tostring(low))
    _G[slider:GetName() .. "High"]:SetText(tostring(high))
    _G[slider:GetName() .. "Text"]:SetText(label)
    slider.tooltipText = label
    slider.tooltipRequirement = tooltip
    slider.key = key
    slider.formatter = formatter or function(v) return label .. ": " .. v end
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        Config:Get()[key] = value
        _G[self:GetName() .. "Text"]:SetText(self.formatter(value))
    end)
    widgets[key] = { type = "slider", widget = slider,
        get = function() return Config:Get()[key] end,
        set = function(v)
            slider:SetValue(v)
            _G[slider:GetName() .. "Text"]:SetText(slider.formatter(v))
        end,
        enable = function(on)
            -- BlizzardOptionsPanel_Slider_Enable/Disable may not exist on
            -- every client; fall back to manual visual + interaction toggle.
            if on then
                if BlizzardOptionsPanel_Slider_Enable then
                    BlizzardOptionsPanel_Slider_Enable(slider)
                else
                    slider:Enable()
                    slider:SetAlpha(1.0)
                end
            else
                if BlizzardOptionsPanel_Slider_Disable then
                    BlizzardOptionsPanel_Slider_Disable(slider)
                else
                    slider:Disable()
                    slider:SetAlpha(0.5)
                end
            end
        end,
    }
    return slider
end

local function makeDropdown(parent, key, label, choices, anchorTo, x, y)
    local dd = CreateFrame("Frame", "StellarLootOpt_" .. key, parent, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", x or 0, y or -28)
    local labelFS = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    labelFS:SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 20, 2)
    labelFS:SetText(label)
    UIDropDownMenu_SetWidth(dd, 160)
    UIDropDownMenu_Initialize(dd, function(_, level)
        for _, choice in ipairs(choices) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = choice.label
            info.value = choice.value
            info.func = function()
                Config:Get()[key] = choice.value
                UIDropDownMenu_SetSelectedValue(dd, choice.value)
                UIDropDownMenu_SetText(dd, choice.label)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    widgets[key] = { type = "dropdown", widget = dd,
        get = function() return Config:Get()[key] end,
        set = function(v)
            UIDropDownMenu_SetSelectedValue(dd, v)
            for _, choice in ipairs(choices) do
                if choice.value == v then
                    UIDropDownMenu_SetText(dd, choice.label)
                    break
                end
            end
        end }
    return dd
end

local function makeButton(parent, label, anchorTo, x, y, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(160, 22)
    btn:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", x or 0, y or -8)
    btn:SetText(label)
    btn:SetScript("OnClick", onClick)
    return btn
end

-- ---- Panel layout ----------------------------------------------------------

-- Format the .toc Version field. A clean semver is shown bare; anything else
-- (git-describe output, unsubstituted placeholder, "dev" fallback) gets a
-- "(dev)" marker so it's obvious you're not running a tagged release.
--
-- The unsubstituted-placeholder literal must be assembled at runtime: the CF
-- packager does keyword substitution across .lua too, not just .toc, so a
-- bare "@project-version@" in source would be replaced with the real version
-- at package time and turn this guard into a self-defeating check.
local UNSUBSTITUTED = "@" .. "project-version@"
local function formatVersion(v)
    if not v or v == "" or v == "dev" or v == UNSUBSTITUTED then
        return "(dev)"
    end
    local clean = v:match("^v?(%d+%.%d+%.%d+)$")
    if clean then
        return "v" .. clean
    end
    local prefixed = (v:sub(1,1) == "v") and v or ("v" .. v)
    return prefixed .. " (dev)"
end

local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
local versionText = formatVersion(getMeta and getMeta("StellarLoot", "Version"))

local title = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("StellarLoot — " .. versionText)

local subtitle = makeDescription(scrollChild,
    "Automatically rolls Need / Greed / Pass on group loot based on class, spec, and equipped gear.",
    title, -4)

-- Per-character override toggle (master scope switch)
local cbPerChar = CreateFrame("CheckButton", "StellarLootOpt_useCharOverrides", scrollChild, "InterfaceOptionsCheckButtonTemplate")
cbPerChar:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -16)
_G[cbPerChar:GetName() .. "Text"]:SetText("Use per-character settings on this character")
cbPerChar.tooltipText = "Per-character settings"
cbPerChar.tooltipRequirement =
    "When OFF (default), this character uses your account-wide settings. " ..
    "When ON, this character has its own copy of the settings (seeded from the global ones the first time you turn it on). " ..
    "Toggling OFF preserves the per-character copy so you can turn it back on later."
cbPerChar:SetScript("OnClick", function(self)
    Config:EnableCharOverrides(self:GetChecked() and true or false)
    panel.refresh()
end)
widgets.__perchar = {
    type = "checkbox", widget = cbPerChar,
    get = function() return Config:UsingCharOverrides() end,
    set = function(v) cbPerChar:SetChecked(v and true or false) end,
}

local perCharDesc = makeDescription(scrollChild,
    "All other settings on this panel apply to whichever scope is active.",
    cbPerChar, -2)

-- ---- Section: Roll Behavior -----------------------------------------------
local sec1 = makeSection(scrollChild, "Roll Behavior", perCharDesc, -16)

local cbEnabled = makeCheckbox(scrollChild, "enabled",
    "Enabled",
    "Master toggle. When off, the addon does nothing and you click manually.",
    sec1, 0, -8)

local cbTest = makeCheckbox(scrollChild, "testMode",
    "Preview only — do not actually roll",
    "When on, the addon prints the action it WOULD have taken (prefixed 'WOULD '), but never calls the real Need/Greed buttons. Use this to validate behavior in a real dungeon before going live.",
    cbEnabled, 0, -4)
local cbTestDesc = makeDescription(scrollChild,
    "Decisions print to chat as 'WOULD GREED [item] — reason'. Nothing is actually rolled.",
    cbTest, -2, 480)

-- ---- Section: Upgrades ----------------------------------------------------
local sec2 = makeSection(scrollChild, "Upgrades", cbTestDesc, -20)

-- ilvl upgrade: toggle + slider with explanation
local cbReqILvl = makeCheckbox(scrollChild, "requireILvlUpgrade",
    "Need only on item-level upgrades",
    "When on, Need rolls require the incoming item to have higher ilvl than your equipped item in that slot. When off, Need on any stat-matching item regardless of ilvl.",
    sec2, 0, -8)
cbReqILvl.onChange = function(on)
    if widgets.needILvlMargin and widgets.needILvlMargin.enable then
        widgets.needILvlMargin.enable(on)
    end
end

local sliderMargin = makeSlider(scrollChild, "needILvlMargin",
    "Required ilvl margin",
    0, 20, 1,
    "Need only if the incoming item is at least this many ilvls higher than equipped. 0 means any upgrade.",
    cbReqILvl, 16, -28,
    function(v)
        if v == 0 then return "Required ilvl margin: 0 (any upgrade is enough)" end
        return ("Required ilvl margin: %d (incoming must be %d+ ilvl higher)"):format(v, v)
    end)

-- ---- Section: Off-Spec ----------------------------------------------------
local secOff = makeSection(scrollChild, "Off-Spec Support", sliderMargin, -28, -16)

local offspecDesc = makeDescription(scrollChild,
    "If you regularly play a second spec, StellarLoot can Need items that match its primary stat. " ..
    "|cffffd200Heads up:|r off-spec rolls compare against an in-game Equipment Manager set, " ..
    "|cffffffffnot|r your currently-equipped gear. Save your off-spec gear as a set in " ..
    "Character → Equipment Manager first; without one, off-spec items fall through to Greed.",
    secOff, -4, 540)

local function offspec()
    local cfg = Config:Get()
    cfg.offspec = cfg.offspec or {}
    return cfg.offspec
end

-- Off-spec source dropdown
local sourceChoices = {
    { label = "Disabled",    value = "off"    },
    { label = "Auto-detect", value = "auto"   },
    { label = "Manual",      value = "manual" },
}
local ddOffSource = CreateFrame("Frame", "StellarLootOpt_offspecSource", scrollChild, "UIDropDownMenuTemplate")
ddOffSource:SetPoint("TOPLEFT", offspecDesc, "BOTTOMLEFT", 0, -16)
local ddOffSourceLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
ddOffSourceLabel:SetPoint("BOTTOMLEFT", ddOffSource, "TOPLEFT", 20, 2)
ddOffSourceLabel:SetText("Off-spec source")
UIDropDownMenu_SetWidth(ddOffSource, 160)

local statChoices = {
    { label = "(unset)",   value = false },
    { label = "Strength",  value = Data.STAT_STRENGTH },
    { label = "Agility",   value = Data.STAT_AGILITY },
    { label = "Intellect", value = Data.STAT_INTELLECT },
}
local ddOffStat = CreateFrame("Frame", "StellarLootOpt_offspecStat", scrollChild, "UIDropDownMenuTemplate")
ddOffStat:SetPoint("TOPLEFT", ddOffSource, "BOTTOMLEFT", 0, -28)
local ddOffStatLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
ddOffStatLabel:SetPoint("BOTTOMLEFT", ddOffStat, "TOPLEFT", 20, 2)
ddOffStatLabel:SetText("Off-spec primary stat (manual)")
UIDropDownMenu_SetWidth(ddOffStat, 160)

local ddOffSet = CreateFrame("Frame", "StellarLootOpt_offspecSet", scrollChild, "UIDropDownMenuTemplate")
ddOffSet:SetPoint("TOPLEFT", ddOffStat, "BOTTOMLEFT", 0, -28)
local ddOffSetLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
ddOffSetLabel:SetPoint("BOTTOMLEFT", ddOffSet, "TOPLEFT", 20, 2)
ddOffSetLabel:SetText("Off-spec equipment set")
UIDropDownMenu_SetWidth(ddOffSet, 200)

local function refreshOffspecEnable()
    local source = offspec().source or "off"
    if UIDropDownMenu_EnableDropDown and UIDropDownMenu_DisableDropDown then
        if source == "manual" then UIDropDownMenu_EnableDropDown(ddOffStat)
        else                       UIDropDownMenu_DisableDropDown(ddOffStat) end
        if source ~= "off" then    UIDropDownMenu_EnableDropDown(ddOffSet)
        else                       UIDropDownMenu_DisableDropDown(ddOffSet) end
    end
end

UIDropDownMenu_Initialize(ddOffSource, function(_, level)
    for _, c in ipairs(sourceChoices) do
        local info = UIDropDownMenu_CreateInfo()
        info.text, info.value = c.label, c.value
        info.func = function()
            offspec().source = c.value
            UIDropDownMenu_SetSelectedValue(ddOffSource, c.value)
            UIDropDownMenu_SetText(ddOffSource, c.label)
            refreshOffspecEnable()
            if StellarLoot.PlayerState then StellarLoot.PlayerState:RefreshOffSpec() end
        end
        UIDropDownMenu_AddButton(info, level)
    end
end)
widgets.__offspec_source = {
    type = "dropdown", widget = ddOffSource,
    get = function() return offspec().source or "off" end,
    set = function(v)
        UIDropDownMenu_SetSelectedValue(ddOffSource, v)
        for _, c in ipairs(sourceChoices) do
            if c.value == v then UIDropDownMenu_SetText(ddOffSource, c.label) break end
        end
    end,
}

UIDropDownMenu_Initialize(ddOffStat, function(_, level)
    for _, c in ipairs(statChoices) do
        local info = UIDropDownMenu_CreateInfo()
        info.text, info.value = c.label, c.value
        info.func = function()
            offspec().primaryStat = (c.value == false) and nil or c.value
            UIDropDownMenu_SetSelectedValue(ddOffStat, c.value)
            UIDropDownMenu_SetText(ddOffStat, c.label)
            if StellarLoot.PlayerState then StellarLoot.PlayerState:RefreshOffSpec() end
        end
        UIDropDownMenu_AddButton(info, level)
    end
end)
widgets.__offspec_stat = {
    type = "dropdown", widget = ddOffStat,
    get = function() return offspec().primaryStat end,
    set = function(v)
        local target = (v == nil) and false or v
        UIDropDownMenu_SetSelectedValue(ddOffStat, target)
        for _, c in ipairs(statChoices) do
            if c.value == target then UIDropDownMenu_SetText(ddOffStat, c.label) break end
        end
    end,
}

local function buildSetChoices()
    local choices = { { label = "(none)", value = false } }
    if StellarLoot.PlayerState and StellarLoot.PlayerState.GetEquipmentSetNames then
        for _, name in ipairs(StellarLoot.PlayerState:GetEquipmentSetNames()) do
            table.insert(choices, { label = name, value = name })
        end
    end
    return choices
end

local function initSetDropdown()
    UIDropDownMenu_Initialize(ddOffSet, function(_, level)
        for _, c in ipairs(buildSetChoices()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.value = c.label, c.value
            info.func = function()
                offspec().equipmentSet = (c.value == false) and nil or c.value
                UIDropDownMenu_SetSelectedValue(ddOffSet, c.value)
                UIDropDownMenu_SetText(ddOffSet, c.label)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
end
initSetDropdown()
function ConfigUI:RefreshOffspecSets() initSetDropdown() end

widgets.__offspec_set = {
    type = "dropdown", widget = ddOffSet,
    get = function() return offspec().equipmentSet end,
    set = function(v)
        local target = (v == nil) and false or v
        UIDropDownMenu_SetSelectedValue(ddOffSet, target)
        UIDropDownMenu_SetText(ddOffSet, v or "(none)")
    end,
}

-- ---- Section: Fallback ----------------------------------------------------
local sec3 = makeSection(scrollChild, "Fallback Action", ddOffSet, -28, -16)
local fallbackDesc = makeDescription(scrollChild,
    "What to do when item info doesn't load before the roll timer is about to expire.",
    sec3, -4, 540)

local ddFallback = makeDropdown(scrollChild, "fallbackAction",
    "Fallback",
    {
        { label = "Greed",                  value = "GREED" },
        { label = "Pass",                   value = "PASS" },
        { label = "Need",                   value = "NEED" },
        { label = "Manual (do nothing)",    value = "MANUAL" },
    },
    fallbackDesc, 0, -4)

-- ---- Section: Per-item Overrides ------------------------------------------
local sec5 = makeSection(scrollChild, "Per-item Overrides", ddFallback, -36)

local hint = makeDescription(scrollChild,
    "One per line, format: |cffffff00itemID:ACTION|r where ACTION is NEED, GREED, or PASS. " ..
    "Lines starting with # are comments. Use |cffffff00/stellarloot override <id> <action>|r as a quick alternative.",
    sec5, -4, 540)

local oScroll = CreateFrame("ScrollFrame", "StellarLootOpt_overridesScroll", scrollChild, "UIPanelScrollFrameTemplate")
oScroll:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -8)
oScroll:SetSize(540, 110)
local edit = CreateFrame("EditBox", "StellarLootOpt_overridesEdit", oScroll)
edit:SetMultiLine(true)
edit:SetAutoFocus(false)
edit:SetFontObject(ChatFontNormal)
edit:SetSize(520, 110)
edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
oScroll:SetScrollChild(edit)

local function serializeOverrides()
    local lines = {}
    local cfg = Config:Get()
    for itemID, action in pairs(cfg.overrides or {}) do
        table.insert(lines, ("%d:%s"):format(itemID, action))
    end
    table.sort(lines)
    return table.concat(lines, "\n")
end

local function parseOverrides(text)
    local result = {}
    for line in text:gmatch("[^\r\n]+") do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= "" and not trimmed:match("^#") then
            local id, action = trimmed:match("^(%d+)%s*[:=]%s*(%a+)$")
            if id and action then
                action = action:upper()
                if action == "NEED" or action == "GREED" or action == "PASS" then
                    result[tonumber(id)] = action
                end
            end
        end
    end
    return result
end

edit:SetScript("OnEditFocusLost", function(self)
    Config:Get().overrides = parseOverrides(self:GetText() or "")
end)

widgets["overrides"] = {
    type = "edit", widget = edit,
    get = function() return serializeOverrides() end,
    set = function() edit:SetText(serializeOverrides()) end,
}

-- Compute scrollChild height so the viewport matches content.
scrollChild:SetHeight(900)

-- ---- Panel callbacks -------------------------------------------------------

panel.refresh = function()
    for key, w in pairs(widgets) do
        if w.type == "checkbox" then
            w.widget:SetChecked(w.get() and true or false)
        elseif w.type == "slider" then
            w.widget:SetValue(w.get() or 0)
            -- Trigger formatter via OnValueChanged (already done by SetValue)
        elseif w.type == "dropdown" then
            w.set(w.get())
        elseif w.type == "edit" then
            w.set()
        end
    end
    -- Apply enable/disable for sliders that depend on toggles.
    if widgets.needILvlMargin and widgets.needILvlMargin.enable then
        widgets.needILvlMargin.enable(Config:Get().requireILvlUpgrade)
    end
    refreshOffspecEnable()
end

panel.okay = function()
    Config:Get().overrides = parseOverrides(edit:GetText() or "")
end

panel.cancel = function()
    panel.refresh()
end

panel.default = function()
    Config:ResetActive()
    panel.refresh()
end

-- Modern Settings canvas API does not auto-call panel.refresh on show, so
-- without this the widgets sit in default visual state and an Okay click
-- can wipe saved overrides by parsing an empty edit box.
panel:HookScript("OnShow", function() panel.refresh() end)

-- Register with whichever options system this client provides.
if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    panel.settingsCategory = category
elseif _G.InterfaceOptions_AddCategory then
    _G.InterfaceOptions_AddCategory(panel)
end

function ConfigUI:Open()
    if Settings and Settings.OpenToCategory and panel.settingsCategory then
        Settings.OpenToCategory(panel.settingsCategory:GetID() or panel.settingsCategory.ID)
    elseif _G.InterfaceOptionsFrame_OpenToCategory then
        _G.InterfaceOptionsFrame_OpenToCategory(panel)
        _G.InterfaceOptionsFrame_OpenToCategory(panel)
    else
        StellarLoot.Log:Warn("no options panel system detected on this client")
    end
end
