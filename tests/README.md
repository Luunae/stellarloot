# Stellar Loot test suite

Tests for the pure decision engine (`Decision.Evaluate`). The WoW API surface
it touches — `GetItemInfo` and `GetItemStats` — is stubbed from a fixture
corpus of real 5.5.4 item data, so the suite encodes what the game actually
serves rather than what we assume it serves.

## Running

```
./tests/run.sh
```

(or directly: `nix-shell -p lua5_1 --run "lua tests/run_tests.lua"`)

Lua 5.1 matters: it's the dialect the MoP client embeds. Exit code is nonzero
on any failure. Expected runtime: a few seconds, almost all of it the sweep.

## Layout

| file | role |
|---|---|
| `run_tests.lua` | runner: loads the addon modules under stubs, executes cases + sweep |
| `wow_stub.lua` | `GetItemInfo`/`GetItemStats` doubles backed by the fixture registry |
| `helpers.lua` | ctx/cfg/roll/link builders, `decisiveRule()`, the 34-spec table |
| `cases/decision_cases.lua` | curated table-driven cases (regression pins + step-chain coverage) |
| `sweep.lua` | exhaustive sweep: 34 specs × 2931 items × 2 passes vs the EJ oracle |
| `sweep_allowlist.lua` | accepted oracle divergences, each with a reason |
| `fixtures/corpus.lua` | **generated** — itemID → item record incl. EJ filter sets |
| `tools/gen_fixtures.lua` | regenerates the fixture file from an EJGearAudit dump |

## The two layers

**Curated cases** assert an exact action *and* the decisive rule tag from the
trace — a right answer for the wrong reason fails. Each shipped bug gets a
pin here so it can't regress silently.

**The corpus sweep** evaluates every class-spec against every Encounter
Journal item, using Blizzard's own loot-filter mapping (`filterSpecs`) as the
oracle, in two passes:

- **Pass A** (nothing equipped): an EJ-listed spec must Need the item.
  One-directional — SL is intentionally grabbier than the EJ filter, so
  extra Needs on unlisted specs are fine; a listed spec failing to Need is
  the bug class this catches.
- **Pass B** (everything equipped at ilvl 999): an EJ-listed spec must settle
  to Greed, and *no* spec may Need *anything*.

Both passes also assert Evaluate never errors and always reaches a verdict.
The oracle applies to armor, weapons, and known tier tokens; non-gear EJ
entries (mounts, quest items) get only the error/verdict properties.

Caveat: `Data.TrinketSpecs` is generated from the same corpus, so the trinket
slice validates plumbing rather than judgment. Armor, weapons, and tokens are
independent of the oracle.

## Adding a case

Append to `cases/decision_cases.lua`. A case names an `item` (fixture itemID,
or a `synthetic` record for shapes the corpus doesn't carry), overrides for
`ctx`/`cfg`/`roll`, and an `expect` of `{ action, rule }`. Defaults: Ret
paladin, all slots ilvl 480, shipped config defaults — note
`requireILvlUpgrade` defaults to **false**, so ilvl-comparison cases must set
it true or they'll pass via `STAT_MATCH_ANY_ILVL`.

## Triaging a sweep violation

A new violation means either an engine bug (fix it, then add a curated pin)
or a legitimate divergence from the EJ filter (add it to
`sweep_allowlist.lua` with a reason). Stale allowlist entries — listed pairs
that no longer violate — fail the run until removed.

## Regenerating fixtures

When the ej-gear-audit corpus updates:

```
nix-shell -p lua5_1 --run \
  "lua tests/tools/gen_fixtures.lua ../ej-gear-audit/dumps/<dump>.lua" \
  > tests/fixtures/corpus.lua
```

Output is sorted and deterministic; the diff against the committed file shows
exactly what the new dump changed. The sibling repo is only needed at
regeneration time — committed fixtures keep the suite self-contained.

Possible extension: the dump's `scanned` table carries ~5900 forged-variant
records (separate itemIDs the EJ never lists) that could join the sweep via
the same name-join `gen_trinket_specs.lua` uses.
