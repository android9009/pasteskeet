# Native XUI / ImGui windows and menu themes

NEXT GEN is the default. Its Style combo is below Subscription in the top-right
information popup; CLASSIC exposes Style in Misc. Style, Old Name and Old Color
are independent persisted config fields. CLASSIC retains its 900x700 script
editor, original editor background/buttons and original warning image/dialog.
NEXT GEN uses the 765x510 editor and the compact branded warning. Old Color
restores blue backgrounds, accents, icons, checkboxes and sliders.
Old Name and Old Color are available and effective only in NEXT GEN. CLASSIC
ignores their saved values; returning to NEXT GEN restores those preferences.
Explicit Lua theme overrides remain supported in both styles.

## Creating windows

xui.create_window(id, title, options, callback) and
imgui.create_window(id, title, options, callback) run callback once per rendered
frame inside a managed native window. Each script can have up to eight windows
across ui, xui and imgui. Existing ui.create/ui.create_window remain supported;
all three UI types can run simultaneously with either native menu style.

Options: x, y, width, height, key, open, as in ui.create_window.
Native windows also accept titlebar/background/movable/resizable (booleans, true
by default) and padding (0..100). Set titlebar=false, background=false and
padding=0 to draw the entire window from scratch; use movable=false if the top
30px should contain controls rather than a drag handle. key=0 follows
the main menu; a nonzero Windows VK toggles the window independently (117 = F6).
ui.window_bind, ui.set_window_open and ui.get_window work with all window types.
Window state is script-owned; use storage if it should survive reloads.
A window created inside another callback starts drawing next frame.

Widgets return value, changed; retain the returned value in Lua. Combo indices
are 1-based. Colors are four integer channels {r,g,b,a}, each 0..255. Labels and
IDs must be stable. Script-authored text stays literal and is not translated.
Native widgets are callable only inside their own backend's window callback.

## Available API

The IDE declarations in api.lua describe the same exported methods:

- `xui.create_window(id, title, options, callback)`
- `xui.text(text, color)`
- `xui.button(label, width, height)`
- `xui.checkbox(label, value)`
- `xui.slider_float(label, value, minimum, maximum)`
- `xui.slider_int(label, value, minimum, maximum)`
- `xui.input_text(label, value, capacity, hint)`
- `xui.combo(label, selected, items, width)`
- `xui.multicombo(label, selected, items)`
- `xui.color_picker(label, color)`
- `xui.same_line(offset, spacing)`
- `xui.spacing(pixels)`
- `xui.cursor(x, y)`
- `xui.begin_child(id, width, height, border_or_scroll)`
- `xui.push_id(id)`
- `xui.push_style_color(name, color)`
- `xui.push_style_var(name, x, y)`
- `xui.push_font(font)`
- `xui.line(x, y, x2, y2, color, thickness)`
- `xui.rect(x, y, width, height, color, rounding, thickness)`
- `xui.rect_filled(x, y, width, height, color, rounding)`
- `xui.blur(x, y, width, height, color, rounding)`
- `xui.text_at(x, y, text, color, font)`
- `xui.circle(x, y, radius, color, filled, thickness)`
- `xui.image(texture, width, height)`
- `xui.begin_popup(id, width)`
- `xui.keybind(label, key)`
- `imgui.create_window(id, title, options, callback)`
- `imgui.text(text, color)`
- `imgui.button(label, width, height)`
- `imgui.checkbox(label, value)`
- `imgui.slider_float(label, value, minimum, maximum)`
- `imgui.slider_int(label, value, minimum, maximum)`
- `imgui.input_text(label, value, capacity, hint)`
- `imgui.combo(label, selected, items, width)`
- `imgui.multicombo(label, selected, items)`
- `imgui.color_picker(label, color)`
- `imgui.same_line(offset, spacing)`
- `imgui.spacing(pixels)`
- `imgui.cursor(x, y)`
- `imgui.begin_child(id, width, height, border_or_scroll)`
- `imgui.push_id(id)`
- `imgui.push_style_color(name, color)`
- `imgui.push_style_var(name, x, y)`
- `imgui.push_font(font)`
- `imgui.line(x, y, x2, y2, color, thickness)`
- `imgui.rect(x, y, width, height, color, rounding, thickness)`
- `imgui.rect_filled(x, y, width, height, color, rounding)`
- `imgui.blur(x, y, width, height, color, rounding)`
- `imgui.text_at(x, y, text, color, font)`
- `imgui.circle(x, y, radius, color, filled, thickness)`
- `imgui.image(texture, width, height)`
- `imgui.selectable(label, selected)`
- `imgui.item_width(width)`
- `imgui.begin_combo(label, preview)`
- `imgui.tree_node(label)`
- `imgui.begin_tab_bar(id)`
- `imgui.begin_tab_item(label)`
- `imgui.open_popup(id)`
- `imgui.begin_popup(id, width)`
- `imgui.begin_table(id, columns)`
- `imgui.tooltip(text)`
- `ui.style_colors(backend)`
- `ui.set_style_color(backend, name, color)`
- `ui.set_blur_opacity(surface, opacity)`

## Layout, scopes, drawing and fonts

cursor() returns local coordinates, cursor(x,y) sets them. available() returns
remaining width/height. window_rect() returns x/y/width/height. Shapes/text_at
use screen coordinates. line argument 6 is thickness; rect argument 6 is radius
and 7 is thickness. blur draws the cached scene with a rounded tint.
image uses a texture handle obtained from render.setup_texture*; initialize
render resources in paint, as before. ImGui shapes enter its current draw list;
XUI shapes enter the current clipped XUI layer.

XUI begin_child's fourth argument enables scrolling; ImGui's enables a border.
Call the corresponding end only if begin returned true. This also applies to
popup/combo/tree/tab/table begin calls. Push/pop must nest correctly. Remaining
scopes are closed automatically at callback return/error/budget expiry, before
the host window closes. Font/color/layout state is restored for other windows.
Table navigation requires a table in the current window; tab items require a
script tab bar. close_popup applies only to this callback's popup/combo.

push_style_color names come from ui.style_colors(backend). push_style_var uses
native enum names without their prefix: XUI item_spacing_y, rounding, frame_pad_x;
ImGui FrameRounding, FramePadding, ItemSpacing, Alpha. Vec2 variables take x,y.
XUI push_font takes a script-owned render.setup_font handle (or nil for default).
ImGui takes default/title/sync; default supports the menu's custom/language font.
ImGui resources, contexts and frame ownership are managed by the host; the adapter
does not expose raw context/draw-list pointers or every C++ overload.

XUI popups use the native last-widget settings popup mechanism. multicombo takes
matching bool and label arrays. ImGui item_state returns hovered/active/clicked/
edited. item_width sets the width of the next input/slider/combo.

## Main-menu colors and blur

ui.style_colors(backend) returns all supported roles: backend menu includes every
custom NEXT GEN palette role, imgui covers all ImGuiCol, xui covers all
xui::style_col. ui.set_style_color(backend, name, rgba) overrides one role; nil
removes this script's override. The menu roles checkbox_on, checkbox_off,
slider_fill and tab_icon independently color custom controls. ImGui Text,
TextDisabled, CheckMark, SliderGrab, FrameBg, Button and their relevant states
also map to the corresponding custom menu roles.

ui.set_blur_opacity(surface, opacity) changes the tint density over cached blur:
0 means clear blur, 1 means opaque tint. Surfaces: sidebar, header, body, surface,
card, control. Tint the shell via imgui WindowBg; popup colors use PopupBg and
menu frame_inactive. The blur image remains cached; this API changes tint/alpha,
not the blur kernel strength. XUI backgrounds may also be drawn with xui.blur.

ui.reset_theme() releases this script's overrides. Unload, reload and script
failure release them automatically. For overlapping script overrides, the last
script to update its patch wins; release reveals the previous script's patch or
the base Old Color palette. Store user preferences through storage/ui controls.

Example: [three simultaneous windows](native/mixed_menu.lua).
Validation is offline; build and check graphics, focus/input and timing in game.

## No-argument scope helpers and queries

- `xui.available()`
- `xui.window_rect()`
- `xui.end_child()`
- `xui.pop_id()`
- `xui.pop_style_color()`
- `xui.pop_style_var()`
- `xui.pop_font()`
- `xui.end_popup()`
- `imgui.available()`
- `imgui.window_rect()`
- `imgui.end_child()`
- `imgui.pop_id()`
- `imgui.pop_style_color()`
- `imgui.pop_style_var()`
- `imgui.pop_font()`
- `imgui.separator()`
- `imgui.item_state()`
- `imgui.begin_group()`
- `imgui.end_group()`
- `imgui.end_combo()`
- `imgui.tree_pop()`
- `imgui.end_tab_bar()`
- `imgui.end_tab_item()`
- `imgui.end_popup()`
- `imgui.close_popup()`
- `imgui.end_table()`
- `imgui.next_column()`
- `imgui.next_row()`
