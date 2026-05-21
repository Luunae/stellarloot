-- StellarLoot/Decision.lua
-- Pure decision logic. No side effects. Directly testable from /run.
--
-- Decision.Evaluate(itemLink, rollInfo, ctx) → action, trace
--   action: "PASS" | "GREED" | "NEED" | "DEFER" | nil
--           nil = don't roll (master toggle off)
--           DEFER = item info not loaded yet; caller should retry later
--   trace: { itemID, itemLink, factors = {...}, action, decisive, reason }
--          Every check appended a factor. The decisive factor is the rule
--          that determined the action.

local Data = StellarLoot.Data
local Decision = {}
StellarLoot.Decision = Decision

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

-- Effective ilvl lives in Data.EffectiveILvl (shared with PlayerState so the
-- equipped-side and incoming-side both apply heirloom synthetic scaling).
local function effectiveILvl(link)
    local ilvl = Data.EffectiveILvl(link)
    return ilvl
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

    -- Step 4: any roll option available?
    if not rollInfo.canNeed and not rollInfo.canGreed then
        return decide(trace, "PASS",
            "no roll options available (Need and Greed both disallowed)",
            { rule = "NO_ROLL_OPTIONS" })
    end
    note(trace, ("roll options: Need=%s Greed=%s"):format(
        tostring(rollInfo.canNeed), tostring(rollInfo.canGreed)))

    -- Step 5: can the class equip this at all?
    local isArmor  = (classID == Data.ITEM_CLASS_ARMOR)
    local isWeapon = (classID == Data.ITEM_CLASS_WEAPON)
    local classToken = ctx.classToken

    if isArmor then
        local proficient = Data.ClassArmor[classToken] and Data.ClassArmor[classToken][subclassID]
        if not proficient then
            return decide(trace, rollInfo.canGreed and "GREED" or "PASS",
                ("class %s cannot equip %s armor"):format(classToken, armorTypeName(subclassID)),
                { rule = "ARMOR_NOT_PROFICIENT", classToken = classToken,
                  subclassID = subclassID })
        end
        note(trace, ("class %s can equip %s armor"):format(classToken, armorTypeName(subclassID)))
    elseif isWeapon then
        local proficient = Data.ClassWeapons[classToken] and Data.ClassWeapons[classToken][subclassID]
        if not proficient then
            return decide(trace, rollInfo.canGreed and "GREED" or "PASS",
                ("class %s cannot equip weapon subclass %s"):format(classToken, tostring(itemSubType)),
                { rule = "WEAPON_NOT_PROFICIENT", classToken = classToken,
                  subclassID = subclassID })
        end
        note(trace, ("class %s can equip %s"):format(classToken, tostring(itemSubType)))
    end

    -- Step 6: wrong armor type for class (Paladin sees Cloth)
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

    -- Step 7: tier token / class-restricted item.
    -- Token tooltips don't show the redeemed gear's ilvl in-game, so we
    -- surface it in the trace — it's the only way to tell LFR/Normal/Heroic
    -- variants apart at a glance. tokenEquipLoc, when set, redirects Step 9's
    -- ilvl comparison from the token's INVTYPE_NON_EQUIP_IGNORE to the slot
    -- the token redeems for ("WILDCARD" = Essence; compares vs worst tier slot).
    local tokenEquipLoc
    if itemID and Data.TierTokens[itemID] then
        local allowed = Data.TierTokens[itemID]
        local tokenILvl = effectiveILvl(itemLink)
        if allowed[classToken] then
            tokenEquipLoc = Data.TierTokenEquipLoc(name)
            local slotDesc = (tokenEquipLoc == "WILDCARD" and "any tier slot")
                          or tokenEquipLoc
                          or "unknown slot"
            note(trace, ("tier token (ilvl %d) redeemable by %s for %s — eligible for Need"):format(
                tokenILvl, classToken, slotDesc),
                { rule = "TIER_TOKEN_MATCH", ilvl = tokenILvl, equipLoc = tokenEquipLoc })
            -- Skip stat check; jump to ilvl comparison below.
        else
            return decide(trace, rollInfo.canGreed and "GREED" or "PASS",
                ("tier token (ilvl %d) not for %s"):format(tokenILvl, classToken),
                { rule = "TIER_TOKEN_MISMATCH", ilvl = tokenILvl,
                  classToken = classToken, allowed = allowed })
        end
    end

    -- Step 8: primary stat match — main spec or off-spec
    -- specBranch tracks which spec the item matches: "main" or "off". Tier
    -- tokens and stat-less items short-circuit to "main".
    local specBranch
    local needsStatCheck = isArmor or isWeapon
    local skipStatCheck = (itemID and Data.TierTokens[itemID])  -- tier tokens already passed
    if not needsStatCheck or skipStatCheck then
        specBranch = "main"
    else
        local statOverride = cfg.classOverrides and cfg.classOverrides.primaryStat
        local primaryStat = statOverride or ctx.primaryStat
        if not primaryStat then
            note(trace, "no primary stat detected — skipping stat check")
            specBranch = "main"
        else
            local statKey = Data.PrimaryStatKey[primaryStat]
            local statName = Data.PrimaryStatName[primaryStat] or "?"
            local stats = GetItemStats(itemLink) or {}
            local hasPrimary = statKey and (stats[statKey] or 0) > 0
            local hasSpirit = (stats["ITEM_MOD_SPIRIT_SHORT"] or 0) > 0

            -- Extra accepted stats from config (e.g. healer Spirit treated
            -- as a primary-equivalent for some specs).
            local extraOK = false
            if cfg.classOverrides and cfg.classOverrides.extraStats then
                for _, key in ipairs(cfg.classOverrides.extraStats) do
                    if (stats["ITEM_MOD_" .. key .. "_SHORT"] or 0) > 0 then
                        extraOK = true
                        break
                    end
                end
            end

            if hasPrimary or extraOK then
                specBranch = "main"
                note(trace, ("primary stat %s present (main spec)"):format(statName))
                if ctx.isHealer and hasSpirit then
                    note(trace, "Spirit present (healer spec — bonus)")
                end
            else
                -- Try off-spec match
                local offStat = ctx.offspecPrimaryStat
                if offStat and offStat ~= primaryStat then
                    local offKey = Data.PrimaryStatKey[offStat]
                    local offName = Data.PrimaryStatName[offStat] or "?"
                    if offKey and (stats[offKey] or 0) > 0 then
                        specBranch = "off"
                        note(trace, ("off-spec primary stat %s present"):format(offName),
                            { rule = "OFFSPEC_STAT_MATCH" })
                    end
                end
                if not specBranch then
                    return decide(trace, rollInfo.canGreed and "GREED" or "PASS",
                        ("missing primary stat %s"):format(statName),
                        { rule = "WRONG_PRIMARY_STAT", want = statName,
                          stats = stats })
                end
            end
        end
    end

    -- Step 9: ilvl comparison
    -- mainSpec branch: compare against currently-equipped (worst slot).
    -- offSpec branch:  compare against the configured equipment-manager set.
    -- Tier tokens reroute to their redeemed slot (or, for Essence wildcards,
    -- to the worst of the five tier slots). Non-equippable items fall through.
    local isEquippable = equipLoc and Data.EquipLocToSlots[equipLoc] ~= nil
    local isKnownTierToken = itemID and Data.TierTokens[itemID] ~= nil
    local isWildcardToken = (tokenEquipLoc == "WILDCARD")
    if isEquippable or tokenEquipLoc then
        if not cfg.requireILvlUpgrade then
            -- Stat-only mode: a stat-matching item is a Need outright, with no
            -- ilvl comparison or equipment-set requirement.
            note(trace, "ilvl check disabled — stat match is sufficient",
                { rule = "ILVL_DISABLED" })
            if rollInfo.canNeed then
                return decide(trace, "NEED",
                    "stat-matching item (ilvl upgrade not required)",
                    { rule = "STAT_MATCH_ANY_ILVL", branch = specBranch })
            end
        else
            local incomingILvl = effectiveILvl(itemLink)
            local compareILvl, compareLabel
            local compareHeirloom = false

            if isWildcardToken then
                local worst, worstHeirloom
                for _, loc in ipairs(Data.TierWildcardSlots) do
                    local v, h = ctx.worstEquippedILvl(loc)
                    if v and (not worst or v < worst) then
                        worst, worstHeirloom = v, h
                    end
                end
                compareILvl = worst or 0
                compareHeirloom = worstHeirloom or false
                compareLabel = "worst tier slot"
            elseif specBranch == "off" then
                local setName = cfg.offspec and cfg.offspec.equipmentSet
                if not setName or setName == "" then
                    return decide(trace, rollInfo.canGreed and "GREED" or "PASS",
                        "off-spec match but no equipment set configured — Greed",
                        { rule = "OFFSPEC_NO_SET" })
                end
                if ctx.worstSetILvl then
                    compareILvl, compareHeirloom = ctx.worstSetILvl(equipLoc, setName)
                end
                if not compareILvl then
                    return decide(trace, rollInfo.canGreed and "GREED" or "PASS",
                        ("off-spec set %q has no item in this slot — Greed"):format(setName),
                        { rule = "OFFSPEC_SET_SLOT_EMPTY", setName = setName })
                end
                compareLabel = ('set "%s"'):format(setName)
            else
                compareILvl, compareHeirloom = ctx.worstEquippedILvl(tokenEquipLoc or equipLoc)
                compareLabel = "equipped"
            end

            if compareHeirloom then
                note(trace, ("comparison slot holds a heirloom — using synthetic ilvl %d"):format(compareILvl),
                    { rule = "HEIRLOOM_IN_SLOT", compareILvl = compareILvl })
            end

            local extraMargin = compareHeirloom and (cfg.heirloomNeedMarginExtra or 0) or 0
            local effectiveMargin = cfg.needILvlMargin + extraMargin
            local marginDesc = (extraMargin > 0)
                and ("%d + %d heirloom"):format(cfg.needILvlMargin, extraMargin)
                or  tostring(cfg.needILvlMargin)
            note(trace, ("ilvl: incoming %d vs %s %d (margin %s)"):format(
                incomingILvl, compareLabel, compareILvl, marginDesc),
                { rule = "ILVL", incoming = incomingILvl, compare = compareILvl,
                  branch = specBranch, heirloom = compareHeirloom,
                  margin = effectiveMargin })

            if rollInfo.canNeed and incomingILvl > compareILvl + effectiveMargin then
                local suffix = (specBranch == "off") and " (off-spec)" or ""
                return decide(trace, "NEED",
                    ("upgrade: +%d ilvl over %s%s"):format(
                        incomingILvl - compareILvl, compareLabel, suffix),
                    { rule = "UPGRADE", delta = incomingILvl - compareILvl,
                      branch = specBranch })
            end
        end
    elseif isKnownTierToken and rollInfo.canNeed then
        -- Defensive fallback: a tier token whose name doesn't match any known
        -- slot pattern. Shouldn't happen with current data, but if a future
        -- tier ships a new naming convention we'd rather Need than silently
        -- miss it — the user can override per-item if needed.
        local tokenILvl = effectiveILvl(itemLink)
        return decide(trace, "NEED",
            ("tier token (ilvl %d) redeemable by class — slot unknown, defaulting to Need"):format(tokenILvl),
            { rule = "TIER_TOKEN_NEED_FALLBACK", ilvl = tokenILvl })
    else
        note(trace, "non-equippable item — skipping ilvl check",
            { rule = "NON_EQUIPPABLE", equipLoc = equipLoc })
    end

    -- Step 10: default — Greed or Pass
    local action = rollInfo.canGreed and "GREED" or "PASS"
    return decide(trace, action,
        (action == "GREED")
            and "no upgrade and no disqualifier — default Greed"
            or  "no Greed available — default Pass",
        { rule = "DEFAULT", action = action })
end

-- Convenience: render a trace into a multi-line string for verbose logging.
function Decision.FormatTrace(trace)
    local lines = {}
    table.insert(lines, ("StellarLoot trace for %s [%s]:"):format(
        trace.itemLink or "?", tostring(trace.itemID)))
    for i, f in ipairs(trace.factors) do
        local marker = f.decisive and "→" or "·"
        table.insert(lines, ("  %s %s"):format(marker, f.text))
    end
    table.insert(lines, ("  = %s"):format(tostring(trace.action)))
    return table.concat(lines, "\n")
end
