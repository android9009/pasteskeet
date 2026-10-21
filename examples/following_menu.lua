-- This separate Lua window opens/closes together with Skeet's Delete menu.
if type(ui.create_window) ~= "function" then
    client.log("Rebuild Skeet to enable Lua windows")
    return
end
local window = ui.create_window("following", "Lua settings", {x=160, y=140, width=300, height=220})
local enabled = ui.create("checkbox", "following_enabled", "My own caption", false)
ui.attach_window(enabled, window)
-- ui.create controls without ui.attach_window keep their existing Config placement.
