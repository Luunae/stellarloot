#!/usr/bin/env bash
# Run the Stellar Loot test suite under Lua 5.1 (the WoW client's Lua).
exec nix-shell -p lua5_1 --run "lua $(dirname "$0")/run_tests.lua"
