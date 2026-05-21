-- StellarLoot/Events.lua
-- Wires loot-roll events to Decision.Evaluate, then to RollOnLoot.
-- Handles deferred decisions when GetItemInfo hasn't loaded.

local Data        = StellarLoot.Data
local Decision    = StellarLoot.Decision
local PlayerState = StellarLoot.PlayerState
local Config      = StellarLoot.Config
local Log         = StellarLoot.Log

local Events = {
    pendingRolls = {},     -- [rollID] = { itemLink = , scheduledAt = , safetyTimer = }
    pendingByItemID = {},  -- [itemID] = { [rollID] = true } awaiting GET_ITEM_INFO_RECEIVED
    confirmableRolls = {}, -- [rollID] = true for rolls the addon submitted; gates auto-confirm of the BoP popup
}
StellarLoot.Events = Events

local frame = CreateFrame("Frame", "StellarLootEventFrame")

local function submitRoll(rollID, action)
    local cfg = Config:Get()
    local rollType = Data.ActionToRollType[action]
    if rollType == nil or cfg.testMode then return end
    -- Mark confirmable BEFORE RollOnLoot: CONFIRM_LOOT_ROLL can fire
    -- synchronously inside the call, and the handler skips if the flag
    -- isn't set yet. onCancelLootRoll clears any leaked flag.
    Events.confirmableRolls[rollID] = true
    RollOnLoot(rollID, rollType)
end

local function evaluateAndAct(rollID)
    local cfg = Config:Get()
    local itemLink = GetLootRollItemLink(rollID)
    if not itemLink then return end

    local _texture, name, _count, quality, bindOnPickUp, canNeed, canGreed = GetLootRollItemInfo(rollID)

    local rollInfo = {
        name = name,
        quality = quality,
        bindOnPickUp = bindOnPickUp,
        canNeed = canNeed,
        canGreed = canGreed,
    }

    local ctx = PlayerState:Snapshot()
    ctx.config = cfg

    local action, trace = Decision.Evaluate(itemLink, rollInfo, ctx)

    if action == "DEFER" then
        -- Queue this rollID against the itemID; re-evaluate when info arrives.
        local itemID = trace.itemID
        if itemID then
            Events.pendingByItemID[itemID] = Events.pendingByItemID[itemID] or {}
            Events.pendingByItemID[itemID][rollID] = true
        end
        -- Also set a safety timer so we don't sit on the roll forever.
        local timeLeftMs = GetLootRollTimeLeft(rollID) or 0
        local safetyAt = math.max(0.5, (timeLeftMs - 1500) / 1000)
        C_Timer.After(safetyAt, function()
            if not Events.pendingRolls[rollID] then
                local fallback = cfg.fallbackAction or "GREED"
                if fallback == "MANUAL" then
                    Log:Warn(("item info never loaded for rollID %d — leaving for manual click"):format(rollID))
                    Events.pendingRolls[rollID] = { action = "MANUAL", itemLink = itemLink }
                else
                    Log:Warn(("item info never loaded for rollID %d — falling back to %s"):format(
                        rollID, fallback))
                    Events.pendingRolls[rollID] = { action = fallback, itemLink = itemLink }
                    submitRoll(rollID, fallback)
                end
            end
        end)
        return
    end

    Log:Render(trace, cfg)

    -- Action == nil (master toggle off) and "MANUAL" both mean "do not call
    -- RollOnLoot" — leave the dialog for the player. pendingRolls is the
    -- "we have decided" marker the DEFER safety timer reads to skip fallback.
    Events.pendingRolls[rollID] = { action = action, itemLink = itemLink }
    if action and action ~= "MANUAL" then
        submitRoll(rollID, action)
    end
end

local function onStartLootRoll(rollID, _rollTime, _lootHandle)
    evaluateAndAct(rollID)
end

local function onCancelLootRoll(rollID)
    Events.pendingRolls[rollID] = nil
    Events.confirmableRolls[rollID] = nil
    -- Also clean up pendingByItemID entries
    for itemID, rolls in pairs(Events.pendingByItemID) do
        rolls[rollID] = nil
        if not next(rolls) then Events.pendingByItemID[itemID] = nil end
    end
end

local function onConfirmLootRoll(rollID, rollType)
    -- Only auto-confirm the BoP popup for rolls this addon submitted; leave
    -- unrelated bind confirmations (e.g. picking up items not rolled on) alone.
    if Events.confirmableRolls[rollID] then
        ConfirmLootRoll(rollID, rollType)
        Events.confirmableRolls[rollID] = nil
    end
end

local function onItemInfoReceived(itemID, success)
    -- An equipped-slot snapshot may have read ilvl 0 at login because this
    -- item wasn't cached yet; now that it's loaded, re-read that slot. Done
    -- regardless of whether a roll is pending on this itemID.
    if success then
        PlayerState:ResolvePendingSlot(itemID)
    end

    local waiting = Events.pendingByItemID[itemID]
    if not waiting then return end
    Events.pendingByItemID[itemID] = nil
    if not success then
        -- Item doesn't exist; let the safety timer handle fallback.
        return
    end
    for rollID in pairs(waiting) do
        if not Events.pendingRolls[rollID] then
            evaluateAndAct(rollID)
        end
    end
end

frame:RegisterEvent("START_LOOT_ROLL")
frame:RegisterEvent("CANCEL_LOOT_ROLL")
frame:RegisterEvent("CONFIRM_LOOT_ROLL")
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("EQUIPMENT_SETS_CHANGED")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("SKILL_LINES_CHANGED")

frame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
    if event == "START_LOOT_ROLL" then
        onStartLootRoll(arg1, arg2, arg3)
    elseif event == "CANCEL_LOOT_ROLL" then
        onCancelLootRoll(arg1)
    elseif event == "CONFIRM_LOOT_ROLL" then
        onConfirmLootRoll(arg1, arg2)
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        onItemInfoReceived(arg1, arg2)
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        if arg1 == "player" or arg1 == nil then
            PlayerState:RefreshSpec()
            PlayerState:RefreshOffSpec()
        end
    elseif event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        PlayerState:RefreshSpec()
        PlayerState:RefreshOffSpec()
    elseif event == "EQUIPMENT_SETS_CHANGED" then
        -- Equipment set membership changed; nothing cached to invalidate (we
        -- read locations on demand), but refresh the UI dropdown if open.
        if StellarLoot.ConfigUI and StellarLoot.ConfigUI.RefreshOffspecSets then
            StellarLoot.ConfigUI:RefreshOffspecSets()
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        PlayerState:RefreshSlot(arg1)
    elseif event == "SKILL_LINES_CHANGED" then
        PlayerState:RefreshProfessions()
    end
end)

-- Allow the test harness / slash command to evaluate without firing a real roll.
function Events.EvaluateLink(itemLink, fakeRollInfo)
    local cfg = Config:Get()
    local ctx = PlayerState:Snapshot()
    ctx.config = cfg
    local rollInfo = fakeRollInfo or {
        canNeed = true, canGreed = true,
        quality = 4, bindOnPickUp = true,
    }
    return Decision.Evaluate(itemLink, rollInfo, ctx)
end
