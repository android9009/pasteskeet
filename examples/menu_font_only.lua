-- Changes Skeet's menu font while keeping the current language (including English/Chinese).
-- No language registration or ui.set_language call is needed.
-- Put a TTF/OTF/TTC/OTC directly in %LOCALAPPDATA%/skeet and change this filename.
if type(ui.set_menu_font) ~= "function" then
    client.log("Rebuild Skeet to enable ui.set_menu_font")
    return
end
local ok, reason = ui.set_menu_font("menu_pt_br.otf", 11)
if not ok then client.log("Cannot set the menu font:", reason) end
-- ui.set_menu_font(nil) releases this script's override; unload does the same.
-- ui.get_menu_font() reports the effective font and whether it comes from a language.
