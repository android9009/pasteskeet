-- Load this script to display all three UI backends together in either menu style.
-- F6: XUI window. F7: ImGui window. The retained ui window follows the main menu.
local enabled, amount, selected = true, 25, 1
local tint = {125, 175, 255, 255}
local text = "Hello from native UI"

ui.create("checkbox", "retained_enabled", "Retained UI control", true)
ui.create_window("retained", "Lua ui", {x = 30, y = 120, width = 240, height = 180})
ui.attach_window("retained_enabled", "retained")

xui.create_window("native_xui", "Lua XUI", {
    x = 300, y = 120, width = 340, height = 360, key = 117, open = true
}, function()
    xui.push_style_color("checkbox_mark", tint)
    xui.text("A native XUI window")
    enabled = xui.checkbox("Enabled", enabled)
    amount = xui.slider_int("Amount", amount, 0, 100)
    selected = xui.combo("Mode", selected, {"One", "Two", "Three"})
    xui.pop_style_color()
    xui.spacing(8)
    if xui.button("Toggle ImGui window", 200, 24) then
        ui.set_window_open("native_imgui", not ui.get_window("native_imgui").open)
    end
end)

imgui.create_window("native_imgui", "Lua ImGui", {
    x = 670, y = 120, width = 360, height = 400, key = 118, open = true
}, function()
    imgui.text("A native ImGui window")
    if imgui.begin_tab_bar("tabs") then
        if imgui.begin_tab_item("Controls") then
            imgui.push_style_color("CheckMark", tint)
            enabled = imgui.checkbox("Enabled", enabled)
            imgui.pop_style_color()
            amount = imgui.slider_float("Amount", amount, 0, 100)
            text = imgui.input_text("Message", text, 256, "Write a message")
            tint = imgui.color_picker("Tint", tint)
            imgui.end_tab_item()
        end
        if imgui.begin_tab_item("Layout") then
            if imgui.begin_table("columns", 2) then
                imgui.next_column()
                imgui.text("Left column")
                imgui.next_column()
                imgui.text("Right column")
                imgui.end_table()
            end
            imgui.end_tab_item()
        end
        imgui.end_tab_bar()
    end
    if imgui.button("Apply tint to native menu") then
        ui.set_style_color("menu", "checkbox_on", tint)
        ui.set_style_color("menu", "slider_fill", tint)
        ui.set_style_color("menu", "tab_icon", tint)
        ui.set_style_color("xui", "checkbox_mark", tint)
        ui.set_blur_opacity("sidebar", 0.8)
    end
    imgui.same_line()
    if imgui.button("Reset colors") then ui.reset_theme() end
end)
