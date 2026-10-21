-- Put hitsound.wav and/or hitsound.mp3 in %LOCALAPPDATA%/skeet/sounds.
-- Both hit and kill use the same local file. A kill takes priority over its hit.
local hit_enabled = ui.create("checkbox", "hitsound_enabled", "Hitsound", false)
local kill_enabled = ui.create("checkbox", "killsound_enabled", "Killsound", false)
local volume = ui.create("slider", "hitkill_volume", "Sound volume", 70, 0, 100)
local format = ui.create("combo", "hitkill_format", "Sound format", 1, {"Auto (WAV first)", "WAV", "MP3"})

-- Prepare at activation, never open/decode a file in a hit/kill callback.
local wav_ok, wav_error = audio.preload("sounds/hitsound.wav")
local mp3_ok, mp3_error = audio.preload("sounds/hitsound.mp3")
local pending_hit_at = nil
local warned_missing = false

local function play()
    local choice = ui.get(format)
    local use_wav = choice == 2 or (choice == 1 and wav_ok)
    local ready = use_wav and wav_ok or (not use_wav and mp3_ok)
    local sound = use_wav and "sounds/hitsound.wav" or "sounds/hitsound.mp3"
    local reason = use_wav and wav_error or mp3_error
    local ok = false
    if ready then
        audio.volume(ui.get(volume))
        ok, reason = audio.play(sound, false)
    end
    if ok then
        warned_missing = false
    elseif not warned_missing then
        client.log("Hit/kill sound: " .. (reason or ("cannot play " .. sound)))
        warned_missing = true
    end
end

events.on("game_event", function(event)
    if event.attacker ~= 0 or event.userid == nil or event.userid == 0 then return end
    if event.name == "player_death" then
        pending_hit_at = nil
        if ui.get(kill_enabled) then play() end
    elseif event.name == "player_hurt" and ui.get(hit_enabled) then
        -- Wait briefly: a lethal hit also produces player_death.
        pending_hit_at = client.time() + 0.08
    end
end)

events.on("paint", function()
    if pending_hit_at and client.time() >= pending_hit_at then
        pending_hit_at = nil
        if ui.get(hit_enabled) then play() end
    end
end)

events.on("shutdown", function()
    pending_hit_at = nil
    audio.stop()
end)
