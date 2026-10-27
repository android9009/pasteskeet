-- NEXT GEN only: RGB Lab appears below Scripts (at most four visible tabs globally).
-- Keep settings on the script page; the optional tab is for presentation.
-- Attached controls stay available on the script page in CLASSIC and NEXT GEN.
local tab = ui.create_tab("rgb_lab", "RGB Lab", {
    icon = "R", background = {22, 25, 34, 120}, active_background = {35, 45, 65, 220}
})
local demo = ui.create_tab_group(tab, "demo", "Demo overlay", 1)
local appearance = ui.create_tab_group(tab, "appearance", "Menu appearance", 2)
local enabled = ui.create("checkbox", "tab_overlay", "Show demo overlay", true)
local speed = ui.create("slider", "tab_speed", "RGB speed", 1, 0.1, 4)
local logo = ui.create("checkbox", "tab_logo", "Animate Skeet letters", true)
local shadow = ui.create("checkbox", "tab_shadow", "Animate letter shadows", true)
ui.attach_tab(enabled, tab, demo)
ui.attach_tab(speed, tab, demo)
ui.attach_tab(logo, tab, appearance)
ui.attach_tab(shadow, tab, appearance)

local function rgb(phase, alpha)
    return {math.floor(127.5 + 127.5 * math.sin(phase)),
            math.floor(127.5 + 127.5 * math.sin(phase + 2.0944)),
            math.floor(127.5 + 127.5 * math.sin(phase + 4.1888)), alpha or 255}
end

-- Generate a private 32x32 diamond/cross icon once; no external image is needed.
local icon_attempted = false
events.on("paint", function()
    if not icon_attempted then
        icon_attempted = true
        local pixels = {}
        for y = 0, 31 do
            for x = 0, 31 do
                local diamond = math.abs(x - 15.5) + math.abs(y - 15.5)
                local edge = diamond >= 11 and diamond <= 15
                local cross = (math.abs(x - 15.5) < 2 or math.abs(y - 15.5) < 2) and diamond < 9
                pixels[#pixels + 1] = string.char(255, 255, 255, (edge or cross) and 255 or 0)
            end
        end
        local texture = render.setup_texture_rgba(table.concat(pixels), 32, 32)
        if texture then ui.set_tab_style(tab, {icon_texture = texture}) end
    end
    local phase = client.time() * ui.get(speed)
    local letters = {}
    for i = 1, #"RGB Lab" do letters[i] = rgb(phase + i * 0.45) end
    ui.set_tab_style(tab, {text_colors = letters, icon_color = rgb(phase + 1)})
    -- Nine roles also support Old Name's NEVERLOSE; SKEET uses the first five.
    for i = 1, 9 do
        ui.set_style_color("menu", "logo_text_" .. i, ui.get(logo) and rgb(phase + i * 0.5) or nil)
        ui.set_style_color("menu", "logo_shadow_" .. i, ui.get(shadow) and rgb(-phase + i * 0.5, 210) or nil)
    end
    if ui.get(enabled) then
        render.text(30, 110, "RGB Lab: controls in a custom menu tab", rgb(phase))
    end
end)
-- The host removes the tab and restores this script's theme patches on unload.
