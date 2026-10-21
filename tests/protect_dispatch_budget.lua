-- Manual test: one potentially slow paint, then verify the next paint still runs.
local tested, finished = false, false
events.on("paint", function()
    if tested then
        if not finished then finished = true; client.log("PASS: next dispatch has fresh budget") end
        return
    end
    tested = true
    local ok, err, info = api.protect(function()
        while true do end
    end, {instructions = 20000000, time_ms = 250})
    assert(not ok and err == "budget_exceeded" and info.scope == "dispatch" and not info.retryable)
    assert(api.budget().recovering)
    local ran = false
    ok, err = api.protect(function() ran = true end)
    assert(not ok and err == "budget_exceeded" and not ran)
    -- Return promptly: the recovery allowance is finite and never replenished.
end)
