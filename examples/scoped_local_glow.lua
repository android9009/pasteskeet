-- Glow for the scoped local player, plus independent third-person attachments.
-- Attachments include held weapons and the holstered pistol/knife on the model.
-- Thirdperson is required to see the local model and its weapon attachments.
local enabled = ui.create("checkbox", "scoped_local_glow", "Local glow while scoped", false)
local local_color = ui.create("color", "scoped_local_color", "Local glow color", {100, 170, 255, 255})
local local_opacity = ui.create("slider", "scoped_local_opacity", "Local glow opacity %", 80, 0, 100)
local attachments = ui.create("checkbox", "scoped_attachments_glow", "Thirdperson attachments glow", false)
local attachment_color = ui.create("color", "scoped_attachments_color", "Attachments glow color", {255, 140, 80, 255})
local attachment_opacity = ui.create("slider", "scoped_attachments_opacity", "Attachments glow opacity %", 85, 0, 100)
local attachment_scope = ui.create("checkbox", "scoped_attachments_only_zoom", "Attachments only while scoped", false)

local glow, error_message = chams.builtin_material("glow")
if not glow then error("Glow material unavailable: " .. tostring(error_message)) end

local function color_with_opacity(control, opacity)
    local color = ui.get(control)
    return {color[1], color[2], color[3], math.floor(color[4] * ui.get(opacity) / 100 + 0.5)}
end

local function release()
    chams.set("local", nil)
    chams.set("attachments", nil)
    settings.override("chams local", "chams", nil)
end

events.on("paint", function()
    local me = entity.local_player()
    if not me or not me.alive then release(); return end

    local local_enabled = ui.get(enabled)
    -- Suppress a native local layer outside zoom while this feature is enabled.
    -- A selected Lua material takes precedence over this disabled native layer.
    if local_enabled then
        settings.override("chams local", "chams", false)
    else
        settings.override("chams local", "chams", nil)
    end
    if local_enabled and me.scoped then
        chams.set("local", glow, color_with_opacity(local_color, local_opacity))
    else
        chams.set("local", nil)
    end

    local weapon_enabled = ui.get(attachments) and settings.get("camera", "thirdperson") and
        (not ui.get(attachment_scope) or me.scoped)
    if weapon_enabled then
        chams.set("attachments", glow, color_with_opacity(attachment_color, attachment_opacity))
    else
        chams.set("attachments", nil)
    end
end)

events.on("shutdown", release)
