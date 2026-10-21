-- Expected: exact budget code even though fn is short; script continues.
-- A larger inner deadline must not extend the enclosing deadline.
local ok, err, info = api.protect(function()
    api.protect(function() return 1 end, {instructions = 2000000, time_ms = 25})
end, {instructions = 2000000, time_ms = 0.000001})
assert(not ok and err == "budget_exceeded" and info.kind == "time")
assert(info.retryable and api.protect(function() return true end))
client.log("PASS: short-call deadline caught; no parent extension")
