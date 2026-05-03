-- AutoRoll/ConfigUI.lua
-- Blizzard Interface Options panel using stock widget templates.
-- Wrapped in a ScrollFrame so the whole content is reachable on any
-- panel size.

local Config = AutoRoll.Config
local Data   = AutoRoll.Data

local ConfigUI = {}
AutoRoll.ConfigUI = ConfigUI

local panel = CreateFrame("Frame", "AutoRollOptionsPanel", InterfaceOptionsFramePanelContainer or UIParent)
panel.name = "AutoRoll"
panel:Hide()
ConfigUI.panel = panel

-- The scroll frame fills the panel; all content goes into scrollChild.
local scroll = CreateFrame("ScrollFrame", "AutoRollOptionsScroll", panel, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 8, -8)
scroll:SetPoint("BOTTOMRIGHT", -28, 8)

local scrollChild = CreateFrame("Frame", "AutoRollOptionsScrollChild", scroll)
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
    local cb = CreateFrame("CheckButton", "AutoRollOpt_" .. key, parent, "InterfaceOptionsCheckButtonTemplate")
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
    local slider = CreateFrame("Slider", "AutoRollOpt_" .. key, parent, "OptionsSliderTemplate")
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
    local dd = CreateFrame("Frame", "AutoRollOpt_" .. key, parent, "UIDropDownMenuTemplate")
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

local title = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("AutoRoll")

local subtitle = makeDescription(scrollChild,
    "Automatically rolls Need / Greed / Pass on group loot based on class, spec, and equipped gear.",
    title, -4)

-- Per-character override toggle (master scope switch)
local cbPerChar = CreateFrame("CheckButton", "AutoRollOpt_useCharOverrides", scrollChild, "InterfaceOptionsCheckButtonTemplate")
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

local cbGreedUnusable = makeCheckbox(scrollChild, "greedUnusable",
    "Greed items the class cannot equip",
    "When off, items your class cannot equip (e.g. Mage seeing Plate) are passed instead of greeded.",
    cbTestDesc, 0, -4)

local cbDE = makeCheckbox(scrollChild, "preferDEoverGreed",
    "Prefer Disenchant over Greed (when eligible)",
    "If you have sufficient Enchanting skill and the item is disenchantable, roll DE instead of Greed.",
    cbGreedUnusable, 0, -4)

-- ---- Section: Quality & Upgrades ------------------------------------------
local sec2 = makeSection(scrollChild, "Quality & Upgrades", cbDE, -20)

-- Quality filter: toggle + slider with quality NAMES
local cbQualityEnabled = makeCheckbox(scrollChild, "qualityFilterEnabled",
    "Filter by minimum item quality",
    "When on, items below the chosen quality are passed. When off, quality is not considered.",
    sec2, 0, -8)
cbQualityEnabled.onChange = function(on)
    if widgets.minQuality and widgets.minQuality.enable then
        widgets.minQuality.enable(on)
    end
end

local sliderQuality = makeSlider(scrollChild, "minQuality",
    "Minimum quality",
    0, 4, 1,
    "Items below this quality are passed. Slider values: 0=Poor, 1=Common, 2=Uncommon, 3=Rare, 4=Epic.",
    cbQualityEnabled, 16, -28,
    function(v) return ("Minimum quality: %s (%d)"):format(Data.QualityNames[v] or "?", v) end)
local qualityDesc = makeDescription(scrollChild,
    "Items below the selected quality are passed without rolling.",
    sliderQuality, -8, 480)

-- ilvl upgrade: toggle + slider with explanation
local cbReqILvl = makeCheckbox(scrollChild, "requireILvlUpgrade",
    "Need only on item-level upgrades",
    "When on, Need rolls require the incoming item to have higher ilvl than your equipped item in that slot. When off, Need on any stat-matching item regardless of ilvl.",
    qualityDesc, -16, -4)
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

-- ---- Section: Fallback ----------------------------------------------------
local sec3 = makeSection(scrollChild, "Fallback Action", sliderMargin, -28, -16)
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
    "One per line, format: |cffffff00itemID:ACTION|r where ACTION is NEED, GREED, PASS, or DE. " ..
    "Lines starting with # are comments. Use |cffffff00/autoroll override <id> <action>|r as a quick alternative.",
    sec5, -4, 540)

local oScroll = CreateFrame("ScrollFrame", "AutoRollOpt_overridesScroll", scrollChild, "UIPanelScrollFrameTemplate")
oScroll:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -8)
oScroll:SetSize(540, 110)
local edit = CreateFrame("EditBox", "AutoRollOpt_overridesEdit", oScroll)
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
                if action == "NEED" or action == "GREED" or action == "PASS" or action == "DE" then
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
scrollChild:SetHeight(720)

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
    if widgets.minQuality and widgets.minQuality.enable then
        widgets.minQuality.enable(Config:Get().qualityFilterEnabled)
    end
    if widgets.needILvlMargin and widgets.needILvlMargin.enable then
        widgets.needILvlMargin.enable(Config:Get().requireILvlUpgrade)
    end
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

-- Register with whichever options system this client provides.
if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    category.ID = panel.name
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
        AutoRoll.Log:Warn("no options panel system detected on this client")
    end
end
