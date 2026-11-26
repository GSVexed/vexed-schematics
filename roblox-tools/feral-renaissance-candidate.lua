-- FERAL Renaissance 16.1.1 candidate with Territory 0.8.0.
-- Automated regressions passed; live gameplay acceptance remains unverified.
-- Immutable source: cb5ebf20e3366639f76c5e807c43f925a167cae1
-- Bundle SHA-256: 0c11487d5c1f7af9cd6aff57023ecc45052907bc98c8008ebe1df1cbe904ebb3
local source=game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/cb5ebf20e3366639f76c5e807c43f925a167cae1/roblox-tools/feral-renaissance-v16.1.1.lua")
local fn,why=loadstring(source,"=FERAL_Renaissance_16_1_1_candidate")
assert(fn,why)
return fn()
