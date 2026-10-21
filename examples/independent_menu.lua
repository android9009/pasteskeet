-- F6 opens this Lua window independently; Delete remains Skeet's usual key.
-- Omit key (or use key=0) to make the window follow Skeet instead.
if type(ui.create_window) ~= "function" then
    client.log("Rebuild Skeet to enable Lua windows")
    return
end
local window = ui.create_window("my_menu", "My Lua menu", {
    key = 0x75, x = 140, y = 120, width = 320, height = 340,
})
local enabled = ui.create("checkbox", "my_enabled", "My feature", false)
local amount = ui.create("slider", "my_amount", "Amount", 30, 0, 100)
local style = ui.create("combo", "my_style", "Style", 1, {"Simple", "Detailed"})
ui.attach_window(enabled, window)
ui.attach_window(amount, window)
ui.attach_window(style, window)

events.on("paint", function()
    if ui.get(enabled) then
        render.text(30, 80, "My feature: " .. tostring(ui.get(amount)), {255, 255, 255, 255})
    end
end)
-- Change the key: ui.window_bind(window, 0x24) -- Home
-- Follow Skeet: ui.window_bind(window, 0)
-- Programmatic visibility: ui.set_window_open(window, true/false)
-- State/geometry: ui.get_window(window)
-- Return a control to Config: ui.attach_window(enabled, nil)
