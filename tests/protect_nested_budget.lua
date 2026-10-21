-- Expected: inner budget is caught, then outer work continues successfully.
local outer_ok, outer_err = api.protect(function()
    local ok, err, info = api.protect(function()
        while true do end
    end, {instructions = 1000, time_ms = 25})
    assert(not ok and err == "budget_exceeded" and info.scope == "protect")
    assert(info.retryable and not api.budget().recovering)
end, {instructions = 2000000, time_ms = 25})
assert(outer_ok, outer_err)
client.log("PASS: nested budget caught; parent restored")
