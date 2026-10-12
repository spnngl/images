-- The Containerfile's smoke test: lua-json, and lua-lpeg under it, load
-- and work.
local json = require("json")
assert(json.encode({ 1 }) == "[1]")
