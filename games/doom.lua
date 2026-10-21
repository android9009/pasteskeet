-- External Lua FFI frontend for the stock PrBoom libretro DLL. No native bridge.
-- The engine/assets are loaded from LOCALAPPDATA/skeet/doom, never linked to Skeet.
-- P start/pause; WASD move; Q/E turn; Ctrl/LMB fire; Space/RMB use; Tab map.

local show = ui.create("checkbox", "doom_visible", "Doom window", true)
local scale = ui.create("slider", "doom_scale", "Window size (%)", 200, 100, 400)
local gain = ui.create("slider", "doom_volume", "Volume (%)", 70, 0, 100)
local wad = ui.create("combo", "doom_wad", "IWAD (reload after changing)", 1,
    {"Shareware: doom1.wad", "Full: doom.wad", "Ultimate: doomu.wad"})
local block_game = ui.create("checkbox", "doom_block_cs2", "Block game movement/fire while playing", true)
local ffi = require("ffi")
if type(render.update_texture_pixels) ~= "function" then
    error("This example requires the generic render.update_texture_pixels API")
end

ffi.cdef[[
    typedef void (*retro_log_printf_t)(int, const char*, ...);
    struct retro_log_callback { retro_log_printf_t log; };
    // Win64 prefix-only adapter: accept level/format and ignore native varargs.
    // This is not a variadic Lua callback; it never reads or formats the tail.
    typedef void (*retro_log_prefix_t)(int, const char*);
    typedef bool (*retro_environment_t)(unsigned, void*);
    typedef void (*retro_video_refresh_t)(const void*, unsigned, unsigned, size_t);
    typedef void (*retro_audio_sample_t)(int16_t, int16_t);
    typedef size_t (*retro_audio_sample_batch_t)(const int16_t*, size_t);
    typedef void (*retro_input_poll_t)(void);
    typedef int16_t (*retro_input_state_t)(unsigned, unsigned, unsigned, unsigned);
    struct retro_variable { const char* key; const char* value; };
    struct retro_message { const char* msg; unsigned frames; };
    struct retro_game_info { const char* path; const void* data; size_t size; const char* meta; };
    struct retro_game_geometry { unsigned base_width, base_height, max_width, max_height; float aspect_ratio; };
    struct retro_system_timing { double fps, sample_rate; };
    struct retro_system_av_info { struct retro_game_geometry geometry; struct retro_system_timing timing; };
    unsigned retro_api_version(void);
    void retro_set_environment(retro_environment_t);
    void retro_set_video_refresh(retro_video_refresh_t);
    void retro_set_audio_sample(retro_audio_sample_t);
    void retro_set_audio_sample_batch(retro_audio_sample_batch_t);
    void retro_set_input_poll(retro_input_poll_t);
    void retro_set_input_state(retro_input_state_t);
    void retro_set_controller_port_device(unsigned, unsigned);
    void retro_init(void);
    void retro_deinit(void);
    bool retro_load_game(const struct retro_game_info*);
    void retro_unload_game(void);
    void retro_get_system_av_info(struct retro_system_av_info*);
    void retro_run(void);

    unsigned long __stdcall GetEnvironmentVariableW(const uint16_t*, uint16_t*, unsigned long);
    int __stdcall WideCharToMultiByte(unsigned, unsigned long, const uint16_t*, int, char*, int, const char*, int*);
    void* __stdcall GetForegroundWindow(void);
    void* __stdcall CreateMutexW(void*, int, const uint16_t*);
    int __stdcall CloseHandle(void*);
    unsigned long __stdcall GetLastError(void);
    unsigned long __stdcall GetFileAttributesW(const uint16_t*);
    int __stdcall MultiByteToWideChar(unsigned, unsigned long, const char*, int, uint16_t*, int);
    int __stdcall CreateDirectoryW(const uint16_t*, void*);

    struct WAVEFORMATEX { uint16_t wFormatTag, nChannels; uint32_t nSamplesPerSec, nAvgBytesPerSec;
                          uint16_t nBlockAlign, wBitsPerSample, cbSize; };
    struct WAVEHDR { char* lpData; uint32_t dwBufferLength, dwBytesRecorded; uintptr_t dwUser;
                     uint32_t dwFlags, dwLoops; struct WAVEHDR* lpNext; uintptr_t reserved; };
    unsigned __stdcall waveOutOpen(void**, unsigned, const struct WAVEFORMATEX*, uintptr_t, uintptr_t, unsigned);
    unsigned __stdcall waveOutPrepareHeader(void*, struct WAVEHDR*, unsigned);
    unsigned __stdcall waveOutUnprepareHeader(void*, struct WAVEHDR*, unsigned);
    unsigned __stdcall waveOutWrite(void*, struct WAVEHDR*, unsigned);
    unsigned __stdcall waveOutReset(void*);
    unsigned __stdcall waveOutClose(void*);
    unsigned __stdcall waveOutSetVolume(void*, unsigned long);
]]

if ffi.sizeof("void*") ~= 8 or ffi.sizeof("struct retro_log_callback") ~= 8 then
    error("This external example requires the Windows x64 libretro ABI")
end
local kernel = ffi.load("kernel32")
local user = ffi.load("user32")
local mm = ffi.load("winmm")
local host_window = user.GetForegroundWindow()
local play_key = 80 -- Windows VK_P, independent of keyboard language
local failure, focused, last_play_key, last_capture = nil, false, false, 0
local start_requested, preview_attempts = false, 0
local core, lease, mutex
local initialized, loaded, closing, closed = false, false, false, false
local callbacks, anchors, options, keys = {}, {}, {}, {}
local log_lines = 0
local pixel_format, fps, sample_rate, next_frame = 2, 35, 44100, 0
local video, frame_number, uploaded_frame, texture, tw, th = nil, 0, 0, nil, 0, 0
local audio, audio_rate, last_gain = nil, 0, -1
local audio_blocks, audio_cursor = {}, 1
local single = ffi.new("int16_t[8192]")
local single_count = 0
local x, y = storage.get("doom_x", 80), storage.get("doom_y", 90)
local dragging, grab_x, grab_y = false, 0, 0
local input_aliases = {[273]={38,87},[274]={40,83},[276]={37,81},[275]={39,69},[44]={188,65},[46]={190,68}}
local input_special = {[13]=13,[27]=27,[32]=32,[9]=9,[8]=8,[306]=17,[305]=17,[304]=16,[303]=16,
    [308]=18,[307]=18,[61]=187,[45]=189}
local input_vks = {1,2,8,9,13,16,17,18,27,32,37,38,39,40,188,190,187,189}
for vk = 48, 57 do input_vks[#input_vks + 1] = vk end
for vk = 65, 90 do if vk ~= play_key then input_vks[#input_vks + 1] = vk end end
for vk = 112, 123 do input_vks[#input_vks + 1] = vk end

local function cstring(text)
    local buffer = ffi.new("char[?]", #text + 1)
    ffi.copy(buffer, text)
    return buffer
end
local function wide(text)
    local n = ffi.tonumber(kernel.MultiByteToWideChar(65001, 8, text, #text, nil, 0))
    if n <= 0 then error("Invalid UTF-8 path") end
    local out = ffi.new("uint16_t[?]", n + 1)
    kernel.MultiByteToWideChar(65001, 8, text, #text, out, n)
    return out
end
local function appdata()
    local name = ffi.new("uint16_t[13]", {76,79,67,65,76,65,80,80,68,65,84,65,0})
    local out = ffi.new("uint16_t[32768]")
    local n = ffi.tonumber(kernel.GetEnvironmentVariableW(name, out, 32768))
    if n == 0 or n >= 32768 then error("Cannot read LOCALAPPDATA") end
    local utf8 = ffi.new("char[98304]")
    local size = ffi.tonumber(kernel.WideCharToMultiByte(65001, 0, out, n, utf8, 98304, nil, nil))
    if size <= 0 then error("Cannot encode LOCALAPPDATA") end
    return ffi.string(utf8, size)
end
local directory = appdata() .. "/skeet/doom"
local function require_file(path)
    local attributes = ffi.tonumber(kernel.GetFileAttributesW(wide(path)))
    if attributes == 4294967295 or (attributes & 16) ~= 0 then error("Missing file: " .. path) end
end
local function set_option(name, value) options[name] = cstring(value) end

local function reset_audio()
    if audio then mm.waveOutReset(audio) end
    for _, block in ipairs(audio_blocks) do block.queued = false end
    single_count = 0
end
local function close_audio()
    if not audio then return end
    reset_audio()
    for _, block in ipairs(audio_blocks) do
        if block.prepared then mm.waveOutUnprepareHeader(audio, block.header, ffi.sizeof("struct WAVEHDR")) end
    end
    mm.waveOutClose(audio)
    audio, audio_blocks, audio_rate = nil, {}, 0
end
local function open_audio(rate)
    close_audio()
    audio_rate = rate -- do not retry a missing audio device on every frame
    local fmt = ffi.new("struct WAVEFORMATEX")
    fmt.wFormatTag, fmt.nChannels, fmt.nSamplesPerSec = 1, 2, rate
    fmt.nBlockAlign, fmt.wBitsPerSample, fmt.nAvgBytesPerSec = 4, 16, rate * 4
    local output = ffi.new("void*[1]")
    if ffi.tonumber(mm.waveOutOpen(output, 4294967295, fmt, 0, 0, 0)) ~= 0 then return end
    audio, audio_rate, audio_cursor, last_gain = output[0], rate, 1, -1
    for i = 1, 8 do
        local block = {samples = ffi.new("int16_t[8192]"), header = ffi.new("struct WAVEHDR"), prepared = false, queued = false}
        audio_blocks[i] = block
        block.header.lpData = ffi.cast("char*", block.samples)
        block.header.dwBufferLength = 16384
        block.header.dwFlags = 0
        if ffi.tonumber(mm.waveOutPrepareHeader(audio, block.header, ffi.sizeof("struct WAVEHDR"))) ~= 0 then
            close_audio(); return
        end
        block.prepared = true
    end
end
local function audio_batch(data, frames)
    local remaining = ffi.tonumber(frames)
    if not audio or closing or not focused or audio_rate ~= math.floor(sample_rate) then return frames end
    local offset = 0
    while remaining > 0 do
        local block = audio_blocks[audio_cursor]
        if block.queued and (ffi.tonumber(block.header.dwFlags) & 1) == 0 then break end
        local count = math.min(remaining, 4096)
        ffi.copy(block.samples, data + offset * 2, count * 4)
        block.header.dwBufferLength = count * 4
        if ffi.tonumber(mm.waveOutWrite(audio, block.header, ffi.sizeof("struct WAVEHDR"))) ~= 0 then break end
        block.queued = true
        audio_cursor = audio_cursor % 8 + 1
        remaining, offset = remaining - count, offset + count
    end
    return frames -- bounded ring; excess audio is discarded instead of blocking
end
local function close_core()
    if closed then return end
    closed, closing, focused = true, true, false
    -- Keep every callback and its captured buffers alive until the core deinitializes.
    if loaded then loaded = false; core.retro_unload_game() end
    if initialized then initialized = false; core.retro_deinit() end
    close_audio()
    for _, callback in ipairs(callbacks) do callback:free() end
    callbacks = {}
    if mutex then kernel.CloseHandle(mutex); mutex = nil end
end

local function environment(command, data)
    if closing then return false end
    if command == 27 then -- GET_LOG_INTERFACE: this core has unguarded log calls
        -- The native struct is one function pointer at offset zero. Write the
        -- adapter's pointer without constructing a variadic Lua closure.
        ffi.cast("retro_log_prefix_t*", data)[0] = anchors.log
        return true
    elseif command == 9 or command == 30 or command == 31 then
        ffi.cast("const char**", data)[0] = command == 31 and anchors.saves or anchors.directory
        return true
    elseif command == 10 then
        local value = ffi.tonumber(ffi.cast("int*", data)[0])
        if value < 0 or value > 2 then return false end
        pixel_format = value; return true
    elseif command == 3 then ffi.cast("bool*", data)[0] = true; return true
    elseif command == 52 then ffi.cast("unsigned*", data)[0] = 0; return true
    elseif command == 16 then
        local vars = ffi.cast("const struct retro_variable*", data)
        for i = 0, 511 do
            local entry = vars[i]
            if entry.key == ffi.nullptr then break end
            if entry.value ~= ffi.nullptr then
                local value = ffi.string(entry.value):match(";%s*([^|]+)")
                if value then set_option(ffi.string(entry.key), value) end
            end
        end
        set_option("prboom-resolution", "320x200")
        set_option("prboom-color_format", "16bits")
        set_option("prboom-render_threads", "OFF")
        set_option("prboom-mouse_on", "disabled")
        set_option("prboom-sound_samplerate", "44100")
        set_option("prboom-complevel", "-1")
        return true
    elseif command == 15 then
        local var = ffi.cast("struct retro_variable*", data)
        local value = var.key ~= ffi.nullptr and options[ffi.string(var.key)] or nil
        var.value = value or ffi.nullptr
        return value ~= nil
    elseif command == 17 then ffi.cast("bool*", data)[0] = false; return true
    elseif command == 32 then
        local av = ffi.cast("const struct retro_system_av_info*", data)
        fps, sample_rate = ffi.tonumber(av.timing.fps), ffi.tonumber(av.timing.sample_rate)
        return true
    elseif command == 37 then return true
    elseif command == 7 then failure = "Engine stopped. Reload to restart."; return true
    elseif command == 18 or command == 6 or command == 11 or command == 35 or command == 12 then
        return true
    end
    return false -- no hardware renderer, float audio or MIDI callbacks
end
local function video_refresh(data, width, height, pitch)
    if closing or data == ffi.nullptr then return end
    width, height, pitch = ffi.tonumber(width), ffi.tonumber(height), ffi.tonumber(pitch)
    local formats = {[0] = "rgb555", [1] = "bgrx8", [2] = "rgb565"}
    local bpp = pixel_format == 1 and 4 or 2
    local length = pitch * (height - 1) + width * bpp
    if width < 1 or height < 1 or width > 4096 or height > 4096 or width * height > 1048576
        or pitch < width * bpp or length > 4194304 or data == ffi.cast("void*", -1) then
        failure = "Unsupported libretro video frame"; return
    end
    video = {bytes = ffi.string(data, length), width = width, height = height, pitch = pitch, format = formats[pixel_format]}
    frame_number = frame_number + 1
end
local function input_state(port, device, index, id)
    if closing or not focused or port ~= 0 then return 0 end
    if device == 2 then -- libretro mouse
        if id == 2 then return keys[1] and 1 or 0 end
        if id == 3 then return keys[2] and 1 or 0 end
        return 0
    end
    if device ~= 3 then return 0 end -- keyboard only
    if input_aliases[id] then
        local pair = input_aliases[id]; return (keys[pair[1]] or keys[pair[2]]) and 1 or 0
    end
    if id == 112 then return 0 end -- P belongs to the frontend, not Doom's bindings
    if id == 119 or id == 97 or id == 115 or id == 100 then return 0 end -- WASD already mapped
    local vk = input_special[id]
    if not vk and id >= 282 and id <= 293 then vk = 112 + id - 282 end
    if not vk and id >= 97 and id <= 122 then vk = 65 + id - 97 end
    if not vk and id >= 48 and id <= 57 then vk = id end
    return vk and keys[vk] and 1 or 0
end
local function callback(ctype, fn)
    local value = ffi.cast(ctype, fn)
    callbacks[#callbacks + 1] = value
    return value
end

-- Initialization is native work on the Lua thread. No invented per-game API or
-- foreign Lua worker is involved. The normal script initialization limit applies.
local started, reason = api.protect(function()
    require_file(directory .. "/prboom_libretro.dll")
    require_file(directory .. "/prboom.wad")
    local names = {"doom1.wad", "doom.wad", "doomu.wad"}
    local path = directory .. "/" .. names[ui.get(wad)]
    require_file(path)
    mutex = kernel.CreateMutexW(nil, 0, wide("skeet.external.prboom.lua"))
    local last_error = ffi.tonumber(kernel.GetLastError())
    if mutex == ffi.nullptr then mutex = nil; error("Cannot create external example lease") end
    if last_error == 183 then kernel.CloseHandle(mutex); mutex = nil; error("Another PrBoom Lua instance is running") end
    anchors.directory, anchors.saves, anchors.path = cstring(directory), cstring(directory .. "/saves"), cstring(path)
    kernel.CreateDirectoryW(wide(directory .. "/saves"), nil)
    -- The finalizer captures close_core, which owns the core, callbacks and buffers.
    lease = ffi.gc(ffi.new("uint8_t[1]"), function() close_core() end)
end, {instructions = 200000, time_ms = 25})
if not started then
    failure = tostring(reason)
    close_core()
else
    -- Outside the short api.protect scope: the parent initialization budget is
    -- determined by the host, including DLL/audio setup. Ordinary failures appear in the Lua log; the
    -- already-established finalizer closes the lease on failure.
    core = ffi.load(directory .. "/prboom_libretro.dll")
    if ffi.tonumber(core.retro_api_version()) ~= 1 then error("Unsupported libretro API") end
    -- A Win64 variadic caller passes these first two arguments normally. The
    -- fixed-signature closure intentionally discards all remaining arguments.
    -- Keep it alive before set_environment, through load/run/unload/deinit.
    anchors.log = callback("retro_log_prefix_t", function(level, format)
        if closing or level < 2 or format == ffi.nullptr or log_lines >= 64 then return end
        log_lines = log_lines + 1
        client.log("[PrBoom format] " .. ffi.string(format):sub(1, 1024):gsub("[\r\n]+", " "))
    end)
    core.retro_set_environment(callback("retro_environment_t", environment))
    core.retro_set_video_refresh(callback("retro_video_refresh_t", video_refresh))
    core.retro_set_audio_sample_batch(callback("retro_audio_sample_batch_t", audio_batch))
    core.retro_set_audio_sample(callback("retro_audio_sample_t", function(left, right)
        if closing or single_count >= 8192 then return end
        single[single_count], single[single_count + 1] = left, right
        single_count = single_count + 2
    end))
    core.retro_set_input_poll(callback("retro_input_poll_t", function() end))
    core.retro_set_input_state(callback("retro_input_state_t", input_state))
    core.retro_init(); initialized = true
    local game = ffi.new("struct retro_game_info")
    game.path = anchors.path
    if not core.retro_load_game(game) then
        failure = "PrBoom rejected the IWAD"; close_core()
    else
        loaded = true
        core.retro_set_controller_port_device(0, 3)
        local av = ffi.new("struct retro_system_av_info")
        core.retro_get_system_av_info(av)
        fps, sample_rate = ffi.tonumber(av.timing.fps), ffi.tonumber(av.timing.sample_rate)
        -- Driver initialization and buffer preparation may block. Do this once
        -- during script loading, never in the 35 Hz paint/playback path.
        if sample_rate == sample_rate and sample_rate >= 8000 and sample_rate <= 192000 then
            open_audio(math.floor(sample_rate))
        end
    end
end

local function pause()
    if focused then reset_audio() end
    focused = false
end
local function valid_timing()
    return fps == fps and fps >= 1 and fps <= 240 and sample_rate == sample_rate
        and sample_rate >= 8000 and sample_rate <= 192000
end
events.on("paint", function()
    local now = client.time()
    local menu, visible = ui.is_menu_opened(), ui.get(show)
    local foreground = user.GetForegroundWindow() == host_window
    local play = client.key_down(play_key)
    if not foreground or menu or not visible or failure then pause() end
    if not foreground or not visible or failure then start_requested = false end
    if play and not last_play_key and foreground and visible and not failure then
        if menu then
            start_requested = not start_requested
        elseif focused then
            pause()
        else
            focused = true; next_frame = now
        end
    end
    if start_requested and foreground and not menu and visible and not failure then
        start_requested, focused, next_frame = false, true, now
    end
    last_play_key = play
    -- Obtain a preview while paused, even in the Skeet menu. No player input or
    -- audio is enabled until P starts playback; stop preview work after a frame.
    if loaded and foreground and visible and not failure and (focused or not video) then
        if focused then
            last_capture = now
        end
        if not valid_timing() then failure = "Invalid core timing"; pause()
        elseif now >= next_frame then
            next_frame = now + 1 / fps -- at most one core frame per paint; no catch-up burst
            if focused then
                for _, vk in ipairs(input_vks) do keys[vk] = client.key_down(vk) end
                local percent = ui.get(gain)
                if audio and percent ~= last_gain then
                    local value = math.floor(percent * 65535 / 100)
                    mm.waveOutSetVolume(audio, value | (value << 16)); last_gain = percent
                end
            end
            single_count = 0
            core.retro_run()
            if single_count > 0 then audio_batch(single, single_count / 2) end
            if not video then
                preview_attempts = preview_attempts + 1
                if preview_attempts >= 35 and not failure then
                    failure = "No video received after 35 core frames. Check the Lua log."
                    pause()
                end
            end
        end
    end
    if not visible then dragging = false; return end
    local sw, sh = render.screen_size()
    local factor = math.max(0.25, math.min(ui.get(scale) / 100, (sw - 24) / 320, (sh - 95) / 240))
    local width, height = math.floor(320 * factor), math.floor(240 * factor)
    local mouse = ui.mouse_state()
    if menu and mouse.clicked and mouse.x >= x and mouse.x <= x + width and mouse.y >= y and mouse.y <= y + 25 then
        dragging, grab_x, grab_y = true, mouse.x - x, mouse.y - y
    end
    if not menu or not mouse.down then dragging = false end
    if dragging then x, y = mouse.x - grab_x, mouse.y - grab_y end
    x, y = math.max(0, math.min(x, sw - width)), math.max(0, math.min(y, sh - height - 65))
    render.rect(x - 2, y - 2, width + 4, height + 69, {85, 25, 20, 255}, true)
    render.rect(x, y, width, height + 65, {16, 15, 14, 255}, true)
    local status = failure and "ERROR" or focused and "PLAYING" or start_requested and "CLOSE MENU TO PLAY"
        or not video and "LOADING PREVIEW" or "P TO PLAY"
    render.text(x + 8, y + 5, "DOOM / EXTERNAL LUA FFI / " .. status, {225,180,110,255})
    if video and frame_number ~= uploaded_frame and not failure then
        if not texture or tw ~= video.width or th ~= video.height then
            texture, failure = render.create_texture_rgba(video.width, video.height)
            tw, th = video.width, video.height
        end
        if texture then
            local ok, err = render.update_texture_pixels(texture, video.bytes, video.format, video.pitch)
            if ok then uploaded_frame = frame_number else failure = tostring(err); pause() end
        end
    end
    if texture then render.texture(texture, x, y + 25, width, height) end
    if failure or not focused then
        render.rect(x, y + 25, width, height, {0,0,0,texture and 110 or 255}, true)
        local hint = start_requested and "Close Skeet menu to start"
            or menu and "P: queue start, then close Skeet menu"
            or not video and "Loading first frame..." or "P: play / pause"
        render.text(x + 10, y + 50, failure and "EXTERNAL EXAMPLE ERROR" or hint, {240,195,125,255})
        if failure then
            local text = tostring(failure):gsub("[\r\n]", " ")
            local columns = math.max(20, math.floor(width / 8) - 4)
            for row = 0, 5 do
                local part = text:sub(row * columns + 1, (row + 1) * columns)
                if part == "" then break end
                render.text(x + 10, y + 77 + row * 17, part, {230,205,190,255})
            end
        else render.text(x + 10, y + 78, "Esc: Doom menu / Enter: select", {205,205,205,255}) end
    end
    render.text(x + 8, y + height + 30, "WASD move | Q/E turn | Ctrl fire | Space use", {180,175,165,255})
    render.text(x + 8, y + height + 47, "Tab map | Shift run | F2 save | F3 load | P pause", {180,175,165,255})
end)

local function capturing()
    return focused and not failure and ui.get(show) and ui.get(block_game) and client.time() - last_capture < 0.5
end
local function stop_command()
    cmd.set_movement(0, 0, 0); cmd.clear_subticks()
    for _, mask in ipairs({buttons.attack,buttons.attack2,buttons.jump,buttons.duck,buttons.forward,
        buttons.back,buttons.moveleft,buttons.moveright,buttons.use,buttons.reload,buttons.speed}) do
        cmd.set_button_state(mask, false, false, false)
    end
end
events.on("create_move", function()
    if capturing() then movement.claim("bhop"); movement.claim("strafe"); cmd.set_movement(0,0,0) end
end)
events.on("pre_rage", function() if capturing() then ragebot.claim_command(); stop_command() end end)
events.on("post_move", function() if capturing() then stop_command() end end)
events.on("shutdown", function()
    close_core()
    if lease then ffi.gc(lease, nil); lease = nil end
    storage.set("doom_x", x); storage.set("doom_y", y)
end)
