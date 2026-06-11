-- tests/sweep.lua — exhaustive corpus sweep: every MoP class-spec × every
-- corpus item, two passes, with the Encounter Journal loot filter as oracle.
-- Receives (H, Stub, allowlist) as chunk varargs — see run_tests.lua.
-- Returns a report table.
--
-- Pass A (equipped ilvl 0 everywhere — everything is an upgrade):
--   spec ∈ item.filterSpecs ⇒ NEED. One-directional: SL is intentionally
--   grabbier than the EJ filter (it greeds rather than passes off-type
--   items), so extra Needs on non-listed specs are not violations. An
--   EJ-listed spec FAILING to Need is — the 0.7.1 cloak bug was this shape.
-- Pass B (equipped ilvl 999 everywhere — nothing is an upgrade):
--   spec ∈ item.filterSpecs ⇒ GREED (stat match without ilvl gain settles
--   to Greed, never Need), and for ALL pairs: action ≠ NEED.
-- Both passes: Evaluate must not error and must reach a verdict (non-nil).
--
-- The oracle applies only to armor, weapons, and known tier tokens — the EJ
-- also lists non-gear (mounts, quest drops) that the engine rightly defaults
-- to Greed on. Trinket caveat: Data.TrinketSpecs is generated from this same
-- corpus, so the trinket slice validates plumbing rather than judgment.
--
-- Known divergences live in tests/sweep_allowlist.lua, keyed
-- "<pass>:<specID>:<itemID>", each with a reason. Stale entries (no longer
-- violating) are reported so the allowlist can't rot.

local H, Stub, allowlist = ...
local Decision = StellarLoot.Decision
local Data = StellarLoot.Data

local allowed = {}
for _, entry in ipairs(allowlist) do
    allowed[("%s:%d:%d"):format(entry.pass, entry.specID, entry.itemID)] = entry
end

local report = {
    evaluations = 0, oraclePairs = 0,
    violations = 0, allowed = 0, stale = {},
}
local usedAllow = {}
local failures = {}   -- grouped: key → { detail, specIDs = {...} }
local order = {}

local function violate(pass, spec, id, rec, text, trace)
    local key = ("%s:%d:%d"):format(pass, spec.specID, id)
    if allowed[key] then
        usedAllow[key] = true
        report.allowed = report.allowed + 1
        return
    end
    report.violations = report.violations + 1
    -- Group identical failures across specs so one bad item prints once.
    local groupKey = ("%s %d %s"):format(pass, id, text)
    local group = failures[groupKey]
    if not group then
        group = { pass = pass, id = id, name = rec.name, text = text,
                  trace = trace, specIDs = {} }
        failures[groupKey] = group
        order[#order + 1] = groupKey
    end
    group.specIDs[#group.specIDs + 1] = spec.specID
end

local ids = {}
for id in pairs(Stub.fixtures) do ids[#ids + 1] = id end
table.sort(ids)

local roll = H.roll()
local started = os.clock()

for _, pass in ipairs({ { tag = "A", equippedAll = 0 }, { tag = "B", equippedAll = 999 } }) do
    for _, spec in ipairs(H.SPECS) do
        local ctx = H.ctx({ spec = spec.specID, equippedAll = pass.equippedAll })
        ctx.config = H.cfg({ requireILvlUpgrade = true })
        for _, id in ipairs(ids) do
            local rec = Stub.fixtures[id]
            local link = H.link(id, rec.name)
            local ok, action, trace = pcall(Decision.Evaluate, link, roll, ctx)
            report.evaluations = report.evaluations + 1

            if not ok then
                violate(pass.tag, spec, id, rec, "errored: " .. tostring(action), nil)
            elseif action == nil then
                violate(pass.tag, spec, id, rec, "no verdict (nil action)", trace)
            else
                local oracle = rec.filterSpecs and rec.filterSpecs[spec.specID]
                    and (rec.classID == 2 or rec.classID == 4 or Data.TierTokens[id])
                if oracle then report.oraclePairs = report.oraclePairs + 1 end
                if pass.tag == "A" then
                    if oracle and action ~= "NEED" then
                        violate("A", spec, id, rec,
                            ("EJ-listed but not Needed: got %s/%s"):format(
                                action, tostring(H.decisiveRule(trace))), trace)
                    end
                else
                    if action == "NEED" then
                        violate("B", spec, id, rec,
                            "Needed with nothing an upgrade", trace)
                    elseif oracle and action ~= "GREED" then
                        violate("B", spec, id, rec,
                            ("EJ-listed non-upgrade should Greed: got %s/%s"):format(
                                action, tostring(H.decisiveRule(trace))), trace)
                    end
                end
            end
        end
    end
end

report.seconds = os.clock() - started

for key in pairs(allowed) do
    if not usedAllow[key] then
        report.stale[#report.stale + 1] = key
    end
end
table.sort(report.stale)

local MAX_TRACES = 5
for i, groupKey in ipairs(order) do
    local g = failures[groupKey]
    table.sort(g.specIDs)
    local specs = {}
    for _, s in ipairs(g.specIDs) do specs[#specs + 1] = tostring(s) end
    print(("VIOLATION [pass %s] %d %s — %s (specs: %s)"):format(
        g.pass, g.id, g.name, g.text, table.concat(specs, ",")))
    if i <= MAX_TRACES and g.trace then
        print(Decision.FormatTrace(g.trace))
    end
end
if #order > MAX_TRACES then
    print(("(... traces shown for first %d violation groups only)"):format(MAX_TRACES))
end

return report
