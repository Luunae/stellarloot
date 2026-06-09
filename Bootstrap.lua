-- StellarLoot/Bootstrap.lua
-- ADDON_LOADED + PLAYER_LOGIN startup. Loaded last so all modules are present.

local Config      = StellarLoot.Config
local PlayerState = StellarLoot.PlayerState
local Log         = StellarLoot.Log

local f = CreateFrame("Frame", "StellarLootBootstrapFrame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == StellarLoot.name then
        Config:Init()
    elseif event == "PLAYER_LOGIN" then
        -- Belt-and-suspenders: ensure DB is initialized even if ADDON_LOADED
        -- fired with an unexpected name (folder/TOC casing quirks).
        if not Config:Get() then Config:Init() end
        PlayerState:RefreshClass()
        PlayerState:RefreshSpec()
        PlayerState:RefreshOffSpec()
        PlayerState:RefreshAllSlots()
        Log:Info(("loaded — %s. /stellarloot for help."):format(
            PlayerState.specName and ("playing " .. PlayerState.specName) or "spec pending"))
    end
end)
