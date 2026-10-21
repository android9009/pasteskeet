-- Expected: low local budget fails, a bounded retry succeeds, script stays enabled.
local function work()
    local result = 0
    for i = 1, 10000 do result = result + i end
    return result, nil, "complete", nil
end
local ok, err, info = api.protect(work, {instructions = 1000})
assert(not ok and err == api.error_codes.budget_exceeded and info.retryable)
local left = api.budget()
assert(left.instructions_remaining > 200000 and left.native_work_remaining > 64)
local result, empty, marker, tail
ok, err, result, empty, marker, tail = api.protect(work, {instructions = 200000})
assert(ok and err == nil and result == 50005000 and empty == nil and marker == "complete" and tail == nil)
client.log("PASS: budget retry and nil results")
