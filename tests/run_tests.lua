-- tests/run_tests.lua — load the addon's pure modules under stubbed WoW APIs,
-- run the curated decision cases, then the corpus sweep. Exits nonzero on any
-- failure. Lua 5.1.
--
-- Usage: nix-shell -p lua5_1 --run "lua tests/run_tests.lua"   (or ./tests/run.sh)

local script = arg and arg[0] or "tests/run_tests.lua"
local TESTS = script:match("^(.*)[/\\][^/\\]+$") or "."
local ROOT = TESTS .. "/.."

local Stub = dofile(TESTS .. "/wow_stub.lua")
Stub.install()

local okFixtures, fixtures = pcall(dofile, TESTS .. "/fixtures/corpus.lua")
if okFixtures and type(fixtures) == "table" then
    Stub.fixtures = fixtures
else
    print("WARN: tests/fixtures/corpus.lua not loadable — fixture-backed cases and the sweep will fail")
end

-- .toc order, the subset Decision needs. Each chunk gets the addon varargs.
for _, f in ipairs({ "Core.lua", "Data.lua", "TrinketSpecs.lua", "Config.lua", "Decision.lua" }) do
    assert(loadfile(ROOT .. "/" .. f))("StellarLoot", {})
end

local H = dofile(TESTS .. "/helpers.lua")
local Decision = StellarLoot.Decision

local passed, failed = 0, 0

-- expect.action uses the string "nil" for the no-action (addon disabled) case,
-- since a nil table field is indistinguishable from an absent one.
local function show(v)
    return v == nil and "nil" or tostring(v)
end

local cases = assert(loadfile(TESTS .. "/cases/decision_cases.lua"))(H)
for _, case in ipairs(cases) do
    Stub.reset()
    if case.synthetic then
        for id, rec in pairs(case.synthetic) do Stub.add(id, rec) end
    end

    local cfg = H.cfg(case.cfg)
    local ctx = H.ctx(case.ctx)
    ctx.config = cfg
    local roll = H.roll(case.roll)
    local rec = Stub.get(case.item)
    local link = H.link(case.item, rec and rec.name)

    local ok, action, trace = pcall(Decision.Evaluate, link, roll, ctx)
    local wantAction = case.expect.action
    local gotAction = ok and show(action) or "ERROR"
    local gotRule = ok and show(H.decisiveRule(trace)) or "ERROR"

    if not ok then
        failed = failed + 1
        print(("FAIL %s: errored: %s"):format(case.name, tostring(action)))
    elseif gotAction ~= wantAction or gotRule ~= case.expect.rule then
        failed = failed + 1
        print(("FAIL %s: expected %s/%s, got %s/%s"):format(
            case.name, wantAction, case.expect.rule, gotAction, gotRule))
        if trace then print(Decision.FormatTrace(trace)) end
    else
        passed = passed + 1
        print(("PASS %s"):format(case.name))
    end
end

print(("cases: %d passed, %d failed"):format(passed, failed))

-- Corpus sweep
Stub.reset()
local allowlist = assert(loadfile(TESTS .. "/sweep_allowlist.lua"))()
local sweep = assert(loadfile(TESTS .. "/sweep.lua"))(H, Stub, allowlist)

print(("sweep: %d evaluations, %d oracle pairs, %d violations (%d allowlisted), %d stale allowlist entries — %.1fs"):format(
    sweep.evaluations, sweep.oraclePairs, sweep.violations + sweep.allowed,
    sweep.allowed, #sweep.stale, sweep.seconds))
local sweepFailed = sweep.violations > 0 or #sweep.stale > 0
if #sweep.stale > 0 then
    print("stale allowlist entries (no longer violating — remove them):")
    for _, key in ipairs(sweep.stale) do print("  " .. key) end
end

if failed > 0 or sweepFailed then
    os.exit(1)
end
print("OK")
os.exit(0)
