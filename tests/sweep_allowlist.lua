-- tests/sweep_allowlist.lua — known, intentional divergences between the
-- decision engine and the Encounter Journal loot-filter oracle. Every entry
-- needs a reason. The sweep reports entries that no longer violate as stale;
-- remove them when that happens.
--
-- Entry shape: { pass = "A"|"B", specID = <number>, itemID = <number>,
--                reason = "<why this divergence is correct or accepted>" }

return {
}
