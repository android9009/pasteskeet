-- Ready-made game materials, not the built-in Bloom/Glow/Flat shaders.
-- Replace paths below with your own mounted, compiled model materials.
-- Materials are loaded once; changing the combo does not load every frame.
local resources = {
    {name = "Gold", path = "materials/models/inventory_items/pgl_pickem_2024/gold.vmat_c"},
    {name = "Metal", path = "materials/models/inventory_items/pgl_pickem_2024/crystal_metal.vmat_c"},
    {name = "AK47 finish", path = "materials/models/weapons/v_models/rif_ak47/ak47.vmat_c"}
}
local handles, material_names = {}, {}
for index, resource in ipairs(resources) do
    material_names[index] = resource.name
    local handle, reason = chams.load_material(resource.path)
    handles[index] = handle
    if not handle then
        client.log(resource.name .. " unavailable: " .. tostring(reason))
    end
end

local enabled = ui.create("checkbox", "custom_material_enabled", "Custom material chams", false)
local material = ui.create("combo", "custom_material_choice", "Material", 1, material_names)
local target = ui.create("combo", "custom_material_target", "Apply to", 1,
    {"Enemies", "Teammates", "Local player", "Hands", "Firstperson weapon", "Thirdperson attachments"})
local tint = ui.create("color", "custom_material_color", "Material tint", {255, 255, 255, 255})
local opacity = ui.create("slider", "custom_material_opacity", "Opacity %", 100, 0, 100)
local pulse = ui.create("checkbox", "custom_material_pulse", "Pulse tint", false)
local pulse_speed = ui.create("slider", "custom_material_pulse_speed", "Pulse speed", 2, 0.1, 8)
local targets = {"enemy", "team", "local", "arms", "weapon", "attachments"}
local active_target

local function release()
    if active_target then
        chams.set(active_target, nil)
        active_target = nil
    end
end

events.on("paint", function()
    local handle = handles[ui.get(material)]
    if not ui.get(enabled) or not handle then release(); return end
    local selected = targets[ui.get(target)]
    if selected == "local" or selected == "attachments" then
        local me = entity.local_player()
        if not me or not me.alive then release(); return end
    end
    if selected == "attachments" and not settings.get("camera", "thirdperson") then
        release(); return
    end
    if selected ~= active_target then release(); active_target = selected end

    local color = ui.get(tint)
    local brightness = 1
    if ui.get(pulse) then
        brightness = 0.7 + 0.3 * math.sin(client.time() * ui.get(pulse_speed))
    end
    local function channel(value) return math.floor(value * brightness + 0.5) end
    chams.set(active_target, handle, {
        channel(color[1]), channel(color[2]), channel(color[3]),
        math.floor(color[4] * ui.get(opacity) / 100 + 0.5)
    })
end)
events.on("shutdown", release)
