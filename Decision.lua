-- AutoRoll/Decision.lua
-- Pure decision logic. No side effects. Directly testable from /run.
--
-- Decision.Evaluate(itemLink, rollInfo, ctx) → action, trace
--   action: "PASS" | "GREED" | "NEED" | "DE" | "DEFER" | nil
--           nil = don't roll (master toggle off)
--           DEFER = item info not loaded yet; caller should retry later
--   trace: { itemID, itemLink, factors = {...}, action, decisive, reason }
--          Every check appended a factor. The decisive factor is the rule
--          that determined the action.

local Data = AutoRoll.Data
local Decision = {}
AutoRoll.Decision = Decision

local function qualityName(q)
    return Data.QualityNames[q] or tostring(q)
end

local function newTrace(itemID, itemLink)
    return {
        itemID = itemID,
        itemLink = itemLink,
        factors = {},
        action = nil,
        decisive = nil,
        reason = nil,
    }
end

-- Append a non-decisive factor (a check that passed, or informational data).
local function note(trace, text, data)
    table.insert(trace.factors, { text = text, data = data, decisive = false })
end

-- Append a decisive factor and finalize the trace.
local function decide(trace, action, text, data)
    table.insert(trace.factors, { text = text, data = data, decisive = true })
    trace.action = action
    trace.decisive = #trace.factors
    trace.reason = text
    return action, trace
end

-- Look up an item's effective ilvl, preferring the upgraded value.
local function effectiveILvl(link)
    local fn = _G.GetDetailedItemLevelInfo
    if fn then
        local ilvl = fn(link)
        if ilvl and ilvl > 0 then return ilvl end
    end
    local _, _, _, baseILvl = GetItemInfo(link)
    return baseILvl or 0
end

local function armorTypeName(subclassID)
    local names = {
        [Data.ARMOR_GENERIC] = "Misc",
        [Data.ARMOR_CLOTH]   = "Cloth",
        [Data.ARMOR_LEATHER] = "Leather",
        [Data.ARMOR_MAIL]    = "Mail",
        [Data.ARMOR_PLATE]   = "Plate",
        [Data.ARMOR_SHIELD]  = "Shield",
    }
    return names[subclassID] or ("subclass " .. tostring(subclassID))
end

-- The big one. Ordered checks; first match wins.
function Decision.Evaluate(itemLink, rollInfo, ctx)
    local cfg = ctx.config
    local trace = newTrace(nil, itemLink)

    -- Resolve itemID from the link (works even if GetItemInfo hasn't cached).
    local itemID = tonumber(itemLink and itemLink:match("item:(%d+)"))
    trace.itemID = itemID

    -- Step 1: per-item override
    if itemID and cfg.overrides and cfg.overrides[itemID] then
        local action = cfg.overrides[itemID]
        return decide(trace, action,
            ("user override → %s"):format(action),
            { rule = "USER_OVERRIDE", itemID = itemID, action = action })
    end

    -- Step 2: master toggle
    if not cfg.enabled then
        return decide(trace, nil,
            "addon disabled — leaving roll for manual click",
            { rule = "DISABLED" })
    end
    note(trace, "addon enabled")

    -- Step 3: item info loaded?
    local name, link, quality, baseILvl, _, itemType, itemSubType,
          _, equipLoc, _, _, classID, subclassID = GetItemInfo(itemLink)
    if not name then
        return decide(trace, "DEFER",
            "item info not yet cached — will retry on GET_ITEM_INFO_RECEIVED",
            { rule = "ITEM_INFO_PENDING", itemID = itemID })
    end
    note(trace, ("item: %s (q%d, ilvl %d, %s/%s, equipLoc %s)"):format(
        name, quality or -1, baseILvl or 0,
        tostring(itemType), tostring(itemSubType), tostring(equipLoc)),
        { rule = "ITEM_INFO", classID = classID, subclassID = subclassID,
          equipLoc = equipLoc, baseILvl = baseILvl, quality = quality })

    -- Step 4: quality threshold (skipped if quality filter disabled)
    if cfg.qualityFilterEnabled then
        if (quality or 0) < cfg.minQuality then
            return decide(trace, "PASS",
                ("quality %s below threshold %s"):format(
                    qualityName(quality), qualityName(cfg.minQuality)),
                { rule = "QUALITY_BELOW_MIN", quality = quality, threshold = cfg.minQuality })
        end
        note(trace, ("quality %s ≥ threshold %s"):format(
            qualityName(quality), qualityName(cfg.minQuality)))
    else
        note(trace, "quality filter disabled — skipping quality check")
    end

    -- Step 5: any roll option available?
    if not rollInfo.canNeed and not rollInfo.canGreed and not rollInfo.canDisenchant then
        return decide(trace, "PASS",
            "no roll options available (Need/Greed/DE all disallowed)",
            { rule = "NO_ROLL_OPTIONS" })
    end
    note(trace, ("roll options: Need=%s Greed=%s DE=%s"):format(
        tostring(rollInfo.canNeed), tostring(rollInfo.canGreed), tostring(rollInfo.canDisenchant)))

    -- Step 6: can the class equip this at all?
    local isArmor  = (classID == Data.ITEM_CLASS_ARMOR)
    local isWeapon = (classID == Data.ITEM_CLASS_WEAPON)
    local classToken = ctx.classToken

    if isArmor then
        local proficient = Data.ClassArmor[classToken] and Data.ClassArmor[classToken][subclassID]
        if not proficient then
            local action = (cfg.greedUnusable and rollInfo.canGreed) and "GREED" or "PASS"
            return decide(trace, action,
                ("class %s cannot equip %s armor"):format(classToken, armorTypeName(subclassID)),
                { rule = "ARMOR_NOT_PROFICIENT", classToken = classToken,
                  subclassID = subclassID })
        end
        note(trace, ("class %s can equip %s armor"):format(classToken, armorTypeName(subclassID)))
    elseif isWeapon then
        local proficient = Data.ClassWeapons[classToken] and Data.ClassWeapons[classToken][subclassID]
        if not proficient then
            local action = (cfg.greedUnusable and rollInfo.canGreed) and "GREED" or "PASS"
            return decide(trace, action,
                ("class %s cannot equip weapon subclass %s"):format(classToken, tostring(itemSubType)),
                { rule = "WEAPON_NOT_PROFICIENT", classToken = classToken,
                  subclassID = subclassID })
        end
        note(trace, ("class %s can equip %s"):format(classToken, tostring(itemSubType)))
    end

    -- Step 7: wrong armor type for class (Paladin sees Cloth)
    if isArmor then
        local preferred = Data.ClassPreferredArmor[classToken]
        -- Generic (cloaks) and shields are always equippable; exempt from "preferred".
        local isFlexible = (subclassID == Data.ARMOR_GENERIC or subclassID == Data.ARMOR_SHIELD)
        if preferred and not isFlexible and subclassID ~= preferred then
            return decide(trace, "GREED",
                ("wrong armor type: %s (class prefers %s)"):format(
                    armorTypeName(subclassID), armorTypeName(preferred)),
                { rule = "WRONG_ARMOR_TYPE", got = subclassID, want = preferred })
        end
        if preferred and not isFlexible then
            note(trace, ("preferred armor type matches: %s"):format(armorTypeName(preferred)))
        end
    end

    -- Step 8: tier token / class-restricted item
    if itemID and Data.TierTokens[itemID] then
        local allowed = Data.TierTokens[itemID]
        if allowed[classToken] then
            note(trace, ("tier token redeemable by %s — eligible for Need"):format(classToken),
                { rule = "TIER_TOKEN_MATCH" })
            -- Skip stat check; jump to ilvl comparison below.
        else
            return decide(trace, rollInfo.canGreed and "GREED" or "PASS",
                ("tier token not for %s"):format(classToken),
                { rule = "TIER_TOKEN_MISMATCH", classToken = classToken, allowed = allowed })
        end
    end

    -- Step 9: primary stat match (only for items with stats — armor & weapons)
    local needsStatCheck = isArmor or isWeapon
    local skipStatCheck = (itemID and Data.TierTokens[itemID])  -- tier tokens already passed
    if needsStatCheck and not skipStatCheck then
        local statOverride = cfg.classOverrides and cfg.classOverrides.primaryStat
        local primaryStat = statOverride or ctx.primaryStat
        if not primaryStat then
            note(trace, "no primary stat detected — skipping stat check")
        else
            local statKey = Data.PrimaryStatKey[primaryStat]
            local statName = Data.PrimaryStatName[primaryStat] or "?"
            local stats = GetItemStats(itemLink) or {}
            local hasPrimary = statKey and (stats[statKey] or 0) > 0

            -- Spirit handling: healers accept Spirit-Int items even if INT is missing
            -- (rare). For non-healers, Spirit on an INT item is irrelevant.
            local hasSpirit = (stats["ITEM_MOD_SPIRIT_SHORT"] or 0) > 0

            -- Extra accepted stats from config
            local extraOK = false
            if cfg.classOverrides and cfg.classOverrides.extraStats then
                for _, key in ipairs(cfg.classOverrides.extraStats) do
                    if (stats["ITEM_MOD_" .. key .. "_SHORT"] or 0) > 0 then
                        extraOK = true
                        break
                    end
                end
            end

            if not hasPrimary and not extraOK then
                -- Healers tolerate items with Spirit + Int even if their primary is Int.
                -- The check above already requires Int for an int-spec, so this is mostly
                -- a no-op; here we only fall through if the item carries the right stat.
                return decide(trace, rollInfo.canGreed and "GREED" or "PASS",
                    ("missing primary stat %s"):format(statName),
                    { rule = "WRONG_PRIMARY_STAT", want = statName,
                      stats = stats })
            end
            note(trace, ("primary stat %s present"):format(statName))
            if ctx.isHealer and hasSpirit then
                note(trace, "Spirit present (healer spec — bonus)")
            end
        end
    end

    -- Step 10: ilvl comparison vs equipped
    -- Only Need-eligible if the item maps to a real equipment slot OR is a
    -- tier token. Non-equippable drops (recipes, mounts, BoP mats) fall
    -- through to the default action below.
    local isEquippable = equipLoc and Data.EquipLocToSlots[equipLoc] ~= nil
    local isKnownTierToken = itemID and Data.TierTokens[itemID] ~= nil
    if isEquippable then
        local incomingILvl = effectiveILvl(itemLink)
        local equippedILvl = ctx.worstEquippedILvl(equipLoc)

        if not cfg.requireILvlUpgrade then
            note(trace, ("ilvl check disabled — incoming %d vs equipped %d"):format(
                incomingILvl, equippedILvl))
            if rollInfo.canNeed then
                return decide(trace, "NEED",
                    "stat-matching item (ilvl upgrade not required)",
                    { rule = "STAT_MATCH_ANY_ILVL" })
            end
        else
            note(trace, ("ilvl: incoming %d vs equipped %d (margin %d)"):format(
                incomingILvl, equippedILvl, cfg.needILvlMargin),
                { rule = "ILVL", incoming = incomingILvl, equipped = equippedILvl })

            if rollInfo.canNeed and incomingILvl > equippedILvl + cfg.needILvlMargin then
                return decide(trace, "NEED",
                    ("upgrade: +%d ilvl over equipped"):format(incomingILvl - equippedILvl),
                    { rule = "UPGRADE", delta = incomingILvl - equippedILvl })
            end
        end
    elseif isKnownTierToken and rollInfo.canNeed then
        return decide(trace, "NEED",
            "tier token redeemable by class",
            { rule = "TIER_TOKEN_NEED" })
    else
        note(trace, "non-equippable item — skipping ilvl check",
            { rule = "NON_EQUIPPABLE", equipLoc = equipLoc })
    end

    -- Step 11: default — Greed (with DE preference if eligible) or Pass
    local action = "GREED"
    if not rollInfo.canGreed then
        action = "PASS"
    end

    -- DE upgrade: if we'd Greed, prefer DE when eligible
    if action == "GREED" and rollInfo.canDisenchant and cfg.preferDEoverGreed then
        local skill = ctx.enchantingSkill or 0
        local req = rollInfo.deSkillRequired or 0
        if skill >= req and skill > 0 then
            return decide(trace, "DE",
                ("DE preferred: enchanting skill %d ≥ required %d"):format(skill, req),
                { rule = "DE_PREFERRED", skill = skill, required = req })
        else
            note(trace, ("DE skipped: skill %d < required %d"):format(skill, req))
        end
    end

    return decide(trace, action,
        (action == "GREED")
            and "no upgrade and no disqualifier — default Greed"
            or  "no Greed available — default Pass",
        { rule = "DEFAULT", action = action })
end

-- Convenience: render a trace into a multi-line string for verbose logging.
function Decision.FormatTrace(trace)
    local lines = {}
    table.insert(lines, ("AutoRoll trace for %s [%s]:"):format(
        trace.itemLink or "?", tostring(trace.itemID)))
    for i, f in ipairs(trace.factors) do
        local marker = f.decisive and "→" or "·"
        table.insert(lines, ("  %s %s"):format(marker, f.text))
    end
    table.insert(lines, ("  = %s"):format(tostring(trace.action)))
    return table.concat(lines, "\n")
end
