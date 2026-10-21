-- Copy to %LOCALAPPDATA%/skeet/chat_spammer.lua and enable in the Lua menu.
-- Sends at most one message per interval; server flood limits still apply.
local enabled = ui.create("checkbox", "chat_spammer_enabled", "Chat spammer", false)
local message = ui.create("text", "chat_spammer_message", "Chat message", "Hello from Lua!")
local interval = ui.create("slider", "chat_spammer_interval", "Interval (seconds)", 5, 1, 30)
local team_only = ui.create("checkbox", "chat_spammer_team", "Team chat only", false)
local next_send = nil
local last_error = nil

events.on("paint", function()
    if not ui.get(enabled) then
        if next_send then console.clear_pending() end
        next_send, last_error = nil, nil
        return
    end
    local me = entity.local_player()
    if not me then
        next_send = nil
        console.clear_pending()
        return
    end
    local now = client.time()
    if not next_send then
        next_send = now + ui.get(interval)
        return
    end
    if now < next_send then return end
    next_send = now + ui.get(interval)

    -- Invalid user input is reported once and can be edited without disabling Lua.
    local called, error, accepted, reason = api.protect(function()
        return console.say(ui.get(message), ui.get(team_only))
    end)
    local problem = not called and error or (not accepted and reason or nil)
    if problem and problem ~= last_error then client.log_level("warning", problem) end
    last_error = problem
end)

events.on("shutdown", function()
    console.clear_pending()
end)
