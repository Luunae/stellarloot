-- AutoRoll/Bootstrap.lua
-- ADDON_LOADED + PLAYER_LOGIN startup. Loaded last so all modules are present.

local Config      = AutoRoll.Config
local PlayerState = AutoRoll.PlayerState
local Log         = AutoRoll.Log

local f = CreateFrame("Frame", "AutoRollBootstrapFrame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == AutoRoll.name then
        Config:Init()
    elseif event == "PLAYER_LOGIN" then
        -- Belt-and-suspenders: ensure DB is initialized even if ADDON_LOADED
        -- fired with an unexpected name (folder/TOC casing quirks).
        if not Config:Get() then Config:Init() end
        PlayerState:RefreshClass()
        PlayerState:RefreshSpec()
        PlayerState:RefreshProfessions()
        PlayerState:RefreshAllSlots()
        Log:Info(("loaded — %s. /autoroll for help."):format(
            PlayerState.specName and ("playing " .. PlayerState.specName) or "spec pending"))
    end
end)
