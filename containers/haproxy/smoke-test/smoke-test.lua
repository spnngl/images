-- lua-json, and lua-lpeg (a C module) under it, as the deployments'
-- configs load them: require fails while parsing if either is missing.
local json = require("json")

core.register_fetches("smoke_test", function()
    return json.encode({ 1 })
end)
